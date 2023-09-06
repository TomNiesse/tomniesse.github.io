#!/bin/bash

# Delete any previous tmp folders
sudo rm -rf tmp target_mnt source_mnt

# Build u-boot
cd u-boot/ && make -j`nproc` && make dtbs -j`nproc` && cd ..
cp u-boot/u-boot-sunxi-with-spl.bin genimage_input/
cp u-boot/arch/arm/dts/sun5i-a13-q8-tablet.dtb genimage_input/

# Build linux
cd linux-sunxi-5.8/ && make -j`nproc` && cd ..
cp linux-sunxi-5.8/arch/arm/boot/zImage genimage_input/

# Configure U-boot (boot.scr)
mkimage -C none -A arm -T script -d genimage_input/boot.txt genimage_input/boot.scr

# Create empty rootfs partition
sudo dd if=/dev/zero of=genimage_input/rootfs.ext4 bs=1MiB count=14500
sudo mkfs.ext4 genimage_input/rootfs.ext4

# Create image
genimage/genimage --inputpath genimage_input/ --rootpath genimage_input/ --outputpath genimage_output/ --config genimage.cfg

# Mount `sdcard.img` to make some changes to it
echo "Installing kernel modules"
SYSTEM_IMAGE=`sudo losetup -Pf genimage_output/sdcard.img --show`
echo $SYSTEM_IMAGE
mkdir ./target_mnt
sudo mount `echo "${SYSTEM_IMAGE}p2"` ./target_mnt

# Extract rootfs tar file
echo "Extracting rootfs to image"
SOURCE_IMAGE=`sudo losetup -Pf genimage_input/kali_armhf.img --show`
mkdir source_mnt
sudo mount `echo "${SOURCE_IMAGE}p2"` ./source_mnt
sudo cp -rav --preserve=all source_mnt/* target_mnt/
sudo chown root:root target_mnt/* -R
sudo chmod 777 target_mnt/* -R
sudo umount ./source_mnt -l

# Install kernel modules
cd linux-sunxi-5.8 && sudo INSTALL_MOD_PATH=../target_mnt/ ARCH=arm CROSS_COMPILE=/home/tom/x-tools/arm-cortex_a8-linux-gnueabi/bin/arm-cortex_a8-linux-gnueabi- make modules_install && cd ..

# Install touch screen firmware
sudo mkdir ./target_mnt/lib/firmware/silead/
sudo cp ./genimage_input/gsl1680.fw ./target_mnt/lib/firmware/silead/

# Install touchscreen calibration
sudo cp ./genimage_input/99-touchscreen.conf ./target_mnt/etc/X11/xorg.conf.d/

# Patch `/etc/fstab` (`sdcard.img` does not contain partition names, nor does it support initrd magic)
echo "/dev/mmcblk0p2     /               ext4  discard,noatime,x-systemd.growfs  0  1" | sudo tee ./target_mnt/etc/fstab

# Check if init is valid
sudo file ./target_mnt/sbin/init
sudo file ./target_mnt/`readlink -f ./target_mnt/sbin/init`

# Unmount the `sdcard.img`
sudo umount ./target_mnt -l
sudo losetup -D
sudo rm -rf ./target_mnt
