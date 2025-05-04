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



; FindWnd - Implements the C-compatible function in x86-64 Assembly (ML64, Intel syntax)
; void FindWnd()
;
; C Signature: void FindWnd();
; x64 ABI:
;   - No parameters passed in registers.
;   - No return value (or implicitly returns void).
;   - Non-volatile registers must be preserved.
;   - RSP must be 16-byte aligned before calls.
;   - Needs shadow space for calls (32 bytes).
;
; Compiles with: ml64.exe /c /Fo FindWnd.obj FindWnd.asm
; Links with:    link.exe your_main.obj FindWnd.obj ... (other assembly/obj files) user32.lib vcruntime.lib legacy_stdio_definitions.lib ... (other libraries)
; Requires:      Global variables defined elsewhere, external functions declared.

    .code   ; Code segment starts here

    ; --- External Declarations for functions called by FindWnd ---
    ; extern functionName: Proc
    extern wprintf: Proc         ; From CRT (stdio)
    extern FindWindowW: Proc      ; From User32.dll (WinAPI). In UNICODE, resolves to FindWindowW.
    extern lstrcpyW: Proc       ; From User32.dll (WinAPI)
    extern EnumChildWindows: Proc ; From User32.dll (WinAPI)
    extern EnumChildWindowsProc: Proc ; Assembly function to be called by EnumChildWindows.
    ; --- External Declarations for Global Variables used by FindWnd ---
    ; extern variableName: Size (BYTE, WORD, DWORD, QWORD)
    extern WindowClassName: QWORD ; const wchar_t[] is a pointer (QWORD)
    extern WindowTitle: QWORD    ; const wchar_t[] is a pointer (QWORD)
    extern ChildClassName: QWORD ; wchar_t[] is a pointer (QWORD)
    extern ClassNameToEnum: QWORD ; wchar_t[] array address (QWORD)
    extern EnumHWnd: QWORD       ; HWND is a pointer (QWORD)

    ; Define the format string literal for wprintf in a data segment
    .data ; Data segment
    ; Define the format string for wprintf: L"Try find %s %s\n"
    ; wchar_t string, null-terminated
    Align 8 ; Ensure data is aligned
FindWnd_FormatString LABEL BYTE ; Label for the string data
    DW 'T', 'r', 'y', ' ', 'f', 'i', 'n', 'd', ' ', '%', 's', ' ', '%', 's', 0Dh, 0Ah, 0 ; L"Try find %s %s\r\n"
    DB 0, 0 ; Null terminator for wchar_t


    .code ; Back to code segment

    ; Define the start of the FindWnd procedure (function)
    ; void FindWnd()
FindWnd Proc

    ; --- Function Prologue ---
    push rbp            ; Save caller's RBP
    mov rbp, rsp        ; Set RBP to current RSP

    ; Allocate stack space (48 bytes):
    ;   32 bytes shadow space (x64 ABI requirement before making calls)
    ;   8 bytes for saving non-volatile R14 (used to save TaskmgrHwnd)
    ; Total required = 32 + 8 = 40 bytes.
    ; Round up to nearest multiple of 16: 48 bytes.
    sub rsp, 960         ; Allocate stack space (ensures RSP is 16-byte aligned before internal calls)

    ; Save non-volatile register R14 (used to store TaskmgrHwnd temporarily)
    mov QWORD PTR [rbp - 8], r14 ; Save non-volatile R14 at [rbp-8]

    ; Stack Frame Layout (relative to RBP after prologue and saving R14):
    ; rbp + 8         : Return Address
    ; rbp + 0         : Saved Caller's RBP
    ; rbp - 8         : Saved R14 value <<< R14 is here
    ; rbp - 48        : RSP BEFORE internal calls (ALIGNED)
    ; rbp - 48 to rbp - 80: Shadow space (32 bytes, will be below RSP before a call)


    ; --- Call wprintf(L"Try find %s %s\n", WindowClassName, WindowTitle) ---
    ; Parameter 1 (Format String): Address of FindWnd_FormatString in .data
    lea rcx, FindWnd_FormatString ; Load Effective Address of the format string into RCX
    ; Parameter 2 (%s 1): Address of WindowClassName
    lea rdx, [WindowClassName] ; Get the address (pointer) of WindowClassName into RDX
    ; Parameter 3 (%s 2): Address of WindowTitle
    lea r8, [WindowTitle]    ; Get the address (pointer) of WindowTitle into R8
    ; RSP is already 16-byte aligned (at rbp - 48)
    call wprintf                        ; Call wprintf

    ; --- Call FindWindow(WindowClassName, WindowTitle) ---
    ; Parameter 1 (lpClassName): Address of WindowClassName
    lea rcx, [WindowClassName] ; Get the address of WindowClassName into RCX
    ; Parameter 2 (lpWindowName): Address of WindowTitle
    lea rdx, [WindowTitle]    ; Get the address of WindowTitle into RDX
    ; RSP is already 16-byte aligned
    call FindWindowW                     ; Call FindWindow. Result (HWND) is in RAX.

    ; Check if FindWindow returned NULL (TaskmgrHwnd != NULL)
    cmp rax, 0 ; Compare RAX (TaskmgrHwnd) with NULL (0)
    je  FindWnd_Exit ; If equal (TaskmgrHwnd is NULL), jump to exit

    ; Save the valid TaskmgrHwnd (currently in RAX) into R14 (non-volatile)
    mov r14, rax

    ; --- Check if ChildClassName is empty (ChildClassName[0] == L'\0') ---
    lea rcx, [ChildClassName] ; Get the address of ChildClassName into RCX
    cmp WORD PTR [rcx], 0             ; Check the first wchar_t (WORD) at that address against 0
    je  FindWnd_NoChildClass        ; If equal (first char is null), jump to NoChildClass label

    ; --- Else (ChildClassName is not empty) ---
    ; Call lstrcpyW(ClassNameToEnum, ChildClassName)
    ; Parameter 1 (lpString1): Address of ClassNameToEnum array
    lea rcx, [ClassNameToEnum] ; Get the address of ClassNameToEnum into RCX
    ; Parameter 2 (lpString2): Address of ChildClassName
    lea rdx, [ChildClassName] ; Get the address of ChildClassName into RDX
    ; RSP is already 16-byte aligned
    call lstrcpyW                       ; Call lstrcpyW

    ; Call EnumChildWindows(TaskmgrHwnd, &EnumChildWindowsProc, NULL)
    ; Parameter 1 (hWndParent): TaskmgrHwnd (saved in R14)
    mov rcx, r14                        ; Move TaskmgrHwnd from R14 into RCX
    ; Parameter 2 (lpEnumFunc): Address of EnumChildWindowsProc assembly function
    lea rdx, EnumChildWindowsProc       ; Load Effective Address of EnumChildWindowsProc procedure into RDX
    ; Parameter 3 (lParam): NULL
    mov r8, 0                           ; Move 0 into R8 for lParam
    ; RSP is already 16-byte aligned
    call EnumChildWindows               ; Call EnumChildWindows

    jmp FindWnd_Exit ; Jump to the exit label

FindWnd_NoChildClass:
    ; If ChildClassName is empty, just assign TaskmgrHwnd to EnumHWnd
    mov rax, r14                    ; Get TaskmgrHwnd from R14 into RAX
    mov QWORD PTR [EnumHWnd], rax   ; Store TaskmgrHwnd into the global EnumHWnd

FindWnd_Exit:
    ; --- Function Epilogue ---
    mov r14, QWORD PTR [rbp - 8] ; Restore original R14 value from stack
    add rsp, 960                  ; Deallocate stack space
    pop rbp                      ; Restore caller's RBP
    ret                          ; Return from the procedure

FindWnd EndP ; Define the end of the procedure


; --- Define EnumChildWindowsProc Assembly Here (or in a separate file) ---
; If defining here, ensure it has its own Proc/EndP and externs if needed.
; For now, just a placeholder to make FindWnd compile if EnumChildWindowsProc is defined in the same file.
; EnumChildWindowsProc Proc
;    ; ... assembly code for EnumChildWindowsProc ...
;    ret
; EnumChildWindowsProc EndP


END ; End of the assembly file