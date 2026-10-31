{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application CorelDraw

  Fonctionnalites :
   - Dessin vectoriel : ligne, polyligne, courbe de Bezier, rectangle,
     ellipse, polygone, etoile et texte artistique
   - Outil Pointeur (deplacement, redimensionnement, selection par cadre),
     outil Forme (edition des noeuds), Zoom et Main
   - Remplissage uniforme, degrade, motifs ; contour (couleur, epaisseur,
     style) ; ombre portee et extrusion ; mode Filaments
   - Organisation : ordre, groupes, alignement, distribution, rotation,
     miroirs, conversion en courbes
   - Regles, grille, magnetisme, apercu plein ecran, annuler/retablir
   - Fichiers : CDR/CDT de CorelDRAW 5, 6, 7, 8 et 9 (lecture, y compris les
     fichiers xxx.CD_ compresses KWAJ des disquettes d'installation de la 5) : courbes, formes,
     remplissages unis et degrades, contours, groupes, transformations),
     CDR natif de ce clone (RIFF "CDR4", lecture/ecriture sans perte),
     CorelDRAW 9 (RIFF "CDR9", ecriture), WPG (lecture), SVG (ecriture)

  Notes :
   - Le format "CDR4" ecrit par Enregistrer est propre a ce clone ; il n'est
     pas lisible par CorelDraw. Pour echanger avec CorelDRAW 9, utiliser
     Enregistrer sous... avec le type "CDR 9" ou Fichier > Exporter CorelDRAW 9.
   - Les objets sont dans une liste doublement chainee du tas : leur nombre
     n'est limite que par la memoire (chaque objet garde au plus 7999 noeuds).
   - Lecture CorelDRAW : les courbes composees (plusieurs sous-chemins, avec
     trous, remplissage pair/impair), les degrades radiaux, les bitmaps
     (RVB 24 bits, RVBA 32 bits, 8 bits a palette, 1 bit ; reduits a 400
     points au plus et affiches avec un cube de 144 couleurs tramees) et les
     motifs/textures en couleurs (bitmap en cache pave sur l'objet) sont
     relus ; les motifs a deux couleurs sont remplaces par une trame ; le
     texte est reconstruit de facon approximative (police 8x8, taille
     estimee) ; les angles de degrades, les degrades a plus de deux couleurs
     et certaines lentilles/transparences ne sont pas relus. Les images sont
     conservees par le format CDR natif. Necessite Free Pascal (l'affichage
     des images aussi : en Turbo Pascal 7 un bitmap est un cadre gris).
     Les images occupent les couleurs 112 a 255 de la palette : un document
     qui en contient garde au plus 64 couleurs personnalisees.
   - Un fichier CorelDRAW ouvert n'est jamais ecrase par Enregistrer.

  Ligne de commande :
   CORELDRW [fichier.cdr|fichier.wpg]
   CORELDRW /SAMPLES                 genere les exemples SAMPLES\CORELDRAW
   CORELDRW /CONVERT entree sortie   conversion sans interface (CDR/SVG)
}

Program CORELDRW;

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$R-}
{$ENDIF}

Uses {$IFDEF FPC}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

Const
 { Types d'objets }
 K_LINE=1; K_RECT=2; K_ELLIPSE=3; K_POLY=4; K_POLYLINE=5; K_BEZIER=6; K_TEXT=7; K_BITMAP=8;
 { Types de remplissage }
 FK_NONE=0; FK_SOLID=1; FK_GRADV=2; FK_GRADH=3; FK_PATTERN=4; FK_RADIAL=5; FK_IMAGE=6;
 FK_CONIC=7; FK_SQUARE=8;
 { Outils }
 T_PICK=0; T_SHAPE=1; T_ZOOM=2; T_HAND=3; T_LINE=4; T_POLYLINE=5; T_CURVE=6;
 T_RECT=7; T_ELLIPSE=8; T_POLYGON=9; T_STAR=10; T_TEXT=11;
 TOOL_COUNT=12;

 MAXPOLY=4000;
 UNDO_MAX=8;
 PAL_COUNT=48;

 { Gabarit de l'interface }
 MENUBAR_H=18;
 ICONBAR_TOP=18; ICONBAR_H=24;
 PROPBAR_TOP=42; PROPBAR_H=20;
 TOOLBOX_W=40;
 RULER_SIZE=12;
 SCROLL_W=12;
 PALETTE_H=20;
 STATUS_H=16;
 MENU_COUNT=10;

 CDR_VERSION=400;

 { Images : maximum, cote maximal conserve (les bitmaps plus grands sont reduits)
   et premier indice du cube de 144 couleurs reserve a leur affichage }
 IMG_MAX=4000;
 IMG_SIDE=400;
 IMG_BASE=112;

 { Marque de rupture : une courbe composee place, entre deux sous-chemins, deux
   noeuds dont X vaut BRK ; le sous-chemin suivant reprend alors sur un
   indice multiple de 3 }
 BRK=-2000000000;

 { Calques, pages, reperes }
 LAYER_N=6;
 PAGE_MAX=20;
 GUIDE_MAX=32;

Type
 TPt=Record X,Y:LongInt; End;
 TPtArr=Array[0..7999] of TPt;
 PPtArr=^TPtArr;
 PObj=^TObj;
 TObj=Record
  Kind:Byte;
  Sel,Closed,Shadow,Extrude:Boolean;
  Group:Integer;
  OutCol,FillCol,FillCol2:Integer;
  FillKind,Pattern,LineStyle:Byte;
  GradX,GradY:ShortInt;   { decalage du centre du degrade radial, en % }
  Img:Integer;            { bitmap (K_BITMAP) ou motif (FK_IMAGE) : indice dans Imgs }
  TileW,TileH:Integer;    { taille du motif, en 1/10 mm }
  Layer,Page:Byte;        { calque (1..LAYER_N) ; page (0 = page maitresse) }
  OutW,TextSize:LongInt;
  N,Cap:Integer;
  Pts:PPtArr;
  Txt:String[60];
  Next,Prev:PObj;
 End;
 PSnap=^TSnap;
 TSnap=Record
  N:LongInt;
  PW,PH:LongInt;
  Head,Tail:PObj;
 End;

Type
 {$IFDEF FPC}
 TImgBuf=Array[0..99999999] of Byte;
 {$ELSE}
 TImgBuf=Array[0..65520] of Byte;
 {$ENDIF}
 PImgBuf=^TImgBuf;
 { Image en couleurs vraies, reduite a IMG_SIDE points au plus ; la ligne du
   haut vient en premier }
 TImage=Record
  W,H:Integer;
  Alpha:Boolean;
  Pix:PImgBuf;          { 3 octets par point : R,V,B }
  A:PImgBuf;            { opacite, 1 octet par point (si Alpha) }
  AR,AG,AB:Byte;        { couleur moyenne }
 End;
 PImage=^TImage;

Var
 Imgs:Array[1..IMG_MAX] of PImage;
 ImgCount:Integer;
 PalTop:Integer;        { premier indice de palette interdit aux couleurs du document }
 ImgPalOn:Boolean;

Var
 { Document }
 ObjHead,ObjTail,CurPtr:PObj;
 ObjCount,CurIdx:LongInt;
 PageW,PageH:LongInt;
 GridSize:LongInt;
 DocName:String;
 Modified:Boolean;
 GroupSeq:Integer;
 UndoList,RedoList:Array[0..UNDO_MAX-1] of PSnap;
 UndoCnt,RedoCnt:Integer;
 ClipSnap:PSnap;

 { Calques, pages, reperes }
 CurPage,PageCnt:Integer;
 EditMaster:Boolean;
 ActLayer:Integer;
 LayerVis,LayerLock,LayerPrn:Array[1..LAYER_N] of Boolean;
 LayerName:Array[1..LAYER_N] of String[16];
 GuideN:Integer;
 GuideHor:Array[0..GUIDE_MAX-1] of Boolean;
 GuidePos:Array[0..GUIDE_MAX-1] of LongInt;
 ShowGuides,SnapGuides:Boolean;
 NodeObj,NodeIdx:Integer;

 { Vue }
 Zoom,OrgX,OrgY:LongInt;
 ShowGrid,ShowRulers,SnapGrid,WireMode,FullPreview:Boolean;

 { Styles par defaut }
 DefOut,DefFill,DefFill2:Integer;
 DefOutW:LongInt;
 DefLineStyle,DefFillKind,DefPattern:Byte;
 DefTextSize:LongInt;
 PolySides:Integer;
 CurTool:Integer;

 { Tampon de polygone ecran }
 PX,PY:Array[0..MAXPOLY-1] of LongInt;
 PN:Integer;
 PClosed:Boolean;
 { Contours du tampon : debut de chacun (courbes composees) }
 PCS:Array[0..63] of Integer;
 PCN:Integer;

 { Tables trigonometriques de l'ellipse (x1000) }
 ECos,ESin:Array[0..47] of LongInt;

 { Dimensions de la zone de dessin }
 CanvasX,CanvasY,CanvasW,CanvasH:Integer;
 ScreenW,ScreenH:Integer;
 GfxReady:Boolean;

 PalR,PalG,PalB:Array[0..255] of Byte;
 PalUsed:Integer;
 PalDirty:Boolean;
 C9Info:String;
 FromCorel:Boolean;

{ ------------------------------------------------------------------ }
{ Utilitaires                                                        }
{ ------------------------------------------------------------------ }

Function IStr(L:LongInt):String;
Var S:String;
Begin
 Str(L,S);
 IStr:=S;
End;

Function MMStr(V:LongInt):String;
Var S:String;
Begin
 S:='';
 If V<0 Then Begin S:='-'; V:=-V; End;
 MMStr:=S+IStr(V Div 10)+'.'+IStr(V Mod 10);
End;

Function UpStr(S:String):String;
Var I:Integer;
Begin
 For I:=1 To Length(S) Do
  If(S[I]>='a')and(S[I]<='z')Then S[I]:=Chr(Ord(S[I])-32);
 UpStr:=S;
End;

Function Min(A,B:LongInt):LongInt;
Begin
 If A<B Then Min:=A Else Min:=B;
End;

Function Max(A,B:LongInt):LongInt;
Begin
 If A>B Then Max:=A Else Max:=B;
End;

Function Clamp(V,A,B:LongInt):LongInt;
Begin
 If V<A Then V:=A;
 If V>B Then V:=B;
 Clamp:=V;
End;

Function CL(V:LongInt):Integer;
Begin
 If V<-30000 Then V:=-30000;
 If V>30000 Then V:=30000;
 CL:=V;
End;

Function FileExists(Const S:String):Boolean;
Var F:File;
    Old:Byte;
Begin
 Old:=FileMode;
 FileMode:=0;
 Assign(F,S);
 {$I-}Reset(F,1);{$I+}
 FileMode:=Old;
 If IOResult=0 Then Begin
  Close(F);
  FileExists:=True;
 End
  Else
 FileExists:=False;
End;

Function ExtOf(Const S:String):String;
Var I:Integer;
Begin
 ExtOf:='';
 I:=Length(S);
 While I>0 Do Begin
  If S[I]='.' Then Begin
   ExtOf:=UpStr(Copy(S,I,255));
   Exit;
  End;
  If(S[I]='\')or(S[I]='/')Then Exit;
  Dec(I);
 End;
End;

Function BaseOf(Const S:String):String;
Var I:Integer;
Begin
 I:=Length(S);
 While(I>0)and(S[I]<>'\')and(S[I]<>'/')and(S[I]<>':')Do Dec(I);
 BaseOf:=Copy(S,I+1,255);
End;

Function ForceExt(Const S,Ext:String):String;
Var I:Integer;
Begin
 I:=Length(S);
 While(I>0)and(S[I]<>'.')and(S[I]<>'\')and(S[I]<>'/')Do Dec(I);
 If(I>0)and(S[I]='.')Then ForceExt:=Copy(S,1,I-1)+Ext
                     Else ForceExt:=S+Ext;
End;

{ Convertit les accents UTF-8 de la source vers la page de codes 437
  utilisee par la police BGI par defaut. }
Function Conv(Const S:String):String;
Var R:String;
    I:Integer;
    C:Byte;
Begin
 R:='';
 I:=1;
 While I<=Length(S) Do Begin
  C:=Ord(S[I]);
  If(C=195)and(I<Length(S))Then Begin
   Inc(I);
   Case Ord(S[I]) Of
    $A9:R:=R+#130; $A8:R:=R+#138; $AA:R:=R+#136; $AB:R:=R+#137;
    $A0:R:=R+#133; $A2:R:=R+#131; $A4:R:=R+#132;
    $A7:R:=R+#135; $AE:R:=R+#140; $AF:R:=R+#139;
    $B4:R:=R+#147; $B6:R:=R+#148; $B9:R:=R+#151; $BB:R:=R+#150;
    $BC:R:=R+#129; $89:R:=R+#144; $87:R:=R+#128;
    $80,$82:R:=R+'A'; $88,$8A:R:=R+'E'; $94:R:=R+'O'; $99,$9B:R:=R+'U';
   Else R:=R+'?';
   End;
  End
   Else
  If(C=194)and(I<Length(S))Then Begin
   Inc(I);
   If Ord(S[I])=$B0 Then R:=R+#248 Else R:=R+' ';
  End
   Else
  R:=R+S[I];
  Inc(I);
 End;
 Conv:=R;
End;

Function Ticks:LongInt;
Var H,M,S,S100:Word;
Begin
 GetTime(H,M,S,S100);
 Ticks:=((LongInt(H)*60+M)*60+S)*100+S100;
End;

{ ------------------------------------------------------------------ }
{ Palette                                                            }
{ ------------------------------------------------------------------ }

Procedure SetPal(I,R,G,B:Integer);
Begin
 PalR[I]:=R; PalG[I]:=G; PalB[I]:=B;
End;

Procedure InitPaletteTable;
Begin
 SetPal(0,0,0,0);       SetPal(1,0,0,170);     SetPal(2,0,170,0);
 SetPal(3,0,170,170);   SetPal(4,170,0,0);     SetPal(5,170,0,170);
 SetPal(6,170,85,0);    SetPal(7,170,170,170); SetPal(8,85,85,85);
 SetPal(9,85,85,255);   SetPal(10,85,255,85);  SetPal(11,85,255,255);
 SetPal(12,255,85,85);  SetPal(13,255,85,255); SetPal(14,255,255,85);
 SetPal(15,255,255,255);
 SetPal(16,255,140,0);  SetPal(17,255,170,200);SetPal(18,255,200,0);
 SetPal(19,100,50,20);  SetPal(20,0,0,100);    SetPal(21,0,120,120);
 SetPal(22,120,0,160);  SetPal(23,110,110,0);  SetPal(24,120,0,0);
 SetPal(25,120,190,255);SetPal(26,170,230,0);  SetPal(27,250,128,114);
 SetPal(28,210,180,140);SetPal(29,245,235,200);SetPal(30,20,100,40);
 SetPal(31,180,120,255);
 SetPal(32,24,24,24);   SetPal(33,40,40,40);   SetPal(34,60,60,60);
 SetPal(35,110,110,110);SetPal(36,135,135,135);SetPal(37,200,200,200);
 SetPal(38,220,220,220);SetPal(39,238,238,238);
 SetPal(40,255,220,180);SetPal(41,178,34,34);  SetPal(42,70,130,180);
 SetPal(43,64,224,208); SetPal(44,255,20,147); SetPal(45,139,69,19);
 SetPal(46,46,139,87);  SetPal(47,75,0,130);
 PalUsed:=PAL_COUNT;
 PalTop:=255;
 ImgPalOn:=False;
 PalDirty:=False;
End;

Function NearestColor(R,G,B:Integer):Integer;
Var I,Best:Integer;
    D,BestD:LongInt;
Begin
 Best:=0;
 BestD:=MaxLongInt;
 For I:=0 To PalUsed-1 Do Begin
  D:=Sqr(LongInt(R)-PalR[I])+Sqr(LongInt(G)-PalG[I])+Sqr(LongInt(B)-PalB[I]);
  If D<BestD Then Begin
   BestD:=D;
   Best:=I;
  End;
 End;
 NearestColor:=Best;
End;

{ Ajoute (ou retrouve) une couleur personnalisee de la palette du document }
Function AddPalColor(R,G,B:Integer):Integer;
Var I,Best:Integer;
    D,BestD:LongInt;
Begin
 Best:=0;
 BestD:=MaxLongInt;
 For I:=0 To PalUsed-1 Do Begin
  D:=Sqr(LongInt(R)-PalR[I])+Sqr(LongInt(G)-PalG[I])+Sqr(LongInt(B)-PalB[I]);
  If D<BestD Then Begin
   BestD:=D;
   Best:=I;
  End;
 End;
 If BestD<=20 Then Begin
  AddPalColor:=Best;
  Exit;
 End;
 If PalUsed<PalTop Then Begin
  SetPal(PalUsed,R,G,B);
  AddPalColor:=PalUsed;
  Inc(PalUsed);
  PalDirty:=True;
 End
  Else AddPalColor:=Best;
End;

Function NearestColor16(R,G,B:Integer):Integer;
Var I,Best:Integer;
    D,BestD:LongInt;
Begin
 Best:=0;
 BestD:=MaxLongInt;
 For I:=0 To 15 Do Begin
  D:=Sqr(LongInt(R)-PalR[I])+Sqr(LongInt(G)-PalG[I])+Sqr(LongInt(B)-PalB[I]);
  If D<BestD Then Begin
   BestD:=D;
   Best:=I;
  End;
 End;
 NearestColor16:=Best;
End;

{ Reserve le cube 6x6x4 des images aux indices IMG_BASE..255 }
Procedure ImgPalSetup;
Var R,G,B:Integer;
Begin
 If ImgPalOn Then Exit;
 If PalUsed>IMG_BASE Then PalUsed:=IMG_BASE;
 For R:=0 To 5 Do
  For G:=0 To 5 Do
   For B:=0 To 3 Do
    SetPal(IMG_BASE+(R*6+G)*4+B,R*51,G*51,B*85);
 PalTop:=IMG_BASE;
 ImgPalOn:=True;
 PalDirty:=True;
End;

Function ImgNew(W,H:Integer;Alpha:Boolean):Integer;
Var P:PImage;
Begin
 ImgNew:=0;
 {$IFDEF FPC}
 If(ImgCount>=IMG_MAX)or(W<1)or(H<1)Then Exit;
 New(P);
 P^.W:=W;
 P^.H:=H;
 P^.Alpha:=Alpha;
 P^.A:=NIL;
 P^.AR:=128; P^.AG:=128; P^.AB:=128;
 GetMem(P^.Pix,LongInt(W)*H*3);
 If Alpha Then GetMem(P^.A,LongInt(W)*H);
 Inc(ImgCount);
 Imgs[ImgCount]:=P;
 ImgNew:=ImgCount;
 {$ENDIF}
End;

Procedure ImgFreeAll;
Var I:Integer;
Begin
 For I:=1 To ImgCount Do
  If Imgs[I]<>NIL Then Begin
   FreeMem(Imgs[I]^.Pix,LongInt(Imgs[I]^.W)*Imgs[I]^.H*3);
   If Imgs[I]^.A<>NIL Then FreeMem(Imgs[I]^.A,LongInt(Imgs[I]^.W)*Imgs[I]^.H);
   Dispose(Imgs[I]);
   Imgs[I]:=NIL;
  End;
 ImgCount:=0;
End;

{ Couleur moyenne des points opaques de l'image I }
Procedure ImgAverage(I:Integer);
Var P:PImage;
    N,SR,SG,SB,K:LongInt;
Begin
 If(I<1)or(I>ImgCount)Then Exit;
 {$IFDEF FPC}
 P:=Imgs[I];
 SR:=0; SG:=0; SB:=0; N:=0;
 K:=0;
 While K<LongInt(P^.W)*P^.H Do Begin
  If(P^.A=NIL)or(P^.A^[K]>=128)Then Begin
   Inc(SR,P^.Pix^[K*3]);
   Inc(SG,P^.Pix^[K*3+1]);
   Inc(SB,P^.Pix^[K*3+2]);
   Inc(N);
  End;
  Inc(K,3);
 End;
 If N>0 Then Begin
  P^.AR:=SR Div N;
  P^.AG:=SG Div N;
  P^.AB:=SB Div N;
 End;
 {$ELSE}
 P:=Imgs[I];
 N:=0;
 {$ENDIF}
End;

Function HexByte(B:Integer):String;
Const Hx:String='0123456789ABCDEF';
Begin
 HexByte:=Hx[(B Shr 4)+1]+Hx[(B And 15)+1];
End;

Function ColorHex(C:Integer):String;
Begin
 If(C<0)or(C>=PalUsed)Then ColorHex:='#000000'
  Else ColorHex:='#'+HexByte(PalR[C])+HexByte(PalG[C])+HexByte(PalB[C]);
End;

{ ------------------------------------------------------------------ }
{ Objets                                                             }
{ ------------------------------------------------------------------ }

Function NewObj(Kind:Byte;N:Integer):PObj;
Var O:PObj;
Begin
 New(O);
 FillChar(O^,SizeOf(O^),0);
 O^.Kind:=Kind;
 O^.OutCol:=DefOut;
 O^.OutW:=DefOutW;
 O^.LineStyle:=DefLineStyle;
 O^.FillCol:=DefFill;
 O^.FillCol2:=DefFill2;
 O^.FillKind:=DefFillKind;
 O^.Pattern:=DefPattern;
 O^.TextSize:=DefTextSize;
 O^.Layer:=ActLayer;
 If EditMaster Then O^.Page:=0 Else O^.Page:=CurPage;
 If(Kind=K_LINE)or(Kind=K_POLYLINE)or(Kind=K_BEZIER)Then Begin
  O^.FillKind:=FK_NONE;
  O^.FillCol:=-1;
 End
  Else
 If(DefFillKind<>FK_NONE)and(DefFill<0)Then Begin
  O^.FillKind:=FK_NONE;
 End;
 If N<1 Then N:=1;
 O^.N:=N;
 O^.Cap:=N;
 GetMem(O^.Pts,N*SizeOf(TPt));
 FillChar(O^.Pts^,N*SizeOf(TPt),0);
 NewObj:=O;
End;

Procedure FreeObj(O:PObj);
Begin
 If O=NIL Then Exit;
 If O^.Pts<>NIL Then FreeMem(O^.Pts,O^.Cap*SizeOf(TPt));
 Dispose(O);
End;

Function CloneObj(O:PObj):PObj;
Var C:PObj;
Begin
 New(C);
 C^:=O^;
 C^.Next:=NIL;
 C^.Prev:=NIL;
 GetMem(C^.Pts,O^.Cap*SizeOf(TPt));
 Move(O^.Pts^,C^.Pts^,O^.Cap*SizeOf(TPt));
 CloneObj:=C;
End;

Procedure ObjSetN(O:PObj;N:Integer);
Var P:PPtArr;
    K:Integer;
Begin
 If N<1 Then N:=1;
 If N<=O^.Cap Then Begin
  O^.N:=N;
  Exit;
 End;
 GetMem(P,N*SizeOf(TPt));
 FillChar(P^,N*SizeOf(TPt),0);
 K:=O^.N;
 If K>N Then K:=N;
 Move(O^.Pts^,P^,K*SizeOf(TPt));
 FreeMem(O^.Pts,O^.Cap*SizeOf(TPt));
 O^.Pts:=P;
 O^.Cap:=N;
 O^.N:=N;
End;

{ Liste doublement chainee des objets (tas) : le dernier est le premier plan }
Procedure ListUnlink(O:PObj);
Begin
 If O^.Prev<>NIL Then O^.Prev^.Next:=O^.Next Else ObjHead:=O^.Next;
 If O^.Next<>NIL Then O^.Next^.Prev:=O^.Prev Else ObjTail:=O^.Prev;
 O^.Next:=NIL;
 O^.Prev:=NIL;
 Dec(ObjCount);
 CurPtr:=NIL;
End;

Procedure ListAppend(O:PObj);
Begin
 O^.Next:=NIL;
 O^.Prev:=ObjTail;
 If ObjTail<>NIL Then ObjTail^.Next:=O Else ObjHead:=O;
 ObjTail:=O;
 Inc(ObjCount);
End;

Procedure ListPrepend(O:PObj);
Begin
 O^.Prev:=NIL;
 O^.Next:=ObjHead;
 If ObjHead<>NIL Then ObjHead^.Prev:=O Else ObjTail:=O;
 ObjHead:=O;
 Inc(ObjCount);
 CurPtr:=NIL;
End;

{ Echange P et son suivant }
Procedure ListSwapNext(P:PObj);
Var Q,A,B:PObj;
Begin
 Q:=P^.Next;
 If Q=NIL Then Exit;
 A:=P^.Prev;
 B:=Q^.Next;
 If A<>NIL Then A^.Next:=Q Else ObjHead:=Q;
 Q^.Prev:=A;
 Q^.Next:=P;
 P^.Prev:=Q;
 P^.Next:=B;
 If B<>NIL Then B^.Prev:=P Else ObjTail:=P;
 CurPtr:=NIL;
End;

Procedure ListReverse;
Var P,Nx,T:PObj;
Begin
 P:=ObjHead;
 While P<>NIL Do Begin
  Nx:=P^.Next;
  P^.Next:=P^.Prev;
  P^.Prev:=Nx;
  P:=Nx;
 End;
 T:=ObjHead;
 ObjHead:=ObjTail;
 ObjTail:=T;
 CurPtr:=NIL;
End;

{ Acces par rang (0 = arriere-plan) ; un curseur rend les balayages O(1) }
Function ObjAt(I:LongInt):PObj;
Var P:PObj;
    K,DC,DH,DT:LongInt;
Begin
 ObjAt:=NIL;
 If(I<0)or(I>=ObjCount)Then Exit;
 DH:=I;
 DT:=ObjCount-1-I;
 If CurPtr<>NIL Then DC:=Abs(I-CurIdx) Else DC:=MaxLongInt;
 If(DC<=DH)and(DC<=DT)Then Begin
  P:=CurPtr;
  K:=CurIdx;
 End
  Else
 If DH<=DT Then Begin
  P:=ObjHead;
  K:=0;
 End
  Else Begin
   P:=ObjTail;
   K:=ObjCount-1;
  End;
 While K<I Do Begin
  P:=P^.Next;
  Inc(K);
 End;
 While K>I Do Begin
  P:=P^.Prev;
  Dec(K);
 End;
 CurPtr:=P;
 CurIdx:=I;
 ObjAt:=P;
End;

Procedure ClearDoc;
Var P,Nx:PObj;
Begin
 P:=ObjHead;
 While P<>NIL Do Begin
  Nx:=P^.Next;
  FreeObj(P);
  P:=Nx;
 End;
 ObjHead:=NIL;
 ObjTail:=NIL;
 ObjCount:=0;
 CurPtr:=NIL;
End;

Function AddObj(O:PObj):Boolean;
Begin
 ListAppend(O);
 Modified:=True;
 AddObj:=True;
End;

Procedure DeleteObj(O:PObj);
Begin
 ListUnlink(O);
 FreeObj(O);
End;

Procedure DeleteObjAt(I:LongInt);
Var P:PObj;
Begin
 P:=ObjAt(I);
 If P<>NIL Then DeleteObj(P);
End;

{ Vrai si la courbe est composee de plusieurs sous-chemins }
Function HasBrk(O:PObj):Boolean;
Var I:Integer;
Begin
 HasBrk:=False;
 If O^.Kind<>K_BEZIER Then Exit;
 I:=1;
 While I<O^.N Do Begin
  If O^.Pts^[I].X=BRK Then Begin HasBrk:=True; Exit; End;
  Inc(I,3);
 End;
End;

Procedure ObjBBox(O:PObj;Var X1,Y1,X2,Y2:LongInt);
Var I:Integer;
Begin
 X1:=O^.Pts^[0].X; Y1:=O^.Pts^[0].Y;
 If O^.Kind=K_TEXT Then Begin
  X2:=X1+Length(O^.Txt)*O^.TextSize;
  Y2:=Y1+O^.TextSize;
  Exit;
 End;
 X2:=X1; Y2:=Y1;
 For I:=1 To O^.N-1 Do Begin
  If O^.Pts^[I].X=BRK Then Continue;
  If O^.Pts^[I].X<X1 Then X1:=O^.Pts^[I].X;
  If O^.Pts^[I].X>X2 Then X2:=O^.Pts^[I].X;
  If O^.Pts^[I].Y<Y1 Then Y1:=O^.Pts^[I].Y;
  If O^.Pts^[I].Y>Y2 Then Y2:=O^.Pts^[I].Y;
 End;
End;

Procedure ObjMove(O:PObj;DX,DY:LongInt);
Var I:Integer;
Begin
 For I:=0 To O^.N-1 Do
  If O^.Pts^[I].X<>BRK Then Begin
   Inc(O^.Pts^[I].X,DX);
   Inc(O^.Pts^[I].Y,DY);
  End;
End;

{ Mise a l'echelle par rapport au point (AX,AY) }
Procedure ObjScale(O:PObj;AX,AY,NX,DX,NY,DY:LongInt);
Var I:Integer;
Begin
 If(DX=0)or(DY=0)Then Exit;
 For I:=0 To O^.N-1 Do
  If O^.Pts^[I].X<>BRK Then Begin
   O^.Pts^[I].X:=AX+((O^.Pts^[I].X-AX)*NX) Div DX;
   O^.Pts^[I].Y:=AY+((O^.Pts^[I].Y-AY)*NY) Div DY;
  End;
 If O^.Kind=K_TEXT Then Begin
  O^.TextSize:=(O^.TextSize*NY) Div DY;
  If O^.TextSize<20 Then O^.TextSize:=20;
 End;
End;

Procedure ObjNormalize2(O:PObj);
Var T:LongInt;
Begin
 If O^.N<2 Then Exit;
 If O^.Pts^[0].X>O^.Pts^[1].X Then Begin
  T:=O^.Pts^[0].X; O^.Pts^[0].X:=O^.Pts^[1].X; O^.Pts^[1].X:=T;
 End;
 If O^.Pts^[0].Y>O^.Pts^[1].Y Then Begin
  T:=O^.Pts^[0].Y; O^.Pts^[0].Y:=O^.Pts^[1].Y; O^.Pts^[1].Y:=T;
 End;
End;

{ ------------------------------------------------------------------ }
{ Annuler / Retablir / Presse-papiers                                }
{ ------------------------------------------------------------------ }

Function TakeSnap(OnlySel:Boolean):PSnap;
Var S:PSnap;
    P,C:PObj;
Begin
 New(S);
 S^.N:=0;
 S^.PW:=PageW;
 S^.PH:=PageH;
 S^.Head:=NIL;
 S^.Tail:=NIL;
 P:=ObjHead;
 While P<>NIL Do Begin
  If(Not OnlySel)or P^.Sel Then Begin
   C:=CloneObj(P);
   C^.Prev:=S^.Tail;
   If S^.Tail<>NIL Then S^.Tail^.Next:=C Else S^.Head:=C;
   S^.Tail:=C;
   Inc(S^.N);
  End;
  P:=P^.Next;
 End;
 TakeSnap:=S;
End;

Procedure FreeSnap(Var S:PSnap);
Var P,Nx:PObj;
Begin
 If S=NIL Then Exit;
 P:=S^.Head;
 While P<>NIL Do Begin
  Nx:=P^.Next;
  FreeObj(P);
  P:=Nx;
 End;
 Dispose(S);
 S:=NIL;
End;

{ Remplace le document par le contenu de l'instantane (qui est consomme) }
Procedure RestoreSnap(Var S:PSnap);
Begin
 ClearDoc;
 ObjHead:=S^.Head;
 ObjTail:=S^.Tail;
 ObjCount:=S^.N;
 PageW:=S^.PW;
 PageH:=S^.PH;
 Dispose(S);
 S:=NIL;
End;

Procedure PushList(Var L:Array of PSnap;Var Cnt:Integer;S:PSnap);
Var I:Integer;
Begin
 If Cnt>=UNDO_MAX Then Begin
  FreeSnap(L[0]);
  For I:=0 To UNDO_MAX-2 Do L[I]:=L[I+1];
  Cnt:=UNDO_MAX-1;
 End;
 L[Cnt]:=S;
 Inc(Cnt);
End;

Procedure ClearList(Var L:Array of PSnap;Var Cnt:Integer);
Var I:Integer;
Begin
 For I:=0 To Cnt-1 Do FreeSnap(L[I]);
 Cnt:=0;
End;

Procedure PushUndo;
Begin
 PushList(UndoList,UndoCnt,TakeSnap(False));
 ClearList(RedoList,RedoCnt);
 Modified:=True;
End;

Procedure DoUndo;
Var S:PSnap;
Begin
 If UndoCnt=0 Then Exit;
 PushList(RedoList,RedoCnt,TakeSnap(False));
 Dec(UndoCnt);
 S:=UndoList[UndoCnt];
 UndoList[UndoCnt]:=NIL;
 RestoreSnap(S);
 Modified:=True;
End;

Procedure DoRedo;
Var S:PSnap;
Begin
 If RedoCnt=0 Then Exit;
 PushList(UndoList,UndoCnt,TakeSnap(False));
 Dec(RedoCnt);
 S:=RedoList[RedoCnt];
 RedoList[RedoCnt]:=NIL;
 RestoreSnap(S);
 Modified:=True;
End;

{ ------------------------------------------------------------------ }
{ Selection et organisation                                          }
{ ------------------------------------------------------------------ }

Function SelCount:LongInt;
Var P:PObj;
    C:LongInt;
Begin
 C:=0;
 P:=ObjHead;
 While P<>NIL Do Begin
  If P^.Sel Then Inc(C);
  P:=P^.Next;
 End;
 SelCount:=C;
End;

Procedure DeselectAll;
Var P:PObj;
Begin
 P:=ObjHead;
 While P<>NIL Do Begin
  P^.Sel:=False;
  P:=P^.Next;
 End;
End;

Procedure SelectIndex(I:LongInt);
Var P,Q:PObj;
    G:Integer;
Begin
 P:=ObjAt(I);
 If P=NIL Then Exit;
 P^.Sel:=True;
 G:=P^.Group;
 If G<>0 Then Begin
  Q:=ObjHead;
  While Q<>NIL Do Begin
   If Q^.Group=G Then Q^.Sel:=True;
   Q:=Q^.Next;
  End;
 End;
End;

Function SelBBox(Var X1,Y1,X2,Y2:LongInt):Boolean;
Var P:PObj;
    A,B,C,D:LongInt;
    First:Boolean;
Begin
 First:=True;
 X1:=0; Y1:=0; X2:=0; Y2:=0;
 P:=ObjHead;
 While P<>NIL Do Begin
  If P^.Sel Then Begin
   ObjBBox(P,A,B,C,D);
   If First Then Begin
    X1:=A; Y1:=B; X2:=C; Y2:=D;
    First:=False;
   End
    Else
   Begin
    If A<X1 Then X1:=A;
    If B<Y1 Then Y1:=B;
    If C>X2 Then X2:=C;
    If D>Y2 Then Y2:=D;
   End;
  End;
  P:=P^.Next;
 End;
 SelBBox:=Not First;
End;

Procedure DeleteSelection;
Var P,Nx:PObj;
Begin
 P:=ObjHead;
 While P<>NIL Do Begin
  Nx:=P^.Next;
  If P^.Sel Then DeleteObj(P);
  P:=Nx;
 End;
End;

{ Les objets selectionnes passent au premier plan en gardant leur ordre }
Procedure ToFront;
Var P,Nx,Last:PObj;
Begin
 If ObjTail=NIL Then Exit;
 Last:=ObjTail;
 P:=ObjHead;
 While P<>NIL Do Begin
  Nx:=P^.Next;
  If P^.Sel Then Begin
   ListUnlink(P);
   ListAppend(P);
  End;
  If P=Last Then Break;
  P:=Nx;
 End;
End;

Procedure ToBack;
Var P,Pv,First:PObj;
Begin
 If ObjHead=NIL Then Exit;
 First:=ObjHead;
 P:=ObjTail;
 While P<>NIL Do Begin
  Pv:=P^.Prev;
  If P^.Sel Then Begin
   ListUnlink(P);
   ListPrepend(P);
  End;
  If P=First Then Break;
  P:=Pv;
 End;
End;

Procedure OneForward;
Var P,Pv:PObj;
Begin
 If ObjTail=NIL Then Exit;
 P:=ObjTail^.Prev;
 While P<>NIL Do Begin
  Pv:=P^.Prev;
  If P^.Sel and(P^.Next<>NIL)and Not P^.Next^.Sel Then ListSwapNext(P);
  P:=Pv;
 End;
End;

Procedure OneBackward;
Var P,Nx:PObj;
Begin
 If ObjHead=NIL Then Exit;
 P:=ObjHead^.Next;
 While P<>NIL Do Begin
  Nx:=P^.Next;
  If P^.Sel and(P^.Prev<>NIL)and Not P^.Prev^.Sel Then ListSwapNext(P^.Prev);
  P:=Nx;
 End;
End;

Procedure GroupSel;
Var I:LongInt;
Begin
 If SelCount<2 Then Exit;
 Inc(GroupSeq);
 For I:=0 To ObjCount-1 Do If ObjAt(I)^.Sel Then ObjAt(I)^.Group:=GroupSeq;
End;

Procedure UngroupSel;
Var I:LongInt;
Begin
 For I:=0 To ObjCount-1 Do If ObjAt(I)^.Sel Then ObjAt(I)^.Group:=0;
End;

{ Alignement : Mode 0..5 = gauche, centre, droite, haut, milieu, bas }
Procedure AlignSel(Mode:Integer);
Var I:LongInt;
    SX1,SY1,SX2,SY2,A,B,C,D,DX,DY:LongInt;
Begin
 If SelCount<2 Then Exit;
 SelBBox(SX1,SY1,SX2,SY2);
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel Then Begin
   ObjBBox(ObjAt(I),A,B,C,D);
   DX:=0; DY:=0;
   Case Mode Of
    0:DX:=SX1-A;
    1:DX:=((SX1+SX2) Div 2)-((A+C) Div 2);
    2:DX:=SX2-C;
    3:DY:=SY1-B;
    4:DY:=((SY1+SY2) Div 2)-((B+D) Div 2);
    5:DY:=SY2-D;
   End;
   ObjMove(ObjAt(I),DX,DY);
  End;
End;

{ Distribution : Horiz=True repartit les centres a intervalles reguliers }
Procedure DistributeSel(Horiz:Boolean);
Type
 TPObjs=Array[0..16777215] of PObj;
 TCtrs=Array[0..16777215] of LongInt;
Var Idx:^TPObjs;
    Ctr:^TCtrs;
    N,I,J,Gap:LongInt;
    P,TP:PObj;
    A,B,C,D,First,Last,Target,TC:LongInt;
Begin
 N:=SelCount;
 If N<3 Then Exit;
 GetMem(Idx,N*SizeOf(PObj));
 GetMem(Ctr,N*SizeOf(LongInt));
 N:=0;
 P:=ObjHead;
 While P<>NIL Do Begin
  If P^.Sel Then Begin
   ObjBBox(P,A,B,C,D);
   Idx^[N]:=P;
   If Horiz Then Ctr^[N]:=(A+C) Div 2 Else Ctr^[N]:=(B+D) Div 2;
   Inc(N);
  End;
  P:=P^.Next;
 End;
 Gap:=N Div 2;
 While Gap>0 Do Begin
  For I:=Gap To N-1 Do Begin
   TP:=Idx^[I];
   TC:=Ctr^[I];
   J:=I;
   While(J>=Gap)and(Ctr^[J-Gap]>TC)Do Begin
    Idx^[J]:=Idx^[J-Gap];
    Ctr^[J]:=Ctr^[J-Gap];
    J:=J-Gap;
   End;
   Idx^[J]:=TP;
   Ctr^[J]:=TC;
  End;
  Gap:=Gap Div 2;
 End;
 First:=Ctr^[0];
 Last:=Ctr^[N-1];
 For I:=1 To N-2 Do Begin
  Target:=First+((Last-First)*I) Div (N-1);
  If Horiz Then ObjMove(Idx^[I],Target-Ctr^[I],0)
           Else ObjMove(Idx^[I],0,Target-Ctr^[I]);
 End;
 FreeMem(Idx,N*SizeOf(PObj));
 FreeMem(Ctr,N*SizeOf(LongInt));
End;

{ Rotation de 90 degres (sens horaire a l'ecran) ou miroirs }
Procedure TransformSel(Mode:Integer);
Var I,K:LongInt;
    X1,Y1,X2,Y2,CX,CY,NX,NY,OX,OY:LongInt;
    O:PObj;
Begin
 If Not SelBBox(X1,Y1,X2,Y2)Then Exit;
 CX:=(X1+X2) Div 2;
 CY:=(Y1+Y2) Div 2;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel Then Begin
   O:=ObjAt(I);
   If O^.Kind=K_TEXT Then Begin
    OX:=O^.Pts^[0].X+(Length(O^.Txt)*O^.TextSize) Div 2;
    OY:=O^.Pts^[0].Y+O^.TextSize Div 2;
    Case Mode Of
     0:Begin NX:=CX-(OY-CY); NY:=CY+(OX-CX); End;
     1:Begin NX:=2*CX-OX; NY:=OY; End;
    Else Begin NX:=OX; NY:=2*CY-OY; End;
    End;
    O^.Pts^[0].X:=NX-(Length(O^.Txt)*O^.TextSize) Div 2;
    O^.Pts^[0].Y:=NY-O^.TextSize Div 2;
   End
    Else
   Begin
    For K:=0 To O^.N-1 Do If O^.Pts^[K].X<>BRK Then Begin
     OX:=O^.Pts^[K].X;
     OY:=O^.Pts^[K].Y;
     Case Mode Of
      0:Begin O^.Pts^[K].X:=CX-(OY-CY); O^.Pts^[K].Y:=CY+(OX-CX); End;
      1:O^.Pts^[K].X:=2*CX-OX;
     Else O^.Pts^[K].Y:=2*CY-OY;
     End;
    End;
    If(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)or(O^.Kind=K_BITMAP)Then ObjNormalize2(O);
   End;
  End;
End;

{ Conversion en courbes : rectangle -> polygone, ellipse -> Bezier }
Procedure ConvertToCurves;
Var I:LongInt;
    O,P:PObj;
    X1,Y1,X2,Y2,CX,CY,RX,RY,KX,KY:LongInt;
    Q:Array[0..12] of TPt;
Begin
 For I:=0 To ObjCount-1 Do Begin
  O:=ObjAt(I);
  If Not O^.Sel Then Continue;
  If O^.Kind=K_RECT Then Begin
   X1:=O^.Pts^[0].X; Y1:=O^.Pts^[0].Y; X2:=O^.Pts^[1].X; Y2:=O^.Pts^[1].Y;
   ObjSetN(O,4);
   O^.Kind:=K_POLY;
   O^.Closed:=True;
   O^.Pts^[0].X:=X1; O^.Pts^[0].Y:=Y1;
   O^.Pts^[1].X:=X2; O^.Pts^[1].Y:=Y1;
   O^.Pts^[2].X:=X2; O^.Pts^[2].Y:=Y2;
   O^.Pts^[3].X:=X1; O^.Pts^[3].Y:=Y2;
  End
   Else
  If O^.Kind=K_ELLIPSE Then Begin
   X1:=O^.Pts^[0].X; Y1:=O^.Pts^[0].Y; X2:=O^.Pts^[1].X; Y2:=O^.Pts^[1].Y;
   CX:=(X1+X2) Div 2; CY:=(Y1+Y2) Div 2;
   RX:=(X2-X1) Div 2; RY:=(Y2-Y1) Div 2;
   KX:=(RX*5523) Div 10000; KY:=(RY*5523) Div 10000;
   Q[0].X:=CX+RX;  Q[0].Y:=CY;
   Q[1].X:=CX+RX;  Q[1].Y:=CY+KY;
   Q[2].X:=CX+KX;  Q[2].Y:=CY+RY;
   Q[3].X:=CX;     Q[3].Y:=CY+RY;
   Q[4].X:=CX-KX;  Q[4].Y:=CY+RY;
   Q[5].X:=CX-RX;  Q[5].Y:=CY+KY;
   Q[6].X:=CX-RX;  Q[6].Y:=CY;
   Q[7].X:=CX-RX;  Q[7].Y:=CY-KY;
   Q[8].X:=CX-KX;  Q[8].Y:=CY-RY;
   Q[9].X:=CX;     Q[9].Y:=CY-RY;
   Q[10].X:=CX+KX; Q[10].Y:=CY-RY;
   Q[11].X:=CX+RX; Q[11].Y:=CY-KY;
   Q[12].X:=CX+RX; Q[12].Y:=CY;
   ObjSetN(O,13);
   Move(Q,O^.Pts^,SizeOf(Q));
   O^.Kind:=K_BEZIER;
   O^.Closed:=True;
  End
   Else
  If O^.Kind=K_LINE Then O^.Kind:=K_POLYLINE;
 End;
 P:=NIL;
End;

{ ------------------------------------------------------------------ }
{ Edition avancee : calques, operations booleennes, transformations,   }
{ noeuds, melange, contour, cotes                                      }
{ ------------------------------------------------------------------ }

{ Un objet est-il affiche / selectionnable / imprimable dans la vue courante ? }
Function ObjShown(O:PObj):Boolean;
Begin
 ObjShown:=False;
 If(O^.Layer>=1)and(O^.Layer<=LAYER_N)Then
  If Not LayerVis[O^.Layer]Then Exit;
 If EditMaster Then ObjShown:=O^.Page=0
  Else ObjShown:=(O^.Page=0)or(O^.Page=CurPage);
End;

Function ObjPickable(O:PObj):Boolean;
Begin
 ObjPickable:=False;
 If Not ObjShown(O)Then Exit;
 If(O^.Layer>=1)and(O^.Layer<=LAYER_N)Then
  If LayerLock[O^.Layer]Then Exit;
 If(O^.Page=0)and Not EditMaster Then Exit;
 ObjPickable:=True;
End;

Function ObjPrintable(O:PObj):Boolean;
Begin
 ObjPrintable:=False;
 If(O^.Layer>=1)and(O^.Layer<=LAYER_N)Then
  If Not(LayerVis[O^.Layer]and LayerPrn[O^.Layer])Then Exit;
 ObjPrintable:=(O^.Page=0)or(O^.Page=CurPage);
End;

{ Insere O apres P (P=NIL : en tete de liste) }
Procedure ListInsertAfter(P,O:PObj);
Begin
 If P=NIL Then Begin
  ListPrepend(O);
  Exit;
 End;
 O^.Prev:=P;
 O^.Next:=P^.Next;
 If P^.Next<>NIL Then P^.Next^.Prev:=O Else ObjTail:=O;
 P^.Next:=O;
 Inc(ObjCount);
 CurPtr:=NIL;
End;

{ Copie les attributs graphiques (pas la geometrie) }
Procedure CopyStyle(D,S:PObj);
Begin
 D^.OutCol:=S^.OutCol;
 D^.FillCol:=S^.FillCol;
 D^.FillCol2:=S^.FillCol2;
 D^.FillKind:=S^.FillKind;
 D^.Pattern:=S^.Pattern;
 D^.LineStyle:=S^.LineStyle;
 D^.GradX:=S^.GradX;
 D^.GradY:=S^.GradY;
 D^.Img:=S^.Img;
 D^.TileW:=S^.TileW;
 D^.TileH:=S^.TileH;
 D^.OutW:=S^.OutW;
 D^.Shadow:=S^.Shadow;
 D^.Extrude:=S^.Extrude;
 D^.Layer:=S^.Layer;
 D^.Page:=S^.Page;
End;

Type
 TSelArr=Array[0..199] of PObj;

{ Objets selectionnes, de l'arriere vers l'avant }
Function CollectSel(Var A:TSelArr):Integer;
Var P:PObj;
    N:Integer;
Begin
 N:=0;
 P:=ObjHead;
 While(P<>NIL)and(N<200)Do Begin
  If P^.Sel Then Begin
   A[N]:=P;
   Inc(N);
  End;
  P:=P^.Next;
 End;
 CollectSel:=N;
End;

Var
 EditMsg:String;

{ Remplace la geometrie de O par les points L[0..N-1] relies par des segments
  droits ; Closed : le dernier noeud reboucle sur le premier }
Procedure LinesToBez(O:PObj;Var L:Array of TPt;N:Integer;Closed:Boolean);
Var I,M:Integer;
    P:PPtArr;
    A,B:TPt;
Begin
 M:=N;
 If Closed Then Inc(M);
 If M<2 Then Exit;
 GetMem(P,(3*(M-1)+1)*SizeOf(TPt));
 For I:=0 To M-2 Do Begin
  A:=L[I];
  B:=L[(I+1) Mod N];
  P^[3*I]:=A;
  P^[3*I+1].X:=A.X+(B.X-A.X) Div 3;
  P^[3*I+1].Y:=A.Y+(B.Y-A.Y) Div 3;
  P^[3*I+2].X:=A.X+(2*(B.X-A.X)) Div 3;
  P^[3*I+2].Y:=A.Y+(2*(B.Y-A.Y)) Div 3;
 End;
 P^[3*(M-1)]:=L[(M-1) Mod N];
 FreeMem(O^.Pts,O^.Cap*SizeOf(TPt));
 O^.Pts:=P;
 O^.N:=3*(M-1)+1;
 O^.Cap:=O^.N;
 O^.Kind:=K_BEZIER;
 O^.Closed:=Closed;
End;

{ Convertit un rectangle, une ellipse, un polygone ou une ligne en courbe }
Procedure ToBezier(O:PObj);
Var L:Array[0..3] of TPt;
    X1,Y1,X2,Y2,CX,CY,RX,RY,KX,KY:LongInt;
    Q:Array[0..7999] of TPt;
    E:Array[0..12] of TPt;
    I:Integer;
Begin
 Case O^.Kind Of
  K_RECT:Begin
   ObjBBox(O,X1,Y1,X2,Y2);
   L[0].X:=X1; L[0].Y:=Y1; L[1].X:=X2; L[1].Y:=Y1;
   L[2].X:=X2; L[2].Y:=Y2; L[3].X:=X1; L[3].Y:=Y2;
   LinesToBez(O,L,4,True);
  End;
  K_ELLIPSE:Begin
   ObjBBox(O,X1,Y1,X2,Y2);
   CX:=(X1+X2) Div 2; CY:=(Y1+Y2) Div 2;
   RX:=(X2-X1) Div 2; RY:=(Y2-Y1) Div 2;
   KX:=(RX*5523) Div 10000; KY:=(RY*5523) Div 10000;
   E[0].X:=CX+RX;  E[0].Y:=CY;
   E[1].X:=CX+RX;  E[1].Y:=CY+KY;
   E[2].X:=CX+KX;  E[2].Y:=CY+RY;
   E[3].X:=CX;     E[3].Y:=CY+RY;
   E[4].X:=CX-KX;  E[4].Y:=CY+RY;
   E[5].X:=CX-RX;  E[5].Y:=CY+KY;
   E[6].X:=CX-RX;  E[6].Y:=CY;
   E[7].X:=CX-RX;  E[7].Y:=CY-KY;
   E[8].X:=CX-KX;  E[8].Y:=CY-RY;
   E[9].X:=CX;     E[9].Y:=CY-RY;
   E[10].X:=CX+KX; E[10].Y:=CY-RY;
   E[11].X:=CX+RX; E[11].Y:=CY-KY;
   E[12].X:=CX+RX; E[12].Y:=CY;
   ObjSetN(O,13);
   Move(E,O^.Pts^,SizeOf(E));
   O^.Kind:=K_BEZIER;
   O^.Closed:=True;
  End;
  K_LINE,K_POLYLINE,K_POLY:Begin
   If O^.N<2 Then Exit;
   For I:=0 To O^.N-1 Do Q[I]:=O^.Pts^[I];
   LinesToBez(O,Q,O^.N,O^.Kind=K_POLY);
  End;
 End;
End;

{$IFDEF FPC}

Const
 FL_MAX=8000;
 EDGE_MAX=6000;
 SPL_MAX=30000;
 OUT_MAX=14000;

Type
 TFlat=Record
  N,CN:LongInt;
  CS:Array[0..63] of LongInt;
  P:PPtArr;
 End;
 TEdge=Record
  X1,Y1,X2,Y2:LongInt;
  Own:Byte;
  Head:LongInt;
 End;
 TEdgeArr=Array[0..EDGE_MAX-1] of TEdge;
 PEdgeArr=^TEdgeArr;
 TSplit=Record
  T:Double;
  X,Y:LongInt;
  Next:LongInt;
 End;
 TSplitArr=Array[0..SPL_MAX-1] of TSplit;
 PSplitArr=^TSplitArr;
 TOutSeg=Record
  X1,Y1,X2,Y2:LongInt;
  Used:Boolean;
 End;
 TOutArr=Array[0..OUT_MAX-1] of TOutSeg;
 POutArr=^TOutArr;

Procedure FlatNew(Var F:TFlat);
Begin
 GetMem(F.P,FL_MAX*SizeOf(TPt));
 F.N:=0;
 F.CN:=1;
 F.CS[0]:=0;
End;

Procedure FlatFree(Var F:TFlat);
Begin
 If F.P<>NIL Then FreeMem(F.P,FL_MAX*SizeOf(TPt));
 F.P:=NIL;
 F.N:=0;
 F.CN:=0;
End;

Procedure FlatClear(Var F:TFlat);
Begin
 F.N:=0;
 F.CN:=1;
 F.CS[0]:=0;
End;

Procedure FlatAdd(Var F:TFlat;X,Y:Double);
Begin
 If F.N<FL_MAX Then Begin
  F.P^[F.N].X:=Round(X);
  F.P^[F.N].Y:=Round(Y);
  Inc(F.N);
 End;
End;

Procedure FlatBreak(Var F:TFlat);
Begin
 If(F.CN<64)and(F.N>F.CS[F.CN-1])Then Begin
  F.CS[F.CN]:=F.N;
  Inc(F.CN);
 End;
End;

Function FlatEnd(Var F:TFlat;C:Integer):LongInt;
Begin
 If C+1<F.CN Then FlatEnd:=F.CS[C+1]-1 Else FlatEnd:=F.N-1;
End;

{ Aplatit O en coordonnees document ; Closed : l'objet est ferme }
Procedure FlatObj(O:PObj;Var F:TFlat;Steps:Integer;Var Closed:Boolean);
Var I,J,T:Integer;
    X1,Y1,X2,Y2,CX,CY,RX,RY:LongInt;
    U,V,A,B,C,D:Double;
    P:Array[0..3] of TPt;
Begin
 FlatClear(F);
 Closed:=False;
 Case O^.Kind Of
  K_LINE,K_POLYLINE,K_POLY:Begin
   For I:=0 To O^.N-1 Do FlatAdd(F,O^.Pts^[I].X,O^.Pts^[I].Y);
   Closed:=O^.Kind=K_POLY;
  End;
  K_RECT,K_TEXT,K_BITMAP:Begin
   ObjBBox(O,X1,Y1,X2,Y2);
   FlatAdd(F,X1,Y1); FlatAdd(F,X2,Y1); FlatAdd(F,X2,Y2); FlatAdd(F,X1,Y2);
   Closed:=True;
  End;
  K_ELLIPSE:Begin
   ObjBBox(O,X1,Y1,X2,Y2);
   CX:=(X1+X2) Div 2; CY:=(Y1+Y2) Div 2;
   RX:=(X2-X1) Div 2; RY:=(Y2-Y1) Div 2;
   For I:=0 To 47 Do
    FlatAdd(F,CX+(RX*ECos[I]) Div 1000,CY+(RY*ESin[I]) Div 1000);
   Closed:=True;
  End;
  K_BEZIER:Begin
   FlatAdd(F,O^.Pts^[0].X,O^.Pts^[0].Y);
   I:=0;
   While I+3<=O^.N-1 Do Begin
    If O^.Pts^[I+1].X=BRK Then Begin
     FlatBreak(F);
     FlatAdd(F,O^.Pts^[I+3].X,O^.Pts^[I+3].Y);
     Inc(I,3);
     Continue;
    End;
    For J:=0 To 3 Do P[J]:=O^.Pts^[I+J];
    For T:=1 To Steps Do Begin
     U:=T/Steps;
     V:=1-U;
     A:=V*V*V; B:=3*V*V*U; C:=3*V*U*U; D:=U*U*U;
     FlatAdd(F,A*P[0].X+B*P[1].X+C*P[2].X+D*P[3].X,
               A*P[0].Y+B*P[1].Y+C*P[2].Y+D*P[3].Y);
    End;
    Inc(I,3);
   End;
   Closed:=O^.Closed;
  End;
 End;
End;

{ Remplace la geometrie de O par les contours de F (polygone, polyligne ou
  courbe composee de segments droits) }
Procedure FlatToObj(O:PObj;Var F:TFlat;Closed:Boolean);
Var C,I,S,E,Tot,K,M,Cn:LongInt;
    P:PPtArr;
    A,B:TPt;
Begin
 If F.N<2 Then Exit;
 If F.CN=1 Then Begin
  FreeMem(O^.Pts,O^.Cap*SizeOf(TPt));
  GetMem(O^.Pts,F.N*SizeOf(TPt));
  Move(F.P^,O^.Pts^,F.N*SizeOf(TPt));
  O^.N:=F.N;
  O^.Cap:=F.N;
  If Closed Then O^.Kind:=K_POLY Else O^.Kind:=K_POLYLINE;
  If(O^.Kind=K_POLYLINE)and(F.N=2)Then O^.Kind:=K_LINE;
  O^.Closed:=Closed;
  Exit;
 End;
 Tot:=0;
 For C:=0 To F.CN-1 Do Begin
  S:=F.CS[C]; E:=FlatEnd(F,C);
  M:=E-S+1;
  If Closed Then Inc(M);
  Inc(Tot,3*(M-1)+1);
  If C>0 Then Inc(Tot,2);
 End;
 If Tot>7990 Then Exit;
 GetMem(P,Tot*SizeOf(TPt));
 K:=0;
 For C:=0 To F.CN-1 Do Begin
  S:=F.CS[C]; E:=FlatEnd(F,C);
  Cn:=E-S+1;
  If C>0 Then Begin
   P^[K].X:=BRK; P^[K].Y:=0;
   P^[K+1].X:=BRK; P^[K+1].Y:=0;
   Inc(K,2);
  End;
  M:=Cn;
  If Closed Then Inc(M);
  For I:=0 To M-2 Do Begin
   A:=F.P^[S+I];
   B:=F.P^[S+(I+1) Mod Cn];
   P^[K]:=A;
   P^[K+1].X:=A.X+(B.X-A.X) Div 3;
   P^[K+1].Y:=A.Y+(B.Y-A.Y) Div 3;
   P^[K+2].X:=A.X+(2*(B.X-A.X)) Div 3;
   P^[K+2].Y:=A.Y+(2*(B.Y-A.Y)) Div 3;
   Inc(K,3);
  End;
  P^[K]:=F.P^[S+(M-1) Mod Cn];
  Inc(K);
 End;
 FreeMem(O^.Pts,O^.Cap*SizeOf(TPt));
 O^.Pts:=P;
 O^.N:=Tot;
 O^.Cap:=Tot;
 O^.Kind:=K_BEZIER;
 O^.Closed:=Closed;
End;

Var
 BEdge:PEdgeArr;
 BSplit:PSplitArr;
 BOut:POutArr;
 BEdgeN,BSplitN,BOutN:LongInt;

Procedure BAddSplit(E:LongInt;T:Double;X,Y:LongInt);
Var K,Prv,Cur:LongInt;
Begin
 If BSplitN>=SPL_MAX Then Exit;
 K:=BSplitN;
 Inc(BSplitN);
 BSplit^[K].T:=T;
 BSplit^[K].X:=X;
 BSplit^[K].Y:=Y;
 Prv:=-1;
 Cur:=BEdge^[E].Head;
 While(Cur>=0)and(BSplit^[Cur].T<T)Do Begin
  Prv:=Cur;
  Cur:=BSplit^[Cur].Next;
 End;
 BSplit^[K].Next:=Cur;
 If Prv<0 Then BEdge^[E].Head:=K Else BSplit^[Prv].Next:=K;
End;

{ Les deux aretes se coupent-elles ? Ajoute alors le point de coupure aux deux }
Procedure BCross(I,J:LongInt);
Const Eps=1e-9;
Var DX1,DY1,DX2,DY2,Den,T,U,L1,L2:Double;
    PX0,PY0,QX0,QY0,IX,IY:LongInt;
    Hit:Boolean;
Begin
 PX0:=BEdge^[I].X1; PY0:=BEdge^[I].Y1;
 QX0:=BEdge^[J].X1; QY0:=BEdge^[J].Y1;
 DX1:=BEdge^[I].X2-PX0; DY1:=BEdge^[I].Y2-PY0;
 DX2:=BEdge^[J].X2-QX0; DY2:=BEdge^[J].Y2-QY0;
 Den:=DX1*DY2-DY1*DX2;
 If Den=0 Then Begin
  { paralleles : recouvrement colineaire ? }
  If((QX0-PX0)*DY1-(QY0-PY0)*DX1)<>0 Then Exit;
  L1:=DX1*DX1+DY1*DY1;
  L2:=DX2*DX2+DY2*DY2;
  If(L1=0)or(L2=0)Then Exit;
  T:=((QX0-PX0)*DX1+(QY0-PY0)*DY1)/L1;
  If(T>Eps)and(T<1-Eps)Then BAddSplit(I,T,QX0,QY0);
  T:=((BEdge^[J].X2-PX0)*DX1+(BEdge^[J].Y2-PY0)*DY1)/L1;
  If(T>Eps)and(T<1-Eps)Then BAddSplit(I,T,BEdge^[J].X2,BEdge^[J].Y2);
  U:=((PX0-QX0)*DX2+(PY0-QY0)*DY2)/L2;
  If(U>Eps)and(U<1-Eps)Then BAddSplit(J,U,PX0,PY0);
  U:=((BEdge^[I].X2-QX0)*DX2+(BEdge^[I].Y2-QY0)*DY2)/L2;
  If(U>Eps)and(U<1-Eps)Then BAddSplit(J,U,BEdge^[I].X2,BEdge^[I].Y2);
  Exit;
 End;
 T:=((QX0-PX0)*DY2-(QY0-PY0)*DX2)/Den;
 U:=((QX0-PX0)*DY1-(QY0-PY0)*DX1)/Den;
 Hit:=(T>=-Eps)and(T<=1+Eps)and(U>=-Eps)and(U<=1+Eps);
 If Not Hit Then Exit;
 If T<=Eps Then Begin IX:=PX0; IY:=PY0; End
  Else If T>=1-Eps Then Begin IX:=BEdge^[I].X2; IY:=BEdge^[I].Y2; End
  Else If U<=Eps Then Begin IX:=QX0; IY:=QY0; End
  Else If U>=1-Eps Then Begin IX:=BEdge^[J].X2; IY:=BEdge^[J].Y2; End
  Else Begin
   IX:=Round(PX0+T*DX1);
   IY:=Round(PY0+T*DY1);
  End;
 If(T>Eps)and(T<1-Eps)Then BAddSplit(I,T,IX,IY);
 If(U>Eps)and(U<1-Eps)Then BAddSplit(J,U,IX,IY);
End;

{ Point (X,Y) a l'interieur de l'ensemble de contours de proprietaire Own
  (regle pair-impair) }
Function BInside(Own:Byte;X,Y:Double):Boolean;
Var I:LongInt;
    Ins:Boolean;
    YA,YB,XA,XB:Double;
Begin
 Ins:=False;
 For I:=0 To BEdgeN-1 Do
  If BEdge^[I].Own=Own Then Begin
   XA:=BEdge^[I].X1; YA:=BEdge^[I].Y1;
   XB:=BEdge^[I].X2; YB:=BEdge^[I].Y2;
   If(YA>Y)<>(YB>Y)Then
    If X<XA+(Y-YA)*(XB-XA)/(YB-YA) Then Ins:=Not Ins;
  End;
 BInside:=Ins;
End;

Function BRes(Op:Integer;A,B:Boolean):Boolean;
Begin
 Case Op Of
  0:BRes:=A or B;
  1:BRes:=A and B;
 Else BRes:=A and Not B;
 End;
End;

Procedure BEmit(X1,Y1,X2,Y2:LongInt);
Begin
 If(BOutN<OUT_MAX)and((X1<>X2)or(Y1<>Y2))Then Begin
  BOut^[BOutN].X1:=X1; BOut^[BOutN].Y1:=Y1;
  BOut^[BOutN].X2:=X2; BOut^[BOutN].Y2:=Y2;
  BOut^[BOutN].Used:=False;
  Inc(BOutN);
 End;
End;

{ Ajoute les contours de F comme aretes de proprietaire Own }
Procedure BAddEdges(Var F:TFlat;Own:Byte);
Var C,I,S,E,J:LongInt;
Begin
 For C:=0 To F.CN-1 Do Begin
  S:=F.CS[C];
  E:=FlatEnd(F,C);
  If E-S<2 Then Continue;
  For I:=S To E Do Begin
   J:=I+1;
   If J>E Then J:=S;
   If((F.P^[I].X<>F.P^[J].X)or(F.P^[I].Y<>F.P^[J].Y))and(BEdgeN<EDGE_MAX)Then Begin
    BEdge^[BEdgeN].X1:=F.P^[I].X; BEdge^[BEdgeN].Y1:=F.P^[I].Y;
    BEdge^[BEdgeN].X2:=F.P^[J].X; BEdge^[BEdgeN].Y2:=F.P^[J].Y;
    BEdge^[BEdgeN].Own:=Own;
    BEdge^[BEdgeN].Head:=-1;
    Inc(BEdgeN);
   End;
  End;
 End;
End;

{ Operation booleenne sur deux ensembles de contours fermes :
  Op 0 union, 1 intersection, 2 A moins B. R recoit les contours du resultat ;
  retourne False si le resultat est vide }
Function BoolFlat(Op:Integer;Var A,B,R:TFlat):Boolean;
Var I,J,K,Cur,N0,N1:LongInt;
    SX,SY,PX0,PY0,CX,CY,NXp,NYp:LongInt;
    MX0,MY0,DX,DY,Len,NX,NY,Area:Double;
    AL,AR,BL,BR2,Found:Boolean;
    Own:Byte;
    Cnt,Q:LongInt;
    LoopX,LoopY:Array[0..3999] of LongInt;
 Procedure SubEdge(Ow:Byte;X1,Y1,X2,Y2:LongInt);
 Begin
  If(X1=X2)and(Y1=Y2)Then Exit;
  MX0:=(X1+X2)/2;
  MY0:=(Y1+Y2)/2;
  DX:=X2-X1;
  DY:=Y2-Y1;
  Len:=Sqrt(DX*DX+DY*DY);
  NX:=-DY/Len*0.6;
  NY:=DX/Len*0.6;
  AL:=BInside(0,MX0+NX,MY0+NY);
  AR:=BInside(0,MX0-NX,MY0-NY);
  BL:=BInside(1,MX0+NX,MY0+NY);
  BR2:=BInside(1,MX0-NX,MY0-NY);
  If Ow=1 Then
   If AL<>AR Then Exit;
  If BRes(Op,AL,BL)<>BRes(Op,AR,BR2)Then BEmit(X1,Y1,X2,Y2);
 End;
Begin
 BoolFlat:=False;
 FlatClear(R);
 GetMem(BEdge,EDGE_MAX*SizeOf(TEdge));
 GetMem(BSplit,SPL_MAX*SizeOf(TSplit));
 GetMem(BOut,OUT_MAX*SizeOf(TOutSeg));
 BEdgeN:=0; BSplitN:=0; BOutN:=0;
 BAddEdges(A,0);
 N0:=BEdgeN;
 BAddEdges(B,1);
 For I:=0 To N0-1 Do
  For J:=N0 To BEdgeN-1 Do BCross(I,J);
 For I:=0 To BEdgeN-1 Do Begin
  SX:=BEdge^[I].X1; SY:=BEdge^[I].Y1;
  Own:=BEdge^[I].Own;
  Cur:=BEdge^[I].Head;
  While Cur>=0 Do Begin
   SubEdge(Own,SX,SY,BSplit^[Cur].X,BSplit^[Cur].Y);
   SX:=BSplit^[Cur].X; SY:=BSplit^[Cur].Y;
   Cur:=BSplit^[Cur].Next;
  End;
  SubEdge(Own,SX,SY,BEdge^[I].X2,BEdge^[I].Y2);
 End;
 { chainage des segments retenus en contours fermes }
 For I:=0 To BOutN-1 Do
  If Not BOut^[I].Used Then Begin
   PX0:=BOut^[I].X1; PY0:=BOut^[I].Y1;
   LoopX[0]:=PX0; LoopY[0]:=PY0;
   Cnt:=1;
   BOut^[I].Used:=True;
   CX:=BOut^[I].X2; CY:=BOut^[I].Y2;
   Found:=True;
   While Found and((CX<>PX0)or(CY<>PY0))Do Begin
    If Cnt>=4000 Then Begin Found:=False; Break; End;
    LoopX[Cnt]:=CX; LoopY[Cnt]:=CY;
    Inc(Cnt);
    Found:=False;
    For K:=0 To BOutN-1 Do
     If Not BOut^[K].Used Then Begin
      If(BOut^[K].X1=CX)and(BOut^[K].Y1=CY)Then Begin
       NXp:=BOut^[K].X2; NYp:=BOut^[K].Y2;
       Found:=True;
      End
       Else If(BOut^[K].X2=CX)and(BOut^[K].Y2=CY)Then Begin
        NXp:=BOut^[K].X1; NYp:=BOut^[K].Y1;
        Found:=True;
       End;
      If Found Then Begin
       BOut^[K].Used:=True;
       CX:=NXp; CY:=NYp;
       Break;
      End;
     End;
   End;
   If Not Found Then Continue;
   { elimination des points alignes ou doubles }
   Q:=Cnt;
   K:=0;
   While(K<Q)and(Q>=3)Do Begin
    J:=(K+Q-1) Mod Q;
    DX:=LoopX[(K+1) Mod Q]-LoopX[K];
    DY:=LoopY[(K+1) Mod Q]-LoopY[K];
    Area:=(LoopX[K]-LoopX[J])*DY-(LoopY[K]-LoopY[J])*DX;
    If(Area=0)or((LoopX[K]=LoopX[J])and(LoopY[K]=LoopY[J]))Then Begin
     For N1:=K To Q-2 Do Begin
      LoopX[N1]:=LoopX[N1+1];
      LoopY[N1]:=LoopY[N1+1];
     End;
     Dec(Q);
     If K>0 Then Dec(K);
    End
     Else Inc(K);
   End;
   If Q<3 Then Continue;
   If(R.N+Q>FL_MAX)or(R.CN>=64)Then Continue;
   FlatBreak(R);
   For K:=0 To Q-1 Do Begin
    R.P^[R.N].X:=LoopX[K];
    R.P^[R.N].Y:=LoopY[K];
    Inc(R.N);
   End;
  End;
 FreeMem(BEdge,EDGE_MAX*SizeOf(TEdge));
 FreeMem(BSplit,SPL_MAX*SizeOf(TSplit));
 FreeMem(BOut,OUT_MAX*SizeOf(TOutSeg));
 BoolFlat:=R.N>=3;
End;

{ L'objet peut-il servir d'operande (forme fermee) ? }
Function BoolOK(O:PObj):Boolean;
Begin
 BoolOK:=(O^.Kind=K_POLY)or(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)or
         ((O^.Kind=K_BEZIER)and O^.Closed);
End;

Procedure FlatCopy(Var D,S:TFlat);
Begin
 Move(S.P^,D.P^,S.N*SizeOf(TPt));
 D.N:=S.N;
 D.CN:=S.CN;
 Move(S.CS,D.CS,SizeOf(S.CS));
End;

{ Soudure (0), intersection (1), avant moins arriere (2), arriere moins
  avant (3) sur les objets selectionnes }
Procedure BoolSel(Op:Integer);
Var Sl:TSelArr;
    N,I,Tgt,OpC:Integer;
    Acc,Nx,Rs:TFlat;
    Cl,Ok:Boolean;
    Tp,Pr,O:PObj;
Begin
 EditMsg:='';
 N:=CollectSel(Sl);
 If N<2 Then Begin
  EditMsg:='Sélectionnez au moins deux objets.';
  Exit;
 End;
 For I:=0 To N-1 Do
  If Not BoolOK(Sl[I])Then Begin
   EditMsg:='Seules les formes fermées sont acceptées.';
   Exit;
  End;
 { cible : objet dont le resultat reprend les attributs }
 If Op=2 Then Tgt:=N-1 Else Tgt:=0;
 Tp:=Sl[Tgt];
 FlatNew(Acc); FlatNew(Nx); FlatNew(Rs);
 FlatObj(Tp,Acc,12,Cl);
 Ok:=True;
 If Op<2 Then OpC:=Op Else OpC:=2;
 For I:=0 To N-1 Do
  If(I<>Tgt)and Ok Then Begin
   FlatObj(Sl[I],Nx,12,Cl);
   If BoolFlat(OpC,Acc,Nx,Rs)Then FlatCopy(Acc,Rs)
    Else Ok:=False;
  End;
 If Ok Then Begin
  PushUndo;
  Pr:=Sl[0]^.Prev;
  O:=NewObj(K_POLY,3);
  CopyStyle(O,Tp);
  FlatToObj(O,Acc,True);
  For I:=0 To N-1 Do DeleteObj(Sl[I]);
  ListInsertAfter(Pr,O);
  O^.Sel:=True;
  Modified:=True;
 End
  Else EditMsg:='Le résultat est vide.';
 FlatFree(Acc); FlatFree(Nx); FlatFree(Rs);
End;

{ Decoupe une forme fermee selon une ligne (couteau) : la forme et une ligne
  doivent etre selectionnees }
Procedure KnifeSel;
Var Sl:TSelArr;
    N,I,Sh,Ln,Side,Pieces:Integer;
    F,H,R:TFlat;
    Cl:Boolean;
    Big,DX,DY,Len,UX,UY:Double;
    X1,Y1,X2,Y2:LongInt;
    O,Pr:PObj;
Begin
 EditMsg:='';
 N:=CollectSel(Sl);
 Sh:=-1; Ln:=-1;
 For I:=0 To N-1 Do Begin
  If BoolOK(Sl[I])and(Sh<0)Then Sh:=I
   Else If((Sl[I]^.Kind=K_LINE)or(Sl[I]^.Kind=K_POLYLINE))and(Ln<0)Then Ln:=I;
 End;
 If(Sh<0)or(Ln<0)or(N<>2)Then Begin
  EditMsg:='Sélectionnez une forme fermée et une ligne.';
  Exit;
 End;
 X1:=Sl[Ln]^.Pts^[0].X; Y1:=Sl[Ln]^.Pts^[0].Y;
 X2:=Sl[Ln]^.Pts^[Sl[Ln]^.N-1].X; Y2:=Sl[Ln]^.Pts^[Sl[Ln]^.N-1].Y;
 DX:=X2-X1; DY:=Y2-Y1;
 Len:=Sqrt(DX*DX+DY*DY);
 If Len<1 Then Exit;
 UX:=DX/Len; UY:=DY/Len;
 Big:=400000;
 FlatNew(F); FlatNew(H); FlatNew(R);
 FlatObj(Sl[Sh],F,12,Cl);
 PushUndo;
 Pr:=Sl[Sh]^.Prev;
 If Pr=Sl[Ln] Then Pr:=Pr^.Prev;
 Pieces:=0;
 For Side:=0 To 1 Do Begin
  FlatClear(H);
  If Side=0 Then Begin
   FlatAdd(H,X1-UX*Big,Y1-UY*Big);
   FlatAdd(H,X1+UX*Big,Y1+UY*Big);
   FlatAdd(H,X1+UX*Big-UY*Big,Y1+UY*Big+UX*Big);
   FlatAdd(H,X1-UX*Big-UY*Big,Y1-UY*Big+UX*Big);
  End
   Else Begin
    FlatAdd(H,X1-UX*Big,Y1-UY*Big);
    FlatAdd(H,X1-UX*Big+UY*Big,Y1-UY*Big-UX*Big);
    FlatAdd(H,X1+UX*Big+UY*Big,Y1+UY*Big-UX*Big);
    FlatAdd(H,X1+UX*Big,Y1+UY*Big);
   End;
  If BoolFlat(1,F,H,R)Then Begin
   O:=NewObj(K_POLY,3);
   CopyStyle(O,Sl[Sh]);
   FlatToObj(O,R,True);
   ListInsertAfter(Pr,O);
   Pr:=O;
   O^.Sel:=True;
   Inc(Pieces);
  End;
 End;
 FlatFree(F); FlatFree(H); FlatFree(R);
 If Pieces>0 Then Begin
  DeleteObj(Sl[Sh]);
  DeleteObj(Sl[Ln]);
  Modified:=True;
 End
  Else EditMsg:='La ligne ne coupe pas la forme.';
End;

{ Rend O en polygone dense (les courbes deviennent des segments courts) }
Procedure Densify(O:PObj);
Var F,G:TFlat;
    Cl:Boolean;
    C,S,E,I,J,K,Cn:LongInt;
    Tot,Step,Len:Double;
    X1,Y1,X2,Y2:Double;
Begin
 If(O^.Kind=K_TEXT)or(O^.Kind=K_BITMAP)Then Exit;
 FlatNew(F); FlatNew(G);
 FlatObj(O,F,16,Cl);
 Tot:=0;
 For I:=0 To F.N-2 Do
  Tot:=Tot+Sqrt(Sqr(1.0*F.P^[I+1].X-F.P^[I].X)+Sqr(1.0*F.P^[I+1].Y-F.P^[I].Y));
 Step:=Tot/3000;
 If Step<60 Then Step:=60;
 For C:=0 To F.CN-1 Do Begin
  S:=F.CS[C]; E:=FlatEnd(F,C);
  Cn:=E-S+1;
  If C>0 Then FlatBreak(G);
  For I:=S To E Do Begin
   X1:=F.P^[I].X; Y1:=F.P^[I].Y;
   FlatAdd(G,X1,Y1);
   If Cl or(I<E)Then Begin
    J:=S+((I-S+1) Mod Cn);
    X2:=F.P^[J].X; Y2:=F.P^[J].Y;
    Len:=Sqrt(Sqr(X2-X1)+Sqr(Y2-Y1));
    K:=Trunc(Len/Step);
    For J:=1 To K Do
     FlatAdd(G,X1+(X2-X1)*J/(K+1),Y1+(Y2-Y1)*J/(K+1));
   End;
  End;
 End;
 FlatToObj(O,G,Cl);
 FlatFree(F); FlatFree(G);
End;

{ Contours paralleles : N copies a la distance Dist (1/10 mm ; positif = vers
  l'exterieur, negatif = vers l'interieur) }
Procedure ContourSel(Steps:Integer;Dist:LongInt);
Var Sl:TSelArr;
    N,K,S:Integer;
    F,G:TFlat;
    Cl:Boolean;
    C,C2,I,P0,P1,Cn,St,En,Cross,Depth:LongInt;
    Area,D,E1X,E1Y,E2X,E2Y,L1,L2,N1X,N1Y,N2X,N2Y,Dot,MX,MY,ML,Sg,Px,Py:Double;
    Ax,Ay,Bx,By:LongInt;
    O,Pr:PObj;
Begin
 EditMsg:='';
 N:=CollectSel(Sl);
 If N=0 Then Begin
  EditMsg:='Sélectionnez un objet.';
  Exit;
 End;
 PushUndo;
 FlatNew(F); FlatNew(G);
 For K:=0 To N-1 Do Begin
  If Not BoolOK(Sl[K])Then Continue;
  FlatObj(Sl[K],F,12,Cl);
  If F.N<3 Then Continue;
  If Dist>=0 Then Pr:=Sl[K]^.Prev Else Pr:=Sl[K];
  For S:=1 To Steps Do Begin
   D:=Dist*S;
   FlatClear(G);
   For C:=0 To F.CN-1 Do Begin
    St:=F.CS[C]; En:=FlatEnd(F,C);
    Cn:=En-St+1;
    If Cn<3 Then Continue;
    Area:=0;
    For I:=0 To Cn-1 Do Begin
     P0:=St+I; P1:=St+((I+1) Mod Cn);
     Area:=Area+1.0*F.P^[P0].X*F.P^[P1].Y-1.0*F.P^[P1].X*F.P^[P0].Y;
    End;
    { profondeur d'emboitement : un trou se decale en sens inverse }
    Depth:=0;
    Px:=F.P^[St].X; Py:=F.P^[St].Y;
    For C2:=0 To F.CN-1 Do
     If C2<>C Then Begin
      Cross:=0;
      For I:=F.CS[C2] To FlatEnd(F,C2) Do Begin
       P0:=I;
       If I=FlatEnd(F,C2) Then P1:=F.CS[C2] Else P1:=I+1;
       Ax:=F.P^[P0].X; Ay:=F.P^[P0].Y; Bx:=F.P^[P1].X; By:=F.P^[P1].Y;
       If(Ay>Py)<>(By>Py)Then
        If Px<Ax+(Py-Ay)*(Bx-Ax)/(By-Ay) Then Inc(Cross);
      End;
      If Odd(Cross)Then Inc(Depth);
     End;
    Sg:=1;
    If Area<0 Then Sg:=-1;
    If Odd(Depth)Then Sg:=-Sg;
    If C>0 Then FlatBreak(G);
    For I:=0 To Cn-1 Do Begin
     P0:=St+((I+Cn-1) Mod Cn); P1:=St+((I+1) Mod Cn);
     E1X:=F.P^[St+I].X-F.P^[P0].X; E1Y:=F.P^[St+I].Y-F.P^[P0].Y;
     E2X:=F.P^[P1].X-F.P^[St+I].X; E2Y:=F.P^[P1].Y-F.P^[St+I].Y;
     L1:=Sqrt(E1X*E1X+E1Y*E1Y); L2:=Sqrt(E2X*E2X+E2Y*E2Y);
     If L1=0 Then L1:=1;
     If L2=0 Then L2:=1;
     N1X:=Sg*E1Y/L1; N1Y:=-Sg*E1X/L1;
     N2X:=Sg*E2Y/L2; N2Y:=-Sg*E2X/L2;
     Dot:=N1X*N2X+N1Y*N2Y;
     MX:=N1X+N2X; MY:=N1Y+N2Y;
     If 1+Dot<0.1 Then Begin
      ML:=Sqrt(MX*MX+MY*MY);
      If ML>0 Then Begin MX:=MX/ML*2; MY:=MY/ML*2; End;
     End
      Else Begin MX:=MX/(1+Dot); MY:=MY/(1+Dot); End;
     FlatAdd(G,F.P^[St+I].X+MX*D,F.P^[St+I].Y+MY*D);
    End;
   End;
   If G.N>=3 Then Begin
    O:=NewObj(K_POLY,3);
    CopyStyle(O,Sl[K]);
    O^.Shadow:=False;
    O^.Extrude:=False;
    FlatToObj(O,G,True);
    ListInsertAfter(Pr,O);
    If Dist<0 Then Pr:=O;
    Modified:=True;
   End;
  End;
 End;
 FlatFree(F); FlatFree(G);
End;

{ Deforme les objets selectionnes : effilement (perspective) ou enveloppe.
  Mode 0 haut, 1 bas, 2 gauche, 3 droite plus etroits ; 4 arc horizontal ;
  5 arc vertical ; 6 vague. Pct : amplitude en pour cent }
Procedure WarpSel(Mode,Pct:Integer);
Var Sl:TSelArr;
    N,K,I:Integer;
    X1,Y1,X2,Y2:LongInt;
    W,H,P,U,V,F,CX,CY,X,Y:Double;
    O:PObj;
Begin
 EditMsg:='';
 If Not SelBBox(X1,Y1,X2,Y2)Then Exit;
 W:=X2-X1; H:=Y2-Y1;
 If(W<=0)or(H<=0)Then Begin
  EditMsg:='La sélection est trop plate.';
  Exit;
 End;
 CX:=(X1+X2)/2; CY:=(Y1+Y2)/2;
 P:=Pct/100;
 N:=CollectSel(Sl);
 PushUndo;
 For K:=0 To N-1 Do Begin
  O:=Sl[K];
  If(O^.Kind=K_TEXT)or(O^.Kind=K_BITMAP)Then Continue;
  If Mode>=4 Then Densify(O)
   Else If(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)Then ToBezier(O);
  For I:=0 To O^.N-1 Do
   If O^.Pts^[I].X<>BRK Then Begin
    X:=O^.Pts^[I].X; Y:=O^.Pts^[I].Y;
    U:=(X-X1)/W; V:=(Y-Y1)/H;
    Case Mode Of
     0:Begin F:=1-P*(1-V); X:=CX+(X-CX)*F; End;
     1:Begin F:=1-P*V; X:=CX+(X-CX)*F; End;
     2:Begin F:=1-P*(1-U); Y:=CY+(Y-CY)*F; End;
     3:Begin F:=1-P*U; Y:=CY+(Y-CY)*F; End;
     4:Y:=Y-P*H*Sin(Pi*U);
     5:X:=X+P*W*Sin(Pi*V);
    Else Y:=Y+P*H*0.5*Sin(2*Pi*U);
    End;
    O^.Pts^[I].X:=Round(X);
    O^.Pts^[I].Y:=Round(Y);
   End;
 End;
 Modified:=True;
End;

{ Fusionne les objets selectionnes en une seule courbe composee }
Procedure CombineSel;
Var Sl:TSelArr;
    N,I,K,M:Integer;
    Tot:LongInt;
    P:PPtArr;
    O,Pr:PObj;
    AllClosed:Boolean;
Begin
 EditMsg:='';
 N:=CollectSel(Sl);
 If N<2 Then Begin
  EditMsg:='Sélectionnez au moins deux objets.';
  Exit;
 End;
 Tot:=0;
 AllClosed:=True;
 For I:=0 To N-1 Do Begin
  If(Sl[I]^.Kind=K_TEXT)or(Sl[I]^.Kind=K_BITMAP)Then Begin
   EditMsg:='Le texte et les bitmaps ne se combinent pas.';
   Exit;
  End;
 End;
 PushUndo;
 For I:=0 To N-1 Do Begin
  ToBezier(Sl[I]);
  Inc(Tot,Sl[I]^.N);
  If I>0 Then Inc(Tot,2);
  If Not Sl[I]^.Closed Then AllClosed:=False;
 End;
 If Tot>7990 Then Begin
  EditMsg:='Trop de nœuds.';
  Exit;
 End;
 GetMem(P,Tot*SizeOf(TPt));
 K:=0;
 For I:=0 To N-1 Do Begin
  If I>0 Then Begin
   P^[K].X:=BRK; P^[K].Y:=0;
   P^[K+1].X:=BRK; P^[K+1].Y:=0;
   Inc(K,2);
  End;
  For M:=0 To Sl[I]^.N-1 Do Begin
   P^[K]:=Sl[I]^.Pts^[M];
   Inc(K);
  End;
 End;
 O:=NewObj(K_BEZIER,3);
 CopyStyle(O,Sl[0]);
 FreeMem(O^.Pts,O^.Cap*SizeOf(TPt));
 O^.Pts:=P;
 O^.N:=Tot;
 O^.Cap:=Tot;
 O^.Closed:=AllClosed;
 If Not AllClosed Then Begin
  O^.FillKind:=FK_NONE;
  O^.FillCol:=-1;
 End;
 Pr:=Sl[0]^.Prev;
 For I:=0 To N-1 Do DeleteObj(Sl[I]);
 ListInsertAfter(Pr,O);
 O^.Sel:=True;
 Modified:=True;
End;

{ Separe une courbe composee en objets independants }
Procedure BreakApartSel;
Var Sl:TSelArr;
    N,K:Integer;
    I,S,M:Integer;
    O,Pr,Q:PObj;
    Any:Boolean;
 Procedure Piece(A,B:Integer);
 Var J:Integer;
 Begin
  If B-A<3 Then Exit;
  Q:=NewObj(K_BEZIER,B-A+1);
  CopyStyle(Q,O);
  For J:=A To B Do Q^.Pts^[J-A]:=O^.Pts^[J];
  Q^.Closed:=O^.Closed;
  Q^.Group:=O^.Group;
  ListInsertAfter(Pr,Q);
  Pr:=Q;
  Q^.Sel:=True;
 End;
Begin
 EditMsg:='';
 N:=CollectSel(Sl);
 Any:=False;
 For K:=0 To N-1 Do
  If HasBrk(Sl[K])Then Any:=True;
 If Not Any Then Begin
  EditMsg:='Aucune courbe composée sélectionnée.';
  Exit;
 End;
 PushUndo;
 For K:=0 To N-1 Do Begin
  O:=Sl[K];
  If Not HasBrk(O)Then Continue;
  Pr:=O^.Prev;
  S:=0;
  I:=0;
  While I+3<=O^.N-1 Do Begin
   If O^.Pts^[I+1].X=BRK Then Begin
    Piece(S,I);
    S:=I+3;
   End;
   Inc(I,3);
  End;
  Piece(S,O^.N-1);
  M:=0;
  DeleteObj(O);
 End;
 Modified:=True;
End;

{ ------------------------------------------------------------------ }
{ Transformations numeriques                                          }
{ ------------------------------------------------------------------ }

Procedure XformObj(O:PObj;A,B,C,D,CX,CY:Double);
Var I:Integer;
    X1,Y1,X2,Y2:LongInt;
    Q:Array[0..3] of TPt;
    Sc:Double;
    LX,LY,HX,HY:LongInt;
 Procedure Map(Var P:TPt);
 Var DX,DY:Double;
 Begin
  DX:=P.X-CX;
  DY:=P.Y-CY;
  P.X:=Round(CX+A*DX+C*DY);
  P.Y:=Round(CY+B*DX+D*DY);
 End;
Begin
 If O^.Kind=K_TEXT Then Begin
  Q[0].X:=O^.Pts^[0].X+(Length(O^.Txt)*O^.TextSize) Div 2;
  Q[0].Y:=O^.Pts^[0].Y+O^.TextSize Div 2;
  Map(Q[0]);
  Sc:=Sqrt(Abs(A*D-B*C));
  O^.TextSize:=Clamp(Round(O^.TextSize*Sc),20,2000);
  O^.Pts^[0].X:=Q[0].X-(Length(O^.Txt)*O^.TextSize) Div 2;
  O^.Pts^[0].Y:=Q[0].Y-O^.TextSize Div 2;
  Exit;
 End;
 If(O^.Kind=K_BITMAP)or(((O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE))and(B=0)and(C=0))Then Begin
  ObjBBox(O,X1,Y1,X2,Y2);
  Q[0].X:=X1; Q[0].Y:=Y1; Q[1].X:=X2; Q[1].Y:=Y1;
  Q[2].X:=X2; Q[2].Y:=Y2; Q[3].X:=X1; Q[3].Y:=Y2;
  For I:=0 To 3 Do Map(Q[I]);
  LX:=Q[0].X; HX:=Q[0].X; LY:=Q[0].Y; HY:=Q[0].Y;
  For I:=1 To 3 Do Begin
   If Q[I].X<LX Then LX:=Q[I].X;
   If Q[I].X>HX Then HX:=Q[I].X;
   If Q[I].Y<LY Then LY:=Q[I].Y;
   If Q[I].Y>HY Then HY:=Q[I].Y;
  End;
  O^.Pts^[0].X:=LX; O^.Pts^[0].Y:=LY;
  O^.Pts^[1].X:=HX; O^.Pts^[1].Y:=HY;
  Exit;
 End;
 If(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)Then ToBezier(O);
 For I:=0 To O^.N-1 Do
  If O^.Pts^[I].X<>BRK Then Map(O^.Pts^[I]);
End;

{ Matrice 2x2 appliquee autour du centre de la selection }
Procedure AffineSel(A,B,C,D:Double);
Var X1,Y1,X2,Y2:LongInt;
    P:PObj;
Begin
 If Not SelBBox(X1,Y1,X2,Y2)Then Exit;
 PushUndo;
 P:=ObjHead;
 While P<>NIL Do Begin
  If P^.Sel Then XformObj(P,A,B,C,D,(X1+X2)/2,(Y1+Y2)/2);
  P:=P^.Next;
 End;
 Modified:=True;
End;

Procedure RotateSel(Deg:Double);
Var A:Double;
Begin
 A:=Deg*Pi/180;
 AffineSel(Cos(A),-Sin(A),Sin(A),Cos(A));
End;

Procedure SkewSel(HDeg,VDeg:Double);
Begin
 AffineSel(1,-Sin(VDeg*Pi/180)/Cos(VDeg*Pi/180),-Sin(HDeg*Pi/180)/Cos(HDeg*Pi/180),1);
End;

{ ------------------------------------------------------------------ }
{ Melange                                                             }
{ ------------------------------------------------------------------ }

Function LerpCol(C1,C2:Integer;T:Double):Integer;
Var R,G,B:Integer;
Begin
 If(C1<0)or(C2<0)Then Begin
  LerpCol:=C1;
  Exit;
 End;
 R:=Round(PalR[C1]+(PalR[C2]-PalR[C1])*T);
 G:=Round(PalG[C1]+(PalG[C2]-PalG[C1])*T);
 B:=Round(PalB[C1]+(PalB[C2]-PalB[C1])*T);
 LerpCol:=NearestColor(R,G,B);
End;

{ Etapes intermediaires entre les deux premiers objets selectionnes }
Procedure BlendSel(Steps:Integer);
Var Sl:TSelArr;
    N,I,J:Integer;
    A,B,CA,CB,O,Pr:PObj;
    T:Double;
    Same:Boolean;
    AX1,AY1,AX2,AY2,BX1,BY1,BX2,BY2,NX1,NY1,NX2,NY2:LongInt;
Begin
 EditMsg:='';
 N:=CollectSel(Sl);
 If N<>2 Then Begin
  EditMsg:='Sélectionnez exactement deux objets.';
  Exit;
 End;
 A:=Sl[0]; B:=Sl[1];
 If(A^.Kind=K_TEXT)or(B^.Kind=K_TEXT)or(A^.Kind=K_BITMAP)or(B^.Kind=K_BITMAP)Then Begin
  EditMsg:='Le mélange concerne les formes.';
  Exit;
 End;
 PushUndo;
 CA:=CloneObj(A);
 CB:=CloneObj(B);
 ToBezier(CA);
 ToBezier(CB);
 Same:=(CA^.Kind=K_BEZIER)and(CB^.Kind=K_BEZIER)and(CA^.N=CB^.N)and
       Not HasBrk(CA)and Not HasBrk(CB);
 ObjBBox(A,AX1,AY1,AX2,AY2);
 ObjBBox(B,BX1,BY1,BX2,BY2);
 Inc(GroupSeq);
 A^.Group:=GroupSeq;
 B^.Group:=GroupSeq;
 Pr:=A;
 For I:=1 To Steps Do Begin
  T:=I/(Steps+1);
  If Same Then Begin
   O:=CloneObj(CA);
   For J:=0 To O^.N-1 Do Begin
    O^.Pts^[J].X:=Round(CA^.Pts^[J].X+(CB^.Pts^[J].X-CA^.Pts^[J].X)*T);
    O^.Pts^[J].Y:=Round(CA^.Pts^[J].Y+(CB^.Pts^[J].Y-CA^.Pts^[J].Y)*T);
   End;
  End
   Else Begin
    O:=CloneObj(A);
    NX1:=Round(AX1+(BX1-AX1)*T); NY1:=Round(AY1+(BY1-AY1)*T);
    NX2:=Round(AX2+(BX2-AX2)*T); NY2:=Round(AY2+(BY2-AY2)*T);
    If(AX2>AX1)and(AY2>AY1)Then
     ObjScale(O,AX1,AY1,Max(1,NX2-NX1),AX2-AX1,Max(1,NY2-NY1),AY2-AY1);
    ObjMove(O,NX1-AX1,NY1-AY1);
   End;
  O^.Sel:=False;
  O^.Group:=GroupSeq;
  O^.FillCol:=LerpCol(A^.FillCol,B^.FillCol,T);
  O^.FillCol2:=LerpCol(A^.FillCol2,B^.FillCol2,T);
  O^.OutCol:=LerpCol(A^.OutCol,B^.OutCol,T);
  O^.OutW:=Round(A^.OutW+(B^.OutW-A^.OutW)*T);
  O^.Shadow:=False;
  ListInsertAfter(Pr,O);
  Pr:=O;
 End;
 FreeObj(CA);
 FreeObj(CB);
 Modified:=True;
End;

{ ------------------------------------------------------------------ }
{ Cotes et connecteurs                                                }
{ ------------------------------------------------------------------ }

Function NewLine(X1,Y1,X2,Y2:LongInt):PObj;
Var O:PObj;
Begin
 O:=NewObj(K_LINE,2);
 O^.Pts^[0].X:=X1; O^.Pts^[0].Y:=Y1;
 O^.Pts^[1].X:=X2; O^.Pts^[1].Y:=Y2;
 O^.OutCol:=0;
 O^.OutW:=3;
 O^.FillKind:=FK_NONE;
 O^.FillCol:=-1;
 O^.LineStyle:=0;
 NewLine:=O;
End;

{ Ligne de cote horizontale ou verticale sous / a droite de la selection }
Procedure DimensionSel(Vertical:Boolean);
Var X1,Y1,X2,Y2,V:LongInt;
    S:String;
    O,T:PObj;
    Gp:Integer;
Begin
 EditMsg:='';
 If Not SelBBox(X1,Y1,X2,Y2)Then Begin
  EditMsg:='Sélectionnez un objet.';
  Exit;
 End;
 PushUndo;
 Inc(GroupSeq);
 Gp:=GroupSeq;
 If Vertical Then Begin
  V:=X2+200;
  S:=MMStr(Y2-Y1)+' mm';
  O:=NewLine(V,Y1,V,Y2); O^.Group:=Gp; AddObj(O);
  O:=NewLine(X2+60,Y1,V+60,Y1); O^.Group:=Gp; AddObj(O);
  O:=NewLine(X2+60,Y2,V+60,Y2); O^.Group:=Gp; AddObj(O);
  O:=NewLine(V-40,Y1+60,V+40,Y1-20); O^.Group:=Gp; AddObj(O);
  O:=NewLine(V-40,Y2+20,V+40,Y2-60); O^.Group:=Gp; AddObj(O);
  T:=NewObj(K_TEXT,1);
  T^.Pts^[0].X:=V+90;
  T^.Pts^[0].Y:=(Y1+Y2) Div 2-60;
 End
  Else Begin
   V:=Y2+200;
   S:=MMStr(X2-X1)+' mm';
   O:=NewLine(X1,V,X2,V); O^.Group:=Gp; AddObj(O);
   O:=NewLine(X1,Y2+60,X1,V+60); O^.Group:=Gp; AddObj(O);
   O:=NewLine(X2,Y2+60,X2,V+60); O^.Group:=Gp; AddObj(O);
   O:=NewLine(X1+60,V-40,X1-20,V+40); O^.Group:=Gp; AddObj(O);
   O:=NewLine(X2-60,V+40,X2+20,V-40); O^.Group:=Gp; AddObj(O);
   T:=NewObj(K_TEXT,1);
   T^.Pts^[0].X:=(X1+X2) Div 2-(Length(S)*120) Div 2;
   T^.Pts^[0].Y:=V+90;
  End;
 T^.Txt:=S;
 T^.TextSize:=120;
 T^.FillCol:=0;
 T^.FillKind:=FK_SOLID;
 T^.OutCol:=-1;
 T^.Group:=Gp;
 AddObj(T);
 Modified:=True;
End;

{ Connecteur coude entre les deux objets selectionnes (trace fixe) }
Procedure ConnectSel;
Var Sl:TSelArr;
    N:Integer;
    AX1,AY1,AX2,AY2,BX1,BY1,BX2,BY2,MX,MY:LongInt;
    O:PObj;
Begin
 EditMsg:='';
 N:=CollectSel(Sl);
 If N<>2 Then Begin
  EditMsg:='Sélectionnez exactement deux objets.';
  Exit;
 End;
 ObjBBox(Sl[0],AX1,AY1,AX2,AY2);
 ObjBBox(Sl[1],BX1,BY1,BX2,BY2);
 PushUndo;
 O:=NewObj(K_POLYLINE,4);
 O^.FillKind:=FK_NONE;
 O^.FillCol:=-1;
 If Abs((AX1+AX2)-(BX1+BX2))>=Abs((AY1+AY2)-(BY1+BY2))Then Begin
  { liaison horizontale }
  If(AX1+AX2)<(BX1+BX2)Then Begin
   O^.Pts^[0].X:=AX2; O^.Pts^[3].X:=BX1;
  End
   Else Begin
    O^.Pts^[0].X:=AX1; O^.Pts^[3].X:=BX2;
   End;
  O^.Pts^[0].Y:=(AY1+AY2) Div 2;
  O^.Pts^[3].Y:=(BY1+BY2) Div 2;
  MX:=(O^.Pts^[0].X+O^.Pts^[3].X) Div 2;
  O^.Pts^[1].X:=MX; O^.Pts^[1].Y:=O^.Pts^[0].Y;
  O^.Pts^[2].X:=MX; O^.Pts^[2].Y:=O^.Pts^[3].Y;
 End
  Else Begin
   If(AY1+AY2)<(BY1+BY2)Then Begin
    O^.Pts^[0].Y:=AY2; O^.Pts^[3].Y:=BY1;
   End
    Else Begin
     O^.Pts^[0].Y:=AY1; O^.Pts^[3].Y:=BY2;
    End;
   O^.Pts^[0].X:=(AX1+AX2) Div 2;
   O^.Pts^[3].X:=(BX1+BX2) Div 2;
   MY:=(O^.Pts^[0].Y+O^.Pts^[3].Y) Div 2;
   O^.Pts^[1].Y:=MY; O^.Pts^[1].X:=O^.Pts^[0].X;
   O^.Pts^[2].Y:=MY; O^.Pts^[2].X:=O^.Pts^[3].X;
  End;
 AddObj(O);
 Modified:=True;
End;

{ ------------------------------------------------------------------ }
{ Noeuds                                                              }
{ ------------------------------------------------------------------ }

{ Operations sur le noeud (NodeObj,NodeIdx) de l'outil Forme :
  1 segment en ligne, 2 segment en courbe, 3 noeud lisse, 4 noeud symetrique,
  5 noeud anguleux, 6 casser le chemin, 7 fermer le chemin }
Procedure NodeOp(Op:Integer);
Var O,Q,Pr:PObj;
    A,S,I,J,M,Pre,Nxt:Integer;
    P:PPtArr;
    DX,DY,LI,LO,L1,L2:Double;
    VX,VY:Double;
    Sl:TSelArr;
    N,K:Integer;
 Function NodeSet:Boolean;
 Begin
  NodeSet:=(NodeObj>=0)and(NodeObj<ObjCount)and(NodeIdx>=0);
 End;
Begin
 EditMsg:='';
 If Op=7 Then Begin
  N:=CollectSel(Sl);
  PushUndo;
  For K:=0 To N-1 Do Begin
   O:=Sl[K];
   If(O^.Kind=K_POLYLINE)and(O^.N>=3)Then Begin
    O^.Kind:=K_POLY;
    O^.Closed:=True;
   End
    Else If(O^.Kind=K_BEZIER)and Not O^.Closed and Not HasBrk(O)Then Begin
     If(O^.Pts^[0].X<>O^.Pts^[O^.N-1].X)or(O^.Pts^[0].Y<>O^.Pts^[O^.N-1].Y)Then Begin
      M:=O^.N;
      If M+3>7990 Then Continue;
      ObjSetN(O,M+3);
      DX:=O^.Pts^[0].X-O^.Pts^[M-1].X;
      DY:=O^.Pts^[0].Y-O^.Pts^[M-1].Y;
      O^.Pts^[M].X:=O^.Pts^[M-1].X+Round(DX/3);
      O^.Pts^[M].Y:=O^.Pts^[M-1].Y+Round(DY/3);
      O^.Pts^[M+1].X:=O^.Pts^[M-1].X+Round(2*DX/3);
      O^.Pts^[M+1].Y:=O^.Pts^[M-1].Y+Round(2*DY/3);
      O^.Pts^[M+2]:=O^.Pts^[0];
     End;
     O^.Closed:=True;
    End;
  End;
  Modified:=True;
  Exit;
 End;
 If Not NodeSet Then Begin
  EditMsg:='Sélectionnez un nœud avec l''outil Forme.';
  Exit;
 End;
 O:=ObjAt(NodeObj);
 If(O=NIL)or(O^.Kind=K_TEXT)or(O^.Kind=K_BITMAP)Then Exit;
 PushUndo;
 O:=ObjAt(NodeObj);
 If(O^.Kind=K_LINE)or(O^.Kind=K_POLYLINE)or(O^.Kind=K_POLY)Then Begin
  NodeIdx:=NodeIdx*3;
  ToBezier(O);
 End
  Else If(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)Then Begin
   ToBezier(O);
   NodeIdx:=-1;
   EditMsg:='Forme convertie en courbe : resélectionnez le nœud.';
   Exit;
  End;
 If(O^.Kind<>K_BEZIER)or(NodeIdx>=O^.N)Then Exit;
 A:=NodeIdx;
 Case Op Of
  1,2:Begin
   Case A Mod 3 Of
    0:Begin
       If(A+3<=O^.N-1)and(O^.Pts^[A+1].X<>BRK)Then S:=A Else S:=A-3;
      End;
    1:S:=A-1;
   Else S:=A-2;
   End;
   If(S<0)or(S+3>O^.N-1)Then Exit;
   DX:=O^.Pts^[S+3].X-O^.Pts^[S].X;
   DY:=O^.Pts^[S+3].Y-O^.Pts^[S].Y;
   If Op=1 Then Begin
    O^.Pts^[S+1].X:=O^.Pts^[S].X+Round(DX/3);
    O^.Pts^[S+1].Y:=O^.Pts^[S].Y+Round(DY/3);
    O^.Pts^[S+2].X:=O^.Pts^[S].X+Round(2*DX/3);
    O^.Pts^[S+2].Y:=O^.Pts^[S].Y+Round(2*DY/3);
   End
    Else Begin
     O^.Pts^[S+1].X:=O^.Pts^[S].X+Round(DX/3-DY/4);
     O^.Pts^[S+1].Y:=O^.Pts^[S].Y+Round(DY/3+DX/4);
     O^.Pts^[S+2].X:=O^.Pts^[S].X+Round(2*DX/3-DY/4);
     O^.Pts^[S+2].Y:=O^.Pts^[S].Y+Round(2*DY/3+DX/4);
    End;
  End;
  3,4,5:Begin
   If Op=5 Then Begin
    EditMsg:='Nœud anguleux : les poignées sont indépendantes.';
    Exit;
   End;
   Case A Mod 3 Of
    1:A:=A-1;
    2:A:=A+1;
   End;
   If A>O^.N-1 Then Exit;
   Pre:=A-1;
   Nxt:=A+1;
   If O^.Closed and Not HasBrk(O)and((A=0)or(A=O^.N-1))Then Begin
    A:=0;
    Pre:=O^.N-2;
    Nxt:=1;
   End;
   If(Pre<0)or(Nxt>O^.N-1)Then Exit;
   If(O^.Pts^[Pre].X=BRK)or(O^.Pts^[Nxt].X=BRK)Then Exit;
   VX:=O^.Pts^[A].X-O^.Pts^[Pre].X;
   VY:=O^.Pts^[A].Y-O^.Pts^[Pre].Y;
   LI:=Sqrt(VX*VX+VY*VY);
   DX:=O^.Pts^[Nxt].X-O^.Pts^[A].X;
   DY:=O^.Pts^[Nxt].Y-O^.Pts^[A].Y;
   LO:=Sqrt(DX*DX+DY*DY);
   If(LI<1)and(LO<1)Then Exit;
   If LI<1 Then Begin
    { poignee entrante repliee : on aligne sur la sortante }
    VX:=-DX; VY:=-DY; LI:=LO;
   End;
   If Op=4 Then Begin
    LO:=(LI+LO)/2;
    LI:=LO;
   End;
   O^.Pts^[Nxt].X:=O^.Pts^[A].X+Round(VX/Sqrt(VX*VX+VY*VY)*LO);
   O^.Pts^[Nxt].Y:=O^.Pts^[A].Y+Round(VY/Sqrt(VX*VX+VY*VY)*LO);
   If Op=4 Then Begin
    O^.Pts^[Pre].X:=O^.Pts^[A].X-Round(VX/Sqrt(VX*VX+VY*VY)*LI);
    O^.Pts^[Pre].Y:=O^.Pts^[A].Y-Round(VY/Sqrt(VX*VX+VY*VY)*LI);
   End;
   If O^.Closed and(A=0)Then Begin
    O^.Pts^[O^.N-1]:=O^.Pts^[0];
   End;
  End;
  6:Begin
   Case A Mod 3 Of
    1:A:=A-1;
    2:A:=A+1;
   End;
   If HasBrk(O)Then Begin
    EditMsg:='Séparez d''abord la courbe composée.';
    Exit;
   End;
   If O^.Closed Then Begin
    If(A=0)or(A=O^.N-1)Then Begin
     O^.Closed:=False;
     O^.FillKind:=FK_NONE;
     O^.FillCol:=-1;
     Exit;
    End;
    M:=O^.N;
    GetMem(P,M*SizeOf(TPt));
    J:=0;
    For I:=A To M-1 Do Begin P^[J]:=O^.Pts^[I]; Inc(J); End;
    For I:=1 To A Do Begin P^[J]:=O^.Pts^[I]; Inc(J); End;
    FreeMem(O^.Pts,O^.Cap*SizeOf(TPt));
    O^.Pts:=P;
    O^.Cap:=M;
    O^.N:=M;
    O^.Closed:=False;
    O^.FillKind:=FK_NONE;
    O^.FillCol:=-1;
    NodeIdx:=-1;
   End
    Else Begin
     If(A<=0)or(A>=O^.N-1)Then Exit;
     Pr:=O;
     Q:=NewObj(K_BEZIER,O^.N-A);
     CopyStyle(Q,O);
     For I:=A To O^.N-1 Do Q^.Pts^[I-A]:=O^.Pts^[I];
     Q^.Group:=O^.Group;
     Q^.Closed:=False;
     O^.N:=A+1;
     ListInsertAfter(Pr,Q);
     NodeIdx:=-1;
    End;
  End;
 End;
 Modified:=True;
End;

{ ------------------------------------------------------------------ }
{ Recherche et remplacement                                           }
{ ------------------------------------------------------------------ }

{ Selectionne les objets qui ressemblent au premier objet selectionne :
  Mode 0 meme remplissage, 1 meme contour, 2 meme type }
Procedure SelectSame(Mode:Integer);
Var Ref,P:PObj;
    Hit:Boolean;
    Cnt:Integer;
Begin
 EditMsg:='';
 Ref:=NIL;
 P:=ObjHead;
 While P<>NIL Do Begin
  If P^.Sel Then Begin Ref:=P; Break; End;
  P:=P^.Next;
 End;
 If Ref=NIL Then Begin
  EditMsg:='Sélectionnez d''abord un objet de référence.';
  Exit;
 End;
 Cnt:=0;
 P:=ObjHead;
 While P<>NIL Do Begin
  If ObjPickable(P)Then Begin
   Case Mode Of
    0:Hit:=(P^.FillCol=Ref^.FillCol)and(P^.FillKind=Ref^.FillKind);
    1:Hit:=(P^.OutCol=Ref^.OutCol)and(P^.OutW=Ref^.OutW);
   Else Hit:=P^.Kind=Ref^.Kind;
   End;
   If Hit Then Begin
    P^.Sel:=True;
    Inc(Cnt);
   End;
  End;
  P:=P^.Next;
 End;
 EditMsg:=IStr(Cnt)+' objet(s) sélectionné(s).';
End;

{ Remplace une couleur par une autre dans tout le dessin (remplissage ou
  contour) ; retourne le nombre d'objets modifies }
Function ReplaceColor(C1,C2:Integer;Fill,Outline:Boolean):Integer;
Var P:PObj;
    Cnt:Integer;
Begin
 Cnt:=0;
 P:=ObjHead;
 While P<>NIL Do Begin
  If ObjPickable(P)Then Begin
   If Fill and(P^.FillCol=C1)and(P^.FillKind<>FK_NONE)Then Begin P^.FillCol:=C2; Inc(Cnt); End;
   If Fill and(P^.FillCol2=C1)and(P^.FillKind>=FK_GRADV)and(P^.FillKind<>FK_IMAGE)Then P^.FillCol2:=C2;
   If Outline and(P^.OutCol=C1)Then Begin P^.OutCol:=C2; Inc(Cnt); End;
  End;
  P:=P^.Next;
 End;
 ReplaceColor:=Cnt;
End;

{$ELSE}
Procedure BoolSel(Op:Integer);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure KnifeSel;
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure ContourSel(Steps:Integer;Dist:LongInt);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure WarpSel(Mode,Pct:Integer);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure CombineSel;
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure BreakApartSel;
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure RotateSel(Deg:Double);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure SkewSel(HDeg,VDeg:Double);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure AffineSel(A,B,C,D:Double);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure BlendSel(Steps:Integer);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure DimensionSel(Vertical:Boolean);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure ConnectSel;
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure NodeOp(Op:Integer);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Procedure SelectSame(Mode:Integer);
Begin
 EditMsg:='Non disponible dans cette version.';
End;
Function ReplaceColor(C1,C2:Integer;Fill,Outline:Boolean):Integer;
Begin
 ReplaceColor:=0;
End;
{$ENDIF}

{ ------------------------------------------------------------------ }
{ Formes regulieres, courbes                                         }
{ ------------------------------------------------------------------ }

Function MakeRegular(CX,CY,RX,RY:LongInt;Sides:Integer;Star:Boolean):PObj;
Var O:PObj;
    N,I:Integer;
    A,F:Real;
Begin
 If Sides<3 Then Sides:=3;
 If Star Then N:=Sides*2 Else N:=Sides;
 O:=NewObj(K_POLY,N);
 O^.Closed:=True;
 For I:=0 To N-1 Do Begin
  A:=-Pi/2+I*2*Pi/N;
  F:=1;
  If Star and Odd(I) Then F:=0.42;
  O^.Pts^[I].X:=CX+Round(RX*F*Cos(A));
  O^.Pts^[I].Y:=CY+Round(RY*F*Sin(A));
 End;
 MakeRegular:=O;
End;

{ Convertit une suite d'ancres en courbe de Bezier (Catmull-Rom) }
Function MakeSmoothCurve(Var P:Array of TPt;M:Integer):PObj;
Var O:PObj;
    I,A,B:Integer;
    P0,P1,P2,P3:TPt;
Begin
 If M<3 Then Begin
  O:=NewObj(K_POLYLINE,M);
  For I:=0 To M-1 Do O^.Pts^[I]:=P[I];
  MakeSmoothCurve:=O;
  Exit;
 End;
 O:=NewObj(K_BEZIER,3*(M-1)+1);
 O^.Pts^[0]:=P[0];
 For I:=0 To M-2 Do Begin
  A:=I-1; If A<0 Then A:=0;
  B:=I+2; If B>M-1 Then B:=M-1;
  P0:=P[A]; P1:=P[I]; P2:=P[I+1]; P3:=P[B];
  O^.Pts^[3*I+1].X:=P1.X+(P2.X-P0.X) Div 6;
  O^.Pts^[3*I+1].Y:=P1.Y+(P2.Y-P0.Y) Div 6;
  O^.Pts^[3*I+2].X:=P2.X-(P3.X-P1.X) Div 6;
  O^.Pts^[3*I+2].Y:=P2.Y-(P3.Y-P1.Y) Div 6;
  O^.Pts^[3*I+3]:=P2;
 End;
 MakeSmoothCurve:=O;
End;

Procedure InitTrig;
Var I:Integer;
    A:Real;
Begin
 For I:=0 To 47 Do Begin
  A:=I*2*Pi/48;
  ECos[I]:=Round(Cos(A)*1000);
  ESin[I]:=Round(Sin(A)*1000);
 End;
End;

Procedure ResetDefaults;
Begin
 DefOut:=0;
 DefFill:=-1;
 DefFill2:=15;
 DefOutW:=1;
 DefLineStyle:=0;
 DefFillKind:=FK_SOLID;
 DefPattern:=1;
 DefTextSize:=140;
 PolySides:=5;
End;

{ Calques, pages et reperes : etat initial d'un document }
Procedure ResetLayers;
Var I:Integer;
Begin
 For I:=1 To LAYER_N Do Begin
  LayerVis[I]:=True;
  LayerLock[I]:=False;
  LayerPrn[I]:=True;
  LayerName[I]:='Calque '+IStr(I);
 End;
 ActLayer:=1;
 CurPage:=1;
 PageCnt:=1;
 EditMaster:=False;
 GuideN:=0;
 NodeObj:=-1;
 NodeIdx:=-1;
End;

Procedure NewDocument;
Begin
 ClearDoc;
 ClearList(UndoList,UndoCnt);
 ClearList(RedoList,RedoCnt);
 ImgFreeAll;
 PageW:=2100;
 PageH:=2970;
 GridSize:=50;
 DocName:='';
 Modified:=False;
 GroupSeq:=0;
 ResetLayers;
End;

{ ------------------------------------------------------------------ }
{ Fichiers : CDR (RIFF), WPG (lecture), SVG (ecriture)              }
{ ------------------------------------------------------------------ }

Var
 FF:File;
 IOBad:Boolean;
 ChunkPos:Array[0..7] of LongInt;
 ChunkSP:Integer;

Procedure WrB(B:Byte);
Begin
 {$I-}BlockWrite(FF,B,1);{$I+}
 If IOResult<>0 Then IOBad:=True;
End;

Procedure WrW(W:Word);
Begin
 WrB(W And $FF);
 WrB(W Shr 8);
End;

Procedure WrL(L:LongInt);
Begin
 WrW(Word(L And $FFFF));
 WrW(Word((L Shr 16) And $FFFF));
End;

Procedure WrID(Const S:String);
Var I:Integer;
Begin
 For I:=1 To 4 Do WrB(Ord(S[I]));
End;

Procedure BeginChunk(Const Id,ListType:String);
Begin
 WrID(Id);
 ChunkPos[ChunkSP]:=FilePos(FF);
 Inc(ChunkSP);
 WrL(0);
 If ListType<>'' Then WrID(ListType);
End;

Procedure EndChunk;
Var Start,Stop,Size:LongInt;
Begin
 Dec(ChunkSP);
 Start:=ChunkPos[ChunkSP];
 Stop:=FilePos(FF);
 Size:=Stop-Start-4;
 If Odd(Size)Then Begin
  WrB(0);
  Stop:=Stop+1;
 End;
 {$I-}
 Seek(FF,Start);
 {$I+}
 WrL(Size);
 {$I-}
 Seek(FF,Stop);
 {$I+}
 If IOResult<>0 Then IOBad:=True;
End;

Function RdB:Byte;
Var B:Byte;
Begin
 B:=0;
 If Eof(FF)Then IOBad:=True
  Else Begin
   {$I-}BlockRead(FF,B,1);{$I+}
   If IOResult<>0 Then IOBad:=True;
  End;
 RdB:=B;
End;

Function RdW:Word;
Var L:Word;
Begin
 L:=RdB;
 RdW:=L Or (Word(RdB) Shl 8);
End;

Function RdL:LongInt;
Var L:LongInt;
Begin
 L:=RdW;
 RdL:=L Or (LongInt(RdW) Shl 16);
End;

Function RdID:String;
Var S:String;
    I:Integer;
Begin
 S:='';
 For I:=1 To 4 Do S:=S+Chr(RdB);
 RdID:=S;
End;

{ Ecrit un bloc d'octets dans le fichier en cours }
Procedure WrBlock(Var Buf;Len:LongInt);
Begin
 {$I-}BlockWrite(FF,Buf,Len);{$I+}
 If IOResult<>0 Then IOBad:=True;
End;

Function SaveCDR(Const Name:String):Boolean;
Var I,K:LongInt;
    O:PObj;
    Fl:Byte;
Begin
 SaveCDR:=False;
 IOBad:=False;
 ChunkSP:=0;
 Assign(FF,Name);
 {$I-}Rewrite(FF,1);{$I+}
 If IOResult<>0 Then Exit;
 BeginChunk('RIFF','CDR4');
 BeginChunk('vrsn','');
 WrW(CDR_VERSION);
 EndChunk;
 BeginChunk('DOCI','');
 WrL(PageW);
 WrL(PageH);
 WrL(GridSize);
 WrW(GroupSeq);
 EndChunk;
 BeginChunk('EXTR','');
 WrW(PageCnt);
 WrW(CurPage);
 WrW(ActLayer);
 For I:=1 To LAYER_N Do Begin
  Fl:=0;
  If LayerVis[I] Then Fl:=Fl Or 1;
  If LayerLock[I] Then Fl:=Fl Or 2;
  If LayerPrn[I] Then Fl:=Fl Or 4;
  WrB(Fl);
  WrB(Length(LayerName[I]));
  For K:=1 To Length(LayerName[I]) Do WrB(Ord(LayerName[I][K]));
 End;
 WrW(GuideN);
 For I:=0 To GuideN-1 Do Begin
  If GuideHor[I] Then WrB(1) Else WrB(0);
  WrL(GuidePos[I]);
 End;
 EndChunk;
 If PalUsed>PAL_COUNT Then Begin
  BeginChunk('PALT','');
  WrW(PalUsed-PAL_COUNT);
  For I:=PAL_COUNT To PalUsed-1 Do Begin
   WrB(PalR[I]);
   WrB(PalG[I]);
   WrB(PalB[I]);
  End;
  EndChunk;
 End;
 If ImgCount>0 Then Begin
  BeginChunk('LIST','imgs');
  For I:=1 To ImgCount Do Begin
   BeginChunk('img ','');
   WrW(Imgs[I]^.W);
   WrW(Imgs[I]^.H);
   If Imgs[I]^.Alpha Then WrB(1) Else WrB(0);
   WrBlock(Imgs[I]^.Pix^,LongInt(Imgs[I]^.W)*Imgs[I]^.H*3);
   If Imgs[I]^.Alpha Then WrBlock(Imgs[I]^.A^,LongInt(Imgs[I]^.W)*Imgs[I]^.H);
   EndChunk;
  End;
  EndChunk;
 End;
 BeginChunk('LIST','objs');
 For I:=0 To ObjCount-1 Do Begin
  O:=ObjAt(I);
  BeginChunk('obj ','');
  WrB(O^.Kind);
  Fl:=0;
  If O^.Closed Then Fl:=Fl Or 1;
  If O^.Shadow Then Fl:=Fl Or 2;
  If O^.Extrude Then Fl:=Fl Or 4;
  WrB(Fl);
  WrW(O^.Group);
  WrW(O^.OutCol+1);
  WrW(O^.FillCol+1);
  WrW(O^.FillCol2+1);
  WrB(O^.FillKind);
  WrB(O^.Pattern);
  WrB(O^.LineStyle);
  WrL(O^.OutW);
  WrL(O^.TextSize);
  WrW(O^.N);
  For K:=0 To O^.N-1 Do Begin
   WrL(O^.Pts^[K].X);
   WrL(O^.Pts^[K].Y);
  End;
  WrB(Length(O^.Txt));
  For K:=1 To Length(O^.Txt) Do WrB(Ord(O^.Txt[K]));
  WrB(Byte(O^.GradX));
  WrB(Byte(O^.GradY));
  WrW(O^.Img);
  WrW(O^.TileW);
  WrW(O^.TileH);
  WrB(O^.Layer);
  WrB(O^.Page);
  EndChunk;
 End;
 EndChunk;
 EndChunk;
 {$I-}Close(FF);{$I+}
 If IOResult<>0 Then IOBad:=True;
 SaveCDR:=Not IOBad;
End;

Function LoadCDR9(Const Name:String):Boolean;Forward;

Function LoadCDR(Const Name:String):Boolean;
Var Id,Form:String;
    Size,Pos,Data,Total:LongInt;
    O:PObj;
    I,K,N:Integer;
    Kind,Fl:Byte;
    Old:Byte;
    Tmp:TObj;
    L:Byte;
    Own:Boolean;
    Bw,Bh:Word;
    Ba:Boolean;
Begin
 LoadCDR:=False;
 IOBad:=False;
 Old:=FileMode;
 FileMode:=0;
 Assign(FF,Name);
 {$I-}Reset(FF,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Exit;
 Total:=FileSize(FF);
 Id:=RdID;
 Size:=RdL;
 Form:=RdID;
 Form:=UpStr(Form);
 If Id='KWAJ' Then Begin
  Close(FF);
  LoadCDR:=LoadCDR9(Name);
  Exit;
 End;
 If(Id<>'RIFF')or((Copy(Form,1,3)<>'CDR')and(Copy(Form,1,3)<>'CDT'))or IOBad Then Begin
  Close(FF);
  Exit;
 End;
 { le format du clone est un 'CDR4' dont le premier chunk est 'DOCI' }
 If Form<>'CDR4' Then Own:=False
  Else Begin
   {$I-}Seek(FF,22);{$I+}
   Own:=(IOResult=0)and(RdID='DOCI');
  End;
 If Not Own Then Begin
  Close(FF);
  LoadCDR:=LoadCDR9(Name);
  Exit;
 End;
 NewDocument;
 Pos:=12;
 While(Pos+8<=Total)and Not IOBad Do Begin
  {$I-}Seek(FF,Pos);{$I+}
  If IOResult<>0 Then Break;
  Id:=RdID;
  Size:=RdL;
  Data:=Pos+8;
  If(Size<0)or(Data+Size>Total+1)Then Break;
  If Id='LIST' Then Pos:=Data+4
  Else Begin
   If Id='DOCI' Then Begin
    PageW:=RdL;
    PageH:=RdL;
    GridSize:=RdL;
    GroupSeq:=RdW;
    If PageW<100 Then PageW:=2100;
    If PageH<100 Then PageH:=2970;
    If GridSize<1 Then GridSize:=50;
   End
    Else
   If Id='EXTR' Then Begin
    PageCnt:=Clamp(RdW,1,PAGE_MAX);
    CurPage:=Clamp(RdW,1,PageCnt);
    ActLayer:=Clamp(RdW,1,LAYER_N);
    For K:=1 To LAYER_N Do Begin
     Fl:=RdB;
     LayerVis[K]:=(Fl And 1)<>0;
     LayerLock[K]:=(Fl And 2)<>0;
     LayerPrn[K]:=(Fl And 4)<>0;
     L:=RdB;
     LayerName[K]:='';
     For N:=1 To L Do Begin
      If N<=16 Then LayerName[K]:=LayerName[K]+Chr(RdB) Else RdB;
     End;
    End;
    GuideN:=Clamp(RdW,0,GUIDE_MAX);
    For K:=0 To GuideN-1 Do Begin
     GuideHor[K]:=RdB<>0;
     GuidePos[K]:=RdL;
    End;
   End
    Else
   If Id='PALT' Then Begin
    N:=RdW;
    For K:=0 To N-1 Do Begin
     If PAL_COUNT+K<256 Then Begin
      PalR[PAL_COUNT+K]:=RdB;
      PalG[PAL_COUNT+K]:=RdB;
      PalB[PAL_COUNT+K]:=RdB;
     End;
    End;
    If PAL_COUNT+N>PalUsed Then PalUsed:=Min(256,PAL_COUNT+N);
    PalDirty:=True;
   End
    Else
   If Id='img ' Then Begin
    Bw:=RdW;
    Bh:=RdW;
    If RdB<>0 Then Ba:=True Else Ba:=False;
    K:=ImgNew(Bw,Bh,Ba);
    If K>0 Then Begin
     ImgPalSetup;
     {$I-}BlockRead(FF,Imgs[K]^.Pix^,LongInt(Bw)*Bh*3);{$I+}
     If Ba Then Begin {$I-}BlockRead(FF,Imgs[K]^.A^,LongInt(Bw)*Bh);{$I+} End;
     If IOResult<>0 Then IOBad:=True;
     ImgAverage(K);
    End;
   End
    Else
   If Id='obj ' Then Begin
    Kind:=RdB;
    Fl:=RdB;
    FillChar(Tmp,SizeOf(Tmp),0);
    Tmp.Kind:=Kind;
    Tmp.Layer:=1;
    Tmp.Page:=1;
    Tmp.Closed:=(Fl And 1)<>0;
    Tmp.Shadow:=(Fl And 2)<>0;
    Tmp.Extrude:=(Fl And 4)<>0;
    Tmp.Group:=RdW;
    Tmp.OutCol:=Integer(RdW)-1;
    Tmp.FillCol:=Integer(RdW)-1;
    Tmp.FillCol2:=Integer(RdW)-1;
    Tmp.FillKind:=RdB;
    Tmp.Pattern:=RdB;
    Tmp.LineStyle:=RdB;
    Tmp.OutW:=RdL;
    Tmp.TextSize:=RdL;
    N:=RdW;
    If(Kind>=1)and(Kind<=8)and(N>=1)and(N<=7999)and(N*8<=Size)And Not IOBad Then Begin
     O:=NewObj(Kind,N);
     Tmp.N:=O^.N;
     Tmp.Cap:=O^.Cap;
     Tmp.Pts:=O^.Pts;
     O^:=Tmp;
     For K:=0 To N-1 Do Begin
      O^.Pts^[K].X:=RdL;
      O^.Pts^[K].Y:=RdL;
     End;
     L:=RdB;
     If L>60 Then L:=60;
     O^.Txt:='';
     For K:=1 To L Do O^.Txt:=O^.Txt+Chr(RdB);
     If FilePos(FF)+2<=Data+Size Then Begin
      O^.GradX:=ShortInt(RdB);
      O^.GradY:=ShortInt(RdB);
     End;
     If FilePos(FF)+6<=Data+Size Then Begin
      O^.Img:=Integer(RdW);
      O^.TileW:=Integer(RdW);
      O^.TileH:=Integer(RdW);
     End;
     If FilePos(FF)+2<=Data+Size Then Begin
      O^.Layer:=RdB;
      O^.Page:=RdB;
     End;
     If(O^.Layer<1)or(O^.Layer>LAYER_N)Then O^.Layer:=1;
     If(O^.Img<0)or(O^.Img>ImgCount)Then O^.Img:=0;
     If Not AddObj(O)Then Break;
    End;
   End;
   Pos:=Data+Size+(Size And 1);
  End;
 End;
 Close(FF);
 Modified:=False;
 I:=0;
 LoadCDR:=Not IOBad;
End;

{ ---------------------------- SVG ---------------------------------- }

Function XmlEsc(Const S:String):String;
Var R:String;
    I:Integer;
Begin
 R:='';
 For I:=1 To Length(S) Do
  Case S[I] Of
   '&':R:=R+'&amp;';
   '<':R:=R+'&lt;';
   '>':R:=R+'&gt;';
   '"':R:=R+'&quot;';
  Else R:=R+S[I];
  End;
 XmlEsc:=R;
End;

Function SaveSVG(Const Name:String):Boolean;
Var T:Text;
    I,K:LongInt;
    O:PObj;
    S,Fill,Stroke:String;
    X1,Y1,X2,Y2:LongInt;
    Pass:Integer;
    DX:LongInt;
    GradN:Integer;
 Function PointsStr:String;
 Var R:String;
     J:LongInt;
 Begin
  R:='';
  For J:=0 To O^.N-1 Do Begin
   R:=R+IStr(O^.Pts^[J].X+DX)+','+IStr(O^.Pts^[J].Y+DX);
   If J<O^.N-1 Then R:=R+' ';
  End;
  PointsStr:=R;
 End;
Begin
 SaveSVG:=False;
 Assign(T,Name);
 {$I-}Rewrite(T);{$I+}
 If IOResult<>0 Then Exit;
 GradN:=0;
 WriteLn(T,'<?xml version="1.0" encoding="UTF-8"?>');
 WriteLn(T,'<svg xmlns="http://www.w3.org/2000/svg" width="',PageW Div 10,'mm" height="',
         PageH Div 10,'mm" viewBox="0 0 ',PageW,' ',PageH,'">');
 WriteLn(T,' <title>',XmlEsc(BaseOf(DocName)),'</title>');
 WriteLn(T,' <rect x="0" y="0" width="',PageW,'" height="',PageH,'" fill="#FFFFFF"/>');
 For I:=0 To ObjCount-1 Do Begin
  O:=ObjAt(I);
  For Pass:=0 To 1 Do Begin
   If(Pass=0)and Not O^.Shadow Then Continue;
   If Pass=0 Then DX:=60 Else DX:=0;
   If Pass=0 Then Begin
    Fill:='fill="#555555"';
    Stroke:='stroke="none"';
   End
    Else
   Begin
    Fill:='fill="none"';
    If(O^.FillKind=FK_SOLID)or(O^.FillKind=FK_IMAGE)Then Begin
     If O^.FillCol>=0 Then Fill:='fill="'+ColorHex(O^.FillCol)+'"';
    End
     Else
    If(O^.FillKind=FK_RADIAL)or(O^.FillKind=FK_CONIC)or(O^.FillKind=FK_SQUARE)Then Begin
     If O^.FillCol>=0 Then Begin
      Inc(GradN);
      WriteLn(T,' <defs><radialGradient id="g',GradN,'" cx="',50+O^.GradX,'%" cy="',50-O^.GradY,
              '%" r="70%"><stop offset="0" stop-color="',ColorHex(O^.FillCol),
              '"/><stop offset="1" stop-color="',ColorHex(O^.FillCol2),'"/></radialGradient></defs>');
      Fill:='fill="url(#g'+IStr(GradN)+')"';
     End;
    End
     Else
    If(O^.FillKind=FK_GRADV)or(O^.FillKind=FK_GRADH)Then Begin
     If O^.FillCol>=0 Then Begin
      Inc(GradN);
      Write(T,' <defs><linearGradient id="g',GradN,'" x1="0" y1="0" x2="');
      If O^.FillKind=FK_GRADV Then Write(T,'0" y2="1"') Else Write(T,'1" y2="0"');
      WriteLn(T,'><stop offset="0" stop-color="',ColorHex(O^.FillCol),
              '"/><stop offset="1" stop-color="',ColorHex(O^.FillCol2),'"/></linearGradient></defs>');
      Fill:='fill="url(#g'+IStr(GradN)+')"';
     End;
    End
     Else
    If O^.FillKind=FK_PATTERN Then Begin
     If O^.FillCol>=0 Then Fill:='fill="'+ColorHex(O^.FillCol)+'" fill-opacity="0.5"';
    End;
    If(O^.Kind=K_TEXT)Then Begin
     If O^.FillCol>=0 Then Fill:='fill="'+ColorHex(O^.FillCol)+'"'
                      Else Fill:='fill="'+ColorHex(O^.OutCol)+'"';
     Stroke:='stroke="none"';
    End
     Else
    If O^.OutCol>=0 Then Begin
     Stroke:='stroke="'+ColorHex(O^.OutCol)+'" stroke-width="'+IStr(Max(1,O^.OutW))+'"';
     If O^.LineStyle=1 Then Stroke:=Stroke+' stroke-dasharray="10 10"';
     If O^.LineStyle=2 Then Stroke:=Stroke+' stroke-dasharray="40 20"';
    End
     Else
    Stroke:='stroke="none"';
   End;
   If(O^.Kind=K_LINE)or(O^.Kind=K_POLYLINE)Then Fill:='fill="none"';
   If(O^.Kind=K_BEZIER)and Not O^.Closed Then Fill:='fill="none"';
   Case O^.Kind Of
    K_LINE:WriteLn(T,' <line x1="',O^.Pts^[0].X+DX,'" y1="',O^.Pts^[0].Y+DX,'" x2="',
                   O^.Pts^[1].X+DX,'" y2="',O^.Pts^[1].Y+DX,'" ',Stroke,'/>');
    K_RECT,K_BITMAP:Begin
     ObjBBox(O,X1,Y1,X2,Y2);
     WriteLn(T,' <rect x="',X1+DX,'" y="',Y1+DX,'" width="',X2-X1,'" height="',Y2-Y1,'" ',
             Fill,' ',Stroke,'/>');
    End;
    K_ELLIPSE:Begin
     ObjBBox(O,X1,Y1,X2,Y2);
     WriteLn(T,' <ellipse cx="',(X1+X2) Div 2+DX,'" cy="',(Y1+Y2) Div 2+DX,'" rx="',(X2-X1) Div 2,
             '" ry="',(Y2-Y1) Div 2,'" ',Fill,' ',Stroke,'/>');
    End;
    K_POLY,K_POLYLINE:Begin
     If O^.Kind=K_POLY Then Write(T,' <polygon points="') Else Write(T,' <polyline points="');
     For K:=0 To O^.N-1 Do Begin
      Write(T,O^.Pts^[K].X+DX,',',O^.Pts^[K].Y+DX);
      If K<O^.N-1 Then Write(T,' ');
     End;
     WriteLn(T,'" ',Fill,' ',Stroke,'/>');
    End;
    K_BEZIER:Begin
     If HasBrk(O)Then Fill:=Fill+' fill-rule="evenodd"';
     Write(T,' <path d="M',O^.Pts^[0].X+DX,' ',O^.Pts^[0].Y+DX);
     K:=1;
     While K+2<O^.N Do Begin
      If O^.Pts^[K].X=BRK Then Begin
       If O^.Closed Then Write(T,' Z');
       Write(T,' M',O^.Pts^[K+2].X+DX,' ',O^.Pts^[K+2].Y+DX);
      End
       Else
      Write(T,' C',O^.Pts^[K].X+DX,' ',O^.Pts^[K].Y+DX,' ',
            O^.Pts^[K+1].X+DX,' ',O^.Pts^[K+1].Y+DX,' ',
            O^.Pts^[K+2].X+DX,' ',O^.Pts^[K+2].Y+DX);
      Inc(K,3);
     End;
     If O^.Closed Then Write(T,' Z');
     WriteLn(T,'" ',Fill,' ',Stroke,'/>');
    End;
    K_TEXT:WriteLn(T,' <text x="',O^.Pts^[0].X+DX,'" y="',O^.Pts^[0].Y+O^.TextSize-O^.TextSize Div 8+DX,
                   '" font-family="monospace" font-size="',O^.TextSize,'" ',Fill,'>',XmlEsc(O^.Txt),'</text>');
   End;
  End;
 End;
 WriteLn(T,'</svg>');
 {$I-}Close(T);{$I+}
 SaveSVG:=IOResult=0;
End;

{ ---------------------------- WPG ---------------------------------- }

Function LoadWPG(Const Name:String;AppendToDoc:Boolean):Boolean;
Var
 Map:Array[0..255] of Integer;
 Old:Byte;
 Total,Pos,Data,Len,StartPos:LongInt;
 T,B:Byte;
 W:Word;
 I,K,Cnt,Step,Kept,Pass:LongInt;
 CurFillT,CurLineT:Byte;
 CurFill,CurLine:Integer;
 CurW:LongInt;
 X1,Y1,X2,Y2,BW,BH,TW,TH,OX,OY,RX1,RY1,RX2,RY2,TX,TY:LongInt;
 Sc:Real;
 First,Any:Boolean;
 O:PObj;

 Function SW:LongInt;
 Begin
  SW:=SmallInt(RdW);
 End;

 { Etendue (passe 1) }
 Procedure Upd(X,Y:LongInt);
 Begin
  If First Then Begin
   X1:=X; X2:=X; Y1:=Y; Y2:=Y;
   First:=False;
  End
   Else Begin
    If X<X1 Then X1:=X;
    If X>X2 Then X2:=X;
    If Y<Y1 Then Y1:=Y;
    If Y>Y2 Then Y2:=Y;
   End;
 End;

 Function MapX(X:LongInt):LongInt;
 Begin
  MapX:=OX+Round((X-X1)*Sc);
 End;

 Function MapY(Y:LongInt):LongInt;
 Begin
  MapY:=OY+Round((Y2-Y)*Sc);
 End;

 { Cree l'objet avec les attributs courants (passe 2) }
 Function Make(Kind:Byte;N:Integer;Closed:Boolean):PObj;
 Var Q:PObj;
 Begin
  Q:=NewObj(Kind,N);
  Q^.Closed:=Closed;
  If CurLineT=0 Then Q^.OutCol:=-1 Else Q^.OutCol:=Map[CurLine And 255];
  Q^.OutW:=Max(1,Round(CurW*Sc));
  If(Kind=K_LINE)or(Kind=K_POLYLINE)Then Begin
   Q^.FillKind:=FK_NONE;
   Q^.FillCol:=-1;
  End
   Else
  If CurFillT=0 Then Begin
   Q^.FillKind:=FK_NONE;
   Q^.FillCol:=-1;
  End
   Else Begin
    Q^.FillKind:=FK_SOLID;
    Q^.FillCol:=Map[CurFill And 255];
    If CurFillT>1 Then Begin
     Q^.FillKind:=FK_PATTERN;
     Q^.Pattern:=(CurFillT-2) Mod 8+1;
     Q^.FillCol2:=-1;
    End;
   End;
  Make:=Q;
 End;

 { Lit tous les enregistrements ; Pass=1 : etendue, Pass=2 : creation }
 Procedure Scan;
 Var I,K:LongInt;
 Begin
  Pos:=StartPos;
  For I:=0 To 255 Do Map[I]:=I And 15;
  CurFillT:=1; CurLineT:=1; CurFill:=0; CurLine:=0; CurW:=1;
  While(Pos+2<=Total)and Not IOBad Do Begin
   {$I-}Seek(FF,Pos);{$I+}
   T:=RdB;
   B:=RdB;
   Len:=B;
   If B=$FF Then Begin
    W:=RdW;
    If W>=$8000 Then Len:=(LongInt(W And $7FFF) Shl 16) Or RdW
                Else Len:=W;
   End;
   Data:=FilePos(FF);
   If(Len<0)or(Data+Len>Total)Then Break;
   Case T Of
    0:Break;
    1:Begin
     CurFillT:=RdB;
     CurFill:=RdB;
    End;
    2:Begin
     CurLineT:=RdB;
     CurLine:=RdB;
     CurW:=RdW;
    End;
    5:Begin
     RX1:=SW; RY1:=SW; RX2:=SW; RY2:=SW;
     If Pass=1 Then Begin
      Upd(RX1,RY1);
      Upd(RX2,RY2);
     End
      Else Begin
       O:=Make(K_LINE,2,False);
       O^.Pts^[0].X:=MapX(RX1); O^.Pts^[0].Y:=MapY(RY1);
       O^.Pts^[1].X:=MapX(RX2); O^.Pts^[1].Y:=MapY(RY2);
       AddObj(O);
      End;
    End;
    6,8:Begin
     Cnt:=RdW;
     If Cnt*4>Len Then Cnt:=Len Div 4-1;
     If Cnt>=2 Then Begin
      If Pass=1 Then Begin
       For K:=0 To Cnt-1 Do Begin
        TX:=SW;
        TY:=SW;
        Upd(TX,TY);
       End;
      End
       Else Begin
        { au plus 7900 noeuds par objet }
        Step:=1;
        While((Cnt-1) Div Step+2)>7900 Do Inc(Step);
        Kept:=(Cnt-1) Div Step+1;
        If(Cnt-1) Mod Step<>0 Then Inc(Kept);
        O:=Make(K_POLYLINE,Kept,T=8);
        If T=8 Then O^.Kind:=K_POLY;
        Kept:=0;
        For K:=0 To Cnt-1 Do Begin
         TX:=SW;
         TY:=SW;
         If((K Mod Step)=0)or(K=Cnt-1)Then Begin
          O^.Pts^[Kept].X:=MapX(TX);
          O^.Pts^[Kept].Y:=MapY(TY);
          Inc(Kept);
         End;
        End;
        AddObj(O);
       End;
     End;
    End;
    7:Begin
     RX1:=SW; RY1:=SW; RX2:=SW; RY2:=SW;
     If Pass=1 Then Begin
      Upd(RX1,RY1);
      Upd(RX1+RX2,RY1+RY2);
     End
      Else Begin
       O:=Make(K_RECT,2,True);
       O^.Pts^[0].X:=MapX(RX1); O^.Pts^[0].Y:=MapY(RY1);
       O^.Pts^[1].X:=MapX(RX1+RX2); O^.Pts^[1].Y:=MapY(RY1+RY2);
       ObjNormalize2(O);
       AddObj(O);
      End;
    End;
    9:Begin
     RX1:=SW; RY1:=SW; RX2:=SW; RY2:=SW;
     If Pass=1 Then Begin
      Upd(RX1-RX2,RY1-RY2);
      Upd(RX1+RX2,RY1+RY2);
     End
      Else Begin
       O:=Make(K_ELLIPSE,2,True);
       O^.Pts^[0].X:=MapX(RX1-RX2); O^.Pts^[0].Y:=MapY(RY1-RY2);
       O^.Pts^[1].X:=MapX(RX1+RX2); O^.Pts^[1].Y:=MapY(RY1+RY2);
       ObjNormalize2(O);
       AddObj(O);
      End;
    End;
    14:Begin
     RX1:=RdW;
     Cnt:=RdW;
     For K:=0 To Cnt-1 Do Begin
      TW:=RdB; TH:=RdB; BW:=RdB;
      If(RX1+K>=0)and(RX1+K<=255)Then Map[RX1+K]:=NearestColor(TW,TH,BW);
     End;
    End;
   End;
   Pos:=Data+Len;
  End;
 End;

Begin
 LoadWPG:=False;
 IOBad:=False;
 Old:=FileMode;
 FileMode:=0;
 Assign(FF,Name);
 {$I-}Reset(FF,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Exit;
 Total:=FileSize(FF);
 If(RdB<>$FF)or(RdB<>Ord('W'))or(RdB<>Ord('P'))or(RdB<>Ord('C'))Then Begin
  Close(FF);
  Exit;
 End;
 StartPos:=RdL;
 If(StartPos<16)or(StartPos>=Total)Then StartPos:=16;
 First:=True;
 X1:=0; Y1:=0; X2:=0; Y2:=0;
 Pass:=1;
 Scan;
 If First Then Begin
  Close(FF);
  Exit;
 End;
 BW:=X2-X1;
 BH:=Y2-Y1;
 If BW<1 Then BW:=1;
 If BH<1 Then BH:=1;
 If Not AppendToDoc Then Begin
  NewDocument;
  If BW>BH Then Begin
   PageW:=2970;
   PageH:=2100;
  End;
 End;
 TW:=PageW-400;
 TH:=PageH-400;
 Sc:=TW/BW;
 If TH/BH<Sc Then Sc:=TH/BH;
 OX:=(PageW-Round(BW*Sc)) Div 2;
 OY:=(PageH-Round(BH*Sc)) Div 2;
 Pass:=2;
 Scan;
 Close(FF);
 Any:=ObjCount>0;
 Modified:=False;
 LoadWPG:=Any;
End;

{ ------------------------------------------------------------------ }
{ Chargement / enregistrement selon l'extension                      }
{ ------------------------------------------------------------------ }

{$IFDEF FPC}
Function LoadForeign(Const Name:String;Append:Boolean):Boolean;Forward;
{$ENDIF}

{ Formats importes par LoadForeign }
Function IsForeignExt(Const E:String):Boolean;
Begin
 IsForeignExt:=(E='.DXF')or(E='.EPS')or(E='.PS')or(E='.AI')or(E='.PDF')or(E='.WMF')or
               (E='.BMP')or(E='.PCX')or(E='.PNG');
End;

Function LoadAny(Const Name:String):Boolean;
Var E:String;
Begin
 C9Info:='';
 FromCorel:=False;
 E:=ExtOf(Name);
 If E='.WPG' Then LoadAny:=LoadWPG(Name,False)
  {$IFDEF FPC}
  Else If IsForeignExt(E)Then LoadAny:=LoadForeign(Name,False)
  {$ENDIF}
  Else LoadAny:=LoadCDR(Name);
End;

{ ------------------------------------------------------------------ }
{ Exportation CorelDRAW 9 natif (RIFF "CDR9")                       }
{ Les formes sont ecrites en courbes ; le texte est converti en     }
{ courbes a partir de la police 8x8 (necessite le mode graphique).   }
{ Remplissages uniformes et couleurs de contour uniquement.          }
{ ------------------------------------------------------------------ }

Var
 GlyphRows:Array[0..255,0..7] of Byte;
 GlyphsReady:Boolean;

Function SaveCDR9(Const Name:String):Boolean;
Const
 Kappa=0.552284749830793;
Var F:File;
    Good:Boolean;
    Code,CloseCode,J,NC:Integer;
    I:LongInt;
    RootPos,DocPos,TablePos,EntryPos,PagePos,GroupPos,LayerPos:LongInt;
    NumPoints:LongInt;
    Mode,FillIndex,LineIndex:Integer;
    O:PObj;
    BL,BT,BR,BB:Real;
    Settings:Array[0..211] of LongInt;

 Procedure Bytes(Var Data;Count:Word);
 Var Got:Word;
     Error:Integer;
 Begin
  If Not Good Then Exit;
  {$I-}BlockWrite(F,Data,Count,Got);Error:=IOResult;{$I+}
  Good:=(Error=0)and(Got=Count);
 End;

 Procedure ByteValue(V:Byte);
 Begin
  Bytes(V,1);
 End;

 Procedure WordValue(V:Word);
 Var B:Array[0..1] of Byte;
 Begin
  B[0]:=V And 255;
  B[1]:=V Shr 8;
  Bytes(B,2);
 End;

 Procedure LongValue(V:LongInt);
 Var B:Array[0..3] of Byte;
     K:LongInt;
 Begin
  For K:=0 To 3 Do B[K]:=(V Shr (K*8)) And 255;
  Bytes(B,4);
 End;

 Procedure StringBytes(S:String);
 Begin
  If S<>'' Then Bytes(S[1],Length(S));
 End;

 Function Position:LongInt;
 Var P:LongInt;
     Error:Integer;
 Begin
  P:=0;
  If Good Then Begin
   {$I-}P:=FilePos(F);Error:=IOResult;{$I+}
   Good:=Error=0;
  End;
  Position:=P;
 End;

 Procedure SeekTo(P:LongInt);
 Var Error:Integer;
 Begin
  If Not Good Then Exit;
  {$I-}Seek(F,P);Error:=IOResult;{$I+}
  Good:=Error=0;
 End;

 Function Chunk(Tag:String):LongInt;
 Begin
  Chunk:=Position;
  StringBytes(Tag);
  LongValue(0);
 End;

 Function List(Kind:String):LongInt;
 Begin
  List:=Chunk('LIST');
  StringBytes(Kind);
 End;

 Procedure EndChunk(P:LongInt);
 Var Last,Size:LongInt;
 Begin
  If Not Good Then Exit;
  Last:=Position;
  Size:=Last-P-8;
  SeekTo(P+4);
  LongValue(Size);
  SeekTo(Last);
  If Odd(Size)Then ByteValue(0);
 End;

 Procedure NumberChunk(Tag:String;V:LongInt);
 Var P:LongInt;
 Begin
  P:=Chunk(Tag);
  LongValue(V);
  EndChunk(P);
 End;

 Procedure ColorValue(Index:Integer);
 Var C:LongInt;
 Begin
  C:=0;
  If Index<NC Then C:=(LongInt(PalR[Index]) Shl 16) Or (LongInt(PalG[Index]) Shl 8) Or PalB[Index];
  WordValue(5);
  WordValue(5);
  LongValue(0);
  LongValue(C);
 End;

 Procedure IdentityTransform;
 Var P,T,D:LongInt;
     K:LongInt;
 Begin
  P:=List('trfl');
  T:=Chunk('trfd');
  LongValue(80); LongValue(1); LongValue(16); LongValue(65535);
  LongValue(24); LongValue(80); WordValue(8);
  WordValue(0); LongValue(0);
  For K:=0 To 5 Do Begin
   LongValue(0);
   If(K=0)or(K=4)Then D:=$3FF00000 Else D:=0;
   LongValue(D);
  End;
  EndChunk(T);
  EndChunk(P);
 End;

 { 254000 unites/pouce, origine au centre de la page, Y vers le haut }
 Procedure Point(X,Y:Real);
 Begin
  LongValue(Round((X-PageW/2)*1000));
  LongValue(Round((PageH/2-Y)*1000));
 End;

 Procedure BoundingBox(Tag:String;L,T,R,B:Real;Twice:Boolean);
 Var P:LongInt;
     K,Count:LongInt;
 Begin
  P:=Chunk(Tag);
  If Twice Then Count:=2 Else Count:=1;
  For K:=1 To Count Do Begin
   Point(L,T);
   Point(R,B);
  End;
  EndChunk(P);
 End;

 Procedure Node(X,Y:Real;Kind:Byte);
 Begin
  If Mode=1 Then Point(X,Y)
   Else
  If Mode=2 Then ByteValue(Kind)
   Else Begin
    If NumPoints=0 Then Begin
     BL:=X; BR:=X; BT:=Y; BB:=Y;
    End
     Else Begin
      If X<BL Then BL:=X;
      If X>BR Then BR:=X;
      If Y<BT Then BT:=Y;
      If Y>BB Then BB:=Y;
     End;
    Inc(NumPoints);
   End;
 End;

 Procedure RectanglePath(X,Y,W,H:Real);
 Begin
  Node(X,Y,12);
  Node(X+W,Y,68);
  Node(X+W,Y+H,68);
  Node(X,Y+H,68);
  Node(X,Y,72);
 End;

 Procedure Cubic(X1,Y1,X2,Y2,X3,Y3:Real;Last:Boolean);
 Begin
  Node(X1,Y1,196);
  Node(X2,Y2,196);
  If Last Then Node(X3,Y3,136) Else Node(X3,Y3,132);
 End;

 Procedure Geometry;
 Var K,Row,Column,Start,Ch:LongInt;
     X,Y,RX,RY,CX,CY,Cell:Real;
     X1,Y1,X2,Y2:LongInt;
     T:String;
 Begin
  Case O^.Kind Of
   K_RECT,K_BITMAP:Begin
    ObjBBox(O,X1,Y1,X2,Y2);
    RectanglePath(X1,Y1,X2-X1,Y2-Y1);
   End;
   K_ELLIPSE:Begin
    ObjBBox(O,X1,Y1,X2,Y2);
    CX:=(X1+X2)/2; CY:=(Y1+Y2)/2;
    RX:=(X2-X1)/2; RY:=(Y2-Y1)/2;
    X:=RX*Kappa;
    Y:=RY*Kappa;
    Node(CX+RX,CY,12);
    Cubic(CX+RX,CY+Y,CX+X,CY+RY,CX,CY+RY,False);
    Cubic(CX-X,CY+RY,CX-RX,CY+Y,CX-RX,CY,False);
    Cubic(CX-RX,CY-Y,CX-X,CY-RY,CX,CY-RY,False);
    Cubic(CX+X,CY-RY,CX+RX,CY-Y,CX+RX,CY,True);
   End;
   K_LINE,K_POLYLINE,K_POLY:Begin
    If O^.Kind=K_POLY Then Node(O^.Pts^[0].X,O^.Pts^[0].Y,12)
                      Else Node(O^.Pts^[0].X,O^.Pts^[0].Y,4);
    For K:=1 To O^.N-1 Do Node(O^.Pts^[K].X,O^.Pts^[K].Y,68);
    If O^.Kind=K_POLY Then Node(O^.Pts^[0].X,O^.Pts^[0].Y,72);
   End;
   K_BEZIER:Begin
    If O^.Closed Then Node(O^.Pts^[0].X,O^.Pts^[0].Y,12)
                 Else Node(O^.Pts^[0].X,O^.Pts^[0].Y,4);
    K:=1;
    While K+2<=O^.N-1 Do Begin
     If O^.Pts^[K].X=BRK Then Begin
      If O^.Closed Then Node(O^.Pts^[K+2].X,O^.Pts^[K+2].Y,12) Else Node(O^.Pts^[K+2].X,O^.Pts^[K+2].Y,4);
     End
      Else Begin
       Node(O^.Pts^[K].X,O^.Pts^[K].Y,196);
       Node(O^.Pts^[K+1].X,O^.Pts^[K+1].Y,196);
       If O^.Closed and(K+2=O^.N-1)Then Node(O^.Pts^[K+2].X,O^.Pts^[K+2].Y,136)
                                    Else Node(O^.Pts^[K+2].X,O^.Pts^[K+2].Y,132);
      End;
     Inc(K,3);
    End;
   End;
   K_TEXT:Begin
    Cell:=O^.TextSize/8;
    T:=Conv(O^.Txt);
    For K:=1 To Length(T) Do Begin
     Ch:=Ord(T[K]);
     For Row:=0 To 7 Do Begin
      Column:=0;
      While Column<8 Do Begin
       If(GlyphRows[Ch,Row] And(1 Shl Column))<>0 Then Begin
        Start:=Column;
        Repeat
         Inc(Column);
        Until(Column=8)or((GlyphRows[Ch,Row] And(1 Shl Column))=0);
        RectanglePath(O^.Pts^[0].X+((K-1)*8+Start)*Cell,O^.Pts^[0].Y+Row*Cell,
                      (Column-Start)*Cell,Cell);
       End
        Else Inc(Column);
      End;
     End;
    End;
   End;
  End;
 End;

 Procedure ObjectColors;
 Begin
  FillIndex:=NC;
  LineIndex:=NC;
  If O^.OutCol>=0 Then LineIndex:=O^.OutCol;
  If O^.Kind=K_TEXT Then Begin
   LineIndex:=NC;
   If O^.FillCol>=0 Then FillIndex:=O^.FillCol
    Else If O^.OutCol>=0 Then FillIndex:=O^.OutCol;
  End
   Else
  If(O^.FillKind<>FK_NONE)and(O^.FillCol>=0)and
    ((O^.Kind=K_RECT)or(O^.Kind=K_BITMAP)or(O^.Kind=K_ELLIPSE)or(O^.Kind=K_POLY)or
     ((O^.Kind=K_BEZIER)and O^.Closed))Then FillIndex:=O^.FillCol;
 End;

 Procedure StyleRecord(Id,Parent:LongInt;Fill,Line:Integer;Default:Boolean);
 Begin
  LongValue(1);
  LongValue(Id);
  LongValue(Parent);
  If Default Then Begin
   LongValue(1); LongValue(1); LongValue(16);
   StringBytes('Default Graphic'+#0);
  End
   Else Begin
    LongValue(0); LongValue(0); LongValue(1); ByteValue(0);
   End;
  LongValue(1000+Fill);
  LongValue(2000+Line);
 End;

 Procedure LayerHeader(Kind:Integer;Flags:LongInt;Name:String);
 Var G,L:LongInt;
     N,Size:LongInt;
 Begin
  NumberChunk('flgs',Flags);
  G:=List('lgob');
  L:=Chunk('loda');
  N:=1;
  Size:=44;
  If Name<>'' Then Begin
   N:=2;
   Size:=53+Length(Name);
  End;
  LongValue(Size); LongValue(N); LongValue(20); LongValue(24+N*4);
  LongValue(Kind);
  If N=2 Then Begin
   LongValue(40); LongValue(52); LongValue(Size); LongValue(1000); LongValue(2000);
  End
   Else Begin
    LongValue(32); LongValue(44); LongValue(2000);
   End;
  ColorValue(0);
  If Name<>'' Then StringBytes(Name+#0);
  EndChunk(L);
  EndChunk(G);
 End;

 Procedure EmptyLayer(Kind:Integer;Flags:LongInt;Name:String);
 Var P:LongInt;
 Begin
  P:=List('layr');
  LayerHeader(Kind,Flags,Name);
  EndChunk(P);
 End;

 Procedure WriteObject(Index:LongInt);
 Var P,G,L,Size:LongInt;
 Begin
  O:=ObjAt(Index);
  Mode:=0;
  NumPoints:=0;
  Geometry;
  If NumPoints=0 Then Exit;
  If NumPoints>65535 Then Begin
   Good:=False;
   Exit;
  End;
  P:=List('obj ');
  NumberChunk('flgs',$08000A00);
  BoundingBox('bbox',BL,BT,BR,BB,False);
  BoundingBox('obbx',BL,BT,BR,BB,True);
  NumberChunk('usdn',Index+5);
  G:=List('lgob');
  L:=Chunk('loda');
  Size:=80+12+NumPoints*9;
  LongValue(Size); LongValue(5); LongValue(20); LongValue(44); LongValue(3);
  LongValue(64); LongValue(68); LongValue(72); LongValue(76); LongValue(80);
  LongValue(Size);
  LongValue(30); LongValue(100); LongValue(200); LongValue(12000); LongValue(12030);
  LongValue(0); LongValue(0); LongValue(3100+Index); LongValue(Index+5);
  WordValue(Word(NumPoints));
  WordValue(0);
  Mode:=1; Geometry;
  Mode:=2; Geometry;
  LongValue(0);
  LongValue(0);
  EndChunk(L);
  IdentityTransform;
  EndChunk(G);
  EndChunk(P);
 End;

Begin
 SaveCDR9:=False;
 NC:=PalUsed;
 Assign(F,Name);
 {$I-}Rewrite(F,1);Code:=IOResult;{$I+}
 If Code<>0 Then Exit;
 Good:=True;
 RootPos:=Chunk('RIFF');
 StringBytes('CDR9');
 EntryPos:=Chunk('vrsn');
 WordValue(900);
 EndChunk(EntryPos);
 DocPos:=List('doc ');
 EntryPos:=Chunk('mcfg');
 FillChar(Settings,SizeOf(Settings),0);
 Settings[0]:=8;
 Settings[1]:=PageW*1000;
 Settings[2]:=PageH*1000;
 Settings[3]:=3; Settings[4]:=1; Settings[7]:=1; Settings[8]:=1;
 For I:=0 To 211 Do LongValue(Settings[I]);
 EndChunk(EntryPos);
 TablePos:=List('filt');
 For I:=0 To NC Do Begin
  GroupPos:=List('filc');
  EntryPos:=Chunk('fild');
  LongValue(I+1);
  If I=NC Then Begin
   WordValue(0);
   WordValue(0);
  End
   Else Begin
    WordValue(1);
    WordValue(0);
    ColorValue(I);
    For J:=1 To 4 Do LongValue(0);
   End;
  EndChunk(EntryPos);
  EndChunk(GroupPos);
 End;
 EndChunk(TablePos);
 TablePos:=List('otlt');
 For I:=0 To NC Do Begin
  EntryPos:=Chunk('outl');
  LongValue(I+1);
  If I=NC Then WordValue(1) Else WordValue(2);
  WordValue(0); WordValue(0); WordValue(0);
  LongValue(2540);
  WordValue(100);
  WordValue(0);
  LongValue(0);
  For J:=1 To 13 Do
   If(J=3)or(J=11)Then LongValue($3FF00000) Else LongValue(0);
  If I=NC Then ColorValue(0) Else ColorValue(I);
  For J:=1 To 13 Do LongValue(0);
  EndChunk(EntryPos);
 End;
 EndChunk(TablePos);
 TablePos:=List('stlt');
 LongValue(ObjCount+2);
 LongValue(NC+1);
 For I:=0 To NC Do Begin
  LongValue(1000+I); LongValue(0); LongValue(I+1);
 End;
 LongValue(NC+1);
 For I:=0 To NC Do Begin
  LongValue(2000+I); LongValue(0); LongValue(I+1);
 End;
 For I:=1 To 10 Do LongValue(0);
 StyleRecord(3000,0,NC,0,True);
 StyleRecord(3001,3000,NC,0,False);
 For I:=0 To ObjCount-1 Do Begin
  O:=ObjAt(I);
  ObjectColors;
  StyleRecord(3100+I,3000,FillIndex,LineIndex,False);
 End;
 EndChunk(TablePos);
 EndChunk(DocPos);
 PagePos:=List('page');
 NumberChunk('flgs',LongInt($90010000));
 BoundingBox('bbox',PageW/2,PageH/2,PageW/2,PageH/2,False);
 GroupPos:=List('gobj');
 EmptyLayer(12,LongInt($9801000A),'Guides');
 EmptyLayer(17,LongInt($98010008),'Desktop');
 EmptyLayer(0,LongInt($98000000),'Layer 1');
 EmptyLayer(11,LongInt($9801011A),'Grid');
 EndChunk(GroupPos);
 EndChunk(PagePos);
 PagePos:=List('page');
 NumberChunk('flgs',LongInt($90000000));
 BoundingBox('bbox',0,0,PageW,PageH,False);
 BoundingBox('obbx',0,0,PageW,PageH,True);
 GroupPos:=List('gobj');
 EmptyLayer(12,LongInt($9801000A),'');
 EmptyLayer(17,LongInt($98010008),'');
 LayerPos:=List('layr');
 LayerHeader(0,LongInt($98000000),'');
 { Les objets CDR sont stockes du premier plan vers l'arriere-plan }
 For I:=ObjCount-1 DownTo 0 Do
  If Good Then WriteObject(I);
 EndChunk(LayerPos);
 EmptyLayer(11,LongInt($9801011A),'');
 EndChunk(GroupPos);
 GroupPos:=List('lgob');
 EntryPos:=Chunk('loda');
 LongValue(48); LongValue(2); LongValue(20); LongValue(32); LongValue(0);
 LongValue(40); LongValue(44); LongValue(48); LongValue(100); LongValue(12000);
 LongValue(0); LongValue(ObjCount+5);
 EndChunk(EntryPos);
 IdentityTransform;
 EndChunk(GroupPos);
 EndChunk(PagePos);
 EndChunk(RootPos);
 {$I-}Close(F);CloseCode:=IOResult;{$I+}
 SaveCDR9:=Good and(CloseCode=0);
End;

Var ExpMode:Integer;

{ ------------------------------------------------------------------ }
{ Exportations : PDF, EPS, DXF, WMF, BMP, PNG                          }
{ Mode de couleur : 0 RVB, 1 CMJN, 2..5 plaque C, M, J, N (separation)  }
{ ------------------------------------------------------------------ }

{$IFDEF FPC}

{ L'objet figure-t-il sur la page P (page maitresse comprise) ? }
Function ObjOnPage(O:PObj;P:Integer):Boolean;
Begin
 ObjOnPage:=False;
 If(O^.Layer>=1)and(O^.Layer<=LAYER_N)Then
  If Not(LayerVis[O^.Layer]and LayerPrn[O^.Layer])Then Exit;
 ObjOnPage:=(O^.Page=0)or(O^.Page=P);
End;

Function FN2(V:Double):String;
Var S:String;
Begin
 Str(V:0:2,S);
 FN2:=S;
End;

Procedure RGB01(C:Integer;Var R,G,B:Double);
Begin
 If(C<0)or(C>=PalUsed)Then Begin
  R:=0; G:=0; B:=0;
 End
  Else Begin
   R:=PalR[C]/255;
   G:=PalG[C]/255;
   B:=PalB[C]/255;
  End;
End;

Var
 XF:Text;
 XPdf:Boolean;
 XMode:Integer;
 XPH:LongInt;
 XPage:Integer;

Function XPx(X:LongInt):String;
Begin
 XPx:=FN2(X*72/254);
End;

Function XPy(Y:LongInt):String;
Begin
 XPy:=FN2((XPH-Y)*72/254);
End;

{ Couleur courante (remplissage ou contour) selon le mode }
Procedure XCol(C:Integer;Stroke:Boolean);
Var R,G,B,K,Cy,M,Y,V:Double;
Begin
 RGB01(C,R,G,B);
 If XMode=0 Then Begin
  Write(XF,FN2(R),' ',FN2(G),' ',FN2(B),' ');
  If XPdf Then Begin
   If Stroke Then WriteLn(XF,'RG') Else WriteLn(XF,'rg');
  End
   Else WriteLn(XF,'setrgbcolor');
  Exit;
 End;
 K:=R;
 If G>K Then K:=G;
 If B>K Then K:=B;
 K:=1-K;
 If K>=1 Then Begin Cy:=0; M:=0; Y:=0; End
  Else Begin
   Cy:=(1-R-K)/(1-K);
   M:=(1-G-K)/(1-K);
   Y:=(1-B-K)/(1-K);
  End;
 If XMode=1 Then Begin
  Write(XF,FN2(Cy),' ',FN2(M),' ',FN2(Y),' ',FN2(K),' ');
  If XPdf Then Begin
   If Stroke Then WriteLn(XF,'K') Else WriteLn(XF,'k');
  End
   Else WriteLn(XF,'setcmykcolor');
 End
  Else Begin
   Case XMode Of
    2:V:=Cy;
    3:V:=M;
    4:V:=Y;
   Else V:=K;
   End;
   Write(XF,FN2(1-V),' ');
   If XPdf Then Begin
    If Stroke Then WriteLn(XF,'G') Else WriteLn(XF,'g');
   End
    Else WriteLn(XF,'setgray');
  End;
End;

Procedure XPathOf(O:PObj;DX:LongInt);
Var K:Integer;
    Mv,Cv,Cl:String;
Begin
 If XPdf Then Begin Mv:='m'; Cv:='c'; Cl:='h'; End
  Else Begin Mv:='moveto'; Cv:='curveto'; Cl:='closepath'; End;
 WriteLn(XF,XPx(O^.Pts^[0].X+DX),' ',XPy(O^.Pts^[0].Y+DX),' ',Mv);
 K:=1;
 While K+2<O^.N Do Begin
  If O^.Pts^[K].X=BRK Then Begin
   If O^.Closed Then WriteLn(XF,Cl);
   WriteLn(XF,XPx(O^.Pts^[K+2].X+DX),' ',XPy(O^.Pts^[K+2].Y+DX),' ',Mv);
  End
   Else
  WriteLn(XF,XPx(O^.Pts^[K].X+DX),' ',XPy(O^.Pts^[K].Y+DX),' ',
          XPx(O^.Pts^[K+1].X+DX),' ',XPy(O^.Pts^[K+1].Y+DX),' ',
          XPx(O^.Pts^[K+2].X+DX),' ',XPy(O^.Pts^[K+2].Y+DX),' ',Cv);
  Inc(K,3);
 End;
 If O^.Closed Then WriteLn(XF,Cl);
End;

Function PsEsc(Const S:String):String;
Var I:Integer;
    R:String;
Begin
 R:='';
 For I:=1 To Length(S) Do Begin
  If(S[I]='(')or(S[I]=')')or(S[I]='\')Then R:=R+'\';
  R:=R+S[I];
 End;
 PsEsc:=R;
End;

Procedure XDrawObj(O:PObj;Shadow:Boolean);
Var C:PObj;
    DX:LongInt;
    Fill,Strk,EO:Boolean;
    FC:Integer;
    W:Double;
    D1,D2:LongInt;
Begin
 If Shadow Then DX:=60 Else DX:=0;
 If O^.Kind=K_TEXT Then Begin
  If Shadow Then Exit;
  If O^.FillCol>=0 Then FC:=O^.FillCol Else FC:=O^.OutCol;
  If FC<0 Then FC:=0;
  XCol(FC,False);
  If XPdf Then
   WriteLn(XF,'BT /F1 ',FN2(O^.TextSize*72/254),' Tf ',XPx(O^.Pts^[0].X),' ',
           XPy(O^.Pts^[0].Y+O^.TextSize-O^.TextSize Div 8),' Td (',PsEsc(O^.Txt),') Tj ET')
   Else
  Begin
   WriteLn(XF,'/Courier findfont ',FN2(O^.TextSize*72/254),' scalefont setfont');
   WriteLn(XF,XPx(O^.Pts^[0].X),' ',XPy(O^.Pts^[0].Y+O^.TextSize-O^.TextSize Div 8),
           ' moveto (',PsEsc(O^.Txt),') show');
  End;
  Exit;
 End;
 C:=CloneObj(O);
 If C^.Kind=K_BITMAP Then Begin
  C^.Kind:=K_RECT;
  C^.FillKind:=FK_SOLID;
  If(C^.Img>=1)and(C^.Img<=ImgCount)Then
   C^.FillCol:=NearestColor(Imgs[C^.Img]^.AR,Imgs[C^.Img]^.AG,Imgs[C^.Img]^.AB);
  C^.OutCol:=-1;
 End;
 ToBezier(C);
 If C^.Kind<>K_BEZIER Then Begin
  FreeObj(C);
  Exit;
 End;
 Fill:=C^.Closed and(C^.FillKind<>FK_NONE)and(C^.FillCol>=0);
 EO:=HasBrk(C);
 If Shadow Then Begin
  If Not Fill Then Begin FreeObj(C); Exit; End;
  FC:=8;
  Strk:=False;
 End
  Else Begin
   FC:=C^.FillCol;
   Strk:=C^.OutCol>=0;
   If Not Fill and Not Strk Then Strk:=True;
  End;
 W:=C^.OutW;
 If W<1 Then W:=1;
 W:=W*72/254;
 D1:=0; D2:=0;
 If C^.LineStyle=1 Then Begin D1:=10; D2:=10; End;
 If C^.LineStyle=2 Then Begin D1:=40; D2:=20; End;
 If XPdf Then Begin
  If Fill Then XCol(FC,False);
  If Strk Then Begin
   If C^.OutCol>=0 Then XCol(C^.OutCol,True) Else XCol(0,True);
   WriteLn(XF,FN2(W),' w');
   If D1>0 Then WriteLn(XF,'[',FN2(D1*72/254),' ',FN2(D2*72/254),'] 0 d')
    Else WriteLn(XF,'[] 0 d');
  End;
  XPathOf(C,DX);
  If Fill and Strk Then Begin
   If EO Then WriteLn(XF,'B*') Else WriteLn(XF,'B');
  End
   Else If Fill Then Begin
    If EO Then WriteLn(XF,'f*') Else WriteLn(XF,'f');
   End
   Else WriteLn(XF,'S');
 End
  Else Begin
   WriteLn(XF,'newpath');
   XPathOf(C,DX);
   If Fill Then Begin
    WriteLn(XF,'gsave');
    XCol(FC,False);
    If EO Then WriteLn(XF,'eofill') Else WriteLn(XF,'fill');
    WriteLn(XF,'grestore');
   End;
   If Strk Then Begin
    If C^.OutCol>=0 Then XCol(C^.OutCol,True) Else XCol(0,True);
    WriteLn(XF,FN2(W),' setlinewidth');
    If D1>0 Then WriteLn(XF,'[',FN2(D1*72/254),' ',FN2(D2*72/254),'] 0 setdash')
     Else WriteLn(XF,'[] 0 setdash');
    WriteLn(XF,'stroke');
   End;
  End;
 FreeObj(C);
End;

Procedure XPageBody(P:Integer);
Var O:PObj;
Begin
 O:=ObjHead;
 While O<>NIL Do Begin
  If ObjOnPage(O,P)Then Begin
   If O^.Shadow Then XDrawObj(O,True);
   XDrawObj(O,False);
  End;
  O:=O^.Next;
 End;
End;

{ ---------------------------- EPS ----------------------------------- }

Function SaveEPS(Const Name:String;Mode:Integer):Boolean;
Begin
 SaveEPS:=False;
 Assign(XF,Name);
 {$I-}Rewrite(XF);{$I+}
 If IOResult<>0 Then Exit;
 XPdf:=False;
 XMode:=Mode;
 XPH:=PageH;
 WriteLn(XF,'%!PS-Adobe-3.0 EPSF-3.0');
 WriteLn(XF,'%%BoundingBox: 0 0 ',Round(PageW*72/254+0.5),' ',Round(PageH*72/254+0.5));
 WriteLn(XF,'%%Creator: CORELDRW');
 WriteLn(XF,'%%Title: ',BaseOf(DocName));
 WriteLn(XF,'%%EndComments');
 WriteLn(XF,'1 setlinejoin');
 XPageBody(CurPage);
 WriteLn(XF,'showpage');
 WriteLn(XF,'%%EOF');
 {$I-}Close(XF);{$I+}
 SaveEPS:=IOResult=0;
End;

{ ---------------------------- PDF ----------------------------------- }

Var
 PF:File;
 PPos:LongInt;

Procedure PW(Const S:String);
Begin
 If S<>'' Then BlockWrite(PF,S[1],Length(S));
 Inc(PPos,Length(S));
End;

Function SavePDF(Const Name:String;Mode:Integer):Boolean;
Var Offs:Array[0..80] of LongInt;
    Pg,N,I:Integer;
    Tmp:String;
    TF:File;
    Buf:Array[0..4095] of Byte;
    L,Got,XrefAt:LongInt;
    MW,MH:String;
    Ok:Boolean;
Begin
 SavePDF:=False;
 Assign(PF,Name);
 {$I-}Rewrite(PF,1);{$I+}
 If IOResult<>0 Then Exit;
 PPos:=0;
 Tmp:=Name+'.tmp';
 MW:=FN2(PageW*72/254);
 MH:=FN2(PageH*72/254);
 XPdf:=True;
 XMode:=Mode;
 XPH:=PageH;
 PW('%PDF-1.4'#10);
 Offs[1]:=PPos;
 PW('1 0 obj'#10'<< /Type /Catalog /Pages 2 0 R >>'#10'endobj'#10);
 Offs[2]:=PPos;
 PW('2 0 obj'#10'<< /Type /Pages /Count '+IStr(PageCnt)+' /Kids [');
 For Pg:=1 To PageCnt Do PW(' '+IStr(4+2*(Pg-1))+' 0 R');
 PW(' ] >>'#10'endobj'#10);
 Offs[3]:=PPos;
 PW('3 0 obj'#10'<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>'#10'endobj'#10);
 Ok:=True;
 For Pg:=1 To PageCnt Do Begin
  Assign(XF,Tmp);
  {$I-}Rewrite(XF);{$I+}
  If IOResult<>0 Then Begin Ok:=False; Break; End;
  XPageBody(Pg);
  {$I-}Close(XF);{$I+}
  Assign(TF,Tmp);
  {$I-}Reset(TF,1);{$I+}
  If IOResult<>0 Then Begin Ok:=False; Break; End;
  L:=FileSize(TF);
  N:=4+2*(Pg-1);
  Offs[N]:=PPos;
  PW(IStr(N)+' 0 obj'#10'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 '+MW+' '+MH+
     '] /Contents '+IStr(N+1)+' 0 R /Resources << /Font << /F1 3 0 R >> >> >>'#10'endobj'#10);
  Offs[N+1]:=PPos;
  PW(IStr(N+1)+' 0 obj'#10'<< /Length '+IStr(L)+' >>'#10'stream'#10);
  Repeat
   BlockRead(TF,Buf,SizeOf(Buf),Got);
   If Got>0 Then Begin
    BlockWrite(PF,Buf,Got);
    Inc(PPos,Got);
   End;
  Until Got=0;
  Close(TF);
  Erase(TF);
  PW(#10'endstream'#10'endobj'#10);
 End;
 N:=3+2*PageCnt;
 XrefAt:=PPos;
 PW('xref'#10'0 '+IStr(N+1)+#10'0000000000 65535 f '#10);
 For I:=1 To N Do Begin
  Tmp:=IStr(Offs[I]);
  While Length(Tmp)<10 Do Tmp:='0'+Tmp;
  PW(Tmp+' 00000 n '#10);
 End;
 PW('trailer'#10'<< /Size '+IStr(N+1)+' /Root 1 0 R >>'#10'startxref'#10+IStr(XrefAt)+#10'%%EOF'#10);
 {$I-}Close(PF);{$I+}
 SavePDF:=Ok and(IOResult=0);
End;

{ ---------------------------- DXF ----------------------------------- }

Function AciOf(C:Integer):Integer;
Const
 Tab:Array[0..8,0..3] of Integer=((1,255,0,0),(2,255,255,0),(3,0,255,0),(4,0,255,255),
      (5,0,0,255),(6,255,0,255),(7,0,0,0),(8,128,128,128),(9,192,192,192));
Var I,Best:Integer;
    D,BD:LongInt;
Begin
 If(C<0)or(C>=PalUsed)Then Begin AciOf:=7; Exit; End;
 BD:=MaxLongInt;
 Best:=7;
 For I:=0 To 8 Do Begin
  D:=Sqr(LongInt(PalR[C])-Tab[I,1])+Sqr(LongInt(PalG[C])-Tab[I,2])+Sqr(LongInt(PalB[C])-Tab[I,3]);
  If D<BD Then Begin BD:=D; Best:=Tab[I,0]; End;
 End;
 AciOf:=Best;
End;

Function DxfNum(V:Double):String;
Var S:String;
Begin
 Str(V:0:3,S);
 DxfNum:=S;
End;

Function SaveDXF(Const Name:String):Boolean;
Var O:PObj;
    F:TFlat;
    Cl:Boolean;
    I,C,S,E,Col:LongInt;
    Ly:String;
    Used:Array[1..LAYER_N] of Boolean;
    L:Integer;
 Procedure G(Code:Integer;Const V:String);
 Begin
  WriteLn(XF,Code);
  WriteLn(XF,V);
 End;
Begin
 SaveDXF:=False;
 Assign(XF,Name);
 {$I-}Rewrite(XF);{$I+}
 If IOResult<>0 Then Exit;
 For L:=1 To LAYER_N Do Used[L]:=False;
 O:=ObjHead;
 While O<>NIL Do Begin
  If ObjOnPage(O,CurPage)and(O^.Layer>=1)and(O^.Layer<=LAYER_N)Then Used[O^.Layer]:=True;
  O:=O^.Next;
 End;
 G(0,'SECTION'); G(2,'HEADER'); G(9,'$ACADVER'); G(1,'AC1009'); G(0,'ENDSEC');
 G(0,'SECTION'); G(2,'TABLES'); G(0,'TABLE'); G(2,'LAYER'); G(70,'7');
 For L:=1 To LAYER_N Do
  If Used[L]Then Begin
   G(0,'LAYER'); G(2,'CALQUE'+IStr(L)); G(70,'0'); G(62,'7'); G(6,'CONTINUOUS');
  End;
 G(0,'ENDTAB'); G(0,'ENDSEC');
 G(0,'SECTION'); G(2,'ENTITIES');
 FlatNew(F);
 O:=ObjHead;
 While O<>NIL Do Begin
  If ObjOnPage(O,CurPage)Then Begin
   Ly:='CALQUE'+IStr(O^.Layer);
   If(O^.Layer<1)or(O^.Layer>LAYER_N)Then Ly:='0';
   If O^.FillCol>=0 Then Col:=AciOf(O^.FillCol) Else Col:=AciOf(O^.OutCol);
   If O^.OutCol>=0 Then Col:=AciOf(O^.OutCol);
   If O^.Kind=K_TEXT Then Begin
    G(0,'TEXT'); G(8,Ly); G(62,IStr(Col));
    G(10,DxfNum(O^.Pts^[0].X/10)); G(20,DxfNum((PageH-O^.Pts^[0].Y-O^.TextSize)/10)); G(30,'0.0');
    G(40,DxfNum(O^.TextSize/10)); G(1,O^.Txt);
   End
    Else Begin
     FlatObj(O,F,12,Cl);
     For C:=0 To F.CN-1 Do Begin
      S:=F.CS[C]; E:=FlatEnd(F,C);
      If E-S<1 Then Continue;
      If(E-S=1)and Not Cl Then Begin
       G(0,'LINE'); G(8,Ly); G(62,IStr(Col));
       G(10,DxfNum(F.P^[S].X/10)); G(20,DxfNum((PageH-F.P^[S].Y)/10)); G(30,'0.0');
       G(11,DxfNum(F.P^[E].X/10)); G(21,DxfNum((PageH-F.P^[E].Y)/10)); G(31,'0.0');
      End
       Else Begin
        G(0,'POLYLINE'); G(8,Ly); G(62,IStr(Col)); G(66,'1');
        If Cl Then G(70,'1') Else G(70,'0');
        For I:=S To E Do Begin
         G(0,'VERTEX'); G(8,Ly);
         G(10,DxfNum(F.P^[I].X/10)); G(20,DxfNum((PageH-F.P^[I].Y)/10)); G(30,'0.0');
        End;
        G(0,'SEQEND'); G(8,Ly);
       End;
     End;
    End;
  End;
  O:=O^.Next;
 End;
 FlatFree(F);
 G(0,'ENDSEC'); G(0,'EOF');
 {$I-}Close(XF);{$I+}
 SaveDXF:=IOResult=0;
End;

{ ---------------------------- WMF ----------------------------------- }

Var
 WF:File;
 WMax:LongInt;
 WSize:LongInt;

Procedure WW(V:LongInt);
Var W:Word;
Begin
 W:=Word(V And $FFFF);
 BlockWrite(WF,W,2);
 Inc(WSize,2);
End;

Procedure WL(V:LongInt);
Begin
 WW(V And $FFFF);
 WW((V Shr 16) And $FFFF);
End;

{ En-tete d'un enregistrement : taille en mots (parametres + 3), fonction }
Procedure WRec(ParamWords:LongInt;Func:Word);
Begin
 WL(ParamWords+3);
 WW(Func);
 If ParamWords+3>WMax Then WMax:=ParamWords+3;
End;

Function ColRef(C:Integer):LongInt;
Begin
 If(C<0)or(C>=PalUsed)Then ColRef:=0
  Else ColRef:=PalR[C]+(LongInt(PalG[C]) Shl 8)+(LongInt(PalB[C]) Shl 16);
End;

Procedure WmfPenBrush(PenStyle:Integer;PenW:LongInt;PenCol:LongInt;Fill:Boolean;FillCol:LongInt);
Begin
 WRec(5,$02FA);
 WW(PenStyle); WW(PenW); WW(0); WL(PenCol);
 WRec(4,$02FC);
 If Fill Then WW(0) Else WW(1);
 WL(FillCol); WW(0);
 WRec(1,$012D); WW(0);
 WRec(1,$012D); WW(1);
End;

Procedure WmfFree;
Begin
 WRec(1,$01F0); WW(0);
 WRec(1,$01F0); WW(1);
End;

Function SaveWMF(Const Name:String):Boolean;
Var O,C:PObj;
    F:TFlat;
    Cl,Fill,Strk:Boolean;
    I,K,N,S,E:LongInt;
    Ck:Word;
    Hd:Array[0..10] of Word;
    FC:Integer;
    T:String;
    Pad:Word;
Begin
 SaveWMF:=False;
 Assign(WF,Name);
 {$I-}Rewrite(WF,1);{$I+}
 If IOResult<>0 Then Exit;
 WMax:=0;
 WSize:=0;
 { en-tete "placeable" : cle, handle, boite, unites par pouce, reserve, somme }
 Hd[0]:=$CDD7; Hd[1]:=$9AC6; Hd[2]:=0;
 Hd[3]:=0; Hd[4]:=0; Hd[5]:=Word(PageW); Hd[6]:=Word(PageH); Hd[7]:=254; Hd[8]:=0; Hd[9]:=0;
 Ck:=0;
 For I:=0 To 9 Do Ck:=Ck Xor Hd[I];
 Hd[10]:=Ck;
 For I:=0 To 10 Do WW(Hd[I]);
 WW(1); WW(9); WW($0300); WL(0); WW(2); WL(0); WW(0);
 WRec(1,$0103); WW(8);
 WRec(2,$020B); WW(0); WW(0);
 WRec(2,$020C); WW(PageH); WW(PageW);
 FlatNew(F);
 O:=ObjHead;
 While O<>NIL Do Begin
  If ObjOnPage(O,CurPage)Then Begin
   If O^.Kind=K_TEXT Then Begin
    FC:=O^.FillCol;
    If FC<0 Then FC:=O^.OutCol;
    WRec(2,$0209); WL(ColRef(FC));
    WRec(25,$02FB);
    WW(-O^.TextSize); WW(0); WW(0); WW(0); WW(400);
    WW(0); WW(0); WW(0); WW(0);
    For I:=0 To 15 Do WW(0);
    T:=O^.Txt;
    WRec(1,$012D); WW(0);
    K:=(Length(T)+1) Div 2;
    WRec(K+3,$0521);
    WW(Length(T));
    For I:=0 To K-1 Do Begin
     N:=0;
     If 2*I+1<=Length(T)Then N:=Ord(T[2*I+1]);
     If 2*I+2<=Length(T)Then N:=N+Ord(T[2*I+2])*256;
     WW(N);
    End;
    WW(O^.Pts^[0].Y); WW(O^.Pts^[0].X);
    WRec(1,$01F0); WW(0);
   End
    Else Begin
     C:=CloneObj(O);
     If C^.Kind=K_BITMAP Then Begin
      C^.Kind:=K_RECT;
      C^.FillKind:=FK_SOLID;
      If(C^.Img>=1)and(C^.Img<=ImgCount)Then
       C^.FillCol:=NearestColor(Imgs[C^.Img]^.AR,Imgs[C^.Img]^.AG,Imgs[C^.Img]^.AB);
      C^.OutCol:=-1;
     End;
     FlatObj(C,F,10,Cl);
     Fill:=Cl and(C^.FillKind<>FK_NONE)and(C^.FillCol>=0);
     Strk:=C^.OutCol>=0;
     If Not Fill and Not Strk Then Strk:=True;
     If Strk Then Begin
      If C^.OutCol>=0 Then K:=ColRef(C^.OutCol) Else K:=0;
      WmfPenBrush(0,Max(1,C^.OutW),K,Fill,ColRef(C^.FillCol));
     End
      Else WmfPenBrush(5,1,0,Fill,ColRef(C^.FillCol));
     If F.N>=2 Then Begin
      If Cl and(F.CN=1)Then Begin
       WRec(1+2*F.N,$0324);
       WW(F.N);
       For I:=0 To F.N-1 Do Begin WW(F.P^[I].X); WW(F.P^[I].Y); End;
      End
       Else If Cl Then Begin
        WRec(1+F.CN+2*F.N,$0538);
        WW(F.CN);
        For K:=0 To F.CN-1 Do WW(FlatEnd(F,K)-F.CS[K]+1);
        For I:=0 To F.N-1 Do Begin WW(F.P^[I].X); WW(F.P^[I].Y); End;
       End
        Else Begin
         For K:=0 To F.CN-1 Do Begin
          S:=F.CS[K]; E:=FlatEnd(F,K);
          If E-S<1 Then Continue;
          N:=E-S+1;
          WRec(1+2*N,$0325);
          WW(N);
          For I:=S To E Do Begin WW(F.P^[I].X); WW(F.P^[I].Y); End;
         End;
        End;
     End;
     WmfFree;
     FreeObj(C);
    End;
  End;
  O:=O^.Next;
 End;
 FlatFree(F);
 WRec(0,$0000);
 { taille et plus grand enregistrement dans l'en-tete standard }
 Seek(WF,22+6);
 K:=(WSize-22) Div 2;
 WL(K);
 WW(2);
 WL(WMax);
 {$I-}Close(WF);{$I+}
 SaveWMF:=IOResult=0;
End;

{ ------------------- Images (BMP / PNG) : trame RVB ------------------ }

Type
 TRB=Array[0..199999999] of Byte;
 PRB=^TRB;

Var
 RW,RH:LongInt;
 RBuf:PRB;
 RDpi:Integer;

Procedure RPut(X,Y:LongInt;R,G,B:Byte);
Var P:LongInt;
Begin
 If(X<0)or(Y<0)or(X>=RW)or(Y>=RH)Then Exit;
 P:=(Y*RW+X)*3;
 RBuf^[P]:=R;
 RBuf^[P+1]:=G;
 RBuf^[P+2]:=B;
End;

Procedure RDisk(X,Y,Rad:LongInt;R,G,B:Byte);
Var I,J:LongInt;
Begin
 If Rad<=0 Then Begin RPut(X,Y,R,G,B); Exit; End;
 For J:=-Rad To Rad Do
  For I:=-Rad To Rad Do
   If I*I+J*J<=Rad*Rad+Rad Then RPut(X+I,Y+J,R,G,B);
End;

Procedure RLine(X1,Y1,X2,Y2,Rad:LongInt;R,G,B:Byte);
Var DX,DY,N,I:LongInt;
Begin
 DX:=X2-X1; DY:=Y2-Y1;
 N:=Abs(DX);
 If Abs(DY)>N Then N:=Abs(DY);
 If N=0 Then Begin RDisk(X1,Y1,Rad,R,G,B); Exit; End;
 For I:=0 To N Do RDisk(X1+(DX*I) Div N,Y1+(DY*I) Div N,Rad,R,G,B);
End;

{ Pixels par unite document (1/10 mm) : RDpi / 254 }
Function RPx(V:LongInt):LongInt;
Begin
 RPx:=(V*RDpi) Div 254;
End;

Procedure RFill(Var F:TFlat;R,G,B:Byte);
Var Y,C,I,J,S,E,N,K,T:LongInt;
    Xs:Array[0..1999] of LongInt;
    X1,Y1,X2,Y2,Ya,Yb,MinY,MaxY:LongInt;
Begin
 MinY:=MaxLongInt; MaxY:=-MaxLongInt;
 For I:=0 To F.N-1 Do Begin
  If RPx(F.P^[I].Y)<MinY Then MinY:=RPx(F.P^[I].Y);
  If RPx(F.P^[I].Y)>MaxY Then MaxY:=RPx(F.P^[I].Y);
 End;
 If MinY<0 Then MinY:=0;
 If MaxY>RH-1 Then MaxY:=RH-1;
 For Y:=MinY To MaxY Do Begin
  N:=0;
  For C:=0 To F.CN-1 Do Begin
   S:=F.CS[C]; E:=FlatEnd(F,C);
   For I:=S To E Do Begin
    If I=E Then J:=S Else J:=I+1;
    Y1:=RPx(F.P^[I].Y); Y2:=RPx(F.P^[J].Y);
    X1:=RPx(F.P^[I].X); X2:=RPx(F.P^[J].X);
    If(Y1>Y)<>(Y2>Y)Then
     If N<2000 Then Begin
      Xs[N]:=X1+((Y-Y1)*(X2-X1)) Div (Y2-Y1);
      Inc(N);
     End;
   End;
  End;
  For I:=1 To N-1 Do Begin
   T:=Xs[I];
   K:=I-1;
   While(K>=0)and(Xs[K]>T)Do Begin Xs[K+1]:=Xs[K]; Dec(K); End;
   Xs[K+1]:=T;
  End;
  I:=0;
  While I+1<N Do Begin
   For K:=Xs[I] To Xs[I+1] Do RPut(K,Y,R,G,B);
   Inc(I,2);
  End;
 End;
 Ya:=0; Yb:=0;
End;

Procedure RenderPage(P:Integer);
Var O,C:PObj;
    F:TFlat;
    Cl:Boolean;
    I,K,S,E,Rad,X1,Y1,X2,Y2,X,Y,IX,IY:LongInt;
    Im:PImage;
    A:Byte;
Begin
 FillChar(RBuf^,RW*RH*3,255);
 FlatNew(F);
 O:=ObjHead;
 While O<>NIL Do Begin
  If ObjOnPage(O,P)and(O^.Kind<>K_TEXT)Then Begin
   If(O^.Kind=K_BITMAP)and(O^.Img>=1)and(O^.Img<=ImgCount)Then Begin
    Im:=Imgs[O^.Img];
    ObjBBox(O,X1,Y1,X2,Y2);
    X1:=RPx(X1); X2:=RPx(X2); Y1:=RPx(Y1); Y2:=RPx(Y2);
    If(X2>X1)and(Y2>Y1)Then
     For Y:=Y1 To Y2 Do
      For X:=X1 To X2 Do Begin
       IX:=((X-X1)*Im^.W) Div (X2-X1+1);
       IY:=((Y-Y1)*Im^.H) Div (Y2-Y1+1);
       K:=(IY*Im^.W+IX);
       If(Im^.A=NIL)or(Im^.A^[K]>=128)Then
        RPut(X,Y,Im^.Pix^[K*3],Im^.Pix^[K*3+1],Im^.Pix^[K*3+2]);
      End;
   End
    Else Begin
     C:=CloneObj(O);
     If C^.Kind=K_BITMAP Then C^.Kind:=K_RECT;
     FlatObj(C,F,12,Cl);
     If Cl and(C^.FillKind<>FK_NONE)and(C^.FillCol>=0)and(C^.Kind<>K_BITMAP)Then
      RFill(F,PalR[C^.FillCol],PalG[C^.FillCol],PalB[C^.FillCol]);
     If(C^.OutCol>=0)or Not Cl Then Begin
      Rad:=RPx(Max(1,C^.OutW)) Div 2;
      If C^.OutCol>=0 Then K:=C^.OutCol Else K:=0;
      For I:=0 To F.CN-1 Do Begin
       S:=F.CS[I]; E:=FlatEnd(F,I);
       For Y:=S To E-1 Do
        RLine(RPx(F.P^[Y].X),RPx(F.P^[Y].Y),RPx(F.P^[Y+1].X),RPx(F.P^[Y+1].Y),Rad,PalR[K],PalG[K],PalB[K]);
       If Cl and(E>S)Then
        RLine(RPx(F.P^[E].X),RPx(F.P^[E].Y),RPx(F.P^[S].X),RPx(F.P^[S].Y),Rad,PalR[K],PalG[K],PalB[K]);
      End;
     End;
     FreeObj(C);
    End;
  End;
  O:=O^.Next;
 End;
 FlatFree(F);
 A:=0;
End;

Procedure RasterBegin;
Begin
 RDpi:=96;
 RW:=(PageW*RDpi) Div 254;
 RH:=(PageH*RDpi) Div 254;
 If RW<1 Then RW:=1;
 If RH<1 Then RH:=1;
 GetMem(RBuf,RW*RH*3);
End;

Procedure RasterEnd;
Begin
 FreeMem(RBuf,RW*RH*3);
End;

Function SaveBMP(Const Name:String):Boolean;
Var F:File;
    Row:Array[0..19999] of Byte;
    RB,Y,X,Sz,V:LongInt;
    Hd:Array[0..53] of Byte;
 Procedure L4(Pos,Val:LongInt);
 Begin
  Hd[Pos]:=Val And 255;
  Hd[Pos+1]:=(Val Shr 8) And 255;
  Hd[Pos+2]:=(Val Shr 16) And 255;
  Hd[Pos+3]:=(Val Shr 24) And 255;
 End;
Begin
 SaveBMP:=False;
 RasterBegin;
 If RW>6000 Then Begin RasterEnd; Exit; End;
 RenderPage(CurPage);
 Assign(F,Name);
 {$I-}Rewrite(F,1);{$I+}
 If IOResult<>0 Then Begin RasterEnd; Exit; End;
 RB:=((RW*3+3) Div 4)*4;
 Sz:=54+RB*RH;
 FillChar(Hd,SizeOf(Hd),0);
 Hd[0]:=Ord('B'); Hd[1]:=Ord('M');
 L4(2,Sz); L4(10,54); L4(14,40); L4(18,RW); L4(22,RH);
 Hd[26]:=1; Hd[28]:=24;
 L4(34,RB*RH); L4(38,3780); L4(42,3780);
 BlockWrite(F,Hd,54);
 For Y:=RH-1 DownTo 0 Do Begin
  FillChar(Row,RB,0);
  For X:=0 To RW-1 Do Begin
   V:=(Y*RW+X)*3;
   Row[X*3]:=RBuf^[V+2];
   Row[X*3+1]:=RBuf^[V+1];
   Row[X*3+2]:=RBuf^[V];
  End;
  BlockWrite(F,Row,RB);
 End;
 {$I-}Close(F);{$I+}
 SaveBMP:=IOResult=0;
 RasterEnd;
End;

Var
 CrcTab:Array[0..255] of LongInt;
 CrcReady:Boolean;

Procedure CrcInit;
Var N,K:Integer;
    C:LongInt;
Begin
 For N:=0 To 255 Do Begin
  C:=N;
  For K:=1 To 8 Do
   If(C And 1)<>0 Then C:=LongInt($EDB88320) Xor((C Shr 1) And $7FFFFFFF)
    Else C:=(C Shr 1) And $7FFFFFFF;
  CrcTab[N]:=C;
 End;
 CrcReady:=True;
End;

Function SavePNG(Const Name:String):Boolean;
Var F:File;
    Raw:PRB;
    RawLen,Pos,Y,X,Blk,N,I:LongInt;
    A,B:LongInt;
    Crc:LongInt;
    Idat:PRB;
    IdLen:LongInt;
 Procedure B4(V:LongInt);
 Var T:Array[0..3] of Byte;
 Begin
  T[0]:=(V Shr 24) And 255; T[1]:=(V Shr 16) And 255; T[2]:=(V Shr 8) And 255; T[3]:=V And 255;
  BlockWrite(F,T,4);
 End;
 Procedure CrcAdd(Var Data;Len:LongInt);
 Var P:PRB;
     K:LongInt;
 Begin
  P:=PRB(@Data);
  For K:=0 To Len-1 Do
   Crc:=CrcTab[(Crc Xor P^[K]) And 255] Xor((Crc Shr 8) And $FFFFFF);
 End;
 Procedure Chunk(Const Tag:String;Var Data;Len:LongInt);
 Var T:Array[0..3] of Byte;
     K:Integer;
 Begin
  B4(Len);
  For K:=0 To 3 Do T[K]:=Ord(Tag[K+1]);
  BlockWrite(F,T,4);
  Crc:=LongInt($FFFFFFFF);
  CrcAdd(T,4);
  If Len>0 Then Begin
   BlockWrite(F,Data,Len);
   CrcAdd(Data,Len);
  End;
  B4(Crc Xor LongInt($FFFFFFFF));
 End;
Var Sig:Array[0..7] of Byte;
    Ihdr:Array[0..12] of Byte;
    Z:Array[0..1] of Byte;
Begin
 SavePNG:=False;
 If Not CrcReady Then CrcInit;
 RasterBegin;
 If RW>4000 Then Begin RasterEnd; Exit; End;
 RenderPage(CurPage);
 { donnees brutes : un octet de filtre (0) par ligne }
 RawLen:=RH*(RW*3+1);
 GetMem(Raw,RawLen);
 Pos:=0;
 For Y:=0 To RH-1 Do Begin
  Raw^[Pos]:=0;
  Inc(Pos);
  Move(RBuf^[Y*RW*3],Raw^[Pos],RW*3);
  Inc(Pos,RW*3);
 End;
 { flux zlib en blocs "stockes" }
 IdLen:=2+((RawLen+65534) Div 65535)*5+RawLen+4;
 GetMem(Idat,IdLen);
 Idat^[0]:=$78; Idat^[1]:=$01;
 N:=2;
 Pos:=0;
 While Pos<RawLen Do Begin
  Blk:=RawLen-Pos;
  If Blk>65535 Then Blk:=65535;
  If Pos+Blk>=RawLen Then Idat^[N]:=1 Else Idat^[N]:=0;
  Idat^[N+1]:=Blk And 255; Idat^[N+2]:=(Blk Shr 8) And 255;
  Idat^[N+3]:=(Not Blk) And 255; Idat^[N+4]:=((Not Blk) Shr 8) And 255;
  Inc(N,5);
  Move(Raw^[Pos],Idat^[N],Blk);
  Inc(N,Blk);
  Inc(Pos,Blk);
 End;
 A:=1; B:=0;
 For I:=0 To RawLen-1 Do Begin
  A:=(A+Raw^[I]) Mod 65521;
  B:=(B+A) Mod 65521;
 End;
 Idat^[N]:=(B Shr 8) And 255; Idat^[N+1]:=B And 255;
 Idat^[N+2]:=(A Shr 8) And 255; Idat^[N+3]:=A And 255;
 Inc(N,4);
 Assign(F,Name);
 {$I-}Rewrite(F,1);{$I+}
 If IOResult<>0 Then Begin
  FreeMem(Raw,RawLen); FreeMem(Idat,IdLen); RasterEnd;
  Exit;
 End;
 Sig[0]:=137; Sig[1]:=80; Sig[2]:=78; Sig[3]:=71; Sig[4]:=13; Sig[5]:=10; Sig[6]:=26; Sig[7]:=10;
 BlockWrite(F,Sig,8);
 Ihdr[0]:=(RW Shr 24) And 255; Ihdr[1]:=(RW Shr 16) And 255; Ihdr[2]:=(RW Shr 8) And 255; Ihdr[3]:=RW And 255;
 Ihdr[4]:=(RH Shr 24) And 255; Ihdr[5]:=(RH Shr 16) And 255; Ihdr[6]:=(RH Shr 8) And 255; Ihdr[7]:=RH And 255;
 Ihdr[8]:=8; Ihdr[9]:=2; Ihdr[10]:=0; Ihdr[11]:=0; Ihdr[12]:=0;
 Chunk('IHDR',Ihdr,13);
 Chunk('IDAT',Idat^,N);
 Chunk('IEND',Z,0);
 {$I-}Close(F);{$I+}
 SavePNG:=IOResult=0;
 FreeMem(Raw,RawLen);
 FreeMem(Idat,IdLen);
 RasterEnd;
 X:=0;
End;

{ Exporte selon l'extension ; Mode : couleur (0 RVB, 1 CMJN, 6 separations) }
Function SaveVector(Const Name:String;Mode:Integer):Boolean;
Var E,B:String;
    I:Integer;
    Ok:Boolean;
    Pl:String;
Begin
 E:=ExtOf(Name);
 SaveVector:=False;
 If E='.DXF' Then Begin SaveVector:=SaveDXF(Name); Exit; End;
 If E='.WMF' Then Begin SaveVector:=SaveWMF(Name); Exit; End;
 If E='.BMP' Then Begin SaveVector:=SaveBMP(Name); Exit; End;
 If E='.PNG' Then Begin SaveVector:=SavePNG(Name); Exit; End;
 If Mode=6 Then Begin
  Ok:=True;
  B:=Copy(Name,1,Length(Name)-Length(E));
  For I:=2 To 5 Do Begin
   Pl:=Copy('CMJN',I-1,1);
   If E='.PDF' Then Ok:=Ok and SavePDF(B+'_'+Pl+E,I)
    Else Ok:=Ok and SaveEPS(B+'_'+Pl+E,I);
  End;
  SaveVector:=Ok;
  Exit;
 End;
 If E='.PDF' Then SaveVector:=SavePDF(Name,Mode)
  Else SaveVector:=SaveEPS(Name,Mode);
End;

{$ELSE}
Function SaveVector(Const Name:String;Mode:Integer):Boolean;
Begin
 SaveVector:=False;
End;
{$ENDIF}

{ Exporte sans les objets non imprimables ni ceux des autres pages }
Function SaveFiltered(Const Name:String;Svg:Boolean):Boolean;
Var P,Nx:PObj;
    Any:Boolean;
    Snap:PSnap;
Begin
 Any:=False;
 P:=ObjHead;
 While P<>NIL Do Begin
  If Not ObjPrintable(P)Then Any:=True;
  P:=P^.Next;
 End;
 Snap:=NIL;
 If Any Then Begin
  Snap:=TakeSnap(False);
  P:=ObjHead;
  While P<>NIL Do Begin
   Nx:=P^.Next;
   If Not ObjPrintable(P)Then DeleteObj(P);
   P:=Nx;
  End;
 End;
 If Svg Then SaveFiltered:=SaveSVG(Name) Else SaveFiltered:=SaveCDR9(Name);
 If Any Then RestoreSnap(Snap);
End;

Function SaveAny(Const Name:String):Boolean;
Var E:String;
Begin
 E:=ExtOf(Name);
 If E='.SVG' Then SaveAny:=SaveFiltered(Name,True)
  Else If E='.CD9' Then SaveAny:=SaveFiltered(Name,False)
  Else If(E='.PDF')or(E='.EPS')or(E='.PS')or(E='.DXF')or(E='.WMF')or(E='.BMP')or(E='.PNG')Then
   SaveAny:=SaveVector(Name,ExpMode)
  Else SaveAny:=SaveCDR(Name);
End;

{ ------------------------------------------------------------------ }
{ Lecture des fichiers CorelDRAW 5/6/7/8/9 (conteneur RIFF)         }
{                                                                    }
{ Structure observee dans les fichiers de CorelDRAW 9 :              }
{  RIFF "CDR8"/"CDR9"                                                }
{   vrsn, DISP (apercu DIB), LIST INFO                               }
{   LIST cmpr : en-tete (taille comprimee, taille decomprimee,       }
{     taille du bloc d'index, taille de l'index decomprime), puis    }
{     "CPng",1,4 + flux zlib des donnees, puis "CPng",1,4 + flux     }
{     zlib de la table des tailles de blocs (tableau de LongInt).    }
{   Les donnees decomprimees sont une suite de chunks RIFF dont le   }
{   champ "taille" est un INDEX dans la table des blocs.             }
{   doc : mcfg (dimensions de page), filt/fild (remplissages),       }
{         otlt/outl (contours), stlt (styles)                        }
{   page > gobj > layr > lgob > loda ; obj > lgob > loda + trfl/trfd }
{   loda : en-tete (taille, nb d'arguments, table des offsets, table }
{          des types, type d'objet) puis les arguments ; la liste de }
{          points est ( n:Word; 0:Word; (x,y:LongInt)*n; types:n )   }
{   Unites : 1/254000 de pouce, origine au centre, Y vers le haut.   }
{ CorelDRAW 5 ('CDR5', unite = 1/1000 pouce) : meme arbre de chunks,   }
{ mais en-tetes loda/trfd en 16 bits, points en entiers 16 bits,      }
{ enregistrements de texte de 8 octets (avance, FFFF, caractere, 9).  }
{ CorelDRAW 6 ('cdr6') : meme structure sans compression, tags 'fill'  }
{ (au lieu de 'fild'), dimensions de page en +28/+32 de 'mcfg'.       }
{ Seuls les objets vectoriels sont importes (le texte, les bitmaps   }
{ et les effets ne sont pas relus).                                  }
{ ------------------------------------------------------------------ }

{$IFNDEF FPC}
Function LoadCDR9(Const Name:String):Boolean;
Begin
 C9Info:='Lecture CorelDRAW 9 : Free Pascal requis';
 LoadCDR9:=False;
End;
{$ELSE}

Const
 HASH_N=8191;
 LBase:Array[0..28] of Integer=(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258);
 LExt:Array[0..28] of Integer=(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DBase:Array[0..29] of Integer=(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577);
 DExt:Array[0..29] of Integer=(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13);
 CLOrder:Array[0..18] of Integer=(16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);

Type
 TBig=Array[0..1999999999] of Byte;
 PBig=^TBig;
 TLongs=Array[0..16777215] of LongInt;
 PLongs=^TLongs;
 THuff=Record
  Cnt:Array[0..15] of LongInt;
  Sym:Array[0..287] of Integer;
 End;
 TLens=Array[0..319] of Integer;
 TFillRec=Record
  Id:LongInt;
  Kind:Byte;
  Special:Boolean;
  C1,C2:Integer;
  GX,GY:ShortInt;
  Bmp,TW,TH:LongInt;
 End;
 TOutlRec=Record
  Id:LongInt;
  W:LongInt;
  C:Integer;
 End;
 PFillTab=^TFillTab;
 TFillTab=Array[0..HASH_N-1] of TFillRec;
 POutlTab=^TOutlTab;
 TOutlTab=Array[0..HASH_N-1] of TOutlRec;

Var
 { Etat de l'inflateur }
 InfIn,InfOut:PBig;
 InfInLen,InfInPos,InfOutLen,InfOutPos,InfBuf:LongInt;
 InfCnt:Integer;
 InfBad:Boolean;
 FixedLit,FixedDist:THuff;
 FixedReady:Boolean;
 { Donnees du document }
 FileBuf,Dat:PBig;
 DatLen,BlkN:LongInt;
 Blk:PLongs;
 FillTab:PFillTab;
 OutlTab:POutlTab;
 SKeyF,SValF,SKeyO,SValO:Array[0..1023] of LongInt;
 SNF,SNO:Integer;
 StyOff,StyLen:LongInt;
 { Etat de l'analyse }
 CurGroup:Integer;
 PagesDone:Integer;
 CurPageSkip,SkipLayer,C9Full:Boolean;
 PendBody,PendSz:LongInt;
 PendValid,HaveTrf,OwnExport:Boolean;
 C9Ver:Integer;
 C9Old:Boolean;
 CoordK:Double;
 Trf:Array[0..5] of Double;
 SkipText,SkipBmp,SkipOther,SkipFx:Integer;
 { Sous-chemin en cours de construction }
 SubP:Array[0..7999] of TPt;
 SubN:Integer;
 SubAllLines,SubClosed:Boolean;
 { Courbe composee en cours : sous-chemins deja termines de l'objet }
 CompP:Array[0..7999] of TPt;
 CompN,CompCnt:Integer;
 CompLines,CompClosed:Boolean;
 PendC:Array[0..1] of TPt;
 PendCnt:Integer;
 tFillKind:Byte;
 tGX,tGY:ShortInt;
 tImg:Integer;
 tTW,tTH:LongInt;
 tF1,tF2,tOut:Integer;
 tW:LongInt;
 tGroup:Integer;

{ ---------------------------- Inflate ------------------------------ }

Function InfBits(Need:Integer):LongInt;
Var V:LongInt;
Begin
 V:=InfBuf;
 While InfCnt<Need Do Begin
  If InfInPos>=InfInLen Then Begin
   InfBad:=True;
   InfBits:=0;
   Exit;
  End;
  V:=V Or (LongInt(InfIn^[InfInPos]) Shl InfCnt);
  Inc(InfInPos);
  Inc(InfCnt,8);
 End;
 InfBuf:=V Shr Need;
 Dec(InfCnt,Need);
 InfBits:=V And ((LongInt(1) Shl Need)-1);
End;

Function InfBuild(Var H:THuff;Var L:TLens;Off,N:Integer):LongInt;
Var S,Len:Integer;
    Left:LongInt;
    Offs:Array[0..15] of Integer;
Begin
 For Len:=0 To 15 Do H.Cnt[Len]:=0;
 For S:=0 To N-1 Do Inc(H.Cnt[L[Off+S]]);
 If H.Cnt[0]=N Then Begin
  InfBuild:=0;
  Exit;
 End;
 Left:=1;
 For Len:=1 To 15 Do Begin
  Left:=Left Shl 1;
  Left:=Left-H.Cnt[Len];
  If Left<0 Then Begin
   InfBuild:=Left;
   Exit;
  End;
 End;
 Offs[1]:=0;
 For Len:=1 To 14 Do Offs[Len+1]:=Offs[Len]+H.Cnt[Len];
 For S:=0 To N-1 Do
  If L[Off+S]<>0 Then Begin
   H.Sym[Offs[L[Off+S]]]:=S;
   Inc(Offs[L[Off+S]]);
  End;
 InfBuild:=Left;
End;

Function InfDecode(Var H:THuff):Integer;
Var Code,First,Index,Count:LongInt;
    Len:Integer;
Begin
 Code:=0; First:=0; Index:=0;
 For Len:=1 To 15 Do Begin
  Code:=Code Or InfBits(1);
  If InfBad Then Break;
  Count:=H.Cnt[Len];
  If Code-Count<First Then Begin
   InfDecode:=H.Sym[Index+(Code-First)];
   Exit;
  End;
  Index:=Index+Count;
  First:=(First+Count) Shl 1;
  Code:=Code Shl 1;
 End;
 InfBad:=True;
 InfDecode:=-1;
End;

Procedure InfCodes(Var Lc,Dc:THuff);
Var Sym,Len,Dist:LongInt;
Begin
 Repeat
  Sym:=InfDecode(Lc);
  If InfBad Then Exit;
  If Sym<256 Then Begin
   If InfOutPos>=InfOutLen Then Begin InfBad:=True; Exit; End;
   InfOut^[InfOutPos]:=Sym;
   Inc(InfOutPos);
  End
   Else
  If Sym>256 Then Begin
   Sym:=Sym-257;
   If Sym>=29 Then Begin InfBad:=True; Exit; End;
   Len:=LBase[Sym]+InfBits(LExt[Sym]);
   Sym:=InfDecode(Dc);
   If InfBad or(Sym<0)or(Sym>=30)Then Begin InfBad:=True; Exit; End;
   Dist:=DBase[Sym]+InfBits(DExt[Sym]);
   If InfBad or(Dist>InfOutPos)or(InfOutPos+Len>InfOutLen)Then Begin InfBad:=True; Exit; End;
   While Len>0 Do Begin
    InfOut^[InfOutPos]:=InfOut^[InfOutPos-Dist];
    Inc(InfOutPos);
    Dec(Len);
   End;
  End;
 Until Sym=256;
End;

Procedure InfStored;
Var Len,Nlen:LongInt;
Begin
 InfBuf:=0;
 InfCnt:=0;
 If InfInPos+4>InfInLen Then Begin InfBad:=True; Exit; End;
 Len:=InfIn^[InfInPos]+256*InfIn^[InfInPos+1];
 Nlen:=InfIn^[InfInPos+2]+256*InfIn^[InfInPos+3];
 Inc(InfInPos,4);
 If(Len<>(Not Nlen)And $FFFF)or(InfInPos+Len>InfInLen)or(InfOutPos+Len>InfOutLen)Then Begin
  InfBad:=True;
  Exit;
 End;
 Move(InfIn^[InfInPos],InfOut^[InfOutPos],Len);
 Inc(InfInPos,Len);
 Inc(InfOutPos,Len);
End;

Procedure InfFixed;
Var L:TLens;
    S:Integer;
Begin
 If Not FixedReady Then Begin
  For S:=0 To 143 Do L[S]:=8;
  For S:=144 To 255 Do L[S]:=9;
  For S:=256 To 279 Do L[S]:=7;
  For S:=280 To 287 Do L[S]:=8;
  InfBuild(FixedLit,L,0,288);
  For S:=0 To 29 Do L[S]:=5;
  InfBuild(FixedDist,L,0,30);
  FixedReady:=True;
 End;
 InfCodes(FixedLit,FixedDist);
End;

Procedure InfDynamic;
Var Nlen,Ndist,Ncode,Idx,Sym,Rep,Prev,I:Integer;
    L:TLens;
    Lc,Dc:THuff;
    Err:LongInt;
Begin
 Nlen:=InfBits(5)+257;
 Ndist:=InfBits(5)+1;
 Ncode:=InfBits(4)+4;
 If InfBad or(Nlen>286)or(Ndist>30)Then Begin InfBad:=True; Exit; End;
 FillChar(L,SizeOf(L),0);
 For Idx:=0 To Ncode-1 Do L[CLOrder[Idx]]:=InfBits(3);
 Err:=InfBuild(Lc,L,0,19);
 If InfBad or(Err<>0)Then Begin InfBad:=True; Exit; End;
 Idx:=0;
 FillChar(L,SizeOf(L),0);
 While Idx<Nlen+Ndist Do Begin
  Sym:=InfDecode(Lc);
  If InfBad Then Exit;
  If Sym<16 Then Begin
   L[Idx]:=Sym;
   Inc(Idx);
  End
   Else Begin
    Prev:=0;
    If Sym=16 Then Begin
     If Idx=0 Then Begin InfBad:=True; Exit; End;
     Prev:=L[Idx-1];
     Rep:=3+InfBits(2);
    End
     Else
    If Sym=17 Then Rep:=3+InfBits(3)
     Else Rep:=11+InfBits(7);
    If Idx+Rep>Nlen+Ndist Then Begin InfBad:=True; Exit; End;
    For I:=1 To Rep Do Begin
     L[Idx]:=Prev;
     Inc(Idx);
    End;
   End;
 End;
 Err:=InfBuild(Lc,L,0,Nlen);
 If(Err<0)or((Err>0)and(Nlen-Lc.Cnt[0]<>1))Then Begin InfBad:=True; Exit; End;
 Err:=InfBuild(Dc,L,Nlen,Ndist);
 If(Err<0)or((Err>0)and(Ndist-Dc.Cnt[0]<>1))Then Begin InfBad:=True; Exit; End;
 InfCodes(Lc,Dc);
End;

{ Decompresse un flux zlib (2 octets d'en-tete + deflate) }
Function Inflate(Src:PBig;SrcLen:LongInt;Dst:PBig;DstLen:LongInt):Boolean;
Var Last,Typ:LongInt;
Begin
 InfIn:=Src;
 InfInLen:=SrcLen;
 InfInPos:=2;
 InfOut:=Dst;
 InfOutLen:=DstLen;
 InfOutPos:=0;
 InfBuf:=0;
 InfCnt:=0;
 InfBad:=False;
 If SrcLen<3 Then Begin
  Inflate:=False;
  Exit;
 End;
 Repeat
  Last:=InfBits(1);
  Typ:=InfBits(2);
  If InfBad Then Break;
  Case Typ Of
   0:InfStored;
   1:InfFixed;
   2:InfDynamic;
  Else InfBad:=True;
  End;
 Until(Last=1)or InfBad;
 Inflate:=Not InfBad;
End;

{ ------------------------------------------------------------------ }
{ Importations : DXF, EPS/PS, PDF, WMF, BMP, PCX, PNG                  }
{ ------------------------------------------------------------------ }

Var
 IBuf:PBig;
 ILen:LongInt;
 INew:LongInt;     { premier rang des objets importes }
 INewDoc:Boolean;

Function ReadWhole(Const Name:String):Boolean;
Var F:File;
    Old:Byte;
Begin
 ReadWhole:=False;
 IBuf:=NIL;
 ILen:=0;
 Old:=FileMode;
 FileMode:=0;
 Assign(F,Name);
 {$I-}Reset(F,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Exit;
 ILen:=FileSize(F);
 If(ILen<4)or(ILen>80000000)Then Begin
  Close(F);
  Exit;
 End;
 GetMem(IBuf,ILen+8);
 FillChar(IBuf^,ILen+8,0);
 BlockRead(F,IBuf^,ILen);
 Close(F);
 ReadWhole:=True;
End;

Procedure FreeWhole;
Begin
 If IBuf<>NIL Then FreeMem(IBuf,ILen+8);
 IBuf:=NIL;
End;

Function IB(O:LongInt):LongInt;
Begin
 If(O<0)or(O>=ILen)Then IB:=0 Else IB:=IBuf^[O];
End;

Function IW(O:LongInt):LongInt;
Begin
 IW:=IB(O)+IB(O+1)*256;
End;

Function IWs(O:LongInt):LongInt;
Var V:LongInt;
Begin
 V:=IW(O);
 If V>=32768 Then V:=V-65536;
 IWs:=V;
End;

Function IL(O:LongInt):LongInt;
Begin
 IL:=IW(O)+(IW(O+2) Shl 16);
End;

{ Echelle et recentrage des objets importes depuis le rang INew : aucune
  mise a l'echelle si Fit est faux, sinon reduction pour tenir dans la page }
Procedure NormalizeNew(Sc:Double;Fit:Boolean);
Var I:LongInt;
    O:PObj;
    X1,Y1,X2,Y2,A,B,C,D:LongInt;
    First:Boolean;
    F,W,H:Double;
    K:Integer;
Begin
 If ObjCount<=INew Then Exit;
 First:=True;
 X1:=0; Y1:=0; X2:=0; Y2:=0;
 For I:=INew To ObjCount-1 Do Begin
  O:=ObjAt(I);
  ObjBBox(O,A,B,C,D);
  If First Then Begin X1:=A; Y1:=B; X2:=C; Y2:=D; First:=False; End
   Else Begin
    If A<X1 Then X1:=A;
    If B<Y1 Then Y1:=B;
    If C>X2 Then X2:=C;
    If D>Y2 Then Y2:=D;
   End;
 End;
 F:=Sc;
 If Fit Then Begin
  W:=(X2-X1)*F;
  If W>PageW-400 Then F:=F*(PageW-400)/W;
  H:=(Y2-Y1)*F;
  If H>PageH-400 Then F:=F*(PageH-400)/H;
 End;
 For I:=INew To ObjCount-1 Do Begin
  O:=ObjAt(I);
  For K:=0 To O^.N-1 Do
   If O^.Pts^[K].X<>BRK Then Begin
    O^.Pts^[K].X:=Round((O^.Pts^[K].X-X1)*F)+200;
    O^.Pts^[K].Y:=Round((O^.Pts^[K].Y-Y1)*F)+200;
   End;
  If O^.Kind=K_TEXT Then O^.TextSize:=Clamp(Round(O^.TextSize*F),20,2000);
  If(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)Then ObjNormalize2(O);
 End;
 { dessin plus grand que la page d'un nouveau document : on agrandit la page }
 If INewDoc and Not Fit Then Begin
  For I:=INew To ObjCount-1 Do Begin
   ObjBBox(ObjAt(I),A,B,C,D);
   If C+200>PageW Then PageW:=Min(C+200,9000);
   If D+200>PageH Then PageH:=Min(D+200,9000);
  End;
 End;
End;

Function ImpColor(R,G,B:LongInt):Integer;
Begin
 ImpColor:=AddPalColor(Clamp(R,0,255),Clamp(G,0,255),Clamp(B,0,255));
End;

{ ------------------------- images ----------------------------------- }

{ Ajoute un bitmap de W x H points (RVB, ligne du haut en premier) }
Function AddImageBuf(W,H:LongInt;Pix,Alp:PBig):Boolean;
Var DW,DH,X,Y,SX,SY,K,N:LongInt;
    I:Integer;
    O:PObj;
    WU,HU:LongInt;
    F:Double;
Begin
 AddImageBuf:=False;
 DW:=W; DH:=H;
 If(DW>IMG_SIDE)or(DH>IMG_SIDE)Then Begin
  If DW>=DH Then Begin DH:=(DH*IMG_SIDE) Div DW; DW:=IMG_SIDE; End
   Else Begin DW:=(DW*IMG_SIDE) Div DH; DH:=IMG_SIDE; End;
 End;
 If DW<1 Then DW:=1;
 If DH<1 Then DH:=1;
 ImgPalSetup;
 I:=ImgNew(DW,DH,Alp<>NIL);
 If I=0 Then Exit;
 For Y:=0 To DH-1 Do Begin
  SY:=(Y*H) Div DH;
  For X:=0 To DW-1 Do Begin
   SX:=(X*W) Div DW;
   K:=SY*W+SX;
   N:=Y*DW+X;
   Imgs[I]^.Pix^[N*3]:=Pix^[K*3];
   Imgs[I]^.Pix^[N*3+1]:=Pix^[K*3+1];
   Imgs[I]^.Pix^[N*3+2]:=Pix^[K*3+2];
   If Alp<>NIL Then Imgs[I]^.A^[N]:=Alp^[K];
  End;
 End;
 ImgAverage(I);
 WU:=(W*254) Div 96;
 HU:=(H*254) Div 96;
 F:=1;
 If WU>PageW-400 Then F:=(PageW-400)/WU;
 If HU*F>PageH-400 Then F:=(PageH-400)/HU;
 WU:=Round(WU*F); HU:=Round(HU*F);
 If WU<10 Then WU:=10;
 If HU<10 Then HU:=10;
 O:=NewObj(K_BITMAP,2);
 O^.Closed:=True;
 O^.Pts^[0].X:=200; O^.Pts^[0].Y:=200;
 O^.Pts^[1].X:=200+WU; O^.Pts^[1].Y:=200+HU;
 O^.Img:=I;
 O^.FillKind:=FK_SOLID;
 O^.FillCol:=NearestColor(Imgs[I]^.AR,Imgs[I]^.AG,Imgs[I]^.AB);
 O^.OutCol:=-1;
 O^.OutW:=1;
 AddObj(O);
 AddImageBuf:=True;
End;

Function LoadBMPFile:Boolean;
Var Off,Hs,W,H,Bpp,Comp,NC,Pal,RB,X,Y,Row,P,V,Idx:LongInt;
    Pix:PBig;
    Top:Boolean;
Begin
 LoadBMPFile:=False;
 If(IB(0)<>Ord('B'))or(IB(1)<>Ord('M'))Then Exit;
 Off:=IL(10);
 Hs:=IL(14);
 If Hs<40 Then Exit;
 W:=IL(18);
 H:=IL(22);
 Top:=H<0;
 If Top Then H:=-H;
 Bpp:=IW(28);
 Comp:=IL(30);
 NC:=IL(46);
 If(W<1)or(H<1)or(W>20000)or(H>20000)Then Exit;
 If(Comp<>0)and Not((Comp=3)and((Bpp=32)or(Bpp=16)))Then Exit;
 If Not(Bpp in [1,4,8,24,32])Then Exit;
 Pal:=14+Hs;
 If(Bpp<=8)and(NC=0)Then NC:=1 Shl Bpp;
 RB:=((W*Bpp+31) Div 32)*4;
 If Off+RB*H>ILen+3 Then Exit;
 GetMem(Pix,W*H*3);
 For Y:=0 To H-1 Do Begin
  If Top Then Row:=Y Else Row:=H-1-Y;
  P:=Off+Row*RB;
  For X:=0 To W-1 Do Begin
   Case Bpp Of
    24:Begin
     Pix^[(Y*W+X)*3]:=IB(P+X*3+2);
     Pix^[(Y*W+X)*3+1]:=IB(P+X*3+1);
     Pix^[(Y*W+X)*3+2]:=IB(P+X*3);
    End;
    32:Begin
     Pix^[(Y*W+X)*3]:=IB(P+X*4+2);
     Pix^[(Y*W+X)*3+1]:=IB(P+X*4+1);
     Pix^[(Y*W+X)*3+2]:=IB(P+X*4);
    End;
   Else Begin
    Case Bpp Of
     8:Idx:=IB(P+X);
     4:Begin V:=IB(P+X Div 2); If Odd(X)Then Idx:=V And 15 Else Idx:=V Shr 4; End;
    Else Begin V:=IB(P+X Div 8); Idx:=(V Shr (7-(X And 7))) And 1; End;
    End;
    Pix^[(Y*W+X)*3]:=IB(Pal+Idx*4+2);
    Pix^[(Y*W+X)*3+1]:=IB(Pal+Idx*4+1);
    Pix^[(Y*W+X)*3+2]:=IB(Pal+Idx*4);
   End;
   End;
  End;
 End;
 LoadBMPFile:=AddImageBuf(W,H,Pix,NIL);
 FreeMem(Pix,W*H*3);
End;

Function LoadPCXFile:Boolean;
Var W,H,Planes,Bpl,Bpp,X,Y,P,N,C,K,L:LongInt;
    Pix,Ln:PBig;
    PalAt:LongInt;
Begin
 LoadPCXFile:=False;
 If(IB(0)<>10)or(IB(2)<>1)Then Exit;
 Bpp:=IB(3);
 W:=IW(8)-IW(4)+1;
 H:=IW(10)-IW(6)+1;
 Planes:=IB(65);
 Bpl:=IW(66);
 If(W<1)or(H<1)or(W>20000)or(H>20000)Then Exit;
 If Not(((Bpp=8)and((Planes=1)or(Planes=3)))or((Bpp=1)and(Planes=1)))Then Exit;
 GetMem(Pix,W*H*3);
 GetMem(Ln,Bpl*Planes+260);
 P:=128;
 PalAt:=ILen-769;
 For Y:=0 To H-1 Do Begin
  N:=0;
  While N<Bpl*Planes Do Begin
   C:=IB(P);
   Inc(P);
   If(C And $C0)=$C0 Then Begin
    K:=C And $3F;
    C:=IB(P);
    Inc(P);
   End
    Else K:=1;
   While(K>0)and(N<Bpl*Planes+250)Do Begin
    Ln^[N]:=C;
    Inc(N);
    Dec(K);
   End;
   If P>ILen Then Break;
  End;
  For X:=0 To W-1 Do Begin
   If Planes=3 Then Begin
    Pix^[(Y*W+X)*3]:=Ln^[X];
    Pix^[(Y*W+X)*3+1]:=Ln^[Bpl+X];
    Pix^[(Y*W+X)*3+2]:=Ln^[2*Bpl+X];
   End
    Else If Bpp=8 Then Begin
     If IB(PalAt)=12 Then L:=PalAt+1+Ln^[X]*3 Else L:=-1;
     If L>=0 Then Begin
      Pix^[(Y*W+X)*3]:=IB(L); Pix^[(Y*W+X)*3+1]:=IB(L+1); Pix^[(Y*W+X)*3+2]:=IB(L+2);
     End
      Else Begin
       Pix^[(Y*W+X)*3]:=Ln^[X]; Pix^[(Y*W+X)*3+1]:=Ln^[X]; Pix^[(Y*W+X)*3+2]:=Ln^[X];
      End;
    End
     Else Begin
      If((Ln^[X Div 8] Shr (7-(X And 7))) And 1)=0 Then L:=0 Else L:=255;
      Pix^[(Y*W+X)*3]:=L; Pix^[(Y*W+X)*3+1]:=L; Pix^[(Y*W+X)*3+2]:=L;
     End;
  End;
 End;
 LoadPCXFile:=AddImageBuf(W,H,Pix,NIL);
 FreeMem(Pix,W*H*3);
 FreeMem(Ln,Bpl*Planes+260);
End;

Function LoadPNGFile:Boolean;
Var Pos,Len,W,H,Depth,CT,Chans,Bpp,RB,Cnt,Y,X,I,K,Cap,A,B,C,Pa,PB,PC,Pp:LongInt;
    Tag:String;
    Comp,Raw,Pix,Alp:PBig;
    Pl:Array[0..767] of Byte;
    Tr:Array[0..255] of Byte;
    NPl,NTr:LongInt;
    HasA:Boolean;
    V:LongInt;
    Ok:Boolean;
    PrevRow:LongInt;
 Function Sample(Row,Col,Ch:LongInt):LongInt;
 Var O,Bits:LongInt;
 Begin
  If Depth=8 Then Sample:=Raw^[Row*(RB+1)+1+Col*Chans+Ch]
  Else If Depth=16 Then Sample:=Raw^[Row*(RB+1)+1+(Col*Chans+Ch)*2]
  Else Begin
   Bits:=Col*Depth;
   O:=Raw^[Row*(RB+1)+1+(Bits Shr 3)];
   Sample:=(O Shr (8-Depth-(Bits And 7))) And ((1 Shl Depth)-1);
  End;
 End;
Begin
 LoadPNGFile:=False;
 If(IB(0)<>137)or(IB(1)<>80)or(IB(2)<>78)or(IB(3)<>71)Then Exit;
 Pos:=8;
 W:=0; H:=0; NPl:=0; NTr:=0; Cnt:=0;
 GetMem(Comp,ILen+8);
 FillChar(Tr,SizeOf(Tr),255);
 While Pos+8<=ILen Do Begin
  Len:=(IB(Pos) Shl 24)+(IB(Pos+1) Shl 16)+(IB(Pos+2) Shl 8)+IB(Pos+3);
  Tag:=Chr(IB(Pos+4))+Chr(IB(Pos+5))+Chr(IB(Pos+6))+Chr(IB(Pos+7));
  If(Len<0)or(Pos+12+Len>ILen+4)Then Break;
  If Tag='IHDR' Then Begin
   W:=(IB(Pos+8) Shl 24)+(IB(Pos+9) Shl 16)+(IB(Pos+10) Shl 8)+IB(Pos+11);
   H:=(IB(Pos+12) Shl 24)+(IB(Pos+13) Shl 16)+(IB(Pos+14) Shl 8)+IB(Pos+15);
   Depth:=IB(Pos+16);
   CT:=IB(Pos+17);
   If IB(Pos+20)<>0 Then Begin FreeMem(Comp,ILen+8); Exit; End;
  End
   Else If Tag='PLTE' Then Begin
    NPl:=Len Div 3;
    If NPl>256 Then NPl:=256;
    For I:=0 To NPl*3-1 Do Pl[I]:=IB(Pos+8+I);
   End
   Else If Tag='tRNS' Then Begin
    NTr:=Len;
    If NTr>256 Then NTr:=256;
    For I:=0 To NTr-1 Do Tr[I]:=IB(Pos+8+I);
   End
   Else If Tag='IDAT' Then Begin
    Move(IBuf^[Pos+8],Comp^[Cnt],Len);
    Inc(Cnt,Len);
   End
   Else If Tag='IEND' Then Break;
  Pos:=Pos+12+Len;
 End;
 If(W<1)or(H<1)or(W>20000)or(H>20000)or(Cnt<8)Then Begin FreeMem(Comp,ILen+8); Exit; End;
 Case CT Of
  0:Chans:=1;
  2:Chans:=3;
  3:Chans:=1;
  4:Chans:=2;
  6:Chans:=4;
 Else Begin FreeMem(Comp,ILen+8); Exit; End;
 End;
 If Not(Depth in [1,2,4,8,16])Then Begin FreeMem(Comp,ILen+8); Exit; End;
 RB:=(W*Chans*Depth+7) Div 8;
 Bpp:=(Chans*Depth+7) Div 8;
 Cap:=H*(RB+1);
 GetMem(Raw,Cap+8);
 Ok:=Inflate(Comp,Cnt,Raw,Cap);
 FreeMem(Comp,ILen+8);
 If(Not Ok)and(InfOutPos<Cap)Then Begin FreeMem(Raw,Cap+8); Exit; End;
 { filtres }
 For Y:=0 To H-1 Do Begin
  K:=Raw^[Y*(RB+1)];
  For X:=0 To RB-1 Do Begin
   I:=Y*(RB+1)+1+X;
   If X>=Bpp Then A:=Raw^[I-Bpp] Else A:=0;
   If Y>0 Then B:=Raw^[I-(RB+1)] Else B:=0;
   If(Y>0)and(X>=Bpp)Then C:=Raw^[I-(RB+1)-Bpp] Else C:=0;
   Case K Of
    1:Raw^[I]:=(Raw^[I]+A) And 255;
    2:Raw^[I]:=(Raw^[I]+B) And 255;
    3:Raw^[I]:=(Raw^[I]+((A+B) Shr 1)) And 255;
    4:Begin
     Pp:=A+B-C;
     Pa:=Abs(Pp-A); PB:=Abs(Pp-B); PC:=Abs(Pp-C);
     If(Pa<=PB)and(Pa<=PC)Then V:=A Else If PB<=PC Then V:=B Else V:=C;
     Raw^[I]:=(Raw^[I]+V) And 255;
    End;
   End;
  End;
 End;
 HasA:=(CT=4)or(CT=6)or((CT=3)and(NTr>0));
 GetMem(Pix,W*H*3);
 Alp:=NIL;
 If HasA Then GetMem(Alp,W*H);
 For Y:=0 To H-1 Do
  For X:=0 To W-1 Do Begin
   I:=(Y*W+X)*3;
   Case CT Of
    0:Begin
     V:=Sample(Y,X,0);
     If Depth<8 Then V:=V*255 Div ((1 Shl Depth)-1);
     Pix^[I]:=V; Pix^[I+1]:=V; Pix^[I+2]:=V;
    End;
    2,6:Begin
     Pix^[I]:=Sample(Y,X,0); Pix^[I+1]:=Sample(Y,X,1); Pix^[I+2]:=Sample(Y,X,2);
     If CT=6 Then Alp^[Y*W+X]:=Sample(Y,X,3);
    End;
    3:Begin
     V:=Sample(Y,X,0);
     If V>=NPl Then V:=0;
     Pix^[I]:=Pl[V*3]; Pix^[I+1]:=Pl[V*3+1]; Pix^[I+2]:=Pl[V*3+2];
     If HasA Then Alp^[Y*W+X]:=Tr[V];
    End;
   Else Begin
    V:=Sample(Y,X,0);
    If Depth<8 Then V:=V*255 Div ((1 Shl Depth)-1);
    Pix^[I]:=V; Pix^[I+1]:=V; Pix^[I+2]:=V;
    Alp^[Y*W+X]:=Sample(Y,X,1);
   End;
   End;
  End;
 FreeMem(Raw,Cap+8);
 LoadPNGFile:=AddImageBuf(W,H,Pix,Alp);
 FreeMem(Pix,W*H*3);
 If Alp<>NIL Then FreeMem(Alp,W*H);
 PrevRow:=0;
End;

{ ------------------------------ DXF --------------------------------- }

Function AciToPal(C:Integer):Integer;
Begin
 Case C Of
  1:AciToPal:=ImpColor(255,0,0);
  2:AciToPal:=ImpColor(255,255,0);
  3:AciToPal:=ImpColor(0,255,0);
  4:AciToPal:=ImpColor(0,255,255);
  5:AciToPal:=ImpColor(0,0,255);
  6:AciToPal:=ImpColor(255,0,255);
  8:AciToPal:=ImpColor(128,128,128);
  9:AciToPal:=ImpColor(192,192,192);
 Else AciToPal:=0;
 End;
End;

Function Raw1000(V:Double):LongInt;
Begin
 If V>1000000 Then V:=1000000;
 If V<-1000000 Then V:=-1000000;
 Raw1000:=Round(V*1000);
End;

Function LoadDXFFile(Const Name:String):Boolean;
Const MV=3000;
Var T:Text;
    L1,L2:String;
    Code,Cd,I:Integer;
    Sec,Cur,Lay,Txt:String;
    InEnt,InPoly:Boolean;
    VX,VY:Array[0..MV-1] of Double;
    PVX,PVY:Array[0..MV-1] of Double;
    VN,PVN,PFlags,Flags,Col,PCol:Integer;
    X2,Y2,Rad,A1,A2,Hgt,Ratio,V:Double;
    LN:Integer;
    LyN:Array[1..LAYER_N] of String[16];
 Function LayerIdx(Const S:String):Integer;
 Var K:Integer;
 Begin
  For K:=1 To LN Do If LyN[K]=S Then Begin LayerIdx:=K; Exit; End;
  If LN<LAYER_N Then Begin
   Inc(LN);
   LyN[LN]:=Copy(S,1,16);
   LayerName[LN]:=LyN[LN];
   LayerIdx:=LN;
  End
   Else LayerIdx:=LAYER_N;
 End;
 Procedure Fin(O:PObj;C:Integer;Closed:Boolean);
 Begin
  O^.OutCol:=AciToPal(C);
  O^.OutW:=3;
  O^.FillKind:=FK_NONE;
  O^.FillCol:=-1;
  O^.Closed:=Closed;
  O^.Layer:=LayerIdx(Lay);
  AddObj(O);
 End;
 Procedure Poly(Const XS,YS:Array of Double;N:Integer;Closed:Boolean;C:Integer);
 Var O:PObj;
     K:Integer;
 Begin
  If N<2 Then Exit;
  If Closed and(N>=3)Then O:=NewObj(K_POLY,N)
   Else If N=2 Then O:=NewObj(K_LINE,2)
   Else O:=NewObj(K_POLYLINE,N);
  For K:=0 To N-1 Do Begin
   O^.Pts^[K].X:=Raw1000(XS[K]);
   O^.Pts^[K].Y:=Raw1000(-YS[K]);
  End;
  Fin(O,C,O^.Kind=K_POLY);
 End;
 Procedure Flush;
 Var O:PObj;
     K,M:Integer;
     CX,CY,Ang,Sw,E:Double;
     AX,AY:Array[0..199] of Double;
 Begin
  If Cur='VERTEX' Then Begin
   If(PVN<MV)and InPoly and(VN>0)Then Begin
    PVX[PVN]:=VX[0]; PVY[PVN]:=VY[0];
    Inc(PVN);
   End;
   Exit;
  End;
  If Cur='SEQEND' Then Begin
   If InPoly Then Poly(PVX,PVY,PVN,(PFlags And 1)<>0,PCol);
   InPoly:=False;
   Exit;
  End;
  If Cur='POLYLINE' Then Begin
   InPoly:=True; PVN:=0; PFlags:=Flags; PCol:=Col;
   Exit;
  End;
  If Not InEnt Then Exit;
  If Cur='LINE' Then Begin
   If VN>=1 Then Begin
    VX[1]:=X2; VY[1]:=Y2;
    Poly(VX,VY,2,False,Col);
   End;
  End
   Else If Cur='LWPOLYLINE' Then Poly(VX,VY,VN,(Flags And 1)<>0,Col)
   Else If(Cur='CIRCLE')and(VN>=1)Then Begin
    O:=NewObj(K_ELLIPSE,2);
    O^.Pts^[0].X:=Raw1000(VX[0]-Rad); O^.Pts^[0].Y:=Raw1000(-VY[0]-Rad);
    O^.Pts^[1].X:=Raw1000(VX[0]+Rad); O^.Pts^[1].Y:=Raw1000(-VY[0]+Rad);
    Fin(O,Col,True);
   End
   Else If(Cur='ARC')and(VN>=1)Then Begin
    If A2<=A1 Then A2:=A2+360;
    M:=Trunc((A2-A1)/6)+2;
    If M>199 Then M:=199;
    For K:=0 To M-1 Do Begin
     Ang:=(A1+(A2-A1)*K/(M-1))*Pi/180;
     AX[K]:=VX[0]+Rad*Cos(Ang);
     AY[K]:=VY[0]+Rad*Sin(Ang);
    End;
    Poly(AX,AY,M,False,Col);
   End
   Else If(Cur='ELLIPSE')and(VN>=1)Then Begin
    For K:=0 To 47 Do Begin
     Ang:=K*2*Pi/48;
     AX[K]:=VX[0]+X2*Cos(Ang)-Ratio*Y2*Sin(Ang);
     AY[K]:=VY[0]+Y2*Cos(Ang)+Ratio*X2*Sin(Ang);
    End;
    Poly(AX,AY,48,True,Col);
   End
   Else If((Cur='TEXT')or(Cur='MTEXT'))and(VN>=1)and(Txt<>'')Then Begin
    O:=NewObj(K_TEXT,1);
    If Hgt<=0 Then Hgt:=2.5;
    O^.Pts^[0].X:=Raw1000(VX[0]);
    O^.Pts^[0].Y:=Raw1000(-VY[0]-Hgt);
    O^.TextSize:=Raw1000(Hgt);
    O^.Txt:=Copy(Txt,1,60);
    O^.FillCol:=AciToPal(Col);
    O^.FillKind:=FK_SOLID;
    O^.OutCol:=-1;
    O^.Layer:=LayerIdx(Lay);
    AddObj(O);
   End;
  E:=0; Sw:=0; CX:=0; CY:=0;
 End;
Begin
 LoadDXFFile:=False;
 Assign(T,Name);
 {$I-}Reset(T);{$I+}
 If IOResult<>0 Then Exit;
 LN:=0;
 Sec:=''; Cur:=''; InEnt:=False; InPoly:=False;
 VN:=0; PVN:=0; Lay:='0'; Txt:=''; Col:=256; Flags:=0; PFlags:=0; PCol:=256;
 X2:=0; Y2:=0; Rad:=0; A1:=0; A2:=0; Hgt:=0; Ratio:=1;
 INew:=ObjCount;
 While Not Eof(T) Do Begin
  ReadLn(T,L1);
  If Eof(T)Then Break;
  ReadLn(T,L2);
  While(L1<>'')and(L1[1]=' ')Do Delete(L1,1,1);
  While(L2<>'')and(L2[Length(L2)] in [' ',#13])Do Delete(L2,Length(L2),1);
  Val(L1,Code,Cd);
  If Cd<>0 Then Continue;
  Case Code Of
   0:Begin
    Flush;
    Cur:=UpStr(L2);
    If Cur='ENDSEC' Then InEnt:=False;
    VN:=0; X2:=0; Y2:=0; Rad:=0; A1:=0; A2:=0; Hgt:=0; Ratio:=1; Txt:=''; Flags:=0;
    Col:=256; Lay:='0';
   End;
   1:Txt:=L2;
   2:If Cur='SECTION' Then Begin
      Sec:=UpStr(L2);
      InEnt:=Sec='ENTITIES';
     End;
   8:Lay:=L2;
   62:Begin Val(L2,I,Cd); If Cd=0 Then Col:=I; End;
   70:Begin Val(L2,I,Cd); If Cd=0 Then Flags:=I; End;
   10:If VN<MV Then Begin
       Val(L2,V,Cd);
       VX[VN]:=V; VY[VN]:=0;
       Inc(VN);
      End;
   20:If VN>0 Then Begin Val(L2,V,Cd); VY[VN-1]:=V; End;
   11:Begin Val(L2,V,Cd); X2:=V; End;
   21:Begin Val(L2,V,Cd); Y2:=V; End;
   40:Begin
       Val(L2,V,Cd);
       If Cur='ELLIPSE' Then Ratio:=V Else Begin Rad:=V; Hgt:=V; End;
      End;
   50:Begin Val(L2,V,Cd); A1:=V; End;
   51:Begin Val(L2,V,Cd); A2:=V; End;
  End;
 End;
 Flush;
 Close(T);
 If ObjCount<=INew Then Exit;
 { les unites sont supposees en mm : 1000 points internes = 1 mm = 10 }
 NormalizeNew(0.01,True);
 LoadDXFFile:=True;
End;

{ ------------------------ PostScript / PDF -------------------------- }

Var
 TP,TEnd:LongInt;
 TBuf:PBig;
 DbgTrace:Boolean;
 DbgF:Text;
 SNum:Array[0..63] of Double;
 SN:Integer;
 SStr,TJAcc:String;
 InArr:Boolean;
 CA,CB,CC,CD,CE,CF:Double;
 GStack:Array[0..31] of Record
  A,B,C,D,E,F,LW,FS:Double;
  FC,SC:Integer;
 End;
 GSP:Integer;
 FillC,StrC:Integer;
 LWd,FontSz,Leading:Double;
 TMa,TMb,TMc,TMd,TMe,TMf,TLa,TLb,TLc,TLd,TLe,TLf:Double;
 PPts:Array[0..7999] of TPt;
 PPN:Integer;
 PSub:Array[0..63] of Integer;
 PCl:Array[0..63] of Boolean;
 PSubN:Integer;
 CurX,CurY,StX,StY:Double;
 OffX,TopY:Double;
 IsPdf:Boolean;
 PSMade:LongInt;

Function NextTok(Var Tok:String):Integer;
Var C:Integer;
    D,N:LongInt;
    V:Double;
    Cd:Integer;
    H:Integer;
 Function Delim(Ch:Integer):Boolean;
 Begin
  Delim:=(Ch<=32)or(Ch=Ord('('))or(Ch=Ord(')'))or(Ch=Ord('<'))or(Ch=Ord('>'))or
         (Ch=Ord('['))or(Ch=Ord(']'))or(Ch=Ord('{'))or(Ch=Ord('}'))or(Ch=Ord('/'))or(Ch=Ord('%'));
 End;
 Function HexV(Ch:Integer):Integer;
 Begin
  If(Ch>=48)and(Ch<=57)Then HexV:=Ch-48
   Else If(Ch>=65)and(Ch<=70)Then HexV:=Ch-55
   Else If(Ch>=97)and(Ch<=102)Then HexV:=Ch-87
   Else HexV:=-1;
 End;
Begin
 Tok:='';
 NextTok:=0;
 While TP<TEnd Do Begin
  C:=TBuf^[TP];
  If C<=32 Then Begin Inc(TP); Continue; End;
  If C=Ord('%')Then Begin
   While(TP<TEnd)and(TBuf^[TP]<>10)and(TBuf^[TP]<>13)Do Inc(TP);
   Continue;
  End;
  If C=Ord('(')Then Begin
   Inc(TP);
   D:=1;
   While(TP<TEnd)and(D>0)Do Begin
    C:=TBuf^[TP];
    Inc(TP);
    If C=Ord('\')Then Begin
     C:=TBuf^[TP];
     Inc(TP);
     If C=Ord('n')Then C:=10
      Else If C=Ord('r')Then C:=13
      Else If C=Ord('t')Then C:=9
      Else If(C>=48)and(C<=55)Then Begin
       N:=C-48;
       H:=0;
       While(H<2)and(TBuf^[TP]>=48)and(TBuf^[TP]<=55)Do Begin
        N:=N*8+TBuf^[TP]-48; Inc(TP); Inc(H);
       End;
       C:=N And 255;
      End;
     If Length(Tok)<255 Then Tok:=Tok+Chr(C);
    End
     Else Begin
      If C=Ord('(')Then Inc(D);
      If C=Ord(')')Then Dec(D);
      If(D>0)and(Length(Tok)<255)Then Tok:=Tok+Chr(C);
     End;
   End;
   NextTok:=3;
   Exit;
  End;
  If C=Ord('<')Then Begin
   If TBuf^[TP+1]=Ord('<')Then Begin
    { dictionnaire : ignore son contenu }
    D:=0;
    While TP<TEnd Do Begin
     If(TBuf^[TP]=Ord('<'))and(TBuf^[TP+1]=Ord('<'))Then Begin Inc(D); Inc(TP,2); End
      Else If(TBuf^[TP]=Ord('>'))and(TBuf^[TP+1]=Ord('>'))Then Begin Dec(D); Inc(TP,2); If D<=0 Then Break; End
      Else Inc(TP);
    End;
    Continue;
   End;
   Inc(TP);
   H:=-1;
   While(TP<TEnd)and(TBuf^[TP]<>Ord('>'))Do Begin
    N:=HexV(TBuf^[TP]);
    If N>=0 Then Begin
     If H<0 Then H:=N Else Begin
      If Length(Tok)<255 Then Tok:=Tok+Chr(H*16+N);
      H:=-1;
     End;
    End;
    Inc(TP);
   End;
   Inc(TP);
   NextTok:=3;
   Exit;
  End;
  If(C=Ord('['))or(C=Ord(']'))Then Begin
   Tok:=Chr(C);
   Inc(TP);
   NextTok:=4;
   Exit;
  End;
  If(C=Ord('{'))or(C=Ord('}'))or(C=Ord(')'))or(C=Ord('>'))Then Begin
   Inc(TP);
   Continue;
  End;
  If C=Ord('/')Then Begin
   Inc(TP);
   While(TP<TEnd)and Not Delim(TBuf^[TP])Do Inc(TP);
   NextTok:=6;
   Exit;
  End;
  While(TP<TEnd)and Not Delim(TBuf^[TP])Do Begin
   If Length(Tok)<40 Then Tok:=Tok+Chr(TBuf^[TP]);
   Inc(TP);
  End;
  If Tok='' Then Begin Inc(TP); Continue; End;
  { nombre ? }
  If(Tok[1]='.')Then Tok:='0'+Tok;
  If(Length(Tok)>1)and(Tok[1]='-')and(Tok[2]='.')Then Tok:='-0'+Copy(Tok,2,40);
  If(Tok[1] in ['0'..'9','-','+'])Then Begin
   Val(Tok,V,Cd);
   If Cd=0 Then Begin NextTok:=1; Exit; End;
  End;
  NextTok:=2;
  Exit;
 End;
End;

Procedure DocPt(X,Y:Double;Var P:TPt);
Var XP,YP,A,B:Double;
Begin
 XP:=CA*X+CC*Y+CE;
 YP:=CB*X+CD*Y+CF;
 A:=(XP-OffX)*254/72;
 B:=(TopY-YP)*254/72;
 If A>1000000 Then A:=1000000;
 If A<-1000000 Then A:=-1000000;
 If B>1000000 Then B:=1000000;
 If B<-1000000 Then B:=-1000000;
 P.X:=Round(A);
 P.Y:=Round(B);
End;

Procedure Concat(MA,MB,MC,MD,ME,MF:Double);
Var A,B,C,D,E,F:Double;
Begin
 A:=MA*CA+MB*CC;
 B:=MA*CB+MB*CD;
 C:=MC*CA+MD*CC;
 D:=MC*CB+MD*CD;
 E:=ME*CA+MF*CC+CE;
 F:=ME*CB+MF*CD+CF;
 CA:=A; CB:=B; CC:=C; CD:=D; CE:=E; CF:=F;
End;

Procedure PMove(X,Y:Double);
Begin
 If(PSubN<64)and(PPN<7900)Then Begin
  PSub[PSubN]:=PPN;
  PCl[PSubN]:=False;
  Inc(PSubN);
  DocPt(X,Y,PPts[PPN]);
  Inc(PPN);
 End;
 CurX:=X; CurY:=Y; StX:=X; StY:=Y;
End;

Procedure PCurve(X1,Y1,X2,Y2,X3,Y3:Double);
Begin
 If PSubN=0 Then PMove(X1,Y1);
 If PPN+3<7990 Then Begin
  DocPt(X1,Y1,PPts[PPN]);
  DocPt(X2,Y2,PPts[PPN+1]);
  DocPt(X3,Y3,PPts[PPN+2]);
  Inc(PPN,3);
 End;
 CurX:=X3; CurY:=Y3;
End;

Procedure PLine(X,Y:Double);
Var P,A:TPt;
Begin
 If PSubN=0 Then Begin PMove(X,Y); Exit; End;
 If PPN+3<7990 Then Begin
  A:=PPts[PPN-1];
  DocPt(X,Y,P);
  PPts[PPN].X:=A.X+(P.X-A.X) Div 3;
  PPts[PPN].Y:=A.Y+(P.Y-A.Y) Div 3;
  PPts[PPN+1].X:=A.X+(2*(P.X-A.X)) Div 3;
  PPts[PPN+1].Y:=A.Y+(2*(P.Y-A.Y)) Div 3;
  PPts[PPN+2]:=P;
  Inc(PPN,3);
 End;
 CurX:=X; CurY:=Y;
End;

Procedure PClose;
Begin
 If PSubN=0 Then Exit;
 If(CurX<>StX)or(CurY<>StY)Then PLine(StX,StY);
 PCl[PSubN-1]:=True;
 CurX:=StX; CurY:=StY;
End;

Procedure PClear;
Begin
 PPN:=0;
 PSubN:=0;
End;

Procedure Paint(Fill,Strk:Boolean);
Var O:PObj;
    I,K,Tot,S,E,N:Integer;
    AnyCl:Boolean;
Begin
 If(PSubN=0)or(PSMade>6000)Then Exit;
 Tot:=0;
 N:=0;
 For I:=0 To PSubN-1 Do Begin
  S:=PSub[I];
  If I+1<PSubN Then E:=PSub[I+1]-1 Else E:=PPN-1;
  If E-S>=3 Then Begin
   Inc(Tot,E-S+1);
   If N>0 Then Inc(Tot,2);
   Inc(N);
  End;
 End;
 If(N=0)or(Tot>7990)Then Exit;
 O:=NewObj(K_BEZIER,Tot);
 K:=0;
 N:=0;
 AnyCl:=False;
 For I:=0 To PSubN-1 Do Begin
  S:=PSub[I];
  If I+1<PSubN Then E:=PSub[I+1]-1 Else E:=PPN-1;
  If E-S>=3 Then Begin
   If N>0 Then Begin
    O^.Pts^[K].X:=BRK; O^.Pts^[K].Y:=0;
    O^.Pts^[K+1].X:=BRK; O^.Pts^[K+1].Y:=0;
    Inc(K,2);
   End;
   Move(PPts[S],O^.Pts^[K],(E-S+1)*SizeOf(TPt));
   Inc(K,E-S+1);
   Inc(N);
   If PCl[I]Then AnyCl:=True;
  End;
 End;
 O^.Closed:=Fill or AnyCl;
 If Fill Then Begin
  O^.FillKind:=FK_SOLID;
  O^.FillCol:=FillC;
 End
  Else Begin
   O^.FillKind:=FK_NONE;
   O^.FillCol:=-1;
  End;
 If Strk Then Begin
  O^.OutCol:=StrC;
  O^.OutW:=Round(LWd*Sqrt(Abs(CA*CD-CB*CC))*254/72);
  If O^.OutW<1 Then O^.OutW:=1;
 End
  Else O^.OutCol:=-1;
 AddObj(O);
 Inc(PSMade);
End;

Procedure ShowText(Const S:String);
Var O:PObj;
    P:TPt;
    Sz:Double;
    T:String;
Begin
 If(S='')or(PSMade>6000)Then Exit;
 T:=S;
 If Length(T)>60 Then T:=Copy(T,1,60);
 DocPt(TMe,TMf,P);
 Sz:=FontSz*Sqrt(Abs(TMa*TMd-TMb*TMc))*Sqrt(Abs(CA*CD-CB*CC))*254/72;
 If Sz<20 Then Sz:=20;
 If Sz>2000 Then Sz:=2000;
 O:=NewObj(K_TEXT,1);
 O^.Txt:=T;
 O^.TextSize:=Round(Sz);
 O^.Pts^[0].X:=P.X;
 O^.Pts^[0].Y:=P.Y-Round(Sz)+Round(Sz) Div 8;
 O^.FillKind:=FK_SOLID;
 O^.FillCol:=FillC;
 O^.OutCol:=-1;
 AddObj(O);
 Inc(PSMade);
 TMe:=TMe+Length(S)*FontSz*0.6*TMa;
 TMf:=TMf+Length(S)*FontSz*0.6*TMb;
 CurX:=CurX+Length(S)*FontSz*0.6;
End;

Procedure GSave;
Begin
 If GSP<32 Then Begin
  GStack[GSP].A:=CA; GStack[GSP].B:=CB; GStack[GSP].C:=CC; GStack[GSP].D:=CD;
  GStack[GSP].E:=CE; GStack[GSP].F:=CF; GStack[GSP].LW:=LWd; GStack[GSP].FS:=FontSz;
  GStack[GSP].FC:=FillC; GStack[GSP].SC:=StrC;
  Inc(GSP);
 End;
End;

Procedure GRestore;
Begin
 If GSP>0 Then Begin
  Dec(GSP);
  CA:=GStack[GSP].A; CB:=GStack[GSP].B; CC:=GStack[GSP].C; CD:=GStack[GSP].D;
  CE:=GStack[GSP].E; CF:=GStack[GSP].F; LWd:=GStack[GSP].LW; FontSz:=GStack[GSP].FS;
  FillC:=GStack[GSP].FC; StrC:=GStack[GSP].SC;
 End;
End;

Function Arg(I:Integer):Double;
Begin
 If SN-I>=0 Then Arg:=SNum[SN-I] Else Arg:=0;
End;

Function CmykCol(C,M,Y,K:Double):Integer;
Begin
 CmykCol:=ImpColor(Round(255*(1-C)*(1-K)),Round(255*(1-M)*(1-K)),Round(255*(1-Y)*(1-K)));
End;

{ Interprete le flux de TP a TEnd (operateurs PostScript et PDF) }
Procedure RunStream;
Var Tok:String;
    K,I:Integer;
    NoClear:Boolean;
Begin
 SN:=0;
 InArr:=False;
 While TP<TEnd Do Begin
  K:=NextTok(Tok);
  If K=0 Then Break;
  If K=1 Then Begin
   If SN<64 Then Begin
    Val(Tok,SNum[SN],I);
    Inc(SN);
   End;
   Continue;
  End;
  If K=3 Then Begin
   SStr:=Tok;
   If InArr Then TJAcc:=TJAcc+Tok;
   Continue;
  End;
  If K=4 Then Begin
   If Tok='[' Then Begin InArr:=True; TJAcc:=''; End Else InArr:=False;
   Continue;
  End;
  If K=6 Then Continue;
  { operateurs }
  If DbgTrace Then WriteLn(DbgF,'op ',Tok,' n=',SN,' a1=',Arg(1):0:2,' a4=',Arg(4):0:2);
  If(Tok='m')or(Tok='moveto')Then PMove(Arg(2),Arg(1))
  Else If(Tok='l')or(Tok='lineto')Then PLine(Arg(2),Arg(1))
  Else If Tok='rmoveto' Then PMove(CurX+Arg(2),CurY+Arg(1))
  Else If Tok='rlineto' Then PLine(CurX+Arg(2),CurY+Arg(1))
  Else If(Tok='c')or(Tok='curveto')Then PCurve(Arg(6),Arg(5),Arg(4),Arg(3),Arg(2),Arg(1))
  Else If Tok='rcurveto' Then
   PCurve(CurX+Arg(6),CurY+Arg(5),CurX+Arg(4),CurY+Arg(3),CurX+Arg(2),CurY+Arg(1))
  Else If Tok='v' Then PCurve(CurX,CurY,Arg(4),Arg(3),Arg(2),Arg(1))
  Else If Tok='y' Then PCurve(Arg(4),Arg(3),Arg(2),Arg(1),Arg(2),Arg(1))
  Else If(Tok='h')or(Tok='closepath')Then PClose
  Else If Tok='re' Then Begin
   PMove(Arg(4),Arg(3));
   PLine(Arg(4)+Arg(2),Arg(3));
   PLine(Arg(4)+Arg(2),Arg(3)+Arg(1));
   PLine(Arg(4),Arg(3)+Arg(1));
   PClose;
  End
  Else If(Tok='n')or(Tok='newpath')Then PClear
  Else If(Tok='f')or(Tok='F')or(Tok='f*')or(Tok='fill')or(Tok='eofill')Then Begin
   Paint(True,False);
   If IsPdf or(GSP=0)Then PClear;
  End
  Else If(Tok='S')or(Tok='stroke')Then Begin
   Paint(False,True);
   If IsPdf or(GSP=0)Then PClear;
  End
  Else If Tok='s' Then Begin PClose; Paint(False,True); PClear; End
  Else If(Tok='B')or(Tok='B*')Then Begin Paint(True,True); PClear; End
  Else If(Tok='b')or(Tok='b*')Then Begin PClose; Paint(True,True); PClear; End
  Else If Tok='rg' Then FillC:=ImpColor(Round(Arg(3)*255),Round(Arg(2)*255),Round(Arg(1)*255))
  Else If Tok='RG' Then StrC:=ImpColor(Round(Arg(3)*255),Round(Arg(2)*255),Round(Arg(1)*255))
  Else If Tok='g' Then FillC:=ImpColor(Round(Arg(1)*255),Round(Arg(1)*255),Round(Arg(1)*255))
  Else If Tok='G' Then StrC:=ImpColor(Round(Arg(1)*255),Round(Arg(1)*255),Round(Arg(1)*255))
  Else If(Tok='scn')or(Tok='sc')or(Tok='SCN')or(Tok='SC')Then Begin
   If SN>=4 Then K:=CmykCol(Arg(4),Arg(3),Arg(2),Arg(1))
   Else If SN=3 Then K:=ImpColor(Round(Arg(3)*255),Round(Arg(2)*255),Round(Arg(1)*255))
   Else If SN=1 Then K:=ImpColor(Round(Arg(1)*255),Round(Arg(1)*255),Round(Arg(1)*255))
   Else K:=-1;
   If K>=0 Then Begin
    If(Tok='scn')or(Tok='sc')Then FillC:=K Else StrC:=K;
   End;
  End
  Else If Tok='k' Then FillC:=CmykCol(Arg(4),Arg(3),Arg(2),Arg(1))
  Else If Tok='K' Then StrC:=CmykCol(Arg(4),Arg(3),Arg(2),Arg(1))
  Else If Tok='setrgbcolor' Then Begin
   FillC:=ImpColor(Round(Arg(3)*255),Round(Arg(2)*255),Round(Arg(1)*255));
   StrC:=FillC;
  End
  Else If Tok='setgray' Then Begin
   FillC:=ImpColor(Round(Arg(1)*255),Round(Arg(1)*255),Round(Arg(1)*255));
   StrC:=FillC;
  End
  Else If Tok='setcmykcolor' Then Begin
   FillC:=CmykCol(Arg(4),Arg(3),Arg(2),Arg(1));
   StrC:=FillC;
  End
  Else If(Tok='w')or(Tok='setlinewidth')Then LWd:=Arg(1)
  Else If Tok='cm' Then Concat(Arg(6),Arg(5),Arg(4),Arg(3),Arg(2),Arg(1))
  Else If Tok='translate' Then Concat(1,0,0,1,Arg(2),Arg(1))
  Else If Tok='scale' Then Concat(Arg(2),0,0,Arg(1),0,0)
  Else If Tok='rotate' Then Concat(Cos(Arg(1)*Pi/180),Sin(Arg(1)*Pi/180),-Sin(Arg(1)*Pi/180),Cos(Arg(1)*Pi/180),0,0)
  Else If Tok='concat' Then Concat(Arg(6),Arg(5),Arg(4),Arg(3),Arg(2),Arg(1))
  Else If(Tok='q')or(Tok='gsave')Then GSave
  Else If(Tok='Q')or(Tok='grestore')Then GRestore
  Else If Tok='BT' Then Begin
   TMa:=1; TMb:=0; TMc:=0; TMd:=1; TMe:=0; TMf:=0;
   TLa:=1; TLb:=0; TLc:=0; TLd:=1; TLe:=0; TLf:=0;
  End
  Else If Tok='Tf' Then FontSz:=Arg(1)
  Else If Tok='scalefont' Then FontSz:=Arg(1)
  Else If Tok='TL' Then Leading:=Arg(1)
  Else If Tok='Tm' Then Begin
   TMa:=Arg(6); TMb:=Arg(5); TMc:=Arg(4); TMd:=Arg(3); TMe:=Arg(2); TMf:=Arg(1);
   TLa:=TMa; TLb:=TMb; TLc:=TMc; TLd:=TMd; TLe:=TMe; TLf:=TMf;
  End
  Else If(Tok='Td')or(Tok='TD')Then Begin
   TLe:=Arg(2)*TLa+Arg(1)*TLc+TLe;
   TLf:=Arg(2)*TLb+Arg(1)*TLd+TLf;
   If Tok='TD' Then Leading:=-Arg(1);
   TMa:=TLa; TMb:=TLb; TMc:=TLc; TMd:=TLd; TMe:=TLe; TMf:=TLf;
  End
  Else If Tok='T*' Then Begin
   TLe:=-Leading*TLc+TLe;
   TLf:=-Leading*TLd+TLf;
   TMe:=TLe; TMf:=TLf;
  End
  Else If(Tok='Tj')or(Tok='''')Then ShowText(SStr)
  Else If Tok='TJ' Then ShowText(TJAcc)
  Else If Tok='show' Then Begin
   TMa:=1; TMb:=0; TMc:=0; TMd:=1; TMe:=CurX; TMf:=CurY;
   ShowText(SStr);
  End
  Else If Tok='BI' Then Begin
   { image en ligne : on saute jusqu'a EI }
   While(TP<TEnd-2)and Not((TBuf^[TP]<=32)and(TBuf^[TP+1]=Ord('E'))and(TBuf^[TP+2]=Ord('I')))Do Inc(TP);
   Inc(TP,3);
  End;
  SN:=0;
  NoClear:=False;
 End;
End;

Procedure InitGState;
Begin
 CA:=1; CB:=0; CC:=0; CD:=1; CE:=0; CF:=0;
 GSP:=0;
 FillC:=0; StrC:=0;
 LWd:=1; FontSz:=12; Leading:=12;
 PClear;
 TMa:=1; TMb:=0; TMc:=0; TMd:=1; TMe:=0; TMf:=0;
 TLa:=1; TLb:=0; TLc:=0; TLd:=1; TLe:=0; TLf:=0;
 CurX:=0; CurY:=0; StX:=0; StY:=0;
End;

Function ParseNums(Const S:String;Var V:Array of Double;N:Integer):Integer;
Var I,K,Cd:Integer;
    T:String;
Begin
 K:=0;
 I:=1;
 While(I<=Length(S))and(K<N)Do Begin
  While(I<=Length(S))and Not(S[I] in ['0'..'9','-','.','+'])Do Inc(I);
  T:='';
  While(I<=Length(S))and(S[I] in ['0'..'9','-','.','+','e','E'])Do Begin T:=T+S[I]; Inc(I); End;
  If T<>'' Then Begin
   If T[1]='.' Then T:='0'+T;
   Val(T,V[K],Cd);
   If Cd=0 Then Inc(K);
  End;
 End;
 ParseNums:=K;
End;

{ Le flux ressemble-t-il a du texte (et non a des donnees binaires) ? }
Function LooksText(B:PBig;Len:LongInt):Boolean;
Var I,N,Bad:LongInt;
Begin
 N:=Len;
 If N>400 Then N:=400;
 Bad:=0;
 For I:=0 To N-1 Do
  If(B^[I]<9)or((B^[I]>13)and(B^[I]<32))or(B^[I]>126)Then Inc(Bad);
 LooksText:=Bad*20<=N;
End;

Function FindStr(Const Pat:String;From:LongInt):LongInt;
Var I,J:LongInt;
    Ok:Boolean;
Begin
 FindStr:=-1;
 For I:=From To ILen-Length(Pat) Do Begin
  Ok:=True;
  For J:=1 To Length(Pat) Do
   If IBuf^[I+J-1]<>Ord(Pat[J])Then Begin Ok:=False; Break; End;
  If Ok Then Begin FindStr:=I; Exit; End;
 End;
End;

Function LoadPSFile:Boolean;
Var P,Q:LongInt;
    S:String;
    V:Array[0..3] of Double;
    N,I:Integer;
Begin
 LoadPSFile:=False;
 IsPdf:=False;
 P:=0;
 { EPS binaire (en-tete DOS) }
 If(IB(0)=$C5)and(IB(1)=$D0)and(IB(2)=$D3)and(IB(3)=$C6)Then Begin
  P:=IL(4);
  If(P<0)or(P>=ILen)Then P:=0;
 End;
 V[0]:=0; V[1]:=0; V[2]:=595; V[3]:=842;
 Q:=FindStr('%%BoundingBox:',P);
 If(Q>=0)Then Begin
  S:='';
  I:=Q+14;
  While(I<ILen)and(IBuf^[I]<>10)and(IBuf^[I]<>13)and(Length(S)<100)Do Begin
   S:=S+Chr(IBuf^[I]);
   Inc(I);
  End;
  N:=ParseNums(S,V,4);
  If N<4 Then Begin V[0]:=0; V[1]:=0; V[2]:=595; V[3]:=842; End;
 End;
 If(V[2]-V[0]<1)or(V[3]-V[1]<1)Then Exit;
 If INewDoc Then Begin
  PageW:=Clamp(Round((V[2]-V[0])*254/72),500,9000);
  PageH:=Clamp(Round((V[3]-V[1])*254/72),500,9000);
 End;
 OffX:=V[0];
 TopY:=V[3];
 InitGState;
 PSMade:=0;
 TBuf:=IBuf;
 TP:=P;
 TEnd:=ILen;
 RunStream;
 LoadPSFile:=ObjCount>INew;
End;

Function LoadPDFFile:Boolean;
Var P,Q,Ds,E,L,OutLen,Cap:LongInt;
    Dict:String;
    V:Array[0..3] of Double;
    N:Integer;
    I:LongInt;
    Dst:PBig;
    Flate,Skip,Ok:Boolean;
    Pages:Integer;
    N0:LongInt;
    S:String;
Begin
 LoadPDFFile:=False;
 IsPdf:=True;
 V[0]:=0; V[1]:=0; V[2]:=595; V[3]:=842;
 Q:=FindStr('/MediaBox',0);
 If Q>=0 Then Begin
  S:='';
  I:=Q+9;
  While(I<ILen)and(IBuf^[I]<>Ord(']'))and(Length(S)<100)Do Begin
   S:=S+Chr(IBuf^[I]);
   Inc(I);
  End;
  N:=ParseNums(S,V,4);
  If N<4 Then Begin V[0]:=0; V[1]:=0; V[2]:=595; V[3]:=842; End;
 End;
 If(V[2]-V[0]<1)or(V[3]-V[1]<1)Then Exit;
 If INewDoc Then Begin
  PageW:=Clamp(Round((V[2]-V[0])*254/72),500,9000);
  PageH:=Clamp(Round((V[3]-V[1])*254/72),500,9000);
 End;
 OffX:=V[0];
 TopY:=V[3];
 PSMade:=0;
 Pages:=0;
 P:=0;
 N0:=ObjCount;
 While P<ILen Do Begin
  Q:=FindStr('stream',P);
  If Q<0 Then Break;
  { evite "endstream" }
  If(Q>=3)and(IBuf^[Q-1]=Ord('d'))and(IBuf^[Q-2]=Ord('n'))and(IBuf^[Q-3]=Ord('e'))Then Begin
   P:=Q+6;
   Continue;
  End;
  { le mot-cle est precede de ">>" et suivi d'une fin de ligne }
  Ds:=Q-1;
  While(Ds>0)and(IBuf^[Ds]<=32)Do Dec(Ds);
  If Not((IBuf^[Ds]=Ord('>'))and(IBuf^[Q+6]<=32))Then Begin
   P:=Q+6;
   Continue;
  End;
  Dict:='';
  I:=Q-1;
  While(I>=0)and(Q-I<600)and Not((IBuf^[I]=Ord('o'))and(IBuf^[I+1]=Ord('b'))and(IBuf^[I+2]=Ord('j')))Do Dec(I);
  For L:=I+3 To Q-1 Do If Length(Dict)<250 Then Dict:=Dict+Chr(IBuf^[L]);
  Q:=Q+6;
  If IBuf^[Q]=13 Then Inc(Q);
  If IBuf^[Q]=10 Then Inc(Q);
  E:=FindStr('endstream',Q);
  If E<0 Then Break;
  P:=E+9;
  Flate:=Pos('FlateDecode',Dict)>0;
  Skip:=(Pos('/XRef',Dict)>0)or(Pos('/ObjStm',Dict)>0)or(Pos('/Image',Dict)>0)or
        (Pos('/Length1',Dict)>0)or(Pos('/Font',Dict)>0)or(Pos('/Metadata',Dict)>0)or
        (Pos('DCTDecode',Dict)>0)or(Pos('LZWDecode',Dict)>0)or(Pos('/ICC',Dict)>0)or(Pos('/N ',Dict)>0);
  If DbgTrace Then WriteLn(DbgF,'stream ',Q,' len ',E-Q,' flate ',Flate,' skip ',Skip,' dict ',Copy(Dict,1,70));
  If Skip Then Continue;
  If E-Q<4 Then Continue;
  Ds:=ObjCount;
  If Flate Then Begin
   Cap:=(E-Q)*30+4096;
   If Cap>40000000 Then Cap:=40000000;
   GetMem(Dst,Cap+8);
   FillChar(Dst^,16,0);
   Ok:=Inflate(PBig(@IBuf^[Q]),E-Q,Dst,Cap);
   OutLen:=InfOutPos;
   If DbgTrace Then WriteLn(DbgF,'  inflate ',Ok,' out ',OutLen);
   If(OutLen>0)and LooksText(Dst,OutLen)Then Begin
    TBuf:=Dst;
    TP:=0;
    TEnd:=OutLen;
    InitGState;
    RunStream;
    TBuf:=IBuf;
   End;
   FreeMem(Dst,Cap+8);
  End
   Else If LooksText(@IBuf^[Q],E-Q)Then Begin
    TBuf:=IBuf;
    InitGState;
    TP:=Q;
    TEnd:=E;
    RunStream;
   End;
  If ObjCount>Ds Then Begin
   Inc(Pages);
   If Pages>1 Then Begin
    If PageCnt<PAGE_MAX Then Inc(PageCnt);
    CurPage:=PageCnt;
    { les objets de ce flux appartiennent a la nouvelle page }
    For I:=Ds To ObjCount-1 Do ObjAt(I)^.Page:=CurPage;
   End;
  End;
 End;
 LoadPDFFile:=ObjCount>N0;
End;

{ ------------------------------ WMF --------------------------------- }

Function LoadWMFFile:Boolean;
Type
 TWObj=Record
  Kind:Byte;
  PStyle,PW:Integer;
  PCol,BCol:LongInt;
  BStyle:Integer;
 End;
Var Pos,Sz,Func,Inch,P:LongInt;
    Tab:Array[0..127] of TWObj;
    CurPen,CurBrush:Integer;
    OrgX,OrgY,I,K,N,J,FontH:LongInt;
    O:PObj;
    Sc:Double;
    TCol:LongInt;
    MoveX,MoveY:LongInt;
    Pl:Boolean;
    PX0,PY0:Array[0..3999] of LongInt;
    Counts:Array[0..99] of LongInt;
    Pen,Brs:TWObj;
    HavePen,HaveBrs:Boolean;
 Function Slot:Integer;
 Var Q:Integer;
 Begin
  For Q:=0 To 127 Do If Tab[Q].Kind=0 Then Begin Slot:=Q; Exit; End;
  Slot:=127;
 End;
 Function Cx(V:LongInt):LongInt;
 Begin
  Cx:=Round((V-OrgX)*Sc);
 End;
 Function Cy(V:LongInt):LongInt;
 Begin
  Cy:=Round((V-OrgY)*Sc);
 End;
 Procedure Style(O:PObj;Closed:Boolean);
 Begin
  If HavePen and(Pen.PStyle<>5)Then Begin
   O^.OutCol:=ImpColor(Pen.PCol And 255,(Pen.PCol Shr 8) And 255,(Pen.PCol Shr 16) And 255);
   O^.OutW:=Max(1,Round(Pen.PW*Sc));
  End
   Else O^.OutCol:=-1;
  If Closed and HaveBrs and(Brs.BStyle<>1)Then Begin
   O^.FillKind:=FK_SOLID;
   O^.FillCol:=ImpColor(Brs.BCol And 255,(Brs.BCol Shr 8) And 255,(Brs.BCol Shr 16) And 255);
  End
   Else Begin
    O^.FillKind:=FK_NONE;
    O^.FillCol:=-1;
   End;
  If(O^.OutCol<0)and(O^.FillKind=FK_NONE)Then O^.OutCol:=0;
  O^.Closed:=Closed;
  AddObj(O);
 End;
 Procedure AddPoly(Cnt,At:LongInt;Closed:Boolean);
 Var O:PObj;
     Q:LongInt;
 Begin
  If(Cnt<2)or(Cnt>4000)Then Exit;
  If Closed and(Cnt>=3)Then O:=NewObj(K_POLY,Cnt)
   Else If Cnt=2 Then O:=NewObj(K_LINE,2)
   Else O:=NewObj(K_POLYLINE,Cnt);
  For Q:=0 To Cnt-1 Do Begin
   O^.Pts^[Q].X:=Cx(IWs(At+Q*4));
   O^.Pts^[Q].Y:=Cy(IWs(At+Q*4+2));
  End;
  Style(O,O^.Kind=K_POLY);
 End;
 Procedure AddRect(L,T,R,B:LongInt;Ell:Boolean);
 Var O:PObj;
 Begin
  If Ell Then O:=NewObj(K_ELLIPSE,2) Else O:=NewObj(K_RECT,2);
  O^.Pts^[0].X:=Cx(L); O^.Pts^[0].Y:=Cy(T);
  O^.Pts^[1].X:=Cx(R); O^.Pts^[1].Y:=Cy(B);
  ObjNormalize2(O);
  Style(O,True);
 End;
 Procedure AddText(S,X,Y:LongInt;Len:LongInt);
 Var O:PObj;
     T:String;
     Q:LongInt;
 Begin
  If Len<=0 Then Exit;
  T:='';
  For Q:=0 To Len-1 Do If Length(T)<60 Then T:=T+Chr(IB(S+Q));
  O:=NewObj(K_TEXT,1);
  O^.Txt:=T;
  O^.TextSize:=Clamp(Round(Abs(FontH)*Sc),20,2000);
  O^.Pts^[0].X:=Cx(X);
  O^.Pts^[0].Y:=Cy(Y);
  O^.FillKind:=FK_SOLID;
  O^.FillCol:=ImpColor(TCol And 255,(TCol Shr 8) And 255,(TCol Shr 16) And 255);
  O^.OutCol:=-1;
  AddObj(O);
 End;
Begin
 LoadWMFFile:=False;
 FillChar(Tab,SizeOf(Tab),0);
 Pos:=0;
 Inch:=0;
 If IL(0)=LongInt($9AC6CDD7)Then Begin
  Inch:=IW(14);
  Pos:=22;
 End;
 If(IW(Pos+2)<>9)Then Exit;
 Pos:=Pos+IW(Pos+2)*2;
 If Inch>0 Then Sc:=254/Inch Else Sc:=1;
 If Inch>0 Then Pl:=True Else Pl:=False;
 OrgX:=0; OrgY:=0;
 HavePen:=False; HaveBrs:=False;
 TCol:=0; MoveX:=0; MoveY:=0; FontH:=200;
 INew:=ObjCount;
 While Pos+6<=ILen Do Begin
  Sz:=IL(Pos);
  Func:=IW(Pos+4);
  If(Sz<3)or(Func=0)Then Break;
  P:=Pos+6;
  Case Func Of
   $020B:Begin OrgY:=IWs(P); OrgX:=IWs(P+2); End;
   $0209:TCol:=IL(P);
   $02FA:Begin
     K:=Slot;
     Tab[K].Kind:=1; Tab[K].PStyle:=IW(P); Tab[K].PW:=IWs(P+2); Tab[K].PCol:=IL(P+6);
    End;
   $02FC:Begin
     K:=Slot;
     Tab[K].Kind:=2; Tab[K].BStyle:=IW(P); Tab[K].BCol:=IL(P+2);
    End;
   $02FB:Begin
     K:=Slot;
     Tab[K].Kind:=3; Tab[K].PW:=IWs(P);
    End;
   $012D:Begin
     K:=IW(P);
     If K<=127 Then Begin
      If Tab[K].Kind=1 Then Begin Pen:=Tab[K]; HavePen:=True; End
       Else If Tab[K].Kind=2 Then Begin Brs:=Tab[K]; HaveBrs:=True; End
       Else If Tab[K].Kind=3 Then FontH:=Tab[K].PW;
     End;
    End;
   $01F0:Begin
     K:=IW(P);
     If K<=127 Then Tab[K].Kind:=0;
    End;
   $0324:AddPoly(IW(P),P+2,True);
   $0325:AddPoly(IW(P),P+2,False);
   $0538:Begin
     N:=IW(P);
     If(N>0)and(N<=100)Then Begin
      J:=P+2+N*2;
      For K:=0 To N-1 Do Begin
       AddPoly(IW(P+2+K*2),J,True);
       J:=J+IW(P+2+K*2)*4;
      End;
     End;
    End;
   $041B:AddRect(IWs(P+6),IWs(P+4),IWs(P+2),IWs(P),False);
   $061C:AddRect(IWs(P+10),IWs(P+8),IWs(P+6),IWs(P+4),False);
   $0418:AddRect(IWs(P+6),IWs(P+4),IWs(P+2),IWs(P),True);
   $0214:Begin MoveY:=IWs(P); MoveX:=IWs(P+2); End;
   $0213:Begin
     K:=IWs(P);
     N:=IWs(P+2);
     O:=NewObj(K_LINE,2);
     O^.Pts^[0].X:=Cx(MoveX); O^.Pts^[0].Y:=Cy(MoveY);
     O^.Pts^[1].X:=Cx(N); O^.Pts^[1].Y:=Cy(K);
     Style(O,False);
     MoveX:=N; MoveY:=K;
    End;
   $0521:AddText(P+2,IWs(P+2+((IW(P)+1) Div 2)*2+2),IWs(P+2+((IW(P)+1) Div 2)*2),IW(P));
   $0A32:Begin
     K:=IW(P+4);
     N:=6;
     If(IW(P+6) And 6)<>0 Then N:=14;
     AddText(P+N,IWs(P+2),IWs(P),K);
    End;
  End;
  Pos:=Pos+Sz*2;
 End;
 If ObjCount<=INew Then Exit;
 NormalizeNew(1,Not Pl);
 LoadWMFFile:=True;
End;

{ ------------------------- point d'entree --------------------------- }

Function ExtIs(Const E,List:String):Boolean;
Begin
 ExtIs:=Pos(E+';',List+';')>0;
End;

Function LoadForeign(Const Name:String;Append:Boolean):Boolean;
Var E:String;
    Ok:Boolean;
Begin
 LoadForeign:=False;
 E:=ExtOf(Name);
 If Not ReadWhole(Name)Then Exit;
 If Not Append Then Begin
  NewDocument;
  PageW:=2100;
  PageH:=2970;
 End;
 INewDoc:=Not Append;
 INew:=ObjCount;
 Ok:=False;
 If E='.DXF' Then Begin
  FreeWhole;
  Ok:=LoadDXFFile(Name);
 End
  Else Begin
   TBuf:=IBuf;
   If(E='.EPS')or(E='.PS')or(E='.AI')Then Begin
    If(IB(0)=Ord('%'))and(IB(1)=Ord('P'))and(IB(2)=Ord('D'))and(IB(3)=Ord('F'))Then Ok:=LoadPDFFile
     Else Ok:=LoadPSFile;
   End
    Else If E='.PDF' Then Ok:=LoadPDFFile
    Else If E='.WMF' Then Ok:=LoadWMFFile
    Else If E='.BMP' Then Ok:=LoadBMPFile
    Else If E='.PCX' Then Ok:=LoadPCXFile
    Else If E='.PNG' Then Ok:=LoadPNGFile;
   FreeWhole;
  End;
 If Not Append Then FromCorel:=True;
 LoadForeign:=Ok;
End;

{ ------------------------- Acces aux donnees ----------------------- }

Function D32(O:LongInt):LongInt;
Begin
 If(O<0)or(O+4>DatLen)Then Begin
  D32:=0;
  Exit;
 End;
 D32:=LongInt(Dat^[O])Or(LongInt(Dat^[O+1])Shl 8)Or(LongInt(Dat^[O+2])Shl 16)Or(LongInt(Dat^[O+3])Shl 24);
End;

Function D16(O:LongInt):LongInt;
Begin
 If(O<0)or(O+2>DatLen)Then Begin
  D16:=0;
  Exit;
 End;
 D16:=LongInt(Dat^[O])Or(LongInt(Dat^[O+1])Shl 8);
End;

Function D16s(O:LongInt):LongInt;
Var V:LongInt;
Begin
 V:=D16(O);
 If V>=32768 Then V:=V-65536;
 D16s:=V;
End;

Function DDbl(O:LongInt):Double;
Var R:Double;
Begin
 R:=0;
 If(O>=0)and(O+8<=DatLen)Then Move(Dat^[O],R,8);
 DDbl:=R;
End;

Function TagAt(O:LongInt):String;
Var S:String;
    I:Integer;
Begin
 S:='';
 If(O>=0)and(O+4<=DatLen)Then
  For I:=0 To 3 Do S:=S+Chr(Dat^[O+I]);
 TagAt:=S;
End;

{ ------------------------- Couleurs et tables ---------------------- }

Function ColorPal(Model:LongInt;B0,B1,B2,B3:Integer):Integer;
Var R,G,B:Integer;
    C,M,Y,K:Real;
Begin
 R:=128; G:=128; B:=128;
 Case Model Of
  5:Begin R:=B2; G:=B1; B:=B0; End;
  2,3,$11:Begin
   If Model=2 Then Begin
    C:=B0/100; M:=B1/100; Y:=B2/100; K:=B3/100;
   End
    Else Begin
     C:=B0/255; M:=B1/255; Y:=B2/255; K:=B3/255;
    End;
   R:=Round(255*(1-C)*(1-K));
   G:=Round(255*(1-M)*(1-K));
   B:=Round(255*(1-Y)*(1-K));
  End;
  4:Begin R:=255-B0; G:=255-B1; B:=255-B2; End;
  9:Begin R:=B0; G:=B0; B:=B0; End;
 End;
 If R<0 Then R:=0; If R>255 Then R:=255;
 If G<0 Then G:=0; If G>255 Then G:=255;
 If B<0 Then B:=0; If B>255 Then B:=255;
 ColorPal:=AddPalColor(R,G,B);
End;

Function ColorAt(O:LongInt):Integer;
Begin
 ColorAt:=ColorPal(D16(O),D32(O+8) And 255,(D32(O+8) Shr 8)And 255,
                   (D32(O+8) Shr 16)And 255,(D32(O+8) Shr 24)And 255);
End;

Function HashSlot(Id:LongInt):Integer;
Begin
 If Id<0 Then Id:=-(Id+1);
 HashSlot:=Integer(Id Mod HASH_N);
End;

Function FindFill(Id:LongInt):Integer;
Var S,N:Integer;
Begin
 FindFill:=-1;
 If Id=0 Then Exit;
 S:=HashSlot(Id);
 For N:=1 To HASH_N Do Begin
  If FillTab^[S].Id=Id Then Begin FindFill:=S; Exit; End;
  If FillTab^[S].Id=0 Then Exit;
  S:=(S+1) Mod HASH_N;
 End;
End;

Function FindOutl(Id:LongInt):Integer;
Var S,N:Integer;
Begin
 FindOutl:=-1;
 If Id=0 Then Exit;
 S:=HashSlot(Id);
 For N:=1 To HASH_N Do Begin
  If OutlTab^[S].Id=Id Then Begin FindOutl:=S; Exit; End;
  If OutlTab^[S].Id=0 Then Exit;
  S:=(S+1) Mod HASH_N;
 End;
End;

Procedure ReadFild(B,Sz:LongInt);
Var R:TFillRec;
    S,N,Cnt,Typ:LongInt;
Begin
 If Sz<8 Then Exit;
 R.Id:=D32(B);
 If R.Id=0 Then Exit;
 Typ:=D16(B+4);
 R.Kind:=FK_NONE;
 R.Special:=D16(B+6)=$F0FF;
 R.C1:=-1;
 R.C2:=15;
 R.GX:=0;
 R.GY:=0;
 R.Bmp:=0;
 R.TW:=0;
 R.TH:=0;
 Case Typ Of
  0:;
  1:If Sz>=20 Then Begin
   R.Kind:=FK_SOLID;
   R.C1:=ColorAt(B+8);
  End;
  2:Begin
   Cnt:=D32(B+52);
   If(Sz>=56)and(Cnt>=2)and(Cnt<64)and(56+16*Cnt<=Sz)Then Begin
    R.Kind:=FK_GRADV;
    { type 2 : radial, 3 : conique, 4 : carre }
    If(D32(B+8)>=2)and(D32(B+8)<=4)Then Begin
     R.Kind:=FK_RADIAL;
     If D32(B+8)=3 Then R.Kind:=FK_CONIC;
     If D32(B+8)=4 Then R.Kind:=FK_SQUARE;
     R.GX:=ShortInt(Clamp(D32(B+36),-100,100));
     R.GY:=ShortInt(Clamp(D32(B+40),-100,100));
    End;
    R.C1:=ColorAt(B+56);
    R.C2:=ColorAt(B+56+16*(Cnt-1));
   End
    Else Begin
     R.Kind:=FK_SOLID;
     R.C1:=7;
    End;
  End;
 Else Begin
  R.Kind:=FK_SOLID;
  R.C1:=7;
  { motif a deux couleurs : le dessin du motif n'est pas relu, on le remplace
    par une trame de ces deux couleurs }
  If(Typ=7)and(Sz>=60)and Not C9Old Then Begin
   R.Kind:=FK_PATTERN;
   R.C1:=ColorAt(B+28);
   R.C2:=ColorAt(B+44);
  End;
  { motif en couleurs, texture : bitmap en cache, designe par son numero }
  If(Typ>=9)and(Typ<=11)and(Sz>=52)and Not C9Old Then Begin
   R.Kind:=FK_IMAGE;
   R.Bmp:=D32(B+48);
   R.TW:=D32(B+32);
   R.TH:=D32(B+36);
  End;
 End;
 End;
 S:=HashSlot(R.Id);
 For N:=1 To HASH_N Do Begin
  If(FillTab^[S].Id=0)or(FillTab^[S].Id=R.Id)Then Break;
  S:=(S+1) Mod HASH_N;
 End;
 FillTab^[S]:=R;
End;

Procedure ReadOutl(B,Sz:LongInt);
Var R:TOutlRec;
    S,N:LongInt;
Begin
 If(Not C9Old)and(Sz<88)Then Exit;
 If C9Old and(Sz<28)Then Exit;
 R.Id:=D32(B);
 If R.Id=0 Then Exit;
 If C9Old Then R.W:=D16(B+10)*254 Else R.W:=D32(B+12);
 If OwnExport and(D16(B+4)=1)Then R.W:=0;
 If C9Old Then R.C:=ColorAt(B+16) Else R.C:=ColorAt(B+76);
 S:=HashSlot(R.Id);
 For N:=1 To HASH_N Do Begin
  If(OutlTab^[S].Id=0)or(OutlTab^[S].Id=R.Id)Then Break;
  S:=(S+1) Mod HASH_N;
 End;
 OutlTab^[S]:=R;
End;

Procedure ReadStyles(B,Sz:LongInt);
Var O,N,I:LongInt;
Begin
 SNF:=0; SNO:=0;
 StyOff:=B;
 StyLen:=Sz;
 If Sz<16 Then Exit;
 O:=B+4;
 N:=D32(O);
 Inc(O,4);
 If(N<0)or(N>1000)Then Exit;
 For I:=0 To N-1 Do Begin
  SKeyF[I]:=D32(O);
  SValF[I]:=D32(O+8);
  Inc(O,12);
 End;
 SNF:=N;
 N:=D32(O);
 Inc(O,4);
 If(N<0)or(N>1000)Then Exit;
 For I:=0 To N-1 Do Begin
  SKeyO[I]:=D32(O);
  SValO[I]:=D32(O+8);
  Inc(O,12);
 End;
 SNO:=N;
End;

{ ------------------------- Objets ---------------------------------- }

{ Termine le sous-chemin en cours : il rejoint la courbe composee de l'objet }
{ ------------------------- Bitmaps --------------------------------- }

Const
 BMAP_N=4096;

Var
 BmpId:Array[0..BMAP_N-1] of LongInt;
 BmpImg:Array[0..BMAP_N-1] of Integer;
 BmpOW,BmpOH:Array[0..BMAP_N-1] of LongInt;
 BmpUsed:Array[0..BMAP_N-1] of Boolean;
 BmpN:Integer;

{ Bloc 'bmp ' : numero, en-tete DIB (repere 'RI'), palette eventuelle puis
  points a la fin du bloc, ligne du bas en premier. Modeles : 1 = RVB 24 bits,
  3 = RVBA 32 bits, 10 = 8 bits avec palette (768 octets avant les points) }
Procedure DecodeBmp(B,Sz:LongInt);
Var M,I,Model,W,H,Bpp,Stride,Size,P,PalOff,Sc,NW,NH,X,Y,SX,SY,Row,Col,O,V:LongInt;
    SumR,SumG,SumB,SumA,SumW,Cnt,Rr,Gg,Bb,Aa,Wt:LongInt;
    HasA,Gray:Boolean;
    Idx:Integer;
    Im:PImage;
Begin
 If C9Old Then Exit;
 If(BmpN>=BMAP_N)or(Sz<80)Then Exit;
 For I:=0 To BmpN-1 Do
  If BmpId[I]=D32(B)Then Exit;
 M:=-1;
 For I:=24 To 56 Do
  If(I+46<=Sz)and(Dat^[B+I]=82)and(Dat^[B+I+1]=73)Then Begin
   M:=I;
   Break;
  End;
 If M<0 Then Exit;
 Model:=D32(B+M+14);
 W:=D32(B+M+22);
 H:=D32(B+M+26);
 Bpp:=D32(B+M+34);
 Stride:=D32(B+M+38);
 Size:=D32(B+M+42);
 If(W<1)or(W>30000)or(H<1)or(H>30000)or(Stride<1)or(Size<1)Then Exit;
 If(Size>Sz-(M+46))or(Stride*H>Size)Then Exit;
 If(Bpp<>1)and(Bpp<>8)and(Bpp<>24)and(Bpp<>32)Then Exit;
 If Stride<(W*Bpp+7) Div 8 Then Exit;
 P:=B+Sz-Size;
 PalOff:=P-768;
 Gray:=(Bpp=8)and(PalOff<B+M+46);
 HasA:=(Bpp=32)and(Model=3);
 Sc:=1;
 While(W Div Sc>IMG_SIDE)or(H Div Sc>IMG_SIDE)Do Inc(Sc);
 NW:=W Div Sc;
 NH:=H Div Sc;
 If NW<1 Then NW:=1;
 If NH<1 Then NH:=1;
 ImgPalSetup;
 Idx:=ImgNew(NW,NH,HasA);
 If Idx=0 Then Exit;
 Im:=Imgs[Idx];
 For Y:=0 To NH-1 Do
  For X:=0 To NW-1 Do Begin
   SumR:=0; SumG:=0; SumB:=0; SumA:=0; SumW:=0; Cnt:=0;
   For SY:=0 To Sc-1 Do
    For SX:=0 To Sc-1 Do Begin
     Row:=H-1-(Y*Sc+SY);
     If Row<0 Then Row:=0;
     Col:=X*Sc+SX;
     If Col>=W Then Col:=W-1;
     O:=P+Row*Stride;
     Aa:=255;
     Case Bpp Of
      24:Begin
       Bb:=Dat^[O+Col*3]; Gg:=Dat^[O+Col*3+1]; Rr:=Dat^[O+Col*3+2];
      End;
      32:Begin
       Bb:=Dat^[O+Col*4]; Gg:=Dat^[O+Col*4+1]; Rr:=Dat^[O+Col*4+2];
       If HasA Then Aa:=Dat^[O+Col*4+3];
      End;
      8:Begin
       V:=Dat^[O+Col];
       If Gray Then Begin Rr:=V; Gg:=V; Bb:=V; End
        Else Begin
         Bb:=Dat^[PalOff+3*V]; Gg:=Dat^[PalOff+3*V+1]; Rr:=Dat^[PalOff+3*V+2];
        End;
      End;
     Else Begin
      V:=(Dat^[O+(Col Shr 3)] Shr (7-(Col And 7)))And 1;
      Rr:=V*255; Gg:=Rr; Bb:=Rr;
     End;
     End;
     If HasA Then Wt:=Aa+1 Else Wt:=1;
     Inc(SumR,Rr*Wt); Inc(SumG,Gg*Wt); Inc(SumB,Bb*Wt);
     Inc(SumW,Wt);
     Inc(SumA,Aa);
     Inc(Cnt);
    End;
   O:=(Y*NW+X)*3;
   Im^.Pix^[O]:=SumR Div SumW;
   Im^.Pix^[O+1]:=SumG Div SumW;
   Im^.Pix^[O+2]:=SumB Div SumW;
   If HasA Then Im^.A^[Y*NW+X]:=SumA Div Cnt;
  End;
 ImgAverage(Idx);
 BmpId[BmpN]:=D32(B);
 BmpImg[BmpN]:=Idx;
 BmpOW[BmpN]:=W;
 BmpOH[BmpN]:=H;
 BmpUsed[BmpN]:=False;
 Inc(BmpN);
End;

{ Image de numero Id (motifs et textures) ; 0 si inconnue }
Function ImgOfBmp(Id:LongInt):Integer;
Var I:Integer;
Begin
 ImgOfBmp:=0;
 For I:=0 To BmpN-1 Do
  If BmpId[I]=Id Then Begin
   ImgOfBmp:=BmpImg[I];
   Exit;
  End;
End;

{ Bitmap de dimensions d'origine W x H (de preference non encore utilise) }
Function ImgOfDims(W,H:LongInt):Integer;
Var I,First:Integer;
Begin
 ImgOfDims:=0;
 First:=-1;
 For I:=0 To BmpN-1 Do
  If(BmpOW[I]=W)and(BmpOH[I]=H)Then Begin
   If First<0 Then First:=I;
   If Not BmpUsed[I]Then Begin
    BmpUsed[I]:=True;
    ImgOfDims:=BmpImg[I];
    Exit;
   End;
  End;
 If First>=0 Then ImgOfDims:=BmpImg[First];
End;

Procedure SubFlush;
Var I:Integer;
    Closed,Fill:Boolean;
Begin
 If SubN<2 Then Begin
  SubN:=0;
  Exit;
 End;
 Fill:=tFillKind<>FK_NONE;
 Closed:=SubClosed or Fill;
 If CompCnt=0 Then Begin
  For I:=0 To SubN-1 Do CompP[I]:=SubP[I];
  CompN:=SubN;
  CompLines:=SubAllLines;
  CompClosed:=Closed;
 End
  Else Begin
   If CompN+2+SubN<=7999 Then Begin
    CompP[CompN].X:=BRK; CompP[CompN].Y:=0;
    CompP[CompN+1].X:=BRK; CompP[CompN+1].Y:=0;
    Inc(CompN,2);
    For I:=0 To SubN-1 Do CompP[CompN+I]:=SubP[I];
    Inc(CompN,SubN);
    CompLines:=False;
    CompClosed:=CompClosed or Closed;
   End;
  End;
 Inc(CompCnt);
 SubN:=0;
End;

{ Cree l'objet a partir des sous-chemins accumules }
Procedure CompFlush;
Var O:PObj;
    A,I:Integer;
Begin
 If CompCnt=0 Then Exit;
 CompCnt:=0;
 If CompN<2 Then Begin
  CompN:=0;
  Exit;
 End;
 A:=(CompN-1) Div 3+1;
 If CompLines Then Begin
  If A<2 Then Begin CompN:=0; Exit; End;
  If CompClosed and(A>2)and(CompP[0].X=CompP[(A-1)*3].X)and(CompP[0].Y=CompP[(A-1)*3].Y)Then Dec(A);
  If CompClosed and(A>=3)Then O:=NewObj(K_POLY,A)
   Else If A=2 Then O:=NewObj(K_LINE,2)
   Else O:=NewObj(K_POLYLINE,A);
  For I:=0 To A-1 Do O^.Pts^[I]:=CompP[I*3];
  O^.Closed:=O^.Kind=K_POLY;
 End
  Else Begin
   O:=NewObj(K_BEZIER,CompN);
   For I:=0 To CompN-1 Do O^.Pts^[I]:=CompP[I];
   O^.Closed:=CompClosed;
  End;
 O^.Group:=tGroup;
 If(O^.Kind=K_POLY)or(O^.Closed)Then Begin
  O^.FillKind:=tFillKind;
  O^.FillCol:=tF1;
  O^.FillCol2:=tF2;
  If tFillKind=FK_NONE Then O^.FillCol:=-1;
 End
  Else Begin
   O^.FillKind:=FK_NONE;
   O^.FillCol:=-1;
  End;
 O^.OutCol:=tOut;
 O^.OutW:=tW;
 O^.LineStyle:=0;
 O^.GradX:=tGX;
 O^.GradY:=tGY;
 If tFillKind=FK_PATTERN Then O^.Pattern:=8;
 O^.Img:=tImg;
 O^.TileW:=tTW;
 O^.TileH:=tTH;
 If Not AddObj(O)Then C9Full:=True;
 CompN:=0;
End;

Procedure SubAdd(X,Y:LongInt);
Begin
 If SubN<8000 Then Begin
  SubP[SubN].X:=X;
  SubP[SubN].Y:=Y;
  Inc(SubN);
 End;
End;

Function ValidPoints(Off,Len:LongInt;Var N:LongInt):Boolean;
Var I:LongInt;
    T:Integer;
Begin
 ValidPoints:=False;
 If C9Old Then Begin
  If Len<9 Then Exit;
  N:=D16(Off);
  If(N<2)or(N>7900)or(4+5*N>Len)Then Exit;
  T:=Dat^[Off+4+4*N];
  If(T And $C0)<>0 Then Exit;
  For I:=0 To N-1 Do
   If(Dat^[Off+4+4*N+I] And 3)<>0 Then Exit;
  ValidPoints:=True;
  Exit;
 End;
 If Len<13 Then Exit;
 N:=D16(Off);
 If(N<2)or(N>7900)or(4+9*N>Len)Then Exit;
 T:=Dat^[Off+4+8*N];
 If(T And $C0)<>0 Then Exit;
 For I:=0 To N-1 Do
  If(Dat^[Off+4+8*N+I] And 3)<>0 Then Exit;
 ValidPoints:=True;
End;

Var
 TxsmOff,TxsmSz:LongInt;
 TxsmOk,BBoxOk:Boolean;
 BB1X,BB1Y,BB2X,BB2Y:LongInt;

{ Liste de points : n:Word ; 0:Word ; (x,y:LongInt)*n ; types:n.
  Retourne le nombre d'octets en trop (>=0) ou -1 si la liste est invalide. }
Function PtsExtra(Off,Len:LongInt;Var N:LongInt):LongInt;
Var I,X,Y:LongInt;
Begin
 PtsExtra:=-1;
 If Not ValidPoints(Off,Len,N)Then Exit;
 If C9Old Then Begin
  PtsExtra:=Len-(4+5*N);
  Exit;
 End;
 For I:=0 To N-1 Do Begin
  X:=D32(Off+4+8*I);
  Y:=D32(Off+8+8*I);
  If(Abs(X)>300000000)or(Abs(Y)>300000000)Then Exit;
 End;
 PtsExtra:=Len-(4+9*N);
End;

{ Convertit les coordonnees locales (unites CDR) en unites du document }
Procedure LocalToWorld(X,Y:Double;Var WX,WY:LongInt);
Var X2,Y2,CX,CY:Double;
Begin
 If HaveTrf Then Begin
  X2:=Trf[0]*X+Trf[1]*Y+Trf[2];
  Y2:=Trf[3]*X+Trf[4]*Y+Trf[5];
 End
  Else Begin
   X2:=X;
   Y2:=Y;
  End;
 CX:=X2*CoordK+PageW/2;
 CY:=PageH/2-Y2*CoordK;
 If CX<-2000000 Then CX:=-2000000;
 If CX>2000000 Then CX:=2000000;
 If CY<-2000000 Then CY:=-2000000;
 If CY>2000000 Then CY:=2000000;
 WX:=Round(CX);
 WY:=Round(CY);
End;

{ Extrait le texte d'un objet texte : lignes dans TxLines[0..TxN-1] }
Var
 TxLines:Array[0..299] of String[60];
 TxAdv:Array[0..299] of Double;
 TxN:Integer;
 TxAcc:Double;

Procedure TextPush(Var Cur:String);
Begin
 If TxN<300 Then Begin
  TxLines[TxN]:=Cur;
  TxAdv[TxN]:=TxAcc;
  Inc(TxN);
 End;
 Cur:='';
 TxAcc:=0;
End;

Procedure EmitText(Kind:LongInt);
Var B,Sz,O,C,F,Found,I,K,BestS,BestL,RunS,Len,L,CPL,MaxLen:LongInt;
    Cur:String;
    Raw:String;
    X1,Y1,X2,Y2,TX,TY,W,H:LongInt;
    Cell,CellA,CellP,Em,Size,Scale:Double;
    Obj:PObj;
    Wrap:Boolean;
 Procedure AddLine(Const S:String;X,Y,CellSz:LongInt);
 Begin
  If S='' Then Exit;
  Obj:=NewObj(K_TEXT,1);
  Obj^.Pts^[0].X:=X;
  Obj^.Pts^[0].Y:=Y;
  Obj^.Txt:=S;
  Obj^.TextSize:=Clamp(CellSz,15,3000);
  Obj^.OutCol:=-1;
  Obj^.FillKind:=FK_SOLID;
  If(tFillKind<>FK_NONE)and(tF1>=0)Then Obj^.FillCol:=tF1 Else Obj^.FillCol:=0;
  Obj^.Group:=tGroup;
  If Not AddObj(Obj)Then C9Full:=True;
 End;
Begin
 If Not TxsmOk Then Begin
  Inc(SkipText);
  Exit;
 End;
 B:=TxsmOff;
 Sz:=TxsmSz;
 TxN:=0;
 TxAcc:=0;
 Cur:='';
 Found:=0;
 Wrap:=False;
 { methode A : enregistrements (avance, caractere, indicateur) }
 O:=0;
 While O+12<=Sz Do Begin
  C:=D32(B+O+4);
  F:=D32(B+O+8);
  If((F=LongInt($80000000))or(F=$10000000))and(C>=9)and(C<=255)Then Begin
   If C=13 Then TextPush(Cur)
    Else If C<>10 Then Begin
     If Length(Cur)>=60 Then TextPush(Cur);
     Cur:=Cur+Chr(C);
     TxAcc:=TxAcc+D32(B+O);
    End;
   Inc(Found);
   Inc(O,12);
  End
   Else Inc(O,4);
 End;
 If Cur<>'' Then TextPush(Cur);
 { methode C : CorelDRAW 5, enregistrements de 8 octets (avance, FFFF, caractere, indicateur) }
 If(Found=0)and C9Old Then Begin
  O:=0;
  While O+8<=Sz Do Begin
   C:=D16(B+O+4);
   If(D16(B+O+2)=$FFFF)and((C=13)or((C>=32)and(C<=255)))Then Begin
    If C=13 Then TextPush(Cur)
     Else Begin
      If Length(Cur)>=60 Then TextPush(Cur);
      Cur:=Cur+Chr(C);
      TxAcc:=TxAcc+D16(B+O);
     End;
    Inc(Found);
    Inc(O,8);
   End
    Else Inc(O,2);
  End;
  If Cur<>'' Then TextPush(Cur);
 End;
 { methode B : texte ASCII brut (CorelDRAW 8/9) }
 If Found=0 Then Begin
  BestS:=0; BestL:=0; RunS:=-1;
  For O:=0 To Sz Do Begin
   If(O<Sz)and(Dat^[B+O]>=32)and(Dat^[B+O]<127)Then Begin
    If RunS<0 Then RunS:=O;
   End
    Else Begin
     If(RunS>=0)and(O-RunS>BestL)Then Begin
      BestS:=RunS;
      BestL:=O-RunS;
     End;
     RunS:=-1;
    End;
  End;
  If BestL<3 Then Begin
   Inc(SkipText);
   Exit;
  End;
  Raw:='';
  For I:=0 To BestL-1 Do
   If Length(Raw)<255 Then Raw:=Raw+Chr(Dat^[B+BestS+I]);
  Wrap:=True;
 End;
 { position et taille }
 If BBoxOk Then Begin
  LocalToWorld(BB1X,BB1Y,X1,Y1);
  LocalToWorld(BB2X,BB2Y,X2,Y2);
  If X1>X2 Then Begin TX:=X1; X1:=X2; X2:=TX; End;
  If Y1>Y2 Then Begin TY:=Y1; Y1:=Y2; Y2:=TY; End;
  W:=Max(10,X2-X1);
  H:=Max(10,Y2-Y1);
  If Wrap Then Begin
   Len:=Length(Raw);
   CellA:=W/Len;
   If H/1.25<CellA Then CellA:=H/1.25;
   If H/(CellA*1.25)<1.8 Then Begin
    Cell:=CellA;
    TxLines[0]:=Copy(Raw,1,60);
    TxN:=1;
   End
    Else Begin
     CellP:=Sqrt(W*H/(Len*1.25));
     If CellP<15 Then CellP:=15;
     Cell:=CellP;
     CPL:=Trunc(W/Cell);
     If CPL<4 Then CPL:=4;
     If CPL>60 Then CPL:=60;
     TxN:=0;
     I:=1;
     While(I<=Len)and(TxN<300)Do Begin
      L:=CPL;
      If I+L-1<Len Then Begin
       K:=I+L-1;
       While(K>I)and(Raw[K]<>' ')Do Dec(K);
       If K>I Then L:=K-I+1;
      End;
      TxLines[TxN]:=Copy(Raw,I,L);
      Inc(TxN);
      Inc(I,L);
     End;
    End;
  End
   Else Begin
    MaxLen:=1;
    For I:=0 To TxN-1 Do If Length(TxLines[I])>MaxLen Then MaxLen:=Length(TxLines[I]);
    Cell:=W/MaxLen;
    If H/(TxN*1.25)<Cell Then Cell:=H/(TxN*1.25);
   End;
  For I:=0 To TxN-1 Do
   AddLine(TxLines[I],X1,Y1+Round(I*1.25*Cell),Round(Cell));
 End
  Else Begin
   If Not HaveTrf Then Begin
    Inc(SkipText);
    Exit;
   End;
   Scale:=Abs(Trf[0]);
   If Scale<0.0001 Then Scale:=1;
   If Wrap Then Begin
    TxLines[0]:=Copy(Raw,1,60);
    TxAdv[0]:=0;
    TxN:=1;
   End;
   LocalToWorld(0,0,TX,TY);
   { taille estimee a partir de la largeur totale (somme des avances) }
   Cell:=0;
   For I:=0 To TxN-1 Do
    If(Length(TxLines[I])>0)and(TxAdv[I]>0)Then Begin
     Em:=TxAdv[I]*Scale*CoordK/Length(TxLines[I]);
     If Em>Cell Then Cell:=Em;
    End;
   If Cell<15 Then Cell:=Max(15,Round(42333*Scale/1000*0.5));
   If Kind=6 Then TY:=TY+Round(Cell*1.6);
   For I:=0 To TxN-1 Do
    AddLine(TxLines[I],TX,TY-Round(Cell)+Round(I*2.5*Cell),Round(Cell));
  End;
End;

Procedure EmitObject;
Var Kind,NArg,OffT,I,Len,Slot,Q,V,PtsOff,PtsN,FillId,OutlId,Key,Ex,BestEx,RectArg,EllArg:LongInt;
    Offs:Array[0..63] of LongInt;
    K,T:Integer;
    PX0,PY0:LongInt;
    WX,WY:LongInt;
    X1,Y1,X2,Y2:LongInt;
    Obj:PObj;
    FxSkip:Boolean;
 { machine a etats du chemin : coordonnees locales X,Y et type de noeud }
 Procedure PathPt(X,Y:LongInt;T:Integer);
 Var KK:Integer;
     PT:TPt;
 Begin
  LocalToWorld(X,Y,WX,WY);
  PT.X:=WX;
  PT.Y:=WY;
  KK:=T And $C0;
  If KK=0 Then Begin
   SubFlush;
   SubN:=0;
   SubAllLines:=True;
   SubClosed:=False;
   PendCnt:=0;
   SubAdd(WX,WY);
  End
   Else
  If KK=$40 Then Begin
   If SubN>0 Then Begin
    PX0:=SubP[SubN-1].X;
    PY0:=SubP[SubN-1].Y;
    SubAdd(PX0+(WX-PX0) Div 3,PY0+(WY-PY0) Div 3);
    SubAdd(PX0+((WX-PX0)*2) Div 3,PY0+((WY-PY0)*2) Div 3);
    SubAdd(WX,WY);
   End;
   PendCnt:=0;
  End
   Else
  If KK=$C0 Then Begin
   If PendCnt<2 Then Begin
    PendC[PendCnt]:=PT;
    Inc(PendCnt);
   End;
  End
   Else Begin
    If SubN>0 Then Begin
     If PendCnt=2 Then Begin
      SubAdd(PendC[0].X,PendC[0].Y);
      SubAdd(PendC[1].X,PendC[1].Y);
      SubAdd(WX,WY);
      SubAllLines:=False;
     End
      Else Begin
       PX0:=SubP[SubN-1].X;
       PY0:=SubP[SubN-1].Y;
       SubAdd(PX0+(WX-PX0) Div 3,PY0+(WY-PY0) Div 3);
       SubAdd(PX0+((WX-PX0)*2) Div 3,PY0+((WY-PY0)*2) Div 3);
       SubAdd(WX,WY);
      End;
    End;
    PendCnt:=0;
   End;
  If((T And 8)<>0)and(KK<>0)and(SubN>1)Then Begin
   SubClosed:=True;
   SubFlush;
   SubN:=0;
   SubAllLines:=True;
   SubClosed:=False;
  End;
 End;

 { rectangle parametrique CorelDRAW 6 : largeur, hauteur (signees), rayon }
 Procedure RectPath(W,H,R:LongInt);
 Var SX,SY,KX,KY:LongInt;
 Begin
  If W=0 Then Exit;
  If H=0 Then Exit;
  If W<0 Then SX:=-1 Else SX:=1;
  If H<0 Then SY:=-1 Else SY:=1;
  R:=Abs(R);
  If R>Abs(W) Div 2 Then R:=Abs(W) Div 2;
  If R>Abs(H) Div 2 Then R:=Abs(H) Div 2;
  If R<=0 Then Begin
   PathPt(0,0,0);
   PathPt(W,0,$40);
   PathPt(W,H,$40);
   PathPt(0,H,$40);
   PathPt(0,0,$48);
  End
   Else Begin
    KX:=Round(R*0.4477)*SX;
    KY:=Round(R*0.4477)*SY;
    R:=R*1;
    PathPt(R*SX,0,0);
    PathPt(W-R*SX,0,$40);
    PathPt(W-KX,0,$C0); PathPt(W,KY,$C0); PathPt(W,R*SY,$80);
    PathPt(W,H-R*SY,$40);
    PathPt(W,H-KY,$C0); PathPt(W-KX,H,$C0); PathPt(W-R*SX,H,$80);
    PathPt(R*SX,H,$40);
    PathPt(KX,H,$C0); PathPt(0,H-KY,$C0); PathPt(0,H-R*SY,$80);
    PathPt(0,R*SY,$40);
    PathPt(0,KY,$C0); PathPt(KX,0,$C0); PathPt(R*SX,0,$88);
   End;
 End;

 { ellipse parametrique : centre a l'origine, rayons RX et RY }
 Procedure EllipsePath(RX,RY:LongInt);
 Var KX,KY:LongInt;
 Begin
  If(RX=0)or(RY=0)Then Exit;
  KX:=Round(RX*0.5523);
  KY:=Round(RY*0.5523);
  PathPt(RX,0,0);
  PathPt(RX,KY,$C0); PathPt(KX,RY,$C0); PathPt(0,RY,$80);
  PathPt(-KX,RY,$C0); PathPt(-RX,KY,$C0); PathPt(-RX,0,$80);
  PathPt(-RX,-KY,$C0); PathPt(-KX,-RY,$C0); PathPt(0,-RY,$80);
  PathPt(KX,-RY,$C0); PathPt(RX,-KY,$C0); PathPt(RX,0,$88);
 End;

Begin
 If C9Old Then Begin
  Kind:=D16(PendBody+8);
  NArg:=D16(PendBody+2);
  OffT:=D16(PendBody+4);
 End
  Else Begin
   Kind:=D32(PendBody+16);
   NArg:=D32(PendBody+4);
   OffT:=D32(PendBody+8);
  End;
 If(NArg<1)or(NArg>60)Then Exit;
 { bitmap : image decodee a l'emplacement du cadre, sinon cadre en trame grise }
 If Kind=5 Then Begin
  If BBoxOk Then Begin
   { le cadre englobant d'un bitmap est deja exprime apres transformation }
   HaveTrf:=False;
   LocalToWorld(BB1X,BB1Y,X1,Y1);
   LocalToWorld(BB2X,BB2Y,X2,Y2);
   Obj:=NewObj(K_BITMAP,2);
   Obj^.Closed:=True;
   Obj^.Pts^[0].X:=X1;
   Obj^.Pts^[0].Y:=Y1;
   Obj^.Pts^[1].X:=X2;
   Obj^.Pts^[1].Y:=Y2;
   ObjNormalize2(Obj);
   Obj^.FillKind:=FK_PATTERN;
   Obj^.Pattern:=8;
   Obj^.FillCol:=8;
   Obj^.FillCol2:=15;
   Obj^.OutCol:=8;
   Obj^.OutW:=1;
   Obj^.Group:=CurGroup;
   { l'argument du bitmap rappelle sa largeur et sa hauteur d'origine }
   If Not C9Old Then
    For I:=0 To NArg-1 Do
     If Obj^.Img=0 Then Begin
      Q:=D32(PendBody+OffT+4*I);
      If(Q>=0)and(Q+44<=PendSz)Then
       Obj^.Img:=ImgOfDims(D32(PendBody+Q+36),D32(PendBody+Q+40));
     End;
   If Obj^.Img>0 Then Begin
    Obj^.FillKind:=FK_SOLID;
    Obj^.FillCol:=NearestColor(Imgs[Obj^.Img]^.AR,Imgs[Obj^.Img]^.AG,Imgs[Obj^.Img]^.AB);
    Obj^.OutCol:=-1;
    Dec(SkipBmp);
   End;
   If Not AddObj(Obj)Then C9Full:=True;
  End;
  Inc(SkipBmp);
  Exit;
 End;
 If(Kind=0)or(Kind=7)or(Kind=8)or(Kind=11)or(Kind=12)or(Kind=15)or(Kind=17)or
   (Kind=23)or(Kind=28)Then Exit;
 For I:=0 To NArg-1 Do
  If C9Old Then Offs[I]:=D16(PendBody+OffT+2*I) Else Offs[I]:=D32(PendBody+OffT+4*I);
 PtsOff:=0; PtsN:=0;
 BestEx:=-1;
 RectArg:=0; EllArg:=0;
 FxSkip:=False;
 FillId:=-1;
 OutlId:=-1;
 For I:=0 To NArg-1 Do Begin
  If I<NArg-1 Then Len:=Offs[I+1]-Offs[I] Else Len:=PendSz-Offs[I];
  If Len=4 Then Begin
   V:=D32(PendBody+Offs[I]);
   If OwnExport Then Slot:=-1 Else Slot:=FindFill(V);
   If(Slot>=0)and(FillId<0)Then FillId:=Slot
    Else If OwnExport Then Begin End
    Else Begin
     Slot:=FindOutl(V);
     If(Slot>=0)and(OutlId<0)Then OutlId:=Slot
      Else Begin
       { cle de style -> identifiant }
       For K:=0 To SNF-1 Do
        If(SKeyF[K]=V)and(FillId<0)Then FillId:=FindFill(SValF[K]);
       For K:=0 To SNO-1 Do
        If(SKeyO[K]=V)and(OutlId<0)Then OutlId:=FindOutl(SValO[K]);
      End;
    End;
  End
   Else Begin
    Ex:=PtsExtra(PendBody+Offs[I],Len,Q);
    If(Ex>=0)and((BestEx<0)or(Ex<BestEx))Then Begin
     BestEx:=Ex;
     PtsOff:=PendBody+Offs[I];
     PtsN:=Q;
    End;
    If(Len=56)and(D32(PendBody+Offs[I])=4)Then FxSkip:=True;
    If(Len=6)and C9Old and(Kind=1)and(RectArg=0)Then RectArg:=PendBody+Offs[I];
    If(Len=10)and C9Old and(Kind=2)and(EllArg=0)Then EllArg:=PendBody+Offs[I];
    If(Len=12)and(Kind=1)and(RectArg=0)Then RectArg:=PendBody+Offs[I];
    If(Len=20)and(Kind=2)and(EllArg=0)Then EllArg:=PendBody+Offs[I];
   End;
 End;
 { objets d'effet (lentille, ombre...) : non representes }
 If FxSkip Then Begin
  Inc(SkipFx);
  Exit;
 End;
 { Styles ecrits par ce programme : arguments de style 3000+ }
 If(FillId<0)and(OutlId<0)and(StyLen>0)Then
  For I:=0 To NArg-1 Do Begin
   If I<NArg-1 Then Len:=Offs[I+1]-Offs[I] Else Len:=PendSz-Offs[I];
   If Len=4 Then Begin
    V:=D32(PendBody+Offs[I]);
    If OwnExport and(V>=3100)Then Begin
     Q:=StyOff;
     While Q+33<=StyOff+StyLen Do Begin
      If(D32(Q)=1)and(D32(Q+4)=V)and(D32(Q+8)=3000)Then Begin
       Key:=D32(Q+25);
       For K:=0 To SNF-1 Do If SKeyF[K]=Key Then FillId:=FindFill(SValF[K]);
       Key:=D32(Q+29);
       For K:=0 To SNO-1 Do If SKeyO[K]=Key Then OutlId:=FindOutl(SValO[K]);
       Break;
      End;
      Inc(Q);
     End;
    End;
   End;
  End;
 { Style de l'objet }
 tFillKind:=FK_NONE; tF1:=-1; tF2:=15;
 tGX:=0; tGY:=0;
 tImg:=0; tTW:=0; tTH:=0;
 If FillId>=0 Then Begin
  tFillKind:=FillTab^[FillId].Kind;
  tGX:=FillTab^[FillId].GX;
  tGY:=FillTab^[FillId].GY;
  tF1:=FillTab^[FillId].C1;
  tF2:=FillTab^[FillId].C2;
  If tF1<0 Then tFillKind:=FK_NONE;
  { motif ou texture : bitmap pave sur l'objet }
  If tFillKind=FK_IMAGE Then Begin
   tImg:=ImgOfBmp(FillTab^[FillId].Bmp);
   If tImg>0 Then Begin
    tTW:=Clamp(Round(FillTab^[FillId].TW*CoordK),20,32000);
    tTH:=Clamp(Round(FillTab^[FillId].TH*CoordK),20,32000);
    If FillTab^[FillId].TW<=0 Then tTW:=500;
    If FillTab^[FillId].TH<=0 Then tTH:=500;
    tF1:=NearestColor(Imgs[tImg]^.AR,Imgs[tImg]^.AG,Imgs[tImg]^.AB);
   End
    Else Begin
     tFillKind:=FK_SOLID;
     tF1:=7;
    End;
  End;
  { remplissage a transparence / lentille : non represente }
  If FillTab^[FillId].Special Then Begin
   tFillKind:=FK_NONE;
   tF1:=-1;
   If OutlId<0 Then Begin
    Inc(SkipFx);
    Exit;
   End;
  End;
 End;
 tOut:=-1; tW:=1;
 If OutlId>=0 Then Begin
  If OutlTab^[OutlId].W>0 Then Begin
   tOut:=OutlTab^[OutlId].C;
   tW:=OutlTab^[OutlId].W Div 1000;
   If tW<1 Then tW:=1;
   If tW>200 Then tW:=200;
  End;
 End
  Else
 If tFillKind=FK_NONE Then tOut:=0;
 tGroup:=CurGroup;
 If(Kind=4)or(Kind=6)Then Begin
  EmitText(Kind);
  Exit;
 End;
 { Parcours du chemin }
 CompCnt:=0;
 CompN:=0;
 SubN:=0;
 SubAllLines:=True;
 SubClosed:=False;
 PendCnt:=0;
 If PtsN>0 Then Begin
  If C9Old Then Begin
   For I:=0 To PtsN-1 Do
    PathPt(D16s(PtsOff+4+4*I),D16s(PtsOff+6+4*I),Dat^[PtsOff+4+4*PtsN+I]);
  End
   Else
  For I:=0 To PtsN-1 Do
   PathPt(D32(PtsOff+4+8*I),D32(PtsOff+8+8*I),Dat^[PtsOff+4+8*PtsN+I]);
 End
  Else
 If(RectArg>0)and C9Old Then RectPath(D16s(RectArg),D16s(RectArg+2),D16s(RectArg+4))
  Else
 If(EllArg>0)and C9Old Then EllipsePath(Abs(D16s(EllArg)),Abs(D16s(EllArg+2)))
  Else
 If RectArg>0 Then RectPath(D32(RectArg),D32(RectArg+4),D32(RectArg+8))
  Else
 If EllArg>0 Then EllipsePath(Abs(D32(EllArg)),Abs(D32(EllArg+4)))
  Else Begin
   Inc(SkipOther);
   Exit;
  End;
 SubFlush;
 CompFlush;
 T:=0;
End;

{ ------------------------- Parcours des chunks --------------------- }

Procedure C9Walk(Pos,EndPos:LongInt;Parent,Grand:String;Pass:Integer);Forward;

Procedure C9Chunk(Tag:String;B,Sz:LongInt;Parent,Grand:String;Pass:Integer);
Var Kind:LongInt;
    I,K,PgOff:Integer;
Begin
 If(Tag='bmp ')and(Parent='bmpt')and(Pass<=0)Then DecodeBmp(B,Sz);
 If Pass<0 Then Exit;
 If Pass=0 Then Begin
  If Tag='mcfg' Then Begin
   OwnExport:=D32(B)=8;
   { CorelDRAW 6 : dimensions de la page en +28/+32 ; versions 7 a 9 : +4/+8 }
   If C9Old Then Begin
    If(D16(B)>=1000)and(D16(B+2)>=1000)Then Begin
     PageW:=Round(D16(B)*0.254);
     PageH:=Round(D16(B+2)*0.254);
    End;
    Exit;
   End;
   If C9Ver<=6 Then PgOff:=28 Else PgOff:=4;
   If(D32(B+PgOff)>=500000)and(D32(B+PgOff)<=200000000)and
     (D32(B+PgOff+4)>=500000)and(D32(B+PgOff+4)<=200000000)Then Begin
    PageW:=D32(B+PgOff) Div 1000;
    PageH:=D32(B+PgOff+4) Div 1000;
   End;
  End
   Else
  If(Tag='fild')or(Tag='fill')Then ReadFild(B,Sz)
   Else
  If Tag='outl' Then ReadOutl(B,Sz);
  Exit;
 End;
 If(Tag='flgs')and(Parent='page')Then Begin
  If(D32(B) And $10000)<>0 Then CurPageSkip:=True;
 End
  Else
 If(Tag='txsm')and(Parent='obj ')Then Begin
  TxsmOff:=B;
  TxsmSz:=Sz;
  TxsmOk:=True;
 End
  Else
 If(Tag='bbox')and(Parent='obj ')and(Sz>=16)Then Begin
  BB1X:=D32(B);
  BB1Y:=D32(B+4);
  BB2X:=D32(B+8);
  BB2Y:=D32(B+12);
  BBoxOk:=True;
 End
  Else
 If(Tag='loda')and(Parent='lgob')Then Begin
  If C9Old Then Kind:=D16(B+8) Else Kind:=D32(B+16);
  If Grand='layr' Then
   SkipLayer:=(Kind=11)or(Kind=12)or(Kind=17)
  Else
  If(Grand='obj ')and Not CurPageSkip and(PagesDone=0)and Not SkipLayer Then Begin
   PendBody:=B;
   PendSz:=Sz;
   PendValid:=True;
   HaveTrf:=False;
  End;
 End
  Else
 If(Tag='trfd')and(Parent='trfl')and PendValid Then Begin
  { les 6 coefficients suivent 8 octets apres le debut du premier argument }
  If C9Old Then Begin
   I:=D16(B+10);
   If(I>=12)and(I+2+48<=Sz)Then Begin
    For K:=0 To 5 Do Trf[K]:=DDbl(B+I+2+8*K);
    HaveTrf:=True;
   End;
  End
   Else Begin
    I:=D32(B+16);
    If(I>=16)and(I+8+48<=Sz)Then Begin
     For K:=0 To 5 Do Trf[K]:=DDbl(B+I+8+8*K);
     HaveTrf:=True;
    End;
   End;
 End;
End;

Procedure C9List(LT:String;Pos,Sz:LongInt;Parent:String;Pass:Integer);
Var Descend:Boolean;
    SaveGroup:Integer;
Begin
 Descend:=False;
 If Pass<0 Then Descend:=(LT='bmpt')
  Else
 If Pass=0 Then Begin
  If(LT='stlt')and(C9Ver>6)Then ReadStyles(Pos+12,Sz-4);
  Descend:=(LT='doc ')or(LT='filt')or(LT='filc')or(LT='otlt')or(LT='bmpt');
 End
  Else
 Descend:=(LT='page')or(LT='gobj')or(LT='layr')or(LT='lgob')or(LT='obj ')or
          (LT='grp ')or(LT='trfl')or(LT='lnkg');
 If Not Descend Then Exit;
 SaveGroup:=CurGroup;
 If Pass=1 Then Begin
  If LT='page' Then CurPageSkip:=False;
  If LT='layr' Then SkipLayer:=False;
  If LT='obj ' Then Begin
   PendValid:=False;
   TxsmOk:=False;
   BBoxOk:=False;
  End;
  If(LT='grp ')or(LT='lnkg')Then Begin
   Inc(GroupSeq);
   CurGroup:=GroupSeq;
  End;
 End;
 C9Walk(Pos+12,Pos+8+Sz,LT,Parent,Pass);
 If Pass=1 Then Begin
  If(LT='obj ')and PendValid Then Begin
   EmitObject;
   PendValid:=False;
  End;
  If(LT='grp ')or(LT='lnkg')Then CurGroup:=SaveGroup;
  If(LT='page')Then Begin
   If Not CurPageSkip Then Inc(PagesDone);
  End;
 End;
End;

Procedure C9Walk(Pos,EndPos:LongInt;Parent,Grand:String;Pass:Integer);
Var Tag:String;
    Idx,Sz:LongInt;
Begin
 While(Pos+8<=EndPos)and Not C9Full Do Begin
  Tag:=TagAt(Pos);
  Idx:=D32(Pos+4);
  If(BlkN>0)and(Idx>=0)and(Idx<BlkN)Then Sz:=Blk^[Idx] Else Sz:=Idx;
  If(Sz<0)or(Pos+8+Sz>DatLen)Then Break;
  If Tag='LIST' Then Begin
   C9List(TagAt(Pos+8),Pos,Sz,Parent,Pass);
   Pos:=Pos+8+Sz;
  End
   Else Begin
    C9Chunk(Tag,Pos+8,Sz,Parent,Grand,Pass);
    Pos:=Pos+8+Sz+(Sz And 1);
   End;
 End;
End;

{ Analyse d'un jeu de donnees (deja decomprime) }
Procedure C9Process;
Var Pass:Integer;
Begin
 For Pass:=-1 To 1 Do Begin
  PendValid:=False;
  CurGroup:=0;
  C9Walk(0,DatLen,'','',Pass);
 End;
End;

{ ------------------------------------------------------------------ }
{ Decompression KWAJ (fichiers "xxx.CD_" des disquettes CorelDRAW 5)  }
{ Methodes 0 (copie), 1 (XOR 0xFF), 2 (SZDD) et 3 (LZ + Huffman).     }
{ ------------------------------------------------------------------ }

Type
 TKBuf=Array[0..1999999999] of Byte;
 PKBuf=^TKBuf;
 TKHuff=Record
  Cnt:Array[0..15] of LongInt;
  Sym:Array[0..255] of Integer;
 End;

Var
 KIn:PKBuf;
 KInLen,KBitPos,KBitEnd:LongInt;
 KBad,KEnd:Boolean;
 KOut:PKBuf;
 KOutLen,KOutCap:LongInt;

Function KBits(N:Integer):LongInt;
Var V:LongInt;
    I:Integer;
    P:LongInt;
Begin
 V:=0;
 For I:=1 To N Do Begin
  P:=KBitPos;
  If P>=KBitEnd Then Begin
   KEnd:=True;
   V:=V Shl 1;
  End
   Else V:=(V Shl 1)Or((KIn^[P Shr 3] Shr (7-(P And 7)))And 1);
  Inc(KBitPos);
 End;
 KBits:=V;
End;

Procedure KPut(B:Byte);
Var P:PKBuf;
Begin
 If KOutLen>=KOutCap Then Begin
  GetMem(P,KOutCap*2);
  Move(KOut^,P^,KOutLen);
  FreeMem(KOut,KOutCap);
  KOut:=P;
  KOutCap:=KOutCap*2;
 End;
 KOut^[KOutLen]:=B;
 Inc(KOutLen);
End;

{ Table de Huffman canonique : codes croissants par longueur puis par symbole }
Procedure KBuild(Var H:TKHuff;Var L:Array of Byte;N:Integer);
Var I,Len:Integer;
    Offs:Array[0..16] of Integer;
Begin
 For I:=0 To 15 Do H.Cnt[I]:=0;
 For I:=0 To N-1 Do Inc(H.Cnt[L[I]]);
 H.Cnt[0]:=0;
 Offs[1]:=0;
 For Len:=1 To 15 Do Offs[Len+1]:=Offs[Len]+H.Cnt[Len];
 For I:=0 To N-1 Do
  If L[I]<>0 Then Begin
   H.Sym[Offs[L[I]]]:=I;
   Inc(Offs[L[I]]);
  End;
End;

Function KSym(Var H:TKHuff):Integer;
Var Code,First,Index,Count:LongInt;
    Len:Integer;
Begin
 Code:=0; First:=0; Index:=0;
 For Len:=1 To 15 Do Begin
  Code:=Code Or KBits(1);
  Count:=H.Cnt[Len];
  If Code-Count<First Then Begin
   KSym:=H.Sym[Index+(Code-First)];
   Exit;
  End;
  Index:=Index+Count;
  First:=(First+Count) Shl 1;
  Code:=Code Shl 1;
 End;
 KBad:=True;
 KSym:=0;
End;

Procedure KReadLens(TypeV,N:Integer;Var L:Array of Byte);
Var I,C,Sel:Integer;
Begin
 C:=0;
 Case TypeV Of
  0:Begin
   Case N Of
    16:C:=4;
    32:C:=5;
    64:C:=6;
    256:C:=8;
   End;
   For I:=0 To N-1 Do L[I]:=C;
  End;
  1:Begin
   C:=KBits(4);
   L[0]:=C;
   For I:=1 To N-1 Do Begin
    Sel:=KBits(1);
    If Sel=0 Then L[I]:=C
     Else Begin
      Sel:=KBits(1);
      If Sel=0 Then Begin
       Inc(C);
       L[I]:=C;
      End
       Else Begin
        C:=KBits(4);
        L[I]:=C;
       End;
     End;
   End;
  End;
  2:Begin
   C:=KBits(4);
   L[0]:=C;
   For I:=1 To N-1 Do Begin
    Sel:=KBits(2);
    If Sel=3 Then C:=KBits(4)
     Else C:=C+Sel-1;
    L[I]:=C And 15;
   End;
  End;
 Else
  For I:=0 To N-1 Do L[I]:=KBits(4);
 End;
End;

{ Methode 3 : LZ (fenetre de 4096 octets) + Huffman }
Procedure KwajLZH;
Var Win:Array[0..4095] of Byte;
    Types:Array[0..5] of Integer;
    L1,L2,L3,L4,L5:Array[0..255] of Byte;
    H1,H2,H3,H4,H5:TKHuff;
    I,J,Len,Offset,Pos,Sym,LitRun:Integer;
Begin
 FillChar(Win,SizeOf(Win),32);
 For I:=0 To 5 Do Types[I]:=KBits(4);
 KReadLens(Types[0],16,L1); KBuild(H1,L1,16);
 KReadLens(Types[1],16,L2); KBuild(H2,L2,16);
 KReadLens(Types[2],32,L3); KBuild(H3,L3,32);
 KReadLens(Types[3],64,L4); KBuild(H4,L4,64);
 KReadLens(Types[4],256,L5); KBuild(H5,L5,256);
 Pos:=0;
 LitRun:=0;
 While Not KBad Do Begin
  If LitRun<>0 Then Len:=KSym(H2) Else Len:=KSym(H1);
  If KEnd Then Exit;
  If Len>0 Then Begin
   Inc(Len,2);
   LitRun:=0;
   J:=KSym(H4);
   Offset:=J Shl 6;
   Offset:=Offset Or KBits(6);
   If KEnd Then Exit;
   While Len>0 Do Begin
    Win[Pos]:=Win[(Pos+4096-Offset)And 4095];
    KPut(Win[Pos]);
    Pos:=(Pos+1)And 4095;
    Dec(Len);
   End;
  End
   Else Begin
    Len:=KSym(H3)+1;
    If KEnd Then Exit;
    If Len=32 Then LitRun:=0 Else LitRun:=1;
    While Len>0 Do Begin
     Sym:=KSym(H5);
     If KEnd Then Exit;
     Win[Pos]:=Sym;
     KPut(Sym);
     Pos:=(Pos+1)And 4095;
     Dec(Len);
    End;
   End;
 End;
End;

{ Decompresse un fichier KWAJ place en memoire ; retourne False si le
  format n'est pas reconnu. Le resultat est dans KOut/KOutLen. }
Function KwajExpand(Src:PKBuf;SrcLen:LongInt):Boolean;
Var Method,DataOff,Flags,I:LongInt;
Begin
 KwajExpand:=False;
 If SrcLen<14 Then Exit;
 If(Src^[0]<>Ord('K'))or(Src^[1]<>Ord('W'))or(Src^[2]<>Ord('A'))or(Src^[3]<>Ord('J'))Then Exit;
 Method:=Src^[8]+256*Src^[9];
 DataOff:=Src^[10]+256*Src^[11];
 Flags:=Src^[12]+256*Src^[13];
 If DataOff>=SrcLen Then Exit;
 KOutCap:=65536;
 GetMem(KOut,KOutCap);
 KOutLen:=0;
 KIn:=Src;
 KBad:=False;
 KEnd:=False;
 Case Method Of
  0:For I:=DataOff To SrcLen-1 Do KPut(Src^[I]);
  1:For I:=DataOff To SrcLen-1 Do KPut(Src^[I] Xor $FF);
  3:Begin
   KBitPos:=DataOff*8;
   KBitEnd:=SrcLen*8;
   KwajLZH;
  End;
 Else Begin
  FreeMem(KOut,KOutCap);
  KOut:=NIL;
  Exit;
 End;
 End;
 If Flags<>0 Then ;
 KwajExpand:=KOutLen>0;
End;

Function LoadCDR9(Const Name:String):Boolean;
Var F:File;
    Old:Byte;
    Pos,Sz,Total,P,Got,Chunk:LongInt;
    Cs,Us,Bi,Bu:LongInt;
    Body:LongInt;
    Ok:Boolean;
    LT:String;
    Tmp:PBig;
    TmpLen:LongInt;
    O1:PObj;
 Function F32(O:LongInt):LongInt;
 Begin
  F32:=LongInt(FileBuf^[O])Or(LongInt(FileBuf^[O+1])Shl 8)Or(LongInt(FileBuf^[O+2])Shl 16)Or(LongInt(FileBuf^[O+3])Shl 24);
 End;
Begin
 LoadCDR9:=False;
 C9Info:='';
 Old:=FileMode;
 FileMode:=0;
 Assign(F,Name);
 {$I-}Reset(F,1);{$I+}
 FileMode:=Old;
 If IOResult<>0 Then Exit;
 Total:=FileSize(F);
 If(Total<32)or(Total>200000000)Then Begin
  Close(F);
  Exit;
 End;
 GetMem(FileBuf,Total);
 P:=0;
 While P<Total Do Begin
  Chunk:=Total-P;
  If Chunk>32000 Then Chunk:=32000;
  {$I-}BlockRead(F,FileBuf^[P],Chunk,Got);{$I+}
  If(IOResult<>0)or(Got<=0)Then Break;
  Inc(P,Got);
 End;
 Close(F);
 If P<Total Then Begin
  FreeMem(FileBuf,Total);
  Exit;
 End;
 { fichier comprime KWAJ (xxx.CD_ des disquettes d'installation) }
 If(FileBuf^[0]=Ord('K'))and(FileBuf^[1]=Ord('W'))and(FileBuf^[2]=Ord('A'))and(FileBuf^[3]=Ord('J'))Then Begin
  If KwajExpand(PKBuf(FileBuf),Total)Then Begin
   FreeMem(FileBuf,Total);
   Total:=KOutLen;
   GetMem(FileBuf,Total);
   Move(KOut^,FileBuf^,Total);
   FreeMem(KOut,KOutCap);
   KOut:=NIL;
  End
   Else Begin
    FreeMem(FileBuf,Total);
    Exit;
   End;
 End;
 If(Total<32)or(Chr(FileBuf^[0])+Chr(FileBuf^[1])+Chr(FileBuf^[2])+Chr(FileBuf^[3])<>'RIFF')Then Begin
  FreeMem(FileBuf,Total);
  Exit;
 End;
 New(FillTab);
 New(OutlTab);
 FillChar(FillTab^,SizeOf(FillTab^),0);
 FillChar(OutlTab^,SizeOf(OutlTab^),0);
 SNF:=0; SNO:=0; StyOff:=0; StyLen:=0;
 OwnExport:=False;
 C9Ver:=9;
 If(Chr(FileBuf^[11])>='4')and(Chr(FileBuf^[11])<='9')Then C9Ver:=Ord(FileBuf^[11])-48;
 C9Old:=C9Ver<=5;
 If C9Old Then CoordK:=0.254 Else CoordK:=0.001;
 NewDocument;
 PagesDone:=0; CurPageSkip:=False; SkipLayer:=False; C9Full:=False;
 SkipText:=0; SkipBmp:=0; SkipOther:=0; SkipFx:=0;
 Ok:=False;
 BmpN:=0;
 Pos:=12;
 While Pos+8<=Total Do Begin
  Sz:=F32(Pos+4);
  If(Sz<0)or(Pos+8+Sz>Total)Then Break;
  If(Chr(FileBuf^[Pos])+Chr(FileBuf^[Pos+1])+Chr(FileBuf^[Pos+2])+Chr(FileBuf^[Pos+3])='LIST')and(Pos+16<=Total)Then Begin
   LT:=Chr(FileBuf^[Pos+8])+Chr(FileBuf^[Pos+9])+Chr(FileBuf^[Pos+10])+Chr(FileBuf^[Pos+11]);
   If LT='cmpr' Then Begin
    Body:=Pos+12;
    If Sz>=20 Then Begin
     Cs:=F32(Body);
     Us:=F32(Body+4);
     Bi:=F32(Body+8);
     Bu:=F32(Body+12);
     If(Us>0)and(Us<400000000)and(Cs>8)and(Body+16+Cs<=Pos+8+Sz)Then Begin
      GetMem(Dat,Us);
      DatLen:=Us;
      BlkN:=0;
      Blk:=NIL;
      Tmp:=@FileBuf^[Body+24];
      If Inflate(Tmp,Cs-8,Dat,Us)Then Begin
       If(Bi>8)and(Bu>=4)and(Body+16+Cs+Bi<=Pos+8+Sz+1)Then Begin
        GetMem(Blk,Bu);
        Tmp:=@FileBuf^[Body+16+Cs+8];
        If Inflate(Tmp,Bi-8,PBig(Blk),Bu)Then BlkN:=Bu Div 4;
       End;
       If BlkN>0 Then Begin
        C9Process;
        Ok:=True;
       End;
       If Blk<>NIL Then FreeMem(Blk,Bu);
       Blk:=NIL;
      End;
      FreeMem(Dat,Us);
      Dat:=NIL;
     End;
    End;
   End
    Else Begin
     { liste non comprimee (anciennes versions) : tailles litterales }
     Dat:=FileBuf;
     DatLen:=Total;
     BlkN:=0;
     Blk:=NIL;
     If LT='bmpt' Then C9Walk(Pos,Pos+8+Sz,'','',-1);
     If(LT='doc ')or(LT='page')Then Begin
      PendValid:=False;
      For Chunk:=0 To 1 Do Begin
       CurGroup:=0;
       C9Walk(Pos,Pos+8+Sz,'','',Chunk);
      End;
      Ok:=True;
     End;
    End;
  End;
  Pos:=Pos+8+Sz+(Sz And 1);
 End;
 Dispose(FillTab);
 Dispose(OutlTab);
 FreeMem(FileBuf,Total);
 FileBuf:=NIL;
 If Ok Then Begin
  { le fichier range les objets du premier plan vers l'arriere-plan }
  ListReverse;
  C9Info:=IStr(ObjCount)+' objets';
  If SkipText>0 Then C9Info:=C9Info+', '+IStr(SkipText)+' textes ignorés';
  If ImgCount>0 Then C9Info:=C9Info+', '+IStr(ImgCount)+' images décodées';
  If SkipBmp>0 Then C9Info:=C9Info+', '+IStr(SkipBmp)+' bitmaps remplacés par un cadre';
  If SkipFx>0 Then C9Info:=C9Info+', '+IStr(SkipFx)+' effets ignorés';
  If SkipOther>0 Then C9Info:=C9Info+', '+IStr(SkipOther)+' objets non reconnus';
  If C9Full Then C9Info:=C9Info+' (limite atteinte)';
  Modified:=False;
 End;
 LoadCDR9:=Ok;
End;
{$ENDIF}

{ ------------------------------------------------------------------ }
{ Exemples de dessins (generes sans interface graphique)            }
{ ------------------------------------------------------------------ }

Function Mk(Kind:Byte;N:Integer;Out,Fill:Integer;W:LongInt):PObj;
Var O:PObj;
Begin
 O:=NewObj(Kind,N);
 O^.OutCol:=Out;
 O^.OutW:=W;
 If Fill>=0 Then Begin
  O^.FillCol:=Fill;
  O^.FillKind:=FK_SOLID;
 End
  Else
 Begin
  O^.FillCol:=-1;
  O^.FillKind:=FK_NONE;
 End;
 Mk:=O;
End;

Procedure SRect(X1,Y1,X2,Y2:LongInt;Out,Fill:Integer;W:LongInt);
Var O:PObj;
Begin
 O:=Mk(K_RECT,2,Out,Fill,W);
 O^.Pts^[0].X:=X1; O^.Pts^[0].Y:=Y1;
 O^.Pts^[1].X:=X2; O^.Pts^[1].Y:=Y2;
 O^.Closed:=True;
 AddObj(O);
End;

Procedure SEllipse(X1,Y1,X2,Y2:LongInt;Out,Fill:Integer;W:LongInt);
Var O:PObj;
Begin
 O:=Mk(K_ELLIPSE,2,Out,Fill,W);
 O^.Pts^[0].X:=X1; O^.Pts^[0].Y:=Y1;
 O^.Pts^[1].X:=X2; O^.Pts^[1].Y:=Y2;
 O^.Closed:=True;
 AddObj(O);
End;

Procedure SLine(X1,Y1,X2,Y2:LongInt;Out:Integer;W:LongInt);
Var O:PObj;
Begin
 O:=Mk(K_LINE,2,Out,-1,W);
 O^.Pts^[0].X:=X1; O^.Pts^[0].Y:=Y1;
 O^.Pts^[1].X:=X2; O^.Pts^[1].Y:=Y2;
 AddObj(O);
End;

Procedure SText(X,Y,Size:LongInt;Const S:String;Col:Integer);
Var O:PObj;
Begin
 O:=Mk(K_TEXT,1,Col,Col,1);
 O^.Pts^[0].X:=X; O^.Pts^[0].Y:=Y;
 O^.TextSize:=Size;
 O^.Txt:=Copy(S,1,60);
 AddObj(O);
End;

Procedure SShape(O:PObj;Out,Fill:Integer;W:LongInt);
Begin
 O^.OutCol:=Out;
 O^.OutW:=W;
 If Fill>=0 Then Begin
  O^.FillCol:=Fill;
  O^.FillKind:=FK_SOLID;
 End;
 AddObj(O);
End;

Function LastObj:PObj;
Begin
 LastObj:=ObjTail;
End;

Procedure SampleLogo;
Var O:PObj;
Begin
 NewDocument;
 PageW:=2970;
 PageH:=2100;
 SRect(0,0,2970,2100,-1,15,1);
 With LastObj^ Do Begin FillKind:=FK_GRADV; FillCol:=1; FillCol2:=11; End;
 SEllipse(1000,500,1970,1470,15,14,30);
 LastObj^.Shadow:=True;
 SShape(MakeRegular(1485,985,360,360,5,True),4,12,20);
 SText(560,1620,260,'CLONEDRAW',15);
 SText(940,1900,100,'Dessin vectoriel',14);
 SLine(300,1500,2670,1500,14,10);
End;

Procedure SampleShapes;
Var O:PObj;
    P:Array[0..4] of TPt;
Begin
 NewDocument;
 PageW:=2970;
 PageH:=2100;
 SText(300,100,180,'Formes de base',0);
 SRect(300,400,1000,800,0,9,10);
 SEllipse(1200,400,1900,800,0,10,10);
 SShape(MakeRegular(2400,600,350,230,6,False),0,12,10);
 SShape(MakeRegular(650,1200,300,280,5,True),0,14,10);
 SLine(1100,1000,1900,1450,4,40);
 O:=Mk(K_POLYLINE,5,1,-1,20);
 O^.Pts^[0].X:=2100; O^.Pts^[0].Y:=1000;
 O^.Pts^[1].X:=2300; O^.Pts^[1].Y:=1450;
 O^.Pts^[2].X:=2400; O^.Pts^[2].Y:=1050;
 O^.Pts^[3].X:=2600; O^.Pts^[3].Y:=1500;
 O^.Pts^[4].X:=2800; O^.Pts^[4].Y:=1000;
 AddObj(O);
 P[0].X:=300; P[0].Y:=1850;
 P[1].X:=800; P[1].Y:=1600;
 P[2].X:=1300; P[2].Y:=1950;
 P[3].X:=1800; P[3].Y:=1650;
 P[4].X:=2300; P[4].Y:=1900;
 O:=MakeSmoothCurve(P,5);
 O^.OutCol:=5;
 O^.OutW:=30;
 AddObj(O);
 SText(2350,1700,110,'Texte',4);
End;

Procedure SampleFills;
Var I:Integer;
    O:PObj;
Begin
 NewDocument;
 SText(300,150,180,'Remplissages',0);
 SRect(300,500,1000,1000,0,12,10);
 LastObj^.FillKind:=FK_GRADV; LastObj^.FillCol:=12; LastObj^.FillCol2:=14;
 SRect(1100,500,1800,1000,0,1,10);
 LastObj^.FillKind:=FK_GRADH; LastObj^.FillCol:=1; LastObj^.FillCol2:=15;
 For I:=1 To 8 Do Begin
  SRect(300+((I-1) Mod 4)*450,1200+((I-1) Div 4)*450,650+((I-1) Mod 4)*450,
        1550+((I-1) Div 4)*450,0,4,10);
  LastObj^.FillKind:=FK_PATTERN;
  LastObj^.Pattern:=I;
  LastObj^.FillCol:=1;
  LastObj^.FillCol2:=15;
 End;
 SEllipse(300,2300,900,2800,0,9,10);
 LastObj^.Extrude:=True;
 SEllipse(1200,2300,1800,2800,0,11,10);
 LastObj^.Shadow:=True;
End;

Procedure SampleCard;
Begin
 NewDocument;
 PageW:=1100;
 PageH:=650;
 SRect(0,0,1100,650,-1,15,1);
 SRect(0,0,1100,160,-1,1,1);
 LastObj^.FillKind:=FK_GRADH; LastObj^.FillCol:=1; LastObj^.FillCol2:=9;
 SText(60,40,80,'GLADIR INFORMATIQUE',15);
 SText(60,260,70,'Sylvain Maltais',0);
 SText(60,350,45,'Developpeur',8);
 SText(60,470,40,'support@gladir.com',1);
 SText(60,530,40,'www.gladir.com',1);
 SEllipse(860,230,1020,390,1,14,10);
 SShape(MakeRegular(940,310,60,60,5,True),4,12,5);
End;

Procedure MakeSamples;
Var Dir:String;
 Procedure Save(Const N:String);
 Begin
  If SaveCDR(Dir+N+'.CDR')Then WriteLn('  ',Dir,N,'.CDR')
   Else WriteLn('  Erreur : ',Dir,N,'.CDR');
 End;
Begin
 Dir:='SAMPLES\CORELDRAW\';
 {$I-}MkDir('SAMPLES');{$I+}
 If IOResult<>0 Then ;
 {$I-}MkDir('SAMPLES\CORELDRAW');{$I+}
 If IOResult<>0 Then ;
 WriteLn('Generation des exemples :');
 SampleLogo;   Save('LOGO');
 DocName:='LOGO.SVG';
 If SaveSVG(Dir+'LOGO.SVG')Then WriteLn('  ',Dir,'LOGO.SVG');
 SampleShapes; Save('FORMES');
 SampleFills;  Save('FILLS');
 SampleCard;   Save('CARTE');
End;

{ ------------------------------------------------------------------ }
{ Souris et graphique                                                }
{ ------------------------------------------------------------------ }

Const
 UI_BG=7; UI_HI=15; UI_SH=8; UI_DK=0; UI_SEL=1;
 CANVAS_BG=39;
 DM_NONE=0; DM_MOVE=1; DM_SIZE=2; DM_MARQUEE=3; DM_CREATE=4; DM_NODE=5;
 DM_PAN=6; DM_ZBOX=7; DM_SCROLLH=8; DM_SCROLLV=9; DM_GUIDE=10;
 EXT_STEPS=8; EXT_STEP=18; SHADOW_OFF=70;

Var
 MX,MY,MB,OldMB:Integer;
 MouseHidden:Boolean;
 HWMap:Array[0..255] of Byte;
 PaletteY:Integer;
 StatusMsg:String;

{$IFDEF FPC}
Procedure MouseInit;
Begin
 PtcMouse.InitMouse;
End;

Procedure PollMouse;
Var X,Y,B:LongInt;
Begin
 PtcMouse.GetMouseState(X,Y,B);
 MX:=X; MY:=Y; MB:=B;
End;

Procedure RawShow;
Begin
 PtcMouse.ShowMouse;
End;

Procedure RawHide;
Begin
 PtcMouse.HideMouse;
End;
{$ELSE}
Procedure MouseInit;
Var R:Registers;
Begin
 R.AX:=0;
 Intr($33,R);
End;

Procedure PollMouse;
Var R:Registers;
Begin
 R.AX:=3;
 Intr($33,R);
 MB:=R.BX;
 MX:=R.CX;
 MY:=R.DX;
End;

Procedure RawShow;
Var R:Registers;
Begin
 R.AX:=1;
 Intr($33,R);
End;

Procedure RawHide;
Var R:Registers;
Begin
 R.AX:=2;
 Intr($33,R);
End;
{$ENDIF}

Procedure MouseOff;
Begin
 If Not MouseHidden Then Begin
  RawHide;
  MouseHidden:=True;
 End;
End;

Procedure MouseOn;
Begin
 If MouseHidden Then Begin
  RawShow;
  MouseHidden:=False;
 End;
End;

Procedure SetCol(C:Integer);
Begin
 If C<0 Then C:=0;
 If C>=PalUsed Then C:=0;
 SetColor(HWMap[C]);
End;

Procedure SetFillCol(C:Integer);
Begin
 If C<0 Then C:=0;
 If C>=PalUsed Then C:=0;
 SetFillStyle(SolidFill,HWMap[C]);
End;

Procedure CaptureGlyphs;
Var C,X,Y:Integer;
Begin
 FillChar(GlyphRows,SizeOf(GlyphRows),0);
 SetTextStyle(DefaultFont,HorizDir,1);
 For C:=32 To 255 Do Begin
  SetFillStyle(SolidFill,0);
  Bar(0,0,7,7);
  SetColor(15);
  OutTextXY(0,0,Chr(C));
  For Y:=0 To 7 Do
   For X:=0 To 7 Do
    If GetPixel(X,Y)=15 Then GlyphRows[C,Y]:=GlyphRows[C,Y] Or (1 Shl X);
 End;
 ClearDevice;
 GlyphsReady:=True;
End;

Procedure ApplyPalette;
Var I:Integer;
Begin
 For I:=0 To PalUsed-1 Do Begin
  {$IFDEF FPC}
  SetRGBPalette(I,PalR[I],PalG[I],PalB[I]);
  HWMap[I]:=I;
  {$ELSE}
  If I<16 Then HWMap[I]:=I
   Else HWMap[I]:=NearestColor16(PalR[I],PalG[I],PalB[I]);
  {$ENDIF}
 End;
 If ImgPalOn Then
  For I:=IMG_BASE To 255 Do Begin
   {$IFDEF FPC}
   SetRGBPalette(I,PalR[I],PalG[I],PalB[I]);
   HWMap[I]:=I;
   {$ELSE}
   HWMap[I]:=NearestColor16(PalR[I],PalG[I],PalB[I]);
   {$ENDIF}
  End;
 PalDirty:=False;
End;

Procedure InitGfx;
Var Driver,Mode,I:Integer;
Begin
 {$IFDEF FPC}
 Driver:=D8bit;
 Mode:=m640x480;
 {$ELSE}
 Driver:=Detect;
 Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 If GraphResult<>grOk Then Begin
  WriteLn('Erreur d''initialisation graphique !');
  Halt(1);
 End;
 ScreenW:=GetMaxX+1;
 ScreenH:=GetMaxY+1;
 ApplyPalette;
 GfxReady:=True;
 CaptureGlyphs;
 CanvasX:=TOOLBOX_W+RULER_SIZE;
 CanvasY:=PROPBAR_TOP+PROPBAR_H+RULER_SIZE;
 CanvasW:=ScreenW-CanvasX-SCROLL_W;
 PaletteY:=ScreenH-STATUS_H-PALETTE_H;
 CanvasH:=PaletteY-SCROLL_W-CanvasY;
End;

Procedure TxtOut(X,Y:Integer;Const S:String);
Begin
 SetTextStyle(DefaultFont,HorizDir,1);
 OutTextXY(X,Y,Conv(S));
End;

Function TxtW(Const S:String):Integer;
Begin
 TxtW:=Length(Conv(S))*8;
End;

Procedure Box(X1,Y1,X2,Y2,C:Integer);
Begin
 SetFillCol(C);
 Bar(X1,Y1,X2,Y2);
End;

Procedure Bevel(X1,Y1,X2,Y2:Integer;Raised:Boolean);
Begin
 If Raised Then SetCol(UI_HI) Else SetCol(UI_SH);
 Line(X1,Y1,X2-1,Y1);
 Line(X1,Y1,X1,Y2-1);
 If Raised Then SetCol(UI_SH) Else SetCol(UI_HI);
 Line(X2,Y1,X2,Y2);
 Line(X1,Y2,X2,Y2);
End;

Procedure Panel(X1,Y1,X2,Y2:Integer;Raised:Boolean);
Begin
 Box(X1,Y1,X2,Y2,UI_BG);
 Bevel(X1,Y1,X2,Y2,Raised);
End;

Function InRect(PXs,PYs,X,Y,W,H:Integer):Boolean;
Begin
 InRect:=(PXs>=X)and(PXs<X+W)and(PYs>=Y)and(PYs<Y+H);
End;

{ ------------------------------------------------------------------ }
{ Transformations monde <-> ecran (relatif a la zone de dessin)      }
{ ------------------------------------------------------------------ }

Function W2SX(X:LongInt):LongInt;
Begin
 W2SX:=((X-OrgX)*Zoom) Div 1000;
End;

Function W2SY(Y:LongInt):LongInt;
Begin
 W2SY:=((Y-OrgY)*Zoom) Div 1000;
End;

Function S2WX(X:LongInt):LongInt;
Begin
 S2WX:=OrgX+(X*1000) Div Zoom;
End;

Function S2WY(Y:LongInt):LongInt;
Begin
 S2WY:=OrgY+(Y*1000) Div Zoom;
End;

{ Aimantation aux reperes : Hor = reperes horizontaux (valeur Y) }
Function SnapGuide(V:LongInt;Hor:Boolean):LongInt;
Var I:Integer;
    Tol:LongInt;
Begin
 SnapGuide:=V;
 If Not(ShowGuides and SnapGuides)Then Exit;
 Tol:=(8*1000) Div Zoom+1;
 For I:=0 To GuideN-1 Do
  If(GuideHor[I]=Hor)and(Abs(GuidePos[I]-V)<=Tol)Then Begin
   SnapGuide:=GuidePos[I];
   Exit;
  End;
End;

Function SnapW(V:LongInt):LongInt;
Begin
 If Not SnapGrid Then Begin
  SnapW:=V;
  Exit;
 End;
 If V>=0 Then SnapW:=((V+GridSize Div 2) Div GridSize)*GridSize
         Else SnapW:=-(((-V)+GridSize Div 2) Div GridSize)*GridSize;
End;

Function SnapWX(V:LongInt):LongInt;
Var G:LongInt;
Begin
 G:=SnapGuide(V,False);
 If G<>V Then SnapWX:=G Else SnapWX:=SnapW(V);
End;

Function SnapWY(V:LongInt):LongInt;
Var G:LongInt;
Begin
 G:=SnapGuide(V,True);
 If G<>V Then SnapWY:=G Else SnapWY:=SnapW(V);
End;

Procedure ViewWorld(Var VW,VH:LongInt);
Begin
 VW:=(LongInt(CanvasW)*1000) Div Zoom;
 VH:=(LongInt(CanvasH)*1000) Div Zoom;
End;

Procedure ClampView;
Var VW,VH,MinX,MaxX,MinY,MaxY:LongInt;
Begin
 If Zoom<20 Then Zoom:=20;
 If Zoom>8000 Then Zoom:=8000;
 ViewWorld(VW,VH);
 MinX:=-1500; MaxX:=PageW+1500;
 MinY:=-1500; MaxY:=PageH+1500;
 If VW>=MaxX-MinX Then OrgX:=(PageW-VW) Div 2
  Else Begin
   If OrgX<MinX Then OrgX:=MinX;
   If OrgX>MaxX-VW Then OrgX:=MaxX-VW;
  End;
 If VH>=MaxY-MinY Then OrgY:=(PageH-VH) Div 2
  Else Begin
   If OrgY<MinY Then OrgY:=MinY;
   If OrgY>MaxY-VH Then OrgY:=MaxY-VH;
  End;
End;

Procedure ZoomAt(SX,SY:Integer;Num,Den:LongInt);
Var WX,WY:LongInt;
Begin
 WX:=S2WX(SX);
 WY:=S2WY(SY);
 Zoom:=Clamp((Zoom*Num) Div Den,20,8000);
 OrgX:=WX-(LongInt(SX)*1000) Div Zoom;
 OrgY:=WY-(LongInt(SY)*1000) Div Zoom;
 ClampView;
End;

Procedure ZoomFit;
Var Z1,Z2:LongInt;
    VW,VH:LongInt;
Begin
 Z1:=(LongInt(CanvasW-16)*1000) Div PageW;
 Z2:=(LongInt(CanvasH-16)*1000) Div PageH;
 Zoom:=Min(Z1,Z2);
 If Zoom<20 Then Zoom:=20;
 ViewWorld(VW,VH);
 OrgX:=(PageW-VW) Div 2;
 OrgY:=(PageH-VH) Div 2;
 ClampView;
End;

Procedure ZoomRect(X1,Y1,X2,Y2:LongInt);
Var Z1,Z2,VW,VH:LongInt;
Begin
 If X2-X1<20 Then X2:=X1+20;
 If Y2-Y1<20 Then Y2:=Y1+20;
 Z1:=(LongInt(CanvasW-16)*1000) Div (X2-X1);
 Z2:=(LongInt(CanvasH-16)*1000) Div (Y2-Y1);
 Zoom:=Min(Z1,Z2);
 If Zoom>8000 Then Zoom:=8000;
 If Zoom<20 Then Zoom:=20;
 ViewWorld(VW,VH);
 OrgX:=(X1+X2) Div 2-VW Div 2;
 OrgY:=(Y1+Y2) Div 2-VH Div 2;
 ClampView;
End;

{ ------------------------------------------------------------------ }
{ Geometrie ecran                                                    }
{ ------------------------------------------------------------------ }

Procedure AddP(X,Y:LongInt);
Begin
 If PN<MAXPOLY Then Begin
  PX[PN]:=X;
  PY[PN]:=Y;
  Inc(PN);
 End;
End;

{ Dernier indice du contour C du tampon }
Function PCE(C:Integer):Integer;
Var E:Integer;
Begin
 If C+1<PCN Then E:=PCS[C+1]-1 Else E:=PN-1;
 If E>PN-1 Then E:=PN-1;
 PCE:=E;
End;

Procedure BuildPoly(O:PObj;OX,OY:LongInt);
Var I,J,T:Integer;
    X1,Y1,X2,Y2,CX,CY,RX,RY:LongInt;
    U,TT,U3,U2,T2,T3,A,B,C,D:LongInt;
    P:Array[0..3] of TPt;
Begin
 PN:=0;
 PCN:=1;
 PCS[0]:=0;
 PClosed:=False;
 Case O^.Kind Of
  K_LINE,K_POLYLINE,K_POLY:Begin
   For I:=0 To O^.N-1 Do
    AddP(W2SX(O^.Pts^[I].X+OX),W2SY(O^.Pts^[I].Y+OY));
   PClosed:=O^.Kind=K_POLY;
  End;
  K_RECT,K_TEXT,K_BITMAP:Begin
   ObjBBox(O,X1,Y1,X2,Y2);
   AddP(W2SX(X1+OX),W2SY(Y1+OY));
   AddP(W2SX(X2+OX),W2SY(Y1+OY));
   AddP(W2SX(X2+OX),W2SY(Y2+OY));
   AddP(W2SX(X1+OX),W2SY(Y2+OY));
   PClosed:=True;
  End;
  K_ELLIPSE:Begin
   ObjBBox(O,X1,Y1,X2,Y2);
   CX:=(X1+X2) Div 2+OX;
   CY:=(Y1+Y2) Div 2+OY;
   RX:=(X2-X1) Div 2;
   RY:=(Y2-Y1) Div 2;
   For I:=0 To 47 Do
    AddP(W2SX(CX+(RX*ECos[I]) Div 1000),W2SY(CY+(RY*ESin[I]) Div 1000));
   PClosed:=True;
  End;
  K_BEZIER:Begin
   AddP(W2SX(O^.Pts^[0].X+OX),W2SY(O^.Pts^[0].Y+OY));
   I:=0;
   While I+3<=O^.N-1 Do Begin
    If O^.Pts^[I+1].X=BRK Then Begin
     If PCN<64 Then Begin
      PCS[PCN]:=PN;
      Inc(PCN);
     End;
     AddP(W2SX(O^.Pts^[I+3].X+OX),W2SY(O^.Pts^[I+3].Y+OY));
     Inc(I,3);
     Continue;
    End;
    For J:=0 To 3 Do Begin
     P[J].X:=O^.Pts^[I+J].X+OX;
     P[J].Y:=O^.Pts^[I+J].Y+OY;
    End;
    For T:=1 To 12 Do Begin
     TT:=T;
     U:=12-T;
     U3:=U*U*U;
     U2:=3*U*U*TT;
     T2:=3*U*TT*TT;
     T3:=TT*TT*TT;
     A:=(U3*P[0].X+U2*P[1].X+T2*P[2].X+T3*P[3].X) Div 1728;
     B:=(U3*P[0].Y+U2*P[1].Y+T2*P[2].Y+T3*P[3].Y) Div 1728;
     C:=A; D:=B;
     AddP(W2SX(C),W2SY(D));
    End;
    Inc(I,3);
   End;
   PClosed:=O^.Closed;
  End;
 End;
 For I:=0 To PN-1 Do Begin
  PX[I]:=Clamp(PX[I],-30000,30000);
  PY[I]:=Clamp(PY[I],-30000,30000);
 End;
End;

Function PointInPoly(X,Y:LongInt):Boolean;
Var I,J,C:Integer;
    Inside:Boolean;
Begin
 Inside:=False;
 For C:=0 To PCN-1 Do Begin
  J:=PCE(C);
  For I:=PCS[C] To PCE(C) Do Begin
   If((PY[I]>Y)<>(PY[J]>Y))Then
    If X<PX[I]+((Y-PY[I])*(PX[J]-PX[I])) Div (PY[J]-PY[I]) Then Inside:=Not Inside;
   J:=I;
  End;
 End;
 PointInPoly:=Inside;
End;

Function DistSeg(PXs,PYs,X1,Y1,X2,Y2:LongInt):LongInt;
Var DX,DY:Real;
    T,L2,QX,QY:Real;
Begin
 DX:=X2-X1;
 DY:=Y2-Y1;
 L2:=DX*DX+DY*DY;
 If L2=0 Then T:=0
  Else T:=((PXs-X1)*DX+(PYs-Y1)*DY)/L2;
 If T<0 Then T:=0;
 If T>1 Then T:=1;
 QX:=X1+T*DX-PXs;
 QY:=Y1+T*DY-PYs;
 DistSeg:=Round(Sqrt(QX*QX+QY*QY));
End;

{ Distance minimale du point (X,Y) au polygone courant }
Function PolyDist(X,Y:LongInt):LongInt;
Var I,J,Last,C,CS:Integer;
    D,Best:LongInt;
Begin
 Best:=MaxLongInt;
 If PN=1 Then Begin
  PolyDist:=Round(Sqrt(Sqr(X-PX[0])+Sqr(Y-PY[0])));
  Exit;
 End;
 For C:=0 To PCN-1 Do Begin
  CS:=PCS[C];
  Last:=PCE(C)-1;
  If PClosed Then Last:=PCE(C);
  For I:=CS To Last Do Begin
   J:=I+1;
   If J>PCE(C)Then J:=CS;
   D:=DistSeg(X,Y,PX[I],PY[I],PX[J],PY[J]);
   If D<Best Then Best:=D;
  End;
 End;
 PolyDist:=Best;
End;

{ ------------------------------------------------------------------ }
{ Remplissage et contours                                            }
{ ------------------------------------------------------------------ }

Const
 Bayer:Array[0..3,0..3] of Byte=((0,8,2,10),(12,4,14,6),(3,11,1,9),(15,7,13,5));

Var
 GFK,GPat:Byte;
 GC1,GC2:Integer;
 GMinX,GMaxX,GMinY,GMaxY:LongInt;
 GOffX,GOffY:Integer;
 GCX,GCY,GRad:LongInt;
 GImg:Integer;
 GTW,GTH,GOX,GOY:LongInt;

{ Indice de palette (cube d'images) du point (IX,IY) de l'image P, tramage
  de Bayer d'apres la position ecran SX,SY ; -1 si le point est transparent }
Function ImgIndex(P:PImage;IX,IY,SX,SY:LongInt):Integer;
Var O,Bay,R,G,B,V:LongInt;
Begin
 ImgIndex:=-1;
 {$IFDEF FPC}
 O:=IY*P^.W+IX;
 If P^.Alpha and(P^.A^[O]<128)Then Exit;
 Bay:=Bayer[SX And 3,SY And 3];
 O:=O*3;
 V:=LongInt(P^.Pix^[O])*80 Div 255;
 R:=V Shr 4;
 If(V And 15)>Bay Then Inc(R);
 V:=LongInt(P^.Pix^[O+1])*80 Div 255;
 G:=V Shr 4;
 If(V And 15)>Bay Then Inc(G);
 V:=LongInt(P^.Pix^[O+2])*48 Div 255;
 B:=V Shr 4;
 If(V And 15)>Bay Then Inc(B);
 ImgIndex:=Integer(IMG_BASE+(R*6+G)*4+B);
 {$ELSE}
 O:=0; Bay:=0; R:=0; G:=0; B:=0; V:=IX+IY+SX+SY;
 {$ENDIF}
End;

Procedure DitherPixel(X,Y,Mix:Integer);
Begin
 If Bayer[X And 3,Y And 3]<Mix Then Begin
  If GC2<0 Then PutPixel(X,Y,HWMap[15]) Else PutPixel(X,Y,HWMap[GC2]);
 End
  Else PutPixel(X,Y,HWMap[GC1]);
End;

{ Degrade conique : 0 a l'angle 0, 16 a l'angle oppose (symetrique) }
Function ConicMix(DX,DY:LongInt):Integer;
Var A:Real;
Begin
 If(DX=0)and(DY=0)Then Begin
  ConicMix:=0;
  Exit;
 End;
 If DX=0 Then Begin
  If DY>0 Then A:=Pi/2 Else A:=-Pi/2;
 End
  Else Begin
   A:=ArcTan(DY/DX);
   If DX<0 Then Begin
    If DY>=0 Then A:=A+Pi Else A:=A-Pi;
   End;
  End;
 ConicMix:=Round(Abs(A)/Pi*16);
End;

Procedure FillSpan(XA,XB,Y:Integer);
Var X,Mix,Blk,E:Integer;
    D:LongInt;
Begin
 If XA<0 Then XA:=0;
 If XB>CanvasW-1 Then XB:=CanvasW-1;
 If XA>XB Then Exit;
 Case GFK Of
  FK_SOLID:Begin
   SetCol(GC1);
   Line(XA,Y,XB,Y);
  End;
  FK_GRADV:Begin
   Mix:=((Y-GMinY)*17) Div (GMaxY-GMinY+1);
   If Mix<=0 Then Begin SetCol(GC1); Line(XA,Y,XB,Y); End
   Else If Mix>=16 Then Begin SetCol(GC2); Line(XA,Y,XB,Y); End
   Else For X:=XA To XB Do DitherPixel(X,Y,Mix);
  End;
  FK_GRADH:Begin
   D:=GMaxX-GMinX+1;
   For X:=XA To XB Do Begin
    Mix:=((X-GMinX)*17) Div D;
    DitherPixel(X,Y,Mix);
   End;
  End;
  FK_IMAGE:Begin
   If(GImg>=1)and(GImg<=ImgCount)and ImgPalOn Then Begin
    D:=Y-GOY;
    D:=((D Mod GTH)+GTH) Mod GTH;
    D:=D*Imgs[GImg]^.H Div GTH;
    For X:=XA To XB Do Begin
     E:=Integer((((X-GOX) Mod GTW)+GTW) Mod GTW);
     E:=Integer(LongInt(E)*Imgs[GImg]^.W Div GTW);
     Mix:=ImgIndex(Imgs[GImg],E,D,X,Y);
     If Mix>=0 Then PutPixel(X,Y,HWMap[Mix]);
    End;
   End
    Else Begin
     SetCol(GC1);
     Line(XA,Y,XB,Y);
    End;
  End;
  FK_RADIAL:Begin
   For X:=XA To XB Do Begin
    D:=Round(Sqrt(Sqr(X-GCX)+Sqr(Y-GCY)));
    Mix:=Integer((D*17) Div GRad);
    If Mix>16 Then Mix:=16;
    DitherPixel(X,Y,Mix);
   End;
  End;
  FK_CONIC:Begin
   For X:=XA To XB Do Begin
    Mix:=ConicMix(X-GCX,Y-GCY);
    DitherPixel(X,Y,Mix);
   End;
  End;
  FK_SQUARE:Begin
   For X:=XA To XB Do Begin
    D:=(Abs(X-GCX)*1000) Div Max(1,(GMaxX-GMinX) Div 2);
    E:=Integer((Abs(Y-GCY)*1000) Div Max(1,(GMaxY-GMinY) Div 2));
    If E>D Then D:=E;
    Mix:=Integer((D*17) Div 1000);
    If Mix>16 Then Mix:=16;
    DitherPixel(X,Y,Mix);
   End;
  End;
  FK_PATTERN:Begin
   If GC2>=0 Then Begin
    SetCol(GC2);
    Line(XA,Y,XB,Y);
   End;
   SetCol(GC1);
   Case GPat Of
    1:If Y Mod 4=0 Then Line(XA,Y,XB,Y);
    2:Begin
     X:=XA+((4-XA Mod 4) Mod 4);
     While X<=XB Do Begin PutPixel(X,Y,GetColor); Inc(X,4); End;
    End;
    3:Begin
     X:=XA;
     While X<=XB Do Begin
      If(X+Y) Mod 6=0 Then PutPixel(X,Y,GetColor);
      Inc(X);
     End;
    End;
    4:Begin
     X:=XA;
     While X<=XB Do Begin
      If((X-Y) Mod 6+6) Mod 6=0 Then PutPixel(X,Y,GetColor);
      Inc(X);
     End;
    End;
    5:Begin
     If Y Mod 6=0 Then Line(XA,Y,XB,Y)
      Else Begin
       X:=XA+((6-XA Mod 6) Mod 6);
       While X<=XB Do Begin PutPixel(X,Y,GetColor); Inc(X,6); End;
      End;
    End;
    6:If Y Mod 4=0 Then Begin
       X:=XA+((4-XA Mod 4) Mod 4);
       While X<=XB Do Begin PutPixel(X,Y,GetColor); Inc(X,4); End;
      End;
    7:Begin
     X:=XA;
     While X<=XB Do Begin
      Blk:=X Div 6;
      E:=Blk*6+5;
      If E>XB Then E:=XB;
      If Odd(Blk+Y Div 6)Then Line(X,Y,E,Y);
      X:=E+1;
     End;
    End;
    8:Begin
     X:=XA;
     While X<=XB Do Begin
      If Not Odd(X+Y)Then PutPixel(X,Y,GetColor);
      Inc(X);
     End;
    End;
   End;
  End;
 End;
End;

Procedure ScanFill(FK,Pat:Byte;C1,C2:Integer);
 { GOffX/GOffY : decalage du centre (degrade radial) }
Var Y,Y1,Y2,I,J,K,M,C:Integer;
    X:Array[0..511] of Integer;
    Ya,Yb,T:LongInt;
Begin
 If PN<3 Then Exit;
 GFK:=FK; GPat:=Pat; GC1:=C1; GC2:=C2;
 GMinX:=PX[0]; GMaxX:=PX[0]; GMinY:=PY[0]; GMaxY:=PY[0];
 For I:=1 To PN-1 Do Begin
  If PX[I]<GMinX Then GMinX:=PX[I];
  If PX[I]>GMaxX Then GMaxX:=PX[I];
  If PY[I]<GMinY Then GMinY:=PY[I];
  If PY[I]>GMaxY Then GMaxY:=PY[I];
 End;
 If GMaxX<0 Then Exit;
 If GMinX>CanvasW-1 Then Exit;
 GOX:=GMinX;
 GOY:=GMinY;
 GCX:=(GMinX+GMaxX) Div 2+((GMaxX-GMinX)*GOffX) Div 100;
 GCY:=(GMinY+GMaxY) Div 2-((GMaxY-GMinY)*GOffY) Div 100;
 GRad:=Round(Sqrt(Sqr(GMaxX-GMinX)+Sqr(GMaxY-GMinY))*0.5)+1;
 Y1:=Integer(Max(GMinY,0));
 Y2:=Integer(Min(GMaxY,CanvasH-1));
 For Y:=Y1 To Y2 Do Begin
  M:=0;
  For C:=0 To PCN-1 Do Begin
   J:=PCE(C);
   For I:=PCS[C] To PCE(C) Do Begin
    Ya:=PY[J]; Yb:=PY[I];
    If((Y>=Ya)and(Y<Yb))or((Y>=Yb)and(Y<Ya))Then
     If M<512 Then Begin
      T:=PX[J]+((Y-Ya)*(PX[I]-PX[J])) Div (Yb-Ya);
      X[M]:=Integer(Clamp(T,-30000,30000));
      Inc(M);
     End;
    J:=I;
   End;
  End;
  For I:=1 To M-1 Do Begin
   K:=X[I];
   J:=I-1;
   While(J>=0)and(X[J]>K)Do Begin
    X[J+1]:=X[J];
    Dec(J);
   End;
   X[J+1]:=K;
  End;
  I:=0;
  While I+1<M Do Begin
   FillSpan(X[I],X[I+1],Y);
   Inc(I,2);
  End;
 End;
End;

Procedure ThickLine(X1,Y1,X2,Y2,W:Integer);
Var I,H:Integer;
Begin
 If W<=1 Then Line(X1,Y1,X2,Y2)
 Else Begin
  H:=W Div 2;
  If Abs(X2-X1)>=Abs(Y2-Y1)Then
   For I:=-H To W-H-1 Do Line(X1,Y1+I,X2,Y2+I)
  Else
   For I:=-H To W-H-1 Do Line(X1+I,Y1,X2+I,Y2);
 End;
End;

Procedure StrokePoly(Col:Integer;W:LongInt;Style:Byte);
Var I,J,Last,WP,C,CS:Integer;
Begin
 If PN<2 Then Exit;
 WP:=Integer(Clamp((W*Zoom+500) Div 1000,1,24));
 SetCol(Col);
 If Style=1 Then SetLineStyle(DottedLn,0,NormWidth)
  Else
 If Style=2 Then SetLineStyle(DashedLn,0,NormWidth)
  Else SetLineStyle(SolidLn,0,NormWidth);
 For C:=0 To PCN-1 Do Begin
  CS:=PCS[C];
  Last:=PCE(C)-1;
  If PClosed Then Last:=PCE(C);
  For I:=CS To Last Do Begin
   J:=I+1;
   If J>PCE(C)Then J:=CS;
   ThickLine(PX[I],PY[I],PX[J],PY[J],WP);
  End;
 End;
 SetLineStyle(SolidLn,0,NormWidth);
End;

Function DarkOf(C:Integer):Integer;
Begin
 If C<0 Then DarkOf:=8
 Else If C=15 Then DarkOf:=7
 Else If(C>=9)and(C<=14)Then DarkOf:=C-8
 Else If C>=16 Then DarkOf:=8
 Else If C=0 Then DarkOf:=8
 Else DarkOf:=0;
End;

Procedure DrawTextObj(O:PObj;OX,OY:LongInt;Col:Integer);
Var SX,SY,HS:LongInt;
    Sz:Integer;
Begin
 SX:=W2SX(O^.Pts^[0].X+OX);
 SY:=W2SY(O^.Pts^[0].Y+OY);
 HS:=(O^.TextSize*Zoom) Div 1000;
 Sz:=Integer((HS+4) Div 8);
 SetCol(Col);
 If Sz<1 Then Begin
  Line(CL(SX),CL(SY+HS Div 2),CL(SX+(Length(O^.Txt)*HS)),CL(SY+HS Div 2));
  Exit;
 End;
 If Sz>10 Then Sz:=10;
 SetTextStyle(DefaultFont,HorizDir,Sz);
 OutTextXY(CL(SX),CL(SY),Conv(O^.Txt));
 SetTextStyle(DefaultFont,HorizDir,1);
End;

{ Dessine un bitmap : echantillonnage au plus proche, tramage de Bayer }
Procedure DrawBitmapObj(O:PObj);
Var X1,Y1,X2,Y2,SX1,SY1,SX2,SY2,XA,XB,YA,YB,X,Y,IY,W:LongInt;
    Im:PImage;
    Idx:Integer;
    Col:Array[0..1023] of Integer;
Begin
 ObjBBox(O,X1,Y1,X2,Y2);
 SX1:=W2SX(X1); SY1:=W2SY(Y1);
 SX2:=W2SX(X2); SY2:=W2SY(Y2);
 If SX2<=SX1 Then SX2:=SX1+1;
 If SY2<=SY1 Then SY2:=SY1+1;
 If(O^.Img<1)or(O^.Img>ImgCount)or Not ImgPalOn or WireMode Then Begin
  BuildPoly(O,0,0);
  If Not WireMode Then ScanFill(FK_PATTERN,8,8,15);
  StrokePoly(8,1,0);
  Exit;
 End;
 Im:=Imgs[O^.Img];
 XA:=Max(SX1,0);
 XB:=Min(SX2,CanvasW-1);
 YA:=Max(SY1,0);
 YB:=Min(SY2,CanvasH-1);
 If(XA>XB)or(YA>YB)or(XB-XA>1023)Then Begin
  If XB-XA>1023 Then XB:=XA+1023 Else Exit;
 End;
 W:=SX2-SX1;
 For X:=XA To XB Do Col[X-XA]:=Integer((X-SX1)*Im^.W Div W);
 For Y:=YA To YB Do Begin
  IY:=(Y-SY1)*Im^.H Div (SY2-SY1);
  If IY>=Im^.H Then IY:=Im^.H-1;
  For X:=XA To XB Do Begin
   Idx:=ImgIndex(Im,Col[X-XA],IY,X,Y);
   If Idx>=0 Then PutPixel(X,Y,HWMap[Idx]);
  End;
 End;
End;

Procedure DrawObject(O:PObj);
Var I,K:Integer;
    TC:Integer;
Begin
 If WireMode Then Begin
  BuildPoly(O,0,0);
  SetCol(0);
  SetLineStyle(SolidLn,0,NormWidth);
  If O^.Kind=K_TEXT Then DrawTextObj(O,0,0,0);
  If PN>=2 Then Begin
   For K:=0 To PCN-1 Do Begin
    For I:=PCS[K] To PCE(K)-1 Do Line(PX[I],PY[I],PX[I+1],PY[I+1]);
    If PClosed Then Line(PX[PCE(K)],PY[PCE(K)],PX[PCS[K]],PY[PCS[K]]);
   End;
  End;
  Exit;
 End;
 If O^.Kind=K_BITMAP Then Begin
  DrawBitmapObj(O);
  Exit;
 End;
 If O^.Kind=K_TEXT Then Begin
  If O^.FillCol>=0 Then TC:=O^.FillCol Else TC:=O^.OutCol;
  If TC<0 Then TC:=0;
  If O^.Shadow Then DrawTextObj(O,SHADOW_OFF,SHADOW_OFF,8);
  If O^.Extrude Then
   For I:=EXT_STEPS DownTo 1 Do DrawTextObj(O,I*EXT_STEP Div 3,-I*EXT_STEP Div 3,DarkOf(TC));
  DrawTextObj(O,0,0,TC);
  Exit;
 End;
 If O^.Shadow Then Begin
  BuildPoly(O,SHADOW_OFF,SHADOW_OFF);
  If PClosed and(O^.FillKind<>FK_NONE)Then ScanFill(FK_SOLID,0,8,-1)
   Else StrokePoly(8,O^.OutW,0);
 End;
 If O^.Extrude Then
  For I:=EXT_STEPS DownTo 1 Do Begin
   BuildPoly(O,I*EXT_STEP,-I*EXT_STEP);
   If PClosed and(O^.FillKind<>FK_NONE)Then Begin
    ScanFill(FK_SOLID,0,DarkOf(O^.FillCol),-1);
    StrokePoly(0,1,0);
   End
    Else StrokePoly(DarkOf(O^.OutCol),O^.OutW,0);
  End;
 BuildPoly(O,0,0);
 If PClosed and(O^.FillKind<>FK_NONE)and(O^.FillCol>=0)Then
  Begin
   GOffX:=O^.GradX;
   GOffY:=O^.GradY;
   GImg:=O^.Img;
   GTW:=Max(2,(LongInt(O^.TileW)*Zoom) Div 1000);
   GTH:=Max(2,(LongInt(O^.TileH)*Zoom) Div 1000);
   ScanFill(O^.FillKind,O^.Pattern,O^.FillCol,O^.FillCol2);
  End;
 If O^.OutCol>=0 Then StrokePoly(O^.OutCol,O^.OutW,O^.LineStyle)
  Else
 If Not PClosed Then StrokePoly(0,1,0);
End;

Function HitObject(SX,SY:Integer):Integer;
Var I:LongInt;
    O:PObj;
Begin
 HitObject:=-1;
 For I:=ObjCount-1 DownTo 0 Do Begin
  O:=ObjAt(I);
  If Not ObjPickable(O)Then Continue;
  BuildPoly(O,0,0);
  If PN=0 Then Continue;
  If(O^.Kind=K_TEXT)Then Begin
   If PointInPoly(SX,SY)Then Begin HitObject:=I; Exit; End;
   Continue;
  End;
  If PClosed and(O^.FillKind<>FK_NONE)and(O^.FillCol>=0)and Not WireMode Then
   If PointInPoly(SX,SY)Then Begin HitObject:=I; Exit; End;
  If PolyDist(SX,SY)<=3+Integer(Min(3,(O^.OutW*Zoom) Div 2000))Then Begin
   HitObject:=I;
   Exit;
  End;
 End;
End;

{ ------------------------------------------------------------------ }
{ Zone de dessin                                                     }
{ ------------------------------------------------------------------ }

Procedure BeginCanvas;
Begin
 SetViewPort(CanvasX,CanvasY,CanvasX+CanvasW-1,CanvasY+CanvasH-1,True);
End;

Procedure EndCanvas;
Begin
 SetViewPort(0,0,ScreenW-1,ScreenH-1,True);
End;

Procedure DrawGridPoints;
Var GX,GY,SX,SY,Step:LongInt;
Begin
 Step:=(GridSize*Zoom) Div 1000;
 If Step<5 Then Exit;
 SetCol(7);
 GX:=((OrgX Div GridSize)-1)*GridSize;
 While W2SX(GX)<CanvasW Do Begin
  SX:=W2SX(GX);
  GY:=((OrgY Div GridSize)-1)*GridSize;
  While W2SY(GY)<CanvasH Do Begin
   SY:=W2SY(GY);
   If(SX>=0)and(SY>=0)and(SX<CanvasW)and(SY<CanvasH)Then PutPixel(SX,SY,GetColor);
   Inc(GY,GridSize);
  End;
  Inc(GX,GridSize);
 End;
End;

Procedure DrawPage;
Var X1,Y1,X2,Y2:LongInt;
Begin
 X1:=CL(W2SX(0)); Y1:=CL(W2SY(0));
 X2:=CL(W2SX(PageW)); Y2:=CL(W2SY(PageH));
 Box(X1+4,Y1+4,X2+4,Y2+4,8);
 Box(X1,Y1,X2,Y2,15);
 SetCol(0);
 Rectangle(X1,Y1,X2,Y2);
End;

Procedure DrawHandleBox(X,Y:Integer);
Begin
 Box(X-3,Y-3,X+3,Y+3,15);
 SetCol(0);
 Rectangle(X-3,Y-3,X+3,Y+3);
 Box(X-1,Y-1,X+1,Y+1,0);
End;

Procedure HandlePos(H:Integer;X1,Y1,X2,Y2:Integer;Var HX,HY:Integer);
Begin
 Case H Of
  1:Begin HX:=X1; HY:=Y1; End;
  2:Begin HX:=(X1+X2) Div 2; HY:=Y1; End;
  3:Begin HX:=X2; HY:=Y1; End;
  4:Begin HX:=X2; HY:=(Y1+Y2) Div 2; End;
  5:Begin HX:=X2; HY:=Y2; End;
  6:Begin HX:=(X1+X2) Div 2; HY:=Y2; End;
  7:Begin HX:=X1; HY:=Y2; End;
 Else Begin HX:=X1; HY:=(Y1+Y2) Div 2; End;
 End;
End;

{ Boite englobante de la selection en coordonnees ecran (zone de dessin) }
Function SelScreenBox(Var X1,Y1,X2,Y2:Integer):Boolean;
Var A,B,C,D:LongInt;
Begin
 SelScreenBox:=False;
 If Not SelBBox(A,B,C,D)Then Exit;
 X1:=CL(W2SX(A))-3; Y1:=CL(W2SY(B))-3;
 X2:=CL(W2SX(C))+3; Y2:=CL(W2SY(D))+3;
 SelScreenBox:=True;
End;

Function HitHandle(SX,SY:Integer):Integer;
Var X1,Y1,X2,Y2,H,HX,HY:Integer;
Begin
 HitHandle:=0;
 If CurTool<>T_PICK Then Exit;
 If Not SelScreenBox(X1,Y1,X2,Y2)Then Exit;
 For H:=1 To 8 Do Begin
  HandlePos(H,X1,Y1,X2,Y2,HX,HY);
  If(Abs(SX-HX)<=5)and(Abs(SY-HY)<=5)Then Begin
   HitHandle:=H;
   Exit;
  End;
 End;
End;

Procedure DrawSelection;
Var X1,Y1,X2,Y2,H,HX,HY,K:Integer;
    I:LongInt;
    O:PObj;
    SX,SY,AX,AY:LongInt;
Begin
 If SelCount=0 Then Exit;
 If CurTool=T_SHAPE Then Begin
  For I:=0 To ObjCount-1 Do
   If ObjAt(I)^.Sel Then Begin
    O:=ObjAt(I);
    If O^.Kind=K_TEXT Then Continue;
    If O^.Kind=K_BEZIER Then Begin
     SetCol(8);
     K:=1;
     While K+2<O^.N Do Begin
      If O^.Pts^[K].X<>BRK Then Begin
       Line(CL(W2SX(O^.Pts^[K-1].X)),CL(W2SY(O^.Pts^[K-1].Y)),
            CL(W2SX(O^.Pts^[K].X)),CL(W2SY(O^.Pts^[K].Y)));
       Line(CL(W2SX(O^.Pts^[K+2].X)),CL(W2SY(O^.Pts^[K+2].Y)),
            CL(W2SX(O^.Pts^[K+1].X)),CL(W2SY(O^.Pts^[K+1].Y)));
      End;
      Inc(K,3);
     End;
    End;
    For K:=0 To O^.N-1 Do If O^.Pts^[K].X<>BRK Then Begin
     SX:=CL(W2SX(O^.Pts^[K].X));
     SY:=CL(W2SY(O^.Pts^[K].Y));
     If(O^.Kind=K_BEZIER)and(K Mod 3<>0)Then Begin
      SetCol(0);
      Circle(SX,SY,3);
     End
      Else
     Begin
      Box(SX-3,SY-3,SX+3,SY+3,15);
      SetCol(0);
      Rectangle(SX-3,SY-3,SX+3,SY+3);
     End;
    End;
   End;
  Exit;
 End;
 If Not SelScreenBox(X1,Y1,X2,Y2)Then Exit;
 SetCol(0);
 SetLineStyle(DashedLn,0,NormWidth);
 Rectangle(X1,Y1,X2,Y2);
 SetLineStyle(SolidLn,0,NormWidth);
 If CurTool=T_PICK Then
  For H:=1 To 8 Do Begin
   HandlePos(H,X1,Y1,X2,Y2,HX,HY);
   DrawHandleBox(HX,HY);
  End;
 AX:=0; AY:=0;
End;

{ Reperes de dessin (lignes pointillees) }
Procedure DrawGuides;
Var I,S,K:Integer;
Begin
 If Not ShowGuides Then Exit;
 SetCol(9);
 For I:=0 To GuideN-1 Do Begin
  If GuideHor[I] Then Begin
   S:=Integer(W2SY(GuidePos[I]));
   If(S>=0)and(S<CanvasH)Then Begin
    K:=0;
    While K<CanvasW Do Begin
     Line(K,S,Min(K+5,CanvasW-1),S);
     Inc(K,9);
    End;
   End;
  End
   Else Begin
    S:=Integer(W2SX(GuidePos[I]));
    If(S>=0)and(S<CanvasW)Then Begin
     K:=0;
     While K<CanvasH Do Begin
      Line(S,K,S,Min(K+5,CanvasH-1));
      Inc(K,9);
     End;
    End;
   End;
 End;
End;

Procedure DrawCanvas;
Var I:LongInt;
Begin
 BeginCanvas;
 Box(0,0,CanvasW-1,CanvasH-1,CANVAS_BG);
 DrawPage;
 If ShowGrid Then DrawGridPoints;
 For I:=0 To ObjCount-1 Do If ObjShown(ObjAt(I))Then DrawObject(ObjAt(I));
 DrawGuides;
 DrawSelection;
 EndCanvas;
End;

{ ------------------------------------------------------------------ }
{ Commandes et menus                                                 }
{ ------------------------------------------------------------------ }

Const
 CM_NEW=1; CM_OPEN=2; CM_SAVE=3; CM_SAVEAS=4; CM_IMPORT=5; CM_EXPORTSVG=6;
 CM_INFO=7; CM_QUIT=8; CM_EXPORTCDR9=9;
 CM_UNDO=10; CM_REDO=11; CM_CUT=12; CM_COPY=13; CM_PASTE=14; CM_DUP=15;
 CM_DEL=16; CM_SELALL=17; CM_SELNONE=18; CM_SELNEXT=19;
 CM_ZIN=20; CM_ZOUT=21; CM_ZFIT=22; CM_Z100=23; CM_ZSEL=24; CM_WIRE=25;
 CM_GRID=26; CM_RULERS=27; CM_SNAP=28; CM_PREVIEW=29;
 CM_PAGE_A4=30; CM_PAGE_A5=31; CM_PAGE_A3=32; CM_PAGE_LET=33;
 CM_PORTRAIT=34; CM_LANDSCAPE=35; CM_GRIDSIZE=36;
 CM_FRONT=40; CM_BACK=41; CM_FWD=42; CM_BWD=43; CM_GROUP=44; CM_UNGROUP=45;
 CM_AL_L=46; CM_AL_C=47; CM_AL_R=48; CM_AL_T=49; CM_AL_M=50; CM_AL_B=51;
 CM_DISTH=52; CM_DISTV=53; CM_ROT90=54; CM_FLIPH=55; CM_FLIPV=56;
 CM_TOCURVE=57;
 CM_FILL_NONE=60; CM_FILL_SOLID=61; CM_FILL_GV=62; CM_FILL_GH=63;
 CM_FILL_RAD=58; CM_FILL_PAT=64; CM_OUT_NONE=65; CM_OUT_COLOR=66; CM_OUT_WIDTH=67;
 CM_OUT_STYLE=68; CM_SHADOW=69; CM_EXTRUDE=70;
 CM_TEXT_EDIT=80; CM_TEXT_BIG=81; CM_TEXT_SMALL=82;
 CM_SIDES=90; CM_RESETDEF=91; CM_STATS=92;
 CM_HELPKEYS=95; CM_ABOUT=96;
 CM_W1=100; CM_W2=101; CM_W3=102; CM_W4=103; CM_W5=104;
 CM_SIDES_UP=110; CM_SIDES_DN=111;
 CM_B_WELD=120; CM_B_INTER=121; CM_B_FMB=122; CM_B_BMF=123; CM_B_KNIFE=124;
 CM_COMBINE=125; CM_BREAK=126;
 CM_ROTATE=130; CM_SKEW=131; CM_SCALE=132; CM_WARP=133; CM_BLEND=134;
 CM_CONTOUR=135; CM_ROT_L=136; CM_ROT_R=137;
 CM_N_LINE=140; CM_N_CURVE=141; CM_N_SMOOTH=142; CM_N_SYM=143; CM_N_CUSP=144;
 CM_N_BREAK=145; CM_N_CLOSE=146;
 CM_FILL_CON=150; CM_FILL_SQ=151; CM_FILL_CMYK=152;
 CM_DIM_H=155; CM_DIM_V=156; CM_CONNECT=157;
 CM_LAYERS=160; CM_PAGE_NEXT=161; CM_PAGE_PREV=162; CM_PAGE_ADD=163;
 CM_PAGE_DEL=164; CM_PAGE_MASTER=165;
 CM_GUIDE_ADD=170; CM_GUIDE_CLEAR=171; CM_GUIDES=172; CM_GUIDE_SNAP=173;
 CM_EXPORTV=180;
 CM_SEL_FILL=175; CM_SEL_OUT=176; CM_SEL_TYPE=177; CM_REPLACE=178;

 POPUP_IDX=10;
 ITEM_H=16; SEP_H=8;

Type
 TMenuItem=Record
  Cap:String[30];
  Short:String[10];
  Cmd:Integer;
 End;
 TMenu=Record
  Title:String[12];
  X,Y,W,N:Integer;
  It:Array[0..31] of TMenuItem;
 End;

Var
 Menus:Array[0..POPUP_IDX] of TMenu;
 MenuIdx,MenuItemSel:Integer;
 NeedRedraw,Running:Boolean;

Procedure AddItem(M:Integer;Const Cap,Short:String;Cmd:Integer);
Begin
 With Menus[M] Do Begin
  It[N].Cap:=Cap;
  It[N].Short:=Short;
  It[N].Cmd:=Cmd;
  Inc(N);
 End;
End;

Procedure AddSep(M:Integer);
Begin
 AddItem(M,'','',0);
End;

Procedure SetMenuTitle(M:Integer;Const T:String);
Begin
 Menus[M].Title:=T;
 Menus[M].N:=0;
End;

Procedure FinishMenus;
Var I,J,W,A,B,X:Integer;
Begin
 X:=4;
 For I:=0 To POPUP_IDX Do Begin
  A:=0; B:=0;
  For J:=0 To Menus[I].N-1 Do Begin
   If TxtW(Menus[I].It[J].Cap)>A Then A:=TxtW(Menus[I].It[J].Cap);
   If TxtW(Menus[I].It[J].Short)>B Then B:=TxtW(Menus[I].It[J].Short);
  End;
  W:=A+B+44;
  If B=0 Then W:=A+34;
  Menus[I].W:=W;
  If I<POPUP_IDX Then Begin
   Menus[I].X:=X;
   Menus[I].Y:=MENUBAR_H;
   Inc(X,TxtW(Menus[I].Title)+14);
  End;
 End;
End;

Procedure InitMenus;
Var I:Integer;
Begin
 FillChar(Menus,SizeOf(Menus),0);
 SetMenuTitle(0,'Fichier');
 AddItem(0,'Nouveau','Ctrl+N',CM_NEW);
 AddItem(0,'Ouvrir...','Ctrl+O',CM_OPEN);
 AddItem(0,'Enregistrer','Ctrl+S',CM_SAVE);
 AddItem(0,'Enregistrer sous...','',CM_SAVEAS);
 AddSep(0);
 AddItem(0,'Importer...','',CM_IMPORT);
 AddItem(0,'Exporter en SVG...','',CM_EXPORTSVG);
 AddItem(0,'Exporter CorelDRAW 9...','',CM_EXPORTCDR9);
 AddItem(0,'Exporter PDF, EPS, DXF...','',CM_EXPORTV);
 AddSep(0);
 AddItem(0,'Informations...','',CM_INFO);
 AddSep(0);
 AddItem(0,'Quitter','Alt+X',CM_QUIT);

 SetMenuTitle(1,'Édition');
 AddItem(1,'Annuler','Ctrl+Z',CM_UNDO);
 AddItem(1,'Rétablir','Ctrl+Y',CM_REDO);
 AddSep(1);
 AddItem(1,'Couper','Ctrl+X',CM_CUT);
 AddItem(1,'Copier','Ctrl+C',CM_COPY);
 AddItem(1,'Coller','Ctrl+V',CM_PASTE);
 AddItem(1,'Dupliquer','Ctrl+D',CM_DUP);
 AddItem(1,'Supprimer','Suppr',CM_DEL);
 AddSep(1);
 AddItem(1,'Tout sélectionner','Ctrl+A',CM_SELALL);
 AddItem(1,'Objet suivant','Tab',CM_SELNEXT);
 AddItem(1,'Désélectionner','Échap',CM_SELNONE);

 SetMenuTitle(2,'Vue');
 AddItem(2,'Zoom avant','+',CM_ZIN);
 AddItem(2,'Zoom arrière','-',CM_ZOUT);
 AddItem(2,'Page entière','F4',CM_ZFIT);
 AddItem(2,'Zoom 100%','F3',CM_Z100);
 AddItem(2,'Zoom sur la sélection','F2',CM_ZSEL);
 AddSep(2);
 AddItem(2,'Filaments','',CM_WIRE);
 AddItem(2,'Grille','',CM_GRID);
 AddItem(2,'Règles','',CM_RULERS);
 AddItem(2,'Magnétisme de la grille','',CM_SNAP);
 AddSep(2);
 AddItem(2,'Aperçu plein écran','F9',CM_PREVIEW);
 AddSep(2);
 AddItem(2,'Repères visibles','',CM_GUIDES);
 AddItem(2,'Magnétisme des repères','',CM_GUIDE_SNAP);
 AddItem(2,'Ajouter un repère...','',CM_GUIDE_ADD);
 AddItem(2,'Effacer les repères','',CM_GUIDE_CLEAR);

 SetMenuTitle(3,'Page');
 AddItem(3,'Page A4','',CM_PAGE_A4);
 AddItem(3,'Page A5','',CM_PAGE_A5);
 AddItem(3,'Page A3','',CM_PAGE_A3);
 AddItem(3,'Page Lettre','',CM_PAGE_LET);
 AddSep(3);
 AddItem(3,'Orientation portrait','',CM_PORTRAIT);
 AddItem(3,'Orientation paysage','',CM_LANDSCAPE);
 AddSep(3);
 AddItem(3,'Pas de la grille...','',CM_GRIDSIZE);
 AddSep(3);
 AddItem(3,'Gestionnaire de calques...','',CM_LAYERS);
 AddSep(3);
 AddItem(3,'Page suivante','',CM_PAGE_NEXT);
 AddItem(3,'Page précédente','',CM_PAGE_PREV);
 AddItem(3,'Insérer une page','',CM_PAGE_ADD);
 AddItem(3,'Supprimer la page','',CM_PAGE_DEL);
 AddItem(3,'Page maîtresse','',CM_PAGE_MASTER);

 SetMenuTitle(4,'Organiser');
 AddItem(4,'Premier plan','Ctrl+PgHaut',CM_FRONT);
 AddItem(4,'Arrière-plan','Ctrl+PgBas',CM_BACK);
 AddItem(4,'Avancer d''un plan','PgHaut',CM_FWD);
 AddItem(4,'Reculer d''un plan','PgBas',CM_BWD);
 AddSep(4);
 AddItem(4,'Grouper','Ctrl+G',CM_GROUP);
 AddItem(4,'Dégrouper','Ctrl+U',CM_UNGROUP);
 AddSep(4);
 AddItem(4,'Aligner à gauche','',CM_AL_L);
 AddItem(4,'Centrer horizontalement','',CM_AL_C);
 AddItem(4,'Aligner à droite','',CM_AL_R);
 AddItem(4,'Aligner en haut','',CM_AL_T);
 AddItem(4,'Centrer verticalement','',CM_AL_M);
 AddItem(4,'Aligner en bas','',CM_AL_B);
 AddItem(4,'Répartir horizontalement','',CM_DISTH);
 AddItem(4,'Répartir verticalement','',CM_DISTV);
 AddSep(4);
 AddItem(4,'Rotation de 90°','Ctrl+R',CM_ROT90);
 AddItem(4,'Miroir horizontal','',CM_FLIPH);
 AddItem(4,'Miroir vertical','',CM_FLIPV);
 AddSep(4);
 AddItem(4,'Convertir en courbes','Ctrl+Q',CM_TOCURVE);

 SetMenuTitle(5,'Effets');
 AddItem(5,'Remplissage uniforme...','',CM_FILL_SOLID);
 AddItem(5,'Dégradé vertical...','',CM_FILL_GV);
 AddItem(5,'Dégradé horizontal...','',CM_FILL_GH);
 AddItem(5,'Dégradé radial...','',CM_FILL_RAD);
 AddItem(5,'Dégradé conique...','',CM_FILL_CON);
 AddItem(5,'Dégradé carré...','',CM_FILL_SQ);
 AddItem(5,'Couleur CMJN...','',CM_FILL_CMYK);
 AddItem(5,'Motif...','',CM_FILL_PAT);
 AddItem(5,'Sans remplissage','',CM_FILL_NONE);
 AddSep(5);
 AddItem(5,'Couleur du contour...','',CM_OUT_COLOR);
 AddItem(5,'Sans contour','',CM_OUT_NONE);
 AddItem(5,'Épaisseur du contour...','',CM_OUT_WIDTH);
 AddItem(5,'Style du contour...','',CM_OUT_STYLE);
 AddSep(5);
 AddItem(5,'Ombre portée','',CM_SHADOW);
 AddItem(5,'Extrusion','',CM_EXTRUDE);

 SetMenuTitle(6,'Texte');
 AddItem(6,'Modifier le texte...','F8',CM_TEXT_EDIT);
 AddItem(6,'Agrandir','',CM_TEXT_BIG);
 AddItem(6,'Réduire','',CM_TEXT_SMALL);

 SetMenuTitle(7,'Outils');
 AddItem(7,'Nombre de côtés...','',CM_SIDES);
 AddItem(7,'Styles par défaut','',CM_RESETDEF);
 AddItem(7,'Statistiques du dessin...','',CM_STATS);
 AddSep(7);
 AddItem(7,'Cote horizontale','',CM_DIM_H);
 AddItem(7,'Cote verticale','',CM_DIM_V);
 AddItem(7,'Connecteur','',CM_CONNECT);
 AddSep(7);
 AddItem(7,'Sélectionner même remplissage','',CM_SEL_FILL);
 AddItem(7,'Sélectionner même contour','',CM_SEL_OUT);
 AddItem(7,'Sélectionner même type','',CM_SEL_TYPE);
 AddItem(7,'Remplacer une couleur...','',CM_REPLACE);

 SetMenuTitle(8,'Formes');
 AddItem(8,'Souder','',CM_B_WELD);
 AddItem(8,'Intersection','',CM_B_INTER);
 AddItem(8,'Avant moins arrière','',CM_B_FMB);
 AddItem(8,'Arrière moins avant','',CM_B_BMF);
 AddItem(8,'Couteau (forme + ligne)','',CM_B_KNIFE);
 AddItem(8,'Combiner','',CM_COMBINE);
 AddItem(8,'Séparer','',CM_BREAK);
 AddSep(8);
 AddItem(8,'Rotation...','[ ]',CM_ROTATE);
 AddItem(8,'Inclinaison...','',CM_SKEW);
 AddItem(8,'Échelle / miroir...','',CM_SCALE);
 AddItem(8,'Perspective / enveloppe...','',CM_WARP);
 AddSep(8);
 AddItem(8,'Mélange...','',CM_BLEND);
 AddItem(8,'Contour...','',CM_CONTOUR);
 AddSep(8);
 AddItem(8,'Nœud : segment en ligne','',CM_N_LINE);
 AddItem(8,'Nœud : segment en courbe','',CM_N_CURVE);
 AddItem(8,'Nœud lisse','',CM_N_SMOOTH);
 AddItem(8,'Nœud symétrique','',CM_N_SYM);
 AddItem(8,'Nœud anguleux','',CM_N_CUSP);
 AddItem(8,'Casser le chemin au nœud','',CM_N_BREAK);
 AddItem(8,'Fermer le chemin','',CM_N_CLOSE);

 SetMenuTitle(9,'Aide');
 AddItem(9,'Raccourcis clavier...','F1',CM_HELPKEYS);
 AddItem(9,'À propos...','',CM_ABOUT);

 SetMenuTitle(POPUP_IDX,'');
 FinishMenus;
 MenuIdx:=-1;
 MenuItemSel:=-1;
End;

Function FirstSel:PObj;
Var I:LongInt;
Begin
 FirstSel:=NIL;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel Then Begin
   FirstSel:=ObjAt(I);
   Exit;
  End;
End;

Function IsChecked(Cmd:Integer):Boolean;
Var O:PObj;
Begin
 IsChecked:=False;
 Case Cmd Of
  CM_WIRE:IsChecked:=WireMode;
  CM_GRID:IsChecked:=ShowGrid;
  CM_RULERS:IsChecked:=ShowRulers;
  CM_SNAP:IsChecked:=SnapGrid;
  CM_GUIDES:IsChecked:=ShowGuides;
  CM_GUIDE_SNAP:IsChecked:=SnapGuides;
  CM_PAGE_MASTER:IsChecked:=EditMaster;
  CM_SHADOW:Begin O:=FirstSel; IsChecked:=(O<>NIL)and O^.Shadow; End;
  CM_EXTRUDE:Begin O:=FirstSel; IsChecked:=(O<>NIL)and O^.Extrude; End;
 End;
End;

Function IsEnabled(Cmd:Integer):Boolean;
Var N:Integer;
Begin
 N:=SelCount;
 Case Cmd Of
  CM_UNDO:IsEnabled:=UndoCnt>0;
  CM_REDO:IsEnabled:=RedoCnt>0;
  CM_CUT,CM_COPY,CM_DUP,CM_DEL,CM_FRONT,CM_BACK,CM_FWD,CM_BWD,CM_ROT90,
  CM_FLIPH,CM_FLIPV,CM_TOCURVE,CM_FILL_SOLID,CM_FILL_GV,CM_FILL_GH,CM_FILL_RAD,CM_FILL_PAT,
  CM_FILL_NONE,CM_OUT_COLOR,CM_OUT_NONE,CM_OUT_WIDTH,CM_OUT_STYLE,CM_SHADOW,
  CM_EXTRUDE,CM_ZSEL,CM_TEXT_EDIT,CM_TEXT_BIG,CM_TEXT_SMALL:IsEnabled:=N>0;
  CM_GROUP,CM_AL_L,CM_AL_C,CM_AL_R,CM_AL_T,CM_AL_M,CM_AL_B:IsEnabled:=N>1;
  CM_DISTH,CM_DISTV:IsEnabled:=N>2;
  CM_UNGROUP:IsEnabled:=N>0;
  CM_PASTE:IsEnabled:=(ClipSnap<>NIL)and(ClipSnap^.N>0);
  CM_B_WELD,CM_B_INTER,CM_B_FMB,CM_B_BMF,CM_COMBINE,CM_BLEND,CM_CONNECT:IsEnabled:=N>1;
  CM_B_KNIFE:IsEnabled:=N=2;
  CM_BREAK,CM_ROTATE,CM_SKEW,CM_SCALE,CM_WARP,CM_CONTOUR,CM_ROT_L,CM_ROT_R,
  CM_DIM_H,CM_DIM_V,CM_SEL_FILL,CM_SEL_OUT,CM_SEL_TYPE,CM_N_CLOSE,
  CM_FILL_CON,CM_FILL_SQ,CM_FILL_CMYK:IsEnabled:=N>0;
  CM_PAGE_PREV:IsEnabled:=CurPage>1;
  CM_PAGE_NEXT:IsEnabled:=CurPage<PageCnt;
  CM_PAGE_DEL:IsEnabled:=(PageCnt>1)and Not EditMaster;
  CM_PAGE_ADD:IsEnabled:=(PageCnt<PAGE_MAX)and Not EditMaster;
 Else IsEnabled:=True;
 End;
End;

Function ItemTop(Var M:TMenu;I:Integer):Integer;
Var K,Y:Integer;
Begin
 Y:=3;
 For K:=0 To I-1 Do
  If M.It[K].Cmd=0 Then Inc(Y,SEP_H) Else Inc(Y,ITEM_H);
 ItemTop:=Y;
End;

Function MenuHeight(Var M:TMenu):Integer;
Begin
 MenuHeight:=ItemTop(M,M.N)+3;
End;

Function MenuItemAt(Idx,SX,SY:Integer):Integer;
Var I,Y:Integer;
Begin
 MenuItemAt:=-1;
 If Idx<0 Then Exit;
 With Menus[Idx] Do Begin
  If(SX<X)or(SX>=X+W)or(SY<Y)or(SY>=Y+MenuHeight(Menus[Idx]))Then Exit;
  For I:=0 To N-1 Do Begin
   Y:=Menus[Idx].Y+ItemTop(Menus[Idx],I);
   If It[I].Cmd<>0 Then
    If(SY>=Y)and(SY<Y+ITEM_H)Then Begin
     MenuItemAt:=I;
     Exit;
    End;
  End;
 End;
End;

Function MenuBarAt(SX,SY:Integer):Integer;
Var I:Integer;
Begin
 MenuBarAt:=-1;
 If SY>=MENUBAR_H Then Exit;
 For I:=0 To MENU_COUNT-1 Do
  If(SX>=Menus[I].X-5)and(SX<Menus[I].X+TxtW(Menus[I].Title)+7)Then Begin
   MenuBarAt:=I;
   Exit;
  End;
End;

Procedure DrawMenuBar;
Var I:Integer;
Begin
 Panel(0,0,ScreenW-1,MENUBAR_H-1,True);
 For I:=0 To MENU_COUNT-1 Do Begin
  If MenuIdx=I Then Begin
   Box(Menus[I].X-5,1,Menus[I].X+TxtW(Menus[I].Title)+6,MENUBAR_H-2,UI_SEL);
   SetCol(15);
  End
   Else SetCol(0);
  TxtOut(Menus[I].X,5,Menus[I].Title);
 End;
End;

Procedure DrawDrop(Idx:Integer);
Var I,Y,X0,Y0,H:Integer;
Begin
 If Idx<0 Then Exit;
 X0:=Menus[Idx].X;
 Y0:=Menus[Idx].Y;
 H:=MenuHeight(Menus[Idx]);
 Box(X0+3,Y0+3,X0+Menus[Idx].W+3,Y0+H+3,8);
 Panel(X0,Y0,X0+Menus[Idx].W-1,Y0+H-1,True);
 For I:=0 To Menus[Idx].N-1 Do Begin
  Y:=Y0+ItemTop(Menus[Idx],I);
  If Menus[Idx].It[I].Cmd=0 Then Begin
   SetCol(UI_SH);
   Line(X0+4,Y+3,X0+Menus[Idx].W-5,Y+3);
   SetCol(UI_HI);
   Line(X0+4,Y+4,X0+Menus[Idx].W-5,Y+4);
  End
   Else
  Begin
   If I=MenuItemSel Then Begin
    Box(X0+2,Y,X0+Menus[Idx].W-3,Y+ITEM_H-1,UI_SEL);
    SetCol(15);
   End
    Else
   If IsEnabled(Menus[Idx].It[I].Cmd)Then SetCol(0) Else SetCol(UI_SH);
   If IsChecked(Menus[Idx].It[I].Cmd)Then TxtOut(X0+6,Y+4,#251);
   TxtOut(X0+20,Y+4,Menus[Idx].It[I].Cap);
   If Menus[Idx].It[I].Short<>'' Then
    TxtOut(X0+Menus[Idx].W-TxtW(Menus[Idx].It[I].Short)-8,Y+4,Menus[Idx].It[I].Short);
  End;
 End;
End;

{ ------------------------------------------------------------------ }
{ Barre d'icones, boite a outils, palette, regles, etat              }
{ ------------------------------------------------------------------ }

Const
 ICON_COUNT=20;
 TOOLBOX_Y0=66;
 TOOL_SIZE=18;

Var
 IconX:Array[0..ICON_COUNT-1] of Integer;
 IconCmd:Array[0..ICON_COUNT-1] of Integer;
 CurFillSwatch,CurOutSwatch:Integer;

Procedure InitIconBar;
Var I,X:Integer;
Const
 Cmds:Array[0..ICON_COUNT-1] of Integer=(CM_NEW,CM_OPEN,CM_SAVE,-1,CM_CUT,CM_COPY,
  CM_PASTE,-1,CM_UNDO,CM_REDO,-1,CM_ZIN,CM_ZOUT,CM_ZFIT,CM_WIRE,-1,CM_GROUP,
  CM_UNGROUP,CM_FRONT,CM_BACK);
Begin
 X:=4;
 For I:=0 To ICON_COUNT-1 Do Begin
  IconCmd[I]:=Cmds[I];
  IconX[I]:=X;
  If Cmds[I]=-1 Then Inc(X,8) Else Inc(X,22);
 End;
End;

Procedure DrawIconGlyph(Cmd,X,Y:Integer);
Begin
 SetLineStyle(SolidLn,0,NormWidth);
 Case Cmd Of
  CM_NEW:Begin
   Box(X+4,Y+2,X+13,Y+15,15);
   SetCol(0); Rectangle(X+4,Y+2,X+13,Y+15);
  End;
  CM_OPEN:Begin
   Box(X+2,Y+6,X+15,Y+14,14);
   SetCol(0); Rectangle(X+2,Y+6,X+15,Y+14);
   Box(X+2,Y+4,X+7,Y+6,14);
   Rectangle(X+2,Y+4,X+7,Y+6);
  End;
  CM_SAVE:Begin
   Box(X+2,Y+2,X+14,Y+14,1);
   Box(X+5,Y+2,X+11,Y+6,15);
   Box(X+5,Y+9,X+11,Y+14,7);
   SetCol(0); Rectangle(X+2,Y+2,X+14,Y+14);
  End;
  CM_CUT:Begin
   SetCol(0);
   Line(X+4,Y+2,X+11,Y+11);
   Line(X+12,Y+2,X+5,Y+11);
   Circle(X+4,Y+13,2);
   Circle(X+12,Y+13,2);
  End;
  CM_COPY:Begin
   Box(X+2,Y+2,X+9,Y+11,15);
   SetCol(0); Rectangle(X+2,Y+2,X+9,Y+11);
   Box(X+6,Y+6,X+13,Y+15,15);
   SetCol(0); Rectangle(X+6,Y+6,X+13,Y+15);
  End;
  CM_PASTE:Begin
   Box(X+2,Y+3,X+11,Y+14,6);
   Box(X+5,Y+1,X+8,Y+4,7);
   Box(X+7,Y+7,X+14,Y+15,15);
   SetCol(0); Rectangle(X+7,Y+7,X+14,Y+15);
  End;
  CM_UNDO:Begin
   SetCol(0);
   Arc(X+8,Y+9,0,180,5);
   Line(X+3,Y+9,X+3,Y+4);
   Line(X+3,Y+9,X+7,Y+9);
  End;
  CM_REDO:Begin
   SetCol(0);
   Arc(X+8,Y+9,0,180,5);
   Line(X+13,Y+9,X+13,Y+4);
   Line(X+13,Y+9,X+9,Y+9);
  End;
  CM_ZIN,CM_ZOUT:Begin
   SetCol(0);
   Circle(X+7,Y+7,5);
   Line(X+11,Y+11,X+15,Y+15);
   Line(X+4,Y+7,X+10,Y+7);
   If Cmd=CM_ZIN Then Line(X+7,Y+4,X+7,Y+10);
  End;
  CM_ZFIT:Begin
   SetCol(0);
   Rectangle(X+3,Y+2,X+13,Y+14);
   Box(X+4,Y+3,X+12,Y+13,15);
   SetCol(4);
   Rectangle(X+1,Y+1,X+15,Y+15);
  End;
  CM_WIRE:Begin
   SetCol(0);
   Rectangle(X+2,Y+3,X+14,Y+13);
   Circle(X+8,Y+8,4);
  End;
  CM_GROUP:Begin
   SetCol(0);
   Rectangle(X+1,Y+1,X+14,Y+14);
   Box(X+3,Y+3,X+8,Y+8,12);
   Rectangle(X+3,Y+3,X+8,Y+8);
   Box(X+7,Y+7,X+12,Y+12,9);
   Rectangle(X+7,Y+7,X+12,Y+12);
  End;
  CM_UNGROUP:Begin
   SetCol(0);
   Box(X+1,Y+1,X+7,Y+7,12);
   Rectangle(X+1,Y+1,X+7,Y+7);
   Box(X+9,Y+9,X+15,Y+15,9);
   Rectangle(X+9,Y+9,X+15,Y+15);
  End;
  CM_FRONT:Begin
   Box(X+2,Y+2,X+9,Y+9,9);
   Box(X+6,Y+6,X+13,Y+13,12);
   SetCol(0); Rectangle(X+2,Y+2,X+9,Y+9); Rectangle(X+6,Y+6,X+13,Y+13);
  End;
  CM_BACK:Begin
   Box(X+6,Y+6,X+13,Y+13,12);
   Box(X+2,Y+2,X+9,Y+9,9);
   SetCol(0); Rectangle(X+6,Y+6,X+13,Y+13); Rectangle(X+2,Y+2,X+9,Y+9);
  End;
 End;
End;

Procedure DrawIconBar;
Var I,J,K:Integer;
    On:Boolean;
Begin
 Panel(0,ICONBAR_TOP,ScreenW-1,ICONBAR_TOP+ICONBAR_H-1,True);
 For I:=0 To ICON_COUNT-1 Do
  If IconCmd[I]=-1 Then Begin
   SetCol(UI_SH);
   Line(IconX[I]+3,ICONBAR_TOP+4,IconX[I]+3,ICONBAR_TOP+ICONBAR_H-5);
  End
   Else
  Begin
   On:=(IconCmd[I]=CM_WIRE)and WireMode;
   If IsEnabled(IconCmd[I])Then Begin
    Box(IconX[I],ICONBAR_TOP+2,IconX[I]+19,ICONBAR_TOP+ICONBAR_H-3,UI_BG);
    Bevel(IconX[I],ICONBAR_TOP+2,IconX[I]+19,ICONBAR_TOP+ICONBAR_H-3,Not On);
    DrawIconGlyph(IconCmd[I],IconX[I]+2,ICONBAR_TOP+4);
   End
    Else
   Begin
    Box(IconX[I],ICONBAR_TOP+2,IconX[I]+19,ICONBAR_TOP+ICONBAR_H-3,UI_BG);
    Bevel(IconX[I],ICONBAR_TOP+2,IconX[I]+19,ICONBAR_TOP+ICONBAR_H-3,True);
    DrawIconGlyph(IconCmd[I],IconX[I]+2,ICONBAR_TOP+4);
    { voile grise pour les commandes inactives }
    For K:=IconX[I]+2 To IconX[I]+17 Do
     For J:=ICONBAR_TOP+4 To ICONBAR_TOP+ICONBAR_H-5 Do
      If Not Odd(K+J)Then PutPixel(K,J,HWMap[UI_BG]);
   End;
  End;
End;

Function IconAt(SX,SY:Integer):Integer;
Var I:Integer;
Begin
 IconAt:=-1;
 If(SY<ICONBAR_TOP)or(SY>=ICONBAR_TOP+ICONBAR_H)Then Exit;
 For I:=0 To ICON_COUNT-1 Do
  If(IconCmd[I]<>-1)and(SX>=IconX[I])and(SX<IconX[I]+20)Then Begin
   IconAt:=IconCmd[I];
   Exit;
  End;
End;

{ Boite a outils }
Procedure ToolPos(T:Integer;Var X,Y:Integer);
Begin
 X:=2+(T Mod 2)*19;
 Y:=TOOLBOX_Y0+(T Div 2)*19;
End;

Function ToolAt(SX,SY:Integer):Integer;
Var T,X,Y:Integer;
Begin
 ToolAt:=-1;
 For T:=0 To TOOL_COUNT-1 Do Begin
  ToolPos(T,X,Y);
  If InRect(SX,SY,X,Y,TOOL_SIZE,TOOL_SIZE)Then Begin
   ToolAt:=T;
   Exit;
  End;
 End;
End;

Procedure DrawToolGlyph(T,X,Y:Integer);
Var P:Array[0..4] of PointType;
    I:Integer;
    A:Real;
Begin
 SetCol(0);
 SetLineStyle(SolidLn,0,NormWidth);
 Case T Of
  T_PICK:Begin
   P[0].X:=X+5; P[0].Y:=Y+2;
   P[1].X:=X+5; P[1].Y:=Y+14;
   P[2].X:=X+8; P[2].Y:=Y+11;
   P[3].X:=X+12; P[3].Y:=Y+11;
   P[4].X:=X+5; P[4].Y:=Y+2;
   SetFillCol(0);
   FillPoly(5,P);
  End;
  T_SHAPE:Begin
   Arc(X+9,Y+13,30,150,9);
   SetCol(0);
   Rectangle(X+2,Y+9,X+5,Y+12);
   Box(X+13,Y+9,X+16,Y+12,0);
   Rectangle(X+9,Y+3,X+12,Y+6);
  End;
  T_ZOOM:Begin
   Circle(X+7,Y+7,5);
   Line(X+11,Y+11,X+15,Y+15);
   Line(X+7,Y+4,X+7,Y+10);
   Line(X+4,Y+7,X+10,Y+7);
  End;
  T_HAND:Begin
   Rectangle(X+5,Y+7,X+13,Y+14);
   Line(X+5,Y+7,X+5,Y+3);
   Line(X+7,Y+7,X+7,Y+2);
   Line(X+9,Y+7,X+9,Y+2);
   Line(X+11,Y+7,X+11,Y+3);
   Line(X+13,Y+9,X+16,Y+7);
  End;
  T_LINE:Line(X+3,Y+14,X+14,Y+3);
  T_POLYLINE:Begin
   Line(X+2,Y+13,X+6,Y+4);
   Line(X+6,Y+4,X+10,Y+12);
   Line(X+10,Y+12,X+15,Y+3);
  End;
  T_CURVE:Begin
   Arc(X+5,Y+9,270,360,5);
   Arc(X+13,Y+9,90,180,5);
   Line(X+5,Y+4,X+13,Y+14);
  End;
  T_RECT:Rectangle(X+3,Y+4,X+14,Y+13);
  T_ELLIPSE:Ellipse(X+9,Y+9,0,360,6,5);
  T_POLYGON:Begin
   Line(X+9,Y+2,X+15,Y+6);
   Line(X+15,Y+6,X+13,Y+14);
   Line(X+13,Y+14,X+5,Y+14);
   Line(X+5,Y+14,X+3,Y+6);
   Line(X+3,Y+6,X+9,Y+2);
  End;
  T_STAR:Begin
   For I:=0 To 4 Do Begin
    A:=-Pi/2+I*4*Pi/5;
    P[I].X:=X+9+Round(7*Cos(A));
    P[I].Y:=Y+9+Round(7*Sin(A));
   End;
   For I:=0 To 4 Do
    Line(P[I].X,P[I].Y,P[(I+1) Mod 5].X,P[(I+1) Mod 5].Y);
  End;
  T_TEXT:Begin
   TxtOut(X+5,Y+5,'A');
   TxtOut(X+6,Y+5,'A');
  End;
 End;
End;

Procedure DrawToolbox;
Var T,X,Y:Integer;
Begin
 Panel(0,PROPBAR_TOP+PROPBAR_H,TOOLBOX_W-1,PaletteY-1,True);
 For T:=0 To TOOL_COUNT-1 Do Begin
  ToolPos(T,X,Y);
  Box(X,Y,X+TOOL_SIZE-1,Y+TOOL_SIZE-1,UI_BG);
  Bevel(X,Y,X+TOOL_SIZE-1,Y+TOOL_SIZE-1,T<>CurTool);
  If T=CurTool Then Box(X+1,Y+1,X+TOOL_SIZE-2,Y+TOOL_SIZE-2,UI_HI);
  DrawToolGlyph(T,X,Y);
 End;
End;

Function ToolName(T:Integer):String;
Begin
 Case T Of
  T_PICK:ToolName:='Pointeur : sélection, déplacement, redimensionnement';
  T_SHAPE:ToolName:='Forme : glisser les noeuds, double-clic = ajouter, Suppr = retirer';
  T_ZOOM:ToolName:='Zoom : clic = avant, clic droit = arrière, glisser = zone';
  T_HAND:ToolName:='Main : glisser pour déplacer la vue';
  T_LINE:ToolName:='Ligne : glisser';
  T_POLYLINE:ToolName:='Polyligne : clics, double-clic ou clic droit = fin';
  T_CURVE:ToolName:='Courbe : clics, double-clic ou clic droit = fin';
  T_RECT:ToolName:='Rectangle : glisser';
  T_ELLIPSE:ToolName:='Ellipse : glisser';
  T_POLYGON:ToolName:='Polygone : glisser (côtés dans la barre de propriétés)';
  T_STAR:ToolName:='Étoile : glisser (pointes dans la barre de propriétés)';
  T_TEXT:ToolName:='Texte artistique : cliquer sur la page';
 Else ToolName:='';
 End;
End;

{ Palette de couleurs }
Function PalSwatchX(I:Integer):Integer;
Begin
 PalSwatchX:=22+I*12;
End;

Procedure DrawPalette;
Var I:Integer;
Begin
 Panel(0,PaletteY,ScreenW-1,PaletteY+PALETTE_H-1,True);
 { Case "aucune couleur" }
 Box(4,PaletteY+4,16,PaletteY+16,15);
 SetCol(0);
 Rectangle(4,PaletteY+4,16,PaletteY+16);
 SetCol(4);
 Line(5,PaletteY+15,15,PaletteY+5);
 For I:=0 To PAL_COUNT-1 Do Begin
  Box(PalSwatchX(I),PaletteY+4,PalSwatchX(I)+10,PaletteY+16,I);
  SetCol(0);
  Rectangle(PalSwatchX(I),PaletteY+4,PalSwatchX(I)+10,PaletteY+16);
 End;
End;

{ -1 = aucune couleur, -2 = hors palette }
Function PaletteAt(SX,SY:Integer):Integer;
Var I:Integer;
Begin
 PaletteAt:=-2;
 If(SY<PaletteY+4)or(SY>PaletteY+16)Then Exit;
 If(SX>=4)and(SX<=16)Then Begin
  PaletteAt:=-1;
  Exit;
 End;
 For I:=0 To PAL_COUNT-1 Do
  If(SX>=PalSwatchX(I))and(SX<=PalSwatchX(I)+10)Then Begin
   PaletteAt:=I;
   Exit;
  End;
End;

{ Regles }
Procedure RulerStep(Var Major,Minor:LongInt);
Const Steps:Array[0..8] of Integer=(10,20,50,100,200,500,1000,2000,5000);
Var I:Integer;
Begin
 Major:=5000;
 For I:=0 To 8 Do
  If(LongInt(Steps[I])*Zoom) Div 1000>=44 Then Begin
   Major:=Steps[I];
   Break;
  End;
 Minor:=Major Div 5;
 If Minor<1 Then Minor:=1;
End;

Procedure DrawRulers;
Var Major,Minor,V,S:LongInt;
    VW,VH:LongInt;
Begin
 Box(CanvasX-RULER_SIZE,CanvasY-RULER_SIZE,CanvasX-1,CanvasY-1,UI_BG);
 If Not ShowRulers Then Begin
  Box(CanvasX,CanvasY-RULER_SIZE,CanvasX+CanvasW-1,CanvasY-1,UI_BG);
  Box(CanvasX-RULER_SIZE,CanvasY,CanvasX-1,CanvasY+CanvasH-1,UI_BG);
  Exit;
 End;
 RulerStep(Major,Minor);
 ViewWorld(VW,VH);
 { Regle horizontale }
 SetViewPort(CanvasX,CanvasY-RULER_SIZE,CanvasX+CanvasW-1,CanvasY-1,True);
 Box(0,0,CanvasW-1,RULER_SIZE-1,UI_BG);
 SetCol(0);
 V:=(OrgX Div Minor)*Minor;
 While V<=OrgX+VW Do Begin
  S:=W2SX(V);
  If V Mod Major=0 Then Begin
   Line(S,3,S,RULER_SIZE-1);
   TxtOut(S+2,2,IStr(V Div 10));
  End
   Else Line(S,8,S,RULER_SIZE-1);
  Inc(V,Minor);
 End;
 Line(0,RULER_SIZE-1,CanvasW-1,RULER_SIZE-1);
 { Regle verticale }
 SetViewPort(CanvasX-RULER_SIZE,CanvasY,CanvasX-1,CanvasY+CanvasH-1,True);
 Box(0,0,RULER_SIZE-1,CanvasH-1,UI_BG);
 SetCol(0);
 V:=(OrgY Div Minor)*Minor;
 While V<=OrgY+VH Do Begin
  S:=W2SY(V);
  If V Mod Major=0 Then Begin
   Line(3,S,RULER_SIZE-1,S);
   SetTextStyle(DefaultFont,VertDir,1);
   OutTextXY(2,S+2,IStr(V Div 10));
   SetTextStyle(DefaultFont,HorizDir,1);
  End
   Else Line(8,S,RULER_SIZE-1,S);
  Inc(V,Minor);
 End;
 Line(RULER_SIZE-1,0,RULER_SIZE-1,CanvasH-1);
 EndCanvas;
End;

{ Barres de defilement }
Procedure ScrollThumb(Horiz:Boolean;Var T1,T2,Track:Integer);
Var VW,VH,Range,View,Off,Len,Pos:LongInt;
Begin
 ViewWorld(VW,VH);
 If Horiz Then Begin
  Range:=PageW+3000; View:=VW; Off:=OrgX+1500; Track:=CanvasW-2;
 End
  Else
 Begin
  Range:=PageH+3000; View:=VH; Off:=OrgY+1500; Track:=CanvasH-2;
 End;
 Len:=(Track*View) Div Range;
 If Len<16 Then Len:=16;
 If Len>Track Then Len:=Track;
 If Range>View Then Pos:=((Track-Len)*Off) Div (Range-View) Else Pos:=0;
 Pos:=Clamp(Pos,0,Track-Len);
 T1:=Pos;
 T2:=Pos+Len;
End;

Procedure DrawScrollbars;
Var T1,T2,Tr:Integer;
Begin
 Box(CanvasX,CanvasY+CanvasH,CanvasX+CanvasW-1,CanvasY+CanvasH+SCROLL_W-1,UI_BG);
 Bevel(CanvasX,CanvasY+CanvasH,CanvasX+CanvasW-1,CanvasY+CanvasH+SCROLL_W-1,False);
 ScrollThumb(True,T1,T2,Tr);
 Panel(CanvasX+1+T1,CanvasY+CanvasH+1,CanvasX+1+T2,CanvasY+CanvasH+SCROLL_W-2,True);
 Box(CanvasX+CanvasW,CanvasY,CanvasX+CanvasW+SCROLL_W-1,CanvasY+CanvasH-1,UI_BG);
 Bevel(CanvasX+CanvasW,CanvasY,CanvasX+CanvasW+SCROLL_W-1,CanvasY+CanvasH-1,False);
 ScrollThumb(False,T1,T2,Tr);
 Panel(CanvasX+CanvasW+1,CanvasY+1+T1,CanvasX+CanvasW+SCROLL_W-2,CanvasY+1+T2,True);
 Box(CanvasX+CanvasW,CanvasY+CanvasH,CanvasX+CanvasW+SCROLL_W-1,CanvasY+CanvasH+SCROLL_W-1,UI_BG);
End;

{ Barre de proprietes }
Const
 PB_W0=262;
 PB_FILL0=372;
 PB_SHADOW=476;
 PB_EXTRUDE=508;
 PB_NUM=544;

Function PropBarAt(SX,SY:Integer):Integer;
Var I:Integer;
Begin
 PropBarAt:=0;
 If(SY<PROPBAR_TOP+1)or(SY>=PROPBAR_TOP+PROPBAR_H)Then Exit;
 For I:=0 To 4 Do
  If InRect(SX,SY,PB_W0+I*22,PROPBAR_TOP+2,20,PROPBAR_H-4)Then Begin
   PropBarAt:=CM_W1+I;
   Exit;
  End;
 If InRect(SX,SY,PB_FILL0,PROPBAR_TOP+2,24,PROPBAR_H-4)Then PropBarAt:=CM_FILL_NONE
 Else If InRect(SX,SY,PB_FILL0+26,PROPBAR_TOP+2,24,PROPBAR_H-4)Then PropBarAt:=CM_FILL_SOLID
 Else If InRect(SX,SY,PB_FILL0+52,PROPBAR_TOP+2,24,PROPBAR_H-4)Then PropBarAt:=CM_FILL_GV
 Else If InRect(SX,SY,PB_FILL0+78,PROPBAR_TOP+2,24,PROPBAR_H-4)Then PropBarAt:=CM_FILL_GH
 Else If InRect(SX,SY,PB_SHADOW,PROPBAR_TOP+2,30,PROPBAR_H-4)Then PropBarAt:=CM_SHADOW
 Else If InRect(SX,SY,PB_EXTRUDE,PROPBAR_TOP+2,30,PROPBAR_H-4)Then PropBarAt:=CM_EXTRUDE
 Else If InRect(SX,SY,PB_NUM,PROPBAR_TOP+2,14,PROPBAR_H-4)Then PropBarAt:=CM_SIDES_DN
 Else If InRect(SX,SY,PB_NUM+50,PROPBAR_TOP+2,14,PROPBAR_H-4)Then PropBarAt:=CM_SIDES_UP;
End;

Procedure PBButton(X:Integer;Down:Boolean);
Begin
 Box(X,PROPBAR_TOP+2,X+19,PROPBAR_TOP+PROPBAR_H-3,UI_BG);
 Bevel(X,PROPBAR_TOP+2,X+19,PROPBAR_TOP+PROPBAR_H-3,Not Down);
End;

Procedure DrawPropBar;
Var X1,Y1,X2,Y2:LongInt;
    S:String;
    I:Integer;
    O:PObj;
    WCur:LongInt;
Const WV:Array[0..4] of Integer=(1,2,5,10,20);
Begin
 Panel(0,PROPBAR_TOP,ScreenW-1,PROPBAR_TOP+PROPBAR_H-1,True);
 SetCol(0);
 O:=FirstSel;
 If SelBBox(X1,Y1,X2,Y2)Then
  S:='X'+MMStr(X1)+' Y'+MMStr(Y1)+' L'+MMStr(X2-X1)+' H'+MMStr(Y2-Y1)
 Else S:='Page '+IStr(PageW Div 10)+' x '+IStr(PageH Div 10)+' mm';
 TxtOut(4,PROPBAR_TOP+6,S);
 If O<>NIL Then WCur:=O^.OutW Else WCur:=DefOutW;
 For I:=0 To 4 Do Begin
  PBButton(PB_W0+I*22,WV[I]=WCur);
  SetCol(0);
  SetFillCol(0);
  Bar(PB_W0+I*22+3,PROPBAR_TOP+PROPBAR_H Div 2-(Integer(Min(WV[I],6)) Div 2),
      PB_W0+I*22+16,PROPBAR_TOP+PROPBAR_H Div 2+(Integer(Min(WV[I],6)) Div 2));
 End;
 { Remplissages }
 For I:=0 To 3 Do PBButton(PB_FILL0+I*26,False);
 SetCol(4);
 Line(PB_FILL0+4,PROPBAR_TOP+15,PB_FILL0+15,PROPBAR_TOP+4);
 Box(PB_FILL0+26+5,PROPBAR_TOP+5,PB_FILL0+26+14,PROPBAR_TOP+14,12);
 Box(PB_FILL0+52+5,PROPBAR_TOP+5,PB_FILL0+52+14,PROPBAR_TOP+8,1);
 Box(PB_FILL0+52+5,PROPBAR_TOP+9,PB_FILL0+52+14,PROPBAR_TOP+11,9);
 Box(PB_FILL0+52+5,PROPBAR_TOP+12,PB_FILL0+52+14,PROPBAR_TOP+14,11);
 Box(PB_FILL0+78+5,PROPBAR_TOP+5,PB_FILL0+78+8,PROPBAR_TOP+14,4);
 Box(PB_FILL0+78+9,PROPBAR_TOP+5,PB_FILL0+78+11,PROPBAR_TOP+14,12);
 Box(PB_FILL0+78+12,PROPBAR_TOP+5,PB_FILL0+78+14,PROPBAR_TOP+14,14);
 { Ombre / extrusion }
 PBButton(PB_SHADOW,IsChecked(CM_SHADOW));
 SetCol(0);
 TxtOut(PB_SHADOW+2,PROPBAR_TOP+6,'Omb');
 PBButton(PB_EXTRUDE,IsChecked(CM_EXTRUDE));
 SetCol(0);
 TxtOut(PB_EXTRUDE+2,PROPBAR_TOP+6,'Ext');
 { Nombre de cotes / taille du texte }
 If(CurTool=T_POLYGON)or(CurTool=T_STAR)or(CurTool=T_TEXT)Then Begin
  PBButton(PB_NUM,False);
  SetCol(0);
  TxtOut(PB_NUM+6,PROPBAR_TOP+6,'-');
  PBButton(PB_NUM+50,False);
  SetCol(0);
  TxtOut(PB_NUM+56,PROPBAR_TOP+6,'+');
  If CurTool=T_TEXT Then S:=IStr(DefTextSize Div 10)+'mm' Else S:=IStr(PolySides);
  TxtOut(PB_NUM+22,PROPBAR_TOP+6,S);
 End;
End;

Procedure DrawStatus(Const CursorTxt:String);
Var O:PObj;
    S:String;
    N:Integer;
Begin
 Panel(0,ScreenH-STATUS_H,ScreenW-1,ScreenH-1,False);
 SetCol(0);
 N:=SelCount;
 If StatusMsg<>'' Then S:=StatusMsg
  Else
 If N=0 Then S:=ToolName(CurTool)
  Else
 If N>1 Then S:=IStr(N)+' objets sélectionnés'
  Else
 Begin
  O:=FirstSel;
  Case O^.Kind Of
   K_LINE:S:='Ligne';
   K_RECT:S:='Rectangle';
   K_BITMAP:S:='Bitmap';
   K_ELLIPSE:S:='Ellipse';
   K_POLY:S:='Polygone de '+IStr(O^.N)+' noeuds';
   K_POLYLINE:S:='Polyligne de '+IStr(O^.N)+' noeuds';
   K_BEZIER:S:='Courbe de '+IStr(O^.N)+' noeuds';
   K_TEXT:S:='Texte : '+O^.Txt;
  Else S:='Objet';
  End;
  S:=S+' sélectionné';
 End;
 If Length(Conv(S))>46 Then S:=Copy(S,1,46);
 TxtOut(4,ScreenH-STATUS_H+4,S);
 TxtOut(392,ScreenH-STATUS_H+4,CursorTxt);
 TxtOut(500,ScreenH-STATUS_H+4,IStr((Zoom*100) Div 378)+'%');
 If EditMaster Then TxtOut(552,ScreenH-STATUS_H+4,'Maître C'+IStr(ActLayer))
  Else TxtOut(552,ScreenH-STATUS_H+4,'P'+IStr(CurPage)+'/'+IStr(PageCnt)+' C'+IStr(ActLayer));
 { Couleurs courantes }
 O:=FirstSel;
 If O<>NIL Then Begin
  CurFillSwatch:=O^.FillCol;
  CurOutSwatch:=O^.OutCol;
 End
  Else
 Begin
  CurFillSwatch:=DefFill;
  CurOutSwatch:=DefOut;
 End;
 SetCol(0);
 TxtOut(552,ScreenH-STATUS_H+4,'R');
 If CurFillSwatch>=0 Then Box(562,ScreenH-STATUS_H+3,572,ScreenH-3,CurFillSwatch)
  Else Begin Box(562,ScreenH-STATUS_H+3,572,ScreenH-3,15); SetCol(4); Line(562,ScreenH-3,572,ScreenH-STATUS_H+3); End;
 SetCol(0);
 Rectangle(562,ScreenH-STATUS_H+3,572,ScreenH-3);
 TxtOut(582,ScreenH-STATUS_H+4,'C');
 If CurOutSwatch>=0 Then Box(592,ScreenH-STATUS_H+3,602,ScreenH-3,CurOutSwatch)
  Else Begin Box(592,ScreenH-STATUS_H+3,602,ScreenH-3,15); SetCol(4); Line(592,ScreenH-3,602,ScreenH-STATUS_H+3); End;
 SetCol(0);
 Rectangle(592,ScreenH-STATUS_H+3,602,ScreenH-3);
End;

{ ------------------------------------------------------------------ }
{ Boites de dialogue                                                 }
{ ------------------------------------------------------------------ }

Var
 ChItems:Array[0..19] of String[34];
 TLines:Array[0..29] of String[80];
 TN:Integer;

Procedure DrawWin(X,Y,W,H:Integer;Const Title:String);
Begin
 Box(X+4,Y+4,X+W+3,Y+H+3,8);
 Panel(X,Y,X+W-1,Y+H-1,True);
 Box(X+3,Y+3,X+W-4,Y+16,UI_SEL);
 SetCol(15);
 TxtOut(X+8,Y+6,Title);
End;

Procedure DrawBtn(X,Y,W,H:Integer;Const Cap:String;Down:Boolean);
Begin
 Panel(X,Y,X+W-1,Y+H-1,Not Down);
 SetCol(0);
 TxtOut(X+(W-TxtW(Cap)) Div 2,Y+(H-8) Div 2,Cap);
End;

Function GetKey(Var Ext:Boolean):Char;
Var C:Char;
Begin
 C:=ReadKey;
 Ext:=False;
 If C=#0 Then Begin
  Ext:=True;
  C:=ReadKey;
 End;
 GetKey:=C;
End;

Procedure WaitUp;
Begin
 Repeat
  PollMouse;
  Delay(5);
 Until MB=0;
 OldMB:=0;
End;

Function Pressed(Var Old:Integer):Boolean;
Begin
 Pressed:=((MB And 1)<>0)and((Old And 1)=0);
 Old:=MB;
End;

Procedure MsgBox(Const Title,L1,L2:String);
Var X,Y,W,H,Old:Integer;
    Done:Boolean;
    K:Char;
    Ext:Boolean;
Begin
 W:=380; H:=110;
 X:=(ScreenW-W) Div 2;
 Y:=(ScreenH-H) Div 2;
 MouseOff;
 DrawWin(X,Y,W,H,Title);
 SetCol(0);
 TxtOut(X+14,Y+30,L1);
 TxtOut(X+14,Y+46,L2);
 DrawBtn(X+W Div 2-30,Y+H-30,60,20,'OK',False);
 MouseOn;
 WaitUp;
 Old:=0;
 Done:=False;
 Repeat
  PollMouse;
  If Pressed(Old)Then
   If InRect(MX,MY,X+W Div 2-30,Y+H-30,60,20)Then Done:=True;
  If KeyPressed Then Begin
   K:=GetKey(Ext);
   If(K=#13)or(K=#27)or(K=' ')Then Done:=True;
  End;
  Delay(10);
 Until Done;
 WaitUp;
End;

{ Retourne 1 = Oui, 2 = Non, 0 = Annuler }
Function Ask3(Const Title,Msg:String;Three:Boolean):Integer;
Var X,Y,W,H,Old,R:Integer;
    K:Char;
    Ext:Boolean;
Begin
 W:=380; H:=110;
 X:=(ScreenW-W) Div 2;
 Y:=(ScreenH-H) Div 2;
 MouseOff;
 DrawWin(X,Y,W,H,Title);
 SetCol(0);
 TxtOut(X+14,Y+34,Msg);
 DrawBtn(X+40,Y+H-32,70,22,'Oui',False);
 DrawBtn(X+150,Y+H-32,70,22,'Non',False);
 If Three Then DrawBtn(X+260,Y+H-32,80,22,'Annuler',False);
 MouseOn;
 WaitUp;
 Old:=0;
 R:=-1;
 Repeat
  PollMouse;
  If Pressed(Old)Then Begin
   If InRect(MX,MY,X+40,Y+H-32,70,22)Then R:=1
   Else If InRect(MX,MY,X+150,Y+H-32,70,22)Then R:=2
   Else If Three and InRect(MX,MY,X+260,Y+H-32,80,22)Then R:=0;
  End;
  If KeyPressed Then Begin
   K:=GetKey(Ext);
   If Not Ext Then Begin
    If(K='o')or(K='O')or(K='y')or(K='Y')or(K=#13)Then R:=1
    Else If(K='n')or(K='N')Then R:=2
    Else If K=#27 Then R:=0;
   End;
  End;
  Delay(10);
 Until R>=0;
 WaitUp;
 Ask3:=R;
End;

Function InputBox(Const Title,Prompt:String;Var S:String;MaxLen:Integer):Boolean;
Var X,Y,W,H,Old:Integer;
    Done,OK:Boolean;
    K:Char;
    Ext:Boolean;
    Tmp:String;
 Procedure Paint;
 Begin
  MouseOff;
  Box(X+10,Y+50,X+W-11,Y+70,15);
  SetCol(0);
  Rectangle(X+10,Y+50,X+W-11,Y+70);
  TxtOut(X+14,Y+56,Tmp+'_');
  MouseOn;
 End;
Begin
 W:=400; H:=120;
 X:=(ScreenW-W) Div 2;
 Y:=(ScreenH-H) Div 2;
 Tmp:=S;
 MouseOff;
 DrawWin(X,Y,W,H,Title);
 SetCol(0);
 TxtOut(X+12,Y+30,Prompt);
 DrawBtn(X+W Div 2-90,Y+H-30,80,22,'OK',False);
 DrawBtn(X+W Div 2+10,Y+H-30,80,22,'Annuler',False);
 MouseOn;
 Paint;
 WaitUp;
 Old:=0;
 Done:=False;
 OK:=False;
 Repeat
  PollMouse;
  If Pressed(Old)Then Begin
   If InRect(MX,MY,X+W Div 2-90,Y+H-30,80,22)Then Begin Done:=True; OK:=True; End
   Else If InRect(MX,MY,X+W Div 2+10,Y+H-30,80,22)Then Done:=True;
  End;
  If KeyPressed Then Begin
   K:=GetKey(Ext);
   If Not Ext Then Begin
    If K=#13 Then Begin Done:=True; OK:=True; End
    Else If K=#27 Then Done:=True
    Else If K=#8 Then Begin
     If Length(Tmp)>0 Then Begin Dec(Tmp[0]); Paint; End;
    End
    Else If(K>=' ')and(Length(Tmp)<MaxLen)and(TxtW(Tmp)<W-50)Then Begin
     Tmp:=Tmp+K;
     Paint;
    End;
   End;
  End;
  Delay(10);
 Until Done;
 WaitUp;
 If OK Then S:=Tmp;
 InputBox:=OK;
End;

{ Choix dans une liste (ChItems[0..N-1]) ; -1 si annule }
Function ChoiceBox(Const Title:String;N,Sel:Integer):Integer;
Var X,Y,W,H,Old,I,R,Hov:Integer;
    K:Char;
    Ext:Boolean;
 Procedure Paint;
 Var J:Integer;
 Begin
  MouseOff;
  For J:=0 To N-1 Do Begin
   If J=Sel Then Begin
    Box(X+8,Y+24+J*16,X+W-9,Y+24+J*16+15,UI_SEL);
    SetCol(15);
   End
    Else Begin
     Box(X+8,Y+24+J*16,X+W-9,Y+24+J*16+15,UI_BG);
     SetCol(0);
    End;
   TxtOut(X+14,Y+28+J*16,ChItems[J]);
  End;
  MouseOn;
 End;
Begin
 W:=300;
 H:=N*16+36;
 X:=(ScreenW-W) Div 2;
 Y:=(ScreenH-H) Div 2;
 If Sel<0 Then Sel:=0;
 MouseOff;
 DrawWin(X,Y,W,H,Title);
 MouseOn;
 Paint;
 WaitUp;
 Old:=0;
 R:=-2;
 Repeat
  PollMouse;
  Hov:=-1;
  If InRect(MX,MY,X+8,Y+24,W-16,N*16)Then Hov:=(MY-Y-24) Div 16;
  If(Hov>=0)and(Hov<>Sel)and((MB And 1)=0)Then Begin
   Sel:=Hov;
   Paint;
  End;
  If Pressed(Old)Then Begin
   If Hov>=0 Then R:=Hov
   Else If Not InRect(MX,MY,X,Y,W,H)Then R:=-1;
  End;
  If KeyPressed Then Begin
   K:=GetKey(Ext);
   If Ext Then Begin
    If(K=#72)and(Sel>0)Then Begin Dec(Sel); Paint; End;
    If(K=#80)and(Sel<N-1)Then Begin Inc(Sel); Paint; End;
   End
    Else
   Begin
    If K=#13 Then R:=Sel;
    If K=#27 Then R:=-1;
   End;
  End;
  Delay(10);
 Until R<>-2;
 WaitUp;
 I:=R;
 ChoiceBox:=I;
End;

{ Selecteur de couleur : -2 = annule, -1 = aucune }
Function ColorBox(Const Title:String;AllowNone:Boolean):Integer;
Var X,Y,W,H,Old,I,R,CX,CY:Integer;
    K:Char;
    Ext:Boolean;
Begin
 W:=8*28+24;
 H:=6*28+70;
 X:=(ScreenW-W) Div 2;
 Y:=(ScreenH-H) Div 2;
 MouseOff;
 DrawWin(X,Y,W,H,Title);
 For I:=0 To PAL_COUNT-1 Do Begin
  CX:=X+12+(I Mod 8)*28;
  CY:=Y+26+(I Div 8)*28;
  Box(CX,CY,CX+25,CY+25,I);
  SetCol(0);
  Rectangle(CX,CY,CX+25,CY+25);
 End;
 If AllowNone Then DrawBtn(X+12,Y+H-34,100,22,'Aucune',False);
 DrawBtn(X+W-112,Y+H-34,100,22,'Annuler',False);
 MouseOn;
 WaitUp;
 Old:=0;
 R:=-3;
 Repeat
  PollMouse;
  If Pressed(Old)Then Begin
   If InRect(MX,MY,X+12,Y+26,8*28,6*28)Then Begin
    I:=((MY-Y-26) Div 28)*8+((MX-X-12) Div 28);
    If((MX-X-12) Mod 28<26)and((MY-Y-26) Mod 28<26)and(I<PAL_COUNT)Then R:=I;
   End
    Else
   If AllowNone and InRect(MX,MY,X+12,Y+H-34,100,22)Then R:=-1
    Else
   If InRect(MX,MY,X+W-112,Y+H-34,100,22)Then R:=-2;
  End;
  If KeyPressed Then Begin
   K:=GetKey(Ext);
   If(K=#27)and Not Ext Then R:=-2;
  End;
  Delay(10);
 Until R<>-3;
 WaitUp;
 ColorBox:=R;
End;

{ Affiche TLines[0..TN-1] }
Procedure TextBox(Const Title:String);
Var X,Y,W,H,Old,I:Integer;
    Done:Boolean;
    K:Char;
    Ext:Boolean;
Begin
 W:=600;
 H:=TN*12+66;
 X:=(ScreenW-W) Div 2;
 Y:=(ScreenH-H) Div 2;
 MouseOff;
 DrawWin(X,Y,W,H,Title);
 SetCol(0);
 For I:=0 To TN-1 Do TxtOut(X+14,Y+28+I*12,TLines[I]);
 DrawBtn(X+W Div 2-30,Y+H-30,60,20,'OK',False);
 MouseOn;
 WaitUp;
 Old:=0;
 Done:=False;
 Repeat
  PollMouse;
  If Pressed(Old)Then
   If InRect(MX,MY,X+W Div 2-30,Y+H-30,60,20)Then Done:=True;
  If KeyPressed Then Begin
   K:=GetKey(Ext);
   If(K=#13)or(K=#27)Then Done:=True;
  End;
  Delay(10);
 Until Done;
 WaitUp;
End;

{ ---------------------------- Fichiers ----------------------------- }

Type
 TEntry=Record
  Name:String[40];
  IsDir:Boolean;
 End;

Var
 FEnt:Array[0..299] of TEntry;
 FN:Integer;
 LastFilter:Integer;

Function FltName(Const E:String):String;
Begin
 If E='.CD9' Then FltName:='CDR 9' Else FltName:=E;
End;

Procedure ScanDir(Const Ext:String);
Var SR:SearchRec;
    E:String;
    I,J:Integer;
    T:TEntry;
Begin
 FN:=0;
 FindFirst('*.*',AnyFile,SR);
 While(DosError=0)and(FN<300)Do Begin
  If(SR.Attr And Directory)<>0 Then Begin
   If SR.Name<>'.' Then Begin
    FEnt[FN].Name:=Copy(SR.Name,1,40);
    FEnt[FN].IsDir:=True;
    Inc(FN);
   End;
  End
   Else
  If(SR.Attr And VolumeID)=0 Then Begin
   E:=ExtOf(SR.Name);
   If(Ext='*')or(E=Ext)or((Ext='.CD9')and(E='.CDR'))or((Ext='.CDR')and((E='.CDT')or(E='.CD_')))Then Begin
    FEnt[FN].Name:=Copy(SR.Name,1,40);
    FEnt[FN].IsDir:=False;
    Inc(FN);
   End;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 For I:=1 To FN-1 Do Begin
  T:=FEnt[I];
  J:=I-1;
  While(J>=0)and((FEnt[J].IsDir<T.IsDir)or((FEnt[J].IsDir=T.IsDir)and(UpStr(FEnt[J].Name)>UpStr(T.Name))))Do Begin
   FEnt[J+1]:=FEnt[J];
   Dec(J);
  End;
  FEnt[J+1]:=T;
 End;
End;

{ Mode : 0 ouvrir, 1 enregistrer, 2 importer WPG, 3 exporter SVG }
Function FileDialog(Mode:Integer;Var Name:String):Boolean;
Const LR=12;
Var X,Y,W,H,Old,I,Top,Sel,Flt,NFlt:Integer;
    Exts:Array[0..11] of String[6];
    Dir,Fld,Msg:String;
    Done,OK,Dirty,Dbl:Boolean;
    K:Char;
    Ext:Boolean;
    T0,LastT:LongInt;
    LastSel:Integer;
 Function Title:String;
 Begin
  Case Mode Of
   0:Title:='Ouvrir un dessin';
   1:Title:='Enregistrer le dessin sous';
   2:Title:='Importer un fichier WPG';
   4:Title:='Exporter en CorelDRAW 9';
   5:Title:='Importer un fichier';
   6:Title:='Exporter (PDF EPS DXF WMF BMP PNG)';
  Else Title:='Exporter en SVG';
  End;
 End;
 Procedure Rescan;
 Var S:String;
 Begin
  GetDir(0,S);
  Dir:=S;
  ScanDir(Exts[Flt]);
  Top:=0;
  Sel:=-1;
  Dirty:=True;
 End;
 Procedure Paint;
 Var J,R:Integer;
     S:String;
 Begin
  MouseOff;
  DrawWin(X,Y,W,H,Title);
  SetCol(0);
  S:=Dir;
  If Length(S)>52 Then S:='...'+Copy(S,Length(S)-48,49);
  TxtOut(X+10,Y+24,S);
  Box(X+10,Y+40,X+W-130,Y+40+LR*16+3,15);
  SetCol(0);
  Rectangle(X+10,Y+40,X+W-130,Y+40+LR*16+3);
  For J:=0 To LR-1 Do Begin
   R:=Top+J;
   If R<FN Then Begin
    If R=Sel Then Begin
     Box(X+11,Y+42+J*16,X+W-131,Y+42+J*16+15,UI_SEL);
     SetCol(15);
    End
     Else SetCol(0);
    If FEnt[R].IsDir Then TxtOut(X+14,Y+46+J*16,'['+FEnt[R].Name+']')
     Else TxtOut(X+14,Y+46+J*16,FEnt[R].Name);
   End;
  End;
  If Mode=1 Then DrawBtn(X+W-118,Y+40,108,22,'Enregistrer',False)
   Else If(Mode=3)or(Mode=4)or(Mode=6)Then DrawBtn(X+W-118,Y+40,108,22,'Exporter',False)
   Else If(Mode=2)or(Mode=5)Then DrawBtn(X+W-118,Y+40,108,22,'Importer',False)
   Else DrawBtn(X+W-118,Y+40,108,22,'Ouvrir',False);
  DrawBtn(X+W-118,Y+68,108,22,'Annuler',False);
  If NFlt>1 Then DrawBtn(X+W-118,Y+104,108,22,'Type : '+FltName(Exts[Flt]),False)
   Else Begin
    SetCol(0);
    TxtOut(X+W-118,Y+110,'Type : '+FltName(Exts[Flt]));
   End;
  DrawBtn(X+W-118,Y+140,108,22,'Haut',False);
  DrawBtn(X+W-118,Y+168,108,22,'Bas',False);
  SetCol(0);
  TxtOut(X+10,Y+H-50,'Nom :');
  Box(X+56,Y+H-54,X+W-130,Y+H-36,15);
  SetCol(0);
  Rectangle(X+56,Y+H-54,X+W-130,Y+H-36);
  S:=Fld+'_';
  If Length(S)>38 Then S:=Copy(S,Length(S)-37,38);
  TxtOut(X+60,Y+H-49,S);
  Msg:=Msg;
  TxtOut(X+10,Y+H-24,Msg);
  MouseOn;
  Dirty:=False;
 End;
 Procedure Accept;
 Var S,E:String;
     Ok2:Boolean;
 Begin
  If Fld='' Then Begin
   If(Sel>=0)and(Sel<FN)Then Fld:=FEnt[Sel].Name Else Exit;
  End;
  { Navigation dans un dossier }
  {$I-}
  If(Fld[Length(Fld)]='\')or(Fld[Length(Fld)]='/')or(Fld=':')Then ChDir(Fld);
  {$I+}
  If(Fld[Length(Fld)]='\')or(Fld[Length(Fld)]='/')Then Begin
   If IOResult=0 Then Begin Fld:=''; Rescan; End;
   Exit;
  End;
  S:=Fld;
  E:=ExtOf(S);
  If(E='')and(Mode<>0)Then Begin
   If Exts[Flt]='.CD9' Then S:=S+'.CDR' Else S:=S+Exts[Flt];
  End;
  If(E='')and(Mode=0)and Not FileExists(S)and FileExists(S+Exts[0])Then S:=S+Exts[0];
  Ok2:=True;
  If(Mode=1)or(Mode=3)or(Mode=4)or(Mode=6)Then Begin
   If FileExists(S)Then Ok2:=Ask3('Remplacer','Le fichier existe déjà. Le remplacer ?',False)=1;
  End
   Else
  If Not FileExists(S)Then Begin
   Msg:='Fichier introuvable.';
   Ok2:=False;
   Dirty:=True;
  End;
  If Ok2 Then Begin
   Name:=FExpand(S);
   LastFilter:=Flt;
   OK:=True;
   Done:=True;
  End
   Else Dirty:=True;
 End;
 Procedure Activate(N:Integer);
 Begin
  If(N<0)or(N>=FN)Then Exit;
  If FEnt[N].IsDir Then Begin
   {$I-}ChDir(FEnt[N].Name);{$I+}
   If IOResult<>0 Then Msg:='Dossier inaccessible.' Else Msg:='';
   Rescan;
  End
   Else Begin
    Fld:=FEnt[N].Name;
    Accept;
   End;
 End;
Begin
 W:=480; H:=LR*16+130;
 X:=(ScreenW-W) Div 2;
 Y:=(ScreenH-H) Div 2;
 Case Mode Of
  0:Begin Exts[0]:='.CDR'; Exts[1]:='.WPG'; Exts[2]:='*'; NFlt:=3; End;
  1:Begin Exts[0]:='.CDR'; Exts[1]:='.SVG'; Exts[2]:='.CD9'; NFlt:=3; End;
  2:Begin Exts[0]:='.WPG'; NFlt:=1; End;
  4:Begin Exts[0]:='.CDR'; NFlt:=1; End;
  5:Begin
   Exts[0]:='.WPG'; Exts[1]:='.DXF'; Exts[2]:='.EPS'; Exts[3]:='.PDF'; Exts[4]:='.AI';
   Exts[5]:='.WMF'; Exts[6]:='.BMP'; Exts[7]:='.PCX'; Exts[8]:='.PNG'; Exts[9]:='*';
   NFlt:=10;
  End;
  6:Begin
   Exts[0]:='.PDF'; Exts[1]:='.EPS'; Exts[2]:='.DXF'; Exts[3]:='.WMF'; Exts[4]:='.BMP'; Exts[5]:='.PNG';
   NFlt:=6;
  End;
 Else Begin Exts[0]:='.SVG'; NFlt:=1; End;
 End;
 Flt:=0;
 Fld:='';
 Msg:='';
 If(Mode=1)and(DocName<>'')Then Fld:=BaseOf(DocName);
 If(Mode=3)and(DocName<>'')Then Fld:=BaseOf(ForceExt(DocName,'.SVG'));
 If(Mode=4)and(DocName<>'')Then Fld:=BaseOf(DocName);
 If(Mode=6)and(DocName<>'')Then Fld:=BaseOf(DocName);
 Rescan;
 Done:=False;
 OK:=False;
 Old:=0;
 LastT:=0;
 LastSel:=-1;
 WaitUp;
 Paint;
 Repeat
  PollMouse;
  If Dirty Then Paint;
  If Pressed(Old)Then Begin
   Dbl:=False;
   If InRect(MX,MY,X+11,Y+42,W-142,LR*16)Then Begin
    I:=Top+(MY-Y-42) Div 16;
    If I<FN Then Begin
     T0:=Ticks;
     If(I=LastSel)and(Abs(T0-LastT)<45)Then Dbl:=True;
     LastT:=T0;
     LastSel:=I;
     Sel:=I;
     If Not FEnt[I].IsDir Then Fld:=FEnt[I].Name;
     Msg:='';
     If Dbl Then Activate(I) Else Dirty:=True;
    End;
   End
    Else
   If InRect(MX,MY,X+W-118,Y+40,108,22)Then Accept
    Else
   If InRect(MX,MY,X+W-118,Y+68,108,22)Then Done:=True
    Else
   If(NFlt>1)and InRect(MX,MY,X+W-118,Y+104,108,22)Then Begin
    Flt:=(Flt+1) Mod NFlt;
    Rescan;
   End
    Else
   If InRect(MX,MY,X+W-118,Y+140,108,22)Then Begin
    If Top>0 Then Dec(Top,LR-1);
    If Top<0 Then Top:=0;
    Dirty:=True;
   End
    Else
   If InRect(MX,MY,X+W-118,Y+168,108,22)Then Begin
    If Top+LR<FN Then Inc(Top,LR-1);
    Dirty:=True;
   End;
  End;
  If KeyPressed Then Begin
   K:=GetKey(Ext);
   If Ext Then Begin
    If(K=#72)and(Sel>0)Then Begin Dec(Sel); If Sel<Top Then Top:=Sel; If Not FEnt[Sel].IsDir Then Fld:=FEnt[Sel].Name; Dirty:=True; End;
    If(K=#80)and(Sel<FN-1)Then Begin Inc(Sel); If Sel>=Top+LR Then Top:=Sel-LR+1; If Not FEnt[Sel].IsDir Then Fld:=FEnt[Sel].Name; Dirty:=True; End;
   End
    Else
   Begin
    If K=#13 Then Begin
     If(Fld='')and(Sel>=0)Then Activate(Sel) Else Accept;
    End
    Else If K=#27 Then Done:=True
    Else If K=#8 Then Begin
     If Length(Fld)>0 Then Dec(Fld[0]);
     Dirty:=True;
    End
    Else If(K>=' ')and(Length(Fld)<60)Then Begin
     Fld:=Fld+K;
     Dirty:=True;
    End;
   End;
  End;
  Delay(10);
 Until Done;
 WaitUp;
 FileDialog:=OK;
End;

{ ------------------------------------------------------------------ }
{ Edition                                                            }
{ ------------------------------------------------------------------ }

Var
 PasteN:Integer;
 StatsMsg:String;

Function CanFill(O:PObj):Boolean;
Begin
 CanFill:=(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)or(O^.Kind=K_POLY)or
          (O^.Kind=K_TEXT)or((O^.Kind=K_BEZIER)and O^.Closed);
End;

Procedure ApplyFillColor(C:Integer);
Var I:LongInt;
Begin
 If SelCount=0 Then Begin
  DefFill:=C;
  If C>=0 Then DefFillKind:=FK_SOLID;
  Exit;
 End;
 PushUndo;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel Then
   If CanFill(ObjAt(I))Then Begin
    If C<0 Then Begin
     If ObjAt(I)^.Kind=K_TEXT Then ObjAt(I)^.FillCol:=-1
      Else Begin ObjAt(I)^.FillKind:=FK_NONE; ObjAt(I)^.FillCol:=-1; End;
    End
     Else Begin
      ObjAt(I)^.FillCol:=C;
      If ObjAt(I)^.FillKind=FK_NONE Then ObjAt(I)^.FillKind:=FK_SOLID;
     End;
   End;
End;

Procedure ApplyOutColor(C:Integer);
Var I:LongInt;
Begin
 If SelCount=0 Then Begin
  DefOut:=C;
  Exit;
 End;
 PushUndo;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel Then ObjAt(I)^.OutCol:=C;
End;

Procedure ApplyOutWidth(W:LongInt);
Var I:LongInt;
Begin
 If SelCount=0 Then Begin
  DefOutW:=W;
  Exit;
 End;
 PushUndo;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel Then Begin
   ObjAt(I)^.OutW:=W;
   If ObjAt(I)^.OutCol<0 Then ObjAt(I)^.OutCol:=0;
  End;
End;

Procedure ApplyFillKind(FK:Byte;C1,C2:Integer);
Var I:LongInt;
Begin
 If SelCount=0 Then Begin
  DefFillKind:=FK;
  If C1>=0 Then DefFill:=C1;
  If C2>=0 Then DefFill2:=C2;
  Exit;
 End;
 PushUndo;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel and CanFill(ObjAt(I))and(ObjAt(I)^.Kind<>K_TEXT)Then Begin
   ObjAt(I)^.FillKind:=FK;
   If FK=FK_NONE Then ObjAt(I)^.FillCol:=-1
    Else Begin
     If C1>=0 Then ObjAt(I)^.FillCol:=C1;
     If ObjAt(I)^.FillCol<0 Then ObjAt(I)^.FillCol:=15;
     ObjAt(I)^.FillCol2:=C2;
    End;
  End;
End;

Procedure ClipCopy;
Begin
 If SelCount=0 Then Exit;
 FreeSnap(ClipSnap);
 ClipSnap:=TakeSnap(True);
 PasteN:=0;
End;

Procedure AddClones(S:PSnap;DX,DY:LongInt);
Var Base,MaxG:Integer;
    O,P:PObj;
Begin
 DeselectAll;
 Base:=GroupSeq;
 MaxG:=0;
 P:=S^.Head;
 While P<>NIL Do Begin
  O:=CloneObj(P);
  ObjMove(O,DX,DY);
  If O^.Group<>0 Then Begin
   If O^.Group>MaxG Then MaxG:=O^.Group;
   O^.Group:=Base+O^.Group;
  End;
  O^.Sel:=True;
  AddObj(O);
  P:=P^.Next;
 End;
 GroupSeq:=Base+MaxG;
End;

Procedure ClipPaste;
Begin
 If(ClipSnap=NIL)or(ClipSnap^.N=0)Then Exit;
 PushUndo;
 Inc(PasteN);
 AddClones(ClipSnap,150*PasteN,150*PasteN);
End;

Procedure Duplicate;
Var S:PSnap;
Begin
 If SelCount=0 Then Exit;
 PushUndo;
 S:=TakeSnap(True);
 AddClones(S,200,200);
 FreeSnap(S);
End;

Procedure SelectNext;
Var I,F,K,J:LongInt;
Begin
 If ObjCount=0 Then Exit;
 F:=-1;
 For I:=0 To ObjCount-1 Do If ObjAt(I)^.Sel Then F:=I;
 DeselectAll;
 For K:=1 To ObjCount Do Begin
  J:=(F+K+ObjCount) Mod ObjCount;
  If ObjPickable(ObjAt(J))Then Begin
   SelectIndex(J);
   Exit;
  End;
 End;
End;

Procedure SetPage(W,H:LongInt);
Begin
 PushUndo;
 If PageW>PageH Then Begin PageW:=H; PageH:=W; End
  Else Begin PageW:=W; PageH:=H; End;
 If PageW<PageH Then Begin End;
 ZoomFit;
End;

Procedure SetOrientation(Land:Boolean);
Var T:LongInt;
Begin
 If Land=(PageW>PageH)Then Exit;
 PushUndo;
 T:=PageW; PageW:=PageH; PageH:=T;
 ZoomFit;
End;

Procedure EditText;
Var I:LongInt;
    S:String;
Begin
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel and(ObjAt(I)^.Kind=K_TEXT)Then Begin
   S:=ObjAt(I)^.Txt;
   If InputBox('Modifier le texte','Texte :',S,60)Then Begin
    PushUndo;
    ObjAt(I)^.Txt:=S;
   End;
   Exit;
  End;
 StatusMsg:='Sélectionnez d''abord un texte.';
End;

Procedure ResizeText(Delta:LongInt);
Var I:LongInt;
    Any:Boolean;
Begin
 Any:=False;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel and(ObjAt(I)^.Kind=K_TEXT)Then Any:=True;
 If Not Any Then Begin
  DefTextSize:=Clamp(DefTextSize+Delta,20,1000);
  Exit;
 End;
 PushUndo;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel and(ObjAt(I)^.Kind=K_TEXT)Then
   ObjAt(I)^.TextSize:=Clamp(ObjAt(I)^.TextSize+Delta,20,2000);
End;

Procedure ShowDocInfo(Stats:Boolean);
Var I,C:LongInt;
    Cnt:Array[1..8] of Integer;
    Pts:LongInt;
Begin
 FillChar(Cnt,SizeOf(Cnt),0);
 Pts:=0;
 For I:=0 To ObjCount-1 Do Begin
  Inc(Cnt[ObjAt(I)^.Kind]);
  Inc(Pts,ObjAt(I)^.N);
 End;
 TN:=0;
 TLines[TN]:='Fichier : '+DocName; Inc(TN);
 If DocName='' Then TLines[0]:='Fichier : (sans titre)';
 TLines[TN]:='Page : '+IStr(PageW Div 10)+' x '+IStr(PageH Div 10)+' mm'; Inc(TN);
 TLines[TN]:='Objets : '+IStr(ObjCount); Inc(TN);
 TLines[TN]:='Noeuds : '+IStr(Pts); Inc(TN);
 TLines[TN]:=''; Inc(TN);
 TLines[TN]:='Lignes : '+IStr(Cnt[K_LINE])+'   Rectangles : '+IStr(Cnt[K_RECT])+
             '   Ellipses : '+IStr(Cnt[K_ELLIPSE]); Inc(TN);
 TLines[TN]:='Polygones : '+IStr(Cnt[K_POLY])+'   Polylignes : '+IStr(Cnt[K_POLYLINE]); Inc(TN);
 TLines[TN]:='Courbes : '+IStr(Cnt[K_BEZIER])+'   Textes : '+IStr(Cnt[K_TEXT])+'   Bitmaps : '+IStr(Cnt[K_BITMAP]); Inc(TN);
 TLines[TN]:=''; Inc(TN);
 TLines[TN]:='Annulations possibles : '+IStr(UndoCnt)+'   Rétablissements : '+IStr(RedoCnt); Inc(TN);
 C:=0;
 If Stats Then C:=1;
 If Stats Then TextBox('Statistiques du dessin') Else TextBox('Informations sur le document');
End;

Procedure ShowHelp;
Begin
 TN:=0;
 TLines[TN]:='Outils : P pointeur  N noeuds  Z zoom  H main  L ligne'; Inc(TN);
 TLines[TN]:='         Y polyligne  B courbe  R rectangle  E ellipse'; Inc(TN);
 TLines[TN]:='         G polygone  S étoile  T texte'; Inc(TN);
 TLines[TN]:=''; Inc(TN);
 TLines[TN]:='Souris : clic gauche = remplissage, clic droit = contour (palette)'; Inc(TN);
 TLines[TN]:='         clic droit sur un objet = menu contextuel'; Inc(TN);
 TLines[TN]:='         double-clic sur un texte = modifier le texte'; Inc(TN);
 TLines[TN]:=''; Inc(TN);
 TLines[TN]:='Ctrl+N/O/S nouveau, ouvrir, enregistrer   Ctrl+Z/Y annuler, rétablir'; Inc(TN);
 TLines[TN]:='Ctrl+X/C/V couper, copier, coller         Ctrl+D dupliquer'; Inc(TN);
 TLines[TN]:='Ctrl+A tout sélectionner   Tab objet suivant   Suppr effacer'; Inc(TN);
 TLines[TN]:='Ctrl+G grouper   Ctrl+U dégrouper   Ctrl+Q convertir en courbes'; Inc(TN);
 TLines[TN]:='Ctrl+R rotation de 90 degrés   PgHaut/PgBas ordre des objets'; Inc(TN);
 TLines[TN]:='Flèches = déplacer la sélection (1 mm) ou la vue'; Inc(TN);
 TLines[TN]:='+ / - zoom   F2 sélection   F3 100%   F4 page   F9 aperçu'; Inc(TN);
 TLines[TN]:='F8 modifier le texte   F10 menus   Alt+X quitter'; Inc(TN);
 TLines[TN]:=''; Inc(TN);
 TLines[TN]:='[ ] rotation de 15 degrés   Formes : soudure, intersection, couteau'; Inc(TN);
 TLines[TN]:='Règles : tirer un repère (le ramener sur la règle le supprime)'; Inc(TN);
 TLines[TN]:='Outil noeuds : clic droit = lisse, symétrique, casser, fermer'; Inc(TN);
 TLines[TN]:='Fichier : importer DXF EPS PDF AI WMF BMP PCX PNG ; exporter PDF EPS DXF WMF BMP PNG'; Inc(TN);
 TextBox('Raccourcis clavier');
End;

Procedure ShowAbout;
Begin
 TN:=0;
 TLines[TN]:='CorelDraw clone pour Turbo Pascal / Free Pascal'; Inc(TN);
 TLines[TN]:='Dessin vectoriel : courbes, formes, texte, remplissages.'; Inc(TN);
 TLines[TN]:=''; Inc(TN);
 TLines[TN]:='Formats : CDR (RIFF CDR4, objets propres à ce clone),'; Inc(TN);
 TLines[TN]:='           WPG (clipart vectoriel, lecture), SVG (écriture)'; Inc(TN);
 TLines[TN]:=''; Inc(TN);
 TLines[TN]:='Auteur : Sylvain Maltais (support@gladir.com)'; Inc(TN);
 TLines[TN]:='https://www.gladir.com/clonedraw'; Inc(TN);
 TextBox('À propos');
End;

{ ------------------------------------------------------------------ }
{ Fichier : nouveau / ouvrir / enregistrer                           }
{ ------------------------------------------------------------------ }

Function ConfirmDiscard:Boolean;
Var R:Integer;
Begin
 ConfirmDiscard:=True;
 If Not Modified Then Exit;
 R:=Ask3('CorelDraw','Enregistrer les modifications ?',True);
 If R=0 Then ConfirmDiscard:=False
  Else
 If R=1 Then Begin
  If DocName='' Then Begin
   ConfirmDiscard:=False;
   StatusMsg:='Utilisez Enregistrer sous... avant de continuer.';
  End
   Else Begin
    If Not SaveAny(DocName)Then Begin
     MsgBox('Erreur','Impossible d''enregistrer le fichier.',DocName);
     ConfirmDiscard:=False;
    End
     Else Modified:=False;
   End;
 End;
End;

{ Zoom sur la page et tous les objets }
Procedure ZoomAll;
Var I:LongInt;
    X1,Y1,X2,Y2,A,B,C,D:LongInt;
Begin
 X1:=0; Y1:=0; X2:=PageW; Y2:=PageH;
 For I:=0 To ObjCount-1 Do Begin
  ObjBBox(ObjAt(I),A,B,C,D);
  If A<X1 Then X1:=A;
  If B<Y1 Then Y1:=B;
  If C>X2 Then X2:=C;
  If D>Y2 Then Y2:=D;
 End;
 If((X2-X1)>3*PageW)or((Y2-Y1)>3*PageH)Then ZoomFit
  Else ZoomRect(X1-50,Y1-50,X2+50,Y2+50);
End;

Procedure DoNew;
Begin
 If Not ConfirmDiscard Then Exit;
 NewDocument;
 ZoomFit;
End;

Procedure DoOpen;
Var N:String;
Begin
 If Not ConfirmDiscard Then Exit;
 N:='';
 If Not FileDialog(0,N)Then Exit;
 If LoadAny(N)Then Begin
  { un fichier WPG ou CorelDRAW natif n'est jamais ecrase par Enregistrer }
  If(ExtOf(N)='.WPG')or FromCorel Then DocName:='' Else DocName:=N;
  Modified:=False;
  ClearList(UndoList,UndoCnt);
  ClearList(RedoList,RedoCnt);
  ZoomAll;
  If C9Info<>'' Then StatusMsg:=C9Info Else StatusMsg:=IStr(ObjCount)+' objets chargés';
 End
  Else Begin
   MsgBox('Erreur','Fichier illisible ou format non reconnu :',BaseOf(N));
   NewDocument;
   ZoomFit;
  End;
End;

Procedure DoSaveAs;
Var N:String;
    Good,Cd9:Boolean;
Begin
 N:='';
 If Not FileDialog(1,N)Then Exit;
 If ExtOf(N)=''Then N:=N+'.CDR';
 Cd9:=(LastFilter=2)and(ExtOf(N)='.CDR');
 If Cd9 Then Good:=SaveFiltered(N,False) Else Good:=SaveAny(N);
 If Cd9 Then Begin
  StatusMsg:='Exporté CorelDRAW 9 : '+BaseOf(N);
  If Not GlyphsReady Then StatusMsg:=StatusMsg+' (texte omis)';
 End
  Else
 If Good Then Begin
  If ExtOf(N)<>'.SVG' Then Begin
   DocName:=N;
   Modified:=False;
  End;
  StatusMsg:='Enregistré : '+BaseOf(N);
 End
  Else MsgBox('Erreur','Impossible d''enregistrer le fichier :',BaseOf(N));
End;

Procedure DoSave;
Begin
 If DocName='' Then DoSaveAs
  Else
 If SaveAny(DocName)Then Begin
  Modified:=False;
  StatusMsg:='Enregistré : '+BaseOf(DocName);
 End
  Else MsgBox('Erreur','Impossible d''enregistrer le fichier :',BaseOf(DocName));
End;

Procedure DoImport;
Var N:String;
    Ok:Boolean;
Begin
 N:='';
 If Not FileDialog(5,N)Then Exit;
 PushUndo;
 {$IFDEF FPC}
 If IsForeignExt(ExtOf(N))Then Ok:=LoadForeign(N,True)
  Else
 {$ENDIF}
  Ok:=LoadWPG(N,True);
 If Ok Then StatusMsg:='Importé : '+BaseOf(N)
  Else MsgBox('Erreur','Fichier illisible ou format non pris en charge :',BaseOf(N));
 Modified:=True;
End;

{ Exportation PDF / EPS (avec choix de la couleur), DXF, WMF, BMP, PNG }
Procedure DoExportVec;
Var N,E:String;
    K:Integer;
Begin
 N:='';
 If Not FileDialog(6,N)Then Exit;
 E:=ExtOf(N);
 If E=''Then Begin
  N:=N+'.PDF';
  E:='.PDF';
 End;
 ExpMode:=0;
 If(E='.PDF')or(E='.EPS')or(E='.PS')Then Begin
  ChItems[0]:='RVB (écran)';
  ChItems[1]:='CMJN (quadrichromie)';
  ChItems[2]:='Séparations C, M, J, N (4 fichiers)';
  K:=ChoiceBox('Couleurs',3,0);
  If K<0 Then Exit;
  If K=0 Then ExpMode:=0 Else If K=1 Then ExpMode:=1 Else ExpMode:=6;
 End;
 If SaveAny(N)Then Begin
  StatusMsg:='Exporté : '+BaseOf(N);
  If(E='.BMP')or(E='.PNG')Then StatusMsg:=StatusMsg+' (texte omis)';
 End
  Else MsgBox('Erreur','Impossible d''écrire le fichier :',BaseOf(N));
 ExpMode:=0;
End;

Procedure DoExportSVG;
Var N:String;
Begin
 N:='';
 If Not FileDialog(3,N)Then Exit;
 If ExtOf(N)=''Then N:=N+'.SVG';
 If SaveFiltered(N,True)Then StatusMsg:='Exporté : '+BaseOf(N)
  Else MsgBox('Erreur','Impossible d''écrire le fichier SVG :',BaseOf(N));
End;

Procedure DoExportCDR9;
Var N:String;
Begin
 N:='';
 If Not FileDialog(4,N)Then Exit;
 If ExtOf(N)=''Then N:=N+'.CDR';
 If SaveFiltered(N,False)Then Begin
  StatusMsg:='Exporté CorelDRAW 9 : '+BaseOf(N);
  If Not GlyphsReady Then StatusMsg:=StatusMsg+' (texte omis)';
 End
  Else MsgBox('Erreur','Impossible d''écrire le fichier CorelDRAW 9 :',BaseOf(N));
End;

{ ------------------------------------------------------------------ }
{ Apercu plein ecran                                                 }
{ ------------------------------------------------------------------ }

Procedure ShowPreviewFull;
Var SX,SY,SW,SH:Integer;
    SZ,SOX,SOY:LongInt;
    SWire,SGrid:Boolean;
    I:LongInt;
    Old:Integer;
    K:Char;
    Ext:Boolean;
Begin
 SX:=CanvasX; SY:=CanvasY; SW:=CanvasW; SH:=CanvasH;
 SZ:=Zoom; SOX:=OrgX; SOY:=OrgY; SWire:=WireMode; SGrid:=ShowGrid;
 CanvasX:=0; CanvasY:=0; CanvasW:=ScreenW; CanvasH:=ScreenH;
 WireMode:=False;
 ZoomFit;
 MouseOff;
 BeginCanvas;
 Box(0,0,CanvasW-1,CanvasH-1,15);
 SetCol(0);
 Rectangle(W2SX(0),W2SY(0),W2SX(PageW),W2SY(PageH));
 For I:=0 To ObjCount-1 Do If ObjShown(ObjAt(I))Then DrawObject(ObjAt(I));
 EndCanvas;
 MouseOn;
 WaitUp;
 Old:=0;
 Repeat
  PollMouse;
  Delay(10);
 Until Pressed(Old)or KeyPressed;
 If KeyPressed Then K:=GetKey(Ext);
 WaitUp;
 CanvasX:=SX; CanvasY:=SY; CanvasW:=SW; CanvasH:=SH;
 Zoom:=SZ; OrgX:=SOX; OrgY:=SOY; WireMode:=SWire; ShowGrid:=SGrid;
End;

{ ------------------------------------------------------------------ }
{ Execution des commandes                                           }
{ ------------------------------------------------------------------ }

Procedure ToggleFlag(Which:Integer);
Var I:LongInt;
    V:Boolean;
    O:PObj;
Begin
 O:=FirstSel;
 If O=NIL Then Begin
  StatusMsg:='Sélectionnez d''abord un objet.';
  Exit;
 End;
 If Which=0 Then V:=Not O^.Shadow Else V:=Not O^.Extrude;
 PushUndo;
 For I:=0 To ObjCount-1 Do
  If ObjAt(I)^.Sel Then
   If Which=0 Then ObjAt(I)^.Shadow:=V Else ObjAt(I)^.Extrude:=V;
End;

{ Saisie d'un nombre reel (virgule ou point) }
Function AskReal(Const Title,Prompt,Def:String;Var R:Real):Boolean;
Var S:String;
    C,I:Integer;
Begin
 AskReal:=False;
 S:=Def;
 If Not InputBox(Title,Prompt,S,10)Then Exit;
 For I:=1 To Length(S) Do If S[I]=',' Then S[I]:='.';
 Val(S,R,C);
 AskReal:=C=0;
End;

{ Gestionnaire de calques : liste, puis action sur le calque choisi }
Procedure LayerManager;
Var I,L,A:Integer;
    Done:Boolean;
    S,Nm:String;
    P:PObj;
Begin
 Done:=False;
 Repeat
  For I:=1 To LAYER_N Do Begin
   S:=LayerName[I];
   While Length(S)<16 Do S:=S+' ';
   If I=ActLayer Then S:='* '+S Else S:='  '+S;
   If LayerVis[I] Then S:=S+' V' Else S:=S+' -';
   If LayerLock[I] Then S:=S+'L' Else S:=S+'-';
   If LayerPrn[I] Then S:=S+'P' Else S:=S+'-';
   ChItems[I-1]:=S;
  End;
  L:=ChoiceBox('Calques (V visible L verrouillé P imprimé)',LAYER_N,ActLayer-1);
  If L<0 Then Done:=True
   Else Begin
    Inc(L);
    ChItems[0]:='Rendre actif';
    ChItems[1]:='Afficher / masquer';
    ChItems[2]:='Verrouiller / déverrouiller';
    ChItems[3]:='Imprimable oui / non';
    ChItems[4]:='Renommer...';
    ChItems[5]:='Y envoyer la sélection';
    ChItems[6]:='Terminer';
    A:=ChoiceBox('Calque : '+LayerName[L],7,0);
    Case A Of
     0:ActLayer:=L;
     1:LayerVis[L]:=Not LayerVis[L];
     2:LayerLock[L]:=Not LayerLock[L];
     3:LayerPrn[L]:=Not LayerPrn[L];
     4:Begin
        Nm:=LayerName[L];
        If InputBox('Calque','Nom du calque :',Nm,16)Then
         If Nm<>'' Then LayerName[L]:=Nm;
       End;
     5:If SelCount>0 Then Begin
        PushUndo;
        P:=ObjHead;
        While P<>NIL Do Begin
         If P^.Sel Then P^.Layer:=L;
         P:=P^.Next;
        End;
       End;
     6:Done:=True;
    End;
    { un calque masque ou verrouille ne garde pas de selection }
    P:=ObjHead;
    While P<>NIL Do Begin
     If P^.Sel and Not ObjPickable(P)Then P^.Sel:=False;
     P:=P^.Next;
    End;
    If A<0 Then Done:=True;
   End;
 Until Done;
End;

Procedure DeletePage;
Var P,Nx:PObj;
Begin
 P:=ObjHead;
 While P<>NIL Do Begin
  Nx:=P^.Next;
  If P^.Page=CurPage Then DeleteObj(P)
   Else If(P^.Page>CurPage)Then Dec(P^.Page);
  P:=Nx;
 End;
 Dec(PageCnt);
 If CurPage>PageCnt Then CurPage:=PageCnt;
End;

Procedure AddGuide;
Var S:String;
    N,C:LongInt;
    K:Integer;
Begin
 If GuideN>=GUIDE_MAX Then Exit;
 ChItems[0]:='Repère horizontal';
 ChItems[1]:='Repère vertical';
 K:=ChoiceBox('Ajouter un repère',2,0);
 If K<0 Then Exit;
 S:='50';
 If InputBox('Repère','Position (mm) :',S,6)Then Begin
  Val(S,N,C);
  If C=0 Then Begin
   GuideHor[GuideN]:=K=0;
   GuidePos[GuideN]:=N*10;
   Inc(GuideN);
   ShowGuides:=True;
  End;
 End;
End;

Procedure DoEdit(Cmd:Integer);
Var A,B,R:Real;
    C,C2,K:Integer;
    S,Nm:String;
    V:Array[0..3] of Real;
    I,N:Integer;
Begin
 EditMsg:='';
 Case Cmd Of
  CM_B_WELD:BoolSel(0);
  CM_B_INTER:BoolSel(1);
  CM_B_FMB:BoolSel(2);
  CM_B_BMF:BoolSel(3);
  CM_B_KNIFE:KnifeSel;
  CM_COMBINE:CombineSel;
  CM_BREAK:BreakApartSel;
  CM_ROTATE:If AskReal('Rotation','Angle en degrés (sens anti-horaire) :','15',A)Then RotateSel(A);
  CM_ROT_L:RotateSel(15);
  CM_ROT_R:RotateSel(-15);
  CM_SKEW:Begin
   If AskReal('Inclinaison','Inclinaison horizontale (degrés) :','15',A)Then
    If AskReal('Inclinaison','Inclinaison verticale (degrés) :','0',B)Then Begin
     If(Abs(A)<89)and(Abs(B)<89)Then SkewSel(A,B)
      Else EditMsg:='Angle limité à 89 degrés.';
    End;
  End;
  CM_SCALE:Begin
   If AskReal('Échelle','Largeur en % (négatif = miroir) :','100',A)Then
    If AskReal('Échelle','Hauteur en % (négatif = miroir) :','100',B)Then Begin
     If(A<>0)and(B<>0)Then AffineSel(A/100,0,0,B/100)
      Else EditMsg:='Une échelle nulle est refusée.';
    End;
  End;
  CM_WARP:Begin
   ChItems[0]:='Haut plus étroit';
   ChItems[1]:='Bas plus étroit';
   ChItems[2]:='Gauche plus étroite';
   ChItems[3]:='Droite plus étroite';
   ChItems[4]:='Arc horizontal';
   ChItems[5]:='Arc vertical';
   ChItems[6]:='Vague';
   K:=ChoiceBox('Perspective / enveloppe',7,0);
   If K>=0 Then
    If AskReal('Perspective / enveloppe','Amplitude en % :','30',A)Then Begin
     If A<0 Then A:=0;
     If(K<4)and(A>90)Then A:=90;
     If A>200 Then A:=200;
     WarpSel(K,Round(A));
    End;
  End;
  CM_BLEND:Begin
   If AskReal('Mélange','Nombre d''étapes (1 à 50) :','5',A)Then Begin
    N:=Round(A);
    If N<1 Then N:=1;
    If N>50 Then N:=50;
    BlendSel(N);
   End;
  End;
  CM_CONTOUR:Begin
   If AskReal('Contour','Nombre de contours (1 à 20) :','3',A)Then
    If AskReal('Contour','Distance en mm (négatif = intérieur) :','2',B)Then Begin
     N:=Round(A);
     If N<1 Then N:=1;
     If N>20 Then N:=20;
     If B=0 Then EditMsg:='Distance nulle.'
      Else ContourSel(N,Round(B*10));
    End;
  End;
  CM_N_LINE:NodeOp(1);
  CM_N_CURVE:NodeOp(2);
  CM_N_SMOOTH:NodeOp(3);
  CM_N_SYM:NodeOp(4);
  CM_N_CUSP:NodeOp(5);
  CM_N_BREAK:NodeOp(6);
  CM_N_CLOSE:NodeOp(7);
  CM_FILL_CON,CM_FILL_SQ:Begin
   C:=ColorBox('Dégradé : couleur de départ',False);
   If C>=0 Then Begin
    C2:=ColorBox('Dégradé : couleur de fin',False);
    If C2>=0 Then Begin
     If Cmd=CM_FILL_CON Then ApplyFillKind(FK_CONIC,C,C2)
                        Else ApplyFillKind(FK_SQUARE,C,C2);
    End;
   End;
  End;
  CM_FILL_CMYK:Begin
   S:='0,0,0,100';
   If InputBox('Couleur CMJN','Cyan,Magenta,Jaune,Noir (0-100) :',S,24)Then Begin
    For I:=1 To Length(S) Do If S[I]=',' Then S[I]:=' ';
    For I:=0 To 3 Do V[I]:=0;
    N:=0;
    K:=1;
    While(K<=Length(S))and(N<4)Do Begin
     While(K<=Length(S))and(S[K]=' ')Do Inc(K);
     If K<=Length(S)Then Begin
      Nm:='';
      While(K<=Length(S))and(S[K]<>' ')Do Begin Nm:=Nm+S[K]; Inc(K); End;
      Val(Nm,R,C);
      If C=0 Then Begin
       If R<0 Then R:=0;
       If R>100 Then R:=100;
       V[N]:=R/100;
      End;
      Inc(N);
     End;
    End;
    C:=AddPalColor(Round(255*(1-V[0])*(1-V[3])),Round(255*(1-V[1])*(1-V[3])),Round(255*(1-V[2])*(1-V[3])));
    ApplyFillColor(C);
   End;
  End;
  CM_DIM_H:DimensionSel(False);
  CM_DIM_V:DimensionSel(True);
  CM_CONNECT:ConnectSel;
  CM_SEL_FILL:SelectSame(0);
  CM_SEL_OUT:SelectSame(1);
  CM_SEL_TYPE:SelectSame(2);
  CM_REPLACE:Begin
   C:=ColorBox('Remplacer : couleur à chercher',False);
   If C>=0 Then Begin
    C2:=ColorBox('Remplacer : nouvelle couleur',False);
    If C2>=0 Then Begin
     ChItems[0]:='Remplissages';
     ChItems[1]:='Contours';
     ChItems[2]:='Les deux';
     K:=ChoiceBox('Remplacer dans',3,2);
     If K>=0 Then Begin
      PushUndo;
      N:=ReplaceColor(C,C2,K<>1,K<>0);
      EditMsg:=IStr(N)+' modification(s).';
     End;
    End;
   End;
  End;
  CM_LAYERS:LayerManager;
  CM_PAGE_NEXT:If CurPage<PageCnt Then Begin
   DeselectAll;
   Inc(CurPage);
   EditMsg:='Page '+IStr(CurPage)+' / '+IStr(PageCnt);
  End;
  CM_PAGE_PREV:If CurPage>1 Then Begin
   DeselectAll;
   Dec(CurPage);
   EditMsg:='Page '+IStr(CurPage)+' / '+IStr(PageCnt);
  End;
  CM_PAGE_ADD:If PageCnt<PAGE_MAX Then Begin
   DeselectAll;
   Inc(PageCnt);
   CurPage:=PageCnt;
   EditMsg:='Page '+IStr(CurPage)+' / '+IStr(PageCnt);
  End;
  CM_PAGE_DEL:If PageCnt>1 Then Begin
   If Ask3('Supprimer la page','Supprimer la page '+IStr(CurPage)+' et son contenu ?',False)=1 Then Begin
    PushUndo;
    DeselectAll;
    DeletePage;
   End;
  End;
  CM_PAGE_MASTER:Begin
   DeselectAll;
   EditMaster:=Not EditMaster;
   If EditMaster Then EditMsg:='Page maîtresse (visible sur toutes les pages)'
    Else EditMsg:='Page '+IStr(CurPage)+' / '+IStr(PageCnt);
  End;
  CM_GUIDES:ShowGuides:=Not ShowGuides;
  CM_GUIDE_SNAP:Begin
   SnapGuides:=Not SnapGuides;
   If SnapGuides Then ShowGuides:=True;
  End;
  CM_GUIDE_ADD:AddGuide;
  CM_GUIDE_CLEAR:GuideN:=0;
 End;
 If EditMsg<>'' Then StatusMsg:=EditMsg;
End;

Procedure DoCommand(Cmd:Integer);
Var C,C2:Integer;
    I:LongInt;
    S:String;
    N:LongInt;
    X1,Y1,X2,Y2:LongInt;
Begin
 StatusMsg:='';
 If Not IsEnabled(Cmd)Then Exit;
 NeedRedraw:=True;
 Case Cmd Of
  CM_NEW:DoNew;
  CM_OPEN:DoOpen;
  CM_SAVE:DoSave;
  CM_SAVEAS:DoSaveAs;
  CM_IMPORT:DoImport;
  CM_EXPORTSVG:DoExportSVG;
  CM_EXPORTCDR9:DoExportCDR9;
  CM_EXPORTV:DoExportVec;
  CM_INFO:ShowDocInfo(False);
  CM_STATS:ShowDocInfo(True);
  CM_QUIT:If ConfirmDiscard Then Running:=False;
  CM_UNDO:DoUndo;
  CM_REDO:DoRedo;
  CM_CUT:Begin ClipCopy; PushUndo; DeleteSelection; End;
  CM_COPY:Begin ClipCopy; StatusMsg:='Copié'; End;
  CM_PASTE:ClipPaste;
  CM_DUP:Duplicate;
  CM_DEL:Begin PushUndo; DeleteSelection; End;
  CM_SELALL:Begin
   For I:=0 To ObjCount-1 Do If ObjPickable(ObjAt(I))Then ObjAt(I)^.Sel:=True;
  End;
  CM_SELNONE:DeselectAll;
  CM_SELNEXT:SelectNext;
  CM_ZIN:ZoomAt(CanvasW Div 2,CanvasH Div 2,3,2);
  CM_ZOUT:ZoomAt(CanvasW Div 2,CanvasH Div 2,2,3);
  CM_ZFIT:ZoomFit;
  CM_Z100:Begin
   ZoomAt(CanvasW Div 2,CanvasH Div 2,1,1);
   Zoom:=378;
   ClampView;
  End;
  CM_ZSEL:If SelBBox(X1,Y1,X2,Y2)Then ZoomRect(X1,Y1,X2,Y2);
  CM_WIRE:WireMode:=Not WireMode;
  CM_GRID:ShowGrid:=Not ShowGrid;
  CM_RULERS:ShowRulers:=Not ShowRulers;
  CM_SNAP:SnapGrid:=Not SnapGrid;
  CM_PREVIEW:ShowPreviewFull;
  CM_PAGE_A4:SetPage(2100,2970);
  CM_PAGE_A5:SetPage(1480,2100);
  CM_PAGE_A3:SetPage(2970,4200);
  CM_PAGE_LET:SetPage(2160,2790);
  CM_PORTRAIT:SetOrientation(False);
  CM_LANDSCAPE:SetOrientation(True);
  CM_GRIDSIZE:Begin
   S:=IStr(GridSize Div 10);
   If InputBox('Grille','Pas de la grille (mm) :',S,5)Then Begin
    Val(S,N,C);
    If(C=0)and(N>=1)and(N<=100)Then GridSize:=N*10;
   End;
  End;
  CM_FRONT:Begin PushUndo; ToFront; End;
  CM_BACK:Begin PushUndo; ToBack; End;
  CM_FWD:Begin PushUndo; OneForward; End;
  CM_BWD:Begin PushUndo; OneBackward; End;
  CM_GROUP:Begin PushUndo; GroupSel; End;
  CM_UNGROUP:Begin PushUndo; UngroupSel; End;
  CM_AL_L..CM_AL_B:Begin PushUndo; AlignSel(Cmd-CM_AL_L); End;
  CM_DISTH:Begin PushUndo; DistributeSel(True); End;
  CM_DISTV:Begin PushUndo; DistributeSel(False); End;
  CM_ROT90:Begin PushUndo; TransformSel(0); End;
  CM_FLIPH:Begin PushUndo; TransformSel(1); End;
  CM_FLIPV:Begin PushUndo; TransformSel(2); End;
  CM_TOCURVE:Begin PushUndo; ConvertToCurves; End;
  CM_FILL_NONE:Begin ApplyFillKind(FK_NONE,-1,-1); If SelCount=0 Then DefFill:=-1; End;
  CM_FILL_SOLID:Begin
   C:=ColorBox('Remplissage uniforme',False);
   If C>=0 Then ApplyFillKind(FK_SOLID,C,15);
  End;
  CM_FILL_GV,CM_FILL_GH,CM_FILL_RAD:Begin
   C:=ColorBox('Dégradé : couleur de départ',False);
   If C>=0 Then Begin
    C2:=ColorBox('Dégradé : couleur de fin',False);
    If C2>=0 Then Begin
     If Cmd=CM_FILL_GV Then ApplyFillKind(FK_GRADV,C,C2)
      Else If Cmd=CM_FILL_RAD Then ApplyFillKind(FK_RADIAL,C,C2)
      Else ApplyFillKind(FK_GRADH,C,C2);
    End;
   End;
  End;
  CM_FILL_PAT:Begin
   ChItems[0]:='Lignes horizontales';
   ChItems[1]:='Lignes verticales';
   ChItems[2]:='Hachures /';
   ChItems[3]:='Hachures \';
   ChItems[4]:='Quadrillage';
   ChItems[5]:='Points';
   ChItems[6]:='Damier';
   ChItems[7]:='Trame 50%';
   I:=ChoiceBox('Motif de remplissage',8,0);
   If I>=0 Then Begin
    C:=ColorBox('Motif : couleur du dessin',False);
    If C>=0 Then Begin
     C2:=ColorBox('Motif : couleur du fond',True);
     If C2>-2 Then Begin
      DefPattern:=I+1;
      ApplyFillKind(FK_PATTERN,C,C2);
      For N:=0 To ObjCount-1 Do
       If ObjAt(N)^.Sel and(ObjAt(N)^.FillKind=FK_PATTERN)Then ObjAt(N)^.Pattern:=I+1;
     End;
    End;
   End;
  End;
  CM_OUT_COLOR:Begin
   C:=ColorBox('Couleur du contour',True);
   If C>-2 Then ApplyOutColor(C);
  End;
  CM_OUT_NONE:ApplyOutColor(-1);
  CM_OUT_WIDTH:Begin
   ChItems[0]:='Très fin';
   ChItems[1]:='0,2 mm';
   ChItems[2]:='0,5 mm';
   ChItems[3]:='1 mm';
   ChItems[4]:='2 mm';
   ChItems[5]:='3 mm';
   ChItems[6]:='4 mm';
   I:=ChoiceBox('Épaisseur du contour',7,3);
   Case I Of
    0:ApplyOutWidth(1);
    1:ApplyOutWidth(2);
    2:ApplyOutWidth(5);
    3:ApplyOutWidth(10);
    4:ApplyOutWidth(20);
    5:ApplyOutWidth(30);
    6:ApplyOutWidth(40);
   End;
  End;
  CM_OUT_STYLE:Begin
   ChItems[0]:='Continu';
   ChItems[1]:='Pointillé';
   ChItems[2]:='Tirets';
   I:=ChoiceBox('Style du contour',3,0);
   If I>=0 Then Begin
    If SelCount=0 Then DefLineStyle:=I
     Else Begin
      PushUndo;
      For N:=0 To ObjCount-1 Do If ObjAt(N)^.Sel Then ObjAt(N)^.LineStyle:=I;
     End;
   End;
  End;
  CM_SHADOW:ToggleFlag(0);
  CM_EXTRUDE:ToggleFlag(1);
  CM_TEXT_EDIT:EditText;
  CM_TEXT_BIG:ResizeText(20);
  CM_TEXT_SMALL:ResizeText(-20);
  CM_SIDES:Begin
   S:=IStr(PolySides);
   If InputBox('Polygone / étoile','Nombre de côtés (3 à 32) :',S,3)Then Begin
    Val(S,N,C);
    If(C=0)and(N>=3)and(N<=32)Then PolySides:=N;
   End;
  End;
  CM_RESETDEF:ResetDefaults;
  CM_HELPKEYS:ShowHelp;
  CM_ABOUT:ShowAbout;
  CM_W1..CM_W5:Begin
   Case Cmd Of
    CM_W1:ApplyOutWidth(1);
    CM_W2:ApplyOutWidth(2);
    CM_W3:ApplyOutWidth(5);
    CM_W4:ApplyOutWidth(10);
    CM_W5:ApplyOutWidth(20);
   End;
  End;
  CM_SIDES_UP:If CurTool=T_TEXT Then ResizeText(20)
              Else If PolySides<32 Then Inc(PolySides);
  CM_SIDES_DN:If CurTool=T_TEXT Then ResizeText(-20)
              Else If PolySides>3 Then Dec(PolySides);
  Else DoEdit(Cmd);
 End;
End;

{ ------------------------------------------------------------------ }
{ Redessin                                                           }
{ ------------------------------------------------------------------ }

Var
 DragMode,HandleSel:Integer;
 DX0,DY0,DCX,DCY:Integer;
 PreviewOn:Boolean;
 PrevX,PrevY:Integer;
 Building:Boolean;
 BuildN:Integer;
 BuildPts:Array[0..299] of TPt;
 OBX1,OBY1,OBX2,OBY2:LongInt;
 LastClickT:LongInt;
 LastClickX,LastClickY:Integer;
 ScrollGrab:Integer;
 CursorTxt,LastCursorTxt:String;
 NodeUndone:Boolean;
 GuideDrag,GDX,GDY:Integer;

Procedure RedrawAll;
Begin
 MouseOff;
 If PalDirty Then ApplyPalette;
 SetWriteMode(CopyPut);
 SetLineStyle(SolidLn,0,NormWidth);
 DrawCanvas;
 DrawToolbox;
 DrawIconBar;
 DrawPropBar;
 DrawRulers;
 DrawScrollbars;
 DrawPalette;
 DrawMenuBar;
 DrawStatus(CursorTxt);
 If MenuIdx>=0 Then DrawDrop(MenuIdx);
 PreviewOn:=False;
 MouseOn;
End;

Procedure RefreshStatus;
Begin
 MouseOff;
 DrawStatus(CursorTxt);
 MouseOn;
End;

{ ------------------------------------------------------------------ }
{ Apercus XOR                                                        }
{ ------------------------------------------------------------------ }

Procedure SizeBoxFor(CX,CY:Integer;Var NX1,NY1,NX2,NY2:LongInt);
Var MXw,MYw:LongInt;
Begin
 MXw:=SnapWX(S2WX(CX));
 MYw:=SnapWY(S2WY(CY));
 NX1:=OBX1; NY1:=OBY1; NX2:=OBX2; NY2:=OBY2;
 Case HandleSel Of
  1:Begin NX1:=MXw; NY1:=MYw; End;
  2:NY1:=MYw;
  3:Begin NX2:=MXw; NY1:=MYw; End;
  4:NX2:=MXw;
  5:Begin NX2:=MXw; NY2:=MYw; End;
  6:NY2:=MYw;
  7:Begin NX1:=MXw; NY2:=MYw; End;
  8:NX1:=MXw;
 End;
 If NX2-NX1<10 Then Begin
  If HandleSel In [1,7,8] Then NX1:=NX2-10 Else NX2:=NX1+10;
 End;
 If NY2-NY1<10 Then Begin
  If HandleSel In [1,2,3] Then NY1:=NY2-10 Else NY2:=NY1+10;
 End;
End;

Procedure MoveDeltaFor(CX,CY:Integer;Var DX,DY:LongInt);
Var NX,NY:LongInt;
Begin
 NX:=SnapWX(OBX1+((LongInt(CX)-DX0)*1000) Div Zoom);
 NY:=SnapWY(OBY1+((LongInt(CY)-DY0)*1000) Div Zoom);
 DX:=NX-OBX1;
 DY:=NY-OBY1;
End;

Procedure PolyOutlineXor;
Var I:Integer;
Begin
 If PN<2 Then Exit;
 For I:=0 To PN-2 Do Line(PX[I],PY[I],PX[I+1],PY[I+1]);
 If PClosed Then Line(PX[PN-1],PY[PN-1],PX[0],PY[0]);
End;

Procedure XorShape(CX,CY:Integer);
Var DXw,DYw,NX1,NY1,NX2,NY2:LongInt;
    I:LongInt;
    O:PObj;
    X1,Y1,X2,Y2:Integer;
Begin
 BeginCanvas;
 SetWriteMode(XORPut);
 SetColor(15);
 SetLineStyle(SolidLn,0,NormWidth);
 Case DragMode Of
  DM_MOVE:Begin
   MoveDeltaFor(CX,CY,DXw,DYw);
   If SelCount<=12 Then Begin
    For I:=0 To ObjCount-1 Do
     If ObjAt(I)^.Sel Then Begin
      BuildPoly(ObjAt(I),DXw,DYw);
      PolyOutlineXor;
     End;
   End
    Else
   Rectangle(CL(W2SX(OBX1+DXw)),CL(W2SY(OBY1+DYw)),CL(W2SX(OBX2+DXw)),CL(W2SY(OBY2+DYw)));
  End;
  DM_SIZE:Begin
   SizeBoxFor(CX,CY,NX1,NY1,NX2,NY2);
   Rectangle(CL(W2SX(NX1)),CL(W2SY(NY1)),CL(W2SX(NX2)),CL(W2SY(NY2)));
  End;
  DM_MARQUEE,DM_ZBOX:Begin
   SetLineStyle(DashedLn,0,NormWidth);
   Rectangle(DX0,DY0,CX,CY);
  End;
  DM_CREATE:Begin
   Case CurTool Of
    T_LINE:Line(DX0,DY0,CX,CY);
    T_RECT:Rectangle(DX0,DY0,CX,CY);
    T_ELLIPSE:Begin
     X1:=(DX0+CX) Div 2; Y1:=(DY0+CY) Div 2;
     X2:=Abs(CX-DX0) Div 2; Y2:=Abs(CY-DY0) Div 2;
     If(X2>0)and(Y2>0)Then Ellipse(X1,Y1,0,360,X2,Y2);
    End;
    T_POLYGON,T_STAR:Begin
     If(Abs(CX-DX0)>2)and(Abs(CY-DY0)>2)Then Begin
      O:=MakeRegular(S2WX((DX0+CX) Div 2),S2WY((DY0+CY) Div 2),
                     (Abs(CX-DX0)*500) Div Zoom,(Abs(CY-DY0)*500) Div Zoom,
                     PolySides,CurTool=T_STAR);
      BuildPoly(O,0,0);
      PolyOutlineXor;
      FreeObj(O);
     End;
    End;
   End;
  End;
 End;
 SetWriteMode(CopyPut);
 EndCanvas;
End;

{ Segment elastique pendant la construction d'une polyligne/courbe }
Procedure XorBuild(CX,CY:Integer);
Var I:Integer;
Begin
 If BuildN=0 Then Exit;
 BeginCanvas;
 SetWriteMode(XORPut);
 SetColor(15);
 For I:=0 To BuildN-2 Do
  Line(CL(W2SX(BuildPts[I].X)),CL(W2SY(BuildPts[I].Y)),
       CL(W2SX(BuildPts[I+1].X)),CL(W2SY(BuildPts[I+1].Y)));
 Line(CL(W2SX(BuildPts[BuildN-1].X)),CL(W2SY(BuildPts[BuildN-1].Y)),CX,CY);
 SetWriteMode(CopyPut);
 EndCanvas;
End;

Procedure ErasePreview;
Begin
 If PreviewOn Then Begin
  MouseOff;
  If Building Then XorBuild(PrevX,PrevY) Else XorShape(PrevX,PrevY);
  MouseOn;
  PreviewOn:=False;
 End;
End;

Procedure ShowPreviewAt(CX,CY:Integer);
Begin
 ErasePreview;
 MouseOff;
 If Building Then XorBuild(CX,CY) Else XorShape(CX,CY);
 MouseOn;
 PrevX:=CX; PrevY:=CY;
 PreviewOn:=True;
End;

{ ------------------------------------------------------------------ }
{ Creation d'objets                                                  }
{ ------------------------------------------------------------------ }

Procedure CommitObject(O:PObj);
Begin
 DeselectAll;
 O^.Sel:=True;
 If Not AddObj(O)Then StatusMsg:='Nombre maximum d''objets atteint';
 NeedRedraw:=True;
End;

Procedure FinishBuild;
Var O:PObj;
    I:Integer;
Begin
 ErasePreview;
 If BuildN>=2 Then Begin
  PushUndo;
  If CurTool=T_CURVE Then O:=MakeSmoothCurve(BuildPts,BuildN)
  Else Begin
   O:=NewObj(K_POLYLINE,BuildN);
   For I:=0 To BuildN-1 Do O^.Pts^[I]:=BuildPts[I];
  End;
  CommitObject(O);
 End;
 Building:=False;
 BuildN:=0;
 NeedRedraw:=True;
End;

Procedure CancelBuild;
Begin
 ErasePreview;
 Building:=False;
 BuildN:=0;
 NeedRedraw:=True;
End;

Procedure CreateFromDrag(CX,CY:Integer);
Var X1,Y1,X2,Y2,T:LongInt;
    O:PObj;
Begin
 If(Abs(CX-DX0)<3)and(Abs(CY-DY0)<3)Then Exit;
 X1:=SnapWX(S2WX(DX0)); Y1:=SnapWY(S2WY(DY0));
 X2:=SnapWX(S2WX(CX)); Y2:=SnapWY(S2WY(CY));
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
 PushUndo;
 O:=NIL;
 Case CurTool Of
  T_LINE:Begin
   O:=NewObj(K_LINE,2);
   O^.Pts^[0].X:=SnapWX(S2WX(DX0)); O^.Pts^[0].Y:=SnapWY(S2WY(DY0));
   O^.Pts^[1].X:=SnapWX(S2WX(CX)); O^.Pts^[1].Y:=SnapWY(S2WY(CY));
  End;
  T_RECT:Begin
   O:=NewObj(K_RECT,2);
   O^.Pts^[0].X:=X1; O^.Pts^[0].Y:=Y1;
   O^.Pts^[1].X:=X2; O^.Pts^[1].Y:=Y2;
   O^.Closed:=True;
  End;
  T_ELLIPSE:Begin
   O:=NewObj(K_ELLIPSE,2);
   O^.Pts^[0].X:=X1; O^.Pts^[0].Y:=Y1;
   O^.Pts^[1].X:=X2; O^.Pts^[1].Y:=Y2;
   O^.Closed:=True;
  End;
  T_POLYGON,T_STAR:
   O:=MakeRegular((X1+X2) Div 2,(Y1+Y2) Div 2,(X2-X1) Div 2,(Y2-Y1) Div 2,PolySides,CurTool=T_STAR);
 End;
 If O<>NIL Then CommitObject(O);
End;

Procedure CreateText(CX,CY:Integer);
Var S:String;
    O:PObj;
Begin
 S:='';
 If Not InputBox('Texte artistique','Texte :',S,60)Then Exit;
 If S='' Then Exit;
 PushUndo;
 O:=NewObj(K_TEXT,1);
 O^.Pts^[0].X:=SnapWX(S2WX(CX));
 O^.Pts^[0].Y:=SnapWY(S2WY(CY));
 O^.Txt:=S;
 O^.TextSize:=DefTextSize;
 If DefFill>=0 Then O^.FillCol:=DefFill Else O^.FillCol:=DefOut;
 If O^.FillCol<0 Then O^.FillCol:=0;
 O^.FillKind:=FK_SOLID;
 O^.OutCol:=-1;
 CommitObject(O);
End;

{ ------------------------------------------------------------------ }
{ Noeuds (outil Forme)                                               }
{ ------------------------------------------------------------------ }

Function HitNode(SX,SY:Integer;Var OI,NI:Integer):Boolean;
Var I,K:LongInt;
    O:PObj;
Begin
 HitNode:=False;
 For I:=ObjCount-1 DownTo 0 Do
  If ObjAt(I)^.Sel and(ObjAt(I)^.Kind<>K_TEXT)Then Begin
   O:=ObjAt(I);
   For K:=O^.N-1 DownTo 0 Do
    If(O^.Pts^[K].X<>BRK)and(Abs(SX-W2SX(O^.Pts^[K].X))<=5)and(Abs(SY-W2SY(O^.Pts^[K].Y))<=5)Then Begin
     OI:=I; NI:=K;
     HitNode:=True;
     Exit;
    End;
  End;
End;

Procedure MoveNode(OI,NI:Integer;WX,WY:LongInt);
Var O:PObj;
    DX,DY:LongInt;
Begin
 O:=ObjAt(OI);
 DX:=WX-O^.Pts^[NI].X;
 DY:=WY-O^.Pts^[NI].Y;
 O^.Pts^[NI].X:=WX;
 O^.Pts^[NI].Y:=WY;
 If(O^.Kind=K_BEZIER)and(NI Mod 3=0)Then Begin
  If(NI>0)and(O^.Pts^[NI-1].X<>BRK)Then Begin Inc(O^.Pts^[NI-1].X,DX); Inc(O^.Pts^[NI-1].Y,DY); End;
  If(NI<O^.N-1)and(O^.Pts^[NI+1].X<>BRK)Then Begin Inc(O^.Pts^[NI+1].X,DX); Inc(O^.Pts^[NI+1].Y,DY); End;
  If O^.Closed and(NI=0)and Not HasBrk(O)Then Begin
   O^.Pts^[O^.N-1].X:=WX; O^.Pts^[O^.N-1].Y:=WY;
   Inc(O^.Pts^[O^.N-2].X,DX); Inc(O^.Pts^[O^.N-2].Y,DY);
  End;
  If O^.Closed and(NI=O^.N-1)and Not HasBrk(O)Then Begin
   O^.Pts^[0].X:=WX; O^.Pts^[0].Y:=WY;
   Inc(O^.Pts^[1].X,DX); Inc(O^.Pts^[1].Y,DY);
  End;
 End;
End;

Procedure InsertNodeAt(SX,SY:Integer);
Var I,K,Best,Seg:Integer;
    O:PObj;
    D,BD:LongInt;
    P:Array[0..3] of TPt;
    L1,M,R2,L2,R1,S:TPt;
    J:Integer;
Begin
 O:=FirstSel;
 If(O=NIL)or(O^.Kind=K_TEXT)Then Exit;
 If(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)or(O^.Kind=K_BITMAP)Then Exit;
 If HasBrk(O)Then Exit;
 BD:=MaxLongInt;
 Seg:=-1;
 If O^.Kind=K_BEZIER Then Begin
  K:=0;
  I:=0;
  While K+3<=O^.N-1 Do Begin
   For J:=0 To 3 Do P[J]:=O^.Pts^[K+J];
   D:=Round(Sqrt(Sqr(SX-W2SX((P[0].X+3*P[1].X+3*P[2].X+P[3].X) Div 8))+
                 Sqr(SY-W2SY((P[0].Y+3*P[1].Y+3*P[2].Y+P[3].Y) Div 8))));
   If D<BD Then Begin BD:=D; Seg:=K; End;
   Inc(K,3);
  End;
  If(Seg<0)or(BD>60)Then Exit;
  PushUndo;
  For J:=0 To 3 Do P[J]:=O^.Pts^[Seg+J];
  L1.X:=(P[0].X+P[1].X) Div 2; L1.Y:=(P[0].Y+P[1].Y) Div 2;
  M.X:=(P[1].X+P[2].X) Div 2;  M.Y:=(P[1].Y+P[2].Y) Div 2;
  R2.X:=(P[2].X+P[3].X) Div 2; R2.Y:=(P[2].Y+P[3].Y) Div 2;
  L2.X:=(L1.X+M.X) Div 2;      L2.Y:=(L1.Y+M.Y) Div 2;
  R1.X:=(M.X+R2.X) Div 2;      R1.Y:=(M.Y+R2.Y) Div 2;
  S.X:=(L2.X+R1.X) Div 2;      S.Y:=(L2.Y+R1.Y) Div 2;
  If O^.N+3>7990 Then Exit;
  ObjSetN(O,O^.N+3);
  For J:=O^.N-1 DownTo Seg+7 Do O^.Pts^[J]:=O^.Pts^[J-3];
  O^.Pts^[Seg+1]:=L1; O^.Pts^[Seg+2]:=L2; O^.Pts^[Seg+3]:=S;
  O^.Pts^[Seg+4]:=R1; O^.Pts^[Seg+5]:=R2;
 End
  Else
 Begin
  K:=O^.N-2;
  If O^.Kind=K_POLY Then K:=O^.N-1;
  For I:=0 To K Do Begin
   J:=I+1;
   If J>=O^.N Then J:=0;
   D:=DistSeg(SX,SY,W2SX(O^.Pts^[I].X),W2SY(O^.Pts^[I].Y),W2SX(O^.Pts^[J].X),W2SY(O^.Pts^[J].Y));
   If D<BD Then Begin BD:=D; Seg:=I; End;
  End;
  If(Seg<0)or(BD>6)Then Exit;
  If O^.N+1>7990 Then Exit;
  PushUndo;
  ObjSetN(O,O^.N+1);
  For J:=O^.N-1 DownTo Seg+2 Do O^.Pts^[J]:=O^.Pts^[J-1];
  O^.Pts^[Seg+1].X:=S2WX(SX);
  O^.Pts^[Seg+1].Y:=S2WY(SY);
 End;
 Best:=0;
End;

Procedure DeleteNode;
Var O:PObj;
    I,K,A:LongInt;
Begin
 If(NodeObj<0)or(NodeObj>=ObjCount)Then Exit;
 O:=ObjAt(NodeObj);
 If NodeIdx<0 Then Exit;
 If HasBrk(O)Then Exit;
 If O^.Kind=K_BEZIER Then Begin
  If(NodeIdx Mod 3<>0)or(O^.N<=4)Then Exit;
  A:=NodeIdx-1;
  If NodeIdx=0 Then A:=0
   Else If NodeIdx=O^.N-1 Then A:=O^.N-3;
  PushUndo;
  O:=ObjAt(NodeObj);
  For I:=A To O^.N-4 Do O^.Pts^[I]:=O^.Pts^[I+3];
  Dec(O^.N,3);
 End
  Else
 Begin
  If((O^.Kind=K_POLY)and(O^.N<=3))or(O^.N<=2)or(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)or(O^.Kind=K_BITMAP)Then Exit;
  PushUndo;
  O:=ObjAt(NodeObj);
  For I:=NodeIdx To O^.N-2 Do O^.Pts^[I]:=O^.Pts^[I+1];
  Dec(O^.N);
 End;
 K:=0;
 NodeIdx:=-1;
 NeedRedraw:=True;
End;

{ ------------------------------------------------------------------ }
{ Menu contextuel                                                    }
{ ------------------------------------------------------------------ }

Procedure OpenPopup(SX,SY:Integer;OnObject:Boolean);
Begin
 SetMenuTitle(POPUP_IDX,'');
 If OnObject Then Begin
  AddItem(POPUP_IDX,'Couper','Ctrl+X',CM_CUT);
  AddItem(POPUP_IDX,'Copier','Ctrl+C',CM_COPY);
  AddItem(POPUP_IDX,'Coller','Ctrl+V',CM_PASTE);
  AddItem(POPUP_IDX,'Dupliquer','Ctrl+D',CM_DUP);
  AddItem(POPUP_IDX,'Supprimer','Suppr',CM_DEL);
  AddSep(POPUP_IDX);
  AddItem(POPUP_IDX,'Premier plan','',CM_FRONT);
  AddItem(POPUP_IDX,'Arrière-plan','',CM_BACK);
  AddSep(POPUP_IDX);
  AddItem(POPUP_IDX,'Grouper','Ctrl+G',CM_GROUP);
  AddItem(POPUP_IDX,'Dégrouper','Ctrl+U',CM_UNGROUP);
  AddItem(POPUP_IDX,'Convertir en courbes','',CM_TOCURVE);
  If CurTool=T_SHAPE Then Begin
   AddSep(POPUP_IDX);
   AddItem(POPUP_IDX,'Segment en ligne','',CM_N_LINE);
   AddItem(POPUP_IDX,'Segment en courbe','',CM_N_CURVE);
   AddItem(POPUP_IDX,'Nœud lisse','',CM_N_SMOOTH);
   AddItem(POPUP_IDX,'Nœud symétrique','',CM_N_SYM);
   AddItem(POPUP_IDX,'Casser au nœud','',CM_N_BREAK);
   AddItem(POPUP_IDX,'Fermer le chemin','',CM_N_CLOSE);
  End;
  AddItem(POPUP_IDX,'Ombre portée','',CM_SHADOW);
 End
  Else
 Begin
  AddItem(POPUP_IDX,'Coller','Ctrl+V',CM_PASTE);
  AddItem(POPUP_IDX,'Tout sélectionner','Ctrl+A',CM_SELALL);
  AddSep(POPUP_IDX);
  AddItem(POPUP_IDX,'Page entière','F4',CM_ZFIT);
  AddItem(POPUP_IDX,'Grille','',CM_GRID);
  AddItem(POPUP_IDX,'Règles','',CM_RULERS);
 End;
 FinishMenus;
 Menus[POPUP_IDX].X:=SX;
 Menus[POPUP_IDX].Y:=SY;
 If SX+Menus[POPUP_IDX].W>ScreenW-4 Then Menus[POPUP_IDX].X:=ScreenW-4-Menus[POPUP_IDX].W;
 If SY+MenuHeight(Menus[POPUP_IDX])>ScreenH-4 Then
  Menus[POPUP_IDX].Y:=ScreenH-4-MenuHeight(Menus[POPUP_IDX]);
 MenuIdx:=POPUP_IDX;
 MenuItemSel:=-1;
 NeedRedraw:=True;
End;

Procedure CloseMenu;
Begin
 MenuIdx:=-1;
 MenuItemSel:=-1;
 NeedRedraw:=True;
End;

Procedure OpenMenu(Idx:Integer);
Begin
 MenuIdx:=Idx;
 MenuItemSel:=-1;
 NeedRedraw:=True;
End;

Procedure MenuStep(Dir:Integer);
Var I,N,Tries:Integer;
Begin
 N:=Menus[MenuIdx].N;
 I:=MenuItemSel;
 Tries:=0;
 Repeat
  I:=I+Dir;
  If I>=N Then I:=0;
  If I<0 Then I:=N-1;
  Inc(Tries);
 Until(Menus[MenuIdx].It[I].Cmd<>0)or(Tries>N);
 MenuItemSel:=I;
 MouseOff;
 DrawDrop(MenuIdx);
 MouseOn;
End;

Procedure RunMenuItem;
Var C:Integer;
Begin
 If(MenuItemSel<0)Then Exit;
 C:=Menus[MenuIdx].It[MenuItemSel].Cmd;
 CloseMenu;
 RedrawAll;
 NeedRedraw:=False;
 DoCommand(C);
End;

{ ------------------------------------------------------------------ }
{ Souris                                                             }
{ ------------------------------------------------------------------ }

Procedure UpdateCursorText(InCanvas:Boolean;CX,CY:Integer);
Begin
 If InCanvas Then CursorTxt:='X:'+MMStr(S2WX(CX))+' Y:'+MMStr(S2WY(CY))
  Else CursorTxt:='';
 If CursorTxt<>LastCursorTxt Then Begin
  LastCursorTxt:=CursorTxt;
  RefreshStatus;
 End;
End;

Procedure StartDrag(Mode,CX,CY:Integer);
Var X1,Y1,X2,Y2:LongInt;
Begin
 DragMode:=Mode;
 DX0:=CX; DY0:=CY; DCX:=CX; DCY:=CY;
 If SelBBox(X1,Y1,X2,Y2)Then Begin
  OBX1:=X1; OBY1:=Y1; OBX2:=X2; OBY2:=Y2;
 End;
 PreviewOn:=False;
End;

Procedure ScrollTo(Horiz:Boolean;Pos:Integer);
Var T1,T2,Tr:Integer;
    VW,VH,Range,View:LongInt;
Begin
 ScrollThumb(Horiz,T1,T2,Tr);
 ViewWorld(VW,VH);
 If Horiz Then Begin Range:=PageW+3000; View:=VW; End
          Else Begin Range:=PageH+3000; View:=VH; End;
 If Tr-(T2-T1)<=0 Then Exit;
 Pos:=Integer(Clamp(Pos,0,Tr-(T2-T1)));
 If Horiz Then OrgX:=-1500+(LongInt(Pos)*(Range-View)) Div (Tr-(T2-T1))
          Else OrgY:=-1500+(LongInt(Pos)*(Range-View)) Div (Tr-(T2-T1));
 ClampView;
End;

Procedure EndDrag(CX,CY:Integer);
Var DXw,DYw,NX1,NY1,NX2,NY2:LongInt;
    I:LongInt;
    X1,Y1,X2,Y2,T:Integer;
    A,B,C,D:LongInt;
Begin
 ErasePreview;
 Case DragMode Of
  DM_MOVE:Begin
   MoveDeltaFor(CX,CY,DXw,DYw);
   If(DXw<>0)or(DYw<>0)Then Begin
    PushUndo;
    For I:=0 To ObjCount-1 Do If ObjAt(I)^.Sel Then ObjMove(ObjAt(I),DXw,DYw);
   End;
  End;
  DM_SIZE:Begin
   SizeBoxFor(CX,CY,NX1,NY1,NX2,NY2);
   If(NX1<>OBX1)or(NY1<>OBY1)or(NX2<>OBX2)or(NY2<>OBY2)Then Begin
    PushUndo;
    For I:=0 To ObjCount-1 Do
     If ObjAt(I)^.Sel Then Begin
      If OBX2-OBX1=0 Then ObjScale(ObjAt(I),OBX1,OBY1,1,1,NY2-NY1,Max(1,OBY2-OBY1))
      Else If OBY2-OBY1=0 Then ObjScale(ObjAt(I),OBX1,OBY1,NX2-NX1,OBX2-OBX1,1,1)
      Else ObjScale(ObjAt(I),OBX1,OBY1,NX2-NX1,OBX2-OBX1,NY2-NY1,OBY2-OBY1);
      ObjMove(ObjAt(I),NX1-OBX1,NY1-OBY1);
     End;
   End;
  End;
  DM_MARQUEE:Begin
   X1:=DX0; Y1:=DY0; X2:=CX; Y2:=CY;
   If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
   If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
   If(X2-X1>3)or(Y2-Y1>3)Then Begin
    A:=S2WX(X1); B:=S2WY(Y1); C:=S2WX(X2); D:=S2WY(Y2);
    DeselectAll;
    For I:=0 To ObjCount-1 Do Begin
     ObjBBox(ObjAt(I),NX1,NY1,NX2,NY2);
     If ObjPickable(ObjAt(I))and(NX1>=A)and(NX2<=C)and(NY1>=B)and(NY2<=D)Then SelectIndex(I);
    End;
   End;
  End;
  DM_ZBOX:Begin
   X1:=DX0; Y1:=DY0; X2:=CX; Y2:=CY;
   If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
   If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
   If(X2-X1>4)and(Y2-Y1>4)Then ZoomRect(S2WX(X1),S2WY(Y1),S2WX(X2),S2WY(Y2))
    Else ZoomAt(CX,CY,2,1);
  End;
  DM_CREATE:CreateFromDrag(CX,CY);
  DM_GUIDE:Begin
   { un repere rejete sur la regle est supprime }
   If(GuideDrag>=0)and(GuideDrag<GuideN)Then
    If(GuideHor[GuideDrag]and(GDY<0))or(Not GuideHor[GuideDrag]and(GDX<0))Then Begin
     For I:=GuideDrag To GuideN-2 Do Begin
      GuideHor[I]:=GuideHor[I+1];
      GuidePos[I]:=GuidePos[I+1];
     End;
     Dec(GuideN);
    End;
   Modified:=True;
   GuideDrag:=-1;
  End;
 End;
 DragMode:=DM_NONE;
 NeedRedraw:=True;
End;

Procedure DragStep(CX,CY:Integer);
Var T1,T2,Tr:Integer;
    VW,VH:LongInt;
Begin
 Case DragMode Of
  DM_PAN:Begin
   OrgX:=OrgX-(LongInt(CX-DCX)*1000) Div Zoom;
   OrgY:=OrgY-(LongInt(CY-DCY)*1000) Div Zoom;
   ClampView;
   DCX:=CX; DCY:=CY;
   NeedRedraw:=True;
  End;
  DM_NODE:Begin
   If(CX<>DCX)or(CY<>DCY)Then Begin
    If Not NodeUndone Then Begin
     PushUndo;
     NodeUndone:=True;
    End;
    MoveNode(NodeObj,NodeIdx,SnapWX(S2WX(CX)),SnapWY(S2WY(CY)));
    DCX:=CX; DCY:=CY;
    NeedRedraw:=True;
   End;
  End;
  DM_GUIDE:Begin
   GDX:=CX;
   GDY:=CY;
   If(GuideDrag>=0)and(GuideDrag<GuideN)Then Begin
    If GuideHor[GuideDrag]Then GuidePos[GuideDrag]:=S2WY(CY)
     Else GuidePos[GuideDrag]:=S2WX(CX);
   End;
   NeedRedraw:=True;
  End;
  DM_SCROLLH:Begin
   ScrollTo(True,MX-CanvasX-1-ScrollGrab);
   NeedRedraw:=True;
  End;
  DM_SCROLLV:Begin
   ScrollTo(False,MY-CanvasY-1-ScrollGrab);
   NeedRedraw:=True;
  End;
 Else
  If(CX<>DCX)or(CY<>DCY)or Not PreviewOn Then Begin
   ShowPreviewAt(CX,CY);
   DCX:=CX; DCY:=CY;
  End;
 End;
 T1:=0; T2:=0; Tr:=0; VW:=0; VH:=0;
End;

Function HitGuide(CX,CY:Integer):Integer;
Var I:Integer;
Begin
 HitGuide:=-1;
 If Not ShowGuides Then Exit;
 For I:=GuideN-1 DownTo 0 Do Begin
  If GuideHor[I]Then Begin
   If Abs(W2SY(GuidePos[I])-CY)<=3 Then Begin HitGuide:=I; Exit; End;
  End
   Else If Abs(W2SX(GuidePos[I])-CX)<=3 Then Begin HitGuide:=I; Exit; End;
 End;
End;

Procedure CanvasPress(CX,CY:Integer);
Var H,I,OI,NI:Integer;
    NowT:LongInt;
    Dbl:Boolean;
    O:PObj;
Begin
 NowT:=Ticks;
 Dbl:=(Abs(NowT-LastClickT)<40)and(Abs(CX-LastClickX)<5)and(Abs(CY-LastClickY)<5);
 LastClickT:=NowT;
 LastClickX:=CX;
 LastClickY:=CY;
 Case CurTool Of
  T_PICK:Begin
   H:=HitHandle(CX,CY);
   If H>0 Then Begin
    HandleSel:=H;
    StartDrag(DM_SIZE,CX,CY);
   End
    Else
   Begin
    I:=HitObject(CX,CY);
    If I>=0 Then Begin
     If Dbl and(ObjAt(I)^.Kind=K_TEXT)Then Begin
      DeselectAll;
      SelectIndex(I);
      EditText;
      NeedRedraw:=True;
      Exit;
     End;
     If Not ObjAt(I)^.Sel Then Begin
      DeselectAll;
      SelectIndex(I);
      NeedRedraw:=True;
      RedrawAll;
      NeedRedraw:=False;
     End;
     StartDrag(DM_MOVE,CX,CY);
    End
     Else
    Begin
     If SelCount>0 Then Begin
      DeselectAll;
      NeedRedraw:=True;
      RedrawAll;
      NeedRedraw:=False;
     End;
     GuideDrag:=HitGuide(CX,CY);
     If GuideDrag>=0 Then Begin
      GDX:=CX;
      GDY:=CY;
      StartDrag(DM_GUIDE,CX,CY);
     End
      Else StartDrag(DM_MARQUEE,CX,CY);
    End;
   End;
  End;
  T_SHAPE:Begin
   If HitNode(CX,CY,OI,NI)Then Begin
    NodeObj:=OI; NodeIdx:=NI;
    NodeUndone:=False;
    StartDrag(DM_NODE,CX,CY);
   End
    Else
   Begin
    I:=HitObject(CX,CY);
    If I>=0 Then Begin
     If Dbl and ObjAt(I)^.Sel Then Begin
      InsertNodeAt(CX,CY);
      NeedRedraw:=True;
     End
      Else Begin
       DeselectAll;
       SelectIndex(I);
       NodeObj:=-1; NodeIdx:=-1;
       NeedRedraw:=True;
      End;
    End
     Else Begin
      DeselectAll;
      NeedRedraw:=True;
     End;
   End;
  End;
  T_ZOOM:StartDrag(DM_ZBOX,CX,CY);
  T_HAND:StartDrag(DM_PAN,CX,CY);
  T_LINE,T_RECT,T_ELLIPSE,T_POLYGON,T_STAR:StartDrag(DM_CREATE,CX,CY);
  T_TEXT:CreateText(CX,CY);
  T_POLYLINE,T_CURVE:Begin
   If Not Building Then Begin
    Building:=True;
    BuildN:=0;
   End;
   ErasePreview;
   If Dbl and(BuildN>=1)Then Begin
    FinishBuild;
   End
    Else
   If BuildN<299 Then Begin
    BuildPts[BuildN].X:=SnapWX(S2WX(CX));
    BuildPts[BuildN].Y:=SnapWY(S2WY(CY));
    Inc(BuildN);
    ShowPreviewAt(CX,CY);
   End;
  End;
 End;
 O:=NIL;
End;

Procedure ChooseTool(T:Integer);
Begin
 If Building Then CancelBuild;
 CurTool:=T;
 NeedRedraw:=True;
End;

Procedure HandleMenuMouse(LP,RP:Boolean);
Var B,I:Integer;
Begin
 B:=MenuBarAt(MX,MY);
 If(MenuIdx<POPUP_IDX)and(B>=0)and(B<>MenuIdx)Then Begin
  OpenMenu(B);
  Exit;
 End;
 I:=MenuItemAt(MenuIdx,MX,MY);
 If I<>MenuItemSel Then Begin
  MenuItemSel:=I;
  MouseOff;
  DrawDrop(MenuIdx);
  MouseOn;
 End;
 If LP or RP Then Begin
  If I>=0 Then RunMenuItem
   Else If(B=MenuIdx)and(MenuIdx<POPUP_IDX)Then CloseMenu
   Else CloseMenu;
  WaitUp;
 End;
End;

Procedure HandlePress(RightBtn:Boolean);
Var CX,CY,B,C,I:Integer;
    InCanvas:Boolean;
    T1,T2,Tr:Integer;
Begin
 CX:=MX-CanvasX;
 CY:=MY-CanvasY;
 InCanvas:=(CX>=0)and(CY>=0)and(CX<CanvasW)and(CY<CanvasH);
 StatusMsg:='';
 { Barre de menus }
 B:=MenuBarAt(MX,MY);
 If B>=0 Then Begin
  If Not RightBtn Then OpenMenu(B);
  Exit;
 End;
 { Palette }
 C:=PaletteAt(MX,MY);
 If C>-2 Then Begin
  If RightBtn Then ApplyOutColor(C) Else ApplyFillColor(C);
  NeedRedraw:=True;
  Exit;
 End;
 If RightBtn Then Begin
  If InCanvas Then Begin
   Case CurTool Of
    T_POLYLINE,T_CURVE:Begin
     If Building Then FinishBuild;
    End;
    T_ZOOM:Begin
     ZoomAt(CX,CY,1,2);
     NeedRedraw:=True;
    End;
   Else Begin
    I:=HitObject(CX,CY);
    If I>=0 Then Begin
     If Not ObjAt(I)^.Sel Then Begin
      DeselectAll;
      SelectIndex(I);
     End;
     OpenPopup(MX,MY,True);
    End
     Else OpenPopup(MX,MY,False);
   End;
   End;
  End;
  Exit;
 End;
 { Barre d'icones }
 C:=IconAt(MX,MY);
 If C>0 Then Begin
  DoCommand(C);
  WaitUp;
  Exit;
 End;
 { Barre de proprietes }
 C:=PropBarAt(MX,MY);
 If C>0 Then Begin
  DoCommand(C);
  WaitUp;
  Exit;
 End;
 { Boite a outils }
 C:=ToolAt(MX,MY);
 If C>=0 Then Begin
  ChooseTool(C);
  Exit;
 End;
 { Regles : on en tire un repere }
 If ShowRulers and(GuideN<GUIDE_MAX)Then Begin
  If InRect(MX,MY,CanvasX,CanvasY-RULER_SIZE,CanvasW,RULER_SIZE)Then Begin
   GuideHor[GuideN]:=True;
   GuidePos[GuideN]:=S2WY(0);
   GuideDrag:=GuideN;
   Inc(GuideN);
   ShowGuides:=True;
   GDX:=0; GDY:=-1;
   StartDrag(DM_GUIDE,CX,0);
   NeedRedraw:=True;
   Exit;
  End;
  If InRect(MX,MY,CanvasX-RULER_SIZE,CanvasY,RULER_SIZE,CanvasH)Then Begin
   GuideHor[GuideN]:=False;
   GuidePos[GuideN]:=S2WX(0);
   GuideDrag:=GuideN;
   Inc(GuideN);
   ShowGuides:=True;
   GDX:=-1; GDY:=0;
   StartDrag(DM_GUIDE,0,CY);
   NeedRedraw:=True;
   Exit;
  End;
 End;
 { Barres de defilement }
 If InRect(MX,MY,CanvasX,CanvasY+CanvasH,CanvasW,SCROLL_W)Then Begin
  ScrollThumb(True,T1,T2,Tr);
  If(MX-CanvasX-1>=T1)and(MX-CanvasX-1<=T2)Then ScrollGrab:=MX-CanvasX-1-T1
   Else Begin ScrollGrab:=(T2-T1) Div 2; ScrollTo(True,MX-CanvasX-1-ScrollGrab); End;
  DragMode:=DM_SCROLLH;
  NeedRedraw:=True;
  Exit;
 End;
 If InRect(MX,MY,CanvasX+CanvasW,CanvasY,SCROLL_W,CanvasH)Then Begin
  ScrollThumb(False,T1,T2,Tr);
  If(MY-CanvasY-1>=T1)and(MY-CanvasY-1<=T2)Then ScrollGrab:=MY-CanvasY-1-T1
   Else Begin ScrollGrab:=(T2-T1) Div 2; ScrollTo(False,MY-CanvasY-1-ScrollGrab); End;
  DragMode:=DM_SCROLLV;
  NeedRedraw:=True;
  Exit;
 End;
 If InCanvas Then CanvasPress(CX,CY);
End;

Procedure HandleMouse;
Var L,R,LP,RP:Boolean;
    CX,CY:Integer;
    InCanvas:Boolean;
Begin
 L:=(MB And 1)<>0;
 R:=(MB And 2)<>0;
 LP:=L And((OldMB And 1)=0);
 RP:=R And((OldMB And 2)=0);
 CX:=MX-CanvasX;
 CY:=MY-CanvasY;
 InCanvas:=(CX>=0)and(CY>=0)and(CX<CanvasW)and(CY<CanvasH);
 If MenuIdx>=0 Then Begin
  HandleMenuMouse(LP,RP);
  Exit;
 End;
 If DragMode<>DM_NONE Then Begin
  If L Then Begin
   If InCanvas or(DragMode>=DM_PAN)Then DragStep(CX,CY)
    Else DragStep(Integer(Clamp(CX,0,CanvasW-1)),Integer(Clamp(CY,0,CanvasH-1)));
  End
   Else Begin
    EndDrag(Integer(Clamp(DCX,0,CanvasW-1)),Integer(Clamp(DCY,0,CanvasH-1)));
   End;
  Exit;
 End;
 UpdateCursorText(InCanvas,CX,CY);
 If LP Then HandlePress(False)
  Else If RP Then HandlePress(True)
  Else
 If Building and InCanvas Then Begin
  If(CX<>PrevX)or(CY<>PrevY)or Not PreviewOn Then ShowPreviewAt(CX,CY);
 End;
End;

{ ------------------------------------------------------------------ }
{ Clavier                                                            }
{ ------------------------------------------------------------------ }

Procedure Nudge(DX,DY:LongInt);
Var I:LongInt;
Begin
 PushUndo;
 For I:=0 To ObjCount-1 Do If ObjAt(I)^.Sel Then ObjMove(ObjAt(I),DX,DY);
 NeedRedraw:=True;
End;

Procedure ScrollView(DX,DY:Integer);
Begin
 OrgX:=OrgX+(LongInt(DX)*30*1000) Div Zoom;
 OrgY:=OrgY+(LongInt(DY)*30*1000) Div Zoom;
 ClampView;
 NeedRedraw:=True;
End;

Procedure HandleMenuKey(K:Char;Ext:Boolean);
Begin
 If Ext Then Begin
  Case K Of
   #72:MenuStep(-1);
   #80:MenuStep(1);
   #75:If MenuIdx<POPUP_IDX Then OpenMenu((MenuIdx+MENU_COUNT-1) Mod MENU_COUNT);
   #77:If MenuIdx<POPUP_IDX Then OpenMenu((MenuIdx+1) Mod MENU_COUNT);
  End;
 End
  Else
 Begin
  If K=#27 Then CloseMenu
   Else If K=#13 Then RunMenuItem;
 End;
End;

Procedure HandleKey;
Var K:Char;
    Ext:Boolean;
    Step:LongInt;
Begin
 K:=GetKey(Ext);
 If MenuIdx>=0 Then Begin
  HandleMenuKey(K,Ext);
  Exit;
 End;
 StatusMsg:='';
 If Building Then Begin
  If(K=#13)and Not Ext Then Begin FinishBuild; Exit; End;
  If(K=#27)and Not Ext Then Begin CancelBuild; Exit; End;
  If(K=#8)and Not Ext Then Begin
   ErasePreview;
   If BuildN>0 Then Dec(BuildN);
   If BuildN=0 Then Building:=False;
   Exit;
  End;
 End;
 If Ext Then Begin
  Step:=10;
  Case K Of
   #83:If(CurTool=T_SHAPE)and(NodeIdx>=0)Then DeleteNode
        Else DoCommand(CM_DEL);
   #72:If SelCount>0 Then Nudge(0,-Step) Else ScrollView(0,-1);
   #80:If SelCount>0 Then Nudge(0,Step) Else ScrollView(0,1);
   #75:If SelCount>0 Then Nudge(-Step,0) Else ScrollView(-1,0);
   #77:If SelCount>0 Then Nudge(Step,0) Else ScrollView(1,0);
   #73:DoCommand(CM_FWD);
   #81:DoCommand(CM_BWD);
   #132:DoCommand(CM_FRONT);
   #118:DoCommand(CM_BACK);
   #59:DoCommand(CM_HELPKEYS);
   #60:DoCommand(CM_ZSEL);
   #61:DoCommand(CM_Z100);
   #62:DoCommand(CM_ZFIT);
   #66:DoCommand(CM_TEXT_EDIT);
   #67:DoCommand(CM_PREVIEW);
   #68:OpenMenu(0);
   #45:DoCommand(CM_QUIT);
  End;
  Exit;
 End;
 Case K Of
  #14:DoCommand(CM_NEW);
  #15:DoCommand(CM_OPEN);
  #19:DoCommand(CM_SAVE);
  #26:DoCommand(CM_UNDO);
  #25:DoCommand(CM_REDO);
  #24:DoCommand(CM_CUT);
  #3:DoCommand(CM_COPY);
  #22:DoCommand(CM_PASTE);
  #4:DoCommand(CM_DUP);
  #1:DoCommand(CM_SELALL);
  #7:DoCommand(CM_GROUP);
  #21:DoCommand(CM_UNGROUP);
  #17:DoCommand(CM_TOCURVE);
  #18:DoCommand(CM_ROT90);
  #9:DoCommand(CM_SELNEXT);
  #27:Begin
   DeselectAll;
   NeedRedraw:=True;
  End;
  '+','=':DoCommand(CM_ZIN);
  '-','_':DoCommand(CM_ZOUT);
  '[':DoCommand(CM_ROT_L);
  ']':DoCommand(CM_ROT_R);
  'p','P':ChooseTool(T_PICK);
  'n','N':ChooseTool(T_SHAPE);
  'z','Z':ChooseTool(T_ZOOM);
  'h','H':ChooseTool(T_HAND);
  'l','L':ChooseTool(T_LINE);
  'y','Y':ChooseTool(T_POLYLINE);
  'b','B':ChooseTool(T_CURVE);
  'r','R':ChooseTool(T_RECT);
  'e','E':ChooseTool(T_ELLIPSE);
  'g','G':ChooseTool(T_POLYGON);
  's','S':ChooseTool(T_STAR);
  't','T':ChooseTool(T_TEXT);
 End;
End;

Procedure MainLoop;
Begin
 Running:=True;
 NeedRedraw:=True;
 OldMB:=0;
 While Running Do Begin
  PollMouse;
  HandleMouse;
  While KeyPressed And Running Do HandleKey;
  If NeedRedraw Then Begin
   NeedRedraw:=False;
   RedrawAll;
  End;
  OldMB:=MB;
  Delay(8);
 End;
End;

Procedure RunInteractive;
Begin
 InitGfx;
 MouseInit;
 MouseHidden:=True;
 InitIconBar;
 InitMenus;
 CurTool:=T_PICK;
 DragMode:=DM_NONE;
 Building:=False;
 BuildN:=0;
 NodeObj:=-1;
 NodeIdx:=-1;
 CursorTxt:='';
 LastCursorTxt:='';
 StatusMsg:='';
 PasteN:=0;
 Zoom:=100;
 ZoomFit;
 If ParamCount>=1 Then Begin
  If FileExists(ParamStr(1))Then Begin
   If LoadAny(ParamStr(1))Then Begin
    If(ExtOf(ParamStr(1))='.WPG')or FromCorel Then DocName:=''
                                 Else DocName:=FExpand(ParamStr(1));
    Modified:=False;
    ZoomAll;
   End;
  End;
 End;
 MouseOn;
 MainLoop;
 MouseOff;
 CloseGraph;
End;

Procedure ShowUsage;
Begin
 WriteLn('CORELDRW : clone de CorelDraw (dessin vectoriel).');
 WriteLn;
 WriteLn('Syntaxe : CORELDRW [fichier.cdr|fichier.wpg]');
 WriteLn('          CORELDRW /SAMPLES');
 WriteLn('          CORELDRW /CONVERT entree sortie   (CDR, WPG vers CDR ou SVG)');
End;

{ /CONVERT ... /DO:op,op : applique des operations d'edition avant
  l'enregistrement (essais et traitements par lots). Operations : SEL:n
  SELALL DESEL WELD INTER FMB BMF KNIFE COMBINE BREAK ROT:deg SKEW:h:v
  SCALE:sx:sy WARP:mode:pct BLEND:n CONTOUR:n:dist DIMH DIMV CONNECT
  SAMEFILL TOCURVE NODE:objet:noeud:op CLOSE PADD PNEXT LAYER:n
  HIDE:n LOCK:n GUIDE:h:pos CON SQ }
Procedure BatchOps(Const Spec:String);
Var Rest,Tok:String;
    A:Array[0..3] of Real;
    P,N,C,I:Integer;
    Nm:String;
    O,Q,R,T:PObj;
Begin
 Rest:=Spec+',';
 While Rest<>'' Do Begin
  P:=Pos(',',Rest);
  Tok:=Copy(Rest,1,P-1);
  Delete(Rest,1,P);
  If Tok='' Then Continue;
  N:=0;
  For I:=0 To 3 Do A[I]:=0;
  P:=Pos(':',Tok);
  If P=0 Then Nm:=UpStr(Tok)
   Else Begin
    Nm:=UpStr(Copy(Tok,1,P-1));
    Delete(Tok,1,P);
    Tok:=Tok+':';
    While(Tok<>'')and(N<4)Do Begin
     P:=Pos(':',Tok);
     Val(Copy(Tok,1,P-1),A[N],C);
     Inc(N);
     Delete(Tok,1,P);
    End;
   End;
  EditMsg:='';
  If Nm='SEL' Then Begin
   O:=ObjAt(Round(A[0]));
   If O<>NIL Then O^.Sel:=True;
  End
  Else If Nm='SELALL' Then Begin
   O:=ObjHead;
   While O<>NIL Do Begin O^.Sel:=True; O:=O^.Next; End;
  End
  Else If Nm='DESEL' Then DeselectAll
  Else If Nm='MOVE' Then Begin
   O:=ObjHead;
   While O<>NIL Do Begin
    If O^.Sel Then ObjMove(O,Round(A[0]),Round(A[1]));
    O:=O^.Next;
   End;
  End
  Else If Nm='DUP' Then Begin
   O:=ObjHead;
   Q:=ObjTail;
   While O<>NIL Do Begin
    R:=O^.Next;
    If O^.Sel Then Begin
     T:=CloneObj(O);
     ObjMove(T,Round(A[0]),Round(A[1]));
     AddObj(T);
    End;
    If O=Q Then Break;
    O:=R;
   End;
  End
  Else If Nm='LINE' Then Begin
   T:=NewLine(Round(A[0]),Round(A[1]),Round(A[2]),Round(A[3]));
   T^.Sel:=True;
   AddObj(T);
  End
  Else If Nm='WELD' Then BoolSel(0)
  Else If Nm='INTER' Then BoolSel(1)
  Else If Nm='FMB' Then BoolSel(2)
  Else If Nm='BMF' Then BoolSel(3)
  Else If Nm='KNIFE' Then KnifeSel
  Else If Nm='COMBINE' Then CombineSel
  Else If Nm='BREAK' Then BreakApartSel
  Else If Nm='ROT' Then RotateSel(A[0])
  Else If Nm='SKEW' Then SkewSel(A[0],A[1])
  Else If Nm='SCALE' Then AffineSel(A[0],0,0,A[1])
  Else If Nm='WARP' Then WarpSel(Round(A[0]),Round(A[1]))
  Else If Nm='BLEND' Then BlendSel(Round(A[0]))
  Else If Nm='CONTOUR' Then ContourSel(Round(A[0]),Round(A[1]))
  Else If Nm='DIMH' Then DimensionSel(False)
  Else If Nm='DIMV' Then DimensionSel(True)
  Else If Nm='CONNECT' Then ConnectSel
  Else If Nm='SAMEFILL' Then SelectSame(0)
  Else If Nm='TOCURVE' Then ConvertToCurves
  Else If Nm='NODE' Then Begin
   NodeObj:=Round(A[0]);
   NodeIdx:=Round(A[1]);
   NodeOp(Round(A[2]));
  End
  Else If Nm='CLOSE' Then NodeOp(7)
  Else If Nm='PADD' Then Begin
   Inc(PageCnt);
   CurPage:=PageCnt;
  End
  Else If Nm='PNEXT' Then Begin
   If CurPage<PageCnt Then Inc(CurPage);
  End
  Else If Nm='LAYER' Then ActLayer:=Clamp(Round(A[0]),1,LAYER_N)
  Else If Nm='HIDE' Then LayerVis[Clamp(Round(A[0]),1,LAYER_N)]:=False
  Else If Nm='LOCK' Then LayerLock[Clamp(Round(A[0]),1,LAYER_N)]:=True
  Else If Nm='GUIDE' Then Begin
   If GuideN<GUIDE_MAX Then Begin
    GuideHor[GuideN]:=A[0]<>0;
    GuidePos[GuideN]:=Round(A[1]);
    Inc(GuideN);
   End;
  End
  Else If Nm='CON' Then ApplyFillKind(FK_CONIC,0,15)
  Else If Nm='SQ' Then ApplyFillKind(FK_SQUARE,0,15)
  Else If Nm='CMYK' Then ExpMode:=1
  Else If Nm='SEP' Then ExpMode:=6
  Else WriteLn('Operation inconnue : ',Nm);
  If EditMsg<>'' Then WriteLn(Nm,' : ',EditMsg);
 End;
End;

Var LogF:Text; BI:Integer;

BEGIN
 InitPaletteTable;
 InitTrig;
 ResetDefaults;
 Zoom:=100;
 ShowGrid:=False;
 ShowRulers:=True;
 SnapGrid:=False;
 WireMode:=False;
 ClipSnap:=NIL;
 UndoCnt:=0;
 RedoCnt:=0;
 ObjCount:=0;
 NewDocument;
 If(ParamStr(1)='/?')or(ParamStr(1)='-h')or(ParamStr(1)='--help')Then ShowUsage
  Else
 If UpStr(ParamStr(1))='/SAMPLES' Then MakeSamples
  Else
 If(UpStr(ParamStr(1))='/CONVERT')and(ParamCount>=3)Then Begin
  DbgTrace:=UpStr(ParamStr(ParamCount))='/TRACE';
  If DbgTrace Then Begin Assign(DbgF,ParamStr(3)+'.trace'); Rewrite(DbgF); End;
  If Not LoadAny(ParamStr(2))Then Begin
   WriteLn('Erreur de lecture : ',ParamStr(2));
   Halt(1);
  End;
  DocName:=ParamStr(3);
  For BI:=4 To ParamCount Do
   If Copy(UpStr(ParamStr(BI)),1,4)='/DO:' Then BatchOps(Copy(ParamStr(BI),5,255));
  If DbgTrace Then Close(DbgF);
  If Not SaveAny(ParamStr(3))Then Begin
   WriteLn('Erreur d''ecriture : ',ParamStr(3));
   Halt(1);
  End;
  WriteLn(ParamStr(2),' -> ',ParamStr(3),' (',ObjCount,' objets)');
  If(ParamCount>=4)and((UpStr(ParamStr(4))='/LOG')or(UpStr(ParamStr(ParamCount))='/LOG'))Then Begin
   Assign(LogF,ParamStr(3)+'.log');
   Rewrite(LogF);
   WriteLn(LogF,ObjCount,' objets ; ',C9Info);
   Close(LogF);
  End;
 End
  Else RunInteractive;
 ClearDoc;
END.
