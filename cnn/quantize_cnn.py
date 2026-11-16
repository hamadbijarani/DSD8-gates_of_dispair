#!/usr/bin/env python3
"""Quantise the trained float CNN to int8 with power-of-two requantisation.

Mirrors nn/quantize.py's approach: symmetric per-tensor weights (clip +-127),
bias folded into the weight tensor (entering the MAC as virtual activation
127), and a shift grid-search per layer that minimises the MSE between the
integer accumulator and the float activation pattern rescaled to int8.

Scale convention (the part that must stay consistent end to end):
  - inputs are x_norm = x/16 in 0..1, quantised x_q = round(x_norm*127), so a
    virtual activation 127 corresponds to float input 1.0;
  - every float target is expressed in the model's own units (conv on 0..1
    inputs, biases as trained) and scaled to fill int8 before the shift search;
  - an activation of float size A is represented by int value A*127/D with D
    the calibration max of that tensor, so the NEXT layer reconstructs float
    units as int*D/127 - that reconstruction is what its targets are built on;
  - a bias on activations of scale D folds as qsym(b, D*max|w|/127).

The layers are chained in the integer domain: conv is quantised first, the
int conv+ReLU+pool outputs (via cnn_ref, bit-exact with the RTL) become the
FC inputs, then FC is quantised. Prints float vs int test accuracy.

Outputs cnn/data/weights_q.json:
  nk, k, conv_shift, fc_shift, conv_w[nk][10], fc_w[K][37],
  samples[{id, x[64] 0..127, y}]  (the test set, quantised inputs)
"""
import json
import pathlib

import numpy as np

import cnn_ref

ROOT = pathlib.Path(__file__).resolve().parent
DATA = ROOT / "data"
NK, K = 4, 4
PIX_MAX = 16.0        # MNIST digits 0-3 rescaled to 0..16


def qsym(w, scale):
    return np.clip(np.round(w / scale), -127, 127).astype(int)


def best_shift(acc, target):
    best, best_err = 0, None
    for sh in range(16):
        q = np.clip(acc >> sh, -128, 127)
        err = float(((q - target) ** 2).mean())
        if best_err is None or err < best_err:
            best, best_err = sh, err
    return best


def windows(x_int):
    """(N,64) int bytes 0..127 -> (N,36,9) float windows in 0..1 units."""
    n = x_int.shape[0]
    x2d = x_int.reshape(n, 8, 8)
    return np.stack([x2d[:, r:r + 3, c:c + 3].reshape(n, 9)
                     for r in range(6) for c in range(6)], axis=1) / 127.0


def pool4(maps):
    """(N,4,6,6) -> (N,4,9) 2x2 max."""
    n = maps.shape[0]
    return maps.reshape(n, NK, 3, 2, 3, 2).max(axis=(3, 5)).reshape(n, NK * 9)


def main():
    m = np.load(DATA / "model_float.npz")
    w1, b1, w2, b2 = m["w1"].reshape(NK, 9), m["b1"], m["w2"], m["b2"]
    xte, yte = m["xte"], m["yte"]
    n = xte.shape[0]

    # ---- inputs: x/16 in 0..1 -> int8 0..127 ----
    xq = np.clip(np.round(xte / PIX_MAX * 127), 0, 127).astype(int).reshape(-1, 64)

    # ---- conv layer: weights quantised, targets in model units ----
    scale1 = float(np.abs(w1).max()) / 127.0
    cw = qsym(w1, scale1)
    cb = qsym(b1, scale1)          # virtual activation 127 <-> float input 1.0
    conv_w = [[int(v) for v in list(cw[k]) + [int(cb[k])]] for k in range(NK)]

    win = windows(xq)                              # (N,36,9) float, 0..1 units
    conv_std = np.einsum("kp,nwp->nkw", w1, win) + b1[None, :, None]  # (N,4,36)
    p_std = pool4(np.maximum(conv_std, 0.0))       # (N,36) float, 0..1 units
    d1 = float(p_std.max()) * 1.02                 # activation calib scale
    target1 = np.clip(np.round(conv_std * 127.0 / d1), -128, 127).astype(int)

    # exact 24-bit accumulators, bit-exact with the hardware MAC chain
    accs1 = np.empty((n, NK, 36), dtype=np.int64)
    for i in range(n):
        x = [int(v) for v in xq[i]]
        for k in range(NK):
            w = conv_w[k]
            for r in range(6):
                for c in range(6):
                    acc = 0
                    for u in range(3):
                        for v in range(3):
                            acc = cnn_ref.s24(
                                acc + x[(r + u) * 8 + (c + v)] * w[u * 3 + v])
                    accs1[i, k, r * 6 + c] = cnn_ref.s24(acc + 127 * w[9])
    conv_shift = best_shift(accs1.reshape(n, -1), target1.reshape(n, -1))

    # int conv+ReLU chained bit-exactly, then int pooling -> FC inputs
    model1 = {"nk": NK, "k": K, "conv_shift": conv_shift, "fc_shift": 0,
              "conv_w": conv_w, "fc_w": [[0] * 37] * K}
    feats_int = np.empty((n, NK * 9), dtype=np.int64)
    for i in range(n):
        x = [int(v) for v in xq[i]]
        feats_int[i] = cnn_ref.pool(cnn_ref.conv_relu(model1, x), NK)

    # ---- FC layer: reconstruct model units from the int features ----
    a_rec = feats_int * (d1 / 127.0)               # (N,36) approx float feats
    of2 = a_rec @ w2.T + b2                        # float logits, model units
    d2 = float(np.abs(of2).max())
    target2 = np.clip(np.round(of2 * 127.0 / d2), -128, 127).astype(int)

    scale2 = float(np.abs(w2).max()) / 127.0
    fw = qsym(w2, scale2)
    fb = qsym(b2, d1 * scale2)      # bias on activations of scale d1
    fc_w = [[int(v) for v in list(fw[c]) + [int(fb[c])]] for c in range(K)]

    accs2 = np.empty((n, K), dtype=np.int64)
    for i in range(n):
        feat = [int(v) for v in feats_int[i]]
        for c in range(K):
            w = fc_w[c]
            acc = 0
            for f in range(len(feat)):
                acc = cnn_ref.s24(acc + feat[f] * w[f])
            accs2[i, c] = cnn_ref.s24(acc + 127 * w[36])
    fc_shift = best_shift(accs2, target2)

    # ---- end-to-end integer accuracy ----
    model2 = {"nk": NK, "k": K, "conv_shift": conv_shift, "fc_shift": fc_shift,
              "conv_w": conv_w, "fc_w": fc_w}
    correct = sum(cnn_ref.infer(model2, [int(v) for v in xq[i]]) == int(yte[i])
                  for i in range(n))
    int_acc = correct / n

    def float_acc():
        # float pipeline on the raw float images end to end
        xf = xte.reshape(n, 8, 8) / PIX_MAX
        winf = np.stack([xf[:, r:r + 3, c:c + 3].reshape(n, 9)
                         for r in range(6) for c in range(6)], axis=1)
        convf = np.einsum("kp,nwp->nkw", w1, winf) + b1[None, :, None]
        h = pool4(np.maximum(convf, 0.0))
        return float(((h @ w2.T + b2).argmax(axis=1) == yte).mean())

    print(f"float test acc: {float_acc():.3f}   int8 test acc: {int_acc:.3f}")
    print(f"conv_shift: {conv_shift}   fc_shift: {fc_shift}   "
          f"d1: {d1:.3f}   d2: {d2:.3f}")

    samples = [{"id": f"s{i:02d}", "x": [int(v) for v in xq[i]], "y": int(yte[i])}
               for i in range(n)]
    out = {"nk": NK, "k": K, "conv_shift": int(conv_shift), "fc_shift": int(fc_shift),
           "conv_w": conv_w, "fc_w": fc_w, "samples": samples}
    (DATA / "weights_q.json").write_text(json.dumps(out, indent=1))
    print(f"wrote {DATA / 'weights_q.json'} ({n} test samples)")


if __name__ == "__main__":
    main()
