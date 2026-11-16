#!/usr/bin/env python3
"""Train a small float CNN (8x8 input -> 4 conv 3x3 ReLU -> 2x2 maxpool
-> FC 36x4) on MNIST digits 0-3. Deterministic seed, numpy only (no sklearn
in this environment).

The dataset is the first 1024 training images of each digit class 0..3
(4096 total), downsampled 28x28 -> 8x8 by area averaging and rescaled to the
0..16 float range every later stage expects (quantize_cnn.py uses PIX_MAX
16.0, a virtual activation 127 <-> float input 1.0). The test set is the
first 16 test images of each class (64 samples, 16 per class) - exactly the
64 samples that stream through the bench peripheral. MNIST IDX files are
cached under cnn/data/mnist/ and downloaded once from the CVDF mirror on
first use; the shipped model + stream already exist, so retraining (and the
download) is only needed when intentionally regenerating the model.

Outputs cnn/data/model_float.npz:
  w_conv (nk,3,3)  b_conv (nk,)  w_fc (K,36)  b_fc (K,)
  xtr,ytr, xte,yte (float images 0..16, int labels)
Prints train/test accuracy.
"""
import gzip
import pathlib
import struct
import urllib.request

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent
DATA = ROOT / "data"
MN = DATA / "mnist"
SEED = 1234
NK, K = 4, 4
EPOCHS = 300
LR = 0.1
BATCH = 256
PER_TRAIN, PER_TEST = 1024, 16

MIRROR = "https://storage.googleapis.com/cvdf-datasets/mnist/"
IDX_FILES = {
    "tr_im": ("train-images-idx3-ubyte.gz", 0x803, ">IIII", (28, 28)),
    "tr_lb": ("train-labels-idx1-ubyte.gz", 0x801, ">II", None),
    "te_im": ("t10k-images-idx3-ubyte.gz", 0x803, ">IIII", (28, 28)),
    "te_lb": ("t10k-labels-idx1-ubyte.gz", 0x801, ">II", None),
}


def load_idx(key):
    """One cached IDX file, downloading it on first use."""
    fname, magic, head, dims = IDX_FILES[key]
    path = MN / fname
    if not path.exists():
        MN.mkdir(exist_ok=True)
        print(f"downloading {fname} ...")
        urllib.request.urlretrieve(MIRROR + fname, path)
    with gzip.open(path, "rb") as f:
        vals = struct.unpack(head, f.read(struct.calcsize(head)))
        if vals[0] != magic:
            raise ValueError(f"{fname}: bad magic {vals[0]:#x}")
        raw = f.read()
    if dims is None:
        n = vals[1]
        lab = np.frombuffer(raw, dtype=np.uint8)
        if lab.size != n:
            raise ValueError(f"{fname}: {lab.size} labels for count {n}")
        return lab
    n = vals[1]
    if vals[2:] != dims:
        raise ValueError(f"{fname}: unexpected shape {vals[2:]}")
    return np.frombuffer(raw, dtype=np.uint8).reshape(n, *dims)


def area_matrix(n_out, n_in, box):
    """Row i = overlap of output box [i*box,(i+1)*box) with input pixels."""
    w = np.zeros((n_out, n_in))
    for i in range(n_out):
        a, b = i * box, (i + 1) * box
        for j in range(n_in):
            w[i, j] = max(0.0, min(b, j + 1) - max(a, j))
    return w / w.sum(axis=1, keepdims=True)


def downsample8(imgs):
    """(N,28,28) uint8 -> (N,8,8) float64, area average, values 0..16."""
    wr = area_matrix(8, 28, 28 / 8)
    wc = area_matrix(8, 28, 28 / 8)
    x = imgs.astype(np.float64)
    return np.einsum("ij,njk,lk->nil", wr, x, wc) / 255.0 * 16.0


def make_dataset():
    tri, trl, tei, tel = (load_idx(k) for k in ("tr_im", "tr_lb", "te_im", "te_lb"))
    xtr, ytr, xte, yte = [], [], [], []
    for c in range(K):
        itr = np.flatnonzero(trl == c)[:PER_TRAIN]
        ite = np.flatnonzero(tel == c)[:PER_TEST]
        xtr.append(tri[itr])
        ytr.append(np.full(itr.size, c, dtype=int))
        xte.append(tei[ite])
        yte.append(np.full(ite.size, c, dtype=int))
    xtr = downsample8(np.concatenate(xtr))
    ytr = np.concatenate(ytr)
    xte = downsample8(np.concatenate(xte))
    yte = np.concatenate(yte)
    rng = np.random.default_rng(SEED)          # shuffle class blocks together
    order = rng.permutation(xtr.shape[0])
    return xtr[order], ytr[order], xte, yte


def windows(x):
    """(N,64) -> (N,36,9) im2col of all 3x3 valid windows, row-major."""
    n = x.shape[0]
    x = x.reshape(-1, 8, 8)
    out = np.empty((n, 36, 9))
    for r in range(6):
        for c in range(6):
            patch = x[:, r:r + 3, c:c + 3].reshape(n, 9)
            out[:, r * 6 + c, :] = patch
    return out


def forward(params, x):
    w1, b1, w2, b2 = params["w1"], params["b1"], params["w2"], params["b2"]
    n = x.shape[0]
    win = windows(x)                              # (N,36,9)
    conv = np.einsum("kp,nwp->nkw", w1, win) + b1[None, :, None]  # (N,4,36)
    relu = np.maximum(conv, 0.0)
    maps = relu.reshape(n, NK, 6, 6)
    pooled = maps.reshape(n, NK, 3, 2, 3, 2).max(axis=(3, 5))    # (N,4,3,3)
    h = pooled.reshape(n, NK * 9)                                # (N,36)
    logits = h @ w2.T + b2                                       # (N,4)
    cache = (win, conv, relu, h)
    return logits, cache


def train():
    DATA.mkdir(exist_ok=True)
    xtr, ytr, xte, yte = make_dataset()
    xtr_f = (xtr / 16.0).reshape(-1, 64)          # normalise to 0..1 to train
    xte_f = (xte / 16.0).reshape(-1, 64)
    rng = np.random.default_rng(SEED)

    params = {
        "w1": rng.normal(0, 0.3, size=(NK, 9)),
        "b1": np.zeros(NK),
        "w2": rng.normal(0, 0.3, size=(K, NK * 9)),
        "b2": np.zeros(K),
    }
    mom = {k: np.zeros_like(v) for k, v in params.items()}
    n = xtr_f.shape[0]

    for ep in range(EPOCHS):
        lr = LR * (0.5 ** (ep // 100))            # halve every 100 epochs
        order = rng.permutation(n)
        for lo in range(0, n, BATCH):
            idx = order[lo:lo + BATCH]
            xb, yb = xtr_f[idx], ytr[idx]
            logits, (win, conv, relu, h) = forward(params, xb)
            p = np.exp(logits - logits.max(axis=1, keepdims=True))
            p /= p.sum(axis=1, keepdims=True)
            loss = -np.log(p[np.arange(len(idx)), yb] + 1e-12).mean()
            dy = p
            dy[np.arange(len(idx)), yb] -= 1.0     # (B,4)

            g = {}
            g["w2"] = dy.T @ h / len(idx)
            g["b2"] = dy.mean(axis=0)
            dh = dy @ params["w2"]                 # (B,36)
            dpooled = dh.reshape(len(idx), NK, 3, 3)
            # max-pool backward: route gradient to the max of each window
            drelu = np.zeros((len(idx), NK, 6, 6))
            maps = relu.reshape(len(idx), NK, 6, 6)
            for pr in range(3):
                for pc in range(3):
                    blk = maps[:, :, pr * 2:pr * 2 + 2, pc * 2:pc * 2 + 2]
                    arg = blk.reshape(len(idx), NK, 4).argmax(axis=2)
                    for k in range(NK):
                        for s in range(4):
                            dr, dc = divmod(s, 2)
                            m = arg[:, k] == s
                            drelu[m, k, pr * 2 + dr, pc * 2 + dc] = \
                                dpooled[m, k, pr, pc]
            dconv = drelu.reshape(len(idx), NK, 36) * (conv > 0)  # ReLU mask
            g["b1"] = dconv.sum(axis=(0, 2)) / len(idx)
            g["w1"] = np.einsum("nkw,nwp->kp", dconv, win) / len(idx)

            for k in params:
                mom[k] = 0.9 * mom[k] - lr * g[k]
                params[k] = params[k] + mom[k]
        if (ep + 1) % 50 == 0:
            print(f"  epoch {ep + 1:5d}  loss {loss:.4f}")

    def acc(x, y):
        logits, _ = forward(params, x.reshape(-1, 64))
        return float((logits.argmax(axis=1) == y).mean())

    print(f"train acc: {acc(xtr_f, ytr):.3f}  test acc: {acc(xte_f, yte):.3f}")
    np.savez(DATA / "model_float.npz",
             w1=params["w1"].reshape(NK, 3, 3), b1=params["b1"],
             w2=params["w2"].reshape(K, NK * 9), b2=params["b2"],
             xtr=xtr, ytr=ytr, xte=xte, yte=yte)
    print(f"wrote {DATA / 'model_float.npz'}")


if __name__ == "__main__":
    train()
