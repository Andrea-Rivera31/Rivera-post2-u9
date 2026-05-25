# Laboratorio: Rutina de Servicio de Interrupción (ISR) Personalizada para IRQ1 (Teclado)

Este repositorio contiene la implementación práctica de soluciones en ensamblador x86 (arquitectura de 16 bits en modo real) para la manipulación avanzada de la Entrada y Salida (E/S) mediante la interceptación de la línea de hardware **IRQ1** (teclado), la programación del **PIC 8259A** y el encadenamiento de interrupciones (*Interrupt Chaining*).

## Información del Estudiante
* **Nombre:** Andrea Valentina Rivera Fernández
* **Código:** 1152444
* **Institución:** Universidad Francisco de Paula Santander (UFPS)
* **Carrera:** Ingeniería de Sistemas
* **Materia:** Arquitectura de Computadores
* **Unidad:** 9 - Post-Contenido 2
* **Entorno de Desarrollo:** macOS (Host) -> DOSBox 0.74+ con NASM 2.x (Emulado)
* **Año:** 2026
---

## Prerrequisitos y Configuración en macOS

Para compilar y ejecutar estos programas en un entorno Mac, se configuró un directorio de trabajo local enlazado al ciclo de ejecución de DOSBox.

1. **Directorio de trabajo:** El directorio asignado dentro del entorno DOSBox es `C:\U9P2\`. En el sistema host macOS, se mapea mediante:
   ```bash
   mkdir -p ~/dosbox/U9P2

```

2. **Montaje en DOSBox:**
```plaintext
mount c ~/dosbox/U9P2
c:
cd U9P2

```



*Nota sobre el teclado en Mac:* Dado que macOS intercepta de forma nativa combinaciones de teclas como `F1-F12` o `Cmd`, se utiliza la utilidad del mapeador de teclado integrada en DOSBox (`Ctrl + F1`) para corregir o remapear cualquier conflicto de entrada de hardware durante los estados críticos de interceptación.

---

## Conceptos Fundamentales

* **PIC 8259A (Controlador Programable de Interrupciones):** Microchip encargado de gestionar las interrupciones de hardware del sistema. En modo real, traduce la línea física **IRQ1 (Teclado)** al vector de software **INT 09h (0x09)**.


* **IMR (Interrupt Mask Register - Puerto 21h):** Registro del PIC maestro donde cada bit representa una línea IRQ. Un bit en `1` enmascara (deshabilita) la interrupción, y un bit en `0` la habilita. Para el teclado (`IRQ1`), el bit afectado es el **Bit 1**.


* **EOI (End Of Interrupt - Puerto 20h):** Comando que se debe enviar de manera obligatoria al registro de control del PIC (`20h`) al finalizar una ISR personalizada. Fija el fin de la atención para que el PIC vuelva a procesar interrupciones prioritarias pendientes.


* **Buffer del Controlador de Teclado (Puerto 60h):** Puerto de E/S donde se almacena el *scancode* de la tecla pulsada. Si la ISR no lee este puerto, el búfer de hardware permanece lleno y el teclado se bloquea.



---

## Descripción de los Programas Implementados

### 1. `ISR_KB.ASM` (Reemplazo Total del Handler)

* **Propósito:** Captura el vector original de la `INT 09h` y lo sustituye por una rutina propia orientada al conteo de pulsaciones.


* **Mecanismo:** 1. Utiliza la función `AH = 35h` de la `INT 21h` para obtener el segmento y offset del manejador original y lo guarda en la variable de memoria de 4 bytes `old_isr`.
2. Modifica el vector mediante la función `AH = 25h` apuntando a `mi_isr`.
3. Al oprimir una tecla, la rutina lee el puerto `60h` (scancode), incrementa un contador y envía el código de señalización `EOI` (`20h`) al puerto `20h` del PIC.
4. Tras acumular exactamente 5 pulsaciones (`MAX_KEYS`), deshabilita interrupciones con `CLI`, restaura el vector original con `LDS DX, [old_isr]` e `INT 21h / AH=25h`, y finaliza regresando el control a DOS.



### 2. `MASK_KB.ASM` (Enmascaramiento por IMR)

* **Propósito:** Demuestra el bloqueo selectivo de interrupciones a nivel de hardware interactuando con el registro IMR del PIC 8259A.


* **Mecanismo:**
1. Lee el estado actual del IMR desde el puerto `21h` e introduce el byte en la pila.


2. Aplica una operación lógica `OR AL, 02h` para encender el bit 1 (enmascarando la `IRQ1`) y lo escribe de vuelta al puerto `21h`.


3. Ejecuta un bucle de retardo de aproximadamente 3 segundos (55 ticks de reloj) consultando el temporizador del sistema mediante la `INT 1Ah` (`AH = 00h`). Durante este lapso, presionar teclas no genera eventos en pantalla.


4. Extrae de la pila la máscara original y la escribe en el puerto `21h` restaurando el funcionamiento normal del teclado.





### 3. `ISR_CHAIN.ASM` (Encadenamiento de Interrupciones)

* **Propósito:** Registra eventos de teclado de manera pasiva (conteo interno) sin adueñarse por completo del flujo de hardware ni romper la interacción estándar con el sistema operativo.


* **Mecanismo:** * En lugar de procesar el scancode y despachar el EOI manualmente al PIC, la rutina incrementa un contador local.


* Antes del retorno de interrupción, simula un llamado clásico a una `INT` empujando el registro de banderas a la pila (`PUSHF`) y realizando un salto lejano indexado (`CALL FAR [old_isr]`) hacia el manejador por defecto de DOSBox. Esto permite mantener el eco normal en consola mientras corre el contador.





---

## Compilación y Ejecución en DOSBox

Para compilar y testear los binarios ejecutables `.COM` ejecutamos las siguientes secuencias en la consola:

### Paso 1: Compilar y verificar el Reemplazo de Handler (`ISR_KB`)

```plaintext
nasm -f bin ISR_KB.ASM -o ISR_KB.COM
ISR_KB

```

* **Verificación (Checkpoint 1):** Al pulsar teclas se imprime secuencialmente *"Tecla detectada por ISR propio"* exactamente 5 veces. El eco normal de letras se suprime debido a que nuestra rutina consume el carácter. Finaliza restaurando el vector.



### Paso 2: Compilar y verificar el Enmascaramiento (`MASK_KB`)

```plaintext
nasm -f bin MASK_KB.ASM -o MASK_KB.COM
MASK_KB

```

* **Verificación (Checkpoint 2):** Al arrancar el retardo, el teclado de la Mac queda completamente deshabilitado a nivel del PIC maestro. Ninguna tecla genera salida en pantalla durante los 3 segundos. Tras el retardo, se visualiza la reactivación.



### Paso 3: Compilar y verificar el Encadenamiento (`ISR_CHAIN`)

```plaintext
nasm -f bin ISR_CHAIN.ASM -o ISR_CHAIN.COM
ISR_CHAIN

```

* **Verificación (Checkpoint 3):** Las teclas se registran en nuestra rutina, imprimiendo el aviso en la consola, pero el sistema retiene su comportamiento regular (las teclas presionadas se imprimen y ejecutan comandos en DOSBox de forma normal).


