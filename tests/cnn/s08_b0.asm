        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_314:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_314
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
kl_315:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_316:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_317:
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
ul_318: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_318
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_318:
vl_319:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_319
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_319          ; last u, V==1: the bias tap
bi_319: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_319
bt_319: LDI  R4, 127
ag_319: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_319            ; w == 0: nothing to accumulate
        BPL  mp_319            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_319:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_319
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_319
        SUB  R3, R3, R5
mnc_319: SUB  R7, R7, R6
        BNE  mn_319
        JMP  mx_319
mp_319:  MOV  R7, R5            ; count = w
mpp_319: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_319
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_319
        ADD  R3, R3, R5
mpc_319: SUB  R7, R7, R6
        BNE  mpp_319
mx_319:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_319: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_319
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
        BNE  ul_318
        LDI  R7, 8
        LDI  R5, 0x80
rq_317:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_317
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_317: SHR  R3, R3
        BCC  rqb_317
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_317: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_317
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_317
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_317
        CMP  R2, R7
        BNE  rqm_317
        AND  R4, R1, R5
        BNE  rqm_317            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_317
rqm_317: LDI  R5, 127
        JMP  rqd_317
rqn_317: LDI  R5, 0              ; ReLU: negative -> 0
rqd_317:
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
        BNE  pl_317
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_316            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_316
po_316:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_316: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_316
        MOV  R1, R5
pa1_316: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_316
        MOV  R1, R5
pa2_316: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_316
        MOV  R1, R5
pa3_316: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_316
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_316: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_316
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
        BNE  kl_315
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
fc_321: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_320:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_320            ; w == 0: nothing to accumulate
        BPL  mp_320            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_320:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_320
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_320
        SUB  R3, R3, R5
mnc_320: SUB  R7, R7, R6
        BNE  mn_320
        JMP  mx_320
mp_320:  MOV  R7, R5            ; count = w
mpp_320: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_320
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_320
        ADD  R3, R3, R5
mpc_320: SUB  R7, R7, R6
        BNE  mpp_320
mx_320:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_320
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_322            ; w == 0: nothing to accumulate
        BPL  mp_322            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_322:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_322
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_322
        SUB  R3, R3, R5
mnc_322: SUB  R7, R7, R6
        BNE  mn_322
        JMP  mx_322
mp_322:  MOV  R7, R5            ; count = w
mpp_322: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_322
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_322
        ADD  R3, R3, R5
mpc_322: SUB  R7, R7, R6
        BNE  mpp_322
mx_322:
        LDI  R7, 8
        LDI  R5, 0x80
rq_323:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_323
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_323: SHR  R3, R3
        BCC  rqb_323
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_323: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_323
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_323
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_323
        CMP  R2, R7
        BNE  rqm_323
        AND  R4, R1, R5
        BNE  rqm_323            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_323
rqm_323: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_323
rqn_323: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_323            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_323
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_323            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_323:
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
        BNE  fc_321
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_324: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_324           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_324: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_324
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
