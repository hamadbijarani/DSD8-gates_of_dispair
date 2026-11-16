; Compact GTKWave demonstration for the complete DSD-8 system.
; Computes 3 * 4 in the NN accelerator and writes 12 (0x0C) to LEDs.

        LDI  R0, 0xA5
        OUT  0x5F, R0       ; unlock accelerator

        LDI  R0, 0x03
        OUT  0x52, R0       ; clear accumulator and counters

        LDI  R1, 3
        OUT  0x50, R1       ; activation operand
        LDI  R2, 4
        OUT  0x51, R2       ; weight operand; starts MAC

        IN   R3, 0x53       ; accumulator low byte
        OUT  0x02, R3       ; LEDs = 0x0C
        HLT
