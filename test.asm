.model small
bseg segment
    org 100h
    assume ds:BSeg, cs:BSeg, ss:BSeg
main:

    ;ret/RETF
    ret
    retf
    ret 3h
    retf 12h

    ;mul/DIV
    mul ax
    mul word ptr [di + 1234h]
    div ax
    div byte ptr [di + 1234h]

    ;push/pop
    push es:[bx + si + 1234h]
    pop es:[bx + si + 1234h]
    push cs
    pop ss
    push dx
    pop cx

    ;loop
    a:
    loop a


    ;cond jmps
    jo a
    jno a
    js a
    jg a


    jcxz a
    ;jmps
    jmp a
    jmp [bx+si]
    jmp [bx+2]
    jmp 1234h:[bp + si + 1222h]

    ;movs
    mov ds, ax
    mov ax, ds
    mov ax, cx
    mov cl, [bp + si]
    mov cl, cs:[bp + si + 3143h]
    mov cl, [bp + si + 3]
    mov cl, es:[abc]
    mov cs:[1234h], ax
    mov ds:[1234h], al
    mov ax, cs:[1234h]
    mov al, ds:[1234h]

    mov byte ptr [bx+si+1234h], 66h
    mov [bx+si+1234h], 5566h
    mov cl, 12h
    mov al, 12h
    mov ax, 0032h

    ;ints
    int 3h
    int 0FFh
    ;unidentified
    abc db 12h
bseg ends
end main
