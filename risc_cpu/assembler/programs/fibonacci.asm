# Fibonacci - Compute first 10 Fibonacci numbers and store in memory
# Results stored at address 0x200 (word 0), 0x204 (word 1), ...
# Registers used:
#   x1 = fib(n-2),  x2 = fib(n-1),  x3 = fib(n)
#   x4 = base address,  x5 = loop counter,  x6 = temp

        addi  x4, x0, 512       # x4 = 0x200 (base address for results)
        addi  x1, x0, 0         # fib(0) = 0
        addi  x2, x0, 1         # fib(1) = 1
        sw    x1, 0(x4)         # mem[0x200] = 0
        sw    x2, 4(x4)         # mem[0x204] = 1
        addi  x5, x0, 2         # loop counter i = 2
        addi  x6, x0, 10        # loop limit = 10

loop:
        add   x3, x1, x2        # fib(i) = fib(i-2) + fib(i-1)
        slli  x7, x5, 2         # offset = i * 4
        add   x8, x4, x7        # addr = base + offset
        sw    x3, 0(x8)         # mem[base + i*4] = fib(i)
        mv    x1, x2            # fib(i-2) = fib(i-1)
        mv    x2, x3            # fib(i-1) = fib(i)
        addi  x5, x5, 1         # i++
        blt   x5, x6, loop      # if i < 10, loop

done:
        nop
        nop
        nop
