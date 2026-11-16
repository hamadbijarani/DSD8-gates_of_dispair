#!/usr/bin/env python3
"""Bit-exact integer reference for the DSD-8 CNN flow (source of truth).

Layers: conv 3x3 (ReLU via LUT bank 0) -> max-pool 2x2 -> FC (bias folded as
virtual activation 127, logits via LUT bank 2 offset-binary -> unsigned argmax).

Mirrors rtl/nn_accel.v + nn_mac_pipe.v + nn_act.v exactly: one 24-bit wrapped
accumulator per output value (s24), requantisation sat8(acc >>> shift), and the
same LUT tables as the MLP flow (imported from nn/nn_ref.py so the two flows
can never drift). Inputs are 8x8 bytes in 0..127 (all-nonnegative int8), so
zero-skip applies to every zero byte the same way the hardware counts it.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / "nn"))
import nn_ref  # supplies s24, sat8 and the four LUT banks

s24 = nn_ref.s24
sat8 = nn_ref.sat8
LUT = nn_ref.LUT

IMG = 8          # 8x8 input
CONV_OUT = 6     # 3x3 valid conv on 8x8 -> 6x6
POOL = 2         # 2x2 max-pool -> 3x3 per kernel


def load():
    return json.loads((ROOT / "data" / "weights_q.json").read_text())


def conv_relu(model, x):
    """x: 64 bytes 0..127. Returns nk*36 pooled-input bytes 0..127."""
    nk = model["nk"]
    shift = model["conv_shift"]
    out = []
    for k in range(nk):
        w = model["conv_w"][k]           # 9 weights + bias at index 9
        for r in range(CONV_OUT):
            for c in range(CONV_OUT):
                acc = 0
                for u in range(3):
                    for v in range(3):
                        acc = s24(acc + x[(r + u) * IMG + (c + v)] * w[u * 3 + v])
                acc = s24(acc + 127 * w[9])   # bias folded as activation 127
                q = sat8(acc >> shift)
                out.append(LUT[0][q & 0xFF])  # bank 0 = ReLU
    return out


def pool(maps, nk):
    """2x2 max over unsigned bytes -> nk*3*3 features."""
    feat = []
    for k in range(nk):
        base = k * CONV_OUT * CONV_OUT
        for pr in range(CONV_OUT // POOL):        # 3 pooled rows
            for pc in range(CONV_OUT // POOL):    # 3 pooled cols
                r, c = pr * POOL, pc * POOL
                quad = [maps[base + (r + dr) * CONV_OUT + (c + dc)]
                        for dr in range(POOL) for dc in range(POOL)]
                feat.append(max(quad))
    return feat


def fc(model, feat):
    """feat: nk*9 bytes 0..127. Returns K logit bytes (offset-binary)."""
    k_out = model["k"]
    shift = model["fc_shift"]
    logits = []
    for c in range(k_out):
        w = model["fc_w"][c]             # 36 weights + bias at index 36
        acc = 0
        for f in range(len(feat)):
            acc = s24(acc + feat[f] * w[f])
        acc = s24(acc + 127 * w[len(feat)])  # bias folded as activation 127
        q = sat8(acc >> shift)
        logits.append(LUT[2][q & 0xFF])  # bank 2 = offset-binary
    return logits


def infer(model, x):
    feat = pool(conv_relu(model, x), model["nk"])
    logits = fc(model, feat)
    return max(range(len(logits)), key=lambda c: logits[c])


def selftest():
    """Edge checks of the exact-arithmetic building blocks."""
    assert s24((1 << 23)) == -(1 << 23)          # wrap boundary
    assert sat8(200) == 127 and sat8(-200) == -128
    assert LUT[0][0xFF] == 0 and LUT[0][127] == 127   # ReLU bank on bytes
    assert LUT[2][0x7F] == 0xFF and LUT[2][0xFF] == 0x7F  # offset-binary order
    m = {"nk": 1, "k": 2, "conv_shift": 0, "fc_shift": 0,
         "conv_w": [[1] * 9 + [0]], "fc_w": [[1] * 36 + [0]] * 2}
    x = [127] * 64
    maps = conv_relu(m, x)
    assert maps[0] == 127 and len(maps) == 36        # 9*127 + 0 -> sat8 127
    feat = pool(maps, 1)
    assert feat == [127] * 9
    logits = fc(m, feat)
    assert logits[0] == 0xFF and logits[1] == 0xFF   # sat(36*127)=127 -> ^0x80
    print("cnn_ref selftest: OK")


if __name__ == "__main__":
    selftest()
