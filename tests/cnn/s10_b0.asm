        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_386:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_386
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
kl_387:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_388:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_389:
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
ul_390: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_390
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_390:
vl_391:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_391
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_391          ; last u, V==1: the bias tap
bi_391: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_391
bt_391: LDI  R4, 127
ag_391: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_391            ; w == 0: nothing to accumulate
        BPL  mp_391            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_391:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_391
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_391
        SUB  R3, R3, R5
mnc_391: SUB  R7, R7, R6
        BNE  mn_391
        JMP  mx_391
mp_391:  MOV  R7, R5            ; count = w
mpp_391: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_391
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_391
        ADD  R3, R3, R5
mpc_391: SUB  R7, R7, R6
        BNE  mpp_391
mx_391:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_391: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_391
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
        BNE  ul_390
        LDI  R7, 8
        LDI  R5, 0x80
rq_389:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_389
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_389: SHR  R3, R3
        BCC  rqb_389
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_389: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_389
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_389
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_389
        CMP  R2, R7
        BNE  rqm_389
        AND  R4, R1, R5
        BNE  rqm_389            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_389
rqm_389: LDI  R5, 127
        JMP  rqd_389
rqn_389: LDI  R5, 0              ; ReLU: negative -> 0
rqd_389:
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
        BNE  pl_389
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_388            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_388
po_388:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_388: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_388
        MOV  R1, R5
pa1_388: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_388
        MOV  R1, R5
pa2_388: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_388
        MOV  R1, R5
pa3_388: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_388
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_388: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_388
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
        BNE  kl_387
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
fc_393: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_392:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_392            ; w == 0: nothing to accumulate
        BPL  mp_392            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_392:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_392
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_392
        SUB  R3, R3, R5
mnc_392: SUB  R7, R7, R6
        BNE  mn_392
        JMP  mx_392
mp_392:  MOV  R7, R5            ; count = w
mpp_392: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_392
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_392
        ADD  R3, R3, R5
mpc_392: SUB  R7, R7, R6
        BNE  mpp_392
mx_392:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_392
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_394            ; w == 0: nothing to accumulate
        BPL  mp_394            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_394:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_394
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_394
        SUB  R3, R3, R5
mnc_394: SUB  R7, R7, R6
        BNE  mn_394
        JMP  mx_394
mp_394:  MOV  R7, R5            ; count = w
mpp_394: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_394
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_394
        ADD  R3, R3, R5
mpc_394: SUB  R7, R7, R6
        BNE  mpp_394
mx_394:
        LDI  R7, 8
        LDI  R5, 0x80
rq_395:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_395
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_395: SHR  R3, R3
        BCC  rqb_395
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_395: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_395
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_395
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_395
        CMP  R2, R7
        BNE  rqm_395
        AND  R4, R1, R5
        BNE  rqm_395            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_395
rqm_395: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_395
rqn_395: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_395            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_395
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_395            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_395:
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
        BNE  fc_393
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_396: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_396           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_396: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_396
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
