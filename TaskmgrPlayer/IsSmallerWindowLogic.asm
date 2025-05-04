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



; IsSmallerWindowLogic - Implements the C-compatible function in x86-64 Assembly (ML64, Intel syntax)
; BOOL IsSmallerWindowLogic(HWND hWnd)
;
; C Signature: BOOL IsSmallerWindowLogic(HWND hWnd);
; x64 ABI:
;   - hWnd (Parameter 1) is passed IN RCX upon function entry.
;   - Return value (BOOL) is placed in EAX.
;   - Non-volatile registers (RBX, RBP, RDI, RSI, R12-R15) must be preserved by the callee.
;
; Compiles with: ml64.exe /c /Fo IsSmallerWindowLogic.obj IsSmallerWindowLogic.asm
; Links with:    link.exe your_main.obj IsSmallerWindowLogic.obj user32.lib ... (other libraries)
; Requires:      EnumHWnd global variable defined elsewhere.

    .code   ; Code segment starts here

    extern GetWindowRect: Proc ; Declare external WinAPI function
    extern EnumHWnd: QWORD     ; Declare global variable

IsSmallerWindowLogic Proc

    ; --- Function Prologue ---
    push rbp
    mov rbp, rsp
    sub rsp, 96 ; Allocate stack space (88 bytes: 32 shadow + 32 RECTs + 16 INTs + 8 saved RBX)

    ; Save non-volatile register RBX.
    mov QWORD PTR [rbp - 8], rbx ; Save non-volatile RBX at [rbp-8]

    ; Stack Frame Layout (relative to RBP after prologue and saving RBX):
    ; rbp + ...       : Caller params 5+
    ; rbp + 16        : Parameter 1 (hWnd) - NOTE: THIS IS WHERE IT *COULD* BE SAVED BY CALLER,
    ;                 ; BUT THE VALUE IS IN RCX UPON ENTRY!
    ; rbp + 8         : Return Address
    ; rbp + 0         : Saved Caller's RBP
    ; rbp - 8         : Saved RBX value <<< RBX is here
    ; rbp - 12        : Local tW (4 bytes) <<< Locals below saved RBX
    ; rbp - 16        : Local tH (4 bytes)
    ; rbp - 20        : Local cW (4 bytes)
    ; rbp - 24        : Local cH (4 bytes)
    ; rbp - 40        : Start of local tRect (16 bytes)
    ; rbp - 56        : Start of local cRect (16 bytes)
    ; rbp - 88        : RSP


    ; --- Call GetWindowRect(hWnd, &tRect) ---
    ; Parameter 1 (hWnd): Is already in RCX upon entry. USE RCX DIRECTLY.
    ; >>> DELETE THIS LINE: mov rcx, QWORD PTR [rbp + 16] ; <--- INCORRECT READING
    ; rcx already contains the correct hWnd value from the caller

    lea rdx, [rbp - 40]         ; Parameter 2: Address of local tRect (at rbp - 40) into RDX
    ; RCX already has hWnd
    call GetWindowRect          ; Call the WinAPI function

    ; --- Call GetWindowRect(EnumHWnd, &cRect) ---
    ; Parameter 1 (hWnd): EnumHWnd (global variable)
    ; This call needs RCX to contain EnumHWnd. It WILL overwrite the original hWnd value in RCX.
    mov rcx, QWORD PTR [EnumHWnd] ; Get the value of the global variable EnumHWnd into RCX
    lea rdx, [rbp - 56]         ; Parameter 2: Address of local cRect (at rbp - 56) into RDX
    call GetWindowRect          ; Call the WinAPI function

    ; --- Calculations: tW = tRect.right - tRect.left ---
    ; ... (calculations remain the same) ...
    mov eax, DWORD PTR [rbp - 40 + 8] ; Get tRect.right
    sub eax, DWORD PTR [rbp - 40 + 0] ; Subtract tRect.left
    mov DWORD PTR [rbp - 12], eax      ; Store tW

    ; --- Calculations: tH = tRect.bottom - tRect.top ---
    mov ecx, DWORD PTR [rbp - 40 + 12] ; Get tRect.bottom
    sub ecx, DWORD PTR [rbp - 40 + 4] ; Subtract tRect.top
    mov DWORD PTR [rbp - 16], ecx      ; Store tH

    ; --- Calculations: cW = cRect.right - cRect.left ---
    mov edx, DWORD PTR [rbp - 56 + 8] ; Get cRect.right
    sub edx, DWORD PTR [rbp - 56 + 0] ; Subtract cRect.left
    mov DWORD PTR [rbp - 20], edx     ; Store cW

    ; --- Calculations: cH = cRect.bottom - cRect.top --- (Corrected Bug Logic)
    mov r8d, DWORD PTR [rbp - 56 + 12] ; Get cRect.bottom
    sub r8d, DWORD PTR [rbp - 56 + 4] ; Subtract cRect.top
    mov DWORD PTR [rbp - 24], r8d     ; Store cH


    ; --- Comparison: cW * cH < tW * tH ---
    ; ... (comparison remains the same) ...
    mov eax, DWORD PTR [rbp - 20] ; Get cW into EAX
    mov edx, DWORD PTR [rbp - 24] ; Get cH into EDX
    imul edx                      ; cW * cH -> EDX:EAX
    mov ebx, eax                  ; Save cW*cH result (EAX) into EBX

    mov eax, DWORD PTR [rbp - 12]  ; Get tW into EAX
    mov edx, DWORD PTR [rbp - 16]  ; Get tH into EDX
    imul edx                      ; tW * tH -> EDX:EAX

    cmp ebx, eax                  ; Compare cW*cH (EBX) vs tW*tH (EAX)
    jl  SmallerWindow_True

    ; --- Return FALSE ---
    mov eax, 0
    jmp SmallerWindow_Exit

SmallerWindow_True:
    ; --- Return TRUE ---
    mov eax, 1

SmallerWindow_Exit:
    ; --- Function Epilogue ---
    ;mov rbx, QWORD PTR [rbp - 8] ; RESTORE: Restore original RBX value from stack
    ;add rsp, 88             ; Deallocate stack space
    ;pop rbp                 ; Restore the caller's RBP
    leave
    ret                     ; Return from the procedure

IsSmallerWindowLogic EndP

; ... data segment if needed, END directive ...
End