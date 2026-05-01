{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2GIF;

{$A-}

Uses DOS;

Const
  {Constantes du format PCX (ZSoft Picture eXchange).}
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;

  {Parametres LZW pour le format GIF}
 HashSize=5003;
 MaxLZWBits=12;
 MaxLZWCode=4096;

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
 SourcePCX,DestGIF:File;
 PCXHeader:HeaderPCX;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 PixelLine:Array[0..MaxWidth-1]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight:Word;
 PCXLineSize,ByteReaded,ByteWritten:Word;
 NumPal:Word;
 TargetOpened:Boolean;

  {Etat de l'encodeur LZW}
 HashKey:Array[0..HashSize-1]of LongInt;
 HashCode:Array[0..HashSize-1]of Word;
 MinCodeSize:Byte;
 ClearCode,EOICode:Word;
 CurCodeSize:Byte;
 NextCode:Word;
 PrefixCode:LongInt;
 BitBuffer:LongInt;
 BitsInBuffer:Byte;
 SubBlock:Array[0..254]of Byte;
 SubBlockLen:Byte;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.GIF';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestGIF);
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

Function Expand3(V:Byte):Byte;
Begin
 Expand3:=(V shl 5)or(V shl 2)or(V shr 1);
End;

Function Expand2(V:Byte):Byte;
Begin
 Expand2:=(V shl 6)or(V shl 4)or(V shl 2)or V;
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
  8,24:NumPal:=256;
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
 End
  Else
 If PCXBitsPerPixel=24 Then Begin
  For I:=0 to 255 Do Begin
   Palette[I].R:=Expand3(Byte((I shr 5)and 7));
   Palette[I].G:=Expand3(Byte((I shr 2)and 7));
   Palette[I].B:=Expand2(Byte(I and 3));
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

Procedure BuildPixelLine;
Var
 X:Word;
 R,G,B:Byte;
Begin
 Case PCXBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do PixelLine[X]:=GetPlaneBit(0,X);
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do
    PixelLine[X]:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
                  (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do PixelLine[X]:=ScanLine[X];
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    R:=ScanLine[X];
    G:=ScanLine[PCXHeader.BytesPerLine+X];
    B:=ScanLine[Word(PCXHeader.BytesPerLine)*2+X];
    PixelLine[X]:=(R and $E0)or((G and $E0)shr 3)or(B shr 6);
   End;
  End;
 End;
End;

Procedure WriteByteToFile(B:Byte);
Begin
 BlockWrite(DestGIF,B,1,ByteWritten);
End;

Procedure WriteWordToFile(W:Word);
Var
 Lo,Hi:Byte;
Begin
 Lo:=Byte(W and $FF);
 Hi:=Byte((W shr 8)and $FF);
 BlockWrite(DestGIF,Lo,1,ByteWritten);
 BlockWrite(DestGIF,Hi,1,ByteWritten);
End;

Procedure FlushSubBlock;
Begin
 If SubBlockLen>0 Then Begin
  BlockWrite(DestGIF,SubBlockLen,1,ByteWritten);
  BlockWrite(DestGIF,SubBlock,SubBlockLen,ByteWritten);
  SubBlockLen:=0;
 End;
End;

Procedure EmitOutputByte(B:Byte);
Begin
 SubBlock[SubBlockLen]:=B;
 Inc(SubBlockLen);
 If SubBlockLen=255 Then FlushSubBlock;
End;

Procedure EmitCode(Code:Word);
Begin
 BitBuffer:=BitBuffer or(LongInt(Code)shl BitsInBuffer);
 Inc(BitsInBuffer,CurCodeSize);
 While BitsInBuffer>=8 Do Begin
  EmitOutputByte(Byte(BitBuffer and $FF));
  BitBuffer:=BitBuffer shr 8;
  Dec(BitsInBuffer,8);
 End;
End;

Procedure FlushBits;
Begin
 If BitsInBuffer>0 Then Begin
  EmitOutputByte(Byte(BitBuffer and $FF));
  BitBuffer:=0;
  BitsInBuffer:=0;
 End;
End;

Procedure ResetHash;
Var
 I:Word;
Begin
 For I:=0 to HashSize-1 Do Begin
  HashKey[I]:=-1;
  HashCode[I]:=0;
 End;
End;

Procedure HashFind(Prefix:Word;Suffix:Byte;Var Idx:Word;Var Found:Boolean);
Var
 Key:LongInt;
 H:Word;
Begin
 Key:=(LongInt(Prefix)shl 8)or Suffix;
 H:=Word(((Word(Suffix)shl 5)xor Prefix)mod HashSize);
 While HashKey[H]<>-1 Do Begin
  If HashKey[H]=Key Then Begin
   Idx:=H;
   Found:=True;
   Exit;
  End;
  Inc(H);
  If H>=HashSize Then H:=0;
 End;
 Idx:=H;
 Found:=False;
End;

Procedure ResetLZWTable;
Begin
 ResetHash;
 CurCodeSize:=MinCodeSize+1;
 NextCode:=EOICode+1;
End;

Var
 I,X:Word;
 Idx:Word;
 Found:Boolean;
 K:Byte;
 GCTBits:Byte;
 GCTSize:Word;
 PackedField:Byte;
 ZeroByte:Byte;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2GIF : Cette commande permet de convertir une image PCX (.PCX) ',
                     'en format GIF (Graphics Interchange Format).');
  WriteLn;
  WriteLn('Syntaxe : PCX2GIF source.PCX [destination.GIF]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.GIF Ce parametre permet d''indiquer le nom du fichier ".GIF".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .GIF.');
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
 LoadPCXPalette;

 Case PCXBitsPerPixel of
  1:Begin GCTBits:=0; MinCodeSize:=2; End;
  4:Begin GCTBits:=3; MinCodeSize:=4; End;
  8,24:Begin GCTBits:=7; MinCodeSize:=8; End;
  Else Begin GCTBits:=7; MinCodeSize:=8; End;
 End;
 GCTSize:=Word(1)shl(GCTBits+1);

 {$I-}Assign(DestGIF,OutputName);
 Rewrite(DestGIF,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 BlockWrite(DestGIF,'GIF89a',6,ByteWritten);

 WriteWordToFile(ImageWidth);
 WriteWordToFile(ImageHeight);
 PackedField:=$80 or(GCTBits shl 4)or GCTBits;
 WriteByteToFile(PackedField);
 WriteByteToFile(0);
 WriteByteToFile(0);

 For I:=0 to GCTSize-1 Do Begin
  If I<NumPal Then Begin
   WriteByteToFile(Palette[I].R);
   WriteByteToFile(Palette[I].G);
   WriteByteToFile(Palette[I].B);
  End
   Else
  Begin
   WriteByteToFile(0);
   WriteByteToFile(0);
   WriteByteToFile(0);
  End;
 End;

 WriteByteToFile($2C);
 WriteWordToFile(0);
 WriteWordToFile(0);
 WriteWordToFile(ImageWidth);
 WriteWordToFile(ImageHeight);
 WriteByteToFile(0);

 WriteByteToFile(MinCodeSize);

 ClearCode:=Word(1)shl MinCodeSize;
 EOICode:=ClearCode+1;
 BitBuffer:=0;
 BitsInBuffer:=0;
 SubBlockLen:=0;
 ResetLZWTable;

 EmitCode(ClearCode);
 PrefixCode:=-1;

 For I:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildPixelLine;
  For X:=0 to ImageWidth-1 Do Begin
   K:=PixelLine[X];
   If PrefixCode<0 Then PrefixCode:=K
    Else
   Begin
    HashFind(Word(PrefixCode),K,Idx,Found);
    If Found Then PrefixCode:=HashCode[Idx]
     Else
    Begin
     EmitCode(Word(PrefixCode));
     If NextCode<MaxLZWCode Then Begin
      HashKey[Idx]:=(LongInt(PrefixCode)shl 8)or K;
      HashCode[Idx]:=NextCode;
      Inc(NextCode);
      If(NextCode>(Word(1)shl CurCodeSize))and(CurCodeSize<MaxLZWBits)Then
       Inc(CurCodeSize);
     End
      Else
     Begin
      EmitCode(ClearCode);
      ResetLZWTable;
     End;
     PrefixCode:=K;
    End;
   End;
  End;
 End;

 If PrefixCode>=0 Then EmitCode(Word(PrefixCode));
 EmitCode(EOICode);
 FlushBits;
 FlushSubBlock;

 ZeroByte:=0;
 WriteByteToFile(ZeroByte);
 WriteByteToFile($3B);

 Close(DestGIF);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier GIF cree : ',OutputName);
END.
