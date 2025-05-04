; Copyright (c) 2025 Idealend Bin
; This file is part of TaskmgrPlayerASM.
; TaskmgrPlayerASM is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; TaskmgrPlayerASM is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with TaskmgrPlayerASM. If not, see <https://www.gnu.org/licenses/>.



; Ensure you have a .data segment defined somewhere in your .asm file
.data
    OutPutDbg_FormatString db "Frame %d at %.3fs. output: %dx%d ,cost %d ms.", 0
    ; Define the double constant 1000.0
    double_1000 real8 1000.0 ; Using real8 for double precision float

; Ensure you have a .code segment defined somewhere
.code

; --- External Declarations for functions called by OutPutDbg ---
; These should be defined as extern somewhere before OutPutDbg Proc
extern GetStdHandle: Proc
extern SetConsoleCursorPosition: Proc
extern printf: Proc
extern clock: Proc
extern WaitKey: Proc ; Your C++ wrapper (needs extern if in separate file)


OutPutDbg Proc
    ; LOCALs for parameters copied to stack and local variables
    LOCAL local_frameCount_ptr: QWORD
    LOCAL local_frameTime: REAL8
    LOCAL local_w: DWORD
    LOCAL local_h: DWORD
    LOCAL local_s_clock: QWORD ; clock_t (Assuming 8 bytes on x64)
    LOCAL temp_double: REAL8 ; Temp space for floating point calculations
    LOCAL SavedXmm6_Space: OWORD ; Space to save XMM6 (OWORD is 16 bytes)
    LOCAL SavedXmm7_Space: OWORD ; Space to save XMM7 (OWORD is 16 bytes)

    ; --- Prologue (Standard x64 ABI with Alignment and Register Saving) ---
    push rbp
    mov rbp, rsp
    ; Save Non-Volatile GPR Registers as per x64 ABI (Matching compiler's saves)
    push rbx
    push rsi
    push rdi
    push r14

    ; Allocate stack space for LOCAL variables, Saved XMMs (using LOCAL space), Shadow Space (32 bytes) + printf stack args (8 bytes).
    ; Total LOCALs declared (GPR related + XMM space): 40 + 32 = 72 bytes.
    ; Additional space needed below LOCALs = 32 (shadow) + 8 (printf stack arg) = 40 bytes.
    ; Total allocation required below RBP: 72 (LOCALs) + 40 (additional below locals) = 112 bytes.
    ; Your working code used sub rsp, 128. Let's stick to 128 for compatibility with your working version's stack layout.
    sub rsp, 128 ; Allocate space (Using 128 to match your working code)

    ; Save XMM6 and XMM7 using the space declared with LOCAL names
    movups SavedXmm6_Space, xmm6 ; Save XMM6 (using movups for safety)
    movups SavedXmm7_Space, xmm7 ; Save XMM7 (using movups for safety)

    ; --- Parameter Access and Local Storage (Using LOCALs and RBP+offset for stack param) ---
    ; RCX: frameCount*
    ; XMM1: frameTime (double)
    ; R8D: w
    ; R9D: h
    ; [rbp + offset]: s (clock_t)
    ; With push rbp, mov rbp, rsp, push rbx,rsi,rdi,r14, sub rsp, 128:
    ; s is at [rbp + 28h] (5th parameter after 4 pushed GPRs).
    ; Let's use [rbp + 28h] for accessing s.

    ; Copy parameters from initial registers/stack to LOCAL variables
    mov rax, rcx                 ; frameCount* is in RCX
    mov local_frameCount_ptr, rax

    movsd xmm0, xmm1             ; frameTime is in XMM1
    movsd local_frameTime, xmm0

    mov eax, r8d                 ; w is in R8D
    mov local_w, eax

    mov eax, r9d                 ; h is in R9D
    mov local_h, eax

    mov rax, [rbp + 28h]         ; s is on stack at [rbp + 28h] (5th parameter after 4 pushed GPRs)
    mov local_s_clock, rax

    ; --- SetConsoleCursorPosition(GetStdHandle(STD_OUTPUT_HANDLE), { 0,1 }) ---
    ; Call GetStdHandle first
    mov ecx, 0FFFFFFF5h ; STD_OUTPUT_HANDLE is -11
    call GetStdHandle   ; Result is in RAX

    ; Prepare parameters for SetConsoleCursorPosition
    mov rcx, rax        ; Arg1: Handle from GetStdHandle
    mov edx, 00010000h ; Arg2: COORD {0,1} (X=0, Y=1 packed into DWORD)
    call SetConsoleCursorPosition
    ; Return value (BOOL) in EAX (ignored)

    ; --- printf(...) call ---
    ; Args for printf: RCX (format), EDX (*frameCount), XMM0 (double), R8D (w), R9D (h), Stack ([rsp+20h]) ((int)(clock - s))
    ; Stack args start at [rsp + 20h] (after 32 bytes shadow space). We need 8 bytes for the int arg.

    ; Arg2 (EDX): *frameCount (int)
    mov rax, local_frameCount_ptr ; Load pointer
    mov edx, dword ptr [rax]      ; Load integer value

    ; Arg3 (XMM0): (double)*frameCount * frameTime / 1000.0
    mov rax, local_frameCount_ptr
    mov eax, dword ptr [rax]     ; Load integer value into EAX
    movd xmm0, eax               ; Move integer from EAX to XMM0 low bits
    cvtdq2pd xmm0, xmm0          ; Convert integer in XMM0 to double in XMM0
    movsd xmm1, local_frameTime  ; Load frameTime (double) into XMM1
    mulsd xmm0, xmm1             ; (*frameCount) * frameTime is in XMM0
    movsd xmm1, double_1000      ; Load 1000.0 into XMM1
    divsd xmm0, xmm1             ; Result / 1000.0 is in XMM0

    ; Arg4 (R8D): w (int)
    mov eax, local_w
    mov r8d, eax

    ; Arg5 (R9D): h (int)
    mov eax, local_h
    mov r9d, eax

    ; Arg6 (Stack @ [rsp+20h]): (int)(clock() - s)
    ; Call clock() first (result in EAX)
    call clock

    ; Calculate clock() - s (current time - start time)
    mov rdx, local_s_clock ; Load start time 's'
    sub rax, rdx           ; Calculate difference (clock_t, assumed 64-bit)
    ; Store 32-bit result on stack for printf
    mov dword ptr [rsp + 20h], eax ; Store the lower 32 bits (int)

    ; Arg1 (RCX): Format string address - Set THIS LAST before the call!
    lea rcx, OutPutDbg_FormatString

    call printf ; Call printf

    ; --- While loop implementation ---
    ; while ((double)*frameCount * frameTime > (double)clock())
    @@WhileLoopCondition:
        ; Calculate (double)*frameCount * frameTime
        mov rax, local_frameCount_ptr ; Load pointer
        mov eax, dword ptr [rax]      ; Load integer value into EAX
        movd xmm0, eax               ; Move integer to XMM0
        cvtdq2pd xmm0, xmm0          ; Convert to double in XMM0
        movsd xmm1, local_frameTime  ; Load frameTime into XMM1
        mulsd xmm0, xmm1             ; (*frameCount) * frameTime is in XMM0

        ; Get current time from clock()
        call clock ; Result in EAX (int clock_t)

        ; Convert clock() result to double
        movd xmm1, eax               ; Move int to XMM1
        cvtdq2pd xmm1, xmm1          ; Convert to double in XMM1

        ; Compare (double)*frameCount * frameTime (XMM0) > (double)clock() (XMM1)
        comisd xmm0, xmm1            ; Compare XMM0 with XMM1. Sets EFLAGS.

        ; We want to continue the loop if XMM0 > XMM1.
        ; The compiler's logic was `jbe @@WhileLoopEnd`.
        jbe @@WhileLoopEnd ; If CalculatedTime <= CurrentTime (ZF=1 or CF=1), exit loop

    @@WhileLoopBody:
        ; Call WaitKey(1)
        mov ecx, 1 ; Arg1: 1
        call WaitKey ; Call the C++ wrapper

        ; Jump back to the condition check
        jmp @@WhileLoopCondition

    @@WhileLoopEnd: ; Label for the end of the while loop

    ; --- Epilogue ---
    ; Deallocate stack space (must match prologue's allocation)
    ; Our sub rsp was 128.
    add rsp, 128

    ; Restore saved XMM registers using LOCAL names
    movups xmm6, SavedXmm6_Space ; Restore XMM6
    movups xmm7, SavedXmm7_Space ; Restore XMM7

    ; Restore saved GPR registers (order matters, opposite of pushes)
    leave
    ret
OutPutDbg EndP

; Ensure the file ends with END directive
END