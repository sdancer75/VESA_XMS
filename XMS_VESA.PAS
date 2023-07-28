Uses Dos4GB,vesa_pm,palette,Crt;
Const
     MaxSeg     = 4;

Procedure DestroyPic(Var Hand :Word);
Begin
       XMS_FreeMem(Hand);
End;


Procedure LoadPic(Path :String;Var Hand :Word);
Var
   Conv_Buf     :Pointer;
   I            :Byte;
   Leng         :Word;
   xms_addr     :LongInt;
   myBuf_addr   :LongInt;
   F            :File;
   Readed       :Word;
   er           :Word;
Begin
    Hand:=XMS_AllocMem(307);
    Assign(F,Path);
{$I-}
    Reset(F,1); {$I+}
    IF IOResult <> 0 Then
    Begin
       Textmode(3);
       Writeln('Error while trying to load the fucking file.');
       DestroyPic(Hand);
       Halt(0);
    End;

    GetMem(Conv_Buf,$FFFF);
    mybuf_addr:=LongInt(ptr(Seg(Conv_Buf^),Ofs(Conv_Buf^)));

    {*********** the 4 first blocks are 64000 bytes long  **********}
    {*********** while the last block is 51200 bytes long **********}

    For I:=0 to MaxSeg do
    Begin

       IF i <> MaxSeg Then
          Leng:= $FFFF
       Else
          Leng:= 45060;

     {$I-}
        BlockRead(F,Conv_Buf^,Leng,Readed);{$I+}
        IF (IOResult <>0) or (Readed <> Leng) Then
        Begin
            FreeMem(Conv_Buf,$FFFF);
            DestroyPic(Hand);
            Textmode(3);
            Writeln('Error while trying to load the fucking file.');
            halt(0);
        End;

        er:=XMS_MoveEMB(0,mybuf_addr,Hand,LongInt(i)*$FFFF,Leng);

    End;

    Close(F);
    freeMem(Conv_Buf,$FFFF);
End;


{************************************************************************************
Use this to show a whole pic. If you wanna print a sprite use
the routines that are included with the vesa_pm unit. These are

Procedure CopyMemToVideoBuf8(SourceX,SourceY,Width,Height :Word;MemoryLoc :Pointer);
Procedure CopyVideoBufToMem8(SourceX,SourceY,Width,Height :Word;MemoryLoc :Pointer);
*************************************************************************************}

Procedure ShowPic(Hand :Word);
Var
   Leng         :Word;
   xms_addr     :Word;
   I            :Byte;
   J            :LongInt;
   Index        :LongInt;
   Conv_Buf     :Pointer;
   MyBuf_addr   :LongInt;
   SSeg,SOfs    :Word;

Begin
     GetMem(Conv_Buf,$FFFF);
     SSeg:=Seg(Conv_Buf^);
     SOfs:=Ofs(Conv_Buf^);

     mybuf_addr:=LongInt(ptr(SSeg,SOfs));
     Index:=0;
     For I:=0 to MaxSeg do
     Begin
         IF i <> MaxSeg Then
            Leng:= $FFFF
         Else
            Leng:= 45060;

         XMS_MoveEMB(Hand,LongInt(i)*$FFFF,0,mybuf_addr,leng);


         IF I<>0 Then
         Begin
             Mem[$A000:$FFFF]:=Mem[SSeg:SOfs];
             Index:=1;
         End;

         SetBank(i);

         For J:=0 to Leng-1 do
         Begin
             Mem[$A000:J]:=Mem[SSeg:SOfs+Index];
             Inc(Index);
         End;
{         readln;       }

     End;


     FreeMem(Conv_Buf,$FFFF);
End;




Var
   Handler      :Word;


Begin
   Clrscr;

   IF InitXMS = True Then
   Begin
      Writeln('XMS driver not found or too old');
      Halt;
   End
   Else
   Begin
      Writeln('þ XMS initialized.');
   End;

   XMS_EnableA20;

   Writeln;
   Writeln;
   Writeln('============== XMS MEM INFO Block =============');

   Writeln('Total MemAvail = ',XMS_MemAvail);
   Writeln('Largest Memory Block = ',XMS_MaxFreeBlock);
   Writeln('===============================================');
   Readln;

   IF isVesa = False Then
   Begin
      Writeln('No Vesa driver  presents.');
      halt(0);
   End;


   LoadPic('Shadow.raw',Handler);
   LoadPalette('Shadow.col',CurrentPalette);


   Writeln;
   Writeln;
   Writeln('============== XMS MEM INFO Block after alloc =============');

   Writeln('Total MemAvail = ',XMS_MemAvail);
   Writeln('Largest Memory Block = ',XMS_MaxFreeBlock);
   Writeln('================== after alloc =============================');
   Readln;

   If SetMode(_640x480x256) = False Then
   Begin
      Writeln('Vesa mode 640x480x8 bpp not supported.');
      halt(0);
   End;

   ClearScreen8(0);

   SetRGBColors(CurrentPalette);
   ShowPic(Handler);


   Readln;
   Textmode(3);
   DestroyPic(Handler);
End.