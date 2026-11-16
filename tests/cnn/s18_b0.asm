        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_674:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_674
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
kl_675:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_676:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_677:
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
ul_678: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_678
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_678:
vl_679:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_679
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_679          ; last u, V==1: the bias tap
bi_679: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_679
bt_679: LDI  R4, 127
ag_679: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_679            ; w == 0: nothing to accumulate
        BPL  mp_679            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_679:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_679
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_679
        SUB  R3, R3, R5
mnc_679: SUB  R7, R7, R6
        BNE  mn_679
        JMP  mx_679
mp_679:  MOV  R7, R5            ; count = w
mpp_679: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_679
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_679
        ADD  R3, R3, R5
mpc_679: SUB  R7, R7, R6
        BNE  mpp_679
mx_679:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_679: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_679
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
        BNE  ul_678
        LDI  R7, 8
        LDI  R5, 0x80
rq_677:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_677
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_677: SHR  R3, R3
        BCC  rqb_677
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_677: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_677
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_677
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_677
        CMP  R2, R7
        BNE  rqm_677
        AND  R4, R1, R5
        BNE  rqm_677            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_677
rqm_677: LDI  R5, 127
        JMP  rqd_677
rqn_677: LDI  R5, 0              ; ReLU: negative -> 0
rqd_677:
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
        BNE  pl_677
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_676            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_676
po_676:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_676: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_676
        MOV  R1, R5
pa1_676: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_676
        MOV  R1, R5
pa2_676: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_676
        MOV  R1, R5
pa3_676: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_676
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_676: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_676
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
        BNE  kl_675
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
fc_681: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_680:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_680            ; w == 0: nothing to accumulate
        BPL  mp_680            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_680:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_680
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_680
        SUB  R3, R3, R5
mnc_680: SUB  R7, R7, R6
        BNE  mn_680
        JMP  mx_680
mp_680:  MOV  R7, R5            ; count = w
mpp_680: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_680
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_680
        ADD  R3, R3, R5
mpc_680: SUB  R7, R7, R6
        BNE  mpp_680
mx_680:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_680
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_682            ; w == 0: nothing to accumulate
        BPL  mp_682            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_682:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_682
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_682
        SUB  R3, R3, R5
mnc_682: SUB  R7, R7, R6
        BNE  mn_682
        JMP  mx_682
mp_682:  MOV  R7, R5            ; count = w
mpp_682: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_682
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_682
        ADD  R3, R3, R5
mpc_682: SUB  R7, R7, R6
        BNE  mpp_682
mx_682:
        LDI  R7, 8
        LDI  R5, 0x80
rq_683:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_683
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_683: SHR  R3, R3
        BCC  rqb_683
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_683: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_683
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_683
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_683
        CMP  R2, R7
        BNE  rqm_683
        AND  R4, R1, R5
        BNE  rqm_683            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_683
rqm_683: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_683
rqn_683: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_683            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_683
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_683            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_683:
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
        BNE  fc_681
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_684: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_684           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_684: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_684
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
