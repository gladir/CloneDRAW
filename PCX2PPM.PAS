{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2PPM;

{$A-}

Uses DOS;

Const
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;
 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

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
 SourcePCX,TargetPPM:File;
 PCXHeader:HeaderPCX;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 HeaderStr,SourceFileName,TargetFileName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 TargetOpened:Boolean;
 Pixel:RGB;
 Y:LongInt;

Function IntToStr(I:LongInt):String;
Var
 S:String;
Begin
 Str(I,S);
 IntToStr:=S;
End;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.PPM';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(TargetPPM);
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

Procedure WriteRGB(R,G,B:Byte);
Begin
 Pixel.R:=R;
 Pixel.G:=G;
 Pixel.B:=B;
 BlockWrite(TargetPPM,Pixel,SizeOf(Pixel),ByteWritten);
 If ByteWritten<>SizeOf(Pixel) Then WriteError('Impossible d''ecrire un pixel PPM !');
End;

Procedure WritePalettePixel(Index:Byte);
Begin
 If Index>=NumPal Then WriteRGB(0,0,0)
                 Else WriteRGB(Palette[Index].R,Palette[Index].G,Palette[Index].B);
End;

Procedure WritePPMLine;
Var
 X:Word;
 Index:Byte;
Begin
 Case PCXBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do WritePalettePixel(GetPlaneBit(0,X));
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Index:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
           (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
    WritePalettePixel(Index);
   End;
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do WritePalettePixel(ScanLine[X]);
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    WriteRGB(ScanLine[X],
             ScanLine[PCXHeader.BytesPerLine+X],
             ScanLine[Word(PCXHeader.BytesPerLine)*2+X]);
   End;
  End;
 End;
End;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2PPM : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en format d''image PPM (Portable PixMap).');
  WriteLn;
  WriteLn('Syntaxe : PCX2PPM source.PCX [destination.PPM]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.PPM Ce parametre permet d''indiquer le nom du fichier ".PPM".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .PPM.');
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
 If PCXBitsPerPixel=0 Then WriteError('Profondeur PCX non supportee !');
 If(PCXHeader.Xmax<PCXHeader.Xmin)or(PCXHeader.Ymax<PCXHeader.Ymin)Then
  WriteError('Dimensions PCX invalides !');

 ImageWidth:=PCXHeader.Xmax-PCXHeader.Xmin+1;
 ImageHeight:=PCXHeader.Ymax-PCXHeader.Ymin+1;
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');

 LoadPCXPalette;

 {$I-}Assign(TargetPPM,TargetFileName);
 Rewrite(TargetPPM,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible d''ecrire le fichier PPM : ',TargetFileName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 HeaderStr:='P6'#10+IntToStr(ImageWidth)+' '+
            IntToStr(ImageHeight)+#10+
            IntToStr(255)+#10;
 BlockWrite(TargetPPM,HeaderStr[1],Length(HeaderStr),ByteWritten);
 If ByteWritten<>Length(HeaderStr) Then WriteError('Impossible d''ecrire l''entete PPM !');

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  WritePPMLine;
 End;

 Close(TargetPPM);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier PPM cree : ',TargetFileName);
END.
