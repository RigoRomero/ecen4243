.section .text.init
.org 0x80000000
.globl rvtest_entry_point


rvtest_entry_point:

    # --- Setup PMP to allow RWX access ---
    li t0, 0x3F
    csrw pmpcfg0, t0
    li t0, -1
    csrw pmpaddr0, t0

    # --- Set mstatus.MPP = 01 (Supervisor mode) ---
    csrr t0, mstatus
    li t1, 0xFFFFE7FF        # Clear bits 12:11 (MPP field)
    and t0, t0, t1
    li t1, 0x00000800        # Set MPP = 01
    or t0, t0, t1
    csrw mstatus, t0

    # --- Set mepc to 0x90000000 (virtual address of testcode) ---
    li t0, 0x90000000
    csrw mepc, t0

    mret                    # Enter Supervisor mode

supervisorstart:
    # --- Setup Page Table (Sv32) ---
    la t0, pagetable
    li t1, 4096
    divu t0, t0, t1          # t0 = pagetable >> 12
    li t1, 0x80000000        # Set MODE=1 (Sv32) in satp
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    # --- Store 42 to virtual address 0x90000300 ---
    li t0, 0x90000300
    li t1, 42
    sw t1, 0(t0)

    # --- Jump to testcode at virtual address 0x90000000 ---
    li t0, 0x90000000
    jr t0
    nop

# --- This code is mapped at 0x90000000 virtually, but 0x80000000 physically ---
testcode:
    li t0, 42                # Arbitrary test instruction

write_tohost:
    la s1, tohost
    li t0, 1
    sw t0, 0(s1)
    sw zero, 4(s1)

self_loop:
    j self_loop

tohost:
    .word 0

# --------------------------
# Data section
# --------------------------
.data
.align 12

# --- First-level Page Table ---
pagetable:
    .word 0x80001 | 0x1
  # VPN1=0 → addr of second level table (valid)

.align 12
secondleveltable:
    .space 2048                          # 512 words (2048 bytes) = second-level page table

    # VPN1 = 0x200 → maps 0x80000000 → 0x80000000 (PPN = 0x80000)
    .org secondleveltable + (512 * 4)
    .word 0x80000 | 0xFF                 # RWXADGV permissions

    # VPN1 = 0x240 → maps 0x90000000 → 0x80000000 (same PPN)
    .org secondleveltable + (576 * 4)
    .word 0x80000 | 0xFF                 # Same mapping for aliasing
