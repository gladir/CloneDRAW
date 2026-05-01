{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2BMP;

{$A-}

Uses DOS;

Const
  {Type de compression Windows}
 bi_RGB=0;

  {Constantes du format PCX (ZSoft Picture eXchange).}
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;

 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

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

  {En-tete PCX : 128 octets, ordre Intel.}
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
 SourcePCX,TargetBMP:File;
 PCXHeader:HeaderPCX;
 BMPHeader:HeaderBMP;
 Palette:Array[0..255]of RGB32;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 BMPLine:Array[0..MaxLineBytes-1]of Byte;
 SourceFileName,TargetFileName:String;
 ImageWidth,ImageHeight:Word;
 BMPBytesPerLine,PCXLineSize,NumPal:Word;
 ByteReaded,ByteWritten:Word;
 ImageSize,PaletteSize:LongInt;
 PaletteWriteSize:Word;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.BMP';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 Close(TargetBMP);
 Halt;
End;

Function BMPBitsPerPixel:Word;
Begin
 If(PCXHeader.BitsPerPixel=1)and(PCXHeader.NPlanes=1)Then BMPBitsPerPixel:=1
 Else If(PCXHeader.BitsPerPixel=1)and(PCXHeader.NPlanes=4)Then BMPBitsPerPixel:=4
 Else If(PCXHeader.BitsPerPixel=8)and(PCXHeader.NPlanes=1)Then BMPBitsPerPixel:=8
 Else If(PCXHeader.BitsPerPixel=8)and(PCXHeader.NPlanes=3)Then BMPBitsPerPixel:=24
 Else BMPBitsPerPixel:=0;
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
 Case BMPBitsPerPixel of
  1:NumPal:=2;
  4:NumPal:=16;
  8:NumPal:=256;
 End;

 If(BMPBitsPerPixel=1)or(BMPBitsPerPixel=4)Then Begin
  For I:=0 to NumPal-1 Do Begin
   Palette[I].R:=PCXHeader.ColorMap[I*3+0];
   Palette[I].G:=PCXHeader.ColorMap[I*3+1];
   Palette[I].B:=PCXHeader.ColorMap[I*3+2];
   Palette[I].FreeByte:=0;
  End;
 End
  Else
 If BMPBitsPerPixel=8 Then Begin
  If FileSize(SourcePCX)<(128+769)Then Begin
   WriteLn('Palette VGA PCX introuvable !');
   Close(SourcePCX);
   Halt;
  End;
  PosPal:=FileSize(SourcePCX)-769;
  Seek(SourcePCX,PosPal);
  BlockRead(SourcePCX,Marker,1,ByteReaded);
  If Marker<>PCXVGAPaletteMarker Then Begin
   WriteLn('Marqueur de palette VGA PCX introuvable !');
   Close(SourcePCX);
   Halt;
  End;
  For I:=0 to 255 Do Begin
   BlockRead(SourcePCX,R,1,ByteReaded);
   BlockRead(SourcePCX,G,1,ByteReaded);
   BlockRead(SourcePCX,B,1,ByteReaded);
   Palette[I].R:=R;
   Palette[I].G:=G;
   Palette[I].B:=B;
   Palette[I].FreeByte:=0;
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

Procedure BuildBMPLine;
Var
 X:Word;
 Index:Byte;
Begin
 FillChar(BMPLine,BMPBytesPerLine,0);
 Case BMPBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do Begin
    If GetPlaneBit(0,X)<>0 Then
     BMPLine[X shr 3]:=BMPLine[X shr 3]or Byte($80 shr (X and 7));
   End;
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Index:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
           (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
    If(X and 1)=0 Then BMPLine[X shr 1]:=Index shl 4
                  Else BMPLine[X shr 1]:=BMPLine[X shr 1]or Index;
   End;
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do BMPLine[X]:=ScanLine[X];
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    BMPLine[X*3+2]:=ScanLine[X]; { R }
    BMPLine[X*3+1]:=ScanLine[PCXHeader.BytesPerLine+X]; { G }
    BMPLine[X*3+0]:=ScanLine[Word(PCXHeader.BytesPerLine)*2+X]; { B }
   End;
  End;
 End;
End;

Procedure WriteBMPHeaders;
Begin
 FillChar(BMPHeader,SizeOf(BMPHeader),0);
 BMPHeader.Sign:='BM';
 BMPHeader.Size:=14+40+PaletteSize+ImageSize;
 BMPHeader.Reserved0:=0;
 BMPHeader.OffBits:=14+40+PaletteSize;
 BMPHeader.biSize:=40;
 BMPHeader.NumXPixels:=ImageWidth;
 BMPHeader.NumYPixels:=ImageHeight;
 BMPHeader.Planes:=1;
 BMPHeader.BitCount:=BMPBitsPerPixel;
 BMPHeader.Compression:=bi_RGB;
 BMPHeader.SizeImage:=ImageSize;
 BMPHeader.XPelsPerMeter:=0;
 BMPHeader.YPelsPerMeter:=0;
 BMPHeader.ClrUsed:=NumPal;
 BMPHeader.ClrImportant:=NumPal;
 BlockWrite(TargetBMP,BMPHeader,SizeOf(BMPHeader),ByteWritten);
 If ByteWritten<>SizeOf(BMPHeader) Then WriteError('Impossible d''ecrire l''entete BMP !');
 If NumPal>0 Then Begin
  BlockWrite(TargetBMP,Palette,PaletteWriteSize,ByteWritten);
  If ByteWritten<>PaletteWriteSize Then WriteError('Impossible d''ecrire la palette BMP !');
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2BMP : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en fichier BitMap (.BMP).');
  WriteLn;
  WriteLn('Syntaxe : PCX2BMP source.PCX [destination.BMP]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.BMP Ce parametre permet d''indiquer le nom du fichier ".BMP".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .BMP.');
  WriteLn('Les PCX RLE 1 bit, 16 couleurs, 256 couleurs et 24 bits sont supportes.');
  Halt;
 End;
 If ParamCount<1 Then Begin
  WriteLn('Parametre requis !');
  Halt;
 End;

 SourceFileName:=ParamStr(1);
 If ParamCount>1 Then TargetFileName:=ParamStr(2)
                 Else TargetFileName:=Path2NameExt(SourceFileName);

 {$I-}Assign(SourcePCX,SourceFileName);
 Reset(SourcePCX,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de lire le fichier PCX : ',SourceFileName);
  Halt;
 End;

 BlockRead(SourcePCX,PCXHeader,SizeOf(PCXHeader),ByteReaded);
 If ByteReaded<>SizeOf(PCXHeader) Then Begin
  WriteLn('Entete PCX incomplet !');
  Close(SourcePCX);
  Halt;
 End;
 If PCXHeader.Manufacturer<>PCXManufacturer Then Begin
  WriteLn('Signature d''entete PCX introuvable !');
  Close(SourcePCX);
  Halt;
 End;
 If PCXHeader.Encoding<>PCXEncodingRLE Then Begin
  WriteLn('Seul l''encodage RLE PCX est supporte !');
  Close(SourcePCX);
  Halt(3);
 End;
 If BMPBitsPerPixel=0 Then Begin
  WriteLn('Profondeur PCX non supportee !');
  Close(SourcePCX);
  Halt(2);
 End;

 If(PCXHeader.Xmax<PCXHeader.Xmin)or(PCXHeader.Ymax<PCXHeader.Ymin)Then Begin
  WriteLn('Dimensions PCX invalides !');
  Close(SourcePCX);
  Halt;
 End;
 ImageWidth:=PCXHeader.Xmax-PCXHeader.Xmin+1;
 ImageHeight:=PCXHeader.Ymax-PCXHeader.Ymin+1;
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then Begin
  WriteLn('Dimensions PCX invalides ou trop larges !');
  Close(SourcePCX);
  Halt;
 End;

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then Begin
  WriteLn('Ligne PCX trop large !');
  Close(SourcePCX);
  Halt;
 End;
 BMPBytesPerLine:=Word(((LongInt(ImageWidth)*LongInt(BMPBitsPerPixel)+31)div 32)*4);
 If(BMPBytesPerLine=0)or(BMPBytesPerLine>SizeOf(BMPLine))Then Begin
  WriteLn('Ligne BMP trop large !');
  Close(SourcePCX);
  Halt;
 End;

 LoadPCXPalette;
 PaletteSize:=LongInt(NumPal)*4;
 PaletteWriteSize:=Word(PaletteSize);
 ImageSize:=LongInt(BMPBytesPerLine)*LongInt(ImageHeight);

 {$I-}Assign(TargetBMP,TargetFileName);
 Rewrite(TargetBMP,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible d''ecrire le fichier BMP : ',TargetFileName);
  Close(SourcePCX);
  Halt;
 End;

 WriteBMPHeaders;

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildBMPLine;
  Seek(TargetBMP,BMPHeader.OffBits+(LongInt(ImageHeight)-1-Y)*LongInt(BMPBytesPerLine));
  BlockWrite(TargetBMP,BMPLine,BMPBytesPerLine,ByteWritten);
  If ByteWritten<>BMPBytesPerLine Then WriteError('Impossible d''ecrire une ligne BMP !');
 End;

 Close(SourcePCX);
 Close(TargetBMP);
 WriteLn('Fichier BMP cree : ',TargetFileName);
END.
