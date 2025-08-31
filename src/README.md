# ORB-Petalinux
ORB Accelerator Demo with Petalinux

# Introdution
This sample code loads an ORB accelerator module on the Zybo board, loads an image to the FPGA fabric and reads the feature descriptors extracted by the accelerator writing them to the console and exporting an image with the detected features overlay.

# Using the test code
## Petalinux
This test code is meant for use with a Petalinux image loaded to the Zybo Z7-20. To avoid cross-compiling this application you must include the OpenCV library when generating the Petalinux image.

## Generate FPGA configuration file

Place the design bitstream named `ORB_writeDescriptHold.bit` on the working directory.

Then generate the FPGA configuration file using `bootgen` (install if needed).

```
#chmod +x ./gen_bin-bin.sh
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
#chmod +x ./gen_bin-bin.sh
./load_bitstream.sh

# Execute test code
./test_fast_zybo <image_path> <optional-threshold> <optional-negative_threshold>
```