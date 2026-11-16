        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_2042:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_2042
        LDI  R0, 176
        LDI  R5, 64
        ST   [R0], R5
        LDI  R0, 188
        LDI  R5, 128
        ST   [R0], R5
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5
        LDI  R0, 189
        LDI  R5, 0
        ST   [R0], R5
        LDI  R0, 187
        LDI  R5, 4
        ST   [R0], R5
        LDI  R0, 1
        OUT  0x02, R0          ; timing marker
        LDI  R6, 1
        LDI  R0, 178
        LDI  R5, 0
        ST   [R0], R5
        LDI  R0, 187
        LDI  R5, 4
        ST   [R0], R5
kl_2043:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_2044:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_2045:
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 176
        LD   R7, [R0]
        LDI  R0, 180
        ST   [R0], R7          ; w-ptr = kernel base (10 weights)
        LDI  R0, 178
        LD   R7, [R0]
        LDI  R0, 179
        ST   [R0], R7          ; a-ptr = row base
        LDI  R0, 193
        LDI  R7, 3
        ST   [R0], R7
ul_2046: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_2046
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_2046:
vl_2047:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_2047
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_2047          ; last u, V==1: the bias tap
bi_2047: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_2047
bt_2047: LDI  R4, 127
ag_2047: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_2047            ; w == 0: nothing to accumulate
        BPL  mp_2047            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_2047:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_2047
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_2047
        SUB  R3, R3, R5
mnc_2047: SUB  R7, R7, R6
        BNE  mn_2047
        JMP  mx_2047
mp_2047:  MOV  R7, R5            ; count = w
mpp_2047: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_2047
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_2047
        ADD  R3, R3, R5
mpc_2047: SUB  R7, R7, R6
        BNE  mpp_2047
mx_2047:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_2047: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_2047
        LDI  R0, 179
        LD   R7, [R0]
        LDI  R5, 5
        ADD  R7, R7, R5        ; skip to the next image row
        LDI  R0, 179
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  ul_2046
        LDI  R7, 8
        LDI  R5, 0x80
rq_2045:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_2045
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_2045: SHR  R3, R3
        BCC  rqb_2045
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_2045: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_2045
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_2045
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_2045
        CMP  R2, R7
        BNE  rqm_2045
        AND  R4, R1, R5
        BNE  rqm_2045            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_2045
rqm_2045: LDI  R5, 127
        JMP  rqd_2045
rqn_2045: LDI  R5, 0              ; ReLU: negative -> 0
rqd_2045:
        LDI  R0, 177
        LD   R7, [R0]
        ST   [R7], R5          ; store conv+ReLU pixel
        ADD  R7, R7, R6
        LDI  R0, 177
        ST   [R0], R7
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next pixel's row base
        ST   [R0], R7
        LDI  R0, 185
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  pl_2045
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_2044            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_2044
po_2044:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_2044: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_2044
        MOV  R1, R5
pa1_2044: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_2044
        MOV  R1, R5
pa2_2044: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_2044
        MOV  R1, R5
pa3_2044: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_2044
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_2044: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_2044
        LDI  R0, 176
        LD   R7, [R0]
        LDI  R5, 10
        ADD  R7, R7, R5        ; next kernel's weight base
        ST   [R0], R7
        LDI  R0, 178
        LDI  R5, 0
        ST   [R0], R5
        LDI  R0, 187
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  kl_2043
        LDI  R0, 190
        LDI  R5, 4
        ST   [R0], R5
        LDI  R0, 192
        LDI  R5, 168
        ST   [R0], R5
        LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5
        LDI  R6, 1
fc_2049: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_2048:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_2048            ; w == 0: nothing to accumulate
        BPL  mp_2048            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_2048:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_2048
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_2048
        SUB  R3, R3, R5
mnc_2048: SUB  R7, R7, R6
        BNE  mn_2048
        JMP  mx_2048
mp_2048:  MOV  R7, R5            ; count = w
mpp_2048: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_2048
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_2048
        ADD  R3, R3, R5
mpc_2048: SUB  R7, R7, R6
        BNE  mpp_2048
mx_2048:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_2048
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_2050            ; w == 0: nothing to accumulate
        BPL  mp_2050            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_2050:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_2050
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_2050
        SUB  R3, R3, R5
mnc_2050: SUB  R7, R7, R6
        BNE  mn_2050
        JMP  mx_2050
mp_2050:  MOV  R7, R5            ; count = w
mpp_2050: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_2050
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_2050
        ADD  R3, R3, R5
mpc_2050: SUB  R7, R7, R6
        BNE  mpp_2050
mx_2050:
        LDI  R7, 8
        LDI  R5, 0x80
rq_2051:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_2051
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_2051: SHR  R3, R3
        BCC  rqb_2051
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_2051: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_2051
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_2051
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_2051
        CMP  R2, R7
        BNE  rqm_2051
        AND  R4, R1, R5
        BNE  rqm_2051            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_2051
rqm_2051: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_2051
rqn_2051: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_2051            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_2051
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_2051            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_2051:
        LDI  R0, 192
        LD   R7, [R0]
        ST   [R7], R5          ; store logit
        ADD  R7, R7, R6
        LDI  R0, 192
        ST   [R0], R7
        LDI  R0, 190
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fc_2049
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_2052: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_2052           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_2052: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_2052
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
