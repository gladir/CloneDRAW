{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2TGA;

{$A-}

Uses DOS;

Const
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;
 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

 TGAImgUncompColormap=1;
 TGAImgUncompTrueCol=2;
 TGAColorMapAbsent=0;
 TGAColorMapPresent=1;
 TGADescTopLeft=$20;

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

 HeaderTGA=Record
  IDLength:Byte;
  ColorMapType:Byte;
  ImageType:Byte;
  CMapFirstEntry:Word;
  CMapLength:Word;
  CMapEntrySize:Byte;
  XOrigin:Word;
  YOrigin:Word;
  ImageWidth:Word;
  ImageHeight:Word;
  PixelDepth:Byte;
  Descriptor:Byte;
 End;

Var
 SourcePCX,DestTGA:File;
 PCXHeader:HeaderPCX;
 TGAHdr:HeaderTGA;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 OutLine:Array[0..MaxWidth*3-1]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 TargetOpened:Boolean;
 X:Word;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.TGA';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestTGA);
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

Procedure WriteTGAHeader;
Var
 B:Byte;
 W:Word;
Begin
 B:=TGAHdr.IDLength;        BlockWrite(DestTGA,B,1,ByteWritten);
 B:=TGAHdr.ColorMapType;    BlockWrite(DestTGA,B,1,ByteWritten);
 B:=TGAHdr.ImageType;       BlockWrite(DestTGA,B,1,ByteWritten);
 W:=TGAHdr.CMapFirstEntry;  BlockWrite(DestTGA,W,2,ByteWritten);
 W:=TGAHdr.CMapLength;      BlockWrite(DestTGA,W,2,ByteWritten);
 B:=TGAHdr.CMapEntrySize;   BlockWrite(DestTGA,B,1,ByteWritten);
 W:=TGAHdr.XOrigin;         BlockWrite(DestTGA,W,2,ByteWritten);
 W:=TGAHdr.YOrigin;         BlockWrite(DestTGA,W,2,ByteWritten);
 W:=TGAHdr.ImageWidth;      BlockWrite(DestTGA,W,2,ByteWritten);
 W:=TGAHdr.ImageHeight;     BlockWrite(DestTGA,W,2,ByteWritten);
 B:=TGAHdr.PixelDepth;      BlockWrite(DestTGA,B,1,ByteWritten);
 B:=TGAHdr.Descriptor;      BlockWrite(DestTGA,B,1,ByteWritten);
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

Procedure WriteTGAPalette;
Var
 I:Integer;
 Z:Byte;
Begin
 Z:=0;
 For I:=0 to 255 Do Begin
  If I<NumPal Then Begin
   BlockWrite(DestTGA,Palette[I].B,1,ByteWritten);
   BlockWrite(DestTGA,Palette[I].G,1,ByteWritten);
   BlockWrite(DestTGA,Palette[I].R,1,ByteWritten);
  End
   Else
  Begin
   BlockWrite(DestTGA,Z,1,ByteWritten);
   BlockWrite(DestTGA,Z,1,ByteWritten);
   BlockWrite(DestTGA,Z,1,ByteWritten);
  End;
 End;
End;

Procedure WriteTGALine;
Begin
 Case PCXBitsPerPixel of
  1,4,8:Begin
   For X:=0 to ImageWidth-1 Do OutLine[X]:=GetPalIndex(X);
   BlockWrite(DestTGA,OutLine,ImageWidth,ByteWritten);
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    OutLine[X*3+0]:=ScanLine[Word(PCXHeader.BytesPerLine)*2+X];
    OutLine[X*3+1]:=ScanLine[PCXHeader.BytesPerLine+X];
    OutLine[X*3+2]:=ScanLine[X];
   End;
   BlockWrite(DestTGA,OutLine,LongInt(ImageWidth)*3,ByteWritten);
  End;
 End;
End;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2TGA : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en format Targa (.TGA).');
  WriteLn;
  WriteLn('Syntaxe : PCX2TGA source.PCX [destination.TGA]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.TGA Ce parametre permet d''indiquer le nom du fichier ".TGA".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .TGA.');
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
 If PCXBitsPerPixel=0 Then WriteError('Format PCX non supporte !');
 If(PCXHeader.Xmax<PCXHeader.Xmin)or(PCXHeader.Ymax<PCXHeader.Ymin)Then
  WriteError('Dimensions PCX invalides !');

 ImageWidth:=PCXHeader.Xmax-PCXHeader.Xmin+1;
 ImageHeight:=PCXHeader.Ymax-PCXHeader.Ymin+1;
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');
 LoadPCXPalette;

 FillChar(TGAHdr,SizeOf(TGAHdr),0);
 TGAHdr.IDLength:=0;
 TGAHdr.XOrigin:=0;
 TGAHdr.YOrigin:=0;
 TGAHdr.ImageWidth:=ImageWidth;
 TGAHdr.ImageHeight:=ImageHeight;
 TGAHdr.Descriptor:=TGADescTopLeft;
 If PCXBitsPerPixel=24 Then Begin
  TGAHdr.ColorMapType:=TGAColorMapAbsent;
  TGAHdr.ImageType:=TGAImgUncompTrueCol;
  TGAHdr.CMapFirstEntry:=0;
  TGAHdr.CMapLength:=0;
  TGAHdr.CMapEntrySize:=0;
  TGAHdr.PixelDepth:=24;
 End
  Else
 Begin
  TGAHdr.ColorMapType:=TGAColorMapPresent;
  TGAHdr.ImageType:=TGAImgUncompColormap;
  TGAHdr.CMapFirstEntry:=0;
  TGAHdr.CMapLength:=256;
  TGAHdr.CMapEntrySize:=24;
  TGAHdr.PixelDepth:=8;
 End;

 {$I-}Assign(DestTGA,OutputName);
 Rewrite(DestTGA,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 WriteTGAHeader;
 If PCXBitsPerPixel<>24 Then WriteTGAPalette;

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  WriteTGALine;
 End;

 Close(DestTGA);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier TGA cree : ',OutputName);
END.
