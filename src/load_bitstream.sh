original_dir=$(pwd)
bitstream="ORB_writeDescriptHold.bit.bin"
cp $bitstream /lib/firmware/
echo 0 > /sys/class/fpga_manager/fpga0/flags
cd /lib/firmware/ ; echo $bitstream > /sys/class/fpga_manager/fpga0/firmware
cd "$original_dir"
