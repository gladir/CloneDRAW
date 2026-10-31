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
   - Lecture CorelDRAW : le texte est reconstruit de facon approximative
     (police 8x8, taille estimee), les bitmaps, les remplissages a motifs
     ou texture et certaines lentilles/transparences ne sont pas relus.
     Necessite Free Pascal.
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
 K_LINE=1; K_RECT=2; K_ELLIPSE=3; K_POLY=4; K_POLYLINE=5; K_BEZIER=6; K_TEXT=7;
 { Types de remplissage }
 FK_NONE=0; FK_SOLID=1; FK_GRADV=2; FK_GRADH=3; FK_PATTERN=4;
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
 MENU_COUNT=9;

 CDR_VERSION=400;

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
 If PalUsed<255 Then Begin
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
  If O^.Pts^[I].X<X1 Then X1:=O^.Pts^[I].X;
  If O^.Pts^[I].X>X2 Then X2:=O^.Pts^[I].X;
  If O^.Pts^[I].Y<Y1 Then Y1:=O^.Pts^[I].Y;
  If O^.Pts^[I].Y>Y2 Then Y2:=O^.Pts^[I].Y;
 End;
End;

Procedure ObjMove(O:PObj;DX,DY:LongInt);
Var I:Integer;
Begin
 For I:=0 To O^.N-1 Do Begin
  Inc(O^.Pts^[I].X,DX);
  Inc(O^.Pts^[I].Y,DY);
 End;
End;

{ Mise a l'echelle par rapport au point (AX,AY) }
Procedure ObjScale(O:PObj;AX,AY,NX,DX,NY,DY:LongInt);
Var I:Integer;
Begin
 If(DX=0)or(DY=0)Then Exit;
 For I:=0 To O^.N-1 Do Begin
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
    For K:=0 To O^.N-1 Do Begin
     OX:=O^.Pts^[K].X;
     OY:=O^.Pts^[K].Y;
     Case Mode Of
      0:Begin O^.Pts^[K].X:=CX-(OY-CY); O^.Pts^[K].Y:=CY+(OX-CX); End;
      1:O^.Pts^[K].X:=2*CX-OX;
     Else O^.Pts^[K].Y:=2*CY-OY;
     End;
    End;
    If(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)Then ObjNormalize2(O);
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

Procedure NewDocument;
Begin
 ClearDoc;
 ClearList(UndoList,UndoCnt);
 ClearList(RedoList,RedoCnt);
 PageW:=2100;
 PageH:=2970;
 GridSize:=50;
 DocName:='';
 Modified:=False;
 GroupSeq:=0;
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
 If(Id<>'RIFF')or(Copy(Form,1,3)<>'CDR')or IOBad Then Begin
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
   If Id='obj ' Then Begin
    Kind:=RdB;
    Fl:=RdB;
    FillChar(Tmp,SizeOf(Tmp),0);
    Tmp.Kind:=Kind;
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
    If(Kind>=1)and(Kind<=7)and(N>=1)and(N<=7999)and(N*8<=Size)And Not IOBad Then Begin
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
    If O^.FillKind=FK_SOLID Then Begin
     If O^.FillCol>=0 Then Fill:='fill="'+ColorHex(O^.FillCol)+'"';
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
    K_RECT:Begin
     ObjBBox(O,X1,Y1,X2,Y2);
     WriteLn(T,' <rect x="',X1+DX,'" y="',Y1+DX,'" width="',X2-X1,'" height="',Y2-Y1,'" ',
             Fill,' ',Stroke,'/>');
    End;
    K_ELLIPSE:Begin
     ObjBBox(O,X1,Y1,X2,Y2);
     WriteLn(T,' <ellipse cx="',(X1+X2) Div 2+DX,'" cy="',(Y1+Y2) Div 2+DX,'" rx="',(X2-X1) Div 2,
             '" ry="',(Y2-Y1) Div 2,'" ',Fill,' ',Stroke,'/>');
    End;
    K_POLY:WriteLn(T,' <polygon points="',PointsStr,'" ',Fill,' ',Stroke,'/>');
    K_POLYLINE:WriteLn(T,' <polyline points="',PointsStr,'" ',Fill,' ',Stroke,'/>');
    K_BEZIER:Begin
     S:='M'+IStr(O^.Pts^[0].X+DX)+' '+IStr(O^.Pts^[0].Y+DX);
     K:=1;
     While K+2<O^.N Do Begin
      S:=S+' C'+IStr(O^.Pts^[K].X+DX)+' '+IStr(O^.Pts^[K].Y+DX)+' '+
         IStr(O^.Pts^[K+1].X+DX)+' '+IStr(O^.Pts^[K+1].Y+DX)+' '+
         IStr(O^.Pts^[K+2].X+DX)+' '+IStr(O^.Pts^[K+2].Y+DX);
      Inc(K,3);
     End;
     If O^.Closed Then S:=S+' Z';
     WriteLn(T,' <path d="',S,'" ',Fill,' ',Stroke,'/>');
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

Function LoadAny(Const Name:String):Boolean;
Var E:String;
Begin
 C9Info:='';
 FromCorel:=False;
 E:=ExtOf(Name);
 If E='.WPG' Then LoadAny:=LoadWPG(Name,False)
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
   K_RECT:Begin
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
     Node(O^.Pts^[K].X,O^.Pts^[K].Y,196);
     Node(O^.Pts^[K+1].X,O^.Pts^[K+1].Y,196);
     If O^.Closed and(K+2=O^.N-1)Then Node(O^.Pts^[K+2].X,O^.Pts^[K+2].Y,136)
                                  Else Node(O^.Pts^[K+2].X,O^.Pts^[K+2].Y,132);
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
    ((O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)or(O^.Kind=K_POLY)or
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

Function SaveAny(Const Name:String):Boolean;
Var E:String;
Begin
 E:=ExtOf(Name);
 If E='.SVG' Then SaveAny:=SaveSVG(Name)
  Else If E='.CD9' Then SaveAny:=SaveCDR9(Name)
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
 PendC:Array[0..1] of TPt;
 PendCnt:Integer;
 tFillKind:Byte;
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

Procedure SubFlush;
Var O:PObj;
    A,I,K:Integer;
    Fill,Closed:Boolean;
Begin
 If SubN<2 Then Begin
  SubN:=0;
  Exit;
 End;
 Fill:=tFillKind<>FK_NONE;
 Closed:=SubClosed or Fill;
 A:=(SubN-1) Div 3+1;
 If SubAllLines Then Begin
  If A<2 Then Begin SubN:=0; Exit; End;
  If Closed and(A>2)and(SubP[0].X=SubP[(A-1)*3].X)and(SubP[0].Y=SubP[(A-1)*3].Y)Then Dec(A);
  If Closed and(A>=3)Then O:=NewObj(K_POLY,A)
   Else If A=2 Then O:=NewObj(K_LINE,2)
   Else O:=NewObj(K_POLYLINE,A);
  For I:=0 To A-1 Do O^.Pts^[I]:=SubP[I*3];
  O^.Closed:=O^.Kind=K_POLY;
 End
  Else Begin
   O:=NewObj(K_BEZIER,SubN);
   For I:=0 To SubN-1 Do O^.Pts^[I]:=SubP[I];
   O^.Closed:=Closed;
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
 K:=0;
 If Not AddObj(O)Then C9Full:=True;
 SubN:=0;
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
 If Kind=5 Then Begin Inc(SkipBmp); Exit; End;
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
 If FillId>=0 Then Begin
  tFillKind:=FillTab^[FillId].Kind;
  tF1:=FillTab^[FillId].C1;
  tF2:=FillTab^[FillId].C2;
  If tF1<0 Then tFillKind:=FK_NONE;
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
 T:=0;
End;

{ ------------------------- Parcours des chunks --------------------- }

Procedure C9Walk(Pos,EndPos:LongInt;Parent,Grand:String;Pass:Integer);Forward;

Procedure C9Chunk(Tag:String;B,Sz:LongInt;Parent,Grand:String;Pass:Integer);
Var Kind:LongInt;
    I,K,PgOff:Integer;
Begin
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
 If Pass=0 Then Begin
  If(LT='stlt')and(C9Ver>6)Then ReadStyles(Pos+12,Sz-4);
  Descend:=(LT='doc ')or(LT='filt')or(LT='filc')or(LT='otlt');
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
 For Pass:=0 To 1 Do Begin
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
  If SkipBmp>0 Then C9Info:=C9Info+', '+IStr(SkipBmp)+' bitmaps ignorés';
  If SkipFx>0 Then C9Info:=C9Info+', '+IStr(SkipFx)+' effets ignorés';
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
 DM_PAN=6; DM_ZBOX=7; DM_SCROLLH=8; DM_SCROLLV=9;
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

Function SnapW(V:LongInt):LongInt;
Begin
 If Not SnapGrid Then Begin
  SnapW:=V;
  Exit;
 End;
 If V>=0 Then SnapW:=((V+GridSize Div 2) Div GridSize)*GridSize
         Else SnapW:=-(((-V)+GridSize Div 2) Div GridSize)*GridSize;
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

Procedure BuildPoly(O:PObj;OX,OY:LongInt);
Var I,J,T:Integer;
    X1,Y1,X2,Y2,CX,CY,RX,RY:LongInt;
    U,TT,U3,U2,T2,T3,A,B,C,D:LongInt;
    P:Array[0..3] of TPt;
Begin
 PN:=0;
 PClosed:=False;
 Case O^.Kind Of
  K_LINE,K_POLYLINE,K_POLY:Begin
   For I:=0 To O^.N-1 Do
    AddP(W2SX(O^.Pts^[I].X+OX),W2SY(O^.Pts^[I].Y+OY));
   PClosed:=O^.Kind=K_POLY;
  End;
  K_RECT,K_TEXT:Begin
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
Var I,J:Integer;
    Inside:Boolean;
Begin
 Inside:=False;
 J:=PN-1;
 For I:=0 To PN-1 Do Begin
  If((PY[I]>Y)<>(PY[J]>Y))Then
   If X<PX[I]+((Y-PY[I])*(PX[J]-PX[I])) Div (PY[J]-PY[I]) Then Inside:=Not Inside;
  J:=I;
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
Var I,J,Last:Integer;
    D,Best:LongInt;
Begin
 Best:=MaxLongInt;
 If PN=1 Then Begin
  PolyDist:=Round(Sqrt(Sqr(X-PX[0])+Sqr(Y-PY[0])));
  Exit;
 End;
 Last:=PN-2;
 If PClosed Then Last:=PN-1;
 For I:=0 To Last Do Begin
  J:=I+1;
  If J>=PN Then J:=0;
  D:=DistSeg(X,Y,PX[I],PY[I],PX[J],PY[J]);
  If D<Best Then Best:=D;
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

Procedure DitherPixel(X,Y,Mix:Integer);
Begin
 If Bayer[X And 3,Y And 3]<Mix Then Begin
  If GC2<0 Then PutPixel(X,Y,HWMap[15]) Else PutPixel(X,Y,HWMap[GC2]);
 End
  Else PutPixel(X,Y,HWMap[GC1]);
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
Var Y,Y1,Y2,I,J,K,M:Integer;
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
 Y1:=Integer(Max(GMinY,0));
 Y2:=Integer(Min(GMaxY,CanvasH-1));
 For Y:=Y1 To Y2 Do Begin
  M:=0;
  J:=PN-1;
  For I:=0 To PN-1 Do Begin
   Ya:=PY[J]; Yb:=PY[I];
   If((Y>=Ya)and(Y<Yb))or((Y>=Yb)and(Y<Ya))Then
    If M<512 Then Begin
     T:=PX[J]+((Y-Ya)*(PX[I]-PX[J])) Div (Yb-Ya);
     X[M]:=Integer(Clamp(T,-30000,30000));
     Inc(M);
    End;
   J:=I;
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
Var I,J,Last,WP:Integer;
Begin
 If PN<2 Then Exit;
 WP:=Integer(Clamp((W*Zoom+500) Div 1000,1,24));
 SetCol(Col);
 If Style=1 Then SetLineStyle(DottedLn,0,NormWidth)
  Else
 If Style=2 Then SetLineStyle(DashedLn,0,NormWidth)
  Else SetLineStyle(SolidLn,0,NormWidth);
 Last:=PN-2;
 If PClosed Then Last:=PN-1;
 For I:=0 To Last Do Begin
  J:=I+1;
  If J>=PN Then J:=0;
  ThickLine(PX[I],PY[I],PX[J],PY[J],WP);
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

Procedure DrawObject(O:PObj);
Var I:Integer;
    TC:Integer;
Begin
 If WireMode Then Begin
  BuildPoly(O,0,0);
  SetCol(0);
  SetLineStyle(SolidLn,0,NormWidth);
  If O^.Kind=K_TEXT Then DrawTextObj(O,0,0,0);
  If PN>=2 Then Begin
   For I:=0 To PN-2 Do Line(PX[I],PY[I],PX[I+1],PY[I+1]);
   If PClosed Then Line(PX[PN-1],PY[PN-1],PX[0],PY[0]);
  End;
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
  ScanFill(O^.FillKind,O^.Pattern,O^.FillCol,O^.FillCol2);
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
      Line(CL(W2SX(O^.Pts^[K-1].X)),CL(W2SY(O^.Pts^[K-1].Y)),
           CL(W2SX(O^.Pts^[K].X)),CL(W2SY(O^.Pts^[K].Y)));
      Line(CL(W2SX(O^.Pts^[K+2].X)),CL(W2SY(O^.Pts^[K+2].Y)),
           CL(W2SX(O^.Pts^[K+1].X)),CL(W2SY(O^.Pts^[K+1].Y)));
      Inc(K,3);
     End;
    End;
    For K:=0 To O^.N-1 Do Begin
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

Procedure DrawCanvas;
Var I:LongInt;
Begin
 BeginCanvas;
 Box(0,0,CanvasW-1,CanvasH-1,CANVAS_BG);
 DrawPage;
 If ShowGrid Then DrawGridPoints;
 For I:=0 To ObjCount-1 Do DrawObject(ObjAt(I));
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
 CM_FILL_PAT=64; CM_OUT_NONE=65; CM_OUT_COLOR=66; CM_OUT_WIDTH=67;
 CM_OUT_STYLE=68; CM_SHADOW=69; CM_EXTRUDE=70;
 CM_TEXT_EDIT=80; CM_TEXT_BIG=81; CM_TEXT_SMALL=82;
 CM_SIDES=90; CM_RESETDEF=91; CM_STATS=92;
 CM_HELPKEYS=95; CM_ABOUT=96;
 CM_W1=100; CM_W2=101; CM_W3=102; CM_W4=103; CM_W5=104;
 CM_SIDES_UP=110; CM_SIDES_DN=111;

 POPUP_IDX=9;
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
  It:Array[0..23] of TMenuItem;
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
 AddItem(0,'Importer (WPG/CDR)...','',CM_IMPORT);
 AddItem(0,'Exporter en SVG...','',CM_EXPORTSVG);
 AddItem(0,'Exporter CorelDRAW 9...','',CM_EXPORTCDR9);
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

 SetMenuTitle(2,'Affichage');
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

 SetMenuTitle(3,'Disposition');
 AddItem(3,'Page A4','',CM_PAGE_A4);
 AddItem(3,'Page A5','',CM_PAGE_A5);
 AddItem(3,'Page A3','',CM_PAGE_A3);
 AddItem(3,'Page Lettre','',CM_PAGE_LET);
 AddSep(3);
 AddItem(3,'Orientation portrait','',CM_PORTRAIT);
 AddItem(3,'Orientation paysage','',CM_LANDSCAPE);
 AddSep(3);
 AddItem(3,'Pas de la grille...','',CM_GRIDSIZE);

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

 SetMenuTitle(8,'Aide');
 AddItem(8,'Raccourcis clavier...','F1',CM_HELPKEYS);
 AddItem(8,'À propos...','',CM_ABOUT);

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
  CM_FLIPH,CM_FLIPV,CM_TOCURVE,CM_FILL_SOLID,CM_FILL_GV,CM_FILL_GH,CM_FILL_PAT,
  CM_FILL_NONE,CM_OUT_COLOR,CM_OUT_NONE,CM_OUT_WIDTH,CM_OUT_STYLE,CM_SHADOW,
  CM_EXTRUDE,CM_ZSEL,CM_TEXT_EDIT,CM_TEXT_BIG,CM_TEXT_SMALL:IsEnabled:=N>0;
  CM_GROUP,CM_AL_L,CM_AL_C,CM_AL_R,CM_AL_T,CM_AL_M,CM_AL_B:IsEnabled:=N>1;
  CM_DISTH,CM_DISTV:IsEnabled:=N>2;
  CM_UNGROUP:IsEnabled:=N>0;
  CM_PASTE:IsEnabled:=(ClipSnap<>NIL)and(ClipSnap^.N>0);
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
    Exts:Array[0..3] of String[6];
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
   Else If(Mode=3)or(Mode=4)Then DrawBtn(X+W-118,Y+40,108,22,'Exporter',False)
   Else If Mode=2 Then DrawBtn(X+W-118,Y+40,108,22,'Importer',False)
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
  If Mode=1 Then Begin
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
 Else Begin Exts[0]:='.SVG'; NFlt:=1; End;
 End;
 Flt:=0;
 Fld:='';
 Msg:='';
 If(Mode=1)and(DocName<>'')Then Fld:=BaseOf(DocName);
 If(Mode=3)and(DocName<>'')Then Fld:=BaseOf(ForceExt(DocName,'.SVG'));
 If(Mode=4)and(DocName<>'')Then Fld:=BaseOf(DocName);
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
Var I,F:LongInt;
Begin
 If ObjCount=0 Then Exit;
 F:=-1;
 For I:=0 To ObjCount-1 Do If ObjAt(I)^.Sel Then F:=I;
 DeselectAll;
 SelectIndex((F+1) Mod ObjCount);
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
    Cnt:Array[1..7] of Integer;
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
 TLines[TN]:='Courbes : '+IStr(Cnt[K_BEZIER])+'   Textes : '+IStr(Cnt[K_TEXT]); Inc(TN);
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
 If Cd9 Then Good:=SaveCDR9(N) Else Good:=SaveAny(N);
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
Begin
 N:='';
 If Not FileDialog(2,N)Then Exit;
 PushUndo;
 If LoadWPG(N,True)Then StatusMsg:='Importé : '+BaseOf(N)
  Else MsgBox('Erreur','Fichier WPG illisible :',BaseOf(N));
 Modified:=True;
End;

Procedure DoExportSVG;
Var N:String;
Begin
 N:='';
 If Not FileDialog(3,N)Then Exit;
 If ExtOf(N)=''Then N:=N+'.SVG';
 If SaveSVG(N)Then StatusMsg:='Exporté : '+BaseOf(N)
  Else MsgBox('Erreur','Impossible d''écrire le fichier SVG :',BaseOf(N));
End;

Procedure DoExportCDR9;
Var N:String;
Begin
 N:='';
 If Not FileDialog(4,N)Then Exit;
 If ExtOf(N)=''Then N:=N+'.CDR';
 If SaveCDR9(N)Then Begin
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
 For I:=0 To ObjCount-1 Do DrawObject(ObjAt(I));
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
   For I:=0 To ObjCount-1 Do ObjAt(I)^.Sel:=True;
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
  CM_FILL_GV,CM_FILL_GH:Begin
   C:=ColorBox('Dégradé : couleur de départ',False);
   If C>=0 Then Begin
    C2:=ColorBox('Dégradé : couleur de fin',False);
    If C2>=0 Then Begin
     If Cmd=CM_FILL_GV Then ApplyFillKind(FK_GRADV,C,C2)
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
 NodeObj,NodeIdx:Integer;
 LastClickT:LongInt;
 LastClickX,LastClickY:Integer;
 ScrollGrab:Integer;
 CursorTxt,LastCursorTxt:String;
 NodeUndone:Boolean;

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
 MXw:=SnapW(S2WX(CX));
 MYw:=SnapW(S2WY(CY));
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
 NX:=SnapW(OBX1+((LongInt(CX)-DX0)*1000) Div Zoom);
 NY:=SnapW(OBY1+((LongInt(CY)-DY0)*1000) Div Zoom);
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
 X1:=SnapW(S2WX(DX0)); Y1:=SnapW(S2WY(DY0));
 X2:=SnapW(S2WX(CX)); Y2:=SnapW(S2WY(CY));
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
 PushUndo;
 O:=NIL;
 Case CurTool Of
  T_LINE:Begin
   O:=NewObj(K_LINE,2);
   O^.Pts^[0].X:=SnapW(S2WX(DX0)); O^.Pts^[0].Y:=SnapW(S2WY(DY0));
   O^.Pts^[1].X:=SnapW(S2WX(CX)); O^.Pts^[1].Y:=SnapW(S2WY(CY));
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
 O^.Pts^[0].X:=SnapW(S2WX(CX));
 O^.Pts^[0].Y:=SnapW(S2WY(CY));
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
    If(Abs(SX-W2SX(O^.Pts^[K].X))<=5)and(Abs(SY-W2SY(O^.Pts^[K].Y))<=5)Then Begin
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
  If NI>0 Then Begin Inc(O^.Pts^[NI-1].X,DX); Inc(O^.Pts^[NI-1].Y,DY); End;
  If NI<O^.N-1 Then Begin Inc(O^.Pts^[NI+1].X,DX); Inc(O^.Pts^[NI+1].Y,DY); End;
  If O^.Closed and(NI=0)Then Begin
   O^.Pts^[O^.N-1].X:=WX; O^.Pts^[O^.N-1].Y:=WY;
   Inc(O^.Pts^[O^.N-2].X,DX); Inc(O^.Pts^[O^.N-2].Y,DY);
  End;
  If O^.Closed and(NI=O^.N-1)Then Begin
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
 If(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)Then Exit;
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
  If((O^.Kind=K_POLY)and(O^.N<=3))or(O^.N<=2)or(O^.Kind=K_RECT)or(O^.Kind=K_ELLIPSE)Then Exit;
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
     If(NX1>=A)and(NX2<=C)and(NY1>=B)and(NY2<=D)Then SelectIndex(I);
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
    MoveNode(NodeObj,NodeIdx,SnapW(S2WX(CX)),SnapW(S2WY(CY)));
    DCX:=CX; DCY:=CY;
    NeedRedraw:=True;
   End;
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
     StartDrag(DM_MARQUEE,CX,CY);
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
    BuildPts[BuildN].X:=SnapW(S2WX(CX));
    BuildPts[BuildN].Y:=SnapW(S2WY(CY));
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
  If Not LoadAny(ParamStr(2))Then Begin
   WriteLn('Erreur de lecture : ',ParamStr(2));
   Halt(1);
  End;
  DocName:=ParamStr(3);
  If Not SaveAny(ParamStr(3))Then Begin
   WriteLn('Erreur d''ecriture : ',ParamStr(3));
   Halt(1);
  End;
  WriteLn(ParamStr(2),' -> ',ParamStr(3),' (',ObjCount,' objets)');
 End
  Else RunInteractive;
 ClearDoc;
END.
