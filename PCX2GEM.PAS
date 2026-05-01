{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2GEM;

{$A-}

Uses DOS;

Const
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;
 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

  {Constantes du format GEM/IMG (Digital Research GEM, Atari ST).}
 GEMVersion=1;
 GEMPatternLen=2;
 GEMPixelDim=372;
 GEMColorModelRGB=0;

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
 SourcePCX,DestGEM:File;
 PCXHeader:HeaderPCX;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 PlaneBuf:Array[0..(MaxWidth div 8)+3]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 PlaneBytes,NumPlanes:Word;
 TargetOpened:Boolean;
 I,K:Integer;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.GEM';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestGEM);
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

Procedure WriteWordBE(W:Word);
Var
 Tmp:Array[0..1]of Byte;
Begin
 Tmp[0]:=Byte(W shr 8);
 Tmp[1]:=Byte(W and $FF);
 BlockWrite(DestGEM,Tmp,2,ByteWritten);
End;

Procedure WriteByte(B:Byte);
Begin
 BlockWrite(DestGEM,B,1,ByteWritten);
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

Procedure EncodeRow(Var Buf:Array of Byte;Length:Word);
Var
 P,LStart:Word;
 RunByte,Cmd:Byte;
 RunCount,EmitN:Word;
Begin
 P:=0;
 While P<Length Do Begin
  RunByte:=Buf[P];
  If(RunByte=0)or(RunByte=$FF)Then Begin
   RunCount:=1;
   While(P+RunCount<Length)and(Buf[P+RunCount]=RunByte)Do Inc(RunCount);
   While RunCount>0 Do Begin
    If RunCount>127 Then EmitN:=127
                    Else EmitN:=RunCount;
    If RunByte=0 Then Cmd:=Byte(EmitN)
                 Else Cmd:=Byte($80 or EmitN);
    WriteByte(Cmd);
    Dec(RunCount,EmitN);
    Inc(P,EmitN);
   End;
  End
   Else
  Begin
   LStart:=P;
   While(P<Length)and(Buf[P]<>0)and(Buf[P]<>$FF)
                 and(P-LStart<255)Do Inc(P);
   EmitN:=P-LStart;
   WriteByte($80);
   WriteByte(Byte(EmitN));
   BlockWrite(DestGEM,Buf[LStart],EmitN,ByteWritten);
  End;
 End;
End;

Function ToGEM(C:Byte):Word;
Begin
 ToGEM:=Word((LongInt(C)*1000+127)div 255);
End;

Procedure BuildPlaneRow(PlaneIdx:Word);
Var
 X:Word;
 Idx:Byte;
Begin
 FillChar(PlaneBuf,PlaneBytes,0);
 For X:=0 to ImageWidth-1 Do Begin
  Idx:=GetPalIndex(X);
  If((Idx shr PlaneIdx)and 1)<>0 Then
   PlaneBuf[X shr 3]:=PlaneBuf[X shr 3]or Byte(1 shl (7-(X and 7)));
 End;
End;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2GEM : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en format GEM/IMG (.GEM) de Digital Research GEM et Atari ST.');
  WriteLn;
  WriteLn('Syntaxe : PCX2GEM source.PCX [destination.GEM]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.GEM Ce parametre permet d''indiquer le nom du fichier ".GEM".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .GEM.');
  WriteLn('Seuls les PCX RLE indexes 1, 4 ou 8 bits sont supportes.');
  WriteLn('La palette est conservee via l''extension XIMG pour les modes 4 et 8 bpp.');
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
 If(PCXBitsPerPixel<>1)and(PCXBitsPerPixel<>4)and(PCXBitsPerPixel<>8)Then
  WriteError('Seuls les PCX 1, 4 ou 8 bits indexes sont supportes pour GEM !');
 If(PCXHeader.Xmax<PCXHeader.Xmin)or(PCXHeader.Ymax<PCXHeader.Ymin)Then
  WriteError('Dimensions PCX invalides !');

 ImageWidth:=PCXHeader.Xmax-PCXHeader.Xmin+1;
 ImageHeight:=PCXHeader.Ymax-PCXHeader.Ymin+1;
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');

 NumPlanes:=PCXBitsPerPixel;
 PlaneBytes:=Word((LongInt(ImageWidth)+7)div 8);
 If(PlaneBytes=0)or(PlaneBytes>SizeOf(PlaneBuf))Then WriteError('Ligne de plan GEM trop large !');
 LoadPCXPalette;

 {$I-}Assign(DestGEM,OutputName);
 Rewrite(DestGEM,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 WriteWordBE(GEMVersion);
 If NumPlanes=1 Then
  WriteWordBE(8)
 Else
  WriteWordBE(Word(11+3*LongInt(NumPal)));
 WriteWordBE(NumPlanes);
 WriteWordBE(GEMPatternLen);
 WriteWordBE(GEMPixelDim);
 WriteWordBE(GEMPixelDim);
 WriteWordBE(ImageWidth);
 WriteWordBE(ImageHeight);
 If NumPlanes>1 Then Begin
  WriteByte(Ord('X'));WriteByte(Ord('I'));
  WriteByte(Ord('M'));WriteByte(Ord('G'));
  WriteWordBE(GEMColorModelRGB);
  For I:=0 to NumPal-1 Do Begin
   WriteWordBE(ToGEM(Palette[I].R));
   WriteWordBE(ToGEM(Palette[I].G));
   WriteWordBE(ToGEM(Palette[I].B));
  End;
 End;

 For Y:=0 to LongInt(ImageHeight)-1 Do Begin
  DecodePCXScanLine;
  For K:=0 to NumPlanes-1 Do Begin
   BuildPlaneRow(Word(K));
   EncodeRow(PlaneBuf,PlaneBytes);
  End;
 End;

 Close(DestGEM);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier GEM cree : ',OutputName);
END.
