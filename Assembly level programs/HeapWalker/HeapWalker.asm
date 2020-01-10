;Name:          Lance Wetzel
;Class:         CS3140
;Project:       Assignment6
;Assembler:     nasm -f elf64 -F dwarf -g assign6.asm
;               nasm -f elf64 -F dwarf -g _brk.asm
;Linker:        gcc -g -o assign6 -m64 tester.c assign6.o _brk.o -no-pie
;Notes:         Linking done by gcc when compliling the tester file  



bits 64

%define SIZE_OFFSET 8

section .text
    
extern get_brk
extern printf
global heap_walk



struc heap_stats
    .num_free_blocks:       resd 1  ;offest 0
    .num_allocated_blocks:  resd 1  ;offest 4
    .largest_allocated:     resq 1  ;offest 8
    .largest_free:          resq 1  ;offest 16
    .first_allocated:       resq 1  ;offest 24
    .last_allocated:        resq 1  ;offest 32
    .tail_chunk:            resq 1  ;offest 40
endstruc


_start:

heap_walk:

;prolog
    push rbp
    mov rbp,rsp

;read address pointed at by rdi
    mov [current_addr],rdi
    
;save address pointed at by rsi for the stats struct
    push rsi


;find the break address
    call get_brk
    mov [brk_addr],rax

;begin walking loop
.loop_top:

    ;read size of current chunk
    mov rdx,[current_addr]
    mov qword rax,[rdx + 0x08]

    ;ensure the last 4 bits are zeroed out
    and al,11110000b
    ;next chunk addr = current addr + size
    add rdx,rax
    mov [next_addr],rdx
    ;if next chunk addr >= break addr, then current chunk is tail chunk
    cmp rdx,[brk_addr]
    jge .found_tail
        
    ;else continue in the loop

    ;read the prev_usage bit in next chunk to determine usage of current chunk
    mov rdx,[next_addr]
    mov rbx,[rdx + 0x08]                ;read into rbx
    and bl,00000001b                    ;zero out all but the last bit
    cmp bl,0                            ;if pbit == 0
    je .current_is_free                 ;current block is free
                                        ;else, drop down to current_is_alloc

.current_is_alloc:

    ;update appropriate counter
    add [num_alloc_bytes],rax

    ;print the appropriate statement (allocation and size)
    mov rdi,allocated           ;use allocated format
    mov rsi,[current_addr]      ;first var is current addr
    mov rdx,rax                 ;2nd var is current size
    push rdx                    ;save current size on the stack
    call printf
    pop rdx                     ;restore rdx to current size

    ;update the heap_stats struct
    ;inc num_alloc
    mov eax,[my_heap_stats + heap_stats.num_allocated_blocks]
    inc eax
    mov [my_heap_stats + heap_stats.num_allocated_blocks],eax

    ;compare current size to largest_alloc
    mov rax, [my_heap_stats + heap_stats.largest_allocated]
    sub rdx,16              ;do not count the headder info
    cmp rdx, rax            ;update if current size > largest_free/alloc
    jge .update_largest_alloc 
    jmp .cont_alloc
            
.update_largest_alloc:
    mov [my_heap_stats + heap_stats.largest_allocated],rdx
.cont_alloc:

    ;if first_alloc == 0 set first_alloc = current address
    mov rax,[my_heap_stats + heap_stats.first_allocated]
    cmp rax,0
    je .first_alloc
    jmp .cont_alloc2
.first_alloc:
    mov rax,[current_addr]
    mov [my_heap_stats + heap_stats.first_allocated],rax
.cont_alloc2:
        
    ;if current is alloc, last_alloc = current addr
    mov rax,[current_addr]
    mov [my_heap_stats + heap_stats.last_allocated],rax

    ;make current addr = next addr
    mov rcx,[next_addr]
    mov [current_addr],rcx

    ;loop back to top
    jmp .loop_top
    
.current_is_free:

    ;update appropriate counter
    add [num_free_bytes],rax

    ;print the appropriate statement (allocation and size)
    mov rdi,unallocated         ;use unallocated format
    mov rsi,[current_addr]      ;first var is current addr
    mov rdx,rax                 ;2nd var is current size
    mov rcx,[rsi + 0x10]        ;3rd var is next field
    mov r8, [rsi + 0x18]        ;4th var is prev field
    push rdx                    ;save current size
    call printf
    pop rdx                     ;restore current size

    ;update the heap_stats struct
        ;inc either num_free or num_alloc
    mov eax,[my_heap_stats + heap_stats.num_free_blocks]
    inc eax
    mov [my_heap_stats + heap_stats.num_free_blocks],eax

        ;compare current size to largest_free/alloc
            ;update if current size > largest_free/alloc
    mov rax, [my_heap_stats + heap_stats.largest_free]
    sub rdx,16              ;do not count the headder info
    cmp rdx, rax            ;update if current size > largest_free/alloc
    jge .update_largest_free 
    jmp .cont_free
            
.update_largest_free:
    mov [my_heap_stats + heap_stats.largest_free],rdx
.cont_free:


    ;set current chunk = next chunk
    mov rcx,[next_addr]
    mov [current_addr],rcx

    ;loop back to top
    jmp .loop_top

;tail chunk actions
.found_tail:

;update num_free_bytes counter
    add [num_free_bytes],rax

;make print call
    mov rdi,tail                ;use unallocated format
    mov rsi,[current_addr]      ;first var is current addr
    mov rdx,rax                 ;2nd var is current size
    push rdx                    ;save current size
    call printf
    pop rdx                     ;restore current size

;update stats
    ;set tail_chunk = current addr
    mov rax,[current_addr]
    mov [my_heap_stats + heap_stats.tail_chunk],rax
    ;inc num_free_blocks
    mov eax,[my_heap_stats + heap_stats.num_free_blocks]
    inc eax
    mov [my_heap_stats + heap_stats.num_free_blocks],eax

    ;write the data to the address originally pointed at
    pop rsi
    mov eax,[my_heap_stats + heap_stats.num_free_blocks]
    mov dword [rsi],eax

    mov eax,[my_heap_stats + heap_stats.num_allocated_blocks]
    mov dword [rsi + 4],eax

    mov rax, [my_heap_stats + heap_stats.largest_allocated]
    mov qword [rsi + 8],rax

    mov rax, [my_heap_stats + heap_stats.largest_free]
    mov qword [rsi + 16], rax

    mov rax, [my_heap_stats + heap_stats.first_allocated]
    mov qword [rsi + 24], rax

    mov rax, [my_heap_stats + heap_stats.last_allocated]
    mov qword [rsi + 32], rax

    mov rax, [my_heap_stats + heap_stats.tail_chunk]
    mov qword [rsi + 40], rax

;print num_alloc_bytes
    mov rdi,total_alloc
    mov rsi,[num_alloc_bytes]
    call printf
;print num_free_bytes
    mov rdi,total_free
    mov rsi,[num_free_bytes]
    call printf



;eplilog
    mov rsp,rbp
    pop rbp
    ret


section .data

my_heap_stats: istruc heap_stats
    at heap_stats.num_free_blocks,      dd 0
    at heap_stats.num_allocated_blocks, dd 0
    at heap_stats.largest_allocated,    dq 0
    at heap_stats.largest_free,         dq 0
    at heap_stats.first_allocated,      dq 0
    at heap_stats.last_allocated,       dq 0
    at heap_stats.tail_chunk,           dq 0 
iend

current_addr: dq 0
next_addr: dq 0
num_alloc_bytes: dq 0
num_free_bytes: dq 0
brk_addr: dq 0

section .rodata

allocated: db `%p: Allocated (%lld bytes)\n`,0
unallocated: db `%p: Unallocated (%lld bytes). next: %p, prev: %p\n`,0
tail: db `%p: Tail (%lld bytes)\n`,0

total_alloc: db `A total of %lld bytes are allocated\n`,0
total_free: db `A total of %lld bytes are free\n`,0