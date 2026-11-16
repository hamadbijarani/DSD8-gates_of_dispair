        LDI  R0, 0xA5
        OUT  0x5F, R0          ; unlock accelerator
        LDI  R0, 0x03
        OUT  0x52, R0          ; clear acc + counters
        LDI  R0, 8
        OUT  0x56, R0
        LDI  R0, 0
        OUT  0x58, R0          ; LUT bank 0 (ReLU)
        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_433:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_433
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
        LDI  R2, 0
        LDI  R0, 187
        LDI  R5, 4
        ST   [R0], R5
kl_434:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_435:  LDI  R0, 177
        LD   R6, [R0]
        LDI  R7, 6
pl_436:  LDI  R0, 0x01
        OUT  0x52, R0          ; clear acc
        LDI  R0, 176
        LD   R1, [R0]
        MOV  R3, R2            ; tap ptr = row 0
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LDI  R5, 5
        ADD  R3, R3, R5
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LDI  R5, 5
        ADD  R3, R3, R5
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LD   R5, [R3]
        OUT  0x50, R5
        LD   R5, [R1]
        OUT  0x51, R5
        ADD  R3, R3, R4
        ADD  R1, R1, R4
        LDI  R5, 127
        OUT  0x50, R5          ; bias as virtual activation
        LD   R5, [R1]
        OUT  0x51, R5
        IN   R5, 0x57          ; sat8(acc>>>shift)
        LDI  R0, 0
        CMP  R5, R0
        BPL  pxok_436
        LDI  R5, 0             ; ReLU: negative -> 0
pxok_436:
        ST   [R6], R5
        ADD  R6, R6, R4
        ADD  R2, R2, R4        ; next pixel's row base
        SUB  R7, R7, R4
        BNE  pl_436
        LDI  R0, 189
        LD   R7, [R0]
        LDI  R5, 1
        XOR  R7, R7, R5
        ST   [R0], R7
        BEQ  po_435            ; odd row: pool the pair
        JMP  rw_435
po_435:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R0, 196
        LDI  R5, 3
        ST   [R0], R5
plp_435: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_435
        MOV  R1, R5
pa1_435: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_435
        MOV  R1, R5
pa2_435: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_435
        MOV  R1, R5
pa3_435: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        LDI  R0, 196
        LD   R5, [R0]
        SUB  R5, R5, R4
        ST   [R0], R5
        BNE  plp_435
        LDI  R0, 188
        ST   [R0], R6
rw_435:  LDI  R0, 177
        LD   R7, [R0]
        LDI  R5, 118
        CMP  R7, R5
        BCS  we_435
        ST   [R0], R5          ; was ROWA -> next ROWB
        JMP  wd_435
we_435:  LDI  R5, 112
        ST   [R0], R5
wd_435:  ADD  R2, R2, R4
        ADD  R2, R2, R4        ; next row starts 2 bytes later
        LDI  R0, 186
        LD   R5, [R0]
        SUB  R5, R5, R4
        ST   [R0], R5
        BNE  rl_435
        LDI  R0, 176
        LD   R7, [R0]
        LDI  R5, 10
        ADD  R7, R7, R5        ; next kernel's weight base
        ST   [R0], R7
        LDI  R2, 0
        LDI  R0, 187
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  kl_434
        LDI  R0, 8
        OUT  0x56, R0          ; requant shift for the FC layer
        LDI  R0, 2
        OUT  0x58, R0          ; LUT bank 2 (offset binary)
        LDI  R6, 168
        LDI  R0, 190
        LDI  R5, 4
        ST   [R0], R5
fc_438:  LDI  R0, 0x01
        OUT  0x52, R0          ; clear acc
        LDI  R2, 128
        LDI  R7, 36
fj_437:  LD   R5, [R2]
        OUT  0x50, R5          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        OUT  0x51, R5
        ADD  R2, R2, R4
        SUB  R7, R7, R4
        BNE  fj_437
        LDI  R5, 127
        OUT  0x50, R5          ; bias as virtual activation
        IN   R5, 0x46
        OUT  0x51, R5
        IN   R5, 0x57
        LDI  R0, 0x80
        XOR  R5, R5, R0        ; signed -> offset binary
        ST   [R6], R5
        ADD  R6, R6, R4
        LDI  R0, 190
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  fc_438
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_439: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_439           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_439: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_439
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
