[BITS 16]
[ORG 0x100]

section .data
    contador    dw 0
    MAX_KEYS    equ 5
    old_isr     dd 0
    msg_tecla   db 0Dh, 0Ah, "[Cadena: Tecla registrada por ISR]$", 0Dh, 0Ah
    msg_fin     db 0Dh, 0Ah, "ISR desinstalado. Fin.$", 0Dh, 0Ah

section .text
start:
    ; 1. OBTENER HANDLER ORIGINAL
    mov ax, 3509h
    int 21h
    mov [old_isr], bx
    mov [old_isr+2], es

    ; 2. INSTALAR NUESTRO HANDLER DE ENCADENAMIENTO
    push ds
    mov ax, cs
    mov ds, ax
    mov dx, mi_isr_chain
    mov ax, 2509h
    int 21h
    pop ds
    sti

.esperar:
    mov ax, [contador]
    cmp ax, MAX_KEYS
    jl .esperar

    ; 3. RESTAURAR ANTES DE SALIR
    cli
    lds dx, [old_isr]
    mov ax, 2509h
    int 21h
    sti

    mov ah, 09h
    mov dx, msg_fin
    int 21h

    mov ah, 4Ch
    int 21h

; ----------------------------------------------------
; ISR CON ENCADENAMIENTO (CHAINING)
; ----------------------------------------------------
mi_isr_chain:
    push ax
    push dx
    push ds

    mov ax, cs
    mov ds, ax

    ; Mostrar que capturamos el evento
    mov ah, 09h
    mov dx, msg_tecla
    int 21h

    ; Incrementar contador propio
    inc word [contador]

    pop ds
    pop dx
    pop ax

    ; 4. ENCADENAR CON EL HANDLER ORIGINAL
    ; Simulamos una llamada de interrupción de hardware.
    ; El handler original espera que los FLAGS estén en la pila y terminará con un IRET.
    pushf
    call far [cs:old_isr]   ; Forzar direccionamiento usando el prefijo de segmento CS

    iret