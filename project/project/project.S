.section .text.init
.globl rvtest_entry_point

rvtest_entry_point:

    # --- Set up PMP to allow RWX access ---
    li t0, 0x3f              # TOR, R, W, X permissions
    csrw pmpcfg0, t0

    li t0, -1                # PMP address range: 0xFFFFFFFF
    csrw pmpaddr0, t0

    # --- Switch to Supervisor Mode ---
    csrr t0, mstatus
    li t1, ~(3 << 11)        # Clear MPP bits
    and t0, t0, t1
    li t1, (1 << 11)         # Set MPP = 01 (Supervisor)
    or t0, t0, t1
    csrw mstatus, t0

    la t0, supervisorstart   # Load address of supervisorstart
    csrw mepc, t0

    mret                     # Enter supervisor mode
    nop

supervisorstart:
    # --- Set up Page Table ---
    la t0, pagetable
    srli t0, t0, 12           # Shift page table address for satp
    li t1, (1 << 31)          # MODE=1 for Sv32
    or t0, t0, t1
    csrw satp, t0             # Write to satp
    sfence.vma                # Flush TLB

    # --- Now running under Virtual Memory ---
    li t0, 0x90000300         # Virtual address
    li t1, 42
    sw t1, 0(t0)              # Store 42 at 0x90000300

    # --- Jump to Testcode ---
    la t0, testcode
    lui t1, 0x10000
    add t0, t0, t1            # Virtual address offset
    jr t0                    # Jump to testcode
    nop                      # Should never execute

testcode:
    li t0, 42                # Do something simple

write_tohost:
    la s1, tohost
    li t0, 1                 # Success code
    sw t0, 0(s1)
    sw zero, 4(s1)

self_loop:
    j self_loop

tohost:
    .word 0

.data
.align 16

# --- Root Page Table (Level 1) ---
pagetable:
    .word 0x80011 | 0x1      # 0x80011000 >> 12 = 0x80011, valid=1

.align 12

# --- Second Level Page Table (Level 0) ---
secondleveltable:
    .space 2048              # Reserve space for 512 entries

    # VPN1 = 0x200 (for 0x80000000)
    .org secondleveltable + (512 * 4)
    .word 0x80000 | 0xFF     # PPN=0x80000 | flags RWXADG

    # VPN1 = 0x240 (for 0x90000000)
    .org secondleveltable + (576 * 4)
    .word 0x80000 | 0xFF     # Map to same 0x80000 physical page
