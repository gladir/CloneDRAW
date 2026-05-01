{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2ICO;

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
 RGB=Record
  R,G,B:Byte;
 End;

 RGB32=Record
  B,G,R,FreeByte:Byte;
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

 IconDir=Record
  idReserved:Word;
  idType:Word;
  idCount:Word;
 End;

 IconDirEntry=Record
  bWidth:Byte;
  bHeight:Byte;
  bColorCount:Byte;
  bReserved:Byte;
  wPlanes:Word;
  wBitCount:Word;
  dwBytesInRes:LongInt;
  dwImageOffset:LongInt;
 End;

Var
 SourcePCX,DestICO:File;
 PCXHeader:HeaderPCX;
 DIBHeader:BitmapInfoHeader;
 IcoDirRec:IconDir;
 IcoEntry:IconDirEntry;
 Palette:Array[0..255]of RGB;
 DIBPalette:Array[0..255]of RGB32;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 XORLine:Array[0..MaxLineBytes-1]of Byte;
 ANDLine:Array[0..(MaxWidth div 8)+3]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 XORStride,ANDStride,PaletteBytes,DIBSize:LongInt;
 XOROffset,ANDOffset:LongInt;
 TargetOpened:Boolean;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.ICO';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestICO);
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

Procedure LoadPCXPalette;
Var
 I:Integer;
 Marker:Byte;
 PosPal:LongInt;
 R,G,B:Byte;
Begin
 FillChar(Palette,SizeOf(Palette),0);
 FillChar(DIBPalette,SizeOf(DIBPalette),0);
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

 For I:=0 to NumPal-1 Do Begin
  DIBPalette[I].B:=Palette[I].B;
  DIBPalette[I].G:=Palette[I].G;
  DIBPalette[I].R:=Palette[I].R;
  DIBPalette[I].FreeByte:=0;
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

Procedure BuildXORLine;
Var
 X:Word;
 Index:Byte;
Begin
 FillChar(XORLine,XORStride,0);
 Case PCXBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do
    If GetPlaneBit(0,X)<>0 Then
     XORLine[X shr 3]:=XORLine[X shr 3]or Byte($80 shr (X and 7));
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Index:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
           (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
    If(X and 1)=0 Then XORLine[X shr 1]:=Index shl 4
                  Else XORLine[X shr 1]:=XORLine[X shr 1]or Index;
   End;
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do XORLine[X]:=ScanLine[X];
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    XORLine[X*3+0]:=ScanLine[Word(PCXHeader.BytesPerLine)*2+X]; { B }
    XORLine[X*3+1]:=ScanLine[PCXHeader.BytesPerLine+X];         { G }
    XORLine[X*3+2]:=ScanLine[X];                                { R }
   End;
  End;
 End;
End;

Procedure ShowHelp;
Begin
 WriteLn('PCX2ICO : Cette commande permet de convertir une image PCX (.PCX) ',
                   'en ressource icone Windows (.ICO).');
 WriteLn;
 WriteLn('Syntaxe : PCX2ICO source.PCX [destination.ICO]');
 WriteLn;
 WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
 WriteLn(' destination.ICO Ce parametre permet d''indiquer le nom du fichier ".ICO".');
 WriteLn;
 WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .ICO.');
 WriteLn('Les PCX RLE 1 bit, 16 couleurs, 256 couleurs et 24 bits sont supportes.');
 WriteLn('Le masque de transparence (AND) est rempli a zero : tous les pixels sont opaques.');
 Halt;
End;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then ShowHelp;
 If ParamCount<1 Then Begin
  WriteLn('Parametre requis !');
  Halt;
 End;

 SourceFileName:=ParamStr(1);
 If ParamCount>1 Then OutputName:=ParamStr(2)
                 Else OutputName:=Path2NameExt(SourceFileName);

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
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)or(ImageHeight>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');

 LoadPCXPalette;

 XORStride:=((LongInt(ImageWidth)*LongInt(PCXBitsPerPixel)+31)div 32)*4;
 ANDStride:=((LongInt(ImageWidth)+31)div 32)*4;
 If(XORStride<=0)or(XORStride>SizeOf(XORLine))Then WriteError('Ligne XOR trop large !');
 If(ANDStride<=0)or(ANDStride>SizeOf(ANDLine))Then WriteError('Ligne AND trop large !');
 PaletteBytes:=LongInt(NumPal)*SizeOf(RGB32);
 DIBSize:=SizeOf(BitmapInfoHeader)+PaletteBytes+
          XORStride*LongInt(ImageHeight)+ANDStride*LongInt(ImageHeight);

 {$I-}Assign(DestICO,OutputName);
 Rewrite(DestICO,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 IcoDirRec.idReserved:=0;
 IcoDirRec.idType:=1;
 IcoDirRec.idCount:=1;
 BlockWrite(DestICO,IcoDirRec,SizeOf(IcoDirRec),ByteWritten);

 If ImageWidth>=256 Then IcoEntry.bWidth:=0
                    Else IcoEntry.bWidth:=Byte(ImageWidth);
 If ImageHeight>=256 Then IcoEntry.bHeight:=0
                     Else IcoEntry.bHeight:=Byte(ImageHeight);
 Case PCXBitsPerPixel of
  1:IcoEntry.bColorCount:=2;
  4:IcoEntry.bColorCount:=16;
  Else IcoEntry.bColorCount:=0;
 End;
 IcoEntry.bReserved:=0;
 IcoEntry.wPlanes:=1;
 IcoEntry.wBitCount:=PCXBitsPerPixel;
 IcoEntry.dwBytesInRes:=DIBSize;
 IcoEntry.dwImageOffset:=SizeOf(IcoDirRec)+SizeOf(IcoEntry);
 BlockWrite(DestICO,IcoEntry,SizeOf(IcoEntry),ByteWritten);

 FillChar(DIBHeader,SizeOf(DIBHeader),0);
 DIBHeader.biSize:=SizeOf(BitmapInfoHeader);
 DIBHeader.biWidth:=ImageWidth;
 DIBHeader.biHeight:=LongInt(ImageHeight)*2;
 DIBHeader.biPlanes:=1;
 DIBHeader.biBitCount:=PCXBitsPerPixel;
 DIBHeader.biCompression:=bi_RGB;
 DIBHeader.biSizeImage:=XORStride*LongInt(ImageHeight)+
                        ANDStride*LongInt(ImageHeight);
 DIBHeader.biXPelsPerMeter:=0;
 DIBHeader.biYPelsPerMeter:=0;
 DIBHeader.biClrUsed:=0;
 DIBHeader.biClrImportant:=0;
 BlockWrite(DestICO,DIBHeader,SizeOf(DIBHeader),ByteWritten);

 If PaletteBytes>0 Then BlockWrite(DestICO,DIBPalette,PaletteBytes,ByteWritten);

 XOROffset:=IcoEntry.dwImageOffset+SizeOf(BitmapInfoHeader)+PaletteBytes;
 ANDOffset:=XOROffset+XORStride*LongInt(ImageHeight);

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildXORLine;
  Seek(DestICO,XOROffset+(LongInt(ImageHeight)-1-Y)*XORStride);
  BlockWrite(DestICO,XORLine,XORStride,ByteWritten);
 End;

 FillChar(ANDLine,SizeOf(ANDLine),0);
 For Y:=0 to ImageHeight-1 Do Begin
  Seek(DestICO,ANDOffset+Y*ANDStride);
  BlockWrite(DestICO,ANDLine,ANDStride,ByteWritten);
 End;

 Close(DestICO);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier ICO cree : ',OutputName);
END.
