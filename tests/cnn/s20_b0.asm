        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_746:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_746
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
kl_747:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_748:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_749:
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
ul_750: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_750
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_750:
vl_751:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_751
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_751          ; last u, V==1: the bias tap
bi_751: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_751
bt_751: LDI  R4, 127
ag_751: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_751            ; w == 0: nothing to accumulate
        BPL  mp_751            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_751:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_751
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_751
        SUB  R3, R3, R5
mnc_751: SUB  R7, R7, R6
        BNE  mn_751
        JMP  mx_751
mp_751:  MOV  R7, R5            ; count = w
mpp_751: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_751
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_751
        ADD  R3, R3, R5
mpc_751: SUB  R7, R7, R6
        BNE  mpp_751
mx_751:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_751: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_751
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
        BNE  ul_750
        LDI  R7, 8
        LDI  R5, 0x80
rq_749:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_749
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_749: SHR  R3, R3
        BCC  rqb_749
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_749: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_749
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_749
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_749
        CMP  R2, R7
        BNE  rqm_749
        AND  R4, R1, R5
        BNE  rqm_749            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_749
rqm_749: LDI  R5, 127
        JMP  rqd_749
rqn_749: LDI  R5, 0              ; ReLU: negative -> 0
rqd_749:
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
        BNE  pl_749
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_748            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_748
po_748:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_748: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_748
        MOV  R1, R5
pa1_748: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_748
        MOV  R1, R5
pa2_748: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_748
        MOV  R1, R5
pa3_748: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_748
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_748: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_748
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
        BNE  kl_747
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
fc_753: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_752:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_752            ; w == 0: nothing to accumulate
        BPL  mp_752            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_752:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_752
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_752
        SUB  R3, R3, R5
mnc_752: SUB  R7, R7, R6
        BNE  mn_752
        JMP  mx_752
mp_752:  MOV  R7, R5            ; count = w
mpp_752: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_752
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_752
        ADD  R3, R3, R5
mpc_752: SUB  R7, R7, R6
        BNE  mpp_752
mx_752:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_752
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_754            ; w == 0: nothing to accumulate
        BPL  mp_754            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_754:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_754
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_754
        SUB  R3, R3, R5
mnc_754: SUB  R7, R7, R6
        BNE  mn_754
        JMP  mx_754
mp_754:  MOV  R7, R5            ; count = w
mpp_754: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_754
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_754
        ADD  R3, R3, R5
mpc_754: SUB  R7, R7, R6
        BNE  mpp_754
mx_754:
        LDI  R7, 8
        LDI  R5, 0x80
rq_755:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_755
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_755: SHR  R3, R3
        BCC  rqb_755
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_755: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_755
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_755
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_755
        CMP  R2, R7
        BNE  rqm_755
        AND  R4, R1, R5
        BNE  rqm_755            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_755
rqm_755: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_755
rqn_755: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_755            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_755
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_755            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_755:
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
        BNE  fc_753
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_756: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_756           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_756: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_756
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
