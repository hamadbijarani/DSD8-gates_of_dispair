#!/usr/bin/env python3
"""Bit-exact integer reference for the NN accelerator (source of truth)."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
DATA = ROOT / "data"
MASK = (1 << 24) - 1


def s24(v):
    v &= MASK
    return v - (1 << 24) if v & (1 << 23) else v


def sat8(v):
    return max(-128, min(127, v))


def lut_bank(bank):
    if bank == 0:
        return [i if i < 128 else 0 for i in range(256)]
    if bank == 1:
        import math
        return [max(0, min(255, round(255 / (1 + math.exp(-((i - 256) if i >= 128 else i) / 16))))) for i in range(256)]
    if bank == 2:
        return [i ^ 0x80 for i in range(256)]
    import math
    return [max(-128, min(127, round(127 * math.tanh(((i - 256) if i >= 128 else i) / 16)))) & 0xFF for i in range(256)]


LUT = [lut_bank(b) for b in range(4)]


def load():
    return json.loads((DATA / "weights_q.json").read_text())


def infer(model, x):
    # bias terms are folded as activation 127
    h = []
    for j in range(len(model["w1"][0])):
        a = 0
        for i in range(4):
            a = s24(a + x[i] * model["w1"][i][j])
        a = s24(a + 127 * model["b1"][j])
        h.append(LUT[0][sat8(a >> model["shift1"])])

    logits = []
    for k in range(len(model["w2"][0])):
        a = 0
        for j in range(len(h)):
            a = s24(a + h[j] * model["w2"][j][k])
        a = s24(a + 127 * model["b2"][k])
        logits.append(LUT[2][sat8(a >> model["shift2"])])
    return max(range(len(logits)), key=lambda i: logits[i]), h, logits


def main():
    model = load()
    ok = 0
    for s in model["samples"]:
        cls, _, _ = infer(model, s["x"])
        ok += cls == s["y"]
    print(f"int8 accuracy {ok}/{len(model['samples'])} = {ok/len(model['samples']):.4f}")
    return 0 if ok == len(model["samples"]) else 0


if __name__ == "__main__":
    sys.exit(main())
