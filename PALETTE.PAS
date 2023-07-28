UNIT Palette;

INTERFACE

Uses Crt;

Const
     FadeDelay   :Word = 1;

Type
     BasicColors = Record
         Red,
         Green,
         Blue  :Byte;
     End;

     RGBColors   = Array [0..767] Of Byte;
     RGBType     = Array [0..255] of BasicColors;

Var
     CurrentPalette :RGBType;
     StaticVar      :Byte;

Procedure RetraceDelay(RetrNum :Word);
Procedure VerticalRetrace;
Procedure HorizontalRetrace;
Procedure ConvInRawData(InType :RGBType;Var OutType :RGBColors);
Procedure ConvInRGBData(InType :RGBColors;Var OutType :RGBType);
Procedure SetDacColor(Num,R,G,B: Byte);
Procedure ReadDacColor(Num:Byte;Var R,G,B :Byte);
Procedure SetRGBColors(Var Pal :RGBType);
Procedure ReadRGBColors(Var Pal :RGBType);
Function  FadeInOnce(StartDACNumber :Byte): Byte;
Procedure FadeIn;
Procedure FadeInOneColor(DACNum :Byte;Red,Green,Blue :Byte);
Procedure FadeInPalette(Pal :RGBType);
Procedure ZeroRGBPalette;
Function  FadeOutOnce(StartDACNumber :Byte): Byte;
Procedure FadeOut;
Procedure FadeOutOneColor(DACNum :Byte;Red,Green,Blue :Byte);
Procedure FadeOutPalette(Pal :RGBType);
Procedure FadeMax;
Function  LoadPalette( Pathname: string;Var Pal :RGBType) :Integer;


IMPLEMENTATION

Procedure RetraceDelay(RetrNum :Word);assembler;
Asm;
    mov cx,RetrNum
@OutLoop:
    mov ax,0040h
    mov es,ax
    mov dx,es:[0063h]
    add dx,6
    {Horizontal Retrace}
@L02:
    in al,dx
    test al,1
    jz @L02

@L03:
    in al,dx
    test al,1
    jnz @L03

    Loop @OutLoop

End;


Procedure VerticalRetrace;assembler;
Asm;
    push ax
    push dx

    mov dx,3DAh   {Vertival Retrace}
@L02:
    in al,dx
    test al,8
    jz @L02

@L03:
    in al,dx
    test al,8
    jnz @L03

    pop dx
    pop ax
End;


Procedure HorizontalRetrace;assembler;
Asm;
    push ax
    push dx

    mov dx,3DAh   {Horizontal Retrace}
@L02:
    in al,dx
    test al,1
    jz @L02

@L03:
    in al,dx
    test al,1
    jnz @L03

    pop dx
    pop ax
End;


Procedure ConvInRawData(InType :RGBType;Var OutType :RGBColors);
Var
   I,J  :Word;
Begin
    J:=0;
    For I:=0 to 255 do
    Begin
       OutType[J+0]:=InType[I].Red;
       OutType[J+1]:=InType[I].Green;
       OutType[J+2]:=InType[I].Blue;

       J:=J+3;
    End;
End;

Procedure ConvInRGBData(InType :RGBColors;Var OutType :RGBType);
Var
   I,J  :Word;
Begin
    J:=0;
    For I:=0 to 255 do
    Begin
       OutType[I].Red:=InType[J+0];
       OutType[I].Green:=InType[J+1];
       OutType[I].Blue:=InType[J+2];

       J:=J+3;
    End;
End;

Procedure SetDacColor(Num ,R,G,B :Byte);Assembler;
Asm;


    mov dx,3DAh   {Horizontal Retrace}
@L02:
    in al,dx
    test al,1  {wait if we are in the middle of Horiz. interval}
    jz @L02

@L03:
    in al,dx
    test al,1   {wait to finish horizontal retrace and come into interval}
    jnz @L03



    mov dx,03c8h   {prepare for write}
    mov al,Num
    out dx,al      {send the signal}
    inc dx

    mov al,R
    out dx,al         {send R}

    mov al,G
    out dx,al         {send G}

    mov al,B
    out dx,al         {Send B}


End;

Procedure ReadDacColor(Num :Byte;Var R,G,B :Byte);Assembler;
Asm;

    mov dx,3DAh   {Horizontal Retrace}
@L02:
    in al,dx
    test al,1
    jz @L02

@L03:
    in al,dx
    test al,1
    jnz @L03


    mov dx,03c7h   {prepare for write}
    mov al,Num
    out dx,al      {send the signal}
    inc dx         {dx,03c9h send data when ready}
    inc dx

    in  al,dx
    les si,R
    mov es:[si],al {read R}

    in  al,dx
    les si,G
    mov es:[si],al {Read G}

    in  al,dx
    les si,B
    mov es:[si],al {Read B}

End;

Procedure SetRGBColors(Var Pal :RGBType);assembler;
asm;
    call VerticalRetrace

    push ds

    mov dx,03c8h   {prepare for write}
    mov al,0
    out dx,al      {send the signal}
    mov cx,256    {cx = 256 DAC colors}
    mov dx,03c9h   {send data when ready}
    lds bx,Pal

@Lo1:
    mov al,[bx]
    out dx,al         {send R}

    inc bx
    mov al,[bx]
    out dx,al         {send G}

    inc bx
    mov al,[bx]
    out dx,al         {Send B}

    inc bx
    loop @lo1

    pop ds

End;

Procedure ReadRGBColors(Var Pal :RGBType);assembler;
asm;
    call VerticalRetrace

    push ds

    mov dx,03c7h   {prepare for write}
    mov al,0
    out dx,al      {send the signal}
    mov cx,256    {cx = 256 DAC colors}
    mov dx,03c9h   {send data when ready}
    lds bx,Pal

@Lo1:
    in  al,dx
    mov [bx],al {read R}

    inc bx
    in  al,dx
    mov [bx],al {Read G}

    inc bx
    in  al,dx
    mov [bx],al {Read B}

    inc bx
    loop @lo1

    pop ds

End;


{**********************************************************************}
{Function FadeInOnce                                                   }
{Input    :StartDACNumber                                              }
{Output   :0 = Not all Colors are zero , 1=DAC=0                       }
{**********************************************************************}

Function FadeInOnce(StartDACNumber :Byte): Byte;assembler;
Var
    Red,Green,Blue :Byte;
    Flags          :Byte;
asm;
    call VerticalRetrace

    mov cx,256
    xor bx,bx
    mov bl,StartDACNumber
    sub cx,bx
    mov Flags,0
@Lo1:

    and Flags,11110000b

    { Read Section}

    mov dx,3c7h
    mov al,bl
    out dx,al

    mov dx,3c9h  {Data Port}
    in  al,dx
    cmp al,0
    jz @1
    dec al
    or Flags,1
@1: mov red,al

    in  al,dx
    cmp al,0
    jz @2
    dec al
    or Flags,2
@2: mov green,al

    in  al,dx
    cmp al,0
    jz @3
    dec al
    or Flags,4
@3: mov Blue,al

    test Flags,00001111b
    jz   @Cont1

    or  Flags,128

    {Write Section}

    mov dx,3c8h {write preparetion}
    mov al,bl
    out dx,al
    mov dx,3c9h {now send data}

    mov al,red
    out dx,al

    mov al,green
    out dx,al

    mov al,Blue
    out dx,al

@Cont1:
    inc  bl

    loop @lo1

    test Flags,128
    jnz  @NotFullDAC
    mov  al,1      {DAC all colors are zero }
    jmp  @Finish
@NotFullDAC:
    mov  al,0   {Not Full}
@Finish:

End;


Procedure FadeIn;
Begin
    Repeat
        RetraceDelay(FadeDelay);
    Until FadeInOnce(0) <> 0;
End;

{*****************************************}
{Procedure FadeOneColor                   }
{We Fade one DAC color to Red,Green,Blue  }
{*****************************************}
Procedure FadeInOneColor(DACNum :Byte;Red,Green,Blue :Byte);assembler;
Var
   Flags :Byte;
Asm;

 mov Flags,0

 {Read section}

 mov dx,3c7h
 mov al,DACNum
 out dx,al

 mov dx,3c9h  {Data Port}


 in  al,dx
 cmp al,Red
 jbe @Cont1
 dec al
 mov Red,al
 or  Flags,1

@Cont1:
 in  al,dx
 cmp al,Green
 jbe @Cont2
 dec al
 mov Green,al
 or  Flags,2

@Cont2:
 in  al,dx
 cmp al,Blue
 jbe @Cont3
 dec al
 mov Blue,al
 or  Flags,4

@Cont3:

 cmp Flags,0
 jz  @Finish

 dec dx    {write preparetion}
 mov al,DACNum
 out dx,al
 inc dx    {now send data}

 mov al,red
 out dx,al

 mov al,green
 out dx,al

 mov al,Blue
 out dx,al

 mov StaticVar,1
@Finish:

End;


Procedure FadeInPalette(Pal :RGBType);
Var
   I            :Byte;
Begin
    Repeat
      StaticVar:=0;
      VerticalRetrace;
      For I:=0 to 255 do
          FadeInOneColor(I,Pal[I].Red,Pal[I].Green,Pal[I].Blue);
      RetraceDelay(FadeDelay);
    Until StaticVar = 0;

End;

Procedure ZeroRGBPalette;assembler;
asm;

    call VerticalRetrace

    mov cx,256
    mov dx,3c8h
    mov al,0
    out dx,al
    mov dx,3c9h
    mov al,0
@Lo1:
    out dx,al
    nop

    out dx,al
    nop

    out dx,al
    nop

    loop @Lo1

End;

{*******************************************************************}
{Procedure FadeOutOnce                                              }
{Input :DAC Start color for fading out.                             }
{Output:0=if fadeout not finished or 1=if fadeout finished.         }
{*******************************************************************}


Function FadeOutOnce(StartDACNumber :Byte): Byte;assembler;
Var
   Red,Green,Blue :Byte;
   Flags          :Byte;
asm;
   call VerticalRetrace

   xor bx,bx
   mov bl,StartDACNumber      {Start DAC number}
   mov cx,256    {Max DAC Colors}
   sub cx,bx
   mov si,Offset CurrentPalette
   mov Flags,0

@Lo1:
   and Flags,11111000b

   mov dx,3c7h  {Read Section}
   mov al,bl    {Which register}
   out dx,al

   mov dx,3c9h  {Data preparetion}
   in  al,dx    {Read current value,Al}
   mov red,al

   in al,dx
   mov green,al

   in al,dx
   mov blue,al

   mov ah,[si]  {Read the actual palette,Ah}
   mov al,red
   cmp al,ah    {Is AL bigger or equal than AH ?}
   jae @Next1   {If yes then don't change anything.}
   inc red
   or Flags,1

@Next1:
   inc si
   mov ah,[si]
   mov al,green
   cmp al,ah
   jae @Next2
   inc green
   or Flags,2

@Next2:
   inc si
   mov ah,[si]
   mov al,blue
   cmp al,ah
   jae @Next
   inc blue
   or Flags,4

@Next:

   test Flags,00001111b
   jz   @Cont1

   or  Flags,128



   mov dx,3c8h  {Write section}
   mov al,bl
   out dx,al

   mov dx,3c9h  {Now the actual transfer section}
   mov al,red
   out dx,al

   mov al,green
   out dx,al

   mov al,blue
   out dx,al

@Cont1:
   inc si
   inc bl

   loop @lo1

   test Flags,128
   jnz  @NotFullOfDAC
   mov al,1    {Ok DAC = Current Palette}
   jmp @Finish

@NotFullOfDAC:
   mov al,0 {we can continue fade out if we want}

@Finish:

End;

Procedure FadeOut;
Begin
    ZeroRGBPalette;
    Repeat
        RetraceDelay(FadeDelay);
    Until FadeOutOnce(0) <> 0;
End;

{*****************************************}
{Procedure FadeOneColor                   }
{We Fade one DAC color to Red,Green,Blue  }
{*****************************************}
Procedure FadeOutOneColor(DACNum :Byte;Red,Green,Blue :Byte);assembler;
Var
   Flags :Byte;
Asm;

 mov Flags,0

 {Read section}

 mov dx,3c7h
 mov al,DACNum
 out dx,al

 mov dx,3c9h  {Data Port}


 in  al,dx
 cmp al,Red
 je  @Cont1
 ja  @Cont1a
 inc al
 mov Red,al
@Cont1a:
 or  Flags,1

@Cont1:
 in  al,dx
 cmp al,Green
 je  @Cont2
 ja  @Cont2a
 inc al
 mov Green,al
@Cont2a:
 or  Flags,2


@Cont2:
 in  al,dx
 cmp al,Blue
 je  @Cont3
 ja  @Cont3a
 inc al
 mov Blue,al
@Cont3a:
 or  Flags,4

@Cont3:
 cmp Flags,0
 jz  @Finish

 dec dx    {write preparetion}
 mov al,DACNum
 out dx,al
 inc dx    {now send data}

 mov al,red
 out dx,al

 mov al,green
 out dx,al

 mov al,Blue
 out dx,al

 mov StaticVar,1
@Finish:

End;


Procedure FadeOutPalette(Pal :RGBType);
Var
   I            :Byte;
Begin
    Repeat
      StaticVar:=0;
      VerticalRetrace;
      For I:=0 to 255 do
          FadeOutOneColor(I,Pal[I].Red,Pal[I].Green,Pal[I].Blue);
{      RetraceDelay(FadeDelay);}
    Until StaticVar = 0;

End;


Procedure FadeMax;Assembler;
Var
   Red,Green,Blue :Byte;
   Flags          :Byte;
   OkDone         :Byte;
Asm;

   mov cx,256    {Max DAC Colors}

@Lo2:
   push cx
   mov cx,256

   mov Flags,0
   mov bl,0      {Start DAC number}
   mov OkDone,0
   call VerticalRetrace

@Lo1:
   mov dx,3c7h  {Read Section}
   mov al,bl    {Which register}
   out dx,al

   mov dx,3c9h  {Data preparetion}
   in  al,dx    {Read current value,Al}
   mov red,al

   in al,dx
   mov green,al

   in al,dx
   mov blue,al

   cmp red,63
   jae @Next1   {If yes then don't change anything.}
   inc red
   or Flags,1

@Next1:
   cmp green,63
   jae @Next2
   inc green
   or Flags,2

@Next2:
   cmp blue,63
   jae @Next
   inc blue
   or Flags,4

@Next:

   cmp Flags,0
   jz  @Cont1

   mov dx,3c8h  {Write section}
   mov al,bl
   out dx,al

   inc  dx  {Now the actual transfer section}
   mov al,red
   out dx,al

   mov al,green
   out dx,al

   mov al,blue
   out dx,al

   mov OkDone,1

@Cont1:

   inc  bl
   loop @lo1

   pop cx
   cmp OkDone,0
   jz  @Finish
   loop @Lo2

@Finish:

End;


Function LoadPalette( Pathname: string;Var Pal :RGBType) :Integer;
Var
  PalFile :File of RGBType;
  Result  :Integer;
Begin
  Assign( PalFile, Pathname);
{$I-}
  Reset( PalFile );{$I+}

  Result:=IOResult;
  IF Result <> 0 Then
  Begin
    LoadPalette:=Result;
    Exit;
  End;

  Read( PalFile, Pal);
  Close( PalFile );

  LoadPalette:=0;
End;



END.