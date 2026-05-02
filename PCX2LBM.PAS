{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2LBM;

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
 SourcePCX,DestLBM:File;
 PCXHeader:HeaderPCX;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxLineBytes-1]of Byte;
 PixelLine:Array[0..MaxWidth-1]of Byte;
 PlaneRow:Array[0..(MaxWidth div 8)+1]of Byte;
 SourceFileName,OutputName:String;
 ImageWidth,ImageHeight,PCXLineSize,ByteReaded,ByteWritten,NumPal:Word;
 LBMNPlanes:Byte;
 RowBytes:Word;
 TargetOpened:Boolean;
 X:Word;
 Y:LongInt;

 ChunkSizePos:Array[0..7]of LongInt;
 ChunkStart:Array[0..7]of LongInt;
 ChunkDepth:Integer;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.LBM';
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 If TargetOpened Then Close(DestLBM);
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

Procedure WriteBE16(Value:Word);
Var
 B:Array[0..1]of Byte;
Begin
 B[0]:=Byte((Value shr 8)and $FF);
 B[1]:=Byte(Value and $FF);
 BlockWrite(DestLBM,B,2,ByteWritten);
End;

Procedure WriteBE32(Value:LongInt);
Var
 B:Array[0..3]of Byte;
Begin
 B[0]:=Byte((Value shr 24)and $FF);
 B[1]:=Byte((Value shr 16)and $FF);
 B[2]:=Byte((Value shr 8)and $FF);
 B[3]:=Byte(Value and $FF);
 BlockWrite(DestLBM,B,4,ByteWritten);
End;

Procedure WriteID(Const Id:String);
Var
 B:Array[0..3]of Char;
 I:Integer;
Begin
 For I:=0 to 3 Do
  If(I+1)<=Length(Id)Then B[I]:=Id[I+1] Else B[I]:=' ';
 BlockWrite(DestLBM,B,4,ByteWritten);
End;

Procedure BeginChunk(Const Id:String);
Begin
 WriteID(Id);
 ChunkSizePos[ChunkDepth]:=FilePos(DestLBM);
 WriteBE32(0);
 ChunkStart[ChunkDepth]:=FilePos(DestLBM);
 Inc(ChunkDepth);
End;

Procedure EndChunk;
Var
 EndPos:LongInt;
 Size:LongInt;
 PadByte:Byte;
Begin
 EndPos:=FilePos(DestLBM);
 Dec(ChunkDepth);
 Size:=EndPos-ChunkStart[ChunkDepth];
 Seek(DestLBM,ChunkSizePos[ChunkDepth]);
 WriteBE32(Size);
 Seek(DestLBM,EndPos);
 If(Size and 1)<>0 Then Begin
  PadByte:=0;
  BlockWrite(DestLBM,PadByte,1,ByteWritten);
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

Procedure BuildPlaneRow(Plane:Byte);
Var
 Col:Word;
 BitVal:Byte;
 ByteIdx:Word;
 BitInByte:Byte;
Begin
 FillChar(PlaneRow,RowBytes,0);
 For Col:=0 to ImageWidth-1 Do Begin
  BitVal:=(PixelLine[Col]shr Plane)and 1;
  If BitVal<>0 Then Begin
   ByteIdx:=Col shr 3;
   BitInByte:=7-(Col and 7);
   PlaneRow[ByteIdx]:=PlaneRow[ByteIdx]or(1 shl BitInByte);
  End;
 End;
End;

Var
 Plane:Byte;
 BMHDBuf:Array[0..19]of Byte;
 CMAPBuf:Array[0..255*3-1]of Byte;
 NumColors:Word;

BEGIN
 TargetOpened:=False;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2LBM : Cette commande permet de convertir une image PCX (.PCX) ',
                    'en format LBM (.LBM, IFF/ILBM Electronic Arts).');
  WriteLn;
  WriteLn('Syntaxe : PCX2LBM source.PCX [destination.LBM]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.LBM Ce parametre permet d''indiquer le nom du fichier ".LBM".');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .LBM.');
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
  WriteError('Seuls les PCX 1, 4 ou 8 bits indexes sont supportes pour LBM !');
 If(PCXHeader.Xmax<PCXHeader.Xmin)or(PCXHeader.Ymax<PCXHeader.Ymin)Then
  WriteError('Dimensions PCX invalides !');

 ImageWidth:=PCXHeader.Xmax-PCXHeader.Xmin+1;
 ImageHeight:=PCXHeader.Ymax-PCXHeader.Ymin+1;
 If(ImageWidth=0)or(ImageHeight=0)or(ImageWidth>MaxWidth)Then
  WriteError('Dimensions PCX invalides ou trop larges !');

 PCXLineSize:=Word(PCXHeader.BytesPerLine)*Word(PCXHeader.NPlanes);
 If(PCXLineSize=0)or(PCXLineSize>SizeOf(ScanLine))Then WriteError('Ligne PCX trop large !');
 LoadPCXPalette;

 LBMNPlanes:=Byte(PCXBitsPerPixel);
 RowBytes:=((ImageWidth+15)div 16)*2;
 If(RowBytes=0)or(RowBytes>SizeOf(PlaneRow))Then WriteError('Ligne de plan LBM trop large !');

 {$I-}Assign(DestLBM,OutputName);
 Rewrite(DestLBM,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer le fichier ',OutputName);
  Close(SourcePCX);
  Halt;
 End;
 TargetOpened:=True;
 ChunkDepth:=0;

 BeginChunk('FORM');
 WriteID('ILBM');

 BMHDBuf[ 0]:=Byte((ImageWidth shr 8)and $FF);
 BMHDBuf[ 1]:=Byte( ImageWidth        and $FF);
 BMHDBuf[ 2]:=Byte((ImageHeight shr 8)and $FF);
 BMHDBuf[ 3]:=Byte( ImageHeight        and $FF);
 BMHDBuf[ 4]:=0; BMHDBuf[ 5]:=0;
 BMHDBuf[ 6]:=0; BMHDBuf[ 7]:=0;
 BMHDBuf[ 8]:=LBMNPlanes;
 BMHDBuf[ 9]:=0;
 BMHDBuf[10]:=0;
 BMHDBuf[11]:=0;
 BMHDBuf[12]:=0; BMHDBuf[13]:=0;
 BMHDBuf[14]:=1; BMHDBuf[15]:=1;
 BMHDBuf[16]:=Byte((ImageWidth shr 8)and $FF);
 BMHDBuf[17]:=Byte( ImageWidth        and $FF);
 BMHDBuf[18]:=Byte((ImageHeight shr 8)and $FF);
 BMHDBuf[19]:=Byte( ImageHeight        and $FF);
 BeginChunk('BMHD');
 BlockWrite(DestLBM,BMHDBuf,20,ByteWritten);
 EndChunk;

 NumColors:=1 shl LBMNPlanes;
 FillChar(CMAPBuf,LongInt(NumColors)*3,0);
 For X:=0 to NumPal-1 Do Begin
  If X>=NumColors Then Break;
  CMAPBuf[X*3+0]:=Palette[X].R;
  CMAPBuf[X*3+1]:=Palette[X].G;
  CMAPBuf[X*3+2]:=Palette[X].B;
 End;
 BeginChunk('CMAP');
 BlockWrite(DestLBM,CMAPBuf,LongInt(NumColors)*3,ByteWritten);
 EndChunk;

 BeginChunk('BODY');
 For Y:=0 to LongInt(ImageHeight)-1 Do Begin
  DecodePCXScanLine;
  For X:=0 to ImageWidth-1 Do PixelLine[X]:=GetPalIndex(X);
  For Plane:=0 to LBMNPlanes-1 Do Begin
   BuildPlaneRow(Plane);
   BlockWrite(DestLBM,PlaneRow,RowBytes,ByteWritten);
  End;
 End;
 EndChunk;

 EndChunk;

 Close(DestLBM);
 TargetOpened:=False;
 Close(SourcePCX);
 WriteLn('Fichier LBM cree : ',OutputName);
END.
