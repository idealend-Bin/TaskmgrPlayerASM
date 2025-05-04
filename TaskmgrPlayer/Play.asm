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



; Define NULL constant
NULL EQU 0

; --- Constant Definitions (using EQU) ---
; These define symbols directly representing values
Const_GWL_STYLE EQU -16
Const_GWL_EXSTYLE EQU -20
Const_WS_BORDER EQU 000800000h ; Use h suffix for hex
Const_WS_CAPTION EQU 000C00000h
Const_WS_SYSMENU EQU 000080000h
Const_WS_SIZEBOX EQU 000040000h
Const_EX_TRANSPARENT EQU 000000020h
Const_EX_LAYERED EQU 000080000h
Const_HWND_TOPMOST EQU -1      ; QWORD value
Const_TRUE EQU 1
Const_FALSE EQU 0
Const_STD_OUTPUT_HANDLE EQU -11
Const_WINDOW_AUTOSIZE EQU 1      ; namedWindow flag
Const_SND_FILENAME EQU 000020000h ; Flags for PlaySoundW
Const_SND_ASYNC EQU 000000001h ; Flags for PlaySoundW
; *** CORRECTION: Use OR operator and ensure EQU constants are used ***
Const_PlaySoundFlags EQU Const_SND_FILENAME OR Const_SND_ASYNC ; Combined flags


.data ; Start of the data segment

    ; Hardcoded strings from Play function (db for byte strings)
    Play_WelcomeString db 0Dh, 0Ah, 0Dh, 0Ah, " ------------------Task Manager Player-----------------", 0Dh, 0Ah, 0Dh, 0Ah, 0
    Play_FindWndFailString db "Can't find the window.", 0Dh, 0Ah, 0
    Play_VideoNameString db "BadApple.flv", 0
    Play_NoVideoString db "No video file detected.", 0Dh, 0Ah, 0
    Play_FindVideoString db "Find video %s.", 0Dh, 0Ah, "Splitting audio.", 0Dh, 0Ah, 0
    Play_FfmpegCmdString db "ffmpeg -i BadApple.flv audio.wav -y", 0
    Play_PlayerWndNameString db "innerPlayer", 0
    Play_MainHighGUIClass db "Main HighGUI class", 0 ; Class name for OpenCV's namedWindow
    Play_RmAudioCmdString db "rm audio.wav", 0

    ; Wide string for PlaySoundW (dw for word strings)
    Play_AudioFileNameString dw 'a', 'u', 'd', 'i', 'o', '.', 'w', 'a', 'v', 0, 0 ; Null terminator for wide string is two bytes

; End of the data segment
.code ; Start/continuation of the code segment

; --- External Declarations for functions called by Play ---
; These must be defined as extern before they are called
extern printf: Proc
extern FindWnd: Proc          ; Your assembly/extern "C" function
extern system: Proc          ; CRT function
extern NamedWindow: Proc      ; Your C++ wrapper (extern "C")
extern FindWindowA: Proc      ; WinAPI function (A suffix for ANSI)
extern SetWindowLongPtrW: Proc ; WinAPI function (Use PtrW for x64)
extern GetWindowLongPtrW: Proc ; Use GetWindowLongPtrW for x64
extern SetParent: Proc        ; WinAPI function
extern GetWindowRect: Proc    ; WinAPI function
extern SetWindowPos: Proc     ; WinAPI function
extern InvalidateRect: Proc   ; WinAPI function
extern UpdateWindow: Proc     ; WinAPI function
extern SetConsoleCursorPosition: Proc ; WinAPI function
extern GetStdHandle: Proc     ; WinAPI function
extern PlaySoundW: Proc       ; WinAPI function (requires winmm.lib)
extern clock: Proc            ; CRT function
extern PlayLoop: Proc         ; Your C++ function (extern "C"), contains OpenCV loop

; External global variable
extern EnumHWnd: QWORD ; HWND is a pointer (QWORD on x64)


; RECT structure definition for accessing its fields
; Left, Top, Right, Bottom are LONG (32-bit)
RECT STRUCT
    left    DWORD ?
    top     DWORD ?
    right   DWORD ?
    bottom  DWORD ?
RECT ENDS


Play Proc
    ; LOCAL variables (allocated on stack by MASM)
    ; These MUST appear immediately after PROC
    LOCAL playerWnd: QWORD      ; HWND (8 bytes)
    LOCAL rect_local: RECT      ; RECT (16 bytes)
    LOCAL w: DWORD              ; int (4 bytes)
    LOCAL h: DWORD              ; int (4 bytes)
    LOCAL startTime: QWORD      ; clock_t (8 bytes)
    LOCAL frameCount: DWORD     ; int (4 bytes)
    LOCAL local_videoName[13]: BYTE ; "BadApple.flv" + null terminator (13 bytes)
    LOCAL local_wndName[12]: BYTE ; "innerPlayer" + null terminator (12 bytes)
    ; LOCALs for intermediate results - declared as DWORD
    LOCAL current_style: QWORD  ; To store result from GetWindowLongPtrW
    LOCAL style_mask: DWORD     ; Mask for standard styles
    LOCAL exstyle_flags: DWORD  ; Flags for extended styles


    ; Stack calculation remains the same or similar - adjust if LOCALs change size/count
    ; ... (stack calculation comments) ...
    ; Let's keep 176 for now, seems sufficient.

    ; --- Prologue ---
    push rbp
    mov rbp, rsp
    ; Save Non-Volatile GPR Registers
    push rbx
    push rsi
    push rdi
    push r14

    ; Allocate stack space (using a size like 176, must be multiple of 16)
    sub rsp, 176

    ; --- Initialize Local Strings (copy from .data) ---
    ; Copy "BadApple.flv" to local_videoName
    lea rsi, Play_VideoNameString  ; Source address
    lea rdi, local_videoName       ; Destination address (LOCAL is relative to RBP)
    mov ecx, 13                    ; Number of bytes to copy
    rep movsb                      ; Repeat movsb ECX times

    ; Copy "innerPlayer" to local_wndName
    lea rsi, Play_PlayerWndNameString
    lea rdi, local_wndName
    mov ecx, 12
    rep movsb

    ; --- Initial Output ---
    lea rcx, Play_WelcomeString ; Arg1: Format string
    call printf

    ; --- FindWnd ---
    call FindWnd

    ; --- Check EnumHWnd ---
    mov rax, EnumHWnd ; Load global HWND (QWORD)
    cmp rax, NULL ; Compare with NULL (0)
    je @@FindWndFail ; If EnumHWnd is NULL, jump to fail handler

    ; --- Check videoName[0] ---
    mov al, byte ptr local_videoName ; Load first byte of local string into AL
    cmp al, 0                      ; Compare with 0
    je @@NoVideoDetected ; If it's NULL terminator, jump to no video handler

    ; --- Handle Video Found ---
    lea rcx, Play_FindVideoString ; Arg1: Format string "Find video %s..."
    lea rdx, local_videoName      ; Arg2: %s (videoName string address)
    call printf

    ; Call system("ffmpeg...")
    lea rcx, Play_FfmpegCmdString ; Arg1: Command string address
    call system

    ; --- Setup Player Window ---
    ; Call NamedWindow(wndName, WINDOW_AUTOSIZE)
    lea rcx, local_wndName       ; Arg1: wndName string address
    mov edx, Const_WINDOW_AUTOSIZE ; Arg2: flags (using EQU constant)
    call NamedWindow

    ; Call FindWindowA("Main HighGUI class", wndName)
    lea rcx, Play_MainHighGUIClass ; Arg1: class name string address
    lea rdx, local_wndName       ; Arg2: window name string address
    call FindWindowA             ; Result (HWND) in RAX

    mov playerWnd, rax           ; Store result in local playerWnd (QWORD)

    ; --- Set Window Styles ---
    ; Calculate combined style mask: ~(WS_BORDER | WS_CAPTION | WS_SYSMENU | WS_SIZEBOX)
    mov eax, Const_WS_BORDER     ; Use EQU constant
    or eax, Const_WS_CAPTION     ; Use EQU constant
    or eax, Const_WS_SYSMENU     ; Use EQU constant
    or eax, Const_WS_SIZEBOX     ; Use EQU constant
    not eax                      ; Perform bitwise NOT (32-bit operation)
    mov style_mask, eax          ; Store the resulting mask (LOCAL DWORD)

    ; Call GetWindowLongPtrW(playerWnd, GWL_STYLE) - Use PtrW for 64-bit
    mov rcx, playerWnd           ; Arg1: HWND (QWORD)
    mov edx, Const_GWL_STYLE     ; Arg2: nIndex (using EQU constant)
    call GetWindowLongPtrW       ; Result (LONG_PTR, QWORD) in RAX
    mov current_style, rax       ; Store current style in local QWORD variable

    ; Perform bitwise AND: current_style & style_mask
    ; *** CORRECTION: Load style_mask into register, extend, then AND ***
    mov eax, style_mask          ; Load 32-bit mask into EAX
    movsxd r8, eax                ; Sign-extend mask to R8 (or movzx if zero-extend preferred)
    mov rax, current_style       ; Load current style (QWORD) into RAX
    and rax, r8                  ; Perform bitwise AND. RAX now holds the new style (LONG_PTR)

    ; Call SetWindowLongPtrW(playerWnd, GWL_STYLE, new_style) - Use PtrW for 64-bit
    mov rcx, playerWnd           ; Arg1: HWND (QWORD)
    mov edx, Const_GWL_STYLE     ; Arg2: nIndex (using EQU constant)
    mov r8, rax                  ; Arg3: dwNewLong (new_style, LONG_PTR in RAX)
    call SetWindowLongPtrW

    ; --- Set Extended Styles ---
    ; Calculate combined extended style flags: WS_EX_TRANSPARENT | WS_EX_LAYERED
    mov eax, Const_EX_TRANSPARENT ; Use EQU constant
    or eax, Const_EX_LAYERED    ; Use EQU constant
    mov exstyle_flags, eax      ; Store flags in local DWORD

    ; Call SetWindowLongPtrW(playerWnd, GWL_EXSTYLE, combined_flags) - Use PtrW for 64-bit
    mov rcx, playerWnd           ; Arg1: HWND (QWORD)
    mov edx, Const_GWL_EXSTYLE   ; Arg2: nIndex (using EQU constant)
    ; *** CORRECTION: Load flags from local, zero-extend to QWORD (R8) for Arg3 ***
    mov eax, exstyle_flags       ; Load flags from local DWORD
    movsxd r8, eax                ; Zero-extend EAX to R8 (QWORD) for LONG_PTR argument
    call SetWindowLongPtrW

    ; --- Set Parent ---
    ; Call SetParent(playerWnd, EnumHWnd)
    mov rcx, playerWnd           ; Arg1: hWndChild (QWORD)
    mov rdx, EnumHWnd            ; Arg2: hWndNewParent (QWORD)
    call SetParent               ; Result (HWND) in RAX (ignored)

    ; --- Get Window Rect ---
    ; Call GetWindowRect(EnumHWnd, &rect)
    mov rcx, EnumHWnd            ; Arg1: HWND (QWORD)
    lea rdx, rect_local          ; Arg2: LPRECT (address of local rect)
    call GetWindowRect           ; Result (BOOL) in EAX (ignored)

    ; --- Calculate w and h ---
    ; Access rect fields from local rect_local (RECT is 16 bytes, fields are DWORD)
    mov eax, rect_local.right    ; Load rect.right (DWORD)
    sub eax, rect_local.left     ; Subtract rect.left (DWORD)
    mov w, eax                   ; Store result in local w (DWORD)

    mov eax, rect_local.bottom   ; Load rect.bottom (DWORD)
    sub eax, rect_local.top      ; Subtract rect.top (DWORD)
    mov h, eax                   ; Store result in local h (DWORD)

    ; --- Set Window Position/Size ---
    ; Call SetWindowPos(playerWnd, HWND_TOPMOST, 0, 0, w, h, SWP_SHOWWINDOW) ; Use SWP_SHOWWINDOW? Check flags. Assuming TRUE=1 means SWP_NOMOVE | SWP_NOSIZE? No, SetWindowPos flags are different. Let's assume TRUE meant SWP_SHOWWINDOW (0x40) or maybe just pass 1 if that worked before. Let's stick to TRUE=1 for now.
    ; Args: RCX=hWnd, RDX=hWndInsertAfter, R8D=X, R9D=Y, StackArg1=cx, StackArg2=cy, StackArg3=uFlags
    mov rcx, playerWnd           ; Arg1: hWnd (QWORD)
    mov rdx, Const_HWND_TOPMOST  ; Arg2: hWndInsertAfter (using EQU constant)
    mov r8d, 0                   ; Arg3: X (DWORD 0)
    mov r9d, 0                   ; Arg4: Y (DWORD 0)
    ; Stack Arg1 (cx): w (DWORD)
    ; *** CORRECTION: Load w from local, zero-extend to QWORD (RAX) for stack ***
    mov eax, w                   ; Load local w (DWORD)
    movsxd rax, eax               ; Zero-extend to QWORD
    mov qword ptr [rsp + 20h], rax ; Store w (QWORD) on stack
    ; Stack Arg2 (cy): h (DWORD)
    ; *** CORRECTION: Load h from local, zero-extend to QWORD (RAX) for stack ***
    mov eax, h                   ; Load local h (DWORD)
    movsxd rax, eax               ; Zero-extend to QWORD
    mov qword ptr [rsp + 28h], rax ; Store h (QWORD) on stack
    ; Stack Arg3 (uFlags): TRUE (DWORD 1)
    ; *** CORRECTION: Load TRUE from EQU, extend to QWORD (RAX) for stack ***
    mov eax, Const_TRUE          ; Load TRUE (using EQU constant)
    movsxd rax, eax               ; Zero-extend to QWORD (movsx works too for 1)
    mov qword ptr [rsp + 30h], rax ; Store TRUE (QWORD) on stack

    call SetWindowPos            ; Result (BOOL) in EAX (ignored)

    ; --- Invalidate and Update ---
    ; Call InvalidateRect(EnumHWnd, &rect, TRUE)
    mov rcx, EnumHWnd            ; Arg1: HWND (QWORD)
    lea rdx, rect_local          ; Arg2: LPRECT
    mov r8d, Const_TRUE          ; Arg3: BOOL bErase (using EQU constant)
    call InvalidateRect          ; Result (BOOL) in EAX (ignored)

    ; Call UpdateWindow(EnumHWnd)
    mov rcx, EnumHWnd            ; Arg1: HWND (QWORD)
    call UpdateWindow            ; Result (BOOL) in EAX (ignored)

    ; --- Set Console Cursor Position ---
    ; Call GetStdHandle(STD_OUTPUT_HANDLE)
    mov ecx, Const_STD_OUTPUT_HANDLE ; Arg1: nStdHandle (using EQU constant)
    call GetStdHandle            ; Result (HANDLE, QWORD) in RAX

    ; Call SetConsoleCursorPosition(Handle, {0,0})
    mov rcx, rax                 ; Arg1: Handle (QWORD)
    xor edx, edx                 ; Arg2: COORD {0,0} (X=0, Y=0 packed into DWORD) - Use XOR for efficiency
    call SetConsoleCursorPosition ; Result (BOOL) in EAX (ignored)

    ; --- Play Sound ---
    ; Call PlaySoundW(L"audio.wav", NULL, SND_FILENAME | SND_ASYNC)
    lea rcx, Play_AudioFileNameString ; Arg1: pszSound (Wide string address)
    mov rdx, NULL                ; Arg2: hmod (NULL is 0)
    mov r8d, Const_PlaySoundFlags ; Arg3: fdwSound (using EQU constant)
    call PlaySoundW              ; Result (BOOL) in EAX (ignored)

    ; --- Get Start Time ---
    ; Call clock()
    call clock                   ; Result (clock_t, QWORD) in RAX
    mov startTime, rax           ; Store result in local startTime (QWORD)

    ; --- Initialize frameCount ---
    mov dword ptr frameCount, 0 ; Initialize local frameCount (DWORD) to 0

    ; --- Call PlayLoop ---
    ; Call PlayLoop(videoName, wndName, &frameCount, playerWnd, rect)
    ; Args: RCX=&videoName, RDX=&wndName, R8=&frameCount, R9=playerWnd, StackArg1=rect
    lea rcx, local_videoName     ; Arg1: videoName (address of local string)
    lea rdx, local_wndName       ; Arg2: wndName (address of local string)
    lea r8, frameCount           ; Arg3: &frameCount (address of local int)
    mov r9, playerWnd            ; Arg4: playerWnd (local HWND)
    ; Stack Arg1 (&rect_local): Pass address of local rect_local
    lea rax, rect_local          ; Get address of rect_local relative to RBP
    mov qword ptr [rsp + 20h], rax ; Store address (QWORD) on stack

    call PlayLoop  

    ; --- Shared Cleanup and Epilogue ---
@@CleanupEpilogue:
    ; Cleanup Audio File (only if video was processed and ffmpeg/playsound happened)
    ; Check if playerWnd was successfully created before destroying window/removing audio.
    cmp playerWnd, NULL          ; Compare local playerWnd (QWORD) with NULL (0)
    je @@EpilogueOnly ; If playerWnd is NULL, skip window/audio cleanup

    ; Cleanup Audio File
    lea rcx, Play_RmAudioCmdString ; Arg1: Command string address
    call system ; Returns int (ignored)


@@EpilogueOnly: ; Common exit point for all paths (including FindWndFail, NoVideoDetected)

    ; Deallocate stack space (must match prologue's allocation)
    add rsp, 176

    ; Restore saved GPR registers (order matters, opposite of pushes)
    pop r14
    pop rdi
    pop rsi
    pop rbx
    ; Restore RBP and return
    pop rbp
    ret

; --- Fail Handlers (Jump directly to shared epilogue) ---
@@FindWndFail:
    lea rcx, Play_FindWndFailString ; Arg1: Format string
    call printf
    jmp @@EpilogueOnly ; Jump to shared epilogue (skips cleanup)

@@NoVideoDetected:
    lea rcx, Play_NoVideoString ; Arg1: Format string
    call printf
    jmp @@EpilogueOnly ; Jump to shared epilogue (skips cleanup)


Play EndP

; Ensure the file ends with END directive
END