#!/usr/bin/env python3
"""Golden simulator with the CNN stream peripheral (subclass of NNCpu).

Ports 0x44-0x46 model sim/cnn_periph.v exactly: one sequential pointer
into the 16128-byte stream (64 samples x 252 bytes each: 64 image bytes,
4x10 conv weights, 4x37 FC weights). 0x45 and 0x46 are two windows on the
same pointer -- each accepted IN returns stream[ptr] and advances it by
exactly one -- and a write to 0x44 skips the pointer to the next sample
boundary. The NN accelerator ports (0x50-0x5F) are inherited unchanged.

Usage:
    python3 dsd8sim_cnn.py program.hex --trace gold.trace \
        --stream cnn/data/stream.hex --sample 0
"""
import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "nn"))
sys.path.insert(0, str(ROOT / "cnn"))

import dsd8sim
import dsd8sim_nn

SAMPLE_BYTES = 252
N_SAMPLES = 64
STREAM_END = N_SAMPLES * SAMPLE_BYTES


def load_stream(path):
    """stream.hex: one 2-digit hex byte per line, in stream order."""
    out = []
    for line in pathlib.Path(path).read_text().split("\n"):
        line = line.strip()
        if line:
            out.append(int(line, 16) & 0xFF)
    if len(out) != STREAM_END:
        raise SystemExit(f"{path}: expected {STREAM_END} stream bytes, got {len(out)}")
    return out


class CNNCpu(dsd8sim_nn.NNCpu):
    def __init__(self, *a, stream=None, sample=0, **k):
        super().__init__(*a, **k)
        self.cnn_stream = list(stream) if stream else [0] * STREAM_END
        self.cnn_ptr = (sample % N_SAMPLES) * SAMPLE_BYTES

    def io_read(self, port):
        if port in (0x45, 0x46):
            val = self.cnn_stream[self.cnn_ptr]
            self.cnn_ptr = (self.cnn_ptr + 1) % STREAM_END
            return val & 0xFF
        return super().io_read(port)

    def io_write(self, port, val):
        if port == 0x44:
            self.cnn_ptr = (((self.cnn_ptr // SAMPLE_BYTES) + 1) % N_SAMPLES) * SAMPLE_BYTES
            return
        super().io_write(port, val)


def run(hex_path, max_instrs=100000, switches=0, buttons=0,
        stream_path=None, sample=0):
    imem = dsd8sim.load_hex(hex_path)
    stream = load_stream(stream_path) if stream_path else None
    cpu = CNNCpu(imem, switches=switches, buttons=buttons,
                 stream=stream, sample=sample)
    trace = []
    hit = False
    for _ in range(max_instrs):
        line = cpu.step()
        if line is None:
            break
        trace.append(line)
    else:
        hit = not cpu.halted
    state = {
        "registers": cpu.r,
        "leds": cpu.leds,
        "nn_acc": cpu.nn_acc,
        "nn_skip": cpu.nn_skip,
        "nn_mac": cpu.nn_mac,
        "cnn_ptr": cpu.cnn_ptr,
        "halted": cpu.halted,
        "instructions_retired": len(trace),
        "hit_instruction_limit": hit,
    }
    return trace, state


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("hex")
    ap.add_argument("--trace", required=True)
    ap.add_argument("--state-out")
    ap.add_argument("--max-instrs", type=int, default=100000)
    ap.add_argument("--stream", default=None)
    ap.add_argument("--sample", type=int, default=0)
    args = ap.parse_args()
    trace, state = run(args.hex, args.max_instrs,
                       stream_path=args.stream, sample=args.sample)
    with open(args.trace, "w") as f:
        for t in trace:
            f.write(dsd8sim.format_trace_line(t) + "\n")
    if args.state_out:
        json.dump(state, open(args.state_out, "w"), indent=2)
    print(f"retired {len(trace)} instructions")


if __name__ == "__main__":
    main()
