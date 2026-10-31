{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application LEOCAD

  LeoCAD est un logiciel libre de CAO pour assembler des briques Lego en 3D.
  Ce clone est entierement contenu dans ce fichier (aucun fichier d'inclusion,
  aucune unite externe en dehors de DOS, Crt, Graph / PtcGraph).

  Fonctionnalites :
   - Fichiers LDraw : lecture et ecriture de .LDR et .MPD (multi-fichiers avec
     sous-modeles "0 FILE"), lecture des pieces .DAT (types 1 a 5, BFC)
   - Bibliotheque de pieces : SAMPLES\LEOCAD\LEGO\*.DAT (index PARTS.LST,
     reconstruit automatiquement si absent), primitives dans LEGO\P\
   - Plans de montage : SAMPLES\LEOCAD\PLAN\*.LDR et *.MPD
   - Rendu 3D logiciel : perspective ou orthogonal, faces ombrees, aretes,
     elimination des faces cachees (BFC), translucidite tramee, grille
   - 1 ou 4 vues (3D, dessus, droite, avant), orbite, panoramique, zoom
   - Edition : selection, insertion avec aimantation sur la grille et
     empilement automatique, deplacement, rotation, couleur, copier/coller,
     annuler/retablir, chronologie par etapes ("0 STEP"), sous-modeles
   - Panneaux : Pieces (categories, recherche, apercu), Proprietes (champs
     modifiables), Chronologie, palette de couleurs LDraw
   - Export : image BMP de la vue active, liste des pieces (texte)

  Ligne de commande :
   LEOCAD [/16] [fichier.ldr|fichier.mpd]
   /16 : force le mode VGA 16 couleurs (sinon 256 couleurs avec Free Pascal)

  Notes :
   - Les pieces sont lues dans SAMPLES\LEOCAD\LEGO (une piece LDraw par fichier
     .DAT, sous-pieces dans le dossier P ou S) ; l'index PARTS.LST est recree
     par Fichier > Reindexer la bibliotheque. Le tenon (STUD.DAT) est integre.
   - Un fichier .MPD contient plusieurs modeles ("0 FILE nom") : le premier est
     le modele principal, les autres sont des sous-modeles (onglets).
   - Les couleurs sont les codes LDraw courants (0 a 484, translucides 33 a 47).
   - Le programme complet depasse les 64 Ko de code d'un segment Turbo Pascal 7 :
     la compilation visee est Free Pascal (mode TP), le code reste compatible
     avec la syntaxe de Turbo Pascal.
}

Program LEOCAD;

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$R-}
{$ELSE}
 {$M 40960,0,655360}
{$ENDIF}

Uses {$IFDEF FPC}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

Var
 Force16:Boolean;
 I0:Integer;
 ArgFile:String;

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  { 256 couleurs si possible : les teintes des briques sont des rampes de
    nuances ; sinon retour au VGA 16 couleurs (ou option /16). }
  Driver:=D8bit;
  Mode:=m640x480;
  ErrCode:=-1;
  If Not Force16 Then Begin
   InitGraph(Driver,Mode,'');
   ErrCode:=GraphResult;
  End;
  If ErrCode<>grOk Then Begin
   Driver:=VGA;
   Mode:=VGAHi;
   InitGraph(Driver,Mode,'');
   ErrCode:=GraphResult;
  End;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
  InitGraph(Driver,Mode,'');
  ErrCode:=GraphResult;
 {$ENDIF}
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

{$IFNDEF FPC}
 Function MouseDriverFound: Boolean;
 Var
  Regs: Registers;
 Begin
  Regs.AX := 0;
  Intr($33, Regs);
  MouseDriverFound := Regs.AX = $FFFF;
 End;

 Procedure ShowMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0001;
  Intr($33, Regs);
 End;

 Procedure HideMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0003;
  Intr($33, Regs);
  Button := Regs.BX;
  X := Regs.CX;
  Y := Regs.DX;
 End;
{$ELSE}
 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := PtcMouse.InitMouse;
 End;

 Procedure ShowMouse;
 Begin
  PtcMouse.ShowMouse;
 End;

 Procedure HideMouse;
 Begin
  PtcMouse.HideMouse;
 End;
{$ENDIF}

{ ====================================================================== }
{ Constantes                                                             }
{ ====================================================================== }

Const
 { Chaines : \e=e aigu \g=e grave \a=a grave \c=c cedille \h=e circonflexe
   \o=o circonflexe \u=u grave \i=i circonflexe \E=E aigu (page 437) }
 PROG_NAME='LEOCAD';
 MAXMOD=16;               { modeles (fichier principal + sous-modeles) }
 MAXCAT=4900;             { pieces du catalogue }
 MAXCATG=48;              { categories }
 MAXSEL=64;
 MAXVIEW=4;
 POLYSH=10;               { 1024 polygones par bloc }
 PBSIZE=1024;
 MAXBLK=16;
 MAXPOLY=16384;
 UNDO_MAX=12;
 CACHE_MAX=140;           { pieces gardees en memoire }
 NSHADE=6;
 MAXCOL=40;
 EPS=0.000001;

 { Types de primitives LDraw }
 PK_REF=1; PK_LINE=2; PK_TRI=3; PK_QUAD=4; PK_STUD=5;

 { Outils }
 TL_SELECT=0; TL_INSERT=1; TL_ORBIT=2; TL_PAN=3; TL_ZOOM=4;

 { Panneaux }
 PN_PARTS=0; PN_PROPS=1; PN_TIME=2;

 { Menus }
 MENU_COUNT=7;
 M_FILE=0; M_EDIT=1; M_VIEW=2; M_PIECE=3; M_STEP=4; M_SUB=5; M_HELP=6;

 { Interface }
 UI_BG=7; UI_HI=15; UI_SH=8; UI_DK=0; UI_SEL=1;
 MENU_H=18; TB_H=28; TAB_H=18; ST_H=18; DOCK_W=196;

Type
 TVec=Record X,Y,Z:Real; End;
 TMat=Record R:Array[0..2,0..2] Of Real; T:TVec; End;

 PPart=^TPart;
 PPrim=^TPrim;
 TPrim=Record
  Next:PPrim;
  Kind,Cull:Byte;       { Cull : 0 aucun, 1 CCW certifie, 2 CW certifie }
  Col:Integer;
  Inv:Boolean;          { INVERTNEXT }
  Case Byte Of
   0:(P:Array[0..3] Of TVec);
   1:(M:TMat; Ref:PPart);
 End;
 TPart=Record
  Name:String[40];
  Prims:PPrim;
  Tail:PPrim;
  Next:PPart;
  Found:Boolean;
  BBox:Boolean;
  AMin,AMax:TVec;      { boite englobante, tenons compris }
  BMin,BMax:TVec;      { boite du corps, sans les tenons }
 End;

 PPiece=^TPiece;
 TPiece=Record
  Name:String[40];
  Col:Integer;
  M:TMat;
  Step:Integer;
  Sel,Hidden:Boolean;
  Part:PPart;
  Epoch:LongInt;
  Next,Prev:PPiece;
 End;

 TModel=Record
  Used:Boolean;
  Name:String[40];
  First,Last:PPiece;
  Count:Integer;
  CurStep:Integer;
 End;

 PSnap=^TSnap;
 TSnap=Record
  NMod,Cur,Col:Integer;
  Name:Array[0..MAXMOD-1] Of String[40];
  List:Array[0..MAXMOD-1] Of PPiece;
  Step:Array[0..MAXMOD-1] Of Integer;
 End;

 TCat=Record
  FileN:String[12];
  Desc:String[44];
  Cat:Byte;
 End;
 PCat=^TCat;

 TPoly=Record
  Z:LongInt;
  Col:Word;
  N,Fl:Byte;
  Owner:Integer;
  X,Y:Array[0..3] Of Integer;
 End;
 PPoly=^TPoly;
 TPolyBlk=Array[0..PBSIZE-1] Of TPoly;
 PPolyBlk=^TPolyBlk;
 TIdxArr=Array[0..MAXPOLY-1] Of Word;
 PIdxArr=^TIdxArr;
 TCatArr=Array[0..MAXCAT-1] Of PCat;
 PCatArr=^TCatArr;
 TIntArr=Array[0..MAXCAT-1] Of Integer;
 PIntArr=^TIntArr;

 TView=Record
  Persp:Boolean;
  Yaw,Pitch,Dist,Zoom:Real;
  Tgt:TVec;
  X1,Y1,X2,Y2:Integer;
  Name:String[12];
 End;

 TMenuItem=Record
  Caption:String[34];
  Shortcut:String[10];
  Enabled,Checked,Separator:Boolean;
 End;
 TMenu=Record
  Title:String[14];
  Items:Array[0..23] Of TMenuItem;
  ItemCount:Byte;
  X,Width:Integer;
 End;

Var
 { ecran }
 ScreenW,ScreenH:Integer;
 Palette256:Boolean;
 Running:Boolean;
 { souris / clavier }
 MX,MY,MB,OldMB:Integer;
 MHid:Integer;
 { repertoires }
 BaseDir,LibDir,PlanDir:String;
 PathSep:Char;
 { couleurs }
 NCol:Integer;
 ColCode:Array[0..MAXCOL-1] Of Integer;
 ColName:Array[0..MAXCOL-1] Of String[22];
 ColR,ColG,ColB:Array[0..MAXCOL-1] Of Byte;
 ColTr:Array[0..MAXCOL-1] Of Boolean;
 ShadeMap:Array[0..MAXCOL-1,0..NSHADE-1] Of Byte;
 VgaR,VgaG,VgaB:Array[0..15] Of Byte;
 CurColor:Integer;             { code LDraw de la couleur courante }
 { bibliotheque }
 Cache:PPart;
 CacheCount:Integer;
 Epoch:LongInt;
 Catalog:PCatArr;
 CatCount:Integer;
 CatNames:Array[0..MAXCATG-1] Of String[20];
 CatN:Integer;
 Filtered:PIntArr;
 FilN:Integer;
 CatSel,CatTop,PartTop,PartSel:Integer;
 SearchStr:String[20];
 SearchEdit:Boolean;
 CurPart:String[40];
 CurPartDesc:String[44];
 { documents }
 Models:Array[0..MAXMOD-1] Of TModel;
 ModelCount,CurModel:Integer;
 DocFile:String;
 Modified:Boolean;
 { annuler / retablir }
 UndoS,RedoS:Array[0..UNDO_MAX-1] Of PSnap;
 UndoN,RedoN:Integer;
 Clip:PPiece;
 ClipN:Integer;
 { vues }
 Views:Array[0..MAXVIEW-1] Of TView;
 ViewCount,ActiveView:Integer;
 Tool:Integer;
 GridOn,EdgesOn,WireOn:Boolean;
 StudMode:Integer;            { 0 auto, 1 complets, 2 simples, 3 aucun }
 StudEff:Integer;
 { tampons de rendu }
 PolyBlk:Array[0..MAXBLK-1] Of PPolyBlk;
 PolyN,PolyMax:Integer;
 PolyIdx:PIdxArr;
 { camera courante }
 CamM:TMat;
 CamPos:TVec;
 CamPersp:Boolean;
 CamFocal,CamOrtho,CamCX,CamCY:Real;
 { interface }
 Menus:Array[0..MENU_COUNT-1] Of TMenu;
 MenuActive:Boolean;
 ActiveMenu,ActiveMenuItem:Integer;
 PanelSel:Integer;
 StatusMsg:String;
 InsM:TMat;
 InsValid:Boolean;
 InsX,InsY,InsZ:Real;
 NeedViews,NeedDock,NeedStatus,NeedTools:Boolean;
 PropField:Integer;
 PropText:String[16];
 PropFresh:Boolean;
 TimeTop:Integer;
 LastOpenDir:String;

{ ====================================================================== }
{ Utilitaires                                                            }
{ ====================================================================== }

{$IFDEF FPC}
Function MaxAvail:LongInt;
Begin
 MaxAvail:=MaxLongInt Div 2;
End;

Function MemAvail:LongInt;
Begin
 MemAvail:=MaxLongInt Div 2;
End;
{$ENDIF}

Function Max(A,B:LongInt):LongInt;
Begin
 If A>B Then Max:=A Else Max:=B;
End;

Function Min(A,B:LongInt):LongInt;
Begin
 If A<B Then Min:=A Else Min:=B;
End;

Function UpStr(Const S:String):String;
Var I:Integer; R:String;
Begin
 R:=S;
 For I:=1 To Length(R) Do If(R[I]>='a')And(R[I]<='z')Then R[I]:=Chr(Ord(R[I])-32);
 UpStr:=R;
End;

Function IntStr(N:LongInt):String;
Var S:String;
Begin
 Str(N,S);
 IntStr:=S;
End;

Function PadR(Const S:String;N:Integer):String;
Var R:String;
Begin
 R:=S;
 While Length(R)<N Do R:=R+' ';
 PadR:=R;
End;

{ Convertit les sequences \e \g \a ... en caracteres accentues (page 437) }
Function Fx(Const S:String):String;
Var I:Integer; R:String; C:Char;
Begin
 R:=''; I:=1;
 While I<=Length(S) Do Begin
  If(S[I]='\')And(I<Length(S))Then Begin
   C:=S[I+1];
   Case C Of
    'e':R:=R+#130; 'g':R:=R+#138; 'a':R:=R+#133; 'c':R:=R+#135;
    'h':R:=R+#136; 'o':R:=R+#147; 'u':R:=R+#151; 'i':R:=R+#140;
    'E':R:=R+#144;
   Else R:=R+S[I]+C;
   End;
   Inc(I,2);
  End
   Else Begin R:=R+S[I]; Inc(I); End;
 End;
 Fx:=R;
End;

Function RStr(X:Real;D:Integer):String;
Var S:String;
Begin
 Str(X:0:D,S);
 RStr:=S;
End;

{ Nombre pour fichier LDraw : entier si possible, sinon 4 decimales utiles }
Function FmtNum(X:Real):String;
Var S:String;
Begin
 If Abs(X-Round(X))<0.00005 Then Begin
  Str(Round(X):0,S);
  If S='-0' Then S:='0';
 End
  Else Begin
   Str(X:0:4,S);
   While(Length(S)>1)And(S[Length(S)]='0')Do Delete(S,Length(S),1);
   If S[Length(S)]='.' Then Delete(S,Length(S),1);
  End;
 FmtNum:=S;
End;

Function ExtOf(Const S:String):String;
Var I:Integer;
Begin
 ExtOf:='';
 For I:=Length(S) DownTo 1 Do Begin
  If S[I]='.' Then Begin ExtOf:=UpStr(Copy(S,I,255)); Exit; End;
  If(S[I]='\')Or(S[I]='/')Or(S[I]=':')Then Exit;
 End;
End;

Function BaseOf(Const S:String):String;
Var I:Integer;
Begin
 BaseOf:=S;
 For I:=Length(S) DownTo 1 Do
  If(S[I]='\')Or(S[I]='/')Or(S[I]=':')Then Begin BaseOf:=Copy(S,I+1,255); Exit; End;
End;

Function DirOf(Const S:String):String;
Var I:Integer;
Begin
 DirOf:='';
 For I:=Length(S) DownTo 1 Do
  If(S[I]='\')Or(S[I]='/')Or(S[I]=':')Then Begin DirOf:=Copy(S,1,I); Exit; End;
End;

Function ForceExt(Const S,E:String):String;
Var I:Integer;
Begin
 For I:=Length(S) DownTo 1 Do Begin
  If S[I]='.' Then Begin ForceExt:=Copy(S,1,I-1)+E; Exit; End;
  If(S[I]='\')Or(S[I]='/')Or(S[I]=':')Then Begin ForceExt:=S+E; Exit; End;
 End;
 ForceExt:=S+E;
End;

Function LoStr(Const S:String):String;
Var I:Integer; R:String;
Begin
 R:=S;
 For I:=1 To Length(R) Do If(R[I]>='A')And(R[I]<='Z')Then R[I]:=Chr(Ord(R[I])+32);
 LoStr:=R;
End;

Function ToSep(Const S:String):String;
Var I:Integer; R:String;
Begin
 R:=S;
 For I:=1 To Length(R) Do If(R[I]='/')Or(R[I]='\')Then R[I]:=PathSep;
 ToSep:=R;
End;

Function FileOK(Const P:String):Boolean;
Var F:File;
Begin
 {$I-}
 Assign(F,P);
 Reset(F,1);
 {$I+}
 If IOResult=0 Then Begin Close(F); FileOK:=True; End Else FileOK:=False;
End;

Function DirOK(Const P:String):Boolean;
Var SR:SearchRec; S:String;
Begin
 S:=P;
 If(Length(S)>0)And((S[Length(S)]='\')Or(S[Length(S)]='/'))Then Delete(S,Length(S),1);
 FindFirst(S,Directory,SR);
 DirOK:=(DosError=0)And((SR.Attr And Directory)<>0);
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
End;

{ Cherche un fichier sans tenir compte de la casse (Linux) }
Function FindCI(Const Dir,Name:String;Var Res:String):Boolean;
Begin
 FindCI:=True;
 Res:=Dir+Name;
 If FileOK(Res)Then Exit;
 Res:=Dir+UpStr(Name);
 If FileOK(Res)Then Exit;
 Res:=Dir+LoStr(Name);
 If FileOK(Res)Then Exit;
 FindCI:=False;
End;

{ ====================================================================== }
{ Souris                                                                 }
{ ====================================================================== }

Procedure MouseOff;
Begin
 If MHid=0 Then HideMouse;
 Inc(MHid);
End;

Procedure MouseOn;
Begin
 If MHid>0 Then Dec(MHid);
 If MHid=0 Then ShowMouse;
End;

Procedure PollMouse;
Var X,Y,B:LongInt;
Begin
 GetMouseState(X,Y,B);
 MX:=X; MY:=Y; MB:=B;
End;

{ ====================================================================== }
{ Maths 3D                                                               }
{ ====================================================================== }

Function ArcSin(X:Real):Real;
Begin
 If X>=1 Then ArcSin:=Pi/2
 Else If X<=-1 Then ArcSin:=-Pi/2
 Else ArcSin:=ArcTan(X/Sqrt(1-X*X));
End;

Function ATan2(Y,X:Real):Real;
Begin
 If Abs(X)<EPS Then Begin
  If Y>0 Then ATan2:=Pi/2 Else If Y<0 Then ATan2:=-Pi/2 Else ATan2:=0;
 End
  Else If X>0 Then ATan2:=ArcTan(Y/X)
  Else If Y>=0 Then ATan2:=ArcTan(Y/X)+Pi
  Else ATan2:=ArcTan(Y/X)-Pi;
End;

Procedure VSet(Var V:TVec;X,Y,Z:Real);
Begin
 V.X:=X; V.Y:=Y; V.Z:=Z;
End;

Function VDot(Const A,B:TVec):Real;
Begin
 VDot:=A.X*B.X+A.Y*B.Y+A.Z*B.Z;
End;

Procedure VCross(Const A,B:TVec;Var C:TVec);
Var T:TVec;
Begin
 T.X:=A.Y*B.Z-A.Z*B.Y;
 T.Y:=A.Z*B.X-A.X*B.Z;
 T.Z:=A.X*B.Y-A.Y*B.X;
 C:=T;
End;

Procedure VNorm(Var V:TVec);
Var L:Real;
Begin
 L:=Sqrt(V.X*V.X+V.Y*V.Y+V.Z*V.Z);
 If L>EPS Then Begin V.X:=V.X/L; V.Y:=V.Y/L; V.Z:=V.Z/L; End;
End;

Procedure MatIdent(Var M:TMat);
Var I,J:Integer;
Begin
 For I:=0 To 2 Do For J:=0 To 2 Do If I=J Then M.R[I,J]:=1 Else M.R[I,J]:=0;
 M.T.X:=0; M.T.Y:=0; M.T.Z:=0;
End;

{ C = A applique apres B : v' = A.R*(B.R*v+B.T)+A.T }
Procedure MatMul(Const A,B:TMat;Var C:TMat);
Var T:TMat; I,J:Integer;
Begin
 For I:=0 To 2 Do
  For J:=0 To 2 Do
   T.R[I,J]:=A.R[I,0]*B.R[0,J]+A.R[I,1]*B.R[1,J]+A.R[I,2]*B.R[2,J];
 T.T.X:=A.R[0,0]*B.T.X+A.R[0,1]*B.T.Y+A.R[0,2]*B.T.Z+A.T.X;
 T.T.Y:=A.R[1,0]*B.T.X+A.R[1,1]*B.T.Y+A.R[1,2]*B.T.Z+A.T.Y;
 T.T.Z:=A.R[2,0]*B.T.X+A.R[2,1]*B.T.Y+A.R[2,2]*B.T.Z+A.T.Z;
 C:=T;
End;

Procedure MatApply(Const M:TMat;Const V:TVec;Var O:TVec);
Var X,Y,Z:Real;
Begin
 X:=M.R[0,0]*V.X+M.R[0,1]*V.Y+M.R[0,2]*V.Z+M.T.X;
 Y:=M.R[1,0]*V.X+M.R[1,1]*V.Y+M.R[1,2]*V.Z+M.T.Y;
 Z:=M.R[2,0]*V.X+M.R[2,1]*V.Y+M.R[2,2]*V.Z+M.T.Z;
 O.X:=X; O.Y:=Y; O.Z:=Z;
End;

Function MatDet(Const M:TMat):Real;
Begin
 MatDet:=M.R[0,0]*(M.R[1,1]*M.R[2,2]-M.R[1,2]*M.R[2,1])
        -M.R[0,1]*(M.R[1,0]*M.R[2,2]-M.R[1,2]*M.R[2,0])
        +M.R[0,2]*(M.R[1,0]*M.R[2,1]-M.R[1,1]*M.R[2,0]);
End;

{ Rotation pure autour d'un axe monde (0=X,1=Y,2=Z), angle en degres }
Procedure MatRotAxis(Axis:Integer;Deg:Real;Var M:TMat);
Var C,S,A:Real;
Begin
 A:=Deg*Pi/180;
 C:=Cos(A); S:=Sin(A);
 { valeurs exactes pour les multiples de 90 degres }
 If Abs(C)<0.0000001 Then C:=0;
 If Abs(S)<0.0000001 Then S:=0;
 If Abs(C-1)<0.0000001 Then C:=1; If Abs(C+1)<0.0000001 Then C:=-1;
 If Abs(S-1)<0.0000001 Then S:=1; If Abs(S+1)<0.0000001 Then S:=-1;
 MatIdent(M);
 Case Axis Of
  0:Begin M.R[1,1]:=C; M.R[1,2]:=-S; M.R[2,1]:=S; M.R[2,2]:=C; End;
  1:Begin M.R[0,0]:=C; M.R[0,2]:=S; M.R[2,0]:=-S; M.R[2,2]:=C; End;
 Else Begin M.R[0,0]:=C; M.R[0,1]:=-S; M.R[1,0]:=S; M.R[1,1]:=C; End;
 End;
End;

Procedure MatFromEuler(RX,RY,RZ:Real;Var M:TMat);
Var A,B,C:TMat;
Begin
 MatRotAxis(0,RX,A); MatRotAxis(1,RY,B); MatRotAxis(2,RZ,C);
 MatMul(B,A,M);
 MatMul(C,M,M);
End;

Function AngNorm(A:Real):Real;
Begin
 While A>180.0001 Do A:=A-360;
 While A<-179.9999 Do A:=A+360;
 AngNorm:=A;
End;

Procedure EulerFromMat(Const M:TMat;Var RX,RY,RZ:Real);
Var SY,AX,AY,AZ:Real;
Begin
 SY:=-M.R[2,0];
 If SY>1 Then SY:=1; If SY<-1 Then SY:=-1;
 RY:=ArcSin(SY);
 If Abs(Cos(RY))>0.0001 Then Begin
  RX:=ATan2(M.R[2,1],M.R[2,2]);
  RZ:=ATan2(M.R[1,0],M.R[0,0]);
 End
  Else Begin
   RX:=ATan2(-M.R[1,2],M.R[1,1]);
   RZ:=0;
  End;
 RX:=RX*180/Pi; RY:=RY*180/Pi; RZ:=RZ*180/Pi;
 { solution equivalente (RX+180, 180-RY, RZ+180) : on garde la plus simple }
 AX:=AngNorm(RX+180); AY:=AngNorm(180-RY); AZ:=AngNorm(RZ+180);
 If Abs(AX)+Abs(AY)+Abs(AZ)+0.001<Abs(RX)+Abs(RY)+Abs(RZ)Then Begin
  RX:=AX; RY:=AY; RZ:=AZ;
 End;
End;

Function Sgn(X:Real):Integer;
Begin
 If X<0 Then Sgn:=-1 Else Sgn:=1;
End;

{ ====================================================================== }
{ Couleurs LDraw                                                         }
{ ====================================================================== }

Procedure AddC(Code:Integer;Const Nm:String;R,G,B:Byte;Tr:Boolean);
Begin
 If NCol>=MAXCOL Then Exit;
 ColCode[NCol]:=Code; ColName[NCol]:=Fx(Nm);
 ColR[NCol]:=R; ColG[NCol]:=G; ColB[NCol]:=B; ColTr[NCol]:=Tr;
 Inc(NCol);
End;

Procedure InitColors;
Begin
 NCol:=0;
 AddC(0,'Noir',27,42,52,False);
 AddC(1,'Bleu',30,90,168,False);
 AddC(2,'Vert',0,133,43,False);
 AddC(3,'Turquoise fonc\e',0,143,155,False);
 AddC(4,'Rouge',196,40,27,False);
 AddC(5,'Rose fonc\e',200,112,160,False);
 AddC(6,'Brun',95,49,9,False);
 AddC(7,'Gris clair',155,161,157,False);
 AddC(8,'Gris fonc\e',109,110,92,False);
 AddC(9,'Bleu clair',180,210,228,False);
 AddC(10,'Vert vif',75,159,74,False);
 AddC(11,'Turquoise',85,165,175,False);
 AddC(12,'Saumon',242,112,94,False);
 AddC(13,'Rose',252,151,172,False);
 AddC(14,'Jaune',245,205,47,False);
 AddC(15,'Blanc',244,244,244,False);
 AddC(19,'Beige',228,205,158,False);
 AddC(25,'Orange',254,138,24,False);
 AddC(26,'Magenta',144,31,118,False);
 AddC(27,'Citron vert',187,233,11,False);
 AddC(28,'Beige fonc\e',149,138,115,False);
 AddC(70,'Brun rouge',105,64,39,False);
 AddC(71,'Gris bleu clair',163,162,164,False);
 AddC(72,'Gris bleu fonc\e',99,95,98,False);
 AddC(84,'Chair',170,125,85,False);
 AddC(272,'Bleu fonc\e',10,52,99,False);
 AddC(288,'Vert fonc\e',24,70,50,False);
 AddC(320,'Rouge fonc\e',123,46,47,False);
 AddC(484,'Orange fonc\e',160,95,52,False);
 AddC(33,'Bleu transp.',0,32,160,True);
 AddC(34,'Vert transp.',35,120,65,True);
 AddC(36,'Rouge transp.',201,26,9,True);
 AddC(43,'Bleu clair transp.',193,223,240,True);
 AddC(46,'Jaune transp.',245,205,47,True);
 AddC(47,'Transparent',252,252,252,True);
End;

Function ColIdx(Code:Integer):Integer;
Var I:Integer;
Begin
 For I:=0 To NCol-1 Do If ColCode[I]=Code Then Begin ColIdx:=I; Exit; End;
 ColIdx:=7;
End;

Procedure InitVga;
Const
 R:Array[0..15] Of Byte=(0,0,0,0,170,170,170,170,85,85,85,85,255,255,255,255);
 G:Array[0..15] Of Byte=(0,0,170,170,0,0,85,170,85,85,255,255,85,85,255,255);
 B:Array[0..15] Of Byte=(0,170,0,170,0,170,0,170,85,255,85,255,85,255,85,255);
Var I:Integer;
Begin
 For I:=0 To 15 Do Begin VgaR[I]:=R[I]; VgaG[I]:=G[I]; VgaB[I]:=B[I]; End;
End;

Function NearVga(R,G,B:Integer):Integer;
Var I,Best:Integer; D,BD:LongInt;
Begin
 Best:=0; BD:=2000000000;
 For I:=0 To 15 Do Begin
  D:=Sqr(LongInt(R)-VgaR[I])*3+Sqr(LongInt(G)-VgaG[I])*4+Sqr(LongInt(B)-VgaB[I])*2;
  If D<BD Then Begin BD:=D; Best:=I; End;
 End;
 NearVga:=Best;
End;

Var PalR,PalG,PalB:Array[0..255] Of Byte;

Procedure SetupPalette;
Const SF:Array[0..NSHADE-1] Of Real=(0.40,0.56,0.72,0.87,1.0,1.16);
Var C,S,Idx:Integer; R,G,B:LongInt;
Begin
 InitVga;
 For C:=0 To 15 Do Begin PalR[C]:=VgaR[C]; PalG[C]:=VgaG[C]; PalB[C]:=VgaB[C]; End;
 For C:=0 To NCol-1 Do
  For S:=0 To NSHADE-1 Do Begin
   R:=Round(ColR[C]*SF[S]); G:=Round(ColG[C]*SF[S]); B:=Round(ColB[C]*SF[S]);
   If R>255 Then R:=255; If G>255 Then G:=255; If B>255 Then B:=255;
   If Palette256 Then Begin
    Idx:=16+C*NSHADE+S;
    SetRGBPalette(Idx,R,G,B);
    PalR[Idx]:=R; PalG[Idx]:=G; PalB[Idx]:=B;
    ShadeMap[C,S]:=Idx;
   End
    Else ShadeMap[C,S]:=NearVga(R,G,B);
  End;
End;

{ ====================================================================== }
{ Primitives d'interface                                                 }
{ ====================================================================== }

Procedure Box(X1,Y1,X2,Y2,C:Integer);
Begin
 SetFillStyle(SolidFill,C);
 Bar(X1,Y1,X2,Y2);
End;

Procedure TxtOut(X,Y:Integer;Const S:String;C:Integer);
Begin
 SetColor(C);
 OutTextXY(X,Y,S);
End;

Procedure TxtF(X,Y:Integer;Const S:String;C:Integer);
Begin
 SetColor(C);
 OutTextXY(X,Y,Fx(S));
End;

Procedure Bevel(X1,Y1,X2,Y2:Integer;Raised:Boolean);
Var A,B:Integer;
Begin
 If Raised Then Begin A:=UI_HI; B:=UI_SH; End Else Begin A:=UI_SH; B:=UI_HI; End;
 SetColor(A);
 Line(X1,Y1,X2-1,Y1); Line(X1,Y1,X1,Y2-1);
 SetColor(B);
 Line(X2,Y1,X2,Y2); Line(X1,Y2,X2,Y2);
End;

Procedure Raised(X1,Y1,X2,Y2:Integer);
Begin
 Box(X1,Y1,X2,Y2,UI_BG);
 Bevel(X1,Y1,X2,Y2,True);
End;

Procedure Sunken(X1,Y1,X2,Y2,C:Integer);
Begin
 Box(X1,Y1,X2,Y2,C);
 Bevel(X1,Y1,X2,Y2,False);
End;

Procedure DrawBtn(X,Y,W,H:Integer;Const Cap:String;Down:Boolean);
Var S:String; TX:Integer;
Begin
 Box(X,Y,X+W-1,Y+H-1,UI_BG);
 Bevel(X,Y,X+W-1,Y+H-1,Not Down);
 S:=Fx(Cap);
 TX:=X+(W-TextWidth(S)) Div 2;
 If Down Then Begin Inc(TX); End;
 TxtOut(TX,Y+(H-8) Div 2+Ord(Down),S,UI_DK);
End;

Procedure DrawWin(X,Y,W,H:Integer;Const Title:String);
Begin
 Box(X,Y,X+W-1,Y+H-1,UI_BG);
 Bevel(X,Y,X+W-1,Y+H-1,True);
 Bevel(X+1,Y+1,X+W-2,Y+H-2,True);
 Box(X+3,Y+3,X+W-4,Y+16,UI_SEL);
 TxtOut(X+8,Y+6,Fx(Title),15);
End;

Function InRect(PX,PY,X,Y,W,H:Integer):Boolean;
Begin
 InRect:=(PX>=X)And(PX<X+W)And(PY>=Y)And(PY<Y+H);
End;

{ Barre de defilement verticale (largeur 12) }
Procedure DrawVScroll(X,Y,H,Top,Count,Vis:Integer);
Var TH,TY,Rng:Integer;
Begin
 Box(X,Y,X+11,Y+H-1,UI_BG);
 Box(X,Y+12,X+11,Y+H-13,8);
 Raised(X,Y,X+11,Y+11);
 Raised(X,Y+H-12,X+11,Y+H-1);
 SetColor(UI_DK);
 Line(X+3,Y+7,X+8,Y+7); Line(X+4,Y+6,X+7,Y+6); Line(X+5,Y+5,X+6,Y+5);
 Line(X+3,Y+H-8,X+8,Y+H-8); Line(X+4,Y+H-7,X+7,Y+H-7); Line(X+5,Y+H-6,X+6,Y+H-6);
 If Count>Vis Then Begin
  Rng:=H-24;
  TH:=LongInt(Rng)*Vis Div Count; If TH<8 Then TH:=8;
  TY:=Y+12+LongInt(Rng-TH)*Top Div (Count-Vis);
  Raised(X,TY,X+11,TY+TH-1);
 End;
End;

{ Retourne le nouveau Top apres un clic en (PY) sur la barre }
Function VScrollClick(Y,H,Top,Count,Vis,PY:Integer):Integer;
Var N:Integer;
Begin
 N:=Top;
 If PY<Y+12 Then Dec(N)
 Else If PY>=Y+H-12 Then Inc(N)
 Else Begin
  If Count>Vis Then Begin
   N:=LongInt(PY-Y-12)*(Count-Vis) Div Max(1,H-24);
  End;
 End;
 If N>Count-Vis Then N:=Count-Vis;
 If N<0 Then N:=0;
 VScrollClick:=N;
End;

{ Sauvegarde / restauration de zone ecran }
Type
 TSave=Record
  P:Pointer;
  Sz:LongInt;
  X1,Y1,X2,Y2:Integer;
 End;

Procedure SaveRect(Var S:TSave;X1,Y1,X2,Y2:Integer);
Var Sz:LongInt;
Begin
 S.P:=Nil; S.Sz:=0;
 If X1<0 Then X1:=0; If Y1<0 Then Y1:=0;
 If X2>ScreenW-1 Then X2:=ScreenW-1;
 If Y2>ScreenH-1 Then Y2:=ScreenH-1;
 S.X1:=X1; S.Y1:=Y1; S.X2:=X2; S.Y2:=Y2;
 Sz:=ImageSize(X1,Y1,X2,Y2);
 If Sz<=0 Then Exit;
 If MaxAvail<Sz+8192 Then Exit;
 GetMem(S.P,Sz);
 S.Sz:=Sz;
 GetImage(X1,Y1,X2,Y2,S.P^);
End;

{ Retourne False si la zone n'etait pas sauvegardee (redessin complet requis) }
Function RestoreRect(Var S:TSave):Boolean;
Begin
 RestoreRect:=False;
 If S.P=Nil Then Exit;
 PutImage(S.X1,S.Y1,S.P^,NormalPut);
 FreeMem(S.P,S.Sz);
 S.P:=Nil;
 RestoreRect:=True;
End;

{ ====================================================================== }
{ Bibliotheque de pieces : lecture des fichiers LDraw (.DAT)             }
{ ====================================================================== }

Function Tok(Var S:String):String;
Var I:Integer;
Begin
 I:=1;
 While(I<=Length(S))And((S[I]=' ')Or(S[I]=#9))Do Inc(I);
 Delete(S,1,I-1);
 I:=1;
 While(I<=Length(S))And(S[I]<>' ')And(S[I]<>#9)Do Inc(I);
 Tok:=Copy(S,1,I-1);
 Delete(S,1,I-1);
End;

Function NumTok(Var S:String;Var V:Real):Boolean;
Var T:String; C:Integer;
Begin
 T:=Tok(S);
 Val(T,V,C);
 NumTok:=(C=0)And(T<>'');
End;

Function TrimStr(Const S:String):String;
Var A,B:Integer;
Begin
 A:=1; B:=Length(S);
 While(A<=B)And((S[A]=' ')Or(S[A]=#9)Or(S[A]=#13)Or(S[A]=#10))Do Inc(A);
 While(B>=A)And((S[B]=' ')Or(S[B]=#9)Or(S[B]=#13)Or(S[B]=#10))Do Dec(B);
 TrimStr:=Copy(S,A,B-A+1);
End;

Procedure FreePrims(Q:PPrim);
Var N:PPrim;
Begin
 While Q<>Nil Do Begin N:=Q^.Next; Dispose(Q); Q:=N; End;
End;

Procedure FlushCache;
Var P,N:PPart;
Begin
 P:=Cache;
 While P<>Nil Do Begin
  N:=P^.Next;
  FreePrims(P^.Prims);
  Dispose(P);
  P:=N;
 End;
 Cache:=Nil;
 CacheCount:=0;
 Inc(Epoch);
End;

Function FindPartFile(Const Name:String;Var Res:String):Boolean;
Var N:String;
Begin
 N:=ToSep(Name);
 FindPartFile:=True;
 If FindCI(LibDir,N,Res)Then Exit;
 If FindCI(LibDir+'P'+PathSep,N,Res)Then Exit;
 If FindCI(LibDir+'PARTS'+PathSep,N,Res)Then Exit;
 If FindCI(LibDir+'P'+PathSep+'48'+PathSep,N,Res)Then Exit;
 If FindCI(LibDir+'S'+PathSep,N,Res)Then Exit;
 If(Length(N)>2)And((UpCase(N[1])='S')And(N[2]=PathSep))Then
  If FindCI(LibDir+'PARTS'+PathSep+'S'+PathSep,Copy(N,3,255),Res)Then Exit;
 If(Length(N)>2)And((UpCase(N[1])='S')And(N[2]=PathSep))Then
  If FindCI(LibDir+'S'+PathSep,Copy(N,3,255),Res)Then Exit;
 FindPartFile:=False;
End;

Function GetPart(Const Name:String;Depth:Integer):PPart; Forward;

Function NewPrim(P:PPart;Kind:Byte):PPrim;
Var Q:PPrim;
Begin
 New(Q);
 FillChar(Q^,SizeOf(TPrim),0);
 Q^.Kind:=Kind;
 If P^.Tail=Nil Then P^.Prims:=Q Else P^.Tail^.Next:=Q;
 P^.Tail:=Q;
 NewPrim:=Q;
End;

Procedure ParseLine(P:PPart;Line:String;Var Cert,CW,InvNext:Boolean;Depth:Integer);
Var
 T,F:String;
 Typ,I:Integer;
 V:Real;
 Q:PPrim;
 Col:Real;
 N:Integer;
 Ok:Boolean;
 Pt:Array[0..3] Of TVec;
 Cl:Byte;
Begin
 Line:=TrimStr(Line);
 If Line='' Then Exit;
 T:=Tok(Line);
 Typ:=Ord(T[1])-48;
 If Length(T)<>1 Then Exit;
 If Typ=0 Then Begin
  T:=UpStr(Tok(Line));
  If T='BFC' Then Begin
   Repeat
    T:=UpStr(Tok(Line));
    If T='CERTIFY' Then Cert:=True
    Else If T='NOCERTIFY' Then Cert:=False
    Else If T='CCW' Then CW:=False
    Else If T='CW' Then CW:=True
    Else If T='INVERTNEXT' Then InvNext:=True;
   Until T='';
  End;
  Exit;
 End;
 If Cert Then Begin If CW Then Cl:=2 Else Cl:=1; End Else Cl:=0;
 If Not NumTok(Line,Col)Then Exit;
 Case Typ Of
  1:Begin
   Q:=NewPrim(P,PK_REF);
   Q^.Col:=Round(Col);
   If Not NumTok(Line,Q^.M.T.X)Then Begin Q^.Kind:=0; Exit; End;
   NumTok(Line,Q^.M.T.Y); NumTok(Line,Q^.M.T.Z);
   For I:=0 To 2 Do Begin
    NumTok(Line,Q^.M.R[I,0]); NumTok(Line,Q^.M.R[I,1]); NumTok(Line,Q^.M.R[I,2]);
   End;
   F:=UpStr(TrimStr(Line));
   Q^.Inv:=InvNext; InvNext:=False;
   If MatDet(Q^.M)<0 Then Q^.Cull:=1;
   If F='STUD.DAT' Then Q^.Kind:=PK_STUD
   Else Begin
    Q^.Ref:=GetPart(F,Depth+1);
    If Q^.Ref=Nil Then Q^.Kind:=0;
   End;
  End;
  2,3,4:Begin
   N:=Typ;
   If Typ=2 Then N:=2;
   Ok:=True;
   For I:=0 To N-1 Do Begin
    Ok:=Ok And NumTok(Line,Pt[I].X) And NumTok(Line,Pt[I].Y) And NumTok(Line,Pt[I].Z);
   End;
   If Not Ok Then Exit;
   Q:=NewPrim(P,Typ);
   Q^.Col:=Round(Col);
   Q^.Cull:=Cl;
   For I:=0 To N-1 Do Q^.P[I]:=Pt[I];
  End;
 End;
 If Typ<>1 Then InvNext:=False;
End;

{ Fusionne un point dans une boite }
Procedure BoxAdd(Var Mn,Mx:TVec;Const V:TVec);
Begin
 If V.X<Mn.X Then Mn.X:=V.X; If V.X>Mx.X Then Mx.X:=V.X;
 If V.Y<Mn.Y Then Mn.Y:=V.Y; If V.Y>Mx.Y Then Mx.Y:=V.Y;
 If V.Z<Mn.Z Then Mn.Z:=V.Z; If V.Z>Mx.Z Then Mx.Z:=V.Z;
End;

Procedure BoxEmpty(Var Mn,Mx:TVec);
Begin
 VSet(Mn,1E9,1E9,1E9); VSet(Mx,-1E9,-1E9,-1E9);
End;

Function BoxIsEmpty(Const Mn,Mx:TVec):Boolean;
Begin
 BoxIsEmpty:=Mn.X>Mx.X;
End;

{ Ajoute les 8 coins de la boite (Mn,Mx) transformes par M }
Procedure BoxAddXf(Var Mn,Mx:TVec;Const M:TMat;Const A,B:TVec);
Var I:Integer; V,O:TVec;
Begin
 If BoxIsEmpty(A,B)Then Exit;
 For I:=0 To 7 Do Begin
  If I And 1=0 Then V.X:=A.X Else V.X:=B.X;
  If I And 2=0 Then V.Y:=A.Y Else V.Y:=B.Y;
  If I And 4=0 Then V.Z:=A.Z Else V.Z:=B.Z;
  MatApply(M,V,O);
  BoxAdd(Mn,Mx,O);
 End;
End;

Procedure CalcBBox(P:PPart);
Var Q:PPrim; I,N:Integer; A,B:TVec;
Begin
 If P^.BBox Then Exit;
 P^.BBox:=True;
 BoxEmpty(P^.AMin,P^.AMax);
 BoxEmpty(P^.BMin,P^.BMax);
 Q:=P^.Prims;
 While Q<>Nil Do Begin
  Case Q^.Kind Of
   PK_LINE,PK_TRI,PK_QUAD:Begin
    N:=Q^.Kind; If N=PK_LINE Then N:=2;
    For I:=0 To N-1 Do Begin
     BoxAdd(P^.AMin,P^.AMax,Q^.P[I]);
     If Q^.Kind<>PK_LINE Then BoxAdd(P^.BMin,P^.BMax,Q^.P[I]);
    End;
   End;
   PK_REF:If Q^.Ref<>Nil Then Begin
    CalcBBox(Q^.Ref);
    BoxAddXf(P^.AMin,P^.AMax,Q^.M,Q^.Ref^.AMin,Q^.Ref^.AMax);
    If Not BoxIsEmpty(Q^.Ref^.BMin,Q^.Ref^.BMax)Then
     BoxAddXf(P^.BMin,P^.BMax,Q^.M,Q^.Ref^.BMin,Q^.Ref^.BMax);
   End;
   PK_STUD:Begin
    VSet(A,-6,-4,-6); VSet(B,6,0,6);
    BoxAddXf(P^.AMin,P^.AMax,Q^.M,A,B);
   End;
  End;
  Q:=Q^.Next;
 End;
 If BoxIsEmpty(P^.AMin,P^.AMax)Then Begin
  VSet(P^.AMin,0,0,0); VSet(P^.AMax,0,0,0);
 End;
 If BoxIsEmpty(P^.BMin,P^.BMax)Then Begin
  P^.BMin:=P^.AMin; P^.BMax:=P^.AMax;
 End;
End;

Function GetPart(Const Name:String;Depth:Integer):PPart;
Var
 P:PPart;
 N,Path,Line:String;
 F:Text;
 Cert,CW,InvNext:Boolean;
Begin
 GetPart:=Nil;
 N:=UpStr(ToSep(TrimStr(Name)));
 If N='' Then Exit;
 P:=Cache;
 While P<>Nil Do Begin
  If P^.Name=N Then Begin
   If P^.Found Then GetPart:=P;
   Exit;
  End;
  P:=P^.Next;
 End;
 If Depth>10 Then Exit;
 New(P);
 FillChar(P^,SizeOf(TPart),0);
 P^.Name:=Copy(N,1,40);
 P^.Next:=Cache; Cache:=P; Inc(CacheCount);
 If Not FindPartFile(N,Path)Then Exit;
 {$I-}
 Assign(F,Path);
 Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 P^.Found:=True;
 Cert:=False; CW:=False; InvNext:=False;
 While Not Eof(F) Do Begin
  {$I-}ReadLn(F,Line);{$I+}
  If IOResult<>0 Then Line:='';
  ParseLine(P,Line,Cert,CW,InvNext,Depth);
 End;
 Close(F);
 GetPart:=P;
End;

{ ====================================================================== }
{ Catalogue des pieces                                                   }
{ ====================================================================== }

Procedure FreeCatalog;
Var I:Integer;
Begin
 For I:=0 To CatCount-1 Do If Catalog^[I]<>Nil Then Dispose(Catalog^[I]);
 CatCount:=0;
End;

Procedure AddCatalog(Const Fn,Desc:String);
Var C:PCat;
Begin
 If CatCount>=MAXCAT Then Exit;
 New(C);
 C^.FileN:=Copy(Fn,1,12);
 C^.Desc:=Copy(TrimStr(Desc),1,44);
 C^.Cat:=0;
 Catalog^[CatCount]:=C;
 Inc(CatCount);
End;

Function FirstWord(Const D:String):String;
Var I:Integer; S:String;
Begin
 I:=1;
 While(I<=Length(D))And(D[I] In ['~','_','=','|',' '])Do Inc(I);
 S:='';
 While(I<=Length(D))And(D[I]<>' ')Do Begin S:=S+D[I]; Inc(I); End;
 If S='' Then S:='Divers';
 FirstWord:=Copy(S,1,16);
End;

Procedure SortCatalog;
Var Gap,I,J:Integer; T:PCat;
Begin
 Gap:=CatCount Div 2;
 While Gap>0 Do Begin
  For I:=Gap To CatCount-1 Do Begin
   T:=Catalog^[I];
   J:=I;
   While(J>=Gap)And(Catalog^[J-Gap]^.Desc>T^.Desc)Do Begin
    Catalog^[J]:=Catalog^[J-Gap];
    Dec(J,Gap);
   End;
   Catalog^[J]:=T;
  End;
  Gap:=Gap Div 2;
 End;
End;

Procedure BuildCategories;
Var I,J,K:Integer; W:String; Found:Boolean; T:String[20];
Begin
 CatN:=1;
 CatNames[0]:=Fx('Toutes les pi\eces');
 For I:=0 To CatCount-1 Do Begin
  W:=FirstWord(Catalog^[I]^.Desc);
  Found:=False;
  For J:=1 To CatN-1 Do If CatNames[J]=W Then Found:=True;
  If(Not Found)And(CatN<MAXCATG)Then Begin
   CatNames[CatN]:=W; Inc(CatN);
  End;
 End;
 { tri des categories (0 reste en tete) }
 For I:=2 To CatN-1 Do Begin
  T:=CatNames[I]; J:=I-1;
  While(J>=1)And(CatNames[J]>T)Do Begin CatNames[J+1]:=CatNames[J]; Dec(J); End;
  CatNames[J+1]:=T;
 End;
 For I:=0 To CatCount-1 Do Begin
  W:=FirstWord(Catalog^[I]^.Desc);
  K:=CatN-1;
  For J:=1 To CatN-1 Do If CatNames[J]=W Then Begin K:=J; J:=CatN; End;
  Catalog^[I]^.Cat:=K;
 End;
End;

Procedure RefilterParts;
Var I:Integer; S,D:String; Ok:Boolean;
Begin
 FilN:=0;
 S:=UpStr(SearchStr);
 For I:=0 To CatCount-1 Do Begin
  Ok:=True;
  If(CatSel<>0)And(Catalog^[I]^.Cat<>CatSel)Then Ok:=False;
  If Ok And(S<>'')Then Begin
   D:=UpStr(Catalog^[I]^.Desc+' '+Catalog^[I]^.FileN);
   If Pos(S,D)=0 Then Ok:=False;
  End;
  If Ok Then Begin Filtered^[FilN]:=I; Inc(FilN); End;
 End;
 PartTop:=0;
 PartSel:=-1;
End;

{ Lit la premiere ligne "0 description" d'un fichier .DAT }
Function ReadDesc(Const Path:String):String;
Var F:Text; L:String;
Begin
 ReadDesc:='';
 {$I-}
 Assign(F,Path); Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 {$I-}ReadLn(F,L);{$I+}
 If IOResult=0 Then Begin
  L:=TrimStr(L);
  If(Length(L)>=2)And(L[1]='0')Then ReadDesc:=TrimStr(Copy(L,2,255));
 End;
 Close(F);
End;

Procedure SaveCatalog;
Var F:Text; I:Integer;
Begin
 {$I-}
 Assign(F,LibDir+'PARTS.LST'); Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 For I:=0 To CatCount-1 Do WriteLn(F,Catalog^[I]^.FileN,'|',Catalog^[I]^.Desc);
 Close(F);
End;

{ Parcourt le repertoire des pieces et reconstruit l'index }
Procedure ScanLibrary;
Var SR:SearchRec; D:String; Pass:Integer;
Begin
 FreeCatalog;
 For Pass:=0 To 1 Do Begin
  {$IFDEF FPC}
  If Pass=0 Then FindFirst(LibDir+'*.DAT',AnyFile,SR) Else FindFirst(LibDir+'*.dat',AnyFile,SR);
  {$ELSE}
  If Pass=0 Then FindFirst(LibDir+'*.DAT',AnyFile,SR) Else DosError:=18;
  {$ENDIF}
  If(Pass=1)And(CatCount>0)Then DosError:=18;
  While DosError=0 Do Begin
   If(SR.Attr And Directory)=0 Then Begin
    D:=ReadDesc(LibDir+SR.Name);
    If D='' Then D:=SR.Name;
    AddCatalog(UpStr(SR.Name),D);
   End;
   FindNext(SR);
  End;
  {$IFDEF FPC}FindClose(SR);{$ENDIF}
 End;
 SortCatalog;
 SaveCatalog;
End;

Procedure LoadCatalog;
Var F:Text; L:String; P:Integer;
Begin
 FreeCatalog;
 {$I-}
 Assign(F,LibDir+'PARTS.LST'); Reset(F);
 {$I+}
 If IOResult=0 Then Begin
  While Not Eof(F) Do Begin
   {$I-}ReadLn(F,L);{$I+}
   If IOResult<>0 Then L:='';
   P:=Pos('|',L);
   If P>1 Then AddCatalog(Copy(L,1,P-1),Copy(L,P+1,255));
  End;
  Close(F);
 End;
 If CatCount=0 Then ScanLibrary;
 BuildCategories;
 CatSel:=0; CatTop:=0; SearchStr:='';
 RefilterParts;
End;

{ ====================================================================== }
{ Modeles, pieces                                                        }
{ ====================================================================== }

Function FindModel(Const N:String):Integer;
Var I:Integer; U:String;
Begin
 U:=UpStr(N);
 For I:=0 To ModelCount-1 Do
  If UpStr(Models[I].Name)=U Then Begin FindModel:=I; Exit; End;
 FindModel:=-1;
End;

Procedure FreeList(Q:PPiece);
Var N:PPiece;
Begin
 While Q<>Nil Do Begin N:=Q^.Next; Dispose(Q); Q:=N; End;
End;

Procedure ClearAllModels;
Var I:Integer;
Begin
 For I:=0 To MAXMOD-1 Do Begin
  FreeList(Models[I].First);
  Models[I].First:=Nil; Models[I].Last:=Nil; Models[I].Count:=0;
  Models[I].Used:=False; Models[I].Name:=''; Models[I].CurStep:=1;
 End;
 ModelCount:=0; CurModel:=0;
End;

Function NewModel(Const N:String):Integer;
Begin
 NewModel:=-1;
 If ModelCount>=MAXMOD Then Exit;
 Models[ModelCount].Used:=True;
 Models[ModelCount].Name:=Copy(N,1,40);
 Models[ModelCount].First:=Nil; Models[ModelCount].Last:=Nil;
 Models[ModelCount].Count:=0; Models[ModelCount].CurStep:=1;
 NewModel:=ModelCount;
 Inc(ModelCount);
End;

Function AddPiece(M:Integer;Const Name:String;Col:Integer;Const Mt:TMat;Step:Integer):PPiece;
Var Q:PPiece;
Begin
 New(Q);
 FillChar(Q^,SizeOf(TPiece),0);
 Q^.Name:=Copy(Name,1,40);
 Q^.Col:=Col; Q^.M:=Mt; Q^.Step:=Step;
 Q^.Prev:=Models[M].Last;
 If Models[M].Last<>Nil Then Models[M].Last^.Next:=Q Else Models[M].First:=Q;
 Models[M].Last:=Q;
 Inc(Models[M].Count);
 AddPiece:=Q;
End;

Procedure RemovePiece(M:Integer;Q:PPiece);
Begin
 If Q^.Prev<>Nil Then Q^.Prev^.Next:=Q^.Next Else Models[M].First:=Q^.Next;
 If Q^.Next<>Nil Then Q^.Next^.Prev:=Q^.Prev Else Models[M].Last:=Q^.Prev;
 Dec(Models[M].Count);
 Dispose(Q);
End;

Function MaxStep(M:Integer):Integer;
Var Q:PPiece; S:Integer;
Begin
 S:=1;
 Q:=Models[M].First;
 While Q<>Nil Do Begin If Q^.Step>S Then S:=Q^.Step; Q:=Q^.Next; End;
 MaxStep:=S;
End;

Function PiecePart(Q:PPiece):PPart;
Begin
 If(Q^.Part=Nil)Or(Q^.Epoch<>Epoch)Then Begin
  Q^.Part:=GetPart(Q^.Name,0);
  Q^.Epoch:=Epoch;
 End;
 PiecePart:=Q^.Part;
End;

{ Boite englobante d'un modele transforme par Xf }
Procedure ModelBounds(M:Integer;Const Xf:TMat;Body,AllSteps:Boolean;Var Mn,Mx:TVec;Depth:Integer);
Var Q:PPiece; T:TMat; S:Integer; P:PPart;
Begin
 If Depth>6 Then Exit;
 Q:=Models[M].First;
 While Q<>Nil Do Begin
  If(AllSteps Or((Q^.Step<=Models[M].CurStep)And(Not Q^.Hidden)))Then Begin
   MatMul(Xf,Q^.M,T);
   S:=FindModel(Q^.Name);
   If S>=0 Then ModelBounds(S,T,Body,True,Mn,Mx,Depth+1)
   Else Begin
    P:=PiecePart(Q);
    If P<>Nil Then Begin
     CalcBBox(P);
     If Body Then BoxAddXf(Mn,Mx,T,P^.BMin,P^.BMax)
     Else BoxAddXf(Mn,Mx,T,P^.AMin,P^.AMax);
    End;
   End;
  End;
  Q:=Q^.Next;
 End;
End;

Procedure PieceBounds(Q:PPiece;Body:Boolean;Var Mn,Mx:TVec);
Var S:Integer; P:PPart; I:TMat;
Begin
 BoxEmpty(Mn,Mx);
 S:=FindModel(Q^.Name);
 If S>=0 Then ModelBounds(S,Q^.M,Body,True,Mn,Mx,1)
 Else Begin
  P:=PiecePart(Q);
  If P<>Nil Then Begin
   CalcBBox(P);
   If Body Then BoxAddXf(Mn,Mx,Q^.M,P^.BMin,P^.BMax)
   Else BoxAddXf(Mn,Mx,Q^.M,P^.AMin,P^.AMax);
  End;
 End;
 If BoxIsEmpty(Mn,Mx)Then Begin
  Mn:=Q^.M.T; Mx:=Q^.M.T;
 End;
End;

Function SelCount:Integer;
Var Q:PPiece; N:Integer;
Begin
 N:=0;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin If Q^.Sel Then Inc(N); Q:=Q^.Next; End;
 SelCount:=N;
End;

Function FirstSel:PPiece;
Var Q:PPiece;
Begin
 Q:=Models[CurModel].First;
 While(Q<>Nil)And(Not Q^.Sel)Do Q:=Q^.Next;
 FirstSel:=Q;
End;

Procedure ClearSel;
Var Q:PPiece;
Begin
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin Q^.Sel:=False; Q:=Q^.Next; End;
End;

Function PieceVisible(Q:PPiece):Boolean;
Begin
 PieceVisible:=(Q^.Step<=Models[CurModel].CurStep)And(Not Q^.Hidden);
End;

Function PieceDesc(Q:PPiece):String;
Var I:Integer; U:String;
Begin
 PieceDesc:=Q^.Name;
 If FindModel(Q^.Name)>=0 Then Begin PieceDesc:=Q^.Name; Exit; End;
 U:=UpStr(Q^.Name);
 For I:=0 To CatCount-1 Do
  If Catalog^[I]^.FileN=U Then Begin PieceDesc:=Catalog^[I]^.Desc; Exit; End;
End;

Function PartDescByName(Const Nm:String):String;
Var I:Integer; U:String;
Begin
 PartDescByName:=Nm;
 U:=UpStr(Nm);
 For I:=0 To CatCount-1 Do
  If Catalog^[I]^.FileN=U Then Begin PartDescByName:=Catalog^[I]^.Desc; Exit; End;
End;

{ ====================================================================== }
{ Annuler / retablir                                                     }
{ ====================================================================== }

Function CopyPiece(Q:PPiece):PPiece;
Var N:PPiece;
Begin
 New(N);
 N^:=Q^;
 N^.Next:=Nil; N^.Prev:=Nil; N^.Part:=Nil; N^.Epoch:=-1;
 CopyPiece:=N;
End;

Function CopyList(Q:PPiece):PPiece;
Var H,T,N:PPiece;
Begin
 H:=Nil; T:=Nil;
 While Q<>Nil Do Begin
  N:=CopyPiece(Q);
  N^.Prev:=T;
  If T<>Nil Then T^.Next:=N Else H:=N;
  T:=N;
  Q:=Q^.Next;
 End;
 CopyList:=H;
End;

Function MakeSnap:PSnap;
Var S:PSnap; I:Integer;
Begin
 MakeSnap:=Nil;
 If MaxAvail<LongInt(SizeOf(TSnap))+30000 Then Exit;
 New(S);
 S^.NMod:=ModelCount; S^.Cur:=CurModel; S^.Col:=CurColor;
 For I:=0 To MAXMOD-1 Do Begin
  S^.List[I]:=Nil; S^.Step[I]:=1; S^.Name[I]:='';
 End;
 For I:=0 To ModelCount-1 Do Begin
  S^.List[I]:=CopyList(Models[I].First);
  S^.Step[I]:=Models[I].CurStep;
  S^.Name[I]:=Models[I].Name;
 End;
 MakeSnap:=S;
End;

Procedure FreeSnap(S:PSnap);
Var I:Integer;
Begin
 If S=Nil Then Exit;
 For I:=0 To MAXMOD-1 Do FreeList(S^.List[I]);
 Dispose(S);
End;

Procedure ApplySnap(S:PSnap);
Var I:Integer; Q:PPiece;
Begin
 ClearAllModels;
 ModelCount:=S^.NMod; CurModel:=S^.Cur;
 If CurModel>=ModelCount Then CurModel:=0;
 For I:=0 To ModelCount-1 Do Begin
  Models[I].Used:=True;
  Models[I].Name:=S^.Name[I];
  Models[I].First:=S^.List[I];
  Models[I].CurStep:=S^.Step[I];
  Models[I].Count:=0;
  Models[I].Last:=Nil;
  Q:=S^.List[I];
  While Q<>Nil Do Begin Inc(Models[I].Count); Models[I].Last:=Q; Q:=Q^.Next; End;
  S^.List[I]:=Nil;
 End;
 Dispose(S);
End;

Procedure ClearRedo;
Var I:Integer;
Begin
 For I:=0 To RedoN-1 Do FreeSnap(RedoS[I]);
 RedoN:=0;
End;

Procedure PushUndo;
Var S:PSnap; I:Integer;
Begin
 S:=MakeSnap;
 If S=Nil Then Exit;
 If UndoN>=UNDO_MAX Then Begin
  FreeSnap(UndoS[0]);
  For I:=1 To UndoN-1 Do UndoS[I-1]:=UndoS[I];
  Dec(UndoN);
 End;
 UndoS[UndoN]:=S; Inc(UndoN);
 ClearRedo;
 Modified:=True;
End;

Procedure DoUndo;
Var S,C:PSnap;
Begin
 If UndoN=0 Then Exit;
 C:=MakeSnap;
 If C<>Nil Then Begin
  If RedoN>=UNDO_MAX Then Begin
   FreeSnap(RedoS[0]);
   Move(RedoS[1],RedoS[0],(UNDO_MAX-1)*SizeOf(PSnap));
   Dec(RedoN);
  End;
  RedoS[RedoN]:=C; Inc(RedoN);
 End;
 Dec(UndoN);
 S:=UndoS[UndoN];
 ApplySnap(S);
 Modified:=True;
End;

Procedure DoRedo;
Var S,C:PSnap;
Begin
 If RedoN=0 Then Exit;
 C:=MakeSnap;
 If C<>Nil Then Begin
  If UndoN>=UNDO_MAX Then Begin
   FreeSnap(UndoS[0]);
   Move(UndoS[1],UndoS[0],(UNDO_MAX-1)*SizeOf(PSnap));
   Dec(UndoN);
  End;
  UndoS[UndoN]:=C; Inc(UndoN);
 End;
 Dec(RedoN);
 S:=RedoS[RedoN];
 ApplySnap(S);
 Modified:=True;
End;

Procedure ClearHistory;
Var I:Integer;
Begin
 For I:=0 To UndoN-1 Do FreeSnap(UndoS[I]);
 UndoN:=0;
 ClearRedo;
End;

{ ====================================================================== }
{ Fichiers LDraw (.LDR, .MPD)                                            }
{ ====================================================================== }

Procedure NewDocument;
Var I:Integer;
Begin
 ClearHistory;
 ClearAllModels;
 I:=NewModel('MODELE.LDR');
 CurModel:=0;
 DocFile:='';
 Modified:=False;
End;

Function PieceLine(Q:PPiece):String;
Var S:String; I:Integer;
Begin
 S:='1 '+IntStr(Q^.Col)+' '+FmtNum(Q^.M.T.X)+' '+FmtNum(Q^.M.T.Y)+' '+FmtNum(Q^.M.T.Z);
 For I:=0 To 2 Do
  S:=S+' '+FmtNum(Q^.M.R[I,0])+' '+FmtNum(Q^.M.R[I,1])+' '+FmtNum(Q^.M.R[I,2]);
 PieceLine:=S+' '+Q^.Name;
End;

Function SaveDoc(Const Path:String):Boolean;
Var F:Text; I,S,MS:Integer; Q:PPiece; Multi:Boolean;
Begin
 SaveDoc:=False;
 {$I-}
 Assign(F,Path); Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 Multi:=(ExtOf(Path)='.MPD')Or(ModelCount>1);
 For I:=0 To ModelCount-1 Do Begin
  If(I=0)And(Not Multi)Then Begin
   WriteLn(F,'0 ',BaseOf(Path));
  End
   Else Begin
    WriteLn(F,'0 FILE ',Models[I].Name);
   End;
  WriteLn(F,'0 Name: ',Models[I].Name);
  WriteLn(F,'0 Author: LEOCAD');
  MS:=MaxStep(I);
  For S:=1 To MS Do Begin
   Q:=Models[I].First;
   While Q<>Nil Do Begin
    If Q^.Step=S Then WriteLn(F,PieceLine(Q));
    Q:=Q^.Next;
   End;
   WriteLn(F,'0 STEP');
  End;
  If Multi Then WriteLn(F,'0 NOFILE');
 End;
 Close(F);
 SaveDoc:=IOResult=0;
End;

Function LoadDoc(Const Path:String):Boolean;
Var
 F:Text;
 Line,T,T2,Nm:String;
 M,Step,I:Integer;
 Mt:TMat;
 V,Cl:Real;
 Seen,Ok:Boolean;
Begin
 LoadDoc:=False;
 {$I-}
 Assign(F,Path); Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 ClearHistory;
 ClearAllModels;
 M:=NewModel(BaseOf(Path));
 Step:=1; Seen:=False;
 While Not Eof(F) Do Begin
  {$I-}ReadLn(F,Line);{$I+}
  If IOResult<>0 Then Line:='';
  Line:=TrimStr(Line);
  If Line<>'' Then Begin
   T:=Tok(Line);
   If T='0' Then Begin
    T2:=UpStr(Tok(Line));
    If T2='FILE' Then Begin
     Nm:=TrimStr(Line);
     If(Not Seen)And(Models[M].Count=0)Then Models[M].Name:=Copy(Nm,1,40)
     Else Begin
      I:=NewModel(Nm);
      If I>=0 Then M:=I;
     End;
     Seen:=True; Step:=1;
    End
     Else If T2='STEP' Then Inc(Step);
   End
    Else If T='1' Then Begin
     Ok:=NumTok(Line,Cl);
     Ok:=Ok And NumTok(Line,Mt.T.X) And NumTok(Line,Mt.T.Y) And NumTok(Line,Mt.T.Z);
     For I:=0 To 2 Do
      Ok:=Ok And NumTok(Line,Mt.R[I,0]) And NumTok(Line,Mt.R[I,1]) And NumTok(Line,Mt.R[I,2]);
     Nm:=TrimStr(Line);
     If Ok And(Nm<>'')Then AddPiece(M,Nm,Round(Cl),Mt,Step);
    End;
  End;
 End;
 Close(F);
 For I:=0 To ModelCount-1 Do Models[I].CurStep:=MaxStep(I);
 CurModel:=0;
 DocFile:=Path;
 Modified:=False;
 LoadDoc:=True;
End;

{ ====================================================================== }
{ Rendu 3D logiciel                                                      }
{ ====================================================================== }

Const
 NEARZ=4;
 LX=-0.30; LY=0.72; LZ=-0.62;      { direction de la lumiere (espace vue) }

Var
 FP:Array[0..3] Of TVec;           { sommets en espace vue de la face courante }
 StudCos,StudSin:Array[0..7] Of Real;
 GhostPiece:PPiece;
 PolyOverflow:Boolean;
 GroundY:Real;

Function PolyAt(I:Integer):PPoly;
Begin
 PolyAt:=@PolyBlk[I Shr POLYSH]^[I And (PBSIZE-1)];
End;

Function NewPoly:PPoly;
Var B:Integer;
Begin
 NewPoly:=Nil;
 If PolyN>=PolyMax Then Begin PolyOverflow:=True; Exit; End;
 B:=PolyN Shr POLYSH;
 If PolyBlk[B]=Nil Then Begin
  If MaxAvail<LongInt(SizeOf(TPolyBlk))+24000 Then Begin
   PolyMax:=PolyN; PolyOverflow:=True; Exit;
  End;
  New(PolyBlk[B]);
 End;
 NewPoly:=PolyAt(PolyN);
 Inc(PolyN);
End;

Procedure FreePolyBlocks;
Var I:Integer;
Begin
 For I:=0 To MAXBLK-1 Do If PolyBlk[I]<>Nil Then Begin Dispose(PolyBlk[I]); PolyBlk[I]:=Nil; End;
 PolyN:=0;
End;

Procedure SetupCamera(Var V:TView);
Var Dir,F,U,R,Up:TVec; PY,YW,D:Real; W,H:Integer;
Begin
 W:=V.X2-V.X1+1; H:=V.Y2-V.Y1+1;
 YW:=V.Yaw*Pi/180; PY:=V.Pitch*Pi/180;
 VSet(Dir,Cos(PY)*Sin(YW),-Sin(PY),Cos(PY)*Cos(YW));
 D:=V.Dist;
 If Not V.Persp Then D:=4000;
 CamPos.X:=V.Tgt.X+Dir.X*D; CamPos.Y:=V.Tgt.Y+Dir.Y*D; CamPos.Z:=V.Tgt.Z+Dir.Z*D;
 VSet(F,-Dir.X,-Dir.Y,-Dir.Z);
 VSet(Up,0,-1,0);
 VCross(F,Up,R); VNorm(R);
 VCross(R,F,U); VNorm(U);
 CamM.R[0,0]:=R.X; CamM.R[0,1]:=R.Y; CamM.R[0,2]:=R.Z;
 CamM.R[1,0]:=U.X; CamM.R[1,1]:=U.Y; CamM.R[1,2]:=U.Z;
 CamM.R[2,0]:=F.X; CamM.R[2,1]:=F.Y; CamM.R[2,2]:=F.Z;
 CamM.T.X:=-VDot(R,CamPos); CamM.T.Y:=-VDot(U,CamPos); CamM.T.Z:=-VDot(F,CamPos);
 CamPersp:=V.Persp;
 CamFocal:=(H/2)/0.26795;
 CamOrtho:=V.Zoom;
 CamCX:=W/2; CamCY:=H/2;
End;

Procedure Proj(Const V:TVec;Var SX,SY:Integer);
Var X,Y,K:Real;
Begin
 If CamPersp Then Begin
  If V.Z<0.5 Then K:=CamFocal/0.5 Else K:=CamFocal/V.Z;
  X:=CamCX+V.X*K; Y:=CamCY-V.Y*K;
 End
  Else Begin
   X:=CamCX+V.X*CamOrtho; Y:=CamCY-V.Y*CamOrtho;
  End;
 If X>30000 Then X:=30000; If X<-30000 Then X:=-30000;
 If Y>30000 Then Y:=30000; If Y<-30000 Then Y:=-30000;
 SX:=Round(X); SY:=Round(Y);
End;

Function EdgeColor(Code:Integer;Sel:Boolean):Integer;
Begin
 If Sel Then Begin EdgeColor:=12; Exit; End;
 If Code=24 Then Begin
  EdgeColor:=0;
 End
  Else EdgeColor:=ShadeMap[ColIdx(Code),1];
End;

Procedure AddLine(Const A,B:TVec;Code:Integer;Sel:Boolean;Owner:Integer);
Var Pl:PPoly; PA,PB:TVec; T:Real; Z:Real;
Begin
 PA:=A; PB:=B;
 If CamPersp Then Begin
  If(PA.Z<NEARZ)And(PB.Z<NEARZ)Then Exit;
  If PA.Z<NEARZ Then Begin
   T:=(NEARZ-PA.Z)/(PB.Z-PA.Z);
   PA.X:=PA.X+(PB.X-PA.X)*T; PA.Y:=PA.Y+(PB.Y-PA.Y)*T; PA.Z:=NEARZ;
  End
  Else If PB.Z<NEARZ Then Begin
   T:=(NEARZ-PB.Z)/(PA.Z-PB.Z);
   PB.X:=PB.X+(PA.X-PB.X)*T; PB.Y:=PB.Y+(PA.Y-PB.Y)*T; PB.Z:=NEARZ;
  End;
 End;
 Pl:=NewPoly;
 If Pl=Nil Then Exit;
 Proj(PA,Pl^.X[0],Pl^.Y[0]);
 Proj(PB,Pl^.X[1],Pl^.Y[1]);
 If PA.Z>PB.Z Then Z:=PA.Z Else Z:=PB.Z;
 Pl^.Z:=Round(Z*4)-14;
 Pl^.Col:=EdgeColor(Code,Sel);
 Pl^.N:=2; Pl^.Fl:=0; Pl^.Owner:=Owner;
 If Sel Then Pl^.Z:=Pl^.Z-6;
End;

{ Ajoute la face FP[0..N-1] (espace vue) }
Procedure AddFace(N:Integer;Cull:Byte;Sg:Integer;Code:Integer;Owner:Integer);
Var
 I,S,CI:Integer;
 NX,NY,NZ,EX,EY,EZ,GX,GY,GZ,D,L,Lm,ZM:Real;
 Pl:PPoly;
Begin
 If CamPersp Then
  For I:=0 To N-1 Do If FP[I].Z<NEARZ Then Exit;
 EX:=FP[1].X-FP[0].X; EY:=FP[1].Y-FP[0].Y; EZ:=FP[1].Z-FP[0].Z;
 GX:=FP[2].X-FP[0].X; GY:=FP[2].Y-FP[0].Y; GZ:=FP[2].Z-FP[0].Z;
 NX:=EY*GZ-EZ*GY; NY:=EZ*GX-EX*GZ; NZ:=EX*GY-EY*GX;
 S:=Sg;
 If Cull=2 Then S:=-S;
 If Cull<>0 Then Begin
  If CamPersp Then D:=S*(NX*FP[0].X+NY*FP[0].Y+NZ*FP[0].Z) Else D:=S*NZ;
  If D>=0 Then Exit;
 End
  Else Begin
   If CamPersp Then D:=NX*FP[0].X+NY*FP[0].Y+NZ*FP[0].Z Else D:=NZ;
   If D<0 Then S:=1 Else S:=-1;
  End;
 L:=Sqrt(NX*NX+NY*NY+NZ*NZ);
 If L<EPS Then Exit;
 Lm:=S*(NX*LX+NY*LY+NZ*LZ)/L;
 If Lm<0 Then Lm:=0;
 CI:=ColIdx(Code);
 S:=Trunc((0.10+0.90*Lm)*NSHADE*0.999);
 If S<0 Then S:=0; If S>=NSHADE Then S:=NSHADE-1;
 Pl:=NewPoly;
 If Pl=Nil Then Exit;
 ZM:=FP[0].Z;
 For I:=0 To N-1 Do Begin
  Proj(FP[I],Pl^.X[I],Pl^.Y[I]);
  If FP[I].Z>ZM Then ZM:=FP[I].Z;
 End;
 Pl^.Z:=Round(ZM*4);
 Pl^.Col:=ShadeMap[CI,S];
 Pl^.N:=N;
 Pl^.Fl:=0;
 If ColTr[CI]Then Pl^.Fl:=1;
 If WireOn Then Pl^.Fl:=Pl^.Fl Or 4;
 Pl^.Owner:=Owner;
End;

Procedure DrawStud(Const M:TMat;Const Q:PPrim;Code:Integer;Sg:Integer;Owner:Integer;Sel:Boolean);
Var X:TMat; I,J:Integer; T,B:Array[0..7] Of TVec; V:TVec;
Begin
 MatMul(M,Q^.M,X);
 If Q^.Cull=1 Then Sg:=-Sg;
 If Q^.Inv Then Sg:=-Sg;
 If StudEff=2 Then Begin
  VSet(V,-5,-4,-5); MatApply(X,V,FP[0]);
  VSet(V,5,-4,-5); MatApply(X,V,FP[1]);
  VSet(V,5,-4,5); MatApply(X,V,FP[2]);
  VSet(V,-5,-4,5); MatApply(X,V,FP[3]);
  AddFace(4,1,Sg,Code,Owner);
  Exit;
 End;
 For I:=0 To 7 Do Begin
  VSet(V,StudCos[I],-4,StudSin[I]); MatApply(X,V,T[I]);
  VSet(V,StudCos[I],0,StudSin[I]); MatApply(X,V,B[I]);
 End;
 For I:=0 To 7 Do Begin
  J:=(I+1) And 7;
  FP[0]:=T[I]; FP[1]:=B[I]; FP[2]:=B[J]; FP[3]:=T[J];
  AddFace(4,1,Sg,Code,Owner);
 End;
 VSet(V,0,-4,0); MatApply(X,V,FP[0]);
 I:=0;
 While I<8 Do Begin
  FP[1]:=T[I]; FP[2]:=T[(I+1) And 7]; FP[3]:=T[(I+2) And 7];
  AddFace(4,1,Sg,Code,Owner);
  Inc(I,2);
 End;
 If EdgesOn Then
  For I:=0 To 7 Do AddLine(T[I],T[(I+1) And 7],24,Sel,Owner);
End;

Procedure RenderPart(P:PPart;Const M:TMat;Code:Integer;Sg:Integer;Owner:Integer;Sel:Boolean;Depth:Integer);
Var Q:PPrim; M2:TMat; C2,S2,I,N,PN:Integer; A,B:TVec;
Begin
 Q:=P^.Prims;
 While Q<>Nil Do Begin
  Case Q^.Kind Of
   PK_REF:If(Q^.Ref<>Nil)And(Depth<9)Then Begin
    MatMul(M,Q^.M,M2);
    C2:=Q^.Col; If(C2=16)Or(C2=24)Then C2:=Code;
    S2:=Sg;
    If Q^.Cull=1 Then S2:=-S2;
    If Q^.Inv Then S2:=-S2;
    RenderPart(Q^.Ref,M2,C2,S2,Owner,Sel,Depth+1);
   End;
   PK_STUD:If StudEff<3 Then DrawStud(M,Q,Code,Sg,Owner,Sel);
   PK_LINE:If EdgesOn Then Begin
    MatApply(M,Q^.P[0],A); MatApply(M,Q^.P[1],B);
    AddLine(A,B,Q^.Col,Sel,Owner);
   End;
   PK_TRI,PK_QUAD:Begin
    N:=Q^.Kind;
    For I:=0 To N-1 Do MatApply(M,Q^.P[I],FP[I]);
    C2:=Q^.Col; If(C2=16)Or(C2=24)Then C2:=Code;
    PN:=PolyN;
    AddFace(N,Q^.Cull,Sg,C2,Owner);
    If(Q^.Col<>16)And(PolyN>PN)Then
     PolyAt(PolyN-1)^.Z:=PolyAt(PolyN-1)^.Z-10;
   End;
  End;
  Q:=Q^.Next;
 End;
End;

Procedure RenderPiece(Q:PPiece;Const Parent:TMat;Sg0,PCode,Owner:Integer;Sel:Boolean;Depth:Integer);
Var T:TMat; Sg,C,S:Integer; P:PPart; Q2:PPiece;
Begin
 MatMul(Parent,Q^.M,T);
 Sg:=Sg0;
 If MatDet(Q^.M)<0 Then Sg:=-Sg;
 C:=Q^.Col; If(C=16)Or(C=24)Then C:=PCode;
 S:=FindModel(Q^.Name);
 If S>=0 Then Begin
  If Depth<6 Then Begin
   Q2:=Models[S].First;
   While Q2<>Nil Do Begin
    RenderPiece(Q2,T,Sg,C,Owner,Sel,Depth+1);
    Q2:=Q2^.Next;
   End;
  End;
 End
  Else Begin
   P:=PiecePart(Q);
   If P<>Nil Then RenderPart(P,T,C,Sg,Owner,Sel,0);
  End;
End;

Procedure BuildScene(WithGhost:Boolean);
Var Q:PPiece; I,N:Integer;
Begin
 PolyN:=0; PolyOverflow:=False; PolyMax:=MAXPOLY;
 N:=0;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin If PieceVisible(Q)Then Inc(N); Q:=Q^.Next; End;
 Case StudMode Of
  0:If N<=120 Then StudEff:=1 Else If N<=700 Then StudEff:=2 Else StudEff:=3;
  1:StudEff:=1;
  2:StudEff:=2;
 Else StudEff:=3;
 End;
 If(StudMode=0)And(CatCount=0)Then StudEff:=1;
 I:=0;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  Inc(I);
  If PieceVisible(Q)Then RenderPiece(Q,CamM,-1,7,I,Q^.Sel,0);
  Q:=Q^.Next;
 End;
 If WithGhost And(GhostPiece<>Nil)Then RenderPiece(GhostPiece,CamM,-1,7,0,False,0);
End;

Procedure QSortPolys(L,R:Integer);
Var I,J,T:Integer; Pv:LongInt;
Begin
 Repeat
  I:=L; J:=R;
  Pv:=PolyAt(PolyIdx^[(L+R) Shr 1])^.Z;
  Repeat
   While PolyAt(PolyIdx^[I])^.Z>Pv Do Inc(I);
   While PolyAt(PolyIdx^[J])^.Z<Pv Do Dec(J);
   If I<=J Then Begin
    T:=PolyIdx^[I]; PolyIdx^[I]:=PolyIdx^[J]; PolyIdx^[J]:=T;
    Inc(I); Dec(J);
   End;
  Until I>J;
  If L<J Then QSortPolys(L,J);
  L:=I;
 Until L>=R;
End;

Procedure SortScene;
Var I:Integer;
Begin
 For I:=0 To PolyN-1 Do PolyIdx^[I]:=I;
 If PolyN>1 Then QSortPolys(0,PolyN-1);
End;

{ Remplissage tramme (translucidite) d'un polygone convexe }
Procedure StipplePoly(Pl:PPoly;W,H:Integer);
Var
 I,J,Y,Y1,Y2,X,XL,XR,N:Integer;
 XA,YA,XB,YB:LongInt;
 T:LongInt;
Begin
 N:=Pl^.N;
 Y1:=Pl^.Y[0]; Y2:=Y1;
 For I:=1 To N-1 Do Begin
  If Pl^.Y[I]<Y1 Then Y1:=Pl^.Y[I];
  If Pl^.Y[I]>Y2 Then Y2:=Pl^.Y[I];
 End;
 If Y1<0 Then Y1:=0; If Y2>H-1 Then Y2:=H-1;
 For Y:=Y1 To Y2 Do Begin
  XL:=32000; XR:=-32000;
  For I:=0 To N-1 Do Begin
   J:=(I+1) Mod N;
   XA:=Pl^.X[I]; YA:=Pl^.Y[I]; XB:=Pl^.X[J]; YB:=Pl^.Y[J];
   If((YA<=Y)And(YB>=Y))Or((YB<=Y)And(YA>=Y))Then Begin
    If YA=YB Then Begin
     If XA<XL Then XL:=XA; If XB<XL Then XL:=XB;
     If XA>XR Then XR:=XA; If XB>XR Then XR:=XB;
    End
     Else Begin
      T:=XA+(XB-XA)*(Y-YA) Div (YB-YA);
      If T<XL Then XL:=T; If T>XR Then XR:=T;
     End;
   End;
  End;
  If XL<0 Then XL:=0; If XR>W-1 Then XR:=W-1;
  X:=XL;
  If((X+Y) And 1)<>0 Then Inc(X);
  While X<=XR Do Begin
   PutPixel(X,Y,Pl^.Col);
   Inc(X,2);
  End;
 End;
End;

Procedure PaintScene(W,H:Integer);
Var K,I,LastCol:Integer; Pl:PPoly; Pts:Array[0..3] Of PointType;
Begin
 LastCol:=-1;
 For K:=0 To PolyN-1 Do Begin
  Pl:=PolyAt(PolyIdx^[K]);
  If Pl^.N=2 Then Begin
   SetColor(Pl^.Col);
   Line(Pl^.X[0],Pl^.Y[0],Pl^.X[1],Pl^.Y[1]);
  End
   Else Begin
    For I:=0 To Pl^.N-1 Do Begin Pts[I].X:=Pl^.X[I]; Pts[I].Y:=Pl^.Y[I]; End;
    If(Pl^.Fl And 4)<>0 Then Begin
     SetColor(Pl^.Col);
     For I:=0 To Pl^.N-1 Do
      Line(Pts[I].X,Pts[I].Y,Pts[(I+1) Mod Pl^.N].X,Pts[(I+1) Mod Pl^.N].Y);
    End
     Else If(Pl^.Fl And 1)<>0 Then Begin
      StipplePoly(Pl,W,H);
      SetColor(Pl^.Col);
      For I:=0 To Pl^.N-1 Do
       Line(Pts[I].X,Pts[I].Y,Pts[(I+1) Mod Pl^.N].X,Pts[(I+1) Mod Pl^.N].Y);
     End
     Else Begin
      If LastCol<>Pl^.Col Then Begin
       SetFillStyle(SolidFill,Pl^.Col);
       SetColor(Pl^.Col);
       LastCol:=Pl^.Col;
      End;
      FillPoly(Pl^.N,Pts);
     End;
   End;
 End;
End;

{ Trait 3D (espace monde) }
Procedure Line3(Const A,B:TVec;Col:Integer);
Var VA,VB:TVec; X1,Y1,X2,Y2:Integer; T:Real;
Begin
 MatApply(CamM,A,VA); MatApply(CamM,B,VB);
 If CamPersp Then Begin
  If(VA.Z<NEARZ)And(VB.Z<NEARZ)Then Exit;
  If VA.Z<NEARZ Then Begin
   T:=(NEARZ-VA.Z)/(VB.Z-VA.Z);
   VA.X:=VA.X+(VB.X-VA.X)*T; VA.Y:=VA.Y+(VB.Y-VA.Y)*T; VA.Z:=NEARZ;
  End
  Else If VB.Z<NEARZ Then Begin
   T:=(NEARZ-VB.Z)/(VA.Z-VB.Z);
   VB.X:=VB.X+(VA.X-VB.X)*T; VB.Y:=VB.Y+(VA.Y-VB.Y)*T; VB.Z:=NEARZ;
  End;
 End;
 Proj(VA,X1,Y1); Proj(VB,X2,Y2);
 SetColor(Col);
 Line(X1,Y1,X2,Y2);
End;

Procedure ComputeGround;
Var Mn,Mx:TVec; I:TMat;
Begin
 MatIdent(I);
 BoxEmpty(Mn,Mx);
 ModelBounds(CurModel,I,True,False,Mn,Mx,0);
 If BoxIsEmpty(Mn,Mx)Then GroundY:=0 Else GroundY:=Mx.Y;
End;

Procedure DrawGrid;
Var Mn,Mx:TVec; I:TMat; X0,X1,Z0,Z1,K:Integer; A,B:TVec; C:Integer;
Begin
 MatIdent(I);
 BoxEmpty(Mn,Mx);
 ModelBounds(CurModel,I,True,False,Mn,Mx,0);
 If BoxIsEmpty(Mn,Mx)Then Begin VSet(Mn,0,0,0); VSet(Mx,0,0,0); End;
 If Mn.X>-160 Then Mn.X:=-160; If Mx.X<160 Then Mx.X:=160;
 If Mn.Z>-160 Then Mn.Z:=-160; If Mx.Z<160 Then Mx.Z:=160;
 X0:=Trunc((Mn.X-60)/20)*20; X1:=Trunc((Mx.X+60)/20)*20;
 Z0:=Trunc((Mn.Z-60)/20)*20; Z1:=Trunc((Mx.Z+60)/20)*20;
 If X1-X0>1600 Then Begin X0:=-800; X1:=800; End;
 If Z1-Z0>1600 Then Begin Z0:=-800; Z1:=800; End;
 If GroundY=0 Then GroundY:=0;
 K:=X0;
 While K<=X1 Do Begin
  VSet(A,K,GroundY,Z0); VSet(B,K,GroundY,Z1);
  If K Mod 200=0 Then C:=8 Else C:=7;
  Line3(A,B,C);
  Inc(K,20);
 End;
 K:=Z0;
 While K<=Z1 Do Begin
  VSet(A,X0,GroundY,K); VSet(B,X1,GroundY,K);
  If K Mod 200=0 Then C:=8 Else C:=7;
  Line3(A,B,C);
  Inc(K,20);
 End;
End;

{ Boite orientee de la piece (contour de selection) }
Procedure DrawPieceBox(Q:PPiece;Col:Integer);
Var P:PPart; A,B,V:TVec; C:Array[0..7] Of TVec; I:Integer; Mn,Mx:TVec;
Begin
 If FindModel(Q^.Name)>=0 Then Begin
  PieceBounds(Q,False,Mn,Mx);
  A:=Mn; B:=Mx;
  For I:=0 To 7 Do Begin
   If I And 1=0 Then V.X:=A.X Else V.X:=B.X;
   If I And 2=0 Then V.Y:=A.Y Else V.Y:=B.Y;
   If I And 4=0 Then V.Z:=A.Z Else V.Z:=B.Z;
   C[I]:=V;
  End;
 End
  Else Begin
   P:=PiecePart(Q);
   If P=Nil Then Exit;
   CalcBBox(P);
   A:=P^.AMin; B:=P^.AMax;
   For I:=0 To 7 Do Begin
    If I And 1=0 Then V.X:=A.X Else V.X:=B.X;
    If I And 2=0 Then V.Y:=A.Y Else V.Y:=B.Y;
    If I And 4=0 Then V.Z:=A.Z Else V.Z:=B.Z;
    MatApply(Q^.M,V,C[I]);
   End;
  End;
 For I:=0 To 3 Do Begin
  Line3(C[I*2],C[I*2+1],Col);
 End;
 Line3(C[0],C[2],Col); Line3(C[1],C[3],Col); Line3(C[4],C[6],Col); Line3(C[5],C[7],Col);
 Line3(C[0],C[4],Col); Line3(C[1],C[5],Col); Line3(C[2],C[6],Col); Line3(C[3],C[7],Col);
End;

Procedure DrawGizmo(Var V:TView);
Var OX,OY,I:Integer; Ax:TVec; D:Array[0..2] Of TVec; Cols:Array[0..2] Of Integer; Lb:Array[0..2] Of Char;
Begin
 OX:=34; OY:=V.Y2-V.Y1-30;
 Cols[0]:=12; Cols[1]:=10; Cols[2]:=9;
 Lb[0]:='X'; Lb[1]:='Y'; Lb[2]:='Z';
 For I:=0 To 2 Do Begin
  VSet(Ax,0,0,0);
  If I=0 Then Ax.X:=1 Else If I=1 Then Ax.Y:=1 Else Ax.Z:=1;
  SetColor(Cols[I]);
  Line(OX,OY,OX+Round(CamM.R[0,0]*Ax.X*24+CamM.R[0,1]*Ax.Y*24+CamM.R[0,2]*Ax.Z*24),
             OY-Round(CamM.R[1,0]*Ax.X*24+CamM.R[1,1]*Ax.Y*24+CamM.R[1,2]*Ax.Z*24));
  OutTextXY(OX+Round(CamM.R[0,0]*Ax.X*30+CamM.R[0,1]*Ax.Y*30+CamM.R[0,2]*Ax.Z*30)-3,
            OY-Round(CamM.R[1,0]*Ax.X*30+CamM.R[1,1]*Ax.Y*30+CamM.R[1,2]*Ax.Z*30)-4,Lb[I]);
 End;
End;

Procedure ViewSelectionBoxes;
Var Q:PPiece;
Begin
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel And PieceVisible(Q)Then DrawPieceBox(Q,12);
  Q:=Q^.Next;
 End;
End;

{ Dessine une vue (rectangle ecran de la vue) }
Procedure RenderView(Var V:TView;Active:Boolean;WithGhost:Boolean);
Var W,H:Integer;
Begin
 W:=V.X2-V.X1+1; H:=V.Y2-V.Y1+1;
 If(W<8)Or(H<8)Then Exit;
 If CacheCount>CACHE_MAX Then FlushCache;
 SetViewPort(V.X1,V.Y1,V.X2,V.Y2,True);
 SetFillStyle(SolidFill,15);
 Bar(0,0,W-1,H-1);
 SetupCamera(V);
 ComputeGround;
 If GridOn Then DrawGrid;
 BuildScene(WithGhost);
 SortScene;
 PaintScene(W,H);
 ViewSelectionBoxes;
 DrawGizmo(V);
 SetColor(8);
 OutTextXY(4,4,Fx(V.Name));
 If PolyOverflow Then Begin SetColor(4); OutTextXY(4,14,Fx('M\emoire gr.')); End;
 SetViewPort(0,0,ScreenW-1,ScreenH-1,False);
 If Active And(ViewCount>1)Then Begin
  SetColor(UI_SEL);
  Rectangle(V.X1,V.Y1,V.X2,V.Y2);
  Rectangle(V.X1+1,V.Y1+1,V.X2-1,V.Y2-1);
 End
  Else Begin
   SetColor(UI_SH);
   Rectangle(V.X1,V.Y1,V.X2,V.Y2);
  End;
End;

{ Point dans polygone (coordonnees entieres) }
Function PolyHit(Pl:PPoly;PX,PY:Integer):Boolean;
Var I,J:Integer; C:Boolean; XI,YI,XJ,YJ:LongInt;
Begin
 C:=False;
 J:=Pl^.N-1;
 For I:=0 To Pl^.N-1 Do Begin
  XI:=Pl^.X[I]; YI:=Pl^.Y[I]; XJ:=Pl^.X[J]; YJ:=Pl^.Y[J];
  If((YI>PY)<>(YJ>PY))Then
   If PX<(XJ-XI)*(PY-YI) Div (YJ-YI)+XI Then C:=Not C;
  J:=I;
 End;
 PolyHit:=C;
End;

{ Piece sous le pointeur (coordonnees relatives a la vue) ; 0 si aucune }
Function PickPiece(Var V:TView;PX,PY:Integer):Integer;
Var K:Integer; Pl:PPoly;
Begin
 PickPiece:=0;
 SetupCamera(V);
 BuildScene(False);
 SortScene;
 For K:=PolyN-1 DownTo 0 Do Begin
  Pl:=PolyAt(PolyIdx^[K]);
  If(Pl^.N>=3)And(Pl^.Owner>0)Then
   If PolyHit(Pl,PX,PY)Then Begin PickPiece:=Pl^.Owner; Exit; End;
 End;
End;

Function PieceByIndex(N:Integer):PPiece;
Var Q:PPiece; I:Integer;
Begin
 Q:=Models[CurModel].First; I:=1;
 While(Q<>Nil)And(I<N)Do Begin Q:=Q^.Next; Inc(I); End;
 PieceByIndex:=Q;
End;

{ Rayon ecran -> monde }
Procedure ScreenRay(Var V:TView;PX,PY:Integer;Var O,D:TVec);
Var R,U,F:TVec; DX,DY:Real;
Begin
 SetupCamera(V);
 VSet(R,CamM.R[0,0],CamM.R[0,1],CamM.R[0,2]);
 VSet(U,CamM.R[1,0],CamM.R[1,1],CamM.R[1,2]);
 VSet(F,CamM.R[2,0],CamM.R[2,1],CamM.R[2,2]);
 DX:=PX-CamCX; DY:=-(PY-CamCY);
 If CamPersp Then Begin
  O:=CamPos;
  D.X:=F.X+R.X*DX/CamFocal+U.X*DY/CamFocal;
  D.Y:=F.Y+R.Y*DX/CamFocal+U.Y*DY/CamFocal;
  D.Z:=F.Z+R.Z*DX/CamFocal+U.Z*DY/CamFocal;
  VNorm(D);
 End
  Else Begin
   O.X:=CamPos.X+(R.X*DX+U.X*DY)/CamOrtho;
   O.Y:=CamPos.Y+(R.Y*DX+U.Y*DY)/CamOrtho;
   O.Z:=CamPos.Z+(R.Z*DX+U.Z*DY)/CamOrtho;
   D:=F;
  End;
End;

{ Intersection du rayon avec le plan horizontal Y=Y0 }
Function RayPlaneY(Const O,D:TVec;Y0:Real;Var X,Z:Real):Boolean;
Var T:Real;
Begin
 RayPlaneY:=False;
 If Abs(D.Y)<0.0001 Then Exit;
 T:=(Y0-O.Y)/D.Y;
 If(T<0)And CamPersp Then Exit;
 X:=O.X+D.X*T; Z:=O.Z+D.Z*T;
 RayPlaneY:=True;
End;

{ Position ecran d'un point monde (vue deja configuree) }
Procedure WorldToScreen(Const P:TVec;Var SX,SY:Integer;Var Vis:Boolean);
Var O:TVec;
Begin
 MatApply(CamM,P,O);
 Vis:=(Not CamPersp)Or(O.Z>=NEARZ);
 Proj(O,SX,SY);
End;

{ ====================================================================== }
{ Vues et camera                                                         }
{ ====================================================================== }

Var
 VX1,VY1,VX2,VY2:Integer;     { zone des vues }
 DockX,PanY1,PanY2,TabY,ColY,ColY2:Integer;
 FullRedraw:Boolean;

Procedure ViewPreset(Var V:TView;K:Integer);
Begin
 Case K Of
  0:Begin V.Persp:=True; V.Yaw:=140; V.Pitch:=28; V.Name:='Vue 3D'; End;
  1:Begin V.Persp:=False; V.Yaw:=180; V.Pitch:=0; V.Name:='Avant'; End;
  2:Begin V.Persp:=False; V.Yaw:=0; V.Pitch:=0; V.Name:=Fx('Arri\ere'); End;
  3:Begin V.Persp:=False; V.Yaw:=-90; V.Pitch:=0; V.Name:='Gauche'; End;
  4:Begin V.Persp:=False; V.Yaw:=90; V.Pitch:=0; V.Name:='Droite'; End;
  5:Begin V.Persp:=False; V.Yaw:=180; V.Pitch:=89.5; V.Name:='Dessus'; End;
  6:Begin V.Persp:=False; V.Yaw:=180; V.Pitch:=-89.5; V.Name:='Dessous'; End;
 End;
End;

Procedure LayoutScreen;
Begin
 VX1:=0; VY1:=MENU_H+TB_H+TAB_H;
 VX2:=ScreenW-DOCK_W-4; VY2:=ScreenH-ST_H-1;
 DockX:=ScreenW-DOCK_W;
 PanY1:=VY1; PanY2:=VY1+232;
 TabY:=PanY2+2;
 ColY:=TabY+19; ColY2:=VY2;
End;

Procedure LayoutViews;
Var I,W,H,MX2,MY2:Integer;
Begin
 If ViewCount=1 Then Begin
  Views[ActiveView].X1:=VX1; Views[ActiveView].Y1:=VY1;
  Views[ActiveView].X2:=VX2; Views[ActiveView].Y2:=VY2;
 End
  Else Begin
   MX2:=(VX1+VX2) Div 2; MY2:=(VY1+VY2) Div 2;
   Views[0].X1:=VX1; Views[0].Y1:=VY1; Views[0].X2:=MX2-1; Views[0].Y2:=MY2-1;
   Views[1].X1:=MX2; Views[1].Y1:=VY1; Views[1].X2:=VX2; Views[1].Y2:=MY2-1;
   Views[2].X1:=VX1; Views[2].Y1:=MY2; Views[2].X2:=MX2-1; Views[2].Y2:=VY2;
   Views[3].X1:=MX2; Views[3].Y1:=MY2; Views[3].X2:=VX2; Views[3].Y2:=VY2;
  End;
End;

Procedure ZoomFit(Var V:TView);
Var Mn,Mx:TVec; I:TMat; R:Real; W,H:Integer;
Begin
 MatIdent(I);
 BoxEmpty(Mn,Mx);
 ModelBounds(CurModel,I,False,False,Mn,Mx,0);
 If BoxIsEmpty(Mn,Mx)Then Begin
  VSet(V.Tgt,0,-40,0); R:=260;
 End
  Else Begin
   VSet(V.Tgt,(Mn.X+Mx.X)/2,(Mn.Y+Mx.Y)/2,(Mn.Z+Mx.Z)/2);
   R:=Sqrt(Sqr(Mx.X-Mn.X)+Sqr(Mx.Y-Mn.Y)+Sqr(Mx.Z-Mn.Z))/2;
   If R<60 Then R:=60;
  End;
 W:=V.X2-V.X1+1; H:=V.Y2-V.Y1+1;
 V.Dist:=R/0.2588*1.08;
 If W<H Then V.Dist:=V.Dist*H/W;
 If Min(W,H)>0 Then V.Zoom:=(Min(W,H)/2)/R*0.92 Else V.Zoom:=1;
End;

Procedure InitViews;
Var I:Integer;
Begin
 For I:=0 To MAXVIEW-1 Do Begin
  Views[I].Dist:=800; Views[I].Zoom:=1; VSet(Views[I].Tgt,0,-40,0);
  Views[I].X1:=0; Views[I].Y1:=0; Views[I].X2:=100; Views[I].Y2:=100;
 End;
 ViewPreset(Views[0],0);
 ViewPreset(Views[1],5);
 ViewPreset(Views[2],4);
 ViewPreset(Views[3],1);
 ViewCount:=1; ActiveView:=0;
 LayoutViews;
 For I:=0 To MAXVIEW-1 Do ZoomFit(Views[I]);
End;

Procedure FitAllViews;
Var I:Integer;
Begin
 LayoutViews;
 For I:=0 To MAXVIEW-1 Do Begin
  If ViewCount=1 Then Begin
   If I<>ActiveView Then Begin
    Views[I].X1:=VX1; Views[I].Y1:=VY1; Views[I].X2:=VX2; Views[I].Y2:=VY2;
   End;
  End;
  ZoomFit(Views[I]);
 End;
End;

Procedure PanView(Var V:TView;DX,DY:Integer);
Var S:Real; H:Integer;
Begin
 SetupCamera(V);
 H:=V.Y2-V.Y1+1;
 If V.Persp Then S:=2*V.Dist*0.26795/H Else S:=1/V.Zoom;
 V.Tgt.X:=V.Tgt.X-CamM.R[0,0]*DX*S+CamM.R[1,0]*DY*S;
 V.Tgt.Y:=V.Tgt.Y-CamM.R[0,1]*DX*S+CamM.R[1,1]*DY*S;
 V.Tgt.Z:=V.Tgt.Z-CamM.R[0,2]*DX*S+CamM.R[1,2]*DY*S;
End;

Procedure ZoomView(Var V:TView;F:Real);
Begin
 If V.Persp Then Begin
  V.Dist:=V.Dist*F;
  If V.Dist<40 Then V.Dist:=40; If V.Dist>60000 Then V.Dist:=60000;
 End
  Else Begin
   V.Zoom:=V.Zoom/F;
   If V.Zoom<0.02 Then V.Zoom:=0.02; If V.Zoom>40 Then V.Zoom:=40;
  End;
End;

Procedure OrbitView(Var V:TView;DX,DY:Integer);
Begin
 V.Yaw:=V.Yaw-DX*0.6;
 V.Pitch:=V.Pitch+DY*0.6;
 If V.Pitch>89.5 Then V.Pitch:=89.5;
 If V.Pitch<-89.5 Then V.Pitch:=-89.5;
 While V.Yaw>=360 Do V.Yaw:=V.Yaw-360;
 While V.Yaw<0 Do V.Yaw:=V.Yaw+360;
 If(V.Name='Avant')Or(V.Name='Droite')Or(V.Name='Gauche')Or(V.Name='Dessus')Or(V.Name='Dessous')Then V.Name:='Vue 3D';
End;

{ ====================================================================== }
{ Menus                                                                  }
{ ====================================================================== }

Procedure MI(M,I:Integer;Const Cap,Short:String);
Begin
 Menus[M].Items[I].Caption:=Fx(Cap);
 Menus[M].Items[I].Shortcut:=Short;
 Menus[M].Items[I].Enabled:=True;
 Menus[M].Items[I].Checked:=False;
 Menus[M].Items[I].Separator:=(Cap='-');
 If M>=0 Then If I>=Menus[M].ItemCount Then Menus[M].ItemCount:=I+1;
End;

Procedure InitMenus;
Var I,J:Integer;
Begin
 For I:=0 To MENU_COUNT-1 Do Begin
  Menus[I].ItemCount:=0;
  For J:=0 To 23 Do Begin
   Menus[I].Items[J].Caption:=''; Menus[I].Items[J].Shortcut:='';
   Menus[I].Items[J].Enabled:=True; Menus[I].Items[J].Checked:=False;
   Menus[I].Items[J].Separator:=False;
  End;
 End;
 Menus[M_FILE].Title:='Fichier';
 MI(M_FILE,0,'Nouveau','Ctrl+N');
 MI(M_FILE,1,'Ouvrir...','Ctrl+O');
 MI(M_FILE,2,'Enregistrer','Ctrl+S');
 MI(M_FILE,3,'Enregistrer sous...','');
 MI(M_FILE,4,'-','');
 MI(M_FILE,5,'Exporter l''image BMP...','');
 MI(M_FILE,6,'Exporter liste des pi\eces...','');
 MI(M_FILE,7,'-','');
 MI(M_FILE,8,'Informations du mod\gle...','');
 MI(M_FILE,9,'R\eindexer la biblioth\gque','');
 MI(M_FILE,10,'-','');
 MI(M_FILE,11,'Quitter','F10');

 Menus[M_EDIT].Title:=Fx('\Edition');
 MI(M_EDIT,0,'Annuler','Ctrl+Z');
 MI(M_EDIT,1,'R\etablir','Ctrl+Y');
 MI(M_EDIT,2,'-','');
 MI(M_EDIT,3,'Couper','Ctrl+X');
 MI(M_EDIT,4,'Copier','Ctrl+C');
 MI(M_EDIT,5,'Coller','Ctrl+V');
 MI(M_EDIT,6,'Supprimer','Suppr');
 MI(M_EDIT,7,'-','');
 MI(M_EDIT,8,'Tout s\electionner','Ctrl+A');
 MI(M_EDIT,9,'Aucune s\election','Ctrl+D');
 MI(M_EDIT,10,'Inverser la s\election','');
 MI(M_EDIT,11,'M\eme couleur','');
 MI(M_EDIT,12,'M\eme pi\ece','');

 Menus[M_VIEW].Title:='Affichage';
 MI(M_VIEW,0,'Une vue / quatre vues','V');
 MI(M_VIEW,1,'Perspective / ortho','P');
 MI(M_VIEW,2,'-','');
 MI(M_VIEW,3,'Vue 3D','0');
 MI(M_VIEW,4,'Avant','1');
 MI(M_VIEW,5,'Arri\ere','2');
 MI(M_VIEW,6,'Gauche','3');
 MI(M_VIEW,7,'Droite','4');
 MI(M_VIEW,8,'Dessus','5');
 MI(M_VIEW,9,'Dessous','6');
 MI(M_VIEW,10,'-','');
 MI(M_VIEW,11,'Zoom avant','+');
 MI(M_VIEW,12,'Zoom arri\ere','-');
 MI(M_VIEW,13,'Ajuster \a la fen\hetre','F');
 MI(M_VIEW,14,'-','');
 MI(M_VIEW,15,'Grille','G');
 MI(M_VIEW,16,'Ar\etes','E');
 MI(M_VIEW,17,'Mode filaire','W');
 MI(M_VIEW,18,'D\etail des tenons','T');
 MI(M_VIEW,19,'-','');
 MI(M_VIEW,20,'Panneau Pi\eces','F2');
 MI(M_VIEW,21,'Panneau Propri\et\es','F3');
 MI(M_VIEW,22,'Panneau Chronologie','F4');

 Menus[M_PIECE].Title:=Fx('Pi\ece');
 MI(M_PIECE,0,'Ins\erer la pi\ece choisie','Ins');
 MI(M_PIECE,1,'Dupliquer','Ctrl+B');
 MI(M_PIECE,2,'-','');
 MI(M_PIECE,3,'Monter d''une plaque','PgUp');
 MI(M_PIECE,4,'Descendre d''une plaque','PgDn');
 MI(M_PIECE,5,'Monter d''une brique','Home');
 MI(M_PIECE,6,'Descendre d''une brique','End');
 MI(M_PIECE,7,'-','');
 MI(M_PIECE,8,'Pivoter X +90','x');
 MI(M_PIECE,9,'Pivoter X -90','X');
 MI(M_PIECE,10,'Pivoter Y +90','y');
 MI(M_PIECE,11,'Pivoter Y -90','Y');
 MI(M_PIECE,12,'Pivoter Z +90','z');
 MI(M_PIECE,13,'Pivoter Z -90','Z');
 MI(M_PIECE,14,'-','');
 MI(M_PIECE,15,'Appliquer la couleur courante','');
 MI(M_PIECE,16,'Masquer la s\election','H');
 MI(M_PIECE,17,'Tout afficher','');

 Menus[M_STEP].Title:=Fx('\Etapes');
 MI(M_STEP,0,'\Etape suivante','.');
 MI(M_STEP,1,'\Etape pr\ec\edente',',');
 MI(M_STEP,2,'Premi\ere \etape','[');
 MI(M_STEP,3,'Derni\ere \etape',']');
 MI(M_STEP,4,'-','');
 MI(M_STEP,5,'Ins\erer une \etape','');
 MI(M_STEP,6,'Supprimer l''\etape','');
 MI(M_STEP,7,'S\election vers \etape courante','');

 Menus[M_SUB].Title:=Fx('Sous-mod\gle');
 MI(M_SUB,0,'Nouveau sous-mod\gle...','');
 MI(M_SUB,1,'Cr\eer depuis la s\election...','');
 MI(M_SUB,2,'Ins\erer un sous-mod\gle...','');
 MI(M_SUB,3,'-','');
 MI(M_SUB,4,'Modifier un sous-mod\gle...','');
 MI(M_SUB,5,'Mod\gle principal','M');
 MI(M_SUB,6,'Supprimer le sous-mod\gle','');

 Menus[M_HELP].Title:='Aide';
 MI(M_HELP,0,'Raccourcis clavier','F1');
 MI(M_HELP,1,'A propos de LEOCAD','');
 Menus[M_FILE].Width:=216;
 Menus[M_EDIT].Width:=212;
 Menus[M_VIEW].Width:=228;
 Menus[M_PIECE].Width:=252;
 Menus[M_STEP].Width:=244;
 Menus[M_SUB].Width:=252;
 Menus[M_HELP].Width:=188;
End;

Procedure UpdateMenuChecks;
Begin
 Menus[M_VIEW].Items[0].Checked:=ViewCount=4;
 Menus[M_VIEW].Items[1].Checked:=Views[ActiveView].Persp;
 Menus[M_VIEW].Items[15].Checked:=GridOn;
 Menus[M_VIEW].Items[16].Checked:=EdgesOn;
 Menus[M_VIEW].Items[17].Checked:=WireOn;
 Menus[M_VIEW].Items[18].Checked:=StudMode<>0;
 Menus[M_VIEW].Items[20].Checked:=PanelSel=PN_PARTS;
 Menus[M_VIEW].Items[21].Checked:=PanelSel=PN_PROPS;
 Menus[M_VIEW].Items[22].Checked:=PanelSel=PN_TIME;
 Menus[M_EDIT].Items[0].Enabled:=UndoN>0;
 Menus[M_EDIT].Items[1].Enabled:=RedoN>0;
 Menus[M_EDIT].Items[5].Enabled:=ClipN>0;
 Menus[M_SUB].Items[5].Enabled:=CurModel<>0;
 Menus[M_SUB].Items[6].Enabled:=CurModel<>0;
 Menus[M_SUB].Items[4].Enabled:=ModelCount>1;
 Menus[M_SUB].Items[2].Enabled:=ModelCount>1;
End;

Procedure DrawMenuBar;
Var I,X:Integer;
Begin
 Box(0,0,ScreenW-1,MENU_H-1,UI_BG);
 SetColor(UI_SH);
 Line(0,MENU_H-1,ScreenW-1,MENU_H-1);
 X:=8;
 For I:=0 To MENU_COUNT-1 Do Begin
  Menus[I].X:=X;
  If MenuActive And(ActiveMenu=I)Then Begin
   Box(X-4,1,X+TextWidth(Menus[I].Title)+3,MENU_H-3,UI_SEL);
   TxtOut(X,5,Menus[I].Title,15);
  End
   Else TxtOut(X,5,Menus[I].Title,UI_DK);
  X:=X+TextWidth(Menus[I].Title)+16;
 End;
End;

Function MenuH(M:Integer):Integer;
Begin
 MenuH:=Menus[M].ItemCount*16+6;
End;

Var MenuLeftX:Integer;

Procedure CalcMenuLeft(M:Integer);
Begin
 MenuLeftX:=Menus[M].X-4;
 If MenuLeftX+Menus[M].Width>=ScreenW-2 Then MenuLeftX:=ScreenW-Menus[M].Width-3;
 If MenuLeftX<0 Then MenuLeftX:=0;
End;

Procedure DrawMenu(M:Integer);
Var I,X,Y,W,H:Integer;
Begin
 If(M<0)Or(M>=MENU_COUNT)Then Exit;
 X:=MenuLeftX;
 Y:=MENU_H; W:=Menus[M].Width; H:=MenuH(M);
 Raised(X,Y,X+W,Y+H);
 For I:=0 To Menus[M].ItemCount-1 Do Begin
  If Menus[M].Items[I].Separator Then Begin
   SetColor(UI_SH); Line(X+4,Y+3+I*16+8,X+W-4,Y+3+I*16+8);
   SetColor(UI_HI); Line(X+4,Y+3+I*16+9,X+W-4,Y+3+I*16+9);
  End
   Else Begin
    If ActiveMenuItem=I Then Begin
     Box(X+3,Y+3+I*16,X+W-3,Y+3+I*16+15,UI_SEL);
     SetColor(15);
    End
     Else If Menus[M].Items[I].Enabled Then SetColor(UI_DK) Else SetColor(UI_SH);
    If Menus[M].Items[I].Checked Then OutTextXY(X+7,Y+3+I*16+4,#251);
    OutTextXY(X+20,Y+3+I*16+4,Menus[M].Items[I].Caption);
    If Menus[M].Items[I].Shortcut<>'' Then
     OutTextXY(X+W-6-TextWidth(Menus[M].Items[I].Shortcut),Y+3+I*16+4,Menus[M].Items[I].Shortcut);
   End;
 End;
End;

Function MenuBarHit(PX,PY:Integer):Integer;
Var I:Integer;
Begin
 MenuBarHit:=-1;
 If PY>=MENU_H Then Exit;
 For I:=0 To MENU_COUNT-1 Do
  If(PX>=Menus[I].X-4)And(PX<=Menus[I].X+TextWidth(Menus[I].Title)+3)Then Begin MenuBarHit:=I; Exit; End;
End;

Function MenuItemHit(PX,PY,M:Integer):Integer;
Var X,I:Integer;
Begin
 MenuItemHit:=-1;
 If(M<0)Or(M>=MENU_COUNT)Then Exit;
 X:=MenuLeftX;
 If(PX<X)Or(PX>X+Menus[M].Width)Then Exit;
 If(PY<MENU_H+3)Or(PY>=MENU_H+3+Menus[M].ItemCount*16)Then Exit;
 I:=(PY-MENU_H-3) Div 16;
 If(I>=0)And(I<Menus[M].ItemCount)Then MenuItemHit:=I;
End;

{ ====================================================================== }
{ Barre d'outils, onglets, barre d'etat                                  }
{ ====================================================================== }

Const
 TBN=18;

Function TBX(I:Integer):Integer;
Var X:Integer;
Begin
 X:=4+I*25;
 If I>=3 Then Inc(X,6);
 If I>=5 Then Inc(X,6);
 If I>=10 Then Inc(X,6);
 If I>=14 Then Inc(X,6);
 TBX:=X;
End;

Function TBHit(PX,PY:Integer):Integer;
Var I:Integer;
Begin
 TBHit:=-1;
 If(PY<MENU_H)Or(PY>=MENU_H+TB_H)Then Exit;
 For I:=0 To TBN-1 Do
  If(PX>=TBX(I))And(PX<TBX(I)+24)Then Begin TBHit:=I; Exit; End;
End;

Function TBHint(I:Integer):String;
Begin
 Case I Of
  0:TBHint:='Nouveau mod\gle';
  1:TBHint:='Ouvrir un fichier LDR / MPD';
  2:TBHint:='Enregistrer le mod\gle';
  3:TBHint:='Annuler';
  4:TBHint:='R\etablir';
  5:TBHint:='Outil de s\election et d\eplacement';
  6:TBHint:='Ins\erer la pi\ece choisie';
  7:TBHint:='Orbite (rotation de la cam\era)';
  8:TBHint:='Panoramique';
  9:TBHint:='Zoom (glisser verticalement)';
  10:TBHint:='Afficher la grille';
  11:TBHint:='Mode filaire / ombr\e';
  12:TBHint:='Une vue / quatre vues';
  13:TBHint:='Ajuster le zoom \a la fen\hetre';
  14:TBHint:='Premi\ere \etape';
  15:TBHint:='\Etape pr\ec\edente';
  16:TBHint:='\Etape suivante';
  17:TBHint:='Derni\ere \etape';
 Else TBHint:='';
 End;
End;

Procedure DrawIcon(Id,X,Y:Integer);
Var Pt:Array[0..7] Of PointType; I:Integer;
 Procedure Tri(X1,Y1,X2,Y2,X3,Y3,C:Integer);
 Begin
  Pt[0].X:=X+X1; Pt[0].Y:=Y+Y1; Pt[1].X:=X+X2; Pt[1].Y:=Y+Y2; Pt[2].X:=X+X3; Pt[2].Y:=Y+Y3;
  Pt[3]:=Pt[0];
  SetFillStyle(SolidFill,C); SetColor(C);
  FillPoly(3,Pt);
 End;
Begin
 Case Id Of
  0:Begin
   Box(X+5,Y+3,X+17,Y+20,15); SetColor(UI_DK); Rectangle(X+5,Y+3,X+17,Y+20);
   Box(X+13,Y+3,X+17,Y+7,UI_BG); Line(X+13,Y+3,X+17,Y+7); Line(X+13,Y+7,X+17,Y+7); Line(X+13,Y+3,X+13,Y+7);
  End;
  1:Begin
   Box(X+3,Y+8,X+20,Y+19,14); SetColor(UI_DK); Rectangle(X+3,Y+8,X+20,Y+19);
   Box(X+3,Y+5,X+10,Y+8,14); Rectangle(X+3,Y+5,X+10,Y+8);
   SetColor(6); Line(X+5,Y+11,X+19,Y+11);
  End;
  2:Begin
   Box(X+4,Y+4,X+19,Y+19,1); SetColor(UI_DK); Rectangle(X+4,Y+4,X+19,Y+19);
   Box(X+7,Y+4,X+16,Y+9,7); Box(X+8,Y+13,X+15,Y+19,15);
  End;
  3:Begin
   SetColor(UI_SEL); SetLineStyle(0,0,3);
   Arc(X+13,Y+13,20,170,6);
   SetLineStyle(0,0,1);
   Tri(3,12,10,12,6,6,UI_SEL);
  End;
  4:Begin
   SetColor(UI_SH); SetLineStyle(0,0,3);
   Arc(X+10,Y+13,10,160,6);
   SetLineStyle(0,0,1);
   Tri(21,12,14,12,18,6,UI_SH);
  End;
  5:Begin
   Pt[0].X:=X+7; Pt[0].Y:=Y+3; Pt[1].X:=X+7; Pt[1].Y:=Y+18; Pt[2].X:=X+11; Pt[2].Y:=Y+14;
   Pt[3].X:=X+15; Pt[3].Y:=Y+20; Pt[4].X:=X+17; Pt[4].Y:=Y+19; Pt[5].X:=X+13; Pt[5].Y:=Y+13;
   Pt[6].X:=X+18; Pt[6].Y:=Y+13; Pt[7]:=Pt[0];
   SetFillStyle(SolidFill,UI_DK); SetColor(UI_HI); FillPoly(7,Pt);
  End;
  6:Begin
   Box(X+4,Y+11,X+17,Y+19,4); SetColor(UI_DK); Rectangle(X+4,Y+11,X+17,Y+19);
   Box(X+6,Y+8,X+9,Y+11,4); Box(X+12,Y+8,X+15,Y+11,4);
   SetColor(2); SetLineStyle(0,0,3); Line(X+17,Y+3,X+17,Y+9); Line(X+14,Y+6,X+20,Y+6); SetLineStyle(0,0,1);
  End;
  7:Begin
   SetColor(UI_SEL); Ellipse(X+12,Y+12,0,360,8,4);
   SetColor(UI_DK); Circle(X+12,Y+12,3);
   Tri(17,7,21,9,17,11,UI_SEL);
  End;
  8:Begin
   SetColor(UI_DK);
   Line(X+12,Y+4,X+12,Y+20); Line(X+4,Y+12,X+20,Y+12);
   Tri(12,2,9,6,15,6,UI_DK); Tri(12,22,9,18,15,18,UI_DK);
   Tri(2,12,6,9,6,15,UI_DK); Tri(22,12,18,9,18,15,UI_DK);
  End;
  9:Begin
   SetColor(UI_DK); SetLineStyle(0,0,2);
   Circle(X+10,Y+10,5); Line(X+14,Y+14,X+19,Y+19);
   SetLineStyle(0,0,1);
  End;
  10:Begin
   SetColor(UI_DK);
   For I:=0 To 3 Do Begin
    Line(X+4+I*5,Y+4,X+4+I*5,Y+19); Line(X+4,Y+4+I*5,X+19,Y+4+I*5);
   End;
  End;
  11:Begin
   SetColor(UI_DK);
   Rectangle(X+4,Y+8,X+15,Y+19); Line(X+4,Y+8,X+9,Y+4); Line(X+15,Y+8,X+20,Y+4);
   Line(X+9,Y+4,X+20,Y+4); Line(X+20,Y+4,X+20,Y+15); Line(X+15,Y+19,X+20,Y+15);
  End;
  12:Begin
   SetColor(UI_DK); Rectangle(X+4,Y+4,X+19,Y+19);
   Line(X+11,Y+4,X+11,Y+19); Line(X+4,Y+11,X+19,Y+11);
  End;
  13:Begin
   SetColor(UI_DK); SetLineStyle(0,0,2);
   Line(X+4,Y+4,X+9,Y+4); Line(X+4,Y+4,X+4,Y+9);
   Line(X+19,Y+4,X+14,Y+4); Line(X+19,Y+4,X+19,Y+9);
   Line(X+4,Y+19,X+9,Y+19); Line(X+4,Y+19,X+4,Y+14);
   Line(X+19,Y+19,X+14,Y+19); Line(X+19,Y+19,X+19,Y+14);
   SetLineStyle(0,0,1);
  End;
  14:Begin Box(X+5,Y+5,X+7,Y+18,UI_SEL); Tri(18,5,18,18,8,11,UI_SEL); End;
  15:Begin Tri(11,5,11,18,3,11,UI_SEL); Tri(20,5,20,18,12,11,UI_SEL); End;
  16:Begin Tri(3,5,3,18,11,11,UI_SEL); Tri(12,5,12,18,20,11,UI_SEL); End;
  17:Begin Box(X+16,Y+5,X+18,Y+18,UI_SEL); Tri(5,5,5,18,15,11,UI_SEL); End;
 End;
End;

Function TBDown(I:Integer):Boolean;
Begin
 Case I Of
  5..9:TBDown:=Tool=I-5;
  10:TBDown:=GridOn;
  11:TBDown:=WireOn;
  12:TBDown:=ViewCount=4;
 Else TBDown:=False;
 End;
End;

Procedure DrawToolbar;
Var I:Integer;
Begin
 Box(0,MENU_H,ScreenW-1,MENU_H+TB_H-1,UI_BG);
 SetColor(UI_SH); Line(0,MENU_H+TB_H-1,ScreenW-1,MENU_H+TB_H-1);
 For I:=0 To TBN-1 Do Begin
  Box(TBX(I),MENU_H+2,TBX(I)+23,MENU_H+25,UI_BG);
  If TBDown(I)Then Bevel(TBX(I),MENU_H+2,TBX(I)+23,MENU_H+25,False)
  Else Begin
   SetColor(UI_BG); Rectangle(TBX(I),MENU_H+2,TBX(I)+23,MENU_H+25);
  End;
  DrawIcon(I,TBX(I)+Ord(TBDown(I)),MENU_H+2+Ord(TBDown(I)));
 End;
End;

{ Onglets des modeles (fichier principal et sous-modeles) }
Function TabW(I:Integer):Integer;
Var W:Integer;
Begin
 W:=TextWidth(Models[I].Name)+18;
 If W>150 Then W:=150;
 TabW:=W;
End;

Function TabHit(PX,PY:Integer):Integer;
Var I,X:Integer;
Begin
 TabHit:=-1;
 If(PY<MENU_H+TB_H)Or(PY>=MENU_H+TB_H+TAB_H)Then Exit;
 X:=2;
 For I:=0 To ModelCount-1 Do Begin
  If(PX>=X)And(PX<X+TabW(I))Then Begin TabHit:=I; Exit; End;
  Inc(X,TabW(I)+2);
 End;
End;

Procedure DrawTabs;
Var I,X,Y,W:Integer; S:String;
Begin
 Y:=MENU_H+TB_H;
 Box(0,Y,ScreenW-1,Y+TAB_H-1,UI_BG);
 SetColor(UI_SH); Line(0,Y+TAB_H-1,ScreenW-1,Y+TAB_H-1);
 X:=2;
 For I:=0 To ModelCount-1 Do Begin
  W:=TabW(I);
  S:=Models[I].Name;
  If TextWidth(S)>W-14 Then S:=Copy(S,1,(W-14) Div 8);
  If I=CurModel Then Begin
   Box(X,Y+1,X+W-1,Y+TAB_H-1,15);
   SetColor(UI_HI); Line(X,Y+1,X,Y+TAB_H-1); Line(X,Y+1,X+W-1,Y+1);
   SetColor(UI_SH); Line(X+W-1,Y+1,X+W-1,Y+TAB_H-1);
   TxtOut(X+7,Y+6,S,UI_DK);
  End
   Else Begin
    Box(X,Y+3,X+W-1,Y+TAB_H-1,UI_BG);
    Bevel(X,Y+3,X+W-1,Y+TAB_H,True);
    TxtOut(X+7,Y+7,S,UI_DK);
   End;
  Inc(X,W+2);
 End;
End;

{ Supprime les espaces doubles des descriptions LDraw }
Function Compact(Const S:String):String;
Var I:Integer; R:String;
Begin
 R:='';
 For I:=1 To Length(S) Do
  If Not((S[I]=' ')And(Length(R)>0)And(R[Length(R)]=' '))Then R:=R+S[I];
 Compact:=R;
End;

Procedure DrawStatus;
Var Y,Q,N:Integer; P:PPiece; S,T:String; Mn,Mx:TVec;
Begin
 Y:=ScreenH-ST_H;
 Box(0,Y,ScreenW-1,ScreenH-1,UI_BG);
 Sunken(2,Y+1,(LongInt(ScreenW)*55 Div 100),ScreenH-2,UI_BG);
 Sunken((LongInt(ScreenW)*55 Div 100)+2,Y+1,(LongInt(ScreenW)*80 Div 100),ScreenH-2,UI_BG);
 Sunken((LongInt(ScreenW)*80 Div 100)+2,Y+1,ScreenW-3,ScreenH-2,UI_BG);
 S:=StatusMsg;
 If S='' Then Begin
  Case Tool Of
   TL_SELECT:S:='S\election : clic, glisser = d\eplacer';
   TL_INSERT:S:='Poser : '+Copy(Compact(CurPartDesc),1,24);
   TL_ORBIT:S:='Orbite : glisser = tourner';
   TL_PAN:S:='Panoramique : glisser';
   TL_ZOOM:S:='Zoom : glisser haut / bas';
  End;
 End;
 TxtOut(6,Y+5,Copy(Fx(S),1,(LongInt(ScreenW)*55 Div 800)-1),UI_DK);
 P:=FirstSel;
 If P<>Nil Then T:='X:'+FmtNum(P^.M.T.X)+' Y:'+FmtNum(P^.M.T.Y)+' Z:'+FmtNum(P^.M.T.Z)
 Else T:='X:'+FmtNum(InsX)+' Y:'+FmtNum(InsY)+' Z:'+FmtNum(InsZ);
 TxtOut((LongInt(ScreenW)*55 Div 100)+6,Y+5,Copy(T,1,(LongInt(ScreenW)*25 Div 800)),UI_DK);
 N:=Models[CurModel].Count;
 T:=Fx('\Etape ')+IntStr(Models[CurModel].CurStep)+'/'+IntStr(MaxStep(CurModel))+' '+IntStr(N)+Fx(' pi\eces');
 If Modified Then T:=T+' *';
 TxtOut((LongInt(ScreenW)*80 Div 100)+6,Y+5,Copy(T,1,(LongInt(ScreenW)*20 Div 800)-1),UI_DK);
End;

{ ====================================================================== }
{ Panneau Pieces                                                         }
{ ====================================================================== }

Const
 CAT_ROWS=5; PART_ROWS=7;

Function CatY:Integer;
Begin
 CatY:=PanY1+3;
End;

Function SearchY:Integer;
Begin
 SearchY:=PanY1+66;
End;

Function ListY:Integer;
Begin
 ListY:=PanY1+83;
End;

Function PrevY:Integer;
Begin
 PrevY:=PanY1+170;
End;

Procedure DrawThumb(X1,Y1,X2,Y2:Integer;Const Nm:String;Code:Integer);
Var Tmp:PPiece; V:TView; Mn,Mx:TVec; R:Real; Mt:TMat; W,H:Integer; P:PPart; SaveStud:Integer;
Begin
 Box(X1,Y1,X2,Y2,15);
 W:=X2-X1+1; H:=Y2-Y1+1;
 If CacheCount>CACHE_MAX Then FlushCache;
 If FindModel(Nm)>=0 Then Begin
  Bevel(X1,Y1,X2,Y2,False); Exit;
 End;
 P:=GetPart(Nm,0);
 If P<>Nil Then Begin
  CalcBBox(P);
  MatIdent(Mt);
  New(Tmp);
  FillChar(Tmp^,SizeOf(TPiece),0);
  Tmp^.Name:=Nm; Tmp^.Col:=Code; Tmp^.M:=Mt; Tmp^.Part:=P; Tmp^.Epoch:=Epoch;
  Mn:=P^.AMin; Mx:=P^.AMax;
  V.Persp:=True; V.Yaw:=145; V.Pitch:=30; V.X1:=X1; V.Y1:=Y1; V.X2:=X2; V.Y2:=Y2;
  VSet(V.Tgt,(Mn.X+Mx.X)/2,(Mn.Y+Mx.Y)/2,(Mn.Z+Mx.Z)/2);
  R:=Sqrt(Sqr(Mx.X-Mn.X)+Sqr(Mx.Y-Mn.Y)+Sqr(Mx.Z-Mn.Z))/2;
  If R<12 Then R:=12;
  V.Dist:=R/0.2588*1.1; V.Zoom:=1;
  SetViewPort(X1,Y1,X2,Y2,True);
  SetupCamera(V);
  PolyN:=0; PolyMax:=3000; PolyOverflow:=False;
  SaveStud:=StudEff; StudEff:=2;
  RenderPiece(Tmp,CamM,-1,7,0,False,0);
  StudEff:=SaveStud;
  SortScene;
  PaintScene(W,H);
  SetViewPort(0,0,ScreenW-1,ScreenH-1,False);
  Dispose(Tmp);
 End;
 Bevel(X1,Y1,X2,Y2,False);
End;

Procedure DrawPartsPanel;
Var I,Y,K,X0,X1:Integer; S:String;
Begin
 X0:=DockX+3; X1:=ScreenW-4;
 { categories }
 Sunken(X0,CatY,X1-12,CatY+CAT_ROWS*12+1,15);
 For I:=0 To CAT_ROWS-1 Do Begin
  K:=CatTop+I;
  If K<CatN Then Begin
   Y:=CatY+1+I*12;
   If K=CatSel Then Begin Box(X0+1,Y,X1-13,Y+11,UI_SEL); TxtOut(X0+4,Y+2,Copy(CatNames[K],1,21),15); End
   Else TxtOut(X0+4,Y+2,Copy(CatNames[K],1,21),UI_DK);
  End;
 End;
 DrawVScroll(X1-11,CatY,CAT_ROWS*12+2,CatTop,CatN,CAT_ROWS);
 { recherche }
 TxtOut(X0+1,SearchY+3,'Rech.',UI_DK);
 Sunken(X0+44,SearchY,X1,SearchY+13,15);
 S:=SearchStr;
 If SearchEdit Then S:=S+'_';
 TxtOut(X0+48,SearchY+3,Copy(S,1,18),UI_DK);
 { liste des pieces }
 Sunken(X0,ListY,X1-12,ListY+PART_ROWS*12+1,15);
 For I:=0 To PART_ROWS-1 Do Begin
  K:=PartTop+I;
  If K<FilN Then Begin
   Y:=ListY+1+I*12;
   S:=Copy(Compact(Catalog^[Filtered^[K]]^.Desc),1,21);
   If K=PartSel Then Begin Box(X0+1,Y,X1-13,Y+11,UI_SEL); TxtOut(X0+4,Y+2,S,15); End
   Else TxtOut(X0+4,Y+2,S,UI_DK);
  End;
 End;
 DrawVScroll(X1-11,ListY,PART_ROWS*12+2,PartTop,FilN,PART_ROWS);
 { apercu }
 If CurPart<>'' Then Begin
  DrawThumb(X0,PrevY,X0+66,PanY2-3,CurPart,CurColor);
  TxtOut(X0+70,PrevY+2,Copy(UpStr(CurPart),1,15),UI_DK);
  TxtOut(X0+70,PrevY+14,Copy(Compact(CurPartDesc),1,15),UI_SH);
  TxtOut(X0+70,PrevY+24,Copy(Compact(CurPartDesc),16,15),UI_SH);
  TxtOut(X0+70,PrevY+34,Copy(Compact(CurPartDesc),31,15),UI_SH);
 End
  Else Begin
   Sunken(X0,PrevY,X0+66,PanY2-3,15);
   TxtF(X0+70,PrevY+2,'Choisir une',UI_SH);
   TxtF(X0+70,PrevY+14,'pi\ece',UI_SH);
  End;
 TxtOut(X0+70,PrevY+46,IntStr(FilN)+' / '+IntStr(CatCount),UI_SH);
End;

{ ====================================================================== }
{ Panneau Proprietes                                                     }
{ ====================================================================== }

Function PropRow(F:Integer):Integer;
Const R:Array[0..8] Of Integer=(1,2,3,5,6,7,9,11,12);
Begin
 PropRow:=R[F];
End;

Function PropValue(F:Integer;Q:PPiece):String;
Var RX,RY,RZ:Real;
Begin
 PropValue:='';
 If Q=Nil Then Exit;
 EulerFromMat(Q^.M,RX,RY,RZ);
 Case F Of
  0:PropValue:=FmtNum(Q^.M.T.X);
  1:PropValue:=FmtNum(Q^.M.T.Y);
  2:PropValue:=FmtNum(Q^.M.T.Z);
  3:PropValue:=FmtNum(Round(RX));
  4:PropValue:=FmtNum(Round(RY));
  5:PropValue:=FmtNum(Round(RZ));
  6:PropValue:=IntStr(Q^.Step);
  7:If Q^.Col=16 Then PropValue:=Fx('Principale') Else PropValue:=ColName[ColIdx(Q^.Col)];
  8:PropValue:=UpStr(Q^.Name);
 End;
End;

Procedure DrawPropsPanel;
Var Q:PPiece; I,Y:Integer; S:String;
 Procedure Head(R:Integer;Const T:String);
 Begin
  TxtF(DockX+6,PanY1+6+R*14,T,UI_SEL);
  SetColor(UI_SH); Line(DockX+6+TextWidth(Fx(T))+4,PanY1+10+R*14,ScreenW-6,PanY1+10+R*14);
 End;
Begin
 Q:=FirstSel;
 Head(0,'Position'); Head(4,'Rotation'); Head(8,'\Etapes visibles'); Head(10,'Apparence');
 For I:=0 To 8 Do Begin
  Y:=PanY1+4+PropRow(I)*14;
  Case I Of
   0,3:TxtOut(DockX+14,Y+3,'X',UI_DK);
   1,4:TxtOut(DockX+14,Y+3,'Y',UI_DK);
   2,5:TxtOut(DockX+14,Y+3,'Z',UI_DK);
   6:TxtF(DockX+14,Y+3,'Afficher',UI_DK);
   7:TxtF(DockX+14,Y+3,'Couleur',UI_DK);
   8:TxtF(DockX+14,Y+3,'Pi\ece',UI_DK);
  End;
  Sunken(DockX+76,Y,ScreenW-6,Y+12,15);
  If(I=PropField)Then S:=PropText+'_' Else S:=PropValue(I,Q);
  If I=7 Then Begin
   If Q<>Nil Then Begin Box(DockX+79,Y+2,DockX+87,Y+10,ShadeMap[ColIdx(Q^.Col),4]); End;
   TxtOut(DockX+92,Y+3,Copy(S,1,14),UI_DK);
  End
   Else TxtOut(DockX+80,Y+3,Copy(S,1,15),UI_DK);
 End;
 If Q=Nil Then TxtF(DockX+8,PanY1+4+14*14,'(aucune s\election)',UI_SH)
 Else If SelCount>1 Then TxtOut(DockX+8,PanY1+4+14*14,IntStr(SelCount)+Fx(' pi\eces s\electionn\ees'),UI_SH);
End;

{ ====================================================================== }
{ Panneau Chronologie                                                    }
{ ====================================================================== }

Const TIME_ROWS=16;

Function TimeSteps:Integer;
Var S:Integer;
Begin
 S:=MaxStep(CurModel);
 If Models[CurModel].CurStep>S Then S:=Models[CurModel].CurStep;
 TimeSteps:=S;
End;

Function TimeRowCount:Integer;
Begin
 TimeRowCount:=TimeSteps+Models[CurModel].Count;
End;

Procedure TimeRowAt(K:Integer;Var Hdr:Boolean;Var Step:Integer;Var Q:PPiece);
Var S,MS,Cnt:Integer; P:PPiece;
Begin
 Hdr:=False; Step:=0; Q:=Nil;
 MS:=TimeSteps;
 For S:=1 To MS Do Begin
  If K=0 Then Begin Hdr:=True; Step:=S; Exit; End;
  Dec(K);
  P:=Models[CurModel].First;
  While P<>Nil Do Begin
   If P^.Step=S Then Begin
    If K=0 Then Begin Step:=S; Q:=P; Exit; End;
    Dec(K);
   End;
   P:=P^.Next;
  End;
 End;
End;

Procedure DrawTimePanel;
Var I,Y,K,N,X0,X1,C:Integer; Hdr:Boolean; S:Integer; Q:PPiece; T:String;
Begin
 X0:=DockX+3; X1:=ScreenW-4;
 Sunken(X0,PanY1+2,X1-12,PanY2-2,15);
 N:=TimeRowCount;
 For I:=0 To TIME_ROWS-1 Do Begin
  K:=TimeTop+I;
  If K<N Then Begin
   Y:=PanY1+4+I*13;
   TimeRowAt(K,Hdr,S,Q);
   If Hdr Then Begin
    If S=Models[CurModel].CurStep Then Begin
     Box(X0+1,Y-1,X1-13,Y+11,UI_SEL); TxtF(X0+14,Y+2,'\Etape '+IntStr(S),15);
    End
     Else TxtF(X0+14,Y+2,'\Etape '+IntStr(S),UI_DK);
    SetColor(UI_SH);
    Line(X0+6,Y+3,X0+10,Y+3); Line(X0+7,Y+4,X0+9,Y+4);
   End
    Else If Q<>Nil Then Begin
     C:=ShadeMap[ColIdx(Q^.Col),4];
     If Q^.Sel Then Box(X0+1,Y-1,X1-13,Y+11,UI_SEL);
     SetFillStyle(SolidFill,C); SetColor(UI_DK);
     FillEllipse(X0+22,Y+5,4,4);
     T:=Copy(Compact(PieceDesc(Q)),1,19);
     If Q^.Sel Then TxtOut(X0+31,Y+2,T,15)
     Else If Q^.Step>Models[CurModel].CurStep Then TxtOut(X0+31,Y+2,T,UI_SH)
     Else TxtOut(X0+31,Y+2,T,UI_DK);
    End;
  End;
 End;
 DrawVScroll(X1-11,PanY1+2,PanY2-PanY1-3,TimeTop,N,TIME_ROWS);
End;

{ ====================================================================== }
{ Palette de couleurs                                                    }
{ ====================================================================== }

Procedure ColPos(I:Integer;Var X,Y:Integer);
Var Sol,K:Integer;
Begin
 Sol:=0;
 For K:=0 To NCol-1 Do If Not ColTr[K]Then Inc(Sol);
 If Not ColTr[I]Then Begin
  X:=DockX+4+(I Mod 11)*17; Y:=ColY+18+(I Div 11)*16;
 End
  Else Begin
   K:=I-Sol;
   X:=DockX+4+(K Mod 11)*17; Y:=ColY+18+((Sol+10) Div 11)*16+12+(K Div 11)*16;
  End;
End;

Function ColHit(PX,PY:Integer):Integer;
Var I,X,Y:Integer;
Begin
 ColHit:=-1;
 For I:=0 To NCol-1 Do Begin
  ColPos(I,X,Y);
  If InRect(PX,PY,X,Y,16,15)Then Begin ColHit:=I; Exit; End;
 End;
End;

Procedure DrawColors;
Var I,X,Y,C,SolRows:Integer;
Begin
 Raised(DockX,ColY,ScreenW-1,ColY2);
 C:=ColIdx(CurColor);
 TxtF(DockX+6,ColY+4,'Couleur :',UI_DK);
 Box(DockX+80,ColY+2,DockX+92,ColY+12,ShadeMap[C,4]);
 SetColor(UI_DK); Rectangle(DockX+80,ColY+2,DockX+92,ColY+12);
 TxtOut(DockX+96,ColY+4,Copy(ColName[C],1,12),UI_DK);
 For I:=0 To NCol-1 Do Begin
  ColPos(I,X,Y);
  Box(X,Y,X+15,Y+14,ShadeMap[I,4]);
  If ColTr[I]Then Begin
   SetColor(15);
   Line(X+2,Y+2,X+13,Y+13); Line(X+13,Y+2,X+2,Y+13);
  End;
  If ColCode[I]=CurColor Then Begin
   SetColor(UI_DK); Rectangle(X-1,Y-1,X+16,Y+15);
   SetColor(15); Rectangle(X,Y,X+15,Y+14);
  End
   Else Begin
    SetColor(UI_SH); Rectangle(X,Y,X+15,Y+14);
   End;
 End;
End;

{ ====================================================================== }
{ Dock                                                                   }
{ ====================================================================== }

Function DockTabHit(PX,PY:Integer):Integer;
Var K:Integer;
Begin
 DockTabHit:=-1;
 If(PY<TabY)Or(PY>=TabY+17)Or(PX<DockX)Then Exit;
 K:=(PX-DockX) Div (DOCK_W Div 3);
 If K>2 Then K:=2;
 DockTabHit:=K;
End;

Procedure DrawDockTabs;
Var I,X,W:Integer; Names:Array[0..2] Of String[12];
Begin
 Names[0]:=Fx('Pi\eces'); Names[1]:='Propr.'; Names[2]:='Chrono.';
 W:=DOCK_W Div 3;
 Box(DockX,TabY,ScreenW-1,TabY+17,UI_BG);
 For I:=0 To 2 Do Begin
  X:=DockX+I*W;
  If I=PanelSel Then Begin
   Box(X,TabY,X+W-1,TabY+17,15);
   SetColor(UI_SH); Line(X+W-1,TabY,X+W-1,TabY+17); Line(X,TabY+17,X+W-1,TabY+17);
   TxtOut(X+(W-TextWidth(Names[I])) Div 2,TabY+5,Names[I],UI_DK);
  End
   Else Begin
    Bevel(X,TabY,X+W-1,TabY+17,True);
    TxtOut(X+(W-TextWidth(Names[I])) Div 2,TabY+6,Names[I],UI_DK);
   End;
 End;
End;

Procedure DrawDock;
Begin
 Raised(DockX,PanY1,ScreenW-1,PanY2);
 Case PanelSel Of
  PN_PARTS:DrawPartsPanel;
  PN_PROPS:DrawPropsPanel;
  PN_TIME:DrawTimePanel;
 End;
 DrawDockTabs;
 DrawColors;
End;

Procedure DrawViews;
Var I:Integer;
Begin
 LayoutViews;
 If ViewCount=1 Then RenderView(Views[ActiveView],True,Tool=TL_INSERT)
 Else For I:=0 To 3 Do RenderView(Views[I],I=ActiveView,(Tool=TL_INSERT)And(I=ActiveView));
End;

Procedure RedrawAll;
Begin
 MouseOff;
 UpdateMenuChecks;
 Box(0,0,ScreenW-1,ScreenH-1,UI_BG);
 DrawMenuBar;
 DrawToolbar;
 DrawTabs;
 DrawViews;
 DrawDock;
 DrawStatus;
 NeedViews:=False; NeedDock:=False; NeedStatus:=False; NeedTools:=False;
 MouseOn;
End;

{ ====================================================================== }
{ Boites de dialogue                                                     }
{ ====================================================================== }

Function Ticks:LongInt;
Var H,M,S,C:Word;
Begin
 GetTime(H,M,S,C);
 Ticks:=LongInt(H)*360000+LongInt(M)*6000+LongInt(S)*100+C;
End;

Procedure WaitMouseUp;
Begin
 Repeat
  PollMouse;
  If MB<>0 Then Delay(10);
 Until MB=0;
 OldMB:=0;
End;

Function ReadKeyEx(Var Ext:Boolean):Char;
Var C:Char;
Begin
 C:=ReadKey;
 Ext:=False;
 If C=#0 Then Begin
  Ext:=True;
  C:=ReadKey;
 End;
 ReadKeyEx:=C;
End;

Procedure SplitLines(Const S:String;Var Ln:Array Of String;Var N:Integer);
Var I:Integer; T:String;
Begin
 N:=0; T:='';
 For I:=1 To Length(S) Do Begin
  If S[I]='|' Then Begin
   If N<=High(Ln) Then Begin Ln[N]:=T; Inc(N); End;
   T:='';
  End
   Else T:=T+S[I];
 End;
 If N<=High(Ln) Then Begin Ln[N]:=T; Inc(N); End;
End;

{ Boite de message. Kind : 0 OK, 1 Oui/Non, 2 Oui/Non/Annuler.
  Retour : 1 oui/ok, 0 non, -1 annuler }
Function AskBox(Const Title,Msg:String;Kind:Integer):Integer;
Var
 Ln:Array[0..9] Of String;
 N,I,W,H,X,Y,BW,Res:Integer;
 Sv:TSave;
 Done,Ext:Boolean;
 K:Char;
 B1,B2,B3:Integer;
Begin
 SplitLines(Fx(Msg),Ln,N);
 W:=240;
 For I:=0 To N-1 Do If Length(Ln[I])*8+40>W Then W:=Length(Ln[I])*8+40;
 H:=76+N*13;
 X:=(ScreenW-W) Div 2; Y:=(ScreenH-H) Div 2;
 MouseOff;
 SaveRect(Sv,X,Y,X+W,Y+H);
 DrawWin(X,Y,W,H,Title);
 For I:=0 To N-1 Do TxtOut(X+20,Y+26+I*13,Ln[I],UI_DK);
 BW:=70;
 Case Kind Of
  0:Begin DrawBtn(X+(W-BW) Div 2,Y+H-30,BW,20,'OK',False); End;
  1:Begin DrawBtn(X+W Div 2-BW-6,Y+H-30,BW,20,'Oui',False); DrawBtn(X+W Div 2+6,Y+H-30,BW,20,'Non',False); End;
 Else Begin
  DrawBtn(X+W Div 2-BW*3 Div 2-8,Y+H-30,BW,20,'Oui',False);
  DrawBtn(X+W Div 2-BW Div 2,Y+H-30,BW,20,'Non',False);
  DrawBtn(X+W Div 2+BW Div 2+8,Y+H-30,BW,20,'Annuler',False);
 End;
 End;
 MouseOn;
 WaitMouseUp;
 Done:=False; Res:=0;
 Repeat
  PollMouse;
  If KeyPressed Then Begin
   K:=ReadKeyEx(Ext);
   If Not Ext Then Begin
    Case UpCase(K) Of
     #13:Begin Res:=1; Done:=True; End;
     #27:Begin If Kind=2 Then Res:=-1 Else Res:=0; Done:=True; End;
     'O','Y':Begin Res:=1; Done:=True; End;
     'N':If Kind>0 Then Begin Res:=0; Done:=True; End;
    End;
   End;
  End;
  If((MB And 1)<>0)And((OldMB And 1)=0)Then Begin
   If InRect(MX,MY,X,Y+H-30,W,20)Then Begin
    Case Kind Of
     0:Begin Res:=1; Done:=True; End;
     1:If MX<X+W Div 2 Then Res:=1 Else Res:=0;
     2:If MX<X+W Div 2-BW Div 2-4 Then Res:=1
       Else If MX<X+W Div 2+BW Div 2+4 Then Res:=0 Else Res:=-1;
    End;
    Done:=True;
   End;
  End;
  OldMB:=MB;
  Delay(10);
 Until Done;
 WaitMouseUp;
 MouseOff;
 If Not RestoreRect(Sv)Then FullRedraw:=True;
 MouseOn;
 AskBox:=Res;
End;

Function InputBox(Const Title,Prompt:String;Var S:String;MaxLen:Integer):Boolean;
Var
 W,H,X,Y:Integer;
 Sv:TSave;
 Done,OK,Ext,Redraw,Fresh:Boolean;
 K:Char;
 T:String;
 Procedure Paint;
 Begin
  MouseOff;
  DrawWin(X,Y,W,H,Title);
  TxtOut(X+14,Y+26,Fx(Prompt),UI_DK);
  Sunken(X+14,Y+42,X+W-15,Y+58,15);
  TxtOut(X+18,Y+47,Copy(T+'_',Length(T)+2-Min(Length(T)+1,(W-40) Div 8),255),UI_DK);
  DrawBtn(X+W Div 2-76,Y+H-30,70,20,'OK',False);
  DrawBtn(X+W Div 2+6,Y+H-30,70,20,'Annuler',False);
  MouseOn;
 End;
Begin
 W:=360; H:=112;
 X:=(ScreenW-W) Div 2; Y:=(ScreenH-H) Div 2;
 MouseOff;
 SaveRect(Sv,X,Y,X+W,Y+H);
 MouseOn;
 T:=S;
 Fresh:=True;
 Paint;
 WaitMouseUp;
 Done:=False; OK:=False;
 Repeat
  PollMouse;
  If KeyPressed Then Begin
   K:=ReadKeyEx(Ext);
   If Not Ext Then Begin
    If K=#13 Then Begin OK:=True; Done:=True; End
    Else If K=#27 Then Done:=True
    Else If K=#8 Then Begin If Length(T)>0 Then Delete(T,Length(T),1); Fresh:=False; Paint; End
    Else If(K>=' ')And(Length(T)<MaxLen)Then Begin
     If Fresh Then T:='';
     Fresh:=False;
     T:=T+K; Paint;
    End;
   End;
  End;
  If((MB And 1)<>0)And((OldMB And 1)=0)Then Begin
   If InRect(MX,MY,X+W Div 2-76,Y+H-30,70,20)Then Begin OK:=True; Done:=True; End;
   If InRect(MX,MY,X+W Div 2+6,Y+H-30,70,20)Then Done:=True;
  End;
  OldMB:=MB;
  Delay(10);
 Until Done;
 WaitMouseUp;
 MouseOff;
 If Not RestoreRect(Sv)Then FullRedraw:=True;
 MouseOn;
 If OK Then S:=T;
 InputBox:=OK;
End;

Var
 ListItems:Array[0..MAXMOD-1] Of String[40];

{ Choix dans une liste (ListItems[0..N-1]) }
Function ListDialog(Const Title:String;N:Integer;Var Sel:Integer):Boolean;
Var
 W,H,X,Y,I,Top:Integer;
 Sv:TSave;
 Done,OK,Ext:Boolean;
 K:Char;
 Rows:Integer;
 Procedure Paint;
 Var J:Integer;
 Begin
  MouseOff;
  DrawWin(X,Y,W,H,Title);
  Sunken(X+10,Y+24,X+W-11,Y+24+Rows*12+2,15);
  For J:=0 To Rows-1 Do
   If Top+J<N Then Begin
    If Top+J=Sel Then Begin Box(X+11,Y+25+J*12,X+W-12,Y+25+J*12+11,UI_SEL); TxtOut(X+14,Y+27+J*12,ListItems[Top+J],15); End
    Else TxtOut(X+14,Y+27+J*12,ListItems[Top+J],UI_DK);
   End;
  DrawBtn(X+W Div 2-76,Y+H-30,70,20,'OK',False);
  DrawBtn(X+W Div 2+6,Y+H-30,70,20,'Annuler',False);
  MouseOn;
 End;
Begin
 Rows:=Min(N,12);
 If Rows<3 Then Rows:=3;
 W:=300; H:=Rows*12+66;
 X:=(ScreenW-W) Div 2; Y:=(ScreenH-H) Div 2;
 MouseOff;
 SaveRect(Sv,X,Y,X+W,Y+H);
 MouseOn;
 Top:=0;
 If Sel<0 Then Sel:=0;
 Paint;
 WaitMouseUp;
 Done:=False; OK:=False;
 Repeat
  PollMouse;
  If KeyPressed Then Begin
   K:=ReadKeyEx(Ext);
   If Ext Then Begin
    If(K=#72)And(Sel>0)Then Dec(Sel);
    If(K=#80)And(Sel<N-1)Then Inc(Sel);
    If Sel<Top Then Top:=Sel;
    If Sel>=Top+Rows Then Top:=Sel-Rows+1;
    Paint;
   End
    Else If K=#13 Then Begin OK:=True; Done:=True; End
    Else If K=#27 Then Done:=True;
  End;
  If((MB And 1)<>0)And((OldMB And 1)=0)Then Begin
   If InRect(MX,MY,X+W Div 2-76,Y+H-30,70,20)Then Begin OK:=True; Done:=True; End;
   If InRect(MX,MY,X+W Div 2+6,Y+H-30,70,20)Then Done:=True;
   If InRect(MX,MY,X+11,Y+25,W-22,Rows*12)Then Begin
    I:=Top+(MY-Y-25) Div 12;
    If I<N Then Begin
     If I=Sel Then Begin OK:=True; Done:=True; End;
     Sel:=I; Paint;
    End;
   End;
  End;
  OldMB:=MB;
  Delay(10);
 Until Done;
 WaitMouseUp;
 MouseOff;
 If Not RestoreRect(Sv)Then FullRedraw:=True;
 MouseOn;
 ListDialog:=OK;
End;

{ ---------------------------- Fichiers ----------------------------- }

Type
 TEntry=Record Name:String[40]; IsDir:Boolean; End;

Var
 FEnt:Array[0..299] Of TEntry;
 FN:Integer;

Procedure ScanDir(Flt:Integer;Mode:Integer);
Var SR:SearchRec; E:String; I,J:Integer; T:TEntry; Ok:Boolean;
Begin
 FN:=0;
 {$IFDEF FPC}FindFirst('*',AnyFile,SR);{$ELSE}FindFirst('*.*',AnyFile,SR);{$ENDIF}
 While(DosError=0)And(FN<300)Do Begin
  If(SR.Attr And Directory)<>0 Then Begin
   If SR.Name<>'.' Then Begin
    FEnt[FN].Name:=Copy(SR.Name,1,40); FEnt[FN].IsDir:=True; Inc(FN);
   End;
  End
   Else If(SR.Attr And VolumeID)=0 Then Begin
    E:=ExtOf(SR.Name);
    If Mode=0 Then Begin
     Case Flt Of
      0:Ok:=(E='.LDR')Or(E='.MPD');
      1:Ok:=E='.DAT';
     Else Ok:=True;
     End;
    End
     Else If Mode=1 Then Begin
      If Flt=0 Then Ok:=E='.LDR' Else Ok:=E='.MPD';
     End
      Else If Mode=2 Then Ok:=E='.BMP'
      Else Ok:=E='.TXT';
    If Ok Then Begin
     FEnt[FN].Name:=Copy(SR.Name,1,40); FEnt[FN].IsDir:=False; Inc(FN);
    End;
   End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 For I:=1 To FN-1 Do Begin
  T:=FEnt[I]; J:=I-1;
  While(J>=0)And((FEnt[J].IsDir<T.IsDir)Or((FEnt[J].IsDir=T.IsDir)And(UpStr(FEnt[J].Name)>UpStr(T.Name))))Do Begin
   FEnt[J+1]:=FEnt[J]; Dec(J);
  End;
  FEnt[J+1]:=T;
 End;
End;

Procedure GoDir(Const D:String);
Var S:String;
Begin
 S:=D;
 If(Length(S)>1)And((S[Length(S)]='\')Or(S[Length(S)]='/'))Then Begin
  If Not((Length(S)=3)And(S[2]=':'))Then Delete(S,Length(S),1);
 End;
 {$I-}ChDir(S);{$I+}
 If IOResult<>0 Then ;
End;

{ Mode : 0 ouvrir, 1 enregistrer, 2 exporter BMP, 3 exporter liste }
Function FileDialog(Mode:Integer;Var Name:String):Boolean;
Const LR=13;
Var
 X,Y,W,H,Top,Sel,Flt,NFlt,I,LastSel:Integer;
 Dir,Fld,Msg,Ttl:String;
 Done,OK,Dirty,Ext:Boolean;
 K:Char;
 Sv:TSave;
 LastT:LongInt;
 Fresh:Boolean;
 Procedure Rescan;
 Var S:String;
 Begin
  GetDir(0,S); Dir:=S;
  ScanDir(Flt,Mode);
  Top:=0; Sel:=-1; Dirty:=True;
 End;
 Function FltName:String;
 Begin
  If Mode=0 Then Begin
   Case Flt Of 0:FltName:='LDR/MPD'; 1:FltName:='DAT'; Else FltName:='Tous'; End;
  End
   Else If Mode=1 Then Begin If Flt=0 Then FltName:='LDR' Else FltName:='MPD'; End
   Else If Mode=2 Then FltName:='BMP' Else FltName:='TXT';
 End;
 Procedure Paint;
 Var J,R:Integer; S:String;
 Begin
  MouseOff;
  DrawWin(X,Y,W,H,Ttl);
  S:=Dir;
  If Length(S)>54 Then S:='...'+Copy(S,Length(S)-50,51);
  TxtOut(X+10,Y+22,S,UI_DK);
  Sunken(X+10,Y+36,X+W-139,Y+38+LR*12,15);
  For J:=0 To LR-1 Do Begin
   R:=Top+J;
   If R<FN Then Begin
    If R=Sel Then Begin Box(X+11,Y+37+J*12,X+W-152,Y+37+J*12+11,UI_SEL); SetColor(15); End Else SetColor(UI_DK);
    If FEnt[R].IsDir Then OutTextXY(X+14,Y+39+J*12,'['+FEnt[R].Name+']')
    Else OutTextXY(X+14,Y+39+J*12,FEnt[R].Name);
   End;
  End;
  DrawVScroll(X+W-151,Y+36,LR*12+3,Top,FN,LR);
  If Mode=0 Then DrawBtn(X+W-125,Y+36,115,22,'Ouvrir',False) Else DrawBtn(X+W-125,Y+36,115,22,'Enregistrer',False);
  DrawBtn(X+W-125,Y+64,115,22,'Annuler',False);
  DrawBtn(X+W-125,Y+98,115,22,'Type : '+FltName,False);
  DrawBtn(X+W-125,Y+126,115,22,'Dossier parent',False);
  DrawBtn(X+W-125,Y+154,115,22,'Exemples',False);
  TxtOut(X+10,Y+H-46,'Nom :',UI_DK);
  Sunken(X+54,Y+H-50,X+W-139,Y+H-34,15);
  S:=Fld+'_';
  If Length(S)>40 Then S:=Copy(S,Length(S)-39,40);
  TxtOut(X+58,Y+H-45,S,UI_DK);
  TxtOut(X+10,Y+H-24,Fx(Msg),UI_DK);
  MouseOn;
  Dirty:=False;
 End;
 Procedure Accept;
 Var S,E:String; Go:Boolean;
 Begin
  If Fld='' Then Begin
   If(Sel>=0)And(Sel<FN)Then Fld:=FEnt[Sel].Name Else Exit;
  End;
  If(Sel>=0)And(Sel<FN)And FEnt[Sel].IsDir And(Fld=FEnt[Sel].Name)Then Begin
   GoDir(Fld); Fld:=''; Msg:=''; Rescan; Exit;
  End;
  S:=Fld;
  E:=ExtOf(S);
  If E='' Then Begin
   Case Mode Of
    0:If(Not FileOK(S))And FileOK(S+'.LDR')Then S:=S+'.LDR'
      Else If(Not FileOK(S))And FileOK(S+'.MPD')Then S:=S+'.MPD';
    1:If Flt=0 Then S:=S+'.LDR' Else S:=S+'.MPD';
    2:S:=S+'.BMP';
    3:S:=S+'.TXT';
   End;
  End;
  Go:=True;
  If Mode=0 Then Begin
   If Not FileOK(S)Then Begin Msg:='Fichier introuvable.'; Go:=False; Dirty:=True; End;
  End
   Else If FileOK(S)Then Begin
    If AskBox('Remplacer','Le fichier existe d\ej\a.|Le remplacer ?',1)=0 Then Go:=False;
    FullRedraw:=False;
    Dirty:=True;
   End;
  If Go Then Begin
   Name:=FExpand(S); OK:=True; Done:=True;
   GetDir(0,LastOpenDir);
  End;
 End;
 Procedure Activate(N:Integer);
 Begin
  If(N<0)Or(N>=FN)Then Exit;
  If FEnt[N].IsDir Then Begin
   GoDir(FEnt[N].Name); Fld:=''; Msg:=''; Rescan;
  End
   Else Begin Fld:=FEnt[N].Name; Accept; End;
 End;
Begin
 W:=500; H:=LR*12+104;
 X:=(ScreenW-W) Div 2; Y:=(ScreenH-H) Div 2;
 Case Mode Of
  0:Begin Ttl:='Ouvrir un mod\gle'; NFlt:=3; End;
  1:Begin Ttl:='Enregistrer le mod\gle sous'; NFlt:=2; End;
  2:Begin Ttl:='Exporter l''image BMP'; NFlt:=1; End;
 Else Begin Ttl:='Exporter la liste des pi\eces'; NFlt:=1; End;
 End;
 Flt:=0;
 If(Mode=1)And(ExtOf(DocFile)='.MPD')Then Flt:=1;
 Fld:='';
 If Mode<>0 Then Begin
  Fld:=BaseOf(DocFile);
  If Fld='' Then Fld:='MODELE';
  I:=Length(Fld); While(I>0)And(Fld[I]<>'.')Do Dec(I);
  If I>0 Then Fld:=Copy(Fld,1,I-1);
 End;
 Msg:='';
 Fresh:=Fld<>'';
 MouseOff;
 SaveRect(Sv,X,Y,X+W,Y+H);
 MouseOn;
 If(Mode<>0)And(DocFile<>'')And(DirOf(DocFile)<>'')Then GoDir(DirOf(DocFile))
 Else If LastOpenDir<>'' Then GoDir(LastOpenDir) Else If DirOK(PlanDir)Then GoDir(PlanDir);
 Rescan;
 Done:=False; OK:=False; LastT:=0; LastSel:=-1;
 WaitMouseUp;
 Paint;
 Repeat
  PollMouse;
  If Dirty Then Paint;
  If KeyPressed Then Begin
   K:=ReadKeyEx(Ext);
   If Ext Then Begin
    If(K=#72)And(Sel>0)Then Dec(Sel) Else If(K=#80)And(Sel<FN-1)Then Inc(Sel);
    If Sel<Top Then Top:=Sel;
    If Sel>=Top+LR Then Top:=Sel-LR+1;
    If Sel>=0 Then Fld:='';
    Dirty:=True;
   End
    Else Case K Of
     #13:Accept;
     #27:Done:=True;
     #8:Begin If Length(Fld)>0 Then Delete(Fld,Length(Fld),1); Fresh:=False; Dirty:=True; End;
    Else If(K>=' ')And(Length(Fld)<38)Then Begin
     If Fresh Then Fld:='';
     Fresh:=False;
     Fld:=Fld+K; Dirty:=True;
    End;
    End;
  End;
  If((MB And 1)<>0)And((OldMB And 1)=0)Then Begin
   If InRect(MX,MY,X+11,Y+37,W-152,LR*12)Then Begin
    I:=Top+(MY-Y-37) Div 12;
    If I<FN Then Begin
     If(I=LastSel)And(Abs(Ticks-LastT)<45)Then Activate(I)
     Else Begin Sel:=I; Fld:=''; If Not FEnt[I].IsDir Then Fld:=FEnt[I].Name; End;
     LastSel:=I; LastT:=Ticks;
     Dirty:=True;
    End;
   End
    Else If InRect(MX,MY,X+W-151,Y+36,12,LR*12+3)Then Begin
     Top:=VScrollClick(Y+36,LR*12+3,Top,FN,LR,MY); Dirty:=True;
    End
    Else If InRect(MX,MY,X+W-125,Y+36,115,22)Then Accept
    Else If InRect(MX,MY,X+W-125,Y+64,115,22)Then Done:=True
    Else If InRect(MX,MY,X+W-125,Y+98,115,22)Then Begin Flt:=(Flt+1) Mod NFlt; Rescan; End
    Else If InRect(MX,MY,X+W-125,Y+126,115,22)Then Begin GoDir('..'); Fld:=''; Rescan; End
    Else If InRect(MX,MY,X+W-125,Y+154,115,22)Then Begin GoDir(PlanDir); Fld:=''; Rescan; End;
  End;
  OldMB:=MB;
  Delay(10);
 Until Done;
 WaitMouseUp;
 MouseOff;
 If Not RestoreRect(Sv)Then FullRedraw:=True;
 MouseOn;
 FileDialog:=OK;
End;

Procedure HelpDialog;
Var Ln:Array[0..19] Of String; N,W,H,X,Y,I:Integer; Sv:TSave; Done,Ext:Boolean;
Begin
 Ln[0]:=Fx('Souris : clic gauche = s\electionner / d\eplacer / poser une pi\ece');
 Ln[1]:=Fx('Glisser bouton droit = orbite  -  bouton milieu = panoramique');
 Ln[2]:=Fx('Fl\eches : d\eplacer la s\election (grille de 20)');
 Ln[3]:=Fx('PgHaut / PgBas : monter / descendre de 8 (plaque)');
 Ln[4]:=Fx('Debut / Fin : monter / descendre de 24 (brique)');
 Ln[5]:=Fx('x X y Y z Z : pivoter de 90 degr\es   -   Suppr : supprimer');
 Ln[6]:=Fx('Ctrl+C / X / V : copier, couper, coller   -   B : dupliquer');
 Ln[7]:=Fx('Ctrl+Z / Y : annuler, r\etablir   -   Ctrl+A : tout   -   Ctrl+D : rien');
 Ln[8]:=Fx('+ - : zoom   F : ajuster   0..6 : vues   Tab : vue suivante   V : 1/4 vues');
 Ln[9]:=Fx('P : perspective   G : grille   E : ar\etes   W : filaire   T : tenons');
 Ln[10]:=Fx('H : masquer   M : mod\gle principal   Echap : outil de s\election');
 Ln[11]:=Fx(', . : \etape pr\ec\edente / suivante   [ ] : premi\ere / derni\ere');
 Ln[12]:=Fx('F2 F3 F4 : panneaux   Inser : poser la pi\ece   F10 : quitter');
 N:=13;
 W:=240;
 For I:=0 To N-1 Do If Length(Ln[I])*8+30>W Then W:=Length(Ln[I])*8+30;
 If W>ScreenW-8 Then W:=ScreenW-8;
 H:=N*13+64;
 X:=(ScreenW-W) Div 2; Y:=(ScreenH-H) Div 2;
 MouseOff;
 SaveRect(Sv,X,Y,X+W,Y+H);
 DrawWin(X,Y,W,H,'Raccourcis clavier et souris');
 For I:=0 To N-1 Do TxtOut(X+14,Y+26+I*13,Ln[I],UI_DK);
 DrawBtn(X+W Div 2-35,Y+H-30,70,20,'OK',False);
 MouseOn;
 WaitMouseUp;
 Done:=False;
 Repeat
  PollMouse;
  If KeyPressed Then Begin ReadKeyEx(Ext); Done:=True; End;
  If((MB And 1)<>0)And((OldMB And 1)=0)Then Done:=True;
  OldMB:=MB;
  Delay(10);
 Until Done;
 WaitMouseUp;
 MouseOff;
 If Not RestoreRect(Sv)Then FullRedraw:=True;
 MouseOn;
End;

{ ====================================================================== }
{ Edition des pieces                                                     }
{ ====================================================================== }

Procedure Touch;
Begin
 NeedViews:=True; NeedDock:=True; NeedStatus:=True;
End;

Procedure SetMsg(Const S:String);
Begin
 StatusMsg:=S;
 NeedStatus:=True;
End;

Procedure SnapRot(Var M:TMat);
Var I,J:Integer;
Begin
 For I:=0 To 2 Do For J:=0 To 2 Do Begin
  If Abs(M.R[I,J])<0.00001 Then M.R[I,J]:=0;
  If Abs(M.R[I,J]-1)<0.00001 Then M.R[I,J]:=1;
  If Abs(M.R[I,J]+1)<0.00001 Then M.R[I,J]:=-1;
 End;
End;

{ Pas d'aimantation selon la parite du nombre de tenons }
Function SnapAxis(V:Real;Size:Integer):Real;
Begin
 If Odd(Size)Then SnapAxis:=Round((V-10)/20)*20+10
 Else SnapAxis:=Round(V/20)*20;
End;

{ Taille du corps (en tenons) et fond, pour la matrice de rotation M }
Procedure BodyInfo(Const Nm:String;Const R:TMat;Var SX,SZ:Integer;Var MinY,MaxY,HX,HZ:Real);
Var Q:PPiece; Mn,Mx:TVec; Rot:TMat;
Begin
 New(Q);
 FillChar(Q^,SizeOf(TPiece),0);
 Q^.Name:=Nm; Q^.M:=R; Q^.M.T.X:=0; Q^.M.T.Y:=0; Q^.M.T.Z:=0;
 PieceBounds(Q,True,Mn,Mx);
 Dispose(Q);
 SX:=Round((Mx.X-Mn.X)/20); SZ:=Round((Mx.Z-Mn.Z)/20);
 If SX<1 Then SX:=1; If SZ<1 Then SZ:=1;
 MinY:=Mn.Y; MaxY:=Mx.Y;
 HX:=(Mx.X-Mn.X)/2; HZ:=(Mx.Z-Mn.Z)/2;
End;

{ Calcule la position d'insertion (InsX,InsY,InsZ) pour le point monde (X,Z) }
Procedure ComputeInsert(WX,WZ:Real);
Var
 SX,SZ:Integer; MinY,MaxY,HX,HZ,Top,CX,CZ:Real;
 Q:PPiece; Mn,Mx:TVec; Q2:PPiece;
Begin
 BodyInfo(CurPart,InsM,SX,SZ,MinY,MaxY,HX,HZ);
 InsX:=SnapAxis(WX,SX); InsZ:=SnapAxis(WZ,SZ);
 { centre du corps : approximation par l'origine de la piece }
 Top:=GroundY;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If PieceVisible(Q)Then Begin
   PieceBounds(Q,True,Mn,Mx);
   If(Mn.X<InsX+HX-0.5)And(Mx.X>InsX-HX+0.5)And(Mn.Z<InsZ+HZ-0.5)And(Mx.Z>InsZ-HZ+0.5)Then
    If Mn.Y<Top Then Top:=Mn.Y;
  End;
  Q:=Q^.Next;
 End;
 InsY:=Top-MaxY;
End;

Procedure UpdateGhost;
Begin
 If GhostPiece=Nil Then Begin
  New(GhostPiece);
  FillChar(GhostPiece^,SizeOf(TPiece),0);
 End;
 GhostPiece^.Name:=CurPart; GhostPiece^.Col:=CurColor;
 GhostPiece^.M:=InsM;
 GhostPiece^.M.T.X:=InsX; GhostPiece^.M.T.Y:=InsY; GhostPiece^.M.T.Z:=InsZ;
 GhostPiece^.Part:=Nil; GhostPiece^.Epoch:=-1;
 GhostPiece^.Step:=1;
End;

Procedure DoInsert;
Var Q:PPiece; Mt:TMat;
Begin
 If CurPart='' Then Exit;
 PushUndo;
 ClearSel;
 Mt:=InsM;
 Mt.T.X:=InsX; Mt.T.Y:=InsY; Mt.T.Z:=InsZ;
 If FindModel(CurPart)>=0 Then Q:=AddPiece(CurModel,CurPart,16,Mt,Models[CurModel].CurStep)
 Else Q:=AddPiece(CurModel,LoStr(CurPart),CurColor,Mt,Models[CurModel].CurStep);
 Q^.Sel:=True;
 ComputeGround;
 Touch;
End;

Procedure MoveSel(DX,DY,DZ:Real);
Var Q:PPiece;
Begin
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Begin
   Q^.M.T.X:=Q^.M.T.X+DX; Q^.M.T.Y:=Q^.M.T.Y+DY; Q^.M.T.Z:=Q^.M.T.Z+DZ;
  End;
  Q:=Q^.Next;
 End;
End;

Procedure RotateSel(Axis:Integer;Deg:Real);
Var Q:PPiece; Rt:TMat; P:TVec; N:Integer; Cx,Cy,Cz:Real; T:TVec;
Begin
 If Tool=TL_INSERT Then Begin
  MatRotAxis(Axis,Deg,Rt);
  MatMul(Rt,InsM,InsM); SnapRot(InsM);
  InsM.T.X:=0; InsM.T.Y:=0; InsM.T.Z:=0;
  Touch;
  Exit;
 End;
 N:=SelCount;
 If N=0 Then Exit;
 PushUndo;
 Cx:=0; Cy:=0; Cz:=0;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Begin Cx:=Cx+Q^.M.T.X; Cy:=Cy+Q^.M.T.Y; Cz:=Cz+Q^.M.T.Z; End;
  Q:=Q^.Next;
 End;
 VSet(P,Round(Cx/N/10)*10,Round(Cy/N/4)*4,Round(Cz/N/10)*10);
 If N=1 Then Begin Q:=FirstSel; P:=Q^.M.T; End;
 MatRotAxis(Axis,Deg,Rt);
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Begin
   T.X:=Q^.M.T.X-P.X; T.Y:=Q^.M.T.Y-P.Y; T.Z:=Q^.M.T.Z-P.Z;
   MatApply(Rt,T,T);
   Q^.M.T.X:=Round((T.X+P.X)*1000)/1000; Q^.M.T.Y:=Round((T.Y+P.Y)*1000)/1000;
   Q^.M.T.Z:=Round((T.Z+P.Z)*1000)/1000;
   MatMul(Rt,Q^.M,Q^.M);
   { MatMul a aussi transforme la translation : on la restaure }
   Q^.M.T.X:=Round((T.X+P.X)*1000)/1000; Q^.M.T.Y:=Round((T.Y+P.Y)*1000)/1000;
   Q^.M.T.Z:=Round((T.Z+P.Z)*1000)/1000;
   SnapRot(Q^.M);
  End;
  Q:=Q^.Next;
 End;
 Touch;
End;

Procedure DeleteSel;
Var Q,N:PPiece;
Begin
 If SelCount=0 Then Exit;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  N:=Q^.Next;
  If Q^.Sel Then RemovePiece(CurModel,Q);
  Q:=N;
 End;
 Touch;
End;

Procedure ClearClip;
Begin
 FreeList(Clip); Clip:=Nil; ClipN:=0;
End;

Procedure CopySel;
Var Q,N,T:PPiece;
Begin
 If SelCount=0 Then Exit;
 ClearClip;
 T:=Nil;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Begin
   N:=CopyPiece(Q);
   N^.Prev:=T;
   If T<>Nil Then T^.Next:=N Else Clip:=N;
   T:=N; Inc(ClipN);
  End;
  Q:=Q^.Next;
 End;
 SetMsg(IntStr(ClipN)+Fx(' pi\ece(s) copi\ee(s)'));
End;

Procedure PasteClip(DX,DZ:Real);
Var Q,N:PPiece;
Begin
 If ClipN=0 Then Exit;
 PushUndo;
 ClearSel;
 Q:=Clip;
 While Q<>Nil Do Begin
  N:=AddPiece(CurModel,Q^.Name,Q^.Col,Q^.M,Models[CurModel].CurStep);
  N^.M.T.X:=N^.M.T.X+DX; N^.M.T.Z:=N^.M.T.Z+DZ;
  N^.Sel:=True;
  Q:=Q^.Next;
 End;
 Touch;
End;

Procedure SelectAll;
Var Q:PPiece;
Begin
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin Q^.Sel:=PieceVisible(Q); Q:=Q^.Next; End;
 Touch;
End;

Procedure SelectInvert;
Var Q:PPiece;
Begin
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If PieceVisible(Q)Then Q^.Sel:=Not Q^.Sel Else Q^.Sel:=False;
  Q:=Q^.Next;
 End;
 Touch;
End;

Procedure SelectSame(ByColor:Boolean);
Var Q,F:PPiece;
Begin
 F:=FirstSel;
 If F=Nil Then Exit;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If PieceVisible(Q)Then Begin
   If ByColor Then Begin If Q^.Col=F^.Col Then Q^.Sel:=True; End
   Else If UpStr(Q^.Name)=UpStr(F^.Name)Then Q^.Sel:=True;
  End;
  Q:=Q^.Next;
 End;
 Touch;
End;

Procedure ApplyColorSel(Code:Integer);
Var Q:PPiece;
Begin
 If SelCount=0 Then Exit;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel And(FindModel(Q^.Name)<0)Then Q^.Col:=Code;
  Q:=Q^.Next;
 End;
 Touch;
End;

Procedure HideSel;
Var Q:PPiece;
Begin
 If SelCount=0 Then Exit;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Begin Q^.Hidden:=True; Q^.Sel:=False; End;
  Q:=Q^.Next;
 End;
 Touch;
End;

Procedure ShowAllPieces;
Var Q:PPiece;
Begin
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin Q^.Hidden:=False; Q:=Q^.Next; End;
 Touch;
End;

{ ---------------------------- Etapes ------------------------------- }

Procedure SetStep(S:Integer);
Var Mx:Integer;
Begin
 Mx:=MaxStep(CurModel)+1;
 If S>Mx Then S:=Mx;
 If S<1 Then S:=1;
 Models[CurModel].CurStep:=S;
 { deselectionne ce qui devient invisible }
 Touch;
End;

Procedure InsertStep;
Var Q:PPiece;
Begin
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Step>Models[CurModel].CurStep Then Inc(Q^.Step);
  Q:=Q^.Next;
 End;
 Inc(Models[CurModel].CurStep);
 Touch;
End;

Procedure DeleteStep;
Var Q:PPiece; C:Integer;
Begin
 C:=Models[CurModel].CurStep;
 If MaxStep(CurModel)<=1 Then Exit;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Step>C Then Dec(Q^.Step);
  Q:=Q^.Next;
 End;
 If C>MaxStep(CurModel)Then Models[CurModel].CurStep:=MaxStep(CurModel);
 Touch;
End;

Procedure SelToStep;
Var Q:PPiece;
Begin
 If SelCount=0 Then Exit;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Q^.Step:=Models[CurModel].CurStep;
  Q:=Q^.Next;
 End;
 Touch;
End;

{ ---------------------------- Sous-modeles ------------------------- }

Procedure SwitchModel(I:Integer);
Begin
 If(I<0)Or(I>=ModelCount)Or(I=CurModel)Then Exit;
 ClearSel;
 CurModel:=I;
 If Models[I].CurStep<1 Then Models[I].CurStep:=1;
 FitAllViews;
 PartSel:=PartSel;
 Touch;
 NeedTools:=True;
End;

Function UniqueModelName(Const S:String):String;
Var N:String; K:Integer;
Begin
 N:=S;
 If ExtOf(N)='' Then N:=N+'.LDR';
 K:=1;
 While FindModel(N)>=0 Do Begin
  Inc(K);
  N:=ForceExt(S,'')+IntStr(K)+'.LDR';
 End;
 UniqueModelName:=Copy(N,1,40);
End;

Procedure NewSubModel(FromSel:Boolean);
Var Nm:String; I,N:Integer; Q,P,Nx,R:PPiece; Mt:TMat; MnStep:Integer;
Begin
 If ModelCount>=MAXMOD Then Begin AskBox('Sous-mod\gle','Nombre maximal de mod\gles atteint.',0); Exit; End;
 If FromSel And(SelCount=0)Then Begin
  AskBox('Sous-mod\gle','S\electionner d''abord des pi\eces.',0); Exit;
 End;
 Nm:='SOUSMOD'+IntStr(ModelCount);
 If Not InputBox('Nouveau sous-mod\gle','Nom du sous-mod\gle :',Nm,30)Then Exit;
 If TrimStr(Nm)='' Then Exit;
 Nm:=UniqueModelName(TrimStr(Nm));
 PushUndo;
 I:=NewModel(Nm);
 If I<0 Then Exit;
 If FromSel Then Begin
  MnStep:=9999;
  Q:=Models[CurModel].First;
  While Q<>Nil Do Begin
   Nx:=Q^.Next;
   If Q^.Sel Then Begin
    If Q^.Step<MnStep Then MnStep:=Q^.Step;
    P:=AddPiece(I,Q^.Name,Q^.Col,Q^.M,Q^.Step);
    RemovePiece(CurModel,Q);
   End;
   Q:=Nx;
  End;
  MatIdent(Mt);
  R:=AddPiece(CurModel,Nm,16,Mt,MnStep);
  R^.Sel:=True;
  Models[I].CurStep:=MaxStep(I);
  Touch;
 End
  Else Begin
   SwitchModel(I);
  End;
 NeedTools:=True;
End;

Procedure InsertSubModel;
Var I,K,Sel:Integer;
Begin
 K:=0; Sel:=0;
 For I:=0 To ModelCount-1 Do
  If I<>CurModel Then Begin ListItems[K]:=Models[I].Name; Inc(K); End;
 If K=0 Then Begin AskBox('Sous-mod\gle','Aucun autre mod\gle disponible.',0); Exit; End;
 If Not ListDialog('Ins\erer un sous-mod\gle',K,Sel)Then Exit;
 CurPart:=ListItems[Sel];
 CurPartDesc:=Copy(Fx('Sous-mod\gle'),1,44);
 Tool:=TL_INSERT;
 NeedTools:=True; Touch;
End;

Procedure EditSubModel;
Var I,Sel:Integer;
Begin
 For I:=0 To ModelCount-1 Do ListItems[I]:=Models[I].Name;
 Sel:=CurModel;
 If ListDialog('Modifier un mod\gle',ModelCount,Sel)Then SwitchModel(Sel);
End;

Procedure DeleteSubModel;
Var I,J:Integer; Q,N:PPiece; Nm:String;
Begin
 If CurModel=0 Then Exit;
 If AskBox('Supprimer','Supprimer le sous-mod\gle '+Models[CurModel].Name+' ?',1)<>1 Then Exit;
 PushUndo;
 Nm:=Models[CurModel].Name;
 For I:=0 To ModelCount-1 Do If I<>CurModel Then Begin
  Q:=Models[I].First;
  While Q<>Nil Do Begin
   N:=Q^.Next;
   If UpStr(Q^.Name)=UpStr(Nm)Then RemovePiece(I,Q);
   Q:=N;
  End;
 End;
 FreeList(Models[CurModel].First);
 For J:=CurModel To ModelCount-2 Do Models[J]:=Models[J+1];
 Models[ModelCount-1].Used:=False; Models[ModelCount-1].First:=Nil; Models[ModelCount-1].Last:=Nil;
 Models[ModelCount-1].Count:=0; Models[ModelCount-1].Name:='';
 Dec(ModelCount);
 CurModel:=0;
 ClearSel;
 FitAllViews;
 Touch; NeedTools:=True;
End;

{ ---------------------------- Documents ---------------------------- }

Procedure ResetEditState;
Begin
 ClearSel;
 ClearClip;
 PropField:=-1; TimeTop:=0; SearchEdit:=False;
 InsValid:=False;
 FlushCache;
End;

Procedure DoNew;
Begin
 NewDocument;
 ResetEditState;
 FitAllViews;
 StatusMsg:='';
 Touch; NeedTools:=True;
End;

Procedure ExportBMP(Const Path:String);
Var
 F:File;
 V:TView;
 W,H,X,Y,Pad,C:Integer;
 Row:Array[0..2047] Of Byte;
 Hd:Array[0..53] Of Byte;
 Sz:LongInt;
 I:Integer;
Begin
 V:=Views[ActiveView];
 W:=V.X2-V.X1-1; H:=V.Y2-V.Y1-1;
 If W>680 Then W:=680;
 Pad:=(4-(W*3) Mod 4) Mod 4;
 Sz:=54+LongInt(W*3+Pad)*H;
 FillChar(Hd,SizeOf(Hd),0);
 Hd[0]:=Ord('B'); Hd[1]:=Ord('M');
 Move(Sz,Hd[2],4);
 Hd[10]:=54; Hd[14]:=40;
 Sz:=W; Move(Sz,Hd[18],4);
 Sz:=H; Move(Sz,Hd[22],4);
 Hd[26]:=1; Hd[28]:=24;
 {$I-}
 Assign(F,Path); Rewrite(F,1);
 {$I+}
 If IOResult<>0 Then Begin AskBox('Exporter','Impossible de cr\eer le fichier.',0); Exit; End;
 BlockWrite(F,Hd,54);
 MouseOff;
 For Y:=H-1 DownTo 0 Do Begin
  For X:=0 To W-1 Do Begin
   C:=GetPixel(V.X1+1+X,V.Y1+1+Y);
   If C>255 Then C:=0;
   Row[X*3]:=PalB[C]; Row[X*3+1]:=PalG[C]; Row[X*3+2]:=PalR[C];
  End;
  For I:=0 To Pad-1 Do Row[W*3+I]:=0;
  BlockWrite(F,Row,W*3+Pad);
 End;
 MouseOn;
 Close(F);
 SetMsg('Image enregistr\ee : '+BaseOf(Path));
End;

Type
 TAgg=Record N:String[40]; C,Q:Integer; End;
 TAggArr=Array[0..299] Of TAgg;
 PAggArr=^TAggArr;

Var
 Agg:PAggArr;
 AggN:Integer;

Procedure AggAdd(Const Nm:String;Col,Mult:Integer);
Var I:Integer;
Begin
 For I:=0 To AggN-1 Do
  If(Agg^[I].C=Col)And(UpStr(Agg^[I].N)=UpStr(Nm))Then Begin Inc(Agg^[I].Q,Mult); Exit; End;
 If AggN<300 Then Begin
  Agg^[AggN].N:=Nm; Agg^[AggN].C:=Col; Agg^[AggN].Q:=Mult; Inc(AggN);
 End;
End;

Procedure AggModel(M:Integer;Mult,Depth:Integer);
Var Q:PPiece; S:Integer;
Begin
 If Depth>6 Then Exit;
 Q:=Models[M].First;
 While Q<>Nil Do Begin
  S:=FindModel(Q^.Name);
  If S>=0 Then AggModel(S,Mult,Depth+1) Else AggAdd(Q^.Name,Q^.Col,Mult);
  Q:=Q^.Next;
 End;
End;

{ Texte sans accents pour les fichiers d'export }
Function Plain(Const S:String):String;
Var I:Integer; R:String;
Begin
 R:=S;
 For I:=1 To Length(R) Do
  Case R[I] Of
   #130,#138,#136:R[I]:='e';
   #133:R[I]:='a';
   #135:R[I]:='c';
   #147:R[I]:='o';
   #151:R[I]:='u';
   #140:R[I]:='i';
   #144:R[I]:='E';
  End;
 Plain:=R;
End;

Procedure ExportParts(Const Path:String);
Var F:Text; I,Tot:Integer;
Begin
 New(Agg); AggN:=0;
 AggModel(0,1,0);
 {$I-}
 Assign(F,Path); Rewrite(F);
 {$I+}
 If IOResult<>0 Then Begin Dispose(Agg); AskBox('Exporter','Impossible de cr\eer le fichier.',0); Exit; End;
 WriteLn(F,'LISTE DES PIECES - ',BaseOf(DocFile));
 WriteLn(F,'Qte  Couleur                 Piece         Description');
 WriteLn(F,'---------------------------------------------------------------');
 Tot:=0;
 For I:=0 To AggN-1 Do Begin
  WriteLn(F,PadR(IntStr(Agg^[I].Q),5),PadR(Plain(ColName[ColIdx(Agg^[I].C)]),23),' ',
          PadR(UpStr(Agg^[I].N),13),' ',PartDescByName(Agg^[I].N));
  Inc(Tot,Agg^[I].Q);
 End;
 WriteLn(F,'---------------------------------------------------------------');
 WriteLn(F,'Total : ',Tot,' pieces, ',AggN,' references');
 Close(F);
 Dispose(Agg);
 SetMsg('Liste enregistr\ee : '+BaseOf(Path));
End;

Function DoSaveAs:Boolean;
Var Nm:String;
Begin
 DoSaveAs:=False;
 Nm:=DocFile;
 If Not FileDialog(1,Nm)Then Exit;
 If(ModelCount>1)And(ExtOf(Nm)<>'.MPD')Then Begin
  Nm:=ForceExt(Nm,'.MPD');
  AskBox('Enregistrer','Le mod\gle contient des sous-mod\gles :|enregistrement au format MPD.',0);
 End;
 If ModelCount=1 Then Models[0].Name:=Copy(BaseOf(Nm),1,40);
 If SaveDoc(Nm)Then Begin
  DocFile:=Nm;
  Modified:=False;
  DoSaveAs:=True;
  SetMsg('Enregistr\e : '+BaseOf(Nm));
 End
  Else AskBox('Enregistrer','Erreur d''\ecriture du fichier.',0);
 NeedTools:=True;
End;

Function DoSave:Boolean;
Begin
 If(DocFile='')Or(ExtOf(DocFile)='.DAT')Or((ModelCount>1)And(ExtOf(DocFile)<>'.MPD'))Then DoSave:=DoSaveAs
 Else If SaveDoc(DocFile)Then Begin
  Modified:=False;
  SetMsg('Enregistr\e : '+BaseOf(DocFile));
  NeedTools:=True;
  DoSave:=True;
 End
  Else Begin
   AskBox('Enregistrer','Erreur d''\ecriture du fichier.',0);
   DoSave:=False;
  End;
End;

Function ConfirmDiscard:Boolean;
Var R:Integer;
Begin
 ConfirmDiscard:=True;
 If Not Modified Then Exit;
 R:=AskBox('LEOCAD','Le mod\gle a \et\e modifi\e.|Enregistrer les changements ?',2);
 If R=0 Then Exit;
 If R=-1 Then Begin ConfirmDiscard:=False; Exit; End;
 ConfirmDiscard:=DoSave;
End;

Procedure OpenPath(Const Nm:String);
Begin
 If LoadDoc(Nm)Then Begin
  ResetEditState;
  FitAllViews;
  StatusMsg:='';
  Touch; NeedTools:=True;
 End
  Else AskBox('Ouvrir','Impossible de lire le fichier :|'+BaseOf(Nm),0);
End;

Procedure DoOpen;
Var Nm:String;
Begin
 If Not ConfirmDiscard Then Exit;
 Nm:='';
 If FileDialog(0,Nm)Then OpenPath(Nm);
End;

Procedure DoInfo;
Var Q:PPiece; I,Tot,N:Integer; S:String;
Begin
 Tot:=0;
 For I:=0 To ModelCount-1 Do Inc(Tot,Models[I].Count);
 S:='Fichier : '+BaseOf(DocFile)+'|Mod\gles : '+IntStr(ModelCount)+'|Pi\eces (tous mod\gles) : '+IntStr(Tot)+
    '|\Etapes : '+IntStr(MaxStep(CurModel))+'|Pi\eces du mod\gle : '+IntStr(Models[CurModel].Count)+
    '|Biblioth\gque : '+IntStr(CatCount)+' pi\eces|Polygones : '+IntStr(PolyN)+
    '|M\emoire libre : '+IntStr(MemAvail Div 1024)+' Ko';
 AskBox('Informations',S,0);
End;

Procedure DoReindex;
Begin
 If AskBox('Biblioth\gque','Reconstruire l''index de la biblioth\gque ?|(lecture de tous les fichiers .DAT)',1)<>1 Then Exit;
 MouseOff;
 ScanLibrary;
 BuildCategories;
 CatSel:=0; CatTop:=0; SearchStr:='';
 RefilterParts;
 MouseOn;
 AskBox('Biblioth\gque',IntStr(CatCount)+' pi\eces index\ees.',0);
 Touch;
End;

Procedure DoQuit;
Begin
 If ConfirmDiscard Then Running:=False;
End;

{ ---------------------------- Vues --------------------------------- }

Procedure ToggleViews;
Begin
 If ViewCount=1 Then ViewCount:=4 Else ViewCount:=1;
 FitAllViews;
 NeedViews:=True; NeedTools:=True;
End;

Procedure SetPreset(K:Integer);
Begin
 ViewPreset(Views[ActiveView],K);
 ZoomFit(Views[ActiveView]);
 NeedViews:=True;
End;

Procedure CycleStuds;
Begin
 StudMode:=(StudMode+1) Mod 4;
 Case StudMode Of
  0:SetMsg('Tenons : automatique');
  1:SetMsg('Tenons : complets');
  2:SetMsg('Tenons : simplifi\es');
  3:SetMsg('Tenons : masqu\es');
 End;
 NeedViews:=True;
End;

Procedure SetPanel(P:Integer);
Begin
 PanelSel:=P;
 PropField:=-1; SearchEdit:=False;
 NeedDock:=True;
End;

{ ---------------------------- Menus : commandes -------------------- }

Procedure DoMenu(M,I:Integer);
Var Nm:String;
Begin
 Case M Of
  M_FILE:Case I Of
   0:If ConfirmDiscard Then DoNew;
   1:DoOpen;
   2:DoSave;
   3:DoSaveAs;
   5:Begin
    Nm:=BaseOf(DocFile);
    If FileDialog(2,Nm)Then Begin
     If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
     ExportBMP(Nm);
    End;
   End;
   6:Begin Nm:=''; If FileDialog(3,Nm)Then ExportParts(Nm); End;
   8:DoInfo;
   9:DoReindex;
   11:DoQuit;
  End;
  M_EDIT:Case I Of
   0:Begin DoUndo; ClearSel; Touch; NeedTools:=True; End;
   1:Begin DoRedo; ClearSel; Touch; NeedTools:=True; End;
   3:Begin CopySel; DeleteSel; End;
   4:CopySel;
   5:PasteClip(20,20);
   6:DeleteSel;
   8:SelectAll;
   9:Begin ClearSel; Touch; End;
   10:SelectInvert;
   11:SelectSame(True);
   12:SelectSame(False);
  End;
  M_VIEW:Case I Of
   0:ToggleViews;
   1:Begin Views[ActiveView].Persp:=Not Views[ActiveView].Persp; ZoomFit(Views[ActiveView]); NeedViews:=True; End;
   3:SetPreset(0);
   4:SetPreset(1);
   5:SetPreset(2);
   6:SetPreset(3);
   7:SetPreset(4);
   8:SetPreset(5);
   9:SetPreset(6);
   11:Begin ZoomView(Views[ActiveView],0.8); NeedViews:=True; End;
   12:Begin ZoomView(Views[ActiveView],1.25); NeedViews:=True; End;
   13:Begin ZoomFit(Views[ActiveView]); NeedViews:=True; End;
   15:Begin GridOn:=Not GridOn; NeedViews:=True; NeedTools:=True; End;
   16:Begin EdgesOn:=Not EdgesOn; NeedViews:=True; End;
   17:Begin WireOn:=Not WireOn; NeedViews:=True; NeedTools:=True; End;
   18:CycleStuds;
   20:SetPanel(PN_PARTS);
   21:SetPanel(PN_PROPS);
   22:SetPanel(PN_TIME);
  End;
  M_PIECE:Case I Of
   0:Begin If CurPart<>'' Then Begin Tool:=TL_INSERT; NeedTools:=True; Touch; End Else SetMsg('Choisir d''abord une pi\ece.'); End;
   1:Begin CopySel; PasteClip(20,20); End;
   3:Begin If SelCount>0 Then Begin PushUndo; MoveSel(0,-8,0); Touch; End; End;
   4:Begin If SelCount>0 Then Begin PushUndo; MoveSel(0,8,0); Touch; End; End;
   5:Begin If SelCount>0 Then Begin PushUndo; MoveSel(0,-24,0); Touch; End; End;
   6:Begin If SelCount>0 Then Begin PushUndo; MoveSel(0,24,0); Touch; End; End;
   8:RotateSel(0,90);
   9:RotateSel(0,-90);
   10:RotateSel(1,90);
   11:RotateSel(1,-90);
   12:RotateSel(2,90);
   13:RotateSel(2,-90);
   15:ApplyColorSel(CurColor);
   16:HideSel;
   17:ShowAllPieces;
  End;
  M_STEP:Case I Of
   0:SetStep(Models[CurModel].CurStep+1);
   1:SetStep(Models[CurModel].CurStep-1);
   2:SetStep(1);
   3:SetStep(MaxStep(CurModel));
   5:InsertStep;
   6:DeleteStep;
   7:SelToStep;
  End;
  M_SUB:Case I Of
   0:NewSubModel(False);
   1:NewSubModel(True);
   2:InsertSubModel;
   4:EditSubModel;
   5:SwitchModel(0);
   6:DeleteSubModel;
  End;
  M_HELP:Case I Of
   0:HelpDialog;
   1:AskBox('A propos de LEOCAD','LEOCAD 1.00 - clone de LeoCAD|CAO de briques Lego en 3D (LDraw .LDR/.MPD)|Turbo Pascal 7 / Free Pascal|https://www.gladir.com/clonedraw',0);
  End;
 End;
 If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
 NeedStatus:=True;
End;

Procedure ToolbarClick(I:Integer);
Begin
 Case I Of
  0:DoMenu(M_FILE,0);
  1:DoMenu(M_FILE,1);
  2:DoMenu(M_FILE,2);
  3:DoMenu(M_EDIT,0);
  4:DoMenu(M_EDIT,1);
  5:Begin Tool:=TL_SELECT; NeedTools:=True; NeedViews:=True; End;
  6:DoMenu(M_PIECE,0);
  7:Begin Tool:=TL_ORBIT; NeedTools:=True; NeedViews:=True; End;
  8:Begin Tool:=TL_PAN; NeedTools:=True; NeedViews:=True; End;
  9:Begin Tool:=TL_ZOOM; NeedTools:=True; NeedViews:=True; End;
  10:DoMenu(M_VIEW,15);
  11:DoMenu(M_VIEW,17);
  12:DoMenu(M_VIEW,0);
  13:DoMenu(M_VIEW,13);
  14:DoMenu(M_STEP,2);
  15:DoMenu(M_STEP,1);
  16:DoMenu(M_STEP,0);
  17:DoMenu(M_STEP,3);
 End;
 NeedTools:=True;
End;

{ ====================================================================== }
{ Evenements : menus                                                     }
{ ====================================================================== }

Var
 MenuSv:TSave;
 DragMode,DragView,DragX,DragY,DragScroll:Integer;
 MoveAppX,MoveAppZ,MoveStartX,MoveStartZ,MovePlaneY:Real;
 MoveBegun:Boolean;
 HoverTB:Integer;
 OldMX,OldMY:Integer;
 RubOn:Boolean;
 RubX1,RubY1,RubX2,RubY2:Integer;

Procedure CloseMenu;
Begin
 If Not MenuActive Then Exit;
 MouseOff;
 If Not RestoreRect(MenuSv)Then FullRedraw:=True;
 MenuActive:=False;
 DrawMenuBar;
 MouseOn;
End;

Procedure OpenMenu(I:Integer);
Begin
 If MenuActive Then CloseMenu;
 UpdateMenuChecks;
 ActiveMenu:=I; ActiveMenuItem:=-1;
 MenuActive:=True;
 CalcMenuLeft(I);
 MouseOff;
 DrawMenuBar;
 SaveRect(MenuSv,MenuLeftX,MENU_H,MenuLeftX+Menus[I].Width+2,MENU_H+MenuH(I)+2);
 DrawMenu(I);
 MouseOn;
End;

Procedure MenuStep(Step:Integer);
Var N,K:Integer;
Begin
 N:=Menus[ActiveMenu].ItemCount;
 If ActiveMenuItem<0 Then Begin If Step>0 Then ActiveMenuItem:=-1 Else ActiveMenuItem:=N; End;
 For K:=1 To N Do Begin
  ActiveMenuItem:=ActiveMenuItem+Step;
  If ActiveMenuItem<0 Then ActiveMenuItem:=N-1;
  If ActiveMenuItem>=N Then ActiveMenuItem:=0;
  If(Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator)And Menus[ActiveMenu].Items[ActiveMenuItem].Enabled Then Exit;
 End;
End;

Procedure RunMenuItem(M,I:Integer);
Begin
 CloseMenu;
 If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
 If Menus[M].Items[I].Enabled Then DoMenu(M,I);
End;

{ ====================================================================== }
{ Evenements : vues                                                      }
{ ====================================================================== }

Function ViewAt(PX,PY:Integer):Integer;
Var I,N:Integer;
Begin
 ViewAt:=-1;
 If ViewCount=1 Then Begin
  If InRect(PX,PY,Views[ActiveView].X1,Views[ActiveView].Y1,Views[ActiveView].X2-Views[ActiveView].X1+1,
     Views[ActiveView].Y2-Views[ActiveView].Y1+1)Then ViewAt:=ActiveView;
 End
  Else
   For I:=0 To 3 Do
    If InRect(PX,PY,Views[I].X1,Views[I].Y1,Views[I].X2-Views[I].X1+1,Views[I].Y2-Views[I].Y1+1)Then ViewAt:=I;
End;

Procedure RubberXor;
Begin
 SetWriteMode(XORPut);
 SetColor(15);
 Rectangle(RubX1,RubY1,RubX2,RubY2);
 SetWriteMode(CopyPut);
End;

{ Met a jour la piece fantome pour la position ecran (vue V) }
Procedure UpdateInsert(V:Integer;PX,PY:Integer);
Var O,D:TVec; X,Z,Y0:Real; Own:Integer; Q:PPiece; Mn,Mx:TVec; RX,RY:Integer; Ok:Boolean;
Begin
 InsValid:=False;
 If(CurPart='')Or(V<0)Then Exit;
 RX:=PX-Views[V].X1; RY:=PY-Views[V].Y1;
 ComputeGround;
 Y0:=GroundY;
 If Models[CurModel].Count<=600 Then Begin
  Own:=PickPiece(Views[V],RX,RY);
  If Own>0 Then Begin
   Q:=PieceByIndex(Own);
   If Q<>Nil Then Begin PieceBounds(Q,True,Mn,Mx); Y0:=Mn.Y; End;
  End;
 End;
 ScreenRay(Views[V],RX,RY,O,D);
 Ok:=RayPlaneY(O,D,Y0,X,Z);
 If Not Ok Then Exit;
 ComputeInsert(X,Z);
 UpdateGhost;
 InsValid:=True;
End;

Procedure ViewPress(V,Btn:Integer);
Var RX,RY,Own:Integer; Q:PPiece; O,D:TVec; X,Z:Real;
Begin
 If V<>ActiveView Then Begin ActiveView:=V; NeedViews:=True; NeedTools:=True; End;
 RX:=MX-Views[V].X1; RY:=MY-Views[V].Y1;
 DragView:=V; DragX:=MX; DragY:=MY;
 StatusMsg:='';
 If Btn=2 Then Begin DragMode:=1; Exit; End;
 If Btn=4 Then Begin DragMode:=2; Exit; End;
 Case Tool Of
  TL_ORBIT:DragMode:=1;
  TL_PAN:DragMode:=2;
  TL_ZOOM:DragMode:=3;
  TL_INSERT:Begin
   UpdateInsert(V,MX,MY);
   If InsValid Then DoInsert;
  End;
 Else Begin
  Own:=PickPiece(Views[V],RX,RY);
  If Own>0 Then Begin
   Q:=PieceByIndex(Own);
   If Q<>Nil Then Begin
    If Not Q^.Sel Then Begin ClearSel; Q^.Sel:=True; End;
    DragMode:=4; MoveBegun:=False; MoveAppX:=0; MoveAppZ:=0;
    MovePlaneY:=Q^.M.T.Y;
    ScreenRay(Views[V],RX,RY,O,D);
    If RayPlaneY(O,D,MovePlaneY,X,Z)Then Begin MoveStartX:=X; MoveStartZ:=Z; End
    Else DragMode:=0;
    Touch;
   End;
  End
   Else Begin
    ClearSel;
    DragMode:=5; RubOn:=False;
    RubX1:=MX; RubY1:=MY; RubX2:=MX; RubY2:=MY;
    Touch;
   End;
 End;
 End;
End;

Procedure ViewDrag;
Var DX,DY,RX,RY:Integer; O,D:TVec; X,Z:Real; TX,TZ:Real;
Begin
 If DragView<0 Then Exit;
 DX:=MX-DragX; DY:=MY-DragY;
 If(DX=0)And(DY=0)Then Exit;
 Case DragMode Of
  1:Begin OrbitView(Views[DragView],DX,DY); NeedViews:=True; End;
  2:Begin PanView(Views[DragView],DX,DY); NeedViews:=True; End;
  3:Begin ZoomView(Views[DragView],1+DY*0.01); NeedViews:=True; End;
  4:Begin
   RX:=MX-Views[DragView].X1; RY:=MY-Views[DragView].Y1;
   ScreenRay(Views[DragView],RX,RY,O,D);
   If RayPlaneY(O,D,MovePlaneY,X,Z)Then Begin
    TX:=Round((X-MoveStartX)/20)*20; TZ:=Round((Z-MoveStartZ)/20)*20;
    If(TX<>MoveAppX)Or(TZ<>MoveAppZ)Then Begin
     If Not MoveBegun Then Begin PushUndo; MoveBegun:=True; End;
     MoveSel(TX-MoveAppX,0,TZ-MoveAppZ);
     MoveAppX:=TX; MoveAppZ:=TZ;
     NeedViews:=True; NeedStatus:=True;
    End;
   End;
  End;
  5:Begin
   MouseOff;
   If RubOn Then RubberXor;
   RubX2:=MX; RubY2:=MY;
   RubberXor; RubOn:=True;
   MouseOn;
  End;
 End;
 DragX:=MX; DragY:=MY;
End;

Procedure ViewRelease;
Var Q:PPiece; BN,BX:TVec; SX,SY:Integer; Vis:Boolean; X1,Y1,X2,Y2,T,RX,RY:Integer; V:Integer;
Begin
 If DragMode=5 Then Begin
  MouseOff;
  If RubOn Then RubberXor;
  MouseOn;
  RubOn:=False;
  X1:=RubX1; X2:=RubX2; Y1:=RubY1; Y2:=RubY2;
  If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
  If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
  If(X2-X1>3)Or(Y2-Y1>3)Then Begin
   V:=DragView;
   SetupCamera(Views[V]);
   Q:=Models[CurModel].First;
   While Q<>Nil Do Begin
    If PieceVisible(Q)Then Begin
     WorldToScreen(Q^.M.T,SX,SY,Vis);
     SX:=SX+Views[V].X1; SY:=SY+Views[V].Y1;
     If Vis And(SX>=X1)And(SX<=X2)And(SY>=Y1)And(SY<=Y2)Then Q^.Sel:=True;
    End;
    Q:=Q^.Next;
   End;
  End;
  Touch;
 End;
 If(DragMode=4)And MoveBegun Then Begin Touch; NeedTools:=True; End;
 DragMode:=0; DragView:=-1;
End;

{ ====================================================================== }
{ Evenements : panneaux                                                  }
{ ====================================================================== }

Procedure SelectPart(K:Integer);
Var E:PCat;
Begin
 If(K<0)Or(K>=FilN)Then Exit;
 E:=Catalog^[Filtered^[K]];
 PartSel:=K;
 CurPart:=LoStr(E^.FileN);
 CurPartDesc:=E^.Desc;
 Tool:=TL_INSERT;
 StatusMsg:='';
 NeedTools:=True; Touch;
End;

Procedure ApplyProp;
Var V,RX,RY,RZ:Real; Code:Integer; Q:PPiece; Sv:TMat;
Begin
 Q:=FirstSel;
 If(Q=Nil)Or(PropField<0)Then Begin PropField:=-1; Exit; End;
 Val(PropText,V,Code);
 If(Code<>0)Or(PropText='')Then Begin PropField:=-1; NeedDock:=True; Exit; End;
 PushUndo;
 Q:=FirstSel;
 Case PropField Of
  0:MoveSel(V-Q^.M.T.X,0,0);
  1:MoveSel(0,V-Q^.M.T.Y,0);
  2:MoveSel(0,0,V-Q^.M.T.Z);
  3,4,5:Begin
   EulerFromMat(Q^.M,RX,RY,RZ);
   RX:=Round(RX); RY:=Round(RY); RZ:=Round(RZ);
   If PropField=3 Then RX:=V Else If PropField=4 Then RY:=V Else RZ:=V;
   Sv:=Q^.M;
   MatFromEuler(RX,RY,RZ,Q^.M);
   SnapRot(Q^.M);
   Q^.M.T:=Sv.T;
  End;
  6:Begin
   Q:=Models[CurModel].First;
   While Q<>Nil Do Begin
    If Q^.Sel Then Begin Q^.Step:=Round(V); If Q^.Step<1 Then Q^.Step:=1; End;
    Q:=Q^.Next;
   End;
  End;
 End;
 PropField:=-1;
 Touch;
End;

Procedure PanelPress(PX,PY:Integer);
Var X0,X1,K,F,N:Integer; Hdr:Boolean; S:Integer; Q:PPiece;
Begin
 X0:=DockX+3; X1:=ScreenW-4;
 Case PanelSel Of
  PN_PARTS:Begin
   SearchEdit:=False;
   If InRect(PX,PY,X0,CatY,X1-X0-12,CAT_ROWS*12+2)Then Begin
    K:=CatTop+(PY-CatY-1) Div 12;
    If K<CatN Then Begin CatSel:=K; RefilterParts; End;
    NeedDock:=True;
   End
    Else If InRect(PX,PY,X1-11,CatY,12,CAT_ROWS*12+2)Then Begin
     CatTop:=VScrollClick(CatY,CAT_ROWS*12+2,CatTop,CatN,CAT_ROWS,PY);
     DragScroll:=1; NeedDock:=True;
    End
    Else If InRect(PX,PY,X0+44,SearchY,X1-X0-44,14)Then Begin SearchEdit:=True; NeedDock:=True; End
    Else If InRect(PX,PY,X0,ListY,X1-X0-12,PART_ROWS*12+2)Then Begin
     K:=PartTop+(PY-ListY-1) Div 12;
     SelectPart(K);
    End
    Else If InRect(PX,PY,X1-11,ListY,12,PART_ROWS*12+2)Then Begin
     PartTop:=VScrollClick(ListY,PART_ROWS*12+2,PartTop,FilN,PART_ROWS,PY);
     DragScroll:=2; NeedDock:=True;
    End;
  End;
  PN_PROPS:Begin
   PropField:=-1;
   For F:=0 To 6 Do
    If InRect(PX,PY,DockX+76,PanY1+4+PropRow(F)*14,ScreenW-6-DockX-76,13)Then
     If FirstSel<>Nil Then Begin PropField:=F; PropText:=PropValue(F,FirstSel); PropFresh:=True; End;
   NeedDock:=True;
  End;
  PN_TIME:Begin
   N:=TimeRowCount;
   If InRect(PX,PY,X1-11,PanY1+2,12,PanY2-PanY1-3)Then Begin
    TimeTop:=VScrollClick(PanY1+2,PanY2-PanY1-3,TimeTop,N,TIME_ROWS,PY);
    DragScroll:=3; NeedDock:=True;
   End
    Else If InRect(PX,PY,X0,PanY1+3,X1-X0-12,TIME_ROWS*13)Then Begin
     K:=TimeTop+(PY-PanY1-4) Div 13;
     If K<N Then Begin
      TimeRowAt(K,Hdr,S,Q);
      If Hdr Then SetStep(S)
      Else If Q<>Nil Then Begin
       ClearSel; Q^.Sel:=True;
       If Q^.Step>Models[CurModel].CurStep Then Models[CurModel].CurStep:=Q^.Step;
       Touch;
      End;
     End;
    End;
  End;
 End;
End;

Procedure DragScrollMove;
Var PY,N:Integer;
Begin
 PY:=MY;
 Case DragScroll Of
  1:Begin
   If PY<CatY+12 Then PY:=CatY+12; If PY>CatY+CAT_ROWS*12+2-13 Then PY:=CatY+CAT_ROWS*12+2-13;
   N:=VScrollClick(CatY,CAT_ROWS*12+2,CatTop,CatN,CAT_ROWS,PY);
   If N<>CatTop Then Begin CatTop:=N; NeedDock:=True; End;
  End;
  2:Begin
   If PY<ListY+12 Then PY:=ListY+12; If PY>ListY+PART_ROWS*12+2-13 Then PY:=ListY+PART_ROWS*12+2-13;
   N:=VScrollClick(ListY,PART_ROWS*12+2,PartTop,FilN,PART_ROWS,PY);
   If N<>PartTop Then Begin PartTop:=N; NeedDock:=True; End;
  End;
  3:Begin
   If PY<PanY1+14 Then PY:=PanY1+14; If PY>PanY2-14 Then PY:=PanY2-14;
   N:=VScrollClick(PanY1+2,PanY2-PanY1-3,TimeTop,TimeRowCount,TIME_ROWS,PY);
   If N<>TimeTop Then Begin TimeTop:=N; NeedDock:=True; End;
  End;
 End;
End;

{ ====================================================================== }
{ Evenements : souris                                                    }
{ ====================================================================== }

Procedure HandleMouse;
Var LP,RP,MP,LR:Boolean; V,B,I:Integer; HB:Integer;
Begin
 PollMouse;
 LP:=((MB And 1)<>0)And((OldMB And 1)=0);
 RP:=((MB And 2)<>0)And((OldMB And 2)=0);
 MP:=((MB And 4)<>0)And((OldMB And 4)=0);
 LR:=((MB And 7)=0)And((OldMB And 7)<>0);

 { menus ouverts }
 If MenuActive Then Begin
  If(MX<>OldMX)Or(MY<>OldMY)Then Begin
   B:=MenuBarHit(MX,MY);
   If(B>=0)And(B<>ActiveMenu)Then OpenMenu(B)
   Else Begin
    I:=MenuItemHit(MX,MY,ActiveMenu);
    If I<>ActiveMenuItem Then Begin
     ActiveMenuItem:=I;
     MouseOff; DrawMenu(ActiveMenu); MouseOn;
    End;
   End;
  End;
  If LP Then Begin
   B:=MenuBarHit(MX,MY);
   If B>=0 Then Begin
    If B=ActiveMenu Then Begin CloseMenu; If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End; End;
   End
    Else Begin
     I:=MenuItemHit(MX,MY,ActiveMenu);
     If I>=0 Then Begin
      If Not Menus[ActiveMenu].Items[I].Separator Then RunMenuItem(ActiveMenu,I);
     End
      Else Begin
       CloseMenu;
       If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
       WaitMouseUp;
      End;
    End;
  End;
  OldMX:=MX; OldMY:=MY; OldMB:=MB;
  Exit;
 End;

 { glisser en cours }
 If DragScroll>0 Then Begin
  If(MB And 1)<>0 Then DragScrollMove Else DragScroll:=0;
 End
  Else If DragMode<>0 Then Begin
   If(MB And 7)<>0 Then ViewDrag;
   If LR Then ViewRelease;
  End
  Else Begin
   { survol }
   HB:=TBHit(MX,MY);
   If HB<>HoverTB Then Begin
    HoverTB:=HB;
    If HB>=0 Then StatusMsg:=TBHint(HB) Else StatusMsg:='';
    NeedStatus:=True;
   End;
   If(Tool=TL_INSERT)And((MX<>OldMX)Or(MY<>OldMY))And((MB And 7)=0)Then Begin
    V:=ViewAt(MX,MY);
    If V>=0 Then Begin
     UpdateInsert(V,MX,MY);
     NeedViews:=True; NeedStatus:=True;
    End;
   End;
   If LP Or RP Or MP Then Begin
    If MY<MENU_H Then Begin
     B:=MenuBarHit(MX,MY);
     If B>=0 Then OpenMenu(B);
    End
     Else If MY<MENU_H+TB_H Then Begin
      B:=TBHit(MX,MY);
      If B>=0 Then Begin
       MouseOff; DrawIcon(B,TBX(B)+1,MENU_H+3); MouseOn;
       WaitMouseUp;
       ToolbarClick(B);
       If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
      End;
     End
     Else If MY<MENU_H+TB_H+TAB_H Then Begin
      B:=TabHit(MX,MY);
      If B>=0 Then SwitchModel(B);
     End
     Else Begin
      V:=ViewAt(MX,MY);
      If V>=0 Then Begin
       If LP Then ViewPress(V,1) Else If RP Then ViewPress(V,2) Else ViewPress(V,4);
      End
       Else If LP Then Begin
        If InRect(MX,MY,DockX,PanY1,ScreenW-DockX,PanY2-PanY1+1)Then Begin
         If PropField>=0 Then Begin ApplyProp; End;
         PanelPress(MX,MY);
        End
         Else If DockTabHit(MX,MY)>=0 Then SetPanel(DockTabHit(MX,MY))
         Else If InRect(MX,MY,DockX,ColY,ScreenW-DockX,ColY2-ColY+1)Then Begin
          B:=ColHit(MX,MY);
          If B>=0 Then Begin
           CurColor:=ColCode[B];
           ApplyColorSel(CurColor);
           NeedDock:=True; NeedViews:=True;
          End;
         End;
       End;
     End;
   End;
  End;
 OldMX:=MX; OldMY:=MY; OldMB:=MB;
End;

{ ====================================================================== }
{ Evenements : clavier                                                   }
{ ====================================================================== }

{ Deplacement par les fleches : direction ecran -> axe monde }
Procedure ArrowMove(Dir:Integer);
Var V:Integer; RX,RZ,FX,FZ:Real; AX,AZ:Real;
Begin
 V:=ActiveView;
 SetupCamera(Views[V]);
 RX:=CamM.R[0,0]; RZ:=CamM.R[0,2];
 FX:=CamM.R[2,0]; FZ:=CamM.R[2,2];
 AX:=0; AZ:=0;
 Case Dir Of
  0:If Abs(FX)>=Abs(FZ)Then AX:=Sgn(FX)*20 Else AZ:=Sgn(FZ)*20;
  1:If Abs(FX)>=Abs(FZ)Then AX:=-Sgn(FX)*20 Else AZ:=-Sgn(FZ)*20;
  2:If Abs(RX)>=Abs(RZ)Then AX:=-Sgn(RX)*20 Else AZ:=-Sgn(RZ)*20;
  3:If Abs(RX)>=Abs(RZ)Then AX:=Sgn(RX)*20 Else AZ:=Sgn(RZ)*20;
 End;
 If SelCount>0 Then Begin
  PushUndo; MoveSel(AX,0,AZ); Touch;
 End
  Else Begin
   Case Dir Of
    0:PanView(Views[V],0,-24);
    1:PanView(Views[V],0,24);
    2:PanView(Views[V],-24,0);
    3:PanView(Views[V],24,0);
   End;
   NeedViews:=True;
  End;
End;

Procedure NextView;
Begin
 If ViewCount=1 Then Begin
  ActiveView:=(ActiveView+1) Mod 4;
  LayoutViews;
  ZoomFit(Views[ActiveView]);
 End
  Else ActiveView:=(ActiveView+1) Mod 4;
 NeedViews:=True; NeedTools:=True;
End;

Procedure HandleKey;
Var K:Char; Ext:Boolean;
Begin
 K:=ReadKeyEx(Ext);
 StatusMsg:='';
 If Ext Then Begin
  If MenuActive Then Begin
   Case K Of
    #72:Begin MenuStep(-1); MouseOff; DrawMenu(ActiveMenu); MouseOn; Exit; End;
    #80:Begin MenuStep(1); MouseOff; DrawMenu(ActiveMenu); MouseOn; Exit; End;
    #75:Begin OpenMenu((ActiveMenu+MENU_COUNT-1) Mod MENU_COUNT); Exit; End;
    #77:Begin OpenMenu((ActiveMenu+1) Mod MENU_COUNT); Exit; End;
   End;
  End;
  Case K Of
   #59:HelpDialog;
   #60:SetPanel(PN_PARTS);
   #61:SetPanel(PN_PROPS);
   #62:SetPanel(PN_TIME);
   #67:OpenMenu(0);
   #68,#107:DoQuit;
   #33:OpenMenu(M_FILE);
   #18:OpenMenu(M_EDIT);
   #30:OpenMenu(M_VIEW);
   #25:OpenMenu(M_PIECE);
   #20:OpenMenu(M_STEP);
   #31:OpenMenu(M_SUB);
   #35:OpenMenu(M_HELP);
   #72:ArrowMove(0);
   #80:ArrowMove(1);
   #75:ArrowMove(2);
   #77:ArrowMove(3);
   #73:DoMenu(M_PIECE,3);
   #81:DoMenu(M_PIECE,4);
   #71:DoMenu(M_PIECE,5);
   #79:DoMenu(M_PIECE,6);
   #83:DeleteSel;
   #82:DoMenu(M_PIECE,0);
  End;
  If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
  Exit;
 End;
 { menu ouvert : Entree / Echap }
 If MenuActive Then Begin
  If K=#13 Then Begin
   If(ActiveMenuItem>=0)And(Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator)Then RunMenuItem(ActiveMenu,ActiveMenuItem);
  End
   Else If K=#27 Then Begin CloseMenu; If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End; End;
  Exit;
 End;
 { edition d'un champ de proprietes }
 If PropField>=0 Then Begin
  If K=#13 Then ApplyProp
  Else If K=#27 Then Begin PropField:=-1; NeedDock:=True; End
  Else If K=#8 Then Begin If Length(PropText)>0 Then Delete(PropText,Length(PropText),1); PropFresh:=False; NeedDock:=True; End
  Else If K In ['0'..'9','-','.'] Then Begin
   If PropFresh Then PropText:='';
   PropFresh:=False;
   If Length(PropText)<12 Then PropText:=PropText+K;
   NeedDock:=True;
  End;
  Exit;
 End;
 { saisie de recherche }
 If SearchEdit Then Begin
  If(K=#13)Or(K=#27)Then Begin SearchEdit:=False; NeedDock:=True; End
  Else If K=#8 Then Begin
   If Length(SearchStr)>0 Then Delete(SearchStr,Length(SearchStr),1);
   RefilterParts; NeedDock:=True;
  End
  Else If(K>=' ')And(Length(SearchStr)<18)Then Begin
   SearchStr:=SearchStr+K; RefilterParts; NeedDock:=True;
  End;
  Exit;
 End;
 Case K Of
  #14:DoMenu(M_FILE,0);
  #15:DoMenu(M_FILE,1);
  #19:DoMenu(M_FILE,2);
  #26:DoMenu(M_EDIT,0);
  #25:DoMenu(M_EDIT,1);
  #1:DoMenu(M_EDIT,8);
  #4:DoMenu(M_EDIT,9);
  #24:DoMenu(M_EDIT,3);
  #3:DoMenu(M_EDIT,4);
  #22:DoMenu(M_EDIT,5);
  #2:DoMenu(M_PIECE,1);
  #9:NextView;
  #27:Begin
   If Tool<>TL_SELECT Then Begin Tool:=TL_SELECT; NeedTools:=True; NeedViews:=True; End
   Else Begin ClearSel; Touch; End;
  End;
  'x':RotateSel(0,90);
  'X':RotateSel(0,-90);
  'y':RotateSel(1,90);
  'Y':RotateSel(1,-90);
  'z':RotateSel(2,90);
  'Z':RotateSel(2,-90);
  'v','V':DoMenu(M_VIEW,0);
  'p','P':DoMenu(M_VIEW,1);
  'g','G':DoMenu(M_VIEW,15);
  'e','E':DoMenu(M_VIEW,16);
  'w','W':DoMenu(M_VIEW,17);
  't','T':DoMenu(M_VIEW,18);
  'h','H':HideSel;
  'f','F':DoMenu(M_VIEW,13);
  'b','B':DoMenu(M_PIECE,1);
  'm','M':SwitchModel(0);
  '0'..'6':SetPreset(Ord(K)-48);
  '+','=':DoMenu(M_VIEW,11);
  '-','_':DoMenu(M_VIEW,12);
  '.':DoMenu(M_STEP,0);
  ',':DoMenu(M_STEP,1);
  '[':DoMenu(M_STEP,2);
  ']':DoMenu(M_STEP,3);
 End;
 If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
End;

{ ====================================================================== }
{ Initialisation                                                         }
{ ====================================================================== }

Procedure InitDirs;
Var S:String; Root:String; I:Integer;
 Function TryDir(Const D:String):Boolean;
 Var R:Boolean;
 Begin
  R:=DirOK(D+'SAMPLES'+PathSep+'LEOCAD'+PathSep+'LEGO');
  If R Then Root:=D;
  TryDir:=R;
 End;
Begin
 {$IFDEF FPC}PathSep:=DirectorySeparator;{$ELSE}PathSep:='\';{$ENDIF}
 GetDir(0,S);
 If(Length(S)>0)And(S[Length(S)]<>PathSep)Then S:=S+PathSep;
 BaseDir:=S;
 Root:=BaseDir;
 If Not TryDir(BaseDir)Then
  If Not TryDir(DirOf(FExpand(ParamStr(0))))Then
   If Not TryDir(BaseDir+'..'+PathSep)Then
    If Not TryDir(DirOf(FExpand(ParamStr(0)))+'..'+PathSep)Then Root:=BaseDir;
 LibDir:=Root+'SAMPLES'+PathSep+'LEOCAD'+PathSep+'LEGO'+PathSep;
 PlanDir:=Root+'SAMPLES'+PathSep+'LEOCAD'+PathSep+'PLAN'+PathSep;
End;

Procedure InitGlobals;
Var I:Integer;
Begin
 For I:=0 To 7 Do Begin
  StudCos[I]:=6*Cos(2*Pi*I/8); StudSin[I]:=6*Sin(2*Pi*I/8);
 End;
 For I:=0 To MAXBLK-1 Do PolyBlk[I]:=Nil;
 For I:=0 To MAXMOD-1 Do Begin
  Models[I].First:=Nil; Models[I].Last:=Nil; Models[I].Count:=0; Models[I].Used:=False;
 End;
 GetMem(Catalog,SizeOf(TCatArr)); FillChar(Catalog^,SizeOf(TCatArr),0);
 GetMem(Filtered,SizeOf(TIntArr)); FillChar(Filtered^,SizeOf(TIntArr),0);
 GetMem(PolyIdx,SizeOf(TIdxArr));
 CatCount:=0; FilN:=0; CatN:=1; CatSel:=0; CatTop:=0; PartTop:=0; PartSel:=-1;
 SearchStr:=''; SearchEdit:=False;
 CurPart:=''; CurPartDesc:='';
 Cache:=Nil; CacheCount:=0; Epoch:=1;
 Clip:=Nil; ClipN:=0; UndoN:=0; RedoN:=0;
 GhostPiece:=Nil;
 CurColor:=4;
 Tool:=TL_SELECT; PanelSel:=PN_PARTS;
 GridOn:=True; EdgesOn:=True; WireOn:=False; StudMode:=0;
 MenuActive:=False; ActiveMenu:=0; ActiveMenuItem:=-1;
 StatusMsg:=''; PropField:=-1; TimeTop:=0;
 DragMode:=0; DragView:=-1; DragScroll:=0; HoverTB:=-1;
 MHid:=0; OldMB:=0; OldMX:=0; OldMY:=0;
 MatIdent(InsM); InsValid:=False; InsX:=0; InsY:=0; InsZ:=0;
 Modified:=False; DocFile:=''; FullRedraw:=False;
 NeedViews:=False; NeedDock:=False; NeedStatus:=False; NeedTools:=False;
 ModelCount:=0; CurModel:=0;
End;

Procedure Cleanup;
Begin
 FreePolyBlocks;
 FlushCache;
 ClearHistory;
 ClearAllModels;
 CloseGraph;
End;

Procedure MainLoop;
Begin
 While Running Do Begin
  HandleMouse;
  If KeyPressed Then HandleKey;
  If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
  If Not MenuActive Then Begin
   If NeedTools Then Begin
    MouseOff; UpdateMenuChecks; DrawToolbar; DrawTabs; MouseOn;
    NeedTools:=False; NeedStatus:=True;
   End;
   If NeedViews Then Begin
    NeedViews:=False;
    MouseOff; DrawViews; MouseOn;
   End;
   If NeedDock Then Begin
    NeedDock:=False;
    MouseOff; DrawDock; MouseOn;
   End;
   If NeedStatus Then Begin
    NeedStatus:=False;
    MouseOff; DrawStatus; MouseOn;
   End;
  End;
  Delay(8);
 End;
End;

BEGIN
 If(ParamStr(1)='/?')Or(ParamStr(1)='-h')Or(ParamStr(1)='--help')Then Begin
  WriteLn('LEOCAD : Clone de LeoCAD, CAO de briques Lego en 3D (fichiers LDraw).');
  WriteLn;
  WriteLn('Syntaxe : LEOCAD [/16] [fichier.ldr|fichier.mpd]');
  WriteLn;
  WriteLn(' /16        force le mode VGA 16 couleurs');
  WriteLn(' Bibliotheque : SAMPLES\LEOCAD\LEGO\*.DAT');
  WriteLn(' Plans       : SAMPLES\LEOCAD\PLAN\*.LDR, *.MPD');
  Halt;
 End;
 Force16:=False; ArgFile:='';
 For I0:=1 To ParamCount Do
  If(ParamStr(I0)='/16')Or(ParamStr(I0)='-16')Then Force16:=True
  Else If ArgFile='' Then ArgFile:=ParamStr(I0);
 InitializeGraphics;
 ScreenW:=GetMaxX+1; ScreenH:=GetMaxY+1;
 Palette256:=GetMaxColor>15;
 InitGlobals;
 InitDirs;
 InitColors;
 SetupPalette;
 MouseDriverFound;
 LayoutScreen;
 InitMenus;
 LoadCatalog;
 NewDocument;
 InitViews;
 Running:=True;
 RedrawAll;
 If ArgFile<>'' Then OpenPath(ArgFile);
 MainLoop;
 Cleanup;
END.
