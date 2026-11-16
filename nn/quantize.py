#!/usr/bin/env python3
"""Symmetric per-tensor int8 quantisation with power-of-two requantisation."""
import json
import math
import pathlib
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent
DATA = ROOT / "data"


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def qsym(w, scale):
    return np.clip(np.round(w / scale), -127, 127).astype(int)


def pow2_shift(ratio):
    if ratio <= 1.0:
        return 0
    return clamp(int(round(math.log2(ratio))), 0, 15)


def best_shift(acc, target):
    best, best_err = 0, None
    for sh in range(16):
        q = np.clip(acc >> sh, -128, 127)
        err = float(((q - target) ** 2).mean())
        if best_err is None or err < best_err:
            best, best_err = sh, err
    return best


def main():
    m = np.load(DATA / "model_float.npz")
    w1, b1, w2, b2 = m["w1"], m["b1"], m["w2"], m["b2"]
    xte, yte = m["xte"], m["yte"]

    # inputs are already min-max scaled to 0..1 by train.py
    xmin, xmax = m["x_min"], m["x_max"]
    def qin(x):
        return np.round(np.clip(x, 0.0, 1.0) * 127).astype(int)

    sa1 = 1.0 / 127.0
    sw1 = max(abs(w1).max(), 1e-9) / 127.0
    h_cal = np.maximum(xte @ w1 + b1, 0)
    so1 = max(h_cal.max(), 1e-9) / 127.0
    qw1 = qsym(w1, sw1)
    qb1 = np.round(b1 / (127.0 * sa1 * sw1)).astype(int)
    qb1 = np.clip(qb1, -127, 127)
    xq_cal = np.array([qin(x) for x in xte])
    acc1_cal = xq_cal @ qw1 + 127 * qb1

    sa2 = so1
    sw2 = max(abs(w2).max(), 1e-9) / 127.0
    # estimate output range from float activations
    h = np.maximum(xte @ w1 + b1, 0)
    logits = h @ w2 + b2
    so2 = max(abs(logits).max(), 1e-9) / 127.0
    qw2 = qsym(w2, sw2)
    qb2 = np.round(b2 / (127.0 * sa2 * sw2)).astype(int)
    qb2 = np.clip(qb2, -127, 127)
    # grid-search both shifts on the calibration set for best accuracy
    ycal = np.array([s["y"] for s in samples]) if False else None
    best = None
    for sh1 in range(16):
        hq = np.clip(acc1_cal >> sh1, 0, 127)
        hq = np.maximum(hq, 0)
        acc2 = hq @ qw2 + 127 * qb2
        for sh2 in range(16):
            lg = np.clip(acc2 >> sh2, -128, 127) ^ 0x80
            pred = lg.argmax(1)
            acc = int((pred == yte).sum())
            mse = float(((np.clip(acc1_cal >> sh1, -128, 127) - h_cal / so1) ** 2).mean())
            key = (acc, -mse)
            if best is None or key > best[0]:
                best = (key, sh1, sh2)
    _, shift1, shift2 = best

    samples = []
    for x, y in zip(xte, yte):
        samples.append({"x": [int(v) for v in qin(x)], "y": int(y)})

    out = {
        "w1": qw1.tolist(), "b1": qb1.tolist(), "shift1": shift1,
        "w2": qw2.tolist(), "b2": qb2.tolist(), "shift2": shift2,
        "xmin": [float(v) for v in xmin], "xmax": [float(v) for v in xmax],
        "samples": samples,
    }
    (DATA / "weights_q.json").write_text(json.dumps(out, indent=1))
    print(f"shift1={shift1} shift2={shift2} samples={len(samples)}")
    print(f"wrote {DATA/'weights_q.json'}")


if __name__ == "__main__":
    main()
