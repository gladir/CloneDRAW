{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program ICO2PAS;

{$A-}

Type
 IconDirEntry=Record
  bWidth:Byte;            { Largeur de l'icìne. 16, 32 ou 64 pixels. }
  bHeight:Byte;           { Hauteur de l'icìne. Doit àtre identique Ö bWidth }
  bColorCount:Byte;       { Nombre de couleurs. 2, 8 ou 16. }
  bReserved:Byte;         { RÇservÇs, doit àtre Ö 0 pour l'instant, mais
                            pourra àtre utilisÇ Çventuellement pour
                            l'extension en 256 couleurs par exemples... }
  wPlanes:Word;           { Nombre de plans de couleurs dans l'icìne }
  wBitCount:Word;         { Nombre de bits par pixels }
  dwBytesInRes:LongInt;   { Grosseurs de la ressource en octets.}
  dwImageOffset:LongInt;  { SpÇcifie la position absolue Ö partie du dÇbut
                            du fichier en octets ou se trouve l'Icìne.}
 End;

 IconHeader=Record
  idReserved:Word;        { RÇservÇ; doit toujours àtre Ö 0 }
  idType:Word;            { SpÇcifie le type de ressource, ce membre doit
                            donc àtre Ö 1 = Icìne, 2 = Curseur }
  idCount:Word;           { Nombre d'Icìne dans le rÇpertoire, C'est le
                            nombre dans le tableau ridEntries_!}
  idEntries:Array[0..1]of { DÇfinit une structure contenant des }
            IconDirEntry; { indications d'une des Icìnes du fichier.}
 End;

 BitmapInfoHeader=Record
  biSize:LongInt;         { SpÇcifie le nombre d'octets requis pour la structure }
  biWidth:LongInt;        { SpÇcifie la largeur du BitMap en pixels }
  biHeight:LongInt;       { SpÇcifie la hauteur du BitMap en pixels }
  biPlanes:Word;          { SpÇcifie le nombre de plane pour la destination }
  biBitCount:Word;        { SpÇcifie le nombre de bits par pixel (1, 4, 8, 24)}
  biCompression:LongInt;  { SpÇcifie le style de compression: BI_RGB, BI_RLE8, BI_RLE4 }
  biSizeImage:LongInt;    { SpÇcifie la taille en octets pour l'image }
  biXPelsPerMeter:LongInt;{ SpÇcifie le nombre horizontal de pixels par mStre }
  biYPelsPerMeter:LongInt;{ SpÇcifie le nombre vertical de pixels par mStre }
  biClrUsed:LongInt;      { SpÇcifie le nombre de couleurs indexÇs dans la table}
  biClrImportant:LongInt; { SpÇcifie le nombre de couleurs indexÇs dans la table
                            en comptant ceux Çtant vraiment indispensable Ö l'affichage}
 End;

Var
 CurrLine:LongInt;
 SourceICO:File;
 Header:IconHeader;
 B,Size,I,J,K,Min,Max,BytesPerLine,ByteReaded:Word;
 Buffer:Array[0..4095]of Byte;
 BitMap:BitMapInfoHeader Absolute Buffer;

Function ByteHex2Str(value:Byte):String;
Const
 matrix:Array[0..15]of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
Begin
 ByteHex2Str:=matrix[(value shr 4) and $0F]+matrix[value and $F];
End;

BEGIN
If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('ICO2BAS : Cette commande permet de transformer un icìne ',
                     'en code source BASIC.');
  WriteLn;
  WriteLn('Syntaxe : ICO2BAS nomdufichier.ICO');
  WriteLn;
  WriteLn(' nomdufichier   Ce paramätre permet d''indiquer le nom du fichier ".ICO".');
 End
  Else
 If ParamCount>0Then Begin
  CurrLine:=60;
  {$I-}Assign(SourceICO,ParamStr(1));
  Reset(SourceICO,1);{$I+}
  If IOResult<>0 Then Begin
   WriteLn('Impossible de lire le fichier d''icìne');
   Halt;
  End;
  BlockRead(SourceICO,Header,SizeOf(Header),ByteReaded);
  Min:=1;
  Max:=Header.idCount;
  If(Header.idReserved=0)and(Header.idType in[1,2])Then For I:=Min to(Max)do Begin
   Size:=Word(Header.idEntries[I-1].dwBytesInRes);
   If Size>SizeOf(Buffer)Then Begin
    WriteLn('Ligne d''icìne trop grande !');
    Halt;
   End;
   Seek(SourceICO,Header.idEntries[I-1].dwImageOffset);
   BlockRead(SourceICO,Buffer,Size,ByteReaded);
   WriteLn('10 NumXPixels%=',Header.idEntries[I-1].bWidth);
   WriteLn('20 NumYPixels%=',Header.idEntries[I-1].bHeight);
   If(Header.idEntries[I-1].bWidth=0)or(Header.idEntries[I-1].bHeight=0)Then Begin
    WriteLn('Taille de l''icìne invalide');
    Halt;
   End;
   WriteLn('30 BitsPerPixel%=',BitMap.biBitCount);
   B:=SizeOf(BitmapInfoHeader);
   Case BitMap.biBitCount of
    1:BytesPerLine:=Header.idEntries[I-1].bWidth shr 4;
    4:Begin
     BytesPerLine:=Header.idEntries[I-1].bWidth shr 1;
     Inc(B,4*16);
    End;
    8:BytesPerLine:=Header.idEntries[I-1].bWidth;
    15,16:BytesPerLine:=Header.idEntries[I-1].bWidth shl 1;
    24:BytesPerLine:=Header.idEntries[I-1].bWidth*3;
    Else BytesPerLine:=Header.idEntries[I-1].bWidth;
   End;
   WriteLn('40 BytesPerLine%=',BytesPerLine);
   WriteLn('50 ''BitmapData');
   For J:=Header.idEntries[I-1].bHeight-1 downto 0 do Begin
    Write(CurrLine,' DATA ');
    For K:=0 to BytesPerLine-1 do Begin
     Write(Buffer[B+J*(Header.idEntries[I-1].bWidth shr 1)+K]);
     If(K=BytesPerLine-1)Then Begin
     End
      Else
     Write(',');
    End;
    WriteLn;
    Inc(CurrLine,10);
   End;
  End;
  Close(SourceICO);
 End
  Else
 WriteLn('Paramätre requis !');
END.
