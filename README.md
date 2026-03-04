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

# Current issues :

When trying to insert the driver, I get the following error :
```bash
sudo insmod coyote_driver.ko
insmod: ERROR: could not insert module coyote_driver.ko: Invalid module format
```