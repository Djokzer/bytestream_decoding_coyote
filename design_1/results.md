# Design 1 - 32 bits input, 32 bits output, 250 MHz

## Host program output :
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

## ILA - Valid, Ready duty cycle :
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