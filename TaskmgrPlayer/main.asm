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

; Standard MASM directives for x64
.code ; Start of the code segment

; --- Data Segment ---
; Define initialized data variables
.data
	_Locale db "zh_CN.UTF-8", 0 ; String literal for setting locale to Chinese UTF-8
    CmdLine db "pause", 0       ; String literal for the "pause" command for system()

; --- Code Segment ---
; Declare external procedures (functions) used in main
.code ; Ensure we are in the code segment (can be written multiple times)
	extern Play: Proc        ; External procedure (defined in Play.asm) - main application logic
	extern system: Proc      ; External procedure (CRT) - for executing shell commands
	extern setlocale: Proc   ; External procedure (CRT) - for setting locale

; int main(void) - Entry point of the program
main Proc
	; --- Function Prologue ---
	push rbp           ; Save the caller's Base Pointer (RBP)
	mov rbp, rsp       ; Set the current Stack Pointer (RSP) as the new Base Pointer
	sub rsp, 32        ; Allocate stack space for Shadow Space (32 bytes) required by x64 ABI for calls

	; --- Call setlocale(LC_ALL, "zh_CN.UTF-8") ---
	; Parameter 1 (category - LC_ALL): 0
	xor rcx, rcx       ; Set RCX to 0 (LC_ALL)
	; Parameter 2 (locale): Address of _Locale string
	lea rdx, _Locale   ; Load Effective Address of _Locale string into RDX
	call setlocale     ; Call the setlocale function

	; --- Call Play() ---
	; No parameters are passed to Play
	; Shadow space (32 bytes) is already allocated by sub rsp, 32
	call Play          ; Call the main Play function

	; --- Call system("pause") ---
	; Parameter 1 (command): Address of CmdLine string
	lea rcx, CmdLine   ; Load Effective Address of CmdLine string into RCX
	; Shadow space (32 bytes) is already allocated
	call system        ; Call the system function

	; --- Function Epilogue ---
	leave              ; Equivalent to: mov rsp, rbp; pop rbp. Deallocates stack space allocated by sub rsp and restores original RBP.

	; --- Set Return Value ---
	xor rax, rax       ; Set RAX to 0. Conventionally, main returns 0 for success.

	ret                ; Return from the main procedure

main Endp ; Define the end of the main procedure

; End of the entire assembly file
End