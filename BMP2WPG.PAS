{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program BMP2WPG;

{$A-}

Uses DOS;

Const
  {Type de compression Windows}
 bi_RGB=0;
 bi_RLE8=1;
 bi_RLE4=2;

  {Largeur maximale support�e (en pixels).}
 MaxWidth=4096;

  {Constantes du format WPG (WordPerfect Graphics, version 1).
   Toutes les valeurs num�riques multi-octets sont stock�es en
   "little-endian" (ordre Intel) puisque WPG est issu du monde MS-DOS.}
 WPGMagic0=$FF;          { Octets de signature : FF 57 50 43 ('�WPC') }
 WPGMagic1=$57;
 WPGMagic2=$50;
 WPGMagic3=$43;
 WPGProductType=1;       { 1 = WordPerfect }
 WPGFileType=22;         { 22 = fichier graphique WPG }
 WPGVersionMajor=1;
 WPGVersionMinor=0;

  {Types d'enregistrement utilis�s.}
 WPGRecStart=$0F;        { D�but d'image }
 WPGRecEnd=$10;          { Fin d'image }
 WPGRecColorMap=$0E;     { Palette de couleurs }
 WPGRecBitmap1=$0B;      { Bitmap type 1 (sans positionnement) }

  {Maximum d'octets dans une "course litt�rale" RLE WPG : le compteur
   est cod� sur 7 bits (le bit haut indique une r�p�tition).}
 MaxRunLen=127;

Type
 RGB32=Record
  B,G,R,FreeByte:Byte;
 End;

 HeaderBMP=Record
  Sign:Array[0..1]of Char;
  Size,Reserved0,OffBits:LongInt;
  biSize,NumXPixels,NumYPixels:LongInt;
  Planes,BitCount:Word;
  Compression,SizeImage:LongInt;
  XPelsPerMeter,YPelsPerMeter,ClrUsed,ClrImportant:LongInt;
 End;

 BitmapInfoHeader=Record
  biSize:LongInt;         { Sp�cifie le nombre d'octets requis pour la structure }
  biWidth:LongInt;        { Sp�cifie la largeur du BitMap en pixels }
  biHeight:LongInt;       { Sp�cifie la hauteur du BitMap en pixels }
  biPlanes:Word;          { Sp�cifie le nombre de plane pour la destination }
  biBitCount:Word;        { Sp�cifie le nombre de bits par pixel (1, 4, 8, 24)}
  biCompression:LongInt;  { Sp�cifie le style de compression: BI_RGB, BI_RLE8, BI_RLE4 }
  biSizeImage:LongInt;    { Sp�cifie la taille en octets pour l'image }
  biXPelsPerMeter:LongInt;{ Sp�cifie le nombre horizontal de pixels par mStre }
  biYPelsPerMeter:LongInt;{ Sp�cifie le nombre vertical de pixels par mStre }
  biClrUsed:LongInt;      { Sp�cifie le nombre de couleurs index�s dans la table}
  biClrImportant:LongInt; { Sp�cifie le nombre de couleurs index�s dans la table
                            en comptant ceux �tant vraiment indispensable � l'affichage}
 End;

Var
 SourceBMP,DestWPG:File;
 Header:HeaderBMP;
 BIH:BitMapInfoHeader;
 BMPBytesPerLine,ByteReaded,ByteWritten:Word;
 StartPos:LongInt;
 NumPal:Word;
 Palette:Array[0..255]of RGB32;
 BMPLine:Array[0..MaxWidth*3-1]of Byte;
 OutLine:Array[0..MaxWidth*3-1]of Byte;
 OutputName:String;
 ImageWidth,ImageHeight:Word;
 BMPBPL:LongInt;
 WPGBytesPerLine:Word;
 I:Integer;
 Y:LongInt;

Function Path2NameExt(Const Path:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+'.WPG';
End;

  {�criture d'un mot 16 bits en little-endian (ordre Intel) dans le
   fichier de destination.}
Procedure WriteWordLE(W:Word);
Var
 Buf:Array[0..1]of Byte;
Begin
 Buf[0]:=Byte(W and $FF);
 Buf[1]:=Byte((W shr 8)and $FF);
 BlockWrite(DestWPG,Buf,2,ByteWritten);
End;

  {�criture d'un long 32 bits en little-endian.}
Procedure WriteLongLE(L:LongInt);
Var
 Buf:Array[0..3]of Byte;
Begin
 Buf[0]:=Byte(L and $FF);
 Buf[1]:=Byte((L shr 8)and $FF);
 Buf[2]:=Byte((L shr 16)and $FF);
 Buf[3]:=Byte((L shr 24)and $FF);
 BlockWrite(DestWPG,Buf,4,ByteWritten);
End;

Procedure WriteByte(B:Byte);
Begin
 BlockWrite(DestWPG,B,1,ByteWritten);
End;

  {�criture de la longueur variable d'un enregistrement WPG :
    - si Len < $FF : un seul octet contient la longueur ;
    - sinon : octet $FF suivi d'un mot 16 bits little-endian.
   Cette forme variable est indispensable pour les enregistrements
   bitmap qui d�passent g�n�ralement 254 octets.}
Procedure WriteRecLength(Len:LongInt);
Begin
 If Len<$FF Then WriteByte(Byte(Len))
            Else Begin
             WriteByte($FF);
             WriteWordLE(Word(Len));
            End;
End;

  {Lit la ligne brute du BMP (index RowIndex, 0 = haut) dans BMPLine.}
Procedure ReadBmpRow(RowIndex:LongInt);
Begin
 Seek(SourceBMP,StartPos+RowIndex*LongInt(BMPBytesPerLine));
 BlockRead(SourceBMP,BMPLine,BMPBytesPerLine,ByteReaded);
End;

  {�crit une scanline d�j� compact�e (sans bourrage) en RLE WPG.
   On n'utilise que des "courses litt�rales" de 1 � 127 octets : c'est
   parfaitement conforme � la sp�cification (un compteur sans bit haut
   suivi de 'count' octets bruts) et lisible par tous les d�codeurs WPG.}
Procedure WriteScanlineRLE(Var Line; LineLen:Word);
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
  Buf:=Byte(Chunk);                  { 1..127, bit 7 � 0 = course litt�rale }
  BlockWrite(DestWPG,Buf,1,ByteWritten);
  BlockWrite(DestWPG,P^,Chunk,ByteWritten);
  Inc(P,Chunk);
  Dec(Remaining,Chunk);
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('BMP2WPG : Cette commande permet de convertir une image BitMap (.BMP) ',
                    'en fichier WordPerfect Graphics (.WPG).');
  WriteLn;
  WriteLn('Syntaxe : BMP2WPG nomdufichier.BMP');
  WriteLn;
  WriteLn(' nomdufichier   Nom du fichier ".BMP" � convertir.');
  WriteLn;
  WriteLn('Le fichier r�sultant porte le m�me nom avec l''extension .WPG.');
  WriteLn('Seuls les BitMaps 1, 4 ou 8 bits par pixel non compress�s sont support�s ',
          '(le format WPG version 1 ne g�re pas les images en couleurs vraies).');
  Halt;
 End;
 If ParamCount<1 Then Begin
  WriteLn('Param�tre requis !');
  Halt;
 End;
 {$I-}Assign(SourceBMP,ParamStr(1));
 Reset(SourceBMP,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de lire le fichier d''image');
  Halt;
 End;
 BlockRead(SourceBMP,Header,SizeOf(Header),ByteReaded);
 If Header.Sign<>'BM'Then Begin
  WriteLn('Signature d''ent�te Bitmap introuvable !');
  Close(SourceBMP);
  Halt;
 End;
 Seek(SourceBMP,14);
 BlockRead(SourceBMP,BIH,SizeOf(BIH),ByteReaded);
  {WPG1 ne supporte que les images index�es 1, 2, 4 ou 8 bits par pixel.
   Le format BMP n'expose que 1, 4, 8 et 24 ; on rejette donc 24 bpp.}
 If(BIH.biBitCount<>1)and(BIH.biBitCount<>4)and(BIH.biBitCount<>8)Then Begin
  WriteLn('Seuls les BitMaps 1, 4 ou 8 bits par pixel sont support�s pour la conversion en WPG !');
  Close(SourceBMP);
  Halt(2);
 End;
 If BIH.biCompression<>bi_RGB Then Begin
  WriteLn('Compression RLE4 ou RLE8 non support�');
  Close(SourceBMP);
  Halt(3);
 End;
 If(BIH.biWidth<=0)or(BIH.biHeight<=0)Then Begin
  WriteLn('Dimensions invalides !');
  Close(SourceBMP);
  Halt;
 End;
 If LongInt(BIH.biWidth)>MaxWidth Then Begin
  WriteLn('Image trop large (largeur max : ',MaxWidth,') !');
  Close(SourceBMP);
  Halt;
 End;

  {Calcul du nombre d'octets par scanline c�t� BMP (avec bourrage sur
   4 octets) et c�t� WPG (sans bourrage : juste les bits utiles).}
 If BIH.biSizeImage=0 Then
  BMPBPL:=((LongInt(BIH.biWidth)*LongInt(BIH.biBitCount)+31)div 32)*4
  Else
  BMPBPL:=LongInt(BIH.biSizeImage)div LongInt(BIH.biHeight);
 If(BMPBPL<=0)or(BMPBPL>SizeOf(BMPLine))Then Begin
  WriteLn('Largeur de l''image trop grande !');
  Close(SourceBMP);
  Halt;
 End;
 BMPBytesPerLine:=Word(BMPBPL);
 ImageWidth:=Word(BIH.biWidth);
 ImageHeight:=Word(BIH.biHeight);
 WPGBytesPerLine:=Word((LongInt(ImageWidth)*LongInt(BIH.biBitCount)+7)div 8);

  {Lecture de la palette du BMP.}
 Case BIH.biBitCount of
  1:NumPal:=2;
  4:NumPal:=16;
  8:NumPal:=256;
 End;
 Seek(SourceBMP,14+SizeOf(BitmapInfoHeader));
 BlockRead(SourceBMP,Palette,LongInt(NumPal)*4,ByteReaded);

 StartPos:=Header.OffBits;

  {Cr�ation du fichier de destination.}
 OutputName:=Path2NameExt(ParamStr(1));
 {$I-}Assign(DestWPG,OutputName);
 Rewrite(DestWPG,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de cr�er le fichier ',OutputName);
  Close(SourceBMP);
  Halt;
 End;

  {1) Ent�te de fichier WPG (16 octets).}
 WriteByte(WPGMagic0);
 WriteByte(WPGMagic1);
 WriteByte(WPGMagic2);
 WriteByte(WPGMagic3);
 WriteLongLE(16);                  { Offset du premier enregistrement }
 WriteByte(WPGProductType);        { 1 = WordPerfect }
 WriteByte(WPGFileType);           { 22 = fichier WPG }
 WriteByte(WPGVersionMajor);       { Version 1.0 }
 WriteByte(WPGVersionMinor);
 WriteWordLE(0);                   { Cl� de chiffrement (aucune) }
 WriteWordLE(0);                   { R�serv� }

  {2) Enregistrement "Start WPG" (type $0F, 6 octets de donn�es).
     Les dimensions sont exprim�es en 1/1200 de pouce. On choisit un
     facteur de 8 unit�s WPG par pixel (= 150 dpi) ce qui garantit
     l'absence de d�bordement m�me � la largeur maximale support�e.}
 WriteByte(WPGRecStart);
 WriteRecLength(6);
 WriteByte(1);                     { Version interne du d�but de figure }
 WriteByte(0);                     { Drapeaux }
 WriteWordLE(Word(LongInt(ImageWidth)*8));
 WriteWordLE(Word(LongInt(ImageHeight)*8));

  {3) Enregistrement de palette (type $0E).
     Donn�es : index de d�part (2) + nombre de couleurs (2) + RGB par
     couleur (3 octets chacun, dans l'ordre R, G, B).}
 WriteByte(WPGRecColorMap);
 WriteRecLength(LongInt(4)+LongInt(NumPal)*3);
 WriteWordLE(0);                   { Premier index modifi� }
 WriteWordLE(NumPal);              { Nombre de couleurs }
 For I:=0 to NumPal-1 Do Begin
  WriteByte(Palette[I].R);
  WriteByte(Palette[I].G);
  WriteByte(Palette[I].B);
 End;

  {4) Enregistrement bitmap type 1 (type $0B).
     Pour pouvoir �crire la longueur AVANT les donn�es, on calcule � la
     vol�e la taille des donn�es RLE : courses litt�rales de 1..127
     octets, soit ceil(WPGBytesPerLine / 127) compteurs par ligne, plus
     les octets bruts eux-m�mes, le tout multipli� par le nombre de
     lignes. Les 10 octets restants sont l'ent�te du bitmap.}
 WriteByte(WPGRecBitmap1);
 Begin
  Var_Block:Begin end;            { (juste pour la coh�rence visuelle) }
 End;
END.
