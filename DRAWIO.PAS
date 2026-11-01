{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application draw.io (diagrams.net) : editeur de
                diagrammes vectoriels fonctionnant localement. Lit et ecrit
                les fichiers .drawio / .xml de draw.io (mxfile, XML clair ou
                compresse en Base64+Deflate), exporte en SVG.
}

{ Liste de points implementes :
  ---------------------------------------------------------------------------
   1. Menus deroulants File / Edit / View / Arrange / Extras / Help (souris et
      clavier : Alt+lettre, fleches, Entree, Echap)
   2. Barre d'outils : zoom, annuler/refaire, supprimer, avant/arriere-plan,
      couleurs de remplissage et de trait, ombre, style de connexion, insertion
   3. Panneau de formes a gauche : recherche, sections General / Flowchart /
      Arrows / Lines / Misc repliables, defilement, glisser-deposer
   4. Zone de dessin : grille, zoom 10 % a 400 %, panoramique (bouton droit ou
      fleches), aimantation a la grille, selection rectangulaire (lasso)
   5. Formes : rectangle, arrondi, ellipse, losange, triangle, hexagone,
      parallelogramme, trapeze, cylindre, nuage, document, processus, etape,
      note, carte, acteur, couloir (swimlane), texte, fleches, etc.
   6. Connecteurs : droits, orthogonaux, courbes, points de passage, fleches
      de depart/fin, points d'ancrage exitX/entryX, extremites flottantes
   7. Edition du texte dans les formes et sur les connecteurs (multi-lignes)
   8. Panneau de format : Style / Texte / Arrange / Diagram (preset de couleurs,
      remplissage, trait, epaisseur, pointille, arrondi, ombre, police...)
   9. Copier / couper / coller / dupliquer, groupes et conteneurs, alignement
  10. Annuler / Refaire sur 24 niveaux (instantanes sur disque)
  11. Pages multiples (onglets en bas)
  12. Fichiers draw.io : lecture de mxfile (plusieurs pages), XML non compresse
      et compresse (Base64 + Deflate + URL), ecriture (clair ou compresse)
  13. Export SVG, import (fusion) d'un autre fichier draw.io
  14. Interface en francais par defaut, en anglais si la variable
      d'environnement LANGUAGE=EN
}

Program DRAWIO;

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$R-}
 {$OVERFLOWCHECKS OFF}
{$ELSE}
 {$M 32768,0,655360}
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
  { Turbo Pascal : essai dans le dossier du programme puis dans BGI }
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

{ ========================================================================== }
{                          CONSTANTES ET TYPES                               }
{ ========================================================================== }

Const
 SCR_W = 640;
 SCR_H = 480;

 MENU_H = 16;            { Barre de menu }
 TOOL_Y = 16;            { Barre d'outils }
 TOOL_H = 24;
 PANEL_Y = 40;           { Debut des panneaux et du canevas }
 STAT_H = 14;            { Barre d'etat }
 TAB_H = 14;             { Onglets de pages }
 LEFT_W0 = 114;          { Largeur panneau de formes }
 RIGHT_W0 = 156;         { Largeur panneau de format }

 {$IFDEF FPC}
 MAX_CELLS = 1500;
 {$ELSE}
 MAX_CELLS = 220;
 {$ENDIF}
 MAX_PTS = 10;           { Points de passage d'un connecteur }
 MAX_PAGES = 12;
 MAX_HITS = 420;
 MAX_POLY = 72;
 UNDO_N = 24;

 { Types de cellule }
 K_VERTEX = 0;
 K_EDGE = 1;
 K_LAYER = 2;

 { Formes }
 SH_RECT = 0;     SH_ELLIPSE = 1;   SH_RHOMBUS = 2;   SH_TRIANGLE = 3;
 SH_HEXAGON = 4;  SH_PARALLEL = 5;  SH_TRAPEZOID = 6; SH_CYLINDER = 7;
 SH_CLOUD = 8;    SH_DOCUMENT = 9;  SH_PROCESS = 10;  SH_STEP = 11;
 SH_NOTE = 12;    SH_CARD = 13;     SH_ACTOR = 14;    SH_SWIMLANE = 15;
 SH_TEXT = 16;    SH_LINE = 17;     SH_SARROW = 18;   SH_DARROW = 19;
 SH_DELAY = 20;   SH_DISPLAY = 21;  SH_MANUAL = 22;   SH_OFFPAGE = 23;
 SH_STENCIL = 24; SH_CUBE = 25;     SH_IMAGE = 26;

 { Evenements }
 EV_NONE = 0;  EV_KEY = 1;   EV_LDOWN = 2; EV_LUP = 3;
 EV_MOVE = 4;  EV_RDOWN = 5; EV_RUP = 6;

 { Couleurs de l'interface (indices de palette) }
 C_BLACK = 0;  C_ACCENT = 1; C_PANEL = 2;  C_BORDER = 3;  C_DARK = 4;
 C_LBLUE = 5;  C_LGREEN = 6; C_LORANGE = 7; C_LYELLOW = 8; C_LRED = 9;
 C_LPURPLE = 10; C_SBLUE = 11; C_SGREEN = 12; C_SORANGE = 13; C_SRED = 14;
 C_WHITE = 15;

 { Actions de l'interface }
 A_NONE = 0;      A_MENU = 1;      A_TOOL = 2;      A_PALITEM = 3;
 A_PALHEAD = 4;   A_TAB = 5;       A_PRESET = 6;    A_CHECK = 7;
 A_COLOR = 8;     A_SPIN = 9;      A_BTN = 10;      A_DROP = 11;
 A_PAGE = 12;     A_SEARCH = 13;   A_PALSCROLL = 14; A_SPINEDIT = 15;
 A_ALIGN = 16;

Type
 TPt = Record X, Y: LongInt; End;
 PCell = ^TCell;
 TCell = Record
  Id: String[40];
  Parent: String[40];
  Source, Target: String[40];
  Value: String[120];
  Style: String[255];
  Kind: Byte;
  X, Y, W, H: LongInt;        { Geometrie absolue (vertex) }
  NPts: Byte;
  Pts: Array[0..MAX_PTS-1] Of TPt;
  SrcPt, TgtPt: TPt;          { Extremites flottantes (edge) }
  HasSrc, HasTgt: Boolean;
  Hidden: Boolean;
  Rel: Boolean;               { Geometrie relative (etiquette de connecteur) }
  Sel: Boolean;                { Selectionne (execution) }
  SrcIdx, TgtIdx, ParIdx: Integer;  { Index resolus (execution) }
 End;

 TPoly = Record
  N: Integer;
  P: Array[0..MAX_POLY-1] Of TPt;
 End;

 TShapeDef = Record
  Name: String[20];
  Sty: String[140];
  W, H: Integer;
  Sec: Byte;
 End;

 THit = Record
  X1, Y1, X2, Y2: Integer;
  Act: Integer;
  P1, P2: LongInt;
 End;

 TDocSet = Record
  Sig: LongInt;
  N: Integer;
  GridOn, SnapOn: Boolean;
  GridSize: Integer;
  Bg: LongInt;
  PageName: String[40];
  Pad: Array[0..15] Of Byte;
 End;

 TPageInfo = Record
  Name: String[40];
  Id: String[24];
 End;
 TPageArr = Array[0..MAX_PAGES-1] Of TPageInfo;

Const
 { Palette VGA 16 couleurs adaptee a draw.io }
 PalRGB: Array[0..15] Of LongInt = (
  $000000, $4285F4, $EEEEEE, $C8C8C8, $787878, $DAE8FC, $D5E8D4, $FFE6CC,
  $FFF2CC, $F8CECC, $E1D5E7, $6C8EBF, $82B366, $D6A82B, $B85450, $FFFFFF);
 { Registre DAC du VGA correspondant a chaque couleur BGI 0..15 }
 DacIdx: Array[0..15] Of Byte = (0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63);

 { Table CP437 -> Unicode (caracteres 128..255) }
 CP437U: Array[0..127] Of Word = (
  $00C7,$00FC,$00E9,$00E2,$00E4,$00E0,$00E5,$00E7,$00EA,$00EB,$00E8,$00EF,$00EE,$00EC,$00C4,$00C5,
  $00C9,$00E6,$00C6,$00F4,$00F6,$00F2,$00FB,$00F9,$00FF,$00D6,$00DC,$00A2,$00A3,$00A5,$20A7,$0192,
  $00E1,$00ED,$00F3,$00FA,$00F1,$00D1,$00AA,$00BA,$00BF,$2310,$00AC,$00BD,$00BC,$00A1,$00AB,$00BB,
  $2591,$2592,$2593,$2502,$2524,$2561,$2562,$2556,$2555,$2563,$2551,$2557,$255D,$255C,$255B,$2510,
  $2514,$2534,$252C,$251C,$2500,$253C,$255E,$255F,$255A,$2554,$2569,$2566,$2560,$2550,$256C,$2567,
  $2568,$2564,$2565,$2559,$2558,$2552,$2553,$256B,$256A,$2518,$250C,$2588,$2584,$258C,$2590,$2580,
  $03B1,$00DF,$0393,$03C0,$03A3,$03C3,$00B5,$03C4,$03A6,$0398,$03A9,$03B4,$221E,$03C6,$03B5,$2229,
  $2261,$00B1,$2265,$2264,$2320,$2321,$00F7,$2248,$00B0,$2219,$00B7,$221A,$207F,$00B2,$25A0,$00A0);

 { Lettres de remplacement pour U+00C0..U+00FF absents de CP437 }
 LatinFold = 'AAAAAAACEEEEIIIIDNOOOOOxOUUUUYTsaaaaaaaceeeeiiiidnooooo/ouuuuyty';

 { Presets de couleurs (fill, stroke) de draw.io }
 PresetFill: Array[0..7] Of LongInt = (
  $FFFFFF, $F5F5F5, $DAE8FC, $D5E8D4, $FFE6CC, $FFF2CC, $F8CECC, $E1D5E7);
 PresetStroke: Array[0..7] Of LongInt = (
  $000000, $666666, $6C8EBF, $82B366, $D79B00, $D6B656, $B85450, $9673A6);

 SecNames: Array[0..4] Of String[10] = ('General','Flowchart','Arrows','Lines','Misc');
 NSEC = 5;

 ZoomSteps: Array[0..13] Of Integer = (10,25,33,50,67,75,100,125,150,175,200,250,300,400);

Var
 { Etat graphique }
 OfsX, OfsY: Integer;       { Origine d'ecran des coordonnees de dessin }
 LeftW, RightW: Integer;
 CX1, CY1, CX2, CY2: Integer;   { Rectangle de la zone de dessin }
 ViewX, ViewY: LongInt;         { Coin haut-gauche visible (coord. document) }
 Zoom: Integer;                 { Pourcentage }

 { Document }
 Cells: Array[1..MAX_CELLS] Of PCell;
 NCells: Integer;
 IdCounter: LongInt;
 GridOn, SnapOn: Boolean;
 GridSize: Integer;
 BgColor: LongInt;               { -1 = aucun }
 Modified: Boolean;
 FileName: String;
 CompressedSave: Boolean;
 PageName: String[40];
 Pages: TPageArr;
 NPages, CurPage: Integer;

 { Interface }
 Hits: Array[0..MAX_HITS-1] Of THit;
 NHits: Integer;
 ShowLeft, ShowRight: Boolean;
 PalOpen: Array[0..NSEC-1] Of Boolean;
 PalScroll, PalTotal: Integer;
 SearchText: String[30];
 SearchFocus: Boolean;
 FmtTab: Integer;
 Running: Boolean;
 ActiveMenu: Integer;
 ActiveItem: Integer;
 MenuOpen: Boolean;
 StatusMsg: String;
 DefaultEdgeStyle: Byte;   { 0 droit, 1 orthogonal, 2 courbe }
 StyleClip: String;        { Presse-papiers de style }
 DefaultVStyle: String;    { Style par defaut des nouveaux sommets }
 DefaultEStyle: String;

 { Evenements }
 EvKey: Char;
 EvExt: Boolean;
 EvX, EvY: Integer;
 EvDbl: Boolean;
 OldMX, OldMY: LongInt;
 OldMB: LongInt;
 LastClickT: LongInt;
 LastClickX, LastClickY: Integer;
 Names0, StyleTmp: String;
 EditRaw: Boolean;        { Champ de nom de fichier : octets bruts (pas d'UTF-8) }
 EditFresh: Boolean;      { Texte initial d'un champ : remplace a la premiere frappe }
 GhostOn, HoverOn: Boolean;   { Ghost XOR et fleches de survol affiches }
 Editing: Boolean;          { Edition d'etiquette en cours }
 HoverIdx: Integer;
 EditHide: Integer;        { Cellule dont l'etiquette est en cours d'edition }
 PageTag: Char;

{ ========================================================================== }
{                          UTILITAIRES DE CHAINES                            }
{ ========================================================================== }

Function IStr(N: LongInt): String;
Var S: String;
Begin
 Str(N,S); IStr:=S;
End;

Function IVal(Const S: String; Def: LongInt): LongInt;
Var N: LongInt; Code: Integer;
Begin
 Val(S,N,Code);
 If Code<>0 Then IVal:=Def Else IVal:=N;
End;

Function UpStr(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:=S;
 For I:=1 To Length(R) Do
  If (R[I]>='a') And (R[I]<='z') Then R[I]:=Chr(Ord(R[I])-32);
 UpStr:=R;
End;

Function LoStr(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:=S;
 For I:=1 To Length(R) Do
  If (R[I]>='A') And (R[I]<='Z') Then R[I]:=Chr(Ord(R[I])+32);
 LoStr:=R;
End;

Function TrimStr(Const S: String): String;
Var A, B: Integer;
Begin
 A:=1; B:=Length(S);
 While (A<=B) And (S[A]<=' ') Do Inc(A);
 While (B>=A) And (S[B]<=' ') Do Dec(B);
 TrimStr:=Copy(S,A,B-A+1);
End;

Function Min(A, B: LongInt): LongInt;
Begin
 If A<B Then Min:=A Else Min:=B;
End;

Function Max(A, B: LongInt): LongInt;
Begin
 If A>B Then Max:=A Else Max:=B;
End;

Function Abs32(A: LongInt): LongInt;
Begin
 If A<0 Then Abs32:=-A Else Abs32:=A;
End;

Function Sgn(A: LongInt): Integer;
Begin
 If A<0 Then Sgn:=-1 Else If A>0 Then Sgn:=1 Else Sgn:=0;
End;

Function Clamp(V, A, B: LongInt): LongInt;
Begin
 If V<A Then V:=A;
 If V>B Then V:=B;
 Clamp:=V;
End;

Function HexDigit(N: Integer): Char;
Begin
 If N<10 Then HexDigit:=Chr(48+N) Else HexDigit:=Chr(55+N);
End;

Function HexVal(C: Char): Integer;
Begin
 If (C>='0') And (C<='9') Then HexVal:=Ord(C)-48
 Else If (C>='A') And (C<='F') Then HexVal:=Ord(C)-55
 Else If (C>='a') And (C<='f') Then HexVal:=Ord(C)-87
 Else HexVal:=-1;
End;

Function Hex2(B: Integer): String;
Begin
 Hex2:=HexDigit((B shr 4) And 15)+HexDigit(B And 15);
End;

{ Couleur RGB (LongInt $RRGGBB) vers '#RRGGBB' }
Function RGBToHex(C: LongInt): String;
Begin
 RGBToHex:='#'+Hex2((C shr 16) And 255)+Hex2((C shr 8) And 255)+Hex2(C And 255);
End;

{ Analyse '#RGB', '#RRGGBB' ou 'RRGGBB'. Retourne False si invalide. }
Function HexToRGB(Const S: String; Var C: LongInt): Boolean;
Var T: String; I, V: Integer; R: LongInt;
Begin
 HexToRGB:=False;
 T:=S;
 If (Length(T)>0) And (T[1]='#') Then Delete(T,1,1);
 If Length(T)=3 Then T:=T[1]+T[1]+T[2]+T[2]+T[3]+T[3];
 If Length(T)<>6 Then Exit;
 R:=0;
 For I:=1 To 6 Do Begin
  V:=HexVal(T[I]);
  If V<0 Then Exit;
  R:=R*16+V;
 End;
 C:=R;
 HexToRGB:=True;
End;

{ Nombre decimal eventuellement signe (ex. -12.5) arrondi a l'entier }
Function ParseNum(Const S: String): LongInt;
Var I: Integer; Neg: Boolean; N: LongInt; FracDig: Integer; HalfUp: Boolean;
Begin
 I:=1; Neg:=False; N:=0; HalfUp:=False;
 While (I<=Length(S)) And (S[I]=' ') Do Inc(I);
 If (I<=Length(S)) And ((S[I]='-') Or (S[I]='+')) Then Begin
  Neg:=S[I]='-'; Inc(I);
 End;
 While (I<=Length(S)) And (S[I]>='0') And (S[I]<='9') Do Begin
  If N<100000000 Then N:=N*10+Ord(S[I])-48;
  Inc(I);
 End;
 If (I<=Length(S)) And (S[I]='.') Then Begin
  Inc(I); FracDig:=0;
  While (I<=Length(S)) And (S[I]>='0') And (S[I]<='9') Do Begin
   If FracDig=0 Then HalfUp:=(S[I]>='5');
   Inc(FracDig); Inc(I);
  End;
  If HalfUp Then Inc(N);
 End;
 If Neg Then N:=-N;
 ParseNum:=N;
End;

{ Conversion entre l'UTF-8 interne et l'affichage CP437 }
Function U8ToCP(Const S: String): String;
Var I, J: Integer; R: String; B: Integer; U: LongInt; Found: Boolean;
Begin
 R:=''; I:=1;
 While I<=Length(S) Do Begin
  B:=Ord(S[I]);
  If B<128 Then Begin
   If (B<>0) And (B<>13) Then R:=R+S[I];
   Inc(I);
  End Else Begin
   U:=0;
   If (B And $E0)=$C0 Then Begin
    If I<Length(S) Then U:=((B And $1F) Shl 6) Or (Ord(S[I+1]) And $3F);
    Inc(I,2);
   End Else If (B And $F0)=$E0 Then Begin
    If I+1<=Length(S) Then
     U:=((B And $0F) Shl 12) Or ((Ord(S[I+1]) And $3F) Shl 6) Or (Ord(S[I+2]) And $3F);
    Inc(I,3);
   End Else Begin
    Inc(I,4); U:=63;
   End;
   Found:=False;
   For J:=0 To 127 Do
    If CP437U[J]=U Then Begin R:=R+Chr(128+J); Found:=True; Break; End;
   If Not Found Then Begin
    If (U>=$C0) And (U<=$FF) Then R:=R+LatinFold[U-$C0+1]
    Else If U=$2019 Then R:=R+''''
    Else If (U=$2013) Or (U=$2014) Then R:=R+'-'
    Else If U=$2022 Then R:=R+#7
    Else R:=R+'?';
   End;
  End;
 End;
 U8ToCP:=R;
End;

{ Caractere CP437 saisi au clavier vers UTF-8 }
Function CPToU8(C: Char): String;
Var U: Word;
Begin
 If Ord(C)<128 Then CPToU8:=C
 Else Begin
  U:=CP437U[Ord(C)-128];
  If U<$800 Then CPToU8:=Chr($C0 Or (U Shr 6))+Chr($80 Or (U And $3F))
  Else CPToU8:=Chr($E0 Or (U Shr 12))+Chr($80 Or ((U Shr 6) And $3F))+Chr($80 Or (U And $3F));
 End;
End;

{ Longueur (octets) du dernier caractere UTF-8 }
Function LastCharLen(Const S: String): Integer;
Var I: Integer;
Begin
 I:=Length(S);
 If I=0 Then Begin LastCharLen:=0; Exit; End;
 While (I>1) And ((Ord(S[I]) And $C0)=$80) Do Dec(I);
 LastCharLen:=Length(S)-I+1;
End;

{ Memoire libre sur le tas (Free Pascal : toujours suffisante) }
Function HeapFree: LongInt;
Begin
 {$IFDEF FPC}
 HeapFree:=MaxLongInt;
 {$ELSE}
 HeapFree:=MaxAvail;
 {$ENDIF}
End;

{ Ticks en centiemes de seconde }
Function Ticks: LongInt;
Var H, M, S, S100: Word;
Begin
 GetTime(H,M,S,S100);
 Ticks:=((LongInt(H)*60+M)*60+S)*100+S100;
End;

{ ========================================================================== }
{               LANGUE : francais par defaut, anglais si LANGUAGE=EN         }
{ ========================================================================== }

Type
 TTrEntry = Record
  E: String[40];
  F: String[44];
 End;

Const
 NTR = 194;
 TrTable: Array[0..NTR-1] Of TTrEntry = (
  (E:'File'; F:'Fichier'),
  (E:'Edit'; F:'Edition'),
  (E:'View'; F:'Affichage'),
  (E:'Arrange'; F:'Organiser'),
  (E:'Extras'; F:'Extras'),
  (E:'Help'; F:'Aide'),
  (E:'New'; F:'Nouveau'),
  (E:'Open...'; F:'Ouvrir...'),
  (E:'Save'; F:'Enreg.'),
  (E:'Save as...'; F:'Enregistrer sous...'),
  (E:'Import from file...'; F:'Importer un fichier...'),
  (E:'Export as SVG...'; F:'Exporter en SVG...'),
  (E:'Export as XML...'; F:'Exporter en XML...'),
  (E:'Exit'; F:'Quitter'),
  (E:'Undo'; F:'Annuler'),
  (E:'Redo'; F:'Rétablir'),
  (E:'Cut'; F:'Couper'),
  (E:'Copy'; F:'Copier'),
  (E:'Paste'; F:'Coller'),
  (E:'Delete'; F:'Supprimer'),
  (E:'Duplicate'; F:'Dupliquer'),
  (E:'Edit Style...'; F:'Modifier le style...'),
  (E:'Edit Label'; F:'Modifier le texte'),
  (E:'Copy Style'; F:'Copier le style'),
  (E:'Paste Style'; F:'Coller le style'),
  (E:'Select All'; F:'Tout sélectionner'),
  (E:'Select None'; F:'Rien sélectionner'),
  (E:'Select Vertices'; F:'Sélect. les formes'),
  (E:'Select Edges'; F:'Sélect. les liens'),
  (E:'Shapes'; F:'Formes'),
  (E:'Format'; F:'Format'),
  (E:'Grid'; F:'Grille'),
  (E:'Snap to Grid'; F:'Aimanter à la grille'),
  (E:'Zoom In'; F:'Zoom avant'),
  (E:'Zoom Out'; F:'Zoom arrière'),
  (E:'Reset Zoom (100%)'; F:'Zoom 100 %'),
  (E:'Fit to Window'; F:'Ajuster à la fenêtre'),
  (E:'To Front'; F:'Premier plan'),
  (E:'To Back'; F:'Arrière-plan'),
  (E:'Bring Forward'; F:'Avancer'),
  (E:'Send Backward'; F:'Reculer'),
  (E:'Group'; F:'Grouper'),
  (E:'Ungroup'; F:'Dégrouper'),
  (E:'Align Left'; F:'Aligner à gauche'),
  (E:'Align Center'; F:'Aligner au centre'),
  (E:'Align Right'; F:'Aligner à droite'),
  (E:'Align Top'; F:'Aligner en haut'),
  (E:'Align Middle'; F:'Aligner au milieu'),
  (E:'Align Bottom'; F:'Aligner en bas'),
  (E:'Distribute Horizontally'; F:'Répartir horizontalement'),
  (E:'Distribute Vertically'; F:'Répartir verticalement'),
  (E:'Clear Waypoints'; F:'Effacer les points'),
  (E:'Compressed XML'; F:'XML compressé'),
  (E:'Grid Size...'; F:'Taille de la grille...'),
  (E:'Background Color...'; F:'Couleur de fond...'),
  (E:'New edges: Straight'; F:'Nouveaux liens : droits'),
  (E:'New edges: Orthogonal'; F:'Nouveaux liens : orthogonaux'),
  (E:'New edges: Curved'; F:'Nouveaux liens : courbes'),
  (E:'Add Page'; F:'Ajouter une page'),
  (E:'Delete Page'; F:'Supprimer la page'),
  (E:'Rename Page...'; F:'Renommer la page...'),
  (E:'Previous Page'; F:'Page précédente'),
  (E:'Next Page'; F:'Page suivante'),
  (E:'Keyboard Shortcuts'; F:'Raccourcis clavier'),
  (E:'About DRAWIO'; F:'À propos de DRAWIO'),
  (E:'Del'; F:'Suppr'),
  (E:'Search Shapes'; F:'Rechercher'),
  (E:'General'; F:'Général'),
  (E:'Flowchart'; F:'Organigr.'),
  (E:'Arrows'; F:'Flèches'),
  (E:'Lines'; F:'Lignes'),
  (E:'Misc'; F:'Divers'),
  (E:'Diagram'; F:'Diagramme'),
  (E:'Snap to grid'; F:'Aimanter'),
  (E:'Background'; F:'Fond'),
  (E:'Reset View'; F:'Réinit. vue'),
  (E:'Page: '; F:'Page : '),
  (E:'Objects: '; F:'Objets : '),
  (E:'Zoom: '; F:'Zoom : '),
  (E:'Fill'; F:'Remplir'),
  (E:'Gradient'; F:'Dégradé'),
  (E:'Line'; F:'Trait'),
  (E:'Solid'; F:'Plein'),
  (E:'Dashed'; F:'Tirets'),
  (E:'Dotted'; F:'Points'),
  (E:'Opacity'; F:'Opacité'),
  (E:'Rounded'; F:'Arrondi'),
  (E:'Shadow'; F:'Ombre'),
  (E:'Glass'; F:'Verre'),
  (E:'Comic'; F:'Comique'),
  (E:'Edit Style'; F:'Modifier le style'),
  (E:'Set as Default'; F:'Défaut du style'),
  (E:'Connection'; F:'Connexion'),
  (E:'Start'; F:'Début'),
  (E:'End'; F:'Fin'),
  (E:'Size '; F:'Taille '),
  (E:'Align'; F:'Aligner'),
  (E:'Vert.'; F:'Vert.'),
  (E:'Word wrap'; F:'Retour auto'),
  (E:'Font color'; F:'Coul. texte'),
  (E:'Label bg'; F:'Fond texte'),
  (E:'Position'; F:'Position'),
  (E:'Size'; F:'Taille'),
  (E:'Forward'; F:'Avancer'),
  (E:'Backward'; F:'Reculer'),
  (E:'Straight'; F:'Droit'),
  (E:'Orthogonal'; F:'Orthogonal'),
  (E:'Elbow'; F:'Coudé'),
  (E:'Curved'; F:'Courbe'),
  (E:'Entity Relation'; F:'Entité-relation'),
  (E:'Style'; F:'Style'),
  (E:'Text'; F:'Texte'),
  (E:'Arrange*'; F:'Ordre'),
  (E:'DistH'; F:'EspH'),
  (E:'DistV'; F:'EspV'),
  (E:'Untitled'; F:'Sans titre'),
  (E:'Rectangle'; F:'Rectangle'),
  (E:'Rounded Rectangle'; F:'Rectangle arrondi'),
  (E:'Ellipse'; F:'Ellipse'),
  (E:'Diamond'; F:'Losange'),
  (E:'Swimlane'; F:'Couloir'),
  (E:'Arrow'; F:'Flèche'),
  (E:'OK'; F:'OK'),
  (E:'Yes'; F:'Oui'),
  (E:'No'; F:'Non'),
  (E:'Cancel'; F:'Annuler'),
  (E:'None'; F:'Aucune'),
  (E:'All files'; F:'Tous'),
  (E:'File name:'; F:'Nom :'),
  (E:'Confirm'; F:'Confirmation'),
  (E:'Palette colors:'; F:'Couleurs de la palette :'),
  (E:'Other colors:'; F:'Autres couleurs :'),
  (E:'Hex value (#RRGGBB, none):'; F:'Valeur hexa (#RRGGBB, none) :'),
  (E:'Color'; F:'Couleur'),
  (E:'Background color'; F:'Couleur de fond'),
  (E:'New value:'; F:'Nouvelle valeur :'),
  (E:'Value'; F:'Valeur'),
  (E:'Grid size'; F:'Taille de la grille'),
  (E:'Grid size (pixels):'; F:'Taille de la grille (pixels) :'),
  (E:'Style (key=value;...):'; F:'Style (clé=valeur;...) :'),
  (E:'Open'; F:'Ouvrir'),
  (E:'Save as'; F:'Enregistrer sous'),
  (E:'Import from file'; F:'Importer un fichier'),
  (E:'Export as SVG'; F:'Exporter en SVG'),
  (E:'Export as XML'; F:'Exporter en XML'),
  (E:'Rename page'; F:'Renommer la page'),
  (E:'Page name:'; F:'Nom de la page :'),
  (E:'Pages'; F:'Pages'),
  (E:'Import'; F:'Importer'),
  (E:'Export'; F:'Exporter'),
  (E:'Unsaved changes'; F:'Modifications non enregistrées'),
  (E:'Nothing to undo'; F:'Rien à annuler'),
  (E:'Nothing to redo'; F:'Rien à rétablir'),
  (E:'Too many objects'; F:'Trop d''objets'),
  (E:'Corrupt compressed data'; F:'Données compressées corrompues'),
  (E:'Cannot open file'; F:'Ouverture du fichier impossible'),
  (E:'Cannot create file'; F:'Création du fichier impossible'),
  (E:'Nothing to copy'; F:'Rien à copier'),
  (E:' object(s) copied'; F:' objet(s) copié(s)'),
  (E:'Clipboard is empty'; F:'Le presse-papiers est vide'),
  (E:'Nothing pasted'; F:'Rien n''a été collé'),
  (E:'Select a group to ungroup'; F:'Sélectionnez un groupe à dégrouper'),
  (E:'Select two or more shapes'; F:'Sélectionnez au moins deux formes'),
  (E:'Too many pages'; F:'Trop de pages'),
  (E:'A diagram needs at least one page'; F:'Un diagramme doit avoir au moins une page'),
  (E:'File '; F:'Le fichier '),
  (E:' exists. Overwrite?'; F:' existe. Remplacer ?'),
  (E:'Saved '; F:'Enregistré : '),
  (E:'Cannot save the file. '; F:'Enregistrement impossible. '),
  (E:'File not found: '; F:'Fichier introuvable : '),
  (E:'This file is not a draw.io diagram.'; F:'Ce fichier n''est pas un diagramme draw.io.'),
  (E:'Cannot read the diagram. '; F:'Lecture du diagramme impossible. '),
  (E:'Opened '; F:'Ouvert : '),
  (E:' object(s) imported'; F:' objet(s) importé(s)'),
  (E:'Exported '; F:'Exporté : '),
  (E:'Cannot write the SVG file.'; F:'Écriture du fichier SVG impossible.'),
  (E:'Cannot write the file.'; F:'Écriture du fichier impossible.'),
  (E:'Select a shape first'; F:'Sélectionnez d''abord une forme'),
  (E:'Style copied'; F:'Style copié'),
  (E:'No style copied'; F:'Aucun style copié'),
  (E:'Default style updated'; F:'Style par défaut mis à jour'),
  (E:'Connection: straight'; F:'Connexion : droite'),
  (E:'Connection: orthogonal'; F:'Connexion : orthogonale'),
  (E:'Connection: curved'; F:'Connexion : courbe'),
  (E:'Select a connector'; F:'Sélectionnez un lien'),
  (E:'Connection to the same shape cancelled'; F:'Connexion à la même forme annulée'),
  (E:'Multi-select ON'; F:'Sélection multiple activée'),
  (E:'Multi-select OFF'; F:'Sélection multiple désactivée'),
  (E:' selected'; F:' sélectionné(s)'),
  (E:'Fit window'; F:'Ajuster'),
  (E:'Reset Zoom'; F:'Zoom 100 %'),
  (E:'Erreur'; F:'Erreur'),
  (E:'Rename Page'; F:'Renommer la page'),
  (E:'Home'; F:'Début'));

Var
 LangFr: Boolean;     { Vrai : interface en francais }

{ Choisit la langue d'apres la variable d'environnement LANGUAGE (EN = anglais) }
Procedure InitLanguage;
Var L: String; I: Integer;
Begin
 L:=GetEnv('LANGUAGE');
 For I:=1 To Length(L) Do If (L[I]>='a') And (L[I]<='z') Then L[I]:=Chr(Ord(L[I])-32);
 LangFr:=Not ((Length(L)>=2) And (Copy(L,1,2)='EN'));
End;

{ Traduit un libelle (liste d'elements separes par '|' acceptee) }
Function Tr(Const S: String): String;
Var I, P: Integer; R, Part: String; Found: Boolean;
 Function One(Const K: String): String;
 Var J: Integer;
 Begin
  One:=K;
  For J:=0 To NTR-1 Do If TrTable[J].E=K Then Begin One:=TrTable[J].F; Exit; End;
 End;
Begin
 If Not LangFr Then Begin Tr:=S; Exit; End;
 If Pos('|',S)=0 Then Begin Tr:=One(S); Exit; End;
 R:=''; Part:='';
 For I:=1 To Length(S)+1 Do Begin
  If (I>Length(S)) Or (S[I]='|') Then Begin
   If R<>'' Then R:=R+'|';
   R:=R+One(Part); Part:='';
  End Else Part:=Part+S[I];
 End;
 Tr:=R;
End;

{ Texte long : version anglaise ou francaise }
Function Fr(Const En, Fre: String): String;
Begin
 If LangFr Then Fr:=Fre Else Fr:=En;
End;

{ ========================================================================== }
{                      STYLES (chaines "cle=valeur;...")                     }
{ ========================================================================== }

{ Recupere la valeur d'une cle de style. Retourne False si absente. }
Function StyGet(Const Sty, Key: String; Var V: String): Boolean;
Var I, P, Q: Integer;
Begin
 StyGet:=False; V:='';
 I:=1;
 While I<=Length(Sty) Do Begin
  P:=I;
  While (P<=Length(Sty)) And (Sty[P]<>';') Do Inc(P);
  Q:=I;
  While (Q<P) And (Sty[Q]<>'=') Do Inc(Q);
  If (Q<P) And (Q-I=Length(Key)) And (Copy(Sty,I,Q-I)=Key) Then Begin
   V:=Copy(Sty,Q+1,P-Q-1);
   StyGet:=True; Exit;
  End;
  I:=P+1;
 End;
End;

Function StyStr(Const Sty, Key, Def: String): String;
Var V: String;
Begin
 If StyGet(Sty,Key,V) Then StyStr:=V Else StyStr:=Def;
End;

Function StyInt(Const Sty, Key: String; Def: LongInt): LongInt;
Var V: String;
Begin
 If StyGet(Sty,Key,V) Then StyInt:=ParseNum(V) Else StyInt:=Def;
End;

Function StyBool(Const Sty, Key: String; Def: Boolean): Boolean;
Var V: String;
Begin
 If StyGet(Sty,Key,V) Then StyBool:=(V='1') Or (V='true') Else StyBool:=Def;
End;

{ Premier jeton sans "=" (ex. "ellipse", "swimlane", "text") }
Function StyKeyless(Const Sty: String): String;
Var I, P, Q: Integer;
Begin
 StyKeyless:='';
 I:=1;
 While I<=Length(Sty) Do Begin
  P:=I;
  While (P<=Length(Sty)) And (Sty[P]<>';') Do Inc(P);
  Q:=I;
  While (Q<P) And (Sty[Q]<>'=') Do Inc(Q);
  If (Q>=P) And (P>I) Then Begin StyKeyless:=Copy(Sty,I,P-I); Exit; End;
  I:=P+1;
 End;
End;

{ Supprime une cle }
Procedure StyDel(Var Sty: String; Const Key: String);
Var I, P, Q: Integer; R: String;
Begin
 R:=''; I:=1;
 While I<=Length(Sty) Do Begin
  P:=I;
  While (P<=Length(Sty)) And (Sty[P]<>';') Do Inc(P);
  Q:=I;
  While (Q<P) And (Sty[Q]<>'=') Do Inc(Q);
  If Not ((Q<P) And (Q-I=Length(Key)) And (Copy(Sty,I,Q-I)=Key)) Then
   If P>I Then R:=R+Copy(Sty,I,P-I)+';';
  I:=P+1;
 End;
 Sty:=R;
End;

{ Definit une cle (remplace ou ajoute) }
Procedure StySet(Var Sty: String; Const Key, Val: String);
Var R: String;
Begin
 R:=Sty;
 StyDel(R,Key);
 If (R<>'') And (R[Length(R)]<>';') Then R:=R+';';
 If Length(R)+Length(Key)+Length(Val)+2<=255 Then Begin
  R:=R+Key+'='+Val+';';
  Sty:=R;
 End;
End;

{ Valeur fractionnaire *100 (ex. 0.5 -> 50). Retourne False si absente. }
Function StyFrac(Const Sty, Key: String; Var V100: Integer): Boolean;
Var S: String; I: Integer; Neg: Boolean; N, F: LongInt; Dig: Integer;
Begin
 StyFrac:=False;
 If Not StyGet(Sty,Key,S) Then Exit;
 If S='' Then Exit;
 I:=1; Neg:=False; N:=0; F:=0; Dig:=0;
 If S[1]='-' Then Begin Neg:=True; Inc(I); End;
 While (I<=Length(S)) And (S[I]>='0') And (S[I]<='9') Do Begin N:=N*10+Ord(S[I])-48; Inc(I); End;
 If (I<=Length(S)) And (S[I]='.') Then Begin
  Inc(I);
  While (I<=Length(S)) And (S[I]>='0') And (S[I]<='9') And (Dig<2) Do Begin
   F:=F*10+Ord(S[I])-48; Inc(Dig); Inc(I);
  End;
  If Dig=1 Then F:=F*10;
 End;
 N:=N*100+F;
 If Neg Then N:=-N;
 V100:=N;
 StyFrac:=True;
End;

{ Couleur d'un style : -1 = aucune, -2 = absente/defaut }
Function ParseColor(Const S: String; Def: LongInt): LongInt;
Var C: LongInt; P: Integer; T: String;
Begin
 T:=LoStr(S);
 If (T='') Or (T='default') Or (T='inherit') Then Begin ParseColor:=Def; Exit; End;
 If T='none' Then Begin ParseColor:=-1; Exit; End;
 If T='white' Then Begin ParseColor:=$FFFFFF; Exit; End;
 If T='black' Then Begin ParseColor:=$000000; Exit; End;
 If T='red' Then Begin ParseColor:=$FF0000; Exit; End;
 If T='green' Then Begin ParseColor:=$008000; Exit; End;
 If T='blue' Then Begin ParseColor:=$0000FF; Exit; End;
 If T='yellow' Then Begin ParseColor:=$FFFF00; Exit; End;
 If T='gray' Then Begin ParseColor:=$808080; Exit; End;
 If T='orange' Then Begin ParseColor:=$FFA500; Exit; End;
 P:=Pos('#',T);
 If P>0 Then Begin
  If HexToRGB(Copy(T,P,7),C) Then Begin ParseColor:=C; Exit; End;
 End;
 ParseColor:=Def;
End;

{ Couleur RGB vers l'indice de palette le plus proche }
Function PalOf(Rgb: LongInt): Integer;
Var I, Best: Integer; D, BD: LongInt; R, G, B, PR, PG, PB: Integer;
Begin
 If Rgb<0 Then Begin PalOf:=C_WHITE; Exit; End;
 R:=(Rgb Shr 16) And 255; G:=(Rgb Shr 8) And 255; B:=Rgb And 255;
 Best:=0; BD:=999999999;
 For I:=0 To 15 Do Begin
  If I=C_ACCENT Then Continue;
  PR:=(PalRGB[I] Shr 16) And 255; PG:=(PalRGB[I] Shr 8) And 255; PB:=PalRGB[I] And 255;
  D:=2*LongInt(R-PR)*(R-PR)+4*LongInt(G-PG)*(G-PG)+3*LongInt(B-PB)*(B-PB);
  If D<BD Then Begin BD:=D; Best:=I; End;
 End;
 PalOf:=Best;
End;

{ ========================================================================== }
{                              POOL DE CELLULES                              }
{ ========================================================================== }

Function FindId(Const Id: String): Integer;
Var I: Integer;
Begin
 FindId:=0;
 If Id='' Then Exit;
 For I:=1 To NCells Do
  If Cells[I]^.Id=Id Then Begin FindId:=I; Exit; End;
End;

Function MakeId: String;
Var S: String;
Begin
 Repeat
  Inc(IdCounter);
  S:='dw'+IStr(IdCounter);
 Until FindId(S)=0;
 MakeId:=S;
End;

Function NewCell(Kind: Byte): Integer;
Var P: PCell;
Begin
 NewCell:=0;
 If NCells>=MAX_CELLS Then Exit;
 If HeapFree<LongInt(SizeOf(TCell))+4096 Then Exit;
 New(P);
 FillChar(P^,SizeOf(TCell),0);
 P^.Kind:=Kind;
 P^.Parent:='1';
 Inc(NCells);
 Cells[NCells]:=P;
 NewCell:=NCells;
End;

Procedure ResolveLinks;
Var I, J, D: Integer;
Begin
 For I:=1 To NCells Do
  With Cells[I]^ Do Begin
   SrcIdx:=FindId(Source); TgtIdx:=FindId(Target);
   ParIdx:=FindId(Parent);
   If ParIdx=I Then ParIdx:=0;
   If ParIdx>0 Then
    If Cells[ParIdx]^.Kind=K_LAYER Then ParIdx:=0;
  End;
 { Elimine les boucles de parente }
 For I:=1 To NCells Do Begin
  J:=Cells[I]^.ParIdx; D:=0;
  While (J>0) And (J<>I) And (D<=NCells) Do Begin J:=Cells[J]^.ParIdx; Inc(D); End;
  If (J=I) Or (D>NCells) Then Begin Cells[I]^.ParIdx:=0; Cells[I]^.Parent:='1'; End;
 End;
End;

Procedure FreeCellAt(I: Integer);
Var J: Integer;
Begin
 Dispose(Cells[I]);
 For J:=I To NCells-1 Do Cells[J]:=Cells[J+1];
 Cells[NCells]:=Nil;
 Dec(NCells);
End;

Procedure ClearDoc;
Var I: Integer;
Begin
 For I:=1 To NCells Do Begin Dispose(Cells[I]); Cells[I]:=Nil; End;
 NCells:=0;
End;

{ Vrai si la cellule I est un descendant de A (groupe / conteneur) }
Function IsDescendant(I, A: Integer): Boolean;
Var J, D: Integer;
Begin
 IsDescendant:=False;
 J:=Cells[I]^.ParIdx; D:=0;
 While (J>0) And (D<12) Do Begin
  If J=A Then Begin IsDescendant:=True; Exit; End;
  J:=Cells[J]^.ParIdx; Inc(D);
 End;
End;

Function Visible(I: Integer): Boolean;
Var J, D: Integer;
Begin
 Visible:=False;
 If Cells[I]^.Hidden Then Exit;
 J:=Cells[I]^.ParIdx; D:=0;
 While (J>0) And (D<12) Do Begin
  If Cells[J]^.Hidden Then Exit;
  J:=Cells[J]^.ParIdx; Inc(D);
 End;
 Visible:=True;
End;

Procedure ClearSel;
Var I: Integer;
Begin
 For I:=1 To NCells Do Cells[I]^.Sel:=False;
End;

Function SelCount: Integer;
Var I, N: Integer;
Begin
 N:=0;
 For I:=1 To NCells Do If Cells[I]^.Sel Then Inc(N);
 SelCount:=N;
End;

Function FirstSel: Integer;
Var I: Integer;
Begin
 FirstSel:=0;
 For I:=1 To NCells Do If Cells[I]^.Sel Then Begin FirstSel:=I; Exit; End;
End;

{ Etiquette d'un connecteur (sommet enfant d'un edge) }
Function IsEdgeLabel(I: Integer): Boolean;
Begin
 IsEdgeLabel:=False;
 With Cells[I]^ Do
  If (Kind=K_VERTEX) And (ParIdx>0) Then
   If Cells[ParIdx]^.Kind=K_EDGE Then IsEdgeLabel:=True;
End;

Function CellShape(I: Integer): Byte;
Var Sty, S: String;
Begin
 Sty:=Cells[I]^.Style;
 If Not StyGet(Sty,'shape',S) Then S:=StyKeyless(Sty);
 S:=LoStr(S);
 CellShape:=SH_RECT;
 If (S='ellipse') Or (S='doubleellipse') Or (S='umlstart') Or (S='mxgraph.flowchart.on-page_reference') Then CellShape:=SH_ELLIPSE
 Else If (S='rhombus') Or (S='mxgraph.flowchart.decision') Then CellShape:=SH_RHOMBUS
 Else If S='triangle' Then CellShape:=SH_TRIANGLE
 Else If S='hexagon' Then CellShape:=SH_HEXAGON
 Else If S='parallelogram' Then CellShape:=SH_PARALLEL
 Else If S='trapezoid' Then CellShape:=SH_TRAPEZOID
 Else If (S='cylinder') Or (S='cylinder3') Or (S='datastore') Then CellShape:=SH_CYLINDER
 Else If S='cloud' Then CellShape:=SH_CLOUD
 Else If (S='document') Or (S='tape') Then CellShape:=SH_DOCUMENT
 Else If S='process' Then CellShape:=SH_PROCESS
 Else If S='step' Then CellShape:=SH_STEP
 Else If S='note' Then CellShape:=SH_NOTE
 Else If S='card' Then CellShape:=SH_CARD
 Else If (S='umlactor') Or (S='actor') Then CellShape:=SH_ACTOR
 Else If S='swimlane' Then CellShape:=SH_SWIMLANE
 Else If S='text' Then CellShape:=SH_TEXT
 Else If S='line' Then CellShape:=SH_LINE
 Else If S='singlearrow' Then CellShape:=SH_SARROW
 Else If S='doublearrow' Then CellShape:=SH_DARROW
 Else If S='delay' Then CellShape:=SH_DELAY
 Else If S='display' Then CellShape:=SH_DISPLAY
 Else If S='manualinput' Then CellShape:=SH_MANUAL
 Else If S='offpageconnector' Then CellShape:=SH_OFFPAGE
 Else If S='cube' Then CellShape:=SH_CUBE
 Else If (S='image') Or (S='label') And (StyStr(Sty,'image','')<>'') Then CellShape:=SH_IMAGE
 Else If Copy(S,1,8)='mxgraph.' Then CellShape:=SH_STENCIL;
End;

Function CellFill(I: Integer): LongInt;
Var Def: LongInt; Sh: Byte;
Begin
 Sh:=CellShape(I);
 Def:=$FFFFFF;
 If (Sh=SH_TEXT) Or (Sh=SH_LINE) Or (Sh=SH_IMAGE) Or (StyKeyless(Cells[I]^.Style)='group') Then Def:=-1;
 CellFill:=ParseColor(StyStr(Cells[I]^.Style,'fillColor',''),Def);
End;

Function CellStroke(I: Integer): LongInt;
Var Def: LongInt; Sh: Byte;
Begin
 Sh:=CellShape(I);
 Def:=$000000;
 If (Sh=SH_TEXT) Or (Sh=SH_IMAGE) Or (StyKeyless(Cells[I]^.Style)='group') Then Def:=-1;
 If Cells[I]^.Kind=K_EDGE Then Def:=$000000;
 CellStroke:=ParseColor(StyStr(Cells[I]^.Style,'strokeColor',''),Def);
End;

Function CellFontColor(I: Integer): LongInt;
Begin
 CellFontColor:=ParseColor(StyStr(Cells[I]^.Style,'fontColor',''),$000000);
End;

{ ========================================================================== }
{                       PALETTE ET PRIMITIVES GRAPHIQUES                     }
{ ========================================================================== }

Procedure SetupPalette;
Var I, R, G, B: Integer;
Begin
 For I:=0 To 15 Do Begin
  R:=(PalRGB[I] Shr 16) And 255; G:=(PalRGB[I] Shr 8) And 255; B:=PalRGB[I] And 255;
  {$IFDEF FPC}
  { ptcgraph : numero de couleur 0..15 et valeurs 0..255 }
  SetRGBPalette(I,R,G,B);
  {$ELSE}
  Port[$3C8]:=DacIdx[I];
  Port[$3C9]:=R Shr 2;
  Port[$3C9]:=G Shr 2;
  Port[$3C9]:=B Shr 2;
  {$ENDIF}
 End;
End;

Function Cl(V: LongInt): Integer;
Begin
 If V<-30000 Then V:=-30000;
 If V>30000 Then V:=30000;
 Cl:=V;
End;

Function SX(X: LongInt): LongInt;
Begin
 SX:=OfsX+((X-ViewX)*Zoom) Div 100;
End;

Function SY(Y: LongInt): LongInt;
Begin
 SY:=OfsY+((Y-ViewY)*Zoom) Div 100;
End;

Function DX(X: LongInt): LongInt;  { ecran -> document }
Begin
 DX:=ViewX+((X-CX1)*100) Div Zoom;
End;

Function DY(Y: LongInt): LongInt;
Begin
 DY:=ViewY+((Y-CY1)*100) Div Zoom;
End;

Function ZL(L: LongInt): LongInt;  { longueur document -> ecran }
Begin
 ZL:=(L*Zoom) Div 100;
End;

Procedure DLine(X1, Y1, X2, Y2: LongInt);
Begin
 Line(Cl(X1),Cl(Y1),Cl(X2),Cl(Y2));
End;

Procedure DBar(X1, Y1, X2, Y2: LongInt; Col: Integer);
Begin
 If (X2<X1) Or (Y2<Y1) Then Exit;
 SetFillStyle(SolidFill,Col);
 Bar(Cl(X1),Cl(Y1),Cl(X2),Cl(Y2));
End;

Procedure DRect(X1, Y1, X2, Y2: LongInt; Col: Integer);
Begin
 SetColor(Col);
 Rectangle(Cl(X1),Cl(Y1),Cl(X2),Cl(Y2));
End;

{ Texte deja en CP437 }
Procedure DTextRaw(X, Y: LongInt; Const S: String; Col: Integer);
Begin
 SetColor(Col);
 OutTextXY(Cl(X),Cl(Y),S);
End;

{ Texte UTF-8 (converti pour la police CP437) }
Procedure DText(X, Y: LongInt; Const S: String; Col: Integer);
Begin
 SetColor(Col);
 OutTextXY(Cl(X),Cl(Y),U8ToCP(S));
End;

Function ULen(Const S: String): Integer;
Begin
 ULen:=Length(U8ToCP(S));
End;

Procedure Pen(Dashed: Byte; Width: Integer);
Var Th: Integer;
Begin
 If Width>=2 Then Th:=ThickWidth Else Th:=NormWidth;
 Case Dashed Of
  1: SetLineStyle(DashedLn,0,Th);
  2: SetLineStyle(DottedLn,0,Th);
 Else SetLineStyle(SolidLn,0,Th);
 End;
End;

Procedure PenReset;
Begin
 SetLineStyle(SolidLn,0,NormWidth);
End;

{ Polygone en coordonnees document (transforme par SX/SY).
  Fill<0 : pas de remplissage ; Stroke<0 : pas de trait. }
Procedure PolyDraw(Var P: TPoly; Fill, Stroke: Integer; Closed: Boolean);
Var Q: Array[0..MAX_POLY] Of PointType; I, N: Integer;
Begin
 N:=P.N;
 If N<2 Then Exit;
 For I:=0 To N-1 Do Begin
  Q[I].X:=Cl(SX(P.P[I].X)); Q[I].Y:=Cl(SY(P.P[I].Y));
 End;
 If (Fill>=0) And Closed And (N>=3) Then Begin
  SetFillStyle(SolidFill,Fill);
  If Stroke>=0 Then SetColor(Stroke) Else SetColor(Fill);
  FillPoly(N,Q);
 End Else If Stroke>=0 Then Begin
  SetColor(Stroke);
  If Closed Then Begin Q[N]:=Q[0]; DrawPoly(N+1,Q); End
  Else DrawPoly(N,Q);
 End;
End;

Procedure PAdd(Var P: TPoly; X, Y: LongInt);
Begin
 If P.N<MAX_POLY Then Begin
  P.P[P.N].X:=X; P.P[P.N].Y:=Y; Inc(P.N);
 End;
End;

{ Boite en relief de l'interface }
Procedure Bevel(X1, Y1, X2, Y2: Integer; Raised: Boolean; Fill: Integer);
Begin
 If Fill>=0 Then DBar(X1,Y1,X2,Y2,Fill);
 If Raised Then SetColor(C_WHITE) Else SetColor(C_DARK);
 DLine(X1,Y1,X2-1,Y1); DLine(X1,Y1,X1,Y2-1);
 If Raised Then SetColor(C_DARK) Else SetColor(C_WHITE);
 DLine(X2,Y1,X2,Y2); DLine(X1,Y2,X2,Y2);
End;

Procedure Frame(X1, Y1, X2, Y2: Integer; Col: Integer);
Begin
 DRect(X1,Y1,X2,Y2,Col);
End;

Procedure ResetHits;
Begin
 NHits:=0;
End;

Procedure AddHit(X1, Y1, X2, Y2, Act: Integer; P1, P2: LongInt);
Begin
 If NHits>=MAX_HITS Then Exit;
 Hits[NHits].X1:=X1; Hits[NHits].Y1:=Y1; Hits[NHits].X2:=X2; Hits[NHits].Y2:=Y2;
 Hits[NHits].Act:=Act; Hits[NHits].P1:=P1; Hits[NHits].P2:=P2;
 Inc(NHits);
End;

Function FindHit(X, Y: Integer): Integer;
Var I: Integer;
Begin
 FindHit:=-1;
 For I:=NHits-1 DownTo 0 Do
  If (X>=Hits[I].X1) And (X<=Hits[I].X2) And (Y>=Hits[I].Y1) And (Y<=Hits[I].Y2) Then Begin
   FindHit:=I; Exit;
  End;
End;

Procedure SetText(Size: Integer);
Begin
 SetTextStyle(DefaultFont,HorizDir,Size);
End;

Function TW(Const S: String): Integer;
Begin
 TW:=TextWidth(U8ToCP(S));
End;

{ Texte centre dans une boite (interface), couleur Col }
Procedure TextC(X1, X2, Y: Integer; Const S: String; Col: Integer);
Var T: String;
Begin
 T:=U8ToCP(S);
 DTextRaw((X1+X2-TextWidth(T)) Div 2,Y,T,Col);
End;

{ ========================================================================== }
{                       GEOMETRIE DES FORMES (polygones)                     }
{ ========================================================================== }

Const
 BRK = -999999999;   { Marque de rupture dans les polylignes d'extras }

Var
 OBX, OBY, OBW, OBH: LongInt;   { Boite d'orientation }
 ODir: Integer;                 { 0 est, 1 sud, 2 ouest, 3 nord }

Function DirOf(Const Sty: String): Integer;
Var S: String;
Begin
 S:=LoStr(StyStr(Sty,'direction','east'));
 DirOf:=0;
 If S='south' Then DirOf:=1 Else If S='west' Then DirOf:=2 Else If S='north' Then DirOf:=3;
End;

{ Ajoute un point canonique (U,V) oriente dans la boite }
Procedure PO(Var P: TPoly; U, V: LongInt);
Var X, Y: LongInt;
Begin
 Case ODir Of
  1: Begin X:=OBX+OBW-V; Y:=OBY+U; End;
  2: Begin X:=OBX+OBW-U; Y:=OBY+OBH-V; End;
  3: Begin X:=OBX+V; Y:=OBY+OBH-U; End;
 Else Begin X:=OBX+U; Y:=OBY+V; End;
 End;
 PAdd(P,X,Y);
End;

Procedure PArc(Var P: TPoly; CxU, CyV, RxU, RyV: LongInt; A0, A1: Real; Steps: Integer;
               Orient: Boolean);
Var K: Integer; A: Real; U, V: LongInt;
Begin
 For K:=0 To Steps Do Begin
  A:=A0+(A1-A0)*K/Steps;
  U:=CxU+Round(RxU*Cos(A)); V:=CyV+Round(RyV*Sin(A));
  If Orient Then PO(P,U,V) Else PAdd(P,U,V);
 End;
End;

Function ArcRadius(Const Sty: String; W, H: LongInt): LongInt;
Var F: LongInt; R: LongInt;
Begin
 F:=StyInt(Sty,'arcSize',15);
 If StyBool(Sty,'absoluteArcSize',False) Then R:=Min(F,Min(W,H) Div 2)
 Else R:=Min(W,H)*F Div 100;
 If R<0 Then R:=0;
 ArcRadius:=R;
End;

{ Construit le contour principal M et les traits supplementaires E (separes
  par BRK) de la forme du sommet I, en coordonnees document. }
Procedure BuildShape(I: Integer; Var M, E: TPoly);
Var C: PCell; Sty: String; Sh: Byte; X, Y, W, H, CW, CH, D, R, S1: LongInt;
    K, F1, F2: Integer; A, Sc: Real; Rounded: Boolean;
Begin
 M.N:=0; E.N:=0;
 C:=Cells[I]; X:=C^.X; Y:=C^.Y; W:=C^.W; H:=C^.H;
 Sty:=C^.Style; Sh:=CellShape(I);
 If W<1 Then W:=1;
 If H<1 Then H:=1;
 ODir:=DirOf(Sty);
 OBX:=X; OBY:=Y; OBW:=W; OBH:=H;
 If Odd(ODir) Then Begin CW:=H; CH:=W; End Else Begin CW:=W; CH:=H; End;
 Rounded:=StyBool(Sty,'rounded',False);
 Case Sh Of
  SH_ELLIPSE:
   For K:=0 To 35 Do Begin
    A:=2*Pi*K/36;
    PAdd(M,X+W Div 2+Round(W*Cos(A)/2),Y+H Div 2+Round(H*Sin(A)/2));
   End;
  SH_RHOMBUS: Begin
   PAdd(M,X+W Div 2,Y); PAdd(M,X+W,Y+H Div 2);
   PAdd(M,X+W Div 2,Y+H); PAdd(M,X,Y+H Div 2);
  End;
  SH_TRIANGLE: Begin
   PO(M,0,0); PO(M,CW,CH Div 2); PO(M,0,CH);
  End;
  SH_HEXAGON: Begin
   D:=CW*25 Div 100;
   PO(M,D,0); PO(M,CW-D,0); PO(M,CW,CH Div 2); PO(M,CW-D,CH); PO(M,D,CH); PO(M,0,CH Div 2);
  End;
  SH_PARALLEL: Begin
   D:=CW*20 Div 100;
   PO(M,D,0); PO(M,CW,0); PO(M,CW-D,CH); PO(M,0,CH);
  End;
  SH_TRAPEZOID: Begin
   D:=CW*20 Div 100;
   PO(M,0,CH); PO(M,D,0); PO(M,CW-D,0); PO(M,CW,CH);
  End;
  SH_STEP: Begin
   D:=Min(CW Div 4,CH Div 2+4);
   PO(M,0,0); PO(M,CW-D,0); PO(M,CW,CH Div 2); PO(M,CW-D,CH); PO(M,0,CH); PO(M,D,CH Div 2);
  End;
  SH_DELAY: Begin
   PO(M,0,0); PO(M,CW Div 2,0);
   For K:=1 To 11 Do Begin
    A:=-Pi/2+Pi*K/12;
    PO(M,CW Div 2+Round(CW*Cos(A)/2),CH Div 2+Round(CH*Sin(A)/2));
   End;
   PO(M,CW Div 2,CH); PO(M,0,CH);
  End;
  SH_DISPLAY: Begin
   D:=Min(CW Div 5,CH Div 2);
   PO(M,0,CH Div 2); PO(M,D,0); PO(M,CW-D,0);
   For K:=1 To 9 Do Begin
    A:=-Pi/2+Pi*K/10;
    PO(M,CW-D+Round(D*Cos(A)),CH Div 2+Round(CH*Sin(A)/2));
   End;
   PO(M,CW-D,CH); PO(M,D,CH);
  End;
  SH_MANUAL: Begin
   PO(M,0,CH Div 5); PO(M,CW,0); PO(M,CW,CH); PO(M,0,CH);
  End;
  SH_OFFPAGE: Begin
   PO(M,0,0); PO(M,CW,0); PO(M,CW,CH*3 Div 4); PO(M,CW Div 2,CH); PO(M,0,CH*3 Div 4);
  End;
  SH_SARROW: Begin
   If Not StyFrac(Sty,'arrowWidth',F1) Then F1:=40;
   If Not StyFrac(Sty,'arrowSize',F2) Then F2:=40;
   S1:=CH*F1 Div 100;
   D:=CW*F2 Div 100;
   PO(M,0,(CH-S1) Div 2); PO(M,CW-D,(CH-S1) Div 2); PO(M,CW-D,0); PO(M,CW,CH Div 2);
   PO(M,CW-D,CH); PO(M,CW-D,(CH+S1) Div 2); PO(M,0,(CH+S1) Div 2);
  End;
  SH_DARROW: Begin
   If Not StyFrac(Sty,'arrowWidth',F1) Then F1:=40;
   If Not StyFrac(Sty,'arrowSize',F2) Then F2:=30;
   S1:=CH*F1 Div 100;
   D:=Min(CW Div 2,CW*F2 Div 100);
   PO(M,0,CH Div 2); PO(M,D,0); PO(M,D,(CH-S1) Div 2); PO(M,CW-D,(CH-S1) Div 2);
   PO(M,CW-D,0); PO(M,CW,CH Div 2); PO(M,CW-D,CH); PO(M,CW-D,(CH+S1) Div 2);
   PO(M,D,(CH+S1) Div 2); PO(M,D,CH);
  End;
  SH_CYLINDER: Begin
   D:=Min(15,H Div 4);
   If D<4 Then D:=4;
   PArc(M,W Div 2,D Div 2,W Div 2,D Div 2,Pi,2*Pi,10,False);
   PArc(M,W Div 2,H-D Div 2,W Div 2,D Div 2,0,Pi,10,False);
   For K:=0 To M.N-1 Do Begin M.P[K].X:=M.P[K].X+X; M.P[K].Y:=M.P[K].Y+Y; End;
   For K:=0 To 10 Do Begin
    A:=Pi*K/10;
    PAdd(E,X+W Div 2+Round(W*Cos(A)/2),Y+D Div 2+Round(D*Sin(A)/2));
   End;
  End;
  SH_CLOUD:
   For K:=0 To 47 Do Begin
    A:=2*Pi*K/48;
    Sc:=0.86+0.14*Abs(Sin(4*A));
    PAdd(M,X+W Div 2+Round(W*Cos(A)*Sc/2),Y+H Div 2+Round(H*Sin(A)*Sc/2));
   End;
  SH_DOCUMENT: Begin
   D:=Max(4,H*15 Div 100);
   PAdd(M,X,Y); PAdd(M,X+W,Y);
   For K:=0 To 16 Do Begin
    A:=2*Pi*K/16;
    PAdd(M,X+W-W*K Div 16,Y+H-D+Round(D*Sin(A)));
   End;
  End;
  SH_PROCESS: Begin
   PAdd(M,X,Y); PAdd(M,X+W,Y); PAdd(M,X+W,Y+H); PAdd(M,X,Y+H);
   D:=W*10 Div 100;
   PAdd(E,X+D,Y); PAdd(E,X+D,Y+H); PAdd(E,BRK,0);
   PAdd(E,X+W-D,Y); PAdd(E,X+W-D,Y+H);
  End;
  SH_NOTE: Begin
   D:=Min(18,Min(W,H) Div 2);
   PAdd(M,X,Y); PAdd(M,X+W-D,Y); PAdd(M,X+W,Y+D); PAdd(M,X+W,Y+H); PAdd(M,X,Y+H);
   PAdd(E,X+W-D,Y); PAdd(E,X+W-D,Y+D); PAdd(E,X+W,Y+D);
  End;
  SH_CARD: Begin
   D:=Min(18,Min(W,H) Div 2);
   PAdd(M,X+D,Y); PAdd(M,X+W,Y); PAdd(M,X+W,Y+H); PAdd(M,X,Y+H); PAdd(M,X,Y+D);
  End;
  SH_CUBE: Begin
   D:=Min(W,H) Div 4;
   PAdd(M,X,Y+D); PAdd(M,X+D,Y); PAdd(M,X+W,Y); PAdd(M,X+W,Y+H-D); PAdd(M,X+W-D,Y+H); PAdd(M,X,Y+H);
   PAdd(E,X,Y+D); PAdd(E,X+W-D,Y+D); PAdd(E,X+W,Y); PAdd(E,BRK,0);
   PAdd(E,X+W-D,Y+D); PAdd(E,X+W-D,Y+H);
  End;
  SH_ACTOR: Begin
   { Tete + corps : le contour principal est la tete }
   R:=Min(W Div 2,H Div 5);
   For K:=0 To 15 Do Begin
    A:=2*Pi*K/16;
    PAdd(M,X+W Div 2+Round(R*Cos(A)),Y+R+Round(R*Sin(A)));
   End;
   PAdd(E,X+W Div 2,Y+2*R); PAdd(E,X+W Div 2,Y+H*60 Div 100); PAdd(E,BRK,0);
   PAdd(E,X,Y+H*40 Div 100); PAdd(E,X+W,Y+H*40 Div 100); PAdd(E,BRK,0);
   PAdd(E,X,Y+H); PAdd(E,X+W Div 2,Y+H*60 Div 100); PAdd(E,X+W,Y+H);
  End;
 Else Begin
  If Rounded And (Sh<>SH_TEXT) Then Begin
   R:=ArcRadius(Sty,W,H);
   If R<1 Then R:=1;
   PArc(M,X+R,Y+R,R,R,Pi,1.5*Pi,5,False);
   PArc(M,X+W-R,Y+R,R,R,1.5*Pi,2*Pi,5,False);
   PArc(M,X+W-R,Y+H-R,R,R,0,Pi/2,5,False);
   PArc(M,X+R,Y+H-R,R,R,Pi/2,Pi,5,False);
  End Else Begin
   PAdd(M,X,Y); PAdd(M,X+W,Y); PAdd(M,X+W,Y+H); PAdd(M,X,Y+H);
  End;
 End;
 End;
End;

{ ========================================================================== }
{                             TEXTE / ETIQUETTES                             }
{ ========================================================================== }

Type
 TLines = Record
  N: Integer;
  S: Array[1..14] Of String[80];
 End;

{ Decoupe un texte en lignes (retours chariot et mots) pour la largeur Wpx }
Procedure WrapText(Const T: String; Wpx: Integer; Wrap: Boolean; Var L: TLines);
Var I: Integer; Cur, Wrd: String;
 Procedure Flush;
 Begin
  If L.N<14 Then Begin Inc(L.N); L.S[L.N]:=Cur; End;
  Cur:='';
 End;
 Procedure AddWord;
 Var Try: String;
 Begin
  If Wrd='' Then Exit;
  If Cur='' Then Try:=Wrd Else Try:=Cur+' '+Wrd;
  If Wrap And (Cur<>'') And (TextWidth(Try)>Wpx) Then Begin
   Flush; Cur:=Wrd;
  End Else Cur:=Try;
  Wrd:='';
 End;
Begin
 L.N:=0; Cur:=''; Wrd:='';
 For I:=1 To Length(T) Do Begin
  If T[I]=#10 Then Begin AddWord; Flush; End
  Else If T[I]=' ' Then AddWord
  Else If Length(Wrd)<78 Then Wrd:=Wrd+T[I];
 End;
 AddWord;
 If (Cur<>'') Or (L.N=0) Then Flush;
End;

{ Dessine une etiquette dans la boite document (BX,BY,BW,BH).
  AH : 0 gauche 1 centre 2 droite ; AV : 0 haut 1 milieu 2 bas }
Procedure DrawLabel(Const Txt: String; BX, BY, BW, BH: LongInt; AH, AV: Integer;
                    FontSize: Integer; Col: Integer; FStyle: Integer; Wrap: Boolean;
                    BgCol: Integer; Spc: Integer);
Var Sp, Cs, Lh, I, Tw: Integer; L: TLines; X0, Y0, X1, Y1, Th, Px, Py: LongInt; T: String;
Begin
 If Txt='' Then Exit;
 Sp:=Integer(ZL(FontSize));
 If Sp<7 Then Exit;
 Cs:=(Sp+3) Div 9;
 If Cs<1 Then Cs:=1;
 If Cs>6 Then Cs:=6;
 SetText(Cs);
 T:=U8ToCP(Txt);
 X0:=SX(BX)+Spc; X1:=SX(BX+BW)-Spc;
 Y0:=SY(BY); Y1:=SY(BY+BH);
 If X1<X0 Then X1:=X0;
 WrapText(T,Integer(X1-X0),Wrap,L);
 Lh:=TextHeight('A')+2;
 Th:=LongInt(L.N)*Lh-2;
 Case AV Of
  0: Py:=Y0+2;
  2: Py:=Y1-Th-2;
 Else Py:=(Y0+Y1-Th) Div 2;
 End;
 For I:=1 To L.N Do Begin
  Tw:=TextWidth(L.S[I]);
  Case AH Of
   0: Px:=X0;
   2: Px:=X1-Tw;
  Else Px:=(X0+X1-Tw) Div 2;
  End;
  If BgCol>=0 Then DBar(Px-1,Py-1,Px+Tw,Py+Lh-3,BgCol);
  DTextRaw(Px,Py,L.S[I],Col);
  If (FStyle And 1)<>0 Then DTextRaw(Px+1,Py,L.S[I],Col);
  If (FStyle And 4)<>0 Then Begin SetColor(Col); DLine(Px,Py+Lh-3,Px+Tw,Py+Lh-3); End;
  Py:=Py+Lh;
 End;
 SetText(1);
End;

{ Etiquette d'un sommet selon son style }
Procedure DrawVertexLabel(I: Integer);
Var C: PCell; Sty, S: String; BX, BY, BW, BH: LongInt; AH, AV, Fs, Fst, Sp: Integer;
    LPos, VPos: String; Sh: Byte; Bg: LongInt; BgI: Integer; Sz: LongInt;
Begin
 C:=Cells[I];
 If (C^.Value='') Or (I=EditHide) Then Exit;
 Sty:=C^.Style; Sh:=CellShape(I);
 BX:=C^.X; BY:=C^.Y; BW:=C^.W; BH:=C^.H;
 S:=LoStr(StyStr(Sty,'align','center'));
 AH:=1; If S='left' Then AH:=0 Else If S='right' Then AH:=2;
 S:=LoStr(StyStr(Sty,'verticalAlign','middle'));
 AV:=1; If S='top' Then AV:=0 Else If S='bottom' Then AV:=2;
 LPos:=LoStr(StyStr(Sty,'labelPosition','center'));
 VPos:=LoStr(StyStr(Sty,'verticalLabelPosition','middle'));
 If LPos='left' Then Begin BX:=BX-BW; End
 Else If LPos='right' Then Begin BX:=BX+BW; End;
 If VPos='top' Then Begin BY:=BY-BH; End
 Else If VPos='bottom' Then Begin BY:=BY+BH; End;
 If Sh=SH_SWIMLANE Then Begin
  Sz:=StyInt(Sty,'startSize',23);
  If StyBool(Sty,'horizontal',True) Then BH:=Sz Else Begin BW:=Sz; End;
 End;
 If Sh=SH_ACTOR Then Begin
  If (VPos='middle') And (StyStr(Sty,'verticalAlign','')='') Then Begin BY:=BY+BH; AV:=0; End;
 End;
 Fs:=Integer(StyInt(Sty,'fontSize',12));
 Fst:=Integer(StyInt(Sty,'fontStyle',0));
 Sp:=Integer(StyInt(Sty,'spacing',2))+2;
 Bg:=ParseColor(StyStr(Sty,'labelBackgroundColor',''),-1);
 If Bg>=0 Then BgI:=PalOf(Bg) Else BgI:=-1;
 DrawLabel(C^.Value,BX,BY,BW,BH,AH,AV,Fs,PalOf(CellFontColor(I)),Fst,
           StyStr(Sty,'whiteSpace','')='wrap',BgI,Sp);
End;

{ ========================================================================== }
{                           DESSIN DES SOMMETS                               }
{ ========================================================================== }

Var
 NoCull: Boolean;      { Vrai pour les miniatures (hors de la zone de dessin) }

{ Remplissage en degrade (bandes) entre deux couleurs RGB }
Procedure DrawGradient(X1, Y1, X2, Y2: LongInt; C1, C2: LongInt; Const Dir: String);
Var K, Steps: Integer; R, G, B, T: LongInt; Col: LongInt; Horiz, Rev: Boolean; L, A, Bb: LongInt;
Begin
 Horiz:=(Dir='east') Or (Dir='west');
 Rev:=(Dir='north') Or (Dir='west');
 If Horiz Then L:=X2-X1+1 Else L:=Y2-Y1+1;
 Steps:=Integer(Min(16,Max(2,L Div 3)));
 For K:=0 To Steps-1 Do Begin
  T:=K*100 Div (Steps-1);
  If Rev Then T:=100-T;
  R:=((C1 Shr 16) And 255)*(100-T) Div 100+((C2 Shr 16) And 255)*T Div 100;
  G:=((C1 Shr 8) And 255)*(100-T) Div 100+((C2 Shr 8) And 255)*T Div 100;
  B:=(C1 And 255)*(100-T) Div 100+(C2 And 255)*T Div 100;
  Col:=(R Shl 16) Or (G Shl 8) Or B;
  A:=K*L Div Steps; Bb:=(K+1)*L Div Steps-1;
  If K=Steps-1 Then Bb:=L-1;
  If Horiz Then DBar(X1+A,Y1,X1+Bb,Y2,PalOf(Col)) Else DBar(X1,Y1+A,X2,Y1+Bb,PalOf(Col));
 End;
End;

{ Degrade dans un polygone (coordonnees document), par balayage }
Procedure PolyGradient(Var P: TPoly; C1, C2: LongInt; Const Dir: String);
Var Q: Array[0..MAX_POLY] Of TPt; N, I, K, J, Cnt: Integer; Xs: Array[0..15] Of LongInt;
    Ymin, Ymax, Lo, Hi, V, T, Tmp, Xa, Xb: LongInt; Horiz, Rev: Boolean; R, G, Bl: LongInt; Col: Integer;
Begin
 N:=P.N;
 If N<3 Then Exit;
 Horiz:=(Dir='east') Or (Dir='west');
 Rev:=(Dir='north') Or (Dir='west');
 { Coordonnees ecran (axe de balayage = Y, ou X si Horiz) }
 For I:=0 To N-1 Do Begin
  If Horiz Then Begin Q[I].X:=SY(P.P[I].Y); Q[I].Y:=SX(P.P[I].X); End
  Else Begin Q[I].X:=SX(P.P[I].X); Q[I].Y:=SY(P.P[I].Y); End;
 End;
 Ymin:=Q[0].Y; Ymax:=Q[0].Y;
 For I:=1 To N-1 Do Begin
  If Q[I].Y<Ymin Then Ymin:=Q[I].Y;
  If Q[I].Y>Ymax Then Ymax:=Q[I].Y;
 End;
 If Ymax=Ymin Then Exit;

 For V:=Ymin To Ymax Do Begin
  T:=(V-Ymin)*100 Div (Ymax-Ymin);
  If Rev Then T:=100-T;
  R:=((C1 Shr 16) And 255)*(100-T) Div 100+((C2 Shr 16) And 255)*T Div 100;
  G:=((C1 Shr 8) And 255)*(100-T) Div 100+((C2 Shr 8) And 255)*T Div 100;
  Bl:=(C1 And 255)*(100-T) Div 100+(C2 And 255)*T Div 100;
  Col:=PalOf((R Shl 16) Or (G Shl 8) Or Bl);
  Cnt:=0;
  For I:=0 To N-1 Do Begin
   K:=(I+1) Mod N;
   Lo:=Q[I].Y; Hi:=Q[K].Y;
   If Lo=Hi Then Continue;
   If ((V>=Lo) And (V<Hi)) Or ((V>=Hi) And (V<Lo)) Then
    If Cnt<16 Then Begin
     Xs[Cnt]:=Q[I].X+(V-Lo)*(Q[K].X-Q[I].X) Div (Hi-Lo); Inc(Cnt);
    End;
  End;
  For I:=1 To Cnt-1 Do Begin
   Tmp:=Xs[I]; J:=I-1;
   While (J>=0) And (Xs[J]>Tmp) Do Begin Xs[J+1]:=Xs[J]; Dec(J); End;
   Xs[J+1]:=Tmp;
  End;
  SetColor(Col);
  I:=0;
  While I+1<Cnt Do Begin
   Xa:=Xs[I]; Xb:=Xs[I+1];
   If Horiz Then DLine(V,Xa,V,Xb) Else DLine(Xa,V,Xb,V);
   Inc(I,2);
  End;
 End;
End;

Procedure DrawVertexShape(I: Integer; Selected: Boolean);
Var C: PCell; M, E: TPoly; Sty: String; Fill, Stroke: LongInt; Fi, Si, K, Sw: Integer;
    Dash: Byte; Shp: Byte; X1, Y1, X2, Y2: LongInt; Sz: LongInt; Horiz: Boolean;
    SwFill, Gr: LongInt; Q: TPoly;
Begin
 C:=Cells[I]; Sty:=C^.Style; Shp:=CellShape(I);
 X1:=SX(C^.X); Y1:=SY(C^.Y); X2:=SX(C^.X+C^.W); Y2:=SY(C^.Y+C^.H);
 If (Not NoCull) And ((X2<OfsX) Or (X1>OfsX+CX2-CX1) Or (Y2<OfsY) Or (Y1>OfsY+CY2-CY1)) Then Begin
  { Hors ecran (sauf si l'etiquette deborde) }
  If Not ((StyStr(Sty,'verticalLabelPosition','')<>'') Or (StyStr(Sty,'labelPosition','')<>'')) Then Exit;
 End;
 Fill:=CellFill(I); Stroke:=CellStroke(I);
 If Fill>=0 Then Fi:=PalOf(Fill) Else Fi:=-1;
 If Stroke>=0 Then Si:=PalOf(Stroke) Else Si:=-1;
 Sw:=Integer(StyInt(Sty,'strokeWidth',1));
 Dash:=0;
 If StyBool(Sty,'dashed',False) Then Begin
  Dash:=1;
  If Copy(StyStr(Sty,'dashPattern',''),1,2)='1 ' Then Dash:=2;
 End;
 If Shp=SH_TEXT Then Begin
  DrawVertexLabel(I);
  Exit;
 End;
 If Shp=SH_STENCIL Then Begin
  { Pochoir non supporte : rectangle clair avec croix }
  If Fi<0 Then Fi:=C_WHITE;
  If Si<0 Then Si:=C_DARK;
 End;
 If Shp=SH_LINE Then Begin
  Pen(Dash,Sw);
  If Si<0 Then Si:=C_BLACK;
  SetColor(Si);
  DLine(X1,(Y1+Y2) Div 2,X2,(Y1+Y2) Div 2);
  PenReset;
  DrawVertexLabel(I);
  Exit;
 End;
 If Shp=SH_SWIMLANE Then Begin
  Horiz:=StyBool(Sty,'horizontal',True);
  Sz:=ZL(StyInt(Sty,'startSize',23));
  SwFill:=ParseColor(StyStr(Sty,'swimlaneFillColor',''),-1);
  If SwFill>=0 Then DBar(X1,Y1,X2,Y2,PalOf(SwFill));
  If Fi>=0 Then Begin
   If Horiz Then DBar(X1,Y1,X2,Y1+Sz,Fi) Else DBar(X1,Y1,X1+Sz,Y2,Fi);
  End;
  If Si>=0 Then Begin
   Pen(Dash,Sw);
   DRect(X1,Y1,X2,Y2,Si);
   If Horiz Then DLine(X1,Y1+Sz,X2,Y1+Sz) Else DLine(X1+Sz,Y1,X1+Sz,Y2);
   PenReset;
  End;
  DrawVertexLabel(I);
  Exit;
 End;
 BuildShape(I,M,E);
 If StyBool(Sty,'shadow',False) Then Begin
  Q:=M;
  For K:=0 To Q.N-1 Do Begin Inc(Q.P[K].X,3); Inc(Q.P[K].Y,3); End;
  If Shp=SH_ELLIPSE Then Begin
   SetFillStyle(SolidFill,C_BORDER);
   SetColor(C_BORDER);
   FillEllipse(Cl(SX((C^.X+C^.W Div 2)+3)),Cl(SY((C^.Y+C^.H Div 2)+3)),Cl(ZL(C^.W) Div 2),Cl(ZL(C^.H) Div 2));
  End Else PolyDraw(Q,C_BORDER,C_BORDER,True);
 End;
 Pen(Dash,Sw);
 Gr:=ParseColor(StyStr(Sty,'gradientColor',''),-1);
 If (Shp=SH_ELLIPSE) And (Gr>=0) And (Fi>=0) Then Begin
  PolyGradient(M,Fill,Gr,LoStr(StyStr(Sty,'gradientDirection','south')));
  PolyDraw(M,-1,Si,True);
 End Else If Shp=SH_ELLIPSE Then Begin
  If Fi>=0 Then Begin
   SetFillStyle(SolidFill,Fi);
   If Si>=0 Then SetColor(Si) Else SetColor(Fi);
   FillEllipse(Cl((X1+X2) Div 2),Cl((Y1+Y2) Div 2),Cl((X2-X1) Div 2),Cl((Y2-Y1) Div 2));
  End Else If Si>=0 Then Begin
   SetColor(Si);
   Ellipse(Cl((X1+X2) Div 2),Cl((Y1+Y2) Div 2),0,360,Cl((X2-X1) Div 2),Cl((Y2-Y1) Div 2));
  End;
  If StyStr(Sty,'shape','')='doubleEllipse' Then Begin
   SetColor(Si);
   Ellipse(Cl((X1+X2) Div 2),Cl((Y1+Y2) Div 2),0,360,Cl((X2-X1) Div 2-3),Cl((Y2-Y1) Div 2-3));
  End;
 End Else If (M.N=4) And (Shp=SH_RECT) And (Fi<>-1) And (M.P[0].X=C^.X) And (M.P[1].X=C^.X+C^.W) Then Begin
  { Rectangle simple : Bar + Rectangle (rapide) }
  If Fi>=0 Then Begin
   Gr:=ParseColor(StyStr(Sty,'gradientColor',''),-1);
   If Gr>=0 Then DrawGradient(X1,Y1,X2,Y2,Fill,Gr,LoStr(StyStr(Sty,'gradientDirection','south')))
   Else DBar(X1,Y1,X2,Y2,Fi);
  End;
  If Si>=0 Then Begin SetColor(Si); Rectangle(Cl(X1),Cl(Y1),Cl(X2),Cl(Y2)); End;
 End Else Begin
  Gr:=ParseColor(StyStr(Sty,'gradientColor',''),-1);
  If (Gr>=0) And (Fi>=0) And (Shp<>SH_ACTOR) Then Begin
   PolyGradient(M,Fill,Gr,LoStr(StyStr(Sty,'gradientDirection','south')));
   PolyDraw(M,-1,Si,True);
  End Else PolyDraw(M,Fi,Si,True);
 End;
 { Traits supplementaires (processus, note, acteur, ...) }
 If E.N>0 Then Begin
  Q.N:=0;
  For K:=0 To E.N-1 Do Begin
   If E.P[K].X=BRK Then Begin
    If Q.N>1 Then PolyDraw(Q,-1,Si,False);
    Q.N:=0;
   End Else PAdd(Q,E.P[K].X,E.P[K].Y);
  End;
  If Q.N>1 Then PolyDraw(Q,-1,Si,False);
 End;
 If Shp=SH_STENCIL Then Begin
  SetColor(Si);
  DLine(X1,Y1,X2,Y2); DLine(X1,Y2,X2,Y1);
 End;
 If (Shp=SH_RECT) And (StyStr(Sty,'shape','')='') And (Pos('swimlane',Sty)=0) And
    (StyBool(Sty,'glass',False)) Then Begin
  SetColor(C_WHITE);
  DLine(X1+2,Y1+2,X2-2,Y1+2);
 End;
 PenReset;
 DrawVertexLabel(I);
End;

{ ========================================================================== }
{                              CONNECTEURS                                   }
{ ========================================================================== }

Const
 AR_NONE = 0; AR_CLASSIC = 1; AR_CLASSICTHIN = 2; AR_BLOCK = 3; AR_BLOCKTHIN = 4;
 AR_OPEN = 5; AR_OVAL = 6; AR_DIAMOND = 7; AR_DASH = 8;
 ArrowNames: Array[0..8] Of String[12] = ('none','classic','classicThin','block','blockThin','open','oval','diamond','dash');

Function ArrowKind(Const S: String): Byte;
Var I: Integer;
Begin
 ArrowKind:=AR_CLASSIC;
 If S='' Then Exit;
 For I:=0 To 8 Do If ArrowNames[I]=S Then Begin ArrowKind:=I; Exit; End;
 If Copy(S,1,4)='open' Then ArrowKind:=AR_OPEN
 Else If Copy(S,1,7)='diamond' Then ArrowKind:=AR_DIAMOND
 Else If Copy(S,1,5)='block' Then ArrowKind:=AR_BLOCK;
End;

Procedure CellCenter(I: Integer; Var CXc, CYc: LongInt);
Begin
 CXc:=Cells[I]^.X+Cells[I]^.W Div 2;
 CYc:=Cells[I]^.Y+Cells[I]^.H Div 2;
End;

{ Point d'intersection du perimetre du sommet I avec le rayon centre -> (TX,TY) }
Procedure Perimeter(I: Integer; TX, TY: LongInt; Var PX, PY: LongInt);
Var M, E: TPoly; Cx, Cy: LongInt; K: Integer; Dx, Dy, Ex, Ey, Den, T, U, BestT: Real;
    Sh: Byte; S: Real; W2, H2: Real; Found: Boolean;
Begin
 CellCenter(I,Cx,Cy);
 PX:=Cx; PY:=Cy;
 Dx:=TX-Cx; Dy:=TY-Cy;
 If (Dx=0) And (Dy=0) Then Exit;
 Sh:=CellShape(I);
 If (Sh=SH_RECT) Or (Sh=SH_TEXT) Or (Sh=SH_SWIMLANE) Or (Sh=SH_PROCESS) Or (Sh=SH_STENCIL) Or
    (Sh=SH_IMAGE) Or (Sh=SH_NOTE) Or (Sh=SH_LINE) Then Begin
  W2:=Cells[I]^.W/2; H2:=Cells[I]^.H/2;
  If Abs(Dx)*H2>Abs(Dy)*W2 Then S:=W2/Abs(Dx) Else S:=H2/Abs(Dy);
  PX:=Cx+Round(Dx*S); PY:=Cy+Round(Dy*S);
  Exit;
 End;
 BuildShape(I,M,E);
 BestT:=-1; Found:=False;
 For K:=0 To M.N-1 Do Begin
  Ex:=M.P[(K+1) Mod M.N].X-M.P[K].X; Ey:=M.P[(K+1) Mod M.N].Y-M.P[K].Y;
  Den:=Dx*Ey-Dy*Ex;
  If Abs(Den)<0.000001 Then Continue;
  T:=((M.P[K].X-Cx)*Ey-(M.P[K].Y-Cy)*Ex)/Den;
  U:=((M.P[K].X-Cx)*Dy-(M.P[K].Y-Cy)*Dx)/Den;
  If (T>0) And (U>=-0.0001) And (U<=1.0001) Then
   If T>BestT Then Begin BestT:=T; Found:=True; End;
 End;
 If Found Then Begin
  PX:=Cx+Round(Dx*BestT); PY:=Cy+Round(Dy*BestT);
 End;
End;

{ Point de sortie fixe (exitX/exitY ou entryX/entryY). Retourne la direction
  0 est 1 sud 2 ouest 3 nord, ou -1 si non defini }
Function Anchor(I: Integer; Const Sty, Pfx: String; Var PX, PY: LongInt): Integer;
Var Fx, Fy: Integer; C: PCell; Dx, Dy: LongInt;
Begin
 Anchor:=-1;
 If I=0 Then Exit;
 If Not StyFrac(Sty,Pfx+'X',Fx) Then Exit;
 If Not StyFrac(Sty,Pfx+'Y',Fy) Then Exit;
 C:=Cells[I];
 Dx:=StyInt(Sty,Pfx+'Dx',0); Dy:=StyInt(Sty,Pfx+'Dy',0);
 PX:=C^.X+C^.W*Fx Div 100+Dx;
 PY:=C^.Y+C^.H*Fy Div 100+Dy;
 If Fx<=0 Then Anchor:=2
 Else If Fx>=100 Then Anchor:=0
 Else If Fy<=0 Then Anchor:=3
 Else If Fy>=100 Then Anchor:=1
 Else Anchor:=0;
End;

{ Point au milieu du cote Dir du sommet I }
Procedure SidePoint(I: Integer; Dir: Integer; Var PX, PY: LongInt);
Var C: PCell;
Begin
 C:=Cells[I];
 Case Dir Of
  0: Begin PX:=C^.X+C^.W; PY:=C^.Y+C^.H Div 2; End;
  1: Begin PX:=C^.X+C^.W Div 2; PY:=C^.Y+C^.H; End;
  2: Begin PX:=C^.X; PY:=C^.Y+C^.H Div 2; End;
 Else Begin PX:=C^.X+C^.W Div 2; PY:=C^.Y; End;
 End;
End;

{ Arrondit les angles d'une polyligne (rayon R) }
Procedure RoundPath(Var Pl: TPoly; R: LongInt);
Var Q: TPoly; K: Integer; X0, Y0, X1, Y1, X2, Y2: LongInt; L1, L2, Rr: Real;
    Ax, Ay, Bx, By: LongInt; S: Integer;
Begin
 If Pl.N<3 Then Exit;
 Q.N:=0;
 PAdd(Q,Pl.P[0].X,Pl.P[0].Y);
 For K:=1 To Pl.N-2 Do Begin
  X0:=Pl.P[K-1].X; Y0:=Pl.P[K-1].Y; X1:=Pl.P[K].X; Y1:=Pl.P[K].Y;
  X2:=Pl.P[K+1].X; Y2:=Pl.P[K+1].Y;
  L1:=Sqrt(Sqr(1.0*(X1-X0))+Sqr(1.0*(Y1-Y0)));
  L2:=Sqrt(Sqr(1.0*(X2-X1))+Sqr(1.0*(Y2-Y1)));
  Rr:=R;
  If Rr>L1/2 Then Rr:=L1/2;
  If Rr>L2/2 Then Rr:=L2/2;
  If (Rr<2) Or (L1<1) Or (L2<1) Then Begin PAdd(Q,X1,Y1); Continue; End;
  Ax:=X1+Round((X0-X1)*Rr/L1); Ay:=Y1+Round((Y0-Y1)*Rr/L1);
  Bx:=X1+Round((X2-X1)*Rr/L2); By:=Y1+Round((Y2-Y1)*Rr/L2);
  PAdd(Q,Ax,Ay);
  For S:=1 To 3 Do
   PAdd(Q,Round(Sqr(1-S/4)*Ax+2*(1-S/4)*(S/4)*X1+Sqr(S/4)*Bx),
          Round(Sqr(1-S/4)*Ay+2*(1-S/4)*(S/4)*Y1+Sqr(S/4)*By));
  PAdd(Q,Bx,By);
 End;
 PAdd(Q,Pl.P[Pl.N-1].X,Pl.P[Pl.N-1].Y);
 Pl:=Q;
End;

{ Lisse une polyligne par une courbe de Bezier / spline quadratique }
Procedure CurvePath(Var Pl: TPoly; SD, TD: Integer);
Var Q: TPoly; K: Integer; T: Real; X0, Y0, X3, Y3, X1, Y1, X2, Y2, D: LongInt; A, B, Cc, Dd: Real;
Begin
 If Pl.N<2 Then Exit;
 Q.N:=0;
 If Pl.N=2 Then Begin
  X0:=Pl.P[0].X; Y0:=Pl.P[0].Y; X3:=Pl.P[1].X; Y3:=Pl.P[1].Y;
  D:=(Abs32(X3-X0)+Abs32(Y3-Y0)) Div 2;
  X1:=X0; Y1:=Y0; X2:=X3; Y2:=Y3;
  Case SD Of 0: X1:=X0+D; 2: X1:=X0-D; 1: Y1:=Y0+D; 3: Y1:=Y0-D; End;
  Case TD Of 0: X2:=X3+D; 2: X2:=X3-D; 1: Y2:=Y3+D; 3: Y2:=Y3-D; End;
  For K:=0 To 20 Do Begin
   T:=K/20;
   A:=Sqr(1-T)*(1-T); B:=3*Sqr(1-T)*T; Cc:=3*(1-T)*T*T; Dd:=T*T*T;
   PAdd(Q,Round(A*X0+B*X1+Cc*X2+Dd*X3),Round(A*Y0+B*Y1+Cc*Y2+Dd*Y3));
  End;
 End Else Begin
  { Spline quadratique passant par les milieux }
  PAdd(Q,Pl.P[0].X,Pl.P[0].Y);
  For K:=1 To Pl.N-2 Do Begin
   X0:=(Pl.P[K-1].X+Pl.P[K].X) Div 2; Y0:=(Pl.P[K-1].Y+Pl.P[K].Y) Div 2;
   If K=1 Then Begin X0:=Pl.P[0].X; Y0:=Pl.P[0].Y; End;
   X3:=(Pl.P[K].X+Pl.P[K+1].X) Div 2; Y3:=(Pl.P[K].Y+Pl.P[K+1].Y) Div 2;
   If K=Pl.N-2 Then Begin X3:=Pl.P[Pl.N-1].X; Y3:=Pl.P[Pl.N-1].Y; End;
   For D:=1 To 8 Do Begin
    T:=D/8;
    PAdd(Q,Round(Sqr(1-T)*X0+2*(1-T)*T*Pl.P[K].X+T*T*X3),
           Round(Sqr(1-T)*Y0+2*(1-T)*T*Pl.P[K].Y+T*T*Y3));
   End;
  End;
 End;
 Pl:=Q;
End;

{ Calcule le chemin (coordonnees document) du connecteur I }
Procedure EdgePath(I: Integer; Var Pl: TPoly; Var SDir, TDir: Integer);
Var E: PCell; Sty, Es: String; Src, Tgt, K: Integer; Orth, Curved, Rnd: Boolean;
    Sx, Sy, Tx, Ty, Cx, Cy, Ax, Ay: LongInt; Bx1, By1, Bw1, Bh1, Bx2, By2, Bw2, Bh2: LongInt;
    Gx, Gy: LongInt; AimSx, AimSy, AimTx, AimTy: LongInt; Sd, Td, D1: Integer;
    HorizFirst: Boolean; Mx, My: LongInt;
 Procedure Box(Idx: Integer; Var X, Y, W, H: LongInt; Pt: TPt);
 Begin
  If Idx>0 Then Begin X:=Cells[Idx]^.X; Y:=Cells[Idx]^.Y; W:=Cells[Idx]^.W; H:=Cells[Idx]^.H; End
  Else Begin X:=Pt.X; Y:=Pt.Y; W:=0; H:=0; End;
 End;
 Procedure Join(X, Y: LongInt; HF: Boolean);
 Var L: Integer;
 Begin
  If Pl.N=0 Then Begin PAdd(Pl,X,Y); Exit; End;
  L:=Pl.N-1;
  If (Pl.P[L].X<>X) And (Pl.P[L].Y<>Y) Then Begin
   If HF Then PAdd(Pl,X,Pl.P[L].Y) Else PAdd(Pl,Pl.P[L].X,Y);
  End;
  PAdd(Pl,X,Y);
 End;
Begin
 Pl.N:=0; SDir:=-1; TDir:=-1;
 E:=Cells[I]; Sty:=E^.Style;
 Src:=E^.SrcIdx; Tgt:=E^.TgtIdx;
 Es:=StyStr(Sty,'edgeStyle','');
 Orth:=(Pos('rthogonal',Es)>0) Or (Pos('lbow',Es)>0) Or (Pos('ntityRelation',Es)>0) Or (Pos('egment',Es)>0);
 Curved:=StyBool(Sty,'curved',False);
 Rnd:=StyBool(Sty,'rounded',False);
 Box(Src,Bx1,By1,Bw1,Bh1,E^.SrcPt);
 Box(Tgt,Bx2,By2,Bw2,Bh2,E^.TgtPt);
 { Points de visee }
 If E^.NPts>0 Then Begin
  AimSx:=E^.Pts[0].X; AimSy:=E^.Pts[0].Y;
  AimTx:=E^.Pts[E^.NPts-1].X; AimTy:=E^.Pts[E^.NPts-1].Y;
 End Else Begin
  AimSx:=Bx2+Bw2 Div 2; AimSy:=By2+Bh2 Div 2;
  AimTx:=Bx1+Bw1 Div 2; AimTy:=By1+Bh1 Div 2;
 End;
 { Directions de sortie / entree }
 Sd:=-1; Td:=-1;
 If Src>0 Then Sd:=Anchor(Src,Sty,'exit',Sx,Sy);
 If Tgt>0 Then Td:=Anchor(Tgt,Sty,'entry',Tx,Ty);
 If Orth Then Begin
  If Sd<0 Then Begin
   Gx:=Max(AimSx-(Bx1+Bw1),Bx1-AimSx); Gy:=Max(AimSy-(By1+Bh1),By1-AimSy);
   If (E^.NPts=0) And (Tgt>0) Then Begin
    Gx:=Max(Bx2-(Bx1+Bw1),Bx1-(Bx2+Bw2)); Gy:=Max(By2-(By1+Bh1),By1-(By2+Bh2));
   End;
   Cx:=Bx1+Bw1 Div 2; Cy:=By1+Bh1 Div 2;
   If (Gx>0) And (Gy>0) Then D1:=Ord(Gx<Gy)
   Else If Gx>0 Then D1:=0 Else If Gy>0 Then D1:=1
   Else D1:=Ord(Abs32(AimSx-Cx)<Abs32(AimSy-Cy));
   If D1=0 Then Begin If AimSx>=Cx Then Sd:=0 Else Sd:=2; End
   Else Begin If AimSy>=Cy Then Sd:=1 Else Sd:=3; End;
   If Src>0 Then SidePoint(Src,Sd,Sx,Sy) Else Begin Sx:=E^.SrcPt.X; Sy:=E^.SrcPt.Y; End;
  End;
  If Td<0 Then Begin
   Cx:=Bx2+Bw2 Div 2; Cy:=By2+Bh2 Div 2;
   If E^.NPts>0 Then Begin Ax:=AimTx; Ay:=AimTy; End Else Begin Ax:=Bx1+Bw1 Div 2; Ay:=By1+By1*0+Bh1 Div 2; End;
   Gx:=Max(Ax-(Bx2+Bw2),Bx2-Ax); Gy:=Max(Ay-(By2+Bh2),By2-Ay);
   If (E^.NPts=0) And (Src>0) Then Begin
    Gx:=Max(Bx1-(Bx2+Bw2),Bx2-(Bx1+Bw1)); Gy:=Max(By1-(By2+Bh2),By2-(By1+Bh1));
   End;
   If (Gx>0) And (Gy>0) Then D1:=Ord(Gx<Gy)
   Else If Gx>0 Then D1:=0 Else If Gy>0 Then D1:=1
   Else D1:=Ord(Abs32(Ax-Cx)<Abs32(Ay-Cy));
   If D1=0 Then Begin If Ax>=Cx Then Td:=0 Else Td:=2; End
   Else Begin If Ay>=Cy Then Td:=1 Else Td:=3; End;
   If Tgt>0 Then SidePoint(Tgt,Td,Tx,Ty) Else Begin Tx:=E^.TgtPt.X; Ty:=E^.TgtPt.Y; End;
  End;
 End Else Begin
  If Sd<0 Then Begin
   If Src>0 Then Perimeter(Src,AimSx,AimSy,Sx,Sy) Else Begin Sx:=E^.SrcPt.X; Sy:=E^.SrcPt.Y; End;
  End;
  If Td<0 Then Begin
   If Tgt>0 Then Perimeter(Tgt,AimTx,AimTy,Tx,Ty) Else Begin Tx:=E^.TgtPt.X; Ty:=E^.TgtPt.Y; End;
  End;
 End;
 SDir:=Sd; TDir:=Td;
 { Assemblage de la polyligne }
 If Not Orth Then Begin
  PAdd(Pl,Sx,Sy);
  For K:=0 To E^.NPts-1 Do PAdd(Pl,E^.Pts[K].X,E^.Pts[K].Y);
  PAdd(Pl,Tx,Ty);
 End Else Begin
  HorizFirst:=(Sd=0) Or (Sd=2);
  PAdd(Pl,Sx,Sy);
  If E^.NPts=0 Then Begin
   If HorizFirst Then Begin
    If (Td=0) Or (Td=2) Then Begin
     Mx:=(Sx+Tx) Div 2;
     If ((Sd=0) And (Td=0)) Or ((Sd=2) And (Td=2)) Then Begin
      If Sd=0 Then Mx:=Max(Sx,Tx)+20 Else Mx:=Min(Sx,Tx)-20;
     End;
     PAdd(Pl,Mx,Sy); PAdd(Pl,Mx,Ty);
    End Else PAdd(Pl,Tx,Sy);
   End Else Begin
    If (Td=1) Or (Td=3) Then Begin
     My:=(Sy+Ty) Div 2;
     If ((Sd=1) And (Td=1)) Or ((Sd=3) And (Td=3)) Then Begin
      If Sd=1 Then My:=Max(Sy,Ty)+20 Else My:=Min(Sy,Ty)-20;
     End;
     PAdd(Pl,Sx,My); PAdd(Pl,Tx,My);
    End Else PAdd(Pl,Sx,Ty);
   End;
  End Else Begin
   For K:=0 To E^.NPts-1 Do Join(E^.Pts[K].X,E^.Pts[K].Y,HorizFirst);
   Join(Tx,Ty,Not ((Td=0) Or (Td=2)));
   Pl.N:=Pl.N-1;
  End;
  PAdd(Pl,Tx,Ty);
 End;
 { Elimine les points confondus consecutifs }
 K:=1;
 While K<Pl.N Do Begin
  If (Pl.P[K].X=Pl.P[K-1].X) And (Pl.P[K].Y=Pl.P[K-1].Y) And (Pl.N>2) Then Begin
   For D1:=K To Pl.N-2 Do Pl.P[D1]:=Pl.P[D1+1];
   Dec(Pl.N);
  End Else Inc(K);
 End;
 If Curved Then CurvePath(Pl,Sd,Td)
 Else If Rnd And (Pl.N>2) Then RoundPath(Pl,12);
End;

Function PathLength(Var Pl: TPoly): LongInt;
Var K: Integer; L: Real;
Begin
 L:=0;
 For K:=1 To Pl.N-1 Do
  L:=L+Sqrt(Sqr(1.0*(Pl.P[K].X-Pl.P[K-1].X))+Sqr(1.0*(Pl.P[K].Y-Pl.P[K-1].Y)));
 PathLength:=Round(L);
End;

{ Point a la fraction T100 (0..100) de la longueur du chemin }
Procedure PathAt(Var Pl: TPoly; T100: Integer; Var PX, PY: LongInt);
Var K: Integer; Tot, Want, Acc, Sl, F: Real;
Begin
 PX:=0; PY:=0;
 If Pl.N=0 Then Exit;
 PX:=Pl.P[0].X; PY:=Pl.P[0].Y;
 If Pl.N=1 Then Exit;
 Tot:=PathLength(Pl);
 Want:=Tot*T100/100; Acc:=0;
 For K:=1 To Pl.N-1 Do Begin
  Sl:=Sqrt(Sqr(1.0*(Pl.P[K].X-Pl.P[K-1].X))+Sqr(1.0*(Pl.P[K].Y-Pl.P[K-1].Y)));
  If (Acc+Sl>=Want) Or (K=Pl.N-1) Then Begin
   If Sl<0.001 Then F:=0 Else F:=(Want-Acc)/Sl;
   If F<0 Then F:=0;
   If F>1 Then F:=1;
   PX:=Pl.P[K-1].X+Round((Pl.P[K].X-Pl.P[K-1].X)*F);
   PY:=Pl.P[K-1].Y+Round((Pl.P[K].Y-Pl.P[K-1].Y)*F);
   Exit;
  End;
  Acc:=Acc+Sl;
 End;
End;

{ Distance (document) d'un point a un segment }
Function SegDist(Px, Py, X1, Y1, X2, Y2: LongInt): LongInt;
Var Dx, Dy, T, L2, Qx, Qy: Real;
Begin
 Dx:=X2-X1; Dy:=Y2-Y1; L2:=Dx*Dx+Dy*Dy;
 If L2<0.001 Then T:=0 Else T:=((Px-X1)*Dx+(Py-Y1)*Dy)/L2;
 If T<0 Then T:=0;
 If T>1 Then T:=1;
 Qx:=X1+T*Dx; Qy:=Y1+T*Dy;
 SegDist:=Round(Sqrt(Sqr(Px-Qx)+Sqr(Py-Qy)));
End;

Function PathDist(Var Pl: TPoly; Px, Py: LongInt): LongInt;
Var K: Integer; D, B: LongInt;
Begin
 B:=999999;
 For K:=1 To Pl.N-1 Do Begin
  D:=SegDist(Px,Py,Pl.P[K-1].X,Pl.P[K-1].Y,Pl.P[K].X,Pl.P[K].Y);
  If D<B Then B:=D;
 End;
 PathDist:=B;
End;

{ Tete de fleche en coordonnees ecran. (Tx,Ty)=pointe, (Fx,Fy)=point en amont. }
Procedure DrawArrowHead(Kind: Byte; Tx, Ty, Fx, Fy: LongInt; Col: Integer; Filled: Boolean; Sz: Integer);
Var Ux, Uy, L, Len, Wd: Real; Q: Array[0..5] Of PointType; Nx, Ny: Real;
    Bx, By: Real;
 Procedure P(Idx: Integer; A, B: Real);  { A le long de l'axe, B perpendiculaire }
 Begin
  Q[Idx].X:=Cl(Round(Tx+Ux*A+Nx*B)); Q[Idx].Y:=Cl(Round(Ty+Uy*A+Ny*B));
 End;
Begin
 If Kind=AR_NONE Then Exit;
 L:=Sqrt(Sqr(1.0*(Tx-Fx))+Sqr(1.0*(Ty-Fy)));
 If L<0.5 Then Exit;
 Ux:=(Tx-Fx)/L; Uy:=(Ty-Fy)/L; Nx:=-Uy; Ny:=Ux;
 Len:=Sz; Wd:=Sz*0.45;
 If (Kind=AR_CLASSICTHIN) Or (Kind=AR_BLOCKTHIN) Then Wd:=Sz*0.28;
 SetColor(Col);
 SetFillStyle(SolidFill,Col);
 Case Kind Of
  AR_CLASSIC,AR_CLASSICTHIN: Begin
   P(0,0,0); P(1,-Len,-Wd); P(2,-Len*0.7,0); P(3,-Len,Wd);
   If Filled Then FillPoly(4,Q) Else Begin SetFillStyle(SolidFill,C_WHITE); FillPoly(4,Q); End;
  End;
  AR_BLOCK,AR_BLOCKTHIN: Begin
   P(0,0,0); P(1,-Len,-Wd); P(2,-Len,Wd);
   If Not Filled Then SetFillStyle(SolidFill,C_WHITE);
   FillPoly(3,Q);
  End;
  AR_OPEN: Begin
   P(0,-Len,-Wd); P(1,0,0); P(2,-Len,Wd);
   DrawPoly(3,Q);
  End;
  AR_OVAL: Begin
   Bx:=Tx-Ux*Len/2; By:=Ty-Uy*Len/2;
   If Not Filled Then SetFillStyle(SolidFill,C_WHITE);
   FillEllipse(Cl(Round(Bx)),Cl(Round(By)),Cl(Round(Len/2)),Cl(Round(Len/2)));
  End;
  AR_DIAMOND: Begin
   P(0,0,0); P(1,-Len*0.6,-Wd); P(2,-Len*1.2,0); P(3,-Len*0.6,Wd);
   If Not Filled Then SetFillStyle(SolidFill,C_WHITE);
   FillPoly(4,Q);
  End;
  AR_DASH: Begin
   P(0,-Len*0.5,-Wd); P(1,-Len*0.5,Wd);
   DrawPoly(2,Q);
  End;
 End;
End;

{ Longueur de recul de la ligne selon le type de fleche (en pixels ecran) }
Function ArrowInset(Kind: Byte; Sz: Integer): Integer;
Begin
 Case Kind Of
  AR_CLASSIC,AR_CLASSICTHIN: ArrowInset:=Sz*7 Div 10;
  AR_BLOCK,AR_BLOCKTHIN: ArrowInset:=Sz;
  AR_OVAL: ArrowInset:=Sz;
  AR_DIAMOND: ArrowInset:=Sz*12 Div 10;
 Else ArrowInset:=0;
 End;
End;

Function EdgeDash(Const Sty: String): Byte;
Begin
 EdgeDash:=0;
 If StyBool(Sty,'dashed',False) Then Begin
  EdgeDash:=1;
  If Copy(StyStr(Sty,'dashPattern',''),1,2)='1 ' Then EdgeDash:=2;
 End;
End;

Procedure DrawEdge(I: Integer);
Var E: PCell; Pl, Draw: TPoly; Sty: String; Sd, Td: Integer; Si, Sw, Sz: Integer; Stroke: LongInt;
    EA, SA: Byte; EFill, SFill: Boolean; Mx, My: LongInt; K: Integer;
    Inset: Integer; L: Real; Bg: LongInt; BgI: Integer; Dash: Byte;
Begin
 E:=Cells[I]; Sty:=E^.Style;
 EdgePath(I,Pl,Sd,Td);
 If Pl.N<2 Then Exit;
 Stroke:=CellStroke(I);
 If Stroke<0 Then Exit;
 Si:=PalOf(Stroke);
 Sw:=Integer(StyInt(Sty,'strokeWidth',1));
 Dash:=EdgeDash(Sty);
 EA:=ArrowKind(StyStr(Sty,'endArrow','classic'));
 SA:=ArrowKind(StyStr(Sty,'startArrow','none'));
 If StyStr(Sty,'endArrow','classic')='none' Then EA:=AR_NONE;
 If StyStr(Sty,'startArrow','none')='none' Then SA:=AR_NONE;
 EFill:=StyInt(Sty,'endFill',1)<>0;
 SFill:=StyInt(Sty,'startFill',1)<>0;
 Sz:=Integer(ZL(StyInt(Sty,'endSize',6)))+4;
 If Sz<5 Then Sz:=5;
 { Raccourcit le chemin pour ne pas deborder de la pointe }
 Draw:=Pl;
 Inset:=ArrowInset(EA,Sz);
 K:=Draw.N-1;
 If (Inset>0) And EFill Then Begin
  L:=Sqrt(Sqr(1.0*(Draw.P[K].X-Draw.P[K-1].X))+Sqr(1.0*(Draw.P[K].Y-Draw.P[K-1].Y)));
  If L>Inset*100/Zoom Then Begin
   Draw.P[K].X:=Draw.P[K].X-Round((Draw.P[K].X-Draw.P[K-1].X)*(Inset*100/Zoom)/L);
   Draw.P[K].Y:=Draw.P[K].Y-Round((Draw.P[K].Y-Draw.P[K-1].Y)*(Inset*100/Zoom)/L);
  End;
 End;
 Inset:=ArrowInset(SA,Sz);
 If (Inset>0) And SFill Then Begin
  L:=Sqrt(Sqr(1.0*(Draw.P[1].X-Draw.P[0].X))+Sqr(1.0*(Draw.P[1].Y-Draw.P[0].Y)));
  If L>Inset*100/Zoom Then Begin
   Draw.P[0].X:=Draw.P[0].X+Round((Draw.P[1].X-Draw.P[0].X)*(Inset*100/Zoom)/L);
   Draw.P[0].Y:=Draw.P[0].Y+Round((Draw.P[1].Y-Draw.P[0].Y)*(Inset*100/Zoom)/L);
  End;
 End;
 If StyBool(Sty,'shadow',False) Then Begin
  For K:=0 To Draw.N-1 Do Begin Inc(Draw.P[K].X,2); Inc(Draw.P[K].Y,2); End;
  Pen(Dash,Sw); PolyDraw(Draw,-1,C_BORDER,False);
  For K:=0 To Draw.N-1 Do Begin Dec(Draw.P[K].X,2); Dec(Draw.P[K].Y,2); End;
 End;
 Pen(Dash,Sw);
 PolyDraw(Draw,-1,Si,False);
 PenReset;
 { Fleches }
 If EA<>AR_NONE Then Begin
  K:=Pl.N-1;
  DrawArrowHead(EA,SX(Pl.P[K].X),SY(Pl.P[K].Y),SX(Pl.P[K-1].X),SY(Pl.P[K-1].Y),Si,EFill,Sz);
 End;
 If SA<>AR_NONE Then
  DrawArrowHead(SA,SX(Pl.P[0].X),SY(Pl.P[0].Y),SX(Pl.P[1].X),SY(Pl.P[1].Y),Si,SFill,Sz);
 { Etiquette }
 If (E^.Value<>'') And (I<>EditHide) Then Begin
  PathAt(Pl,50,Mx,My);
  Bg:=ParseColor(StyStr(Sty,'labelBackgroundColor',''),-1);
  If Bg>=0 Then BgI:=PalOf(Bg) Else BgI:=-1;
  DrawLabel(E^.Value,Mx-60,My-8,120,16,1,1,Integer(StyInt(Sty,'fontSize',12)),
            PalOf(CellFontColor(I)),Integer(StyInt(Sty,'fontStyle',0)),False,BgI,2);
 End;
End;

{ Etiquette enfant d'un connecteur }
Procedure DrawEdgeLabelCell(I: Integer);
Var C: PCell; Pl: TPoly; Sd, Td: Integer; Mx, My: LongInt; T: Integer; Bg: LongInt; BgI: Integer;
Begin
 C:=Cells[I];
 If (C^.Value='') Or (I=EditHide) Then Exit;
 EdgePath(C^.ParIdx,Pl,Sd,Td);
 If Pl.N<2 Then Exit;
 T:=Integer(Clamp(50+C^.X Div 2,0,100));
 PathAt(Pl,T,Mx,My);
 Bg:=ParseColor(StyStr(C^.Style,'labelBackgroundColor',''),-1);
 If Bg>=0 Then BgI:=PalOf(Bg) Else BgI:=-1;
 DrawLabel(C^.Value,Mx-60,My-8+C^.Y,120,16,1,1,Integer(StyInt(C^.Style,'fontSize',12)),
           PalOf(CellFontColor(I)),Integer(StyInt(C^.Style,'fontStyle',0)),False,BgI,2);
End;

{ ========================================================================== }
{                          ZONE DE DESSIN (CANEVAS)                          }
{ ========================================================================== }

Procedure EnterCanvas;
Begin
 SetViewPort(CX1,CY1,CX2,CY2,ClipOn);
 OfsX:=0; OfsY:=0;
End;

Procedure LeaveCanvas;
Begin
 SetViewPort(0,0,SCR_W-1,SCR_H-1,ClipOff);
 OfsX:=CX1; OfsY:=CY1;
End;

Procedure DrawGrid;
Var Step, X, Y, Sx0, Sy0: LongInt; Mult: Integer;
Begin
 If Not GridOn Then Exit;
 Mult:=1; Step:=ZL(GridSize);
 While (Step<5) And (Mult<64) Do Begin Mult:=Mult*2; Step:=ZL(GridSize*Mult); End;
 If Step<2 Then Exit;
 SetColor(C_PANEL);
 X:=ViewX Div (GridSize*Mult)*(GridSize*Mult);
 If X<ViewX Then X:=X+GridSize*Mult;
 While SX(X)<=CX2-CX1 Do Begin
  Sx0:=SX(X);
  DLine(Sx0,0,Sx0,CY2-CY1);
  X:=X+GridSize*Mult;
 End;
 Y:=ViewY Div (GridSize*Mult)*(GridSize*Mult);
 If Y<ViewY Then Y:=Y+GridSize*Mult;
 While SY(Y)<=CY2-CY1 Do Begin
  Sy0:=SY(Y);
  DLine(0,Sy0,CX2-CX1,Sy0);
  Y:=Y+GridSize*Mult;
 End;
End;

{ Dessine tout le contenu du diagramme (sans selection) }
Procedure DrawDocument;
Var I: Integer;
Begin
 For I:=1 To NCells Do Begin
  If Not Visible(I) Then Continue;
  Case Cells[I]^.Kind Of
   K_VERTEX: If IsEdgeLabel(I) Then DrawEdgeLabelCell(I) Else DrawVertexShape(I,False);
   K_EDGE: DrawEdge(I);
  End;
 End;
End;

Procedure CellBounds(I: Integer; Var X1, Y1, X2, Y2: LongInt);
Var Pl: TPoly; Sd, Td, K: Integer;
Begin
 If Cells[I]^.Kind=K_EDGE Then Begin
  EdgePath(I,Pl,Sd,Td);
  If Pl.N=0 Then Begin X1:=0; Y1:=0; X2:=0; Y2:=0; Exit; End;
  X1:=Pl.P[0].X; X2:=X1; Y1:=Pl.P[0].Y; Y2:=Y1;
  For K:=1 To Pl.N-1 Do Begin
   If Pl.P[K].X<X1 Then X1:=Pl.P[K].X;
   If Pl.P[K].X>X2 Then X2:=Pl.P[K].X;
   If Pl.P[K].Y<Y1 Then Y1:=Pl.P[K].Y;
   If Pl.P[K].Y>Y2 Then Y2:=Pl.P[K].Y;
  End;
 End Else Begin
  X1:=Cells[I]^.X; Y1:=Cells[I]^.Y; X2:=X1+Cells[I]^.W; Y2:=Y1+Cells[I]^.H;
 End;
End;

{ Poignees : 0 NO 1 N 2 NE 3 E 4 SE 5 S 6 SO 7 O }
Procedure HandlePos(H: Integer; X1, Y1, X2, Y2: LongInt; Var HX, HY: LongInt);
Begin
 Case H Of
  0,6,7: HX:=X1;
  1,5: HX:=(X1+X2) Div 2;
 Else HX:=X2;
 End;
 Case H Of
  0,1,2: HY:=Y1;
  3,7: HY:=(Y1+Y2) Div 2;
 Else HY:=Y2;
 End;
End;

Procedure DrawHandle(X, Y: LongInt; Col: Integer);
Begin
 DBar(X-3,Y-3,X+3,Y+3,C_WHITE);
 DRect(X-3,Y-3,X+3,Y+3,Col);
End;

{ Surbrillance de la selection }
Procedure DrawSelection;
Var I, N, K: Integer; X1, Y1, X2, Y2, Sx0, Sy0: LongInt; Pl: TPoly; Sd, Td: Integer; C: PCell;
Begin
 N:=SelCount;
 For I:=1 To NCells Do Begin
  If Not Cells[I]^.Sel Then Continue;
  If Not Visible(I) Then Continue;
  C:=Cells[I];
  If C^.Kind=K_EDGE Then Begin
   EdgePath(I,Pl,Sd,Td);
   SetLineStyle(DashedLn,0,NormWidth);
   PolyDraw(Pl,-1,C_ACCENT,False);
   PenReset;
   If N=1 Then Begin
    DrawHandle(SX(Pl.P[0].X),SY(Pl.P[0].Y),C_ACCENT);
    DrawHandle(SX(Pl.P[Pl.N-1].X),SY(Pl.P[Pl.N-1].Y),C_ACCENT);
    For K:=0 To C^.NPts-1 Do DrawHandle(SX(C^.Pts[K].X),SY(C^.Pts[K].Y),C_ACCENT);
   End;
  End Else Begin
   If IsEdgeLabel(I) Then Continue;
   X1:=SX(C^.X)-2; Y1:=SY(C^.Y)-2; X2:=SX(C^.X+C^.W)+2; Y2:=SY(C^.Y+C^.H)+2;
   SetLineStyle(DashedLn,0,NormWidth);
   DRect(X1,Y1,X2,Y2,C_ACCENT);
   PenReset;
   If N=1 Then
    For K:=0 To 7 Do Begin
     HandlePos(K,X1,Y1,X2,Y2,Sx0,Sy0);
     DrawHandle(Sx0,Sy0,C_ACCENT);
    End;
  End;
 End;
End;

Procedure DrawCanvas;
Var Bg: Integer;
Begin
 HideMouse;
 EnterCanvas;
 If BgColor>=0 Then Bg:=PalOf(BgColor) Else Bg:=C_WHITE;
 DBar(0,0,CX2-CX1,CY2-CY1,Bg);
 DrawGrid;
 DrawDocument;
 DrawSelection;
 LeaveCanvas;
 Frame(CX1-1,CY1-1,CX2+1,CY2+1,C_BORDER);
 GhostOn:=False; HoverOn:=False; HoverIdx:=0;
 ShowMouse;
End;

{ ========================================================================== }
{                  FICHIERS TEMPORAIRES ET INSTANTANES                       }
{ ========================================================================== }

Const
 {$IFDEF FPC}
 PATH_SEP = DirectorySeparator;
 {$ELSE}
 PATH_SEP = '\';
 {$ENDIF}
 SNAP_SIG = $44575231;

Var
 TempDir: String;
 UHead, UCount, RHead, RCount: Integer;
 LastError: String;

Procedure InitTempDir;
Begin
 TempDir:=GetEnv('TEMP');
 If TempDir='' Then TempDir:=GetEnv('TMP');
 If TempDir<>'' Then
  If TempDir[Length(TempDir)]<>PATH_SEP Then TempDir:=TempDir+PATH_SEP;
End;

Function TmpName(Tag: Char; N: Integer): String;
Begin
 TmpName:=TempDir+'DRW'+Tag+IStr(N)+'.TMP';
End;

Procedure EraseFile(Const Name: String);
Var F: File;
Begin
 Assign(F,Name);
 {$I-} Erase(F); {$I+}
 If IOResult<>0 Then ;
End;

Function FileExists(Const Name: String): Boolean;
Var F: File;
Begin
 Assign(F,Name);
 {$I-} Reset(F,1); {$I+}
 If IOResult=0 Then Begin Close(F); FileExists:=True; End Else FileExists:=False;
End;

{ ------------------------------------------------------------------------- }

Procedure SnapSave(Const Name: String);
Var F: File; H: TDocSet; I: Integer;
Begin
 FillChar(H,SizeOf(H),0);
 H.Sig:=SNAP_SIG; H.N:=NCells; H.GridOn:=GridOn; H.SnapOn:=SnapOn;
 H.GridSize:=GridSize; H.Bg:=BgColor; H.PageName:=PageName;
 Assign(F,Name);
 {$I-} Rewrite(F,1); {$I+}
 If IOResult<>0 Then Exit;
 BlockWrite(F,H,SizeOf(H));
 For I:=1 To NCells Do BlockWrite(F,Cells[I]^,SizeOf(TCell));
 Close(F);
End;

Function SnapLoad(Const Name: String): Boolean;
Var F: File; H: TDocSet; I, N: Integer; P: PCell; Got: Word;
Begin
 SnapLoad:=False;
 Assign(F,Name);
 {$I-} Reset(F,1); {$I+}
 If IOResult<>0 Then Exit;
 BlockRead(F,H,SizeOf(H),Got);
 If (Got<>SizeOf(H)) Or (H.Sig<>SNAP_SIG) Then Begin Close(F); Exit; End;
 ClearDoc;
 GridOn:=H.GridOn; SnapOn:=H.SnapOn; GridSize:=H.GridSize; BgColor:=H.Bg;
 PageName:=H.PageName;
 N:=H.N;
 For I:=1 To N Do Begin
  If NCells>=MAX_CELLS Then Break;
  New(P);
  BlockRead(F,P^,SizeOf(TCell),Got);
  If Got<>SizeOf(TCell) Then Begin Dispose(P); Break; End;
  Inc(NCells); Cells[NCells]:=P;
 End;
 Close(F);
 ResolveLinks;
 SnapLoad:=True;
End;

{ Fusionne le contenu d'un instantane dans le document (avec de nouveaux
  identifiants). Les cellules ajoutees sont selectionnees. }
Function MergeSnap(Const Name: String; OffX, OffY: LongInt): Integer;
Type TIdList = Array[1..MAX_CELLS] Of String[40];
Var F: File; H: TDocSet; I, J, N0, K: Integer; P: PCell; Got: Word; Old: ^TIdList;
    Added: Integer;
Begin
 MergeSnap:=0;
 Assign(F,Name);
 {$I-} Reset(F,1); {$I+}
 If IOResult<>0 Then Exit;
 BlockRead(F,H,SizeOf(H),Got);
 If (Got<>SizeOf(H)) Or (H.Sig<>SNAP_SIG) Then Begin Close(F); Exit; End;
 If HeapFree<SizeOf(TIdList)+2048 Then Begin Close(F); Exit; End;
 New(Old);
 N0:=NCells; Added:=0;
 ClearSel;
 For I:=1 To H.N Do Begin
  If NCells>=MAX_CELLS Then Break;
  New(P);
  BlockRead(F,P^,SizeOf(TCell),Got);
  If Got<>SizeOf(TCell) Then Begin Dispose(P); Break; End;
  Inc(NCells); Cells[NCells]:=P; Inc(Added);
  Old^[Added]:=P^.Id;
 End;
 Close(F);
 { Nouveaux identifiants }
 For I:=1 To Added Do Begin
  Cells[N0+I]^.Id:=MakeId;
  Cells[N0+I]^.Sel:=True;
 End;
 For I:=1 To Added Do
  With Cells[N0+I]^ Do Begin
   K:=0;
   For J:=1 To Added Do If Old^[J]=Parent Then K:=J;
   If K>0 Then Parent:=Cells[N0+K]^.Id Else Parent:='1';
   K:=0;
   For J:=1 To Added Do If (Source<>'') And (Old^[J]=Source) Then K:=J;
   If K>0 Then Source:=Cells[N0+K]^.Id Else Source:='';
   K:=0;
   For J:=1 To Added Do If (Target<>'') And (Old^[J]=Target) Then K:=J;
   If K>0 Then Target:=Cells[N0+K]^.Id Else Target:='';
   If Kind=K_VERTEX Then Begin Inc(X,OffX); Inc(Y,OffY); End
   Else Begin
    For J:=0 To NPts-1 Do Begin Inc(Pts[J].X,OffX); Inc(Pts[J].Y,OffY); End;
    Inc(SrcPt.X,OffX); Inc(SrcPt.Y,OffY); Inc(TgtPt.X,OffX); Inc(TgtPt.Y,OffY);
   End;
  End;
 Dispose(Old);
 ResolveLinks;
 MergeSnap:=Added;
End;

{ ------------------------------------------------------------------------- }
{ Annuler / Refaire                                                           }
{ ------------------------------------------------------------------------- }

Procedure UndoPush;
Begin
 SnapSave(TmpName('U',UHead));
 UHead:=(UHead+1) Mod UNDO_N;
 If UCount<UNDO_N Then Inc(UCount);
 RCount:=0;
 Modified:=True;
End;

Procedure DoUndo;
Begin
 If UCount=0 Then Begin StatusMsg:=Tr('Nothing to undo'); Exit; End;
 SnapSave(TmpName('R',RHead));
 RHead:=(RHead+1) Mod UNDO_N;
 If RCount<UNDO_N Then Inc(RCount);
 UHead:=(UHead+UNDO_N-1) Mod UNDO_N;
 Dec(UCount);
 SnapLoad(TmpName('U',UHead));
 Modified:=True;
End;

Procedure DoRedo;
Begin
 If RCount=0 Then Begin StatusMsg:=Tr('Nothing to redo'); Exit; End;
 SnapSave(TmpName('U',UHead));
 UHead:=(UHead+1) Mod UNDO_N;
 If UCount<UNDO_N Then Inc(UCount);
 RHead:=(RHead+UNDO_N-1) Mod UNDO_N;
 Dec(RCount);
 SnapLoad(TmpName('R',RHead));
 Modified:=True;
End;

Procedure ResetUndo;
Begin
 UHead:=0; UCount:=0; RHead:=0; RCount:=0;
End;

Procedure CleanTemp;
Var I: Integer;
Begin
 For I:=0 To UNDO_N-1 Do Begin EraseFile(TmpName('U',I)); EraseFile(TmpName('R',I)); End;
 For I:=0 To MAX_PAGES-1 Do Begin EraseFile(TmpName('P',I)); End;
 EraseFile(TmpName('C',0)); EraseFile(TmpName('A',0)); EraseFile(TmpName('A',1));
 EraseFile(TmpName('A',2)); EraseFile(TmpName('I',0));
End;

{ ========================================================================== }
{          BASE64, DEFLATE (INFLATE), URL : CODAGE DES DIAGRAMMES            }
{ ========================================================================== }

Const
 B64: String[64] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

Type
 THuff = Record
  Count: Array[0..15] Of Integer;
  Sym: Array[0..287] Of Integer;
 End;
 PHuff = ^THuff;
 TWin = Array[0..32767] Of Byte;
 PWin = ^TWin;

Var
 { Etat de l'inflate }
 InF, OutBF: File;
 InBuf: Array[0..2047] Of Byte;
 InPos, InLen: Integer;
 OutBuf: Array[0..4095] Of Byte;
 OutPos: Integer;
 BitBuf: LongInt;
 BitCnt: Integer;
 Win: PWin;
 WinPos: Integer;
 InflateErr: Boolean;
 LitH, DistH: PHuff;

Const
 LBase: Array[0..28] Of Integer = (3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258);
 LExt: Array[0..28] Of Integer = (0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DBase: Array[0..29] Of Integer = (1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577);
 DExt: Array[0..29] Of Integer = (0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13);
 ClOrder: Array[0..18] Of Integer = (16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);

Function InByte: Integer;
Var Got: Word;
Begin
 If InPos>=InLen Then Begin
  BlockRead(InF,InBuf,SizeOf(InBuf),Got);
  InLen:=Got; InPos:=0;
  If Got=0 Then Begin InByte:=-1; Exit; End;
 End;
 InByte:=InBuf[InPos]; Inc(InPos);
End;

Procedure FlushOut;
Begin
 If OutPos>0 Then BlockWrite(OutBF,OutBuf,OutPos);
 OutPos:=0;
End;

Procedure PutOut(B: Byte);
Begin
 Win^[WinPos]:=B; WinPos:=(WinPos+1) And 32767;
 OutBuf[OutPos]:=B; Inc(OutPos);
 If OutPos>=SizeOf(OutBuf) Then FlushOut;
End;

Function GetBits(N: Integer): LongInt;
Var V: LongInt; B: Integer;
Begin
 V:=BitBuf;
 While BitCnt<N Do Begin
  B:=InByte;
  If B<0 Then Begin InflateErr:=True; GetBits:=0; Exit; End;
  V:=V Or (LongInt(B) Shl BitCnt);
  Inc(BitCnt,8);
 End;
 BitBuf:=V Shr N;
 Dec(BitCnt,N);
 GetBits:=V And ((LongInt(1) Shl N)-1);
End;

Function Decode(H: PHuff): Integer;
Var Len: Integer; Code, First, Index, Cnt: LongInt;
Begin
 Code:=0; First:=0; Index:=0;
 For Len:=1 To 15 Do Begin
  Code:=Code Or GetBits(1);
  If InflateErr Then Begin Decode:=-1; Exit; End;
  Cnt:=H^.Count[Len];
  If Code-Cnt<First Then Begin
   If (Index+(Code-First)<0) Or (Index+(Code-First)>287) Then Begin InflateErr:=True; Decode:=-1; Exit; End;
   Decode:=H^.Sym[Index+(Code-First)]; Exit;
  End;
  Index:=Index+Cnt; First:=First+Cnt; First:=First Shl 1; Code:=Code Shl 1;
 End;
 Decode:=-1;
End;

Procedure Construct(H: PHuff; Const Lens: Array Of Integer; N: Integer);
Var Sym, Len, Left: Integer; Offs: Array[0..15] Of Integer;
Begin
 For Len:=0 To 15 Do H^.Count[Len]:=0;
 For Sym:=0 To N-1 Do Inc(H^.Count[Lens[Sym]]);
 { Un jeu de codes sur-souscrit est invalide }
 Left:=1;
 For Len:=1 To 15 Do Begin
  Left:=Left Shl 1;
  Dec(Left,H^.Count[Len]);
  If Left<0 Then Begin InflateErr:=True; Exit; End;
 End;
 Offs[1]:=0;
 For Len:=1 To 14 Do Offs[Len+1]:=Offs[Len]+H^.Count[Len];
 For Sym:=0 To N-1 Do
  If Lens[Sym]<>0 Then Begin H^.Sym[Offs[Lens[Sym]]]:=Sym; Inc(Offs[Lens[Sym]]); End;
End;

Procedure InflateCodes;
Var Sym, Len, Dist, K: Integer; B: Byte;
Begin
 Repeat
  Sym:=Decode(LitH);
  If Sym<0 Then Begin InflateErr:=True; Exit; End;
  If Sym<256 Then PutOut(Sym)
  Else If Sym>256 Then Begin
   Dec(Sym,257);
   If Sym>=29 Then Begin InflateErr:=True; Exit; End;
   Len:=LBase[Sym]+Integer(GetBits(LExt[Sym]));
   Sym:=Decode(DistH);
   If (Sym<0) Or (Sym>=30) Then Begin InflateErr:=True; Exit; End;
   Dist:=DBase[Sym]+Integer(GetBits(DExt[Sym]));
   If InflateErr Then Exit;
   For K:=1 To Len Do Begin
    B:=Win^[(WinPos-Dist) And 32767];
    PutOut(B);
   End;
  End;
 Until Sym=256-257;
End;

Procedure InflateBlockCodes;
Var Sym, Len, Dist, K: Integer; B: Byte; Done: Boolean;
Begin
 Done:=False;
 While Not Done Do Begin
  Sym:=Decode(LitH);
  If Sym<0 Then Begin InflateErr:=True; Exit; End;
  If Sym<256 Then PutOut(Sym)
  Else If Sym=256 Then Done:=True
  Else Begin
   Dec(Sym,257);
   If Sym>=29 Then Begin InflateErr:=True; Exit; End;
   Len:=LBase[Sym]+Integer(GetBits(LExt[Sym]));
   Sym:=Decode(DistH);
   If (Sym<0) Or (Sym>=30) Then Begin InflateErr:=True; Exit; End;
   Dist:=DBase[Sym]+Integer(GetBits(DExt[Sym]));
   If InflateErr Then Exit;
   For K:=1 To Len Do Begin
    B:=Win^[(WinPos-Dist) And 32767];
    PutOut(B);
   End;
  End;
 End;
End;

Procedure InflateStored;
Var Len, NLen, I: LongInt; B, B1, B2: Integer;
Begin
 BitBuf:=0; BitCnt:=0;
 B1:=InByte; B2:=InByte;
 Len:=LongInt(B1)+LongInt(B2)*256;
 B1:=InByte; B2:=InByte;
 NLen:=LongInt(B1)+LongInt(B2)*256;
 If (B1<0) Or (B2<0) Or (Len<>((Not NLen) And $FFFF)) Then Begin InflateErr:=True; Exit; End;
 For I:=1 To Len Do Begin
  B:=InByte;
  If B<0 Then Begin InflateErr:=True; Exit; End;
  PutOut(B);
 End;
End;

Procedure InflateFixed;
Var Lens: Array[0..319] Of Integer; I: Integer;
Begin
 For I:=0 To 143 Do Lens[I]:=8;
 For I:=144 To 255 Do Lens[I]:=9;
 For I:=256 To 279 Do Lens[I]:=7;
 For I:=280 To 287 Do Lens[I]:=8;
 Construct(LitH,Lens,288);
 For I:=0 To 29 Do Lens[I]:=5;
 Construct(DistH,Lens,30);
 InflateBlockCodes;
End;

Procedure InflateDynamic;
Var NLen, NDist, NCode, I, Sym, Rep, Prev: Integer; Lens: Array[0..319] Of Integer;
Begin
 NLen:=Integer(GetBits(5))+257; NDist:=Integer(GetBits(5))+1; NCode:=Integer(GetBits(4))+4;
 If InflateErr Or (NLen>286) Or (NDist>30) Then Begin InflateErr:=True; Exit; End;
 For I:=0 To 18 Do Lens[I]:=0;
 For I:=0 To NCode-1 Do Lens[ClOrder[I]]:=Integer(GetBits(3));
 Construct(LitH,Lens,19);
 I:=0;
 While I<NLen+NDist Do Begin
  Sym:=Decode(LitH);
  If Sym<0 Then Begin InflateErr:=True; Exit; End;
  If Sym<16 Then Begin Lens[I]:=Sym; Inc(I); End
  Else Begin
   Prev:=0;
   If Sym=16 Then Begin
    If I=0 Then Begin InflateErr:=True; Exit; End;
    Prev:=Lens[I-1]; Rep:=3+Integer(GetBits(2));
   End Else If Sym=17 Then Rep:=3+Integer(GetBits(3))
   Else Rep:=11+Integer(GetBits(7));
   If I+Rep>NLen+NDist Then Begin InflateErr:=True; Exit; End;
   While Rep>0 Do Begin Lens[I]:=Prev; Inc(I); Dec(Rep); End;
  End;
 End;
 { Les longueurs des distances commencent a NLen : copie dans un tableau a part }
 Construct(LitH,Lens,NLen);
 For I:=0 To NDist-1 Do Lens[I]:=Lens[NLen+I];
 Construct(DistH,Lens,NDist);
 InflateBlockCodes;
End;

{ Decompresse un flux deflate brut (Src) vers Dst. }
Function InflateFile(Const Src, Dst: String): Boolean;
Var Last, Typ: Integer;
Begin
 InflateFile:=False;
 InflateErr:=False; InPos:=0; InLen:=0; OutPos:=0; BitBuf:=0; BitCnt:=0; WinPos:=0;
 Assign(InF,Src);
 {$I-} Reset(InF,1); {$I+}
 If IOResult<>0 Then Exit;
 Assign(OutBF,Dst);
 {$I-} Rewrite(OutBF,1); {$I+}
 If IOResult<>0 Then Begin Close(InF); Exit; End;
 If HeapFree<LongInt(SizeOf(TWin))+LongInt(2*SizeOf(THuff))+1024 Then Begin Close(InF); Close(OutBF); Exit; End;
 New(Win); New(LitH); New(DistH);
 FillChar(Win^,SizeOf(Win^),0);
 Repeat
  Last:=Integer(GetBits(1));
  Typ:=Integer(GetBits(2));
  If InflateErr Then Break;
  Case Typ Of
   0: InflateStored;
   1: InflateFixed;
   2: InflateDynamic;
  Else InflateErr:=True;
  End;
 Until (Last=1) Or InflateErr;
 FlushOut;
 Close(InF); Close(OutBF);
 Dispose(Win); Dispose(LitH); Dispose(DistH);
 InflateFile:=Not InflateErr;
End;

{ Decode les %XX d'un fichier (encodeURIComponent) }
Procedure UrlDecodeFile(Const Src, Dst: String);
Var FI, FO: File; B: Array[0..2047] Of Byte; O: Array[0..2047] Of Byte; Got: Word; I, N: Integer;
    Carry: String[2]; H1, H2: Integer; Ch: Char;
Begin
 Assign(FI,Src); {$I-} Reset(FI,1); {$I+}
 If IOResult<>0 Then Exit;
 Assign(FO,Dst); {$I-} Rewrite(FO,1); {$I+}
 If IOResult<>0 Then Begin Close(FI); Exit; End;
 Carry:='';
 N:=0;
 Repeat
  BlockRead(FI,B,SizeOf(B),Got);
  I:=0;
  While I<Got Do Begin
   Ch:=Chr(B[I]);
   If Ch='%' Then Begin
    { Besoin de 2 chiffres hexadecimaux, peut-etre sur le bloc suivant }
    If I+2<Got Then Begin
     H1:=HexVal(Chr(B[I+1])); H2:=HexVal(Chr(B[I+2]));
     If (H1>=0) And (H2>=0) Then Begin O[N]:=H1*16+H2; Inc(N); Inc(I,3); End
     Else Begin O[N]:=B[I]; Inc(N); Inc(I); End;
    End Else Begin
     { Bloc coupe : on relit l'octet suivant pas a pas }
     Carry:='';
     Inc(I);
     While (I<Got) And (Length(Carry)<2) Do Begin Carry:=Carry+Chr(B[I]); Inc(I); End;
     If Length(Carry)<2 Then Begin
      BlockRead(FI,B,SizeOf(B),Got); I:=0;
      While (I<Got) And (Length(Carry)<2) Do Begin Carry:=Carry+Chr(B[I]); Inc(I); End;
     End;
     If Length(Carry)=2 Then Begin
      H1:=HexVal(Carry[1]); H2:=HexVal(Carry[2]);
      If (H1>=0) And (H2>=0) Then Begin O[N]:=H1*16+H2; Inc(N); End
      Else Begin O[N]:=37; Inc(N); O[N]:=Ord(Carry[1]); Inc(N); O[N]:=Ord(Carry[2]); Inc(N); End;
     End;
    End;
   End Else Begin O[N]:=B[I]; Inc(N); Inc(I); End;
   If N>=SizeOf(O)-4 Then Begin BlockWrite(FO,O,N); N:=0; End;
  End;
 Until Got=0;
 If N>0 Then BlockWrite(FO,O,N);
 Close(FI); Close(FO);
End;

{ Etat du decodeur Base64 en flux }
Var B64Acc: LongInt; B64N: Integer; B64Out: File; B64Buf: Array[0..1023] Of Byte; B64Pos: Integer;

Procedure B64Begin(Const Dst: String);
Begin
 Assign(B64Out,Dst);
 Rewrite(B64Out,1);
 B64Acc:=0; B64N:=0; B64Pos:=0;
End;

Procedure B64Put(B: Byte);
Begin
 B64Buf[B64Pos]:=B; Inc(B64Pos);
 If B64Pos>=SizeOf(B64Buf) Then Begin BlockWrite(B64Out,B64Buf,B64Pos); B64Pos:=0; End;
End;

Procedure B64Feed(C: Char);
Var V: Integer;
Begin
 V:=Pos(C,B64);
 If (V=0) Or (C=#0) Then Begin
  If C='-' Then V:=63 Else If C='_' Then V:=64 Else Exit;
 End;
 Dec(V);
 B64Acc:=B64Acc*64+V; Inc(B64N);
 If B64N=4 Then Begin
  B64Put((B64Acc Shr 16) And 255); B64Put((B64Acc Shr 8) And 255); B64Put(B64Acc And 255);
  B64Acc:=0; B64N:=0;
 End;
End;

Procedure B64End;
Begin
 If B64N=2 Then B64Put((B64Acc Shr 4) And 255)
 Else If B64N=3 Then Begin B64Put((B64Acc Shr 10) And 255); B64Put((B64Acc Shr 2) And 255); End;
 If B64Pos>0 Then BlockWrite(B64Out,B64Buf,B64Pos);
 Close(B64Out);
End;

{ ========================================================================== }
{                              LECTEUR XML                                   }
{ ========================================================================== }

Type
 TXml = Record
  F: File;
  Buf: Array[0..2047] Of Byte;
  Pos, Len: Integer;
  Back: Integer;
  Kind: Byte;                 { 0 fin, 1 ouvrant, 2 fermant, 3 auto-fermant }
  Name: String[40];
  NA: Integer;
  AN: Array[0..15] Of String[24];
  AV: Array[0..15] Of String[255];
 End;
 PXml = ^TXml;

Function XOpen(Const Name: String): PXml;
Var X: PXml;
Begin
 XOpen:=Nil;
 If HeapFree<LongInt(SizeOf(TXml))+4096 Then Exit;
 New(X);
 Assign(X^.F,Name);
 {$I-} Reset(X^.F,1); {$I+}
 If IOResult<>0 Then Begin Dispose(X); Exit; End;
 X^.Pos:=0; X^.Len:=0; X^.Back:=-2; X^.Kind:=0; X^.NA:=0;
 XOpen:=X;
End;

Procedure XClose(X: PXml);
Begin
 If X=Nil Then Exit;
 Close(X^.F);
 Dispose(X);
End;

Function XCh(X: PXml): Integer;
Var Got: Word;
Begin
 If X^.Back<>-2 Then Begin XCh:=X^.Back; X^.Back:=-2; Exit; End;
 If X^.Pos>=X^.Len Then Begin
  BlockRead(X^.F,X^.Buf,SizeOf(X^.Buf),Got);
  X^.Len:=Got; X^.Pos:=0;
  If Got=0 Then Begin XCh:=-1; Exit; End;
 End;
 XCh:=X^.Buf[X^.Pos]; Inc(X^.Pos);
End;

Function U8Char(U: LongInt): String;
Begin
 If U<128 Then U8Char:=Chr(U)
 Else If U<$800 Then U8Char:=Chr($C0 Or (U Shr 6))+Chr($80 Or (U And $3F))
 Else If U<$10000 Then U8Char:=Chr($E0 Or (U Shr 12))+Chr($80 Or ((U Shr 6) And $3F))+Chr($80 Or (U And $3F))
 Else U8Char:=Chr($F0 Or (U Shr 18))+Chr($80 Or ((U Shr 12) And $3F))+Chr($80 Or ((U Shr 6) And $3F))+Chr($80 Or (U And $3F));
End;

{ Decode une entite (apres le '&', jusqu'au ';') }
Function XEntity(X: PXml): String;
Var S: String; C: Integer; U: LongInt; I: Integer; Hx: Boolean;
Begin
 S:='';
 Repeat
  C:=XCh(X);
  If (C<0) Or (C=Ord(';')) Then Break;
  If Length(S)<12 Then S:=S+Chr(C);
 Until False;
 If S='amp' Then XEntity:='&'
 Else If S='lt' Then XEntity:='<'
 Else If S='gt' Then XEntity:='>'
 Else If S='quot' Then XEntity:='"'
 Else If S='apos' Then XEntity:=''''
 Else If (Length(S)>1) And (S[1]='#') Then Begin
  U:=0;
  Hx:=(S[2]='x') Or (S[2]='X');
  For I:=2+Ord(Hx) To Length(S) Do
   If Hx Then U:=U*16+HexVal(S[I]) Else U:=U*10+(Ord(S[I])-48);
  If U<=0 Then XEntity:='' Else XEntity:=U8Char(U);
 End Else XEntity:='';
End;

{ Lit le prochain marqueur. Retourne False a la fin du fichier. }
Function XTag(X: PXml): Boolean;
Var C, Q, K: Integer; S, Nm, Vl: String;
Begin
 XTag:=False; X^.Kind:=0; X^.NA:=0; X^.Name:='';
 Repeat
  Repeat C:=XCh(X); Until (C<0) Or (C=Ord('<'));
  If C<0 Then Exit;
  C:=XCh(X);
  If C=Ord('?') Then Begin
   { <? ... ?> }
   Repeat C:=XCh(X); Until (C<0) Or (C=Ord('>'));
   Continue;
  End;
  If C=Ord('!') Then Begin
   C:=XCh(X);
   If C=Ord('-') Then Begin
    { commentaire <!-- ... --> }
    S:='';
    Repeat
     C:=XCh(X);
     If C<0 Then Exit;
     S:=S+Chr(C); If Length(S)>3 Then Delete(S,1,1);
    Until S='-->';
   End Else If C=Ord('[') Then Begin
    { CDATA : on saute }
    S:='';
    Repeat
     C:=XCh(X);
     If C<0 Then Exit;
     S:=S+Chr(C); If Length(S)>3 Then Delete(S,1,1);
    Until S=']]>';
   End Else Begin
    K:=1;
    While (C>=0) And (K>0) Do Begin
     C:=XCh(X);
     If C=Ord('<') Then Inc(K) Else If C=Ord('>') Then Dec(K);
    End;
   End;
   Continue;
  End;
  Break;
 Until False;
 { Nom du marqueur }
 If C=Ord('/') Then Begin X^.Kind:=2; C:=XCh(X); End Else X^.Kind:=1;
 Nm:='';
 While (C>=0) And (C>32) And (C<>Ord('>')) And (C<>Ord('/')) Do Begin
  If Length(Nm)<40 Then Nm:=Nm+Chr(C);
  C:=XCh(X);
 End;
 X^.Name:=Nm;
 { Attributs }
 While C>=0 Do Begin
  While (C>=0) And (C<=32) Do C:=XCh(X);
  If C=Ord('>') Then Break;
  If C=Ord('/') Then Begin
   C:=XCh(X);
   If C=Ord('>') Then Begin X^.Kind:=3; Break; End;
   Continue;
  End;
  If C<0 Then Break;
  Nm:='';
  While (C>32) And (C<>Ord('=')) And (C<>Ord('>')) And (C<>Ord('/')) Do Begin
   If Length(Nm)<24 Then Nm:=Nm+Chr(C);
   C:=XCh(X);
  End;
  While (C>=0) And (C<=32) Do C:=XCh(X);
  Vl:='';
  If C=Ord('=') Then Begin
   C:=XCh(X);
   While (C>=0) And (C<=32) Do C:=XCh(X);
   If (C=Ord('"')) Or (C=Ord('''')) Then Begin
    Q:=C;
    C:=XCh(X);
    While (C>=0) And (C<>Q) Do Begin
     If C=Ord('&') Then Begin
      S:=XEntity(X);
      If Length(Vl)+Length(S)<=255 Then Vl:=Vl+S;
     End Else If Length(Vl)<255 Then Vl:=Vl+Chr(C);
     C:=XCh(X);
    End;
    C:=XCh(X);
   End;
  End;
  If (Nm<>'') And (X^.NA<16) Then Begin
   X^.AN[X^.NA]:=Nm; X^.AV[X^.NA]:=Vl; Inc(X^.NA);
  End;
 End;
 XTag:=True;
End;

Function XAttr(X: PXml; Const Nm: String): String;
Var I: Integer;
Begin
 XAttr:='';
 For I:=0 To X^.NA-1 Do
  If X^.AN[I]=Nm Then Begin XAttr:=X^.AV[I]; Exit; End;
End;

Function XHas(X: PXml; Const Nm: String): Boolean;
Var I: Integer;
Begin
 XHas:=False;
 For I:=0 To X^.NA-1 Do If X^.AN[I]=Nm Then XHas:=True;
End;

{ Premier caractere non blanc du texte (remis dans le flux) }
Function XPeek(X: PXml): Integer;
Var C: Integer;
Begin
 Repeat C:=XCh(X); Until (C<0) Or (C>32);
 X^.Back:=C;
 XPeek:=C;
End;

{ Lit le texte jusqu'au prochain '<' et le decode en Base64 vers Dst }
Procedure XTextToBase64(X: PXml; Const Dst: String);
Var C: Integer;
Begin
 B64Begin(Dst);
 Repeat
  C:=XCh(X);
  If C<0 Then Break;
  If C=Ord('<') Then Begin X^.Back:=C; Break; End;
  If C=Ord('&') Then Begin XEntity(X); Continue; End;
  If C>32 Then B64Feed(Chr(C));
 Until False;
 B64End;
End;

{ ========================================================================== }
{                  HTML -> TEXTE (etiquettes html=1)                         }
{ ========================================================================== }

Function HtmlToText(Const S: String): String;
Var I, J: Integer; R, Tg, En: String; U: LongInt; Hx: Boolean; K: Integer; Closing: Boolean;
 Procedure NL;
 Begin
  If (R<>'') And (R[Length(R)]<>#10) Then R:=R+#10;
 End;
Begin
 R:=''; I:=1;
 While I<=Length(S) Do Begin
  If S[I]='<' Then Begin
   J:=I+1; Tg:='';
   While (J<=Length(S)) And (S[J]<>'>') Do Begin
    If Length(Tg)<20 Then Tg:=Tg+S[J];
    Inc(J);
   End;
   Closing:=(Tg<>'') And (Tg[1]='/');
   If Closing Then Delete(Tg,1,1);
   K:=1;
   While (K<=Length(Tg)) And (Tg[K]>' ') And (Tg[K]<>'/') Do Inc(K);
   Tg:=LoStr(Copy(Tg,1,K-1));
   If Tg='br' Then Begin If Length(R)<119 Then R:=R+#10; End
   Else If (Tg='div') Or (Tg='p') Or (Tg='li') Or (Tg='tr') Or (Tg='h1') Or (Tg='h2') Or (Tg='h3') Then NL;
   I:=J+1;
  End Else If S[I]='&' Then Begin
   J:=I+1; En:='';
   While (J<=Length(S)) And (S[J]<>';') And (Length(En)<10) Do Begin En:=En+S[J]; Inc(J); End;
   If (J<=Length(S)) And (S[J]=';') Then Begin
    If En='lt' Then R:=R+'<' Else If En='gt' Then R:=R+'>' Else If En='amp' Then R:=R+'&'
    Else If En='quot' Then R:=R+'"' Else If En='apos' Then R:=R+''''
    Else If En='nbsp' Then R:=R+' '
    Else If (Length(En)>1) And (En[1]='#') Then Begin
     U:=0; Hx:=(En[2]='x') Or (En[2]='X');
     For K:=2+Ord(Hx) To Length(En) Do
      If Hx Then U:=U*16+HexVal(En[K]) Else U:=U*10+(Ord(En[K])-48);
     If U>0 Then R:=R+U8Char(U);
    End Else R:=R+'?';
    I:=J+1;
   End Else Begin R:=R+'&'; Inc(I); End;
  End Else Begin
   If Length(R)<119 Then R:=R+S[I];
   Inc(I);
  End;
 End;
 While (R<>'') And (R[Length(R)]=#10) Do Delete(R,Length(R),1);
 HtmlToText:=R;
End;

{ ========================================================================== }
{                       LECTURE D'UN FICHIER DRAW.IO                         }
{ ========================================================================== }

Procedure FinalizeModel;
Var Done: Array[1..MAX_CELLS] Of Boolean; I: Integer;
 Procedure AbsOf(K: Integer);
 Var P: Integer; J: Integer; C: PCell;
 Begin
  If Done[K] Then Exit;
  Done[K]:=True;
  C:=Cells[K];
  P:=C^.ParIdx;
  If P=0 Then Exit;
  AbsOf(P);
  If C^.Rel Then Exit;
  If Cells[P]^.Kind<>K_VERTEX Then Exit;
  If C^.Kind=K_VERTEX Then Begin
   Inc(C^.X,Cells[P]^.X); Inc(C^.Y,Cells[P]^.Y);
  End Else Begin
   For J:=0 To C^.NPts-1 Do Begin Inc(C^.Pts[J].X,Cells[P]^.X); Inc(C^.Pts[J].Y,Cells[P]^.Y); End;
   Inc(C^.SrcPt.X,Cells[P]^.X); Inc(C^.SrcPt.Y,Cells[P]^.Y);
   Inc(C^.TgtPt.X,Cells[P]^.X); Inc(C^.TgtPt.Y,Cells[P]^.Y);
  End;
 End;
Begin
 ResolveLinks;
 FillChar(Done,SizeOf(Done),0);
 For I:=1 To NCells Do AbsOf(I);
End;

Procedure ParseModel(X: PXml);
Var Cur: Integer; InArr: Boolean; ObjOn: Boolean; ObjId, ObjLabel: String; Nm, V, Sty: String;
    C: PCell; K: Integer; Pt: TPt; Html: Boolean; Idx: Integer;
Begin
 Cur:=0; InArr:=False; ObjOn:=False; ObjId:=''; ObjLabel:='';
 { Attributs de mxGraphModel }
 If XHas(X,'grid') Then GridOn:=XAttr(X,'grid')<>'0';
 If XHas(X,'gridSize') Then GridSize:=Integer(Clamp(IVal(XAttr(X,'gridSize'),10),2,200));
 If XHas(X,'background') Then BgColor:=ParseColor(XAttr(X,'background'),-1);
 If X^.Kind=3 Then Exit;
 While XTag(X) Do Begin
  Nm:=X^.Name;
  If X^.Kind=2 Then Begin
   If Nm='mxGraphModel' Then Break;
   If Nm='mxCell' Then Cur:=0;
   If (Nm='object') Or (Nm='UserObject') Then ObjOn:=False;
   If Nm='Array' Then InArr:=False;
   Continue;
  End;
  If (Nm='object') Or (Nm='UserObject') Then Begin
   ObjOn:=True; ObjId:=XAttr(X,'id');
   ObjLabel:=XAttr(X,'label');
   If (ObjLabel='') And XHas(X,'value') Then ObjLabel:=XAttr(X,'value');
   If X^.Kind=3 Then ObjOn:=False;
  End
  Else If Nm='mxCell' Then Begin
   Cur:=0;
   V:=XAttr(X,'id');
   If ObjOn And (ObjId<>'') Then V:=ObjId;
   If (V='0') Or ((V='1') And (XAttr(X,'parent')='0')) Then Begin
    If X^.Kind=3 Then Cur:=0;
    Continue;
   End;
   If V='' Then V:=MakeId;
   Sty:=XAttr(X,'style');
   If Length(Sty)>=253 Then Begin
    K:=Length(Sty);
    While (K>1) And (Sty[K]<>';') Do Dec(K);
    If K>1 Then Sty:=Copy(Sty,1,K);
   End;
   If XAttr(X,'edge')='1' Then Idx:=NewCell(K_EDGE)
   Else If (XAttr(X,'vertex')='1') Or (XAttr(X,'parent')<>'0') Then Idx:=NewCell(K_VERTEX)
   Else Idx:=NewCell(K_LAYER);
   If Idx=0 Then Begin LastError:=Tr('Too many objects'); Continue; End;
   C:=Cells[Idx];
   C^.Id:=V;
   C^.Parent:=XAttr(X,'parent');
   If C^.Parent='' Then C^.Parent:='1';
   C^.Source:=XAttr(X,'source'); C^.Target:=XAttr(X,'target');
   C^.Style:=Sty;
   If C^.Kind=K_LAYER Then Begin C^.Parent:='0'; End;
   Html:=StyBool(Sty,'html',False);
   If ObjOn Then V:=ObjLabel Else V:=XAttr(X,'value');
   If Html Or (Pos('<',V)>0) Then V:=HtmlToText(V);
   C^.Value:=V;
   If XAttr(X,'visible')='0' Then C^.Hidden:=True;
   If C^.Kind=K_VERTEX Then Begin C^.W:=80; C^.H:=40; End;
   If X^.Kind=1 Then Cur:=Idx;
  End
  Else If (Nm='mxGeometry') And (Cur>0) Then Begin
   C:=Cells[Cur];
   If C^.Kind=K_VERTEX Then Begin
    If XAttr(X,'relative')='1' Then Begin
     C^.Rel:=True;
     C^.X:=ParseNum(XAttr(X,'x')+'')*0;
     V:=XAttr(X,'x');
     If StyFrac('x='+V+';','x',K) Then C^.X:=K;
     C^.Y:=ParseNum(XAttr(X,'y'));
    End Else Begin
     C^.X:=ParseNum(XAttr(X,'x')); C^.Y:=ParseNum(XAttr(X,'y'));
     If XHas(X,'width') Then C^.W:=ParseNum(XAttr(X,'width'));
     If XHas(X,'height') Then C^.H:=ParseNum(XAttr(X,'height'));
    End;
   End;
  End
  Else If (Nm='Array') And (Cur>0) Then InArr:=(X^.Kind=1)
  Else If (Nm='mxPoint') And (Cur>0) Then Begin
   C:=Cells[Cur];
   Pt.X:=ParseNum(XAttr(X,'x')); Pt.Y:=ParseNum(XAttr(X,'y'));
   V:=XAttr(X,'as');
   If V='sourcePoint' Then Begin C^.SrcPt:=Pt; C^.HasSrc:=True; End
   Else If V='targetPoint' Then Begin C^.TgtPt:=Pt; C^.HasTgt:=True; End
   Else If (V='offset') Then Begin
    If C^.Kind=K_VERTEX Then Begin C^.Y:=Pt.Y; End;
   End
   Else If InArr And (C^.Kind=K_EDGE) And (C^.NPts<MAX_PTS) Then Begin
    C^.Pts[C^.NPts]:=Pt; Inc(C^.NPts);
   End;
  End;
 End;
End;

{ Ajoute / initialise une page dans la liste }
Procedure NewPageInfo(Const Nm: String; Idx: Integer);
Begin
 Pages[Idx].Name:=Copy(Nm,1,40);
 If Pages[Idx].Name='' Then Pages[Idx].Name:='Page-'+IStr(Idx+1);
End;

Procedure ResetDocSettings;
Begin
 GridOn:=True; SnapOn:=True; GridSize:=10; BgColor:=-1;
End;

Function PageSnap(N: Integer): String;
Begin
 PageSnap:=TmpName(PageTag,N);
End;

{ Decompresse le contenu texte d'un <diagram> et analyse le modele }
Function ParseCompressed(X: PXml): Boolean;
Var X2: PXml;
Begin
 ParseCompressed:=False;
 XTextToBase64(X,TmpName('A',0));
 If Not InflateFile(TmpName('A',0),TmpName('A',1)) Then Begin LastError:=Tr('Corrupt compressed data'); Exit; End;
 UrlDecodeFile(TmpName('A',1),TmpName('A',2));
 X2:=XOpen(TmpName('A',2));
 If X2=Nil Then Exit;
 While XTag(X2) Do
  If (X2^.Kind=1) And (X2^.Name='mxGraphModel') Then Begin
   ParseModel(X2);
   ParseCompressed:=True;
   Break;
  End;
 XClose(X2);
End;

{ Charge un fichier draw.io. Toutes les pages sont rangees dans des
  instantanes ; la premiere est ensuite chargee en memoire. }
Function ReadDrawio(Const Name: String; Var NPg: Integer): Boolean;
Var X: PXml; InDiag: Boolean; Got: Boolean; PgName: String; Nm: String; Pk: Integer;
 Procedure FinishPage;
 Begin
  FinalizeModel;
  If NPg<MAX_PAGES Then Begin
   NewPageInfo(PgName,NPg);
   PageName:=Pages[NPg].Name;
   SnapSave(PageSnap(NPg));
   Inc(NPg);
  End;
  ClearDoc;
  ResetDocSettings;
 End;
Begin
 ReadDrawio:=False;
 NPg:=0; LastError:='';
 X:=XOpen(Name);
 If X=Nil Then Begin LastError:=Tr('Cannot open file'); Exit; End;
 ClearDoc; ResetDocSettings;
 InDiag:=False; Got:=False; PgName:='';
 While XTag(X) Do Begin
  Nm:=X^.Name;
  If (X^.Kind=1) Or (X^.Kind=3) Then Begin
   If Nm='diagram' Then Begin
    InDiag:=True; Got:=True;
    PgName:=XAttr(X,'name');
    If X^.Kind=3 Then Begin FinishPage; InDiag:=False; End
    Else Begin
     Pk:=XPeek(X);
     If (Pk>=0) And (Pk<>Ord('<')) Then Begin
      ParseCompressed(X);
     End;
    End;
   End
   Else If Nm='mxGraphModel' Then Begin
    Got:=True;
    ParseModel(X);
    If Not InDiag Then FinishPage;
   End;
  End Else If (X^.Kind=2) And (Nm='diagram') Then Begin
   If InDiag Then FinishPage;
   InDiag:=False;
  End;
 End;
 If InDiag Then FinishPage;
 XClose(X);
 If (NPg=0) And Got Then Begin PgName:='Page-1'; FinishPage; End;
 ReadDrawio:=NPg>0;
End;

{ ========================================================================== }
{                      ECRITURE D'UN FICHIER DRAW.IO                         }
{ ========================================================================== }

Type
 TByteBuf = Array[0..16383] Of Byte;
 PByteBuf = ^TByteBuf;

{ Ecrit un texte dans un attribut XML. Html : le texte est converti en HTML
  (les sauts de ligne deviennent <br>) puis echappe pour XML. }
Procedure WAttr(Var T: Text; Const S: String; Html: Boolean);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do
  Case S[I] Of
   '&': If Html Then Write(T,'&amp;amp;') Else Write(T,'&amp;');
   '<': If Html Then Write(T,'&amp;lt;') Else Write(T,'&lt;');
   '>': If Html Then Write(T,'&amp;gt;') Else Write(T,'&gt;');
   '"': Write(T,'&quot;');
   #10: If Html Then Write(T,'&lt;br&gt;') Else Write(T,'&#xa;');
   #13: ;
  Else Write(T,S[I]);
  End;
End;

Function Frac100Str(V: LongInt): String;
Var S: String; A: LongInt;
Begin
 A:=Abs32(V);
 S:=IStr(A Div 100);
 If A Mod 100<>0 Then Begin
  If A Mod 100<10 Then S:=S+'.0'+IStr(A Mod 100)
  Else If A Mod 10=0 Then S:=S+'.'+IStr(A Mod 100 Div 10)
  Else S:=S+'.'+IStr(A Mod 100);
 End;
 If V<0 Then S:='-'+S;
 Frac100Str:=S;
End;

Procedure WritePoint(Var T: Text; Const P: TPt; Const As_: String; OX, OY: LongInt);
Begin
 Write(T,'<mxPoint x="',P.X-OX,'" y="',P.Y-OY,'"');
 If As_<>'' Then Write(T,' as="',As_,'"');
 Write(T,' />');
End;

Procedure WriteModel(Var T: Text);
Var I, K: Integer; C: PCell; Html: Boolean; OX, OY: LongInt; PS: String;
Begin
 Write(T,'<mxGraphModel dx="1000" dy="600" grid="',Ord(GridOn),'" gridSize="',GridSize,
       '" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1"',
       ' pageWidth="850" pageHeight="1100" math="0" shadow="0"');
 If BgColor>=0 Then Write(T,' background="',RGBToHex(BgColor),'"');
 WriteLn(T,'>');
 WriteLn(T,'  <root>');
 WriteLn(T,'    <mxCell id="0" />');
 WriteLn(T,'    <mxCell id="1" parent="0" />');
 For I:=1 To NCells Do Begin
  C:=Cells[I];
  If C^.Kind<>K_LAYER Then Continue;
  Write(T,'    <mxCell id="'); WAttr(T,C^.Id,False);
  Write(T,'" value="'); WAttr(T,C^.Value,False);
  Write(T,'" parent="0"');
  If C^.Hidden Then Write(T,' visible="0"');
  WriteLn(T,' />');
 End;
 For I:=1 To NCells Do Begin
  C:=Cells[I];
  If C^.Kind=K_LAYER Then Continue;
  Html:=StyBool(C^.Style,'html',False);
  Write(T,'    <mxCell id="'); WAttr(T,C^.Id,False);
  Write(T,'" value="'); WAttr(T,C^.Value,Html);
  Write(T,'" style="'); WAttr(T,C^.Style,False);
  If C^.Kind=K_EDGE Then Write(T,'" edge="1"') Else Write(T,'" vertex="1"');
  PS:=C^.Parent;
  If (PS<>'1') And (FindId(PS)=0) Then PS:='1';
  Write(T,' parent="'); WAttr(T,PS,False); Write(T,'"');
  If C^.Hidden Then Write(T,' visible="0"');
  If C^.Kind=K_EDGE Then Begin
   If C^.SrcIdx>0 Then Begin Write(T,' source="'); WAttr(T,C^.Source,False); Write(T,'"'); End;
   If C^.TgtIdx>0 Then Begin Write(T,' target="'); WAttr(T,C^.Target,False); Write(T,'"'); End;
  End;
  WriteLn(T,'>');
  OX:=0; OY:=0;
  If (C^.ParIdx>0) And (Not C^.Rel) Then
   If Cells[C^.ParIdx]^.Kind=K_VERTEX Then Begin OX:=Cells[C^.ParIdx]^.X; OY:=Cells[C^.ParIdx]^.Y; End;
  If C^.Kind=K_VERTEX Then Begin
   If C^.Rel Then Begin
    WriteLn(T,'      <mxGeometry x="',Frac100Str(C^.X),'" y="',C^.Y,'" relative="1" as="geometry">');
    WriteLn(T,'        <mxPoint as="offset" />');
    WriteLn(T,'      </mxGeometry>');
   End Else
    WriteLn(T,'      <mxGeometry x="',C^.X-OX,'" y="',C^.Y-OY,'" width="',C^.W,'" height="',C^.H,'" as="geometry" />');
  End Else Begin
   WriteLn(T,'      <mxGeometry relative="1" as="geometry">');
   If (C^.SrcIdx=0) Then Begin Write(T,'        '); WritePoint(T,C^.SrcPt,'sourcePoint',OX,OY); WriteLn(T); End;
   If (C^.TgtIdx=0) Then Begin Write(T,'        '); WritePoint(T,C^.TgtPt,'targetPoint',OX,OY); WriteLn(T); End;
   If C^.NPts>0 Then Begin
    WriteLn(T,'        <Array as="points">');
    For K:=0 To C^.NPts-1 Do Begin
     Write(T,'          '); WritePoint(T,C^.Pts[K],'',OX,OY); WriteLn(T);
    End;
    WriteLn(T,'        </Array>');
   End;
   WriteLn(T,'      </mxGeometry>');
  End;
  WriteLn(T,'    </mxCell>');
 End;
 WriteLn(T,'  </root>');
 WriteLn(T,'</mxGraphModel>');
End;

{ Base64 en sortie }
Var B64EAcc: LongInt; B64EN: Integer;

Procedure B64EPut(Var T: Text; B: Integer);
Begin
 B64EAcc:=B64EAcc*256+B; Inc(B64EN);
 If B64EN=3 Then Begin
  Write(T,B64[((B64EAcc Shr 18) And 63)+1],B64[((B64EAcc Shr 12) And 63)+1],
        B64[((B64EAcc Shr 6) And 63)+1],B64[(B64EAcc And 63)+1]);
  B64EAcc:=0; B64EN:=0;
 End;
End;

Procedure B64EFlush(Var T: Text);
Begin
 If B64EN=1 Then Begin
  B64EAcc:=B64EAcc*65536;
  Write(T,B64[((B64EAcc Shr 18) And 63)+1],B64[((B64EAcc Shr 12) And 63)+1],'==');
 End Else If B64EN=2 Then Begin
  B64EAcc:=B64EAcc*256;
  Write(T,B64[((B64EAcc Shr 18) And 63)+1],B64[((B64EAcc Shr 12) And 63)+1],B64[((B64EAcc Shr 6) And 63)+1],'=');
 End;
 B64EAcc:=0; B64EN:=0;
End;

{ Encode le fichier Src : encodeURIComponent + deflate (blocs non compresses)
  + Base64. Le resultat est ecrit dans T. }
Procedure EncodeFile(Const Src: String; Var T: Text);
Var FI: File; Inb, Enc: PByteBuf; Got: Word; I, N: Integer; Last: Boolean; B: Byte;
Begin
 B64EAcc:=0; B64EN:=0;
 If HeapFree<2*SizeOf(TByteBuf)+1024 Then Exit;
 New(Inb); New(Enc);
 Assign(FI,Src); {$I-} Reset(FI,1); {$I+}
 If IOResult<>0 Then Begin Dispose(Inb); Dispose(Enc); Exit; End;
 Repeat
  BlockRead(FI,Inb^,4000,Got);
  Last:=Eof(FI);
  N:=0;
  For I:=0 To Got-1 Do Begin
   B:=Inb^[I];
   If ((B>=48) And (B<=57)) Or ((B>=65) And (B<=90)) Or ((B>=97) And (B<=122)) Or
      (B=45) Or (B=95) Or (B=46) Or (B=33) Or (B=126) Or (B=42) Or (B=39) Or (B=40) Or (B=41) Then Begin
    Enc^[N]:=B; Inc(N);
   End Else Begin
    Enc^[N]:=37; Enc^[N+1]:=Ord(HexDigit(B Shr 4)); Enc^[N+2]:=Ord(HexDigit(B And 15)); Inc(N,3);
   End;
  End;
  B64EPut(T,Ord(Last));
  B64EPut(T,N And 255); B64EPut(T,N Shr 8);
  B64EPut(T,(Not N) And 255); B64EPut(T,((Not N) Shr 8) And 255);
  For I:=0 To N-1 Do B64EPut(T,Enc^[I]);
 Until Last;
 B64EFlush(T);
 Close(FI);
 Dispose(Inb); Dispose(Enc);
End;

Function DateStamp: String;
Var Y, M, D, Dw, H, Mi, S, S1: Word;
Begin
 GetDate(Y,M,D,Dw); GetTime(H,Mi,S,S1);
 DateStamp:=IStr(Y)+'-'+Copy(IStr(100+M),2,2)+'-'+Copy(IStr(100+D),2,2)+'T'+
            Copy(IStr(100+H),2,2)+':'+Copy(IStr(100+Mi),2,2)+':'+Copy(IStr(100+S),2,2)+'.000Z';
End;

Procedure WriteDiagram(Var T: Text; Idx: Integer; Comp: Boolean);
Var W: Text;
Begin
 Write(T,'  <diagram id="page',Idx+1,'" name="'); WAttr(T,Pages[Idx].Name,False); Write(T,'">');
 If Not Comp Then Begin
  WriteLn(T);
  WriteModel(T);
  WriteLn(T,'  </diagram>');
 End Else Begin
  Assign(W,TmpName('W',0));
  {$I-} Rewrite(W); {$I+}
  If IOResult=0 Then Begin
   WriteModel(W);
   Close(W);
   EncodeFile(TmpName('W',0),T);
   EraseFile(TmpName('W',0));
  End;
  WriteLn(T,'</diagram>');
 End;
End;

Function SaveDrawio(Const Name: String; Comp: Boolean): Boolean;
Var T: Text; I: Integer;
Begin
 SaveDrawio:=False;
 Pages[CurPage].Name:=PageName;
 SnapSave(PageSnap(CurPage));
 Assign(T,Name);
 {$I-} Rewrite(T); {$I+}
 If IOResult<>0 Then Begin LastError:=Tr('Cannot create file'); Exit; End;
 WriteLn(T,'<mxfile host="CloneDRAW" modified="',DateStamp,'" agent="CloneDRAW DRAWIO.PAS 1.0" version="1.0" type="device">');
 For I:=0 To NPages-1 Do Begin
  If Not SnapLoad(PageSnap(I)) Then Continue;
  WriteDiagram(T,I,Comp);
 End;
 WriteLn(T,'</mxfile>');
 Close(T);
 SnapLoad(PageSnap(CurPage));
 SaveDrawio:=IOResult=0;
End;

{ Ecrit seulement le modele XML (fichier .xml non compresse) }
Function SaveModelXml(Const Name: String): Boolean;
Var T: Text;
Begin
 SaveModelXml:=False;
 Assign(T,Name);
 {$I-} Rewrite(T); {$I+}
 If IOResult<>0 Then Begin LastError:=Tr('Cannot create file'); Exit; End;
 WriteModel(T);
 Close(T);
 SaveModelXml:=IOResult=0;
End;

{ ========================================================================== }
{                              EXPORT SVG                                    }
{ ========================================================================== }

Function SvgColor(C: LongInt): String;
Begin
 If C<0 Then SvgColor:='none' Else SvgColor:=RGBToHex(C);
End;

Procedure SvgEsc(Var T: Text; Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do
  Case S[I] Of
   '&': Write(T,'&amp;');
   '<': Write(T,'&lt;');
   '>': Write(T,'&gt;');
   '"': Write(T,'&quot;');
  Else If S[I]<>#13 Then Write(T,S[I]);
  End;
End;

{ Ecrit le texte d'une etiquette centre en (Cx,Cy) }
Procedure SvgText(Var T: Text; Const S: String; Cx, Cy: LongInt; Anchor: Integer; Fs: Integer;
                  Col: LongInt; FStyle: Integer; MaxW: LongInt; Wrap: Boolean);
Var Lines: Array[1..12] Of String[80]; N, I, Per: Integer; Cur, Wrd: String; Ch: Integer;
    Y0: LongInt;
 Procedure Flush;
 Begin
  If N<12 Then Begin Inc(N); Lines[N]:=Cur; End;
  Cur:='';
 End;
 Procedure AddW;
 Begin
  If Wrd='' Then Exit;
  If (Cur<>'') And Wrap And (Length(Cur)+1+Length(Wrd)>Per) Then Flush;
  If Cur='' Then Cur:=Wrd Else Cur:=Cur+' '+Wrd;
  Wrd:='';
 End;
Begin
 If S='' Then Exit;
 Ch:=Fs*6 Div 10; If Ch<3 Then Ch:=3;
 Per:=Integer(MaxW) Div Ch; If Per<4 Then Per:=4;
 N:=0; Cur:=''; Wrd:='';
 For I:=1 To Length(S) Do
  If S[I]=#10 Then Begin AddW; Flush; End
  Else If S[I]=' ' Then AddW
  Else If Length(Wrd)<78 Then Wrd:=Wrd+S[I];
 AddW;
 If (Cur<>'') Or (N=0) Then Flush;
 Y0:=Cy-LongInt(N-1)*(Fs+2) Div 2;
 Write(T,'<text fill="',SvgColor(Col),'" font-family="Helvetica,Arial,sans-serif" font-size="',Fs,'px"');
 If (FStyle And 1)<>0 Then Write(T,' font-weight="bold"');
 If (FStyle And 2)<>0 Then Write(T,' font-style="italic"');
 If (FStyle And 4)<>0 Then Write(T,' text-decoration="underline"');
 Case Anchor Of
  0: Write(T,' text-anchor="start"');
  2: Write(T,' text-anchor="end"');
 Else Write(T,' text-anchor="middle"');
 End;
 WriteLn(T,' dominant-baseline="central">');
 For I:=1 To N Do Begin
  Write(T,'<tspan x="',Cx,'" y="',Y0+LongInt(I-1)*(Fs+2),'">'); SvgEsc(T,Lines[I]); WriteLn(T,'</tspan>');
 End;
 WriteLn(T,'</text>');
End;

Procedure SvgPoly(Var T: Text; Var P: TPoly; Closed: Boolean; Fill, Stroke: LongInt; Sw: Integer; Dash: Byte);
Var K: Integer;
Begin
 If P.N<2 Then Exit;
 If Closed Then Write(T,'<polygon') Else Write(T,'<polyline');
 Write(T,' points="');
 For K:=0 To P.N-1 Do Begin
  If K>0 Then Write(T,' ');
  Write(T,P.P[K].X,',',P.P[K].Y);
 End;
 Write(T,'" fill="');
 If Closed Then Write(T,SvgColor(Fill)) Else Write(T,'none');
 Write(T,'" stroke="',SvgColor(Stroke),'" stroke-width="',Sw,'"');
 If Dash=1 Then Write(T,' stroke-dasharray="6 4"') Else If Dash=2 Then Write(T,' stroke-dasharray="2 2"');
 WriteLn(T,' />');
End;

Procedure SvgVertex(Var T: Text; I: Integer);
Var C: PCell; M, E, Q: TPoly; Sty, S: String; Fill, Stroke: LongInt; Sw: Integer; Dash: Byte; Sh: Byte;
    K: Integer; AH: Integer; Cx: LongInt; Fs, Fst: Integer; Lab: LongInt;
Begin
 C:=Cells[I]; Sty:=C^.Style; Sh:=CellShape(I);
 Fill:=CellFill(I); Stroke:=CellStroke(I);
 Sw:=Integer(StyInt(Sty,'strokeWidth',1));
 Dash:=EdgeDash(Sty);
 If Sh<>SH_TEXT Then Begin
  If Sh=SH_SWIMLANE Then Begin
   Sw:=Sw;
   Write(T,'<rect x="',C^.X,'" y="',C^.Y,'" width="',C^.W,'" height="',C^.H,'" fill="',
         SvgColor(ParseColor(StyStr(Sty,'swimlaneFillColor',''),-1)),'" stroke="',SvgColor(Stroke),'" />');
   WriteLn(T);
   If StyBool(Sty,'horizontal',True) Then
    WriteLn(T,'<rect x="',C^.X,'" y="',C^.Y,'" width="',C^.W,'" height="',StyInt(Sty,'startSize',23),
            '" fill="',SvgColor(Fill),'" stroke="',SvgColor(Stroke),'" />')
   Else
    WriteLn(T,'<rect x="',C^.X,'" y="',C^.Y,'" width="',StyInt(Sty,'startSize',23),'" height="',C^.H,
            '" fill="',SvgColor(Fill),'" stroke="',SvgColor(Stroke),'" />');
  End Else If Sh=SH_LINE Then Begin
   WriteLn(T,'<line x1="',C^.X,'" y1="',C^.Y+C^.H Div 2,'" x2="',C^.X+C^.W,'" y2="',C^.Y+C^.H Div 2,
           '" stroke="',SvgColor(Stroke),'" stroke-width="',Sw,'" />');
  End Else If Sh=SH_ELLIPSE Then Begin
   Write(T,'<ellipse cx="',C^.X+C^.W Div 2,'" cy="',C^.Y+C^.H Div 2,'" rx="',C^.W Div 2,'" ry="',C^.H Div 2,
         '" fill="',SvgColor(Fill),'" stroke="',SvgColor(Stroke),'" stroke-width="',Sw,'"');
   If Dash=1 Then Write(T,' stroke-dasharray="6 4"');
   WriteLn(T,' />');
  End Else Begin
   BuildShape(I,M,E);
   If (Sh=SH_RECT) And (Not StyBool(Sty,'rounded',False)) Then Begin
    Write(T,'<rect x="',C^.X,'" y="',C^.Y,'" width="',C^.W,'" height="',C^.H,'" fill="',SvgColor(Fill),
          '" stroke="',SvgColor(Stroke),'" stroke-width="',Sw,'"');
    If Dash=1 Then Write(T,' stroke-dasharray="6 4"') Else If Dash=2 Then Write(T,' stroke-dasharray="2 2"');
    WriteLn(T,' />');
   End Else SvgPoly(T,M,True,Fill,Stroke,Sw,Dash);
   If E.N>0 Then Begin
    Q.N:=0;
    For K:=0 To E.N-1 Do Begin
     If E.P[K].X=BRK Then Begin SvgPoly(T,Q,False,-1,Stroke,Sw,0); Q.N:=0; End
     Else PAdd(Q,E.P[K].X,E.P[K].Y);
    End;
    SvgPoly(T,Q,False,-1,Stroke,Sw,0);
   End;
  End;
 End;
 If C^.Value<>'' Then Begin
  S:=LoStr(StyStr(Sty,'align','center'));
  AH:=1; If S='left' Then AH:=0 Else If S='right' Then AH:=2;
  Fs:=Integer(StyInt(Sty,'fontSize',12)); Fst:=Integer(StyInt(Sty,'fontStyle',0));
  Case AH Of
   0: Cx:=C^.X+4;
   2: Cx:=C^.X+C^.W-4;
  Else Cx:=C^.X+C^.W Div 2;
  End;
  Lab:=C^.Y+C^.H Div 2;
  If Sh=SH_SWIMLANE Then Lab:=C^.Y+StyInt(Sty,'startSize',23) Div 2;
  If LoStr(StyStr(Sty,'verticalLabelPosition',''))='bottom' Then Lab:=C^.Y+C^.H+Fs;
  If LoStr(StyStr(Sty,'verticalAlign',''))='top' Then Lab:=C^.Y+Fs;
  If LoStr(StyStr(Sty,'verticalAlign',''))='bottom' Then Lab:=C^.Y+C^.H-Fs;
  SvgText(T,C^.Value,Cx,Lab,AH,Fs,CellFontColor(I),Fst,C^.W-8,StyStr(Sty,'whiteSpace','')='wrap');
 End;
End;

Procedure SvgArrow(Var T: Text; Kind: Byte; Tx, Ty, Fx, Fy: LongInt; Col: LongInt; Filled: Boolean);
Var Ux, Uy, L, Len, Wd, Nx, Ny: Real; Fl: String;
 Function Pt(A, B: Real): String;
 Begin
  Pt:=IStr(Round(Tx+Ux*A+Nx*B))+','+IStr(Round(Ty+Uy*A+Ny*B));
 End;
Begin
 If Kind=AR_NONE Then Exit;
 L:=Sqrt(Sqr(1.0*(Tx-Fx))+Sqr(1.0*(Ty-Fy)));
 If L<0.5 Then Exit;
 Ux:=(Tx-Fx)/L; Uy:=(Ty-Fy)/L; Nx:=-Uy; Ny:=Ux;
 Len:=10; Wd:=4.5;
 If (Kind=AR_CLASSICTHIN) Or (Kind=AR_BLOCKTHIN) Then Wd:=3;
 If Filled Then Fl:=SvgColor(Col) Else Fl:='#ffffff';
 Case Kind Of
  AR_CLASSIC,AR_CLASSICTHIN:
   WriteLn(T,'<polygon points="',Pt(0,0),' ',Pt(-Len,-Wd),' ',Pt(-Len*0.7,0),' ',Pt(-Len,Wd),
           '" fill="',Fl,'" stroke="',SvgColor(Col),'" />');
  AR_BLOCK,AR_BLOCKTHIN:
   WriteLn(T,'<polygon points="',Pt(0,0),' ',Pt(-Len,-Wd),' ',Pt(-Len,Wd),'" fill="',Fl,'" stroke="',SvgColor(Col),'" />');
  AR_OPEN:
   WriteLn(T,'<polyline points="',Pt(-Len,-Wd),' ',Pt(0,0),' ',Pt(-Len,Wd),'" fill="none" stroke="',SvgColor(Col),'" />');
  AR_OVAL:
   WriteLn(T,'<circle cx="',Round(Tx-Ux*Len/2),'" cy="',Round(Ty-Uy*Len/2),'" r="',Round(Len/2),'" fill="',Fl,'" stroke="',SvgColor(Col),'" />');
  AR_DIAMOND:
   WriteLn(T,'<polygon points="',Pt(0,0),' ',Pt(-Len*0.6,-Wd),' ',Pt(-Len*1.2,0),' ',Pt(-Len*0.6,Wd),
           '" fill="',Fl,'" stroke="',SvgColor(Col),'" />');
  AR_DASH:
   WriteLn(T,'<line x1="',Pt(-Len*0.5,-Wd),'" x2="',Pt(-Len*0.5,Wd),'" stroke="',SvgColor(Col),'" />');
 End;
End;

Procedure SvgEdge(Var T: Text; I: Integer);
Var C: PCell; Pl: TPoly; Sd, Td, K: Integer; Sty: String; Stroke: LongInt; Sw: Integer; Dash: Byte;
    EA, SA: Byte; Mx, My: LongInt; Fs: Integer;
Begin
 C:=Cells[I]; Sty:=C^.Style;
 EdgePath(I,Pl,Sd,Td);
 If Pl.N<2 Then Exit;
 Stroke:=CellStroke(I);
 If Stroke<0 Then Exit;
 Sw:=Integer(StyInt(Sty,'strokeWidth',1));
 Dash:=EdgeDash(Sty);
 EA:=ArrowKind(StyStr(Sty,'endArrow','classic'));
 SA:=ArrowKind(StyStr(Sty,'startArrow','none'));
 SvgPoly(T,Pl,False,-1,Stroke,Sw,Dash);
 K:=Pl.N-1;
 SvgArrow(T,EA,Pl.P[K].X,Pl.P[K].Y,Pl.P[K-1].X,Pl.P[K-1].Y,Stroke,StyInt(Sty,'endFill',1)<>0);
 SvgArrow(T,SA,Pl.P[0].X,Pl.P[0].Y,Pl.P[1].X,Pl.P[1].Y,Stroke,StyInt(Sty,'startFill',1)<>0);
 If C^.Value<>'' Then Begin
  PathAt(Pl,50,Mx,My);
  Fs:=Integer(StyInt(Sty,'fontSize',12));
  If ParseColor(StyStr(Sty,'labelBackgroundColor',''),-1)>=0 Then
   WriteLn(T,'<rect x="',Mx-Length(C^.Value)*Fs*3 Div 10,'" y="',My-Fs Div 2-1,'" width="',Length(C^.Value)*Fs*6 Div 10,
           '" height="',Fs+2,'" fill="',SvgColor(ParseColor(StyStr(Sty,'labelBackgroundColor',''),-1)),'" />');
  SvgText(T,C^.Value,Mx,My,1,Fs,CellFontColor(I),Integer(StyInt(Sty,'fontStyle',0)),200,False);
 End;
End;

Function ExportSvg(Const Name: String): Boolean;
Var T: Text; I: Integer; X1, Y1, X2, Y2, A, B, C2, D: LongInt; First: Boolean;
Begin
 ExportSvg:=False;
 First:=True; X1:=0; Y1:=0; X2:=100; Y2:=100;
 For I:=1 To NCells Do Begin
  If (Cells[I]^.Kind=K_LAYER) Or (Not Visible(I)) Then Continue;
  If IsEdgeLabel(I) Then Continue;
  CellBounds(I,A,B,C2,D);
  If First Then Begin X1:=A; Y1:=B; X2:=C2; Y2:=D; First:=False; End
  Else Begin
   If A<X1 Then X1:=A;
   If B<Y1 Then Y1:=B;
   If C2>X2 Then X2:=C2;
   If D>Y2 Then Y2:=D;
  End;
 End;
 X1:=X1-10; Y1:=Y1-10; X2:=X2+10; Y2:=Y2+10;
 Assign(T,Name);
 {$I-} Rewrite(T); {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(T,'<?xml version="1.0" encoding="UTF-8"?>');
 WriteLn(T,'<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="',X2-X1,'px" height="',Y2-Y1,
         'px" viewBox="',X1,' ',Y1,' ',X2-X1,' ',Y2-Y1,'" style="background-color: ',
         SvgColor(BgColor+Ord(BgColor<0)*($FFFFFF+1)),';">');
 For I:=1 To NCells Do Begin
  If (Cells[I]^.Kind=K_LAYER) Or (Not Visible(I)) Then Continue;
  If Cells[I]^.Kind=K_EDGE Then SvgEdge(T,I)
  Else If Not IsEdgeLabel(I) Then SvgVertex(T,I);
 End;
 WriteLn(T,'</svg>');
 Close(T);
 ExportSvg:=IOResult=0;
End;

{ ========================================================================== }
{                  BIBLIOTHEQUE DE FORMES (panneau de gauche)                }
{ ========================================================================== }

Const
 NDEFS = 55;
 ShapeDefs: Array[0..NDEFS-1] Of TShapeDef = (
  (Name:'Rectangle'; Sty:'rounded=0;whiteSpace=wrap;html=1;'; W:120; H:60; Sec:0),
  (Name:'Rounded Rectangle'; Sty:'rounded=1;whiteSpace=wrap;html=1;'; W:120; H:60; Sec:0),
  (Name:'Text'; Sty:'text;html=1;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;whiteSpace=wrap;rounded=0;'; W:60; H:30; Sec:0),
  (Name:'Square'; Sty:'whiteSpace=wrap;html=1;aspect=fixed;'; W:80; H:80; Sec:0),
  (Name:'Ellipse'; Sty:'ellipse;whiteSpace=wrap;html=1;'; W:120; H:80; Sec:0),
  (Name:'Circle'; Sty:'ellipse;whiteSpace=wrap;html=1;aspect=fixed;'; W:80; H:80; Sec:0),
  (Name:'Process'; Sty:'shape=process;whiteSpace=wrap;html=1;backgroundOutline=1;'; W:120; H:60; Sec:0),
  (Name:'Diamond'; Sty:'rhombus;whiteSpace=wrap;html=1;'; W:80; H:80; Sec:0),
  (Name:'Parallelogram'; Sty:'shape=parallelogram;perimeter=parallelogramPerimeter;whiteSpace=wrap;html=1;fixedSize=1;'; W:120; H:60; Sec:0),
  (Name:'Hexagon'; Sty:'shape=hexagon;perimeter=hexagonPerimeter2;whiteSpace=wrap;html=1;fixedSize=1;'; W:120; H:80; Sec:0),
  (Name:'Triangle'; Sty:'triangle;whiteSpace=wrap;html=1;'; W:60; H:80; Sec:0),
  (Name:'Cylinder'; Sty:'shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;'; W:60; H:80; Sec:0),
  (Name:'Cloud'; Sty:'ellipse;shape=cloud;whiteSpace=wrap;html=1;'; W:120; H:80; Sec:0),
  (Name:'Document'; Sty:'shape=document;whiteSpace=wrap;html=1;boundedLbl=1;'; W:120; H:80; Sec:0),
  (Name:'Step'; Sty:'shape=step;perimeter=stepPerimeter;whiteSpace=wrap;html=1;fixedSize=1;'; W:120; H:80; Sec:0),
  (Name:'Trapezoid'; Sty:'shape=trapezoid;perimeter=trapezoidPerimeter;whiteSpace=wrap;html=1;fixedSize=1;'; W:120; H:60; Sec:0),
  (Name:'Note'; Sty:'shape=note;whiteSpace=wrap;html=1;backgroundOutline=1;darkOpacity=0.05;'; W:80; H:100; Sec:0),
  (Name:'Card'; Sty:'shape=card;whiteSpace=wrap;html=1;'; W:80; H:100; Sec:0),
  (Name:'Actor'; Sty:'shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;outlineConnect=0;'; W:30; H:60; Sec:0),
  (Name:'Cube'; Sty:'shape=cube;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;'; W:120; H:80; Sec:0),
  (Name:'Process'; Sty:'rounded=0;whiteSpace=wrap;html=1;'; W:120; H:60; Sec:1),
  (Name:'Decision'; Sty:'rhombus;whiteSpace=wrap;html=1;'; W:100; H:80; Sec:1),
  (Name:'Start / End'; Sty:'rounded=1;whiteSpace=wrap;html=1;arcSize=50;'; W:120; H:50; Sec:1),
  (Name:'Data'; Sty:'shape=parallelogram;perimeter=parallelogramPerimeter;whiteSpace=wrap;html=1;fixedSize=1;'; W:120; H:60; Sec:1),
  (Name:'Document'; Sty:'shape=document;whiteSpace=wrap;html=1;boundedLbl=1;'; W:120; H:80; Sec:1),
  (Name:'Predefined Process'; Sty:'shape=process;whiteSpace=wrap;html=1;backgroundOutline=1;'; W:120; H:60; Sec:1),
  (Name:'Database'; Sty:'shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;'; W:60; H:80; Sec:1),
  (Name:'Delay'; Sty:'shape=delay;whiteSpace=wrap;html=1;'; W:80; H:40; Sec:1),
  (Name:'Manual Input'; Sty:'shape=manualInput;whiteSpace=wrap;html=1;'; W:100; H:60; Sec:1),
  (Name:'Connector'; Sty:'ellipse;whiteSpace=wrap;html=1;aspect=fixed;'; W:40; H:40; Sec:1),
  (Name:'Off-page Connector'; Sty:'shape=offPageConnector;whiteSpace=wrap;html=1;'; W:60; H:60; Sec:1),
  (Name:'Display'; Sty:'shape=display;whiteSpace=wrap;html=1;'; W:100; H:60; Sec:1),
  (Name:'Preparation'; Sty:'shape=hexagon;perimeter=hexagonPerimeter2;whiteSpace=wrap;html=1;fixedSize=1;'; W:100; H:60; Sec:1),
  (Name:'Right Arrow'; Sty:'shape=singleArrow;whiteSpace=wrap;html=1;arrowWidth=0.4;arrowSize=0.4;'; W:80; H:40; Sec:2),
  (Name:'Left Arrow'; Sty:'shape=singleArrow;direction=west;whiteSpace=wrap;html=1;arrowWidth=0.4;arrowSize=0.4;'; W:80; H:40; Sec:2),
  (Name:'Up Arrow'; Sty:'shape=singleArrow;direction=north;whiteSpace=wrap;html=1;arrowWidth=0.4;arrowSize=0.4;'; W:40; H:80; Sec:2),
  (Name:'Down Arrow'; Sty:'shape=singleArrow;direction=south;whiteSpace=wrap;html=1;arrowWidth=0.4;arrowSize=0.4;'; W:40; H:80; Sec:2),
  (Name:'Double Arrow'; Sty:'shape=doubleArrow;whiteSpace=wrap;html=1;arrowWidth=0.4;arrowSize=0.2;'; W:100; H:40; Sec:2),
  (Name:'Double Arrow V'; Sty:'shape=doubleArrow;direction=south;whiteSpace=wrap;html=1;arrowWidth=0.4;arrowSize=0.2;'; W:40; H:100; Sec:2),
  (Name:'Line'; Sty:'endArrow=none;html=1;rounded=0;'; W:80; H:0; Sec:3),
  (Name:'Arrow'; Sty:'endArrow=classic;html=1;rounded=0;'; W:80; H:0; Sec:3),
  (Name:'Dashed Arrow'; Sty:'endArrow=classic;html=1;rounded=0;dashed=1;'; W:80; H:0; Sec:3),
  (Name:'Bidirectional Arrow'; Sty:'endArrow=classic;startArrow=classic;html=1;rounded=0;'; W:80; H:0; Sec:3),
  (Name:'Dotted Line'; Sty:'endArrow=none;dashed=1;html=1;dashPattern=1 3;strokeWidth=2;rounded=0;'; W:80; H:0; Sec:3),
  (Name:'Orthogonal Arrow'; Sty:'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;'; W:80; H:40; Sec:3),
  (Name:'Curved Arrow'; Sty:'curved=1;endArrow=classic;html=1;'; W:80; H:40; Sec:3),
  (Name:'Open Arrow'; Sty:'endArrow=open;html=1;rounded=0;endSize=12;'; W:80; H:0; Sec:3),
  (Name:'Diamond Arrow'; Sty:'endArrow=diamondThin;endFill=0;endSize=14;html=1;rounded=0;'; W:80; H:0; Sec:3),
  (Name:'Swimlane'; Sty:'swimlane;whiteSpace=wrap;html=1;startSize=23;'; W:200; H:140; Sec:4),
  (Name:'Vertical Swimlane'; Sty:'swimlane;horizontal=0;whiteSpace=wrap;html=1;startSize=23;'; W:140; H:200; Sec:4),
  (Name:'Container'; Sty:'rounded=1;whiteSpace=wrap;html=1;dashed=1;fillColor=none;container=1;'; W:240; H:160; Sec:4),
  (Name:'Group'; Sty:'group'; W:160; H:120; Sec:4),
  (Name:'Heading'; Sty:'text;html=1;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;whiteSpace=wrap;rounded=0;fontSize=20;fontStyle=1;'; W:200; H:40; Sec:4),
  (Name:'Sticky Note'; Sty:'shape=note;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;size=14;'; W:100; H:100; Sec:4),
  (Name:'Label'; Sty:'rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;'; W:120; H:40; Sec:4));

Var
 TmpCell: PCell;

Procedure InitTmp;
Begin
 New(TmpCell);
 FillChar(TmpCell^,SizeOf(TCell),0);
End;

{ Dessine la miniature de la forme D dans la case (X,Y,W,H) de l'ecran }
Procedure DrawThumbReal(D: Integer; X, Y, W, H: Integer);
Var SvOx, SvOy, SvZ, SvVx, SvVy: LongInt; Z: LongInt; Dw, Dh: LongInt; C: PCell;
Begin
 If NCells>=MAX_CELLS Then Exit;
 C:=TmpCell;
 FillChar(C^,SizeOf(TCell),0);
 C^.Id:='tmp'; C^.Parent:='1';
 C^.Style:=ShapeDefs[D].Sty;
 Dw:=ShapeDefs[D].W; Dh:=ShapeDefs[D].H;
 If ShapeDefs[D].Sec=3 Then Begin
  C^.Kind:=K_EDGE;
  C^.SrcPt.X:=0; C^.SrcPt.Y:=Dh; C^.TgtPt.X:=Dw; C^.TgtPt.Y:=0;
  If Dh=0 Then Begin C^.SrcPt.Y:=0; C^.TgtPt.Y:=0; End;
  If Pos('orthogonal',C^.Style)>0 Then Begin C^.NPts:=0; End;
  C^.HasSrc:=True; C^.HasTgt:=True;
  Dh:=Max(Dh,1);
 End Else Begin
  C^.Kind:=K_VERTEX;
  C^.X:=0; C^.Y:=0; C^.W:=Dw; C^.H:=Dh;
 End;
 Z:=Min((W-4)*100 Div Dw,(H-4)*100 Div Dh);
 If Z>100 Then Z:=100;
 If Z<5 Then Z:=5;
 SvOx:=OfsX; SvOy:=OfsY; SvZ:=Zoom; SvVx:=ViewX; SvVy:=ViewY;
 Zoom:=Z; ViewX:=0; ViewY:=0;
 OfsX:=X+(W-Dw*Z Div 100) Div 2; OfsY:=Y+(H-Dh*Z Div 100) Div 2;
 Cells[NCells+1]:=C;
 NoCull:=True;
 If C^.Kind=K_EDGE Then DrawEdge(NCells+1) Else DrawVertexShape(NCells+1,False);
 NoCull:=False;
 Cells[NCells+1]:=Nil;
 OfsX:=SvOx; OfsY:=SvOy; Zoom:=SvZ; ViewX:=SvVx; ViewY:=SvVy;
End;

{ ========================================================================== }
{                                MENUS                                       }
{ ========================================================================== }

Const
 MENU_FILE = 0; MENU_EDIT = 1; MENU_VIEW = 2; MENU_ARRANGE = 3; MENU_EXTRAS = 4; MENU_HELP = 5;
 NMENUS = 6;
 MaxItems = 26;

Type
 TMenuItem = Record
  Caption: String[30];
  Shortcut: String[10];
  Id: Integer;
  Sep: Boolean;
  Checked: Boolean;
 End;
 TMenu = Record
  Title: String[12];
  X, W: Integer;
  N: Integer;
  Items: Array[0..MaxItems-1] Of TMenuItem;
 End;

 { Identifiants des commandes }
Const
 CM_NEW=1; CM_OPEN=2; CM_SAVE=3; CM_SAVEAS=4; CM_IMPORT=5; CM_EXPSVG=6; CM_EXPXML=7; CM_QUIT=8;
 CM_UNDO=10; CM_REDO=11; CM_CUT=12; CM_COPY=13; CM_PASTE=14; CM_DELETE=15; CM_DUP=16;
 CM_EDITSTYLE=17; CM_EDITLABEL=18; CM_COPYSTYLE=19; CM_PASTESTYLE=20; CM_SELALL=21;
 CM_SELNONE=22; CM_SELV=23; CM_SELE=24;
 CM_SHAPES=30; CM_FORMAT=31; CM_GRID=32; CM_SNAP=33; CM_ZIN=34; CM_ZOUT=35; CM_Z100=36; CM_ZFIT=37;
 CM_FRONT=40; CM_BACK=41; CM_FWD=42; CM_BWD=43; CM_GROUP=44; CM_UNGROUP=45;
 CM_AL=46; CM_AC=47; CM_AR=48; CM_AT=49; CM_AM=50; CM_AB=51; CM_DH=52; CM_DV=53; CM_CLRPTS=54;
 CM_COMPR=60; CM_GRIDSZ=61; CM_BGCOL=62; CM_ESTR=63; CM_EORT=64; CM_ECUR=65;
 CM_ADDPAGE=66; CM_DELPAGE=67; CM_RENPAGE=68; CM_PREVPAGE=69; CM_NEXTPAGE=70;
 CM_KEYS=80; CM_ABOUT=81;

Var
 Menus: Array[0..NMENUS-1] Of TMenu;
 AltKeys: Array[0..NMENUS-1] Of Byte;   { Codes Alt+lettre de chaque menu }

Procedure AddItem(M: Integer; Const Cap, Sc: String; Id: Integer);
Begin
 With Menus[M] Do Begin
  If N>=MaxItems Then Exit;
  Items[N].Caption:=Cap; Items[N].Shortcut:=Sc; Items[N].Id:=Id;
  Items[N].Sep:=False; Items[N].Checked:=False;
  Inc(N);
 End;
End;

Procedure AddSep(M: Integer);
Begin
 With Menus[M] Do Begin
  If N>=MaxItems Then Exit;
  Items[N].Sep:=True; Items[N].Id:=0; Items[N].Caption:=''; Items[N].Shortcut:='';
  Items[N].Checked:=False;
  Inc(N);
 End;
End;

Procedure InitMenus;
Var M, I, X, W, L: Integer;
Begin
 FillChar(Menus,SizeOf(Menus),0);
 Menus[0].Title:=Tr('File'); Menus[1].Title:=Tr('Edit'); Menus[2].Title:=Tr('View');
 Menus[3].Title:=Tr('Arrange'); Menus[4].Title:=Tr('Extras'); Menus[5].Title:=Tr('Help');

 AddItem(0,Tr('New'),'Ctrl+N',CM_NEW);
 AddItem(0,Tr('Open...'),'Ctrl+O',CM_OPEN);
 AddSep(0);
 AddItem(0,Tr('Save'),'Ctrl+S',CM_SAVE);
 AddItem(0,Tr('Save as...'),'',CM_SAVEAS);
 AddSep(0);
 AddItem(0,Tr('Import from file...'),'',CM_IMPORT);
 AddItem(0,Tr('Export as SVG...'),'',CM_EXPSVG);
 AddItem(0,Tr('Export as XML...'),'',CM_EXPXML);
 AddSep(0);
 AddItem(0,Tr('Exit'),'Ctrl+Q',CM_QUIT);

 AddItem(1,Tr('Undo'),'Ctrl+Z',CM_UNDO);
 AddItem(1,Tr('Redo'),'Ctrl+Y',CM_REDO);
 AddSep(1);
 AddItem(1,Tr('Cut'),'Ctrl+X',CM_CUT);
 AddItem(1,Tr('Copy'),'Ctrl+C',CM_COPY);
 AddItem(1,Tr('Paste'),'Ctrl+V',CM_PASTE);
 AddItem(1,Tr('Delete'),Tr('Del'),CM_DELETE);
 AddItem(1,Tr('Duplicate'),'Ctrl+D',CM_DUP);
 AddSep(1);
 AddItem(1,Tr('Edit Style...'),'Ctrl+E',CM_EDITSTYLE);
 AddItem(1,Tr('Edit Label'),'F2',CM_EDITLABEL);
 AddItem(1,Tr('Copy Style'),'',CM_COPYSTYLE);
 AddItem(1,Tr('Paste Style'),'',CM_PASTESTYLE);
 AddSep(1);
 AddItem(1,Tr('Select All'),'Ctrl+A',CM_SELALL);
 AddItem(1,Tr('Select None'),'',CM_SELNONE);
 AddItem(1,Tr('Select Vertices'),'',CM_SELV);
 AddItem(1,Tr('Select Edges'),'',CM_SELE);

 AddItem(2,Tr('Shapes'),'',CM_SHAPES);
 AddItem(2,Tr('Format'),'',CM_FORMAT);
 AddSep(2);
 AddItem(2,Tr('Grid'),'F9',CM_GRID);
 AddItem(2,Tr('Snap to Grid'),'F8',CM_SNAP);
 AddSep(2);
 AddItem(2,Tr('Zoom In'),'+',CM_ZIN);
 AddItem(2,Tr('Zoom Out'),'-',CM_ZOUT);
 AddItem(2,Tr('Reset Zoom (100%)'),'Home',CM_Z100);
 AddItem(2,Tr('Fit to Window'),Tr('End'),CM_ZFIT);

 AddItem(3,Tr('To Front'),'Ctrl+F',CM_FRONT);
 AddItem(3,Tr('To Back'),'Ctrl+B',CM_BACK);
 AddItem(3,Tr('Bring Forward'),'',CM_FWD);
 AddItem(3,Tr('Send Backward'),'',CM_BWD);
 AddSep(3);
 AddItem(3,Tr('Group'),'Ctrl+G',CM_GROUP);
 AddItem(3,Tr('Ungroup'),'Ctrl+U',CM_UNGROUP);
 AddSep(3);
 AddItem(3,Tr('Align Left'),'',CM_AL);
 AddItem(3,Tr('Align Center'),'',CM_AC);
 AddItem(3,Tr('Align Right'),'',CM_AR);
 AddItem(3,Tr('Align Top'),'',CM_AT);
 AddItem(3,Tr('Align Middle'),'',CM_AM);
 AddItem(3,Tr('Align Bottom'),'',CM_AB);
 AddItem(3,Tr('Distribute Horizontally'),'',CM_DH);
 AddItem(3,Tr('Distribute Vertically'),'',CM_DV);
 AddSep(3);
 AddItem(3,Tr('Clear Waypoints'),'',CM_CLRPTS);

 AddItem(4,Tr('Compressed XML'),'',CM_COMPR);
 AddItem(4,Tr('Grid Size...'),'',CM_GRIDSZ);
 AddItem(4,Tr('Background Color...'),'',CM_BGCOL);
 AddSep(4);
 AddItem(4,Tr('New edges: Straight'),'',CM_ESTR);
 AddItem(4,Tr('New edges: Orthogonal'),'',CM_EORT);
 AddItem(4,Tr('New edges: Curved'),'',CM_ECUR);
 AddSep(4);
 AddItem(4,Tr('Add Page'),'',CM_ADDPAGE);
 AddItem(4,Tr('Delete Page'),'',CM_DELPAGE);
 AddItem(4,Tr('Rename Page...'),'',CM_RENPAGE);
 AddItem(4,Tr('Previous Page'),'PgUp',CM_PREVPAGE);
 AddItem(4,Tr('Next Page'),'PgDn',CM_NEXTPAGE);

 AddItem(5,Tr('Keyboard Shortcuts'),'F1',CM_KEYS);
 AddItem(5,Tr('About DRAWIO'),'',CM_ABOUT);

 X:=6;
 For M:=0 To NMENUS-1 Do Begin
  Menus[M].X:=X;
  W:=0;
  For I:=0 To Menus[M].N-1 Do Begin
   L:=ULen(Menus[M].Items[I].Caption)*8+ULen(Menus[M].Items[I].Shortcut)*8+44;
   If L>W Then W:=L;
  End;
  Menus[M].W:=W;
  X:=X+ULen(Menus[M].Title)*8+16;
 End;
 { Alt+lettre : codes de balayage }
 If LangFr Then Begin
  AltKeys[0]:=33; AltKeys[1]:=18; AltKeys[2]:=30; AltKeys[3]:=24; AltKeys[4]:=45; AltKeys[5]:=23;
 End Else Begin
  AltKeys[0]:=33; AltKeys[1]:=18; AltKeys[2]:=47; AltKeys[3]:=30; AltKeys[4]:=45; AltKeys[5]:=35;
 End;
End;

Function MenuChecked(Id: Integer): Boolean;
Begin
 Case Id Of
  CM_SHAPES: MenuChecked:=ShowLeft;
  CM_FORMAT: MenuChecked:=ShowRight;
  CM_GRID: MenuChecked:=GridOn;
  CM_SNAP: MenuChecked:=SnapOn;
  CM_COMPR: MenuChecked:=CompressedSave;
  CM_ESTR: MenuChecked:=DefaultEdgeStyle=0;
  CM_EORT: MenuChecked:=DefaultEdgeStyle=1;
  CM_ECUR: MenuChecked:=DefaultEdgeStyle=2;
 Else MenuChecked:=False;
 End;
End;

Procedure DrawMenuBar;
Var M, X: Integer; T: String;
Begin
 DBar(0,0,SCR_W-1,MENU_H-1,C_WHITE);
 SetColor(C_BORDER); DLine(0,MENU_H-1,SCR_W-1,MENU_H-1);
 SetText(1);
 For M:=0 To NMENUS-1 Do Begin
  X:=Menus[M].X;
  If MenuOpen And (ActiveMenu=M) Then Begin
   DBar(X-5,0,X+ULen(Menus[M].Title)*8+4,MENU_H-2,C_ACCENT);
   DText(X,4,Menus[M].Title,C_WHITE);
  End Else DText(X,4,Menus[M].Title,C_BLACK);
  AddHit(X-5,0,X+ULen(Menus[M].Title)*8+4,MENU_H-1,A_MENU,M,0);
 End;
 { Nom du fichier a droite }
 If FileName='' Then T:=Tr('Untitled') Else T:=FileName;
 If Length(T)>26 Then T:='...'+Copy(T,Length(T)-22,23);
 If Modified Then T:=T+' *';
 DText(SCR_W-Length(T)*8-6,4,T,C_DARK);
End;

Procedure DrawMenuDrop;
Var M, I, X, Y, W, H: Integer; It: ^TMenuItem;
Begin
 If Not MenuOpen Then Exit;
 M:=ActiveMenu;
 X:=Menus[M].X-6; Y:=MENU_H; W:=Menus[M].W; H:=Menus[M].N*16+4;
 If X+W>SCR_W-2 Then X:=SCR_W-2-W;
 HideMouse;
 DBar(X+3,Y+3,X+W+3,Y+H+3,C_BORDER);
 DBar(X,Y,X+W,Y+H,C_WHITE);
 DRect(X,Y,X+W,Y+H,C_DARK);
 SetText(1);
 For I:=0 To Menus[M].N-1 Do Begin
  It:=@Menus[M].Items[I];
  If It^.Sep Then Begin
   SetColor(C_BORDER); DLine(X+3,Y+2+I*16+8,X+W-3,Y+2+I*16+8);
  End Else Begin
   If ActiveItem=I Then Begin
    DBar(X+2,Y+2+I*16,X+W-2,Y+2+I*16+15,C_ACCENT);
    DText(X+22,Y+2+I*16+4,It^.Caption,C_WHITE);
    DText(X+W-Length(It^.Shortcut)*8-8,Y+2+I*16+4,It^.Shortcut,C_WHITE);
    If MenuChecked(It^.Id) Then DTextRaw(X+7,Y+2+I*16+4,#251,C_WHITE);
   End Else Begin
    DText(X+22,Y+2+I*16+4,It^.Caption,C_BLACK);
    DText(X+W-Length(It^.Shortcut)*8-8,Y+2+I*16+4,It^.Shortcut,C_DARK);
    If MenuChecked(It^.Id) Then DTextRaw(X+7,Y+2+I*16+4,#251,C_BLACK);
   End;
  End;
 End;
 ShowMouse;
End;

{ Index de l'element de menu sous (MX,MY), ou -1 }
Function MenuItemAt(MX, MY: Integer): Integer;
Var M, X, Y, W, H, I: Integer;
Begin
 MenuItemAt:=-1;
 If Not MenuOpen Then Exit;
 M:=ActiveMenu;
 X:=Menus[M].X-6; Y:=MENU_H; W:=Menus[M].W; H:=Menus[M].N*16+4;
 If X+W>SCR_W-2 Then X:=SCR_W-2-W;
 If (MX<X) Or (MX>X+W) Or (MY<Y) Or (MY>Y+H) Then Exit;
 I:=(MY-Y-2) Div 16;
 If (I>=0) And (I<Menus[M].N) Then MenuItemAt:=I;
End;

{ ========================================================================== }
{                          ELEMENTS D'INTERFACE                              }
{ ========================================================================== }

Procedure DrawButton(X1, Y1, X2, Y2: Integer; Const Cap: String; Act: Integer; P1, P2: LongInt);
Begin
 Bevel(X1,Y1,X2,Y2,True,C_PANEL);
 TextC(X1,X2,(Y1+Y2) Div 2-3,Cap,C_BLACK);
 AddHit(X1,Y1,X2,Y2,Act,P1,P2);
End;

Procedure DrawCheck(X, Y: Integer; Checked: Boolean; Const Cap: String; Id: LongInt; Enabled: Boolean);
Begin
 DBar(X,Y,X+9,Y+9,C_WHITE);
 DRect(X,Y,X+9,Y+9,C_DARK);
 If Checked Then Begin
  SetColor(C_BLACK);
  DLine(X+2,Y+4,X+4,Y+7); DLine(X+4,Y+7,X+8,Y+2);
  DLine(X+2,Y+5,X+4,Y+8); DLine(X+4,Y+8,X+8,Y+3);
 End;
 If Enabled Then DText(X+15,Y+1,Cap,C_BLACK) Else DText(X+15,Y+1,Cap,C_DARK);
 If Enabled Then AddHit(X,Y-1,X+15+Length(Cap)*8,Y+10,A_CHECK,Id,0);
End;

Procedure DrawSwatch(X1, Y1, X2, Y2: Integer; Rgb: LongInt; Act: Integer; P1: LongInt);
Begin
 If Rgb<0 Then Begin
  DBar(X1,Y1,X2,Y2,C_WHITE);
  SetColor(C_SRED); DLine(X1,Y2,X2,Y1);
 End Else DBar(X1,Y1,X2,Y2,PalOf(Rgb));
 DRect(X1,Y1,X2,Y2,C_BLACK);
 DRect(X1+1,Y1+1,X2-1,Y2-1,C_WHITE);
 AddHit(X1,Y1,X2,Y2,Act,P1,0);
End;

Procedure DrawDrop(X1, Y1, X2, Y2: Integer; Const Txt: String; P1: LongInt);
Begin
 DBar(X1,Y1,X2,Y2,C_WHITE);
 DRect(X1,Y1,X2,Y2,C_DARK);
 DText(X1+4,Y1+(Y2-Y1) Div 2-3,Copy(Txt,1,(X2-X1-18) Div 8),C_BLACK);
 DBar(X2-13,Y1+1,X2-1,Y2-1,C_PANEL);
 SetColor(C_BLACK);
 DLine(X2-10,Y1+(Y2-Y1) Div 2-1,X2-4,Y1+(Y2-Y1) Div 2-1);
 DLine(X2-9,Y1+(Y2-Y1) Div 2,X2-5,Y1+(Y2-Y1) Div 2);
 DLine(X2-8,Y1+(Y2-Y1) Div 2+1,X2-6,Y1+(Y2-Y1) Div 2+1);
 AddHit(X1,Y1,X2,Y2,A_DROP,P1,0);
End;

Procedure DrawSpin(X, Y: Integer; Const Cap: String; Const Val: String; Field: LongInt; Wd: Integer);
Begin
 If Cap<>'' Then DText(X,Y+3,Cap,C_BLACK);
 X:=X+Length(Cap)*8+2;
 DBar(X,Y,X+Wd,Y+13,C_WHITE);
 DRect(X,Y,X+Wd,Y+13,C_DARK);
 DText(X+3,Y+3,Val,C_BLACK);
 AddHit(X,Y,X+Wd-14,Y+13,A_SPINEDIT,Field,0);
 DBar(X+Wd-13,Y+1,X+Wd-1,Y+6,C_PANEL);
 DBar(X+Wd-13,Y+7,X+Wd-1,Y+12,C_PANEL);
 SetColor(C_BLACK);
 DLine(X+Wd-9,Y+4,X+Wd-5,Y+4); DLine(X+Wd-8,Y+3,X+Wd-6,Y+3);
 DLine(X+Wd-9,Y+8,X+Wd-5,Y+8); DLine(X+Wd-8,Y+9,X+Wd-6,Y+9);
 AddHit(X+Wd-13,Y+1,X+Wd-1,Y+6,A_SPIN,Field,1);
 AddHit(X+Wd-13,Y+7,X+Wd-1,Y+12,A_SPIN,Field,-1);
End;

Procedure HLine(X1, X2, Y: Integer);
Begin
 SetColor(C_BORDER); DLine(X1,Y,X2,Y);
End;

{ ========================================================================== }
{                              BARRE D'OUTILS                                }
{ ========================================================================== }

Function SelStyleStr(Const Key, Def: String): String;
Var I: Integer;
Begin
 I:=FirstSel;
 If I=0 Then SelStyleStr:=Def Else SelStyleStr:=StyStr(Cells[I]^.Style,Key,Def);
End;

Procedure ToolIcon(Id, X, Y: Integer);
Begin
 SetColor(C_BLACK);
 Case Id Of
  1: Begin DRect(X+1,Y+2,X+13,Y+12,C_BLACK); DLine(X+5,Y+2,X+5,Y+12); End;
  2: Begin Circle(X+6,Y+6,4); DLine(X+9,Y+9,X+13,Y+13); DLine(X+4,Y+6,X+8,Y+6); End;
  4: Begin Circle(X+6,Y+6,4); DLine(X+9,Y+9,X+13,Y+13); DLine(X+4,Y+6,X+8,Y+6); DLine(X+6,Y+4,X+6,Y+8); End;
  5: Begin Arc(X+8,Y+8,20,200,5); DLine(X+3,Y+7,X+3,Y+2); DLine(X+3,Y+7,X+8,Y+7); End;
  6: Begin Arc(X+6,Y+8,340,160,5); DLine(X+11,Y+7,X+11,Y+2); DLine(X+11,Y+7,X+6,Y+7); End;
  7: Begin DRect(X+3,Y+4,X+11,Y+13,C_BLACK); DLine(X+2,Y+3,X+12,Y+3); DLine(X+6,Y+1,X+8,Y+1);
          DLine(X+5,Y+6,X+5,Y+11); DLine(X+7,Y+6,X+7,Y+11); DLine(X+9,Y+6,X+9,Y+11); End;
  8: Begin DBar(X+1,Y+1,X+8,Y+8,C_BORDER); DRect(X+1,Y+1,X+8,Y+8,C_BLACK);
          DBar(X+5,Y+5,X+13,Y+13,C_WHITE); DRect(X+5,Y+5,X+13,Y+13,C_BLACK); End;
  9: Begin DBar(X+5,Y+5,X+13,Y+13,C_BORDER); DRect(X+5,Y+5,X+13,Y+13,C_BLACK);
          DBar(X+1,Y+1,X+8,Y+8,C_WHITE); DRect(X+1,Y+1,X+8,Y+8,C_BLACK); End;
  10: Begin
       DLine(X+2,Y+7,X+7,Y+2); DLine(X+7,Y+2,X+12,Y+7); DLine(X+12,Y+7,X+7,Y+12); DLine(X+7,Y+12,X+2,Y+7);
       DLine(X+12,Y+8,X+14,Y+11);
      End;
  11: Begin DLine(X+3,Y+11,X+11,Y+3); DLine(X+4,Y+12,X+12,Y+4); DLine(X+3,Y+11,X+2,Y+13); End;
  12: Begin DBar(X+4,Y+4,X+13,Y+13,C_BORDER); DBar(X+2,Y+2,X+10,Y+10,C_WHITE); DRect(X+2,Y+2,X+10,Y+10,C_BLACK); End;
  13: Begin DLine(X+1,Y+12,X+12,Y+3); DLine(X+12,Y+3,X+8,Y+3); DLine(X+12,Y+3,X+12,Y+7); End;
  14: Begin DLine(X+1,Y+11,X+5,Y+11); DLine(X+5,Y+11,X+5,Y+4); DLine(X+5,Y+4,X+13,Y+4);
          DRect(X+4,Y+10,X+6,Y+12,C_BLACK); End;
  15: Begin DLine(X+7,Y+2,X+7,Y+12); DLine(X+2,Y+7,X+12,Y+7); DLine(X+6,Y+2,X+6,Y+12); DLine(X+2,Y+6,X+12,Y+6); End;
 End;
End;

Procedure DrawToolbar;
Var X: Integer; Z: String; Rgb: LongInt;
 Procedure Btn(Idn: Integer; Wd: Integer);
 Begin
  DBar(X,TOOL_Y+3,X+Wd,TOOL_Y+TOOL_H-4,C_PANEL);
  ToolIcon(Idn,X+(Wd-14) Div 2,TOOL_Y+5);
  AddHit(X,TOOL_Y+2,X+Wd,TOOL_Y+TOOL_H-3,A_TOOL,Idn,0);
  X:=X+Wd+2;
 End;
 Procedure Sep;
 Begin
  SetColor(C_BORDER); DLine(X+1,TOOL_Y+4,X+1,TOOL_Y+TOOL_H-5);
  X:=X+5;
 End;
Begin
 DBar(0,TOOL_Y,SCR_W-1,TOOL_Y+TOOL_H-1,C_PANEL);
 SetColor(C_BORDER); DLine(0,TOOL_Y+TOOL_H-1,SCR_W-1,TOOL_Y+TOOL_H-1);
 X:=4;
 Btn(1,22); Sep;
 { Zoom }
 Z:=IStr(Zoom)+'%';
 DBar(X,TOOL_Y+3,X+46,TOOL_Y+TOOL_H-4,C_WHITE);
 DRect(X,TOOL_Y+3,X+46,TOOL_Y+TOOL_H-4,C_BORDER);
 DText(X+4,TOOL_Y+9,Z,C_BLACK);
 DTextRaw(X+36,TOOL_Y+9,#31,C_DARK);
 AddHit(X,TOOL_Y+2,X+46,TOOL_Y+TOOL_H-3,A_TOOL,3,0);
 X:=X+50; Sep;
 Btn(4,22); Btn(2,22); Sep;
 Btn(5,22); Btn(6,22); Sep;
 Btn(7,22); Sep;
 Btn(8,22); Btn(9,22); Sep;
 { Couleurs (barre de couleur sous l'icone) }
 Btn(10,22);
 Rgb:=$FFFFFF; If FirstSel>0 Then Rgb:=CellFill(FirstSel);
 If Rgb>=0 Then DBar(X-22,TOOL_Y+TOOL_H-6,X-3,TOOL_Y+TOOL_H-4,PalOf(Rgb));
 Btn(11,22);
 Rgb:=$000000; If FirstSel>0 Then Rgb:=CellStroke(FirstSel);
 If Rgb>=0 Then DBar(X-22,TOOL_Y+TOOL_H-6,X-3,TOOL_Y+TOOL_H-4,PalOf(Rgb));
 Btn(12,22); Sep;
 Btn(13,22); Btn(14,22); Sep;
 Btn(15,22);
 { Boutons Save / Exit a droite }
 DBar(SCR_W-132,TOOL_Y+3,SCR_W-72,TOOL_Y+TOOL_H-4,C_ACCENT);
 TextC(SCR_W-132,SCR_W-72,TOOL_Y+9,Tr('Save'),C_WHITE);
 AddHit(SCR_W-132,TOOL_Y+3,SCR_W-72,TOOL_Y+TOOL_H-4,A_TOOL,20,0);
 TextC(SCR_W-68,SCR_W-6,TOOL_Y+9,Tr('Exit'),C_BLACK);
 AddHit(SCR_W-68,TOOL_Y+3,SCR_W-6,TOOL_Y+TOOL_H-4,A_TOOL,21,0);
End;

{ ========================================================================== }
{                         PANNEAU DES FORMES (GAUCHE)                        }
{ ========================================================================== }

Function MatchDef(D: Integer): Boolean;
Begin
 If SearchText='' Then MatchDef:=True
 Else MatchDef:=(Pos(UpStr(SearchText),UpStr(ShapeDefs[D].Name))>0) Or
                 (Pos(UpStr(SearchText),UpStr(Tr(ShapeDefs[D].Name)))>0);
End;

Function CellShapeOfDef(D: Integer): Byte;
Begin
 If StyKeyless(ShapeDefs[D].Sty)='text' Then CellShapeOfDef:=SH_TEXT Else CellShapeOfDef:=SH_RECT;
End;

Procedure DrawLeftPanel;
Var S, D, Col, Row, X, Y, Bottom, Top: Integer;
Begin
 If LeftW=0 Then Exit;
 DBar(0,PANEL_Y,LeftW-1,CY2+TAB_H+1,C_PANEL);
 SetColor(C_BORDER); DLine(LeftW-1,PANEL_Y,LeftW-1,CY2+TAB_H+1);
 { Zone de recherche }
 DBar(4,PANEL_Y+4,LeftW-8,PANEL_Y+19,C_WHITE);
 If SearchFocus Then DRect(4,PANEL_Y+4,LeftW-8,PANEL_Y+19,C_ACCENT) Else DRect(4,PANEL_Y+4,LeftW-8,PANEL_Y+19,C_BORDER);
 If SearchText='' Then DText(8,PANEL_Y+9,Tr('Search Shapes'),C_BORDER)
 Else DText(8,PANEL_Y+9,Copy(SearchText,1,12)+Chr(95),C_BLACK);
 AddHit(4,PANEL_Y+4,LeftW-8,PANEL_Y+19,A_SEARCH,0,0);
 Top:=PANEL_Y+24;
 Bottom:=CY2+TAB_H-2;
 Y:=Top-PalScroll;
 If SearchText<>'' Then Begin
  Col:=0; Row:=0;
  For D:=0 To NDEFS-1 Do Begin
   If Not MatchDef(D) Then Continue;
   X:=4+Col*27;
   If (Y+Row*24>=Top) And (Y+Row*24+23<=Bottom) Then Begin
    DBar(X,Y+Row*24,X+25,Y+Row*24+22,C_WHITE);
    DRect(X,Y+Row*24,X+25,Y+Row*24+22,C_BORDER);
    DrawThumbReal(D,X+1,Y+Row*24+1,24,21);
    AddHit(X,Y+Row*24,X+25,Y+Row*24+22,A_PALITEM,D,0);
   End;
   Inc(Col);
   If Col>=4 Then Begin Col:=0; Inc(Row); End;
  End;
  If Col>0 Then Inc(Row);
  PalTotal:=Row*24;
  Exit;
 End;
 For S:=0 To NSEC-1 Do Begin
  If (Y>=Top) And (Y+15<=Bottom) Then Begin
   DBar(0,Y,LeftW-2,Y+15,C_PANEL);
   If PalOpen[S] Then DTextRaw(4,Y+4,#31,C_DARK) Else DTextRaw(4,Y+4,#16,C_DARK);
   DText(16,Y+4,Tr(SecNames[S]),C_BLACK);
   SetColor(C_BORDER); DLine(0,Y+15,LeftW-2,Y+15);
   AddHit(0,Y,LeftW-2,Y+15,A_PALHEAD,S,0);
  End;
  Y:=Y+16;
  If PalOpen[S] Then Begin
   Col:=0; Row:=0;
   For D:=0 To NDEFS-1 Do Begin
    If ShapeDefs[D].Sec<>S Then Continue;
    X:=4+Col*27;
    If (Y+Row*24>=Top) And (Y+Row*24+23<=Bottom) Then Begin
     DBar(X,Y+Row*24,X+25,Y+Row*24+22,C_WHITE);
     DRect(X,Y+Row*24,X+25,Y+Row*24+22,C_BORDER);
     If CellShapeOfDef(D)=SH_TEXT Then TextC(X,X+25,Y+Row*24+8,'Abc',C_BLACK)
     Else DrawThumbReal(D,X+1,Y+Row*24+1,24,21);
     AddHit(X,Y+Row*24,X+25,Y+Row*24+22,A_PALITEM,D,0);
    End;
    Inc(Col);
    If Col>=4 Then Begin Col:=0; Inc(Row); End;
   End;
   If Col>0 Then Inc(Row);
   Y:=Y+Row*24+4;
  End;
 End;
 PalTotal:=Y+PalScroll-Top;
 { Boutons de defilement }
 If PalTotal>Bottom-Top Then Begin
  DBar(LeftW-16,Bottom-26,LeftW-3,Bottom-14,C_PANEL); DRect(LeftW-16,Bottom-26,LeftW-3,Bottom-14,C_DARK);
  DTextRaw(LeftW-13,Bottom-23,#30,C_BLACK);
  AddHit(LeftW-16,Bottom-26,LeftW-3,Bottom-14,A_PALSCROLL,-1,0);
  DBar(LeftW-16,Bottom-12,LeftW-3,Bottom,C_PANEL); DRect(LeftW-16,Bottom-12,LeftW-3,Bottom,C_DARK);
  DTextRaw(LeftW-13,Bottom-10,#31,C_BLACK);
  AddHit(LeftW-16,Bottom-12,LeftW-3,Bottom,A_PALSCROLL,1,0);
 End;
End;

{ ========================================================================== }
{                       PANNEAU DE FORMAT (DROITE)                           }
{ ========================================================================== }

Const
 { Champs numeriques }
 F_SWIDTH = 1; F_OPACITY = 2; F_FSIZE = 3; F_X = 4; F_Y = 5; F_W = 6; F_H = 7; F_GRIDSZ = 8;
 { Cases a cocher }
 CK_FILL = 1; CK_GRAD = 2; CK_LINE = 3; CK_ROUND = 4; CK_SHADOW = 5; CK_GLASS = 6; CK_COMIC = 7;
 CK_WRAP = 8; CK_GRID = 9; CK_SNAP = 10; CK_BG = 11; CK_BOLD = 20; CK_ITAL = 21; CK_UNDER = 22;
 { Couleurs }
 CO_FILL = 0; CO_STROKE = 1; CO_GRAD = 2; CO_FONT = 3; CO_LBLBG = 4; CO_BG = 5;
 { Listes deroulantes }
 DD_DASH = 1; DD_CONN = 2; DD_START = 3; DD_END = 4;
 { Boutons }
 BT_EDITSTYLE = 1; BT_COPYSTYLE = 2; BT_PASTESTYLE = 3; BT_SETDEFAULT = 4; BT_FRONT = 5; BT_BACK = 6;
 BT_FWD = 7; BT_BWD = 8; BT_GROUP = 9; BT_UNGROUP = 10; BT_RESETVIEW = 11; BT_CLRPTS = 12;
 BT_AL = 30; BT_AC = 31; BT_AR = 32; BT_VT = 33; BT_VM = 34; BT_VB = 35;
 BT_ALIGN0 = 40;

Const TabNames: Array[0..2] Of String[9] = ('Style','Text','Arrange*');

{ Libelle d'onglet (le '*' ne sert qu'a distinguer le menu Arrange) }
Function TabLabel(I: Integer): String;
Var T: String;
Begin
 T:=Tr(TabNames[I]);
 If (T<>'') And (T[Length(T)]='*') Then Delete(T,Length(T),1);
 TabLabel:=T;
End;

Function SelHasEdge: Boolean;
Var I: Integer;
Begin
 SelHasEdge:=False;
 For I:=1 To NCells Do If Cells[I]^.Sel And (Cells[I]^.Kind=K_EDGE) Then SelHasEdge:=True;
End;

Function SelAllEdges: Boolean;
Var I: Integer; Any: Boolean;
Begin
 Any:=False; SelAllEdges:=True;
 For I:=1 To NCells Do
  If Cells[I]^.Sel Then Begin
   Any:=True;
   If Cells[I]^.Kind<>K_EDGE Then SelAllEdges:=False;
  End;
 If Not Any Then SelAllEdges:=False;
End;

Function ConnName(Const Sty: String): String;
Var Es: String;
Begin
 Es:=StyStr(Sty,'edgeStyle','');
 If StyBool(Sty,'curved',False) Then ConnName:=Tr('Curved')
 Else If Pos('orthogonal',Es)>0 Then ConnName:=Tr('Orthogonal')
 Else If Pos('lbow',Es)>0 Then ConnName:=Tr('Elbow')
 Else If Pos('ntityRelation',Es)>0 Then ConnName:=Tr('Entity Relation')
 Else ConnName:=Tr('Straight');
End;

Function DashName(Const Sty: String): String;
Begin
 If StyBool(Sty,'dashed',False) Then Begin
  If Copy(StyStr(Sty,'dashPattern',''),1,2)='1 ' Then DashName:=Tr('Dotted') Else DashName:=Tr('Dashed');
 End Else DashName:=Tr('Solid');
End;


Procedure DrawRightPanel;
Var RX, X1, X2, Y, I, N, Tb: Integer; Sty: String; C: PCell; IsEdge, IsV: Boolean; Rgb: LongInt;
 Fs: Integer; Fst: Integer; Bw: Integer;
 Procedure Sep;
 Begin
  HLine(RX+2,SCR_W-3,Y); Inc(Y,5);
 End;
 Procedure Btn(Const Cap: String; Id: Integer);
 Begin
  DrawButton(RX+8,Y,SCR_W-8,Y+14,Cap,A_BTN,Id,0);
  Inc(Y,17);
 End;
 Procedure Btn2(Const C1: String; I1: Integer; Const C2: String; I2: Integer);
 Begin
  DrawButton(RX+8,Y,RX+RightW Div 2-2,Y+14,C1,A_BTN,I1,0);
  DrawButton(RX+RightW Div 2+1,Y,SCR_W-8,Y+14,C2,A_BTN,I2,0);
  Inc(Y,17);
 End;
 Procedure Tgl(X, Wd: Integer; Const Cap: String; On_: Boolean; Id: Integer);
 Begin
  If On_ Then Begin DBar(X,Y,X+Wd,Y+14,C_BORDER); Bevel(X,Y,X+Wd,Y+14,False,-1); End
  Else Bevel(X,Y,X+Wd,Y+14,True,C_PANEL);
  TextC(X,X+Wd,Y+4,Cap,C_BLACK);
  AddHit(X,Y,X+Wd,Y+14,A_CHECK,Id,0);
 End;
 Procedure ABtn(X, Wd: Integer; Const Cap: String; Id: Integer);
 Begin
  DrawButton(X,Y,X+Wd,Y+14,Cap,A_BTN,Id,0);
 End;
Begin
 If RightW=0 Then Exit;
 RX:=SCR_W-RightW;
 DBar(RX,PANEL_Y,SCR_W-1,CY2+TAB_H+1,C_PANEL);
 SetColor(C_BORDER); DLine(RX,PANEL_Y,RX,CY2+TAB_H+1);
 N:=SelCount;
 SetText(1);
 If N=0 Then Begin
  { Onglet Diagram }
  DBar(RX+1,PANEL_Y,SCR_W-1,PANEL_Y+16,C_WHITE);
  TextC(RX,SCR_W-1,PANEL_Y+5,Tr('Diagram'),C_BLACK);
  SetColor(C_BORDER); DLine(RX+1,PANEL_Y+16,SCR_W-1,PANEL_Y+16);
  Y:=PANEL_Y+24;
  DrawCheck(RX+8,Y,GridOn,Tr('Grid'),CK_GRID,True);
  DrawSpin(RX+RightW-62,Y-3,'',IStr(GridSize)+' pt',F_GRIDSZ,54);
  Inc(Y,20);
  DrawCheck(RX+8,Y,SnapOn,Tr('Snap to grid'),CK_SNAP,True);
  Inc(Y,20);
  DrawCheck(RX+8,Y,BgColor>=0,Tr('Background'),CK_BG,True);
  DrawSwatch(RX+RightW-48,Y-2,RX+RightW-8,Y+11,BgColor,A_COLOR,CO_BG);
  Inc(Y,22); Sep;
  Btn(Tr('Reset View'),BT_RESETVIEW);
  Inc(Y,6); Sep;
  DText(RX+8,Y,Tr('Page: ')+Copy(PageName,1,12),C_DARK); Inc(Y,14);
  DText(RX+8,Y,Tr('Objects: ')+IStr(NCells),C_DARK); Inc(Y,14);
  DText(RX+8,Y,Tr('Zoom: ')+IStr(Zoom)+'%',C_DARK);
  Exit;
 End;
 { Onglets }
 X1:=RX+1;
 For I:=0 To 2 Do Begin
  Case I Of 0: Tb:=50; 1: Tb:=42; Else Tb:=RightW-1-92; End;
  X2:=X1+Tb-1;
  If I=FmtTab Then Begin
   DBar(X1,PANEL_Y,X2,PANEL_Y+16,C_PANEL);
   TextC(X1,X2,PANEL_Y+5,TabLabel(I),C_BLACK);
  End Else Begin
   DBar(X1,PANEL_Y,X2,PANEL_Y+16,C_BORDER);
   TextC(X1,X2,PANEL_Y+5,TabLabel(I),C_DARK);
  End;
  SetColor(C_BORDER); DLine(X2,PANEL_Y,X2,PANEL_Y+16);
  AddHit(X1,PANEL_Y,X2,PANEL_Y+16,A_TAB,I,0);
  X1:=X2+1;
 End;
 SetColor(C_BORDER);
 I:=FirstSel; C:=Cells[I]; Sty:=C^.Style;
 IsEdge:=C^.Kind=K_EDGE;
 IsV:=Not IsEdge;
 Y:=PANEL_Y+22;
 If FmtTab=0 Then Begin
  { -------- Onglet Style -------- }
  If IsV Then Begin
   For I:=0 To 7 Do Begin
    X1:=RX+8+(I Mod 4)*35; X2:=X1+30; Bw:=Y+(I Div 4)*20;
    DBar(X1,Bw,X2,Bw+16,PalOf(PresetFill[I]));
    DRect(X1,Bw,X2,Bw+16,PalOf(PresetStroke[I]));
    AddHit(X1,Bw,X2,Bw+16,A_PRESET,I,0);
   End;
   Inc(Y,44); Sep;
   Rgb:=CellFill(FirstSel);
   DrawCheck(RX+8,Y,Rgb>=0,Tr('Fill'),CK_FILL,True);
   DrawSwatch(RX+RightW-48,Y-2,RX+RightW-8,Y+11,Rgb,A_COLOR,CO_FILL);
   Inc(Y,17);
   Rgb:=ParseColor(StyStr(Sty,'gradientColor',''),-1);
   DrawCheck(RX+8,Y,Rgb>=0,Tr('Gradient'),CK_GRAD,True);
   DrawSwatch(RX+RightW-48,Y-2,RX+RightW-8,Y+11,Rgb,A_COLOR,CO_GRAD);
   Inc(Y,18); Sep;
  End;
  Rgb:=CellStroke(FirstSel);
  DrawCheck(RX+8,Y,Rgb>=0,Tr('Line'),CK_LINE,True);
  DrawSwatch(RX+RightW-48,Y-2,RX+RightW-8,Y+11,Rgb,A_COLOR,CO_STROKE);
  Inc(Y,18);
  DrawDrop(RX+8,Y,RX+84,Y+14,DashName(Sty),DD_DASH);
  DrawSpin(RX+88,Y,'',IStr(StyInt(Sty,'strokeWidth',1))+' pt',F_SWIDTH,RightW-98);
  Inc(Y,20);
  If IsEdge Then Begin
   Sep;
   DText(RX+8,Y+3,Tr('Connection'),C_BLACK);
   Inc(Y,15);
   DrawDrop(RX+8,Y,SCR_W-8,Y+14,ConnName(Sty),DD_CONN);
   Inc(Y,20);
   DText(RX+8,Y+3,Tr('Start'),C_BLACK);
   DrawDrop(RX+52,Y,SCR_W-8,Y+14,StyStr(Sty,'startArrow','none'),DD_START);
   Inc(Y,18);
   DText(RX+8,Y+3,Tr('End'),C_BLACK);
   DrawDrop(RX+52,Y,SCR_W-8,Y+14,StyStr(Sty,'endArrow','classic'),DD_END);
   Inc(Y,22);
  End;
  Sep;
  If IsV Then Begin
   DText(RX+8,Y+3,Tr('Opacity'),C_BLACK);
   DrawSpin(RX+RightW-70,Y,'',IStr(StyInt(Sty,'opacity',100))+' %',F_OPACITY,62);
   Inc(Y,20); Sep;
  End;
  DrawCheck(RX+8,Y,StyBool(Sty,'rounded',False),Tr('Rounded'),CK_ROUND,True);
  DrawCheck(RX+RightW Div 2+4,Y,StyBool(Sty,'shadow',False),Tr('Shadow'),CK_SHADOW,True);
  Inc(Y,15);
  If IsV Then Begin
   DrawCheck(RX+8,Y,StyBool(Sty,'glass',False),Tr('Glass'),CK_GLASS,True);
   DrawCheck(RX+RightW Div 2+4,Y,StyBool(Sty,'comic',False),Tr('Comic'),CK_COMIC,True);
   Inc(Y,15);
  End;
  Inc(Y,2); Sep;
  Btn(Tr('Edit Style'),BT_EDITSTYLE);
  Btn(Tr('Copy Style'),BT_COPYSTYLE);
  Btn(Tr('Paste Style'),BT_PASTESTYLE);
  Btn(Tr('Set as Default'),BT_SETDEFAULT);
  If IsEdge And (C^.NPts>0) Then Btn(Tr('Clear Waypoints'),BT_CLRPTS);
 End Else If FmtTab=1 Then Begin
  { -------- Onglet Text -------- }
  Fs:=Integer(StyInt(Sty,'fontSize',12));
  Fst:=Integer(StyInt(Sty,'fontStyle',0));
  DrawSpin(RX+8,Y,Tr('Size '),IStr(Fs)+' pt',F_FSIZE,RightW-24-40);
  Inc(Y,22);
  Tgl(RX+8,28,'B',(Fst And 1)<>0,CK_BOLD);
  Tgl(RX+40,28,'I',(Fst And 2)<>0,CK_ITAL);
  Tgl(RX+72,28,'U',(Fst And 4)<>0,CK_UNDER);
  Inc(Y,22); Sep;
  DText(RX+8,Y+3,Tr('Align'),C_BLACK);
  ABtn(RX+56,26,'L',BT_AL); ABtn(RX+84,26,'C',BT_AC); ABtn(RX+112,26,'R',BT_AR);
  Inc(Y,20);
  DText(RX+8,Y+3,Tr('Vert.'),C_BLACK);
  ABtn(RX+56,26,'T',BT_VT); ABtn(RX+84,26,'M',BT_VM); ABtn(RX+112,26,'B',BT_VB);
  Inc(Y,22); Sep;
  DrawCheck(RX+8,Y,StyStr(Sty,'whiteSpace','')='wrap',Tr('Word wrap'),CK_WRAP,True);
  Inc(Y,20); Sep;
  DText(RX+8,Y+2,Tr('Font color'),C_BLACK);
  DrawSwatch(RX+RightW-48,Y-2,RX+RightW-8,Y+11,CellFontColor(FirstSel),A_COLOR,CO_FONT);
  Inc(Y,20);
  DText(RX+8,Y+2,Tr('Label bg'),C_BLACK);
  DrawSwatch(RX+RightW-48,Y-2,RX+RightW-8,Y+11,ParseColor(StyStr(Sty,'labelBackgroundColor',''),-1),A_COLOR,CO_LBLBG);
  Inc(Y,24);
  Btn(Tr('Edit Label'),BT_EDITSTYLE+100);
 End Else Begin
  { -------- Onglet Arrange -------- }
  If IsV Then Begin
   DText(RX+8,Y,Tr('Position'),C_DARK); Inc(Y,12);
   DrawSpin(RX+8,Y,'X ',IStr(C^.X),F_X,RightW Div 2-34);
   DrawSpin(RX+RightW Div 2+2,Y,'Y ',IStr(C^.Y),F_Y,RightW Div 2-34);
   Inc(Y,20);
   DText(RX+8,Y,Tr('Size'),C_DARK); Inc(Y,12);
   DrawSpin(RX+8,Y,'W ',IStr(C^.W),F_W,RightW Div 2-34);
   DrawSpin(RX+RightW Div 2+2,Y,'H ',IStr(C^.H),F_H,RightW Div 2-34);
   Inc(Y,22); Sep;
  End;
  Btn2(Tr('To Front'),BT_FRONT,Tr('To Back'),BT_BACK);
  Btn2(Tr('Forward'),BT_FWD,Tr('Backward'),BT_BWD);
  Sep;
  Btn2(Tr('Group'),BT_GROUP,Tr('Ungroup'),BT_UNGROUP);
  Sep;
  If N>=2 Then Begin
   DText(RX+8,Y,Tr('Align'),C_DARK); Inc(Y,12);
   ABtn(RX+8,22,'L',BT_ALIGN0); ABtn(RX+34,22,'C',BT_ALIGN0+1); ABtn(RX+60,22,'R',BT_ALIGN0+2);
   ABtn(RX+86,22,'T',BT_ALIGN0+3); ABtn(RX+112,22,'M',BT_ALIGN0+4);
   Inc(Y,18);
   ABtn(RX+8,22,'B',BT_ALIGN0+5); ABtn(RX+34,50,Tr('DistH'),BT_ALIGN0+6); ABtn(RX+88,50,Tr('DistV'),BT_ALIGN0+7);
  End;
 End;
End;

{ ========================================================================== }
{                  ONGLETS DE PAGES, BARRE D'ETAT, REDESSIN                  }
{ ========================================================================== }

Procedure DrawTabs;
Var I, X, W, Y1, Y2: Integer; T: String;
Begin
 Y1:=CY2+2; Y2:=CY2+TAB_H+1;
 DBar(CX1-1,Y1,CX2+1,Y2,C_PANEL);
 SetColor(C_BORDER); DLine(CX1-1,Y1,CX2+1,Y1);
 X:=CX1+2;
 SetText(1);
 For I:=0 To NPages-1 Do Begin
  If I=CurPage Then T:=PageName Else T:=Pages[I].Name;
  T:=Copy(T,1,10);
  W:=Length(T)*8+12;
  If X+W>CX2-18 Then Break;
  If I=CurPage Then Begin
   DBar(X,Y1+1,X+W,Y2,C_WHITE);
   DText(X+6,Y1+4,T,C_BLACK);
  End Else Begin
   DBar(X,Y1+2,X+W,Y2,C_BORDER);
   DText(X+6,Y1+5,T,C_DARK);
  End;
  AddHit(X,Y1+1,X+W,Y2,A_PAGE,I,0);
  X:=X+W+2;
 End;
 DBar(X,Y1+2,X+14,Y2,C_PANEL);
 DText(X+3,Y1+5,'+',C_BLACK);
 AddHit(X,Y1+1,X+14,Y2,A_PAGE,-1,0);
End;

Procedure DrawStatus;
Var T: String; Y1: Integer;
Begin
 Y1:=SCR_H-STAT_H;
 DBar(0,Y1,SCR_W-1,SCR_H-1,C_PANEL);
 SetColor(C_BORDER); DLine(0,Y1,SCR_W-1,Y1);
 SetText(1);
 T:=StatusMsg;
 If T='' Then Begin
  If SelCount=0 Then T:=Fr('Click a shape to insert it. Right button: pan.','Cliquez une forme pour l''insérer')
  Else T:=IStr(SelCount)+Tr(' selected');
 End;
 DText(4,Y1+4,Copy(T,1,58),C_BLACK);
 T:=IStr(Zoom)+'%';
 DText(SCR_W-Length(T)*8-6,Y1+4,T,C_DARK);
End;

Procedure Layout;
Begin
 If ShowLeft Then LeftW:=LEFT_W0 Else LeftW:=0;
 If ShowRight Then RightW:=RIGHT_W0 Else RightW:=0;
 CX1:=LeftW+1; CX2:=SCR_W-RightW-2;
 If LeftW=0 Then CX1:=1;
 If RightW=0 Then CX2:=SCR_W-2;
 CY1:=PANEL_Y+1; CY2:=SCR_H-STAT_H-TAB_H-2;
 OfsX:=CX1; OfsY:=CY1;
End;

Procedure RedrawUI;
Begin
 ResetHits;
 HideMouse;
 DrawMenuBar;
 DrawToolbar;
 DrawLeftPanel;
 DrawRightPanel;
 DrawTabs;
 DrawStatus;
 ShowMouse;
End;

Procedure DrawEditOverlay; Forward;

Procedure RedrawAll;
Begin
 Layout;
 HideMouse;
 DBar(0,0,SCR_W-1,SCR_H-1,C_PANEL);
 RedrawUI;
 DrawCanvas;
 DrawMenuDrop;
 If Editing Then DrawEditOverlay;
 ShowMouse;
End;

{ ========================================================================== }
{                  EVENEMENTS (souris + clavier) ET DIALOGUES                }
{ ========================================================================== }

Const
 DBL_TICKS = 40;

Var
 MultiMode: Boolean;     { Selection multiple "collante" (touche Inser) }

Function ShiftHeld: Boolean;
Begin
 {$IFNDEF FPC}
 ShiftHeld:=(Mem[$0040:$0017] And 3)<>0;
 {$ELSE}
 ShiftHeld:=MultiMode;
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

{ Lecture d'un evenement. Un seul evenement par appel. }
Function PollEvent: Integer;
Var NX, NY, NB: LongInt; T: LongInt;
Begin
 PollEvent:=EV_NONE;
 EvDbl:=False;
 If KeyPressed Then Begin
  EvKey:=ReadKey; EvExt:=False;
  If EvKey=#0 Then Begin EvKey:=ReadKey; EvExt:=True; End;
  PollEvent:=EV_KEY;
  Exit;
 End;
 GetMouseState(NX,NY,NB);
 EvX:=NX; EvY:=NY;
 If (NB And 1)<>(OldMB And 1) Then Begin
  If (NB And 1)<>0 Then Begin
   OldMB:=OldMB Or 1;
   T:=Ticks;
   If (Abs(T-LastClickT)<DBL_TICKS) And (Abs(EvX-LastClickX)<5) And (Abs(EvY-LastClickY)<5) Then Begin
    EvDbl:=True; LastClickT:=-10000;
   End Else Begin
    LastClickT:=T; LastClickX:=EvX; LastClickY:=EvY;
   End;
   PollEvent:=EV_LDOWN;
  End Else Begin
   OldMB:=OldMB And (Not 1);
   PollEvent:=EV_LUP;
  End;
  OldMX:=NX; OldMY:=NY;
  Exit;
 End;
 If (NB And 2)<>(OldMB And 2) Then Begin
  If (NB And 2)<>0 Then Begin OldMB:=OldMB Or 2; PollEvent:=EV_RDOWN; End
  Else Begin OldMB:=OldMB And (Not 2); PollEvent:=EV_RUP; End;
  OldMX:=NX; OldMY:=NY;
  Exit;
 End;
 If (NX<>OldMX) Or (NY<>OldMY) Then Begin
  OldMX:=NX; OldMY:=NY;
  PollEvent:=EV_MOVE;
  Exit;
 End;
 Delay(2);
End;

{ Edition d'une ligne de texte (UTF-8) : retourne True si la touche a ete traitee }
Function LineEditKey(Var S: String; Var P: Integer; MaxLen: Integer): Boolean;
Var U: String; K: Integer;
Begin
 LineEditKey:=True;
 If P>Length(S) Then P:=Length(S);
 If P<0 Then P:=0;
 If EditFresh Then Begin
  EditFresh:=False;
  If (Not EvExt) And ((EvKey=#8) Or (EvKey>=#32)) Then Begin S:=''; P:=0; End;
 End;
 If EvExt Then Begin
  Case EvKey Of
   #75: Begin
    If P>0 Then Begin Dec(P); While (P>0) And ((Ord(S[P+1]) And $C0)=$80) Do Dec(P); End;
   End;
   #77: Begin
    If P<Length(S) Then Begin Inc(P); While (P<Length(S)) And ((Ord(S[P+1]) And $C0)=$80) Do Inc(P); End;
   End;
   #71: P:=0;
   #79: P:=Length(S);
   #83: Begin
    If P<Length(S) Then Begin
     K:=1;
     While (P+K<Length(S)) And ((Ord(S[P+K+1]) And $C0)=$80) Do Inc(K);
     Delete(S,P+1,K);
    End;
   End;
  Else LineEditKey:=False;
  End;
  Exit;
 End;
 Case EvKey Of
  #8: Begin
   If P>0 Then Begin
    K:=1;
    While (P-K>0) And ((Ord(S[P-K+1]) And $C0)=$80) Do Inc(K);
    Delete(S,P-K+1,K); Dec(P,K);
   End;
  End;
  #32..#126,#128..#254: Begin
   If EditRaw Then U:=EvKey Else U:=CPToU8(EvKey);
   If Length(S)+Length(U)<=MaxLen Then Begin Insert(U,S,P+1); Inc(P,Length(U)); End;
  End;
 Else LineEditKey:=False;
 End;
End;

{ Dessine une ligne de saisie avec curseur }
Procedure DrawEditField(X1, Y1, X2, Y2: Integer; Const S: String; P: Integer; Focus: Boolean);
Var T, Pre: String; Off, Cx, Vw: Integer;
Begin
 DBar(X1,Y1,X2,Y2,C_WHITE);
 If Focus Then DRect(X1,Y1,X2,Y2,C_ACCENT) Else DRect(X1,Y1,X2,Y2,C_DARK);
 If EditRaw Then Begin T:=S; Pre:=Copy(S,1,P); End
 Else Begin T:=U8ToCP(S); Pre:=U8ToCP(Copy(S,1,P)); End;
 Vw:=(X2-X1-8) Div 8;
 Off:=0;
 If Length(Pre)>Vw-1 Then Off:=Length(Pre)-(Vw-1);
 DTextRaw(X1+4,Y1+(Y2-Y1) Div 2-3,Copy(T,Off+1,Vw),C_BLACK);
 If Focus Then Begin
  Cx:=X1+4+(Length(Pre)-Off)*8;
  SetColor(C_BLACK); DLine(Cx,Y1+2,Cx,Y2-2);
 End;
End;

Procedure DlgBox(X, Y, W, H: Integer; Const Title: String);
Begin
 HideMouse;
 DBar(X+4,Y+4,X+W+4,Y+H+4,C_DARK);
 DBar(X,Y,X+W,Y+H,C_PANEL);
 Bevel(X,Y,X+W,Y+H,True,-1);
 DBar(X+2,Y+2,X+W-2,Y+16,C_ACCENT);
 DText(X+8,Y+6,Title,C_WHITE);
 ShowMouse;
End;

Function InRect(X, Y, X1, Y1, X2, Y2: Integer): Boolean;
Begin
 InRect:=(X>=X1) And (X<=X2) And (Y>=Y1) And (Y<=Y2);
End;

{ Message avec boutons. Mode : 0 = OK ; 1 = Oui/Non ; 2 = Oui/Non/Annuler.
  Retourne 1 (OK/Oui), 2 (Non), 0 (Annuler) }
Function MessageBox(Const Title, Msg: String; Mode: Integer): Integer;
Var Lines: Array[0..7] Of String[48]; N, I, X, Y, W, H, Res, Ev, L: Integer; Cur, Wd: String; Done: Boolean;
    B1, B2, B3: Integer;
Begin
 N:=0; Cur:='';
 L:=1;
 While L<=Length(Msg)+1 Do Begin
  Wd:='';
  While (L<=Length(Msg)) And (Msg[L]<>' ') And (Msg[L]<>#10) Do Begin Wd:=Wd+Msg[L]; Inc(L); End;
  If (Length(Cur)+1+Length(Wd)>46) And (Cur<>'') Then Begin
   If N<8 Then Begin Lines[N]:=Cur; Inc(N); End; Cur:='';
  End;
  If Cur='' Then Cur:=Wd Else Cur:=Cur+' '+Wd;
  If (L<=Length(Msg)) And (Msg[L]=#10) Then Begin
   If N<8 Then Begin Lines[N]:=Cur; Inc(N); End; Cur:='';
  End;
  Inc(L);
 End;
 If (Cur<>'') And (N<8) Then Begin Lines[N]:=Cur; Inc(N); End;
 W:=400; H:=60+N*12+20;
 X:=(SCR_W-W) Div 2; Y:=(SCR_H-H) Div 2;
 Res:=0; Done:=False;
 B1:=X+W Div 2-40; B2:=0; B3:=0;
 Case Mode Of
  1: Begin B1:=X+W Div 2-86; B2:=X+W Div 2+6; End;
  2: Begin B1:=X+W Div 2-126; B2:=X+W Div 2-40; B3:=X+W Div 2+46; End;
 End;
 Repeat
  DlgBox(X,Y,W,H,Title);
  SetText(1);
  For I:=0 To N-1 Do DText(X+12,Y+26+I*12,Lines[I],C_BLACK);
  Case Mode Of
   0: DrawButton(B1,Y+H-26,B1+80,Y+H-8,Tr('OK'),A_NONE,0,0);
   1: Begin DrawButton(B1,Y+H-26,B1+80,Y+H-8,Tr('Yes'),A_NONE,0,0); DrawButton(B2,Y+H-26,B2+80,Y+H-8,Tr('No'),A_NONE,0,0); End;
   2: Begin DrawButton(B1,Y+H-26,B1+80,Y+H-8,Tr('Yes'),A_NONE,0,0); DrawButton(B2,Y+H-26,B2+80,Y+H-8,Tr('No'),A_NONE,0,0);
        DrawButton(B3,Y+H-26,B3+80,Y+H-8,Tr('Cancel'),A_NONE,0,0); End;
  End;
  Repeat
   Ev:=PollEvent;
   If Ev=EV_KEY Then Begin
    If Not EvExt Then Begin
     If EvKey=#13 Then Begin Res:=1; Done:=True; End
     Else If EvKey=#27 Then Begin If Mode=2 Then Res:=0 Else If Mode=1 Then Res:=2 Else Res:=1; Done:=True; End
     Else If ((UpCase(EvKey)='Y') Or (UpCase(EvKey)='O')) And (Mode>0) Then Begin Res:=1; Done:=True; End
     Else If (UpCase(EvKey)='N') And (Mode>0) Then Begin Res:=2; Done:=True; End;
    End;
   End Else If Ev=EV_LDOWN Then Begin
    If InRect(EvX,EvY,B1,Y+H-26,B1+80,Y+H-8) Then Begin Res:=1; Done:=True; End
    Else If (Mode>0) And InRect(EvX,EvY,B2,Y+H-26,B2+80,Y+H-8) Then Begin Res:=2; Done:=True; End
    Else If (Mode=2) And InRect(EvX,EvY,B3,Y+H-26,B3+80,Y+H-8) Then Begin Res:=0; Done:=True; End;
   End;
  Until Done;
 Until Done;
 MessageBox:=Res;
 RedrawAll;
End;

Procedure ShowMsg(Const Title, Msg: String);
Begin
 MessageBox(Title,Msg,0);
End;

Function Confirm(Const Msg: String): Boolean;
Begin
 Confirm:=MessageBox(Tr('Confirm'),Msg,1)=1;
End;

{ Saisie d'une ligne de texte }
Function InputBox(Const Title, Prompt: String; Var S: String; MaxLen: Integer): Boolean;
Var X, Y, W, H, P, Ev: Integer; T: String; Done, Ok: Boolean;
Begin
 W:=380; H:=90; X:=(SCR_W-W) Div 2; Y:=(SCR_H-H) Div 2;
 T:=S; P:=Length(T); Done:=False; Ok:=False; EditFresh:=True;
 Repeat
  DlgBox(X,Y,W,H,Title);
  SetText(1);
  DText(X+10,Y+24,Prompt,C_BLACK);
  DrawEditField(X+10,Y+38,X+W-10,Y+54,T,P,True);
  DrawButton(X+W-176,Y+H-26,X+W-96,Y+H-8,Tr('OK'),A_NONE,0,0);
  DrawButton(X+W-90,Y+H-26,X+W-10,Y+H-8,Tr('Cancel'),A_NONE,0,0);
  Repeat
   Ev:=PollEvent;
   If Ev=EV_KEY Then Begin
    If (Not EvExt) And (EvKey=#13) Then Begin Ok:=True; Done:=True; End
    Else If (Not EvExt) And (EvKey=#27) Then Begin Done:=True; End
    Else LineEditKey(T,P,MaxLen);
    Break;
   End Else If Ev=EV_LDOWN Then Begin
    If InRect(EvX,EvY,X+W-176,Y+H-26,X+W-96,Y+H-8) Then Begin Ok:=True; Done:=True; End
    Else If InRect(EvX,EvY,X+W-90,Y+H-26,X+W-10,Y+H-8) Then Done:=True;
    Break;
   End;
  Until False;
 Until Done;
 If Ok Then S:=T;
 InputBox:=Ok;
 RedrawAll;
End;

{ Liste deroulante modale. Items separes par '|'. Retourne l'index ou -1. }
Function PopupList(X, Y: Integer; Const Items: String; Cur: Integer): Integer;
Var N, I, W, H, Ev, Sel, K: Integer; Names: Array[0..15] Of String[24]; Cs: String; Done: Boolean;
    Redo: Boolean;
Begin
 N:=0; Cs:='';
 For I:=1 To Length(Items)+1 Do Begin
  If (I>Length(Items)) Or (Items[I]='|') Then Begin
   If N<16 Then Begin Names[N]:=Cs; Inc(N); End;
   Cs:='';
  End Else If Length(Cs)<24 Then Cs:=Cs+Items[I];
 End;
 W:=40;
 For I:=0 To N-1 Do If Length(Names[I])*8+24>W Then W:=Length(Names[I])*8+24;
 H:=N*14+4;
 If X+W>SCR_W-2 Then X:=SCR_W-2-W;
 If Y+H>SCR_H-2 Then Y:=SCR_H-2-H;
 Sel:=Cur; Done:=False; PopupList:=-1;
 Redo:=True;
 Repeat
  If Redo Then Begin
   HideMouse;
   DBar(X+3,Y+3,X+W+3,Y+H+3,C_BORDER);
   DBar(X,Y,X+W,Y+H,C_WHITE); DRect(X,Y,X+W,Y+H,C_DARK);
   SetText(1);
   For I:=0 To N-1 Do Begin
    If I=Sel Then Begin DBar(X+2,Y+2+I*14,X+W-2,Y+2+I*14+13,C_ACCENT); DText(X+10,Y+2+I*14+3,Names[I],C_WHITE); End
    Else DText(X+10,Y+2+I*14+3,Names[I],C_BLACK);
   End;
   ShowMouse;
   Redo:=False;
  End;
  Ev:=PollEvent;
  If Ev=EV_KEY Then Begin
   If EvExt Then Begin
    If EvKey=#72 Then Begin If Sel>0 Then Dec(Sel); Redo:=True; End
    Else If EvKey=#80 Then Begin If Sel<N-1 Then Inc(Sel); Redo:=True; End;
   End Else If EvKey=#13 Then Begin PopupList:=Sel; Done:=True; End
   Else If EvKey=#27 Then Done:=True;
  End Else If Ev=EV_MOVE Then Begin
   If InRect(EvX,EvY,X,Y+2,X+W,Y+H-2) Then Begin
    K:=(EvY-Y-2) Div 14;
    If (K>=0) And (K<N) And (K<>Sel) Then Begin Sel:=K; Redo:=True; End;
   End;
  End Else If Ev=EV_LDOWN Then Begin
   If InRect(EvX,EvY,X,Y,X+W,Y+H) Then Begin
    K:=(EvY-Y-2) Div 14;
    If (K>=0) And (K<N) Then PopupList:=K;
   End;
   Done:=True;
  End;
 Until Done;
 RedrawAll;
End;

{ Selecteur de couleur. Retourne True si valide. Rgb : -1 = aucune. }
Function ColorDialog(Const Title: String; Var Rgb: LongInt): Boolean;
Const Extra: Array[0..11] Of LongInt = ($FF0000,$FF8000,$FFFF00,$00FF00,$00FFFF,$0000FF,$8000FF,$FF00FF,$A52A2A,$808080,$404040,$000000);
Var X, Y, W, H, I, Ev, P: Integer; T: String; Done, Ok: Boolean; V: LongInt; Cx, Cy: Integer;
Begin
 W:=300; H:=190; X:=(SCR_W-W) Div 2; Y:=(SCR_H-H) Div 2;
 If Rgb>=0 Then T:=RGBToHex(Rgb) Else T:='none';
 P:=Length(T); Done:=False; Ok:=False; EditFresh:=True;
 Repeat
  DlgBox(X,Y,W,H,Title);
  SetText(1);
  DText(X+10,Y+24,Tr('Palette colors:'),C_BLACK);
  For I:=0 To 15 Do Begin
   Cx:=X+10+(I Mod 8)*34; Cy:=Y+36+(I Div 8)*24;
   DBar(Cx,Cy,Cx+30,Cy+20,I);
   DRect(Cx,Cy,Cx+30,Cy+20,C_BLACK);
  End;
  DText(X+10,Y+86,Tr('Other colors:'),C_BLACK);
  For I:=0 To 11 Do Begin
   Cx:=X+10+(I Mod 12)*22; Cy:=Y+98;
   DBar(Cx,Cy,Cx+19,Cy+16,PalOf(Extra[I]));
   DRect(Cx,Cy,Cx+19,Cy+16,C_BLACK);
  End;
  DText(X+10,Y+124,Tr('Hex value (#RRGGBB, none):'),C_BLACK);
  DrawEditField(X+10,Y+136,X+130,Y+152,T,P,True);
  If HexToRGB(T,V) Then DBar(X+138,Y+136,X+170,Y+152,PalOf(V)) Else DBar(X+138,Y+136,X+170,Y+152,C_PANEL);
  DRect(X+138,Y+136,X+170,Y+152,C_BLACK);
  DrawButton(X+W-176,Y+H-26,X+W-96,Y+H-8,Tr('OK'),A_NONE,0,0);
  DrawButton(X+W-90,Y+H-26,X+W-10,Y+H-8,Tr('Cancel'),A_NONE,0,0);
  DrawButton(X+10,Y+H-26,X+90,Y+H-8,Tr('None'),A_NONE,0,0);
  Repeat
   Ev:=PollEvent;
   If Ev=EV_KEY Then Begin
    If (Not EvExt) And (EvKey=#13) Then Begin
     If LoStr(T)='none' Then Begin Rgb:=-1; Ok:=True; End
     Else If HexToRGB(T,V) Then Begin Rgb:=V; Ok:=True; End;
     Done:=Ok;
    End Else If (Not EvExt) And (EvKey=#27) Then Done:=True
    Else LineEditKey(T,P,9);
    Break;
   End Else If Ev=EV_LDOWN Then Begin
    For I:=0 To 15 Do Begin
     Cx:=X+10+(I Mod 8)*34; Cy:=Y+36+(I Div 8)*24;
     If InRect(EvX,EvY,Cx,Cy,Cx+30,Cy+20) Then Begin T:=RGBToHex(PalRGB[I]); P:=Length(T); End;
    End;
    For I:=0 To 11 Do Begin
     Cx:=X+10+(I Mod 12)*22; Cy:=Y+98;
     If InRect(EvX,EvY,Cx,Cy,Cx+19,Cy+16) Then Begin T:=RGBToHex(Extra[I]); P:=Length(T); End;
    End;
    If InRect(EvX,EvY,X+10,Y+H-26,X+90,Y+H-8) Then Begin T:='none'; P:=4; End;
    If InRect(EvX,EvY,X+W-176,Y+H-26,X+W-96,Y+H-8) Then Begin
     If LoStr(T)='none' Then Begin Rgb:=-1; Ok:=True; End
     Else If HexToRGB(T,V) Then Begin Rgb:=V; Ok:=True; End;
     Done:=Ok;
    End;
    If InRect(EvX,EvY,X+W-90,Y+H-26,X+W-10,Y+H-8) Then Done:=True;
    Break;
   End;
  Until False;
 Until Done;
 ColorDialog:=Ok;
 RedrawAll;
End;

{ ------------------------------------------------------------------------- }
{ Dialogue de fichiers                                                        }
{ ------------------------------------------------------------------------- }

Type
 TNameList = Array[0..299] Of String[44];
 PNameList = ^TNameList;

Function ExtOf(Const N: String): String;
Var I: Integer;
Begin
 ExtOf:='';
 For I:=Length(N) DownTo 1 Do Begin
  If N[I]='.' Then Begin ExtOf:=LoStr(Copy(N,I,10)); Exit; End;
  If (N[I]='\') Or (N[I]='/') Then Exit;
 End;
End;

Function ExtMatch(Const N, Exts: String): Boolean;
Var E: String;
Begin
 If Exts='*' Then Begin ExtMatch:=True; Exit; End;
 E:=ExtOf(N);
 ExtMatch:=(E<>'') And (Pos(E+';',Exts+';')>0);
End;

Function FileDialog(Const Title: String; Var Name: String; Saving: Boolean; Const Exts: String;
                    DefExt: String): Boolean;
Var Lst: PNameList; N, Top, Sel, X, Y, W, H, Rows, I, J, P, Ev, K: Integer; SR: SearchRec; Path, T: String;
    Done, Ok, Redo, All: Boolean; IsDir: Array[0..299] Of Boolean; LastSel: Integer; LastT: LongInt; Tk: LongInt;
 Procedure Scan;
 Var Tn: String[44]; Td: Boolean; A, B: Integer;
 Begin
  N:=0;
  GetDir(0,Path);
  FindFirst('*.*',AnyFile,SR);
  While (DosError=0) And (N<298) Do Begin
   If (SR.Attr And Directory)<>0 Then Begin
    If SR.Name<>'.' Then Begin Lst^[N]:=SR.Name; IsDir[N]:=True; Inc(N); End;
   End Else If All Or ExtMatch(SR.Name,Exts) Then Begin
    Lst^[N]:=SR.Name; IsDir[N]:=False; Inc(N);
   End;
   FindNext(SR);
  End;
  { Tri : dossiers d'abord, puis alphabetique }
  For A:=1 To N-1 Do Begin
   Tn:=Lst^[A]; Td:=IsDir[A]; B:=A-1;
   While (B>=0) And ((Td And Not IsDir[B]) Or ((Td=IsDir[B]) And (UpStr(Lst^[B])>UpStr(Tn)))) Do Begin
    Lst^[B+1]:=Lst^[B]; IsDir[B+1]:=IsDir[B]; Dec(B);
   End;
   Lst^[B+1]:=Tn; IsDir[B+1]:=Td;
  End;
  Top:=0; Sel:=-1;
 End;
Begin
 FileDialog:=False;
 If HeapFree<SizeOf(TNameList)+1024 Then Exit;
 New(Lst);
 W:=420; H:=300; X:=(SCR_W-W) Div 2; Y:=(SCR_H-H) Div 2; Rows:=12;
 T:=Name; P:=Length(T); Done:=False; Ok:=False; All:=False; LastSel:=-2; LastT:=0; EditFresh:=True; EditRaw:=True;
 Scan;
 Redo:=True;
 Repeat
  If Redo Then Begin
   DlgBox(X,Y,W,H,Title);
   SetText(1);
   DTextRaw(X+10,Y+22,Copy(Path,1,48),C_DARK);
   DBar(X+10,Y+36,X+W-26,Y+36+Rows*14+2,C_WHITE);
   DRect(X+10,Y+36,X+W-26,Y+36+Rows*14+2,C_DARK);
   For I:=0 To Rows-1 Do Begin
    J:=Top+I;
    If J>=N Then Break;
    If J=Sel Then DBar(X+11,Y+37+I*14,X+W-27,Y+37+I*14+13,C_ACCENT);
    If J=Sel Then K:=C_WHITE Else K:=C_BLACK;
    If IsDir[J] Then DTextRaw(X+14,Y+40+I*14,'['+Lst^[J]+']',K) Else DTextRaw(X+14,Y+40+I*14,Lst^[J],K);
   End;
   { Barre de defilement }
   DBar(X+W-24,Y+36,X+W-10,Y+36+Rows*14+2,C_PANEL);
   DrawButton(X+W-24,Y+36,X+W-10,Y+50,#30,A_NONE,0,0);
   DrawButton(X+W-24,Y+36+Rows*14-12,X+W-10,Y+36+Rows*14+2,#31,A_NONE,0,0);
   DText(X+10,Y+Rows*14+44,Tr('File name:'),C_BLACK);
   DrawEditField(X+90,Y+Rows*14+40,X+W-10,Y+Rows*14+56,T,P,True);
   DrawButton(X+10,Y+H-26,X+90,Y+H-8,Tr('All files'),A_NONE,0,0);
   If All Then DTextRaw(X+96,Y+H-21,#251,C_BLACK);
   DrawButton(X+W-176,Y+H-26,X+W-96,Y+H-8,Tr('OK'),A_NONE,0,0);
   DrawButton(X+W-90,Y+H-26,X+W-10,Y+H-8,Tr('Cancel'),A_NONE,0,0);
   Redo:=False;
  End;
  Ev:=PollEvent;
  If Ev=EV_KEY Then Begin
   If EvExt And (EvKey=#72) Then Begin If Sel>0 Then Dec(Sel) Else If Sel<0 Then Sel:=0; Redo:=True; End
   Else If EvExt And (EvKey=#80) Then Begin If Sel<N-1 Then Inc(Sel); Redo:=True; End
   Else If EvExt And (EvKey=#73) Then Begin Sel:=Max(0,Sel-Rows); Redo:=True; End
   Else If EvExt And (EvKey=#81) Then Begin Sel:=Min(N-1,Sel+Rows); Redo:=True; End
   Else If (Not EvExt) And (EvKey=#27) Then Done:=True
   Else If (Not EvExt) And (EvKey=#13) Then Begin
    If (Sel>=0) And (T='') Then Begin T:=Lst^[Sel]; P:=Length(T); End;
    If (Sel>=0) And IsDir[Sel] And ((T='') Or (T=Lst^[Sel])) Then Begin
     {$I-} ChDir(Lst^[Sel]); {$I+} If IOResult<>0 Then ;
     Scan; T:=''; P:=0;
    End Else If T<>'' Then Begin
     { Dossier tape ? }
     {$I-} ChDir(T); {$I+}
     If IOResult=0 Then Begin Scan; T:=''; P:=0; End
     Else Begin
      If (Pos('.',T)=0) And (DefExt<>'') Then T:=T+DefExt;
      Name:=T; Ok:=True; Done:=True;
     End;
    End;
    Redo:=True;
   End Else Begin
    LineEditKey(T,P,60);
    Sel:=-1;
    Redo:=True;
   End;
   If Sel>=0 Then Begin
    If Sel<Top Then Top:=Sel;
    If Sel>=Top+Rows Then Top:=Sel-Rows+1;
   End;
  End Else If Ev=EV_LDOWN Then Begin
   Redo:=True;
   If InRect(EvX,EvY,X+10,Y+37,X+W-26,Y+36+Rows*14) Then Begin
    J:=Top+(EvY-Y-37) Div 14;
    If (J>=0) And (J<N) Then Begin
     Tk:=Ticks;
     If (J=LastSel) And (Abs(Tk-LastT)<50) Then Begin
      If IsDir[J] Then Begin
       {$I-} ChDir(Lst^[J]); {$I+} If IOResult<>0 Then ;
       Scan; T:=''; P:=0;
      End Else Begin Name:=Lst^[J]; Ok:=True; Done:=True; End;
     End Else Begin
      Sel:=J;
      If Not IsDir[J] Then Begin T:=Lst^[J]; P:=Length(T); End;
     End;
     LastSel:=J; LastT:=Tk;
    End;
   End
   Else If InRect(EvX,EvY,X+W-24,Y+36,X+W-10,Y+50) Then Begin If Top>0 Then Dec(Top,3); If Top<0 Then Top:=0; End
   Else If InRect(EvX,EvY,X+W-24,Y+36+Rows*14-12,X+W-10,Y+36+Rows*14+2) Then Begin If Top<N-Rows Then Inc(Top,3); End
   Else If InRect(EvX,EvY,X+10,Y+H-26,X+90,Y+H-8) Then Begin All:=Not All; Scan; End
   Else If InRect(EvX,EvY,X+W-176,Y+H-26,X+W-96,Y+H-8) Then Begin
    If T<>'' Then Begin
     If (Pos('.',T)=0) And (DefExt<>'') Then T:=T+DefExt;
     Name:=T; Ok:=True; Done:=True;
    End;
   End
   Else If InRect(EvX,EvY,X+W-90,Y+H-26,X+W-10,Y+H-8) Then Done:=True;
  End;
 Until Done;
 Dispose(Lst);
 EditRaw:=False;
 FileDialog:=Ok;
 RedrawAll;
End;

{ ------------------------------------------------------------------------- }

Procedure ShowKeys;
Begin
 If LangFr Then Begin
  ShowMsg('Raccourcis clavier (1/2)',
   'Ctrl+N/O/S  nouveau / ouvrir / enreg.'#10'Ctrl+Z / Ctrl+Y  annuler / rétablir'#10+
   'Ctrl+X/C/V  couper / copier / coller'#10'Ctrl+D  dupliquer   Ctrl+A  tout sélect.'#10+
   'Suppr  supprimer    Tab  forme suivante'#10'Entrée / F2 / double-clic  modifier texte');
  ShowMsg('Raccourcis clavier (2/2)',
   'Flèches  déplacer (Maj : pas de grille)'#10'+ / -  zoom   Début  100 %   Fin  ajuster'#10+
   'Ctrl+G / Ctrl+U  grouper / dégrouper'#10'Ctrl+F / Ctrl+B  avant / arrière-plan'#10+
   'Ctrl+E  style   F8  aimanter   F9  grille'#10'Bouton droit + glisser  déplacer la vue'#10+
   'Inser  sélection multiple (sans Maj)');
 End Else Begin
  ShowMsg('Keyboard shortcuts (1/2)',
   'Ctrl+N/O/S  new / open / save'#10'Ctrl+Z / Ctrl+Y  undo / redo'#10+
   'Ctrl+X/C/V  cut / copy / paste'#10'Ctrl+D  duplicate    Ctrl+A  select all'#10+
   'Del  delete    Tab  next shape'#10'Enter / F2 / double-click  edit label');
  ShowMsg('Keyboard shortcuts (2/2)',
   'Arrows  move (Shift: grid step)'#10'+ / -  zoom    Home  100%    End  fit'#10+
   'Ctrl+G / Ctrl+U  group / ungroup'#10'Ctrl+F / Ctrl+B  to front / back'#10+
   'Ctrl+E  edit style    F8 snap    F9 grid'#10'Right button drag  pan'#10+
   'Ins  multi-select mode (no Shift key)');
 End;
End;

Procedure ShowAbout;
Begin
 ShowMsg(Tr('About DRAWIO'),
  Fr('DRAWIO - clone of draw.io (diagrams.net)','DRAWIO - clone de draw.io (diagrams.net)')+#10+
  'Turbo Pascal 7 / Free Pascal'#10+
  Fr('Reads and writes .drawio files (plain and compressed XML),'#10'exports SVG.',
     'Lit et écrit les fichiers .drawio (XML clair et compressé),'#10'exporte en SVG.')+#10+
  'CloneDRAW - https://www.gladir.com/clonedraw');
End;

{ ========================================================================== }
{                    OPERATIONS SUR LE DIAGRAMME                             }
{ ========================================================================== }

Var
 EditCell: Integer;
 EditText: String;
 EditPos: Integer;
 InsertCount: Integer;
 PasteCount: Integer;

Function SnapV(V: LongInt): LongInt;
Var G: LongInt;
Begin
 If Not SnapOn Then Begin SnapV:=V; Exit; End;
 G:=GridSize;
 If V>=0 Then SnapV:=((V+G Div 2) Div G)*G Else SnapV:=-(((-V+G Div 2) Div G)*G);
End;

Procedure Touch;
Begin
 Modified:=True;
 StatusMsg:='';
End;

Procedure SelectOnly(I: Integer);
Begin
 ClearSel;
 If I>0 Then Cells[I]^.Sel:=True;
End;

Function IsContainer(J: Integer): Boolean;
Begin
 IsContainer:=False;
 If Cells[J]^.Kind<>K_VERTEX Then Exit;
 IsContainer:=(CellShape(J)=SH_SWIMLANE) Or StyBool(Cells[J]^.Style,'container',False);
End;

Function IsGroup(J: Integer): Boolean;
Begin
 IsGroup:=(Cells[J]^.Kind=K_VERTEX) And (StyKeyless(Cells[J]^.Style)='group');
End;

{ ------------------------------------------------------------------------- }
{ Recherche d'objets sous un point (coordonnees document)                    }
{ ------------------------------------------------------------------------- }

Function HitCellAt(X, Y: LongInt; OnlyVertex: Boolean): Integer;
Var I: Integer; C: PCell; Tol: LongInt; Sh: Byte; Inside, Near, Hd: Boolean; Pl: TPoly; Sd, Td: Integer; Sz: LongInt;
Begin
 HitCellAt:=0;
 Tol:=Max(3,400 Div Zoom);
 For I:=NCells DownTo 1 Do Begin
  C:=Cells[I];
  If (C^.Kind=K_LAYER) Or (Not Visible(I)) Or IsEdgeLabel(I) Then Continue;
  If C^.Kind=K_EDGE Then Begin
   If OnlyVertex Then Continue;
   EdgePath(I,Pl,Sd,Td);
   If PathDist(Pl,X,Y)<=Tol+1 Then Begin HitCellAt:=I; Exit; End;
  End Else Begin
   If (X<C^.X-Tol) Or (X>C^.X+C^.W+Tol) Or (Y<C^.Y-Tol) Or (Y>C^.Y+C^.H+Tol) Then Continue;
   Sh:=CellShape(I);
   Inside:=(X>=C^.X) And (X<=C^.X+C^.W) And (Y>=C^.Y) And (Y<=C^.Y+C^.H);
   Near:=Inside And ((X<C^.X+Tol) Or (X>C^.X+C^.W-Tol) Or (Y<C^.Y+Tol) Or (Y>C^.Y+C^.H-Tol));
   If Not Inside Then Begin
    { Marge de tolerance autour du bord }
    Near:=True;
   End;
   If IsGroup(I) Then Begin
    If Near And Not OnlyVertex Then Begin HitCellAt:=I; Exit; End;
    Continue;
   End;
   Hd:=False;
   If Sh=SH_SWIMLANE Then Begin
    Sz:=StyInt(C^.Style,'startSize',23);
    If StyBool(C^.Style,'horizontal',True) Then Hd:=Inside And (Y<=C^.Y+Sz) Else Hd:=Inside And (X<=C^.X+Sz);
    If Hd Or Near Or (ParseColor(StyStr(C^.Style,'swimlaneFillColor',''),-1)>=0) Then Begin HitCellAt:=I; Exit; End;
   End Else If (Sh=SH_TEXT) Or (CellFill(I)>=0) Or (Sh=SH_ACTOR) Or (Sh=SH_LINE) Then Begin
    If Inside Or Near Then Begin HitCellAt:=I; Exit; End;
   End Else If Near Then Begin HitCellAt:=I; Exit; End;
  End;
 End;
End;

{ Si la cellule I appartient a un groupe non selectionne, retourne le groupe }
Function GroupTarget(I: Integer): Integer;
Var J, Best, D: Integer;
Begin
 Best:=I; J:=Cells[I]^.ParIdx; D:=0;
 While (J>0) And (D<12) Do Begin
  If IsGroup(J) And Not Cells[J]^.Sel Then Best:=J;
  J:=Cells[J]^.ParIdx; Inc(D);
 End;
 GroupTarget:=Best;
End;

{ ------------------------------------------------------------------------- }
{ Deplacement, suppression, presse-papiers                                   }
{ ------------------------------------------------------------------------- }

Procedure MoveSelected(Dx, Dy: LongInt);
Var Mv: Array[1..MAX_CELLS] Of Boolean; I, K: Integer; C: PCell;
Begin
 For I:=1 To NCells Do Mv[I]:=Cells[I]^.Sel Or ((Cells[I]^.ParIdx>0) And False);
 For I:=1 To NCells Do
  If Not Mv[I] Then
   For K:=1 To NCells Do If Cells[K]^.Sel And IsDescendant(I,K) Then Mv[I]:=True;
 For I:=1 To NCells Do Begin
  C:=Cells[I];
  If C^.Kind=K_VERTEX Then Begin
   If Mv[I] And Not C^.Rel Then Begin Inc(C^.X,Dx); Inc(C^.Y,Dy); End;
  End Else If C^.Kind=K_EDGE Then Begin
   If Mv[I] Or ((C^.SrcIdx>0) And (C^.TgtIdx>0) And Mv[C^.SrcIdx] And Mv[C^.TgtIdx]) Then Begin
    For K:=0 To C^.NPts-1 Do Begin Inc(C^.Pts[K].X,Dx); Inc(C^.Pts[K].Y,Dy); End;
   End;
   If Mv[I] Then Begin
    If C^.SrcIdx=0 Then Begin Inc(C^.SrcPt.X,Dx); Inc(C^.SrcPt.Y,Dy); End;
    If C^.TgtIdx=0 Then Begin Inc(C^.TgtPt.X,Dx); Inc(C^.TgtPt.Y,Dy); End;
   End;
  End;
 End;
End;

Procedure Reparent(I: Integer);
Var J, Best: Integer; Cx, Cy: LongInt; C: PCell;
Begin
 C:=Cells[I];
 If C^.Kind<>K_VERTEX Then Exit;
 If IsGroup(I) Then Exit;
 Cx:=C^.X+C^.W Div 2; Cy:=C^.Y+C^.H Div 2;
 Best:=0;
 For J:=NCells DownTo 1 Do Begin
  If (J=I) Or (Not IsContainer(J)) Or IsDescendant(J,I) Then Continue;
  If (Cx>=Cells[J]^.X) And (Cx<=Cells[J]^.X+Cells[J]^.W) And
     (Cy>=Cells[J]^.Y) And (Cy<=Cells[J]^.Y+Cells[J]^.H) Then Begin Best:=J; Break; End;
 End;
 If Best>0 Then Begin
  If C^.ParIdx<>Best Then C^.Parent:=Cells[Best]^.Id;
 End Else If (C^.ParIdx>0) And IsContainer(C^.ParIdx) Then C^.Parent:='1';
End;

Procedure MoveToEnd(I: Integer);
Var P: PCell; J: Integer;
Begin
 P:=Cells[I];
 For J:=I To NCells-1 Do Cells[J]:=Cells[J+1];
 Cells[NCells]:=P;
End;

Procedure MoveToStart(I: Integer);
Var P: PCell; J: Integer;
Begin
 P:=Cells[I];
 For J:=I DownTo 2 Do Cells[J]:=Cells[J-1];
 Cells[1]:=P;
End;

Procedure ReparentSelection;
Var I: Integer;
Begin
 For I:=1 To NCells Do
  If Cells[I]^.Sel And (Cells[I]^.Kind=K_VERTEX) Then
   If (Cells[I]^.ParIdx=0) Or Not Cells[Cells[I]^.ParIdx]^.Sel Then Reparent(I);
 ResolveLinks;
 { Un enfant doit etre dessine apres son conteneur }
 For I:=1 To NCells Do
  If Cells[I]^.ParIdx>I Then Begin MoveToEnd(I); ResolveLinks; End;
End;

Procedure DeleteSelected;
Var Del: Array[1..MAX_CELLS] Of Boolean; I, K: Integer; Any: Boolean;
Begin
 Any:=False;
 For I:=1 To NCells Do Begin
  Del[I]:=Cells[I]^.Sel;
  If Del[I] Then Any:=True;
 End;
 If Not Any Then Exit;
 For I:=1 To NCells Do
  If Not Del[I] Then
   For K:=1 To NCells Do If Cells[K]^.Sel And IsDescendant(I,K) Then Del[I]:=True;
 For I:=1 To NCells Do
  If (Cells[I]^.Kind=K_EDGE) And (Not Del[I]) Then
   If ((Cells[I]^.SrcIdx>0) And Del[Cells[I]^.SrcIdx]) Or ((Cells[I]^.TgtIdx>0) And Del[Cells[I]^.TgtIdx]) Then Del[I]:=True;
 UndoPush;
 For I:=NCells DownTo 1 Do If Del[I] Then FreeCellAt(I);
 ResolveLinks;
 Touch;
End;

Procedure CopySelection;
Var Inc_: Array[1..MAX_CELLS] Of Boolean; I, K, N, Sd, Td: Integer; F: File; H: TDocSet; C: TCell; Pl: TPoly;
Begin
 N:=0;
 For I:=1 To NCells Do Inc_[I]:=Cells[I]^.Sel And (Cells[I]^.Kind<>K_LAYER);
 For I:=1 To NCells Do
  If Not Inc_[I] Then
   For K:=1 To NCells Do If Cells[K]^.Sel And IsDescendant(I,K) Then Inc_[I]:=True;
 For I:=1 To NCells Do
  If (Cells[I]^.Kind=K_EDGE) And (Not Inc_[I]) Then
   If (Cells[I]^.SrcIdx>0) And (Cells[I]^.TgtIdx>0) And Inc_[Cells[I]^.SrcIdx] And Inc_[Cells[I]^.TgtIdx] Then Inc_[I]:=True;
 For I:=1 To NCells Do If Inc_[I] Then Inc(N);
 If N=0 Then Begin StatusMsg:=Tr('Nothing to copy'); Exit; End;
 FillChar(H,SizeOf(H),0);
 H.Sig:=SNAP_SIG; H.N:=N; H.GridOn:=GridOn; H.SnapOn:=SnapOn; H.GridSize:=GridSize; H.Bg:=BgColor;
 Assign(F,TmpName('C',0));
 {$I-} Rewrite(F,1); {$I+}
 If IOResult<>0 Then Exit;
 BlockWrite(F,H,SizeOf(H));
 For I:=1 To NCells Do
  If Inc_[I] Then Begin
   C:=Cells[I]^;
   C.Sel:=False;
   If (C.ParIdx=0) Or (Not Inc_[C.ParIdx]) Then C.Parent:='1';
   If C.Kind=K_EDGE Then Begin
    If (C.SrcIdx=0) Or (Not Inc_[C.SrcIdx]) Or (C.TgtIdx=0) Or (Not Inc_[C.TgtIdx]) Then Begin
     EdgePath(I,Pl,Sd,Td);
     If Pl.N>=2 Then Begin
      If (C.SrcIdx=0) Or (Not Inc_[C.SrcIdx]) Then Begin C.SrcPt:=Pl.P[0]; C.Source:=''; End;
      If (C.TgtIdx=0) Or (Not Inc_[C.TgtIdx]) Then Begin C.TgtPt:=Pl.P[Pl.N-1]; C.Target:=''; End;
     End;
    End;
   End;
   BlockWrite(F,C,SizeOf(TCell));
  End;
 Close(F);
 PasteCount:=0;
 StatusMsg:=IStr(N)+Tr(' object(s) copied');
End;

Procedure PasteClip(Off: LongInt);
Var N: Integer;
Begin
 If Not FileExists(TmpName('C',0)) Then Begin StatusMsg:=Tr('Clipboard is empty'); Exit; End;
 UndoPush;
 Inc(PasteCount);
 N:=MergeSnap(TmpName('C',0),Off*PasteCount,Off*PasteCount);
 Touch;
 If N=0 Then StatusMsg:=Tr('Nothing pasted');
End;

{ ------------------------------------------------------------------------- }
{ Ordre d'empilement, groupes, alignement                                    }
{ ------------------------------------------------------------------------- }

Procedure Reorder(Op: Integer);
Var Ids: Array[1..MAX_CELLS] Of String[40]; N, I, J: Integer;
Begin
 N:=0;
 For I:=1 To NCells Do If Cells[I]^.Sel Then Begin Inc(N); Ids[N]:=Cells[I]^.Id; End;
 If N=0 Then Exit;
 UndoPush;
 Case Op Of
  0: For J:=1 To N Do Begin I:=FindId(Ids[J]); If I>0 Then MoveToEnd(I); End;
  1: For J:=N DownTo 1 Do Begin I:=FindId(Ids[J]); If I>0 Then MoveToStart(I); End;
 End;
 ResolveLinks;
 Touch;
End;

Procedure StepOrder(Dir: Integer);
Var I: Integer; P: PCell;
Begin
 I:=FirstSel;
 If I=0 Then Exit;
 If (Dir>0) And (I>=NCells) Then Exit;
 If (Dir<0) And (I<=1) Then Exit;
 UndoPush;
 P:=Cells[I]; Cells[I]:=Cells[I+Dir]; Cells[I+Dir]:=P;
 ResolveLinks;
 Touch;
End;

Procedure DoGroup;
Var I, G, N: Integer; X1, Y1, X2, Y2, A, B, C2, D: LongInt; First: Boolean;
Begin
 N:=0; First:=True; X1:=0; Y1:=0; X2:=0; Y2:=0;
 For I:=1 To NCells Do
  If Cells[I]^.Sel And (Cells[I]^.Kind<>K_LAYER) And Not IsEdgeLabel(I) Then Begin
   CellBounds(I,A,B,C2,D);
   If First Then Begin X1:=A; Y1:=B; X2:=C2; Y2:=D; First:=False; End
   Else Begin
    If A<X1 Then X1:=A; If B<Y1 Then Y1:=B; If C2>X2 Then X2:=C2; If D>Y2 Then Y2:=D;
   End;
   Inc(N);
  End;
 If N<1 Then Exit;
 UndoPush;
 G:=NewCell(K_VERTEX);
 If G=0 Then Exit;
 Cells[G]^.Id:=MakeId; Cells[G]^.Style:='group';
 Cells[G]^.X:=X1; Cells[G]^.Y:=Y1; Cells[G]^.W:=X2-X1; Cells[G]^.H:=Y2-Y1;
 For I:=1 To G-1 Do
  If Cells[I]^.Sel And (Cells[I]^.Kind<>K_LAYER) And ((Cells[I]^.ParIdx=0) Or Not Cells[Cells[I]^.ParIdx]^.Sel) Then
   Cells[I]^.Parent:=Cells[G]^.Id;
 ResolveLinks;
 ClearSel; Cells[G]^.Sel:=True;
 Touch;
End;

Procedure DoUngroup;
Var I, K: Integer; Par: String[40]; Any: Boolean; Del: Array[1..MAX_CELLS] Of Boolean;
Begin
 Any:=False;
 For I:=1 To NCells Do Begin
  Del[I]:=False;
  If Cells[I]^.Sel And (Cells[I]^.Kind=K_VERTEX) Then
   For K:=1 To NCells Do If Cells[K]^.ParIdx=I Then Any:=True;
 End;
 If Not Any Then Begin StatusMsg:=Tr('Select a group to ungroup'); Exit; End;
 UndoPush;
 For I:=1 To NCells Do
  If Cells[I]^.Sel And (Cells[I]^.Kind=K_VERTEX) Then Begin
   Par:=Cells[I]^.Parent;
   For K:=1 To NCells Do
    If Cells[K]^.ParIdx=I Then Begin Cells[K]^.Parent:=Par; Cells[K]^.Sel:=True; End;
   If IsGroup(I) Then Del[I]:=True;
  End;
 For I:=NCells DownTo 1 Do If Del[I] Then FreeCellAt(I);
 ResolveLinks;
 Touch;
End;

Procedure MoveTree(I: Integer; Dx, Dy: LongInt);
Var K, J: Integer; C: PCell;
Begin
 For K:=1 To NCells Do Begin
  If (K<>I) And (Not IsDescendant(K,I)) Then Continue;
  C:=Cells[K];
  If C^.Kind=K_VERTEX Then Begin Inc(C^.X,Dx); Inc(C^.Y,Dy); End
  Else If C^.Kind=K_EDGE Then Begin
   For J:=0 To C^.NPts-1 Do Begin Inc(C^.Pts[J].X,Dx); Inc(C^.Pts[J].Y,Dy); End;
   Inc(C^.SrcPt.X,Dx); Inc(C^.SrcPt.Y,Dy); Inc(C^.TgtPt.X,Dx); Inc(C^.TgtPt.Y,Dy);
  End;
 End;
End;

Procedure AlignSel(Op: Integer);
Var L: Array[1..MAX_CELLS] Of Integer; N, I, J, T: Integer; X1, Y1, X2, Y2, Tot, Gap, Pos_: LongInt; C: PCell;
Begin
 N:=0;
 For I:=1 To NCells Do
  If Cells[I]^.Sel And (Cells[I]^.Kind=K_VERTEX) And (Not IsEdgeLabel(I)) Then Begin Inc(N); L[N]:=I; End;
 If N<2 Then Begin StatusMsg:=Tr('Select two or more shapes'); Exit; End;
 UndoPush;
 X1:=Cells[L[1]]^.X; Y1:=Cells[L[1]]^.Y; X2:=X1+Cells[L[1]]^.W; Y2:=Y1+Cells[L[1]]^.H;
 For I:=2 To N Do Begin
  C:=Cells[L[I]];
  If C^.X<X1 Then X1:=C^.X; If C^.Y<Y1 Then Y1:=C^.Y;
  If C^.X+C^.W>X2 Then X2:=C^.X+C^.W; If C^.Y+C^.H>Y2 Then Y2:=C^.Y+C^.H;
 End;
 If Op<6 Then Begin
  For I:=1 To N Do Begin
   C:=Cells[L[I]];
   Case Op Of
    0: MoveTree(L[I],X1-C^.X,0);
    1: MoveTree(L[I],(X1+X2) Div 2-(C^.X+C^.W Div 2),0);
    2: MoveTree(L[I],X2-(C^.X+C^.W),0);
    3: MoveTree(L[I],0,Y1-C^.Y);
    4: MoveTree(L[I],0,(Y1+Y2) Div 2-(C^.Y+C^.H Div 2));
    5: MoveTree(L[I],0,Y2-(C^.Y+C^.H));
   End;
  End;
 End Else Begin
  { Tri par position puis repartition egale }
  For I:=2 To N Do Begin
   T:=L[I]; J:=I-1;
   While (J>=1) And (((Op=6) And (Cells[L[J]]^.X>Cells[T]^.X)) Or ((Op=7) And (Cells[L[J]]^.Y>Cells[T]^.Y))) Do Begin
    L[J+1]:=L[J]; Dec(J);
   End;
   L[J+1]:=T;
  End;
  Tot:=0;
  For I:=1 To N Do If Op=6 Then Tot:=Tot+Cells[L[I]]^.W Else Tot:=Tot+Cells[L[I]]^.H;
  If Op=6 Then Gap:=(X2-X1-Tot) Div (N-1) Else Gap:=(Y2-Y1-Tot) Div (N-1);
  If Op=6 Then Pos_:=X1 Else Pos_:=Y1;
  For I:=1 To N Do Begin
   C:=Cells[L[I]];
   If Op=6 Then Begin MoveTree(L[I],Pos_-C^.X,0); Pos_:=Pos_+C^.W+Gap; End
   Else Begin MoveTree(L[I],0,Pos_-C^.Y); Pos_:=Pos_+C^.H+Gap; End;
  End;
 End;
 Touch;
End;

{ ------------------------------------------------------------------------- }
{ Styles                                                                      }
{ ------------------------------------------------------------------------- }

Procedure ApplyStyle(Const Key, Val: String);
Var I: Integer; S: String;
Begin
 If SelCount=0 Then Exit;
 UndoPush;
 For I:=1 To NCells Do
  If Cells[I]^.Sel And (Cells[I]^.Kind<>K_LAYER) Then Begin
   S:=Cells[I]^.Style;
   If Val='' Then StyDel(S,Key) Else StySet(S,Key,Val);
   If (Key='whiteSpace') Or (Key='fontSize') Then
    If Not StyBool(S,'html',False) Then StySet(S,'html','1');
   Cells[I]^.Style:=S;
  End;
 Touch;
End;

Function ColorStyleVal(Rgb: LongInt): String;
Begin
 If Rgb<0 Then ColorStyleVal:='none' Else ColorStyleVal:=RGBToHex(Rgb);
End;

Procedure ToggleStyle(Const Key: String);
Var S: String;
Begin
 S:=SelStyleStr(Key,'0');
 If (S='1') Or (S='true') Then ApplyStyle(Key,'0') Else ApplyStyle(Key,'1');
End;

Procedure SetFontStyleBit(Bit: Integer);
Var V: Integer;
Begin
 V:=Integer(IVal(SelStyleStr('fontStyle','0'),0));
 V:=V Xor Bit;
 ApplyStyle('fontStyle',IStr(V));
End;

Procedure ApplyPreset(I: Integer);
Var K: Integer; S: String;
Begin
 If SelCount=0 Then Exit;
 UndoPush;
 For K:=1 To NCells Do
  If Cells[K]^.Sel And (Cells[K]^.Kind=K_VERTEX) Then Begin
   S:=Cells[K]^.Style;
   If I=0 Then Begin StyDel(S,'fillColor'); StyDel(S,'strokeColor'); End
   Else Begin StySet(S,'fillColor',RGBToHex(PresetFill[I])); StySet(S,'strokeColor',RGBToHex(PresetStroke[I])); End;
   Cells[K]^.Style:=S;
  End;
 Touch;
End;

Procedure MergeStyle(Var Base: String; Const Over: String);
Var I, P, Q: Integer; Key, Val: String;
Begin
 I:=1;
 While I<=Length(Over) Do Begin
  P:=I;
  While (P<=Length(Over)) And (Over[P]<>';') Do Inc(P);
  Q:=I;
  While (Q<P) And (Over[Q]<>'=') Do Inc(Q);
  If Q<P Then Begin
   Key:=Copy(Over,I,Q-I); Val:=Copy(Over,Q+1,P-Q-1);
   StySet(Base,Key,Val);
  End;
  I:=P+1;
 End;
End;

{ ------------------------------------------------------------------------- }
{ Insertion de formes et de connecteurs                                       }
{ ------------------------------------------------------------------------- }

Function InsertDef(D: Integer; X, Y: LongInt): Integer;
Var Idx: Integer; C: PCell; S: String; W, H: LongInt;
Begin
 InsertDef:=0;
 UndoPush;
 W:=ShapeDefs[D].W; H:=ShapeDefs[D].H;
 If ShapeDefs[D].Sec=3 Then Begin
  Idx:=NewCell(K_EDGE);
  If Idx=0 Then Begin StatusMsg:=Tr('Too many objects'); Exit; End;
  C:=Cells[Idx];
  C^.Id:=MakeId; C^.Style:=ShapeDefs[D].Sty;
  C^.SrcPt.X:=X; C^.SrcPt.Y:=Y+H; C^.TgtPt.X:=X+W; C^.TgtPt.Y:=Y;
  C^.HasSrc:=True; C^.HasTgt:=True;
 End Else Begin
  Idx:=NewCell(K_VERTEX);
  If Idx=0 Then Begin StatusMsg:=Tr('Too many objects'); Exit; End;
  C:=Cells[Idx];
  C^.Id:=MakeId;
  S:=ShapeDefs[D].Sty;
  If DefaultVStyle<>'' Then MergeStyle(S,DefaultVStyle);
  C^.Style:=S;
  C^.X:=X; C^.Y:=Y; C^.W:=W; C^.H:=H;
 End;
 ClearSel; C^.Sel:=True;
 ResolveLinks;
 If C^.Kind=K_VERTEX Then Begin Reparent(Idx); ResolveLinks; End;
 Touch;
 InsertDef:=Idx;
End;

{ Position libre au centre de la vue }
Procedure FreeSpot(D: Integer; Var X, Y: LongInt);
Begin
 X:=SnapV(DX((CX1+CX2) Div 2)-ShapeDefs[D].W Div 2+(InsertCount Mod 6)*GridSize);
 Y:=SnapV(DY((CY1+CY2) Div 2)-ShapeDefs[D].H Div 2+(InsertCount Mod 6)*GridSize);
 Inc(InsertCount);
End;

Function CreateEdge(Src, Tgt: Integer; SDir: Integer; EndX, EndY: LongInt): Integer;
Var Idx: Integer; C: PCell; S: String;
Begin
 CreateEdge:=0;
 UndoPush;
 Idx:=NewCell(K_EDGE);
 If Idx=0 Then Begin StatusMsg:=Tr('Too many objects'); Exit; End;
 C:=Cells[Idx];
 C^.Id:=MakeId;
 S:=DefaultEStyle;
 If SDir>=0 Then Begin
  Case SDir Of
   0: StySet(S,'exitX','1');
   2: StySet(S,'exitX','0');
  Else StySet(S,'exitX','0.5');
  End;
  Case SDir Of
   1: StySet(S,'exitY','1');
   3: StySet(S,'exitY','0');
  Else StySet(S,'exitY','0.5');
  End;
  StySet(S,'exitDx','0'); StySet(S,'exitDy','0');
 End;
 C^.Style:=S;
 C^.Source:=Cells[Src]^.Id;
 If Tgt>0 Then C^.Target:=Cells[Tgt]^.Id
 Else Begin C^.TgtPt.X:=EndX; C^.TgtPt.Y:=EndY; C^.HasTgt:=True; End;
 ResolveLinks;
 ClearSel; C^.Sel:=True;
 Touch;
 CreateEdge:=Idx;
End;

Procedure BuildDefaultEdgeStyle;
Begin
 Case DefaultEdgeStyle Of
  1: DefaultEStyle:='edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;';
  2: DefaultEStyle:='curved=1;endArrow=classic;html=1;';
 Else DefaultEStyle:='endArrow=classic;html=1;rounded=0;';
 End;
End;

{ ------------------------------------------------------------------------- }
{ Vue : zoom, panoramique, ajustement                                         }
{ ------------------------------------------------------------------------- }

Procedure SetZoomAt(Z: Integer; Sx, Sy: LongInt);
Var Dx0, Dy0: LongInt;
Begin
 If Z<10 Then Z:=10;
 If Z>400 Then Z:=400;
 Dx0:=DX(Sx); Dy0:=DY(Sy);
 Zoom:=Z;
 ViewX:=Dx0-((Sx-CX1)*100) Div Zoom;
 ViewY:=Dy0-((Sy-CY1)*100) Div Zoom;
End;

Procedure ZoomStep(Dir: Integer);
Var I, Best: Integer;
Begin
 Best:=6;
 If Dir>0 Then Begin
  For I:=13 DownTo 0 Do If ZoomSteps[I]>Zoom Then Best:=I;
  If ZoomSteps[13]<=Zoom Then Best:=13;
 End Else Begin
  Best:=0;
  For I:=0 To 13 Do If ZoomSteps[I]<Zoom Then Best:=I;
 End;
 SetZoomAt(ZoomSteps[Best],(CX1+CX2) Div 2,(CY1+CY2) Div 2);
End;

Procedure FitView;
Var I: Integer; X1, Y1, X2, Y2, A, B, C2, D: LongInt; First: Boolean; Z, Zx, Zy: LongInt;
Begin
 First:=True; X1:=0; Y1:=0; X2:=0; Y2:=0;
 For I:=1 To NCells Do Begin
  If (Cells[I]^.Kind=K_LAYER) Or (Not Visible(I)) Or IsEdgeLabel(I) Then Continue;
  CellBounds(I,A,B,C2,D);
  If First Then Begin X1:=A; Y1:=B; X2:=C2; Y2:=D; First:=False; End
  Else Begin
   If A<X1 Then X1:=A; If B<Y1 Then Y1:=B; If C2>X2 Then X2:=C2; If D>Y2 Then Y2:=D;
  End;
 End;
 If First Then Begin Zoom:=100; ViewX:=-20; ViewY:=-20; Exit; End;
 Zx:=(CX2-CX1-30)*100 Div Max(1,X2-X1);
 Zy:=(CY2-CY1-30)*100 Div Max(1,Y2-Y1);
 Z:=Min(Zx,Zy);
 If Z>100 Then Z:=100;
 Z:=Max(10,Z);
 Zoom:=Integer(Z);
 ViewX:=(X1+X2) Div 2-((CX2-CX1) Div 2)*100 Div Zoom;
 ViewY:=(Y1+Y2) Div 2-((CY2-CY1) Div 2)*100 Div Zoom;
End;

Procedure ResetView;
Begin
 Zoom:=100; ViewX:=-20; ViewY:=-20;
End;

{ ------------------------------------------------------------------------- }
{ Edition d'etiquette sur place                                               }
{ ------------------------------------------------------------------------- }

Procedure StartEdit(I: Integer; Const Init: String; Replace: Boolean);
Begin
 If (I<=0) Or (Cells[I]^.Kind=K_LAYER) Then Exit;
 Editing:=True; EditCell:=I; EditHide:=I;
 If Replace Then EditText:=Init Else EditText:=Cells[I]^.Value;
 EditPos:=Length(EditText);
 EditFresh:=False;
 SelectOnly(I);
 RedrawAll;
End;

Procedure EndEdit(Apply: Boolean);
Begin
 If Not Editing Then Exit;
 If Apply And (EditCell>0) And (EditCell<=NCells) Then
  If Copy(EditText,1,120)<>Cells[EditCell]^.Value Then Begin
   UndoPush;
   Cells[EditCell]^.Value:=Copy(EditText,1,120);
   Touch;
  End;
 Editing:=False; EditHide:=0; EditCell:=0;
 RedrawAll;
End;

Procedure DrawEditOverlay;
Var C: PCell; X1, Y1, X2, Y2, Mx, My: LongInt; Py, Px, I, Ln: Integer; Lines: Array[0..12] Of String[120];
    N, Cc: Integer; Pre: String; Pl: TPoly; Sd, Td: Integer;
Begin
 If Not Editing Then Exit;
 C:=Cells[EditCell];
 If C^.Kind=K_EDGE Then Begin
  EdgePath(EditCell,Pl,Sd,Td);
  PathAt(Pl,50,Mx,My);
  X1:=SX(Mx)-70; Y1:=SY(My)-12; X2:=X1+140; Y2:=Y1+24;
 End Else Begin
  X1:=SX(C^.X); Y1:=SY(C^.Y); X2:=SX(C^.X+C^.W); Y2:=SY(C^.Y+C^.H);
  If X2-X1<90 Then Begin Mx:=(X1+X2) Div 2; X1:=Mx-45; X2:=Mx+45; End;
  If Y2-Y1<30 Then Begin My:=(Y1+Y2) Div 2; Y1:=My-15; Y2:=My+15; End;
 End;
 { Decoupe en lignes }
 N:=0; Lines[0]:=''; Ln:=0; Cc:=0;
 For I:=1 To Length(EditText)+1 Do Begin
  If I=EditPos+1 Then Begin Ln:=N; Cc:=Length(Lines[N]); End;
  If I>Length(EditText) Then Break;
  If EditText[I]=#10 Then Begin If N<12 Then Inc(N); Lines[N]:=''; End
  Else If Length(Lines[N])<110 Then Lines[N]:=Lines[N]+EditText[I];
 End;
 If EditPos>=Length(EditText) Then Begin Ln:=N; Cc:=Length(Lines[N]); End;
 HideMouse;
 SetViewPort(CX1,CY1,CX2,CY2,ClipOn);
 X1:=X1-CX1; X2:=X2-CX1; Y1:=Y1-CY1; Y2:=Y2-CY1;
 DBar(X1,Y1,X2,Y2,C_WHITE);
 DRect(X1,Y1,X2,Y2,C_ACCENT);
 SetText(1);
 Py:=Integer(Y1)+4;
 For I:=0 To N Do Begin
  DTextRaw(X1+4,Py+I*10,U8ToCP(Lines[I]),C_BLACK);
  If I=Ln Then Begin
   Pre:=U8ToCP(Copy(Lines[I],1,Cc));
   Px:=Integer(X1)+4+TextWidth(Pre);
   SetColor(C_ACCENT); DLine(Px,Py+I*10-1,Px,Py+I*10+8);
  End;
 End;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,ClipOff);
 ShowMouse;
End;

{ ------------------------------------------------------------------------- }
{ Pages                                                                       }
{ ------------------------------------------------------------------------- }

Procedure SwitchPage(N: Integer);
Begin
 If (N<0) Or (N>=NPages) Or (N=CurPage) Then Exit;
 Pages[CurPage].Name:=PageName;
 SnapSave(PageSnap(CurPage));
 If SnapLoad(PageSnap(N)) Then Begin
  CurPage:=N;
  PageName:=Pages[N].Name;
  ClearSel;
  ResetUndo;
  FitView;
  If Zoom>100 Then ResetView;
 End;
 RedrawAll;
End;

Procedure AddPage;
Begin
 If NPages>=MAX_PAGES Then Begin ShowMsg(Tr('Pages'),Tr('Too many pages')); Exit; End;
 Pages[CurPage].Name:=PageName;
 SnapSave(PageSnap(CurPage));
 ClearDoc;
 ResetDocSettings;
 Pages[NPages].Name:='Page-'+IStr(NPages+1);
 CurPage:=NPages; Inc(NPages);
 PageName:=Pages[CurPage].Name;
 ResetUndo; ResetView; Touch;
 RedrawAll;
End;

Procedure DeletePage;
Var I: Integer;
Begin
 If NPages<=1 Then Begin ShowMsg(Tr('Pages'),Tr('A diagram needs at least one page')); Exit; End;
 If Not Confirm(Tr('Delete Page')+' "'+PageName+'" ?') Then Exit;
 Pages[CurPage].Name:=PageName;
 SnapSave(PageSnap(CurPage));
 For I:=CurPage To NPages-2 Do Begin
  SnapLoad(PageSnap(I+1));
  Pages[I].Name:=Pages[I+1].Name;
  PageName:=Pages[I].Name;
  SnapSave(PageSnap(I));
 End;
 Dec(NPages);
 If CurPage>=NPages Then CurPage:=NPages-1;
 SnapLoad(PageSnap(CurPage));
 PageName:=Pages[CurPage].Name;
 ClearSel; ResetUndo; ResetView; Touch;
 RedrawAll;
End;

Procedure RenamePage;
Var S: String;
Begin
 S:=PageName;
 If InputBox(Tr('Rename page'),Tr('Page name:'),S,40) Then Begin
  If S<>'' Then Begin PageName:=Copy(S,1,40); Pages[CurPage].Name:=PageName; Touch; End;
 End;
End;

{ Supprime une cle de style d'une cellule }
Procedure StyDelLocal(C: PCell; Const Key: String);
Var S: String;
Begin
 S:=C^.Style;
 StyDel(S,Key);
 If Key='exitX' Then Begin StyDel(S,'exitY'); StyDel(S,'exitDx'); StyDel(S,'exitDy'); End;
 If Key='entryX' Then Begin StyDel(S,'entryY'); StyDel(S,'entryDx'); StyDel(S,'entryDy'); End;
 C^.Style:=S;
End;

{ ========================================================================== }
{                       FICHIERS : NOUVEAU / OUVRIR / ENREGISTRER            }
{ ========================================================================== }

Function LooksLikeDrawio(Const Name: String): Boolean;
Var X: PXml; N: Integer;
Begin
 LooksLikeDrawio:=False;
 X:=XOpen(Name);
 If X=Nil Then Exit;
 N:=0;
 While XTag(X) And (N<40) Do Begin
  Inc(N);
  If (X^.Name='mxfile') Or (X^.Name='mxGraphModel') Or (X^.Name='diagram') Then Begin
   LooksLikeDrawio:=True; Break;
  End;
 End;
 XClose(X);
End;

Procedure DoSave(AsNew: Boolean);
Var Nm: String;
Begin
 Nm:=FileName;
 If AsNew Or (Nm='') Then Begin
  If Nm='' Then Nm:='diagram.drawio';
  If Not FileDialog(Tr('Save as'),Nm,True,'.drawio;.xml;.dio','.drawio') Then Exit;
  If FileExists(Nm) And (Nm<>FileName) Then
   If Not Confirm(Tr('File ')+Nm+Tr(' exists. Overwrite?')) Then Exit;
 End;
 If SaveDrawio(Nm,CompressedSave) Then Begin
  FileName:=Nm; Modified:=False; StatusMsg:=Tr('Saved ')+Nm;
 End Else ShowMsg(Tr('Save'),Tr('Cannot save the file. ')+LastError);
 RedrawAll;
End;

Function ConfirmDiscard: Boolean;
Var R: Integer;
Begin
 ConfirmDiscard:=True;
 If Not Modified Then Exit;
 R:=MessageBox(Tr('Unsaved changes'),Fr('The diagram has been modified. Save changes?','Le diagramme a été modifié. Enregistrer les modifications ?'),2);
 If R=1 Then Begin
  DoSave(False);
  ConfirmDiscard:=Not Modified;
 End Else If R=0 Then ConfirmDiscard:=False;
End;

Procedure NewDoc;
Begin
 If Not ConfirmDiscard Then Exit;
 ClearDoc; ResetDocSettings;
 NPages:=1; CurPage:=0; Pages[0].Name:='Page-1'; PageName:='Page-1';
 FileName:=''; Modified:=False; ResetUndo; ResetView; ClearSel;
 RedrawAll;
End;

Function DoLoad(Const Nm: String): Boolean;
Var N: Integer;
Begin
 DoLoad:=False;
 If Not FileExists(Nm) Then Begin ShowMsg(Tr('Open'),Tr('File not found: ')+Nm); Exit; End;
 If Not LooksLikeDrawio(Nm) Then Begin ShowMsg(Tr('Open'),Tr('This file is not a draw.io diagram.')); Exit; End;
 PageTag:='P';
 If Not ReadDrawio(Nm,N) Then Begin
  ClearDoc; ResetDocSettings; NPages:=1; CurPage:=0; Pages[0].Name:='Page-1'; PageName:='Page-1';
  FileName:=''; ResetUndo;
  ShowMsg(Tr('Open'),Tr('Cannot read the diagram. ')+LastError);
  Exit;
 End;
 NPages:=N; CurPage:=0;
 SnapLoad(PageSnap(0));
 PageName:=Pages[0].Name;
 FileName:=Nm; Modified:=False; ResetUndo; ClearSel;
 Layout;
 FitView;
 If Zoom>100 Then ResetView;
 StatusMsg:=Tr('Opened ')+Nm;
 DoLoad:=True;
End;

Procedure DoOpen;
Var Nm: String;
Begin
 If Not ConfirmDiscard Then Exit;
 Nm:='';
 If Not FileDialog(Tr('Open'),Nm,False,'.drawio;.xml;.dio','') Then Exit;
 DoLoad(Nm);
 RedrawAll;
End;

Procedure DoImport;
Var Nm: String; N, K: Integer; SavedPages: TPageArr; SvN, SvCur: Integer; Cnt: Integer;
Begin
 Nm:='';
 If Not FileDialog(Tr('Import from file'),Nm,False,'.drawio;.xml;.dio','') Then Exit;
 If Not LooksLikeDrawio(Nm) Then Begin ShowMsg(Tr('Import'),Tr('This file is not a draw.io diagram.')); Exit; End;
 Pages[CurPage].Name:=PageName;
 SnapSave(TmpName('B',0));
 SavedPages:=Pages; SvN:=NPages; SvCur:=CurPage;
 PageTag:='I';
 K:=0;
 If ReadDrawio(Nm,N) Then K:=N;
 PageTag:='P';
 Pages:=SavedPages; NPages:=SvN; CurPage:=SvCur;
 SnapLoad(TmpName('B',0));
 EraseFile(TmpName('B',0));
 If K=0 Then Begin ShowMsg(Tr('Import'),Tr('Cannot read the diagram. ')+LastError); Exit; End;
 UndoPush;
 Cnt:=MergeSnap(TmpName('I',0),30,30);
 For K:=0 To MAX_PAGES-1 Do EraseFile(TmpName('I',K));
 Touch;
 StatusMsg:=IStr(Cnt)+Tr(' object(s) imported');
 RedrawAll;
End;

Procedure DoExportSvg;
Var Nm: String;
Begin
 Nm:=FileName;
 If Nm='' Then Nm:='diagram' Else Begin
  If (Length(Nm)>7) And (LoStr(Copy(Nm,Length(Nm)-6,7))='.drawio') Then Nm:=Copy(Nm,1,Length(Nm)-7);
 End;
 Nm:=Nm+'.svg';
 If Not FileDialog(Tr('Export as SVG'),Nm,True,'.svg','.svg') Then Exit;
 If ExportSvg(Nm) Then StatusMsg:=Tr('Exported ')+Nm Else ShowMsg(Tr('Export'),Tr('Cannot write the SVG file.'));
 RedrawAll;
End;

Procedure DoExportXml;
Var Nm: String;
Begin
 Nm:='diagram.xml';
 If Not FileDialog(Tr('Export as XML'),Nm,True,'.xml','.xml') Then Exit;
 If SaveModelXml(Nm) Then StatusMsg:=Tr('Exported ')+Nm Else ShowMsg(Tr('Export'),Tr('Cannot write the file.'));
 RedrawAll;
End;

Procedure DoQuit;
Begin
 If ConfirmDiscard Then Running:=False;
End;

{ ========================================================================== }
{                              COMMANDES                                     }
{ ========================================================================== }

Procedure DoEditStyle;
Var I: Integer; S: String; K: Integer;
Begin
 I:=FirstSel;
 If I=0 Then Begin StatusMsg:=Tr('Select a shape first'); Exit; End;
 S:=Cells[I]^.Style;
 If InputBox(Tr('Edit Style'),Tr('Style (key=value;...):'),S,255) Then Begin
  UndoPush;
  For K:=1 To NCells Do If Cells[K]^.Sel And (Cells[K]^.Kind<>K_LAYER) Then Cells[K]^.Style:=S;
  Touch;
 End;
End;

Procedure DoEditLabel;
Begin
 If FirstSel>0 Then StartEdit(FirstSel,'',False);
End;

Procedure PickColor(Which: Integer);
Var Rgb: LongInt; Key: String; I: Integer;
Begin
 I:=FirstSel;
 Case Which Of
  CO_FILL: Begin Key:='fillColor'; If I>0 Then Rgb:=CellFill(I) Else Rgb:=$FFFFFF; End;
  CO_STROKE: Begin Key:='strokeColor'; If I>0 Then Rgb:=CellStroke(I) Else Rgb:=0; End;
  CO_GRAD: Begin Key:='gradientColor'; Rgb:=$FFFFFF; If I>0 Then Rgb:=ParseColor(StyStr(Cells[I]^.Style,'gradientColor',''),$FFFFFF); End;
  CO_FONT: Begin Key:='fontColor'; If I>0 Then Rgb:=CellFontColor(I) Else Rgb:=0; End;
  CO_LBLBG: Begin Key:='labelBackgroundColor'; Rgb:=-1; If I>0 Then Rgb:=ParseColor(StyStr(Cells[I]^.Style,'labelBackgroundColor',''),-1); End;
 Else Key:='';
 End;
 If Which=CO_BG Then Begin
  Rgb:=BgColor;
  If ColorDialog(Tr('Background color'),Rgb) Then Begin UndoPush; BgColor:=Rgb; Touch; End;
  Exit;
 End;
 If (Key='') Or (I=0) Then Exit;
 If ColorDialog(Tr('Color'),Rgb) Then ApplyStyle(Key,ColorStyleVal(Rgb));
End;

Procedure ToggleCheck(Id: Integer);
Var I: Integer;
Begin
 I:=FirstSel;
 Case Id Of
  CK_GRID: GridOn:=Not GridOn;
  CK_SNAP: SnapOn:=Not SnapOn;
  CK_BG: Begin If BgColor>=0 Then BgColor:=-1 Else BgColor:=$FFFFFF; End;
 Else Begin
  If I=0 Then Exit;
  Case Id Of
   CK_FILL: Begin
    If CellFill(I)>=0 Then ApplyStyle('fillColor','none') Else ApplyStyle('fillColor','#ffffff');
   End;
   CK_GRAD: Begin
    If ParseColor(StyStr(Cells[I]^.Style,'gradientColor',''),-1)>=0 Then ApplyStyle('gradientColor','')
    Else ApplyStyle('gradientColor','#ffffff');
   End;
   CK_LINE: Begin
    If CellStroke(I)>=0 Then ApplyStyle('strokeColor','none') Else ApplyStyle('strokeColor','#000000');
   End;
   CK_ROUND: ToggleStyle('rounded');
   CK_SHADOW: ToggleStyle('shadow');
   CK_GLASS: ToggleStyle('glass');
   CK_COMIC: ToggleStyle('comic');
   CK_WRAP: Begin
    If StyStr(Cells[I]^.Style,'whiteSpace','')='wrap' Then ApplyStyle('whiteSpace','') Else ApplyStyle('whiteSpace','wrap');
   End;
   CK_BOLD: SetFontStyleBit(1);
   CK_ITAL: SetFontStyleBit(2);
   CK_UNDER: SetFontStyleBit(4);
  End;
 End;
 End;
End;

Function SpinValue(Field: Integer): LongInt;
Var I: Integer;
Begin
 SpinValue:=0;
 I:=FirstSel;
 Case Field Of
  F_GRIDSZ: SpinValue:=GridSize;
 Else If I>0 Then
  Case Field Of
   F_SWIDTH: SpinValue:=StyInt(Cells[I]^.Style,'strokeWidth',1);
   F_OPACITY: SpinValue:=StyInt(Cells[I]^.Style,'opacity',100);
   F_FSIZE: SpinValue:=StyInt(Cells[I]^.Style,'fontSize',12);
   F_X: SpinValue:=Cells[I]^.X;
   F_Y: SpinValue:=Cells[I]^.Y;
   F_W: SpinValue:=Cells[I]^.W;
   F_H: SpinValue:=Cells[I]^.H;
  End;
 End;
End;

Procedure SpinSet(Field: Integer; V: LongInt);
Var K: Integer; Cur: LongInt;
Begin
 If Field=F_GRIDSZ Then Begin GridSize:=Integer(Clamp(V,2,200)); Modified:=True; Exit; End;
 If FirstSel=0 Then Exit;
 Case Field Of
  F_SWIDTH: ApplyStyle('strokeWidth',IStr(Clamp(V,0,30)));
  F_OPACITY: ApplyStyle('opacity',IStr(Clamp(V,0,100)));
  F_FSIZE: ApplyStyle('fontSize',IStr(Clamp(V,6,120)));
  F_X,F_Y: Begin
   Cur:=SpinValue(Field);
   If V<>Cur Then Begin
    UndoPush;
    If Field=F_X Then MoveSelected(V-Cur,0) Else MoveSelected(0,V-Cur);
    Touch;
   End;
  End;
  F_W,F_H: Begin
   Cur:=SpinValue(Field);
   If (V>=4) And (V<>Cur) Then Begin
    UndoPush;
    For K:=1 To NCells Do
     If Cells[K]^.Sel And (Cells[K]^.Kind=K_VERTEX) Then
      If Field=F_W Then Cells[K]^.W:=V Else Cells[K]^.H:=V;
    Touch;
   End;
  End;
 End;
End;

Procedure SpinApply(Field: Integer; Dir: Integer);
Var Step: LongInt;
Begin
 Step:=1;
 If Field=F_OPACITY Then Step:=10;
 If (Field=F_X) Or (Field=F_Y) Or (Field=F_W) Or (Field=F_H) Then Step:=GridSize;
 SpinSet(Field,SpinValue(Field)+Dir*Step);
End;

Procedure SpinEdit(Field: Integer);
Var S: String;
Begin
 S:=IStr(SpinValue(Field));
 If InputBox(Tr('Value'),Tr('New value:'),S,8) Then SpinSet(Field,IVal(S,SpinValue(Field)));
End;

Procedure DropAction(Id: Integer; X, Y: Integer);
Var R: Integer;
Begin
 Case Id Of
  DD_DASH: Begin
   R:=PopupList(X,Y,Tr('Solid|Dashed|Dotted'),0);
   Case R Of
    0: Begin ApplyStyle('dashed','0'); ApplyStyle('dashPattern',''); End;
    1: Begin ApplyStyle('dashed','1'); ApplyStyle('dashPattern',''); End;
    2: Begin ApplyStyle('dashed','1'); ApplyStyle('dashPattern','1 3'); End;
   End;
  End;
  DD_CONN: Begin
   R:=PopupList(X,Y,Tr('Straight|Orthogonal|Elbow|Curved'),0);
   Case R Of
    0: Begin ApplyStyle('edgeStyle',''); ApplyStyle('curved',''); End;
    1: Begin ApplyStyle('edgeStyle','orthogonalEdgeStyle'); ApplyStyle('curved',''); End;
    2: Begin ApplyStyle('edgeStyle','elbowEdgeStyle'); ApplyStyle('elbow','horizontal'); ApplyStyle('curved',''); End;
    3: Begin ApplyStyle('curved','1'); ApplyStyle('edgeStyle',''); End;
   End;
  End;
  DD_START,DD_END: Begin
   R:=PopupList(X,Y,'none|classic|classicThin|block|blockThin|open|oval|diamond|dash',1);
   If R>=0 Then Begin
    If Id=DD_START Then ApplyStyle('startArrow',ArrowNames[R]) Else ApplyStyle('endArrow',ArrowNames[R]);
   End;
  End;
 End;
End;

Procedure SetAlignKey(Key: Integer);
Begin
 Case Key Of
  BT_AL: ApplyStyle('align','left');
  BT_AC: ApplyStyle('align','center');
  BT_AR: ApplyStyle('align','right');
  BT_VT: ApplyStyle('verticalAlign','top');
  BT_VM: ApplyStyle('verticalAlign','middle');
  BT_VB: ApplyStyle('verticalAlign','bottom');
 End;
End;

Procedure ClearWaypoints;
Var I: Integer;
Begin
 UndoPush;
 For I:=1 To NCells Do If Cells[I]^.Sel And (Cells[I]^.Kind=K_EDGE) Then Cells[I]^.NPts:=0;
 Touch;
End;

Procedure CopyStyle;
Var I: Integer;
Begin
 I:=FirstSel;
 If I>0 Then Begin StyleClip:=Cells[I]^.Style; StatusMsg:=Tr('Style copied'); End;
End;

Procedure PasteStyle;
Var K: Integer;
Begin
 If (StyleClip='') Or (FirstSel=0) Then Begin StatusMsg:=Tr('No style copied'); Exit; End;
 UndoPush;
 For K:=1 To NCells Do If Cells[K]^.Sel And (Cells[K]^.Kind<>K_LAYER) Then Cells[K]^.Style:=StyleClip;
 Touch;
End;

Procedure SetDefaultStyle;
Var I: Integer; S: String;
Begin
 I:=FirstSel;
 If I=0 Then Exit;
 S:=Cells[I]^.Style;
 If Cells[I]^.Kind=K_EDGE Then DefaultEStyle:=S
 Else Begin
  StyDel(S,'shape'); DefaultVStyle:='';
  If StyGet(S,'fillColor',Names0) Then DefaultVStyle:=DefaultVStyle+'fillColor='+Names0+';';
  If StyGet(S,'strokeColor',Names0) Then DefaultVStyle:=DefaultVStyle+'strokeColor='+Names0+';';
  If StyGet(S,'fontColor',Names0) Then DefaultVStyle:=DefaultVStyle+'fontColor='+Names0+';';
  If StyGet(S,'fontSize',Names0) Then DefaultVStyle:=DefaultVStyle+'fontSize='+Names0+';';
 End;
 StatusMsg:=Tr('Default style updated');
End;

Procedure SelectAll;
Var I: Integer;
Begin
 For I:=1 To NCells Do Cells[I]^.Sel:=(Cells[I]^.Kind<>K_LAYER) And Visible(I) And (Not IsEdgeLabel(I));
End;

Procedure SelectKind(K: Byte);
Var I: Integer;
Begin
 For I:=1 To NCells Do Cells[I]^.Sel:=(Cells[I]^.Kind=K) And Visible(I) And (Not IsEdgeLabel(I));
End;

Procedure NextShape;
Var I, J: Integer;
Begin
 I:=FirstSel;
 For J:=1 To NCells Do Begin
  I:=I+1;
  If I>NCells Then I:=1;
  If (Cells[I]^.Kind<>K_LAYER) And Visible(I) And (Not IsEdgeLabel(I)) Then Begin SelectOnly(I); Exit; End;
 End;
End;

Procedure DoCommand(Id: Integer);
Begin
 StatusMsg:='';
 Case Id Of
  CM_NEW: NewDoc;
  CM_OPEN: DoOpen;
  CM_SAVE: DoSave(False);
  CM_SAVEAS: DoSave(True);
  CM_IMPORT: DoImport;
  CM_EXPSVG: DoExportSvg;
  CM_EXPXML: DoExportXml;
  CM_QUIT: DoQuit;
  CM_UNDO: Begin DoUndo; ClearSel; End;
  CM_REDO: Begin DoRedo; ClearSel; End;
  CM_CUT: Begin CopySelection; DeleteSelected; End;
  CM_COPY: CopySelection;
  CM_PASTE: PasteClip(20);
  CM_DELETE: DeleteSelected;
  CM_DUP: Begin CopySelection; PasteClip(20); End;
  CM_EDITSTYLE: DoEditStyle;
  CM_EDITLABEL: DoEditLabel;
  CM_COPYSTYLE: CopyStyle;
  CM_PASTESTYLE: PasteStyle;
  CM_SELALL: SelectAll;
  CM_SELNONE: ClearSel;
  CM_SELV: SelectKind(K_VERTEX);
  CM_SELE: SelectKind(K_EDGE);
  CM_SHAPES: ShowLeft:=Not ShowLeft;
  CM_FORMAT: ShowRight:=Not ShowRight;
  CM_GRID: GridOn:=Not GridOn;
  CM_SNAP: SnapOn:=Not SnapOn;
  CM_ZIN: ZoomStep(1);
  CM_ZOUT: ZoomStep(-1);
  CM_Z100: ResetView;
  CM_ZFIT: FitView;
  CM_FRONT: Reorder(0);
  CM_BACK: Reorder(1);
  CM_FWD: StepOrder(1);
  CM_BWD: StepOrder(-1);
  CM_GROUP: DoGroup;
  CM_UNGROUP: DoUngroup;
  CM_AL: AlignSel(0);
  CM_AC: AlignSel(1);
  CM_AR: AlignSel(2);
  CM_AT: AlignSel(3);
  CM_AM: AlignSel(4);
  CM_AB: AlignSel(5);
  CM_DH: AlignSel(6);
  CM_DV: AlignSel(7);
  CM_CLRPTS: ClearWaypoints;
  CM_COMPR: CompressedSave:=Not CompressedSave;
  CM_GRIDSZ: Begin
   StyleTmp:=IStr(GridSize);
   If InputBox(Tr('Grid size'),Tr('Grid size (pixels):'),StyleTmp,4) Then GridSize:=Integer(Clamp(IVal(StyleTmp,10),2,200));
  End;
  CM_BGCOL: PickColor(CO_BG);
  CM_ESTR: Begin DefaultEdgeStyle:=0; BuildDefaultEdgeStyle; End;
  CM_EORT: Begin DefaultEdgeStyle:=1; BuildDefaultEdgeStyle; End;
  CM_ECUR: Begin DefaultEdgeStyle:=2; BuildDefaultEdgeStyle; End;
  CM_ADDPAGE: AddPage;
  CM_DELPAGE: DeletePage;
  CM_RENPAGE: RenamePage;
  CM_PREVPAGE: SwitchPage(CurPage-1);
  CM_NEXTPAGE: SwitchPage(CurPage+1);
  CM_KEYS: ShowKeys;
  CM_ABOUT: ShowAbout;
 End;
 RedrawAll;
End;

Function FindDef(Const Nm: String): Integer;
Var I: Integer;
Begin
 FindDef:=0;
 For I:=0 To NDEFS-1 Do If ShapeDefs[I].Name=Nm Then Begin FindDef:=I; Exit; End;
End;

Procedure InsertQuick;
Var R, D: Integer; X, Y: LongInt;
Begin
 R:=PopupList(150,TOOL_Y+TOOL_H,Tr('Rectangle|Rounded Rectangle|Ellipse|Diamond|Text|Swimlane|Arrow'),0);
 Case R Of
  0: D:=FindDef('Rectangle'); 1: D:=FindDef('Rounded Rectangle'); 2: D:=FindDef('Ellipse');
  3: D:=FindDef('Diamond'); 4: D:=FindDef('Text'); 5: D:=FindDef('Swimlane'); 6: D:=FindDef('Arrow');
 Else Exit;
 End;
 FreeSpot(D,X,Y);
 InsertDef(D,X,Y);
 RedrawAll;
End;

Procedure ToolAction(Id: Integer);
Var R: Integer;
Begin
 StatusMsg:='';
 Case Id Of
  1: ShowRight:=Not ShowRight;
  2: ZoomStep(-1);
  4: ZoomStep(1);
  3: Begin
   R:=PopupList(60,TOOL_Y+TOOL_H,'Fit window|25%|50%|75%|100%|150%|200%|300%|400%',4);
   Case R Of
    0: FitView;
    1: SetZoomAt(25,(CX1+CX2) Div 2,(CY1+CY2) Div 2);
    2: SetZoomAt(50,(CX1+CX2) Div 2,(CY1+CY2) Div 2);
    3: SetZoomAt(75,(CX1+CX2) Div 2,(CY1+CY2) Div 2);
    4: SetZoomAt(100,(CX1+CX2) Div 2,(CY1+CY2) Div 2);
    5: SetZoomAt(150,(CX1+CX2) Div 2,(CY1+CY2) Div 2);
    6: SetZoomAt(200,(CX1+CX2) Div 2,(CY1+CY2) Div 2);
    7: SetZoomAt(300,(CX1+CX2) Div 2,(CY1+CY2) Div 2);
    8: SetZoomAt(400,(CX1+CX2) Div 2,(CY1+CY2) Div 2);
   End;
  End;
  5: Begin DoUndo; ClearSel; End;
  6: Begin DoRedo; ClearSel; End;
  7: DeleteSelected;
  8: Reorder(0);
  9: Reorder(1);
  10: PickColor(CO_FILL);
  11: PickColor(CO_STROKE);
  12: ToggleStyle('shadow');
  13: Begin
   DefaultEdgeStyle:=(DefaultEdgeStyle+1) Mod 3; BuildDefaultEdgeStyle;
   If SelHasEdge Then Begin
    Case DefaultEdgeStyle Of
     0: Begin ApplyStyle('edgeStyle',''); ApplyStyle('curved',''); End;
     1: Begin ApplyStyle('edgeStyle','orthogonalEdgeStyle'); ApplyStyle('curved',''); End;
     2: Begin ApplyStyle('curved','1'); ApplyStyle('edgeStyle',''); End;
    End;
   End;
   Case DefaultEdgeStyle Of
    0: StatusMsg:=Tr('Connection: straight'); 1: StatusMsg:=Tr('Connection: orthogonal'); 2: StatusMsg:=Tr('Connection: curved');
   End;
  End;
  14: Begin
   If SelHasEdge Then ToggleStyle('rounded') Else StatusMsg:=Tr('Select a connector');
  End;
  15: Begin InsertQuick; Exit; End;
  20: DoSave(False);
  21: DoQuit;
 End;
 RedrawAll;
End;

Procedure ButtonAction(Id: Integer);
Begin
 StatusMsg:='';
 Case Id Of
  BT_EDITSTYLE: DoEditStyle;
  BT_EDITSTYLE+100: DoEditLabel;
  BT_COPYSTYLE: CopyStyle;
  BT_PASTESTYLE: PasteStyle;
  BT_SETDEFAULT: SetDefaultStyle;
  BT_FRONT: Reorder(0);
  BT_BACK: Reorder(1);
  BT_FWD: StepOrder(1);
  BT_BWD: StepOrder(-1);
  BT_GROUP: DoGroup;
  BT_UNGROUP: DoUngroup;
  BT_RESETVIEW: ResetView;
  BT_CLRPTS: ClearWaypoints;
  BT_AL,BT_AC,BT_AR,BT_VT,BT_VM,BT_VB: SetAlignKey(Id);
  BT_ALIGN0..BT_ALIGN0+7: AlignSel(Id-BT_ALIGN0);
 End;
 RedrawAll;
End;

{ ========================================================================== }
{                  INTERACTION : SOURIS, GLISSER-DEPOSER, CLAVIER            }
{ ========================================================================== }

Const
 DM_NONE = 0; DM_MOVE = 1; DM_RESIZE = 2; DM_LASSO = 3; DM_PAN = 4; DM_CONNECT = 5;
 DM_EDGEEND = 6; DM_WAYPT = 7; DM_PAL = 8;

Var
 DragMode, DragHandle, DragIdx, DragDef, DragEnd: Integer;
 DragX0, DragY0: Integer;
 DocX0, DocY0: LongInt;
 DragMoved, NewWp: Boolean;
 ConnDir, WpIns: Integer;
 GDx, GDy, GPx, GPy, GX1, GY1, GX2, GY2, GAx, GAy, GBx, GBy, PanVX, PanVY, OrgX, OrgY: LongInt;
 PrimIdx: Integer;


Function InCanvas(X, Y: Integer): Boolean;
Begin
 InCanvas:=(X>=CX1) And (X<=CX2) And (Y>=CY1) And (Y<=CY2);
End;

{ Position ecran du centre de la fleche de connexion Dir (0 E,1 S,2 O,3 N) }
Procedure ArrowPos(I, Dir: Integer; Var Ax, Ay: LongInt);
Var C: PCell; X1, Y1, X2, Y2: LongInt;
Begin
 C:=Cells[I];
 X1:=SX(C^.X); Y1:=SY(C^.Y); X2:=SX(C^.X+C^.W); Y2:=SY(C^.Y+C^.H);
 Case Dir Of
  0: Begin Ax:=X2+13; Ay:=(Y1+Y2) Div 2; End;
  1: Begin Ax:=(X1+X2) Div 2; Ay:=Y2+13; End;
  2: Begin Ax:=X1-13; Ay:=(Y1+Y2) Div 2; End;
 Else Begin Ax:=(X1+X2) Div 2; Ay:=Y1-13; End;
 End;
End;

Procedure DrawHoverArrows(I: Integer);
Var D: Integer; Ax, Ay: LongInt; Q: Array[0..3] Of PointType;
Begin
 HideMouse;
 EnterCanvas;
 SetWriteMode(XORPut);
 SetFillStyle(SolidFill,C_WHITE); SetColor(C_WHITE);
 For D:=0 To 3 Do Begin
  ArrowPos(I,D,Ax,Ay);
  Case D Of
   0: Begin Q[0].X:=Cl(Ax-4); Q[0].Y:=Cl(Ay-5); Q[1].X:=Cl(Ax+5); Q[1].Y:=Cl(Ay); Q[2].X:=Cl(Ax-4); Q[2].Y:=Cl(Ay+5); End;
   1: Begin Q[0].X:=Cl(Ax-5); Q[0].Y:=Cl(Ay-4); Q[1].X:=Cl(Ax); Q[1].Y:=Cl(Ay+5); Q[2].X:=Cl(Ax+5); Q[2].Y:=Cl(Ay-4); End;
   2: Begin Q[0].X:=Cl(Ax+4); Q[0].Y:=Cl(Ay-5); Q[1].X:=Cl(Ax-5); Q[1].Y:=Cl(Ay); Q[2].X:=Cl(Ax+4); Q[2].Y:=Cl(Ay+5); End;
  Else Begin Q[0].X:=Cl(Ax-5); Q[0].Y:=Cl(Ay+4); Q[1].X:=Cl(Ax); Q[1].Y:=Cl(Ay-5); Q[2].X:=Cl(Ax+5); Q[2].Y:=Cl(Ay+4); End;
  End;
  Q[3]:=Q[0];
  DrawPoly(4,Q);
 End;
 SetWriteMode(NormalPut);
 LeaveCanvas;
 ShowMouse;
End;

Procedure ClearHover;
Begin
 If HoverOn And (HoverIdx>0) And (HoverIdx<=NCells) Then DrawHoverArrows(HoverIdx);
 HoverOn:=False; HoverIdx:=0;
End;

Procedure DrawGhost;
Var I, K: Integer; C: PCell;
Begin
 HideMouse;
 EnterCanvas;
 SetWriteMode(XORPut);
 SetColor(C_WHITE);
 SetLineStyle(SolidLn,0,NormWidth);
 Case DragMode Of
  DM_MOVE: Begin
   K:=0;
   For I:=1 To NCells Do Begin
    C:=Cells[I];
    If C^.Sel And (C^.Kind=K_VERTEX) And (K<60) And (Not C^.Rel) Then Begin
     DRect(SX(C^.X+GDx),SY(C^.Y+GDy),SX(C^.X+C^.W+GDx),SY(C^.Y+C^.H+GDy),C_WHITE);
     Inc(K);
    End;
   End;
  End;
  DM_RESIZE: DRect(SX(GX1),SY(GY1),SX(GX2),SY(GY2),C_WHITE);
  DM_LASSO: DRect(SX(DocX0),SY(DocY0),SX(GPx),SY(GPy),C_WHITE);
  DM_CONNECT,DM_EDGEEND: DLine(SX(GAx),SY(GAy),SX(GPx),SY(GPy));
  DM_WAYPT: Begin
   DLine(SX(GAx),SY(GAy),SX(GPx),SY(GPy));
   DLine(SX(GBx),SY(GBy),SX(GPx),SY(GPy));
  End;
  DM_PAL: DRect(SX(GPx-ShapeDefs[DragDef].W Div 2),SY(GPy-ShapeDefs[DragDef].H Div 2),
                SX(GPx+ShapeDefs[DragDef].W Div 2),SY(GPy+ShapeDefs[DragDef].H Div 2),C_WHITE);
 End;
 SetWriteMode(NormalPut);
 LeaveCanvas;
 ShowMouse;
End;

Procedure EraseGhost;
Begin
 If GhostOn Then Begin DrawGhost; GhostOn:=False; End;
End;

Procedure ShowGhost;
Begin
 DrawGhost; GhostOn:=True;
End;

{ Index (0..7) de la poignee sous (X,Y) pour un sommet unique selectionne, ou -1 }
Function HandleAt(I, X, Y: Integer): Integer;
Var C: PCell; K: Integer; X1, Y1, X2, Y2, Hx, Hy: LongInt;
Begin
 HandleAt:=-1;
 C:=Cells[I];
 X1:=SX(C^.X)-2; Y1:=SY(C^.Y)-2; X2:=SX(C^.X+C^.W)+2; Y2:=SY(C^.Y+C^.H)+2;
 For K:=0 To 7 Do Begin
  HandlePos(K,X1,Y1,X2,Y2,Hx,Hy);
  If (Abs(X-Hx)<=4) And (Abs(Y-Hy)<=4) Then Begin HandleAt:=K; Exit; End;
 End;
End;

{ ------------------------------------------------------------------------- }

Procedure CanvasDown(X, Y: Integer);
Var Dxd, Dyd: LongInt; I, H, K, Sd, Td, Best: Integer; C: PCell; Pl: TPoly; Ax, Ay, Bd, D: LongInt;
    Tg: Integer;
Begin
 Dxd:=DX(X); Dyd:=DY(Y);
 DragX0:=X; DragY0:=Y; DocX0:=Dxd; DocY0:=Dyd; DragMoved:=False; NewWp:=False;
 DragMode:=DM_NONE;
 { Poignees d'un objet unique }
 If SelCount=1 Then Begin
  I:=FirstSel; C:=Cells[I];
  If C^.Kind=K_VERTEX Then Begin
   H:=HandleAt(I,X,Y);
   If H>=0 Then Begin
    DragMode:=DM_RESIZE; DragHandle:=H; DragIdx:=I;
    GX1:=C^.X; GY1:=C^.Y; GX2:=C^.X+C^.W; GY2:=C^.Y+C^.H;
    ClearHover; Exit;
   End;
  End Else If C^.Kind=K_EDGE Then Begin
   EdgePath(I,Pl,Sd,Td);
   If Pl.N>=2 Then Begin
    { extremites }
    If (Abs(X-SX(Pl.P[0].X))<=5) And (Abs(Y-SY(Pl.P[0].Y))<=5) Then Begin
     DragMode:=DM_EDGEEND; DragEnd:=0; DragIdx:=I;
     GAx:=Pl.P[Pl.N-1].X; GAy:=Pl.P[Pl.N-1].Y; GPx:=Pl.P[0].X; GPy:=Pl.P[0].Y;
     Exit;
    End;
    If (Abs(X-SX(Pl.P[Pl.N-1].X))<=5) And (Abs(Y-SY(Pl.P[Pl.N-1].Y))<=5) Then Begin
     DragMode:=DM_EDGEEND; DragEnd:=1; DragIdx:=I;
     GAx:=Pl.P[0].X; GAy:=Pl.P[0].Y; GPx:=Pl.P[Pl.N-1].X; GPy:=Pl.P[Pl.N-1].Y;
     Exit;
    End;
    For K:=0 To C^.NPts-1 Do
     If (Abs(X-SX(C^.Pts[K].X))<=5) And (Abs(Y-SY(C^.Pts[K].Y))<=5) Then Begin
      DragMode:=DM_WAYPT; DragIdx:=I; WpIns:=K; NewWp:=False;
      If K>0 Then Begin GAx:=C^.Pts[K-1].X; GAy:=C^.Pts[K-1].Y; End Else Begin GAx:=Pl.P[0].X; GAy:=Pl.P[0].Y; End;
      If K<C^.NPts-1 Then Begin GBx:=C^.Pts[K+1].X; GBy:=C^.Pts[K+1].Y; End Else Begin GBx:=Pl.P[Pl.N-1].X; GBy:=Pl.P[Pl.N-1].Y; End;
      GPx:=C^.Pts[K].X; GPy:=C^.Pts[K].Y;
      Exit;
     End;
   End;
  End;
 End;
 { Fleches de connexion }
 If HoverOn And (HoverIdx>0) Then Begin
  For K:=0 To 3 Do Begin
   ArrowPos(HoverIdx,K,Ax,Ay);
   If (Abs(X-Ax)<=7) And (Abs(Y-Ay)<=7) Then Begin
    DragMode:=DM_CONNECT; DragIdx:=HoverIdx; ConnDir:=K;
    SidePoint(HoverIdx,K,GAx,GAy);
    GPx:=Dxd; GPy:=Dyd;
    ClearHover;
    Exit;
   End;
  End;
 End;
 { Objet sous le curseur }
 I:=HitCellAt(Dxd,Dyd,False);
 If I>0 Then Begin
  If EvDbl Then Begin StartEdit(I,'',False); Exit; End;
  Tg:=GroupTarget(I);
  If ShiftHeld Then Begin
   Cells[Tg]^.Sel:=Not Cells[Tg]^.Sel;
   RedrawAll;
   Exit;
  End;
  { Un connecteur deja selectionne : glisser son corps cree un point de passage }
  If (SelCount=1) And Cells[I]^.Sel And (Cells[I]^.Kind=K_EDGE) And (Cells[I]^.NPts<MAX_PTS) Then Begin
   C:=Cells[I];
   EdgePath(I,Pl,Sd,Td);
   Best:=0; Bd:=999999;
   { segment le plus proche parmi S,W0..Wn,T }
   For K:=0 To C^.NPts Do Begin
    If K=0 Then Begin Ax:=Pl.P[0].X; Ay:=Pl.P[0].Y; End Else Begin Ax:=C^.Pts[K-1].X; Ay:=C^.Pts[K-1].Y; End;
    If K=C^.NPts Then Begin GBx:=Pl.P[Pl.N-1].X; GBy:=Pl.P[Pl.N-1].Y; End Else Begin GBx:=C^.Pts[K].X; GBy:=C^.Pts[K].Y; End;
    D:=SegDist(Dxd,Dyd,Ax,Ay,GBx,GBy);
    If D<Bd Then Begin Bd:=D; Best:=K; End;
   End;
   WpIns:=Best; NewWp:=True; DragMode:=DM_WAYPT; DragIdx:=I;
   If Best=0 Then Begin GAx:=Pl.P[0].X; GAy:=Pl.P[0].Y; End Else Begin GAx:=C^.Pts[Best-1].X; GAy:=C^.Pts[Best-1].Y; End;
   If Best=C^.NPts Then Begin GBx:=Pl.P[Pl.N-1].X; GBy:=Pl.P[Pl.N-1].Y; End Else Begin GBx:=C^.Pts[Best].X; GBy:=C^.Pts[Best].Y; End;
   GPx:=Dxd; GPy:=Dyd;
   Exit;
  End;
  If Not Cells[Tg]^.Sel Then Begin
   SelectOnly(Tg);
   ClearHover;
   RedrawAll;
  End;
  If Cells[Tg]^.Kind=K_VERTEX Then Begin
   DragMode:=DM_MOVE; PrimIdx:=Tg; OrgX:=Cells[Tg]^.X; OrgY:=Cells[Tg]^.Y; GDx:=0; GDy:=0;
  End Else Begin
   DragMode:=DM_MOVE; PrimIdx:=Tg; OrgX:=0; OrgY:=0; GDx:=0; GDy:=0;
  End;
  Exit;
 End;
 { Fond : selection par rectangle }
 If EvDbl Then Begin Exit; End;
 If (Not ShiftHeld) And (SelCount>0) Then Begin ClearSel; ClearHover; RedrawAll; End;
 DragMode:=DM_LASSO; GPx:=Dxd; GPy:=Dyd;
End;

Procedure CommitMove;
Var Dx0, Dy0: LongInt;
Begin
 Dx0:=GDx; Dy0:=GDy;
 If (Dx0=0) And (Dy0=0) Then Exit;
 UndoPush;
 MoveSelected(Dx0,Dy0);
 ReparentSelection;
 Touch;
End;

Procedure CommitResize;
Var C: PCell; X1, Y1, X2, Y2: LongInt;
Begin
 C:=Cells[DragIdx];
 X1:=GX1; Y1:=GY1; X2:=GX2; Y2:=GY2;
 If X2-X1<8 Then Begin If DragHandle In [0,6,7] Then X1:=X2-8 Else X2:=X1+8; End;
 If Y2-Y1<8 Then Begin If DragHandle In [0,1,2] Then Y1:=Y2-8 Else Y2:=Y1+8; End;
 If (X1=C^.X) And (Y1=C^.Y) And (X2-X1=C^.W) And (Y2-Y1=C^.H) Then Exit;
 UndoPush;
 C^.X:=X1; C^.Y:=Y1; C^.W:=X2-X1; C^.H:=Y2-Y1;
 Touch;
End;

Procedure CommitLasso;
Var X1, Y1, X2, Y2, A, B, C2, D, T: LongInt; I: Integer;
Begin
 X1:=DocX0; Y1:=DocY0; X2:=GPx; Y2:=GPy;
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
 For I:=1 To NCells Do Begin
  If (Cells[I]^.Kind=K_LAYER) Or (Not Visible(I)) Or IsEdgeLabel(I) Then Continue;
  CellBounds(I,A,B,C2,D);
  If (A>=X1) And (C2<=X2) And (B>=Y1) And (D<=Y2) Then Cells[I]^.Sel:=True;
 End;
End;

Procedure CommitConnect(X, Y: Integer);
Var T: Integer; Dxd, Dyd: LongInt;
Begin
 Dxd:=DX(X); Dyd:=DY(Y);
 T:=HitCellAt(Dxd,Dyd,True);
 If T=DragIdx Then Begin StatusMsg:=Tr('Connection to the same shape cancelled'); Exit; End;
 If (T=0) And (Not InCanvas(X,Y)) Then Exit;
 CreateEdge(DragIdx,T,ConnDir,SnapV(Dxd),SnapV(Dyd));
End;

Procedure CommitEdgeEnd(X, Y: Integer);
Var T: Integer; C: PCell; Dxd, Dyd: LongInt;
Begin
 Dxd:=DX(X); Dyd:=DY(Y);
 T:=HitCellAt(Dxd,Dyd,True);
 C:=Cells[DragIdx];
 UndoPush;
 If DragEnd=0 Then Begin
  If T>0 Then Begin C^.Source:=Cells[T]^.Id; C^.HasSrc:=False; StyDelLocal(C,'exitX'); End
  Else Begin C^.Source:=''; C^.SrcPt.X:=SnapV(Dxd); C^.SrcPt.Y:=SnapV(Dyd); C^.HasSrc:=True; StyDelLocal(C,'exitX'); End;
 End Else Begin
  If T>0 Then Begin C^.Target:=Cells[T]^.Id; C^.HasTgt:=False; StyDelLocal(C,'entryX'); End
  Else Begin C^.Target:=''; C^.TgtPt.X:=SnapV(Dxd); C^.TgtPt.Y:=SnapV(Dyd); C^.HasTgt:=True; StyDelLocal(C,'entryX'); End;
 End;
 ResolveLinks;
 Touch;
End;

Procedure CommitWaypoint;
Var C: PCell; K: Integer;
Begin
 C:=Cells[DragIdx];
 UndoPush;
 If NewWp Then Begin
  For K:=C^.NPts DownTo WpIns+1 Do C^.Pts[K]:=C^.Pts[K-1];
  C^.Pts[WpIns].X:=GPx; C^.Pts[WpIns].Y:=GPy;
  Inc(C^.NPts);
 End Else Begin
  C^.Pts[WpIns].X:=GPx; C^.Pts[WpIns].Y:=GPy;
 End;
 Touch;
End;

Procedure HandleLDown;
Var X, Y, H, K, Id, Act: Integer; P1: LongInt; Wasn: Boolean;
Begin
 X:=EvX; Y:=EvY;
 StatusMsg:='';
 If Editing Then EndEdit(True);
 If MenuOpen Then Begin
  K:=MenuItemAt(X,Y);
  If K>=0 Then Begin
   If Not Menus[ActiveMenu].Items[K].Sep Then Begin
    Id:=Menus[ActiveMenu].Items[K].Id;
    MenuOpen:=False;
    DoCommand(Id);
   End;
   Exit;
  End;
  H:=FindHit(X,Y);
  If (H>=0) And (Hits[H].Act=A_MENU) And (Hits[H].P1<>ActiveMenu) Then Begin
   ActiveMenu:=Hits[H].P1; ActiveItem:=-1; RedrawAll;
  End Else Begin MenuOpen:=False; RedrawAll; End;
  Exit;
 End;
 Wasn:=SearchFocus;
 SearchFocus:=False;
 H:=FindHit(X,Y);
 If H>=0 Then Begin
  Act:=Hits[H].Act; P1:=Hits[H].P1;
  Case Act Of
   A_MENU: Begin MenuOpen:=True; ActiveMenu:=Integer(P1); ActiveItem:=-1; RedrawAll; End;
   A_TOOL: ToolAction(Integer(P1));
   A_PALITEM: Begin
    DragMode:=DM_PAL; DragDef:=Integer(P1); DragX0:=X; DragY0:=Y; DragMoved:=False; GhostOn:=False;
    RedrawAll;
   End;
   A_PALHEAD: Begin PalOpen[P1]:=Not PalOpen[P1]; PalScroll:=0; RedrawAll; End;
   A_PALSCROLL: Begin
    PalScroll:=PalScroll+Integer(P1)*24;
    If PalScroll<0 Then PalScroll:=0;
    If PalScroll>PalTotal Then PalScroll:=Max(0,PalTotal-24);
    RedrawAll;
   End;
   A_SEARCH: Begin SearchFocus:=True; PalScroll:=0; RedrawAll; End;
   A_TAB: Begin FmtTab:=Integer(P1); RedrawAll; End;
   A_PRESET: Begin ApplyPreset(Integer(P1)); RedrawAll; End;
   A_CHECK: Begin ToggleCheck(Integer(P1)); RedrawAll; End;
   A_COLOR: Begin PickColor(Integer(P1)); RedrawAll; End;
   A_SPIN: Begin SpinApply(Integer(P1),Integer(Hits[H].P2)); RedrawAll; End;
   A_SPINEDIT: Begin SpinEdit(Integer(P1)); RedrawAll; End;
   A_BTN: ButtonAction(Integer(P1));
   A_DROP: Begin DropAction(Integer(P1),Hits[H].X1,Hits[H].Y2+1); RedrawAll; End;
   A_PAGE: Begin
    If P1<0 Then AddPage Else Begin
     If EvDbl And (P1=CurPage) Then Begin RenamePage; RedrawAll; End Else SwitchPage(Integer(P1));
    End;
   End;
  End;
  Exit;
 End;
 If Wasn Then RedrawAll;
 If InCanvas(X,Y) Then CanvasDown(X,Y);
End;

Procedure HandleMove;
Var X, Y, I, K: Integer; Dxd, Dyd, Rx, Ry, Nx, Ny: LongInt; H: Integer; C: PCell; Keep: Boolean;
    T: String;
Begin
 X:=EvX; Y:=EvY;
 If MenuOpen Then Begin
  K:=MenuItemAt(X,Y);
  If K<>ActiveItem Then Begin
   If K>=0 Then If Menus[ActiveMenu].Items[K].Sep Then K:=-1;
   If K<>ActiveItem Then Begin ActiveItem:=K; DrawMenuDrop; End;
  End;
  H:=FindHit(X,Y);
  If (H>=0) And (Hits[H].Act=A_MENU) And (Hits[H].P1<>ActiveMenu) Then Begin
   ActiveMenu:=Hits[H].P1; ActiveItem:=-1; RedrawAll;
  End;
  Exit;
 End;
 If Editing Then Exit;
 If (Abs(X-DragX0)>2) Or (Abs(Y-DragY0)>2) Then DragMoved:=True;
 Dxd:=DX(X); Dyd:=DY(Y);
 Case DragMode Of
  DM_NONE: Begin
   If InCanvas(X,Y) Then Begin
    T:='x: '+IStr(Dxd)+'  y: '+IStr(Dyd);
    HideMouse;
    DBar(SCR_W-260,SCR_H-STAT_H+2,SCR_W-60,SCR_H-3,C_PANEL);
    DText(SCR_W-260,SCR_H-STAT_H+4,T,C_DARK);
    ShowMouse;
    { Fleches de connexion au survol }
    If (SelCount<=1) Then Begin
     Keep:=False;
     If HoverOn And (HoverIdx>0) Then Begin
      C:=Cells[HoverIdx];
      If (X>=SX(C^.X)-22) And (X<=SX(C^.X+C^.W)+22) And (Y>=SY(C^.Y)-22) And (Y<=SY(C^.Y+C^.H)+22) Then Keep:=True;
     End;
     If Not Keep Then Begin
      I:=HitCellAt(Dxd,Dyd,True);
      If (I>0) And ((IsGroup(I)) Or (CellShape(I)=SH_TEXT)) Then I:=0;
      If I<>HoverIdx Then Begin
       ClearHover;
       If I>0 Then Begin HoverIdx:=I; HoverOn:=True; DrawHoverArrows(I); End;
      End;
     End;
    End;
   End Else If HoverOn Then ClearHover;
  End;
  DM_PAN: Begin
   ViewX:=PanVX-((X-DragX0)*100) Div Zoom;
   ViewY:=PanVY-((Y-DragY0)*100) Div Zoom;
   DrawCanvas;
  End;
  DM_MOVE: If DragMoved Then Begin
   EraseGhost;
   Rx:=Dxd-DocX0; Ry:=Dyd-DocY0;
   If Cells[PrimIdx]^.Kind=K_VERTEX Then Begin
    GDx:=SnapV(OrgX+Rx)-OrgX; GDy:=SnapV(OrgY+Ry)-OrgY;
   End Else Begin GDx:=Rx; GDy:=Ry; End;
   ShowGhost;
  End;
  DM_RESIZE: If DragMoved Then Begin
   EraseGhost;
   C:=Cells[DragIdx];
   Nx:=SnapV(Dxd); Ny:=SnapV(Dyd);
   GX1:=C^.X; GY1:=C^.Y; GX2:=C^.X+C^.W; GY2:=C^.Y+C^.H;
   Case DragHandle Of
    0,6,7: GX1:=Nx;
    2,3,4: GX2:=Nx;
   End;
   Case DragHandle Of
    0,1,2: GY1:=Ny;
    4,5,6: GY2:=Ny;
   End;
   If StyBool(C^.Style,'aspect',False) Or (StyStr(C^.Style,'aspect','')='fixed') Then Begin
    If (DragHandle In [0,2,4,6]) And (C^.W>0) Then Begin
     If DragHandle In [0,2] Then GY1:=GY2-(GX2-GX1)*C^.H Div C^.W
     Else GY2:=GY1+(GX2-GX1)*C^.H Div C^.W;
    End;
   End;
   ShowGhost;
  End;
  DM_LASSO: If DragMoved Then Begin
   EraseGhost; GPx:=Dxd; GPy:=Dyd; ShowGhost;
  End;
  DM_CONNECT: Begin
   EraseGhost; GPx:=Dxd; GPy:=Dyd; ShowGhost;
  End;
  DM_EDGEEND,DM_WAYPT: Begin
   EraseGhost; GPx:=SnapV(Dxd); GPy:=SnapV(Dyd);
   If DragMode=DM_EDGEEND Then Begin GPx:=Dxd; GPy:=Dyd; End;
   ShowGhost;
  End;
  DM_PAL: If DragMoved Then Begin
   EraseGhost;
   If InCanvas(X,Y) Then Begin GPx:=Dxd; GPy:=Dyd; ShowGhost; End;
  End;
 End;
End;

Procedure HandleLUp;
Var X, Y, D: Integer; Dxd, Dyd, Px, Py: LongInt;
Begin
 X:=EvX; Y:=EvY;
 Dxd:=DX(X); Dyd:=DY(Y);
 EraseGhost;
 Case DragMode Of
  DM_MOVE: If DragMoved Then Begin CommitMove; RedrawAll; End;
  DM_RESIZE: If DragMoved Then Begin CommitResize; RedrawAll; End;
  DM_LASSO: Begin
   If DragMoved Then Begin GPx:=Dxd; GPy:=Dyd; CommitLasso; End;
   RedrawAll;
  End;
  DM_CONNECT: If DragMoved Then Begin CommitConnect(X,Y); RedrawAll; End;
  DM_EDGEEND: If DragMoved Then Begin CommitEdgeEnd(X,Y); RedrawAll; End;
  DM_WAYPT: If DragMoved Then Begin CommitWaypoint; RedrawAll; End;
  DM_PAL: Begin
   D:=DragDef;
   If InCanvas(X,Y) And DragMoved Then Begin
    Px:=SnapV(Dxd-ShapeDefs[D].W Div 2); Py:=SnapV(Dyd-ShapeDefs[D].H Div 2);
    If ShapeDefs[D].Sec=3 Then Begin Px:=SnapV(Dxd-40); Py:=SnapV(Dyd); End;
    InsertDef(D,Px,Py);
    RedrawAll;
   End Else If Not DragMoved Then Begin
    FreeSpot(D,Px,Py);
    InsertDef(D,Px,Py);
    RedrawAll;
   End Else RedrawAll;
  End;
 End;
 DragMode:=DM_NONE;
End;

{ ------------------------------------------------------------------------- }

Procedure HandleEditKey;
Var K, P, Col, Ls, Le: Integer;
Begin
 If EvExt Then Begin
  Case EvKey Of
   #72,#80: Begin
    { Haut / bas : meme colonne sur la ligne voisine }
    P:=EditPos; Ls:=P;
    While (Ls>0) And (EditText[Ls]<>#10) Do Dec(Ls);
    Col:=P-Ls;
    If EvKey=#72 Then Begin
     If Ls>0 Then Begin
      Le:=Ls-1; K:=Le;
      While (K>0) And (EditText[K]<>#10) Do Dec(K);
      EditPos:=K+Min(Col,Le-K);
     End;
    End Else Begin
     Le:=P+1;
     While (Le<=Length(EditText)) And (EditText[Le]<>#10) Do Inc(Le);
     If Le<=Length(EditText) Then Begin
      K:=Le+1;
      While (K<=Length(EditText)) And (EditText[K]<>#10) Do Inc(K);
      EditPos:=Le+Min(Col,K-Le-1);
     End;
    End;
   End;
  Else LineEditKey(EditText,EditPos,120);
  End;
 End Else Begin
  Case EvKey Of
   #13: Begin
    If Length(EditText)<119 Then Begin Insert(#10,EditText,EditPos+1); Inc(EditPos); End;
   End;
   #10: Begin EndEdit(True); Exit; End;
   #27: Begin EndEdit(True); Exit; End;
  Else LineEditKey(EditText,EditPos,120);
  End;
 End;
 DrawEditOverlay;
End;

Procedure HandleKey;
Var K: Char; Step: LongInt; I: Integer; Dx0, Dy0: LongInt; Id: Integer; S: String;
Begin
 K:=EvKey;
 StatusMsg:='';
 If Editing Then Begin HandleEditKey; Exit; End;
 { Pendant un glisser-deposer, seule la touche Echap est prise en compte }
 If DragMode<>DM_NONE Then Begin
  If (Not EvExt) And (K=#27) Then Begin
   EraseGhost; DragMode:=DM_NONE; DragMoved:=False; RedrawAll;
  End;
  Exit;
 End;
 { Zone de recherche }
 If SearchFocus Then Begin
  If EvExt Then Begin
   If EvKey=#83 Then SearchText:='';
  End Else Begin
   If (K=#27) Or (K=#13) Then SearchFocus:=False
   Else Begin
    S:=SearchText; I:=Length(S);
    If K=#8 Then Begin If I>0 Then Delete(S,I,1); End
    Else If (K>=' ') And (I<30) Then S:=S+K;
    SearchText:=S;
   End;
  End;
  PalScroll:=0;
  RedrawAll;
  Exit;
 End;
 { Menu ouvert : navigation au clavier }
 If MenuOpen Then Begin
  If EvExt Then Begin
   Case K Of
    #72: Begin
     I:=ActiveItem;
     Repeat Dec(I); If I<0 Then I:=Menus[ActiveMenu].N-1; Until Not Menus[ActiveMenu].Items[I].Sep;
     ActiveItem:=I; DrawMenuDrop;
    End;
    #80: Begin
     I:=ActiveItem;
     Repeat Inc(I); If I>=Menus[ActiveMenu].N Then I:=0; Until Not Menus[ActiveMenu].Items[I].Sep;
     ActiveItem:=I; DrawMenuDrop;
    End;
    #75: Begin ActiveMenu:=(ActiveMenu+NMENUS-1) Mod NMENUS; ActiveItem:=-1; RedrawAll; End;
    #77: Begin ActiveMenu:=(ActiveMenu+1) Mod NMENUS; ActiveItem:=-1; RedrawAll; End;
   End;
   Exit;
  End;
  If K=#13 Then Begin
   If (ActiveItem>=0) And Not Menus[ActiveMenu].Items[ActiveItem].Sep Then Begin
    Id:=Menus[ActiveMenu].Items[ActiveItem].Id;
    MenuOpen:=False;
    DoCommand(Id);
   End;
   Exit;
  End;
  If K=#27 Then Begin MenuOpen:=False; RedrawAll; End;
  Exit;
 End;
 If EvExt Then Begin
  For I:=0 To NMENUS-1 Do
   If K=Chr(AltKeys[I]) Then Begin
    MenuOpen:=True; ActiveMenu:=I; ActiveItem:=-1; RedrawAll; Exit;
   End;
  Case K Of
   #68: Begin MenuOpen:=True; ActiveMenu:=MENU_FILE; ActiveItem:=-1; RedrawAll; End;
      #59: DoCommand(CM_KEYS);
   #60: DoCommand(CM_EDITLABEL);
   #66: DoCommand(CM_SNAP);
   #67: DoCommand(CM_GRID);
   #83: DoCommand(CM_DELETE);
   #82: Begin MultiMode:=Not MultiMode; If MultiMode Then StatusMsg:=Tr('Multi-select ON') Else StatusMsg:=Tr('Multi-select OFF'); RedrawAll; End;
   #71: DoCommand(CM_Z100);
   #79: DoCommand(CM_ZFIT);
   #73: If NPages>1 Then DoCommand(CM_PREVPAGE) Else Begin ViewY:=ViewY-((CY2-CY1)*100 Div Zoom) Div 2; RedrawAll; End;
   #81: If NPages>1 Then DoCommand(CM_NEXTPAGE) Else Begin ViewY:=ViewY+((CY2-CY1)*100 Div Zoom) Div 2; RedrawAll; End;
   #72,#80,#75,#77: Begin
    If SelCount>0 Then Begin
     Step:=1;
     If ShiftHeld Then Step:=GridSize;
     Dx0:=0; Dy0:=0;
     Case K Of #72: Dy0:=-Step; #80: Dy0:=Step; #75: Dx0:=-Step; #77: Dx0:=Step; End;
     UndoPush; MoveSelected(Dx0,Dy0); Touch;
    End Else Begin
     Step:=Max(8,50*100 Div Zoom);
     Case K Of #72: ViewY:=ViewY-Step; #80: ViewY:=ViewY+Step; #75: ViewX:=ViewX-Step; #77: ViewX:=ViewX+Step; End;
    End;
    RedrawAll;
   End;
  End;
  Exit;
 End;
 Case K Of
  #1: DoCommand(CM_SELALL);
  #3: DoCommand(CM_COPY);
  #4: DoCommand(CM_DUP);
  #5: DoCommand(CM_EDITSTYLE);
  #6: DoCommand(CM_FRONT);
  #2: DoCommand(CM_BACK);
  #7: DoCommand(CM_GROUP);
  #21: DoCommand(CM_UNGROUP);
  #14: DoCommand(CM_NEW);
  #15: DoCommand(CM_OPEN);
  #17: DoCommand(CM_QUIT);
  #19: DoCommand(CM_SAVE);
  #22: DoCommand(CM_PASTE);
  #24: DoCommand(CM_CUT);
  #25: DoCommand(CM_REDO);
  #26: DoCommand(CM_UNDO);
  #9: Begin NextShape; RedrawAll; End;
  #27: Begin
   If SelCount>0 Then Begin ClearSel; RedrawAll; End;
  End;
  #13: If FirstSel>0 Then DoCommand(CM_EDITLABEL);
  #8: DoCommand(CM_DELETE);
  '+','=': DoCommand(CM_ZIN);
  '-': DoCommand(CM_ZOUT);
  Else If K>=#32 Then Begin
   { Frappe directe : edition de l'etiquette de l'objet selectionne }
   If (FirstSel>0) And (SelCount=1) Then Begin
    S:=CPToU8(K);
    StartEdit(FirstSel,S,True);
   End;
  End;
 End;
End;

Procedure HandleRDown;
Begin
 If MenuOpen Then Begin MenuOpen:=False; RedrawAll; Exit; End;
 If InCanvas(EvX,EvY) Then Begin
  If Editing Then EndEdit(True);
  DragMode:=DM_PAN; DragX0:=EvX; DragY0:=EvY; PanVX:=ViewX; PanVY:=ViewY; DragMoved:=False;
  ClearHover;
 End;
End;

{ Menu contextuel (clic droit sans deplacement) }
Procedure ContextMenu(X, Y: Integer);
Var I, R: Integer; Id: Integer;
Begin
 I:=HitCellAt(DX(X),DY(Y),False);
 If I>0 Then Begin
  I:=GroupTarget(I);
  If Not Cells[I]^.Sel Then Begin SelectOnly(I); RedrawAll; End;
 End;
 Id:=0;
 If SelCount>0 Then Begin
  R:=PopupList(X,Y,Tr('Edit Label|Edit Style...|Copy|Cut|Duplicate|Delete|To Front|To Back|Group|Ungroup'),-1);
  Case R Of
   0: Id:=CM_EDITLABEL; 1: Id:=CM_EDITSTYLE; 2: Id:=CM_COPY; 3: Id:=CM_CUT; 4: Id:=CM_DUP;
   5: Id:=CM_DELETE; 6: Id:=CM_FRONT; 7: Id:=CM_BACK; 8: Id:=CM_GROUP; 9: Id:=CM_UNGROUP;
  End;
 End Else Begin
  R:=PopupList(X,Y,Tr('Paste|Select All|Fit to Window|Reset Zoom|Add Page'),-1);
  Case R Of
   0: Id:=CM_PASTE; 1: Id:=CM_SELALL; 2: Id:=CM_ZFIT; 3: Id:=CM_Z100; 4: Id:=CM_ADDPAGE;
  End;
 End;
 If Id>0 Then DoCommand(Id);
End;

Procedure HandleRUp;
Begin
 If DragMode=DM_PAN Then Begin
  DragMode:=DM_NONE;
  If DragMoved Then RedrawAll Else ContextMenu(EvX,EvY);
 End;
End;

{ ========================================================================== }
{                              PROGRAMME PRINCIPAL                           }
{ ========================================================================== }

Procedure InitApp;
Var I: Integer;
Begin
 NCells:=0; IdCounter:=0; GridOn:=True; SnapOn:=True; GridSize:=10; BgColor:=-1;
 Modified:=False; FileName:=''; CompressedSave:=False; PageName:='Page-1';
 NPages:=1; CurPage:=0; Pages[0].Name:='Page-1'; PageTag:='P';
 ShowLeft:=True; ShowRight:=True; FmtTab:=0;
 For I:=0 To NSEC-1 Do PalOpen[I]:=(I=0) Or (I=3);
 PalScroll:=0; SearchText:=''; SearchFocus:=False;
 MenuOpen:=False; ActiveMenu:=0; ActiveItem:=-1; StatusMsg:='';
 DefaultEdgeStyle:=0; BuildDefaultEdgeStyle; DefaultVStyle:=''; StyleClip:='';
 Zoom:=100; ViewX:=-20; ViewY:=-20;
 Editing:=False; EditHide:=0; EditCell:=0; InsertCount:=0; PasteCount:=0;
 DragMode:=DM_NONE; GhostOn:=False; HoverOn:=False; HoverIdx:=0; MultiMode:=False;
 OldMX:=-1; OldMY:=-1; OldMB:=0; LastClickT:=-10000;
 ResetUndo;
 InitLanguage;
 InitTempDir; InitTmp; InitMenus;
End;


Procedure LoadStartupFile;
Var Nm: String;
Begin
 If ParamCount>=1 Then Begin
  Nm:=ParamStr(1);
  If FileExists(Nm) Then Begin
   Layout;
   DoLoad(Nm);
     End;
 End;
End;

Procedure MainLoop;
Var Ev: Integer;
Begin
 Layout;
 RedrawAll;
 While Running Do Begin
  Ev:=PollEvent;
  Case Ev Of
   EV_KEY: HandleKey;
   EV_LDOWN: HandleLDown;
   EV_LUP: HandleLUp;
   EV_MOVE: HandleMove;
   EV_RDOWN: HandleRDown;
   EV_RUP: HandleRUp;
  End;
  If Editing And (Ev=EV_LDOWN) Then ;
 End;
End;

BEGIN
 InitializeGraphics;
 SetupPalette;
 InitApp;
 Running:=True;
 Layout;
 LoadStartupFile;
 MainLoop;
 CleanTemp;
 CloseGraph;
END.
