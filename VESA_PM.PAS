{*************************************************************************}
{VESA LIBRARY Ver 1.00                                                    }
{                                                                         }
{Programmed by George Papaioannou Thessaloniki 1997                       }
{This program is copyrighted under the law of the GR constitution         }
{                                                                         }
{**It supports Real and Dos4GB_PM mode-->fOR NoW oNLy rEaL                }
{*************************************************************************}


UNIT VESA_PM;



INTERFACE


Uses Dos;
{$L vesa_pm.obj}


Const
  _640x400x256   = $100;
  _640x480x256   = $101;
  _800x600x256   = $103;
  _1024x768x256  = $105;
  _1280x1024x256 = $107;
  _640x480x32k   = $110;
  _640x480x64k   = $111;

  XOR_PUT        = 1;
  AND_PUT        = 2;
  MASKED_PUT       = 3;


Type
     ModeList=Array[1..32] Of Word;  { List of VESA mode numbers }

     modeAttrBits = (modeAvail,
                     modeExtendInfo,
                     modeBIOSsupport,
                     modeColor,
                     modeGraphics,
                     modeBit5,
                     modeBit6,
                     modeBit7,
                     modeBit8);

     winAttrBits  = (winSupported,
                     winReadable,
                     winWriteable);

     tMemModel    = (modelText,
                     modelCGA,
                     modelHerc,
                     model4Plane,
                     modelPacked,
                     modelModeX,
                     modelRGB);


     TVesaMode=Record
       Attr     : set of modeAttrBits; { Mode Attributes                   }
       WinA,                                  { Window A attributes        }
       WinB     : set of winAttrBits;         { Window B attributes        }
       Gran     : Word;         { Window granularity in K bytes     }
       WinSiz   : Word;         { Size of window in K bytes         }
       SegA     : Word;         { Segment address of window A       }
       SegB     : Word;         { Segment address of window B       }
       WinFunc  : Pointer;      { Windows positioning function      }
       BPLine   : Word;         { Number of bytes per line          }
       {------------------------------------------------------------}
       {Extended information for non-VESA supported video modes     }
       {------------------------------------------------------------}
       PWidth   : Word;         { Number of horizontal pixels       }
       PHeight  : Word;         { Number of vertical pixels         }
       CharW    : Byte;         { Width of character cell           }
       CharH    : Byte;         { Height of character cell          }
       Planes   : Byte;         { Number of memory planes           }
       Bits     : Byte;         { Number of bits per pixel          }
       nBanks   : Byte;         { Number of banks        (not used) }
       MemModel : Byte;         { Memory model type                 }
       Banks    : Byte;         { Size of bank           (not used) }
       Pages    : Byte;         { Number of image pages             }
       Reserved : Byte; { The following are for 15,16,24,32 bit colour modes }
       RedMaskSize   : Byte;    { Size of Red mask in bits          }
       RedFieldPos   : Byte;    { Bit position of LSB of Red mask   }
       GreenMaskSize : Byte;    { Size of Green mask in bits        }
       GreenFieldPos : Byte;    { Bit position of LSB of Green mask }
       BlueMaskSize  : Byte;    { Size of Blue mask in bits         }
       BlueFieldPos  : Byte;    { Bit position of LSB of Blue mask  }
       RsvdMaskSize  : Byte;    { Size of Reserved mask in bits     }
       RsvdFieldPos  : Byte;    { Bit pos. of LSB of Reserved mask  }
       DirColModeInf : Byte;    { Direct Colour mode attributes     }
       Filler   : Array[0..215] Of Byte; { Not used - filler        }
     End;


     TVesaInfo=Record
       Signature    : LongInt;   { Signature - "VESA"               }
       Version      : Word;      { VESA Version number hi byte = major ver}
       OEMName      : PChar;     { Pointer to manufacturer name     }
       Capabilities : Longint;   { Capabilities       (Not used)    }
       List         : ModeList; { Pointer to list of VESA modes    }
       TotalMemory  : Word;      { Number of 64k memory blocks on card }
       Filler       : Array[1..238] of Byte;
     End; { 258 byte size due to bug in the Diamond SpeedStar 24X v1.01 BIOS }

     FontDEF = Array[0..255,0..15] Of Byte;                  { Font array }

Var

   Regs                 :Registers;
   VesaMode             :TVesaMode;
   VesaInfo             :TVesaInfo;
   Vesa_On              :Byte;
   ActiveBank           :Word;
   CharSet              :FontDEF;
Const
   TxtBGColor           :Byte = 0;
   TxtFGColor           :Byte = 15;


{$F+}
Function  GetPixel8(X,Y :Word) :Byte ;
Procedure SetPixel8(X,Y :Word;Pix :Byte);
Procedure CopyMemToVideoBuf8(SourceX,SourceY,Width,Height :Word;MemoryLoc :Pointer);
Procedure CopyVideoBufToMem8(SourceX,SourceY,Width,Height :Word;MemoryLoc :Pointer);
Procedure ClearScreen8(Color :Word);
{$F-}

Function  IsVesa :Boolean;
Procedure GetVesaInfo;
Procedure GetVesaModeInfo(Md:Word);
Function  SetMode(Md:Word):Boolean;
Function  GetMode:Word;
Function  SizeOfVideoState:Word;
Procedure SaveVideoState(Var Buf);
Procedure RestoreVideoState(Var Buf);
Procedure SetBank(Bank:Word);
Function  GetBank:Word;
Procedure SetLineLength(Var Len:Word);
Function  GetLineLength:Word;
Procedure SetDisplayStart(X,Y:Word);
Procedure GetDisplayStart(Var X,Y:Word);

{General Routines}

Procedure EnableVGA;
Procedure DisableVGA;
Procedure VSync;
Function  MakeHex(A :Word) :String;
Function  LoadCharSet(FileName :String) :Integer;
Procedure SetFGroundTxt(TColor :Byte);
Procedure SetBGroundTxt(TColor :Byte);
Procedure Print_Char(X,Y :Word;Ch :Char);
Procedure Print_String(X,Y :Word;Str :String);

IMPLEMENTATION

{$F+}
Function  GetPixel8(X,Y :Word) :Byte ;external;
Procedure SetPixel8(X,Y :Word;Pix :Byte);external;
Procedure CopyMemToVideoBuf8(SourceX,SourceY,Width,Height :Word;MemoryLoc :Pointer);external;
Procedure CopyVideoBufToMem8(SourceX,SourceY,Width,Height :Word;MemoryLoc :Pointer);external;
Procedure ClearScreen8(Color :Word);external;
{$F-}



{**************************************************************}
{Function IsVesa :Boolean                                      }
{Returns true is the video card supports the vesa standard     }
{**************************************************************}

Function IsVesa :Boolean;
Begin
   Regs.ax:=$4F03;
   Intr($10,Regs);
   IsVesa:=(Regs.ax = $4F);
End;

{**************************************************************}
{Procedure GetVesaInfo                                         }
{Returns SVGA information                                      }
{**************************************************************}
Procedure GetVesaInfo;
Begin
  Regs.ax:=$4F00;
  Regs.di:=Ofs(VesaInfo);
  Regs.es:=Seg(VesaInfo);
  Intr($10,Regs);
End;

{**************************************************************}
{Procedure GetVesaModeInfo(Md :Word);                          }
{Returns info for a specific video mode that may not be        }
{supported from the standard vesa video modes.                 }
{**************************************************************}
Procedure GetVesaModeInfo(Md:Word);
Begin
  Regs.ax:=$4F01;
  Regs.cx:=md;
  Regs.di:=Ofs(VesaMode);
  Regs.es:=Seg(VesaMode);
  Intr($10,Regs);
End;

{**************************************************************}
{Function SetMode(Md:Word):Boolean                             }
{Set SVga video mode.IF video mode < $FF is not a vesa mode but}
{the program will try to set it adjusting propertly and the    }
{VesaMode variable info.IF VESA mode then VESA_On=1 else =0    }
{**************************************************************}
Function SetMode(Md:Word):Boolean;
Begin
  SetMode:=True; VESA_On:=1;
  ActiveBank:=0;

  IF Md > $FF Then
  Begin
    Regs.bx:=Md;
    Regs.ax:=$4F02;
    Intr($10,Regs);
    IF Regs.ax<>$4F Then
       SetMode:=False
    Else
       GetVesaModeInfo(Md);
  End
  Else
  Begin
    Regs.ax:=Md;
    Intr($10,Regs);
    VesaMode.Gran:=64;
    VESA_On:=0;
    VesaMode.SegA:=$A000;
    Case Md Of  { OEM (standard) video modes }
      1..3,7 : Begin { Text modes }
                 VesaMode.PWidth:=80;
                 VesaMode.PHeight:=25;
                 IF Md=7 Then
                 Begin
                   VesaMode.Bits:=1;
                   VesaMode.SegA:=$B000;
                 End
                 Else
                 Begin
                   VesaMode.Bits:=4;
                   VesaMode.SegA:=$B800;
                 End;
                 VesaMode.BPLine:=160;
                 VesaMode.MemModel:=0;
               End;
      $13 : Begin  { 320 x 200 x 256 colours, VGA & MCGA }
              VesaMode.PWidth:=320;
              VesaMode.PHeight:=200;
              VesaMode.Bits:=8;
              VesaMode.MemModel:=4;
              VesaMode.BPLine:=320;
            End;
      $12 : Begin  { 640 x 480 x 16 colours, VGA only }
              VesaMode.PWidth:=640;
              VesaMode.PHeight:=480;
              VesaMode.Bits:=4;
              VesaMode.MemModel:=3;
              VesaMode.BPLine:=80;
            End;
      $10 : Begin  { 640 x 350 x 16 colours, VGA & EGA with 128k+ }
              VesaMode.PWidth:=640;
              VesaMode.PHeight:=350;
              VesaMode.Bits:=4;
              VesaMode.MemModel:=3;
              VesaMode.BPLine:=80;
            End;
      $0E : Begin  { 640 x 200 x 16 colours, VGA & EGA }
              VesaMode.PWidth:=640;
              VesaMode.PHeight:=200;
              VesaMode.Bits:=4;
              VesaMode.MemModel:=3;
              VesaMode.BPLine:=80;
            End;
      $0D : Begin  { 320 x 200 x 16 colours, VGA & EGA }
              VesaMode.PWidth:=320;
              VesaMode.PHeight:=200;
              VesaMode.Bits:=4;
              VesaMode.MemModel:=3;
              VesaMode.BPLine:=40;
            End;
      Else
        SetMode:=False;
    End;
  End;
End;

{*****************************************************************}
{Function GetMode :Word                                           }
{Return Current video mode.                                       }
{*****************************************************************}
Function GetMode:Word;
Begin
  Regs.ax:=$4F03;
  Intr($10,Regs);
  GetMode:=Regs.bx;
End;

{*****************************************************************}
{Function SizeOfVideoState:Word                                   }
{Return Save/Restore state buffer size.In this function we request}
{the size of all states that is :Video Hardware,Video BIOS,Video  }
{DAC and SVga state.Returns the number of 64-byte blocks.         }
{*****************************************************************}
Function SizeOfVideoState:Word;
Begin  { Will save/restore all video states }
  Regs.ax:=$4F04;
  Regs.dl:=0;
  Regs.cx:=$0F;  { hardware, BIOS, DAC & SVGA states }
  Intr($10,Regs);
  SizeOfVideoState:=Regs.bx;
End;

{*****************************************************************}
{Procedure SaveVideoSate(Var Buf)                                 }
{Save SVGA video state.Again we save all the requested states     }
{*****************************************************************}
Procedure SaveVideoState(Var Buf);
Begin
  Regs.ax:=$4F04;
  Regs.dl:=1;
  Regs.cx:=$0F;
  Regs.es:=Seg(Buf);
  Regs.bx:=Ofs(Buf);
  Intr($10,Regs);
End;

{*****************************************************************}
{Procedure RestoreVideoSate(Var Buf);                             }
{Restore Svga video state.                                        }
{*****************************************************************}
Procedure RestoreVideoState(Var Buf);
Begin
  Regs.ax:=$4F04;
  Regs.dl:=2;
  Regs.cx:=$0F;
  Regs.es:=Seg(Buf);
  Regs.bx:=Ofs(Buf);
  Intr($10,Regs);
End;

{*****************************************************************}
{Procedure SetBank(Bank :Word);                                   }
{Select svga memory window                                        }
{*****************************************************************}
Procedure SetBank(Bank:Word);
Var
   WinPos:Word;
Begin
  WinPos:=Bank*64 Div VesaMode.Gran;
  ActiveBank:=Bank;
  Asm;
     mov  ax,4f05h
     mov  bx,0
     mov  dx,winpos
     or   word ptr vesamode.winfunc[2],0
     jz   @interrupt
     call vesamode.winfunc
     jmp  @exit
  @interrupt:
     int 10h
  @Exit:
  End;
End;

{********************************************************************}
{Function GetBank : Word                                             }
{Return svga window position in video memory (in window granularity  }
{units                                                               }
{********************************************************************}
Function GetBank:Word;
Begin
  Regs.ax:=$4F05;
  Regs.bx:=$100;
  Intr($10,Regs);
  GetBank:=Regs.dx;
End;

{*********************************************************************}
{Procedure SetLineLentg(Var Len:Word);                                }
{Set Logical scan line length.                                        }
{*********************************************************************}
Procedure SetLineLength(Var Len:Word);
Begin
  Regs.ax:=$4F06;
  Regs.bl:=0;
  Regs.cx:=Len;
  Intr($10,Regs); { dx:=maximum number of scan lines }
  Len:=Regs.cx;
End;

{*********************************************************************}
{Function GetLineLength:Word;                                         }
{Get Logical scan line length                                         }
{*********************************************************************}
Function GetLineLength:Word;
Begin
  Regs.ax:=$4F06;
  Regs.bl:=1;
  Intr($10,Regs); { dx:=maximum number of scan lines }
  GetLineLength:=Regs.cx;
End;

{*********************************************************************}
{Procedure SetDisplayStart(Pixel,Line:Word);                          }
{Set display start.It used for scrolling in virtual screens.          }
{*********************************************************************}
Procedure SetDisplayStart(X,Y:Word);
Begin
  Regs.ax:=$4F07;
  Regs.bx:=0;
  Regs.cx:=X;
  Regs.dx:=Y;
  Intr($10,Regs);
End;

{********************************************************************}
{Procedure GetDisplayStart(Var pixel,line:Word);                     }
{Get display start.                                                  }
{********************************************************************}
Procedure GetDisplayStart(Var X,Y:Word);
Begin
  Regs.ax:=$4F07;
  Regs.bx:=1;
  Intr($10,Regs);
  X:=Regs.cx;
  Y:=Regs.dx;
End;

Procedure EnableVGA;Assembler;
Asm
   mov  dx,03c4h
   mov  al,1
   out  dx,al
   inc  dx
   in   al,dx
   and  al,0dfh
   out  dx,al
End;

Procedure DisableVGA;Assembler;
Asm
   mov  dx,03c4h
   mov  al,1
   out  dx,al
   inc  dx
   in   al,dx
   or   al,20h
   out  dx,al
End;

Procedure VSync;assembler;
Asm;
@OneCycle:
        MOV     DX,3DAh
@Wait:  IN      AL,DX
        TEST    AL,08h
        JZ      @Wait
@Retr:  IN      AL,DX
        TEST    AL,08h
        JNZ     @Retr
End;


Function MakeHex(A :Word) :String;
Const
     Hex :Array [0..15] of Char =
     ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
Var
   B,I          :Byte;
   S            :String;
Begin
     S:='';
     For I:=0 to 3 do
     Begin
        B:=Lo(A and $000F);
        A:=A shr 4;
        S:=char(B+48)+S;
     End;
     MakeHex:=S;
End;

Function LoadCharSet(FileName :String) :Integer;
Var
   FontFile     :File;
   FFileSize    :LongInt;
   Er           :Integer;
   TIOResult    :Integer;
Begin
    Assign(FontFile,FileName);
{$I-}
    Reset(FontFile,1);{$I+}
    TIOResult:=IOResult;
    IF TIOResult<>0 Then
    Begin
       LoadCharSet:=TIOResult;
       Exit;
    End;

    FFileSize:=FileSize(FontFile);
{$I-}
    BlockRead(FontFile,CharSet,FFileSize,Er);{$I+}
    TIOResult:=IOResult;
    IF (TIOResult<>0) Then
    Begin
        LoadCharSet:=TIOResult;
        Close(FontFile);
        Exit;
    End;
    Close(FontFile);
    LoadCharSet:=0;
End;

Procedure SetFGroundTxt(TColor :Byte);
Begin
    TxtFGColor:=TColor;
End;

Procedure SetBGroundTxt(TColor :Byte);
Begin
   TxtBGColor:=TColor;
End;

Procedure Print_Char(X,Y :Word;Ch :Char);
Var
     I, K :Word;                    { Loop counter }
     BMask:Byte;                    { Bit mask for character design }

Begin
    For I:= 0 to 15 do              { Yes --> Set foreground pixels only }
    Begin
      BMask := CharSet[ord(ch),i]; { Get bit pattern for one line }
      For K:= 0 to 7 do
      Begin
        If ( BMask and 128 <> 0 ) Then   { Pixel set? }
              SetPixel8( Word(X+K), Word(Y+I), TxtFGColor );  { Yes }
        BMask := BMask shl 1;
      End;
    End
End;

Procedure Print_String(X,Y :Word;Str :String);
Var
   I            :Byte;
   MyX          :Word;
   TakeChar     :String[1];
Begin
    For I:=1 to Length(Str) do
    Begin
        TakeChar:=Copy(Str,I,1);
        Print_Char(X,Y,TakeChar[1]);
        X:=X+8;
    End;
End;

End.