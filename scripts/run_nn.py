#!/usr/bin/env python3
"""
run_nn.py -- end-to-end NN accelerator certification and speedup bench.

For every tests/nn/sNN_<variant>.asm (23 samples x a0/a2/a4/b0/b1) and
for both NN_POSTED settings, this:
  1. assembles it with tools/dsd8asm.py,
  2. runs tools/dsd8sim_nn.py for the golden trace,
  3. runs nn/tb_nn_system.v (cpu + imem + io_bus + nn_accel +
     peripherals) under Icarus Verilog for the RTL trace and metrics,
  4. checks: RTL trace == golden trace, testbench errors == 0
     (no ready-without-request, no stall > 4 cycles), LEDs == the class
     nn/nn_ref.py predicts,
  5. reports timed-region cycles (between OUT 0x02<-1 and OUT 0x02<-2)
     and the speedup of each variant over the software baselines.

Results table: build/nn/bench.md. Exit code non-zero on any failure.

Usage:
    python3 scripts/run_nn.py                 # everything
    python3 scripts/run_nn.py --samples 0 5   # just s00 and s05
    python3 scripts/run_nn.py --posted 0      # one POSTED setting
"""
import argparse
import json
import pathlib
import statistics
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
TOOLS = REPO / "tools"
TESTS = REPO / "tests" / "nn"
BUILD = REPO / "build" / "nn"
sys.path.insert(0, str(REPO / "nn"))
import nn_ref  # noqa: E402

RTL_SOURCES = [
    "dsd8_cpu.v", "prog_counter.v", "instr_memory.v", "instr_decoder.v",
    "register_file.v", "alu.v", "flags_reg.v", "data_memory.v",
    "control_unit.v", "io_bus.v",
    "nn_accel.v", "nn_mac_pipe.v", "nn_act.v", "nn_lut_rom.v",
]
VARIANTS = ["b0", "b1", "a0", "a2", "a4"]
DESCR = {
    "b0": "software, repeated-addition multiply",
    "b1": "software, shift-and-add multiply",
    "a0": "accelerator, looped, software activation",
    "a2": "accelerator, looped, LUT activation",
    "a4": "accelerator, unrolled, LUT activation",
}


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, **kw)
    except FileNotFoundError as e:
        sys.exit(f"'{cmd[0]}' not found ({e}); install Icarus Verilog (apt-get install iverilog)")


def compile_bench(posted):
    out = BUILD / f"tb_nn_system_p{posted}.vvp"
    srcs = [str(REPO / "rtl" / f) for f in RTL_SOURCES]
    srcs += [str(REPO / "sim" / "peripherals.v"), str(REPO / "nn" / "tb_nn_system.v")]
    r = run(["iverilog", "-g2005", "-o", str(out), f"-Ptb_nn_system.POSTED={posted}"] + srcs)
    if r.returncode != 0:
        sys.exit(f"iverilog failed:\n{r.stdout}{r.stderr}")
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
    ap.add_argument("--posted", type=int, choices=[0, 1], nargs="*", default=[0, 1])
    args = ap.parse_args()

    BUILD.mkdir(parents=True, exist_ok=True)
    model = nn_ref.load()
    samples = args.samples if args.samples else range(len(model["samples"]))

    cycles = {}          # (posted, variant) -> [timed cycles]
    failures = []
    for posted in args.posted:
        vvp = compile_bench(posted)
        for idx in samples:
            want = nn_ref.infer(model, model["samples"][idx]["x"])[0]
            for v in VARIANTS:
                name = f"s{idx:02d}_{v}"
                work = BUILD / f"p{posted}" / name
                work.mkdir(parents=True, exist_ok=True)
                hexf, gold = work / f"{name}.hex", work / "gold.trace"
                r = run([sys.executable, str(TOOLS / "dsd8asm.py"), str(TESTS / f"{name}.asm"), "-o", str(hexf)])
                if r.returncode != 0:
                    failures.append(f"p{posted} {name}: assembler: {r.stderr.strip()}")
                    continue
                run([sys.executable, str(TOOLS / "dsd8sim_nn.py"), str(hexf), "--trace", str(gold),
                     "--max-instrs", "2000000"])
                r = run(["vvp", str(vvp), f"+IMEM={hexf}"], cwd=work)
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

    lines = ["# NN accelerator benchmark", "",
             f"Timed region = cycles between the start and end LED markers, "
             f"{len(list(samples))} Iris test samples, RTL simulation (Icarus).", ""]
    for posted in args.posted:
        base = {b: statistics.mean(cycles[(posted, b)]) for b in ("b0", "b1") if (posted, b) in cycles}
        lines += [f"## NN_POSTED = {posted}", "",
                  "| Variant | What it is | Mean cycles | Min | Max | vs b0 | vs b1 |",
                  "|---|---|---:|---:|---:|---:|---:|"]
        for v in VARIANTS:
            c = cycles.get((posted, v))
            if not c:
                lines.append(f"| {v} | {DESCR[v]} | FAIL | | | | |")
                continue
            mean = statistics.mean(c)
            sp = [f"{base[b] / mean:.1f}x" if b in base else "-" for b in ("b0", "b1")]
            lines.append(f"| {v} | {DESCR[v]} | {mean:.0f} | {min(c)} | {max(c)} | {sp[0]} | {sp[1]} |")
        lines.append("")
    if failures:
        lines += ["## Failures", ""] + [f"- {f}" for f in failures] + [""]
    else:
        lines += ["All runs: RTL trace == golden trace, 0 testbench errors, LEDs == nn_ref class.", ""]
    (BUILD / "bench.md").write_text("\n".join(lines))
    print("\n".join(lines))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
