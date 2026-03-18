# LED Blink - Toggle GPIO output register in a loop
# GPIO base address: 0x1000_0000
# Memory map:
#   0x10000000 = GPIO output register (write LEDs)
#   0x10000004 = GPIO input register  (read switches)
#
# Behavior: counts up on LEDs, with a software delay loop

        # Load GPIO base address using lui + addi
        lui   x1, 0x10000        # x1 = 0x10000000 (GPIO base)
        addi  x2, x0, 0         # x2 = LED pattern (start at 0)
        addi  x3, x0, 1         # x3 = increment

main_loop:
        # Write LED pattern to GPIO output
        sw    x2, 0(x1)          # GPIO_OUT = x2

        # Software delay loop (~65536 iterations)
        lui   x4, 0x1            # x4 = 0x1000 = 4096
        addi  x4, x4, 0         # (keep 4096)

delay_loop:
        addi  x4, x4, -1        # decrement counter
        bne   x4, x0, delay_loop # loop while counter != 0

        # Increment LED pattern and mask to 16 bits
        add   x2, x2, x3        # x2 += 1
        lui   x5, 0x1            # x5 = 0x00001000 (mask upper bits)
        addi  x5, x5, -1        # x5 = 0x00000FFF — use as wrap point
        and   x2, x2, x5        # mask to keep lower 12 bits cycling

        # Loop forever
        j     main_loop
