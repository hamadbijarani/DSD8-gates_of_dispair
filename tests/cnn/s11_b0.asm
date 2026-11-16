        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_422:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_422
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
kl_423:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_424:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_425:
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
ul_426: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_426
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_426:
vl_427:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_427
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_427          ; last u, V==1: the bias tap
bi_427: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_427
bt_427: LDI  R4, 127
ag_427: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_427            ; w == 0: nothing to accumulate
        BPL  mp_427            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_427:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_427
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_427
        SUB  R3, R3, R5
mnc_427: SUB  R7, R7, R6
        BNE  mn_427
        JMP  mx_427
mp_427:  MOV  R7, R5            ; count = w
mpp_427: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_427
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_427
        ADD  R3, R3, R5
mpc_427: SUB  R7, R7, R6
        BNE  mpp_427
mx_427:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_427: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_427
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
        BNE  ul_426
        LDI  R7, 8
        LDI  R5, 0x80
rq_425:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_425
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_425: SHR  R3, R3
        BCC  rqb_425
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_425: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_425
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_425
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_425
        CMP  R2, R7
        BNE  rqm_425
        AND  R4, R1, R5
        BNE  rqm_425            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_425
rqm_425: LDI  R5, 127
        JMP  rqd_425
rqn_425: LDI  R5, 0              ; ReLU: negative -> 0
rqd_425:
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
        BNE  pl_425
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_424            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_424
po_424:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_424: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_424
        MOV  R1, R5
pa1_424: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_424
        MOV  R1, R5
pa2_424: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_424
        MOV  R1, R5
pa3_424: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_424
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_424: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_424
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
        BNE  kl_423
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
fc_429: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_428:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_428            ; w == 0: nothing to accumulate
        BPL  mp_428            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_428:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_428
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_428
        SUB  R3, R3, R5
mnc_428: SUB  R7, R7, R6
        BNE  mn_428
        JMP  mx_428
mp_428:  MOV  R7, R5            ; count = w
mpp_428: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_428
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_428
        ADD  R3, R3, R5
mpc_428: SUB  R7, R7, R6
        BNE  mpp_428
mx_428:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_428
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_430            ; w == 0: nothing to accumulate
        BPL  mp_430            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_430:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_430
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_430
        SUB  R3, R3, R5
mnc_430: SUB  R7, R7, R6
        BNE  mn_430
        JMP  mx_430
mp_430:  MOV  R7, R5            ; count = w
mpp_430: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_430
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_430
        ADD  R3, R3, R5
mpc_430: SUB  R7, R7, R6
        BNE  mpp_430
mx_430:
        LDI  R7, 8
        LDI  R5, 0x80
rq_431:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_431
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_431: SHR  R3, R3
        BCC  rqb_431
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_431: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_431
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_431
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_431
        CMP  R2, R7
        BNE  rqm_431
        AND  R4, R1, R5
        BNE  rqm_431            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_431
rqm_431: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_431
rqn_431: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_431            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_431
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_431            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_431:
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
        BNE  fc_429
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_432: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_432           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_432: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_432
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
