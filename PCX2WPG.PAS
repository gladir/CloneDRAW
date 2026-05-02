{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2WPG;

{$A-}

Uses DOS;

Const
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;
 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

 WPGMagic0=$FF;
 WPGMagic1=$57;
 WPGMagic2=$50;
 WPGMagic3=$43;
 WPGProductType=1;
 WPGFileType=$16;
 WPGVersionMajor=1;
 WPGVersionMinor=0;

 WPGRecStart=$0F;
 WPGRecEnd=$10;
 WPGRecColorMap=$0E;
 WPGRecBitmap1=$0B;
 MaxRunLen=127;

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
 SourcePCX,DestWPG:File;
 PCXHeader:HeaderPCX;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 WPGLine:Array[0..MaxWidth-1]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 WPGBytesPerLine:Word;
 TargetOpened:Boolean;
 X:Word;
 Y:LongInt;
 I:Integer;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.WPG';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestWPG);
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
 Buf:Array[0..1]of Byte;
Begin
 Buf[0]:=Byte((W shr 8)and $FF);
 Buf[1]:=Byte(W and $FF);
 BlockWrite(DestWPG,Buf,2,ByteWritten);
End;

Procedure WriteLongBE(L:LongInt);
Var
 Buf:Array[0..3]of Byte;
Begin
 Buf[0]:=Byte((L shr 24)and $FF);
 Buf[1]:=Byte((L shr 16)and $FF);
 Buf[2]:=Byte((L shr 8)and $FF);
 Buf[3]:=Byte(L and $FF);
 BlockWrite(DestWPG,Buf,4,ByteWritten);
End;

Procedure WriteByte(B:Byte);
Begin
 BlockWrite(DestWPG,B,1,ByteWritten);
End;

Procedure WriteRecLength(Len:LongInt);
Begin
 If Len<$FF Then WriteByte(Byte(Len))
 Else Begin
  WriteByte($FF);
  If Len<=$7FFF Then WriteWordBE(Word(Len))
  Else Begin
   WriteWordBE(Word($8000 or ((Len shr 16)and $7FFF)));
   WriteWordBE(Word(Len and $FFFF));
  End;
 End;
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

Procedure BuildWPGLine;
Var
 Index:Byte;
Begin
 FillChar(WPGLine,WPGBytesPerLine,0);
 Case PCXBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do Begin
    If GetPlaneBit(0,X)<>0 Then
     WPGLine[X shr 3]:=WPGLine[X shr 3]or Byte($80 shr (X and 7));
   End;
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Index:=GetPalIndex(X);
    If(X and 1)=0 Then WPGLine[X shr 1]:=Index shl 4
                  Else WPGLine[X shr 1]:=WPGLine[X shr 1]or Index;
   End;
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do WPGLine[X]:=ScanLine[X];
  End;
 End;
End;

Procedure WriteScanlineRLE(Var Line;LineLen:Word);
Var
 P:^Byte;
 Remaining:Word;
 Chunk:Word;
 Buf:Byte;
Begin
 P:=@Line;
 Remaining:=LineLen;
 While Remaining>0 Do Begin
  If Remaining>MaxRunLen Then Chunk:=MaxRunLen
                         Else Chunk:=Remaining;
  Buf:=Byte(Chunk);
  BlockWrite(DestWPG,Buf,1,ByteWritten);
  BlockWrite(DestWPG,P^,Chunk,ByteWritten);
  Inc(P,Chunk);
  Dec(Remaining,Chunk);
 End;
End;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2WPG : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en fichier WordPerfect Graphics (.WPG).');
  WriteLn;
  WriteLn('Syntaxe : PCX2WPG source.PCX [destination.WPG]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.WPG Ce parametre permet d''indiquer le nom du fichier ".WPG".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .WPG.');
  WriteLn('Seuls les PCX RLE indexes 1, 4 ou 8 bits sont supportes.');
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
  WriteError('Seuls les PCX 1, 4 ou 8 bits indexes sont supportes pour WPG !');
 If(PCXHeader.Xmax<PCXHeader.Xmin)or(PCXHeader.Ymax<PCXHeader.Ymin)Then
  WriteError('Dimensions PCX invalides !');

 ImageWidth:=PCXHeader.Xmax-PCXHeader.Xmin+1;
 ImageHeight:=PCXHeader.Ymax-PCXHeader.Ymin+1;
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');
 WPGBytesPerLine:=Word((LongInt(ImageWidth)*LongInt(PCXBitsPerPixel)+7)div 8);
 If(WPGBytesPerLine=0)or(WPGBytesPerLine>SizeOf(WPGLine))Then WriteError('Ligne WPG trop large !');
 LoadPCXPalette;

 {$I-}Assign(DestWPG,OutputName);
 Rewrite(DestWPG,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 WriteByte(WPGMagic0);
 WriteByte(WPGMagic1);
 WriteByte(WPGMagic2);
 WriteByte(WPGMagic3);
 WriteLongBE(16);
 WriteByte(WPGProductType);
 WriteByte(WPGFileType);
 WriteByte(WPGVersionMajor);
 WriteByte(WPGVersionMinor);
 WriteWordBE(0);
 WriteWordBE(0);

 WriteByte(WPGRecStart);
 WriteRecLength(6);
 WriteByte(1);
 WriteByte(0);
 WriteWordBE(Word(LongInt(ImageWidth)*8));
 WriteWordBE(Word(LongInt(ImageHeight)*8));

 WriteByte(WPGRecColorMap);
 WriteRecLength(LongInt(4)+LongInt(NumPal)*3);
 WriteWordBE(0);
 WriteWordBE(NumPal);
 For I:=0 to NumPal-1 Do Begin
  WriteByte(Palette[I].R);
  WriteByte(Palette[I].G);
  WriteByte(Palette[I].B);
 End;

 WriteByte(WPGRecBitmap1);
 WriteRecLength(LongInt(10)+
                (LongInt(WPGBytesPerLine)+
                 ((LongInt(WPGBytesPerLine)+MaxRunLen-1)div MaxRunLen))*
                LongInt(ImageHeight));
 WriteWordBE(ImageWidth);
 WriteWordBE(ImageHeight);
 WriteWordBE(PCXBitsPerPixel);
 WriteWordBE(150);
 WriteWordBE(150);

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildWPGLine;
  WriteScanlineRLE(WPGLine,WPGBytesPerLine);
 End;

 WriteByte(WPGRecEnd);
 WriteRecLength(0);

 Close(SourcePCX);
 Close(DestWPG);
 TargetOpened:=False;
 WriteLn('Fichier WPG cree : ',OutputName);
END.
