{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2MSP;

{$A-}

Uses DOS;

Const
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;
 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

 MSPSig1V1=$6144;
 MSPSig2V1=$4D6E;

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

 HeaderMSP=Record
  Sig1,Sig2:Word;
  Width,Height:Word;
  XAspectRatio,
  YAspectRatio:Word;
  PrinterWidth,
  PrinterHeight:Word;
  PrinterXOffset,
  PrinterYOffset:Word;
  Checksum:Word;
  Reserved:Array[0..4]of Word;
 End;

Var
 SourcePCX,DestMSP:File;
 PCXHeader:HeaderPCX;
 MSPHeader:HeaderMSP;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 OutLine:Array[0..MaxWidth div 8]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 MSPBytesPerLine:Word;
 TargetOpened:Boolean;
 X:Word;
 Y:LongInt;
 W:Word;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.MSP';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestMSP);
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

Function IsBlackRGB(R,G,B:Byte):Boolean;
Var
 L:LongInt;
Begin
 L:=LongInt(R)*299+LongInt(G)*587+LongInt(B)*114;
 IsBlackRGB:=L<128000;
End;

Function IsBlackPixel(X:Word):Boolean;
Var
 Index:Byte;
Begin
 Case PCXBitsPerPixel of
  1,4,8:Begin
   Index:=GetPalIndex(X);
   IsBlackPixel:=IsBlackRGB(Palette[Index].R,Palette[Index].G,Palette[Index].B);
  End;
  24:IsBlackPixel:=IsBlackRGB(ScanLine[X],
                              ScanLine[PCXHeader.BytesPerLine+X],
                              ScanLine[Word(PCXHeader.BytesPerLine)*2+X]);
  Else IsBlackPixel:=False;
 End;
End;

Procedure BuildMSPHeader;
Begin
 FillChar(MSPHeader,SizeOf(MSPHeader),0);
 MSPHeader.Sig1:=MSPSig1V1;
 MSPHeader.Sig2:=MSPSig2V1;
 MSPHeader.Width:=ImageWidth;
 MSPHeader.Height:=ImageHeight;
 MSPHeader.XAspectRatio:=1;
 MSPHeader.YAspectRatio:=1;
 MSPHeader.PrinterWidth:=ImageWidth;
 MSPHeader.PrinterHeight:=ImageHeight;
 MSPHeader.PrinterXOffset:=0;
 MSPHeader.PrinterYOffset:=0;
 W:=0;
 W:=W xor MSPHeader.Sig1;
 W:=W xor MSPHeader.Sig2;
 W:=W xor MSPHeader.Width;
 W:=W xor MSPHeader.Height;
 W:=W xor MSPHeader.XAspectRatio;
 W:=W xor MSPHeader.YAspectRatio;
 W:=W xor MSPHeader.PrinterWidth;
 W:=W xor MSPHeader.PrinterHeight;
 W:=W xor MSPHeader.PrinterXOffset;
 W:=W xor MSPHeader.PrinterYOffset;
 MSPHeader.Checksum:=W;
End;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2MSP : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en format MSP (.MSP) de Microsoft Paint.');
  WriteLn;
  WriteLn('Syntaxe : PCX2MSP source.PCX [destination.MSP]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.MSP Ce parametre permet d''indiquer le nom du fichier ".MSP".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .MSP.');
  WriteLn('Le fichier MSP produit utilise la signature "DanM" version 1 sans compression.');
  WriteLn('Les PCX RLE 1, 4, 8 et 24 bits sont supportes et convertis en monochrome.');
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
 MSPBytesPerLine:=Word((LongInt(ImageWidth)+7)div 8);
 If MSPBytesPerLine>SizeOf(OutLine)Then WriteError('Ligne MSP trop large !');
 LoadPCXPalette;
 BuildMSPHeader;

 {$I-}Assign(DestMSP,OutputName);
 Rewrite(DestMSP,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 BlockWrite(DestMSP,MSPHeader,SizeOf(MSPHeader),ByteWritten);
 If ByteWritten<>SizeOf(MSPHeader)Then WriteError('Impossible d''ecrire l''entete MSP !');

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  FillChar(OutLine,SizeOf(OutLine),0);
  For X:=0 to ImageWidth-1 Do Begin
   If IsBlackPixel(X)Then
    OutLine[X shr 3]:=OutLine[X shr 3]or(1 shl (7-(X and 7)));
  End;
  If(ImageWidth and 7)<>0 Then
   OutLine[MSPBytesPerLine-1]:=OutLine[MSPBytesPerLine-1]
                              and(Byte($FF)shl(8-(ImageWidth and 7)));
  BlockWrite(DestMSP,OutLine,MSPBytesPerLine,ByteWritten);
  If ByteWritten<>MSPBytesPerLine Then WriteError('Impossible d''ecrire les donnees MSP !');
 End;

 Close(DestMSP);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier MSP cree : ',OutputName);
END.
