;Name:              Lance Wetzel
;Last Modifed:      5/8/2019
;Class/Assingment:  CS3140/HW3
;assembly command:  nasm -f elf64 -F dwarf -g assign3.asm
;Linking command:   ld -o assign3 -m elf_x86_64 assign3.o
;Description:       This program will read user input from stdin,
;                   switch the capitization of every letter, 
;                   and then write back out to stdout. 
;                   No command line arguments are accepted.

bits 64

section .text

global _start

_start:

read:
    mov     rdi, 0      ;setup for read syscall
    mov     rsi, buff   ;store 1 byte in buff
    mov     rdx, 1
    mov     rax, 0
    syscall

    cmp     rax, 0      ;if return from read is <=0
    jle     done        ;jmp to done and exit

    mov     bl,[buff]   ;move data in buff to a reg to allow for operations
swap_logic:

    cmp     bl,65       ;if ascii of data is < 65
    jl      write       ;jmp to write (no swap needed)

    cmp     bl,122      ;if ascii of data is > 122
    jg      write       ;jmp to write (no swap needed)

    cmp     bl, 90      ;if ascii of data is <= 90
    jle     swap        ;jmp to swap, char is A-Z

    cmp     bl,97       ;if ascii of data is >=97
    jge     swap        ;jmp to swap, char is a-z

    jmp     write       ;else, jmp to write

swap:
    xor     bl, 0x20    ;xor with 0x20 to change case of ascii letter
write:
    mov     [buff],bl   ;move data back to buff to allow for write out
    mov     rdi,1       ;set up for write syscall
    mov     rsi,buff    
    mov     rdx,1
    mov     rax,1
    syscall
    jmp     read        ;loop back to read to repeat program

done:
    mov     rdi,0       ;set up exit syscall, will always return '0'
    mov     rax, 60
    syscall

section .data


section .bss
buff:    resb    1      ;reserve 1 byte of data to use as buffer