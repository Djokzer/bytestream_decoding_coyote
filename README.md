# General steps to run Coyote

## Launch Vivado from server : 
```bash
ssh abi@dpnc-tdaq-fpgadev02 -X
source /tools/Xilinx/Vivado/2024.2/settings64.sh
cd /tools/Xilinx/Vivado/2024.2/bin/
./hw_server -d -stcp::3121
vivado
```

## Check PCIe devices : 
```bash
lspci | grep 21:
21:00.0 Processing accelerators: Xilinx Corporation Device 505c
```

## Rescan PCIe devices : 
```bash
sudo sh -c "echo 1 > /sys/bus/pci/devices/0000:21:00.0/remove "
sudo sh -c "echo 1 > /sys/bus/pci/rescan "
```

## Load coyote driver : 
```bash
cd /home/abi/Coyote/driver/build/
sudo insmod coyote_driver.ko
```

# Build steps for V80 :

## Hardware build :
```bash
cd Coyote/examples/01_hello_world/hw
mkdir build_hw && cd build_hw                
cmake ../ -DFDEV_NAME=v80 -DBUILD_STATIC=1 -DBUILD_SHELL=0
make project && make bitgen
```

## Driver build :
```bash
cd Coyote/driver
make TARGET_PLATFORM=versal
```

# Encountered issues :

## Invalid module format error - FIXED

When trying to insert the driver, I get the following error :
```bash
sudo insmod coyote_driver.ko
insmod: ERROR: could not insert module coyote_driver.ko: Invalid module format
```

I tried to recompile the driver and it seems to have fixed the issue.


## Test program crashing - FIXED

When trying to run the test program, I get the following error :
```bash
cd Coyote/examples/01_hello_world/sw/build_sw
./test

-- CLI PARAMETERS:
-----------------------------------------------
Enable hugepages: 1
Enable mapped pages: 1
Data stream: HOST
Number of test runs: 50
Starting transfer size: 64
Ending transfer size: 4194304

terminate called after throwing an instance of 'std::runtime_error'
  what():  ERROR: cThread instance could not be obtained, vfid: 0
Aborted (core dumped)
```

Driver not correctly loaded.
After programming the fpga need to do a correct rescan of the PCIe devices. For this we need to force a remove of the device and then rescan the PCIe bus. The following commands should be used :
```bash
sudo sh -c "echo 1 > /sys/bus/pci/devices/0000:21:00.0/remove "
sudo sh -c "echo 1 > /sys/bus/pci/rescan "
```

## Test program blocking - FIXED

When trying to run the test program, It gets stucked during the transfers.

It was fixed by enabling the IOMMU in the grub boot args :
```bash
GRUB_CMDLINE_LINUX_DEFAULT="default_hugepagesz=2M hugepagesz=2M hugepages=2048 amd_iommu=on iommu=pt"
```

## Driver loading error with V80 - FIXED

When trying to load the driver, I get an error with MSI-X.

There is a pci=realloc option : 
```bash
pci=
  realloc=        Enable/disable reallocating PCI bridge resources
                  if allocations done by BIOS are too small to
                  accommodate resources required by all child
                  devices.
                  off: Turn realloc off
                  on: Turn realloc on
```

Tried to change grub default : 
```bash
GRUB_CMDLINE_LINUX_DEFAULT="default_hugepagesz=2M hugepagesz=2M hugepages=2048 pci=realloc=on amd_iommu=off"
```

And now it works !!
