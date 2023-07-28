;{*************************************************************************}
;{VESA LIBRARY Ver 1.00                                                    }
;{                                                                         }
;{Programmed by George Papaioannou Thessaloniki 1997                       }
;{This program is copyrighted under the law of the GR constitution         }
;{                                                                         }
;{It supports Real and Dos4GB mode.                                        }
;{                                                                         }
;{ <The assembly file.>                                                    }
;{*************************************************************************}

.386

;
;----------------------------------------------------------------
;Vesa Info Block
;

TVesaMode struc
   Attr     dw   ?         ;{ Mode Attributes                   }
   WinA     db   ?         ;{ Window A attributes               }
   WinB     db   ?         ;{ Window B attributes               }
   Gran     dw   ?         ;{ Window granularity in K bytes     }
   WinSiz   dw   ?         ;{ Size of window in K bytes         }
   SegA     dw   ?         ;{ Segment address of window A       }
   SegB     dw   ?         ;{ Segment address of window B       }
   WinFunc  dd   ?         ;{ Windows positioning function      }
   Bytes    dw   ?         ;{ Number of bytes per line          }
;  {------------------------------------------------------------}
;  {Extended information for non-VESA supported video modes     }
;  {------------------------------------------------------------}
   PWidth   dw   ?         ;{ Number of horizontal pixels       }
   PHeight  dw   ?         ;{ Number of vertical pixels         }
   CharW    db   ?         ;{ Width of character cell           }
   CharH    db   ?         ;{ Height of character cell          }
   Planes   db   ?         ;{ Number of memory planes           }
   Bits     db   ?         ;{ Number of bits per pixel          }
   nBanks   db   ?         ;{ Number of banks        (not used) }
   MemModel db   ?         ;{ Memory model type                 }
   Banks    db   ?         ;{ Size of bank           (not used) }
   Pages    db   ?         ;{ Number of image pages             }
   Reserved db   ?         ;{ The following are for 15,16,24,32 bit colour modes }
   RedMaskSize   db ?      ;{ Size of Red mask in bits          }
   RedFieldPos   db ?      ;{ Bit position of LSB of Red mask   }
   GreenMaskSize db ?      ;{ Size of Green mask in bits        }
   GreenFieldPos db ?      ;{ Bit position of LSB of Green mask }
   BlueMaskSize  db ?      ;{ Size of Blue mask in bits         }
   BlueFieldPos  db ?      ;{ Bit position of LSB of Blue mask  }
   RsvdMaskSize  db ?      ;{ Size of Reserved mask in bits     }
   RsvdFieldPos  db ?      ;{ Bit pos. of LSB of Reserved mask  }
   DirColModeInf db ?      ;{ Direct Colour mode attributes     }
   Filler        db 255 dup(?)  ;{ Not used - filler            }
TVesaMode ends
;-----------------------------------------------------------------





;----------------------------------------
;------------ data segment --------------
;----------------------------------------
DATA segment para public use16

;--------------------------------------
;---- External Variables --------------
;--------------------------------------

extrn  VesaMode      :TVesaMode
extrn  ActiveBank    :Word

DATA ends

;------------------------------------------
;-------------- code segment --------------
;------------------------------------------
CODE segment para public use16
     assume cs:code,ds:data



;--------------------------------------
;----- Public Procedures --------------
;--------------------------------------
public GetPixel8
public SetPixel8
public CopyMemToVideoBuf8
public CopyVideoBufToMem8
public ClearScreen8

;------------------------------------
;predefined calcs just to speed up
;------------------------------------
BankAddr Label
     Bank0   dd 0
     Bank1   dd 1*10000h
     Bank2   dd 2*10000h
     Bank3   dd 3*10000h
     Bank4   dd 4*10000h
     Bank5   dd 5*10000h
     Bank6   dd 6*10000h
     Bank7   dd 7*10000h
     Bank8   dd 8*10000h
     Bank9   dd 9*10000h
     Bank10  dd 10*10000h
     Bank11  dd 11*10000h
     Bank12  dd 12*10000h

;---------------------------------
;Rest bytes of the banked lines
;just to speed up
v640x480x256  Label
     dw  640-256   ;Screen1
     dw  640-512
     dw  640-128
     dw  640-384
     dw  640-640   ;Screen2
     dw  640-256
     dw  640-512
     dw  640-128
     dw  640-384   ;Screen3
     dw  640-640
     dw  640-256
     dw  640-512


v800x600x256  Label
     dw  800-736
     dw  800-672
     dw  800-608
     dw  800-544
     dw  800-480
     dw  800-416
     dw  800-352

;=====================================================
;Read a Byte
;Function GetPixel8(X,Y :Word) :Byte;

GetPixel8 proc far
    push     bp
    mov      bp,sp

    xor      eax,eax
    xor      edx,edx

    or       ax,word ptr [bp+6]  ;Parameter Y
    jz       ZeroY
    mov      ebx,eax
    shl      eax,8    ;mul Y*256
    shl      ebx,6    ;mul Y*64
    add      eax,ebx  ;add the results
    shl      eax,1    ;320*2
ZeroY:
    movzx    ebx,word ptr [bp+8]
    add      eax,ebx          ;add X offset

    mov      ebx,eax
    shr      eax,16           ;bank in ax=0,1,2,3

    mov      si,ax
    shl      si,2
    mov      ecx,dword ptr [BankAddr+si] ;Banked Offset (y*ScreenX+x) mod FFFF
    sub      ebx,ecx
    mov      si,bx     ;Here is the Real offset


    cmp      ax,ActiveBank
    jz       Exit_0
    mov      ActiveBank,ax

    shl      eax,6           ;mul * 64
    div      VesaMode.Gran   ;WinPos:=Bank*64 Div VesaMode.Gran;

    mov      dx,ax           ;The quotient is in al
    mov      ax,4f05h
    mov      bx,0
    or       VesaMode.WinFunc,0
    jz       interrupt_0
    call     dword ptr VesaMode.Winfunc
    jmp      exit_0
interrupt_0:
    int      10h
Exit_0:
    mov      ax,0a000h
    mov      es,ax
    mov      al,es:[si]

    pop      bp

    ret      4
GetPixel8 endp

;========================================================
;Write a byte
;Procedure SetPixel8(X,Y :Word;Pix:Byte);

SetPixel8 proc far
    push     bp
    mov      bp,sp

    xor      eax,eax
    xor      edx,edx

    or       ax,word ptr [bp+8]  ;Parameter Y
    jz       @@ZeroY
    mov      ebx,eax
    shl      eax,8    ;mul Y*256
    shl      ebx,6    ;mul Y*64
    add      eax,ebx  ;add the results
    shl      eax,1    ;320*2
@@ZeroY:
    movzx    ebx,word ptr [bp+10]
    add      eax,ebx        ;add X offset

    mov      ebx,eax
    shr      eax,16               ;bank in ax=0,1,2,3

    mov      si,ax
    shl      si,2
    mov      ecx,dword ptr [BankAddr+si] ;Banked Offset (y*ScreenX+x) mod FFFF
    sub      ebx,ecx
    mov      si,bx   ;Here Is the Real Offset


    cmp      ax,ActiveBank
    jz       @@Exit_0
    mov      ActiveBank,ax

    shl      eax,6    ;{mul * 64}
    div      VesaMode.Gran   ;{WinPos:=Bank*64 Div VesaMode.Gran;}

    mov      dx,ax                    ;The quotient is in al
    mov      ax,4f05h
    mov      bx,0
    or       VesaMode.WinFunc,0
    jz       @@interrupt_0
    call     dword ptr VesaMode.Winfunc
    jmp      @@exit_0
@@interrupt_0:
    int      10h
@@Exit_0:
    mov      ax,0a000h
    mov      es,ax
    mov      al,byte ptr [bp+6]
    mov      es:[si],al

    pop      bp

    ret      6
SetPixel8 endp


;=================================================================
;Copy a BitBlock from MEM ----> SCREEN
;Procedure CopyMemToVideoBuf(SourceX,SourceY,Width,Height :Word;MemoryLoc :Pointer)
;Copies a rectangular box from Memory to Video Buffer
;

CopyMemToVideoBuf8  proc far

    ;--------------------
    ;Stack frame
    ;--------------------
    Params_Struc   struc
       bp0        dw ?
       ret_addr   dd ?
       MemoryLoc  dd ?
       Height     dw ?
       Wide       dw ?
       SourceY    dw ?
       SourceX    dw ?
    Params_Struc ends

    push     bp
    mov      bp,sp
    jmp      Start_1

    Params      =    [bp-bp0]
    AddValue    dw   ?
    THeight     dw   ?

Start_1:
    mov      ax,Data
    mov      ds,ax

    mov      ax,VesaMode.PWidth
    sub      ax,Params.Wide
    mov      AddValue,ax

    mov      ax,Params.Height
    mov      cs:THeight,ax

    mov      ax,0a000h
    mov      es,ax

    cld
    xor      eax,eax
    xor      edx,edx


    or       ax,Params.SourceY  ;Parameter Y
    jz       @@@ZeroY
    mov      ebx,eax
    shl      eax,8    ;mul Y*256
    shl      ebx,6    ;mul Y*64
    add      eax,ebx  ;add the results
    shl      eax,1    ;320*2
@@@ZeroY:
    add      eax,dword ptr Params.SourceX    ;add X offset
    mov      ebx,eax
    shr      eax,16               ;bank in ax=0,1,2,3

    mov      di,ax
    shl      di,2
    mov      ecx,dword ptr [BankAddr+di] ;Banked Offset (y*ScreenX+x) mod FFFF
    sub      ebx,ecx
    mov      di,bx           ;Here Is the Real Offset
    mov      si,word ptr Params.MemoryLoc[0]

    ;eax=bank
    call     @Change_bank

    ;Check to see if the first line is banked

    mov      ax,Params.Wide
    add      ax,di
    jnc      @Cont1         ;if not banked then jump else go ahead

    mov      bx,0
;========================
;MAIN LOOP
;========================
@Banked_line:
    ; ----   First Bank -----

    xor      edx,edx
    add      edi,ebx      ;bx must be equal with addvalue
    cmp      edi,0ffffh
    ja       @Next_Bank

    mov      cx,0ffffh
    sub      cx,di      ;cx=bytes for the current bank
    inc      cx
    mov      dx,Params.Wide
    sub      dx,cx      ;dx=bytes for the next bank

    push     ds
    mov      ds,word ptr Params.MemoryLoc[2]
    rep      movsb
    pop      ds

@Next_bank:

    mov      cx,dx

    ; ----- Second Bank ------

    movzx    eax,ActiveBank
    inc      ax
    xor      edx,edx
    call     @Change_Bank

    mov      bx,ActiveBank
    dec      bx
    shl      bx,1
    or       cx,0       ;does we have any bytes for the next bank?
    jz       @Check_If_Banked_Line

    xor      edi,edi
    jmp      @Start_Copy

@Check_If_Banked_Line:
    sub      edi,0ffffh
    dec      edi
    cmp      di,word ptr [v640x480x256+bx]
    ja       @No_More_2
    mov      cx,Params.Wide
@Start_Copy:
    push     ds
    mov      ds,word ptr Params.MemoryLoc[2]
    rep      movsb
    pop      ds

@No_more_2:
    xor      edi,edi
    mov      di,word ptr [v640x480x256+bx]    ;adjust offset
    add      di,Params.SourceX
    dec      cs:THeight
@Cont1:
    or      cs:THeight,0
    jz      EndLoop

    movzx    ebx,addvalue
    mov      ax,Params.Wide
    call     @Line_Render

    or      cs:THeight,0
    jz      EndLoop

    jmp     @Banked_line

EndLoop:

    pop      bp

    retf     12
CopyMemToVideoBuf8  endp

;===================================================
;                  CALL ROUTINES
;===================================================

;================================================
;Copy Data without bank breaks
;input ax :num of bytes to be copied  (per line)
;      bx :bytes to be added to reach next line
;return dx := 0 no banked line
;           <>0 banked line and dx=rest bytes before bank change
;
; es:di must point to the first byte to be copied.

@Line_Render:
    push     ds
    mov      ds,word ptr Params.MemoryLoc[2]

    mov      cx,ax
    mov      dx,cx      ;If the rectangular chunk isn't divisible by
                        ;four then first copy the remainder byte per
    and      dx,0003h   ;byte and then copy with dword.
    jz       @Divide4
    sub      cx,dx
    push     cx
    mov      cx,dx
    rep      movsb
    pop      cx
    or       cx,0
    jz       @No_more
@Divide4:
    shr      cx,2       ;div by four
    rep      movsd
@No_more:
    xor      dx,dx
    pop      ds


    cmp      di,0ffffh
    jae      @End_Of_Lines


    mov      dx,0ffffh
    sub      dx,di
    mov      cx,Params.Wide
    add      cx,bx          ;bx=addvalue
    cmp      dx,cx          ;cx=addvalue+Params.Wide
    jb       @End_Of_Lines

    add      di,bx

    dec      cs:THeight
    jz       @End_Of_Lines

    jmp      @Line_Render


@End_Of_Lines:
    ret


;========================================
;Change bank
;input eax :bank number 0,1,2,3....n

@Change_bank:
    cmp      ax,ActiveBank  ;if we are already in this bank just go away
    jz       Exit_3
    mov      ActiveBank,ax

    shl      eax,6           ;mul * 64
    xor      edx,edx
    div      VesaMode.Gran   ;WinPos:=Bank*64 Div VesaMode.Gran

    mov      dx,ax           ;The quotient is in al
    mov      ax,4f05h
    mov      bx,0
    or       VesaMode.WinFunc,0
    jz       @@interrupt_10
    call     dword ptr VesaMode.Winfunc
    jmp      exit_3
@@interrupt_10:
    int      10h
Exit_3:
    ret




;=================================================================
;Copy a BitBlock from SCREEN ---> MEM
;Procedure CopyVideoBufToMem(SourceX,SourceY,Width,Height :Word;MemoryLoc :Pointer)
;Copies a rectangular box from Video Buffer to Memory
;

CopyVideoBufToMem8  proc far

    ;--------------------
    ;Stack frame
    ;--------------------
    Params_Struc   struc
       bp0        dw ?
       ret_addr   dd ?
       MemoryLoc  dd ?
       Height     dw ?
       Wide       dw ?
       SourceY    dw ?
       SourceX    dw ?
    Params_Struc ends

    push     bp
    mov      bp,sp
    jmp      Start_2

    Params      =    [bp-bp0]
    AddValue2    dw   ?
    THeight2     dw   ?

Start_2:
    mov      ax,Data
    mov      ds,ax

    mov      ax,VesaMode.PWidth
    sub      ax,Params.Wide
    mov      AddValue2,ax

    mov      ax,Params.Height
    mov      cs:THeight2,ax

    mov      ax,word ptr Params.MemoryLoc[2]
    mov      es,ax

    cld
    xor      eax,eax
    xor      edx,edx


    or       ax,Params.SourceY  ;Parameter Y
    jz       ZeroY_2
    mov      ebx,eax
    shl      eax,8    ;mul Y*256
    shl      ebx,6    ;mul Y*64
    add      eax,ebx  ;add the results
    shl      eax,1    ;320*2
ZeroY_2:
    add      eax,dword ptr Params.SourceX    ;add X offset
    mov      ebx,eax
    shr      eax,16               ;bank in ax=0,1,2,3

    mov      si,ax
    shl      si,2
    mov      ecx,dword ptr [BankAddr+si] ;Banked Offset (y*ScreenX+x) mod FFFF
    sub      ebx,ecx
    mov      si,bx           ;Here Is the Real Offset
    mov      di,word ptr Params.MemoryLoc[0]

    ;eax=bank
    call     @Change_bank

    ;Check to see if the first line is banked

    mov      ax,Params.Wide
    add      ax,si
    jnc      @Cont2         ;if not banked then jump else go ahead

    mov      bx,0
;========================
;MAIN LOOP
;========================
@Banked_line2:
    ; ----   First Bank -----

    xor      edx,edx
    add      esi,ebx      ;bx must be equal with addvalue
    cmp      esi,0ffffh
    ja       @Next_Bank2

    mov      cx,0ffffh
    sub      cx,si      ;cx=bytes for the current bank
    inc      cx
    mov      dx,Params.Wide
    sub      dx,cx      ;dx=bytes for the next bank

    push     ds
    mov      ax,0a000h
    mov      ds,ax
    rep      movsb
    pop      ds

@Next_bank2:

    mov      cx,dx

    ; ----- Second Bank ------

    movzx    eax,ActiveBank
    inc      ax
    xor      edx,edx
    call     @Change_Bank

    mov      bx,ActiveBank
    dec      bx
    shl      bx,1
    or       cx,0       ;does we have any bytes for the next bank?
    jz       @Check_If_Banked_Line2

    xor      esi,esi
    jmp      @Start_Copy2

@Check_If_Banked_Line2:
    sub      esi,0ffffh
    dec      esi
    cmp      si,word ptr [v640x480x256+bx]
    ja       @No_More_3
    mov      cx,Params.Wide
@Start_Copy2:
    push     ds
    mov      ax,0a000h
    mov      ds,ax
    rep      movsb
    pop      ds

@No_more_3:
    xor      esi,esi
    mov      si,word ptr [v640x480x256+bx]    ;adjust offset
    add      si,Params.SourceX
    dec      cs:THeight2
@Cont2:
    or      cs:THeight2,0
    jz      EndLoop2

    movzx    ebx,addvalue2
    mov      ax,Params.Wide
    call     @Line_Render2

    or      cs:THeight2,0
    jz      EndLoop2

    jmp     @Banked_line2

EndLoop2:

    pop      bp

    retf     12
CopyVideoBufToMem8  endp

;===================================================
;                  CALL ROUTINES
;===================================================

;================================================
;Copy Data without bank breaks
;input ax :num of bytes to be copied  (per line)
;      bx :bytes to be added to reach next line
;return dx := 0 no banked line
;           <>0 banked line and dx=rest bytes before bank change
;
; es:di must point to the first byte to be copied.

@Line_Render2:
    push     ds
    mov      cx,0a000h
    mov      ds,cx

    mov      cx,ax
    mov      dx,cx      ;If the rectangular chunk isn't divisible by
                        ;four then first copy the remainder byte per
    and      dx,0003h   ;byte and then copy with dword.
    jz       @@Divide4
    sub      cx,dx
    push     cx
    mov      cx,dx
    rep      movsb
    pop      cx
    or       cx,0
    jz       @No_more3
@@Divide4:
    shr      cx,2       ;div by four
    rep      movsd
@No_more3:
    xor      dx,dx
    pop      ds


    cmp      si,0ffffh
    jae      @End_Of_Lines2


    mov      dx,0ffffh
    sub      dx,si
    mov      cx,Params.Wide
    add      cx,bx          ;bx=addvalue
    cmp      dx,cx          ;cx=addvalue+Params.Wide
    jb       @End_Of_Lines2

    add      si,bx

    dec      cs:THeight2
    jz       @End_Of_Lines2

    jmp      @Line_Render2


@End_Of_Lines2:
    ret

;===========================================================
;Procedure ClearScreen8(Color :Word)
;Clears the screen with a specified color ! Weird ha ?

ClearScreen8 proc far
    push     bp
    mov      bp,sp

    xor       eax,eax
    call      @Change_bank

    mov       ax,0a000h
    mov       es,ax

    movzx     eax,word ptr [bp+6]  ;Copy to all eax
    mov       ah,al
    mov       bx,ax
    shl       eax,16
    mov       ax,bx

    mov       bx,5
    cld
@In_Loop:
    xor       di,di
    mov       cx,3FFFh
    rep       stosd

    mov       cx,4
    rep       stosb

    push      eax
    push      bx
    mov       ax,ActiveBank
    inc       ax
    call      @Change_Bank
    pop       bx
    pop       eax

    dec       bx
    jnz       @In_Loop

    pop      bp
    ret      2
ClearScreen8 endp


CODE      ends
          end
