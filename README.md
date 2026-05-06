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

# ILA TESTS

### ILA test with U55C - Example 01_hello_world - When not working

There is a case with the u55c, where when loading the bitstream and the driver it seems to work. But when trying to run the test program, it gets stucked during the transfers.
I tried to check with the ILA and it seems that the transfers are not starting. The ILA is configured to trigger on the receiver valid signal, and it seems that the signal is never going high.

### ILA test with V80 - bytestream_decoding

I've checked the valid signal of the output, and it seems to be at 1 most of the time, there is random moment where it will be at 0 for a clock cycle.
So it seems that the transfer is good, the logic isn't waiting on the host input data.


# Results - V80

## Design 1 - 32 bits input, 32 bits output, 250 MHz

### Host program output :
```bash
./test --raw ../../../test_files/Uncompressed_data_LAR_only.raw --correction ../../../test_files/initial_correction_values.bin 
Raw words loaded: 174736
Expected output cells: 195072  (780288 32-bit words)
Correction stream time: 0.012358 ms
Transfer time:  3.17294 ms

First decoded cells:
0 Gain_and_ID = 0x18180 Energy = -26.2165 Time = 0 Quality_and_Provenence = 0
1 Gain_and_ID = 0x18181 Energy = -5.21647 Time = 0 Quality_and_Provenence = 0
2 Gain_and_ID = 0x18380 Energy = -26.0439 Time = 0 Quality_and_Provenence = 0
3 Gain_and_ID = 0x18381 Energy = -8.04395 Time = 0 Quality_and_Provenence = 0
4 Gain_and_ID = 0x18580 Energy = -0.126187 Time = 0 Quality_and_Provenence = 0
5 Gain_and_ID = 0x18581 Energy = -17.1262 Time = 0 Quality_and_Provenence = 0
6 Gain_and_ID = 0x18780 Energy = -8.16222 Time = 0 Quality_and_Provenence = 0
7 Gain_and_ID = 0x18781 Energy = -10.1622 Time = 0 Quality_and_Provenence = 0
8 Gain_and_ID = 0x18980 Energy = -12.1776 Time = 0 Quality_and_Provenence = 0
9 Gain_and_ID = 0x18981 Energy = -3.17763 Time = 0 Quality_and_Provenence = 0
10 Gain_and_ID = 0x18b80 Energy = -10.0699 Time = 0 Quality_and_Provenence = 0
11 Gain_and_ID = 0x18b81 Energy = -18.0699 Time = 0 Quality_and_Provenence = 0
12 Gain_and_ID = 0x18d80 Energy = -5.03174 Time = 0 Quality_and_Provenence = 0
13 Gain_and_ID = 0x18d81 Energy = 14.9683 Time = 0 Quality_and_Provenence = 0
14 Gain_and_ID = 0x18f80 Energy = 2.90987 Time = 0 Quality_and_Provenence = 0
15 Gain_and_ID = 0x18f81 Energy = -5.09013 Time = 0 Quality_and_Provenence = 0
16 Gain_and_ID = 0x181c0 Energy = 0.931092 Time = 0 Quality_and_Provenence = 0
17 Gain_and_ID = 0x181c1 Energy = 2.93109 Time = 0 Quality_and_Provenence = 0
18 Gain_and_ID = 0x183c0 Energy = -66.1086 Time = 0 Quality_and_Provenence = 0
19 Gain_and_ID = 0x183c1 Energy = -4.10864 Time = 0 Quality_and_Provenence = 0

First cells with non-zero time:
37594 Gain_and_ID = 0x21919 Energy = 300.213 Time = -1.62 Quality_and_Provenence = 0
37596 Gain_and_ID = 0x21b19 Energy = 978.284 Time = 2.19 Quality_and_Provenence = 0
```

### ILA - Valid, Ready duty cycle :
```bash
Total samples: 512  (post-trigger, starting at sample 512)

Signal                High cycles    Ratio
------------------------------------------
  [axis_host_recv[0]]
    tvalid                    512 100.000%
    tready                    107  20.898%

  [axis_host_send[0]]
    tvalid                    512 100.000%
    tready                    512 100.000%
```

## Design 2 - 32 bits input, 128 bits output, 250 MHz

### Host program output :
```bash
./test --raw ../../../test_files/Uncompressed_data_LAR_only.raw --correction ../../../test_files/initial_correction_values.bin 
Raw words loaded: 174736
Expected output cells: 195072
Correction stream time: 0.010726 ms
Transfer time:  0.826564 ms

First decoded cells:
0 Gain_and_ID = 0x18180 Energy = -26.2165 Time = 0 Quality_and_Provenence = 0
1 Gain_and_ID = 0x18181 Energy = -5.21647 Time = 0 Quality_and_Provenence = 0
2 Gain_and_ID = 0x18380 Energy = -26.0439 Time = 0 Quality_and_Provenence = 0
3 Gain_and_ID = 0x18381 Energy = -8.04395 Time = 0 Quality_and_Provenence = 0
4 Gain_and_ID = 0x18580 Energy = -0.126187 Time = 0 Quality_and_Provenence = 0
5 Gain_and_ID = 0x18581 Energy = -17.1262 Time = 0 Quality_and_Provenence = 0
6 Gain_and_ID = 0x18780 Energy = -8.16222 Time = 0 Quality_and_Provenence = 0
7 Gain_and_ID = 0x18781 Energy = -10.1622 Time = 0 Quality_and_Provenence = 0
8 Gain_and_ID = 0x18980 Energy = -12.1776 Time = 0 Quality_and_Provenence = 0
9 Gain_and_ID = 0x18981 Energy = -3.17763 Time = 0 Quality_and_Provenence = 0
10 Gain_and_ID = 0x18b80 Energy = -10.0699 Time = 0 Quality_and_Provenence = 0
11 Gain_and_ID = 0x18b81 Energy = -18.0699 Time = 0 Quality_and_Provenence = 0
12 Gain_and_ID = 0x18d80 Energy = -5.03174 Time = 0 Quality_and_Provenence = 0
13 Gain_and_ID = 0x18d81 Energy = 14.9683 Time = 0 Quality_and_Provenence = 0
14 Gain_and_ID = 0x18f80 Energy = 2.90987 Time = 0 Quality_and_Provenence = 0
15 Gain_and_ID = 0x18f81 Energy = -5.09013 Time = 0 Quality_and_Provenence = 0
16 Gain_and_ID = 0x181c0 Energy = 0.931092 Time = 0 Quality_and_Provenence = 0
17 Gain_and_ID = 0x181c1 Energy = 2.93109 Time = 0 Quality_and_Provenence = 0
18 Gain_and_ID = 0x183c0 Energy = -66.1086 Time = 0 Quality_and_Provenence = 0
19 Gain_and_ID = 0x183c1 Energy = -4.10864 Time = 0 Quality_and_Provenence = 0

First cells with non-zero time:
37594 Gain_and_ID = 0x21919 Energy = 300.213 Time = -1.62 Quality_and_Provenence = 0
37596 Gain_and_ID = 0x21b19 Energy = 978.284 Time = 2.19 Quality_and_Provenence = 0
```

### ILA - Valid, Ready duty cycle :
```bash
Total samples: 512  (post-trigger, starting at sample 512)

Signal                High cycles    Ratio
------------------------------------------
  [axis_host_recv[0]]
    tvalid                    512 100.000%
    tready                    454  88.672%

  [axis_host_send[0]]
    tvalid                    509  99.414%
    tready                    512 100.000%
```

## Design 2 - 32 bits input, 128 bits output, 400 MHz

### Host program output :
```bash
./test --raw ../../../test_files/Uncompressed_data_LAR_only.raw --correction ../../../test_files/initial_correction_values.bin 
Raw words loaded: 174736
Expected output cells: 195072
Correction stream time: 0.010666 ms
Transfer time:  0.823029 ms

First decoded cells:
0 Gain_and_ID = 0x18180 Energy = -26.2165 Time = 0 Quality_and_Provenence = 0
1 Gain_and_ID = 0x18181 Energy = -5.21647 Time = 0 Quality_and_Provenence = 0
2 Gain_and_ID = 0x18380 Energy = -26.0439 Time = 0 Quality_and_Provenence = 0
3 Gain_and_ID = 0x18381 Energy = -8.04395 Time = 0 Quality_and_Provenence = 0
4 Gain_and_ID = 0x18580 Energy = -0.126187 Time = 0 Quality_and_Provenence = 0
5 Gain_and_ID = 0x18581 Energy = -17.1262 Time = 0 Quality_and_Provenence = 0
6 Gain_and_ID = 0x18780 Energy = -8.16222 Time = 0 Quality_and_Provenence = 0
7 Gain_and_ID = 0x18781 Energy = -10.1622 Time = 0 Quality_and_Provenence = 0
8 Gain_and_ID = 0x18980 Energy = -12.1776 Time = 0 Quality_and_Provenence = 0
9 Gain_and_ID = 0x18981 Energy = -3.17763 Time = 0 Quality_and_Provenence = 0
10 Gain_and_ID = 0x18b80 Energy = -10.0699 Time = 0 Quality_and_Provenence = 0
11 Gain_and_ID = 0x18b81 Energy = -18.0699 Time = 0 Quality_and_Provenence = 0
12 Gain_and_ID = 0x18d80 Energy = -5.03174 Time = 0 Quality_and_Provenence = 0
13 Gain_and_ID = 0x18d81 Energy = 14.9683 Time = 0 Quality_and_Provenence = 0
14 Gain_and_ID = 0x18f80 Energy = 2.90987 Time = 0 Quality_and_Provenence = 0
15 Gain_and_ID = 0x18f81 Energy = -5.09013 Time = 0 Quality_and_Provenence = 0
16 Gain_and_ID = 0x181c0 Energy = 0.931092 Time = 0 Quality_and_Provenence = 0
17 Gain_and_ID = 0x181c1 Energy = 2.93109 Time = 0 Quality_and_Provenence = 0
18 Gain_and_ID = 0x183c0 Energy = -66.1086 Time = 0 Quality_and_Provenence = 0
19 Gain_and_ID = 0x183c1 Energy = -4.10864 Time = 0 Quality_and_Provenence = 0

First cells with non-zero time:
37594 Gain_and_ID = 0x21919 Energy = 300.213 Time = -1.62 Quality_and_Provenence = 0
37596 Gain_and_ID = 0x21b19 Energy = 978.284 Time = 2.19 Quality_and_Provenence = 0
```