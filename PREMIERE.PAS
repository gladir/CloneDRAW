{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application PREMIERE
}

Program PREMIERE;

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$R-}
{$ELSE}
 {$M 20480,0,655360}
 {$R-,S-}
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
  { Pas d'implémentation pour Free Pascal }
 End;

 Procedure HideMouse;
 Begin
  { Pas d'implémentation pour Free Pascal }
 End;
{$ENDIF}

{ ====================================================================== }
{  Constantes de l'application                                           }
{ ====================================================================== }

Const
 SW = 640;            { Largeur de l'ecran }
 SH = 480;            { Hauteur de l'ecran }
 MENUH = 19;          { Hauteur de la barre de menus }

 { Dimensions de l'image des moniteurs (16:9) }
 VW = 284;
 VH = 160;

 MAXMEDIA = 24;       { Nombre maximal de medias dans le projet }
 MAXCLIPS = 150;      { Nombre maximal de clips dans la sequence }
 MAXMARK = 24;        { Nombre maximal de marqueurs }
 MAXUNDO = 10;        { Niveaux d'annulation }
 MAXIMG = 3;          { Images BMP importees }
 NTRK = 6;            { V1,V2,V3,A1,A2,A3 }

 { Panneau A (Source / Controles des effets) }
 AX1 = 2;   AY1 = 40;  AX2 = 319; AY2 = 250;
 { Panneau B (Moniteur du programme) }
 BX1 = 321; BY1 = 40;  BX2 = 637; BY2 = 250;
 { Panneau C (Projet / Effets / Marqueurs) }
 CX1 = 2;   CY1 = 253; CX2 = 212; CY2 = 461;
 { Outils }
 TX1 = 214; TY1 = 253; TX2 = 235; TY2 = 461;
 { Chronologie }
 LX1 = 237; LY1 = 253; LX2 = 620; LY2 = 461;
 { Vumetres }
 MX1 = 622; MX2 = 637;

 { Zones internes de la chronologie }
 TLX0 = 299;          { Debut de la zone des pistes }
 TLX1 = 617;          { Fin de la zone des pistes }
 RULY1 = 273;         { Regle }
 RULY2 = 286;
 TRY0 = 288;          { Premiere piste }
 TRH = 26;            { Hauteur d'une piste }
 HSY1 = 446;          { Barre de defilement }
 HSY2 = 458;

 { Outils de montage }
 TL_SELECT = 0;
 TL_TRACKFWD = 1;
 TL_RIPPLE = 2;
 TL_RAZOR = 3;
 TL_HAND = 4;
 TL_ZOOM = 5;
 TL_TYPE = 6;

 { Types de medias }
 MK_BARS = 0;
 MK_GRAD = 1;
 MK_PLASMA = 2;
 MK_CHECK = 3;
 MK_COUNT = 4;
 MK_SOLID = 5;
 MK_TITLE = 6;
 MK_NOISE = 7;
 MK_WAVES = 8;
 MK_IMAGE = 9;
 MK_TONE = 20;
 MK_MELODY = 21;
 MK_PULSE = 22;

 { Indicateurs de clip }
 CF_MIRH = 1;
 CF_MIRV = 2;
 CF_INV = 4;
 CF_OFF = 8;

 { Indicateurs de piste }
 TF_HIDE = 1;
 TF_LOCK = 2;

 { Modes de glissement }
 DM_NONE = 0;
 DM_SCRUB = 1;
 DM_SCRUBP = 2;
 DM_SCRUBS = 3;
 DM_MOVE = 4;
 DM_TRIML = 5;
 DM_TRIMR = 6;
 DM_RIPL = 7;
 DM_RIPR = 8;
 DM_MARQUEE = 9;
 DM_HAND = 10;
 DM_SLIDER = 11;
 DM_MEDIA = 12;
 DM_EFFECT = 13;
 DM_HSCROLL = 14;

 NPRE = 10;           { Couleurs predefinies }
 NEFF = 16;           { Effets du catalogue }
 NGRP = 6;            { Groupes d'effets }

Type
 TMedia = Record
  Name: String[20];
  Kind: Integer;
  Dur: LongInt;
  Par: Integer;
  Img: Integer;
  Txt: String[22];
  Path: String[40];
 End;

 TClip = Record
  Trk: Integer;
  Med: Integer;
  Start, Dur, InPt: LongInt;
  Speed: Integer;
  Name: String[20];
  Opac, PosX, PosY, Scale, Br, Co, Sa, Mos: Integer;
  Fl: Integer;
  Vol: Integer;
  Mute: Boolean;
  TIn, TOut: Integer;
  TInL, TOutL: Integer;
  Sel: Boolean;
 End;

 TMarker = Record
  Pos: LongInt;
  Name: String[14];
 End;

 PProject = ^TProject;
 TProject = Record
  Name: String[24];
  Fps: Integer;
  NM, NC, NK: Integer;
  Media: Array[0..MAXMEDIA-1] Of TMedia;
  Clips: Array[0..MAXCLIPS-1] Of TClip;
  Marks: Array[0..MAXMARK-1] Of TMarker;
  InM, OutM: LongInt;
  TrkF: Array[0..NTRK-1] Of Integer;
 End;

 TImgBuf = Array[0..VW*VH-1] Of Byte;
 PImgBuf = ^TImgBuf;

 TLayer = Record
  K, M, Par: Integer;
  T, MDur: LongInt;
  Al: LongInt;
  PX, PY, Sc, Br, Co, Sa, Mos: LongInt;
  Fl: Integer;
  Fx, Tr: Boolean;
  WM: Integer;
  WP: LongInt;
  Dim: LongInt;
  TS, TX0, TY0: LongInt;
  TT: String[22];
  Cd: LongInt;
 End;

 TMenuItem = Record
  Cap: String[30];
  Sc: String[12];
  Id: Integer;
  Sep: Boolean;
 End;

 TMenu = Record
  Title: String[12];
  N: Integer;
  X, W: Integer;
  It: Array[0..17] Of TMenuItem;
 End;

Const
 PreR: Array[0..NPRE-1] Of Byte = (0,255,255,0,0,255,0,255,255,150);
 PreG: Array[0..NPRE-1] Of Byte = (0,255,0,200,0,255,255,0,150,150);
 PreB: Array[0..NPRE-1] Of Byte = (0,255,0,0,255,0,255,255,0,150);
 PreName: Array[0..NPRE-1] Of String[8] =
  ('Noir','Blanc','Rouge','Vert','Bleu','Jaune','Cyan','Magenta','Orange','Gris');

 { Palette VGA standard (16 couleurs) }
 PalR: Array[0..15] Of Byte = (0,0,0,0,170,170,170,170,85,85,85,85,255,255,255,255);
 PalG: Array[0..15] Of Byte = (0,0,170,170,0,0,85,170,85,85,255,255,85,85,255,255);
 PalB: Array[0..15] Of Byte = (0,170,0,170,0,170,0,170,85,255,85,255,85,255,85,255);

 Bayer: Array[0..3,0..3] Of Integer =
  ((0,8,2,10),(12,4,14,6),(3,11,1,9),(15,7,13,5));

 BarR: Array[0..6] Of Byte = (192,192,0,0,192,192,0);
 BarG: Array[0..6] Of Byte = (192,192,192,192,0,0,0);
 BarB: Array[0..6] Of Byte = (192,0,192,0,192,0,192);
 MidR: Array[0..6] Of Byte = (0,19,192,19,0,19,192);
 MidG: Array[0..6] Of Byte = (0,19,0,19,192,19,192);
 MidB: Array[0..6] Of Byte = (192,19,192,19,192,19,192);

 { Police 5x7 : A-Z, 0-9, - . : ! ? espace }
 Font57: Array[0..41,0..6] Of Byte = (
  ($0E,$11,$11,$1F,$11,$11,$11),($1E,$11,$11,$1E,$11,$11,$1E),
  ($0E,$11,$10,$10,$10,$11,$0E),($1E,$11,$11,$11,$11,$11,$1E),
  ($1F,$10,$10,$1E,$10,$10,$1F),($1F,$10,$10,$1E,$10,$10,$10),
  ($0E,$11,$10,$17,$11,$11,$0F),($11,$11,$11,$1F,$11,$11,$11),
  ($0E,$04,$04,$04,$04,$04,$0E),($07,$02,$02,$02,$02,$12,$0C),
  ($11,$12,$14,$18,$14,$12,$11),($10,$10,$10,$10,$10,$10,$1F),
  ($11,$1B,$15,$15,$11,$11,$11),($11,$19,$15,$13,$11,$11,$11),
  ($0E,$11,$11,$11,$11,$11,$0E),($1E,$11,$11,$1E,$10,$10,$10),
  ($0E,$11,$11,$11,$15,$12,$0D),($1E,$11,$11,$1E,$14,$12,$11),
  ($0F,$10,$10,$0E,$01,$01,$1E),($1F,$04,$04,$04,$04,$04,$04),
  ($11,$11,$11,$11,$11,$11,$0E),($11,$11,$11,$11,$11,$0A,$04),
  ($11,$11,$11,$15,$15,$1B,$11),($11,$11,$0A,$04,$0A,$11,$11),
  ($11,$11,$0A,$04,$04,$04,$04),($1F,$01,$02,$04,$08,$10,$1F),
  ($0E,$11,$13,$15,$19,$11,$0E),($04,$0C,$04,$04,$04,$04,$0E),
  ($0E,$11,$01,$02,$04,$08,$1F),($1E,$01,$01,$0E,$01,$01,$1E),
  ($02,$06,$0A,$12,$1F,$02,$02),($1F,$10,$1E,$01,$01,$11,$0E),
  ($06,$08,$10,$1E,$11,$11,$0E),($1F,$01,$02,$04,$08,$08,$08),
  ($0E,$11,$11,$0E,$11,$11,$0E),($0E,$11,$11,$0F,$01,$02,$0C),
  ($00,$00,$00,$1F,$00,$00,$00),($00,$00,$00,$00,$00,$0C,$0C),
  ($00,$0C,$0C,$00,$0C,$0C,$00),($04,$04,$04,$04,$04,$00,$04),
  ($0E,$11,$01,$02,$04,$00,$04),($00,$00,$00,$00,$00,$00,$00));

 { Catalogue des effets }
 GrpName: Array[0..NGRP-1] Of String[26] =
  ('Transformer','Correction des couleurs','Stylisation',
   'Transitions vidéo','Effets audio','Transitions audio');
 EffName: Array[0..NEFF-1] Of String[26] =
  ('Miroir horizontal','Miroir vertical','Zoom 150 %',
   'Luminosité et contraste','Noir et blanc','Inverser','Saturation accrue',
   'Mosaïque','Fondu enchaîné','Fondu au noir','Volet','Iris',
   'Gain +6 dB','Gain -6 dB','Muet','Fondu audio');
 EffGrp: Array[0..NEFF-1] Of Byte =
  (0,0,0,1,1,1,1,2,3,3,3,3,4,4,4,5);
 TrNames: Array[0..4] Of String[16] =
  ('Aucune','Fondu enchaîné','Fondu au noir','Volet','Iris');

 ToolKeys: String[8] = 'VABCHZT';
 ToolNames: Array[0..6] Of String[40] =
  ('Sélection (V)','Sélection de piste vers l''avant (A)',
   'Modification par ondulation (B)','Lame (C)','Main (H)','Zoom (Z)','Texte (T)');

 { Identifiants de commandes }
 CM_NEW = 100;  CM_OPEN = 101;  CM_SAVE = 102;  CM_SAVEAS = 103;
 CM_IMPORT = 104; CM_NEWITEM = 105; CM_EXPFRAME = 106; CM_EXPSEQ = 107;
 CM_EXPEDL = 108; CM_QUIT = 109;
 CM_UNDO = 200; CM_REDO = 201; CM_CUT = 202; CM_COPY = 203; CM_PASTE = 204;
 CM_DELETE = 205; CM_RIPDEL = 206; CM_DUP = 207; CM_SELALL = 208; CM_SELNONE = 209;
 CM_RENAME = 300; CM_SPEED = 301; CM_ENABLE = 302; CM_RESETFX = 303;
 CM_SPLIT = 304; CM_INSERT = 305; CM_OVERWRITE = 306; CM_VTRANS = 307;
 CM_ATRANS = 308; CM_NOTRANS = 309; CM_EDITTITLE = 310;
 CM_SEQSET = 400; CM_MARKIN = 401; CM_MARKOUT = 402; CM_CLEARIO = 403;
 CM_REMGAP = 404; CM_ZOOMIN = 405; CM_ZOOMOUT = 406; CM_ZOOMFIT = 407;
 CM_GOSTART = 408; CM_GOEND = 409; CM_NEXTEDIT = 410; CM_PREVEDIT = 411;
 CM_ADDMARK = 500; CM_NEXTMARK = 501; CM_PREVMARK = 502; CM_DELMARK = 503;
 CM_DELMARKS = 504;
 CM_QFULL = 600; CM_QHALF = 601; CM_QQUART = 602; CM_SAFE = 603;
 CM_WAVE = 604; CM_SNAP = 605; CM_AUDIO = 606; CM_LOOP = 607;
 CM_WS0 = 700;
 CM_TABS = 710; CM_TABCTL = 711; CM_TABPROJ = 712; CM_TABEFF = 713; CM_TABMARK = 714;
 CM_HELP = 800; CM_ABOUT = 801;

 WsNames: Array[0..4] Of String[12] =
  ('Assemblage','Montage','Couleur','Effets','Audio');

Var
 { Projet et historique }
 P: TProject;
 UndoStk: Array[0..MAXUNDO-1] Of PProject;
 RedoStk: Array[0..MAXUNDO-1] Of PProject;
 UndoCnt, RedoCnt: Integer;
 ClipBuf: Array[0..39] Of TClip;
 ClipCnt: Integer;
 ImgPool: Array[0..MAXIMG-1] Of PImgBuf;
 ProjFile: String;
 Modified: Boolean;

 { Souris et clavier }
 MX, MY, MB: LongInt;
 OldMB: LongInt;
 PressL, PressR, RelL: Boolean;
 LastClickT: LongInt;
 LastClickX, LastClickY: LongInt;
 DblClick: Boolean;

 { Etat de l'interface }
 Running: Boolean;
 Playhead: LongInt;
 ScrollF: LongInt;
 PPS: Integer;
 CurTool: Integer;
 TabA, TabC, WorkSp: Integer;
 SnapOn, WaveOn, SafeOn, AudioOn, LoopOn: Boolean;
 Quality: Integer;
 Playing: Boolean;
 PlayTarget: Integer;
 PlaySpeed: Integer;
 PlayT0: LongInt;
 PlayF0: LongInt;
 SrcMed: Integer;
 SrcPos, SrcIn, SrcOut: LongInt;
 ProjSel, ProjScroll: Integer;
 EffSel, EffScroll: Integer;
 GrpOpen: Array[0..NGRP-1] Of Boolean;
 MarkSel, MarkScroll: Integer;
 CtlScroll: Integer;
 StatusMsg: String;
 MsgT0: LongInt;
 LevelL, LevelR, PeakL, PeakR: Integer;
 SnapGuide: LongInt;
 LastTone: Integer;

 { Menus }
 Menus: Array[0..7] Of TMenu;
 MenuActive: Boolean;
 ActiveMenu, ActiveItem: Integer;

 { Glissement }
 DragMode: Integer;
 DragX0, DragY0: LongInt;
 DragF0: LongInt;
 DragRow0: Integer;
 DragClip: Integer;
 DragItem: Integer;
 DragMoved: Boolean;
 DragNow: LongInt;
 DragDT: Integer;
 DragSlider: Integer;
 MqX0, MqY0, MqX1, MqY1: LongInt;
 HandScroll0: LongInt;

 { Invalidation }
 NeedAll, NeedProg, NeedSrc, NeedTL, NeedMeters, NeedA, NeedC, NeedStatus: Boolean;

 { Rendu }
 SinTab: Array[0..255] Of Integer;
 Quant: Array[0..511] Of Byte;
 Lay: Array[0..2] Of TLayer;
 NLay, CL: Integer;
 CR, CG, CB, CA: LongInt;
 AR, AG, AB: LongInt;
 FpsCache: LongInt;

 { Dialogues }
 DlgItems: Array[0..31] Of String[40];
 DlgCount: Integer;
 FileList: Array[0..119] Of String[14];
 FileIsDir: Array[0..119] Of Boolean;
 FileCount: Integer;

{ ====================================================================== }
{  Utilitaires                                                           }
{ ====================================================================== }

Function Min(A, B: LongInt): LongInt;
Begin
 If A < B Then Min := A Else Min := B;
End;

Function Max(A, B: LongInt): LongInt;
Begin
 If A > B Then Max := A Else Max := B;
End;

Function Clamp(V, A, B: LongInt): LongInt;
Begin
 If V < A Then V := A;
 If V > B Then V := B;
 Clamp := V;
End;

Function IStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IStr := S;
End;

Function Pad(N: LongInt; W: Integer): String;
Var
 S: String;
Begin
 S := IStr(N);
 While Length(S) < W Do S := '0' + S;
 Pad := S;
End;

Function StrVal(S: String; Def: LongInt): LongInt;
Var
 V: LongInt;
 Code: Integer;
Begin
 While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
 While (Length(S) > 0) And (S[Length(S)] = ' ') Do Delete(S, Length(S), 1);
 Val(S, V, Code);
 If (Code <> 0) Or (S = '') Then StrVal := Def Else StrVal := V;
End;

Function UpStr(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'a') And (S[I] <= 'z') Then S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

{ Convertit les accents UTF-8 vers la page de code 437 de la police BIOS. }
Function Cv(S: String): String;
Var
 I, N: Integer;
 R: String;
 C, D: Byte;
Begin
 R := '';
 I := 1;
 N := Length(S);
 While I <= N Do Begin
  C := Ord(S[I]);
  If (C = $C3) And (I < N) Then Begin
   D := Ord(S[I + 1]);
   Inc(I, 2);
   Case D Of
    $A9: R := R + #130;
    $A8: R := R + #138;
    $AA: R := R + #136;
    $AB: R := R + #137;
    $A0: R := R + #133;
    $A2: R := R + #131;
    $A4: R := R + #132;
    $A7: R := R + #135;
    $B9: R := R + #151;
    $BB: R := R + #150;
    $BC: R := R + #129;
    $AE: R := R + #140;
    $AF: R := R + #139;
    $B4: R := R + #147;
    $B6: R := R + #148;
    $89: R := R + #144;
    $87: R := R + #128;
    $80, $82: R := R + 'A';
    $88, $8A: R := R + 'E';
    $97: R := R + 'x';
   Else R := R + '?';
   End;
  End
  Else If (C = $C2) And (I < N) Then Begin
   D := Ord(S[I + 1]);
   Inc(I, 2);
   Case D Of
    $B0: R := R + #248;
    $AB: R := R + #174;
    $BB: R := R + #175;
    $B7: R := R + #250;
   Else R := R + ' ';
   End;
  End
  Else If (C = $E2) And (I + 1 < N) Then Begin
   Inc(I, 3);
   R := R + '.';
  End
  Else Begin
   R := R + S[I];
   Inc(I);
  End;
 End;
 Cv := R;
End;

Function TW(S: String): Integer;
Begin
 TW := TextWidth(Cv(S));
End;

Procedure Txt(X, Y: Integer; S: String; C: Integer);
Begin
 SetColor(C);
 OutTextXY(X, Y, Cv(S));
End;

Procedure TxtR(X, Y: Integer; S: String; C: Integer);
Begin
 Txt(X - TW(S), Y, S, C);
End;

Procedure TxtC(X, Y: Integer; S: String; C: Integer);
Begin
 Txt(X - TW(S) Div 2, Y, S, C);
End;

{ Tronque une chaine pour qu'elle tienne en W pixels. }
Function Fit(S: String; W: Integer): String;
Var
 N: Integer;
Begin
 N := W Div 8;
 If N < 0 Then N := 0;
 If Length(Cv(S)) > N Then Begin
  While (Length(S) > 0) And (Length(Cv(S)) > N) Do Delete(S, Length(S), 1);
 End;
 Fit := S;
End;

Procedure FillR(X1, Y1, X2, Y2, C: Integer);
Begin
 SetFillStyle(SolidFill, C);
 Bar(X1, Y1, X2, Y2);
End;

Procedure Frame(X1, Y1, X2, Y2, C: Integer);
Begin
 SetColor(C);
 Rectangle(X1, Y1, X2, Y2);
End;

Procedure HLine(X1, X2, Y, C: Integer);
Begin
 SetColor(C);
 Line(X1, Y, X2, Y);
End;

Procedure VLine(X, Y1, Y2, C: Integer);
Begin
 SetColor(C);
 Line(X, Y1, X, Y2);
End;

Function InRect(X, Y, X1, Y1, X2, Y2: LongInt): Boolean;
Begin
 InRect := (X >= X1) And (X <= X2) And (Y >= Y1) And (Y <= Y2);
End;

{ Bouton en relief sombre }
Procedure Btn(X1, Y1, X2, Y2: Integer; Down: Boolean);
Begin
 FillR(X1, Y1, X2, Y2, DarkGray);
 If Down Then Begin
  HLine(X1, X2, Y1, Black); VLine(X1, Y1, Y2, Black);
  HLine(X1, X2, Y2, LightGray); VLine(X2, Y1, Y2, LightGray);
 End Else Begin
  HLine(X1, X2, Y1, LightGray); VLine(X1, Y1, Y2, LightGray);
  HLine(X1, X2, Y2, Black); VLine(X2, Y1, Y2, Black);
 End;
End;

Function FDiv(A, B: LongInt): LongInt;
Begin
 If A >= 0 Then FDiv := A Div B Else FDiv := -((-A + B - 1) Div B);
End;

{ Temps en centiemes de seconde depuis minuit }
Function Ticks: LongInt;
Var
 H, M, S, C: Word;
Begin
 GetTime(H, M, S, C);
 Ticks := ((LongInt(H) * 60 + M) * 60 + S) * 100 + C;
End;

Function TickDiff(Now0, Then0: LongInt): LongInt;
Var
 D: LongInt;
Begin
 D := Now0 - Then0;
 If D < 0 Then D := D + 8640000;
 TickDiff := D;
End;

{ Code temporel HH:MM:SS:FF }
Function TC(F: LongInt): String;
Var
 Fp, S, M, H: LongInt;
 Neg: Boolean;
Begin
 Fp := P.Fps;
 If Fp < 1 Then Fp := 25;
 Neg := F < 0;
 If Neg Then F := -F;
 S := F Div Fp;
 H := S Div 3600;
 M := (S Div 60) Mod 60;
 S := S Mod 60;
 TC := Pad(H, 2) + ':' + Pad(M, 2) + ':' + Pad(S, 2) + ':' + Pad(F Mod Fp, 2);
End;

Function TCShort(F: LongInt): String;
Var
 S, M, H: LongInt;
Begin
 S := F Div P.Fps;
 H := S Div 3600;
 M := (S Div 60) Mod 60;
 S := S Mod 60;
 If H > 0 Then TCShort := IStr(H) + ':' + Pad(M, 2) + ':' + Pad(S, 2)
 Else TCShort := IStr(M) + ':' + Pad(S, 2);
End;

{ Parsing de lignes de projet }
Function TakeField(Var S: String): String;
Var
 K: Integer;
Begin
 K := Pos('|', S);
 If K = 0 Then Begin
  TakeField := S;
  S := '';
 End Else Begin
  TakeField := Copy(S, 1, K - 1);
  Delete(S, 1, K);
 End;
End;

Function TakeNum(Var S: String): LongInt;
Var
 K: Integer;
 T: String;
Begin
 While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
 K := Pos(' ', S);
 If K = 0 Then Begin
  T := S;
  S := '';
 End Else Begin
  T := Copy(S, 1, K - 1);
  Delete(S, 1, K);
 End;
 TakeNum := StrVal(T, 0);
End;

{ ====================================================================== }
{  Modele du projet : medias, clips, selection, historique               }
{ ====================================================================== }

Function MediaAudio(M: Integer): Boolean;
Begin
 MediaAudio := (M >= 0) And (P.Media[M].Kind >= 20);
End;

Function MediaUnlimited(M: Integer): Boolean;
Var
 K: Integer;
Begin
 K := P.Media[M].Kind;
 MediaUnlimited := (K = MK_SOLID) Or (K = MK_TITLE) Or (K = MK_IMAGE);
End;

Function MediaMax(M: Integer): LongInt;
Begin
 If MediaUnlimited(M) Then MediaMax := 1000000 Else MediaMax := P.Media[M].Dur;
End;

Function KindName(K: Integer): String;
Begin
 Case K Of
  MK_BARS: KindName := 'Barres de couleur';
  MK_GRAD: KindName := 'Dégradé animé';
  MK_PLASMA: KindName := 'Plasma';
  MK_CHECK: KindName := 'Damier';
  MK_COUNT: KindName := 'Compte à rebours';
  MK_SOLID: KindName := 'Couleur unie';
  MK_TITLE: KindName := 'Titre';
  MK_NOISE: KindName := 'Neige';
  MK_WAVES: KindName := 'Ondes';
  MK_IMAGE: KindName := 'Image BMP';
  MK_TONE: KindName := 'Tonalité';
  MK_MELODY: KindName := 'Mélodie';
  MK_PULSE: KindName := 'Impulsions';
 Else KindName := 'Média';
 End;
End;

Function ClipEnd(I: Integer): LongInt;
Begin
 ClipEnd := P.Clips[I].Start + P.Clips[I].Dur;
End;

Function IsVideoTrack(T: Integer): Boolean;
Begin
 IsVideoTrack := T < 3;
End;

Function TrackName(T: Integer): String;
Begin
 If T < 3 Then TrackName := 'V' + IStr(T + 1) Else TrackName := 'A' + IStr(T - 2);
End;

Function TrackRow(T: Integer): Integer;
Begin
 If T < 3 Then TrackRow := 2 - T Else TrackRow := T;
End;

Function RowTrack(R: Integer): Integer;
Begin
 If R <= 2 Then RowTrack := 2 - R Else RowTrack := R;
End;

Function FindClip(T: Integer; F: LongInt): Integer;
Var
 I: Integer;
Begin
 FindClip := -1;
 For I := 0 To P.NC - 1 Do
  If (P.Clips[I].Trk = T) And (F >= P.Clips[I].Start) And (F < ClipEnd(I)) Then Begin
   FindClip := I;
   Exit;
  End;
End;

Function SeqEnd: LongInt;
Var
 I: Integer;
 E: LongInt;
Begin
 E := 0;
 For I := 0 To P.NC - 1 Do
  If ClipEnd(I) > E Then E := ClipEnd(I);
 SeqEnd := E;
End;

Procedure DelClip(I: Integer);
Var
 J: Integer;
Begin
 If (I < 0) Or (I >= P.NC) Then Exit;
 For J := I To P.NC - 2 Do P.Clips[J] := P.Clips[J + 1];
 Dec(P.NC);
End;

Function AddClipRec(Var C: TClip): Integer;
Begin
 If P.NC >= MAXCLIPS Then Begin
  AddClipRec := -1;
  Exit;
 End;
 P.Clips[P.NC] := C;
 AddClipRec := P.NC;
 Inc(P.NC);
End;

Procedure DefClip(Var C: TClip; T, M: Integer; S, D, InP: LongInt);
Begin
 FillChar(C, SizeOf(C), 0);
 C.Trk := T;
 C.Med := M;
 C.Start := S;
 C.Dur := D;
 C.InPt := InP;
 C.Speed := 100;
 C.Name := P.Media[M].Name;
 C.Opac := 100;
 C.Scale := 100;
 C.Sa := 100;
 C.TInL := 15;
 C.TOutL := 15;
End;

Function ClipHasFx(Var C: TClip): Boolean;
Begin
 ClipHasFx := ((C.Fl And 7) <> 0) Or (C.PosX <> 0) Or (C.PosY <> 0) Or (C.Scale <> 100) Or
  (C.Br <> 0) Or (C.Co <> 0) Or (C.Sa <> 100) Or (C.Mos > 1) Or (C.Opac <> 100) Or
  (C.Vol <> 0) Or (C.TIn > 0) Or (C.TOut > 0);
End;

Procedure SetModified;
Begin
 Modified := True;
End;

Procedure ClearSel;
Var
 I: Integer;
Begin
 For I := 0 To P.NC - 1 Do P.Clips[I].Sel := False;
End;

Function SelCount: Integer;
Var
 I, N: Integer;
Begin
 N := 0;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Inc(N);
 SelCount := N;
End;

Function FirstSel: Integer;
Var
 I: Integer;
Begin
 FirstSel := -1;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   FirstSel := I;
   Exit;
  End;
End;

Function TrackLocked(T: Integer): Boolean;
Begin
 TrackLocked := (P.TrkF[T] And TF_LOCK) <> 0;
End;

{ Retire ou coupe tout ce qui occupe [A,B[ sur la piste T. }
Procedure CutRange(T: Integer; A, B: LongInt; KeepSel: Boolean);
Var
 J: Integer;
 C2: TClip;
 S, E: LongInt;
Begin
 J := P.NC - 1;
 While J >= 0 Do Begin
  If (J < P.NC) And (P.Clips[J].Trk = T) And (Not (KeepSel And P.Clips[J].Sel)) Then Begin
   S := P.Clips[J].Start;
   E := S + P.Clips[J].Dur;
   If (S < B) And (E > A) Then Begin
    If (S >= A) And (E <= B) Then
     DelClip(J)
    Else If (S < A) And (E > B) Then Begin
     C2 := P.Clips[J];
     P.Clips[J].Dur := A - S;
     P.Clips[J].TOut := 0;
     C2.InPt := C2.InPt + ((B - S) * C2.Speed) Div 100;
     C2.Dur := E - B;
     C2.Start := B;
     C2.TIn := 0;
     AddClipRec(C2);
    End
    Else If S < A Then Begin
     P.Clips[J].Dur := A - S;
     P.Clips[J].TOut := 0;
    End
    Else Begin
     P.Clips[J].InPt := P.Clips[J].InPt + ((B - S) * P.Clips[J].Speed) Div 100;
     P.Clips[J].Dur := E - B;
     P.Clips[J].Start := B;
     P.Clips[J].TIn := 0;
    End;
   End;
  End;
  Dec(J);
 End;
End;

{ Place un clip en ecrasant ce qui se trouve dessous. }
Function PlaceClip(T, M: Integer; S, InP, D: LongInt): Integer;
Var
 C: TClip;
Begin
 PlaceClip := -1;
 If (M < 0) Or (D < 1) Then Exit;
 CutRange(T, S, S + D, False);
 DefClip(C, T, M, S, D, InP);
 PlaceClip := AddClipRec(C);
End;

{ Coupe le clip I a l'image F. Retourne l'index de la seconde partie. }
Function SplitClip(I: Integer; F: LongInt): Integer;
Var
 C2: TClip;
 S, E: LongInt;
Begin
 SplitClip := -1;
 S := P.Clips[I].Start;
 E := S + P.Clips[I].Dur;
 If (F <= S) Or (F >= E) Then Exit;
 C2 := P.Clips[I];
 P.Clips[I].Dur := F - S;
 P.Clips[I].TOut := 0;
 C2.InPt := C2.InPt + ((F - S) * C2.Speed) Div 100;
 C2.Dur := E - F;
 C2.Start := F;
 C2.TIn := 0;
 SplitClip := AddClipRec(C2);
End;

{ Decale tous les clips commencant a partir de F (pistes non verrouillees). }
Procedure ShiftFrom(F, Delta: LongInt; OnlyTrack: Integer);
Var
 I: Integer;
Begin
 For I := 0 To P.NC - 1 Do
  If (P.Clips[I].Start >= F) And (Not TrackLocked(P.Clips[I].Trk)) Then
   If (OnlyTrack < 0) Or (P.Clips[I].Trk = OnlyTrack) Then
    P.Clips[I].Start := Max(0, P.Clips[I].Start + Delta);
End;

Function FindMarkIdx(F: LongInt): Integer;
Var
 I: Integer;
Begin
 FindMarkIdx := -1;
 For I := 0 To P.NK - 1 Do
  If P.Marks[I].Pos = F Then FindMarkIdx := I;
End;

{ ---------- Historique (annuler / retablir) ---------- }

Procedure ClearRedo;
Var
 I: Integer;
Begin
 For I := 0 To RedoCnt - 1 Do
  If RedoStk[I] <> Nil Then Begin
   Dispose(RedoStk[I]);
   RedoStk[I] := Nil;
  End;
 RedoCnt := 0;
End;

Procedure PushUndo;
Var
 I: Integer;
 S: PProject;
Begin
 ClearRedo;
 If UndoCnt >= MAXUNDO Then Begin
  Dispose(UndoStk[0]);
  For I := 0 To MAXUNDO - 2 Do UndoStk[I] := UndoStk[I + 1];
  UndoStk[MAXUNDO - 1] := Nil;
  Dec(UndoCnt);
 End;
 New(S);
 S^ := P;
 UndoStk[UndoCnt] := S;
 Inc(UndoCnt);
 SetModified;
End;

Procedure DropLastUndo;
Begin
 If UndoCnt > 0 Then Begin
  Dispose(UndoStk[UndoCnt - 1]);
  UndoStk[UndoCnt - 1] := Nil;
  Dec(UndoCnt);
 End;
End;

Procedure DoUndo;
Var
 S: PProject;
Begin
 If UndoCnt = 0 Then Exit;
 If RedoCnt < MAXUNDO Then Begin
  New(S);
  S^ := P;
  RedoStk[RedoCnt] := S;
  Inc(RedoCnt);
 End;
 P := UndoStk[UndoCnt - 1]^;
 DropLastUndo;
End;

Procedure DoRedo;
Var
 S: PProject;
Begin
 If RedoCnt = 0 Then Exit;
 New(S);
 S^ := P;
 If UndoCnt < MAXUNDO Then Begin
  UndoStk[UndoCnt] := S;
  Inc(UndoCnt);
 End Else Dispose(S);
 P := RedoStk[RedoCnt - 1]^;
 Dispose(RedoStk[RedoCnt - 1]);
 RedoStk[RedoCnt - 1] := Nil;
 Dec(RedoCnt);
End;

Procedure FreeHistory;
Var
 I: Integer;
Begin
 For I := 0 To UndoCnt - 1 Do
  If UndoStk[I] <> Nil Then Dispose(UndoStk[I]);
 UndoCnt := 0;
 ClearRedo;
End;

{ ====================================================================== }
{  Moteur de rendu : generateurs, composition, tramage 16 couleurs       }
{ ====================================================================== }

Function Sn(A: LongInt): LongInt;
Begin
 Sn := SinTab[A And 255];
End;

Function Tri(A: LongInt): LongInt;
Begin
 A := A And 255;
 If A < 128 Then Tri := A * 2 Else Tri := (255 - A) * 2;
End;

Function Hash3(A, B, C: LongInt): LongInt;
Var
 H: LongInt;
Begin
 H := (A * 7919 + B * 104729 + C * 1299709 + 12345) And $7FFFFFFF;
 H := (H Xor (H Shr 7)) * 31 + (H Shr 3);
 H := H And $7FFFFFFF;
 H := (H Xor (H Shr 11)) And $7FFF;
 Hash3 := H;
End;

Procedure InitTables;
Var
 I, R, G, B, J, Best: Integer;
 D, BestD, DR, DG, DB: LongInt;
 CR8, CG8, CB8: LongInt;
Begin
 For I := 0 To 255 Do SinTab[I] := Round(Sin(I * 2 * Pi / 256) * 127);
 For R := 0 To 7 Do
  For G := 0 To 7 Do
   For B := 0 To 7 Do Begin
    CR8 := Min(255, R * 36 + 18);
    CG8 := Min(255, G * 36 + 18);
    CB8 := Min(255, B * 36 + 18);
    Best := 0;
    BestD := 99999999;
    For J := 0 To 15 Do Begin
     DR := CR8 - PalR[J];
     DG := CG8 - PalG[J];
     DB := CB8 - PalB[J];
     D := DR * DR + DG * DG + DB * DB;
     If D < BestD Then Begin
      BestD := D;
      Best := J;
     End;
    End;
    Quant[(R Shl 6) Or (G Shl 3) Or B] := Best;
   End;
End;

{ Index du glyphe dans la police 5x7 }
Function GlyphIdx(Ch: Char): Integer;
Begin
 Case Ch Of
  'A'..'Z': GlyphIdx := Ord(Ch) - 65;
  'a'..'z': GlyphIdx := Ord(Ch) - 97;
  '0'..'9': GlyphIdx := 26 + Ord(Ch) - 48;
  '-': GlyphIdx := 36;
  '.': GlyphIdx := 37;
  ':': GlyphIdx := 38;
  '!': GlyphIdx := 39;
  '?': GlyphIdx := 40;
  #128, #135: GlyphIdx := 2;
  #130, #136, #137, #138, #144: GlyphIdx := 4;
  #131, #132, #133: GlyphIdx := 0;
  #139, #140: GlyphIdx := 8;
  #147, #148: GlyphIdx := 14;
  #129, #150, #151: GlyphIdx := 20;
 Else GlyphIdx := 41;
 End;
End;

Function GlyphBit(Ch: Char; GX, GY: LongInt): Boolean;
Begin
 GlyphBit := (Font57[GlyphIdx(Ch), GY] And (16 Shr GX)) <> 0;
End;

Function TitleBit(Var L: TLayer; X, Y: LongInt): Boolean;
Var
 TX, TY, GX, GY, CI, SB: LongInt;
Begin
 TitleBit := False;
 TX := X - L.TX0;
 TY := Y - L.TY0;
 If (TX < 0) Or (TY < 0) Then Exit;
 GX := TX Div L.TS;
 GY := TY Div L.TS;
 CI := GX Div 6;
 SB := GX Mod 6;
 If (CI >= Length(L.TT)) Or (SB >= 5) Or (GY >= 7) Then Exit;
 TitleBit := GlyphBit(L.TT[CI + 1], SB, GY);
End;

Procedure SetupLayer(Var L: TLayer; M: Integer; T: LongInt);
Var
 N, S: Integer;
Begin
 FillChar(L, SizeOf(L), 0);
 L.M := M;
 L.K := P.Media[M].Kind;
 L.Par := P.Media[M].Par;
 L.T := T;
 L.MDur := P.Media[M].Dur;
 L.Al := 255;
 L.Sc := 100;
 L.Dim := 256;
 L.TS := 1;
 If L.K = MK_IMAGE Then L.Par := P.Media[M].Img;
 If L.K = MK_TITLE Then Begin
  L.TT := Copy(Cv(P.Media[M].Txt), 1, 22);
  N := Length(L.TT);
  If N < 1 Then N := 1;
  S := (VW - 16) Div (N * 6);
  If S > 8 Then S := 8;
  If S < 1 Then S := 1;
  L.TS := S;
  L.TX0 := (VW - (N * 6 - 1) * S) Div 2;
  L.TY0 := (VH - 7 * S) Div 2;
 End;
 If L.K = MK_COUNT Then Begin
  L.Cd := (L.MDur - T + P.Fps - 1) Div P.Fps;
  If L.Cd < 0 Then L.Cd := 0;
  L.Cd := L.Cd Mod 10;
 End;
End;

Procedure PutRGB(R, G, B: LongInt);
Begin
 CR := R;
 CG := G;
 CB := B;
End;

{ Genere le pixel (X,Y) du calque courant CL dans CR,CG,CB,CA }
Procedure Gen(X, Y: LongInt);
Var
 I, J, V, DX, DY, D, Q: LongInt;
 PB: PImgBuf;
Begin
 CA := 255;
 With Lay[CL] Do
  Case K Of
   MK_BARS: Begin
    If Y < 107 Then Begin
     I := X * 7 Div VW;
     PutRGB(BarR[I], BarG[I], BarB[I]);
    End Else If Y < 120 Then Begin
     I := X * 7 Div VW;
     PutRGB(MidR[I], MidG[I], MidB[I]);
    End Else Begin
     I := X * 6 Div VW;
     Case I Of
      0: PutRGB(0, 33, 76);
      1: PutRGB(255, 255, 255);
      2: PutRGB(50, 0, 106);
      3: PutRGB(19, 19, 19);
      4: PutRGB(0, 0, 0);
     Else PutRGB(38, 38, 38);
     End;
     If (Y >= 128) And (Y < 150) And (Abs(X - ((T * 4) Mod VW)) < 3) Then PutRGB(255, 255, 255);
    End;
   End;
   MK_GRAD: Begin
    V := X * 256 Div VW + T * 4;
    I := 255 - Y * 90 Div VH;
    PutRGB(Tri(V) * I Div 255, Tri(V + 85) * I Div 255, Tri(V + 170) * I Div 255);
   End;
   MK_PLASMA: Begin
    V := Sn(X * 2 + T * 3) + Sn(Y * 3 - T * 2) + Sn(X + Y + T * 4) +
         Sn((X * X + Y * Y) Div 160 + T * 3);
    PutRGB(128 + Sn(V + 0) Div 2 + 63, 128 + Sn(V + 85) Div 2 + 63, 128 + Sn(V + 170) Div 2 + 63);
   End;
   MK_CHECK: Begin
    I := ((X + T * 3) Div 20 + (Y + T) Div 20) And 1;
    J := Par;
    If (J < 0) Or (J >= NPRE) Then J := 2;
    If I = 0 Then PutRGB(PreR[J], PreG[J], PreB[J])
    Else PutRGB(PreR[J] Div 4, PreG[J] Div 4, PreB[J] Div 4);
   End;
   MK_COUNT: Begin
    DX := X - VW Div 2;
    DY := Y - VH Div 2;
    PutRGB(40, 40, 40);
    If (DX = 0) Or (DY = 0) Then PutRGB(120, 120, 120);
    D := DX * DX + DY * DY;
    If (D >= 4600) And (D <= 5200) Then PutRGB(220, 220, 220);
    I := ((T * 256) Div P.Fps) And 255;
    DX := X - (VW Div 2 + Sn(I + 64) * 69 Div 127);
    DY := Y - (VH Div 2 - Sn(I) * 69 Div 127);
    If DX * DX + DY * DY < 30 Then PutRGB(255, 80, 80);
    DX := X - (VW Div 2 - 35);
    DY := Y - (VH Div 2 - 49);
    If (DX >= 0) And (DY >= 0) And (DX < 70) And (DY < 98) Then
     If (Font57[26 + Cd, DY Div 14] And (16 Shr (DX Div 14))) <> 0 Then PutRGB(255, 255, 255);
   End;
   MK_SOLID: Begin
    J := Par;
    If (J < 0) Or (J >= NPRE) Then J := 0;
    PutRGB(PreR[J], PreG[J], PreB[J]);
   End;
   MK_TITLE: Begin
    J := Par;
    If (J < 0) Or (J >= NPRE) Then J := 1;
    If TitleBit(Lay[CL], X, Y) Then PutRGB(PreR[J], PreG[J], PreB[J])
    Else If TitleBit(Lay[CL], X - TS, Y - TS) Then Begin
     PutRGB(0, 0, 0);
     CA := 200;
    End Else CA := 0;
   End;
   MK_NOISE: Begin
    V := Hash3(X, Y, T) And 255;
    PutRGB(V, V, V + (V Shr 3));
    If CB > 255 Then CB := 255;
   End;
   MK_WAVES: Begin
    DX := Abs(X - VW Div 2);
    DY := Abs(Y - VH Div 2);
    If DX > DY Then D := DX + DY Div 2 Else D := DY + DX Div 2;
    V := D * 3 - T * 6;
    PutRGB(128 + Sn(V), 128 + Sn(V + 85), 128 + Sn(V + 170));
   End;
   MK_IMAGE: Begin
    If (Par >= 0) And (Par < MAXIMG) And (ImgPool[Par] <> Nil) Then Begin
     PB := ImgPool[Par];
     Q := PB^[Y * VW + X];
     PutRGB((Q Shr 5) * 255 Div 7, ((Q Shr 2) And 7) * 255 Div 7, (Q And 3) * 255 Div 3);
    End Else PutRGB(30, 30, 30);
   End;
  Else PutRGB(0, 0, 0);
  End;
End;

{ Construit le calque d'un clip a l'image Tm de la sequence }
Procedure BuildClipLayer(I: Integer; Tm: LongInt);
Var
 SF, Off, Rem, Prog: LongInt;
 Kind: Integer;
Begin
 If NLay > 2 Then Exit;
 SF := P.Clips[I].InPt + ((Tm - P.Clips[I].Start) * P.Clips[I].Speed) Div 100;
 SetupLayer(Lay[NLay], P.Clips[I].Med, SF);
 With Lay[NLay] Do Begin
  Al := (P.Clips[I].Opac * 255) Div 100;
  PX := P.Clips[I].PosX;
  PY := P.Clips[I].PosY;
  Sc := P.Clips[I].Scale;
  If Sc < 1 Then Sc := 1;
  Br := P.Clips[I].Br;
  Co := P.Clips[I].Co;
  Sa := P.Clips[I].Sa;
  Mos := P.Clips[I].Mos;
  Fl := P.Clips[I].Fl;
  Tr := (Sc <> 100) Or (PX <> 0) Or (PY <> 0);
  Fx := (Br <> 0) Or (Co <> 0) Or (Sa <> 100) Or ((Fl And CF_INV) <> 0);
  Off := Tm - P.Clips[I].Start;
  Rem := P.Clips[I].Start + P.Clips[I].Dur - 1 - Tm;
  Kind := 0;
  Prog := 256;
  If (P.Clips[I].TIn > 0) And (P.Clips[I].TInL > 0) And (Off < P.Clips[I].TInL) Then Begin
   Kind := P.Clips[I].TIn;
   Prog := (Off * 256) Div P.Clips[I].TInL;
  End Else If (P.Clips[I].TOut > 0) And (P.Clips[I].TOutL > 0) And (Rem < P.Clips[I].TOutL) Then Begin
   Kind := P.Clips[I].TOut;
   Prog := (Rem * 256) Div P.Clips[I].TOutL;
  End;
  Case Kind Of
   1: Al := (Al * Prog) Div 256;
   2: Dim := Prog;
   3: Begin WM := 1; WP := (Prog * VW) Div 256; End;
   4: Begin WM := 2; WP := (Prog * 190) Div 256; End;
  End;
 End;
 Inc(NLay);
End;

Procedure BuildLayers(Tm: LongInt);
Var
 T, I: Integer;
Begin
 NLay := 0;
 For T := 0 To 2 Do
  If (P.TrkF[T] And TF_HIDE) = 0 Then Begin
   I := FindClip(T, Tm);
   If (I >= 0) And ((P.Clips[I].Fl And CF_OFF) = 0) Then BuildClipLayer(I, Tm);
  End;
End;

Procedure BuildSource;
Begin
 NLay := 0;
 If (SrcMed >= 0) And (SrcMed < P.NM) Then
  If Not MediaAudio(SrcMed) Then Begin
   SetupLayer(Lay[0], SrcMed, SrcPos);
   NLay := 1;
  End;
End;

Procedure Compose(X, Y: LongInt);
Var
 I: Integer;
 SX, SY, A, G, DX, DY, D, M: LongInt;
 Skip: Boolean;
Begin
 AR := 0;
 AG := 0;
 AB := 0;
 For I := 0 To NLay - 1 Do Begin
  CL := I;
  Skip := False;
  SX := X;
  SY := Y;
  If Lay[I].WM = 1 Then
   Skip := X >= Lay[I].WP
  Else If Lay[I].WM = 2 Then Begin
   DX := Abs(X - VW Div 2);
   DY := Abs(Y - VH Div 2);
   If DX > DY Then D := DX + DY Div 2 Else D := DY + DX Div 2;
   Skip := D >= Lay[I].WP;
  End;
  If Not Skip Then Begin
   If (Lay[I].Fl And CF_MIRH) <> 0 Then SX := VW - 1 - SX;
   If (Lay[I].Fl And CF_MIRV) <> 0 Then SY := VH - 1 - SY;
   If Lay[I].Tr Then Begin
    SX := ((SX - VW Div 2 - Lay[I].PX) * 100) Div Lay[I].Sc + VW Div 2;
    SY := ((SY - VH Div 2 - Lay[I].PY) * 100) Div Lay[I].Sc + VH Div 2;
    If (SX < 0) Or (SX >= VW) Or (SY < 0) Or (SY >= VH) Then Skip := True;
   End;
  End;
  If Not Skip Then Begin
   M := Lay[I].Mos;
   If M > 1 Then Begin
    SX := Min(VW - 1, (SX Div M) * M + M Div 2);
    SY := Min(VH - 1, (SY Div M) * M + M Div 2);
   End;
   Gen(SX, SY);
   If CA > 0 Then Begin
    If Lay[I].Fx Then Begin
     If (Lay[I].Fl And CF_INV) <> 0 Then Begin
      CR := 255 - CR;
      CG := 255 - CG;
      CB := 255 - CB;
     End;
     If Lay[I].Sa <> 100 Then Begin
      G := (CR * 30 + CG * 59 + CB * 11) Div 100;
      CR := G + ((CR - G) * Lay[I].Sa) Div 100;
      CG := G + ((CG - G) * Lay[I].Sa) Div 100;
      CB := G + ((CB - G) * Lay[I].Sa) Div 100;
     End;
     If (Lay[I].Co <> 0) Or (Lay[I].Br <> 0) Then Begin
      CR := ((CR - 128) * (100 + Lay[I].Co)) Div 100 + 128 + Lay[I].Br * 2;
      CG := ((CG - 128) * (100 + Lay[I].Co)) Div 100 + 128 + Lay[I].Br * 2;
      CB := ((CB - 128) * (100 + Lay[I].Co)) Div 100 + 128 + Lay[I].Br * 2;
     End;
     If CR < 0 Then CR := 0 Else If CR > 255 Then CR := 255;
     If CG < 0 Then CG := 0 Else If CG > 255 Then CG := 255;
     If CB < 0 Then CB := 0 Else If CB > 255 Then CB := 255;
    End;
    A := (CA * Lay[I].Al) Div 255;
    If A > 0 Then Begin
     AR := AR + ((CR - AR) * A) Div 255;
     AG := AG + ((CG - AG) * A) Div 255;
     AB := AB + ((CB - AB) * A) Div 255;
    End;
   End;
  End;
  If Lay[I].Dim < 256 Then Begin
   AR := (AR * Lay[I].Dim) Div 256;
   AG := (AG * Lay[I].Dim) Div 256;
   AB := (AB * Lay[I].Dim) Div 256;
  End;
 End;
End;

Function QuantColor(X, Y: LongInt): Integer;
Var
 R, G, B, D: LongInt;
Begin
 D := (Bayer[Y And 3, X And 3] - 8) * 4;
 R := AR + D;
 G := AG + D;
 B := AB + D;
 If R < 0 Then R := 0 Else If R > 255 Then R := 255;
 If G < 0 Then G := 0 Else If G > 255 Then G := 255;
 If B < 0 Then B := 0 Else If B > 255 Then B := 255;
 QuantColor := Quant[((R Shr 5) Shl 6) Or ((G Shr 5) Shl 3) Or (B Shr 5)];
End;

Procedure RenderView(OX, OY, Q: Integer);
Var
 X, Y: Integer;
 C: Integer;
Begin
 Y := 0;
 While Y < VH Do Begin
  X := 0;
  While X < VW Do Begin
   If NLay = 0 Then Begin
    AR := 0;
    AG := 0;
    AB := 0;
   End Else Compose(X, Y);
   C := QuantColor(X, Y);
   If Q <= 1 Then PutPixel(OX + X, OY + Y, C)
   Else Begin
    SetFillStyle(SolidFill, C);
    Bar(OX + X, OY + Y, OX + X + Q - 1, OY + Y + Q - 1);
   End;
   Inc(X, Q);
  End;
  Inc(Y, Q);
 End;
End;

{ ====================================================================== }
{  Audio : niveaux des vumetres et frequence jouee                       }
{ ====================================================================== }

Const
 MelodyIdx: Array[0..7] Of Integer = (0,2,3,5,3,2,4,1);
 MelodyHz: Array[0..7] Of Integer = (262,294,330,392,440,523,659,784);

Var
 AudioFreq: Integer;

Procedure AnalyseAudio(Tm: LongInt);
Var
 T, I: Integer;
 SF, Off, Rem: LongInt;
 Amp, AL, AR2, Pr, Q, Beat: LongInt;
 M: Integer;
 Got: Boolean;
Begin
 AL := 0;
 AR2 := 0;
 AudioFreq := 0;
 Got := False;
 For T := 3 To 5 Do
  If (P.TrkF[T] And TF_HIDE) = 0 Then Begin
   I := FindClip(T, Tm);
   If (I >= 0) And ((P.Clips[I].Fl And CF_OFF) = 0) And (Not P.Clips[I].Mute) Then Begin
    M := P.Clips[I].Med;
    SF := P.Clips[I].InPt + ((Tm - P.Clips[I].Start) * P.Clips[I].Speed) Div 100;
    Beat := P.Fps Div 3;
    If Beat < 1 Then Beat := 1;
    Case P.Media[M].Kind Of
     MK_TONE: Begin
      Amp := 70 + Sn(SF * 5) Div 12;
      Q := P.Media[M].Par;
     End;
     MK_MELODY: Begin
      Pr := SF Mod Beat;
      Amp := 90 - (Pr * 60) Div Beat;
      Q := MelodyHz[MelodyIdx[(SF Div Beat) And 7]];
     End;
    Else Begin
      If ((SF Div Beat) And 1) = 0 Then Amp := 85 Else Amp := 0;
      Q := P.Media[M].Par;
     End;
    End;
    Off := Tm - P.Clips[I].Start;
    Rem := P.Clips[I].Start + P.Clips[I].Dur - 1 - Tm;
    If (P.Clips[I].TIn > 0) And (P.Clips[I].TInL > 0) And (Off < P.Clips[I].TInL) Then
     Amp := (Amp * Off) Div P.Clips[I].TInL
    Else If (P.Clips[I].TOut > 0) And (P.Clips[I].TOutL > 0) And (Rem < P.Clips[I].TOutL) Then
     Amp := (Amp * Rem) Div P.Clips[I].TOutL;
    Amp := (Amp * (100 + P.Clips[I].Vol * 3)) Div 100;
    If Amp < 0 Then Amp := 0;
    If Amp > 100 Then Amp := 100;
    AL := Min(100, AL + Amp);
    AR2 := Min(100, AR2 + (Amp * (90 + (Hash3(Tm, T, 1) And 15))) Div 100);
    If (Not Got) And (Amp > 5) And (Q > 0) Then Begin
     AudioFreq := Q;
     Got := True;
    End;
   End;
  End;
 If AL > LevelL Then LevelL := AL Else LevelL := (LevelL * 3 + AL) Div 4;
 If AR2 > LevelR Then LevelR := AR2 Else LevelR := (LevelR * 3 + AR2) Div 4;
 If LevelL > PeakL Then PeakL := LevelL;
 If LevelR > PeakR Then PeakR := LevelR;
End;

Procedure StopSound;
Begin
 If LastTone <> 0 Then Begin
  NoSound;
  LastTone := 0;
 End;
End;

Procedure UpdateSound;
Begin
 If Playing And AudioOn And (AudioFreq > 0) Then Begin
  If AudioFreq <> LastTone Then Begin
   Sound(AudioFreq);
   LastTone := AudioFreq;
  End;
 End Else StopSound;
End;

{ ====================================================================== }
{  Interface : geometrie, icones, menus                                  }
{ ====================================================================== }

Type
 TTabs = Array[0..2] Of String[22];

Const
 TabNA: TTabs = ('Source','Contrôles des effets','');
 TabNC: TTabs = ('Projet','Effets','Marqueurs');
 ZoomTab: Array[0..13] Of Integer = (1,2,3,5,8,12,18,25,40,60,100,150,220,320);

Function FrameToX(F: LongInt): LongInt;
Begin
 FrameToX := TLX0 + ((F - ScrollF) * PPS) Div P.Fps;
End;

Function XToFrame(X: LongInt): LongInt;
Begin
 XToFrame := ScrollF + FDiv((X - TLX0) * P.Fps, PPS);
End;

Function VisFrames: LongInt;
Begin
 VisFrames := ((TLX1 - TLX0) * P.Fps) Div PPS;
End;

Function RowY(R: Integer): Integer;
Begin
 RowY := TRY0 + R * TRH;
End;

Procedure IcoTri(X1, Y1, X2, Y2, X3, Y3, C: Integer);
Var
 Pt: Array[0..2] Of PointType;
Begin
 Pt[0].X := X1; Pt[0].Y := Y1;
 Pt[1].X := X2; Pt[1].Y := Y2;
 Pt[2].X := X3; Pt[2].Y := Y3;
 SetFillStyle(SolidFill, C);
 SetColor(C);
 FillPoly(3, Pt);
End;

{ Icone de transport dans une cellule de 16x16 }
Procedure Icon(Id, X, Y, C: Integer);
Begin
 SetColor(C);
 Case Id Of
  0: Begin
   Line(X + 10, Y + 3, X + 6, Y + 3); Line(X + 6, Y + 3, X + 6, Y + 12);
   Line(X + 6, Y + 12, X + 10, Y + 12); Line(X + 7, Y + 3, X + 7, Y + 12);
  End;
  1: Begin
   Line(X + 6, Y + 3, X + 10, Y + 3); Line(X + 10, Y + 3, X + 10, Y + 12);
   Line(X + 10, Y + 12, X + 6, Y + 12); Line(X + 9, Y + 3, X + 9, Y + 12);
  End;
  2: Begin
   FillR(X + 3, Y + 4, X + 4, Y + 11, C);
   IcoTri(X + 12, Y + 3, X + 5, Y + 8, X + 12, Y + 12, C);
  End;
  3: IcoTri(X + 4, Y + 3, X + 12, Y + 8, X + 4, Y + 13, C);
  4: Begin
   IcoTri(X + 3, Y + 3, X + 10, Y + 8, X + 3, Y + 12, C);
   FillR(X + 11, Y + 4, X + 12, Y + 11, C);
  End;
  5: Begin
   IcoTri(X + 8, Y + 3, X + 2, Y + 8, X + 8, Y + 13, C);
   IcoTri(X + 14, Y + 3, X + 8, Y + 8, X + 14, Y + 13, C);
  End;
  6: Begin
   IcoTri(X + 2, Y + 3, X + 8, Y + 8, X + 2, Y + 13, C);
   IcoTri(X + 8, Y + 3, X + 14, Y + 8, X + 8, Y + 13, C);
  End;
  7: Begin
   Rectangle(X + 2, Y + 5, X + 13, Y + 12);
   Rectangle(X + 5, Y + 3, X + 9, Y + 5);
   Circle(X + 8, Y + 9, 2);
  End;
  8: Begin
   Line(X + 3, Y + 3, X + 3, Y + 12); Line(X + 3, Y + 12, X + 12, Y + 12);
   Line(X + 12, Y + 12, X + 12, Y + 3);
   IcoTri(X + 5, Y + 4, X + 10, Y + 4, X + 8, Y + 9, C);
  End;
  9: Begin
   IcoTri(X + 4, Y + 3, X + 11, Y + 3, X + 8, Y + 9, C);
   FillR(X + 3, Y + 11, X + 12, Y + 12, C);
  End;
  10: Begin
   FillR(X + 5, Y + 4, X + 6, Y + 11, C);
   IcoTri(X + 12, Y + 3, X + 7, Y + 8, X + 12, Y + 12, C);
  End;
  11: Begin
   IcoTri(X + 4, Y + 3, X + 9, Y + 8, X + 4, Y + 12, C);
   FillR(X + 10, Y + 4, X + 11, Y + 11, C);
  End;
  12: Begin
   FillR(X + 4, Y + 3, X + 6, Y + 12, C);
   FillR(X + 9, Y + 3, X + 11, Y + 12, C);
  End;
 End;
End;

{ Icones des outils de montage dans une cellule 22x22 }
Procedure ToolIcon(T, X, Y, C: Integer);
Begin
 SetColor(C);
 Case T Of
  TL_SELECT: Begin
   IcoTri(X + 6, Y + 3, X + 6, Y + 16, X + 15, Y + 11, C);
   Line(X + 10, Y + 12, X + 14, Y + 18); Line(X + 11, Y + 12, X + 15, Y + 18);
  End;
  TL_TRACKFWD: Begin
   IcoTri(X + 8, Y + 5, X + 8, Y + 17, X + 17, Y + 11, C);
   FillR(X + 3, Y + 5, X + 4, Y + 17, C);
   Line(X + 4, Y + 11, X + 8, Y + 11);
  End;
  TL_RIPPLE: Begin
   Line(X + 12, Y + 4, X + 8, Y + 4); Line(X + 8, Y + 4, X + 8, Y + 17);
   Line(X + 8, Y + 17, X + 12, Y + 17); Line(X + 9, Y + 4, X + 9, Y + 17);
   IcoTri(X + 3, Y + 11, X + 7, Y + 7, X + 7, Y + 15, C);
   IcoTri(X + 18, Y + 11, X + 14, Y + 7, X + 14, Y + 15, C);
  End;
  TL_RAZOR: Begin
   Line(X + 4, Y + 17, X + 16, Y + 5); Line(X + 5, Y + 17, X + 17, Y + 5);
   Line(X + 3, Y + 15, X + 7, Y + 19); Line(X + 14, Y + 4, X + 18, Y + 8);
   Line(X + 11, Y + 3, X + 11, Y + 18);
  End;
  TL_HAND: Begin
   Rectangle(X + 6, Y + 10, X + 16, Y + 18);
   Line(X + 7, Y + 10, X + 7, Y + 4); Line(X + 10, Y + 10, X + 10, Y + 3);
   Line(X + 13, Y + 10, X + 13, Y + 4); Line(X + 16, Y + 12, X + 19, Y + 8);
  End;
  TL_ZOOM: Begin
   Circle(X + 9, Y + 9, 5);
   Line(X + 13, Y + 13, X + 18, Y + 18); Line(X + 14, Y + 13, X + 19, Y + 18);
   Line(X + 7, Y + 9, X + 11, Y + 9); Line(X + 9, Y + 7, X + 9, Y + 11);
  End;
  TL_TYPE: Begin
   Line(X + 5, Y + 4, X + 17, Y + 4); Line(X + 5, Y + 5, X + 17, Y + 5);
   Line(X + 10, Y + 5, X + 10, Y + 18); Line(X + 11, Y + 5, X + 11, Y + 18);
   Line(X + 8, Y + 18, X + 13, Y + 18);
  End;
 End;
End;

{ ---------- Etat des commandes ---------- }

Function CmdEnabled(Id: Integer): Boolean;
Begin
 CmdEnabled := True;
 Case Id Of
  CM_UNDO: CmdEnabled := UndoCnt > 0;
  CM_REDO: CmdEnabled := RedoCnt > 0;
  CM_CUT, CM_COPY, CM_DELETE, CM_RIPDEL, CM_DUP, CM_RENAME, CM_SPEED, CM_ENABLE,
  CM_RESETFX, CM_VTRANS, CM_ATRANS, CM_NOTRANS: CmdEnabled := SelCount > 0;
  CM_PASTE: CmdEnabled := ClipCnt > 0;
  CM_INSERT, CM_OVERWRITE: CmdEnabled := (SrcMed >= 0) And (SrcMed < P.NM);
  CM_EDITTITLE: CmdEnabled := (FirstSel >= 0) And
                              (P.Media[P.Clips[FirstSel].Med].Kind = MK_TITLE);
  CM_NEXTMARK, CM_PREVMARK, CM_DELMARK, CM_DELMARKS: CmdEnabled := P.NK > 0;
 End;
End;

Function CmdChecked(Id: Integer): Boolean;
Begin
 CmdChecked := False;
 Case Id Of
  CM_QFULL: CmdChecked := Quality = 1;
  CM_QHALF: CmdChecked := Quality = 2;
  CM_QQUART: CmdChecked := Quality = 4;
  CM_SAFE: CmdChecked := SafeOn;
  CM_WAVE: CmdChecked := WaveOn;
  CM_SNAP: CmdChecked := SnapOn;
  CM_AUDIO: CmdChecked := AudioOn;
  CM_LOOP: CmdChecked := LoopOn;
  CM_WS0..CM_WS0 + 4: CmdChecked := WorkSp = Id - CM_WS0;
  CM_TABS: CmdChecked := TabA = 0;
  CM_TABCTL: CmdChecked := TabA = 1;
  CM_TABPROJ: CmdChecked := TabC = 0;
  CM_TABEFF: CmdChecked := TabC = 1;
  CM_TABMARK: CmdChecked := TabC = 2;
 End;
End;

Procedure MenuBegin(Idx: Integer; Const Title: String);
Begin
 Menus[Idx].Title := Title;
 Menus[Idx].N := 0;
End;

Procedure MenuAdd(Idx: Integer; Const Cap, Sc: String; Id: Integer);
Begin
 With Menus[Idx] Do Begin
  It[N].Cap := Cap;
  It[N].Sc := Sc;
  It[N].Id := Id;
  It[N].Sep := False;
  Inc(N);
 End;
End;

Procedure MenuSep(Idx: Integer);
Begin
 With Menus[Idx] Do Begin
  It[N].Cap := '';
  It[N].Sc := '';
  It[N].Id := 0;
  It[N].Sep := True;
  Inc(N);
 End;
End;

Procedure InitMenus;
Var
 I, J, W: Integer;
Begin
 MenuBegin(0, 'Fichier');
 MenuAdd(0, 'Nouveau projet', 'Ctrl+N', CM_NEW);
 MenuAdd(0, 'Ouvrir le projet...', 'Ctrl+O', CM_OPEN);
 MenuAdd(0, 'Enregistrer', 'Ctrl+S', CM_SAVE);
 MenuAdd(0, 'Enregistrer sous...', '', CM_SAVEAS);
 MenuSep(0);
 MenuAdd(0, 'Importer...', 'Ctrl+I', CM_IMPORT);
 MenuAdd(0, 'Nouvel élément...', 'Ctrl+E', CM_NEWITEM);
 MenuSep(0);
 MenuAdd(0, 'Exporter l''image (BMP)', '', CM_EXPFRAME);
 MenuAdd(0, 'Exporter la séquence...', '', CM_EXPSEQ);
 MenuAdd(0, 'Exporter la liste EDL...', '', CM_EXPEDL);
 MenuSep(0);
 MenuAdd(0, 'Quitter', 'Ctrl+Q', CM_QUIT);

 MenuBegin(1, 'Édition');
 MenuAdd(1, 'Annuler', 'Ctrl+Z', CM_UNDO);
 MenuAdd(1, 'Rétablir', 'Ctrl+Y', CM_REDO);
 MenuSep(1);
 MenuAdd(1, 'Couper', 'Ctrl+X', CM_CUT);
 MenuAdd(1, 'Copier', 'Ctrl+C', CM_COPY);
 MenuAdd(1, 'Coller', 'Ctrl+V', CM_PASTE);
 MenuAdd(1, 'Supprimer', 'Suppr', CM_DELETE);
 MenuAdd(1, 'Supprimer et fermer', 'Retour', CM_RIPDEL);
 MenuAdd(1, 'Dupliquer', 'Ctrl+J', CM_DUP);
 MenuSep(1);
 MenuAdd(1, 'Tout sélectionner', 'Ctrl+A', CM_SELALL);
 MenuAdd(1, 'Désélectionner', 'Ctrl+D', CM_SELNONE);

 MenuBegin(2, 'Clip');
 MenuAdd(2, 'Renommer...', 'F2', CM_RENAME);
 MenuAdd(2, 'Vitesse/Durée...', 'Ctrl+R', CM_SPEED);
 MenuAdd(2, 'Activer/Désactiver', 'Ctrl+T', CM_ENABLE);
 MenuAdd(2, 'Modifier le titre...', '', CM_EDITTITLE);
 MenuAdd(2, 'Réinitialiser les effets', '', CM_RESETFX);
 MenuSep(2);
 MenuAdd(2, 'Ajouter une coupe', 'Ctrl+K', CM_SPLIT);
 MenuAdd(2, 'Insérer (Source)', ',', CM_INSERT);
 MenuAdd(2, 'Écraser (Source)', '.', CM_OVERWRITE);
 MenuSep(2);
 MenuAdd(2, 'Transition vidéo par défaut', 'F7', CM_VTRANS);
 MenuAdd(2, 'Transition audio par défaut', 'F8', CM_ATRANS);
 MenuAdd(2, 'Retirer les transitions', '', CM_NOTRANS);

 MenuBegin(3, 'Séquence');
 MenuAdd(3, 'Paramètres de séquence...', '', CM_SEQSET);
 MenuSep(3);
 MenuAdd(3, 'Marquer l''entrée', 'I', CM_MARKIN);
 MenuAdd(3, 'Marquer la sortie', 'O', CM_MARKOUT);
 MenuAdd(3, 'Effacer entrée/sortie', 'X', CM_CLEARIO);
 MenuSep(3);
 MenuAdd(3, 'Supprimer l''espace vide', '', CM_REMGAP);
 MenuAdd(3, 'Aller au début', 'Début', CM_GOSTART);
 MenuAdd(3, 'Aller à la fin', 'Fin', CM_GOEND);
 MenuAdd(3, 'Coupe suivante', 'Bas', CM_NEXTEDIT);
 MenuAdd(3, 'Coupe précédente', 'Haut', CM_PREVEDIT);

 MenuBegin(4, 'Marqueur');
 MenuAdd(4, 'Ajouter un marqueur', 'M', CM_ADDMARK);
 MenuAdd(4, 'Marqueur suivant', 'N', CM_NEXTMARK);
 MenuAdd(4, 'Marqueur précédent', 'P', CM_PREVMARK);
 MenuSep(4);
 MenuAdd(4, 'Effacer le marqueur', '', CM_DELMARK);
 MenuAdd(4, 'Effacer tous les marqueurs', '', CM_DELMARKS);

 MenuBegin(5, 'Affichage');
 MenuAdd(5, 'Qualité : Pleine', '', CM_QFULL);
 MenuAdd(5, 'Qualité : 1/2', '', CM_QHALF);
 MenuAdd(5, 'Qualité : 1/4', '', CM_QQUART);
 MenuSep(5);
 MenuAdd(5, 'Marges de sécurité', '''', CM_SAFE);
 MenuAdd(5, 'Formes d''onde audio', '', CM_WAVE);
 MenuAdd(5, 'Magnétisme', 'S', CM_SNAP);
 MenuAdd(5, 'Lecture audio', '', CM_AUDIO);
 MenuAdd(5, 'Lecture en boucle', 'Ctrl+L', CM_LOOP);
 MenuSep(5);
 MenuAdd(5, 'Zoom avant', '+', CM_ZOOMIN);
 MenuAdd(5, 'Zoom arrière', '-', CM_ZOOMOUT);
 MenuAdd(5, 'Ajuster à la séquence', '\', CM_ZOOMFIT);

 MenuBegin(6, 'Fenêtre');
 For I := 0 To 4 Do MenuAdd(6, 'Espace : ' + WsNames[I], 'Alt+' + IStr(I + 1), CM_WS0 + I);
 MenuSep(6);
 MenuAdd(6, 'Moniteur source', '', CM_TABS);
 MenuAdd(6, 'Contrôles des effets', '', CM_TABCTL);
 MenuAdd(6, 'Projet', '', CM_TABPROJ);
 MenuAdd(6, 'Effets', '', CM_TABEFF);
 MenuAdd(6, 'Marqueurs', '', CM_TABMARK);

 MenuBegin(7, 'Aide');
 MenuAdd(7, 'Raccourcis clavier...', 'F1', CM_HELP);
 MenuAdd(7, 'À propos de Premiere...', '', CM_ABOUT);

 For I := 0 To 7 Do Begin
  W := 100;
  For J := 0 To Menus[I].N - 1 Do
   If Not Menus[I].It[J].Sep Then
    W := Max(W, TW(Menus[I].It[J].Cap) + TW(Menus[I].It[J].Sc) + 56);
  Menus[I].W := W;
 End;
End;

Procedure DrawMenuBar;
Var
 I, X: Integer;
Begin
 FillR(0, 0, SW - 1, MENUH - 1, DarkGray);
 HLine(0, SW - 1, MENUH - 1, Black);
 X := 8;
 For I := 0 To 7 Do Begin
  Menus[I].X := X;
  If MenuActive And (ActiveMenu = I) Then Begin
   FillR(X - 4, 1, X + TW(Menus[I].Title) + 4, MENUH - 2, Blue);
   Txt(X, 6, Menus[I].Title, White);
  End Else Txt(X, 6, Menus[I].Title, White);
  X := X + TW(Menus[I].Title) + 18;
 End;
End;

Function MenuTop(M: Integer): Integer;
Begin
 MenuTop := MENUH;
End;

Procedure DrawMenuDrop(M: Integer);
Var
 I, X, Y, W, H: Integer;
Begin
 If (M < 0) Or (M > 7) Then Exit;
 X := Menus[M].X - 4;
 If X + Menus[M].W > SW - 2 Then X := SW - 2 - Menus[M].W;
 Y := MENUH;
 W := Menus[M].W;
 H := Menus[M].N * 16 + 6;
 FillR(X, Y, X + W, Y + H, LightGray);
 Frame(X, Y, X + W, Y + H, Black);
 HLine(X + 1, X + W - 1, Y + 1, White);
 VLine(X + 1, Y + 1, Y + H - 1, White);
 For I := 0 To Menus[M].N - 1 Do Begin
  If Menus[M].It[I].Sep Then Begin
   HLine(X + 4, X + W - 4, Y + 3 + I * 16 + 8, DarkGray);
  End Else Begin
   If I = ActiveItem Then Begin
    FillR(X + 3, Y + 3 + I * 16, X + W - 3, Y + 3 + I * 16 + 15, Blue);
    If CmdEnabled(Menus[M].It[I].Id) Then SetColor(White) Else SetColor(DarkGray);
   End Else Begin
    If CmdEnabled(Menus[M].It[I].Id) Then SetColor(Black) Else SetColor(DarkGray);
   End;
   If CmdChecked(Menus[M].It[I].Id) Then OutTextXY(X + 7, Y + 3 + I * 16 + 4, #251);
   OutTextXY(X + 20, Y + 3 + I * 16 + 4, Cv(Menus[M].It[I].Cap));
   OutTextXY(X + W - 8 - TextWidth(Cv(Menus[M].It[I].Sc)), Y + 3 + I * 16 + 4,
             Cv(Menus[M].It[I].Sc));
  End;
 End;
End;

Function MenuBarHit(X, Y: LongInt): Integer;
Var
 I: Integer;
Begin
 MenuBarHit := -1;
 If Y >= MENUH Then Exit;
 For I := 0 To 7 Do
  If (X >= Menus[I].X - 4) And (X <= Menus[I].X + TW(Menus[I].Title) + 4) Then Begin
   MenuBarHit := I;
   Exit;
  End;
End;

Function MenuItemHit(X, Y: LongInt; M: Integer): Integer;
Var
 BX, I: Integer;
Begin
 MenuItemHit := -1;
 If (M < 0) Or (M > 7) Then Exit;
 BX := Menus[M].X - 4;
 If BX + Menus[M].W > SW - 2 Then BX := SW - 2 - Menus[M].W;
 If (X < BX) Or (X > BX + Menus[M].W) Or (Y < MENUH + 3) Then Exit;
 I := (Y - MENUH - 3) Div 16;
 If (I >= 0) And (I < Menus[M].N) Then MenuItemHit := I;
End;

{ ---------- Bandeau des espaces de travail ---------- }

Procedure DrawWorkspaces;
Var
 I, X, W: Integer;
Begin
 FillR(0, MENUH, SW - 1, 38, Black);
 HLine(0, SW - 1, 38, DarkGray);
 X := 8;
 For I := 0 To 4 Do Begin
  W := TW(WsNames[I]);
  If I = WorkSp Then Begin
   Txt(X, 26, WsNames[I], White);
   FillR(X - 2, 37, X + W + 2, 38, LightCyan);
  End Else Txt(X, 26, WsNames[I], LightGray);
  X := X + W + 22;
 End;
End;

Function WsHit(X, Y: LongInt): Integer;
Var
 I, XX, W: Integer;
Begin
 WsHit := -1;
 If (Y < MENUH) Or (Y > 38) Then Exit;
 XX := 8;
 For I := 0 To 4 Do Begin
  W := TW(WsNames[I]);
  If (X >= XX - 6) And (X <= XX + W + 10) Then Begin
   WsHit := I;
   Exit;
  End;
  XX := XX + W + 22;
 End;
End;

{ ---------- Panneaux et onglets ---------- }

Procedure PanelBox(X1, Y1, X2, Y2: Integer);
Begin
 FillR(X1, Y1, X2, Y2, Black);
 Frame(X1, Y1, X2, Y2, DarkGray);
End;

Procedure DrawTabs(X1, Y1, X2, N, Active: Integer; Var Names: TTabs);
Var
 I, X, W: Integer;
Begin
 FillR(X1 + 1, Y1 + 1, X2 - 1, Y1 + 13, DarkGray);
 X := X1 + 2;
 For I := 0 To N - 1 Do Begin
  W := TW(Names[I]) + 12;
  If I = Active Then Begin
   FillR(X, Y1 + 1, X + W, Y1 + 13, Black);
   HLine(X, X + W, Y1 + 1, LightCyan);
   Txt(X + 6, Y1 + 4, Names[I], White);
  End Else Txt(X + 6, Y1 + 4, Names[I], LightGray);
  X := X + W + 2;
 End;
End;

Function TabAt(X1, N: Integer; Var Names: TTabs; X: LongInt): Integer;
Var
 I, XX, W: Integer;
Begin
 TabAt := -1;
 XX := X1 + 2;
 For I := 0 To N - 1 Do Begin
  W := TW(Names[I]) + 12;
  If (X >= XX) And (X <= XX + W) Then Begin
   TabAt := I;
   Exit;
  End;
  XX := XX + W + 2;
 End;
End;

{ ====================================================================== }
{  Moniteurs source et programme                                         }
{ ====================================================================== }

Function MonX1(IsProg: Boolean): Integer;
Begin
 If IsProg Then MonX1 := BX1 Else MonX1 := AX1;
End;

Function MonX2(IsProg: Boolean): Integer;
Begin
 If IsProg Then MonX2 := BX2 Else MonX2 := AX2;
End;

Function MonVX(IsProg: Boolean): Integer;
Begin
 MonVX := MonX1(IsProg) + (MonX2(IsProg) - MonX1(IsProg) + 1 - VW) Div 2;
End;

Function MonVY: Integer;
Begin
 MonVY := AY1 + 16;
End;

Function MonLen(IsProg: Boolean): LongInt;
Begin
 If IsProg Then Begin
  MonLen := Max(SeqEnd, P.Fps * 5);
 End Else Begin
  If (SrcMed >= 0) And (SrcMed < P.NM) Then MonLen := Max(1, MediaMax(SrcMed))
  Else MonLen := P.Fps * 5;
  If (SrcMed >= 0) And (SrcMed < P.NM) Then
   If MediaUnlimited(SrcMed) Then MonLen := P.Fps * 10;
 End;
End;

Function MonPos(IsProg: Boolean): LongInt;
Begin
 If IsProg Then MonPos := Playhead Else MonPos := SrcPos;
End;

Function MonBtnX(IsProg: Boolean; I: Integer): Integer;
Begin
 MonBtnX := (MonX1(IsProg) + MonX2(IsProg)) Div 2 - 64 + I * 16;
End;

Function MonBtnY: Integer;
Begin
 MonBtnY := MonVY + VH + 13;
End;

Function MonBtnIcon(IsProg: Boolean; I: Integer): Integer;
Begin
 If IsProg Then
  Case I Of
   0: MonBtnIcon := 0;
   1: MonBtnIcon := 1;
   2: MonBtnIcon := 5;
   3: MonBtnIcon := 2;
   4: If Playing And (PlayTarget = 1) Then MonBtnIcon := 12 Else MonBtnIcon := 3;
   5: MonBtnIcon := 4;
   6: MonBtnIcon := 6;
  Else MonBtnIcon := 7;
  End
 Else
  Case I Of
   0: MonBtnIcon := 0;
   1: MonBtnIcon := 1;
   2: MonBtnIcon := 10;
   3: MonBtnIcon := 2;
   4: If Playing And (PlayTarget = 2) Then MonBtnIcon := 12 Else MonBtnIcon := 3;
   5: MonBtnIcon := 4;
   6: MonBtnIcon := 8;
  Else MonBtnIcon := 9;
  End;
End;

Function MonBtnHit(IsProg: Boolean; X, Y: LongInt): Integer;
Var
 I: Integer;
Begin
 MonBtnHit := -1;
 If (Y < MonBtnY) Or (Y > MonBtnY + 16) Then Exit;
 For I := 0 To 7 Do
  If (X >= MonBtnX(IsProg, I)) And (X <= MonBtnX(IsProg, I) + 14) Then Begin
   MonBtnHit := I;
   Exit;
  End;
End;

Function MonScrubHit(IsProg: Boolean; X, Y: LongInt): Boolean;
Begin
 MonScrubHit := InRect(X, Y, MonVX(IsProg) - 4, MonVY + VH + 2, MonVX(IsProg) + VW + 4,
                       MonVY + VH + 11);
End;

Function MonScrubFrame(IsProg: Boolean; X: LongInt): LongInt;
Var
 F: LongInt;
Begin
 F := ((X - MonVX(IsProg)) * MonLen(IsProg)) Div VW;
 MonScrubFrame := Clamp(F, 0, MonLen(IsProg));
End;

Procedure DrawMonitor(IsProg: Boolean);
Var
 X1, X2, VX, VY, I, Q, PX, BY: Integer;
 Len, Pos: LongInt;
 Title: String;
Begin
 X1 := MonX1(IsProg);
 X2 := MonX2(IsProg);
 VX := MonVX(IsProg);
 VY := MonVY;
 PanelBox(X1, AY1, X2, AY2);
 If IsProg Then Begin
  FillR(X1 + 1, AY1 + 1, X2 - 1, AY1 + 13, DarkGray);
  Title := 'Programme : ' + P.Name;
  Txt(X1 + 6, AY1 + 4, Fit(Title, X2 - X1 - 60), White);
  Case Quality Of
   1: TxtR(X2 - 6, AY1 + 4, 'Pleine', LightCyan);
   2: TxtR(X2 - 6, AY1 + 4, '1/2', LightCyan);
  Else TxtR(X2 - 6, AY1 + 4, '1/4', LightCyan);
  End;
 End Else Begin
  DrawTabs(AX1, AY1, AX2, 2, 0, TabNA);
  If (SrcMed >= 0) And (SrcMed < P.NM) Then
   TxtR(X2 - 6, AY1 + 4, Fit(P.Media[SrcMed].Name, 100), LightCyan);
 End;
 If IsProg Then BuildLayers(Playhead) Else BuildSource;
 Q := 1;
 If Playing Then Q := Quality;
 RenderView(VX, VY, Q);
 Frame(VX - 1, VY - 1, VX + VW, VY + VH, DarkGray);
 If (Not IsProg) And (NLay = 0) Then Begin
  If (SrcMed >= 0) And (SrcMed < P.NM) Then
   TxtC(VX + VW Div 2, VY + VH Div 2 - 4, '(média audio)', LightGray)
  Else TxtC(VX + VW Div 2, VY + VH Div 2 - 4, 'Aucun clip source', DarkGray);
 End;
 If SafeOn Then Begin
  SetColor(LightGreen);
  SetLineStyle(DottedLn, 0, 1);
  Rectangle(VX + VW Div 20, VY + VH Div 20, VX + VW - VW Div 20, VY + VH - VH Div 20);
  Rectangle(VX + VW Div 10, VY + VH Div 10, VX + VW - VW Div 10, VY + VH - VH Div 10);
  SetLineStyle(SolidLn, 0, 1);
 End;
 { Barre de defilement }
 Len := MonLen(IsProg);
 Pos := MonPos(IsProg);
 BY := VY + VH + 6;
 FillR(VX, BY - 2, VX + VW - 1, BY + 3, Black);
 HLine(VX, VX + VW - 1, BY, DarkGray);
 If IsProg Then Begin
  If P.InM >= 0 Then FillR(VX + Integer((P.InM * VW) Div Len), BY - 2, VX + VW - 1, BY + 3, 8);
 End;
 If IsProg Then Begin
  If (P.InM >= 0) Or (P.OutM >= 0) Then Begin
   FillR(VX, BY - 2, VX + VW - 1, BY + 3, Black);
   HLine(VX, VX + VW - 1, BY, DarkGray);
   If P.InM >= 0 Then I := Integer((P.InM * VW) Div Len) Else I := 0;
   If P.OutM >= 0 Then PX := Integer((P.OutM * VW) Div Len) Else PX := VW - 1;
   If PX > VW - 1 Then PX := VW - 1;
   If PX >= I Then FillR(VX + I, BY - 2, VX + PX, BY + 3, Blue);
  End;
  For I := 0 To P.NK - 1 Do
   If P.Marks[I].Pos <= Len Then
    VLine(VX + Integer((P.Marks[I].Pos * VW) Div Len), BY - 3, BY + 4, LightGreen);
 End Else Begin
  If (SrcIn >= 0) Or (SrcOut >= 0) Then Begin
   If SrcIn >= 0 Then I := Integer((SrcIn * VW) Div Len) Else I := 0;
   If SrcOut >= 0 Then PX := Integer((SrcOut * VW) Div Len) Else PX := VW - 1;
   If PX > VW - 1 Then PX := VW - 1;
   If PX >= I Then FillR(VX + I, BY - 2, VX + PX, BY + 3, Blue);
  End;
 End;
 PX := VX + Integer((Pos * VW) Div Len);
 If PX > VX + VW - 1 Then PX := VX + VW - 1;
 IcoTri(PX - 4, BY - 5, PX + 4, BY - 5, PX, BY + 1, LightBlue);
 VLine(PX, BY, BY + 4, LightBlue);
 { Codes temporels et boutons }
 BY := MonBtnY;
 Txt(X1 + 6, BY + 4, TC(Pos), LightCyan);
 If IsProg Then Txt(X2 - 94, BY + 4, TC(SeqEnd), LightGray)
 Else Txt(X2 - 94, BY + 4, TC(Max(0, MediaMax(Max(0, SrcMed)))), LightGray);
 If (Not IsProg) And ((SrcMed < 0) Or (SrcMed >= P.NM)) Then
  FillR(X2 - 94, BY + 2, X2 - 4, BY + 14, Black);
 If (Not IsProg) And (SrcMed >= 0) And (SrcMed < P.NM) Then
  If MediaUnlimited(SrcMed) Then Begin
   FillR(X2 - 94, BY + 2, X2 - 4, BY + 14, Black);
   Txt(X2 - 94, BY + 4, 'illimité', LightGray);
  End;
 For I := 0 To 7 Do Begin
  Btn(MonBtnX(IsProg, I), BY, MonBtnX(IsProg, I) + 14, BY + 16, False);
  Icon(MonBtnIcon(IsProg, I), MonBtnX(IsProg, I) - 1, BY + 1, White);
 End;
End;

{ ====================================================================== }
{  Controles des effets                                                  }
{ ====================================================================== }

Const
 MAXCTL = 24;

Var
 CtlN: Integer;
 CtlKind: Array[0..MAXCTL-1] Of Integer;  { 0 curseur, 1 case, 2 type, 3 titre }
 CtlId: Array[0..MAXCTL-1] Of Integer;

Function CtlLabel(Id: Integer): String;
Begin
 Case Id Of
  1: CtlLabel := 'Position X';
  2: CtlLabel := 'Position Y';
  3: CtlLabel := 'Échelle';
  4: CtlLabel := 'Opacité';
  5: CtlLabel := 'Luminosité';
  6: CtlLabel := 'Contraste';
  7: CtlLabel := 'Saturation';
  8: CtlLabel := 'Mosaïque';
  9: CtlLabel := 'Volume (dB)';
  10: CtlLabel := 'Durée début';
  11: CtlLabel := 'Durée fin';
  20: CtlLabel := 'Miroir horiz.';
  21: CtlLabel := 'Miroir vert.';
  22: CtlLabel := 'Inverser';
  23: CtlLabel := 'Muet';
  24: CtlLabel := 'Désactivé';
  30: CtlLabel := 'Trans. début';
  31: CtlLabel := 'Trans. fin';
  40: CtlLabel := 'Mouvement';
  41: CtlLabel := 'Couleur';
  42: CtlLabel := 'Effets';
  43: CtlLabel := 'Transitions';
  44: CtlLabel := 'Audio';
 Else CtlLabel := '';
 End;
End;

Function CtlMin(Id: Integer): Integer;
Begin
 Case Id Of
  1, 2: CtlMin := -200;
  3: CtlMin := 10;
  5, 6: CtlMin := -100;
  9: CtlMin := -40;
  10, 11: CtlMin := 1;
 Else CtlMin := 0;
 End;
End;

Function CtlMax(Id: Integer): Integer;
Begin
 Case Id Of
  1, 2: CtlMax := 200;
  3: CtlMax := 400;
  4: CtlMax := 100;
  5, 6: CtlMax := 100;
  7: CtlMax := 200;
  8: CtlMax := 30;
  9: CtlMax := 12;
  10, 11: CtlMax := 90;
 Else CtlMax := 1;
 End;
End;

Function CtlDef(Id: Integer): Integer;
Begin
 Case Id Of
  3, 4, 7: CtlDef := 100;
  10, 11: CtlDef := 15;
 Else CtlDef := 0;
 End;
End;

Function CtlGet(C: Integer; Id: Integer): Integer;
Begin
 CtlGet := 0;
 If (C < 0) Or (C >= P.NC) Then Exit;
 With P.Clips[C] Do
  Case Id Of
   1: CtlGet := PosX;
   2: CtlGet := PosY;
   3: CtlGet := Scale;
   4: CtlGet := Opac;
   5: CtlGet := Br;
   6: CtlGet := Co;
   7: CtlGet := Sa;
   8: CtlGet := Mos;
   9: CtlGet := Vol;
   10: CtlGet := TInL;
   11: CtlGet := TOutL;
   20: CtlGet := Ord((Fl And CF_MIRH) <> 0);
   21: CtlGet := Ord((Fl And CF_MIRV) <> 0);
   22: CtlGet := Ord((Fl And CF_INV) <> 0);
   23: CtlGet := Ord(Mute);
   24: CtlGet := Ord((Fl And CF_OFF) <> 0);
   30: CtlGet := TIn;
   31: CtlGet := TOut;
  End;
End;

Procedure CtlSet(C: Integer; Id, V: Integer);
Var
 Bit: Integer;
Begin
 If (C < 0) Or (C >= P.NC) Then Exit;
 With P.Clips[C] Do
  Case Id Of
   1: PosX := V;
   2: PosY := V;
   3: Scale := V;
   4: Opac := V;
   5: Br := V;
   6: Co := V;
   7: Sa := V;
   8: Mos := V;
   9: Vol := V;
   10: TInL := V;
   11: TOutL := V;
   20, 21, 22, 24: Begin
    Case Id Of
     20: Bit := CF_MIRH;
     21: Bit := CF_MIRV;
     22: Bit := CF_INV;
    Else Bit := CF_OFF;
    End;
    If V <> 0 Then Fl := Fl Or Bit Else Fl := Fl And (Not Bit);
   End;
   23: Mute := V <> 0;
   30: TIn := V;
   31: TOut := V;
  End;
End;

Procedure CtlAdd(K, Id: Integer);
Begin
 If CtlN < MAXCTL Then Begin
  CtlKind[CtlN] := K;
  CtlId[CtlN] := Id;
  Inc(CtlN);
 End;
End;

Procedure BuildCtl;
Var
 C: Integer;
Begin
 CtlN := 0;
 C := FirstSel;
 If C < 0 Then Exit;
 If IsVideoTrack(P.Clips[C].Trk) Then Begin
  CtlAdd(3, 40); CtlAdd(0, 1); CtlAdd(0, 2); CtlAdd(0, 3); CtlAdd(0, 4);
  CtlAdd(3, 41); CtlAdd(0, 5); CtlAdd(0, 6); CtlAdd(0, 7);
  CtlAdd(3, 42); CtlAdd(0, 8); CtlAdd(1, 20); CtlAdd(1, 21); CtlAdd(1, 22); CtlAdd(1, 24);
  CtlAdd(3, 43); CtlAdd(2, 30); CtlAdd(0, 10); CtlAdd(2, 31); CtlAdd(0, 11);
 End Else Begin
  CtlAdd(3, 44); CtlAdd(0, 9); CtlAdd(1, 23); CtlAdd(1, 24);
  CtlAdd(3, 43); CtlAdd(2, 30); CtlAdd(0, 10); CtlAdd(2, 31); CtlAdd(0, 11);
 End;
End;

Const
 CTLH = 12;
 CTLROWS = 13;

Function CtlRowY(I: Integer): Integer;
Begin
 CtlRowY := AY1 + 45 + (I - CtlScroll) * CTLH;
End;

Function CtlSliderX1: Integer;
Begin
 CtlSliderX1 := AX1 + 104;
End;

Function CtlSliderX2: Integer;
Begin
 CtlSliderX2 := AX1 + 236;
End;

Function TransName(Id, V: Integer): String;
Begin
 If (Id = 30) Or (Id = 31) Then Begin
  If (FirstSel >= 0) And (Not IsVideoTrack(P.Clips[FirstSel].Trk)) Then Begin
   If V = 0 Then TransName := 'Aucune' Else TransName := 'Fondu audio';
   Exit;
  End;
 End;
 If V <= 4 Then TransName := TrNames[V] Else TransName := '?';
End;

Procedure DrawControls;
Var
 I, Y, C, V, X1, X2, T: Integer;
Begin
 PanelBox(AX1, AY1, AX2, AY2);
 DrawTabs(AX1, AY1, AX2, 2, 1, TabNA);
 BuildCtl;
 C := FirstSel;
 If C < 0 Then Begin
  Txt(AX1 + 10, AY1 + 24, 'Sélectionnez un clip dans la', DarkGray);
  Txt(AX1 + 10, AY1 + 36, 'séquence pour modifier ses effets.', DarkGray);
  Exit;
 End;
 Txt(AX1 + 6, AY1 + 18, Fit('Clip : ' + P.Clips[C].Name, 280), LightCyan);
 Txt(AX1 + 6, AY1 + 29, TC(P.Clips[C].Start) + ' - ' + TC(ClipEnd(C)), DarkGray);
 HLine(AX1 + 1, AX2 - 1, AY1 + 42, DarkGray);
 If CtlN > CTLROWS Then Begin
  Btn(AX2 - 14, AY1 + 17, AX2 - 4, AY1 + 26, False);
  IcoTri(AX2 - 9, AY1 + 19, AX2 - 12, AY1 + 24, AX2 - 6, AY1 + 24, White);
  Btn(AX2 - 14, AY1 + 28, AX2 - 4, AY1 + 37, False);
  IcoTri(AX2 - 9, AY1 + 35, AX2 - 12, AY1 + 30, AX2 - 6, AY1 + 30, White);
 End;
 X1 := CtlSliderX1;
 X2 := CtlSliderX2;
 For I := CtlScroll To Min(CtlN - 1, CtlScroll + CTLROWS - 1) Do Begin
  Y := CtlRowY(I);
  V := CtlGet(C, CtlId[I]);
  Case CtlKind[I] Of
   3: Begin
    FillR(AX1 + 2, Y, AX2 - 2, Y + CTLH - 2, DarkGray);
    Txt(AX1 + 6, Y + 2, CtlLabel(CtlId[I]), White);
   End;
   0: Begin
    Txt(AX1 + 10, Y + 2, CtlLabel(CtlId[I]), LightGray);
    HLine(X1, X2, Y + 5, DarkGray);
    HLine(X1, X2, Y + 6, DarkGray);
    T := X1 + Integer(((V - CtlMin(CtlId[I])) * LongInt(X2 - X1)) Div
         (CtlMax(CtlId[I]) - CtlMin(CtlId[I])));
    FillR(T - 2, Y + 1, T + 2, Y + 10, LightCyan);
    TxtR(AX2 - 8, Y + 2, IStr(V), White);
   End;
   1: Begin
    Frame(AX1 + 10, Y + 1, AX1 + 18, Y + 9, LightGray);
    If V <> 0 Then FillR(AX1 + 12, Y + 3, AX1 + 16, Y + 7, LightCyan);
    Txt(AX1 + 24, Y + 2, CtlLabel(CtlId[I]), LightGray);
   End;
   2: Begin
    Txt(AX1 + 10, Y + 2, CtlLabel(CtlId[I]), LightGray);
    FillR(X1, Y, X2, Y + CTLH - 3, DarkGray);
    Txt(X1 + 4, Y + 2, TransName(CtlId[I], V), White);
   End;
  End;
 End;
End;

Function CtlHit(X, Y: LongInt): Integer;
Var
 I, YY: Integer;
Begin
 CtlHit := -1;
 For I := CtlScroll To Min(CtlN - 1, CtlScroll + CTLROWS - 1) Do Begin
  YY := CtlRowY(I);
  If InRect(X, Y, AX1 + 2, YY, AX2 - 2, YY + CTLH - 2) Then Begin
   CtlHit := I;
   Exit;
  End;
 End;
End;

{ ====================================================================== }
{  Panneau Projet / Effets / Marqueurs                                   }
{ ====================================================================== }

Const
 PROWH = 20;
 PROWY0 = 279;

Function ProjRows: Integer;
Begin
 ProjRows := (CY2 - 24 - PROWY0) Div PROWH;
End;

Function ProjHit(X, Y: LongInt): Integer;
Var
 R: Integer;
Begin
 ProjHit := -1;
 If (X < CX1 + 1) Or (X > CX2 - 14) Or (Y < PROWY0) Then Exit;
 R := (Y - PROWY0) Div PROWH;
 If R >= ProjRows Then Exit;
 R := R + ProjScroll;
 If R < P.NM Then ProjHit := R;
End;

Procedure RenderThumb(OX, OY, TWd, THt: Integer; M: Integer);
Var
 X, Y: Integer;
 T: LongInt;
Begin
 If MediaAudio(M) Then Begin
  FillR(OX, OY, OX + TWd - 1, OY + THt - 1, Green);
  SetColor(LightGreen);
  For X := 0 To TWd - 1 Do
   Line(OX + X, OY + THt Div 2 - Abs(Sn(X * 23 + M * 7)) * (THt Div 2 - 1) Div 127,
        OX + X, OY + THt Div 2 + Abs(Sn(X * 23 + M * 7)) * (THt Div 2 - 1) Div 127);
  Exit;
 End;
 T := Min(P.Media[M].Dur Div 2, 40);
 SetupLayer(Lay[0], M, T);
 NLay := 1;
 CL := 0;
 For Y := 0 To THt - 1 Do
  For X := 0 To TWd - 1 Do Begin
   Compose((X * VW) Div TWd, (Y * VH) Div THt);
   PutPixel(OX + X, OY + Y, QuantColor(X, Y));
  End;
End;

Procedure DrawProject;
Var
 I, R, Y: Integer;
 S: String;
Begin
 PanelBox(CX1, CY1, CX2, CY2);
 DrawTabs(CX1, CY1, CX2, 3, 0, TabNC);
 Txt(CX1 + 6, CY1 + 18, Fit(P.Name, 150), White);
 TxtR(CX2 - 6, CY1 + 18, IStr(P.NM) + ' élém.', DarkGray);
 HLine(CX1 + 1, CX2 - 1, PROWY0 - 3, DarkGray);
 For R := 0 To ProjRows - 1 Do Begin
  I := R + ProjScroll;
  If I >= P.NM Then Break;
  Y := PROWY0 + R * PROWH;
  If I = ProjSel Then FillR(CX1 + 1, Y, CX2 - 14, Y + PROWH - 1, Blue);
  RenderThumb(CX1 + 3, Y + 1, 32, 18, I);
  Txt(CX1 + 40, Y + 2, Fit(P.Media[I].Name, CX2 - CX1 - 58), White);
  If MediaAudio(I) Then S := 'Audio ' + TCShort(P.Media[I].Dur)
  Else If MediaUnlimited(I) Then S := KindName(P.Media[I].Kind)
  Else S := 'Vidéo ' + TCShort(P.Media[I].Dur);
  Txt(CX1 + 40, Y + 11, Fit(S, CX2 - CX1 - 58), LightGray);
 End;
 { Defilement }
 Btn(CX2 - 12, PROWY0, CX2 - 2, PROWY0 + 10, False);
 IcoTri(CX2 - 7, PROWY0 + 3, CX2 - 10, PROWY0 + 8, CX2 - 4, PROWY0 + 8, White);
 Btn(CX2 - 12, CY2 - 36, CX2 - 2, CY2 - 26, False);
 IcoTri(CX2 - 7, CY2 - 29, CX2 - 10, CY2 - 34, CX2 - 4, CY2 - 34, White);
 { Boutons }
 Btn(CX1 + 3, CY2 - 21, CX1 + 52, CY2 - 3, False);
 TxtC(CX1 + 28, CY2 - 16, 'Import.', White);
 Btn(CX1 + 54, CY2 - 21, CX1 + 103, CY2 - 3, False);
 TxtC(CX1 + 79, CY2 - 16, 'Nouveau', White);
 Btn(CX1 + 105, CY2 - 21, CX1 + 154, CY2 - 3, False);
 TxtC(CX1 + 130, CY2 - 16, 'Séquen.', White);
 Btn(CX1 + 156, CY2 - 21, CX2 - 3, CY2 - 3, False);
 TxtC((CX1 + 156 + CX2 - 3) Div 2, CY2 - 16, 'Suppr.', White);
End;

Function ProjBtnHit(X, Y: LongInt): Integer;
Begin
 ProjBtnHit := -1;
 If (Y < CY2 - 21) Or (Y > CY2 - 3) Then Exit;
 If InRect(X, Y, CX1 + 3, CY2 - 21, CX1 + 52, CY2 - 3) Then ProjBtnHit := 0
 Else If InRect(X, Y, CX1 + 54, CY2 - 21, CX1 + 103, CY2 - 3) Then ProjBtnHit := 1
 Else If InRect(X, Y, CX1 + 105, CY2 - 21, CX1 + 154, CY2 - 3) Then ProjBtnHit := 2
 Else If InRect(X, Y, CX1 + 156, CY2 - 21, CX2 - 3, CY2 - 3) Then ProjBtnHit := 3;
End;

{ Arbre des effets : lignes affichees }
Var
 EffRowKind: Array[0..40] Of Integer;  { 0 groupe, 1 effet }
 EffRowId: Array[0..40] Of Integer;
 EffRowN: Integer;

Procedure BuildEffRows;
Var
 G, E: Integer;
Begin
 EffRowN := 0;
 For G := 0 To NGRP - 1 Do Begin
  EffRowKind[EffRowN] := 0;
  EffRowId[EffRowN] := G;
  Inc(EffRowN);
  If GrpOpen[G] Then
   For E := 0 To NEFF - 1 Do
    If EffGrp[E] = G Then Begin
     EffRowKind[EffRowN] := 1;
     EffRowId[EffRowN] := E;
     Inc(EffRowN);
    End;
 End;
End;

Const
 EROWH = 11;
 EROWY0 = 294;

Function EffRows: Integer;
Begin
 EffRows := (CY2 - 25 - EROWY0) Div EROWH;
End;

Function EffHit(X, Y: LongInt): Integer;
Var
 R: Integer;
Begin
 EffHit := -1;
 If (X < CX1 + 1) Or (X > CX2 - 14) Or (Y < EROWY0) Then Exit;
 R := (Y - EROWY0) Div EROWH;
 If R >= EffRows Then Exit;
 R := R + EffScroll;
 If R < EffRowN Then EffHit := R;
End;

Procedure DrawEffects;
Var
 R, I, Y: Integer;
Begin
 PanelBox(CX1, CY1, CX2, CY2);
 DrawTabs(CX1, CY1, CX2, 3, 1, TabNC);
 Txt(CX1 + 6, CY1 + 17, 'Bibliothèque d''effets', White);
 Txt(CX1 + 6, CY1 + 28, 'Double-clic : appliquer', DarkGray);
 HLine(CX1 + 1, CX2 - 1, EROWY0 - 3, DarkGray);
 BuildEffRows;
 If EffScroll > Max(0, EffRowN - EffRows) Then EffScroll := Max(0, EffRowN - EffRows);
 For R := 0 To EffRows - 1 Do Begin
  I := R + EffScroll;
  If I >= EffRowN Then Break;
  Y := EROWY0 + R * EROWH;
  If EffRowKind[I] = 0 Then Begin
   If GrpOpen[EffRowId[I]] Then Txt(CX1 + 4, Y + 1, '-', LightGray)
   Else Txt(CX1 + 4, Y + 1, '+', LightGray);
   Txt(CX1 + 16, Y + 1, GrpName[EffRowId[I]], White);
  End Else Begin
   If EffRowId[I] = EffSel Then FillR(CX1 + 1, Y, CX2 - 14, Y + EROWH - 1, Blue);
   Txt(CX1 + 26, Y + 1, EffName[EffRowId[I]], LightGray);
  End;
 End;
 Btn(CX2 - 12, EROWY0, CX2 - 2, EROWY0 + 10, False);
 IcoTri(CX2 - 7, EROWY0 + 3, CX2 - 10, EROWY0 + 8, CX2 - 4, EROWY0 + 8, White);
 Btn(CX2 - 12, CY2 - 38, CX2 - 2, CY2 - 28, False);
 IcoTri(CX2 - 7, CY2 - 31, CX2 - 10, CY2 - 36, CX2 - 4, CY2 - 36, White);
 Btn(CX1 + 3, CY2 - 21, CX2 - 3, CY2 - 3, False);
 TxtC((CX1 + CX2) Div 2, CY2 - 16, 'Appliquer à la sélection', White);
End;

Procedure DrawMarkersTab;
Var
 R, I, Y: Integer;
Begin
 PanelBox(CX1, CY1, CX2, CY2);
 DrawTabs(CX1, CY1, CX2, 3, 2, TabNC);
 Txt(CX1 + 6, CY1 + 17, IStr(P.NK) + ' marqueur(s)', White);
 HLine(CX1 + 1, CX2 - 1, EROWY0 - 3, DarkGray);
 For R := 0 To EffRows - 1 Do Begin
  I := R + MarkScroll;
  If I >= P.NK Then Break;
  Y := EROWY0 + R * EROWH;
  If I = MarkSel Then FillR(CX1 + 1, Y, CX2 - 14, Y + EROWH - 1, Blue);
  Txt(CX1 + 4, Y + 1, TC(P.Marks[I].Pos), LightGreen);
  Txt(CX1 + 100, Y + 1, Fit(P.Marks[I].Name, 90), White);
 End;
 Btn(CX1 + 3, CY2 - 21, CX1 + 100, CY2 - 3, False);
 TxtC(CX1 + 51, CY2 - 16, 'Ajouter', White);
 Btn(CX1 + 102, CY2 - 21, CX2 - 3, CY2 - 3, False);
 TxtC((CX1 + 102 + CX2 - 3) Div 2, CY2 - 16, 'Supprimer', White);
End;

Procedure DrawPanelC;
Begin
 Case TabC Of
  0: DrawProject;
  1: DrawEffects;
 Else DrawMarkersTab;
 End;
End;

Procedure DrawPanelA;
Begin
 If TabA = 1 Then DrawControls Else DrawMonitor(False);
End;

{ ====================================================================== }
{  Outils et chronologie                                                 }
{ ====================================================================== }

Function ToolBtnY(I: Integer): Integer;
Begin
 ToolBtnY := TY1 + 16 + I * 24;
End;

Procedure DrawTools;
Var
 I, Y: Integer;
Begin
 PanelBox(TX1, TY1, TX2, TY2);
 FillR(TX1 + 1, TY1 + 1, TX2 - 1, TY1 + 13, DarkGray);
 For I := 0 To 6 Do Begin
  Y := ToolBtnY(I);
  If I = CurTool Then Begin
   FillR(TX1 + 1, Y, TX2 - 1, Y + 22, Blue);
   Frame(TX1 + 1, Y, TX2 - 1, Y + 22, LightCyan);
   ToolIcon(I, TX1, Y, White);
  End Else Begin
   Btn(TX1 + 1, Y, TX2 - 1, Y + 22, False);
   ToolIcon(I, TX1, Y, LightGray);
  End;
 End;
 Y := TY2 - 26;
 If SnapOn Then Begin
  FillR(TX1 + 1, Y, TX2 - 1, Y + 22, Blue);
  Frame(TX1 + 1, Y, TX2 - 1, Y + 22, LightCyan);
  TxtC((TX1 + TX2) Div 2 + 1, Y + 7, 'S', White);
 End Else Begin
  Btn(TX1 + 1, Y, TX2 - 1, Y + 22, False);
  TxtC((TX1 + TX2) Div 2 + 1, Y + 7, 'S', LightGray);
 End;
End;

Function ToolHit(X, Y: LongInt): Integer;
Var
 I: Integer;
Begin
 ToolHit := -1;
 If (X < TX1) Or (X > TX2) Then Exit;
 For I := 0 To 6 Do
  If (Y >= ToolBtnY(I)) And (Y <= ToolBtnY(I) + 22) Then ToolHit := I;
 If (Y >= TY2 - 26) And (Y <= TY2 - 4) Then ToolHit := 7;
End;

Function ClipBody(I: Integer): Integer;
Var
 K: Integer;
Begin
 K := P.Media[P.Clips[I].Med].Kind;
 If (P.Clips[I].Fl And CF_OFF) <> 0 Then ClipBody := DarkGray
 Else If K >= 20 Then ClipBody := Green
 Else If K = MK_TITLE Then ClipBody := Cyan
 Else If K = MK_SOLID Then ClipBody := Magenta
 Else If K = MK_IMAGE Then ClipBody := Brown
 Else ClipBody := Blue;
End;

Function ClipStrip(I: Integer): Integer;
Var
 K: Integer;
Begin
 K := P.Media[P.Clips[I].Med].Kind;
 If (P.Clips[I].Fl And CF_OFF) <> 0 Then ClipStrip := LightGray
 Else If K >= 20 Then ClipStrip := LightGreen
 Else If K = MK_TITLE Then ClipStrip := LightCyan
 Else If K = MK_SOLID Then ClipStrip := LightMagenta
 Else If K = MK_IMAGE Then ClipStrip := Yellow
 Else ClipStrip := LightBlue;
End;

Procedure DrawClipBox(I: Integer);
Var
 X1, X2, XA, XB, Y1, Y2, W, X, H, YM, NameW: Integer;
 F: LongInt;
 Sel: Boolean;
 Body, Strip, TxtC2: Integer;
Begin
 X1 := FrameToX(P.Clips[I].Start);
 X2 := FrameToX(ClipEnd(I)) - 1;
 If (X2 < TLX0) Or (X1 > TLX1) Then Exit;
 XA := Max(X1, TLX0);
 XB := Min(X2, TLX1);
 If XB < XA Then Exit;
 Y1 := RowY(TrackRow(P.Clips[I].Trk)) + 1;
 Y2 := Y1 + TRH - 3;
 Sel := P.Clips[I].Sel;
 Body := ClipBody(I);
 Strip := ClipStrip(I);
 If Sel Then Begin
  If Body = Blue Then Body := LightBlue
  Else If Body = Green Then Body := LightGreen;
  Strip := White;
 End;
 FillR(XA, Y1, XB, Y2, Body);
 FillR(XA, Y1, XB, Y1 + 8, Strip);
 If Strip = White Then TxtC2 := Black Else TxtC2 := Black;
 NameW := XB - XA - 4;
 If ClipHasFx(P.Clips[I]) And (NameW > 40) Then Begin
  Txt(XB - 17, Y1 + 1, 'fx', Red);
  NameW := NameW - 18;
 End;
 If NameW >= 8 Then Txt(XA + 3, Y1 + 1, Fit(P.Clips[I].Name, NameW), TxtC2);
 { Transitions }
 If (P.Clips[I].TIn > 0) And (X1 >= TLX0) Then Begin
  W := FrameToX(P.Clips[I].Start + P.Clips[I].TInL) - X1;
  If W > 2 Then Begin
   If X1 + W > TLX1 Then W := TLX1 - X1;
   IcoTri(X1, Y1 + 9, X1 + W, Y1 + 9, X1, Y2, Black);
   Line(X1, Y2, X1 + W, Y1 + 9);
  End;
 End;
 If (P.Clips[I].TOut > 0) And (X2 <= TLX1) Then Begin
  W := X2 + 1 - FrameToX(ClipEnd(I) - P.Clips[I].TOutL);
  If W > 2 Then Begin
   If X2 - W < TLX0 Then W := X2 - TLX0;
   IcoTri(X2, Y1 + 9, X2 - W, Y1 + 9, X2, Y2, Black);
   SetColor(White);
   Line(X2, Y2, X2 - W, Y1 + 9);
  End;
 End;
 { Forme d'onde audio }
 If WaveOn And (P.Clips[I].Trk >= 3) And (Not P.Clips[I].Mute) Then Begin
  YM := (Y1 + 9 + Y2) Div 2;
  SetColor(Black);
  X := XA;
  While X <= XB Do Begin
   F := XToFrame(X) - P.Clips[I].Start;
   H := Abs(Sn(F * 13 + P.Clips[I].Med * 29)) * 6 Div 127 +
        (Hash3(F, P.Clips[I].Med, 5) Mod 4);
   H := H * (100 + P.Clips[I].Vol * 3) Div 100;
   If H > (Y2 - Y1 - 10) Div 2 Then H := (Y2 - Y1 - 10) Div 2;
   If H < 0 Then H := 0;
   Line(X, YM - H, X, YM + H);
   Inc(X, 2);
  End;
 End;
 If Sel Then Frame(XA, Y1, XB, Y2, White)
 Else Frame(XA, Y1, XB, Y2, Black);
 { Poignees d'ajustement }
 If Sel And (CurTool <> TL_HAND) Then Begin
  If X1 >= TLX0 Then FillR(X1, Y1, X1 + 1, Y2, Yellow);
  If X2 <= TLX1 Then FillR(X2 - 1, Y1, X2, Y2, Yellow);
 End;
End;

Procedure DrawRuler;
Var
 Step, Sec, X, K: LongInt;
 Fp, I: Integer;
 Steps: Array[0..11] Of LongInt;
 XA, XB: LongInt;
Begin
 Fp := P.Fps;
 FillR(TLX0, RULY1, TLX1, RULY2, DarkGray);
 { Zone entree / sortie }
 If (P.InM >= 0) Or (P.OutM >= 0) Then Begin
  If P.InM >= 0 Then XA := FrameToX(P.InM) Else XA := TLX0;
  If P.OutM >= 0 Then XB := FrameToX(P.OutM) Else XB := TLX1;
  XA := Max(XA, TLX0);
  XB := Min(XB, TLX1);
  If XB >= XA Then FillR(XA, RULY1, XB, RULY2, Blue);
 End;
 Steps[0] := 1; Steps[1] := 2; Steps[2] := 5; Steps[3] := 10; Steps[4] := 15;
 Steps[5] := 30; Steps[6] := 60; Steps[7] := 120; Steps[8] := 300; Steps[9] := 600;
 Steps[10] := 1800; Steps[11] := 3600;
 Step := 3600;
 For I := 11 Downto 0 Do
  If Steps[I] * PPS >= 60 Then Step := Steps[I];
 Sec := (ScrollF Div Fp) Div Step * Step;
 SetColor(LightGray);
 While True Do Begin
  X := FrameToX(Sec * Fp);
  If X > TLX1 Then Break;
  If X >= TLX0 Then Begin
   Line(X, RULY2 - 6, X, RULY2);
   If X + 36 <= TLX1 Then Txt(X + 2, RULY1 + 1, TCShort(Sec * Fp), White);
   SetColor(LightGray);
  End;
  If Step >= 2 Then
   For K := 1 To 4 Do Begin
    X := FrameToX(Sec * Fp + (K * Step * Fp) Div 5);
    If (X >= TLX0) And (X <= TLX1) Then Line(X, RULY2 - 2, X, RULY2);
   End;
  Sec := Sec + Step;
 End;
 If PPS Div Fp >= 4 Then Begin
  SetColor(DarkGray);
  K := ScrollF;
  While True Do Begin
   X := FrameToX(K);
   If X > TLX1 Then Break;
   If X >= TLX0 Then Line(X, RULY2 - 1, X, RULY2);
   Inc(K);
  End;
 End;
 { Marqueurs }
 For I := 0 To P.NK - 1 Do Begin
  X := FrameToX(P.Marks[I].Pos);
  If (X >= TLX0) And (X <= TLX1) Then
   IcoTri(X - 3, RULY2 - 6, X + 3, RULY2 - 6, X, RULY2, LightGreen);
 End;
 Frame(TLX0, RULY1, TLX1, RULY2, Black);
End;

Procedure DrawTimeline;
Var
 R, T, I, Y, X, TW0, TL0: Integer;
 Vis, Tot: LongInt;
Begin
 PanelBox(LX1, LY1, LX2, LY2);
 { En-tete }
 SetTextStyle(DefaultFont, HorizDir, 2);
 Txt(LX1 + 4, LY1 + 3, TC(Playhead), LightCyan);
 SetTextStyle(DefaultFont, HorizDir, 1);
 Btn(LX1 + 190, LY1 + 2, LX1 + 207, LY1 + 17, SnapOn);
 TxtC(LX1 + 199, LY1 + 7, 'S', White);
 Btn(LX1 + 210, LY1 + 2, LX1 + 227, LY1 + 17, False);
 IcoTri(LX1 + 213, LY1 + 5, LX1 + 224, LY1 + 5, LX1 + 218, LY1 + 14, LightGreen);
 Btn(LX1 + 230, LY1 + 2, LX1 + 247, LY1 + 17, False);
 TxtC(LX1 + 239, LY1 + 7, '-', White);
 Btn(LX1 + 250, LY1 + 2, LX1 + 267, LY1 + 17, False);
 TxtC(LX1 + 259, LY1 + 7, '+', White);
 Btn(LX1 + 270, LY1 + 2, LX1 + 287, LY1 + 17, False);
 TxtC(LX1 + 279, LY1 + 7, '<>', White);
 Txt(LX1 + 294, LY1 + 7, Fit(P.Name, 80), LightGray);
 HLine(LX1 + 1, LX2 - 1, LY1 + 19, DarkGray);
 { Pistes }
 For R := 0 To NTRK - 1 Do Begin
  T := RowTrack(R);
  Y := RowY(R);
  FillR(LX1 + 1, Y, TLX0 - 2, Y + TRH - 1, DarkGray);
  FillR(TLX0, Y, TLX1, Y + TRH - 1, Black);
  HLine(LX1 + 1, TLX1, Y + TRH - 1, DarkGray);
  Txt(LX1 + 4, Y + 9, TrackName(T), White);
  If (P.TrkF[T] And TF_HIDE) <> 0 Then Begin
   If T < 3 Then Btn(LX1 + 26, Y + 7, LX1 + 38, Y + 19, True)
   Else Btn(LX1 + 26, Y + 7, LX1 + 38, Y + 19, True);
   Txt(LX1 + 29, Y + 10, 'x', LightRed);
  End Else Begin
   Btn(LX1 + 26, Y + 7, LX1 + 38, Y + 19, False);
   If T < 3 Then Txt(LX1 + 29, Y + 10, 'o', LightCyan) Else Txt(LX1 + 29, Y + 10, 'M', LightGreen);
  End;
  If (P.TrkF[T] And TF_LOCK) <> 0 Then Begin
   Btn(LX1 + 42, Y + 7, LX1 + 54, Y + 19, True);
   Txt(LX1 + 45, Y + 10, 'L', Yellow);
  End Else Begin
   Btn(LX1 + 42, Y + 7, LX1 + 54, Y + 19, False);
   Txt(LX1 + 45, Y + 10, 'l', LightGray);
  End;
  If (P.TrkF[T] And TF_LOCK) <> 0 Then Begin
   SetColor(DarkGray);
   Y := Y + 1;
   X := TLX0;
   While X < TLX1 Do Begin
    Line(X, Y, X + 6, Y + TRH - 3);
    Inc(X, 12);
   End;
  End;
 End;
 HLine(LX1 + 1, TLX1, RowY(3) - 1, LightGray);
 For I := 0 To P.NC - 1 Do DrawClipBox(I);
 DrawRuler;
 { Tete de lecture }
 X := FrameToX(Playhead);
 If (X >= TLX0) And (X <= TLX1) Then Begin
  VLine(X, RULY1 + 4, RowY(NTRK) - 1, LightBlue);
  IcoTri(X - 4, RULY1, X + 4, RULY1, X, RULY1 + 6, LightBlue);
 End;
 { Guide de magnetisme }
 If (SnapGuide >= 0) And (DragMode <> DM_NONE) Then Begin
  X := FrameToX(SnapGuide);
  If (X >= TLX0) And (X <= TLX1) Then VLine(X, RULY2, RowY(NTRK) - 1, White);
 End;
 { Rectangle de selection }
 If DragMode = DM_MARQUEE Then Begin
  SetColor(White);
  SetLineStyle(DottedLn, 0, 1);
  Rectangle(Integer(Min(MqX0, MqX1)), Integer(Min(MqY0, MqY1)),
            Integer(Max(MqX0, MqX1)), Integer(Max(MqY0, MqY1)));
  SetLineStyle(SolidLn, 0, 1);
 End;
 { Defilement horizontal }
 FillR(TLX0, HSY1, TLX1, HSY2, DarkGray);
 Vis := VisFrames;
 Tot := Max(SeqEnd + P.Fps * 10, ScrollF + Vis);
 TW0 := Integer((Vis * (TLX1 - TLX0)) Div Tot);
 If TW0 < 12 Then TW0 := 12;
 TL0 := TLX0 + Integer((ScrollF * (TLX1 - TLX0)) Div Tot);
 If TL0 + TW0 > TLX1 Then TL0 := TLX1 - TW0;
 FillR(TL0, HSY1 + 1, TL0 + TW0, HSY2 - 1, LightGray);
 Frame(TLX0, HSY1, TLX1, HSY2, Black);
End;

Function HScrollThumb(Var TL0, TW0: Integer): LongInt;
Var
 Tot: LongInt;
 Vis: LongInt;
Begin
 Vis := VisFrames;
 Tot := Max(SeqEnd + P.Fps * 10, ScrollF + Vis);
 TW0 := Integer((Vis * (TLX1 - TLX0)) Div Tot);
 If TW0 < 12 Then TW0 := 12;
 TL0 := TLX0 + Integer((ScrollF * (TLX1 - TLX0)) Div Tot);
 If TL0 + TW0 > TLX1 Then TL0 := TLX1 - TW0;
 HScrollThumb := Tot;
End;

Function TLHdrBtn(X, Y: LongInt): Integer;
Begin
 TLHdrBtn := -1;
 If (Y < LY1 + 2) Or (Y > LY1 + 17) Then Exit;
 If InRect(X, Y, LX1 + 190, LY1 + 2, LX1 + 207, LY1 + 17) Then TLHdrBtn := 0
 Else If InRect(X, Y, LX1 + 210, LY1 + 2, LX1 + 227, LY1 + 17) Then TLHdrBtn := 1
 Else If InRect(X, Y, LX1 + 230, LY1 + 2, LX1 + 247, LY1 + 17) Then TLHdrBtn := 2
 Else If InRect(X, Y, LX1 + 250, LY1 + 2, LX1 + 267, LY1 + 17) Then TLHdrBtn := 3
 Else If InRect(X, Y, LX1 + 270, LY1 + 2, LX1 + 287, LY1 + 17) Then TLHdrBtn := 4;
End;

{ ====================================================================== }
{  Vumetres, barre d'etat, dessin complet                                }
{ ====================================================================== }

Procedure DrawMeterBar(X, Lvl, Peak: Integer);
Var
 I, N, Y, C, PY: Integer;
Begin
 N := 36;
 For I := 0 To N - 1 Do Begin
  Y := LY2 - 20 - I * 5;
  If I * 100 Div N < Lvl Then Begin
   If I >= 31 Then C := LightRed
   Else If I >= 24 Then C := Yellow
   Else C := LightGreen;
   FillR(X, Y - 3, X + 5, Y, C);
  End Else FillR(X, Y - 3, X + 5, Y, DarkGray);
 End;
 PY := LY2 - 20 - (Peak * N Div 100) * 5;
 If Peak > 3 Then HLine(X, X + 5, PY, White);
End;

Procedure DrawMeters;
Begin
 PanelBox(MX1, LY1, MX2, LY2);
 FillR(MX1 + 1, LY1 + 1, MX2 - 1, LY1 + 13, DarkGray);
 DrawMeterBar(MX1 + 2, LevelL, PeakL);
 DrawMeterBar(MX1 + 9, LevelR, PeakR);
 Txt(MX1 + 2, LY2 - 12, 'G', LightGray);
 Txt(MX1 + 9, LY2 - 12, 'D', LightGray);
End;

Procedure DrawStatus;
Var
 S: String;
Begin
 FillR(0, SH - 18, SW - 1, SH - 1, Black);
 HLine(0, SW - 1, SH - 18, DarkGray);
 If StatusMsg <> '' Then S := StatusMsg
 Else S := 'Outil : ' + ToolNames[CurTool];
 Txt(6, SH - 12, Fit(S, 430), LightGray);
 TxtR(SW - 6, SH - 12, IStr(P.Fps) + ' i/s  ' + IStr(SelCount) + ' sél.', DarkGray);
 If Modified Then Txt(SW - 200, SH - 12, '*', Yellow);
End;

Procedure DrawAll;
Begin
 HideMouse;
 FillR(0, 0, SW - 1, SH - 1, Black);
 DrawMenuBar;
 DrawWorkspaces;
 DrawPanelA;
 DrawMonitor(True);
 DrawPanelC;
 DrawTools;
 DrawTimeline;
 DrawMeters;
 DrawStatus;
 If MenuActive Then DrawMenuDrop(ActiveMenu);
 ShowMouse;
 NeedAll := False; NeedProg := False; NeedSrc := False; NeedTL := False;
 NeedMeters := False; NeedA := False; NeedC := False; NeedStatus := False;
End;

Procedure InvAll;
Begin
 NeedAll := True;
End;

Procedure Refresh;
Begin
 If NeedAll Or MenuActive Then Begin
  If NeedAll Then DrawAll;
  Exit;
 End;
 If NeedProg Or NeedSrc Or NeedTL Or NeedMeters Or NeedA Or NeedC Or NeedStatus Then Begin
  HideMouse;
  If NeedA Or NeedSrc Then Begin DrawPanelA; NeedA := False; NeedSrc := False; End;
  If NeedProg Then Begin DrawMonitor(True); NeedProg := False; End;
  If NeedC Then Begin DrawPanelC; NeedC := False; End;
  If NeedTL Then Begin DrawTimeline; NeedTL := False; End;
  If NeedMeters Then Begin DrawMeters; NeedMeters := False; End;
  If NeedStatus Then Begin DrawStatus; NeedStatus := False; End;
  ShowMouse;
 End;
End;

Procedure Msg(S: String);
Begin
 StatusMsg := S;
 MsgT0 := Ticks;
 NeedStatus := True;
End;

{ ====================================================================== }
{  Entrees : souris, clavier, boites de dialogue                         }
{ ====================================================================== }

Procedure PollMouse;
Var
 T: LongInt;
Begin
 GetMouseState(MX, MY, MB);
 PressL := ((MB And 1) <> 0) And ((OldMB And 1) = 0);
 PressR := ((MB And 2) <> 0) And ((OldMB And 2) = 0);
 RelL := ((MB And 1) = 0) And ((OldMB And 1) <> 0);
 DblClick := False;
 If PressL Then Begin
  T := Ticks;
  If (TickDiff(T, LastClickT) < 45) And (Abs(MX - LastClickX) < 6) And
     (Abs(MY - LastClickY) < 6) Then Begin
   DblClick := True;
   LastClickT := -100000;
  End Else LastClickT := T;
  LastClickX := MX;
  LastClickY := MY;
 End;
 OldMB := MB;
End;

Function ReadKeyCode: Integer;
Var
 K: Char;
Begin
 ReadKeyCode := 0;
 If Not KeyPressed Then Exit;
 K := ReadKey;
 If K = #0 Then Begin
  If KeyPressed Then ReadKeyCode := 256 + Ord(ReadKey);
 End Else ReadKeyCode := Ord(K);
End;

Procedure WaitRelease;
Begin
 Repeat
  GetMouseState(MX, MY, MB);
  Delay(5);
 Until (MB And 3) = 0;
 OldMB := 0;
End;

{ Une boite de dialogue interrompt toujours la lecture. }
Procedure DlgPause;
Begin
 If Playing Then Begin
  Playing := False;
  PlayTarget := 0;
  StopSound;
  LevelL := 0;
  LevelR := 0;
 End;
End;

Procedure DlgBox(X, Y, W, H: Integer; Title: String);
Begin
 DlgPause;
 FillR(X + 4, Y + 4, X + W + 4, Y + H + 4, Black);
 FillR(X, Y, X + W, Y + H, LightGray);
 HLine(X, X + W, Y, White);
 VLine(X, Y, Y + H, White);
 HLine(X, X + W, Y + H, DarkGray);
 VLine(X + W, Y, Y + H, DarkGray);
 FillR(X + 3, Y + 3, X + W - 3, Y + 16, Blue);
 Txt(X + 8, Y + 6, Title, White);
End;

Procedure DlgBtn(X1, Y1, X2, Y2: Integer; Cap: String; Def: Boolean);
Begin
 FillR(X1, Y1, X2, Y2, LightGray);
 HLine(X1, X2, Y1, White);
 VLine(X1, Y1, Y2, White);
 HLine(X1, X2, Y2, DarkGray);
 VLine(X2, Y1, Y2, DarkGray);
 If Def Then Frame(X1 - 1, Y1 - 1, X2 + 1, Y2 + 1, Black);
 TxtC((X1 + X2) Div 2, Y1 + (Y2 - Y1 - 7) Div 2, Cap, Black);
End;

{ Boite de message : lignes separees par '|' }
Procedure MsgBox(Title, Msg: String);
Var
 Lines: Array[1..12] Of String;
 N, I, K, W, H, X, Y, BW: Integer;
 Done: Boolean;
 Code: Integer;
Begin
 N := 0;
 While (Msg <> '') And (N < 12) Do Begin
  K := Pos('|', Msg);
  Inc(N);
  If K = 0 Then Begin
   Lines[N] := Msg;
   Msg := '';
  End Else Begin
   Lines[N] := Copy(Msg, 1, K - 1);
   Delete(Msg, 1, K);
  End;
 End;
 W := Max(240, TW(Title) + 40);
 For I := 1 To N Do W := Max(W, TW(Lines[I]) + 40);
 If W > SW - 20 Then W := SW - 20;
 H := 62 + N * 12;
 X := (SW - W) Div 2;
 Y := (SH - H) Div 2;
 HideMouse;
 DlgBox(X, Y, W, H, Title);
 For I := 1 To N Do Txt(X + 20, Y + 28 + (I - 1) * 12, Lines[I], Black);
 BW := 70;
 DlgBtn(X + W Div 2 - BW Div 2, Y + H - 26, X + W Div 2 + BW Div 2, Y + H - 8, 'OK', True);
 ShowMouse;
 WaitRelease;
 Done := False;
 Repeat
  PollMouse;
  If PressL Then
   If InRect(MX, MY, X + W Div 2 - BW Div 2, Y + H - 26, X + W Div 2 + BW Div 2, Y + H - 8) Then
    Done := True;
  Code := ReadKeyCode;
  If (Code = 13) Or (Code = 27) Or (Code = 32) Then Done := True;
  Delay(10);
 Until Done;
 WaitRelease;
 DrawAll;
End;

Function Confirm(Title, Msg: String): Boolean;
Var
 Lines: Array[1..8] Of String;
 N, I, K, W, H, X, Y: Integer;
 Done, Res: Boolean;
 Code: Integer;
Begin
 N := 0;
 While (Msg <> '') And (N < 8) Do Begin
  K := Pos('|', Msg);
  Inc(N);
  If K = 0 Then Begin
   Lines[N] := Msg;
   Msg := '';
  End Else Begin
   Lines[N] := Copy(Msg, 1, K - 1);
   Delete(Msg, 1, K);
  End;
 End;
 W := Max(260, TW(Title) + 40);
 For I := 1 To N Do W := Max(W, TW(Lines[I]) + 40);
 If W > SW - 20 Then W := SW - 20;
 H := 62 + N * 12;
 X := (SW - W) Div 2;
 Y := (SH - H) Div 2;
 HideMouse;
 DlgBox(X, Y, W, H, Title);
 For I := 1 To N Do Txt(X + 20, Y + 28 + (I - 1) * 12, Lines[I], Black);
 DlgBtn(X + W Div 2 - 80, Y + H - 26, X + W Div 2 - 10, Y + H - 8, 'Oui', True);
 DlgBtn(X + W Div 2 + 10, Y + H - 26, X + W Div 2 + 80, Y + H - 8, 'Non', False);
 ShowMouse;
 WaitRelease;
 Done := False;
 Res := False;
 Repeat
  PollMouse;
  If PressL Then Begin
   If InRect(MX, MY, X + W Div 2 - 80, Y + H - 26, X + W Div 2 - 10, Y + H - 8) Then Begin
    Res := True;
    Done := True;
   End;
   If InRect(MX, MY, X + W Div 2 + 10, Y + H - 26, X + W Div 2 + 80, Y + H - 8) Then Done := True;
  End;
  Code := ReadKeyCode;
  Case Code Of
   13, Ord('o'), Ord('O'), Ord('y'), Ord('Y'): Begin Res := True; Done := True; End;
   27, Ord('n'), Ord('N'): Done := True;
  End;
  Delay(10);
 Until Done;
 WaitRelease;
 DrawAll;
 Confirm := Res;
End;

{ Saisie d'une chaine de caracteres }
Function InputBox(Title, Prompt: String; Var S: String; MaxLen: Integer): Boolean;
Var
 W, H, X, Y, Code, Blink: Integer;
 Done, Res: Boolean;
 Tmp: String;
 Fresh: Boolean;
Begin
 W := Max(300, Max(TW(Prompt), TW(Title)) + 40);
 If W > SW - 20 Then W := SW - 20;
 H := 96;
 X := (SW - W) Div 2;
 Y := (SH - H) Div 2;
 Tmp := S;
 Fresh := True;
 Done := False;
 Res := False;
 Blink := 0;
 HideMouse;
 DlgBox(X, Y, W, H, Title);
 Txt(X + 12, Y + 26, Prompt, Black);
 DlgBtn(X + W Div 2 - 80, Y + H - 26, X + W Div 2 - 10, Y + H - 8, 'OK', True);
 DlgBtn(X + W Div 2 + 10, Y + H - 26, X + W Div 2 + 80, Y + H - 8, 'Annuler', False);
 ShowMouse;
 WaitRelease;
 Repeat
  HideMouse;
  FillR(X + 10, Y + 40, X + W - 10, Y + 54, White);
  Frame(X + 10, Y + 40, X + W - 10, Y + 54, DarkGray);
  If Fresh Then Begin
   FillR(X + 12, Y + 42, X + 12 + TW(Fit(Tmp, W - 28)) + 1, Y + 52, Blue);
   Txt(X + 13, Y + 44, Fit(Tmp, W - 28), White);
  End Else Begin
   Txt(X + 13, Y + 44, Fit(Tmp, W - 28), Black);
   If Blink < 25 Then VLine(X + 13 + TW(Fit(Tmp, W - 28)), Y + 42, Y + 52, Black);
  End;
  ShowMouse;
  Repeat
   PollMouse;
   Code := ReadKeyCode;
   Inc(Blink);
   If Blink > 50 Then Blink := 0;
   If PressL Then Begin
    If InRect(MX, MY, X + W Div 2 - 80, Y + H - 26, X + W Div 2 - 10, Y + H - 8) Then Begin
     Res := True;
     Done := True;
    End;
    If InRect(MX, MY, X + W Div 2 + 10, Y + H - 26, X + W Div 2 + 80, Y + H - 8) Then Done := True;
   End;
   Delay(10);
  Until (Code <> 0) Or Done Or (Blink = 0) Or (Blink = 25);
  If Code = 13 Then Begin
   Res := True;
   Done := True;
  End
  Else If Code = 27 Then Done := True
  Else If Code = 8 Then Begin
   If Fresh Then Tmp := '' Else If Length(Tmp) > 0 Then Delete(Tmp, Length(Tmp), 1);
   Fresh := False;
  End
  Else If (Code >= 32) And (Code < 127) Then Begin
   If Fresh Then Tmp := '';
   Fresh := False;
   If Length(Tmp) < MaxLen Then Tmp := Tmp + Chr(Code);
  End;
 Until Done;
 WaitRelease;
 If Res Then S := Tmp;
 DrawAll;
 InputBox := Res;
End;

{ Choix dans une liste (DlgItems[0..DlgCount-1]) ; retourne -1 si annule }
Function ListDlg(Title: String; Def: Integer): Integer;
Var
 W, H, X, Y, I, Sel, Top, Rows, Code, Res, Row: Integer;
 Done: Boolean;
Begin
 Rows := Min(DlgCount, 12);
 W := Max(260, TW(Title) + 40);
 For I := 0 To DlgCount - 1 Do W := Max(W, TW(DlgItems[I]) + 50);
 H := 66 + Rows * 13;
 X := (SW - W) Div 2;
 Y := (SH - H) Div 2;
 Sel := Def;
 If (Sel < 0) Or (Sel >= DlgCount) Then Sel := 0;
 Top := 0;
 Res := -1;
 Done := False;
 WaitRelease;
 Repeat
  HideMouse;
  DlgBox(X, Y, W, H, Title);
  FillR(X + 8, Y + 24, X + W - 8, Y + 26 + Rows * 13, White);
  Frame(X + 8, Y + 24, X + W - 8, Y + 26 + Rows * 13, DarkGray);
  If Sel < Top Then Top := Sel;
  If Sel >= Top + Rows Then Top := Sel - Rows + 1;
  For I := Top To Min(DlgCount - 1, Top + Rows - 1) Do Begin
   If I = Sel Then Begin
    FillR(X + 9, Y + 26 + (I - Top) * 13, X + W - 9, Y + 38 + (I - Top) * 13, Blue);
    Txt(X + 14, Y + 29 + (I - Top) * 13, DlgItems[I], White);
   End Else Txt(X + 14, Y + 29 + (I - Top) * 13, DlgItems[I], Black);
  End;
  DlgBtn(X + W Div 2 - 80, Y + H - 26, X + W Div 2 - 10, Y + H - 8, 'OK', True);
  DlgBtn(X + W Div 2 + 10, Y + H - 26, X + W Div 2 + 80, Y + H - 8, 'Annuler', False);
  ShowMouse;
  Repeat
   PollMouse;
   Code := ReadKeyCode;
   Delay(10);
   If PressL Then Begin
    If InRect(MX, MY, X + W Div 2 - 80, Y + H - 26, X + W Div 2 - 10, Y + H - 8) Then Begin
     Res := Sel;
     Done := True;
    End
    Else If InRect(MX, MY, X + W Div 2 + 10, Y + H - 26, X + W Div 2 + 80, Y + H - 8) Then
     Done := True
    Else If InRect(MX, MY, X + 9, Y + 26, X + W - 9, Y + 26 + Rows * 13) Then Begin
     Row := (MY - Y - 26) Div 13 + Top;
     If (Row >= 0) And (Row < DlgCount) Then Begin
      Sel := Row;
      If DblClick Then Begin
       Res := Sel;
       Done := True;
      End;
     End;
     Code := 1000;
    End;
   End;
  Until (Code <> 0) Or Done;
  Case Code Of
   13: Begin Res := Sel; Done := True; End;
   27: Done := True;
   328: If Sel > 0 Then Dec(Sel);
   336: If Sel < DlgCount - 1 Then Inc(Sel);
   327: Sel := 0;
   335: Sel := DlgCount - 1;
  End;
 Until Done;
 WaitRelease;
 DrawAll;
 ListDlg := Res;
End;

{ ---------- Dialogue de fichiers ---------- }

Function ExtOf(Const N: String): String;
Var
 K, I: Integer;
Begin
 K := 0;
 For I := 1 To Length(N) Do
  If N[I] = '.' Then K := I;
 If K = 0 Then ExtOf := '' Else ExtOf := UpStr(Copy(N, K, 10));
End;

Procedure ScanDir(Const Exts: String);
Var
 SR: SearchRec;
 I, J: Integer;
 TmpN: String[14];
 TmpD: Boolean;
Begin
 FileCount := 0;
 FindFirst('*.*', Directory, SR);
 While DosError = 0 Do Begin
  If (SR.Attr And Directory) <> 0 Then Begin
   If (SR.Name <> '.') And (FileCount < 120) Then Begin
    FileList[FileCount] := SR.Name;
    FileIsDir[FileCount] := True;
    Inc(FileCount);
   End;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 FindFirst('*.*', AnyFile, SR);
 While DosError = 0 Do Begin
  If ((SR.Attr And Directory) = 0) And (FileCount < 120) Then
   If (Exts = '') Or (Pos(ExtOf(SR.Name), Exts) > 0) Then Begin
    FileList[FileCount] := SR.Name;
    FileIsDir[FileCount] := False;
    Inc(FileCount);
   End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 For I := 0 To FileCount - 2 Do
  For J := I + 1 To FileCount - 1 Do
   If (FileIsDir[J] And Not FileIsDir[I]) Or
      ((FileIsDir[J] = FileIsDir[I]) And (UpStr(FileList[J]) < UpStr(FileList[I]))) Then Begin
    TmpN := FileList[I]; FileList[I] := FileList[J]; FileList[J] := TmpN;
    TmpD := FileIsDir[I]; FileIsDir[I] := FileIsDir[J]; FileIsDir[J] := TmpD;
   End;
End;

Function FileDlg(Title, Exts: String; Var Name: String): Boolean;
Var
 W, H, X, Y, I, Sel, Top, Rows, Code, Row: Integer;
 Done, Res, Redo: Boolean;
 Dir, Typed: String;
Begin
 W := 340;
 Rows := 10;
 H := 66 + Rows * 12 + 24;
 X := (SW - W) Div 2;
 Y := (SH - H) Div 2;
 Typed := Name;
 Sel := -1;
 Top := 0;
 Res := False;
 Done := False;
 Redo := True;
 WaitRelease;
 Repeat
  If Redo Then Begin
   ScanDir(Exts);
   Sel := -1;
   Top := 0;
   Redo := False;
  End;
  GetDir(0, Dir);
  HideMouse;
  DlgBox(X, Y, W, H, Title);
  Txt(X + 8, Y + 22, Fit(Dir, W - 16), Black);
  FillR(X + 8, Y + 34, X + W - 8, Y + 36 + Rows * 12, White);
  Frame(X + 8, Y + 34, X + W - 8, Y + 36 + Rows * 12, DarkGray);
  If Sel >= 0 Then Begin
   If Sel < Top Then Top := Sel;
   If Sel >= Top + Rows Then Top := Sel - Rows + 1;
  End;
  For I := Top To Min(FileCount - 1, Top + Rows - 1) Do Begin
   If I = Sel Then FillR(X + 9, Y + 36 + (I - Top) * 12, X + W - 9, Y + 47 + (I - Top) * 12, Blue);
   If FileIsDir[I] Then Begin
    If I = Sel Then Txt(X + 14, Y + 38 + (I - Top) * 12, '[' + FileList[I] + ']', White)
    Else Txt(X + 14, Y + 38 + (I - Top) * 12, '[' + FileList[I] + ']', Blue);
   End Else Begin
    If I = Sel Then Txt(X + 14, Y + 38 + (I - Top) * 12, FileList[I], White)
    Else Txt(X + 14, Y + 38 + (I - Top) * 12, FileList[I], Black);
   End;
  End;
  Txt(X + 8, Y + H - 52, 'Fichier :', Black);
  FillR(X + 70, Y + H - 56, X + W - 8, Y + H - 42, White);
  Frame(X + 70, Y + H - 56, X + W - 8, Y + H - 42, DarkGray);
  Txt(X + 74, Y + H - 52, Fit(Typed, W - 90), Black);
  DlgBtn(X + W Div 2 - 80, Y + H - 26, X + W Div 2 - 10, Y + H - 8, 'OK', True);
  DlgBtn(X + W Div 2 + 10, Y + H - 26, X + W Div 2 + 80, Y + H - 8, 'Annuler', False);
  ShowMouse;
  Repeat
   PollMouse;
   Code := ReadKeyCode;
   Delay(10);
   If PressL Then Begin
    If InRect(MX, MY, X + W Div 2 - 80, Y + H - 26, X + W Div 2 - 10, Y + H - 8) Then Code := 13
    Else If InRect(MX, MY, X + W Div 2 + 10, Y + H - 26, X + W Div 2 + 80, Y + H - 8) Then
     Done := True
    Else If InRect(MX, MY, X + 9, Y + 36, X + W - 9, Y + 36 + Rows * 12) Then Begin
     Row := (MY - Y - 36) Div 12 + Top;
     If (Row >= 0) And (Row < FileCount) Then Begin
      Sel := Row;
      If Not FileIsDir[Row] Then Typed := FileList[Row];
      If DblClick Then Code := 13 Else Code := 1000;
     End;
    End;
   End;
  Until (Code <> 0) Or Done;
  Case Code Of
   27: Done := True;
   13: Begin
    If (Sel >= 0) And FileIsDir[Sel] Then Begin
     {$I-}
     ChDir(FileList[Sel]);
     {$I+}
     If IOResult <> 0 Then Code := 0;
     Redo := True;
     Typed := '';
    End Else If Typed <> '' Then Begin
     Name := Typed;
     Res := True;
     Done := True;
    End;
   End;
   8: If Length(Typed) > 0 Then Delete(Typed, Length(Typed), 1);
   328: If Sel > 0 Then Dec(Sel) Else If Sel < 0 Then Sel := 0;
   336: If Sel < FileCount - 1 Then Inc(Sel);
  Else
   If (Code >= 32) And (Code < 127) And (Length(Typed) < 60) Then Typed := Typed + Chr(Code);
  End;
 Until Done;
 WaitRelease;
 DrawAll;
 FileDlg := Res;
End;

{ ====================================================================== }
{  Fichiers : medias BMP, projets, exportations                          }
{ ====================================================================== }

Type
 TBmpWork = Record
  Row: Array[0..8191] Of Byte;
  Pal: Array[0..1023] Of Byte;
 End;
 PBmpWork = ^TBmpWork;

Function LE16(Var A: Array Of Byte; O: Integer): LongInt;
Begin
 LE16 := LongInt(A[O]) + LongInt(A[O + 1]) * 256;
End;

Function LE32(Var A: Array Of Byte; O: Integer): LongInt;
Begin
 LE32 := LongInt(A[O]) + LongInt(A[O + 1]) * 256 + LongInt(A[O + 2]) * 65536 +
          LongInt(A[O + 3]) * 16777216;
End;

Procedure PutLE32(Var A: Array Of Byte; O: Integer; V: LongInt);
Begin
 A[O] := V And 255;
 A[O + 1] := (V Shr 8) And 255;
 A[O + 2] := (V Shr 16) And 255;
 A[O + 3] := (V Shr 24) And 255;
End;

{ Charge un BMP non compresse dans l'emplacement Slot du bassin d'images }
Function LoadBmpSlot(Const FN: String; Slot: Integer): Boolean;
Var
 F: File;
 H: Array[0..53] Of Byte;
 Wk: PBmpWork;
 Buf: PImgBuf;
 W, Ht, Bpp, Stride, OffB, HdrSz, NPal, DW, DH, OX, OY, DX, DY, SX, SY, FR: LongInt;
 R, G, B, Idx, Q: LongInt;
 TopDown: Boolean;
 N: Word;
Begin
 LoadBmpSlot := False;
 {$I-}
 Assign(F, FN);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 BlockRead(F, H, 54, N);
 If (N < 54) Or (H[0] <> Ord('B')) Or (H[1] <> Ord('M')) Then Begin
  Close(F);
  Exit;
 End;
 OffB := LE32(H, 10);
 HdrSz := LE32(H, 14);
 W := LE32(H, 18);
 Ht := LE32(H, 22);
 Bpp := LE16(H, 28);
 TopDown := Ht < 0;
 If TopDown Then Ht := -Ht;
 If (LE32(H, 30) <> 0) Or (W < 1) Or (Ht < 1) Or (HdrSz < 40) Or
    ((Bpp <> 1) And (Bpp <> 4) And (Bpp <> 8) And (Bpp <> 24) And (Bpp <> 32)) Then Begin
  Close(F);
  Exit;
 End;
 Stride := ((W * Bpp + 31) Div 32) * 4;
 If Stride > 8192 Then Begin
  Close(F);
  Exit;
 End;
 New(Wk);
 NPal := 0;
 If Bpp <= 8 Then Begin
  NPal := 1 Shl Bpp;
  Seek(F, 14 + HdrSz);
  BlockRead(F, Wk^.Pal, NPal * 4, N);
 End;
 If ImgPool[Slot] = Nil Then New(ImgPool[Slot]);
 Buf := ImgPool[Slot];
 FillChar(Buf^, SizeOf(TImgBuf), 0);
 If W * VH >= Ht * VW Then Begin
  DW := VW;
  DH := (Ht * VW) Div W;
 End Else Begin
  DH := VH;
  DW := (W * VH) Div Ht;
 End;
 If DW < 1 Then DW := 1;
 If DH < 1 Then DH := 1;
 OX := (VW - DW) Div 2;
 OY := (VH - DH) Div 2;
 For DY := OY To OY + DH - 1 Do Begin
  SY := ((DY - OY) * Ht) Div DH;
  If TopDown Then FR := SY Else FR := Ht - 1 - SY;
  Seek(F, OffB + FR * Stride);
  FillChar(Wk^.Row, 8192, 0);
  BlockRead(F, Wk^.Row, Stride, N);
  For DX := OX To OX + DW - 1 Do Begin
   SX := ((DX - OX) * W) Div DW;
   Case Bpp Of
    24: Begin B := Wk^.Row[SX * 3]; G := Wk^.Row[SX * 3 + 1]; R := Wk^.Row[SX * 3 + 2]; End;
    32: Begin B := Wk^.Row[SX * 4]; G := Wk^.Row[SX * 4 + 1]; R := Wk^.Row[SX * 4 + 2]; End;
    8: Begin
     Idx := Wk^.Row[SX];
     B := Wk^.Pal[Idx * 4]; G := Wk^.Pal[Idx * 4 + 1]; R := Wk^.Pal[Idx * 4 + 2];
    End;
    4: Begin
     Idx := Wk^.Row[SX Shr 1];
     If (SX And 1) = 0 Then Idx := Idx Shr 4 Else Idx := Idx And 15;
     B := Wk^.Pal[Idx * 4]; G := Wk^.Pal[Idx * 4 + 1]; R := Wk^.Pal[Idx * 4 + 2];
    End;
   Else Begin
     Idx := (Wk^.Row[SX Shr 3] Shr (7 - (SX And 7))) And 1;
     B := Wk^.Pal[Idx * 4]; G := Wk^.Pal[Idx * 4 + 1]; R := Wk^.Pal[Idx * 4 + 2];
    End;
   End;
   Q := ((R Shr 5) Shl 5) Or ((G Shr 5) Shl 2) Or (B Shr 6);
   Buf^[DY * VW + DX] := Q;
  End;
 End;
 Close(F);
 Dispose(Wk);
 LoadBmpSlot := True;
End;

Function FreeImgSlot: Integer;
Var
 I, J: Integer;
 Used: Boolean;
Begin
 FreeImgSlot := -1;
 For I := 0 To MAXIMG - 1 Do Begin
  Used := False;
  For J := 0 To P.NM - 1 Do
   If (P.Media[J].Kind = MK_IMAGE) And (P.Media[J].Img = I) Then Used := True;
  If Not Used Then Begin
   FreeImgSlot := I;
   Exit;
  End;
 End;
End;

Function AddMedia(Const Nm: String; Kind: Integer; Dur: LongInt; Par: Integer;
                  Const Tx, Path: String): Integer;
Begin
 AddMedia := -1;
 If P.NM >= MAXMEDIA Then Exit;
 FillChar(P.Media[P.NM], SizeOf(TMedia), 0);
 P.Media[P.NM].Name := Copy(Nm, 1, 20);
 P.Media[P.NM].Kind := Kind;
 P.Media[P.NM].Dur := Dur;
 P.Media[P.NM].Par := Par;
 P.Media[P.NM].Img := -1;
 P.Media[P.NM].Txt := Copy(Tx, 1, 22);
 P.Media[P.NM].Path := Copy(Path, 1, 40);
 AddMedia := P.NM;
 Inc(P.NM);
End;

Function ImportBmp(FN: String): Boolean;
Var
 Slot, M: Integer;
 Nm: String;
 K: Integer;
Begin
 ImportBmp := False;
 Slot := FreeImgSlot;
 If Slot < 0 Then Begin
  MsgBox('Importer', 'Limite d''images BMP atteinte (' + IStr(MAXIMG) + ').');
  Exit;
 End;
 If Not LoadBmpSlot(FN, Slot) Then Begin
  MsgBox('Importer', 'Fichier BMP illisible ou non supporté.|(BMP non compressé 1/4/8/24/32 bits)');
  Exit;
 End;
 Nm := FN;
 K := Pos('.', Nm);
 If K > 0 Then Nm := Copy(Nm, 1, K - 1);
 M := AddMedia(Nm, MK_IMAGE, P.Fps * 5, 0, '', FN);
 If M < 0 Then Begin
  MsgBox('Importer', 'Le projet contient trop de médias.');
  Exit;
 End;
 P.Media[M].Img := Slot;
 ImportBmp := True;
End;

Function SaveProject(Const FN: String): Boolean;
Var
 F: Text;
 I: Integer;
Begin
 SaveProject := False;
 {$I-}
 Assign(F, FN);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, 'PREMIERE1');
 WriteLn(F, 'N|', P.Name);
 WriteLn(F, 'F|', P.Fps);
 For I := 0 To P.NM - 1 Do
  WriteLn(F, 'M|', P.Media[I].Name, '|', P.Media[I].Kind, '|', P.Media[I].Dur, '|',
          P.Media[I].Par, '|', P.Media[I].Txt, '|', P.Media[I].Path);
 For I := 0 To P.NC - 1 Do
  With P.Clips[I] Do
   WriteLn(F, 'C|', Trk, ' ', Med, ' ', Start, ' ', Dur, ' ', InPt, ' ', Speed, ' ', Opac, ' ',
           PosX, ' ', PosY, ' ', Scale, ' ', Br, ' ', Co, ' ', Sa, ' ', Mos, ' ', Fl, ' ',
           Vol, ' ', Ord(Mute), ' ', TIn, ' ', TInL, ' ', TOut, ' ', TOutL, '|', Name);
 For I := 0 To P.NK - 1 Do WriteLn(F, 'K|', P.Marks[I].Pos, '|', P.Marks[I].Name);
 WriteLn(F, 'I|', P.InM, '|', P.OutM);
 WriteLn(F, 'T|', P.TrkF[0], ' ', P.TrkF[1], ' ', P.TrkF[2], ' ', P.TrkF[3], ' ', P.TrkF[4], ' ',
         P.TrkF[5]);
 Close(F);
 SaveProject := IOResult = 0;
End;

Procedure ResetProject;
Var
 I: Integer;
Begin
 FillChar(P, SizeOf(P), 0);
 P.Name := 'Séquence 01';
 P.Fps := 25;
 P.InM := -1;
 P.OutM := -1;
 FreeHistory;
 Playhead := 0;
 ScrollF := 0;
 PPS := 25;
 SrcMed := -1;
 SrcPos := 0;
 SrcIn := -1;
 SrcOut := -1;
 ProjSel := -1;
 ProjScroll := 0;
 MarkSel := -1;
 CtlScroll := 0;
 Playing := False;
 For I := 0 To MAXIMG - 1 Do
  If ImgPool[I] <> Nil Then Begin
   Dispose(ImgPool[I]);
   ImgPool[I] := Nil;
  End;
 Modified := False;
 ProjFile := '';
End;

Function LoadProject(Const FN: String): Boolean;
Var
 F: Text;
 L, Tag, S: String;
 C: TClip;
 M: Integer;
 Slot: Integer;
Begin
 LoadProject := False;
 {$I-}
 Assign(F, FN);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 ReadLn(F, L);
 If L <> 'PREMIERE1' Then Begin
  Close(F);
  Exit;
 End;
 ResetProject;
 While Not Eof(F) Do Begin
  ReadLn(F, L);
  If Length(L) < 2 Then Continue;
  Tag := Copy(L, 1, 1);
  Delete(L, 1, 2);
  If Tag = 'N' Then P.Name := Copy(L, 1, 24)
  Else If Tag = 'F' Then Begin
   P.Fps := Integer(StrVal(L, 25));
   If (P.Fps < 10) Or (P.Fps > 60) Then P.Fps := 25;
  End
  Else If Tag = 'M' Then Begin
   S := TakeField(L);
   M := AddMedia(S, 0, 0, 0, '', '');
   If M >= 0 Then Begin
    P.Media[M].Kind := Integer(StrVal(TakeField(L), 0));
    P.Media[M].Dur := StrVal(TakeField(L), 125);
    P.Media[M].Par := Integer(StrVal(TakeField(L), 0));
    P.Media[M].Txt := Copy(TakeField(L), 1, 22);
    P.Media[M].Path := Copy(L, 1, 40);
    If P.Media[M].Kind = MK_IMAGE Then Begin
     Slot := FreeImgSlot;
     If (Slot >= 0) And LoadBmpSlot(P.Media[M].Path, Slot) Then P.Media[M].Img := Slot;
    End;
   End;
  End
  Else If Tag = 'C' Then Begin
   S := TakeField(L);
   FillChar(C, SizeOf(C), 0);
   C.Trk := Integer(TakeNum(S));
   C.Med := Integer(TakeNum(S));
   C.Start := TakeNum(S);
   C.Dur := TakeNum(S);
   C.InPt := TakeNum(S);
   C.Speed := Integer(TakeNum(S));
   C.Opac := Integer(TakeNum(S));
   C.PosX := Integer(TakeNum(S));
   C.PosY := Integer(TakeNum(S));
   C.Scale := Integer(TakeNum(S));
   C.Br := Integer(TakeNum(S));
   C.Co := Integer(TakeNum(S));
   C.Sa := Integer(TakeNum(S));
   C.Mos := Integer(TakeNum(S));
   C.Fl := Integer(TakeNum(S));
   C.Vol := Integer(TakeNum(S));
   C.Mute := TakeNum(S) <> 0;
   C.TIn := Integer(TakeNum(S));
   C.TInL := Integer(TakeNum(S));
   C.TOut := Integer(TakeNum(S));
   C.TOutL := Integer(TakeNum(S));
   C.Name := Copy(L, 1, 20);
   If (C.Trk >= 0) And (C.Trk < NTRK) And (C.Med >= 0) And (C.Med < P.NM) And
      (C.Dur > 0) And (C.Speed > 0) And (C.Scale > 0) Then AddClipRec(C);
  End
  Else If Tag = 'K' Then Begin
   If P.NK < MAXMARK Then Begin
    P.Marks[P.NK].Pos := StrVal(TakeField(L), 0);
    P.Marks[P.NK].Name := Copy(L, 1, 14);
    Inc(P.NK);
   End;
  End
  Else If Tag = 'I' Then Begin
   P.InM := StrVal(TakeField(L), -1);
   P.OutM := StrVal(L, -1);
  End
  Else If Tag = 'T' Then Begin
   For M := 0 To NTRK - 1 Do P.TrkF[M] := Integer(TakeNum(L));
  End;
 End;
 Close(F);
 Modified := False;
 ProjFile := FN;
 LoadProject := True;
End;

{ ---------- Exportations ---------- }

Function ExportBmpFrame(Const FN: String; Tm: LongInt): Boolean;
Var
 F: File;
 H: Array[0..53] Of Byte;
 Row: Array[0..VW * 3 - 1] Of Byte;
 X, Y: Integer;
Begin
 ExportBmpFrame := False;
 FillChar(H, SizeOf(H), 0);
 H[0] := Ord('B');
 H[1] := Ord('M');
 PutLE32(H, 2, 54 + VW * VH * 3);
 PutLE32(H, 10, 54);
 PutLE32(H, 14, 40);
 PutLE32(H, 18, VW);
 PutLE32(H, 22, VH);
 H[26] := 1;
 H[28] := 24;
 PutLE32(H, 34, VW * VH * 3);
 PutLE32(H, 38, 2835);
 PutLE32(H, 42, 2835);
 {$I-}
 Assign(F, FN);
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 BlockWrite(F, H, 54);
 BuildLayers(Tm);
 For Y := VH - 1 Downto 0 Do Begin
  For X := 0 To VW - 1 Do Begin
   If NLay = 0 Then Begin
    AR := 0; AG := 0; AB := 0;
   End Else Compose(X, Y);
   Row[X * 3] := AB;
   Row[X * 3 + 1] := AG;
   Row[X * 3 + 2] := AR;
  End;
  BlockWrite(F, Row, VW * 3);
 End;
 Close(F);
 ExportBmpFrame := IOResult = 0;
End;

Function EDLName(S: String): String;
Var
 I: Integer;
 R: String;
Begin
 R := '';
 S := Cv(S);
 For I := 1 To Length(S) Do
  If S[I] in ['A'..'Z', 'a'..'z', '0'..'9'] Then R := R + UpCase(S[I]);
 If R = '' Then R := 'AX';
 EDLName := Copy(R, 1, 8);
End;

Function ExportEDL(Const FN: String): Boolean;
Var
 F: Text;
 N, I, T, Best: Integer;
 Done: Array[0..MAXCLIPS-1] Of Boolean;
 BestS: LongInt;
 Ch: String;
Begin
 ExportEDL := False;
 {$I-}
 Assign(F, FN);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, 'TITLE: ', EDLName(P.Name));
 WriteLn(F, 'FCM: NON-DROP FRAME');
 WriteLn(F);
 FillChar(Done, SizeOf(Done), 0);
 N := 0;
 For T := 0 To NTRK - 1 Do Begin
  Repeat
   Best := -1;
   BestS := 0;
   For I := 0 To P.NC - 1 Do
    If (P.Clips[I].Trk = T) And (Not Done[I]) Then
     If (Best < 0) Or (P.Clips[I].Start < BestS) Then Begin
      Best := I;
      BestS := P.Clips[I].Start;
     End;
   If Best >= 0 Then Begin
    Done[Best] := True;
    Inc(N);
    If T < 3 Then Ch := 'V' Else Ch := 'A';
    With P.Clips[Best] Do Begin
     WriteLn(F, Pad(N, 3), '  ', EDLName(P.Media[Med].Name), '        ', Ch,
             '     C        ', TC(InPt), ' ', TC(InPt + (Dur * Speed) Div 100), ' ',
             TC(Start), ' ', TC(Start + Dur));
     WriteLn(F, '* FROM CLIP NAME: ', Name);
     WriteLn(F, '* TRACK: ', TrackName(T));
    End;
   End;
  Until Best < 0;
 End;
 Close(F);
 ExportEDL := IOResult = 0;
End;

{ ====================================================================== }
{  Lecture, navigation, operations de montage                            }
{ ====================================================================== }

Var
 FocusSrc: Boolean;

Procedure EnsureVisible;
Var
 V: LongInt;
Begin
 V := VisFrames;
 If Playhead < ScrollF Then ScrollF := Max(0, Playhead - V Div 8)
 Else If Playhead > ScrollF + V - 1 Then ScrollF := Playhead - V Div 8;
End;

Procedure SetPlayhead(F: LongInt);
Begin
 If F < 0 Then F := 0;
 Playhead := F;
 AnalyseAudio(F);
 EnsureVisible;
 NeedProg := True;
 NeedTL := True;
 NeedMeters := True;
End;

Procedure SetSrcPos(F: LongInt);
Begin
 F := Clamp(F, 0, MonLen(False));
 SrcPos := F;
 NeedSrc := True;
End;

Procedure StopPlay;
Begin
 If Playing Then Begin
  Playing := False;
  PlayTarget := 0;
  StopSound;
  LevelL := 0;
  LevelR := 0;
  NeedProg := True;
  NeedSrc := True;
  NeedTL := True;
  NeedMeters := True;
 End;
End;

Procedure StartPlay(Target, Speed: Integer);
Begin
 If Target = 1 Then Begin
  If (Speed > 0) And (Playhead >= SeqEnd) And (SeqEnd > 0) Then Playhead := 0;
  If (Speed < 0) And (Playhead = 0) Then Playhead := SeqEnd;
  PlayF0 := Playhead;
 End Else Begin
  If (Speed > 0) And (SrcPos >= MonLen(False)) Then SrcPos := 0;
  PlayF0 := SrcPos;
 End;
 PlayT0 := Ticks;
 PlaySpeed := Speed;
 PlayTarget := Target;
 Playing := True;
 NeedProg := True;
 NeedSrc := True;
End;

Procedure TogglePlay(Target: Integer);
Begin
 If Playing Then StopPlay Else StartPlay(Target, 1);
End;

Procedure PlayTick;
Var
 El, Delta, NewF, Lim: LongInt;
Begin
 If Not Playing Then Exit;
 El := TickDiff(Ticks, PlayT0);
 Delta := (El * P.Fps * Abs(PlaySpeed)) Div 100;
 If PlaySpeed >= 0 Then NewF := PlayF0 + Delta Else NewF := PlayF0 - Delta;
 If PlayTarget = 1 Then Begin
  Lim := SeqEnd;
  If P.OutM >= 0 Then Lim := Min(Lim, P.OutM);
  If (NewF >= Lim) And (PlaySpeed > 0) Then Begin
   If LoopOn And (Lim > 0) Then Begin
    PlayF0 := 0;
    If P.InM >= 0 Then PlayF0 := P.InM;
    PlayT0 := Ticks;
    NewF := PlayF0;
   End Else Begin
    StopPlay;
    SetPlayhead(Max(0, Lim));
    Exit;
   End;
  End;
  If (NewF <= 0) And (PlaySpeed < 0) Then Begin
   StopPlay;
   SetPlayhead(0);
   Exit;
  End;
  If NewF <> Playhead Then Begin
   Playhead := NewF;
   AnalyseAudio(NewF);
   UpdateSound;
   EnsureVisible;
   NeedProg := True;
   NeedTL := True;
   NeedMeters := True;
   NeedStatus := True;
  End;
 End Else Begin
  Lim := MonLen(False);
  If SrcOut >= 0 Then Lim := Min(Lim, SrcOut);
  If (NewF >= Lim) And (PlaySpeed > 0) Then Begin
   StopPlay;
   SetSrcPos(Lim);
   Exit;
  End;
  If (NewF <= 0) And (PlaySpeed < 0) Then Begin
   StopPlay;
   SetSrcPos(0);
   Exit;
  End;
  If NewF <> SrcPos Then Begin
   SrcPos := NewF;
   NeedSrc := True;
  End;
 End;
 { Decroissance des pics des vumetres }
 If PeakL > 0 Then Dec(PeakL);
 If PeakR > 0 Then Dec(PeakR);
End;

Function NextEdit(F: LongInt): LongInt;
Var
 I: Integer;
 B: LongInt;
Begin
 B := -1;
 For I := 0 To P.NC - 1 Do Begin
  If (P.Clips[I].Start > F) And ((B < 0) Or (P.Clips[I].Start < B)) Then B := P.Clips[I].Start;
  If (ClipEnd(I) > F) And ((B < 0) Or (ClipEnd(I) < B)) Then B := ClipEnd(I);
 End;
 NextEdit := B;
End;

Function PrevEdit(F: LongInt): LongInt;
Var
 I: Integer;
 B: LongInt;
Begin
 B := -1;
 For I := 0 To P.NC - 1 Do Begin
  If (P.Clips[I].Start < F) And (P.Clips[I].Start > B) Then B := P.Clips[I].Start;
  If (ClipEnd(I) < F) And (ClipEnd(I) > B) Then B := ClipEnd(I);
 End;
 PrevEdit := B;
End;

{ Magnetisme : retourne la position ajustee et memorise le guide }
Function SnapTo(F: LongInt; Skip: Integer): LongInt;
Var
 I: Integer;
 Th, Best, BestD, D: LongInt;
 Procedure Tr(C: LongInt);
 Begin
  D := Abs(C - F);
  If D < BestD Then Begin
   BestD := D;
   Best := C;
  End;
 End;
Begin
 SnapGuide := -1;
 SnapTo := F;
 If Not SnapOn Then Exit;
 Th := Max(1, (7 * P.Fps) Div PPS);
 BestD := Th + 1;
 Best := F;
 Tr(0);
 Tr(Playhead);
 For I := 0 To P.NK - 1 Do Tr(P.Marks[I].Pos);
 For I := 0 To P.NC - 1 Do
  If (I <> Skip) And Not ((Skip = -2) And P.Clips[I].Sel) Then Begin
   Tr(P.Clips[I].Start);
   Tr(ClipEnd(I));
  End;
 If BestD <= Th Then Begin
  SnapTo := Best;
  SnapGuide := Best;
 End;
End;

Procedure ZoomBy(Dir: Integer; CenterX: Integer);
Var
 I, Cur: Integer;
 F: LongInt;
Begin
 F := XToFrame(CenterX);
 Cur := 0;
 For I := 0 To 13 Do
  If ZoomTab[I] <= PPS Then Cur := I;
 If Dir > 0 Then Cur := Min(13, Cur + 1) Else Cur := Max(0, Cur - 1);
 If (Dir > 0) And (ZoomTab[Cur] = PPS) And (Cur < 13) Then Cur := Cur + 1;
 PPS := ZoomTab[Cur];
 ScrollF := Max(0, F - ((CenterX - TLX0) * P.Fps) Div PPS);
 NeedTL := True;
End;

Procedure ZoomFit;
Var
 L: LongInt;
 I, Cur: Integer;
Begin
 L := Max(SeqEnd, P.Fps * 4);
 Cur := 0;
 For I := 0 To 13 Do
  If (ZoomTab[I] * L) Div P.Fps <= (TLX1 - TLX0) Then Cur := I;
 PPS := ZoomTab[Cur];
 ScrollF := 0;
 NeedTL := True;
End;

{ ---------- Operations de montage ---------- }

Function DefaultTrackFor(M: Integer): Integer;
Begin
 If MediaAudio(M) Then DefaultTrackFor := 3 Else DefaultTrackFor := 0;
End;

Procedure DropMedia(M, Track: Integer; F: LongInt);
Var
 T, I: Integer;
 D: LongInt;
Begin
 If (M < 0) Or (M >= P.NM) Then Exit;
 T := Track;
 If MediaAudio(M) Then Begin
  If T < 3 Then T := 3;
 End Else If T >= 3 Then T := 0;
 If TrackLocked(T) Then Begin
  Msg('Piste verrouillée');
  Exit;
 End;
 D := P.Media[M].Dur;
 If D < 1 Then D := P.Fps * 5;
 PushUndo;
 ClearSel;
 I := PlaceClip(T, M, Max(0, F), 0, D);
 If I >= 0 Then Begin
  P.Clips[I].Sel := True;
  Msg('Clip ajouté sur ' + TrackName(T));
 End Else Msg('Séquence pleine');
 NeedTL := True;
 NeedProg := True;
 NeedA := True;
End;

Procedure DoDelete(Ripple: Boolean);
Var
 I, B: Integer;
 BS, D, E: LongInt;
 T: Integer;
 Any: Boolean;
Begin
 Any := False;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel And (Not TrackLocked(P.Clips[I].Trk)) Then Any := True;
 If Not Any Then Exit;
 PushUndo;
 If Not Ripple Then Begin
  For I := P.NC - 1 Downto 0 Do
   If P.Clips[I].Sel And (Not TrackLocked(P.Clips[I].Trk)) Then DelClip(I);
 End Else Begin
  Repeat
   B := -1;
   BS := -1;
   For I := 0 To P.NC - 1 Do
    If P.Clips[I].Sel And (Not TrackLocked(P.Clips[I].Trk)) Then
     If P.Clips[I].Start > BS Then Begin
      BS := P.Clips[I].Start;
      B := I;
     End;
   If B >= 0 Then Begin
    T := P.Clips[B].Trk;
    D := P.Clips[B].Dur;
    E := ClipEnd(B);
    DelClip(B);
    For I := 0 To P.NC - 1 Do
     If (P.Clips[I].Trk = T) And (P.Clips[I].Start >= E) Then
      P.Clips[I].Start := P.Clips[I].Start - D;
   End;
  Until B < 0;
 End;
 NeedTL := True;
 NeedProg := True;
 NeedA := True;
 Msg('Clip(s) supprimé(s)');
End;

Procedure DoCopy;
Var
 I, N: Integer;
Begin
 N := 0;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel And (N < 40) Then Begin
   ClipBuf[N] := P.Clips[I];
   Inc(N);
  End;
 If N > 0 Then Begin
  ClipCnt := N;
  Msg(IStr(N) + ' clip(s) copié(s)');
 End;
End;

Procedure PasteAt(F: LongInt);
Var
 I, K: Integer;
 MinS, Off: LongInt;
 C: TClip;
Begin
 If ClipCnt = 0 Then Exit;
 MinS := ClipBuf[0].Start;
 For I := 1 To ClipCnt - 1 Do
  If ClipBuf[I].Start < MinS Then MinS := ClipBuf[I].Start;
 Off := F - MinS;
 PushUndo;
 ClearSel;
 For I := 0 To ClipCnt - 1 Do
  If (ClipBuf[I].Med < P.NM) And (Not TrackLocked(ClipBuf[I].Trk)) Then Begin
   C := ClipBuf[I];
   C.Start := Max(0, C.Start + Off);
   CutRange(C.Trk, C.Start, C.Start + C.Dur, False);
   C.Sel := True;
   K := AddClipRec(C);
  End;
 NeedTL := True;
 NeedProg := True;
 Msg('Collé');
End;

Procedure DoDuplicate;
Var
 I: Integer;
 MaxE, MinS: LongInt;
Begin
 If SelCount = 0 Then Exit;
 DoCopy;
 MaxE := 0;
 MinS := 99999999;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   If ClipEnd(I) > MaxE Then MaxE := ClipEnd(I);
   If P.Clips[I].Start < MinS Then MinS := P.Clips[I].Start;
  End;
 PasteAt(MaxE);
End;

Procedure SplitAtPlayhead;
Var
 I, K: Integer;
 Any, Sels: Boolean;
Begin
 Sels := SelCount > 0;
 Any := False;
 For I := 0 To P.NC - 1 Do
  If (Not TrackLocked(P.Clips[I].Trk)) And (Playhead > P.Clips[I].Start) And
     (Playhead < ClipEnd(I)) And ((Not Sels) Or P.Clips[I].Sel) Then Any := True;
 If Not Any Then Begin
  Msg('Aucun clip à couper à la tête de lecture');
  Exit;
 End;
 PushUndo;
 For I := P.NC - 1 Downto 0 Do
  If (Not TrackLocked(P.Clips[I].Trk)) And (Playhead > P.Clips[I].Start) And
     (Playhead < ClipEnd(I)) And ((Not Sels) Or P.Clips[I].Sel) Then
   K := SplitClip(I, Playhead);
 NeedTL := True;
 NeedProg := True;
 Msg('Coupe ajoutée');
End;

Procedure SetDefaultTransition(Video: Boolean);
Var
 I: Integer;
 Any: Boolean;
 L: Integer;
Begin
 Any := False;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel And (IsVideoTrack(P.Clips[I].Trk) = Video) Then Any := True;
 If Not Any Then Begin
  Msg('Sélectionnez au moins un clip ' + 'de ce type');
  Exit;
 End;
 PushUndo;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel And (IsVideoTrack(P.Clips[I].Trk) = Video) Then Begin
   L := Integer(Min(15, Max(1, P.Clips[I].Dur Div 3)));
   P.Clips[I].TIn := 1;
   P.Clips[I].TOut := 1;
   P.Clips[I].TInL := L;
   P.Clips[I].TOutL := L;
  End;
 NeedTL := True;
 NeedProg := True;
 NeedA := True;
 Msg('Transition par défaut appliquée');
End;

Procedure ApplyEffect(E, I: Integer; AtEnd: Boolean; Both: Boolean);
Var
 Vid: Boolean;
 L: Integer;
Begin
 If (I < 0) Or (I >= P.NC) Or (E < 0) Or (E >= NEFF) Then Exit;
 Vid := IsVideoTrack(P.Clips[I].Trk);
 If (E <= 11) And Not Vid Then Begin
  Msg('Cet effet ne s''applique qu''aux clips vidéo');
  Exit;
 End;
 If (E >= 12) And Vid Then Begin
  Msg('Cet effet ne s''applique qu''aux clips audio');
  Exit;
 End;
 If TrackLocked(P.Clips[I].Trk) Then Begin
  Msg('Piste verrouillée');
  Exit;
 End;
 PushUndo;
 With P.Clips[I] Do Begin
  L := Integer(Min(15, Max(1, Dur Div 2)));
  Case E Of
   0: Fl := Fl Xor CF_MIRH;
   1: Fl := Fl Xor CF_MIRV;
   2: Scale := 150;
   3: Begin Br := Integer(Min(100, Br + 25)); Co := Integer(Min(100, Co + 25)); End;
   4: Sa := 0;
   5: Fl := Fl Xor CF_INV;
   6: Sa := 160;
   7: Mos := 10;
   8, 9, 10, 11: Begin
    If Both Or Not AtEnd Then Begin TIn := E - 7; TInL := L; End;
    If Both Or AtEnd Then Begin TOut := E - 7; TOutL := L; End;
   End;
   12: Vol := Integer(Min(12, Vol + 6));
   13: Vol := Integer(Max(-40, Vol - 6));
   14: Mute := True;
   15: Begin
    If Both Or Not AtEnd Then Begin TIn := 1; TInL := L; End;
    If Both Or AtEnd Then Begin TOut := 1; TOutL := L; End;
   End;
  End;
 End;
 Msg('Effet appliqué : ' + EffName[E]);
 NeedTL := True;
 NeedProg := True;
 NeedA := True;
End;

Procedure ApplyEffectToSel(E: Integer);
Var
 I: Integer;
 AtEnd, Both: Boolean;
Begin
 If SelCount = 0 Then Begin
  Msg('Sélectionnez un clip dans la séquence');
  Exit;
 End;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   Both := (Playhead < P.Clips[I].Start) Or (Playhead >= ClipEnd(I));
   AtEnd := Playhead >= P.Clips[I].Start + P.Clips[I].Dur Div 2;
   ApplyEffect(E, I, AtEnd, Both);
  End;
End;

Procedure ResetFx;
Var
 I: Integer;
Begin
 If SelCount = 0 Then Exit;
 PushUndo;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then
   With P.Clips[I] Do Begin
    Opac := 100; PosX := 0; PosY := 0; Scale := 100; Br := 0; Co := 0; Sa := 100;
    Mos := 0; Fl := Fl And CF_OFF; Vol := 0; Mute := False;
    TIn := 0; TOut := 0;
   End;
 NeedTL := True;
 NeedProg := True;
 NeedA := True;
 Msg('Effets réinitialisés');
End;

Procedure ChangeSpeed;
Var
 I: Integer;
 S: String;
 NS, ND, Gap, Lim: LongInt;
 J: Integer;
Begin
 I := FirstSel;
 If I < 0 Then Exit;
 S := IStr(P.Clips[I].Speed);
 If Not InputBox('Vitesse/Durée du clip', 'Vitesse en % (25 à 400) :', S, 4) Then Exit;
 NS := Clamp(StrVal(S, 100), 25, 400);
 PushUndo;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   ND := Max(1, (P.Clips[I].Dur * P.Clips[I].Speed) Div NS);
   Gap := 1000000;
   For J := 0 To P.NC - 1 Do
    If (J <> I) And (P.Clips[J].Trk = P.Clips[I].Trk) And (P.Clips[J].Start >= ClipEnd(I)) Then
     Gap := Min(Gap, P.Clips[J].Start - P.Clips[I].Start);
   If ND > Gap Then ND := Gap;
   If Not MediaUnlimited(P.Clips[I].Med) Then Begin
    Lim := ((MediaMax(P.Clips[I].Med) - P.Clips[I].InPt) * 100) Div NS;
    If ND > Lim Then ND := Max(1, Lim);
   End;
   P.Clips[I].Speed := Integer(NS);
   P.Clips[I].Dur := ND;
  End;
 NeedTL := True;
 NeedProg := True;
 Msg('Vitesse : ' + IStr(NS) + ' %');
End;

Procedure RemoveGap;
Var
 T, I: Integer;
 GS, GE: LongInt;
Begin
 I := FirstSel;
 If I >= 0 Then T := P.Clips[I].Trk Else T := 0;
 If TrackLocked(T) Then Exit;
 If FindClip(T, Playhead) >= 0 Then Begin
  Msg('La tête de lecture n''est pas dans un espace vide');
  Exit;
 End;
 GS := 0;
 GE := -1;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Trk = T Then Begin
   If (ClipEnd(I) <= Playhead) And (ClipEnd(I) > GS) Then GS := ClipEnd(I);
   If (P.Clips[I].Start > Playhead) And ((GE < 0) Or (P.Clips[I].Start < GE)) Then
    GE := P.Clips[I].Start;
  End;
 If GE < 0 Then Begin
  Msg('Aucun clip après cet espace');
  Exit;
 End;
 PushUndo;
 For I := 0 To P.NC - 1 Do
  If (P.Clips[I].Trk = T) And (P.Clips[I].Start >= GE) Then
   P.Clips[I].Start := P.Clips[I].Start - (GE - GS);
 NeedTL := True;
 NeedProg := True;
 Msg('Espace supprimé');
End;

{ ---------- Source : insertion / ecrasement ---------- }

Procedure SourceEdit(InsertMode: Boolean);
Var
 M, T, I: Integer;
 A, B, D: LongInt;
Begin
 M := SrcMed;
 If (M < 0) Or (M >= P.NM) Then Begin
  Msg('Aucun clip dans le moniteur source');
  Exit;
 End;
 A := SrcIn;
 B := SrcOut;
 If A < 0 Then A := 0;
 If B < 0 Then Begin
  If MediaUnlimited(M) Then B := A + P.Media[M].Dur Else B := MediaMax(M);
 End;
 If B <= A Then Begin
  Msg('Plage source vide');
  Exit;
 End;
 D := B - A;
 T := DefaultTrackFor(M);
 If TrackLocked(T) Then Begin
  Msg('Piste verrouillée');
  Exit;
 End;
 PushUndo;
 If InsertMode Then Begin
  For I := P.NC - 1 Downto 0 Do
   If (Not TrackLocked(P.Clips[I].Trk)) And (Playhead > P.Clips[I].Start) And
      (Playhead < ClipEnd(I)) Then SplitClip(I, Playhead);
  ShiftFrom(Playhead, D, -1);
 End;
 ClearSel;
 I := PlaceClip(T, M, Playhead, A, D);
 If I >= 0 Then P.Clips[I].Sel := True;
 If Not InsertMode Then Msg('Écrasement effectué') Else Msg('Insertion effectuée');
 SetPlayhead(Playhead + D);
 NeedTL := True;
 NeedProg := True;
End;

Procedure OpenInSource(M: Integer; InP, OutP: LongInt);
Begin
 If (M < 0) Or (M >= P.NM) Then Exit;
 StopPlay;
 SrcMed := M;
 SrcPos := InP;
 SrcIn := -1;
 SrcOut := -1;
 If OutP >= 0 Then Begin
  SrcIn := InP;
  SrcOut := OutP;
 End;
 TabA := 0;
 FocusSrc := True;
 NeedA := True;
 NeedSrc := True;
End;

{ ---------- Marqueurs ---------- }

Procedure AddMarkerHere;
Var
 I: Integer;
Begin
 If P.NK >= MAXMARK Then Begin
  Msg('Trop de marqueurs');
  Exit;
 End;
 If FindMarkIdx(Playhead) >= 0 Then Exit;
 PushUndo;
 I := P.NK;
 P.Marks[I].Pos := Playhead;
 P.Marks[I].Name := 'Marqueur ' + IStr(I + 1);
 Inc(P.NK);
 { tri par position }
 While (I > 0) And (P.Marks[I - 1].Pos > P.Marks[I].Pos) Do Begin
  P.Marks[MAXMARK - 1] := P.Marks[I];
  P.Marks[I] := P.Marks[I - 1];
  P.Marks[I - 1] := P.Marks[MAXMARK - 1];
  Dec(I);
 End;
 NeedTL := True;
 NeedC := True;
 NeedProg := True;
 Msg('Marqueur ajouté');
End;

Procedure DelMarker(I: Integer);
Var
 J: Integer;
Begin
 If (I < 0) Or (I >= P.NK) Then Exit;
 PushUndo;
 For J := I To P.NK - 2 Do P.Marks[J] := P.Marks[J + 1];
 Dec(P.NK);
 MarkSel := -1;
 NeedTL := True;
 NeedC := True;
 NeedProg := True;
End;

Procedure GoMarker(Dir: Integer);
Var
 I: Integer;
Begin
 If P.NK = 0 Then Exit;
 If Dir > 0 Then Begin
  For I := 0 To P.NK - 1 Do
   If P.Marks[I].Pos > Playhead Then Begin
    SetPlayhead(P.Marks[I].Pos);
    Exit;
   End;
 End Else Begin
  For I := P.NK - 1 Downto 0 Do
   If P.Marks[I].Pos < Playhead Then Begin
    SetPlayhead(P.Marks[I].Pos);
    Exit;
   End;
 End;
End;

{ ---------- Medias ---------- }

Procedure DeleteMedia(M: Integer);
Var
 I, J, Used: Integer;
Begin
 If (M < 0) Or (M >= P.NM) Then Exit;
 Used := 0;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Med = M Then Inc(Used);
 If Used > 0 Then
  If Not Confirm('Supprimer le média', 'Ce média est utilisé par ' + IStr(Used) + ' clip(s).|' +
                 'Supprimer aussi ces clips ?') Then Exit;
 PushUndo;
 For I := P.NC - 1 Downto 0 Do
  If P.Clips[I].Med = M Then DelClip(I)
  Else If P.Clips[I].Med > M Then Dec(P.Clips[I].Med);
 For J := M To P.NM - 2 Do P.Media[J] := P.Media[J + 1];
 Dec(P.NM);
 If SrcMed = M Then SrcMed := -1 Else If SrcMed > M Then Dec(SrcMed);
 ProjSel := -1;
 NeedAll := True;
End;

Procedure NewItemDlg;
Const
 Kinds: Array[0..11] Of Integer = (MK_BARS, MK_GRAD, MK_PLASMA, MK_CHECK, MK_COUNT,
  MK_SOLID, MK_TITLE, MK_NOISE, MK_WAVES, MK_TONE, MK_MELODY, MK_PULSE);
Var
 I, K, Par, M: Integer;
 Dur: LongInt;
 Tx, Nm, S: String;
Begin
 DlgCount := 12;
 For I := 0 To 11 Do DlgItems[I] := KindName(Kinds[I]);
 I := ListDlg('Nouvel élément', 0);
 If I < 0 Then Exit;
 K := Kinds[I];
 Par := 0;
 Tx := '';
 Nm := KindName(K);
 Dur := P.Fps * 10;
 Case K Of
  MK_SOLID, MK_CHECK, MK_TITLE: Begin
   If K = MK_TITLE Then Begin
    Tx := 'TITRE';
    If Not InputBox('Nouveau titre', 'Texte du titre (22 car. max) :', Tx, 22) Then Exit;
    If Tx = '' Then Tx := 'TITRE';
    Nm := 'Titre : ' + Tx;
   End;
   DlgCount := NPRE;
   For I := 0 To NPRE - 1 Do DlgItems[I] := PreName[I];
   If K = MK_TITLE Then Par := 1 Else If K = MK_SOLID Then Par := 2 Else Par := 3;
   Par := ListDlg('Couleur', Par);
   If Par < 0 Then Exit;
   If K = MK_SOLID Then Nm := 'Matte ' + PreName[Par];
  End;
  MK_TONE, MK_PULSE: Begin
   S := '440';
   If Not InputBox('Fréquence', 'Fréquence en Hz (50 à 4000) :', S, 4) Then Exit;
   Par := Integer(Clamp(StrVal(S, 440), 50, 4000));
   Nm := Nm + ' ' + IStr(Par) + ' Hz';
   Dur := P.Fps * 8;
  End;
  MK_MELODY: Dur := P.Fps * 8;
  MK_COUNT: Dur := P.Fps * 9;
 End;
 If (K = MK_SOLID) Or (K = MK_TITLE) Then Dur := P.Fps * 5;
 PushUndo;
 M := AddMedia(Nm, K, Dur, Par, Tx, '');
 If M < 0 Then Begin
  DropLastUndo;
  MsgBox('Nouvel élément', 'Le projet contient trop de médias.');
  Exit;
 End;
 ProjSel := M;
 TabC := 0;
 ProjScroll := Max(0, M - ProjRows + 1);
 NeedAll := True;
 Msg('Élément créé : ' + P.Media[M].Name);
End;

Procedure ImportDlg;
Var
 FN: String;
Begin
 FN := '';
 If Not FileDlg('Importer un fichier', '.BMP;.DIB', FN) Then Exit;
 PushUndo;
 If ImportBmp(FN) Then Begin
  ProjSel := P.NM - 1;
  TabC := 0;
  ProjScroll := Max(0, P.NM - ProjRows);
  Msg('Importé : ' + FN);
 End Else DropLastUndo;
 NeedAll := True;
End;

{ Ajoute le media selectionne a la sequence, a la tete de lecture }
Procedure AutoAssemble;
Begin
 If (ProjSel < 0) Or (ProjSel >= P.NM) Then Begin
  Msg('Sélectionnez un élément dans le projet');
  Exit;
 End;
 DropMedia(ProjSel, DefaultTrackFor(ProjSel), Playhead);
 SetPlayhead(Playhead + P.Media[ProjSel].Dur);
End;

{ ---------- Exportations ---------- }

Function FileExists(Const FN: String): Boolean;
Var
 F: File;
Begin
 {$I-}
 Assign(F, FN);
 Reset(F, 1);
 {$I+}
 If IOResult = 0 Then Begin
  Close(F);
  FileExists := True;
 End Else FileExists := False;
End;

Procedure DoExportFrame;
Var
 FN: String;
Begin
 FN := 'IMAGE001.BMP';
 If Not InputBox('Exporter l''image', 'Nom du fichier BMP :', FN, 40) Then Exit;
 If ExtOf(FN) = '' Then FN := FN + '.BMP';
 If FileExists(FN) Then
  If Not Confirm('Exporter l''image', FN + ' existe déjà.|Le remplacer ?') Then Exit;
 If ExportBmpFrame(FN, Playhead) Then
  MsgBox('Exporter l''image', 'Image exportée : ' + FN + '|' + IStr(VW) + 'x' + IStr(VH) +
         ' pixels, 24 bits (' + TC(Playhead) + ')')
 Else MsgBox('Exporter l''image', 'Impossible d''écrire le fichier.');
End;

Procedure DoExportSeq;
Var
 Pre, S: String;
 A, B, Step, F, N, Total, Cnt: LongInt;
 Code: Integer;
 Cancel: Boolean;
 FN: String;
Begin
 If SeqEnd = 0 Then Begin
  MsgBox('Exporter la séquence', 'La séquence est vide.');
  Exit;
 End;
 Pre := 'IMG';
 If Not InputBox('Exporter la séquence', 'Préfixe des fichiers (4 car. max) :', Pre, 4) Then Exit;
 If Pre = '' Then Pre := 'IMG';
 S := IStr(P.Fps);
 If Not InputBox('Exporter la séquence', 'Une image toutes les N images :', S, 4) Then Exit;
 Step := Clamp(StrVal(S, P.Fps), 1, 9999);
 A := 0;
 B := SeqEnd;
 If P.InM >= 0 Then A := P.InM;
 If (P.OutM >= 0) And (P.OutM > A) Then B := Min(B, P.OutM);
 Total := (B - A + Step - 1) Div Step;
 If Total > 999 Then Begin
  MsgBox('Exporter la séquence', 'Trop d''images (' + IStr(Total) + ', maximum 999).|' +
         'Augmentez l''intervalle.');
  Exit;
 End;
 If Total < 1 Then Exit;
 If Not Confirm('Exporter la séquence', IStr(Total) + ' image(s) BMP seront écrites|dans le dossier courant. Continuer ?') Then
  Exit;
 Cnt := 0;
 Cancel := False;
 F := A;
 N := 0;
 While (F < B) And (Not Cancel) Do Begin
  Inc(N);
  FN := Pre + Pad(N, 4) + '.BMP';
  HideMouse;
  FillR(170, 220, 470, 260, LightGray);
  Frame(170, 220, 470, 260, Black);
  Txt(180, 226, 'Exportation : ' + FN, Black);
  FillR(180, 242, 460, 252, White);
  FillR(180, 242, 180 + Integer((N * 280) Div Total), 252, Blue);
  Txt(180, 232, IStr(N) + ' / ' + IStr(Total) + '   (Echap pour annuler)', DarkGray);
  ShowMouse;
  If Not ExportBmpFrame(FN, F) Then Begin
   MsgBox('Exporter la séquence', 'Erreur d''écriture : ' + FN);
   Cancel := True;
  End Else Inc(Cnt);
  Code := ReadKeyCode;
  If Code = 27 Then Cancel := True;
  F := F + Step;
 End;
 InvAll;
 MsgBox('Exporter la séquence', IStr(Cnt) + ' image(s) exportée(s).');
End;

Procedure DoExportEDL;
Var
 FN: String;
Begin
 FN := 'SEQUENCE.EDL';
 If Not InputBox('Exporter la liste EDL', 'Nom du fichier EDL (CMX 3600) :', FN, 40) Then Exit;
 If ExtOf(FN) = '' Then FN := FN + '.EDL';
 If ExportEDL(FN) Then MsgBox('Exporter la liste EDL', 'Liste de décisions exportée : ' + FN)
 Else MsgBox('Exporter la liste EDL', 'Impossible d''écrire le fichier.');
End;

{ ---------- Projet ---------- }

Procedure PopulateDemo;
Var
 M, I: Integer;
Begin
 M := AddMedia('Barres de couleur', MK_BARS, P.Fps * 10, 0, '', '');
 M := AddMedia('Compte à rebours', MK_COUNT, P.Fps * 9, 0, '', '');
 M := AddMedia('Plasma', MK_PLASMA, P.Fps * 10, 0, '', '');
 M := AddMedia('Ondes', MK_WAVES, P.Fps * 10, 0, '', '');
 M := AddMedia('Damier', MK_CHECK, P.Fps * 10, 3, '', '');
 M := AddMedia('Dégradé animé', MK_GRAD, P.Fps * 10, 0, '', '');
 M := AddMedia('Titre : PREMIERE', MK_TITLE, P.Fps * 5, 1, 'PREMIERE', '');
 M := AddMedia('Mélodie', MK_MELODY, P.Fps * 12, 0, '', '');
 M := AddMedia('Tonalité 440 Hz', MK_TONE, P.Fps * 8, 440, '', '');
 { Sequence de demonstration }
 I := PlaceClip(0, 1, 0, 0, P.Fps * 5);
 I := PlaceClip(0, 2, P.Fps * 5, 0, P.Fps * 5);
 If I >= 0 Then Begin
  P.Clips[I].TIn := 1;
  P.Clips[I].TInL := 12;
 End;
 I := PlaceClip(0, 3, P.Fps * 10, 0, P.Fps * 4);
 If I >= 0 Then Begin
  P.Clips[I].TIn := 3;
  P.Clips[I].TInL := 20;
  P.Clips[I].TOut := 2;
  P.Clips[I].TOutL := 15;
 End;
 I := PlaceClip(1, 6, P.Fps Div 2, 0, P.Fps * 4);
 If I >= 0 Then Begin
  P.Clips[I].TIn := 1;
  P.Clips[I].TOut := 1;
 End;
 I := PlaceClip(3, 7, 0, 0, P.Fps * 12);
 If I >= 0 Then Begin
  P.Clips[I].TIn := 1;
  P.Clips[I].TOut := 1;
  P.Clips[I].TOutL := 30;
 End;
 P.InM := -1;
 P.OutM := -1;
 ClearSel;
 ProjSel := 0;
 Modified := False;
End;

Procedure NewProject;
Begin
 If Modified Then
  If Not Confirm('Nouveau projet', 'Les modifications seront perdues.|Continuer ?') Then Exit;
 StopPlay;
 ResetProject;
 NeedAll := True;
 Msg('Nouveau projet vide');
End;

Procedure SaveAs;
Var
 FN: String;
Begin
 FN := ProjFile;
 If FN = '' Then FN := 'PROJET.PRP';
 If Not InputBox('Enregistrer le projet', 'Nom du fichier :', FN, 40) Then Exit;
 If ExtOf(FN) = '' Then FN := FN + '.PRP';
 If FN <> ProjFile Then
  If FileExists(FN) Then
   If Not Confirm('Enregistrer le projet', FN + ' existe déjà.|Le remplacer ?') Then Exit;
 If SaveProject(FN) Then Begin
  ProjFile := FN;
  Modified := False;
  Msg('Projet enregistré : ' + FN);
 End Else MsgBox('Enregistrer le projet', 'Impossible d''écrire le fichier.');
 NeedStatus := True;
End;

Procedure SaveCmd;
Begin
 If ProjFile = '' Then SaveAs
 Else If SaveProject(ProjFile) Then Begin
  Modified := False;
  Msg('Projet enregistré : ' + ProjFile);
 End Else MsgBox('Enregistrer', 'Impossible d''écrire le fichier.');
End;

Procedure OpenCmd;
Var
 FN: String;
Begin
 If Modified Then
  If Not Confirm('Ouvrir un projet', 'Les modifications seront perdues.|Continuer ?') Then Exit;
 FN := '';
 If Not FileDlg('Ouvrir un projet', '.PRP', FN) Then Exit;
 StopPlay;
 If Not LoadProject(FN) Then Begin
  MsgBox('Ouvrir un projet', 'Fichier de projet invalide : ' + FN);
  ResetProject;
 End Else Begin
  Msg('Projet ouvert : ' + FN);
  ZoomFit;
 End;
 InvAll;
End;

Procedure SeqSettings;
Var
 S: String;
 Sel: Integer;
Begin
 S := P.Name;
 If Not InputBox('Paramètres de séquence', 'Nom de la séquence :', S, 24) Then Exit;
 If S = '' Then S := P.Name;
 DlgCount := 3;
 DlgItems[0] := '24 images/seconde (cinéma)';
 DlgItems[1] := '25 images/seconde (PAL)';
 DlgItems[2] := '30 images/seconde (NTSC)';
 Case P.Fps Of
  24: Sel := 0;
  30: Sel := 2;
 Else Sel := 1;
 End;
 Sel := ListDlg('Cadence d''images', Sel);
 PushUndo;
 P.Name := S;
 If Sel >= 0 Then Begin
  Case Sel Of
   0: P.Fps := 24;
   2: P.Fps := 30;
  Else P.Fps := 25;
  End;
 End;
 NeedAll := True;
End;

Const
 HelpN = 17;
 HelpL: Array[0..HelpN - 1] Of String[72] = (
  'Espace : lecture/pause     J K L : navette arrière / arrêt / avant',
  'Gauche/Droite : image      Ctrl+Gauche/Droite : une seconde',
  'Haut/Bas : coupe précédente/suivante      Début/Fin : début/fin',
  'I / O : marquer entrée/sortie    X : effacer    M : marqueur',
  'N / P : marqueur suivant / précédent',
  '',
  'V A B C H Z T : outils de montage         S : magnétisme',
  'Suppr : supprimer       Retour : supprimer et fermer l''espace',
  'Ctrl+K : couper     Ctrl+J : dupliquer     Ctrl+R : vitesse',
  'Ctrl+Z / Ctrl+Y : annuler / rétablir',
  'Ctrl+C / X / V : copier / couper / coller      Ctrl+A : tout',
  ', et . : insérer / écraser depuis la source',
  'F7 / F8 : transition vidéo / audio      F2 : renommer le clip',
  '+ / - / \ : zoom avant / arrière / ajuster',
  'Alt+lettre ou F10 : menus        Alt+1 à Alt+5 : espaces de travail',
  'Clic droit : ajouter à la sélection     Glisser : rectangle',
  'Glisser un média ou un effet sur un clip de la séquence');

Procedure ShowHelp;
Var
 I, W, H, X, Y, Code: Integer;
 Done: Boolean;
Begin
 W := 580;
 H := 62 + HelpN * 12;
 X := (SW - W) Div 2;
 Y := (SH - H) Div 2;
 HideMouse;
 DlgBox(X, Y, W, H, 'Raccourcis clavier');
 For I := 0 To HelpN - 1 Do Txt(X + 14, Y + 28 + I * 12, HelpL[I], Black);
 DlgBtn(X + W Div 2 - 35, Y + H - 26, X + W Div 2 + 35, Y + H - 8, 'OK', True);
 ShowMouse;
 WaitRelease;
 Done := False;
 Repeat
  PollMouse;
  If PressL Then
   If InRect(MX, MY, X + W Div 2 - 35, Y + H - 26, X + W Div 2 + 35, Y + H - 8) Then Done := True;
  Code := ReadKeyCode;
  If (Code = 13) Or (Code = 27) Or (Code = 32) Then Done := True;
  Delay(10);
 Until Done;
 WaitRelease;
 DrawAll;
End;

Procedure ShowAbout;
Begin
 MsgBox('À propos de Premiere',
  'PREMIERE - Clone de Adobe Premiere Pro|' +
  'Montage vidéo non linéaire en mode graphique VGA 640x480|' +
  'Turbo Pascal 7 / Free Pascal - Sylvain Maltais (Gladir.com)|' +
  'Licence MIT - https://www.gladir.com/clonedraw');
End;

Procedure SetWorkspace(W: Integer);
Begin
 WorkSp := W;
 Case W Of
  0: Begin TabA := 0; TabC := 0; End;
  1: Begin TabA := 0; TabC := 1; End;
  2: Begin TabA := 1; TabC := 0; End;
  3: Begin TabA := 1; TabC := 1; End;
 Else Begin TabA := 1; TabC := 2; End;
 End;
 NeedAll := True;
End;

Procedure MarkIO(IsIn: Boolean);
Begin
 If FocusSrc And (TabA = 0) And (SrcMed >= 0) Then Begin
  If IsIn Then Begin
   SrcIn := SrcPos;
   If (SrcOut >= 0) And (SrcOut <= SrcIn) Then SrcOut := -1;
  End Else Begin
   SrcOut := SrcPos;
   If (SrcIn >= 0) And (SrcIn >= SrcOut) Then SrcIn := -1;
  End;
  NeedSrc := True;
 End Else Begin
  If IsIn Then Begin
   P.InM := Playhead;
   If (P.OutM >= 0) And (P.OutM <= P.InM) Then P.OutM := -1;
  End Else Begin
   P.OutM := Playhead;
   If (P.InM >= 0) And (P.InM >= P.OutM) Then P.InM := -1;
  End;
  NeedProg := True;
  NeedTL := True;
 End;
End;

Procedure RenameSel;
Var
 I: Integer;
 S: String;
Begin
 I := FirstSel;
 If I < 0 Then Exit;
 S := P.Clips[I].Name;
 If Not InputBox('Renommer le clip', 'Nouveau nom :', S, 20) Then Exit;
 If S = '' Then Exit;
 PushUndo;
 P.Clips[I].Name := S;
 NeedTL := True;
 NeedA := True;
End;

Procedure EditTitle;
Var
 I, M: Integer;
 S: String;
Begin
 I := FirstSel;
 If I < 0 Then Exit;
 M := P.Clips[I].Med;
 If P.Media[M].Kind <> MK_TITLE Then Exit;
 S := P.Media[M].Txt;
 If Not InputBox('Modifier le titre', 'Texte du titre :', S, 22) Then Exit;
 If S = '' Then Exit;
 PushUndo;
 P.Media[M].Txt := S;
 P.Media[M].Name := 'Titre : ' + S;
 NeedAll := True;
End;

Procedure ToggleSelClips(Bit: Integer);
Var
 I: Integer;
Begin
 If SelCount = 0 Then Exit;
 PushUndo;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then P.Clips[I].Fl := P.Clips[I].Fl Xor Bit;
 NeedTL := True;
 NeedProg := True;
 NeedA := True;
End;

{ ====================================================================== }
{  Execution des commandes de menu                                       }
{ ====================================================================== }

Procedure DoCommand(Id: Integer);
Var
 I: Integer;
Begin
 Case Id Of
  CM_NEW: NewProject;
  CM_OPEN: OpenCmd;
  CM_SAVE: SaveCmd;
  CM_SAVEAS: SaveAs;
  CM_IMPORT: ImportDlg;
  CM_NEWITEM: NewItemDlg;
  CM_EXPFRAME: DoExportFrame;
  CM_EXPSEQ: DoExportSeq;
  CM_EXPEDL: DoExportEDL;
  CM_QUIT: Begin
   If Modified Then Begin
    If Confirm('Quitter', 'Les modifications seront perdues.|Quitter quand même ?') Then Running := False;
   End Else Running := False;
  End;
  CM_UNDO: Begin DoUndo; NeedAll := True; Msg('Annulé'); End;
  CM_REDO: Begin DoRedo; NeedAll := True; Msg('Rétabli'); End;
  CM_CUT: Begin DoCopy; DoDelete(False); End;
  CM_COPY: DoCopy;
  CM_PASTE: PasteAt(Playhead);
  CM_DELETE: DoDelete(False);
  CM_RIPDEL: DoDelete(True);
  CM_DUP: DoDuplicate;
  CM_SELALL: Begin
   For I := 0 To P.NC - 1 Do P.Clips[I].Sel := True;
   NeedTL := True;
   NeedA := True;
  End;
  CM_SELNONE: Begin ClearSel; NeedTL := True; NeedA := True; End;
  CM_RENAME: RenameSel;
  CM_SPEED: ChangeSpeed;
  CM_ENABLE: ToggleSelClips(CF_OFF);
  CM_EDITTITLE: EditTitle;
  CM_RESETFX: ResetFx;
  CM_SPLIT: SplitAtPlayhead;
  CM_INSERT: SourceEdit(True);
  CM_OVERWRITE: SourceEdit(False);
  CM_VTRANS: SetDefaultTransition(True);
  CM_ATRANS: SetDefaultTransition(False);
  CM_NOTRANS: Begin
   If SelCount > 0 Then Begin
    PushUndo;
    For I := 0 To P.NC - 1 Do
     If P.Clips[I].Sel Then Begin
      P.Clips[I].TIn := 0;
      P.Clips[I].TOut := 0;
     End;
    NeedAll := True;
   End;
  End;
  CM_SEQSET: SeqSettings;
  CM_MARKIN: MarkIO(True);
  CM_MARKOUT: MarkIO(False);
  CM_CLEARIO: Begin
   P.InM := -1;
   P.OutM := -1;
   SrcIn := -1;
   SrcOut := -1;
   NeedAll := True;
  End;
  CM_REMGAP: RemoveGap;
  CM_ZOOMIN: ZoomBy(1, (TLX0 + TLX1) Div 2);
  CM_ZOOMOUT: ZoomBy(-1, (TLX0 + TLX1) Div 2);
  CM_ZOOMFIT: ZoomFit;
  CM_GOSTART: SetPlayhead(0);
  CM_GOEND: SetPlayhead(SeqEnd);
  CM_NEXTEDIT: Begin
   I := Integer(NextEdit(Playhead));
   If I >= 0 Then SetPlayhead(I);
  End;
  CM_PREVEDIT: Begin
   I := Integer(PrevEdit(Playhead));
   If I >= 0 Then SetPlayhead(I) Else SetPlayhead(0);
  End;
  CM_ADDMARK: AddMarkerHere;
  CM_NEXTMARK: GoMarker(1);
  CM_PREVMARK: GoMarker(-1);
  CM_DELMARK: Begin
   If MarkSel >= 0 Then DelMarker(MarkSel)
   Else DelMarker(FindMarkIdx(Playhead));
  End;
  CM_DELMARKS: Begin
   If P.NK > 0 Then Begin
    PushUndo;
    P.NK := 0;
    MarkSel := -1;
    NeedAll := True;
   End;
  End;
  CM_QFULL: Begin Quality := 1; NeedProg := True; End;
  CM_QHALF: Begin Quality := 2; NeedProg := True; End;
  CM_QQUART: Begin Quality := 4; NeedProg := True; End;
  CM_SAFE: Begin SafeOn := Not SafeOn; NeedAll := True; End;
  CM_WAVE: Begin WaveOn := Not WaveOn; NeedTL := True; End;
  CM_SNAP: Begin SnapOn := Not SnapOn; NeedAll := True; End;
  CM_AUDIO: Begin AudioOn := Not AudioOn; StopSound; End;
  CM_LOOP: Begin LoopOn := Not LoopOn; End;
  CM_WS0..CM_WS0 + 4: SetWorkspace(Id - CM_WS0);
  CM_TABS: Begin TabA := 0; NeedAll := True; End;
  CM_TABCTL: Begin TabA := 1; NeedAll := True; End;
  CM_TABPROJ: Begin TabC := 0; NeedAll := True; End;
  CM_TABEFF: Begin TabC := 1; NeedAll := True; End;
  CM_TABMARK: Begin TabC := 2; NeedAll := True; End;
  CM_HELP: ShowHelp;
  CM_ABOUT: ShowAbout;
 End;
 NeedStatus := True;
End;

{ ====================================================================== }
{  Gestion de la souris                                                  }
{ ====================================================================== }

Var
 LastMX, LastMY: LongInt;
 HintStr: String;
 MoveA, MoveB: Array[0..MAXCLIPS-1] Of LongInt;
 MoveT: Array[0..MAXCLIPS-1] Of Integer;

Procedure CtlApply(Id, V: Integer);
Var
 I, W: Integer;
 Vid, Ok: Boolean;
Begin
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   Vid := IsVideoTrack(P.Clips[I].Trk);
   Ok := True;
   W := V;
   If (Id = 9) Or (Id = 23) Then Ok := Not Vid
   Else If ((Id >= 1) And (Id <= 8)) Or ((Id >= 20) And (Id <= 22)) Then Ok := Vid;
   If ((Id = 30) Or (Id = 31)) And (Not Vid) And (W > 1) Then W := 1;
   If Ok Then CtlSet(I, Id, W);
  End;
 SetModified;
End;

Procedure SliderUpdate(X: LongInt);
Var
 R, Id: Integer;
 V: LongInt;
 X1, X2: Integer;
Begin
 R := DragSlider;
 If (R < 0) Or (R >= CtlN) Then Exit;
 Id := CtlId[R];
 X1 := CtlSliderX1;
 X2 := CtlSliderX2;
 V := CtlMin(Id) + ((X - X1) * (CtlMax(Id) - CtlMin(Id)) + (X2 - X1) Div 2) Div (X2 - X1);
 V := Clamp(V, CtlMin(Id), CtlMax(Id));
 If (Id = 4) Or (Id = 3) Or (Id = 7) Then
  If Abs(V - CtlDef(Id)) < 3 Then V := CtlDef(Id);
 If V <> CtlGet(FirstSel, Id) Then Begin
  CtlApply(Id, Integer(V));
  DragMoved := True;
  NeedA := True;
  NeedProg := True;
  NeedTL := True;
 End;
End;

Procedure PressControls;
Var
 R, Id, C, V: Integer;
Begin
 If CtlN > CTLROWS Then Begin
  If InRect(MX, MY, AX2 - 14, AY1 + 17, AX2 - 4, AY1 + 26) Then Begin
   If CtlScroll > 0 Then Dec(CtlScroll);
   NeedA := True;
   Exit;
  End;
  If InRect(MX, MY, AX2 - 14, AY1 + 28, AX2 - 4, AY1 + 37) Then Begin
   If CtlScroll < CtlN - CTLROWS Then Inc(CtlScroll);
   NeedA := True;
   Exit;
  End;
 End;
 R := CtlHit(MX, MY);
 If R < 0 Then Exit;
 C := FirstSel;
 If C < 0 Then Exit;
 Id := CtlId[R];
 Case CtlKind[R] Of
  0: Begin
   If MX >= CtlSliderX1 - 4 Then Begin
    PushUndo;
    DragMode := DM_SLIDER;
    DragSlider := R;
    DragMoved := False;
    SliderUpdate(MX);
   End Else If DblClick Then Begin
    PushUndo;
    CtlApply(Id, CtlDef(Id));
    NeedA := True;
    NeedProg := True;
    NeedTL := True;
   End;
  End;
  1: Begin
   PushUndo;
   CtlApply(Id, 1 - CtlGet(C, Id));
   NeedA := True;
   NeedProg := True;
   NeedTL := True;
  End;
  2: Begin
   V := CtlGet(C, Id) + 1;
   If IsVideoTrack(P.Clips[C].Trk) Then Begin
    If V > 4 Then V := 0;
   End Else If V > 1 Then V := 0;
   PushUndo;
   CtlApply(Id, V);
   NeedA := True;
   NeedProg := True;
   NeedTL := True;
  End;
 End;
End;

Procedure MonButton(IsProg: Boolean; B: Integer);
Begin
 If IsProg Then Begin
  FocusSrc := False;
  Case B Of
   0: MarkIO(True);
   1: MarkIO(False);
   2: Begin StopPlay; DoCommand(CM_PREVEDIT); End;
   3: Begin StopPlay; SetPlayhead(Playhead - 1); End;
   4: TogglePlay(1);
   5: Begin StopPlay; SetPlayhead(Playhead + 1); End;
   6: Begin StopPlay; DoCommand(CM_NEXTEDIT); End;
   7: DoExportFrame;
  End;
 End Else Begin
  FocusSrc := True;
  Case B Of
   0: MarkIO(True);
   1: MarkIO(False);
   2: Begin StopPlay; If SrcIn >= 0 Then SetSrcPos(SrcIn) Else SetSrcPos(0); End;
   3: Begin StopPlay; SetSrcPos(SrcPos - 1); End;
   4: Begin
    If SrcMed >= 0 Then TogglePlay(2);
   End;
   5: Begin StopPlay; SetSrcPos(SrcPos + 1); End;
   6: SourceEdit(True);
   7: SourceEdit(False);
  End;
 End;
End;

Procedure PressMonitor(IsProg: Boolean);
Var
 B: Integer;
Begin
 FocusSrc := Not IsProg;
 B := MonBtnHit(IsProg, MX, MY);
 If B >= 0 Then Begin
  MonButton(IsProg, B);
  Exit;
 End;
 If MonScrubHit(IsProg, MX, MY) Then Begin
  StopPlay;
  If IsProg Then Begin
   DragMode := DM_SCRUBP;
   SetPlayhead(MonScrubFrame(True, MX));
  End Else Begin
   DragMode := DM_SCRUBS;
   SetSrcPos(MonScrubFrame(False, MX));
  End;
 End;
End;

Procedure PressPanelC;
Var
 B, I, K: Integer;
 EndFr: LongInt;
Begin
 If MY <= CY1 + 13 Then Begin
  B := TabAt(CX1, 3, TabNC, MX);
  If B >= 0 Then Begin
   TabC := B;
   NeedC := True;
  End;
  Exit;
 End;
 Case TabC Of
  0: Begin
   B := ProjBtnHit(MX, MY);
   If B >= 0 Then Begin
    Case B Of
     0: ImportDlg;
     1: NewItemDlg;
     2: AutoAssemble;
     3: DeleteMedia(ProjSel);
    End;
    Exit;
   End;
   If InRect(MX, MY, CX2 - 12, PROWY0, CX2 - 2, PROWY0 + 10) Then Begin
    If ProjScroll > 0 Then Dec(ProjScroll);
    NeedC := True;
    Exit;
   End;
   If InRect(MX, MY, CX2 - 12, CY2 - 36, CX2 - 2, CY2 - 26) Then Begin
    If ProjScroll < P.NM - ProjRows Then Inc(ProjScroll);
    NeedC := True;
    Exit;
   End;
   I := ProjHit(MX, MY);
   If I >= 0 Then Begin
    ProjSel := I;
    NeedC := True;
    If DblClick Then OpenInSource(I, 0, -1)
    Else Begin
     DragMode := DM_MEDIA;
     DragItem := I;
     DragX0 := MX;
     DragY0 := MY;
    End;
   End;
  End;
  1: Begin
   BuildEffRows;
   If InRect(MX, MY, CX1 + 3, CY2 - 21, CX2 - 3, CY2 - 3) Then Begin
    If EffSel >= 0 Then ApplyEffectToSel(EffSel);
    Exit;
   End;
   If InRect(MX, MY, CX2 - 12, EROWY0, CX2 - 2, EROWY0 + 10) Then Begin
    If EffScroll > 0 Then Dec(EffScroll);
    NeedC := True;
    Exit;
   End;
   If InRect(MX, MY, CX2 - 12, CY2 - 38, CX2 - 2, CY2 - 28) Then Begin
    If EffScroll < EffRowN - EffRows Then Inc(EffScroll);
    NeedC := True;
    Exit;
   End;
   I := EffHit(MX, MY);
   If I >= 0 Then Begin
    If EffRowKind[I] = 0 Then Begin
     GrpOpen[EffRowId[I]] := Not GrpOpen[EffRowId[I]];
     NeedC := True;
    End Else Begin
     EffSel := EffRowId[I];
     NeedC := True;
     If DblClick Then ApplyEffectToSel(EffSel)
     Else Begin
      DragMode := DM_EFFECT;
      DragX0 := MX;
      DragY0 := MY;
     End;
    End;
   End;
  End;
 Else Begin
   If InRect(MX, MY, CX1 + 3, CY2 - 21, CX1 + 100, CY2 - 3) Then Begin
    AddMarkerHere;
    Exit;
   End;
   If InRect(MX, MY, CX1 + 102, CY2 - 21, CX2 - 3, CY2 - 3) Then Begin
    If MarkSel >= 0 Then DelMarker(MarkSel) Else DelMarker(FindMarkIdx(Playhead));
    Exit;
   End;
   If (MY >= EROWY0) And (MX < CX2 - 14) Then Begin
    I := (MY - EROWY0) Div EROWH + MarkScroll;
    If (I >= 0) And (I < P.NK) Then Begin
     MarkSel := I;
     SetPlayhead(P.Marks[I].Pos);
     NeedC := True;
    End;
   End;
  End;
 End;
End;

{ ---------- Chronologie ---------- }

Procedure SelectFwd(I: Integer);
Var
 J: Integer;
 S: LongInt;
 T: Integer;
Begin
 T := P.Clips[I].Trk;
 S := P.Clips[I].Start;
 ClearSel;
 For J := 0 To P.NC - 1 Do
  If (P.Clips[J].Trk = T) And (P.Clips[J].Start >= S) Then P.Clips[J].Sel := True;
 NeedTL := True;
 NeedA := True;
End;

Procedure TypeTool(T: Integer; F: LongInt; I: Integer);
Var
 S: String;
 M, K: Integer;
Begin
 If (I >= 0) And (P.Media[P.Clips[I].Med].Kind = MK_TITLE) Then Begin
  ClearSel;
  P.Clips[I].Sel := True;
  EditTitle;
  Exit;
 End;
 If T >= 3 Then T := 1;
 If TrackLocked(T) Then Exit;
 S := 'TITRE';
 If Not InputBox('Outil texte', 'Texte du titre (22 car. max) :', S, 22) Then Exit;
 If S = '' Then Exit;
 PushUndo;
 M := AddMedia('Titre : ' + S, MK_TITLE, P.Fps * 5, 1, S, '');
 If M < 0 Then Begin
  DropLastUndo;
  Exit;
 End;
 ClearSel;
 K := PlaceClip(T, M, F, 0, P.Fps * 5);
 If K >= 0 Then P.Clips[K].Sel := True;
 NeedAll := True;
End;

Procedure PressTrackArea;
Var
 Row, T, I: Integer;
 F, F2: LongInt;
 X1, X2: LongInt;
Begin
 Row := (MY - TRY0) Div TRH;
 T := RowTrack(Row);
 F := XToFrame(MX);
 I := FindClip(T, F);
 Case CurTool Of
  TL_SELECT: Begin
   If I >= 0 Then Begin
    If TrackLocked(T) Then Begin
     Msg('Piste verrouillée');
     Exit;
    End;
    If DblClick Then Begin
     OpenInSource(P.Clips[I].Med, P.Clips[I].InPt,
                  P.Clips[I].InPt + (P.Clips[I].Dur * P.Clips[I].Speed) Div 100);
     Exit;
    End;
    X1 := FrameToX(P.Clips[I].Start);
    X2 := FrameToX(ClipEnd(I)) - 1;
    If Not P.Clips[I].Sel Then Begin
     ClearSel;
     P.Clips[I].Sel := True;
    End;
    DragClip := I;
    PushUndo;
    DragMoved := False;
    If (MX - X1 <= 3) And (X2 - X1 >= 10) Then DragMode := DM_TRIML
    Else If (X2 - MX <= 3) And (X2 - X1 >= 10) Then DragMode := DM_TRIMR
    Else Begin
     DragMode := DM_MOVE;
     DragF0 := F;
     DragRow0 := Row;
    End;
    NeedTL := True;
    NeedA := True;
   End Else Begin
    ClearSel;
    DragMode := DM_MARQUEE;
    MqX0 := MX; MqY0 := MY; MqX1 := MX; MqY1 := MY;
    NeedTL := True;
    NeedA := True;
   End;
  End;
  TL_TRACKFWD: If I >= 0 Then SelectFwd(I);
  TL_RIPPLE: Begin
   If (I >= 0) And (Not TrackLocked(T)) Then Begin
    X1 := FrameToX(P.Clips[I].Start);
    X2 := FrameToX(ClipEnd(I)) - 1;
    If (MX - X1 <= 5) Or (X2 - MX <= 5) Then Begin
     ClearSel;
     P.Clips[I].Sel := True;
     DragClip := I;
     PushUndo;
     DragMoved := False;
     If MX - X1 <= 5 Then DragMode := DM_RIPL Else DragMode := DM_RIPR;
     NeedTL := True;
     NeedA := True;
    End;
   End;
  End;
  TL_RAZOR: Begin
   If (I >= 0) And (Not TrackLocked(T)) Then Begin
    F2 := SnapTo(F, -1);
    SnapGuide := -1;
    If (F2 <= P.Clips[I].Start) Or (F2 >= ClipEnd(I)) Then F2 := F;
    PushUndo;
    SplitClip(I, F2);
    NeedTL := True;
    NeedProg := True;
    Msg('Coupe ajoutée à ' + TC(F2));
   End;
  End;
  TL_HAND: Begin
   DragMode := DM_HAND;
   DragX0 := MX;
   HandScroll0 := ScrollF;
  End;
  TL_ZOOM: ZoomBy(1, MX);
  TL_TYPE: TypeTool(T, F, I);
 End;
End;

Procedure PressTimeline;
Var
 Row, T, B, TL0, TW0: Integer;
Begin
 FocusSrc := False;
 B := TLHdrBtn(MX, MY);
 If B >= 0 Then Begin
  Case B Of
   0: Begin SnapOn := Not SnapOn; NeedAll := True; End;
   1: AddMarkerHere;
   2: ZoomBy(-1, (TLX0 + TLX1) Div 2);
   3: ZoomBy(1, (TLX0 + TLX1) Div 2);
   4: ZoomFit;
  End;
  Exit;
 End;
 If (MX < TLX0) And (MY >= TRY0) And (MY < TRY0 + NTRK * TRH) Then Begin
  Row := (MY - TRY0) Div TRH;
  T := RowTrack(Row);
  If InRect(MX, MY, LX1 + 26, RowY(Row) + 7, LX1 + 38, RowY(Row) + 19) Then Begin
   P.TrkF[T] := P.TrkF[T] Xor TF_HIDE;
   SetModified;
   NeedAll := True;
  End Else If InRect(MX, MY, LX1 + 42, RowY(Row) + 7, LX1 + 54, RowY(Row) + 19) Then Begin
   P.TrkF[T] := P.TrkF[T] Xor TF_LOCK;
   SetModified;
   NeedTL := True;
  End;
  Exit;
 End;
 If (MY >= HSY1) And (MY <= HSY2) And (MX >= TLX0) And (MX <= TLX1) Then Begin
  HScrollThumb(TL0, TW0);
  If (MX >= TL0) And (MX <= TL0 + TW0) Then Begin
   DragMode := DM_HSCROLL;
   DragX0 := MX;
   HandScroll0 := ScrollF;
  End Else Begin
   If MX < TL0 Then ScrollF := Max(0, ScrollF - VisFrames)
   Else ScrollF := ScrollF + VisFrames;
   NeedTL := True;
  End;
  Exit;
 End;
 If (MY >= RULY1) And (MY <= RULY2) And (MX >= TLX0) And (MX <= TLX1) Then Begin
  StopPlay;
  DragMode := DM_SCRUB;
  SetPlayhead(XToFrame(MX));
  Exit;
 End;
 If (MX >= TLX0) And (MX <= TLX1) And (MY >= TRY0) And (MY < TRY0 + NTRK * TRH) Then
  PressTrackArea;
End;

Procedure ApplyMove;
Var
 I, DMin, DMax, DRow, R, NT: Integer;
 DF, MinS, MaxE, S1: LongInt;
 Base: PProject;
Begin
 If UndoCnt = 0 Then Exit;
 Base := UndoStk[UndoCnt - 1];
 P := Base^;
 MinS := 999999999;
 MaxE := 0;
 DMin := -10;
 DMax := 10;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   MinS := Min(MinS, P.Clips[I].Start);
   MaxE := Max(MaxE, ClipEnd(I));
   R := TrackRow(P.Clips[I].Trk);
   If R <= 2 Then Begin
    DMin := Integer(Max(DMin, -R));
    DMax := Integer(Min(DMax, 2 - R));
   End Else Begin
    DMin := Integer(Max(DMin, 3 - R));
    DMax := Integer(Min(DMax, 5 - R));
   End;
  End;
 DF := XToFrame(MX) - DragF0;
 If MinS + DF < 0 Then DF := -MinS;
 SnapGuide := -1;
 S1 := SnapTo(MinS + DF, -2);
 If SnapGuide >= 0 Then DF := S1 - MinS
 Else Begin
  S1 := SnapTo(MaxE + DF, -2);
  If SnapGuide >= 0 Then DF := S1 - MaxE;
 End;
 If MinS + DF < 0 Then DF := -MinS;
 DRow := Integer(Clamp(FDiv(MY - TRY0, TRH) - DragRow0, DMin, DMax));
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then
   If TrackLocked(RowTrack(TrackRow(P.Clips[I].Trk) + DRow)) Then DRow := 0;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   NT := RowTrack(TrackRow(P.Clips[I].Trk) + DRow);
   P.Clips[I].Start := P.Clips[I].Start + DF;
   P.Clips[I].Trk := NT;
  End;
 DragMoved := (DF <> 0) Or (DRow <> 0);
 NeedTL := True;
End;

Procedure FinishMove;
Var
 I, N: Integer;
Begin
 If Not DragMoved Then Begin
  DropLastUndo;
  Exit;
 End;
 N := 0;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   MoveT[N] := P.Clips[I].Trk;
   MoveA[N] := P.Clips[I].Start;
   MoveB[N] := ClipEnd(I);
   Inc(N);
  End;
 For I := 0 To N - 1 Do CutRange(MoveT[I], MoveA[I], MoveB[I], True);
 NeedProg := True;
 NeedTL := True;
End;

Procedure ApplyTrim(IsLeft, Ripple: Boolean);
Var
 C, J: Integer;
 E, OS, OD, OE, In0, Lo, Hi, D: LongInt;
 Spd: LongInt;
 Base: PProject;
 Unl: Boolean;
Begin
 If UndoCnt = 0 Then Exit;
 Base := UndoStk[UndoCnt - 1];
 P := Base^;
 C := DragClip;
 SnapGuide := -1;
 E := SnapTo(XToFrame(MX), C);
 OS := P.Clips[C].Start;
 OD := P.Clips[C].Dur;
 OE := OS + OD;
 In0 := P.Clips[C].InPt;
 Spd := P.Clips[C].Speed;
 Unl := MediaUnlimited(P.Clips[C].Med);
 If IsLeft Then Begin
  Lo := 0;
  Hi := OE - 1;
  If Not Ripple Then
   For J := 0 To P.NC - 1 Do
    If (J <> C) And (P.Clips[J].Trk = P.Clips[C].Trk) And (ClipEnd(J) <= OS) Then
     Lo := Max(Lo, ClipEnd(J));
  If Not Unl Then Lo := Max(Lo, OS - (In0 * 100) Div Spd);
  If Ripple Then Begin
   If Unl Then Lo := OS - 100000 Else Lo := OS - (In0 * 100) Div Spd;
  End;
  E := Clamp(E, Lo, Hi);
  D := E - OS;
  If Ripple Then Begin
   P.Clips[C].InPt := Max(0, In0 + (D * Spd) Div 100);
   P.Clips[C].Dur := OD - D;
   ShiftFrom(OE, -D, -1);
  End Else Begin
   P.Clips[C].Start := E;
   P.Clips[C].InPt := Max(0, In0 + (D * Spd) Div 100);
   P.Clips[C].Dur := OD - D;
  End;
 End Else Begin
  Lo := OS + 1;
  Hi := 1000000000;
  If Not Ripple Then
   For J := 0 To P.NC - 1 Do
    If (J <> C) And (P.Clips[J].Trk = P.Clips[C].Trk) And (P.Clips[J].Start >= OE) Then
     Hi := Min(Hi, P.Clips[J].Start);
  If Not Unl Then Hi := Min(Hi, OS + ((MediaMax(P.Clips[C].Med) - In0) * 100) Div Spd);
  If Hi < Lo Then Hi := Lo;
  E := Clamp(E, Lo, Hi);
  If Ripple Then ShiftFrom(OE, E - OE, -1);
  P.Clips[C].Dur := E - OS;
 End;
 If P.Clips[C].TInL > P.Clips[C].Dur Then P.Clips[C].TInL := Integer(P.Clips[C].Dur);
 If P.Clips[C].TOutL > P.Clips[C].Dur Then P.Clips[C].TOutL := Integer(P.Clips[C].Dur);
 DragMoved := (P.Clips[C].Dur <> OD) Or (P.Clips[C].Start <> OS);
 NeedTL := True;
 NeedProg := True;
End;

Procedure UpdateMarquee;
Var
 I: Integer;
 X1, X2, Y1, Y2, CX1p, CX2p, CY1p, CY2p: LongInt;
Begin
 X1 := Min(MqX0, MqX1);
 X2 := Max(MqX0, MqX1);
 Y1 := Min(MqY0, MqY1);
 Y2 := Max(MqY0, MqY1);
 For I := 0 To P.NC - 1 Do Begin
  CX1p := FrameToX(P.Clips[I].Start);
  CX2p := FrameToX(ClipEnd(I)) - 1;
  CY1p := RowY(TrackRow(P.Clips[I].Trk));
  CY2p := CY1p + TRH - 1;
  P.Clips[I].Sel := (Not TrackLocked(P.Clips[I].Trk)) And (CX1p <= X2) And (CX2p >= X1) And
                    (CY1p <= Y2) And (CY2p >= Y1);
 End;
End;

Procedure DropOnTimeline(Kind: Integer);
Var
 Row, T, I: Integer;
 F: LongInt;
Begin
 Row := (MY - TRY0) Div TRH;
 If (MY < TRY0) Or (Row < 0) Or (Row >= NTRK) Then Exit;
 T := RowTrack(Row);
 F := XToFrame(MX);
 If Kind = 0 Then Begin
  F := SnapTo(F, -1);
  SnapGuide := -1;
  DropMedia(DragItem, T, F);
 End Else Begin
  I := FindClip(T, F);
  If I >= 0 Then Begin
   ClearSel;
   P.Clips[I].Sel := True;
   ApplyEffect(EffSel, I, F >= P.Clips[I].Start + P.Clips[I].Dur Div 2, False);
  End;
 End;
End;

Procedure OnRelease;
Begin
 Case DragMode Of
  DM_MOVE: FinishMove;
  DM_TRIML, DM_TRIMR, DM_RIPL, DM_RIPR, DM_SLIDER:
   If Not DragMoved Then DropLastUndo;
  DM_MEDIA: Begin
   If (Abs(MX - DragX0) > 4) Or (Abs(MY - DragY0) > 4) Then Begin
    If InRect(MX, MY, TLX0, TRY0, TLX1, TRY0 + NTRK * TRH - 1) Then DropOnTimeline(0)
    Else If InRect(MX, MY, BX1, BY1, BX2, BY2) Then
     DropMedia(DragItem, DefaultTrackFor(DragItem), Playhead)
    Else If InRect(MX, MY, AX1, AY1, AX2, AY2) Then OpenInSource(DragItem, 0, -1);
   End;
  End;
  DM_EFFECT: Begin
   If (Abs(MX - DragX0) > 4) Or (Abs(MY - DragY0) > 4) Then
    If InRect(MX, MY, TLX0, TRY0, TLX1, TRY0 + NTRK * TRH - 1) Then DropOnTimeline(1);
  End;
 End;
 DragMode := DM_NONE;
 SnapGuide := -1;
 NeedTL := True;
 NeedA := True;
 NeedProg := True;
 NeedStatus := True;
End;

Procedure OnDrag;
Var
 Vis: LongInt;
 TL0, TW0: Integer;
 Tot: LongInt;
Begin
 If (MX = LastMX) And (MY = LastMY) And (DragMode <> DM_SCRUB) Then Exit;
 Case DragMode Of
  DM_SCRUB: Begin
   Vis := VisFrames;
   If MX > TLX1 - 4 Then ScrollF := ScrollF + Max(1, Vis Div 50);
   If (MX < TLX0 + 4) And (ScrollF > 0) Then ScrollF := Max(0, ScrollF - Max(1, Vis Div 50));
   SetPlayhead(XToFrame(Clamp(MX, TLX0, TLX1)));
  End;
  DM_SCRUBP: SetPlayhead(MonScrubFrame(True, MX));
  DM_SCRUBS: SetSrcPos(MonScrubFrame(False, MX));
  DM_MOVE: ApplyMove;
  DM_TRIML: ApplyTrim(True, False);
  DM_TRIMR: ApplyTrim(False, False);
  DM_RIPL: ApplyTrim(True, True);
  DM_RIPR: ApplyTrim(False, True);
  DM_MARQUEE: Begin
   MqX1 := Clamp(MX, TLX0, TLX1);
   MqY1 := Clamp(MY, TRY0, TRY0 + NTRK * TRH - 1);
   UpdateMarquee;
   NeedTL := True;
   NeedA := True;
  End;
  DM_HAND: Begin
   ScrollF := Max(0, HandScroll0 - FDiv((MX - DragX0) * P.Fps, PPS));
   NeedTL := True;
  End;
  DM_HSCROLL: Begin
   Tot := HScrollThumb(TL0, TW0);
   ScrollF := Max(0, HandScroll0 + ((MX - DragX0) * Tot) Div (TLX1 - TLX0));
   NeedTL := True;
  End;
  DM_SLIDER: SliderUpdate(MX);
  DM_MEDIA: Msg('Glissez le média sur une piste de la séquence...');
  DM_EFFECT: Msg('Glissez l''effet sur un clip de la séquence...');
 End;
End;

Function ToolHint(B: Integer): String;
Begin
 If B <= 6 Then ToolHint := ToolNames[B] Else ToolHint := 'Magnétisme (S)';
End;

Function MonHint(IsProg: Boolean; B: Integer): String;
Begin
 If IsProg Then
  Case B Of
   0: MonHint := 'Marquer l''entrée (I)';
   1: MonHint := 'Marquer la sortie (O)';
   2: MonHint := 'Aller à la coupe précédente (Haut)';
   3: MonHint := 'Reculer d''une image (Gauche)';
   4: MonHint := 'Lecture / Pause (Espace)';
   5: MonHint := 'Avancer d''une image (Droite)';
   6: MonHint := 'Aller à la coupe suivante (Bas)';
  Else MonHint := 'Exporter l''image courante (BMP)';
  End
 Else
  Case B Of
   0: MonHint := 'Marquer l''entrée de la source (I)';
   1: MonHint := 'Marquer la sortie de la source (O)';
   2: MonHint := 'Aller à l''entrée';
   3: MonHint := 'Reculer d''une image';
   4: MonHint := 'Lecture / Pause de la source';
   5: MonHint := 'Avancer d''une image';
   6: MonHint := 'Insérer dans la séquence (,)';
  Else MonHint := 'Écraser dans la séquence (.)';
  End;
End;

Procedure UpdateHint;
Var
 S: String;
 B, Row, T, I: Integer;
Begin
 S := '';
 B := ToolHit(MX, MY);
 If B >= 0 Then S := ToolHint(B)
 Else If InRect(MX, MY, AX1, AY1, AX2, AY2) And (TabA = 0) Then Begin
  B := MonBtnHit(False, MX, MY);
  If B >= 0 Then S := MonHint(False, B);
 End
 Else If InRect(MX, MY, BX1, BY1, BX2, BY2) Then Begin
  B := MonBtnHit(True, MX, MY);
  If B >= 0 Then S := MonHint(True, B);
 End
 Else If InRect(MX, MY, TLX0, TRY0, TLX1, TRY0 + NTRK * TRH - 1) Then Begin
  Row := (MY - TRY0) Div TRH;
  T := RowTrack(Row);
  I := FindClip(T, XToFrame(MX));
  If I >= 0 Then
   S := P.Clips[I].Name + '  -  ' + TC(P.Clips[I].Start) + '  durée ' + TC(P.Clips[I].Dur)
  Else S := 'Piste ' + TrackName(T) + '  -  ' + TC(XToFrame(MX));
 End;
 If S <> HintStr Then Begin
  HintStr := S;
  If TickDiff(Ticks, MsgT0) >= 250 Then Begin
   StatusMsg := S;
   NeedStatus := True;
  End;
 End;
End;

Procedure MenuClose;
Begin
 MenuActive := False;
 InvAll;
End;

Procedure MenuExec(Item: Integer);
Var
 Id: Integer;
Begin
 If (Item < 0) Or (Item >= Menus[ActiveMenu].N) Then Exit;
 If Menus[ActiveMenu].It[Item].Sep Then Exit;
 Id := Menus[ActiveMenu].It[Item].Id;
 If Not CmdEnabled(Id) Then Exit;
 MenuActive := False;
 DrawAll;
 DoCommand(Id);
 InvAll;
End;

Procedure MenuMouse;
Var
 Bar, Item: Integer;
Begin
 Bar := MenuBarHit(MX, MY);
 If (MX <> LastMX) Or (MY <> LastMY) Then Begin
  If (Bar >= 0) And (Bar <> ActiveMenu) Then Begin
   ActiveMenu := Bar;
   ActiveItem := -1;
   InvAll;
  End Else Begin
   Item := MenuItemHit(MX, MY, ActiveMenu);
   If Item <> ActiveItem Then Begin
    ActiveItem := Item;
    HideMouse;
    DrawMenuDrop(ActiveMenu);
    ShowMouse;
   End;
  End;
 End;
 If PressL Then Begin
  If Bar >= 0 Then Begin
   If Bar = ActiveMenu Then MenuClose Else Begin
    ActiveMenu := Bar;
    ActiveItem := -1;
    InvAll;
   End;
  End Else Begin
   Item := MenuItemHit(MX, MY, ActiveMenu);
   If Item >= 0 Then MenuExec(Item) Else MenuClose;
  End;
 End;
End;

Procedure OpenMenu(M: Integer);
Begin
 StopPlay;
 MenuActive := True;
 ActiveMenu := M;
 ActiveItem := -1;
 InvAll;
End;

Procedure HandleMouse;
Var
 B: Integer;
Begin
 PollMouse;
 If MenuActive Then Begin
  MenuMouse;
  LastMX := MX;
  LastMY := MY;
  Exit;
 End;
 If PressL Then Begin
  If MY < MENUH Then Begin
   B := MenuBarHit(MX, MY);
   If B >= 0 Then OpenMenu(B);
  End
  Else If MY <= 38 Then Begin
   B := WsHit(MX, MY);
   If B >= 0 Then SetWorkspace(B);
  End
  Else If InRect(MX, MY, AX1, AY1, AX2, AY2) Then Begin
   If MY <= AY1 + 13 Then Begin
    B := TabAt(AX1, 2, TabNA, MX);
    If B >= 0 Then Begin
     StopPlay;
     TabA := B;
     NeedA := True;
    End;
   End Else If TabA = 0 Then PressMonitor(False)
   Else PressControls;
  End
  Else If InRect(MX, MY, BX1, BY1, BX2, BY2) Then PressMonitor(True)
  Else If InRect(MX, MY, CX1, CY1, CX2, CY2) Then PressPanelC
  Else If InRect(MX, MY, TX1, TY1, TX2, TY2) Then Begin
   B := ToolHit(MX, MY);
   If (B >= 0) And (B <= 6) Then Begin
    CurTool := B;
    NeedAll := True;
   End Else If B = 7 Then Begin
    SnapOn := Not SnapOn;
    NeedAll := True;
   End;
  End
  Else If InRect(MX, MY, LX1, LY1, LX2, LY2) Then PressTimeline
  Else If InRect(MX, MY, MX1, LY1, MX2, LY2) Then Begin
   PeakL := 0;
   PeakR := 0;
   NeedMeters := True;
  End;
 End
 Else If PressR Then Begin
  If InRect(MX, MY, TLX0, TRY0, TLX1, TRY0 + NTRK * TRH - 1) Then Begin
   B := FindClip(RowTrack((MY - TRY0) Div TRH), XToFrame(MX));
   If CurTool = TL_ZOOM Then ZoomBy(-1, MX)
   Else If B >= 0 Then Begin
    If Not TrackLocked(P.Clips[B].Trk) Then Begin
     P.Clips[B].Sel := Not P.Clips[B].Sel;
     NeedTL := True;
     NeedA := True;
    End;
   End;
  End
  Else If (TabA = 1) And InRect(MX, MY, AX1, AY1 + 14, AX2, AY2) Then Begin
   B := CtlHit(MX, MY);
   If (B >= 0) And (CtlKind[B] = 2) And (FirstSel >= 0) Then Begin
    PushUndo;
    If IsVideoTrack(P.Clips[FirstSel].Trk) Then
     CtlApply(CtlId[B], (CtlGet(FirstSel, CtlId[B]) + 4) Mod 5)
    Else CtlApply(CtlId[B], 1 - CtlGet(FirstSel, CtlId[B]));
    NeedA := True;
    NeedProg := True;
    NeedTL := True;
   End;
  End;
 End
 Else If ((MB And 1) <> 0) And (DragMode <> DM_NONE) Then OnDrag
 Else If ((MB And 1) = 0) And (DragMode = DM_NONE) And ((MX <> LastMX) Or (MY <> LastMY)) Then
  UpdateHint;
 If RelL And (DragMode <> DM_NONE) Then OnRelease;
 LastMX := MX;
 LastMY := MY;
End;

{ ====================================================================== }
{  Gestion du clavier                                                    }
{ ====================================================================== }

Procedure MenuKey(C: Integer);
Var
 N, K: Integer;
Begin
 N := Menus[ActiveMenu].N;
 Case C Of
  27: MenuClose;
  13: Begin
   If ActiveItem >= 0 Then MenuExec(ActiveItem) Else MenuClose;
  End;
  328, 336: Begin
   If C = 336 Then K := 1 Else K := -1;
   Repeat
    ActiveItem := ActiveItem + K;
    If ActiveItem < 0 Then ActiveItem := N - 1;
    If ActiveItem >= N Then ActiveItem := 0;
   Until Not Menus[ActiveMenu].It[ActiveItem].Sep;
   HideMouse;
   DrawMenuDrop(ActiveMenu);
   ShowMouse;
  End;
  331: Begin
   ActiveMenu := (ActiveMenu + 7) Mod 8;
   ActiveItem := -1;
   InvAll;
  End;
  333: Begin
   ActiveMenu := (ActiveMenu + 1) Mod 8;
   ActiveItem := -1;
   InvAll;
  End;
 End;
End;

Procedure Shuttle(Dir: Integer);
Var
 Sp: Integer;
Begin
 If Playing And (PlayTarget = 1) And (((PlaySpeed > 0) And (Dir > 0)) Or
    ((PlaySpeed < 0) And (Dir < 0))) Then Begin
  Sp := Abs(PlaySpeed) * 2;
  If Sp > 8 Then Sp := 8;
  PlayF0 := Playhead;
  PlayT0 := Ticks;
  PlaySpeed := Sp * Dir;
 End Else Begin
  StopPlay;
  StartPlay(1, Dir);
 End;
End;

Procedure StepFrames(N: LongInt);
Begin
 StopPlay;
 If FocusSrc And (TabA = 0) And (SrcMed >= 0) Then SetSrcPos(SrcPos + N)
 Else SetPlayhead(Playhead + N);
End;

Procedure HandleKey(C: Integer);
Var
 I: Integer;
Begin
 If MenuActive Then Begin
  MenuKey(C);
  Exit;
 End;
 Case C Of
  27: Begin
   If Playing Then StopPlay
   Else If DragMode <> DM_NONE Then Begin
    If UndoCnt > 0 Then Begin
     If DragMode In [DM_MOVE, DM_TRIML, DM_TRIMR, DM_RIPL, DM_RIPR, DM_SLIDER] Then Begin
      P := UndoStk[UndoCnt - 1]^;
      DropLastUndo;
     End;
    End;
    DragMode := DM_NONE;
    SnapGuide := -1;
    NeedAll := True;
   End Else Begin
    ClearSel;
    NeedTL := True;
    NeedA := True;
   End;
  End;
  32: Begin
   If FocusSrc And (TabA = 0) And (SrcMed >= 0) Then TogglePlay(2) Else TogglePlay(1);
  End;
  Ord('l'), Ord('L'): Shuttle(1);
  Ord('j'), Ord('J'): Shuttle(-1);
  Ord('k'), Ord('K'): StopPlay;
  Ord('v'), Ord('V'): Begin CurTool := TL_SELECT; NeedAll := True; End;
  Ord('a'), Ord('A'): Begin CurTool := TL_TRACKFWD; NeedAll := True; End;
  Ord('b'), Ord('B'): Begin CurTool := TL_RIPPLE; NeedAll := True; End;
  Ord('c'), Ord('C'): Begin CurTool := TL_RAZOR; NeedAll := True; End;
  Ord('h'), Ord('H'): Begin CurTool := TL_HAND; NeedAll := True; End;
  Ord('z'), Ord('Z'): Begin CurTool := TL_ZOOM; NeedAll := True; End;
  Ord('t'), Ord('T'): Begin CurTool := TL_TYPE; NeedAll := True; End;
  Ord('i'), Ord('I'): DoCommand(CM_MARKIN);
  Ord('o'), Ord('O'): DoCommand(CM_MARKOUT);
  Ord('x'), Ord('X'): DoCommand(CM_CLEARIO);
  Ord('m'), Ord('M'): DoCommand(CM_ADDMARK);
  Ord('n'), Ord('N'): DoCommand(CM_NEXTMARK);
  Ord('p'), Ord('P'): DoCommand(CM_PREVMARK);
  Ord('s'), Ord('S'): DoCommand(CM_SNAP);
  Ord(','): DoCommand(CM_INSERT);
  Ord('.'): DoCommand(CM_OVERWRITE);
  Ord('+'), Ord('='): DoCommand(CM_ZOOMIN);
  Ord('-'): DoCommand(CM_ZOOMOUT);
  Ord('\'): DoCommand(CM_ZOOMFIT);
  39: DoCommand(CM_SAFE);
  1: DoCommand(CM_SELALL);
  3: DoCommand(CM_COPY);
  4: DoCommand(CM_SELNONE);
  5: DoCommand(CM_NEWITEM);
  9: DoCommand(CM_IMPORT);
  10: DoCommand(CM_DUP);
  11: DoCommand(CM_SPLIT);
  12: DoCommand(CM_LOOP);
  14: DoCommand(CM_NEW);
  15: DoCommand(CM_OPEN);
  17: DoCommand(CM_QUIT);
  18: DoCommand(CM_SPEED);
  19: DoCommand(CM_SAVE);
  20: DoCommand(CM_ENABLE);
  22: DoCommand(CM_PASTE);
  24: DoCommand(CM_CUT);
  25: DoCommand(CM_REDO);
  26: DoCommand(CM_UNDO);
  8: DoCommand(CM_RIPDEL);
  331: StepFrames(-1);
  333: StepFrames(1);
  371: StepFrames(-P.Fps);
  372: StepFrames(P.Fps);
  328: DoCommand(CM_PREVEDIT);
  336: DoCommand(CM_NEXTEDIT);
  327: Begin
   StopPlay;
   If FocusSrc And (TabA = 0) Then SetSrcPos(0) Else SetPlayhead(0);
  End;
  335: Begin
   StopPlay;
   If FocusSrc And (TabA = 0) Then SetSrcPos(MonLen(False)) Else SetPlayhead(SeqEnd);
  End;
  339: DoCommand(CM_DELETE);
  329: Begin ScrollF := Max(0, ScrollF - VisFrames Div 2); NeedTL := True; End;
  337: Begin ScrollF := ScrollF + VisFrames Div 2; NeedTL := True; End;
  315: DoCommand(CM_HELP);
  316: DoCommand(CM_RENAME);
  321: DoCommand(CM_VTRANS);
  322: DoCommand(CM_ATRANS);
  324: OpenMenu(0);
  289: OpenMenu(0);
  363: DoCommand(CM_QUIT);
  274: OpenMenu(1);
  302: OpenMenu(2);
  287: OpenMenu(3);
  306: OpenMenu(4);
  286: OpenMenu(5);
  273: OpenMenu(6);
  291: OpenMenu(7);
  376..380: SetWorkspace(C - 376);
 End;
End;

Procedure HandleKeys;
Var
 C: Integer;
Begin
 C := ReadKeyCode;
 While C <> 0 Do Begin
  HandleKey(C);
  C := ReadKeyCode;
 End;
End;

{ ====================================================================== }
{  Programme principal                                                   }
{ ====================================================================== }

Procedure InitApp;
Var
 I: Integer;
Begin
 InitTables;
 For I := 0 To MAXIMG - 1 Do ImgPool[I] := Nil;
 For I := 0 To MAXUNDO - 1 Do Begin
  UndoStk[I] := Nil;
  RedoStk[I] := Nil;
 End;
 UndoCnt := 0;
 RedoCnt := 0;
 ClipCnt := 0;
 InitMenus;
 ResetProject;
 CurTool := TL_SELECT;
 TabA := 0;
 TabC := 0;
 WorkSp := 0;
 SnapOn := True;
 WaveOn := True;
 SafeOn := False;
 AudioOn := True;
 LoopOn := False;
 Quality := 2;
 Playing := False;
 PlayTarget := 0;
 PlaySpeed := 1;
 EffSel := -1;
 EffScroll := 0;
 MarkScroll := 0;
 For I := 0 To NGRP - 1 Do GrpOpen[I] := I In [0, 3];
 MenuActive := False;
 DragMode := DM_NONE;
 SnapGuide := -1;
 StatusMsg := '';
 HintStr := '';
 MsgT0 := -100000;
 LevelL := 0; LevelR := 0; PeakL := 0; PeakR := 0;
 LastTone := 0;
 FocusSrc := False;
 OldMB := 0;
 LastClickT := -100000;
 LastMX := -1;
 LastMY := -1;
 PopulateDemo;
 ZoomFit;
 If (ParamCount > 0) And (ExtOf(ParamStr(1)) = '.PRP') Then
  If LoadProject(ParamStr(1)) Then ZoomFit;
End;

BEGIN
 InitializeGraphics;
 If Not MouseDriverFound Then Begin
  CloseGraph;
  WriteLn('Pilote de souris requis.');
  Halt(1);
 End;
 SetTextStyle(DefaultFont, HorizDir, 1);
 Running := True;
 InitApp;
 NeedAll := True;
 ShowMouse;
 DrawAll;
 While Running Do Begin
  HandleMouse;
  HandleKeys;
  PlayTick;
  Refresh;
  If Not Playing Then Delay(10);
 End;
 StopSound;
 FreeHistory;
 CloseGraph;
END.
