[BITS 16]
[ORG 0x100]

section .data
    msg_mask    db "IRQ1 enmascarado (teclado deshabilitado)...$", 0Dh, 0Ah
    msg_unmask  db 0Dh, 0Ah, "IRQ1 restaurado.$", 0Dh, 0Ah

section .text
start:
    ; 1. LEER IMR ACTUAL Y GUARDAR EN LA PILA
    in al, 21h
    push ax                 ; Guardar configuración original del PIC

    ; 2. ENMASCARAR IRQ1 (Poner en '1' el Bit 1)
    ; Bit 1 corresponde a IRQ1. Máscara binaria: 00000010b = 02h
    or al, 02h
    out 21h, al

    ; Mostrar mensaje informativo
    mov ah, 09h
    mov dx, msg_mask
    int 21h

    ; 3. ESPERAR ~3 SEGUNDOS USANDO EL TIMER DE LA BIOS
    ; La INT 1Ah / AH=00h lee los ticks del sistema (18.2 ticks por segundo).
    ; 3 segundos * 18.2 = ~55 ticks.
    mov ah, 00h
    int 1Ah                 ; Devuelve ticks actuales en CX:DX
    mov bx, dx              ; Guardar parte baja de los ticks en BX
    add bx, 55              ; Nuestro objetivo final de ticks

.wait:
    mov ah, 00h
    int 1Ah
    cmp dx, bx              ; ¿Ya pasaron los 55 ticks?
    jl .wait                ; Si es menor, seguir esperando en bucle

    ; 4. RESTAURAR IMR ORIGINAL (Quitar la máscara)
    pop ax                  ; Recuperar el valor original de la pila
    out 21h, AL

    ; Mostrar mensaje de éxito
    mov ah, 09h
    mov dx, msg_unmask
    int 21h

    ; Terminar programa
    mov ah, 4Ch
    int 21h