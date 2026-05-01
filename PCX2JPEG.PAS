{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program PCX2JPEG;

{$A-}

Uses DOS;

Const
  {Constantes du format PCX (ZSoft Picture eXchange).}
 PCXManufacturer=10;
 PCXEncodingRLE=1;
 PCXVGAPaletteMarker=$0C;

  {Largeur maximale support�e (en pixels) pour rester compatible avec les
   contraintes m�moire de Turbo Pascal 7. Une ligne de pixels d�cod�e en 24
   bits ne d�passe ainsi pas une m�moire raisonnable.}
 MaxWidth=4096;

  {Constante pour le calcul du facteur d'�chelle des tables de quantification.}
 OneOverSqrt2=0.70710678118654752440;

  {Marqueurs JPEG}
 MarkerSOI=$D8;
 MarkerEOI=$D9;
 MarkerSOF0=$C0;
 MarkerDHT=$C4;
 MarkerDQT=$DB;
 MarkerSOS=$DA;
 MarkerAPP0=$E0;

  {Ordre zigzag : pour la position k dans le balayage zigzag, ZigZag[k]
   donne l'index naturel (ligne*8+colonne) dans le bloc 8x8.}
 ZigZag:Array[0..63]of Byte=(
   0, 1, 8,16, 9, 2, 3,10,
  17,24,32,25,18,11, 4, 5,
  12,19,26,33,40,48,41,34,
  27,20,13, 6, 7,14,21,28,
  35,42,49,56,57,50,43,36,
  29,22,15,23,30,37,44,51,
  58,59,52,45,38,31,39,46,
  53,60,61,54,47,55,62,63);

  {Table de quantification standard pour la luminance (Annexe K, qualit� 50).}
 StdQTLuma:Array[0..63]of Byte=(
  16,11,10,16, 24, 40, 51, 61,
  12,12,14,19, 26, 58, 60, 55,
  14,13,16,24, 40, 57, 69, 56,
  14,17,22,29, 51, 87, 80, 62,
  18,22,37,56, 68,109,103, 77,
  24,35,55,64, 81,104,113, 92,
  49,64,78,87,103,121,120,101,
  72,92,95,98,112,100,103, 99);

  {Table de quantification standard pour la chrominance (Annexe K, qualit� 50).}
 StdQTChroma:Array[0..63]of Byte=(
  17,18,24,47,99,99,99,99,
  18,21,26,66,99,99,99,99,
  24,26,56,99,99,99,99,99,
  47,66,99,99,99,99,99,99,
  99,99,99,99,99,99,99,99,
  99,99,99,99,99,99,99,99,
  99,99,99,99,99,99,99,99,
  99,99,99,99,99,99,99,99);

  {Tables Huffman standard JPEG (Annexe K). Pour chaque table : 16 octets
   donnant, pour chaque longueur de code de 1 � 16, le nombre de codes de
   cette longueur, suivis de la liste des valeurs (octets) associ�es aux
   codes, par ordre croissant de longueur.}
 StdDCLumaCounts:Array[0..15]of Byte=
   (0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0);
 StdDCLumaValues:Array[0..11]of Byte=
   (0,1,2,3,4,5,6,7,8,9,10,11);

 StdDCChromaCounts:Array[0..15]of Byte=
   (0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0);
 StdDCChromaValues:Array[0..11]of Byte=
   (0,1,2,3,4,5,6,7,8,9,10,11);

 StdACLumaCounts:Array[0..15]of Byte=
   (0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,$7D);
 StdACLumaValues:Array[0..161]of Byte=(
  $01,$02,$03,$00,$04,$11,$05,$12,$21,$31,$41,$06,$13,$51,$61,$07,
  $22,$71,$14,$32,$81,$91,$A1,$08,$23,$42,$B1,$C1,$15,$52,$D1,$F0,
  $24,$33,$62,$72,$82,$09,$0A,$16,$17,$18,$19,$1A,$25,$26,$27,$28,
  $29,$2A,$34,$35,$36,$37,$38,$39,$3A,$43,$44,$45,$46,$47,$48,$49,
  $4A,$53,$54,$55,$56,$57,$58,$59,$5A,$63,$64,$65,$66,$67,$68,$69,
  $6A,$73,$74,$75,$76,$77,$78,$79,$7A,$83,$84,$85,$86,$87,$88,$89,
  $8A,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$A2,$A3,$A4,$A5,$A6,$A7,
  $A8,$A9,$AA,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$C2,$C3,$C4,$C5,
  $C6,$C7,$C8,$C9,$CA,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$E1,$E2,
  $E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,
  $F9,$FA);

 StdACChromaCounts:Array[0..15]of Byte=
   (0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,$77);
 StdACChromaValues:Array[0..161]of Byte=(
  $00,$01,$02,$03,$11,$04,$05,$21,$31,$06,$12,$41,$51,$07,$61,$71,
  $13,$22,$32,$81,$08,$14,$42,$91,$A1,$B1,$C1,$09,$23,$33,$52,$F0,
  $15,$62,$72,$D1,$0A,$16,$24,$34,$E1,$25,$F1,$17,$18,$19,$1A,$26,
  $27,$28,$29,$2A,$35,$36,$37,$38,$39,$3A,$43,$44,$45,$46,$47,$48,
  $49,$4A,$53,$54,$55,$56,$57,$58,$59,$5A,$63,$64,$65,$66,$67,$68,
  $69,$6A,$73,$74,$75,$76,$77,$78,$79,$7A,$82,$83,$84,$85,$86,$87,
  $88,$89,$8A,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$A2,$A3,$A4,$A5,
  $A6,$A7,$A8,$A9,$AA,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$C2,$C3,
  $C4,$C5,$C6,$C7,$C8,$C9,$CA,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,
  $E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$F2,$F3,$F4,$F5,$F6,$F7,$F8,
  $F9,$FA);
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

 Block64=Array[0..63]of Real;
 IBlock64=Array[0..63]of Integer;

Var
 SourcePCX,DestJPEG:File;
 PCXHeader:HeaderPCX;
 PCXLineSize,ByteReaded,ByteWritten:Word;
 NumPal:Word;
 Palette:Array[0..255]of RGB;
 ScanLine:Array[0..MaxWidth*3+4-1]of Byte;
 LineBuf:Array[0..MaxWidth*3-1]of Byte;     { Une ligne decompressee en 24 bits BGR }
 SourceFileName,OutputName:String;
 Quality:Integer;
  {Tables de quantification effectives (apr�s ajustement du facteur de qualit�)}
 QTLuma,QTChroma:Array[0..63]of Byte;

  {Tables Huffman effectives : codes et tailles index�s par symbole.}
 DCLumaCode,ACLumaCode,DCChromaCode,ACChromaCode:Array[0..255]of Word;
 DCLumaSize,ACLumaSize,DCChromaSize,ACChromaSize:Array[0..255]of Byte;

  {Table des cosinus pr�calcul�e pour la DCT.}
 CosTab:Array[0..7,0..7]of Real;

  {Tampons de bande (8 lignes de pixels) pour Y, Cb, Cr. Chaque tampon est
   allou� sur le tas car peut atteindre 8*4096 octets.}
 YBuf,CbBuf,CrBuf:Pointer;
 StripeWidth:Word;        { Largeur effective (multiple de 8) }
 StripeBytes:Word;        { 8 * StripeWidth }
 ImageWidth,ImageHeight:Word;

  {�tat du flux de bits pour l'�criture entropique.}
 BitBuffer:LongInt;
 BitsInBuffer:Integer;

  {DC pr�c�dent pour chaque composante (codage diff�rentiel).}
 PrevDCY,PrevDCCb,PrevDCCr:Integer;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.JPG';
End;

Procedure WriteByteToFile(B:Byte);
Begin
 BlockWrite(DestJPEG,B,1,ByteWritten);
End;

Procedure WriteWordToFile(W:Word);
Var
 Hi,Lo:Byte;
Begin
  {JPEG utilise l'ordre big-endian (octet de poids fort en premier).}
 Hi:=Byte((W shr 8)and $FF);
 Lo:=Byte(W and $FF);
 BlockWrite(DestJPEG,Hi,1,ByteWritten);
 BlockWrite(DestJPEG,Lo,1,ByteWritten);
End;

Procedure WriteMarker(M:Byte);
Var
 FF:Byte;
Begin
 FF:=$FF;
 BlockWrite(DestJPEG,FF,1,ByteWritten);
 BlockWrite(DestJPEG,M,1,ByteWritten);
End;

  {Initialise la table de cosinus utilis�e par la DCT.}
Procedure InitCosTab;
Var
 I,J:Integer;
Begin
 For I:=0 to 7 Do
  For J:=0 to 7 Do
   CosTab[I,J]:=Cos((2*I+1)*J*Pi/16);
End;

  {Calcule les tables de quantification effectives pour le facteur de qualit�
   (1..100). Suit la formule traditionnelle de la libjpeg :
     scale = 5000/Q  si Q<50, sinon 200-2*Q
     q'    = (q*scale + 50) div 100, born� � [1, 255].}
Procedure BuildQuantTables(Q:Integer);
Var
 I:Integer;
 Scale,V:LongInt;
Begin
 If Q<1 Then Q:=1;
 If Q>100 Then Q:=100;
 If Q<50 Then Scale:=LongInt(5000)div LongInt(Q)
         Else Scale:=200-2*LongInt(Q);
 For I:=0 to 63 Do Begin
  V:=(LongInt(StdQTLuma[I])*Scale+50)div 100;
  If V<1 Then V:=1;
  If V>255 Then V:=255;
  QTLuma[I]:=Byte(V);
  V:=(LongInt(StdQTChroma[I])*Scale+50)div 100;
  If V<1 Then V:=1;
  If V>255 Then V:=255;
  QTChroma[I]:=Byte(V);
 End;
End;

  {Construit, � partir d'une description JPEG (BITS + HUFFVAL), les tableaux
   "code" et "taille" index�s par symbole. Suit la proc�dure de l'Annexe C
   de la norme T.81.}
Procedure BuildHuffTable(Const Counts:Array of Byte;Const Values:Array of Byte;
                         NumValues:Integer;
                         Var Codes:Array of Word;Var Sizes:Array of Byte);
Var
 I,J,K:Integer;
 Code:Word;
 Size:Integer;
 HuffSize:Array[0..256]of Byte;
 HuffCode:Array[0..256]of Word;
Begin
  {�tape 1 : liste HUFFSIZE.}
 K:=0;
 For I:=1 to 16 Do
  For J:=1 to Counts[I-1] Do Begin
   HuffSize[K]:=Byte(I);
   Inc(K);
  End;
 HuffSize[K]:=0;
  {�tape 2 : liste HUFFCODE.}
 Code:=0;
 Size:=HuffSize[0];
 K:=0;
 While HuffSize[K]<>0 Do Begin
  While(HuffSize[K]<>0)and(Integer(HuffSize[K])=Size)Do Begin
   HuffCode[K]:=Code;
   Inc(Code);
   Inc(K);
  End;
  If HuffSize[K]=0 Then Break;
  Repeat
   Code:=Word(Code shl 1);
   Inc(Size);
  Until Integer(HuffSize[K])=Size;
 End;
  {�tape 3 : ranger codes et tailles index�s par symbole.}
 For I:=0 to 255 Do Begin
  Codes[I]:=0;
  Sizes[I]:=0;
 End;
 For I:=0 to NumValues-1 Do Begin
  Codes[Values[I]]:=HuffCode[I];
  Sizes[Values[I]]:=HuffSize[I];
 End;
End;

Procedure BuildAllHuffTables;
Begin
 BuildHuffTable(StdDCLumaCounts,StdDCLumaValues,12,DCLumaCode,DCLumaSize);
 BuildHuffTable(StdDCChromaCounts,StdDCChromaValues,12,DCChromaCode,DCChromaSize);
 BuildHuffTable(StdACLumaCounts,StdACLumaValues,162,ACLumaCode,ACLumaSize);
 BuildHuffTable(StdACChromaCounts,StdACChromaValues,162,ACChromaCode,ACChromaSize);
End;

  {DCT 2D 8x8 directe (formule s�parable simple). Le bloc d'entr�e contient
   les �chantillons d�cal�s de niveau (-128). Le bloc de sortie contient les
   coefficients DCT en ordre naturel.}
Procedure ForwardDCT(Var Block:Block64);
Var
 U,V,X,Y:Integer;
 Sum,Cu,Cv:Real;
 Tmp:Block64;
Begin
 For V:=0 to 7 Do Begin
  If V=0 Then Cv:=OneOverSqrt2 Else Cv:=1.0;
  For U:=0 to 7 Do Begin
   If U=0 Then Cu:=OneOverSqrt2 Else Cu:=1.0;
   Sum:=0.0;
   For Y:=0 to 7 Do
    For X:=0 to 7 Do
     Sum:=Sum+Block[Y*8+X]*CosTab[X,U]*CosTab[Y,V];
   Tmp[V*8+U]:=0.25*Cu*Cv*Sum;
  End;
 End;
 For U:=0 to 63 Do Block[U]:=Tmp[U];
End;

  {Quantifie le bloc DCT par division enti�re arrondie au plus proche, puis
   r�organise les coefficients selon l'ordre zigzag.}
Procedure QuantizeAndZigZag(Const Src:Block64;Const QT:Array of Byte;
                            Var Dst:IBlock64);
Var
 I:Integer;
 V:Real;
 Q:Integer;
Begin
 For I:=0 to 63 Do Begin
  V:=Src[ZigZag[I]];
  Q:=QT[ZigZag[I]];
  If V>=0 Then Dst[I]:=Trunc((V+Q/2)/Q)
          Else Dst[I]:=-Trunc((-V+Q/2)/Q);
 End;
End;

  {�criture de "Size" bits de "Bits" dans le flux de sortie (poids fort en
   premier). Octet 0xFF �mis -> ajout de 0x00 pour respecter la r�gle de
   "byte stuffing" de JPEG.}
Procedure WriteBits(Bits:Word;Size:Integer);
Var
 B:Byte;
 Mask:LongInt;
 Pad:Byte;
Begin
 If Size=0 Then Exit;
 Mask:=(LongInt(1)shl Size)-1;
 BitBuffer:=(BitBuffer shl Size)or(LongInt(Bits)and Mask);
 Inc(BitsInBuffer,Size);
 While BitsInBuffer>=8 Do Begin
  Dec(BitsInBuffer,8);
  B:=Byte((BitBuffer shr BitsInBuffer)and $FF);
  BlockWrite(DestJPEG,B,1,ByteWritten);
  If B=$FF Then Begin
   Pad:=0;
   BlockWrite(DestJPEG,Pad,1,ByteWritten);
  End;
 End;
End;

  {Termine le flux de bits courant en compl�tant le dernier octet par des
   bits 1 (compl�ment de remplissage exig� par JPEG).}
Procedure FlushBits;
Var
 B,Pad:Byte;
 Pad1:Integer;
Begin
 If BitsInBuffer>0 Then Begin
  Pad1:=8-BitsInBuffer;
  BitBuffer:=(BitBuffer shl Pad1)or((LongInt(1)shl Pad1)-1);
  BitsInBuffer:=8;
  Dec(BitsInBuffer,8);
  B:=Byte(BitBuffer and $FF);
  BlockWrite(DestJPEG,B,1,ByteWritten);
  If B=$FF Then Begin
   Pad:=0;
   BlockWrite(DestJPEG,Pad,1,ByteWritten);
  End;
 End;
 BitBuffer:=0;
 BitsInBuffer:=0;
End;

  {Calcule la cat�gorie SSSS et le motif de bits pour un coefficient sign�.}
Procedure EncodeCoef(Value:Integer;Var Size:Integer;Var Bits:Word);
Var
 AV:Integer;
Begin
 AV:=Abs(Value);
 Size:=0;
 While AV<>0 Do Begin
  Inc(Size);
  AV:=AV shr 1;
 End;
 If Value<0 Then
  Bits:=Word((Value+(LongInt(1)shl Size)-1)and((LongInt(1)shl Size)-1))
  Else
  Bits:=Word(Value);
End;

  {Encode un bloc 8x8 quantifi� (en ordre zigzag) dans le flux entropique en
   utilisant les tables Huffman DC et AC fournies.}
Procedure EncodeBlock(Const ZZ:IBlock64;Var PrevDC:Integer;
                      Const DCCode:Array of Word;Const DCSize:Array of Byte;
                      Const ACCode:Array of Word;Const ACSize:Array of Byte);
Var
 K,RunLen,Size:Integer;
 Diff:Integer;
 Bits:Word;
 RS:Integer;
Begin
  {Coefficient DC : codage diff�rentiel.}
 Diff:=ZZ[0]-PrevDC;
 PrevDC:=ZZ[0];
 EncodeCoef(Diff,Size,Bits);
 WriteBits(DCCode[Size],DCSize[Size]);
 If Size>0 Then WriteBits(Bits,Size);
  {Coefficients AC : ZRL pour 16 z�ros, EOB pour fin de bloc.}
 K:=1;
 While K<=63 Do Begin
  RunLen:=0;
  While(K<=63)and(ZZ[K]=0)Do Begin
   Inc(K); Inc(RunLen);
  End;
  If K>63 Then Begin
   WriteBits(ACCode[$00],ACSize[$00]);  { EOB }
   Break;
  End;
  While RunLen>=16 Do Begin
   WriteBits(ACCode[$F0],ACSize[$F0]); { ZRL }
   Dec(RunLen,16);
  End;
  EncodeCoef(ZZ[K],Size,Bits);
  RS:=(RunLen shl 4)or Size;
  WriteBits(ACCode[RS],ACSize[RS]);
  If Size>0 Then WriteBits(Bits,Size);
  Inc(K);
 End;
End;

  {Conversions RGB -> YCbCr (BT.601). Les composantes Cb et Cr sont d�cal�es
   de +128 pour rester dans [0..255].}
Function ClampByte(V:Real):Byte;
Begin
 If V<0.0 Then ClampByte:=0
  Else
 If V>255.0 Then ClampByte:=255
  Else
 ClampByte:=Byte(Trunc(V+0.5));
End;
Function PCXBitsPerPixel:Word;
Begin
 If(PCXHeader.BitsPerPixel=1)and(PCXHeader.NPlanes=1)Then PCXBitsPerPixel:=1
 Else If(PCXHeader.BitsPerPixel=1)and(PCXHeader.NPlanes=4)Then PCXBitsPerPixel:=4
 Else If(PCXHeader.BitsPerPixel=8)and(PCXHeader.NPlanes=1)Then PCXBitsPerPixel:=8
 Else If(PCXHeader.BitsPerPixel=8)and(PCXHeader.NPlanes=3)Then PCXBitsPerPixel:=24
 Else PCXBitsPerPixel:=0;
End;

Procedure WriteError(Const S:String);
Begin
 WriteLn(S);
 Close(SourcePCX);
 Halt;
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

Procedure ReadPCXRowAsRGB;
Var
 X:Word;
 Idx:Byte;
Begin
 DecodePCXScanLine;
 Case PCXBitsPerPixel of
  1:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Idx:=GetPlaneBit(0,X);
    LineBuf[X*3]  :=Palette[Idx].B;
    LineBuf[X*3+1]:=Palette[Idx].G;
    LineBuf[X*3+2]:=Palette[Idx].R;
   End;
  End;
  4:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Idx:=GetPlaneBit(0,X) or (GetPlaneBit(1,X)shl 1) or
         (GetPlaneBit(2,X)shl 2) or (GetPlaneBit(3,X)shl 3);
    LineBuf[X*3]  :=Palette[Idx].B;
    LineBuf[X*3+1]:=Palette[Idx].G;
    LineBuf[X*3+2]:=Palette[Idx].R;
   End;
  End;
  8:Begin
   For X:=0 to ImageWidth-1 Do Begin
    Idx:=ScanLine[X];
    LineBuf[X*3]  :=Palette[Idx].B;
    LineBuf[X*3+1]:=Palette[Idx].G;
    LineBuf[X*3+2]:=Palette[Idx].R;
   End;
  End;
  24:Begin
   For X:=0 to ImageWidth-1 Do Begin
    LineBuf[X*3]  :=ScanLine[Word(PCXHeader.BytesPerLine)*2+X];
    LineBuf[X*3+1]:=ScanLine[PCXHeader.BytesPerLine+X];
    LineBuf[X*3+2]:=ScanLine[X];
   End;
  End;
 End;
End;

Type
 PByteArr=^TByteArr;
 TByteArr=Array[0..32767]of Byte;

Procedure ConvertRowToYCbCr(Y8:PByteArr;Cb8:PByteArr;Cr8:PByteArr;
                            DstRowOffset:Word);
Var
 X:Word;
 R,G,B:Byte;
 YV,CbV,CrV:Real;
 LastB,LastG,LastR:Byte;
Begin
 LastB:=0; LastG:=0; LastR:=0;
 For X:=0 to StripeWidth-1 Do Begin
  If X<ImageWidth Then Begin
   B:=LineBuf[X*3];
   G:=LineBuf[X*3+1];
   R:=LineBuf[X*3+2];
   LastB:=B; LastG:=G; LastR:=R;
  End
   Else
  Begin
    {R�plique du dernier pixel pour le bourrage de bord.}
   B:=LastB; G:=LastG; R:=LastR;
  End;
  YV :=  0.299*R+0.587*G+0.114*B;
  CbV:= -0.168736*R-0.331264*G+0.5*B+128.0;
  CrV:=  0.5*R-0.418688*G-0.081312*B+128.0;
  Y8^[DstRowOffset+X]:=ClampByte(YV);
  Cb8^[DstRowOffset+X]:=ClampByte(CbV);
  Cr8^[DstRowOffset+X]:=ClampByte(CrV);
 End;
End;

  {Extrait un bloc 8x8 d'une bande de pixels (composante donn�e) en niveau
   d�cal� (samples - 128).}
Procedure ExtractBlock(Buf:PByteArr;ColX:Word;ValidRows:Word;Var Block:Block64);
Var
 R,C:Integer;
 SrcRow:Word;
Begin
 For R:=0 to 7 Do Begin
  If Word(R)<ValidRows Then SrcRow:=Word(R)
                       Else SrcRow:=ValidRows-1; { r�plique de la derni�re ligne valide }
  For C:=0 to 7 Do
   Block[R*8+C]:=Integer(Buf^[SrcRow*StripeWidth+ColX+Word(C)])-128;
 End;
End;

  {�crit l'en-t�te APP0 / JFIF.}
Procedure WriteJFIFHeader;
Var
 ID:Array[0..4]of Char;
Begin
 WriteMarker(MarkerAPP0);
 WriteWordToFile(16);   { Longueur du segment }
 ID[0]:='J'; ID[1]:='F'; ID[2]:='I'; ID[3]:='F'; ID[4]:=#0;
 BlockWrite(DestJPEG,ID,5,ByteWritten);
 WriteByteToFile(1);    { Version majeure }
 WriteByteToFile(1);    { Version mineure }
 WriteByteToFile(0);    { Unit�s : 0 = aucune (ratio uniquement) }
 WriteWordToFile(1);    { Densit� X }
 WriteWordToFile(1);    { Densit� Y }
 WriteByteToFile(0);    { Largeur de la vignette }
 WriteByteToFile(0);    { Hauteur de la vignette }
End;

  {�crit un segment DQT contenant une table de quantification 8 bits.}
Procedure WriteDQT(TableID:Byte;Const QT:Array of Byte);
Var
 I:Integer;
 B:Byte;
Begin
 WriteMarker(MarkerDQT);
 WriteWordToFile(67);          { 2 (longueur) + 1 (Pq/Tq) + 64 (valeurs) }
 WriteByteToFile(TableID);     { Pq=0 (8 bits) | Tq dans les 4 bits faibles }
 For I:=0 to 63 Do Begin
   {Les valeurs sont �crites dans l'ordre zigzag.}
  B:=QT[ZigZag[I]];
  WriteByteToFile(B);
 End;
End;

  {�crit le segment SOF0 (Baseline DCT, 3 composantes Y/Cb/Cr en 4:4:4).}
Procedure WriteSOF0;
Begin
 WriteMarker(MarkerSOF0);
 WriteWordToFile(17);              { 2+1+2+2+1+3*3 }
 WriteByteToFile(8);               { Pr�cision : 8 bits par �chantillon }
 WriteWordToFile(ImageHeight);
 WriteWordToFile(ImageWidth);
 WriteByteToFile(3);               { Nombre de composantes }
  {Composante Y}
 WriteByteToFile(1); WriteByteToFile($11); WriteByteToFile(0);
  {Composante Cb}
 WriteByteToFile(2); WriteByteToFile($11); WriteByteToFile(1);
  {Composante Cr}
 WriteByteToFile(3); WriteByteToFile($11); WriteByteToFile(1);
End;

  {�crit un segment DHT.}
Procedure WriteDHT(TableClassAndID:Byte;Const Counts:Array of Byte;
                   Const Values:Array of Byte;NumValues:Integer);
Var
 I:Integer;
Begin
 WriteMarker(MarkerDHT);
 WriteWordToFile(Word(2+1+16+NumValues));
 WriteByteToFile(TableClassAndID);
 For I:=0 to 15 Do WriteByteToFile(Counts[I]);
 For I:=0 to NumValues-1 Do WriteByteToFile(Values[I]);
End;

  {�crit le segment SOS pour 3 composantes en s�quentiel baseline.}
Procedure WriteSOS;
Begin
 WriteMarker(MarkerSOS);
 WriteWordToFile(12);              { 2+1+2*3+3 }
 WriteByteToFile(3);               { Nombre de composantes du scan }
  {Y : DC=0 / AC=0}
 WriteByteToFile(1); WriteByteToFile($00);
  {Cb : DC=1 / AC=1}
 WriteByteToFile(2); WriteByteToFile($11);
  {Cr : DC=1 / AC=1}
 WriteByteToFile(3); WriteByteToFile($11);
 WriteByteToFile(0);               { Ss = 0 }
 WriteByteToFile(63);              { Se = 63 }
 WriteByteToFile(0);               { Ah/Al = 0 }
End;

Var
 I:Integer;
 BlockY,BlockCb,BlockCr:Block64;
 ZZBlock:IBlock64;
 MCUCol:Word;
 ValidRows:Word;
 Y,Y2:LongInt;
BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PCX2JPEG : Cette commande permet de convertir une image PCX (.PCX) ',
                     'en format JPEG (.JPG).');
  WriteLn;
  WriteLn('Syntaxe : PCX2JPEG source.PCX [destination.JPG] [qualite]');
  WriteLn;
  WriteLn(' source.PCX      Ce parametre permet d''indiquer le nom du fichier ".PCX".');
  WriteLn(' destination.JPG Ce parametre permet d''indiquer le nom du fichier ".JPG".');
  WriteLn(' qualite         Facteur de qualite JPEG entre 1 et 100 (75 par defaut).');
  WriteLn;
  WriteLn('Si destination est omis, le fichier resultant porte le meme nom avec l''extension .JPG.');
  WriteLn('Les PCX RLE 1 bit, 16 couleurs, 256 couleurs et 24 bits sont supportes.');
  Halt;
 End;
 If ParamCount<1 Then Begin
  WriteLn('Parametre requis !');
  Halt;
 End;

 SourceFileName:=ParamStr(1);
 OutputName:=Path2NameExt(SourceFileName);
 Quality:=75;
 If ParamCount>=2 Then Begin
  Val(ParamStr(2),Quality,I);
  If I=0 Then Begin
   If(Quality<1)or(Quality>100)Then Begin
    WriteLn('Qualite invalide (1..100) !');
    Halt;
   End;
  End
   Else
  Begin
   OutputName:=ParamStr(2);
   Quality:=75;
  End;
 End;
 If ParamCount>=3 Then Begin
  Val(ParamStr(3),Quality,I);
  If(I<>0)or(Quality<1)or(Quality>100)Then Begin
   WriteLn('Qualite invalide (1..100) !');
   Halt;
  End;
 End;

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

 StripeWidth:=((ImageWidth+7)shr 3)shl 3;
 StripeBytes:=StripeWidth*8;

 LoadPCXPalette;

  {Preparation des tables.}
 InitCosTab;
 BuildQuantTables(Quality);
 BuildAllHuffTables;

  {Allocation des tampons de bande.}
 GetMem(YBuf,StripeBytes);
 GetMem(CbBuf,StripeBytes);
 GetMem(CrBuf,StripeBytes);

  {Cr�ation du fichier JPEG.}
 {$I-}Assign(DestJPEG,OutputName);
 Rewrite(DestJPEG,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de cr�er le fichier ',OutputName);
  FreeMem(YBuf,StripeBytes);
  FreeMem(CbBuf,StripeBytes);
  FreeMem(CrBuf,StripeBytes);
  Close(SourcePCX);
  Halt;
 End;

  {En-t�tes JPEG.}
 WriteMarker(MarkerSOI);
 WriteJFIFHeader;
 WriteDQT($00,QTLuma);     { Tq=0, Pq=0 }
 WriteDQT($01,QTChroma);   { Tq=1, Pq=0 }
 WriteSOF0;
 WriteDHT($00,StdDCLumaCounts,StdDCLumaValues,12);     { Classe DC, table 0 }
 WriteDHT($10,StdACLumaCounts,StdACLumaValues,162);    { Classe AC, table 0 }
 WriteDHT($01,StdDCChromaCounts,StdDCChromaValues,12); { Classe DC, table 1 }
 WriteDHT($11,StdACChromaCounts,StdACChromaValues,162);{ Classe AC, table 1 }
 WriteSOS;

  {�tat initial du flux de bits et des DC pr�c�dents.}
 BitBuffer:=0;
 BitsInBuffer:=0;
 PrevDCY:=0; PrevDCCb:=0; PrevDCCr:=0;

  {Boucle sur les bandes (lignes de MCU). Les PCX sont stockes du haut vers le bas.}
 Y:=0;
 While Y<LongInt(ImageHeight)Do Begin
   {Calcul du nombre de lignes valides dans cette bande (1..8).}
  If Y+8<=LongInt(ImageHeight)Then ValidRows:=8
                              Else ValidRows:=Word(LongInt(ImageHeight)-Y);
   {Lecture de chaque ligne valide depuis le PCX.}
  For Y2:=0 to LongInt(ValidRows)-1 Do Begin
   ReadPCXRowAsRGB;
   ConvertRowToYCbCr(YBuf,CbBuf,CrBuf,Word(Y2)*StripeWidth);
  End;
   {Encodage des MCU de la bande.}
  MCUCol:=0;
  While MCUCol<StripeWidth Do Begin
   ExtractBlock(YBuf,MCUCol,ValidRows,BlockY);
   ForwardDCT(BlockY);
   QuantizeAndZigZag(BlockY,QTLuma,ZZBlock);
   EncodeBlock(ZZBlock,PrevDCY,DCLumaCode,DCLumaSize,
               ACLumaCode,ACLumaSize);

   ExtractBlock(CbBuf,MCUCol,ValidRows,BlockCb);
   ForwardDCT(BlockCb);
   QuantizeAndZigZag(BlockCb,QTChroma,ZZBlock);
   EncodeBlock(ZZBlock,PrevDCCb,DCChromaCode,DCChromaSize,
               ACChromaCode,ACChromaSize);

   ExtractBlock(CrBuf,MCUCol,ValidRows,BlockCr);
   ForwardDCT(BlockCr);
   QuantizeAndZigZag(BlockCr,QTChroma,ZZBlock);
   EncodeBlock(ZZBlock,PrevDCCr,DCChromaCode,DCChromaSize,
               ACChromaCode,ACChromaSize);

   Inc(MCUCol,8);
  End;
  Inc(Y,8);
 End;

 FlushBits;
 WriteMarker(MarkerEOI);

 Close(DestJPEG);
 Close(SourcePCX);
 FreeMem(YBuf,StripeBytes);
 FreeMem(CbBuf,StripeBytes);
 FreeMem(CrBuf,StripeBytes);
END.
