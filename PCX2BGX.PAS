{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2BGX;

{$A-}

Uses DOS;

Const
  {Constantes du format PCX (ZSoft Picture eXchange).}
 PCXManufacturer=10;
 PCXEncodingRLE=1;

 MaxWidth=4096;
 MaxLineBytes=MaxWidth*3+4;

Type
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

 {Entete d'un format d'image BGX}
 BGXHeader=Record
  Sign:Array[0..3]of Char;
  NumXPixels,NumYPixels:Word;
  BitsPerPixel:Byte;
 End;

Var
 SourcePCX,TargetBGX:File;
 PCXHeader:HeaderPCX;
 BGX:BGXHeader;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 BGXLine:Array[0..MaxLineBytes-1]of Byte;
 SourceFileName,TargetFileName:String;
 ImageWidth,ImageHeight:Word;
 PCXLineSize,BGXBytesPerLine:Word;
 ByteReaded,ByteWritten:Word;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.BGX';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 Close(TargetBGX);
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

Function LenNBits2BytesPerLine(Width:Word;Bits4Pixel:Byte):Word;Begin
 Case(Bits4Pixel)of
  1:LenNBits2BytesPerLine:=(Width+7)shr 3;
  2:LenNBits2BytesPerLine:=(Width+3)shr 2;
  4:LenNBits2BytesPerLine:=(Width+1)shr 1;
  9..16:LenNBits2BytesPerLine:=Width shl 1;
  17..24:LenNBits2BytesPerLine:=Width*3;
  25..32:LenNBits2BytesPerLine:=Width shl 2;
  33..64:LenNBits2BytesPerLine:=Width shl 4;
  Else LenNBits2BytesPerLine:=Width;
 End;
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

Procedure BuildBGXLine;
Var
 X:Word;
 Index:Byte;
Begin
 FillChar(BGXLine,BGXBytesPerLine,0);
 Case PCXBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do Begin
    If GetPlaneBit(0,X)<>0 Then
     BGXLine[X shr 3]:=BGXLine[X shr 3]or Byte($80 shr (X and 7));
   End;
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Index:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
           (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
    If(X and 1)=0 Then BGXLine[X shr 1]:=Index shl 4
                  Else BGXLine[X shr 1]:=BGXLine[X shr 1]or Index;
   End;
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do BGXLine[X]:=ScanLine[X];
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    BGXLine[X*3+0]:=ScanLine[X]; { R }
    BGXLine[X*3+1]:=ScanLine[PCXHeader.BytesPerLine+X]; { G }
    BGXLine[X*3+2]:=ScanLine[Word(PCXHeader.BytesPerLine)*2+X]; { B }
   End;
  End;
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2BGX : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en format BGX (MonsterBook).');
  WriteLn;
  WriteLn('Syntaxe : PCX2BGX source.PCX [destination.BGX]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.BGX Ce parametre permet d''indiquer le nom du fichier ".BGX".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .BGX.');
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
 If PCXBitsPerPixel=0 Then Begin
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
 BGXBytesPerLine:=LenNBits2BytesPerLine(ImageWidth,Byte(PCXBitsPerPixel));
 If(BGXBytesPerLine=0)or(BGXBytesPerLine>SizeOf(BGXLine))Then Begin
  WriteLn('Ligne BGX trop large !');
  Close(SourcePCX);
  Halt;
 End;

 {$I-}Assign(TargetBGX,TargetFileName);
 Rewrite(TargetBGX,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible d''ecrire le fichier BGX : ',TargetFileName);
  Close(SourcePCX);
  Halt;
 End;

 BGX.Sign:='BGX1';
 BGX.NumXPixels:=ImageWidth;
 BGX.NumYPixels:=ImageHeight;
 BGX.BitsPerPixel:=Byte(PCXBitsPerPixel);
 BlockWrite(TargetBGX,BGX,SizeOf(BGX),ByteWritten);
 If ByteWritten<>SizeOf(BGX) Then WriteError('Impossible d''ecrire l''entete BGX !');

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildBGXLine;
  BlockWrite(TargetBGX,BGXLine,BGXBytesPerLine,ByteWritten);
  If ByteWritten<>BGXBytesPerLine Then WriteError('Impossible d''ecrire une ligne BGX !');
 End;

 Close(SourcePCX);
 Close(TargetBGX);
 WriteLn('Fichier BGX cree : ',TargetFileName);
END.
