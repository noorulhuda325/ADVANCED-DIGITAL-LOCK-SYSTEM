;--------------------------------------------------
; SEMESTER PROJECT: ADVANCED DIGITAL LOCK SYSTEM
; Features: Centered UI, Box Borders, Port I/O (LED/Buzzer),
;           Password Masking, and Password Modification.
;--------------------------------------------------

.MODEL SMALL
.STACK 100H

.DATA
    PASS        DB '1234'           ; Default PIN
    INPUT       DB 4 DUP(?)         ; User input buffer
    TRY_COUNT   DB 3
    
    ; UI Labels
    HEADER      DB '--- DIGITAL LOCK SYSTEM ---$'
    PROMPT      DB 'ENTER PIN: [    ]$'
    NEW_PROMPT  DB 'NEW PIN:   [    ]$'
    
    ; Status Messages
    MSG_OK      DB 'ACCESS GRANTED$'
    MSG_FAIL    DB 'ACCESS DENIED!$'
    MSG_LOCKED  DB 'SYSTEM HALTED!$'
    MSG_CHOICE  DB 'C: CHANGE  ANY: EXIT$'
    MSG_DONE    DB 'PIN UPDATED!$'
    
.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

RESET_MAIN:
    CALL CLEAR_SCREEN
    CALL DRAW_WINDOW
    MOV TRY_COUNT, 3

START_INPUT:
    ; Position cursor inside the brackets for PIN entry
    MOV DH, 12      ; Row 12
    MOV DL, 44      ; Column 44
    CALL SET_CURSOR

    CALL READ_MASKED_PASS
    CALL COMPARE_PASS
    
    CMP AL, 1
    JE SUCCESS_UI

    ; --- FAILURE LOGIC ---
    DEC TRY_COUNT
    JZ LOCKED_UI

    CALL ACCESS_DENIED      ; Red LED + Buzzer Hardware Call
    
    MOV DH, 15
    MOV DL, 33
    CALL SET_CURSOR
    LEA DX, MSG_FAIL
    MOV AH, 09H
    INT 21H
    
    CALL DELAY
    JMP RESET_MAIN

SUCCESS_UI:
    CALL DOOR_UNLOCK        ; Green LED Hardware Call
    CALL CLEAR_SCREEN
    CALL DRAW_WINDOW
    
    ; Display Success Message
    MOV DH, 15
    MOV DL, 33
    CALL SET_CURSOR
    LEA DX, MSG_OK
    MOV AH, 09H
    INT 21H

    ; Ask for Change Password or Exit
    MOV DH, 17
    MOV DL, 30
    CALL SET_CURSOR
    LEA DX, MSG_CHOICE
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H
    CMP AL, 'C'
    JE CHANGE_UI
    CMP AL, 'c'
    JE CHANGE_UI
    JMP EXIT

CHANGE_UI:
    CALL CLEAR_SCREEN
    CALL DRAW_WINDOW_CHANGE
    
    MOV DH, 12
    MOV DL, 44
    CALL SET_CURSOR
    
    ; Store new PIN directly into PASS buffer
    LEA SI, PASS
    MOV CX, 4
NEW_P_LOOP:
    MOV AH, 08H
    INT 21H
    MOV [SI], AL
    MOV DL, '*'
    MOV AH, 02H
    INT 21H
    INC SI
    LOOP NEW_P_LOOP

    MOV DH, 15
    MOV DL, 33
    CALL SET_CURSOR
    LEA DX, MSG_DONE
    MOV AH, 09H
    INT 21H
    CALL DELAY
    JMP RESET_MAIN

LOCKED_UI:
    CALL SYSTEM_LOCK        ; Final Red LED Hardware Call
    CALL CLEAR_SCREEN
    MOV DH, 12
    MOV DL, 33
    CALL SET_CURSOR
    LEA DX, MSG_LOCKED
    MOV AH, 09H
    INT 21H

EXIT:
    MOV AH, 4CH
    INT 21H
MAIN ENDP

;-----------------------------------------
; HARDWARE PROCEDURES (Port I/O Fix)
;-----------------------------------------
BUZZER PROC
    MOV AL, 182
    OUT 43H, AL
    MOV AX, 1000
    OUT 42H, AL
    MOV AL, AH
    OUT 42H, AL
    IN AL, 61H
    OR AL, 03H
    OUT 61H, AL
    MOV CX, 0FFFFH          
B_DLY: LOOP B_DLY
    IN AL, 61H
    AND AL, 0FCH
    OUT 61H, AL
    RET
BUZZER ENDP

DOOR_UNLOCK PROC
    MOV AL, 00000001B       ; Green LED bit
    MOV DX, 300H            ; Port Fix: Use DX for ports > 255
    OUT DX, AL              
    RET
DOOR_UNLOCK ENDP

ACCESS_DENIED PROC
    MOV AL, 00000110B       ; Red LED bit
    MOV DX, 300H            ; Port Fix: Use DX for ports > 255
    OUT DX, AL
    CALL BUZZER
    RET
ACCESS_DENIED ENDP

SYSTEM_LOCK PROC
    MOV AL, 00000010B       ; Red LED Lock
    MOV DX, 300H            ; Port Fix: Use DX for ports > 255
    OUT DX, AL
    RET
SYSTEM_LOCK ENDP

;-----------------------------------------
; UI & DATA PROCEDURES
;-----------------------------------------
DRAW_WINDOW PROC
    ; Top Border
    MOV DH, 10      
    MOV DL, 28      
    CALL SET_CURSOR
    MOV AH, 02H
    MOV DL, 201             ; '+'
    INT 21H
    MOV CX, 24
T_L: MOV DL, 205            ; '-'
    INT 21H
    LOOP T_L
    MOV DL, 187             ; '+'
    INT 21H
    
    ; Header Text
    MOV DH, 11
    MOV DL, 29
    CALL SET_CURSOR
    LEA DX, HEADER
    MOV AH, 09H
    INT 21H

    ; Input Prompt
    MOV DH, 12
    MOV DL, 32
    CALL SET_CURSOR
    LEA DX, PROMPT
    MOV AH, 09H
    INT 21H

    ; Bottom Border
    MOV DH, 13
    MOV DL, 28
    CALL SET_CURSOR
    MOV AH, 02H
    MOV DL, 200             ; '+'
    INT 21H
    MOV CX, 24
B_L: MOV DL, 205            ; '-'
    INT 21H
    LOOP B_L
    MOV DL, 188             ; '+'
    INT 21H
    RET
DRAW_WINDOW ENDP

DRAW_WINDOW_CHANGE PROC
    CALL DRAW_WINDOW        ; Draw frame and header
    MOV DH, 12
    MOV DL, 32
    CALL SET_CURSOR
    LEA DX, NEW_PROMPT      ; Change prompt text inside the box
    MOV AH, 09H
    INT 21H
    RET
DRAW_WINDOW_CHANGE ENDP

READ_MASKED_PASS PROC
    LEA SI, INPUT
    MOV CX, 4
R_L:MOV AH, 08H             ; Input without echo
    INT 21H
    MOV [SI], AL
    MOV DL, '*'             ; Print mask
    MOV AH, 02H
    INT 21H
    INC SI
    LOOP R_L
    RET
READ_MASKED_PASS ENDP

COMPARE_PASS PROC
    LEA SI, PASS
    LEA DI, INPUT
    MOV CX, 4
    CLD
    REPE CMPSB
    JNE M_F
    MOV AL, 1
    RET
M_F:MOV AL, 0
    RET
COMPARE_PASS ENDP

SET_CURSOR PROC
    MOV AH, 02H
    MOV BH, 0
    INT 10H
    RET
SET_CURSOR ENDP

CLEAR_SCREEN PROC
    MOV AH, 06H
    MOV AL, 0
    MOV BH, 17H             ; Color Attribute: Blue Background, White Text
    MOV CX, 0
    MOV DX, 184FH
    INT 10H
    RET
CLEAR_SCREEN ENDP

DELAY PROC
    MOV CX, 0FH
    MOV DX, 4240H
    MOV AH, 86H
    INT 15H
    RET
DELAY ENDP

END MAIN