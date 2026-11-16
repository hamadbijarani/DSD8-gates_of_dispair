#!/usr/bin/env python3
"""Emit CNN benchmark programs per test sample (tests/cnn/sNN_<variant>.asm)
and the byte stream they consume (cnn/data/stream.hex).

The image and the weights are NOT stored in instruction memory: a new
peripheral (sim/cnn_periph.v, ports 0x44-0x46) streams them from a hex file
chosen by the +CNNSTREAM plusarg. Port 0x45 returns the next image byte and
0x46 the next weight byte (one shared sequential pointer); a write to 0x44
skips to the next sample boundary. Per sample the stream is exactly 252
bytes: 64 image bytes, 4x10 conv weights (kernel-major, bias last), 4x37 FC
weights (class-major, bias last). The FC weights are consumed straight from
port 0x46 during the FC phase, never stored.

Variants
  a2  accelerator, fused conv+pool loops, LUT activation (bank 0 / bank 2)
  a0  accelerator, fused conv+pool loops, software activation
  b1  pure software, shift-and-add multiply, 24-bit accumulator
  b0  pure software, repeated-addition multiply, 24-bit accumulator

Every variant computes exactly the same integers as cnn/cnn_ref.py and ends
with the predicted class on the LEDs (port 0x02). The timed region is
bracketed by OUT 0x02 <- 1 / <- 2 (setup and the final argmax are not
counted), exactly like the MLP bench.

Algorithm (all variants): for each kernel k and output row r, compute the 6
conv+ReLU pixels of row r into a 2-row ping-pong buffer (ROWA/ROWB); every
odd row, max-pool the two buffered rows into POOLED. The 3x3 window walk per
pixel is 3 taps, skip 5, 3 taps, skip 5, 3 taps (rows advance by 8, taps by
1), plus a 10th MAC for the bias folded as virtual activation 127.

Data-memory layout:
  IMG    0..63    image (streamed in)
  CONVW 64..103   4 kernels x (9 weights + bias) (streamed in)
  ROWA 112..117   conv row buffer A (even rows)
  ROWB 118..123   conv row buffer B (odd rows)
  POOL 128..163   4 kernels x 9 pooled features
  LOG  168..171   logits (offset binary)
  S_*  176..      scratch (pointers, counters, 24-bit accumulator)
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
DATA = ROOT / "data"
OUT = ROOT.parent / "tests" / "cnn"

IMEM_WORDS = 512

IMG, CONVW = 0, 64
ROWA, ROWB = 112, 118
POOL, LOG = 128, 168

# scratch cells
S_KB, S_WR, S_RB, S_AP, S_WP = 176, 177, 178, 179, 180
S_A0, S_A1, S_A2, S_SGN = 181, 182, 183, 184
S_PC, S_RC, S_KC, S_PP, S_PR = 185, 186, 187, 188, 189
S_FC, S_FJ, S_LP, S_U, S_V, S_BF, S_PLC = 190, 191, 192, 193, 194, 195, 196

SAMPLE_BYTES = 252          # 64 img + 4x10 conv + 4x37 fc

_UID = [0]


def uid():
    _UID[0] += 1
    return _UID[0]


def gen_stream(m):
    """One stream.hex for all samples: per sample 252 bytes."""
    lines = []
    for s in m["samples"]:
        lines += [f"{v:02X}" for v in s["x"]]
        for k in range(m["nk"]):
            lines += [f"{v & 0xFF:02X}" for v in m["conv_w"][k]]
        for c in range(m["k"]):
            lines += [f"{v & 0xFF:02X}" for v in m["fc_w"][c]]
    assert len(lines) == len(m["samples"]) * SAMPLE_BYTES
    (DATA / "stream.hex").write_text("\n".join(lines) + "\n")
    return len(lines)


def marker(v):
    return [f"        LDI  R0, {v}", "        OUT  0x02, R0          ; timing marker"]


def argmax4():
    """Logits are offset-binary, so an unsigned compare orders them."""
    u = uid()
    return [
        f"        LDI  R7, {LOG}",
        "        LD   R1, [R7]          ; best = logit 0",
        "        LDI  R6, 0             ; best class",
        "        LDI  R5, 1             ; candidate class",
        "        LDI  R4, 1",
        f"am_{u}: ADD  R7, R7, R4",
        "        LD   R2, [R7]",
        "        CMP  R1, R2",
        f"        BCS  ask_{u}           ; ties keep the lower class",
        "        MOV  R1, R2",
        "        MOV  R6, R5",
        f"ask_{u}: ADD  R5, R5, R4",
        "        LDI  R0, 4",
        "        CMP  R5, R0",
        f"        BNE  am_{u}",
        "        OUT  0x02, R6          ; LEDs = predicted class",
        "        HLT",
    ]


def init_block(accel):
    """Unlock (a-variants only), stream image+convW into DMEM, init scratch."""
    out = []
    if accel:
        out += [
            "        LDI  R0, 0xA5",
            "        OUT  0x5F, R0          ; unlock accelerator",
            "        LDI  R0, 0x03",
            "        OUT  0x52, R0          ; clear acc + counters",
            f"        LDI  R0, %CONVSHIFT%",
            "        OUT  0x56, R0",
            "        LDI  R0, 0",
            "        OUT  0x58, R0          ; LUT bank 0 (ReLU)",
        ]
    out += [
        "        LDI  R4, 1",
        f"        LDI  R6, {IMG}",
        "        LDI  R7, 104",
    ]
    u = uid()
    out += [
        f"gi_{u}:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share",
        "                               ;  one pointer: 64 img + 40 convW)",
        "        ST   [R6], R5",
        "        ADD  R6, R6, R4",
        "        SUB  R7, R7, R4",
        f"        BNE  gi_{u}",
    ]
    for cell, val in [(S_KB, CONVW), (S_PP, POOL), (S_WR, ROWA),
                      (S_PR, 0), (S_KC, 4)]:
        out += [f"        LDI  R0, {cell}", f"        LDI  R5, {val}", "        ST   [R0], R5"]
    return out


def sw_clear24(mul):
    """acc = 0. b0 keeps it in R1:R2:R3, b1 in DMEM S_A0..A2."""
    if mul == "add":
        return ["        LDI  R1, 0", "        LDI  R2, 0", "        LDI  R3, 0"]
    return [
        "        LDI  R7, 0",
        f"        LDI  R0, {S_A0}",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_A1}",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_A2}",
        "        ST   [R0], R7",
    ]


def sw_mul_add(u):
    """b0: acc (R1:R2:R3) += a*w, one repeated add/sub per unit of |w|.

    R4 = a, R5 = w, R6 = 1, R7 = count. The w == 0 case exits at once
    (its CMP already set Z), otherwise the count loop runs |w| >= 1 times."""
    return [
        "        LDI  R0, 0",
        "        CMP  R5, R0",
        f"        BEQ  mx_{u}            ; w == 0: nothing to accumulate",
        f"        BPL  mp_{u}            ; w > 0: add loop",
        "        LDI  R0, 0xFF",
        "        XOR  R5, R5, R0",
        "        LDI  R0, 1",
        "        ADD  R5, R5, R0        ; R5 = |w| >= 1",
        "        MOV  R7, R5            ; count = |w|",
        f"mn_{u}:  SUB  R1, R1, R4        ; acc -= a",
        f"        BCS  mnc_{u}",
        "        LDI  R5, 1",
        "        SUB  R2, R2, R5",
        f"        BCS  mnc_{u}",
        "        SUB  R3, R3, R5",
        f"mnc_{u}: SUB  R7, R7, R6",
        f"        BNE  mn_{u}",
        f"        JMP  mx_{u}",
        f"mp_{u}:  MOV  R7, R5            ; count = w",
        f"mpp_{u}: ADD  R1, R1, R4        ; acc += a",
        f"        BCC  mpc_{u}",
        "        LDI  R5, 1",
        "        ADD  R2, R2, R5",
        f"        BCC  mpc_{u}",
        "        ADD  R3, R3, R5",
        f"mpc_{u}: SUB  R7, R7, R6",
        f"        BNE  mpp_{u}",
        f"mx_{u}:",
    ]


def sw_mul_shift(u):
    """b1: acc += a*w by shift-and-add, 24-bit acc in DMEM S_A0..A2.

    R1 = a, R2 = w, R3:R4 = product (hi:lo), R5 = bit counter, R6 = 1,
    R7 = pointer stage. The lo-carry is folded into the product high byte
    before the mid-byte add, so each byte sees exactly one conditional +/-1."""
    return [
        f"        LDI  R0, {S_SGN}",
        "        ST   [R0], R2          ; remember w",
        "        LDI  R5, 0",
        "        CMP  R2, R5",
        f"        BPL  ms_{u}",
        "        LDI  R5, 0xFF",
        "        XOR  R2, R2, R5",
        "        LDI  R5, 1",
        "        ADD  R2, R2, R5        ; R2 = |w|",
        f"ms_{u}:  LDI  R3, 0",
        "        LDI  R4, 0             ; product = 0",
        "        LDI  R5, 8",
        f"ml_{u}:  SHL  R4, R4            ; C = old product lo bit 7",
        f"        BCC  mla_{u}",
        "        SHL  R3, R3",
        "        OR   R3, R3, R6        ; hi |= 1",
        f"        JMP  mlb_{u}",
        f"mla_{u}: SHL  R3, R3            ; C discarded (product < 2^15)",
        f"mlb_{u}: SHL  R2, R2            ; next multiplier bit -> C",
        f"        BCC  mlz_{u}",
        "        ADD  R4, R4, R1        ; prod lo += a",
        f"        BCC  mlz_{u}",
        "        ADD  R3, R3, R6        ; prod hi += 1",
        f"mlz_{u}: SUB  R5, R5, R6",
        f"        BNE  ml_{u}",
        f"        LDI  R0, {S_SGN}",
        "        LD   R7, [R0]",
        "        LDI  R5, 0x80",
        "        AND  R7, R7, R5",
        f"        BEQ  ma_{u}            ; w >= 0: acc += product",
        f"msa_{u}: LDI  R0, {S_A0}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)",
        "        ST   [R0], R7",
        f"        BCS  nmd_{u}",
        "        ADD  R3, R3, R6        ; fold the lo borrow into prod hi",
        f"nmd_{u}: LDI  R0, {S_A1}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R3        ; acc mid -= prod hi",
        "        ST   [R0], R7",
        f"        BCS  nhi_{u}",
        f"        LDI  R0, {S_A2}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R6        ; acc hi -= borrow",
        "        ST   [R0], R7",
        f"nhi_{u}: JMP  msd_{u}",
        f"ma_{u}:  LDI  R0, {S_A0}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)",
        "        ST   [R0], R7",
        f"        BCC  pmd_{u}",
        "        ADD  R3, R3, R6        ; fold the lo carry into prod hi",
        f"pmd_{u}: LDI  R0, {S_A1}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R3        ; acc mid += prod hi",
        "        ST   [R0], R7",
        f"        BCC  phi_{u}",
        f"        LDI  R0, {S_A2}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R6        ; acc hi += carry",
        "        ST   [R0], R7",
        f"phi_{u}:",
        f"msd_{u}:",
    ]


def sw_requant(u, shift, act):
    """R5 = act(sat8(acc24 >>> shift)) with the acc in R1(lo) R2(mid) R3(hi).

    Arithmetic shift via logical SHRs with sign refill. After the loop R7 is
    exactly 0, so it doubles as the zero constant in the saturation checks."""
    out = [
        f"        LDI  R7, {shift}",
        "        LDI  R5, 0x80",
    ]
    if shift > 0:
        out += [
            f"rq_{u}:  AND  R4, R3, R5        ; keep sign bit of hi",
            "        SHR  R1, R1",
            "        SHR  R2, R2",
            f"        BCC  rqa_{u}",
            "        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7",
            f"rqa_{u}: SHR  R3, R3",
            f"        BCC  rqb_{u}",
            "        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7",
            f"rqb_{u}: OR   R3, R3, R4         ; refill the sign bit",
            "        SUB  R7, R7, R6",
            f"        BNE  rq_{u}",
        ]
    out += [
        "        AND  R4, R3, R5         ; sign of the shifted value",
        f"        BNE  rqn_{u}",
        "        CMP  R3, R7             ; hi == 0?",
        f"        BNE  rqm_{u}",
        "        CMP  R2, R7",
        f"        BNE  rqm_{u}",
        "        AND  R4, R1, R5",
        f"        BNE  rqm_{u}            ; lo >= 128",
    ]
    if act == "relu":
        out += [
            "        MOV  R5, R1             ; 0..127 passes through",
            f"        JMP  rqd_{u}",
            f"rqm_{u}: LDI  R5, 127",
            f"        JMP  rqd_{u}",
            f"rqn_{u}: LDI  R5, 0              ; ReLU: negative -> 0",
            f"rqd_{u}:",
        ]
    else:
        out += [
            "        OR   R5, R1, R5         ; 0..127 -> 128..255",
            f"        JMP  rqd_{u}",
            f"rqm_{u}: LDI  R5, 0xFF           ; +127 -> 0xFF",
            f"        JMP  rqd_{u}",
            f"rqn_{u}: LDI  R5, 0",
            "        LDI  R4, 0xFF",
            "        CMP  R3, R4",
            f"        BNE  rqd_{u}            ; < -256: 0x00 (-128)",
            "        CMP  R2, R4",
            f"        BNE  rqd_{u}",
            "        LDI  R4, 0x80",
            "        AND  R4, R1, R4         ; mask in R4: R5 holds the result",
            f"        BEQ  rqd_{u}            ; -256..-129: keep 0x00",
            "        XOR  R5, R1, R4         ; -128..-1 -> 0..127",
            f"rqd_{u}:",
        ]
    return out


def conv_sw(mul, shift, act):
    """b-variant fused conv+pool: k/r/pixel loops with a looped tap walk.

    Per pixel the 9 image taps loop over u (3 rows) x v (3 cols); the 10th
    tap is the bias folded as activation 127. The last u row runs 4 taps and
    the one with U==1 and V==1 takes a=127; both pointers advance on every
    tap (S_AP is reloaded from S_RB each pixel), so one shared multiply body
    serves all ten MACs."""
    out = []
    out += ["        LDI  R6, 1", f"        LDI  R0, {S_RB}", f"        LDI  R5, {IMG}",
            "        ST   [R0], R5"]
    k = uid()
    r = uid()
    p = uid()
    out += [
        f"        LDI  R0, {S_KC}",
        "        LDI  R5, 4",
        "        ST   [R0], R5",
        f"kl_{k}:  LDI  R0, {S_RC}",
        "        LDI  R5, 6",
        "        ST   [R0], R5",
        f"rl_{r}:  LDI  R0, {S_PC}",
        "        LDI  R5, 6",
        "        ST   [R0], R5",
        f"pl_{p}:",
    ]
    out += sw_clear24(mul)
    out += [
        f"        LDI  R0, {S_KB}",
        "        LD   R7, [R0]",
        f"        LDI  R0, {S_WP}",
        "        ST   [R0], R7          ; w-ptr = kernel base (10 weights)",
        f"        LDI  R0, {S_RB}",
        "        LD   R7, [R0]",
        f"        LDI  R0, {S_AP}",
        "        ST   [R0], R7          ; a-ptr = row base",
        f"        LDI  R0, {S_U}",
        "        LDI  R7, 3",
        "        ST   [R0], R7",
    ]
    uu = uid()
    vv = uid()
    out += [
        f"ul_{uu}: LDI  R0, {S_V}",
        "        LDI  R7, 3",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_U}",
        "        LD   R7, [R0]",
        "        CMP  R7, R6",
        f"        BNE  vg_{uu}",
        f"        LDI  R0, {S_V}",
        "        LDI  R7, 4",
        "        ST   [R0], R7          ; last u: its 4th tap is the bias",
        f"vg_{uu}:",
        f"vl_{vv}:"]
    out += [
        f"        LDI  R0, {S_U}",
        "        LD   R7, [R0]",
        "        CMP  R7, R6",
        f"        BNE  bi_{vv}",
        f"        LDI  R0, {S_V}",
        "        LD   R7, [R0]",
        "        CMP  R7, R6",
        f"        BEQ  bt_{vv}          ; last u, V==1: the bias tap",
        f"bi_{vv}: LDI  R0, {S_AP}",
        "        LD   R7, [R0]",
        "        LD   R4, [R7]          ; a = *a_ptr" if mul == "add" else "        LD   R1, [R7]          ; a = *a_ptr",
        f"        JMP  ag_{vv}",
        f"bt_{vv}: LDI  R4, 127" if mul == "add" else f"bt_{vv}: LDI  R1, 127",
        f"ag_{vv}: LDI  R0, {S_WP}",
        "        LD   R7, [R0]",
        "        LD   R5, [R7]          ; w = *w_ptr" if mul == "add" else "        LD   R2, [R7]          ; w = *w_ptr",
    ]
    out += sw_mul_add(vv) if mul == "add" else sw_mul_shift(vv)
    out += [
        f"        LDI  R0, {S_AP}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R6        ; both pointers advance on every tap",
        "        ST   [R0], R7",
        f"aw_{vv}: LDI  R0, {S_WP}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R6",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_V}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R6",
        "        ST   [R0], R7",
        f"        BNE  vl_{vv}",
        f"        LDI  R0, {S_AP}",
        "        LD   R7, [R0]",
        "        LDI  R5, 5",
        "        ADD  R7, R7, R5        ; skip to the next image row",
        f"        LDI  R0, {S_AP}",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_U}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R6",
        "        ST   [R0], R7",
        f"        BNE  ul_{uu}",
    ]
    if mul == "shift":
        out += [
            f"        LDI  R0, {S_A0}",
            "        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM",
            f"        LDI  R0, {S_A1}",
            "        LD   R2, [R0]",
            f"        LDI  R0, {S_A2}",
            "        LD   R3, [R0]",
        ]
    out += sw_requant(p, shift, "relu")
    out += [
        f"        LDI  R0, {S_WR}",
        "        LD   R7, [R0]",
        "        ST   [R7], R5          ; store conv+ReLU pixel",
        "        ADD  R7, R7, R6",
        f"        LDI  R0, {S_WR}",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_RB}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R6        ; next pixel's row base",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_PC}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R6",
        "        ST   [R0], R7",
        f"        BNE  pl_{p}",
    ]
    # row end: pool every second row (ROWA = even row, ROWB = odd row),
    # then point S_WR at the other buffer and advance the row base.
    out += [
        "        LDI  R4, 1",
        f"        LDI  R0, {S_PR}",
        "        LD   R7, [R0]",
        "        XOR  R7, R7, R6",
        "        ST   [R0], R7",
        f"        BEQ  po_{r}            ; odd row done: pool the pair",
        f"        LDI  R0, {S_WR}",
        f"        LDI  R5, {ROWB}",
        "        ST   [R0], R5          ; even row done: next row -> ROWB",
        f"        JMP  wr_{r}",
        f"po_{r}:",
    ]
    out += pool_block("sw", r)
    out += [
        f"        LDI  R0, {S_WR}",
        f"        LDI  R5, {ROWA}",
        "        ST   [R0], R5          ; odd row done: next row -> ROWA",
        f"wr_{r}: LDI  R6, 1",
        f"        LDI  R0, {S_RB}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R4",
        "        ADD  R7, R7, R4        ; next row starts 2 bytes later",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_RC}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R4",
        "        ST   [R0], R7",
        f"        BNE  rl_{r}",
        f"        LDI  R0, {S_KB}",
        "        LD   R7, [R0]",
        "        LDI  R5, 10",
        "        ADD  R7, R7, R5        ; next kernel's weight base",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_RB}",
        f"        LDI  R5, {IMG}",
        "        ST   [R0], R5",
        f"        LDI  R0, {S_KC}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R6",
        "        ST   [R0], R7",
        f"        BNE  kl_{k}",
    ]
    return out


def pool_block(family, u):
    """Max-pool ROWA/ROWB (2x2) into *S_PP and advance S_PP.

    R3 walks ROWA and R7 walks ROWB; each iteration covers one pool column
    by loading [p] and [p+1] from both buffers, so cols {0,1},{2,3},{4,5}.
    R6 is the pooled write ptr (loaded from S_PP), R1/R5 are candidates,
    R4 = 1. The loop counter lives in R2 for the software family (R2 is
    dead between pixels) and in S_PLC for the accelerator family (R2 is
    the live image walker there)."""
    out = [
        f"        LDI  R3, {ROWA}",
        f"        LDI  R7, {ROWB}",
        f"        LDI  R0, {S_PP}",
        "        LD   R6, [R0]",
    ]
    if family == "sw":
        out += ["        LDI  R2, 3"]
    else:
        out += [f"        LDI  R0, {S_PLC}", "        LDI  R5, 3",
                "        ST   [R0], R5"]
    out += [
        f"plp_{u}: LD   R1, [R3]",
        "        ADD  R3, R3, R4",
        "        LD   R5, [R3]",
        "        CMP  R1, R5",
        f"        BCS  pa1_{u}",
        "        MOV  R1, R5",
        f"pa1_{u}: LD   R5, [R7]",
        "        CMP  R1, R5",
        f"        BCS  pa2_{u}",
        "        MOV  R1, R5",
        f"pa2_{u}: ADD  R7, R7, R4",
        "        LD   R5, [R7]",
        "        CMP  R1, R5",
        f"        BCS  pa3_{u}",
        "        MOV  R1, R5",
        f"pa3_{u}: ST   [R6], R1",
        "        ADD  R6, R6, R4",
        "        ADD  R3, R3, R4",
        "        ADD  R7, R7, R4",
    ]
    if family == "sw":
        out += ["        SUB  R2, R2, R4", f"        BNE  plp_{u}"]
    else:
        out += [
            f"        LDI  R0, {S_PLC}",
            "        LD   R5, [R0]",
            "        SUB  R5, R5, R4",
            "        ST   [R0], R5",
            f"        BNE  plp_{u}",
        ]
    out += [f"        LDI  R0, {S_PP}", "        ST   [R0], R6"]
    return out


def fc_sw(mul, shift, act):
    """b-variant FC: 4 classes x (36 features + bias), weights from port 0x46.

    Features are read through S_AP (the a-ptr cell, free after the conv
    phase) because both multiply bodies trash every register; logits are
    stored via S_LP staged through R7."""
    u = uid()
    k = uid()
    out = [
        f"        LDI  R0, {S_FC}",
        "        LDI  R5, 4",
        "        ST   [R0], R5",
        f"        LDI  R0, {S_LP}",
        f"        LDI  R5, {LOG}",
        "        ST   [R0], R5",
        f"        LDI  R0, {S_AP}",
        f"        LDI  R5, {POOL}",
        "        ST   [R0], R5",
        "        LDI  R6, 1",
        f"fc_{k}: LDI  R0, {S_AP}",
        f"        LDI  R5, {POOL}",
        "        ST   [R0], R5          ; features restart for each class",
    ]
    out += sw_clear24(mul)
    out += [
        f"        LDI  R0, {S_FJ}",
        "        LDI  R5, 36",
        "        ST   [R0], R5",
    ]
    if mul == "add":
        load_a = f"fj_{u}:  LDI  R0, {S_AP}\n        LD   R7, [R0]\n        LD   R4, [R7]          ; a = feature\n        IN   R5, 0x46          ; w = next streamed weight"
    else:
        load_a = f"fj_{u}:  LDI  R0, {S_AP}\n        LD   R7, [R0]\n        LD   R1, [R7]          ; a = feature\n        IN   R2, 0x46          ; w = next streamed weight"
    out += load_a.split("\n")
    out += sw_mul_add(u) if mul == "add" else sw_mul_shift(u)
    out += [
        f"        LDI  R0, {S_AP}",
        "        LD   R7, [R0]",
        "        ADD  R7, R7, R6        ; next feature",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_FJ}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R6",
        "        ST   [R0], R7",
        f"        BNE  fj_{u}",
    ]
    if mul == "add":
        out += ["        LDI  R4, 127", "        IN   R5, 0x46"]
    else:
        out += ["        LDI  R1, 127", "        IN   R2, 0x46"]
    out += sw_mul_add(uid()) if mul == "add" else sw_mul_shift(uid())
    if mul == "shift":
        out += [
            f"        LDI  R0, {S_A0}",
            "        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM",
            f"        LDI  R0, {S_A1}",
            "        LD   R2, [R0]",
            f"        LDI  R0, {S_A2}",
            "        LD   R3, [R0]",
        ]
    out += sw_requant(uid(), shift, "offset")
    out += [
        f"        LDI  R0, {S_LP}",
        "        LD   R7, [R0]",
        "        ST   [R7], R5          ; store logit",
        "        ADD  R7, R7, R6",
        f"        LDI  R0, {S_LP}",
        "        ST   [R0], R7",
        f"        LDI  R0, {S_FC}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R6",
        "        ST   [R0], R7",
        f"        BNE  fc_{k}",
    ]
    return out


def conv_accel(act):
    """a-variant fused conv+pool: unrolled 3x3 tap walk per pixel.

    R2 walks image row bases, R1 the kernel weights (reloaded per pixel),
    R3 the tap pointer, R6 the row-buffer write ptr, R7 the pixel counter."""
    k = uid()
    r = uid()
    p = uid()
    tap = ["        LD   R5, [R3]",
           "        OUT  0x50, R5",
           "        LD   R5, [R1]",
           "        OUT  0x51, R5",
           "        ADD  R3, R3, R4",
           "        ADD  R1, R1, R4"]
    out = [f"        LDI  R2, {IMG}",
           f"        LDI  R0, {S_KC}",
           "        LDI  R5, 4",
           "        ST   [R0], R5",
           f"kl_{k}:  LDI  R0, {S_RC}",
           "        LDI  R5, 6",
           "        ST   [R0], R5",
           f"rl_{r}:  LDI  R0, {S_WR}",
           "        LD   R6, [R0]",
           "        LDI  R7, 6",
           f"pl_{p}:  LDI  R0, 0x01",
           "        OUT  0x52, R0          ; clear acc",
           f"        LDI  R0, {S_KB}",
           "        LD   R1, [R0]",
           "        MOV  R3, R2            ; tap ptr = row 0"]
    for _ in range(3):
        out += tap
    out += ["        LDI  R5, 5", "        ADD  R3, R3, R5"]
    for _ in range(3):
        out += tap
    out += ["        LDI  R5, 5", "        ADD  R3, R3, R5"]
    for _ in range(3):
        out += tap
    out += [
        "        LDI  R5, 127",
        "        OUT  0x50, R5          ; bias as virtual activation",
        "        LD   R5, [R1]",
        "        OUT  0x51, R5",
    ]
    if act == "lut":
        out += ["        IN   R5, 0x59          ; LUT[sat8(acc>>>shift)]"]
    else:
        out += [
            "        IN   R5, 0x57          ; sat8(acc>>>shift)",
            "        LDI  R0, 0",
            "        CMP  R5, R0",
            f"        BPL  pxok_{p}",
            "        LDI  R5, 0             ; ReLU: negative -> 0",
            f"pxok_{p}:",
        ]
    out += [
        "        ST   [R6], R5",
        "        ADD  R6, R6, R4",
        "        ADD  R2, R2, R4        ; next pixel's row base",
        "        SUB  R7, R7, R4",
        f"        BNE  pl_{p}",
        f"        LDI  R0, {S_PR}",
        "        LD   R7, [R0]",
        "        LDI  R5, 1",
        "        XOR  R7, R7, R5",
        "        ST   [R0], R7",
        f"        BEQ  po_{r}            ; odd row: pool the pair",
        f"        JMP  rw_{r}",
        f"po_{r}:",
    ]
    out += pool_block("accel", r)
    out += [
        f"rw_{r}:  LDI  R0, {S_WR}",
        "        LD   R7, [R0]",
        f"        LDI  R5, {ROWB}",
        "        CMP  R7, R5",
        f"        BCS  we_{r}",
        "        ST   [R0], R5          ; was ROWA -> next ROWB",
        f"        JMP  wd_{r}",
        f"we_{r}:  LDI  R5, {ROWA}",
        "        ST   [R0], R5",
        f"wd_{r}:  ADD  R2, R2, R4",
        "        ADD  R2, R2, R4        ; next row starts 2 bytes later",
        f"        LDI  R0, {S_RC}",
        "        LD   R5, [R0]",
        "        SUB  R5, R5, R4",
        "        ST   [R0], R5",
        f"        BNE  rl_{r}",
        f"        LDI  R0, {S_KB}",
        "        LD   R7, [R0]",
        "        LDI  R5, 10",
        "        ADD  R7, R7, R5        ; next kernel's weight base",
        "        ST   [R0], R7",
        f"        LDI  R2, {IMG}",
        f"        LDI  R0, {S_KC}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R4",
        "        ST   [R0], R7",
        f"        BNE  kl_{k}",
    ]
    return out


def fc_accel(act):
    """a-variant FC: 4 classes, features from POOLED, weights from port 0x46."""
    u = uid()
    k = uid()
    out = [
        f"        LDI  R6, {LOG}",
        f"        LDI  R0, {S_FC}",
        "        LDI  R5, 4",
        "        ST   [R0], R5",
        f"fc_{k}:  LDI  R0, 0x01",
        "        OUT  0x52, R0          ; clear acc",
        f"        LDI  R2, {POOL}",
        "        LDI  R7, 36",
        f"fj_{u}:  LD   R5, [R2]",
        "        OUT  0x50, R5          ; a = feature",
        "        IN   R5, 0x46          ; w = next streamed weight",
        "        OUT  0x51, R5",
        "        ADD  R2, R2, R4",
        "        SUB  R7, R7, R4",
        f"        BNE  fj_{u}",
        "        LDI  R5, 127",
        "        OUT  0x50, R5          ; bias as virtual activation",
        "        IN   R5, 0x46",
        "        OUT  0x51, R5",
    ]
    if act == "lut":
        out += ["        IN   R5, 0x59          ; LUT bank 2 (offset binary)"]
    else:
        out += [
            "        IN   R5, 0x57",
            "        LDI  R0, 0x80",
            "        XOR  R5, R5, R0        ; signed -> offset binary",
        ]
    out += [
        "        ST   [R6], R5",
        "        ADD  R6, R6, R4",
        f"        LDI  R0, {S_FC}",
        "        LD   R7, [R0]",
        "        SUB  R7, R7, R4",
        "        ST   [R0], R7",
        f"        BNE  fc_{k}",
    ]
    return out


def prog_a(m, act):
    out = init_block(True) + marker(1)
    out += conv_accel(act)
    out += [
        f"        LDI  R0, {m['fc_shift']}",
        "        OUT  0x56, R0          ; requant shift for the FC layer",
        "        LDI  R0, 2",
        "        OUT  0x58, R0          ; LUT bank 2 (offset binary)",
    ]
    out += fc_accel(act) + marker(2) + argmax4()
    return [ln.replace("%CONVSHIFT%", str(m["conv_shift"])) for ln in out]


def prog_b(m, mul):
    out = init_block(False) + marker(1)
    out += conv_sw(mul, m["conv_shift"], "relu")
    out += fc_sw(mul, m["fc_shift"], "offset")
    out += marker(2) + argmax4()
    return out


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
    # static worst-case accumulator: 10 MACs of 127*127 each, far below 2^23,
    # so the software 24-bit accumulator can never wrap (like the hardware).
    assert 10 * 127 * 127 < (1 << 23)
    OUT.mkdir(parents=True, exist_ok=True)
    n_stream = gen_stream(m)
    sizes = {}
    for idx, s in enumerate(m["samples"]):
        progs = {
            "a0": prog_a(m, "sw"),
            "a2": prog_a(m, "lut"),
            "b1": prog_b(m, "shift"),
            "b0": prog_b(m, "add"),
        }
        for name, lines in progs.items():
            n = n_instrs(lines)
            if n > IMEM_WORDS:
                raise SystemExit(f"s{idx:02d}_{name}: {n} instructions > IMEM {IMEM_WORDS}")
            sizes[name] = max(sizes.get(name, 0), n)
            (OUT / f"s{idx:02d}_{name}.asm").write_text("\n".join(lines) + "\n")
    print(f"wrote {len(m['samples'])} samples x {len(sizes)} variants to {OUT} "
          f"(stream: {n_stream} bytes)")
    print("max instructions: " + ", ".join(f"{k}={v}" for k, v in sorted(sizes.items())))


if __name__ == "__main__":
    main()
