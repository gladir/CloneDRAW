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
   LEOCAD [/16] [-maxscreen] [fichier.ldr|fichier.mpd]
   /16        : force le mode VGA 16 couleurs (sinon 256 couleurs avec Free Pascal)
   -maxscreen : utilise la resolution maximale disponible (Free Pascal)

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
 Force16,MaxScreen:Boolean;
 I0:Integer;
 ArgFile:String;

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
 {$IFDEF FPC}
 LoMode, HiMode: SmallInt;
 {$ENDIF}
Begin
 {$IFDEF FPC}
  { 256 couleurs si possible : les teintes des briques sont des rampes de
    nuances ; sinon retour au VGA 16 couleurs (ou option /16).
    -maxscreen : resolution maximale du pilote D8bit (Free Pascal seulement). }
  Driver:=D8bit;
  Mode:=m640x480;
  If MaxScreen Then Begin
   GetModeRange(Driver,LoMode,HiMode);
   If HiMode>=LoMode Then Mode:=HiMode;
  End;
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
 MAXMOD=96;               { modeles (fichier principal + sous-modeles) }
 MAXVIEW=4;
 MAXPOLY=60000;           { polygones d'une scene (liste chainee) }
 UNDO_MAX=12;
 CACHE_MAX=160;           { pieces gardees en memoire }
 NSHADE=6;
 GRP_MAX=32;              { groupes de nuances (6 entrees de palette chacun) }
 UI_BASE=208;             { entrees de palette reservees a l'interface }
 UI_SLOTS=48;
 EPS=0.000001;

 { Types de primitives LDraw }
 PK_REF=1; PK_LINE=2; PK_TRI=3; PK_QUAD=4; PK_STUD=5; PK_OPT=6;

 { Finitions de couleur }
 FN_CHROME=1; FN_PEARL=2; FN_RUBBER=4; FN_MATTE=8; FN_METAL=16;

 { Outils }
 TL_SELECT=0; TL_INSERT=1; TL_ORBIT=2; TL_PAN=3; TL_ZOOM=4;

 { Panneaux }
 PN_PARTS=0; PN_PROPS=1; PN_TIME=2;

 { Menus }
 MENU_COUNT=9;
 M_FILE=0; M_EDIT=1; M_VIEW=2; M_PIECE=3; M_XFORM=4; M_STEP=5; M_SUB=6; M_CAM=7; M_HELP=8;

 { Commandes (menus, clavier, barre d'outils) }
 CM_NONE=0;
 CM_NEW=1; CM_OPEN=2; CM_SAVE=3; CM_SAVEAS=4; CM_EXP_IMG=5; CM_EXP_HTML=6; CM_EXP_POV=7;
 CM_EXP_OBJ=8; CM_EXP_3DS=9; CM_EXP_BL=10; CM_EXP_LIST=11; CM_IMP_BL=12; CM_PARTSUSED=13;
 CM_INFO=14; CM_PREFS=15; CM_REINDEX=16; CM_DOCS=17; CM_QUIT=18;
 CM_UNDO=20; CM_REDO=21; CM_CUT=22; CM_COPY=23; CM_PASTE=24; CM_DELETE=25; CM_SELALL=26;
 CM_SELNONE=27; CM_SELINV=28; CM_SELCOL=29; CM_SELPART=30; CM_ADDMODE=31;
 CM_VIEWS=40; CM_PERSP=41; CM_V_HOME=42; CM_V_FRONT=43; CM_V_BACK=44; CM_V_LEFT=45;
 CM_V_RIGHT=46; CM_V_TOP=47; CM_V_BOTTOM=48; CM_ZOOMIN=49; CM_ZOOMOUT=50; CM_FIT=51;
 CM_GRID=52; CM_EDGES=53; CM_WIRE=54; CM_STUDS=55; CM_PN_PARTS=56; CM_PN_PROPS=57;
 CM_PN_TIME=58; CM_NEXTVIEW=59;
 CM_INSERT=60; CM_DUP=61; CM_UP8=62; CM_DN8=63; CM_UP24=64; CM_DN24=65; CM_RXP=66;
 CM_RXM=67; CM_RYP=68; CM_RYM=69; CM_RZP=70; CM_RZM=71; CM_APPLYCOL=72; CM_HIDE=73;
 CM_SHOWALL=74; CM_GROUP=75; CM_UNGROUP=76; CM_LOCK=77; CM_UNLOCK=78; CM_SELTOOL=79;
 CM_AL_L=80; CM_AL_R=81; CM_AL_F=82; CM_AL_B=83; CM_AL_T=84; CM_AL_D=85; CM_CEN_X=86;
 CM_CEN_Z=87; CM_DIST_X=88; CM_DIST_Y=89; CM_DIST_Z=90; CM_MIR_X=91; CM_MIR_Y=92;
 CM_MIR_Z=93; CM_ARRAY=94; CM_NUMXF=95; CM_PIVOT=96;
 CM_STEP_NEXT=100; CM_STEP_PREV=101; CM_STEP_FIRST=102; CM_STEP_LAST=103; CM_STEP_INS=104;
 CM_STEP_DEL=105; CM_STEP_SEL=106;
 CM_SUB_NEW=110; CM_SUB_FROMSEL=111; CM_SUB_INS=112; CM_SUB_EDIT=113; CM_SUB_MAIN=114;
 CM_SUB_DEL=115;
 CM_CAM_NEW=120; CM_CAM_GO=121; CM_CAM_DEL=122; CM_FOV=123; CM_KEY_ADD=124; CM_KEY_DEL=125;
 CM_KEY_PLAY=126; CM_ANIM_EXP=127; CM_STEPS_PLAY=128;
 CM_HELP=130; CM_ABOUT=131; CM_KEYS=132;
 CM_TOOL_SEL=140; CM_TOOL_INS=141; CM_TOOL_ORB=142; CM_TOOL_PAN=143; CM_TOOL_ZOOM=144;

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
  Col:LongInt;
  Inv:Boolean;          { INVERTNEXT }
  Case Byte Of
   0:(P:Array[0..3] Of TVec);
   1:(M:TMat; Ref:PPart);
 End;
 TPart=Record
  Name:String[40];
  Prims:PPrim;          { definition d'origine (avec references) }
  Tail:PPrim;
  Flat:PPrim;           { geometrie aplatie (sans references), pour le rendu }
  FlatTail:PPrim;
  Flattened:Boolean;
  Next:PPart;
  Found:Boolean;
  BBox:Boolean;
  AMin,AMax:TVec;      { boite englobante, tenons compris }
  BMin,BMax:TVec;      { boite du corps, sans les tenons }
 End;

 PPiece=^TPiece;
 TPiece=Record
  Name:String[40];
  Col:LongInt;
  M:TMat;
  Step,HideStep:Integer;
  Group:LongInt;
  Sel,Hidden,Locked,Mark:Boolean;
  Part:PPart;
  Epoch:LongInt;
  SubIdx:Integer;
  SubEpoch:LongInt;
  Next,Prev:PPiece;
 End;

 TModel=Record
  Used:Boolean;
  Name:String[40];
  First,Last:PPiece;
  Count:Integer;
  CurStep:Integer;
 End;

 PSnapMod=^TSnapMod;
 TSnapMod=Record
  Name:String[40];
  List:PPiece;
  Step:Integer;
  Next:PSnapMod;
 End;
 PSnap=^TSnap;
 TSnap=Record
  NMod,Cur:Integer;
  Col:LongInt;
  Mods:PSnapMod;
  Next:PSnap;
 End;

 PCat=^TCat;
 TCat=Record
  FileN:String[20];
  Desc:String[60];
  Keys:String[48];
  CatI:Integer;
  Next:PCat;
 End;
 PFil=^TFil;
 TFil=Record
  C:PCat;
  Next:PFil;
 End;
 PCategory=^TCategory;
 TCategory=Record
  Name:String[24];
  Next:PCategory;
 End;

 PColor=^TColor;
 TColor=Record
  Code:LongInt;
  Name:String[32];
  R,G,B,ER,EG,EB,Alpha,Fin:Byte;
  Next:PColor;
 End;

 PPoly=^TPoly;
 TPoly=Record
  Next:PPoly;
  Z:LongInt;
  Col:Word;
  N,Fl:Byte;
  Owner:Integer;
  X,Y:Array[0..3] Of Integer;
 End;

 PGroup=^TGroup;
 TGroup=Record
  Id:LongInt;
  Name:String[40];
  Next:PGroup;
 End;

 PCamera=^TCamera;
 TCamera=Record
  Name:String[30];
  Persp:Boolean;
  Yaw,Pitch,Dist,Zoom,Fov:Real;
  Tgt:TVec;
  Next:PCamera;
 End;

 PKey=^TKey;
 TKey=Record
  Time:Integer;           { image de l'animation }
  Persp:Boolean;
  Yaw,Pitch,Dist,Zoom,Fov:Real;
  Tgt:TVec;
  Step:Integer;
  Next:PKey;
 End;

 TView=Record
  Persp:Boolean;
  Yaw,Pitch,Dist,Zoom,Fov:Real;
  Tgt:TVec;
  X1,Y1,X2,Y2:Integer;
  Name:String[12];
 End;

 TMenuItem=Record
  Caption:String[34];
  Shortcut:String[12];
  Cmd:Integer;
  Enabled,Checked,Separator:Boolean;
 End;

 PBind=^TBind;
 TBind=Record
  Key:Integer;            { code ASCII, ou 256 + code etendu }
  Cmd:Integer;
  Next:PBind;
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
 BaseDir,LibDir,PlanDir,ExtraDir,AltLibDir:String;
 PathSep:Char;
 { couleurs : liste chainee (LDConfig.ldr ou table integree) }
 ColHead,ColTail:PColor;
 NCol:Integer;
 ColCache:Array[0..255] Of PColor;
 VgaR,VgaG,VgaB:Array[0..15] Of Byte;
 CurColor:LongInt;             { code LDraw de la couleur courante }
 ColTop:Integer;
 { palette dynamique (256 couleurs) }
 GrpKey:Array[0..GRP_MAX-1] Of LongInt;
 GrpR,GrpG,GrpB:Array[0..GRP_MAX-1] Of Byte;
 GrpN:Integer;
 { bibliotheque }
 Cache:PPart;
 CacheCount:Integer;
 Epoch:LongInt;
 CatHead,CatTail:PCat;
 CatCount:Integer;
 CatList,CatListTail:PCategory;
 CatN:Integer;
 FilHead,FilTail:PFil;
 FilN:Integer;
 CatSel,CatTop,PartTop,PartSel:Integer;
 SearchStr:String[20];
 SearchEdit:Boolean;
 CurPart:String[40];
 CurPartDesc:String[60];
 { documents }
 Models:Array[0..MAXMOD-1] Of TModel;
 ModelCount,CurModel:Integer;
 ModEpoch:LongInt;
 DocFile:String;
 Modified:Boolean;
 GroupHead:PGroup;
 NextGroupId:LongInt;
 CamHead:PCamera;
 KeyHead:PKey;
 BindHead:PBind;
 AddMode:Boolean;
 PivotMode:Integer;
 { annuler / retablir : piles chainees }
 UndoTop,RedoTop:PSnap;
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
 { scene : liste chainee de polygones }
 PolyHead,PolyPool:PPoly;
 PolyN,PolyMax:LongInt;
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
Var T:String; C:Integer; L:LongInt;
Begin
 T:=Tok(S);
 If(Length(T)>2)And(T[1]='0')And((T[2]='x')Or(T[2]='X'))Then Begin
  Val('$'+Copy(T,3,20),L,C);
  V:=L;
 End
  Else Val(T,V,C);
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

Var
 LatchL,LatchR,LatchM,LatchRel:Boolean;
 LatchX,LatchY,PrevPoll:Integer;

{ Lecture de la souris ; les fronts montants sont memorises (verrou) pour ne
  pas perdre un clic bref survenu pendant un rendu long }
Procedure PollMouse;
Var X,Y,B:LongInt;
Begin
 GetMouseState(X,Y,B);
 MX:=X; MY:=Y; MB:=B;
 If((MB And 1)<>0)And((PrevPoll And 1)=0)Then Begin LatchL:=True; LatchX:=MX; LatchY:=MY; End;
 If((MB And 2)<>0)And((PrevPoll And 2)=0)Then Begin LatchR:=True; LatchX:=MX; LatchY:=MY; End;
 If((MB And 4)<>0)And((PrevPoll And 4)=0)Then Begin LatchM:=True; LatchX:=MX; LatchY:=MY; End;
 If((MB And 7)=0)And((PrevPoll And 7)<>0)Then LatchRel:=True;
 PrevPoll:=MB;
End;

Procedure ClearLatch;
Begin
 LatchL:=False; LatchR:=False; LatchM:=False; LatchRel:=False;
End;

Procedure LatchMouse;
Begin
 PollMouse;
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
{ Couleurs LDraw (liste chainee)                                        }
{ ====================================================================== }

Var
 PalR,PalG,PalB:Array[0..255] Of Byte;
 GrpIdx:Array[0..GRP_MAX-1,0..NSHADE-1] Of Byte;
 CGCode:Array[0..255] Of LongInt;
 CGGrp:Array[0..255] Of Integer;
 CGTr:Array[0..255] Of Boolean;

Procedure ColFree;
Var C,N:PColor; I:Integer;
Begin
 C:=ColHead;
 While C<>Nil Do Begin N:=C^.Next; Dispose(C); C:=N; End;
 ColHead:=Nil; ColTail:=Nil; NCol:=0;
 For I:=0 To 255 Do ColCache[I]:=Nil;
End;

Procedure AddColor(Code:LongInt;Const Nm:String;R,G,B,ER,EG,EB,Alpha,Fin:Byte);
Var C:PColor;
Begin
 New(C);
 C^.Code:=Code; C^.Name:=Copy(Nm,1,32);
 C^.R:=R; C^.G:=G; C^.B:=B; C^.ER:=ER; C^.EG:=EG; C^.EB:=EB;
 C^.Alpha:=Alpha; C^.Fin:=Fin; C^.Next:=Nil;
 If ColTail=Nil Then ColHead:=C Else ColTail^.Next:=C;
 ColTail:=C;
 Inc(NCol);
End;

Procedure AddC(Code:LongInt;Const Nm:String;R,G,B:Byte;Tr:Boolean);
Begin
 If Tr Then AddColor(Code,Fx(Nm),R,G,B,R Div 2,G Div 2,B Div 2,128,0)
 Else AddColor(Code,Fx(Nm),R,G,B,R Div 2,G Div 2,B Div 2,255,0);
End;

Procedure InitColors;
Begin
 ColFree;
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

Function HexVal(C:Char):Integer;
Begin
 If(C>='0')And(C<='9')Then HexVal:=Ord(C)-48
 Else If(C>='A')And(C<='F')Then HexVal:=Ord(C)-55
 Else If(C>='a')And(C<='f')Then HexVal:=Ord(C)-87
 Else HexVal:=0;
End;

Function ParseRGB(Const S:String;Var R,G,B:Byte):Boolean;
Begin
 ParseRGB:=False;
 If(Length(S)<7)Or(S[1]<>'#')Then Exit;
 R:=HexVal(S[2])*16+HexVal(S[3]);
 G:=HexVal(S[4])*16+HexVal(S[5]);
 B:=HexVal(S[6])*16+HexVal(S[7]);
 ParseRGB:=True;
End;

Function FindColor(Code:LongInt):PColor;
Var C:PColor; H:Integer;
Begin
 H:=Code And 255;
 C:=ColCache[H];
 If(C<>Nil)And(C^.Code=Code)Then Begin FindColor:=C; Exit; End;
 C:=ColHead;
 While C<>Nil Do Begin
  If C^.Code=Code Then Begin ColCache[H]:=C; FindColor:=C; Exit; End;
  C:=C^.Next;
 End;
 FindColor:=Nil;
End;

Function ColNameOf(Code:LongInt):String;
Var C:PColor;
Begin
 If Code=16 Then Begin ColNameOf:=Fx('Principale'); Exit; End;
 If Code=24 Then Begin ColNameOf:=Fx('Bord'); Exit; End;
 C:=FindColor(Code);
 If C<>Nil Then ColNameOf:=C^.Name Else ColNameOf:='#'+IntStr(Code);
End;

Function ColByIndex(I:Integer):PColor;
Var C:PColor;
Begin
 C:=ColHead;
 While(C<>Nil)And(I>0)Do Begin C:=C^.Next; Dec(I); End;
 ColByIndex:=C;
End;

{ Lecture de LDConfig.ldr : 0 !COLOUR nom CODE n VALUE #RRGGBB EDGE #RRGGBB [ALPHA n] [CHROME ...] }
Function LoadLDConfig(Const Path:String):Boolean;
Var F:Text; L,T,Nm:String; Code:LongInt; R,G,B,ER,EG,EB,Al,Fin:Byte; V:Real; Cd:Integer; N:Integer;
Begin
 LoadLDConfig:=False;
 {$I-}
 Assign(F,Path); Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 ColFree;
 While Not Eof(F) Do Begin
  {$I-}ReadLn(F,L);{$I+}
  If IOResult<>0 Then L:='';
  L:=TrimStr(L);
  If Copy(L,1,1)='0' Then Begin
   Tok(L);
   T:=Tok(L);
   If UpStr(T)='!COLOUR' Then Begin
    Nm:=Tok(L);
    Code:=-1; R:=128; G:=128; B:=128; ER:=0; EG:=0; EB:=0; Al:=255; Fin:=0;
    Repeat
     T:=UpStr(Tok(L));
     If T='CODE' Then Begin NumTok(L,V); Code:=Round(V); End
     Else If T='VALUE' Then ParseRGB(Tok(L),R,G,B)
     Else If T='EDGE' Then ParseRGB(Tok(L),ER,EG,EB)
     Else If T='ALPHA' Then Begin NumTok(L,V); Al:=Round(V); End
     Else If T='CHROME' Then Fin:=Fin Or FN_CHROME
     Else If T='PEARLESCENT' Then Fin:=Fin Or FN_PEARL
     Else If T='RUBBER' Then Fin:=Fin Or FN_RUBBER
     Else If T='MATTE_METALLIC' Then Fin:=Fin Or FN_MATTE
     Else If T='METAL' Then Fin:=Fin Or FN_METAL;
    Until T='';
    If Code>=0 Then Begin
     For N:=1 To Length(Nm) Do If Nm[N]='_' Then Nm[N]:=' ';
     AddColor(Code,Nm,R,G,B,ER,EG,EB,Al,Fin);
    End;
   End;
  End;
 End;
 Close(F);
 LoadLDConfig:=NCol>0;
 If NCol=0 Then InitColors;
End;

{ Couleur d'un code LDraw (table, ou couleur directe 0x2RRGGBB) }
Procedure ColInfo(Code:LongInt;Var R,G,B:Byte;Var Tr:Boolean;Var Fin:Byte);
Var C:PColor; V:LongInt;
Begin
 Tr:=False; Fin:=0;
 If Code>=$2000000 Then Begin
  V:=Code And $FFFFFF;
  If Code>=$3000000 Then Begin
   R:=((V Shr 20) And 15)*17; G:=((V Shr 16) And 15)*17; B:=((V Shr 12) And 15)*17;
  End
   Else Begin
    R:=(V Shr 16) And 255; G:=(V Shr 8) And 255; B:=V And 255;
   End;
  Exit;
 End;
 C:=FindColor(Code);
 If C=Nil Then Begin R:=155; G:=161; B:=157; Exit; End;
 R:=C^.R; G:=C^.G; B:=C^.B; Tr:=C^.Alpha<255; Fin:=C^.Fin;
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

{ Palette dynamique : chaque couleur (RVB + finition) utilisee dans une scene
  recoit 6 entrees (nuances) parmi 32 groupes ; au-dela, le groupe le plus proche. }
Procedure SlotReset;
Var I:Integer;
Begin
 GrpN:=0;
 For I:=0 To 255 Do Begin CGCode[I]:=-1; CGGrp[I]:=0; CGTr[I]:=False; End;
End;

Procedure SetPal(Idx,R,G,B:Integer);
Begin
 If R>255 Then R:=255; If G>255 Then G:=255; If B>255 Then B:=255;
 If R<0 Then R:=0; If G<0 Then G:=0; If B<0 Then B:=0;
 PalR[Idx]:=R; PalG[Idx]:=G; PalB[Idx]:=B;
 If Palette256 Then SetRGBPalette(Idx,R,G,B);
End;

Function GroupFor(R,G,B,Fin:Integer):Integer;
Const
 SFN:Array[0..NSHADE-1] Of Real=(0.40,0.56,0.72,0.87,1.0,1.16);
 SFM:Array[0..NSHADE-1] Of Real=(0.22,0.45,0.72,1.0,1.28,1.6);
 SFP:Array[0..NSHADE-1] Of Real=(0.50,0.65,0.80,0.95,1.1,1.32);
 SFR:Array[0..NSHADE-1] Of Real=(0.58,0.68,0.80,0.90,1.0,1.08);
Var K:LongInt; I,G2,S:Integer; D,BD:LongInt; F:Real;
Begin
 K:=(LongInt(Fin) Shl 24) Or (LongInt(R) Shl 16) Or (LongInt(G) Shl 8) Or B;
 For I:=0 To GrpN-1 Do If GrpKey[I]=K Then Begin GroupFor:=I; Exit; End;
 If GrpN>=GRP_MAX Then Begin
  G2:=0; BD:=2000000000;
  For I:=0 To GrpN-1 Do Begin
   D:=Sqr(LongInt(R)-GrpR[I])+Sqr(LongInt(G)-GrpG[I])+Sqr(LongInt(B)-GrpB[I]);
   If D<BD Then Begin BD:=D; G2:=I; End;
  End;
  GroupFor:=G2;
  Exit;
 End;
 G2:=GrpN; Inc(GrpN);
 GrpKey[G2]:=K; GrpR[G2]:=R; GrpG[G2]:=G; GrpB[G2]:=B;
 For S:=0 To NSHADE-1 Do Begin
  If(Fin And(FN_CHROME Or FN_METAL))<>0 Then F:=SFM[S]
  Else If(Fin And(FN_PEARL Or FN_MATTE))<>0 Then F:=SFP[S]
  Else If(Fin And FN_RUBBER)<>0 Then F:=SFR[S]
  Else F:=SFN[S];
  If Palette256 Then Begin
   SetPal(16+G2*NSHADE+S,Round(R*F),Round(G*F),Round(B*F));
   GrpIdx[G2,S]:=16+G2*NSHADE+S;
  End
   Else GrpIdx[G2,S]:=NearVga(Round(R*F),Round(G*F),Round(B*F));
 End;
 GroupFor:=G2;
End;

{ Groupe de nuances d'un code couleur (avec cache) ; Tr = translucide }
Function ColGroup(Code:LongInt;Var Tr:Boolean):Integer;
Var H,G:Integer; R,Gc,B,Fin:Byte; T:Boolean;
Begin
 H:=Code And 255;
 If CGCode[H]=Code Then Begin Tr:=CGTr[H]; ColGroup:=CGGrp[H]; Exit; End;
 ColInfo(Code,R,Gc,B,T,Fin);
 G:=GroupFor(R,Gc,B,Fin);
 CGCode[H]:=Code; CGGrp[H]:=G; CGTr[H]:=T;
 Tr:=T; ColGroup:=G;
End;

{ Entree de palette d'interface (apercus de couleurs) }
Function UIColor(Slot,R,G,B:Integer):Integer;
Begin
 If Palette256 Then Begin
  If Slot>=UI_SLOTS Then Slot:=UI_SLOTS-1;
  SetPal(UI_BASE+Slot,R,G,B);
  UIColor:=UI_BASE+Slot;
 End
  Else UIColor:=NearVga(R,G,B);
End;

{ Couleur d'apercu d'un code LDraw (nuance 1.0) dans l'entree d'interface Slot }
Function UICode(Slot:Integer;Code:LongInt):Integer;
Var R,G,B,Fin:Byte; Tr:Boolean;
Begin
 If Code=16 Then Begin R:=170; G:=170; B:=170; End
 Else ColInfo(Code,R,G,B,Tr,Fin);
 UICode:=UIColor(Slot,R,G,B);
End;

Procedure SetupPalette;
Var C:Integer;
Begin
 InitVga;
 For C:=0 To 15 Do Begin PalR[C]:=VgaR[C]; PalG[C]:=VgaG[C]; PalB[C]:=VgaB[C]; End;
 SlotReset;
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
  FreePrims(P^.Flat);
  Dispose(P);
  P:=N;
 End;
 Cache:=Nil;
 CacheCount:=0;
 Inc(Epoch);
End;

{ Dispositions acceptees : racine a plat, parts\, p\, p\48\, p\8\, parts\s\
  (bibliotheque LDraw officielle) ; AltLibDir = autre racine LDraw (LDRAWDIR). }
Type
 TRootDirs=Record
  Root,Parts,P,S,Models:String;
 End;

Var
 RootDirs:Array[0..1] Of TRootDirs;

{ Sous-dossier existant sans tenir compte de la casse ('' s'il n'existe pas) }
Function SubDirCI(Const Root,Nm:String):String;
Begin
 SubDirCI:='';
 If DirOK(Root+Nm)Then SubDirCI:=Root+Nm+PathSep
 Else If DirOK(Root+LoStr(Nm))Then SubDirCI:=Root+LoStr(Nm)+PathSep
 Else If DirOK(Root+UpStr(Nm))Then SubDirCI:=Root+UpStr(Nm)+PathSep;
End;

Procedure ResolveRoot(I:Integer;Const Root:String);
Var P:String;
Begin
 RootDirs[I].Root:=Root;
 RootDirs[I].Parts:=''; RootDirs[I].P:=''; RootDirs[I].S:=''; RootDirs[I].Models:='';
 If Root='' Then Exit;
 RootDirs[I].Parts:=SubDirCI(Root,'PARTS');
 RootDirs[I].P:=SubDirCI(Root,'P');
 RootDirs[I].Models:=SubDirCI(Root,'MODELS');
 RootDirs[I].S:=SubDirCI(Root,'S');
 If(RootDirs[I].S='')And(RootDirs[I].Parts<>'')Then RootDirs[I].S:=SubDirCI(RootDirs[I].Parts,'S');
End;

Function FindUnder(I:Integer;Const N:String;Var Res:String):Boolean;
Begin
 FindUnder:=True;
 If FindCI(RootDirs[I].Root,N,Res)Then Exit;
 If(RootDirs[I].Parts<>'')And FindCI(RootDirs[I].Parts,N,Res)Then Exit;
 If(RootDirs[I].P<>'')And FindCI(RootDirs[I].P,N,Res)Then Exit;
 If(RootDirs[I].Models<>'')And FindCI(RootDirs[I].Models,N,Res)Then Exit;
 If(RootDirs[I].S<>'')And(Length(N)>2)And(UpCase(N[1])='S')And(N[2]=PathSep)Then
  If FindCI(RootDirs[I].S,Copy(N,3,255),Res)Then Exit;
 FindUnder:=False;
End;

Function FindPartFile(Const Name:String;Var Res:String):Boolean;
Var N:String;
Begin
 N:=ToSep(Name);
 FindPartFile:=True;
 If FindUnder(0,N,Res)Then Exit;
 If(AltLibDir<>'')And FindUnder(1,N,Res)Then Exit;
 If(ExtraDir<>'')And FindCI(ExtraDir,N,Res)Then Exit;
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
 If Length(T)<>1 Then Exit;
 Typ:=Ord(T[1])-48;
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
 If(Typ<1)Or(Typ>5)Then Exit;
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
  2,3,4,5:Begin
   N:=Typ;
   If Typ=5 Then N:=4;
   Ok:=True;
   For I:=0 To N-1 Do Begin
    Ok:=Ok And NumTok(Line,Pt[I].X) And NumTok(Line,Pt[I].Y) And NumTok(Line,Pt[I].Z);
   End;
   If Not Ok Then Exit;
   If Typ=5 Then Q:=NewPrim(P,PK_OPT) Else Q:=NewPrim(P,Typ);
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
   PK_LINE,PK_TRI,PK_QUAD,PK_OPT:Begin
    N:=Q^.Kind; If(N=PK_LINE)Or(N=PK_OPT)Then N:=2;
    For I:=0 To N-1 Do Begin
     BoxAdd(P^.AMin,P^.AMax,Q^.P[I]);
     If(Q^.Kind=PK_TRI)Or(Q^.Kind=PK_QUAD)Then BoxAdd(P^.BMin,P^.BMax,Q^.P[I]);
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
 If Depth>24 Then Exit;
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

{ Aplatit la piece : copie toute la geometrie des sous-fichiers dans P^.Flat,
  transformee, avec couleur heritee et sens d'enroulement corriges.
  Le rendu ne parcourt plus que cette liste (aucune recursion). }
Procedure FlatAppend(P:PPart;G:PPrim);
Begin
 G^.Next:=Nil;
 If P^.FlatTail=Nil Then P^.Flat:=G Else P^.FlatTail^.Next:=G;
 P^.FlatTail:=G;
End;

Procedure FlattenPart(P:PPart);
Var Q,F,G:PPrim; Flip:Boolean; I,N:Integer;
Begin
 If P^.Flattened Then Exit;
 P^.Flattened:=True;
 Q:=P^.Prims;
 While Q<>Nil Do Begin
  Case Q^.Kind Of
   PK_LINE,PK_TRI,PK_QUAD,PK_OPT,PK_STUD:Begin
    New(G); G^:=Q^;
    If Q^.Kind=PK_STUD Then Begin
     G^.Cull:=Ord((Q^.Cull=1)<>Q^.Inv); G^.Inv:=False;
    End;
    FlatAppend(P,G);
   End;
   PK_REF:If Q^.Ref<>Nil Then Begin
    FlattenPart(Q^.Ref);
    Flip:=(Q^.Cull=1)<>Q^.Inv;
    F:=Q^.Ref^.Flat;
    While F<>Nil Do Begin
     New(G); G^:=F^;
     If F^.Kind=PK_STUD Then Begin
      MatMul(Q^.M,F^.M,G^.M);
      G^.Cull:=Ord((F^.Cull=1)<>Flip);
      G^.Inv:=False;
     End
      Else Begin
       N:=4;
       If F^.Kind=PK_LINE Then N:=2 Else If F^.Kind=PK_TRI Then N:=3;
       For I:=0 To N-1 Do MatApply(Q^.M,F^.P[I],G^.P[I]);
       If Flip Then Begin
        If F^.Cull=1 Then G^.Cull:=2 Else If F^.Cull=2 Then G^.Cull:=1;
       End;
      End;
     If F^.Col=16 Then G^.Col:=Q^.Col;
     FlatAppend(P,G);
     F:=F^.Next;
    End;
   End;
  End;
  Q:=Q^.Next;
 End;
End;

{ ====================================================================== }
{ Catalogue des pieces (listes chainees)                                 }
{ ====================================================================== }

Procedure FreeFiltered;
Var F,N:PFil;
Begin
 F:=FilHead;
 While F<>Nil Do Begin N:=F^.Next; Dispose(F); F:=N; End;
 FilHead:=Nil; FilTail:=Nil; FilN:=0;
End;

Procedure FreeCategories;
Var C,N:PCategory;
Begin
 C:=CatList;
 While C<>Nil Do Begin N:=C^.Next; Dispose(C); C:=N; End;
 CatList:=Nil; CatListTail:=Nil; CatN:=0;
End;

Procedure FreeCatalog;
Var C,N:PCat;
Begin
 FreeFiltered;
 C:=CatHead;
 While C<>Nil Do Begin N:=C^.Next; Dispose(C); C:=N; End;
 CatHead:=Nil; CatTail:=Nil; CatCount:=0;
End;

Procedure AddCatalog(Const Fn,Desc,Cat,Keys:String);
Var C:PCat;
Begin
 New(C);
 C^.FileN:=Copy(Fn,1,20);
 C^.Desc:=Copy(TrimStr(Desc),1,60);
 C^.Keys:=Copy(Cat+' '+Keys,1,48);
 C^.CatI:=0;
 C^.Next:=Nil;
 If CatTail=Nil Then CatHead:=C Else CatTail^.Next:=C;
 CatTail:=C;
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
 FirstWord:=Copy(S,1,24);
End;

{ Tri fusion d'une liste chainee de pieces (ordre des descriptions) }
Function MergeCat(A,B:PCat):PCat;
Var H,T:PCat;
Begin
 H:=Nil; T:=Nil;
 While(A<>Nil)And(B<>Nil)Do Begin
  If A^.Desc<=B^.Desc Then Begin
   If T=Nil Then H:=A Else T^.Next:=A;
   T:=A; A:=A^.Next;
  End
   Else Begin
    If T=Nil Then H:=B Else T^.Next:=B;
    T:=B; B:=B^.Next;
   End;
 End;
 If A<>Nil Then Begin If T=Nil Then H:=A Else T^.Next:=A; End
 Else If B<>Nil Then Begin If T=Nil Then H:=B Else T^.Next:=B; End;
 MergeCat:=H;
End;

Function SortCatList(L:PCat):PCat;
Var Slow,Fast,B:PCat;
Begin
 If(L=Nil)Or(L^.Next=Nil)Then Begin SortCatList:=L; Exit; End;
 Slow:=L; Fast:=L^.Next;
 While(Fast<>Nil)And(Fast^.Next<>Nil)Do Begin Slow:=Slow^.Next; Fast:=Fast^.Next^.Next; End;
 B:=Slow^.Next; Slow^.Next:=Nil;
 SortCatList:=MergeCat(SortCatList(L),SortCatList(B));
End;

Procedure SortCatalog;
Var C:PCat;
Begin
 CatHead:=SortCatList(CatHead);
 CatTail:=CatHead;
 While(CatTail<>Nil)And(CatTail^.Next<>Nil)Do CatTail:=CatTail^.Next;
End;

Function CatNameAt(I:Integer):String;
Var C:PCategory;
Begin
 C:=CatList;
 While(C<>Nil)And(I>0)Do Begin C:=C^.Next; Dec(I); End;
 If C=Nil Then CatNameAt:='' Else CatNameAt:=C^.Name;
End;

Function CatIndexOf(Const N:String):Integer;
Var C:PCategory; I:Integer;
Begin
 C:=CatList; I:=0;
 While C<>Nil Do Begin
  If C^.Name=N Then Begin CatIndexOf:=I; Exit; End;
  C:=C^.Next; Inc(I);
 End;
 CatIndexOf:=-1;
End;

Procedure AddCategory(Const N:String);
Var C,P,Q:PCategory;
Begin
 New(C); C^.Name:=Copy(N,1,24); C^.Next:=Nil;
 { insertion triee (la categorie 0 reste en tete) }
 P:=CatList;
 If P=Nil Then Begin CatList:=C; CatListTail:=C; Inc(CatN); Exit; End;
 Q:=P;
 While(Q^.Next<>Nil)And(Q^.Next^.Name<C^.Name)Do Q:=Q^.Next;
 C^.Next:=Q^.Next; Q^.Next:=C;
 Inc(CatN);
End;

{ Categories : 0 !CATEGORY du fichier, sinon premier mot de la description }
Procedure BuildCategories;
Var C:PCat; W:String;
Begin
 FreeCategories;
 AddCategory(Fx('Toutes les pi\eces'));
 C:=CatHead;
 While C<>Nil Do Begin
  W:=Copy(C^.Keys,1,Pos(' ',C^.Keys+' ')-1);
  If W='' Then W:=FirstWord(C^.Desc);
  If CatIndexOf(W)<0 Then AddCategory(W);
  C:=C^.Next;
 End;
 C:=CatHead;
 While C<>Nil Do Begin
  W:=Copy(C^.Keys,1,Pos(' ',C^.Keys+' ')-1);
  If W='' Then W:=FirstWord(C^.Desc);
  C^.CatI:=CatIndexOf(W);
  If C^.CatI<0 Then C^.CatI:=0;
  C:=C^.Next;
 End;
End;

Procedure RefilterParts;
Var C:PCat; S,D:String; Ok:Boolean; F:PFil;
Begin
 FreeFiltered;
 S:=UpStr(SearchStr);
 C:=CatHead;
 While C<>Nil Do Begin
  Ok:=True;
  If(CatSel<>0)And(C^.CatI<>CatSel)Then Ok:=False;
  If Ok And(S<>'')Then Begin
   D:=UpStr(C^.Desc+' '+C^.FileN+' '+C^.Keys);
   If Pos(S,D)=0 Then Ok:=False;
  End;
  If Ok Then Begin
   New(F); F^.C:=C; F^.Next:=Nil;
   If FilTail=Nil Then FilHead:=F Else FilTail^.Next:=F;
   FilTail:=F; Inc(FilN);
  End;
  C:=C^.Next;
 End;
 PartTop:=0;
 PartSel:=-1;
End;

Function FilAt(I:Integer):PCat;
Var F:PFil;
Begin
 F:=FilHead;
 While(F<>Nil)And(I>0)Do Begin F:=F^.Next; Dec(I); End;
 If F=Nil Then FilAt:=Nil Else FilAt:=F^.C;
End;

{ Lit l'en-tete d'un fichier .DAT : description, categorie, mots-cles.
  Retourne False si c'est une sous-piece / primitive / piece obsolete. }
Function ReadHeader(Const Path:String;Var Desc,Cat,Keys:String):Boolean;
Var F:Text; L,T:String; N:Integer; Org:String;
Begin
 ReadHeader:=False;
 Desc:=''; Cat:=''; Keys:=''; Org:='';
 {$I-}
 Assign(F,Path); Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 N:=0;
 While(Not Eof(F))And(N<30)Do Begin
  {$I-}ReadLn(F,L);{$I+}
  If IOResult<>0 Then L:='';
  L:=TrimStr(L); Inc(N);
  If(L<>'')And(L[1]<>'0')Then N:=99;
  If(Length(L)>=1)And(L[1]='0')Then Begin
   Tok(L);
   T:=Tok(L);
   If(Desc='')And(T<>'')And(T[1]<>'!')And(UpStr(T)<>'BFC')And(UpStr(T)<>'NAME:')Then
    Desc:=TrimStr(T+' '+L)
   Else If UpStr(T)='!CATEGORY' Then Cat:=TrimStr(L)
   Else If UpStr(T)='!KEYWORDS' Then Keys:=TrimStr(L)
   Else If UpStr(T)='!LDRAW_ORG' Then Org:=UpStr(TrimStr(L));
  End;
 End;
 Close(F);
 If Desc='' Then Exit;
 If(Desc[1]='~')Or(Desc[1]='=')Or(Desc[1]='_')Then Exit;
 If(Pos('SUBPART',Org)>0)Or(Pos('PRIMITIVE',Org)>0)Then Exit;
 If Cat<>'' Then Cat:=Copy(Cat,1,Pos(' ',Cat+' ')-1);
 ReadHeader:=True;
End;

Procedure SaveCatalog(Const Dir:String;From:PCat);
Var F:Text; C:PCat;
Begin
 {$I-}
 Assign(F,Dir+'PARTS.LST'); Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 C:=From;
 While C<>Nil Do Begin
  WriteLn(F,C^.FileN,'|',C^.Desc,'|',C^.Keys);
  C:=C^.Next;
 End;
 Close(F);
End;

{ Parcourt un repertoire de pieces (dossier PARTS s'il existe) }
Procedure ScanDirParts(Const Root:String);
Var SR:SearchRec; D,Cat,Keys,Dir:String; Pass:Integer; Start:Integer;
Begin
 Start:=CatCount;
 Dir:=SubDirCI(Root,'PARTS');
 If Dir='' Then Dir:=Root;
 For Pass:=0 To 1 Do Begin
  {$IFDEF FPC}
  If Pass=0 Then FindFirst(Dir+'*.DAT',AnyFile,SR) Else FindFirst(Dir+'*.dat',AnyFile,SR);
  {$ELSE}
  If Pass=0 Then FindFirst(Dir+'*.DAT',AnyFile,SR) Else DosError:=18;
  {$ENDIF}
  If(Pass=1)And(CatCount>Start)Then DosError:=18;
  While DosError=0 Do Begin
   If(SR.Attr And Directory)=0 Then
    If ReadHeader(Dir+SR.Name,D,Cat,Keys)Then AddCatalog(UpStr(SR.Name),D,Cat,Keys);
   FindNext(SR);
  End;
  {$IFDEF FPC}FindClose(SR);{$ENDIF}
 End;
End;

{ Charge le catalogue d'une racine : index PARTS.LST ou parcours }
Procedure LoadCatalogFrom(Const Root:String);
Var F:Text; L,A,B,C:String; P:Integer; Before:Integer; Last,NewH:PCat;
Begin
 Before:=CatCount;
 Last:=CatTail;
 {$I-}
 Assign(F,Root+'PARTS.LST'); Reset(F);
 {$I+}
 If IOResult=0 Then Begin
  While Not Eof(F) Do Begin
   {$I-}ReadLn(F,L);{$I+}
   If IOResult<>0 Then L:='';
   P:=Pos('|',L);
   If P>1 Then Begin
    A:=Copy(L,1,P-1); L:=Copy(L,P+1,255);
    P:=Pos('|',L);
    If P>0 Then Begin B:=Copy(L,1,P-1); C:=Copy(L,P+1,255); End
    Else Begin B:=L; C:=''; End;
    AddCatalog(A,B,'',C);
    If(Length(C)>0)And(CatTail<>Nil)Then CatTail^.Keys:=Copy(C,1,48);
   End;
  End;
  Close(F);
 End;
 If CatCount=Before Then Begin
  { les pieces de cette racine sont triees et enregistrees a part }
  If Last=Nil Then Begin NewH:=Nil; End
  Else Begin NewH:=Last^.Next; End;
  ScanDirParts(Root);
  If Last=Nil Then Begin NewH:=CatHead; CatHead:=Nil; CatTail:=Nil; End
  Else Begin NewH:=Last^.Next; Last^.Next:=Nil; CatTail:=Last; End;
  CatCount:=Before;
  NewH:=SortCatList(NewH);
  SaveCatalog(Root,NewH);
  { rattache la liste triee }
  While NewH<>Nil Do Begin
   If CatTail=Nil Then CatHead:=NewH Else CatTail^.Next:=NewH;
   CatTail:=NewH; NewH:=NewH^.Next; CatTail^.Next:=Nil; Inc(CatCount);
  End;
 End;
End;

{ Reconstruit les index PARTS.LST (parcours de tous les fichiers .DAT) }
Procedure RescanLibrary;
Begin
 FreeCatalog;
 ScanDirParts(LibDir); SortCatalog; SaveCatalog(LibDir,CatHead);
 If AltLibDir<>'' Then Begin
  FreeCatalog;
  ScanDirParts(AltLibDir); SortCatalog; SaveCatalog(AltLibDir,CatHead);
 End;
End;

Procedure LoadCatalog;
Begin
 FreeCatalog;
 LoadCatalogFrom(LibDir);
 If AltLibDir<>'' Then LoadCatalogFrom(AltLibDir);
 BuildCategories;
 CatSel:=0; CatTop:=0; SearchStr:='';
 RefilterParts;
End;

{ ====================================================================== }
{ Modeles, pieces, groupes, cameras                                      }
{ ====================================================================== }

Function FindModel(Const N:String):Integer;
Var I:Integer; U:String;
Begin
 U:=UpStr(N);
 For I:=0 To ModelCount-1 Do
  If(Length(Models[I].Name)=Length(U))And(UpStr(Models[I].Name)=U)Then Begin FindModel:=I; Exit; End;
 FindModel:=-1;
End;

{ Sous-modele reference par une piece (resultat memorise) ; -1 si c'est une piece }
Function PieceSub(Q:PPiece):Integer;
Begin
 If Q^.SubEpoch<>ModEpoch Then Begin
  Q^.SubIdx:=FindModel(Q^.Name);
  Q^.SubEpoch:=ModEpoch;
 End;
 PieceSub:=Q^.SubIdx;
End;

Procedure FreeList(Q:PPiece);
Var N:PPiece;
Begin
 While Q<>Nil Do Begin N:=Q^.Next; Dispose(Q); Q:=N; End;
End;

Procedure FreeGroups;
Var G,N:PGroup;
Begin
 G:=GroupHead;
 While G<>Nil Do Begin N:=G^.Next; Dispose(G); G:=N; End;
 GroupHead:=Nil; NextGroupId:=1;
End;

Procedure FreeCameras;
Var C,N:PCamera; K,KN:PKey;
Begin
 C:=CamHead;
 While C<>Nil Do Begin N:=C^.Next; Dispose(C); C:=N; End;
 CamHead:=Nil;
 K:=KeyHead;
 While K<>Nil Do Begin KN:=K^.Next; Dispose(K); K:=KN; End;
 KeyHead:=Nil;
End;

Function NewGroupId(Const Nm:String):LongInt;
Var G:PGroup; T:PGroup;
Begin
 New(G);
 G^.Id:=NextGroupId; Inc(NextGroupId);
 G^.Name:=Copy(Nm,1,40); G^.Next:=Nil;
 If GroupHead=Nil Then GroupHead:=G
 Else Begin T:=GroupHead; While T^.Next<>Nil Do T:=T^.Next; T^.Next:=G; End;
 NewGroupId:=G^.Id;
End;

Function GroupIdByName(Const Nm:String):LongInt;
Var G:PGroup;
Begin
 G:=GroupHead;
 While G<>Nil Do Begin
  If G^.Name=Nm Then Begin GroupIdByName:=G^.Id; Exit; End;
  G:=G^.Next;
 End;
 GroupIdByName:=0;
End;

Function GroupName(Id:LongInt):String;
Var G:PGroup;
Begin
 G:=GroupHead;
 While G<>Nil Do Begin
  If G^.Id=Id Then Begin GroupName:=G^.Name; Exit; End;
  G:=G^.Next;
 End;
 GroupName:='Groupe '+IntStr(Id);
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
 Inc(ModEpoch);
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
 Inc(ModEpoch);
End;

Function AddPiece(M:Integer;Const Name:String;Col:LongInt;Const Mt:TMat;Step:Integer):PPiece;
Var Q:PPiece;
Begin
 New(Q);
 FillChar(Q^,SizeOf(TPiece),0);
 Q^.Name:=Copy(Name,1,40);
 Q^.Col:=Col; Q^.M:=Mt; Q^.Step:=Step;
 Q^.SubEpoch:=-1; Q^.Epoch:=-1;
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

Function PieceVisible(Q:PPiece):Boolean;
Begin
 PieceVisible:=(Q^.Step<=Models[CurModel].CurStep)And(Not Q^.Hidden)
   And((Q^.HideStep=0)Or(Models[CurModel].CurStep<Q^.HideStep));
End;

{ Boite englobante d'un modele transforme par Xf }
Procedure ModelBounds(M:Integer;Const Xf:TMat;Body,AllSteps:Boolean;Var Mn,Mx:TVec;Depth:Integer);
Var Q:PPiece; T:TMat; S:Integer; P:PPart;
Begin
 If Depth>6 Then Exit;
 Q:=Models[M].First;
 While Q<>Nil Do Begin
  If AllSteps Or((Q^.Step<=Models[M].CurStep)And(Not Q^.Hidden)
    And((Q^.HideStep=0)Or(Models[M].CurStep<Q^.HideStep)))Then Begin
   MatMul(Xf,Q^.M,T);
   S:=PieceSub(Q);
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
Var S:Integer; P:PPart;
Begin
 BoxEmpty(Mn,Mx);
 S:=PieceSub(Q);
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

Function PartDescByName(Const Nm:String):String;
Var C:PCat; U:String;
Begin
 PartDescByName:=Nm;
 U:=UpStr(Nm);
 C:=CatHead;
 While C<>Nil Do Begin
  If C^.FileN=U Then Begin PartDescByName:=C^.Desc; Exit; End;
  C:=C^.Next;
 End;
End;

Function PieceDesc(Q:PPiece):String;
Begin
 If PieceSub(Q)>=0 Then PieceDesc:=Q^.Name
 Else PieceDesc:=PartDescByName(Q^.Name);
End;

{ ====================================================================== }
{ Annuler / retablir (piles chainees)                                    }
{ ====================================================================== }

Function CopyPiece(Q:PPiece):PPiece;
Var N:PPiece;
Begin
 New(N);
 N^:=Q^;
 N^.Next:=Nil; N^.Prev:=Nil; N^.Part:=Nil; N^.Epoch:=-1; N^.SubEpoch:=-1;
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
Var S:PSnap; I:Integer; M,T:PSnapMod;
Begin
 MakeSnap:=Nil;
 If MaxAvail<LongInt(SizeOf(TSnap))+30000 Then Exit;
 New(S);
 S^.NMod:=ModelCount; S^.Cur:=CurModel; S^.Col:=CurColor; S^.Next:=Nil; S^.Mods:=Nil;
 T:=Nil;
 For I:=0 To ModelCount-1 Do Begin
  New(M);
  M^.Name:=Models[I].Name; M^.Step:=Models[I].CurStep;
  M^.List:=CopyList(Models[I].First); M^.Next:=Nil;
  If T=Nil Then S^.Mods:=M Else T^.Next:=M;
  T:=M;
 End;
 MakeSnap:=S;
End;

Procedure FreeSnap(S:PSnap);
Var M,N:PSnapMod;
Begin
 If S=Nil Then Exit;
 M:=S^.Mods;
 While M<>Nil Do Begin N:=M^.Next; FreeList(M^.List); Dispose(M); M:=N; End;
 Dispose(S);
End;

Procedure ApplySnap(S:PSnap);
Var I:Integer; Q:PPiece; M,N:PSnapMod;
Begin
 ClearAllModels;
 ModelCount:=S^.NMod; CurModel:=S^.Cur;
 If CurModel>=ModelCount Then CurModel:=0;
 M:=S^.Mods; I:=0;
 While(M<>Nil)And(I<ModelCount)Do Begin
  N:=M^.Next;
  Models[I].Used:=True;
  Models[I].Name:=M^.Name;
  Models[I].First:=M^.List;
  Models[I].CurStep:=M^.Step;
  Models[I].Count:=0;
  Models[I].Last:=Nil;
  Q:=M^.List;
  While Q<>Nil Do Begin Inc(Models[I].Count); Models[I].Last:=Q; Q:=Q^.Next; End;
  Dispose(M);
  M:=N; Inc(I);
 End;
 Dispose(S);
 Inc(ModEpoch);
End;

Procedure TrimStack(Var Top:PSnap;Var N:Integer);
Var P,Q:PSnap;
Begin
 While N>UNDO_MAX Do Begin
  P:=Top;
  If(P=Nil)Or(P^.Next=Nil)Then Begin N:=UNDO_MAX; Exit; End;
  While P^.Next^.Next<>Nil Do P:=P^.Next;
  Q:=P^.Next; P^.Next:=Nil;
  FreeSnap(Q);
  Dec(N);
 End;
End;

Procedure ClearRedo;
Var S,N:PSnap;
Begin
 S:=RedoTop;
 While S<>Nil Do Begin N:=S^.Next; FreeSnap(S); S:=N; End;
 RedoTop:=Nil; RedoN:=0;
End;

Procedure PushUndo;
Var S:PSnap;
Begin
 S:=MakeSnap;
 If S=Nil Then Exit;
 S^.Next:=UndoTop; UndoTop:=S; Inc(UndoN);
 TrimStack(UndoTop,UndoN);
 ClearRedo;
 Modified:=True;
End;

Procedure DoUndo;
Var S,C:PSnap;
Begin
 If UndoTop=Nil Then Exit;
 C:=MakeSnap;
 If C<>Nil Then Begin C^.Next:=RedoTop; RedoTop:=C; Inc(RedoN); TrimStack(RedoTop,RedoN); End;
 S:=UndoTop; UndoTop:=S^.Next; Dec(UndoN);
 S^.Next:=Nil;
 ApplySnap(S);
 Modified:=True;
End;

Procedure DoRedo;
Var S,C:PSnap;
Begin
 If RedoTop=Nil Then Exit;
 C:=MakeSnap;
 If C<>Nil Then Begin C^.Next:=UndoTop; UndoTop:=C; Inc(UndoN); TrimStack(UndoTop,UndoN); End;
 S:=RedoTop; RedoTop:=S^.Next; Dec(RedoN);
 S^.Next:=Nil;
 ApplySnap(S);
 Modified:=True;
End;

Procedure ClearHistory;
Var S,N:PSnap;
Begin
 S:=UndoTop;
 While S<>Nil Do Begin N:=S^.Next; FreeSnap(S); S:=N; End;
 UndoTop:=Nil; UndoN:=0;
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
 FreeGroups;
 FreeCameras;
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

{ Convertit position / cible / vecteur haut en angles de vue }
Procedure CameraFromLook(Const Pos,Tgt:TVec;Var Yaw,Pitch,Dist:Real);
Var D:TVec;
Begin
 D.X:=Pos.X-Tgt.X; D.Y:=Pos.Y-Tgt.Y; D.Z:=Pos.Z-Tgt.Z;
 Dist:=Sqrt(D.X*D.X+D.Y*D.Y+D.Z*D.Z);
 If Dist<1 Then Dist:=1;
 Pitch:=ArcSin(-D.Y/Dist)*180/Pi;
 Yaw:=ATan2(D.X,D.Z)*180/Pi;
 If Yaw<0 Then Yaw:=Yaw+360;
End;

Procedure LookFromCamera(Yaw,Pitch,Dist:Real;Const Tgt:TVec;Var Pos:TVec);
Var Y,P:Real;
Begin
 Y:=Yaw*Pi/180; P:=Pitch*Pi/180;
 Pos.X:=Tgt.X+Cos(P)*Sin(Y)*Dist; Pos.Y:=Tgt.Y-Sin(P)*Dist; Pos.Z:=Tgt.Z+Cos(P)*Cos(Y)*Dist;
End;

Function SaveDoc(Const Path:String):Boolean;
Var F:Text; I,S,MS:Integer; Q,R:PPiece; Multi:Boolean; C:PCamera; K:PKey; Pos:TVec;
 Procedure PieceMeta(P:PPiece);
 Begin
  If P^.Hidden Then WriteLn(F,'0 !LEOCAD PIECE HIDDEN');
  If P^.HideStep>0 Then WriteLn(F,'0 !LEOCAD PIECE STEP_HIDE ',P^.HideStep);
  If P^.Locked Then WriteLn(F,'0 !LEOCAD PIECE LOCKED');
  WriteLn(F,PieceLine(P));
 End;
Begin
 SaveDoc:=False;
 {$I-}
 Assign(F,Path); Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 Multi:=(ExtOf(Path)='.MPD')Or(ModelCount>1);
 For I:=0 To ModelCount-1 Do Begin
  If(I=0)And(Not Multi)Then WriteLn(F,'0 ',BaseOf(Path))
  Else WriteLn(F,'0 FILE ',Models[I].Name);
  WriteLn(F,'0 Name: ',Models[I].Name);
  WriteLn(F,'0 Author: LEOCAD');
  If I=0 Then Begin
   C:=CamHead;
   While C<>Nil Do Begin
    LookFromCamera(C^.Yaw,C^.Pitch,C^.Dist,C^.Tgt,Pos);
    Write(F,'0 !LEOCAD CAMERA FOV ',FmtNum(C^.Fov),' ZNEAR 25 ZFAR 50000 POSITION ',FmtNum(Pos.X),' ',FmtNum(Pos.Y),' ',FmtNum(Pos.Z),
     ' TARGET_POSITION ',FmtNum(C^.Tgt.X),' ',FmtNum(C^.Tgt.Y),' ',FmtNum(C^.Tgt.Z),' UP_VECTOR 0 -1 0');
    If Not C^.Persp Then Write(F,' ORTHOGRAPHIC ZOOM ',FmtNum(C^.Zoom*1000));
    WriteLn(F,' NAME ',C^.Name);
    C:=C^.Next;
   End;
   K:=KeyHead;
   While K<>Nil Do Begin
    WriteLn(F,'0 !LEOCAD ANIMATION KEY ',K^.Time,' ',FmtNum(K^.Yaw),' ',FmtNum(K^.Pitch),' ',FmtNum(K^.Dist),' ',
     FmtNum(K^.Zoom*1000),' ',FmtNum(K^.Fov),' ',Ord(K^.Persp),' ',K^.Step,' ',FmtNum(K^.Tgt.X),' ',FmtNum(K^.Tgt.Y),' ',FmtNum(K^.Tgt.Z));
    K:=K^.Next;
   End;
  End;
  MS:=MaxStep(I);
  For S:=1 To MS Do Begin
   Q:=Models[I].First;
   While Q<>Nil Do Begin Q^.Mark:=False; Q:=Q^.Next; End;
   Q:=Models[I].First;
   While Q<>Nil Do Begin
    If(Q^.Step=S)And(Q^.Group=0)Then PieceMeta(Q);
    Q:=Q^.Next;
   End;
   Q:=Models[I].First;
   While Q<>Nil Do Begin
    If(Q^.Step=S)And(Q^.Group<>0)And(Not Q^.Mark)Then Begin
     WriteLn(F,'0 !LEOCAD GROUP BEGIN ',GroupName(Q^.Group));
     R:=Q;
     While R<>Nil Do Begin
      If(R^.Step=S)And(R^.Group=Q^.Group)Then Begin PieceMeta(R); R^.Mark:=True; End;
      R:=R^.Next;
     End;
     WriteLn(F,'0 !LEOCAD GROUP END');
    End;
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
 CurGroup:LongInt;
 PHidden,PLocked:Boolean; PHide:Integer;
 Cam:PCamera; Key:PKey; Pos,Up:TVec; Orth:Boolean; Q:PPiece;
 Function RN:Real;
 Var X:Real;
 Begin
  If NumTok(Line,X)Then RN:=X Else RN:=0;
 End;
Begin
 LoadDoc:=False;
 {$I-}
 Assign(F,Path); Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 ClearHistory;
 ClearAllModels;
 FreeGroups;
 FreeCameras;
 M:=NewModel(BaseOf(Path));
 Step:=1; Seen:=False; CurGroup:=0; PHidden:=False; PLocked:=False; PHide:=0;
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
     If(Not Seen)And(Models[M].Count=0)Then Begin Models[M].Name:=Copy(Nm,1,40); Inc(ModEpoch); End
     Else Begin
      I:=NewModel(Nm);
      If I>=0 Then M:=I;
     End;
     Seen:=True; Step:=1;
    End
     Else If T2='STEP' Then Inc(Step)
     Else If T2='!LEOCAD' Then Begin
      T2:=UpStr(Tok(Line));
      If T2='GROUP' Then Begin
       T2:=UpStr(Tok(Line));
       If T2='BEGIN' Then Begin
        Nm:=TrimStr(Line);
        CurGroup:=GroupIdByName(Nm);
        If CurGroup=0 Then CurGroup:=NewGroupId(Nm);
       End
        Else If T2='END' Then CurGroup:=0;
      End
       Else If T2='PIECE' Then Begin
        T2:=UpStr(Tok(Line));
        If T2='HIDDEN' Then PHidden:=True
        Else If T2='LOCKED' Then PLocked:=True
        Else If T2='STEP_HIDE' Then PHide:=Round(RN);
       End
       Else If T2='CAMERA' Then Begin
        New(Cam);
        FillChar(Cam^,SizeOf(TCamera),0);
        Cam^.Persp:=True; Cam^.Fov:=30; Cam^.Zoom:=1; Cam^.Name:='Camera';
        VSet(Pos,0,-100,-100); VSet(Cam^.Tgt,0,0,0); VSet(Up,0,-1,0);
        Orth:=False;
        Repeat
         T2:=UpStr(Tok(Line));
         If T2='FOV' Then Cam^.Fov:=RN
         Else If T2='POSITION' Then Begin Pos.X:=RN; Pos.Y:=RN; Pos.Z:=RN; End
         Else If T2='TARGET_POSITION' Then Begin Cam^.Tgt.X:=RN; Cam^.Tgt.Y:=RN; Cam^.Tgt.Z:=RN; End
         Else If T2='UP_VECTOR' Then Begin Up.X:=RN; Up.Y:=RN; Up.Z:=RN; End
         Else If T2='ZOOM' Then Cam^.Zoom:=RN/1000
         Else If T2='ORTHOGRAPHIC' Then Cam^.Persp:=False
         Else If T2='NAME' Then Begin Cam^.Name:=Copy(TrimStr(Line),1,30); Line:=''; End;
        Until T2='';
        CameraFromLook(Pos,Cam^.Tgt,Cam^.Yaw,Cam^.Pitch,Cam^.Dist);
        If Cam^.Zoom<=0 Then Cam^.Zoom:=1;
        If Cam^.Fov<5 Then Cam^.Fov:=30;
        Cam^.Next:=Nil;
        If CamHead=Nil Then CamHead:=Cam
        Else Begin
         Q:=Nil;
         Cam^.Next:=CamHead; CamHead:=Cam;
        End;
       End
       Else If T2='ANIMATION' Then Begin
        T2:=UpStr(Tok(Line));
        If T2='KEY' Then Begin
         New(Key);
         FillChar(Key^,SizeOf(TKey),0);
         Key^.Time:=Round(RN); Key^.Yaw:=RN; Key^.Pitch:=RN; Key^.Dist:=RN; Key^.Zoom:=RN/1000;
         Key^.Fov:=RN; Key^.Persp:=RN>0; Key^.Step:=Round(RN);
         Key^.Tgt.X:=RN; Key^.Tgt.Y:=RN; Key^.Tgt.Z:=RN;
         Key^.Next:=KeyHead; KeyHead:=Key;
        End;
       End;
     End;
   End
    Else If T='1' Then Begin
     Ok:=NumTok(Line,Cl);
     Ok:=Ok And NumTok(Line,Mt.T.X) And NumTok(Line,Mt.T.Y) And NumTok(Line,Mt.T.Z);
     For I:=0 To 2 Do
      Ok:=Ok And NumTok(Line,Mt.R[I,0]) And NumTok(Line,Mt.R[I,1]) And NumTok(Line,Mt.R[I,2]);
     Nm:=TrimStr(Line);
     If Ok And(Nm<>'')Then Begin
      Q:=AddPiece(M,Nm,Round(Cl),Mt,Step);
      Q^.Group:=CurGroup; Q^.Hidden:=PHidden; Q^.Locked:=PLocked; Q^.HideStep:=PHide;
     End;
     PHidden:=False; PLocked:=False; PHide:=0;
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
 PolyTail:PPoly;

{ La liste des polygones est recyclee : reservoir PolyPool }
Procedure PolyReset;
Begin
 If PolyHead<>Nil Then Begin
  PolyTail:=PolyHead;
  While PolyTail^.Next<>Nil Do PolyTail:=PolyTail^.Next;
  PolyTail^.Next:=PolyPool;
  PolyPool:=PolyHead;
  PolyHead:=Nil;
 End;
 PolyTail:=Nil;
 PolyN:=0;
End;

Function NewPoly:PPoly;
Var P:PPoly;
Begin
 NewPoly:=Nil;
 If PolyN>=PolyMax Then Begin PolyOverflow:=True; Exit; End;
 If PolyPool<>Nil Then Begin P:=PolyPool; PolyPool:=P^.Next; End
 Else Begin
  If MaxAvail<LongInt(SizeOf(TPoly))+20000 Then Begin
   PolyMax:=PolyN; PolyOverflow:=True; Exit;
  End;
  New(P);
 End;
 P^.Next:=Nil;
 If PolyTail=Nil Then PolyHead:=P Else PolyTail^.Next:=P;
 PolyTail:=P;
 Inc(PolyN);
 NewPoly:=P;
End;

Procedure FreePolyBlocks;
Var P,N:PPoly;
Begin
 PolyReset;
 P:=PolyPool;
 While P<>Nil Do Begin N:=P^.Next; Dispose(P); P:=N; End;
 PolyPool:=Nil;
End;

Procedure SetupCamera(Var V:TView);
Var Dir,F,U,R,Up:TVec; PY,YW,D,T:Real; W,H:Integer;
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
 T:=Sin(V.Fov*Pi/360)/Cos(V.Fov*Pi/360);
 If T<0.05 Then T:=0.05;
 CamFocal:=(H/2)/T;
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

Function EdgeColor(Code:LongInt;Sel:Boolean):Integer;
Var Tr:Boolean;
Begin
 If Sel Then Begin EdgeColor:=12; Exit; End;
 If(Code=24)Or(Code=16)Then Begin
  EdgeColor:=0;
 End
  Else EdgeColor:=GrpIdx[ColGroup(Code,Tr),1];
End;

Procedure ClipNear(Var PA,PB:TVec;Var Ok:Boolean);
Var T:Real;
Begin
 Ok:=True;
 If CamPersp Then Begin
  If(PA.Z<NEARZ)And(PB.Z<NEARZ)Then Begin Ok:=False; Exit; End;
  If PA.Z<NEARZ Then Begin
   T:=(NEARZ-PA.Z)/(PB.Z-PA.Z);
   PA.X:=PA.X+(PB.X-PA.X)*T; PA.Y:=PA.Y+(PB.Y-PA.Y)*T; PA.Z:=NEARZ;
  End
  Else If PB.Z<NEARZ Then Begin
   T:=(NEARZ-PB.Z)/(PA.Z-PB.Z);
   PB.X:=PB.X+(PA.X-PB.X)*T; PB.Y:=PB.Y+(PA.Y-PB.Y)*T; PB.Z:=NEARZ;
  End;
 End;
End;

Procedure AddLine(Const A,B:TVec;Code:LongInt;Sel:Boolean;Owner:Integer);
Var Pl:PPoly; PA,PB:TVec; Z:Real; Ok:Boolean;
Begin
 PA:=A; PB:=B;
 ClipNear(PA,PB,Ok);
 If Not Ok Then Exit;
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

{ Ligne optionnelle (type 5) : tracee seulement si les deux points de controle
  sont du meme cote de la ligne a l'ecran }
Procedure AddOptLine(Const P:Array Of TVec;Code:LongInt;Sel:Boolean;Owner:Integer);
Var X:Array[0..3] Of Integer; Y:Array[0..3] Of Integer; I:Integer; S1,S2:LongInt; A,B:TVec; Ok:Boolean;
Begin
 If CamPersp Then
  For I:=0 To 3 Do If P[I].Z<NEARZ Then Exit;
 For I:=0 To 3 Do Proj(P[I],X[I],Y[I]);
 S1:=LongInt(X[1]-X[0])*(Y[2]-Y[0])-LongInt(Y[1]-Y[0])*(X[2]-X[0]);
 S2:=LongInt(X[1]-X[0])*(Y[3]-Y[0])-LongInt(Y[1]-Y[0])*(X[3]-X[0]);
 If(S1>0)And(S2>0)Or(S1<0)And(S2<0)Then Begin
  A:=P[0]; B:=P[1];
  AddLine(A,B,Code,Sel,Owner);
 End;
End;

{ Ajoute la face FP[0..N-1] (espace vue) }
Procedure AddFace(N:Integer;Cull:Byte;Sg:Integer;Code:LongInt;Owner:Integer);
Var
 I,S,G,Sh:Integer;
 NX,NY,NZ,EX,EY,EZ,GX,GY,GZ,D,L,Lm,ZM:Real;
 Pl:PPoly; Tr:Boolean;
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
 G:=ColGroup(Code,Tr);
 Sh:=Trunc((0.10+0.90*Lm)*NSHADE*0.999);
 If Sh<0 Then Sh:=0; If Sh>=NSHADE Then Sh:=NSHADE-1;
 Pl:=NewPoly;
 If Pl=Nil Then Exit;
 ZM:=FP[0].Z;
 For I:=0 To N-1 Do Begin
  Proj(FP[I],Pl^.X[I],Pl^.Y[I]);
  If FP[I].Z>ZM Then ZM:=FP[I].Z;
 End;
 Pl^.Z:=Round(ZM*4);
 Pl^.Col:=GrpIdx[G,Sh];
 Pl^.N:=N;
 Pl^.Fl:=0;
 If Tr Then Pl^.Fl:=1;
 If WireOn Then Pl^.Fl:=Pl^.Fl Or 4;
 Pl^.Owner:=Owner;
End;

Procedure DrawStud(Const M:TMat;Const Q:PPrim;Code:LongInt;Sg:Integer;Owner:Integer;Sel:Boolean);
Var X:TMat; I,J:Integer; T,B:Array[0..7] Of TVec; V:TVec;
Begin
 MatMul(M,Q^.M,X);
 If Q^.Cull=1 Then Sg:=-Sg;
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

{ Rendu d'une piece aplatie : plus aucune recursion de sous-fichiers }
Procedure RenderPart(P:PPart;Const M:TMat;Code:LongInt;Sg:Integer;Owner:Integer;Sel:Boolean);
Var Q:PPrim; C2:LongInt; I,N,PN:Integer; A,B:TVec; O:Array[0..3] Of TVec;
Begin
 If Not P^.Flattened Then FlattenPart(P);
 Q:=P^.Flat;
 While Q<>Nil Do Begin
  C2:=Q^.Col; If C2=16 Then C2:=Code;
  Case Q^.Kind Of
   PK_STUD:If StudEff<3 Then DrawStud(M,Q,C2,Sg,Owner,Sel);
   PK_LINE:If EdgesOn Then Begin
    MatApply(M,Q^.P[0],A); MatApply(M,Q^.P[1],B);
    AddLine(A,B,C2,Sel,Owner);
   End;
   PK_OPT:If EdgesOn Then Begin
    For I:=0 To 3 Do MatApply(M,Q^.P[I],O[I]);
    AddOptLine(O,C2,Sel,Owner);
   End;
   PK_TRI,PK_QUAD:Begin
    N:=Q^.Kind;
    For I:=0 To N-1 Do MatApply(M,Q^.P[I],FP[I]);
    PN:=PolyN;
    AddFace(N,Q^.Cull,Sg,C2,Owner);
    If(Q^.Col<>16)And(PolyN>PN)And(PolyTail<>Nil)Then PolyTail^.Z:=PolyTail^.Z-10;
   End;
  End;
  Q:=Q^.Next;
 End;
End;

Procedure RenderPiece(Q:PPiece;Const Parent:TMat;Sg0:Integer;PCode:LongInt;Owner:Integer;Sel:Boolean;Depth:Integer);
Var T:TMat; Sg,S:Integer; C:LongInt; P:PPart; Q2:PPiece;
Begin
 MatMul(Parent,Q^.M,T);
 Sg:=Sg0;
 If MatDet(Q^.M)<0 Then Sg:=-Sg;
 C:=Q^.Col; If(C=16)Or(C=24)Then C:=PCode;
 S:=PieceSub(Q);
 If S>=0 Then Begin
  If Depth<12 Then Begin
   Q2:=Models[S].First;
   While Q2<>Nil Do Begin
    RenderPiece(Q2,T,Sg,C,Owner,Sel,Depth+1);
    Q2:=Q2^.Next;
   End;
  End;
 End
  Else Begin
   P:=PiecePart(Q);
   If P<>Nil Then RenderPart(P,T,C,Sg,Owner,Sel);
  End;
End;

Procedure BuildScene(WithGhost:Boolean);
Var Q:PPiece; I,N:Integer;
Begin
 PolyReset;
 PolyOverflow:=False; PolyMax:=MAXPOLY;
 N:=0;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin If PieceVisible(Q)Then Inc(N); Q:=Q^.Next; End;
 Case StudMode Of
  0:If N<=120 Then StudEff:=1 Else If N<=700 Then StudEff:=2 Else StudEff:=3;
  1:StudEff:=1;
  2:StudEff:=2;
 Else StudEff:=3;
 End;
 I:=0;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  Inc(I);
  If PieceVisible(Q)Then RenderPiece(Q,CamM,-1,7,I,Q^.Sel,0);
  Q:=Q^.Next;
 End;
 If WithGhost And(GhostPiece<>Nil)Then RenderPiece(GhostPiece,CamM,-1,7,0,False,0);
End;

{ Tri fusion de la liste des polygones : lointain d'abord (Z decroissant) }
Function MergePoly(A,B:PPoly):PPoly;
Var H,T:PPoly;
Begin
 H:=Nil; T:=Nil;
 While(A<>Nil)And(B<>Nil)Do Begin
  If A^.Z>=B^.Z Then Begin
   If T=Nil Then H:=A Else T^.Next:=A;
   T:=A; A:=A^.Next;
  End
   Else Begin
    If T=Nil Then H:=B Else T^.Next:=B;
    T:=B; B:=B^.Next;
   End;
 End;
 If A<>Nil Then Begin If T=Nil Then H:=A Else T^.Next:=A; End
 Else If B<>Nil Then Begin If T=Nil Then H:=B Else T^.Next:=B; End;
 MergePoly:=H;
End;

Function SortPolyList(L:PPoly):PPoly;
Var Slow,Fast,B:PPoly;
Begin
 If(L=Nil)Or(L^.Next=Nil)Then Begin SortPolyList:=L; Exit; End;
 Slow:=L; Fast:=L^.Next;
 While(Fast<>Nil)And(Fast^.Next<>Nil)Do Begin Slow:=Slow^.Next; Fast:=Fast^.Next^.Next; End;
 B:=Slow^.Next; Slow^.Next:=Nil;
 SortPolyList:=MergePoly(SortPolyList(L),SortPolyList(B));
End;

Procedure SortScene;
Begin
 PolyHead:=SortPolyList(PolyHead);
 PolyTail:=PolyHead;
 While(PolyTail<>Nil)And(PolyTail^.Next<>Nil)Do PolyTail:=PolyTail^.Next;
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
 LastCol:=-1; K:=0;
 Pl:=PolyHead;
 While Pl<>Nil Do Begin
  Inc(K);
  If K And 255=0 Then LatchMouse;
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
  Pl:=Pl^.Next;
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
  If Q^.Sel And PieceVisible(Q)Then Begin
   If Q^.Locked Then DrawPieceBox(Q,9) Else DrawPieceBox(Q,12);
  End;
  Q:=Q^.Next;
 End;
End;

Procedure DrawEditGizmo(Var V:TView); Forward;

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
 If Active And(Tool=TL_SELECT)Then DrawEditGizmo(V);
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
Var Pl:PPoly; R:Integer;
Begin
 PickPiece:=0;
 SetupCamera(V);
 BuildScene(False);
 SortScene;
 R:=0;
 { ordre de peintre : le dernier polygone touche est le plus proche }
 Pl:=PolyHead;
 While Pl<>Nil Do Begin
  If(Pl^.N>=3)And(Pl^.Owner>0)Then
   If PolyHit(Pl,PX,PY)Then R:=Pl^.Owner;
  Pl:=Pl^.Next;
 End;
 PickPiece:=R;
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
 V.Dist:=R/Sin(V.Fov*Pi/360)*1.08;
 If W<H Then V.Dist:=V.Dist*H/W;
 If Min(W,H)>0 Then V.Zoom:=(Min(W,H)/2)/R*0.92 Else V.Zoom:=1;
End;

Procedure InitViews;
Var I:Integer;
Begin
 For I:=0 To MAXVIEW-1 Do Begin
  Views[I].Dist:=800; Views[I].Zoom:=1; Views[I].Fov:=30; VSet(Views[I].Tgt,0,-40,0);
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
 If V.Persp Then S:=2*V.Dist*Sin(V.Fov*Pi/360)/Cos(V.Fov*Pi/360)/H Else S:=1/V.Zoom;
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
{ Raccourcis clavier (liste chainee) et menus                           }
{ ====================================================================== }

Procedure BindClear;
Var B,N:PBind;
Begin
 B:=BindHead;
 While B<>Nil Do Begin N:=B^.Next; Dispose(B); B:=N; End;
 BindHead:=Nil;
End;

Procedure BindAdd(Key,Cmd:Integer);
Var B,T:PBind;
Begin
 New(B); B^.Key:=Key; B^.Cmd:=Cmd; B^.Next:=Nil;
 If BindHead=Nil Then BindHead:=B
 Else Begin T:=BindHead; While T^.Next<>Nil Do T:=T^.Next; T^.Next:=B; End;
End;

Function BindCmd(Key:Integer):Integer;
Var B:PBind;
Begin
 B:=BindHead;
 While B<>Nil Do Begin
  If B^.Key=Key Then Begin BindCmd:=B^.Cmd; Exit; End;
  B:=B^.Next;
 End;
 BindCmd:=0;
End;

Function BindKeyOf(Cmd:Integer):Integer;
Var B:PBind;
Begin
 B:=BindHead;
 While B<>Nil Do Begin
  If B^.Cmd=Cmd Then Begin BindKeyOf:=B^.Key; Exit; End;
  B:=B^.Next;
 End;
 BindKeyOf:=-1;
End;

{ Remplace (ou ajoute) la touche d'une commande ; la touche est retiree d'une autre commande }
Procedure BindSet(Key,Cmd:Integer);
Var B:PBind;
Begin
 B:=BindHead;
 While B<>Nil Do Begin
  If B^.Key=Key Then B^.Cmd:=0;
  B:=B^.Next;
 End;
 B:=BindHead;
 While B<>Nil Do Begin
  If B^.Cmd=Cmd Then Begin B^.Key:=Key; Exit; End;
  B:=B^.Next;
 End;
 BindAdd(Key,Cmd);
End;

Function KeyName(Key:Integer):String;
Begin
 If Key<0 Then Begin KeyName:=''; Exit; End;
 If Key>=256 Then Begin
  Case Key-256 Of
   59..68:KeyName:='F'+IntStr(Key-256-58);
   71:KeyName:='Debut'; 72:KeyName:='Haut'; 73:KeyName:='PgHaut'; 75:KeyName:='Gauche';
   77:KeyName:='Droite'; 79:KeyName:='Fin'; 80:KeyName:='Bas'; 81:KeyName:='PgBas';
   82:KeyName:='Inser'; 83:KeyName:='Suppr'; 146:KeyName:='Ctrl+Ins';
   33:KeyName:='Alt+F'; 18:KeyName:='Alt+E'; 30:KeyName:='Alt+A'; 25:KeyName:='Alt+P';
   20:KeyName:='Alt+T'; 31:KeyName:='Alt+S'; 35:KeyName:='Alt+H';
  Else KeyName:='#'+IntStr(Key-256);
  End;
  Exit;
 End;
 Case Key Of
  1..26:If Key=9 Then KeyName:='Tab' Else If Key=13 Then KeyName:='Entree' Else KeyName:='Ctrl+'+Chr(Key+64);
  27:KeyName:='Echap';
  Else KeyName:=Chr(Key);
 End;
End;

Procedure InitKeys;
Begin
 BindClear;
 BindAdd(14,CM_NEW); BindAdd(15,CM_OPEN); BindAdd(19,CM_SAVE); BindAdd(256+68,CM_QUIT);
 BindAdd(3,CM_QUIT); BindAdd(256+107,CM_QUIT);
 BindAdd(26,CM_UNDO); BindAdd(25,CM_REDO); BindAdd(24,CM_CUT); BindAdd(256+146,CM_COPY);
 BindAdd(22,CM_PASTE); BindAdd(256+83,CM_DELETE); BindAdd(1,CM_SELALL); BindAdd(4,CM_SELNONE);
 BindAdd(Ord('a'),CM_ADDMODE);
 BindAdd(Ord('v'),CM_VIEWS); BindAdd(Ord('p'),CM_PERSP);
 BindAdd(Ord('0'),CM_V_HOME); BindAdd(Ord('1'),CM_V_FRONT); BindAdd(Ord('2'),CM_V_BACK);
 BindAdd(Ord('3'),CM_V_LEFT); BindAdd(Ord('4'),CM_V_RIGHT); BindAdd(Ord('5'),CM_V_TOP);
 BindAdd(Ord('6'),CM_V_BOTTOM); BindAdd(Ord('+'),CM_ZOOMIN); BindAdd(Ord('-'),CM_ZOOMOUT);
 BindAdd(Ord('f'),CM_FIT); BindAdd(Ord('g'),CM_GRID); BindAdd(Ord('e'),CM_EDGES);
 BindAdd(Ord('w'),CM_WIRE); BindAdd(Ord('t'),CM_STUDS);
 BindAdd(256+60,CM_PN_PARTS); BindAdd(256+61,CM_PN_PROPS); BindAdd(256+62,CM_PN_TIME);
 BindAdd(9,CM_NEXTVIEW);
 BindAdd(256+82,CM_INSERT); BindAdd(2,CM_DUP); BindAdd(Ord('b'),CM_DUP);
 BindAdd(256+73,CM_UP8); BindAdd(256+81,CM_DN8); BindAdd(256+71,CM_UP24); BindAdd(256+79,CM_DN24);
 BindAdd(Ord('x'),CM_RXP); BindAdd(Ord('X'),CM_RXM); BindAdd(Ord('y'),CM_RYP);
 BindAdd(Ord('Y'),CM_RYM); BindAdd(Ord('z'),CM_RZP); BindAdd(Ord('Z'),CM_RZM);
 BindAdd(Ord('h'),CM_HIDE); BindAdd(7,CM_GROUP); BindAdd(21,CM_UNGROUP);
 BindAdd(12,CM_LOCK); BindAdd(11,CM_UNLOCK); BindAdd(27,CM_SELTOOL);
 BindAdd(Ord('.'),CM_STEP_NEXT); BindAdd(Ord(','),CM_STEP_PREV); BindAdd(Ord('['),CM_STEP_FIRST);
 BindAdd(Ord(']'),CM_STEP_LAST); BindAdd(Ord('m'),CM_SUB_MAIN);
 BindAdd(Ord('k'),CM_KEY_ADD); BindAdd(Ord('l'),CM_KEY_PLAY);
 BindAdd(256+59,CM_HELP); BindAdd(256+63,CM_PN_PARTS);
End;

Procedure MC(M,I,Cmd:Integer;Const Cap:String);
Begin
 Menus[M].Items[I].Caption:=Fx(Cap);
 Menus[M].Items[I].Cmd:=Cmd;
 Menus[M].Items[I].Shortcut:='';
 Menus[M].Items[I].Enabled:=True;
 Menus[M].Items[I].Checked:=False;
 Menus[M].Items[I].Separator:=(Cap='-');
 If I>=Menus[M].ItemCount Then Menus[M].ItemCount:=I+1;
End;

Procedure UpdateShortcuts;
Var M,I,K:Integer;
Begin
 For M:=0 To MENU_COUNT-1 Do
  For I:=0 To Menus[M].ItemCount-1 Do
   If Menus[M].Items[I].Cmd<>0 Then Begin
    K:=BindKeyOf(Menus[M].Items[I].Cmd);
    Menus[M].Items[I].Shortcut:=Copy(KeyName(K),1,12);
   End;
End;

Procedure InitMenus;
Var I,J:Integer;
Begin
 For I:=0 To MENU_COUNT-1 Do Begin
  Menus[I].ItemCount:=0;
  For J:=0 To 23 Do Begin
   Menus[I].Items[J].Caption:=''; Menus[I].Items[J].Shortcut:=''; Menus[I].Items[J].Cmd:=0;
   Menus[I].Items[J].Enabled:=True; Menus[I].Items[J].Checked:=False;
   Menus[I].Items[J].Separator:=False;
  End;
 End;
 Menus[M_FILE].Title:='Fichier';
 MC(M_FILE,0,CM_NEW,'Nouveau');
 MC(M_FILE,1,CM_OPEN,'Ouvrir...');
 MC(M_FILE,2,CM_SAVE,'Enregistrer');
 MC(M_FILE,3,CM_SAVEAS,'Enregistrer sous...');
 MC(M_FILE,4,0,'-');
 MC(M_FILE,5,CM_EXP_IMG,'Exporter l''image...');
 MC(M_FILE,6,CM_EXP_HTML,'Exporter instructions HTML...');
 MC(M_FILE,7,CM_EXP_POV,'Exporter POV-Ray...');
 MC(M_FILE,8,CM_EXP_OBJ,'Exporter Wavefront OBJ...');
 MC(M_FILE,9,CM_EXP_3DS,'Exporter 3D Studio...');
 MC(M_FILE,10,CM_EXP_BL,'Exporter BrickLink XML...');
 MC(M_FILE,11,CM_EXP_LIST,'Exporter liste des pi\eces...');
 MC(M_FILE,12,CM_IMP_BL,'Importer BrickLink XML...');
 MC(M_FILE,13,0,'-');
 MC(M_FILE,14,CM_PARTSUSED,'Pi\eces utilis\ees...');
 MC(M_FILE,15,CM_INFO,'Informations du mod\gle...');
 MC(M_FILE,16,CM_PREFS,'Pr\ef\erences...');
 MC(M_FILE,17,CM_REINDEX,'R\eindexer la biblioth\gque');
 MC(M_FILE,18,0,'-');
 MC(M_FILE,19,CM_DOCS,'Documents ouverts...');
 MC(M_FILE,20,CM_QUIT,'Quitter');

 Menus[M_EDIT].Title:=Fx('\Edition');
 MC(M_EDIT,0,CM_UNDO,'Annuler');
 MC(M_EDIT,1,CM_REDO,'R\etablir');
 MC(M_EDIT,2,0,'-');
 MC(M_EDIT,3,CM_CUT,'Couper');
 MC(M_EDIT,4,CM_COPY,'Copier');
 MC(M_EDIT,5,CM_PASTE,'Coller');
 MC(M_EDIT,6,CM_DELETE,'Supprimer');
 MC(M_EDIT,7,0,'-');
 MC(M_EDIT,8,CM_SELALL,'Tout s\electionner');
 MC(M_EDIT,9,CM_SELNONE,'Aucune s\election');
 MC(M_EDIT,10,CM_SELINV,'Inverser la s\election');
 MC(M_EDIT,11,CM_SELCOL,'M\eme couleur');
 MC(M_EDIT,12,CM_SELPART,'M\eme pi\ece');
 MC(M_EDIT,13,CM_ADDMODE,'Mode ajout \a la s\election');

 Menus[M_VIEW].Title:='Affichage';
 MC(M_VIEW,0,CM_VIEWS,'Une vue / quatre vues');
 MC(M_VIEW,1,CM_PERSP,'Perspective / ortho');
 MC(M_VIEW,2,0,'-');
 MC(M_VIEW,3,CM_V_HOME,'Vue 3D');
 MC(M_VIEW,4,CM_V_FRONT,'Avant');
 MC(M_VIEW,5,CM_V_BACK,'Arri\ere');
 MC(M_VIEW,6,CM_V_LEFT,'Gauche');
 MC(M_VIEW,7,CM_V_RIGHT,'Droite');
 MC(M_VIEW,8,CM_V_TOP,'Dessus');
 MC(M_VIEW,9,CM_V_BOTTOM,'Dessous');
 MC(M_VIEW,10,0,'-');
 MC(M_VIEW,11,CM_ZOOMIN,'Zoom avant');
 MC(M_VIEW,12,CM_ZOOMOUT,'Zoom arri\ere');
 MC(M_VIEW,13,CM_FIT,'Ajuster \a la fen\hetre');
 MC(M_VIEW,14,0,'-');
 MC(M_VIEW,15,CM_GRID,'Grille');
 MC(M_VIEW,16,CM_EDGES,'Ar\etes');
 MC(M_VIEW,17,CM_WIRE,'Mode filaire');
 MC(M_VIEW,18,CM_STUDS,'D\etail des tenons');
 MC(M_VIEW,19,0,'-');
 MC(M_VIEW,20,CM_PN_PARTS,'Panneau Pi\eces');
 MC(M_VIEW,21,CM_PN_PROPS,'Panneau Propri\et\es');
 MC(M_VIEW,22,CM_PN_TIME,'Panneau Chronologie');

 Menus[M_PIECE].Title:=Fx('Pi\ece');
 MC(M_PIECE,0,CM_INSERT,'Ins\erer la pi\ece choisie');
 MC(M_PIECE,1,CM_DUP,'Dupliquer');
 MC(M_PIECE,2,0,'-');
 MC(M_PIECE,3,CM_UP8,'Monter d''une plaque');
 MC(M_PIECE,4,CM_DN8,'Descendre d''une plaque');
 MC(M_PIECE,5,CM_UP24,'Monter d''une brique');
 MC(M_PIECE,6,CM_DN24,'Descendre d''une brique');
 MC(M_PIECE,7,0,'-');
 MC(M_PIECE,8,CM_RXP,'Pivoter X +90');
 MC(M_PIECE,9,CM_RXM,'Pivoter X -90');
 MC(M_PIECE,10,CM_RYP,'Pivoter Y +90');
 MC(M_PIECE,11,CM_RYM,'Pivoter Y -90');
 MC(M_PIECE,12,CM_RZP,'Pivoter Z +90');
 MC(M_PIECE,13,CM_RZM,'Pivoter Z -90');
 MC(M_PIECE,14,0,'-');
 MC(M_PIECE,15,CM_APPLYCOL,'Appliquer la couleur courante');
 MC(M_PIECE,16,CM_HIDE,'Masquer la s\election');
 MC(M_PIECE,17,CM_SHOWALL,'Tout afficher');
 MC(M_PIECE,18,0,'-');
 MC(M_PIECE,19,CM_GROUP,'Grouper');
 MC(M_PIECE,20,CM_UNGROUP,'Dissocier');
 MC(M_PIECE,21,CM_LOCK,'Verrouiller');
 MC(M_PIECE,22,CM_UNLOCK,'D\everrouiller');

 Menus[M_XFORM].Title:='Transf.';
 MC(M_XFORM,0,CM_AL_L,'Aligner \a gauche');
 MC(M_XFORM,1,CM_AL_R,'Aligner \a droite');
 MC(M_XFORM,2,CM_AL_F,'Aligner devant');
 MC(M_XFORM,3,CM_AL_B,'Aligner derri\ere');
 MC(M_XFORM,4,CM_AL_T,'Aligner en haut');
 MC(M_XFORM,5,CM_AL_D,'Aligner en bas');
 MC(M_XFORM,6,CM_CEN_X,'Centrer en X');
 MC(M_XFORM,7,CM_CEN_Z,'Centrer en Z');
 MC(M_XFORM,8,0,'-');
 MC(M_XFORM,9,CM_DIST_X,'R\epartir en X');
 MC(M_XFORM,10,CM_DIST_Y,'R\epartir en Y');
 MC(M_XFORM,11,CM_DIST_Z,'R\epartir en Z');
 MC(M_XFORM,12,0,'-');
 MC(M_XFORM,13,CM_MIR_X,'Miroir X');
 MC(M_XFORM,14,CM_MIR_Y,'Miroir Y');
 MC(M_XFORM,15,CM_MIR_Z,'Miroir Z');
 MC(M_XFORM,16,0,'-');
 MC(M_XFORM,17,CM_ARRAY,'Tableau (copies)...');
 MC(M_XFORM,18,CM_NUMXF,'Transformation num\erique...');
 MC(M_XFORM,19,CM_PIVOT,'Pivot : centre / pi\ece / origine');

 Menus[M_STEP].Title:=Fx('\Etapes');
 MC(M_STEP,0,CM_STEP_NEXT,'\Etape suivante');
 MC(M_STEP,1,CM_STEP_PREV,'\Etape pr\ec\edente');
 MC(M_STEP,2,CM_STEP_FIRST,'Premi\ere \etape');
 MC(M_STEP,3,CM_STEP_LAST,'Derni\ere \etape');
 MC(M_STEP,4,0,'-');
 MC(M_STEP,5,CM_STEP_INS,'Ins\erer une \etape');
 MC(M_STEP,6,CM_STEP_DEL,'Supprimer l''\etape');
 MC(M_STEP,7,CM_STEP_SEL,'S\election vers \etape courante');

 Menus[M_SUB].Title:='Sous-mod.';
 MC(M_SUB,0,CM_SUB_NEW,'Nouveau sous-mod\gle...');
 MC(M_SUB,1,CM_SUB_FROMSEL,'Cr\eer depuis la s\election...');
 MC(M_SUB,2,CM_SUB_INS,'Ins\erer un sous-mod\gle...');
 MC(M_SUB,3,0,'-');
 MC(M_SUB,4,CM_SUB_EDIT,'Modifier un sous-mod\gle...');
 MC(M_SUB,5,CM_SUB_MAIN,'Mod\gle principal');
 MC(M_SUB,6,CM_SUB_DEL,'Supprimer le sous-mod\gle');

 Menus[M_CAM].Title:=Fx('Cam\era');
 MC(M_CAM,0,CM_CAM_NEW,'Enregistrer la vue comme cam\era...');
 MC(M_CAM,1,CM_CAM_GO,'Aller \a une cam\era...');
 MC(M_CAM,2,CM_CAM_DEL,'Supprimer une cam\era...');
 MC(M_CAM,3,CM_FOV,'Champ de vision...');
 MC(M_CAM,4,0,'-');
 MC(M_CAM,5,CM_KEY_ADD,'Ajouter une image cl\e');
 MC(M_CAM,6,CM_KEY_DEL,'Supprimer les images cl\es');
 MC(M_CAM,7,CM_KEY_PLAY,'Lire l''animation');
 MC(M_CAM,8,CM_STEPS_PLAY,'Lire les \etapes');
 MC(M_CAM,9,CM_ANIM_EXP,'Exporter l''animation...');

 Menus[M_HELP].Title:='Aide';
 MC(M_HELP,0,CM_HELP,'Raccourcis clavier');
 MC(M_HELP,1,CM_KEYS,'Personnaliser les raccourcis...');
 MC(M_HELP,2,CM_ABOUT,'A propos de LEOCAD');
 For I:=0 To MENU_COUNT-1 Do Menus[I].Width:=220;
 Menus[M_FILE].Width:=252;
 Menus[M_VIEW].Width:=236;
 Menus[M_PIECE].Width:=252;
 Menus[M_XFORM].Width:=268;
 Menus[M_STEP].Width:=244;
 Menus[M_SUB].Width:=252;
 Menus[M_CAM].Width:=292;
 Menus[M_HELP].Width:=268;
 UpdateShortcuts;
End;

Procedure UpdateMenuChecks;
Var M,I:Integer;
 Procedure Chk(Cmd:Integer;V:Boolean);
 Var K,J:Integer;
 Begin
  For K:=0 To MENU_COUNT-1 Do
   For J:=0 To Menus[K].ItemCount-1 Do
    If Menus[K].Items[J].Cmd=Cmd Then Menus[K].Items[J].Checked:=V;
 End;
 Procedure Ena(Cmd:Integer;V:Boolean);
 Var K,J:Integer;
 Begin
  For K:=0 To MENU_COUNT-1 Do
   For J:=0 To Menus[K].ItemCount-1 Do
    If Menus[K].Items[J].Cmd=Cmd Then Menus[K].Items[J].Enabled:=V;
 End;
Begin
 Chk(CM_VIEWS,ViewCount=4);
 Chk(CM_PERSP,Views[ActiveView].Persp);
 Chk(CM_GRID,GridOn); Chk(CM_EDGES,EdgesOn); Chk(CM_WIRE,WireOn); Chk(CM_STUDS,StudMode<>0);
 Chk(CM_PN_PARTS,PanelSel=PN_PARTS); Chk(CM_PN_PROPS,PanelSel=PN_PROPS); Chk(CM_PN_TIME,PanelSel=PN_TIME);
 Chk(CM_ADDMODE,AddMode);
 Ena(CM_UNDO,UndoN>0); Ena(CM_REDO,RedoN>0); Ena(CM_PASTE,ClipN>0);
 Ena(CM_SUB_MAIN,CurModel<>0); Ena(CM_SUB_DEL,CurModel<>0);
 Ena(CM_SUB_EDIT,ModelCount>1); Ena(CM_SUB_INS,ModelCount>1);
 Ena(CM_CAM_GO,CamHead<>Nil); Ena(CM_CAM_DEL,CamHead<>Nil);
 Ena(CM_KEY_PLAY,KeyHead<>Nil); Ena(CM_KEY_DEL,KeyHead<>Nil);
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

Procedure DrawThumb(X1,Y1,X2,Y2:Integer;Const Nm:String;Code:LongInt);
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
  V.Persp:=True; V.Fov:=30; V.Yaw:=145; V.Pitch:=30; V.X1:=X1; V.Y1:=Y1; V.X2:=X2; V.Y2:=Y2;
  VSet(V.Tgt,(Mn.X+Mx.X)/2,(Mn.Y+Mx.Y)/2,(Mn.Z+Mx.Z)/2);
  R:=Sqrt(Sqr(Mx.X-Mn.X)+Sqr(Mx.Y-Mn.Y)+Sqr(Mx.Z-Mn.Z))/2;
  If R<12 Then R:=12;
  V.Dist:=R/0.2588*1.1; V.Zoom:=1;
  SetViewPort(X1,Y1,X2,Y2,True);
  SetupCamera(V);
  PolyReset; PolyMax:=3000; PolyOverflow:=False;
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
Var I,Y,K,X0,X1:Integer; S:String; C:PCat; F:PFil;
Begin
 X0:=DockX+3; X1:=ScreenW-4;
 { categories }
 Sunken(X0,CatY,X1-12,CatY+CAT_ROWS*12+1,15);
 For I:=0 To CAT_ROWS-1 Do Begin
  K:=CatTop+I;
  If K<CatN Then Begin
   Y:=CatY+1+I*12;
   S:=Copy(CatNameAt(K),1,21);
   If K=CatSel Then Begin Box(X0+1,Y,X1-13,Y+11,UI_SEL); TxtOut(X0+4,Y+2,S,15); End
   Else TxtOut(X0+4,Y+2,S,UI_DK);
  End;
 End;
 DrawVScroll(X1-11,CatY,CAT_ROWS*12+2,CatTop,CatN,CAT_ROWS);
 { recherche }
 TxtOut(X0+1,SearchY+3,'Rech.',UI_DK);
 Sunken(X0+44,SearchY,X1,SearchY+13,15);
 S:=SearchStr;
 If SearchEdit Then S:=S+'_';
 TxtOut(X0+48,SearchY+3,Copy(S,1,18),UI_DK);
 { liste des pieces : parcours de la liste chainee }
 Sunken(X0,ListY,X1-12,ListY+PART_ROWS*12+1,15);
 F:=FilHead;
 K:=PartTop;
 While(F<>Nil)And(K>0)Do Begin F:=F^.Next; Dec(K); End;
 For I:=0 To PART_ROWS-1 Do Begin
  If F<>Nil Then Begin
   K:=PartTop+I;
   Y:=ListY+1+I*12;
   S:=Copy(Compact(F^.C^.Desc),1,21);
   If K=PartSel Then Begin Box(X0+1,Y,X1-13,Y+11,UI_SEL); TxtOut(X0+4,Y+2,S,15); End
   Else TxtOut(X0+4,Y+2,S,UI_DK);
   F:=F^.Next;
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
  7:PropValue:=ColNameOf(Q^.Col);
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
   If Q<>Nil Then Box(DockX+79,Y+2,DockX+87,Y+10,UICode(UI_SLOTS-1,Q^.Col));
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
Var I,Y,K,N,X0,X1,C:Integer; Hdr:Boolean; S:Integer; Q:PPiece; T:String; Trn:Boolean;
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
     C:=GrpIdx[ColGroup(Q^.Col,Trn),4];
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
{ Palette de couleurs (liste chainee, defilement)                        }
{ ====================================================================== }

Const COL_COLS=10; COL_ROWS=4;

Procedure ColCell(K:Integer;Var X,Y:Integer);
Begin
 X:=DockX+4+(K Mod COL_COLS)*17;
 Y:=ColY+18+(K Div COL_COLS)*16;
End;

Function ColRowsTotal:Integer;
Begin
 ColRowsTotal:=(NCol+COL_COLS-1) Div COL_COLS;
End;

Function ColHit(PX,PY:Integer):Integer;
Var K,X,Y:Integer;
Begin
 ColHit:=-1;
 For K:=0 To COL_COLS*COL_ROWS-1 Do Begin
  ColCell(K,X,Y);
  If InRect(PX,PY,X,Y,16,15)Then Begin
   If(ColTop*COL_COLS+K)<NCol Then ColHit:=ColTop*COL_COLS+K;
   Exit;
  End;
 End;
End;

Procedure DrawColors;
Var K,X,Y,C:Integer; P:PColor; R,G,B,Fin:Byte; Tr:Boolean;
Begin
 Raised(DockX,ColY,ScreenW-1,ColY2);
 If CurColor=16 Then Begin R:=170; G:=170; B:=170; End Else ColInfo(CurColor,R,G,B,Tr,Fin);
 TxtF(DockX+6,ColY+4,'Couleur :',UI_DK);
 Box(DockX+80,ColY+2,DockX+92,ColY+12,UIColor(UI_SLOTS-2,R,G,B));
 SetColor(UI_DK); Rectangle(DockX+80,ColY+2,DockX+92,ColY+12);
 TxtOut(DockX+96,ColY+4,Copy(ColNameOf(CurColor),1,12),UI_DK);
 P:=ColByIndex(ColTop*COL_COLS);
 For K:=0 To COL_COLS*COL_ROWS-1 Do Begin
  If P=Nil Then Begin
   ColCell(K,X,Y);
   Box(X,Y,X+15,Y+14,UI_BG);
  End
   Else Begin
    ColCell(K,X,Y);
    Box(X,Y,X+15,Y+14,UIColor(K,P^.R,P^.G,P^.B));
    If P^.Alpha<255 Then Begin
     SetColor(15);
     Line(X+2,Y+2,X+13,Y+13); Line(X+13,Y+2,X+2,Y+13);
    End;
    If P^.Code=CurColor Then Begin
     SetColor(UI_DK); Rectangle(X-1,Y-1,X+16,Y+15);
     SetColor(15); Rectangle(X,Y,X+15,Y+14);
    End
     Else Begin
      SetColor(UI_SH); Rectangle(X,Y,X+15,Y+14);
     End;
    P:=P^.Next;
   End;
 End;
 DrawVScroll(ScreenW-15,ColY+16,COL_ROWS*16+4,ColTop,ColRowsTotal,COL_ROWS);
 TxtOut(DockX+6,ColY+18+COL_ROWS*16+6,IntStr(NCol)+Fx(' couleurs'),UI_SH);
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
 ClearLatch;
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
 PEntry=^TEntry;
 TEntry=Record
  Name:String[40];
  IsDir:Boolean;
  Next:PEntry;
 End;

Var
 FHead:PEntry;
 FN:Integer;

Procedure FreeEntries;
Var E,N:PEntry;
Begin
 E:=FHead;
 While E<>Nil Do Begin N:=E^.Next; Dispose(E); E:=N; End;
 FHead:=Nil; FN:=0;
End;

Function EntryAt(I:Integer):PEntry;
Var E:PEntry;
Begin
 E:=FHead;
 While(E<>Nil)And(I>0)Do Begin E:=E^.Next; Dec(I); End;
 EntryAt:=E;
End;

{ Insertion triee : dossiers d'abord, puis par nom }
Procedure AddEntry(Const Nm:String;IsDir:Boolean);
Var E,P:PEntry;
 Function Before(A:PEntry):Boolean;
 Begin
  If A^.IsDir<>IsDir Then Before:=IsDir
  Else Before:=UpStr(Nm)<UpStr(A^.Name);
 End;
Begin
 New(E); E^.Name:=Copy(Nm,1,40); E^.IsDir:=IsDir; E^.Next:=Nil;
 If(FHead=Nil)Or Before(FHead)Then Begin E^.Next:=FHead; FHead:=E; End
 Else Begin
  P:=FHead;
  While(P^.Next<>Nil)And(Not Before(P^.Next))Do P:=P^.Next;
  E^.Next:=P^.Next; P^.Next:=E;
 End;
 Inc(FN);
End;

Procedure ScanDir(Flt:Integer;Mode:Integer);
Var SR:SearchRec; E:String; Ok:Boolean;
Begin
 FreeEntries;
 {$IFDEF FPC}FindFirst('*',AnyFile,SR);{$ELSE}FindFirst('*.*',AnyFile,SR);{$ENDIF}
 While DosError=0 Do Begin
  If(SR.Attr And Directory)<>0 Then Begin
   If SR.Name<>'.' Then AddEntry(SR.Name,True);
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
      Else If Mode=2 Then Ok:=(E='.BMP')Or(E='.PNG')Or(E='.GIF')
      Else Ok:=True;
    If Ok Then AddEntry(SR.Name,False);
   End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
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
    If EntryAt(R)^.IsDir Then OutTextXY(X+14,Y+39+J*12,'['+EntryAt(R)^.Name+']')
    Else OutTextXY(X+14,Y+39+J*12,EntryAt(R)^.Name);
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
   If(Sel>=0)And(Sel<FN)Then Fld:=EntryAt(Sel)^.Name Else Exit;
  End;
  If(Sel>=0)And(Sel<FN)And EntryAt(Sel)^.IsDir And(Fld=EntryAt(Sel)^.Name)Then Begin
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
  If EntryAt(N)^.IsDir Then Begin
   GoDir(EntryAt(N)^.Name); Fld:=''; Msg:=''; Rescan;
  End
   Else Begin Fld:=EntryAt(N)^.Name; Accept; End;
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
     Else Begin Sel:=I; Fld:=''; If Not EntryAt(I)^.IsDir Then Fld:=EntryAt(I)^.Name; End;
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

{ Position relative (rotation seule) du premier tenon d'une piece ; False si aucun }
Function FirstStud(Const Nm:String;Const R:TMat;Var GX,GZ:Real):Boolean;
Var P:PPart; Q:PPrim; V,O:TVec; Z:TMat;
Begin
 FirstStud:=False;
 If FindModel(Nm)>=0 Then Exit;
 P:=GetPart(Nm,0);
 If P=Nil Then Exit;
 FlattenPart(P);
 Q:=P^.Flat;
 While(Q<>Nil)And(Q^.Kind<>PK_STUD)Do Q:=Q^.Next;
 If Q=Nil Then Exit;
 Z:=R; Z.T.X:=0; Z.T.Y:=0; Z.T.Z:=0;
 V:=Q^.M.T;
 MatApply(Z,V,O);
 GX:=O.X; GZ:=O.Z;
 FirstStud:=True;
End;

{ Calcule la position d'insertion (InsX,InsY,InsZ) pour le point monde (X,Z).
  Ref = piece sous le curseur : le tenon de la piece posee s'aligne sur son reseau. }
Procedure ComputeInsert(WX,WZ:Real;Ref:PPiece);
Var
 SX,SZ:Integer; MinY,MaxY,HX,HZ,Top,CX,CZ,GX,GZ,RX,RZ:Real;
 Q:PPiece; Mn,Mx:TVec; Q2:PPiece;
Begin
 BodyInfo(CurPart,InsM,SX,SZ,MinY,MaxY,HX,HZ);
 InsX:=SnapAxis(WX,SX); InsZ:=SnapAxis(WZ,SZ);
 If(Ref<>Nil)And(PieceSub(Ref)<0)And FirstStud(CurPart,InsM,GX,GZ)And FirstStud(Ref^.Name,Ref^.M,RX,RZ)Then Begin
  RX:=RX+Ref^.M.T.X; RZ:=RZ+Ref^.M.T.Z;
  InsX:=RX-GX+20*Round((WX-(RX-GX))/20);
  InsZ:=RZ-GZ+20*Round((WZ-(RZ-GZ))/20);
 End;
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
  If Q^.Sel And(Not Q^.Locked)Then Begin
   Q^.M.T.X:=Q^.M.T.X+DX; Q^.M.T.Y:=Q^.M.T.Y+DY; Q^.M.T.Z:=Q^.M.T.Z+DZ;
  End;
  Q:=Q^.Next;
 End;
End;

Procedure RotateSelCore(Axis:Integer;Deg:Real);
Var Q:PPiece; Rt:TMat; P:TVec; N:Integer; Cx,Cy,Cz:Real; T:TVec;
Begin
 N:=SelCount;
 If N=0 Then Exit;
 Cx:=0; Cy:=0; Cz:=0;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Begin Cx:=Cx+Q^.M.T.X; Cy:=Cy+Q^.M.T.Y; Cz:=Cz+Q^.M.T.Z; End;
  Q:=Q^.Next;
 End;
 If Abs(Deg-Round(Deg/90)*90)<0.01 Then VSet(P,Round(Cx/N/10)*10,Round(Cy/N/4)*4,Round(Cz/N/10)*10)
 Else VSet(P,Cx/N,Cy/N,Cz/N);
 If N=1 Then Begin Q:=FirstSel; P:=Q^.M.T; End;
 If PivotMode=2 Then VSet(P,0,0,0);
 MatRotAxis(Axis,Deg,Rt);
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel And(Not Q^.Locked)Then Begin
   If PivotMode=1 Then P:=Q^.M.T;
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
End;

Procedure RotateSel(Axis:Integer;Deg:Real);
Var Rt:TMat;
Begin
 If Tool=TL_INSERT Then Begin
  MatRotAxis(Axis,Deg,Rt);
  MatMul(Rt,InsM,InsM); SnapRot(InsM);
  InsM.T.X:=0; InsM.T.Y:=0; InsM.T.Z:=0;
  Touch;
  Exit;
 End;
 If SelCount=0 Then Exit;
 PushUndo;
 RotateSelCore(Axis,Deg);
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
  If Q^.Sel And(Not Q^.Locked)Then RemovePiece(CurModel,Q);
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

Procedure ApplyColorSel(Code:LongInt);
Var Q:PPiece;
Begin
 If SelCount=0 Then Exit;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel And(PieceSub(Q)<0)Then Q^.Col:=Code;
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


{ ====================================================================== }
{ Groupes, verrouillage, alignement, miroir, tableau, pivot             }
{ ====================================================================== }

Procedure GroupSel;
Var Q:PPiece; Id:LongInt; N:Integer;
Begin
 N:=SelCount;
 If N<2 Then Begin SetMsg('S\electionner au moins deux pi\eces.'); Exit; End;
 PushUndo;
 Id:=NewGroupId('Groupe '+IntStr(NextGroupId));
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin If Q^.Sel Then Q^.Group:=Id; Q:=Q^.Next; End;
 SetMsg(Fx('Groupe cr\e\e'));
 Touch;
End;

Procedure UngroupSel;
Var Q:PPiece;
Begin
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin If Q^.Sel Then Q^.Group:=0; Q:=Q^.Next; End;
 Touch;
End;

Procedure LockSel(V:Boolean);
Var Q:PPiece;
Begin
 If SelCount=0 Then Exit;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin If Q^.Sel Then Q^.Locked:=V; Q:=Q^.Next; End;
 Touch;
End;

{ Selectionne toutes les pieces du groupe de Q }
Procedure SelectGroupOf(Q:PPiece;V:Boolean);
Var P:PPiece;
Begin
 Q^.Sel:=V;
 If Q^.Group=0 Then Exit;
 P:=Models[CurModel].First;
 While P<>Nil Do Begin
  If P^.Group=Q^.Group Then P^.Sel:=V;
  P:=P^.Next;
 End;
End;

{ Boite englobante des pieces selectionnees }
Function SelBounds(Var Mn,Mx:TVec):Boolean;
Var Q:PPiece; A,B:TVec;
Begin
 BoxEmpty(Mn,Mx);
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Begin
   PieceBounds(Q,False,A,B);
   BoxAdd(Mn,Mx,A); BoxAdd(Mn,Mx,B);
  End;
  Q:=Q^.Next;
 End;
 SelBounds:=Not BoxIsEmpty(Mn,Mx);
End;

{ Kind : 0 gauche (X min) 1 droite 2 devant (Z min) 3 derriere 4 haut (Y min) 5 bas 6 centre X 7 centre Z }
Procedure AlignSel(Kind:Integer);
Var Q:PPiece; SA,SB,A,B:TVec; D:Real; N:Integer;
Begin
 If SelCount<2 Then Exit;
 If Not SelBounds(SA,SB)Then Exit;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel And(Not Q^.Locked)Then Begin
   PieceBounds(Q,False,A,B);
   Case Kind Of
    0:Q^.M.T.X:=Q^.M.T.X+SA.X-A.X;
    1:Q^.M.T.X:=Q^.M.T.X+SB.X-B.X;
    2:Q^.M.T.Z:=Q^.M.T.Z+SA.Z-A.Z;
    3:Q^.M.T.Z:=Q^.M.T.Z+SB.Z-B.Z;
    4:Q^.M.T.Y:=Q^.M.T.Y+SA.Y-A.Y;
    5:Q^.M.T.Y:=Q^.M.T.Y+SB.Y-B.Y;
    6:Q^.M.T.X:=Q^.M.T.X+(SA.X+SB.X)/2-(A.X+B.X)/2;
    7:Q^.M.T.Z:=Q^.M.T.Z+(SA.Z+SB.Z)/2-(A.Z+B.Z)/2;
   End;
  End;
  Q:=Q^.Next;
 End;
 Touch;
End;

Type
 PSNode=^TSNode;
 TSNode=Record Q:PPiece; K:Real; Next:PSNode; End;

{ Repartit les pieces selectionnees regulierement entre la premiere et la derniere (axe 0 X, 1 Y, 2 Z) }
Procedure DistSel(Axis:Integer);
Var Q:PPiece; L,N,P:PSNode; I,Cnt:Integer; A,B:TVec; K0,K1,Step,Cur,C:Real;
Begin
 Cnt:=SelCount;
 If Cnt<3 Then Begin SetMsg('Au moins trois pi\eces.'); Exit; End;
 L:=Nil;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel Then Begin
   PieceBounds(Q,False,A,B);
   Case Axis Of 0:C:=(A.X+B.X)/2; 1:C:=(A.Y+B.Y)/2; Else C:=(A.Z+B.Z)/2; End;
   New(N); N^.Q:=Q; N^.K:=C; N^.Next:=Nil;
   If(L=Nil)Or(C<L^.K)Then Begin N^.Next:=L; L:=N; End
   Else Begin
    P:=L;
    While(P^.Next<>Nil)And(P^.Next^.K<=C)Do P:=P^.Next;
    N^.Next:=P^.Next; P^.Next:=N;
   End;
  End;
  Q:=Q^.Next;
 End;
 PushUndo;
 K0:=L^.K;
 P:=L; While P^.Next<>Nil Do P:=P^.Next;
 K1:=P^.K;
 Step:=(K1-K0)/(Cnt-1);
 N:=L; I:=0;
 While N<>Nil Do Begin
  Cur:=K0+Step*I;
  If Not N^.Q^.Locked Then
   Case Axis Of
    0:N^.Q^.M.T.X:=N^.Q^.M.T.X+Cur-N^.K;
    1:N^.Q^.M.T.Y:=N^.Q^.M.T.Y+Cur-N^.K;
   Else N^.Q^.M.T.Z:=N^.Q^.M.T.Z+Cur-N^.K;
   End;
  Inc(I);
  P:=N^.Next; Dispose(N); N:=P;
 End;
 Touch;
End;

Procedure MirrorSel(Axis:Integer);
Var Q:PPiece; Mn,Mx:TVec; C:TVec; I:Integer;
Begin
 If SelCount=0 Then Exit;
 If Not SelBounds(Mn,Mx)Then Exit;
 C.X:=Round((Mn.X+Mx.X)/40)*20; C.Y:=Round((Mn.Y+Mx.Y)/16)*8; C.Z:=Round((Mn.Z+Mx.Z)/40)*20;
 PushUndo;
 Q:=Models[CurModel].First;
 While Q<>Nil Do Begin
  If Q^.Sel And(Not Q^.Locked)Then Begin
   Case Axis Of
    0:Begin Q^.M.T.X:=2*C.X-Q^.M.T.X; For I:=0 To 2 Do Q^.M.R[0,I]:=-Q^.M.R[0,I]; End;
    1:Begin Q^.M.T.Y:=2*C.Y-Q^.M.T.Y; For I:=0 To 2 Do Q^.M.R[1,I]:=-Q^.M.R[1,I]; End;
   Else Begin Q^.M.T.Z:=2*C.Z-Q^.M.T.Z; For I:=0 To 2 Do Q^.M.R[2,I]:=-Q^.M.R[2,I]; End;
   End;
  End;
  Q:=Q^.Next;
 End;
 Touch;
End;

{ Analyse "a b c ..." : nombres separes par des espaces ou des virgules }
Function ParseNums(S:String;Var V:Array Of Real;Max:Integer):Integer;
Var I,N:Integer; T:String;
Begin
 For I:=1 To Length(S) Do If S[I]=',' Then S[I]:=' ';
 N:=0;
 While(N<Max)And(TrimStr(S)<>'')Do Begin
  If Not NumTok(S,V[N])Then Begin ParseNums:=N; Exit; End;
  Inc(N);
 End;
 ParseNums:=N;
End;

{ Tableau : "n dx dy dz [ry]" copies de la selection decalees (et pivotees autour de Y) }
Procedure ArraySel;
Var S:String; V:Array[0..4] Of Real; N,I,K:Integer; Q,C,Last:PPiece; Rt:TMat; T:TVec; Pv:TVec; Mn,Mx:TVec;
Begin
 If SelCount=0 Then Exit;
 S:='3 40 0 0';
 If Not InputBox('Tableau','Copies, dx, dy, dz [rotation Y] :',S,40)Then Exit;
 N:=ParseNums(S,V,5);
 If N<4 Then Begin AskBox('Tableau','Format : n dx dy dz [ry]',0); Exit; End;
 If(V[0]<2)Or(V[0]>200)Then Exit;
 PushUndo;
 If SelBounds(Mn,Mx)Then Begin Pv.X:=Round((Mn.X+Mx.X)/40)*20; Pv.Y:=0; Pv.Z:=Round((Mn.Z+Mx.Z)/40)*20; End
 Else VSet(Pv,0,0,0);
 Last:=Models[CurModel].Last;
 For K:=1 To Round(V[0])-1 Do Begin
  Q:=Models[CurModel].First;
  While Q<>Nil Do Begin
   If Q^.Sel Then Begin
    C:=AddPiece(CurModel,Q^.Name,Q^.Col,Q^.M,Q^.Step);
    C^.Group:=0; C^.Locked:=False;
    C^.M.T.X:=C^.M.T.X+V[1]*K; C^.M.T.Y:=C^.M.T.Y+V[2]*K; C^.M.T.Z:=C^.M.T.Z+V[3]*K;
    If(N>=5)And(Abs(V[4])>0.001)Then Begin
     MatRotAxis(1,V[4]*K,Rt);
     T.X:=C^.M.T.X-Pv.X; T.Y:=C^.M.T.Y-Pv.Y; T.Z:=C^.M.T.Z-Pv.Z;
     MatApply(Rt,T,T);
     MatMul(Rt,C^.M,C^.M);
     C^.M.T.X:=Round((T.X+Pv.X)*100)/100; C^.M.T.Y:=T.Y+Pv.Y; C^.M.T.Z:=Round((T.Z+Pv.Z)*100)/100;
     SnapRot(C^.M);
    End;
    C^.Sel:=False;
   End;
   If Q=Last Then Q:=Nil Else Q:=Q^.Next;
  End;
 End;
 Touch;
End;

{ Transformation numerique : "dx dy dz rx ry rz" (rotations autour du pivot) }
Procedure NumXform;
Var S:String; V:Array[0..5] Of Real; N:Integer;
Begin
 If SelCount=0 Then Exit;
 S:='0 0 0 0 0 0';
 If Not InputBox('Transformation','dx dy dz rx ry rz (LDU, degres) :',S,50)Then Exit;
 N:=ParseNums(S,V,6);
 If N<3 Then Exit;
 PushUndo;
 MoveSel(V[0],V[1],V[2]);
 If(N>=4)And(Abs(V[3])>0.001)Then RotateSelCore(0,V[3]);
 If(N>=5)And(Abs(V[4])>0.001)Then RotateSelCore(1,V[4]);
 If(N>=6)And(Abs(V[5])>0.001)Then RotateSelCore(2,V[5]);
 Touch;
End;

Procedure CyclePivot;
Begin
 PivotMode:=(PivotMode+1) Mod 3;
 Case PivotMode Of
  0:SetMsg('Pivot : centre de la s\election');
  1:SetMsg('Pivot : origine de chaque pi\ece');
  2:SetMsg('Pivot : origine du mod\gle');
 End;
End;

{ ====================================================================== }
{ Poignees de transformation (gizmo)                                     }
{ ====================================================================== }

Type
 TGizHandle=Record
  Ok:Boolean;
  TX,TY,RX,RY:Integer;     { pointe de translation, poignee de rotation (relatif a la vue) }
  UX,UY:Real;              { direction ecran unitaire de l'axe }
  PxPerLDU:Real;
 End;

Var
 Giz:Array[0..2] Of TGizHandle;
 GizOX,GizOY:Integer;
 GizOk:Boolean;
 GizCenter:TVec;

Procedure ComputeGizmo(Var V:TView);
Var Mn,Mx:TVec; A:Integer; E,P0,P1,O0,O1:TVec; X0,Y0,X1,Y1:Integer; DX,DY,L,Sc:Real;
Begin
 GizOk:=False;
 If Not SelBounds(Mn,Mx)Then Exit;
 GizCenter.X:=(Mn.X+Mx.X)/2; GizCenter.Y:=(Mn.Y+Mx.Y)/2; GizCenter.Z:=(Mn.Z+Mx.Z)/2;
 SetupCamera(V);
 MatApply(CamM,GizCenter,O0);
 If CamPersp And(O0.Z<NEARZ)Then Exit;
 Proj(O0,X0,Y0);
 GizOX:=X0; GizOY:=Y0;
 For A:=0 To 2 Do Begin
  VSet(E,0,0,0);
  If A=0 Then E.X:=10 Else If A=1 Then E.Y:=10 Else E.Z:=10;
  P1.X:=GizCenter.X+E.X; P1.Y:=GizCenter.Y+E.Y; P1.Z:=GizCenter.Z+E.Z;
  MatApply(CamM,P1,O1);
  Proj(O1,X1,Y1);
  DX:=X1-X0; DY:=Y1-Y0;
  L:=Sqrt(DX*DX+DY*DY);
  Giz[A].Ok:=L>1.5;
  If Giz[A].Ok Then Begin
   Giz[A].UX:=DX/L; Giz[A].UY:=DY/L;
   Giz[A].PxPerLDU:=L/10;
   Giz[A].TX:=X0+Round(Giz[A].UX*46); Giz[A].TY:=Y0+Round(Giz[A].UY*46);
   Giz[A].RX:=X0+Round(Giz[A].UX*26-Giz[A].UY*12); Giz[A].RY:=Y0+Round(Giz[A].UY*26+Giz[A].UX*12);
  End;
 End;
 GizOk:=True;
End;

Procedure DrawEditGizmo(Var V:TView);
Var A,Col:Integer;
Begin
 ComputeGizmo(V);
 If Not GizOk Then Exit;
 For A:=0 To 2 Do
  If Giz[A].Ok Then Begin
   Case A Of 0:Col:=12; 1:Col:=10; Else Col:=9; End;
   SetColor(Col);
   SetLineStyle(0,0,3);
   Line(GizOX,GizOY,Giz[A].TX,Giz[A].TY);
   SetLineStyle(0,0,1);
   SetFillStyle(SolidFill,Col);
   FillEllipse(Giz[A].TX,Giz[A].TY,4,4);
   SetColor(UI_DK);
   Rectangle(Giz[A].RX-4,Giz[A].RY-4,Giz[A].RX+4,Giz[A].RY+4);
   SetFillStyle(SolidFill,Col);
   Bar(Giz[A].RX-3,Giz[A].RY-3,Giz[A].RX+3,Giz[A].RY+3);
  End;
 SetColor(UI_DK);
 Circle(GizOX,GizOY,3);
End;

{ Retourne l'axe touche (0..2) et IsRot ; -1 si rien }
Function GizmoHit(Var V:TView;PX,PY:Integer;Var IsRot:Boolean):Integer;
Var A:Integer;
Begin
 GizmoHit:=-1;
 ComputeGizmo(V);
 If Not GizOk Then Exit;
 For A:=0 To 2 Do
  If Giz[A].Ok Then Begin
   If(Abs(PX-Giz[A].TX)<=6)And(Abs(PY-Giz[A].TY)<=6)Then Begin GizmoHit:=A; IsRot:=False; Exit; End;
   If(Abs(PX-Giz[A].RX)<=6)And(Abs(PY-Giz[A].RY)<=6)Then Begin GizmoHit:=A; IsRot:=True; Exit; End;
  End;
End;
{ ---------------------------- Documents ---------------------------- }

Procedure ResetEditState;
Begin
 SlotReset;
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
 PAgg=^TAgg;
 TAgg=Record
  N:String[40];
  C:LongInt;
  Q:Integer;
  Next:PAgg;
 End;

Var
 Agg:PAgg;
 AggN:Integer;

Procedure FreeAgg;
Var A,N:PAgg;
Begin
 A:=Agg;
 While A<>Nil Do Begin N:=A^.Next; Dispose(A); A:=N; End;
 Agg:=Nil; AggN:=0;
End;

Procedure AggAdd(Const Nm:String;Col:LongInt;Mult:Integer);
Var A,T:PAgg; U:String;
Begin
 U:=UpStr(Nm);
 A:=Agg; T:=Nil;
 While A<>Nil Do Begin
  If(A^.C=Col)And(UpStr(A^.N)=U)Then Begin Inc(A^.Q,Mult); Exit; End;
  T:=A; A:=A^.Next;
 End;
 New(A); A^.N:=Copy(Nm,1,40); A^.C:=Col; A^.Q:=Mult; A^.Next:=Nil;
 If T=Nil Then Agg:=A Else T^.Next:=A;
 Inc(AggN);
End;

Procedure AggModel(M:Integer;Mult,Depth:Integer);
Var Q:PPiece; S:Integer;
Begin
 If Depth>12 Then Exit;
 Q:=Models[M].First;
 While Q<>Nil Do Begin
  S:=PieceSub(Q);
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
Var F:Text; A:PAgg; Tot:LongInt;
Begin
 FreeAgg;
 AggModel(0,1,0);
 {$I-}
 Assign(F,Path); Rewrite(F);
 {$I+}
 If IOResult<>0 Then Begin FreeAgg; AskBox('Exporter','Impossible de cr\eer le fichier.',0); Exit; End;
 WriteLn(F,'LISTE DES PIECES - ',BaseOf(DocFile));
 WriteLn(F,'Qte  Couleur                 Piece         Description');
 WriteLn(F,'---------------------------------------------------------------');
 Tot:=0;
 A:=Agg;
 While A<>Nil Do Begin
  WriteLn(F,PadR(IntStr(A^.Q),5),PadR(Plain(ColNameOf(A^.C)),23),' ',
          PadR(UpStr(A^.N),13),' ',PartDescByName(A^.N));
  Inc(Tot,A^.Q);
  A:=A^.Next;
 End;
 WriteLn(F,'---------------------------------------------------------------');
 WriteLn(F,'Total : ',Tot,' pieces, ',AggN,' references');
 Close(F);
 FreeAgg;
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
 ExtraDir:=DirOf(FExpand(Nm));
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
 RescanLibrary;
 LoadCatalog;
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


{ ====================================================================== }
{ Fonctions avancees (cameras, animation, exports, preferences...)      }
{ ====================================================================== }

Procedure NotYet(Const S:String);
Begin
 AskBox(S,'Cette fonction n''est pas encore disponible.',0);
End;

Procedure NextViewCmd;
Begin
 If ViewCount=1 Then Begin
  ActiveView:=(ActiveView+1) Mod 4;
  LayoutViews;
  ZoomFit(Views[ActiveView]);
 End
  Else ActiveView:=(ActiveView+1) Mod 4;
 NeedViews:=True; NeedTools:=True;
End;

Procedure ExportImageCmd; Begin NotYet('Exporter l''image'); End;
Procedure ExportHTMLCmd; Begin NotYet('Instructions HTML'); End;
Procedure ExportPOVCmd; Begin NotYet('POV-Ray'); End;
Procedure ExportOBJCmd; Begin NotYet('Wavefront OBJ'); End;
Procedure Export3DSCmd; Begin NotYet('3D Studio'); End;
Procedure ExportBLCmd; Begin NotYet('BrickLink XML'); End;
Procedure ImportBLCmd; Begin NotYet('BrickLink XML'); End;
Procedure PartsUsedDialog; Begin NotYet('Pieces utilisees'); End;
Procedure PrefsDialog; Begin NotYet('Preferences'); End;
Procedure DocsDialog; Begin NotYet('Documents'); End;
Procedure CamNewCmd; Begin NotYet('Cameras'); End;
Procedure CamGoCmd; Begin NotYet('Cameras'); End;
Procedure CamDelCmd; Begin NotYet('Cameras'); End;
Procedure FovCmd; Begin NotYet('Champ de vision'); End;
Procedure KeyAddCmd; Begin NotYet('Animation'); End;
Procedure KeyDelCmd; Begin NotYet('Animation'); End;
Procedure KeyPlayCmd; Begin NotYet('Animation'); End;
Procedure StepsPlayCmd; Begin NotYet('Animation'); End;
Procedure AnimExportCmd; Begin NotYet('Animation'); End;
Procedure KeysDialog; Begin NotYet('Raccourcis'); End;

{ ---------------------------- Commandes ----------------------------- }

Procedure DoCmd(Cmd:Integer);
Var Nm:String;
Begin
 Case Cmd Of
  CM_NEW:If ConfirmDiscard Then DoNew;
  CM_OPEN:DoOpen;
  CM_SAVE:DoSave;
  CM_SAVEAS:DoSaveAs;
  CM_EXP_IMG:ExportImageCmd;
  CM_EXP_HTML:ExportHTMLCmd;
  CM_EXP_POV:ExportPOVCmd;
  CM_EXP_OBJ:ExportOBJCmd;
  CM_EXP_3DS:Export3DSCmd;
  CM_EXP_BL:ExportBLCmd;
  CM_EXP_LIST:Begin Nm:=''; If FileDialog(3,Nm)Then ExportParts(Nm); End;
  CM_IMP_BL:ImportBLCmd;
  CM_PARTSUSED:PartsUsedDialog;
  CM_INFO:DoInfo;
  CM_PREFS:PrefsDialog;
  CM_REINDEX:DoReindex;
  CM_DOCS:DocsDialog;
  CM_QUIT:DoQuit;
  CM_UNDO:Begin DoUndo; ClearSel; Touch; NeedTools:=True; End;
  CM_REDO:Begin DoRedo; ClearSel; Touch; NeedTools:=True; End;
  CM_CUT:Begin CopySel; DeleteSel; End;
  CM_COPY:CopySel;
  CM_PASTE:PasteClip(20,20);
  CM_DELETE:DeleteSel;
  CM_SELALL:SelectAll;
  CM_SELNONE:Begin ClearSel; Touch; End;
  CM_SELINV:SelectInvert;
  CM_SELCOL:SelectSame(True);
  CM_SELPART:SelectSame(False);
  CM_ADDMODE:Begin
   AddMode:=Not AddMode;
   If AddMode Then SetMsg('Mode ajout \a la s\election : actif') Else SetMsg('Mode ajout \a la s\election : inactif');
  End;
  CM_VIEWS:ToggleViews;
  CM_PERSP:Begin Views[ActiveView].Persp:=Not Views[ActiveView].Persp; ZoomFit(Views[ActiveView]); NeedViews:=True; End;
  CM_V_HOME:SetPreset(0);
  CM_V_FRONT:SetPreset(1);
  CM_V_BACK:SetPreset(2);
  CM_V_LEFT:SetPreset(3);
  CM_V_RIGHT:SetPreset(4);
  CM_V_TOP:SetPreset(5);
  CM_V_BOTTOM:SetPreset(6);
  CM_ZOOMIN:Begin ZoomView(Views[ActiveView],0.8); NeedViews:=True; End;
  CM_ZOOMOUT:Begin ZoomView(Views[ActiveView],1.25); NeedViews:=True; End;
  CM_FIT:Begin ZoomFit(Views[ActiveView]); NeedViews:=True; End;
  CM_GRID:Begin GridOn:=Not GridOn; NeedViews:=True; NeedTools:=True; End;
  CM_EDGES:Begin EdgesOn:=Not EdgesOn; NeedViews:=True; End;
  CM_WIRE:Begin WireOn:=Not WireOn; NeedViews:=True; NeedTools:=True; End;
  CM_STUDS:CycleStuds;
  CM_PN_PARTS:SetPanel(PN_PARTS);
  CM_PN_PROPS:SetPanel(PN_PROPS);
  CM_PN_TIME:SetPanel(PN_TIME);
  CM_NEXTVIEW:NextViewCmd;
  CM_INSERT:Begin If CurPart<>'' Then Begin Tool:=TL_INSERT; NeedTools:=True; Touch; End Else SetMsg('Choisir d''abord une pi\ece.'); End;
  CM_DUP:Begin CopySel; PasteClip(20,20); End;
  CM_UP8:Begin If SelCount>0 Then Begin PushUndo; MoveSel(0,-8,0); Touch; End; End;
  CM_DN8:Begin If SelCount>0 Then Begin PushUndo; MoveSel(0,8,0); Touch; End; End;
  CM_UP24:Begin If SelCount>0 Then Begin PushUndo; MoveSel(0,-24,0); Touch; End; End;
  CM_DN24:Begin If SelCount>0 Then Begin PushUndo; MoveSel(0,24,0); Touch; End; End;
  CM_RXP:RotateSel(0,90);
  CM_RXM:RotateSel(0,-90);
  CM_RYP:RotateSel(1,90);
  CM_RYM:RotateSel(1,-90);
  CM_RZP:RotateSel(2,90);
  CM_RZM:RotateSel(2,-90);
  CM_APPLYCOL:ApplyColorSel(CurColor);
  CM_HIDE:HideSel;
  CM_SHOWALL:ShowAllPieces;
  CM_GROUP:GroupSel;
  CM_UNGROUP:UngroupSel;
  CM_LOCK:LockSel(True);
  CM_UNLOCK:LockSel(False);
  CM_SELTOOL:Begin
   If Tool<>TL_SELECT Then Begin Tool:=TL_SELECT; NeedTools:=True; NeedViews:=True; End
   Else Begin ClearSel; Touch; End;
  End;
  CM_AL_L:AlignSel(0);
  CM_AL_R:AlignSel(1);
  CM_AL_F:AlignSel(2);
  CM_AL_B:AlignSel(3);
  CM_AL_T:AlignSel(4);
  CM_AL_D:AlignSel(5);
  CM_CEN_X:AlignSel(6);
  CM_CEN_Z:AlignSel(7);
  CM_DIST_X:DistSel(0);
  CM_DIST_Y:DistSel(1);
  CM_DIST_Z:DistSel(2);
  CM_MIR_X:MirrorSel(0);
  CM_MIR_Y:MirrorSel(1);
  CM_MIR_Z:MirrorSel(2);
  CM_ARRAY:ArraySel;
  CM_NUMXF:NumXform;
  CM_PIVOT:CyclePivot;
  CM_STEP_NEXT:SetStep(Models[CurModel].CurStep+1);
  CM_STEP_PREV:SetStep(Models[CurModel].CurStep-1);
  CM_STEP_FIRST:SetStep(1);
  CM_STEP_LAST:SetStep(MaxStep(CurModel));
  CM_STEP_INS:InsertStep;
  CM_STEP_DEL:DeleteStep;
  CM_STEP_SEL:SelToStep;
  CM_SUB_NEW:NewSubModel(False);
  CM_SUB_FROMSEL:NewSubModel(True);
  CM_SUB_INS:InsertSubModel;
  CM_SUB_EDIT:EditSubModel;
  CM_SUB_MAIN:SwitchModel(0);
  CM_SUB_DEL:DeleteSubModel;
  CM_CAM_NEW:CamNewCmd;
  CM_CAM_GO:CamGoCmd;
  CM_CAM_DEL:CamDelCmd;
  CM_FOV:FovCmd;
  CM_KEY_ADD:KeyAddCmd;
  CM_KEY_DEL:KeyDelCmd;
  CM_KEY_PLAY:KeyPlayCmd;
  CM_STEPS_PLAY:StepsPlayCmd;
  CM_ANIM_EXP:AnimExportCmd;
  CM_HELP:HelpDialog;
  CM_KEYS:KeysDialog;
  CM_ABOUT:AskBox('A propos de LEOCAD','LEOCAD 1.00 - clone de LeoCAD|CAO de briques Lego en 3D (LDraw .LDR/.MPD)|Turbo Pascal 7 / Free Pascal|https://www.gladir.com/clonedraw',0);
  CM_TOOL_SEL:Begin Tool:=TL_SELECT; NeedTools:=True; NeedViews:=True; End;
  CM_TOOL_ORB:Begin Tool:=TL_ORBIT; NeedTools:=True; NeedViews:=True; End;
  CM_TOOL_PAN:Begin Tool:=TL_PAN; NeedTools:=True; NeedViews:=True; End;
  CM_TOOL_ZOOM:Begin Tool:=TL_ZOOM; NeedTools:=True; NeedViews:=True; End;
 End;
 If FullRedraw Then Begin RedrawAll; FullRedraw:=False; End;
 NeedStatus:=True;
End;

Procedure ToolbarClick(I:Integer);
Begin
 Case I Of
  0:DoCmd(CM_NEW);
  1:DoCmd(CM_OPEN);
  2:DoCmd(CM_SAVE);
  3:DoCmd(CM_UNDO);
  4:DoCmd(CM_REDO);
  5:DoCmd(CM_TOOL_SEL);
  6:DoCmd(CM_INSERT);
  7:DoCmd(CM_TOOL_ORB);
  8:DoCmd(CM_TOOL_PAN);
  9:DoCmd(CM_TOOL_ZOOM);
  10:DoCmd(CM_GRID);
  11:DoCmd(CM_WIRE);
  12:DoCmd(CM_VIEWS);
  13:DoCmd(CM_FIT);
  14:DoCmd(CM_STEP_FIRST);
  15:DoCmd(CM_STEP_PREV);
  16:DoCmd(CM_STEP_NEXT);
  17:DoCmd(CM_STEP_LAST);
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
 GizAxis,GizStartX,GizStartY:Integer;
 GizApplied,GizUX,GizUY,GizPx:Real;
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
 If Menus[M].Items[I].Enabled Then DoCmd(Menus[M].Items[I].Cmd);
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
Var O,D:TVec; X,Z,Y0:Real; Own:Integer; Q:PPiece; Mn,Mx:TVec; RX,RY:Integer; Ok:Boolean; RefQ:PPiece;
Begin
 InsValid:=False; RefQ:=Nil;
 If(CurPart='')Or(V<0)Then Exit;
 RX:=PX-Views[V].X1; RY:=PY-Views[V].Y1;
 ComputeGround;
 Y0:=GroundY;
 If Models[CurModel].Count<=600 Then Begin
  Own:=PickPiece(Views[V],RX,RY);
  If Own>0 Then Begin
   Q:=PieceByIndex(Own);
   If Q<>Nil Then Begin PieceBounds(Q,True,Mn,Mx); Y0:=Mn.Y; RefQ:=Q; End;
  End;
 End;
 ScreenRay(Views[V],RX,RY,O,D);
 Ok:=RayPlaneY(O,D,Y0,X,Z);
 If Not Ok Then Exit;
 ComputeInsert(X,Z,RefQ);
 UpdateGhost;
 InsValid:=True;
End;

Procedure ViewPress(V,Btn:Integer);
Var RX,RY,Own:Integer; Q:PPiece; O,D:TVec; X,Z:Real; IsRot:Boolean;
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
  If SelCount>0 Then Begin
   GizAxis:=GizmoHit(Views[V],RX,RY,IsRot);
   If GizAxis>=0 Then Begin
    GizStartX:=MX; GizStartY:=MY; GizApplied:=0; MoveBegun:=False;
    GizUX:=Giz[GizAxis].UX; GizUY:=Giz[GizAxis].UY; GizPx:=Giz[GizAxis].PxPerLDU;
    If IsRot Then DragMode:=8 Else DragMode:=7;
    Exit;
   End;
  End;
  Own:=PickPiece(Views[V],RX,RY);
  If Own>0 Then Begin
   Q:=PieceByIndex(Own);
   If(Q<>Nil)And AddMode Then Begin
    SelectGroupOf(Q,Not Q^.Sel);
    Touch;
    Exit;
   End;
   If Q<>Nil Then Begin
    If Not Q^.Sel Then Begin ClearSel; SelectGroupOf(Q,True); End;
    DragMode:=4; MoveBegun:=False; MoveAppX:=0; MoveAppZ:=0;
    MovePlaneY:=Q^.M.T.Y;
    ScreenRay(Views[V],RX,RY,O,D);
    If RayPlaneY(O,D,MovePlaneY,X,Z)Then Begin MoveStartX:=X; MoveStartZ:=Z; End
    Else DragMode:=0;
    Touch;
   End;
  End
   Else Begin
    If Not AddMode Then ClearSel;
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
  7:Begin
   TX:=((MX-GizStartX)*GizUX+(MY-GizStartY)*GizUY)/GizPx;
   If GizAxis=1 Then TZ:=8 Else TZ:=20;
   TX:=Round(TX/TZ)*TZ;
   If TX<>GizApplied Then Begin
    If Not MoveBegun Then Begin PushUndo; MoveBegun:=True; End;
    Case GizAxis Of
     0:MoveSel(TX-GizApplied,0,0);
     1:MoveSel(0,TX-GizApplied,0);
    Else MoveSel(0,0,TX-GizApplied);
    End;
    GizApplied:=TX;
    NeedViews:=True; NeedStatus:=True;
   End;
  End;
  8:Begin
   TX:=Round(((MX-GizStartX)*0.6)/15)*15;
   If TX<>GizApplied Then Begin
    If Not MoveBegun Then Begin PushUndo; MoveBegun:=True; End;
    RotateSelCore(GizAxis,TX-GizApplied);
    GizApplied:=TX;
    NeedViews:=True; NeedStatus:=True;
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
     If Vis And(SX>=X1)And(SX<=X2)And(SY>=Y1)And(SY<=Y2)Then SelectGroupOf(Q,True);
    End;
    Q:=Q^.Next;
   End;
  End;
  Touch;
 End;
 If((DragMode=4)Or(DragMode=7)Or(DragMode=8))And MoveBegun Then Begin Touch; NeedTools:=True; End;
 DragMode:=0; DragView:=-1;
End;

{ ====================================================================== }
{ Evenements : panneaux                                                  }
{ ====================================================================== }

Procedure SelectPart(K:Integer);
Var E:PCat;
Begin
 If(K<0)Or(K>=FilN)Then Exit;
 E:=FilAt(K);
 If E=Nil Then Exit;
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
  4:Begin
   If PY<ColY+28 Then PY:=ColY+28; If PY>ColY+16+COL_ROWS*16+4-13 Then PY:=ColY+16+COL_ROWS*16+4-13;
   N:=VScrollClick(ColY+16,COL_ROWS*16+4,ColTop,ColRowsTotal,COL_ROWS,PY);
   If N<>ColTop Then Begin ColTop:=N; NeedDock:=True; End;
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
 LP:=(((MB And 1)<>0)And((OldMB And 1)=0))Or LatchL;
 RP:=(((MB And 2)<>0)And((OldMB And 2)=0))Or LatchR;
 MP:=(((MB And 4)<>0)And((OldMB And 4)=0))Or LatchM;
 LR:=(((MB And 7)=0)And((OldMB And 7)<>0))Or LatchRel;
 { clic bref survenu pendant un rendu : position memorisee a l'appui }
 If(LP Or RP Or MP)And((MB And 7)=0)Then Begin MX:=LatchX; MY:=LatchY; End;
 ClearLatch;

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
         Else If InRect(MX,MY,ScreenW-15,ColY+16,12,COL_ROWS*16+4)Then Begin
          ColTop:=VScrollClick(ColY+16,COL_ROWS*16+4,ColTop,ColRowsTotal,COL_ROWS,MY);
          DragScroll:=4; NeedDock:=True;
         End
         Else If InRect(MX,MY,DockX,ColY,ScreenW-DockX,ColY2-ColY+1)Then Begin
          B:=ColHit(MX,MY);
          If B>=0 Then Begin
           CurColor:=ColByIndex(B)^.Code;
           ApplyColorSel(CurColor);
           NeedDock:=True; NeedViews:=True;
          End;
         End;
       End;
     End;
   End;
  End;
 If(DragMode<>0)And((MB And 7)=0)And(LR Or LP Or RP Or MP)Then ViewRelease;
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

Procedure HandleKey;
Var K:Char; Ext:Boolean; Key,Cmd:Integer;
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
   #67:Begin OpenMenu(0); Exit; End;
   #33:Begin OpenMenu(M_FILE); Exit; End;
   #18:Begin OpenMenu(M_EDIT); Exit; End;
   #30:Begin OpenMenu(M_VIEW); Exit; End;
   #25:Begin OpenMenu(M_PIECE); Exit; End;
   #20:Begin OpenMenu(M_STEP); Exit; End;
   #31:Begin OpenMenu(M_SUB); Exit; End;
   #35:Begin OpenMenu(M_HELP); Exit; End;
  End;
  Cmd:=BindCmd(256+Ord(K));
  If Cmd<>0 Then DoCmd(Cmd)
  Else Case K Of
   #72:ArrowMove(0);
   #80:ArrowMove(1);
   #75:ArrowMove(2);
   #77:ArrowMove(3);
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
 Key:=Ord(K);
 Cmd:=BindCmd(Key);
 If(Cmd=0)And(K='=')Then Cmd:=CM_ZOOMIN;
 If(Cmd=0)And(K='_')Then Cmd:=CM_ZOOMOUT;
 If(Cmd=0)And(K>='A')And(K<='Z')And(K<>'X')And(K<>'Y')And(K<>'Z')Then Cmd:=BindCmd(Key+32);
 If Cmd<>0 Then DoCmd(Cmd);
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
 For I:=0 To MAXMOD-1 Do Begin
  Models[I].First:=Nil; Models[I].Last:=Nil; Models[I].Count:=0; Models[I].Used:=False;
 End;
 CatHead:=Nil; CatTail:=Nil; CatList:=Nil; CatListTail:=Nil; FilHead:=Nil; FilTail:=Nil;
 ColHead:=Nil; ColTail:=Nil; NCol:=0; ColTop:=0;
 PolyHead:=Nil; PolyPool:=Nil; PolyN:=0;
 UndoTop:=Nil; RedoTop:=Nil;
 GroupHead:=Nil; NextGroupId:=1; CamHead:=Nil; KeyHead:=Nil; ModEpoch:=1;
 ExtraDir:=''; AltLibDir:=GetEnv('LDRAWDIR');
 If(AltLibDir<>'')And(AltLibDir[Length(AltLibDir)]<>#92)And(AltLibDir[Length(AltLibDir)]<>'/')Then AltLibDir:=AltLibDir+PathSep;
 If Not DirOK(AltLibDir)Then AltLibDir:='';
 ClearLatch; PrevPoll:=0; LatchX:=0; LatchY:=0;
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
  WriteLn('Syntaxe : LEOCAD [/16] [-maxscreen] [fichier.ldr|fichier.mpd]');
  WriteLn;
  WriteLn(' /16        force le mode VGA 16 couleurs');
  WriteLn(' -maxscreen Utilise la resolution maximale disponible.');
  WriteLn(' Bibliotheque : SAMPLES\LEOCAD\LEGO\*.DAT');
  WriteLn(' Plans       : SAMPLES\LEOCAD\PLAN\*.LDR, *.MPD');
  Halt;
 End;
 Force16:=False; MaxScreen:=False; ArgFile:='';
 For I0:=1 To ParamCount Do
  If(ParamStr(I0)='/16')Or(ParamStr(I0)='-16')Then Force16:=True
  Else If UpStr(ParamStr(I0))='-MAXSCREEN' Then MaxScreen:=True
  Else If ArgFile='' Then ArgFile:=ParamStr(I0);
 InitializeGraphics;
 ScreenW:=GetMaxX+1; ScreenH:=GetMaxY+1;
 Palette256:=GetMaxColor>15;
 InitDirs;
 InitGlobals;
 ResolveRoot(0,LibDir); ResolveRoot(1,AltLibDir);
 InitColors;
 If Not LoadLDConfig(LibDir+'LDCONFIG.LDR')Then
  If Not LoadLDConfig(LibDir+'..'+PathSep+'LDCONFIG.LDR')Then
   If(AltLibDir<>'')And Not LoadLDConfig(AltLibDir+'LDConfig.ldr')Then;
 SetupPalette;
 MouseDriverFound;
 LayoutScreen;
 InitMenus;
 LoadCatalog;
 If AltLibDir<>'' Then StatusMsg:=Copy('LDraw : '+AltLibDir,1,60);
 NewDocument;
 InitViews;
 Running:=True;
 RedrawAll;
 If ArgFile<>'' Then OpenPath(ArgFile);
 MainLoop;
 Cleanup;
END.
