/**
 * Copyright 2025 INES-ID
 *
 * @file test_fast_zybo.cpp
 * @brief ORB Feature Detection Test Program for Zybo FPGA Platform
 *
 * This program tests the hardware-accelerated ORB (Oriented FAST and Rotated
 * BRIEF) feature detection implementation on the Zynq 7020 platform. It
 * processes input images through the FPGA accelerator and extracts keypoints
 * with descriptors.
 */

#include <stdlib.h>
#include <time.h>

#include <chrono>
#include <iomanip>
#include <iostream>
#include <opencv2/opencv.hpp>

#include "dma_zcu.h"

// ============================================================================
// CONFIGURATION CONSTANTS
// ============================================================================

// Image dimensions
#define LINE_SIZE 640  // Image width in pixels
#define NUM_LINES 480  // Image height in pixels

// Feature detection parameters
#define MAX_FEATURES 600    // Maximum number of features to detect
#define FEAT_MEM_LINES 512  // Feature memory buffer size

// Memory configuration
#define MEM_SIZE_PIX 65528   // Total pixel memory size
#define MEM_LINE_SIZE_PIX 8  // Pixels per memory line
#define BURST_SIZE 254       // DMA burst transfer size

// ============================================================================
// GLOBAL VARIABLES
// ============================================================================

// FAST corner detection thresholds
int32_t corner_thresh = 15;     // Positive threshold for corner detection
int32_t corner_thresh_n = -15;  // Negative threshold for corner detection

// ============================================================================
// FUNCTION DECLARATIONS
// ============================================================================

/**
 * @brief Process a single image frame through the ORB accelerator
 * @param imagePath Path to the input image file
 * @param index Pointer to current buffer index
 * @param index_offset Pointer to index offset
 * @return 0 on success, 1 on error
 */
int process_frame(std::string imagePath, uint32_t *index, u32 *index_offset);

/**
 * @brief Convert quadrant and theta values to orientation in degrees
 * @param quadrant Quadrant value (0-3)
 * @param theta Theta value within quadrant
 * @return Orientation angle in degrees
 */
float get_orientation(uint16_t quadrant, uint16_t theta);

// ============================================================================
// MAIN FUNCTION
// ============================================================================

/**
 * @brief Main function - ORB feature detection test program
 * @param argc Number of command line arguments
 * @param argv Array of command line arguments
 * @return 0 on success
 */
int main(int argc, char const *argv[]) {
  // ========================================================================
  // COMMAND LINE ARGUMENT PROCESSING
  // ========================================================================

  if (argc < 2) {
    std::cerr << "Usage: " << argv[0]
              << " <image_path> [positive_threshold] [negative_threshold]"
              << std::endl;
    std::cerr << "  image_path: Path to input image file" << std::endl;
    std::cerr << "  positive_threshold: FAST corner detection positive "
                 "threshold (default: 15)"
              << std::endl;
    std::cerr << "  negative_threshold: FAST corner detection negative "
                 "threshold (default: -15)"
              << std::endl;
    return 1;
  }

  // Parse optional threshold parameters
  if (argc >= 4) {
    char *endptr = nullptr;
    corner_thresh = static_cast<int32_t>(strtol(argv[2], &endptr, 10));
    corner_thresh_n = static_cast<int32_t>(strtol(argv[3], &endptr, 10));

    std::cout << "Using custom thresholds: positive=" << corner_thresh
              << ", negative=" << corner_thresh_n << std::endl;
  }

  // ========================================================================
  // PLATFORM INITIALIZATION
  // ========================================================================

  std::cout << "Initializing FPGA platform..." << std::endl;
  platform_t platform = init_platform();

  // Reset the FPGA accelerator
  _reset_ptr[0] = 0;

  // ========================================================================
  // MEMORY INITIALIZATION
  // ========================================================================

  std::cout << "Initializing feature memory buffers..." << std::endl;

  // Clear feature descriptor memory
  for (int i = 0; i < FEAT_MEM_LINES - 1; i++) {
    // Clear descriptor data (2 sections, 4 components each)
    for (int section = 1; section >= 0; section--) {
      for (int component = 3; component >= 0; component--) {
        _descripts_ptr[section][i * 4 + component] = 0;
      }
    }
    // Clear position data
    _descripts_pos_ptr[i] = 0;
  }

  // ========================================================================
  // IMAGE PROCESSING
  // ========================================================================

  std::string imagePath = argv[1];
  uint32_t index = 1;  // Buffer index starts at 1 (0 reserved for control)
  u32 index_offset = 0;

  std::cout << "Processing image: " << imagePath << std::endl;

  int result = process_frame(imagePath, &index, &index_offset);

  if (result == 0) {
    std::cout << "Image processing completed successfully." << std::endl;
  } else {
    std::cerr << "Error processing image." << std::endl;
  }

  return result;
}

int process_frame(std::string imagePath, uint32_t *index, u32 *index_offset) {
  // ========================================================================
  // IMAGE LOADING AND VALIDATION
  // ========================================================================
  cv::Mat grayImage = cv::imread(imagePath, cv::IMREAD_GRAYSCALE);
  cv::Mat coloredImage = cv::imread(imagePath, cv::IMREAD_COLOR);

  if (grayImage.empty()) {
    std::cerr << "Could not read the image: " << imagePath << std::endl;
    return 1;
  }

  // ========================================================================
  // VARIABLE INITIALIZATION
  // ========================================================================

  // Pixel processing variables
  int pos = 0;           // Position in current memory line (0-7)
  uint64_t pix = 0;      // Current pixel value
  u64 mem_line = 0;      // 64-bit memory line (8 pixels)
  u32 mem_line_32b = 0;  // 32-bit memory line for feature data
  int y = 0, x = 0;      // Image coordinates

  // Timing measurement
  auto start = std::chrono::high_resolution_clock::now();
  auto stop = std::chrono::high_resolution_clock::now();
  auto timer =
      std::chrono::duration_cast<std::chrono::microseconds>(stop - stop);

  // DMA instruction (declared but not used in current version)
  dma_instr_t instruction;

  // Feature descriptor parsing variables
  uint16_t descriptor_pos_x[2] = {0};
  uint16_t descriptor_pos_y[2] = {0};
  uint16_t descriptor_score[2] = {0};
  uint16_t descriptor_angle[2] = {0};
  uint16_t descriptor_quadrant[2] = {0};
  uint16_t descriptor_theta[2] = {0};
  uint16_t descriptor_scale[2] = {0};
  float descriptor_orientation[2] = {0};
  uint32_t partial_descriptor = 0;

  // Unused variables (kept for compatibility)
  float offset = 0;
  float invert = 0;
  int extra = 0;

  // ========================================================================
  // FPGA HARDWARE INITIALIZATION SEQUENCE
  // ========================================================================

  // Initialize input buffer
  _in_buffer[0] = 0;

  // FPGA reset sequence
  _reset_ptr[0] = 0;  // Reset low
  *index = 1;         // Reset buffer index to 1
  _reset_ptr[0] = 1;  // Reset high (activate)
  // Frame memory initialization - FPGA BRAM clear
  for (int i = 0; i < (MEM_SIZE_PIX / MEM_LINE_SIZE_PIX); i++) {
    _bram_ptr[i] = 0;
  }

  // Configure ORB corner detection thresholds
  _corner_thresh_ptr[0] = static_cast<uint64_t>(corner_thresh);
  _corner_thresh_ptr[1] = static_cast<uint64_t>(corner_thresh_n);

  // ========================================================================
  // PIXEL STREAMING TO FPGA
  // ========================================================================

  // Stream image pixels to FPGA in 8-pixel chunks
  for (y = 0; y < NUM_LINES; y++) {
    for (x = 0; x < LINE_SIZE; x++) {
      // Extract pixel value
      pix = static_cast<uint64_t>(grayImage.at<uchar>(y, x));

      // Pack pixel into memory line (8 pixels per 64-bit word)
      mem_line |= (pix & 0xFF) << (pos * 8);

      if (pos < 7) {
        pos++;
      } else {
        pos = 0;

        // Write to both input buffer and BRAM simultaneously
        _in_buffer[*index] = mem_line;
        _bram_ptr[*index] = mem_line;
        mem_line = 0;
        ++*index;

        // Check if buffer is full and trigger FPGA processing
        if (*index == MEM_SIZE_PIX / MEM_LINE_SIZE_PIX + 1) {
          // Brief delay before triggering FPGA
          usleep(100);

          // FPGA TRIGGER SEQUENCE
          start = std::chrono::high_resolution_clock::now();
          _bram_ptr[0] = 1;            // Trigger FPGA processing
          while (_bram_ptr[0] == 1) {  // Wait for completion
                                       // FPGA sets this to 0 when done
          }
          stop = std::chrono::high_resolution_clock::now();
          timer += std::chrono::duration_cast<std::chrono::microseconds>(stop -
                                                                         start);

          *index = 1;  // Reset buffer index
        }
      }
    }
  }

  // Handle any remaining data in buffer
  if (_bram_ptr[0] == 0) {
    start = std::chrono::high_resolution_clock::now();
    _bram_ptr[0] = 1;            // Final trigger
    while (_bram_ptr[0] == 1) {  // Wait for completion
                                 // FPGA processing final batch
    }
    stop = std::chrono::high_resolution_clock::now();
    timer +=
        std::chrono::duration_cast<std::chrono::microseconds>(stop - start);
  }

  // Wait for all FPGA operations to complete
  usleep(10000);

  // ========================================================================
  // IMAGE NORMALIZATION FOR VISUALIZATION
  // ========================================================================

  // Find intensity range for normalization
  int minValue = 255, maxValue = 0;
  for (int y = 0; y < NUM_LINES; ++y) {
    for (int x = 0; x < LINE_SIZE; ++x) {
      int pixelValue = static_cast<int>(grayImage.at<uchar>(y, x));
      minValue = std::min(minValue, pixelValue);
      maxValue = std::max(maxValue, pixelValue);
    }
  }

  // Handle edge case: uniform intensity
  if (minValue == maxValue) {
    minValue = 0;
    maxValue = 255;
  }

  // Normalize and create base visualization image
  for (int y = 0; y < NUM_LINES; ++y) {
    for (int x = 0; x < LINE_SIZE; ++x) {
      int pixelValue = static_cast<int>(grayImage.at<uchar>(y, x));
      uchar normalizedValue = static_cast<uchar>(255 * (pixelValue - minValue) /
                                                 (maxValue - minValue));
      coloredImage.at<cv::Vec3b>(y, x) =
          cv::Vec3b(normalizedValue, normalizedValue, normalizedValue);
    }
  }

  // ========================================================================
  // FEATURE DESCRIPTOR EXTRACTION FROM FPGA MEMORY
  // ========================================================================

  int descriptor_count = 0;

  // Read feature descriptors from FPGA memory
  // sequence
  for (int i = 0; i < FEAT_MEM_LINES - 1; i++) {
    // Read position data from FPGA memory
    mem_line_32b = _descripts_pos_ptr[i];
    if (mem_line_32b == 0) {
      break;  // End of valid features
    }

    descriptor_count++;

    // Extract position coordinates (Y:upper 16 bits, X:lower 16 bits)
    descriptor_pos_y[0] =
        static_cast<uint16_t>((0xFFFF0000 & mem_line_32b) >> 16);
    descriptor_pos_x[0] = static_cast<uint16_t>((0x0000FFFF & mem_line_32b));

    // Read score and angle data from FPGA memory
    mem_line_32b = _descripts_scr_angle_ptr[i];
    descriptor_score[0] =
        static_cast<uint16_t>((0x0FFF0000 & mem_line_32b) >> 16);
    descriptor_angle[0] = static_cast<uint16_t>((0x0000FFFF & mem_line_32b));
    descriptor_theta[0] = static_cast<uint16_t>((0x00000003 & mem_line_32b));
    descriptor_quadrant[0] =
        static_cast<uint16_t>((0x0000000C & mem_line_32b) >> 2);
    descriptor_scale[0] =
        static_cast<uint16_t>((0xC0000000 & mem_line_32b) >> 30);

    // Calculate feature orientation
    descriptor_orientation[0] =
        get_orientation(descriptor_quadrant[0], descriptor_theta[0]);

    // Display feature information
    std::cout << std::dec << "(" << descriptor_pos_y[0] << ","
              << descriptor_pos_x[0] << ") "
              << "score:" << descriptor_score[0]
              << " orientation:" << descriptor_orientation[0]
              << "° quadrant: " << descriptor_quadrant[0]
              << " theta: " << descriptor_theta[0]
              << " scale: " << descriptor_scale[0] << std::endl;

    // Display binary descriptor data
    for (int section = 1; section >= 0; section--) {
      for (int component = 3; component >= 0; component--) {
        partial_descriptor =
            static_cast<uint32_t>(_descripts_ptr[section][i * 4 + component]);
        std::cout << std::hex << std::setw(8) << std::setfill('0')
                  << partial_descriptor;
      }
    }
    std::cout << std::dec << std::endl;  // Reset to decimal

    // Mark feature locations in visualization (green dots)
    // Note: Only descriptor_pos_y[0] and descriptor_pos_x[0] are valid
    if (descriptor_pos_y[0] < NUM_LINES && descriptor_pos_x[0] < LINE_SIZE) {
      coloredImage.at<cv::Vec3b>(descriptor_pos_y[0], descriptor_pos_x[0]) =
          cv::Vec3b(0, 255, 0);
    }
    // descriptor_pos_y[1] and descriptor_pos_x[1] are not set, so skip them
  }

  // ========================================================================
  // OUTPUT GENERATION
  // ========================================================================

  // Generate descriptive filename
  std::string out_filename = "features_image" + std::to_string(corner_thresh) +
                             "[" + std::to_string(descriptor_count) + "]" +
                             ".bmp";

  // Save annotated image
  cv::imwrite(out_filename, coloredImage);

  std::cout << "Found " << descriptor_count << " features" << std::endl;
  std::cout << "Output saved as: " << out_filename << std::endl;

  return 0;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * @brief Convert FPGA quadrant and theta values to orientation angle
 *
 * The FPGA ORB implementation encodes feature orientation using:
 * - quadrant: Which 90-degree quadrant (0-3)
 * - theta: Fine angle within the quadrant
 *
 * This function reconstructs the full orientation angle in degrees.
 * Formula: theta * (90/4) - (90/4/2) = theta * 22.5 - 11.25
 *
 * @param quadrant Quadrant identifier (0-3)
 * @param theta Theta value within the quadrant
 * @return Orientation angle in degrees (0-360)
 */
float get_orientation(uint16_t quadrant, uint16_t theta) {
  float invert = 1;
  float offset = 0;
  float degree = 0;

  switch (quadrant) {
    case 0:
      offset = 0;
      invert = 1;
      break;
    case 1:
      offset = 180;
      invert = -1;
      break;
    case 2:
      offset = 180;
      invert = 1;
      break;
    case 3:
      offset = 360;
      invert = -1;
      break;
    default:
      offset = 0;
      invert = 1;
      break;
  }

  // Convert theta to degrees within quadrant
  degree = static_cast<float>(theta * 90 / 4 - 90 / 4 / 2);

  // Apply quadrant transformation
  return static_cast<float>(degree * invert + offset);
}
