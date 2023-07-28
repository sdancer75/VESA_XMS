;========================================================================
; þ Real32/4GB     Version  1.1    (C)opyright 1995,97   
;
;Programmed By George Papaioannou at June 1997.
;Greece
;
;========================================================================

.386p


;== Data segment =======================================================

DATA   segment para public use16

extrn XMS_Address:Ptr

DATA   ends


;== Program ============================================================

CODE   segment para public use16  ;Program segment
       assume CS:CODE,Ds:Data     ;CS points to the code segment whose
                                  ;contents are unknown to DS, SS & ES

;-------------------- Public Declarations --------------------------
public     INITCode32             ;Allows the TP program to read
                                  ;the address of the assembler handlers
public     Virtual86
public     InitXMS

public     XMS_ReadB
public     XMS_WriteB

public     XMS_ReadW
public     XMS_WriteW

public     XMS_ReadD
public     XMS_WriteD

public     XMS_CopyBitBlt

public     FlatMem

;------------------- Variable Declarations -------------------------
Mem48 db 16,0,0,0,0,0
GDT   db 00h,00h,00h,00h,00h,00h,00h,00h     ;GDT entry 0 (null segment)
      db 0FFh,0FFh,00h,00h,00h,93h,0CFh,00h ;GDT entry 1 (seg 0, limit 4GB)
;         |____|    |___|  |____ |   |______________________________
;           |         |______  | |__Readable,Code or Data segment, |
;         Segment limit Max |  |    Present segment                |
;                           |  Accessed                            |
;                   Segment base 0..15                         Page granular(4GB),32 bit segment
;







;-------------------------------------------------------------------------
;Procedure INITCode32


INITCode32   proc far
           push ds

           mov ax,cs
           mov ds,ax

	   mov eax,seg GDT      ;convert to physical address (Seg*16)+Offset
	   shl eax,4
	   mov bx,offset GDT
	   movzx ebx,bx
	   add eax,ebx
	   mov dword ptr MEM48[2],eax
	   lgdt fword ptr MEM48     ;Load global descriptor table address

           in  al,70h	  ;Disable NMI via CMOS 
	   mov ah,al
	   or  al,80h
	   out 70h,al
           and ah,80h
           mov ch,ah
           in  al,71h   

	   mov bx,08h                  ;Load bx to point to GDT entry 1
	   cli                         ;Disable interrupts

	   mov eax,cr0                 ;Switch to protected mode
	   or eax,1
	   mov cr0,eax

	   jmp PROTECTION_ENABLED      ;Clear executionpipe
PROTECTION_ENABLED:
	   mov gs,bx                   ;Load segment shadow-registers
	   mov fs,bx                   ;with GDT entry 1 (4GB segment limit)
	   mov es,bx
	   mov ds,bx
	   and al,0FEh                 ;Switch back to real-mode without

	   mov cr0,eax                 ;resetting the CPU
	   jmp PROTECTION_DISABLED     ;Clear executionpipe
PROTECTION_DISABLED:

           in  al,70h			;Enable NMI via CMOS
	   and al,7fh
           or  al,ch
           out 70h,al
           in  al,71h

	   sti                         ;Enable interrupts
	   pop ds


ende:      retf

INITCode32  endp


;-----------------------------------------------------------------------
;Function Virtual86 :Boolean
;Returns True if the cpu is already in v86 mode.

Virtual86 Proc far
        mov eax,cr0
	and ax,1
        retf
Virtual86 endp

;-----------------------------------------------------------------------
;Function InitXMS :Boolean
;Returns False if everything went just fine !!!.

InitXMS Proc far

        push  ds

        mov ax,Data
        mov ds,ax

	mov ax,4300h
	int 2Fh

	cmp al,80h
	jne Error

	mov ax,4310h
	int 2Fh
	mov ax,es
	shl eax,16
	mov ax,bx
	mov word ptr XMS_Address[0],bx
	mov word ptr XMS_Address[2],es

	mov ah,0
	mov dx,0
	call dword ptr XMS_Address;

	cmp ah,2
	jb Error

        mov ax,0
        jmp Fin

Error:
        mov ax,1

Fin:
        pop  ds
        retf

InitXMS endp

;===================================================================
;====================================
;Read a Byte
;Function XMS_ReadB(Addr,Index:LongInt) :Byte

XMS_ReadB Proc Far
       push  bp
       mov   bp,sp

       xor ax,ax
       mov es,ax
       mov edi,dword ptr [bp+6]
       mov ebx,dword ptr [bp+10]
       mov al,byte ptr es:[ebx+edi]


       pop  bp
       ret  8
XMS_ReadB endp


;====================================================
;Write a Byte
;Procedure XMS_WriteB(Addr,Index:LongInt;Data:Byte);

XMS_WriteB Proc Far
       push  bp
       mov   bp,sp

       xor ax,ax
       mov es,ax
       mov edi,dword ptr [bp+8]
       mov ebx,dword ptr [bp+12]
       mov al,byte ptr [bp+6]
       mov byte ptr es:[ebx+edi],al

       pop  bp

       ret  10
XMS_WriteB endp

;====================================
;Read a Word
;Function XMS_ReadW(Addr,Index:LongInt) :Word

XMS_ReadW Proc Far
       push  bp
       mov   bp,sp

       xor ax,ax
       mov es,ax
       mov edi,dword ptr [bp+6]
       mov ebx,dword ptr [bp+10]
       mov ax,word ptr es:[ebx+edi]

       pop  bp

       ret  8
XMS_ReadW endp


;====================================================
;Write a Word
;Procedure XMS_WriteW(Addr,Index:LongInt;Data:Word);

XMS_WriteW Proc Far
       push  bp
       mov   bp,sp

       xor ax,ax
       mov es,ax
       mov edi,dword ptr [bp+8]
       mov ebx,dword ptr [bp+12]
       mov ax,word ptr [bp+6]
       mov word ptr es:[ebx+edi],ax

       pop  bp

       ret  10
XMS_WriteW endp


;====================================
;Read a Double Word
;Function XMS_ReadD(Addr,Index:LongInt) :LongInt;

XMS_ReadD Proc Far
       push  bp
       mov   bp,sp

       xor ax,ax
       mov es,ax
       mov edi,dword ptr [bp+6]
       mov ebx,dword ptr [bp+10]
       mov ax,word ptr es:[ebx+edi]
       mov dx,word ptr es:[ebx+edi+2]

       pop  bp
       ret  8
XMS_ReadD endp


;====================================================
;Write a Double Word
;Procedure XMS_WriteD(Addr,Index:LongInt;Data:LongInt);

XMS_WriteD Proc Far
       push  bp
       mov   bp,sp

       xor ax,ax
       mov es,ax
       mov edx,dword ptr [bp+6]
       mov edi,dword ptr [bp+10]
       mov ebx,dword ptr [bp+14]
       mov dword ptr es:[ebx+edi],edx

       pop  bp

       ret  12
XMS_WriteD endp

;==========================================================
;Function FlatMem(Segment,Offset :Word) :LongInt;
;Converts a seg:ofs address into a real 32bit physical addr

FlatMem Proc Far
       push bp
       mov  bp,sp
       
       xor edx,edx
       xor eax,eax
       mov ax,word ptr [bp+6]    ;here is the offset
       mov dx,word ptr [bp+8]    ;here is the segment     
       shl edx,4		 ;mul segment by 16
       add edx,eax
       mov ax,dx
       shr edx,16		 ;return dx:ax = 32 bit address     

       pop bp
       ret 4 
FlatMem endp

;===================================================
;Procedure XMS_CopyBitBlt(Source,Dest,Data:LongInt)
;Do a bit block transfer

XMS_CopyBitBlt Proc Far
       push  bp
       mov   bp,sp

       xor   ax,ax
       mov   es,ax

       mov   ecx,dword ptr [bp+6]    ;Bytes to be transfered
       mov   edx,ecx
       mov   edi,dword ptr [bp+10]    ;Destination address
       mov   esi,dword ptr [bp+14]   ;Source Address

       push  ds
       mov   ds,ax

       and   edx,3               ;Check to see if ecx is divisible by four
       jz    Transfer            ;If yes then it's ok
       sub   ecx,edx             ;else force ecx to be divisible by four

Transfer:
       or    ecx,ecx             ;Is ecx zero ?
       jz    Remainer            ;Yes, then transfer the remainer
L1:
       mov   eax,dword ptr ds:[esi]  ;No, start copy process
       mov   es:[edi],eax
       add   esi,4
       add   edi,4
       sub   ecx,4
       jnz   L1   	

Remainer:
       or    edx,edx             ;Is the remainer empty ?
       jz    Finito              ;If yes, exit
       mov   cx,dx               ;Else transfer the remainer bytes
L2:
       mov   al,byte ptr ds:[esi]  ;No, start copy process
       mov   es:[edi],al
       inc   esi
       inc   edi
       dec   cx
       jnz   L2

       

finito:
       pop  ds
       pop  bp

       ret  12
XMS_CopyBitBlt endp




CODE       ends                   ;End of code segment
           end                    ;End of program
