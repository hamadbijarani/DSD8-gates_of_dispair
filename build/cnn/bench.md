# CNN benchmark

Timed region = cycles between the start and end LED markers, 64 test samples, RTL simulation (Icarus).

## NN_POSTED = 0

| Variant | What it is | Mean cycles | Min | Max | Golden instrs | vs b0 | vs b1 |
|---|---|---:|---:|---:|---:|---:|---:|
| b0 | software conv, repeated-addition multiply | 1202307 | 1157739 | 1269487 | 332617 | 1.0x | 0.7x |
| b1 | software conv, shift-and-add multiply | 790545 | 783847 | 798293 | 208913 | 1.5x | 1.0x |
| a0 | accelerator conv, looped, software activation | 59387 | 59321 | 59429 | 14182 | 20.2x | 13.3x |
| a2 | accelerator conv, looped, LUT activation | 57731 | 57697 | 57765 | 13696 | 20.8x | 13.7x |

All runs: RTL trace == golden trace, 0 testbench errors, LEDs == cnn_ref class.
