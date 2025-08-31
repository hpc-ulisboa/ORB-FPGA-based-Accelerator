# ORB-Accelerator
Zybo Z7-20 ORB Accelerator

# Generate Demo Vivado project

The following command generates a Vivado (v2020.2) project that implements the ORB Accelerator on the Zybo Z7-20. This project can be used with the sample code in this [repository](https://github.com/hpc-ulisboa/ORB-ROS-Petalinux) for testing purposes.

```
# Generates the example project under the directory orb_acc_demo
./create_project.sh
```

# Testing the accelerator

We provide software to test our ORB accelerator. This testing program loads a provided image (640x480) to the FPGA fabric to stream the pixels to the accelerator. Refer to the README file included in the `src/` directory.