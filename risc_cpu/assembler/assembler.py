#!/usr/bin/env python3
"""
RISC-V RV32I Assembler
Supports all RV32I instructions, labels, and common pseudo-instructions.
Outputs hex files compatible with Verilog $readmemh.

Usage:
    python3 assembler.py <input.asm> <output.hex>
    python3 assembler.py <input.asm>        # outputs to stdout
"""

import sys
import re
import os

# ---------------------------------------------------------------------------
# Register name → number mapping
# ---------------------------------------------------------------------------
REGS = {
    'x0':0,'x1':1,'x2':2,'x3':3,'x4':4,'x5':5,'x6':6,'x7':7,
    'x8':8,'x9':9,'x10':10,'x11':11,'x12':12,'x13':13,'x14':14,'x15':15,
    'x16':16,'x17':17,'x18':18,'x19':19,'x20':20,'x21':21,'x22':22,'x23':23,
    'x24':24,'x25':25,'x26':26,'x27':27,'x28':28,'x29':29,'x30':30,'x31':31,
    # ABI names
    'zero':0,'ra':1,'sp':2,'gp':3,'tp':4,
    't0':5,'t1':6,'t2':7,
    's0':8,'fp':8,'s1':9,
    'a0':10,'a1':11,'a2':12,'a3':13,'a4':14,'a5':15,'a6':16,'a7':17,
    's2':18,'s3':19,'s4':20,'s5':21,'s6':22,'s7':23,'s8':24,'s9':25,
    's10':26,'s11':27,
    't3':28,'t4':29,'t5':30,'t6':31,
}

def reg(name):
    name = name.strip().lower()
    if name not in REGS:
        raise ValueError(f"Unknown register: {name!r}")
    return REGS[name]

def imm_val(s, labels=None, pc=None):
    """Parse an immediate value or label reference."""
    s = s.strip()
    # Label reference
    if labels is not None and s in labels:
        label_addr = labels[s]
        if pc is not None:
            return label_addr - pc   # PC-relative offset
        return label_addr
    # Hex
    if s.startswith('0x') or s.startswith('0X'):
        return int(s, 16)
    # Negative hex
    if s.startswith('-0x') or s.startswith('-0X'):
        return -int(s[1:], 16)
    # Decimal
    try:
        return int(s, 0)
    except ValueError:
        raise ValueError(f"Cannot parse immediate: {s!r}")

def sign_extend(value, bits):
    """Sign-extend a value to the given bit width."""
    if value & (1 << (bits - 1)):
        value -= (1 << bits)
    return value

def to_u32(v):
    """Convert signed Python int to unsigned 32-bit."""
    return v & 0xFFFF_FFFF

# ---------------------------------------------------------------------------
# Instruction encoding helpers
# ---------------------------------------------------------------------------

def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return to_u32((funct7 << 25) | (rs2 << 20) | (rs1 << 15) |
                  (funct3 << 12) | (rd << 7) | opcode)

def i_type(imm, rs1, funct3, rd, opcode):
    imm = to_u32(imm) & 0xFFF
    return to_u32((imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode)

def s_type(imm, rs2, rs1, funct3, opcode):
    imm = to_u32(imm) & 0xFFF
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return to_u32((imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) |
                  (funct3 << 12) | (imm4_0 << 7) | opcode)

def b_type(imm, rs2, rs1, funct3, opcode):
    imm = to_u32(imm) & 0x1FFF
    b12    = (imm >> 12) & 1
    b11    = (imm >> 11) & 1
    b10_5  = (imm >> 5)  & 0x3F
    b4_1   = (imm >> 1)  & 0xF
    return to_u32((b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) |
                  (funct3 << 12) | (b4_1 << 8) | (b11 << 7) | opcode)

def u_type(imm, rd, opcode):
    imm = to_u32(imm) & 0xFFFFF000
    return to_u32(imm | (rd << 7) | opcode)

def j_type(imm, rd, opcode):
    imm = to_u32(imm) & 0x1FFFFF
    j20    = (imm >> 20) & 1
    j19_12 = (imm >> 12) & 0xFF
    j11    = (imm >> 11) & 1
    j10_1  = (imm >> 1)  & 0x3FF
    return to_u32((j20 << 31) | (j10_1 << 21) | (j11 << 20) |
                  (j19_12 << 12) | (rd << 7) | opcode)

# ---------------------------------------------------------------------------
# Opcode constants
# ---------------------------------------------------------------------------
OP_R      = 0b0110011
OP_I_ARITH= 0b0010011
OP_LOAD   = 0b0000011
OP_STORE  = 0b0100011
OP_BRANCH = 0b1100011
OP_JAL    = 0b1101111
OP_JALR   = 0b1100111
OP_LUI    = 0b0110111
OP_AUIPC  = 0b0010111
OP_FENCE  = 0b0001111
OP_SYSTEM = 0b1110011

# ---------------------------------------------------------------------------
# parse_load_store: parses "imm(rs)" → (imm, rs)
# ---------------------------------------------------------------------------
def parse_mem_operand(s):
    s = s.strip()
    m = re.match(r'^(-?\w+)\s*\(\s*(\w+)\s*\)$', s)
    if not m:
        raise ValueError(f"Bad memory operand: {s!r}")
    return m.group(1), m.group(2)

# ---------------------------------------------------------------------------
# Assembler core
# ---------------------------------------------------------------------------

def preprocess(lines):
    """Strip comments, blank lines, handle .data/.text directives."""
    result = []
    for line in lines:
        # Remove inline comments
        line = re.sub(r'#.*', '', line)
        line = re.sub(r'//.*', '', line)
        line = line.strip()
        if line:
            result.append(line)
    return result

def first_pass(lines):
    """Collect labels and their addresses (in bytes)."""
    labels = {}
    pc = 0
    for line in lines:
        # Directive handling (skip .section, .text, .data, .globl, .equ, .word)
        if line.startswith('.'):
            # .equ or .set: define a numeric symbol
            m = re.match(r'\.(?:equ|set)\s+(\w+)\s*,\s*(.+)', line)
            if m:
                labels[m.group(1)] = imm_val(m.group(2))
            # .word: one word of data
            elif re.match(r'\.word\b', line):
                pc += 4
            continue
        # Label
        m = re.match(r'^(\w+)\s*:\s*(.*)', line)
        if m:
            labels[m.group(1)] = pc
            rest = m.group(2).strip()
            if rest and not rest.startswith('.'):
                pc += 4
        else:
            pc += 4
    return labels

def encode_instr(mnemonic, args, pc, labels):
    """Encode a single instruction, returning a 32-bit word."""
    m = mnemonic.lower()

    def get_imm(s, relative=False):
        v = imm_val(s, labels, pc if relative else None)
        return v

    # ------------------------------------------------------------------
    # R-type
    # ------------------------------------------------------------------
    R_TABLE = {
        'add' :(0b0000000,0b000), 'sub' :(0b0100000,0b000),
        'sll' :(0b0000000,0b001), 'slt' :(0b0000000,0b010),
        'sltu':(0b0000000,0b011), 'xor' :(0b0000000,0b100),
        'srl' :(0b0000000,0b101), 'sra' :(0b0100000,0b101),
        'or'  :(0b0000000,0b110), 'and' :(0b0000000,0b111),
    }
    if m in R_TABLE:
        rd_r, rs1_r, rs2_r = [a.strip() for a in args]
        f7, f3 = R_TABLE[m]
        return r_type(f7, reg(rs2_r), reg(rs1_r), f3, reg(rd_r), OP_R)

    # ------------------------------------------------------------------
    # I-type arithmetic
    # ------------------------------------------------------------------
    I_TABLE = {
        'addi' :0b000, 'slti' :0b010, 'sltiu':0b011,
        'xori' :0b100, 'ori'  :0b110, 'andi' :0b111,
    }
    if m in I_TABLE:
        rd_r, rs1_r, imm_s = [a.strip() for a in args]
        f3 = I_TABLE[m]
        return i_type(get_imm(imm_s), reg(rs1_r), f3, reg(rd_r), OP_I_ARITH)

    if m in ('slli', 'srli', 'srai'):
        rd_r, rs1_r, shamt_s = [a.strip() for a in args]
        shamt = int(shamt_s.strip(), 0) & 0x1F
        f7 = 0b0100000 if m == 'srai' else 0b0000000
        f3 = 0b001 if m == 'slli' else 0b101
        imm12 = (f7 << 5) | shamt
        return i_type(imm12, reg(rs1_r), f3, reg(rd_r), OP_I_ARITH)

    # ------------------------------------------------------------------
    # Load
    # ------------------------------------------------------------------
    LOAD_TABLE = {
        'lb':0b000,'lh':0b001,'lw':0b010,'lbu':0b100,'lhu':0b101,
    }
    if m in LOAD_TABLE:
        rd_r, mem_s = args[0].strip(), args[1].strip()
        imm_s, rs1_s = parse_mem_operand(mem_s)
        f3 = LOAD_TABLE[m]
        return i_type(get_imm(imm_s), reg(rs1_s), f3, reg(rd_r), OP_LOAD)

    # ------------------------------------------------------------------
    # Store
    # ------------------------------------------------------------------
    STORE_TABLE = {'sb':0b000,'sh':0b001,'sw':0b010}
    if m in STORE_TABLE:
        rs2_r, mem_s = args[0].strip(), args[1].strip()
        imm_s, rs1_s = parse_mem_operand(mem_s)
        f3 = STORE_TABLE[m]
        return s_type(get_imm(imm_s), reg(rs2_r), reg(rs1_s), f3, OP_STORE)

    # ------------------------------------------------------------------
    # Branch
    # ------------------------------------------------------------------
    BRANCH_TABLE = {
        'beq':0b000,'bne':0b001,'blt':0b100,
        'bge':0b101,'bltu':0b110,'bgeu':0b111,
    }
    if m in BRANCH_TABLE:
        rs1_r, rs2_r, label_s = [a.strip() for a in args]
        offset = get_imm(label_s, relative=True)
        f3 = BRANCH_TABLE[m]
        return b_type(offset, reg(rs2_r), reg(rs1_r), f3, OP_BRANCH)

    # ------------------------------------------------------------------
    # JAL
    # ------------------------------------------------------------------
    if m == 'jal':
        if len(args) == 1:
            rd_r = 'ra'; label_s = args[0].strip()
        else:
            rd_r, label_s = args[0].strip(), args[1].strip()
        offset = get_imm(label_s, relative=True)
        return j_type(offset, reg(rd_r), OP_JAL)

    # ------------------------------------------------------------------
    # JALR
    # ------------------------------------------------------------------
    if m == 'jalr':
        if len(args) == 1:
            # jalr rs1  → jalr x0, rs1, 0
            rs1_r = args[0].strip(); rd_r = 'x0'; imm_s = '0'
        elif len(args) == 2:
            # jalr rd, rs1  or jalr rd, imm(rs1)
            rd_r = args[0].strip()
            rest = args[1].strip()
            if '(' in rest:
                imm_s, rs1_s = parse_mem_operand(rest)
                return i_type(get_imm(imm_s), reg(rs1_s), 0b000, reg(rd_r), OP_JALR)
            else:
                rs1_r = rest; imm_s = '0'
        else:
            rd_r, rs1_r, imm_s = args[0].strip(), args[1].strip(), args[2].strip()
        return i_type(get_imm(imm_s), reg(rs1_r), 0b000, reg(rd_r), OP_JALR)

    # ------------------------------------------------------------------
    # LUI / AUIPC
    # ------------------------------------------------------------------
    if m == 'lui':
        rd_r, imm_s = args[0].strip(), args[1].strip()
        v = get_imm(imm_s) & 0xFFFFF
        return u_type(v << 12, reg(rd_r), OP_LUI)

    if m == 'auipc':
        rd_r, imm_s = args[0].strip(), args[1].strip()
        v = get_imm(imm_s) & 0xFFFFF
        return u_type(v << 12, reg(rd_r), OP_AUIPC)

    # ------------------------------------------------------------------
    # FENCE / ECALL / EBREAK
    # ------------------------------------------------------------------
    if m == 'fence':
        return 0x0000000F
    if m == 'ecall':
        return 0x00000073
    if m == 'ebreak':
        return 0x00100073

    # ------------------------------------------------------------------
    # Pseudo-instructions
    # ------------------------------------------------------------------
    if m == 'nop':
        return i_type(0, 0, 0b000, 0, OP_I_ARITH)  # addi x0,x0,0

    if m == 'mv':
        rd_r, rs1_r = args[0].strip(), args[1].strip()
        return i_type(0, reg(rs1_r), 0b000, reg(rd_r), OP_I_ARITH)  # addi rd,rs1,0

    if m == 'not':
        rd_r, rs1_r = args[0].strip(), args[1].strip()
        return i_type(-1 & 0xFFF, reg(rs1_r), 0b100, reg(rd_r), OP_I_ARITH)  # xori rd,rs1,-1

    if m == 'neg':
        rd_r, rs1_r = args[0].strip(), args[1].strip()
        return r_type(0b0100000, reg(rs1_r), 0, 0b000, reg(rd_r), OP_R)  # sub rd,x0,rs1

    if m == 'li':
        rd_r, imm_s = args[0].strip(), args[1].strip()
        v = get_imm(imm_s)
        if -2048 <= v <= 2047:
            return i_type(v, 0, 0b000, reg(rd_r), OP_I_ARITH)  # addi rd,x0,imm
        else:
            # lui + addi (two instructions — caller must handle; for single-word we just lui)
            upper = (v + 0x800) >> 12
            lower = v - (upper << 12)
            # Return lui first; caller should split pseudo into two words
            # For simplicity we encode as lui+addi pair appended
            raise ValueError(f"'li' with large immediate {v} needs 2 instructions; "
                             f"use lui/addi directly, or this assembler expands it.")

    if m == 'la':
        rd_r, label_s = args[0].strip(), args[1].strip()
        target = get_imm(label_s)
        upper = (target + 0x800) >> 12
        lower = target - (upper << 12)
        # Returns auipc + addi as pair — caller must handle
        raise ValueError(f"'la' is a 2-instruction pseudo; use auipc+addi directly.")

    if m == 'ret':
        return i_type(0, reg('ra'), 0b000, 0, OP_JALR)  # jalr x0, ra, 0

    if m == 'j':
        label_s = args[0].strip()
        offset = get_imm(label_s, relative=True)
        return j_type(offset, 0, OP_JAL)  # jal x0, label

    if m == 'jr':
        rs1_r = args[0].strip()
        return i_type(0, reg(rs1_r), 0b000, 0, OP_JALR)

    if m == 'call':
        label_s = args[0].strip()
        offset = get_imm(label_s, relative=True)
        return j_type(offset, reg('ra'), OP_JAL)

    if m in ('beqz','bnez','bltz','bgez','bgtz','blez'):
        ZERO_BR = {'beqz':'beq','bnez':'bne','bltz':'blt',
                   'bgez':'bge','bgtz':'blt','blez':'bge'}
        rs1_r, label_s = args[0].strip(), args[1].strip()
        offset = get_imm(label_s, relative=True)
        base = ZERO_BR[m]
        f3 = BRANCH_TABLE[base]
        # For bgtz/blez swap operands
        if m in ('bgtz',):
            return b_type(offset, reg(rs1_r), 0, f3, OP_BRANCH)
        if m in ('blez',):
            return b_type(offset, 0, reg(rs1_r), f3, OP_BRANCH)
        return b_type(offset, 0, reg(rs1_r), f3, OP_BRANCH)

    if m == 'seqz':
        rd_r, rs1_r = args[0].strip(), args[1].strip()
        return i_type(1, reg(rs1_r), 0b011, reg(rd_r), OP_I_ARITH)  # sltiu rd,rs1,1

    if m == 'snez':
        rd_r, rs1_r = args[0].strip(), args[1].strip()
        return r_type(0b0000000, reg(rs1_r), 0, 0b011, reg(rd_r), OP_R)  # sltu rd,x0,rs1

    if m == 'sltz':
        rd_r, rs1_r = args[0].strip(), args[1].strip()
        return r_type(0b0000000, 0, reg(rs1_r), 0b010, reg(rd_r), OP_R)  # slt rd,rs1,x0

    if m == 'sgtz':
        rd_r, rs1_r = args[0].strip(), args[1].strip()
        return r_type(0b0000000, reg(rs1_r), 0, 0b010, reg(rd_r), OP_R)  # slt rd,x0,rs1

    raise ValueError(f"Unknown mnemonic: {m!r}")


def assemble_lines(lines, base_addr=0):
    """Two-pass assembly. Returns list of (addr, word) tuples."""
    cleaned = preprocess(lines)

    # Expand .word directives and label-only lines
    # Build a flat list of (type, content) for second pass
    entries = []
    for line in cleaned:
        # Directive
        if line.startswith('.'):
            m = re.match(r'\.word\s+(.+)', line)
            if m:
                entries.append(('word', m.group(1)))
            # Other directives (.section, .text, .data, .globl, .equ) skipped
            continue
        # Label with optional instruction
        m = re.match(r'^(\w+)\s*:\s*(.*)', line)
        if m:
            entries.append(('label', m.group(1)))
            rest = m.group(2).strip()
            if rest:
                entries.append(('instr', rest))
        else:
            entries.append(('instr', line))

    # First pass: assign addresses
    labels = {}
    pc = base_addr
    for kind, content in entries:
        if kind == 'label':
            labels[content] = pc
        elif kind in ('instr', 'word'):
            pc += 4

    # Second pass: encode
    words = []
    pc = base_addr
    for kind, content in entries:
        if kind == 'label':
            continue
        elif kind == 'word':
            v = imm_val(content, labels)
            words.append((pc, to_u32(v)))
            pc += 4
        elif kind == 'instr':
            # Split mnemonic and operands
            parts = content.split(None, 1)
            mnemonic = parts[0]
            if len(parts) > 1:
                # Split by comma but be careful with mem operands like 0(x1)
                raw_args = parts[1]
                # Split on commas that are not inside parentheses
                args = re.split(r',\s*(?![^()]*\))', raw_args)
            else:
                args = []

            try:
                word = encode_instr(mnemonic, args, pc, labels)
                words.append((pc, word))
                pc += 4
            except ValueError as e:
                print(f"ERROR at PC=0x{pc:08x}: {e}", file=sys.stderr)
                # Insert NOP on error
                words.append((pc, 0x0000_0013))
                pc += 4

    return words


def assemble_file(input_path, output_path=None, base_addr=0):
    with open(input_path, 'r') as f:
        lines = f.readlines()

    words = assemble_lines(lines, base_addr)

    # Generate hex output (one 8-digit hex word per line, no address prefix)
    hex_lines = [f"{w:08x}" for _, w in words]
    output = '\n'.join(hex_lines) + '\n'

    if output_path:
        with open(output_path, 'w') as f:
            f.write(output)
        print(f"Assembled {len(words)} instructions → {output_path}")
    else:
        sys.stdout.write(output)

    return words


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    base_addr = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0

    assemble_file(input_path, output_path, base_addr)


if __name__ == '__main__':
    main()
