{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application Calamus
}

{ Liste de points implementes :
  ---------------------------------------------------------------------------
   1. Menus deroulants : logo Calamus / Fichier (Datei) / Page (Seite) /
      Texte (Text) / Vue (Sicht) / Extras (souris, F10, fleches, Entree,
      Echap), messages d'aide (Hilfsmeldungen) en haut a droite
   2. Fenetre de document : barre de titre a rayures, barres de defilement,
      barre d'icones du haut (outils, police, style, motif, page, X/Y/dX/dY)
   3. Boite a outils hierarchique a icones (outils principaux, palette de
      formes, reperes/grille, fichiers) comme dans Calamus
   4. Cadres de texte (police, taille, style, alignement, interligne,
      rotation libre), cadres graphiques (15 formes), lignes, cadres raster
   5. Edition du texte dans les cadres : curseur, retour a la ligne
      automatique, justification, import / export de texte ASCII
   6. Selection, deplacement, redimensionnement (poignees), selection par
      cadre, duplication, premier plan / arriere-plan, suppression
   7. Dialogues : format de page (A5, A4, A3, Letter, Legal, Double, Half,
      marges, unites), numerotation des pages (1,2 A,B a,b I,II i,ii),
      attributs de texte, attributs de cadre, zoom, chemins, options,
      scanner, statistiques
   8. Pages multiples, reperes, grille, zoom, annulation (Undo)
   9. Fichiers : format natif .CDK, import d'images BMP (trame ordonnee),
      export de texte, sortie PostScript, sauvegarde de la configuration
  10. Interface en francais par defaut, en anglais si la variable
      d'environnement LANGUAGE=EN, en allemand si LANGUAGE=GR
}

Program CALAMUS;

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
 TB_Y = 16;              { barre d'icones du haut }
 TB_H = 36;
 WIN_Y = 52;             { haut de la fenetre et de la boite a outils }
 PANEL_W = 132;
 TITLE_H = 16;
 CVX1 = 133;
 CVY1 = 69;
 CVX2 = 622;
 CVY2 = 461;
 VSX1 = 623;             { barre de defilement verticale }
 HSY1 = 462;             { barre de defilement horizontale }

 INK = 0;
 PAPER = 15;
 GREY = 8;

 MAXFR = 150;            { cadres maximum }
 MAXTXT = 8000;          { caracteres maximum par cadre de texte }
 MAXLN = 400;            { lignes maximum d'un cadre de texte }
 MAXGUIDE = 16;
 MAXPAGES = 40;
 NFONT = 6;
 NPAT = 24;
 TPAD = 1.0;             { marge interne d'un cadre de texte (mm) }
 PT_MM = 0.35277778;     { millimetres par point }

 { Types de cadres }
 FK_TEXT = 1; FK_SHAPE = 2; FK_LINE = 3; FK_RASTER = 4;

 { Outils }
 TL_SELECT = 1; TL_TEXTEDIT = 2; TL_ZOOM = 3; TL_TEXTFR = 4; TL_LINE = 5;
 TL_RASTER = 6; TL_SHAPE = 7; TL_ROTTXT = 8;

 { Styles de texte (bits) }
 ST_BOLD = 1; ST_ITALIC = 2; ST_UNDER = 4; ST_OUTLINE = 8; ST_SHADOW = 16;

 { Codes de touches : caractere = ord ; etendue = 256 + code }
 K_ESC = 27; K_ENTER = 13; K_BKSP = 8; K_TAB = 9;
 K_UP = 328; K_DOWN = 336; K_LEFT = 331; K_RIGHT = 333;
 K_HOME = 327; K_END = 335; K_PGUP = 329; K_PGDN = 337;
 K_INS = 338; K_DEL = 339; K_F1 = 315; K_F10 = 324; K_STAB = 271;

 NMENU = 6;

{ ====================================================================== }
{                                TYPES                                   }
{ ====================================================================== }

Type
 TPt = Record X,Y: Double; End;
 TPoly = Array[1..64] Of TPt;
 PBits = ^TBits;
 TBits = Array[0..8191] Of Byte;
 PTxt = ^TTxt;
 TTxt = Array[0..MAXTXT-1] Of Char;
 PFrame = ^TFrame;
 TFrame = Record
  Kind: Byte;
  Page: Integer;
  X,Y,W,H,Ang: Double;
  Shape,Fill,LineW: Byte;     { LineW en dixiemes de mm }
  Shadow,Flip: Boolean;
  Font: Byte;
  Size: Double;               { points }
  Style,Align: Byte;
  LineSp: Integer;            { pourcentage }
  TLen,Cap: Integer;
  Txt: PTxt;
  BW,BH: Integer;
  Bits: PBits;
  Sel: Boolean;
 End;
 TEvent = Record
  { 0 rien, 1 touche, 2 bouton gauche bas, 3 bouton gauche haut,
    4 mouvement, 5 bouton droit bas }
  Kind: Byte;
  Key: Word;
  X,Y,B: LongInt;
 End;
 TPat = Array[0..7] Of Byte;

{ ====================================================================== }
{                              VARIABLES                                 }
{ ====================================================================== }

Var
 Lang: Integer;                { 0 francais, 1 anglais, 2 allemand }
 Quit: Boolean;
 NeedDraw: Boolean;
 { Document }
 Frs: Array[1..MAXFR] Of PFrame;
 NFr: Integer;
 PageW,PageH: Double;          { mm }
 MarL,MarR,MarT,MarB: Double;
 MirrorMar,DoublePg: Boolean;
 NPages,CurPage: Integer;
 NumStyle,NumFrom,NumTo,NumStart: Integer;
 NumOn: Boolean;
 GuideV,GuideH: Array[1..MAXGUIDE] Of Double;
 NGV,NGH: Integer;
 DocName: String;
 Named,Modified: Boolean;
 { Vue }
 Zoom: Double;                 { pourcentage }
 Sc: Double;                   { pixels par mm }
 OrgX,OrgY: Double;            { coin haut gauche du canevas (mm) }
 CvW,CvH: Integer;
 GridX,GridY: Double;
 GridShow,GridSnap,ShowMargins,ShowFrames: Boolean;
 UnitIdx,FUnitIdx: Integer;    { unites : 0 inch, 1 cm, 2 pica, 3 cicero }
 PatOX,PatOY: Integer;
 { Options }
 OptHelp,OptCopyAsk,OptBeep,OptUndo,OptAutoEdit: Boolean;
 PathDoc,PathFont,PathImg,PathTxt: String;
 ScanDpi,ScanMode,ScanThr: Integer;
 FontLoaded: Array[1..NFONT] Of Boolean;
 { Attributs courants }
 CurFont: Integer;
 CurSize: Double;
 CurStyle,CurAlign: Integer;
 CurLineSp: Integer;
 CurShape,CurFillMode: Integer;
 CurLineW: Integer;
 { Modes }
 Tool: Integer;
 TbPage: Integer;
 EditFr: PFrame;
 Editing: Boolean;
 CurPos: Integer;
 { Souris / clavier }
 MX,MY,MB,LastB: LongInt;
 PrevMX,PrevMY: LongInt;
 LastClickT: LongInt;
 LastClickX,LastClickY: LongInt;
 HelpMsg: String;
 InfoX,InfoY,InfoDX,InfoDY: Double;
 { Divers }
 FontBits: Array[0..255,0..7] Of Byte;
 GW: Array[0..255] Of Byte;
 MenuOpen,MenuHi: Integer;
 UndoHas: Boolean;
 ClipFr: PFrame;
 TrigC,TrigS: Double;
 { Disposition du texte }
 LnS,LnL,LnN: Array[1..MAXLN] Of Integer;
 LnWd: Array[1..MAXLN] Of Double;
 LnPar: Array[1..MAXLN] Of Boolean;
 NLn: Integer;
 { Boite de dialogue : liste }
 LstItem: Array[1..80] Of String[40];
 LstN: Integer;

{ ====================================================================== }
{                       UTILITAIRES GENERAUX                             }
{ ====================================================================== }

Function L3(Const En,Fr,De: String): String;
Begin
 Case Lang Of
  1: L3:=En;
  2: L3:=De;
  Else L3:=Fr;
 End;
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
 While (S<>'') And (S[Length(S)]=' ') Do Dec(S[0]);
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

Function ClampD(V,Lo,Hi: Double): Double;
Begin
 If V<Lo Then V:=Lo;
 If V>Hi Then V:=Hi;
 ClampD:=V;
End;

Function ToInt(D: Double): Integer;
Begin
 If D>30000 Then D:=30000;
 If D<-30000 Then D:=-30000;
 ToInt:=Round(D);
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

Function ParseNum(Const S: String; Var X: Double): Boolean;
Var Code: Integer; T: String; I: Integer;
Begin
 T:=TrimStr(S);
 For I:=1 To Length(T) Do If T[I]=',' Then T[I]:='.';
 If T='' Then Begin ParseNum:=False;Exit;End;
 Val(T,X,Code);
 ParseNum:=(Code=0);
End;

Function SameDoc(A,B: Double): Boolean;
Begin
 SameDoc:=Abs(A-B)<0.05;
End;

Function ExtOf(Const N: String): String;
Var I,P: Integer;
Begin
 P:=0;
 For I:=1 To Length(N) Do Begin
  If N[I]='.' Then P:=I;
  If (N[I]='\') Or (N[I]='/') Then P:=0;
 End;
 If P=0 Then ExtOf:='' Else ExtOf:=Upper(Copy(N,P,10));
End;

Function AddExt(Const N,E: String): String;
Begin
 If ExtOf(N)='' Then AddExt:=N+E Else AddExt:=N;
End;

Function ShortName(Const N: String): String;
Var I,P: Integer;
Begin
 P:=0;
 For I:=1 To Length(N) Do If (N[I]='\') Or (N[I]='/') Then P:=I;
 ShortName:=Copy(N,P+1,100);
End;

Function Hex2(B: Integer): String;
Const HexC: String[16] = '0123456789ABCDEF';
Begin
 Hex2:=HexC[((B Shr 4) And 15)+1]+HexC[(B And 15)+1];
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

Function TokNum(Var S: String): Double;
Var T: String; X: Double;
Begin
 T:=NextTok(S);
 If Not ParseNum(T,X) Then X:=0;
 TokNum:=X;
End;

{ ---- unites ---- }
Const
 UMM: Array[0..3] Of Double = (25.4,10.0,4.2333333,4.5106);
 FMM: Array[0..2] Of Double = (0.35277778,0.37595,1.0);

Function UnitName(U: Integer): String;
Begin
 Case U Of
  0: UnitName:='in';
  1: UnitName:='cm';
  2: UnitName:='pica';
  Else UnitName:='cic';
 End;
End;

Function MmToU(Mm: Double): Double;
Begin
 MmToU:=Mm/UMM[UnitIdx];
End;

Function UToMm(V: Double): Double;
Begin
 UToMm:=V*UMM[UnitIdx];
End;

Function FmtU(Mm: Double): String;
Begin
 FmtU:=RealStr(MmToU(Mm),2);
End;

Function PtToF(Pt: Double): Double;     { points -> unite des polices }
Begin
 PtToF:=Pt*PT_MM/FMM[FUnitIdx];
End;

Function FToPt(V: Double): Double;
Begin
 FToPt:=V*FMM[FUnitIdx]/PT_MM;
End;

Function Roman(N: Integer; Up: Boolean): String;
Const
 V: Array[1..13] Of Integer = (1000,900,500,400,100,90,50,40,10,9,5,4,1);
 R: Array[1..13] Of String[2] = ('M','CM','D','CD','C','XC','L','XL','X','IX','V','IV','I');
Var I: Integer; S: String;
Begin
 S:='';
 If N<1 Then N:=1;
 If N>3999 Then N:=3999;
 For I:=1 To 13 Do
  While N>=V[I] Do Begin S:=S+R[I];Dec(N,V[I]);End;
 If Not Up Then S:=Lower(S);
 Roman:=S;
End;

Function PageLabel(N: Integer): String;
Var S: String; K: Integer;
Begin
 K:=N-1+NumStart;
 If K<1 Then K:=1;
 Case NumStyle Of
  1: Begin
      S:='';
      Repeat
       S:=Chr(65+((K-1) Mod 26))+S;
       K:=(K-1) Div 26;
      Until K=0;
      PageLabel:=S;
     End;
  2: Begin
      S:='';
      Repeat
       S:=Chr(97+((K-1) Mod 26))+S;
       K:=(K-1) Div 26;
      Until K=0;
      PageLabel:=S;
     End;
  3: PageLabel:=Roman(K,True);
  4: PageLabel:=Roman(K,False);
  Else PageLabel:=IntStr(K);
 End;
End;

Function PageNumbered(N: Integer): Boolean;
Begin
 PageNumbered:=NumOn And (N>=NumFrom) And (N<=NumTo);
End;

{ ====================================================================== }
{                        PRIMITIVES GRAPHIQUES                           }
{ ====================================================================== }

Const
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

Var
 PolyP: Array[1..64] Of PointType;
 ClipW,ClipH: Integer;

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

Procedure WText(X,Y: Integer; Const S: String);
Begin
 SetColor(PAPER);
 OutTextXY(X,Y,S);
End;

Procedure GreyText(X,Y: Integer; Const S: String);
Begin
 SetColor(GREY);
 OutTextXY(X,Y,S);
End;

Procedure BText(X,Y: Integer; Const S: String);
Begin
 SetColor(INK);
 OutTextXY(X,Y,S);
 OutTextXY(X+1,Y,S);
End;

Function TextW(Const S: String): Integer;
Begin
 TextW:=Length(S)*8;
End;

Function InBox(X,Y,X1,Y1,X2,Y2: LongInt): Boolean;
Begin
 InBox:=(X>=X1) And (X<=X2) And (Y>=Y1) And (Y<=Y2);
End;

Procedure DotLine(X1,Y1,X2,Y2,C: Integer);
Begin
 SetColor(C);
 SetLineStyle(UserBitLn,$AAAA,1);
 Line(X1,Y1,X2,Y2);
 SetLineStyle(SolidLn,0,1);
End;

Procedure DashLine(X1,Y1,X2,Y2,C: Integer);
Begin
 SetColor(C);
 SetLineStyle(UserBitLn,$F0F0,1);
 Line(X1,Y1,X2,Y2);
 SetLineStyle(SolidLn,0,1);
End;

{ Bouton blanc a double contour (le bouton par defaut est plus epais) }
Procedure Button(X1,Y1,X2,Y2: Integer; Const S: String; Hot,Enabled: Boolean);
Var TX: Integer;
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 If Hot Then Begin
  Frame(X1+1,Y1+1,X2-1,Y2-1);
  Frame(X1+2,Y1+2,X2-2,Y2-2);
 End;
 TX:=(X1+X2+1-TextW(S)) Div 2;
 If Enabled Then PText(TX,(Y1+Y2-6) Div 2,S) Else GreyText(TX,(Y1+Y2-6) Div 2,S);
End;

{ Fond de bureau tramé (damier) }
Procedure Desktop(X1,Y1,X2,Y2: Integer);
Var Y: Integer;
Begin
 Box(X1,Y1,X2,Y2,INK);
 SetColor(PAPER);
 For Y:=Y1 To Y2 Do Begin
  If Odd(Y) Then SetLineStyle(UserBitLn,$AAAA,1) Else SetLineStyle(UserBitLn,$5555,1);
  Line(X1,Y,X2,Y);
 End;
 SetLineStyle(SolidLn,0,1);
End;

{ ---- capture de la police 8x8 par defaut ---- }
Procedure CaptureFont;
Var C,R,X,W: Integer; B: Byte; S: String;
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
 { largeurs proportionnelles }
 For C:=0 To 255 Do Begin
  W:=0;
  For R:=0 To 7 Do
   For X:=0 To 7 Do
    If (FontBits[C,R] And (128 Shr X))<>0 Then
     If X+1>W Then W:=X+1;
  If (W=0) Or (C=32) Then GW[C]:=4 Else GW[C]:=W+1;
 End;
End;

{ Texte agrandi avec la police bitmap (logo, titres) }
Procedure BigText(X,Y,Scale: Integer; Const S: String; Col: Integer; Bold: Boolean);
Var I,R,C: Integer; B: Byte;
Begin
 SetFillStyle(SolidFill,Col);
 For I:=1 To Length(S) Do Begin
  For R:=0 To 7 Do Begin
   B:=FontBits[Ord(S[I]),R];
   For C:=0 To 7 Do
    If (B And (128 Shr C))<>0 Then Begin
     Bar(X+C*Scale,Y+R*Scale,X+C*Scale+Scale-1+Ord(Bold),Y+R*Scale+Scale-1);
    End;
  End;
  X:=X+8*Scale;
 End;
End;

{ ---- remplissage de polygone avec une trame (PolyP, N points) ---- }

Procedure PatSpan(Y,XA,XB: Integer; Pat: Integer);
Var X,Run: Integer; B: Byte; Bit: Boolean;
Begin
 If XA<0 Then XA:=0;
 If XB>ClipW-1 Then XB:=ClipW-1;
 If XA>XB Then Exit;
 If Pat<=1 Then Begin
  Line(XA,Y,XB,Y);
  Exit;
 End;
 B:=FillPats[Pat][(Y+PatOY) And 7];
 Run:=-1;
 For X:=XA To XB+1 Do Begin
  If X<=XB Then Bit:=((B Shr (7-((X+PatOX) And 7))) And 1)<>0 Else Bit:=False;
  If Bit Then Begin
   If Run<0 Then Run:=X;
  End Else If Run>=0 Then Begin
   Line(Run,Y,X-1,Y);
   Run:=-1;
  End;
 End;
End;

{ Pat : 1 = plein, 2..NPAT = trames ; Col = couleur de la trame }
Procedure FillPolyPat(N: Integer; Pat: Integer; Col: Integer);
Var Y,Y0,Y1,I,J,K,NX,T: Integer; XS: Array[0..63] Of Integer;
    P1,P2: PointType; X: Double;
Begin
 If N<3 Then Exit;
 Y0:=32000;Y1:=-32000;
 For I:=1 To N Do Begin
  If PolyP[I].Y<Y0 Then Y0:=PolyP[I].Y;
  If PolyP[I].Y>Y1 Then Y1:=PolyP[I].Y;
 End;
 If Y0<0 Then Y0:=0;
 If Y1>ClipH-1 Then Y1:=ClipH-1;
 SetColor(Col);
 SetLineStyle(SolidLn,0,1);
 For Y:=Y0 To Y1 Do Begin
  NX:=0;
  For I:=1 To N Do Begin
   J:=I+1;
   If J>N Then J:=1;
   P1:=PolyP[I];P2:=PolyP[J];
   If ((P1.Y<=Y) And (P2.Y>Y)) Or ((P2.Y<=Y) And (P1.Y>Y)) Then Begin
    X:=P1.X+(Y-P1.Y)*(P2.X-P1.X)/(P2.Y-P1.Y);
    If NX<64 Then Begin XS[NX]:=Round(X);Inc(NX);End;
   End;
  End;
  For I:=1 To NX-1 Do
   For J:=I DownTo 1 Do
    If XS[J]<XS[J-1] Then Begin T:=XS[J];XS[J]:=XS[J-1];XS[J-1]:=T;End;
  K:=0;
  While K+1<NX Do Begin
   PatSpan(Y,XS[K],XS[K+1]-1,Pat);
   Inc(K,2);
  End;
 End;
End;

Procedure OutlinePoly(N: Integer; Closed: Boolean; Col,Thick: Integer);
Var I,J: Integer;
Begin
 SetColor(Col);
 If Thick>1 Then SetLineStyle(SolidLn,0,ThickWidth) Else SetLineStyle(SolidLn,0,NormWidth);
 For I:=1 To N-1 Do
  Line(PolyP[I].X,PolyP[I].Y,PolyP[I+1].X,PolyP[I+1].Y);
 If Closed And (N>2) Then
  Line(PolyP[N].X,PolyP[N].Y,PolyP[1].X,PolyP[1].Y);
 SetLineStyle(SolidLn,0,NormWidth);
End;

{ ====================================================================== }
{                       POLICES (simulees) ET TEXTE                      }
{ ====================================================================== }

Const
 FontHS: Array[1..NFONT] Of Double = (1.0,0.92,1.0,0.72,1.38,1.0);

Function FontName(F: Integer): String;
Begin
 Case F Of
  1: FontName:='Roman';
  2: FontName:='Swiss';
  3: FontName:='Courier';
  4: FontName:='Narrow';
  5: FontName:='Wide';
  Else FontName:='Script';
 End;
End;

Var
 TxHx,TxHy: Double;      { mm par pixel de la police (horizontal / vertical) }
 TxFixed,TxBold: Boolean;

Procedure SetMetrics(F: PFrame);
Begin
 TxHy:=F^.Size*PT_MM/8;
 TxHx:=TxHy*FontHS[F^.Font];
 TxFixed:=(F^.Font=3);
 TxBold:=(F^.Style And ST_BOLD)<>0;
End;

Function AdvOf(C: Char): Double;
Var W: Double;
Begin
 If TxFixed Then W:=7 Else W:=GW[Ord(C)];
 If TxBold Then W:=W+0.6;
 AdvOf:=W*TxHx;
End;

{ ====================================================================== }
{                  MODELE : CADRES, GEOMETRIE, FORMES                    }
{ ====================================================================== }

Var
 TrigAng: Double;
 UndoOn: Boolean;

Procedure SetTrig(A: Double);
Begin
 If (A<>TrigAng) Or (TrigC=0) Then Begin
  TrigAng:=A;
  TrigC:=Cos(A*Pi/180);
  TrigS:=Sin(A*Pi/180);
 End;
End;

Procedure LocToWorld(F: PFrame; U,V: Double; Var WX,WY: Double);
Var DX,DY: Double;
Begin
 SetTrig(F^.Ang);
 DX:=U-F^.W/2;DY:=V-F^.H/2;
 WX:=F^.X+F^.W/2+DX*TrigC-DY*TrigS;
 WY:=F^.Y+F^.H/2+DX*TrigS+DY*TrigC;
End;

Procedure WorldToLoc(F: PFrame; WX,WY: Double; Var U,V: Double);
Var DX,DY: Double;
Begin
 SetTrig(F^.Ang);
 DX:=WX-(F^.X+F^.W/2);DY:=WY-(F^.Y+F^.H/2);
 U:=DX*TrigC+DY*TrigS+F^.W/2;
 V:=-DX*TrigS+DY*TrigC+F^.H/2;
End;

Function SxL(X: Double): Integer;       { mm monde -> pixel local au canevas }
Begin
 SxL:=ToInt((X-OrgX)*Sc);
End;

Function SyL(Y: Double): Integer;
Begin
 SyL:=ToInt((Y-OrgY)*Sc);
End;

Function WxOf(PX: LongInt): Double;     { pixel ecran -> mm monde }
Begin
 WxOf:=OrgX+(PX-CVX1)/Sc;
End;

Function WyOf(PY: LongInt): Double;
Begin
 WyOf:=OrgY+(PY-CVY1)/Sc;
End;

Function SnapV(V,G: Double): Double;
Begin
 If G<=0 Then SnapV:=V Else SnapV:=Round(V/G)*G;
End;

Procedure SnapPt(Var X,Y: Double);
Var I: Integer; Best,D: Double;
Begin
 If Not GridSnap Then Exit;
 X:=SnapV(X,GridX);Y:=SnapV(Y,GridY);
 For I:=1 To NGV Do If Abs(GuideV[I]-X)<GridX*0.4 Then X:=GuideV[I];
 For I:=1 To NGH Do If Abs(GuideH[I]-Y)<GridY*0.4 Then Y:=GuideH[I];
End;

{ ---- formes des cadres graphiques ---- }
Const
 NSHAPE = 15;

Function ShapeName(S: Integer): String;
Begin
 Case S Of
  1: ShapeName:=L3('Rectangle','Rectangle','Rechteck');
  2: ShapeName:=L3('Rounded rectangle','Rectangle arrondi','Abgerundetes Rechteck');
  3: ShapeName:=L3('Chamfered rectangle','Rectangle biseaute','Abgeschr. Rechteck');
  4: ShapeName:=L3('Hexagon','Hexagone','Sechseck');
  5: ShapeName:=L3('Octagon','Octogone','Achteck');
  6: ShapeName:=L3('Rounded bar','Barre arrondie','Runder Balken');
  7: ShapeName:=L3('Diamond','Losange','Raute');
  8: ShapeName:=L3('Pentagon','Pentagone','F'#129'nfeck');
  9: ShapeName:=L3('Circle / Ellipse','Cercle / Ellipse','Kreis / Ellipse');
  10: ShapeName:=L3('Triangle up','Triangle haut','Dreieck oben');
  11: ShapeName:=L3('Triangle right','Triangle droite','Dreieck rechts');
  12: ShapeName:=L3('Star','Etoile','Stern');
  13: ShapeName:=L3('Triangle down','Triangle bas','Dreieck unten');
  14: ShapeName:=L3('Triangle left','Triangle gauche','Dreieck links');
  Else ShapeName:=L3('Burst','Explosion','Explosion');
 End;
End;

Procedure ArcPts(Var P: TPoly; Var N: Integer; CX,CY,R,A1,A2: Double; Steps: Integer);
Var I: Integer; A: Double;
Begin
 For I:=0 To Steps Do Begin
  A:=(A1+(A2-A1)*I/Steps)*Pi/180;
  If N<64 Then Begin
   Inc(N);
   P[N].X:=CX+R*Cos(A);
   P[N].Y:=CY+R*Sin(A);
  End;
 End;
End;

Procedure AddPt(Var P: TPoly; Var N: Integer; X,Y: Double);
Begin
 If N<64 Then Begin Inc(N);P[N].X:=X;P[N].Y:=Y;End;
End;

{ Polygone de la forme S dans un rectangle W x H (coordonnees locales) }
Function ShapePoly(S: Integer; W,H: Double; Var P: TPoly): Integer;
Var N,I: Integer; R,K,A,Rx,Ry,Cx,Cy: Double;
Begin
 N:=0;
 Case S Of
  1: Begin
      AddPt(P,N,0,0);AddPt(P,N,W,0);AddPt(P,N,W,H);AddPt(P,N,0,H);
     End;
  2: Begin
      R:=MinD(W,H)*0.22;
      ArcPts(P,N,W-R,R,R,-90,0,5);
      ArcPts(P,N,W-R,H-R,R,0,90,5);
      ArcPts(P,N,R,H-R,R,90,180,5);
      ArcPts(P,N,R,R,R,180,270,5);
     End;
  3: Begin
      R:=MinD(W,H)*0.22;
      AddPt(P,N,R,0);AddPt(P,N,W-R,0);AddPt(P,N,W,R);AddPt(P,N,W,H-R);
      AddPt(P,N,W-R,H);AddPt(P,N,R,H);AddPt(P,N,0,H-R);AddPt(P,N,0,R);
     End;
  4: Begin
      AddPt(P,N,W*0.25,0);AddPt(P,N,W*0.75,0);AddPt(P,N,W,H/2);
      AddPt(P,N,W*0.75,H);AddPt(P,N,W*0.25,H);AddPt(P,N,0,H/2);
     End;
  5: Begin
      K:=0.29;
      AddPt(P,N,K*W,0);AddPt(P,N,(1-K)*W,0);AddPt(P,N,W,K*H);AddPt(P,N,W,(1-K)*H);
      AddPt(P,N,(1-K)*W,H);AddPt(P,N,K*W,H);AddPt(P,N,0,(1-K)*H);AddPt(P,N,0,K*H);
     End;
  6: Begin
      R:=MinD(W,H)/2;
      If W>=H Then Begin
       ArcPts(P,N,W-R,R,R,-90,90,8);
       ArcPts(P,N,R,R,R,90,270,8);
      End Else Begin
       ArcPts(P,N,R,R,R,180,360,8);
       ArcPts(P,N,R,H-R,R,0,180,8);
      End;
     End;
  7: Begin
      AddPt(P,N,W/2,0);AddPt(P,N,W,H/2);AddPt(P,N,W/2,H);AddPt(P,N,0,H/2);
     End;
  8: Begin
      AddPt(P,N,W/2,0);AddPt(P,N,W,H*0.38);AddPt(P,N,W*0.81,H);
      AddPt(P,N,W*0.19,H);AddPt(P,N,0,H*0.38);
     End;
  9: Begin
      For I:=0 To 35 Do Begin
       A:=I*10*Pi/180;
       AddPt(P,N,W/2+W/2*Cos(A),H/2+H/2*Sin(A));
      End;
     End;
  10: Begin AddPt(P,N,W/2,0);AddPt(P,N,W,H);AddPt(P,N,0,H);End;
  11: Begin AddPt(P,N,0,0);AddPt(P,N,W,H/2);AddPt(P,N,0,H);End;
  12: Begin
       Cx:=W/2;Cy:=H*0.53;
       For I:=0 To 9 Do Begin
        A:=(-90+I*36)*Pi/180;
        If Odd(I) Then Begin Rx:=W/2*0.40;Ry:=H/2*0.40;End
        Else Begin Rx:=W/2;Ry:=H*0.53;End;
        AddPt(P,N,Cx+Rx*Cos(A),Cy+Ry*Sin(A));
       End;
      End;
  13: Begin AddPt(P,N,0,0);AddPt(P,N,W,0);AddPt(P,N,W/2,H);End;
  14: Begin AddPt(P,N,W,0);AddPt(P,N,W,H);AddPt(P,N,0,H/2);End;
  Else Begin
       For I:=0 To 23 Do Begin
        A:=(-90+I*15)*Pi/180;
        If Odd(I) Then K:=0.30+0.06*((I Mod 3)-1) Else K:=0.5;
        AddPt(P,N,W/2+W*K*Cos(A),H/2+H*K*Sin(A));
       End;
      End;
 End;
 ShapePoly:=N;
End;

{ ---- gestion des cadres ---- }

Procedure TxtGrow(F: PFrame; Need: Integer);
Var NewCap: Integer; P: PTxt;
Begin
 If Need<=F^.Cap Then Exit;
 NewCap:=F^.Cap*2;
 If NewCap<Need Then NewCap:=Need;
 If NewCap<128 Then NewCap:=128;
 If NewCap>MAXTXT Then NewCap:=MAXTXT;
 GetMem(P,NewCap);
 If F^.Txt<>Nil Then Begin
  If F^.TLen>0 Then Move(F^.Txt^,P^,F^.TLen);
  FreeMem(F^.Txt,F^.Cap);
 End;
 F^.Txt:=P;
 F^.Cap:=NewCap;
End;

Procedure TxtInsert(F: PFrame; Pos: Integer; C: Char);
Begin
 If F^.TLen>=MAXTXT Then Exit;
 TxtGrow(F,F^.TLen+1);
 If Pos<0 Then Pos:=0;
 If Pos>F^.TLen Then Pos:=F^.TLen;
 If F^.TLen>Pos Then Move(F^.Txt^[Pos],F^.Txt^[Pos+1],F^.TLen-Pos);
 F^.Txt^[Pos]:=C;
 Inc(F^.TLen);
End;

Procedure TxtDelete(F: PFrame; Pos: Integer);
Begin
 If (Pos<0) Or (Pos>=F^.TLen) Then Exit;
 If F^.TLen-Pos-1>0 Then Move(F^.Txt^[Pos+1],F^.Txt^[Pos],F^.TLen-Pos-1);
 Dec(F^.TLen);
End;

Function TxtString(F: PFrame; Max: Integer): String;
Var I,N: Integer; S: String;
Begin
 S:='';
 N:=F^.TLen;
 If N>Max Then N:=Max;
 For I:=0 To N-1 Do S:=S+F^.Txt^[I];
 TxtString:=S;
End;

Procedure TxtAppend(F: PFrame; Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do TxtInsert(F,F^.TLen,S[I]);
End;

Function RowBytes(W: Integer): Integer;
Begin
 RowBytes:=(W+7) Shr 3;
End;

Procedure BitsAlloc(F: PFrame; W,H: Integer);
Var Sz: Integer;
Begin
 If F^.Bits<>Nil Then FreeMem(F^.Bits,RowBytes(F^.BW)*F^.BH);
 F^.Bits:=Nil;F^.BW:=0;F^.BH:=0;
 If (W<1) Or (H<1) Or (W>256) Or (H>256) Then Exit;
 Sz:=RowBytes(W)*H;
 GetMem(F^.Bits,Sz);
 FillChar(F^.Bits^,Sz,0);
 F^.BW:=W;F^.BH:=H;
End;

Function BitGet(F: PFrame; X,Y: Integer): Boolean;
Begin
 BitGet:=(F^.Bits^[Y*RowBytes(F^.BW)+(X Shr 3)] And (128 Shr (X And 7)))<>0;
End;

Procedure BitSet(F: PFrame; X,Y: Integer);
Var I: Integer;
Begin
 I:=Y*RowBytes(F^.BW)+(X Shr 3);
 F^.Bits^[I]:=F^.Bits^[I] Or (128 Shr (X And 7));
End;

Function NewFrame(K: Byte): PFrame;
Var F: PFrame;
Begin
 NewFrame:=Nil;
 If NFr>=MAXFR Then Exit;
 New(F);
 FillChar(F^,SizeOf(TFrame),0);
 F^.Kind:=K;
 F^.Page:=CurPage;
 F^.Font:=CurFont;F^.Size:=CurSize;F^.Style:=CurStyle;F^.Align:=CurAlign;
 F^.LineSp:=CurLineSp;
 Inc(NFr);
 Frs[NFr]:=F;
 NewFrame:=F;
End;

Procedure FreeFrame(F: PFrame);
Begin
 If F=Nil Then Exit;
 If F^.Txt<>Nil Then FreeMem(F^.Txt,F^.Cap);
 If F^.Bits<>Nil Then FreeMem(F^.Bits,RowBytes(F^.BW)*F^.BH);
 Dispose(F);
End;

Function FrameIndex(F: PFrame): Integer;
Var I: Integer;
Begin
 FrameIndex:=0;
 For I:=1 To NFr Do If Frs[I]=F Then FrameIndex:=I;
End;

Procedure DelFrameAt(I: Integer);
Var K: Integer;
Begin
 If (I<1) Or (I>NFr) Then Exit;
 If Frs[I]=EditFr Then Begin EditFr:=Nil;Editing:=False;End;
 FreeFrame(Frs[I]);
 For K:=I To NFr-1 Do Frs[K]:=Frs[K+1];
 Dec(NFr);
End;

Procedure ClearDoc;
Begin
 While NFr>0 Do DelFrameAt(NFr);
 NGV:=0;NGH:=0;
 EditFr:=Nil;Editing:=False;
End;

Function CloneFrame(Src: PFrame): PFrame;
Var F: PFrame;
Begin
 CloneFrame:=Nil;
 F:=NewFrame(Src^.Kind);
 If F=Nil Then Exit;
 F^:=Src^;
 F^.Txt:=Nil;F^.Cap:=0;F^.Bits:=Nil;
 If Src^.Txt<>Nil Then Begin
  TxtGrow(F,Src^.TLen+1);
  If Src^.TLen>0 Then Move(Src^.Txt^,F^.Txt^,Src^.TLen);
 End;
 If Src^.Bits<>Nil Then Begin
  GetMem(F^.Bits,RowBytes(Src^.BW)*Src^.BH);
  Move(Src^.Bits^,F^.Bits^,RowBytes(Src^.BW)*Src^.BH);
 End;
 CloneFrame:=F;
End;

Function CountSel: Integer;
Var I,C: Integer;
Begin
 C:=0;
 For I:=1 To NFr Do If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then Inc(C);
 CountSel:=C;
End;

Function FirstSel: PFrame;
Var I: Integer;
Begin
 FirstSel:=Nil;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then Begin FirstSel:=Frs[I];Exit;End;
End;

Procedure DeselectAll;
Var I: Integer;
Begin
 For I:=1 To NFr Do Frs[I]^.Sel:=False;
End;

Function PageFrames(P: Integer): Integer;
Var I,C: Integer;
Begin
 C:=0;
 For I:=1 To NFr Do If Frs[I]^.Page=P Then Inc(C);
 PageFrames:=C;
End;

{ boite englobante (monde) d'un cadre }
Procedure FrameBBox(F: PFrame; Var X1,Y1,X2,Y2: Double);
Var I: Integer; WX,WY: Double;
Begin
 X1:=1E9;Y1:=1E9;X2:=-1E9;Y2:=-1E9;
 For I:=0 To 3 Do Begin
  LocToWorld(F,(I And 1)*F^.W,(I Shr 1)*F^.H,WX,WY);
  If WX<X1 Then X1:=WX;If WX>X2 Then X2:=WX;
  If WY<Y1 Then Y1:=WY;If WY>Y2 Then Y2:=WY;
 End;
End;

Function PointInPoly(N: Integer; PX,PY: Double; Var P: TPoly): Boolean;
Var I,J: Integer; In1: Boolean;
Begin
 In1:=False;
 J:=N;
 For I:=1 To N Do Begin
  If ((P[I].Y>PY)<>(P[J].Y>PY)) And
     (PX<(P[J].X-P[I].X)*(PY-P[I].Y)/(P[J].Y-P[I].Y)+P[I].X) Then In1:=Not In1;
  J:=I;
 End;
 PointInPoly:=In1;
End;

Function DistSeg(PX,PY,X1,Y1,X2,Y2: Double): Double;
Var DX,DY,L2,T: Double;
Begin
 DX:=X2-X1;DY:=Y2-Y1;L2:=DX*DX+DY*DY;
 If L2<1E-9 Then Begin DistSeg:=Sqrt((PX-X1)*(PX-X1)+(PY-Y1)*(PY-Y1));Exit;End;
 T:=((PX-X1)*DX+(PY-Y1)*DY)/L2;
 If T<0 Then T:=0;
 If T>1 Then T:=1;
 DistSeg:=Sqrt((PX-X1-T*DX)*(PX-X1-T*DX)+(PY-Y1-T*DY)*(PY-Y1-T*DY));
End;

Function HitFrame(F: PFrame; WX,WY: Double): Boolean;
Var U,V,X1,Y1,X2,Y2,Tol: Double; P: TPoly; N: Integer;
Begin
 HitFrame:=False;
 Tol:=3/Sc;
 If F^.Kind=FK_LINE Then Begin
  If F^.Flip Then Begin
   LocToWorld(F,0,F^.H,X1,Y1);LocToWorld(F,F^.W,0,X2,Y2);
  End Else Begin
   LocToWorld(F,0,0,X1,Y1);LocToWorld(F,F^.W,F^.H,X2,Y2);
  End;
  HitFrame:=DistSeg(WX,WY,X1,Y1,X2,Y2)<=Tol;
  Exit;
 End;
 WorldToLoc(F,WX,WY,U,V);
 If (U<-Tol) Or (V<-Tol) Or (U>F^.W+Tol) Or (V>F^.H+Tol) Then Exit;
 If (F^.Kind=FK_SHAPE) And (F^.Fill<>0) Then Begin
  N:=ShapePoly(F^.Shape,F^.W,F^.H,P);
  HitFrame:=PointInPoly(N,U,V,P);
 End Else If (F^.Kind=FK_SHAPE) Then Begin
  { cadre sans remplissage : seulement pres du contour }
  HitFrame:=True;
 End Else HitFrame:=True;
End;

Function FrameAt(WX,WY: Double): PFrame;
Var I: Integer;
Begin
 FrameAt:=Nil;
 For I:=NFr DownTo 1 Do
  If (Frs[I]^.Page=CurPage) And HitFrame(Frs[I],WX,WY) Then Begin
   FrameAt:=Frs[I];Exit;
  End;
End;

{ ====================================================================== }
{                       MISE EN PAGE DU TEXTE                            }
{ ====================================================================== }

Function LineH(F: PFrame): Double;
Begin
 LineH:=F^.Size*PT_MM*1.2*F^.LineSp/100;
End;

Procedure Layout(F: PFrame);
Var Start,J,LastSp,EndI: Integer; Lw,LastW,W,Avail: Double; C: Char;
    Done,Hard: Boolean;
Begin
 SetMetrics(F);
 NLn:=0;
 Avail:=F^.W-2*TPAD;
 If Avail<1 Then Avail:=1;
 Start:=0;
 Repeat
  Lw:=0;J:=Start;LastSp:=-1;LastW:=0;Hard:=False;Done:=False;
  While True Do Begin
   If J>=F^.TLen Then Begin Done:=True;EndI:=J;Break;End;
   C:=F^.Txt^[J];
   If C=#13 Then Begin Hard:=True;EndI:=J;Break;End;
   W:=AdvOf(C);
   If (Lw+W>Avail+0.0001) And (J>Start) Then Begin
    If LastSp>=Start Then Begin EndI:=LastSp+1;Lw:=LastW;End Else EndI:=J;
    Break;
   End;
   Lw:=Lw+W;
   If C=' ' Then Begin LastSp:=J;LastW:=Lw;End;
   Inc(J);
  End;
  If NLn<MAXLN Then Begin
   Inc(NLn);
   LnS[NLn]:=Start;
   LnL[NLn]:=EndI-Start;
   { largeur sans les espaces de fin }
   J:=EndI-1;
   While (J>=Start) And (F^.Txt^[J]=' ') Do Begin
    Lw:=Lw-AdvOf(' ');Dec(J);
   End;
   If Lw<0 Then Lw:=0;
   LnWd[NLn]:=Lw;
   LnPar[NLn]:=Hard Or Done;
   If Hard Then LnN[NLn]:=EndI+1 Else If Done Then LnN[NLn]:=F^.TLen+1 Else LnN[NLn]:=EndI;
  End Else Done:=True;
  If Hard Then Start:=EndI+1 Else Start:=EndI;
 Until Done;
End;

{ position X locale du debut de la ligne N selon l'alignement }
Function LineX0(F: PFrame; N: Integer): Double;
Var Avail: Double;
Begin
 Avail:=F^.W-2*TPAD;
 Case F^.Align Of
  1: LineX0:=TPAD+(Avail-LnWd[N])/2;
  2: LineX0:=TPAD+Avail-LnWd[N];
  Else LineX0:=TPAD;
 End;
End;

Function LineSpaces(F: PFrame; N: Integer): Integer;
Var I,C,E: Integer;
Begin
 C:=0;
 E:=LnS[N]+LnL[N]-1;
 While (E>=LnS[N]) And (F^.Txt^[E]=' ') Do Dec(E);
 For I:=LnS[N] To E Do If F^.Txt^[I]=' ' Then Inc(C);
 LineSpaces:=C;
End;

{ espace supplementaire par blanc (justification) }
Function JustExtra(F: PFrame; N: Integer): Double;
Var S: Integer;
Begin
 JustExtra:=0;
 If (F^.Align<>3) Or LnPar[N] Then Exit;
 S:=LineSpaces(F,N);
 If S>0 Then JustExtra:=((F^.W-2*TPAD)-LnWd[N])/S;
End;

{ ligne contenant la position P }
Function LineOfPos(P: Integer): Integer;
Var N: Integer;
Begin
 LineOfPos:=NLn;
 For N:=1 To NLn Do
  If (P>=LnS[N]) And (P<LnN[N]) Then Begin LineOfPos:=N;Exit;End;
End;

Function CaretX(F: PFrame; N,P: Integer): Double;
Var I: Integer; X,Ex: Double;
Begin
 X:=LineX0(F,N);
 Ex:=JustExtra(F,N);
 For I:=LnS[N] To P-1 Do Begin
  If I>=F^.TLen Then Break;
  If F^.Txt^[I]=#13 Then Break;
  X:=X+AdvOf(F^.Txt^[I]);
  If F^.Txt^[I]=' ' Then X:=X+Ex;
 End;
 CaretX:=X;
End;

{ position de caractere la plus proche d'un point local }
Function PosAtLocal(F: PFrame; U,V: Double): Integer;
Var N,I,E: Integer; X,Ex,A: Double;
Begin
 Layout(F);
 N:=Trunc((V-TPAD)/LineH(F))+1;
 If N<1 Then N:=1;
 If N>NLn Then N:=NLn;
 X:=LineX0(F,N);Ex:=JustExtra(F,N);
 E:=LnS[N]+LnL[N];
 PosAtLocal:=E;
 For I:=LnS[N] To E-1 Do Begin
  A:=AdvOf(F^.Txt^[I]);
  If F^.Txt^[I]=' ' Then A:=A+Ex;
  If U<X+A/2 Then Begin PosAtLocal:=I;Exit;End;
  X:=X+A;
 End;
 If (E>LnS[N]) And (LnN[N]=E) And (F^.Txt^[E-1]=' ') Then PosAtLocal:=E-1;
End;

{ ====================================================================== }
{                       AFFICHAGE DES CADRES / CANEVAS                   }
{ ====================================================================== }

Var
 SelBoxOn: Boolean;
 CaretOn: Boolean;

{ Remplit PolyP avec le contour d'un cadre (pixels locaux au canevas) }
Procedure BuildPoly(F: PFrame; DX,DY: Double; Var N: Integer);
Var P: TPoly; I: Integer; WX,WY: Double;
Begin
 If F^.Kind=FK_SHAPE Then N:=ShapePoly(F^.Shape,F^.W,F^.H,P)
 Else Begin
  N:=4;
  P[1].X:=0;P[1].Y:=0;P[2].X:=F^.W;P[2].Y:=0;
  P[3].X:=F^.W;P[3].Y:=F^.H;P[4].X:=0;P[4].Y:=F^.H;
 End;
 For I:=1 To N Do Begin
  LocToWorld(F,P[I].X,P[I].Y,WX,WY);
  PolyP[I].X:=SxL(WX+DX);
  PolyP[I].Y:=SyL(WY+DY);
 End;
End;

{ Rectangle plein en coordonnees locales du cadre (mm), decale en pixels }
Procedure QuadFill(F: PFrame; U1,V1,U2,V2: Double; Col,OX,OY: Integer);
Var XA,XB,YA,YB: Integer; WX,WY: Double; I: Integer;
Begin
 If F^.Ang=0 Then Begin
  XA:=ToInt((F^.X+U1-OrgX)*Sc)+OX;XB:=ToInt((F^.X+U2-OrgX)*Sc)-1+OX;
  YA:=ToInt((F^.Y+V1-OrgY)*Sc)+OY;YB:=ToInt((F^.Y+V2-OrgY)*Sc)-1+OY;
  If XB<XA Then XB:=XA;
  If YB<YA Then YB:=YA;
  If (XB<0) Or (YB<0) Or (XA>=CvW) Or (YA>=CvH) Then Exit;
  Box(XA,YA,XB,YB,Col);
 End Else Begin
  For I:=0 To 3 Do Begin
   Case I Of
    0: LocToWorld(F,U1,V1,WX,WY);
    1: LocToWorld(F,U2,V1,WX,WY);
    2: LocToWorld(F,U2,V2,WX,WY);
    Else LocToWorld(F,U1,V2,WX,WY);
   End;
   PolyP[I+1].X:=SxL(WX)+OX;PolyP[I+1].Y:=SyL(WY)+OY;
  End;
  FillPolyPat(4,1,Col);
 End;
End;

Procedure GlyphDraw(F: PFrame; C: Char; U,V: Double; Col,OX,OY: Integer;
                    Slant,Ext: Double);
Var R,X,X1: Integer; B: Byte; U1,U2,V1,V2,Sh: Double;
Begin
 For R:=0 To 7 Do Begin
  B:=FontBits[Ord(C),R];
  If B=0 Then Continue;
  Sh:=(7-R)*TxHy*Slant;
  V1:=V+R*TxHy;V2:=V1+TxHy;
  X:=0;
  While X<8 Do Begin
   If (B And (128 Shr X))<>0 Then Begin
    X1:=X;
    While (X<7) And ((B And (128 Shr (X+1)))<>0) Do Inc(X);
    U1:=U+Sh+X1*TxHx;U2:=U+Sh+(X+1)*TxHx+Ext;
    QuadFill(F,U1,V1,U2,V2,Col,OX,OY);
   End;
   Inc(X);
  End;
 End;
End;

Procedure LineChars(F: PFrame; N: Integer; Y: Double; Col,OX,OY: Integer;
                    Slant,Ext: Double);
Var I: Integer; X,Ex: Double; C: Char;
Begin
 X:=LineX0(F,N);Ex:=JustExtra(F,N);
 For I:=LnS[N] To LnS[N]+LnL[N]-1 Do Begin
  C:=F^.Txt^[I];
  If C=#13 Then Break;
  If C<>' ' Then GlyphDraw(F,C,X,Y,Col,OX,OY,Slant,Ext);
  X:=X+AdvOf(C);
  If C=' ' Then X:=X+Ex;
 End;
End;

Procedure DrawFrameText(F: PFrame);
Var N,K,NS,WX1,WY1,WX2,WY2: Integer; Y,LH,PxH,Slant,Ext,X0,A,B: Double;
    Over: Boolean; X1,Y1,X2,Y2: Double;
Begin
 Layout(F);
 LH:=LineH(F);
 PxH:=TxHy*Sc;
 Slant:=0;
 If ((F^.Style And ST_ITALIC)<>0) Or (F^.Font=6) Then Slant:=0.25;
 If TxBold Then Ext:=TxHx*0.55 Else Ext:=0;
 Over:=False;
 For N:=1 To NLn Do Begin
  If (N>1) And (TPAD+N*LH>F^.H+0.01) Then Begin Over:=True;Break;End;
  Y:=TPAD+(N-1)*LH+(LH-8*TxHy)/2;
  If LnL[N]>0 Then Begin
   If PxH<0.8 Then Begin
    { texte trop petit : trait gris }
    X0:=LineX0(F,N);
    LocToWorld(F,X0,Y+4*TxHy,X1,Y1);
    LocToWorld(F,X0+LnWd[N],Y+4*TxHy,X2,Y2);
    SetColor(GREY);SetLineStyle(SolidLn,0,1);
    Line(SxL(X1),SyL(Y1),SxL(X2),SyL(Y2));
   End Else Begin
    If (F^.Style And ST_SHADOW)<>0 Then Begin
     NS:=Clamp(Round(PxH*0.9),1,5);
     For K:=NS DownTo 1 Do LineChars(F,N,Y,GREY,K,K,Slant,Ext);
    End;
    If (F^.Style And ST_OUTLINE)<>0 Then Begin
     LineChars(F,N,Y,INK,-1,-1,Slant,Ext);LineChars(F,N,Y,INK,1,-1,Slant,Ext);
     LineChars(F,N,Y,INK,-1,1,Slant,Ext);LineChars(F,N,Y,INK,1,1,Slant,Ext);
     LineChars(F,N,Y,INK,-1,0,Slant,Ext);LineChars(F,N,Y,INK,1,0,Slant,Ext);
     LineChars(F,N,Y,INK,0,-1,Slant,Ext);LineChars(F,N,Y,INK,0,1,Slant,Ext);
     LineChars(F,N,Y,PAPER,0,0,Slant,Ext);
    End Else LineChars(F,N,Y,INK,0,0,Slant,Ext);
   End;
   If ((F^.Style And ST_UNDER)<>0) And (LnWd[N]>0) Then Begin
    X0:=LineX0(F,N);
    QuadFill(F,X0,Y+8.2*TxHy,X0+LnWd[N]+JustExtra(F,N)*LineSpaces(F,N),
             Y+8.2*TxHy+MaxD(TxHy*0.9,1/Sc),INK,0,0);
   End;
  End;
 End;
 If Over Then Begin
  { indicateur de debordement : petit triangle noir dans le coin }
  LocToWorld(F,F^.W,F^.H,X1,Y1);
  A:=SxL(X1);B:=SyL(Y1);
  PolyP[1].X:=ToInt(A);PolyP[1].Y:=ToInt(B);
  PolyP[2].X:=ToInt(A)-8;PolyP[2].Y:=ToInt(B);
  PolyP[3].X:=ToInt(A);PolyP[3].Y:=ToInt(B)-8;
  FillPolyPat(3,1,INK);
 End;
End;

Procedure DrawRasterFrame(F: PFrame);
Var X1,Y1,X2,Y2,SX,SY,RX,RY,W,H,Run,XL,XH,YL,YH: Integer; Bit: Boolean;
Begin
 X1:=SxL(F^.X);Y1:=SyL(F^.Y);X2:=SxL(F^.X+F^.W)-1;Y2:=SyL(F^.Y+F^.H)-1;
 W:=X2-X1+1;H:=Y2-Y1+1;
 If (W<1) Or (H<1) Then Exit;
 If F^.Bits=Nil Then Begin
  DotLine(X1,Y1,X2,Y2,INK);
  DotLine(X1,Y2,X2,Y1,INK);
  Exit;
 End;
 SetColor(INK);SetLineStyle(SolidLn,0,1);
 XL:=Max2(X1,0);XH:=Min2(X2,CvW-1);
 YL:=Max2(Y1,0);YH:=Min2(Y2,CvH-1);
 For SY:=YL To YH Do Begin
  RY:=(LongInt(SY-Y1)*F^.BH) Div H;
  Run:=-1;
  For SX:=XL To XH+1 Do Begin
   If SX<=XH Then Begin
    RX:=(LongInt(SX-X1)*F^.BW) Div W;
    Bit:=BitGet(F,RX,RY);
   End Else Bit:=False;
   If Bit Then Begin
    If Run<0 Then Run:=SX;
   End Else If Run>=0 Then Begin
    Line(Run,SY,SX-1,SY);
    Run:=-1;
   End;
  End;
 End;
End;

Procedure DrawLineFrame(F: PFrame; DX,DY: Double; Col: Integer);
Var X1,Y1,X2,Y2: Double; Wd: Integer;
Begin
 If F^.Flip Then Begin
  LocToWorld(F,0,F^.H,X1,Y1);LocToWorld(F,F^.W,0,X2,Y2);
 End Else Begin
  LocToWorld(F,0,0,X1,Y1);LocToWorld(F,F^.W,F^.H,X2,Y2);
 End;
 SetColor(Col);
 Wd:=Round(F^.LineW/10*Sc);
 If Wd>=2 Then SetLineStyle(SolidLn,0,ThickWidth) Else SetLineStyle(SolidLn,0,NormWidth);
 Line(SxL(X1+DX),SyL(Y1+DY),SxL(X2+DX),SyL(Y2+DY));
 SetLineStyle(SolidLn,0,NormWidth);
End;

Procedure DrawFrameObj(F: PFrame);
Var N,I,J: Integer; Thick: Integer;
Begin
 If F^.Kind=FK_LINE Then Begin
  If F^.Shadow Then DrawLineFrame(F,1.5,1.5,GREY);
  DrawLineFrame(F,0,0,INK);
  Exit;
 End;
 If F^.Shadow And ((F^.Fill<>0) Or (F^.LineW>0)) Then Begin
  BuildPoly(F,1.5,1.5,N);
  FillPolyPat(N,1,INK);
 End;
 BuildPoly(F,0,0,N);
 If F^.Fill=1 Then FillPolyPat(N,1,PAPER)
 Else If F^.Fill>=2 Then Begin
  FillPolyPat(N,1,PAPER);
  FillPolyPat(N,F^.Fill-1,INK);
 End;
 If F^.LineW>0 Then Begin
  Thick:=Round(F^.LineW/10*Sc);
  OutlinePoly(N,True,INK,Thick);
 End Else If ShowFrames And ((F^.Kind=FK_TEXT) Or (F^.Kind=FK_RASTER)) Then Begin
  For I:=1 To N Do Begin
   J:=I+1;If J>N Then J:=1;
   DotLine(PolyP[I].X,PolyP[I].Y,PolyP[J].X,PolyP[J].Y,GREY);
  End;
 End;
 If F^.Kind=FK_TEXT Then DrawFrameText(F)
 Else If F^.Kind=FK_RASTER Then DrawRasterFrame(F);
End;

{ Texte libre positionne (numero de page) }
Procedure DrawLabelMm(Const S: String; X,Y,W,Size: Double);
Var T: TFrame; I: Integer;
Begin
 FillChar(T,SizeOf(T),0);
 T.Kind:=FK_TEXT;T.X:=X;T.Y:=Y;T.W:=W;T.H:=Size*PT_MM*2;
 T.Font:=1;T.Size:=Size;T.Align:=1;T.LineSp:=100;
 TxtGrow(@T,Length(S)+1);
 For I:=1 To Length(S) Do TxtInsert(@T,T.TLen,S[I]);
 DrawFrameText(@T);
 If T.Txt<>Nil Then FreeMem(T.Txt,T.Cap);
End;

Procedure HandlePos(F: PFrame; I: Integer; Var WX,WY: Double);
Var HX,HY: Integer;
Begin
 Case I Of
  1: Begin HX:=-1;HY:=-1;End;
  2: Begin HX:=0;HY:=-1;End;
  3: Begin HX:=1;HY:=-1;End;
  4: Begin HX:=1;HY:=0;End;
  5: Begin HX:=1;HY:=1;End;
  6: Begin HX:=0;HY:=1;End;
  7: Begin HX:=-1;HY:=1;End;
  Else Begin HX:=-1;HY:=0;End;
 End;
 LocToWorld(F,(HX+1)*F^.W/2,(HY+1)*F^.H/2,WX,WY);
End;

Procedure DrawSelection;
Var I,K,N,J,X,Y: Integer; F: PFrame; WX,WY: Double; One: Boolean;
Begin
 One:=CountSel=1;
 For I:=1 To NFr Do Begin
  F:=Frs[I];
  If F^.Sel And (F^.Page=CurPage) Then Begin
   BuildPoly(F,0,0,N);
   If F^.Kind<>FK_SHAPE Then Begin
    For K:=1 To 4 Do Begin
     J:=K+1;If J>4 Then J:=1;
     DashLine(PolyP[K].X,PolyP[K].Y,PolyP[J].X,PolyP[J].Y,INK);
    End;
   End Else Begin
    LocToWorld(F,0,0,WX,WY);
    PolyP[1].X:=SxL(WX);PolyP[1].Y:=SyL(WY);
    LocToWorld(F,F^.W,0,WX,WY);PolyP[2].X:=SxL(WX);PolyP[2].Y:=SyL(WY);
    LocToWorld(F,F^.W,F^.H,WX,WY);PolyP[3].X:=SxL(WX);PolyP[3].Y:=SyL(WY);
    LocToWorld(F,0,F^.H,WX,WY);PolyP[4].X:=SxL(WX);PolyP[4].Y:=SyL(WY);
    For K:=1 To 4 Do Begin
     J:=K+1;If J>4 Then J:=1;
     DashLine(PolyP[K].X,PolyP[K].Y,PolyP[J].X,PolyP[J].Y,INK);
    End;
   End;
   If One And (F^.Kind<>FK_LINE) Then
    For K:=1 To 8 Do Begin
     HandlePos(F,K,WX,WY);
     X:=SxL(WX);Y:=SyL(WY);
     Box(X-3,Y-3,X+3,Y+3,INK);
     Box(X-1,Y-1,X+1,Y+1,PAPER);
    End
   Else If One Then Begin
    HandlePos(F,1,WX,WY);
    If F^.Flip Then LocToWorld(F,0,F^.H,WX,WY) Else LocToWorld(F,0,0,WX,WY);
    X:=SxL(WX);Y:=SyL(WY);Box(X-3,Y-3,X+3,Y+3,INK);
    If F^.Flip Then LocToWorld(F,F^.W,0,WX,WY) Else LocToWorld(F,F^.W,F^.H,WX,WY);
    X:=SxL(WX);Y:=SyL(WY);Box(X-3,Y-3,X+3,Y+3,INK);
   End;
  End;
 End;
End;

Procedure DrawCaret;
Var N: Integer; X,Y,LH,X1,Y1,X2,Y2: Double;
Begin
 If (Not Editing) Or (EditFr=Nil) Or (EditFr^.Page<>CurPage) Then Exit;
 Layout(EditFr);
 N:=LineOfPos(CurPos);
 LH:=LineH(EditFr);
 X:=CaretX(EditFr,N,CurPos);
 Y:=TPAD+(N-1)*LH;
 LocToWorld(EditFr,X,Y,X1,Y1);
 LocToWorld(EditFr,X,Y+LH,X2,Y2);
 SetColor(INK);SetLineStyle(SolidLn,0,1);
 Line(SxL(X1),SyL(Y1),SxL(X2),SyL(Y2));
 Line(SxL(X1)+1,SyL(Y1),SxL(X2)+1,SyL(Y2));
End;

Procedure DrawGridDots;
Var X,Y: Double; PX,PY: Integer;
Begin
 If (GridX*Sc<5) Or (GridY*Sc<5) Then Exit;
 X:=Int(OrgX/GridX)*GridX;
 While X<=OrgX+CvW/Sc Do Begin
  PX:=SxL(X);
  If (X>=0) And (X<=PageW) Then Begin
   Y:=Int(OrgY/GridY)*GridY;
   While Y<=OrgY+CvH/Sc Do Begin
    PY:=SyL(Y);
    If (Y>=0) And (Y<=PageH) And (PX>=0) And (PX<CvW) And (PY>=0) And (PY<CvH)
      Then PutPixel(PX,PY,INK);
    Y:=Y+GridY;
   End;
  End;
  X:=X+GridX;
 End;
End;

Procedure PageMargins(Var L,R,T,B: Double);
Begin
 L:=MarL;R:=MarR;T:=MarT;B:=MarB;
 If MirrorMar And DoublePg And Not Odd(CurPage) Then Begin L:=MarR;R:=MarL;End;
End;

Procedure DrawCanvas;
Var I,P1X,P1Y,P2X,P2Y,K: Integer; L,R,T,B: Double;
Begin
 SetViewPort(CVX1,CVY1,CVX2,CVY2,True);
 CvW:=CVX2-CVX1+1;CvH:=CVY2-CVY1+1;
 ClipW:=CvW;ClipH:=CvH;
 PatOX:=ToInt(OrgX*Sc) And 7;PatOY:=ToInt(OrgY*Sc) And 7;
 Desktop(0,0,CvW-1,CvH-1);
 P1X:=SxL(0);P1Y:=SyL(0);P2X:=SxL(PageW);P2Y:=SyL(PageH);
 Box(P1X+3,P1Y+3,P2X+3,P2Y+3,INK);
 Box(P1X,P1Y,P2X,P2Y,PAPER);
 SetColor(INK);SetLineStyle(SolidLn,0,1);
 Rectangle(P1X,P1Y,P2X,P2Y);
 If ShowMargins Then Begin
  PageMargins(L,R,T,B);
  DotLine(SxL(L),SyL(T),SxL(PageW-R),SyL(T),INK);
  DotLine(SxL(PageW-R),SyL(T),SxL(PageW-R),SyL(PageH-B),INK);
  DotLine(SxL(PageW-R),SyL(PageH-B),SxL(L),SyL(PageH-B),INK);
  DotLine(SxL(L),SyL(PageH-B),SxL(L),SyL(T),INK);
 End;
 If GridShow Then DrawGridDots;
 For K:=1 To NGV Do
  DashLine(SxL(GuideV[K]),0,SxL(GuideV[K]),CvH-1,GREY);
 For K:=1 To NGH Do
  DashLine(0,SyL(GuideH[K]),CvW-1,SyL(GuideH[K]),GREY);
 For I:=1 To NFr Do
  If Frs[I]^.Page=CurPage Then DrawFrameObj(Frs[I]);
 If PageNumbered(CurPage) And (NumTo>=NumFrom) Then Begin
  PageMargins(L,R,T,B);
  DrawLabelMm(PageLabel(CurPage),L,PageH-B*0.5-2,PageW-L-R,10);
 End;
 DrawSelection;
 DrawCaret;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
End;

{ ====================================================================== }
{                          VUE : ZOOM ET DEFILEMENT                      }
{ ====================================================================== }

Procedure ClampOrg;
Var MinX,MaxX,MinY,MaxY,VW,VH: Double;
Begin
 MinX:=-12;MaxX:=PageW+16;MinY:=-12;MaxY:=PageH+16;
 VW:=CvW/Sc;VH:=CvH/Sc;
 If MaxX-MinX<=VW Then OrgX:=(MinX+MaxX-VW)/2
 Else OrgX:=ClampD(OrgX,MinX,MaxX-VW);
 If MaxY-MinY<=VH Then OrgY:=(MinY+MaxY-VH)/2
 Else OrgY:=ClampD(OrgY,MinY,MaxY-VH);
End;

Procedure SetZoom(Z: Double);
Var CX,CY: Double;
Begin
 CX:=OrgX+CvW/Sc/2;CY:=OrgY+CvH/Sc/2;
 If Z<5 Then Z:=5;
 If Z>1600 Then Z:=1600;
 Zoom:=Z;
 Sc:=Zoom/100*(96/25.4);
 OrgX:=CX-CvW/Sc/2;OrgY:=CY-CvH/Sc/2;
 ClampOrg;
 NeedDraw:=True;
End;

Procedure ZoomFit;
Var Z1,Z2: Double;
Begin
 Z1:=(CvW-30)/PageW;Z2:=(CvH-30)/PageH;
 If Z2<Z1 Then Z1:=Z2;
 OrgX:=PageW/2;OrgY:=PageH/2;
 Zoom:=Round(Z1/(96/25.4)*1000)/10;
 If Zoom<5 Then Zoom:=5;
 Sc:=Zoom/100*(96/25.4);
 OrgX:=PageW/2-CvW/Sc/2;OrgY:=PageH/2-CvH/Sc/2;
 ClampOrg;
 NeedDraw:=True;
End;

Procedure ZoomRectMm(X1,Y1,X2,Y2: Double);
Var Z1,Z2,W,H: Double;
Begin
 W:=Abs(X2-X1);H:=Abs(Y2-Y1);
 If (W<1) Or (H<1) Then Exit;
 Z1:=CvW/W;Z2:=CvH/H;
 If Z2<Z1 Then Z1:=Z2;
 Zoom:=ClampD(Z1/(96/25.4)*100,5,1600);
 Sc:=Zoom/100*(96/25.4);
 OrgX:=(X1+X2)/2-CvW/Sc/2;OrgY:=(Y1+Y2)/2-CvH/Sc/2;
 ClampOrg;
 NeedDraw:=True;
End;

Procedure ScrollBy(DX,DY: Double);
Begin
 OrgX:=OrgX+DX;OrgY:=OrgY+DY;
 ClampOrg;
 NeedDraw:=True;
End;

{ ====================================================================== }
{                      ICONES (boite a outils / barre)                   }
{ ====================================================================== }

Const
 IC_NONE = 0;
 IC_TAB_TOOLS = 1; IC_TAB_HELP = 2; IC_TAB_GUIDE = 3; IC_TAB_FILES = 4;
 IC_TEXTFR = 10; IC_LINE = 11; IC_RASTER = 12; IC_GRID = 13; IC_SHAPES = 14;
 IC_ATTR = 15; IC_DUP = 16; IC_PAGE = 17; IC_ROTTXT = 18; IC_SHADOW = 19;
 IC_DESEL = 20; IC_SIZE = 21; IC_EDIT = 22; IC_SELECT = 23; IC_IMPORT = 24;
 IC_FRONT = 25; IC_BACK = 26; IC_TRASH = 27;
 IC_ARROW = 30; IC_IBEAM = 31; IC_A = 32; IC_ZOOM = 33; IC_DOC = 34;
 IC_PGL = 35; IC_PGR = 36;
 IC_SHAPE0 = 39;                   { 40..54 : formes }
 IC_FM1 = 60; IC_FM2 = 61; IC_FM3 = 62; IC_FM4 = 63; IC_BACKARROW = 64;
 IC_GRIDSHOW = 70; IC_SNAP = 71; IC_MARGINS = 72; IC_GV = 73; IC_GH = 74;
 IC_GCLR = 75; IC_FIT = 76; IC_ONE = 77; IC_GRIDSET = 78;
 IC_NEW = 80; IC_OPEN = 81; IC_SAVE = 82; IC_SAVEAS = 83; IC_TXTLOAD = 84;
 IC_PRINT = 85; IC_INFO = 86; IC_QUIT = 88;

Var
 IcX,IcY,IcFg,IcBg: Integer;

Procedure IL(X1,Y1,X2,Y2: Integer);
Begin
 SetColor(IcFg);SetLineStyle(SolidLn,0,1);
 Line(IcX+X1,IcY+Y1,IcX+X2,IcY+Y2);
End;

Procedure IR(X1,Y1,X2,Y2: Integer);
Begin
 SetColor(IcFg);SetLineStyle(SolidLn,0,1);
 Rectangle(IcX+X1,IcY+Y1,IcX+X2,IcY+Y2);
End;

Procedure IB(X1,Y1,X2,Y2: Integer);
Begin
 Box(IcX+X1,IcY+Y1,IcX+X2,IcY+Y2,IcFg);
End;

Procedure IW(X1,Y1,X2,Y2: Integer);
Begin
 Box(IcX+X1,IcY+Y1,IcX+X2,IcY+Y2,IcBg);
End;

Procedure IDot(X1,Y1,X2,Y2: Integer);
Begin
 DotLine(IcX+X1,IcY+Y1,IcX+X2,IcY+Y1,IcFg);
 DotLine(IcX+X2,IcY+Y1,IcX+X2,IcY+Y2,IcFg);
 DotLine(IcX+X2,IcY+Y2,IcX+X1,IcY+Y2,IcFg);
 DotLine(IcX+X1,IcY+Y2,IcX+X1,IcY+Y1,IcFg);
End;

Procedure IO(X,Y,R: Integer);
Begin
 SetColor(IcFg);SetLineStyle(SolidLn,0,1);
 Circle(IcX+X,IcY+Y,R);
End;

Procedure ITxt(X,Y: Integer; Const S: String);
Begin
 SetColor(IcFg);
 OutTextXY(IcX+X,IcY+Y,S);
End;

{ polygone a partir de points relatifs (IPS / IPA / IPE) }
Var IPN: Integer;

Procedure IPS;
Begin
 IPN:=0;
End;

Procedure IPA(X,Y: Integer);
Begin
 If IPN<64 Then Begin
  Inc(IPN);
  PolyP[IPN].X:=IcX+X;PolyP[IPN].Y:=IcY+Y;
 End;
End;

Procedure IPE(Filled: Boolean);
Begin
 If Filled Then Begin
  ClipW:=SCR_W;ClipH:=SCR_H;
  FillPolyPat(IPN,1,IcFg);
 End Else OutlinePoly(IPN,True,IcFg,1);
End;

Procedure IcRotText(Const S: String; AngDeg,Scale: Double);
Var DX,DY,SX,SY,IX,IY: Integer; C,Sn,FX,FY: Double;
Begin
 C:=Cos(AngDeg*Pi/180);Sn:=Sin(AngDeg*Pi/180);
 For DY:=-14 To 14 Do
  For DX:=-18 To 18 Do Begin
   FX:=(DX*C+DY*Sn)/Scale+Length(S)*4;
   FY:=(-DX*Sn+DY*C)/Scale+4;
   IX:=Trunc(FX);IY:=Trunc(FY);
   If (FX>=0) And (FY>=0) And (IX<Length(S)*8) And (IY<8) Then
    If (FontBits[Ord(S[IX Div 8+1]),IY] And (128 Shr (IX Mod 8)))<>0 Then
     PutPixel(IcX+DX,IcY+DY,IcFg);
  End;
End;

Procedure DrawIcon(Id,X1,Y1,X2,Y2: Integer; Inv: Boolean);
Var I,J,N,S: Integer; P: TPoly;
Begin
 If Inv Then Begin IcBg:=INK;IcFg:=PAPER;End Else Begin IcBg:=PAPER;IcFg:=INK;End;
 Box(X1,Y1,X2,Y2,IcBg);
 IcX:=(X1+X2) Div 2;IcY:=(Y1+Y2) Div 2;
 If (Id>IC_SHAPE0) And (Id<=IC_SHAPE0+NSHAPE) Then Begin
  N:=ShapePoly(Id-IC_SHAPE0,22,22,P);
  For I:=1 To N Do Begin
   PolyP[I].X:=ToInt(IcX-11+P[I].X);PolyP[I].Y:=ToInt(IcY-11+P[I].Y);
  End;
  OutlinePoly(N,True,IcFg,1);
  Exit;
 End;
 Case Id Of
  IC_TAB_TOOLS: Begin
    IO(-7,6,4);IO(7,6,4);IL(-6,3,5,-10);IL(6,3,-5,-10);
   End;
  IC_TAB_HELP: BigText(IcX-6,IcY-8,2,'?',IcFg,True);
  IC_TAB_GUIDE: Begin
    DotLine(IcX-12,IcY,IcX+12,IcY,IcFg);
    IL(-12,-4,-12,4);IL(12,-4,12,4);IL(0,-3,0,3);
   End;
  IC_TAB_FILES: Begin
    IL(-12,-7,-12,9);IL(-12,9,12,9);IL(12,9,12,-4);IL(12,-4,2,-4);
    IL(2,-4,-1,-8);IL(-1,-8,-12,-8);IL(-12,-3,12,-3);
   End;
  IC_TEXTFR: Begin
    IDot(-18,-15,18,15);ITxt(-16,-12,'ABC-');ITxt(-16,0,'DEFG');
   End;
  IC_LINE: Begin
    IDot(-17,-14,17,14);IL(-13,-10,13,10);IL(-13,-9,13,11);
   End;
  IC_RASTER: Begin
    IDot(-17,-14,17,14);
    For J:=-10 To 10 Do
     For I:=-13 To 13 Do
      If ((I+J) And 1)=0 Then PutPixel(IcX+I,IcY+J,IcFg);
   End;
  IC_GRID: Begin
    For J:=0 To 3 Do For I:=0 To 3 Do IB(-12+I*8,-12+J*8,-11+I*8,-11+J*8);
    IR(-14,-14,14,14);
   End;
  IC_SHAPES: Begin
    IO(-6,3,9);IL(-6,3,-6,-6);IL(-6,3,3,3);
    IB(8,-8,10,10);IB(13,-3,15,10);
    IL(7,11,17,11);
   End;
  IC_ATTR: Begin
    SetColor(IcFg);Ellipse(IcX,IcY,0,360,15,11);
    IB(-9,-4,-7,-2);IB(-2,-8,0,-6);IB(5,-4,7,-2);IB(-8,3,-6,5);
    Ellipse(IcX+7,IcY+5,0,360,3,2);
   End;
  IC_DUP: Begin
    IR(-15,-13,3,5);IW(-5,-3,15,14);IR(-5,-3,15,14);
   End;
  IC_PAGE: Begin
    IR(-16,-14,16,6);IR(-12,-10,12,2);IL(-7,10,7,10);IL(0,6,0,10);
   End;
  IC_ROTTXT: IcRotText('ABC',32,1.3);
  IC_SHADOW: Begin
    For I:=0 To 15 Do Begin
     If Odd(I) Then S:=5 Else S:=14;
     PolyP[I+1].X:=IcX+Round(S*Cos(I*Pi/8));
     PolyP[I+1].Y:=IcY+Round(S*Sin(I*Pi/8)*0.9);
    End;
    OutlinePoly(16,True,IcFg,1);
    IB(-2,-2,2,2);
   End;
  IC_DESEL: Begin
    IDot(-16,-14,16,14);IL(-14,-12,14,12);IL(-14,12,14,-12);
   End;
  IC_SIZE: Begin
    IDot(-16,-14,16,14);IL(-9,-8,11,10);IL(11,10,5,10);IL(11,10,11,4);
   End;
  IC_EDIT: Begin
    IDot(-17,-14,17,14);IL(-11,10,9,-10);IL(-10,11,10,-9);IL(-12,10,-12,13);
    IL(-12,13,-9,12);IL(9,-10,12,-13);
   End;
  IC_SELECT: Begin
    IDot(-17,-14,5,6);
    IPS;IPA(0,-2);IPA(0,14);IPA(4,10);IPA(8,16);IPA(11,14);IPA(7,8);IPA(12,8);IPE(True);
   End;
  IC_IMPORT: Begin
    IR(-15,-8,15,12);IB(-5,-12,5,-8);IO(0,2,6);IO(0,2,3);IB(9,-6,12,-4);
   End;
  IC_FRONT: Begin
    IR(-15,-13,3,5);IB(-5,-3,15,14);
   End;
  IC_BACK: Begin
    IB(-15,-13,3,5);IW(-5,-3,15,14);IR(-5,-3,15,14);
   End;
  IC_TRASH: Begin
    IL(-10,-8,10,-8);IL(-4,-12,4,-12);IL(-4,-12,-4,-8);IL(4,-12,4,-8);
    IL(-9,-8,-7,13);IL(9,-8,7,13);IL(-7,13,7,13);
    IL(-3,-5,-3,10);IL(0,-5,0,10);IL(3,-5,3,10);
   End;
  IC_ARROW: Begin
    IPS;IPA(-6,-14);IPA(-6,10);IPA(-2,6);IPA(2,14);IPA(5,12);IPA(1,4);IPA(7,4);IPE(True);
   End;
  IC_IBEAM: Begin
    IL(0,-12,0,12);IL(-4,-12,4,-12);IL(-4,12,4,12);IL(1,-12,1,12);
   End;
  IC_A: BigText(IcX-9,IcY-11,3,'A',IcFg,True);
  IC_ZOOM: Begin
    IO(-3,-3,9);IO(-3,-3,8);IL(4,4,13,13);IL(3,5,12,14);
   End;
  IC_DOC: Begin
    IL(-9,-13,3,-13);IL(3,-13,9,-7);IL(9,-7,9,13);IL(9,13,-9,13);IL(-9,13,-9,-13);
    IL(3,-13,3,-7);IL(3,-7,9,-7);IL(-5,-2,5,-2);IL(-5,3,5,3);IL(-5,8,5,8);
   End;
  IC_PGL: Begin
    IPS;IPA(-7,0);IPA(0,-7);IPA(7,0);IPA(0,7);IPE(False);IPS;IPA(2,-3);IPA(-3,0);IPA(2,3);IPE(True);
   End;
  IC_PGR: Begin
    IPS;IPA(-7,0);IPA(0,-7);IPA(7,0);IPA(0,7);IPE(False);IPS;IPA(-2,-3);IPA(3,0);IPA(-2,3);IPE(True);
   End;
  IC_FM1: IR(-12,-10,12,10);
  IC_FM2: Begin
    IR(-12,-10,12,10);
    For J:=-9 To 9 Do For I:=-11 To 11 Do
     If (((I+J) And 1)=0) And ((J And 1)=0) Then PutPixel(IcX+I,IcY+J,IcFg);
   End;
  IC_FM3: IB(-12,-10,12,10);
  IC_FM4: IDot(-12,-10,12,10);
  IC_BACKARROW: Begin
    IL(-12,0,12,0);IL(-12,0,-5,-6);IL(-12,0,-5,6);IL(12,0,12,-8);IL(12,-8,2,-8);
   End;
  IC_GRIDSHOW: Begin
    For J:=0 To 3 Do For I:=0 To 3 Do IB(-11+I*7,-11+J*7,-10+I*7,-10+J*7);
   End;
  IC_SNAP: Begin
    IL(-8,-12,-8,2);IL(8,-12,8,2);IL(-4,-12,-4,2);IL(4,-12,4,2);
    SetColor(IcFg);Arc(IcX,IcY+2,180,360,8);Arc(IcX,IcY+2,180,360,4);
    IB(-9,-14,-3,-11);IB(3,-14,9,-11);
   End;
  IC_MARGINS: Begin
    IR(-14,-12,14,12);IDot(-9,-7,9,7);
   End;
  IC_GV: Begin
    DashLine(IcX,IcY-13,IcX,IcY+13,IcFg);IL(-4,-9,0,-13);IL(4,-9,0,-13);
    IL(-13,0,-7,0);IL(13,0,7,0);
   End;
  IC_GH: Begin
    DashLine(IcX-13,IcY,IcX+13,IcY,IcFg);IL(9,-4,13,0);IL(9,4,13,0);
    IL(0,-13,0,-7);IL(0,13,0,7);
   End;
  IC_GCLR: Begin
    DashLine(IcX-13,IcY,IcX+13,IcY,IcFg);DashLine(IcX,IcY-13,IcX,IcY+13,IcFg);
    IL(-9,-9,9,9);IL(-9,9,9,-9);
   End;
  IC_FIT: Begin
    IR(-9,-13,9,13);IL(-14,-13,-14,13);IL(14,-13,14,13);
   End;
  IC_ONE: ITxt(-12,-3,'1:1');
  IC_GRIDSET: Begin
    BigText(IcX-6,IcY-8,2,'#',IcFg,True);
   End;
  IC_NEW: Begin
    IL(-9,-13,3,-13);IL(3,-13,9,-7);IL(9,-7,9,13);IL(9,13,-9,13);IL(-9,13,-9,-13);
    IL(3,-13,3,-7);IL(3,-7,9,-7);
   End;
  IC_OPEN: Begin
    IL(-13,-6,-13,10);IL(-13,10,9,10);IL(-13,-6,-4,-6);IL(-4,-6,-2,-9);
    IL(-2,-9,5,-9);IL(5,-9,5,-4);IL(-7,-3,14,-3);IL(-7,-3,-13,10);IL(14,-3,9,10);
   End;
  IC_SAVE: Begin
    IR(-12,-12,12,12);IB(-7,-12,6,-5);IW(2,-11,4,-6);IR(-8,1,8,12);
    IL(-5,5,5,5);IL(-5,8,5,8);
   End;
  IC_SAVEAS: Begin
    IR(-12,-12,12,12);IB(-7,-12,6,-5);IR(-8,1,8,12);ITxt(-7,3,'...');
   End;
  IC_TXTLOAD: Begin
    IR(-12,-13,12,13);ITxt(-9,-10,'ABC');ITxt(-9,-1,'DEF');ITxt(-9,7,'...');
   End;
  IC_PRINT: Begin
    IR(-14,-3,14,9);IR(-8,-12,8,-3);IR(-8,5,8,13);IL(-5,8,5,8);IB(9,0,11,2);
   End;
  IC_INFO: Begin
    IO(0,0,13);IO(0,0,12);BigText(IcX-3,IcY-8,2,'i',IcFg,True);
   End;
  IC_QUIT: Begin
    IR(-12,-13,0,13);IL(0,0,14,0);IL(14,0,9,-5);IL(14,0,9,5);IB(-4,-1,-2,1);
   End;
 End;
End;

Function IconName(Id: Integer): String;
Begin
 IconName:='';
 If (Id>IC_SHAPE0) And (Id<=IC_SHAPE0+NSHAPE) Then Begin
  IconName:=ShapeName(Id-IC_SHAPE0);Exit;
 End;
 Case Id Of
  IC_TAB_TOOLS: IconName:=L3('Main tools','Outils principaux','Hauptwerkzeuge');
  IC_TAB_HELP: IconName:=L3('Help messages','Messages d''aide','Hilfsmeldungen');
  IC_TAB_GUIDE: IconName:=L3('Guides and grid','Reperes et grille','Hilfslinien und Raster');
  IC_TAB_FILES: IconName:=L3('Files','Fichiers','Dateien');
  IC_TEXTFR: IconName:=L3('Text frame','Cadre de texte','Textrahmen');
  IC_LINE: IconName:=L3('Line','Ligne','Linie');
  IC_RASTER: IconName:=L3('Raster frame','Cadre raster','Rasterrahmen');
  IC_GRID: IconName:=L3('Grid on/off','Grille oui/non','Raster ein/aus');
  IC_SHAPES: IconName:=L3('Graphic frames','Cadres graphiques','Grafikrahmen');
  IC_ATTR: IconName:=L3('Frame attributes','Attributs de cadre','Rahmenattribute');
  IC_DUP: IconName:=L3('Duplicate frame','Dupliquer le cadre','Rahmen kopieren');
  IC_PAGE: IconName:=L3('Page format','Format de page','Seitenformat');
  IC_ROTTXT: IconName:=L3('Rotated text','Texte tourne','Gedrehter Text');
  IC_SHADOW: IconName:=L3('Shadow on/off','Ombre oui/non','Schatten ein/aus');
  IC_DESEL: IconName:=L3('Deselect all','Tout deselectionner','Alles abw'#132'hlen');
  IC_SIZE: IconName:=L3('Position and size','Position et taille','Position und Gr'#148#225'e');
  IC_EDIT: IconName:=L3('Edit text','Editer le texte','Text bearbeiten');
  IC_SELECT: IconName:=L3('Select frames','Selection de cadres','Rahmen w'#132'hlen');
  IC_IMPORT: IconName:=L3('Import image','Importer une image','Bild importieren');
  IC_FRONT: IconName:=L3('To front','Premier plan','In den Vordergrund');
  IC_BACK: IconName:=L3('To back','Arriere-plan','In den Hintergrund');
  IC_TRASH: IconName:=L3('Delete frame','Supprimer le cadre','Rahmen l'#148'schen');
  IC_ARROW: IconName:=L3('Select / move frames','Selection / deplacement','Rahmen w'#132'hlen / bewegen');
  IC_IBEAM: IconName:=L3('Text cursor','Curseur de texte','Textcursor');
  IC_A: IconName:=L3('Text attributes','Attributs de texte','Textattribute');
  IC_ZOOM: IconName:=L3('Zoom','Zoom','Ausschnitt');
  IC_DOC: IconName:=L3('Document files','Fichiers du document','Dokumentdateien');
  IC_PGL: IconName:=L3('Previous page','Page precedente','Vorherige Seite');
  IC_PGR: IconName:=L3('Next page','Page suivante','N'#132'chste Seite');
  IC_FM1: IconName:=L3('Outline only','Contour seulement','Nur Kontur');
  IC_FM2: IconName:=L3('Outline and grey','Contour et gris','Kontur und Grau');
  IC_FM3: IconName:=L3('Black fill','Remplissage noir','Schwarze F'#129'llung');
  IC_FM4: IconName:=L3('No outline, no fill','Ni contour ni fond','Ohne Kontur');
  IC_BACKARROW: IconName:=L3('Back to main tools','Retour aux outils','Zur'#129'ck');
  IC_GRIDSHOW: IconName:=L3('Show grid','Afficher la grille','Raster anzeigen');
  IC_SNAP: IconName:=L3('Snap to grid','Aimanter a la grille','Am Raster ausrichten');
  IC_MARGINS: IconName:=L3('Show margins','Afficher les marges','R'#132'nder zeigen');
  IC_GV: IconName:=L3('Vertical guide','Repere vertical','Senkrechte Hilfslinie');
  IC_GH: IconName:=L3('Horizontal guide','Repere horizontal','Waagerechte Hilfslinie');
  IC_GCLR: IconName:=L3('Clear guides','Effacer les reperes','Hilfslinien l'#148'schen');
  IC_FIT: IconName:=L3('Full page','Page entiere','Ganze Seite');
  IC_ONE: IconName:=L3('Original size','Taille reelle','Originalgr'#148#225'e');
  IC_GRIDSET: IconName:=L3('Grid settings','Reglage de la grille','Rastereinstellung');
  IC_NEW: IconName:=L3('New document','Nouveau document','Neues Dokument');
  IC_OPEN: IconName:=L3('Load document','Charger un document','Dokument laden');
  IC_SAVE: IconName:=L3('Save document','Sauver le document','Dokument sichern');
  IC_SAVEAS: IconName:=L3('Save as...','Sauver sous...','Sichern unter...');
  IC_TXTLOAD: IconName:=L3('Load text','Charger un texte','Text laden');
  IC_PRINT: IconName:=L3('PostScript output','Sortie PostScript','PostScript-Ausgabe');
  IC_INFO: IconName:=L3('Statistics','Statistiques','Statistik');
  IC_QUIT: IconName:=L3('Quit','Quitter','Beenden');
 End;
End;

{ ====================================================================== }
{                     BOITE A OUTILS ET BARRES                           }
{ ====================================================================== }

Const
 TBX0 = 6;
 CELL_W = 40;
 CELL_H = 38;
 TAB_Y1 = 58;
 TAB_Y2 = 84;
 GRID_Y0 = 92;

Function RowY(R: Integer): Integer;
Begin
 If (TbPage=0) And (R>=3) Then RowY:=GRID_Y0+R*CELL_H+8
 Else RowY:=GRID_Y0+R*CELL_H;
End;

{ icone de la cellule (rang R, colonne C) de la page courante }
Function CellIcon(Pg,R,C: Integer): Integer;
Var K: Integer;
Begin
 K:=R*3+C+1;
 CellIcon:=IC_NONE;
 Case Pg Of
  0: Case K Of
      1: CellIcon:=IC_TEXTFR;  2: CellIcon:=IC_LINE;    3: CellIcon:=IC_RASTER;
      4: CellIcon:=IC_GRID;    5: CellIcon:=IC_SHAPES;  6: CellIcon:=IC_ATTR;
      7: CellIcon:=IC_DUP;     8: CellIcon:=IC_PAGE;    9: CellIcon:=IC_ROTTXT;
      10: CellIcon:=IC_SHADOW; 11: CellIcon:=IC_DESEL;  12: CellIcon:=IC_SIZE;
      13: CellIcon:=IC_EDIT;   14: CellIcon:=IC_SELECT; 15: CellIcon:=IC_IMPORT;
      16: CellIcon:=IC_FRONT;  17: CellIcon:=IC_BACK;   18: CellIcon:=IC_TRASH;
     End;
  1: Case K Of
      1..15: CellIcon:=IC_SHAPE0+K;
      16: CellIcon:=IC_BACKARROW;
      17: CellIcon:=IC_ARROW;
     End;
  2: Case K Of
      1: CellIcon:=IC_GRIDSHOW; 2: CellIcon:=IC_SNAP;     3: CellIcon:=IC_MARGINS;
      4: CellIcon:=IC_GV;       5: CellIcon:=IC_GH;       6: CellIcon:=IC_GCLR;
      7: CellIcon:=IC_FIT;      8: CellIcon:=IC_ONE;      9: CellIcon:=IC_GRIDSET;
     End;
  3: Case K Of
      1: CellIcon:=IC_NEW;      2: CellIcon:=IC_OPEN;     3: CellIcon:=IC_SAVE;
      4: CellIcon:=IC_SAVEAS;   5: CellIcon:=IC_TXTLOAD;  6: CellIcon:=IC_PRINT;
      7: CellIcon:=IC_INFO;     8: CellIcon:=IC_PAGE;     9: CellIcon:=IC_QUIT;
     End;
 End;
End;

Function TabIcon(I: Integer): Integer;
Begin
 If TbPage=1 Then TabIcon:=IC_FM1+I-1 Else TabIcon:=I;
End;

Function IconActive(Id: Integer): Boolean;
Begin
 IconActive:=False;
 If (Id>IC_SHAPE0) And (Id<=IC_SHAPE0+NSHAPE) Then Begin
  IconActive:=(Tool=TL_SHAPE) And (CurShape=Id-IC_SHAPE0);Exit;
 End;
 Case Id Of
  IC_TAB_TOOLS: IconActive:=(TbPage=0) Or (TbPage=1);
  IC_TAB_HELP: IconActive:=OptHelp;
  IC_TAB_GUIDE: IconActive:=TbPage=2;
  IC_TAB_FILES: IconActive:=TbPage=3;
  IC_TEXTFR: IconActive:=Tool=TL_TEXTFR;
  IC_LINE: IconActive:=Tool=TL_LINE;
  IC_RASTER: IconActive:=Tool=TL_RASTER;
  IC_ROTTXT: IconActive:=Tool=TL_ROTTXT;
  IC_GRID: IconActive:=GridShow;
  IC_SELECT,IC_ARROW: IconActive:=Tool=TL_SELECT;
  IC_IBEAM: IconActive:=Tool=TL_TEXTEDIT;
  IC_ZOOM: IconActive:=Tool=TL_ZOOM;
  IC_FM1..IC_FM4: IconActive:=CurFillMode=Id-IC_FM1+1;
  IC_GRIDSHOW: IconActive:=GridShow;
  IC_SNAP: IconActive:=GridSnap;
  IC_MARGINS: IconActive:=ShowMargins;
 End;
End;

Function ToolName: String;
Begin
 Case Tool Of
  TL_SELECT: ToolName:=IconName(IC_ARROW);
  TL_TEXTEDIT: ToolName:=IconName(IC_IBEAM);
  TL_ZOOM: ToolName:=IconName(IC_ZOOM);
  TL_TEXTFR: ToolName:=IconName(IC_TEXTFR);
  TL_LINE: ToolName:=IconName(IC_LINE);
  TL_RASTER: ToolName:=IconName(IC_RASTER);
  TL_SHAPE: ToolName:=ShapeName(CurShape);
  TL_ROTTXT: ToolName:=IconName(IC_ROTTXT);
  Else ToolName:='';
 End;
End;

Procedure CellRect(R,C: Integer; Var X1,Y1,X2,Y2: Integer);
Begin
 X1:=TBX0+C*CELL_W;X2:=X1+CELL_W-1;
 Y1:=RowY(R);Y2:=Y1+CELL_H-1;
End;

Procedure DrawHelpBox;
Var S: String; L: Integer;
Begin
 Box(TBX0,350,PANEL_W-7,424,PAPER);
 If OptHelp Then Begin
  Frame(TBX0,350,PANEL_W-7,424);
  S:=HelpMsg;
  If S='' Then S:=ToolName;
  L:=0;
  While (S<>'') And (L<7) Do Begin
   PText(TBX0+4,354+L*9,Copy(S,1,14));
   Delete(S,1,14);
   Inc(L);
  End;
 End;
End;

Procedure DrawToolbox;
Var R,C,X1,Y1,X2,Y2,I,Id,L: Integer; S: String; Rows: Integer;
Begin
 Box(0,WIN_Y,PANEL_W-1,SCR_H-1,PAPER);
 Frame(0,WIN_Y,PANEL_W-1,SCR_H-1);
 { rangee des onglets }
 For I:=1 To 4 Do Begin
  X1:=TBX0+(I-1)*30;Id:=TabIcon(I);
  DrawIcon(Id,X1,TAB_Y1,X1+29,TAB_Y2,IconActive(Id));
  Frame(X1,TAB_Y1,X1+29,TAB_Y2);
 End;
 Case TbPage Of
  0: Rows:=6;
  1: Rows:=6;
  Else Rows:=3;
 End;
 For R:=0 To Rows-1 Do
  For C:=0 To 2 Do Begin
   Id:=CellIcon(TbPage,R,C);
   If Id<>IC_NONE Then Begin
    CellRect(R,C,X1,Y1,X2,Y2);
    DrawIcon(Id,X1,Y1,X2,Y2,IconActive(Id));
    Frame(X1,Y1,X2,Y2);
   End;
  End;
 DrawHelpBox;
 { logo }
 Frame(TBX0,432,PANEL_W-7,SCR_H-6);
 Frame(TBX0+2,434,PANEL_W-9,SCR_H-8);
 BigText(TBX0+8,442,2,'CALAMUS',INK,True);
 PText(PANEL_W-48,SCR_H-18,'1.00');
End;

Procedure DrawTitleBar;
Var I,TW,TX,X2: Integer; S: String;
Begin
 X2:=SCR_W-1;
 Box(PANEL_W,WIN_Y,X2,WIN_Y+TITLE_H-1,PAPER);
 SetColor(INK);SetLineStyle(SolidLn,0,1);
 Rectangle(PANEL_W-1,WIN_Y,X2,WIN_Y+TITLE_H-1);
 I:=WIN_Y+3;
 While I<=WIN_Y+12 Do Begin
  Line(PANEL_W+22,I,X2-24,I);
  Inc(I,2);
 End;
 Box(PANEL_W+4,WIN_Y+3,PANEL_W+16,WIN_Y+12,PAPER);
 Frame(PANEL_W+4,WIN_Y+3,PANEL_W+16,WIN_Y+12);
 Box(PANEL_W+8,WIN_Y+5,PANEL_W+12,WIN_Y+10,PAPER);
 Frame(PANEL_W+8,WIN_Y+5,PANEL_W+12,WIN_Y+10);
 Box(X2-19,WIN_Y+3,X2-6,WIN_Y+12,PAPER);
 Frame(X2-19,WIN_Y+3,X2-6,WIN_Y+12);
 Frame(X2-16,WIN_Y+5,X2-9,WIN_Y+10);
 If Named Then S:=Upper(DocName)
 Else S:=L3('NEW DOCUMENT','NOUVEAU DOCUMENT','NEUES DOKUMENT');
 If Modified Then S:=S+' *';
 If Length(S)>40 Then S:=Copy(S,Length(S)-39,40);
 TW:=TextW(S);
 TX:=(PANEL_W+X2-TW) Div 2;
 Box(TX-8,WIN_Y+1,TX+TW+7,WIN_Y+TITLE_H-2,PAPER);
 BText(TX,WIN_Y+5,S);
End;

{ barres de defilement }
Procedure ScrollInfo(Vert: Boolean; Var Pos,Size: Integer; Var TrackLen: Integer);
Var Mn,Mx,V,O,F: Double; L: Integer;
Begin
 If Vert Then Begin
  Mn:=-12;Mx:=PageH+16;V:=CvH/Sc;O:=OrgY;L:=(CVY2-CVY1+1)-32;
 End Else Begin
  Mn:=-12;Mx:=PageW+16;V:=CvW/Sc;O:=OrgX;L:=(CVX2-CVX1+1)-32;
 End;
 TrackLen:=L;
 If Mx-Mn<=V Then Begin Size:=L;Pos:=0;Exit;End;
 Size:=Round(L*V/(Mx-Mn));
 If Size<12 Then Size:=12;
 If Size>L Then Size:=L;
 F:=(O-Mn)/((Mx-Mn)-V);
 If F<0 Then F:=0;
 If F>1 Then F:=1;
 Pos:=Round(F*(L-Size));
End;

Procedure DrawScrollbars;
Var P,S,L: Integer;
Begin
 { verticale }
 Box(VSX1,CVY1,SCR_W-1,CVY2,PAPER);
 Desktop(VSX1+1,CVY1+16,SCR_W-2,CVY2-16);
 Frame(VSX1,CVY1,SCR_W-1,CVY2);
 Box(VSX1,CVY1,SCR_W-1,CVY1+15,PAPER);Frame(VSX1,CVY1,SCR_W-1,CVY1+15);
 Box(VSX1,CVY2-15,SCR_W-1,CVY2,PAPER);Frame(VSX1,CVY2-15,SCR_W-1,CVY2);
 SetColor(INK);
 Line(VSX1+8,CVY1+4,VSX1+3,CVY1+10);Line(VSX1+8,CVY1+4,VSX1+13,CVY1+10);
 Line(VSX1+3,CVY1+10,VSX1+13,CVY1+10);
 Line(VSX1+8,CVY2-4,VSX1+3,CVY2-10);Line(VSX1+8,CVY2-4,VSX1+13,CVY2-10);
 Line(VSX1+3,CVY2-10,VSX1+13,CVY2-10);
 ScrollInfo(True,P,S,L);
 Box(VSX1,CVY1+16+P,SCR_W-1,CVY1+16+P+S-1,PAPER);
 Frame(VSX1,CVY1+16+P,SCR_W-1,CVY1+16+P+S-1);
 { horizontale }
 Box(CVX1,HSY1,VSX1-1,SCR_H-1,PAPER);
 Desktop(CVX1+16,HSY1+1,CVX2-16,SCR_H-2);
 Frame(CVX1-1,HSY1,VSX1-1,SCR_H-1);
 Box(CVX1,HSY1,CVX1+15,SCR_H-1,PAPER);Frame(CVX1-1,HSY1,CVX1+15,SCR_H-1);
 Box(CVX2-15,HSY1,CVX2,SCR_H-1,PAPER);Frame(CVX2-15,HSY1,CVX2+1,SCR_H-1);
 SetColor(INK);
 Line(CVX1+4,HSY1+9,CVX1+11,HSY1+4);Line(CVX1+4,HSY1+9,CVX1+11,HSY1+14);
 Line(CVX1+11,HSY1+4,CVX1+11,HSY1+14);
 Line(CVX2-4,HSY1+9,CVX2-11,HSY1+4);Line(CVX2-4,HSY1+9,CVX2-11,HSY1+14);
 Line(CVX2-11,HSY1+4,CVX2-11,HSY1+14);
 ScrollInfo(False,P,S,L);
 Box(CVX1+16+P,HSY1,CVX1+16+P+S-1,SCR_H-1,PAPER);
 Frame(CVX1+16+P,HSY1,CVX1+16+P+S-1,SCR_H-1);
 { coin }
 Box(VSX1,HSY1,SCR_W-1,SCR_H-1,PAPER);Frame(VSX1,HSY1,SCR_W-1,SCR_H-1);
 Box(VSX1+5,HSY1+5,VSX1+12,HSY1+12,INK);
End;

{ ---- barre d'icones du haut ---- }
Const
 TBI_DOC = 4;     TBI_ARROW = 38;   TBI_IBEAM = 72;  TBI_A = 106;  TBI_ZOOM = 140;
 TBI_W = 33;
 TBF_X = 208;     { boite police }
 TBS_X = 292;     { boite style }
 TBP_X = 340;     { navigation de page }
 TBC_X = 432;     { coordonnees }

Function CurFontOf: Integer;
Var F: PFrame;
Begin
 F:=FirstSel;
 If (F<>Nil) And (F^.Kind=FK_TEXT) Then CurFontOf:=F^.Font Else CurFontOf:=CurFont;
End;

Function CurSizeOf: Double;
Var F: PFrame;
Begin
 F:=FirstSel;
 If (F<>Nil) And (F^.Kind=FK_TEXT) Then CurSizeOf:=F^.Size Else CurSizeOf:=CurSize;
End;

Function CurStyleOf: Integer;
Var F: PFrame;
Begin
 F:=FirstSel;
 If (F<>Nil) And (F^.Kind=FK_TEXT) Then CurStyleOf:=F^.Style Else CurStyleOf:=CurStyle;
End;

Function PadL(S: String; N: Integer): String;
Begin
 While Length(S)<N Do S:=' '+S;
 PadL:=S;
End;

Procedure DrawInfoCoords;
Var Y: Integer;
Begin
 Y:=TB_Y+4;
 Box(TBC_X,TB_Y+2,SCR_W-3,TB_Y+TB_H-4,PAPER);
 Frame(TBC_X,TB_Y+2,SCR_W-3,TB_Y+TB_H-4);
 PText(TBC_X+4,Y+2,'X:');
 PText(TBC_X+22,Y+2,PadL(RealStr(InfoX,2),8));
 PText(TBC_X+96,Y+2,'dX:');
 PText(TBC_X+126,Y+2,PadL(RealStr(InfoDX,2),8));
 PText(TBC_X+4,Y+15,'Y:');
 PText(TBC_X+22,Y+15,PadL(RealStr(InfoY,2),8));
 PText(TBC_X+96,Y+15,'dY:');
 PText(TBC_X+126,Y+15,PadL(RealStr(InfoDY,2),8));
End;

Procedure DrawToolbar;
Var Y1,Y2,I,X,Pt: Integer; S: String; St: Integer;
Begin
 Y1:=TB_Y+2;Y2:=TB_Y+TB_H-4;
 Box(0,TB_Y,SCR_W-1,TB_Y+TB_H-1,PAPER);
 SetColor(INK);SetLineStyle(SolidLn,0,1);
 Line(0,TB_Y+TB_H-1,SCR_W-1,TB_Y+TB_H-1);
 DrawIcon(IC_DOC,TBI_DOC,Y1,TBI_DOC+TBI_W-1,Y2,TbPage=3);Frame(TBI_DOC,Y1,TBI_DOC+TBI_W-1,Y2);
 DrawIcon(IC_ARROW,TBI_ARROW,Y1,TBI_ARROW+TBI_W-1,Y2,Tool=TL_SELECT);
 Frame(TBI_ARROW,Y1,TBI_ARROW+TBI_W-1,Y2);
 DrawIcon(IC_IBEAM,TBI_IBEAM,Y1,TBI_IBEAM+TBI_W-1,Y2,Tool=TL_TEXTEDIT);
 Frame(TBI_IBEAM,Y1,TBI_IBEAM+TBI_W-1,Y2);
 DrawIcon(IC_A,TBI_A,Y1,TBI_A+TBI_W-1,Y2,False);Frame(TBI_A,Y1,TBI_A+TBI_W-1,Y2);
 DrawIcon(IC_ZOOM,TBI_ZOOM,Y1,TBI_ZOOM+TBI_W-1,Y2,Tool=TL_ZOOM);
 Frame(TBI_ZOOM,Y1,TBI_ZOOM+TBI_W-1,Y2);
 { motif courant }
 Box(176,Y1,204,Y2,PAPER);Frame(176,Y1,204,Y2);
 ClipW:=SCR_W;ClipH:=SCR_H;PatOX:=0;PatOY:=0;
 PolyP[1].X:=178;PolyP[1].Y:=Y1+2;PolyP[2].X:=202;PolyP[2].Y:=Y1+2;
 PolyP[3].X:=202;PolyP[3].Y:=Y2-2;PolyP[4].X:=178;PolyP[4].Y:=Y2-2;
 Case CurFillMode Of
  2: FillPolyPat(4,3,INK);
  3: FillPolyPat(4,1,INK);
 End;
 { police }
 Box(TBF_X,Y1,TBF_X+80,Y2,PAPER);Frame(TBF_X,Y1,TBF_X+80,Y2);
 PText(TBF_X+4,Y1+4,Copy(FontName(CurFontOf),1,9));
 Pt:=Round(PtToF(CurSizeOf)*10);
 Case FUnitIdx Of
  0: S:=' pt';
  1: S:=' did';
  Else S:=' mm';
 End;
 PText(TBF_X+4,Y1+15,RealStr(Pt/10,1)+S);
 { style }
 Box(TBS_X,Y1,TBS_X+44,Y2,PAPER);Frame(TBS_X,Y1,TBS_X+44,Y2);
 St:=CurStyleOf;
 S:='BIUOS';
 For I:=1 To 5 Do Begin
  X:=TBS_X+3+(I-1)*8;
  If (St And (1 Shl (I-1)))<>0 Then Begin
   Box(X-1,Y1+9,X+7,Y1+18,INK);WText(X,Y1+10,S[I]);
  End Else PText(X,Y1+10,S[I]);
 End;
 { page }
 DrawIcon(IC_PGL,TBP_X,Y1,TBP_X+18,Y2,False);Frame(TBP_X,Y1,TBP_X+18,Y2);
 Box(TBP_X+20,Y1,TBP_X+72,Y2,PAPER);Frame(TBP_X+20,Y1,TBP_X+72,Y2);
 PText(TBP_X+24,Y1+4,'#');
 S:=IntStr(CurPage);
 BText(TBP_X+68-TextW(S),Y1+4,S);
 PText(TBP_X+24,Y1+15,'/'+IntStr(NPages));
 DrawIcon(IC_PGR,TBP_X+74,Y1,TBP_X+92,Y2,False);Frame(TBP_X+74,Y1,TBP_X+92,Y2);
 DrawInfoCoords;
End;

Procedure DrawMenuHelp;
Var X: Integer;
Begin
 Box(280,1,SCR_W-1,MENU_H-3,PAPER);
 If (HelpMsg<>'') Then Begin
  X:=SCR_W-8-TextW(HelpMsg);
  If X<284 Then X:=284;
  PText(X,4,HelpMsg);
 End;
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
  1: MTitle:='   ';
  2: MTitle:=L3('File','Fichier','Datei');
  3: MTitle:=L3('Page','Page','Seite');
  4: MTitle:=L3('Text','Texte','Text');
  5: MTitle:=L3('View','Vue','Sicht');
  Else MTitle:='Extras';
 End;
End;

Function MCount(M: Integer): Integer;
Begin
 Case M Of
  1: MCount:=4;
  2: MCount:=12;
  3: MCount:=11;
  4: MCount:=17;
  5: MCount:=11;
  6: MCount:=15;
  Else MCount:=0;
 End;
End;

{ '-' = separateur ; '|' separe le raccourci }
Function MLabel(M,I: Integer): String;
Begin
 MLabel:='';
 Case M Of
  1: Case I Of
      1: MLabel:=L3('About Calamus...','A propos de Calamus...',#129'ber Calamus...');
      2: MLabel:='-';
      3: MLabel:=L3('Free memory','Memoire libre','Freier Speicher');
      4: MLabel:=L3('Keyboard help','Aide clavier','Tastaturhilfe');
     End;
  2: Case I Of
      1: MLabel:=L3('New|^N','Nouveau|^N','Neu|^N');
      2: MLabel:=L3('Load...|^O','Charger...|^O','Laden...|^O');
      3: MLabel:=L3('Save|^S','Sauver|^S','Sichern|^S');
      4: MLabel:=L3('Save as...','Sauver sous...','Sichern unter...');
      5: MLabel:='-';
      6: MLabel:=L3('Load text...','Charger texte...','Text laden...');
      7: MLabel:=L3('Save text...','Sauver texte...','Text sichern...');
      8: MLabel:=L3('Import image...','Importer image...','Bild importieren...');
      9: MLabel:='-';
      10: MLabel:=L3('PostScript...|^P','PostScript...|^P','PostScript...|^P');
      11: MLabel:='-';
      12: MLabel:=L3('Quit|^Q','Quitter|^Q','Beenden|^Q');
     End;
  3: Case I Of
      1: MLabel:=L3('Page format...','Format de page...','Seitenformat einstellen...');
      2: MLabel:=L3('Page numbering...','Numerotation...','Seitennumerierung...');
      3: MLabel:='-';
      4: MLabel:=L3('Insert page','Inserer une page','Seite einf'#129'gen');
      5: MLabel:=L3('Delete page','Supprimer la page','Seite l'#148'schen');
      6: MLabel:=L3('Go to page...','Aller a la page...','Gehe zu Seite...');
      7: MLabel:=L3('Next page|PgDn','Page suivante|PgDn','N'#132'chste|PgDn');
      8: MLabel:=L3('Previous page|PgUp','Page precedente|PgUp','Vorherige|PgUp');
      9: MLabel:='-';
      10: MLabel:=L3('Add guide...','Ajouter un repere...','Hilfslinie setzen...');
      11: MLabel:=L3('Show margins','Afficher marges','R'#132'nder zeigen');
     End;
  4: Case I Of
      1: MLabel:=L3('Font and size...|^T','Police et taille...|^T','Zeichensatz, Gr'#148#225'e...|^T');
      2: MLabel:=L3('Line spacing...','Interligne...','Zeilenabstand...');
      3: MLabel:='-';
      4: MLabel:=L3('Normal','Normal','Normal');
      5: MLabel:=L3('Bold|^B','Gras|^B','Fett|^B');
      6: MLabel:=L3('Italic|^K','Italique|^K','Kursiv|^K');
      7: MLabel:=L3('Underline|^U','Souligne|^U','Unterstr.|^U');
      8: MLabel:=L3('Outline','Contour','Umriss');
      9: MLabel:=L3('Shadow','Ombre','Schatten');
      10: MLabel:='-';
      11: MLabel:=L3('Left','Gauche','Linksb'#129'ndig');
      12: MLabel:=L3('Centered','Centre','Zentriert');
      13: MLabel:=L3('Right','Droite','Rechtsb'#129'ndig');
      14: MLabel:=L3('Justified','Justifie','Blocksatz');
      15: MLabel:='-';
      16: MLabel:=L3('Rotate frame...','Tourner le cadre...','Rahmen drehen...');
      17: MLabel:=L3('Edit text|F2','Editer le texte|F2','Text bearbeiten|F2');
     End;
  5: Case I Of
      1: MLabel:=L3('Full page|^F','Page entiere|^F','Ganze Seite|^F');
      2: MLabel:=L3('Original 100%','Taille reelle 100%','Original 100%');
      3: MLabel:='50%';
      4: MLabel:='200%';
      5: MLabel:=L3('Zoom...','Zoom...','Ausschnitt...');
      6: MLabel:='-';
      7: MLabel:=L3('Show grid','Afficher la grille','Raster anzeigen');
      8: MLabel:=L3('Snap to grid','Aimanter a la grille','Am Raster ausrichten');
      9: MLabel:=L3('Show frames','Afficher les cadres','Rahmen anzeigen');
      10: MLabel:='-';
      11: MLabel:=L3('Redraw','Reafficher','Neu zeichnen');
     End;
  6: Case I Of
      1: MLabel:=L3('Help messages','Messages d''aide','Hilfsmeldungen');
      2: MLabel:=L3('Load fonts...','Charger polices...','Zeichens'#132'tze laden');
      3: MLabel:=L3('Clear guides','Effacer les reperes','Hilfslinien l'#148'schen');
      4: MLabel:=L3('Statistics...','Statistiques...','Statistik');
      5: MLabel:=L3('Frame copy selectable','Copie de cadre au choix','Rahmenkopierart w'#132'hlbar');
      6: MLabel:='-';
      7: MLabel:=L3('Set search paths','Regler les chemins','Suchpfade einstellen');
      8: MLabel:=L3('Misc. settings','Reglages divers','Diverse Einstellungen');
      9: MLabel:='-';
      10: MLabel:=L3('Save settings','Sauver les reglages','Einstellungen sichern');
      11: MLabel:=L3('Scanning (settings)','Scanner (reglages)','Scannen (einstellen)');
      12: MLabel:='-';
      13: MLabel:=L3('Select all|^A','Tout selectionner|^A','Alles selektieren|^A');
      14: MLabel:='-';
      15: MLabel:=L3('Undo|^Z','Annuler|^Z','R'#129'ckg'#132'ngig|^Z');
     End;
 End;
End;

Function MHelpText(M,I: Integer): String;
Var S: String; P: Integer;
Begin
 S:='';
 If M=6 Then Case I Of
  1: S:=L3('Show help messages','Afficher les messages d''aide','Hilfsmeldungen anzeigen');
  2: S:=L3('Load typefaces','Charger des polices','Zeichens'#132'tze laden');
  3: S:=L3('Remove all guides','Supprimer les reperes','Hilfslinien entfernen');
  4: S:=L3('Document statistics','Statistiques du document','Dokumentstatistik');
  5: S:=L3('Choose copy mode','Choisir le mode de copie','Rahmenkopierart w'#132'hlen');
  7: S:=L3('Search paths','Chemins de recherche','Suchpfade');
  8: S:=L3('Various options','Options diverses','Verschiedene Optionen');
  10: S:=L3('Save settings','Sauver les reglages','Einstellungen sichern');
  11: S:=L3('Scanner settings','Reglages du scanner','Scanner-Einstellung');
  13: S:=L3('Select all frames','Selectionner tous les cadres','Alle Rahmen w'#132'hlen');
  15: S:=L3('Undo last action','Annuler la derniere action','Letzte Aktion zur'#129'ck');
 End;
 If (S='') And (M>0) And (I>0) Then Begin
  S:=MLabel(M,I);
  P:=Pos('|',S);
  If P>0 Then S:=Copy(S,1,P-1);
  If S='-' Then S:='';
 End;
 MHelpText:=S;
End;

Function SelText: PFrame;
Var F: PFrame;
Begin
 SelText:=Nil;
 If Editing And (EditFr<>Nil) Then Begin SelText:=EditFr;Exit;End;
 F:=FirstSel;
 If (F<>Nil) And (F^.Kind=FK_TEXT) Then SelText:=F;
End;

Function MChecked(M,I: Integer): Boolean;
Var F: PFrame;
Begin
 MChecked:=False;
 F:=SelText;
 Case M Of
  3: If I=11 Then MChecked:=ShowMargins;
  4: Begin
      If F<>Nil Then Begin
       If I=4 Then MChecked:=(F^.Style=0);
       If I In [5..9] Then MChecked:=(F^.Style And (1 Shl (I-5)))<>0;
       If I In [11..14] Then MChecked:=(F^.Align=I-11);
      End;
     End;
  5: Case I Of
      7: MChecked:=GridShow;
      8: MChecked:=GridSnap;
      9: MChecked:=ShowFrames;
     End;
  6: Case I Of
      1: MChecked:=OptHelp;
      5: MChecked:=OptCopyAsk;
     End;
 End;
End;

Function MEnabled(M,I: Integer): Boolean;
Begin
 MEnabled:=True;
 If (M=3) And (I=5) Then MEnabled:=NPages>1;
 If (M=3) And (I=7) Then MEnabled:=CurPage<NPages;
 If (M=3) And (I=8) Then MEnabled:=CurPage>1;
 If (M=4) And (I In [16,17]) Then MEnabled:=CountSel>0;
 If (M=2) And (I In [6,7]) Then MEnabled:=SelText<>Nil;
 If (M=6) And (I=3) Then MEnabled:=(NGV+NGH)>0;
 If (M=6) And (I=15) Then MEnabled:=UndoHas;
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
 Y1:=MENU_H-1;Y2:=Y2+2;
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

{ logo Calamus du menu : un A stylise suivi d'une barre inclinee }
Procedure DrawLogo(X,Y: Integer; Inv: Boolean);
Var C: Integer;
Begin
 If Inv Then C:=PAPER Else C:=INK;
 SetColor(C);SetLineStyle(SolidLn,0,1);
 Line(X+1,Y+10,X+6,Y);Line(X+6,Y,X+11,Y+10);
 Line(X+2,Y+10,X+6,Y+1);Line(X+6,Y+1,X+10,Y+10);
 Line(X+3,Y+7,X+9,Y+7);
 Line(X+11,Y+2,X+18,Y+10);Line(X+12,Y+2,X+19,Y+10);
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
   If M=1 Then DrawLogo(MenuX(M),2,True) Else WText(MenuX(M),4,MTitle(M));
  End Else Begin
   If M=1 Then DrawLogo(MenuX(M),2,False) Else PText(MenuX(M),4,MTitle(M));
  End;
 End;
 If HelpMsg<>'' Then Begin
  M:=SCR_W-8-TextW(HelpMsg);
  If M<MenuX(NMENU)+70 Then M:=MenuX(NMENU)+70;
  PText(M,4,Copy(HelpMsg,1,(SCR_W-M) Div 8));
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

Procedure DrawAll;
Begin
 HideMouse;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 DrawCanvas;
 DrawToolbox;
 DrawToolbar;
 DrawTitleBar;
 DrawScrollbars;
 SetColor(INK);
 DrawMenuBar;
 DrawDropDown;
 ShowMouse;
 NeedDraw:=False;
End;

{ ====================================================================== }
{                          MOTEUR DE BOITES DE DIALOGUE                  }
{ ====================================================================== }

Const
 DC_LABEL = 1; DC_EDIT = 2; DC_CHECK = 3; DC_RADIO = 4; DC_BTN = 5;
 DC_POP = 6; DC_SLIDER = 7; DC_LIST = 9; DC_PATSEL = 11; DC_FRAME = 12;
 DC_TAB = 13;
 ID_OK = 1; ID_CANCEL = 2; ID_APPLY = 3;

Type
 TCtl = Record
  K: Byte;
  X,Y,W,H: Integer;
  T: String[60];
  V: LongInt;
  S: String[70];
  Grp,Id,Mx: Integer;
  Items: String[160];
 End;

Var
 Ctl: Array[1..56] Of TCtl;
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
 If NCtl<56 Then Inc(NCtl);
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

Function AddTab(X,Y,W,Grp,Id: Integer; Const T: String): Integer;
Var I: Integer;
Begin
 I:=AddCtl(DC_TAB,X,Y,W,16,T);
 Ctl[I].Grp:=Grp;Ctl[I].Id:=Id;
 AddTab:=I;
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

Function AddFrameBox(X,Y,W,H: Integer; Const T: String): Integer;
Begin
 AddFrameBox:=AddCtl(DC_FRAME,X,Y,W,H,T);
End;

Procedure AddStdBtns(Apply: Boolean);
Var X: Integer;
Begin
 X:=DlgW-12;
 X:=X-72;AddBtn(X,DlgH-26,72,ID_OK,'OK');Ctl[NCtl].Mx:=1;
 X:=X-80;AddBtn(X,DlgH-26,72,ID_CANCEL,L3('Cancel','Annuler','ABBRUCH'));
 If Apply Then Begin X:=X-80;AddBtn(X,DlgH-26,72,ID_APPLY,L3('Apply','Appliquer','Anwenden'));End;
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

Procedure DrawDlgTitle;
Var TW: Integer;
Begin
 Box(DlgX+2,DlgY+2,DlgX+DlgW-2,DlgY+17,INK);
 TW:=TextW(DlgTitle);
 WText(DlgX+(DlgW-TW) Div 2,DlgY+6,DlgTitle);
End;

Procedure DrawDialog;
Var I,J,X,Y,T,B,Xs,Ys,Cw: Integer; C: TCtl; Lv: Integer;
Begin
 HideMouse;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 Box(DlgX+4,DlgY+4,DlgX+DlgW+4,DlgY+DlgH+4,INK);
 Box(DlgX,DlgY,DlgX+DlgW,DlgY+DlgH,PAPER);
 Frame(DlgX,DlgY,DlgX+DlgW,DlgY+DlgH);
 Frame(DlgX+1,DlgY+1,DlgX+DlgW-1,DlgY+DlgH-1);
 DrawDlgTitle;
 For I:=1 To NCtl Do Begin
  C:=Ctl[I];
  X:=DlgX+C.X;Y:=DlgY+C.Y;
  Case C.K Of
   DC_LABEL: PText(X,Y,C.T);
   DC_FRAME: Begin
     SetColor(INK);SetLineStyle(SolidLn,0,1);Rectangle(X,Y,X+C.W,Y+C.H);
     If C.T<>'' Then Begin
      Box(X+6,Y-4,X+10+Length(C.T)*8,Y+4,PAPER);
      PText(X+8,Y-3,C.T);
     End;
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
     SetColor(INK);SetLineStyle(SolidLn,0,1);Circle(X+5,Y+5,5);
     If RadioVal[C.Grp]=C.Id Then Begin
      SetFillStyle(SolidFill,INK);FillEllipse(X+5,Y+5,2,2);
     End;
     PText(X+16,Y+2,C.T);
    End;
   DC_TAB: Begin
     If RadioVal[C.Grp]=C.Id Then Begin
      Box(X,Y,X+C.W,Y+C.H,INK);Frame(X,Y,X+C.W,Y+C.H);
      WText(X+(C.W+1-TextW(C.T)) Div 2,Y+(C.H-6) Div 2,C.T);
     End Else Begin
      Box(X,Y,X+C.W,Y+C.H,PAPER);Frame(X,Y,X+C.W,Y+C.H);
      PText(X+(C.W+1-TextW(C.T)) Div 2,Y+(C.H-6) Div 2,C.T);
     End;
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
   DC_PATSEL: Begin
     Cw:=C.W Div 8;
     ClipW:=SCR_W;ClipH:=SCR_H;PatOX:=0;PatOY:=0;
     For J:=1 To NPAT Do Begin
      Xs:=X+((J-1) Mod 8)*Cw;Ys:=Y+((J-1) Div 8)*Cw;
      Box(Xs,Ys,Xs+Cw-2,Ys+Cw-2,PAPER);
      For T:=0 To Cw-3 Do
       For B:=0 To Cw-3 Do
        If ((FillPats[J][T And 7] Shr (7-(B And 7))) And 1)<>0 Then
         PutPixel(Xs+B,Ys+T,INK);
      If J=C.V Then Begin
       SetColor(INK);Rectangle(Xs-1,Ys-1,Xs+Cw-1,Ys+Cw-1);
       Rectangle(Xs-2,Ys-2,Xs+Cw,Ys+Cw);
      End Else Begin
       SetColor(GREY);Rectangle(Xs,Ys,Xs+Cw-2,Ys+Cw-2);
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
     Box(X+C.W-16,Y+1,X+C.W-1,Y+14,PAPER);Frame(X+C.W-16,Y+1,X+C.W-1,Y+14);
     SetColor(INK);
     Line(X+C.W-8,Y+4,X+C.W-12,Y+10);Line(X+C.W-8,Y+4,X+C.W-4,Y+10);
     Line(X+C.W-12,Y+10,X+C.W-4,Y+10);
     Box(X+C.W-16,Y+C.H-14,X+C.W-1,Y+C.H-1,PAPER);
     Frame(X+C.W-16,Y+C.H-14,X+C.W-1,Y+C.H-1);
     Line(X+C.W-8,Y+C.H-4,X+C.W-12,Y+C.H-10);Line(X+C.W-8,Y+C.H-4,X+C.W-4,Y+C.H-10);
     Line(X+C.W-12,Y+C.H-10,X+C.W-4,Y+C.H-10);
    End;
  End;
 End;
 ShowMouse;
End;

{ Execute la boite : retourne l'Id du bouton active (ID_OK, ID_CANCEL, ...) }
Function RunDialog: Integer;
Var E: TEvent; I,Res,J,Lv,Sel: Integer; Done,Redraw: Boolean; C: ^TCtl;
 Rows: Integer; LastT: LongInt;
 Function CtlAt(X,Y: Integer): Integer;
 Var K: Integer;
 Begin
  CtlAt:=0;
  For K:=NCtl DownTo 1 Do Begin
   Case Ctl[K].K Of
    DC_LABEL,DC_FRAME: Continue;
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
 Res:=0;Done:=False;Redraw:=True;LastT:=0;
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
         DC_RADIO,DC_TAB: Begin RadioVal[C^.Grp]:=C^.Id;Redraw:=True;End;
         DC_BTN: Begin Res:=C^.Id;Done:=True;End;
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
Var N,P: Integer; S: String; W: Integer;
Begin
 S:=Txt;N:=0;
 DlgInit(Title,360,60);
 W:=0;
 While S<>'' Do Begin
  P:=Pos('|',S);
  Inc(N);
  If P=0 Then Begin AddLabel(14,30+(N-1)*12,S);If Length(S)*8>W Then W:=Length(S)*8;S:='';End
  Else Begin
   AddLabel(14,30+(N-1)*12,Copy(S,1,P-1));
   If (P-1)*8>W Then W:=(P-1)*8;
   Delete(S,1,P);
  End;
 End;
 DlgW:=W+40;
 If DlgW<240 Then DlgW:=240;
 DlgH:=N*12+68;
 DlgX:=(SCR_W-DlgW) Div 2;DlgY:=(SCR_H-DlgH) Div 2;
 AddBtn((DlgW-72) Div 2,DlgH-26,72,ID_OK,'OK');
 Ctl[NCtl].Mx:=1;
 RunDialog;
End;

Function ConfirmBox(Const Txt: String): Boolean;
Begin
 DlgInit('CALAMUS',Length(Txt)*8+40,70);
 If DlgW<280 Then DlgW:=280;
 DlgX:=(SCR_W-DlgW) Div 2;
 AddLabel(16,32,Txt);
 AddBtn(DlgW-12-72,DlgH-26,72,ID_OK,L3('Yes','Oui','Ja'));
 Ctl[NCtl].Mx:=1;
 AddBtn(DlgW-12-152,DlgH-26,72,ID_CANCEL,L3('No','Non','Nein'));
 ConfirmBox:=(RunDialog=ID_OK);
End;

{ 1 = enregistrer, 2 = abandonner, 0 = annuler }
Function AskSave(Const Txt: String): Integer;
Var R: Integer;
Begin
 DlgInit('CALAMUS',Length(Txt)*8+40,70);
 If DlgW<330 Then DlgW:=330;
 DlgX:=(SCR_W-DlgW) Div 2;
 AddLabel(16,32,Txt);
 AddBtn(DlgW-12-72,DlgH-26,72,ID_OK,L3('Save','Sauver','Sichern'));
 Ctl[NCtl].Mx:=1;
 AddBtn(DlgW-12-152,DlgH-26,72,4,L3('Discard','Abandon','Verwerfen'));
 AddBtn(DlgW-12-232,DlgH-26,72,ID_CANCEL,L3('Cancel','Annuler','ABBRUCH'));
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
 If MaxLen>36 Then MaxLen:=36;
 DlgInit(Title,Max2(300,Length(Prompt)*8+MaxLen*8+50),80);
 DlgX:=(SCR_W-DlgW) Div 2;
 AddLabel(14,36,Prompt);
 I:=AddEdit(14+Length(Prompt)*8+8,32,MaxLen*8+8,S);
 AddStdBtns(False);
 If RunDialog=ID_OK Then Begin
  S:=Ctl[I].S;
  InputBox:=True;
 End Else InputBox:=False;
End;

{ ---- selection de fichier avec navigation dans les repertoires ---- }
Function DirSep(Const D: String): Char;
Begin
 If Pos('\',D)>0 Then DirSep:='\' Else DirSep:='/';
End;

Procedure AddList(Const S: String);
Var I: Integer;
Begin
 If LstN>=78 Then Exit;
 For I:=1 To LstN Do If LstItem[I]=Copy(S,1,40) Then Exit;
 Inc(LstN);
 LstItem[LstN]:=Copy(S,1,40);
End;

Procedure ScanDir(Const Dir,Mask: String);
Var SR: SearchRec; Pass: Integer; M: String;
Begin
 LstN:=0;
 AddList('..');
 FindFirst(Dir+'*',Directory,SR);
 While DosError=0 Do Begin
  If ((SR.Attr And Directory)<>0) And (SR.Name<>'.') And (SR.Name<>'..') Then
   AddList('['+SR.Name+']');
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 For Pass:=1 To 2 Do Begin
  If Pass=1 Then M:=Mask Else M:=Lower(Mask);
  FindFirst(Dir+M,AnyFile-Directory,SR);
  While DosError=0 Do Begin
   AddList(SR.Name);
   FindNext(SR);
  End;
  {$IFDEF FPC}
  FindClose(SR);
  {$ENDIF}
 End;
End;

Function ParentDir(Const D: String): String;
Var I: Integer; S: String; Sp: Char;
Begin
 S:=D;Sp:=DirSep(D);
 If (S<>'') And (S[Length(S)]=Sp) Then Dec(S[0]);
 I:=Length(S);
 While (I>0) And (S[I]<>Sp) Do Dec(I);
 If I<=1 Then ParentDir:=D Else ParentDir:=Copy(S,1,I);
End;

Function FileSelect(Const Title,Mask: String; Var Name: String; Dir0: String): Boolean;
Var I,L,R: Integer; S,Dir,Orig: String; Sp: Char;
Begin
 FileSelect:=False;
 Dir:=Dir0;
 If Dir='' Then GetDir(0,Dir);
 Sp:=DirSep(Dir);
 If Dir[Length(Dir)]<>Sp Then Dir:=Dir+Sp;
 Orig:=ShortName(Name);
 DlgInit(Title+' ('+Mask+')',460,270);
 L:=AddCtl(DC_LIST,14,50,432,140,'');
 AddLabel(14,32,'');
 AddLabel(14,202,L3('Name:','Nom :','Name:'));
 I:=AddEdit(70,198,376,Orig);
 AddStdBtns(False);
 Repeat
  ScanDir(Dir,Mask);
  Ctl[L].V:=0;Ctl[L].Mx:=0;Ctl[L].Id:=ID_OK;
  Ctl[L+1].T:=Copy(Dir,1,52);
  Ctl[L+1].W:=Length(Ctl[L+1].T)*8;
  DlgFocus:=I;DlgFresh:=True;
  R:=RunDialog;
  If R<>ID_OK Then Exit;
  S:=TrimStr(Ctl[I].S);
  If (S<>Orig) And (S<>'') Then Begin
   If (Pos('/',S)>0) Or (Pos('\',S)>0) Then Name:=S Else Name:=Dir+S;
   FileSelect:=True;Exit;
  End;
  If Ctl[L].V>=1 Then Begin
   S:=LstItem[Ctl[L].V];
   If S='..' Then Dir:=ParentDir(Dir)
   Else If S[1]='[' Then Dir:=Dir+Copy(S,2,Length(S)-2)+Sp
   Else Begin Name:=Dir+S;FileSelect:=True;Exit;End;
   If (Dir<>'') And (Dir[Length(Dir)]<>Sp) Then Dir:=Dir+Sp;
  End Else If S<>'' Then Begin
   Name:=Dir+S;FileSelect:=True;Exit;
  End Else Exit;
 Until False;
End;

{ ====================================================================== }
{                  FICHIERS : DOCUMENT .CDK, TEXTE, BMP, PS              }
{ ====================================================================== }

Const
 DOCSIG = 'CALAMUS-CLONE 1';

Function R3(X: Double): String;
Begin
 R3:=RealStr(X,3);
End;

Function SaveDocFile(Const Fn: String): Boolean;
Var T: Text; I,J,K,N,RB: Integer; F: PFrame; S: String;
Begin
 SaveDocFile:=False;
 {$I-}
 Assign(T,Fn);
 Rewrite(T);
 {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(T,DOCSIG);
 WriteLn(T,'P ',R3(PageW),' ',R3(PageH),' ',R3(MarL),' ',R3(MarR),' ',R3(MarT),' ',
         R3(MarB),' ',Ord(MirrorMar),' ',Ord(DoublePg),' ',NPages,' ',NumStyle,' ',
         NumFrom,' ',NumTo,' ',NumStart,' ',UnitIdx,' ',FUnitIdx,' ',Ord(NumOn));
 For I:=1 To NGV Do WriteLn(T,'G V ',R3(GuideV[I]));
 For I:=1 To NGH Do WriteLn(T,'G H ',R3(GuideH[I]));
 For I:=1 To NFr Do Begin
  F:=Frs[I];
  WriteLn(T,'F ',F^.Kind,' ',F^.Page,' ',R3(F^.X),' ',R3(F^.Y),' ',R3(F^.W),' ',
          R3(F^.H),' ',R3(F^.Ang),' ',F^.Shape,' ',F^.Fill,' ',F^.LineW,' ',
          Ord(F^.Shadow),' ',Ord(F^.Flip),' ',F^.Font,' ',R3(F^.Size),' ',F^.Style,
          ' ',F^.Align,' ',F^.LineSp,' ',F^.TLen,' ',F^.BW,' ',F^.BH);
  J:=0;
  While J<F^.TLen Do Begin
   N:=F^.TLen-J;
   If N>90 Then N:=90;
   S:='';
   For K:=0 To N-1 Do S:=S+Hex2(Ord(F^.Txt^[J+K]));
   WriteLn(T,'T ',S);
   Inc(J,N);
  End;
  If F^.Bits<>Nil Then Begin
   RB:=RowBytes(F^.BW);
   For J:=0 To F^.BH-1 Do Begin
    S:='';
    For K:=0 To RB-1 Do S:=S+Hex2(F^.Bits^[J*RB+K]);
    WriteLn(T,'R ',S);
   End;
  End;
  WriteLn(T,'E');
 End;
 WriteLn(T,'END');
 {$I-}
 Close(T);
 {$I+}
 SaveDocFile:=(IOResult=0);
End;

Function LoadDocFile(Const Fn: String): Boolean;
Var T: Text; L,Tk: String; F: PFrame; Row,I,RB,K: Integer;
Begin
 LoadDocFile:=False;
 {$I-}
 Assign(T,Fn);
 Reset(T);
 {$I+}
 If IOResult<>0 Then Exit;
 {$I-}
 ReadLn(T,L);
 {$I+}
 If (IOResult<>0) Or (TrimStr(L)<>DOCSIG) Then Begin Close(T);Exit;End;
 ClearDoc;
 F:=Nil;Row:=0;
 NPages:=1;
 While Not Eof(T) Do Begin
  {$I-}
  ReadLn(T,L);
  {$I+}
  If IOResult<>0 Then Break;
  If L='' Then Continue;
  Tk:=NextTok(L);
  If Tk='P' Then Begin
   PageW:=TokNum(L);PageH:=TokNum(L);MarL:=TokNum(L);MarR:=TokNum(L);
   MarT:=TokNum(L);MarB:=TokNum(L);MirrorMar:=TokNum(L)<>0;DoublePg:=TokNum(L)<>0;
   NPages:=Round(TokNum(L));NumStyle:=Round(TokNum(L));NumFrom:=Round(TokNum(L));
   NumTo:=Round(TokNum(L));NumStart:=Round(TokNum(L));
   UnitIdx:=Clamp(Round(TokNum(L)),0,3);FUnitIdx:=Clamp(Round(TokNum(L)),0,2);
   NumOn:=TokNum(L)<>0;
  End Else If Tk='G' Then Begin
   Tk:=NextTok(L);
   If (Tk='V') And (NGV<MAXGUIDE) Then Begin Inc(NGV);GuideV[NGV]:=TokNum(L);End;
   If (Tk='H') And (NGH<MAXGUIDE) Then Begin Inc(NGH);GuideH[NGH]:=TokNum(L);End;
  End Else If Tk='F' Then Begin
   F:=NewFrame(Round(TokNum(L)));
   If F<>Nil Then Begin
    F^.Page:=Round(TokNum(L));
    F^.X:=TokNum(L);F^.Y:=TokNum(L);F^.W:=TokNum(L);F^.H:=TokNum(L);F^.Ang:=TokNum(L);
    F^.Shape:=Round(TokNum(L));F^.Fill:=Round(TokNum(L));F^.LineW:=Round(TokNum(L));
    F^.Shadow:=TokNum(L)<>0;F^.Flip:=TokNum(L)<>0;
    F^.Font:=Clamp(Round(TokNum(L)),1,NFONT);F^.Size:=TokNum(L);
    F^.Style:=Round(TokNum(L));F^.Align:=Round(TokNum(L));F^.LineSp:=Round(TokNum(L));
    TokNum(L);
    K:=Round(TokNum(L));I:=Round(TokNum(L));
    If (K>0) And (I>0) Then BitsAlloc(F,K,I);
    Row:=0;
    If F^.Kind=FK_TEXT Then TxtGrow(F,128);
   End;
  End Else If (Tk='T') And (F<>Nil) Then Begin
   I:=1;
   While I<Length(L) Do Begin
    TxtInsert(F,F^.TLen,Chr(HexVal(L[I])*16+HexVal(L[I+1])));
    Inc(I,2);
   End;
  End Else If (Tk='R') And (F<>Nil) And (F^.Bits<>Nil) Then Begin
   RB:=RowBytes(F^.BW);
   If Row<F^.BH Then Begin
    For K:=0 To RB-1 Do
     If K*2+1<=Length(L) Then F^.Bits^[Row*RB+K]:=HexVal(L[K*2+1])*16+HexVal(L[K*2+2]);
    Inc(Row);
   End;
  End Else If Tk='E' Then F:=Nil
  Else If Tk='END' Then Break;
 End;
 Close(T);
 If NPages<1 Then NPages:=1;
 If NPages>MAXPAGES Then NPages:=MAXPAGES;
 CurPage:=1;
 LoadDocFile:=True;
End;

{ ---- texte ASCII ---- }
Function LoadTextInto(F: PFrame; Const Fn: String): Boolean;
Var T: Text; L: String; I: Integer; First: Boolean;
Begin
 LoadTextInto:=False;
 {$I-}
 Assign(T,Fn);
 Reset(T);
 {$I+}
 If IOResult<>0 Then Exit;
 F^.TLen:=0;
 First:=True;
 While Not Eof(T) Do Begin
  {$I-}
  ReadLn(T,L);
  {$I+}
  If IOResult<>0 Then Break;
  If Not First Then TxtInsert(F,F^.TLen,#13);
  First:=False;
  For I:=1 To Length(L) Do Begin
   If L[I]=#9 Then TxtInsert(F,F^.TLen,' ')
   Else If (L[I]>=' ') Or (L[I]=#0) Then TxtInsert(F,F^.TLen,L[I]);
  End;
 End;
 Close(T);
 LoadTextInto:=True;
End;

Function SaveTextFrom(F: PFrame; Const Fn: String): Boolean;
Var T: Text; I: Integer;
Begin
 SaveTextFrom:=False;
 {$I-}
 Assign(T,Fn);
 Rewrite(T);
 {$I+}
 If IOResult<>0 Then Exit;
 For I:=0 To F^.TLen-1 Do
  If F^.Txt^[I]=#13 Then WriteLn(T) Else Write(T,F^.Txt^[I]);
 WriteLn(T);
 Close(T);
 SaveTextFrom:=True;
End;

{ ---- import d'une image BMP en trame 1 bit ---- }
Function RdW(Var B; Ofs: Integer): Word;
Type TA = Array[0..65000] Of Byte;
Begin
 RdW:=TA(B)[Ofs]+TA(B)[Ofs+1]*256;
End;

Function RdL(Var B; Ofs: Integer): LongInt;
Type TA = Array[0..65000] Of Byte;
Begin
 RdL:=TA(B)[Ofs]+TA(B)[Ofs+1]*256+LongInt(TA(B)[Ofs+2])*65536+LongInt(TA(B)[Ofs+3])*16777216;
End;

Function LoadBMPInto(F: PFrame; Const Fn: String; Var SrcW,SrcH: Integer): Boolean;
Type TBuf = Array[0..65000] Of Byte;
Var Fl: File; Hdr: Array[0..127] Of Byte; Pal: Array[0..255] Of Byte; Row: ^TBuf;
    Off,HSz,Stride: LongInt; W,H,Bpp,Comp,Ncol,TW,TH,X,Y,SX,SY,I,Lum,Thr: Integer;
    Rd: Integer; TopDown: Boolean; Sc2: Double; V: Integer; Idx: Integer;
Begin
 LoadBMPInto:=False;
 {$I-}
 Assign(Fl,Fn);
 Reset(Fl,1);
 {$I+}
 If IOResult<>0 Then Exit;
 BlockRead(Fl,Hdr,54,Rd);
 If (Rd<54) Or (Hdr[0]<>Ord('B')) Or (Hdr[1]<>Ord('M')) Then Begin Close(Fl);Exit;End;
 Off:=RdL(Hdr,10);HSz:=RdL(Hdr,14);
 W:=RdL(Hdr,18);H:=RdL(Hdr,22);Bpp:=RdW(Hdr,28);Comp:=RdL(Hdr,30);
 TopDown:=False;
 If H<0 Then Begin H:=-H;TopDown:=True;End;
 If (Comp<>0) Or (Not (Bpp In [1,4,8,24])) Or (W<1) Or (H<1) Or (HSz<40) Then Begin
  Close(Fl);Exit;
 End;
 Stride:=((LongInt(W)*Bpp+31) Div 32)*4;
 If Stride>60000 Then Begin Close(Fl);Exit;End;
 { palette }
 FillChar(Pal,SizeOf(Pal),0);
 If Bpp<=8 Then Begin
  Ncol:=1 Shl Bpp;
  Seek(Fl,14+HSz);
  For I:=0 To Ncol-1 Do Begin
   BlockRead(Fl,Hdr,4,Rd);
   If Rd=4 Then Pal[I]:=(Hdr[0]*11+Hdr[1]*59+Hdr[2]*30) Div 100;
  End;
 End;
 SrcW:=W;SrcH:=H;
 Sc2:=1;
 If W/256>Sc2 Then Sc2:=W/256;
 If H/256>Sc2 Then Sc2:=H/256;
 TW:=Trunc(W/Sc2);TH:=Trunc(H/Sc2);
 If TW<1 Then TW:=1;
 If TH<1 Then TH:=1;
 BitsAlloc(F,TW,TH);
 If F^.Bits=Nil Then Begin Close(Fl);Exit;End;
 GetMem(Row,Stride+8);
 For Y:=0 To TH-1 Do Begin
  SY:=(LongInt(Y)*H) Div TH;
  If TopDown Then I:=SY Else I:=H-1-SY;
  Seek(Fl,Off+LongInt(I)*Stride);
  BlockRead(Fl,Row^,Stride,Rd);
  For X:=0 To TW-1 Do Begin
   SX:=(LongInt(X)*W) Div TW;
   Case Bpp Of
    24: Lum:=(Row^[SX*3]*11+Row^[SX*3+1]*59+Row^[SX*3+2]*30) Div 100;
    8: Lum:=Pal[Row^[SX]];
    4: Begin
        V:=Row^[SX Shr 1];
        If Odd(SX) Then Idx:=V And 15 Else Idx:=V Shr 4;
        Lum:=Pal[Idx];
       End;
    Else Begin
     V:=Row^[SX Shr 3];
     Idx:=(V Shr (7-(SX And 7))) And 1;
     Lum:=Pal[Idx];
    End;
   End;
   Case ScanMode Of
    0: Thr:=ScanThr;
    1: Thr:=Bayer[Y And 7,X And 7]*4+2;
    Else Thr:=Bayer[(Y Shr 1) And 7,(X Shr 1) And 7]*4+2;
   End;
   If Lum<Thr Then BitSet(F,X,Y);
  End;
 End;
 FreeMem(Row,Stride+8);
 Close(Fl);
 LoadBMPInto:=True;
End;

{ ---- sortie PostScript ---- }
Function PsFont(Fnt,Sty: Integer): String;
Var Base: String; B,I: Boolean;
Begin
 B:=(Sty And ST_BOLD)<>0;
 I:=(Sty And ST_ITALIC)<>0;
 If Fnt=6 Then I:=True;
 Case Fnt Of
  1,6: Begin
        If B And I Then PsFont:='Times-BoldItalic'
        Else If B Then PsFont:='Times-Bold'
        Else If I Then PsFont:='Times-Italic' Else PsFont:='Times-Roman';
       End;
  3: Begin
        If B And I Then PsFont:='Courier-BoldOblique'
        Else If B Then PsFont:='Courier-Bold'
        Else If I Then PsFont:='Courier-Oblique' Else PsFont:='Courier';
       End;
  Else Begin
        If B And I Then PsFont:='Helvetica-BoldOblique'
        Else If B Then PsFont:='Helvetica-Bold'
        Else If I Then PsFont:='Helvetica-Oblique' Else PsFont:='Helvetica';
       End;
 End;
End;

Function PsStr(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:='(';
 For I:=1 To Length(S) Do Begin
  If (S[I]='(') Or (S[I]=')') Or (S[I]='\') Then R:=R+'\'+S[I]
  Else If (S[I]>=' ') And (S[I]<#127) Then R:=R+S[I]
  Else R:=R+'?';
 End;
 PsStr:=R+')';
End;

Function PatGrey(Fill: Integer): String;
Var I,J,C: Integer;
Begin
 If Fill<=1 Then PatGrey:='1'
 Else Begin
  C:=0;
  For I:=0 To 7 Do For J:=0 To 7 Do
   If ((FillPats[Fill-1][I] Shr J) And 1)<>0 Then Inc(C);
  PatGrey:=RealStr(1-C/64,2);
 End;
End;

Function SavePostScript(Const Fn: String): Boolean;
Var T: Text; P,I,J,K,N,RB,Ln,E: Integer; F: PFrame; S,Q: String; Pl: TPoly; X0,Y,Ex: Double;
    C: Char; Bold: Boolean;
Begin
 SavePostScript:=False;
 {$I-}
 Assign(T,Fn);
 Rewrite(T);
 {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(T,'%!PS-Adobe-3.0');
 WriteLn(T,'%%Title: ',DocName);
 WriteLn(T,'%%Creator: Calamus clone (CloneDRAW)');
 WriteLn(T,'%%Pages: ',NPages);
 WriteLn(T,'%%BoundingBox: 0 0 ',Round(PageW*72/25.4),' ',Round(PageH*72/25.4));
 WriteLn(T,'%%EndComments');
 For P:=1 To NPages Do Begin
  WriteLn(T,'%%Page: ',P,' ',P);
  WriteLn(T,'gsave 0 ',R3(PageH*72/25.4),' translate ',R3(72/25.4),' ',R3(-72/25.4),' scale');
  For I:=1 To NFr Do Begin
   F:=Frs[I];
   If F^.Page=P Then Begin
    WriteLn(T,'gsave ',R3(F^.X+F^.W/2),' ',R3(F^.Y+F^.H/2),' translate ',R3(F^.Ang),' rotate');
    WriteLn(T,R3(-F^.W/2),' ',R3(-F^.H/2),' translate');
    Case F^.Kind Of
     FK_LINE: Begin
       If F^.Flip Then WriteLn(T,'newpath 0 ',R3(F^.H),' moveto ',R3(F^.W),' 0 lineto')
       Else WriteLn(T,'newpath 0 0 moveto ',R3(F^.W),' ',R3(F^.H),' lineto');
       WriteLn(T,R3(Max2(1,F^.LineW)/10),' setlinewidth 0 setgray stroke');
      End;
     FK_RASTER: If F^.Bits<>Nil Then Begin
       RB:=RowBytes(F^.BW);
       WriteLn(T,'gsave ',R3(F^.W),' ',R3(F^.H),' scale ',F^.BW,' ',F^.BH,' 1 [',
               F^.BW,' 0 0 ',F^.BH,' 0 0] <');
       For J:=0 To F^.BH-1 Do Begin
        S:='';
        For K:=0 To RB-1 Do S:=S+Hex2(F^.Bits^[J*RB+K] Xor $FF);
        WriteLn(T,S);
       End;
       WriteLn(T,'> image grestore');
      End;
     Else Begin
       N:=4;
       If F^.Kind=FK_SHAPE Then N:=ShapePoly(F^.Shape,F^.W,F^.H,Pl)
       Else Begin
        Pl[1].X:=0;Pl[1].Y:=0;Pl[2].X:=F^.W;Pl[2].Y:=0;
        Pl[3].X:=F^.W;Pl[3].Y:=F^.H;Pl[4].X:=0;Pl[4].Y:=F^.H;
       End;
       If (F^.Fill<>0) Or (F^.LineW>0) Then Begin
        If F^.Shadow Then Begin
         Write(T,'gsave 1.5 1.5 translate newpath');
         For J:=1 To N Do Begin
          If J=1 Then Write(T,' ',R3(Pl[J].X),' ',R3(Pl[J].Y),' moveto')
          Else Write(T,' ',R3(Pl[J].X),' ',R3(Pl[J].Y),' lineto');
         End;
         WriteLn(T,' closepath 0 setgray fill grestore');
        End;
        Write(T,'newpath');
        For J:=1 To N Do Begin
         If J=1 Then Write(T,' ',R3(Pl[J].X),' ',R3(Pl[J].Y),' moveto')
         Else Write(T,' ',R3(Pl[J].X),' ',R3(Pl[J].Y),' lineto');
        End;
        WriteLn(T,' closepath');
        If F^.Fill<>0 Then Begin
         If F^.LineW>0 Then WriteLn(T,'gsave ',PatGrey(F^.Fill),' setgray fill grestore')
         Else WriteLn(T,PatGrey(F^.Fill),' setgray fill');
        End;
        If F^.LineW>0 Then WriteLn(T,R3(F^.LineW/10),' setlinewidth 0 setgray stroke');
       End;
       If F^.Kind=FK_TEXT Then Begin
        Layout(F);
        WriteLn(T,'0 setgray /',PsFont(F^.Font,F^.Style),' findfont ',R3(F^.Size*PT_MM),
                ' scalefont setfont');
        For Ln:=1 To NLn Do Begin
         S:='';
         For K:=LnS[Ln] To LnS[Ln]+LnL[Ln]-1 Do
          If F^.Txt^[K]<>#13 Then S:=S+F^.Txt^[K];
         If S<>'' Then Begin
          Y:=TPAD+(Ln-1)*LineH(F)+F^.Size*PT_MM*0.95;
          WriteLn(T,'gsave ',R3(LineX0(F,Ln)),' ',R3(Y),' translate 1 -1 scale 0 0 moveto ',
                  PsStr(S),' show grestore');
         End;
        End;
       End;
      End;
    End;
    WriteLn(T,'grestore');
   End;
  End;
  If PageNumbered(P) Then Begin
   WriteLn(T,'/Times-Roman findfont 3.5 scalefont setfont 0 setgray');
   WriteLn(T,'gsave ',R3(PageW/2-2),' ',R3(PageH-MarB/2),' translate 1 -1 scale 0 0 moveto ',
           PsStr(PageLabel(P)),' show grestore');
  End;
  WriteLn(T,'grestore showpage');
 End;
 WriteLn(T,'%%EOF');
 Close(T);
 SavePostScript:=True;
End;

{ ---- configuration ---- }
Procedure SaveConfig;
Var T: Text; I: Integer; S: String;
Begin
 {$I-}
 Assign(T,'CALAMUS.CFG');
 Rewrite(T);
 {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(T,'UNIT=',UnitIdx);
 WriteLn(T,'FUNIT=',FUnitIdx);
 WriteLn(T,'HELP=',Ord(OptHelp));
 WriteLn(T,'COPYASK=',Ord(OptCopyAsk));
 WriteLn(T,'UNDO=',Ord(OptUndo));
 WriteLn(T,'AUTOEDIT=',Ord(OptAutoEdit));
 WriteLn(T,'BEEP=',Ord(OptBeep));
 WriteLn(T,'GRIDSHOW=',Ord(GridShow));
 WriteLn(T,'GRIDSNAP=',Ord(GridSnap));
 WriteLn(T,'GRIDX=',R3(GridX));
 WriteLn(T,'GRIDY=',R3(GridY));
 WriteLn(T,'MARGINS=',Ord(ShowMargins));
 WriteLn(T,'FRAMES=',Ord(ShowFrames));
 WriteLn(T,'PATHDOC=',PathDoc);
 WriteLn(T,'PATHFONT=',PathFont);
 WriteLn(T,'PATHIMG=',PathImg);
 WriteLn(T,'PATHTXT=',PathTxt);
 WriteLn(T,'SCANDPI=',ScanDpi);
 WriteLn(T,'SCANMODE=',ScanMode);
 WriteLn(T,'SCANTHR=',ScanThr);
 S:='';
 For I:=1 To NFONT Do S:=S+Chr(48+Ord(FontLoaded[I]));
 WriteLn(T,'FONTS=',S);
 Close(T);
End;

Procedure LoadConfig;
Var T: Text; L,K,V: String; P,I: Integer; X: Double;
Begin
 {$I-}
 Assign(T,'CALAMUS.CFG');
 Reset(T);
 {$I+}
 If IOResult<>0 Then Exit;
 While Not Eof(T) Do Begin
  {$I-}
  ReadLn(T,L);
  {$I+}
  If IOResult<>0 Then Break;
  P:=Pos('=',L);
  If P=0 Then Continue;
  K:=Copy(L,1,P-1);V:=Copy(L,P+1,200);
  If Not ParseNum(V,X) Then X:=0;
  If K='UNIT' Then UnitIdx:=Clamp(Round(X),0,3)
  Else If K='FUNIT' Then FUnitIdx:=Clamp(Round(X),0,2)
  Else If K='HELP' Then OptHelp:=X<>0
  Else If K='COPYASK' Then OptCopyAsk:=X<>0
  Else If K='UNDO' Then OptUndo:=X<>0
  Else If K='AUTOEDIT' Then OptAutoEdit:=X<>0
  Else If K='BEEP' Then OptBeep:=X<>0
  Else If K='GRIDSHOW' Then GridShow:=X<>0
  Else If K='GRIDSNAP' Then GridSnap:=X<>0
  Else If K='GRIDX' Then GridX:=MaxD(1,X)
  Else If K='GRIDY' Then GridY:=MaxD(1,X)
  Else If K='MARGINS' Then ShowMargins:=X<>0
  Else If K='FRAMES' Then ShowFrames:=X<>0
  Else If K='PATHDOC' Then PathDoc:=V
  Else If K='PATHFONT' Then PathFont:=V
  Else If K='PATHIMG' Then PathImg:=V
  Else If K='PATHTXT' Then PathTxt:=V
  Else If K='SCANDPI' Then ScanDpi:=Clamp(Round(X),50,1200)
  Else If K='SCANMODE' Then ScanMode:=Clamp(Round(X),0,2)
  Else If K='SCANTHR' Then ScanThr:=Clamp(Round(X),0,255)
  Else If K='FONTS' Then
   For I:=1 To NFONT Do
    If I<=Length(V) Then FontLoaded[I]:=(V[I]='1');
 End;
 Close(T);
End;

{ ====================================================================== }
{                       ACTIONS SUR LE DOCUMENT                          }
{ ====================================================================== }

Procedure Dirty;
Begin
 Modified:=True;
 NeedDraw:=True;
End;

Procedure SaveUndo;
Begin
 If Not OptUndo Then Exit;
 If SaveDocFile('CALAMUS.UND') Then UndoHas:=True;
End;

Procedure DoUndo;
Var Pg: Integer; Z: Double;
Begin
 If Not UndoHas Then Exit;
 Pg:=CurPage;
 Editing:=False;EditFr:=Nil;
 If LoadDocFile('CALAMUS.UND') Then Begin
  CurPage:=Clamp(Pg,1,NPages);
  Modified:=True;
  NeedDraw:=True;
 End;
 UndoHas:=False;
End;

Procedure ClampPageView;
Begin
 If CurPage>NPages Then CurPage:=NPages;
 If CurPage<1 Then CurPage:=1;
End;

Procedure GotoPage(N: Integer);
Begin
 If N<1 Then N:=1;
 If N>NPages Then N:=NPages;
 If N<>CurPage Then Begin
  Editing:=False;EditFr:=Nil;
  DeselectAll;
  CurPage:=N;
  NeedDraw:=True;
 End;
End;

Procedure InsertPage;
Var I: Integer;
Begin
 If NPages>=MAXPAGES Then Exit;
 SaveUndo;
 For I:=1 To NFr Do If Frs[I]^.Page>CurPage Then Inc(Frs[I]^.Page);
 Inc(NPages);
 Inc(CurPage);
 If NumTo<NPages Then NumTo:=NPages;
 DeselectAll;Editing:=False;EditFr:=Nil;
 Dirty;
End;

Procedure DeletePage;
Var I: Integer;
Begin
 If NPages<=1 Then Exit;
 If Not ConfirmBox(L3('Delete this page?','Supprimer cette page ?','Diese Seite l'#148'schen?')) Then Exit;
 SaveUndo;
 Editing:=False;EditFr:=Nil;
 I:=NFr;
 While I>=1 Do Begin
  If Frs[I]^.Page=CurPage Then DelFrameAt(I)
  Else If Frs[I]^.Page>CurPage Then Dec(Frs[I]^.Page);
  Dec(I);
 End;
 Dec(NPages);
 If CurPage>NPages Then CurPage:=NPages;
 If NumTo>NPages Then NumTo:=NPages;
 Dirty;
End;

Procedure DeleteSel;
Var I: Integer;
Begin
 If CountSel=0 Then Exit;
 SaveUndo;
 For I:=NFr DownTo 1 Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then DelFrameAt(I);
 Editing:=False;EditFr:=Nil;
 Dirty;
End;

Procedure SelectAllFrames;
Var I: Integer;
Begin
 For I:=1 To NFr Do Frs[I]^.Sel:=(Frs[I]^.Page=CurPage);
 NeedDraw:=True;
End;

Procedure ToFront;
Var I,K,Cnt: Integer; Tmp: PFrame;
Begin
 If CountSel=0 Then Exit;
 SaveUndo;
 Cnt:=NFr;K:=0;
 For I:=1 To Cnt Do Begin
  If Frs[I-K]^.Sel And (Frs[I-K]^.Page=CurPage) Then Begin
   Tmp:=Frs[I-K];
   Move(Frs[I-K+1],Frs[I-K],(NFr-(I-K))*SizeOf(PFrame));
   Frs[NFr]:=Tmp;
   Inc(K);
  End;
 End;
 Dirty;
End;

Procedure ToBack;
Var I,K: Integer; Tmp: PFrame;
Begin
 If CountSel=0 Then Exit;
 SaveUndo;
 K:=0;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then Begin
   Tmp:=Frs[I];
   Move(Frs[K+1],Frs[K+2],(I-K-1)*SizeOf(PFrame));
   Frs[K+1]:=Tmp;
   Inc(K);
  End;
 Dirty;
End;

Procedure ToggleShadow;
Var I,N: Integer;
Begin
 If CountSel=0 Then Exit;
 SaveUndo;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then Frs[I]^.Shadow:=Not Frs[I]^.Shadow;
 Dirty;
End;

Procedure DuplicateSel;
Var I,N,K,Cnt: Integer; F,G: PFrame; DX,DY: Double; S1,S2,S3: String; Idx: Integer;
    Src: Array[1..MAXFR] Of PFrame; NS: Integer;
Begin
 If CountSel=0 Then Exit;
 Cnt:=1;DX:=5;DY:=5;
 If OptCopyAsk Then Begin
  DlgInit(L3('COPY FRAMES','COPIE DE CADRES','RAHMEN KOPIEREN'),330,150);
  AddLabel(14,34,L3('Number of copies:','Nombre de copies :','Anzahl Kopien:'));
  Idx:=AddEdit(230,30,72,'1');
  AddLabel(14,58,L3('Offset X','Decalage X','Versatz X')+' ('+UnitName(UnitIdx)+'):');
  S1:=RealStr(MmToU(5),2);
  K:=AddEdit(230,54,72,S1);
  AddLabel(14,82,L3('Offset Y','Decalage Y','Versatz Y')+' ('+UnitName(UnitIdx)+'):');
  N:=AddEdit(230,78,72,S1);
  AddStdBtns(False);
  If RunDialog<>ID_OK Then Exit;
  If ParseNum(Ctl[Idx].S,DX) Then Cnt:=Clamp(Round(DX),1,20);
  If ParseNum(Ctl[K].S,DX) Then DX:=UToMm(DX) Else DX:=5;
  If ParseNum(Ctl[N].S,DY) Then DY:=UToMm(DY) Else DY:=5;
 End;
 SaveUndo;
 NS:=0;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then Begin Inc(NS);Src[NS]:=Frs[I];End;
 DeselectAll;
 For K:=1 To Cnt Do
  For I:=1 To NS Do Begin
   G:=CloneFrame(Src[I]);
   If G<>Nil Then Begin
    G^.X:=G^.X+DX*K;G^.Y:=G^.Y+DY*K;G^.Sel:=(K=Cnt);
   End;
  End;
 Dirty;
End;

{ ---- attributs de texte ---- }
Procedure ApplyTextAttr(Fnt: Integer; Size: Double; Sty,Al,Sp: Integer; AllAttr: Boolean);
Var I: Integer; F: PFrame;
Begin
 CurFont:=Fnt;CurSize:=Size;CurStyle:=Sty;CurAlign:=Al;CurLineSp:=Sp;
 For I:=1 To NFr Do Begin
  F:=Frs[I];
  If F^.Sel And (F^.Page=CurPage) And (F^.Kind=FK_TEXT) Then Begin
   F^.Font:=Fnt;F^.Size:=Size;F^.Style:=Sty;F^.Align:=Al;F^.LineSp:=Sp;
  End;
 End;
End;

Procedure TextAttrDlg;
Var F: PFrame; Fnt,Sty,Al,Sp,I,J,N,Pf,Es,El,Cs: Integer; Size: Double;
    Items,Un: String; Map: Array[1..NFONT] Of Integer; V: Double; Ck: Array[1..5] Of Integer;
Begin
 F:=SelText;
 If F<>Nil Then Begin
  Fnt:=F^.Font;Size:=F^.Size;Sty:=F^.Style;Al:=F^.Align;Sp:=F^.LineSp;
 End Else Begin
  Fnt:=CurFont;Size:=CurSize;Sty:=CurStyle;Al:=CurAlign;Sp:=CurLineSp;
 End;
 Items:='';N:=0;Pf:=0;
 For I:=1 To NFONT Do
  If FontLoaded[I] Or (I=Fnt) Then Begin
   If N>0 Then Items:=Items+'|';
   Items:=Items+FontName(I);
   Inc(N);Map[N]:=I;
   If I=Fnt Then Pf:=N-1;
  End;
 DlgInit(L3('TEXT ATTRIBUTES','ATTRIBUTS DE TEXTE','TEXTATTRIBUTE'),380,250);
 AddLabel(14,34,L3('Typeface:','Police :','Zeichensatz:'));
 J:=AddPop(130,30,150,Items,Pf);
 Case FUnitIdx Of
  0: Un:='pt';
  1: Un:='did';
  Else Un:='mm';
 End;
 AddLabel(14,58,L3('Size in ','Taille en ','Gr'#148#225'e in ')+Un+':');
 Es:=AddEdit(130,54,80,RealStr(PtToF(Size),1));
 AddLabel(14,82,L3('Line spacing %:','Interligne % :','Zeilenabstand %:'));
 El:=AddEdit(130,78,80,IntStr(Sp));
 RadioVal[1]:=Al+1;
 AddFrameBox(14,116,170,70,L3('Alignment','Alignement','Ausrichtung'));
 AddRadio(22,124,1,1,L3('Left','Gauche','Links'));
 AddRadio(22,138,1,2,L3('Centered','Centre','Zentriert'));
 AddRadio(22,152,1,3,L3('Right','Droite','Rechts'));
 AddRadio(22,166,1,4,L3('Justified','Justifie','Blocksatz'));
 AddFrameBox(196,116,170,90,L3('Style','Style','Stil'));
 Ck[1]:=AddCheck(204,124,L3('Bold','Gras','Fett'),(Sty And ST_BOLD)<>0);
 Ck[2]:=AddCheck(204,138,L3('Italic','Italique','Kursiv'),(Sty And ST_ITALIC)<>0);
 Ck[3]:=AddCheck(204,152,L3('Underline','Souligne','Unterstrichen'),(Sty And ST_UNDER)<>0);
 Ck[4]:=AddCheck(204,166,L3('Outline','Contour','Umriss'),(Sty And ST_OUTLINE)<>0);
 Ck[5]:=AddCheck(204,180,L3('Shadow','Ombre','Schatten'),(Sty And ST_SHADOW)<>0);
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 SaveUndo;
 Fnt:=Map[Ctl[J].V+1];
 If ParseNum(Ctl[Es].S,V) Then Size:=ClampD(FToPt(V),2,720);
 If ParseNum(Ctl[El].S,V) Then Sp:=Clamp(Round(V),50,400);
 Sty:=0;
 For I:=1 To 5 Do If Ctl[Ck[I]].V<>0 Then Sty:=Sty Or (1 Shl (I-1));
 ApplyTextAttr(Fnt,Size,Sty,RadioVal[1]-1,Sp,True);
 Dirty;
End;

Procedure ToggleStyleBit(Bit: Integer);
Var I: Integer; F: PFrame; On: Boolean;
Begin
 F:=SelText;
 If F<>Nil Then On:=(F^.Style And Bit)=0 Else On:=(CurStyle And Bit)=0;
 SaveUndo;
 If On Then CurStyle:=CurStyle Or Bit Else CurStyle:=CurStyle And (255-Bit);
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) And (Frs[I]^.Kind=FK_TEXT) Then Begin
   If On Then Frs[I]^.Style:=Frs[I]^.Style Or Bit Else Frs[I]^.Style:=Frs[I]^.Style And (255-Bit);
  End;
 If Editing And (EditFr<>Nil) Then
  If On Then EditFr^.Style:=EditFr^.Style Or Bit Else EditFr^.Style:=EditFr^.Style And (255-Bit);
 Dirty;
End;

Procedure SetStyleNormal;
Var I: Integer;
Begin
 SaveUndo;
 CurStyle:=0;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) And (Frs[I]^.Kind=FK_TEXT) Then Frs[I]^.Style:=0;
 If Editing And (EditFr<>Nil) Then EditFr^.Style:=0;
 Dirty;
End;

Procedure SetAlign(A: Integer);
Var I: Integer;
Begin
 SaveUndo;
 CurAlign:=A;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) And (Frs[I]^.Kind=FK_TEXT) Then Frs[I]^.Align:=A;
 If Editing And (EditFr<>Nil) Then EditFr^.Align:=A;
 Dirty;
End;

Procedure RotateDlg;
Var F: PFrame; S: String; A: Double; I: Integer;
Begin
 F:=FirstSel;
 If F=Nil Then Exit;
 S:=RealStr(F^.Ang,1);
 If Not InputBox(L3('ROTATE FRAME','TOURNER LE CADRE','RAHMEN DREHEN'),
                 L3('Angle (degrees):','Angle (degres) :','Winkel (Grad):'),S,8) Then Exit;
 If Not ParseNum(S,A) Then Exit;
 SaveUndo;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) And (Frs[I]^.Kind<>FK_RASTER) Then Frs[I]^.Ang:=A;
 Dirty;
End;

{ ---- attributs de cadre : position, taille, angle, trait, fond ---- }
Procedure FrameAttrDlg;
Var F: PFrame; One: Boolean; EX,EY,EW,EH,EA,ELw,Ck,Pt: Integer; V: Double; I,Fl: Integer;
Begin
 F:=FirstSel;
 If F=Nil Then Begin
  MsgBox(L3('Frame attributes','Attributs de cadre','Rahmenattribute'),
         L3('Select a frame first.','Selectionnez d''abord un cadre.','Zuerst einen Rahmen w'#132'hlen.'));
  Exit;
 End;
 One:=CountSel=1;
 DlgInit(L3('FRAME ATTRIBUTES','ATTRIBUTS DE CADRE','RAHMENATTRIBUTE'),450,300);
 AddFrameBox(10,30,430,76,L3('Position and size','Position et taille','Position und Gr'#148#225'e')+' ('+UnitName(UnitIdx)+')');
 AddLabel(18,44,'X:');EX:=AddEdit(38,40,72,FmtU(F^.X));
 AddLabel(124,44,'Y:');EY:=AddEdit(144,40,72,FmtU(F^.Y));
 AddLabel(18,68,'W:');EW:=AddEdit(38,64,72,FmtU(F^.W));
 AddLabel(124,68,'H:');EH:=AddEdit(144,64,72,FmtU(F^.H));
 AddLabel(236,44,L3('Angle:','Angle :','Winkel:'));
 EA:=AddEdit(300,40,72,RealStr(F^.Ang,1));
 AddLabel(236,68,L3('Line 1/10mm:','Trait 1/10mm:','Linie 1/10mm:'));
 ELw:=AddEdit(348,64,72,IntStr(F^.LineW));
 If F^.Kind=FK_RASTER Then Ctl[EA].S:='0';
 If F^.Fill=0 Then RadioVal[1]:=1 Else If F^.Fill=1 Then RadioVal[1]:=2 Else RadioVal[1]:=3;
 AddFrameBox(10,118,430,134,L3('Fill','Remplissage','F'#129'llung'));
 AddRadio(18,128,1,1,L3('None','Aucun','Keine'));
 AddRadio(18,144,1,2,L3('White','Blanc','Wei'#225));
 AddRadio(18,160,1,3,L3('Pattern:','Motif :','Muster:'));
 Pt:=AddCtl(DC_PATSEL,140,128,288,0,'');
 If F^.Fill>=2 Then Ctl[Pt].V:=F^.Fill-1 Else Ctl[Pt].V:=1;
 Ck:=AddCheck(18,190,L3('Shadow','Ombre','Schatten'),F^.Shadow);
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 SaveUndo;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then Begin
   If One Then Begin
    If ParseNum(Ctl[EX].S,V) Then Frs[I]^.X:=UToMm(V);
    If ParseNum(Ctl[EY].S,V) Then Frs[I]^.Y:=UToMm(V);
    If ParseNum(Ctl[EW].S,V) Then Frs[I]^.W:=MaxD(0.5,UToMm(V));
    If ParseNum(Ctl[EH].S,V) Then Frs[I]^.H:=MaxD(0.5,UToMm(V));
    If (ParseNum(Ctl[EA].S,V)) And (Frs[I]^.Kind<>FK_RASTER) Then Frs[I]^.Ang:=V;
   End;
   If ParseNum(Ctl[ELw].S,V) Then Frs[I]^.LineW:=Clamp(Round(V),0,100);
   Case RadioVal[1] Of
    1: Frs[I]^.Fill:=0;
    2: Frs[I]^.Fill:=1;
    Else Frs[I]^.Fill:=Ctl[Pt].V+1;
   End;
   Frs[I]^.Shadow:=Ctl[Ck].V<>0;
  End;
 Dirty;
End;

{ ---- format de page ---- }
Const
 PaperW: Array[1..7] Of Double = (148,210,297,215.9,215.9,279.4,139.7);
 PaperH: Array[1..7] Of Double = (210,297,420,279.4,355.6,431.8,215.9);
 ID_MINMAR = 20;

Var
 PfW,PfH: Double;
 PfM,PfEM: Array[1..4] Of Double;
 PfEdW,PfEdH,PfLab: Integer;
 PfEd: Array[1..4] Of Integer;
 PfTxtW,PfTxtH: String;
 PfTxtM: Array[1..4] Of String;
 PfPrevPaper,PfPrevOri,PfPrevUnit: Integer;
 PfReformat: Boolean;

Procedure PageHook;
Var I,U: Integer; X,T: Double;
Begin
 { lecture des champs modifies a la main }
 If Ctl[PfEdW].S<>PfTxtW Then Begin
  If ParseNum(Ctl[PfEdW].S,X) Then Begin PfW:=X*UMM[PfPrevUnit];RadioVal[1]:=8;PfPrevPaper:=8;End;
  PfTxtW:=Ctl[PfEdW].S;
 End;
 If Ctl[PfEdH].S<>PfTxtH Then Begin
  If ParseNum(Ctl[PfEdH].S,X) Then Begin PfH:=X*UMM[PfPrevUnit];RadioVal[1]:=8;PfPrevPaper:=8;End;
  PfTxtH:=Ctl[PfEdH].S;
 End;
 For I:=1 To 4 Do
  If Ctl[PfEd[I]].S<>PfTxtM[I] Then Begin
   If ParseNum(Ctl[PfEd[I]].S,X) Then PfM[I]:=X*UMM[PfPrevUnit];
   PfTxtM[I]:=Ctl[PfEd[I]].S;
  End;
 { format de papier }
 If (RadioVal[1]<>PfPrevPaper) Then Begin
  If (RadioVal[1]>=1) And (RadioVal[1]<=7) Then Begin
   PfW:=PaperW[RadioVal[1]];PfH:=PaperH[RadioVal[1]];
   If RadioVal[2]=2 Then Begin T:=PfW;PfW:=PfH;PfH:=T;End;
   PfReformat:=True;
  End;
  PfPrevPaper:=RadioVal[1];
 End;
 { orientation }
 If RadioVal[2]<>PfPrevOri Then Begin
  If ((RadioVal[2]=1) And (PfW>PfH)) Or ((RadioVal[2]=2) And (PfW<PfH)) Then Begin
   T:=PfW;PfW:=PfH;PfH:=T;PfReformat:=True;
  End;
  PfPrevOri:=RadioVal[2];
 End Else Begin
  If PfW<=PfH Then RadioVal[2]:=1 Else RadioVal[2]:=2;
  PfPrevOri:=RadioVal[2];
 End;
 { unite }
 U:=RadioVal[4]-1;
 If U<>PfPrevUnit Then Begin PfPrevUnit:=U;PfReformat:=True;End;
 If RadioVal[6]=1 Then Begin
  PfM[1]:=5;PfM[2]:=5;PfM[3]:=5;PfM[4]:=5;RadioVal[6]:=0;PfReformat:=True;
 End;
 If PfReformat Then Begin
  PfTxtW:=RealStr(PfW/UMM[U],2);Ctl[PfEdW].S:=PfTxtW;
  PfTxtH:=RealStr(PfH/UMM[U],2);Ctl[PfEdH].S:=PfTxtH;
  For I:=1 To 4 Do Begin
   PfTxtM[I]:=RealStr(PfM[I]/UMM[U],2);Ctl[PfEd[I]].S:=PfTxtM[I];
  End;
  PfReformat:=False;
 End;
 Ctl[PfLab].T:=RealStr(PfW/UMM[U],2)+' '+UnitName(U)+' x '+RealStr(PfH/UMM[U],2)+' '+UnitName(U);
End;

Procedure DlgHookProc;
Begin
 Case DlgHookId Of
  1: PageHook;
 End;
End;

Procedure PageFormatDlg;
Var I,Mir,Dbl,R: Integer; Names: String;
Begin
 PfW:=PageW;PfH:=PageH;
 PfM[1]:=MarL;PfM[2]:=MarR;PfM[3]:=MarT;PfM[4]:=MarB;
 DlgInit(L3('SET PAGE FORMAT','FORMAT DE PAGE','SEITENFORMAT EINSTELLEN'),560,296);
 RadioVal[1]:=8;
 For I:=1 To 7 Do
  If (SameDoc(PageW,PaperW[I]) And SameDoc(PageH,PaperH[I])) Or
     (SameDoc(PageH,PaperW[I]) And SameDoc(PageW,PaperH[I])) Then RadioVal[1]:=I;
 PfPrevPaper:=RadioVal[1];
 If PageW<=PageH Then RadioVal[2]:=1 Else RadioVal[2]:=2;
 PfPrevOri:=RadioVal[2];
 If DoublePg Then RadioVal[3]:=2 Else RadioVal[3]:=1;
 RadioVal[4]:=UnitIdx+1;PfPrevUnit:=UnitIdx;
 RadioVal[5]:=FUnitIdx+1;
 RadioVal[6]:=0;
 AddTab(14,26,56,1,1,'A5');AddTab(76,26,56,1,2,'A4');AddTab(138,26,56,1,3,'A3');
 AddTab(200,26,72,1,4,'Letter');AddTab(278,26,64,1,5,'Legal');
 AddTab(348,26,72,1,6,'Double');AddTab(426,26,56,1,7,'Half');
 AddTab(14,50,80,1,8,L3('Custom:','Perso :','Eigenes:'));
 AddLabel(108,54,L3('Width:','Larg.:','Breite:'));
 PfEdW:=AddEdit(164,50,80,'');
 AddLabel(262,54,L3('Height:','Haut.:','H'#148'he:'));
 PfEdH:=AddEdit(318,50,80,'');
 AddLabel(14,82,L3('Orientation:','Orientation :','Ausrichtung:'));
 AddTab(124,78,110,2,1,L3('Portrait','Portrait','Hochformat'));
 AddTab(240,78,110,2,2,L3('Landscape','Paysage','Querformat'));
 AddLabel(14,106,L3('Resulting page size:','Dimensions obtenues :','Resultierende Seitenausma'#225'e:'));
 PfLab:=AddLabel(14+8*29,106,'                    ');
 Ctl[PfLab].W:=200;
 AddRadio(14,128,3,1,L3('Single pages','Pages simples','Einfachseiten'));
 AddRadio(160,128,3,2,L3('Facing pages','Pages doubles','Doppelseiten'));
 AddLabel(310,130,L3('Printer: ','Imprimante : ','Drucker: ')+'>> '+L3('No driver loaded','Aucun pilote','Kein Treiber geladen'));
 AddFrameBox(10,158,540,68,L3('Margins','Marges','R'#132'nder'));
 AddLabel(18,172,L3('Left:','Gauche:','Links:'));PfEd[1]:=AddEdit(84,168,80,'');
 AddLabel(196,172,L3('Right:','Droite:','Rechts:'));PfEd[2]:=AddEdit(250,168,80,'');
 AddLabel(18,196,L3('Top:','Haut:','Oben:'));PfEd[3]:=AddEdit(84,192,80,'');
 AddLabel(196,196,L3('Bottom:','Bas:','Unten:'));PfEd[4]:=AddEdit(250,192,80,'');
 AddBtn(360,166,170,ID_MINMAR,L3('Minimal margins','Marges minimales','Minimale R'#132'nder'));
 Mir:=AddCheck(360,196,L3('Mirror margins','Marges miroir','R'#132'nder spiegeln'),MirrorMar);
 AddLabel(14,244,L3('Units:','Unites :','Ma'#225'e in:'));
 AddTab(90,240,64,4,1,'Inch');AddTab(158,240,48,4,2,'cm');AddTab(210,240,56,4,3,'Pica');
 AddTab(270,240,72,4,4,'Cicero');
 AddLabel(360,244,L3('Fonts:','Polices :','f'#129'r Fonts:'));
 AddTab(414,240,40,5,3,'mm');AddTab(458,240,38,5,2,'cic');AddTab(500,240,40,5,1,'pt');
 DlgH:=296;
 AddStdBtns(False);
 DlgHookId:=1;
 PfTxtW:='?';PfTxtH:='?';
 For I:=1 To 4 Do PfTxtM[I]:='?';
 PfReformat:=True;
 PageHook;
 Repeat
  R:=RunDialog;
  If R=ID_MINMAR Then Begin RadioVal[6]:=1;End;
 Until R<>ID_MINMAR;
 If R<>ID_OK Then Begin DlgHookId:=0;Exit;End;
 PageHook;
 DlgHookId:=0;
 If (PfW<20) Or (PfH<20) Or (PfW>2000) Or (PfH>2000) Then Begin
  MsgBox('CALAMUS',L3('Invalid page size.','Format de page invalide.','Ung'#129'ltiges Format.'));
  Exit;
 End;
 SaveUndo;
 PageW:=PfW;PageH:=PfH;
 MarL:=PfM[1];MarR:=PfM[2];MarT:=PfM[3];MarB:=PfM[4];
 MirrorMar:=Ctl[Mir].V<>0;
 DoublePg:=RadioVal[3]=2;
 UnitIdx:=RadioVal[4]-1;
 FUnitIdx:=RadioVal[5]-1;
 ZoomFit;
 Dirty;
End;

{ ---- numerotation des pages ---- }
Procedure NumberingDlg;
Var L,E1,E2,E3: Integer; V: Double;
Begin
 DlgInit(L3('PAGE NUMBERING','NUMEROTATION DES PAGES','SEITENNUMERIERUNG:'),340,262);
 AddLabel(24,32,L3('Numbering style:','Type de numerotation :','Art der Numerierung:'));
 LstN:=5;
 LstItem[1]:='1,2     '+L3('Digits','Chiffres','Zahlen');
 LstItem[2]:='A,B     '+L3('Capitals','Majuscules','Gro'#225'buchstaben');
 LstItem[3]:='a,b     '+L3('Lower case','Minuscules','Kleinbuchstaben');
 LstItem[4]:='I,II    '+L3('Roman (caps)','Romain (maj.)','R'#148'misch (gro'#225')');
 LstItem[5]:='i,ii    '+L3('Roman (small)','Romain (min.)','R'#148'misch (klein)');
 L:=AddCtl(DC_LIST,24,48,290,64,'');
 Ctl[L].V:=NumStyle+1;
 AddLabel(24,130,L3('Number from','Numeroter de','Numerierung von'));
 E1:=AddEdit(24+8*16+4,126,40,IntStr(NumFrom));
 AddLabel(24+8*16+52,130,L3('to','a','bis'));
 E2:=AddEdit(24+8*16+52+8*4,126,40,IntStr(NumTo));
 AddLabel(24,158,L3('Start number:','Numero de depart :','Startnummer:'));
 E3:=AddEdit(24+8*16+4,154,40,IntStr(NumStart));
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 SaveUndo;
 NumOn:=True;
 NumStyle:=Clamp(Ctl[L].V-1,0,4);
 If ParseNum(Ctl[E1].S,V) Then NumFrom:=Clamp(Round(V),1,MAXPAGES);
 If ParseNum(Ctl[E2].S,V) Then NumTo:=Clamp(Round(V),1,MAXPAGES);
 If ParseNum(Ctl[E3].S,V) Then NumStart:=Clamp(Round(V),1,9999);
 Dirty;
End;

{ ---- divers ---- }
Procedure GotoPageDlg;
Var S: String; V: Double;
Begin
 S:=IntStr(CurPage);
 If InputBox(L3('GO TO PAGE','ALLER A LA PAGE','GEHE ZU SEITE'),
             L3('Page (1-','Page (1-','Seite (1-')+IntStr(NPages)+'):',S,6) Then
  If ParseNum(S,V) Then GotoPage(Round(V));
End;

Procedure ZoomDlg;
Var S: String; V: Double;
Begin
 S:=RealStr(Zoom,0);
 If InputBox(L3('ZOOM','ZOOM','AUSSCHNITT'),L3('Percent (5-1600):','Pourcentage (5-1600) :','Prozent (5-1600):'),S,6) Then
  If ParseNum(S,V) Then SetZoom(V);
End;

Procedure GuideDlg(Orient: Integer);
Var E: Integer; V: Double;
Begin
 DlgInit(L3('ADD GUIDE','AJOUTER UN REPERE','HILFSLINIE SETZEN'),330,150);
 RadioVal[1]:=Orient;
 AddRadio(20,34,1,1,L3('Vertical','Vertical','Senkrecht'));
 AddRadio(160,34,1,2,L3('Horizontal','Horizontal','Waagerecht'));
 AddLabel(20,64,L3('Position','Position','Position')+' ('+UnitName(UnitIdx)+'):');
 E:=AddEdit(200,60,80,'');
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 If Not ParseNum(Ctl[E].S,V) Then Exit;
 V:=UToMm(V);
 SaveUndo;
 If RadioVal[1]=1 Then Begin
  If NGV<MAXGUIDE Then Begin Inc(NGV);GuideV[NGV]:=V;End;
 End Else If NGH<MAXGUIDE Then Begin Inc(NGH);GuideH[NGH]:=V;End;
 Dirty;
End;

Procedure ClearGuides;
Begin
 If NGV+NGH=0 Then Exit;
 SaveUndo;
 NGV:=0;NGH:=0;
 Dirty;
End;

Procedure PathsDlg;
Var E1,E2,E3,E4: Integer;
Begin
 DlgInit(L3('SEARCH PATHS','CHEMINS DE RECHERCHE','SUCHPFADE EINSTELLEN'),480,220);
 AddLabel(14,36,L3('Documents:','Documents :','Dokumente:'));E1:=AddEdit(120,32,340,PathDoc);
 AddLabel(14,64,L3('Typefaces:','Polices :','Zeichens'#132'tze:'));E2:=AddEdit(120,60,340,PathFont);
 AddLabel(14,92,L3('Images:','Images :','Bilder:'));E3:=AddEdit(120,88,340,PathImg);
 AddLabel(14,120,L3('Texts:','Textes :','Texte:'));E4:=AddEdit(120,116,340,PathTxt);
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 PathDoc:=TrimStr(Ctl[E1].S);PathFont:=TrimStr(Ctl[E2].S);
 PathImg:=TrimStr(Ctl[E3].S);PathTxt:=TrimStr(Ctl[E4].S);
End;

Procedure MiscDlg;
Var C1,C2,C3,C4,C5,C6,E1,E2: Integer; V: Double;
Begin
 DlgInit(L3('MISCELLANEOUS OPTIONS','OPTIONS DIVERSES','VERSCHIEDENE OPTIONEN'),420,250);
 C1:=AddCheck(20,34,L3('Undo enabled','Annulation active','R'#129'ckg'#132'ngig aktiv'),OptUndo);
 C2:=AddCheck(20,52,L3('Edit text after creating a text frame','Editer le texte apres creation','Text nach Anlegen bearbeiten'),OptAutoEdit);
 C3:=AddCheck(20,70,L3('Show frame outlines','Afficher les contours de cadres','Rahmenr'#132'nder zeigen'),ShowFrames);
 C4:=AddCheck(20,88,L3('Snap to grid and guides','Aimanter grille et reperes','Am Raster einrasten'),GridSnap);
 C5:=AddCheck(20,106,L3('Show grid','Afficher la grille','Raster anzeigen'),GridShow);
 C6:=AddCheck(20,124,L3('Beep on errors','Bip en cas d''erreur','Ton bei Fehlern'),OptBeep);
 AddLabel(20,154,L3('Grid X','Grille X','Raster X')+' ('+UnitName(UnitIdx)+'):');
 E1:=AddEdit(220,150,80,FmtU(GridX));
 AddLabel(20,178,L3('Grid Y','Grille Y','Raster Y')+' ('+UnitName(UnitIdx)+'):');
 E2:=AddEdit(220,174,80,FmtU(GridY));
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 OptUndo:=Ctl[C1].V<>0;OptAutoEdit:=Ctl[C2].V<>0;ShowFrames:=Ctl[C3].V<>0;
 GridSnap:=Ctl[C4].V<>0;GridShow:=Ctl[C5].V<>0;OptBeep:=Ctl[C6].V<>0;
 If ParseNum(Ctl[E1].S,V) Then GridX:=MaxD(0.5,UToMm(V));
 If ParseNum(Ctl[E2].S,V) Then GridY:=MaxD(0.5,UToMm(V));
 NeedDraw:=True;
End;

Procedure ScanDlg;
Var P1,P2,Sl: Integer; D: Integer;
Begin
 DlgInit(L3('SCANNING SETTINGS','REGLAGES DU SCANNER','SCANNEN EINSTELLEN'),400,200);
 AddLabel(20,36,L3('Resolution (dpi):','Resolution (dpi) :','Aufl'#148'sung (dpi):'));
 D:=0;
 Case ScanDpi Of
  75: D:=0; 100: D:=1; 150: D:=2; 200: D:=3; 300: D:=4; 400: D:=5; 600: D:=6;
  Else D:=4;
 End;
 P1:=AddPop(200,32,100,'75|100|150|200|300|400|600',D);
 AddLabel(20,64,L3('Mode:','Mode :','Modus:'));
 P2:=AddPop(200,60,150,L3('Line art|Halftone|Fine halftone','Trait|Demi-teinte|Demi-teinte fine','Strich|Raster|Feines Raster'),ScanMode);
 AddLabel(20,92,L3('Threshold:','Seuil :','Schwelle:'));
 Sl:=AddSlider(200,90,150,255,ScanThr);
 AddLabel(20,118,L3('Used when importing images (BMP).','Utilise a l''import d''images (BMP).','Beim Bildimport (BMP) verwendet.'));
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 Case Ctl[P1].V Of
  0: ScanDpi:=75; 1: ScanDpi:=100; 2: ScanDpi:=150; 3: ScanDpi:=200;
  4: ScanDpi:=300; 5: ScanDpi:=400; Else ScanDpi:=600;
 End;
 ScanMode:=Ctl[P2].V;
 ScanThr:=Ctl[Sl].V;
End;

Procedure FontsDlg;
Var Ck: Array[1..NFONT] Of Integer; I: Integer;
Begin
 DlgInit(L3('LOAD TYPEFACES','CHARGER DES POLICES','ZEICHENS'#132'TZE LADEN'),360,230);
 For I:=1 To NFONT Do Begin
  Ck[I]:=AddCheck(24,34+(I-1)*20,FontName(I),FontLoaded[I] Or (I=1));
  AddLabel(140,36+(I-1)*20,'Abcde 123');
 End;
 AddLabel(24,34+NFONT*20,L3('Fonts in use stay available.','Les polices utilisees restent dispo.','Benutzte Fonts bleiben verf'#129'gbar.'));
 AddStdBtns(False);
 If RunDialog<>ID_OK Then Exit;
 For I:=1 To NFONT Do FontLoaded[I]:=(Ctl[Ck[I]].V<>0) Or (I=1);
 NeedDraw:=True;
End;

Procedure StatsDlg;
Var C: Array[1..4] Of Integer; I,J,Chars,Words,Pg: Integer; InW: Boolean; F: PFrame;
    Pgs: Integer;
Begin
 For I:=1 To 4 Do C[I]:=0;
 Chars:=0;Words:=0;
 For I:=1 To NFr Do Begin
  F:=Frs[I];
  Inc(C[F^.Kind]);
  If F^.Kind=FK_TEXT Then Begin
   Inc(Chars,F^.TLen);
   InW:=False;
   For J:=0 To F^.TLen-1 Do Begin
    If (F^.Txt^[J]=' ') Or (F^.Txt^[J]=#13) Then InW:=False
    Else If Not InW Then Begin InW:=True;Inc(Words);End;
   End;
  End;
 End;
 MsgBox(L3('STATISTICS','STATISTIQUES','STATISTIK'),
  L3('Pages: ','Pages : ','Seiten: ')+IntStr(NPages)+'  ('+L3('current ','courante ','aktuell ')+IntStr(CurPage)+')|'+
  L3('Frames: ','Cadres : ','Rahmen: ')+IntStr(NFr)+'|'+
  '  '+L3('text','texte','Text')+': '+IntStr(C[FK_TEXT])+'  '+L3('graphic','graphique','Grafik')+': '+IntStr(C[FK_SHAPE])+'|'+
  '  '+L3('lines','lignes','Linien')+': '+IntStr(C[FK_LINE])+'  raster: '+IntStr(C[FK_RASTER])+'|'+
  L3('Characters: ','Caracteres : ','Zeichen: ')+IntStr(Chars)+'  '+L3('Words: ','Mots : ','W'#148'rter: ')+IntStr(Words)+'|'+
  L3('Page: ','Page : ','Seite: ')+RealStr(PageW,1)+' x '+RealStr(PageH,1)+' mm|'+
  L3('Free memory: ','Memoire libre : ','Freier Speicher: ')+IntStr(FreeMemKB)+' KB');
End;

Procedure KeysDlg;
Begin
 MsgBox(L3('KEYBOARD HELP','AIDE CLAVIER','TASTATURHILFE'),
  '^N '+L3('new','nouveau','neu')+'   ^O '+L3('load','charger','laden')+'   ^S '+L3('save','sauver','sichern')+
  '   ^Q '+L3('quit','quitter','Ende')+'|'+
  '^P PostScript   ^A '+L3('select all','tout selectionner','alles w'#132'hlen')+'   ^Z '+L3('undo','annuler','zur'#129'ck')+'|'+
  '^D '+L3('duplicate','dupliquer','kopieren')+'   Del '+L3('delete frame','supprimer','l'#148'schen')+'|'+
  '^B '+L3('bold','gras','fett')+'   ^K '+L3('italic','italique','kursiv')+'   ^U '+L3('underline','souligne','unterstr.')+'|'+
  'F2 '+L3('edit text','editer le texte','Text bearbeiten')+'   Esc '+L3('leave text / tool','quitter texte / outil','Text / Werkzeug verlassen')+'|'+
  'PgUp/PgDn '+L3('page','page','Seite')+'   + - '+L3('zoom','zoom','Ausschnitt')+'   F10 '+L3('menus','menus','Men'#129's')+'|'+
  L3('Arrows: move frame / scroll','Fleches : deplacer cadre / defiler','Pfeile: Rahmen bewegen / scrollen')+'|'+
  L3('Right click: add to selection / back to arrow','Clic droit : ajouter a la selection / fleche','Rechtsklick: Auswahl erweitern / Pfeil'));
End;

Procedure AboutDlg;
Const
 Names: Array[1..12] Of String[24] = ('Harald Siegmund','Christian Griesbeck','Klaus Garns',
  'Pierre Hansen','J'#148'rn Janneck','Jochen Mickel','Christian Holsten',
  'Hans-J'#129'rgen Reiss','Dietmar Heyfeldt','Alfred Sneets','Michael Bernards','Klaus Ullmann');
Var I: Integer;
Begin
 DlgInit('CALAMUS',420,296);
 AddLabel(140,28,'CLONE  -  VERSION 1.00');
 AddLabel(114,40,'(c) CloneDRAW - www.gladir.com');
 AddFrameBox(14,66,164,190,L3('Authors:','Auteurs :','Autoren:'));
 For I:=1 To 12 Do AddLabel(20,76+(I-1)*14,Names[I]);
 AddLabel(196,80,L3('Original program:','Programme original :','Originalprogramm:'));
 AddLabel(196,94,'Calamus - DMC GmbH');
 AddLabel(196,122,L3('Clone written in','Clone ecrit en','Clone in'));
 AddLabel(196,136,'Turbo / Free Pascal');
 AddLabel(196,164,L3('Language: ','Langue : ','Sprache: ')+L3('English','Francais','Deutsch'));
 AddLabel(196,178,'LANGUAGE=EN / GR');
 AddBtn(320,DlgH-30,72,ID_OK,'OK');
 Ctl[NCtl].Mx:=1;
 RunDialog;
End;

{ ====================================================================== }
{                     FICHIERS : COMMANDES DU MENU                       }
{ ====================================================================== }

Procedure ResetDoc;
Begin
 ClearDoc;
 PageW:=210;PageH:=297;
 MarL:=20;MarR:=20;MarT:=20;MarB:=20;
 MirrorMar:=False;DoublePg:=False;
 NPages:=1;CurPage:=1;
 NumStyle:=0;NumFrom:=1;NumTo:=1;NumStart:=1;NumOn:=False;
 DocName:='';Named:=False;Modified:=False;UndoHas:=False;
 Editing:=False;EditFr:=Nil;
End;

Function AbandonOk: Boolean;
Var R: Integer;
Begin
 AbandonOk:=True;
 If Not Modified Then Exit;
 R:=AskSave(L3('Document modified. Save it?','Document modifie. Le sauver ?','Dokument ge'#132'ndert. Sichern?'));
 If R=0 Then AbandonOk:=False
 Else If R=1 Then Begin
  If Named Then Begin
   If SaveDocFile(DocName) Then Modified:=False Else AbandonOk:=False;
  End;
 End;
End;

Procedure DoNew;
Begin
 If Not AbandonOk Then Exit;
 ResetDoc;
 ZoomFit;
 NeedDraw:=True;
End;

Procedure DoOpen;
Var N: String;
Begin
 If Not AbandonOk Then Exit;
 N:='';
 If Not FileSelect(L3('LOAD DOCUMENT','CHARGER UN DOCUMENT','DOKUMENT LADEN'),'*.CDK',N,PathDoc) Then Exit;
 If LoadDocFile(N) Then Begin
  DocName:=N;Named:=True;Modified:=False;UndoHas:=False;
  Editing:=False;EditFr:=Nil;
  ZoomFit;NeedDraw:=True;
 End Else
  MsgBox('CALAMUS',L3('Cannot read this document.','Lecture du document impossible.','Dokument nicht lesbar.'));
End;

Procedure DoSaveAs;
Var N: String;
Begin
 If Named Then N:=DocName Else N:='NONAME.CDK';
 If Not FileSelect(L3('SAVE DOCUMENT','SAUVER LE DOCUMENT','DOKUMENT SICHERN'),'*.CDK',N,PathDoc) Then Exit;
 N:=AddExt(N,'.CDK');
 If FileExists(N) And (N<>DocName) Then
  If Not ConfirmBox(L3('Overwrite existing file?','Ecraser le fichier existant ?','Datei '#129'berschreiben?')) Then Exit;
 If SaveDocFile(N) Then Begin
  DocName:=N;Named:=True;Modified:=False;NeedDraw:=True;
 End Else
  MsgBox('CALAMUS',L3('Cannot write the file.','Ecriture impossible.','Schreiben nicht m'#148'glich.'));
End;

Procedure DoSave;
Begin
 If Not Named Then Begin DoSaveAs;Exit;End;
 If SaveDocFile(DocName) Then Begin Modified:=False;NeedDraw:=True;End
 Else MsgBox('CALAMUS',L3('Cannot write the file.','Ecriture impossible.','Schreiben nicht m'#148'glich.'));
End;

Procedure DoLoadText;
Var F: PFrame; N: String;
Begin
 F:=SelText;
 If F=Nil Then Begin
  MsgBox('CALAMUS',L3('Select a text frame first.','Selectionnez d''abord un cadre de texte.','Zuerst einen Textrahmen w'#132'hlen.'));
  Exit;
 End;
 N:='';
 If Not FileSelect(L3('LOAD TEXT','CHARGER UN TEXTE','TEXT LADEN'),'*.TXT',N,PathTxt) Then Exit;
 SaveUndo;
 If LoadTextInto(F,N) Then Begin CurPos:=0;Dirty;End
 Else MsgBox('CALAMUS',L3('Cannot read this text.','Lecture du texte impossible.','Text nicht lesbar.'));
End;

Procedure DoSaveText;
Var F: PFrame; N: String;
Begin
 F:=SelText;
 If F=Nil Then Begin
  MsgBox('CALAMUS',L3('Select a text frame first.','Selectionnez d''abord un cadre de texte.','Zuerst einen Textrahmen w'#132'hlen.'));
  Exit;
 End;
 N:='TEXT.TXT';
 If Not FileSelect(L3('SAVE TEXT','SAUVER LE TEXTE','TEXT SICHERN'),'*.TXT',N,PathTxt) Then Exit;
 N:=AddExt(N,'.TXT');
 If Not SaveTextFrom(F,N) Then
  MsgBox('CALAMUS',L3('Cannot write the file.','Ecriture impossible.','Schreiben nicht m'#148'glich.'));
End;

Procedure DoImportImage;
Var N: String; F: PFrame; SW,SH: Integer; W,H,K,AvW,AvH: Double; NewF: Boolean;
Begin
 N:='';
 If Not FileSelect(L3('IMPORT IMAGE','IMPORTER UNE IMAGE','BILD IMPORTIEREN'),'*.BMP',N,PathImg) Then Exit;
 SaveUndo;
 F:=FirstSel;
 NewF:=(F=Nil) Or (F^.Kind<>FK_RASTER) Or (CountSel<>1);
 If NewF Then Begin
  F:=NewFrame(FK_RASTER);
  If F=Nil Then Exit;
 End;
 If Not LoadBMPInto(F,N,SW,SH) Then Begin
  If NewF Then DelFrameAt(FrameIndex(F));
  MsgBox('CALAMUS',L3('Unsupported or unreadable BMP file.','Fichier BMP illisible ou non gere.','BMP-Datei nicht lesbar.'));
  Exit;
 End;
 If NewF Then Begin
  W:=SW/ScanDpi*25.4;H:=SH/ScanDpi*25.4;
  AvW:=PageW-MarL-MarR;AvH:=PageH-MarT-MarB;
  K:=1;
  If W>AvW Then K:=AvW/W;
  If H*K>AvH Then K:=AvH/H;
  F^.W:=W*K;F^.H:=H*K;F^.X:=MarL;F^.Y:=MarT;
  DeselectAll;F^.Sel:=True;
 End;
 Dirty;
End;

Procedure DoPrintPS;
Var N: String;
Begin
 N:='CALAMUS.PS';
 If Not InputBox('POSTSCRIPT',L3('File:','Fichier :','Datei:'),N,30) Then Exit;
 N:=AddExt(N,'.PS');
 If SavePostScript(N) Then
  MsgBox('POSTSCRIPT',L3('File written: ','Fichier ecrit : ','Datei geschrieben: ')+N)
 Else MsgBox('POSTSCRIPT',L3('Cannot write the file.','Ecriture impossible.','Schreiben nicht m'#148'glich.'));
End;

Procedure DoQuit;
Begin
 If AbandonOk Then Quit:=True;
End;

{ ====================================================================== }
{               INTERACTION : OUTILS, SELECTION, EDITION                 }
{ ====================================================================== }

Var
 EditUndoDone: Boolean;

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

Procedure XorFrameOutline(F: PFrame; DX,DY: Double);
Var I,J: Integer; WX,WY: Double; X,Y: Array[0..3] Of Integer;
Begin
 For I:=0 To 3 Do Begin
  LocToWorld(F,(I And 1)*F^.W,((I+1) Shr 1 And 1)*F^.H,WX,WY);
  X[I]:=SxL(WX+DX);Y[I]:=SyL(WY+DY);
 End;
 For I:=0 To 3 Do Begin
  J:=(I+1) And 3;
  Line(X[I],Y[I],X[J],Y[J]);
 End;
End;

Procedure RefreshInfo;
Begin
 HideMouse;
 DrawInfoCoords;
 ShowMouse;
End;

Procedure UpdateInfoFromMouse(X,Y: LongInt);
Begin
 If InBox(X,Y,CVX1,CVY1,CVX2,CVY2) Then Begin
  InfoX:=MmToU(WxOf(X));InfoY:=MmToU(WyOf(Y));
 End;
End;

{ Elastique : Mode 0 rectangle, 1 ligne. Retourne False si pas de mouvement }
Function RubberBand(Mode: Integer; Var WX1,WY1,WX2,WY2: Double): Boolean;
Var E: TEvent; Done,Drawn,Moved: Boolean; CX,CY: Double; X1,Y1,X2,Y2: Integer;
 Procedure Draw;
 Begin
  XorBegin;
  X1:=SxL(WX1);Y1:=SyL(WY1);X2:=SxL(CX);Y2:=SyL(CY);
  If Mode=0 Then Rectangle(X1,Y1,X2,Y2) Else Line(X1,Y1,X2,Y2);
  XorEnd;
 End;
Begin
 RubberBand:=False;
 CX:=WxOf(MX);CY:=WyOf(MY);
 SnapPt(CX,CY);
 WX1:=CX;WY1:=CY;
 Done:=False;Drawn:=False;Moved:=False;
 Repeat
  PollEvent(E);
  Case E.Kind Of
   4: Begin
       If Drawn Then Draw;
       CX:=WxOf(E.X);CY:=WyOf(E.Y);
       SnapPt(CX,CY);
       Moved:=True;
       InfoX:=MmToU(CX);InfoY:=MmToU(CY);
       InfoDX:=MmToU(Abs(CX-WX1));InfoDY:=MmToU(Abs(CY-WY1));
       RefreshInfo;
       Draw;Drawn:=True;
      End;
   3: Done:=True;
   1: If E.Key=K_ESC Then Begin
       If Drawn Then Draw;
       Drawn:=False;Moved:=False;Done:=True;WX2:=WX1;WY2:=WY1;
       Exit;
      End;
  End;
 Until Done;
 If Drawn Then Draw;
 WX2:=CX;WY2:=CY;
 RubberBand:=Moved And ((Abs(WX2-WX1)*Sc>2) Or (Abs(WY2-WY1)*Sc>2));
End;

Procedure StartEdit(F: PFrame; Pos: Integer);
Begin
 If (F=Nil) Or (F^.Kind<>FK_TEXT) Then Exit;
 DeselectAll;
 F^.Sel:=True;
 EditFr:=F;Editing:=True;
 CurPos:=Clamp(Pos,0,F^.TLen);
 EditUndoDone:=False;
 NeedDraw:=True;
End;

Procedure StopEdit;
Begin
 If Editing Then Begin Editing:=False;NeedDraw:=True;End;
End;

Function FrameFill(Mode: Integer): Byte;
Begin
 Case Mode Of
  2: FrameFill:=4;
  3: FrameFill:=2;
  Else FrameFill:=0;
 End;
End;

{ Cree un cadre selon l'outil courant dans le rectangle monde donne }
Procedure CreateFrame(X1,Y1,X2,Y2: Double; Dragged: Boolean);
Var F: PFrame; T: Double;
Begin
 If X2<X1 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y2<Y1 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 If Not Dragged Then Begin
  Case Tool Of
   TL_LINE: Begin X2:=X1+40;Y2:=Y1+20;End;
   TL_TEXTFR,TL_ROTTXT: Begin X2:=X1+60;Y2:=Y1+30;End;
   TL_RASTER: Begin X2:=X1+40;Y2:=Y1+30;End;
   Else Begin X2:=X1+30;Y2:=Y1+30;End;
  End;
 End;
 If X2-X1<1 Then X2:=X1+1;
 If Y2-Y1<1 Then Y2:=Y1+1;
 If NFr>=MAXFR Then Begin
  MsgBox('CALAMUS',L3('Too many frames.','Trop de cadres.','Zu viele Rahmen.'));
  Exit;
 End;
 SaveUndo;
 Case Tool Of
  TL_TEXTFR,TL_ROTTXT: F:=NewFrame(FK_TEXT);
  TL_LINE: F:=NewFrame(FK_LINE);
  TL_RASTER: F:=NewFrame(FK_RASTER);
  Else F:=NewFrame(FK_SHAPE);
 End;
 If F=Nil Then Exit;
 F^.X:=X1;F^.Y:=Y1;F^.W:=X2-X1;F^.H:=Y2-Y1;
 Case Tool Of
  TL_LINE: Begin F^.LineW:=CurLineW;End;
  TL_SHAPE: Begin
    F^.Shape:=CurShape;F^.LineW:=CurLineW;F^.Fill:=FrameFill(CurFillMode);
    If CurFillMode=4 Then F^.LineW:=0;
   End;
  TL_RASTER: F^.LineW:=1;
 End;
 DeselectAll;
 F^.Sel:=True;
 If (Tool=TL_TEXTFR) Or (Tool=TL_ROTTXT) Then Begin
  StartEdit(F,0);
  If Tool=TL_ROTTXT Then Begin F^.Ang:=-30;End;
 End;
 Dirty;
End;

{ ---- poignees ---- }
Function HitHandle(F: PFrame; PX,PY: LongInt): Integer;
Var I: Integer; WX,WY: Double;
Begin
 HitHandle:=0;
 If F^.Kind=FK_LINE Then Begin
  If F^.Flip Then LocToWorld(F,0,F^.H,WX,WY) Else LocToWorld(F,0,0,WX,WY);
  If (Abs(SxL(WX)+CVX1-PX)<=5) And (Abs(SyL(WY)+CVY1-PY)<=5) Then Begin HitHandle:=101;Exit;End;
  If F^.Flip Then LocToWorld(F,F^.W,0,WX,WY) Else LocToWorld(F,F^.W,F^.H,WX,WY);
  If (Abs(SxL(WX)+CVX1-PX)<=5) And (Abs(SyL(WY)+CVY1-PY)<=5) Then HitHandle:=102;
  Exit;
 End;
 For I:=1 To 8 Do Begin
  HandlePos(F,I,WX,WY);
  If (Abs(SxL(WX)+CVX1-PX)<=5) And (Abs(SyL(WY)+CVY1-PY)<=5) Then Begin HitHandle:=I;Exit;End;
 End;
End;

Procedure ResizeLoop(F: PFrame; H: Integer);
Var E: TEvent; Done,Drawn: Boolean; HX,HY: Integer; T,N: TFrame;
    OU,OV,POX,POY,MXw,MYw,U,V,NW,NH,OU2,OV2,CX,CY,WX,WY: Double;
 Procedure Calc;
 Begin
  N:=T;
  WorldToLoc(@T,MXw,MYw,U,V);
  NW:=T.W;NH:=T.H;
  If HX=1 Then NW:=U-OU;
  If HX=-1 Then NW:=OU-U;
  If HY=1 Then NH:=V-OV;
  If HY=-1 Then NH:=OV-V;
  If NW<1 Then NW:=1;
  If NH<1 Then NH:=1;
  If HX=1 Then OU2:=0 Else If HX=-1 Then OU2:=NW Else OU2:=NW/2;
  If HY=1 Then OV2:=0 Else If HY=-1 Then OV2:=NH Else OV2:=NH/2;
  SetTrig(T.Ang);
  CX:=POX-((OU2-NW/2)*TrigC-(OV2-NH/2)*TrigS);
  CY:=POY-((OU2-NW/2)*TrigS+(OV2-NH/2)*TrigC);
  N.W:=NW;N.H:=NH;N.X:=CX-NW/2;N.Y:=CY-NH/2;
 End;
 Procedure Draw;
 Begin
  XorBegin;
  XorFrameOutline(@N,0,0);
  XorEnd;
 End;
Begin
 Case H Of
  1: Begin HX:=-1;HY:=-1;End; 2: Begin HX:=0;HY:=-1;End;
  3: Begin HX:=1;HY:=-1;End; 4: Begin HX:=1;HY:=0;End;
  5: Begin HX:=1;HY:=1;End; 6: Begin HX:=0;HY:=1;End;
  7: Begin HX:=-1;HY:=1;End; Else Begin HX:=-1;HY:=0;End;
 End;
 T:=F^;
 If HX=1 Then OU:=0 Else If HX=-1 Then OU:=T.W Else OU:=T.W/2;
 If HY=1 Then OV:=0 Else If HY=-1 Then OV:=T.H Else OV:=T.H/2;
 LocToWorld(@T,OU,OV,POX,POY);
 Done:=False;Drawn:=False;
 MXw:=WxOf(MX);MYw:=WyOf(MY);
 Repeat
  PollEvent(E);
  Case E.Kind Of
   4: Begin
       If Drawn Then Draw;
       MXw:=WxOf(E.X);MYw:=WyOf(E.Y);
       SnapPt(MXw,MYw);
       Calc;
       InfoDX:=MmToU(NW);InfoDY:=MmToU(NH);RefreshInfo;
       Draw;Drawn:=True;
      End;
   3: Done:=True;
   1: If E.Key=K_ESC Then Begin If Drawn Then Draw;Exit;End;
  End;
 Until Done;
 If Drawn Then Draw;
 If Drawn Then Begin
  SaveUndo;
  F^.X:=N.X;F^.Y:=N.Y;F^.W:=N.W;F^.H:=N.H;
  Dirty;
 End;
End;

Procedure LineEndLoop(F: PFrame; H: Integer);
Var E: TEvent; Done: Boolean; AX,AY,BX,BY,MXw,MYw: Double; Drawn: Boolean;
 Procedure Draw;
 Begin
  XorBegin;
  Line(SxL(AX),SyL(AY),SxL(MXw),SyL(MYw));
  XorEnd;
 End;
Begin
 If F^.Flip Then Begin LocToWorld(F,0,F^.H,AX,AY);LocToWorld(F,F^.W,0,BX,BY);End
 Else Begin LocToWorld(F,0,0,AX,AY);LocToWorld(F,F^.W,F^.H,BX,BY);End;
 If H=101 Then Begin MXw:=AX;MYw:=AY;AX:=BX;AY:=BY;End Else Begin MXw:=BX;MYw:=BY;End;
 { A = point fixe, M = point mobile }
 Done:=False;Drawn:=False;
 Repeat
  PollEvent(E);
  Case E.Kind Of
   4: Begin
       If Drawn Then Draw;
       MXw:=WxOf(E.X);MYw:=WyOf(E.Y);SnapPt(MXw,MYw);
       Draw;Drawn:=True;
      End;
   3: Done:=True;
   1: If E.Key=K_ESC Then Begin If Drawn Then Draw;Exit;End;
  End;
 Until Done;
 If Drawn Then Draw;
 If Drawn Then Begin
  SaveUndo;
  F^.Ang:=0;
  F^.X:=MinD(AX,MXw);F^.Y:=MinD(AY,MYw);
  F^.W:=MaxD(Abs(AX-MXw),0.5);F^.H:=MaxD(Abs(AY-MYw),0.5);
  F^.Flip:=((MXw-AX)*(MYw-AY)<0);
  Dirty;
 End;
End;

Procedure MoveSelLoop;
Var E: TEvent; Done,Drawn,Moved: Boolean; W0X,W0Y,DX,DY,NX,NY: Double; I: Integer; First: PFrame;
 Procedure Draw;
 Var K: Integer;
 Begin
  XorBegin;
  For K:=1 To NFr Do
   If Frs[K]^.Sel And (Frs[K]^.Page=CurPage) Then XorFrameOutline(Frs[K],DX,DY);
  XorEnd;
 End;
Begin
 W0X:=WxOf(MX);W0Y:=WyOf(MY);
 First:=FirstSel;
 DX:=0;DY:=0;Done:=False;Drawn:=False;Moved:=False;
 Repeat
  PollEvent(E);
  Case E.Kind Of
   4: Begin
       If Drawn Then Draw;
       DX:=WxOf(E.X)-W0X;DY:=WyOf(E.Y)-W0Y;
       If GridSnap And (First<>Nil) Then Begin
        NX:=First^.X+DX;NY:=First^.Y+DY;
        SnapPt(NX,NY);
        DX:=NX-First^.X;DY:=NY-First^.Y;
       End;
       If (Abs(DX)*Sc>2) Or (Abs(DY)*Sc>2) Then Moved:=True;
       InfoDX:=MmToU(DX);InfoDY:=MmToU(DY);RefreshInfo;
       Draw;Drawn:=True;
      End;
   3: Done:=True;
   1: If E.Key=K_ESC Then Begin If Drawn Then Draw;Exit;End;
  End;
 Until Done;
 If Drawn Then Draw;
 If Moved Then Begin
  SaveUndo;
  For I:=1 To NFr Do
   If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then Begin
    Frs[I]^.X:=Frs[I]^.X+DX;Frs[I]^.Y:=Frs[I]^.Y+DY;
   End;
  Dirty;
 End;
End;

Procedure SelectInRect(X1,Y1,X2,Y2: Double; Add: Boolean);
Var I: Integer; A,B,C,D,T: Double;
Begin
 If X2<X1 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y2<Y1 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 For I:=1 To NFr Do
  If Frs[I]^.Page=CurPage Then Begin
   FrameBBox(Frs[I],A,B,C,D);
   If (A<=X2) And (C>=X1) And (B<=Y2) And (D>=Y1) Then Frs[I]^.Sel:=True
   Else If Not Add Then Frs[I]^.Sel:=False;
  End;
 NeedDraw:=True;
End;

{ ---- clic sur le canevas ---- }
Procedure CanvasDown(X,Y: LongInt);
Var WX,WY,X2,Y2: Double; F,G: PFrame; H,P: Integer; U,V: Double; Dbl: Boolean;
Begin
 WX:=WxOf(X);WY:=WyOf(Y);
 Dbl:=(Tick-LastClickT<40) And (Abs(X-LastClickX)<4) And (Abs(Y-LastClickY)<4);
 LastClickT:=Tick;LastClickX:=X;LastClickY:=Y;
 { texte en cours d'edition : clic dans le cadre = deplacer le curseur }
 If Editing And (EditFr<>Nil) Then Begin
  If HitFrame(EditFr,WX,WY) Then Begin
   WorldToLoc(EditFr,WX,WY,U,V);
   CurPos:=PosAtLocal(EditFr,U,V);
   NeedDraw:=True;
   Exit;
  End;
  StopEdit;
 End;
 Case Tool Of
  TL_ZOOM: Begin
    If RubberBand(0,WX,WY,X2,Y2) Then ZoomRectMm(WX,WY,X2,Y2)
    Else SetZoom(Zoom*1.6);
   End;
  TL_TEXTFR,TL_ROTTXT,TL_RASTER,TL_SHAPE,TL_LINE: Begin
    If RubberBand(Ord(Tool=TL_LINE),WX,WY,X2,Y2) Then CreateFrame(WX,WY,X2,Y2,True)
    Else Begin
     SnapPt(WX,WY);
     CreateFrame(WX,WY,WX,WY,False);
    End;
   End;
  TL_TEXTEDIT: Begin
    F:=FrameAt(WX,WY);
    If (F<>Nil) And (F^.Kind=FK_TEXT) Then Begin
     WorldToLoc(F,WX,WY,U,V);
     StartEdit(F,PosAtLocal(F,U,V));
    End Else Begin
     DeselectAll;NeedDraw:=True;
    End;
   End;
  Else Begin
    { outil fleche : poignees, deplacement, selection }
    F:=FirstSel;
    If (CountSel=1) And (F<>Nil) Then Begin
     H:=HitHandle(F,X,Y);
     If H>0 Then Begin
      If H>=101 Then LineEndLoop(F,H) Else ResizeLoop(F,H);
      Exit;
     End;
    End;
    F:=FrameAt(WX,WY);
    If F<>Nil Then Begin
     If Dbl And (F^.Kind=FK_TEXT) Then Begin
      WorldToLoc(F,WX,WY,U,V);
      StartEdit(F,PosAtLocal(F,U,V));
      Exit;
     End;
     If Not F^.Sel Then Begin DeselectAll;F^.Sel:=True;NeedDraw:=True;DrawAll;End;
     MoveSelLoop;
    End Else Begin
     DeselectAll;
     If RubberBand(0,WX,WY,X2,Y2) Then SelectInRect(WX,WY,X2,Y2,False);
     NeedDraw:=True;
    End;
   End;
 End;
End;

Procedure CanvasRight(X,Y: LongInt);
Var F: PFrame;
Begin
 If Tool<>TL_SELECT Then Begin
  Tool:=TL_SELECT;StopEdit;NeedDraw:=True;Exit;
 End;
 F:=FrameAt(WxOf(X),WyOf(Y));
 If F<>Nil Then Begin F^.Sel:=Not F^.Sel;NeedDraw:=True;End;
End;

{ ---- edition du texte ---- }
Procedure EditChar(C: Char);
Begin
 If Not EditUndoDone Then Begin SaveUndo;EditUndoDone:=True;End;
 If EditFr^.TLen>=MAXTXT Then Exit;
 TxtInsert(EditFr,CurPos,C);
 Inc(CurPos);
 Modified:=True;NeedDraw:=True;
End;

Procedure EditKey(K: Word);
Var N,E: Integer; X,LH: Double;
Begin
 Layout(EditFr);
 N:=LineOfPos(CurPos);
 Case K Of
  K_ESC: StopEdit;
  K_ENTER: EditChar(#13);
  K_BKSP: If CurPos>0 Then Begin
    If Not EditUndoDone Then Begin SaveUndo;EditUndoDone:=True;End;
    TxtDelete(EditFr,CurPos-1);Dec(CurPos);Modified:=True;NeedDraw:=True;
   End;
  K_DEL: If CurPos<EditFr^.TLen Then Begin
    If Not EditUndoDone Then Begin SaveUndo;EditUndoDone:=True;End;
    TxtDelete(EditFr,CurPos);Modified:=True;NeedDraw:=True;
   End;
  K_LEFT: Begin If CurPos>0 Then Dec(CurPos);NeedDraw:=True;End;
  K_RIGHT: Begin If CurPos<EditFr^.TLen Then Inc(CurPos);NeedDraw:=True;End;
  K_HOME: Begin CurPos:=LnS[N];NeedDraw:=True;End;
  K_END: Begin
    E:=LnS[N]+LnL[N];
    If (Not LnPar[N]) And (E>LnS[N]) Then Dec(E);
    CurPos:=E;NeedDraw:=True;
   End;
  K_UP,K_DOWN: Begin
    LH:=LineH(EditFr);
    X:=CaretX(EditFr,N,CurPos);
    If K=K_UP Then Dec(N) Else Inc(N);
    If (N>=1) And (N<=NLn) Then Begin
     CurPos:=PosAtLocal(EditFr,X,TPAD+(N-1)*LH+LH/2);
     NeedDraw:=True;
    End;
   End;
  32..255: EditChar(Chr(K));
 End;
End;

{ ---- barre d'icones et boite a outils ---- }
Function HitToolbox(X,Y: LongInt): Integer;
Var I,R,C,X1,Y1,X2,Y2,Rows: Integer;
Begin
 HitToolbox:=IC_NONE;
 If X>=PANEL_W Then Exit;
 For I:=1 To 4 Do
  If InBox(X,Y,TBX0+(I-1)*30,TAB_Y1,TBX0+(I-1)*30+29,TAB_Y2) Then Begin
   HitToolbox:=TabIcon(I);Exit;
  End;
 If TbPage<2 Then Rows:=6 Else Rows:=3;
 For R:=0 To Rows-1 Do
  For C:=0 To 2 Do Begin
   CellRect(R,C,X1,Y1,X2,Y2);
   If InBox(X,Y,X1,Y1,X2,Y2) Then Begin HitToolbox:=CellIcon(TbPage,R,C);Exit;End;
  End;
End;

Procedure SetTool(T: Integer);
Begin
 StopEdit;
 Tool:=T;
 NeedDraw:=True;
End;

Procedure ToolboxAction(Id: Integer);
Var F: PFrame;
Begin
 If (Id>IC_SHAPE0) And (Id<=IC_SHAPE0+NSHAPE) Then Begin
  CurShape:=Id-IC_SHAPE0;SetTool(TL_SHAPE);Exit;
 End;
 Case Id Of
  IC_TAB_TOOLS: Begin TbPage:=0;NeedDraw:=True;End;
  IC_TAB_HELP: Begin OptHelp:=Not OptHelp;NeedDraw:=True;End;
  IC_TAB_GUIDE: Begin If TbPage=2 Then TbPage:=0 Else TbPage:=2;NeedDraw:=True;End;
  IC_TAB_FILES: Begin If TbPage=3 Then TbPage:=0 Else TbPage:=3;NeedDraw:=True;End;
  IC_TEXTFR: SetTool(TL_TEXTFR);
  IC_LINE: SetTool(TL_LINE);
  IC_RASTER: SetTool(TL_RASTER);
  IC_GRID: Begin GridShow:=Not GridShow;NeedDraw:=True;End;
  IC_SHAPES: Begin TbPage:=1;SetTool(TL_SHAPE);End;
  IC_ATTR,IC_SIZE: FrameAttrDlg;
  IC_DUP: DuplicateSel;
  IC_PAGE: PageFormatDlg;
  IC_ROTTXT: SetTool(TL_ROTTXT);
  IC_SHADOW: ToggleShadow;
  IC_DESEL: Begin StopEdit;DeselectAll;NeedDraw:=True;End;
  IC_EDIT: Begin
    F:=SelText;
    If F<>Nil Then StartEdit(F,F^.TLen);
   End;
  IC_SELECT,IC_ARROW: SetTool(TL_SELECT);
  IC_IMPORT: DoImportImage;
  IC_FRONT: ToFront;
  IC_BACK: ToBack;
  IC_TRASH: DeleteSel;
  IC_FM1..IC_FM4: Begin CurFillMode:=Id-IC_FM1+1;NeedDraw:=True;End;
  IC_BACKARROW: Begin TbPage:=0;NeedDraw:=True;End;
  IC_GRIDSHOW: Begin GridShow:=Not GridShow;NeedDraw:=True;End;
  IC_SNAP: Begin GridSnap:=Not GridSnap;NeedDraw:=True;End;
  IC_MARGINS: Begin ShowMargins:=Not ShowMargins;NeedDraw:=True;End;
  IC_GV: GuideDlg(1);
  IC_GH: GuideDlg(2);
  IC_GCLR: ClearGuides;
  IC_FIT: ZoomFit;
  IC_ONE: SetZoom(100);
  IC_GRIDSET: MiscDlg;
  IC_NEW: DoNew;
  IC_OPEN: DoOpen;
  IC_SAVE: DoSave;
  IC_SAVEAS: DoSaveAs;
  IC_TXTLOAD: DoLoadText;
  IC_PRINT: DoPrintPS;
  IC_INFO: StatsDlg;
  IC_QUIT: DoQuit;
 End;
End;

Procedure ToolbarClick(X,Y: LongInt);
Var Y1,Y2: Integer;
Begin
 Y1:=TB_Y+2;Y2:=TB_Y+TB_H-4;
 If InBox(X,Y,TBI_DOC,Y1,TBI_DOC+TBI_W-1,Y2) Then Begin
  If TbPage=3 Then TbPage:=0 Else TbPage:=3;NeedDraw:=True;
 End Else If InBox(X,Y,TBI_ARROW,Y1,TBI_ARROW+TBI_W-1,Y2) Then SetTool(TL_SELECT)
 Else If InBox(X,Y,TBI_IBEAM,Y1,TBI_IBEAM+TBI_W-1,Y2) Then Begin
  SetTool(TL_TEXTEDIT);
  If SelText<>Nil Then StartEdit(SelText,SelText^.TLen);
 End
 Else If InBox(X,Y,TBI_A,Y1,TBI_A+TBI_W-1,Y2) Then TextAttrDlg
 Else If InBox(X,Y,TBI_ZOOM,Y1,TBI_ZOOM+TBI_W-1,Y2) Then SetTool(TL_ZOOM)
 Else If InBox(X,Y,176,Y1,204,Y2) Then FrameAttrDlg
 Else If InBox(X,Y,TBF_X,Y1,TBF_X+80,Y2) Then TextAttrDlg
 Else If InBox(X,Y,TBS_X,Y1,TBS_X+44,Y2) Then TextAttrDlg
 Else If InBox(X,Y,TBP_X,Y1,TBP_X+18,Y2) Then GotoPage(CurPage-1)
 Else If InBox(X,Y,TBP_X+74,Y1,TBP_X+92,Y2) Then GotoPage(CurPage+1)
 Else If InBox(X,Y,TBP_X+20,Y1,TBP_X+72,Y2) Then GotoPageDlg;
End;

Function ToolbarHelp(X,Y: LongInt): String;
Var Y1,Y2: Integer;
Begin
 ToolbarHelp:='';
 Y1:=TB_Y+2;Y2:=TB_Y+TB_H-4;
 If InBox(X,Y,TBI_DOC,Y1,TBI_DOC+TBI_W-1,Y2) Then ToolbarHelp:=IconName(IC_DOC)
 Else If InBox(X,Y,TBI_ARROW,Y1,TBI_ARROW+TBI_W-1,Y2) Then ToolbarHelp:=IconName(IC_ARROW)
 Else If InBox(X,Y,TBI_IBEAM,Y1,TBI_IBEAM+TBI_W-1,Y2) Then ToolbarHelp:=IconName(IC_IBEAM)
 Else If InBox(X,Y,TBI_A,Y1,TBI_A+TBI_W-1,Y2) Then ToolbarHelp:=IconName(IC_A)
 Else If InBox(X,Y,TBI_ZOOM,Y1,TBI_ZOOM+TBI_W-1,Y2) Then ToolbarHelp:=IconName(IC_ZOOM)
 Else If InBox(X,Y,176,Y1,204,Y2) Then ToolbarHelp:=IconName(IC_ATTR)
 Else If InBox(X,Y,TBF_X,Y1,TBS_X+44,Y2) Then ToolbarHelp:=IconName(IC_A)
 Else If InBox(X,Y,TBP_X,Y1,TBP_X+18,Y2) Then ToolbarHelp:=IconName(IC_PGL)
 Else If InBox(X,Y,TBP_X+74,Y1,TBP_X+92,Y2) Then ToolbarHelp:=IconName(IC_PGR)
 Else If InBox(X,Y,TBP_X+20,Y1,TBP_X+72,Y2) Then ToolbarHelp:=L3('Go to page','Aller a la page','Gehe zu Seite');
End;

{ ---- barres de defilement ---- }
Procedure ScrollBarDown(X,Y: LongInt);
Var P,S,L: Integer; E: TEvent; Vert: Boolean; Start,T0: LongInt; Mn,Mx,V,Fr: Double;
Begin
 Vert:=X>=VSX1;
 If Vert Then Begin
  ScrollInfo(True,P,S,L);
  If Y<CVY1+16 Then ScrollBy(0,-CvH/Sc*0.1)
  Else If Y>CVY2-16 Then ScrollBy(0,CvH/Sc*0.1)
  Else If Y<CVY1+16+P Then ScrollBy(0,-CvH/Sc*0.9)
  Else If Y>CVY1+16+P+S Then ScrollBy(0,CvH/Sc*0.9)
  Else Begin
   Start:=Y;T0:=P;Mn:=-12;Mx:=PageH+16;V:=CvH/Sc;
   Repeat
    PollEvent(E);
    If E.Kind=4 Then Begin
     Fr:=(T0+(E.Y-Start))/(L-S);
     OrgY:=Mn+ClampD(Fr,0,1)*((Mx-Mn)-V);
     ClampOrg;NeedDraw:=True;DrawAll;
    End;
   Until E.Kind=3;
  End;
 End Else Begin
  ScrollInfo(False,P,S,L);
  If X<CVX1+16 Then ScrollBy(-CvW/Sc*0.1,0)
  Else If X>CVX2-16 Then ScrollBy(CvW/Sc*0.1,0)
  Else If X<CVX1+16+P Then ScrollBy(-CvW/Sc*0.9,0)
  Else If X>CVX1+16+P+S Then ScrollBy(CvW/Sc*0.9,0)
  Else Begin
   Start:=X;T0:=P;Mn:=-12;Mx:=PageW+16;V:=CvW/Sc;
   Repeat
    PollEvent(E);
    If E.Kind=4 Then Begin
     Fr:=(T0+(E.X-Start))/(L-S);
     OrgX:=Mn+ClampD(Fr,0,1)*((Mx-Mn)-V);
     ClampOrg;NeedDraw:=True;DrawAll;
    End;
   Until E.Kind=3;
  End;
 End;
End;

{ ====================================================================== }
{                              MENUS (actions)                           }
{ ====================================================================== }

Procedure DoMenu(M,I: Integer);
Var F: PFrame;
Begin
 Case M Of
  1: Case I Of
      1: AboutDlg;
      3: MsgBox(L3('FREE MEMORY','MEMOIRE LIBRE','FREIER SPEICHER'),IntStr(FreeMemKB)+' KB');
      4: KeysDlg;
     End;
  2: Case I Of
      1: DoNew;
      2: DoOpen;
      3: DoSave;
      4: DoSaveAs;
      6: DoLoadText;
      7: DoSaveText;
      8: DoImportImage;
      10: DoPrintPS;
      12: DoQuit;
     End;
  3: Case I Of
      1: PageFormatDlg;
      2: NumberingDlg;
      4: InsertPage;
      5: DeletePage;
      6: GotoPageDlg;
      7: GotoPage(CurPage+1);
      8: GotoPage(CurPage-1);
      10: GuideDlg(1);
      11: Begin ShowMargins:=Not ShowMargins;NeedDraw:=True;End;
     End;
  4: Case I Of
      1,2: TextAttrDlg;
      4: SetStyleNormal;
      5..9: ToggleStyleBit(1 Shl (I-5));
      11..14: SetAlign(I-11);
      16: RotateDlg;
      17: Begin
        F:=SelText;
        If F=Nil Then F:=FirstSel;
        If (F<>Nil) And (F^.Kind=FK_TEXT) Then StartEdit(F,F^.TLen);
       End;
     End;
  5: Case I Of
      1: ZoomFit;
      2: SetZoom(100);
      3: SetZoom(50);
      4: SetZoom(200);
      5: ZoomDlg;
      7: Begin GridShow:=Not GridShow;NeedDraw:=True;End;
      8: Begin GridSnap:=Not GridSnap;NeedDraw:=True;End;
      9: Begin ShowFrames:=Not ShowFrames;NeedDraw:=True;End;
      11: NeedDraw:=True;
     End;
  6: Case I Of
      1: Begin OptHelp:=Not OptHelp;If Not OptHelp Then HelpMsg:='';NeedDraw:=True;End;
      2: FontsDlg;
      3: ClearGuides;
      4: StatsDlg;
      5: OptCopyAsk:=Not OptCopyAsk;
      7: PathsDlg;
      8: MiscDlg;
      10: Begin
        SaveConfig;
        MsgBox('CALAMUS',L3('Settings saved (CALAMUS.CFG).','Reglages sauves (CALAMUS.CFG).','Einstellungen gesichert (CALAMUS.CFG).'));
       End;
      11: ScanDlg;
      13: SelectAllFrames;
      15: DoUndo;
     End;
 End;
End;

Function NextItem(M,Cur,Dir: Integer): Integer;
Var I,K,N: Integer;
Begin
 N:=MCount(M);I:=Cur;
 For K:=1 To N+1 Do Begin
  I:=I+Dir;
  If I>N Then I:=1;
  If I<1 Then I:=N;
  If (Not MSep(M,I)) And MEnabled(M,I) Then Begin NextItem:=I;Exit;End;
 End;
 NextItem:=0;
End;

Procedure RunMenu(StartM: Integer; ByMouse: Boolean);
Var M,Hi,H,T: Integer; E: TEvent; Done,Pick,Redraw: Boolean;
Begin
 M:=StartM;Hi:=0;
 If Not ByMouse Then Hi:=NextItem(M,0,1);
 MenuOpen:=M;MenuHi:=Hi;
 If OptHelp Then HelpMsg:=MHelpText(M,Hi);
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
  If Redraw Then Begin
   MenuOpen:=M;MenuHi:=Hi;
   If OptHelp Then HelpMsg:=MHelpText(M,Hi) Else HelpMsg:='';
   DrawAll;
  End;
 Until Done;
 MenuOpen:=0;MenuHi:=0;HelpMsg:='';
 DrawAll;
 If Pick And (Hi>0) Then DoMenu(M,Hi);
End;

{ ====================================================================== }
{                          CLAVIER / SOURIS / PRINCIPAL                  }
{ ====================================================================== }

Procedure NudgeSel(DX,DY: Double);
Var I: Integer;
Begin
 SaveUndo;
 For I:=1 To NFr Do
  If Frs[I]^.Sel And (Frs[I]^.Page=CurPage) Then Begin
   Frs[I]^.X:=Frs[I]^.X+DX;Frs[I]^.Y:=Frs[I]^.Y+DY;
  End;
 Dirty;
End;

Procedure HandleKey(K: Word);
Begin
 { raccourcis communs (Ctrl) }
 Case K Of
  14: Begin DoNew;Exit;End;
  15: Begin DoOpen;Exit;End;
  19: Begin DoSave;Exit;End;
  17: Begin DoQuit;Exit;End;
  16: Begin DoPrintPS;Exit;End;
  1: Begin SelectAllFrames;Exit;End;
  26: Begin DoUndo;Exit;End;
  4: Begin DuplicateSel;Exit;End;
  6: Begin ZoomFit;Exit;End;
  20: Begin TextAttrDlg;Exit;End;
  2: Begin ToggleStyleBit(ST_BOLD);Exit;End;
  11: Begin ToggleStyleBit(ST_ITALIC);Exit;End;
  21: Begin ToggleStyleBit(ST_UNDER);Exit;End;
  K_F10: Begin RunMenu(1,False);Exit;End;
  K_F1: Begin KeysDlg;Exit;End;
  K_PGUP: If Not Editing Then Begin GotoPage(CurPage-1);Exit;End;
  K_PGDN: If Not Editing Then Begin GotoPage(CurPage+1);Exit;End;
 End;
 If Editing And (EditFr<>Nil) Then Begin
  EditKey(K);
  Exit;
 End;
 Case K Of
  K_ESC: Begin
    If Tool<>TL_SELECT Then SetTool(TL_SELECT) Else Begin DeselectAll;NeedDraw:=True;End;
   End;
  K_DEL: DeleteSel;
  315+1: Begin { F2 }
    If SelText<>Nil Then StartEdit(SelText,SelText^.TLen);
   End;
  K_LEFT: If CountSel>0 Then NudgeSel(-1,0) Else ScrollBy(-CvW/Sc*0.1,0);
  K_RIGHT: If CountSel>0 Then NudgeSel(1,0) Else ScrollBy(CvW/Sc*0.1,0);
  K_UP: If CountSel>0 Then NudgeSel(0,-1) Else ScrollBy(0,-CvH/Sc*0.1);
  K_DOWN: If CountSel>0 Then NudgeSel(0,1) Else ScrollBy(0,CvH/Sc*0.1);
  K_HOME: ZoomFit;
  Ord('+'),Ord('='): SetZoom(Zoom*1.25);
  Ord('-'): SetZoom(Zoom/1.25);
 End;
End;

Procedure ShowHelp(Const S: String);
Begin
 If S=HelpMsg Then Exit;
 HelpMsg:=S;
 HideMouse;
 DrawMenuBar;
 DrawHelpBox;
 ShowMouse;
End;

Procedure HandleMove(X,Y: LongInt);
Var Id: Integer; S: String;
Begin
 If InBox(X,Y,CVX1,CVY1,CVX2,CVY2) Then Begin
  UpdateInfoFromMouse(X,Y);
  InfoDX:=0;InfoDY:=0;
  RefreshInfo;
  If OptHelp Then ShowHelp('') Else If HelpMsg<>'' Then ShowHelp('');
  Exit;
 End;
 If Not OptHelp Then Begin If HelpMsg<>'' Then ShowHelp('');Exit;End;
 S:='';
 If X<PANEL_W Then Begin
  Id:=HitToolbox(X,Y);
  If Id<>IC_NONE Then S:=IconName(Id);
 End Else If (Y>=TB_Y) And (Y<TB_Y+TB_H) Then S:=ToolbarHelp(X,Y);
 ShowHelp(S);
End;

Procedure HandleLDown(X,Y: LongInt);
Var T,Id: Integer;
Begin
 If Y<MENU_H Then Begin
  T:=TitleHit(X,Y);
  If T>0 Then RunMenu(T,True);
  Exit;
 End;
 If (Y>=TB_Y) And (Y<TB_Y+TB_H) Then Begin ToolbarClick(X,Y);Exit;End;
 If (X<PANEL_W) And (Y>=WIN_Y) Then Begin
  Id:=HitToolbox(X,Y);
  If Id<>IC_NONE Then ToolboxAction(Id);
  Exit;
 End;
 If (Y>=WIN_Y) And (Y<WIN_Y+TITLE_H) Then Begin
  If InBox(X,Y,PANEL_W+4,WIN_Y+3,PANEL_W+16,WIN_Y+12) Then DoNew;
  Exit;
 End;
 If (X>=VSX1) Or (Y>=HSY1) Then Begin
  If (X>=CVX1-1) And (Y>=CVY1-1) And Not ((X>=VSX1) And (Y>=HSY1)) Then ScrollBarDown(X,Y);
  Exit;
 End;
 If InBox(X,Y,CVX1,CVY1,CVX2,CVY2) Then CanvasDown(X,Y);
End;

Procedure MainLoop;
Var E: TEvent;
Begin
 Repeat
  If NeedDraw Then DrawAll;
  PollEvent(E);
  Case E.Kind Of
   1: HandleKey(E.Key);
   2: HandleLDown(E.X,E.Y);
   4: HandleMove(E.X,E.Y);
   5: If InBox(E.X,E.Y,CVX1,CVY1,CVX2,CVY2) Then CanvasRight(E.X,E.Y);
  End;
 Until Quit;
End;

Procedure InitData;
Var I: Integer;
Begin
 Quit:=False;NeedDraw:=True;
 NFr:=0;NGV:=0;NGH:=0;
 Editing:=False;EditFr:=Nil;
 TrigAng:=-999;TrigC:=0;TrigS:=0;
 GridX:=5;GridY:=5;
 GridShow:=False;GridSnap:=False;ShowMargins:=True;ShowFrames:=True;
 UnitIdx:=1;FUnitIdx:=0;
 OptHelp:=True;OptCopyAsk:=False;OptBeep:=False;OptUndo:=True;OptAutoEdit:=True;
 PathDoc:='';PathFont:='';PathImg:='';PathTxt:='';
 ScanDpi:=300;ScanMode:=1;ScanThr:=128;
 For I:=1 To NFONT Do FontLoaded[I]:=True;
 CurFont:=1;CurSize:=12;CurStyle:=0;CurAlign:=0;CurLineSp:=100;
 CurShape:=9;CurFillMode:=1;CurLineW:=2;
 Tool:=TL_SELECT;TbPage:=0;
 HelpMsg:='';MenuOpen:=0;MenuHi:=0;
 InfoX:=0;InfoY:=0;InfoDX:=0;InfoDY:=0;
 LastClickT:=0;LastClickX:=-100;LastClickY:=-100;
 MX:=0;MY:=0;MB:=0;LastB:=0;PrevMX:=0;PrevMY:=0;
 CvW:=CVX2-CVX1+1;CvH:=CVY2-CVY1+1;ClipW:=CvW;ClipH:=CvH;
 ResetDoc;
 Zoom:=40;Sc:=Zoom/100*(96/25.4);OrgX:=0;OrgY:=0;
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
 Case Lang Of
  1: Begin
      WriteLn(H,'CALAMUS - Clone of the Calamus desktop publishing program (Atari ST).');
      WriteLn(H);
      WriteLn(H,'Usage : CALAMUS [file.CDK] [/?]');
      WriteLn(H);
      WriteLn(H,'  file.CDK  Document to open (native format).');
      WriteLn(H,'  /?        Show this help.');
      WriteLn(H);
      WriteLn(H,'Language : French by default, English if LANGUAGE=EN, German if LANGUAGE=GR.');
     End;
  2: Begin
      WriteLn(H,'CALAMUS - Clone des DTP-Programms Calamus (Atari ST).');
      WriteLn(H);
      WriteLn(H,'Aufruf : CALAMUS [Datei.CDK] [/?]');
      WriteLn(H);
      WriteLn(H,'  Datei.CDK  Zu '#246'ffnendes Dokument.');
      WriteLn(H,'  /?         Diese Hilfe anzeigen.');
      WriteLn(H);
      WriteLn(H,'Sprache : Franz'#246'sisch (Standard), Englisch bei LANGUAGE=EN, Deutsch bei LANGUAGE=GR.');
     End;
  Else Begin
      WriteLn(H,'CALAMUS - Clone du programme de PAO Calamus (Atari ST).');
      WriteLn(H);
      WriteLn(H,'Utilisation : CALAMUS [fichier.CDK] [/?]');
      WriteLn(H);
      WriteLn(H,'  fichier.CDK  Document a ouvrir (format natif).');
      WriteLn(H,'  /?           Affiche cette aide.');
      WriteLn(H);
      WriteLn(H,'Langue : francais par defaut, anglais si LANGUAGE=EN, allemand si LANGUAGE=GR.');
     End;
 End;
 Close(H);
End;

BEGIN
 Lang:=0;
 If Upper(Copy(GetEnv('LANGUAGE'),1,2))='EN' Then Lang:=1
 Else If (Upper(Copy(GetEnv('LANGUAGE'),1,2))='GR') Or
         (Upper(Copy(GetEnv('LANGUAGE'),1,2))='DE') Then Lang:=2;
 If (ParamCount>=1) And ((ParamStr(1)='/?') Or (ParamStr(1)='-h') Or
    (ParamStr(1)='--help')) Then Begin
  ShowHelpLine;
  Halt(0);
 End;
 InitData;
 InitializeGraphics;
 CaptureFont;
 If MouseDriverFound Then ShowMouse;
 LoadConfig;
 ZoomFit;
 If ParamCount>=1 Then Begin
  If LoadDocFile(ParamStr(1)) Then Begin
   DocName:=ParamStr(1);Named:=True;Modified:=False;ZoomFit;
  End;
 End;
 MainLoop;
 EraseFile('CALAMUS.UND');
 CloseGraph;
END.
