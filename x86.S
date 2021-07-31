/*
Run with the following series of commands (on Linux)
    as -o x86.o x86.S --32
    ld -s -o x86 x86.o -m elf_i386
    ./x86

This needs the as assembler, it should come with gcc

Debugging:
    You can pipe input into GDB with this:
    run < <(echo foo)

    You can set breakpoints by adding an int3 instruction
*/

sys_exit = 1
sys_read = 3
sys_write = 4
stdin = 0
stdout = 1
syscall_interrupt_vector = 0x80
line_feed = 0xA
buffer_size = 48
digit_9 = 0x39
digit_0 = 0x30


.text
    .global _start

prompt:
    .ascii "Number of iterations: "
    prompt_len = . - prompt

debug:
    .ascii "DEBUG\n"
    debug_len = . - debug

input_invalid_str:
    .ascii "Input was invalid. Exiting\n"
    input_invalid_str_len = . - input_invalid_str

_start:
    pushl $prompt
    pushl $prompt_len
    call print

    jmp read_int



read_int:
    # Create stack frame
    pushl %ebp
    movl %esp, %ebp

    # Allocate buffer on stack
    subl $buffer_size, %esp
    movl %esp, %ecx # Use ecx as our pointer into the buffer
    subl $4, %esp
    movl %ecx, (%esp) # Our original pointer


    movl $stdin, %ebx # file handle
    movl $1, %edx # length
# Do not use ebx or edx registers here, we only set them once and then use them for sys_read
input_loop:
    movl %ecx, %eax
    subl (%esp), %eax
    cmpl $buffer_size, %eax

    jge input_invalid

    movl $sys_read, %eax # syscall number
    int $syscall_interrupt_vector

    movl %ecx, %eax
    addl $1, %ecx
    cmpl $line_feed, (%eax)
    jne input_loop


    movl %ecx, %eax
    subl (%esp), %eax
    subl $1, %eax

    pushl (%esp)
    pushl %eax
    call parse_int

    movl %ebp, %esp
    popl %ebp

    movl %eax, %ebx
    jmp exit_with_code

debug_print:
    pushl $debug
    pushl $debug_len
    call print
    ret

print:
    popl %esi # preserve return address
    popl %edx # length
    popl %ecx # char array
    movl $stdout, %ebx # file handle (i.e. stdout)
    movl $sys_write, %eax # syscall number
    int $syscall_interrupt_vector

    pushl %esi
    ret

parse_int:
    popl %esi # preserve return address
    popl %edx # length
    popl %ecx # char array
    pushl %esi

    movl $0, %esi # temp value
    movl %edx, %ebx # power of 10
    subl $1, %ebx

    cmpl $0, %edx
    je input_invalid

    # Create stack frame
    pushl %ebp
    movl %esp, %ebp

    subl $4, %esp
    movl %edx, (%esp) # We're low on registers, so we put the length on the stack

parse_loop:
    movl $0, %eax
    movb (%ecx), %al
    cmpb $digit_0, %al
    jl input_invalid
    cmpb $digit_9, %al
    jg input_invalid

    subl $digit_0, %eax
    movl %ebx, %edi

exponentiate:
    cmpl $0, %edi
    je end_exponentiate

    movl $10, %edx # Cannot multiply by an immediate
    mull %edx # This will zero out edx because multiplies store the low bytes in eax and the high bytes in edx

    subl $1, %edi
    jmp exponentiate
end_exponentiate:
    addl $1, %ecx
    subl $1, %ebx

    addl %eax, %esi

    cmpl $0, %ebx
    jge parse_loop

    movl %ebp, %esp
    popl %ebp

    movl %esi, %eax
    ret

input_invalid:
    pushl $input_invalid_str
    pushl $input_invalid_str_len
    call print
    movl $-1, %ebx
exit_with_code: # Code is in ebx
    movl $sys_exit, %eax # syscall number
    int $syscall_interrupt_vector

exit_successfully:
    movl $0, %ebx
    jmp exit_with_code

.data
