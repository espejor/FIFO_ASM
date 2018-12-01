;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Autor:
;Fecha:
;Versión:
;Titulo:
;Descripción:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; PIC16F887 Configuration Bit Settings
; Assembly source line config statements
#include "p16f887.inc"

; CONFIG1
; __config 0x2FF7
 __CONFIG _CONFIG1, _FOSC_EXTRC_CLKOUT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_OFF
; CONFIG2
; __config 0x3FFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

;----------- Constantes

#define setGIE	    bsf INTCON,GIE	    ; Habilitar Interrupciones globales
#define setT0IE	    bsf INTCON,T0IE	    ; Habilitar Interrupción TIMER0
#define clrT0IF	    bcf INTCON,T0IF	    ; INTF - A 0 .

#define	BANK0	        0x00
#define	BANK1	        0x20
#define	BANK2		0x40
#define	BANK3		0x60
 
#define	semiCiclo	0x20
#define	semiC1		0x01
#define	semiC2		0x00
#define	shift		.238
 
#define	dirInicioFIFO	0x2A
#define	dirFinFIFO	0x39	; 16 posiciones
#define	tamFIFO		.16 
 
;---------- Definición de BITs
FRE		EQU	.0	    ;FIFO Read Enabled
FWE		EQU	.1	    ;FIFO Write Enabled
 	

;---------- Variables
fifoReadPtr	EQU	0x21
fifoWritePtr	EQU	0x22
fifoTamPtr	EQU	0x23  
fifoDataPtr     EQU	0X24
fifoSTATUS	EQU	0x25
aux		EQU	0x26



;---------- MACROS
;---------- Copia un literal en un registro
MOVLF	MACRO	literal,reg,banco
	    setBANK	banco
	    MOVLW	literal
	    MOVWF	reg
	    setBANK	BANK0
	ENDM
	
;---------- Copia un registo en otro registro
MOVFF	MACRO	regO,bancoO,regD,bancoD
	    setBANK	bancoO
	    MOVF	regO,W
	    setBANK	BANK0
	    setBANK	bancoD
	    MOVWF	regD
	    setBANK	BANK0
	ENDM

;---------- Cambiar al Banco determinado
setBANK    MACRO    banco
		MOVLW 0x9F
		ANDWF STATUS,F
		MOVLW banco
		IORWF STATUS,F
	    ENDM

;---------- Configurar puerto C como salida
setTRISC    MACRO valor
		MOVLF valor,TRISC,BANK1
	    ENDM
;---------- Configurar el PreEscaler
setPS	MACRO	pie
	    setBANK	BANK1
	    MOVLW	pie
	    IORWF	OPTION_REG,F
	    setBANK	BANK0
	ENDM
;----------- Resetear TIMER0 a un valor
resetTMR0   MACRO   t
		MOVLW	t
		MOVWF	TMR0
	    ENDM
;----------- Configura el TIMER0 como Temporizacor	    
setAsTIMER  MACRO
		setBANK	    BANK1
		bcf	    OPTION_REG, T0CS
		setBANK	    BANK0
	    ENDM
;----------- PSA = 0. Activar Preescaler para TIMER0	    
setPST0	    MACRO
		setBANK	    BANK1
		bcf OPTION_REG, PSA
		setBANK	    BANK0
	    ENDM

	    
;=============== INICIO DEL PROGRAMA ====================================
	    
    ORG 0000h ; El PIC comienza aquí si se enciende o hay un reset.
    GOTO Inicio ; Ve al programa principal.
  
    
 ;--------- Interrupciones
    ORG 0004h ; El PIC vendrá aquí si ocurre una interrupción.
	
    RETFIE ; Fin de la rutina de interrupción.
       
;--------- Este es el comienzo de nuestro programa principal
;--------- Configuración del Interrupciones
Inicio:

    MOVLF   tamFIFO,fifoTamPtr,BANK0	;definir tamaño FIFO
    MOVLF   'a',fifoDataPtr,BANK0	;dato a cargar en FIFO
    MOVLF   dirInicioFIFO,fifoWritePtr,BANK0
    MOVLF   dirInicioFIFO,fifoReadPtr,BANK0
    bsf	    fifoSTATUS,FWE		;FIFO Write Enabled
    bcf	    fifoSTATUS,FRE		;FIFO Read Disabled
    

;--------- escribir la memoria de datos
    call    cargaDatos

    call    fifoPull
    call    fifoPull
    call    fifoPull
    call    fifoPull
    call    fifoPull
    call    fifoPull
    
    call    cargaDatos
    
    goto    fin
;================ Zona de subrutinas ==============
    
cargaDatos:
loop	call    fifoPush
	incf    fifoDataPtr
	btfsc   fifoSTATUS,FWE
	goto    loop   
    return

;------- Escribe el contenido de <dato> en primera dircción libre de la FIFO
fifoPush:
	btfss   fifoSTATUS,FWE	    ;Salta si se puede escribir
    return			    ;Volver si no se puede escribir
	movf    fifoWritePtr,W	    ;Cargar dirección a escribir
	movwf   FSR		    ;en FSR
	movf    fifoDataPtr,W	    ;Cargar dato a escribir en INDF
	movwf   INDF		    ;Escribir dato
	decf	fifoTamPtr,F
	bsf	fifoSTATUS,FRE	    ;Estamos seguros de que se puede leer
	call    testFullFIFO	    ;Comprobar si está llena la FIFO 
	movf	fifoWritePtr,W	    ;Pasamos el valor del puntero como parámetro
	call    updatePointer	    ;Actualizar puntero de escritura
	movwf	fifoWritePtr	    ;Recuperamos la nueva drección del puntero de escritura
    return

testFullFIFO:	;Cuando el tamaño sea 0
	    movf	fifoTamPtr,W	;Restamos la var tamaño a 0
	    sublw	.0
	    btfss	STATUS,Z	;Comprobamos si la resta es cero(0)
	    goto	setWE
	    goto	setWD
setWE	    bsf		fifoSTATUS,FWE	;POnemos Flag de escritura a uno
	return
setWD	    bcf		fifoSTATUS,FWE	;Pnemos Flag de escritura a cero
	return				;Fin subrutina


fifoPull:
	btfss   fifoSTATUS,FRE	;Salta si se puede leer
    return	
	movf    fifoReadPtr,W   ;Cargamos el puntero de lectura en el FSR
	movwf   FSR    
	movf    INDF,W		;Leemos lo que hay en INDF y ...
	movwf   fifoDataPtr	;... lo llevamos al registro de datos
	incf    fifoTamPtr,F	;Incrementamos el tamaño de la FIFO
	bsf	fifoSTATUS,FWE	;Estamos seguros de que se puede escribir
	call	testEmptyFIFO	;Comprobar si la pila está vacía
	movf	fifoReadPtr,W	;Pasamos el valor del puntero como parámetro
	call    updatePointer	;Actualizar puntero de escritura    return
    	movwf	fifoReadPtr	;Recuperamos la nueva drección del puntero de lectura
    return

testEmptyFIFO:	;Cuando el tamaño sea 16
	    movlw	fifoTamPtr	;Restamos la var tamaño a la cte Tamaño
	    sublw	tamFIFO
	    btfss	STATUS,Z	;Comprobamos si la resta es cero(0)
	    goto	setRE
	    goto	setRD
setRE	    bsf	fifoSTATUS,FRE	;POnemos Flag de escritura a uno
	return
setRD	    bcf	fifoSTATUS,FRE	;Pnemos Flag de escritura a cero
	return			;Fin subrutina
	
updatePointer:
	    movwf   aux		    ;En aux está el puntero
	    sublw   dirFinFIFO	    ;Restamos el valor del ptr a la dir fe fin FIFO
	    btfss   STATUS,Z	    ;Comprobamos si la resta es cero(0)
	    goto    incr	    ;Si no es cero incrementamos
	    movlw   dirInicioFIFO   ;Cargamos el valor de la dir inicio de la FIFO
	    movwf   aux		    ;en el puntero 
	    goto    exitU
incr	    incf    aux,W	    ;Incrementar el puntero
exitU	return	
        
    
fin:
    sleep
    
    end
    

    
        


