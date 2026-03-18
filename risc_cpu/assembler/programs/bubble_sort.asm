# Bubble Sort - Sort an array of 8 integers (ascending)
# Array stored at address 0x300
# Uses registers:
#   x10 = base address,  x11 = outer loop i,  x12 = inner loop j
#   x13 = array[j],  x14 = array[j+1],  x15 = temp (swap)
#   x16 = limit (n-1 = 7),  x17 = inner limit

        # Initialize array at 0x300: [64, 34, 25, 12, 22, 11, 90, 1]
        addi  x10, x0, 768      # x10 = 0x300
        addi  x1, x0, 64
        sw    x1, 0(x10)
        addi  x1, x0, 34
        sw    x1, 4(x10)
        addi  x1, x0, 25
        sw    x1, 8(x10)
        addi  x1, x0, 12
        sw    x1, 12(x10)
        addi  x1, x0, 22
        sw    x1, 16(x10)
        addi  x1, x0, 11
        sw    x1, 20(x10)
        addi  x1, x0, 90
        sw    x1, 24(x10)
        addi  x1, x0, 1
        sw    x1, 28(x10)

        addi  x11, x0, 0        # outer i = 0
        addi  x16, x0, 7        # n - 1 = 7

outer_loop:
        bge   x11, x16, sort_done   # if i >= 7, done
        addi  x12, x0, 0            # inner j = 0
        sub   x17, x16, x11         # inner limit = 7 - i

inner_loop:
        bge   x12, x17, next_outer  # if j >= limit, next outer
        slli  x18, x12, 2           # offset = j * 4
        add   x19, x10, x18         # addr_j = base + offset
        lw    x13, 0(x19)           # x13 = array[j]
        lw    x14, 4(x19)           # x14 = array[j+1]
        bge   x14, x13, no_swap     # if array[j+1] >= array[j], no swap (i.e. in order)

        # Swap array[j] and array[j+1]
        sw    x14, 0(x19)           # array[j] = array[j+1]
        sw    x13, 4(x19)           # array[j+1] = array[j]

no_swap:
        addi  x12, x12, 1           # j++
        j     inner_loop

next_outer:
        addi  x11, x11, 1           # i++
        j     outer_loop

sort_done:
        nop
        nop
        nop
