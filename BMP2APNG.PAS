{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program BMP2APNG;

{$A-}

Uses DOS;

Const
 bi_RGB=0;
 bi_RLE8=1;
 bi_RLE4=2;
 MaxWidth=4096;
 PNGSignature:Array[0..7]of Byte=(137,80,78,71,13,10,26,10);
 MaxStoredBlock=65535;

Type
 RGB32=Record
  B,G,R,FreeByte:Byte;
 End;

 HeaderBMP=Record
  Sign:Array[0..1]of Char;
  Size,Reserved0,OffBits:LongInt;
  biSize,NumXPixels,NumYPixels:LongInt;
  Planes,BitCount:Word;
  Compression,SizeImage:LongInt;
  XPelsPerMeter,YPelsPerMeter,ClrUsed,ClrImportant:LongInt;
 End;

 BitmapInfoHeader=Record
  biSize:LongInt;
  biWidth:LongInt;
  biHeight:LongInt;
  biPlanes:Word;
  biBitCount:Word;
  biCompression:LongInt;
  biSizeImage:LongInt;
  biXPelsPerMeter:LongInt;
  biYPelsPerMeter:LongInt;
  biClrUsed:LongInt;
  biClrImportant:LongInt;
 End;

Var
 SourceBMP,DestAPNG:File;
 Header:HeaderBMP;
 BIH:BitmapInfoHeader;
 BMPBytesPerLine,ByteReaded,ByteWritten:Word;
 StartPos:LongInt;
 NumPal:Word;
 Palette:Array[0..255]of RGB32;
 BMPLine:Array[0..MaxWidth*3-1]of Byte;
 RowBuf:Array[0..MaxWidth*3]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight:Word;
 BMPBPL:LongInt;
 Y,SourceRow:LongInt;
 X:Word;
 PalIdx:Byte;
 ByteV:Byte;
 CRCTable:Array[0..255]of LongInt;
 Adler_A,Adler_B:LongInt;
 TargetOpened:Boolean;

 RawBuf:Array[0..(MaxWidth*3+1)*64-1]of Byte;
 RawLen:LongInt;
 IDATBuf:Array[0..((MaxWidth*3+1)*64)+1024]of Byte;
 IDATLen:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.APNG';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourceBMP);
 If TargetOpened Then Close(DestAPNG);
 Halt;
End;

Procedure InitCRCTable;
Var
 N,K:Integer;
 C:LongInt;
Begin
 For N:=0 to 255 Do Begin
  C:=N;
  For K:=0 to 7 Do Begin
   If(C and 1)<>0 Then C:=LongInt($EDB88320)xor(LongInt(C shr 1)and LongInt($7FFFFFFF))
                  Else C:=LongInt(C shr 1)and LongInt($7FFFFFFF);
  End;
  CRCTable[N]:=C;
 End;
End;

Function UpdateCRC(CRC:LongInt;Const Buf;Len:LongInt):LongInt;
Var
 P:^Byte;
 I:LongInt;
 Idx:Byte;
Begin
 P:=@Buf;
 For I:=0 to Len-1 Do Begin
  Idx:=Byte((CRC xor LongInt(P^))and $FF);
  CRC:=CRCTable[Idx]xor(LongInt(CRC shr 8)and LongInt($00FFFFFF));
  Inc(P);
 End;
 UpdateCRC:=CRC;
End;

Function StartCRC:LongInt;
Begin
 StartCRC:=LongInt($FFFFFFFF);
End;

Function FinishCRC(CRC:LongInt):LongInt;
Begin
 FinishCRC:=CRC xor LongInt($FFFFFFFF);
End;

Procedure WriteBE32(Value:LongInt);
Var
 B:Array[0..3]of Byte;
Begin
 B[0]:=Byte((Value shr 24)and $FF);
 B[1]:=Byte((Value shr 16)and $FF);
 B[2]:=Byte((Value shr  8)and $FF);
 B[3]:=Byte( Value         and $FF);
 BlockWrite(DestAPNG,B,4,ByteWritten);
End;

Procedure WriteChunk(Const ChunkType:Array of Char;Const Data;Len:LongInt);
Var
 TypeBuf:Array[0..3]of Byte;
 CRC:LongInt;
Begin
 TypeBuf[0]:=Byte(ChunkType[0]);
 TypeBuf[1]:=Byte(ChunkType[1]);
 TypeBuf[2]:=Byte(ChunkType[2]);
 TypeBuf[3]:=Byte(ChunkType[3]);
 WriteBE32(Len);
 BlockWrite(DestAPNG,TypeBuf,4,ByteWritten);
 If Len>0 Then BlockWrite(DestAPNG,Data,Len,ByteWritten);
 CRC:=StartCRC;
 CRC:=UpdateCRC(CRC,TypeBuf,4);
 If Len>0 Then CRC:=UpdateCRC(CRC,Data,Len);
 CRC:=FinishCRC(CRC);
 WriteBE32(CRC);
End;

Procedure PutBE32(Var Buf:Array of Byte;Pos:Word;Value:LongInt);
Begin
 Buf[Pos+0]:=Byte((Value shr 24)and $FF);
 Buf[Pos+1]:=Byte((Value shr 16)and $FF);
 Buf[Pos+2]:=Byte((Value shr  8)and $FF);
 Buf[Pos+3]:=Byte( Value         and $FF);
End;

Procedure PutBE16(Var Buf:Array of Byte;Pos:Word;Value:Word);
Begin
 Buf[Pos+0]:=Byte((Value shr 8)and $FF);
 Buf[Pos+1]:=Byte( Value       and $FF);
End;

Procedure UpdateAdler(Const Buf;Len:LongInt);
Var
 P:^Byte;
 I:LongInt;
Begin
 P:=@Buf;
 For I:=0 to Len-1 Do Begin
  Adler_A:=(Adler_A+LongInt(P^))mod 65521;
  Adler_B:=(Adler_B+Adler_A)mod 65521;
  Inc(P);
 End;
End;

Function GetAdler32:LongInt;
Begin
 GetAdler32:=(LongInt(Adler_B)shl 16)or LongInt(Adler_A);
End;

Procedure BuildIDAT;
Var
 Pos:LongInt;
 Remain,BlockLen:LongInt;
 IsLast:Byte;
 Adler:LongInt;
Begin
 IDATLen:=0;
 IDATBuf[IDATLen]:=$78; Inc(IDATLen);
 IDATBuf[IDATLen]:=$01; Inc(IDATLen);
 Pos:=0;
 Adler_A:=1;
 Adler_B:=0;
 If RawLen=0 Then Begin
  IDATBuf[IDATLen]:=1; Inc(IDATLen);
  IDATBuf[IDATLen]:=0; Inc(IDATLen);
  IDATBuf[IDATLen]:=0; Inc(IDATLen);
  IDATBuf[IDATLen]:=$FF; Inc(IDATLen);
  IDATBuf[IDATLen]:=$FF; Inc(IDATLen);
 End
  Else
 Begin
  While Pos<RawLen Do Begin
   Remain:=RawLen-Pos;
   If Remain>MaxStoredBlock Then BlockLen:=MaxStoredBlock
                            Else BlockLen:=Remain;
   If(Pos+BlockLen)>=RawLen Then IsLast:=1 Else IsLast:=0;
   IDATBuf[IDATLen]:=IsLast; Inc(IDATLen);
   IDATBuf[IDATLen]:=Byte( BlockLen        and $FF); Inc(IDATLen);
   IDATBuf[IDATLen]:=Byte((BlockLen shr 8) and $FF); Inc(IDATLen);
   IDATBuf[IDATLen]:=Byte((not BlockLen)        and $FF); Inc(IDATLen);
   IDATBuf[IDATLen]:=Byte(((not BlockLen)shr 8) and $FF); Inc(IDATLen);
   Move(RawBuf[Pos],IDATBuf[IDATLen],BlockLen);
   UpdateAdler(RawBuf[Pos],BlockLen);
   Inc(IDATLen,BlockLen);
   Inc(Pos,BlockLen);
  End;
 End;
 Adler:=GetAdler32;
 IDATBuf[IDATLen]:=Byte((Adler shr 24)and $FF); Inc(IDATLen);
 IDATBuf[IDATLen]:=Byte((Adler shr 16)and $FF); Inc(IDATLen);
 IDATBuf[IDATLen]:=Byte((Adler shr  8)and $FF); Inc(IDATLen);
 IDATBuf[IDATLen]:=Byte( Adler         and $FF); Inc(IDATLen);
End;

Procedure ReadBmpRow(RowIndex:LongInt);
Begin
 Seek(SourceBMP,StartPos+RowIndex*LongInt(BMPBytesPerLine));
 BlockRead(SourceBMP,BMPLine,BMPBytesPerLine,ByteReaded);
End;

Function GetPalIndex(X:Word):Byte;
Var
 ByteV:Byte;
Begin
 Case BIH.biBitCount of
  1:Begin
   ByteV:=BMPLine[X shr 3];
   GetPalIndex:=(ByteV shr (7-(X and 7)))and 1;
  End;
  4:Begin
   ByteV:=BMPLine[X shr 1];
   If(X and 1)=0 Then GetPalIndex:=ByteV shr 4
                 Else GetPalIndex:=ByteV and $0F;
  End;
  8:GetPalIndex:=BMPLine[X];
  Else GetPalIndex:=0;
 End;
End;

Procedure BuildRawImage;
Begin
 RawLen:=0;
 For Y:=0 to LongInt(ImageHeight)-1 Do Begin
  SourceRow:=LongInt(ImageHeight)-1-Y;
  ReadBmpRow(SourceRow);
  RowBuf[0]:=0;
  Case BIH.biBitCount of
   24:Begin
    For X:=0 to ImageWidth-1 Do Begin
     RowBuf[1+X*3+0]:=BMPLine[X*3+2];
     RowBuf[1+X*3+1]:=BMPLine[X*3+1];
     RowBuf[1+X*3+2]:=BMPLine[X*3+0];
    End;
   End;
   Else Begin
    For X:=0 to ImageWidth-1 Do Begin
     PalIdx:=GetPalIndex(X);
     RowBuf[1+X*3+0]:=Palette[PalIdx].R;
     RowBuf[1+X*3+1]:=Palette[PalIdx].G;
     RowBuf[1+X*3+2]:=Palette[PalIdx].B;
    End;
   End;
  End;
  Move(RowBuf,RawBuf[RawLen],LongInt(ImageWidth)*3+1);
  Inc(RawLen,LongInt(ImageWidth)*3+1);
 End;
End;

Var
 IHDRData:Array[0..12]of Byte;
 ACTLData:Array[0..7]of Byte;
 FCTLData:Array[0..25]of Byte;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('BMP2APNG : Cette commande permet de convertir une image BitMap (.BMP) ',
                    'en format APNG (Animated Portable Network Graphics).');
  WriteLn;
  WriteLn('Syntaxe : BMP2APNG source.BMP [destination.APNG]');
  WriteLn;
  WriteLn(' source.BMP       Nom du fichier ".BMP" a convertir.');
  WriteLn(' destination.APNG Nom du fichier ".APNG" a creer.');
  WriteLn;
  WriteLn('Avec un seul BMP en entree, le fichier APNG produit contient une seule image.');
  WriteLn('Les BitMaps 1, 4, 8 ou 24 bits non compresses sont supportes.');
  Halt;
 End;
 If ParamCount<1 Then Begin
  WriteLn('Parametre requis !');
  Halt;
 End;

 SourceFileName:=ParamStr(1);
 If ParamCount>1 Then OutputName:=ParamStr(2)
                 Else OutputName:=Path2NameExt(SourceFileName);

 InitCRCTable;
 {$I-}Assign(SourceBMP,SourceFileName);
 Reset(SourceBMP,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de lire le fichier BMP : ',SourceFileName);
  Halt;
 End;

 BlockRead(SourceBMP,Header,SizeOf(Header),ByteReaded);
 If Header.Sign<>'BM'Then WriteError('Signature d''entete Bitmap introuvable !');
 Seek(SourceBMP,14);
 BlockRead(SourceBMP,BIH,SizeOf(BIH),ByteReaded);
 If(BIH.biBitCount<>1)and(BIH.biBitCount<>4)and(BIH.biBitCount<>8)
   and(BIH.biBitCount<>24)Then WriteError('Profondeur BMP non supportee !');
 If BIH.biCompression<>bi_RGB Then WriteError('Compression BMP non supportee !');
 If(BIH.biWidth<=0)or(BIH.biHeight<=0)Then WriteError('Dimensions BMP invalides !');
 If LongInt(BIH.biWidth)>MaxWidth Then WriteError('Image trop large !');

 If BIH.biSizeImage=0 Then Begin
  Case BIH.biBitCount of
   1:BMPBPL:=((LongInt(BIH.biWidth)+31)div 32)*4;
   4:BMPBPL:=((LongInt(BIH.biWidth)+7)div 8)*4;
   8:BMPBPL:=((LongInt(BIH.biWidth)+3)div 4)*4;
   24:BMPBPL:=((LongInt(BIH.biWidth)*3+3)div 4)*4;
   Else BMPBPL:=0;
  End;
 End
  Else
 BMPBPL:=LongInt(BIH.biSizeImage)div LongInt(BIH.biHeight);
 If(BMPBPL<=0)or(BMPBPL>SizeOf(BMPLine))Then WriteError('Largeur de l''image trop grande !');
 BMPBytesPerLine:=Word(BMPBPL);

 If(LongInt(BIH.biWidth)*3+1)*LongInt(BIH.biHeight)>SizeOf(RawBuf)Then
  WriteError('Image trop grande pour la conversion APNG en memoire !');

 If BIH.biBitCount<=8 Then Begin
  NumPal:=Word(BIH.biClrUsed);
  If NumPal=0 Then NumPal:=1 shl BIH.biBitCount;
  Seek(SourceBMP,14+SizeOf(BitmapInfoHeader));
  BlockRead(SourceBMP,Palette,LongInt(NumPal)*SizeOf(RGB32),ByteReaded);
 End;

 ImageWidth:=Word(BIH.biWidth);
 ImageHeight:=Word(BIH.biHeight);
 StartPos:=Header.OffBits;

 {$I-}Assign(DestAPNG,OutputName);
 Rewrite(DestAPNG,1);{$I+}
 If IOResult<>0 Then Begin
  Close(SourceBMP);
  WriteLn('Impossible de creer le fichier ',OutputName);
  Halt;
 End;
 TargetOpened:=True;

 BlockWrite(DestAPNG,PNGSignature,8,ByteWritten);

 PutBE32(IHDRData,0,ImageWidth);
 PutBE32(IHDRData,4,ImageHeight);
 IHDRData[8]:=8;
 IHDRData[9]:=2;
 IHDRData[10]:=0;
 IHDRData[11]:=0;
 IHDRData[12]:=0;
 WriteChunk('IHDR',IHDRData,13);

 PutBE32(ACTLData,0,1);
 PutBE32(ACTLData,4,0);
 WriteChunk('acTL',ACTLData,8);

 PutBE32(FCTLData,0,0);
 PutBE32(FCTLData,4,ImageWidth);
 PutBE32(FCTLData,8,ImageHeight);
 PutBE32(FCTLData,12,0);
 PutBE32(FCTLData,16,0);
 PutBE16(FCTLData,20,1);
 PutBE16(FCTLData,22,10);
 FCTLData[24]:=0;
 FCTLData[25]:=0;
 WriteChunk('fcTL',FCTLData,26);

 BuildRawImage;
 BuildIDAT;
 WriteChunk('IDAT',IDATBuf,IDATLen);

 ByteV:=0;
 WriteChunk('IEND',ByteV,0);

 Close(DestAPNG);
 TargetOpened:=False;
 Close(SourceBMP);
 WriteLn('Fichier APNG cree : ',OutputName);
END.
