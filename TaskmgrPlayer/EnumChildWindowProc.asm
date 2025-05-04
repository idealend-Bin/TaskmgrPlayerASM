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



; EnumChildWindowsProc - Implements the C-compatible callback function in x86-64 Assembly (ML64, Intel syntax)
; BOOL CALLBACK EnumChildWindowsProc(HWND hWnd, LPARAM lParam)
;
; C Signature: BOOL CALLBACK EnumChildWindowsProc(HWND hWnd, LPARAM lParam);
; x64 ABI:
;   - hWnd (Param 1) in RCX, lParam (Param 2) in RDX upon entry.
;   - Return value (BOOL) in EAX.
;   - Non-volatile registers (RBX, RBP, RDI, RSI, R12-R15) must be preserved by the callee.
;   - RSP must be 16-byte aligned BEFORE a call instruction. Needs 32 bytes shadow space.
;   - Parameters are typically accessed at [rbp + 16], [rbp + 24] etc. after standard prologue.
;
; Compiles with: ml64.exe /c /Fo EnumChildWindowsProc.obj EnumChildWindowsProc.asm
; Links with:    link.exe ... EnumChildWindowsProc.obj ... user32.lib legacy_stdio_definitions.lib ...
; Requires:      Global variables and IsSmallerWindowLogic defined elsewhere/declared extern.

    .code   ; Code segment starts here

    ; --- External Declarations for functions called by EnumChildWindowsProc ---
    extern GetClassNameW: Proc   ; From User32.dll
    extern lstrcmpW: Proc      ; From User32.dll
    extern IsSmallerWindowLogic: Proc ; Our assembly function

    ; --- External Declarations for Global Variables used by EnumChildWindowsProc ---
    extern EnumHWnd: QWORD       ; HWND (pointer size)
    extern ClassNameToEnum: QWORD ; wchar_t[256] array (get address)


    ; Define the start of the procedure (function)
    ; BOOL CALLBACK EnumChildWindowsProc(HWND hWnd, LPARAM lParam)
EnumChildWindowsProc Proc
    LOCAL hWnd: QWORD
    ; --- Function Prologue ---
    push rbp            ; Save caller's RBP. RSP = OriginalRSP_entry - 8
    mov rbp, rsp        ; Set RBP to current RSP. RBP = OriginalRSP_entry - 8

    ; Allocate stack space:
    ;   WndClassName[256]: 256 * 2 = 512 bytes
    ;   Shadow Space for calls: 32 bytes
    ;   Saved non-volatile registers (RBX if used): 8 bytes
    ; Total needed: 512 + 32 + 8 = 552 bytes.
    ; Round up to nearest multiple of 16: 560 bytes.
    sub rsp, 560        ; Allocate stack space. RSP = OriginalRSP_entry - 8 - 560 = OriginalRSP_entry - 568.
                        ; If OriginalRSP_entry % 16 == 8 (as observed before), RSP now ends in ...8 - 568 = ...8 - 8 = ...0 (Aligned).

    ; Save non-volatile registers we *might* use. Saving RBX is standard practice if its value needs preserving.
    mov QWORD PTR [rbp - 8], rbx ; Save non-volatile RBX at [rbp-8]
    mov hWnd, rcx
    ; Stack Frame Layout (relative to RBP after prologue and saving RBX):
    ; rbp + 24        : lParam (Param 2) - passed in RDX, accessible here via RBP
    ; rbp + 16        : hWnd (Param 1)   - passed in RCX, accessible here via RBP
    ; rbp + 8         : Return Address
    ; rbp + 0         : Saved Caller's RBP
    ; rbp - 8         : Saved RBX value <<< RBX is here
    ; rbp - 512       : Start of local WndClassName[256] buffer (512 bytes) <<< from rbp - 512 to rbp - 1
    ; rbp - 560       : RSP BEFORE internal calls (ALIGNED)
    ; rbp - 560 to rbp - 592: Shadow space (32 bytes, below RSP before a call)


    ; --- Allocate local buffer for WndClassName[256] ---
    ; Space is already allocated by sub rsp, 560. The buffer starts at rbp - 512.
    ; We don't need explicit allocation instructions here, just use the address.


    ; --- Call GetClassNameW(hWnd, WndClassName, 256) ---
    ; Parameter 1 (hWnd): Get from caller's stack relative to RBP. In C++ this was simply 'hWnd'.
    ;mov rcx, QWORD PTR [rbp + 16] ; Get hWnd (Param 1) from caller's stack into RCX
    ; Parameter 2 (lpClassName): Address of local WndClassName buffer on *our* stack frame
    lea rdx, [rbp - 512]          ; Load address of WndClassName buffer (at rbp - 512) into RDX
    ; Parameter 3 (nMaxCount): 256 (size of the buffer including null terminator)
    mov r8d, 256                  ; Move size 256 into R8D (lower 32 bits of R8)
    ; RSP is already 16-byte aligned (at rbp - 560)
    call GetClassNameW            ; Call GetClassNameW. Return value (length) in EAX.
                                  ; Note: C++ source didn't check length, so we don't need to either for functional equivalence.


    ; --- Compare WndClassName with ClassNameToEnum ---
    ; Use lstrcmpW(WndClassName, ClassNameToEnum)
    ; Parameter 1 (lpString1): Address of local WndClassName buffer
    lea rcx, [rbp - 512]          ; Address of WndClassName buffer into RCX
    ; Parameter 2 (lpString2): Address of global ClassNameToEnum array
    lea rdx, [ClassNameToEnum]   ; Load address of global _ClassNameToEnum into RDX
    ; RSP is already 16-byte aligned
    call lstrcmpW                 ; Call lstrcmpW. Return value (difference) in EAX.

    ; Check if lstrcmpW returned 0 (strings are equal)
    test eax, eax                 ; Test EAX against itself. Sets ZF if EAX is 0.
    jne  EnumProc_SkipIfMatch     ; If not equal (ZF=0, strings differ), jump to SkipIfMatch

    ; --- If lstrcmpW == 0 (Class names match) ---

    ; --- Check if EnumHWnd == 0 ---
    ; Use cmp QWORD PTR [_EnumHWnd], 0
EnumProc_IfMatch: ; Label for the start of the block where lstrcmpW returned 0
    cmp QWORD PTR [EnumHWnd], 0  ; Compare value of global _EnumHWnd with 0
    jne  EnumProc_EnumHWndNotNull ; If not equal, jump to the 'else' block

    ; --- If EnumHWnd == 0 (First match or smaller match was null) ---
    ; EnumHWnd = hWnd;
    mov rax, hWnd ; Get hWnd (Param 1) from caller's stack into RAX
    mov QWORD PTR [EnumHWnd], rax ; Store hWnd into global _EnumHWnd

    ; Jump to the end of the 'if (lstrcmpW == 0)' block's logic
    jmp  EnumProc_EndIfMatchLogic

EnumProc_EnumHWndNotNull: ; Label for the 'else' block
    ; --- If EnumHWnd != 0 ---
    ; Call IsSmallerWindowLogic(hWnd)
    ; Parameter 1 (hWnd): Get from caller's stack
    mov rcx, hWnd ; Get hWnd (Param 1) from caller's stack into RCX
    ; RSP is already 16-byte aligned
    call IsSmallerWindowLogic     ; Call IsSmallerWindowLogic. Return value (BOOL) in EAX.

    ; Check if IsSmallerWindowLogic returned TRUE (non-zero)
    test eax, eax                 ; Test EAX against itself. Sets ZF if EAX is 0.
    je   EnumProc_EndIfMatchLogic ; If equal (result is 0/FALSE), jump to the end of if/else logic

    ; --- If IsSmallerWindowLogic returned TRUE ---
    ; EnumHWnd = hWnd;
    mov rax, hWnd ; Get hWnd (Param 1) from caller's stack into RAX
    mov QWORD PTR [EnumHWnd], rax ; Store hWnd into global _EnumHWnd

EnumProc_EndIfMatchLogic: ; Label for the end of the if (EnumHWnd==0) / else block


EnumProc_SkipIfMatch: ; Label for the jump target if lstrcmpW != 0
    ; --- Return TRUE ---
    ; CALLBACK function returns BOOL in EAX. TRUE is non-zero, commonly 1.
    mov eax, 1                    ; Set return value EAX to 1 (TRUE)

    ; --- Function Epilogue ---
    ; Standard epilogue: restore saved non-volatile registers, deallocate stack, restore RBP, return.
    mov rbx, QWORD PTR [rbp - 8] ; RESTORE: Restore original RBX value
    add rsp, 560              ; Deallocate stack space (must match sub rsp, 560)
    pop rbp                   ; Restore caller's RBP
    ret                       ; Return from the procedure

EnumChildWindowsProc EndP ; Define the end of the procedure

; --- Other Assembly Code (FindWnd, IsSmallerWindowLogic) Would Go Here or in Other Files ---
; Ensure all needed procedures are defined or declared extern and linked.

; Example extern for globals if defined in C++ (needed if not in same file)
; extern _WindowClassName: QWORD
; extern _WindowTitle: QWORD
; extern _ChildClassName: QWORD

; Example extern for other functions if defined in C++ or other ASM files
; extern FindWindowW: Proc
; extern EnumChildWindows: Proc ; EnumChildWindowsProc is called BY EnumChildWindows, not vice-versa

; Remember to add the extern _VariableName: Size declarations for any globals used here

; And the extern EnumChildWindowsProc: Proc in FindWnd.asm if they are in separate files.


END ; End of the assembly file