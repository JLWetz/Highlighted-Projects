;Name: Lance Wetzel
;Last Modified: May 22, 2019
;Course Number: CS 3140
;Assignment 4


bits 64

global l_strlen
global l_strcmp
global l_gets
global l_puts
global l_write
global l_open
global l_close
global l_exit
global l_atoi
global l_itoa
global l_rand


section .text

;-------------------------------------------------------------------
;int l_strlen(char *str);
;                rdi
;Return the length of the null terminated string, str. 
;The null character should not be counted.
l_strlen:
    push rbx        ;save rbx on the stack
    mov rcx,-1      ;set rep counter to max value
    mov al,0x00     ;looking for null terminator
    mov rbx,rdi     ;save the orignial pointer adress
    cld             ;clear direction flags
    repne scasb     ;scan string pointed at by rdi
    sub rdi,rbx     ;get length of string by sub the original adress
                    ;and the modified adress from scasb
    dec rdi         ;must dec by 1 to not count the last byte
    mov rax,rdi     ;move counter to rax for ret
    mov rdi,rbx     ;restore orginal pointer to rdi
    pop rbx         ;restor rbx
    ret             ;return
;-------------------------------------------------------------------
;-------------------------------------------------------------------
;int l_strcmp(char *str1, char *str2);
;Return 0 if str1 and str2 are equal, return 1 if they are not. 
;Note that this is not quite the same
;definition as the C standard library function strcmp.
l_strcmp:
    call l_strlen   ;get length of string in rdi(1st string)
    push rax        ;push result to stack
    xchg rsi,rdi    ;swap rsi,rdi
    call l_strlen   ;get length of 2nd string
    pop rcx         ;pop 1st result, will also use as loop counter
    sub rax,rcx     ;if rax!=rcx, cannot be same string, also sets rax to 0
    ;jnz .not_equal  ;jump to not equal
    cld             ;clear DF for cmpsb
.top_loop:
    cmpsb           ;comp the bytes at [rsi],[rdi] and inc the address
    jnz .not_equal  ;if ZF!=0, jmp to not_equal
    dec rcx         ;dec loop counter
    cmp rcx,0       ;if counter <= 0
    jle .done       ;jmp to done
    jmp .top_loop   ;else, contine to loop
.not_equal:
    mov rax,1
.done:
    ret
;--------------------------------------------------------------------
;--------------------------------------------------------------------
;int l_gets(int fd, char *buf, int len);
;             rdi     rsi       rdx
l_gets:
    push rbx            ;save rbx on the stack
    push rcx            ;save rcx on the stack
    mov r8,rsi          ;save the original buffer position
                        ;if rdx = 0, read nothing and return 0
    cmp rdx,0
    jz .done
    mov r10,0           ;init counter to total bytes read
    mov rbx, rdx        ;save len in rbx
    mov rdx,1           ;set up to read one byte at a time

.read:
    mov rax,0           ;make read syscall
    syscall
    cmp rax,0           ;if return is <=0
    jle .done           ;jmp to done
    inc r10             ;inc bytes read counter
    dec rbx             ;dec total reads counter
    mov byte al,[rsi]   ;
    inc rsi             ;position rsi to read next byte
    cmp al,0xA          ;check if [rsi] is '/n'
    jz  .done           ;if so, done reading
    cmp rbx,0           ;if tot read counter == 0
    jz .done            ;done reading
    jmp .read
.clean:
    mov r10, 0      ;set bytes read to 0
.done:
    mov byte [rsi],0x00
    mov rsi,r8
    mov rax,r10     ;return bytes read
    pop rcx
    pop rbx         ;restore rbx
    ret

;----------------------------------------------------------------
;----------------------------------------------------------------
;void l_puts(const char *buf)
;                   rdi
l_puts:
    mov al,[rdi]
    cmp al,0            ;if the contents of the pointer is null, 
    jle .done           ;jump to done, no write happens
    call l_strlen       ;get length of the string
    mov rdx,rax         ;return of the strlen is the count for write
    mov rsi,rdi         ;mvoe the address of the string to rsi for write
    mov rdi,1
    mov rax,1
    syscall             ;make write syscall to stdout
.done:
    ret

;-------------------------------------------------------------------


;-------------------------------------------------------------------
;int l_write(int fd, char *buf, int len, int *err);
;              rdi      rsi        rdx        rcx
l_write:
    mov     rax,1
    syscall         ;call write, rdi,rsi,rdx already setup by function call
    cmp rax,0       ;if rax is < 0 there is an error     
    jge .no_err     ;else, set r10 to 0, and return
    mov rcx,rax     ;set rax to -1, and r10 to abs(rax)
    neg rcx         ;error value
    mov rax, -1     ;error code
    jmp .done
.no_err:
    mov rcx,0       ;success code
.done:
    ret
;--------------------------------------------------------------------
;--------------------------------------------------------------------
;int l_open(const char *name, int flags, int mode, int *err);
;                  rdi            rsi       rdx       rcx
l_open:
    mov rax,2       ;call open, parameters already set up by caller
    syscall         
    cmp rax,0       ;if rax is < 0 there is an error
    jge .no_err     ;else, set rcx to 0, and return
    mov rcx,rax     ;set rax to -1, and r10 to abs(rax)
    neg rcx         ;error value
    mov rax, -1     ;error code
    jmp .done
.no_err:
    mov rcx,0
.done:
    ret

;-------------------------------------------------------------------
;-------------------------------------------------------------------
;int l_close(int fd, int *err);
;              rdi      rsi
l_close:
    mov rax,3       ;call close, parameters already set up by caller
    syscall     
    cmp rax,0       ;if rax is < 0 there is an error,
    jge .no_err     ;else, set rcx to 0, and return
    mov rsi,rax     ;set rax to -1, and r10 to abs(rax)
    neg rsi         ;error value
    mov rax, -1     ;error code
    jmp .done
.no_err:
    mov rsi,0
.done:
    ret
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;void l_exit(int rc);
l_exit:
    mov rax,60      ;call exit, parameter already set up
    syscall
;-----------------------------------------------------------------

;-----------------------------------------------------------------
;unsigned int l_atoi(char *value);
;                        rdi
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

;---------------------------------------------------------------------
;---------------------------------------------------------------------
;char *l_itoa(unsigned int value, char *buffer);
;                      rdi             rsi
;return a pointer to the buffer
l_itoa:
    push rbx            ;save rbx on the stack
    mov r8,rsi          ;save original vale of rsi
    mov rax,rdi         ;mov val to rax for operations
    mov r10,1           ;set up scalar
    mov rbx,0           ;set up digit coutner
;determine number of digits in value
.dig_count:
    sub rax,r10         ; rax = rax - r10
    js  .end_dig_count  ;if rax is neg, done counting digits
    mov rax,rdi         ;reset rax to orig val
    imul r10,10         ;increase scalar by mag of 10
    inc rbx             ;inc the digits counter
    jmp .dig_count      ;continue counting digits


.end_dig_count:
    mov rax,rdi         ;reset rax with the value
    cmp rbx,0           ;if digit coutner == 0
    jz  .zero_case      ;jmp to zero case

.digits_gt_ones:
    mov rcx,1                   ;rcx will be the divisor
    mov r10,rbx                 ;set up the divisor scalar
    dec r10                     ;as the loop counter to control iterations
    cmp r10,0                   ;if loop counter == 0
    jz .convert_and_load_number ;one the ones digit, ready to load
.set_divisor_loop:
    
    imul rcx,10                 ;of the x10 increase in the divisor
    dec r10                     ;dec the loop counter
    cmp r10,0                   ;if loop counter is > 0
    jg .set_divisor_loop        ;keep multipliting by 10

.strip_number:
    mov rdx,0           ;zero the rdx to prep for DIV
    div rcx             ;divide rax by rcx, the result is the digit
                        ;to be converted
.convert_and_load_number:
    add rax,0x30        ;convert to ascii
    mov byte [rsi],al   ;move to address pointed at by rsi
    inc rsi             ;inc the buffer pointer
    dec rbx             ;dec the digit counter
    mov rax,rdx         ;set rax to value of the remainder
    cmp rcx,1           ;if operation was on the ones digit
    jz .cleanup         ;done with conversions, move to clean
    jmp .digits_gt_ones ;else, jmp to top of loop

.zero_case:
    mov byte [rsi],0x30 ;load "0" into rsi
    inc rsi             ;inc the buffer pointer


.cleanup:
    mov byte [rsi],0x00 ;end string in null terminator
    mov rax,r8          ;set up to return pointer to begining of string
    pop rbx             ;restore rbx
    ret

;-------------------------------------------------------------------------
;-------------------------------------------------------------------------
;unsigned int l_rand(unsigned int n);
l_rand:
;open /dev/urandom
;int l_open(const char *name, int flags, int mode, int *err);
;                  rdi            rsi       rdx       rcx
;prolog
    push rbp
    mov rbp,rsp
    sub rsp,16
    mov r8,rbx          ;save rbx
    mov rbx,rdi         ;save n in rbx
    mov rdx,0           ;'mode 0 for open call
    cmp rbx,1           ;if n <= 1
    jle .ret_zero       ;do not get random value, just return 0
    mov rdi,urand       ;filename saved in urand
    mov rsi,0           ;read-only
    mov rdx,0           ;mode 0
    mov rcx,rbp         ;the pointer to err
    call l_open         ;open /dev/urandom

;read 4 bytes into rbx
;int l_gets(int fd, char *buf, int len);
;             rdi     rsi       rdx
    mov rdi,rax         ;set up fd from ret of l_open
    mov rcx,rax         ;save fd in rcx, will not be changed by l_gets
    sub rbp,8           ;have rbp point at the buffer locatio
    mov rsi,rbp         ;load pointer to the buffer in rsi
    
    mov rdx,5           ;only read 4 (5-1) bytes
    call l_gets
;close /dev/urandom
;int l_close(int fd, int *err);
    mov rdi,rcx         ;setup close of fd
    mov rsi,rsp         ;load the pointer to err
    call l_close

;mod rbx by n
    xor rdx,rdx         ;zero out rdx
    mov eax,[rbp]       ;move the 4 bytes into eax
    add rbp,8           ;restore rbp
    div ebx             ;divide eax/ebx
.ret_zero:
    mov rax,rdx         ;place the remainder in rax/or 0 if jumped here    
    mov rbx,r8          ;restore rbx
;elpilog
    mov rsp,rbp
    pop rbp
    ret



section .data

urand: db '/dev/urandom',0
