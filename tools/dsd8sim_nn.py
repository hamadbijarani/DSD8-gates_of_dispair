#!/usr/bin/env python3
"""Golden simulator with the NN accelerator (subclass of tools/dsd8sim.py)."""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "nn"))

import dsd8sim
import nn_ref

MASK = (1 << 24) - 1


def s24(v):
    v &= MASK
    return v - (1 << 24) if v & (1 << 23) else v


def s8(v):
    return v - 256 if v >= 128 else v


class NNCpu(dsd8sim.Cpu):
    def __init__(self, *a, **k):
        super().__init__(*a, **k)
        self.nn_unlocked = False
        self.nn_a = 0
        self.nn_acc = 0
        self.nn_shift = 0
        self.nn_bank = 0
        self.nn_lut_idx = 0
        self.nn_skip = 0
        self.nn_mac = 0

    def io_read(self, port):
        if 0x50 <= port <= 0x5F:
            if not self.nn_unlocked:
                return 0x00
            if port == 0x53:
                return self.nn_acc & 0xFF
            if port == 0x54:
                return (self.nn_acc >> 8) & 0xFF
            if port == 0x55:
                return (self.nn_acc >> 16) & 0xFF
            if port == 0x57:
                return nn_ref.sat8(self.nn_acc >> self.nn_shift) & 0xFF
            if port == 0x59:
                return nn_ref.LUT[self.nn_bank][nn_ref.sat8(self.nn_acc >> self.nn_shift) & 0xFF]
            if port == 0x5B:
                return nn_ref.LUT[self.nn_bank][self.nn_lut_idx]
            if port == 0x5C:
                return self.nn_skip
            if port == 0x5D:
                return self.nn_mac
            if port == 0x5F:
                return 0x01
            return 0x00
        return super().io_read(port)

    def io_write(self, port, val):
        if 0x50 <= port <= 0x5F:
            if port == 0x5F:
                self.nn_unlocked = val == 0xA5
                return
            if not self.nn_unlocked:
                return
            if port == 0x50:
                self.nn_a = val & 0xFF
            elif port == 0x51:
                w = val & 0xFF
                if self.nn_a == 0 or w == 0:
                    self.nn_skip = min(255, self.nn_skip + 1)
                else:
                    self.nn_acc = s24(self.nn_acc + s8(self.nn_a) * s8(w))
                    self.nn_mac = min(255, self.nn_mac + 1)
            elif port == 0x52:
                if val & 0x01:
                    self.nn_acc = 0
                if val & 0x02:
                    self.nn_skip = 0
                    self.nn_mac = 0
            elif port == 0x56:
                self.nn_shift = val & 0x0F
            elif port == 0x58:
                self.nn_bank = val & 0x03
            elif port == 0x5A:
                self.nn_lut_idx = val & 0xFF
            return
        super().io_write(port, val)


def run(hex_path, max_instrs=100000, switches=0, buttons=0):
    imem = dsd8sim.load_hex(hex_path)
    cpu = NNCpu(imem, switches=switches, buttons=buttons)
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
    args = ap.parse_args()
    trace, state = run(args.hex, args.max_instrs)
    with open(args.trace, "w") as f:
        for t in trace:
            f.write(dsd8sim.format_trace_line(t) + "\n")
    if args.state_out:
        import json
        json.dump(state, open(args.state_out, "w"), indent=2)
    print(f"retired {len(trace)} instructions")


if __name__ == "__main__":
    main()
