#!/usr/bin/env python3
"""
run_cnn.py -- end-to-end CNN certification and speedup bench.

For every tests/cnn/sNN_<variant>.asm (64 samples x a0/a2/b0/b1) this:
  1. assembles it with tools/dsd8asm.py,
  2. runs tools/dsd8sim_cnn.py for the golden trace (stream peripheral),
  3. runs cnn/tb_cnn_system.v (cpu + imem + io_bus + nn_accel +
     cnn_periph stream) under Icarus Verilog for the RTL trace and metrics,
  4. checks: RTL trace == golden trace, testbench errors == 0
     (no ready-without-request, no stall > 4 cycles), LEDs == the class
     cnn/cnn_ref.py predicts,
  5. reports timed-region cycles (between OUT 0x02<-1 and OUT 0x02<-2)
     and the speedup of each variant over the software baselines.

Results table: build/cnn/bench.md. Exit code non-zero on any failure.

Usage:
    python3 scripts/run_cnn.py                 # everything, NN_POSTED=0
    python3 scripts/run_cnn.py --samples 0 5   # just s00 and s05
    python3 scripts/run_cnn.py --posted 0 1    # both POSTED settings
"""
import argparse
import json
import os
import pathlib
import statistics
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
TOOLS = REPO / "tools"
TESTS = REPO / "tests" / "cnn"
BUILD = REPO / "build" / "cnn"
STREAM = REPO / "cnn" / "data" / "stream.hex"
sys.path.insert(0, str(REPO / "cnn"))
import cnn_ref  # noqa: E402

RTL_SOURCES = [
    "dsd8_cpu.v", "prog_counter.v", "instr_memory.v", "instr_decoder.v",
    "register_file.v", "alu.v", "flags_reg.v", "data_memory.v",
    "control_unit.v", "io_bus.v",
    "nn_accel.v", "nn_mac_pipe.v", "nn_act.v", "nn_lut_rom.v",
]
VARIANTS = ["b0", "b1", "a0", "a2"]
DESCR = {
    "b0": "software conv, repeated-addition multiply",
    "b1": "software conv, shift-and-add multiply",
    "a0": "accelerator conv, looped, software activation",
    "a2": "accelerator conv, looped, LUT activation",
}


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, **kw)
    except FileNotFoundError as e:
        sys.exit(f"'{cmd[0]}' not found ({e}); install Icarus Verilog (apt-get install iverilog)")


def compile_bench(posted):
    out = BUILD / f"tb_cnn_system_p{posted}.vvp"
    srcs = [str(REPO / "rtl" / f) for f in RTL_SOURCES]
    srcs += [str(REPO / "sim" / "cnn_periph.v"), str(REPO / "cnn" / "tb_cnn_system.v")]
    tmp = out.with_name(f"{out.name}.{os.getpid()}.tmp")
    r = run(["iverilog", "-g2005", "-o", str(tmp), f"-Ptb_cnn_system.POSTED={posted}"] + srcs)
    if r.returncode != 0:
        sys.exit(f"iverilog failed:\n{r.stdout}{r.stderr}")
    tmp.replace(out)
    return out


def read_metrics(path):
    d = {}
    for line in path.read_text().splitlines():
        k, v = line.split()
        d[k] = v
    return d


def first_diff(gold, dut):
    g = gold.read_text().splitlines()
    d = dut.read_text().splitlines() if dut.exists() else []
    for i, (a, b) in enumerate(zip(g, d), 1):
        if a != b:
            return f"trace line {i}: expected '{a}' got '{b}'"
    if len(g) != len(d):
        return f"trace length gold={len(g)} dut={len(d)}"
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--samples", type=int, nargs="*")
    ap.add_argument("--posted", type=int, choices=[0, 1], nargs="*", default=[0])
    args = ap.parse_args()

    BUILD.mkdir(parents=True, exist_ok=True)
    model = cnn_ref.load()
    samples = args.samples if args.samples else range(len(model["samples"]))

    cycles = {}          # (posted, variant) -> [timed cycles]
    golden = {}          # variant -> [retired instructions from the golden sim]
    failures = []
    for posted in args.posted:
        vvp = compile_bench(posted)
        for idx in samples:
            want = cnn_ref.infer(model, model["samples"][idx]["x"])
            for v in VARIANTS:
                name = f"s{idx:02d}_{v}"
                work = BUILD / f"p{posted}" / name
                work.mkdir(parents=True, exist_ok=True)
                hexf, gold = work / f"{name}.hex", work / "gold.trace"
                r = run([sys.executable, str(TOOLS / "dsd8asm.py"), str(TESTS / f"{name}.asm"), "-o", str(hexf)])
                if r.returncode != 0:
                    failures.append(f"p{posted} {name}: assembler: {r.stderr.strip()}")
                    continue
                r = run([sys.executable, str(TOOLS / "dsd8sim_cnn.py"), str(hexf), "--trace", str(gold),
                         "--stream", str(STREAM), "--sample", str(idx), "--max-instrs", "2000000"])
                if r.returncode != 0:
                    failures.append(f"p{posted} {name}: golden sim: {r.stderr.strip()}")
                    continue
                golden.setdefault(v, []).append(sum(1 for _ in gold.open()))
                r = run(["vvp", str(vvp), f"+IMEM={hexf}", f"+CNNSTREAM={STREAM}",
                         f"+CNNSAMP={idx}"], cwd=work)
                if r.returncode != 0:
                    failures.append(f"p{posted} {name}: vvp: {r.stderr.strip()}")
                    continue
                met = read_metrics(work / "metrics.txt")
                problems = []
                diff = first_diff(gold, work / "dut.trace")
                if diff:
                    problems.append(diff)
                if met["errors"] != "0":
                    problems.append(f"testbench errors={met['errors']}")
                if int(met["leds"], 16) != want:
                    problems.append(f"leds={met['leds']} want {want}")
                if problems:
                    failures.append(f"p{posted} {name}: " + "; ".join(problems))
                    continue
                cycles.setdefault((posted, v), []).append(int(met["end"]) - int(met["start"]))

    lines = ["# CNN benchmark", "",
             f"Timed region = cycles between the start and end LED markers, "
             f"{len(list(samples))} test samples, RTL simulation (Icarus).", ""]
    for posted in args.posted:
        base = {b: statistics.mean(cycles[(posted, b)]) for b in ("b0", "b1") if (posted, b) in cycles}
        lines += [f"## NN_POSTED = {posted}", "",
                  "| Variant | What it is | Mean cycles | Min | Max | Golden instrs | vs b0 | vs b1 |",
                  "|---|---|---:|---:|---:|---:|---:|---:|"]
        for v in VARIANTS:
            c = cycles.get((posted, v))
            if not c:
                lines.append(f"| {v} | {DESCR[v]} | FAIL | | | | | |")
                continue
            mean = statistics.mean(c)
            g = statistics.mean(golden.get(v, [0]))
            sp = [f"{base[b] / mean:.1f}x" if b in base else "-" for b in ("b0", "b1")]
            lines.append(f"| {v} | {DESCR[v]} | {mean:.0f} | {min(c)} | {max(c)} | {g:.0f} | {sp[0]} | {sp[1]} |")
        lines.append("")
    if failures:
        lines += ["## Failures", ""] + [f"- {f}" for f in failures] + [""]
    else:
        lines += ["All runs: RTL trace == golden trace, 0 testbench errors, LEDs == cnn_ref class.", ""]
    (BUILD / "bench.md").write_text("\n".join(lines))
    print("\n".join(lines))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
