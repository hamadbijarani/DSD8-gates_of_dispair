#!/usr/bin/env python3
"""Emit benchmark programs per test sample (tests/nn/sNN_<variant>.asm).

Variants
  a4  accelerator, fully unrolled, LUT activation (weights as immediates)
  a2  accelerator, looped,         LUT activation (weights in data memory)
  a0  accelerator, looped,         software activation (reads NN_QOUT)
  b1  pure software, shift-and-add multiply, 16-bit accumulator
  b0  pure software, repeated-addition multiply, 16-bit accumulator

Every variant computes exactly the same integers as nn/nn_ref.py and ends
with the predicted class on the LEDs (port 0x02). The timed region is
bracketed by OUT 0x02 <- 1 (start) and OUT 0x02 <- 2 (end), so one-time
setup (unlock, loading inputs and weights) and the final argmax are not
counted.

Data-memory layout for the looped variants (a0/a2/b0/b1). Each neuron's
weights are stored contiguously with its bias as the last element, and
every input vector ends with a constant 127, so the bias is just one more
multiply-accumulate (bias folded as activation 127, see quantize.py):

  W1T  0..29   neuron j: W1T[j*5 + i]  i=0..3 weights, i=4 bias
  W2T 32..52   neuron k: W2T[32 + k*7 + j]  j=0..5 weights, j=6 bias
  H   64..70   hidden activations, H[6] = 127
  L   72..74   output logits (offset binary)
  X   80..84   inputs, X[4] = 127
  S   96..101  software-baseline scratch (pointers, counters, sign)

The b0/b1 baselines use a 16-bit accumulator. Accumulation is modular,
so only the final sum must fit in int16; main() asserts this for every
sample (worst case in the shipped model is |27722|).
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
DATA = ROOT / "data"
OUT = ROOT.parent / "tests" / "nn"

IMEM_WORDS = 512

W1_BASE = 0
W2_BASE = 32
H_BASE = 64
L_BASE = 72
X_BASE = 80

# software-baseline scratch cells
S_PW, S_PIN, S_POUT, S_CN, S_CI, S_SGN = 96, 97, 98, 99, 100, 101

N_IN, N_HID, N_OUT = 4, 6, 3

_UID = [0]


def uid():
    _UID[0] += 1
    return _UID[0]


# ---------------------------------------------------------------- common

def unlock(m, bank):
    return [
        "        LDI  R0, 0xA5",
        "        OUT  0x5F, R0          ; unlock accelerator",
        "        LDI  R0, 0x03",
        "        OUT  0x52, R0          ; clear acc + counters",
        f"        LDI  R0, {m['shift1']}",
        "        OUT  0x56, R0",
        f"        LDI  R0, {bank}",
        "        OUT  0x58, R0",
    ]


def load_inputs_regs(x):
    """a4 only: inputs kept in R1..R4 (and mirrored to X)."""
    out = []
    for i, v in enumerate(x):
        out.append(f"        LDI  R{i + 1}, {v}")
        out.append(f"        LDI  R7, {X_BASE + i}")
        out.append(f"        ST   [R7], R{i + 1}")
    return out


def store_block(base, values):
    """Write a list of bytes to consecutive addresses. Uses R4=1, R5, R7."""
    out = [f"        LDI  R7, {base}", "        LDI  R4, 1"]
    for v in values:
        out += [
            f"        LDI  R5, {v & 0xFF}",
            "        ST   [R7], R5",
            "        ADD  R7, R7, R4",
        ]
    return out


def data_init(m, x):
    """Inputs (+127), transposed weights with bias last, H[6]=127."""
    w1t = []
    for j in range(N_HID):
        w1t += [m["w1"][i][j] for i in range(N_IN)] + [m["b1"][j]]
    w2t = []
    for k in range(N_OUT):
        w2t += [m["w2"][j][k] for j in range(N_HID)] + [m["b2"][k]]
    out = []
    out += store_block(X_BASE, list(x) + [127])
    out += store_block(W1_BASE, w1t)
    out += store_block(W2_BASE, w2t)
    out += [f"        LDI  R7, {H_BASE + N_HID}", "        LDI  R5, 127", "        ST   [R7], R5"]
    return out


def marker(v):
    return [f"        LDI  R0, {v}", "        OUT  0x02, R0          ; timing marker"]


def argmax_unsigned():
    """Logits are offset-binary, so an unsigned compare orders them."""
    u = uid()
    return [
        f"        LDI  R7, {L_BASE}",
        "        LD   R1, [R7]",
        f"        LDI  R7, {L_BASE + 1}",
        "        LD   R2, [R7]",
        f"        LDI  R7, {L_BASE + 2}",
        "        LD   R3, [R7]",
        "        LDI  R0, 0",
        "        CMP  R1, R2            ; C=1 when best >= L1",
        f"        BCS  am1_{u}           ; ties keep the lower class",
        "        LDI  R0, 1",
        "        OR   R1, R2, R2",
        f"am1_{u}: CMP  R1, R3",
        f"        BCS  am2_{u}",
        "        LDI  R0, 2",
        f"am2_{u}: OUT  0x02, R0          ; LEDs = predicted class",
        "        HLT",
    ]


# ------------------------------------------- accelerated, looped (a0/a2)

def accel_layer(in_base, n_in, w_base, out_base, n_out, shift, act):
    """One layer on the accelerator. act: 'lut' (read NN_ACT) or
    'relu' / 'offset' (read NN_QOUT, activation done in software).

    R0 tmp, R1 weight ptr, R2 input ptr, R3 neurons left, R4 = 1,
    R5 data, R6 output ptr, R7 inputs left.
    """
    u = uid()
    out = [
        f"        LDI  R0, {shift}",
        "        OUT  0x56, R0          ; requant shift",
        f"        LDI  R1, {w_base}",
        f"        LDI  R6, {out_base}",
        f"        LDI  R3, {n_out}",
        "        LDI  R4, 1",
        f"ln_{u}:  LDI  R0, 0x01",
        "        OUT  0x52, R0          ; clear accumulator",
        f"        LDI  R2, {in_base}",
        f"        LDI  R7, {n_in + 1}         ; inputs + bias",
        f"li_{u}:  LD   R5, [R2]",
        "        OUT  0x50, R5          ; A = activation",
        "        LD   R5, [R1]",
        "        OUT  0x51, R5          ; W = weight -> one MAC",
        "        ADD  R1, R1, R4",
        "        ADD  R2, R2, R4",
        "        SUB  R7, R7, R4",
        f"        BNE  li_{u}",
    ]
    if act == "lut":
        out += ["        IN   R5, 0x59          ; LUT[sat8(acc>>>shift)]"]
    else:
        out += ["        IN   R5, 0x57          ; sat8(acc>>>shift)"]
        if act == "relu":
            out += [
                "        LDI  R0, 0",
                "        CMP  R5, R0",
                f"        BPL  ap_{u}",
                "        LDI  R5, 0             ; ReLU: negative -> 0",
                f"ap_{u}:  NOP",
            ]
        else:
            out += [
                "        LDI  R0, 0x80",
                "        XOR  R5, R5, R0        ; signed -> offset binary",
            ]
    out += [
        "        ST   [R6], R5",
        "        ADD  R6, R6, R4",
        "        SUB  R3, R3, R4",
        f"        BNE  ln_{u}",
    ]
    return out


def prog_accel_loop(m, x, act_mode):
    out = unlock(m, 0) + data_init(m, x) + marker(1)
    if act_mode == "lut":
        out += accel_layer(X_BASE, N_IN, W1_BASE, H_BASE, N_HID, m["shift1"], "lut")
        out += ["        LDI  R0, 2", "        OUT  0x58, R0          ; LUT bank 2 (offset binary)"]
        out += accel_layer(H_BASE, N_HID, W2_BASE, L_BASE, N_OUT, m["shift2"], "lut")
    else:
        out += accel_layer(X_BASE, N_IN, W1_BASE, H_BASE, N_HID, m["shift1"], "relu")
        out += accel_layer(H_BASE, N_HID, W2_BASE, L_BASE, N_OUT, m["shift2"], "offset")
    out += marker(2) + argmax_unsigned()
    return out


# ----------------------------------------- accelerated, unrolled (a4)

def prog_unrolled(m, x):
    out = unlock(m, 0) + load_inputs_regs(x)
    out += marker(1)
    for j in range(N_HID):
        out += [
            "        LDI  R0, 0x01",
            "        OUT  0x52, R0",
            f"        LDI  R0, {m['shift1']}",
            "        OUT  0x56, R0",
        ]
        for i in range(N_IN):
            out += [
                f"        LDI  R5, {m['w1'][i][j] & 0xFF}",
                f"        OUT  0x50, R{i + 1}",
                "        OUT  0x51, R5",
            ]
        out += [
            "        LDI  R5, 127",
            "        OUT  0x50, R5",
            f"        LDI  R5, {m['b1'][j] & 0xFF}",
            "        OUT  0x51, R5",
            "        IN   R6, 0x59",
            f"        LDI  R7, {H_BASE + j}",
            "        ST   [R7], R6",
        ]
    out += ["        LDI  R0, 2", "        OUT  0x58, R0"]
    for k in range(N_OUT):
        out += [
            "        LDI  R0, 0x01",
            "        OUT  0x52, R0",
            f"        LDI  R0, {m['shift2']}",
            "        OUT  0x56, R0",
        ]
        for j in range(N_HID):
            out += [
                f"        LDI  R7, {H_BASE + j}",
                "        LD   R5, [R7]",
                f"        LDI  R6, {m['w2'][j][k] & 0xFF}",
                "        OUT  0x50, R5",
                "        OUT  0x51, R6",
            ]
        out += [
            "        LDI  R5, 127",
            "        OUT  0x50, R5",
            f"        LDI  R5, {m['b2'][k] & 0xFF}",
            "        OUT  0x51, R5",
            "        IN   R6, 0x59",
            f"        LDI  R7, {L_BASE + k}",
            "        ST   [R7], R6",
        ]
    out += marker(2) + argmax_unsigned()
    return out


# ------------------------------------------------ software (b0/b1)
#
# Register use inside a software layer:
#   R1:R2  16-bit accumulator (lo:hi)
#   R3     activation a (always 0..127: inputs, ReLU outputs, bias 127)
#   R4     weight w (signed int8)
#   R5:R6  16-bit product (b1 only), R5 = result byte after requant
#   R7     loop counter / temp,  R0 temp
# Pointers and counters live in data memory (S_*), since 8 registers
# are not enough to hold everything at once.

def sw_load_operands(u):
    """R3 = *in_ptr, R4 = *w_ptr."""
    return [
        f"sw_i{u}: LDI  R0, {S_PIN}",
        "        LD   R3, [R0]",
        "        LD   R3, [R3]          ; a = *in_ptr",
        f"        LDI  R0, {S_PW}",
        "        LD   R4, [R0]",
        "        LD   R4, [R4]          ; w = *w_ptr",
    ]


def sw_mul_repeated_add(u):
    """b0: acc += a*w by adding (or subtracting) a, |w| times."""
    return [
        "        LDI  R0, 0",
        "        CMP  R4, R0",
        f"        BEQ  sw_nx{u}          ; w == 0: nothing to add",
        f"        BMI  ra_n{u}",
        f"ra_p{u}: ADD  R1, R1, R3        ; acc += a",
        f"        BCC  ra_pc{u}",
        "        LDI  R0, 1",
        "        ADD  R2, R2, R0        ; carry into high byte",
        f"ra_pc{u}: LDI  R0, 1",
        "        SUB  R4, R4, R0",
        f"        BNE  ra_p{u}",
        f"        JMP  sw_nx{u}",
        f"ra_n{u}: SUB  R1, R1, R3        ; acc -= a",
        f"        BCS  ra_nc{u}",
        "        LDI  R0, 1",
        "        SUB  R2, R2, R0        ; borrow from high byte",
        f"ra_nc{u}: LDI  R0, 1",
        "        ADD  R4, R4, R0",
        f"        BNE  ra_n{u}",
    ]


def sw_mul_shift_add(u):
    """b1: P = a*|w| by shift-and-add (MSB first), then acc +/-= P."""
    return [
        f"        LDI  R0, {S_SGN}",
        "        ST   [R0], R4          ; remember sign of w",
        "        LDI  R0, 0",
        "        CMP  R4, R0",
        f"        BPL  ms_ab{u}",
        "        LDI  R0, 0xFF",
        "        XOR  R4, R4, R0",
        "        LDI  R0, 1",
        "        ADD  R4, R4, R0        ; R4 = -w (two's complement)",
        f"ms_ab{u}: LDI  R5, 0",
        "        LDI  R6, 0             ; P = 0",
        "        LDI  R7, 8",
        f"ms_l{u}:  SHL  R6, R6            ; P <<= 1 (high byte)",
        "        SHL  R5, R5            ; low byte, C = bit 7",
        f"        BCC  ms_s{u}",
        "        LDI  R0, 1",
        "        OR   R6, R6, R0",
        f"ms_s{u}:  SHL  R4, R4            ; next multiplier bit -> C",
        f"        BCC  ms_z{u}",
        "        ADD  R5, R5, R3        ; P += a",
        f"        BCC  ms_z{u}",
        "        LDI  R0, 1",
        "        ADD  R6, R6, R0",
        f"ms_z{u}:  LDI  R0, 1",
        "        SUB  R7, R7, R0",
        f"        BNE  ms_l{u}",
        f"        LDI  R0, {S_SGN}",
        "        LD   R0, [R0]",
        "        LDI  R7, 0",
        "        CMP  R0, R7",
        f"        BMI  ms_n{u}",
        "        ADD  R1, R1, R5        ; acc += P",
        f"        BCC  ms_pc{u}",
        "        LDI  R0, 1",
        "        ADD  R2, R2, R0",
        f"ms_pc{u}: ADD  R2, R2, R6",
        f"        JMP  sw_nx{u}",
        f"ms_n{u}:  SUB  R1, R1, R5        ; acc -= P",
        f"        BCS  ms_nc{u}",
        "        LDI  R0, 1",
        "        SUB  R2, R2, R0",
        f"ms_nc{u}: SUB  R2, R2, R6",
    ]


def sw_advance(u):
    """in_ptr++, w_ptr++, inputs_left--, loop."""
    return [
        f"sw_nx{u}: LDI  R3, 1",
        f"        LDI  R0, {S_PIN}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R3",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_PW}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R3",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_CI}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R3",
        "        ST   [R0], R7          ; ST leaves flags alone",
        f"        BNE  sw_i{u}",
    ]


def sw_requant(u, shift, act):
    """R5 = act(sat8(R2:R1 >>> shift)). act: 'relu' or 'offset'."""
    out = []
    if shift > 0:
        out += [
            f"        LDI  R7, {shift}",
            "        LDI  R3, 0x80",
            f"rq_l{u}:  AND  R4, R2, R3        ; keep sign bit",
            "        SHR  R1, R1",
            "        SHR  R2, R2            ; C = old bit 0 of high byte",
            f"        BCC  rq_c{u}",
            "        OR   R1, R1, R3        ; ... moves into bit 7 of low",
            f"rq_c{u}:  OR   R2, R2, R4        ; arithmetic: refill sign",
            "        LDI  R0, 1",
            "        SUB  R7, R7, R0",
            f"        BNE  rq_l{u}",
        ]
    else:
        out += ["        LDI  R3, 0x80"]
    out += [
        "        LDI  R5, 0",
        "        AND  R4, R2, R3",
        "        CMP  R4, R5",
        f"        BNE  rq_ng{u}           ; value is negative",
        "        CMP  R2, R5",
        f"        BNE  rq_mx{u}           ; > 255: saturate high",
        "        AND  R4, R1, R3",
        "        CMP  R4, R5",
        f"        BNE  rq_mx{u}           ; 128..255: saturate high",
    ]
    if act == "relu":
        out += [
            "        OR   R5, R1, R1        ; 0..127 passes through",
            f"        JMP  rq_d{u}",
            f"rq_mx{u}: LDI  R5, 127",
            f"rq_ng{u}: NOP                    ; ReLU: negative -> R5 = 0",
            f"rq_d{u}:  NOP",
        ]
    else:
        out += [
            "        OR   R5, R1, R3        ; 0..127 -> 128..255",
            f"        JMP  rq_d{u}",
            f"rq_mx{u}: LDI  R5, 0xFF          ; +127 -> 0xFF",
            f"        JMP  rq_d{u}",
            f"rq_ng{u}: LDI  R4, 0xFF",
            "        CMP  R2, R4",
            f"        BNE  rq_d{u}           ; < -256: R5 = 0x00 (-128)",
            "        AND  R4, R1, R3",
            "        CMP  R4, R5",
            f"        BEQ  rq_d{u}           ; -256..-129: R5 = 0x00",
            "        XOR  R5, R1, R3        ; -128..-1 -> 0..127",
            f"rq_d{u}:  NOP",
        ]
    return out


def sw_layer(in_base, n_in, w_base, out_base, n_out, shift, act, mul):
    u = uid()
    out = [
        f"        LDI  R0, {S_PW}",
        f"        LDI  R7, {w_base}",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_POUT}",
        f"        LDI  R7, {out_base}",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_CN}",
        f"        LDI  R7, {n_out}",
        "        ST   [R0], R7",
        f"sw_n{u}: LDI  R1, 0",
        "        LDI  R2, 0             ; acc = 0",
        f"        LDI  R0, {S_PIN}",
        f"        LDI  R7, {in_base}",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_CI}",
        f"        LDI  R7, {n_in + 1}",
        "        ST   [R0], R7",
    ]
    out += sw_load_operands(u)
    out += sw_mul_repeated_add(u) if mul == "add" else sw_mul_shift_add(u)
    out += sw_advance(u)
    out += sw_requant(u, shift, act)
    out += [
        "        LDI  R3, 1",
        f"        LDI  R0, {S_POUT}",
        "        LD   R7, [R0]",
        "        ST   [R7], R5          ; store neuron output",
        "        ADD  R7, R7, R3",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_CN}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R3",
        "        ST   [R0], R7",
        f"        BNE  sw_n{u}",
    ]
    return out


def prog_sw(m, x, mul):
    """b0 (mul='add') or b1 (mul='shift'). Never touches the accelerator."""
    out = data_init(m, x) + marker(1)
    out += sw_layer(X_BASE, N_IN, W1_BASE, H_BASE, N_HID, m["shift1"], "relu", mul)
    out += sw_layer(H_BASE, N_HID, W2_BASE, L_BASE, N_OUT, m["shift2"], "offset", mul)
    out += marker(2) + argmax_unsigned()
    return out


# ------------------------------------------------------------- driver

def check_int16(m, x):
    """b0/b1 use a 16-bit accumulator: the final sums must fit."""
    import nn_ref
    _, h, _ = nn_ref.infer(m, x)
    sums = []
    for j in range(N_HID):
        sums.append(sum(x[i] * m["w1"][i][j] for i in range(N_IN)) + 127 * m["b1"][j])
    for k in range(N_OUT):
        sums.append(sum(h[j] * m["w2"][j][k] for j in range(N_HID)) + 127 * m["b2"][k])
    worst = max(abs(s) for s in sums)
    if worst > 32767:
        raise SystemExit(f"sample {x}: |acc| {worst} overflows the 16-bit software accumulator")


def n_instrs(lines):
    n = 0
    for ln in lines:
        body = ln.split(";")[0].strip()
        if ":" in body:
            body = body.split(":", 1)[1].strip()
        if body:
            n += 1
    return n


def main():
    import sys
    sys.path.insert(0, str(ROOT))
    m = json.loads((DATA / "weights_q.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    sizes = {}
    for idx, s in enumerate(m["samples"]):
        x = s["x"]
        check_int16(m, x)
        progs = {
            "a0": prog_accel_loop(m, x, "sw"),
            "a2": prog_accel_loop(m, x, "lut"),
            "a4": prog_unrolled(m, x),
            "b1": prog_sw(m, x, "shift"),
            "b0": prog_sw(m, x, "add"),
        }
        for name, lines in progs.items():
            n = n_instrs(lines)
            if n > IMEM_WORDS:
                raise SystemExit(f"s{idx:02d}_{name}: {n} instructions > IMEM {IMEM_WORDS}")
            sizes[name] = max(sizes.get(name, 0), n)
            (OUT / f"s{idx:02d}_{name}.asm").write_text("\n".join(lines) + "\n")
    print(f"wrote {len(m['samples'])} samples x {len(sizes)} variants to {OUT}")
    print("max instructions: " + ", ".join(f"{k}={v}" for k, v in sizes.items()))


if __name__ == "__main__":
    main()
