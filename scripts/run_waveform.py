#!/usr/bin/env python3
"""Build and run the compact DSD-8 GTKWave demonstration."""

import pathlib
import shutil
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "waveform"
ASM = ROOT / "sim" / "waveform_demo.asm"
TB = ROOT / "sim" / "tb_waveform.v"
HEX = BUILD / "waveform_demo.hex"
VVP = BUILD / "tb_waveform.vvp"
VCD = BUILD / "dsd8_wave.vcd"

RTL_SOURCES = [
    "dsd8_cpu.v", "prog_counter.v", "instr_memory.v", "instr_decoder.v",
    "register_file.v", "alu.v", "flags_reg.v", "data_memory.v",
    "control_unit.v", "io_bus.v", "nn_accel.v", "nn_mac_pipe.v",
    "nn_act.v", "nn_lut_rom.v",
]


def run(command, cwd=ROOT):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def check_vcd_hierarchy():
    """Fail if the VCD scope tree is malformed (duplicate sibling scopes or
    the same signal dumped twice), which breaks GTKWave/NovyWave hierarchy."""
    path, seen_scopes, seen_vars, stack = [], set(), set(), []
    for line in VCD.read_text().splitlines():
        tok = line.split()
        if not tok:
            continue
        if tok[0] == "$scope":
            path.append(tok[2])
            key = "/".join(path)
            if key in seen_scopes:
                sys.exit(f"VCD has duplicate scope '{key}'; dump a probe "
                         "module with $dumpvars, not loose nets")
            seen_scopes.add(key)
        elif tok[0] == "$upscope":
            path.pop()
        elif tok[0] == "$var":
            key = "/".join(path) + "/" + tok[4]
            if key in seen_vars:
                sys.exit(f"VCD dumps '{key}' twice")
            seen_vars.add(key)
        elif tok[0] == "$enddefinitions":
            break


def main():
    for tool in ("iverilog", "vvp"):
        if shutil.which(tool) is None:
            sys.exit(f"'{tool}' not found; install Icarus Verilog first")

    BUILD.mkdir(parents=True, exist_ok=True)

    run([
        sys.executable, str(ROOT / "tools" / "dsd8asm.py"),
        str(ASM), "-o", str(HEX),
    ])

    # A full image avoids a distracting $readmemh short-file warning.
    words = HEX.read_text().splitlines()
    if len(words) > 512:
        sys.exit("waveform demo exceeds the 512-word instruction memory")
    HEX.write_text("\n".join(words + ["0000"] * (512 - len(words))) + "\n")

    sources = [str(ROOT / "rtl" / name) for name in RTL_SOURCES]
    sources += [str(ROOT / "sim" / "peripherals.v"), str(TB)]
    run([
        "iverilog", "-g2005", "-s", "tb_waveform", "-o", str(VVP),
        f'-Ptb_waveform.VCD_FILE="{VCD}"',
        *sources,
    ])
    run(["vvp", str(VVP), f"+IMEM={HEX}"], cwd=BUILD)

    if not VCD.exists() or VCD.stat().st_size == 0:
        sys.exit("simulation completed without producing a waveform")

    check_vcd_hierarchy()

    print(f"Waveform: {VCD.relative_to(ROOT)}")
    print(f"Open with: gtkwave {VCD.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
