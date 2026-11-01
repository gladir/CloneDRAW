{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application ARTWORX
}

{ Liste de points implementes :
  ---------------------------------------------------------------------------
   1. Menus deroulants ArtWorx / Fichier / Edition / Objet / Style / Module /
      Options (souris, F10, Alt+lettre, fleches, Entree, Echap)
   2. Fenetre de document : barre de titre (Noname, * si modifie), ligne
      d'information (zoom, X:, Y:, dX:, dY:, page, icones rapides), panneau
      d'icones (fonctions, choix, boites a outils), regle de defilement
   3. Boite a outils de dessin : ligne, multi-ligne, rectangle, rectangle
      arrondi, triangle, parallelogramme, cercle, ellipse, arc circulaire,
      arc elliptique, ligne elastique, courbe de Bezier, texte, texte cadre,
      courbe spline, N-cotes, main levee, image bitmap
   4. Boite a outils d'edition de chemin : deplacer noeud, deplacement
      tangentiel, type de segment, couper, supprimer, ajouter, lisser,
      point de saut, sens de la ligne
   5. Boite a outils image (ajuster, couper bordures, palette, gradation) et
      boite a outils texte (edition du contenu)
   6. Mode selection : selection, deplacement, redimensionnement (poignees),
      rotation et cisaillement (second clic), cadre de selection, Maj
   7. Rotation libre de tous les objets (ellipses, groupes, texte, ...)
   8. Couleurs RVB / CMJ / TSV (indexe ou TrueColor), traits, extremites
      (fleche, arrondie), trames de remplissage, tons de gris, ombres
   9. Groupes, calques (8), pages multiples, verrouillage, statuts d'objet
  10. Aligner (Arrange), Commuter, Transformer (formules utilisateur, miroir,
      sinus, cercle, globe...), Tiling (copies en serie), Booleen
  11. Annuler (Undo) sur 10 niveaux, copier / couper / coller
  12. Fichiers : format natif .CWG, export EPS / SVG / ASCII, import de
      texte ASCII et d'images BMP, impression PostScript
  13. Modules internes (texte sur un cercle, etiquettes, rosace)
  14. Interface en francais par defaut, en anglais si la variable
      d'environnement LANGUAGE=EN
}

Program ARTWORX;

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$R-}
 {$OVERFLOWCHECKS OFF}
{$ELSE}
 {$N+,E+}
 {$M 49152,0,380000}
 {$R-,S-,I-,Q-}
{$ENDIF}

Uses {$IFDEF FPC}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 {$IFNDEF FPC}
 If ErrCode<>grOk Then Begin
  Driver:=Detect; Mode:=VGAHi;
  InitGraph(Driver,Mode,'BGI');
  ErrCode:=GraphResult;
  If ErrCode<>grOk Then Begin
   Driver:=Detect; Mode:=VGAHi;
   InitGraph(Driver,Mode,'C:\TP\BGI');
   ErrCode:=GraphResult;
  End;
 End;
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
  MouseDriverFound := True;
 End;

 Procedure ShowMouse;
 Begin
  { Pas d'implementation pour Free Pascal }
 End;

 Procedure HideMouse;
 Begin
  { Pas d'implementation pour Free Pascal }
 End;
{$ENDIF}

{ ====================================================================== }
{                              CONSTANTES                                }
{ ====================================================================== }

Const
 SCR_W = 640;
 SCR_H = 480;
 MENU_H = 16;
 TITLE_Y = 16;
 TITLE_H = 16;
 INFO_Y = 32;
 INFO_H = 34;
 PANEL_W = 78;
 CVX1 = 78;
 CVY1 = 66;
 CVX2 = 622;
 CVY2 = 462;
 SB_W = 16;

 INK = 0;
 PAPER = 15;
 CHROME = 7;

 MAXOBJ = 400;
 MAXNODE = 300;
 MAXPT = 3400;
 MAXSUB = 80;
 MAXUNDO = 10;
 NLAYER = 8;
 MAXPAGE = 20;
 BMPMAXW = 200;
 BMPMAXH = 140;

 { Types d'objets }
 OK_LINE = 1;   OK_POLY = 2;   OK_RECT = 3;   OK_RRECT = 4;  OK_TRI = 5;
 OK_PARA = 6;   OK_CIRCLE = 7; OK_ELLIPSE = 8; OK_ARC = 9;   OK_EARC = 10;
 OK_BEZIER = 11; OK_SPLINE = 12; OK_NGON = 13; OK_FREE = 14; OK_TEXT = 15;
 OK_FTEXT = 16; OK_BITMAP = 17; OK_COMPOUND = 18;

 { Outils de dessin (1..18) }
 T_LINE = 1; T_MLINE = 2; T_RECT = 3; T_RRECT = 4; T_TRI = 5; T_PARA = 6;
 T_CIRCLE = 7; T_ELLIPSE = 8; T_ARC = 9; T_EARC = 10; T_RUBBER = 11;
 T_BEZIER = 12; T_TEXT = 13; T_FTEXT = 14; T_SPLINE = 15; T_NGON = 16;
 T_FREE = 17; T_BITMAP = 18;

 { Boites a outils }
 BX_DRAW = 1; BX_PATH = 2; BX_PIC = 3; BX_TEXT = 4;

 { Codes de touches : caractere = ord ; etendue = 256 + code }
 K_ESC = 27; K_ENTER = 13; K_BKSP = 8; K_TAB = 9;
 K_UP = 328; K_DOWN = 336; K_LEFT = 331; K_RIGHT = 333;
 K_HOME = 327; K_END = 335; K_PGUP = 329; K_PGDN = 337;
 K_INS = 338; K_DEL = 339; K_F1 = 315; K_STAB = 271;

 NMENU = 7;

{ ====================================================================== }
{                                TYPES                                   }
{ ====================================================================== }

Type
 PStr = ^String;
 TNode = Record
  X,Y,AX,AY,BX,BY: Double;
  Kind: Byte;                { 0 ligne, 1 bezier, 2 saut }
 End;
 PNodeArr = ^TNodeArr;
 TNodeArr = Array[0..MAXNODE-1] Of TNode;
 PBytes = ^TBytes;
 TBytes = Array[0..BMPMAXW*BMPMAXH-1] Of Byte;
 PObj = ^TObj;
 TObj = Record
  Kind: Byte;
  Closed: Boolean;
  N,Cap: Integer;
  Nd: PNodeArr;
  Layer,Page: Byte;
  Group: Integer;
  Sel,Locked,OnScreen,Outline,PropRes,NoRes: Boolean;
  LineCol,FillCol,ShCol: LongInt;
  LineW: Double;
  LineSty,EndS,EndE: Byte;
  FillMode,FillPat,Grey: Byte;
  ShOn: Boolean;
  ShDX,ShDY: Double;
  Txt: PStr;
  FSize: Double;
  TFlags,TAlign: Byte;
  Rad,A1,A2: Double;
  BW,BH: Integer;
  BPix: PBytes;
 End;
 TPt = Record X,Y: Double; End;
 PPts = ^TPts;
 TPts = Array[0..MAXPT-1] Of TPt;
 PSPts = ^TSPts;
 TSPts = Array[0..MAXPT-1] Of PointType;
 TEvent = Record
  { 0 rien, 1 touche, 2 bouton gauche bas, 3 bouton gauche haut,
    4 mouvement, 5 bouton droit bas }
  Kind: Byte;
  Key: Word;
  X,Y,B: LongInt;
 End;
 TLayer = Record
  Name: String[20];
  Hidden,Locked,OnScreen: Boolean;
 End;

{ ====================================================================== }
{                              VARIABLES                                 }
{ ====================================================================== }

Var
 LangEN: Boolean;
 Quit: Boolean;
 NeedDraw: Boolean;
 { Document }
 Objs: Array[1..MAXOBJ] Of PObj;
 NObj: Integer;
 PageW,PageH: Double;
 NPages,CurPage: Integer;
 DocName: String;
 Named,Modified: Boolean;
 Layers: Array[1..NLAYER] Of TLayer;
 CurLayer: Integer;
 NextGroup: Integer;
 { Vue }
 Zoom: Double;                 { pourcentage }
 Sc: Double;                   { pixels par mm }
 OrgX,OrgY: Double;            { coin haut gauche du canevas (mm) }
 GridX,GridY: Double;
 GridShow,GridSnap: Boolean;
 UnitIdx: Integer;             { 0 mm, 1 cm, 2 in, 3 pt }
 PropResize: Boolean;
 { Style courant }
 CurLineCol,CurFillCol,CurShCol: LongInt;
 CurLineW: Double;
 CurLineSty,CurEndS,CurEndE: Byte;
 CurFillMode,CurFillPat,CurGrey: Byte;
 CurShOn: Boolean;
 CurShDX,CurShDY: Double;
 CurFSize: Double;
 CurTFlags,CurTAlign: Byte;
 { Options }
 OptDKey,OptBeep,OptConfirm,OptUndo,OptClip,OptTrue: Boolean;
 OptImages,OptModule,OptEditor: String;
 { Mode d'edition }
 CurBox,LastBox,AuxBox: Integer;
 CurTool: Array[1..4] Of Integer;
 SelMode: Boolean;
 { Souris / clavier }
 MX,MY,MB,LastB: LongInt;
 PrevMX,PrevMY: LongInt;
 LastClickT: LongInt;
 LastClickX,LastClickY: LongInt;
 { Dessin en cours }
 DS: Integer;
 DP: Array[1..40] Of TPt;
 NDP: Integer;
 DNSides: Integer;
 FreeP: PPts;
 FreeN: Integer;
 EditObj: PObj;
 TxtEditing: Boolean;
 { Tampons de decoupage / affichage }
 FP: PPts;
 FN: Integer;
 SubS: Array[0..MAXSUB] Of Integer;
 SubC: Array[0..MAXSUB] Of Boolean;
 NSub: Integer;
 SP: PSPts;
 { Selection / manipulation }
 RotMode: Boolean;
 Dragging: Integer;
 DragX0,DragY0: Double;
 DragSX,DragSY: Integer;
 DragHandle: Integer;
 SelBX1,SelBY1,SelBX2,SelBY2: Double;
 PathObj: PObj;
 PathNode: Integer;
 PathPart: Integer;           { 0 noeud, 1 tangente A, 2 tangente B }
 MarkObj: PObj;
 CurMsg: String;
 ZoomRect: Boolean;
 { Police bitmap 8x8 capturee }
 FontBits: Array[0..255,0..7] Of Byte;
 { Presse-papiers / annulation }
 UndoN: Integer;
 UndoSeq: Integer;
 ClipHas: Boolean;
 { Dialogues }
 LstItem: Array[1..80] Of String[40];
 LstN: Integer;
 { Menus }
 MenuOpen,MenuHi: Integer;
 { Divers }
 RandSeed0: LongInt;
 UserPatN: Integer;
 ImgDpi: Double;
 PrevDrawn: Boolean;
 MultiSel: Boolean;

{ ====================================================================== }
{                       UTILITAIRES GENERAUX                             }
{ ====================================================================== }

Function L2(Const En,Fr: String): String;
Begin
 If LangEN Then L2:=En Else L2:=Fr;
End;

Function IntStr(N: LongInt): String;
Var S: String;
Begin
 Str(N,S);
 IntStr:=S;
End;

Function Upper(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 Upper:=S;
End;

Function Lower(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do
  If (S[I]>='A') And (S[I]<='Z') Then S[I]:=Chr(Ord(S[I])+32);
 Lower:=S;
End;

Function TrimStr(S: String): String;
Begin
 While (S<>'') And (S[1]=' ') Do Delete(S,1,1);
 While (S<>'') And (S[Length(S)]=' ') Do Delete(S,Length(S),1);
 TrimStr:=S;
End;

Function Min2(A,B: LongInt): LongInt;
Begin
 If A<B Then Min2:=A Else Min2:=B;
End;

Function Max2(A,B: LongInt): LongInt;
Begin
 If A>B Then Max2:=A Else Max2:=B;
End;

Function MinD(A,B: Double): Double;
Begin
 If A<B Then MinD:=A Else MinD:=B;
End;

Function MaxD(A,B: Double): Double;
Begin
 If A>B Then MaxD:=A Else MaxD:=B;
End;

Function Clamp(V,Lo,Hi: LongInt): LongInt;
Begin
 If V<Lo Then V:=Lo;
 If V>Hi Then V:=Hi;
 Clamp:=V;
End;

Function ToInt(D: Double): Integer;
Begin
 If D>30000 Then D:=30000;
 If D<-30000 Then D:=-30000;
 ToInt:=Round(D);
End;

Function ArcTan2(Y,X: Double): Double;
Begin
 If X>0 Then ArcTan2:=ArcTan(Y/X)
 Else If X<0 Then Begin
  If Y>=0 Then ArcTan2:=ArcTan(Y/X)+Pi Else ArcTan2:=ArcTan(Y/X)-Pi;
 End Else Begin
  If Y>0 Then ArcTan2:=Pi/2 Else If Y<0 Then ArcTan2:=-Pi/2 Else ArcTan2:=0;
 End;
End;

Function Hypot(X,Y: Double): Double;
Begin
 Hypot:=Sqrt(X*X+Y*Y);
End;

Function ASin(X: Double): Double;
Begin
 If X>=1 Then ASin:=Pi/2 Else If X<=-1 Then ASin:=-Pi/2
 Else ASin:=ArcTan(X/Sqrt(1-X*X));
End;

Function ACos(X: Double): Double;
Begin
 ACos:=Pi/2-ASin(X);
End;

Function Power(X,Y: Double): Double;
Begin
 If X=0 Then Power:=0
 Else If X>0 Then Power:=Exp(Y*Ln(X))
 Else If Frac(Y)=0 Then Begin
  If Odd(Round(Y)) Then Power:=-Exp(Y*Ln(-X)) Else Power:=Exp(Y*Ln(-X));
 End Else Power:=0;
End;

Function RealStr(X: Double; Dec: Integer): String;
Var S: String;
Begin
 Str(X:0:Dec,S);
 RealStr:=S;
End;

Function FileExists(Const N: String): Boolean;
Var F: File;
Begin
 {$I-}
 Assign(F,N);
 Reset(F,1);
 {$I+}
 If IOResult=0 Then Begin
  Close(F);
  FileExists:=True;
 End Else FileExists:=False;
End;

Function Rnd01: Double;
Begin
 Rnd01:=Random(10000)/10000;
End;

Function ShiftHeld: Boolean;
Begin
 {$IFNDEF FPC}
 ShiftHeld:=(Mem[$0040:$0017] And 3)<>0;
 {$ELSE}
 ShiftHeld:=False;
 {$ENDIF}
End;

Function CtrlHeld: Boolean;
Begin
 {$IFNDEF FPC}
 CtrlHeld:=(Mem[$0040:$0017] And 4)<>0;
 {$ELSE}
 CtrlHeld:=False;
 {$ENDIF}
End;

Function AltHeld: Boolean;
Begin
 {$IFNDEF FPC}
 AltHeld:=(Mem[$0040:$0017] And 8)<>0;
 {$ELSE}
 AltHeld:=False;
 {$ENDIF}
End;

Function FreeMemKB: LongInt;
Begin
 {$IFDEF FPC}
 FreeMemKB:=GetFPCHeapStatus.CurrHeapFree Div 1024;
 {$ELSE}
 FreeMemKB:=MemAvail Div 1024;
 {$ENDIF}
End;

Function Tick: LongInt;
Var H,M,S,S100: Word;
Begin
 GetTime(H,M,S,S100);
 Tick:=((LongInt(H)*60+M)*60+S)*100+S100;
End;

{ ---- unites et evaluation d'expressions avec unites ---- }

Function UnitName(U: Integer): String;
Begin
 Case U Of
  0: UnitName:='mm';
  1: UnitName:='cm';
  2: UnitName:='in';
  Else UnitName:='pt';
 End;
End;

Function UnitFactor(U: Integer): Double;     { mm par unite }
Begin
 Case U Of
  0: UnitFactor:=1;
  1: UnitFactor:=10;
  2: UnitFactor:=25.4;
  Else UnitFactor:=25.4/72;
 End;
End;

Function FmtLen(Mm: Double): String;
Var D: Integer;
Begin
 Case UnitIdx Of
  0: D:=1;
  1: D:=2;
  2: D:=3;
  Else D:=1;
 End;
 FmtLen:=RealStr(Mm/UnitFactor(UnitIdx),D)+UnitName(UnitIdx);
End;

Var
 EvS: String;
 EvP: Integer;
 EvOk: Boolean;

Type
 TUVal = Record V: Double; U: Boolean; End;

Procedure EvSkip;
Begin
 While (EvP<=Length(EvS)) And (EvS[EvP]=' ') Do Inc(EvP);
End;

Procedure EvExpr(Var R: TUVal); Forward;

Procedure EvFactor(Var R: TUVal);
Var S: String; V: Double; Code: Integer; Un: String; Neg: Boolean;
Begin
 R.V:=0; R.U:=False;
 EvSkip;
 Neg:=False;
 While (EvP<=Length(EvS)) And ((EvS[EvP]='-') Or (EvS[EvP]='+')) Do Begin
  If EvS[EvP]='-' Then Neg:=Not Neg;
  Inc(EvP);
  EvSkip;
 End;
 If (EvP<=Length(EvS)) And (EvS[EvP]='(') Then Begin
  Inc(EvP);
  EvExpr(R);
  EvSkip;
  If (EvP<=Length(EvS)) And (EvS[EvP]=')') Then Inc(EvP) Else EvOk:=False;
 End Else Begin
  S:='';
  While (EvP<=Length(EvS)) And (EvS[EvP] In ['0'..'9','.',',']) Do Begin
   If EvS[EvP]=',' Then S:=S+'.' Else S:=S+EvS[EvP];
   Inc(EvP);
  End;
  If S='' Then Begin EvOk:=False;Exit;End;
  Val(S,V,Code);
  If Code<>0 Then Begin EvOk:=False;Exit;End;
  EvSkip;
  Un:='';
  While (EvP<=Length(EvS)) And (UpCase(EvS[EvP]) In ['A'..'Z']) Do Begin
   Un:=Un+Lower(EvS[EvP]);
   Inc(EvP);
  End;
  R.V:=V;
  If Un='mm' Then R.U:=True
  Else If Un='cm' Then Begin R.V:=V*10;R.U:=True;End
  Else If (Un='in') Or (Un='inch') Then Begin R.V:=V*25.4;R.U:=True;End
  Else If Un='pt' Then Begin R.V:=V*25.4/72;R.U:=True;End
  Else If Un<>'' Then EvOk:=False;
 End;
 If Neg Then R.V:=-R.V;
End;

Procedure EvTerm(Var R: TUVal);
Var B: TUVal; Op: Char;
Begin
 EvFactor(R);
 Repeat
  EvSkip;
  If (EvP<=Length(EvS)) And ((EvS[EvP]='*') Or (EvS[EvP]='/')) Then Begin
   Op:=EvS[EvP];
   Inc(EvP);
   EvFactor(B);
   If Op='*' Then Begin
    R.V:=R.V*B.V;
    R.U:=R.U Or B.U;
   End Else Begin
    If B.V=0 Then Begin EvOk:=False;B.V:=1;End;
    R.V:=R.V/B.V;
    If R.U And B.U Then R.U:=False Else R.U:=R.U Or B.U;
   End;
  End Else Break;
 Until False;
End;

Procedure EvExpr(Var R: TUVal);
Var B: TUVal; Op: Char; F: Double;
Begin
 EvTerm(R);
 F:=UnitFactor(UnitIdx);
 Repeat
  EvSkip;
  If (EvP<=Length(EvS)) And ((EvS[EvP]='+') Or (EvS[EvP]='-')) Then Begin
   Op:=EvS[EvP];
   Inc(EvP);
   EvTerm(B);
   If Not R.U Then R.V:=R.V*F;
   If Not B.U Then B.V:=B.V*F;
   R.U:=True;
   If Op='+' Then R.V:=R.V+B.V Else R.V:=R.V-B.V;
  End Else Break;
 Until False;
End;

{ Convertit un texte (avec unites et operateurs) en millimetres }
Function ParseLen(Const S: String; Var Mm: Double): Boolean;
Var R: TUVal;
Begin
 EvS:=S;EvP:=1;EvOk:=True;
 If TrimStr(S)='' Then Begin ParseLen:=False;Exit;End;
 EvExpr(R);
 EvSkip;
 If EvP<=Length(EvS) Then EvOk:=False;
 If Not R.U Then R.V:=R.V*UnitFactor(UnitIdx);
 Mm:=R.V;
 ParseLen:=EvOk;
End;

Function ParseNum(Const S: String; Var X: Double): Boolean;
Var Code: Integer; T: String; I: Integer;
Begin
 T:=TrimStr(S);
 For I:=1 To Length(T) Do If T[I]=',' Then T[I]:='.';
 Val(T,X,Code);
 ParseNum:=(Code=0) And (T<>'');
End;

Function ShortName(Const N: String): String;
Var I,P: Integer;
Begin
 P:=0;
 For I:=1 To Length(N) Do If (N[I]='\') Or (N[I]='/') Then P:=I;
 ShortName:=Copy(N,P+1,255);
End;

Function AddExt(Const N,E: String): String;
Var I: Integer; Has: Boolean;
Begin
 Has:=False;
 For I:=1 To Length(N) Do Begin
  If (N[I]='\') Or (N[I]='/') Then Has:=False;
  If N[I]='.' Then Has:=True;
 End;
 If Has Then AddExt:=N Else AddExt:=N+'.'+E;
End;

Function ExtOf(Const N: String): String;
Var I,P: Integer;
Begin
 P:=0;
 For I:=1 To Length(N) Do Begin
  If (N[I]='\') Or (N[I]='/') Then P:=0;
  If N[I]='.' Then P:=I;
 End;
 If P=0 Then ExtOf:='' Else ExtOf:=Upper(Copy(N,P+1,10));
End;

Function SetExt(Const N,E: String): String;
Var I,P: Integer;
Begin
 P:=0;
 For I:=1 To Length(N) Do Begin
  If (N[I]='\') Or (N[I]='/') Then P:=0;
  If N[I]='.' Then P:=I;
 End;
 If P=0 Then SetExt:=N+'.'+E Else SetExt:=Copy(N,1,P-1)+'.'+E;
End;

{ ====================================================================== }
{                              COULEURS                                  }
{ ====================================================================== }

Const
 EgaRGB: Array[0..15,0..2] Of Byte = (
  (0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),
  (170,85,0),(170,170,170),(85,85,85),(85,85,255),(85,255,85),
  (85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255));

Function MkRGB(R,G,B: Integer): LongInt;
Begin
 MkRGB:=(LongInt(R) Shl 16) Or (LongInt(G) Shl 8) Or B;
End;

Function CR(C: LongInt): Integer;
Begin
 CR:=(C Shr 16) And 255;
End;

Function CG(C: LongInt): Integer;
Begin
 CG:=(C Shr 8) And 255;
End;

Function CB(C: LongInt): Integer;
Begin
 CB:=C And 255;
End;

Function PalRGB(I: Integer): LongInt;
Begin
 PalRGB:=MkRGB(EgaRGB[I,0],EgaRGB[I,1],EgaRGB[I,2]);
End;

Function NearestCol(C: LongInt): Integer;
Var I,Best: Integer; D,BD: LongInt; DR,DG,DB: LongInt;
Begin
 Best:=0;BD:=2000000000;
 For I:=0 To 15 Do Begin
  DR:=CR(C)-EgaRGB[I,0];DG:=CG(C)-EgaRGB[I,1];DB:=CB(C)-EgaRGB[I,2];
  D:=DR*DR*3+DG*DG*4+DB*DB*2;
  If D<BD Then Begin BD:=D;Best:=I;End;
 End;
 NearestCol:=Best;
End;

Procedure RGBtoHSV(C: LongInt; Var H,S,V: Integer);
Var R,G,B,Mx,Mn,D: Double; Hh: Double;
Begin
 R:=CR(C)/255;G:=CG(C)/255;B:=CB(C)/255;
 Mx:=MaxD(R,MaxD(G,B));Mn:=MinD(R,MinD(G,B));
 D:=Mx-Mn;
 V:=Round(Mx*100);
 If Mx=0 Then S:=0 Else S:=Round(D/Mx*100);
 If D=0 Then Hh:=0
 Else If Mx=R Then Hh:=(G-B)/D
 Else If Mx=G Then Hh:=2+(B-R)/D
 Else Hh:=4+(R-G)/D;
 Hh:=Hh*60;
 If Hh<0 Then Hh:=Hh+360;
 H:=Round(Hh) Mod 360;
End;

Function HSVtoRGB(H,S,V: Integer): LongInt;
Var Hh,F,P,Q,T,Vv,Ss: Double; I: Integer; R,G,B: Double;
Begin
 Vv:=V/100;Ss:=S/100;
 Hh:=(H Mod 360)/60;
 I:=Trunc(Hh);
 F:=Hh-I;
 P:=Vv*(1-Ss);Q:=Vv*(1-Ss*F);T:=Vv*(1-Ss*(1-F));
 Case I Of
  0: Begin R:=Vv;G:=T;B:=P;End;
  1: Begin R:=Q;G:=Vv;B:=P;End;
  2: Begin R:=P;G:=Vv;B:=T;End;
  3: Begin R:=P;G:=Q;B:=Vv;End;
  4: Begin R:=T;G:=P;B:=Vv;End;
  Else Begin R:=Vv;G:=P;B:=Q;End;
 End;
 HSVtoRGB:=MkRGB(Round(R*255),Round(G*255),Round(B*255));
End;

Function LerpCol(C1,C2: LongInt; T: Double): LongInt;
Begin
 LerpCol:=MkRGB(Round(CR(C1)+(CR(C2)-CR(C1))*T),
   Round(CG(C1)+(CG(C2)-CG(C1))*T),Round(CB(C1)+(CB(C2)-CB(C1))*T));
End;

{ ====================================================================== }
{                        PRIMITIVES GRAPHIQUES                           }
{ ====================================================================== }

Type
 TPat = Array[0..7] Of Byte;

Const
 NPAT = 24;
 FillPats: Array[1..NPAT] Of TPat = (
  ($FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF),
  ($80,$00,$08,$00,$80,$00,$08,$00),
  ($88,$22,$88,$22,$88,$22,$88,$22),
  ($AA,$55,$AA,$55,$AA,$55,$AA,$55),
  ($77,$DD,$77,$DD,$77,$DD,$77,$DD),
  ($FF,$00,$00,$00,$FF,$00,$00,$00),
  ($FF,$00,$FF,$00,$FF,$00,$FF,$00),
  ($FF,$FF,$00,$FF,$FF,$00,$FF,$FF),
  ($88,$88,$88,$88,$88,$88,$88,$88),
  ($AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA),
  ($EE,$EE,$EE,$EE,$EE,$EE,$EE,$EE),
  ($80,$40,$20,$10,$08,$04,$02,$01),
  ($88,$44,$22,$11,$88,$44,$22,$11),
  ($CC,$66,$33,$99,$CC,$66,$33,$99),
  ($01,$02,$04,$08,$10,$20,$40,$80),
  ($11,$22,$44,$88,$11,$22,$44,$88),
  ($33,$66,$CC,$99,$33,$66,$CC,$99),
  ($FF,$88,$88,$88,$FF,$88,$88,$88),
  ($81,$42,$24,$18,$18,$24,$42,$81),
  ($FF,$80,$80,$80,$80,$80,$80,$80),
  ($F8,$74,$22,$47,$8F,$17,$22,$71),
  ($FF,$80,$80,$80,$FF,$08,$08,$08),
  ($18,$18,$18,$FF,$FF,$18,$18,$18),
  ($3C,$7E,$FF,$FF,$FF,$FF,$7E,$3C));
 Bayer: Array[0..7,0..7] Of Byte = (
  (0,32,8,40,2,34,10,42),(48,16,56,24,50,18,58,26),
  (12,44,4,36,14,46,6,38),(60,28,52,20,62,30,54,22),
  (3,35,11,43,1,33,9,41),(51,19,59,27,49,17,57,25),
  (15,47,7,39,13,45,5,37),(63,31,55,23,61,29,53,21));
 LinePat: Array[0..6] Of Word = ($FFFF,$F0F0,$AAAA,$E4E4,$FC30,$CCCC,$FF18);

Procedure Box(X1,Y1,X2,Y2,C: Integer);
Begin
 SetFillStyle(SolidFill,C);
 Bar(X1,Y1,X2,Y2);
End;

Procedure Frame(X1,Y1,X2,Y2: Integer);
Begin
 SetColor(INK);
 SetLineStyle(SolidLn,0,1);
 Rectangle(X1,Y1,X2,Y2);
End;

Procedure PText(X,Y: Integer; Const S: String);
Begin
 SetColor(INK);
 OutTextXY(X,Y,S);
End;

Procedure CText(X,Y: Integer; C: Integer; Const S: String);
Begin
 SetColor(C);
 OutTextXY(X,Y,S);
End;

Procedure BText(X,Y: Integer; Const S: String);
Begin
 SetColor(INK);
 OutTextXY(X,Y,S);
 OutTextXY(X+1,Y,S);
End;

Procedure WText(X,Y: Integer; Const S: String);
Begin
 SetColor(PAPER);
 OutTextXY(X,Y,S);
End;

Procedure GreyText(X,Y: Integer; Const S: String);
Begin
 SetColor(8);
 OutTextXY(X,Y,S);
End;

Function TextW(Const S: String): Integer;
Begin
 TextW:=Length(S)*8;
End;

Function InBox(X,Y,X1,Y1,X2,Y2: LongInt): Boolean;
Begin
 InBox:=(X>=X1) And (X<=X2) And (Y>=Y1) And (Y<=Y2);
End;

Procedure Bevel(X1,Y1,X2,Y2: Integer; Down: Boolean);
Begin
 SetLineStyle(SolidLn,0,1);
 If Down Then SetColor(8) Else SetColor(15);
 Line(X1,Y1,X2-1,Y1);Line(X1,Y1,X1,Y2-1);
 If Down Then SetColor(15) Else SetColor(8);
 Line(X2,Y1,X2,Y2);Line(X1,Y2,X2,Y2);
End;

Procedure Button(X1,Y1,X2,Y2: Integer; Const S: String; Hot,Enabled: Boolean);
Var TX: Integer;
Begin
 Box(X1,Y1,X2,Y2,CHROME);
 Frame(X1,Y1,X2,Y2);
 If Hot Then Begin
  Frame(X1+1,Y1+1,X2-1,Y2-1);
 End Else Bevel(X1+1,Y1+1,X2-1,Y2-1,False);
 TX:=(X1+X2+1-TextW(S)) Div 2;
 If Enabled Then PText(TX,(Y1+Y2-6) Div 2,S) Else GreyText(TX,(Y1+Y2-6) Div 2,S);
End;

Procedure DotLine(X1,Y1,X2,Y2,C: Integer);
Begin
 SetColor(C);
 SetLineStyle(UserBitLn,$AAAA,1);
 Line(X1,Y1,X2,Y2);
 SetLineStyle(SolidLn,0,1);
End;

{ ---- capture de la police 8x8 par defaut ---- }
Procedure CaptureFont;
Var C,R,X: Integer; B: Byte; S: String;
Begin
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 SetTextStyle(DefaultFont,HorizDir,1);
 For C:=0 To 255 Do Begin
  Box(0,0,15,15,0);
  If C=0 Then S:=' ' Else S:=Chr(C);
  SetColor(15);
  OutTextXY(0,0,S);
  For R:=0 To 7 Do Begin
   B:=0;
   For X:=0 To 7 Do
    If GetPixel(X,R)<>0 Then B:=B Or (128 Shr X);
   FontBits[C,R]:=B;
  End;
 End;
 Box(0,0,SCR_W-1,SCR_H-1,0);
End;

{ ====================================================================== }
{                     GESTION DES OBJETS (modele)                        }
{ ====================================================================== }

Var
 TmpNd: PNodeArr;
 PrevO: TObj;
 FlatSc: Double;
 FtL: Array[1..60] Of String[100];
 FtS: Array[1..60] Of String[100];
 FtA: Array[1..60] Of Byte;
 FtN: Integer;

Function TxtOf(O: PObj): String;
Begin
 If O^.Txt=Nil Then TxtOf:='' Else TxtOf:=O^.Txt^;
End;

Procedure SetTxt(O: PObj; Const S: String);
Begin
 If O^.Txt<>Nil Then Begin FreeMem(O^.Txt,Length(O^.Txt^)+1);O^.Txt:=Nil;End;
 If S<>'' Then Begin
  GetMem(O^.Txt,Length(S)+1);
  O^.Txt^:=S;
 End;
End;

Procedure InitObj(Var O: TObj; K: Byte);
Begin
 FillChar(O,SizeOf(O),0);
 O.Kind:=K;
 O.Layer:=CurLayer;O.Page:=CurPage;
 O.LineCol:=CurLineCol;O.FillCol:=CurFillCol;O.ShCol:=CurShCol;
 O.LineW:=CurLineW;O.LineSty:=CurLineSty;O.EndS:=CurEndS;O.EndE:=CurEndE;
 O.FillMode:=CurFillMode;O.FillPat:=CurFillPat;O.Grey:=CurGrey;
 O.ShOn:=CurShOn;O.ShDX:=CurShDX;O.ShDY:=CurShDY;
 O.FSize:=CurFSize;O.TFlags:=CurTFlags;O.TAlign:=CurTAlign;O.Rad:=3;
 O.Closed:=(K In [OK_RECT,OK_RRECT,OK_TRI,OK_PARA,OK_NGON,OK_CIRCLE,
   OK_ELLIPSE]);
 If K In [OK_LINE,OK_POLY,OK_BEZIER,OK_SPLINE,OK_FREE,OK_ARC,OK_EARC,
   OK_TEXT,OK_FTEXT,OK_BITMAP] Then Begin
  If K In [OK_LINE,OK_BEZIER,OK_SPLINE,OK_FREE,OK_ARC,OK_EARC] Then
    O.FillMode:=0;
  If K In [OK_TEXT] Then O.FillMode:=0;
 End;
 If K In [OK_FTEXT,OK_BITMAP] Then O.FillMode:=0;
End;

Procedure SetCap(O: PObj; NewCap: Integer);
Var P: PNodeArr;
Begin
 If NewCap<=O^.Cap Then Exit;
 GetMem(P,NewCap*SizeOf(TNode));
 FillChar(P^,NewCap*SizeOf(TNode),0);
 If O^.Nd<>Nil Then Begin
  Move(O^.Nd^,P^,O^.N*SizeOf(TNode));
  FreeMem(O^.Nd,O^.Cap*SizeOf(TNode));
 End;
 O^.Nd:=P;O^.Cap:=NewCap;
End;

Procedure FreeObj(P: PObj);
Begin
 If P=Nil Then Exit;
 If P^.Nd<>Nil Then FreeMem(P^.Nd,P^.Cap*SizeOf(TNode));
 If P^.Txt<>Nil Then FreeMem(P^.Txt,Length(P^.Txt^)+1);
 If P^.BPix<>Nil Then FreeMem(P^.BPix,P^.BW*P^.BH);
 Dispose(P);
End;

{ Copie profonde d'un enregistrement vers un nouvel objet du tas }
Function CloneRec(Const T: TObj): PObj;
Var P: PObj;
Begin
 New(P);
 P^:=T;
 P^.Nd:=Nil;P^.Cap:=0;P^.Txt:=Nil;P^.BPix:=Nil;
 SetCap(P,T.N+4);
 If T.N>0 Then Move(T.Nd^,P^.Nd^,T.N*SizeOf(TNode));
 P^.N:=T.N;
 If T.Txt<>Nil Then SetTxt(P,T.Txt^);
 If T.BPix<>Nil Then Begin
  GetMem(P^.BPix,T.BW*T.BH);
  Move(T.BPix^,P^.BPix^,T.BW*T.BH);
 End;
 P^.Sel:=False;
 CloneRec:=P;
End;

Function AddObjRec(Const T: TObj): PObj;
Var P: PObj;
Begin
 AddObjRec:=Nil;
 If NObj>=MAXOBJ Then Exit;
 P:=CloneRec(T);
 Inc(NObj);
 Objs[NObj]:=P;
 AddObjRec:=P;
End;

Procedure DelObjAt(I: Integer);
Var K: Integer;
Begin
 If (I<1) Or (I>NObj) Then Exit;
 If Objs[I]=MarkObj Then MarkObj:=Nil;
 If Objs[I]=PathObj Then PathObj:=Nil;
 If Objs[I]=EditObj Then EditObj:=Nil;
 FreeObj(Objs[I]);
 For K:=I To NObj-1 Do Objs[K]:=Objs[K+1];
 Dec(NObj);
End;

Procedure ClearDoc;
Begin
 While NObj>0 Do DelObjAt(NObj);
 PathObj:=Nil;MarkObj:=Nil;EditObj:=Nil;
End;

Function IndexOfObj(P: PObj): Integer;
Var I: Integer;
Begin
 IndexOfObj:=0;
 For I:=1 To NObj Do If Objs[I]=P Then IndexOfObj:=I;
End;

Function ObjVisible(O: PObj): Boolean;
Begin
 ObjVisible:=(O^.Page=CurPage) And Not Layers[O^.Layer].Hidden;
End;

Function ObjLocked(O: PObj): Boolean;
Begin
 ObjLocked:=O^.Locked Or Layers[O^.Layer].Locked;
End;

Function IsPathKind(K: Byte): Boolean;
Begin
 IsPathKind:=K In [OK_LINE,OK_POLY,OK_TRI,OK_PARA,OK_BEZIER,OK_SPLINE,OK_NGON,
   OK_FREE,OK_COMPOUND,OK_RECT,OK_RRECT];
End;

Function IsFilledKind(K: Byte): Boolean;
Begin
 IsFilledKind:=K In [OK_RECT,OK_RRECT,OK_TRI,OK_PARA,OK_CIRCLE,OK_ELLIPSE,
   OK_NGON,OK_POLY,OK_COMPOUND,OK_BEZIER,OK_SPLINE,OK_FREE,OK_ARC,OK_EARC];
End;

{ ---- aplatissement des objets en polylignes (coordonnees monde) ---- }

Procedure PushPt(X,Y: Double);
Begin
 If FN<MAXPT Then Begin
  FP^[FN].X:=X;FP^[FN].Y:=Y;
  Inc(FN);
 End;
End;

Procedure SubBegin;
Begin
 If NSub<MAXSUB Then Begin
  SubS[NSub]:=FN;SubC[NSub]:=False;
  Inc(NSub);
 End;
End;

Procedure SubEnd(Closed: Boolean);
Begin
 If NSub>0 Then SubC[NSub-1]:=Closed;
End;

Procedure FlatBez(X0,Y0,X1,Y1,X2,Y2,X3,Y3: Double);
Var I,Steps: Integer; L,T,U,A,B,C,D: Double;
Begin
 L:=(Hypot(X1-X0,Y1-Y0)+Hypot(X2-X1,Y2-Y1)+Hypot(X3-X2,Y3-Y2))*FlatSc;
 Steps:=Clamp(Trunc(L/7)+4,6,48);
 For I:=1 To Steps Do Begin
  T:=I/Steps;U:=1-T;
  A:=U*U*U;B:=3*U*U*T;C:=3*U*T*T;D:=T*T*T;
  PushPt(A*X0+B*X1+C*X2+D*X3,A*Y0+B*Y1+C*Y2+D*Y3);
 End;
End;

Procedure FlatEllipse(CX,CY,AX,AY,BX,BY,T1,T2: Double);
Var I,Steps: Integer; R,T,Span: Double;
Begin
 R:=MaxD(Hypot(AX,AY),Hypot(BX,BY))*FlatSc;
 Steps:=Clamp(Trunc(R/2.5)+14,18,150);
 Span:=T2-T1;
 Steps:=Clamp(Trunc(Steps*Abs(Span)/(2*Pi))+2,4,160);
 For I:=0 To Steps Do Begin
  T:=T1+Span*I/Steps;
  PushPt(CX+AX*Cos(T)+BX*Sin(T),CY+AY*Cos(T)+BY*Sin(T));
 End;
End;

Procedure FlatPath(O: PObj);
Var I,J,Last: Integer; SX0,SY0: Double; Comp: Boolean;
Begin
 If O^.N<2 Then Begin
  If O^.N=1 Then Begin SubBegin;PushPt(O^.Nd^[0].X,O^.Nd^[0].Y);SubEnd(False);End;
  Exit;
 End;
 Comp:=(O^.Kind=OK_COMPOUND);
 SubBegin;
 SX0:=O^.Nd^[0].X;SY0:=O^.Nd^[0].Y;
 PushPt(SX0,SY0);
 If O^.Closed Then Last:=O^.N-1 Else Last:=O^.N-2;
 For I:=0 To Last Do Begin
  J:=(I+1) Mod O^.N;
  Case O^.Nd^[I].Kind Of
   1: FlatBez(O^.Nd^[I].X,O^.Nd^[I].Y,O^.Nd^[I].AX,O^.Nd^[I].AY,
        O^.Nd^[J].BX,O^.Nd^[J].BY,O^.Nd^[J].X,O^.Nd^[J].Y);
   2: Begin
       If Comp Then Begin PushPt(SX0,SY0);SubEnd(True);End
       Else SubEnd(False);
       SubBegin;
       SX0:=O^.Nd^[J].X;SY0:=O^.Nd^[J].Y;
       PushPt(SX0,SY0);
      End;
   Else PushPt(O^.Nd^[J].X,O^.Nd^[J].Y);
  End;
 End;
 If Comp Then Begin PushPt(SX0,SY0);SubEnd(True);End
 Else SubEnd(O^.Closed);
End;

Procedure FlatRRect(O: PObj);
Var I,K: Integer; P0,P1,P2: TPt; L1,L2,R,Ux,Uy,Vx,Vy,SX,SY,EX,EY,T: Double;
Begin
 SubBegin;
 For I:=0 To 3 Do Begin
  P1.X:=O^.Nd^[I].X;P1.Y:=O^.Nd^[I].Y;
  P0.X:=O^.Nd^[(I+3) Mod 4].X;P0.Y:=O^.Nd^[(I+3) Mod 4].Y;
  P2.X:=O^.Nd^[(I+1) Mod 4].X;P2.Y:=O^.Nd^[(I+1) Mod 4].Y;
  L1:=Hypot(P0.X-P1.X,P0.Y-P1.Y);L2:=Hypot(P2.X-P1.X,P2.Y-P1.Y);
  R:=MinD(O^.Rad,MinD(L1,L2)/2);
  If (L1<0.001) Or (L2<0.001) Then Begin PushPt(P1.X,P1.Y);Continue;End;
  Ux:=(P0.X-P1.X)/L1;Uy:=(P0.Y-P1.Y)/L1;
  Vx:=(P2.X-P1.X)/L2;Vy:=(P2.Y-P1.Y)/L2;
  SX:=P1.X+Ux*R;SY:=P1.Y+Uy*R;
  EX:=P1.X+Vx*R;EY:=P1.Y+Vy*R;
  For K:=0 To 6 Do Begin
   T:=K/6;
   PushPt((1-T)*(1-T)*SX+2*T*(1-T)*P1.X+T*T*EX,
          (1-T)*(1-T)*SY+2*T*(1-T)*P1.Y+T*T*EY);
  End;
 End;
 PushPt(FP^[SubS[NSub-1]].X,FP^[SubS[NSub-1]].Y);
 SubEnd(True);
End;

Procedure GetTextExtent(O: PObj; Var Cols,Rows: Integer);
Var S: String; I,L: Integer;
Begin
 S:=TxtOf(O);
 Cols:=0;Rows:=1;L:=0;
 For I:=1 To Length(S) Do Begin
  If S[I]=#10 Then Begin
   If L>Cols Then Cols:=L;
   L:=0;Inc(Rows);
  End Else Inc(L);
 End;
 If L>Cols Then Cols:=L;
 If Cols<1 Then Cols:=1;
End;

Procedure FlatBox4(O: PObj);
Begin
 SubBegin;
 PushPt(O^.Nd^[0].X,O^.Nd^[0].Y);PushPt(O^.Nd^[1].X,O^.Nd^[1].Y);
 PushPt(O^.Nd^[2].X,O^.Nd^[2].Y);PushPt(O^.Nd^[3].X,O^.Nd^[3].Y);
 PushPt(O^.Nd^[0].X,O^.Nd^[0].Y);
 SubEnd(True);
End;

Procedure FlattenObj(O: PObj; StepSc: Double);
Var CX,CY,AX,AY,BX,BY,T1,T2: Double; Cols,Rows: Integer;
Begin
 FlatSc:=StepSc;
 FN:=0;NSub:=0;
 Case O^.Kind Of
  OK_RRECT: FlatRRect(O);
  OK_CIRCLE,OK_ELLIPSE,OK_ARC,OK_EARC: Begin
   CX:=O^.Nd^[0].X;CY:=O^.Nd^[0].Y;
   AX:=O^.Nd^[1].X-CX;AY:=O^.Nd^[1].Y-CY;
   BX:=O^.Nd^[2].X-CX;BY:=O^.Nd^[2].Y-CY;
   SubBegin;
   If O^.Kind In [OK_ARC,OK_EARC] Then Begin
    T1:=O^.A1*Pi/180;T2:=O^.A2*Pi/180;
    If T2<=T1 Then T2:=T2+2*Pi;
    FlatEllipse(CX,CY,AX,AY,BX,BY,T1,T2);
    SubEnd(False);
   End Else Begin
    FlatEllipse(CX,CY,AX,AY,BX,BY,0,2*Pi);
    SubEnd(True);
   End;
  End;
  OK_TEXT: Begin
   GetTextExtent(O,Cols,Rows);
   AX:=O^.Nd^[1].X-O^.Nd^[0].X;AY:=O^.Nd^[1].Y-O^.Nd^[0].Y;
   BX:=O^.Nd^[2].X-O^.Nd^[0].X;BY:=O^.Nd^[2].Y-O^.Nd^[0].Y;
   SubBegin;
   PushPt(O^.Nd^[0].X,O^.Nd^[0].Y);
   PushPt(O^.Nd^[0].X+AX*Cols,O^.Nd^[0].Y+AY*Cols);
   PushPt(O^.Nd^[0].X+AX*Cols+BX*Rows*1.25,O^.Nd^[0].Y+AY*Cols+BY*Rows*1.25);
   PushPt(O^.Nd^[0].X+BX*Rows*1.25,O^.Nd^[0].Y+BY*Rows*1.25);
   PushPt(O^.Nd^[0].X,O^.Nd^[0].Y);
   SubEnd(True);
  End;
  OK_FTEXT,OK_BITMAP: FlatBox4(O);
  Else FlatPath(O);
 End;
 SubS[NSub]:=FN;
End;

Procedure ObjBBox(O: PObj; Var X1,Y1,X2,Y2: Double);
Var I: Integer;
Begin
 FlattenObj(O,1);
 X1:=1E30;Y1:=1E30;X2:=-1E30;Y2:=-1E30;
 For I:=0 To FN-1 Do Begin
  If FP^[I].X<X1 Then X1:=FP^[I].X;
  If FP^[I].X>X2 Then X2:=FP^[I].X;
  If FP^[I].Y<Y1 Then Y1:=FP^[I].Y;
  If FP^[I].Y>Y2 Then Y2:=FP^[I].Y;
 End;
 If FN=0 Then Begin X1:=0;Y1:=0;X2:=0;Y2:=0;End;
End;

Function CountSel: Integer;
Var I,C: Integer;
Begin
 C:=0;
 For I:=1 To NObj Do If Objs[I]^.Sel Then Inc(C);
 CountSel:=C;
End;

Function FirstSel: PObj;
Var I: Integer;
Begin
 FirstSel:=Nil;
 For I:=1 To NObj Do If Objs[I]^.Sel Then Begin FirstSel:=Objs[I];Exit;End;
End;

Function SelBBox: Boolean;
Var I: Integer; X1,Y1,X2,Y2: Double; Any: Boolean;
Begin
 Any:=False;
 SelBX1:=1E30;SelBY1:=1E30;SelBX2:=-1E30;SelBY2:=-1E30;
 For I:=1 To NObj Do
  If Objs[I]^.Sel And ObjVisible(Objs[I]) Then Begin
   ObjBBox(Objs[I],X1,Y1,X2,Y2);
   If X1<SelBX1 Then SelBX1:=X1;
   If Y1<SelBY1 Then SelBY1:=Y1;
   If X2>SelBX2 Then SelBX2:=X2;
   If Y2>SelBY2 Then SelBY2:=Y2;
   Any:=True;
  End;
 SelBBox:=Any;
End;

Procedure DeselectAll;
Var I: Integer;
Begin
 For I:=1 To NObj Do Objs[I]^.Sel:=False;
 RotMode:=False;
End;

Procedure XNew(Var X,Y: Double; A,B,C,D,E,F: Double);
Var T: Double;
Begin
 T:=A*X+C*Y+E;
 Y:=B*X+D*Y+F;
 X:=T;
End;

Procedure XformObj(O: PObj; A,B,C,D,E,F: Double);
Var I: Integer; Det: Double;
Begin
 For I:=0 To O^.N-1 Do
  With O^.Nd^[I] Do Begin
   XNew(X,Y,A,B,C,D,E,F);
   XNew(AX,AY,A,B,C,D,E,F);
   XNew(BX,BY,A,B,C,D,E,F);
  End;
 Det:=Abs(A*D-B*C);
 If Det>0 Then O^.Rad:=O^.Rad*Sqrt(Det);
End;

{ ====================================================================== }
{                  GEOMETRIE : TESTS DE SELECTION, ETC.                  }
{ ====================================================================== }

Function DistSeg(PX,PY,X1,Y1,X2,Y2: Double): Double;
Var DX,DY,L2v,T: Double;
Begin
 DX:=X2-X1;DY:=Y2-Y1;
 L2v:=DX*DX+DY*DY;
 If L2v<1E-9 Then Begin DistSeg:=Hypot(PX-X1,PY-Y1);Exit;End;
 T:=((PX-X1)*DX+(PY-Y1)*DY)/L2v;
 If T<0 Then T:=0;
 If T>1 Then T:=1;
 DistSeg:=Hypot(PX-(X1+T*DX),PY-(Y1+T*DY));
End;

{ Point dans les sous-chemins aplatis (regle pair/impair) }
Function InsideFlat(PX,PY: Double): Boolean;
Var S,I,J,A,B: Integer; In1: Boolean;
Begin
 In1:=False;
 For S:=0 To NSub-1 Do Begin
  A:=SubS[S];B:=SubS[S+1]-1;
  If B>A Then Begin
   J:=B;
   For I:=A To B Do Begin
    If ((FP^[I].Y>PY)<>(FP^[J].Y>PY)) Then
     If PX<(FP^[J].X-FP^[I].X)*(PY-FP^[I].Y)/(FP^[J].Y-FP^[I].Y)+FP^[I].X
       Then In1:=Not In1;
    J:=I;
   End;
  End;
 End;
 InsideFlat:=In1;
End;

Function NearFlatEdge(PX,PY,Tol: Double): Boolean;
Var S,I: Integer;
Begin
 NearFlatEdge:=False;
 For S:=0 To NSub-1 Do
  For I:=SubS[S] To SubS[S+1]-2 Do
   If DistSeg(PX,PY,FP^[I].X,FP^[I].Y,FP^[I+1].X,FP^[I+1].Y)<=Tol Then Begin
    NearFlatEdge:=True;Exit;End;
End;

Function HitObj(O: PObj; WX,WY,Tol: Double): Boolean;
Var T: Double;
Begin
 HitObj:=False;
 FlattenObj(O,Sc);
 T:=MaxD(Tol,O^.LineW/2);
 If O^.Kind In [OK_TEXT,OK_FTEXT,OK_BITMAP] Then Begin
  HitObj:=InsideFlat(WX,WY) Or NearFlatEdge(WX,WY,T);
  Exit;
 End;
 If NearFlatEdge(WX,WY,T) Then Begin HitObj:=True;Exit;End;
 If (O^.FillMode<>0) And IsFilledKind(O^.Kind) Then
   If InsideFlat(WX,WY) Then HitObj:=True;
End;

Function GroupMembers(G: Integer): Integer;
Var I,C: Integer;
Begin
 C:=0;
 For I:=1 To NObj Do If Objs[I]^.Group=G Then Inc(C);
 GroupMembers:=C;
End;

Procedure SelectWithGroup(O: PObj; V: Boolean);
Var I: Integer;
Begin
 O^.Sel:=V;
 If O^.Group<>0 Then
  For I:=1 To NObj Do
   If Objs[I]^.Group=O^.Group Then Objs[I]^.Sel:=V;
End;

Function TopObjAt(WX,WY: Double; Cycle: Boolean; Force: Boolean): PObj;
Var I,Start: Integer; Tol: Double; Hits: Array[1..40] Of PObj; NH,K: Integer;
 CurIdx: Integer;
Begin
 TopObjAt:=Nil;
 Tol:=4/Sc;
 NH:=0;
 For I:=NObj DownTo 1 Do
  If ObjVisible(Objs[I]) And (Force Or Not ObjLocked(Objs[I])) Then
   If HitObj(Objs[I],WX,WY,Tol) Then Begin
    If NH<40 Then Begin Inc(NH);Hits[NH]:=Objs[I];End;
   End;
 If NH=0 Then Exit;
 TopObjAt:=Hits[1];
 If Cycle And (CountSel=1) Then
  For K:=1 To NH Do
   If Hits[K]^.Sel Then Begin
    If K<NH Then TopObjAt:=Hits[K+1] Else TopObjAt:=Hits[1];
    Exit;
   End;
End;

{ ====================================================================== }
{                      MISE EN PAGE DU TEXTE CADRE                       }
{ ====================================================================== }

{ Les lignes de FtL contiennent le texte a afficher, FtS les styles de chaque
  caractere (bit0 gras, bit1 souligne, bit2 italique, bit3 contour) et FtA
  l'alignement (0 gauche, 1 droite, 2 justifie, 3 centre) }
Procedure LayoutFrame(O: PObj; MaxCols: Integer);
Var Src: String; I: Integer; Ch: Char; Mode: Char; Sty: Byte;
 Cur,CurS: String; Words: Array[1..60] Of String[60];
 WStyles: Array[1..60] Of String[60]; NW: Integer; WCur,WSt: String;
 Bold,Und,Ita,Outl: Boolean;
 Wrap: Boolean; Al: Byte;

 Procedure FlushLine(A: Byte);
 Begin
  If FtN<60 Then Begin
   Inc(FtN);FtL[FtN]:=Cur;FtS[FtN]:=CurS;FtA[FtN]:=A;
  End;
  Cur:='';CurS:='';
 End;

 Function StyleByte: Byte;
 Var B: Byte;
 Begin
  B:=0;
  If Bold Then B:=B Or 1;
  If Und Then B:=B Or 2;
  If Ita Then B:=B Or 4;
  If Outl Then B:=B Or 8;
  StyleByte:=B;
 End;

 Procedure EndWord;
 Begin
  If WCur<>'' Then Begin
   If NW<60 Then Begin Inc(NW);Words[NW]:=WCur;WStyles[NW]:=WSt;End;
   WCur:='';WSt:='';
  End;
 End;

 Procedure Justify;
 Var Need,I,P,Gaps: Integer;
 Begin
  Need:=MaxCols-Length(Cur);
  Gaps:=0;
  For I:=1 To Length(Cur) Do If Cur[I]=' ' Then Inc(Gaps);
  If (Need<=0) Or (Gaps=0) Then Exit;
  P:=1;
  While (Need>0) And (Length(Cur)<100) Do Begin
   While (P<=Length(Cur)) And (Cur[P]<>' ') Do Inc(P);
   If P>Length(Cur) Then P:=1
   Else Begin
    Insert(' ',Cur,P);
    Insert(#0,CurS,P);
    Dec(Need);
    P:=P+2;
   End;
  End;
 End;

 Procedure FlushPara;
 Var K: Integer;
 Begin
  EndWord;
  Cur:='';CurS:='';
  For K:=1 To NW Do Begin
   If (Cur<>'') And (Length(Cur)+1+Length(Words[K])>MaxCols) Then Begin
    Case Al Of
     2: Begin Justify;FlushLine(0);End;
     1: FlushLine(1);
     Else FlushLine(0);
    End;
   End;
   If Cur<>'' Then Begin Cur:=Cur+' ';CurS:=CurS+#0;End;
   Cur:=Cur+Words[K];CurS:=CurS+WStyles[K];
  End;
  If Al=1 Then FlushLine(1) Else FlushLine(0);
  NW:=0;
 End;

Begin
 FtN:=0;
 Src:=TxtOf(O);
 Mode:='k';Bold:=False;Und:=False;Ita:=False;Outl:=False;
 Wrap:=False;Al:=0;NW:=0;WCur:='';WSt:='';Cur:='';CurS:='';
 { detection du mode de formatage }
 I:=1;
 While I<=Length(Src) Do Begin
  If (Src[I]='\') And (I<Length(Src)) Then Begin
   Ch:=Src[I+1];
   Case Ch Of
    'l','r','b','c': Wrap:=True;
   End;
   Inc(I,2);
  End Else Inc(I);
 End;
 I:=1;
 While I<=Length(Src) Do Begin
  Ch:=Src[I];
  If (Ch='\') And (I<Length(Src)) Then Begin
   Ch:=Src[I+1];
   Inc(I,2);
   Case Ch Of
    'k': Begin If Wrap Then FlushPara Else FlushLine(0);Wrap:=False;Al:=0;End;
    'l': Begin Wrap:=True;Al:=0;End;
    'r': Begin Wrap:=True;Al:=1;End;
    'b': Begin Wrap:=True;Al:=0;End;
    'c': Begin Wrap:=True;Al:=2;End;
    'n': If Wrap Then FlushPara Else FlushLine(Al);
    'f','h','u','o','i','t','g': Begin
      If (I<=Length(Src)) And (Src[I] In ['+','-']) Then Begin
       Case Ch Of
        'f': Bold:=(Src[I]='+');
        'u': Und:=(Src[I]='+');
        'i': Ita:=(Src[I]='+');
        'o': Outl:=(Src[I]='+');
       End;
       Inc(I);
      End;
     End;
    'z': Begin
      While (I<=Length(Src)) And (Src[I]<>'}') And (Src[I]<>' ') Do Inc(I);
      If (I<=Length(Src)) And (Src[I]='}') Then Inc(I);
     End;
    '\': Begin WCur:=WCur+'\';WSt:=WSt+Chr(StyleByte);End;
   End;
  End Else Begin
   If (Ch=#10) Or (Ch=#13) Then Begin
    If Ch=#10 Then Begin
     If Wrap Then FlushPara Else FlushLine(Al);
    End;
   End Else If Ch=' ' Then Begin
    If Wrap Then EndWord Else Begin
     Cur:=Cur+' ';CurS:=CurS+Chr(StyleByte);
    End;
   End Else Begin
    If Wrap Then Begin WCur:=WCur+Ch;WSt:=WSt+Chr(StyleByte);End
    Else Begin
     If Length(Cur)<100 Then Begin Cur:=Cur+Ch;CurS:=CurS+Chr(StyleByte);End;
    End;
   End;
   Inc(I);
  End;
 End;
 If Wrap Then FlushPara Else If (Cur<>'') Or (FtN=0) Then FlushLine(Al);
End;

{ ====================================================================== }
{                      RENDU : REMPLISSAGE, TRAITS                       }
{ ====================================================================== }

Var
 XS: Array[0..600] Of Integer;
 CvW,CvH: Integer;

Procedure BuildGreyPat(G: Integer; Var P: TPat);
Var R,C: Integer; B: Byte; Lv: Integer;
Begin
 Lv:=G*64 Div 256;
 For R:=0 To 7 Do Begin
  B:=0;
  For C:=0 To 7 Do
   If Bayer[R,C]<Lv Then B:=B Or (128 Shr C);
  P[R]:=B;
 End;
End;

{ Remplissage par balayage (pair/impair) des sous-chemins de SP }
Procedure FillScan(Solid: Boolean; Const Pat: TPat; Col: Integer);
Var Y,YMin,YMax,S,I,J,A,B,N,X1,X,X2,T,K: Integer; Y1,Y2: Integer; Bits: Byte;
Begin
 If FN<3 Then Exit;
 YMin:=32000;YMax:=-32000;
 For I:=0 To FN-1 Do Begin
  If SP^[I].Y<YMin Then YMin:=SP^[I].Y;
  If SP^[I].Y>YMax Then YMax:=SP^[I].Y;
 End;
 If YMin<0 Then YMin:=0;
 If YMax>CvH-1 Then YMax:=CvH-1;
 SetColor(Col);
 SetLineStyle(SolidLn,0,1);
 For Y:=YMin To YMax Do Begin
  N:=0;
  For S:=0 To NSub-1 Do Begin
   A:=SubS[S];B:=SubS[S+1]-1;
   If B>A Then Begin
    J:=B;
    For I:=A To B Do Begin
     Y1:=SP^[J].Y;Y2:=SP^[I].Y;
     If ((Y1<=Y) And (Y<Y2)) Or ((Y2<=Y) And (Y<Y1)) Then
      If N<600 Then Begin
       XS[N]:=SP^[J].X+Round((Y-Y1)*(SP^[I].X-SP^[J].X)/(Y2-Y1));
       Inc(N);
      End;
     J:=I;
    End;
   End;
  End;
  For I:=1 To N-1 Do Begin
   T:=XS[I];J:=I-1;
   While (J>=0) And (XS[J]>T) Do Begin XS[J+1]:=XS[J];Dec(J);End;
   XS[J+1]:=T;
  End;
  I:=0;
  While I+1<N Do Begin
   X1:=XS[I];X2:=XS[I+1]-1;
   If X1<0 Then X1:=0;
   If X2>CvW-1 Then X2:=CvW-1;
   If X2>=X1 Then Begin
    If Solid Then Line(X1,Y,X2,Y)
    Else Begin
     Bits:=Pat[Y And 7];
     If Bits<>0 Then
      For X:=X1 To X2 Do
       If ((Bits Shr (7-(X And 7))) And 1)<>0 Then PutPixel(X,Y,Col);
    End;
   End;
   Inc(I,2);
  End;
 End;
End;

Procedure ObjToScreen(DX,DY: Double);
Var I: Integer;
Begin
 For I:=0 To FN-1 Do Begin
  SP^[I].X:=ToInt((FP^[I].X+DX-OrgX)*Sc);
  SP^[I].Y:=ToInt((FP^[I].Y+DY-OrgY)*Sc);
 End;
End;

Procedure DoFill(O: PObj; Col: Integer);
Var Pat: TPat; Solid: Boolean;
Begin
 Case O^.FillMode Of
  1: Begin
      Pat:=FillPats[Clamp(O^.FillPat,1,NPAT)];
      Solid:=(O^.FillPat=1);
     End;
  2: Begin
      BuildGreyPat(O^.Grey,Pat);
      Solid:=(O^.Grey>=250);
     End;
  Else Exit;
 End;
 FillScan(Solid,Pat,Col);
End;

Procedure SetStroke(O: PObj; Col: Integer);
Var Px: Double; Th: Integer;
Begin
 SetColor(Col);
 Px:=O^.LineW*Sc;
 If Px<=1.5 Then Th:=1 Else Th:=3;
 If O^.LineSty=0 Then SetLineStyle(SolidLn,0,Th)
 Else SetLineStyle(UserBitLn,LinePat[Clamp(O^.LineSty,0,6)],Th);
End;

Procedure StrokeSubs(O: PObj; Col: Integer);
Var S,N,I,M,DX,DY: Integer; Px: Double; Q: Array[0..0] Of PointType;
 Tmp: PSPts; Save: Array[0..1] Of Integer;
Begin
 If O^.LineW<0 Then Exit;
 Px:=O^.LineW*Sc;
 SetStroke(O,Col);
 M:=0;
 If Px>4.5 Then M:=Clamp(Trunc((Px-3)/2),1,5);
 For DX:=-M To M Do
  For DY:=-M To M Do
   If DX*DX+DY*DY<=M*M Then Begin
    For S:=0 To NSub-1 Do Begin
     N:=SubS[S+1]-SubS[S];
     If N>=2 Then Begin
      If (DX<>0) Or (DY<>0) Then
       For I:=SubS[S] To SubS[S+1]-1 Do Begin
        SP^[I].X:=SP^[I].X+DX;SP^[I].Y:=SP^[I].Y+DY;
       End;
      DrawPoly(N,SP^[SubS[S]]);
      If (DX<>0) Or (DY<>0) Then
       For I:=SubS[S] To SubS[S+1]-1 Do Begin
        SP^[I].X:=SP^[I].X-DX;SP^[I].Y:=SP^[I].Y-DY;
       End;
     End;
    End;
   End;
 SetLineStyle(SolidLn,0,1);
End;

Procedure DrawArrowHead(X1,Y1,X2,Y2: Integer; Px: Double; Col: Integer);
{ pointe en (X2,Y2), venant de (X1,Y1) }
Var L,Ux,Uy,Sz: Double; Pt: Array[0..2] Of PointType;
Begin
 L:=Hypot(X2-X1,Y2-Y1);
 If L<0.5 Then Exit;
 Ux:=(X2-X1)/L;Uy:=(Y2-Y1)/L;
 Sz:=8+Px*2.5;
 Pt[0].X:=X2;Pt[0].Y:=Y2;
 Pt[1].X:=Round(X2-Ux*Sz-Uy*Sz*0.4);Pt[1].Y:=Round(Y2-Uy*Sz+Ux*Sz*0.4);
 Pt[2].X:=Round(X2-Ux*Sz+Uy*Sz*0.4);Pt[2].Y:=Round(Y2-Uy*Sz-Ux*Sz*0.4);
 SetFillStyle(SolidFill,Col);
 SetColor(Col);
 SetLineStyle(SolidLn,0,1);
 FillPoly(3,Pt);
End;

Procedure DrawEnds(O: PObj; Col: Integer);
Var A,B,I: Integer; Px: Double;
Begin
 If (NSub<1) Or (O^.Kind In [OK_CIRCLE,OK_ELLIPSE,OK_RECT,OK_RRECT,OK_TRI,
   OK_PARA,OK_NGON,OK_TEXT,OK_FTEXT,OK_BITMAP]) Then Exit;
 If SubC[0] And O^.Closed Then Exit;
 A:=SubS[0];B:=SubS[1]-1;
 If B<=A Then Exit;
 Px:=Max2(1,Round(O^.LineW*Sc));
 If O^.EndS=1 Then Begin
  I:=A+1;
  While (I<B) And (Hypot(SP^[I].X-SP^[A].X,SP^[I].Y-SP^[A].Y)<3) Do Inc(I);
  DrawArrowHead(SP^[I].X,SP^[I].Y,SP^[A].X,SP^[A].Y,Px,Col);
 End Else If (O^.EndS=2) And (Px>=2) Then Begin
  SetFillStyle(SolidFill,Col);SetColor(Col);
  FillEllipse(SP^[A].X,SP^[A].Y,Round(Px/2),Round(Px/2));
 End;
 If O^.EndE=1 Then Begin
  I:=B-1;
  While (I>A) And (Hypot(SP^[I].X-SP^[B].X,SP^[I].Y-SP^[B].Y)<3) Do Dec(I);
  DrawArrowHead(SP^[I].X,SP^[I].Y,SP^[B].X,SP^[B].Y,Px,Col);
 End Else If (O^.EndE=2) And (Px>=2) Then Begin
  SetFillStyle(SolidFill,Col);SetColor(Col);
  FillEllipse(SP^[B].X,SP^[B].Y,Round(Px/2),Round(Px/2));
 End;
End;

{ ---- texte vectoriel : chaque pixel de la police 8x8 est transforme ---- }
Procedure DrawStrWorld(OX,OY,UX,UY,VX,VY: Double; Const S,St: String;
  Col: Integer; Bold,Ita,Und: Boolean);
Var I,R,C,C0: Integer; Row: Byte; Sty: Byte; B,It,Un: Boolean; Sh: Double;
 P0X,P0Y,P1X,P1Y,PxS: Double; Q: Array[0..3] Of PointType; Pass: Integer;
 ChC: Integer; AX,AY,BX,BY: Double;
Begin
 PxS:=Hypot(UX,UY)*Sc;
 SetColor(Col);
 SetFillStyle(SolidFill,Col);
 SetLineStyle(SolidLn,0,1);
 For I:=1 To Length(S) Do Begin
  If (St<>'') And (I<=Length(St)) Then Sty:=Ord(St[I]) Else Sty:=0;
  B:=Bold Or ((Sty And 1)<>0);
  It:=Ita Or ((Sty And 4)<>0);
  Un:=Und Or ((Sty And 2)<>0);
  ChC:=Ord(S[I]);
  For Pass:=0 To Ord(B) Do
   For R:=0 To 7 Do Begin
    Row:=FontBits[ChC,R];
    If Row<>0 Then Begin
     If It Then Sh:=(7-R)*0.25 Else Sh:=0;
     C:=0;
     While C<8 Do Begin
      If ((Row Shr (7-C)) And 1)<>0 Then Begin
       C0:=C;
       While (C<8) And (((Row Shr (7-C)) And 1)<>0) Do Inc(C);
       { pixels C0..C-1 }
       P0X:=OX+UX*((I-1)*8+C0+Sh+Pass*0.7)+VX*R;
       P0Y:=OY+UY*((I-1)*8+C0+Sh+Pass*0.7)+VY*R;
       P1X:=OX+UX*((I-1)*8+C+Sh+Pass*0.7)+VX*R;
       P1Y:=OY+UY*((I-1)*8+C+Sh+Pass*0.7)+VY*R;
       If PxS<2.2 Then Begin
        Line(ToInt((P0X+VX*0.5-OrgX)*Sc),ToInt((P0Y+VY*0.5-OrgY)*Sc),
             ToInt((P1X+VX*0.5-OrgX)*Sc),ToInt((P1Y+VY*0.5-OrgY)*Sc));
       End Else Begin
        Q[0].X:=ToInt((P0X-OrgX)*Sc);Q[0].Y:=ToInt((P0Y-OrgY)*Sc);
        Q[1].X:=ToInt((P1X-OrgX)*Sc);Q[1].Y:=ToInt((P1Y-OrgY)*Sc);
        Q[2].X:=ToInt((P1X+VX-OrgX)*Sc);Q[2].Y:=ToInt((P1Y+VY-OrgY)*Sc);
        Q[3].X:=ToInt((P0X+VX-OrgX)*Sc);Q[3].Y:=ToInt((P0Y+VY-OrgY)*Sc);
        FillPoly(4,Q);
       End;
      End Else Inc(C);
     End;
    End;
   End;
  If Un Then Begin
   P0X:=OX+UX*((I-1)*8)+VX*8.5;P0Y:=OY+UY*((I-1)*8)+VY*8.5;
   P1X:=OX+UX*(I*8)+VX*8.5;P1Y:=OY+UY*(I*8)+VY*8.5;
   Line(ToInt((P0X-OrgX)*Sc),ToInt((P0Y-OrgY)*Sc),
        ToInt((P1X-OrgX)*Sc),ToInt((P1Y-OrgY)*Sc));
  End;
 End;
End;

Procedure DrawTextObj(O: PObj; DX,DY: Double; Col: Integer);
Var S,Line1: String; Ln,P,Cols,Rows,I,L: Integer; UX,UY,VX,VY,CellX,CellY,
 BX,BY,Off: Double; Fl: Byte; MaxL: Integer; St: String;
 FW,FH,Cell,UL,VL: Double; AUx,AUy,AVx,AVy: Double;
Begin
 If O^.Kind=OK_TEXT Then Begin
  S:=TxtOf(O);
  GetTextExtent(O,Cols,Rows);
  CellX:=(O^.Nd^[1].X-O^.Nd^[0].X)/8;CellY:=(O^.Nd^[1].Y-O^.Nd^[0].Y)/8;
  BX:=(O^.Nd^[2].X-O^.Nd^[0].X)/8;BY:=(O^.Nd^[2].Y-O^.Nd^[0].Y)/8;
  Ln:=0;P:=1;
  Repeat
   L:=P;
   While (L<=Length(S)) And (S[L]<>#10) Do Inc(L);
   Line1:=Copy(S,P,L-P);
   Case O^.TAlign Of
    1: Off:=(Cols-Length(Line1))/2;
    2: Off:=Cols-Length(Line1);
    Else Off:=0;
   End;
   DrawStrWorld(O^.Nd^[0].X+DX+CellX*8*Off+BX*8*1.25*Ln,
     O^.Nd^[0].Y+DY+CellY*8*Off+BY*8*1.25*Ln,CellX,CellY,BX,BY,Line1,'',Col,
     (O^.TFlags And 1)<>0,(O^.TFlags And 4)<>0,(O^.TFlags And 2)<>0);
   Inc(Ln);
   P:=L+1;
  Until P>Length(S)+1;
 End Else Begin
  { texte cadre }
  FW:=Hypot(O^.Nd^[1].X-O^.Nd^[0].X,O^.Nd^[1].Y-O^.Nd^[0].Y);
  FH:=Hypot(O^.Nd^[3].X-O^.Nd^[0].X,O^.Nd^[3].Y-O^.Nd^[0].Y);
  If (FW<0.1) Or (FH<0.1) Then Exit;
  Cell:=O^.FSize*25.4/72;
  If Cell<0.5 Then Cell:=0.5;
  AUx:=(O^.Nd^[1].X-O^.Nd^[0].X)/FW;AUy:=(O^.Nd^[1].Y-O^.Nd^[0].Y)/FW;
  AVx:=(O^.Nd^[3].X-O^.Nd^[0].X)/FH;AVy:=(O^.Nd^[3].Y-O^.Nd^[0].Y)/FH;
  LayoutFrame(O,Trunc(FW/Cell));
  For I:=1 To FtN Do Begin
   If (I*1.25*Cell)>FH+Cell*0.3 Then Break;
   Line1:=FtL[I];St:=FtS[I];
   L:=Trunc(FW/Cell);
   Fl:=FtA[I];
   If (Fl=0) And (O^.TAlign=1) Then Fl:=3;
   If (Fl=0) And (O^.TAlign=2) Then Fl:=1;
   Case Fl Of
    1: Off:=L-Length(Line1);
    3: Off:=(L-Length(Line1))/2;
    Else Off:=0;
   End;
   If Off<0 Then Off:=0;
   DrawStrWorld(O^.Nd^[0].X+DX+AUx*Cell*Off+AVx*Cell*1.25*(I-1),
     O^.Nd^[0].Y+DY+AUy*Cell*Off+AVy*Cell*1.25*(I-1),
     AUx*Cell/8,AUy*Cell/8,AVx*Cell/8,AVy*Cell/8,Line1,St,Col,
     (O^.TFlags And 1)<>0,(O^.TFlags And 4)<>0,(O^.TFlags And 2)<>0);
  End;
 End;
End;

Procedure DrawBitmapObj(O: PObj; DX,DY: Double);
Var X1,Y1,X2,Y2: Double; SX1,SY1,SX2,SY2,Y,X,SrcY,SrcX,W,H,RunX: Integer;
 Cur,C: Integer; Rot: Boolean;
Begin
 X1:=1E30;Y1:=1E30;X2:=-1E30;Y2:=-1E30;
 For X:=0 To 3 Do Begin
  If O^.Nd^[X].X<X1 Then X1:=O^.Nd^[X].X;
  If O^.Nd^[X].X>X2 Then X2:=O^.Nd^[X].X;
  If O^.Nd^[X].Y<Y1 Then Y1:=O^.Nd^[X].Y;
  If O^.Nd^[X].Y>Y2 Then Y2:=O^.Nd^[X].Y;
 End;
 SX1:=ToInt((X1+DX-OrgX)*Sc);SY1:=ToInt((Y1+DY-OrgY)*Sc);
 SX2:=ToInt((X2+DX-OrgX)*Sc);SY2:=ToInt((Y2+DY-OrgY)*Sc);
 If (O^.BPix=Nil) Or (SX2<=SX1) Or (SY2<=SY1) Then Begin
  SetColor(8);
  Rectangle(SX1,SY1,SX2,SY2);
  Line(SX1,SY1,SX2,SY2);Line(SX1,SY2,SX2,SY1);
  Exit;
 End;
 W:=SX2-SX1;H:=SY2-SY1;
 For Y:=Max2(SY1,0) To Min2(SY2-1,CvH-1) Do Begin
  SrcY:=(Y-SY1)*O^.BH Div H;
  If SrcY>=O^.BH Then SrcY:=O^.BH-1;
  X:=Max2(SX1,0);
  While X<=Min2(SX2-1,CvW-1) Do Begin
   SrcX:=(X-SX1)*O^.BW Div W;
   If SrcX>=O^.BW Then SrcX:=O^.BW-1;
   Cur:=O^.BPix^[SrcY*O^.BW+SrcX];
   RunX:=X;
   Repeat
    Inc(RunX);
    If RunX>Min2(SX2-1,CvW-1) Then Break;
    SrcX:=(RunX-SX1)*O^.BW Div W;
    If SrcX>=O^.BW Then SrcX:=O^.BW-1;
    C:=O^.BPix^[SrcY*O^.BW+SrcX];
   Until C<>Cur;
   SetColor(Cur);
   SetLineStyle(SolidLn,0,1);
   Line(X,Y,RunX-1,Y);
   X:=RunX;
  End;
 End;
End;

Procedure DrawObject(O: PObj; DX,DY: Double; Shadow: Boolean);
Var Col,FCol: Integer; Pat: TPat;
Begin
 If O^.Kind In [OK_TEXT,OK_FTEXT] Then Begin
  If Shadow Then Col:=NearestCol(O^.ShCol) Else Col:=NearestCol(O^.LineCol);
  FlattenObj(O,Sc);
  DrawTextObj(O,DX,DY,Col);
  Exit;
 End;
 If O^.Kind=OK_BITMAP Then Begin
  If Shadow Then Begin
   FlattenObj(O,Sc);
   ObjToScreen(DX,DY);
   FillScan(True,Pat,NearestCol(O^.ShCol));
  End Else DrawBitmapObj(O,DX,DY);
  Exit;
 End;
 FlattenObj(O,Sc);
 ObjToScreen(DX,DY);
 If Shadow Then Col:=NearestCol(O^.ShCol) Else Col:=NearestCol(O^.LineCol);
 If Shadow Then FCol:=Col Else FCol:=NearestCol(O^.FillCol);
 If (O^.FillMode<>0) And IsFilledKind(O^.Kind) Then Begin
  If Shadow Then FillScan(True,Pat,Col) Else DoFill(O,FCol);
 End;
 StrokeSubs(O,Col);
 If Not Shadow Then DrawEnds(O,Col);
End;

Procedure DrawObjectFull(O: PObj);
Var X1,Y1,X2,Y2: Double;
Begin
 If O^.Outline Then Begin
  ObjBBox(O,X1,Y1,X2,Y2);
  SetColor(8);
  SetLineStyle(UserBitLn,$AAAA,1);
  Rectangle(ToInt((X1-OrgX)*Sc),ToInt((Y1-OrgY)*Sc),ToInt((X2-OrgX)*Sc),
    ToInt((Y2-OrgY)*Sc));
  SetLineStyle(SolidLn,0,1);
  Exit;
 End;
 If O^.ShOn Then DrawObject(O,O^.ShDX,O^.ShDY,True);
 DrawObject(O,0,0,False);
End;

{ ====================================================================== }
{                  ICONES (glyphes dessines au vol)                      }
{ ====================================================================== }

Var
 GX,GY: Integer;

Procedure GL(X1,Y1,X2,Y2: Integer);
Begin
 Line(GX+X1,GY+Y1,GX+X2,GY+Y2);
End;

Procedure GR(X1,Y1,X2,Y2: Integer);
Begin
 Rectangle(GX+X1,GY+Y1,GX+X2,GY+Y2);
End;

Procedure GB(X1,Y1,X2,Y2: Integer);
Begin
 Bar(GX+X1,GY+Y1,GX+X2,GY+Y2);
End;

Procedure GBez(X0,Y0,X1,Y1,X2,Y2,X3,Y3: Double);
Var I: Integer; T,U: Double; PX,PY,QX,QY: Integer;
Begin
 PX:=Round(X0);PY:=Round(Y0);
 For I:=1 To 10 Do Begin
  T:=I/10;U:=1-T;
  QX:=Round(U*U*U*X0+3*U*U*T*X1+3*U*T*T*X2+T*T*T*X3);
  QY:=Round(U*U*U*Y0+3*U*U*T*Y1+3*U*T*T*Y2+T*T*T*Y3);
  GL(PX,PY,QX,QY);
  PX:=QX;PY:=QY;
 End;
End;

{ G : code du glyphe ; X,Y : coin haut gauche (zone de 16x16 a X+4,Y+4) }
Procedure DrawGlyph(G,X,Y,C: Integer);
Var I: Integer; A: Double;
Begin
 GX:=X+4;GY:=Y+4;
 SetColor(C);SetFillStyle(SolidFill,C);SetLineStyle(SolidLn,0,1);
 Case G Of
  1,2: Begin
   Circle(GX+6,GY+6,5);
   GL(10,10,15,15);GL(11,10,15,14);
   GL(3,6,9,6);
   If G=1 Then GL(6,3,6,9);
  End;
  3: Begin GR(2,0,13,15);GL(5,4,10,4);GL(5,7,10,7);GL(5,10,10,10);End;
  4: Begin GB(5,5,14,14);SetColor(PAPER);SetFillStyle(SolidFill,PAPER);
      GB(0,0,9,9);SetColor(C);GR(0,0,9,9);End;
  5: Begin SetColor(PAPER);SetFillStyle(SolidFill,PAPER);GB(5,5,14,14);
      SetColor(C);GR(5,5,14,14);GR(0,0,9,9);SetFillStyle(SolidFill,C);
      GB(0,0,9,9);GR(5,5,14,14);End;
  6: OutTextXY(X,Y+8,'1:1');
  7: Begin GR(0,1,6,7);GR(9,8,15,14);SetLineStyle(UserBitLn,$AAAA,1);
      GR(-1,0,16,15);SetLineStyle(SolidLn,0,1);End;
  8: Begin GR(0,0,6,6);GR(9,9,15,15);GL(7,7,8,8);GL(2,10,2,14);GL(2,14,6,14);
      End;
  9: Begin
      For I:=0 To 2 Do Begin
       PutPixel(GX+1+I*6,GY+1,C);PutPixel(GX+1+I*6,GY+7,C);
       PutPixel(GX+1+I*6,GY+13,C);
      End;
      GR(5,5,9,9);
     End;
  10: OutTextXY(X,Y+8,'X=U');
  11: Begin GB(0,1,5,4);GB(0,6,11,9);GB(0,11,8,14);GL(14,0,14,15);End;
  12: Begin GR(3,4,12,15);GL(1,3,14,3);GL(5,1,10,1);GL(5,1,5,3);GL(10,1,10,3);
       GL(6,6,6,13);GL(9,6,9,13);End;
  13: Begin GL(1,14,10,5);GL(2,14,11,5);GR(9,2,13,6);GL(12,6,14,8);End;
  14: Begin GL(2,14,11,3);GL(4,14,13,3);GL(11,3,13,3);GL(2,14,3,10);GL(2,14,6,13);
      GL(11,3,14,0);GL(13,3,15,1);End;
  15: Begin
       GL(2,1,2,13);GL(2,13,5,10);GL(5,10,9,15);GL(9,15,11,14);GL(11,14,8,9);
       GL(8,9,12,9);GL(12,9,2,1);
      End;
  16: Begin GR(0,2,15,13);GL(0,10,5,6);GL(5,6,9,11);GL(9,11,12,8);GL(12,8,15,11);
       Circle(GX+11,GY+5,1);End;
  17: Begin GL(2,2,13,2);GL(7,2,7,14);GL(2,2,2,5);GL(13,2,13,5);End;
  21: GL(1,14,14,1);
  22: Begin GL(1,13,5,3);GL(5,3,10,11);GL(10,11,14,2);End;
  23: GR(1,2,14,13);
  24: Begin GL(4,2,11,2);GL(4,13,11,13);GL(1,5,1,10);GL(14,5,14,10);
       GL(4,2,1,5);GL(11,2,14,5);GL(1,10,4,13);GL(14,10,11,13);End;
  25: Begin GL(1,14,14,14);GL(14,14,7,1);GL(7,1,1,14);End;
  26: Begin GL(4,3,14,3);GL(14,3,11,13);GL(11,13,1,13);GL(1,13,4,3);End;
  27: Circle(GX+8,GY+8,6);
  28: Ellipse(GX+8,GY+8,0,360,7,4);
  29: Begin Arc(GX+8,GY+10,20,160,7);GL(8,10,8,10);End;
  30: Begin Ellipse(GX+8,GY+9,10,170,7,5);End;
  31: Begin GBez(1,13,4,0,12,0,14,13);GR(0,12,2,14);GR(13,12,15,14);End;
  32: Begin GBez(1,12,5,0,10,16,14,3);GR(0,11,2,13);GR(13,2,15,4);End;
  33: Begin OutTextXY(GX+4,GY+4,'T');OutTextXY(GX+5,GY+4,'T');End;
  34: Begin GR(0,0,15,15);GL(2,3,13,3);GL(2,6,13,6);GL(2,9,13,9);GL(2,12,9,12);
       End;
  35: Begin GBez(1,11,4,0,7,0,8,7);GBez(8,7,9,14,12,14,14,3);End;
  36: Begin
       For I:=0 To 5 Do Begin
        A:=I*Pi/3;
        GL(8+Round(7*Cos(A)),8+Round(7*Sin(A)),8+Round(7*Cos(A+Pi/3)),
           8+Round(7*Sin(A+Pi/3)));
       End;
      End;
  37: Begin GL(1,12,3,5);GL(3,5,5,10);GL(5,10,7,3);GL(7,3,9,12);GL(9,12,12,6);
       GL(12,6,14,9);End;
  38: Begin GR(0,1,15,14);GB(2,9,6,13);GB(7,6,10,13);GB(11,3,14,13);End;
  41: Begin GL(1,1,1,12);GL(1,12,4,9);GL(4,9,8,14);GL(8,14,10,13);GL(10,13,6,8);
       GL(6,8,10,8);GL(10,8,1,1);GR(11,3,14,6);End;
  42: Begin GL(1,1,1,12);GL(1,12,4,9);GL(4,9,10,8);GL(10,8,1,1);
       DotLine(GX+6,GY+10,GX+14,GY+14,C);GR(13,12,15,14);End;
  43: Begin GL(1,12,7,12);GBez(7,12,9,4,12,4,15,4);GR(5,10,8,13);End;
  44: Begin GL(2,2,13,13);GL(2,13,13,2);Circle(GX+2,GY+2,2);Circle(GX+2,GY+13,2);
       End;
  45: Begin GR(0,0,15,15);GL(3,3,12,12);GL(3,12,12,3);End;
  46: Begin GL(0,11,15,11);GL(7,7,7,15);GL(4,11,4,11);GR(5,4,9,8);End;
  47: Begin GBez(0,12,4,2,10,2,15,12);GR(0,11,2,14);GR(13,11,15,14);End;
  48: Begin GL(0,8,4,8);GL(11,8,15,8);GR(5,6,10,10);End;
  49: Begin Arc(GX+8,GY+10,0,180,7);GL(1,10,3,6);GL(1,10,5,9);End;
  51: Begin GR(1,2,14,13);GL(1,7,14,7);GL(7,2,7,13);GL(4,1,4,0);End;
  52: Begin GR(3,3,12,12);GL(0,1,5,1);GL(1,0,1,5);GL(10,14,15,14);GL(14,10,14,15);
      End;
  53: Begin GB(0,0,6,6);SetFillStyle(SolidFill,8);GB(8,0,14,6);GB(0,8,6,14);
       SetColor(C);GR(8,8,14,14);End;
  54: Begin GL(0,8,15,8);GB(6,4,9,12);GL(2,2,2,14);End;
  61: Begin GL(1,2,12,2);GL(6,2,6,13);GL(1,2,1,5);GL(12,2,12,5);GL(14,6,14,14);
      End;
  71: Begin GR(1,1,14,14);GB(3,1,12,5);GR(4,8,11,14);End;
  72: Begin GR(1,6,14,13);GR(4,1,11,6);GL(3,10,12,10);GB(4,11,11,14);End;
  73: Begin GL(1,1,14,14);GL(14,1,1,14);Circle(GX+3,GY+12,2);
       Circle(GX+12,GY+12,2);End;
  74: Begin GR(1,1,9,11);GR(5,4,14,15);End;
  75: Begin GR(2,3,13,15);GR(5,1,10,4);GL(4,8,11,8);GL(4,11,11,11);End;
  76: Begin DotLine(GX+1,GY+1,GX+14,GY+1,C);DotLine(GX+1,GY+1,GX+1,GY+14,C);
       GB(11,11,14,14);GL(3,3,11,11);End;
  77: Begin OutTextXY(X+2,Y+6,'ab');End;
  78: Begin Circle(GX+8,GY+8,6);Circle(GX+6,GY+6,1);Circle(GX+10,GY+6,1);
       GL(5,10,11,10);End;
  79: Begin GR(1,1,14,14);For I:=0 To 6 Do GL(2+I*2,1,2+I*2,14);End;
  80: Begin GL(1,3,14,3);GL(1,7,14,7);GL(1,11,14,11);GB(1,6,14,8);End;
  81: Begin GL(7,1,7,14);GL(7,1,3,5);GL(7,1,11,5);End;
  82: Begin GL(7,1,7,14);GL(7,14,3,10);GL(7,14,11,10);End;
 End;
 SetFillStyle(SolidFill,C);
End;

{ ====================================================================== }
{                    PANNEAU D'ICONES, INFO, BARRES                      }
{ ====================================================================== }

Const
 PNX = 3;
 PNFY = 70;       { fonctions }
 PNCY = 172;      { choix }
 PNTY = 202;      { boite a outils }
 ICW = 24;

 FuncGlyph: Array[1..12] Of Integer = (1,2,3,4,5,6,7,8,9,10,11,12);

 QuickN = 10;
 QuickG: Array[1..QuickN] Of Integer = (71,72,73,74,75,76,77,78,79,80);

Function ToolCount(Bx: Integer): Integer;
Begin
 Case Bx Of
  BX_DRAW: ToolCount:=18;
  BX_PATH: ToolCount:=9;
  BX_PIC: ToolCount:=4;
  Else ToolCount:=1;
 End;
End;

Function ToolGlyph(Bx,T: Integer): Integer;
Begin
 Case Bx Of
  BX_DRAW: ToolGlyph:=20+T;
  BX_PATH: ToolGlyph:=40+T;
  BX_PIC: ToolGlyph:=50+T;
  Else ToolGlyph:=61;
 End;
End;

Function ToolName(Bx,T: Integer): String;
Begin
 ToolName:='';
 Case Bx Of
  BX_DRAW: Case T Of
   1: ToolName:=L2('Line','Ligne');
   2: ToolName:=L2('Multi-line','Multi-ligne');
   3: ToolName:=L2('Rectangle','Rectangle');
   4: ToolName:=L2('Rounded rectangle','Rectangle arrondi');
   5: ToolName:=L2('Triangle','Triangle');
   6: ToolName:=L2('Parallelogram','Parallelogramme');
   7: ToolName:=L2('Circle','Cercle');
   8: ToolName:=L2('Ellipse','Ellipse');
   9: ToolName:=L2('Circular arc','Arc circulaire');
   10: ToolName:=L2('Elliptical arc','Arc elliptique');
   11: ToolName:=L2('Rubberband line','Ligne elastique');
   12: ToolName:=L2('Bezier curve','Courbe de Bezier');
   13: ToolName:=L2('Text','Texte');
   14: ToolName:=L2('Frame text','Texte cadre');
   15: ToolName:=L2('Spline curve','Courbe spline');
   16: ToolName:=L2('N-sides','N-cotes');
   17: ToolName:=L2('Freehand line','Ligne a main levee');
   18: ToolName:=L2('Bitmap graphic','Image bitmap');
  End;
  BX_PATH: Case T Of
   1: ToolName:=L2('Move node','Deplacer noeud');
   2: ToolName:=L2('Tangential move','Deplacement tangentiel');
   3: ToolName:=L2('Change segment type','Changer type de segment');
   4: ToolName:=L2('Cut path','Couper le chemin');
   5: ToolName:=L2('Delete node','Supprimer noeud');
   6: ToolName:=L2('Add node','Ajouter noeud');
   7: ToolName:=L2('Smooth','Lisser');
   8: ToolName:=L2('Jump point','Point de saut');
   9: ToolName:=L2('Change line direction','Inverser le sens');
  End;
  BX_PIC: Case T Of
   1: ToolName:=L2('Fit to printer resolution','Ajuster a la resolution');
   2: ToolName:=L2('Cut borders','Couper les bordures');
   3: ToolName:=L2('Set colour palette','Definir la palette');
   4: ToolName:=L2('Gradation curve','Courbe de gradation');
  End;
  Else ToolName:=L2('Edit text','Editer le texte');
 End;
End;

Procedure IconButton(X,Y,G: Integer; Down: Boolean; Enabled: Boolean);
Begin
 If Down Then Begin
  Box(X,Y,X+ICW-1,Y+ICW-1,INK);
  If Enabled Then DrawGlyph(G,X,Y,PAPER) Else DrawGlyph(G,X,Y,8);
 End Else Begin
  Box(X,Y,X+ICW-1,Y+ICW-1,CHROME);
  Bevel(X,Y,X+ICW-1,Y+ICW-1,False);
  If Enabled Then DrawGlyph(G,X,Y,INK) Else DrawGlyph(G,X,Y,8);
 End;
End;

Function AuxGlyph: Integer;
Begin
 Case AuxBox Of
  BX_PIC: AuxGlyph:=16;
  BX_TEXT: AuxGlyph:=17;
  Else AuxGlyph:=13;
 End;
End;

Procedure DrawPanel;
Var I,R,C,N: Integer;
Begin
 Box(0,CVY1,PANEL_W-1,SCR_H-1,CHROME);
 SetColor(INK);
 Line(PANEL_W-1,CVY1,PANEL_W-1,SCR_H-1);
 For I:=1 To 12 Do Begin
  R:=(I-1) Div 3;C:=(I-1) Mod 3;
  IconButton(PNX+C*ICW,PNFY+R*ICW,FuncGlyph[I],
    (I=9) And GridSnap,True);
 End;
 { icones de choix : popup, dessin, selection }
 IconButton(PNX,PNCY,AuxGlyph,(Not SelMode) And (CurBox<>BX_DRAW),True);
 IconButton(PNX+ICW,PNCY,14,(Not SelMode) And (CurBox=BX_DRAW),True);
 IconButton(PNX+2*ICW,PNCY,15,SelMode,True);
 SetColor(INK);
 { petit triangle sur l'icone popup }
 Line(PNX+1,PNCY+ICW-2,PNX+6,PNCY+ICW-2);Line(PNX+1,PNCY+ICW-2,PNX+1,PNCY+ICW-7);
 { boite a outils courante }
 N:=ToolCount(CurBox);
 For I:=1 To N Do Begin
  R:=(I-1) Div 3;C:=(I-1) Mod 3;
  IconButton(PNX+C*ICW,PNTY+R*ICW,ToolGlyph(CurBox,I),
    (Not SelMode) And (CurTool[CurBox]=I),True);
 End;
End;

Procedure DrawField(X,Y,W: Integer; Const Lab,Val: String);
Begin
 PText(X,Y+3,Lab);
 Box(X+TextW(Lab),Y,X+TextW(Lab)+W,Y+13,PAPER);
 Frame(X+TextW(Lab),Y,X+TextW(Lab)+W,Y+13);
 PText(X+TextW(Lab)+3,Y+3,Copy(Val,1,W Div 8));
End;

Var
 CurWX,CurWY,CurDX,CurDY: Double;
 ShowDelta: Boolean;

Function TitleStr: String;
Var S: String;
Begin
 If Named Then S:=ShortName(DocName) Else S:='Noname';
 If Modified Then S:='*'+S;
 TitleStr:=S;
End;

{ Barre de titre style GEM / Atari ST : fermeture a gauche, rayures, titre
  centre sur fond blanc, boutons a droite }
Procedure DrawWinTitle(X1,Y1,X2: Integer; Const T: String; Right: Boolean);
Var I,TW,TX,RW: Integer;
Begin
 Box(X1,Y1,X2,Y1+15,PAPER);
 SetColor(INK);SetLineStyle(SolidLn,0,1);
 If Right Then RW:=50 Else RW:=4;
 I:=Y1+2;
 While I<=Y1+13 Do Begin
  Line(X1+20,I,X2-RW,I);
  Inc(I,2);
 End;
 { bouton de fermeture }
 Box(X1+3,Y1+2,X1+15,Y1+13,PAPER);
 Frame(X1+3,Y1+2,X1+15,Y1+13);
 Box(X1+6,Y1+5,X1+12,Y1+10,PAPER);
 Frame(X1+6,Y1+5,X1+12,Y1+10);
 { titre }
 TW:=TextW(T);
 TX:=X1+(X2-X1-TW) Div 2;
 Box(TX-6,Y1+1,TX+TW+5,Y1+14,PAPER);
 PText(TX,Y1+4,T);
 If Right Then Begin
  { iconifier, agrandir, plein ecran }
  Box(X2-47,Y1+2,X2-35,Y1+13,PAPER);Frame(X2-47,Y1+2,X2-35,Y1+13);
  Box(X2-44,Y1+7,X2-38,Y1+10,INK);
  Box(X2-32,Y1+2,X2-20,Y1+13,PAPER);Frame(X2-32,Y1+2,X2-20,Y1+13);
  Line(X2-26,Y1+4,X2-30,Y1+10);Line(X2-26,Y1+4,X2-22,Y1+10);
  Line(X2-30,Y1+10,X2-22,Y1+10);
  Box(X2-17,Y1+2,X2-5,Y1+13,PAPER);Frame(X2-17,Y1+2,X2-5,Y1+13);
  Frame(X2-14,Y1+5,X2-8,Y1+10);
 End;
End;

Procedure DrawTitleBar;
Begin
 DrawWinTitle(0,TITLE_Y,SCR_W-1,TitleStr,True);
 SetColor(INK);
 Line(0,TITLE_Y+TITLE_H-1,SCR_W-1,TITLE_Y+TITLE_H-1);
End;

Procedure DrawInfoLine;
Var I,X: Integer; S: String;
Begin
 Box(0,INFO_Y,SCR_W-1,INFO_Y+INFO_H-1,CHROME);
 SetColor(INK);
 Line(0,INFO_Y+INFO_H-1,SCR_W-1,INFO_Y+INFO_H-1);
 { zoom }
 Box(3,INFO_Y+3,60,INFO_Y+17,PAPER);
 Frame(3,INFO_Y+3,60,INFO_Y+17);
 S:=IntStr(Round(Zoom))+'%';
 PText(8,INFO_Y+7,S);
 Line(52,INFO_Y+9,58,INFO_Y+9);Line(52,INFO_Y+9,55,INFO_Y+13);
 Line(58,INFO_Y+9,55,INFO_Y+13);
 DrawField(66,INFO_Y+3,64,'X:',RealStr(CurWX/UnitFactor(UnitIdx),1));
 DrawField(66+80,INFO_Y+3,64,'Y:',RealStr(CurWY/UnitFactor(UnitIdx),1));
 If ShowDelta Then Begin
  DrawField(66+160,INFO_Y+3,64,'dX:',RealStr(CurDX/UnitFactor(UnitIdx),1));
  DrawField(66+256,INFO_Y+3,64,'dY:',RealStr(CurDY/UnitFactor(UnitIdx),1));
 End Else Begin
  DrawField(66+160,INFO_Y+3,64,'dX:','');
  DrawField(66+256,INFO_Y+3,64,'dY:','');
 End;
 PText(488,INFO_Y+6,'Page:');
 Box(528,INFO_Y+3,568,INFO_Y+17,PAPER);
 Frame(528,INFO_Y+3,568,INFO_Y+17);
 PText(532,INFO_Y+7,IntStr(CurPage)+'/'+IntStr(NPages));
 { fleches de page }
 Box(576,INFO_Y+3,591,INFO_Y+17,CHROME);Frame(576,INFO_Y+3,591,INFO_Y+17);
 DrawGlyph(81,576-2,INFO_Y+2,INK);
 Box(596,INFO_Y+3,611,INFO_Y+17,CHROME);Frame(596,INFO_Y+3,611,INFO_Y+17);
 DrawGlyph(82,596-2,INFO_Y+2,INK);
 { ligne de description + icones rapides }
 PText(8,INFO_Y+23,Copy(CurMsg,1,50));
 For I:=1 To QuickN Do Begin
  X:=SCR_W-4-(QuickN-I+1)*20;
  Box(X,INFO_Y+18,X+18,INFO_Y+INFO_H-2,CHROME);
  Bevel(X,INFO_Y+18,X+18,INFO_Y+INFO_H-2,False);
  DrawGlyph(QuickG[I],X-3,INFO_Y+16,INK);
 End;
End;

Function PageMinX: Double;
Begin
 PageMinX:=-30;
End;

Procedure DitherBox(X1,Y1,X2,Y2: Integer);
Var X,Y: Integer;
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 For Y:=Y1 To Y2 Do
  For X:=X1 To X2 Do
   If Odd(X+Y) Then PutPixel(X,Y,INK);
End;

Procedure ScrollArrow(X1,Y1,X2,Y2,Dir: Integer);
Var P: Array[0..2] Of PointType; CX,CY: Integer;
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 CX:=(X1+X2) Div 2;CY:=(Y1+Y2) Div 2;
 Case Dir Of
  1: Begin P[0].X:=CX;P[0].Y:=CY-3;P[1].X:=CX-4;P[1].Y:=CY+3;P[2].X:=CX+4;P[2].Y:=CY+3;End;
  2: Begin P[0].X:=CX;P[0].Y:=CY+3;P[1].X:=CX-4;P[1].Y:=CY-3;P[2].X:=CX+4;P[2].Y:=CY-3;End;
  3: Begin P[0].X:=CX-3;P[0].Y:=CY;P[1].X:=CX+3;P[1].Y:=CY-4;P[2].X:=CX+3;P[2].Y:=CY+4;End;
  Else Begin P[0].X:=CX+3;P[0].Y:=CY;P[1].X:=CX-3;P[1].Y:=CY-4;P[2].X:=CX-3;P[2].Y:=CY+4;End;
 End;
 SetFillStyle(SolidFill,INK);
 SetColor(INK);
 FillPoly(3,P);
End;

Procedure DrawScrollbars;
Var Rng,Vis,TL,TH: Double; TrackLen,T0: Integer;
Begin
 { barre verticale : piste tramee, fleches aux extremites, curseur noir }
 SetLineStyle(SolidLn,0,1);
 T0:=CVY1+SB_W+1;
 TrackLen:=CVY2-CVY1-2*SB_W-1;
 DitherBox(CVX2+1,T0,SCR_W-1,T0+TrackLen-1);
 SetColor(INK);Line(CVX2+1,CVY1,CVX2+1,CVY2);
 ScrollArrow(CVX2+1,CVY1,SCR_W-1,CVY1+SB_W,1);
 ScrollArrow(CVX2+1,CVY2-SB_W,SCR_W-1,CVY2,2);
 Rng:=PageH+60;Vis:=(CVY2-CVY1+1)/Sc;
 If Vis>=Rng Then Begin TL:=0;TH:=TrackLen;End
 Else Begin
  TL:=(OrgY+30)/Rng*TrackLen;TH:=Vis/Rng*TrackLen;
  If TH<10 Then TH:=10;
 End;
 If TL<0 Then TL:=0;
 If TL+TH>TrackLen Then TL:=TrackLen-TH;
 Box(CVX2+2,T0+Round(TL),SCR_W-2,T0+Round(TL+TH)-1,INK);
 Box(CVX2+3,T0+Round(TL)+1,SCR_W-3,T0+Round(TL+TH)-2,PAPER);
 DitherBox(CVX2+4,T0+Round(TL)+2,SCR_W-4,T0+Round(TL+TH)-3);
 { barre horizontale }
 T0:=CVX1+SB_W+1;
 TrackLen:=CVX2-CVX1-2*SB_W-1;
 DitherBox(T0,CVY2+2,T0+TrackLen-1,SCR_H-1);
 SetColor(INK);Line(CVX1,CVY2+1,CVX2,CVY2+1);
 ScrollArrow(CVX1,CVY2+1,CVX1+SB_W,SCR_H-1,3);
 ScrollArrow(CVX2-SB_W,CVY2+1,CVX2,SCR_H-1,4);
 Rng:=PageW+60;Vis:=(CVX2-CVX1+1)/Sc;
 If Vis>=Rng Then Begin TL:=0;TH:=TrackLen;End
 Else Begin
  TL:=(OrgX+30)/Rng*TrackLen;TH:=Vis/Rng*TrackLen;
  If TH<10 Then TH:=10;
 End;
 If TL<0 Then TL:=0;
 If TL+TH>TrackLen Then TL:=TrackLen-TH;
 Box(T0+Round(TL),CVY2+2,T0+Round(TL+TH)-1,SCR_H-2,INK);
 Box(T0+Round(TL)+1,CVY2+3,T0+Round(TL+TH)-2,SCR_H-3,PAPER);
 DitherBox(T0+Round(TL)+2,CVY2+4,T0+Round(TL+TH)-3,SCR_H-4);
 { coin de redimensionnement }
 Box(CVX2+1,CVY2+1,SCR_W-1,SCR_H-1,PAPER);
 Frame(CVX2+1,CVY2+1,SCR_W-1,SCR_H-1);
 Frame(CVX2+4,CVY2+4,SCR_W-5,SCR_H-5);
 Box(CVX2+4,CVY2+4,CVX2+9,CVY2+9,INK);
End;

{ ---- coordonnees ecran <-> monde ---- }
Function WorldX(SX: Integer): Double;
Begin
 WorldX:=OrgX+(SX-CVX1)/Sc;
End;

Function WorldY(SY: Integer): Double;
Begin
 WorldY:=OrgY+(SY-CVY1)/Sc;
End;

Function ScrX(X: Double): Integer;
Begin
 ScrX:=ToInt((X-OrgX)*Sc)+CVX1;
End;

Function ScrY(Y: Double): Integer;
Begin
 ScrY:=ToInt((Y-OrgY)*Sc)+CVY1;
End;

Procedure SetZoom(Z: Double);
Begin
 If Z<5 Then Z:=5;
 If Z>3200 Then Z:=3200;
 Zoom:=Z;
 Sc:=Zoom/100*3.7795;
End;

Procedure ClampOrigin;
Var VW,VH: Double;
Begin
 VW:=(CVX2-CVX1+1)/Sc;VH:=(CVY2-CVY1+1)/Sc;
 If VW>=PageW+60 Then OrgX:=-(VW-PageW)/2
 Else Begin
  If OrgX<-30 Then OrgX:=-30;
  If OrgX>PageW+30-VW Then OrgX:=PageW+30-VW;
 End;
 If VH>=PageH+60 Then OrgY:=-(VH-PageH)/2
 Else Begin
  If OrgY<-30 Then OrgY:=-30;
  If OrgY>PageH+30-VH Then OrgY:=PageH+30-VH;
 End;
End;

Procedure ZoomFullPage;
Var ZW,ZH: Double;
Begin
 ZW:=(CVX2-CVX1-20)/(PageW*3.7795)*100;
 ZH:=(CVY2-CVY1-20)/(PageH*3.7795)*100;
 SetZoom(MinD(ZW,ZH));
 OrgX:=0;OrgY:=0;
 ClampOrigin;
End;

Procedure ZoomAround(Z,WX,WY: Double);
Begin
 SetZoom(Z);
 OrgX:=WX-(CVX2-CVX1+1)/Sc/2;
 OrgY:=WY-(CVY2-CVY1+1)/Sc/2;
 ClampOrigin;
End;

{ ====================================================================== }
{                  AFFICHAGE DU CANEVAS ET DES POIGNEES                  }
{ ====================================================================== }

Procedure HandlePos(H: Integer; X1,Y1,X2,Y2: Integer; Var HX,HY: Integer);
Begin
 Case H Of
  1: Begin HX:=X1;HY:=Y1;End;
  2: Begin HX:=(X1+X2) Div 2;HY:=Y1;End;
  3: Begin HX:=X2;HY:=Y1;End;
  4: Begin HX:=X2;HY:=(Y1+Y2) Div 2;End;
  5: Begin HX:=X2;HY:=Y2;End;
  6: Begin HX:=(X1+X2) Div 2;HY:=Y2;End;
  7: Begin HX:=X1;HY:=Y2;End;
  Else Begin HX:=X1;HY:=(Y1+Y2) Div 2;End;
 End;
End;

Procedure DrawHandles;
Var X1,Y1,X2,Y2,H,HX,HY: Integer;
Begin
 If Not SelBBox Then Exit;
 X1:=ToInt((SelBX1-OrgX)*Sc);Y1:=ToInt((SelBY1-OrgY)*Sc);
 X2:=ToInt((SelBX2-OrgX)*Sc);Y2:=ToInt((SelBY2-OrgY)*Sc);
 SetColor(INK);
 SetLineStyle(UserBitLn,$CCCC,1);
 Rectangle(X1,Y1,X2,Y2);
 SetLineStyle(SolidLn,0,1);
 For H:=1 To 8 Do Begin
  If (PropResize Or RotMode) And Not Odd(H) Then Continue;
  If PropResize And (H In [2,4,6,8]) Then Continue;
  HandlePos(H,X1,Y1,X2,Y2,HX,HY);
  If RotMode Then Begin
   If Odd(H) Then Begin
    SetFillStyle(SolidFill,PAPER);
    FillEllipse(HX,HY,4,4);
    SetColor(INK);Circle(HX,HY,4);
   End Else Begin
    SetFillStyle(SolidFill,INK);
    Line(HX-4,HY,HX,HY-4);Line(HX,HY-4,HX+4,HY);
    Line(HX+4,HY,HX,HY+4);Line(HX,HY+4,HX-4,HY);
   End;
  End Else Begin
   Box(HX-3,HY-3,HX+3,HY+3,PAPER);
   Box(HX-2,HY-2,HX+2,HY+2,INK);
  End;
 End;
 If RotMode Then Begin
  HX:=(X1+X2) Div 2;HY:=(Y1+Y2) Div 2;
  SetColor(INK);
  Line(HX-5,HY,HX+5,HY);Line(HX,HY-5,HX,HY+5);
 End;
End;

Function HandleAt(SX,SY: Integer): Integer;
Var X1,Y1,X2,Y2,H,HX,HY: Integer;
Begin
 HandleAt:=0;
 If Not SelBBox Then Exit;
 X1:=ScrX(SelBX1);Y1:=ScrY(SelBY1);X2:=ScrX(SelBX2);Y2:=ScrY(SelBY2);
 For H:=1 To 8 Do Begin
  If (PropResize Or RotMode) And Not Odd(H) Then Continue;
  HandlePos(H,X1,Y1,X2,Y2,HX,HY);
  If (Abs(SX-HX)<=5) And (Abs(SY-HY)<=5) Then Begin HandleAt:=H;Exit;End;
 End;
End;

{ ---- noeuds et tangentes en mode edition de chemin ---- }
Procedure DrawPathNodes(O: PObj);
Var I,J: Integer; X,Y: Integer;
Begin
 If Not IsPathKind(O^.Kind) Then Exit;
 SetLineStyle(SolidLn,0,1);
 For I:=0 To O^.N-1 Do Begin
  X:=ToInt((O^.Nd^[I].X-OrgX)*Sc);Y:=ToInt((O^.Nd^[I].Y-OrgY)*Sc);
  { tangentes }
  J:=(I+1) Mod O^.N;
  If (O^.Nd^[I].Kind=1) And ((I<O^.N-1) Or O^.Closed) Then Begin
   DotLine(X,Y,ToInt((O^.Nd^[I].AX-OrgX)*Sc),ToInt((O^.Nd^[I].AY-OrgY)*Sc),8);
   DotLine(ToInt((O^.Nd^[J].X-OrgX)*Sc),ToInt((O^.Nd^[J].Y-OrgY)*Sc),
     ToInt((O^.Nd^[J].BX-OrgX)*Sc),ToInt((O^.Nd^[J].BY-OrgY)*Sc),8);
   SetColor(INK);
   X:=ToInt((O^.Nd^[I].AX-OrgX)*Sc);Y:=ToInt((O^.Nd^[I].AY-OrgY)*Sc);
   Line(X-2,Y-2,X+2,Y+2);Line(X-2,Y+2,X+2,Y-2);
   X:=ToInt((O^.Nd^[J].BX-OrgX)*Sc);Y:=ToInt((O^.Nd^[J].BY-OrgY)*Sc);
   Line(X-2,Y-2,X+2,Y+2);Line(X-2,Y+2,X+2,Y-2);
  End;
 End;
 For I:=0 To O^.N-1 Do Begin
  X:=ToInt((O^.Nd^[I].X-OrgX)*Sc);Y:=ToInt((O^.Nd^[I].Y-OrgY)*Sc);
  Box(X-3,Y-3,X+3,Y+3,PAPER);
  SetColor(INK);
  Rectangle(X-3,Y-3,X+3,Y+3);
  If I=0 Then Begin Box(X-1,Y-1,X+1,Y+1,INK);End;
 End;
End;

Procedure DrawGridDots;
Var X,Y,Sx,Sy: Double; PX,PY: Integer;
Begin
 If (GridX*Sc<4) Or (GridY*Sc<4) Then Exit;
 X:=Int(OrgX/GridX)*GridX;
 While X<=OrgX+CvW/Sc Do Begin
  PX:=ToInt((X-OrgX)*Sc);
  If (X>=0) And (X<=PageW) Then Begin
   Y:=Int(OrgY/GridY)*GridY;
   While Y<=OrgY+CvH/Sc Do Begin
    PY:=ToInt((Y-OrgY)*Sc);
    If (Y>=0) And (Y<=PageH) And (PX>=0) And (PX<CvW) And (PY>=0) And (PY<CvH)
      Then PutPixel(PX,PY,8);
    Y:=Y+GridY;
   End;
  End;
  X:=X+GridX;
 End;
End;

Procedure DrawCanvas;
Var I,P1X,P1Y,P2X,P2Y: Integer; Any: Boolean;
Begin
 SetViewPort(CVX1,CVY1,CVX2,CVY2,True);
 CvW:=CVX2-CVX1+1;CvH:=CVY2-CVY1+1;
 Box(0,0,CvW-1,CvH-1,CHROME);
 P1X:=ToInt((0-OrgX)*Sc);P1Y:=ToInt((0-OrgY)*Sc);
 P2X:=ToInt((PageW-OrgX)*Sc);P2Y:=ToInt((PageH-OrgY)*Sc);
 Box(P1X+4,P1Y+4,P2X+4,P2Y+4,8);
 Box(P1X,P1Y,P2X,P2Y,PAPER);
 SetColor(INK);SetLineStyle(SolidLn,0,1);
 Rectangle(P1X,P1Y,P2X,P2Y);
 If GridShow Then DrawGridDots;
 For I:=1 To NObj Do
  If ObjVisible(Objs[I]) Then DrawObjectFull(Objs[I]);
 DrawHandles;
 If (Not SelMode) And (CurBox=BX_PATH) Then Begin
  Any:=CountSel>0;
  For I:=1 To NObj Do
   If ObjVisible(Objs[I]) And ((Not Any) Or Objs[I]^.Sel) Then
     DrawPathNodes(Objs[I]);
 End;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
End;

{ ====================================================================== }
{                       EVENEMENTS (souris / clavier)                    }
{ ====================================================================== }

Procedure DrawAll; Forward;

Function AltLetter(K: Word): Integer;
Const
 RowQ: String[10] = 'QWERTYUIOP';
 RowA: String[9] = 'ASDFGHJKL';
 RowZ: String[7] = 'ZXCVBNM';
Var Sc2: Integer;
Begin
 AltLetter:=-1;
 If K<256 Then Exit;
 Sc2:=K-256;
 Case Sc2 Of
  16..25: AltLetter:=Ord(RowQ[Sc2-15])-65;
  30..38: AltLetter:=Ord(RowA[Sc2-29])-65;
  44..50: AltLetter:=Ord(RowZ[Sc2-43])-65;
 End;
End;

Procedure PollEvent(Var E: TEvent);
Var Ch: Char; K: Word;
Begin
 E.Kind:=0;E.Key:=0;E.X:=MX;E.Y:=MY;E.B:=MB;
 If KeyPressed Then Begin
  Ch:=ReadKey;
  If Ch=#0 Then K:=256+Ord(ReadKey) Else K:=Ord(Ch);
  E.Kind:=1;E.Key:=K;
  Exit;
 End;
 PrevMX:=MX;PrevMY:=MY;LastB:=MB;
 GetMouseState(MX,MY,MB);
 E.X:=MX;E.Y:=MY;E.B:=MB;
 If ((MB And 1)<>0) And ((LastB And 1)=0) Then E.Kind:=2
 Else If ((MB And 1)=0) And ((LastB And 1)<>0) Then E.Kind:=3
 Else If ((MB And 2)<>0) And ((LastB And 2)=0) Then E.Kind:=5
 Else If (MX<>PrevMX) Or (MY<>PrevMY) Then E.Kind:=4
 Else Delay(4);
End;

{ ====================================================================== }
{                              MENUS (donnees)                           }
{ ====================================================================== }

Function MTitle(M: Integer): String;
Begin
 Case M Of
  1: MTitle:='ArtWorx';
  2: MTitle:=L2('File','Fichier');
  3: MTitle:=L2('Edit','Edition');
  4: MTitle:=L2('Object','Objet');
  5: MTitle:='Style';
  6: MTitle:='Module';
  Else MTitle:='Options';
 End;
End;

Function MCount(M: Integer): Integer;
Begin
 Case M Of
  1: MCount:=3;
  2: MCount:=15;
  3: MCount:=18;
  4: MCount:=17;
  5: MCount:=10;
  6: MCount:=1;
  7: MCount:=8;
  Else MCount:=0;
 End;
End;

{ '-' = separateur ; '|' separe le raccourci }
Function MLabel(M,I: Integer): String;
Begin
 MLabel:='';
 Case M Of
  1: Case I Of
      1: MLabel:=L2('About ArtWorx...','A propos d''ArtWorx...');
      2: MLabel:='-';
      3: MLabel:=L2('Free memory','Memoire libre');
     End;
  2: Case I Of
      1: MLabel:=L2('New|^N','Nouveau|^N');
      2: MLabel:=L2('Open...|^O','Ouvrir...|^O');
      3: MLabel:=L2('Close|^U','Fermer|^U');
      4: MLabel:=L2('Insert...|^B','Inserer...|^B');
      5: MLabel:=L2('Update','Mettre a jour');
      6: MLabel:='-';
      7: MLabel:=L2('Save|^S','Enregistrer|^S');
      8: MLabel:=L2('Save as...|^M','Enregistrer sous...|Ret');
      9: MLabel:=L2('Abandon','Abandonner');
      10: MLabel:='-';
      11: MLabel:=L2('Export...|^E','Exporter...|^E');
      12: MLabel:=L2('Info...|^I','Info...|^I');
      13: MLabel:=L2('Print...|^P','Imprimer...|^P');
      14: MLabel:='-';
      15: MLabel:=L2('Quit|^Q','Quitter|^Q');
     End;
  3: Case I Of
      1: MLabel:=L2('Undo|F2','Annuler|F2');
      2: MLabel:='-';
      3: MLabel:=L2('Copy|^C','Copier|^C');
      4: MLabel:=L2('Cut|^X','Couper|^X');
      5: MLabel:=L2('Paste|^V','Coller|^V');
      6: MLabel:=L2('Select all|^A','Tout selectionner|^A');
      7: MLabel:=L2('Delete|Del','Supprimer|Del');
      8: MLabel:='-';
      9: MLabel:=L2('Full page|AltQ','Page entiere|AltQ');
      10: MLabel:=L2('Size 1:1|AltW','Taille 1:1|AltW');
      11: MLabel:=L2('Zoom...|AltZ','Zoom...|AltZ');
      12: MLabel:='-';
      13: MLabel:=L2('Insert page','Inserer une page');
      14: MLabel:=L2('Delete page','Supprimer la page');
      15: MLabel:='-';
      16: MLabel:=L2('Cycle windows|^W','Fenetre suivante|^W');
      17: MLabel:=L2('Prop. resizing|^Z','Redim. prop.|^Z');
      18: MLabel:=L2('Layers...','Calques...');
     End;
  4: Case I Of
      1: MLabel:=L2('Import...|I','Importer...|I');
      2: MLabel:=L2('Export...|O','Exporter...|O');
      3: MLabel:='-';
      4: MLabel:=L2('To front|V','Premier plan|V');
      5: MLabel:=L2('To back|H','Arriere-plan|H');
      6: MLabel:=L2('Group|G','Grouper|G');
      7: MLabel:=L2('Ungroup|Z','Degrouper|Z');
      8: MLabel:=L2('Lock|S','Verrouiller|S');
      9: MLabel:=L2('Unlock|F','Deverrouiller|F');
      10: MLabel:='-';
      11: MLabel:=L2('Info...|N','Info...|N');
      12: MLabel:=L2('Arrange...|A','Aligner...|A');
      13: MLabel:=L2('Snap to grid|E','Aimanter a la grille|E');
      14: MLabel:=L2('Commute...|U','Commuter...|U');
      15: MLabel:=L2('Transform...|T','Transformer...|T');
      16: MLabel:=L2('Tiling...|P','Tiling...|P');
      17: MLabel:=L2('Boolean...|K','Booleen...|K');
     End;
  5: Case I Of
      1: MLabel:=L2('Mask','Masque');
      2: MLabel:=L2('Remove mask','Retirer le masque');
      3: MLabel:=L2('As fillpattern','Comme trame');
      4: MLabel:='-';
      5: MLabel:=L2('Lines...|AltL','Traits...|AltL');
      6: MLabel:=L2('Fill...|AltM','Remplissage...|AltM');
      7: MLabel:=L2('Colour...|AltF','Couleur...|AltF');
      8: MLabel:=L2('Text...|AltT','Texte...|AltT');
      9: MLabel:=L2('Shadows...|AltS','Ombres...|AltS');
      10: MLabel:=L2('Status...|AltU','Statut...|AltU');
     End;
  6: If I=1 Then MLabel:=L2('External module...|AltD','Module externe...|AltD');
  7: Case I Of
      1: MLabel:=L2('General...|AltA','General...|AltA');
      2: MLabel:=L2('Paths...|AltE','Chemins...|AltE');
      3: MLabel:=L2('Grid...|AltR','Grille...|AltR');
      4: MLabel:=L2('Format...|AltO','Format...|AltO');
      5: MLabel:=L2('Editor...|AltB','Editeur...|AltB');
      6: MLabel:=L2('Images...|AltI','Images...|AltI');
      7: MLabel:='-';
      8: MLabel:=L2('Save settings','Enregistrer options');
     End;
 End;
End;

Function MChecked(M,I: Integer): Boolean;
Begin
 MChecked:=False;
 If (M=3) And (I=17) Then MChecked:=PropResize;
End;

Function MEnabled(M,I: Integer): Boolean;
Var S: Boolean;
Begin
 MEnabled:=True;
 S:=CountSel>0;
 If (M=2) And (I=7) Then MEnabled:=Modified Or Not Named;
 If (M=3) And (I In [3,4,7]) Then MEnabled:=S;
 If (M=3) And (I=5) Then MEnabled:=ClipHas;
 If (M=3) And (I=1) Then MEnabled:=UndoN>0;
 If M=4 Then Case I Of
  1,2,4..9,11..17: MEnabled:=S;
 End;
 If (M=5) And (I In [1,2,3]) Then MEnabled:=S;
End;

Function MSep(M,I: Integer): Boolean;
Begin
 MSep:=(MLabel(M,I)='-');
End;

Function MenuX(M: Integer): Integer;
Var I,X: Integer;
Begin
 X:=12;
 For I:=1 To M-1 Do X:=X+Length(MTitle(I))*8+20;
 MenuX:=X;
End;

Function ItemH(M,I: Integer): Integer;
Begin
 If MSep(M,I) Then ItemH:=7 Else ItemH:=14;
End;

Procedure DropRect(M: Integer; Var X1,Y1,X2,Y2: Integer);
Var I,W,L,P: Integer; S: String;
Begin
 W:=0;Y2:=MENU_H+2;
 For I:=1 To MCount(M) Do Begin
  S:=MLabel(M,I);
  P:=Pos('|',S);
  If P>0 Then L:=(P-1)*8+28+(Length(S)-P)*8 Else L:=Length(S)*8;
  If L>W Then W:=L;
  Y2:=Y2+ItemH(M,I);
 End;
 X1:=MenuX(M)-8;
 X2:=X1+W+30;
 If X2>SCR_W-4 Then Begin X1:=X1-(X2-(SCR_W-4));X2:=SCR_W-4;End;
 Y1:=MENU_H;Y2:=Y2+2;
End;

Function ItemY(M,I: Integer): Integer;
Var K,Y: Integer;
Begin
 Y:=MENU_H+2;
 For K:=1 To I-1 Do Y:=Y+ItemH(M,K);
 ItemY:=Y;
End;

Function DropHit(M: Integer; X,Y: LongInt): Integer;
Var X1,Y1,X2,Y2,I: Integer;
Begin
 DropHit:=0;
 DropRect(M,X1,Y1,X2,Y2);
 If Not InBox(X,Y,X1,Y1,X2,Y2) Then Exit;
 For I:=1 To MCount(M) Do
  If (Y>=ItemY(M,I)) And (Y<ItemY(M,I)+ItemH(M,I)) Then DropHit:=I;
End;

Function TitleHit(X,Y: LongInt): Integer;
Var M: Integer;
Begin
 TitleHit:=0;
 If (Y<0) Or (Y>=MENU_H) Then Exit;
 For M:=1 To NMENU Do
  If (X>=MenuX(M)-8) And (X<=MenuX(M)+Length(MTitle(M))*8+7) Then TitleHit:=M;
End;

Procedure DrawMenuBar;
Var M: Integer;
Begin
 Box(0,0,SCR_W-1,MENU_H-1,PAPER);
 SetColor(INK);
 SetLineStyle(SolidLn,0,1);
 Line(0,MENU_H-1,SCR_W-1,MENU_H-1);
 For M:=1 To NMENU Do Begin
  If M=MenuOpen Then Begin
   Box(MenuX(M)-8,0,MenuX(M)+Length(MTitle(M))*8+7,MENU_H-2,INK);
   WText(MenuX(M),4,MTitle(M));
  End Else PText(MenuX(M),4,MTitle(M));
 End;
End;

Procedure DrawDropDown;
Var X1,Y1,X2,Y2,I,Y,P: Integer; S,Sc2,Lb: String; Hi: Boolean;
Begin
 If MenuOpen=0 Then Exit;
 DropRect(MenuOpen,X1,Y1,X2,Y2);
 Box(X1+3,Y1+3,X2+3,Y2+3,INK);
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 For I:=1 To MCount(MenuOpen) Do Begin
  S:=MLabel(MenuOpen,I);
  Y:=ItemY(MenuOpen,I);
  If S='-' Then Begin
   DotLine(X1+2,Y+3,X2-2,Y+3,INK);
  End Else Begin
   P:=Pos('|',S);
   If P>0 Then Begin Lb:=Copy(S,1,P-1);Sc2:=Copy(S,P+1,20);End
   Else Begin Lb:=S;Sc2:='';End;
   Hi:=(I=MenuHi) And MEnabled(MenuOpen,I);
   If Hi Then Box(X1+1,Y,X2-1,Y+13,INK);
   If MChecked(MenuOpen,I) Then Begin
    If Hi Then WText(X1+5,Y+3,#251) Else PText(X1+5,Y+3,#251);
   End;
   If Not MEnabled(MenuOpen,I) Then Begin
    GreyText(X1+22,Y+3,Lb);
    If Sc2<>'' Then GreyText(X2-6-Length(Sc2)*8,Y+3,Sc2);
   End Else If Hi Then Begin
    WText(X1+22,Y+3,Lb);
    If Sc2<>'' Then WText(X2-6-Length(Sc2)*8,Y+3,Sc2);
   End Else Begin
    PText(X1+22,Y+3,Lb);
    If Sc2<>'' Then PText(X2-6-Length(Sc2)*8,Y+3,Sc2);
   End;
  End;
 End;
End;

{ ---- affichage complet ---- }
Procedure DrawAll;
Begin
 PrevDrawn:=False;
 HideMouse;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 DrawCanvas;
 DrawPanel;
 DrawTitleBar;
 DrawInfoLine;
 DrawScrollbars;
 SetColor(INK);
 Rectangle(0,CVY1-1,SCR_W-1,SCR_H-1);
 DrawMenuBar;
 DrawDropDown;
 ShowMouse;
 NeedDraw:=False;
End;

Procedure RedrawCanvasOnly;
Begin
 HideMouse;
 DrawCanvas;
 ShowMouse;
End;

{ ====================================================================== }
{                          MOTEUR DE BOITES DE DIALOGUE                  }
{ ====================================================================== }

Const
 DC_LABEL = 1; DC_EDIT = 2; DC_CHECK = 3; DC_RADIO = 4; DC_BTN = 5;
 DC_POP = 6; DC_SLIDER = 7; DC_SWATCH = 8; DC_LIST = 9; DC_COLBOX = 10;
 DC_PATSEL = 11; DC_FRAME = 12;
 ID_OK = 1; ID_CANCEL = 2; ID_APPLY = 3;

Type
 TCtl = Record
  K: Byte;
  X,Y,W,H: Integer;
  T: String[44];
  V: LongInt;
  S: String[70];
  Grp,Id,Mx: Integer;
  Items: String[160];
 End;

Var
 Ctl: Array[1..48] Of TCtl;
 NCtl: Integer;
 DlgTitle: String;
 DlgW,DlgH,DlgX,DlgY: Integer;
 DlgFocus: Integer;
 DlgFresh: Boolean;
 RadioVal: Array[1..8] Of LongInt;
 DlgHookId: Integer;

Procedure DlgHookProc; Forward;

Procedure DlgInit(Const Title: String; W,H: Integer);
Begin
 NCtl:=0;DlgTitle:=Title;DlgW:=W;DlgH:=H;DlgFocus:=0;DlgFresh:=True;DlgHookId:=0;
 DlgX:=(SCR_W-W) Div 2;DlgY:=(SCR_H-H) Div 2;
End;

Function AddCtl(K: Byte; X,Y,W,H: Integer; Const T: String): Integer;
Begin
 If NCtl<48 Then Inc(NCtl);
 FillChar(Ctl[NCtl],SizeOf(TCtl),0);
 Ctl[NCtl].K:=K;Ctl[NCtl].X:=X;Ctl[NCtl].Y:=Y;Ctl[NCtl].W:=W;Ctl[NCtl].H:=H;
 Ctl[NCtl].T:=T;
 AddCtl:=NCtl;
End;

Function AddLabel(X,Y: Integer; Const T: String): Integer;
Begin
 AddLabel:=AddCtl(DC_LABEL,X,Y,Length(T)*8,8,T);
End;

Function AddEdit(X,Y,W: Integer; Const S: String): Integer;
Var I: Integer;
Begin
 I:=AddCtl(DC_EDIT,X,Y,W,14,'');
 Ctl[I].S:=S;
 If DlgFocus=0 Then DlgFocus:=I;
 AddEdit:=I;
End;

Function AddCheck(X,Y: Integer; Const T: String; V: Boolean): Integer;
Var I: Integer;
Begin
 I:=AddCtl(DC_CHECK,X,Y,Length(T)*8+18,12,T);
 Ctl[I].V:=Ord(V);
 AddCheck:=I;
End;

Function AddRadio(X,Y,Grp,Id: Integer; Const T: String): Integer;
Var I: Integer;
Begin
 I:=AddCtl(DC_RADIO,X,Y,Length(T)*8+18,12,T);
 Ctl[I].Grp:=Grp;Ctl[I].Id:=Id;
 AddRadio:=I;
End;

Function AddBtn(X,Y,W,Id: Integer; Const T: String): Integer;
Var I: Integer;
Begin
 I:=AddCtl(DC_BTN,X,Y,W,16,T);
 Ctl[I].Id:=Id;
 AddBtn:=I;
End;

Function AddPop(X,Y,W: Integer; Const Items: String; V: Integer): Integer;
Var I: Integer;
Begin
 I:=AddCtl(DC_POP,X,Y,W,14,'');
 Ctl[I].Items:=Items;Ctl[I].V:=V;
 AddPop:=I;
End;

Function AddSlider(X,Y,W,Mx,V: Integer): Integer;
Var I: Integer;
Begin
 I:=AddCtl(DC_SLIDER,X,Y,W,12,'');
 Ctl[I].Mx:=Mx;Ctl[I].V:=V;
 AddSlider:=I;
End;

Procedure AddStdBtns(Apply: Boolean);
Var X: Integer;
Begin
 X:=DlgW-12;
 X:=X-70;AddBtn(X,DlgH-26,70,ID_OK,'OK');Ctl[NCtl].Mx:=1;
 X:=X-78;AddBtn(X,DlgH-26,70,ID_CANCEL,L2('Cancel','Annuler'));
 If Apply Then Begin X:=X-78;AddBtn(X,DlgH-26,70,ID_APPLY,L2('Apply','Appliquer'));End;
End;

Function ItemOf(Const Items: String; N: Integer): String;
Var S: String; P,K: Integer;
Begin
 S:=Items;K:=0;
 Repeat
  P:=Pos('|',S);
  If P=0 Then Begin ItemOf:=S;If K=N Then Exit Else Begin ItemOf:='';Exit;End;End;
  If K=N Then Begin ItemOf:=Copy(S,1,P-1);Exit;End;
  Delete(S,1,P);Inc(K);
 Until False;
End;

Function ItemCount(Const Items: String): Integer;
Var I,C: Integer;
Begin
 C:=1;
 For I:=1 To Length(Items) Do If Items[I]='|' Then Inc(C);
 ItemCount:=C;
End;

{ Boite de choix (popup) : retourne -1 si annule, sinon l'index 0..N-1 }
Function PopupChoice(Const Items: String; X,Y,Start: Integer): Integer;
Var N,I,W,H,Sel,L: Integer; E: TEvent; Done: Boolean; Res: Integer; S: String;
Begin
 N:=ItemCount(Items);
 W:=0;
 For I:=0 To N-1 Do Begin
  L:=Length(ItemOf(Items,I))*8+16;
  If L>W Then W:=L;
 End;
 H:=N*13+4;
 If X+W>SCR_W-2 Then X:=SCR_W-2-W;
 If Y+H>SCR_H-2 Then Y:=SCR_H-2-H;
 If X<2 Then X:=2;
 If Y<2 Then Y:=2;
 Sel:=Start;Res:=-1;Done:=False;
 HideMouse;
 Repeat
  Box(X+3,Y+3,X+W+3,Y+H+3,INK);
  Box(X,Y,X+W,Y+H,PAPER);
  Frame(X,Y,X+W,Y+H);
  For I:=0 To N-1 Do Begin
   S:=ItemOf(Items,I);
   If I=Sel Then Begin
    Box(X+1,Y+2+I*13,X+W-1,Y+14+I*13,INK);
    WText(X+8,Y+5+I*13,S);
   End Else PText(X+8,Y+5+I*13,S);
  End;
  ShowMouse;
  Repeat
   PollEvent(E);
  Until E.Kind<>0;
  HideMouse;
  Case E.Kind Of
   1: Case E.Key Of
       K_UP: If Sel>0 Then Dec(Sel);
       K_DOWN: If Sel<N-1 Then Inc(Sel);
       K_ENTER: Begin Res:=Sel;Done:=True;End;
       K_ESC: Done:=True;
      End;
   2,4: If InBox(E.X,E.Y,X,Y+2,X+W,Y+H-2) Then Begin
       Sel:=(E.Y-Y-2) Div 13;
       If Sel>=N Then Sel:=N-1;
       If Sel<0 Then Sel:=0;
       If E.Kind=2 Then Begin Res:=Sel;Done:=True;End;
      End Else If E.Kind=2 Then Done:=True;
  End;
 Until Done;
 ShowMouse;
 PopupChoice:=Res;
End;

Procedure DrawDialog;
Var I,J,X,Y,T,B,Xs,Ys: Integer; C: TCtl; S: String; Lv: Integer;
Begin
 HideMouse;
 Box(DlgX+4,DlgY+4,DlgX+DlgW+4,DlgY+DlgH+4,INK);
 Box(DlgX,DlgY,DlgX+DlgW,DlgY+DlgH,CHROME);
 Frame(DlgX,DlgY,DlgX+DlgW,DlgY+DlgH);
 Frame(DlgX+1,DlgY+1,DlgX+DlgW-1,DlgY+DlgH-1);
 DrawWinTitle(DlgX+2,DlgY+2,DlgX+DlgW-2,DlgTitle,True);
 SetColor(INK);
 Line(DlgX+2,DlgY+18,DlgX+DlgW-2,DlgY+18);
 For I:=1 To NCtl Do Begin
  C:=Ctl[I];
  X:=DlgX+C.X;Y:=DlgY+C.Y;
  Case C.K Of
   DC_LABEL: PText(X,Y,C.T);
   DC_FRAME: Begin
     SetColor(8);Rectangle(X,Y,X+C.W,Y+C.H);
     Box(X+6,Y-4,X+10+Length(C.T)*8,Y+4,CHROME);
     PText(X+8,Y-3,C.T);
    End;
   DC_EDIT: Begin
     Box(X,Y,X+C.W,Y+13,PAPER);
     Frame(X,Y,X+C.W,Y+13);
     If (I=DlgFocus) And DlgFresh And (C.S<>'') Then Begin
      Box(X+1,Y+1,X+8*Length(Copy(C.S,1,C.W Div 8-1))+4,Y+12,INK);
      WText(X+3,Y+3,Copy(C.S,1,C.W Div 8-1));
     End Else Begin
      PText(X+3,Y+3,Copy(C.S,1,C.W Div 8-1));
      If I=DlgFocus Then
       PText(X+3+8*Length(Copy(C.S,1,C.W Div 8-1)),Y+3,'_');
     End;
    End;
   DC_CHECK: Begin
     Box(X,Y,X+10,Y+10,PAPER);Frame(X,Y,X+10,Y+10);
     If C.V<>0 Then Begin SetColor(INK);Line(X+1,Y+1,X+9,Y+9);Line(X+1,Y+9,X+9,Y+1);End;
     PText(X+16,Y+2,C.T);
    End;
   DC_RADIO: Begin
     SetColor(INK);Circle(X+5,Y+5,5);
     If RadioVal[C.Grp]=C.Id Then Begin
      SetFillStyle(SolidFill,INK);FillEllipse(X+5,Y+5,2,2);
     End;
     PText(X+16,Y+2,C.T);
    End;
   DC_BTN: Button(X,Y,X+C.W,Y+C.H,C.T,C.Mx=1,True);
   DC_POP: Begin
     Box(X,Y,X+C.W,Y+13,PAPER);Frame(X,Y,X+C.W,Y+13);
     Box(X+C.W+1,Y+2,X+C.W+2,Y+15,INK);
     Box(X+2,Y+14,X+C.W+2,Y+15,INK);
     PText(X+4,Y+3,Copy(ItemOf(C.Items,C.V),1,C.W Div 8-2));
     SetColor(INK);
     Line(X+C.W-10,Y+4,X+C.W-4,Y+4);Line(X+C.W-10,Y+4,X+C.W-7,Y+9);
     Line(X+C.W-4,Y+4,X+C.W-7,Y+9);
    End;
   DC_SLIDER: Begin
     Box(X,Y,X+C.W,Y+C.H,PAPER);Frame(X,Y,X+C.W,Y+C.H);
     If C.Mx>0 Then Lv:=Round(C.V/C.Mx*(C.W-12)) Else Lv:=0;
     Box(X+1+Lv,Y+1,X+11+Lv,Y+C.H-1,INK);
    End;
   DC_SWATCH: Begin
     Box(X,Y,X+C.W,Y+C.H,C.V);
     Frame(X,Y,X+C.W,Y+C.H);
     If C.Mx=1 Then Begin
      SetColor(NearestCol(MkRGB(255,255,255)));
      Rectangle(X+1,Y+1,X+C.W-1,Y+C.H-1);
      SetColor(INK);Rectangle(X+2,Y+2,X+C.W-2,Y+C.H-2);
     End;
    End;
   DC_COLBOX: Begin
     Box(X,Y,X+C.W,Y+C.H,NearestCol(C.V));Frame(X,Y,X+C.W,Y+C.H);
    End;
   DC_PATSEL: Begin
     For J:=1 To NPAT Do Begin
      Xs:=X+((J-1) Mod 8)*(C.W Div 8);Ys:=Y+((J-1) Div 8)*(C.W Div 8);
      Box(Xs,Ys,Xs+C.W Div 8-2,Ys+C.W Div 8-2,PAPER);
      For T:=0 To C.W Div 8-3 Do
       For B:=0 To C.W Div 8-3 Do
        If ((FillPats[J][T And 7] Shr (7-(B And 7))) And 1)<>0 Then
         PutPixel(Xs+B,Ys+T,INK);
      If J=C.V Then Begin
       SetColor(INK);Rectangle(Xs-1,Ys-1,Xs+C.W Div 8-1,Ys+C.W Div 8-1);
       Rectangle(Xs-2,Ys-2,Xs+C.W Div 8,Ys+C.W Div 8);
      End Else Begin
       SetColor(8);Rectangle(Xs,Ys,Xs+C.W Div 8-2,Ys+C.W Div 8-2);
      End;
     End;
    End;
   DC_LIST: Begin
     Box(X,Y,X+C.W,Y+C.H,PAPER);Frame(X,Y,X+C.W,Y+C.H);
     For J:=0 To C.H Div 12-1 Do
      If C.Mx+J+1<=LstN Then Begin
       If C.Mx+J+1=C.V Then Begin
        Box(X+1,Y+1+J*12,X+C.W-17,Y+12+J*12,INK);
        WText(X+4,Y+3+J*12,Copy(LstItem[C.Mx+J+1],1,(C.W-24) Div 8));
       End Else PText(X+4,Y+3+J*12,Copy(LstItem[C.Mx+J+1],1,(C.W-24) Div 8));
      End;
     Box(X+C.W-16,Y+1,X+C.W-1,Y+14,CHROME);Frame(X+C.W-16,Y+1,X+C.W-1,Y+14);
     DrawGlyph(81,X+C.W-18,Y-3,INK);
     Box(X+C.W-16,Y+C.H-14,X+C.W-1,Y+C.H-1,CHROME);
     Frame(X+C.W-16,Y+C.H-14,X+C.W-1,Y+C.H-1);
     DrawGlyph(82,X+C.W-18,Y+C.H-18,INK);
    End;
  End;
 End;
 ShowMouse;
End;

{ Execute la boite : retourne l'Id du bouton active (ID_OK, ID_CANCEL, ...) }
Function RunDialog: Integer;
Var E: TEvent; I,Res,J,Lv,Sel: Integer; Done,Redraw: Boolean; C: ^TCtl;
 Ch: Char; Rows: Integer; R2: Integer; LastT: LongInt;
 Function CtlAt(X,Y: Integer): Integer;
 Var K: Integer;
 Begin
  CtlAt:=0;
  For K:=NCtl DownTo 1 Do Begin
   Case Ctl[K].K Of
    DC_LABEL,DC_FRAME,DC_COLBOX: Continue;
    DC_PATSEL: If InBox(X,Y,DlgX+Ctl[K].X,DlgY+Ctl[K].Y,DlgX+Ctl[K].X+Ctl[K].W,
       DlgY+Ctl[K].Y+(NPAT Div 8)*(Ctl[K].W Div 8)) Then Begin CtlAt:=K;Exit;End;
    DC_POP: If InBox(X,Y,DlgX+Ctl[K].X,DlgY+Ctl[K].Y,DlgX+Ctl[K].X+Ctl[K].W,
       DlgY+Ctl[K].Y+14) Then Begin CtlAt:=K;Exit;End;
    Else If InBox(X,Y,DlgX+Ctl[K].X,DlgY+Ctl[K].Y,DlgX+Ctl[K].X+Ctl[K].W,
       DlgY+Ctl[K].Y+Ctl[K].H) Then Begin CtlAt:=K;Exit;End;
   End;
  End;
 End;
 Procedure NextEdit(Dir: Integer);
 Var K,N: Integer;
 Begin
  N:=0;K:=DlgFocus;
  If K=0 Then K:=1;
  Repeat
   K:=K+Dir;
   If K>NCtl Then K:=1;
   If K<1 Then K:=NCtl;
   Inc(N);
   If Ctl[K].K=DC_EDIT Then Begin DlgFocus:=K;DlgFresh:=True;Exit;End;
  Until N>NCtl;
 End;
Begin
 Res:=0;Done:=False;Redraw:=True;
 Repeat
  If Redraw Then Begin
   If DlgHookId<>0 Then DlgHookProc;
   DrawDialog;Redraw:=False;
  End;
  PollEvent(E);
  Case E.Kind Of
   1: Begin
       Case E.Key Of
        K_ENTER: Begin
          Res:=ID_OK;
          For I:=1 To NCtl Do
           If (Ctl[I].K=DC_BTN) And (Ctl[I].Mx=1) Then Res:=Ctl[I].Id;
          Done:=True;
         End;
        K_ESC: Begin Res:=ID_CANCEL;Done:=True;End;
        K_TAB,K_DOWN: Begin NextEdit(1);Redraw:=True;End;
        K_STAB,K_UP: Begin NextEdit(-1);Redraw:=True;End;
        K_BKSP: If DlgFocus>0 Then Begin
          If DlgFresh Then Ctl[DlgFocus].S:=''
          Else If Length(Ctl[DlgFocus].S)>0 Then Dec(Ctl[DlgFocus].S[0]);
          DlgFresh:=False;Redraw:=True;
         End;
        K_DEL: If DlgFocus>0 Then Begin
          Ctl[DlgFocus].S:='';DlgFresh:=False;Redraw:=True;End;
        32..255: If (DlgFocus>0) Then Begin
          If DlgFresh Then Ctl[DlgFocus].S:='';
          DlgFresh:=False;
          If Length(Ctl[DlgFocus].S)<Ctl[DlgFocus].W Div 8-1 Then
            Ctl[DlgFocus].S:=Ctl[DlgFocus].S+Chr(E.Key);
          Redraw:=True;
         End;
       End;
      End;
   2: Begin
       I:=CtlAt(E.X,E.Y);
       If (I=0) And InBox(E.X,E.Y,DlgX+4,DlgY+4,DlgX+15,DlgY+15) Then Begin
        Res:=ID_CANCEL;Done:=True;
       End;
       If I>0 Then Begin
        C:=@Ctl[I];
        Case C^.K Of
         DC_EDIT: Begin DlgFocus:=I;DlgFresh:=False;Redraw:=True;End;
         DC_CHECK: Begin C^.V:=1-C^.V;Redraw:=True;End;
         DC_RADIO: Begin RadioVal[C^.Grp]:=C^.Id;Redraw:=True;End;
         DC_BTN: Begin Res:=C^.Id;Done:=True;End;
         DC_SWATCH: Begin Res:=C^.Id;Done:=True;End;
         DC_POP: Begin
           J:=PopupChoice(C^.Items,DlgX+C^.X,DlgY+C^.Y+14,C^.V);
           If J>=0 Then C^.V:=J;
           Redraw:=True;
          End;
         DC_SLIDER: Begin
           Lv:=Round((E.X-(DlgX+C^.X)-6)/(C^.W-12)*C^.Mx);
           C^.V:=Clamp(Lv,0,C^.Mx);
           Redraw:=True;
          End;
         DC_PATSEL: Begin
           J:=((E.X-(DlgX+C^.X)) Div (C^.W Div 8))+
              ((E.Y-(DlgY+C^.Y)) Div (C^.W Div 8))*8+1;
           If (J>=1) And (J<=NPAT) Then C^.V:=J;
           Redraw:=True;
          End;
         DC_LIST: Begin
           Rows:=C^.H Div 12;
           If E.X>DlgX+C^.X+C^.W-17 Then Begin
            If E.Y<DlgY+C^.Y+C^.H Div 2 Then Begin
             If C^.Mx>0 Then Dec(C^.Mx);
            End Else If C^.Mx+Rows<LstN Then Inc(C^.Mx);
           End Else Begin
            Sel:=C^.Mx+((E.Y-(DlgY+C^.Y+1)) Div 12)+1;
            If (Sel>=1) And (Sel<=LstN) Then Begin
             If (Sel=C^.V) And (Tick-LastT<40) And (C^.Id<>0) Then Begin
              Res:=C^.Id;Done:=True;End;
             C^.V:=Sel;LastT:=Tick;
            End;
           End;
           Redraw:=True;
          End;
        End;
       End;
      End;
   4: If (E.B And 1)<>0 Then Begin
       I:=CtlAt(E.X,E.Y);
       If (I>0) And (Ctl[I].K=DC_SLIDER) Then Begin
        C:=@Ctl[I];
        Lv:=Round((E.X-(DlgX+C^.X)-6)/(C^.W-12)*C^.Mx);
        If Clamp(Lv,0,C^.Mx)<>C^.V Then Begin
         C^.V:=Clamp(Lv,0,C^.Mx);Redraw:=True;
        End;
       End;
      End;
  End;
 Until Done;
 RunDialog:=Res;
 NeedDraw:=True;
End;

Procedure MsgBox(Const Title,Txt: String);
Var I,N,P: Integer; S: String; W,H,Y: Integer;
Begin
 S:=Txt;N:=0;
 DlgInit(Title,360,60);
 W:=0;
 While S<>'' Do Begin
  P:=Pos('|',S);
  Inc(N);
  If P=0 Then Begin AddLabel(14,28+(N-1)*12,S);If Length(S)*8>W Then W:=Length(S)*8;S:='';End
  Else Begin
   AddLabel(14,28+(N-1)*12,Copy(S,1,P-1));
   If (P-1)*8>W Then W:=(P-1)*8;
   Delete(S,1,P);
  End;
 End;
 DlgW:=W+40;
 If DlgW<220 Then DlgW:=220;
 DlgH:=N*12+68;
 DlgX:=(SCR_W-DlgW) Div 2;DlgY:=(SCR_H-DlgH) Div 2;
 AddBtn((DlgW-70) Div 2,DlgH-26,70,ID_OK,'OK');
 Ctl[NCtl].Mx:=1;
 RunDialog;
End;

{ Retourne 1 = Oui, 2 = Non, 0 = Annuler }
Function ConfirmBox(Const Txt: String): Boolean;
Begin
 DlgInit('ArtWorx',Length(Txt)*8+40,70);
 If DlgW<260 Then DlgW:=260;
 DlgX:=(SCR_W-DlgW) Div 2;
 AddLabel(16,30,Txt);
 AddBtn(DlgW-12-70,DlgH-26,70,ID_OK,L2('Yes','Oui'));
 Ctl[NCtl].Mx:=1;
 AddBtn(DlgW-12-148,DlgH-26,70,ID_CANCEL,L2('No','Non'));
 ConfirmBox:=(RunDialog=ID_OK);
End;

{ Boite : Abandon / Enregistrer / Annuler }
Function AskSave(Const Txt: String): Integer;
Var R: Integer;
Begin
 DlgInit(L2('Close file','Fermer le fichier'),Length(Txt)*8+40,70);
 If DlgW<300 Then DlgW:=300;
 DlgX:=(SCR_W-DlgW) Div 2;
 AddLabel(16,30,Txt);
 AddBtn(DlgW-12-70,DlgH-26,70,ID_OK,L2('Save','Enreg.'));
 Ctl[NCtl].Mx:=1;
 AddBtn(DlgW-12-148,DlgH-26,70,4,L2('Abandon','Abandon'));
 AddBtn(DlgW-12-226,DlgH-26,70,ID_CANCEL,L2('Cancel','Annuler'));
 R:=RunDialog;
 Case R Of
  ID_OK: AskSave:=1;
  4: AskSave:=2;
  Else AskSave:=0;
 End;
End;

Function InputBox(Const Title,Prompt: String; Var S: String; MaxLen: Integer): Boolean;
Var I: Integer;
Begin
 DlgInit(Title,Max2(300,Length(Prompt)*8+MaxLen*8+50),80);
 If MaxLen>40 Then MaxLen:=40;
 DlgW:=Max2(300,Length(Prompt)*8+MaxLen*8+50);
 DlgX:=(SCR_W-DlgW) Div 2;
 AddLabel(14,32,Prompt);
 I:=AddEdit(14+Length(Prompt)*8+8,28,MaxLen*8+8,S);
 AddStdBtns(False);
 If RunDialog=ID_OK Then Begin
  S:=Ctl[I].S;
  InputBox:=True;
 End Else InputBox:=False;
End;

{ Selection de fichier : liste des fichiers correspondant au masque }
Procedure ScanFiles(Const Mask: String);
Var SR: SearchRec; I: Integer; Dup: Boolean;
Begin
 FindFirst(Mask,AnyFile-Directory,SR);
 While (DosError=0) And (LstN<78) Do Begin
  Dup:=False;
  For I:=1 To LstN Do If LstItem[I]=Copy(SR.Name,1,40) Then Dup:=True;
  If Not Dup Then Begin
   Inc(LstN);
   LstItem[LstN]:=Copy(SR.Name,1,40);
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
End;

Function FileSelect(Const Title,Mask: String; Var Name: String): Boolean;
Var I,L: Integer; S,Pth,Orig: String;
Begin
 FileSelect:=False;
 Pth:=OptImages;
 LstN:=0;
 ScanFiles(Pth+Mask);
 If Lower(Mask)<>Mask Then ScanFiles(Pth+Lower(Mask));
 Orig:=Name;
 DlgInit(Title+' ('+Mask+')',340,230);
 L:=AddCtl(DC_LIST,14,34,312,132,'');
 Ctl[L].V:=1;Ctl[L].Id:=ID_OK;
 AddLabel(14,174,L2('Name:','Nom :'));
 I:=AddEdit(70,170,256,Name);
 DlgFocus:=I;DlgFresh:=True;
 AddStdBtns(False);
 If RunDialog=ID_OK Then Begin
  S:=Ctl[I].S;
  If (S=Orig) Or (S='') Then
   If (LstN>0) And (Ctl[L].V>=1) And (Ctl[L].V<=LstN) Then
     S:=Pth+LstItem[Ctl[L].V];
  If S<>'' Then Begin Name:=S;FileSelect:=True;End;
 End;
End;

{ ====================================================================== }
{                  FICHIERS : FORMAT NATIF CWG, EXPORTS, IMPORTS         }
{ ====================================================================== }

Const
 HexC: String[16] = '0123456789ABCDEF';

Function Hex2(B: Integer): String;
Begin
 Hex2:=HexC[(B Shr 4) And 15+1]+HexC[B And 15+1];
End;

Function HexVal(C: Char): Integer;
Begin
 If (C>='0') And (C<='9') Then HexVal:=Ord(C)-48
 Else If (C>='A') And (C<='F') Then HexVal:=Ord(C)-55
 Else If (C>='a') And (C<='f') Then HexVal:=Ord(C)-87
 Else HexVal:=0;
End;

Function NextTok(Var S: String): String;
Var P: Integer;
Begin
 While (S<>'') And (S[1]=' ') Do Delete(S,1,1);
 P:=Pos(' ',S);
 If P=0 Then Begin NextTok:=S;S:='';End
 Else Begin NextTok:=Copy(S,1,P-1);Delete(S,1,P);End;
End;

Function TokInt(Var S: String): LongInt;
Var V: LongInt; Code: Integer; T: String;
Begin
 T:=NextTok(S);
 Val(T,V,Code);
 If Code<>0 Then V:=0;
 TokInt:=V;
End;

Function TokReal(Var S: String): Double;
Var V: Double; Code: Integer; T: String;
Begin
 T:=NextTok(S);
 Val(T,V,Code);
 If Code<>0 Then V:=0;
 TokReal:=V;
End;

Function ObjFlags(O: PObj): Integer;
Var F: Integer;
Begin
 F:=0;
 If O^.Locked Then F:=F Or 1;
 If O^.OnScreen Then F:=F Or 2;
 If O^.Outline Then F:=F Or 4;
 If O^.PropRes Then F:=F Or 8;
 If O^.NoRes Then F:=F Or 16;
 ObjFlags:=F;
End;

Function SaveCWG(Const FNm: String; OnlySel: Boolean): Boolean;
Var F: Text; I,J,R,C: Integer; O: PObj; S,Ln: String;
Begin
 SaveCWG:=False;
 {$I-}
 Assign(F,FNm);
 Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(F,'ARTWORX 1');
 WriteLn(F,'D ',RealStr(PageW,2),' ',RealStr(PageH,2),' ',NPages,' ',
   RealStr(GridX,2),' ',RealStr(GridY,2),' ',Ord(GridShow),' ',Ord(GridSnap));
 For I:=1 To NLAYER Do
  WriteLn(F,'Y ',I,' ',Ord(Layers[I].Hidden),' ',Ord(Layers[I].Locked),' ',
    Ord(Layers[I].OnScreen),' ',Layers[I].Name);
 For I:=1 To NObj Do Begin
  O:=Objs[I];
  If OnlySel And Not O^.Sel Then Continue;
  WriteLn(F,'O ',O^.Kind,' ',Ord(O^.Closed),' ',O^.N,' ',O^.Layer,' ',O^.Page,' ',
    O^.Group,' ',ObjFlags(O),' ',O^.LineCol,' ',O^.FillCol,' ',O^.ShCol,' ',
    RealStr(O^.LineW,3),' ',O^.LineSty,' ',O^.EndS,' ',O^.EndE,' ',O^.FillMode,
    ' ',O^.FillPat,' ',O^.Grey,' ',Ord(O^.ShOn),' ',RealStr(O^.ShDX,2),' ',
    RealStr(O^.ShDY,2),' ',RealStr(O^.FSize,2),' ',O^.TFlags,' ',O^.TAlign,' ',
    RealStr(O^.Rad,3),' ',RealStr(O^.A1,3),' ',RealStr(O^.A2,3),' ',O^.BW,' ',
    O^.BH);
  For J:=0 To O^.N-1 Do
   With O^.Nd^[J] Do
    WriteLn(F,'N ',RealStr(X,4),' ',RealStr(Y,4),' ',RealStr(AX,4),' ',
      RealStr(AY,4),' ',RealStr(BX,4),' ',RealStr(BY,4),' ',Kind);
  If O^.Txt<>Nil Then Begin
   S:=O^.Txt^;Ln:='';
   For J:=1 To Length(S) Do Ln:=Ln+Hex2(Ord(S[J]));
   WriteLn(F,'T ',Ln);
  End;
  If O^.BPix<>Nil Then
   For R:=0 To O^.BH-1 Do Begin
    Ln:='';
    For C:=0 To O^.BW-1 Do Ln:=Ln+HexC[O^.BPix^[R*O^.BW+C] And 15+1];
    WriteLn(F,'B ',Ln);
   End;
  WriteLn(F,'E');
 End;
 WriteLn(F,'Z');
 Close(F);
 SaveCWG:=(IOResult=0);
End;

Function LoadCWG(Const FNm: String; Append: Boolean): Boolean;
Var F: Text; Ln,T: String; P: PObj; Row,J: Integer; Tx: String; Ok: Boolean;
 N0,I,K: Integer; X: Double; Hdr: Boolean; Code: Integer;
Begin
 LoadCWG:=False;
 {$I-}
 Assign(F,FNm);
 Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 ReadLn(F,Ln);
 If Copy(Ln,1,7)<>'ARTWORX' Then Begin Close(F);Exit;End;
 If Not Append Then Begin
  ClearDoc;
  For I:=1 To NLAYER Do Begin
   Layers[I].Hidden:=False;Layers[I].Locked:=False;Layers[I].OnScreen:=False;
   Layers[I].Name:='Layer '+IntStr(I);
  End;
 End;
 P:=Nil;
 While Not Eof(F) Do Begin
  ReadLn(F,Ln);
  If Ln='' Then Continue;
  T:=Copy(Ln,3,255);
  Case Ln[1] Of
   'D': If Not Append Then Begin
         PageW:=TokReal(T);PageH:=TokReal(T);NPages:=TokInt(T);
         GridX:=TokReal(T);GridY:=TokReal(T);
         GridShow:=TokInt(T)<>0;GridSnap:=TokInt(T)<>0;
         If NPages<1 Then NPages:=1;
        End;
   'Y': If Not Append Then Begin
         I:=TokInt(T);
         If (I>=1) And (I<=NLAYER) Then Begin
          Layers[I].Hidden:=TokInt(T)<>0;
          Layers[I].Locked:=TokInt(T)<>0;
          Layers[I].OnScreen:=TokInt(T)<>0;
          Layers[I].Name:=Copy(T,1,20);
         End;
        End;
   'O': Begin
         New(P);
         FillChar(P^,SizeOf(TObj),0);
         P^.Kind:=TokInt(T);P^.Closed:=TokInt(T)<>0;
         N0:=TokInt(T);
         SetCap(P,N0+4);
         P^.N:=0;
         P^.Layer:=Clamp(TokInt(T),1,NLAYER);P^.Page:=Clamp(TokInt(T),1,MAXPAGE);
         P^.Group:=TokInt(T);
         K:=TokInt(T);
         P^.Locked:=(K And 1)<>0;P^.OnScreen:=(K And 2)<>0;
         P^.Outline:=(K And 4)<>0;P^.PropRes:=(K And 8)<>0;P^.NoRes:=(K And 16)<>0;
         P^.LineCol:=TokInt(T);P^.FillCol:=TokInt(T);P^.ShCol:=TokInt(T);
         P^.LineW:=TokReal(T);P^.LineSty:=TokInt(T);P^.EndS:=TokInt(T);
         P^.EndE:=TokInt(T);P^.FillMode:=TokInt(T);P^.FillPat:=TokInt(T);
         P^.Grey:=TokInt(T);P^.ShOn:=TokInt(T)<>0;P^.ShDX:=TokReal(T);
         P^.ShDY:=TokReal(T);P^.FSize:=TokReal(T);P^.TFlags:=TokInt(T);
         P^.TAlign:=TokInt(T);P^.Rad:=TokReal(T);P^.A1:=TokReal(T);
         P^.A2:=TokReal(T);P^.BW:=TokInt(T);P^.BH:=TokInt(T);
         If (P^.BW>BMPMAXW) Or (P^.BH>BMPMAXH) Or (P^.BW<0) Or (P^.BH<0) Then Begin
          P^.BW:=0;P^.BH:=0;End;
         Row:=0;
         If (P^.BW>0) And (P^.BH>0) Then Begin
          GetMem(P^.BPix,P^.BW*P^.BH);
          FillChar(P^.BPix^,P^.BW*P^.BH,15);
         End;
         If Append And (P^.Page>NPages) Then P^.Page:=CurPage;
        End;
   'N': If (P<>Nil) And (P^.N<P^.Cap) Then Begin
         With P^.Nd^[P^.N] Do Begin
          X:=TokReal(T);Y:=TokReal(T);AX:=TokReal(T);AY:=TokReal(T);
          BX:=TokReal(T);BY:=TokReal(T);Kind:=TokInt(T);
         End;
         Inc(P^.N);
        End;
   'T': If P<>Nil Then Begin
         Tx:='';J:=1;
         While J+1<=Length(T) Do Begin
          Tx:=Tx+Chr(HexVal(T[J])*16+HexVal(T[J+1]));
          Inc(J,2);
         End;
         SetTxt(P,Tx);
        End;
   'B': If (P<>Nil) And (P^.BPix<>Nil) And (Row<P^.BH) Then Begin
         For J:=1 To Min2(Length(T),P^.BW) Do
          P^.BPix^[Row*P^.BW+J-1]:=HexVal(T[J]);
         Inc(Row);
        End;
   'E': If P<>Nil Then Begin
         If (P^.N>=1) And (NObj<MAXOBJ) Then Begin
          Inc(NObj);Objs[NObj]:=P;
         End Else FreeObj(P);
         P:=Nil;
        End;
  End;
 End;
 If P<>Nil Then FreeObj(P);
 Close(F);
 LoadCWG:=True;
End;

{ ---- annulation par instantanes sur disque ---- }
Function UndoName(K: Integer): String;
Begin
 UndoName:='ARTWU'+IntStr(K)+'.TMP';
End;

Procedure PushUndo;
Begin
 If Not OptUndo Then Exit;
 If SaveCWG(UndoName(UndoSeq Mod MAXUNDO),False) Then Begin
  Inc(UndoSeq);
  If UndoN<MAXUNDO Then Inc(UndoN);
 End;
End;

Procedure DoUndo;
Var Pg: Integer;
Begin
 If UndoN<=0 Then Exit;
 Dec(UndoSeq);Dec(UndoN);
 Pg:=CurPage;
 If LoadCWG(UndoName(UndoSeq Mod MAXUNDO),False) Then Begin
  If Pg>NPages Then Pg:=NPages;
  CurPage:=Pg;
  Modified:=True;
  PathObj:=Nil;
 End;
 NeedDraw:=True;
End;

Procedure CleanUndo;
Var F: File; I: Integer;
Begin
 For I:=0 To MAXUNDO-1 Do Begin
  {$I-}
  Assign(F,UndoName(I));
  Erase(F);
  {$I+}
  If IOResult<>0 Then ;
 End;
End;

{ ---- export PostScript / SVG / texte ---- }

Const PTMM = 2.834646;

Function PsStr(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:='';
 For I:=1 To Length(S) Do Begin
  If S[I] In ['(',')','\'] Then R:=R+'\';
  If Ord(S[I])>=32 Then R:=R+S[I];
 End;
 PsStr:=R;
End;

Function PsCol(C: LongInt): String;
Begin
 PsCol:=RealStr(CR(C)/255,3)+' '+RealStr(CG(C)/255,3)+' '+RealStr(CB(C)/255,3)+
   ' setrgbcolor';
End;

Function PatDensity(O: PObj): Double;
Var I,J,C: Integer; Pat: TPat;
Begin
 If O^.FillMode=2 Then Begin PatDensity:=O^.Grey/255;Exit;End;
 Pat:=FillPats[Clamp(O^.FillPat,1,NPAT)];
 C:=0;
 For I:=0 To 7 Do For J:=0 To 7 Do
  If ((Pat[I] Shr J) And 1)<>0 Then Inc(C);
 PatDensity:=C/64;
End;

Procedure PsPath(Var F: Text; PH: Double);
Var S,I: Integer;
Begin
 For S:=0 To NSub-1 Do Begin
  For I:=SubS[S] To SubS[S+1]-1 Do Begin
   Write(F,RealStr(FP^[I].X*PTMM,2),' ',RealStr((PH-FP^[I].Y)*PTMM,2));
   If I=SubS[S] Then WriteLn(F,' moveto') Else WriteLn(F,' lineto');
  End;
  If SubC[S] Then WriteLn(F,'closepath');
 End;
End;

Procedure PsObject(Var F: Text; O: PObj);
Var Dn: Double; I,J,R,C,Run,Cur: Integer; Cell,Ang: Double; Cols,Rows,L,P: Integer;
 S,Ln: String; X1,Y1,X2,Y2,PW,PHt: Double; Col: LongInt;
Begin
 PHt:=PageH;
 If O^.OnScreen Or Layers[O^.Layer].Hidden Or Layers[O^.Layer].OnScreen Then Exit;
 If O^.Kind In [OK_TEXT,OK_FTEXT] Then Begin
  WriteLn(F,PsCol(O^.LineCol));
  If O^.Kind=OK_TEXT Then Begin
   Cell:=Hypot(O^.Nd^[2].X-O^.Nd^[0].X,O^.Nd^[2].Y-O^.Nd^[0].Y);
   Ang:=ArcTan2(-(O^.Nd^[1].Y-O^.Nd^[0].Y),O^.Nd^[1].X-O^.Nd^[0].X)*180/Pi;
   S:=TxtOf(O);P:=1;J:=0;
   Repeat
    L:=P;
    While (L<=Length(S)) And (S[L]<>#10) Do Inc(L);
    WriteLn(F,'/Courier findfont ',RealStr(Cell*PTMM*0.95,2),' scalefont setfont');
    WriteLn(F,'gsave ',RealStr(O^.Nd^[0].X*PTMM,2),' ',
      RealStr((PHt-O^.Nd^[0].Y)*PTMM,2),' translate ',RealStr(Ang,2),
      ' rotate 0 ',RealStr(-(Cell*0.85+J*Cell*1.25)*PTMM,2),' moveto (',
      PsStr(Copy(S,P,L-P)),') show grestore');
    Inc(J);P:=L+1;
   Until P>Length(S)+1;
  End Else Begin
   Cell:=O^.FSize*25.4/72;
   LayoutFrame(O,Trunc(Hypot(O^.Nd^[1].X-O^.Nd^[0].X,O^.Nd^[1].Y-O^.Nd^[0].Y)/
     MaxD(Cell,0.5)));
   For I:=1 To FtN Do Begin
    WriteLn(F,'/Courier findfont ',RealStr(Cell*PTMM*0.95,2),' scalefont setfont');
    WriteLn(F,'gsave ',RealStr(O^.Nd^[0].X*PTMM,2),' ',
      RealStr((PHt-O^.Nd^[0].Y)*PTMM,2),' translate 0 ',
      RealStr(-(Cell*0.85+(I-1)*Cell*1.25)*PTMM,2),' moveto (',
      PsStr(FtL[I]),') show grestore');
   End;
  End;
  Exit;
 End;
 If O^.Kind=OK_BITMAP Then Begin
  If O^.BPix=Nil Then Exit;
  X1:=1E30;Y1:=1E30;X2:=-1E30;Y2:=-1E30;
  For I:=0 To 3 Do Begin
   If O^.Nd^[I].X<X1 Then X1:=O^.Nd^[I].X;
   If O^.Nd^[I].X>X2 Then X2:=O^.Nd^[I].X;
   If O^.Nd^[I].Y<Y1 Then Y1:=O^.Nd^[I].Y;
   If O^.Nd^[I].Y>Y2 Then Y2:=O^.Nd^[I].Y;
  End;
  For R:=0 To O^.BH-1 Do Begin
   C:=0;
   While C<O^.BW Do Begin
    Cur:=O^.BPix^[R*O^.BW+C];Run:=C;
    While (Run<O^.BW) And (O^.BPix^[R*O^.BW+Run]=Cur) Do Inc(Run);
    If Cur<>15 Then Begin
     WriteLn(F,PsCol(PalRGB(Cur)));
     WriteLn(F,RealStr((X1+(X2-X1)*C/O^.BW)*PTMM,2),' ',
       RealStr((PHt-(Y1+(Y2-Y1)*(R+1)/O^.BH))*PTMM,2),' ',
       RealStr((X2-X1)*(Run-C)/O^.BW*PTMM+0.3,2),' ',
       RealStr((Y2-Y1)/O^.BH*PTMM+0.3,2),' rectfill');
    End;
    C:=Run;
   End;
  End;
  Exit;
 End;
 FlattenObj(O,4);
 If O^.ShOn Then Begin
  WriteLn(F,'gsave ',RealStr(O^.ShDX*PTMM,2),' ',RealStr(-O^.ShDY*PTMM,2),
    ' translate newpath');
  PsPath(F,PHt);
  WriteLn(F,PsCol(O^.ShCol),' ',Ord(O^.FillMode<>0)*0,' pop');
  If (O^.FillMode<>0) And IsFilledKind(O^.Kind) Then WriteLn(F,'fill')
  Else WriteLn(F,RealStr(MaxD(O^.LineW,0.2)*PTMM,2),' setlinewidth stroke');
  WriteLn(F,'grestore');
 End;
 If (O^.FillMode<>0) And IsFilledKind(O^.Kind) Then Begin
  Dn:=PatDensity(O);
  Col:=LerpCol(MkRGB(255,255,255),O^.FillCol,Dn);
  WriteLn(F,'newpath');
  PsPath(F,PHt);
  WriteLn(F,PsCol(Col),' eofill');
 End;
 If O^.LineW>=0 Then Begin
  WriteLn(F,'newpath');
  PsPath(F,PHt);
  WriteLn(F,PsCol(O^.LineCol));
  WriteLn(F,RealStr(MaxD(O^.LineW,0.15)*PTMM,2),' setlinewidth');
  Case O^.LineSty Of
   1: WriteLn(F,'[4 3] 0 setdash');
   2: WriteLn(F,'[1 2] 0 setdash');
   3: WriteLn(F,'[5 2 1 2] 0 setdash');
   4: WriteLn(F,'[8 2 1 2 1 2] 0 setdash');
   5: WriteLn(F,'[2 2] 0 setdash');
   6: WriteLn(F,'[6 3 1 3] 0 setdash');
   Else WriteLn(F,'[] 0 setdash');
  End;
  WriteLn(F,'stroke [] 0 setdash');
 End;
End;

Function ExportPS(Const FNm: String; AllPages,Eps: Boolean): Boolean;
Var F: Text; I,Pg,P0,P1,Sv: Integer;
Begin
 ExportPS:=False;
 {$I-}
 Assign(F,FNm);
 Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 If Eps Then WriteLn(F,'%!PS-Adobe-3.0 EPSF-3.0') Else WriteLn(F,'%!PS-Adobe-3.0');
 WriteLn(F,'%%BoundingBox: 0 0 ',Round(PageW*PTMM),' ',Round(PageH*PTMM));
 WriteLn(F,'%%Creator: ArtWorx (clone)');
 If AllPages Then WriteLn(F,'%%Pages: ',NPages) Else WriteLn(F,'%%Pages: 1');
 WriteLn(F,'%%EndComments');
 Sv:=CurPage;
 If AllPages Then Begin P0:=1;P1:=NPages;End Else Begin P0:=CurPage;P1:=CurPage;End;
 For Pg:=P0 To P1 Do Begin
  CurPage:=Pg;
  WriteLn(F,'%%Page: ',Pg,' ',Pg);
  WriteLn(F,'gsave');
  For I:=1 To NObj Do
   If Objs[I]^.Page=Pg Then PsObject(F,Objs[I]);
  WriteLn(F,'grestore');
  If Not Eps Then WriteLn(F,'showpage');
 End;
 CurPage:=Sv;
 If Eps Then WriteLn(F,'showpage');
 WriteLn(F,'%%EOF');
 Close(F);
 ExportPS:=(IOResult=0);
End;

Function SvgCol(C: LongInt): String;
Begin
 SvgCol:='#'+Hex2(CR(C))+Hex2(CG(C))+Hex2(CB(C));
End;

Function ExportSVG(Const FNm: String): Boolean;
Var F: Text; I,S,J: Integer; O: PObj; D: String; Dn: Double; Cell,Ang: Double;
 Sx: String; P,L,K: Integer;
Begin
 ExportSVG:=False;
 {$I-}
 Assign(F,FNm);
 Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(F,'<?xml version="1.0" encoding="UTF-8"?>');
 WriteLn(F,'<svg xmlns="http://www.w3.org/2000/svg" width="',RealStr(PageW,1),
   'mm" height="',RealStr(PageH,1),'mm" viewBox="0 0 ',RealStr(PageW,2),' ',
   RealStr(PageH,2),'">');
 WriteLn(F,'<rect width="100%" height="100%" fill="#ffffff"/>');
 For I:=1 To NObj Do Begin
  O:=Objs[I];
  If (O^.Page<>CurPage) Or O^.OnScreen Or Layers[O^.Layer].Hidden Then Continue;
  If O^.Kind=OK_TEXT Then Begin
   Cell:=Hypot(O^.Nd^[2].X-O^.Nd^[0].X,O^.Nd^[2].Y-O^.Nd^[0].Y);
   Ang:=ArcTan2(O^.Nd^[1].Y-O^.Nd^[0].Y,O^.Nd^[1].X-O^.Nd^[0].X)*180/Pi;
   Sx:=TxtOf(O);P:=1;K:=0;
   Repeat
    L:=P;
    While (L<=Length(Sx)) And (Sx[L]<>#10) Do Inc(L);
    WriteLn(F,'<text x="0" y="',RealStr(Cell*0.85+K*Cell*1.25,2),
      '" font-family="monospace" font-size="',RealStr(Cell,2),'" fill="',
      SvgCol(O^.LineCol),'" transform="translate(',RealStr(O^.Nd^[0].X,2),',',
      RealStr(O^.Nd^[0].Y,2),') rotate(',RealStr(Ang,2),')">',
      Copy(Sx,P,L-P),'</text>');
    Inc(K);P:=L+1;
   Until P>Length(Sx)+1;
   Continue;
  End;
  If O^.Kind In [OK_FTEXT,OK_BITMAP] Then Begin
   FlattenObj(O,1);
  End Else FlattenObj(O,4);
  D:='';
  For S:=0 To NSub-1 Do Begin
   For J:=SubS[S] To SubS[S+1]-1 Do Begin
    If J=SubS[S] Then D:=D+'M' Else D:=D+'L';
    D:=D+RealStr(FP^[J].X,2)+' '+RealStr(FP^[J].Y,2)+' ';
    If Length(D)>200 Then Begin Write(F,D);D:='';End;
   End;
   If SubC[S] Then D:=D+'Z ';
  End;
  If (O^.FillMode<>0) And IsFilledKind(O^.Kind) Then Begin
   Dn:=PatDensity(O);
   Write(F,'<path fill="',SvgCol(LerpCol(MkRGB(255,255,255),O^.FillCol,Dn)),'" ')
  End Else Write(F,'<path fill="none" ');
  If O^.LineW>=0 Then
   Write(F,'stroke="',SvgCol(O^.LineCol),'" stroke-width="',
     RealStr(MaxD(O^.LineW,0.15),2),'" ');
  WriteLn(F,'fill-rule="evenodd" d="',D,'"/>');
 End;
 WriteLn(F,'</svg>');
 Close(F);
 ExportSVG:=(IOResult=0);
End;

Function ExportASCII(Const FNm: String): Boolean;
Var F: Text; I,P,L: Integer; S: String;
Begin
 ExportASCII:=False;
 {$I-}
 Assign(F,FNm);
 Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 For I:=1 To NObj Do
  If (Objs[I]^.Kind In [OK_TEXT,OK_FTEXT]) And (Objs[I]^.Page=CurPage) Then Begin
   S:=TxtOf(Objs[I]);
   P:=1;
   Repeat
    L:=P;
    While (L<=Length(S)) And (S[L]<>#10) Do Inc(L);
    WriteLn(F,Copy(S,P,L-P));
    P:=L+1;
   Until P>Length(S)+1;
  End;
 Close(F);
 ExportASCII:=(IOResult=0);
End;

{ ---- import d'images BMP (1,4,8,24 bits non compresse) ---- }
Function LoadBMP(Const FNm: String; O: PObj): Boolean;
Var F: File; Hd: Array[0..53] Of Byte; W,H,Bpp,Off,RowSz,Sz,DW,DH,X,Y,SX,SY,
 NCol,I,Idx,Cnt: Integer; Pal: Array[0..255] Of LongInt; Buf: Array[0..2047] Of Byte;
 TopDown: Boolean; Rw: LongInt; R2,G2,B2: Integer; PB: PBytes; PalB: Array[0..3] Of Byte;
 Res: Word;
 Function LE32(P: Integer): LongInt;
 Begin
  LE32:=LongInt(Hd[P])+LongInt(Hd[P+1]) Shl 8+LongInt(Hd[P+2]) Shl 16+
    LongInt(Hd[P+3]) Shl 24;
 End;
Begin
 LoadBMP:=False;
 {$I-}
 Assign(F,FNm);
 Reset(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 BlockRead(F,Hd,54,Res);
 If (Res<54) Or (Hd[0]<>Ord('B')) Or (Hd[1]<>Ord('M')) Then Begin Close(F);Exit;End;
 Off:=LE32(10);W:=LE32(18);H:=LE32(22);Bpp:=Hd[28]+Hd[29]*256;
 TopDown:=False;
 If H<0 Then Begin H:=-H;TopDown:=True;End;
 If (LE32(30)<>0) Or (W<=0) Or (H<=0) Or Not (Bpp In [1,4,8,24]) Or (W>2000)
   Then Begin Close(F);Exit;End;
 For I:=0 To 255 Do Pal[I]:=0;
 If Bpp<=8 Then Begin
  NCol:=1 Shl Bpp;
  Seek(F,14+LE32(14));
  For I:=0 To NCol-1 Do Begin
   BlockRead(F,PalB,4,Res);
   Pal[I]:=MkRGB(PalB[2],PalB[1],PalB[0]);
  End;
 End;
 RowSz:=((W*Bpp+31) Div 32)*4;
 If W>=H Then Begin DW:=Min2(W,BMPMAXW);DH:=Max2(1,H*DW Div W);End
 Else Begin DH:=Min2(H,BMPMAXH);DW:=Max2(1,W*DH Div H);End;
 If DH>BMPMAXH Then Begin DH:=BMPMAXH;DW:=Max2(1,W*DH Div H);End;
 GetMem(PB,DW*DH);
 For Y:=0 To DH-1 Do Begin
  SY:=Y*H Div DH;
  If TopDown Then Rw:=SY Else Rw:=H-1-SY;
  Seek(F,Off+Rw*RowSz);
  If RowSz>2048 Then Begin FreeMem(PB,DW*DH);Close(F);Exit;End;
  BlockRead(F,Buf,RowSz,Res);
  For X:=0 To DW-1 Do Begin
   SX:=X*W Div DW;
   Case Bpp Of
    1: Idx:=(Buf[SX Shr 3] Shr (7-(SX And 7))) And 1;
    4: If (SX And 1)=0 Then Idx:=Buf[SX Shr 1] Shr 4 Else Idx:=Buf[SX Shr 1] And 15;
    8: Idx:=Buf[SX];
    Else Idx:=0;
   End;
   If Bpp=24 Then
    PB^[Y*DW+X]:=NearestCol(MkRGB(Buf[SX*3+2],Buf[SX*3+1],Buf[SX*3]))
   Else PB^[Y*DW+X]:=NearestCol(Pal[Idx]);
  End;
 End;
 Close(F);
 If O^.BPix<>Nil Then FreeMem(O^.BPix,O^.BW*O^.BH);
 O^.BPix:=PB;O^.BW:=DW;O^.BH:=DH;
 LoadBMP:=True;
End;

{ ====================================================================== }
{                  CONSTRUCTION DES OBJETS A LA SOURIS                   }
{ ====================================================================== }

Var
 CloseIt: Boolean;

Function SnapV(V,G: Double): Double;
Begin
 If G<=0 Then SnapV:=V Else SnapV:=Round(V/G)*G;
End;

Procedure SnapPt(Var X,Y: Double);
Begin
 If GridSnap Or CtrlHeld Then Begin
  X:=SnapV(X,GridX);Y:=SnapV(Y,GridY);
 End;
End;

Procedure PO_Init(K: Byte);
Begin
 InitObj(PrevO,K);
 PrevO.Nd:=TmpNd;PrevO.Cap:=MAXNODE;PrevO.N:=0;
End;

Procedure NodeSet(Var Nd: TNode; PX,PY: Double);
Begin
 Nd.X:=PX;Nd.Y:=PY;Nd.AX:=PX;Nd.AY:=PY;Nd.BX:=PX;Nd.BY:=PY;Nd.Kind:=0;
End;

Procedure PO_Add(PX,PY: Double);
Begin
 If PrevO.N>=MAXNODE Then Exit;
 NodeSet(PrevO.Nd^[PrevO.N],PX,PY);
 Inc(PrevO.N);
End;

Procedure PO_Rect(X1,Y1,X2,Y2: Double);
Var T: Double;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y1>Y2 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 PO_Add(X1,Y1);PO_Add(X2,Y1);PO_Add(X2,Y2);PO_Add(X1,Y2);
End;

Procedure PO_Ellipse(CX,CY,RX,RY: Double);
Begin
 PO_Add(CX,CY);PO_Add(CX+RX,CY);PO_Add(CX,CY+RY);
End;

{ Calcule les poignees d'un chemin pour qu'il passe par les noeuds (Catmull-Rom) }
Procedure SplineHandles(O: PObj);
Var I,N: Integer; TX,TY: Double;
Begin
 N:=O^.N;
 If N<2 Then Exit;
 For I:=0 To N-1 Do Begin
  If I=0 Then Begin
   TX:=O^.Nd^[1].X-O^.Nd^[0].X;TY:=O^.Nd^[1].Y-O^.Nd^[0].Y;
  End Else If I=N-1 Then Begin
   TX:=O^.Nd^[N-1].X-O^.Nd^[N-2].X;TY:=O^.Nd^[N-1].Y-O^.Nd^[N-2].Y;
  End Else Begin
   TX:=(O^.Nd^[I+1].X-O^.Nd^[I-1].X)/2;TY:=(O^.Nd^[I+1].Y-O^.Nd^[I-1].Y)/2;
  End;
  O^.Nd^[I].AX:=O^.Nd^[I].X+TX/3;O^.Nd^[I].AY:=O^.Nd^[I].Y+TY/3;
  O^.Nd^[I].BX:=O^.Nd^[I].X-TX/3;O^.Nd^[I].BY:=O^.Nd^[I].Y-TY/3;
  If I<N-1 Then O^.Nd^[I].Kind:=1 Else O^.Nd^[I].Kind:=0;
 End;
End;

{ Angle parametrique (degres) d'un point dans le repere de l'ellipse de O }
Function ParamAngle(O: PObj; QX,QY: Double): Double;
Var CX,CY,AXv,AYv,BXv,BYv,Det,C,S,DX,DY,R: Double;
Begin
 CX:=O^.Nd^[0].X;CY:=O^.Nd^[0].Y;
 AXv:=O^.Nd^[1].X-CX;AYv:=O^.Nd^[1].Y-CY;
 BXv:=O^.Nd^[2].X-CX;BYv:=O^.Nd^[2].Y-CY;
 Det:=AXv*BYv-BXv*AYv;
 If Abs(Det)<1E-9 Then Begin ParamAngle:=0;Exit;End;
 DX:=QX-CX;DY:=QY-CY;
 C:=(DX*BYv-BXv*DY)/Det;
 S:=(AXv*DY-DX*AYv)/Det;
 R:=ArcTan2(S,C)*180/Pi;
 If R<0 Then R:=R+360;
 ParamAngle:=R;
End;

{ Construit PrevO a partir de l'etat de l'outil de dessin. Retourne True si
  l'apercu existe. Final=True : construction definitive (sans le point souris
  courant pour les outils a nombre variable de points) }
Function BuildPrev(Final: Boolean; MXw,MYw: Double): Boolean;
Var I,Cnt,Done,Part,K: Integer; R,RX,RY,A0,X1,Y1,X2,Y2,Tx,Ty: Double;
 Sx,Sy: Double;
Begin
 BuildPrev:=False;
 If NDP<1 Then Exit;
 Case CurTool[BX_DRAW] Of
  T_LINE: Begin
    PO_Init(OK_LINE);PO_Add(DP[1].X,DP[1].Y);PO_Add(MXw,MYw);
    BuildPrev:=True;
   End;
  T_MLINE: Begin
    PO_Init(OK_POLY);
    For I:=1 To NDP Do PO_Add(DP[I].X,DP[I].Y);
    If Not Final Then PO_Add(MXw,MYw);
    PrevO.Closed:=CloseIt And Final;
    If Not PrevO.Closed Then PrevO.FillMode:=0;
    BuildPrev:=PrevO.N>=2;
   End;
  T_RECT,T_RRECT: Begin
    If CurTool[BX_DRAW]=T_RECT Then PO_Init(OK_RECT) Else PO_Init(OK_RRECT);
    PO_Rect(DP[1].X,DP[1].Y,MXw,MYw);
    BuildPrev:=True;
   End;
  T_TRI: Begin
    If NDP=1 Then Begin
     PO_Init(OK_LINE);PO_Add(DP[1].X,DP[1].Y);PO_Add(MXw,MYw);
    End Else Begin
     PO_Init(OK_TRI);PO_Add(DP[1].X,DP[1].Y);PO_Add(DP[2].X,DP[2].Y);
     PO_Add(MXw,MYw);
    End;
    BuildPrev:=True;
   End;
  T_PARA: Begin
    If NDP=1 Then Begin
     PO_Init(OK_LINE);PO_Add(DP[1].X,DP[1].Y);PO_Add(MXw,MYw);
    End Else Begin
     PO_Init(OK_PARA);PO_Add(DP[1].X,DP[1].Y);PO_Add(DP[2].X,DP[2].Y);
     PO_Add(MXw,MYw);PO_Add(DP[1].X+MXw-DP[2].X,DP[1].Y+MYw-DP[2].Y);
    End;
    BuildPrev:=True;
   End;
  T_CIRCLE: Begin
    R:=Hypot(MXw-DP[1].X,MYw-DP[1].Y);
    PO_Init(OK_CIRCLE);PO_Ellipse(DP[1].X,DP[1].Y,R,R);
    BuildPrev:=True;
   End;
  T_ELLIPSE: Begin
    PO_Init(OK_ELLIPSE);
    PO_Ellipse(DP[1].X,DP[1].Y,Abs(MXw-DP[1].X),Abs(MYw-DP[1].Y));
    BuildPrev:=True;
   End;
  T_ARC,T_EARC: Begin
    If NDP=1 Then Begin
     RX:=MXw-DP[1].X;RY:=MYw-DP[1].Y;
    End Else Begin
     RX:=DP[2].X-DP[1].X;RY:=DP[2].Y-DP[1].Y;
    End;
    If CurTool[BX_DRAW]=T_ARC Then Begin
     R:=Hypot(RX,RY);RX:=R;RY:=R;
    End Else Begin RX:=Abs(RX);RY:=Abs(RY);End;
    If NDP<3 Then Begin
     If CurTool[BX_DRAW]=T_ARC Then PO_Init(OK_CIRCLE) Else PO_Init(OK_ELLIPSE);
     PO_Ellipse(DP[1].X,DP[1].Y,RX,RY);
    End Else Begin
     If CurTool[BX_DRAW]=T_ARC Then PO_Init(OK_ARC) Else PO_Init(OK_EARC);
     PO_Ellipse(DP[1].X,DP[1].Y,RX,RY);
     PrevO.A1:=ParamAngle(@PrevO,DP[3].X,DP[3].Y);
     PrevO.A2:=ParamAngle(@PrevO,MXw,MYw);
    End;
    BuildPrev:=True;
   End;
  T_RUBBER: Begin
    If NDP=1 Then Begin
     PO_Init(OK_LINE);PO_Add(DP[1].X,DP[1].Y);PO_Add(MXw,MYw);
    End Else Begin
     PO_Init(OK_BEZIER);PO_Add(DP[1].X,DP[1].Y);PO_Add(DP[2].X,DP[2].Y);
     PrevO.Nd^[0].AX:=DP[1].X+(MXw-DP[1].X)*2/3;
     PrevO.Nd^[0].AY:=DP[1].Y+(MYw-DP[1].Y)*2/3;
     PrevO.Nd^[1].BX:=DP[2].X+(MXw-DP[2].X)*2/3;
     PrevO.Nd^[1].BY:=DP[2].Y+(MYw-DP[2].Y)*2/3;
     PrevO.Nd^[0].Kind:=1;
    End;
    BuildPrev:=True;
   End;
  T_BEZIER: Begin
    PO_Init(OK_BEZIER);
    PO_Add(DP[1].X,DP[1].Y);
    Done:=(NDP-1) Div 3;
    Part:=(NDP-1) Mod 3;
    For I:=1 To Done Do Begin
     K:=1+(I-1)*3;
     PO_Add(DP[K+1].X,DP[K+1].Y);
     PrevO.Nd^[I-1].AX:=DP[K+2].X;PrevO.Nd^[I-1].AY:=DP[K+2].Y;
     PrevO.Nd^[I].BX:=DP[K+3].X;PrevO.Nd^[I].BY:=DP[K+3].Y;
     PrevO.Nd^[I-1].Kind:=1;
    End;
    If Not Final Then Begin
     K:=1+Done*3;
     Case Part Of
      0: Begin PO_Add(MXw,MYw);End;
      1: Begin
          PO_Add(DP[K+1].X,DP[K+1].Y);
          PrevO.Nd^[Done].AX:=MXw;PrevO.Nd^[Done].AY:=MYw;
          PrevO.Nd^[Done].Kind:=1;
         End;
      2: Begin
          PO_Add(DP[K+1].X,DP[K+1].Y);
          PrevO.Nd^[Done].AX:=DP[K+2].X;PrevO.Nd^[Done].AY:=DP[K+2].Y;
          PrevO.Nd^[Done+1].BX:=MXw;PrevO.Nd^[Done+1].BY:=MYw;
          PrevO.Nd^[Done].Kind:=1;
         End;
     End;
    End;
    BuildPrev:=PrevO.N>=2;
   End;
  T_SPLINE: Begin
    PO_Init(OK_SPLINE);
    For I:=1 To NDP Do PO_Add(DP[I].X,DP[I].Y);
    If Not Final Then PO_Add(MXw,MYw);
    If PrevO.N>=2 Then SplineHandles(@PrevO);
    BuildPrev:=PrevO.N>=2;
   End;
  T_NGON: Begin
    R:=Hypot(MXw-DP[1].X,MYw-DP[1].Y);
    A0:=ArcTan2(MYw-DP[1].Y,MXw-DP[1].X);
    PO_Init(OK_NGON);
    For I:=0 To DNSides-1 Do
     PO_Add(DP[1].X+R*Cos(A0+2*Pi*I/DNSides),DP[1].Y+R*Sin(A0+2*Pi*I/DNSides));
    BuildPrev:=True;
   End;
  T_FTEXT,T_BITMAP: Begin
    If CurTool[BX_DRAW]=T_FTEXT Then PO_Init(OK_FTEXT) Else PO_Init(OK_BITMAP);
    PO_Rect(DP[1].X,DP[1].Y,MXw,MYw);
    BuildPrev:=True;
   End;
 End;
End;

Procedure MarkModified;
Begin
 Modified:=True;
End;

Function CommitPrev: PObj;
Var P: PObj;
Begin
 PushUndo;
 If (PrevO.Kind=OK_POLY) And Not PrevO.Closed Then PrevO.FillMode:=0;
 P:=AddObjRec(PrevO);
 If P=Nil Then MsgBox('ArtWorx',L2('Too many objects','Trop d''objets'))
 Else MarkModified;
 CommitPrev:=P;
End;

{ ====================================================================== }
{                       COMMANDES SUR LES OBJETS                         }
{ ====================================================================== }

Procedure CmdSelectAll;
Var I: Integer;
Begin
 For I:=1 To NObj Do
  If ObjVisible(Objs[I]) And Not ObjLocked(Objs[I]) Then Objs[I]^.Sel:=True;
End;

Procedure CmdDelete;
Var I: Integer;
Begin
 If CountSel=0 Then Exit;
 If OptConfirm Then
  If Not ConfirmBox(L2('Delete selected objects ?','Supprimer les objets selectionnes ?')) Then Exit;
 PushUndo;
 For I:=NObj DownTo 1 Do
  If Objs[I]^.Sel Then DelObjAt(I);
 RotMode:=False;
 MarkModified;
End;

Procedure CmdGroup;
Var I: Integer;
Begin
 If CountSel<2 Then Exit;
 PushUndo;
 Inc(NextGroup);
 For I:=1 To NObj Do If Objs[I]^.Sel Then Objs[I]^.Group:=NextGroup;
 MarkModified;
End;

Procedure CmdUngroup;
Var I: Integer;
Begin
 If CountSel<1 Then Exit;
 PushUndo;
 For I:=1 To NObj Do If Objs[I]^.Sel Then Objs[I]^.Group:=0;
 MarkModified;
End;

Procedure CmdZOrder(ToFront: Boolean);
Var Tmp: Array[1..MAXOBJ] Of PObj; N,I: Integer;
Begin
 If CountSel=0 Then Exit;
 PushUndo;
 N:=0;
 If ToFront Then Begin
  For I:=1 To NObj Do If Not Objs[I]^.Sel Then Begin Inc(N);Tmp[N]:=Objs[I];End;
  For I:=1 To NObj Do If Objs[I]^.Sel Then Begin Inc(N);Tmp[N]:=Objs[I];End;
 End Else Begin
  For I:=1 To NObj Do If Objs[I]^.Sel Then Begin Inc(N);Tmp[N]:=Objs[I];End;
  For I:=1 To NObj Do If Not Objs[I]^.Sel Then Begin Inc(N);Tmp[N]:=Objs[I];End;
 End;
 For I:=1 To NObj Do Objs[I]:=Tmp[I];
 MarkModified;
End;

Procedure CmdLock(V: Boolean);
Var I: Integer;
Begin
 If CountSel=0 Then Exit;
 PushUndo;
 For I:=1 To NObj Do
  If Objs[I]^.Sel Then Begin
   Objs[I]^.Locked:=V;
   If V Then Objs[I]^.Sel:=False;
  End;
 MarkModified;
End;

Procedure XformSel(A,B,C,D,E,F: Double);
Var I: Integer;
Begin
 For I:=1 To NObj Do
  If Objs[I]^.Sel Then XformObj(Objs[I],A,B,C,D,E,F);
End;

Procedure MoveSel(DX,DY: Double);
Begin
 XformSel(1,0,0,1,DX,DY);
End;

Procedure CmdSnapToGrid;
Var X,Y: Double;
Begin
 If Not SelBBox Then Exit;
 PushUndo;
 X:=SnapV(SelBX1,GridX)-SelBX1;Y:=SnapV(SelBY1,GridY)-SelBY1;
 MoveSel(X,Y);
 MarkModified;
End;

{ ---- presse-papiers interne (fichier) ---- }
Procedure CmdCopy;
Begin
 If CountSel=0 Then Exit;
 If SaveCWG('ARTWORX.CLP',True) Then ClipHas:=True;
End;

Procedure CmdCut;
Begin
 If CountSel=0 Then Exit;
 CmdCopy;
 PushUndo;
 While FirstSel<>Nil Do DelObjAt(IndexOfObj(FirstSel));
 MarkModified;
End;

Procedure CmdPaste;
Var N0,I: Integer;
Begin
 If Not ClipHas Then Exit;
 PushUndo;
 DeselectAll;
 N0:=NObj;
 If LoadCWG('ARTWORX.CLP',True) Then Begin
  For I:=N0+1 To NObj Do Begin
   Objs[I]^.Sel:=True;Objs[I]^.Page:=CurPage;Objs[I]^.Layer:=CurLayer;
   Objs[I]^.Group:=0;
  End;
  MoveSel(5,5);
  MarkModified;
 End;
End;

{ ---- pages ---- }
Procedure SetPage(N: Integer);
Begin
 If N<1 Then N:=1;
 If N>NPages Then N:=NPages;
 If N<>CurPage Then Begin
  DeselectAll;
  CurPage:=N;
 End;
End;

Procedure CmdInsertPage;
Var I: Integer;
Begin
 If NPages>=MAXPAGE Then Exit;
 PushUndo;
 For I:=1 To NObj Do If Objs[I]^.Page>CurPage Then Inc(Objs[I]^.Page);
 Inc(NPages);
 DeselectAll;
 Inc(CurPage);
 MarkModified;
End;

Procedure CmdDeletePage;
Var I: Integer;
Begin
 If NPages<=1 Then Begin
  MsgBox('ArtWorx',L2('Cannot delete the last page','Impossible de supprimer la derniere page'));
  Exit;
 End;
 If Not ConfirmBox(L2('Delete current page ?','Supprimer la page courante ?')) Then Exit;
 PushUndo;
 For I:=NObj DownTo 1 Do If Objs[I]^.Page=CurPage Then DelObjAt(I);
 For I:=1 To NObj Do If Objs[I]^.Page>CurPage Then Dec(Objs[I]^.Page);
 Dec(NPages);
 If CurPage>NPages Then CurPage:=NPages;
 DeselectAll;
 MarkModified;
End;

{ ---- conversion en chemins ---- }
Function ToPathObj(O: PObj): Boolean;
Var I,J,Segs: Integer; K,CX,CY,AXv,AYv,BXv,BYv,T,T1,T2,Dx,Dy,Dth,Kf: Double;
 NewN: Integer; Tmp: Array[0..40] Of TNode; N0: Integer; Sx,Sy: Double;
Begin
 ToPathObj:=False;
 Case O^.Kind Of
  OK_LINE,OK_POLY,OK_BEZIER,OK_SPLINE,OK_FREE,OK_COMPOUND,OK_TRI,OK_PARA,
  OK_NGON,OK_RECT: Begin
   If O^.Kind In [OK_RECT,OK_TRI,OK_PARA,OK_NGON] Then O^.Kind:=OK_POLY;
   ToPathObj:=True;
  End;
  OK_RRECT: Begin
   FlattenObj(O,Sc);
   N0:=SubS[1]-1;
   If N0>MAXNODE-1 Then N0:=MAXNODE-1;
   SetCap(O,N0+2);
   O^.N:=N0;
   For I:=0 To N0-1 Do NodeSet(O^.Nd^[I],FP^[I].X,FP^[I].Y);
   O^.Kind:=OK_POLY;O^.Closed:=True;
   ToPathObj:=True;
  End;
  OK_CIRCLE,OK_ELLIPSE,OK_ARC,OK_EARC: Begin
   CX:=O^.Nd^[0].X;CY:=O^.Nd^[0].Y;
   AXv:=O^.Nd^[1].X-CX;AYv:=O^.Nd^[1].Y-CY;
   BXv:=O^.Nd^[2].X-CX;BYv:=O^.Nd^[2].Y-CY;
   If O^.Kind In [OK_CIRCLE,OK_ELLIPSE] Then Begin
    T1:=0;T2:=2*Pi;
   End Else Begin
    T1:=O^.A1*Pi/180;T2:=O^.A2*Pi/180;
    If T2<=T1 Then T2:=T2+2*Pi;
   End;
   Segs:=Trunc((T2-T1)/(Pi/2)-0.001)+1;
   If Segs<1 Then Segs:=1;
   If Segs>8 Then Segs:=8;
   Dth:=(T2-T1)/Segs;
   Kf:=4/3*Sin(Dth/4)/Cos(Dth/4);
   NewN:=Segs+1;
   If O^.Kind In [OK_CIRCLE,OK_ELLIPSE] Then NewN:=Segs;
   For I:=0 To NewN-1 Do Begin
    T:=T1+I*Dth;
    Sx:=CX+AXv*Cos(T)+BXv*Sin(T);Sy:=CY+AYv*Cos(T)+BYv*Sin(T);
    Dx:=-AXv*Sin(T)+BXv*Cos(T);Dy:=-AYv*Sin(T)+BYv*Cos(T);
    NodeSet(Tmp[I],Sx,Sy);
    Tmp[I].AX:=Sx+Kf*Dx;Tmp[I].AY:=Sy+Kf*Dy;
    Tmp[I].BX:=Sx-Kf*Dx;Tmp[I].BY:=Sy-Kf*Dy;
    Tmp[I].Kind:=1;
   End;
   If NewN=Segs+1 Then Tmp[NewN-1].Kind:=0;
   SetCap(O,NewN+2);
   For I:=0 To NewN-1 Do O^.Nd^[I]:=Tmp[I];
   O^.N:=NewN;
   O^.Closed:=(O^.Kind In [OK_CIRCLE,OK_ELLIPSE]);
   If O^.Kind In [OK_ARC,OK_EARC] Then O^.Closed:=False;
   O^.Kind:=OK_BEZIER;
   ToPathObj:=True;
  End;
 End;
End;

Procedure ToBezierSegs(O: PObj);
Var I,J: Integer; Last: Integer;
Begin
 If Not O^.Closed Then Last:=O^.N-2 Else Last:=O^.N-1;
 For I:=0 To Last Do Begin
  J:=(I+1) Mod O^.N;
  If O^.Nd^[I].Kind=0 Then Begin
   O^.Nd^[I].AX:=O^.Nd^[I].X+(O^.Nd^[J].X-O^.Nd^[I].X)/3;
   O^.Nd^[I].AY:=O^.Nd^[I].Y+(O^.Nd^[J].Y-O^.Nd^[I].Y)/3;
   O^.Nd^[J].BX:=O^.Nd^[J].X-(O^.Nd^[J].X-O^.Nd^[I].X)/3;
   O^.Nd^[J].BY:=O^.Nd^[J].Y-(O^.Nd^[J].Y-O^.Nd^[I].Y)/3;
   O^.Nd^[I].Kind:=1;
  End;
 End;
 O^.Kind:=OK_BEZIER;
End;

{ Double le nombre de noeuds sans changer la forme }
Procedure RefineObj(O: PObj);
Var I,J,Last,N0: Integer; Tmp: Array[0..MAXNODE-1] Of TNode; NN: Integer;
 P0x,P0y,P1x,P1y,P2x,P2y,P3x,P3y,Ax,Ay,Bx,By,Cx,Cy,Dx,Dy,Ex,Ey,Mx,My: Double;
Begin
 N0:=O^.N;
 If O^.Closed Then Last:=N0-1 Else Last:=N0-2;
 NN:=0;
 For I:=0 To Last Do Begin
  J:=(I+1) Mod N0;
  If NN+3>MAXNODE-2 Then Break;
  Tmp[NN]:=O^.Nd^[I];
  If O^.Nd^[I].Kind=0 Then Begin
   Inc(NN);
   NodeSet(Tmp[NN],(O^.Nd^[I].X+O^.Nd^[J].X)/2,(O^.Nd^[I].Y+O^.Nd^[J].Y)/2);
  End Else If O^.Nd^[I].Kind=1 Then Begin
   P0x:=O^.Nd^[I].X;P0y:=O^.Nd^[I].Y;P1x:=O^.Nd^[I].AX;P1y:=O^.Nd^[I].AY;
   P2x:=O^.Nd^[J].BX;P2y:=O^.Nd^[J].BY;P3x:=O^.Nd^[J].X;P3y:=O^.Nd^[J].Y;
   Ax:=(P0x+P1x)/2;Ay:=(P0y+P1y)/2;Bx:=(P1x+P2x)/2;By:=(P1y+P2y)/2;
   Cx:=(P2x+P3x)/2;Cy:=(P2y+P3y)/2;Dx:=(Ax+Bx)/2;Dy:=(Ay+By)/2;
   Ex:=(Bx+Cx)/2;Ey:=(By+Cy)/2;Mx:=(Dx+Ex)/2;My:=(Dy+Ey)/2;
   Tmp[NN].AX:=Ax;Tmp[NN].AY:=Ay;
   Inc(NN);
   NodeSet(Tmp[NN],Mx,My);
   Tmp[NN].BX:=Dx;Tmp[NN].BY:=Dy;Tmp[NN].AX:=Ex;Tmp[NN].AY:=Ey;Tmp[NN].Kind:=1;
   O^.Nd^[J].BX:=Cx;O^.Nd^[J].BY:=Cy;
  End Else Begin
   Inc(NN);
   NodeSet(Tmp[NN],O^.Nd^[I].X,O^.Nd^[I].Y);Tmp[NN].Kind:=2;
   Tmp[NN-1].Kind:=2;
  End;
  Inc(NN);
 End;
 If Not O^.Closed Then Begin Tmp[NN]:=O^.Nd^[N0-1];Inc(NN);End;
 SetCap(O,NN+2);
 For I:=0 To NN-1 Do O^.Nd^[I]:=Tmp[I];
 O^.N:=NN;
End;

{ ---- texte -> courbes (contours des pixels du glyphe) ---- }
Procedure TextToCurves(O: PObj);
Var S: String; Line1: String; I,R,C,C0,Ln,P,L,Cols,Rows,K: Integer; Row: Byte;
 Ux,Uy,Vx,Vy,Ox,Oy,X0,Y0,X1,Y1,X2,Y2,X3,Y3,Off: Double; T: TObj; Pn: PObj;
 Gid: Integer;
 Procedure AddN(X,Y: Double);
 Begin
  If T.N<MAXNODE-1 Then Begin NodeSet(T.Nd^[T.N],X,Y);Inc(T.N);End;
 End;
Begin
 If O^.Kind<>OK_TEXT Then Exit;
 S:=TxtOf(O);
 GetTextExtent(O,Cols,Rows);
 Ux:=(O^.Nd^[1].X-O^.Nd^[0].X)/8;Uy:=(O^.Nd^[1].Y-O^.Nd^[0].Y)/8;
 Vx:=(O^.Nd^[2].X-O^.Nd^[0].X)/8;Vy:=(O^.Nd^[2].Y-O^.Nd^[0].Y)/8;
 PushUndo;
 Inc(NextGroup);Gid:=NextGroup;
 Ln:=0;P:=1;
 Repeat
  L:=P;
  While (L<=Length(S)) And (S[L]<>#10) Do Inc(L);
  Line1:=Copy(S,P,L-P);
  Case O^.TAlign Of
   1: Off:=(Cols-Length(Line1))/2;
   2: Off:=Cols-Length(Line1);
   Else Off:=0;
  End;
  Ox:=O^.Nd^[0].X+Ux*8*Off+Vx*8*1.25*Ln;
  Oy:=O^.Nd^[0].Y+Uy*8*Off+Vy*8*1.25*Ln;
  For I:=1 To Length(Line1) Do Begin
   If Line1[I]=' ' Then Continue;
   InitObj(T,OK_COMPOUND);
   T.Nd:=TmpNd;T.Cap:=MAXNODE;T.N:=0;
   T.Layer:=O^.Layer;T.Page:=O^.Page;T.Group:=Gid;
   T.FillMode:=1;T.FillPat:=1;T.FillCol:=O^.LineCol;T.LineCol:=O^.LineCol;
   T.LineW:=-1;T.Closed:=False;
   For R:=0 To 7 Do Begin
    Row:=FontBits[Ord(Line1[I]),R];
    C:=0;
    While C<8 Do Begin
     If ((Row Shr (7-C)) And 1)<>0 Then Begin
      C0:=C;
      While (C<8) And (((Row Shr (7-C)) And 1)<>0) Do Inc(C);
      X0:=Ox+Ux*((I-1)*8+C0)+Vx*R;Y0:=Oy+Uy*((I-1)*8+C0)+Vy*R;
      X1:=Ox+Ux*((I-1)*8+C)+Vx*R;Y1:=Oy+Uy*((I-1)*8+C)+Vy*R;
      X2:=X1+Vx;Y2:=Y1+Vy;X3:=X0+Vx;Y3:=Y0+Vy;
      AddN(X0,Y0);AddN(X1,Y1);AddN(X2,Y2);AddN(X3,Y3);AddN(X0,Y0);
      T.Nd^[T.N-1].Kind:=2;
     End Else Inc(C);
    End;
   End;
   If T.N>1 Then Begin
    T.Nd^[T.N-1].Kind:=0;
    Pn:=AddObjRec(T);
   End;
  End;
  Inc(Ln);
  P:=L+1;
 Until P>Length(S)+1;
 DelObjAt(IndexOfObj(O));
 MarkModified;
End;

{ ---- commuter : changer le type d'un objet ---- }
Procedure CmdCommute;
Var O: PObj; Items: String; Codes: Array[0..7] Of Integer; N,R,I,J,Cnt: Integer;
 Procedure Add(Code: Integer; Const S: String);
 Begin
  If N>0 Then Items:=Items+'|';
  Items:=Items+S;Codes[N]:=Code;Inc(N);
 End;
Begin
 O:=FirstSel;
 If O=Nil Then Exit;
 Items:='';N:=0;
 Case O^.Kind Of
  OK_CIRCLE: Begin Add(1,L2('Ellipse','Ellipse'));Add(2,L2('Circular arc','Arc circulaire'));
    Add(3,L2('Bezier curves','Courbes de Bezier'));End;
  OK_ELLIPSE: Begin Add(4,L2('Circle','Cercle'));Add(5,L2('Elliptical arc','Arc elliptique'));
    Add(3,L2('Bezier curves','Courbes de Bezier'));End;
  OK_ARC: Begin Add(6,L2('Circle','Cercle'));Add(3,L2('Bezier curves','Courbes de Bezier'));End;
  OK_EARC: Begin Add(7,L2('Ellipse','Ellipse'));Add(3,L2('Bezier curves','Courbes de Bezier'));End;
  OK_TEXT: Add(8,L2('Bezier curves','Courbes de Bezier'));
  OK_RECT,OK_RRECT,OK_TRI,OK_PARA,OK_NGON: Begin
    Add(9,L2('Multi-line','Multi-ligne'));Add(3,L2('Bezier curves','Courbes de Bezier'));End;
  OK_LINE,OK_POLY,OK_BEZIER,OK_SPLINE,OK_FREE,OK_COMPOUND: Begin
    Add(3,L2('Bezier curves','Courbes de Bezier'));
    Add(10,L2('Multi-line (flatten)','Multi-ligne (aplatir)'));
    Add(11,L2('Refine (double nodes)','Raffiner (double les noeuds)'));
    Add(12,L2('Close / open path','Fermer / ouvrir le chemin'));
   End;
  Else Begin
   MsgBox(L2('Commute','Commuter'),L2('No conversion available','Aucune conversion possible'));
   Exit;
  End;
 End;
 R:=PopupChoice(Items,200,150,0);
 If R<0 Then Exit;
 PushUndo;
 Case Codes[R] Of
  1: Begin O^.Kind:=OK_ELLIPSE;End;
  2: Begin O^.Kind:=OK_ARC;O^.A1:=0;O^.A2:=270;O^.Closed:=False;O^.FillMode:=0;End;
  3: Begin If ToPathObj(O) Then ToBezierSegs(O);End;
  4: Begin
      O^.Kind:=OK_CIRCLE;
      N:=0;
      I:=Round((Hypot(O^.Nd^[1].X-O^.Nd^[0].X,O^.Nd^[1].Y-O^.Nd^[0].Y)+
        Hypot(O^.Nd^[2].X-O^.Nd^[0].X,O^.Nd^[2].Y-O^.Nd^[0].Y))*50);
      NodeSet(O^.Nd^[1],O^.Nd^[0].X+I/100,O^.Nd^[0].Y);
      NodeSet(O^.Nd^[2],O^.Nd^[0].X,O^.Nd^[0].Y+I/100);
     End;
  5: Begin O^.Kind:=OK_EARC;O^.A1:=0;O^.A2:=270;O^.Closed:=False;O^.FillMode:=0;End;
  6: Begin O^.Kind:=OK_CIRCLE;O^.Closed:=True;End;
  7: Begin O^.Kind:=OK_ELLIPSE;O^.Closed:=True;End;
  8: TextToCurves(O);
  9: ToPathObj(O);
  10: Begin
       FlattenObj(O,Sc);
       Cnt:=SubS[1];
       If Cnt>MAXNODE-2 Then Cnt:=MAXNODE-2;
       SetCap(O,Cnt+2);
       For I:=0 To Cnt-1 Do NodeSet(O^.Nd^[I],FP^[I].X,FP^[I].Y);
       O^.N:=Cnt;
       If O^.Closed Then Dec(O^.N);
       O^.Kind:=OK_POLY;
      End;
  11: RefineObj(O);
  12: O^.Closed:=Not O^.Closed;
 End;
 MarkModified;
End;

{ ---- operations booleennes ---- }
Type
 TSmall = Array[0..449] Of TPt;
 PSmall = ^TSmall;

Function PolyFromFlat(P: PSmall): Integer;
Var N,I,Stride,Cnt: Integer;
Begin
 N:=SubS[1];
 If (N>1) And (Abs(FP^[0].X-FP^[N-1].X)<1E-6) And (Abs(FP^[0].Y-FP^[N-1].Y)<1E-6) Then Dec(N);
 Stride:=1;
 While N Div Stride>440 Do Inc(Stride);
 Cnt:=0;
 For I:=0 To N-1 Do If I Mod Stride=0 Then Begin P^[Cnt]:=FP^[I];Inc(Cnt);End;
 PolyFromFlat:=Cnt;
End;

{ ====================================================================== }
{                       OPERATIONS BOOLEENNES                            }
{ ====================================================================== }

Function PolyArea(P: PSmall; N: Integer): Double;
Var I,J: Integer; A: Double;
Begin
 A:=0;
 For I:=0 To N-1 Do Begin
  J:=(I+1) Mod N;
  A:=A+(P^[I].X*P^[J].Y-P^[J].X*P^[I].Y);
 End;
 PolyArea:=A/2;
End;

Function IsConvex(P: PSmall; N: Integer): Boolean;
Var I,J,K: Integer; Cr: Double; Pos1,Neg1: Boolean;
Begin
 Pos1:=False;Neg1:=False;
 For I:=0 To N-1 Do Begin
  J:=(I+1) Mod N;K:=(I+2) Mod N;
  Cr:=(P^[J].X-P^[I].X)*(P^[K].Y-P^[J].Y)-(P^[J].Y-P^[I].Y)*(P^[K].X-P^[J].X);
  If Cr>1E-9 Then Pos1:=True;
  If Cr<-1E-9 Then Neg1:=True;
 End;
 IsConvex:=Not (Pos1 And Neg1);
End;

{ Sutherland-Hodgman : polygone quelconque decoupe par un polygone convexe }
Function ClipSH(Subj: PSmall; NS: Integer; Clip: PSmall; NC: Integer;
  Res: PSmall): Integer;
Var Buf: PSmall; NI,NO,I,J,E: Integer; Sg,D1,D2,T: Double; S,P: TPt; C1,C2: TPt;
 InS,InP: Boolean;
 Function Side(Q: TPt): Double;
 Begin
  Side:=Sg*((C2.X-C1.X)*(Q.Y-C1.Y)-(C2.Y-C1.Y)*(Q.X-C1.X));
 End;
Begin
 New(Buf);
 Sg:=1;
 If PolyArea(Clip,NC)<0 Then Sg:=-1;
 For I:=0 To NS-1 Do Res^[I]:=Subj^[I];
 NO:=NS;
 For E:=0 To NC-1 Do Begin
  C1:=Clip^[E];C2:=Clip^[(E+1) Mod NC];
  NI:=NO;
  For I:=0 To NI-1 Do Buf^[I]:=Res^[I];
  NO:=0;
  If NI=0 Then Break;
  S:=Buf^[NI-1];
  For I:=0 To NI-1 Do Begin
   P:=Buf^[I];
   D1:=Side(S);D2:=Side(P);
   InS:=D1>=0;InP:=D2>=0;
   If InP Then Begin
    If Not InS Then Begin
     T:=D1/(D1-D2);
     If NO<440 Then Begin Res^[NO].X:=S.X+(P.X-S.X)*T;Res^[NO].Y:=S.Y+(P.Y-S.Y)*T;Inc(NO);End;
    End;
    If NO<440 Then Begin Res^[NO]:=P;Inc(NO);End;
   End Else If InS Then Begin
    T:=D1/(D1-D2);
    If NO<440 Then Begin Res^[NO].X:=S.X+(P.X-S.X)*T;Res^[NO].Y:=S.Y+(P.Y-S.Y)*T;Inc(NO);End;
   End;
   S:=P;
  End;
 End;
 Dispose(Buf);
 ClipSH:=NO;
End;

Procedure BoolCompound(A,B: PObj);
Var T: TObj; I,K: Integer; Src: PObj; Okk: Boolean; Pn: PObj;
Begin
 If Not (ToPathObj(A) And ToPathObj(B)) Then Begin
  MsgBox(L2('Boolean','Booleen'),L2('Objects must be shapes or paths','Les objets doivent etre des formes ou des chemins'));
  Exit;
 End;
 InitObj(T,OK_COMPOUND);
 T.Nd:=TmpNd;T.Cap:=MAXNODE;T.N:=0;
 T.LineCol:=A^.LineCol;T.FillCol:=A^.FillCol;T.LineW:=A^.LineW;
 T.FillMode:=A^.FillMode;T.FillPat:=A^.FillPat;T.Grey:=A^.Grey;
 If T.FillMode=0 Then T.FillMode:=1;
 T.Layer:=A^.Layer;T.Page:=A^.Page;T.ShOn:=A^.ShOn;T.ShDX:=A^.ShDX;
 T.ShDY:=A^.ShDY;T.ShCol:=A^.ShCol;
 For K:=0 To 1 Do Begin
  If K=0 Then Src:=A Else Src:=B;
  For I:=0 To Src^.N-1 Do
   If T.N<MAXNODE-2 Then Begin T.Nd^[T.N]:=Src^.Nd^[I];Inc(T.N);End;
  If Src^.Closed Then Begin
   If T.N<MAXNODE-1 Then Begin
    T.Nd^[T.N]:=Src^.Nd^[0];
    T.Nd^[T.N].Kind:=0;
    Inc(T.N);
   End;
  End;
  If K=0 Then T.Nd^[T.N-1].Kind:=2 Else T.Nd^[T.N-1].Kind:=0;
 End;
 T.Closed:=False;
 PushUndo;
 DelObjAt(IndexOfObj(B));
 DelObjAt(IndexOfObj(A));
 Pn:=AddObjRec(T);
 If Pn<>Nil Then Pn^.Sel:=True;
 MarkModified;
End;

Procedure CmdBoolean;
Var A,B: PObj; I,N,R,NA,NB,NR: Integer; PA,PB,PR: PSmall; Ok1: Boolean;
 T: TObj; Pn: PObj; Cx: Boolean;
Begin
 If CountSel<>2 Then Begin
  MsgBox(L2('Boolean','Booleen'),L2('Select exactly two objects','Selectionnez exactement deux objets'));
  Exit;
 End;
 A:=Nil;B:=Nil;
 For I:=1 To NObj Do
  If Objs[I]^.Sel Then Begin
   If A=Nil Then A:=Objs[I] Else B:=Objs[I];
  End;
 R:=PopupChoice(L2('Union|Intersect|Difference|Dependent',
   'Union|Intersection|Difference|Dependant'),200,150,0);
 If R<0 Then Exit;
 Case R Of
  0: Begin
      PushUndo;Inc(NextGroup);A^.Group:=NextGroup;B^.Group:=NextGroup;
      MarkModified;
     End;
  2,3: BoolCompound(A,B);
  1: Begin
      New(PA);New(PB);New(PR);
      FlattenObj(A,Sc);NA:=PolyFromFlat(PA);
      FlattenObj(B,Sc);NB:=PolyFromFlat(PB);
      If (NA<3) Or (NB<3) Then Begin
       MsgBox(L2('Boolean','Booleen'),L2('Closed shapes required','Formes fermees requises'));
      End Else Begin
       Cx:=IsConvex(PB,NB);
       If Cx Then NR:=ClipSH(PA,NA,PB,NB,PR)
       Else If IsConvex(PA,NA) Then NR:=ClipSH(PB,NB,PA,NA,PR)
       Else Begin NR:=-1;End;
       If NR<0 Then
        MsgBox(L2('Boolean','Booleen'),L2('Intersection needs one convex shape','L''intersection demande une forme convexe'))
       Else If NR<3 Then
        MsgBox(L2('Boolean','Booleen'),L2('Empty intersection','Intersection vide'))
       Else Begin
        PushUndo;
        InitObj(T,OK_POLY);
        T.Nd:=TmpNd;T.Cap:=MAXNODE;T.N:=0;
        T.LineCol:=A^.LineCol;T.FillCol:=A^.FillCol;T.LineW:=A^.LineW;
        T.FillMode:=A^.FillMode;T.FillPat:=A^.FillPat;T.Grey:=A^.Grey;
        T.Layer:=A^.Layer;T.Page:=A^.Page;T.Closed:=True;
        For I:=0 To NR-1 Do Begin
         NodeSet(T.Nd^[T.N],PR^[I].X,PR^[I].Y);Inc(T.N);
        End;
        DelObjAt(IndexOfObj(B));
        DelObjAt(IndexOfObj(A));
        Pn:=AddObjRec(T);
        If Pn<>Nil Then Pn^.Sel:=True;
        MarkModified;
       End;
      End;
      Dispose(PA);Dispose(PB);Dispose(PR);
     End;
 End;
End;

{ ====================================================================== }
{                     BOITES DE DIALOGUE DE STYLE                        }
{ ====================================================================== }

Const
 LnWidths: Array[0..10] Of Double = (0,-1,0.25,0.5,1,1.5,2,3,4,5,-2);

Function WidthIdx(W: Double): Integer;
Var I: Integer;
Begin
 WidthIdx:=10;
 For I:=0 To 9 Do If Abs(LnWidths[I]-W)<0.001 Then WidthIdx:=I;
End;

Var
 HkA,HkB,HkC,HkD,HkE: Integer;
 ColCur: LongInt;
 ColModelPrev: Integer;
 SlPrev: Array[1..3] Of Integer;

Function StyleRef: PObj;
Begin
 StyleRef:=FirstSel;
End;

Procedure CmdLines;
Var R,I,GS,GE,Sty,WIx: Integer; P: PObj; W: Double; Fr: Integer;
 Es,Ee,St,Wi,Fw: Integer; Wv: Double; Ok: Boolean;
Begin
 P:=StyleRef;
 DlgInit(L2('Line attributes','Attributs de trait'),340,176);
 If P<>Nil Then Begin RadioVal[1]:=P^.EndS;RadioVal[2]:=P^.EndE;Sty:=P^.LineSty;
  WIx:=WidthIdx(P^.LineW);Wv:=P^.LineW;End
 Else Begin RadioVal[1]:=CurEndS;RadioVal[2]:=CurEndE;Sty:=CurLineSty;
  WIx:=WidthIdx(CurLineW);Wv:=CurLineW;End;
 AddCtl(DC_FRAME,12,38,150,76,L2('Line ends','Extremites'));
 AddLabel(18,50,L2('Start','Debut'));AddLabel(98,50,L2('End','Fin'));
 AddRadio(18,62,1,0,L2('Std','Std'));AddRadio(18,76,1,1,L2('Arrow','Fleche'));
 AddRadio(18,90,1,2,L2('Round','Rond'));
 AddRadio(98,62,2,0,L2('Std','Std'));AddRadio(98,76,2,1,L2('Arrow','Fleche'));
 AddRadio(98,90,2,2,L2('Round','Rond'));
 AddLabel(176,40,L2('Style:','Style :'));
 St:=AddPop(236,36,92,L2('Solid|Dashed|Dotted|Dash-dot|Dash2-dot|Dense|Long',
   'Plein|Tirets|Points|Tiret-pt|Tiret-2pt|Dense|Long'),Sty);
 AddLabel(176,64,L2('Width:','Epais. :'));
 Wi:=AddPop(236,60,92,L2('Hairline|Null|0.25mm|0.5mm|1mm|1.5mm|2mm|3mm|4mm|5mm|Free',
   'Filet|Nulle|0.25mm|0.5mm|1mm|1.5mm|2mm|3mm|4mm|5mm|Libre'),WIx);
 AddLabel(176,88,L2('Free:','Libre :'));
 If Wv>0 Then Fw:=AddEdit(236,84,66,RealStr(Wv,2)) Else Fw:=AddEdit(236,84,66,'0');
 AddLabel(306,88,'mm');
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  GS:=RadioVal[1];GE:=RadioVal[2];
  If Ctl[Wi].V=10 Then Begin
   If Not ParseNum(Ctl[Fw].S,W) Then W:=0;
  End Else W:=LnWidths[Ctl[Wi].V];
  PushUndo;
  CurEndS:=GS;CurEndE:=GE;CurLineSty:=Ctl[St].V;CurLineW:=W;
  For I:=1 To NObj Do
   If Objs[I]^.Sel Then Begin
    Objs[I]^.EndS:=GS;Objs[I]^.EndE:=GE;Objs[I]^.LineSty:=Ctl[St].V;
    Objs[I]^.LineW:=W;
   End;
  MarkModified;
  If R=ID_APPLY Then Begin DrawAll;End;
 Until R<>ID_APPLY;
End;

Procedure CmdFill;
Var R,I,Pt,Gr,Ge,G0: Integer; P: PObj; Mode,Pat,Grey: Integer; V: Double;
Begin
 P:=StyleRef;
 If P<>Nil Then Begin Mode:=P^.FillMode;Pat:=P^.FillPat;Grey:=P^.Grey;End
 Else Begin Mode:=CurFillMode;Pat:=CurFillPat;Grey:=CurGrey;End;
 DlgInit(L2('Pattern','Trame'),340,236);
 RadioVal[1]:=Mode;
 AddCtl(DC_FRAME,12,38,100,60,L2('Filling','Remplissage'));
 AddRadio(18,48,1,0,L2('None','Aucun'));
 AddRadio(18,62,1,1,L2('Pattern','Trame'));
 AddRadio(18,76,1,2,L2('Grey tone','Ton de gris'));
 Pt:=AddCtl(DC_PATSEL,128,32,200,0,'');Ctl[Pt].V:=Pat;
 AddCtl(DC_FRAME,12,118,100,50,L2('Grey tone','Ton de gris'));
 Gr:=AddSlider(18,128,88,255,Grey);
 Ge:=AddEdit(18,146,40,IntStr(Grey));
 HkA:=Gr;HkB:=Ge;HkC:=Grey;DlgHookId:=2;
 AddStdBtns(True);
 Repeat
  G0:=Grey;
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  Grey:=Ctl[Gr].V;
  If ParseNum(Ctl[Ge].S,V) Then If Clamp(Round(V),0,255)<>Grey Then
    Grey:=Clamp(Round(V),0,255);
  Mode:=RadioVal[1];Pat:=Ctl[Pt].V;
  PushUndo;
  CurFillMode:=Mode;CurFillPat:=Pat;CurGrey:=Grey;
  For I:=1 To NObj Do
   If Objs[I]^.Sel Then Begin
    Objs[I]^.FillMode:=Mode;Objs[I]^.FillPat:=Pat;Objs[I]^.Grey:=Grey;
   End;
  MarkModified;
  Ctl[Gr].V:=Grey;Ctl[Ge].S:=IntStr(Grey);HkC:=Grey;
  If R=ID_APPLY Then DrawAll;
 Until R<>ID_APPLY;
End;

{ ====================================================================== }
{                  COULEURS, TEXTE, OMBRES, STATUT, INFO                 }
{ ====================================================================== }

Function ModelMax(M,K: Integer): Integer;
Begin
 If M<2 Then ModelMax:=255
 Else Case K Of
  1: ModelMax:=359;
  Else ModelMax:=100;
 End;
End;

Procedure SlidersFromColor;
Var H,S,V: Integer;
Begin
 Case RadioVal[3] Of
  0: Begin Ctl[HkA].V:=CR(ColCur);Ctl[HkA+1].V:=CG(ColCur);Ctl[HkA+2].V:=CB(ColCur);End;
  1: Begin Ctl[HkA].V:=255-CR(ColCur);Ctl[HkA+1].V:=255-CG(ColCur);
      Ctl[HkA+2].V:=255-CB(ColCur);End;
  Else Begin
   RGBtoHSV(ColCur,H,S,V);
   Ctl[HkA].V:=H;Ctl[HkA+1].V:=S;Ctl[HkA+2].V:=V;
  End;
 End;
End;

Procedure ColorFromSliders;
Begin
 Case RadioVal[3] Of
  0: ColCur:=MkRGB(Ctl[HkA].V,Ctl[HkA+1].V,Ctl[HkA+2].V);
  1: ColCur:=MkRGB(255-Ctl[HkA].V,255-Ctl[HkA+1].V,255-Ctl[HkA+2].V);
  Else ColCur:=HSVtoRGB(Ctl[HkA].V,Ctl[HkA+1].V,Ctl[HkA+2].V);
 End;
End;

Procedure ColorLabels;
Var I: Integer;
Begin
 Case RadioVal[3] Of
  0: Begin Ctl[HkB].T:='R';Ctl[HkB+1].T:='G';Ctl[HkB+2].T:='B';End;
  1: Begin Ctl[HkB].T:='C';Ctl[HkB+1].T:='M';Ctl[HkB+2].T:='J';End;
  Else Begin Ctl[HkB].T:='H';Ctl[HkB+1].T:='S';Ctl[HkB+2].T:='V';End;
 End;
 For I:=0 To 2 Do Ctl[HkA+I].Mx:=ModelMax(RadioVal[3],I);
End;

Procedure DlgHookProc;
Var I,G: Integer; V: Double; Ch: Boolean;
Begin
 Case DlgHookId Of
  1: Begin
      If RadioVal[3]<>ColModelPrev Then Begin
       ColModelPrev:=RadioVal[3];
       ColorLabels;
       SlidersFromColor;
      End Else Begin
       Ch:=False;
       For I:=0 To 2 Do If Ctl[HkA+I].V<>SlPrev[I+1] Then Ch:=True;
       If Ch Then ColorFromSliders;
      End;
      For I:=0 To 2 Do Begin
       SlPrev[I+1]:=Ctl[HkA+I].V;
       Ctl[HkC+I].S:=IntStr(Ctl[HkA+I].V);
      End;
      Ctl[HkD].V:=ColCur;
     End;
  2: Begin
      G:=Ctl[HkA].V;
      If G<>HkC Then Begin Ctl[HkB].S:=IntStr(G);HkC:=G;End;
     End;
 End;
End;

Procedure CmdColour;
Var R,I,S1,Fr,Fl,Sh,Cb,X,Y: Integer; P: PObj; Mx: Integer;
Begin
 P:=StyleRef;
 If P<>Nil Then ColCur:=P^.LineCol Else ColCur:=CurLineCol;
 DlgInit(L2('Colour','Couleur'),420,244);
 RadioVal[3]:=0;ColModelPrev:=0;
 HkB:=NCtl+1;
 AddLabel(14,44,'R');AddLabel(14,68,'G');AddLabel(14,92,'B');
 HkA:=NCtl+1;
 S1:=AddSlider(30,40,200,255,0);AddSlider(30,64,200,255,0);AddSlider(30,88,200,255,0);
 HkC:=NCtl+1;
 AddEdit(240,40,48,'0');AddEdit(240,64,48,'0');AddEdit(240,88,48,'0');
 For I:=0 To 15 Do Begin
  X:=14+(I Mod 8)*26;Y:=124+(I Div 8)*22;
  Cb:=AddCtl(DC_SWATCH,X,Y,22,16,'');
  Ctl[Cb].V:=I;Ctl[Cb].Id:=100+I;
 End;
 AddCtl(DC_FRAME,300,34,106,62,L2('Colour model','Modele'));
 AddRadio(308,44,3,0,'RGB');AddRadio(308,58,3,1,'CMY');AddRadio(308,72,3,2,'HSV');
 AddCtl(DC_FRAME,300,112,106,62,L2('Colour of','Couleur de'));
 Fr:=AddCheck(308,120,L2('Frames','Traits'),True);
 Fl:=AddCheck(308,134,L2('Fill','Remplissage'),True);
 Sh:=AddCheck(308,148,L2('Shadows','Ombres'),False);
 AddLabel(14,172,L2('Current colour:','Couleur courante :'));
 HkD:=AddCtl(DC_COLBOX,150,168,100,16,'');
 DlgHookId:=1;
 SlidersFromColor;Ctl[HkD].V:=ColCur;
 For I:=0 To 2 Do SlPrev[I+1]:=Ctl[HkA+I].V;
 For I:=0 To 2 Do Ctl[HkC+I].S:=IntStr(Ctl[HkA+I].V);
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  If (R>=100) And (R<116) Then Begin
   ColCur:=PalRGB(R-100);
   SlidersFromColor;
   Ctl[HkD].V:=ColCur;
   For I:=0 To 2 Do Begin SlPrev[I+1]:=Ctl[HkA+I].V;Ctl[HkC+I].S:=IntStr(Ctl[HkA+I].V);End;
   Continue;
  End;
  PushUndo;
  If Ctl[Fr].V<>0 Then CurLineCol:=ColCur;
  If Ctl[Fl].V<>0 Then CurFillCol:=ColCur;
  If Ctl[Sh].V<>0 Then CurShCol:=ColCur;
  For I:=1 To NObj Do
   If Objs[I]^.Sel Then Begin
    If Ctl[Fr].V<>0 Then Objs[I]^.LineCol:=ColCur;
    If Ctl[Fl].V<>0 Then Objs[I]^.FillCol:=ColCur;
    If Ctl[Sh].V<>0 Then Objs[I]^.ShCol:=ColCur;
   End;
  MarkModified;
  If R=ID_APPLY Then DrawAll;
 Until (R=ID_OK) Or (R=ID_CANCEL);
End;

Procedure SetTextSizeObj(O: PObj; Pt: Double);
Var Cell,L1,L2v: Double;
Begin
 O^.FSize:=Pt;
 If O^.Kind=OK_TEXT Then Begin
  Cell:=Pt*25.4/72;
  L1:=Hypot(O^.Nd^[1].X-O^.Nd^[0].X,O^.Nd^[1].Y-O^.Nd^[0].Y);
  L2v:=Hypot(O^.Nd^[2].X-O^.Nd^[0].X,O^.Nd^[2].Y-O^.Nd^[0].Y);
  If (L1>1E-6) And (L2v>1E-6) Then Begin
   O^.Nd^[1].X:=O^.Nd^[0].X+(O^.Nd^[1].X-O^.Nd^[0].X)*Cell/L1;
   O^.Nd^[1].Y:=O^.Nd^[0].Y+(O^.Nd^[1].Y-O^.Nd^[0].Y)*Cell/L1;
   O^.Nd^[2].X:=O^.Nd^[0].X+(O^.Nd^[2].X-O^.Nd^[0].X)*Cell/L2v;
   O^.Nd^[2].Y:=O^.Nd^[0].Y+(O^.Nd^[2].Y-O^.Nd^[0].Y)*Cell/L2v;
  End;
 End;
End;

Function TextSizePt(O: PObj): Double;
Begin
 If O^.Kind=OK_TEXT Then
  TextSizePt:=Hypot(O^.Nd^[2].X-O^.Nd^[0].X,O^.Nd^[2].Y-O^.Nd^[0].Y)*72/25.4
 Else TextSizePt:=O^.FSize;
End;

Procedure CmdText;
Var R,I,Sz,B,It,Un,Ou,Al: Integer; P: PObj; V: Double; Fl: Byte; Pt,AlN: Integer;
Begin
 P:=Nil;
 For I:=1 To NObj Do
  If Objs[I]^.Sel And (Objs[I]^.Kind In [OK_TEXT,OK_FTEXT]) Then Begin P:=Objs[I];Break;End;
 DlgInit(L2('Select Font','Police de caracteres'),340,176);
 AddLabel(14,40,L2('Size (pt):','Taille (pt) :'));
 If P<>Nil Then Sz:=AddEdit(110,36,60,RealStr(TextSizePt(P),1))
 Else Sz:=AddEdit(110,36,60,RealStr(CurFSize,1));
 If P<>Nil Then Fl:=P^.TFlags Else Fl:=CurTFlags;
 B:=AddCheck(14,64,L2('Bold','Gras'),(Fl And 1)<>0);
 It:=AddCheck(14,80,L2('Italic','Italique'),(Fl And 4)<>0);
 Un:=AddCheck(14,96,L2('Underline','Souligne'),(Fl And 2)<>0);
 Ou:=AddCheck(14,112,L2('Outline','Contour'),(Fl And 8)<>0);
 AddLabel(180,40,L2('Align:','Alignement :'));
 If P<>Nil Then AlN:=P^.TAlign Else AlN:=CurTAlign;
 Al:=AddPop(180,56,130,L2('Left|Centre|Right','Gauche|Centre|Droite'),AlN);
 AddLabel(180,84,L2('Font : System 8x8','Police : Systeme 8x8'));
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  If Not ParseNum(Ctl[Sz].S,V) Then V:=CurFSize;
  If V<4 Then V:=4;
  If V>400 Then V:=400;
  Fl:=0;
  If Ctl[B].V<>0 Then Fl:=Fl Or 1;
  If Ctl[Un].V<>0 Then Fl:=Fl Or 2;
  If Ctl[It].V<>0 Then Fl:=Fl Or 4;
  If Ctl[Ou].V<>0 Then Fl:=Fl Or 8;
  PushUndo;
  CurFSize:=V;CurTFlags:=Fl;CurTAlign:=Ctl[Al].V;
  For I:=1 To NObj Do
   If Objs[I]^.Sel And (Objs[I]^.Kind In [OK_TEXT,OK_FTEXT]) Then Begin
    SetTextSizeObj(Objs[I],V);
    Objs[I]^.TFlags:=Fl;Objs[I]^.TAlign:=Ctl[Al].V;
   End;
  MarkModified;
  If R=ID_APPLY Then DrawAll;
 Until R<>ID_APPLY;
End;

Procedure CmdShadows;
Var R,I,Sh,Ex,Ey: Integer; P: PObj; X,Y: Double; On1: Boolean;
Begin
 P:=StyleRef;
 DlgInit(L2('Shadows','Ombres'),320,150);
 If P<>Nil Then Begin On1:=P^.ShOn;X:=P^.ShDX;Y:=P^.ShDY;End
 Else Begin On1:=CurShOn;X:=CurShDX;Y:=CurShDY;End;
 Sh:=AddCheck(14,36,L2('Draw shadows','Dessiner les ombres'),On1);
 AddLabel(14,62,L2('x-offset:','Decalage x :'));
 Ex:=AddEdit(120,58,100,FmtLen(X));
 AddLabel(14,84,L2('y-offset:','Decalage y :'));
 Ey:=AddEdit(120,80,100,FmtLen(Y));
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  If Not ParseLen(Ctl[Ex].S,X) Then X:=5;
  If Not ParseLen(Ctl[Ey].S,Y) Then Y:=5;
  PushUndo;
  CurShOn:=Ctl[Sh].V<>0;CurShDX:=X;CurShDY:=Y;
  For I:=1 To NObj Do
   If Objs[I]^.Sel Then Begin
    Objs[I]^.ShOn:=CurShOn;Objs[I]^.ShDX:=X;Objs[I]^.ShDY:=Y;
   End;
  MarkModified;
  If R=ID_APPLY Then DrawAll;
 Until R<>ID_APPLY;
End;

Procedure CmdStatus;
Var R,I,C1,C2,C3,C4,C5: Integer; P: PObj;
Begin
 P:=StyleRef;
 If P=Nil Then Exit;
 DlgInit(L2('Object-Status','Statut de l''objet'),320,176);
 C1:=AddCheck(20,36,L2('Only on screen','Seulement a l''ecran'),P^.OnScreen);
 C2:=AddCheck(20,54,L2('Outline view','Vue en contour'),P^.Outline);
 C3:=AddCheck(20,72,L2('Locked','Verrouille'),P^.Locked);
 C4:=AddCheck(20,90,L2('Proportional resizing','Redim. proportionnel'),P^.PropRes);
 C5:=AddCheck(20,108,L2('No resizing','Pas de redimensionnement'),P^.NoRes);
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  PushUndo;
  For I:=1 To NObj Do
   If Objs[I]^.Sel Then Begin
    Objs[I]^.OnScreen:=Ctl[C1].V<>0;Objs[I]^.Outline:=Ctl[C2].V<>0;
    Objs[I]^.Locked:=Ctl[C3].V<>0;Objs[I]^.PropRes:=Ctl[C4].V<>0;
    Objs[I]^.NoRes:=Ctl[C5].V<>0;
    If Objs[I]^.Locked Then Objs[I]^.Sel:=False;
   End;
  MarkModified;
  If R=ID_APPLY Then DrawAll;
 Until R<>ID_APPLY;
End;

Function KindName(K: Byte): String;
Begin
 Case K Of
  OK_LINE: KindName:=L2('Line','Ligne');
  OK_POLY: KindName:=L2('Multi-line','Multi-ligne');
  OK_RECT: KindName:=L2('Rectangle','Rectangle');
  OK_RRECT: KindName:=L2('Rounded rectangle','Rect. arrondi');
  OK_TRI: KindName:=L2('Triangle','Triangle');
  OK_PARA: KindName:=L2('Parallelogram','Parallelogramme');
  OK_CIRCLE: KindName:=L2('Circle','Cercle');
  OK_ELLIPSE: KindName:=L2('Ellipse','Ellipse');
  OK_ARC: KindName:=L2('Circular arc','Arc circulaire');
  OK_EARC: KindName:=L2('Elliptical arc','Arc elliptique');
  OK_BEZIER: KindName:=L2('Bezier curve','Courbe de Bezier');
  OK_SPLINE: KindName:=L2('Spline curve','Courbe spline');
  OK_NGON: KindName:=L2('N-sides','N-cotes');
  OK_FREE: KindName:=L2('Freehand line','Main levee');
  OK_TEXT: KindName:=L2('Text','Texte');
  OK_FTEXT: KindName:=L2('Frame text','Texte cadre');
  OK_BITMAP: KindName:=L2('Bitmap graphic','Image bitmap');
  OK_COMPOUND: KindName:=L2('Compound path','Chemin compose');
  Else KindName:='?';
 End;
End;

Procedure CmdObjInfo;
Var R,Ex,Ey,Ew,Eh: Integer; P: PObj; X,Y,W,H,NX,NY,NW,NH,A,D: Double; Bytes: LongInt;
Begin
 P:=FirstSel;
 If P=Nil Then Exit;
 If Not SelBBox Then Exit;
 X:=SelBX1;Y:=SelBY1;W:=SelBX2-SelBX1;H:=SelBY2-SelBY1;
 DlgInit(L2('Object information','Information sur l''objet'),360,200);
 AddLabel(14,34,L2('Type: ','Type : ')+KindName(P^.Kind)+' ('+IntStr(CountSel)+')');
 AddLabel(14,48,L2('Nodes: ','Noeuds : ')+IntStr(P^.N)+L2('  Layer: ','  Calque : ')+IntStr(P^.Layer));
 AddLabel(14,76,'X:');Ex:=AddEdit(40,72,120,FmtLen(X));
 AddLabel(180,76,'Y:');Ey:=AddEdit(206,72,120,FmtLen(Y));
 AddLabel(14,100,L2('W:','L :'));Ew:=AddEdit(40,96,120,FmtLen(W));
 AddLabel(180,100,L2('H:','H :'));Eh:=AddEdit(206,96,120,FmtLen(H));
 AddLabel(14,124,L2('Tip: 3.46cm+1.5mm is accepted','Astuce : 3.46cm+1.5mm est accepte'));
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  NX:=X;NY:=Y;NW:=W;NH:=H;
  If Not ParseLen(Ctl[Ex].S,NX) Then NX:=X;
  If Not ParseLen(Ctl[Ey].S,NY) Then NY:=Y;
  If Not ParseLen(Ctl[Ew].S,NW) Then NW:=W;
  If Not ParseLen(Ctl[Eh].S,NH) Then NH:=H;
  If NW<0.01 Then NW:=0.01;
  If NH<0.01 Then NH:=0.01;
  PushUndo;
  If W>0.001 Then A:=NW/W Else A:=1;
  If H>0.001 Then D:=NH/H Else D:=1;
  XformSel(A,0,0,D,NX-X*A,NY-Y*D);
  MarkModified;
  X:=NX;Y:=NY;W:=NW;H:=NH;
  If R=ID_APPLY Then DrawAll;
 Until R<>ID_APPLY;
End;

{ ====================================================================== }
{                   ALIGNER, GRILLE, FORMAT, OPTIONS...                  }
{ ====================================================================== }

Type
 TBB = Record X1,Y1,X2,Y2: Double; O: PObj; End;

Procedure DoArrange(HM,VM: Integer; RH,RV: Double; Area: Integer);
Var BB: Array[1..60] Of TBB; N,I,J,Ax: Integer; Rx1,Ry1,Rx2,Ry2,DX,DY,Pos1,
 Tot,Gap,Sp: Double; T: TBB; Ref: PObj; Mother: PObj; Mode: Integer;
 R: Double;
Begin
 N:=0;
 Mother:=FirstSel;
 If Area=3 Then Begin
  If MarkObj=Nil Then Begin
   MsgBox(L2('Arrange','Aligner'),L2('No marked object','Aucun objet marque'));
   Exit;
  End;
  ObjBBox(MarkObj,Rx1,Ry1,Rx2,Ry2);
 End Else If Area=2 Then Begin
  If Mother=Nil Then Exit;
  ObjBBox(Mother,Rx1,Ry1,Rx2,Ry2);
 End Else Begin
  Rx1:=0;Ry1:=0;Rx2:=PageW;Ry2:=PageH;
 End;
 For I:=1 To NObj Do Begin
  If Not ObjVisible(Objs[I]) Then Continue;
  If Area=2 Then Begin
   If Objs[I]^.Sel Then Continue;
   ObjBBox(Objs[I],T.X1,T.Y1,T.X2,T.Y2);
   If (T.X1<Rx1) Or (T.X2>Rx2) Or (T.Y1<Ry1) Or (T.Y2>Ry2) Then Continue;
  End Else Begin
   If Not Objs[I]^.Sel Then Continue;
   ObjBBox(Objs[I],T.X1,T.Y1,T.X2,T.Y2);
  End;
  If N<60 Then Begin Inc(N);T.O:=Objs[I];BB[N]:=T;End;
 End;
 If N=0 Then Exit;
 PushUndo;
 For Ax:=0 To 1 Do Begin
  If Ax=0 Then Mode:=HM Else Mode:=VM;
  If Ax=0 Then R:=RH Else R:=RV;
  If Mode=0 Then Continue;
  { tri par position }
  For I:=1 To N-1 Do
   For J:=I+1 To N Do Begin
    If Ax=0 Then Begin
     If BB[J].X1<BB[I].X1 Then Begin T:=BB[I];BB[I]:=BB[J];BB[J]:=T;End;
    End Else If BB[J].Y1<BB[I].Y1 Then Begin T:=BB[I];BB[I]:=BB[J];BB[J]:=T;End;
   End;
  Case Mode Of
   1,2,3: For I:=1 To N Do Begin
     DX:=0;DY:=0;
     If Ax=0 Then Begin
      Case Mode Of
       1: DX:=Rx1-BB[I].X1;
       2: DX:=(Rx1+Rx2)/2-(BB[I].X1+BB[I].X2)/2;
       Else DX:=Rx2-BB[I].X2;
      End;
     End Else Begin
      Case Mode Of
       1: DY:=Ry1-BB[I].Y1;
       2: DY:=(Ry1+Ry2)/2-(BB[I].Y1+BB[I].Y2)/2;
       Else DY:=Ry2-BB[I].Y2;
      End;
     End;
     XformObj(BB[I].O,1,0,0,1,DX,DY);
    End;
   4: Begin
     Pos1:=0;
     For I:=1 To N Do Begin
      If Ax=0 Then Begin
       If I=1 Then Pos1:=BB[1].X2+R Else Begin
        XformObj(BB[I].O,1,0,0,1,Pos1-BB[I].X1,0);
        Pos1:=Pos1+(BB[I].X2-BB[I].X1)+R;
       End;
      End Else Begin
       If I=1 Then Pos1:=BB[1].Y2+R Else Begin
        XformObj(BB[I].O,1,0,0,1,0,Pos1-BB[I].Y1);
        Pos1:=Pos1+(BB[I].Y2-BB[I].Y1)+R;
       End;
      End;
     End;
    End;
   5: If N>1 Then Begin
     Tot:=0;
     For I:=1 To N Do
      If Ax=0 Then Tot:=Tot+BB[I].X2-BB[I].X1 Else Tot:=Tot+BB[I].Y2-BB[I].Y1;
     If Ax=0 Then Sp:=BB[N].X2-BB[1].X1 Else Sp:=BB[N].Y2-BB[1].Y1;
     If R>0 Then Gap:=R Else Gap:=(Sp-Tot)/(N-1);
     If Ax=0 Then Pos1:=BB[1].X2+Gap Else Pos1:=BB[1].Y2+Gap;
     For I:=2 To N Do Begin
      If Ax=0 Then Begin
       XformObj(BB[I].O,1,0,0,1,Pos1-BB[I].X1,0);
       Pos1:=Pos1+(BB[I].X2-BB[I].X1)+Gap;
      End Else Begin
       XformObj(BB[I].O,1,0,0,1,0,Pos1-BB[I].Y1);
       Pos1:=Pos1+(BB[I].Y2-BB[I].Y1)+Gap;
      End;
     End;
    End;
   6: If R>0 Then For I:=1 To N Do Begin
     If Ax=0 Then XformObj(BB[I].O,1,0,0,1,SnapV(BB[I].X1,R)-BB[I].X1,0)
     Else XformObj(BB[I].O,1,0,0,1,0,SnapV(BB[I].Y1,R)-BB[I].Y1);
    End;
   7: For I:=1 To N Do Begin
     If Ax=0 Then XformObj(BB[I].O,1,0,0,1,R-BB[I].X1,0)
     Else XformObj(BB[I].O,1,0,0,1,0,R-BB[I].Y1);
    End;
  End;
  { recalcul des boites }
  For I:=1 To N Do ObjBBox(BB[I].O,BB[I].X1,BB[I].Y1,BB[I].X2,BB[I].Y2);
 End;
 MarkModified;
End;

Procedure CmdArrange;
Var R,Hp,Vp,Eh,Ev: Integer; RH,RV: Double; Items: String;
Begin
 If CountSel=0 Then Exit;
 Items:=L2('None|Left/Top|Centred|Right/Bottom|Stacked|Equidistant|To grid|Absolute',
   'Aucun|Gauche/Haut|Centre|Droite/Bas|Empile|Equidistant|Sur la grille|Absolu');
 DlgInit(L2('Arrange objects','Aligner les objets'),420,206);
 RadioVal[4]:=1;
 AddLabel(14,36,L2('Horizontal:','Horizontal :'));
 Hp:=AddPop(110,32,130,Items,0);
 AddLabel(250,36,L2('Raster:','Trame :'));
 Eh:=AddEdit(310,32,92,'10mm');
 AddLabel(14,60,L2('Vertical:','Vertical :'));
 Vp:=AddPop(110,56,130,Items,0);
 AddLabel(250,60,L2('Raster:','Trame :'));
 Ev:=AddEdit(310,56,92,'10mm');
 AddCtl(DC_FRAME,14,94,392,50,L2('Work area','Zone de travail'));
 AddRadio(24,102,4,1,L2('Selected object','Objet selectionne (page)'));
 AddRadio(24,116,4,2,L2('Inside object','A l''interieur de l''objet'));
 AddRadio(24,130,4,3,L2('Marked object','Objet marque'));
 AddBtn(280,114,110,4,L2('Mark object','Marquer objet'));
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  If R=4 Then Begin MarkObj:=FirstSel;Continue;End;
  If Not ParseLen(Ctl[Eh].S,RH) Then RH:=0;
  If Not ParseLen(Ctl[Ev].S,RV) Then RV:=0;
  DoArrange(Ctl[Hp].V,Ctl[Vp].V,RH,RV,RadioVal[4]);
  If R=ID_APPLY Then DrawAll;
 Until (R=ID_OK) Or (R=ID_CANCEL);
End;

Procedure CmdGrid;
Var R,Dg,Sn,Ex,Ey: Integer; X,Y: Double;
Begin
 DlgInit(L2('Grid','Grille'),300,150);
 Dg:=AddCheck(30,36,L2('Draw grid','Afficher la grille'),GridShow);
 Sn:=AddCheck(30,52,L2('Snap to grid','Aimanter a la grille'),GridSnap);
 AddLabel(30,78,'X:');Ex:=AddEdit(60,74,100,FmtLen(GridX));
 AddLabel(30,98,'Y:');Ey:=AddEdit(60,94,100,FmtLen(GridY));
 AddStdBtns(False);
 If RunDialog=ID_OK Then Begin
  GridShow:=Ctl[Dg].V<>0;GridSnap:=Ctl[Sn].V<>0;
  If ParseLen(Ctl[Ex].S,X) And (X>0.1) Then GridX:=X;
  If ParseLen(Ctl[Ey].S,Y) And (Y>0.1) Then GridY:=Y;
 End;
End;

Procedure CmdFormat;
Var R,Eu,Ew,Eh,F: Integer; W,H: Double;
Begin
 DlgInit(L2('Page format','Format de page'),380,170);
 F:=6;
 If (PageW=210) And (PageH=297) Then F:=1
 Else If (PageW=297) And (PageH=210) Then F:=2
 Else If (PageW=148) And (PageH=210) Then F:=3
 Else If (PageW=210) And (PageH=148) Then F:=4
 Else If (PageW=297) And (PageH=420) Then F:=5;
 RadioVal[5]:=F;
 AddRadio(14,34,5,1,'A4 '+L2('Portrait','Portrait'));
 AddRadio(14,50,5,2,'A4 '+L2('Landscape','Paysage'));
 AddRadio(14,66,5,3,'A5 '+L2('Portrait','Portrait'));
 AddRadio(190,34,5,4,'A5 '+L2('Landscape','Paysage'));
 AddRadio(190,50,5,5,'A3 '+L2('Portrait','Portrait'));
 AddRadio(14,92,5,6,L2('User:','Utilisateur :'));
 Ew:=AddEdit(120,90,80,FmtLen(PageW));AddLabel(206,94,'x');
 Eh:=AddEdit(220,90,80,FmtLen(PageH));
 AddStdBtns(False);
 If RunDialog=ID_OK Then Begin
  Case RadioVal[5] Of
   1: Begin PageW:=210;PageH:=297;End;
   2: Begin PageW:=297;PageH:=210;End;
   3: Begin PageW:=148;PageH:=210;End;
   4: Begin PageW:=210;PageH:=148;End;
   5: Begin PageW:=297;PageH:=420;End;
   Else Begin
    If ParseLen(Ctl[Ew].S,W) And (W>=10) Then PageW:=W;
    If ParseLen(Ctl[Eh].S,H) And (H>=10) Then PageH:=H;
   End;
  End;
  MarkModified;
  ZoomFullPage;
 End;
End;

Procedure SaveOptions;
Var F: Text;
Begin
 {$I-}
 Assign(F,'ARTWORX.INF');
 Rewrite(F);
 {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(F,'UNIT=',UnitIdx);
 WriteLn(F,'DKEY=',Ord(OptDKey));
 WriteLn(F,'BEEP=',Ord(OptBeep));
 WriteLn(F,'CONFIRM=',Ord(OptConfirm));
 WriteLn(F,'UNDO=',Ord(OptUndo));
 WriteLn(F,'GRIDSHOW=',Ord(GridShow));
 WriteLn(F,'GRIDSNAP=',Ord(GridSnap));
 WriteLn(F,'GRIDX=',RealStr(GridX,2));
 WriteLn(F,'GRIDY=',RealStr(GridY,2));
 WriteLn(F,'IMAGES=',OptImages);
 WriteLn(F,'MODULE=',OptModule);
 WriteLn(F,'EDITOR=',OptEditor);
 Close(F);
End;

Procedure LoadOptions;
Var F: Text; Ln,K,V: String; P: Integer; X: Double; Code: Integer; N: LongInt;
Begin
 {$I-}
 Assign(F,'ARTWORX.INF');
 Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 While Not Eof(F) Do Begin
  ReadLn(F,Ln);
  P:=Pos('=',Ln);
  If P=0 Then Continue;
  K:=Copy(Ln,1,P-1);V:=Copy(Ln,P+1,200);
  Val(V,N,Code);
  If K='UNIT' Then UnitIdx:=Clamp(N,0,3)
  Else If K='DKEY' Then OptDKey:=N<>0
  Else If K='BEEP' Then OptBeep:=N<>0
  Else If K='CONFIRM' Then OptConfirm:=N<>0
  Else If K='UNDO' Then OptUndo:=N<>0
  Else If K='GRIDSHOW' Then GridShow:=N<>0
  Else If K='GRIDSNAP' Then GridSnap:=N<>0
  Else If K='GRIDX' Then Begin If ParseNum(V,X) And (X>0.1) Then GridX:=X;End
  Else If K='GRIDY' Then Begin If ParseNum(V,X) And (X>0.1) Then GridY:=X;End
  Else If K='IMAGES' Then OptImages:=V
  Else If K='MODULE' Then OptModule:=V
  Else If K='EDITOR' Then OptEditor:=V;
 End;
 Close(F);
End;

Procedure CmdGeneral;
Var C1,C2,C3,C4,C5,C6,Un: Integer;
Begin
 DlgInit(L2('General Settings','Parametres generaux'),360,196);
 C1:=AddCheck(14,34,L2('"D" deletes object','"D" supprime l''objet'),OptDKey);
 C2:=AddCheck(14,50,L2('Beep on errors','Bip sur erreur'),OptBeep);
 C3:=AddCheck(14,66,L2('Delete confirmation','Confirmer la suppression'),OptConfirm);
 C4:=AddCheck(14,82,L2('Use clipboard file','Utiliser le presse-papiers'),OptClip);
 C5:=AddCheck(14,98,L2('Undo','Annuler (Undo)'),OptUndo);
 C6:=AddCheck(14,114,L2('New objects in TrueColor','Nouveaux objets en TrueColor'),OptTrue);
 AddLabel(14,140,L2('Units:','Unites :'));
 Un:=AddPop(80,136,140,L2('Millimeter [mm]|Centimeter [cm]|Inch [in]|Point [pt]',
   'Millimetre [mm]|Centimetre [cm]|Pouce [in]|Point [pt]'),UnitIdx);
 AddStdBtns(False);
 If RunDialog=ID_OK Then Begin
  OptDKey:=Ctl[C1].V<>0;OptBeep:=Ctl[C2].V<>0;OptConfirm:=Ctl[C3].V<>0;
  OptClip:=Ctl[C4].V<>0;OptUndo:=Ctl[C5].V<>0;OptTrue:=Ctl[C6].V<>0;
  UnitIdx:=Ctl[Un].V;
 End;
End;

Procedure CmdPaths;
Var Ei,Em: Integer;
Begin
 DlgInit(L2('External path settings','Chemins externes'),420,120);
 AddLabel(14,38,L2('Images:','Images :'));
 Ei:=AddEdit(88,34,320,OptImages);
 AddLabel(14,62,L2('Module:','Module :'));
 Em:=AddEdit(88,58,320,OptModule);
 AddStdBtns(False);
 If RunDialog=ID_OK Then Begin OptImages:=Ctl[Ei].S;OptModule:=Ctl[Em].S;End;
End;

Procedure CmdEditor;
Var Ed: Integer;
Begin
 DlgInit(L2('Editor-Settings','Reglages de l''editeur'),420,100);
 AddLabel(14,38,L2('Editor:','Editeur :'));
 Ed:=AddEdit(88,34,320,OptEditor);
 AddStdBtns(False);
 If RunDialog=ID_OK Then OptEditor:=Ctl[Ed].S;
End;

Procedure CmdImages;
Var Dp: Integer; V: Double;
Begin
 DlgInit(L2('Image settings','Reglages des images'),360,110);
 AddLabel(14,38,L2('Resolution (dpi):','Resolution (dpi) :'));
 Dp:=AddEdit(170,34,60,IntStr(Round(ImgDpi)));
 AddLabel(14,60,L2('Used to fit imported bitmaps','Sert a ajuster les bitmaps importes'));
 AddStdBtns(False);
 If RunDialog=ID_OK Then
  If ParseNum(Ctl[Dp].S,V) And (V>=30) And (V<=2400) Then ImgDpi:=V;
End;

Procedure CmdZoomDlg;
Var R: Integer;
Begin
 R:=PopupChoice('12%|25%|50%|75%|100%|150%|200%|400%|800%|'+L2('Full page','Page entiere'),
   220,120,4);
 Case R Of
  0: ZoomAround(12,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  1: ZoomAround(25,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  2: ZoomAround(50,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  3: ZoomAround(75,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  4: ZoomAround(100,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  5: ZoomAround(150,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  6: ZoomAround(200,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  7: ZoomAround(400,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  8: ZoomAround(800,(OrgX+CvW/Sc/2),(OrgY+CvH/Sc/2));
  9: ZoomFullPage;
 End;
End;

Procedure CmdLayers;
Var R,L,I,Lst: Integer; S: String; Ed: Integer;
 Procedure Fill;
 Var K: Integer;
 Begin
  LstN:=NLAYER;
  For K:=1 To NLAYER Do Begin
   S:=Layers[K].Name;
   While Length(S)<14 Do S:=S+' ';
   If K=CurLayer Then S:='>'+S Else S:=' '+S;
   If Layers[K].Locked Then S:=S+'L' Else S:=S+'-';
   If Layers[K].OnScreen Then S:=S+'S' Else S:=S+'-';
   If Layers[K].Hidden Then S:=S+'I' Else S:=S+'-';
   LstItem[K]:=S;
  End;
 End;
Begin
 L:=CurLayer;
 Repeat
  Fill;
  DlgInit(L2('Layers','Calques'),400,220);
  Lst:=AddCtl(DC_LIST,14,32,230,110,'');
  Ctl[Lst].V:=L;
  AddBtn(256,32,130,4,L2('Activate','Activer'));
  AddBtn(256,54,130,5,L2('Locked','Verrouille'));
  AddBtn(256,76,130,6,L2('Only on screen','Ecran seul'));
  AddBtn(256,98,130,7,L2('Invisible','Invisible'));
  AddBtn(256,120,130,8,L2('Rename...','Renommer...'));
  AddLabel(14,150,L2('L=locked S=screen only I=invisible','L=verrouille S=ecran I=invisible'));
  AddBtn(DlgW-82,DlgH-26,70,ID_OK,'OK');
  Ctl[NCtl].Mx:=1;
  R:=RunDialog;
  L:=Ctl[Lst].V;
  If L<1 Then L:=1;
  Case R Of
   4: CurLayer:=L;
   5: Layers[L].Locked:=Not Layers[L].Locked;
   6: Layers[L].OnScreen:=Not Layers[L].OnScreen;
   7: Layers[L].Hidden:=Not Layers[L].Hidden;
   8: Begin S:=Layers[L].Name;If InputBox(L2('Layer name','Nom du calque'),L2('Name:','Nom :'),S,16) Then Layers[L].Name:=Copy(S,1,20);End;
  End;
 Until (R=ID_OK) Or (R=ID_CANCEL);
 DeselectAll;
End;

{ ====================================================================== }
{                  TRANSFORMATIONS (formules utilisateur)                }
{ ====================================================================== }

Var
 FxS: String;
 FxP: Integer;
 FxX,FxY,FxA,FxB: Double;
 FxOk: Boolean;

Procedure FxSkip;
Begin
 While (FxP<=Length(FxS)) And (FxS[FxP]=' ') Do Inc(FxP);
End;

Function FxExpr: Double; Forward;

Function FxFunc(Const Nm: String; V: Double): Double;
Var N: String;
Begin
 N:=Lower(Nm);
 FxFunc:=0;
 If N='sin' Then FxFunc:=Sin(V)
 Else If N='cos' Then FxFunc:=Cos(V)
 Else If N='tan' Then Begin If Cos(V)=0 Then FxOk:=False Else FxFunc:=Sin(V)/Cos(V);End
 Else If N='cot' Then Begin If Sin(V)=0 Then FxOk:=False Else FxFunc:=Cos(V)/Sin(V);End
 Else If N='log' Then Begin If V<=0 Then FxOk:=False Else FxFunc:=Ln(V)/Ln(10);End
 Else If N='ln' Then Begin If V<=0 Then FxOk:=False Else FxFunc:=Ln(V);End
 Else If N='sqr' Then Begin If V<0 Then FxOk:=False Else FxFunc:=Sqrt(V);End
 Else If N='abs' Then FxFunc:=Abs(V)
 Else If N='sgn' Then Begin If V>0 Then FxFunc:=1 Else If V<0 Then FxFunc:=-1;End
 Else If N='arcsin' Then FxFunc:=ASin(V)
 Else If N='arccos' Then FxFunc:=ACos(V)
 Else If N='arctan' Then FxFunc:=ArcTan(V)
 Else If N='arccot' Then FxFunc:=Pi/2-ArcTan(V)
 Else If N='sinh' Then FxFunc:=(Exp(V)-Exp(-V))/2
 Else If N='cosh' Then FxFunc:=(Exp(V)+Exp(-V))/2
 Else If N='tanh' Then FxFunc:=(Exp(V)-Exp(-V))/(Exp(V)+Exp(-V))
 Else If N='coth' Then Begin If V=0 Then FxOk:=False Else FxFunc:=(Exp(V)+Exp(-V))/(Exp(V)-Exp(-V));End
 Else If N='arsinh' Then FxFunc:=Ln(V+Sqrt(V*V+1))
 Else If N='arcosh' Then Begin If V<1 Then FxOk:=False Else FxFunc:=Ln(V+Sqrt(V*V-1));End
 Else If N='artanh' Then Begin If Abs(V)>=1 Then FxOk:=False Else FxFunc:=0.5*Ln((1+V)/(1-V));End
 Else If N='arcoth' Then Begin If Abs(V)<=1 Then FxOk:=False Else FxFunc:=0.5*Ln((V+1)/(V-1));End
 Else If N='sec' Then Begin If Cos(V)=0 Then FxOk:=False Else FxFunc:=1/Cos(V);End
 Else If N='cosec' Then Begin If Sin(V)=0 Then FxOk:=False Else FxFunc:=1/Sin(V);End
 Else FxOk:=False;
End;

Function IsFuncName(Const N0: String): Boolean;
Var N: String;
Begin
 N:=Lower(N0);
 IsFuncName:=(N='sin') Or (N='cos') Or (N='tan') Or (N='cot') Or (N='log') Or
  (N='ln') Or (N='sqr') Or (N='abs') Or (N='sgn') Or (N='arcsin') Or
  (N='arccos') Or (N='arctan') Or (N='arccot') Or (N='sinh') Or (N='cosh') Or
  (N='tanh') Or (N='coth') Or (N='arsinh') Or (N='arcosh') Or (N='artanh') Or
  (N='arcoth') Or (N='sec') Or (N='cosec');
End;

Function FxUnary: Double; Forward;

Function FxPrim: Double;
Var S: String; V,R: Double; Code,I: Integer; Nm: String;
Begin
 FxPrim:=0;
 FxSkip;
 If FxP>Length(FxS) Then Begin FxOk:=False;Exit;End;
 If FxS[FxP] In ['0'..'9','.'] Then Begin
  S:='';
  While (FxP<=Length(FxS)) And (FxS[FxP] In ['0'..'9','.']) Do Begin
   S:=S+FxS[FxP];Inc(FxP);
  End;
  Val(S,V,Code);
  If Code<>0 Then FxOk:=False;
  FxPrim:=V;
 End Else If FxS[FxP]='(' Then Begin
  Inc(FxP);
  V:=FxExpr;
  FxSkip;
  If (FxP<=Length(FxS)) And (FxS[FxP]=')') Then Inc(FxP) Else FxOk:=False;
  FxPrim:=V;
 End Else If UpCase(FxS[FxP]) In ['A'..'Z'] Then Begin
  Nm:='';
  While (FxP<=Length(FxS)) And (UpCase(FxS[FxP]) In ['A'..'Z']) Do Begin
   Nm:=Nm+FxS[FxP];Inc(FxP);
  End;
  If IsFuncName(Nm) Then Begin
   FxSkip;
   If (FxP<=Length(FxS)) And (FxS[FxP]='(') Then Begin
    Inc(FxP);V:=FxExpr;FxSkip;
    If (FxP<=Length(FxS)) And (FxS[FxP]=')') Then Inc(FxP) Else FxOk:=False;
   End Else V:=FxUnary;
   FxPrim:=FxFunc(Nm,V);
  End Else Begin
   R:=1;
   For I:=1 To Length(Nm) Do Begin
    Case Nm[I] Of
     'x','X': R:=R*FxX;
     'y','Y': R:=R*FxY;
     'A': R:=R*FxA;
     'B': R:=R*FxB;
     'e': R:=R*Exp(1);
     'p','P': R:=R*Pi;
     'a': R:=R*FxA;
     'b': R:=R*FxB;
     Else FxOk:=False;
    End;
   End;
   FxPrim:=R;
  End;
 End Else FxOk:=False;
End;

Function FxPow: Double;
Var B,E: Double;
Begin
 B:=FxPrim;
 FxSkip;
 If (FxP<=Length(FxS)) And (FxS[FxP]='^') Then Begin
  Inc(FxP);
  E:=FxUnary;
  FxPow:=Power(B,E);
 End Else FxPow:=B;
End;

Function FxUnary: Double;
Begin
 FxSkip;
 If (FxP<=Length(FxS)) And (FxS[FxP]='-') Then Begin
  Inc(FxP);FxUnary:=-FxUnary;
 End Else If (FxP<=Length(FxS)) And (FxS[FxP]='+') Then Begin
  Inc(FxP);FxUnary:=FxUnary;
 End Else FxUnary:=FxPow;
End;

Function FxTerm: Double;
Var R,B: Double; C: Char;
Begin
 R:=FxUnary;
 Repeat
  FxSkip;
  If FxP>Length(FxS) Then Break;
  C:=FxS[FxP];
  If (C='*') Then Begin Inc(FxP);R:=R*FxUnary;End
  Else If (C='/') Or (C=':') Then Begin
   Inc(FxP);B:=FxUnary;
   If B=0 Then Begin FxOk:=False;B:=1;End;
   R:=R/B;
  End Else If (C In ['0'..'9','.','(']) Or (UpCase(C) In ['A'..'Z']) Then
   R:=R*FxPow
  Else Break;
 Until False;
 FxTerm:=R;
End;

Function FxExpr: Double;
Var R: Double; C: Char;
Begin
 R:=FxTerm;
 Repeat
  FxSkip;
  If FxP>Length(FxS) Then Break;
  C:=FxS[FxP];
  If C='+' Then Begin Inc(FxP);R:=R+FxTerm;End
  Else If C='-' Then Begin Inc(FxP);R:=R-FxTerm;End
  Else Break;
 Until False;
 FxExpr:=R;
End;

Function FxEval(Const S: String; X,Y,A,B: Double; Var Ok: Boolean): Double;
Begin
 FxS:=S;FxP:=1;FxOk:=True;FxX:=X;FxY:=Y;FxA:=A;FxB:=B;
 If TrimStr(S)='' Then Begin Ok:=False;FxEval:=0;Exit;End;
 FxEval:=FxExpr;
 FxSkip;
 If FxP<=Length(FxS) Then FxOk:=False;
 Ok:=FxOk;
End;

Procedure ApplyTransform(Idx: Integer; Const Fxs,Fys: String; A,B: Double);
Var X0,Y0,X1,Y1,W,H,CX,CY,Rad,T,Span,R0,R,Ang,U,V,NX,NY: Double; I,J: Integer; O: PObj;
 Ok1,Ok2: Boolean; Aff: Boolean;
 Procedure Map(Var PX,PY: Double);
 Begin
  NX:=PX;NY:=PY;
  Case Idx Of
   0: Begin
       NX:=FxEval(Fxs,PX*10,PY*10,A,B,Ok1)/10;
       NY:=FxEval(Fys,PX*10,PY*10,A,B,Ok2)/10;
      End;
   5: Begin
       NX:=PX+(Rnd01*2-1)*A*10;NY:=PY+(Rnd01*2-1)*A*10;
      End;
   7: If B<>0 Then NY:=PY+A*10*Sin(2*Pi*(PX-X0)/(B*10));
   8: If B<>0 Then NX:=PX+A*10*Sin(2*Pi*(PY-Y0)/(B*10));
   9: Begin
       Ang:=(A+(B-A)*(PX-X0)/W)*Pi/180;
       R:=R0+(Y1-PY);
       NX:=CX+R*Sin(Ang);NY:=CY-R*Cos(Ang);
      End;
   10: Begin
        U:=(PX-PageW/2)/(PageW/2);V:=(PY-PageH/2)/(PageW/2);
        If U>1 Then U:=1;If U<-1 Then U:=-1;
        If V>1 Then V:=1;If V<-1 Then V:=-1;
        NX:=PageW/2+PageW/2*Sin(U*Pi/2)*Cos(V*Pi/2);
        NY:=PageH/2+PageW/2*Sin(V*Pi/2);
       End;
  End;
  PX:=NX;PY:=NY;
 End;
Begin
 If Not SelBBox Then Exit;
 X0:=SelBX1;Y0:=SelBY1;X1:=SelBX2;Y1:=SelBY2;
 W:=X1-X0;H:=Y1-Y0;CX:=(X0+X1)/2;CY:=(Y0+Y1)/2;
 If W<0.01 Then W:=0.01;
 Aff:=Idx In [1,2,3,4,6];
 If Idx=0 Then Begin
  FxEval(Fxs,1,1,A,B,Ok1);FxEval(Fys,1,1,A,B,Ok2);
  If Not (Ok1 And Ok2) Then Begin
   MsgBox(L2('Transform','Transformer'),L2('Invalid formula','Formule invalide'));
   Exit;
  End;
 End;
 PushUndo;
 If Aff Then Begin
  Case Idx Of
   1: XformSel(-1,0,0,-1,2*X0,2*Y1);
   2: XformSel(-1,0,0,1,2*X0,0);
   3: XformSel(1,0,0,-1,0,2*Y1);
   4: Begin
       If A=0 Then A:=1;If B=0 Then B:=A;
       XformSel(A,0,0,B,X0*(1-A),Y0*(1-B));
      End;
   6: Begin
       T:=A*Pi/180;
       XformSel(Cos(T),Sin(T),-Sin(T),Cos(T),CX-CX*Cos(T)+CY*Sin(T),
         CY-CX*Sin(T)-CY*Cos(T));
      End;
  End;
 End Else Begin
  If Idx=5 Then Begin If A=0 Then A:=0.1;End;
  If (Idx=7) Or (Idx=8) Then Begin If B=0 Then Begin If Idx=7 Then B:=W/10 Else B:=H/10;End;End;
  If Idx=9 Then Begin
   If (A=0) And (B=0) Then B:=360;
   Span:=(B-A)*Pi/180;
   If Span=0 Then Span:=2*Pi;
   R0:=W/Abs(Span);
  End;
  For I:=1 To NObj Do Begin
   O:=Objs[I];
   If Not O^.Sel Then Continue;
   If O^.Kind In [OK_TEXT,OK_FTEXT,OK_BITMAP] Then Continue;
   If Not ToPathObj(O) Then Continue;
   For J:=0 To O^.N-1 Do Begin
    Map(O^.Nd^[J].X,O^.Nd^[J].Y);
    Map(O^.Nd^[J].AX,O^.Nd^[J].AY);
    Map(O^.Nd^[J].BX,O^.Nd^[J].BY);
   End;
  End;
 End;
 MarkModified;
End;

Procedure CmdTransform;
Var R,Lst,Ex,Ey,Ea,Eb: Integer; A,B: Double;
Begin
 If CountSel=0 Then Exit;
 LstN:=11;
 LstItem[1]:=L2('User','Utilisateur');LstItem[2]:=L2('Point mirror','Miroir point');
 LstItem[3]:=L2('Y-mirror','Miroir Y');LstItem[4]:=L2('X-mirror','Miroir X');
 LstItem[5]:=L2('Scale','Echelle');LstItem[6]:=L2('Random','Aleatoire');
 LstItem[7]:=L2('Rotate','Rotation');LstItem[8]:=L2('Sine (hor.)','Sinus (hor.)');
 LstItem[9]:=L2('Sine (ver.)','Sinus (ver.)');LstItem[10]:='Circ.';
 LstItem[11]:='Globe';
 DlgInit(L2('Object transformation','Transformation de l''objet'),440,262);
 AddLabel(14,36,'x'''+'=');Ex:=AddEdit(44,32,384,'x');
 AddLabel(14,58,'y'''+'=');Ey:=AddEdit(44,54,384,'y');
 Lst:=AddCtl(DC_LIST,14,84,170,100,'');Ctl[Lst].V:=1;
 AddCtl(DC_FRAME,196,88,232,96,L2('Transformation','Transformation'));
 AddLabel(206,100,L2('Formula in 1/10 mm (x,y,A,B)','Formule en 1/10 mm (x,y,A,B)'));
 AddLabel(206,116,L2('Constants / Constantes:','Constantes :'));
 AddLabel(206,138,'A:');Ea:=AddEdit(236,134,100,'0');
 AddLabel(206,158,'B:');Eb:=AddEdit(236,154,100,'0');
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  If Not ParseNum(Ctl[Ea].S,A) Then A:=0;
  If Not ParseNum(Ctl[Eb].S,B) Then B:=0;
  ApplyTransform(Ctl[Lst].V-1,Ctl[Ex].S,Ctl[Ey].S,A,B);
  If R=ID_APPLY Then DrawAll;
 Until R<>ID_APPLY;
End;

{ ====================================================================== }
{                              TILING                                    }
{ ====================================================================== }

Procedure CmdTiling;
Var R,Cm,Cs,Cp,Cc,Cr,Cn,Cb,Ex,Ey,Efx,Efy,Ep1,Ep2,Ea,Ei,Erx,Ery: Integer;
 DX,DY,FX,FY,P1,P2,Ang,RotX,RotY,T: Double; Iter,It,I,K,N0,NS: Integer;
 Last,Cur: Array[1..40] Of PObj; Sel: Array[1..40] Of PObj; Col1,Col2: LongInt;
 P: PObj; X1,Y1,X2,Y2,CX,CY,BX1,BY1,BX2,BY2,PvX,PvY,CsA,SnA: Double;
 Tmp: Array[1..MAXOBJ] Of PObj; N,J: Integer;
Begin
 NS:=0;
 For I:=1 To NObj Do If Objs[I]^.Sel And (NS<40) Then Begin Inc(NS);Sel[NS]:=Objs[I];End;
 If NS=0 Then Exit;
 Col1:=CurLineCol;Col2:=CurFillCol;
 DlgInit('Tiling',470,238);
 Cm:=AddCheck(14,34,L2('Move','Deplacer'),False);
 AddLabel(130,38,'dx:');Ex:=AddEdit(160,34,80,'10mm');
 AddLabel(250,38,'dy:');Ey:=AddEdit(280,34,80,'10mm');
 Cs:=AddCheck(14,56,L2('Scale','Echelle'),False);
 AddLabel(130,60,'x:');Efx:=AddEdit(160,56,80,'1');
 AddLabel(250,60,'y:');Efy:=AddEdit(280,56,80,'1');
 Cp:=AddCheck(14,78,L2('Pattern gradient','Degrade de trame'),False);
 AddLabel(190,82,L2('from','de'));Ep1:=AddEdit(225,78,50,'0');
 AddLabel(285,82,L2('to','a'));Ep2:=AddEdit(310,78,50,'255');
 Cc:=AddCheck(14,100,L2('Colour gradient','Degrade de couleur'),False);
 AddBtn(190,98,80,4,L2('Start=cur','Debut=cour.'));
 AddBtn(280,98,80,5,L2('End=cur','Fin=cour.'));
 Cr:=AddCheck(14,122,L2('Rotation','Rotation'),False);
 AddLabel(130,126,L2('angle:','angle :'));Ea:=AddEdit(190,122,60,'90');
 AddLabel(256,126,L2('degrees','degres'));
 Cn:=AddCheck(14,144,L2('Use new rotation point','Point de rotation libre'),False);
 AddLabel(250,148,'X:');Erx:=AddEdit(272,144,70,'');
 AddLabel(350,148,'Y:');Ery:=AddEdit(372,144,70,'');
 Cb:=AddCheck(14,166,L2('Put objects to back','Objets en arriere-plan'),False);
 AddLabel(14,192,L2('Iterations:','Iterations :'));Ei:=AddEdit(100,188,50,'1');
 AddStdBtns(True);
 Repeat
  R:=RunDialog;
  If R=ID_CANCEL Then Exit;
  If R=4 Then Begin Col1:=CurFillCol;Continue;End;
  If R=5 Then Begin Col2:=CurFillCol;Continue;End;
  If Not ParseLen(Ctl[Ex].S,DX) Then DX:=10;
  If Not ParseLen(Ctl[Ey].S,DY) Then DY:=10;
  If Not ParseNum(Ctl[Efx].S,FX) Then FX:=1;
  If Not ParseNum(Ctl[Efy].S,FY) Then FY:=1;
  If Not ParseNum(Ctl[Ep1].S,P1) Then P1:=0;
  If Not ParseNum(Ctl[Ep2].S,P2) Then P2:=255;
  If Not ParseNum(Ctl[Ea].S,Ang) Then Ang:=90;
  If Not ParseNum(Ctl[Ei].S,T) Then T:=1;
  Iter:=Clamp(Round(T),1,50);
  If Not ParseLen(Ctl[Erx].S,RotX) Then Ctl[Cn].V:=0;
  If Not ParseLen(Ctl[Ery].S,RotY) Then Ctl[Cn].V:=0;
  PushUndo;
  N0:=NObj;
  For K:=1 To NS Do Last[K]:=Sel[K];
  For It:=1 To Iter Do Begin
   For K:=1 To NS Do Begin
    If NObj>=MAXOBJ Then Break;
    P:=CloneRec(Last[K]^);
    Inc(NObj);Objs[NObj]:=P;
    P^.Group:=0;
    Cur[K]:=P;
   End;
   If NObj>=MAXOBJ Then Break;
   { operations sur les copies : centre du groupe de copies }
   X1:=1E30;Y1:=1E30;X2:=-1E30;Y2:=-1E30;
   For K:=1 To NS Do Begin
    ObjBBox(Cur[K],BX1,BY1,BX2,BY2);
    If BX1<X1 Then X1:=BX1;
    If BY1<Y1 Then Y1:=BY1;
    If BX2>X2 Then X2:=BX2;
    If BY2>Y2 Then Y2:=BY2;
   End;
   CX:=(X1+X2)/2;CY:=(Y1+Y2)/2;
   If Ctl[Cm].V<>0 Then Begin CX:=CX+DX;CY:=CY+DY;End;
   If Ctl[Cn].V<>0 Then Begin PvX:=RotX;PvY:=RotY;End
   Else Begin PvX:=CX;PvY:=CY;End;
   CsA:=Cos(Ang*Pi/180);SnA:=Sin(Ang*Pi/180);
   For K:=1 To NS Do Begin
    If Ctl[Cm].V<>0 Then XformObj(Cur[K],1,0,0,1,DX,DY);
    If Ctl[Cs].V<>0 Then XformObj(Cur[K],FX,0,0,FY,CX*(1-FX),CY*(1-FY));
    If Ctl[Cr].V<>0 Then
     XformObj(Cur[K],CsA,SnA,-SnA,CsA,PvX-PvX*CsA+PvY*SnA,PvY-PvX*SnA-PvY*CsA);
    If Ctl[Cc].V<>0 Then Begin
     Cur[K]^.FillCol:=LerpCol(Col1,Col2,It/Iter);
     Cur[K]^.LineCol:=LerpCol(Col1,Col2,It/Iter);
     If Cur[K]^.FillMode=0 Then Cur[K]^.FillMode:=1;
    End;
    If Ctl[Cp].V<>0 Then Begin
     Cur[K]^.FillMode:=2;
     Cur[K]^.Grey:=Clamp(Round(P1+(P2-P1)*It/Iter),0,255);
    End;
    Last[K]:=Cur[K];
   End;
  End;
  If Ctl[Cb].V<>0 Then Begin
   N:=0;
   For J:=N0+1 To NObj Do Begin Inc(N);Tmp[N]:=Objs[J];End;
   For J:=1 To N0 Do Begin Inc(N);Tmp[N]:=Objs[J];End;
   For J:=1 To NObj Do Objs[J]:=Tmp[J];
  End;
  MarkModified;
  If R=ID_APPLY Then DrawAll;
 Until R<>ID_APPLY;
End;

{ ====================================================================== }
{                          MODULES INTERNES                              }
{ ====================================================================== }

Procedure NewPathObj(K: Byte; Closed: Boolean);
Begin
 PO_Init(K);
 PrevO.Closed:=Closed;
End;

Procedure ModTextCircle;
Var R,Et,Er,Ea,I: Integer; S: String; Rad,Ang0,Cell,Step,A,PX,PY,Ux,Uy,Vx,Vy,CX,CY: Double;
 T: TObj; P: PObj; Gid: Integer;
Begin
 DlgInit(L2('Text around a circle','Texte autour d''un cercle'),400,140);
 AddLabel(14,36,L2('Text:','Texte :'));Et:=AddEdit(100,32,280,'ARTWORX');
 AddLabel(14,58,L2('Radius:','Rayon :'));Er:=AddEdit(100,54,100,'50mm');
 AddLabel(14,80,L2('Start angle:','Angle depart :'));Ea:=AddEdit(130,76,70,'-90');
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 S:=Ctl[Et].S;
 If Not ParseLen(Ctl[Er].S,Rad) Then Rad:=50;
 If Not ParseNum(Ctl[Ea].S,Ang0) Then Ang0:=-90;
 If (S='') Or (Rad<5) Then Exit;
 PushUndo;
 Cell:=CurFSize*25.4/72;
 Step:=Cell/Rad;
 CX:=PageW/2;CY:=PageH/2;
 Inc(NextGroup);Gid:=NextGroup;
 A:=Ang0*Pi/180;
 For I:=1 To Length(S) Do Begin
  PX:=CX+Rad*Sin(A+Pi/2);PY:=CY-Rad*Cos(A+Pi/2);
  { angle depuis le haut : theta = A + 90deg - 90... on prend theta = A+90deg }
  Ux:=Cos(A+Pi/2);Uy:=Sin(A+Pi/2);
  Vx:=-Sin(A+Pi/2);Vy:=Cos(A+Pi/2);
  InitObj(T,OK_TEXT);
  T.Nd:=TmpNd;T.Cap:=MAXNODE;T.N:=3;
  NodeSet(T.Nd^[0],PX-Ux*Cell/2,PY-Uy*Cell/2);
  NodeSet(T.Nd^[1],T.Nd^[0].X+Ux*Cell,T.Nd^[0].Y+Uy*Cell);
  NodeSet(T.Nd^[2],T.Nd^[0].X+Vx*Cell,T.Nd^[0].Y+Vy*Cell);
  T.Group:=Gid;
  P:=AddObjRec(T);
  If P<>Nil Then Begin SetTxt(P,S[I]);End;
  A:=A+Step;
 End;
 MarkModified;
End;

Procedure ModLabels;
Var R,Ec,Er2,Ew,Eh,Eg,I,J: Integer; C,Rw: Double; W,H,G: Double; T: TObj; P: PObj;
Begin
 DlgInit(L2('Labels and business cards','Etiquettes et cartes de visite'),400,170);
 AddLabel(14,36,L2('Columns:','Colonnes :'));Ec:=AddEdit(120,32,60,'2');
 AddLabel(200,36,L2('Rows:','Lignes :'));Er2:=AddEdit(270,32,60,'5');
 AddLabel(14,58,L2('Width:','Largeur :'));Ew:=AddEdit(120,54,80,'85mm');
 AddLabel(14,80,L2('Height:','Hauteur :'));Eh:=AddEdit(120,76,80,'50mm');
 AddLabel(14,102,L2('Gap:','Espace :'));Eg:=AddEdit(120,98,80,'0mm');
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 If Not ParseNum(Ctl[Ec].S,C) Then C:=2;
 If Not ParseNum(Ctl[Er2].S,Rw) Then Rw:=5;
 If Not ParseLen(Ctl[Ew].S,W) Then W:=85;
 If Not ParseLen(Ctl[Eh].S,H) Then H:=50;
 If Not ParseLen(Ctl[Eg].S,G) Then G:=0;
 PushUndo;
 Inc(NextGroup);
 For I:=0 To Clamp(Round(C),1,10)-1 Do
  For J:=0 To Clamp(Round(Rw),1,12)-1 Do Begin
   InitObj(T,OK_RECT);
   T.Nd:=TmpNd;T.Cap:=MAXNODE;T.N:=0;
   T.FillMode:=0;T.Group:=NextGroup;
   PrevO.N:=0;
   NodeSet(T.Nd^[0],10+I*(W+G),10+J*(H+G));
   NodeSet(T.Nd^[1],10+I*(W+G)+W,10+J*(H+G));
   NodeSet(T.Nd^[2],10+I*(W+G)+W,10+J*(H+G)+H);
   NodeSet(T.Nd^[3],10+I*(W+G),10+J*(H+G)+H);
   T.N:=4;
   P:=AddObjRec(T);
  End;
 MarkModified;
End;

Function Gcd(A,B: Integer): Integer;
Var T: Integer;
Begin
 While B<>0 Do Begin T:=B;B:=A Mod B;A:=T;End;
 Gcd:=A;
End;

Procedure ModRosette;
Var R,Ep,Eq,Er3,I,P1,Q1,Np: Integer; V,Rr,T,Rad,Rin,D,X,Y,Mx: Double; Tb: TObj; Pn: PObj;
Begin
 DlgInit(L2('Rosette (spirograph)','Rosace (spirographe)'),380,140);
 AddLabel(14,36,L2('Outer teeth:','Dents externes :'));Ep:=AddEdit(170,32,60,'7');
 AddLabel(14,58,L2('Inner teeth:','Dents internes :'));Eq:=AddEdit(170,54,60,'3');
 AddLabel(14,80,L2('Size:','Taille :'));Er3:=AddEdit(170,76,90,'60mm');
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 If Not ParseNum(Ctl[Ep].S,V) Then V:=7;
 P1:=Clamp(Round(V),3,30);
 If Not ParseNum(Ctl[Eq].S,V) Then V:=3;
 Q1:=Clamp(Round(V),1,P1-1);
 If Not ParseLen(Ctl[Er3].S,Rad) Then Rad:=60;
 Np:=Q1 Div Gcd(P1,Q1);
 PushUndo;
 InitObj(Tb,OK_POLY);
 Tb.Nd:=TmpNd;Tb.Cap:=MAXNODE;Tb.N:=0;Tb.Closed:=True;Tb.FillMode:=0;
 Rin:=Rad*Q1/P1;
 D:=Rin*0.9;
 Mx:=0;
 For I:=0 To 279 Do Begin
  T:=2*Pi*Np*I/280;
  X:=(Rad-Rin)*Cos(T)+D*Cos((Rad-Rin)/Rin*T);
  Y:=(Rad-Rin)*Sin(T)-D*Sin((Rad-Rin)/Rin*T);
  If Hypot(X,Y)>Mx Then Mx:=Hypot(X,Y);
  NodeSet(Tb.Nd^[Tb.N],X,Y);Inc(Tb.N);
 End;
 For I:=0 To Tb.N-1 Do Begin
  Tb.Nd^[I].X:=PageW/2+Tb.Nd^[I].X*Rad/Mx;
  Tb.Nd^[I].Y:=PageH/2+Tb.Nd^[I].Y*Rad/Mx;
  Tb.Nd^[I].AX:=Tb.Nd^[I].X;Tb.Nd^[I].AY:=Tb.Nd^[I].Y;
  Tb.Nd^[I].BX:=Tb.Nd^[I].X;Tb.Nd^[I].BY:=Tb.Nd^[I].Y;
 End;
 Pn:=AddObjRec(Tb);
 If Pn<>Nil Then Begin DeselectAll;Pn^.Sel:=True;End;
 MarkModified;
End;

Procedure CmdModules;
Var R,Lst: Integer;
Begin
 Repeat
  LstN:=3;
  LstItem[1]:=L2('Text on a circle','Texte sur un cercle');
  LstItem[2]:=L2('Labels / cards','Etiquettes / cartes');
  LstItem[3]:=L2('Rosette','Rosace (spirographe)');
  DlgInit(L2('External modules','Modules externes'),400,200);
  Lst:=AddCtl(DC_LIST,14,32,250,70,'');Ctl[Lst].V:=1;
  AddBtn(280,32,100,4,L2('Execute','Executer'));
  AddCtl(DC_FRAME,14,118,372,40,'Module-info');
  AddLabel(24,134,L2('Built-in modules (ArtWorx clone)','Modules internes (clone ArtWorx)'));
  AddBtn(DlgW-82,DlgH-26,70,ID_OK,'OK');
  Ctl[NCtl].Mx:=1;
  R:=RunDialog;
  If R=4 Then Begin
   Case Ctl[Lst].V Of
    1: ModTextCircle;
    2: ModLabels;
    3: ModRosette;
   End;
   R:=ID_OK;
  End;
 Until R<>4;
End;

{ ====================================================================== }
{                  EDITEUR DE TEXTE (texte / texte cadre)                }
{ ====================================================================== }

Function TextEditor(Const Title: String; Var S: String): Boolean;
Var Ln: Array[1..24] Of String[100]; N,CY,CX,I,P,L: Integer; E: TEvent; Done,Ok,Redraw: Boolean;
 F2: Text;
 X1,Y1,X2,Y2: Integer; Tot: Integer; Nm: String;
 Function Total: Integer;
 Var K,T: Integer;
 Begin
  T:=0;
  For K:=1 To N Do T:=T+Length(Ln[K])+1;
  Total:=T-1;
 End;
Begin
 TextEditor:=False;
 N:=1;Ln[1]:='';
 For I:=1 To Length(S) Do Begin
  If S[I]=#10 Then Begin If N<24 Then Begin Inc(N);Ln[N]:='';End;End
  Else If Length(Ln[N])<100 Then Ln[N]:=Ln[N]+S[I];
 End;
 CY:=N;CX:=Length(Ln[N]);
 X1:=30;Y1:=60;X2:=SCR_W-30;Y2:=SCR_H-60;
 Done:=False;Ok:=False;Redraw:=True;
 Repeat
  If Redraw Then Begin
   HideMouse;
   Box(X1+4,Y1+4,X2+4,Y2+4,INK);
   Box(X1,Y1,X2,Y2,CHROME);Frame(X1,Y1,X2,Y2);Frame(X1+1,Y1+1,X2-1,Y2-1);
   DrawWinTitle(X1+2,Y1+2,X2-2,Title,True);Line(X1+2,Y1+18,X2-2,Y1+18);
   Box(X1+8,Y1+26,X2-8,Y2-30,PAPER);Frame(X1+8,Y1+26,X2-8,Y2-30);
   For I:=1 To N Do Begin
    If Y1+30+(I-1)*10+8>Y2-32 Then Break;
    PText(X1+12,Y1+30+(I-1)*10,Ln[I]);
   End;
   PText(X1+12+CX*8,Y1+31+(CY-1)*10,'_');
   PText(X1+10,Y2-22,L2('F10/Ctrl-S: OK   Esc: cancel   F3: load file   Ctrl-J: new line',
     'F10/Ctrl-S : OK   Echap : annuler   F3 : charger   Ctrl-J : nouvelle ligne'));
   PText(X2-90,Y2-12,IntStr(Total)+'/255');
   ShowMouse;
   Redraw:=False;
  End;
  PollEvent(E);
  If E.Kind=1 Then Begin
   Redraw:=True;
   Case E.Key Of
    K_ESC: Done:=True;
    324,19: Begin Ok:=True;Done:=True;End;
    K_ENTER,10: If (N<24) And (Total<254) Then Begin
      Inc(N);
      For I:=N DownTo CY+2 Do Ln[I]:=Ln[I-1];
      Ln[CY+1]:=Copy(Ln[CY],CX+1,100);
      Ln[CY]:=Copy(Ln[CY],1,CX);
      Inc(CY);CX:=0;
     End;
    K_UP: If CY>1 Then Begin Dec(CY);If CX>Length(Ln[CY]) Then CX:=Length(Ln[CY]);End;
    K_DOWN: If CY<N Then Begin Inc(CY);If CX>Length(Ln[CY]) Then CX:=Length(Ln[CY]);End;
    K_LEFT: If CX>0 Then Dec(CX) Else If CY>1 Then Begin Dec(CY);CX:=Length(Ln[CY]);End;
    K_RIGHT: If CX<Length(Ln[CY]) Then Inc(CX) Else If CY<N Then Begin Inc(CY);CX:=0;End;
    K_HOME: CX:=0;
    K_END: CX:=Length(Ln[CY]);
    K_BKSP: If CX>0 Then Begin Delete(Ln[CY],CX,1);Dec(CX);End
     Else If CY>1 Then Begin
      CX:=Length(Ln[CY-1]);
      Ln[CY-1]:=Ln[CY-1]+Ln[CY];
      For I:=CY To N-1 Do Ln[I]:=Ln[I+1];
      Dec(N);Dec(CY);
     End;
    K_DEL: If CX<Length(Ln[CY]) Then Delete(Ln[CY],CX+1,1)
     Else If CY<N Then Begin
      Ln[CY]:=Ln[CY]+Ln[CY+1];
      For I:=CY+1 To N-1 Do Ln[I]:=Ln[I+1];
      Dec(N);
     End;
    317: Begin
      Nm:='';
      If FileSelect(L2('Load text','Charger du texte'),'*.TXT',Nm) Then Begin
       {$I-}
       Assign(F2,Nm);Reset(F2);
       {$I+}
       If IOResult=0 Then Begin
        While Not Eof(F2) Do Begin
         ReadLn(F2,Nm);
         If (N<24) And (Total+Length(Nm)<254) Then Begin
          If (N=1) And (Ln[1]='') Then Ln[1]:=Copy(Nm,1,100)
          Else Begin Inc(N);Ln[N]:=Copy(Nm,1,100);End;
         End;
        End;
        Close(F2);CY:=N;CX:=Length(Ln[N]);
       End;
      End;
     End;
    32..255: If (Length(Ln[CY])<100) And (Total<254) Then Begin
      Insert(Chr(E.Key),Ln[CY],CX+1);Inc(CX);
     End;
   End;
  End Else If E.Kind=2 Then Begin
   If Not InBox(E.X,E.Y,X1,Y1,X2,Y2) Then Begin Done:=True;End;
  End;
 Until Done;
 If Ok Then Begin
  S:='';
  For I:=1 To N Do Begin
   If I>1 Then S:=S+#10;
   S:=S+Ln[I];
  End;
  If Length(S)>255 Then S:=Copy(S,1,255);
  TextEditor:=True;
 End;
 NeedDraw:=True;
End;

{ ====================================================================== }
{                  IMPORT / EXPORT / FICHIERS : COMMANDES                }
{ ====================================================================== }

Procedure ResetDoc;
Var I: Integer;
Begin
 ClearDoc;
 NPages:=1;CurPage:=1;PageW:=210;PageH:=297;
 DocName:='';Named:=False;Modified:=False;
 For I:=1 To NLAYER Do Begin
  Layers[I].Name:=L2('Layer ','Calque ')+IntStr(I);
  Layers[I].Hidden:=False;Layers[I].Locked:=False;Layers[I].OnScreen:=False;
 End;
 CurLayer:=1;NextGroup:=0;UndoN:=0;UndoSeq:=0;
 DeselectAll;
 DS:=0;NDP:=0;
 ZoomFullPage;
End;

Function NewBitmapObj(Const Nm: String; X,Y,W: Double): PObj;
Var T: TObj; P: PObj; H: Double;
Begin
 NewBitmapObj:=Nil;
 InitObj(T,OK_BITMAP);
 T.Nd:=TmpNd;T.Cap:=MAXNODE;T.N:=0;
 NodeSet(T.Nd^[0],X,Y);NodeSet(T.Nd^[1],X+W,Y);NodeSet(T.Nd^[2],X+W,Y+W);
 NodeSet(T.Nd^[3],X,Y+W);T.N:=4;
 P:=AddObjRec(T);
 If P=Nil Then Exit;
 If Not LoadBMP(Nm,P) Then Begin
  DelObjAt(IndexOfObj(P));
  MsgBox('ArtWorx',L2('Unknown format','Format inconnu'));
  Exit;
 End;
 H:=W*P^.BH/P^.BW;
 P^.Nd^[2].Y:=Y+H;P^.Nd^[3].Y:=Y+H;
 P^.Nd^[2].AY:=Y+H;P^.Nd^[3].AY:=Y+H;P^.Nd^[2].BY:=Y+H;P^.Nd^[3].BY:=Y+H;
 NewBitmapObj:=P;
End;

Procedure ImportTextFile(Const Nm: String; X0,Y0,W: Double);
Var F: Text; Ln,Chunk: String; Cnt: Integer; Y,Cell,H: Double; T: TObj; P: PObj; I: Integer;
 Procedure Flush;
 Begin
  If Chunk='' Then Exit;
  Cell:=CurFSize*25.4/72;
  H:=Cnt*Cell*1.25+Cell;
  InitObj(T,OK_FTEXT);
  T.Nd:=TmpNd;T.Cap:=MAXNODE;T.N:=0;
  NodeSet(T.Nd^[0],X0,Y);NodeSet(T.Nd^[1],X0+W,Y);NodeSet(T.Nd^[2],X0+W,Y+H);
  NodeSet(T.Nd^[3],X0,Y+H);T.N:=4;
  P:=AddObjRec(T);
  If P<>Nil Then SetTxt(P,Chunk);
  Y:=Y+H;Chunk:='';Cnt:=0;
 End;
Begin
 {$I-}
 Assign(F,Nm);Reset(F);
 {$I+}
 If IOResult<>0 Then Begin
  MsgBox('ArtWorx',L2('File not found','Fichier introuvable'));Exit;
 End;
 Chunk:='';Cnt:=0;Y:=Y0;
 While Not Eof(F) Do Begin
  ReadLn(F,Ln);
  For I:=1 To Length(Ln) Do If Ln[I]=#9 Then Ln[I]:=' ';
  If Length(Ln)>200 Then Ln:=Copy(Ln,1,200);
  If Length(Chunk)+Length(Ln)+1>250 Then Flush;
  If Chunk='' Then Chunk:=Ln Else Chunk:=Chunk+#10+Ln;
  Inc(Cnt);
 End;
 Flush;
 Close(F);
End;

Function IsTextFile(Const Nm: String): Boolean;
Var F: Text; Ln: String;
Begin
 IsTextFile:=False;
 {$I-}
 Assign(F,Nm);Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 Close(F);
 IsTextFile:=True;
End;

Function SaveAsTo(Const Nm: String): Boolean;
Var E: String; Ok: Boolean;
Begin
 SaveAsTo:=False;
 E:=ExtOf(Nm);
 If (E='') Or (E='CWG') Then Begin
  Ok:=SaveCWG(Nm,False);
  If Ok Then Begin DocName:=Nm;Named:=True;Modified:=False;End;
 End Else If E='EPS' Then Ok:=ExportPS(Nm,False,True)
 Else If E='PS' Then Ok:=ExportPS(Nm,True,False)
 Else If E='SVG' Then Ok:=ExportSVG(Nm)
 Else If (E='TXT') Or (E='ASC') Then Ok:=ExportASCII(Nm)
 Else If E='GEM' Then Begin
  MsgBox('ArtWorx',L2('GEM metafile format is not available','Le format metafichier GEM n''est pas disponible'));
  Exit;
 End Else Begin
  Ok:=SaveCWG(Nm,False);
  If Ok Then Begin DocName:=Nm;Named:=True;Modified:=False;End;
 End;
 If Not Ok Then MsgBox('ArtWorx',L2('Cannot write file','Impossible d''ecrire le fichier'));
 SaveAsTo:=Ok;
End;

Function CmdSaveAs: Boolean;
Var Nm: String;
Begin
 CmdSaveAs:=False;
 If Named Then Nm:=ShortName(DocName) Else Nm:='NONAME.CWG';
 If FileSelect(L2('Save as','Enregistrer sous'),'*.CWG',Nm) Then Begin
  If ExtOf(Nm)='' Then Nm:=Nm+'.CWG';
  CmdSaveAs:=SaveAsTo(Nm);
 End;
End;

Function CmdSave: Boolean;
Begin
 If Named Then CmdSave:=SaveAsTo(DocName) Else CmdSave:=CmdSaveAs;
End;

Function CheckSave: Boolean;
Var R: Integer;
Begin
 CheckSave:=True;
 If Not Modified Then Exit;
 R:=AskSave(L2('Close file ? [Abandon] [Save] [Cancel]','Fermer le fichier ? [Abandon] [Enreg.] [Annuler]'));
 Case R Of
  1: CheckSave:=CmdSave;
  2: CheckSave:=True;
  Else CheckSave:=False;
 End;
End;

Procedure CmdNew;
Begin
 If CheckSave Then ResetDoc;
End;

Function OpenFile(Const Nm: String): Boolean;
Var E: String; P: PObj;
Begin
 OpenFile:=False;
 E:=ExtOf(Nm);
 If E='BMP' Then Begin
  ResetDoc;
  P:=NewBitmapObj(Nm,10,10,PageW-20);
  If P<>Nil Then OpenFile:=True;
 End Else If LoadCWG(Nm,False) Then Begin
  DocName:=Nm;Named:=True;Modified:=False;UndoN:=0;
  If CurPage>NPages Then CurPage:=1;
  ZoomFullPage;
  OpenFile:=True;
 End Else If (E='TXT') Or (E='ASC') Then Begin
  ResetDoc;
  ImportTextFile(Nm,15,15,PageW-30);
  OpenFile:=True;
 End Else MsgBox('ArtWorx',L2('Unknown format','Format inconnu'));
End;

Procedure CmdOpen;
Var Nm: String;
Begin
 If Not CheckSave Then Exit;
 Nm:='';
 If FileSelect(L2('Open','Ouvrir'),'*.CWG',Nm) Then OpenFile(Nm);
End;

Procedure CmdInsert;
Var Nm,E: String; P: PObj; N0,I: Integer;
Begin
 Nm:='';
 If Not FileSelect(L2('Insert','Inserer'),'*.*',Nm) Then Exit;
 E:=ExtOf(Nm);
 PushUndo;
 If E='BMP' Then Begin
  P:=NewBitmapObj(Nm,15,15,PageW/2);
  If P<>Nil Then Begin DeselectAll;P^.Sel:=True;End;
 End Else If (E='TXT') Or (E='ASC') Then Begin
  ImportTextFile(Nm,15,15,PageW-30);
 End Else Begin
  N0:=NObj;
  If LoadCWG(Nm,True) Then Begin
   DeselectAll;
   For I:=N0+1 To NObj Do Begin Objs[I]^.Sel:=True;Objs[I]^.Page:=CurPage;End;
  End Else MsgBox('ArtWorx',L2('Unknown format','Format inconnu'));
 End;
 MarkModified;
End;

Procedure CmdAbandon;
Begin
 If Not ConfirmBox(L2('Abandon changes ?','Abandonner les modifications ?')) Then Exit;
 If Named And FileExists(DocName) Then Begin
  If LoadCWG(DocName,False) Then Begin Modified:=False;UndoN:=0;End;
 End Else ResetDoc;
 DeselectAll;
End;

Procedure CmdExport;
Var R,Fm,Fn: Integer; Nm,Ex: String;
Begin
 DlgInit(L2('Export','Exporter'),420,130);
 AddLabel(14,36,L2('Format:','Format :'));
 Fm:=AddPop(90,32,280,'Encapsulated PostScript (EPS)|SVG|ASCII text|PostScript (PS)|ArtWorx (CWG)',0);
 If Named Then Nm:=ShortName(DocName) Else Nm:='NONAME';
 AddLabel(14,64,L2('File:','Fichier :'));
 Fn:=AddEdit(90,60,280,SetExt(Nm,'EPS'));
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 Nm:=Ctl[Fn].S;
 Case Ctl[Fm].V Of
  0: Ex:='EPS';
  1: Ex:='SVG';
  2: Ex:='TXT';
  3: Ex:='PS';
  Else Ex:='CWG';
 End;
 If ExtOf(Nm)='' Then Nm:=Nm+'.'+Ex;
 Case Ctl[Fm].V Of
  0: R:=Ord(ExportPS(Nm,False,True));
  1: R:=Ord(ExportSVG(Nm));
  2: R:=Ord(ExportASCII(Nm));
  3: R:=Ord(ExportPS(Nm,True,False));
  Else R:=Ord(SaveCWG(Nm,False));
 End;
 If R=0 Then MsgBox('ArtWorx',L2('Cannot write file','Impossible d''ecrire le fichier'))
 Else MsgBox(L2('Export','Exporter'),L2('File written: ','Fichier ecrit : ')+Nm);
End;

Procedure CmdObjExport;
Var Nm: String;
Begin
 If CountSel=0 Then Exit;
 Nm:='OBJECT.CWG';
 If FileSelect(L2('Export object','Exporter l''objet'),'*.CWG',Nm) Then Begin
  If ExtOf(Nm)='' Then Nm:=Nm+'.CWG';
  If Not SaveCWG(Nm,True) Then MsgBox('ArtWorx',L2('Cannot write file','Impossible d''ecrire le fichier'));
 End;
End;

Procedure CmdPrint;
Var Cp,Zm,Rt,Ff,Fp,Tp: Integer; V1,V2: Double; R: Integer; Ok: Boolean;
Begin
 DlgInit(L2('Print','Imprimer'),420,200);
 AddLabel(14,36,L2('Copies:','Copies :'));Cp:=AddEdit(100,32,50,'1');
 AddLabel(14,58,'Zoom:');Zm:=AddEdit(100,54,50,'100');AddLabel(154,58,'%');
 Rt:=AddCheck(14,82,L2('Rotated','Pivote'),False);
 Ff:=AddCheck(14,98,L2('Form feed','Saut de page'),True);
 AddLabel(14,126,L2('from page','de la page'));Fp:=AddEdit(120,122,50,'1');
 AddLabel(14,146,L2('to page','a la page'));Tp:=AddEdit(120,142,50,IntStr(NPages));
 AddCtl(DC_FRAME,200,34,208,80,L2('Driver','Pilote'));
 AddLabel(210,48,'PostScript -> ARTWORX.PS');
 AddLabel(210,64,L2('Output goes to a file','La sortie va dans un fichier'));
 AddBtn(200,122,100,4,L2('Print','Imprimer'));
 AddStdBtns(False);
 R:=RunDialog;
 If R=4 Then Begin
  If Not ParseNum(Ctl[Fp].S,V1) Then V1:=1;
  If Not ParseNum(Ctl[Tp].S,V2) Then V2:=NPages;
  Ok:=ExportPS('ARTWORX.PS',(V1<=1) And (V2>=NPages) And (NPages>1),False);
  If Ok Then MsgBox(L2('Print','Imprimer'),L2('Output written to ARTWORX.PS','Sortie ecrite dans ARTWORX.PS'))
  Else MsgBox('ArtWorx',L2('Cannot write file','Impossible d''ecrire le fichier'));
 End;
End;

Procedure CmdInfo;
Var F: File; Sz: LongInt; Nm: String;
Begin
 Sz:=0;
 If Named Then Begin
  {$I-}
  Assign(F,DocName);Reset(F,1);
  {$I+}
  If IOResult=0 Then Begin Sz:=FileSize(F);Close(F);End;
 End;
 If Named Then Nm:=DocName Else Nm:='Noname';
 MsgBox(L2('Document information','Information sur le document'),
   L2('Name: ','Nom : ')+Nm+'|'+L2('Size on disk: ','Taille sur disque : ')+IntStr(Sz)+' '+L2('bytes','octets')+'|'+
   L2('Objects: ','Objets : ')+IntStr(NObj)+'|'+L2('Pages: ','Pages : ')+IntStr(NPages)+'|'+
   L2('Page size: ','Format : ')+FmtLen(PageW)+' x '+FmtLen(PageH));
End;

Procedure CmdAbout;
Begin
 MsgBox(L2('about ArtWorx','A propos d''ArtWorx'),
  'ArtWorx - '+L2('Object-oriented vector drawing','Dessin vectoriel oriente objet')+'|'+
  L2('Clone for Turbo Pascal / Free Pascal','Clone pour Turbo Pascal / Free Pascal')+'|'+
  'Version '+'1.00 - (c) Sylvain Maltais 2026|'+
  'https://www.gladir.com/clonedraw|'+
  L2('Free memory: ','Memoire libre : ')+IntStr(FreeMemKB)+' Ko');
End;

Procedure CmdImportInto;
Var P: PObj; Nm,S,Ln: String; F: Text; E: String;
Begin
 P:=FirstSel;
 If P=Nil Then Exit;
 Nm:='';
 Case P^.Kind Of
  OK_BITMAP: Begin
    If FileSelect(L2('Import picture','Importer une image'),'*.BMP',Nm) Then Begin
     PushUndo;
     If LoadBMP(Nm,P) Then MarkModified
     Else MsgBox('ArtWorx',L2('Unknown format','Format inconnu'));
    End;
   End;
  OK_FTEXT,OK_TEXT: Begin
    If FileSelect(L2('Import text','Importer du texte'),'*.TXT',Nm) Then Begin
     {$I-}
     Assign(F,Nm);Reset(F);
     {$I+}
     If IOResult<>0 Then Exit;
     PushUndo;
     S:='';
     While (Not Eof(F)) And (Length(S)<240) Do Begin
      ReadLn(F,Ln);
      If S<>'' Then S:=S+#10;
      S:=S+Copy(Ln,1,200);
     End;
     Close(F);
     If Length(S)>255 Then S:=Copy(S,1,255);
     SetTxt(P,S);
     MarkModified;
    End;
   End;
  Else MsgBox('ArtWorx',L2('Select a bitmap or text frame first','Selectionnez d''abord une image ou un texte cadre'));
 End;
End;

{ ====================================================================== }
{                          MENUS : DISTRIBUTION                          }
{ ====================================================================== }

Procedure DoMenu(M,I: Integer);
Begin
 Case M Of
  1: Case I Of
      1: CmdAbout;
      3: MsgBox(L2('Free memory','Memoire libre'),IntStr(FreeMemKB)+' Ko');
     End;
  2: Case I Of
      1: CmdNew;
      2: CmdOpen;
      3: CmdNew;
      4: CmdInsert;
      5: MsgBox('ArtWorx',L2('No embedded objects to update','Aucun objet incorpore a mettre a jour'));
      7: CmdSave;
      8: CmdSaveAs;
      9: CmdAbandon;
      11: CmdExport;
      12: CmdInfo;
      13: CmdPrint;
      15: If CheckSave Then Quit:=True;
     End;
  3: Case I Of
      1: DoUndo;
      3: CmdCopy;
      4: CmdCut;
      5: CmdPaste;
      6: CmdSelectAll;
      7: CmdDelete;
      9: ZoomFullPage;
      10: ZoomAround(100,OrgX+CvW/Sc/2,OrgY+CvH/Sc/2);
      11: CmdZoomDlg;
      13: CmdInsertPage;
      14: CmdDeletePage;
      16: Begin If NPages>1 Then If CurPage<NPages Then SetPage(CurPage+1) Else SetPage(1);End;
      17: PropResize:=Not PropResize;
      18: CmdLayers;
     End;
  4: Case I Of
      1: CmdImportInto;
      2: CmdObjExport;
      4: CmdZOrder(True);
      5: CmdZOrder(False);
      6: CmdGroup;
      7: CmdUngroup;
      8: CmdLock(True);
      9: CmdLock(False);
      11: CmdObjInfo;
      12: CmdArrange;
      13: CmdSnapToGrid;
      14: CmdCommute;
      15: CmdTransform;
      16: CmdTiling;
      17: CmdBoolean;
     End;
  5: Case I Of
      1,2,3: MsgBox(L2('Style','Style'),L2('This function is not available in this version',
        'Cette fonction n''est pas disponible dans cette version'));
      5: CmdLines;
      6: CmdFill;
      7: CmdColour;
      8: CmdText;
      9: CmdShadows;
      10: CmdStatus;
     End;
  6: CmdModules;
  7: Case I Of
      1: CmdGeneral;
      2: CmdPaths;
      3: CmdGrid;
      4: CmdFormat;
      5: CmdEditor;
      6: CmdImages;
      8: Begin SaveOptions;MsgBox('ArtWorx',L2('Settings saved','Options enregistrees'));End;
     End;
 End;
 NeedDraw:=True;
End;

Function NextItem(M,From,Dir: Integer): Integer;
Var I,N,K: Integer;
Begin
 N:=MCount(M);
 I:=From;
 { au plus N essais : un menu dont tous les elements sont inactifs (Objet
   sans selection) ne doit pas faire boucler indefiniment }
 For K:=1 To N Do Begin
  I:=I+Dir;
  If I<1 Then I:=N;
  If I>N Then I:=1;
  If (Not MSep(M,I)) And MEnabled(M,I) Then Begin NextItem:=I;Exit;End;
 End;
 NextItem:=From;
End;

Procedure RunMenu(StartM: Integer; ByMouse: Boolean);
Var M,Hi,H,T: Integer; E: TEvent; Done,Pick,Redraw: Boolean;
Begin
 M:=StartM;Hi:=0;
 If Not ByMouse Then Hi:=NextItem(M,0,1);
 MenuOpen:=M;MenuHi:=Hi;
 DrawAll;
 Done:=False;Pick:=False;
 Repeat
  PollEvent(E);
  Redraw:=False;
  Case E.Kind Of
   4,2: Begin
         T:=TitleHit(E.X,E.Y);
         If (T>0) And (T<>M) Then Begin M:=T;Hi:=0;Redraw:=True;End
         Else Begin
          H:=DropHit(M,E.X,E.Y);
          If (H<>0) And (MSep(M,H) Or Not MEnabled(M,H)) Then H:=0;
          If H<>Hi Then Begin Hi:=H;Redraw:=True;End;
         End;
         If E.Kind=2 Then Begin
          If DropHit(M,E.X,E.Y)=0 Then Begin
           If TitleHit(E.X,E.Y)=0 Then Done:=True;
          End Else If Hi<>0 Then Begin Pick:=True;Done:=True;End;
         End;
        End;
   3: Begin
       H:=DropHit(M,E.X,E.Y);
       If (H<>0) And (Hi=H) Then Begin Pick:=True;Done:=True;End;
      End;
   1: Case E.Key Of
       K_ESC: Done:=True;
       K_LEFT: Begin Dec(M);If M<1 Then M:=NMENU;Hi:=NextItem(M,0,1);Redraw:=True;End;
       K_RIGHT: Begin Inc(M);If M>NMENU Then M:=1;Hi:=NextItem(M,0,1);Redraw:=True;End;
       K_UP: Begin Hi:=NextItem(M,Hi,-1);Redraw:=True;End;
       K_DOWN: Begin Hi:=NextItem(M,Hi,1);Redraw:=True;End;
       K_ENTER: If Hi<>0 Then Begin Pick:=True;Done:=True;End;
      End;
  End;
  If Redraw Then Begin MenuOpen:=M;MenuHi:=Hi;DrawAll;End;
 Until Done;
 MenuOpen:=0;MenuHi:=0;
 DrawAll;
 If Pick And (Hi>0) Then DoMenu(M,Hi);
End;

{ ====================================================================== }
{               INTERACTION : OUTILS, SELECTION, EDITION DE CHEMINS      }
{ ====================================================================== }

Var
 PrevOk: Boolean;
 DragMoved: Boolean;
 ClickObj: PObj;
 ClickWasSel: Boolean;
 RubKind: Integer;                { 0 aucun, 1 rectangle, 2 quadrilatere }
 RubX1,RubY1,RubX2,RubY2: Integer;
 RubQ: Array[0..3] Of TPt;
 DragB: Array[1..4] Of Double;    { boite de la selection au debut }
 LastPanelT: LongInt;
 LastPanelId: Integer;
 SbDragOff: Integer;
 DragStartOrgX,DragStartOrgY: Double;

Procedure XorBegin;
Begin
 HideMouse;
 SetViewPort(CVX1,CVY1,CVX2,CVY2,True);
 SetWriteMode(XORPut);
 SetColor(15);
 SetLineStyle(SolidLn,0,1);
End;

Procedure XorEnd;
Begin
 SetWriteMode(NormalPut);
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 ShowMouse;
End;

Procedure XorPreviewDraw;
Var S,N: Integer;
Begin
 XorBegin;
 FlattenObj(@PrevO,Sc);
 ObjToScreen(0,0);
 For S:=0 To NSub-1 Do Begin
  N:=SubS[S+1]-SubS[S];
  If N>=2 Then DrawPoly(N,SP^[SubS[S]]);
 End;
 XorEnd;
End;

Procedure XorPreview(Draw: Boolean);
Begin
 If Not Draw Then Begin
  If PrevDrawn Then Begin XorPreviewDraw;PrevDrawn:=False;End;
 End Else If PrevOk Then Begin
  XorPreviewDraw;PrevDrawn:=True;
 End;
End;

Procedure RubDraw;
Var I: Integer;
Begin
 If RubKind=0 Then Exit;
 XorBegin;
 If RubKind=1 Then
  Rectangle(RubX1-CVX1,RubY1-CVY1,RubX2-CVX1,RubY2-CVY1)
 Else Begin
  For I:=0 To 3 Do
   Line(ToInt((RubQ[I].X-OrgX)*Sc),ToInt((RubQ[I].Y-OrgY)*Sc),
     ToInt((RubQ[(I+1) Mod 4].X-OrgX)*Sc),ToInt((RubQ[(I+1) Mod 4].Y-OrgY)*Sc));
 End;
 XorEnd;
End;

Procedure RubSetRect(X1,Y1,X2,Y2: Integer);
Begin
 RubDraw;
 RubKind:=1;RubX1:=X1;RubY1:=Y1;RubX2:=X2;RubY2:=Y2;
 RubDraw;
End;

Procedure RubClear;
Begin
 RubDraw;
 RubKind:=0;
End;

Procedure UpdateMsg;
Begin
 If SelMode Then CurMsg:=L2('Selection mode','Mode selection')
 Else CurMsg:=ToolName(CurBox,CurTool[CurBox]);
End;

{ ---- annulation / fin des outils de dessin ---- }
Procedure AbortTool;
Begin
 XorPreview(False);
 DS:=0;NDP:=0;PrevOk:=False;CloseIt:=False;Dragging:=0;
 If TxtEditing Then Begin
  If (EditObj<>Nil) And (TxtOf(EditObj)='') Then DelObjAt(IndexOfObj(EditObj));
  TxtEditing:=False;EditObj:=Nil;
 End;
 NeedDraw:=True;
End;

Function NeedPts(T: Integer): Integer;
Begin
 Case T Of
  T_LINE,T_RECT,T_RRECT,T_CIRCLE,T_ELLIPSE,T_FTEXT,T_BITMAP,T_NGON: NeedPts:=2;
  T_TRI,T_PARA,T_RUBBER: NeedPts:=3;
  T_ARC,T_EARC: NeedPts:=4;
  Else NeedPts:=0;
 End;
End;

Procedure PostCreate(P: PObj);
Var S,Nm: String; Fw,Hh: Double;
Begin
 If P=Nil Then Exit;
 If P^.Kind=OK_FTEXT Then Begin
  S:='';
  If TextEditor(L2('Frame text','Texte cadre'),S) Then SetTxt(P,S);
 End Else If P^.Kind=OK_BITMAP Then Begin
  Nm:='';
  If FileSelect(L2('Import picture','Importer une image'),'*.BMP',Nm) Then Begin
   If LoadBMP(Nm,P) Then Begin
    Fw:=Abs(P^.Nd^[1].X-P^.Nd^[0].X);
    Hh:=Fw*P^.BH/P^.BW;
    P^.Nd^[2].Y:=P^.Nd^[0].Y+Hh;P^.Nd^[3].Y:=P^.Nd^[0].Y+Hh;
    P^.Nd^[2].AY:=P^.Nd^[2].Y;P^.Nd^[3].AY:=P^.Nd^[3].Y;
    P^.Nd^[2].BY:=P^.Nd^[2].Y;P^.Nd^[3].BY:=P^.Nd^[3].Y;
   End Else MsgBox('ArtWorx',L2('Unknown format','Format inconnu'));
  End;
 End;
End;

Procedure ToolFinish(WX,WY: Double);
Var P: PObj;
Begin
 XorPreview(False);
 If BuildPrev(True,WX,WY) Then Begin
  P:=CommitPrev;
  PostCreate(P);
 End;
 DS:=0;NDP:=0;PrevOk:=False;CloseIt:=False;
 NeedDraw:=True;
End;

Procedure ToolFinishOpen;
Var T: Integer;
Begin
 T:=CurTool[BX_DRAW];
 If ((T=T_MLINE) And (NDP>=2)) Or ((T=T_SPLINE) And (NDP>=2)) Or
    ((T=T_BEZIER) And (NDP>=4)) Then ToolFinish(0,0)
 Else AbortTool;
End;

Procedure StartText(WX,WY: Double);
Var Cell: Double;
Begin
 PushUndo;
 Cell:=CurFSize*25.4/72;
 PO_Init(OK_TEXT);
 PO_Add(WX,WY);PO_Add(WX+Cell,WY);PO_Add(WX,WY+Cell);
 EditObj:=AddObjRec(PrevO);
 If EditObj<>Nil Then Begin
  TxtEditing:=True;DS:=2;
  CurMsg:=L2('Type text, Return ends, Esc = special char','Tapez le texte, Entree termine, Echap = caractere special');
 End;
End;

Procedure TextKey(K: Word);
Var S: String; Nm: String; V: Double;
Begin
 If EditObj=Nil Then Begin TxtEditing:=False;Exit;End;
 S:=TxtOf(EditObj);
 Case K Of
  K_ENTER: Begin
    If S='' Then DelObjAt(IndexOfObj(EditObj));
    TxtEditing:=False;EditObj:=Nil;DS:=0;MarkModified;UpdateMsg;
   End;
  10: If Length(S)<250 Then SetTxt(EditObj,S+#10);
  K_BKSP: If S<>'' Then SetTxt(EditObj,Copy(S,1,Length(S)-1));
  K_ESC: Begin
    Nm:='';
    If InputBox(L2('Special character','Caractere special'),L2('ASCII code:','Code ASCII :'),Nm,4) Then
     If ParseNum(Nm,V) And (V>=1) And (V<=255) And (Length(S)<250) Then
      SetTxt(EditObj,S+Chr(Round(V)));
   End;
  32..255: If Length(S)<250 Then SetTxt(EditObj,S+Chr(K));
 End;
 NeedDraw:=True;
End;

Procedure ToolClick(WX,WY: Double);
Var T,Nd,R: Integer; D: Double;
Begin
 T:=CurTool[BX_DRAW];
 SnapPt(WX,WY);
 If T=T_TEXT Then Begin StartText(WX,WY);NeedDraw:=True;Exit;End;
 If T=T_FREE Then Exit;
 If (T=T_NGON) And (NDP=0) Then Begin
  R:=PopupChoice('3|4|5|6|7|8|9|10|12|16|20|24',ScrX(WX),ScrY(WY),3);
  If R<0 Then Exit;
  Case R Of
   0..7: DNSides:=R+3;
   8: DNSides:=12;
   9: DNSides:=16;
   10: DNSides:=20;
   Else DNSides:=24;
  End;
 End;
 Nd:=NeedPts(T);
 If (Nd>0) And (NDP+1=Nd) Then Begin ToolFinish(WX,WY);Exit;End;
 If T=T_MLINE Then Begin
  If (NDP>=3) And (Hypot((WX-DP[1].X)*Sc,(WY-DP[1].Y)*Sc)<7) Then Begin
   CloseIt:=True;ToolFinish(0,0);Exit;
  End;
 End;
 If (NDP>=1) And ((T=T_MLINE) Or (T=T_SPLINE)) Then
  If (Abs(DP[NDP].X-WX)<0.01) And (Abs(DP[NDP].Y-WY)<0.01) Then Begin
   ToolFinishOpen;Exit;
  End;
 XorPreview(False);
 If NDP<40 Then Begin
  Inc(NDP);DP[NDP].X:=WX;DP[NDP].Y:=WY;DS:=1;
 End;
 PrevOk:=BuildPrev(False,WX,WY);
 XorPreview(True);
End;

Procedure ToolMove(WX,WY: Double);
Begin
 If NDP<1 Then Exit;
 SnapPt(WX,WY);
 XorPreview(False);
 PrevOk:=BuildPrev(False,WX,WY);
 XorPreview(True);
 CurDX:=WX-DP[NDP].X;CurDY:=WY-DP[NDP].Y;ShowDelta:=True;
End;

{ ---- main levee ---- }
Procedure FreeBegin(WX,WY: Double);
Begin
 FreeN:=0;
 FreeP^[0].X:=WX;FreeP^[0].Y:=WY;FreeN:=1;
 Dragging:=8;
End;

Procedure FreeMove(WX,WY: Double);
Begin
 If FreeN>=MAXPT-1 Then Exit;
 If Hypot((WX-FreeP^[FreeN-1].X)*Sc,(WY-FreeP^[FreeN-1].Y)*Sc)<2.5 Then Exit;
 HideMouse;
 SetViewPort(CVX1,CVY1,CVX2,CVY2,True);
 SetColor(NearestCol(CurLineCol));
 Line(ToInt((FreeP^[FreeN-1].X-OrgX)*Sc),ToInt((FreeP^[FreeN-1].Y-OrgY)*Sc),
   ToInt((WX-OrgX)*Sc),ToInt((WY-OrgY)*Sc));
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 ShowMouse;
 FreeP^[FreeN].X:=WX;FreeP^[FreeN].Y:=WY;Inc(FreeN);
End;

Procedure FreeEnd;
Var I,Stride,Cnt: Integer; LastX,LastY: Double; P: PObj;
Begin
 Dragging:=0;
 If FreeN<2 Then Begin NeedDraw:=True;Exit;End;
 Stride:=1;
 Cnt:=0;
 While (FreeN Div Stride)>MAXNODE-8 Do Inc(Stride);
 PO_Init(OK_FREE);
 LastX:=-1E9;LastY:=-1E9;
 For I:=0 To FreeN-1 Do
  If (I Mod Stride=0) Or (I=FreeN-1) Then
   If Hypot((FreeP^[I].X-LastX)*Sc,(FreeP^[I].Y-LastY)*Sc)>=3 Then Begin
    PO_Add(FreeP^[I].X,FreeP^[I].Y);
    LastX:=FreeP^[I].X;LastY:=FreeP^[I].Y;
   End;
 If PrevO.N>=2 Then Begin
  SplineHandles(@PrevO);
  P:=CommitPrev;
 End;
 NeedDraw:=True;
End;

{ ---- edition de chemins ---- }
Function PathCand(O: PObj; Any: Boolean): Boolean;
Begin
 PathCand:=ObjVisible(O) And Not ObjLocked(O) And IsPathKind(O^.Kind) And
   ((Not Any) Or O^.Sel);
End;

Function FindNode(WX,WY: Double; Var O: PObj; Var NI,Part: Integer): Boolean;
Var I,K,J: Integer; Tol,D,Best: Double; Any: Boolean; C: PObj;
Begin
 Tol:=6/Sc;Best:=1E30;FindNode:=False;
 Any:=CountSel>0;
 For I:=NObj DownTo 1 Do Begin
  C:=Objs[I];
  If Not PathCand(C,Any) Then Continue;
  For K:=0 To C^.N-1 Do Begin
   D:=Hypot(WX-C^.Nd^[K].X,WY-C^.Nd^[K].Y);
   If (D<=Tol) And (D<Best) Then Begin Best:=D;O:=C;NI:=K;Part:=0;FindNode:=True;End;
   If (C^.Nd^[K].Kind=1) And ((K<C^.N-1) Or C^.Closed) Then Begin
    J:=(K+1) Mod C^.N;
    D:=Hypot(WX-C^.Nd^[K].AX,WY-C^.Nd^[K].AY);
    If (D<=Tol) And (D<Best) Then Begin Best:=D;O:=C;NI:=K;Part:=1;FindNode:=True;End;
    D:=Hypot(WX-C^.Nd^[J].BX,WY-C^.Nd^[J].BY);
    If (D<=Tol) And (D<Best) Then Begin Best:=D;O:=C;NI:=J;Part:=2;FindNode:=True;End;
   End;
  End;
 End;
End;

Function FindSeg(WX,WY: Double; Var O: PObj; Var Seg: Integer; Var T: Double): Boolean;
Var I,K,J,Last,S: Integer; Tol,D,Best,U,V,W,X0,Y0,X1,Y1,Px,Py,Dx,Dy,L2v,Tt: Double;
 Any: Boolean; C: PObj;
Begin
 Tol:=6/Sc;Best:=1E30;FindSeg:=False;
 Any:=CountSel>0;
 For I:=NObj DownTo 1 Do Begin
  C:=Objs[I];
  If Not PathCand(C,Any) Then Continue;
  If C^.Closed Then Last:=C^.N-1 Else Last:=C^.N-2;
  For K:=0 To Last Do Begin
   J:=(K+1) Mod C^.N;
   If C^.Nd^[K].Kind=2 Then Continue;
   If C^.Nd^[K].Kind=0 Then Begin
    D:=DistSeg(WX,WY,C^.Nd^[K].X,C^.Nd^[K].Y,C^.Nd^[J].X,C^.Nd^[J].Y);
    If (D<=Tol) And (D<Best) Then Begin
     Best:=D;O:=C;Seg:=K;FindSeg:=True;
     Dx:=C^.Nd^[J].X-C^.Nd^[K].X;Dy:=C^.Nd^[J].Y-C^.Nd^[K].Y;
     L2v:=Dx*Dx+Dy*Dy;
     If L2v>0 Then Tt:=((WX-C^.Nd^[K].X)*Dx+(WY-C^.Nd^[K].Y)*Dy)/L2v Else Tt:=0;
     If Tt<0.02 Then Tt:=0.02;If Tt>0.98 Then Tt:=0.98;
     T:=Tt;
    End;
   End Else Begin
    X0:=C^.Nd^[K].X;Y0:=C^.Nd^[K].Y;
    For S:=1 To 24 Do Begin
     Tt:=S/24;U:=1-Tt;
     Px:=U*U*U*C^.Nd^[K].X+3*U*U*Tt*C^.Nd^[K].AX+3*U*Tt*Tt*C^.Nd^[J].BX+Tt*Tt*Tt*C^.Nd^[J].X;
     Py:=U*U*U*C^.Nd^[K].Y+3*U*U*Tt*C^.Nd^[K].AY+3*U*Tt*Tt*C^.Nd^[J].BY+Tt*Tt*Tt*C^.Nd^[J].Y;
     D:=DistSeg(WX,WY,X0,Y0,Px,Py);
     If (D<=Tol) And (D<Best) Then Begin
      Best:=D;O:=C;Seg:=K;FindSeg:=True;
      T:=(S-0.5)/24;
      If T<0.02 Then T:=0.02;If T>0.98 Then T:=0.98;
     End;
     X0:=Px;Y0:=Py;
    End;
   End;
  End;
 End;
End;

Procedure MakePathy(O: PObj);
Begin
 If O^.Kind=OK_RRECT Then ToPathObj(O)
 Else If O^.Kind In [OK_RECT,OK_TRI,OK_PARA,OK_NGON] Then O^.Kind:=OK_POLY;
End;

Procedure InsertNodeAt(O: PObj; Seg: Integer; T: Double);
Var I,J,K: Integer; Q0x,Q0y,Q1x,Q1y,Q2x,Q2y,R0x,R0y,R1x,R1y,Sx,Sy: Double;
 P0x,P0y,P1x,P1y,P2x,P2y,P3x,P3y: Double; Nn: TNode;
Begin
 If O^.N>=MAXNODE-2 Then Exit;
 I:=Seg;J:=(I+1) Mod O^.N;
 If O^.Nd^[I].Kind=1 Then Begin
  P0x:=O^.Nd^[I].X;P0y:=O^.Nd^[I].Y;P1x:=O^.Nd^[I].AX;P1y:=O^.Nd^[I].AY;
  P2x:=O^.Nd^[J].BX;P2y:=O^.Nd^[J].BY;P3x:=O^.Nd^[J].X;P3y:=O^.Nd^[J].Y;
  Q0x:=P0x+(P1x-P0x)*T;Q0y:=P0y+(P1y-P0y)*T;
  Q1x:=P1x+(P2x-P1x)*T;Q1y:=P1y+(P2y-P1y)*T;
  Q2x:=P2x+(P3x-P2x)*T;Q2y:=P2y+(P3y-P2y)*T;
  R0x:=Q0x+(Q1x-Q0x)*T;R0y:=Q0y+(Q1y-Q0y)*T;
  R1x:=Q1x+(Q2x-Q1x)*T;R1y:=Q1y+(Q2y-Q1y)*T;
  Sx:=R0x+(R1x-R0x)*T;Sy:=R0y+(R1y-R0y)*T;
  NodeSet(Nn,Sx,Sy);
  Nn.BX:=R0x;Nn.BY:=R0y;Nn.AX:=R1x;Nn.AY:=R1y;Nn.Kind:=1;
  O^.Nd^[I].AX:=Q0x;O^.Nd^[I].AY:=Q0y;
  O^.Nd^[J].BX:=Q2x;O^.Nd^[J].BY:=Q2y;
 End Else Begin
  NodeSet(Nn,O^.Nd^[I].X+(O^.Nd^[J].X-O^.Nd^[I].X)*T,O^.Nd^[I].Y+(O^.Nd^[J].Y-O^.Nd^[I].Y)*T);
 End;
 SetCap(O,O^.N+4);
 For K:=O^.N DownTo I+2 Do O^.Nd^[K]:=O^.Nd^[K-1];
 O^.Nd^[I+1]:=Nn;
 Inc(O^.N);
End;

Procedure CutPath(O: PObj; Seg: Integer; T: Double);
Var K,I,N0: Integer; Tmp: Array[0..MAXNODE-1] Of TNode; T2: TObj; P: PObj; Cnt: Integer;
Begin
 InsertNodeAt(O,Seg,T);
 K:=Seg+1;
 N0:=O^.N;
 If O^.Closed Then Begin
  Cnt:=0;
  For I:=K To N0-1 Do Begin Tmp[Cnt]:=O^.Nd^[I];Inc(Cnt);End;
  For I:=0 To K Do Begin Tmp[Cnt]:=O^.Nd^[I];Inc(Cnt);End;
  If Cnt>MAXNODE-2 Then Exit;
  SetCap(O,Cnt+2);
  For I:=0 To Cnt-1 Do O^.Nd^[I]:=Tmp[I];
  O^.N:=Cnt;O^.Closed:=False;
  O^.Nd^[Cnt-1].Kind:=0;
 End Else Begin
  T2:=O^;
  T2.Nd:=TmpNd;T2.Cap:=MAXNODE;T2.Txt:=Nil;T2.BPix:=Nil;
  Cnt:=0;
  For I:=K To N0-1 Do Begin T2.Nd^[Cnt]:=O^.Nd^[I];Inc(Cnt);End;
  T2.N:=Cnt;T2.Sel:=False;
  P:=AddObjRec(T2);
  O^.N:=K+1;O^.Nd^[K].Kind:=0;
 End;
End;

Procedure ReversePath(O: PObj);
Var I,N: Integer; Tmp: Array[0..MAXNODE-1] Of TNode; T: Double;
Begin
 N:=O^.N;
 For I:=0 To N-1 Do Tmp[I]:=O^.Nd^[N-1-I];
 For I:=0 To N-1 Do Begin
  O^.Nd^[I]:=Tmp[I];
  T:=O^.Nd^[I].AX;O^.Nd^[I].AX:=O^.Nd^[I].BX;O^.Nd^[I].BX:=T;
  T:=O^.Nd^[I].AY;O^.Nd^[I].AY:=O^.Nd^[I].BY;O^.Nd^[I].BY:=T;
 End;
 For I:=0 To N-1 Do Begin
  O^.Nd^[I].Kind:=Tmp[(N-2-I+2*N) Mod N].Kind;
 End;
 If Not O^.Closed Then O^.Nd^[N-1].Kind:=0;
End;

Procedure DeleteNode(O: PObj; K: Integer);
Var I: Integer;
Begin
 If (O^.N<=2) Or (O^.Closed And (O^.N<=3)) Then Exit;
 For I:=K To O^.N-2 Do O^.Nd^[I]:=O^.Nd^[I+1];
 Dec(O^.N);
 If Not O^.Closed Then O^.Nd^[O^.N-1].Kind:=0;
End;

Procedure PathDown(WX,WY: Double);
Var O: PObj; NI,Part,Seg,Tl,Jx: Integer; T,L1,L2v: Double;
Begin
 Tl:=CurTool[BX_PATH];
 If FindNode(WX,WY,O,NI,Part) Then Begin
  Case Tl Of
   5: If Part=0 Then Begin
       PushUndo;MakePathy(O);DeleteNode(O,NI);MarkModified;NeedDraw:=True;Exit;
      End;
   7: If Part<>0 Then Begin
       PushUndo;
       If Part=1 Then Begin
        L1:=Hypot(O^.Nd^[NI].AX-O^.Nd^[NI].X,O^.Nd^[NI].AY-O^.Nd^[NI].Y);
        L2v:=Hypot(O^.Nd^[NI].BX-O^.Nd^[NI].X,O^.Nd^[NI].BY-O^.Nd^[NI].Y);
        If L1>1E-6 Then Begin
         If L2v<1E-6 Then L2v:=L1;
         O^.Nd^[NI].BX:=O^.Nd^[NI].X-(O^.Nd^[NI].AX-O^.Nd^[NI].X)*L2v/L1;
         O^.Nd^[NI].BY:=O^.Nd^[NI].Y-(O^.Nd^[NI].AY-O^.Nd^[NI].Y)*L2v/L1;
        End;
       End Else Begin
        L1:=Hypot(O^.Nd^[NI].BX-O^.Nd^[NI].X,O^.Nd^[NI].BY-O^.Nd^[NI].Y);
        L2v:=Hypot(O^.Nd^[NI].AX-O^.Nd^[NI].X,O^.Nd^[NI].AY-O^.Nd^[NI].Y);
        If L1>1E-6 Then Begin
         If L2v<1E-6 Then L2v:=L1;
         O^.Nd^[NI].AX:=O^.Nd^[NI].X-(O^.Nd^[NI].BX-O^.Nd^[NI].X)*L2v/L1;
         O^.Nd^[NI].AY:=O^.Nd^[NI].Y-(O^.Nd^[NI].BY-O^.Nd^[NI].Y)*L2v/L1;
        End;
       End;
       MarkModified;NeedDraw:=True;Exit;
      End;
   9: If Part=0 Then Begin
       PushUndo;MakePathy(O);ReversePath(O);MarkModified;NeedDraw:=True;Exit;
      End;
  End;
  { sinon : deplacement du noeud ou de la tangente }
  PushUndo;
  MakePathy(O);
  PathObj:=O;PathNode:=NI;PathPart:=Part;
  Dragging:=7;
  DragX0:=WX;DragY0:=WY;
  Exit;
 End;
 If FindSeg(WX,WY,O,Seg,T) Then Begin
  Case Tl Of
   3: Begin
       PushUndo;MakePathy(O);
       Jx:=(Seg+1) Mod O^.N;
       If O^.Nd^[Seg].Kind=1 Then O^.Nd^[Seg].Kind:=0
       Else Begin
        O^.Nd^[Seg].AX:=O^.Nd^[Seg].X+(O^.Nd^[Jx].X-O^.Nd^[Seg].X)/3;
        O^.Nd^[Seg].AY:=O^.Nd^[Seg].Y+(O^.Nd^[Jx].Y-O^.Nd^[Seg].Y)/3;
        O^.Nd^[Jx].BX:=O^.Nd^[Jx].X-(O^.Nd^[Jx].X-O^.Nd^[Seg].X)/3;
        O^.Nd^[Jx].BY:=O^.Nd^[Jx].Y-(O^.Nd^[Jx].Y-O^.Nd^[Seg].Y)/3;
        O^.Nd^[Seg].Kind:=1;
       End;
       MarkModified;
      End;
   4: Begin PushUndo;MakePathy(O);CutPath(O,Seg,T);MarkModified;DeselectAll;End;
   6: Begin PushUndo;MakePathy(O);InsertNodeAt(O,Seg,T);MarkModified;End;
   8: Begin
       PushUndo;MakePathy(O);
       If O^.Nd^[Seg].Kind=2 Then O^.Nd^[Seg].Kind:=0 Else O^.Nd^[Seg].Kind:=2;
       MarkModified;
      End;
  End;
  NeedDraw:=True;
 End;
End;

Procedure PathMove(WX,WY: Double);
Var DX,DY: Double; Tl: Integer;
Begin
 If PathObj=Nil Then Exit;
 SnapPt(WX,WY);
 Tl:=CurTool[BX_PATH];
 With PathObj^.Nd^[PathNode] Do Begin
  Case PathPart Of
   0: Begin
       DX:=WX-X;DY:=WY-Y;
       If Tl=2 Then Begin
        AX:=AX+DX;AY:=AY+DY;BX:=BX+DX;BY:=BY+DY;
       End;
       X:=WX;Y:=WY;
      End;
   1: Begin AX:=WX;AY:=WY;End;
   Else Begin BX:=WX;BY:=WY;End;
  End;
 End;
 RedrawCanvasOnly;
End;

{ ---- outils image ---- }
Procedure PicTool(O: PObj);
Var Tl,I,J,X1,Y1,X2,Y2,NW,NH,R: Integer; Nb: PBytes; Dp,Fw,Fh,Fx,Fy,V: Double; Mn: Boolean;
 Mapc: Array[0..15] Of Byte;
 Ax1,Ay1,Ax2,Ay2: Double;
Begin
 If O^.Kind<>OK_BITMAP Then Begin
  MsgBox('ArtWorx',L2('Click on a bitmap graphic','Cliquez sur une image bitmap'));Exit;
 End;
 If O^.BPix=Nil Then Exit;
 Tl:=CurTool[BX_PIC];
 Case Tl Of
  1: Begin
      DlgInit(L2('Fit to printer','Ajuster a l''imprimante'),320,100);
      AddLabel(14,38,L2('Resolution (dpi):','Resolution (dpi) :'));
      I:=AddEdit(170,34,70,IntStr(Round(ImgDpi)));
      AddStdBtns(False);
      If RunDialog=ID_OK Then
       If ParseNum(Ctl[I].S,Dp) And (Dp>=30) Then Begin
        PushUndo;
        Fw:=O^.BW*25.4/Dp;Fh:=O^.BH*25.4/Dp;
        Fx:=MinD(O^.Nd^[0].X,O^.Nd^[2].X);Fy:=MinD(O^.Nd^[0].Y,O^.Nd^[2].Y);
        NodeSet(O^.Nd^[0],Fx,Fy);NodeSet(O^.Nd^[1],Fx+Fw,Fy);
        NodeSet(O^.Nd^[2],Fx+Fw,Fy+Fh);NodeSet(O^.Nd^[3],Fx,Fy+Fh);
        MarkModified;
       End;
     End;
  2: Begin
      X1:=O^.BW;Y1:=O^.BH;X2:=-1;Y2:=-1;
      For J:=0 To O^.BH-1 Do
       For I:=0 To O^.BW-1 Do
        If O^.BPix^[J*O^.BW+I]<>15 Then Begin
         If I<X1 Then X1:=I;If I>X2 Then X2:=I;
         If J<Y1 Then Y1:=J;If J>Y2 Then Y2:=J;
        End;
      If (X2<X1) Or ((X1=0) And (Y1=0) And (X2=O^.BW-1) And (Y2=O^.BH-1)) Then Exit;
      PushUndo;
      NW:=X2-X1+1;NH:=Y2-Y1+1;
      GetMem(Nb,NW*NH);
      For J:=0 To NH-1 Do For I:=0 To NW-1 Do
       Nb^[J*NW+I]:=O^.BPix^[(J+Y1)*O^.BW+I+X1];
      Ax1:=MinD(O^.Nd^[0].X,O^.Nd^[2].X);Ay1:=MinD(O^.Nd^[0].Y,O^.Nd^[2].Y);
      Ax2:=MaxD(O^.Nd^[0].X,O^.Nd^[2].X);Ay2:=MaxD(O^.Nd^[0].Y,O^.Nd^[2].Y);
      Fw:=Ax2-Ax1;Fh:=Ay2-Ay1;
      NodeSet(O^.Nd^[0],Ax1+Fw*X1/O^.BW,Ay1+Fh*Y1/O^.BH);
      NodeSet(O^.Nd^[1],Ax1+Fw*(X2+1)/O^.BW,Ay1+Fh*Y1/O^.BH);
      NodeSet(O^.Nd^[2],Ax1+Fw*(X2+1)/O^.BW,Ay1+Fh*(Y2+1)/O^.BH);
      NodeSet(O^.Nd^[3],Ax1+Fw*X1/O^.BW,Ay1+Fh*(Y2+1)/O^.BH);
      FreeMem(O^.BPix,O^.BW*O^.BH);
      O^.BPix:=Nb;O^.BW:=NW;O^.BH:=NH;
      MarkModified;
     End;
  3: MsgBox(L2('Colour palette','Palette de couleurs'),
       L2('The document uses the standard 16-colour palette','Le document utilise la palette standard de 16 couleurs'));
  4: Begin
      R:=PopupChoice(L2('Lighter|Darker|Invert|Grey levels','Plus clair|Plus sombre|Inverser|Niveaux de gris'),
        ScrX(O^.Nd^[0].X),ScrY(O^.Nd^[0].Y),0);
      If R<0 Then Exit;
      PushUndo;
      For I:=0 To 15 Do Begin
       Case R Of
        0: If I<8 Then Mapc[I]:=I+8 Else Mapc[I]:=I;
        1: If I>=8 Then Mapc[I]:=I-8 Else Mapc[I]:=I;
        2: Mapc[I]:=15-I;
        Else Begin
         J:=(CR(PalRGB(I))*30+CG(PalRGB(I))*59+CB(PalRGB(I))*11) Div 100;
         If J<43 Then Mapc[I]:=0 Else If J<128 Then Mapc[I]:=8
         Else If J<213 Then Mapc[I]:=7 Else Mapc[I]:=15;
        End;
       End;
      End;
      For I:=0 To O^.BW*O^.BH-1 Do O^.BPix^[I]:=Mapc[O^.BPix^[I] And 15];
      MarkModified;
     End;
 End;
End;

{ ====================================================================== }
{                  SELECTION, MANIPULATION A LA SOURIS                   }
{ ====================================================================== }

Function AnyPropRes: Boolean;
Var I: Integer;
Begin
 AnyPropRes:=PropResize;
 For I:=1 To NObj Do If Objs[I]^.Sel And Objs[I]^.PropRes Then AnyPropRes:=True;
End;

{ Matrice de la manipulation courante (redimensionnement, rotation, cisaillement) }
Function ManipMatrix(H: Integer; WX,WY: Double; Var A,B,C,D,E,F: Double): Boolean;
Var NX1,NY1,NX2,NY2,W0,H0,CX,CY,Ang0,Ang1,Da,Kk,Yref,Hy,Xref,Hx,S: Double;
Begin
 ManipMatrix:=True;
 A:=1;B:=0;C:=0;D:=1;E:=0;F:=0;
 W0:=DragB[3]-DragB[1];H0:=DragB[4]-DragB[2];
 If W0<0.01 Then W0:=0.01;
 If H0<0.01 Then H0:=0.01;
 If RotMode Then Begin
  CX:=(DragB[1]+DragB[3])/2;CY:=(DragB[2]+DragB[4])/2;
  If Odd(H) Then Begin
   Ang0:=ArcTan2(DragY0-CY,DragX0-CX);
   Ang1:=ArcTan2(WY-CY,WX-CX);
   Da:=Ang1-Ang0;
   If GridSnap Or CtrlHeld Then Da:=Round(Da/(Pi/12))*(Pi/12);
   A:=Cos(Da);B:=Sin(Da);C:=-Sin(Da);D:=Cos(Da);
   E:=CX-CX*A-CY*C;F:=CY-CX*B-CY*D;
  End Else If (H=2) Or (H=6) Then Begin
   If H=2 Then Begin Yref:=DragB[4];Hy:=DragB[2];End
   Else Begin Yref:=DragB[2];Hy:=DragB[4];End;
   Kk:=(WX-DragX0)/(Hy-Yref);
   A:=1;B:=0;C:=Kk;D:=1;E:=-Kk*Yref;F:=0;
  End Else Begin
   If H=4 Then Begin Xref:=DragB[1];Hx:=DragB[3];End
   Else Begin Xref:=DragB[3];Hx:=DragB[1];End;
   Kk:=(WY-DragY0)/(Hx-Xref);
   A:=1;B:=Kk;C:=0;D:=1;E:=0;F:=-Kk*Xref;
  End;
 End Else Begin
  NX1:=DragB[1];NY1:=DragB[2];NX2:=DragB[3];NY2:=DragB[4];
  Case H Of
   1: Begin NX1:=WX;NY1:=WY;End;
   2: NY1:=WY;
   3: Begin NX2:=WX;NY1:=WY;End;
   4: NX2:=WX;
   5: Begin NX2:=WX;NY2:=WY;End;
   6: NY2:=WY;
   7: Begin NX1:=WX;NY2:=WY;End;
   8: NX1:=WX;
  End;
  If AnyPropRes And Odd(H) Then Begin
   S:=MaxD(Abs(NX2-NX1)/W0,Abs(NY2-NY1)/H0);
   Case H Of
    1: Begin NX1:=DragB[3]-W0*S;NY1:=DragB[4]-H0*S;End;
    3: Begin NX2:=DragB[1]+W0*S;NY1:=DragB[4]-H0*S;End;
    5: Begin NX2:=DragB[1]+W0*S;NY2:=DragB[2]+H0*S;End;
    7: Begin NX1:=DragB[3]-W0*S;NY2:=DragB[2]+H0*S;End;
   End;
  End;
  If NX2-NX1<0.3 Then Begin If H In [1,7,8] Then NX1:=NX2-0.3 Else NX2:=NX1+0.3;End;
  If NY2-NY1<0.3 Then Begin If H In [1,2,3] Then NY1:=NY2-0.3 Else NY2:=NY1+0.3;End;
  A:=(NX2-NX1)/W0;D:=(NY2-NY1)/H0;
  E:=NX1-DragB[1]*A;F:=NY1-DragB[2]*D;
 End;
End;

Procedure ManipPreview(WX,WY: Double);
Var A,B,C,D,E,F: Double; I: Integer; X,Y: Double;
Begin
 ManipMatrix(DragHandle,WX,WY,A,B,C,D,E,F);
 RubDraw;
 RubKind:=2;
 For I:=0 To 3 Do Begin
  Case I Of
   0: Begin X:=DragB[1];Y:=DragB[2];End;
   1: Begin X:=DragB[3];Y:=DragB[2];End;
   2: Begin X:=DragB[3];Y:=DragB[4];End;
   Else Begin X:=DragB[1];Y:=DragB[4];End;
  End;
  RubQ[I].X:=A*X+C*Y+E;RubQ[I].Y:=B*X+D*Y+F;
 End;
 RubDraw;
End;

Procedure ManipApply(WX,WY: Double);
Var A,B,C,D,E,F: Double; I: Integer;
Begin
 ManipMatrix(DragHandle,WX,WY,A,B,C,D,E,F);
 PushUndo;
 For I:=1 To NObj Do
  If Objs[I]^.Sel Then
   If (Not RotMode) And Objs[I]^.NoRes Then Else
    XformObj(Objs[I],A,B,C,D,E,F);
 MarkModified;
End;

Procedure SelectInRect(X1,Y1,X2,Y2: Double);
Var I: Integer; BX1,BY1,BX2,BY2,T: Double;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y1>Y2 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 For I:=1 To NObj Do
  If ObjVisible(Objs[I]) And Not ObjLocked(Objs[I]) Then Begin
   ObjBBox(Objs[I],BX1,BY1,BX2,BY2);
   If (BX1>=X1) And (BX2<=X2) And (BY1>=Y1) And (BY2<=Y2) Then
     SelectWithGroup(Objs[I],True);
  End;
End;

Procedure ScrollTo(NX,NY: Double);
Begin
 OrgX:=NX;OrgY:=NY;
 ClampOrigin;
End;

Procedure ZoomToRect(X1,Y1,X2,Y2: Double);
Var Zw,Zh,T: Double;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y1>Y2 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 If (X2-X1<0.5) Or (Y2-Y1<0.5) Then Exit;
 Zw:=(CVX2-CVX1+1)/((X2-X1)*3.7795)*100;
 Zh:=(CVY2-CVY1+1)/((Y2-Y1)*3.7795)*100;
 ZoomAround(MinD(Zw,Zh),(X1+X2)/2,(Y1+Y2)/2);
End;

{ ====================================================================== }
{                       PANNEAU, LIGNE D'INFO, BARRES                    }
{ ====================================================================== }

Procedure FuncClick(I: Integer);
Begin
 Case I Of
  1: Begin ZoomRect:=True;CurMsg:=L2('Draw a rectangle to zoom in','Tracez un rectangle pour agrandir');End;
  2: ZoomAround(Zoom/1.5,OrgX+CvW/Sc/2,OrgY+CvH/Sc/2);
  3: ZoomFullPage;
  4: CmdZOrder(False);
  5: CmdZOrder(True);
  6: ZoomAround(100,OrgX+CvW/Sc/2,OrgY+CvH/Sc/2);
  7: CmdGroup;
  8: CmdUngroup;
  9: CmdSnapToGrid;
  10: CmdCommute;
  11: CmdArrange;
  12: CmdDelete;
 End;
 NeedDraw:=True;
End;

Procedure PanelClick(X,Y: Integer);
Var C,I,N,R: Integer; Dbl: Boolean;
Begin
 If InBox(X,Y,PNX,PNFY,PNX+3*ICW-1,PNFY+4*ICW-1) Then Begin
  I:=((Y-PNFY) Div ICW)*3+((X-PNX) Div ICW)+1;
  FuncClick(I);
  Exit;
 End;
 If InBox(X,Y,PNX,PNCY,PNX+3*ICW-1,PNCY+ICW-1) Then Begin
  C:=(X-PNX) Div ICW;
  Dbl:=(LastPanelId=C+100) And (Tick-LastPanelT<45);
  LastPanelId:=C+100;LastPanelT:=Tick;
  Case C Of
   0: Begin
       If Dbl Then Begin
        R:=PopupChoice(L2('Path editing|Picture editing|Text editing','Edition de chemin|Edition d''image|Edition de texte'),
          PNX+ICW,PNCY+ICW,AuxBox-2);
        If R>=0 Then AuxBox:=R+2;
       End;
       AbortTool;
       SelMode:=False;CurBox:=AuxBox;
      End;
   1: Begin AbortTool;SelMode:=False;CurBox:=BX_DRAW;End;
   Else Begin AbortTool;SelMode:=True;RotMode:=False;End;
  End;
  If CurBox<>BX_DRAW Then LastBox:=CurBox;
  UpdateMsg;NeedDraw:=True;
  Exit;
 End;
 N:=ToolCount(CurBox);
 If InBox(X,Y,PNX,PNTY,PNX+3*ICW-1,PNTY+((N+2) Div 3)*ICW-1) Then Begin
  I:=((Y-PNTY) Div ICW)*3+((X-PNX) Div ICW)+1;
  If I<=N Then Begin
   AbortTool;
   SelMode:=False;
   CurTool[CurBox]:=I;
   UpdateMsg;NeedDraw:=True;
  End;
 End;
End;

Procedure InfoClick(X,Y: Integer);
Var I,R: Integer; Items: String;
Begin
 If InBox(X,Y,3,INFO_Y+3,60,INFO_Y+17) Then Begin CmdZoomDlg;NeedDraw:=True;Exit;End;
 If InBox(X,Y,66,INFO_Y+3,480,INFO_Y+17) Then Begin
  If CountSel>0 Then CmdObjInfo;
  NeedDraw:=True;Exit;
 End;
 If InBox(X,Y,528,INFO_Y+3,568,INFO_Y+17) Then Begin
  Items:='';
  For I:=1 To NPages Do Begin
   If I>1 Then Items:=Items+'|';
   Items:=Items+IntStr(I);
  End;
  R:=PopupChoice(Items,528,INFO_Y+17,CurPage-1);
  If R>=0 Then SetPage(R+1);
  NeedDraw:=True;Exit;
 End;
 If InBox(X,Y,576,INFO_Y+3,591,INFO_Y+17) Then Begin SetPage(CurPage-1);NeedDraw:=True;Exit;End;
 If InBox(X,Y,596,INFO_Y+3,611,INFO_Y+17) Then Begin SetPage(CurPage+1);NeedDraw:=True;Exit;End;
 For I:=1 To QuickN Do
  If InBox(X,Y,SCR_W-4-(QuickN-I+1)*20,INFO_Y+18,SCR_W-4-(QuickN-I+1)*20+18,INFO_Y+INFO_H-2) Then Begin
   Case I Of
    1: CmdSave;
    2: CmdPrint;
    3: CmdCut;
    4: CmdCopy;
    5: CmdPaste;
    6: PropResize:=Not PropResize;
    7: CmdText;
    8: CmdColour;
    9: CmdFill;
    10: CmdLines;
   End;
   NeedDraw:=True;Exit;
  End;
End;

Procedure ScrollClick(X,Y: Integer);
Var Vert: Boolean; StepV: Double; Tr,Rng,Vis,Pos1: Double;
Begin
 Vert:=X>CVX2;
 StepV:=60/Sc;
 If Vert Then Begin
  If Y<CVY1+SB_W Then ScrollTo(OrgX,OrgY-StepV)
  Else If Y>CVY2-SB_W Then ScrollTo(OrgX,OrgY+StepV)
  Else Dragging:=5;
 End Else Begin
  If X<CVX1+SB_W Then ScrollTo(OrgX-StepV,OrgY)
  Else If X>CVX2-SB_W Then ScrollTo(OrgX+StepV,OrgY)
  Else Dragging:=6;
 End;
 NeedDraw:=True;
End;

Procedure ScrollDrag(X,Y: Integer);
Var Tr,Rng,Vis,P: Double;
Begin
 If Dragging=5 Then Begin
  Tr:=CVY2-CVY1-2*SB_W-2;Rng:=PageH+60;Vis:=(CVY2-CVY1+1)/Sc;
  P:=(Y-CVY1-SB_W-1)/Tr*Rng-30-Vis/2;
  ScrollTo(OrgX,P);
 End Else Begin
  Tr:=CVX2-CVX1-2*SB_W-2;Rng:=PageW+60;Vis:=(CVX2-CVX1+1)/Sc;
  P:=(X-CVX1-SB_W-1)/Tr*Rng-30-Vis/2;
  ScrollTo(P,OrgY);
 End;
 RedrawCanvasOnly;
 HideMouse;DrawScrollbars;ShowMouse;
End;

{ ====================================================================== }
{                         GESTION DES EVENEMENTS                         }
{ ====================================================================== }

Procedure CanvasDown(X,Y: Integer; Dbl: Boolean);
Var WX,WY: Double; H: Integer; O: PObj; Mult: Boolean; S1: String;
Begin
 WX:=WorldX(X);WY:=WorldY(Y);
 Mult:=MultiSel Or ShiftHeld;
 If ZoomRect Then Begin
  Dragging:=9;DragX0:=WX;DragY0:=WY;RubKind:=0;
  Exit;
 End;
 DragX0:=WX;DragY0:=WY;DragSX:=X;DragSY:=Y;
 { poignees actives dans tous les modes (sauf edition de chemin) }
 If (SelMode Or (CurBox=BX_DRAW)) And (CountSel>0) And (DS=0) Then Begin
  H:=HandleAt(X,Y);
  If H>0 Then Begin
   SelBBox;
   DragB[1]:=SelBX1;DragB[2]:=SelBY1;DragB[3]:=SelBX2;DragB[4]:=SelBY2;
   DragHandle:=H;
   Dragging:=2;
   Exit;
  End;
 End;
 If SelMode Then Begin
  O:=TopObjAt(WX,WY,False,False);
  If O<>Nil Then Begin
   If Dbl Then Begin
    DeselectAll;SelectWithGroup(O,True);
    SelMode:=False;CurBox:=BX_PATH;AuxBox:=BX_PATH;UpdateMsg;
    NeedDraw:=True;Exit;
   End;
   ClickObj:=O;
   ClickWasSel:=O^.Sel And Not Mult;
   If Not ClickWasSel Then Begin
    If Not Mult Then DeselectAll;
    If Mult And O^.Sel Then SelectWithGroup(O,False) Else SelectWithGroup(O,True);
    RotMode:=False;
    NeedDraw:=True;
   End;
   DragMoved:=False;
   Dragging:=1;
  End Else Begin
   If Not Mult Then Begin DeselectAll;NeedDraw:=True;End;
   Dragging:=4;RubKind:=0;
  End;
  Exit;
 End;
 Case CurBox Of
  BX_DRAW: Begin
    If CurTool[BX_DRAW]=T_FREE Then Begin
     SnapPt(WX,WY);FreeBegin(WX,WY);
    End Else ToolClick(WX,WY);
   End;
  BX_PATH: PathDown(WX,WY);
  BX_PIC: Begin
    O:=TopObjAt(WX,WY,False,False);
    If O<>Nil Then Begin PicTool(O);NeedDraw:=True;End;
   End;
  BX_TEXT: Begin
    O:=TopObjAt(WX,WY,False,False);
    If (O<>Nil) And (O^.Kind In [OK_TEXT,OK_FTEXT]) Then Begin
     S1:=TxtOf(O);
     If TextEditor(KindName(O^.Kind),S1) Then Begin
      PushUndo;SetTxt(O,S1);MarkModified;NeedDraw:=True;
     End;
    End;
   End;
 End;
End;

Procedure CanvasMove(X,Y: Integer);
Var WX,WY,A,B,C,D,E,F: Double; Ddx,Ddy: Double;
Begin
 WX:=WorldX(X);WY:=WorldY(Y);
 Case Dragging Of
  1: If (Abs(X-DragSX)>3) Or (Abs(Y-DragSY)>3) Then Begin
      DragMoved:=True;Dragging:=11;
      SelBBox;
      DragB[1]:=SelBX1;DragB[2]:=SelBY1;DragB[3]:=SelBX2;DragB[4]:=SelBY2;
     End;
  4: RubSetRect(DragSX,DragSY,X,Y);
  9: RubSetRect(DragSX,DragSY,X,Y);
  5,6: ScrollDrag(X,Y);
  8: FreeMove(WX,WY);
  7: PathMove(WX,WY);
 End;
 If Dragging=11 Then Begin
  Ddx:=WX-DragX0;Ddy:=WY-DragY0;
  If GridSnap Or CtrlHeld Then Begin
   Ddx:=SnapV(DragB[1]+Ddx,GridX)-DragB[1];Ddy:=SnapV(DragB[2]+Ddy,GridY)-DragB[2];
  End;
  RubDraw;
  RubKind:=1;
  RubX1:=ScrX(DragB[1]+Ddx);RubY1:=ScrY(DragB[2]+Ddy);
  RubX2:=ScrX(DragB[3]+Ddx);RubY2:=ScrY(DragB[4]+Ddy);
  RubDraw;
  CurDX:=Ddx;CurDY:=Ddy;ShowDelta:=True;
 End;
 If Dragging=2 Then Begin
  SnapPt(WX,WY);
  ManipPreview(WX,WY);
  If Not RotMode Then Begin
   ManipMatrix(DragHandle,WX,WY,A,B,C,D,E,F);
   CurDX:=(DragB[3]-DragB[1])*A;CurDY:=(DragB[4]-DragB[2])*D;ShowDelta:=True;
  End;
 End;
 If (Dragging=0) And (DS>0) And (Not SelMode) And (CurBox=BX_DRAW) Then ToolMove(WX,WY);
End;

Procedure CanvasUp(X,Y: Integer);
Var WX,WY,Ddx,Ddy: Double; I: Integer;
Begin
 WX:=WorldX(X);WY:=WorldY(Y);
 Case Dragging Of
  1: Begin
      If ClickWasSel And Not DragMoved Then Begin
       RotMode:=Not RotMode;NeedDraw:=True;
      End;
      Dragging:=0;
     End;
  11: Begin
       RubClear;
       Ddx:=WX-DragX0;Ddy:=WY-DragY0;
       If GridSnap Or CtrlHeld Then Begin
        Ddx:=SnapV(DragB[1]+Ddx,GridX)-DragB[1];Ddy:=SnapV(DragB[2]+Ddy,GridY)-DragB[2];
       End;
       If (Abs(Ddx)>0.001) Or (Abs(Ddy)>0.001) Then Begin
        PushUndo;MoveSel(Ddx,Ddy);MarkModified;
       End;
       Dragging:=0;ShowDelta:=False;NeedDraw:=True;
      End;
  2: Begin
      RubClear;
      SnapPt(WX,WY);
      If (Abs(X-DragSX)>2) Or (Abs(Y-DragSY)>2) Then ManipApply(WX,WY)
      Else If Not RotMode Then ;
      Dragging:=0;ShowDelta:=False;NeedDraw:=True;
     End;
  4: Begin
      RubClear;
      If (Abs(X-DragSX)>3) Or (Abs(Y-DragSY)>3) Then
        SelectInRect(WorldX(DragSX),WorldY(DragSY),WX,WY);
      Dragging:=0;NeedDraw:=True;
     End;
  9: Begin
      RubClear;
      If (Abs(X-DragSX)>4) Or (Abs(Y-DragSY)>4) Then
        ZoomToRect(WorldX(DragSX),WorldY(DragSY),WX,WY)
      Else ZoomAround(Zoom*2,WX,WY);
      Dragging:=0;ZoomRect:=False;UpdateMsg;NeedDraw:=True;
     End;
  5,6: Begin Dragging:=0;NeedDraw:=True;End;
  7: Begin Dragging:=0;PathObj:=Nil;MarkModified;NeedDraw:=True;End;
  8: FreeEnd;
 End;
 If (Not SelMode) And (CurBox=BX_DRAW) And (DS>0) And (NeedPts(CurTool[BX_DRAW])=2)
   And (Dragging=0) And (NDP=1) Then Begin
  { glisser-deposer (Click-Move) : relacher loin du point de depart }
  If (Abs(X-DragSX)>=8) Or (Abs(Y-DragSY)>=8) Then Begin
   WX:=WorldX(X);WY:=WorldY(Y);SnapPt(WX,WY);
   ToolFinish(WX,WY);
  End;
 End;
End;

Procedure CanvasRight(X,Y: Integer);
Begin
 If TxtEditing Then Begin TextKey(K_ENTER);Exit;End;
 If (DS>0) Or (NDP>0) Then Begin
  If (Not SelMode) And (CurBox=BX_DRAW) Then ToolFinishOpen;
  Exit;
 End;
 If Dragging<>0 Then Begin RubClear;Dragging:=0;NeedDraw:=True;Exit;End;
 If SelMode Then Begin
  SelMode:=False;
  If LastBox>0 Then CurBox:=LastBox;
 End Else Begin
  If CurBox<>BX_DRAW Then LastBox:=CurBox Else LastBox:=BX_DRAW;
  SelMode:=True;
 End;
 UpdateMsg;NeedDraw:=True;
End;

Procedure HandleLDown(X,Y: Integer);
Var T: Integer; Dbl: Boolean; Tk: LongInt;
Begin
 Tk:=Tick;
 Dbl:=(Abs(Tk-LastClickT)<35) And (Abs(X-LastClickX)<5) And (Abs(Y-LastClickY)<5);
 LastClickT:=Tk;LastClickX:=X;LastClickY:=Y;
 T:=TitleHit(X,Y);
 If T>0 Then Begin
  If TxtEditing Then TextKey(K_ENTER);
  RunMenu(T,True);
  Exit;
 End;
 If TxtEditing Then TextKey(K_ENTER);
 If Y<MENU_H Then Exit;
 If (Y>=TITLE_Y) And (Y<TITLE_Y+TITLE_H) Then Begin
  If X<=TITLE_H Then CmdNew;
  NeedDraw:=True;Exit;
 End;
 If (Y>=INFO_Y) And (Y<INFO_Y+INFO_H) Then Begin InfoClick(X,Y);Exit;End;
 If (X<PANEL_W) And (Y>=CVY1) Then Begin PanelClick(X,Y);Exit;End;
 If InBox(X,Y,CVX1,CVY1,CVX2,CVY2) Then Begin CanvasDown(X,Y,Dbl);Exit;End;
 If (X>CVX2) Or (Y>CVY2) Then ScrollClick(X,Y);
End;

Procedure HandleMove(X,Y: Integer);
Var WX,WY: Double; Ic,N: Integer; Old: String;
Begin
 If InBox(X,Y,CVX1,CVY1,CVX2,CVY2) Then Begin
  WX:=WorldX(X);WY:=WorldY(Y);
  CurWX:=WX;CurWY:=WY;
  CanvasMove(X,Y);
  If Dragging=0 Then ShowDelta:=ShowDelta And (DS>0);
  HideMouse;DrawInfoLine;ShowMouse;
 End Else Begin
  If Dragging<>0 Then CanvasMove(X,Y);
  If (X<PANEL_W) And (Y>=PNTY) Then Begin
   N:=ToolCount(CurBox);
   Ic:=((Y-PNTY) Div ICW)*3+((X-PNX) Div ICW)+1;
   Old:=CurMsg;
   If (Ic>=1) And (Ic<=N) And (X-PNX<3*ICW) Then CurMsg:=ToolName(CurBox,Ic) Else UpdateMsg;
   If Old<>CurMsg Then Begin HideMouse;DrawInfoLine;ShowMouse;End;
  End;
 End;
End;

Procedure ScrollKey(K: Word);
Var St: Double;
Begin
 St:=40/Sc;
 Case K Of
  K_UP: ScrollTo(OrgX,OrgY-St);
  K_DOWN: ScrollTo(OrgX,OrgY+St);
  K_LEFT: ScrollTo(OrgX-St,OrgY);
  K_RIGHT: ScrollTo(OrgX+St,OrgY);
 End;
 NeedDraw:=True;
End;

Procedure HandleKey(K: Word);
Var L: Integer; Ch: Char; I: Integer;
Begin
 If TxtEditing Then Begin TextKey(K);Exit;End;
 L:=AltLetter(K);
 If L>=0 Then Begin
  Case L Of
   16: ZoomFullPage;                                  { Alt-Q }
   22: ZoomAround(100,OrgX+CvW/Sc/2,OrgY+CvH/Sc/2);   { Alt-W }
   25: CmdZoomDlg;                                    { Alt-Z }
   11: CmdLines;                                      { Alt-L }
   12: CmdFill;                                       { Alt-M }
   5: CmdColour;                                      { Alt-F }
   19: CmdText;                                       { Alt-T }
   18: CmdShadows;                                    { Alt-S }
   20: CmdStatus;                                     { Alt-U }
   3: CmdModules;                                     { Alt-D }
   0: CmdGeneral;                                     { Alt-A }
   4: CmdPaths;                                       { Alt-E }
   17: CmdGrid;                                       { Alt-R }
   14: CmdFormat;                                     { Alt-O }
   1: CmdEditor;                                      { Alt-B }
   8: CmdImages;                                      { Alt-I }
  End;
  NeedDraw:=True;
  Exit;
 End;
 Case K Of
  K_ESC: Begin
    If (DS>0) Or (NDP>0) Then AbortTool Else Begin DeselectAll;NeedDraw:=True;End;
    ZoomRect:=False;
   End;
  K_ENTER: If (NDP>0) And (Not SelMode) Then ToolFinishOpen Else Begin CmdSaveAs;NeedDraw:=True;End;
  14: CmdNew;
  15: CmdOpen;
  21: CmdNew;
  2: CmdInsert;
  19: CmdSave;
  5: CmdExport;
  9: Begin
      { Tab : objet suivant }
      If NObj>0 Then Begin
       I:=0;
       Repeat
        Inc(I);
        If I>NObj Then I:=0;
       Until (I=0) Or Objs[I]^.Sel;
       DeselectAll;
       If (I=0) Or (I>=NObj) Then I:=1 Else Inc(I);
       Repeat
        If ObjVisible(Objs[I]) And Not ObjLocked(Objs[I]) Then Begin SelectWithGroup(Objs[I],True);Break;End;
        Inc(I);If I>NObj Then I:=1;
       Until False;
       NeedDraw:=True;
      End;
     End;
  16: CmdPrint;
  17: If CheckSave Then Quit:=True;
  3: Begin CmdCopy;End;
  24: Begin CmdCut;NeedDraw:=True;End;
  22: Begin CmdPaste;NeedDraw:=True;End;
  1: Begin CmdSelectAll;NeedDraw:=True;End;
  23: Begin If NPages>1 Then If CurPage<NPages Then SetPage(CurPage+1) Else SetPage(1);NeedDraw:=True;End;
  26: Begin PropResize:=Not PropResize;NeedDraw:=True;End;
  316: Begin DoUndo;NeedDraw:=True;End;
  K_F1: Begin
    MsgBox(L2('Help','Aide'),
      L2('Right click or Space: selection / drawing mode','Clic droit ou Espace : mode selection / dessin')+'|'+
      L2('Click twice on a selected object: rotate / skew','Cliquez 2 fois sur un objet : rotation / cisaillement')+'|'+
      L2('Double click an object: path editing','Double-clic sur un objet : edition de chemin')+'|'+
      L2('Ctrl: snap to grid   M: multi-selection   Tab: next object','Ctrl : grille   M : multi-selection   Tab : objet suivant')+'|'+
      L2('F10: menus   F2: undo   Del: delete','F10 : menus   F2 : annuler   Suppr : effacer'));
    NeedDraw:=True;
   End;
  324: RunMenu(2,False);
  K_DEL,K_BKSP: Begin CmdDelete;NeedDraw:=True;End;
  32: Begin
    If (DS>0) Or (NDP>0) Then AbortTool;
    If SelMode Then Begin SelMode:=False;If LastBox>0 Then CurBox:=LastBox;End
    Else Begin SelMode:=True;End;
    UpdateMsg;NeedDraw:=True;
   End;
  K_UP,K_DOWN,K_LEFT,K_RIGHT: ScrollKey(K);
  K_PGUP: Begin SetPage(CurPage-1);NeedDraw:=True;End;
  K_PGDN: Begin SetPage(CurPage+1);NeedDraw:=True;End;
  Ord('+'): Begin ZoomAround(Zoom*1.5,OrgX+CvW/Sc/2,OrgY+CvH/Sc/2);NeedDraw:=True;End;
  Ord('-'): Begin ZoomAround(Zoom/1.5,OrgX+CvW/Sc/2,OrgY+CvH/Sc/2);NeedDraw:=True;End;
  Else Begin
   If K<256 Then Begin
    Ch:=UpCase(Chr(K));
    Case Ch Of
     'M': Begin MultiSel:=Not MultiSel;
          If MultiSel Then CurMsg:=L2('Multi-selection ON','Multi-selection active') Else UpdateMsg;
          NeedDraw:=True;End;
     'D': If OptDKey Then Begin CmdDelete;NeedDraw:=True;End;
     'I': If CountSel>0 Then CmdImportInto;
     'O': If CountSel>0 Then CmdObjExport;
     'V': CmdZOrder(True);
     'H': CmdZOrder(False);
     'G': CmdGroup;
     'Z': CmdUngroup;
     'S': CmdLock(True);
     'F': CmdLock(False);
     'N': CmdObjInfo;
     'A': CmdArrange;
     'E': CmdSnapToGrid;
     'U': CmdCommute;
     'T': CmdTransform;
     'P': CmdTiling;
     'K': CmdBoolean;
    End;
    NeedDraw:=True;
   End;
  End;
 End;
End;

{ ====================================================================== }
{                          INITIALISATION ET PRINCIPAL                   }
{ ====================================================================== }

Procedure InitData;
Var I: Integer;
Begin
 LangEN:=(Upper(Copy(GetEnv('LANGUAGE'),1,2))='EN');
 Quit:=False;NeedDraw:=True;
 NObj:=0;PageW:=210;PageH:=297;NPages:=1;CurPage:=1;
 DocName:='';Named:=False;Modified:=False;
 GridX:=10;GridY:=10;GridShow:=True;GridSnap:=False;
 UnitIdx:=0;PropResize:=False;
 CurLineCol:=0;CurFillCol:=0;CurShCol:=MkRGB(85,85,85);
 CurLineW:=0;CurLineSty:=0;CurEndS:=0;CurEndE:=0;
 CurFillMode:=0;CurFillPat:=1;CurGrey:=128;
 CurShOn:=False;CurShDX:=5;CurShDY:=5;CurFSize:=14;CurTFlags:=0;CurTAlign:=0;
 OptDKey:=False;OptBeep:=True;OptConfirm:=False;OptUndo:=True;OptClip:=False;
 OptTrue:=False;OptImages:='';OptModule:='';OptEditor:='';
 CurBox:=BX_DRAW;LastBox:=BX_DRAW;AuxBox:=BX_PATH;
 For I:=1 To 4 Do CurTool[I]:=1;
 SelMode:=True;
 DS:=0;NDP:=0;DNSides:=5;Dragging:=0;RotMode:=False;
 PathObj:=Nil;MarkObj:=Nil;EditObj:=Nil;TxtEditing:=False;
 ClipHas:=False;UndoN:=0;UndoSeq:=0;
 MenuOpen:=0;MenuHi:=0;MX:=0;MY:=0;MB:=0;LastB:=0;
 LastClickT:=0;LastClickX:=0;LastClickY:=0;
 LastPanelT:=0;LastPanelId:=0;
 ImgDpi:=300;MultiSel:=False;ZoomRect:=False;
 PrevDrawn:=False;PrevOk:=False;RubKind:=0;CloseIt:=False;
 CurMsg:='';ShowDelta:=False;
 NextGroup:=0;
 For I:=1 To NLAYER Do Begin
  Layers[I].Name:=L2('Layer ','Calque ')+IntStr(I);
  Layers[I].Hidden:=False;Layers[I].Locked:=False;Layers[I].OnScreen:=False;
 End;
 CurLayer:=1;
 New(FP);New(SP);New(FreeP);
 GetMem(TmpNd,MAXNODE*SizeOf(TNode));
 FillChar(TmpNd^,MAXNODE*SizeOf(TNode),0);
 SetZoom(50);
 CvW:=CVX2-CVX1+1;CvH:=CVY2-CVY1+1;
 Randomize;
End;

Procedure EraseFile(Const N: String);
Var F: File;
Begin
 {$I-}
 Assign(F,N);
 Erase(F);
 {$I+}
 If IOResult<>0 Then ;
End;

Procedure ShowHelpLine;
Var H: Text;
Begin
 Assign(H,'');Rewrite(H);
 If LangEN Then Begin
  WriteLn(H,'ARTWORX - Clone of the ArtWorx vector drawing program (Atari ST).');
  WriteLn(H);
  WriteLn(H,'Usage : ARTWORX [file.CWG] [/?]');
  WriteLn(H);
  WriteLn(H,'  file.CWG  Drawing to open (native ArtWorx format).');
  WriteLn(H,'  /?        Show this help.');
  WriteLn(H);
  WriteLn(H,'Language : French by default, English if LANGUAGE=EN is set.');
 End Else Begin
  WriteLn(H,'ARTWORX - Clone du programme de dessin vectoriel ArtWorx (Atari ST).');
  WriteLn(H);
  WriteLn(H,'Utilisation : ARTWORX [fichier.CWG] [/?]');
  WriteLn(H);
  WriteLn(H,'  fichier.CWG  Dessin a ouvrir (format natif ArtWorx).');
  WriteLn(H,'  /?           Affiche cette aide.');
  WriteLn(H);
  WriteLn(H,'Langue : francais par defaut, anglais si LANGUAGE=EN est definie.');
 End;
 Close(H);
End;

Procedure MainLoop;
Var E: TEvent;
Begin
 Repeat
  If NeedDraw Then Begin DrawAll;If PrevOk And (DS>0) Then XorPreview(True);End;
  PollEvent(E);
  Case E.Kind Of
   1: HandleKey(E.Key);
   2: HandleLDown(E.X,E.Y);
   3: CanvasUp(E.X,E.Y);
   4: HandleMove(E.X,E.Y);
   5: Begin
       If InBox(E.X,E.Y,CVX1,CVY1,CVX2,CVY2) Then CanvasRight(E.X,E.Y)
       Else If E.X<PANEL_W Then Begin End;
      End;
  End;
 Until Quit;
End;

BEGIN
 LangEN:=(Upper(Copy(GetEnv('LANGUAGE'),1,2))='EN');
 If (ParamCount>=1) And ((ParamStr(1)='/?') Or (ParamStr(1)='-h') Or
    (ParamStr(1)='--help')) Then Begin
  ShowHelpLine;
  Halt(0);
 End;
 InitData;
 InitializeGraphics;
 CaptureFont;
 If MouseDriverFound Then ShowMouse;
 LoadOptions;
 ZoomFullPage;
 If ParamCount>=1 Then OpenFile(ParamStr(1));
 UpdateMsg;
 MainLoop;
 CleanUndo;
 EraseFile('ARTWORX.CLP');
 CloseGraph;
END.
