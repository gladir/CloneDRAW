{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2TIFF;

{$A-}

Uses DOS;

Const
  {Constantes du format PCX (ZSoft Picture eXchange).}
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;

  {Constantes du format TIFF (TIFF 6.0 baseline, octet de poids faible
   en premier - "Intel byte order").}
 TiffByteOrder=$4949;
 TiffMagic=42;
 TiffNoCompression=1;
 TiffPhotoRGB=2;
 TiffPhotoPalette=3;
 TiffResolutionInch=2;

  {Codes de type de donnees TIFF}
 TiffTypeShort=3;
 TiffTypeLong=4;
 TiffTypeRational=5;

  {Identificateurs (tags) TIFF utilises}
 TagImageWidth=256;
 TagImageLength=257;
 TagBitsPerSample=258;
 TagCompression=259;
 TagPhotometric=262;
 TagStripOffsets=273;
 TagSamplesPerPixel=277;
 TagRowsPerStrip=278;
 TagStripByteCounts=279;
 TagXResolution=282;
 TagYResolution=283;
 TagResolutionUnit=296;
 TagColorMap=320;

 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

Type
 RGB=Record
  R,G,B:Byte;
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
 SourcePCX,DestTIFF:File;
 PCXHeader:HeaderPCX;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 TiffLine:Array[0..MaxLineBytes-1]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight:Word;
 PCXLineSize,TiffBytesPerLine,ByteReaded,ByteWritten:Word;
 NumPal:Word;
 TargetOpened:Boolean;
 NumEntries:Word;
 IsPalette:Boolean;
 SamplesPerPixel:Word;
 BitsPerSample:Word;
 Photometric:Word;
 PaletteSize:Word;
 ExternalStart:LongInt;
 XResOffset,YResOffset:LongInt;
 BitsPerSampleOffset:LongInt;
 ColorMapOffset:LongInt;
 StripOffset:LongInt;
 StripByteCount:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.TIF';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestTIFF);
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

Procedure WriteByteToFile(B:Byte);
Begin
 BlockWrite(DestTIFF,B,1,ByteWritten);
End;

Procedure WriteWordToFile(W:Word);
Var
 Tmp:Array[0..1]of Byte;
Begin
 Tmp[0]:=Byte(W and $FF);
 Tmp[1]:=Byte((W shr 8)and $FF);
 BlockWrite(DestTIFF,Tmp,2,ByteWritten);
End;

Procedure WriteLongToFile(L:LongInt);
Var
 Tmp:Array[0..3]of Byte;
Begin
 Tmp[0]:=Byte(L and $FF);
 Tmp[1]:=Byte((L shr 8)and $FF);
 Tmp[2]:=Byte((L shr 16)and $FF);
 Tmp[3]:=Byte((L shr 24)and $FF);
 BlockWrite(DestTIFF,Tmp,4,ByteWritten);
End;

Procedure WriteIFDEntry(Tag,FType:Word;Count,Value:LongInt);
Begin
 WriteWordToFile(Tag);
 WriteWordToFile(FType);
 WriteLongToFile(Count);
 WriteLongToFile(Value);
End;

Procedure WriteRational(Numerator,Denominator:LongInt);
Begin
 WriteLongToFile(Numerator);
 WriteLongToFile(Denominator);
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

Procedure BuildTiffLine;
Var
 X:Word;
 Index:Byte;
Begin
 FillChar(TiffLine,TiffBytesPerLine,0);
 Case PCXBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do
    If GetPlaneBit(0,X)<>0 Then
     TiffLine[X shr 3]:=TiffLine[X shr 3]or Byte($80 shr (X and 7));
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Index:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
           (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
    If(X and 1)=0 Then TiffLine[X shr 1]:=Index shl 4
                  Else TiffLine[X shr 1]:=TiffLine[X shr 1]or Index;
   End;
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do TiffLine[X]:=ScanLine[X];
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    TiffLine[X*3+0]:=ScanLine[X]; { R }
    TiffLine[X*3+1]:=ScanLine[PCXHeader.BytesPerLine+X]; { G }
    TiffLine[X*3+2]:=ScanLine[Word(PCXHeader.BytesPerLine)*2+X]; { B }
   End;
  End;
 End;
End;

Var
 I:Word;
 Y:LongInt;
 ByteVal:Byte;
 ColorMapEntries:Word;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2TIFF : Cette commande permet de convertir une image PCX (.PCX) ',
                     'en format TIFF (Tagged Image File Format).');
  WriteLn;
  WriteLn('Syntaxe : PCX2TIFF source.PCX [destination.TIF]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.TIF Ce parametre permet d''indiquer le nom du fichier ".TIF".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .TIF.');
  WriteLn('Les PCX RLE 1 bit, 16 couleurs, 256 couleurs et 24 bits sont supportes.');
  Halt;
 End;
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
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');

 Case PCXBitsPerPixel of
  1:Begin
   IsPalette:=True; SamplesPerPixel:=1; BitsPerSample:=1;
   Photometric:=TiffPhotoPalette; PaletteSize:=2;
   TiffBytesPerLine:=Word((LongInt(ImageWidth)+7)shr 3);
  End;
  4:Begin
   IsPalette:=True; SamplesPerPixel:=1; BitsPerSample:=4;
   Photometric:=TiffPhotoPalette; PaletteSize:=16;
   TiffBytesPerLine:=Word((LongInt(ImageWidth)+1)shr 1);
  End;
  8:Begin
   IsPalette:=True; SamplesPerPixel:=1; BitsPerSample:=8;
   Photometric:=TiffPhotoPalette; PaletteSize:=256;
   TiffBytesPerLine:=ImageWidth;
  End;
  24:Begin
   IsPalette:=False; SamplesPerPixel:=3; BitsPerSample:=8;
   Photometric:=TiffPhotoRGB; PaletteSize:=0;
   TiffBytesPerLine:=Word(LongInt(ImageWidth)*3);
  End;
 End;
 If(TiffBytesPerLine=0)or(TiffBytesPerLine>SizeOf(TiffLine))Then
  WriteError('Ligne TIFF trop large !');

 LoadPCXPalette;
 StripByteCount:=LongInt(TiffBytesPerLine)*LongInt(ImageHeight);
 If IsPalette Then NumEntries:=13 Else NumEntries:=12;

 ExternalStart:=8+2+LongInt(NumEntries)*12+4;
 XResOffset:=ExternalStart;
 YResOffset:=XResOffset+8;
 If IsPalette Then Begin
  ColorMapEntries:=Word(3*PaletteSize);
  ColorMapOffset:=YResOffset+8;
  StripOffset:=ColorMapOffset+LongInt(ColorMapEntries)*2;
  BitsPerSampleOffset:=0;
 End
  Else
 Begin
  ColorMapEntries:=0;
  BitsPerSampleOffset:=YResOffset+8;
  ColorMapOffset:=0;
  StripOffset:=BitsPerSampleOffset+6;
 End;

 {$I-}Assign(DestTIFF,OutputName);
 Rewrite(DestTIFF,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 WriteWordToFile(TiffByteOrder);
 WriteWordToFile(TiffMagic);
 WriteLongToFile(8);

 WriteWordToFile(NumEntries);
 WriteIFDEntry(TagImageWidth,TiffTypeLong,1,LongInt(ImageWidth));
 WriteIFDEntry(TagImageLength,TiffTypeLong,1,LongInt(ImageHeight));
 If IsPalette Then
  WriteIFDEntry(TagBitsPerSample,TiffTypeShort,1,LongInt(BitsPerSample))
  Else
  WriteIFDEntry(TagBitsPerSample,TiffTypeShort,3,BitsPerSampleOffset);
 WriteIFDEntry(TagCompression,TiffTypeShort,1,TiffNoCompression);
 WriteIFDEntry(TagPhotometric,TiffTypeShort,1,LongInt(Photometric));
 WriteIFDEntry(TagStripOffsets,TiffTypeLong,1,StripOffset);
 WriteIFDEntry(TagSamplesPerPixel,TiffTypeShort,1,LongInt(SamplesPerPixel));
 WriteIFDEntry(TagRowsPerStrip,TiffTypeLong,1,LongInt(ImageHeight));
 WriteIFDEntry(TagStripByteCounts,TiffTypeLong,1,StripByteCount);
 WriteIFDEntry(TagXResolution,TiffTypeRational,1,XResOffset);
 WriteIFDEntry(TagYResolution,TiffTypeRational,1,YResOffset);
 WriteIFDEntry(TagResolutionUnit,TiffTypeShort,1,TiffResolutionInch);
 If IsPalette Then
  WriteIFDEntry(TagColorMap,TiffTypeShort,LongInt(ColorMapEntries),ColorMapOffset);
 WriteLongToFile(0);

 WriteRational(72,1);
 WriteRational(72,1);
 If IsPalette Then Begin
  For I:=0 to PaletteSize-1 Do Begin
   If I<NumPal Then ByteVal:=Palette[I].R Else ByteVal:=0;
   WriteWordToFile(Word((Word(ByteVal)shl 8)or ByteVal));
  End;
  For I:=0 to PaletteSize-1 Do Begin
   If I<NumPal Then ByteVal:=Palette[I].G Else ByteVal:=0;
   WriteWordToFile(Word((Word(ByteVal)shl 8)or ByteVal));
  End;
  For I:=0 to PaletteSize-1 Do Begin
   If I<NumPal Then ByteVal:=Palette[I].B Else ByteVal:=0;
   WriteWordToFile(Word((Word(ByteVal)shl 8)or ByteVal));
  End;
 End
  Else
 Begin
  WriteWordToFile(BitsPerSample);
  WriteWordToFile(BitsPerSample);
  WriteWordToFile(BitsPerSample);
 End;

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildTiffLine;
  BlockWrite(DestTIFF,TiffLine,TiffBytesPerLine,ByteWritten);
  If ByteWritten<>TiffBytesPerLine Then WriteError('Impossible d''ecrire une ligne TIFF !');
 End;

 Close(DestTIFF);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier TIFF cree : ',OutputName);
END.
