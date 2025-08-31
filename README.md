# ORB-Accelerator
Hardware-accelerated ORB (Oriented FAST and Rotated BRIEF) feature detection implementation for the Zybo Z7-20 FPGA platform.

## Overview
This project provides a complete FPGA-based ORB feature detection accelerator, including:
- HDL implementation of FAST corner detection
- BRIEF descriptor computation hardware
- DMA interface for high-speed data transfer
- PetaLinux software integration
- Testing and demonstration code

## Generate Demo Vivado Project

The following command generates a Vivado 2020.2 project that implements the ORB Accelerator on the Zybo Z7-20. **Note: Only Vivado 2020.2 is guaranteed to work with this project.**

```bash
# Generates the Vivado project
./create_project.sh
```

## Project Structure

- `hdl/` - Hardware description files (VHDL/Verilog)
  - `FAST/` - FAST corner detection implementation
  - `BRIEF/` - BRIEF descriptor computation
  - `ORB/` - Top-level ORB accelerator integration
- `src/` - Software test code and PetaLinux integration
- `create_project.sh` - Vivado project generation script
- `ORB_sample_bd.tcl` - Block design TCL script

## Testing the Accelerator

We provide complete software to test the ORB accelerator. The testing program:
- Loads user-provided images (640x480) to the FPGA fabric
- Streams pixels to the hardware accelerator
- Extracts and displays detected features
- Exports annotated images with detected features

**Important**: Processing includes CPU-based preprocessing overhead. Direct hardware streaming provides significantly better performance.

For detailed testing instructions, refer to the README file in the `src/` directory.

## Requirements

- **FPGA**: Zybo Z7-20 development board
- **Software**: Vivado 2020.2 (other versions not guaranteed to work)
- **OS**: PetaLinux with OpenCV library
- **Images**: 640x480 pixel test images (user-provided)

## Citation

If you use this work in your research, please cite our paper:

```bibtex
@article{costa2025realtime,
  title={Real-Time ORB Accelerator for Embedded FPGA-Based SoCs With ROS Integration},
  author={A. Costa and J. D. Lopes and P. Tom{\'a}s and N. Roma and N. Neves},
  journal={IEEE Transactions on Very Large Scale Integration (VLSI) Systems},
  pages={1--10},
  year={2025},
  doi={10.1109/TVLSI.2025.3601802},
  issn={1557-9999}
}
```
