# NN accelerator benchmark

Timed region = cycles between the start and end LED markers, 23 Iris test samples, RTL simulation (Icarus).

## NN_POSTED = 0

| Variant | What it is | Mean cycles | Min | Max | vs b0 | vs b1 |
|---|---|---:|---:|---:|---:|---:|
| b0 | software, repeated-addition multiply | 43155 | 41637 | 44678 | 1.0x | 0.6x |
| b1 | software, shift-and-add multiply | 24427 | 24135 | 24654 | 1.8x | 1.0x |
| a0 | accelerator, looped, software activation | 2172 | 2171 | 2175 | 19.9x | 11.2x |
| a2 | accelerator, looped, LUT activation | 2071 | 2071 | 2071 | 20.8x | 11.8x |
| a4 | accelerator, unrolled, LUT activation | 1087 | 1087 | 1087 | 39.7x | 22.5x |

## NN_POSTED = 1

| Variant | What it is | Mean cycles | Min | Max | vs b0 | vs b1 |
|---|---|---:|---:|---:|---:|---:|
| b0 | software, repeated-addition multiply | 43155 | 41637 | 44678 | 1.0x | 0.6x |
| b1 | software, shift-and-add multiply | 24427 | 24135 | 24654 | 1.8x | 1.0x |
| a0 | accelerator, looped, software activation | 2172 | 2171 | 2175 | 19.9x | 11.2x |
| a2 | accelerator, looped, LUT activation | 2071 | 2071 | 2071 | 20.8x | 11.8x |
| a4 | accelerator, unrolled, LUT activation | 1087 | 1087 | 1087 | 39.7x | 22.5x |

All runs: RTL trace == golden trace, 0 testbench errors, LEDs == nn_ref class.
