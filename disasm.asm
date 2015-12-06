.model small
.stack 100h
.data
    helpMessage db "Disassembleris. Nurodykite 1 parametra su com failo pavadinimu.", 10, 13, "Gytis Vinclovas, I kursas II grupe II pogrupis.", "$"
    failedToOpenMessage db "Nepavyko atidaryti failo.$"
    failedToCreateMessage db "Nepavyko sukurti failo.$"
    failedToCloseMessage db "Nepavyko uzdaryti failo.$"
    failedToWriteMessage db "Nepavyko rasyti i faila.$"
    failedToReadMessage db "Nepavyko perskaityti is failo.$"

    ;variables for params
    params db 255 dup(0)
    paramCount db 0

    ;variables for file name
    resultFileName db 255 dup(0)
    resultFileExtension db "txt"

    ;variables for file reading and writing
    readHandler dw ?
    writeHandler dw ?

    codeOffsetBuffer db 4 dup(0), ":", 09h ; 0000: tab
    commandsBuffer db 18 dup (20h), 09h ; 00 00 00 00 00 00 tab
    commandTextBuffer db 15 dup (0), 09h
    commandParametersBuffer db 20 dup (0), 10 ;buffer for command
    offsetInCommandParametersBuffer dw 0

    writeBufferSize db 62

    readBufferSize db 20
    readBuffer db 20 dup(0)
    amountToRead db 20 ;how much should be read

    actualBufferSize db ?
    bytesLeftInBuffer db 0 ;after moving bytes from buffer back to beggining, how many bytes are in buffer
    bufferLocation db 0 ;offset used to find out at which byte we are currently checking
    fileEnd db 0 ;have we reached file end

    maximumByteCount db 6 ;maximum amount of bytes needed for command
    codeBytes dw ? ;variable to easily reach next maximumByteCount bytes
    codeFakeOffset dw 0100h

    bytesUsed db 0

    intCom db "INT "
    intComL db 4

    loopCom db "LOOP"
    loopComL db 4

    uCom db "Neatpazinta"
    uComL db 11

    jcxzCom db "JCXZ"
    jcxzComL db 4

    conJmpCom db "JO  ", "JNO ", "JNAE", "JAE ", "JE  ", "JNE ", "JBE ", "JA  ", "JS  ", "JNS ", "JP  ", "JNP ", "JL  ", "JGE ", "JLE ", "JG  "

    jmpCom db "JMP "
    jmpComL db 4


.code
main:
    mov ax, @data
    mov ds, ax

    call checkAnyParametersGiven
    call checkParameterIsHelp

    call moveParamsToDataSegment

    call openFile

    call createResultFileName
    call createFile

    call handleFile

    call closeFiles
    call endProgram

;-------------------------------------------------------------------------------
;-------------------------------P R O C E D U R E S-----------------------------
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;-------------------------------FOR RECOGNISING CODE----------------------------
;-------------------------------------------------------------------------------

;moves code offset number to writing buffer
;USES: bx, dx, al, di
moveCodeOffsetToBuffer proc
    lea di, codeOffsetBuffer

    mov bx, codeFakeOffset

    mov dl, bh
    call byteToAscii

    mov ds:[di], dx

    mov dl, bl
    call byteToAscii

    add di, 2

    mov ds:[di], dx

    ret
endp moveCodeOffsetToBuffer


;-------------------------------------------------------------------------------
;---------------------------------------MISC------------------------------------
;-------------------------------------------------------------------------------

moveByteToBuffer proc
    mov dx, ds:[si]
    call byteToAscii
    mov ds:[di], dx
    add di, 2
    mov dl, ' '
    mov ds:[di], dl ; ' '
    add di, 1

    ret
endp moveByteToBuffer

;-------------------------------------------------------------------------------

moveCommandBytesToBuffer proc
    mov si, codeBytes
    lea di, commandsBuffer
    print:
        call moveByteToBuffer
        inc si
    loop print

    ret
endp moveCommandBytesToBuffer

;-------------------------------------------------------------------------------

moveCommandNameToBuffer proc
    lea di, commandTextBuffer
    call copyBetweenVariables
    ret
endp moveCommandNameToBuffer
;-------------------------------------------------------------------------------
moveWordOffsetToBuffer proc
    mov di, offsetInCommandParametersBuffer

    inc bx
    add bx, codeBytes

    mov byte ptr [di], 30h
    inc di
    ;mov lower byte

    mov dx, [bx]
    call byteToAscii
    mov [di], dx
    add di, 2

    dec bx
    mov dx, [bx]
    call byteToAscii
    mov [di], dx
    add di, 2

    mov byte ptr[di], "h"
    inc di

    mov offsetInCommandParametersBuffer, di

    ret
endp moveWordOffsetToBuffer

;-------------------------------------------------------------------------------
moveWholeAddressToBuffer proc
    call moveWordOffsetToBuffer

    add bx, 2

    ret

endp moveWholeAddressToBuffer
;-------------------------------------------------------------------------------
moveOffsetToBuffer proc
    mov di, offsetInCommandParametersBuffer
    add bx, codeBytes

    mov dx, [bx]
    call byteToAscii

    mov byte ptr [di], 30h
    inc di
    mov [di], dx
    add di, 2
    mov byte ptr [di], "h"
    inc di

    mov [offsetInCommandParametersBuffer], di
    ret
endp moveOffsetToBuffer
;-------------------------------------------------------------------------------
;Checks all commands in 0111 **** range
checkConditionalJumps proc
    xor ax, ax
    mov al, dl
    and al, 00001111b
    mov bl, 4
    mul bl

    lea si, conJmpCom
    add si, ax

    mov cl, 4
    call moveCommandNameToBuffer

    mov bx, 1
    call moveOffsetToBuffer

    mov cl, 2
    ret
endp checkConditionalJumps
;-------------------------------------------------------------------------------

afterCheck proc
    ;mve code offset, write to file and return how much bytes used
    mov ax, codeFakeOffset
    add al, cl
    mov [codeFakeOffset], ax
    mov [bytesUsed], cl

    call moveCommandBytesToBuffer

    call writeToFile

    ret
endp afterCheck

checkCommand proc

    call moveCodeOffsetToBuffer

    lea di, commandParametersBuffer

    mov [offsetInCommandParametersBuffer], di

    xor cx, cx
    mov bx, codeBytes
    mov dl, [bx]

comJump:
    cmp dl, 11101001b
    jne comJumpOutDir

    lea si, jmpCom
    mov cl, jmpComL
    call moveCommandNameToBuffer

    mov bx, 1
    call moveWordOffsetToBuffer
    mov cl, 3
    call afterCheck
    ret
comJumpOutDir:
    cmp dl, 11101010b
    jne comJumpInRel

    lea si, jmpCom
    mov cl, jmpComL
    call moveCommandNameToBuffer

    call moveWholeAddressToBuffer
    mov cl, 5
    call afterCheck
    ret

comJumpInRel:

comJCXZ:
    cmp dl, 11100011b
    jne comCondJumps

    lea si, jcxzCom
    mov cl, jcxzComL
    call moveCommandNameToBuffer

    mov bx, 1
    call moveOffsetToBuffer

    mov cl, 2
    call afterCheck
    ret

comCondJumps:
    mov al, dl
    and al, 11110000b

    cmp al, 01110000b
    jne comInt

    call checkConditionalJumps
    call afterCheck
    ret

comInt:
    cmp dl, 11001101b
    jne comLoop

    lea si, intCom
    mov cl, intComL
    call moveCommandNameToBuffer

    mov bx, 1
    call moveOffsetToBuffer

    mov cl, 2
    call afterCheck
    ret

comLoop:
    cmp dl, 11100010b
    jne unidentified

    lea si, loopCom
    mov cl, loopComL
    call moveCommandNameToBuffer

    mov bx, 1
    call moveOffsetToBuffer

    mov cl, 2
    call afterCheck
    ret

unidentified:
    lea si, uCom
    mov cl, uComL
    call moveCommandNameToBuffer
    mov cl, 1
    call afterCheck
    ret

endp checkCommand

;-------------------------------------------------------------------------------

;converts number (between 0 and 0Fh )  at al to its ascii representation
; USES AL
hexToAscii proc

    cmp al, 0ah
    jl toAscii

    add al, 07h ;Difference between number and letter

toAscii:

    add al, 30h
    ret
endp hexToAscii

;-------------------------------------------------------------------------------

;converts number (between 0 and 0FFh) to its ascii representation
;USES DL, AL
byteToAscii proc
    mov dh, dl

    ;get left byte of number
    shr dl, 4
    mov al, dl
    call hexToAscii
    mov dl, al

    ;get right byte of number
    shl dh, 4
    shr dh, 4

    mov al, dh
    call hexToAscii
    mov dh, al

ret
endp byteToAscii

;-------------------------------------------------------------------------------

;prints message from ds:[dx] terminated by $
;USES AH
printMessage proc
    mov ah, 09h
    int 21h

    ret
endp printMessage

;-------------------------------------------------------------------------------
;Simply exits program
endProgram proc
    mov ax, 4c00h
    int 21h
    ret
endp endProgram

;-------------------------------------------------------------------------------

;Moves cx amount of info between ds:si to ds:ds
;USES DL, DI, SI, CX,
copyBetweenVariables proc
copyBetweenVariablesLoop:
    mov dl, ds:[si]
    mov ds:[di], dl
    inc di
    inc si
    loop copyBetweenVariablesLoop
    ret
endp copyBetweenVariables

;-------------------------------------------------------------------------------
clearBuffer proc
clearNextByte:
    mov [di], al
    inc di
    loop clearNextByte
    ret
endp clearBuffer

;-------------------------------------------------------------------------------
;-------------------------------PROCEDURES FOR FILES----------------------------
;-------------------------------------------------------------------------------

handleFile proc
    ;save bytes location to buffer beggining at first
    lea ax, readBuffer
    mov [codeBytes], ax

getNextBuffer:

    call readFromFile

    mov bl, bytesLeftInBuffer
    add bl, al

    mov [actualBufferSize], bl

    cmp al, amountToRead
    je checkCanCalculate

    mov [fileEnd], 1

checkCanCalculate:

    ;if there is enough bytes left in buffer to use, try to calculate
    xor ax, ax
    mov al, bufferLocation
    add al, maximumByteCount
    cmp al, actualBufferSize

    jg readBufferEnded

    ;Call command checking here
    call checkCommand
    mov al, bytesUsed

    xor bx, bx
    mov bl, bufferLocation
    add bl, al
    mov [bufferLocation], bl

    mov bx, codeBytes
    add bl, al
    mov [codeBytes], bx

    jmp checkCanCalculate
readBufferEnded:

;if (!fileEnd) {
    ;check if not file end.
    cmp fileEnd, 0
    jne finishLeftBytes

    ;likusiuBaituKiekis = bufferioDydis - codeBufferOffset;
    xor ax, ax
    xor bx, bx

    mov al, readBufferSize
    mov bl, bufferLocation
    sub al, bl
    mov [bytesLeftInBuffer], al

    mov bl, readBufferSize
    sub bl, al
    mov [amountToRead], bl

    ;copy whats lefts in buffer to beggining of it
    xor cx, cx
    mov cl, al
    mov si, codeBytes
    lea di, readBuffer
    call copyBetweenVariables

    mov [bufferLocation], 0
    lea bx, readBuffer
    mov [codeBytes], bx

    jmp getNextBuffer
;} else {
finishLeftBytes:

    mov al, bufferLocation
    mov bl, actualBufferSize

    cmp al, bl
    jge fileEnded

    ;Call command checking here
    call checkCommand
    mov al, bytesUsed

    xor bx, bx
    mov bl, bufferLocation
    add bl, al
    mov [bufferLocation], bl

    mov bx, codeBytes
    add bl, al
    mov [codeBytes], bx

    jmp finishLeftBytes

fileEnded:
    ret
endp handleFile

;-------------------------------------------------------------------------------

;READS FROM file
;USES AH, BX, DX, CX
readFromFile proc
    mov ah, 3fh

    mov bx, readHandler

    lea dx, readBuffer
    add dl, bytesLeftInBuffer

    xor cx, cx
    mov cl, amountToRead

    int 21h

    jnc readSuccesfully

    lea dx, failedToReadMessage
    call printMessage

readSuccesfully:

    ret
endp readFromFile

;-------------------------------------------------------------------------------

;Writes text from write buffer to file
;USES BX, DX, CX, AH
writeToFile proc
    mov bx, writeHandler
    lea dx, codeOffsetBuffer
    xor cx, cx
    mov cl, writeBufferSize
    mov ah, 40h
    int 21h

    jnc wroteSuccesfully

    lea dx, failedToCloseMessage
    call printMessage

wroteSuccesfully:

    ;clear the buffers
    mov al, 0
    mov cl, 4
    lea di, codeOffsetBuffer
    call clearBuffer
    mov al, 20h
    mov cl, 18
    lea di, commandsBuffer
    call clearBuffer
    mov al, 0
    mov cl, 15
    lea di, commandTextBuffer
    call clearBuffer
    mov cl, 20
    lea di, commandParametersBuffer
    call clearBuffer

    ret
endp writeToFile

;-------------------------------------------------------------------------------

;Finds file name from given source name (for instance ./program.com will become ./program.txt)
;USES CX, DI, SI
createResultFileName proc

    xor cx, cx
    mov cl, paramCount
    sub cl, 3

    ;moves file name without extension (i.e. program.)
    lea di, resultFileName
    lea si, params

    call copyBetweenVariables

    ;moves txt extension (program.txt)
    mov cl, 3
    lea si, resultFileExtension
    call copyBetweenVariables

endp createResultFileName

;-------------------------------------------------------------------------------

;creates file with name given at dx
createFile proc
    lea dx, resultFileName

    mov cx, 0
    mov al, 00h
    mov ah, 3ch
    int 21h

    jnc createdFileSuccesfully

    lea dx, failedToCreateMessage
    call printMessage
    call endProgram

createdFileSuccesfully:
    mov [writeHandler], ax

    ret
endp createFile

;-------------------------------------------------------------------------------
;opens file with name at dx
;USES AX
openFile proc
    lea dx, params
    mov al, 00h
    mov ah, 3dh
    int 21h

    jnc openedSuccesfully

    lea dx, failedToOpenMessage
    call printMessage
    call endProgram

openedSuccesfully:

    mov [readHandler], ax

    ret
endp openFile

;-------------------------------------------------------------------------------


;closes the file with handler at bx, displays message if something is bad
closeFile proc
    mov ah, 3eh
    int 21h

    jnc closedSuccesfully

    lea dx, failedToCloseMessage
    call printMessage

closedSuccesfully:
    ret
endp closeFile

;-------------------------------------------------------------------------------

;closes both code and result files
closeFiles proc
    xor bx, bx
    mov bx, readHandler
    call closeFile
    mov bx, writeHandler
    call closeFile
    ret
endp closeFiles

;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
;---------------------PROCEDURES FOR PARAMETERS HANDLING------------------------
;-------------------------------------------------------------------------------

;moves params from es to ds.
moveParamsToDataSegment proc
    ;load params offset
    mov si, 0082h
    lea di, params

    xor cx, cx
    mov cl, [paramCount]
copyParam:

    mov dl, es:[si]
    mov ds:[di], dl
    inc si
    inc di

    loop copyParam

    ret
endp moveParamsToDataSegment

;-------------------------------------------------------------------------------

;Checks if at least a simbol is given for parameters.
;Return count in cx
checkAnyParametersGiven proc

    mov ch, 0
    mov cl, es:[80h]

    cmp cx, 1

    jl noParametersGiven

    dec cx ; Skips first parameter symbol (empty space)
    mov [paramCount], cl ;saves params count

    ret

noParametersGiven:
    lea dx, helpMessage
    call printMessage

    call endProgram

endp checkAnyParametersGiven

;-------------------------------------------------------------------------------

checkParameterIsHelp proc

    mov bx, 0082h

    cmp es:[bx], '?/'

    jne notHelpParameter

    lea dx, helpMessage
    call printMessage
    call endProgram

notHelpParameter:

    ret
endp checkParameterIsHelp

end main
