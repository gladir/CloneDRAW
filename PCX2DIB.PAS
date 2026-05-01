{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2DIB;

{$A-}

Uses DOS;

Const
 bi_RGB=0;
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;
 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

Type
 RGB32=Record
  B,G,R,FreeByte:Byte;
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
 SourcePCX,TargetDIB:File;
 PCXHeader:HeaderPCX;
 DIBHeader:BitmapInfoHeader;
 Palette:Array[0..255]of RGB32;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 DIBLine:Array[0..MaxLineBytes-1]of Byte;
 SourceFileName,TargetFileName:String;
 ImageWidth,ImageHeight,PCXLineSize,DIBBytesPerLine,NumPal:Word;
 ByteReaded,ByteWritten:Word;
 ImageSize,PaletteSize:LongInt;
 PaletteWriteSize:Word;
 TargetOpened:Boolean;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.DIB';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(TargetDIB);
 Halt;
End;

Function DIBBitsPerPixel:Word;
Begin
 If(PCXHeader.BitsPerPixel=1)and(PCXHeader.NPlanes=1)Then DIBBitsPerPixel:=1
 Else If(PCXHeader.BitsPerPixel=1)and(PCXHeader.NPlanes=4)Then DIBBitsPerPixel:=4
 Else If(PCXHeader.BitsPerPixel=8)and(PCXHeader.NPlanes=1)Then DIBBitsPerPixel:=8
 Else If(PCXHeader.BitsPerPixel=8)and(PCXHeader.NPlanes=3)Then DIBBitsPerPixel:=24
 Else DIBBitsPerPixel:=0;
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
 Case DIBBitsPerPixel of
  1:NumPal:=2;
  4:NumPal:=16;
  8:NumPal:=256;
 End;

 If(DIBBitsPerPixel=1)or(DIBBitsPerPixel=4)Then Begin
  For I:=0 to NumPal-1 Do Begin
   Palette[I].R:=PCXHeader.ColorMap[I*3+0];
   Palette[I].G:=PCXHeader.ColorMap[I*3+1];
   Palette[I].B:=PCXHeader.ColorMap[I*3+2];
   Palette[I].FreeByte:=0;
  End;
 End
  Else
 If DIBBitsPerPixel=8 Then Begin
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

Procedure BuildDIBLine;
Var
 X:Word;
 Index:Byte;
Begin
 FillChar(DIBLine,DIBBytesPerLine,0);
 Case DIBBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do
    If GetPlaneBit(0,X)<>0 Then
     DIBLine[X shr 3]:=DIBLine[X shr 3]or Byte($80 shr (X and 7));
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Index:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
           (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
    If(X and 1)=0 Then DIBLine[X shr 1]:=Index shl 4
                  Else DIBLine[X shr 1]:=DIBLine[X shr 1]or Index;
   End;
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do DIBLine[X]:=ScanLine[X];
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    DIBLine[X*3+2]:=ScanLine[X]; { R }
    DIBLine[X*3+1]:=ScanLine[PCXHeader.BytesPerLine+X]; { G }
    DIBLine[X*3+0]:=ScanLine[Word(PCXHeader.BytesPerLine)*2+X]; { B }
   End;
  End;
 End;
End;

Procedure WriteDIBHeader;
Begin
 FillChar(DIBHeader,SizeOf(DIBHeader),0);
 DIBHeader.biSize:=SizeOf(BitmapInfoHeader);
 DIBHeader.biWidth:=ImageWidth;
 DIBHeader.biHeight:=ImageHeight;
 DIBHeader.biPlanes:=1;
 DIBHeader.biBitCount:=DIBBitsPerPixel;
 DIBHeader.biCompression:=bi_RGB;
 DIBHeader.biSizeImage:=ImageSize;
 DIBHeader.biXPelsPerMeter:=0;
 DIBHeader.biYPelsPerMeter:=0;
 DIBHeader.biClrUsed:=NumPal;
 DIBHeader.biClrImportant:=NumPal;
 BlockWrite(TargetDIB,DIBHeader,SizeOf(DIBHeader),ByteWritten);
 If ByteWritten<>SizeOf(DIBHeader) Then WriteError('Impossible d''ecrire l''entete DIB !');
 If NumPal>0 Then Begin
  BlockWrite(TargetDIB,Palette,PaletteWriteSize,ByteWritten);
  If ByteWritten<>PaletteWriteSize Then WriteError('Impossible d''ecrire la palette DIB !');
 End;
End;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2DIB : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en fichier Device-Independent Bitmap (.DIB).');
  WriteLn;
  WriteLn('Syntaxe : PCX2DIB source.PCX [destination.DIB]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.DIB Ce parametre permet d''indiquer le nom du fichier ".DIB".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .DIB.');
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
 If ByteReaded<>SizeOf(PCXHeader) Then WriteError('Entete PCX incomplet !');
 If PCXHeader.Manufacturer<>PCXManufacturer Then WriteError('Signature d''entete PCX introuvable !');
 If PCXHeader.Encoding<>PCXEncodingRLE Then WriteError('Seul l''encodage RLE PCX est supporte !');
 If DIBBitsPerPixel=0 Then WriteError('Profondeur PCX non supportee !');
 If(PCXHeader.Xmax<PCXHeader.Xmin)or(PCXHeader.Ymax<PCXHeader.Ymin)Then
  WriteError('Dimensions PCX invalides !');

 ImageWidth:=PCXHeader.Xmax-PCXHeader.Xmin+1;
 ImageHeight:=PCXHeader.Ymax-PCXHeader.Ymin+1;
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');
 DIBBytesPerLine:=Word(((LongInt(ImageWidth)*LongInt(DIBBitsPerPixel)+31)div 32)*4);
 If(DIBBytesPerLine=0)or(DIBBytesPerLine>SizeOf(DIBLine))Then WriteError('Ligne DIB trop large !');

 LoadPCXPalette;
 PaletteSize:=LongInt(NumPal)*4;
 PaletteWriteSize:=Word(PaletteSize);
 ImageSize:=LongInt(DIBBytesPerLine)*LongInt(ImageHeight);

 {$I-}Assign(TargetDIB,TargetFileName);
 Rewrite(TargetDIB,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible d''ecrire le fichier DIB : ',TargetFileName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 WriteDIBHeader;

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildDIBLine;
  Seek(TargetDIB,SizeOf(BitmapInfoHeader)+PaletteSize+
       (LongInt(ImageHeight)-1-Y)*LongInt(DIBBytesPerLine));
  BlockWrite(TargetDIB,DIBLine,DIBBytesPerLine,ByteWritten);
  If ByteWritten<>DIBBytesPerLine Then WriteError('Impossible d''ecrire une ligne DIB !');
 End;

 Close(TargetDIB);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier DIB cree : ',TargetFileName);
END.
