# General steps to run Coyote

## Launch Vivado hardware server : 
```bash
cd /tools/Xilinx/Vivado/2024.2/bin/
./hw_server -d -stcp::3121
```

## Check PCIe devices : 
```bash
lspci | grep 21:
21:00.0 Processing accelerators: Xilinx Corporation Device 505c
```

## Rescan PCIe devices : 
```bash
sudo sh -c "echo 1 > /sys/bus/pci/rescan "
sudo sh -c "echo 1 > /sys/bus/pci/devices/0000:21:00.0/rescan "
```

## Load coyote driver : 
```bash
cd /home/abi/Coyote/driver/build/
sudo insmod coyote_driver.ko
```

# Encountered issues :

## Invalid module format error - FIXED

When trying to insert the driver, I get the following error :
```bash
sudo insmod coyote_driver.ko
insmod: ERROR: could not insert module coyote_driver.ko: Invalid module format
```

I tried to recompile the driver and it seems to have fixed the issue.


## Test program not working

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