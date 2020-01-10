;Name:          Lance Wetzel
;Class:         CS3140
;Project:       Assignment5
;Assembler:     nasm -f elf64 -F dwarf -g assign5.asm
;Linker:        ld -o assign5 -m elf_x86_64 assign5.o dns64.o
;Notes:         Also requires an executable named 'assign3' in
;               the same directory




bits 64

section .text

struc sockaddr_in
    .sin_family:    resw 1
    .sin_port:      resw 1
    .sin_addr:      resd 1
    .sin_pad:       resb 8
endstruc


extern resolv
global _start

_start:


;check if 3 args were passed on the command line
;if not, return with status code of 1
command_line_check:
;prolog
    push rbp
    mov rbp,rsp
    sub rsp,16              ;set up local vars

    mov qword [rsp],my_cat_fileName   ;set up for argv
    mov qword [rsp+8],0               ;null terminate

    mov rax,[rbp+8]         ;move argc into rax
    mov r8,[rbp+48]         ;save the envp variable start in r8
    cmp rax,3               ;if argc == 3
    je  dns_call            ;continue program

    mov rax,60              ;else, exit
    mov rdi,1               ;with satus code of 1
    syscall


;call resolv to turn hostname into an IP adress
;if return from resolv is 0xffffffff, exit with code 2
;resolv (constant char *Hostname)
;                   rdi
;returns network byte order IPv4 address
dns_call:
    mov rdi,[rbp + 24]      ;move the pointer to Hostname to rdi
    call resolv             ;call the dns resolv function from dns64.o
    mov rcx,0xffffffff      ;if return = 0xffffffff, resolv failed
    cmp rax,rcx
    jne port_check          ;else, move to building the socket

    mov rax,1               ;for failure
    mov rdi,2               ;write fail message to stderr
    mov rsi,resolve_fail
    mov rdx,RESOLVE_FAIL_LEN
    syscall
    mov rax,60              ;then exit with status code 2
    mov rdi,2           
    syscall

;call l_atio to convert arg[3] to an int
;if fail move to sock_fail
;if pass, place in network byte order
port_check:
    ;move the IP adress to struct
    mov [client + sockaddr_in.sin_addr],eax 
    mov rdi, 0
    mov rdi,[rbp + 32]  ;move the pointer to sock_num to rdi
    call l_atoi         ;convert to an int
    cmp rax,0           ;if return is == 0
    je sock_fail        ;move to sock_fail
    cmp rax, 65535      ;if return is > 65535 (greatest port num)
    jg sock_fail        ;move to sock_fail
    xchg ah,al          ;swap to network byte order
    ;move the port to  struct
    mov [client + sockaddr_in.sin_port],ax  
   

socket_call:
;sys_socket(int family	,int type,	int protocol)
;               rdi         rsi         rdx
    mov rdi, 2          ;family = AF_INET (2)
    mov rsi, 1          ;type = SOCK_STREAM (1)
    mov rdx, 0          ;protocol = 0
    mov rax, 41         ;call socket()
    syscall
    cmp rax,-1          ;if return is -1
    je sock_fail        ;connection failed  
    mov [sock_desc],eax ;save the fd of the socket in local var        

   
connect_call:
;sys_connect(int fd	,struct sockaddr *uservaddr,int addrlen)
;             rdi            rsi                    rdx
    mov rdi,rax             ;move the fd of the socket to rdi
    mov rsi,client          ;move the address of the struct to rsi
    mov rdx,sockaddr_in_size;move the addrlen to rdx
    mov rax, 42             ;set up for connect() call
    syscall                 ;call connect()

    cmp rax, 0              ;if return is 0
    je fork_children        ;connection established, ready to fork


sock_fail:    
    mov rax,1               ;for failure
    mov rdi,2               ;write fail message to stderr
    mov rsi,connect_fail
    mov rdx,CONNECT_FAIL_LEN
    syscall
    mov rax,60              ;then exit with status code 3
    mov rdi,3           
    syscall


fork_children:

    mov rax, 57
    syscall             ;fork for the first time
    cmp rax, 0          ;if this is the child
    je childA           ;continue to child code

    mov r9,rax         ;save childA pid in r8 for later wait4()
    
    mov rax,57
    syscall             ;fork for the second time   
    cmp rax,0           ;if this is the child
    je childB           ;contine to child code

    mov rbx,rax         ;save childB pid in rbx for future kill()

    jmp parent          ;contine to parent code


childA:
;use syscall dup2 to duplicate the fd of the socket
    mov rdi,[sock_desc]         ;dup the socket
    mov rsi,0                   ;to std in
    mov rax,33                  ;set up for dup
    syscall

    mov rdi, [sock_desc]        ;close the old socket
    mov rax, 3
    syscall

    mov rdi, my_cat_fileName    ;the adress of the program to be execve
    mov rsi, rsp                ;an array of args, set up early
    mov rdx,r8                  ;the array of envp, from the stack
    mov rax,59                  ;call execve
    syscall


childB:
    mov rdi,[sock_desc]         ;dup the socket
    mov rsi,1                   ;to std out
    mov rax,33                  ;set up for dup
    syscall

    mov rdi, [sock_desc]        ;close the old socket
    mov rax, 3
    syscall

    mov rdi, my_cat_fileName    ;the adress of the program to be execve
    mov rsi, rsp                ;an array of args, set up early
    mov rdx,r8                  ;the array of envp, from the stack
    mov rax,59                  ;call execve
    syscall

parent:

    mov rdi, [sock_desc]        ;close the old socket
    mov rax, 3
    syscall

    mov rdi,r9
    mov rsi,error_code  ;pointer to error msg for wait4
    mov rdx,0
    mov r10,0
    mov rax, 61         ;set up for wait4() syscall
    syscall             ;wait for childA to finish


    mov rdi,rbx         ;mov the pid of childB into rdi
    mov rsi,15          ;arg for SIGTERM
    mov rax, 62         ;set up for kill()
    syscall             ;kill childB


    mov rdi,rbx         ;use pid for childB
    mov rsi,error_code  ;pointer to error msg for wait4
    mov rdx,0
    mov r10,0
    mov rax, 61         ;set up for wait4() syscall
    syscall             ;wait for childB to finis

    ;eplilog
    mov rsp,rbp
    pop rbp


    mov rdi,0           ;exit with code 0
    mov rax,60
    syscall


l_atoi:
;look at next value in string
;if 1st value in string in invalid, output 0, stop conversion
;if value is '0-9' perform conversion (0x30 - 0x39)
;else, stop conversion
    push rbx            ;save value of rbx on stack
    mov rbx,0           ;zero out the rbx reg
    mov rax,0           ;zero out the rax reg
    mov rcx,0           ;setup loop counter
.read_loop_top:
    mov byte al,[rdi]   ;load byte from rdi into al
    cmp al,0x30         ;if value is < 0x30
    jl  .end_read       ;end reading
    cmp al,0x39         ;if value is > 0x39
    jg  .end_read       ;end reading

    xor al,0x30         ;perform conversion to a decimal
    inc rdi             ;inc read buffer
    inc rcx             ;inc loop counter
    push rax            ;push the int onto the stack
    jmp .read_loop_top  ;keep reading

.end_read:
    mov rbx,0           ;will use rbx to contain final ans, zero out
    mov r10,1           ;set up scalar for ints coming off of stack
.conv_loop_top:
    cmp rcx,0           ;if read loop counter is <=0
    jle .end_conv       ;end conversion                    
    pop rax             ;mov the next smallest int off of stack
    mul r10             ;scale int to correct magitude (1's,10's,ect)
    add rbx,rax         ;add scaled int to rbx
    imul r10,10         ;increase the scalar by 10
    dec rcx             ;dec the loop counter
    jmp .conv_loop_top  ;contine looping

.end_conv:
    mov rax,rbx         ;mov the ans to rax
    pop rbx             ;restore rbx
    ret


section .data

client: istruc sockaddr_in
    at sockaddr_in.sin_family, dw 2
    at sockaddr_in.sin_port, dw 0x0000
    at sockaddr_in.sin_addr, dd 0x00000000
iend

resolve_fail: db 'unable to resolve host',10,0
RESOLVE_FAIL_LEN equ $-resolve_fail
connect_fail: db 'connection attempt failed',10,0
CONNECT_FAIL_LEN equ $-connect_fail

my_cat_fileName: db './assign3',0


sock_desc: db 0x00000000

error_code: db 0x00000000


section .bss

port_buff: resb 2   ;need 2 bytes to hold port number



