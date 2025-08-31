#include "dma_zcu.h"
#include <chrono>
#include <iomanip>
#include <iostream>
#include <opencv2/opencv.hpp>
#include <stdlib.h>
#include <time.h>

#define LINE_SIZE 640
#define NUM_LINES 480
#define MAX_FEATURES 600
#define FEAT_MEM_LINES 512
#define MEM_SIZE_PIX 65528
#define MEM_LINE_SIZE_PIX 8
#define BURST_SIZE 254

void stream_burst(uint32_t offset, uint32_t burst_size);
int process_frame(std::string imagePath, uint32_t *index, u32 *index_offset);
float get_orientation(uint16_t quadrant, uint16_t theta);

int32_t corner_thresh = 15;
int32_t corner_thresh_n = -15;

int main(int argc, char const *argv[]) {
  if (argc < 2) {
    perror("Usage: ./test_fast_zybo <image_path> | <threshold> <negative "
           "threshol>");
    return 0;
  }
  char *endptr = NULL;
  if (argc == 4) {
    corner_thresh = int32_t(strtol(argv[2], &endptr, 10));
    corner_thresh_n = int32_t(strtol(argv[3], &endptr, 10));
  }
  // Iniciar plataforma
  platform_t platform = init_platform();

  // Escrever no buffer
  // ...
  // Criar instrucao que envia 32bits no output buffer para BRAM
  //printf("Reset1\n");
  //printf("Reset1\n");
  _reset_ptr[0] = 0;
  //printf("Reset2\n");
  /* dma_instr_t instruction;
  dma_create_tx(&instruction, DMA_DRAM_TO_FPGA, INPUT_BUFFER_BASE_ADDR,
                BRAM_BASE_ADDR, OUTPUT_BUFFER_BASE_ADDR, 32, 32);
  // Executar instrucao
  for (int i = 0; i < 32; i++) {
    _in_buffer[i] = 0;
  }
  dma_run(instruction); */
  // Path to the image file
  std::string imagePath = argv[1];
  uint32_t index = 1;
  u32 index_offset = 0;
  for (int i = 0; i < (FEAT_MEM_LINES) - 1; i++) {
    for (int section = 2-1; section >= 0; section--) {
      for (int component = 128/32-1; component >= 0; component--) {
        //printf("Doing %d - \t\t%d\t\t%d\n\n ",i,section,int(i*128/32)+component);
        _descripts_ptr[section][int(i*128/32)+component]=0;
      }
    }
    _descripts_pos_ptr[i] = 0;
  }
  process_frame(imagePath, &index, &index_offset);
  // process_frame(imagePath, &index, &index_offset);
  //  Load the image in grayscale mode directly
}

int process_frame(std::string imagePath, uint32_t *index, u32 *index_offset) {
  cv::Mat grayImage = cv::imread(imagePath, cv::IMREAD_GRAYSCALE);
  cv::Mat coloredImage = cv::imread(imagePath, cv::IMREAD_COLOR);

  if (grayImage.empty()) {
    std::cout << "Could not read the image: " << imagePath << std::endl;
    return 1;
  }
  //printf("Starting1\n");

  int pos = 0;
  uint64_t pix = 0;
  _in_buffer[0] = 0;
  u64 mem_line = 0;
  u32 mem_line_32b = 0;
  _reset_ptr[0] = 0;
  int y = 0;
  int x = 0;
  // While image has not yet been fully loaded
  auto start = std::chrono::high_resolution_clock::now();
  auto stop = std::chrono::high_resolution_clock::now();
  auto timer =
      std::chrono::duration_cast<std::chrono::microseconds>(stop - stop);
  dma_instr_t instruction;
  *index = 1;
  int extra = 0;

  //printf("Starting2\n");
  uint16_t descriptor_pos_x[2] = {0};
  uint16_t descriptor_pos_y[2] = {0};
  uint16_t descriptor_score[2] = {0};
  uint16_t descriptor_angle[2] = {0};
  uint16_t descriptor_quadrant[2] = {0};
  uint16_t descriptor_theta[2] = {0};
  uint16_t descriptor_scale[2] = {0};
  float offset = 0;
  float invert = 0;
  float descriptor_orientation[2] = {0};
  uint32_t partial_descriptor = 0;

  _reset_ptr[0] = 1;
  /* Frame memory initialization */
  //printf("Starting3\n");
  for (int i = 0; i < (MEM_SIZE_PIX / MEM_LINE_SIZE_PIX); i++)
    _bram_ptr[i] = 0;
    //printf("Starting4\n");
  /* --------------------------- */
  /* Feature memory initialization */
  /* for (int i = 0; i < (MAX_FEATURES); i++)
    _features_ptr[i] = 0; */
  /* ------------------------------- */
  //std::cout << "Configuring ORB\n";
  _corner_thresh_ptr[0] = uint64_t(corner_thresh);
  _corner_thresh_ptr[1] = uint64_t(corner_thresh_n);
  //_rgb_rg_ptr[0] = uint64_t(0x0000000100000000);
  //_rgb_rg_ptr[1] = uint64_t(0x0000000100000000);

  //std::cout << "Loading new pixels\n";
  for (y = 0; y < NUM_LINES; y++) {
    for (x = 0; x < LINE_SIZE; x++) {
      pix = static_cast<uint64_t>(grayImage.at<uchar>(y, x));
      // std::cout << std::hex << (pix & 0xFF);
      //_in_buffer[*index] =*index;//|= (pix&0xFF) << (pos * 8);
      /* if (y == 0 && x < 10) {
        std::cout << std::hex << (pix & 0xFF) << " " << pos << "\n";
        std::cout << std::hex << mem_line << " " << pos << "\n";
      } */
      mem_line |= (pix & 0xFF) << (pos * 8);
      if (pos < 7) {
        pos++;
      } else {
        pos = 0;
        /* if (x < 10)
          std::cout << "line: " << y << " " << std::hex << mem_line << "\n"; */
        // Sets input buffer line with 8 new pixel
        _in_buffer[*index] = mem_line;
        _bram_ptr[*index] = mem_line;
        mem_line = 0;
        ++*index;
        if (*index == MEM_SIZE_PIX / MEM_LINE_SIZE_PIX + 1) {

          usleep(100);
          start = std::chrono::high_resolution_clock::now();
          _bram_ptr[0] = 1;
          while (_bram_ptr[0] == 1) {
          }
          stop = std::chrono::high_resolution_clock::now();
          timer += std::chrono::duration_cast<std::chrono::microseconds>(stop -
                                                                         start);
          *index = 1;
        }
      }
    }
  }

  if (_bram_ptr[0] == 0) {
    start = std::chrono::high_resolution_clock::now();
    _bram_ptr[0] = 1;
    while (_bram_ptr[0] == 1) {
    }
    stop = std::chrono::high_resolution_clock::now();
    timer +=
        std::chrono::duration_cast<std::chrono::microseconds>(stop - start);
  }

  //std::cout << "Processed image in " << std::dec << timer.count() << "us\n";

  // Wait for transmission to finish
  usleep(10000);

  // Grayscale image ---------------------------------------
  int minValue = 255, maxValue = 0;
  for (int y = 0; y < NUM_LINES; ++y) {
    for (int x = 0; x < LINE_SIZE; ++x) {
      minValue = std::min(minValue, int(grayImage.at<uchar>(y, x)));
      maxValue = std::max(maxValue, int(grayImage.at<uchar>(y, x)));
    }
  }

  // Handle the case where all values in the patch are the same
  if (minValue == maxValue) {
    minValue = 0;
    maxValue = 255;
  }
  for (int y = 0; y < NUM_LINES; ++y) {
    for (int x = 0; x < LINE_SIZE; ++x) {
      // Normalize the value to be within 0-255
      uchar normalizedValue =
          static_cast<uchar>(255 * (int(grayImage.at<uchar>(y, x)) - minValue) /
                             (maxValue - minValue));

      coloredImage.at<cv::Vec3b>(y, x) =
          cv::Vec3b(normalizedValue, normalizedValue, normalizedValue);
    }
  }
  //-------------------------------------------------------
  //-------------------------------------------------------

  //std::cout << "Descriptors found:\n";
  int descriptor_count = 0;
  for (int i = 0; i < FEAT_MEM_LINES - 1; i++) {
    mem_line_32b = _descripts_pos_ptr[i];
    if (mem_line_32b == 0)
      break;
    descriptor_count += 1;
    descriptor_pos_y[0] = uint16_t((0xFFFF0000 & mem_line_32b) >> 16);
    descriptor_pos_x[0] = uint16_t((0x0000FFFF & mem_line_32b));

    mem_line_32b = _descripts_scr_angle_ptr[i];
    descriptor_score[0] = uint16_t((0x0FFF0000 & mem_line_32b) >> 16);
    descriptor_angle[0] = uint16_t((0x0000FFFF & mem_line_32b));
    descriptor_theta[0] = uint16_t((0x00000003 & mem_line_32b));
    descriptor_quadrant[0] = uint16_t((0x0000000C & mem_line_32b) >> 2);
    descriptor_scale[0] = uint16_t((0xC0000000 & mem_line_32b) >> 30);
    descriptor_orientation[0] =
        get_orientation(descriptor_quadrant[0], descriptor_theta[0]);
    std::cout << std::dec << "(" << descriptor_pos_y[0] << ","
              << descriptor_pos_x[0] << ") "
              << "score:" << descriptor_score[0]
              << " orientation:" << descriptor_orientation[0] << "º quadrant: " 
              << descriptor_quadrant[0] << " theta: " << descriptor_theta[0] << 
              " scale: " << descriptor_scale[0] << "\n";
    for (int section = 1; section >= 0; section--) {
      for (int component = 4-1; component >= 0; component--) {
        partial_descriptor =
            uint32_t((_descripts_ptr[section][int(i*4)+component]));
        std::cout << std::hex << std::setw(8) << std::setfill('0')
                  << partial_descriptor;
      }
    }
    std::cout << "\n";

    coloredImage.at<cv::Vec3b>(descriptor_pos_y[0], descriptor_pos_x[0]) =
        cv::Vec3b(0, 255, 0);
    coloredImage.at<cv::Vec3b>(descriptor_pos_y[1], descriptor_pos_x[1]) =
        cv::Vec3b(0, 255, 0);
  }
  //std::cout << "Found " << std::dec << descriptor_count << " features\n";

  // Save the grayscale image (optional)
  std::string out_filename = "features_image" + std::to_string(corner_thresh) +
                             "[" + std::to_string(descriptor_count) + "]" +
                             ".bmp";

  cv::imwrite(out_filename, coloredImage);

  return 0;
}

void stream_burst(uint32_t offset, uint32_t burst_size) {
  dma_instr_t instruction;
  dma_create_tx(&instruction, DMA_DRAM_TO_FPGA,
                INPUT_BUFFER_BASE_ADDR + (offset * 8),
                BRAM_BASE_ADDR + (offset * 8), OUTPUT_BUFFER_BASE_ADDR,
                burst_size, burst_size);
  // Executar instrucao
  dma_run(instruction);
}

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
  degree=theta*90/4-90/4/2;
  return float(degree * invert + offset);
}