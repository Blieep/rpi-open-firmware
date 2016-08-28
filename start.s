/*=============================================================================
Copyright (C) 2016 Kristina Brooks
All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

FILE DESCRIPTION
Entry.

A small explanation. The ROM loads bootcode.bin at 0x80000000 and jumps to
0x80000200. This region corresponds to L1/L2 cached IO and cache is never
evicted as long as we don't touch memory above that. This gives us 128KB
of memory at startup.

Exception names are from the public release from:
	brcm_usrlib\dag\vmcsx\vcfw\rtos\none\rtos_none.c

=============================================================================*/


.text

empty_space:
	.space 0x200

.include "ghetto.s"

/* main entry point */

.globl _start
.align 2
_start:
        version r0
	mov r5, r0

	/* vectors */
	mov r3, #0x1B000
	mov r1, r3

	/*
	 * populate the exception vector table using PC relative labels
	 * so the code isnt position dependent
	 */
.macro RegisterISR label, exception_number
	lea r2, fleh_\label
        mov r1, #(0x1B000 + 4*\exception_number)
	st r2, (r1)
.endm

.macro RegisterIRQ label, exception_number
        RegisterISR \label, \exception_number
.endm

	RegisterISR zero, 0
	RegisterISR misaligned, 1
	RegisterISR dividebyzero, 2
	RegisterISR undefinedinstruction, 3
	RegisterISR forbiddeninstruction, 4
	RegisterISR illegalmemory, 5
	RegisterISR buserror, 6
	RegisterISR floatingpoint, 7
	RegisterISR isp, 8
	RegisterISR dummy, 9
	RegisterISR icache, 10
	RegisterISR veccore, 11
	RegisterISR badl2alias, 12
	RegisterISR breakpoint, 13

        RegisterIRQ monitor_irq, 94 /* ARM interrupt */

	/*
	 * load the interrupt and normal stack pointers. these
	 * are chosen to be near the top of the available cache memory
	 */

	mov r28, #0x1D000 
	mov sp, #0x1C000

        /* unmask ARM interrupts */
        mov r0, #(IC0_BASE + 0x10)
        mov r1, #(IC1_BASE + 0x10)
        mov r2, 0x11111111
        mov r3, #(IC0_BASE + 0x10 + 0x20)

    unmask_all:
        st r2, (r0)
        st r2, (r1)
        add r0, 4
        add r1, 4
        ble r0, r3, unmask_all
 
	/* set interrupt vector bases */
	mov r3, #0x1B000
	mov r0, #IC0_VADDR
	st r3, (r0)
	mov r0, #IC1_VADDR
	st r3, (r0)


        /* enable interrupts */
	ei

	/* jump to C code */
	mov r0, r5
	lea r1, _start

	bl _main

/************************************************************
 * Debug
 ************************************************************/

blinker:
	mov r1, #GPFSEL1
	ld r0, (r1)
	and r0, #(~(7<<18))
	or r0, #(1<<18)
	st r0, (r1)
	mov r1, #GPSET0
	mov r2, #GPCLR0
	mov r3, #(1<<16)
loop:
	st r3, (r1)
	mov r0, #0
delayloop1:
	add r0, #1
	cmp r0, #0x100000
	bne delayloop1
	st r3, (r2)
	mov r0, #0
delayloop2:
	add r0, #1
	cmp r0, #0x100000
	bne delayloop2
	b loop

/************************************************************
 * Exception Handling
 ************************************************************/

.macro SaveRegsLower 
        stm lr, (--sp)
	stm r0-r5, (--sp)
.endm

.macro SaveRegsUpper
	stm r6-r15, (--sp)
	stm r16-r23, (--sp)
.endm

.macro ExceptionHandler label, exception_number
fleh_\label:
	SaveRegsLower
	mov r1, \exception_number
        SaveRegsUpper
        mov r0, sp
        b sleh_fatal
.endm

.macro IRQHandler label, number
fleh_\label:
        SaveRegsLower
        SaveRegsUpper

        mov r1, \number
        bl \label

        ldm r16-r23, (sp++)
	ldm r6-r15, (sp++)
	ldm r0-r5, (sp++)
	ld lr, (sp++)
	rti
.endm

	ExceptionHandler zero, #0
	ExceptionHandler misaligned, #1
	ExceptionHandler dividebyzero, #2
	ExceptionHandler undefinedinstruction, #3
	ExceptionHandler forbiddeninstruction, #4
	ExceptionHandler illegalmemory, #5
	ExceptionHandler buserror, #6
	ExceptionHandler floatingpoint, #7
	ExceptionHandler isp, #8
	ExceptionHandler dummy, #9
	ExceptionHandler icache, #10
	ExceptionHandler veccore, #11
	ExceptionHandler badl2alias, #12
	ExceptionHandler breakpoint, #13
	ExceptionHandler unknown, #14

        IRQHandler monitor_irq, #94
