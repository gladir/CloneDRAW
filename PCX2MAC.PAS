{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2MAC;

{$A-}

Uses DOS;

Const
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;
 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

 MacPaintWidth=576;
 MacPaintHeight=720;
 MacPaintRowBytes=72;
 MacPaintHeaderSize=512;

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
 SourcePCX,DestMAC:File;
 PCXHeader:HeaderPCX;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 RowBuf:Array[0..MacPaintRowBytes-1]of Byte;
 PackBuf:Array[0..MacPaintRowBytes*2+1]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 CopyW,CopyH:Word;
 TargetOpened:Boolean;
 ZeroByte:Byte;
 I,X:Word;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.MAC';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestMAC);
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

Function PackBitsRow(Const Src:Array of Byte;Count:Word;
                     Var Dest:Array of Byte):Word;
Var
 Pos,DestPos:Word;
 RunLen,LitLen,K:Word;
Begin
 Pos:=0;
 DestPos:=0;
 While Pos<Count Do Begin
  RunLen:=1;
  While(Pos+RunLen<Count)and(RunLen<128)and
       (Src[Pos+RunLen]=Src[Pos])Do Inc(RunLen);
  If RunLen>=3 Then Begin
   Dest[DestPos]:=Byte(257-RunLen);
   Dest[DestPos+1]:=Src[Pos];
   Inc(DestPos,2);
   Inc(Pos,RunLen);
  End
   Else Begin
    LitLen:=0;
    While(Pos+LitLen<Count)and(LitLen<128)Do Begin
     If(Pos+LitLen+2<Count)and
       (Src[Pos+LitLen]=Src[Pos+LitLen+1])and
       (Src[Pos+LitLen+1]=Src[Pos+LitLen+2])Then Break;
     Inc(LitLen);
    End;
    If LitLen=0 Then LitLen:=1;
    Dest[DestPos]:=Byte(LitLen-1);
    Inc(DestPos);
    For K:=0 to LitLen-1 Do Dest[DestPos+K]:=Src[Pos+K];
    Inc(DestPos,LitLen);
    Inc(Pos,LitLen);
   End;
 End;
 PackBitsRow:=DestPos;
End;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2MAC : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en format MacPaint (.MAC, Apple).');
  WriteLn;
  WriteLn('Syntaxe : PCX2MAC source.PCX [destination.MAC]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.MAC Ce parametre permet d''indiquer le nom du fichier ".MAC".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .MAC.');
  WriteLn('L''image est convertie en monochrome dans le canevas fixe MacPaint de 576 par 720 pixels.');
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

 If ImageWidth>MacPaintWidth Then CopyW:=MacPaintWidth Else CopyW:=ImageWidth;
 If ImageHeight>MacPaintHeight Then CopyH:=MacPaintHeight Else CopyH:=ImageHeight;

 {$I-}Assign(DestMAC,OutputName);
 Rewrite(DestMAC,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 ZeroByte:=0;
 For I:=1 to MacPaintHeaderSize Do BlockWrite(DestMAC,ZeroByte,1,ByteWritten);

 For Y:=0 to MacPaintHeight-1 Do Begin
  FillChar(RowBuf,MacPaintRowBytes,0);

  If Y<LongInt(CopyH) Then Begin
   DecodePCXScanLine;
   For X:=0 to CopyW-1 Do Begin
    If IsBlackPixel(X)Then
     RowBuf[X shr 3]:=RowBuf[X shr 3]or(1 shl (7-(X and 7)));
   End;
  End;

  ByteReaded:=PackBitsRow(RowBuf,MacPaintRowBytes,PackBuf);
  BlockWrite(DestMAC,PackBuf,ByteReaded,ByteWritten);
 End;

 Close(DestMAC);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier MAC cree : ',OutputName);
END.
