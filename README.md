# Bytestream Decoding - Coyote

FPGA bytestream decoder running on the V80 via the [Coyote](https://github.com/fpgasystems/Coyote) framework.

## Project Structure

```
bytestream_decoding_coyote/
├── design_1/              # Original XRT design ported for Coyote (32-bit output, 250 MHz)
│   ├── assets/            # ILA measurement files (.csv, .vcd, .ila)
│   ├── hw/                # VHDL logic + SystemVerilog top, CMakeLists.txt
│   └── sw/                # Host code, CMakeLists.txt
├── design_2/              # 128-bit output variant, 400 MHz clock
│   ├── hw/                # CMakeLists.txt
│   └── sw/                # CMakeLists.txt
├── docs/
│   └── notes.md           # Build steps, encountered issues, and ILA results
├── scripts/
│   └── ila_utilization.py # Reads ILA measurements and computes duty cycles
└── test_files/            # Test data consumed by the host program
    ├── Uncompressed_data_LAR_only.raw
    ├── Uncompressed_data.raw
    └── initial_correction_values.bin
```

### Designs

| Design | Input | Output | Clock |
|--------|-------|--------|-------|
| design_1 | 32 bits | 32 bits | 250 MHz |
| design_2 | 32 bits | 128 bits | 400 MHz |

**design_1** is a direct port of the original XRT design to the Coyote framework.

**design_2** widens the output bus to 128 bits and targets 400 MHz, defined in the CMake configuration.

## Prerequisites

- **Coyote** — clone the repo:
  ```bash
  git clone --recurse-submodules https://github.com/fpgasystems/Coyote
  ```

- **Vivado 2024.2** — source the correct settings for the V80 before building:
  ```bash
  source /tools/Xilinx/Vivado/2024.2/.settings64-Vivado.sh
  ```

- Edit `env.sh` at the repo root to point to your local Coyote clone, then source it.
  ```bash
  source env.sh
  ```

## Build instructions

### Build V80 hardware design
```bash
cd design_1/hw
mkdir build_hw && cd build_hw                
cmake ../ -DFDEV_NAME=v80
make project && make bitgen
```

### Build host software
```bash
cd design_1/sw
mkdir build && cd build                
cmake ../
make
```

### Build Coyote driver
```bash
cd $COYOTE_DIR/driver
make TARGET_PLATFORM=versal
```

## Setup and Test instructions

1. Program the FPGA using the generated bitstream.
	
	To do this, first launch vivado :
	```bash
	ssh -X user@Server_ip
	vivado
	```

	Connect to the board using the hardware manager and program the board using the generated ``design_1/hw/build_hw/bitstreams/cyt_top.pdi``.

2. Rescan the PCIe device. In our case, the V80 PCIe address is ``0000:e1:00.0``
	```bash
	sudo sh -c "echo 1 > /sys/bus/pci/devices/0000:e1:00.0/remove "
	sudo sh -c "echo 1 > /sys/bus/pci/rescan "
	```

3. Load the Coyote driver.
	```bash
	cd $COYOTE_DIR/driver/build
	sudo insmod coyote_driver.ko
	```

	You need to check if the driver has been loaded correctly with ``dmesg``, the last printed message should be ``probe returning 0``.

	If you are facing an issue during the driver loading, you may need to do reboot of the host machine.

4. Test with the host program.
	```bash
	cd design_1/sw/build
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