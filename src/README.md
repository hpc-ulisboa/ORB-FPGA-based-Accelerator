# ORB-Petalinux
ORB Accelerator Demo with Petalinux

## Overview
This sample code demonstrates the hardware-accelerated ORB (Oriented FAST and Rotated BRIEF) feature detection system running on the Zybo Z7-20 FPGA platform. The program:

- Loads an ORB accelerator module onto the FPGA fabric
- Preprocesses images (grayscale conversion) and streams pixels to the hardware accelerator
- Extracts feature descriptors from the accelerator
- Displays detected features in the console
- Exports an annotated image with detected features highlighted

**Note**: Processing time includes CPU-based image preprocessing and loading. Direct hardware streaming (without CPU involvement) provides significantly better performance.

# Using the test code
## Petalinux
This test code is meant for use with a Petalinux image loaded to the Zybo Z7-20. To avoid cross-compiling this application you must include the OpenCV library when generating the Petalinux image.

## Generate FPGA configuration file

Place the design bitstream file in the working directory and rename it to `ORB_writeDescriptHold.bit` (this is the filename expected by the `gen_bit-bin.sh` script). The bitstream should be generated from the Vivado project.

Then generate the FPGA configuration file using `bootgen` (install if needed).

```
#chmod +x ./gen_bit-bin.sh
./gen_bit-bin.sh
```

## Running the test code

To test the ORB accelerator:

- Load the bitstream to the FPGA;
- Run the test code providing the sample image with the correct dimensions and provide optional thresholds for the FAST corner detector (lighter/darker).

This is achieved by running the following commands.

```
# Compile test code
cd src
make
cp test_fast_zybo .

# Load bitstream
#chmod +x ./load_bitstream.sh
./load_bitstream.sh

# Execute test code
./test_fast_zybo <image_path> [positive_threshold] [negative_threshold]
```

### Command Line Arguments
- `image_path`: Path to input image file (must be 640x480 pixels)
- `positive_threshold`: FAST corner detection positive threshold (default: 15)
- `negative_threshold`: FAST corner detection negative threshold (default: -15)

### Example Usage
```bash
# Basic usage with default thresholds
./test_fast_zybo my_image.jpg

# Custom thresholds for more/fewer features
./test_fast_zybo my_image.jpg 20 -20
```

## Expected Output

The program will:
1. Display processing time in microseconds (includes preprocessing overhead)
2. List detected features with coordinates, scores, and orientations
3. Show binary feature descriptors in hexadecimal format
4. Save an output image with green dots marking detected features
5. Print the total number of features found

## Image Requirements

- **Dimensions**: Exactly 640x480 pixels
- **Formats**: Supported OpenCV formats (JPG, PNG, BMP, etc.)
- **Content**: Images with texture, corners, and distinct features work best
- **Source**: Users must provide their own test images
