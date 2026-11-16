        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_602:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_602
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
kl_603:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_604:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_605:
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
ul_606: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_606
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_606:
vl_607:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_607
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_607          ; last u, V==1: the bias tap
bi_607: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_607
bt_607: LDI  R4, 127
ag_607: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_607            ; w == 0: nothing to accumulate
        BPL  mp_607            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_607:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_607
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_607
        SUB  R3, R3, R5
mnc_607: SUB  R7, R7, R6
        BNE  mn_607
        JMP  mx_607
mp_607:  MOV  R7, R5            ; count = w
mpp_607: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_607
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_607
        ADD  R3, R3, R5
mpc_607: SUB  R7, R7, R6
        BNE  mpp_607
mx_607:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_607: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_607
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
        BNE  ul_606
        LDI  R7, 8
        LDI  R5, 0x80
rq_605:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_605
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_605: SHR  R3, R3
        BCC  rqb_605
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_605: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_605
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_605
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_605
        CMP  R2, R7
        BNE  rqm_605
        AND  R4, R1, R5
        BNE  rqm_605            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_605
rqm_605: LDI  R5, 127
        JMP  rqd_605
rqn_605: LDI  R5, 0              ; ReLU: negative -> 0
rqd_605:
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
        BNE  pl_605
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_604            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_604
po_604:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_604: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_604
        MOV  R1, R5
pa1_604: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_604
        MOV  R1, R5
pa2_604: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_604
        MOV  R1, R5
pa3_604: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_604
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_604: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_604
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
        BNE  kl_603
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
fc_609: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_608:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_608            ; w == 0: nothing to accumulate
        BPL  mp_608            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_608:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_608
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_608
        SUB  R3, R3, R5
mnc_608: SUB  R7, R7, R6
        BNE  mn_608
        JMP  mx_608
mp_608:  MOV  R7, R5            ; count = w
mpp_608: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_608
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_608
        ADD  R3, R3, R5
mpc_608: SUB  R7, R7, R6
        BNE  mpp_608
mx_608:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_608
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_610            ; w == 0: nothing to accumulate
        BPL  mp_610            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_610:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_610
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_610
        SUB  R3, R3, R5
mnc_610: SUB  R7, R7, R6
        BNE  mn_610
        JMP  mx_610
mp_610:  MOV  R7, R5            ; count = w
mpp_610: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_610
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_610
        ADD  R3, R3, R5
mpc_610: SUB  R7, R7, R6
        BNE  mpp_610
mx_610:
        LDI  R7, 8
        LDI  R5, 0x80
rq_611:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_611
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_611: SHR  R3, R3
        BCC  rqb_611
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_611: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_611
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_611
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_611
        CMP  R2, R7
        BNE  rqm_611
        AND  R4, R1, R5
        BNE  rqm_611            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_611
rqm_611: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_611
rqn_611: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_611            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_611
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_611            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_611:
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
        BNE  fc_609
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_612: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_612           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_612: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_612
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
