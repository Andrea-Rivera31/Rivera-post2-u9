[BITS 16]
[ORG 0x100]

section .data
    contador    dw 0                ; Número de teclas atendidas
    MAX_KEYS    equ 5               ; Límite de pulsaciones
    old_isr     dd 0                ; Almacena SEG:OFF del handler original
    msg_tecla   db 0Dh, 0Ah, "Tecla detectada por ISR propio$", 0Dh, 0Ah
    msg_fin     db 0Dh, 0Ah, "ISR restaurado. Fin del programa.$", 0Dh, 0Ah

section .text
start:
    ; 1. GUARDAR VECTOR ORIGINAL DE INT 09h (AH = 35h)
    mov ax, 3509h
    int 21h
    mov [old_isr], bx       ; Offset devuelto en BX
    mov [old_isr+2], es     ; Segmento devuelto en ES

    ; 2. INSTALAR ISR PROPIO (AH = 25h)
    push ds                 ; Preservar DS actual
    mov ax, cs              ; Asegurar que DS apunte al segmento de código actual
    mov ds, ax
    mov dx, mi_isr          ; DS:DX debe apuntar a nuestra rutina
    mov ax, 2509h
    int 21h
    pop ds                  ; Restaurar DS original
    sti                     ; Asegurar que las interrupciones estén habilitadas

.esperar:
    ; 3. BUCLE ACTIVO HASTA LLEGAR A 5 PULSACIONES
    mov ax, [contador]
    cmp ax, MAX_KEYS
    jl .esperar

    ; 4. RESTAURAR HANDLER ORIGINAL
    cli                     ; Deshabilitar interrupciones durante el cambio crítico
    lds dx, [old_isr]       ; Carga DS:DX directamente desde el puntero DWORD
    mov ax, 2509h
    int 21h
    sti                     ; Rehabilitar interrupciones

    ; Mostrar mensaje de salida
    mov ah, 09h
    mov dx, msg_fin
    int 21h

    ; Terminar programa (Retorno a DOS)
    mov ah, 4Ch
    int 21h

; ----------------------------------------------------
; NUESTRA RUTINA DE SERVICIO DE INTERRUPCIÓN (ISR)
; ----------------------------------------------------
mi_isr:
    push ax
    push dx
    push ds

    mov ax, cs              ; Configurar segmento de datos local para la ISR
    mov ds, ax

    ; Leer y descartar el scancode del buffer del teclado (Puerto 60h)
    ; ¡CRÍTICO! Si no hacemos esto, el controlador de teclado se bloquea.
    in al, 60h

    ; Mostrar mensaje en pantalla
    mov ah, 09h
    mov dx, msg_tecla
    int 21h

    ; Incrementar nuestro contador interno
    inc word [contador]

    ; Enviar EOI (End of Interrupt) al PIC maestro (Puerto 20h)
    mov al, 20h
    out 20h, al

    pop ds
    pop dx
    pop ax
    iret                    ; Retorno de interrupción hardware (restaura FLAGS)