        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_1430:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_1430
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
kl_1431:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_1432:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_1433:
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
ul_1434: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_1434
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_1434:
vl_1435:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_1435
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_1435          ; last u, V==1: the bias tap
bi_1435: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_1435
bt_1435: LDI  R4, 127
ag_1435: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1435            ; w == 0: nothing to accumulate
        BPL  mp_1435            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1435:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1435
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1435
        SUB  R3, R3, R5
mnc_1435: SUB  R7, R7, R6
        BNE  mn_1435
        JMP  mx_1435
mp_1435:  MOV  R7, R5            ; count = w
mpp_1435: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1435
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1435
        ADD  R3, R3, R5
mpc_1435: SUB  R7, R7, R6
        BNE  mpp_1435
mx_1435:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_1435: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_1435
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
        BNE  ul_1434
        LDI  R7, 8
        LDI  R5, 0x80
rq_1433:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_1433
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_1433: SHR  R3, R3
        BCC  rqb_1433
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_1433: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_1433
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_1433
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_1433
        CMP  R2, R7
        BNE  rqm_1433
        AND  R4, R1, R5
        BNE  rqm_1433            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_1433
rqm_1433: LDI  R5, 127
        JMP  rqd_1433
rqn_1433: LDI  R5, 0              ; ReLU: negative -> 0
rqd_1433:
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
        BNE  pl_1433
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_1432            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_1432
po_1432:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_1432: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_1432
        MOV  R1, R5
pa1_1432: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_1432
        MOV  R1, R5
pa2_1432: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_1432
        MOV  R1, R5
pa3_1432: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_1432
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_1432: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_1432
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
        BNE  kl_1431
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
fc_1437: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_1436:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1436            ; w == 0: nothing to accumulate
        BPL  mp_1436            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1436:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1436
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1436
        SUB  R3, R3, R5
mnc_1436: SUB  R7, R7, R6
        BNE  mn_1436
        JMP  mx_1436
mp_1436:  MOV  R7, R5            ; count = w
mpp_1436: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1436
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1436
        ADD  R3, R3, R5
mpc_1436: SUB  R7, R7, R6
        BNE  mpp_1436
mx_1436:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_1436
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1438            ; w == 0: nothing to accumulate
        BPL  mp_1438            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1438:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1438
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1438
        SUB  R3, R3, R5
mnc_1438: SUB  R7, R7, R6
        BNE  mn_1438
        JMP  mx_1438
mp_1438:  MOV  R7, R5            ; count = w
mpp_1438: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1438
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1438
        ADD  R3, R3, R5
mpc_1438: SUB  R7, R7, R6
        BNE  mpp_1438
mx_1438:
        LDI  R7, 8
        LDI  R5, 0x80
rq_1439:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_1439
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_1439: SHR  R3, R3
        BCC  rqb_1439
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_1439: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_1439
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_1439
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_1439
        CMP  R2, R7
        BNE  rqm_1439
        AND  R4, R1, R5
        BNE  rqm_1439            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_1439
rqm_1439: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_1439
rqn_1439: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_1439            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_1439
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_1439            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_1439:
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
        BNE  fc_1437
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_1440: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_1440           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_1440: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_1440
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
