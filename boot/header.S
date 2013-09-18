#include "asm.h"
#include "mmu.h"

# Start the first CPU: switch to 32-bit protected mode, jump into C.

# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.code16	# Assemble for 16-bit mode
.globl start
start:
	cli	# BIOS enabled interrupts; disable

	# Zero data segment registers DS, ES, and SS.
	xorw %ax, %ax	# Set %ax to zero
	movw %ax, %ds	# -> Data Segment
	movw %ax, %es	# -> Extra Segment
	movw %ax, %ss	# -> Stack Segment

	# Physical address line A20 is tied to zero so that the first PCs
	# with 2 MB would run software that assumed 1 MB.	Undo that.
	# Reference: http://www.win.tue.nl/~aeb/linux/kbd/A20.html
	#			 http://wiki.osdev.org/A20_Line
	#			 linux/arch/x86/boot/a20.c
	mov $0x2401, %ax
	int $0x15

	# Switch from real to protected mode. Use a bootstrap GDT that makes
	# virtual addresses map directly to physical addresses so that the
	# effective memory map doesn't change during the transition.
	lgdt gdtdesc
	movl %cr0, %eax
	orl $CR0_PE, %eax
	movl %eax, %cr0

	# Complete transition to 32-bit protected mode by using long jmp
	# to reload %cs and %eip.	The segment descriptors are set up with no
	# translation, so that the mapping is still the identity mapping.
	ljmp $(SEG_KCODE<<3), $start32

.code32	# Tell assembler to generate 32-bit code now.
start32:
	# Set up the protected-mode data segment registers
	movw $(SEG_KDATA<<3), %ax	# Our data segment selector
	movw %ax, %ds	# -> DS: Data Segment
	movw %ax, %es	# -> ES: Extra Segment
	movw %ax, %ss	# -> SS: Stack Segment
	movw $0,  %ax	# Zero segments not ready for use
	movw %ax, %fs	# -> FS
	movw %ax, %gs	# -> GS

	# Set up the stack pointer and call into C.
	movl $start, %esp
	call main

	# If bootmain returns (it shouldn't), trigger a Bochs
	# breakpoint if running under Bochs, then loop.
	movw		$0x8a00, %ax	# 0x8a00 -> port 0x8a00
	movw		%ax, %dx
	outw		%ax, %dx
	movw		$0x8ae0, %ax	# 0x8ae0 -> port 0x8a00
	outw		%ax, %dx
spin:
	jmp		 spin

# Bootstrap GDT
.align 8	# force 8 byte alignment, see 3A 3.5.1
gdt:
	SEG_NULLASM	# null seg
	SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)	 # code seg
	SEG_ASM(STA_W, 0x0, 0xffffffff)	# data seg

# Format of GDTR pseudo-descriptor in IA-32 mode
#
# 47					16 15		0
# +-----+-----+-----+-----+-----+----+
# |	 32-bit Base Address |	 Limit	 |
# +-----+-----+-----+-----+-----+----+
#
# Base addresses of the GDT should be aligned on an eight-byte boundary.
# GDT limit should be one less than an integral multiple of eight (8N – 1).

gdtdesc:
	.word (gdtdesc - gdt - 1)	# sizeof(gdt) - 1
	.long gdt	# address gdt
