.model small
bseg segment
    org 100h
    assume ds:BSeg, cs:BSeg, ss:BSeg
main:

    a:
    loop a

    jo a
    jno a
    js a
    jg a

    mov byte ptr [bx+si+1234h], 66h
    mov [bx+si+1234h], 5566h

    mov cl, 12h

    mov al, 12h

    mov ax, 0032h

    mov cs:[1234h], ax
    mov ds:[1234h], al
    jcxz a
    int 3h
    int 21h

    jmp a

    jmp [bx+si]
    jmp [bx+2]

    jmp 1234h:[bp + si + 1222h]

    mov ds, ax
    mov ax, ds

    mov ax, cx

    mov cl, [bp + si]

    mov cl, cs:[bp + si + 3143h]

    int 21h

    mov cl, [bp + si + 3]

    int 21h

    mov cl, es:[abc]

    int 21h

    int 0FFh

    abc db 12h
bseg ends
end main
