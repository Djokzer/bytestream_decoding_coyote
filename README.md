# Bytestream Decoding - Coyote

FPGA bytestream decoder running on the Xilinx V80 via the [Coyote](https://github.com/fpgasystems/Coyote) framework.

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

## Build and Setup

