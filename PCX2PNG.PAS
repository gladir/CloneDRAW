{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2PNG;

{$A-}

Uses DOS;

Const
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;
 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;
 PNGSignature:Array[0..7]of Byte=(137,80,78,71,13,10,26,10);
 MaxStoredBlock=65535;

Type
 RGB=Record
  R,G,B:Byte;
 End;

 HeaderPCX=Record
  Manufacturer:Byte;
  Version:Byte;
  Encoding:Byte;
  BitsPerPixel:Byte;
  Xmin,Ymin,Xmax,Ymax:Word;
  HDpi,VDpi:Word;
  ColorMap:Array[0..47]of Byte;
  Reserved1:Byte;
  NPlanes:Byte;
  BytesPerLine:Word;
  PaletteInfo:Word;
  HscreenSize:Word;
  VscreenSize:Word;
  Filler:Array[0..53]of Byte;
 End;

Var
 SourcePCX,DestPNG:File;
 PCXHeader:HeaderPCX;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 RowBuf:Array[0..MaxWidth*3]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 TargetOpened:Boolean;
 CRCTable:Array[0..255]of LongInt;
 Adler_A,Adler_B:LongInt;
 X:Word;
 Y:LongInt;

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
 Path2NameExt:=D+N+'.PNG';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestPNG);
 Halt;
End;

Function PCXBitsPerPixel:Word;
Begin
 If(PCXHeader.BitsPerPixel=1)and(PCXHeader.NPlanes=1)Then PCXBitsPerPixel:=1
 Else If(PCXHeader.BitsPerPixel=1)and(PCXHeader.NPlanes=4)Then PCXBitsPerPixel:=4
 Else If(PCXHeader.BitsPerPixel=8)and(PCXHeader.NPlanes=1)Then PCXBitsPerPixel:=8
 Else If(PCXHeader.BitsPerPixel=8)and(PCXHeader.NPlanes=3)Then PCXBitsPerPixel:=24
 Else PCXBitsPerPixel:=0;
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
 BlockWrite(DestPNG,B,4,ByteWritten);
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
 BlockWrite(DestPNG,TypeBuf,4,ByteWritten);
 If Len>0 Then BlockWrite(DestPNG,Data,Len,ByteWritten);
 CRC:=StartCRC;
 CRC:=UpdateCRC(CRC,TypeBuf,4);
 If Len>0 Then CRC:=UpdateCRC(CRC,Data,Len);
 CRC:=FinishCRC(CRC);
 WriteBE32(CRC);
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
 While Pos<RawLen Do Begin
  Remain:=RawLen-Pos;
  If Remain>MaxStoredBlock Then BlockLen:=MaxStoredBlock
                           Else BlockLen:=Remain;
  If(Pos+BlockLen)>=RawLen Then IsLast:=1 Else IsLast:=0;
  IDATBuf[IDATLen]:=IsLast; Inc(IDATLen);
  IDATBuf[IDATLen]:=Byte(BlockLen and $FF); Inc(IDATLen);
  IDATBuf[IDATLen]:=Byte((BlockLen shr 8)and $FF); Inc(IDATLen);
  IDATBuf[IDATLen]:=Byte((not BlockLen)and $FF); Inc(IDATLen);
  IDATBuf[IDATLen]:=Byte(((not BlockLen)shr 8)and $FF); Inc(IDATLen);
  Move(RawBuf[Pos],IDATBuf[IDATLen],BlockLen);
  UpdateAdler(RawBuf[Pos],BlockLen);
  Inc(IDATLen,BlockLen);
  Inc(Pos,BlockLen);
 End;
 Adler:=GetAdler32;
 IDATBuf[IDATLen]:=Byte((Adler shr 24)and $FF); Inc(IDATLen);
 IDATBuf[IDATLen]:=Byte((Adler shr 16)and $FF); Inc(IDATLen);
 IDATBuf[IDATLen]:=Byte((Adler shr  8)and $FF); Inc(IDATLen);
 IDATBuf[IDATLen]:=Byte( Adler         and $FF); Inc(IDATLen);
End;

Procedure LoadPCXPalette;
Var
 I:Integer;
 Marker:Byte;
 PosPal:LongInt;
 R,G,B:Byte;
Begin
 FillChar(Palette,SizeOf(Palette),0);
 NumPal:=0;
 Case PCXBitsPerPixel of
  1:NumPal:=2;
  4:NumPal:=16;
  8:NumPal:=256;
 End;

 If(PCXBitsPerPixel=1)or(PCXBitsPerPixel=4)Then Begin
  For I:=0 to NumPal-1 Do Begin
   Palette[I].R:=PCXHeader.ColorMap[I*3+0];
   Palette[I].G:=PCXHeader.ColorMap[I*3+1];
   Palette[I].B:=PCXHeader.ColorMap[I*3+2];
  End;
 End
  Else
 If PCXBitsPerPixel=8 Then Begin
  If FileSize(SourcePCX)<(128+769)Then WriteError('Palette VGA PCX introuvable !');
  PosPal:=FileSize(SourcePCX)-769;
  Seek(SourcePCX,PosPal);
  BlockRead(SourcePCX,Marker,1,ByteReaded);
  If Marker<>PCXVGAPaletteMarker Then WriteError('Marqueur de palette VGA PCX introuvable !');
  For I:=0 to 255 Do Begin
   BlockRead(SourcePCX,R,1,ByteReaded);
   BlockRead(SourcePCX,G,1,ByteReaded);
   BlockRead(SourcePCX,B,1,ByteReaded);
   Palette[I].R:=R;
   Palette[I].G:=G;
   Palette[I].B:=B;
  End;
 End;
 Seek(SourcePCX,SizeOf(PCXHeader));
End;

Procedure DecodePCXScanLine;
Var
 P:Word;
 B,Value,Count:Byte;
 I:Byte;
Begin
 P:=0;
 While P<PCXLineSize Do Begin
  BlockRead(SourcePCX,B,1,ByteReaded);
  If ByteReaded<>1 Then WriteError('Lecture incomplete des donnees PCX !');
  If(B and $C0)=$C0 Then Begin
   Count:=B and $3F;
   BlockRead(SourcePCX,Value,1,ByteReaded);
   If ByteReaded<>1 Then WriteError('Lecture incomplete des donnees PCX !');
  End
   Else
  Begin
   Count:=1;
   Value:=B;
  End;
  For I:=1 to Count Do Begin
   If P<PCXLineSize Then Begin
    ScanLine[P]:=Value;
    Inc(P);
   End;
  End;
 End;
End;

Function GetPlaneBit(Plane:Byte;X:Word):Byte;
Var
 Offset:Word;
Begin
 Offset:=Word(Plane)*PCXHeader.BytesPerLine+(X shr 3);
 GetPlaneBit:=(ScanLine[Offset] shr (7-(X and 7)))and 1;
End;

Function GetPalIndex(X:Word):Byte;
Begin
 Case PCXBitsPerPixel of
  1:GetPalIndex:=GetPlaneBit(0,X);
  4:GetPalIndex:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
                 (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
  8:GetPalIndex:=ScanLine[X];
  Else GetPalIndex:=0;
 End;
End;

Procedure BuildPNGRow;
Var
 Index:Byte;
Begin
 RowBuf[0]:=0;
 Case PCXBitsPerPixel of
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    RowBuf[1+X*3+0]:=ScanLine[X];
    RowBuf[1+X*3+1]:=ScanLine[PCXHeader.BytesPerLine+X];
    RowBuf[1+X*3+2]:=ScanLine[Word(PCXHeader.BytesPerLine)*2+X];
   End;
  End;
  Else Begin
   For X:=0 to ImageWidth-1 Do Begin
    Index:=GetPalIndex(X);
    RowBuf[1+X*3+0]:=Palette[Index].R;
    RowBuf[1+X*3+1]:=Palette[Index].G;
    RowBuf[1+X*3+2]:=Palette[Index].B;
   End;
  End;
 End;
End;

Var
 IHDRData:Array[0..12]of Byte;
 Dummy:Byte;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2PNG : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en format PNG (.PNG, Portable Network Graphics).');
  WriteLn;
  WriteLn('Syntaxe : PCX2PNG source.PCX [destination.PNG]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.PNG Ce parametre permet d''indiquer le nom du fichier ".PNG".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .PNG.');
  WriteLn('La sortie PNG est encodee en couleurs vraies RGB 8 bits par canal.');
  WriteLn('Les PCX RLE 1, 4, 8 et 24 bits sont supportes.');
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
 {$I-}Assign(SourcePCX,SourceFileName);
 Reset(SourcePCX,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de lire le fichier PCX : ',SourceFileName);
  Halt;
 End;

 BlockRead(SourcePCX,PCXHeader,SizeOf(PCXHeader),ByteReaded);
 If ByteReaded<>SizeOf(PCXHeader) Then WriteError('Entete PCX incomplet !');
 If PCXHeader.Manufacturer<>PCXManufacturer Then WriteError('Signature d''entete PCX introuvable !');
 If PCXHeader.Encoding<>PCXEncodingRLE Then WriteError('Seul l''encodage RLE PCX est supporte !');
 If PCXBitsPerPixel=0 Then WriteError('Profondeur PCX non supportee !');
 If(PCXHeader.Xmax<PCXHeader.Xmin)or(PCXHeader.Ymax<PCXHeader.Ymin)Then
  WriteError('Dimensions PCX invalides !');

 ImageWidth:=PCXHeader.Xmax-PCXHeader.Xmin+1;
 ImageHeight:=PCXHeader.Ymax-PCXHeader.Ymin+1;
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');
 If(LongInt(ImageWidth)*3+1)*LongInt(ImageHeight)>SizeOf(RawBuf)Then
  WriteError('Image trop grande pour la conversion PNG en memoire !');
 LoadPCXPalette;

 {$I-}Assign(DestPNG,OutputName);
 Rewrite(DestPNG,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 BlockWrite(DestPNG,PNGSignature,8,ByteWritten);

 IHDRData[0]:=Byte((LongInt(ImageWidth) shr 24)and $FF);
 IHDRData[1]:=Byte((LongInt(ImageWidth) shr 16)and $FF);
 IHDRData[2]:=Byte((LongInt(ImageWidth) shr  8)and $FF);
 IHDRData[3]:=Byte( LongInt(ImageWidth)         and $FF);
 IHDRData[4]:=Byte((LongInt(ImageHeight)shr 24)and $FF);
 IHDRData[5]:=Byte((LongInt(ImageHeight)shr 16)and $FF);
 IHDRData[6]:=Byte((LongInt(ImageHeight)shr  8)and $FF);
 IHDRData[7]:=Byte( LongInt(ImageHeight)        and $FF);
 IHDRData[8]:=8;
 IHDRData[9]:=2;
 IHDRData[10]:=0;
 IHDRData[11]:=0;
 IHDRData[12]:=0;
 WriteChunk('IHDR',IHDRData,13);

 RawLen:=0;
 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildPNGRow;
  Move(RowBuf,RawBuf[RawLen],LongInt(ImageWidth)*3+1);
  Inc(RawLen,LongInt(ImageWidth)*3+1);
 End;

 BuildIDAT;
 WriteChunk('IDAT',IDATBuf,IDATLen);

 Dummy:=0;
 WriteChunk('IEND',Dummy,0);

 Close(DestPNG);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier PNG cree : ',OutputName);
END.
