{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2CUR;

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
 SourcePCX,DestCUR:File;
 PCXHeader:HeaderPCX;
 DIBHeader:BitmapInfoHeader;
 CurDir:IconDir;
 CurEntry:IconDirEntry;
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
 HotspotX,HotspotY:Word;
 Argi:Integer;
 Arg,ArgUp:String;
 ParamVal:LongInt;
 Code:Integer;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.CUR';
End;

Function UpStr(Const S:String):String;
Var
 I:Integer;
 R:String;
Begin
 R:=S;
 For I:=1 to Length(R)Do R[I]:=UpCase(R[I]);
 UpStr:=R;
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestCUR);
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
 WriteLn('PCX2CUR : Cette commande permet de convertir une image PCX (.PCX) ',
                   'en ressource curseur Windows (.CUR).');
 WriteLn;
 WriteLn('Syntaxe : PCX2CUR source.PCX [destination.CUR] [/HX:n] [/HY:n]');
 WriteLn;
 WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
 WriteLn(' destination.CUR Ce parametre permet d''indiquer le nom du fichier ".CUR".');
 WriteLn(' /HX:n           Coordonne X du point chaud (hotspot), 0 par defaut.');
 WriteLn(' /HY:n           Coordonne Y du point chaud (hotspot), 0 par defaut.');
 WriteLn;
 WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .CUR.');
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

 SourceFileName:='';
 OutputName:='';
 HotspotX:=0;
 HotspotY:=0;
 For Argi:=1 to ParamCount Do Begin
  Arg:=ParamStr(Argi);
  ArgUp:=UpStr(Arg);
  If(Arg='/?')or(Arg='--help')or(Arg='-h')Then ShowHelp
  Else If(Length(ArgUp)>=4)and(Copy(ArgUp,1,4)='/HX:')Then Begin
   Val(Copy(Arg,5,Length(Arg)-4),ParamVal,Code);
   If(Code<>0)or(ParamVal<0)or(ParamVal>65535)Then Begin
    WriteLn('Valeur /HX invalide !');
    Halt;
   End;
   HotspotX:=Word(ParamVal);
  End
  Else If(Length(ArgUp)>=4)and(Copy(ArgUp,1,4)='/HY:')Then Begin
   Val(Copy(Arg,5,Length(Arg)-4),ParamVal,Code);
   If(Code<>0)or(ParamVal<0)or(ParamVal>65535)Then Begin
    WriteLn('Valeur /HY invalide !');
    Halt;
   End;
   HotspotY:=Word(ParamVal);
  End
  Else If SourceFileName=''Then SourceFileName:=Arg
  Else If OutputName=''Then OutputName:=Arg
  Else Begin
   WriteLn('Parametre inattendu : ',Arg);
   Halt;
  End;
 End;
 If SourceFileName=''Then Begin
  WriteLn('Parametre requis !');
  Halt;
 End;
 If OutputName=''Then OutputName:=Path2NameExt(SourceFileName);

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

 {$I-}Assign(DestCUR,OutputName);
 Rewrite(DestCUR,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;

 CurDir.idReserved:=0;
 CurDir.idType:=2;
 CurDir.idCount:=1;
 BlockWrite(DestCUR,CurDir,SizeOf(CurDir),ByteWritten);

 If ImageWidth>=256 Then CurEntry.bWidth:=0
                    Else CurEntry.bWidth:=Byte(ImageWidth);
 If ImageHeight>=256 Then CurEntry.bHeight:=0
                     Else CurEntry.bHeight:=Byte(ImageHeight);
 Case PCXBitsPerPixel of
  1:CurEntry.bColorCount:=2;
  4:CurEntry.bColorCount:=16;
  Else CurEntry.bColorCount:=0;
 End;
 CurEntry.bReserved:=0;
 CurEntry.wPlanes:=HotspotX;
 CurEntry.wBitCount:=HotspotY;
 CurEntry.dwBytesInRes:=DIBSize;
 CurEntry.dwImageOffset:=SizeOf(CurDir)+SizeOf(CurEntry);
 BlockWrite(DestCUR,CurEntry,SizeOf(CurEntry),ByteWritten);

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
 BlockWrite(DestCUR,DIBHeader,SizeOf(DIBHeader),ByteWritten);

 If PaletteBytes>0 Then BlockWrite(DestCUR,DIBPalette,PaletteBytes,ByteWritten);

 XOROffset:=CurEntry.dwImageOffset+SizeOf(BitmapInfoHeader)+PaletteBytes;
 ANDOffset:=XOROffset+XORStride*LongInt(ImageHeight);

 For Y:=0 to ImageHeight-1 Do Begin
  DecodePCXScanLine;
  BuildXORLine;
  Seek(DestCUR,XOROffset+(LongInt(ImageHeight)-1-Y)*XORStride);
  BlockWrite(DestCUR,XORLine,XORStride,ByteWritten);
 End;

 FillChar(ANDLine,SizeOf(ANDLine),0);
 For Y:=0 to ImageHeight-1 Do Begin
  Seek(DestCUR,ANDOffset+Y*ANDStride);
  BlockWrite(DestCUR,ANDLine,ANDStride,ByteWritten);
 End;

 Close(DestCUR);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier CUR cree : ',OutputName);
END.
