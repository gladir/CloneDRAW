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
   - Fichiers : CDR (conteneur RIFF "CDR4" - lecture/ecriture),
     WPG (clipart vectoriel WordPerfect/Corel - lecture),
     SVG (exportation)

  Note : le format CDR ecrit par ce programme est un conteneur RIFF de type
  CDR4 dont les objets sont propres a ce clone ; il n'est pas lisible par
  le CorelDraw original.

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

 MAXOBJ=400;
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
 End;
 PSnap=^TSnap;
 TSnap=Record
  N:Integer;
  PW,PH:LongInt;
  O:Array[0..MAXOBJ-1] of PObj;
 End;

Var
 { Document }
 Objs:Array[0..MAXOBJ-1] of PObj;
 ObjCount:Integer;
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

 PalR,PalG,PalB:Array[0..PAL_COUNT-1] of Byte;

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
End;

Function NearestColor(R,G,B:Integer):Integer;
Var I,Best:Integer;
    D,BestD:LongInt;
Begin
 Best:=0;
 BestD:=MaxLongInt;
 For I:=0 To PAL_COUNT-1 Do Begin
  D:=Sqr(LongInt(R)-PalR[I])+Sqr(LongInt(G)-PalG[I])+Sqr(LongInt(B)-PalB[I]);
  If D<BestD Then Begin
   BestD:=D;
   Best:=I;
  End;
 End;
 NearestColor:=Best;
End;

Function HexByte(B:Integer):String;
Const Hx:String='0123456789ABCDEF';
Begin
 HexByte:=Hx[(B Shr 4)+1]+Hx[(B And 15)+1];
End;

Function ColorHex(C:Integer):String;
Begin
 If(C<0)or(C>=PAL_COUNT)Then ColorHex:='#000000'
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

Procedure ClearDoc;
Var I:Integer;
Begin
 For I:=0 To ObjCount-1 Do Begin
  FreeObj(Objs[I]);
  Objs[I]:=NIL;
 End;
 ObjCount:=0;
End;

Function AddObj(O:PObj):Boolean;
Begin
 If ObjCount>=MAXOBJ Then Begin
  FreeObj(O);
  AddObj:=False;
  Exit;
 End;
 Objs[ObjCount]:=O;
 Inc(ObjCount);
 Modified:=True;
 AddObj:=True;
End;

Procedure DeleteObjAt(I:Integer);
Var K:Integer;
Begin
 FreeObj(Objs[I]);
 For K:=I To ObjCount-2 Do Objs[K]:=Objs[K+1];
 Objs[ObjCount-1]:=NIL;
 Dec(ObjCount);
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
    I:Integer;
Begin
 New(S);
 S^.N:=0;
 S^.PW:=PageW;
 S^.PH:=PageH;
 For I:=0 To ObjCount-1 Do
  If(Not OnlySel)or Objs[I]^.Sel Then Begin
   S^.O[S^.N]:=CloneObj(Objs[I]);
   Inc(S^.N);
  End;
 TakeSnap:=S;
End;

Procedure FreeSnap(Var S:PSnap);
Var I:Integer;
Begin
 If S=NIL Then Exit;
 For I:=0 To S^.N-1 Do FreeObj(S^.O[I]);
 Dispose(S);
 S:=NIL;
End;

{ Remplace le document par le contenu de l'instantane (qui est consomme) }
Procedure RestoreSnap(Var S:PSnap);
Var I:Integer;
Begin
 ClearDoc;
 For I:=0 To S^.N-1 Do Objs[I]:=S^.O[I];
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

Function SelCount:Integer;
Var I,C:Integer;
Begin
 C:=0;
 For I:=0 To ObjCount-1 Do If Objs[I]^.Sel Then Inc(C);
 SelCount:=C;
End;

Procedure DeselectAll;
Var I:Integer;
Begin
 For I:=0 To ObjCount-1 Do Objs[I]^.Sel:=False;
End;

Procedure SelectIndex(I:Integer);
Var K:Integer;
    G:Integer;
Begin
 Objs[I]^.Sel:=True;
 G:=Objs[I]^.Group;
 If G<>0 Then
  For K:=0 To ObjCount-1 Do If Objs[K]^.Group=G Then Objs[K]^.Sel:=True;
End;

Function SelBBox(Var X1,Y1,X2,Y2:LongInt):Boolean;
Var I:Integer;
    A,B,C,D:LongInt;
    First:Boolean;
Begin
 First:=True;
 X1:=0; Y1:=0; X2:=0; Y2:=0;
 For I:=0 To ObjCount-1 Do
  If Objs[I]^.Sel Then Begin
   ObjBBox(Objs[I],A,B,C,D);
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
 SelBBox:=Not First;
End;

Procedure DeleteSelection;
Var I:Integer;
Begin
 I:=ObjCount-1;
 While I>=0 Do Begin
  If Objs[I]^.Sel Then DeleteObjAt(I);
  Dec(I);
 End;
End;

Procedure ToFront;
Var Tmp:Array[0..MAXOBJ-1] of PObj;
    I,N:Integer;
Begin
 N:=0;
 For I:=0 To ObjCount-1 Do If Not Objs[I]^.Sel Then Begin Tmp[N]:=Objs[I]; Inc(N); End;
 For I:=0 To ObjCount-1 Do If Objs[I]^.Sel Then Begin Tmp[N]:=Objs[I]; Inc(N); End;
 For I:=0 To ObjCount-1 Do Objs[I]:=Tmp[I];
End;

Procedure ToBack;
Var Tmp:Array[0..MAXOBJ-1] of PObj;
    I,N:Integer;
Begin
 N:=0;
 For I:=0 To ObjCount-1 Do If Objs[I]^.Sel Then Begin Tmp[N]:=Objs[I]; Inc(N); End;
 For I:=0 To ObjCount-1 Do If Not Objs[I]^.Sel Then Begin Tmp[N]:=Objs[I]; Inc(N); End;
 For I:=0 To ObjCount-1 Do Objs[I]:=Tmp[I];
End;

Procedure OneForward;
Var I:Integer;
    T:PObj;
Begin
 For I:=ObjCount-2 DownTo 0 Do
  If Objs[I]^.Sel and Not Objs[I+1]^.Sel Then Begin
   T:=Objs[I]; Objs[I]:=Objs[I+1]; Objs[I+1]:=T;
  End;
End;

Procedure OneBackward;
Var I:Integer;
    T:PObj;
Begin
 For I:=1 To ObjCount-1 Do
  If Objs[I]^.Sel and Not Objs[I-1]^.Sel Then Begin
   T:=Objs[I]; Objs[I]:=Objs[I-1]; Objs[I-1]:=T;
  End;
End;

Procedure GroupSel;
Var I:Integer;
Begin
 If SelCount<2 Then Exit;
 Inc(GroupSeq);
 For I:=0 To ObjCount-1 Do If Objs[I]^.Sel Then Objs[I]^.Group:=GroupSeq;
End;

Procedure UngroupSel;
Var I:Integer;
Begin
 For I:=0 To ObjCount-1 Do If Objs[I]^.Sel Then Objs[I]^.Group:=0;
End;

{ Alignement : Mode 0..5 = gauche, centre, droite, haut, milieu, bas }
Procedure AlignSel(Mode:Integer);
Var I:Integer;
    SX1,SY1,SX2,SY2,A,B,C,D,DX,DY:LongInt;
Begin
 If SelCount<2 Then Exit;
 SelBBox(SX1,SY1,SX2,SY2);
 For I:=0 To ObjCount-1 Do
  If Objs[I]^.Sel Then Begin
   ObjBBox(Objs[I],A,B,C,D);
   DX:=0; DY:=0;
   Case Mode Of
    0:DX:=SX1-A;
    1:DX:=((SX1+SX2) Div 2)-((A+C) Div 2);
    2:DX:=SX2-C;
    3:DY:=SY1-B;
    4:DY:=((SY1+SY2) Div 2)-((B+D) Div 2);
    5:DY:=SY2-D;
   End;
   ObjMove(Objs[I],DX,DY);
  End;
End;

{ Distribution : Horiz=True repartit les centres a intervalles reguliers }
Procedure DistributeSel(Horiz:Boolean);
Var Idx:Array[0..MAXOBJ-1] of Integer;
    Ctr:Array[0..MAXOBJ-1] of LongInt;
    N,I,J,T:Integer;
    A,B,C,D,First,Last,Target:LongInt;
Begin
 N:=0;
 For I:=0 To ObjCount-1 Do
  If Objs[I]^.Sel Then Begin
   ObjBBox(Objs[I],A,B,C,D);
   Idx[N]:=I;
   If Horiz Then Ctr[N]:=(A+C) Div 2 Else Ctr[N]:=(B+D) Div 2;
   Inc(N);
  End;
 If N<3 Then Exit;
 For I:=0 To N-2 Do
  For J:=I+1 To N-1 Do
   If Ctr[J]<Ctr[I] Then Begin
    T:=Idx[I]; Idx[I]:=Idx[J]; Idx[J]:=T;
    First:=Ctr[I]; Ctr[I]:=Ctr[J]; Ctr[J]:=First;
   End;
 First:=Ctr[0];
 Last:=Ctr[N-1];
 For I:=1 To N-2 Do Begin
  Target:=First+((Last-First)*I) Div (N-1);
  If Horiz Then ObjMove(Objs[Idx[I]],Target-Ctr[I],0)
           Else ObjMove(Objs[Idx[I]],0,Target-Ctr[I]);
 End;
End;

{ Rotation de 90 degres (sens horaire a l'ecran) ou miroirs }
Procedure TransformSel(Mode:Integer);
Var I,K:Integer;
    X1,Y1,X2,Y2,CX,CY,NX,NY,OX,OY:LongInt;
    O:PObj;
Begin
 If Not SelBBox(X1,Y1,X2,Y2)Then Exit;
 CX:=(X1+X2) Div 2;
 CY:=(Y1+Y2) Div 2;
 For I:=0 To ObjCount-1 Do
  If Objs[I]^.Sel Then Begin
   O:=Objs[I];
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
Var I:Integer;
    O,P:PObj;
    X1,Y1,X2,Y2,CX,CY,RX,RY,KX,KY:LongInt;
    Q:Array[0..12] of TPt;
Begin
 For I:=0 To ObjCount-1 Do Begin
  O:=Objs[I];
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
Var I,K:Integer;
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
 BeginChunk('LIST','objs');
 For I:=0 To ObjCount-1 Do Begin
  O:=Objs[I];
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

Function LoadCDR(Const Name:String):Boolean;
Var Id,Form:String;
    Size,Pos,Data,Total:LongInt;
    O:PObj;
    I,K,N:Integer;
    Kind,Fl:Byte;
    Old:Byte;
    Tmp:TObj;
    L:Byte;
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
 If(Id<>'RIFF')or(Copy(Form,1,3)<>'CDR')or IOBad Then Begin
  Close(FF);
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
    I,K:Integer;
    O:PObj;
    S,Fill,Stroke:String;
    X1,Y1,X2,Y2:LongInt;
    Pass:Integer;
    DX:LongInt;
    GradN:Integer;
 Function PointsStr:String;
 Var R:String;
     J:Integer;
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
  O:=Objs[I];
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
Type
 TRaw=Record
  Kind:Byte;
  Closed:Boolean;
  Fill,Line:Integer;
  FillT,LineT:Byte;
  W:LongInt;
  First,Cnt:LongInt;
 End;
Var
 Raw:Array[0..MAXOBJ-1] of TRaw;
 RawN:Integer;
 Pt:Array[0..11999] of TPt;
 PtN:LongInt;
 Map:Array[0..255] of Integer;
 Old:Byte;
 Total,Pos,Data,Len,V:LongInt;
 T,B:Byte;
 W:Word;
 I,K,Cnt,Step:Integer;
 CurFillT,CurLineT:Byte;
 CurFill,CurLine:Integer;
 CurW:LongInt;
 X1,Y1,X2,Y2,BW,BH,TW,TH,OX,OY:LongInt;
 Sc:Real;
 O:PObj;
 First:Boolean;
 SX,SY:Integer;

 Procedure AddRaw(Kind:Byte;Closed:Boolean);
 Begin
  If RawN>=MAXOBJ Then Exit;
  Raw[RawN].Kind:=Kind;
  Raw[RawN].Closed:=Closed;
  Raw[RawN].Fill:=CurFill;
  Raw[RawN].Line:=CurLine;
  Raw[RawN].FillT:=CurFillT;
  Raw[RawN].LineT:=CurLineT;
  Raw[RawN].W:=CurW;
  Raw[RawN].First:=PtN;
  Raw[RawN].Cnt:=0;
 End;

 Procedure AddPt(X,Y:LongInt);
 Begin
  If(PtN>=12000)or(RawN>=MAXOBJ)Then Exit;
  Pt[PtN].X:=X;
  Pt[PtN].Y:=Y;
  Inc(PtN);
  Inc(Raw[RawN].Cnt);
 End;

 Function SW:LongInt;
 Begin
  SW:=SmallInt(RdW);
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
 Pos:=RdL;
 If(Pos<16)or(Pos>=Total)Then Pos:=16;
 For I:=0 To 255 Do Map[I]:=I And 15;
 RawN:=0;
 PtN:=0;
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
    AddRaw(K_LINE,False);
    AddPt(SW,SW);
    AddPt(SW,SW);
    Inc(RawN);
   End;
   6,8:Begin
    Cnt:=RdW;
    If Cnt*4>Len Then Cnt:=Len Div 4 - 1;
    If Cnt>=2 Then Begin
     AddRaw(K_POLYLINE,T=8);
     Step:=1;
     While Cnt Div Step>1500 Do Inc(Step);
     For K:=0 To Cnt-1 Do Begin
      SX:=SW;
      SY:=SW;
      If(K Mod Step=0)or(K=Cnt-1)Then AddPt(SX,SY);
     End;
     Inc(RawN);
    End;
   End;
   7:Begin
    AddRaw(K_RECT,True);
    X1:=SW; Y1:=SW; X2:=SW; Y2:=SW;
    AddPt(X1,Y1);
    AddPt(X1+X2,Y1+Y2);
    Inc(RawN);
   End;
   9:Begin
    AddRaw(K_ELLIPSE,True);
    X1:=SW; Y1:=SW; X2:=SW; Y2:=SW;
    AddPt(X1-X2,Y1-Y2);
    AddPt(X1+X2,Y1+Y2);
    Inc(RawN);
   End;
   14:Begin
    X1:=RdW;
    Cnt:=RdW;
    For K:=0 To Cnt-1 Do Begin
     TW:=RdB; TH:=RdB; BW:=RdB;
     If(X1+K>=0)and(X1+K<=255)Then Map[X1+K]:=NearestColor(TW,TH,BW);
    End;
   End;
  End;
  Pos:=Data+Len;
 End;
 Close(FF);
 If RawN=0 Then Exit;
 { Etendue du dessin }
 First:=True;
 BW:=0; BH:=0; OX:=0; OY:=0;
 X1:=0; Y1:=0; X2:=0; Y2:=0;
 For I:=0 To RawN-1 Do
  For K:=0 To Raw[I].Cnt-1 Do
   With Pt[Raw[I].First+K] Do Begin
    If First Then Begin X1:=X; X2:=X; Y1:=Y; Y2:=Y; First:=False; End
    Else Begin
     If X<X1 Then X1:=X; If X>X2 Then X2:=X;
     If Y<Y1 Then Y1:=Y; If Y>Y2 Then Y2:=Y;
    End;
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
 For I:=0 To RawN-1 Do Begin
  O:=NewObj(Raw[I].Kind,Raw[I].Cnt);
  For K:=0 To Raw[I].Cnt-1 Do Begin
   O^.Pts^[K].X:=OX+Round((Pt[Raw[I].First+K].X-X1)*Sc);
   O^.Pts^[K].Y:=OY+Round((Y2-Pt[Raw[I].First+K].Y)*Sc);
  End;
  If(Raw[I].Kind=K_RECT)or(Raw[I].Kind=K_ELLIPSE)Then ObjNormalize2(O);
  O^.Closed:=Raw[I].Closed;
  If Raw[I].Closed and(Raw[I].Kind=K_POLYLINE)Then O^.Kind:=K_POLY;
  If Raw[I].LineT=0 Then O^.OutCol:=-1 Else O^.OutCol:=Map[Raw[I].Line And 255];
  O^.OutW:=Max(1,Round(Raw[I].W*Sc));
  If(Raw[I].Kind=K_LINE)or(O^.Kind=K_POLYLINE)Then Begin
   O^.FillKind:=FK_NONE;
   O^.FillCol:=-1;
  End
   Else
  If Raw[I].FillT=0 Then Begin
   O^.FillKind:=FK_NONE;
   O^.FillCol:=-1;
  End
   Else
  Begin
   O^.FillKind:=FK_SOLID;
   O^.FillCol:=Map[Raw[I].Fill And 255];
   If Raw[I].FillT>1 Then Begin
    O^.FillKind:=FK_PATTERN;
    O^.Pattern:=(Raw[I].FillT-2) Mod 8+1;
    O^.FillCol2:=-1;
   End;
  End;
  If Not AddObj(O)Then Break;
 End;
 Modified:=False;
 LoadWPG:=True;
End;

{ ------------------------------------------------------------------ }
{ Chargement / enregistrement selon l'extension                      }
{ ------------------------------------------------------------------ }

Function LoadAny(Const Name:String):Boolean;
Var E:String;
Begin
 E:=ExtOf(Name);
 If E='.WPG' Then LoadAny:=LoadWPG(Name,False)
  Else LoadAny:=LoadCDR(Name);
End;

Function SaveAny(Const Name:String):Boolean;
Var E:String;
Begin
 E:=ExtOf(Name);
 If E='.SVG' Then SaveAny:=SaveSVG(Name)
  Else SaveAny:=SaveCDR(Name);
End;

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
 LastObj:=Objs[ObjCount-1];
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

Procedure RunInteractive;
Begin
 WriteLn('interactif: non implemente');
End;

BEGIN
 InitPaletteTable;
 InitTrig;
 ResetDefaults;
 NewDocument;
 If UpStr(ParamStr(1))='/SAMPLES' Then MakeSamples
  Else
 If UpStr(ParamStr(1))='/CONVERT' Then Begin
  If Not LoadAny(ParamStr(2))Then Begin WriteLn('Erreur de lecture'); Halt(1); End;
  DocName:=ParamStr(3);
  If Not SaveAny(ParamStr(3))Then Begin WriteLn('Erreur d''ecriture'); Halt(1); End;
  WriteLn(ParamStr(2),' -> ',ParamStr(3),' (',ObjCount,' objets)');
 End
  Else RunInteractive;
END.
