UNIT DOS4GB;

INTERFACE

Uses Crt;
Type
    ExtMemMoveStruct = Record
        Leng             :LongInt;
        SourceHandler    :Word;
        SourceOfs        :LongInt;
        DestHandler      :Word;
        DestOfs          :LongInt;
    End;

Var

   XMS_Address  :Pointer;
   XMS_R_Result :Word;
   Move_EMB     :ExtMemMoveStruct;


{$L Dos4gb.obj}
{$L Cpu.Obj}

{********************************************************************}
{/////////////////////// ASSEMBLY ROYTINES //////////////////////////}



{$F+}
Procedure InitCode32;
Function  Virtual86 :Boolean;
Function  InitXMS   :Boolean;




Function  XMS_ReadB(Address,Index:LongInt) :Byte;
Procedure XMS_WriteB(Address,Index:LongInt;Data:Byte);

Function  XMS_ReadW(Address,Index:LongInt) :Word;
Procedure XMS_WriteW(Address,Index:LongInt;Data:Word);

Function  XMS_ReadD(Address,Index:LongInt) :LongInt;
Procedure XMS_WriteD(Address,Index:LongInt;Data:LongInt);

Procedure XMS_CopyBitBlt(Source,Dest,Data:LongInt);

Function  FlatMem(Segment,Offset :Word) : LongInt;
{$F-}

{************************************************************************}
{////////////////////// PASCAL ROYTINES /////////////////////////////////}
Function XMS_MoveEMB(Sourcehandle :Word;SourceOfs :LongInt;
             DestHandle :Word; DestOfs :LongInt; Leng :LongInt) :Word;
Function  XMS_Result :Word;
Function  XMS_MaxFreeBlock :Word;
Function  XMS_MemAvail :Word;
Function  XMS_AllocMem(KBytes :Word) :Word;
Function  XMS_FreeMem(Handle :Word) :Word;
Function  XMS_Lock(Handle :Word):LongInt;
Procedure XMS_UnLock(Handle :Word);
Function  XMS_EnableA20 :Word;
Procedure Init_DOS4GB;
Function  XMS_BlockRead(Var F: File;Var Handle:Word;Count :LongInt) :Integer;

IMPLEMENTATION



{$F+}
Procedure InitCode32;external;
Function  Virtual86 :Boolean;external;
Function  InitXMS   :Boolean;external;



Function  XMS_ReadB(Address,Index:LongInt) :Byte;external;
Procedure XMS_WriteB(Address,Index:LongInt;Data:Byte);external;

Function  XMS_ReadW(Address,Index:LongInt) :Word;external;
Procedure XMS_WriteW(Address,Index:LongInt;Data:Word);external;

Function  XMS_ReadD(Address,Index:LongInt) :LongInt;external;
Procedure XMS_WriteD(Address,Index:LongInt;Data:LongInt);external;

Procedure XMS_CopyBitBlt(Source,Dest,Data:LongInt);external;

Function  FlatMem(Segment,Offset :Word) : LongInt;external;

Function   GetProz :Integer;external;
Function   GetCo   :Integer;external;
{$F-}


{*************************************************************************}
{Function XMS_MoveEMB(Sourcehandle :Word;SourceOfs :LongInt;
             DestHandle :Word; DestOfs :LongInt; Leng :LongInt);
Moves Extended Memory Block. If SourceHandle or DestHandle = 0000 then
the himem manager refers derectly to a Seg:Ofs pair.
**************************************************************************}
Function XMS_MoveEMB(Sourcehandle :Word;SourceOfs :LongInt;
             DestHandle :Word; DestOfs :LongInt; Leng :LongInt) :Word;
Var
   Address      :Pointer;
Begin
   Move_EMB.SourceHandler:=SourceHandle;
   Move_EMB.SourceOfs:=SourceOfs;
   Move_EMB.DestHandler:=DestHandle;
   Move_EMB.DestOfs:=DestOfs;
   Move_EMB.Leng:=Leng and $FFFFFFFE; {always even}

   Address:=@Move_EMB;

   Asm;
         mov ah,0bh
         push ds
         lds si,address
         call dword ptr XMS_ADDRESS
         pop  ds
         or ax,ax    {IF ax=1 then correct else if ax=0 the error}
         jz @Error
         xor ax,ax
         jmp @Fin
     @Error:
         xor ax,ax
         mov al,bl  {bl=error code}
         mov XMS_R_Result,ax
     @Fin:

   End;

   XMS_MoveEMB:=XMS_R_Result;
End;

{*************************************************************************}
{Function XMS_Result :Word                                                }
{It's a READ ONLY Error Code information.After the first reading the      }
{XMS_Result returns zero until the next error code.It works just like the }
{IOResult.                                                                }
{*************************************************************************}
Function XMS_Result :Word;
Begin
    XMS_Result:=XMS_R_Result;
    XMS_R_Result:=0;
End;


{********************************************************************}
{Function XMS_EnableA20 :Word                                        }
{Returns: Zero if no Error occured                                   }
{********************************************************************}
Function XMS_EnableA20 :Word;Assembler;
Asm;
    mov ah,05h
    call dword ptr XMS_ADDRESS
    or ax,ax    {IF ax=1 then correct else if ax=0 the error}
    jz @Error
    xor ax,ax
    jmp @Fin
@Error:
    xor ax,ax
    mov al,bl  {bl=error code}
    mov XMS_R_Result,ax
@Fin:
End;

{************************************************************************}
{Function XMS_MaxFreeBlock : Word                                        }
{Returns :Size of the largest free block of extended memory in Kbytes    }
{************************************************************************}
Function XMS_MaxFreeBlock :Word;Assembler;
Asm;
    mov ah,08h
    call dword ptr XMS_ADDRESS
    {Now ax has the max free block in KB}
End;

{**********************************************************************}
{Function XMS_MemAvail :Word                                           }
{Returns :Total free extended memory in Kbytes                         }
{**********************************************************************}

Function XMS_MemAvail :Word;Assembler;
Asm;
    mov ah,08h
    call dword ptr XMS_ADDRESS
    mov ax,dx
    {Now ax has the max free Mem in KB}
End;

{***********************************************************************}
{Function XMS_AllocMem(KBytes :Word) :Word                              }
{Allocate Extended Memory Block.                                        }
{Returns: Zero if no Error occured                                      }
{Note   :The number of handles is limited (Usually 32)                  }
{***********************************************************************}
Function XMS_AllocMem(KBytes :Word) :Word;Assembler;
Asm;
    mov ah,09h
    mov dx,KBytes
    call dword ptr XMS_ADDRESS
    or ax,ax    {IF ax=1 then correct else if ax=0 the error}
    jz @Error
    mov ax,dx {handle}
    jmp @Fin
@Error:
    xor ax,ax
    mov al,bl  {bl=error code}

    mov XMS_R_Result,ax
@Fin:
End;

{*************************************************************************}
{Function XMS_FreeMem(Handle :Word) :Word                                 }
{Free allocated Extended Memory Block (EMB)                               }
{If an error will occured the XMS_Error function is loaded with the       }
{returned error code.                                                     }
{*************************************************************************}
Function XMS_FreeMem(Handle :Word) :Word;Assembler;
Asm;
    mov ah,0Ah
    mov dx,Handle
    call dword ptr XMS_ADDRESS
    or ax,ax    {IF ax=1 then correct else if ax=0 the error}
    jz @Error
    xor ax,ax
    jmp @Fin
@Error:
    xor ax,ax
    mov al,bl  {bl=error code}

    mov XMS_R_Result,ax

@Fin:
End;

{**********************************************************************}
{Function XMS_Lock(Handle :Word):Pointer                               }
{Lock Extended Memory Block                                            }
{Returns the linear 32bit address of the EMB in memory                 }
{**********************************************************************}
Function XMS_Lock(Handle :Word):LongInt;Assembler;
Asm;
       mov ah,0Ch
       mov dx,Handle
       call dword ptr XMS_ADDRESS
       or ax,ax    {IF ax=1 then correct else if ax=0 the error}
       jz @Error

       mov ax,bx        {dx:ax = 32bit address}

       jmp @Fin
   @Error:
       xor ax,ax
       mov al,bl  {bl=error code}
       mov XMS_R_Result,ax
       xor ax,ax
       xor dx,dx

   @Fin:



End;

{************************************************************************}
{Procedure XMS_UnLock(Handle :Word)                                      }
{Unlocks an EMB previously locked by the function XMS_Lock               }
{See the XMS_Error for error checking.                                   }
{************************************************************************}
Procedure XMS_UnLock(Handle :Word);Assembler;
Asm;
    mov ah,0Dh
    mov dx,Handle
    call dword ptr XMS_ADDRESS
    or ax,ax    {IF ax=1 then correct else if ax=0 the error}
    jz @Error
    xor ax,ax
    jmp @Fin
@Error:
    xor ax,ax
    mov al,bl  {bl=error code}

    mov XMS_R_Result,ax

@Fin:
End;


{***********************************************************************}
{Procedure Init_DOS4GB                                                  }
{Initialize the program                                                 }
{***********************************************************************}
Procedure Init_DOS4GB;
Begin
   TextColor(11);

   Writeln('        Dos4GB   Version  1.1   (C)opyright  1995,97       ');
   Writeln;
   XMS_Address:=Nil;
   TextColor(7);

   IF GetProz < 7 Then
   Begin
     Writeln('Sorry, a i386 CPU and above is required to run this program.');
     Halt;
   End;

   IF Virtual86 Then
   Begin
     Writeln('Machine is already in V86 mode.Please remove QEMM and other such drivers.');
     Halt;
   End;

   InitCode32;

   IF InitXMS = True Then
   Begin
      Writeln('XMS driver not found or too old');
      Halt;
   End;

   XMS_EnableA20;

   Writeln('þ Flat mode initialized.');
   Writeln('þ Line A20 enabled.');

End;


{*****************************************************************************}
{Function XMS_BlockRead(Var F: File;Var Handle :Word;Count :LongInt) :Integer;}
{Reads a Block size from the file into an XMS_RAM.                            }
{It works like the Turbo Pascal's BlockRead procedure.                        }
{*****************************************************************************}
Function XMS_BlockRead(Var F: File;Var Handle :Word;Count :LongInt) :Integer;
Var
   Conv_Buf     :Pointer;
   Buf          :LongInt;
   Readed       :Word;
   TIOResult    :Integer;
   InnerLoop    :Word;
   Temp,I       :Word;
   BlockSize    :Word;
   Addr1        :LongInt;
   OrgBlockSize :Word;

Begin

   {If the Block is greater than 64k then break it in small pieces of shit}

   IF Count > 64000 Then
   Begin
      Temp:=Count div 64000;
      IF (Count mod 64000) = 0 Then
         InnerLoop:=Temp
      Else
         InnerLoop:=Temp+1;

      BlockSize:=64000;
   End
   Else
   Begin
      InnerLoop:=1;
      BlockSize:=Count;
   End;

    OrgBlockSize:=BlockSize;
    GetMem(Conv_Buf,OrgBlockSize);
    Addr1:=FlatMem(Seg(Conv_Buf^),Ofs(Conv_Buf^));
    Buf:=XMS_Lock(Handle);

    For I:=1 to InnerLoop do
    Begin
       {$I-}
           IF Count > BlockSize Then
              BlockRead(F,Conv_Buf^,BlockSize,Readed)
           Else
           Begin
              BlockSize:=Count;
              BlockRead(F,Conv_Buf^,BlockSize,Readed)
           End;
       {$I+}

           TIOResult:=IOResult;
           IF (Readed <> BlockSize) or (TIOResult <> 0) Then
           Begin
               FreeMem(Conv_Buf,OrgBlockSize);
               XMS_UnLock(Handle);
               XMS_BlockRead:=TIOResult;
               Exit;
           End;

           XMS_CopyBitBlt(Addr1,Buf+(OrgBlockSize*(I-1)),BlockSize);

           Count:=Count-BlockSize;
    End;

    FreeMem(Conv_Buf,OrgBlockSize);
    XMS_UnLock(Handle);
    XMS_BlockRead:=0;

End;

Begin


End.