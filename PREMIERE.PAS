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

Var
 MaxScreen: Boolean;      { -maxscreen : resolution maximale (Free Pascal seulement) }
 MaxColors: Boolean;      { -maxcolors : nombre maximal de couleurs (Free Pascal seulement) }
 TrueMode: Boolean;       { Mode graphique en couleurs directes (RGB) }
 SW, SH: Integer;         { Dimensions de l'ecran graphique }
 VW, VH: LongInt;         { Resolution de la sequence (exportation) }
 UiRGB: Array[0..15] Of LongInt;

Const
 UiPal: Array[0..15, 0..2] Of Byte = (
  (0,0,0), (0,0,170), (0,170,0), (0,170,170),
  (170,0,0), (170,0,170), (170,85,0), (170,170,170),
  (85,85,85), (85,85,255), (85,255,85), (85,255,255),
  (255,85,85), (255,85,255), (255,255,85), (255,255,255));

{$IFDEF FPC}
{ En couleurs directes, les 16 couleurs de l'interface sont traduites en RGB ;
  les couleurs de l'image sont tracees avec PutRGBPixel / FillRGB (sans traduction). }
Function MapC(C: LongInt): LongInt;
Begin
 If TrueMode And (C >= 0) And (C <= 15) Then MapC := UiRGB[C] Else MapC := C;
End;

Procedure SetColor(C: LongInt);
Begin
 PtcGraph.SetColor(MapC(C));
End;

Procedure SetFillStyle(Pat: Word; C: LongInt);
Begin
 PtcGraph.SetFillStyle(Pat, MapC(C));
End;

Procedure PutPixel(X, Y: Integer; C: LongInt);
Begin
 PtcGraph.PutPixel(X, Y, MapC(C));
End;

Procedure PutRGBPixel(X, Y: Integer; Col: LongInt);
Begin
 PtcGraph.PutPixel(X, Y, Col);
End;

Procedure FillRGB(X1, Y1, X2, Y2: Integer; Col: LongInt);
Begin
 PtcGraph.SetFillStyle(SolidFill, Col);
 PtcGraph.Bar(X1, Y1, X2, Y2);
End;
{$ELSE}
Procedure PutRGBPixel(X, Y: Integer; Col: LongInt);
Begin
End;

Procedure FillRGB(X1, Y1, X2, Y2: Integer; Col: LongInt);
Begin
End;
{$ENDIF}

{ Choix du pilote et du mode graphique.
  -maxscreen : mode le plus grand ; -maxcolors : plus grand nombre de couleurs
  (couleurs directes 24 bits si disponibles). Sans option : VGA 640x480 16 couleurs. }
Procedure SelectScreenDriverMode(WantMaxScreen, WantMaxColors: Boolean;
 Var Driver, Mode: Integer);
{$IFDEF FPC}
Var
 LoMode, HiMode: SmallInt;
 M, Best: PModeInfo;
 BestArea, Area: LongInt;
 Found: Boolean;
{$ENDIF}
Begin
 {$IFDEF FPC}
 Found := False;
 If WantMaxColors Then Begin
  M := QueryAdapterInfo;
  Best := Nil;
  BestArea := 0;
  While M <> Nil Do Begin
   If M^.DirectColor And (M^.MaxColor >= 16777216) Then Begin
    Area := (M^.MaxX + 1) * (M^.MaxY + 1);
    If WantMaxScreen Then Begin
     If Area > BestArea Then Begin
      Best := M;
      BestArea := Area;
     End;
    End Else If (M^.MaxX + 1 >= 640) And (M^.MaxY + 1 >= 480) Then Begin
     If (Best = Nil) Or (Area < BestArea) Then Begin
      Best := M;
      BestArea := Area;
     End;
    End;
   End;
   M := M^.Next;
  End;
  If Best <> Nil Then Begin
   Driver := Best^.DriverNumber;
   Mode := Best^.ModeNumber;
   Found := True;
  End;
 End;
 If Not Found Then Begin
  If WantMaxScreen Then Begin
   Driver := D8bit;
   GetModeRange(Driver, LoMode, HiMode);
   If HiMode >= LoMode Then Mode := HiMode
   Else Begin Driver := Detect; Mode := 0; End;
  End Else Begin
   Driver := VGA;
   Mode := VGAHi;
  End;
 End;
 {$ELSE}
 Driver := Detect;
 Mode := VGAHi;
 {$ENDIF}
End;

{ Les seize couleurs de l'interface restent identiques dans les pilotes indexes ;
  en couleurs directes, elles sont converties en RGB. }
Procedure InitializeScreenPalette;
{$IFDEF FPC}
Var I: Integer;
{$ENDIF}
Begin
 {$IFDEF FPC}
 TrueMode := GetMaxColor > 255;
 For I := 0 To 15 Do
  UiRGB[I] := (LongInt(UiPal[I, 0]) Shl 16) Or (LongInt(UiPal[I, 1]) Shl 8) Or UiPal[I, 2];
 If (Not TrueMode) And (GetMaxColor > 15) Then
  For I := 0 To 15 Do SetRGBPalette(I, UiPal[I, 0], UiPal[I, 1], UiPal[I, 2]);
 {$ENDIF}
End;

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 SelectScreenDriverMode(MaxScreen, MaxColors, Driver, Mode);
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SW:=GetMaxX+1;
  SH:=GetMaxY+1;
  InitializeScreenPalette;
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
 MENUH = 19;          { Hauteur de la barre de menus }

 { Dimensions de l'image des moniteurs (16:9) }
 BW = 284;           { Geometrie de base des generateurs }
 BH = 160;

 MAXMEDIA = 24;       { Nombre maximal de medias dans le projet }
 MAXCLIPS = 150;      { Nombre maximal de clips dans la sequence }
 MAXMARK = 24;        { Nombre maximal de marqueurs }
 MAXUNDO = 10;        { Niveaux d'annulation }
 NSLOT = 5;          { Fichiers cache ouverts simultanement }
 CACHEHDR = 32;       { En-tete d'un fichier cache }
 NTRK = 16;           { 8 pistes video (0..7) + 8 pistes audio (8..15) }
 AUDBASE = 8;         { Premiere piste audio }
 MAXLAY = 16;         { Calques composes simultanement }
 NKP = 10;            { Parametres animables (images-cles) }
 MAXK = 6;            { Images-cles par parametre }

 { Outils de montage }
 TL_SELECT = 0;
 TL_TRACKFWD = 1;
 TL_RIPPLE = 2;
 TL_RAZOR = 3;
 TL_HAND = 4;
 TL_ZOOM = 5;
 TL_TYPE = 6;
 TL_TRACKBACK = 7;
 TL_SLIP = 8;
 TL_SLIDE = 9;
 TL_PEN = 10;

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
 MK_VIDEO = 10;
 MK_TONE = 20;
 MK_MELODY = 21;
 MK_PULSE = 22;
 MK_WAV = 23;

 { Indicateurs de clip }
 CF_MIRH = 1;
 CF_MIRV = 2;
 CF_INV = 4;
 CF_OFF = 8;
 CF_MASKINV = 16;
 CF_TCUT = 32;

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
 DM_SLIP = 15;
 DM_SLIDE = 16;
 DM_PEN = 17;

 NPRE = 10;           { Couleurs predefinies }
 NEFF = 16;           { Effets du catalogue }
 NGRP = 6;            { Groupes d'effets }

Type
 TMedia = Record
  Name: String[20];
  Kind: Integer;
  Dur: LongInt;
  Par: Integer;
  NF: LongInt;
  Fps100: Integer;
  CW, CH: Integer;
  Pair: Integer;
  Txt: String[22];
  Path: String[80];
  Cache: String[12];
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
  Speed2: Integer;                     { vitesse finale (0 = constante) }
  Rot, Pan, Blend: Integer;
  CropL, CropT, CropR, CropB: Integer;
  Blur, Sharp: Integer;
  KeyOn, KeySim, KeySmo: Integer;      { incrustation chroma }
  MaskK, MaskX, MaskY, MaskW, MaskH, MaskF: Integer;
  LutIdx: Integer;
  EqL, EqM, EqH, Comp, Rev, Gate: Integer;
  Link: Integer;
  Kn: Array[0..NKP-1] Of Byte;
  Kt: Array[0..NKP-1, 0..MAXK-1] Of LongInt;
  Kv: Array[0..NKP-1, 0..MAXK-1] Of SmallInt;
  Ki: Array[0..NKP-1, 0..MAXK-1] Of Byte;
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
  NV, NA: Integer;
  InM, OutM: LongInt;
  TrkF: Array[0..NTRK-1] Of Integer;
 End;

 TBigBytes = Array[0..{$IFDEF FPC}400000000{$ELSE}32000{$ENDIF}] Of Byte;
 PBigBytes = ^TBigBytes;
 TBig16 = Array[0..{$IFDEF FPC}200000000{$ELSE}32000{$ENDIF}] Of Word;
 PBig16 = ^TBig16;

 TLayer = Record
  K, Mm, Par: Integer;
  Tm, MDur: LongInt;
  Ok: Boolean;
  CW, CH: LongInt;
  Al: LongInt;
  PX, PY, Sc, Br, Co, Sa, Mos, Rt: LongInt;
  Fl: Integer;
  Fx, Tr, Cp: Boolean;
  Bl, BlurR, Sharp, CrL, CrR, CrT, CrB, Key, KeyT, KeyS: LongInt;
  MaskK, MaskX, MaskY, MaskW, MaskH, MaskF, Lut: LongInt;
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
  It: Array[0..23] Of TMenuItem;
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

 ToolNames: Array[0..10] Of String[40] =
  ('Sélection (V)','Sélection de piste vers l''avant (A)',
   'Modification par ondulation (B)','Lame (C)','Main (H)','Zoom (Z)','Texte (T)',
   'Sélection de piste vers l''arrière (Q)','Glissement interne (Y)','Glissement externe (U)',
   'Plume (P) : images-clés');

 { Identifiants de commandes }
 CM_NEW = 100;  CM_OPEN = 101;  CM_SAVE = 102;  CM_SAVEAS = 103;
 CM_IMPORT = 104; CM_NEWITEM = 105; CM_EXPFRAME = 106; CM_EXPSEQ = 107;
 CM_EXPEDL = 108; CM_QUIT = 109; CM_EXPAVI = 110; CM_EXPWAV = 111;
 CM_UNDO = 200; CM_REDO = 201; CM_CUT = 202; CM_COPY = 203; CM_PASTE = 204;
 CM_DELETE = 205; CM_RIPDEL = 206; CM_DUP = 207; CM_SELALL = 208; CM_SELNONE = 209;
 CM_RENAME = 300; CM_SPEED = 301; CM_ENABLE = 302; CM_RESETFX = 303;
 CM_SPLIT = 304; CM_INSERT = 305; CM_OVERWRITE = 306; CM_VTRANS = 307;
 CM_ATRANS = 308; CM_NOTRANS = 309; CM_EDITTITLE = 310;
 CM_LINK = 312; CM_UNLINK = 313; CM_INTERP0 = 320; CM_LUT = 323;
 CM_ADDV = 412; CM_ADDA = 413; CM_DELV = 414; CM_DELA = 415;
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
 { Geometrie de l'interface (calculee par InitLayout selon la resolution) }
 ZW, ZH: Integer;          { Taille de l'apercu dans les moniteurs }
 AX1, AY1, AX2, AY2: Integer;
 BX1, BY1, BX2, BY2: Integer;
 CX1, CY1, CX2, CY2: Integer;
 TX1, TY1, TX2, TY2: Integer;
 LX1, LY1, LX2, LY2: Integer;
 MX1, MX2: Integer;
 TLX0, TLX1, RULY1, RULY2, TRY0, TRH, HSY1, HSY2: Integer;
 PROWY0, EROWY0, CTLROWS: Integer;

 { Projet et historique }
 P: TProject;
 UndoStk: Array[0..MAXUNDO-1] Of PProject;
 RedoStk: Array[0..MAXUNDO-1] Of PProject;
 UndoCnt, RedoCnt: Integer;
 ClipBuf: Array[0..39] Of TClip;
 ClipCnt: Integer;
 LayBuf: Array[0..MAXLAY-1] Of PBig16;
 LayCap: Array[0..MAXLAY-1] Of LongInt;
 LayKey: Array[0..MAXLAY-1] Of String[12];
 LayCF: Array[0..MAXLAY-1] Of LongInt;
 LayOK: Array[0..MAXLAY-1] Of Boolean;
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
 AuActive: Boolean;
 DefInterp: Integer;
 NextLink: Integer;
 ToolSlot: Array[0..6] Of Integer;
 LutNames: Array[1..4] Of String[12];
 LutCnt: Integer;

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
 Lay: Array[0..MAXLAY-1] Of TLayer;
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

{ Entiers petit-boutiste dans un tableau d'octets }
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

{ Calcule la disposition des panneaux pour l'ecran SW x SH (640x480 = disposition de base) }
Procedure InitLayout;
Var
 AW, AH: Integer;
Begin
 AW := (SW - 6) Div 2 - 33;
 AH := SH - 320;
 If AH < 160 Then AH := 160;
 ZW := AW;
 ZH := Integer((LongInt(ZW) * VH) Div VW);
 If ZH > AH Then Begin
  ZH := AH;
  ZW := Integer((LongInt(ZH) * VW) Div VH);
 End;
 AX1 := 2;
 AX2 := SW Div 2 - 1;
 BX1 := SW Div 2 + 1;
 BX2 := SW - 3;
 AY1 := 40;
 BY1 := 40;
 AY2 := AY1 + 16 + ZH + 34;
 BY2 := AY2;
 CX1 := 2;
 CX2 := 212;
 If SW > 640 Then CX2 := 212 + Min(130, (SW - 640) Div 6);
 CY1 := AY2 + 3;
 CY2 := SH - 19;
 TX1 := CX2 + 2;
 TX2 := TX1 + 21;
 TY1 := CY1;
 TY2 := CY2;
 LX1 := TX2 + 2;
 LX2 := SW - 20;
 LY1 := CY1;
 LY2 := CY2;
 MX1 := SW - 18;
 MX2 := SW - 3;
 TLX0 := LX1 + 62;
 TLX1 := LX2 - 3;
 RULY1 := CY1 + 20;
 RULY2 := RULY1 + 13;
 TRY0 := RULY2 + 2;
 TRH := (CY2 - 3 - 12 - 2 - TRY0) Div Max(1, P.NV + P.NA);
 If TRH < 16 Then TRH := 16;
 If TRH > 90 Then TRH := 90;
 HSY1 := TRY0 + Max(1, P.NV + P.NA) * TRH + 2;
 HSY2 := HSY1 + 12;
 PROWY0 := CY1 + 26;
 EROWY0 := CY1 + 41;
 CTLROWS := (AY2 - 2 - (AY1 + 45)) Div 12;
End;

{ ====================================================================== }
{  Cache des medias conformes (images 284x160 en RGB332, enveloppes audio) }
{ ====================================================================== }

Type
 TEnv = Array[0..59999] Of Byte;
 PEnv = ^TEnv;

Var
 CSF: Array[0..NSLOT-1] Of File;
 CSName: Array[0..NSLOT-1] Of String[12];
 CSNext: Integer;
 EnvName: Array[0..5] Of String[12];
 EnvPtr: Array[0..5] Of PEnv;
 EnvN: Array[0..5] Of LongInt;
 EnvNext: Integer;

Procedure CacheCloseName(Const Name: String);
Var
 I: Integer;
Begin
 For I := 0 To NSLOT - 1 Do
  If CSName[I] = Name Then Begin
   Close(CSF[I]);
   CSName[I] := '';
  End;
 For I := 0 To 5 Do
  If EnvName[I] = Name Then Begin
   If EnvPtr[I] <> Nil Then Dispose(EnvPtr[I]);
   EnvPtr[I] := Nil;
   EnvName[I] := '';
  End;
 For I := 0 To MAXLAY - 1 Do
  If LayKey[I] = Name Then LayKey[I] := '';
End;

Procedure CacheCloseAll;
Var
 I: Integer;
Begin
 For I := 0 To NSLOT - 1 Do
  If CSName[I] <> '' Then Begin
   Close(CSF[I]);
   CSName[I] := '';
  End;
 For I := 0 To 5 Do Begin
  If EnvPtr[I] <> Nil Then Dispose(EnvPtr[I]);
  EnvPtr[I] := Nil;
  EnvName[I] := '';
 End;
 For I := 0 To MAXLAY - 1 Do LayKey[I] := '';
End;

Function CacheSlot(Const Name: String): Integer;
Var
 I: Integer;
 R: Integer;
Begin
 CacheSlot := -1;
 If Name = '' Then Exit;
 For I := 0 To NSLOT - 1 Do
  If CSName[I] = Name Then Begin
   CacheSlot := I;
   Exit;
  End;
 I := CSNext;
 CSNext := (CSNext + 1) Mod NSLOT;
 If CSName[I] <> '' Then Begin
  Close(CSF[I]);
  CSName[I] := '';
 End;
 {$I-}
 Assign(CSF[I], Name);
 FileMode := 0;
 Reset(CSF[I], 1);
 FileMode := 2;
 {$I+}
 R := IOResult;
 If R <> 0 Then Exit;
 CSName[I] := Name;
 CacheSlot := I;
End;

Function CacheFrame(Const Name: String; Idx, FrameBytes: LongInt; Buf: Pointer): Boolean;
Var
 S: Integer;
 N: Word;
 R: Integer;
 Got: LongInt;
Begin
 CacheFrame := False;
 S := CacheSlot(Name);
 If (S < 0) Or (Buf = Nil) Or (FrameBytes < 2) Then Exit;
 Got := 0;
 {$I-}
 Seek(CSF[S], CACHEHDR + Idx * FrameBytes);
 While Got < FrameBytes Do Begin
  BlockRead(CSF[S], PBigBytes(Buf)^[Got], Min(FrameBytes - Got, 60000), N);
  If N = 0 Then Break;
  Got := Got + N;
 End;
 {$I+}
 R := IOResult;
 CacheFrame := (R = 0) And (Got = FrameBytes);
End;

{ Enveloppe audio (L,R par fenetre de 20 ms) chargee en memoire }
Function EnvGet(Const Name: String; Var N: LongInt): PEnv;
Var
 I, S: Integer;
 H: Array[0..31] Of Byte;
 Cnt: LongInt;
 R: Word;
Begin
 EnvGet := Nil;
 N := 0;
 For I := 0 To 5 Do
  If (EnvName[I] = Name) And (EnvPtr[I] <> Nil) Then Begin
   N := EnvN[I];
   EnvGet := EnvPtr[I];
   Exit;
  End;
 S := CacheSlot(Name);
 If S < 0 Then Exit;
 {$I-}
 Seek(CSF[S], 0);
 BlockRead(CSF[S], H, 32, R);
 {$I+}
 If (IOResult <> 0) Or (R < 32) Then Exit;
 Cnt := LE32(H, 12);
 If Cnt < 1 Then Exit;
 If Cnt > 30000 Then Cnt := 30000;
 I := EnvNext;
 EnvNext := (EnvNext + 1) Mod 6;
 If EnvPtr[I] <> Nil Then Dispose(EnvPtr[I]);
 New(EnvPtr[I]);
 FillChar(EnvPtr[I]^, SizeOf(TEnv), 0);
 {$I-}
 Seek(CSF[S], CACHEHDR);
 BlockRead(CSF[S], EnvPtr[I]^, Cnt * 2, R);
 {$I+}
 If IOResult <> 0 Then Begin
  Dispose(EnvPtr[I]);
  EnvPtr[I] := Nil;
  Exit;
 End;
 EnvName[I] := Name;
 EnvN[I] := Cnt;
 N := Cnt;
 EnvGet := EnvPtr[I];
End;

Procedure InitCache;
Var
 I: Integer;
Begin
 For I := 0 To NSLOT - 1 Do CSName[I] := '';
 For I := 0 To 5 Do Begin
  EnvName[I] := '';
  EnvPtr[I] := Nil;
 End;
 For I := 0 To MAXLAY - 1 Do Begin
  LayBuf[I] := Nil;
  LayCap[I] := 0;
  LayKey[I] := '';
  LayOK[I] := False;
  LayCF[I] := -1;
 End;
 CSNext := 0;
 EnvNext := 0;
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
  MK_IMAGE: KindName := 'Image';
  MK_VIDEO: KindName := 'Vidéo';
  MK_WAV: KindName := 'Audio WAV';
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

{ ---------- Images-cles et rampes de vitesse ---------- }

Type
 TSL = {$IFDEF FPC}Int64{$ELSE}LongInt{$ENDIF};

{ Images source ecoulees apres Tl images de sequence (vitesse constante ou rampe lineaire) }
Function SrcOfs(Var C: TClip; Tl: LongInt): LongInt;
Var
 S2: LongInt;
Begin
 S2 := C.Speed2;
 If S2 <= 0 Then S2 := C.Speed;
 If (S2 = C.Speed) Or (C.Dur < 1) Then SrcOfs := (Tl * C.Speed) Div 100
 Else SrcOfs := LongInt((TSL(C.Speed) * Tl + (TSL(S2 - C.Speed) * Tl * Tl) Div (2 * C.Dur)) Div 100);
End;

Function SpeedAt(Var C: TClip; Tl: LongInt): LongInt;
Var
 S2: LongInt;
Begin
 S2 := C.Speed2;
 If S2 <= 0 Then S2 := C.Speed;
 If C.Dur < 1 Then SpeedAt := C.Speed
 Else SpeedAt := C.Speed + ((S2 - C.Speed) * Tl) Div C.Dur;
End;

Function KfHas(Var C: TClip; KP: Integer): Boolean;
Begin
 KfHas := (KP >= 0) And (KP < NKP) And (C.Kn[KP] > 0);
End;

Function KfEval(Var C: TClip; KP: Integer; Tl: LongInt; Base: LongInt): LongInt;
Var
 N, I: Integer;
 T0, T1, V0, V1, U: LongInt;
Begin
 KfEval := Base;
 If (KP < 0) Or (KP >= NKP) Then Exit;
 N := C.Kn[KP];
 If N = 0 Then Exit;
 If Tl <= C.Kt[KP, 0] Then Begin
  KfEval := C.Kv[KP, 0];
  Exit;
 End;
 If Tl >= C.Kt[KP, N - 1] Then Begin
  KfEval := C.Kv[KP, N - 1];
  Exit;
 End;
 I := 0;
 While (I < N - 2) And (Tl >= C.Kt[KP, I + 1]) Do Inc(I);
 T0 := C.Kt[KP, I];
 T1 := C.Kt[KP, I + 1];
 V0 := C.Kv[KP, I];
 V1 := C.Kv[KP, I + 1];
 If T1 <= T0 Then Begin
  KfEval := V1;
  Exit;
 End;
 Case C.Ki[KP, I] Of
  1: KfEval := V0;
  2: Begin
   U := ((Tl - T0) * 256) Div (T1 - T0);
   U := (U * U * (3 * 256 - 2 * U)) Div (256 * 256);
   KfEval := V0 + ((V1 - V0) * U) Div 256;
  End;
 Else KfEval := V0 + ((V1 - V0) * (Tl - T0)) Div (T1 - T0);
 End;
End;

Function KfFind(Var C: TClip; KP: Integer; Tl: LongInt): Integer;
Var
 I: Integer;
Begin
 KfFind := -1;
 For I := 0 To C.Kn[KP] - 1 Do
  If C.Kt[KP, I] = Tl Then KfFind := I;
End;

Procedure KfDel(Var C: TClip; KP, Idx: Integer);
Var
 J: Integer;
Begin
 If (Idx < 0) Or (Idx >= C.Kn[KP]) Then Exit;
 For J := Idx To C.Kn[KP] - 2 Do Begin
  C.Kt[KP, J] := C.Kt[KP, J + 1];
  C.Kv[KP, J] := C.Kv[KP, J + 1];
  C.Ki[KP, J] := C.Ki[KP, J + 1];
 End;
 Dec(C.Kn[KP]);
End;

{ Insere ou met a jour l'image-cle au temps Tl (relatif au debut du clip) }
Procedure KfSet(Var C: TClip; KP: Integer; Tl, V: LongInt; Interp: Integer);
Var
 I, J, Best: Integer;
 D, BD: LongInt;
Begin
 If (KP < 0) Or (KP >= NKP) Then Exit;
 If V > 32000 Then V := 32000;
 If V < -32000 Then V := -32000;
 I := KfFind(C, KP, Tl);
 If I >= 0 Then Begin
  C.Kv[KP, I] := V;
  Exit;
 End;
 If C.Kn[KP] >= MAXK Then Begin
  Best := 0;
  BD := 999999999;
  For J := 0 To C.Kn[KP] - 1 Do Begin
   D := Abs(C.Kt[KP, J] - Tl);
   If D < BD Then Begin
    BD := D;
    Best := J;
   End;
  End;
  KfDel(C, KP, Best);
 End;
 I := C.Kn[KP];
 While (I > 0) And (C.Kt[KP, I - 1] > Tl) Do Begin
  C.Kt[KP, I] := C.Kt[KP, I - 1];
  C.Kv[KP, I] := C.Kv[KP, I - 1];
  C.Ki[KP, I] := C.Ki[KP, I - 1];
  Dec(I);
 End;
 C.Kt[KP, I] := Tl;
 C.Kv[KP, I] := V;
 C.Ki[KP, I] := Interp;
 Inc(C.Kn[KP]);
End;

{ Decale toutes les images-cles de -Dt (le debut du clip avance de Dt images) }
Procedure KfShift(Var C: TClip; Dt: LongInt);
Var
 KP, I, N: Integer;
 V0: LongInt;
 Dropped: Boolean;
Begin
 If Dt = 0 Then Exit;
 For KP := 0 To NKP - 1 Do
  If C.Kn[KP] > 0 Then Begin
   V0 := KfEval(C, KP, Dt, 0);
   Dropped := False;
   For I := C.Kn[KP] - 1 Downto 0 Do
    If C.Kt[KP, I] < Dt Then Begin
     KfDel(C, KP, I);
     Dropped := True;
    End;
   For I := 0 To C.Kn[KP] - 1 Do C.Kt[KP, I] := C.Kt[KP, I] - Dt;
   If Dropped And (KfFind(C, KP, 0) < 0) Then KfSet(C, KP, 0, V0, 0);
   N := C.Kn[KP];
  End;
End;

{ Coupe A en A (debut) et B (fin) a l'instant Tcut : images-cles et rampe de vitesse }
Procedure KfSplit(Var A, B: TClip; Tcut: LongInt);
Var
 KP, I: Integer;
 V: LongInt;
 S: LongInt;
Begin
 S := SpeedAt(A, Tcut);
 If A.Speed2 > 0 Then Begin
  B.Speed := Integer(S);
  B.Speed2 := A.Speed2;
  A.Speed2 := Integer(S);
 End;
 For KP := 0 To NKP - 1 Do
  If A.Kn[KP] > 0 Then Begin
   V := KfEval(A, KP, Tcut, 0);
   KfShift(B, Tcut);
   For I := A.Kn[KP] - 1 Downto 0 Do
    If A.Kt[KP, I] > Tcut Then KfDel(A, KP, I);
   If KfFind(A, KP, Tcut) < 0 Then KfSet(A, KP, Tcut, V, 0);
  End;
End;

Function IsVideoTrack(T: Integer): Boolean;
Begin
 IsVideoTrack := T < AUDBASE;
End;

Function TrackName(T: Integer): String;
Begin
 If T < AUDBASE Then TrackName := 'V' + IStr(T + 1) Else TrackName := 'A' + IStr(T - AUDBASE + 1);
End;

Function TrackRow(T: Integer): Integer;
Begin
 If T < AUDBASE Then TrackRow := P.NV - 1 - T Else TrackRow := P.NV + T - AUDBASE;
End;

Function NRows: Integer;
Begin
 NRows := P.NV + P.NA;
End;

Function RowTrack(R: Integer): Integer;
Begin
 If R < P.NV Then RowTrack := P.NV - 1 - R Else RowTrack := AUDBASE + R - P.NV;
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
 C.KeySim := 40;
 C.KeySmo := 20;
 C.MaskX := 50;
 C.MaskY := 50;
 C.MaskW := 50;
 C.MaskH := 50;
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
     C2.InPt := C2.InPt + SrcOfs(C2, B - S);
     KfSplit(P.Clips[J], C2, B - S);
     P.Clips[J].Dur := A - S;
     P.Clips[J].TOut := 0;
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
     P.Clips[J].InPt := P.Clips[J].InPt + SrcOfs(P.Clips[J], B - S);
     KfShift(P.Clips[J], B - S);
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
 C2.InPt := C2.InPt + SrcOfs(C2, F - S);
 KfSplit(P.Clips[I], C2, F - S);
 P.Clips[I].Dur := F - S;
 P.Clips[I].TOut := 0;
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

Var
 Exp5: Array[0..31] Of Byte;
 Exp6: Array[0..63] Of Byte;

Procedure InitTables;
Var
 I, R, G, B, J, Best: Integer;
 D, BestD, DR, DG, DB: LongInt;
 CR8, CG8, CB8: LongInt;
Begin
 For I := 0 To 255 Do SinTab[I] := Round(Sin(I * 2 * Pi / 256) * 127);
 For I := 0 To 31 Do Exp5[I] := (I * 255 + 15) Div 31;
 For I := 0 To 63 Do Exp6[I] := (I * 255 + 31) Div 63;
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

Procedure SetupLayer(Idx: Integer; M: Integer; T: LongInt);
Var
 N, S: Integer;
 CFr, FB: LongInt;
 Nm: String;
Begin
 FillChar(Lay[Idx], SizeOf(Lay[Idx]), 0);
 With Lay[Idx] Do Begin
  K := P.Media[M].Kind;
  Par := P.Media[M].Par;
  Mm := M;
  Tm := T;
  MDur := P.Media[M].Dur;
  Al := 255;
  Sc := 100;
  Dim := 256;
  TS := 1;
  If K = MK_TITLE Then Begin
   TT := Copy(Cv(P.Media[M].Txt), 1, 22);
   N := Length(TT);
   If N < 1 Then N := 1;
   S := (VW - VW Div 18) Div (N * 6);
   If S > (8 * VW) Div BW Then S := (8 * VW) Div BW;
   If S < 1 Then S := 1;
   TS := S;
   TX0 := (VW - (N * 6 - 1) * S) Div 2;
   TY0 := (VH - 7 * S) Div 2;
  End;
  If K = MK_COUNT Then Begin
   Cd := (MDur - T + P.Fps - 1) Div P.Fps;
   If Cd < 0 Then Cd := 0;
   Cd := Cd Mod 10;
  End;
  If (K = MK_IMAGE) Or (K = MK_VIDEO) Then Begin
   Nm := P.Media[M].Cache;
   CFr := 0;
   If (K = MK_VIDEO) And (P.Media[M].Fps100 > 0) Then CFr := (T * P.Media[M].Fps100) Div (P.Fps * 100);
   If CFr >= P.Media[M].NF Then CFr := P.Media[M].NF - 1;
   If CFr < 0 Then CFr := 0;
   CW := P.Media[M].CW;
   CH := P.Media[M].CH;
   FB := CW * CH * 2;
   Ok := False;
   If (CW > 0) And (CH > 0) Then Begin
    If LayCap[Idx] < FB Then Begin
     If LayBuf[Idx] <> Nil Then FreeMem(LayBuf[Idx], LayCap[Idx]);
     LayBuf[Idx] := Nil;
     GetMem(LayBuf[Idx], FB);
     LayCap[Idx] := FB;
     LayKey[Idx] := '';
    End;
    If (LayKey[Idx] <> Nm) Or (LayCF[Idx] <> CFr) Or (Not LayOK[Idx]) Then Begin
     LayOK[Idx] := CacheFrame(Nm, CFr, FB, LayBuf[Idx]);
     LayKey[Idx] := Nm;
     LayCF[Idx] := CFr;
    End;
    Ok := LayOK[Idx];
   End;
  End;
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
Begin
 CA := 255;
 With Lay[CL] Do Begin
  If (K <> MK_IMAGE) And (K <> MK_VIDEO) And (K <> MK_TITLE) Then Begin
   X := (X * BW) Div VW;
   Y := (Y * BH) Div VH;
  End;
  Case K Of
   MK_BARS: Begin
    If Y < 107 Then Begin
     I := X * 7 Div BW;
     PutRGB(BarR[I], BarG[I], BarB[I]);
    End Else If Y < 120 Then Begin
     I := X * 7 Div BW;
     PutRGB(MidR[I], MidG[I], MidB[I]);
    End Else Begin
     I := X * 6 Div BW;
     Case I Of
      0: PutRGB(0, 33, 76);
      1: PutRGB(255, 255, 255);
      2: PutRGB(50, 0, 106);
      3: PutRGB(19, 19, 19);
      4: PutRGB(0, 0, 0);
     Else PutRGB(38, 38, 38);
     End;
     If (Y >= 128) And (Y < 150) And (Abs(X - ((Tm * 4) Mod BW)) < 3) Then PutRGB(255, 255, 255);
    End;
   End;
   MK_GRAD: Begin
    V := X * 256 Div BW + Tm * 4;
    I := 255 - Y * 90 Div BH;
    PutRGB(Tri(V) * I Div 255, Tri(V + 85) * I Div 255, Tri(V + 170) * I Div 255);
   End;
   MK_PLASMA: Begin
    V := Sn(X * 2 + Tm * 3) + Sn(Y * 3 - Tm * 2) + Sn(X + Y + Tm * 4) +
         Sn((X * X + Y * Y) Div 160 + Tm * 3);
    PutRGB(128 + Sn(V + 0) Div 2 + 63, 128 + Sn(V + 85) Div 2 + 63, 128 + Sn(V + 170) Div 2 + 63);
   End;
   MK_CHECK: Begin
    I := ((X + Tm * 3) Div 20 + (Y + Tm) Div 20) And 1;
    J := Par;
    If (J < 0) Or (J >= NPRE) Then J := 2;
    If I = 0 Then PutRGB(PreR[J], PreG[J], PreB[J])
    Else PutRGB(PreR[J] Div 4, PreG[J] Div 4, PreB[J] Div 4);
   End;
   MK_COUNT: Begin
    DX := X - BW Div 2;
    DY := Y - BH Div 2;
    PutRGB(40, 40, 40);
    If (DX = 0) Or (DY = 0) Then PutRGB(120, 120, 120);
    D := DX * DX + DY * DY;
    If (D >= 4600) And (D <= 5200) Then PutRGB(220, 220, 220);
    I := ((Tm * 256) Div P.Fps) And 255;
    DX := X - (BW Div 2 + Sn(I + 64) * 69 Div 127);
    DY := Y - (BH Div 2 - Sn(I) * 69 Div 127);
    If DX * DX + DY * DY < 30 Then PutRGB(255, 80, 80);
    DX := X - (BW Div 2 - 35);
    DY := Y - (BH Div 2 - 49);
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
    V := Hash3(X, Y, Tm) And 255;
    PutRGB(V, V, V + (V Shr 3));
    If CB > 255 Then CB := 255;
   End;
   MK_WAVES: Begin
    DX := Abs(X - BW Div 2);
    DY := Abs(Y - BH Div 2);
    If DX > DY Then D := DX + DY Div 2 Else D := DY + DX Div 2;
    V := D * 3 - Tm * 6;
    PutRGB(128 + Sn(V), 128 + Sn(V + 85), 128 + Sn(V + 170));
   End;
   MK_IMAGE, MK_VIDEO: Begin
    If Ok Then Begin
     Q := LayBuf[CL]^[((Y * CH) Div VH) * CW + (X * CW) Div VW];
     PutRGB(Exp5[Q Shr 11], Exp6[(Q Shr 5) And 63], Exp5[Q And 31]);
    End Else Begin
     If (((X Shr 4) Xor (Y Shr 4)) And 1) = 0 Then PutRGB(50, 50, 50) Else PutRGB(25, 25, 25);
     If (Abs(X - Y * BW Div BH) < 2) Or (Abs(BW - 1 - X - Y * BW Div BH) < 2) Then PutRGB(200, 40, 40);
    End;
   End;
  Else PutRGB(0, 0, 0);
  End;
 End;
End;

{ Construit le calque d'un clip a l'image Tm de la sequence }
Procedure BuildClipLayer(I: Integer; Tf: LongInt; Under: Boolean);
Var
 SF, Off, Rem, Prog, Tl: LongInt;
 Kind: Integer;
Begin
 If NLay >= MAXLAY Then Exit;
 SF := P.Clips[I].InPt + SrcOfs(P.Clips[I], Tf - P.Clips[I].Start);
 SetupLayer(NLay, P.Clips[I].Med, SF);
 With Lay[NLay] Do Begin
  Tl := Tf - P.Clips[I].Start;
  Al := (Clamp(KfEval(P.Clips[I], 4, Tl, P.Clips[I].Opac), 0, 100) * 255) Div 100;
  PX := (KfEval(P.Clips[I], 0, Tl, P.Clips[I].PosX) * VW) Div BW;
  PY := (KfEval(P.Clips[I], 1, Tl, P.Clips[I].PosY) * VH) Div BH;
  Sc := KfEval(P.Clips[I], 2, Tl, P.Clips[I].Scale);
  If Sc < 1 Then Sc := 1;
  Rt := KfEval(P.Clips[I], 3, Tl, P.Clips[I].Rot);
  Br := KfEval(P.Clips[I], 5, Tl, P.Clips[I].Br);
  Co := KfEval(P.Clips[I], 6, Tl, P.Clips[I].Co);
  Sa := KfEval(P.Clips[I], 7, Tl, P.Clips[I].Sa);
  Mos := (P.Clips[I].Mos * VW) Div BW;
  If (Mos < 2) And (P.Clips[I].Mos > 1) Then Mos := 2;
  Fl := P.Clips[I].Fl;
  Bl := P.Clips[I].Blend;
  BlurR := (P.Clips[I].Blur * VW) Div (BW * 8);
  If (BlurR < 1) And (P.Clips[I].Blur > 0) Then BlurR := 1;
  Sharp := P.Clips[I].Sharp;
  Cp := (P.Clips[I].CropL + P.Clips[I].CropT + P.Clips[I].CropR + P.Clips[I].CropB) > 0;
  CrL := (P.Clips[I].CropL * VW) Div 100;
  CrR := VW - (P.Clips[I].CropR * VW) Div 100;
  CrT := (P.Clips[I].CropT * VH) Div 100;
  CrB := VH - (P.Clips[I].CropB * VH) Div 100;
  Key := P.Clips[I].KeyOn;
  KeyT := P.Clips[I].KeySim * 3;
  KeyS := P.Clips[I].KeySmo * 3;
  MaskK := P.Clips[I].MaskK;
  MaskX := P.Clips[I].MaskX;
  MaskY := P.Clips[I].MaskY;
  MaskW := P.Clips[I].MaskW;
  MaskH := P.Clips[I].MaskH;
  MaskF := (P.Clips[I].MaskF * VW) Div BW;
  Lut := P.Clips[I].LutIdx;
  Tr := (Sc <> 100) Or (PX <> 0) Or (PY <> 0) Or (Rt <> 0);
  Fx := (Br <> 0) Or (Co <> 0) Or (Sa <> 100) Or ((Fl And CF_INV) <> 0);
  Off := Tf - P.Clips[I].Start;
  Rem := P.Clips[I].Start + P.Clips[I].Dur - 1 - Tf;
  Kind := 0;
  Prog := 256;
  If Under Then Begin
   Dim := 256;
  End Else If (P.Clips[I].TIn > 0) And (P.Clips[I].TInL > 0) And (Off < P.Clips[I].TInL) Then Begin
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
   4: Begin WM := 2; WP := (Prog * (VW Div 2 + VH Div 4 + 8)) Div 256; End;
  End;
 End;
 Inc(NLay);
End;

Procedure BuildLayers(Tm: LongInt);
Var
 T, I, J: Integer;
Begin
 NLay := 0;
 For T := 0 To P.NV - 1 Do
  If (P.TrkF[T] And TF_HIDE) = 0 Then Begin
   I := FindClip(T, Tm);
   If (I >= 0) And ((P.Clips[I].Fl And CF_OFF) = 0) Then Begin
    If (P.Clips[I].TIn > 0) And ((P.Clips[I].Fl And CF_TCUT) <> 0) And
       (Tm - P.Clips[I].Start < P.Clips[I].TInL) Then Begin
     J := FindClip(T, P.Clips[I].Start - 1);
     If (J >= 0) And ((P.Clips[J].Fl And CF_OFF) = 0) Then BuildClipLayer(J, Tm, True);
    End;
    BuildClipLayer(I, Tm, False);
   End;
  End;
End;

Procedure BuildSource;
Begin
 NLay := 0;
 If (SrcMed >= 0) And (SrcMed < P.NM) Then
  If Not MediaAudio(SrcMed) Then Begin
   SetupLayer(0, SrcMed, SrcPos);
   NLay := 1;
  End;
End;

{ ---------- LUT 3D (.CUBE) ---------- }

Var
 LutSz: Array[1..4] Of Integer;
 LutData: Array[1..4] Of PBig16;
 LutPath: Array[1..4] Of String[80];

Function ISqrt(N: LongInt): LongInt;
Var
 R, Q: LongInt;
Begin
 If N <= 0 Then Begin
  ISqrt := 0;
  Exit;
 End;
 R := N;
 Q := (R + 1) Div 2;
 While Q < R Do Begin
  R := Q;
  Q := (R + N Div R) Div 2;
 End;
 ISqrt := R;
End;

{$IFDEF FPC}
{ Charge un fichier .CUBE (LUT_3D_SIZE N, lignes "r g b" avec r variant le plus vite) }
Function LutLoad(Const FN: String): Integer;
Var
 F: Text;
 L, T: String;
 Slot, N, K, Cnt, Code, J: Integer;
 V: Double;
 Nm: String;
 D: PBig16;
Begin
 LutLoad := 0;
 If LutCnt >= 4 Then Exit;
 {$I-}
 Assign(F, FN);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 N := 0;
 D := Nil;
 Cnt := 0;
 While Not Eof(F) Do Begin
  ReadLn(F, L);
  While (Length(L) > 0) And ((L[1] = ' ') Or (L[1] = #9)) Do Delete(L, 1, 1);
  If (L = '') Or (L[1] = '#') Then Continue;
  If UpStr(Copy(L, 1, 11)) = 'LUT_3D_SIZE' Then Begin
   T := Copy(L, 12, 20);
   N := Integer(StrVal(T, 0));
   If (N < 2) Or (N > 33) Then Begin
    Close(F);
    Exit;
   End;
   GetMem(D, LongInt(N) * N * N * 3 * 2);
   Continue;
  End;
  If ((L[1] >= '0') And (L[1] <= '9')) Or (L[1] = '.') Or (L[1] = '-') Then Begin
   If (D = Nil) Or (Cnt >= N * N * N) Then Continue;
   For J := 0 To 2 Do Begin
    K := Pos(' ', L);
    If K = 0 Then Begin
     T := L;
     L := '';
    End Else Begin
     T := Copy(L, 1, K - 1);
     Delete(L, 1, K);
     While (Length(L) > 0) And (L[1] = ' ') Do Delete(L, 1, 1);
    End;
    Val(T, V, Code);
    If Code <> 0 Then V := 0;
    If V < 0 Then V := 0;
    If V > 1 Then V := 1;
    D^[Cnt * 3 + J] := Round(V * 65535);
   End;
   Inc(Cnt);
  End;
 End;
 Close(F);
 If (D = Nil) Or (Cnt < N * N * N) Then Begin
  If D <> Nil Then FreeMem(D, LongInt(N) * N * N * 3 * 2);
  Exit;
 End;
 Inc(LutCnt);
 Slot := LutCnt;
 LutSz[Slot] := N;
 LutData[Slot] := D;
 LutPath[Slot] := Copy(FN, 1, 80);
 Nm := FN;
 K := Length(Nm);
 While (K > 0) And (Nm[K] <> '\') And (Nm[K] <> '/') Do Dec(K);
 Delete(Nm, 1, K);
 LutNames[Slot] := Copy(UpStr(Nm), 1, 12);
 LutLoad := Slot;
End;
{$ELSE}
Function LutLoad(Const FN: String): Integer;
Begin
 LutLoad := 0;
End;
{$ENDIF}

Procedure LutApply(Idx: Integer; Var R, G, B: LongInt);
Var
 N, R0, G0, B0, R1, G1, B1, FR, FG, FB, Ch, A, Bb: LongInt;
 D: PBig16;
 C: Array[0..1, 0..1, 0..1] Of LongInt;
 X0, X1, Y0, Y1: LongInt;
Begin
 If (Idx < 1) Or (Idx > LutCnt) Or (LutData[Idx] = Nil) Then Exit;
 N := LutSz[Idx];
 D := LutData[Idx];
 FR := (R * (N - 1) * 256) Div 255;
 FG := (G * (N - 1) * 256) Div 255;
 FB := (B * (N - 1) * 256) Div 255;
 R0 := FR Shr 8; FR := FR And 255; R1 := Min(R0 + 1, N - 1);
 G0 := FG Shr 8; FG := FG And 255; G1 := Min(G0 + 1, N - 1);
 B0 := FB Shr 8; FB := FB And 255; B1 := Min(B0 + 1, N - 1);
 For Ch := 0 To 2 Do Begin
  C[0, 0, 0] := D^[((B0 * N + G0) * N + R0) * 3 + Ch];
  C[1, 0, 0] := D^[((B0 * N + G0) * N + R1) * 3 + Ch];
  C[0, 1, 0] := D^[((B0 * N + G1) * N + R0) * 3 + Ch];
  C[1, 1, 0] := D^[((B0 * N + G1) * N + R1) * 3 + Ch];
  C[0, 0, 1] := D^[((B1 * N + G0) * N + R0) * 3 + Ch];
  C[1, 0, 1] := D^[((B1 * N + G0) * N + R1) * 3 + Ch];
  C[0, 1, 1] := D^[((B1 * N + G1) * N + R0) * 3 + Ch];
  C[1, 1, 1] := D^[((B1 * N + G1) * N + R1) * 3 + Ch];
  X0 := C[0, 0, 0] + ((C[1, 0, 0] - C[0, 0, 0]) * FR) Div 256;
  X1 := C[0, 1, 0] + ((C[1, 1, 0] - C[0, 1, 0]) * FR) Div 256;
  Y0 := C[0, 0, 1] + ((C[1, 0, 1] - C[0, 0, 1]) * FR) Div 256;
  Y1 := C[0, 1, 1] + ((C[1, 1, 1] - C[0, 1, 1]) * FR) Div 256;
  A := X0 + ((X1 - X0) * FG) Div 256;
  Bb := Y0 + ((Y1 - Y0) * FG) Div 256;
  A := A + ((Bb - A) * FB) Div 256;
  A := (A * 255 + 32767) Div 65535;
  If A < 0 Then A := 0;
  If A > 255 Then A := 255;
  Case Ch Of
   0: R := A;
   1: G := A;
  Else B := A;
  End;
 End;
End;

{ ---------- Composition des calques ---------- }

{ Echantillon brut du calque I au pixel (X,Y) de la sequence : geometrie, generateur,
  couleur, LUT, incrustation. Retourne False si le pixel est transparent. }
Function RawSample(I: Integer; X, Y: LongInt): Boolean;
Var
 SX, SY, G, M, RX, RY, RA, RC, RS, RT2, PCb, PCr, KCb, KCr, Dst, T, Sm: LongInt;
Begin
 RawSample := False;
 SX := X;
 SY := Y;
 If (Lay[I].Fl And CF_MIRH) <> 0 Then SX := VW - 1 - SX;
 If (Lay[I].Fl And CF_MIRV) <> 0 Then SY := VH - 1 - SY;
 If Lay[I].Tr Then Begin
  RX := SX - VW Div 2 - Lay[I].PX;
  RY := SY - VH Div 2 - Lay[I].PY;
  If Lay[I].Rt <> 0 Then Begin
   RA := ((Lay[I].Rt * 256) Div 360) And 255;
   RC := Sn(RA + 64);
   RS := Sn(RA);
   RT2 := (RC * RX + RS * RY) Div 127;
   RY := (RC * RY - RS * RX) Div 127;
   RX := RT2;
  End;
  SX := (RX * 100) Div Lay[I].Sc + VW Div 2;
  SY := (RY * 100) Div Lay[I].Sc + VH Div 2;
  If (SX < 0) Or (SX >= VW) Or (SY < 0) Or (SY >= VH) Then Exit;
 End;
 If Lay[I].Cp Then
  If (SX < Lay[I].CrL) Or (SX >= Lay[I].CrR) Or (SY < Lay[I].CrT) Or (SY >= Lay[I].CrB) Then Exit;
 M := Lay[I].Mos;
 If M > 1 Then Begin
  SX := Min(VW - 1, (SX Div M) * M + M Div 2);
  SY := Min(VH - 1, (SY Div M) * M + M Div 2);
 End;
 CL := I;
 Gen(SX, SY);
 If CA <= 0 Then Exit;
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
 If Lay[I].Lut > 0 Then LutApply(Lay[I].Lut, CR, CG, CB);
 If Lay[I].Key > 0 Then Begin
  { Distance de chrominance a la couleur-cle (Cb/Cr, echelle 0..255) }
  PCb := (-43 * CR - 85 * CG + 128 * CB) Div 256;
  PCr := (128 * CR - 107 * CG - 21 * CB) Div 256;
  Case Lay[I].Key Of
   1: Begin KCb := -43 * 0 - 85 * 255 Div 256; KCr := (-107 * 255) Div 256; End;
   2: Begin KCb := 127; KCr := -21 * 255 Div 256 + 0; End;
  Else Begin KCb := (-43 * 255) Div 256; KCr := 127; End;
  End;
  Dst := Abs(PCb - KCb) + Abs(PCr - KCr);
  T := Lay[I].KeyT;
  Sm := Lay[I].KeyS + 1;
  If Dst <= T Then CA := 0
  Else If Dst < T + Sm Then CA := (CA * (Dst - T)) Div Sm;
  If (CA > 0) And (Lay[I].Key = 1) And (CG > Max(CR, CB)) Then CG := Max(CR, CB);
  If (CA > 0) And (Lay[I].Key = 2) And (CB > Max(CR, CG)) Then CB := Max(CR, CG);
  If (CA > 0) And (Lay[I].Key = 3) And (CR > Max(CG, CB)) Then CR := Max(CG, CB);
  If CA <= 0 Then Exit;
 End;
 RawSample := True;
End;

{ Echantillon final : flou / nettete, masque, volet. }
Function LayerSample(I: Integer; X, Y: LongInt): Boolean;
Var
 DX, DY, D, SA, SR, SG, SB, SW0, Dd, Rd, W, CR0, CG0, CB0, CA0, MX0, MY0, HW, HH, Q, A2: LongInt;
 Ok: Boolean;
 TX, TY: Integer;
Begin
 LayerSample := False;
 If Lay[I].WM = 1 Then Begin
  If X >= Lay[I].WP Then Exit;
 End Else If Lay[I].WM = 2 Then Begin
  DX := Abs(X - VW Div 2);
  DY := Abs(Y - VH Div 2);
  If DX > DY Then D := DX + DY Div 2 Else D := DY + DX Div 2;
  If D >= Lay[I].WP Then Exit;
 End;
 If Lay[I].BlurR > 0 Then Begin
  Rd := Lay[I].BlurR;
  SA := 0; SR := 0; SG := 0; SB := 0;
  For TY := -1 To 1 Do
   For TX := -1 To 1 Do
    If RawSample(I, X + TX * Rd, Y + TY * Rd) Then Begin
     SA := SA + CA;
     SR := SR + CR * CA;
     SG := SG + CG * CA;
     SB := SB + CB * CA;
    End;
  If SA <= 0 Then Exit;
  CR := SR Div SA;
  CG := SG Div SA;
  CB := SB Div SA;
  CA := SA Div 9;
 End Else Begin
  If Not RawSample(I, X, Y) Then Exit;
  If Lay[I].Sharp > 0 Then Begin
   CR0 := CR; CG0 := CG; CB0 := CB; CA0 := CA;
   Dd := Max(1, VW Div BW);
   SR := 0; SG := 0; SB := 0; SW0 := 0;
   If RawSample(I, X - Dd, Y) Then Begin SR := SR + CR; SG := SG + CG; SB := SB + CB; Inc(SW0); End;
   If RawSample(I, X + Dd, Y) Then Begin SR := SR + CR; SG := SG + CG; SB := SB + CB; Inc(SW0); End;
   If RawSample(I, X, Y - Dd) Then Begin SR := SR + CR; SG := SG + CG; SB := SB + CB; Inc(SW0); End;
   If RawSample(I, X, Y + Dd) Then Begin SR := SR + CR; SG := SG + CG; SB := SB + CB; Inc(SW0); End;
   If SW0 > 0 Then Begin
    CR := CR0 + ((CR0 - SR Div SW0) * Lay[I].Sharp) Div 25;
    CG := CG0 + ((CG0 - SG Div SW0) * Lay[I].Sharp) Div 25;
    CB := CB0 + ((CB0 - SB Div SW0) * Lay[I].Sharp) Div 25;
    If CR < 0 Then CR := 0 Else If CR > 255 Then CR := 255;
    If CG < 0 Then CG := 0 Else If CG > 255 Then CG := 255;
    If CB < 0 Then CB := 0 Else If CB > 255 Then CB := 255;
   End Else Begin
    CR := CR0; CG := CG0; CB := CB0;
   End;
   CA := CA0;
  End;
 End;
 { Masque }
 If Lay[I].MaskK > 0 Then Begin
  MX0 := (Lay[I].MaskX * VW) Div 100;
  MY0 := (Lay[I].MaskY * VH) Div 100;
  HW := Max(1, (Lay[I].MaskW * VW) Div 200);
  HH := Max(1, (Lay[I].MaskH * VH) Div 200);
  DX := X - MX0;
  DY := Y - MY0;
  If Lay[I].MaskK = 1 Then D := Min(HW - Abs(DX), HH - Abs(DY))
  Else Begin
   Q := ISqrt(((DX * HH) * (DX * HH) + (DY * HW) * (DY * HW)) Div Max(1, HW * HH Div 1024)) ;
   { Q = rayon normalise * 32 * (HW*HH)^0.5 / 1024 ... approximation : distance au bord }
   Rd := ISqrt(DX * DX * 1024 Div Max(1, HW * HW) + DY * DY * 1024 Div Max(1, HH * HH));
   D := ((32 - Rd) * Min(HW, HH)) Div 32;
  End;
  If Lay[I].MaskF > 0 Then Begin
   If D <= 0 Then A2 := 0
   Else If D >= Lay[I].MaskF Then A2 := 255
   Else A2 := (D * 255) Div Lay[I].MaskF;
  End Else If D >= 0 Then A2 := 255 Else A2 := 0;
  If (Lay[I].Fl And CF_MASKINV) <> 0 Then A2 := 255 - A2;
  CA := (CA * A2) Div 255;
  If CA <= 0 Then Exit;
 End;
 LayerSample := True;
End;

Procedure Compose(X, Y: LongInt);
Var
 I: Integer;
 A, BR2, BG2, BB2: LongInt;
Begin
 AR := 0;
 AG := 0;
 AB := 0;
 For I := 0 To NLay - 1 Do Begin
  CL := I;
  If LayerSample(I, X, Y) Then Begin
   A := (CA * Lay[I].Al) Div 255;
   If A > 0 Then Begin
    BR2 := CR;
    BG2 := CG;
    BB2 := CB;
    Case Lay[I].Bl Of
     1: Begin BR2 := Min(255, AR + CR); BG2 := Min(255, AG + CG); BB2 := Min(255, AB + CB); End;
     2: Begin BR2 := (AR * CR) Div 255; BG2 := (AG * CG) Div 255; BB2 := (AB * CB) Div 255; End;
     3: Begin
      BR2 := 255 - ((255 - AR) * (255 - CR)) Div 255;
      BG2 := 255 - ((255 - AG) * (255 - CG)) Div 255;
      BB2 := 255 - ((255 - AB) * (255 - CB)) Div 255;
     End;
     4: Begin
      If AR < 128 Then BR2 := (2 * AR * CR) Div 255 Else BR2 := 255 - (2 * (255 - AR) * (255 - CR)) Div 255;
      If AG < 128 Then BG2 := (2 * AG * CG) Div 255 Else BG2 := 255 - (2 * (255 - AG) * (255 - CG)) Div 255;
      If AB < 128 Then BB2 := (2 * AB * CB) Div 255 Else BB2 := 255 - (2 * (255 - AB) * (255 - CB)) Div 255;
     End;
     5: Begin BR2 := Abs(AR - CR); BG2 := Abs(AG - CG); BB2 := Abs(AB - CB); End;
     6: Begin BR2 := Min(AR, CR); BG2 := Min(AG, CG); BB2 := Min(AB, CB); End;
     7: Begin BR2 := Max(AR, CR); BG2 := Max(AG, CG); BB2 := Max(AB, CB); End;
    End;
    AR := AR + ((BR2 - AR) * A) Div 255;
    AG := AG + ((BG2 - AG) * A) Div 255;
    AB := AB + ((BB2 - AB) * A) Div 255;
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
 PX, PY, X, Y, BS: Integer;
 C: Integer;
 Col: LongInt;
Begin
 BS := Q;
 PY := 0;
 While PY < ZH Do Begin
  Y := Integer((LongInt(PY) * VH) Div ZH);
  PX := 0;
  While PX < ZW Do Begin
   X := Integer((LongInt(PX) * VW) Div ZW);
   If NLay = 0 Then Begin
    AR := 0;
    AG := 0;
    AB := 0;
   End Else Compose(X, Y);
   If TrueMode Then Begin
    Col := (AR Shl 16) Or (AG Shl 8) Or AB;
    If BS <= 1 Then PutRGBPixel(OX + PX, OY + PY, Col)
    Else FillRGB(OX + PX, OY + PY, Min(OX + PX + BS - 1, OX + ZW - 1), Min(OY + PY + BS - 1, OY + ZH - 1), Col);
   End Else Begin
    C := QuantColor(PX, PY);
    If BS <= 1 Then PutPixel(OX + PX, OY + PY, C)
    Else Begin
     SetFillStyle(SolidFill, C);
     Bar(OX + PX, OY + PY, Min(OX + PX + BS - 1, OX + ZW - 1), Min(OY + PY + BS - 1, OY + ZH - 1));
    End;
   End;
   Inc(PX, BS);
  End;
  Inc(PY, BS);
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
 Amp, AL, AR2, Pr, Q, Beat, AmpR, EN: LongInt;
 M: Integer;
 Env: PEnv;
 Got: Boolean;
Begin
 AL := 0;
 AR2 := 0;
 AudioFreq := 0;
 Got := False;
 For T := AUDBASE To AUDBASE + P.NA - 1 Do
  If (P.TrkF[T] And TF_HIDE) = 0 Then Begin
   I := FindClip(T, Tm);
   If (I >= 0) And ((P.Clips[I].Fl And CF_OFF) = 0) And (Not P.Clips[I].Mute) Then Begin
    M := P.Clips[I].Med;
    SF := P.Clips[I].InPt + SrcOfs(P.Clips[I], Tm - P.Clips[I].Start);
    Beat := P.Fps Div 3;
    If Beat < 1 Then Beat := 1;
    AmpR := -1;
    Case P.Media[M].Kind Of
     MK_TONE: Begin
      Amp := 70 + Sn(SF * 5) Div 12;
      Q := P.Media[M].Par;
     End;
     MK_WAV: Begin
      Env := EnvGet(P.Media[M].Cache, EN);
      Pr := (SF * 50) Div P.Fps;
      Amp := 0;
      If (Env <> Nil) And (Pr < EN) Then Begin
       Amp := (Env^[Pr * 2] * 100) Div 255;
       AmpR := (Env^[Pr * 2 + 1] * 100) Div 255;
      End;
      Q := 0;
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
     Begin
      Amp := (Amp * Off) Div P.Clips[I].TInL;
      If AmpR >= 0 Then AmpR := (AmpR * Off) Div P.Clips[I].TInL;
     End
    Else If (P.Clips[I].TOut > 0) And (P.Clips[I].TOutL > 0) And (Rem < P.Clips[I].TOutL) Then
     Begin
      Amp := (Amp * Rem) Div P.Clips[I].TOutL;
      If AmpR >= 0 Then AmpR := (AmpR * Rem) Div P.Clips[I].TOutL;
     End;
    Amp := (Amp * (100 + Integer(KfEval(P.Clips[I], 8, Off, P.Clips[I].Vol)) * 3)) Div 100;
    If AmpR >= 0 Then AmpR := Clamp((AmpR * (100 + Integer(KfEval(P.Clips[I], 8, Off, P.Clips[I].Vol)) * 3)) Div 100, 0, 100);
    If Amp < 0 Then Amp := 0;
    If Amp > 100 Then Amp := 100;
    AL := Min(100, AL + Amp);
    If AmpR >= 0 Then AR2 := Min(100, AR2 + AmpR)
    Else AR2 := Min(100, AR2 + (Amp * (90 + (Hash3(Tm, T, 1) And 15))) Div 100);
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
 If AuActive Then Begin
  StopSound;
  Exit;
 End;
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
  TL_TRACKBACK: Begin
   IcoTri(X + 14, Y + 5, X + 14, Y + 17, X + 5, Y + 11, C);
   FillR(X + 17, Y + 5, X + 18, Y + 17, C);
   Line(X + 14, Y + 11, X + 17, Y + 11);
  End;
  TL_SLIP: Begin
   Rectangle(X + 3, Y + 6, X + 18, Y + 16);
   Line(X + 7, Y + 3, X + 7, Y + 19);
   Line(X + 14, Y + 3, X + 14, Y + 19);
   Line(X + 8, Y + 11, X + 13, Y + 11);
  End;
  TL_SLIDE: Begin
   Rectangle(X + 7, Y + 6, X + 14, Y + 16);
   IcoTri(X + 2, Y + 11, X + 6, Y + 7, X + 6, Y + 15, C);
   IcoTri(X + 19, Y + 11, X + 15, Y + 7, X + 15, Y + 15, C);
  End;
  TL_PEN: Begin
   Line(X + 4, Y + 17, X + 15, Y + 6);
   Line(X + 5, Y + 17, X + 16, Y + 6);
   Line(X + 14, Y + 5, X + 18, Y + 9);
   Line(X + 4, Y + 17, X + 3, Y + 19);
   Rectangle(X + 16, Y + 14, X + 19, Y + 17);
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
  CM_LINK, CM_UNLINK: CmdEnabled := SelCount > 0;
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
  CM_INTERP0..CM_INTERP0 + 2: CmdChecked := DefInterp = Id - CM_INTERP0;
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
 MenuAdd(0, 'Exporter la vidéo...', '', CM_EXPAVI);
 MenuAdd(0, 'Exporter l''audio (WAV)...', '', CM_EXPWAV);
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
 MenuSep(2);
 MenuAdd(2, 'Lier vidéo/audio', '', CM_LINK);
 MenuAdd(2, 'Dissocier', '', CM_UNLINK);
 MenuAdd(2, 'Clés : interpolation linéaire', '', CM_INTERP0);
 MenuAdd(2, 'Clés : maintien', '', CM_INTERP0 + 1);
 MenuAdd(2, 'Clés : lissée', '', CM_INTERP0 + 2);
 MenuAdd(2, 'Importer une LUT (.CUBE)...', '', CM_LUT);

 MenuBegin(3, 'Séquence');
 MenuAdd(3, 'Paramètres de séquence...', '', CM_SEQSET);
 MenuSep(3);
 MenuAdd(3, 'Marquer l''entrée', 'I', CM_MARKIN);
 MenuAdd(3, 'Marquer la sortie', 'O', CM_MARKOUT);
 MenuAdd(3, 'Effacer entrée/sortie', 'X', CM_CLEARIO);
 MenuSep(3);
 MenuAdd(3, 'Supprimer l''espace vide', '', CM_REMGAP);
 MenuAdd(3, 'Ajouter une piste vidéo', '', CM_ADDV);
 MenuAdd(3, 'Ajouter une piste audio', '', CM_ADDA);
 MenuAdd(3, 'Supprimer la dernière piste V', '', CM_DELV);
 MenuAdd(3, 'Supprimer la dernière piste A', '', CM_DELA);
 MenuAdd(3, 'Aller au début', 'Début', CM_GOSTART);
 MenuAdd(3, 'Aller à la fin', 'Fin', CM_GOEND);
 MenuAdd(3, 'Coupe suivante', 'Bas', CM_NEXTEDIT);
 MenuAdd(3, 'Coupe précédente', 'Haut', CM_PREVEDIT);

 MenuBegin(4, 'Marqueur');
 MenuAdd(4, 'Ajouter un marqueur', 'M', CM_ADDMARK);
 MenuAdd(4, 'Marqueur suivant', 'N', CM_NEXTMARK);
 MenuAdd(4, 'Marqueur précédent', '[', CM_PREVMARK);
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
 MonVX := MonX1(IsProg) + (MonX2(IsProg) - MonX1(IsProg) + 1 - ZW) Div 2;
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
 MonBtnY := MonVY + ZH + 13;
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
 MonScrubHit := InRect(X, Y, MonVX(IsProg) - 4, MonVY + ZH + 2, MonVX(IsProg) + ZW + 4,
                       MonVY + ZH + 11);
End;

Function MonScrubFrame(IsProg: Boolean; X: LongInt): LongInt;
Var
 F: LongInt;
Begin
 F := ((X - MonVX(IsProg)) * MonLen(IsProg)) Div (ZW);
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
 Frame(VX - 1, VY - 1, VX + ZW, VY + ZH, DarkGray);
 If (Not IsProg) And (NLay = 0) Then Begin
  If (SrcMed >= 0) And (SrcMed < P.NM) Then
   TxtC(VX + ZW Div 2, VY + ZH Div 2 - 4, '(média audio)', LightGray)
  Else TxtC(VX + ZW Div 2, VY + ZH Div 2 - 4, 'Aucun clip source', DarkGray);
 End;
 If SafeOn Then Begin
  SetColor(LightGreen);
  SetLineStyle(DottedLn, 0, 1);
  Rectangle(VX + ZW Div 20, VY + ZH Div 20, VX + ZW - ZW Div 20, VY + ZH - ZH Div 20);
  Rectangle(VX + ZW Div 10, VY + ZH Div 10, VX + ZW - ZW Div 10, VY + ZH - ZH Div 10);
  SetLineStyle(SolidLn, 0, 1);
 End;
 { Barre de defilement }
 Len := MonLen(IsProg);
 Pos := MonPos(IsProg);
 BY := VY + ZH + 6;
 FillR(VX, BY - 2, VX + ZW - 1, BY + 3, Black);
 HLine(VX, VX + ZW - 1, BY, DarkGray);
 If IsProg Then Begin
  If P.InM >= 0 Then FillR(VX + Integer((P.InM * ZW) Div Len), BY - 2, VX + ZW - 1, BY + 3, 8);
 End;
 If IsProg Then Begin
  If (P.InM >= 0) Or (P.OutM >= 0) Then Begin
   FillR(VX, BY - 2, VX + ZW - 1, BY + 3, Black);
   HLine(VX, VX + ZW - 1, BY, DarkGray);
   If P.InM >= 0 Then I := Integer((P.InM * ZW) Div Len) Else I := 0;
   If P.OutM >= 0 Then PX := Integer((P.OutM * ZW) Div Len) Else PX := ZW - 1;
   If PX > ZW - 1 Then PX := ZW - 1;
   If PX >= I Then FillR(VX + I, BY - 2, VX + PX, BY + 3, Blue);
  End;
  For I := 0 To P.NK - 1 Do
   If P.Marks[I].Pos <= Len Then
    VLine(VX + Integer((P.Marks[I].Pos * ZW) Div Len), BY - 3, BY + 4, LightGreen);
 End Else Begin
  If (SrcIn >= 0) Or (SrcOut >= 0) Then Begin
   If SrcIn >= 0 Then I := Integer((SrcIn * ZW) Div Len) Else I := 0;
   If SrcOut >= 0 Then PX := Integer((SrcOut * ZW) Div Len) Else PX := ZW - 1;
   If PX > ZW - 1 Then PX := ZW - 1;
   If PX >= I Then FillR(VX + I, BY - 2, VX + PX, BY + 3, Blue);
  End;
 End;
 PX := VX + Integer((Pos * ZW) Div Len);
 If PX > VX + ZW - 1 Then PX := VX + ZW - 1;
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
 MAXCTL = 48;

Var
 CtlN: Integer;
 CtlKind: Array[0..MAXCTL-1] Of Integer;  { 0 curseur, 1 case, 2 type, 3 titre }
 CtlId: Array[0..MAXCTL-1] Of Integer;

Const
 BlendNames: Array[0..7] Of String[14] =
  ('Normal','Addition','Multiplier','Ecran','Superposer','Difference','Obscurcir','Eclaircir');
 KeyNames: Array[0..3] Of String[10] = ('Aucune','Vert','Bleu','Rouge');
 MaskNames: Array[0..2] Of String[10] = ('Aucun','Rectangle','Ellipse');

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
  12: CtlLabel := 'Rotation';
  13: CtlLabel := 'Panoramique';
  14: CtlLabel := 'Gauche %';
  15: CtlLabel := 'Haut %';
  16: CtlLabel := 'Droite %';
  17: CtlLabel := 'Bas %';
  18: CtlLabel := 'Flou';
  19: CtlLabel := 'Netteté';
  20: CtlLabel := 'Miroir horiz.';
  21: CtlLabel := 'Miroir vert.';
  22: CtlLabel := 'Inverser';
  23: CtlLabel := 'Muet';
  24: CtlLabel := 'Désactivé';
  25: CtlLabel := 'Fusion';
  26: CtlLabel := 'Clé de teinte';
  27: CtlLabel := 'Tolérance';
  28: CtlLabel := 'Adoucir';
  30: CtlLabel := 'Trans. début';
  31: CtlLabel := 'Trans. fin';
  32: CtlLabel := 'Forme';
  33: CtlLabel := 'Centre X %';
  34: CtlLabel := 'Centre Y %';
  35: CtlLabel := 'Largeur %';
  36: CtlLabel := 'Hauteur %';
  37: CtlLabel := 'Contour doux';
  38: CtlLabel := 'Inverser masque';
  39: CtlLabel := 'LUT';
  45: CtlLabel := 'Graves dB';
  46: CtlLabel := 'Médiums dB';
  47: CtlLabel := 'Aigus dB';
  48: CtlLabel := 'Compresseur';
  49: CtlLabel := 'Réverbération';
  50: CtlLabel := 'Porte (bruit)';
  40: CtlLabel := 'Mouvement';
  41: CtlLabel := 'Couleur';
  42: CtlLabel := 'Effets';
  43: CtlLabel := 'Transitions';
  44: CtlLabel := 'Audio';
  51: CtlLabel := 'Recadrage';
  52: CtlLabel := 'Flou / Netteté';
  53: CtlLabel := 'Incrustation';
  54: CtlLabel := 'Masque';
  55: CtlLabel := 'Effets audio';
 Else CtlLabel := '';
 End;
End;

Function CtlMin(Id: Integer): Integer;
Begin
 Case Id Of
  1, 2: CtlMin := -400;
  3: CtlMin := 10;
  5, 6: CtlMin := -100;
  9: CtlMin := -40;
  10, 11: CtlMin := 1;
  12: CtlMin := -360;
  13: CtlMin := -100;
  35, 36: CtlMin := 1;
  45, 46, 47: CtlMin := -12;
 Else CtlMin := 0;
 End;
End;

Function CtlMax(Id: Integer): Integer;
Begin
 Case Id Of
  1, 2: CtlMax := 400;
  3: CtlMax := 400;
  4: CtlMax := 100;
  5, 6: CtlMax := 100;
  7: CtlMax := 200;
  8: CtlMax := 30;
  9: CtlMax := 12;
  10, 11: CtlMax := 90;
  12: CtlMax := 360;
  13: CtlMax := 100;
  14, 15, 16, 17: CtlMax := 100;
  18: CtlMax := 40;
  19: CtlMax := 100;
  27, 28: CtlMax := 100;
  33, 34, 35, 36: CtlMax := 100;
  37: CtlMax := 50;
  45, 46, 47: CtlMax := 12;
  48, 49, 50: CtlMax := 100;
 Else CtlMax := 1;
 End;
End;

Function CtlDef(Id: Integer): Integer;
Begin
 Case Id Of
  3, 4, 7: CtlDef := 100;
  10, 11: CtlDef := 15;
  27: CtlDef := 40;
  28: CtlDef := 20;
  33, 34, 35, 36: CtlDef := 50;
 Else CtlDef := 0;
 End;
End;

{ Parametre animable (index d'images-cles) ou -1 }
Function CtlKP(Id: Integer): Integer;
Begin
 Case Id Of
  1: CtlKP := 0;
  2: CtlKP := 1;
  3: CtlKP := 2;
  12: CtlKP := 3;
  4: CtlKP := 4;
  5: CtlKP := 5;
  6: CtlKP := 6;
  7: CtlKP := 7;
  9: CtlKP := 8;
  13: CtlKP := 9;
 Else CtlKP := -1;
 End;
End;

Function CtlGet(C: Integer; Id: Integer): Integer;
Var
 V: Integer;
 KP: Integer;
Begin
 CtlGet := 0;
 If (C < 0) Or (C >= P.NC) Then Exit;
 With P.Clips[C] Do Begin
  Case Id Of
   1: V := PosX;
   2: V := PosY;
   3: V := Scale;
   4: V := Opac;
   5: V := Br;
   6: V := Co;
   7: V := Sa;
   8: V := Mos;
   9: V := Vol;
   10: V := TInL;
   11: V := TOutL;
   12: V := Rot;
   13: V := Pan;
   14: V := CropL;
   15: V := CropT;
   16: V := CropR;
   17: V := CropB;
   18: V := Blur;
   19: V := Sharp;
   20: V := Ord((Fl And CF_MIRH) <> 0);
   21: V := Ord((Fl And CF_MIRV) <> 0);
   22: V := Ord((Fl And CF_INV) <> 0);
   23: V := Ord(Mute);
   24: V := Ord((Fl And CF_OFF) <> 0);
   25: V := Blend;
   26: V := KeyOn;
   27: V := KeySim;
   28: V := KeySmo;
   30: V := TIn;
   31: V := TOut;
   32: V := MaskK;
   33: V := MaskX;
   34: V := MaskY;
   35: V := MaskW;
   36: V := MaskH;
   37: V := MaskF;
   38: V := Ord((Fl And CF_MASKINV) <> 0);
   39: V := LutIdx;
   45: V := EqL;
   46: V := EqM;
   47: V := EqH;
   48: V := Comp;
   49: V := Rev;
   50: V := Gate;
  Else V := 0;
  End;
  KP := CtlKP(Id);
  If KP >= 0 Then V := Integer(KfEval(P.Clips[C], KP, Playhead - Start, V));
 End;
 CtlGet := V;
End;

Procedure CtlSet(C: Integer; Id, V: Integer);
Var
 Bit, KP: Integer;
 Tl: LongInt;
Begin
 If (C < 0) Or (C >= P.NC) Then Exit;
 KP := CtlKP(Id);
 If (KP >= 0) And KfHas(P.Clips[C], KP) Then Begin
  Tl := Clamp(Playhead - P.Clips[C].Start, 0, Max(0, P.Clips[C].Dur - 1));
  KfSet(P.Clips[C], KP, Tl, V, DefInterp);
  Exit;
 End;
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
   12: Rot := V;
   13: Pan := V;
   14: CropL := V;
   15: CropT := V;
   16: CropR := V;
   17: CropB := V;
   18: Blur := V;
   19: Sharp := V;
   20, 21, 22, 24, 38: Begin
    Case Id Of
     20: Bit := CF_MIRH;
     21: Bit := CF_MIRV;
     22: Bit := CF_INV;
     38: Bit := CF_MASKINV;
    Else Bit := CF_OFF;
    End;
    If V <> 0 Then Fl := Fl Or Bit Else Fl := Fl And (Not Bit);
   End;
   23: Mute := V <> 0;
   25: Blend := V;
   26: KeyOn := V;
   27: KeySim := V;
   28: KeySmo := V;
   30: TIn := V;
   31: TOut := V;
   32: MaskK := V;
   33: MaskX := V;
   34: MaskY := V;
   35: MaskW := V;
   36: MaskH := V;
   37: MaskF := V;
   39: LutIdx := V;
   45: EqL := V;
   46: EqM := V;
   47: EqH := V;
   48: Comp := V;
   49: Rev := V;
   50: Gate := V;
  End;
End;

{ Active/desactive l'animation d'un parametre : premiere cle a la tete de lecture,
  puis ajoute ou retire la cle a cet instant ; desactive quand la derniere cle disparait. }
Procedure KfToggleKey(C: Integer; Id: Integer; Off: Boolean);
Var
 KP, I: Integer;
 Tl, V: LongInt;
Begin
 KP := CtlKP(Id);
 If (KP < 0) Or (C < 0) Or (C >= P.NC) Then Exit;
 Tl := Clamp(Playhead - P.Clips[C].Start, 0, Max(0, P.Clips[C].Dur - 1));
 V := CtlGet(C, Id);
 If Off Then Begin
  P.Clips[C].Kn[KP] := 0;
  CtlSet(C, Id, Integer(V));
  Exit;
 End;
 If Not KfHas(P.Clips[C], KP) Then Begin
  KfSet(P.Clips[C], KP, Tl, V, DefInterp);
  Exit;
 End;
 I := KfFind(P.Clips[C], KP, Tl);
 If I >= 0 Then Begin
  If P.Clips[C].Kn[KP] = 1 Then Begin
   P.Clips[C].Kn[KP] := 0;
   CtlSet(C, Id, Integer(V));
  End Else KfDel(P.Clips[C], KP, I);
 End Else KfSet(P.Clips[C], KP, Tl, V, DefInterp);
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
  CtlAdd(3, 40); CtlAdd(0, 1); CtlAdd(0, 2); CtlAdd(0, 3); CtlAdd(0, 12); CtlAdd(0, 4);
  CtlAdd(3, 41); CtlAdd(0, 5); CtlAdd(0, 6); CtlAdd(0, 7);
  CtlAdd(3, 51); CtlAdd(0, 14); CtlAdd(0, 15); CtlAdd(0, 16); CtlAdd(0, 17);
  CtlAdd(3, 52); CtlAdd(0, 18); CtlAdd(0, 19);
  CtlAdd(3, 53); CtlAdd(2, 26); CtlAdd(0, 27); CtlAdd(0, 28);
  CtlAdd(3, 54); CtlAdd(2, 32); CtlAdd(0, 33); CtlAdd(0, 34); CtlAdd(0, 35); CtlAdd(0, 36);
  CtlAdd(0, 37); CtlAdd(1, 38);
  CtlAdd(3, 42); CtlAdd(0, 8); CtlAdd(1, 20); CtlAdd(1, 21); CtlAdd(1, 22); CtlAdd(2, 25);
  CtlAdd(2, 39); CtlAdd(1, 24);
  CtlAdd(3, 43); CtlAdd(2, 30); CtlAdd(0, 10); CtlAdd(2, 31); CtlAdd(0, 11);
 End Else Begin
  CtlAdd(3, 44); CtlAdd(0, 9); CtlAdd(0, 13); CtlAdd(1, 23); CtlAdd(1, 24);
  CtlAdd(3, 55); CtlAdd(0, 45); CtlAdd(0, 46); CtlAdd(0, 47); CtlAdd(0, 48); CtlAdd(0, 49);
  CtlAdd(0, 50);
  CtlAdd(3, 43); CtlAdd(2, 30); CtlAdd(0, 10); CtlAdd(2, 31); CtlAdd(0, 11);
 End;
End;

Const
 CTLH = 12;

Function CtlRowY(I: Integer): Integer;
Begin
 CtlRowY := AY1 + 45 + (I - CtlScroll) * CTLH;
End;

Function CtlSliderX1: Integer;
Begin
 CtlSliderX1 := AX1 + 118;
End;

Function CtlSliderX2: Integer;
Begin
 CtlSliderX2 := AX2 - 62;
End;

Function CtlKindMax(Id: Integer; Vid: Boolean): Integer;
Begin
 Case Id Of
  25: CtlKindMax := 7;
  26: CtlKindMax := 3;
  32: CtlKindMax := 2;
  39: CtlKindMax := LutCnt;
 Else If Vid Then CtlKindMax := 4 Else CtlKindMax := 1;
 End;
End;

Function TransName(Id, V: Integer): String;
Begin
 Case Id Of
  25: If (V >= 0) And (V <= 7) Then TransName := BlendNames[V] Else TransName := '?';
  26: If (V >= 0) And (V <= 3) Then TransName := KeyNames[V] Else TransName := '?';
  32: If (V >= 0) And (V <= 2) Then TransName := MaskNames[V] Else TransName := '?';
  39: If V = 0 Then TransName := 'Aucune' Else If V <= LutCnt Then TransName := LutNames[V] Else TransName := '?';
 Else Begin
   If (Id = 30) Or (Id = 31) Then Begin
    If (FirstSel >= 0) And (Not IsVideoTrack(P.Clips[FirstSel].Trk)) Then Begin
     If V = 0 Then TransName := 'Aucune' Else TransName := 'Fondu audio';
     Exit;
    End;
   End;
   If V <= 4 Then TransName := TrNames[V] Else TransName := '?';
  End;
 End;
End;

Procedure DrawControls;
Var
 I, Y, C, V, X1, X2, T, KP: Integer;
 Tl: LongInt;
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
 Tl := Playhead - P.Clips[C].Start;
 For I := CtlScroll To Min(CtlN - 1, CtlScroll + CTLROWS - 1) Do Begin
  Y := CtlRowY(I);
  V := CtlGet(C, CtlId[I]);
  Case CtlKind[I] Of
   3: Begin
    FillR(AX1 + 2, Y, AX2 - 2, Y + CTLH - 2, DarkGray);
    Txt(AX1 + 6, Y + 2, CtlLabel(CtlId[I]), White);
   End;
   0: Begin
    KP := CtlKP(CtlId[I]);
    If KP >= 0 Then Begin
     Frame(AX1 + 5, Y + 1, AX1 + 13, Y + 9, LightGray);
     If KfHas(P.Clips[C], KP) Then Begin
      If KfFind(P.Clips[C], KP, Tl) >= 0 Then FillR(AX1 + 7, Y + 3, AX1 + 11, Y + 7, Yellow)
      Else FillR(AX1 + 7, Y + 3, AX1 + 11, Y + 7, LightCyan);
     End;
    End;
    Txt(AX1 + 17, Y + 2, CtlLabel(CtlId[I]), LightGray);
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
    Txt(AX1 + 17, Y + 2, CtlLabel(CtlId[I]), LightGray);
    FillR(X1, Y, AX2 - 8, Y + CTLH - 3, DarkGray);
    Txt(X1 + 4, Y + 2, Fit(TransName(CtlId[I], V), AX2 - 8 - X1 - 6), White);
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
 SetupLayer(0, M, T);
 NLay := 1;
 CL := 0;
 For Y := 0 To THt - 1 Do
  For X := 0 To TWd - 1 Do Begin
   Compose((X * VW) Div TWd, (Y * VH) Div THt);
   If TrueMode Then PutRGBPixel(OX + X, OY + Y, (AR Shl 16) Or (AG Shl 8) Or AB)
   Else PutPixel(OX + X, OY + Y, QuantColor(X, Y));
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

Function SlotOf(T: Integer): Integer;
Begin
 Case T Of
  0, 1, 7: SlotOf := 0;
  2, 8, 9: SlotOf := 1;
  3: SlotOf := 2;
  10: SlotOf := 3;
  4: SlotOf := 4;
  5: SlotOf := 5;
 Else SlotOf := 6;
 End;
End;

Function SlotGroupSize(S: Integer): Integer;
Begin
 If (S = 0) Or (S = 1) Then SlotGroupSize := 3 Else SlotGroupSize := 1;
End;

{ Variante suivante d'un groupe d'outils }
Function NextVariant(T: Integer): Integer;
Begin
 Case T Of
  0: NextVariant := 1;
  1: NextVariant := 7;
  7: NextVariant := 0;
  2: NextVariant := 8;
  8: NextVariant := 9;
  9: NextVariant := 2;
 Else NextVariant := T;
 End;
End;

Procedure SelectTool(T: Integer);
Begin
 CurTool := T;
 ToolSlot[SlotOf(T)] := T;
 NeedAll := True;
End;

Procedure DrawTools;
Var
 S, Y, T: Integer;
Begin
 PanelBox(TX1, TY1, TX2, TY2);
 FillR(TX1 + 1, TY1 + 1, TX2 - 1, TY1 + 13, DarkGray);
 For S := 0 To 6 Do Begin
  Y := ToolBtnY(S);
  T := ToolSlot[S];
  If SlotOf(CurTool) = S Then Begin
   T := CurTool;
   FillR(TX1 + 1, Y, TX2 - 1, Y + 22, Blue);
   Frame(TX1 + 1, Y, TX2 - 1, Y + 22, LightCyan);
   ToolIcon(T, TX1, Y, White);
  End Else Begin
   Btn(TX1 + 1, Y, TX2 - 1, Y + 22, False);
   ToolIcon(T, TX1, Y, LightGray);
  End;
  If SlotGroupSize(S) > 1 Then IcoTri(TX2 - 5, Y + 17, TX2 - 2, Y + 17, TX2 - 2, Y + 20, LightCyan);
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

{ Retourne l'emplacement d'outil (0..6), 7 pour le magnetisme, -1 sinon }
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
 KP2, K2, PY0, PY1, VBase: Integer;
 VMin, VMax, V2: LongInt;
 F, EN, WI: LongInt;
 Env: PEnv;
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
 If WaveOn And (Not IsVideoTrack(P.Clips[I].Trk)) And (Not P.Clips[I].Mute) Then Begin
  YM := (Y1 + 9 + Y2) Div 2;
  SetColor(Black);
  Env := Nil;
  EN := 0;
  If P.Media[P.Clips[I].Med].Kind = MK_WAV Then Env := EnvGet(P.Media[P.Clips[I].Med].Cache, EN);
  X := XA;
  While X <= XB Do Begin
   F := XToFrame(X) - P.Clips[I].Start;
   If Env <> Nil Then Begin
    WI := ((P.Clips[I].InPt + SrcOfs(P.Clips[I], F)) * 50) Div P.Fps;
    If (WI >= 0) And (WI < EN) Then
     H := (Max(Env^[WI * 2], Env^[WI * 2 + 1]) * 7) Div 255
    Else H := 0;
   End Else
   H := Abs(Sn(F * 13 + P.Clips[I].Med * 29)) * 6 Div 127 +
        (Hash3(F, P.Clips[I].Med, 5) Mod 4);
   H := H * (100 + P.Clips[I].Vol * 3) Div 100;
   If H > (Y2 - Y1 - 10) Div 2 Then H := (Y2 - Y1 - 10) Div 2;
   If H < 0 Then H := 0;
   Line(X, YM - H, X, YM + H);
   Inc(X, 2);
  End;
 End;
 { Courbe d'opacite (video) ou de volume (audio) et images-cles }
 If (Sel Or (CurTool = TL_PEN)) And (XB - XA > 6) Then Begin
  If IsVideoTrack(P.Clips[I].Trk) Then Begin
   KP2 := 4; VMin := 0; VMax := 100; VBase := P.Clips[I].Opac;
  End Else Begin
   KP2 := 8; VMin := -40; VMax := 12; VBase := P.Clips[I].Vol;
  End;
  SetColor(Yellow);
  PY0 := -1;
  X := XA;
  While X <= XB Do Begin
   V2 := KfEval(P.Clips[I], KP2, XToFrame(X) - P.Clips[I].Start, VBase);
   PY1 := Y2 - Integer(((V2 - VMin) * (Y2 - Y1 - 10)) Div (VMax - VMin));
   If PY0 >= 0 Then Line(X - 3, PY0, X, PY1);
   PY0 := PY1;
   Inc(X, 3);
  End;
  For K2 := 0 To P.Clips[I].Kn[KP2] - 1 Do Begin
   X := FrameToX(P.Clips[I].Start + P.Clips[I].Kt[KP2, K2]);
   If (X >= XA) And (X <= XB) Then Begin
    PY1 := Y2 - Integer(((P.Clips[I].Kv[KP2, K2] - VMin) * (Y2 - Y1 - 10)) Div (VMax - VMin));
    FillR(X - 2, PY1 - 2, X + 2, PY1 + 2, White);
    Frame(X - 2, PY1 - 2, X + 2, PY1 + 2, Black);
   End;
  End;
 End;
 For KP2 := 0 To NKP - 1 Do
  For K2 := 0 To P.Clips[I].Kn[KP2] - 1 Do Begin
   X := FrameToX(P.Clips[I].Start + P.Clips[I].Kt[KP2, K2]);
   If (X >= XA) And (X <= XB) Then PutPixel(X, Y1 + 7, Red);
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

Function TrkBtnTop(R: Integer): Integer;
Begin
 TrkBtnTop := RowY(R) + (TRH - 13) Div 2;
End;

Procedure DrawTimeline;
Var
 R, T, I, Y, X, TW0, TL0, BY0: Integer;
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
 For R := 0 To NRows - 1 Do Begin
  T := RowTrack(R);
  Y := RowY(R);
  BY0 := TrkBtnTop(R);
  FillR(LX1 + 1, Y, TLX0 - 2, Y + TRH - 1, DarkGray);
  FillR(TLX0, Y, TLX1, Y + TRH - 1, Black);
  HLine(LX1 + 1, TLX1, Y + TRH - 1, DarkGray);
  Txt(LX1 + 4, BY0 + 2, TrackName(T), White);
  If (P.TrkF[T] And TF_HIDE) <> 0 Then Begin
   Btn(LX1 + 26, BY0, LX1 + 38, BY0 + 12, True);
   Txt(LX1 + 29, BY0 + 3, 'x', LightRed);
  End Else Begin
   Btn(LX1 + 26, BY0, LX1 + 38, BY0 + 12, False);
   If IsVideoTrack(T) Then Txt(LX1 + 29, BY0 + 3, 'o', LightCyan) Else Txt(LX1 + 29, BY0 + 3, 'M', LightGreen);
  End;
  If (P.TrkF[T] And TF_LOCK) <> 0 Then Begin
   Btn(LX1 + 42, BY0, LX1 + 54, BY0 + 12, True);
   Txt(LX1 + 45, BY0 + 3, 'L', Yellow);
  End Else Begin
   Btn(LX1 + 42, BY0, LX1 + 54, BY0 + 12, False);
   Txt(LX1 + 45, BY0 + 3, 'l', LightGray);
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
 HLine(LX1 + 1, TLX1, RowY(P.NV) - 1, LightGray);
 For I := 0 To P.NC - 1 Do DrawClipBox(I);
 DrawRuler;
 { Tete de lecture }
 X := FrameToX(Playhead);
 If (X >= TLX0) And (X <= TLX1) Then Begin
  VLine(X, RULY1 + 4, RowY(NRows) - 1, LightBlue);
  IcoTri(X - 4, RULY1, X + 4, RULY1, X, RULY1 + 6, LightBlue);
 End;
 { Guide de magnetisme }
 If (SnapGuide >= 0) And (DragMode <> DM_NONE) Then Begin
  X := FrameToX(SnapGuide);
  If (X >= TLX0) And (X <= TLX1) Then VLine(X, RULY2, RowY(NRows) - 1, White);
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
 N := (LY2 - 20 - (LY1 + 14)) Div 5 + 1;
 If N < 8 Then N := 8;
 For I := 0 To N - 1 Do Begin
  Y := LY2 - 20 - I * 5;
  If I * 100 Div N < Lvl Then Begin
   If I * 100 Div N >= 86 Then C := LightRed
   Else If I * 100 Div N >= 66 Then C := Yellow
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
 P.Media[P.NM].NF := 0;
 P.Media[P.NM].Fps100 := 0;
 P.Media[P.NM].Cache := '';
 P.Media[P.NM].CW := 0;
 P.Media[P.NM].CH := 0;
 P.Media[P.NM].Txt := Copy(Tx, 1, 22);
 P.Media[P.NM].Path := Copy(Path, 1, 80);
 AddMedia := P.NM;
 Inc(P.NM);
End;

Function SaveProject(Const FN: String): Boolean;
Var
 F: Text;
 I, KPi, KJ: Integer;
Begin
 SaveProject := False;
 {$I-}
 Assign(F, FN);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, 'PREMIERE1');
 WriteLn(F, 'N|', P.Name);
 WriteLn(F, 'V|2');
 WriteLn(F, 'U|', P.NV, ' ', P.NA);
 WriteLn(F, 'F|', P.Fps);
 WriteLn(F, 'R|', VW, '|', VH);
 For I := 0 To P.NM - 1 Do
  WriteLn(F, 'M|', P.Media[I].Name, '|', P.Media[I].Kind, '|', P.Media[I].Dur, '|',
          P.Media[I].Par, '|', P.Media[I].Txt, '|', P.Media[I].Cache, '|', P.Media[I].NF, '|',
          P.Media[I].Fps100, '|', P.Media[I].CW, '|', P.Media[I].CH, '|', P.Media[I].Path);
 For I := 0 To P.NC - 1 Do
  With P.Clips[I] Do Begin
   WriteLn(F, 'C|', Trk, ' ', Med, ' ', Start, ' ', Dur, ' ', InPt, ' ', Speed, ' ', Opac, ' ',
           PosX, ' ', PosY, ' ', Scale, ' ', Br, ' ', Co, ' ', Sa, ' ', Mos, ' ', Fl, ' ',
           Vol, ' ', Ord(Mute), ' ', TIn, ' ', TInL, ' ', TOut, ' ', TOutL, '|', Name);
   WriteLn(F, 'X|', Speed2, ' ', Rot, ' ', Pan, ' ', Blend, ' ', CropL, ' ', CropT, ' ', CropR, ' ',
           CropB, ' ', Blur, ' ', Sharp, ' ', KeyOn, ' ', KeySim, ' ', KeySmo, ' ', MaskK, ' ',
           MaskX, ' ', MaskY, ' ', MaskW, ' ', MaskH, ' ', MaskF, ' ', LutIdx, ' ', EqL, ' ',
           EqM, ' ', EqH, ' ', Comp, ' ', Rev, ' ', Gate, ' ', Link);
   For KPi := 0 To NKP - 1 Do
    If Kn[KPi] > 0 Then Begin
     Write(F, 'Y|', KPi, ' ', Kn[KPi]);
     For KJ := 0 To Kn[KPi] - 1 Do Write(F, ' ', Kt[KPi, KJ], ' ', Kv[KPi, KJ], ' ', Ki[KPi, KJ]);
     WriteLn(F);
    End;
  End;
 For I := 0 To P.NK - 1 Do WriteLn(F, 'K|', P.Marks[I].Pos, '|', P.Marks[I].Name);
 WriteLn(F, 'I|', P.InM, '|', P.OutM);
 For I := 0 To 15 Do WriteLn(F, 'W|', I, ' ', P.TrkF[I]);
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
 P.NV := 3;
 P.NA := 3;
 If TrueMode Then Begin
  VW := 640;
  VH := 360;
 End Else Begin
  VW := 284;
  VH := 160;
 End;
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
 CacheCloseAll;
 Modified := False;
 ProjFile := '';
 InitLayout;
End;

Function LoadProject(Const FN: String): Boolean;
Var
 F: Text;
 L, Tag, S: String;
 C: TClip;
 M: Integer;
 Slot, KJ: Integer;
 LastOk: Boolean;
 LoadVer: Integer;
Begin
 LoadProject := False;
 LastOk := False;
 LoadVer := 1;
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
  Else If Tag = 'V' Then LoadVer := Integer(StrVal(L, 1))
  Else If Tag = 'U' Then Begin
   P.NV := Integer(Clamp(TakeNum(L), 1, 8));
   P.NA := Integer(Clamp(TakeNum(L), 1, 8));
  End
  Else If Tag = 'R' Then Begin
   If TrueMode Then Begin
    VW := Integer(Clamp(StrVal(TakeField(L), 640), 160, 3840));
    VH := Integer(Clamp(StrVal(L, 360), 90, 2160));
   End;
  End
  Else If Tag = 'M' Then Begin
   S := TakeField(L);
   M := AddMedia(S, 0, 0, 0, '', '');
   If M >= 0 Then Begin
    P.Media[M].Kind := Integer(StrVal(TakeField(L), 0));
    P.Media[M].Dur := StrVal(TakeField(L), 125);
    P.Media[M].Par := Integer(StrVal(TakeField(L), 0));
    P.Media[M].Txt := Copy(TakeField(L), 1, 22);
    P.Media[M].Cache := Copy(TakeField(L), 1, 12);
    P.Media[M].NF := StrVal(TakeField(L), 0);
    P.Media[M].Fps100 := Integer(StrVal(TakeField(L), 0));
    P.Media[M].CW := Integer(StrVal(TakeField(L), 0));
    P.Media[M].CH := Integer(StrVal(TakeField(L), 0));
    P.Media[M].Path := Copy(L, 1, 80);
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
   If (LoadVer < 2) And (C.Trk >= 3) Then C.Trk := C.Trk + AUDBASE - 3;
   If (C.Trk >= 0) And (C.Trk < NTRK) And (C.Med >= 0) And (C.Med < P.NM) And
      (C.Dur > 0) And (C.Speed > 0) And (C.Scale > 0) Then LastOk := AddClipRec(C) >= 0
   Else LastOk := False;
  End
  Else If Tag = 'X' Then Begin
   If LastOk Then With P.Clips[P.NC - 1] Do Begin
    Speed2 := Integer(TakeNum(L));
    Rot := Integer(TakeNum(L));
    Pan := Integer(TakeNum(L));
    Blend := Integer(TakeNum(L));
    CropL := Integer(TakeNum(L));
    CropT := Integer(TakeNum(L));
    CropR := Integer(TakeNum(L));
    CropB := Integer(TakeNum(L));
    Blur := Integer(TakeNum(L));
    Sharp := Integer(TakeNum(L));
    KeyOn := Integer(TakeNum(L));
    KeySim := Integer(TakeNum(L));
    KeySmo := Integer(TakeNum(L));
    MaskK := Integer(TakeNum(L));
    MaskX := Integer(TakeNum(L));
    MaskY := Integer(TakeNum(L));
    MaskW := Integer(TakeNum(L));
    MaskH := Integer(TakeNum(L));
    MaskF := Integer(TakeNum(L));
    LutIdx := Integer(TakeNum(L));
    EqL := Integer(TakeNum(L));
    EqM := Integer(TakeNum(L));
    EqH := Integer(TakeNum(L));
    Comp := Integer(TakeNum(L));
    Rev := Integer(TakeNum(L));
    Gate := Integer(TakeNum(L));
    Link := Integer(TakeNum(L));
   End;
  End
  Else If Tag = 'Y' Then Begin
   If LastOk Then With P.Clips[P.NC - 1] Do Begin
    M := Integer(TakeNum(L));
    Slot := Integer(TakeNum(L));
    If (M >= 0) And (M < NKP) And (Slot > 0) And (Slot <= MAXK) Then Begin
     Kn[M] := Slot;
     For KJ := 0 To Slot - 1 Do Begin
      Kt[M, KJ] := TakeNum(L);
      Kv[M, KJ] := SmallInt(TakeNum(L));
      Ki[M, KJ] := Byte(TakeNum(L));
     End;
    End;
   End;
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
  Else If Tag = 'W' Then Begin
   M := Integer(TakeNum(L));
   If (M >= 0) And (M < NTRK) Then P.TrkF[M] := Integer(TakeNum(L));
  End;
 End;
 Close(F);
 Modified := False;
 ProjFile := FN;
 InitLayout;
 LoadProject := True;
End;

{ ---------- Exportations ---------- }

Function ExportBmpFrame(Const FN: String; Tm: LongInt): Boolean;
Var
 F: File;
 H: Array[0..53] Of Byte;
 Row: PBigBytes;
 X, Y: Integer;
 Stride: LongInt;
Begin
 ExportBmpFrame := False;
 Stride := ((LongInt(VW) * 3 + 3) Div 4) * 4;
 FillChar(H, SizeOf(H), 0);
 H[0] := Ord('B');
 H[1] := Ord('M');
 PutLE32(H, 2, 54 + Stride * VH);
 PutLE32(H, 10, 54);
 PutLE32(H, 14, 40);
 PutLE32(H, 18, VW);
 PutLE32(H, 22, VH);
 H[26] := 1;
 H[28] := 24;
 PutLE32(H, 34, Stride * VH);
 PutLE32(H, 38, 2835);
 PutLE32(H, 42, 2835);
 {$I-}
 Assign(F, FN);
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 GetMem(Row, Stride);
 FillChar(Row^, Stride, 0);
 BlockWrite(F, H, 54);
 BuildLayers(Tm);
 For Y := VH - 1 Downto 0 Do Begin
  For X := 0 To VW - 1 Do Begin
   If NLay = 0 Then Begin
    AR := 0; AG := 0; AB := 0;
   End Else Compose(X, Y);
   Row^[X * 3] := AB;
   Row^[X * 3 + 1] := AG;
   Row^[X * 3 + 2] := AR;
  End;
  BlockWrite(F, Row^, Stride);
 End;
 FreeMem(Row, Stride);
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
    If IsVideoTrack(T) Then Ch := 'V' Else Ch := 'A';
    With P.Clips[Best] Do Begin
     WriteLn(F, Pad(N, 3), '  ', EDLName(P.Media[Med].Name), '        ', Ch,
             '     C        ', TC(InPt), ' ', TC(InPt + SrcOfs(P.Clips[Best], Dur)), ' ',
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
{  Puits de conformation : redimensionne chaque image decodee a 284x160, }
{  la convertit en RGB332 et l'ecrit dans le fichier cache du media      }
{ ====================================================================== }

Var
 CnOn: Boolean;
 CnF: File;
 CnName: String[12];
 CnAudio: Boolean;
 CnFrames, CnMaxFrames, CnFps100, CnMaxSec, CnProgD, CnProgT, CnLastUI: LongInt;
 CnCancel, CnCapped: Boolean;
 CnBuf: PBig16;
 CnBufSz: LongInt;
 CnCW, CnCH: LongInt;
 CnX0, CnX1: Array[0..2047] Of Integer;
 CnAB: Array[0..511] Of Byte;
 CnABN: Integer;
 CnTitle: String;

Procedure ConfWriteHdr(IsAud: Boolean);
Var
 H: Array[0..31] Of Byte;
Begin
 FillChar(H, SizeOf(H), 0);
 If IsAud Then H[0] := Ord('A') Else H[0] := Ord('V');
 H[1] := Ord('C');
 If IsAud Then H[2] := Ord('1') Else H[2] := Ord('2');
 H[3] := 0;
 H[4] := CnCW And 255;
 H[5] := CnCW Shr 8;
 H[6] := CnCH And 255;
 H[7] := CnCH Shr 8;
 PutLE32(H, 8, CnFrames);
 PutLE32(H, 12, CnFrames);
 PutLE32(H, 16, CnFps100);
 Seek(CnF, 0);
 BlockWrite(CnF, H, 32);
End;

Procedure ConfShow;
Var
 X, Y, W, Pc: Integer;
Begin
 W := 340;
 X := (SW - W) Div 2;
 Y := (SH - 80) Div 2;
 HideMouse;
 DlgBox(X, Y, W, 80, CnTitle);
 If CnAudio Then Txt(X + 12, Y + 26, 'Analyse audio : ' + IStr(CnFrames) + ' fenêtres', Black)
 Else Txt(X + 12, Y + 26, 'Conformation : ' + IStr(CnFrames) + ' images', Black);
 FillR(X + 12, Y + 42, X + W - 12, Y + 52, White);
 Frame(X + 12, Y + 42, X + W - 12, Y + 52, DarkGray);
 If CnProgT > 0 Then Pc := Integer((CnProgD * (W - 26)) Div CnProgT)
 Else If CnMaxFrames > 0 Then Pc := Integer((CnFrames * (W - 26)) Div CnMaxFrames)
 Else Pc := 0;
 If Pc > W - 26 Then Pc := W - 26;
 If Pc > 0 Then FillR(X + 13, Y + 43, X + 12 + Pc, Y + 51, Blue);
 Txt(X + 12, Y + 60, 'Echap ou clic : arrêter et garder le début', DarkGray);
 ShowMouse;
End;

Procedure ConfUI(Force: Boolean);
Var
 T: LongInt;
 C: Integer;
Begin
 T := Ticks;
 If (Not Force) And (TickDiff(T, CnLastUI) < 15) Then Exit;
 CnLastUI := T;
 ConfShow;
 PollMouse;
 If PressL Then CnCancel := True;
 C := ReadKeyCode;
 If C = 27 Then CnCancel := True;
End;

{ Taille d'une image du cache : la resolution de la sequence, plafonnee. }
Procedure ConfTarget(Still: Boolean; Var W, H: LongInt);
Var
 Cap: LongInt;
Begin
 W := VW;
 H := VH;
 If Still Then Cap := 2048 Else Cap := 640;
 If W > Cap Then Begin
  H := (H * Cap) Div W;
  W := Cap;
 End;
 If W < 16 Then W := 16;
 If H < 16 Then H := 16;
End;

Function ConfBegin(Const Name: String; IsAud: Boolean; MaxSec: LongInt; Const Title: String;
                   Still: Boolean): Boolean;
Var
 H: Array[0..31] Of Byte;
Begin
 ConfBegin := False;
 CacheCloseName(Name);
 {$I-}
 Assign(CnF, Name);
 Rewrite(CnF, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 FillChar(H, SizeOf(H), 0);
 BlockWrite(CnF, H, 32);
 ConfTarget(Still, CnCW, CnCH);
 If CnBuf <> Nil Then FreeMem(CnBuf, CnBufSz);
 CnBufSz := CnCW * CnCH * 2;
 GetMem(CnBuf, CnBufSz);
 CnName := Name;
 CnAudio := IsAud;
 CnFrames := 0;
 CnFps100 := 2500;
 CnMaxSec := MaxSec;
 CnMaxFrames := (MaxSec * CnFps100) Div 100;
 If IsAud Then CnMaxFrames := 30000;
 CnProgD := 0;
 CnProgT := 0;
 CnCancel := False;
 CnCapped := False;
 CnABN := 0;
 CnTitle := Title;
 CnLastUI := 0;
 CnOn := True;
 WaitRelease;
 ConfUI(True);
 ConfBegin := True;
End;

Procedure ConfEnd(Var Frames: LongInt; Var Fps100: LongInt);
Begin
 Frames := CnFrames;
 Fps100 := CnFps100;
 If CnOn Then Begin
  CnOn := False;
  If CnAudio And (CnABN > 0) Then BlockWrite(CnF, CnAB, CnABN);
  If CnFrames > 0 Then ConfWriteHdr(CnAudio);
  Close(CnF);
  If CnFrames = 0 Then Begin
   Erase(CnF);
  End;
  If IOResult <> 0 Then ;
 End;
 WaitRelease;
 DrawAll;
End;

Procedure ConfSetFps(Fps100: LongInt);
Begin
 If (Fps100 < 100) Or (Fps100 > 12000) Then Exit;
 CnFps100 := Fps100;
 CnMaxFrames := (CnMaxSec * Fps100) Div 100;
End;

Procedure ConfProgress(Done, Total: LongInt);
Begin
 CnProgD := Done;
 CnProgT := Total;
End;

Function ConfEmit(W, H: LongInt; Pix: Pointer): Boolean;
Var
 DW, DH, OX, OY, DX, DY, Y0, Y1, X, Y, SR, SG, SB, N, Idx: LongInt;
 Src: PBigBytes;
 R, G, B: LongInt;
 Rem: LongInt;
 Got: LongInt;
Begin
 ConfEmit := False;
 If (Not CnOn) Or CnCancel Or CnAudio Then Exit;
 ConfEmit := True;
 If (W < 1) Or (H < 1) Or (W > 16384) Or (H > 16384) Or (Pix = Nil) Then Exit;
 Src := PBigBytes(Pix);
 If W * CnCH >= H * CnCW Then Begin
  DW := CnCW;
  DH := (H * CnCW) Div W;
 End Else Begin
  DH := CnCH;
  DW := (W * CnCH) Div H;
 End;
 If DW < 1 Then DW := 1;
 If DH < 1 Then DH := 1;
 If DW > CnCW Then DW := CnCW;
 If DH > CnCH Then DH := CnCH;
 OX := (CnCW - DW) Div 2;
 OY := (CnCH - DH) Div 2;
 FillChar(CnBuf^, CnBufSz, 0);
 For DX := 0 To DW - 1 Do Begin
  CnX0[DX] := Integer((DX * W) Div DW);
  CnX1[DX] := Integer(((DX + 1) * W) Div DW);
  If CnX1[DX] <= CnX0[DX] Then CnX1[DX] := CnX0[DX] + 1;
  If CnX1[DX] > W Then CnX1[DX] := W;
 End;
 For DY := 0 To DH - 1 Do Begin
  Y0 := (DY * H) Div DH;
  Y1 := ((DY + 1) * H) Div DH;
  If Y1 <= Y0 Then Y1 := Y0 + 1;
  If Y1 > H Then Y1 := H;
  For DX := 0 To DW - 1 Do Begin
   N := 0;
   SR := 0;
   SG := 0;
   SB := 0;
   For Y := Y0 To Y1 - 1 Do Begin
    Idx := (Y * W + CnX0[DX]) * 3;
    For X := CnX0[DX] To CnX1[DX] - 1 Do Begin
     SR := SR + Src^[Idx];
     SG := SG + Src^[Idx + 1];
     SB := SB + Src^[Idx + 2];
     Inc(Idx, 3);
     Inc(N);
    End;
   End;
   R := SR Div N;
   G := SG Div N;
   B := SB Div N;
   CnBuf^[(OY + DY) * CnCW + OX + DX] := ((R Shr 3) Shl 11) Or ((G Shr 2) Shl 5) Or (B Shr 3);
  End;
 End;
 {$I-}
 Got := 0;
 While Got < CnBufSz Do Begin
  Rem := Min(CnBufSz - Got, 60000);
  BlockWrite(CnF, PBigBytes(CnBuf)^[Got], Rem);
  Got := Got + Rem;
 End;
 {$I+}
 If IOResult <> 0 Then Begin
  CnCancel := True;
  ConfEmit := False;
  Exit;
 End;
 Inc(CnFrames);
 ConfUI(False);
 If CnCancel Then ConfEmit := False;
 If CnFrames >= CnMaxFrames Then Begin
  CnCapped := True;
  CnCancel := True;
  ConfEmit := False;
 End;
End;

Function ConfAudioEmit(PeakL, PeakR: LongInt): Boolean;
Begin
 ConfAudioEmit := False;
 If (Not CnOn) Or (Not CnAudio) Or CnCancel Then Exit;
 CnAB[CnABN] := Clamp(PeakL, 0, 255);
 CnAB[CnABN + 1] := Clamp(PeakR, 0, 255);
 Inc(CnABN, 2);
 If CnABN >= 512 Then Begin
  BlockWrite(CnF, CnAB, 512);
  CnABN := 0;
 End;
 Inc(CnFrames);
 ConfUI(False);
 If CnFrames >= CnMaxFrames Then CnCancel := True;
 ConfAudioEmit := Not CnCancel;
End;
{ ================================================================
  IMGLOAD : lecture d'images pour PREMIERE.
  Decodeurs extraits de PAINT.PAS (CloneDRAW), en Pascal pur.
  Points d'entree :
    Function ImgConform(Const FN: String): Boolean;
    Function ImgKnownExt(Const Ext: String): Boolean;
  Formats : BMP DIB GIF PNG APNG JPG PCX TGA PPM/PGM/PBM XBM LBM/IFF
  TIFF BGX WPG MSP MAC ICO CUR DDS HDR EXR DNG CR2 ARW DCM FAX.
  Les decodeurs ecrivent dans une couche de compatibilite minimale
  (PnImageBuffer, PnCanvasImage...) ; le resultat est reconverti en RGB24
  et passe UNE fois a ConfEmit. Requiert FPC (stub sous Turbo Pascal).
  ================================================================ }
{$IFDEF FPC}
{$PUSH}{$R-}{$Q-}
Const
 PnFMT_BMP = 0; PnFMT_GIF = 1; PnFMT_PNG = 2; PnFMT_JPEG = 3; PnFMT_PCX = 4; PnFMT_TARGA = 5;
 PnFMT_TIFF = 6; PnFMT_XBM = 7; PnFMT_WPG = 8; PnFMT_LBM = 9; PnFMT_HDR = 10; PnFMT_FAX = 11;
 PnFMT_EXR = 12; PnFMT_DNG = 13; PnFMT_BGX = 14; PnFMT_DDS = 15; PnFMT_DCM = 16; PnFMT_APNG = 17;
 PnFMT_ARW = 18; PnFMT_CR2 = 19; PnFMT_PPM = 20; PnFMT_DIB = 21; PnFMT_CUR = 22; PnFMT_MSP = 23;
 PnFMT_MAC = 24; PnFMT_PAS = 25; PnFMT_ICO = 26;
 PnMAX_IMAGE_WIDTH = 4096;
 PnMAX_IMAGE_HEIGHT = 4096;
Type
 PnTRGBColor = Record
  R, G, B: Byte;
  A: Byte;
 End;
 PnTPalette = Array[0..255] of PnTRGBColor;
 PnTPaintMetadata = Record
  Values: Array[0..5] Of String;
  Limited: Boolean;
 End;
 PnTImageBuffer = Record
  Width, Height: Integer;
  BitDepth: Byte;
  HasTransparency: Boolean;
  TransparentColor: PnTRGBColor;
  Palette: PnTPalette;
  Modified: Boolean;
  FileName: String;
  Format: Byte;
  Metadata: PnTPaintMetadata;
  HasHotspot: Boolean;
  HotspotX,HotspotY,CursorImages: Integer;
 End;
Var
 PnImageBuffer: PnTImageBuffer;
 PnCanvasImage: PByte;
 PnCanvasImageW, PnCanvasImageH: Integer;
 { Copie RGB24 pleine resolution interceptee a la quantification. }
 ImgCapRGB: PByte;
 ImgCapSize: LongInt;
 ImgCapW, ImgCapH: Integer;

Const
 PnGIF87_SIGNATURE = 'GIF87a';
 PnGIF89_SIGNATURE = 'GIF89a';
 PnPNG_SIGNATURE: Array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

Function PnMin(A, B: Integer): Integer;
Begin
 If A < B Then PnMin := A Else PnMin := B;
End;

Function PnMax(A, B: Integer): Integer;
Begin
 If A > B Then PnMax := A Else PnMax := B;
End;

Function PnUpperCase(S: String): String;
Var I: Integer;
Begin
 For I := 1 to Length(S) do S[I] := UpCase(S[I]);
 PnUpperCase := S;
End;

Procedure ImgNoPal(I, R, G, B: Integer);
Begin
End;

Function PMKey(Index: Integer): String;
Begin
 Case Index Of
  0: PMKey:='Title'; 1: PMKey:='Author'; 2: PMKey:='Copyright';
  3: PMKey:='Software'; 4: PMKey:='Description'; 5: PMKey:='Comment';
 Else PMKey:=''; End;
End;

Function PMIndex(Const Key: String): Integer;
Var I: Integer;
Begin
 PMIndex:=-1; For I:=0 To 5 Do If PMKey(I)=Key Then Begin PMIndex:=I; Exit; End;
End;

Procedure PMByte(Var M: PnTPaintMetadata; Index,B: Integer);
Begin
 If Length(M.Values[Index])<255 Then M.Values[Index]:=M.Values[Index]+Chr(B)
 Else M.Limited:=True;
End;
Type
 TGFBytes = Array[0..134217727] Of Byte;
 PGFBytes = ^TGFBytes;
 TGFState = Record
  Data: PGFBytes;
  Size,Position: LongInt;
  Bad,HaveImage,HaveGlobal,Transparent: Boolean;
  Width,Height,GlobalCount,ColorCount,BackgroundIndex,TransparentIndex: Integer;
  GlobalPalette,Colors: PnTPalette;
  Background: PnTRGBColor;
  ImageLeft,ImageTop,ImageWidth,ImageHeight: Integer;
  Interlaced: Boolean;
  Frame: PGFBytes;
  FrameSize,Produced: LongInt;
  Row,Column,Pass: Integer;
  BlockLeft,BitCount: Integer;
  BitBuffer: LongInt;
  Prefix: Array[0..4095] Of Word;
  Suffix: Array[0..4095] Of Byte;
  Stack: Array[0..4096] Of Byte;
  Metadata: PnTPaintMetadata;
 End;
 PGFState = ^TGFState;

Function JDAllocate(Size: LongInt): Pointer; Forward;

Function GFByte(Var D: TGFState): Integer;
Begin
 GFByte:=0;
 If D.Bad Then Exit;
 If D.Position>=D.Size Then Begin D.Bad:=True; Exit; End;
 GFByte:=D.Data^[D.Position]; Inc(D.Position);
End;

Function GFWord(Var D: TGFState): LongInt;
Var LoByte: Integer;
Begin
 LoByte:=GFByte(D); GFWord:=LoByte+LongInt(GFByte(D))*256;
End;

Procedure GFReadPalette(Var D: TGFState; Var Colors: PnTPalette; Count: Integer);
Var I: Integer;
Begin
 If (Count<2) Or (Count>256) Or (D.Size-D.Position<LongInt(Count)*3) Then Begin D.Bad:=True; Exit; End;
 FillChar(Colors,SizeOf(Colors),0);
 For I:=0 To Count-1 Do Begin
  Colors[I].R:=GFByte(D); Colors[I].G:=GFByte(D); Colors[I].B:=GFByte(D);
  Colors[I].A:=255;
 End;
End;

Procedure GFSkipBlocks(Var D: TGFState);
Var N: Integer;
Begin
 Repeat
  N:=GFByte(D);
  If D.Bad Then Exit;
  If N>D.Size-D.Position Then Begin D.Bad:=True; Exit; End;
  Inc(D.Position,N);
 Until N=0;
End;

Function GFDataByte(Var D: TGFState): Integer;
Begin
 GFDataByte:=-1;
 If D.Bad Then Exit;
 If D.BlockLeft=0 Then Begin
  D.BlockLeft:=GFByte(D);
  If D.Bad Or (D.BlockLeft=0) Then Exit;
  If D.BlockLeft>D.Size-D.Position Then Begin D.Bad:=True; Exit; End;
 End;
 GFDataByte:=GFByte(D); Dec(D.BlockLeft);
End;

Function GFCode(Var D: TGFState; Bits: Integer): Integer;
Var B: Integer;
Begin
 GFCode:=0;
 While (D.BitCount<Bits) And Not D.Bad Do Begin
  B:=GFDataByte(D);
  If B<0 Then Begin D.Bad:=True; Exit; End;
  D.BitBuffer:=D.BitBuffer Or (LongInt(B) Shl D.BitCount);
  Inc(D.BitCount,8);
 End;
 GFCode:=D.BitBuffer And ((1 Shl Bits)-1);
 D.BitBuffer:=D.BitBuffer Shr Bits; Dec(D.BitCount,Bits);
End;

Procedure GFEmit(Var D: TGFState; Index: Integer);
Const Starts: Array[0..3] Of Byte = (0,4,2,1);
      Steps: Array[0..3] Of Byte = (8,8,4,2);
Begin
 If D.Bad Then Exit;
 If (Index<0) Or (Index>=D.ColorCount) Or (D.Produced>=D.FrameSize) Or
    (D.Row<0) Or (D.Row>=D.ImageHeight) Then Begin D.Bad:=True; Exit; End;
 D.Frame^[LongInt(D.Row)*D.ImageWidth+D.Column]:=Index;
 Inc(D.Produced); Inc(D.Column);
 If D.Column=D.ImageWidth Then Begin
  D.Column:=0;
  If Not D.Interlaced Then Inc(D.Row)
  Else Begin
   Inc(D.Row,Steps[D.Pass]);
   While (D.Row>=D.ImageHeight) And (D.Pass<3) Do Begin
    Inc(D.Pass); D.Row:=Starts[D.Pass];
   End;
  End;
 End;
End;

Procedure GFLZW(Var D: TGFState; Minimum: Integer);
Var ClearCode,EndCode,NextCode,CodeSize,OldCode,Code,InputCode: Integer;
    First,Top,I,Depth: Integer; SawClear,Ended: Boolean;
Begin
 If (Minimum<2) Or (Minimum>8) Then Begin D.Bad:=True; Exit; End;
 ClearCode:=1 Shl Minimum; EndCode:=ClearCode+1; NextCode:=EndCode+1;
 CodeSize:=Minimum+1; OldCode:=-1; First:=0; SawClear:=False; Ended:=False;
 D.BlockLeft:=0; D.BitCount:=0; D.BitBuffer:=0;
 D.Row:=0; D.Column:=0; D.Pass:=0; D.Produced:=0;
 Repeat
  Code:=GFCode(D,CodeSize); If D.Bad Then Exit;
  If Code=ClearCode Then Begin
   CodeSize:=Minimum+1; NextCode:=EndCode+1; OldCode:=-1; SawClear:=True;
  End Else If Code=EndCode Then Begin Ended:=True; Break; End
  Else Begin
   If Not SawClear Then Begin D.Bad:=True; Exit; End;
   InputCode:=Code; Top:=0;
   If OldCode<0 Then Begin
    If Code>=ClearCode Then Begin D.Bad:=True; Exit; End;
    First:=Code; GFEmit(D,Code); OldCode:=Code;
   End Else Begin
    If Code>=NextCode Then Begin
     If (Code<>NextCode) Or (NextCode>=4096) Then Begin D.Bad:=True; Exit; End;
     D.Stack[Top]:=First; Inc(Top); Code:=OldCode;
    End;
    Depth:=0;
    While Code>=ClearCode Do Begin
     If (Code<=EndCode) Or (Code>=NextCode) Or (Code>=4096) Or
        (Top>=4096) Or (Depth>=4096) Then Begin D.Bad:=True; Exit; End;
     D.Stack[Top]:=D.Suffix[Code]; Inc(Top);
     { Toute entree ne peut referencer qu'une entree plus ancienne. }
     I:=D.Prefix[Code]; If I>=Code Then Begin D.Bad:=True; Exit; End;
     Code:=I; Inc(Depth);
    End;
    First:=Code; D.Stack[Top]:=First; Inc(Top);
    For I:=Top-1 DownTo 0 Do Begin GFEmit(D,D.Stack[I]); If D.Bad Then Exit; End;
    If NextCode<4096 Then Begin
     D.Prefix[NextCode]:=OldCode; D.Suffix[NextCode]:=First; Inc(NextCode);
     If (NextCode=(1 Shl CodeSize)) And (CodeSize<12) Then Inc(CodeSize);
    End;
    OldCode:=InputCode;
   End;
  End;
 Until D.Bad;
 If Not Ended Or (D.Produced<>D.FrameSize) Then Begin D.Bad:=True; Exit; End;
 { EOI peut preceder la fin du dernier sous-bloc. Consommer le remplissage
   puis le terminateur, sans le confondre avec un marqueur du conteneur. }
 If D.BlockLeft>D.Size-D.Position Then Begin D.Bad:=True; Exit; End;
 Inc(D.Position,D.BlockLeft); D.BlockLeft:=0;
 GFSkipBlocks(D);
End;

Procedure GFReadControl(Var D: TGFState);
Var Flags,Index: Integer;
Begin
 If GFByte(D)<>4 Then Begin D.Bad:=True; Exit; End;
 Flags:=GFByte(D); GFWord(D); Index:=GFByte(D);
 If GFByte(D)<>0 Then D.Bad:=True;
 If (Flags And $E0)<>0 Then D.Bad:=True;
 D.Transparent:=(Flags And 1)<>0; D.TransparentIndex:=Index;
End;

Procedure GFReadFrame(Var D: TGFState);
Var Left,Top,W,H,Flags,Minimum,LocalCount: Integer;
Begin
 Left:=GFWord(D); Top:=GFWord(D); W:=GFWord(D); H:=GFWord(D); Flags:=GFByte(D);
 If D.Bad Then Exit;
 If (W<1) Or (H<1) Or (Left<0) Or (Top<0) Or
    (LongInt(Left)+W>D.Width) Or (LongInt(Top)+H>D.Height) Or
    ((Flags And $18)<>0) Then Begin D.Bad:=True; Exit; End;
 LocalCount:=0; If (Flags And $80)<>0 Then LocalCount:=1 Shl ((Flags And 7)+1);
 If D.HaveImage Then Begin
  { PAINT edite une image fixe : conserver la premiere trame, mais verifier
    les bornes des trames suivantes et la terminaison du conteneur. }
  If LocalCount>0 Then Begin
   If D.Size-D.Position<LocalCount*3 Then Begin D.Bad:=True; Exit; End;
   Inc(D.Position,LocalCount*3);
  End;
  Minimum:=GFByte(D); If (Minimum<2) Or (Minimum>8) Then Begin D.Bad:=True; Exit; End;
  GFSkipBlocks(D); Exit;
 End;
 D.ImageLeft:=Left; D.ImageTop:=Top; D.ImageWidth:=W; D.ImageHeight:=H;
 D.Interlaced:=(Flags And $40)<>0;
 If LocalCount>0 Then Begin
  D.ColorCount:=LocalCount; GFReadPalette(D,D.Colors,LocalCount);
 End Else If D.HaveGlobal Then Begin
  D.ColorCount:=D.GlobalCount; D.Colors:=D.GlobalPalette;
 End Else Begin D.Bad:=True; Exit; End;
 If D.Bad Then Exit;
 If D.Transparent And (D.TransparentIndex>=D.ColorCount) Then Begin D.Bad:=True; Exit; End;
 D.FrameSize:=LongInt(W)*H; D.Frame:=PGFBytes(JDAllocate(D.FrameSize));
 If D.Frame=Nil Then Begin D.Bad:=True; Exit; End;
 Minimum:=GFByte(D); GFLZW(D,Minimum);
 If Not D.Bad Then D.HaveImage:=True;
End;

Procedure GFComment(Var D: TGFState);
Var N,I,B: Integer;
Begin
 If D.Metadata.Values[5]<>'' Then PMByte(D.Metadata,5,10);
 Repeat
  N:=GFByte(D); If D.Bad Or (N=0) Then Exit;
  For I:=1 To N Do Begin B:=GFByte(D); If D.Bad Then Exit; PMByte(D.Metadata,5,B); End;
 Until D.Bad;
End;

Function GFDecode(Const FileName: String; Var D: PGFState): Boolean;
Var F: File; Bytes: LongInt; OldMode: Byte; I,Flags,BlockType,LabelID: Integer;
    Signature: String; Ended: Boolean;
Begin
 GFDecode:=False;
 D:=PGFState(JDAllocate(SizeOf(TGFState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0); Ended:=False;
 Assign(F,FileName); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode;
 If IOResult<>0 Then Begin D^.Bad:=True; Exit; End;
 {$I-}
 D^.Size:=FileSize(F);
 If (D^.Size>=14) And (D^.Size<=134217728) Then Begin
  D^.Data:=PGFBytes(JDAllocate(D^.Size));
  If D^.Data<>Nil Then Begin BlockRead(F,D^.Data^,D^.Size,Bytes); D^.Bad:=Bytes<>D^.Size; End
  Else D^.Bad:=True;
 End Else D^.Bad:=True;
 Close(F);
 {$I+}
 If IOResult<>0 Then D^.Bad:=True;
 If D^.Bad Then Exit;
 Signature:=''; For I:=1 To 6 Do Signature:=Signature+Chr(GFByte(D^));
 If (Signature<>PnGIF87_SIGNATURE) And (Signature<>PnGIF89_SIGNATURE) Then Begin D^.Bad:=True; Exit; End;
 D^.Width:=GFWord(D^); D^.Height:=GFWord(D^);
 If (D^.Width<1) Or (D^.Height<1) Or (D^.Width>PnMAX_IMAGE_WIDTH) Or
    (D^.Height>PnMAX_IMAGE_HEIGHT) Then Begin D^.Bad:=True; Exit; End;
 Flags:=GFByte(D^); D^.BackgroundIndex:=GFByte(D^); GFByte(D^);
 D^.HaveGlobal:=(Flags And $80)<>0;
 If D^.HaveGlobal Then Begin
  D^.GlobalCount:=1 Shl ((Flags And 7)+1);
  GFReadPalette(D^,D^.GlobalPalette,D^.GlobalCount);
  If D^.BackgroundIndex>=D^.GlobalCount Then Begin D^.Bad:=True; Exit; End;
  D^.Background:=D^.GlobalPalette[D^.BackgroundIndex];
 End Else Begin D^.Background.R:=255; D^.Background.G:=255; D^.Background.B:=255; D^.Background.A:=255; End;
 While Not D^.Bad And Not Ended Do Begin
  BlockType:=GFByte(D^);
  Case BlockType Of
   $2C: GFReadFrame(D^);
   $3B: Ended:=True;
   $21: Begin
    LabelID:=GFByte(D^);
    If LabelID=$FE Then GFComment(D^)
    Else If (LabelID=$F9) And Not D^.HaveImage Then GFReadControl(D^)
    Else Begin
     GFSkipBlocks(D^);
     { Le controle graphique ne s'applique qu'au prochain rendu. }
     If (LabelID=$01) And Not D^.HaveImage Then D^.Transparent:=False;
    End;
   End;
   Else D^.Bad:=True;
  End;
 End;
 GFDecode:=Not D^.Bad And Ended And D^.HaveImage;
End;

Procedure GFFree(D: PGFState);
Begin
 If D=Nil Then Exit;
 If D^.Frame<>Nil Then FreeMem(D^.Frame,D^.FrameSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TGFState));
End;

Function GFDistance(Const A,B: PnTRGBColor): LongInt;
Var R,G,Blue: LongInt;
Begin
 R:=LongInt(A.R)-B.R; G:=LongInt(A.G)-B.G; Blue:=LongInt(A.B)-B.B;
 GFDistance:=R*R+G*G+Blue*Blue;
End;

Procedure GFMakePalette(Var D: TGFState; Var Palette: PnTPalette;
                        Var Map: Array Of Byte; Var BackgroundSlot: Byte);
Const
 R: Array[0..15] Of Byte = (0,0,0,0,168,168,168,168,84,84,84,84,252,252,252,252);
 G: Array[0..15] Of Byte = (0,0,168,168,0,0,84,168,84,84,252,252,84,84,252,252);
 B: Array[0..15] Of Byte = (0,168,0,168,0,168,0,168,84,252,84,252,84,252,84,252);
Var Counts: Array[0..256] Of LongInt; Done: Array[0..256] Of Boolean;
    I,J,N,Best,Slot,Used: Integer; K,Weight,Dist,BestDist: LongInt; C: PnTRGBColor;
Begin
 FillChar(Counts,SizeOf(Counts),0); FillChar(Done,SizeOf(Done),0);
 FillChar(Palette,SizeOf(Palette),0);
 For I:=0 To 15 Do Begin Palette[I].R:=R[I]; Palette[I].G:=G[I]; Palette[I].B:=B[I]; Palette[I].A:=255; End;
 Used:=16;
 If D.Transparent Then Begin
  { Le canvas indexe de PAINT ne possede pas de canal alpha par pixel.
    Les zones transparentes sont composees sur blanc a l'importation. }
  D.Background.R:=255; D.Background.G:=255; D.Background.B:=255; D.Background.A:=0;
 End;
 Counts[256]:=LongInt(D.Width)*D.Height-D.FrameSize;
 For K:=0 To D.FrameSize-1 Do Begin
  I:=D.Frame^[K];
  If D.Transparent And (I=D.TransparentIndex) Then Inc(Counts[256]) Else Inc(Counts[I]);
 End;
 { Choisir les couleurs utilisees par frequence. Les couleurs exactes sont
   conservees tant que les 240 registres disponibles suffisent. }
 BackgroundSlot:=White;
 For N:=0 To D.ColorCount Do Begin
  Best:=-1; Weight:=-1;
  For I:=0 To D.ColorCount-1 Do If Not Done[I] And (Counts[I]>Weight) Then Begin Best:=I; Weight:=Counts[I]; End;
  If Not Done[256] And (Counts[256]>Weight) Then Best:=256;
  If Best<0 Then Break;
  Done[Best]:=True;
  If Best=256 Then C:=D.Background Else C:=D.Colors[Best];
  Slot:=0; BestDist:=MaxLongInt;
  For J:=0 To Used-1 Do Begin
   Dist:=GFDistance(C,Palette[J]); If Dist<BestDist Then Begin BestDist:=Dist; Slot:=J; End;
  End;
  If (BestDist<>0) And (Used<256) Then Begin
   Slot:=Used; Palette[Slot]:=C; Palette[Slot].A:=255; Inc(Used);
  End;
  If Best=256 Then BackgroundSlot:=Slot Else Map[Best]:=Slot;
 End;
End;

Function LoadGIF(FileName: String): Boolean;
Var D: PGFState; Pixels: PGFBytes; Palette: PnTPalette; Map: Array[0..255] Of Byte;
    BackgroundSlot: Byte; X,Y,I,Index: Integer; Dest,Source,Size: LongInt;
Begin
 LoadGIF:=False; D:=Nil; Pixels:=Nil;
 If Not GFDecode(FileName,D) Then Begin GFFree(D); Exit; End;
 Size:=LongInt(D^.Width)*D^.Height; Pixels:=PGFBytes(JDAllocate(Size));
 If Pixels<>Nil Then Begin
  GFMakePalette(D^,Palette,Map,BackgroundSlot); FillChar(Pixels^,Size,BackgroundSlot);
  For Y:=0 To D^.ImageHeight-1 Do Begin
   Source:=LongInt(Y)*D^.ImageWidth;
   Dest:=LongInt(Y+D^.ImageTop)*D^.Width+D^.ImageLeft;
   For X:=0 To D^.ImageWidth-1 Do Begin
    Index:=D^.Frame^[Source+X];
    If Not D^.Transparent Or (Index<>D^.TransparentIndex) Then Pixels^[Dest+X]:=Map[Index];
   End;
  End;
  { Commit uniquement apres la lecture et la decompression completes. }
  If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
  PnCanvasImage:=PByte(Pixels); Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
  PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
  PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_GIF; PnImageBuffer.BitDepth:=8;
  PnImageBuffer.HasTransparency:=D^.Transparent; PnImageBuffer.TransparentColor:=D^.Background;
  PnImageBuffer.Modified:=False; PnImageBuffer.Palette:=Palette; PnImageBuffer.Metadata:=D^.Metadata;
  For I:=0 To 255 Do Begin
   {$IFDEF FPC}ImgNoPal(I,Palette[I].R,Palette[I].G,Palette[I].B);
   {$ELSE}ImgNoPal(I,Palette[I].R Shr 2,Palette[I].G Shr 2,Palette[I].B Shr 2);{$ENDIF}
  End;
  LoadGIF:=True;
 End;
 If Pixels<>Nil Then FreeMem(Pixels,Size);
 GFFree(D);
End;


{ PNG integre : conteneur et CRC-32, zlib/Adler-32, DEFLATE (RFC 1950/1951),
  cinq filtres PNG, types 0/2/3/4/6, echantillons 1/2/4/8/16 bits et Adam7.
  Aucun appel a zlib, aucune unite image, aucune bibliotheque externe.
  Les buffers temporaires sont bornes par les dimensions du document. }
Type
 TPNBytes = Array[0..150994943] Of Byte;
 PPNBytes = ^TPNBytes;
 TPNHuffman = Record
  Counts: Array[0..15] Of Integer;
  Symbols: Array[0..287] Of Integer;
  Total: Integer;
 End;
 TPNState = Record
  FileData,Compressed,Raw,RGB: PPNBytes;
  FileSize,CompressedSize,RawSize,RGBSize,Position: LongInt;
  Width,Height,Depth,ColorType,Channels,Interlace,PaletteCount: Integer;
  APCanvasW,APCanvasH,APX,APY: Integer;
  Metadata: PnTPaintMetadata;
  AllowShort: Boolean;
  Palette: PnTPalette;
  Alpha: Array[0..255] Of Byte;
  Transparent: Array[0..2] Of LongInt;
  HasTRNS,HasTransparency,Bad: Boolean;
  CRC: Array[0..255] Of LongWord;
  InputPosition,InputLimit,OutputPosition: LongInt;
  BitBuffer: LongInt;
  BitCount: Integer;
  Lit,Dist,Code: TPNHuffman;
 End;
 PPNState = ^TPNState;

Function PNBE(P: PPNBytes; Offset: LongInt): LongWord;
Begin
 PNBE:=(LongWord(P^[Offset]) Shl 24) Or (LongWord(P^[Offset+1]) Shl 16) Or
       (LongWord(P^[Offset+2]) Shl 8) Or P^[Offset+3];
End;

Procedure PNInitCRC(Var D: TPNState);
Var I,J: Integer; C: LongWord;
Begin
 For I:=0 To 255 Do Begin
  C:=I;
  For J:=1 To 8 Do If (C And 1)<>0 Then C:=(C Shr 1) Xor $EDB88320 Else C:=C Shr 1;
  D.CRC[I]:=C;
 End;
End;

Function PNCRC(Var D: TPNState; Start,Count: LongInt): LongWord;
Var C: LongWord; I: LongInt;
Begin
 C:=$FFFFFFFF;
 For I:=Start To Start+Count-1 Do C:=D.CRC[(C Xor D.FileData^[I]) And 255] Xor (C Shr 8);
 PNCRC:=C Xor $FFFFFFFF;
End;

Function PNPassSize(Size,Start,Step: Integer): LongInt;
Begin
 If Size<=Start Then PNPassSize:=0 Else PNPassSize:=(LongInt(Size)-Start+Step-1) Div Step;
End;

Function PNExpected(Var D: TPNState): LongInt;
Const XStart: Array[0..6] Of Byte = (0,4,0,2,0,1,0);
      YStart: Array[0..6] Of Byte = (0,0,4,0,2,0,1);
      XStep: Array[0..6] Of Byte = (8,8,4,4,2,2,1);
      YStep: Array[0..6] Of Byte = (8,8,8,4,4,2,2);
Var P: Integer; W,H,Total,Row: LongInt;
Begin
 Total:=0;
 If D.Interlace=0 Then Total:=((LongInt(D.Width)*D.Channels*D.Depth+7) Div 8+1)*D.Height
 Else For P:=0 To 6 Do Begin
  W:=PNPassSize(D.Width,XStart[P],XStep[P]); H:=PNPassSize(D.Height,YStart[P],YStep[P]);
  If (W>0) And (H>0) Then Begin Row:=(W*D.Channels*D.Depth+7) Div 8; Inc(Total,(Row+1)*H); End;
 End;
 PNExpected:=Total;
End;

Function PNInflate(Var D: TPNState): Boolean; Forward;

Procedure PNTextMetadata(Var D: TPNState; Const Kind: String; Start,Count: LongInt);
Var P,Stop,TextStart,TextSize,I,Index,Flag,Method,B,C,Code,N: LongInt;
    Key: String; Z: PPNState; Buffer: PPNBytes; UTF8,Compressed: Boolean;
Begin
 P:=Start; Stop:=Start+Count; Key:='';
 While (P<Stop) And (D.FileData^[P]<>0) Do Begin
  If Length(Key)>=79 Then Exit; Key:=Key+Chr(D.FileData^[P]); Inc(P);
 End;
 Index:=PMIndex(Key); If (Index<0) Or (P>=Stop) Then Exit;
 Inc(P); UTF8:=Kind='iTXt'; Compressed:=Kind='zTXt';
 If UTF8 Then Begin
  If Stop-P<2 Then Begin D.Metadata.Limited:=True; Exit; End;
  Flag:=D.FileData^[P]; Method:=D.FileData^[P+1]; Inc(P,2);
  If (Flag>1) Or (Method<>0) Then Begin D.Metadata.Limited:=True; Exit; End;
  Compressed:=Flag=1;
  For I:=1 To 2 Do Begin
   While (P<Stop) And (D.FileData^[P]<>0) Do Inc(P);
   If P=Stop Then Begin D.Metadata.Limited:=True; Exit; End; Inc(P);
  End;
 End Else If Compressed Then Begin
  If (P>=Stop) Or (D.FileData^[P]<>0) Then Begin D.Metadata.Limited:=True; Exit; End; Inc(P);
 End;
 Z:=Nil; Buffer:=D.FileData; TextStart:=P; TextSize:=Stop-P;
 If Compressed Then Begin
  Z:=PPNState(JDAllocate(SizeOf(TPNState))); If Z=Nil Then Begin D.Metadata.Limited:=True; Exit; End;
  FillChar(Z^,SizeOf(Z^),0); Z^.Compressed:=PPNBytes(@D.FileData^[P]); Z^.CompressedSize:=Stop-P;
  Z^.RawSize:=65536; Z^.Raw:=PPNBytes(JDAllocate(65536)); Z^.AllowShort:=True;
  If Z^.Raw=Nil Then Begin FreeMem(Z,SizeOf(TPNState)); D.Metadata.Limited:=True; Exit; End;
  If Not PNInflate(Z^) Then Begin
   FreeMem(Z^.Raw,65536); FreeMem(Z,SizeOf(TPNState)); D.Metadata.Limited:=True; Exit;
  End;
  Buffer:=Z^.Raw; TextStart:=0; TextSize:=Z^.OutputPosition;
 End;
 { Champs Latin-1, 255 octets. Les textes non representables sont signales,
   et leur remplacement requiert une confirmation dans Proprietes. }
 If D.Metadata.Values[Index]<>'' Then D.Metadata.Limited:=True;
 D.Metadata.Values[Index]:=''; P:=TextStart; Stop:=TextStart+TextSize;
 While P<Stop Do Begin
  B:=Buffer^[P]; Inc(P); Code:=B;
  If UTF8 And (B>=128) Then Begin
   N:=0;
   If (B>=194) And (B<=223) Then Begin N:=1; Code:=B And 31; End
   Else If (B>=224) And (B<=239) Then Begin N:=2; Code:=B And 15; End
   Else If (B>=240) And (B<=244) Then Begin N:=3; Code:=B And 7; End;
   If (N=0) Or (Stop-P<N) Then Begin Code:=63; D.Metadata.Limited:=True; End
   Else For I:=1 To N Do Begin
    C:=Buffer^[P]; Inc(P);
    If (C And 192)<>128 Then Begin D.Metadata.Limited:=True; Code:=256; End
    Else Code:=Code*64+(C And 63);
   End;
   If Code>255 Then Begin Code:=63; D.Metadata.Limited:=True; End;
  End;
  If Code=0 Then Begin Code:=32; D.Metadata.Limited:=True; End;
  PMByte(D.Metadata,Index,Code);
 End;
 If Z<>Nil Then Begin FreeMem(Z^.Raw,65536); FreeMem(Z,SizeOf(TPNState)); End;
End;

Function PNParseChunks(Var D: TPNState): Boolean;
Var Start,Length,ChunkEnd,I: LongInt; Kind: String; N: LongWord;
    HaveHeader,HavePalette,HaveData,PastData,Ended: Boolean;
Begin
 PNParseChunks:=False;
 If (D.FileData=Nil) Or (D.FileSize<45) Then Exit;
 HaveHeader:=False; HavePalette:=False;
 HaveData:=False; PastData:=False; Ended:=False;
 For I:=0 To 7 Do If D.FileData^[I]<>PnPNG_SIGNATURE[I] Then Exit;
 D.Compressed:=PPNBytes(JDAllocate(D.FileSize)); If D.Compressed=Nil Then Exit;
 PNInitCRC(D); D.Position:=8;
 While (D.Position<D.FileSize) And Not Ended Do Begin
  If D.FileSize-D.Position<12 Then Exit;
  N:=PNBE(D.FileData,D.Position); If N>LongWord(D.FileSize-D.Position-12) Then Exit;
  Length:=LongInt(N); Start:=D.Position+8; ChunkEnd:=Start+Length;
  Kind:='';
  For I:=D.Position+4 To D.Position+7 Do Begin
   If Not (D.FileData^[I] In [Ord('A')..Ord('Z'),Ord('a')..Ord('z')]) Then Exit;
   Kind:=Kind+Chr(D.FileData^[I]);
  End;
  If (Ord(Kind[3]) And 32)<>0 Then Exit;
  If PNCRC(D,D.Position+4,Length+4)<>PNBE(D.FileData,ChunkEnd) Then Exit;
  If Not HaveHeader And (Kind<>'IHDR') Then Exit;
  If HaveData And (Kind<>'IDAT') Then PastData:=True;
  If Kind='IHDR' Then Begin
   If HaveHeader Or (Length<>13) Then Exit;
   N:=PNBE(D.FileData,Start); If (N=0) Or (N>PnMAX_IMAGE_WIDTH) Then Exit; D.Width:=N;
   N:=PNBE(D.FileData,Start+4); If (N=0) Or (N>PnMAX_IMAGE_HEIGHT) Then Exit; D.Height:=N;
   D.Depth:=D.FileData^[Start+8]; D.ColorType:=D.FileData^[Start+9];
   D.Interlace:=D.FileData^[Start+12];
   If (D.FileData^[Start+10]<>0) Or (D.FileData^[Start+11]<>0) Or (D.Interlace>1) Then Exit;
   Case D.ColorType Of
    0: Begin D.Channels:=1; If Not (D.Depth In [1,2,4,8,16]) Then Exit; End;
    2: Begin D.Channels:=3; If Not (D.Depth In [8,16]) Then Exit; End;
    3: Begin D.Channels:=1; If Not (D.Depth In [1,2,4,8]) Then Exit; End;
    4: Begin D.Channels:=2; If Not (D.Depth In [8,16]) Then Exit; End;
    6: Begin D.Channels:=4; If Not (D.Depth In [8,16]) Then Exit; End;
    Else Exit;
   End;
   HaveHeader:=True;
  End Else If Kind='PLTE' Then Begin
   If HavePalette Or HaveData Or D.HasTRNS Or (Length=0) Or (Length>768) Or
      ((Length Mod 3)<>0) Or (D.ColorType In [0,4]) Then Exit;
   D.PaletteCount:=Length Div 3;
   If (D.ColorType=3) And (D.PaletteCount>(1 Shl D.Depth)) Then Exit;
   For I:=0 To D.PaletteCount-1 Do Begin
    D.Palette[I].R:=D.FileData^[Start+I*3]; D.Palette[I].G:=D.FileData^[Start+I*3+1];
    D.Palette[I].B:=D.FileData^[Start+I*3+2]; D.Palette[I].A:=255;
   End;
   HavePalette:=True;
  End Else If Kind='tRNS' Then Begin
   If D.HasTRNS Or HaveData Then Exit;
   Case D.ColorType Of
    0: Begin
     If Length<>2 Then Exit;
     D.Transparent[0]:=LongInt(D.FileData^[Start])*256+D.FileData^[Start+1];
    End;
    2: Begin
     If Length<>6 Then Exit;
     For I:=0 To 2 Do D.Transparent[I]:=LongInt(D.FileData^[Start+I*2])*256+D.FileData^[Start+I*2+1];
    End;
    3: Begin
     If Not HavePalette Or (Length<1) Or (Length>D.PaletteCount) Then Exit;
     For I:=0 To Length-1 Do D.Alpha[I]:=D.FileData^[Start+I];
    End;
    Else Exit;
   End;
   D.HasTRNS:=True;
  End Else If (Kind='tEXt') Or (Kind='zTXt') Or (Kind='iTXt') Then Begin
   PNTextMetadata(D,Kind,Start,Length);
  End Else If Kind='IDAT' Then Begin
   If PastData Or ((D.ColorType=3) And Not HavePalette) Then Exit;
   If Length>D.FileSize-D.CompressedSize Then Exit;
   If Length>0 Then Move(D.FileData^[Start],D.Compressed^[D.CompressedSize],Length);
   Inc(D.CompressedSize,Length); HaveData:=True;
  End Else If Kind='IEND' Then Begin
   If (Length<>0) Or Not HaveData Or (ChunkEnd+4<>D.FileSize) Then Exit;
   Ended:=True;
  End Else If (Ord(Kind[1]) And 32)=0 Then Exit; { Type critique inconnu. }
  D.Position:=ChunkEnd+4;
 End;
 If Not Ended Or (D.CompressedSize<6) Then Exit;
 D.RawSize:=PNExpected(D);
 If (D.RawSize<1) Or (D.RawSize>150994944) Then Exit;
 D.Raw:=PPNBytes(JDAllocate(D.RawSize));
 PNParseChunks:=D.Raw<>Nil;
End;

Function PNReadChunks(Const Name: String; Var D: TPNState): Boolean;
Var F: File; OldMode: Byte; Bytes: LongInt;
Begin
 PNReadChunks:=False;
 Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode;
 If IOResult<>0 Then Exit;
 {$I-}
 D.FileSize:=FileSize(F);
 If (D.FileSize>=45) And (D.FileSize<=134217728) Then Begin
  D.FileData:=PPNBytes(JDAllocate(D.FileSize));
  If D.FileData<>Nil Then Begin BlockRead(F,D.FileData^,D.FileSize,Bytes); D.Bad:=Bytes<>D.FileSize; End
  Else D.Bad:=True;
 End Else D.Bad:=True;
 Close(F);
 {$I+}
 If IOResult<>0 Then D.Bad:=True;
 If D.Bad Then Exit;
 PNReadChunks:=PNParseChunks(D);
End;

Function APReadChunks(Const Name: String; Var D: TPNState): Boolean;
Var P,Start,Length,N,Frames,Expected,Sequence,FW,FH,FX,FY: LongInt;
    Kind: String; I: Integer; V: LongWord;
    Control,HaveIDAT,FrameData,DefaultFrame,FirstDefault: Boolean;
Begin
 APReadChunks:=False;
 If Not PNReadChunks(Name,D) Then Exit;
 D.APCanvasW:=D.Width; D.APCanvasH:=D.Height;
 P:=8; Frames:=0; Expected:=0; Sequence:=0;
 FW:=0; FH:=0; FX:=0; FY:=0;
 Control:=False; HaveIDAT:=False; FrameData:=False; DefaultFrame:=False; FirstDefault:=False;
 While P<D.FileSize Do Begin
  { Les bornes et CRC de chaque bloc ont deja ete verifies par PNReadChunks. }
  Length:=PNBE(D.FileData,P); Start:=P+8;
  Kind:=''; For I:=0 To 3 Do Kind:=Kind+Chr(D.FileData^[P+4+I]);
  If Kind='acTL' Then Begin
   If Control Or HaveIDAT Or (Length<>8) Then Exit;
   V:=PNBE(D.FileData,Start); If (V=0) Or (V>10000) Then Exit;
   Expected:=V; Control:=True;
  End Else If Kind='fcTL' Then Begin
   If Not Control Or (Length<>26) Then Exit;
   If (Frames>0) And Not FrameData Then Exit;
   If PNBE(D.FileData,Start)<>LongWord(Sequence) Then Exit; Inc(Sequence);
   V:=PNBE(D.FileData,Start+4); If (V=0) Or (V>LongWord(D.APCanvasW)) Then Exit; N:=V;
   V:=PNBE(D.FileData,Start+8); If (V=0) Or (V>LongWord(D.APCanvasH)) Then Exit;
   If PNBE(D.FileData,Start+12)>LongWord(D.APCanvasW-N) Then Exit;
   If PNBE(D.FileData,Start+16)>LongWord(D.APCanvasH-LongInt(V)) Then Exit;
   If (D.FileData^[Start+24]>2) Or (D.FileData^[Start+25]>1) Then Exit;
   Inc(Frames); If Frames>Expected Then Exit;
   DefaultFrame:=Not HaveIDAT; FrameData:=False;
   If DefaultFrame Then Begin
    If (Frames<>1) Or (N<>D.APCanvasW) Or (V<>LongWord(D.APCanvasH)) Or
       (PNBE(D.FileData,Start+12)<>0) Or (PNBE(D.FileData,Start+16)<>0) Then Exit;
   End;
   If Frames=1 Then Begin
    FW:=N; FH:=V; FX:=PNBE(D.FileData,Start+12); FY:=PNBE(D.FileData,Start+16);
    FirstDefault:=DefaultFrame;
    If Not FirstDefault Then D.CompressedSize:=0;
   End;
  End Else If Kind='IDAT' Then Begin
   HaveIDAT:=True;
   If (Frames>0) And Not DefaultFrame Then Exit;
   If DefaultFrame And (Length>0) Then FrameData:=True;
  End Else If Kind='fdAT' Then Begin
   If Not Control Or Not HaveIDAT Or (Frames=0) Or DefaultFrame Or (Length<4) Then Exit;
   If PNBE(D.FileData,Start)<>LongWord(Sequence) Then Exit; Inc(Sequence);
   If Length>4 Then FrameData:=True;
   If (Frames=1) And Not FirstDefault Then Begin
    If Length-4>D.FileSize-D.CompressedSize Then Exit;
    If Length>4 Then Move(D.FileData^[Start+4],D.Compressed^[D.CompressedSize],Length-4);
    Inc(D.CompressedSize,Length-4);
   End;
  End;
  Inc(P,Length+12);
 End;
 If Not Control Or (Frames<>Expected) Or Not FrameData Or (D.CompressedSize<6) Then Exit;
 D.APX:=FX; D.APY:=FY; D.Width:=FW; D.Height:=FH;
 If D.Raw<>Nil Then Begin FreeMem(D.Raw,D.RawSize); D.Raw:=Nil; End;
 D.RawSize:=PNExpected(D); If (D.RawSize<1) Or (D.RawSize>150994944) Then Exit;
 D.Raw:=PPNBytes(JDAllocate(D.RawSize)); APReadChunks:=D.Raw<>Nil;
End;

Function APExpand(Var D: TPNState): Boolean;
Var Buffer: PPNBytes; Size,P: LongInt; Y: Integer;
Begin
 APExpand:=False;
 If (D.Width=D.APCanvasW) And (D.Height=D.APCanvasH) Then Begin APExpand:=True; Exit; End;
 Size:=LongInt(D.APCanvasW)*D.APCanvasH*3;
 Buffer:=PPNBytes(JDAllocate(Size)); If Buffer=Nil Then Exit;
 FillChar(Buffer^,Size,255);
 For Y:=0 To D.Height-1 Do Begin
  P:=(LongInt(Y+D.APY)*D.APCanvasW+D.APX)*3;
  Move(D.RGB^[LongInt(Y)*D.Width*3],Buffer^[P],LongInt(D.Width)*3);
 End;
 FreeMem(D.RGB,D.RGBSize); D.RGB:=Buffer; D.RGBSize:=Size;
 D.Width:=D.APCanvasW; D.Height:=D.APCanvasH; D.HasTransparency:=True;
 APExpand:=True;
End;

Function PNBits(Var D: TPNState; Count: Integer): LongInt;
Begin
 PNBits:=0;
 If D.Bad Or (Count<0) Or (Count>16) Then Begin D.Bad:=True; Exit; End;
 While D.BitCount<Count Do Begin
  If D.InputPosition>=D.InputLimit Then Begin D.Bad:=True; Exit; End;
  D.BitBuffer:=D.BitBuffer Or (LongInt(D.Compressed^[D.InputPosition]) Shl D.BitCount);
  Inc(D.InputPosition); Inc(D.BitCount,8);
 End;
 PNBits:=D.BitBuffer And ((LongInt(1) Shl Count)-1);
 D.BitBuffer:=D.BitBuffer Shr Count; Dec(D.BitCount,Count);
End;

Function PNBuildTree(Var T: TPNHuffman; Const Lengths: Array Of Integer;
                     Count: Integer; AllowEmpty: Boolean): Boolean;
Var I,N: Integer; Left: LongInt; Offset: Array[0..15] Of Integer;
Begin
 PNBuildTree:=False; FillChar(T,SizeOf(T),0);
 For I:=0 To Count-1 Do Begin
  N:=Lengths[I]; If (N<0) Or (N>15) Then Exit;
  If N>0 Then Begin Inc(T.Counts[N]); Inc(T.Total); End;
 End;
 If T.Total=0 Then Begin PNBuildTree:=AllowEmpty; Exit; End;
 Left:=1; Offset[0]:=0; Offset[1]:=0;
 For N:=1 To 15 Do Begin
  Left:=Left*2-T.Counts[N]; If Left<0 Then Exit;
  If N<15 Then Offset[N+1]:=Offset[N]+T.Counts[N];
 End;
 If (Left>0) And Not ((T.Total=1) And (T.Counts[1]=1)) Then Exit;
 For I:=0 To Count-1 Do Begin
  N:=Lengths[I];
  If N>0 Then Begin T.Symbols[Offset[N]]:=I; Inc(Offset[N]); End;
 End;
 PNBuildTree:=True;
End;

Function PNDecodeSymbol(Var D: TPNState; Const T: TPNHuffman): Integer;
Var Length,Index: Integer; Code,First,Count: LongInt;
Begin
 PNDecodeSymbol:=0; Code:=0; First:=0; Index:=0;
 If T.Total=0 Then Begin D.Bad:=True; Exit; End;
 For Length:=1 To 15 Do Begin
  Code:=Code Or PNBits(D,1); If D.Bad Then Exit;
  Count:=T.Counts[Length];
  If (Code>=First) And (Code-First<Count) Then Begin
   PNDecodeSymbol:=T.Symbols[Index+Code-First]; Exit;
  End;
  Inc(Index,Count); First:=(First+Count)*2; Code:=Code*2;
 End;
 D.Bad:=True;
End;

Procedure PNFixedTrees(Var D: TPNState);
Var L: Array[0..287] Of Integer; I: Integer;
Begin
 For I:=0 To 143 Do L[I]:=8;
 For I:=144 To 255 Do L[I]:=9;
 For I:=256 To 279 Do L[I]:=7;
 For I:=280 To 287 Do L[I]:=8;
 If Not PNBuildTree(D.Lit,L,288,False) Then D.Bad:=True;
 For I:=0 To 31 Do L[I]:=5;
 If Not PNBuildTree(D.Dist,L,32,False) Then D.Bad:=True;
End;

Procedure PNDynamicTrees(Var D: TPNState);
Const Order: Array[0..18] Of Byte = (16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);
Var CL: Array[0..18] Of Integer; L: Array[0..319] Of Integer;
    DistLengths: Array[0..31] Of Integer;
    HLIT,HDIST,HCLEN,I,N,Symbol,RepeatCount,Value: Integer;
Begin
 HLIT:=PNBits(D,5)+257; HDIST:=PNBits(D,5)+1; HCLEN:=PNBits(D,4)+4;
 If D.Bad Or (HLIT>286) Then Begin D.Bad:=True; Exit; End;
 FillChar(CL,SizeOf(CL),0);
 For I:=0 To HCLEN-1 Do CL[Order[I]]:=PNBits(D,3);
 If Not PNBuildTree(D.Code,CL,19,False) Then Begin D.Bad:=True; Exit; End;
 I:=0; N:=HLIT+HDIST;
 While (I<N) And Not D.Bad Do Begin
  Symbol:=PNDecodeSymbol(D,D.Code);
  If Symbol<=15 Then Begin L[I]:=Symbol; Inc(I); End
  Else Begin
   Value:=0;
   Case Symbol Of
    16: Begin
     If I=0 Then Begin D.Bad:=True; Exit; End;
     Value:=L[I-1]; RepeatCount:=PNBits(D,2)+3;
    End;
    17: RepeatCount:=PNBits(D,3)+3;
    18: RepeatCount:=PNBits(D,7)+11;
    Else Begin D.Bad:=True; Exit; End;
   End;
   If RepeatCount>N-I Then Begin D.Bad:=True; Exit; End;
   While RepeatCount>0 Do Begin L[I]:=Value; Inc(I); Dec(RepeatCount); End;
  End;
 End;
 If D.Bad Or (L[256]=0) Then Begin D.Bad:=True; Exit; End;
 If Not PNBuildTree(D.Lit,L,HLIT,False) Then Begin D.Bad:=True; Exit; End;
 For I:=0 To HDIST-1 Do DistLengths[I]:=L[HLIT+I];
 If Not PNBuildTree(D.Dist,DistLengths,HDIST,True) Then D.Bad:=True;
End;

Procedure PNInflateCodes(Var D: TPNState);
Const LengthBase: Array[0..28] Of Integer =
  (3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258);
 LengthExtra: Array[0..28] Of Byte =
  (0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DistanceBase: Array[0..29] Of LongInt =
  (1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577);
 DistanceExtra: Array[0..29] Of Byte =
  (0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13);
Var Symbol,N,I: Integer; Length,Distance: LongInt;
Begin
 Repeat
  Symbol:=PNDecodeSymbol(D,D.Lit); If D.Bad Then Exit;
  If Symbol<256 Then Begin
   If D.OutputPosition>=D.RawSize Then Begin D.Bad:=True; Exit; End;
   D.Raw^[D.OutputPosition]:=Symbol; Inc(D.OutputPosition);
  End Else If Symbol=256 Then Exit
  Else Begin
   If Symbol>285 Then Begin D.Bad:=True; Exit; End;
   N:=Symbol-257; Length:=LengthBase[N]+PNBits(D,LengthExtra[N]);
   Symbol:=PNDecodeSymbol(D,D.Dist); If D.Bad Then Exit;
   If Symbol>29 Then Begin D.Bad:=True; Exit; End;
   Distance:=DistanceBase[Symbol]+PNBits(D,DistanceExtra[Symbol]);
   If D.Bad Or (Distance>D.OutputPosition) Or (Length>D.RawSize-D.OutputPosition) Then Begin D.Bad:=True; Exit; End;
   For I:=1 To Length Do Begin
    D.Raw^[D.OutputPosition]:=D.Raw^[D.OutputPosition-Distance]; Inc(D.OutputPosition);
   End;
  End;
 Until D.Bad;
End;

Function PNInflate(Var D: TPNState): Boolean;
Var CMF,FLG,FinalBlock,BlockType: Integer; N,InverseN,I: LongInt; A,B: LongWord;
Begin
 PNInflate:=False; CMF:=D.Compressed^[0]; FLG:=D.Compressed^[1];
 If ((CMF And 15)<>8) Or ((CMF Shr 4)>7) Or (((LongInt(CMF)*256+FLG) Mod 31)<>0) Or
    ((FLG And 32)<>0) Then Exit;
 D.InputPosition:=2; D.InputLimit:=D.CompressedSize-4;
 Repeat
  FinalBlock:=PNBits(D,1); BlockType:=PNBits(D,2);
  If D.Bad Then Exit;
  Case BlockType Of
   0: Begin
    D.BitCount:=0; D.BitBuffer:=0;
    N:=PNBits(D,16); InverseN:=PNBits(D,16);
    If D.Bad Or ((N Xor InverseN)<>65535) Or (N>D.RawSize-D.OutputPosition) Or
       (N>D.InputLimit-D.InputPosition) Then Exit;
    If N>0 Then Move(D.Compressed^[D.InputPosition],D.Raw^[D.OutputPosition],N);
    Inc(D.InputPosition,N); Inc(D.OutputPosition,N);
   End;
   1: Begin PNFixedTrees(D); If Not D.Bad Then PNInflateCodes(D); End;
   2: Begin PNDynamicTrees(D); If Not D.Bad Then PNInflateCodes(D); End;
   Else Exit;
  End;
  If D.Bad Then Exit;
 Until FinalBlock<>0;
 If ((D.OutputPosition<>D.RawSize) And Not D.AllowShort) Or (D.InputPosition<>D.InputLimit) Then Exit;
 A:=1; B:=0;
 For I:=0 To D.OutputPosition-1 Do Begin
  A:=(A+D.Raw^[I]) Mod 65521; B:=(B+A) Mod 65521;
 End;
 PNInflate:=((B Shl 16) Or A)=PNBE(D.Compressed,D.CompressedSize-4);
End;

Function PNPaeth(A,B,C: Integer): Integer;
Var P,DA,DB,DC: Integer;
Begin
 P:=A+B-C; DA:=Abs(P-A); DB:=Abs(P-B); DC:=Abs(P-C);
 If (DA<=DB) And (DA<=DC) Then PNPaeth:=A Else If DB<=DC Then PNPaeth:=B Else PNPaeth:=C;
End;

Function PNSample(Var D: TPNState; Row,Sample: LongInt): LongInt;
Var Offset,Shift: LongInt;
Begin
 If D.Depth=8 Then PNSample:=D.Raw^[Row+Sample]
 Else If D.Depth=16 Then Begin
  Offset:=Row+Sample*2; PNSample:=LongInt(D.Raw^[Offset])*256+D.Raw^[Offset+1];
 End Else Begin
  Offset:=Row+(Sample*D.Depth Div 8); Shift:=8-D.Depth-(Sample*D.Depth Mod 8);
  PNSample:=(D.Raw^[Offset] Shr Shift) And ((1 Shl D.Depth)-1);
 End;
End;

Function PNReconstruct(Var D: TPNState): Boolean;
Const XS: Array[0..6] Of Byte = (0,4,0,2,0,1,0);
 YS: Array[0..6] Of Byte = (0,0,4,0,2,0,1);
 DX: Array[0..6] Of Byte = (8,8,4,4,2,2,1);
 DY: Array[0..6] Of Byte = (8,8,8,4,4,2,2);
Var Pass,LastPass,StartX,StartY,StepX,StepY,Filter,BPP,A,B,C,Pred: Integer;
    W,H,RowBytes,Position,Previous,Row,X,Y,I,Dest,Sample,MaxSample: LongInt;
    R,G,Blue,Alpha,Value: LongInt;
Begin
 PNReconstruct:=False; D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 Position:=0; LastPass:=0; If D.Interlace=1 Then LastPass:=6;
 BPP:=(D.Channels*D.Depth+7) Div 8; If BPP<1 Then BPP:=1;
 MaxSample:=(LongInt(1) Shl D.Depth)-1;
 For Pass:=0 To LastPass Do Begin
  If D.Interlace=0 Then Begin StartX:=0; StartY:=0; StepX:=1; StepY:=1; End
  Else Begin StartX:=XS[Pass]; StartY:=YS[Pass]; StepX:=DX[Pass]; StepY:=DY[Pass]; End;
  W:=PNPassSize(D.Width,StartX,StepX); H:=PNPassSize(D.Height,StartY,StepY);
  If (W>0) And (H>0) Then Begin
   RowBytes:=(W*D.Channels*D.Depth+7) Div 8; Previous:=-1;
   For Y:=0 To H-1 Do Begin
    If D.RawSize-Position<RowBytes+1 Then Exit;
    Filter:=D.Raw^[Position]; Inc(Position); Row:=Position;
    If Filter>4 Then Exit;
    For I:=0 To RowBytes-1 Do Begin
     A:=0; B:=0; C:=0;
     If I>=BPP Then A:=D.Raw^[Row+I-BPP];
     If Previous>=0 Then Begin
      B:=D.Raw^[Previous+I]; If I>=BPP Then C:=D.Raw^[Previous+I-BPP];
     End;
     Case Filter Of
      0: Pred:=0;
      1: Pred:=A;
      2: Pred:=B;
      3: Pred:=(A+B) Div 2;
      Else Pred:=PNPaeth(A,B,C);
     End;
     D.Raw^[Row+I]:=(Integer(D.Raw^[Row+I])+Pred) And 255;
    End;
    For X:=0 To W-1 Do Begin
     Sample:=X*D.Channels; Value:=PNSample(D,Row,Sample); R:=Value; G:=Value; Blue:=Value; Alpha:=MaxSample;
     Case D.ColorType Of
      0: If D.HasTRNS And (Value=D.Transparent[0]) Then Alpha:=0;
      2,6: Begin
       G:=PNSample(D,Row,Sample+1); Blue:=PNSample(D,Row,Sample+2);
       If D.ColorType=6 Then Alpha:=PNSample(D,Row,Sample+3)
       Else If D.HasTRNS And (R=D.Transparent[0]) And (G=D.Transparent[1]) And (Blue=D.Transparent[2]) Then Alpha:=0;
      End;
      3: Begin
       If Value>=D.PaletteCount Then Exit;
       R:=D.Palette[Value].R; G:=D.Palette[Value].G; Blue:=D.Palette[Value].B; Alpha:=D.Alpha[Value];
      End;
      4: Alpha:=PNSample(D,Row,Sample+1);
     End;
     If D.ColorType<>3 Then Begin
      R:=(R*255+MaxSample Div 2) Div MaxSample; G:=(G*255+MaxSample Div 2) Div MaxSample;
      Blue:=(Blue*255+MaxSample Div 2) Div MaxSample; Alpha:=(Alpha*255+MaxSample Div 2) Div MaxSample;
     End;
     If Alpha<255 Then Begin
      D.HasTransparency:=True;
      { Le canvas indexe est opaque : composer l'alpha sur fond blanc. }
      R:=(R*Alpha+255*(255-Alpha)+127) Div 255;
      G:=(G*Alpha+255*(255-Alpha)+127) Div 255;
      Blue:=(Blue*Alpha+255*(255-Alpha)+127) Div 255;
     End;
     Dest:=((LongInt(StartY)+Y*StepY)*D.Width+StartX+X*StepX)*3;
     D.RGB^[Dest]:=R; D.RGB^[Dest+1]:=G; D.RGB^[Dest+2]:=Blue;
    End;
    Previous:=Row; Inc(Position,RowBytes);
   End;
  End;
 End;
 PNReconstruct:=Position=D.RawSize;
End;

Procedure PNFree(D: PPNState);
Begin
 If D=Nil Then Exit;
 If D^.FileData<>Nil Then FreeMem(D^.FileData,D^.FileSize);
 If D^.Compressed<>Nil Then FreeMem(D^.Compressed,D^.FileSize);
 If D^.Raw<>Nil Then FreeMem(D^.Raw,D^.RawSize);
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 FreeMem(D,SizeOf(TPNState));
End;


{ Decodeur JPEG integre. Structure du flux et decodage Huffman selon
  ITU-T T.81, annexes B, C, F et G (JPEG sequentiel et progressif 8 bits).
  Aucune unite image, bibliotheque externe ou API Windows n'est utilisee.
  Les marqueurs, tables, indices et allocations sont controles avant acces. }
Const
 JDZigZag: Array[0..63] Of Byte =
  (0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,
   12,19,26,33,40,48,41,34,27,20,13,6,7,14,21,28,
   35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,
   58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63);
Type
 TJDBytes = Array[0..134217727] Of Byte;
 PJDBytes = ^TJDBytes;
 TJDInts = Array[0..16777215] Of LongInt;
 PJDInts = ^TJDInts;
 TJDImage = Record
  Width,Height: Integer;
  Pixels: PByte; { Triplets R,V,B ; resultat temporaire avant quantification. }
 End;
 TJDHuffman = Record
  Ready: Boolean;
  MinCode,MaxCode,ValueOffset: Array[1..16] Of LongInt;
  Symbols: Array[0..255] Of Byte;
 End;
 TJDComponent = Record
  ID,H,V,TQ,TD,TA: Integer;
  BlockWidth,BlockHeight,RealWidth,RealHeight: LongInt;
  CoefCount,PlaneSize: LongInt;
  Predictor: LongInt;
  Coefficients: PJDInts;
  Plane: PJDBytes;
  Quant: Array[0..63] Of Word;
  Progress: Array[0..63] Of ShortInt;
  QuantReady: Boolean;
 End;
 TJDState = Record
  Data: PJDBytes;
  Size,Position: LongInt;
  Bad,FrameFound,ScanFound,Progressive,Adobe: Boolean;
  Width,Height,Components,MaxH,MaxV,MCUWidth,MCUHeight: Integer;
  AdobeTransform: Integer;
  RestartInterval: LongInt;
  BitsLeft,BitByte: Integer;
  EOBRun: LongInt;
  Quant: Array[0..3,0..63] Of Word;
  QuantReady: Array[0..3] Of Boolean;
  Huffman: Array[0..1,0..3] Of TJDHuffman;
  Component: Array[0..3] Of TJDComponent;
  Basis: Array[0..7,0..7] Of Double;
 End;
 PJDState = ^TJDState;

Function JDAllocate(Size: LongInt): Pointer;
Var P: Pointer;
 {$IFDEF FPC}Previous: Boolean;{$ENDIF}
Begin
 P:=Nil;
 If Size>0 Then Begin
  {$IFDEF FPC}
  Previous:=ReturnNilIfGrowHeapFails; ReturnNilIfGrowHeapFails:=True;
  GetMem(P,Size); ReturnNilIfGrowHeapFails:=Previous;
  {$ELSE}
  If MaxAvail>=Size Then GetMem(P,Size);
  {$ENDIF}
 End;
 JDAllocate:=P;
End;

Function JDByte(Var D: TJDState): Integer;
Begin
 JDByte:=0;
 If D.Bad Then Exit;
 If D.Position>=D.Size Then Begin D.Bad:=True; Exit; End;
 JDByte:=D.Data^[D.Position]; Inc(D.Position);
End;

Function JDWord(Var D: TJDState): LongInt;
Var A: Integer;
Begin
 A:=JDByte(D); JDWord:=LongInt(A)*256+JDByte(D);
End;

Function JDMarker(Var D: TJDState): Integer;
Var M: Integer;
Begin
 JDMarker:=0;
 If JDByte(D)<>255 Then Begin D.Bad:=True; Exit; End;
 Repeat M:=JDByte(D); Until (M<>255) Or D.Bad;
 If M=0 Then D.Bad:=True;
 JDMarker:=M;
End;

Function JDBits(Var D: TJDState; Count: Integer): LongInt;
Var I,B: Integer; V: LongInt;
Begin
 V:=0;
 If (Count<0) Or (Count>16) Then Begin D.Bad:=True; JDBits:=0; Exit; End;
 For I:=1 To Count Do Begin
  If D.BitsLeft=0 Then Begin
   B:=JDByte(D);
   If B=255 Then If JDByte(D)<>0 Then D.Bad:=True;
   D.BitByte:=B; D.BitsLeft:=8;
  End;
  Dec(D.BitsLeft); V:=V*2+((D.BitByte Shr D.BitsLeft) And 1);
 End;
 JDBits:=V;
End;

Function JDExtend(Var D: TJDState; Count: Integer): LongInt;
Var V: LongInt;
Begin
 If Count=0 Then Begin JDExtend:=0; Exit; End;
 V:=JDBits(D,Count);
 If V<(LongInt(1) Shl (Count-1)) Then V:=V-(LongInt(1) Shl Count)+1;
 JDExtend:=V;
End;

Function JDHuff(Var D: TJDState; Kind,Table: Integer): Integer;
Var N: Integer; Code,Index: LongInt;
Begin
 JDHuff:=0;
 If Not D.Huffman[Kind,Table].Ready Then Begin D.Bad:=True; Exit; End;
 Code:=0;
 For N:=1 To 16 Do Begin
  Code:=Code*2+JDBits(D,1);
  With D.Huffman[Kind,Table] Do
   If (MaxCode[N]>=0) And (Code>=MinCode[N]) And (Code<=MaxCode[N]) Then Begin
    Index:=Code+ValueOffset[N];
    If (Index<0) Or (Index>255) Then D.Bad:=True
    Else JDHuff:=Symbols[Index];
    Exit;
   End;
  If D.Bad Then Exit;
 End;
 D.Bad:=True;
End;

Procedure JDReadQuant(Var D: TJDState; Limit: LongInt);
Var Spec,Precision,Table,I,V: Integer;
Begin
 While (D.Position<Limit) And Not D.Bad Do Begin
  Spec:=JDByte(D); Precision:=Spec Shr 4; Table:=Spec And 15;
  If (Precision>1) Or (Table>3) Or (Limit-D.Position<64*(Precision+1)) Then Begin D.Bad:=True; Exit; End;
  For I:=0 To 63 Do Begin
   If Precision=0 Then V:=JDByte(D) Else V:=JDWord(D);
   If V=0 Then D.Bad:=True;
   D.Quant[Table,JDZigZag[I]]:=V;
  End;
  D.QuantReady[Table]:=True;
 End;
End;

Procedure JDReadHuffman(Var D: TJDState; Limit: LongInt);
Var Spec,Kind,Table,N,I,Total: Integer; Code: LongInt;
    Counts: Array[1..16] Of Byte;
Begin
 While (D.Position<Limit) And Not D.Bad Do Begin
  Spec:=JDByte(D); Kind:=Spec Shr 4; Table:=Spec And 15;
  If (Kind>1) Or (Table>3) Or (Limit-D.Position<16) Then Begin D.Bad:=True; Exit; End;
  Total:=0;
  For N:=1 To 16 Do Begin Counts[N]:=JDByte(D); Inc(Total,Counts[N]); End;
  If (Total=0) Or (Total>256) Or (Total>Limit-D.Position) Then Begin D.Bad:=True; Exit; End;
  Code:=0; I:=0;
  With D.Huffman[Kind,Table] Do Begin
   For N:=1 To 16 Do Begin
    MinCode[N]:=Code; MaxCode[N]:=-1; ValueOffset[N]:=I-Code;
    If Counts[N]>0 Then Begin
     MaxCode[N]:=Code+Counts[N]-1;
     If MaxCode[N]>=(LongInt(1) Shl N)-1 Then Begin D.Bad:=True; Exit; End;
    End;
    Inc(Code,Counts[N]); Inc(I,Counts[N]); Code:=Code*2;
   End;
   For I:=0 To Total-1 Do Begin
    Spec:=JDByte(D); Symbols[I]:=Spec;
    If (Kind=0) And (Spec>11) Then D.Bad:=True;
   End;
   Ready:=True;
  End;
 End;
End;

Procedure JDReadFrame(Var D: TJDState; Marker: Integer; Limit: LongInt);
Var I,J,Spec,Blocks: Integer;
Begin
 If D.FrameFound Or (Limit-D.Position<6) Then Begin D.Bad:=True; Exit; End;
 If JDByte(D)<>8 Then Begin D.Bad:=True; Exit; End;
 D.Height:=JDWord(D); D.Width:=JDWord(D); D.Components:=JDByte(D);
 If (D.Width<1) Or (D.Height<1) Or (D.Width>PnMAX_IMAGE_WIDTH) Or
    (D.Height>PnMAX_IMAGE_HEIGHT) Or Not (D.Components In [1,3,4]) Or
    (Limit-D.Position<>D.Components*3) Then Begin D.Bad:=True; Exit; End;
 D.Progressive:=Marker=$C2; D.MaxH:=1; D.MaxV:=1; Blocks:=0;
 For I:=0 To D.Components-1 Do With D.Component[I] Do Begin
  ID:=JDByte(D); Spec:=JDByte(D); H:=Spec Shr 4; V:=Spec And 15; TQ:=JDByte(D);
  If (H<1) Or (H>4) Or (V<1) Or (V>4) Or (TQ>3) Then Begin D.Bad:=True; Exit; End;
  For J:=0 To I-1 Do If ID=D.Component[J].ID Then Begin D.Bad:=True; Exit; End;
  Inc(Blocks,H*V); D.MaxH:=PnMax(D.MaxH,H); D.MaxV:=PnMax(D.MaxV,V);
  FillChar(Progress,SizeOf(Progress),255);
 End;
 If Blocks>10 Then Begin D.Bad:=True; Exit; End;
 D.MCUWidth:=(D.Width+8*D.MaxH-1) Div (8*D.MaxH);
 D.MCUHeight:=(D.Height+8*D.MaxV-1) Div (8*D.MaxV);
 For I:=0 To D.Components-1 Do With D.Component[I] Do Begin
  BlockWidth:=LongInt(D.MCUWidth)*H; BlockHeight:=LongInt(D.MCUHeight)*V;
  RealWidth:=(LongInt(D.Width)*H+D.MaxH-1) Div D.MaxH;
  RealHeight:=(LongInt(D.Height)*V+D.MaxV-1) Div D.MaxV;
  CoefCount:=BlockWidth*BlockHeight*64;
  If (CoefCount<1) Or (CoefCount>16777216) Then Begin D.Bad:=True; Exit; End;
  Coefficients:=PJDInts(JDAllocate(CoefCount*SizeOf(LongInt)));
  If Coefficients=Nil Then Begin D.Bad:=True; Exit; End;
  FillChar(Coefficients^,CoefCount*SizeOf(LongInt),0);
 End;
 D.FrameFound:=True;
End;

Procedure JDRefineValue(Var D: TJDState; Var V: LongInt; BitValue: LongInt);
Begin
 If JDBits(D,1)<>0 Then If (Abs(V) And BitValue)=0 Then Begin
  If V>=0 Then Inc(V,BitValue) Else Dec(V,BitValue);
 End;
End;

Procedure JDDecodeBlock(Var D: TJDState; C: Integer; Block: LongInt;
                        SS,SE,AH,AL: Integer);
Var K,R,S,Symbol: Integer; Base,P1,NewValue,CoefIndex: LongInt; P: PJDInts;
Begin
 If D.Bad Then Exit;
 With D.Component[C] Do Begin
  Base:=Block*64; P:=Coefficients;
  If (Base<0) Or (Base>CoefCount-64) Then Begin D.Bad:=True; Exit; End;
  P1:=LongInt(1) Shl AL;
  If SS=0 Then Begin
   If AH=0 Then Begin
    S:=JDHuff(D,0,TD); If (S>11) Or D.Bad Then Begin D.Bad:=True; Exit; End;
    Predictor:=Predictor+JDExtend(D,S);
    If Abs(Predictor)>32767 Then Begin D.Bad:=True; Exit; End;
    P^[Base]:=Predictor*P1;
   End Else If JDBits(D,1)<>0 Then P^[Base]:=P^[Base] Or P1;
  End;
  K:=SS; If K=0 Then K:=1;
  If K>SE Then Exit;
  If AH=0 Then Begin
   If D.EOBRun>0 Then Begin Dec(D.EOBRun); Exit; End;
   While (K<=SE) And Not D.Bad Do Begin
    Symbol:=JDHuff(D,1,TA); R:=Symbol Shr 4; S:=Symbol And 15;
    If S=0 Then Begin
     If R=15 Then Begin Inc(K,16); If K>SE+1 Then D.Bad:=True; End
     Else Begin
      If Not D.Progressive And (R<>0) Then Begin D.Bad:=True; Exit; End;
      D.EOBRun:=(LongInt(1) Shl R)+JDBits(D,R)-1; Exit;
     End;
    End Else Begin
     If S>10 Then Begin D.Bad:=True; Exit; End;
     Inc(K,R); If K>SE Then Begin D.Bad:=True; Exit; End;
     P^[Base+JDZigZag[K]]:=JDExtend(D,S)*P1; Inc(K);
    End;
   End;
  End Else Begin
   { Scans AC de raffinement : les bits des coefficients deja presents
     sont entrelaces avec les nouvelles valeurs et les suites de zeros. }
   If D.EOBRun=0 Then Begin
    While (K<=SE) And Not D.Bad Do Begin
     Symbol:=JDHuff(D,1,TA); R:=Symbol Shr 4; S:=Symbol And 15; NewValue:=0;
     If S<>0 Then Begin
      If S<>1 Then Begin D.Bad:=True; Exit; End;
      If JDBits(D,1)<>0 Then NewValue:=P1 Else NewValue:=-P1;
     End Else If R<>15 Then Begin
      D.EOBRun:=(LongInt(1) Shl R)+JDBits(D,R); Break;
     End Else R:=16;
     While (K<=SE) And Not D.Bad Do Begin
      CoefIndex:=Base+JDZigZag[K];
      If P^[CoefIndex]<>0 Then JDRefineValue(D,P^[CoefIndex],P1)
      Else Begin
       If R=0 Then Break;
       Dec(R);
       { ZRL termine exactement apres le seizieme zero. Les bits de
         raffinement suivants appartiennent au prochain symbole. }
       If (R=0) And (NewValue=0) Then Begin Inc(K); Break; End;
      End;
      Inc(K);
     End;
     If R<>0 Then Begin D.Bad:=True; Exit; End;
     If NewValue<>0 Then Begin
      If K>SE Then Begin D.Bad:=True; Exit; End;
      P^[Base+JDZigZag[K]]:=NewValue; Inc(K);
     End;
    End;
   End;
   If D.EOBRun>0 Then Begin
    While (K<=SE) And Not D.Bad Do Begin
     CoefIndex:=Base+JDZigZag[K];
     If P^[CoefIndex]<>0 Then JDRefineValue(D,P^[CoefIndex],P1);
     Inc(K);
    End;
    Dec(D.EOBRun);
   End;
  End;
 End;
End;

Procedure JDReadScan(Var D: TJDState; Limit: LongInt);
Var NS,I,J,C,ID,Spec,SS,SE,AH,AL,BX,BY,HX,VY,Restart,Marker: Integer;
    Order: Array[0..3] Of Integer; Found: Boolean;
    Total,MCU,Across,Down,Block: LongInt;
Begin
 FillChar(Order,SizeOf(Order),0);
 If Not D.FrameFound Then Begin D.Bad:=True; Exit; End;
 NS:=JDByte(D);
 If (NS<1) Or (NS>D.Components) Or (Limit-D.Position<>NS*2+3) Then Begin D.Bad:=True; Exit; End;
 For I:=0 To NS-1 Do Begin
  ID:=JDByte(D); Spec:=JDByte(D); Found:=False; C:=0;
  For J:=0 To D.Components-1 Do If D.Component[J].ID=ID Then Begin C:=J; Found:=True; End;
  If Not Found Or ((Spec Shr 4)>3) Or ((Spec And 15)>3) Then Begin D.Bad:=True; Exit; End;
  For J:=0 To I-1 Do If Order[J]=C Then Begin D.Bad:=True; Exit; End;
  Order[I]:=C; D.Component[C].TD:=Spec Shr 4; D.Component[C].TA:=Spec And 15;
 End;
 SS:=JDByte(D); SE:=JDByte(D); Spec:=JDByte(D); AH:=Spec Shr 4; AL:=Spec And 15;
 If (SS>SE) Or (SE>63) Or (AH>13) Or (AL>13) Then Begin D.Bad:=True; Exit; End;
 If D.Progressive Then Begin
  If ((SS=0) And (SE<>0)) Or ((SS>0) And (NS<>1)) Or
     ((AH<>0) And (AH<>AL+1)) Then Begin D.Bad:=True; Exit; End;
 End Else If (SS<>0) Or (SE<>63) Or (AH<>0) Or (AL<>0) Then Begin D.Bad:=True; Exit; End;
 For I:=0 To NS-1 Do With D.Component[Order[I]] Do Begin
  If Not D.QuantReady[TQ] Then Begin D.Bad:=True; Exit; End;
  If Not QuantReady Then Begin Move(D.Quant[TQ],Quant,SizeOf(Quant)); QuantReady:=True; End;
  For J:=SS To SE Do Begin
   If ((AH=0) And (Progress[J]<>-1)) Or ((AH<>0) And (Progress[J]<>AH)) Then Begin D.Bad:=True; Exit; End;
   Progress[J]:=AL;
  End;
 End;
 D.BitsLeft:=0; D.EOBRun:=0; Restart:=0;
 For I:=0 To D.Components-1 Do D.Component[I].Predictor:=0;
 If NS=1 Then Begin
  C:=Order[0]; Across:=(D.Component[C].RealWidth+7) Div 8;
  Down:=(D.Component[C].RealHeight+7) Div 8;
 End Else Begin Across:=D.MCUWidth; Down:=D.MCUHeight; End;
 Total:=Across*Down;
 For MCU:=0 To Total-1 Do Begin
  If (MCU>0) And (D.RestartInterval>0) And ((MCU Mod D.RestartInterval)=0) Then Begin
   If D.EOBRun<>0 Then Begin D.Bad:=True; Exit; End;
   D.BitsLeft:=0; Marker:=JDMarker(D);
   If Marker<>$D0+Restart Then Begin D.Bad:=True; Exit; End;
   Restart:=(Restart+1) And 7;
   For I:=0 To D.Components-1 Do D.Component[I].Predictor:=0;
  End;
  BX:=MCU Mod Across; BY:=MCU Div Across;
  For I:=0 To NS-1 Do Begin
   C:=Order[I];
   If NS=1 Then Begin
    Block:=LongInt(BY)*D.Component[C].BlockWidth+BX;
    JDDecodeBlock(D,C,Block,SS,SE,AH,AL);
   End Else With D.Component[C] Do Begin
    For VY:=0 To V-1 Do For HX:=0 To H-1 Do Begin
     Block:=(LongInt(BY)*V+VY)*BlockWidth+LongInt(BX)*H+HX;
     JDDecodeBlock(D,C,Block,SS,SE,AH,AL);
    End;
   End;
   If D.Bad Then Exit;
  End;
 End;
 If D.EOBRun<>0 Then D.Bad:=True;
 D.BitsLeft:=0; D.ScanFound:=True;
End;

Function JDClamp(V: LongInt): Byte;
Begin
 If V<0 Then JDClamp:=0 Else If V>255 Then JDClamp:=255 Else JDClamp:=V;
End;

Procedure JDInverseDCT(Var D: TJDState; C: Integer);
Var X,Y,IU,IV,I: Integer; BX,BY,Base,Dest,Stride: LongInt;
    Temp: Array[0..7,0..7] Of Double; Sum: Double; OnlyDC: Boolean;
Begin
 With D.Component[C] Do Begin
  Stride:=BlockWidth*8; PlaneSize:=Stride*BlockHeight*8;
  Plane:=PJDBytes(JDAllocate(PlaneSize));
  If Plane=Nil Then Begin D.Bad:=True; Exit; End;
  For BY:=0 To BlockHeight-1 Do For BX:=0 To BlockWidth-1 Do Begin
   Base:=(BY*BlockWidth+BX)*64;
   OnlyDC:=True;
   For I:=1 To 63 Do If Coefficients^[Base+I]<>0 Then Begin OnlyDC:=False; Break; End;
   If OnlyDC Then Begin
    I:=JDClamp(Round((1.0*Coefficients^[Base])*Quant[0]/8)+128);
    For Y:=0 To 7 Do Begin
     Dest:=(BY*8+Y)*Stride+BX*8;
     For X:=0 To 7 Do Plane^[Dest+X]:=I;
    End;
   End Else Begin
    { DCT inverse separable : 2 passes de 8x8x8, base calculee une fois. }
    For IV:=0 To 7 Do For X:=0 To 7 Do Begin
     Sum:=0;
     For IU:=0 To 7 Do Sum:=Sum+(1.0*Coefficients^[Base+IV*8+IU])*Quant[IV*8+IU]*D.Basis[X,IU];
     Temp[IV,X]:=Sum;
    End;
    For Y:=0 To 7 Do For X:=0 To 7 Do Begin
     Sum:=0; For IV:=0 To 7 Do Sum:=Sum+Temp[IV,X]*D.Basis[Y,IV];
     Dest:=(BY*8+Y)*Stride+BX*8+X;
     Plane^[Dest]:=JDClamp(Round(Sum/4)+128);
    End;
   End;
  End;
 End;
End;

Function JDMin(A,B: LongInt): LongInt;
Begin If A<B Then JDMin:=A Else JDMin:=B; End;
Function JDMax(A,B: LongInt): LongInt;
Begin If A>B Then JDMax:=A Else JDMax:=B; End;

Function JDSample(Var D: TJDState; C,X,Y: Integer): Integer;
Var FX,FY,AX,AY,X0,Y0,X1,Y1: LongInt; Stride: LongInt;
Begin
 With D.Component[C] Do Begin
  { Interpolation bilineaire centree des chrominances sous-echantillonnees.
    Les indices sont limites a la partie reelle du plan, pas au remplissage MCU. }
  FX:=((LongInt(X)*2+1)*H*128) Div D.MaxH-128;
  FY:=((LongInt(Y)*2+1)*V*128) Div D.MaxV-128;
  FX:=JDMax(0,JDMin(FX,(RealWidth-1)*256)); FY:=JDMax(0,JDMin(FY,(RealHeight-1)*256));
  X0:=FX Div 256; Y0:=FY Div 256; AX:=FX And 255; AY:=FY And 255;
  X1:=JDMin(X0+1,RealWidth-1); Y1:=JDMin(Y0+1,RealHeight-1); Stride:=BlockWidth*8;
  JDSample:=(LongInt(Plane^[Y0*Stride+X0])*(256-AX)*(256-AY)+
             LongInt(Plane^[Y0*Stride+X1])*AX*(256-AY)+
             LongInt(Plane^[Y1*Stride+X0])*(256-AX)*AY+
             LongInt(Plane^[Y1*Stride+X1])*AX*AY+32768) Div 65536;
 End;
End;

Procedure JDCompose(Var D: TJDState; Var Img: TJDImage);
Var X,Y,I,U,V,A,B,C,K,R,G,Blue: Integer; P: PByte; DirectRGB: Boolean;
Begin
 For X:=0 To 7 Do For U:=0 To 7 Do Begin
  D.Basis[X,U]:=Cos((2*X+1)*U*Pi/16);
  If U=0 Then D.Basis[X,U]:=D.Basis[X,U]/Sqrt(2);
 End;
 For I:=0 To D.Components-1 Do Begin
  If Not D.Component[I].QuantReady Or (D.Component[I].Progress[0]<0) Then Begin D.Bad:=True; Exit; End;
  JDInverseDCT(D,I); If D.Bad Then Exit;
 End;
 Img.Width:=D.Width; Img.Height:=D.Height;
 Img.Pixels:=PByte(JDAllocate(LongInt(D.Width)*D.Height*3));
 If Img.Pixels=Nil Then Begin D.Bad:=True; Exit; End;
 DirectRGB:=(D.Components=3) And
  ((D.Adobe And (D.AdobeTransform=0)) Or
   ((D.Component[0].ID=Ord('R')) And (D.Component[1].ID=Ord('G')) And (D.Component[2].ID=Ord('B'))));
 P:=Img.Pixels;
 For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do Begin
  A:=JDSample(D,0,X,Y); R:=A; G:=A; Blue:=A;
  If D.Components>=3 Then Begin
   B:=JDSample(D,1,X,Y); C:=JDSample(D,2,X,Y);
   If DirectRGB Or ((D.Components=4) And (Not D.Adobe Or (D.AdobeTransform=0))) Then Begin
    R:=A; G:=B; Blue:=C;
   End Else Begin
    U:=B-128; V:=C-128;
    R:=JDClamp(A+Round(1.402*V)); G:=JDClamp(A-Round(0.344136*U+0.714136*V));
    Blue:=JDClamp(A+Round(1.772*U));
   End;
   If D.Components=4 Then Begin
    K:=JDSample(D,3,X,Y);
    If D.Adobe Then Begin
     If D.AdobeTransform=2 Then Begin R:=255-R; G:=255-G; Blue:=255-Blue; End;
     R:=(LongInt(R)*K+127) Div 255; G:=(LongInt(G)*K+127) Div 255;
     Blue:=(LongInt(Blue)*K+127) Div 255;
    End Else Begin
     R:=(LongInt(255-R)*(255-K)+127) Div 255; G:=(LongInt(255-G)*(255-K)+127) Div 255;
     Blue:=(LongInt(255-Blue)*(255-K)+127) Div 255;
    End;
   End;
  End;
  P^:=JDClamp(R); Inc(P); P^:=JDClamp(G); Inc(P); P^:=JDClamp(Blue); Inc(P);
 End;
End;

Function JDDecode(Const FileName: String; Var Img: TJDImage): Boolean;
Var D: PJDState; F: File; Bytes: LongInt; M,I: Integer; L,Limit: LongInt;
    Ended: Boolean; OldFileMode: Byte;
Begin
 JDDecode:=False; FillChar(Img,SizeOf(Img),0);
 D:=PJDState(JDAllocate(SizeOf(TJDState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0); D^.AdobeTransform:=-1; Ended:=False;
 Assign(F,FileName); OldFileMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}
 FileMode:=OldFileMode;
 If IOResult=0 Then Begin
  {$I-}
  D^.Size:=FileSize(F);
  If (D^.Size>=4) And (D^.Size<=134217728) Then Begin
   D^.Data:=PJDBytes(JDAllocate(D^.Size));
   If D^.Data<>Nil Then Begin BlockRead(F,D^.Data^,D^.Size,Bytes); D^.Bad:=Bytes<>D^.Size; End
   Else D^.Bad:=True;
  End Else D^.Bad:=True;
  Close(F);
  {$I+}
  If IOResult<>0 Then D^.Bad:=True;
 End Else D^.Bad:=True;
 If Not D^.Bad Then If JDMarker(D^)<>$D8 Then D^.Bad:=True;
 While Not D^.Bad And Not Ended Do Begin
  M:=JDMarker(D^);
  If D^.Bad Then Break;
  If M=$D9 Then Begin Ended:=True; Break; End;
  If (M=$D8) Or (M In [$D0..$D7]) Then Begin D^.Bad:=True; Break; End;
  If M<>$01 Then Begin
   L:=JDWord(D^);
   If (L<2) Or (L-2>D^.Size-D^.Position) Then Begin D^.Bad:=True; Break; End;
   Limit:=D^.Position+L-2;
   Case M Of
    $DB: JDReadQuant(D^,Limit);
    $C4: JDReadHuffman(D^,Limit);
    $C0,$C1,$C2: JDReadFrame(D^,M,Limit);
    $DD: Begin
     If L<>4 Then D^.Bad:=True Else D^.RestartInterval:=JDWord(D^);
    End;
    $DA: Begin
     JDReadScan(D^,Limit);
     If D^.Bad Then Break;
     Continue; { Position est maintenant a la fin des donnees entropiques. }
    End;
    $EE: Begin
     If L>=14 Then Begin
      With D^ Do If (Data^[Position]=Ord('A')) And (Data^[Position+1]=Ord('d')) And
       (Data^[Position+2]=Ord('o')) And (Data^[Position+3]=Ord('b')) And (Data^[Position+4]=Ord('e')) Then Begin
        Adobe:=True; AdobeTransform:=Data^[Position+11];
        If AdobeTransform>2 Then Bad:=True;
       End;
     End;
    End;
    $E0..$ED,$EF,$FE: ; { APP/JFIF/EXIF/ICC et commentaires non interpretables sont sautes. }
    Else D^.Bad:=True; { JPEG arithmetique, sans perte ou hierarchique non pris en charge. }
   End;
   D^.Position:=Limit;
  End;
 End;
 If Not D^.Bad And Ended And D^.FrameFound And D^.ScanFound Then JDCompose(D^,Img);
 JDDecode:=Not D^.Bad And Ended And D^.FrameFound And D^.ScanFound And (Img.Pixels<>Nil);
 If D^.Bad And (Img.Pixels<>Nil) Then Begin
  FreeMem(Img.Pixels,LongInt(Img.Width)*Img.Height*3); Img.Pixels:=Nil;
 End;
 For I:=0 To 3 Do With D^.Component[I] Do Begin
  If Coefficients<>Nil Then FreeMem(Coefficients,CoefCount*SizeOf(LongInt));
  If Plane<>Nil Then FreeMem(Plane,PlaneSize);
 End;
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TJDState));
End;

Const
 JPBinCount = 32768;
 JPFirstColor = 16; { Les seize couleurs VGA restent disponibles pour l'UI. }
 PnVGA_R: Array[0..15] of Byte =
   (  0,   0,   0,   0, 168, 168, 168, 168,  84,  84,  84,  84, 252, 252, 252, 252);
 PnVGA_G: Array[0..15] of Byte =
   (  0,   0, 168, 168,   0,   0,  84, 168,  84,  84, 252, 252,  84,  84, 252, 252);
 PnVGA_B: Array[0..15] of Byte =
   (  0, 168,   0, 168,   0, 168,   0, 168,  84, 252,  84, 252,  84, 252,  84, 252);
Type
 TJPBox = Record
  First,Last: LongInt;
  Count: LongInt;
  LowR,HighR,LowG,HighG,LowB,HighB: Byte;
 End;
 TJPQuantizer = Record
  Histogram: Array[0..JPBinCount-1] Of LongInt;
  Bins: Array[0..JPBinCount-1] Of Word;
  Map: Array[0..JPBinCount-1] Of Byte;
  Boxes: Array[0..239] Of TJPBox;
  Palette: PnTPalette;
  Used,BoxCount: LongInt;
 End;
 PJPQuantizer = ^TJPQuantizer;

Function JPBin(R,G,B: Byte): Word;
Begin
 JPBin:=(Word(R Shr 3) Shl 10) Or (Word(G Shr 3) Shl 5) Or (B Shr 3);
End;


{ Remplace la quantification : on conserve une copie RGB pleine qualite. }
Procedure JPBuildPalette(Var Q: TJPQuantizer; Const Img: TJDImage);
Var N: LongInt;
Begin
 If ImgCapRGB<>Nil Then Begin FreeMem(ImgCapRGB,ImgCapSize); ImgCapRGB:=Nil; End;
 ImgCapW:=0; ImgCapH:=0;
 N:=LongInt(Img.Width)*Img.Height*3;
 If (Img.Pixels<>Nil) And (N>0) Then Begin
  ImgCapRGB:=PByte(JDAllocate(N));
  If ImgCapRGB<>Nil Then Begin
   Move(Img.Pixels^,ImgCapRGB^,N); ImgCapSize:=N; ImgCapW:=Img.Width; ImgCapH:=Img.Height;
  End;
 End;
End;

Function LoadJPEG(FileName: String): Boolean;
Var Img: TJDImage; Q: PJPQuantizer; Pixels,Dest,Source: PByte;
    X,Y,I: Integer; R,G,B: Byte;
Begin
 LoadJPEG:=False;
 If Not JDDecode(FileName,Img) Then Exit;
 Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
 Pixels:=PByte(JDAllocate(LongInt(Img.Width)*Img.Height));
 If (Q<>Nil) And (Pixels<>Nil) Then Begin
  JPBuildPalette(Q^,Img); Source:=Img.Pixels; Dest:=Pixels;
  For Y:=0 To Img.Height-1 Do For X:=0 To Img.Width-1 Do Begin
   R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source);
   Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest);
  End;
  { Remplacement atomique : un flux invalide ne modifie ni les pixels,
    ni la palette, ni le nom du document courant. }
  If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
  PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=Img.Width; PnCanvasImageH:=Img.Height;
  PnImageBuffer.Width:=Img.Width; PnImageBuffer.Height:=Img.Height;
  PnImageBuffer.BitDepth:=24; PnImageBuffer.FileName:=FileName;
  PnImageBuffer.Format:=PnFMT_JPEG; PnImageBuffer.HasTransparency:=False;
  PnImageBuffer.Modified:=False; PnImageBuffer.Palette:=Q^.Palette;
  For I:=0 To 255 Do Begin
   {$IFDEF FPC}
   ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
   {$ELSE}
   ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);
   {$ENDIF}
  End;
  LoadJPEG:=True;
 End;
 If Pixels<>Nil Then FreeMem(Pixels,LongInt(Img.Width)*Img.Height);
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 FreeMem(Img.Pixels,LongInt(Img.Width)*Img.Height*3);
End;

Function LoadPNG(FileName: String): Boolean;
Var D: PPNState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadPNG:=False; Pixels:=Nil; Q:=Nil;
 D:=PPNState(JDAllocate(SizeOf(TPNState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0); FillChar(D^.Alpha,SizeOf(D^.Alpha),255);
 If Not PNReadChunks(FileName,D^) Then Begin PNFree(D); Exit; End;
 If Not PNInflate(D^) Then Begin PNFree(D); Exit; End;
 If Not PNReconstruct(D^) Then Begin PNFree(D); Exit; End;
 Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
 Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size));
 If (Q<>Nil) And (Pixels<>Nil) Then Begin
  FillChar(Q^,SizeOf(Q^),0);
  For I:=0 To 15 Do Begin
   Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255;
  End;
  { Conserver les couleurs exactes des captures/elements graphiques PNG.
    La quantification n'intervient que si les registres sont tous occupes. }
  Used:=16; Source:=PByte(D^.RGB); Dest:=Pixels; Exact:=True;
  For N:=0 To Size-1 Do Begin
   R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
   For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
   If Slot<0 Then Begin
    If Used=256 Then Begin Exact:=False; Break; End;
    Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G;
    Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
   End;
   Dest^:=Slot; Inc(Dest);
  End;
  If Not Exact Then Begin
   Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB);
   JPBuildPalette(Q^,Img); Source:=Img.Pixels; Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source);
    Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest);
   End;
  End;
  { Commit : ni la palette ni les pixels du document ne changent en cas
    de CRC invalide, flux tronque, filtre inconnu ou echec d'allocation. }
  If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
  PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
  PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=D^.Depth*D^.Channels;
  PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_PNG; PnImageBuffer.Modified:=False;
  PnImageBuffer.Palette:=Q^.Palette; PnImageBuffer.HasTransparency:=D^.HasTransparency; PnImageBuffer.Metadata:=D^.Metadata;
  PnImageBuffer.TransparentColor.R:=255; PnImageBuffer.TransparentColor.G:=255;
  PnImageBuffer.TransparentColor.B:=255; PnImageBuffer.TransparentColor.A:=0;
  For I:=0 To 255 Do Begin
   {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
   {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
  End;
  LoadPNG:=True;
 End;
 If Pixels<>Nil Then FreeMem(Pixels,Size);
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer)); PNFree(D);
End;


Function LoadAPNG(FileName: String): Boolean;
Var D: PPNState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadAPNG:=False; Pixels:=Nil; Q:=Nil;
 D:=PPNState(JDAllocate(SizeOf(TPNState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0); FillChar(D^.Alpha,SizeOf(D^.Alpha),255);
 If Not APReadChunks(FileName,D^) Then Begin PNFree(D); Exit; End;
 If Not PNInflate(D^) Then Begin PNFree(D); Exit; End;
 If Not PNReconstruct(D^) Then Begin PNFree(D); Exit; End;
 If Not APExpand(D^) Then Begin PNFree(D); Exit; End;
 Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
 Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size));
 If (Q<>Nil) And (Pixels<>Nil) Then Begin
  FillChar(Q^,SizeOf(Q^),0);
  For I:=0 To 15 Do Begin
   Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255;
  End;
  { Conserver les couleurs exactes des captures/elements graphiques PNG.
    La quantification n'intervient que si les registres sont tous occupes. }
  Used:=0; Source:=PByte(D^.RGB); Dest:=Pixels; Exact:=True;
  For N:=0 To Size-1 Do Begin
   R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
   For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
   If Slot<0 Then Begin
    If Used=256 Then Begin Exact:=False; Break; End;
    Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G;
    Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
   End;
   Dest^:=Slot; Inc(Dest);
  End;
  If Not Exact Then Begin
   Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB);
   JPBuildPalette(Q^,Img); Source:=Img.Pixels; Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source);
    Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest);
   End;
  End;
  { Commit : ni la palette ni les pixels du document ne changent en cas
    de CRC invalide, flux tronque, filtre inconnu ou echec d'allocation. }
  If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
  PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
  PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=D^.Depth*D^.Channels;
  PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_APNG; PnImageBuffer.Modified:=False;
  PnImageBuffer.Palette:=Q^.Palette; PnImageBuffer.HasTransparency:=D^.HasTransparency; PnImageBuffer.Metadata:=D^.Metadata;
  PnImageBuffer.TransparentColor.R:=255; PnImageBuffer.TransparentColor.G:=255;
  PnImageBuffer.TransparentColor.B:=255; PnImageBuffer.TransparentColor.A:=0;
  For I:=0 To 255 Do Begin
   {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
   {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
  End;
  LoadAPNG:=True;
 End;
 If Pixels<>Nil Then FreeMem(Pixels,Size);
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer)); PNFree(D);
End;


{ Lecture XBM integree : tableaux C X11 (char), X10 (short), et variante
  RGB 24 bits emise par PPM2XBM.PAS. Le texte n'est jamais execute.
  Les bits monochromes sont lus du poids faible vers le poids fort.
  Les constantes de dimensions sont associees au prefixe du tableau _bits. }
Type
 TXBDimension = Record
  Prefix: String;
  Width,Height: LongInt;
 End;
 TXBState = Record
  Data: PPNBytes;
  Size,Position: LongInt;
  Bad: Boolean;
  Dimensions: Array[0..63] Of TXBDimension;
  DimensionCount: Integer;
 End;
 PXBState = ^TXBState;

Function XBToken(Var D: TXBState): String;
Var C,Q: Char; S: String; Closed: Boolean;
Begin
 XBToken:='';
 While (D.Position<D.Size) And Not D.Bad Do Begin
  C:=Chr(D.Data^[D.Position]);
  If C In [#9,#10,#13,' '] Then Inc(D.Position)
  Else If (C='/') And (D.Position+1<D.Size) Then Begin
   Q:=Chr(D.Data^[D.Position+1]);
   If Q='/' Then Begin
    Inc(D.Position,2); While (D.Position<D.Size) And (D.Data^[D.Position]<>10) Do Inc(D.Position);
   End Else If Q='*' Then Begin
    Inc(D.Position,2); Closed:=False;
    While D.Position+1<D.Size Do Begin
     If (D.Data^[D.Position]=Ord('*')) And (D.Data^[D.Position+1]=Ord('/')) Then Begin Inc(D.Position,2); Closed:=True; Break; End;
     Inc(D.Position);
    End;
    If Not Closed Then D.Bad:=True;
   End Else Break;
  End Else Break;
 End;
 If D.Bad Or (D.Position>=D.Size) Then Exit;
 C:=Chr(D.Data^[D.Position]); S:='';
 If C In ['a'..'z','A'..'Z','0'..'9','_'] Then Begin
  While D.Position<D.Size Do Begin
   C:=Chr(D.Data^[D.Position]); If Not (C In ['a'..'z','A'..'Z','0'..'9','_']) Then Break;
   If Length(S)=255 Then Begin D.Bad:=True; Exit; End;
   S:=S+C; Inc(D.Position);
  End;
 End Else If C In ['"',#39] Then Begin
  Q:=C; Inc(D.Position); Closed:=False;
  While D.Position<D.Size Do Begin
   C:=Chr(D.Data^[D.Position]); Inc(D.Position);
   If C='\' Then Begin If D.Position<D.Size Then Inc(D.Position); End
   Else If C=Q Then Begin Closed:=True; Break; End;
  End;
  If Not Closed Then D.Bad:=True;
  S:='"string"';
 End Else Begin S:=C; Inc(D.Position); End;
 XBToken:=S;
End;

Function XBNumber(S: String; Var Value: LongInt): Boolean;
Var Base,I,Digit,Start: Integer; C: Char;
Begin
 XBNumber:=False; Value:=0;
 While (Length(S)>0) And (UpCase(S[Length(S)]) In ['U','L']) Do Delete(S,Length(S),1);
 If S='' Then Exit;
 Base:=10; Start:=1;
 If (Length(S)>2) And (Copy(PnUpperCase(S),1,2)='0X') Then Begin Base:=16; Start:=3; End
 Else If (Length(S)>1) And (S[1]='0') Then Base:=8;
 For I:=Start To Length(S) Do Begin
  C:=UpCase(S[I]); Digit:=Pos(C,'0123456789ABCDEF')-1;
  If (Digit<0) Or (Digit>=Base) Then Exit;
  If Value>(MaxLongInt-Digit) Div Base Then Exit;
  Value:=Value*Base+Digit;
 End;
 XBNumber:=True;
End;

Function XBValue(Var D: TXBState; Token: String; Var Value: LongInt): Boolean;
Var Negative,Parentheses: Boolean;
Begin
 Parentheses:=Token='('; If Parentheses Then Token:=XBToken(D);
 Negative:=Token='-';
 If Negative Or (Token='+') Then Token:=XBToken(D);
 XBValue:=False;
 If Not XBNumber(Token,Value) Then Exit;
 If Negative Then Value:=-Value;
 If Parentheses Then If XBToken(D)<>')' Then Exit;
 XBValue:=Not D.Bad;
End;

Function XBFindArray(Var D: TXBState; Var Width,Height,UnitBits: Integer;
                      Var ArrayStart: LongInt): Boolean;
Var Token,Name,Prefix,S: String; I,N: Integer; Value: LongInt; ShortType: Boolean;
Begin
 XBFindArray:=False; ShortType:=False;
 Repeat
  Token:=XBToken(D); If (Token='') Or D.Bad Then Exit;
  If Token='#' Then Begin
   Token:=XBToken(D);
   If Token='define' Then Begin
    Name:=XBToken(D); N:=Length(Name); Prefix:=''; S:='';
    If (N>6) And (Copy(Name,N-5,6)='_width') Then Begin Prefix:=Copy(Name,1,N-6); S:='w'; End;
    If (N>7) And (Copy(Name,N-6,7)='_height') Then Begin Prefix:=Copy(Name,1,N-7); S:='h'; End;
    If Prefix<>'' Then Begin
     Token:=XBToken(D); If Not XBValue(D,Token,Value) Then Exit;
     If (Value<1) Or (Value>PnMAX_IMAGE_WIDTH) Then Exit;
     I:=0; While (I<D.DimensionCount) And (D.Dimensions[I].Prefix<>Prefix) Do Inc(I);
     If I=D.DimensionCount Then Begin
      If I=64 Then Exit; D.Dimensions[I].Prefix:=Prefix; Inc(D.DimensionCount);
     End;
     If S='w' Then Begin
      If (D.Dimensions[I].Width<>0) And (D.Dimensions[I].Width<>Value) Then Exit;
      D.Dimensions[I].Width:=Value;
     End Else Begin
      If (D.Dimensions[I].Height<>0) And (D.Dimensions[I].Height<>Value) Then Exit;
      D.Dimensions[I].Height:=Value;
     End;
    End;
   End;
  End Else If (Token='static') Or (Token=';') Then ShortType:=False
  Else If Token='short' Then ShortType:=True
  Else If Token='char' Then ShortType:=False
  Else If (Length(Token)>5) And (Copy(Token,Length(Token)-4,5)='_bits') Then Begin
   Prefix:=Copy(Token,1,Length(Token)-5); I:=0;
   While (I<D.DimensionCount) And (D.Dimensions[I].Prefix<>Prefix) Do Inc(I);
   If I=D.DimensionCount Then Exit;
   Width:=D.Dimensions[I].Width; Height:=D.Dimensions[I].Height;
   If (Width<1) Or (Height<1) Or (Width>PnMAX_IMAGE_WIDTH) Or (Height>PnMAX_IMAGE_HEIGHT) Then Exit;
   If XBToken(D)<>'[' Then Exit;
   Token:=XBToken(D);
   If Token<>']' Then Begin
    If Not XBNumber(Token,Value) Then Exit;
    If XBToken(D)<>']' Then Exit;
   End;
   If XBToken(D)<>'=' Then Exit;
   If XBToken(D)<>'{' Then Exit;
   ArrayStart:=D.Position; UnitBits:=8; If ShortType Then UnitBits:=16;
   XBFindArray:=Not D.Bad; Exit;
  End;
 Until D.Bad;
End;

Function XBCountValues(Var D: TXBState; UnitBits: Integer; Limit: LongInt;
                        Var Count: LongInt): Boolean;
Var Token: String; Value: LongInt;
Begin
 XBCountValues:=False; Count:=0; Token:=XBToken(D);
 If Token='}' Then Exit;
 Repeat
  If Not XBValue(D,Token,Value) Then Exit;
  If UnitBits=8 Then Begin
   If (Value< -128) Or (Value>255) Then Exit;
  End Else If (Value< -32768) Or (Value>65535) Then Exit;
  Inc(Count); If Count>Limit Then Exit;
  Token:=XBToken(D);
  If Token='}' Then Break;
  If Token<>',' Then Exit;
  Token:=XBToken(D); If Token='}' Then Break;
 Until D.Bad;
 If D.Bad Then Exit;
 Token:=XBToken(D); If (Token<>';') And (Token<>'') Then Exit;
 XBCountValues:=True;
End;

Function LoadXBM(FileName: String): Boolean;
Var D: PXBState; F: File; OldMode: Byte; Bytes,ArrayStart,Count,Stride,I,Index,Size,Value: LongInt;
    W,H,UnitBits,Mode,X,Y,J,K,Used,Slot: Integer; Token: String;
    Pixels,Dest,Source: PByte; RGB: PByte; Q: PJPQuantizer; Palette: PnTPalette;
    Img: TJDImage; R,G,B: Byte; Exact,OK: Boolean;
Begin
 LoadXBM:=False; Pixels:=Nil; RGB:=Nil; Q:=Nil;
 D:=PXBState(JDAllocate(SizeOf(TXBState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 Assign(F,FileName); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode;
 If IOResult<>0 Then Begin FreeMem(D,SizeOf(TXBState)); Exit; End;
 {$I-}
 D^.Size:=FileSize(F);
 If (D^.Size>0) And (D^.Size<=134217728) Then Begin
  D^.Data:=PPNBytes(JDAllocate(D^.Size));
  If D^.Data<>Nil Then Begin BlockRead(F,D^.Data^,D^.Size,Bytes); D^.Bad:=Bytes<>D^.Size; End
  Else D^.Bad:=True;
 End Else D^.Bad:=True;
 Close(F);
 {$I+}If IOResult<>0 Then D^.Bad:=True;
 OK:=False; Size:=0;
 If Not D^.Bad Then If XBFindArray(D^,W,H,UnitBits,ArrayStart) Then Begin
  Size:=LongInt(W)*H; Stride:=(LongInt(W)+UnitBits-1) Div UnitBits;
  If XBCountValues(D^,UnitBits,Size*3,Count) Then Begin
   Mode:=0;
   If Count=Stride*H Then Mode:=1
   Else If (UnitBits=8) And (Count=Size*3) Then Mode:=24;
   If Mode<>0 Then Begin
    Pixels:=PByte(JDAllocate(Size));
    If Mode=24 Then RGB:=PByte(JDAllocate(Size*3));
    If (Pixels<>Nil) And ((Mode=1) Or (RGB<>Nil)) Then Begin
     D^.Position:=ArrayStart; Dest:=Pixels; Source:=RGB;
     FillChar(Palette,SizeOf(Palette),0);
     For J:=0 To 15 Do Begin Palette[J].R:=PnVGA_R[J]; Palette[J].G:=PnVGA_G[J]; Palette[J].B:=PnVGA_B[J]; Palette[J].A:=255; End;
     Palette[16].R:=255; Palette[16].G:=255; Palette[16].B:=255; Palette[16].A:=255;
     OK:=True;
     For I:=0 To Count-1 Do Begin
      Token:=XBToken(D^);
      If Not XBValue(D^,Token,Value) Then Begin OK:=False; Break; End;
      If Mode=1 Then Begin
       Y:=I Div Stride; X:=(I Mod Stride)*UnitBits;
       For K:=0 To UnitBits-1 Do If X+K<W Then Begin
        Index:=LongInt(Y)*W+X+K;
        If ((Value Shr K) And 1)<>0 Then PPNBytes(Pixels)^[Index]:=Black Else PPNBytes(Pixels)^[Index]:=16;
       End;
      End Else Begin Source^:=Value; Inc(Source); End;
      If I<Count-1 Then If XBToken(D^)<>',' Then Begin OK:=False; Break; End;
     End;
     If OK And (Mode=24) Then Begin
      Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
      If Q=Nil Then OK:=False
      Else Begin
       Used:=16; Exact:=True; Source:=RGB; Dest:=Pixels;
       For I:=0 To Size-1 Do Begin
        R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
        For J:=0 To Used-1 Do If (Palette[J].R=R) And (Palette[J].G=G) And (Palette[J].B=B) Then Begin Slot:=J; Break; End;
        If Slot<0 Then Begin
         If Used=256 Then Begin Exact:=False; Break; End;
         Slot:=Used; Inc(Used); Palette[Slot].R:=R; Palette[Slot].G:=G; Palette[Slot].B:=B; Palette[Slot].A:=255;
        End;
        Dest^:=Slot; Inc(Dest);
       End;
       If Not Exact Then Begin
        Img.Width:=W; Img.Height:=H; Img.Pixels:=RGB; JPBuildPalette(Q^,Img); Palette:=Q^.Palette;
        Source:=RGB; Dest:=Pixels;
        For I:=0 To Size-1 Do Begin
         R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source);
         Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest);
        End;
       End;
      End;
     End;
     If OK Then Begin
      If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
      PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=W; PnCanvasImageH:=H;
      PnImageBuffer.Width:=W; PnImageBuffer.Height:=H; PnImageBuffer.BitDepth:=Mode;
      PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_XBM; PnImageBuffer.Modified:=False;
      PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0);
      PnImageBuffer.Palette:=Palette;
      For J:=0 To 255 Do Begin
       {$IFDEF FPC}ImgNoPal(J,Palette[J].R,Palette[J].G,Palette[J].B);
       {$ELSE}ImgNoPal(J,Palette[J].R Shr 2,Palette[J].G Shr 2,Palette[J].B Shr 2);{$ENDIF}
      End;
      LoadXBM:=True;
     End;
    End;
   End;
  End;
 End;
 If Pixels<>Nil Then FreeMem(Pixels,Size);
 If RGB<>Nil Then FreeMem(RGB,Size*3);
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TXBState));
End;


{ WordPerfect Graphics niveau 1, integre a PAINT.
  Structure et primitives de VIEWWPG.PAS ; compatibilite big-endian avec
  BMP2WPG.PAS/PCX2WPG.PAS et little-endian avec les fichiers WPG usuels.
  RLE : litteraux, repetitions, blancs $80 et repetitions de lignes $00.
  Les dessins vectoriels sont rasterises en conservant leurs proportions.
  WPG2, chiffrement, texte et PostScript ne sont pas interpretes. }
Type
 TWGState = Record
  Data,RGB: PPNBytes;
  Size,Position,Limit,RGBSize,BitmapPosition,BitmapEnd: LongInt;
  Bad,LittleEndian,HaveEnd,HaveDrawing,HaveBitmap: Boolean;
  Width,Height,BitmapType,Depth: Integer;
  PictureWidth,PictureHeight: LongInt;
  SourceWidth,SourceHeight,Rotation: Integer;
  Palette: PnTPalette;
  FillIndex,LineIndex,Stroke,FillMode,LineMode: Integer;
  Count: Integer;
  X,Y: Array[0..4095] Of Integer;
 End;
 PWGState = ^TWGState;

Function WGByte(Var D: TWGState): Integer;
Begin
 WGByte:=0;
 If D.Bad Then Exit;
 If D.Position>=D.Limit Then Begin D.Bad:=True; Exit; End;
 WGByte:=D.Data^[D.Position]; Inc(D.Position);
End;

Function WGWord(Var D: TWGState): LongInt;
Var A,B: Integer;
Begin
 A:=WGByte(D); B:=WGByte(D);
 If D.LittleEndian Then WGWord:=A+LongInt(B)*256 Else WGWord:=LongInt(A)*256+B;
End;

Function WGLength(Var D: TWGState): LongInt;
Var N: LongInt;
Begin
 N:=WGByte(D);
 If N=255 Then Begin
  N:=WGWord(D);
  If (N And $8000)<>0 Then N:=((N And $7FFF) Shl 16)+WGWord(D);
 End;
 WGLength:=N;
End;

Function WGNext(Var D: TWGState; Var Kind: Integer; Var Start,Stop: LongInt): Boolean;
Var Length: LongInt;
Begin
 WGNext:=False; D.Limit:=D.Size;
 If D.Size-D.Position<2 Then Begin D.Bad:=True; Exit; End;
 Kind:=WGByte(D); Length:=WGLength(D); Start:=D.Position;
 If D.Bad Or (Length<0) Or (Length>D.Size-Start) Then Begin D.Bad:=True; Exit; End;
 Stop:=Start+Length; D.Limit:=Stop; WGNext:=True;
End;

Procedure WGReadBitmapHeader(Var D: TWGState; Kind: Integer);
Var I,Angle,W,H,BPP: Integer;
Begin
 Angle:=0;
 If Kind=$14 Then Begin
  If D.Limit-D.Position<20 Then Begin D.Bad:=True; Exit; End;
  Angle:=WGWord(D);
  For I:=1 To 4 Do WGWord(D);
 End Else If D.Limit-D.Position<10 Then Begin D.Bad:=True; Exit; End;
 W:=WGWord(D); H:=WGWord(D); BPP:=WGWord(D); WGWord(D); WGWord(D);
 If (W<1) Or (H<1) Or (W>PnMAX_IMAGE_WIDTH) Or (H>PnMAX_IMAGE_HEIGHT) Or
    Not (BPP In [1,2,4,8,24]) Then Begin D.Bad:=True; Exit; End;
 If ((Angle And $0FFF)<>0) And ((Angle And $0FFF)<>90) And
    ((Angle And $0FFF)<>180) And ((Angle And $0FFF)<>270) Then Begin D.Bad:=True; Exit; End;
 D.SourceWidth:=W; D.SourceHeight:=H; D.Depth:=BPP; D.Rotation:=Angle;
 D.Width:=W; D.Height:=H;
 If ((Angle And $0FFF)=90) Or ((Angle And $0FFF)=270) Then Begin D.Width:=H; D.Height:=W; End;
End;

Procedure WGReadPalette(Var D: TWGState);
Var First,Last,Count,I: Integer; Remaining: LongInt;
Begin
 If D.Limit-D.Position<4 Then Begin D.Bad:=True; Exit; End;
 First:=WGWord(D); Last:=WGWord(D); Remaining:=D.Limit-D.Position;
 Count:=Last-First;
 If (Count<0) Or (Remaining<>LongInt(Count)*3) Then Count:=Last;
 If (First<0) Or (Count<0) Or (First+LongInt(Count)>256) Or (Remaining<>LongInt(Count)*3) Then Begin D.Bad:=True; Exit; End;
 For I:=First To First+Count-1 Do Begin
  D.Palette[I].R:=WGByte(D); D.Palette[I].G:=WGByte(D); D.Palette[I].B:=WGByte(D); D.Palette[I].A:=255;
 End;
End;

Procedure WGPixel(Var D: TWGState; X,Y,Index: Integer);
Var Offset: LongInt;
Begin
 If (X<0) Or (Y<0) Or (X>=D.Width) Or (Y>=D.Height) Then Exit;
 Offset:=(LongInt(Y)*D.Width+X)*3;
 D.RGB^[Offset]:=D.Palette[Index].R; D.RGB^[Offset+1]:=D.Palette[Index].G; D.RGB^[Offset+2]:=D.Palette[Index].B;
End;

Function WGScale(Value: LongInt; Pixels: Integer; Units: LongInt): Integer;
Var V: LongInt;
Begin
 If Units<1 Then Begin WGScale:=0; Exit; End;
 V:=Round(Value*(Pixels-1.0)/Units);
 If V< -30000 Then V:=-30000 Else If V>30000 Then V:=30000;
 WGScale:=V;
End;

Function WGCode(Var D: TWGState; X,Y: LongInt): Integer;
Var C: Integer;
Begin
 C:=0; If X<0 Then C:=C Or 1 Else If X>=D.Width Then C:=C Or 2;
 If Y<0 Then C:=C Or 4 Else If Y>=D.Height Then C:=C Or 8;
 WGCode:=C;
End;

Procedure WGLine(Var D: TWGState; AX,AY,BX,BY: Integer);
Var X1,Y1,X2,Y2,X,Y,DX,DY,SX,SY,Err,E2: LongInt;
    C1,C2,C,I,J,Guard,Radius: Integer;
Begin
 If D.LineMode=0 Then Exit;
 X1:=AX; Y1:=AY; X2:=BX; Y2:=BY; Guard:=0;
 Repeat
  C1:=WGCode(D,X1,Y1); C2:=WGCode(D,X2,Y2);
  If (C1 Or C2)=0 Then Break;
  If (C1 And C2)<>0 Then Exit;
  Inc(Guard); If Guard>16 Then Exit;
  C:=C1; If C=0 Then C:=C2;
  If (C And 8)<>0 Then Begin
   If Y2=Y1 Then Exit; Y:=D.Height-1; X:=X1+Round((X2-X1)*1.0*(Y-Y1)/(Y2-Y1));
  End Else If (C And 4)<>0 Then Begin
   If Y2=Y1 Then Exit; Y:=0; X:=X1+Round((X2-X1)*1.0*(Y-Y1)/(Y2-Y1));
  End Else If (C And 2)<>0 Then Begin
   If X2=X1 Then Exit; X:=D.Width-1; Y:=Y1+Round((Y2-Y1)*1.0*(X-X1)/(X2-X1));
  End Else Begin
   If X2=X1 Then Exit; X:=0; Y:=Y1+Round((Y2-Y1)*1.0*(X-X1)/(X2-X1));
  End;
  If C=C1 Then Begin X1:=X; Y1:=Y; End Else Begin X2:=X; Y2:=Y; End;
 Until False;
 DX:=Abs(X2-X1); DY:=-Abs(Y2-Y1); SX:=1; SY:=1;
 If X1>X2 Then SX:=-1; If Y1>Y2 Then SY:=-1; Err:=DX+DY;
 Radius:=D.Stroke Div 2;
 Repeat
  For J:=-Radius To Radius Do For I:=-Radius To Radius Do WGPixel(D,X1+I,Y1+J,D.LineIndex);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2:=Err*2; If E2>=DY Then Begin Inc(Err,DY); Inc(X1,SX); End;
  If E2<=DX Then Begin Inc(Err,DX); Inc(Y1,SY); End;
 Until False;
End;

Procedure WGSpan(Var D: TWGState; A,B,Y,Index: Integer);
Var X,T: Integer;
Begin
 If (Y<0) Or (Y>=D.Height) Then Exit;
 If A>B Then Begin T:=A; A:=B; B:=T; End;
 A:=PnMax(0,A); B:=PnMin(D.Width-1,B);
 For X:=A To B Do WGPixel(D,X,Y,Index);
End;

Procedure WGPolygon(Var D: TWGState; Closed: Boolean);
Var Cross: Array[0..4095] Of Integer; I,J,K,Y,Low,High,N,T: Integer; V: Int64;
Begin
 If D.Count<2 Then Exit;
 If Closed And (D.FillMode<>0) Then Begin
  Low:=D.Y[0]; High:=Low;
  For I:=1 To D.Count-1 Do Begin Low:=PnMin(Low,D.Y[I]); High:=PnMax(High,D.Y[I]); End;
  Low:=PnMax(0,Low); High:=PnMin(D.Height-1,High);
  For Y:=Low To High Do Begin
   N:=0; J:=D.Count-1;
   For I:=0 To D.Count-1 Do Begin
    If ((D.Y[I]<=Y) And (D.Y[J]>Y)) Or ((D.Y[J]<=Y) And (D.Y[I]>Y)) Then Begin
     V:=D.X[I]+(Int64(Y)-D.Y[I])*(LongInt(D.X[J])-D.X[I]) Div (LongInt(D.Y[J])-D.Y[I]);
     Cross[N]:=V; Inc(N);
    End;
    J:=I;
   End;
   For I:=1 To N-1 Do Begin
    T:=Cross[I]; K:=I-1;
    While K>=0 Do Begin If Cross[K]<=T Then Break; Cross[K+1]:=Cross[K]; Dec(K); End;
    Cross[K+1]:=T;
   End;
   I:=0; While I+1<N Do Begin WGSpan(D,Cross[I],Cross[I+1],Y,D.FillIndex); Inc(I,2); End;
  End;
 End;
 For I:=1 To D.Count-1 Do WGLine(D,D.X[I-1],D.Y[I-1],D.X[I],D.Y[I]);
 If Closed Then WGLine(D,D.X[D.Count-1],D.Y[D.Count-1],D.X[0],D.Y[0]);
 D.HaveDrawing:=True;
End;

Procedure WGPointList(Var D: TWGState; Closed: Boolean);
Var I: Integer;
Begin
 D.Count:=WGWord(D);
 If (D.Count<1) Or (D.Count>4096) Or (LongInt(D.Count)*4>D.Limit-D.Position) Then Begin D.Bad:=True; Exit; End;
 For I:=0 To D.Count-1 Do Begin
  D.X[I]:=WGScale(WGWord(D),D.Width,D.PictureWidth);
  D.Y[I]:=D.Height-1-WGScale(WGWord(D),D.Height,D.PictureHeight);
 End;
 WGPolygon(D,Closed);
End;

Procedure WGRectangle(Var D: TWGState);
Var X,Y,W,H: LongInt;
Begin
 If D.Limit-D.Position<8 Then Begin D.Bad:=True; Exit; End;
 X:=WGWord(D); Y:=WGWord(D); W:=WGWord(D); H:=WGWord(D);
 D.Count:=4;
 D.X[0]:=WGScale(X,D.Width,D.PictureWidth); D.X[1]:=WGScale(X+W,D.Width,D.PictureWidth);
 D.X[2]:=D.X[1]; D.X[3]:=D.X[0];
 D.Y[0]:=D.Height-1-WGScale(Y,D.Height,D.PictureHeight); D.Y[1]:=D.Y[0];
 D.Y[2]:=D.Height-1-WGScale(Y+H,D.Height,D.PictureHeight); D.Y[3]:=D.Y[2];
 WGPolygon(D,True);
End;

Function WGClampCoordinate(V: LongInt): Integer;
Begin
 If V< -30000 Then WGClampCoordinate:=-30000
 Else If V>30000 Then WGClampCoordinate:=30000 Else WGClampCoordinate:=V;
End;

Procedure WGEllipse(Var D: TWGState);
Var CX,CY,RX,RY,I,Steps: Integer; A: Double;
Begin
 If D.Limit-D.Position<8 Then Begin D.Bad:=True; Exit; End;
 CX:=WGScale(WGWord(D),D.Width,D.PictureWidth); CY:=D.Height-1-WGScale(WGWord(D),D.Height,D.PictureHeight);
 RX:=Abs(WGScale(WGWord(D),D.Width,D.PictureWidth)); RY:=Abs(WGScale(WGWord(D),D.Height,D.PictureHeight));
 Steps:=PnMin(1024,PnMax(32,PnMax(PnMin(RX,4096),PnMin(RY,4096))*2));
 D.Count:=Steps;
 For I:=0 To Steps-1 Do Begin A:=2*Pi*I/Steps; D.X[I]:=WGClampCoordinate(CX+Round(RX*Cos(A))); D.Y[I]:=WGClampCoordinate(CY+Round(RY*Sin(A))); End;
 WGPolygon(D,True);
End;

Procedure WGDecodeBitmap(Var D: TWGState; Kind: Integer);
Var Raw: PPNBytes; RowBytes,Total,OutPos,I,Src,Dest: LongInt;
    B,V,Count,X,Y,TX,TY,FX,FY,Angle: Integer; C: PnTRGBColor;
Begin
 WGReadBitmapHeader(D,Kind); If D.Bad Then Exit;
 RowBytes:=(LongInt(D.SourceWidth)*D.Depth+7) Div 8; Total:=RowBytes*D.SourceHeight;
 Raw:=PPNBytes(JDAllocate(Total)); If Raw=Nil Then Begin D.Bad:=True; Exit; End;
 OutPos:=0;
 While (OutPos<Total) And Not D.Bad Do Begin
  B:=WGByte(D); Count:=B And $7F;
  If (B And $80)<>0 Then Begin
   If Count=0 Then Begin Count:=WGByte(D); V:=255; End Else V:=WGByte(D);
   If (Count=0) Or (Count>Total-OutPos) Then Begin D.Bad:=True; Break; End;
   FillChar(Raw^[OutPos],Count,V); Inc(OutPos,Count);
  End Else If Count<>0 Then Begin
   If (Count>Total-OutPos) Or (Count>D.Limit-D.Position) Then Begin D.Bad:=True; Break; End;
   Move(D.Data^[D.Position],Raw^[OutPos],Count); Inc(D.Position,Count); Inc(OutPos,Count);
  End Else Begin
   Count:=WGByte(D);
   If (Count=0) Or (OutPos<RowBytes) Or ((OutPos Mod RowBytes)<>0) Or (LongInt(Count)*RowBytes>Total-OutPos) Then Begin D.Bad:=True; Break; End;
   For I:=1 To Count Do Begin Move(Raw^[OutPos-RowBytes],Raw^[OutPos],RowBytes); Inc(OutPos,RowBytes); End;
  End;
 End;
 If (OutPos<>Total) Or (D.Position<>D.Limit) Then D.Bad:=True;
 If Not D.Bad Then Begin
  Angle:=D.Rotation And $0FFF;
  For Y:=0 To D.SourceHeight-1 Do For X:=0 To D.SourceWidth-1 Do Begin
   Src:=LongInt(Y)*RowBytes;
   If D.Depth=24 Then Begin
    Inc(Src,LongInt(X)*3); C.R:=Raw^[Src]; C.G:=Raw^[Src+1]; C.B:=Raw^[Src+2];
   End Else Begin
    Src:=Src+(LongInt(X)*D.Depth Div 8); V:=(Raw^[Src] Shr (8-D.Depth-(LongInt(X)*D.Depth Mod 8))) And ((1 Shl D.Depth)-1);
    If D.Depth=1 Then Begin C.R:=V*255; C.G:=C.R; C.B:=C.R; End Else C:=D.Palette[V];
   End;
   FX:=X; FY:=Y;
   If (D.Rotation And $8000)<>0 Then FX:=D.SourceWidth-1-FX;
   If (D.Rotation And $2000)<>0 Then FY:=D.SourceHeight-1-FY;
   TX:=FX; TY:=FY;
   Case Angle Of
    90: Begin TX:=D.SourceHeight-1-FY; TY:=FX; End;
    180: Begin TX:=D.SourceWidth-1-FX; TY:=D.SourceHeight-1-FY; End;
    270: Begin TX:=FY; TY:=D.SourceWidth-1-FX; End;
   End;
   Dest:=(LongInt(TY)*D.Width+TX)*3; D.RGB^[Dest]:=C.R; D.RGB^[Dest+1]:=C.G; D.RGB^[Dest+2]:=C.B;
  End;
  D.HaveDrawing:=True;
 End;
 FreeMem(Raw,Total);
End;

Procedure WGDefaultPalette(Var D: TWGState);
Const
 Gray: Array[0..15] Of Byte = (0,5,8,11,14,17,20,24,28,32,36,40,45,50,56,63);
 Ramp: Array[0..8,0..4] Of Byte =
  ((0,16,31,47,63),(31,39,47,55,63),(45,49,54,58,63),
   (0,7,14,21,28),(14,17,21,24,28),(20,22,24,26,28),
   (0,4,8,12,16),(8,10,12,14,16),(11,12,13,15,16));
Var I,G,Phase,K,R,Green,B,Low,High: Integer;
Begin
 FillChar(D.Palette,SizeOf(D.Palette),0);
 For I:=0 To 255 Do D.Palette[I].A:=255;
 For I:=0 To 15 Do Begin D.Palette[I].R:=PnVGA_R[I]; D.Palette[I].G:=PnVGA_G[I]; D.Palette[I].B:=PnVGA_B[I]; End;
 For I:=0 To 15 Do Begin D.Palette[16+I].R:=Gray[I]*4; D.Palette[16+I].G:=Gray[I]*4; D.Palette[16+I].B:=Gray[I]*4; End;
 I:=32;
 For G:=0 To 8 Do Begin
  Low:=Ramp[G,0]; High:=Ramp[G,4];
  For Phase:=0 To 5 Do For K:=0 To 3 Do Begin
   R:=Low; Green:=Low; B:=High;
   Case Phase Of
    0: R:=Ramp[G,K];
    1: Begin R:=High; B:=Ramp[G,4-K]; End;
    2: Begin R:=High; Green:=Ramp[G,K]; B:=Low; End;
    3: Begin R:=Ramp[G,4-K]; Green:=High; B:=Low; End;
    4: Begin R:=Low; Green:=High; B:=Ramp[G,K]; End;
    5: Begin R:=Low; Green:=Ramp[G,4-K]; B:=High; End;
   End;
   D.Palette[I].R:=R*4; D.Palette[I].G:=Green*4; D.Palette[I].B:=B*4; Inc(I);
  End;
 End;
End;

Function WGRead(Const Name: String; Var D: TWGState): Boolean;
Var F: File; OldMode: Byte; Bytes,Offset,Start,Stop,Records,LowWord,HighWord,Width,Height: LongInt;
    Kind,I: Integer; GotBitmap: Boolean;
Begin
 WGRead:=False;
 Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode;
 If IOResult<>0 Then Exit;
 {$I-}
 D.Size:=FileSize(F);
 If (D.Size>=18) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin BlockRead(F,D.Data^,D.Size,Bytes); D.Bad:=Bytes<>D.Size; End Else D.Bad:=True;
 End Else D.Bad:=True;
 Close(F);
 {$I+}If IOResult<>0 Then D.Bad:=True;
 If D.Bad Then Exit;
 If (D.Data^[0]<>$FF) Or (D.Data^[1]<>$57) Or (D.Data^[2]<>$50) Or (D.Data^[3]<>$43) Or
    (D.Data^[8]<>1) Or (D.Data^[9]<>$16) Or (D.Data^[10]<>1) Or (D.Data^[12]<>0) Or (D.Data^[13]<>0) Then Exit;
 D.Limit:=D.Size; D.Position:=4; D.LittleEndian:=True;
 LowWord:=WGWord(D); HighWord:=WGWord(D); Offset:=LowWord+HighWord*65536;
 If (Offset<16) Or (Offset>D.Size-2) Then Begin
  D.Position:=4; D.LittleEndian:=False; HighWord:=WGWord(D); LowWord:=WGWord(D); Offset:=HighWord*65536+LowWord;
 End;
 If (Offset<16) Or (Offset>D.Size-2) Then Exit;
 D.Position:=Offset; Records:=0;
 { Premier passage : dimensions, premiere image raster et bornes des blocs. }
 While Not D.Bad And Not D.HaveEnd Do Begin
  If Not WGNext(D,Kind,Start,Stop) Then Break;
  Inc(Records); If Records>100000 Then Exit;
  Case Kind Of
   $0F: Begin
    If Stop-Start<6 Then Exit; WGByte(D); WGByte(D); D.PictureWidth:=WGWord(D); D.PictureHeight:=WGWord(D);
   End;
   $0B,$14: If Not D.HaveBitmap Then Begin
    D.BitmapPosition:=Start; D.BitmapEnd:=Stop; D.BitmapType:=Kind;
    WGReadBitmapHeader(D,Kind); D.HaveBitmap:=Not D.Bad;
   End;
   $10: Begin If Stop<>Start Then Exit; D.HaveEnd:=True; End;
  End;
  D.Position:=Stop;
 End;
 If D.Bad Or Not D.HaveEnd Then Exit;
 If Not D.HaveBitmap Then Begin
  If (D.PictureWidth<1) Or (D.PictureHeight<1) Then Exit;
  Width:=D.PictureWidth; Height:=D.PictureHeight;
  If (Width>PnMAX_IMAGE_WIDTH) Or (Height>PnMAX_IMAGE_HEIGHT) Then Begin
   If Width>=Height Then Begin Height:=PnMax(1,Round(Height*1024.0/Width)); Width:=1024; End
   Else Begin Width:=PnMax(1,Round(Width*1024.0/Height)); Height:=1024; End;
  End;
  D.Width:=Width; D.Height:=Height; D.Depth:=24;
 End;
 D.RGBSize:=LongInt(D.Width)*D.Height*3; D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 FillChar(D.RGB^,D.RGBSize,255);
 WGDefaultPalette(D);
 D.FillMode:=0; D.LineMode:=1; D.LineIndex:=0; D.FillIndex:=15; D.Stroke:=1;
 D.Position:=Offset; GotBitmap:=False;
 Repeat
  If Not WGNext(D,Kind,Start,Stop) Then Break;
  Case Kind Of
   $0E: WGReadPalette(D);
   $0B,$14: If Start=D.BitmapPosition Then Begin WGDecodeBitmap(D,Kind); GotBitmap:=Not D.Bad; End;
   $10: Break;
   $0F: ;
   Else If Not D.HaveBitmap Then Case Kind Of
    $01: Begin If Stop-Start<2 Then Exit; D.FillMode:=WGByte(D); D.FillIndex:=WGByte(D); End;
    $02: Begin
     If Stop-Start<2 Then Exit; D.LineMode:=WGByte(D); D.LineIndex:=WGByte(D);
     If Stop-Start>=4 Then D.Stroke:=PnMax(1,PnMin(32,Abs(WGScale(WGWord(D),D.Width,D.PictureWidth))));
    End;
    $05: Begin
     If Stop-Start<8 Then Exit; D.Count:=2;
     For I:=0 To 1 Do Begin D.X[I]:=WGScale(WGWord(D),D.Width,D.PictureWidth); D.Y[I]:=D.Height-1-WGScale(WGWord(D),D.Height,D.PictureHeight); End;
     WGPolygon(D,False);
    End;
    $06: WGPointList(D,False);
    $07: WGRectangle(D);
    $08: WGPointList(D,True);
    $09: WGEllipse(D);
    Else Exit; { Refuser les primitives non gerees plutot qu'une image vide. }
   End;
  End;
  If D.Bad Then Exit;
  D.Position:=Stop;
 Until False;
 WGRead:=Not D.Bad And D.HaveDrawing And (Not D.HaveBitmap Or GotBitmap);
End;

Function LoadWPG(FileName: String): Boolean;
Var D: PWGState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadWPG:=False; Q:=Nil; Pixels:=Nil;
 D:=PWGState(JDAllocate(SizeOf(TWGState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If WGRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Source:=PByte(D^.RGB); Dest:=Pixels; Used:=0; Exact:=True;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=D^.Depth;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_WPG; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadWPG:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TWGState));
End;


{ IFF/LBM integre : ILBM a plans entrelaces, PBM Deluxe Paint, ByteRun1.
  Organisation des plans identique a BMP2LBM.PAS et PCX2LBM.PAS :
  lignes de 16 bits, plan 0 = poids faible, pixels MSB en premier.
  Les chunks sont bornes par FORM et leur bourrage pair n'est pas une donnee.
  HAM6/HAM8 et Extra-Half-Brite sont selectionnes par les drapeaux CAMG.
  Le document indexe est opaque : les pixels masques sont composes sur blanc. }
Type
 TLBState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize,BodyStart,BodyEnd,Position: LongInt;
  Width,Height,Planes,Masking,Compression,TransparentIndex,PaletteCount: Integer;
  CAMG: LongWord;
  Chunky,Bad,HasTransparency: Boolean;
  Palette: PnTPalette;
  Row: Array[0..12799] Of Byte;
 End;
 PLBState = ^TLBState;

Function LBWord(P: PPNBytes; Offset: LongInt): LongInt;
Begin
 LBWord:=LongInt(P^[Offset])*256+P^[Offset+1];
End;

Function LBID(P: PPNBytes; Offset: LongInt): String;
Var I: Integer; S: String;
Begin
 S:=''; For I:=0 To 3 Do S:=S+Chr(P^[Offset+I]); LBID:=S;
End;

Function LBReadChunks(Const Name: String; Var D: TLBState): Boolean;
Var F: File; OldMode: Byte; Bytes,Pos,Start,Stop,Length,FormEnd: LongInt;
    N: LongWord; Kind,FormKind: String; I: Integer; Header,Map,Body,Mode: Boolean;
Begin
 LBReadChunks:=False; Header:=False; Map:=False; Body:=False; Mode:=False;
 Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode;
 If IOResult<>0 Then Exit;
 {$I-}
 D.Size:=FileSize(F);
 If (D.Size>=48) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin BlockRead(F,D.Data^,D.Size,Bytes); D.Bad:=Bytes<>D.Size; End Else D.Bad:=True;
 End Else D.Bad:=True;
 Close(F);
 {$I+}If IOResult<>0 Then D.Bad:=True;
 If D.Bad Then Exit;
 If LBID(D.Data,0)<>'FORM' Then Exit;
 N:=PNBE(D.Data,4); If (N<4) Or (N<>LongWord(D.Size-8)) Then Exit;
 FormEnd:=D.Size; FormKind:=LBID(D.Data,8);
 If (FormKind<>'ILBM') And (FormKind<>'PBM ') Then Exit;
 D.Chunky:=FormKind='PBM '; Pos:=12;
 While Pos<FormEnd Do Begin
  If FormEnd-Pos<8 Then Exit;
  Kind:=LBID(D.Data,Pos); N:=PNBE(D.Data,Pos+4); Start:=Pos+8;
  If N>LongWord(FormEnd-Start) Then Exit;
  Length:=N; Stop:=Start+Length;
  If Odd(Length) And (Stop>=FormEnd) Then Exit;
  If Kind='BMHD' Then Begin
   If Header Or Body Or (Length<>20) Then Exit;
   D.Width:=LBWord(D.Data,Start); D.Height:=LBWord(D.Data,Start+2);
   D.Planes:=D.Data^[Start+8]; D.Masking:=D.Data^[Start+9]; D.Compression:=D.Data^[Start+10];
   D.TransparentIndex:=LBWord(D.Data,Start+12);
   If (D.Width<1) Or (D.Height<1) Or (D.Width>PnMAX_IMAGE_WIDTH) Or (D.Height>PnMAX_IMAGE_HEIGHT) Or
      (D.Masking>2) Or (D.Compression>1) Then Exit;
   If D.Chunky Then Begin If (D.Planes<>8) Or (D.Masking=1) Then Exit; End
   Else If Not ((D.Planes>=1) And (D.Planes<=8)) And (D.Planes<>24) Then Exit;
   If (D.Masking=2) And ((D.Planes=24) Or (D.TransparentIndex>=(1 Shl D.Planes))) Then Exit;
   Header:=True;
  End Else If Kind='CMAP' Then Begin
   If Map Or Body Or (Length<3) Or (Length>768) Or ((Length Mod 3)<>0) Then Exit;
   D.PaletteCount:=Length Div 3;
   For I:=0 To D.PaletteCount-1 Do Begin
    D.Palette[I].R:=D.Data^[Start+I*3]; D.Palette[I].G:=D.Data^[Start+I*3+1];
    D.Palette[I].B:=D.Data^[Start+I*3+2]; D.Palette[I].A:=255;
   End;
   Map:=True;
  End Else If Kind='CAMG' Then Begin
   If Mode Or Body Or (Length<>4) Then Exit;
   D.CAMG:=PNBE(D.Data,Start); Mode:=True;
  End Else If Kind='BODY' Then Begin
   If Body Or Not Header Or (Length=0) Then Exit;
   D.BodyStart:=Start; D.BodyEnd:=Stop; Body:=True;
  End Else If (Kind='PCHG') Or (Kind='SHAM') Or (Kind='CTBL') Or (Kind='CLUT') Then Exit;
  Pos:=Stop+(Length And 1);
 End;
 If Not Header Or Not Body Then Exit;
 If (D.CAMG And $800)<>0 Then Begin
  If D.Chunky Or Not (D.Planes In [6,8]) Or (D.PaletteCount<(1 Shl (D.Planes-2))) Then Exit;
 End;
 If (D.CAMG And $80)<>0 Then Begin
  If D.Chunky Or (D.Planes<>6) Or (D.PaletteCount<32) Or ((D.CAMG And $800)<>0) Then Exit;
  For I:=0 To 31 Do Begin
   D.Palette[I+32].R:=D.Palette[I].R Shr 1;
   D.Palette[I+32].G:=D.Palette[I].G Shr 1;
   D.Palette[I+32].B:=D.Palette[I].B Shr 1; D.Palette[I+32].A:=255;
  End;
  D.PaletteCount:=64;
 End;
 { CMAP peut etre absent ou partiel. Choisir un degrade de gris pour les
   registres non definis ; ne pas reutiliser la palette du document courant. }
 If D.Planes<=8 Then For I:=D.PaletteCount To (1 Shl D.Planes)-1 Do Begin
  D.Palette[I].R:=LongInt(I)*255 Div ((1 Shl D.Planes)-1);
  D.Palette[I].G:=D.Palette[I].R; D.Palette[I].B:=D.Palette[I].R; D.Palette[I].A:=255;
 End;
 LBReadChunks:=Pos=FormEnd;
End;

Function LBReadRow(Var D: TLBState; Dest,Count: Integer): Boolean;
Var Control,N,Produced: Integer;
Begin
 LBReadRow:=False; Produced:=0;
 If (Dest<0) Or (Count<1) Or (LongInt(Dest)+Count>SizeOf(D.Row)) Then Exit;
 If D.Compression=0 Then Begin
  If Count>D.BodyEnd-D.Position Then Exit;
  Move(D.Data^[D.Position],D.Row[Dest],Count); Inc(D.Position,Count); LBReadRow:=True; Exit;
 End;
 While Produced<Count Do Begin
  If D.Position>=D.BodyEnd Then Exit;
  Control:=D.Data^[D.Position]; Inc(D.Position);
  If Control<128 Then Begin
   N:=Control+1;
   If (N>Count-Produced) Or (N>D.BodyEnd-D.Position) Then Exit;
   Move(D.Data^[D.Position],D.Row[Dest+Produced],N); Inc(D.Position,N); Inc(Produced,N);
  End Else If Control>128 Then Begin
   N:=257-Control;
   If (N>Count-Produced) Or (D.Position>=D.BodyEnd) Then Exit;
   FillChar(D.Row[Dest+Produced],N,D.Data^[D.Position]); Inc(D.Position); Inc(Produced,N);
  End; { $80 = aucune operation, mais avance toujours dans le flux. }
 End;
 LBReadRow:=True;
End;

Function LBDecode(Var D: TLBState): Boolean;
Var RowBytes,StoredPlanes,Plane,X,Y,Control,Value: Integer;
    Pixel,Offset: LongInt; R,G,B,HeldR,HeldG,HeldB: Byte; Visible,HAM: Boolean;
Begin
 LBDecode:=False; D.Position:=D.BodyStart;
 D.RGBSize:=LongInt(D.Width)*D.Height*3; D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 If D.Chunky Then Begin RowBytes:=(D.Width+1) And $FFFE; StoredPlanes:=1; End
 Else Begin RowBytes:=((D.Width+15) Div 16)*2; StoredPlanes:=D.Planes; If D.Masking=1 Then Inc(StoredPlanes); End;
 HAM:=(D.CAMG And $800)<>0;
 For Y:=0 To D.Height-1 Do Begin
  For Plane:=0 To StoredPlanes-1 Do If Not LBReadRow(D,Plane*RowBytes,RowBytes) Then Exit;
  HeldR:=D.Palette[0].R; HeldG:=D.Palette[0].G; HeldB:=D.Palette[0].B;
  For X:=0 To D.Width-1 Do Begin
   Pixel:=0;
   If D.Chunky Then Pixel:=D.Row[X]
   Else For Plane:=0 To D.Planes-1 Do
    If (D.Row[Plane*RowBytes+(X Shr 3)] And (1 Shl (7-(X And 7))))<>0 Then Pixel:=Pixel Or (LongInt(1) Shl Plane);
   Visible:=True;
   If D.Masking=1 Then Visible:=(D.Row[D.Planes*RowBytes+(X Shr 3)] And (1 Shl (7-(X And 7))))<>0
   Else If D.Masking=2 Then Visible:=Pixel<>D.TransparentIndex;
   If D.Planes=24 Then Begin R:=Pixel And 255; G:=(Pixel Shr 8) And 255; B:=(Pixel Shr 16) And 255; End
   Else If HAM Then Begin
    Control:=Pixel Shr (D.Planes-2); Value:=Pixel And ((1 Shl (D.Planes-2))-1);
    If Control=0 Then Begin HeldR:=D.Palette[Value].R; HeldG:=D.Palette[Value].G; HeldB:=D.Palette[Value].B; End
    Else Begin
     If D.Planes=6 Then Value:=Value*17 Else Value:=Value Shl 2;
     Case Control Of
      1: If D.Planes=8 Then HeldB:=Value Or (HeldB And 3) Else HeldB:=Value;
      2: If D.Planes=8 Then HeldR:=Value Or (HeldR And 3) Else HeldR:=Value;
      3: If D.Planes=8 Then HeldG:=Value Or (HeldG And 3) Else HeldG:=Value;
     End;
    End;
    R:=HeldR; G:=HeldG; B:=HeldB;
   End Else Begin R:=D.Palette[Pixel].R; G:=D.Palette[Pixel].G; B:=D.Palette[Pixel].B; End;
   If Not Visible Then Begin R:=255; G:=255; B:=255; D.HasTransparency:=True; End;
   Offset:=(LongInt(Y)*D.Width+X)*3; D.RGB^[Offset]:=R; D.RGB^[Offset+1]:=G; D.RGB^[Offset+2]:=B;
  End;
 End;
 If D.Compression=1 Then While (D.Position<D.BodyEnd) And (D.Data^[D.Position]=128) Do Inc(D.Position);
 LBDecode:=D.Position=D.BodyEnd;
End;

Function LoadLBM(FileName: String): Boolean;
Var D: PLBState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadLBM:=False; Pixels:=Nil; Q:=Nil;
 D:=PLBState(JDAllocate(SizeOf(TLBState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If LBReadChunks(FileName,D^) Then If LBDecode(D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   { Validation terminee : remplacer maintenant le document, jamais avant. }
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=D^.Planes;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_LBM; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=D^.HasTransparency; PnImageBuffer.Palette:=Q^.Palette;
   PnImageBuffer.TransparentColor.R:=255; PnImageBuffer.TransparentColor.G:=255; PnImageBuffer.TransparentColor.B:=255; PnImageBuffer.TransparentColor.A:=0;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadLBM:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TLBState));
End;


{ Radiance RGBE integre, compatible avec BMP2HDR.PAS.
  Flux brut, ancien RLE RGBE et nouveau RLE par composante ; huit orientations.
  Le texte de l'entete n'est jamais execute. Les valeurs flottantes d'un HDR
  ordinaire sont normalisees au maximum et corrigees avec un gamma de 2,2
  pour l'affichage indexe. La convention 0..255 de BMP2HDR est preservee.
  Un document PAINT n'est pas un tampon d'edition HDR flottant. }
Type
 THRState = Record
  Data,RGBE,RGB: PPNBytes;
  Size,Position,PixelSize,RGBSize: LongInt;
  Width,Height,ScanLength,ScanCount: Integer;
  Axis1,Axis2: Char;
  Negative1,Negative2,Bad,LineLong,CloneDRAW: Boolean;
  Exposure: Double;
  Correction: Array[0..2] Of Double;
  Scale: Array[0..255] Of Double;
  Scan: Array[0..4095,0..3] Of Byte;
 End;
 PHRState = ^THRState;

Function HRByte(Var D: THRState): Integer;
Begin
 HRByte:=0;
 If D.Bad Then Exit;
 If D.Position>=D.Size Then Begin D.Bad:=True; Exit; End;
 HRByte:=D.Data^[D.Position]; Inc(D.Position);
End;

Function HRTrim(S: String): String;
Begin
 While (Length(S)>0) And (S[1] In [' ',#9]) Do Delete(S,1,1);
 While (Length(S)>0) And (S[Length(S)] In [' ',#9,#13]) Do Delete(S,Length(S),1);
 HRTrim:=S;
End;

Function HRLine(Var D: THRState): String;
Var S: String; B,N: Integer;
Begin
 S:=''; N:=0; D.LineLong:=False;
 Repeat
  B:=HRByte(D); If D.Bad Then Break;
  If B=10 Then Break;
  If (B=0) Or (B>127) Then Begin D.Bad:=True; Break; End;
  Inc(N); If N>4096 Then Begin D.Bad:=True; Break; End;
  If Length(S)<255 Then S:=S+Chr(B) Else D.LineLong:=True;
 Until D.Bad;
 HRLine:=HRTrim(S);
End;

Function HRToken(Var S: String): String;
Var I: Integer;
Begin
 S:=HRTrim(S); I:=1;
 While (I<=Length(S)) And Not (S[I] In [' ',#9]) Do Inc(I);
 HRToken:=Copy(S,1,I-1); Delete(S,1,I-1); S:=HRTrim(S);
End;

Function HRPositive(Const S: String; Var V: Double): Boolean;
Var Code: Integer;
Begin
 V:=0; Val(S,V,Code);
 HRPositive:=(Code=0) And (V>=1.0E-30) And (V<=1.0E30);
End;

Function HRReadHeader(Var D: THRState): Boolean;
Var S,Key,Value,A1,A2,N1,N2,T: String; P,Code,I: Integer; V1,V2: LongInt; V: Double; FormatFound: Boolean;
Begin
 HRReadHeader:=False; D.Exposure:=1;
 For I:=0 To 2 Do D.Correction[I]:=1;
 S:=HRLine(D); If (S<>'#?RADIANCE') And (S<>'#?RGBE') Then Exit;
 FormatFound:=False;
 Repeat
  S:=HRLine(D); If D.Bad Or (D.Position>65536) Then Exit;
  If S='' Then Break;
  If (Pos('CloneDRAW BMP2HDR',S)>0) Or
     (S='SOFTWARE=CloneDRAW PAINT_HDR') Then D.CloneDRAW:=True;
  P:=Pos('=',S);
  If P>0 Then Begin
   Key:=HRTrim(Copy(S,1,P-1)); Value:=HRTrim(Copy(S,P+1,255));
   If Key='FORMAT' Then Begin
    If FormatFound Or D.LineLong Or (Value<>'32-bit_rle_rgbe') Then Exit;
    FormatFound:=True;
   End Else If Key='EXPOSURE' Then Begin
    If D.LineLong Or Not HRPositive(Value,V) Then Exit;
    If (D.Exposure>1.0E30/V) Or (D.Exposure<1.0E-30/V) Then Exit;
    D.Exposure:=D.Exposure*V;
   End Else If Key='COLORCORR' Then Begin
    If D.LineLong Then Exit;
    For I:=0 To 2 Do Begin
     T:=HRToken(Value); If Not HRPositive(T,V) Then Exit;
     If (D.Correction[I]>1.0E30/V) Or (D.Correction[I]<1.0E-30/V) Then Exit;
     D.Correction[I]:=D.Correction[I]*V;
    End;
    If Value<>'' Then Exit;
   End;
  End;
 Until D.Bad;
 If Not FormatFound Then Exit;
 S:=HRLine(D); If D.Bad Or D.LineLong Then Exit;
 A1:=HRToken(S); N1:=HRToken(S); A2:=HRToken(S); N2:=HRToken(S);
 If (S<>'') Or (Length(A1)<>2) Or (Length(A2)<>2) Then Exit;
 If Not (A1[1] In ['+','-']) Or Not (A2[1] In ['+','-']) Or
    Not (A1[2] In ['X','Y']) Or Not (A2[2] In ['X','Y']) Or (A1[2]=A2[2]) Then Exit;
 Val(N1,V1,Code); If (Code<>0) Or (V1<1) Or (V1>PnMAX_IMAGE_WIDTH) Then Exit;
 Val(N2,V2,Code); If (Code<>0) Or (V2<1) Or (V2>PnMAX_IMAGE_HEIGHT) Then Exit;
 D.Axis1:=A1[2]; D.Axis2:=A2[2]; D.Negative1:=A1[1]='-'; D.Negative2:=A2[1]='-';
 D.ScanCount:=V1; D.ScanLength:=V2;
 If D.Axis1='Y' Then Begin D.Height:=V1; D.Width:=V2; End
 Else Begin D.Width:=V1; D.Height:=V2; End;
 D.PixelSize:=LongInt(D.Width)*D.Height*4; D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGBE:=PPNBytes(JDAllocate(D.PixelSize)); D.RGB:=PPNBytes(JDAllocate(D.RGBSize));
 HRReadHeader:=(D.RGBE<>Nil) And (D.RGB<>Nil);
End;

Function HROldScan(Var D: THRState): Boolean;
Var I,J,Shift: Integer; V: Array[0..3] Of Byte; Count: LongInt;
Begin
 HROldScan:=False; I:=0; Shift:=0;
 While I<D.ScanLength Do Begin
  For J:=0 To 3 Do V[J]:=HRByte(D); If D.Bad Then Exit;
  If (V[0]=1) And (V[1]=1) And (V[2]=1) Then Begin
   If (I=0) Or (Shift>16) Then Exit;
   If V[3]>(LongInt(D.ScanLength-I) Shr Shift) Then Exit;
   Count:=LongInt(V[3]) Shl Shift;
   While Count>0 Do Begin D.Scan[I]:=D.Scan[I-1]; Inc(I); Dec(Count); End;
   Inc(Shift,8);
  End Else Begin Move(V,D.Scan[I],4); Inc(I); Shift:=0; End;
 End;
 HROldScan:=True;
End;

Function HRScan(Var D: THRState): Boolean;
Var Start: LongInt; A,B,C,E,Channel,I,N,Value: Integer;
Begin
 HRScan:=False; Start:=D.Position;
 A:=HRByte(D); B:=HRByte(D); C:=HRByte(D); E:=HRByte(D); If D.Bad Then Exit;
 If (D.ScanLength<8) Or (A<>2) Or (B<>2) Or ((C And 128)<>0) Then Begin
  D.Position:=Start; HRScan:=HROldScan(D); Exit;
 End;
 If LongInt(C)*256+E<>D.ScanLength Then Exit;
 For Channel:=0 To 3 Do Begin
  I:=0;
  While I<D.ScanLength Do Begin
   N:=HRByte(D); If D.Bad Or (N=0) Then Exit;
   If N>128 Then Begin
    Dec(N,128); Value:=HRByte(D);
    If D.Bad Or (N>D.ScanLength-I) Then Exit;
    While N>0 Do Begin D.Scan[I,Channel]:=Value; Inc(I); Dec(N); End;
   End Else Begin
    If (N>D.ScanLength-I) Or (N>D.Size-D.Position) Then Exit;
    While N>0 Do Begin D.Scan[I,Channel]:=HRByte(D); Inc(I); Dec(N); End;
   End;
  End;
 End;
 HRScan:=Not D.Bad;
End;

Function HRMap(Axis: Char; Negative: Boolean; Index,Size: Integer): Integer;
Begin
 If ((Axis='X') And Negative) Or ((Axis='Y') And Not Negative) Then HRMap:=Size-1-Index Else HRMap:=Index;
End;

Function HRComponent(Var D: THRState; Offset: LongInt; Channel: Integer): Double;
Var E: Integer;
Begin
 E:=D.RGBE^[Offset+3];
 If E=0 Then HRComponent:=0
 Else HRComponent:=D.RGBE^[Offset+Channel]*D.Scale[E]/D.Exposure/D.Correction[Channel];
End;

Function HRRead(Const Name: String; Var D: THRState): Boolean;
Var F: File; OldMode: Byte; Bytes,N,Offset: LongInt; Scan,Pixel,X,Y,C,E,Display: Integer;
    Peak,Value: Double;
Begin
 HRRead:=False;
 Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode;
 If IOResult<>0 Then Exit;
 {$I-}
 D.Size:=FileSize(F);
 If (D.Size>=24) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin BlockRead(F,D.Data^,D.Size,Bytes); D.Bad:=Bytes<>D.Size; End Else D.Bad:=True;
 End Else D.Bad:=True;
 Close(F);
 {$I+}If IOResult<>0 Then D.Bad:=True;
 If D.Bad Or Not HRReadHeader(D) Then Exit;
 For Scan:=0 To D.ScanCount-1 Do Begin
  If Not HRScan(D) Then Exit;
  For Pixel:=0 To D.ScanLength-1 Do Begin
   If D.Axis1='Y' Then Begin Y:=HRMap('Y',D.Negative1,Scan,D.Height); X:=HRMap('X',D.Negative2,Pixel,D.Width); End
   Else Begin X:=HRMap('X',D.Negative1,Scan,D.Width); Y:=HRMap('Y',D.Negative2,Pixel,D.Height); End;
   Offset:=(LongInt(Y)*D.Width+X)*4; Move(D.Scan[Pixel],D.RGBE^[Offset],4);
  End;
 End;
 If D.Position<>D.Size Then Exit;
 { Exposant partage RGBE : mantisse * 2^(E-128-8), sans unite flottante externe. }
 D.Scale[0]:=0; D.Scale[1]:=Exp(-135*Ln(2));
 For E:=2 To 255 Do D.Scale[E]:=D.Scale[E-1]*2;
 Peak:=0;
 If Not D.CloneDRAW Then For N:=0 To LongInt(D.Width)*D.Height-1 Do
  For C:=0 To 2 Do Begin Value:=HRComponent(D,N*4,C); If Value>Peak Then Peak:=Value; End;
 For N:=0 To LongInt(D.Width)*D.Height-1 Do For C:=0 To 2 Do Begin
  Value:=HRComponent(D,N*4,C);
  If D.CloneDRAW Then Begin
   If Value>=255 Then Display:=255 Else If Value<=0 Then Display:=0 Else Display:=Round(Value);
  End Else Begin
   If (Value<=0) Or (Peak<=0) Then Display:=0
   Else If Value>=Peak Then Display:=255
   Else Display:=Round(255*Exp(Ln(Value/Peak)/2.2));
  End;
  D.RGB^[N*3+C]:=Display;
 End;
 HRRead:=True;
End;

Function LoadHDR(FileName: String): Boolean;
Var D: PHRState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadHDR:=False; Pixels:=Nil; Q:=Nil;
 D:=PHRState(JDAllocate(SizeOf(THRState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If HRRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=24;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_HDR; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadHDR:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.RGBE<>Nil Then FreeMem(D^.RGBE,D^.PixelSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(THRState));
End;


{ FAX brut CCITT T.4 Group 3 1D (BMP2FAX.PAS), bits de poids fort d'abord.
  Les dimensions sont deduites des lignes EOL ; RTC obligatoire (six EOL).
  Deux passes valident le flux avant toute modification du document.
  Les conteneurs TIFF et les modes Group 3 2D / Group 4 ne sont pas du FAX brut 1D. }
Type
 TFXNode = Record Next: Array[0..1] Of Integer; Run: Integer; End;
 TFXState = Record
  Data,Pixels: PPNBytes;
  Size,BitPos,PixelSize: LongInt;
  Width,Height,Nodes: Integer;
  Tree: Array[0..2047] Of TFXNode;
 End;
 PFXState = ^TFXState;

Function FXBit(Var D: TFXState): Integer;
Begin
 FXBit:=-1;
 If D.BitPos>=D.Size*8 Then Exit;
 FXBit:=(D.Data^[D.BitPos Shr 3] Shr (7-(D.BitPos And 7))) And 1;
 Inc(D.BitPos);
End;

Function FXAdd(Var D: TFXState; Root,Run: Integer; Const Code: String): Boolean;
Var I,B,N: Integer;
Begin
 FXAdd:=False; N:=Root;
 For I:=1 To Length(Code) Do Begin
  B:=Ord(Code[I])-Ord('0');
  If D.Tree[N].Run>=0 Then Exit;
  If D.Tree[N].Next[B]<0 Then Begin
   If D.Nodes>High(D.Tree) Then Exit;
   D.Tree[N].Next[B]:=D.Nodes; Inc(D.Nodes);
  End;
  N:=D.Tree[N].Next[B];
 End;
 If (D.Tree[N].Run>=0) Or (D.Tree[N].Next[0]>=0) Or (D.Tree[N].Next[1]>=0) Then Exit;
 D.Tree[N].Run:=Run; FXAdd:=True;
End;

Function FXWhiteCode(Run:Byte):String;
Begin
 Case Run of
  0:FXWhiteCode:='00110101'; 1:FXWhiteCode:='000111';
  2:FXWhiteCode:='0111'; 3:FXWhiteCode:='1000';
  4:FXWhiteCode:='1011'; 5:FXWhiteCode:='1100';
  6:FXWhiteCode:='1110'; 7:FXWhiteCode:='1111';
  8:FXWhiteCode:='10011'; 9:FXWhiteCode:='10100';
  10:FXWhiteCode:='00111'; 11:FXWhiteCode:='01000';
  12:FXWhiteCode:='001000'; 13:FXWhiteCode:='000011';
  14:FXWhiteCode:='110100'; 15:FXWhiteCode:='110101';
  16:FXWhiteCode:='101010'; 17:FXWhiteCode:='101011';
  18:FXWhiteCode:='0100111'; 19:FXWhiteCode:='0001100';
  20:FXWhiteCode:='0001000'; 21:FXWhiteCode:='0010111';
  22:FXWhiteCode:='0000011'; 23:FXWhiteCode:='0000100';
  24:FXWhiteCode:='0101000'; 25:FXWhiteCode:='0101011';
  26:FXWhiteCode:='0010011'; 27:FXWhiteCode:='0100100';
  28:FXWhiteCode:='0011000'; 29:FXWhiteCode:='00000010';
  30:FXWhiteCode:='00000011'; 31:FXWhiteCode:='00011010';
  32:FXWhiteCode:='00011011'; 33:FXWhiteCode:='00010010';
  34:FXWhiteCode:='00010011'; 35:FXWhiteCode:='00010100';
  36:FXWhiteCode:='00010101'; 37:FXWhiteCode:='00010110';
  38:FXWhiteCode:='00010111'; 39:FXWhiteCode:='00101000';
  40:FXWhiteCode:='00101001'; 41:FXWhiteCode:='00101010';
  42:FXWhiteCode:='00101011'; 43:FXWhiteCode:='00101100';
  44:FXWhiteCode:='00101101'; 45:FXWhiteCode:='00000100';
  46:FXWhiteCode:='00000101'; 47:FXWhiteCode:='00001010';
  48:FXWhiteCode:='00001011'; 49:FXWhiteCode:='01010010';
  50:FXWhiteCode:='01010011'; 51:FXWhiteCode:='01010100';
  52:FXWhiteCode:='01010101'; 53:FXWhiteCode:='00100100';
  54:FXWhiteCode:='00100101'; 55:FXWhiteCode:='01011000';
  56:FXWhiteCode:='01011001'; 57:FXWhiteCode:='01011010';
  58:FXWhiteCode:='01011011'; 59:FXWhiteCode:='01001010';
  60:FXWhiteCode:='01001011'; 61:FXWhiteCode:='00110010';
  62:FXWhiteCode:='00110011'; Else FXWhiteCode:='00110100';
 End;
End;

Function FXBlackCode(Run:Byte):String;
Begin
 Case Run of
  0:FXBlackCode:='0000110111'; 1:FXBlackCode:='010';
  2:FXBlackCode:='11'; 3:FXBlackCode:='10';
  4:FXBlackCode:='011'; 5:FXBlackCode:='0011';
  6:FXBlackCode:='0010'; 7:FXBlackCode:='00011';
  8:FXBlackCode:='000101'; 9:FXBlackCode:='000100';
  10:FXBlackCode:='0000100'; 11:FXBlackCode:='0000101';
  12:FXBlackCode:='0000111'; 13:FXBlackCode:='00000100';
  14:FXBlackCode:='00000111'; 15:FXBlackCode:='000011000';
  16:FXBlackCode:='0000010111'; 17:FXBlackCode:='0000011000';
  18:FXBlackCode:='0000001000'; 19:FXBlackCode:='00001100111';
  20:FXBlackCode:='00001101000'; 21:FXBlackCode:='00001101100';
  22:FXBlackCode:='00000110111'; 23:FXBlackCode:='00000101000';
  24:FXBlackCode:='00000010111'; 25:FXBlackCode:='00000011000';
  26:FXBlackCode:='000011001010'; 27:FXBlackCode:='000011001011';
  28:FXBlackCode:='000011001100'; 29:FXBlackCode:='000011001101';
  30:FXBlackCode:='000001101000'; 31:FXBlackCode:='000001101001';
  32:FXBlackCode:='000001101010'; 33:FXBlackCode:='000001101011';
  34:FXBlackCode:='000011010010'; 35:FXBlackCode:='000011010011';
  36:FXBlackCode:='000011010100'; 37:FXBlackCode:='000011010101';
  38:FXBlackCode:='000011010110'; 39:FXBlackCode:='000011010111';
  40:FXBlackCode:='000001101100'; 41:FXBlackCode:='000001101101';
  42:FXBlackCode:='000011011010'; 43:FXBlackCode:='000011011011';
  44:FXBlackCode:='000001010100'; 45:FXBlackCode:='000001010101';
  46:FXBlackCode:='000001010110'; 47:FXBlackCode:='000001010111';
  48:FXBlackCode:='000001100100'; 49:FXBlackCode:='000001100101';
  50:FXBlackCode:='000001010010'; 51:FXBlackCode:='000001010011';
  52:FXBlackCode:='000000100100'; 53:FXBlackCode:='000000110111';
  54:FXBlackCode:='000000111000'; 55:FXBlackCode:='000000100111';
  56:FXBlackCode:='000000101000'; 57:FXBlackCode:='000001011000';
  58:FXBlackCode:='000001011001'; 59:FXBlackCode:='000000101011';
  60:FXBlackCode:='000000101100'; 61:FXBlackCode:='000001011010';
  62:FXBlackCode:='000001100110'; Else FXBlackCode:='000001100111';
 End;
End;

Function FXMakeupCode(Run:Word;Black:Boolean):String;
Begin
 Case Run of
  64:If Black Then FXMakeupCode:='0000001111'Else FXMakeupCode:='11011';
  128:If Black Then FXMakeupCode:='000011001000'Else FXMakeupCode:='10010';
  192:If Black Then FXMakeupCode:='000011001001'Else FXMakeupCode:='010111';
  256:If Black Then FXMakeupCode:='000001011011'Else FXMakeupCode:='0110111';
  320:If Black Then FXMakeupCode:='000000110011'Else FXMakeupCode:='00110110';
  384:If Black Then FXMakeupCode:='000000110100'Else FXMakeupCode:='00110111';
  448:If Black Then FXMakeupCode:='000000110101'Else FXMakeupCode:='01100100';
  512:If Black Then FXMakeupCode:='0000001101100'Else FXMakeupCode:='01100101';
  576:If Black Then FXMakeupCode:='0000001101101'Else FXMakeupCode:='01101000';
  640:If Black Then FXMakeupCode:='0000001001010'Else FXMakeupCode:='01100111';
  704:If Black Then FXMakeupCode:='0000001001011'Else FXMakeupCode:='011001100';
  768:If Black Then FXMakeupCode:='0000001001100'Else FXMakeupCode:='011001101';
  832:If Black Then FXMakeupCode:='0000001001101'Else FXMakeupCode:='011010010';
  896:If Black Then FXMakeupCode:='0000001110010'Else FXMakeupCode:='011010011';
  960:If Black Then FXMakeupCode:='0000001110011'Else FXMakeupCode:='011010100';
  1024:If Black Then FXMakeupCode:='0000001110100'Else FXMakeupCode:='011010101';
  1088:If Black Then FXMakeupCode:='0000001110101'Else FXMakeupCode:='011010110';
  1152:If Black Then FXMakeupCode:='0000001110110'Else FXMakeupCode:='011010111';
  1216:If Black Then FXMakeupCode:='0000001110111'Else FXMakeupCode:='011011000';
  1280:If Black Then FXMakeupCode:='0000001010010'Else FXMakeupCode:='011011001';
  1344:If Black Then FXMakeupCode:='0000001010011'Else FXMakeupCode:='011011010';
  1408:If Black Then FXMakeupCode:='0000001010100'Else FXMakeupCode:='011011011';
  1472:If Black Then FXMakeupCode:='0000001010101'Else FXMakeupCode:='010011000';
  1536:If Black Then FXMakeupCode:='0000001011010'Else FXMakeupCode:='010011001';
  1600:If Black Then FXMakeupCode:='0000001011011'Else FXMakeupCode:='010011010';
  1664:If Black Then FXMakeupCode:='0000001100100'Else FXMakeupCode:='011000';
  1728:If Black Then FXMakeupCode:='0000001100101'Else FXMakeupCode:='010011011';
  1792:FXMakeupCode:='00000001000'; 1856:FXMakeupCode:='00000001100';
  1920:FXMakeupCode:='00000001101'; 1984:FXMakeupCode:='000000010010';
  2048:FXMakeupCode:='000000010011'; 2112:FXMakeupCode:='000000010100';
  2176:FXMakeupCode:='000000010101'; 2240:FXMakeupCode:='000000010110';
  2304:FXMakeupCode:='000000010111'; 2368:FXMakeupCode:='000000011100';
  2432:FXMakeupCode:='000000011101'; 2496:FXMakeupCode:='000000011110';
  Else FXMakeupCode:='000000011111';
 End;
End;


Function FXBuild(Var D: TFXState): Boolean;
Var C,R: Integer; S: String;
Begin
 FXBuild:=False; FillChar(D.Tree,SizeOf(D.Tree),255); D.Nodes:=2;
 For C:=0 To 1 Do Begin
  For R:=0 To 63 Do Begin
   If C=0 Then S:=FXWhiteCode(R) Else S:=FXBlackCode(R);
   If Not FXAdd(D,C,R,S) Then Exit;
  End;
  R:=64;
  While R<=2560 Do Begin
   S:=FXMakeupCode(R,C=1); If Not FXAdd(D,C,R,S) Then Exit;
   Inc(R,64);
  End;
 End;
 FXBuild:=True;
End;

Function FXEOL(Var D: TFXState): Boolean;
Var Saved: LongInt; B,Z: Integer;
Begin
 FXEOL:=False; Saved:=D.BitPos; Z:=0;
 Repeat B:=FXBit(D); If B<>0 Then Break; Inc(Z); Until Z>64;
 If (B=1) And (Z>=11) And (Z<=64) Then FXEOL:=True Else D.BitPos:=Saved;
End;

Function FXRun(Var D: TFXState; Black: Boolean): Integer;
Var N,B,I: Integer;
Begin
 FXRun:=-1; N:=Ord(Black);
 For I:=1 To 13 Do Begin
  B:=FXBit(D); If B<0 Then Exit;
  N:=D.Tree[N].Next[B]; If N<0 Then Exit;
  If D.Tree[N].Run>=0 Then Begin FXRun:=D.Tree[N].Run; Exit; End;
 End;
End;

Function FXDecode(Var D: TFXState; Store: Boolean): Boolean;
Var X,Y,W,R,Pending,Empty,I,Tokens: Integer; Black: Boolean; Offset: LongInt;
Begin
 FXDecode:=False; D.BitPos:=0;
 If Not FXEOL(D) Then Exit;
 Y:=0; W:=0; Empty:=1;
 Repeat
  X:=0; Pending:=0; Black:=False; Tokens:=0;
  While Not FXEOL(D) Do Begin
   R:=FXRun(D,Black); If R<0 Then Exit;
   Inc(Tokens); If Tokens>PnMAX_IMAGE_WIDTH*2+128 Then Exit;
   If R>PnMAX_IMAGE_WIDTH-X-Pending Then Exit;
   Inc(Pending,R);
   If R<64 Then Begin
    If Store Then Begin
     If (Y>=D.Height) Or (X+Pending>D.Width) Then Exit;
     Offset:=LongInt(Y)*D.Width+X;
     For I:=0 To Pending-1 Do
      If Black Then D.Pixels^[Offset+I]:=0 Else D.Pixels^[Offset+I]:=16;
    End;
    Inc(X,Pending); Pending:=0; Black:=Not Black;
   End;
  End;
  If Pending<>0 Then Exit;
  If X=0 Then Begin
   { Uniquement les EOL vides du RTC, jamais des lignes de pixels vides. }
   If (Y=0) Or (Tokens<>0) Then Exit;
   Inc(Empty);
  End Else Begin
   If Empty<>1 Then Exit;
   If W=0 Then W:=X Else If X<>W Then Exit;
   Inc(Y); If Y>PnMAX_IMAGE_HEIGHT Then Exit;
   Empty:=1;
  End;
 Until Empty=6;
 If (D.Size*8-D.BitPos)>7 Then Exit;
 While D.BitPos<D.Size*8 Do If FXBit(D)<>0 Then Exit;
 If Store Then Begin If (W<>D.Width) Or (Y<>D.Height) Then Exit; End
 Else Begin D.Width:=W; D.Height:=Y; End;
 FXDecode:=(W>0) And (Y>0);
End;

Function FXRead(Const Name: String; Var D: TFXState): Boolean;
Var F: File; OldMode: Byte; Bytes: LongInt; Failed: Boolean;
Begin
 FXRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=12) And (D.Size<=16777216) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Then Exit;
 If Not FXBuild(D) Or Not FXDecode(D,False) Then Exit;
 D.PixelSize:=LongInt(D.Width)*D.Height;
 D.Pixels:=PPNBytes(JDAllocate(D.PixelSize)); If D.Pixels=Nil Then Exit;
 FXRead:=FXDecode(D,True);
End;

Function LoadFAX(FileName: String): Boolean;
Var D: PFXState; I: Integer;
Begin
 LoadFAX:=False; D:=PFXState(JDAllocate(SizeOf(TFXState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If FXRead(FileName,D^) Then Begin
  If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
  PnCanvasImage:=PByte(D^.Pixels); D^.Pixels:=Nil;
  PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
  PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=1;
  PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_FAX; PnImageBuffer.Modified:=False;
  PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0);
  FillChar(PnImageBuffer.Palette,SizeOf(PnImageBuffer.Palette),0);
  For I:=0 To 15 Do Begin PnImageBuffer.Palette[I].R:=PnVGA_R[I]; PnImageBuffer.Palette[I].G:=PnVGA_G[I]; PnImageBuffer.Palette[I].B:=PnVGA_B[I]; End;
  PnImageBuffer.Palette[16].R:=255; PnImageBuffer.Palette[16].G:=255; PnImageBuffer.Palette[16].B:=255;
  For I:=0 To 255 Do Begin
   PnImageBuffer.Palette[I].A:=255;
   {$IFDEF FPC}ImgNoPal(I,PnImageBuffer.Palette[I].R,PnImageBuffer.Palette[I].G,PnImageBuffer.Palette[I].B);
   {$ELSE}ImgNoPal(I,PnImageBuffer.Palette[I].R Shr 2,PnImageBuffer.Palette[I].G Shr 2,PnImageBuffer.Palette[I].B Shr 2);{$ENDIF}
  End;
  LoadFAX:=True;
 End;
 If D^.Pixels<>Nil Then FreeMem(D^.Pixels,D^.PixelSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TFXState));
End;


{ OpenEXR scanline simple, non compresse : HALF, FLOAT et UINT.
  Compatible BMP2EXR.PAS. Les valeurs sont bornees a [0,1] pour le canevas
  indexe (pas de conservation des valeurs HDR flottantes). Alpha premultiplie
  compose sur blanc. Pas de tuiles, deep, multipart ni compression. }
Type
 TEXChannel = Record Name: String[255]; Kind,Target: Integer; End;
 TEXState = Record
  Data,RGB: PPNBytes;
  Size,Position,RGBSize,MinY,MinX,RowSize,TableEnd: LongInt;
  Width,Height,ChannelCount: Integer;
  Bad,HasAlpha,HasY: Boolean;
  Channels: Array[0..63] Of TEXChannel;
  Seen: Array[0..4095] Of Boolean;
  Starts,Ends: Array[0..4095] Of LongInt;
 End;
 PEXState = ^TEXState;

Function EXByte(Var D: TEXState): Byte;
Begin
 EXByte:=0; If D.Bad Then Exit;
 If (D.Position<0) Or (D.Position>=D.Size) Then Begin D.Bad:=True; Exit; End;
 EXByte:=D.Data^[D.Position]; Inc(D.Position);
End;

Function EXLong(Var D: TEXState): LongWord;
Var V: LongWord; I: Integer;
Begin
 V:=0; For I:=0 To 3 Do V:=V Or (LongWord(EXByte(D)) Shl (I*8)); EXLong:=V;
End;

Function EXString(Var D: TEXState): String;
Var S: String; B: Byte;
Begin
 S:='';
 Repeat
  B:=EXByte(D); If D.Bad Or (B=0) Then Break;
  If (B<32) Or (B>126) Or (Length(S)=255) Then Begin D.Bad:=True; Break; End;
  S:=S+Chr(B);
 Until D.Bad;
 EXString:=S;
End;

Function EXHeader(Var D: TEXState): Boolean;
Var Name,Kind,S: String; Size,Limit,V,Flags: LongWord;
    X1,Y1: LongInt; W,H: Double; I,J,T,K,Mask,AttrCount: Integer;
    GotChannels,GotWindow,GotCompression,GotOrder: Boolean;
Begin
 EXHeader:=False;
 If EXLong(D)<>$01312F76 Then Exit;
 Flags:=EXLong(D); If Flags<>2 Then Exit;
 GotChannels:=False; GotWindow:=False; GotCompression:=False; GotOrder:=False; AttrCount:=0;
 Repeat
  Name:=EXString(D); If D.Bad Then Exit; If Name='' Then Break;
  Inc(AttrCount); If (AttrCount>256) Or (D.Position>1048576) Then Exit;
  Kind:=EXString(D); Size:=EXLong(D);
  If D.Bad Or (Size>LongWord(D.Size-D.Position)) Then Exit;
  Limit:=LongWord(D.Position)+Size;
  If Name='channels' Then Begin
   If GotChannels Or (Kind<>'chlist') Then Exit; GotChannels:=True; Mask:=0;
   Repeat
    S:=EXString(D); If D.Bad Or (LongWord(D.Position)>Limit) Then Exit;
    If S='' Then Break;
    If (D.ChannelCount=64) Or (Limit-LongWord(D.Position)<16) Then Exit;
    For J:=0 To D.ChannelCount-1 Do If D.Channels[J].Name=S Then Exit;
    V:=EXLong(D); If V>2 Then Exit; K:=V;
    If EXByte(D)>1 Then Exit;
    For I:=1 To 3 Do If EXByte(D)<>0 Then Exit;
    If EXLong(D)<>1 Then Exit; If EXLong(D)<>1 Then Exit;
    T:=-1;
    If S='R' Then T:=0 Else If S='G' Then T:=1 Else If S='B' Then T:=2
    Else If S='A' Then Begin T:=3; D.HasAlpha:=True; End
    Else If S='Y' Then Begin T:=4; D.HasY:=True; End;
    If (T>=0) And (T<=2) Then Mask:=Mask Or (1 Shl T);
    With D.Channels[D.ChannelCount] Do Begin Name:=S; Kind:=K; Target:=T; End;
    Inc(D.ChannelCount);
   Until D.Bad;
   If (LongWord(D.Position)<>Limit) Or ((Mask<>7) And Not ((Mask=0) And D.HasY)) Then Exit;
   If Mask=7 Then D.HasY:=False;
  End Else If Name='compression' Then Begin
   If GotCompression Or (Kind<>'compression') Or (Size<>1) Then Exit;
   GotCompression:=True; If EXByte(D)<>0 Then Exit;
  End Else If Name='dataWindow' Then Begin
   If GotWindow Or (Kind<>'box2i') Or (Size<>16) Then Exit; GotWindow:=True;
   D.MinX:=LongInt(EXLong(D)); D.MinY:=LongInt(EXLong(D));
   X1:=LongInt(EXLong(D)); Y1:=LongInt(EXLong(D));
   W:=(X1*1.0)-(D.MinX*1.0)+1; H:=(Y1*1.0)-(D.MinY*1.0)+1;
   If (W<1) Or (W>PnMAX_IMAGE_WIDTH) Or (H<1) Or (H>PnMAX_IMAGE_HEIGHT) Then Exit;
   D.Width:=Round(W); D.Height:=Round(H);
  End Else If Name='lineOrder' Then Begin
   If GotOrder Or (Kind<>'lineOrder') Or (Size<>1) Then Exit;
   GotOrder:=True; If EXByte(D)>2 Then Exit;
  End;
  If D.Bad Or (LongWord(D.Position)>Limit) Then Exit;
  D.Position:=Limit;
 Until D.Bad;
 If D.Bad Or Not GotChannels Or Not GotCompression Or Not GotWindow Then Exit;
 D.RowSize:=0;
 For I:=0 To D.ChannelCount-1 Do
  If D.Channels[I].Kind=1 Then Inc(D.RowSize,LongInt(D.Width)*2) Else Inc(D.RowSize,LongInt(D.Width)*4);
 D.TableEnd:=D.Position+LongInt(D.Height)*8;
 If D.TableEnd>D.Size Then Exit;
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); EXHeader:=D.RGB<>Nil;
End;

Function EXSample(Var D: TEXState; Kind: Integer): Double;
Var V: LongWord; E,M: Integer; F: Single; H: Word; Value: Double;
Begin
 If Kind=1 Then Begin
  H:=EXByte(D); H:=H Or (Word(EXByte(D)) Shl 8); E:=(H Shr 10) And 31; M:=H And 1023;
  If (H And $8000)<>0 Then Value:=0
  Else If E=31 Then Begin If M=0 Then Value:=1 Else Value:=0; End
  Else If E=0 Then Value:=M/16777216.0
  Else Value:=(1+M/1024.0)*Exp((E-15)*Ln(2));
 End Else Begin
  V:=EXLong(D);
  If Kind=0 Then Value:=V/4294967295.0
  Else If (V And $80000000)<>0 Then Value:=0
  Else If (V And $7F800000)=$7F800000 Then Begin
   If (V And $007FFFFF)=0 Then Value:=1 Else Value:=0;
  End Else Begin Move(V,F,4); Value:=F; End;
 End;
 If Value<0 Then Value:=0; If Value>1 Then Value:=1;
 EXSample:=Value;
End;

Function EXRead(Const Name: String; Var D: TEXState): Boolean;
Var F: File; OldMode: Byte; Bytes,TablePos,Offset,EndPos,RowY: LongInt;
    I,J,C,X,Y,T: Integer; Failed: Boolean; Low,HighPart,Count: LongWord;
    Row: Array[0..4095,0..3] Of Double; Value: Double;
Begin
 EXRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=32) And (D.Size<=268435456) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Or Not EXHeader(D) Then Exit;
 TablePos:=D.Position;
 For I:=0 To D.Height-1 Do Begin
  D.Position:=TablePos+LongInt(I)*8; Low:=EXLong(D); HighPart:=EXLong(D);
  If D.Bad Or (HighPart<>0) Or (Low<LongWord(D.TableEnd)) Or (Low>LongWord(D.Size-8)) Then Exit;
  Offset:=Low; D.Position:=Offset; RowY:=LongInt(EXLong(D)); Count:=EXLong(D);
  If (Count<>LongWord(D.RowSize)) Or (Count>LongWord(D.Size-D.Position)) Then Exit;
  EndPos:=D.Position+D.RowSize;
  For J:=0 To I-1 Do If (Offset<D.Ends[J]) And (EndPos>D.Starts[J]) Then Exit;
  D.Starts[I]:=Offset; D.Ends[I]:=EndPos;
  If ((RowY*1.0)<(D.MinY*1.0)) Or ((RowY*1.0)>=(D.MinY*1.0)+D.Height) Then Exit;
  Y:=RowY-D.MinY; If D.Seen[Y] Then Exit; D.Seen[Y]:=True;
  FillChar(Row,SizeOf(Row),0); For X:=0 To D.Width-1 Do Row[X,3]:=1;
  For C:=0 To D.ChannelCount-1 Do Begin
   T:=D.Channels[C].Target;
   For X:=0 To D.Width-1 Do Begin
    Value:=EXSample(D,D.Channels[C].Kind);
    If (T>=0) And (T<=3) Then Row[X,T]:=Value
    Else If (T=4) And D.HasY Then Begin Row[X,0]:=Value; Row[X,1]:=Value; Row[X,2]:=Value; End;
   End;
  End;
  If D.Bad Or (D.Position<>EndPos) Then Exit;
  For X:=0 To D.Width-1 Do For C:=0 To 2 Do Begin
   Value:=Row[X,C]; If D.HasAlpha Then Value:=Value+1-Row[X,3];
   If Value>1 Then Value:=1;
   D.RGB^[(LongInt(Y)*D.Width+X)*3+C]:=Round(Value*255);
  End;
 End;
 EXRead:=True;
End;

Function LoadEXR(FileName: String): Boolean;
Var D: PEXState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadEXR:=False; Pixels:=Nil; Q:=Nil;
 D:=PEXState(JDAllocate(SizeOf(TEXState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If EXRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=24;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_EXR; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadEXR:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TEXState));
End;



{ DNG TIFF classique CFA Bayer 2x2, 8/16 bits non compresse, bandes,
  deux ordres d'octets, huit orientations et dematricage bilineaire.
  Matrice couleur identite seulement : pas de developpement RAW camera general.
  Compatibilite precise avec l'erreur 30/34 entrees de BMP2DNG.PAS. }
Type
 TDNEntry = Record Tag,Kind: Word; Count,Offset: LongInt; End;
 TDNState = Record
  Data,Raw,RGB: PPNBytes;
  Size,RawSize,RGBSize,Fixup,IFD: LongInt;
  Width,Height,OutWidth,OutHeight,Bits,Orientation,EntryCount: Integer;
  Little,Bad,ARWMode,CR2Mode,TIFFMode: Boolean;
  TFSamples,TFPhoto,TFPlanar,TFFill,TFPredictor,TFAlpha: Integer;
  TFRowSize,TFCompression: LongInt;
  Metadata: PnTPaintMetadata;
  Black,White: Double;
  Pattern: Array[0..3] Of Byte;
  Neutral: Array[0..2] Of Double;
  Entries: Array[0..255] Of TDNEntry;
 End;
 PDNState = ^TDNState;

Function DNWord(Var D: TDNState; P: LongInt): Word;
Begin
 DNWord:=0; If D.Bad Then Exit;
 If (P<0) Or (P>D.Size-2) Then Begin D.Bad:=True; Exit; End;
 If D.Little Then DNWord:=Word(D.Data^[P]) Or (Word(D.Data^[P+1]) Shl 8)
 Else DNWord:=(Word(D.Data^[P]) Shl 8) Or D.Data^[P+1];
End;

Function DNLong(Var D: TDNState; P: LongInt): LongWord;
Var A,B: LongWord;
Begin
 A:=DNWord(D,P); B:=DNWord(D,P+2);
 If D.Little Then DNLong:=A Or (B Shl 16) Else DNLong:=(A Shl 16) Or B;
End;

Function DNFind(Var D: TDNState; Tag: Word): Integer;
Var I: Integer;
Begin
 DNFind:=-1; For I:=0 To D.EntryCount-1 Do If D.Entries[I].Tag=Tag Then Begin DNFind:=I; Exit; End;
End;

Function DNValue(Var D: TDNState; E: Integer; Index: LongInt): Double;
Var P,Step: LongInt; A,B: LongWord;
Begin
 DNValue:=0;
 If (E<0) Or (E>=D.EntryCount) Then Begin D.Bad:=True; Exit; End;
 With D.Entries[E] Do Begin
  If (Index<0) Or (Index>=Count) Then Begin D.Bad:=True; Exit; End;
  Case Kind Of 1,2,6,7: Step:=1; 3,8: Step:=2; 4,9,11: Step:=4; 5,10,12: Step:=8;
  Else Begin D.Bad:=True; Exit; End; End;
  P:=Offset+Index*Step;
  Case Kind Of
   1,2,7: DNValue:=D.Data^[P];
   3: DNValue:=DNWord(D,P);
   4: DNValue:=DNLong(D,P);
   5,10: Begin
    A:=DNLong(D,P); B:=DNLong(D,P+4);
    If B=0 Then Begin D.Bad:=True; Exit; End;
    If Kind=10 Then DNValue:=LongInt(A)/(LongInt(B)*1.0) Else DNValue:=A/(B*1.0);
   End;
  Else D.Bad:=True;
  End;
 End;
End;

Function DNScalar(Var D: TDNState; Tag: Word; Default: Double): Double;
Var E: Integer;
Begin
 E:=DNFind(D,Tag); DNScalar:=Default;
 If E>=0 Then Begin
  If D.Entries[E].Count<>1 Then D.Bad:=True Else DNScalar:=DNValue(D,E,0);
 End;
End;

Function DNDirectory(Var D: TDNState): Boolean;
Var N,I,J,K,Step: Integer; P,Bytes: LongInt; V: LongWord; S: String;
Begin
 DNDirectory:=False;
 If D.Size<8 Then Exit;
 D.Little:=(D.Data^[0]=73) And (D.Data^[1]=73);
 If Not D.Little And Not ((D.Data^[0]=77) And (D.Data^[1]=77)) Then Exit;
 If DNWord(D,2)<>42 Then Exit;
 V:=DNLong(D,4); If V>LongWord(D.Size-2) Then Exit; D.IFD:=V;
 If D.CR2Mode Then Begin
  If (D.Size<16) Or (D.IFD<16) Then Exit;
  If (D.Data^[8]<>Ord('C')) Or (D.Data^[9]<>Ord('R')) Or
     (D.Data^[10]<>2) Or (D.Data^[11]<>0) Then Exit;
  V:=DNLong(D,12);
  { Un seul IFD CFA natif : un IFD RAW distinct exige un autre decodeur. }
  If (V<>0) And (V<>LongWord(D.IFD)) Then Exit;
 End;
 N:=DNWord(D,D.IFD); If (N<1) Or (N>256) Or (LongInt(N)*12+6>D.Size-D.IFD) Then Exit;
 { Reparation limitee a la signature exacte du convertisseur historique. }
 If D.Little And (D.IFD=8) And (N=30) And (D.Size>=422) Then Begin
  If (DNWord(D,370)=50721) And (DNWord(D,372)=10) And (DNLong(D,374)=9) And
     (DNWord(D,382)=50728) And (DNWord(D,384)=5) And (DNLong(D,386)=3) And
     (DNWord(D,394)=50778) And (DNWord(D,396)=3) And (DNLong(D,398)=1) And
     (DNWord(D,406)=50827) And (DNWord(D,408)=2) And (DNLong(D,410)=28) And
     (DNLong(D,418)=0) Then Begin
   S:='';
   For I:=0 To 29 Do If DNWord(D,10+LongInt(I)*12)=305 Then Begin
    P:=DNLong(D,18+LongInt(I)*12)+48;
    If (P>=0) And (P<=D.Size-18) Then For J:=0 To 17 Do S:=S+Chr(D.Data^[P+J]);
   End;
   If S='CloneDRAW BMP2DNG'#0 Then Begin N:=34; D.Fixup:=48; End;
  End;
 End;
 { Cette lecture prend en charge un seul IFD CFA, sans chaine de pages. }
 V:=DNLong(D,D.IFD+2+LongInt(N)*12);
 If D.TIFFMode Then Begin
  If (V<>0) And ((V=LongWord(D.IFD)) Or
     (V>LongWord(D.Size-2))) Then Exit;
 End Else If V<>0 Then Exit;
 D.EntryCount:=N;
 For I:=0 To N-1 Do Begin
  P:=D.IFD+2+LongInt(I)*12;
  With D.Entries[I] Do Begin
   Tag:=DNWord(D,P); Kind:=DNWord(D,P+2); V:=DNLong(D,P+4);
   If (V=0) Or (V>LongWord(D.Size)) Then Exit; Count:=V;
   For J:=0 To I-1 Do If D.Entries[J].Tag=Tag Then Exit;
   Case Kind Of 1,2,6,7: Step:=1; 3,8: Step:=2; 4,9,11,13: Step:=4; 5,10,12: Step:=8;
   Else Exit; End;
   If Count>D.Size Div Step Then Exit; Bytes:=Count*Step;
   If Bytes<=4 Then Offset:=P+8 Else Begin
    V:=DNLong(D,P+8); If V>LongWord(D.Size-D.Fixup) Then Exit; Offset:=LongInt(V)+D.Fixup;
   End;
   If (Offset<0) Or (Offset>D.Size-Bytes) Then Exit;
  End;
 End;
 If Not D.CR2Mode And Not D.TIFFMode Then Begin
  K:=DNFind(D,50706); If K<0 Then Exit;
  If (D.Entries[K].Kind<>1) Or (D.Entries[K].Count<>4) Or (DNValue(D,K,0)<>1) Then Exit;
 End;
 DNDirectory:=Not D.Bad;
End;

{ BMP2ARW.PAS choisit la couleur CFA avec l'indice de ligne BMP,
  dont la parite est opposee a la ligne de sortie lorsque la hauteur est paire.
  Ne corriger que le producteur identifie ; respecter les tags des autres TIFF. }
Function DNCloneRaw(Var D: TDNState; Const Producer: String): Boolean;
Var E,I: Integer; S: String;
Begin
 DNCloneRaw:=False; E:=DNFind(D,305); If E<0 Then Exit;
 If (D.Entries[E].Kind<>2) Or (D.Entries[E].Count<>18) Then Exit;
 S:=''; For I:=0 To 17 Do S:=S+Chr(D.Data^[D.Entries[E].Offset+I]);
 DNCloneRaw:=S='CloneDRAW '+Producer+#0;
End;

Function DNDecode(Var D: TDNState): Boolean;
Var E,F,I,J,X,Y,C,DX,DY,N,XX,YY,OX,OY,W,H,Value,Orientation: Integer;
    Rows,StripCount,Strip,Offset,Count,Needed,Pixel,P,Sum: LongInt;
    V,A: Double;
Begin
 DNDecode:=False;
 V:=DNScalar(D,256,0); If (V<1) Or (V>4096) Then Exit; D.Width:=Round(V);
 V:=DNScalar(D,257,0); If (V<1) Or (V>4096) Then Exit; D.Height:=Round(V);
 V:=DNScalar(D,258,0); If (V<>8) And (V<>16) Then Exit; D.Bits:=Round(V);
 If (DNScalar(D,259,1)<>1) Or (DNScalar(D,262,0)<>32803) Or
    (DNScalar(D,277,1)<>1) Or (DNScalar(D,284,1)<>1) Or
    (DNScalar(D,339,1)<>1) Or (DNScalar(D,50711,1)<>1) Or
    (DNScalar(D,266,1)<>1) Then Exit;
 V:=DNScalar(D,274,1); If (V<1) Or (V>8) Then Exit; D.Orientation:=Round(V);
 E:=DNFind(D,33421); If (E<0) Then Exit;
 If (D.Entries[E].Count<>2) Or (DNValue(D,E,0)<>2) Or (DNValue(D,E,1)<>2) Then Exit;
 E:=DNFind(D,33422); If E<0 Then Exit; If D.Entries[E].Count<>4 Then Exit;
 For I:=0 To 3 Do Begin V:=DNValue(D,E,I); If (V<0) Or (V>2) Then Exit; D.Pattern[I]:=Round(V); End;
 { Les quatre motifs Bayer RGB : rouge/bleu opposes et deux verts. }
 For C:=0 To 2 Do Begin
  N:=0; For I:=0 To 3 Do If D.Pattern[I]=C Then Inc(N);
  If ((C=1) And (N<>2)) Or ((C<>1) And (N<>1)) Then Exit;
 End;
 If D.Pattern[0]=1 Then Begin If D.Pattern[3]<>1 Then Exit; End
 Else If (D.Pattern[3]=1) Or (D.Pattern[0]=D.Pattern[3]) Then Exit;
 If ((D.Height And 1)=0) And
    ((D.ARWMode And DNCloneRaw(D,'BMP2ARW')) Or
     (D.CR2Mode And DNCloneRaw(D,'BMP2CR2'))) Then Begin
  I:=D.Pattern[0]; D.Pattern[0]:=D.Pattern[2]; D.Pattern[2]:=I;
  I:=D.Pattern[1]; D.Pattern[1]:=D.Pattern[3]; D.Pattern[3]:=I;
 End;
 E:=DNFind(D,50710); If E>=0 Then Begin
  If D.Entries[E].Count<>3 Then Exit;
  For I:=0 To 2 Do If DNValue(D,E,I)<>I Then Exit;
 End;
 E:=DNFind(D,50721); If E>=0 Then Begin
  If D.Entries[E].Count<>9 Then Exit;
  For I:=0 To 8 Do Begin V:=DNValue(D,E,I); If I Mod 4=0 Then A:=1 Else A:=0; If Abs(V-A)>0.000001 Then Exit; End;
 End;
 For I:=0 To 2 Do D.Neutral[I]:=1;
 E:=DNFind(D,50728); If E>=0 Then Begin
  If D.Entries[E].Count<>3 Then Exit;
  For I:=0 To 2 Do Begin V:=DNValue(D,E,I); If (V<0.000001) Or (V>1000000) Then Exit; D.Neutral[I]:=V; End;
 End;
 D.Black:=DNScalar(D,50714,0); If D.Bits=8 Then V:=255 Else V:=65535;
 D.White:=DNScalar(D,50717,V);
 If (D.Black<0) Or (D.White>V) Or (D.White<=D.Black) Then Exit;
 V:=DNScalar(D,278,D.Height); If (V<1) Or (V>2147483647.0) Then Exit; Rows:=Round(V);
 StripCount:=(D.Height-1) Div Rows+1;
 E:=DNFind(D,273); F:=DNFind(D,279); If (E<0) Or (F<0) Then Exit;
 If (D.Entries[E].Count<>StripCount) Or (D.Entries[F].Count<>StripCount) Or D.Bad Then Exit;
 D.RawSize:=LongInt(D.Width)*D.Height*2; D.Raw:=PPNBytes(JDAllocate(D.RawSize)); If D.Raw=Nil Then Exit;
 For Strip:=0 To StripCount-1 Do Begin
  V:=DNValue(D,E,Strip); If (V<0) Or (V>D.Size-D.Fixup) Then Exit; Offset:=Round(V)+D.Fixup;
  V:=DNValue(D,F,Strip); If (V<0) Or (V>D.Size-Offset) Then Exit; Count:=Round(V);
  Needed:=Rows; If Needed>D.Height-Strip*Rows Then Needed:=D.Height-Strip*Rows;
  Needed:=Needed*D.Width*(D.Bits Div 8); If Count<>Needed Then Exit;
  For Pixel:=0 To Needed Div (D.Bits Div 8)-1 Do Begin
   P:=Offset+Pixel*(D.Bits Div 8);
   If D.Bits=8 Then Value:=D.Data^[P] Else Begin
    { Word peut depasser Integer (mode TP). Copier les octets directement. }
    If D.Little Then Begin D.Raw^[(Strip*Rows*D.Width+Pixel)*2]:=D.Data^[P]; D.Raw^[(Strip*Rows*D.Width+Pixel)*2+1]:=D.Data^[P+1]; End
    Else Begin D.Raw^[(Strip*Rows*D.Width+Pixel)*2]:=D.Data^[P+1]; D.Raw^[(Strip*Rows*D.Width+Pixel)*2+1]:=D.Data^[P]; End;
   End;
   If D.Bits=8 Then Begin D.Raw^[(Strip*Rows*D.Width+Pixel)*2]:=Value; D.Raw^[(Strip*Rows*D.Width+Pixel)*2+1]:=0; End;
  End;
 End;
 W:=D.Width; H:=D.Height; Orientation:=D.Orientation;
 D.OutWidth:=W; D.OutHeight:=H; If Orientation>=5 Then Begin D.OutWidth:=H; D.OutHeight:=W; End;
 D.RGBSize:=LongInt(W)*H*3; D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
  OX:=X; OY:=Y;
  Case Orientation Of
   2: OX:=W-1-X; 3: Begin OX:=W-1-X; OY:=H-1-Y; End; 4: OY:=H-1-Y;
   5: Begin OX:=Y; OY:=X; End; 6: Begin OX:=H-1-Y; OY:=X; End;
   7: Begin OX:=H-1-Y; OY:=W-1-X; End; 8: Begin OX:=Y; OY:=W-1-X; End;
  End;
  For C:=0 To 2 Do Begin
   Sum:=0; N:=0;
   If D.Pattern[(Y And 1)*2+(X And 1)]=C Then Begin
    P:=(LongInt(Y)*W+X)*2; Sum:=LongInt(D.Raw^[P])+LongInt(D.Raw^[P+1])*256; N:=1;
   End Else For DY:=-1 To 1 Do For DX:=-1 To 1 Do Begin
    XX:=X+DX; YY:=Y+DY;
    If (XX>=0) And (XX<W) And (YY>=0) And (YY<H) Then
     If D.Pattern[(YY And 1)*2+(XX And 1)]=C Then Begin
      P:=(LongInt(YY)*W+XX)*2; Inc(Sum,LongInt(D.Raw^[P])+LongInt(D.Raw^[P+1])*256); Inc(N);
     End;
   End;
   V:=0; If N>0 Then V:=(Sum/(N*1.0)-D.Black)/(D.White-D.Black)/D.Neutral[C];
   If V<0 Then V:=0; If V>1 Then V:=1;
   D.RGB^[(LongInt(OY)*D.OutWidth+OX)*3+C]:=Round(V*255);
  End;
 End;
 DNDecode:=Not D.Bad;
End;

Function DNReadDirectory(Const Name: String; Var D: TDNState): Boolean;
Var F: File; OldMode: Byte; Bytes: LongInt; Failed: Boolean;
Begin
 DNReadDirectory:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=8) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}Failed:=(IOResult<>0) Or (Bytes<>D.Size); End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Then Exit;
 DNReadDirectory:=DNDirectory(D);
End;

Function DNRead(Const Name: String; Var D: TDNState): Boolean;
Begin
 DNRead:=False;
 If DNReadDirectory(Name,D) Then DNRead:=DNDecode(D);
End;

Function LoadDNG(FileName: String): Boolean;
Var D: PDNState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadDNG:=False; Pixels:=Nil; Q:=Nil;
 D:=PDNState(JDAllocate(SizeOf(TDNState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If DNRead(FileName,D^) Then Begin
  Size:=LongInt(D^.OutWidth)*D^.OutHeight; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=16; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.OutWidth; Img.Height:=D^.OutHeight; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.OutWidth; PnCanvasImageH:=D^.OutHeight;
   PnImageBuffer.Width:=D^.OutWidth; PnImageBuffer.Height:=D^.OutHeight; PnImageBuffer.BitDepth:=24;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_DNG; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadDNG:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Raw<>Nil Then FreeMem(D^.Raw,D^.RawSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TDNState));
End;

{ CR2 minimal de BMP2CR2.PAS : TIFF/CFA natif, pas de JPEG sans perte
  proprietaire Canon, de MakerNotes interpretees ou de RAW IFD distinct. }
Function CRRead(Const Name: String; Var D: TDNState): Boolean;
Begin
 D.CR2Mode:=True; CRRead:=DNRead(Name,D);
End;

Function LoadCR2(FileName: String): Boolean;
Var D: PDNState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadCR2:=False; Pixels:=Nil; Q:=Nil;
 D:=PDNState(JDAllocate(SizeOf(TDNState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If CRRead(FileName,D^) Then Begin
  Size:=LongInt(D^.OutWidth)*D^.OutHeight; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=16; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.OutWidth; Img.Height:=D^.OutHeight; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.OutWidth; PnCanvasImageH:=D^.OutHeight;
   PnImageBuffer.Width:=D^.OutWidth; PnImageBuffer.Height:=D^.OutHeight; PnImageBuffer.BitDepth:=24;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_CR2; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadCR2:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Raw<>Nil Then FreeMem(D^.Raw,D^.RawSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TDNState));
End;

{ Lecture ARW minimal de BMP2ARW.PAS. Les RAW Sony proprietaires,
  compresses, avec MakerNotes ou sans les tags CFA/DNG requis sont refuses. }
Function ARRead(Const Name: String; Var D: TDNState): Boolean;
Begin
 D.ARWMode:=True; ARRead:=DNRead(Name,D);
End;

Function LoadARW(FileName: String): Boolean;
Var D: PDNState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadARW:=False; Pixels:=Nil; Q:=Nil;
 D:=PDNState(JDAllocate(SizeOf(TDNState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If ARRead(FileName,D^) Then Begin
  Size:=LongInt(D^.OutWidth)*D^.OutHeight; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=16; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.OutWidth; Img.Height:=D^.OutHeight; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.OutWidth; PnCanvasImageH:=D^.OutHeight;
   PnImageBuffer.Width:=D^.OutWidth; PnImageBuffer.Height:=D^.OutHeight; PnImageBuffer.BitDepth:=24;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_ARW; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadARW:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Raw<>Nil Then FreeMem(D^.Raw,D^.RawSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TDNState));
End;



{ BGX1 MonsterBook : entete compacte de 9 octets, lignes de haut en bas,
  sans palette ni padding BMP. Ordre RGB de VIEWBGX / PCX2BGX / XBM2BGX.
  Les convertisseurs BMP2BGX ne signalent pas leur ordre BGR different.
  Palette absente : VGA PAINT (0..15), puis gris de niveau egal a l'indice.
  Les 32 bits sont RGB + octet reserve, sans alpha. 15/16 : RGB555/RGB565. }
Type
 TBGState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize,RowSize: LongInt;
  Width,Height,Bits: Integer;
 End;
 PBGState = ^TBGState;

Function BGRead(Const Name: String; Var D: TBGState): Boolean;
Var F: File; OldMode: Byte; Bytes,P,Dest: LongInt;
    X,Y,Index,Shift,R,G,B: Integer; V: Word; Failed: Boolean;
Begin
 BGRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=9) And (D.Size<=67108873) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Then Exit;
 If (D.Data^[0]<>Ord('B')) Or (D.Data^[1]<>Ord('G')) Or
    (D.Data^[2]<>Ord('X')) Or (D.Data^[3]<>Ord('1')) Then Exit;
 { Lire les dimensions en LongInt avant conversion en Integer 16 bits. }
 Bytes:=LongInt(D.Data^[4])+LongInt(D.Data^[5])*256;
 If (Bytes<1) Or (Bytes>PnMAX_IMAGE_WIDTH) Then Exit; D.Width:=Bytes;
 Bytes:=LongInt(D.Data^[6])+LongInt(D.Data^[7])*256;
 If (Bytes<1) Or (Bytes>PnMAX_IMAGE_HEIGHT) Then Exit; D.Height:=Bytes;
 D.Bits:=D.Data^[8];
 Case D.Bits Of
  1,2,4: D.RowSize:=(LongInt(D.Width)*D.Bits+7) Div 8;
  8: D.RowSize:=D.Width;
  15,16: D.RowSize:=LongInt(D.Width)*2;
  24: D.RowSize:=LongInt(D.Width)*3;
  32: D.RowSize:=LongInt(D.Width)*4;
 Else Exit; End;
 If D.Size<>9+D.RowSize*D.Height Then Exit;
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 Dest:=0;
 For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do Begin
  P:=9+LongInt(Y)*D.RowSize;
  R:=0; G:=0; B:=0;
  Case D.Bits Of
   1,2,4,8: Begin
    If D.Bits=8 Then Index:=D.Data^[P+X] Else Begin
     Shift:=8-D.Bits-((X*D.Bits) And 7);
     Index:=(D.Data^[P+(X*D.Bits) Div 8] Shr Shift) And ((1 Shl D.Bits)-1);
    End;
    If D.Bits=1 Then Begin If Index=1 Then Begin R:=255; G:=255; B:=255; End; End
    Else If Index<16 Then Begin R:=PnVGA_R[Index]; G:=PnVGA_G[Index]; B:=PnVGA_B[Index]; End
    Else Begin R:=Index; G:=Index; B:=Index; End;
   End;
   15,16: Begin
    Inc(P,LongInt(X)*2); V:=Word(D.Data^[P]) Or (Word(D.Data^[P+1]) Shl 8);
    If D.Bits=15 Then Begin R:=((V Shr 10) And 31)*255 Div 31; G:=((V Shr 5) And 31)*255 Div 31; End
    Else Begin R:=((V Shr 11) And 31)*255 Div 31; G:=((V Shr 5) And 63)*255 Div 63; End;
    B:=(V And 31)*255 Div 31;
   End;
   24,32: Begin Inc(P,LongInt(X)*(D.Bits Div 8)); R:=D.Data^[P]; G:=D.Data^[P+1]; B:=D.Data^[P+2]; End;
  End;
  D.RGB^[Dest]:=R; D.RGB^[Dest+1]:=G; D.RGB^[Dest+2]:=B; Inc(Dest,3);
 End;
 BGRead:=True;
End;

Function LoadBGX(FileName: String): Boolean;
Var D: PBGState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadBGX:=False; Pixels:=Nil; Q:=Nil;
 D:=PBGState(JDAllocate(SizeOf(TBGState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If BGRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=D^.Bits;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_BGX; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadBGX:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TBGState));
End;



{ DDS classique 2D : RGB a masques, DXT1/3/5. Texture principale seulement.
  Alpha compose sur blanc ; pas de DX10, cubemap, volume ni tableaux.
  Decodage integre, aucun appel a DirectDraw ni bibliotheque externe. }
Type
 TDSState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize,Pitch,BaseSize: LongInt;
  Width,Height,Bits,Mode,BlockSize: Integer;
  Masks: Array[0..3] Of LongWord;
  Shifts: Array[0..3] Of Integer;
  Maximum: Array[0..3] Of LongWord;
  Alpha,Bad: Boolean;
 End;
 PDSState = ^TDSState;

Function DSLong(Var D: TDSState; P: LongInt): LongWord;
Var I: Integer; V: LongWord;
Begin
 DSLong:=0; If D.Bad Then Exit;
 If (P<0) Or (P>D.Size-4) Then Begin D.Bad:=True; Exit; End;
 V:=0; For I:=0 To 3 Do V:=V Or (LongWord(D.Data^[P+I]) Shl (I*8)); DSLong:=V;
End;

Procedure DSPixel(Var D: TDSState; X,Y,R,G,B,A: Integer);
Var P: LongInt;
Begin
 If (X>=D.Width) Or (Y>=D.Height) Then Exit;
 P:=(LongInt(Y)*D.Width+X)*3;
 D.RGB^[P]:=(LongInt(R)*A+LongInt(255)*(255-A)+127) Div 255;
 D.RGB^[P+1]:=(LongInt(G)*A+LongInt(255)*(255-A)+127) Div 255;
 D.RGB^[P+2]:=(LongInt(B)*A+LongInt(255)*(255-A)+127) Div 255;
End;

Function DSHeader(Var D: TDSState): Boolean;
Var Flags,PF,FourCC,V,Used,Mask: LongWord; I,J,Mips,W,H: Integer; Needed,Part,Row: LongInt;
Begin
 DSHeader:=False;
 If D.Size<128 Then Exit;
 If (DSLong(D,0)<>$20534444) Or (DSLong(D,4)<>124) Or (DSLong(D,76)<>32) Then Exit;
 Flags:=DSLong(D,8); If (Flags And $1007)<>$1007 Then Exit;
 V:=DSLong(D,16); If (V<1) Or (V>PnMAX_IMAGE_WIDTH) Then Exit; D.Width:=V;
 V:=DSLong(D,12); If (V<1) Or (V>PnMAX_IMAGE_HEIGHT) Then Exit; D.Height:=V;
 If (DSLong(D,108) And $1000)=0 Then Exit;
 If (DSLong(D,112)<>0) Or (DSLong(D,24)>1) Then Exit;
 PF:=DSLong(D,80); FourCC:=DSLong(D,84);
 If (PF And 4)<>0 Then Begin
  If (PF And Not LongWord(5))<>0 Then Exit;
  Case FourCC Of
   $31545844: Begin D.Mode:=1; D.BlockSize:=8; End; { DXT1 }
   $33545844: Begin D.Mode:=3; D.BlockSize:=16; End; { DXT3 }
   $35545844: Begin D.Mode:=5; D.BlockSize:=16; End; { DXT5 }
  Else Exit; End;
  D.BaseSize:=LongInt((D.Width+3) Div 4)*((D.Height+3) Div 4)*D.BlockSize;
 End Else Begin
  If (PF And $40)=0 Then Exit;
  If (PF And Not LongWord($41))<>0 Then Exit;
  If FourCC<>0 Then Exit;
  V:=DSLong(D,88); If (V<>8) And (V<>16) And (V<>24) And (V<>32) Then Exit; D.Bits:=V;
  D.Alpha:=(PF And 1)<>0; Used:=0;
  For I:=0 To 3 Do Begin
   Mask:=DSLong(D,92+I*4); If (I=3) And Not D.Alpha Then Mask:=0;
   If ((I<3) Or D.Alpha) And (Mask=0) Then Exit;
   If (D.Bits<32) And ((Mask Shr D.Bits)<>0) Then Exit;
   If (Used And Mask)<>0 Then Exit; Used:=Used Or Mask;
   D.Masks[I]:=Mask; D.Shifts[I]:=0;
   If Mask<>0 Then Begin
    While (Mask And 1)=0 Do Begin Mask:=Mask Shr 1; Inc(D.Shifts[I]); End;
    { Masque contigu, sans addition susceptible de deborder. }
    D.Maximum[I]:=Mask;
    While (Mask And 1)<>0 Do Mask:=Mask Shr 1;
    If Mask<>0 Then Exit;
   End;
  End;
  Row:=LongInt(D.Width)*(D.Bits Div 8); D.Pitch:=Row;
  If (Flags And 8)<>0 Then Begin
   V:=DSLong(D,20); If (V<LongWord(Row)) Or (V>1048576) Then Exit; D.Pitch:=V;
  End;
  If D.Pitch>(D.Size-128) Div D.Height Then Exit;
  D.BaseSize:=D.Pitch*D.Height;
 End;
 If D.BaseSize>D.Size-128 Then Exit;
 { Verifier aussi les niveaux annonces, puis afficher uniquement le premier. }
 V:=DSLong(D,28); If V>13 Then Exit; Mips:=V; If Mips=0 Then Mips:=1;
 W:=D.Width; H:=D.Height; Needed:=D.BaseSize;
 For J:=2 To Mips Do Begin
  If (W=1) And (H=1) Then Exit;
  W:=PnMax(1,W Div 2); H:=PnMax(1,H Div 2);
  If D.Mode<>0 Then Part:=LongInt((W+3) Div 4)*((H+3) Div 4)*D.BlockSize
  Else Part:=LongInt(W)*H*(D.Bits Div 8);
  If Part>D.Size-128-Needed Then Exit; Inc(Needed,Part);
 End;
 If D.Bad Then Exit;
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); DSHeader:=D.RGB<>Nil;
End;

Procedure DSRaw(Var D: TDSState);
Var X,Y,I,J: Integer; P: LongInt; V: LongWord; Color: Array[0..3] Of Integer;
Begin
 For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do Begin
  P:=128+LongInt(Y)*D.Pitch+LongInt(X)*(D.Bits Div 8); V:=0;
  For J:=0 To D.Bits Div 8-1 Do V:=V Or (LongWord(D.Data^[P+J]) Shl (J*8));
  For I:=0 To 2 Do Color[I]:=Round(((V And D.Masks[I]) Shr D.Shifts[I])/(D.Maximum[I]*1.0)*255);
  Color[3]:=255;
  If D.Alpha Then Color[3]:=Round(((V And D.Masks[3]) Shr D.Shifts[3])/(D.Maximum[3]*1.0)*255);
  DSPixel(D,X,Y,Color[0],Color[1],Color[2],Color[3]);
 End;
End;

Procedure DSBlocks(Var D: TDSState);
Var BX,BY,X,Y,I,C,Index,A,BitIndex,Shift,ByteIndex,T: Integer;
    P,CP: LongInt; V0,V1: Word; V,Indices: LongWord;
    Colors: Array[0..3,0..2] Of Integer; Alphas: Array[0..7] Of Integer;
Begin
 P:=128;
 For BY:=0 To (D.Height+3) Div 4-1 Do For BX:=0 To (D.Width+3) Div 4-1 Do Begin
  CP:=P; If D.Mode<>1 Then Inc(CP,8);
  V:=DSLong(D,CP); V0:=V And $FFFF; V1:=V Shr 16;
  For I:=0 To 1 Do Begin
   If I=0 Then V:=V0 Else V:=V1;
   T:=(V Shr 11) And 31; Colors[I,0]:=(T Shl 3) Or (T Shr 2);
   T:=(V Shr 5) And 63; Colors[I,1]:=(T Shl 2) Or (T Shr 4);
   T:=V And 31; Colors[I,2]:=(T Shl 3) Or (T Shr 2);
  End;
  For C:=0 To 2 Do
   If (D.Mode<>1) Or (V0>V1) Then Begin
    Colors[2,C]:=(2*Colors[0,C]+Colors[1,C]) Div 3;
    Colors[3,C]:=(Colors[0,C]+2*Colors[1,C]) Div 3;
   End Else Begin Colors[2,C]:=(Colors[0,C]+Colors[1,C]) Div 2; Colors[3,C]:=0; End;
  If D.Mode=5 Then Begin
   Alphas[0]:=D.Data^[P]; Alphas[1]:=D.Data^[P+1];
   If Alphas[0]>Alphas[1] Then
    For I:=2 To 7 Do Alphas[I]:=((8-I)*Alphas[0]+(I-1)*Alphas[1]) Div 7
   Else Begin
    For I:=2 To 5 Do Alphas[I]:=((6-I)*Alphas[0]+(I-1)*Alphas[1]) Div 5;
    Alphas[6]:=0; Alphas[7]:=255;
   End;
  End;
  Indices:=DSLong(D,CP+4);
  For Y:=0 To 3 Do For X:=0 To 3 Do Begin
   I:=Y*4+X; Index:=(Indices Shr (I*2)) And 3; A:=255;
   Case D.Mode Of
    1: If (V0<=V1) And (Index=3) Then A:=0;
    3: A:=((D.Data^[P+I Div 2] Shr ((I And 1)*4)) And 15)*17;
    5: Begin
     BitIndex:=I*3; ByteIndex:=BitIndex Div 8; Shift:=BitIndex And 7;
     T:=D.Data^[P+2+ByteIndex];
     If ByteIndex<5 Then T:=T Or (Integer(D.Data^[P+3+ByteIndex]) Shl 8);
     A:=Alphas[(T Shr Shift) And 7];
    End;
   End;
   DSPixel(D,BX*4+X,BY*4+Y,Colors[Index,0],Colors[Index,1],Colors[Index,2],A);
  End;
  Inc(P,D.BlockSize);
 End;
End;

Function DSRead(Const Name: String; Var D: TDSState): Boolean;
Var F: File; OldMode: Byte; Bytes: LongInt; Failed: Boolean;
Begin
 DSRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=128) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}Failed:=(IOResult<>0) Or (Bytes<>D.Size); End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Or Not DSHeader(D) Then Exit;
 If D.Mode=0 Then DSRaw(D) Else DSBlocks(D);
 DSRead:=Not D.Bad;
End;

Function LoadDDS(FileName: String): Boolean;
Var D: PDSState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadDDS:=False; Pixels:=Nil; Q:=Nil;
 D:=PDSState(JDAllocate(SizeOf(TDSState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If DSRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=24;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_DDS; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadDDS:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TDSState));
End;



{ DICOM Part 10 : Explicit VR Little Endian, RGB natif non compresse,
  RGB entrelace/planaire ou MONOCHROME1/2 non signe 8/16 bits, une image.
  Les metadonnees textuelles sont ignorees, jamais executees ni affichees.
  Pas de flux encapsule JPEG/RLE, VR implicite, sequences indefinies ou cine. }
Type
 TDCState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize,PixelStart,PixelLength: LongInt;
  Width,Height,Bits,Stored,HighBit,Planar,Samples: Integer;
  Bad,Mono,Invert: Boolean;
 End;
 PDCState = ^TDCState;

Function DCWord(Var D: TDCState; P: LongInt): Word;
Begin
 DCWord:=0; If D.Bad Then Exit;
 If (P<0) Or (P>D.Size-2) Then Begin D.Bad:=True; Exit; End;
 DCWord:=Word(D.Data^[P]) Or (Word(D.Data^[P+1]) Shl 8);
End;

Function DCLong(Var D: TDCState; P: LongInt): LongWord;
Var A,B: LongWord;
Begin
 A:=DCWord(D,P); B:=DCWord(D,P+2); DCLong:=A Or (B Shl 16);
End;

Function DCText(Var D: TDCState; P,N: LongInt): String;
Var S: String; I: Integer;
Begin
 DCText:='';
 If (P<0) Or (N<0) Or (N>255) Or (P>D.Size-N) Then Begin D.Bad:=True; Exit; End;
 S:=''; For I:=0 To N-1 Do S:=S+Chr(D.Data^[P+I]);
 While Length(S)>0 Do
  If S[Length(S)] In [' ',#0] Then Delete(S,Length(S),1) Else Break;
 DCText:=S;
End;

Function DCHeader(Var D: TDCState): Boolean;
Var P,Payload,Count,Elements,Frames: LongInt; Len: LongWord;
    Group,Element,V: Word; VR,S,Transfer: String; Tag: LongWord;
    Seen,Flag: LongWord; DataSet,FoundTransfer,PixelFound,Transforms: Boolean;
Begin
 DCHeader:=False; If D.Size<144 Then Exit;
 If DCText(D,128,4)<>'DICM' Then Exit;
 P:=132; Seen:=0; Elements:=0; Frames:=1;
 DataSet:=False; FoundTransfer:=False; PixelFound:=False; Transfer:=''; Transforms:=False;
 D.HighBit:=-1; D.Planar:=0;
 While P<D.Size Do Begin
  Inc(Elements); If (Elements>65536) Or (P>D.Size-8) Then Exit;
  Group:=DCWord(D,P); Element:=DCWord(D,P+2);
  If Group=$FFFE Then Exit;
  If Group<>2 Then Begin
   If Not FoundTransfer Or (Transfer<>'1.2.840.10008.1.2.1') Then Exit;
   DataSet:=True;
  End Else If DataSet Then Exit;
  VR:=DCText(D,P+4,2);
  If Pos('|'+VR+'|','|AE|AS|AT|CS|DA|DS|DT|FD|FL|IS|LO|LT|OB|OD|OF|OL|OV|OW|PN|SH|SL|SQ|SS|ST|SV|TM|UC|UI|UL|UN|UR|US|UT|UV|')=0 Then Exit;
  If Pos('|'+VR+'|','|OB|OD|OF|OL|OV|OW|SQ|UC|UN|UR|UT|')>0 Then Begin
   If P>D.Size-12 Then Exit;
   If DCWord(D,P+6)<>0 Then Exit;
   Len:=DCLong(D,P+8); Payload:=P+12;
  End Else Begin Len:=DCWord(D,P+6); Payload:=P+8; End;
  { Inclut le rejet des longueurs indefinies $FFFFFFFF et des depassements. }
  If D.Bad Or (Len>LongWord(D.Size-Payload)) Or ((Len And 1)<>0) Then Exit;
  Count:=Len; Tag:=(LongWord(Group) Shl 16) Or Element; Flag:=0;
  If Tag=$00020010 Then Begin
   If FoundTransfer Or (VR<>'UI') Then Exit;
   Transfer:=DCText(D,Payload,Count); FoundTransfer:=True;
  End;
  If (Tag=$00281050) Or (Tag=$00281051) Or (Tag=$00281052) Or (Tag=$00281053) Then Transforms:=True;
  Case Tag Of
   $00280002: Flag:=1;
   $00280004: Flag:=2;
   $00280006: Flag:=4;
   $00280008: Flag:=8;
   $00280010: Flag:=16;
   $00280011: Flag:=32;
   $00280100: Flag:=64;
   $00280101: Flag:=128;
   $00280102: Flag:=256;
   $00280103: Flag:=512;
   $7FE00010: Flag:=1024;
  End;
  If Flag<>0 Then Begin
   If (Seen And Flag)<>0 Then Exit; Seen:=Seen Or Flag;
   If (Flag<>2) And (Flag<>8) And (Flag<>1024) Then Begin
    If (VR<>'US') Or (Count<>2) Then Exit; V:=DCWord(D,Payload);
   End;
   Case Tag Of
    $00280002: Begin If (V<>1) And (V<>3) Then Exit; D.Samples:=V; End;
    $00280004: Begin
     If VR<>'CS' Then Exit; S:=DCText(D,Payload,Count);
     If (S<>'RGB') And (S<>'MONOCHROME1') And (S<>'MONOCHROME2') Then Exit;
     D.Mono:=S<>'RGB'; D.Invert:=S='MONOCHROME1';
    End;
    $00280006: Begin If V>1 Then Exit; D.Planar:=V; End;
    $00280008: Begin
     If VR<>'IS' Then Exit; S:=DCText(D,Payload,Count);
     If S<>'1' Then Exit; Frames:=1;
    End;
    $00280010: Begin If (V<1) Or (V>PnMAX_IMAGE_HEIGHT) Then Exit; D.Height:=V; End;
    $00280011: Begin If (V<1) Or (V>PnMAX_IMAGE_WIDTH) Then Exit; D.Width:=V; End;
    $00280100: Begin If (V<>8) And (V<>16) Then Exit; D.Bits:=V; End;
    $00280101: Begin If (V<1) Or (V>16) Then Exit; D.Stored:=V; End;
    $00280102: Begin If V>15 Then Exit; D.HighBit:=V; End;
    $00280103: If V<>0 Then Exit;
    $7FE00010: Begin
     If (VR<>'OB') And (VR<>'OW') Then Exit;
     PixelFound:=True; D.PixelStart:=Payload; D.PixelLength:=Count;
    End;
   End;
  End;
  P:=Payload+Count;
 End;
 { Tous les attributs du module RGB sont obligatoires, hors NumberOfFrames. }
 If (Seen And 2035)<>2035 Then Exit;
 If D.Mono Then Begin
  If (D.Samples<>1) Or (D.Planar<>0) Or Transforms Then Exit;
 End Else If (D.Samples<>3) Or ((Seen And 4)=0) Then Exit;
 If Not PixelFound Or Not DataSet Or (Frames<>1) Or D.Bad Then Exit;
 If (D.Stored>D.Bits) Or (D.HighBit<>D.Stored-1) Then Exit;
 If (D.Bits=16) And (D.Data^[D.PixelStart-7]<>Ord('W')) Then Exit;
 Count:=LongInt(D.Width)*D.Height*D.Samples*(D.Bits Div 8);
 If D.PixelLength<>Count+(Count And 1) Then Exit;
 DCHeader:=True;
End;

Function DCRead(Const Name: String; Var D: TDCState): Boolean;
Var F: File; OldMode: Byte; Bytes,N,P,Pixels,Component: LongInt;
    Failed: Boolean; C: Integer; V,Mask: LongWord;
Begin
 DCRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=144) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}Failed:=(IOResult<>0) Or (Bytes<>D.Size); End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Or Not DCHeader(D) Then Exit;
 Pixels:=LongInt(D.Width)*D.Height; D.RGBSize:=Pixels*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 Mask:=(LongWord(1) Shl D.Stored)-1;
 For N:=0 To Pixels-1 Do For C:=0 To 2 Do Begin
  If D.Mono Then Component:=N Else
  If D.Planar=0 Then Component:=N*3+C Else Component:=LongInt(C)*Pixels+N;
  P:=D.PixelStart+Component*(D.Bits Div 8);
  If D.Bits=8 Then V:=D.Data^[P] Else V:=DCWord(D,P);
  V:=V And Mask; If D.Invert Then V:=Mask-V;
  D.RGB^[N*3+C]:=Round(V/(Mask*1.0)*255);
 End;
 DCRead:=Not D.Bad;
End;

Function LoadDCM(FileName: String): Boolean;
Var D: PDCState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadDCM:=False; Pixels:=Nil; Q:=Nil;
 D:=PDCState(JDAllocate(SizeOf(TDCState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If DCRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height; PnImageBuffer.BitDepth:=24;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_DCM; PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadDCM:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TDCState));
End;



{ Netpbm : PPM P3/P6 et compatibilite gris P2/P5, 1..65535.
  Commentaires # et espaces dans l'entete ; raster 16 bits big-endian.
  Une image par fichier. Le separateur final n'avale jamais les pixels. }
Type
 TPMState = Record
  Data,RGB: PPNBytes;
  Size,Position,RGBSize: LongInt;
  Width,Height,Channels,BytesPerSample: Integer;
  Maximum: LongInt;
  Binary,Bad: Boolean;
 End;
 PPMState = ^TPMState;

Function PMWhite(B: Byte): Boolean;
Begin
 PMWhite:=B In [9,10,11,12,13,32];
End;

Procedure PMSkip(Var D: TPMState);
Begin
 While D.Position<D.Size Do Begin
  If PMWhite(D.Data^[D.Position]) Then Inc(D.Position)
  Else If D.Data^[D.Position]=35 Then Begin
   While D.Position<D.Size Do Begin
    If D.Data^[D.Position] In [10,13] Then Break;
    Inc(D.Position);
   End;
  End Else Break;
 End;
End;

Function PMNumber(Var D: TPMState; Limit: LongInt): LongInt;
Var V: LongInt; B,N: Integer;
Begin
 PMNumber:=0; If D.Bad Then Exit;
 PMSkip(D); V:=0; N:=0;
 While D.Position<D.Size Do Begin
  B:=D.Data^[D.Position];
  If Not (B In [48..57]) Then Break;
  Inc(N); Dec(B,48);
  If (N>10) Or (V>(Limit-B) Div 10) Then Begin
   D.Bad:=True; Exit;
  End;
  V:=V*10+B; Inc(D.Position);
 End;
 If (N=0) Or (V>Limit) Then Begin D.Bad:=True; Exit; End;
 If D.Position<D.Size Then
  If Not PMWhite(D.Data^[D.Position]) And
     (D.Data^[D.Position]<>35) Then Begin D.Bad:=True; Exit; End;
 PMNumber:=V;
End;

Function PMRead(Const Name: String; Var D: TPMState): Boolean;
Var F: File; OldMode: Byte; Bytes,Needed,N,V: LongInt;
    C,Value: Integer; Failed: Boolean;
Begin
 PMRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=7) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Then Exit;
 If (D.Data^[0]<>80) Or Not (D.Data^[1] In [50,51,53,54]) Then Exit;
 If Not PMWhite(D.Data^[2]) And (D.Data^[2]<>35) Then Exit;
 D.Binary:=D.Data^[1] In [53,54]; D.Channels:=3;
 If D.Data^[1] In [50,53] Then D.Channels:=1;
 D.Position:=2;
 V:=PMNumber(D,PnMAX_IMAGE_WIDTH); If D.Bad Or (V=0) Then Exit;
 D.Width:=V;
 V:=PMNumber(D,PnMAX_IMAGE_HEIGHT); If D.Bad Or (V=0) Then Exit;
 D.Height:=V;
 D.Maximum:=PMNumber(D,65535);
 If D.Bad Or (D.Maximum=0) Then Exit;
 D.BytesPerSample:=1; If D.Maximum>255 Then D.BytesPerSample:=2;
 Needed:=LongInt(D.Width)*D.Height*D.Channels*D.BytesPerSample;
 If D.Binary Then Begin
  If D.Position>=D.Size Then Exit;
  If Not PMWhite(D.Data^[D.Position]) Then Exit;
  Value:=D.Data^[D.Position]; Inc(D.Position);
  { Accepter CRLF tout en preservant un vrai pixel LF apres un CR seul. }
  If (Value=13) And (D.Size-D.Position=Needed+1) Then
   If D.Data^[D.Position]=10 Then Inc(D.Position);
  If D.Size-D.Position<>Needed Then Exit;
 End;
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 For N:=0 To LongInt(D.Width)*D.Height-1 Do Begin
  For C:=0 To D.Channels-1 Do Begin
   If D.Binary Then Begin
    V:=D.Data^[D.Position]; Inc(D.Position);
    If D.BytesPerSample=2 Then Begin
     V:=V*256+D.Data^[D.Position]; Inc(D.Position);
    End;
    If V>D.Maximum Then Exit;
   End Else Begin
    V:=PMNumber(D,D.Maximum); If D.Bad Then Exit;
   End;
   Value:=(V*255+D.Maximum Div 2) Div D.Maximum;
   D.RGB^[N*3+C]:=Value;
  End;
  If D.Channels=1 Then Begin
   D.RGB^[N*3+1]:=D.RGB^[N*3]; D.RGB^[N*3+2]:=D.RGB^[N*3];
  End;
 End;
 If Not D.Binary Then PMSkip(D);
 PMRead:=D.Position=D.Size;
End;

Function LoadPPM(FileName: String): Boolean;
Var D: PPMState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadPPM:=False; Pixels:=Nil; Q:=Nil;
 D:=PPMState(JDAllocate(SizeOf(TPMState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If PMRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
   PnImageBuffer.BitDepth:=D^.Channels*D^.BytesPerSample*8;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_PPM;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadPPM:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TPMState));
End;
{ DIB compact (BMP2DIB / PCX2DIB), avec ou sans BITMAPFILEHEADER.
  CORE/INFO/V2/V3/V4/V5, RGB 1/4/8/16/24/32, BITFIELDS, RLE4/RLE8.
  RLE : https://learn.microsoft.com/windows/win32/gdi/bitmap-compression
  Les profils ICC externes et les rasters JPEG/PNG encapsules sont refuses. }
Type
 TIBState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize,Position,Limit,RowSize,PixelStart: LongInt;
  Width,Height,Bits,Compression,PaletteCount: Integer;
  Palette: PnTPalette;
  Masks,Maximum: Array[0..3] Of LongWord;
  Shifts: Array[0..3] Of Integer;
  TopDown,Bad: Boolean;
 End;
 PIBState = ^TIBState;

Function IBWord(Var D: TIBState; P: LongInt): Word;
Begin
 IBWord:=0; If D.Bad Then Exit;
 If (P<0) Or (P>D.Size-2) Then Begin D.Bad:=True; Exit; End;
 IBWord:=Word(D.Data^[P]) Or (Word(D.Data^[P+1]) Shl 8);
End;

Function IBLong(Var D: TIBState; P: LongInt): LongWord;
Var A,B: LongWord;
Begin
 A:=IBWord(D,P); B:=IBWord(D,P+2); IBLong:=A Or (B Shl 16);
End;

Function IBByte(Var D: TIBState): Integer;
Begin
 IBByte:=0; If D.Bad Then Exit;
 If D.Position>=D.Limit Then Begin D.Bad:=True; Exit; End;
 IBByte:=D.Data^[D.Position]; Inc(D.Position);
End;

Procedure IBIndex(Var D: TIBState; X,Y,Index: Integer);
Var P: LongInt;
Begin
 If D.Bad Then Exit;
 If (X<0) Or (X>=D.Width) Or (Y<0) Or (Y>=D.Height) Or
    (Index<0) Or (Index>=D.PaletteCount) Then Begin
  D.Bad:=True; Exit;
 End;
 If Not D.TopDown Then Y:=D.Height-1-Y;
 P:=(LongInt(Y)*D.Width+X)*3;
 D.RGB^[P]:=D.Palette[Index].R;
 D.RGB^[P+1]:=D.Palette[Index].G;
 D.RGB^[P+2]:=D.Palette[Index].B;
End;

Function IBHeader(Var D: TIBState): Boolean;
Var Base,H,P,Offset,ImageSize,Height: LongInt;
    V,Mask,Used: LongWord; I,J,EntrySize: Integer; Wrapped: Boolean;
Begin
 IBHeader:=False; Base:=0; Offset:=0; Wrapped:=False;
 If D.Size<12 Then Exit;
 If IBWord(D,0)=$4D42 Then Begin
  If D.Size<26 Then Exit;
  Wrapped:=True; Base:=14; V:=IBLong(D,10);
  If V>LongWord(D.Size) Then Exit; Offset:=V;
 End;
 V:=IBLong(D,Base);
 If Not (V In [12,40,52,56,108,124]) Then Exit; H:=V;
 If H>D.Size-Base Then Exit;
 EntrySize:=4; ImageSize:=0;
 If H=12 Then Begin
  D.Width:=0; V:=IBWord(D,Base+4); If (V=0) Or (V>4096) Then Exit;
  D.Width:=V; V:=IBWord(D,Base+6); If (V=0) Or (V>4096) Then Exit;
  D.Height:=V; If IBWord(D,Base+8)<>1 Then Exit;
  D.Bits:=IBWord(D,Base+10); EntrySize:=3;
 End Else Begin
  V:=IBLong(D,Base+4); If (V=0) Or (V>4096) Then Exit;
  D.Width:=V; Height:=LongInt(IBLong(D,Base+8));
  If (Height=0) Or (Height< -4096) Or (Height>4096) Then Exit;
  D.TopDown:=Height<0; D.Height:=Abs(Height);
  If IBWord(D,Base+12)<>1 Then Exit;
  V:=IBWord(D,Base+14); If V>32 Then Exit; D.Bits:=V;
  V:=IBLong(D,Base+16); If V>6 Then Exit; D.Compression:=V;
  V:=IBLong(D,Base+20); If V>LongWord(D.Size) Then Exit;
  ImageSize:=V;
  If H=124 Then
   If (IBLong(D,Base+112)<>0) Or (IBLong(D,Base+116)<>0) Then Exit;
 End;
 If Not (D.Bits In [1,4,8,16,24,32]) Then Exit;
 Case D.Compression Of
  0: ;
  1: If (D.Bits<>8) Or D.TopDown Then Exit;
  2: If (D.Bits<>4) Or D.TopDown Then Exit;
  3,6: If Not (D.Bits In [16,32]) Then Exit;
 Else Exit; End;
 P:=Base+H;
 If D.Bits>=16 Then Begin
  If D.Bits=16 Then Begin
   D.Masks[0]:=$7C00; D.Masks[1]:=$03E0; D.Masks[2]:=$001F;
  End Else Begin
   D.Masks[0]:=$FF0000; D.Masks[1]:=$00FF00; D.Masks[2]:=$0000FF;
  End;
  If D.Compression In [3,6] Then Begin
   If H=40 Then Begin
    J:=3; If D.Compression=6 Then J:=4;
    If D.Size-P<J*4 Then Exit;
    For I:=0 To J-1 Do D.Masks[I]:=IBLong(D,P+I*4);
    Inc(P,J*4);
   End Else Begin
    For I:=0 To 2 Do D.Masks[I]:=IBLong(D,Base+40+I*4);
    If H>=56 Then D.Masks[3]:=IBLong(D,Base+52);
   End;
  End;
  If (D.Compression=6) And (D.Masks[3]=0) Then Exit;
  Used:=0;
  For I:=0 To 3 Do Begin
   Mask:=D.Masks[I]; If (I<3) And (Mask=0) Then Exit;
   If (D.Bits<32) And ((Mask Shr D.Bits)<>0) Then Exit;
   If (Used And Mask)<>0 Then Exit; Used:=Used Or Mask;
   If Mask<>0 Then Begin
    While (Mask And 1)=0 Do Begin
     Mask:=Mask Shr 1; Inc(D.Shifts[I]);
    End;
    D.Maximum[I]:=Mask;
    While (Mask And 1)<>0 Do Mask:=Mask Shr 1;
    If Mask<>0 Then Exit;
   End;
  End;
 End;
 If D.Bits<=8 Then Begin
  V:=0; If H<>12 Then V:=IBLong(D,Base+32);
  If V=0 Then V:=LongWord(1) Shl D.Bits;
  If V>LongWord(1 Shl D.Bits) Then Exit; D.PaletteCount:=V;
  If D.Size-P<D.PaletteCount*EntrySize Then Exit;
  For I:=0 To D.PaletteCount-1 Do Begin
   D.Palette[I].B:=D.Data^[P]; D.Palette[I].G:=D.Data^[P+1];
   D.Palette[I].R:=D.Data^[P+2]; Inc(P,EntrySize);
  End;
 End Else If H<>12 Then Begin
  V:=IBLong(D,Base+32); If V>256 Then Exit;
  If V>LongWord((D.Size-P) Div 4) Then Exit; Inc(P,LongInt(V)*4);
 End;
 If Wrapped Then Begin If Offset<P Then Exit; P:=Offset; End;
 D.PixelStart:=P; D.Position:=P; D.Limit:=D.Size;
 If ImageSize>0 Then Begin
  If ImageSize>D.Size-P Then Exit; D.Limit:=P+ImageSize;
 End;
 D.RowSize:=((LongInt(D.Width)*D.Bits+31) Div 32)*4;
 If D.Compression In [0,3,6] Then
  If D.RowSize>(D.Limit-P) Div D.Height Then Exit;
 If D.Bad Then Exit;
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); IBHeader:=D.RGB<>Nil;
End;

Function IBRLE(Var D: TIBState): Boolean;
Var X,Y,N,V,I,Index,Count,DX,DY: Integer; P: LongInt;
Begin
 IBRLE:=False; X:=0; Y:=0;
 For P:=0 To LongInt(D.Width)*D.Height-1 Do Begin
  D.RGB^[P*3]:=D.Palette[0].R;
  D.RGB^[P*3+1]:=D.Palette[0].G;
  D.RGB^[P*3+2]:=D.Palette[0].B;
 End;
 While Not D.Bad Do Begin
  N:=IBByte(D); V:=IBByte(D); If D.Bad Then Exit;
  If N>0 Then Begin
   If N>D.Width-X Then Exit;
   For I:=0 To N-1 Do Begin
    Index:=V;
    If D.Bits=4 Then Index:=(V Shr (4-((I And 1)*4))) And 15;
    IBIndex(D,X,Y,Index); Inc(X);
   End;
  End Else Case V Of
   0: Begin X:=0; Inc(Y); If Y>D.Height Then Exit; End;
   1: Begin IBRLE:=Not D.Bad; Exit; End;
   2: Begin
    DX:=IBByte(D); DY:=IBByte(D);
    If (DX>=D.Width-X) Or (DY>=D.Height-Y) Then Exit;
    Inc(X,DX); Inc(Y,DY);
   End;
  Else
   N:=V; If N>D.Width-X Then Exit;
   Count:=N; If D.Bits=4 Then Count:=(N+1) Div 2;
   For I:=0 To N-1 Do Begin
    If (D.Bits=8) Or ((I And 1)=0) Then V:=IBByte(D);
    Index:=V;
    If D.Bits=4 Then Index:=(V Shr (4-((I And 1)*4))) And 15;
    IBIndex(D,X,Y,Index); Inc(X);
   End;
   If Odd(Count) Then IBByte(D);
  End;
 End;
End;

Function IBRaster(Var D: TIBState): Boolean;
Var P,N,Dest: LongInt; X,Y,YY,I,Index,A: Integer; V: LongWord;
    Color: Array[0..2] Of Integer;
Begin
 IBRaster:=False;
 If D.Compression In [1,2] Then Begin IBRaster:=IBRLE(D); Exit; End;
 For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do Begin
  P:=D.PixelStart+LongInt(Y)*D.RowSize;
  If D.Bits<=8 Then Begin
   If D.Bits=8 Then Index:=D.Data^[P+X]
   Else Index:=(D.Data^[P+(LongInt(X)*D.Bits) Div 8] Shr
    (8-D.Bits-((X*D.Bits) And 7))) And ((1 Shl D.Bits)-1);
   IBIndex(D,X,Y,Index); If D.Bad Then Exit;
  End Else Begin
   Inc(P,LongInt(X)*(D.Bits Div 8)); V:=0;
   For I:=0 To D.Bits Div 8-1 Do
    V:=V Or (LongWord(D.Data^[P+I]) Shl (I*8));
   For I:=0 To 2 Do
    Color[I]:=Round(((V And D.Masks[I]) Shr D.Shifts[I])/
     (D.Maximum[I]*1.0)*255);
   A:=255;
   If D.Masks[3]<>0 Then
    A:=Round(((V And D.Masks[3]) Shr D.Shifts[3])/
     (D.Maximum[3]*1.0)*255);
   YY:=Y; If Not D.TopDown Then YY:=D.Height-1-Y;
   Dest:=(LongInt(YY)*D.Width+X)*3;
   For I:=0 To 2 Do Begin
    N:=LongInt(Color[I])*A+LongInt(255)*(255-A)+127;
    D.RGB^[Dest+I]:=N Div 255;
   End;
  End;
 End;
 IBRaster:=Not D.Bad;
End;

Function IBRead(Const Name: String; Var D: TIBState): Boolean;
Var F: File; OldMode: Byte; Bytes: LongInt; Failed: Boolean;
Begin
 IBRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=12) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Or Not IBHeader(D) Then Exit;
 IBRead:=IBRaster(D);
End;

Function LoadDIB(FileName: String): Boolean;
Var D: PIBState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadDIB:=False; Pixels:=Nil; Q:=Nil;
 D:=PIBState(JDAllocate(SizeOf(TIBState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If IBRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=16; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
   PnImageBuffer.BitDepth:=D^.Bits;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_DIB;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadDIB:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TIBState));
End;
{ CUR Windows : repertoire, DIB XOR/AND ou PNG, plus grande image.
  Transparence et inversion monochrome composees sur fond blanc.
  https://learn.microsoft.com/windows/win32/menurc/using-cursors
  Les dimensions >=256 de BMP2CUR sont lues dans la ressource DIB. }
Type
 TCUState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize: LongInt;
  Width,Height,Bits,HotX,HotY,Count: Integer;
  Transparent,Icon: Boolean;
 End;
 PCUState = ^TCUState;

Function CUWord(Const D: TCUState; P: LongInt): Word;
Begin
 CUWord:=Word(D.Data^[P]) Or (Word(D.Data^[P+1]) Shl 8);
End;

Function CULong(Const D: TCUState; P: LongInt): LongWord;
Begin
 CULong:=LongWord(CUWord(D,P)) Or (LongWord(CUWord(D,P+2)) Shl 16);
End;

Function CUDIB(Var D: TCUState; Offset,Size: LongInt): Boolean;
Var B: PIBState; H,MaskStart,MaskRow,P,Dest: LongInt;
    X,Y,YY,I: Integer; Alpha,HaveMask: Boolean;
Begin
 CUDIB:=False; B:=PIBState(JDAllocate(SizeOf(TIBState)));
 If B=Nil Then Exit; FillChar(B^,SizeOf(B^),0);
 B^.Size:=Size; B^.Data:=PPNBytes(JDAllocate(Size));
 If B^.Data<>Nil Then Begin
  Move(D.Data^[Offset],B^.Data^,Size); H:=IBLong(B^,0);
  If H=12 Then Begin
   B^.Data^[6]:=(D.Height And 255);
   B^.Data^[7]:=(D.Height Shr 8);
  End Else Begin
   H:=LongInt(IBLong(B^,8));
   If H<0 Then H:=-D.Height Else H:=D.Height;
   Move(H,B^.Data^[8],4);
   H:=0; Move(H,B^.Data^[20],4);
  End;
  If IBHeader(B^) Then Begin
   MaskStart:=B^.PixelStart+B^.RowSize*B^.Height;
   MaskRow:=((LongInt(D.Width)+31) Div 32)*4;
   HaveMask:=MaskRow*D.Height<=Size-MaskStart;
   Alpha:=B^.Masks[3]<>0;
   If (B^.Bits=32) And (B^.Compression=0) Then Begin
    For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do
     If B^.Data^[B^.PixelStart+LongInt(Y)*B^.RowSize+X*4+3]<>0
      Then Alpha:=True;
    If Not HaveMask Then Alpha:=True;
    If Alpha Then Begin
     B^.Masks[3]:=$FF000000; B^.Shifts[3]:=24;
     B^.Maximum[3]:=255;
    End;
   End;
   If (HaveMask Or Alpha) And (HaveMask Or (Size=MaskStart)) And
      IBRaster(B^) Then Begin
    D.Transparent:=False;
    If Alpha Then Begin
     For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do Begin
      P:=B^.PixelStart+LongInt(Y)*B^.RowSize+
       LongInt(X)*(B^.Bits Div 8); H:=0;
      For I:=0 To B^.Bits Div 8-1 Do
       H:=H Or (LongInt(B^.Data^[P+I]) Shl (I*8));
      If (LongWord(H) And B^.Masks[3])<>B^.Masks[3] Then
       D.Transparent:=True;
     End;
    End Else For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do
     If ((B^.Data^[MaskStart+LongInt(Y)*MaskRow+X Div 8] Shr
         (7-(X And 7))) And 1)<>0 Then Begin
      YY:=Y; If Not B^.TopDown Then YY:=D.Height-1-Y;
      Dest:=(LongInt(YY)*D.Width+X)*3;
      For I:=0 To 2 Do
       If D.Icon Then B^.RGB^[Dest+I]:=255
       Else B^.RGB^[Dest+I]:=255-B^.RGB^[Dest+I];
      D.Transparent:=True;
     End;
    D.RGB:=B^.RGB; D.RGBSize:=B^.RGBSize; B^.RGB:=Nil;
    CUDIB:=True;
   End;
  End;
 End;
 If B^.RGB<>Nil Then FreeMem(B^.RGB,B^.RGBSize);
 If B^.Data<>Nil Then FreeMem(B^.Data,B^.Size);
 FreeMem(B,SizeOf(TIBState));
End;

Function CUPNG(Var D: TCUState; Offset,Size: LongInt): Boolean;
Var P: PPNState;
Begin
 CUPNG:=False; P:=PPNState(JDAllocate(SizeOf(TPNState)));
 If P=Nil Then Exit; FillChar(P^,SizeOf(P^),0);
 FillChar(P^.Alpha,SizeOf(P^.Alpha),255); P^.FileSize:=Size;
 P^.FileData:=PPNBytes(JDAllocate(Size));
 If P^.FileData<>Nil Then Begin
  Move(D.Data^[Offset],P^.FileData^,Size);
  If PNParseChunks(P^) Then If PNInflate(P^) Then
   If PNReconstruct(P^) Then Begin
    If (P^.Width=D.Width) And (P^.Height=D.Height) Then Begin
     D.RGB:=P^.RGB; D.RGBSize:=P^.RGBSize; P^.RGB:=Nil;
     D.Transparent:=P^.HasTransparency; CUPNG:=True;
    End;
   End;
 End;
 PNFree(P);
End;

Function CUContainer(Const Name: String; Var D: TCUState;
                     Icon: Boolean): Boolean;
Var F: File; OldMode: Byte; Bytes,P,Offset,Size,BestOffset,BestSize: LongInt;
    W,H,Bits,HX,HY,I,J: Integer; V,Header,Area,BestArea: LongWord;
    Failed,PNG,BestPNG,Usable: Boolean;
Begin
 CUContainer:=False; D.Icon:=Icon; Assign(F,Name); OldMode:=FileMode;
 FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=22) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Then Exit;
 If CUWord(D,0)<>0 Then Exit;
 If Icon Then Begin If CUWord(D,2)<>1 Then Exit; End
 Else If CUWord(D,2)<>2 Then Exit;
 D.Count:=CUWord(D,4);
 If (D.Count<1) Or (D.Count>256) Then Exit;
 If LongInt(D.Count)*16>D.Size-6 Then Exit;
 BestOffset:=0; BestSize:=0; BestArea:=0; BestPNG:=False;
 For I:=0 To D.Count-1 Do Begin
  P:=6+LongInt(I)*16; If D.Data^[P+3]<>0 Then Exit;
  HX:=0; HY:=0;
  If Icon Then Begin
   If CUWord(D,P+4)>1 Then Exit;
   V:=CUWord(D,P+6);
   If Not (V In [0,1,4,8,16,24,32]) Then Exit;
  End Else Begin
   V:=CUWord(D,P+4); If V>4095 Then Exit; HX:=V;
   V:=CUWord(D,P+6); If V>4095 Then Exit; HY:=V;
  End;
  V:=CULong(D,P+8); If (V<12) Or (V>LongWord(D.Size)) Then Exit;
  Size:=V; V:=CULong(D,P+12);
  If (V<LongWord(6+D.Count*16)) Or
     (V>LongWord(D.Size-Size)) Then Exit; Offset:=V;
  PNG:=True;
  For J:=0 To 7 Do If D.Data^[Offset+J]<>PnPNG_SIGNATURE[J]
   Then PNG:=False;
  Usable:=True; Bits:=0; W:=0; H:=0;
  If PNG Then Begin
   If Size<33 Then Exit;
   V:=PNBE(D.Data,Offset+16); If (V=0) Or (V>4096) Then Exit;
   W:=V; V:=PNBE(D.Data,Offset+20);
   If (V=0) Or (V>4096) Then Exit; H:=V; Bits:=32;
  End Else Begin
   Header:=CULong(D,Offset);
   If Header=12 Then Begin
    W:=CUWord(D,Offset+4); V:=CUWord(D,Offset+6);
    Bits:=CUWord(D,Offset+10);
   End Else If Header In [40,52,56,108,124] Then Begin
    If Header>LongWord(Size) Then Exit;
    V:=CULong(D,Offset+4); If (V=0) Or (V>4096) Then Exit;
    W:=V; Bits:=CUWord(D,Offset+14);
    Usable:=CULong(D,Offset+16) In [0,3,6];
    V:=CULong(D,Offset+8);
    If LongInt(V)<0 Then V:=LongWord(-LongInt(V));
   End Else Begin Usable:=False; V:=0; End;
   If Usable Then Begin
    If (W<1) Or (W>4096) Or (V=0) Or (V>8192) Or
       ((V And 1)<>0) Then Exit; H:=V Div 2;
    If Not (Bits In [1,4,8,16,24,32]) Then Usable:=False;
   End;
  End;
  If Usable Then Begin
   If (D.Data^[P]<>0) And (D.Data^[P]<>W) Then Exit;
   If (D.Data^[P+1]<>0) And (D.Data^[P+1]<>H) Then Exit;
   If ((D.Data^[P]=0) And (W<256)) Or
      ((D.Data^[P+1]=0) And (H<256)) Then Exit;
   If (HX>=W) Or (HY>=H) Then Exit;
   Area:=LongWord(W)*H;
   If (Area>BestArea) Or ((Area=BestArea) And (Bits>D.Bits)) Then
   Begin
    BestArea:=Area; BestOffset:=Offset; BestSize:=Size; BestPNG:=PNG;
    D.Width:=W; D.Height:=H; D.Bits:=Bits; D.HotX:=HX; D.HotY:=HY;
   End;
  End;
 End;
 If BestOffset=0 Then Exit;
 If BestPNG Then CUContainer:=CUPNG(D,BestOffset,BestSize)
 Else CUContainer:=CUDIB(D,BestOffset,BestSize);
End;

Function CURead(Const Name: String; Var D: TCUState): Boolean;
Begin CURead:=CUContainer(Name,D,False); End;

Function ICRead(Const Name: String; Var D: TCUState): Boolean;
Begin ICRead:=CUContainer(Name,D,True); End;

Function LoadCUR(FileName: String): Boolean;
Var D: PCUState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadCUR:=False; Pixels:=Nil; Q:=Nil;
 D:=PCUState(JDAllocate(SizeOf(TCUState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If CURead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=16; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
   PnImageBuffer.BitDepth:=D^.Bits;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_CUR;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=D^.Transparent;
   PnImageBuffer.HasHotspot:=True;
   PnImageBuffer.HotspotX:=D^.HotX; PnImageBuffer.HotspotY:=D^.HotY;
   PnImageBuffer.CursorImages:=D^.Count;
   FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0);
   PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadCUR:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TCUState));
End;
{ PCX ZSoft : codage brut/RLE, 1/2/4 bits plans indexes, VGA 8 bits,
  gris 8 bits et RGB 24 bits (trois plans). Aucun decodeur externe.
  Les repetitions sont bornees a une ligne complete, plans compris. }
Type
 TPXState = Record
  Data,Row,RGB: PPNBytes;
  Size,Position,Limit,RowBytes,RowSize,RGBSize: LongInt;
  Width,Height,Bits,Planes,Encoding,Depth: Integer;
  Palette: PnTPalette;
 End;
 PPXState = ^TPXState;

Function PXWord(Const D: TPXState; P: LongInt): Word;
Begin
 PXWord:=Word(D.Data^[P]) Or (Word(D.Data^[P+1]) Shl 8);
End;

Function PXRow(Var D: TPXState): Boolean;
Var P: LongInt; B,Value,Count: Integer;
Begin
 PXRow:=False; P:=0;
 While P<D.RowSize Do Begin
  If D.Position>=D.Limit Then Exit;
  B:=D.Data^[D.Position]; Inc(D.Position); Count:=1; Value:=B;
  If (D.Encoding=1) And ((B And $C0)=$C0) Then Begin
   Count:=B And 63;
   If (Count=0) Or (D.Position>=D.Limit) Then Exit;
   Value:=D.Data^[D.Position]; Inc(D.Position);
  End;
  If Count>D.RowSize-P Then Exit;
  While Count>0 Do Begin D.Row^[P]:=Value; Inc(P); Dec(Count); End;
 End;
 PXRow:=True;
End;

Function PXRead(Const Name: String; Var D: TPXState): Boolean;
Var F: File; OldMode: Byte; Bytes,V,Start,Dest: LongInt;
    X,Y,I,C,Index,Sample,PaletteInfo,Version: Integer;
    Failed,HavePalette,EmptyPalette: Boolean;
Begin
 PXRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=128) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Then Exit;
 If D.Data^[0]<>10 Then Exit;
 Version:=D.Data^[1]; If Not (Version In [0,2,3,4,5]) Then Exit;
 D.Encoding:=D.Data^[2]; If D.Encoding>1 Then Exit;
 D.Bits:=D.Data^[3]; D.Planes:=D.Data^[65];
 If (D.Bits=8) And (D.Planes In [1,3,4]) Then Begin D.Depth:=D.Bits*D.Planes; If D.Planes=4 Then D.Depth:=24; End
 Else If (D.Bits In [1,2,4]) And (D.Planes>=1) And
         (D.Planes*D.Bits<=4) Then D.Depth:=D.Bits*D.Planes
 Else Exit;
 V:=LongInt(PXWord(D,8))-LongInt(PXWord(D,4))+1;
 If (V<1) Or (V>PnMAX_IMAGE_WIDTH) Then Exit; D.Width:=V;
 V:=LongInt(PXWord(D,10))-LongInt(PXWord(D,6))+1;
 If (V<1) Or (V>PnMAX_IMAGE_HEIGHT) Then Exit; D.Height:=V;
 D.RowBytes:=PXWord(D,66);
 If D.RowBytes<(LongInt(D.Width)*D.Bits+7) Div 8 Then Exit;
 D.RowSize:=D.RowBytes*D.Planes; D.Limit:=D.Size;
 PaletteInfo:=PXWord(D,68); HavePalette:=False;
 If D.Depth=8 Then Begin
  If D.Size>=897 Then
   If D.Data^[D.Size-769]=12 Then Begin
    HavePalette:=True;
    For I:=0 To 255 Do Begin
     Start:=D.Size-768+LongInt(I)*3;
     D.Palette[I].R:=D.Data^[Start];
     D.Palette[I].G:=D.Data^[Start+1];
     D.Palette[I].B:=D.Data^[Start+2];
    End;
   End;
  If Not HavePalette Then Begin
   If PaletteInfo<>2 Then Exit;
   For I:=0 To 255 Do Begin
    D.Palette[I].R:=I; D.Palette[I].G:=I; D.Palette[I].B:=I;
   End;
  End;
 End Else If D.Depth<=4 Then Begin
  EmptyPalette:=True;
  For I:=0 To 47 Do If D.Data^[16+I]<>0 Then EmptyPalette:=False;
  If D.Depth=1 Then Begin
   EmptyPalette:=True;
   For I:=0 To 5 Do If D.Data^[16+I]<>0 Then EmptyPalette:=False;
  End;
  For I:=0 To (1 Shl D.Depth)-1 Do Begin
   D.Palette[I].R:=D.Data^[16+I*3];
   D.Palette[I].G:=D.Data^[17+I*3];
   D.Palette[I].B:=D.Data^[18+I*3];
   If EmptyPalette And ((Version In [0,3]) Or (D.Depth=1)) Then Begin
    D.Palette[I].R:=PnVGA_R[I]; D.Palette[I].G:=PnVGA_G[I];
    D.Palette[I].B:=PnVGA_B[I];
    If (D.Depth=1) And (I=1) Then Begin
     D.Palette[I].R:=255; D.Palette[I].G:=255;
     D.Palette[I].B:=255;
    End;
   End;
  End;
 End;
 D.Row:=PPNBytes(JDAllocate(D.RowSize));
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize));
 If (D.Row=Nil) Or (D.RGB=Nil) Then Exit;
 D.Position:=128; Dest:=0;
 For Y:=0 To D.Height-1 Do Begin
  If Not PXRow(D) Then Exit;
  For X:=0 To D.Width-1 Do Begin
   If D.Depth=24 Then Begin
    For C:=0 To 2 Do D.RGB^[Dest+C]:=D.Row^[C*D.RowBytes+X];
   End Else Begin
    Index:=0;
    For C:=0 To D.Planes-1 Do Begin
     If D.Bits=8 Then Sample:=D.Row^[X]
     Else Sample:=(D.Row^[C*D.RowBytes+(X*D.Bits) Div 8] Shr
      (8-D.Bits-((X*D.Bits) And 7))) And ((1 Shl D.Bits)-1);
     Index:=Index Or (Sample Shl (C*D.Bits));
    End;
    If D.Depth=8 Then D.RGB^[Dest]:=Index
    Else D.RGB^[Dest]:=D.Palette[Index].R;
    D.RGB^[Dest+1]:=D.Palette[Index].G;
    D.RGB^[Dest+2]:=D.Palette[Index].B;
   End;
   Inc(Dest,3);
  End;
 End;
 If D.Depth=8 Then Begin
  If HavePalette And (D.Position=D.Size-769) Then D.Limit:=D.Position
  Else If (PaletteInfo=2) And (D.Position=D.Size) Then Begin
   For I:=0 To 255 Do Begin
    D.Palette[I].R:=I; D.Palette[I].G:=I; D.Palette[I].B:=I;
   End;
  End Else Exit;
  For Start:=0 To D.RGBSize Div 3-1 Do Begin
   Index:=D.RGB^[Start*3]; D.RGB^[Start*3]:=D.Palette[Index].R;
   D.RGB^[Start*3+1]:=D.Palette[Index].G;
   D.RGB^[Start*3+2]:=D.Palette[Index].B;
  End;
 End;
 PXRead:=(D.Position=D.Limit) Or ((D.Depth<>8) And (D.Position<D.Limit));
End;

Function LoadPCX(FileName: String): Boolean;
Var D: PPXState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadPCX:=False; Pixels:=Nil; Q:=Nil;
 D:=PPXState(JDAllocate(SizeOf(TPXState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If PXRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=16; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
   PnImageBuffer.BitDepth:=D^.Depth;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_PCX;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadPCX:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Row<>Nil Then FreeMem(D^.Row,D^.RowSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TPXState));
End;
{ Microsoft Paint MSP : DanM brut et LinS RLE par ligne.
  Compatibilite avec le profil d'en-tete et la polarite BMP2MSP/PCX2MSP.
  Le checksum des treize premiers mots est controle avant decodage. }
Type
 TMSState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize,Position: LongInt;
  Width,Height,RowBytes,Version: Integer;
  LocalInk: Boolean;
  Row: Array[0..511] Of Byte;
 End;
 PMSState = ^TMSState;

Function MSWord(Const D: TMSState; P: LongInt): Word;
Begin
 MSWord:=Word(D.Data^[P]) Or (Word(D.Data^[P+1]) Shl 8);
End;

Function MSRead(Const Name: String; Var D: TMSState): Boolean;
Var F: File; OldMode: Byte; Bytes,EndRow,Dest: LongInt;
    Failed: Boolean; I,X,Y,N,Count,Value,Produced: Integer;
    V,Checksum,LocalSum: Word;
Begin
 MSRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=32) And (D.Size<=16777216) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Then Exit;
 If (MSWord(D,0)=$6144) And (MSWord(D,2)=$4D6E) Then D.Version:=1
 Else If (MSWord(D,0)=$694C) And (MSWord(D,2)=$536E) Then D.Version:=2
 Else Exit;
 V:=MSWord(D,4); If (V<1) Or (V>4096) Then Exit; D.Width:=V;
 V:=MSWord(D,6); If (V<1) Or (V>4096) Then Exit; D.Height:=V;
 Checksum:=0; For I:=0 To 12 Do Checksum:=Checksum Xor MSWord(D,I*2);
 If Checksum<>0 Then Exit;
 D.LocalInk:=(D.Version=1) And (MSWord(D,8)=1) And
  (MSWord(D,10)=1) And (MSWord(D,12)=D.Width) And
  (MSWord(D,14)=D.Height) And (MSWord(D,16)=0) And (MSWord(D,18)=0);
 LocalSum:=0; For I:=0 To 9 Do LocalSum:=LocalSum Xor MSWord(D,I*2);
 If MSWord(D,20)<>LocalSum Then D.LocalInk:=False;
 For I:=11 To 15 Do If MSWord(D,I*2)<>0 Then D.LocalInk:=False;
 D.RowBytes:=(D.Width+7) Div 8;
 D.Position:=32;
 If D.Version=1 Then Begin
  If LongInt(D.RowBytes)*D.Height<>D.Size-32 Then Exit;
 End Else Begin
  If LongInt(D.Height)*2>D.Size-32 Then Exit;
  Inc(D.Position,LongInt(D.Height)*2);
 End;
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 Dest:=0;
 For Y:=0 To D.Height-1 Do Begin
  If D.Version=1 Then Begin
   Move(D.Data^[D.Position],D.Row,D.RowBytes);
   Inc(D.Position,D.RowBytes);
  End Else Begin
   N:=MSWord(D,32+LongInt(Y)*2);
   { Une ligne vide dans la table signifie une ligne blanche. }
   FillChar(D.Row,SizeOf(D.Row),255);
   If N>D.Size-D.Position Then Exit;
   EndRow:=D.Position+N; Produced:=0;
   While D.Position<EndRow Do Begin
    Count:=D.Data^[D.Position]; Inc(D.Position);
    If Count=0 Then Begin
     If EndRow-D.Position<2 Then Exit;
     Count:=D.Data^[D.Position]; Value:=D.Data^[D.Position+1];
     Inc(D.Position,2);
     If (Count=0) Or (Count>D.RowBytes-Produced) Then Exit;
     While Count>0 Do Begin
      D.Row[Produced]:=Value; Inc(Produced); Dec(Count);
     End;
    End Else Begin
     If (Count>EndRow-D.Position) Or
        (Count>D.RowBytes-Produced) Then Exit;
     Move(D.Data^[D.Position],D.Row[Produced],Count);
     Inc(D.Position,Count); Inc(Produced,Count);
    End;
   End;
   If (N<>0) And (Produced<>D.RowBytes) Then Exit;
  End;
  For X:=0 To D.Width-1 Do Begin
   Value:=0;
   If ((D.Row[X Div 8] Shr (7-(X And 7))) And 1)<>0 Then Value:=255;
   If D.LocalInk Then Value:=255-Value;
   D.RGB^[Dest]:=Value; D.RGB^[Dest+1]:=Value;
   D.RGB^[Dest+2]:=Value; Inc(Dest,3);
  End;
 End;
 MSRead:=D.Position=D.Size;
End;

Function LoadMSP(FileName: String): Boolean;
Var D: PMSState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadMSP:=False; Pixels:=Nil; Q:=Nil;
 D:=PMSState(JDAllocate(SizeOf(TMSState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If MSRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=16; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
   PnImageBuffer.BitDepth:=1;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_MSP;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadMSP:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TMSState));
End;
{ TIFF classique, premiere page, bandes natives/PackBits/Deflate.
  Gris, palette, RGB, alpha 8/16 bits ; II/MM, plans et orientations.
  Pas de BigTIFF, tuiles, LZW, JPEG ni compression CCITT.
  https://www.itu.int/itudoc/itu-t/com16/tiff-fx/docs/tiff6.pdf }
{ LZW TIFF (MSB d'abord, codes 9..12 bits, "early change") : ajoute pour IMGLOAD. }
Function ImgTiffLZW(Src: PPNBytes; Count: LongInt; Dst: PPNBytes; Needed: LongInt): Boolean;
Var Prefix: Array[0..4095] Of Word; Suffix: Array[0..4095] Of Byte;
    Stack: Array[0..4096] Of Byte;
    Pos,OutPos,BitBuf: LongInt; BitCnt,CodeSize,SP: Integer;
    NextCode,Old,Code,Cur: LongInt; First: Byte; Done: Boolean;
Begin
 ImgTiffLZW:=False; Pos:=0; OutPos:=0; BitBuf:=0; BitCnt:=0;
 CodeSize:=9; NextCode:=258; Old:=-1; Done:=False; First:=0;
 While (Not Done) And (OutPos<Needed) Do Begin
  While (BitCnt<CodeSize) And (Pos<Count) Do Begin
   BitBuf:=(BitBuf Shl 8) Or Src^[Pos]; Inc(Pos); Inc(BitCnt,8);
  End;
  If BitCnt<CodeSize Then Break;
  Code:=(BitBuf Shr (BitCnt-CodeSize)) And ((1 Shl CodeSize)-1);
  Dec(BitCnt,CodeSize); BitBuf:=BitBuf And ((1 Shl BitCnt)-1);
  If Code=257 Then Break;
  If Code=256 Then Begin
   CodeSize:=9; NextCode:=258; Old:=-1;
  End Else If Old<0 Then Begin
   If Code>255 Then Exit;
   Dst^[OutPos]:=Code; Inc(OutPos); Old:=Code; First:=Code;
  End Else Begin
   SP:=0;
   If Code<NextCode Then Cur:=Code
   Else If Code=NextCode Then Begin Stack[0]:=First; SP:=1; Cur:=Old; End
   Else Exit;
   While Cur>=258 Do Begin
    If SP>4094 Then Exit;
    Stack[SP]:=Suffix[Cur]; Inc(SP); Cur:=Prefix[Cur];
   End;
   Stack[SP]:=Cur; Inc(SP); First:=Cur;
   While (SP>0) And (OutPos<Needed) Do Begin
    Dec(SP); Dst^[OutPos]:=Stack[SP]; Inc(OutPos);
   End;
   If NextCode<4096 Then Begin
    Prefix[NextCode]:=Old; Suffix[NextCode]:=First; Inc(NextCode);
    If NextCode=511 Then CodeSize:=10
    Else If NextCode=1023 Then CodeSize:=11
    Else If NextCode=2047 Then CodeSize:=12;
   End;
   Old:=Code;
  End;
 End;
 ImgTiffLZW:=OutPos>=Needed;
End;

Function TFStrip(Var D: TDNState; Offset,Count,Dest,Needed: LongInt): Boolean;
Var P,Stop,OutPos: LongInt; Code,N,Value: Integer; Z: PPNState;
Begin
 TFStrip:=False;
 If D.TFCompression=1 Then Begin
  If Count<>Needed Then Exit;
  Move(D.Data^[Offset],D.Raw^[Dest],Needed); TFStrip:=True; Exit;
 End;
 If D.TFCompression=5 Then Begin
  TFStrip:=ImgTiffLZW(PPNBytes(@D.Data^[Offset]),Count,PPNBytes(@D.Raw^[Dest]),Needed); Exit;
 End;
 If (D.TFCompression=8) Or (D.TFCompression=32946) Then Begin
  Z:=PPNState(JDAllocate(SizeOf(TPNState))); If Z=Nil Then Exit;
  FillChar(Z^,SizeOf(Z^),0);
  Z^.Compressed:=PPNBytes(@D.Data^[Offset]); Z^.CompressedSize:=Count;
  Z^.Raw:=PPNBytes(@D.Raw^[Dest]); Z^.RawSize:=Needed;
  TFStrip:=PNInflate(Z^); FreeMem(Z,SizeOf(TPNState)); Exit;
 End;
 P:=Offset; Stop:=Offset+Count; OutPos:=0;
 While P<Stop Do Begin
  Code:=D.Data^[P]; Inc(P);
  If Code<128 Then Begin
   N:=Code+1;
   If (N>Stop-P) Or (N>Needed-OutPos) Then Exit;
   Move(D.Data^[P],D.Raw^[Dest+OutPos],N); Inc(P,N); Inc(OutPos,N);
  End Else If Code>128 Then Begin
   N:=257-Code;
   If (P>=Stop) Or (N>Needed-OutPos) Then Exit;
   Value:=D.Data^[P]; Inc(P);
   While N>0 Do Begin
    D.Raw^[Dest+OutPos]:=Value; Inc(OutPos); Dec(N);
   End;
  End;
 End;
 TFStrip:=OutPos=Needed;
End;

Function TFRawWord(Var D: TDNState; P: LongInt): LongWord;
Begin
 If D.Little Then
  TFRawWord:=LongWord(D.Raw^[P])+LongWord(D.Raw^[P+1])*256
 Else TFRawWord:=LongWord(D.Raw^[P])*256+D.Raw^[P+1];
End;

Function TFSample(Var D: TDNState; X,Y,C: Integer): LongWord;
Var Base,Sample: LongInt;
Begin
 If D.TFPlanar=1 Then Begin
  Base:=LongInt(Y)*D.TFRowSize; Sample:=LongInt(X)*D.TFSamples+C;
 End Else Begin
  Base:=(LongInt(C)*D.Height+Y)*D.TFRowSize; Sample:=X;
 End;
 If D.Bits=16 Then TFSample:=TFRawWord(D,Base+Sample*2)
 Else If D.Bits=8 Then TFSample:=D.Raw^[Base+Sample]
 Else TFSample:=(D.Raw^[Base+(Sample*D.Bits) Div 8] Shr
  (8-D.Bits-((Sample*D.Bits) And 7))) And ((1 Shl D.Bits)-1);
End;

Function TFDecode(Var D: TDNState): Boolean;
Var V: Double; E,F,I,C,X,Y,OX,OY,Planes,RowSamples,Stride: Integer;
    Strip,PerPlane,Total,Rows,Row,Offset,Count,Needed,Dest,P,J: LongInt;
    A,Sample,Maximum,Value: LongWord;
    Color: Array[0..2] Of Integer; Palette: PnTPalette;
Begin
 TFDecode:=False;
 V:=DNScalar(D,256,0); If (V<1) Or (V>4096) Then Exit;
 D.Width:=Round(V);
 V:=DNScalar(D,257,0); If (V<1) Or (V>4096) Then Exit;
 D.Height:=Round(V);
 V:=DNScalar(D,277,1); If (V<1) Or (V>4) Then Exit;
 D.TFSamples:=Round(V);
 V:=DNScalar(D,262,-1); If (V<0) Or (V>3) Then Exit;
 D.TFPhoto:=Round(V);
 If D.TFPhoto=2 Then Begin
  If Not (D.TFSamples In [3,4]) Then Exit;
 End Else If D.TFPhoto=3 Then Begin If D.TFSamples<>1 Then Exit; End
 Else If Not (D.TFSamples In [1,2]) Then Exit;
 E:=DNFind(D,258); D.Bits:=1;
 If E>=0 Then Begin
  If (D.Entries[E].Count<>1) And
     (D.Entries[E].Count<>D.TFSamples) Then Exit;
  V:=DNValue(D,E,0);
  If Not ((V=1) Or (V=2) Or (V=4) Or (V=8) Or (V=16)) Then Exit;
  D.Bits:=Round(V);
  For I:=1 To D.Entries[E].Count-1 Do
   If DNValue(D,E,I)<>D.Bits Then Exit;
 End;
 If (D.TFSamples>1) And Not (D.Bits In [8,16]) Then Exit;
 If (D.TFPhoto=3) And (D.Bits>8) Then Exit;
 E:=DNFind(D,339);
 If E>=0 Then Begin
  If (D.Entries[E].Count<>1) And
     (D.Entries[E].Count<>D.TFSamples) Then Exit;
  For I:=0 To D.Entries[E].Count-1 Do If DNValue(D,E,I)<>1 Then Exit;
 End;
 V:=DNScalar(D,259,1);
 If Not ((V=1) Or (V=5) Or (V=8) Or (V=32946) Or (V=32773)) Then Exit;
 D.TFCompression:=Round(V);
 If DNFind(D,324)>=0 Then Exit;
 V:=DNScalar(D,284,1); If (V<>1) And (V<>2) Then Exit;
 D.TFPlanar:=Round(V);
 V:=DNScalar(D,274,1); If (V<1) Or (V>8) Then Exit;
 D.Orientation:=Round(V);
 V:=DNScalar(D,266,1); If (V<>1) And (V<>2) Then Exit;
 D.TFFill:=Round(V); If (D.TFFill=2) And (D.Bits>=8) Then Exit;
 V:=DNScalar(D,317,1); If (V<>1) And (V<>2) Then Exit;
 D.TFPredictor:=Round(V);
 If (D.TFPredictor=2) And Not (D.Bits In [8,16]) Then Exit;
 D.TFAlpha:=0;
 If D.TFSamples In [2,4] Then Begin
  V:=DNScalar(D,338,0); If (V<>1) And (V<>2) Then Exit;
  D.TFAlpha:=Round(V);
 End;
 V:=DNScalar(D,278,D.Height); If V<1 Then Exit;
 If V>D.Height Then V:=D.Height; Rows:=Round(V);
 PerPlane:=(D.Height-1) Div Rows+1;
 Planes:=1; If D.TFPlanar=2 Then Planes:=D.TFSamples;
 Total:=PerPlane*Planes;
 E:=DNFind(D,273); F:=DNFind(D,279);
 If (E<0) Or (F<0) Then Exit;
 If (D.Entries[E].Count<>Total) Or (D.Entries[F].Count<>Total) Then Exit;
 RowSamples:=D.Width; If D.TFPlanar=1 Then
  RowSamples:=D.Width*D.TFSamples;
 D.TFRowSize:=(LongInt(RowSamples)*D.Bits+7) Div 8;
 D.RawSize:=D.TFRowSize*D.Height*Planes;
 If D.Bad Or (D.RawSize>150994944) Then Exit;
 D.Raw:=PPNBytes(JDAllocate(D.RawSize)); If D.Raw=Nil Then Exit;
 For Strip:=0 To Total-1 Do Begin
  V:=DNValue(D,E,Strip); If (V<0) Or (V>D.Size) Then Exit;
  Offset:=Round(V);
  V:=DNValue(D,F,Strip); If (V<1) Or (V>D.Size-Offset) Then Exit;
  Count:=Round(V); Row:=(Strip Mod PerPlane)*Rows;
  Needed:=Rows; If Needed>D.Height-Row Then Needed:=D.Height-Row;
  Needed:=Needed*D.TFRowSize;
  Dest:=((Strip Div PerPlane)*D.Height+Row)*D.TFRowSize;
  If D.Bad Or Not TFStrip(D,Offset,Count,Dest,Needed) Then Exit;
 End;
 If D.TFFill=2 Then For P:=0 To D.RawSize-1 Do Begin
  Value:=D.Raw^[P]; Sample:=0;
  For I:=1 To 8 Do Begin
   Sample:=(Sample Shl 1) Or (Value And 1); Value:=Value Shr 1;
  End;
  D.Raw^[P]:=Sample;
 End;
 If D.TFPredictor=2 Then Begin
  Stride:=1; If D.TFPlanar=1 Then Stride:=D.TFSamples;
  For Y:=0 To D.Height*Planes-1 Do
   For X:=Stride To RowSamples-1 Do Begin
    P:=LongInt(Y)*D.TFRowSize+LongInt(X)*(D.Bits Div 8);
    If D.Bits=8 Then
     D.Raw^[P]:=(D.Raw^[P]+D.Raw^[P-Stride]) And 255
    Else Begin
     Value:=(TFRawWord(D,P)+TFRawWord(D,P-Stride*2)) And 65535;
     If D.Little Then Begin
      D.Raw^[P]:=Value And 255; D.Raw^[P+1]:=Value Shr 8;
     End Else Begin
      D.Raw^[P]:=Value Shr 8; D.Raw^[P+1]:=Value And 255;
     End;
    End;
   End;
 End;
 Maximum:=(LongWord(1) Shl D.Bits)-1;
 If D.TFPhoto=3 Then Begin
  E:=DNFind(D,320); If E<0 Then Exit;
  If (D.Entries[E].Kind<>3) Or
     (D.Entries[E].Count<>3*(LongInt(1) Shl D.Bits)) Then Exit;
  For I:=0 To (1 Shl D.Bits)-1 Do Begin
   Palette[I].R:=Round(DNValue(D,E,I)/257);
   Palette[I].G:=Round(DNValue(D,E,I+(1 Shl D.Bits))/257);
   Palette[I].B:=Round(DNValue(D,E,I+(2 Shl D.Bits))/257);
  End;
 End;
 D.OutWidth:=D.Width; D.OutHeight:=D.Height;
 If D.Orientation>=5 Then Begin
  D.OutWidth:=D.Height; D.OutHeight:=D.Width;
 End;
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do Begin
  If D.TFPhoto=3 Then Begin
   I:=TFSample(D,X,Y,0);
   Color[0]:=Palette[I].R; Color[1]:=Palette[I].G;
   Color[2]:=Palette[I].B;
  End Else For C:=0 To 2 Do Begin
   I:=C; If D.TFPhoto<>2 Then I:=0;
   Sample:=TFSample(D,X,Y,I);
   If D.TFPhoto=0 Then Sample:=Maximum-Sample;
   Color[C]:=Round(Sample/(Maximum*1.0)*255);
  End;
  A:=255;
  If D.TFAlpha<>0 Then
   A:=Round(TFSample(D,X,Y,D.TFSamples-1)/(Maximum*1.0)*255);
  OX:=X; OY:=Y;
  Case D.Orientation Of
   2: OX:=D.Width-1-X;
   3: Begin OX:=D.Width-1-X; OY:=D.Height-1-Y; End;
   4: OY:=D.Height-1-Y;
   5: Begin OX:=Y; OY:=X; End;
   6: Begin OX:=D.Height-1-Y; OY:=X; End;
   7: Begin OX:=D.Height-1-Y; OY:=D.Width-1-X; End;
   8: Begin OX:=Y; OY:=D.Width-1-X; End;
  End;
  Dest:=(LongInt(OY)*D.OutWidth+OX)*3;
  For C:=0 To 2 Do Begin
   If D.TFAlpha=1 Then Begin
    Value:=Color[C]+255-A; If Value>255 Then Value:=255;
   End Else Value:=(LongWord(Color[C])*A+255*(255-A)+127) Div 255;
   D.RGB^[Dest+C]:=Value;
  End;
 End;
 { Textes TIFF de la premiere page, conserves pour un export PNG. }
 For I:=0 To 4 Do Begin
  Case I Of
   0: J:=269; 1: J:=315; 2: J:=33432; 3: J:=305; 4: J:=270;
  End;
  E:=DNFind(D,J);
  If E>=0 Then If D.Entries[E].Kind=2 Then
   For P:=0 To D.Entries[E].Count-1 Do Begin
    J:=D.Data^[D.Entries[E].Offset+P]; If J=0 Then Break;
    PMByte(D.Metadata,I,J);
   End;
 End;
 TFDecode:=Not D.Bad;
End;

Function TFRead(Const Name: String; Var D: TDNState): Boolean;
Begin
 D.TIFFMode:=True; TFRead:=False;
 If DNReadDirectory(Name,D) Then TFRead:=TFDecode(D);
End;

Function LoadTIFF(FileName: String): Boolean;
Var D: PDNState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadTIFF:=False; Pixels:=Nil; Q:=Nil;
 D:=PDNState(JDAllocate(SizeOf(TDNState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If TFRead(FileName,D^) Then Begin
  Size:=LongInt(D^.OutWidth)*D^.OutHeight; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.OutWidth; Img.Height:=D^.OutHeight; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.OutWidth; PnCanvasImageH:=D^.OutHeight;
   PnImageBuffer.Width:=D^.OutWidth; PnImageBuffer.Height:=D^.OutHeight;
   PnImageBuffer.BitDepth:=D^.Bits*D^.TFSamples;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_TIFF;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=D^.TFAlpha<>0;
   FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0);
   PnImageBuffer.Palette:=Q^.Palette;
   PnImageBuffer.Metadata:=D^.Metadata;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadTIFF:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Raw<>Nil Then FreeMem(D^.Raw,D^.RawSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TDNState));
End;
{ MacPaint : en-tetes 0/2, 576 x 720, 72 octets par ligne PackBits.
  Bit 1 = noir. Fichier pur ou MacBinary sans en-tete secondaire.
  Apple Technical Note PT24 : MacPaint Document Format. }
Type
 TMAState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize: LongInt;
  Width,Height: Integer;
  Row: Array[0..71] Of Byte;
 End;
 PMAState = ^TMAState;

Function MABE(Const D: TMAState; P: LongInt): LongWord;
Begin
 MABE:=(LongWord(D.Data^[P]) Shl 24) Or
       (LongWord(D.Data^[P+1]) Shl 16) Or
       (LongWord(D.Data^[P+2]) Shl 8) Or D.Data^[P+3];
End;

Function MARead(Const Name: String; Var D: TMAState): Boolean;
Var F: File; OldMode: Byte; Bytes,Base,Position,Limit,Dest,ForkPos: LongInt;
    V,ForkSize,ResourceSize,CRC,Expected: LongWord;
    Failed: Boolean; I,J,X,Y,N,Count,Value,Produced: Integer;
Begin
 MARead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=512) And (D.Size<=16777216) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Failed Then Exit;
 Base:=0; Limit:=D.Size;
 If (MABE(D,0)<>0) And (MABE(D,0)<>2) And
    (D.Data^[65]=Ord('P')) And (D.Data^[66]=Ord('N')) And
    (D.Data^[67]=Ord('T')) And (D.Data^[68]=Ord('G')) Then Begin
  If (D.Size<640) Or (D.Data^[0]<>0) Or
     (D.Data^[1]<1) Or (D.Data^[1]>63) Or
     (D.Data^[74]<>0) Or (D.Data^[82]<>0) Then Exit;
  If (D.Data^[120]<>0) Or (D.Data^[121]<>0) Then Exit;
  Expected:=LongWord(D.Data^[124])*256+D.Data^[125];
  If Expected<>0 Then Begin
   CRC:=0;
   For I:=0 To 123 Do Begin
    CRC:=CRC Xor (LongWord(D.Data^[I]) Shl 8);
    For J:=1 To 8 Do Begin
     If (CRC And $8000)<>0 Then CRC:=(CRC Shl 1) Xor $1021
     Else CRC:=CRC Shl 1;
     CRC:=CRC And $FFFF;
    End;
   End;
   If CRC<>Expected Then Exit;
  End;
  ForkSize:=MABE(D,83); ResourceSize:=MABE(D,87);
  If (ForkSize<512) Or (ForkSize>LongWord(D.Size-128)) Then Exit;
  Base:=128; Limit:=Base+LongInt(ForkSize);
  If ResourceSize<>0 Then Begin
   ForkPos:=128+((LongInt(ForkSize)+127) Div 128)*128;
   If ForkPos>D.Size Then Exit;
   If ResourceSize>LongWord(D.Size-ForkPos) Then Exit;
  End;
 End;
 V:=MABE(D,Base); If (V<>0) And (V<>2) Then Exit;
 D.Width:=576; D.Height:=720; D.RGBSize:=LongInt(576)*720*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 Position:=Base+512; Dest:=0;
 For Y:=0 To 719 Do Begin
  Produced:=0;
  While Produced<72 Do Begin
   If Position>=Limit Then Exit;
   N:=D.Data^[Position]; Inc(Position);
   If N<128 Then Begin
    Count:=N+1;
    If (Count>72-Produced) Or (Count>Limit-Position) Then Exit;
    Move(D.Data^[Position],D.Row[Produced],Count);
    Inc(Position,Count); Inc(Produced,Count);
   End Else If N>128 Then Begin
    Count:=257-N;
    If (Count>72-Produced) Or (Position>=Limit) Then Exit;
    Value:=D.Data^[Position]; Inc(Position);
    While Count>0 Do Begin
     D.Row[Produced]:=Value; Inc(Produced); Dec(Count);
    End;
   End;
  End;
  For X:=0 To 575 Do Begin
   Value:=255;
   If ((D.Row[X Div 8] Shr (7-(X And 7))) And 1)<>0 Then Value:=0;
   D.RGB^[Dest]:=Value; D.RGB^[Dest+1]:=Value;
   D.RGB^[Dest+2]:=Value; Inc(Dest,3);
  End;
 End;
 { PackBits autorise des commandes sans effet, mais pas un autre raster. }
 While Position<Limit Do Begin
  If D.Data^[Position]<>128 Then Exit; Inc(Position);
 End;
 MARead:=True;
End;

Function LoadMAC(FileName: String): Boolean;
Var D: PMAState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadMAC:=False; Pixels:=Nil; Q:=Nil;
 D:=PMAState(JDAllocate(SizeOf(TMAState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If MARead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=16; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
   PnImageBuffer.BitDepth:=1;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_MAC;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadMAC:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TMAState));
End;
{ Targa : types 1/2/3 et RLE 9/10/11, origines et palettes incluses. }
Type
 TTGState = Record
  Data,RGB: PPNBytes;
  Size,RGBSize,Position: LongInt;
  Width,Height,Bits: Integer;
 End;
 PTGState = ^TTGState;

Function TGWord(Var D: TTGState; P: LongInt): LongInt;
Begin
 TGWord:=LongInt(D.Data^[P])+LongInt(D.Data^[P+1])*256;
End;

Function TGColor(Var D: TTGState; Bits,Attributes: Integer;
                 Var R,G,B,A: Integer): Boolean;
Var V: LongInt; N: Integer;
Begin
 TGColor:=False; N:=(Bits+7) Div 8;
 If D.Position>D.Size-N Then Exit;
 V:=D.Position; Inc(D.Position,N); A:=255;
 If Bits In [15,16] Then Begin
  V:=TGWord(D,V); B:=(V And 31)*255 Div 31;
  G:=((V Shr 5) And 31)*255 Div 31;
  R:=((V Shr 10) And 31)*255 Div 31;
  If (Bits=16) And (Attributes=1) And (V And 32768=0) Then A:=0;
 End Else Begin
  B:=D.Data^[V]; G:=D.Data^[V+1]; R:=D.Data^[V+2];
  If (Bits=32) And (Attributes=8) Then A:=D.Data^[V+3];
 End;
 TGColor:=True;
End;

Function TGDecode(Var D: TTGState): Boolean;
Var Kind,Base,Map,Entry,Attributes,Descriptor: Integer;
    First,Count,I,Total,Done,Run,P,Index,Dest: LongInt;
    R,G,B,A,X,Y,N: Integer; RepeatPixel: Boolean;
    Palette: PPNBytes;
Begin
 TGDecode:=False; Palette:=Nil;
 If D.Size<18 Then Exit;
 Map:=D.Data^[1]; Kind:=D.Data^[2]; Base:=Kind;
 If Kind In [9,10,11] Then Dec(Base,8);
 If Not (Base In [1,2,3]) Then Exit;
 D.Width:=TGWord(D,12); D.Height:=TGWord(D,14);
 If (TGWord(D,12)>4096) Or (TGWord(D,14)>4096) Or
    (D.Width<1) Or (D.Height<1) Then Exit;
 D.Bits:=D.Data^[16]; Descriptor:=D.Data^[17];
 Attributes:=Descriptor And 15;
 If Descriptor And 192<>0 Then Exit;
 If Base=1 Then Begin
  If (Map<>1) Or Not (D.Bits In [8,16]) Then Exit;
 End Else If Map<>0 Then Exit;
 If (Base=2) And Not (D.Bits In [15,16,24,32]) Then Exit;
 If (Base=3) And Not (D.Bits In [8,16]) Then Exit;
 If (Base=2) And (((D.Bits In [15,24]) And (Attributes<>0)) Or
    ((D.Bits=16) And Not (Attributes In [0,1])) Or
    ((D.Bits=32) And Not (Attributes In [0,8]))) Then Exit;
 If (Base=3) And (((D.Bits=8) And (Attributes<>0)) Or
    ((D.Bits=16) And Not (Attributes In [0,8]))) Then Exit;
 D.Position:=18+LongInt(D.Data^[0]);
 If D.Position>D.Size Then Exit;
 First:=TGWord(D,3); Count:=TGWord(D,5); Entry:=D.Data^[7];
 If Map=1 Then Begin
  If (Count=0) Or (First+Count>65536) Or
     Not (Entry In [15,16,24,32]) Then Exit;
  If ((Entry In [15,24]) And (Attributes<>0)) Or
     ((Entry=16) And Not (Attributes In [0,1])) Or
     ((Entry=32) And Not (Attributes In [0,8])) Then Exit;
  Palette:=PPNBytes(JDAllocate(262144)); If Palette=Nil Then Exit;
  For I:=First To First+Count-1 Do Begin
   If Not TGColor(D,Entry,Attributes,R,G,B,A) Then Begin
    FreeMem(Palette,262144); Exit;
   End;
   Palette^[I*4]:=R; Palette^[I*4+1]:=G;
   Palette^[I*4+2]:=B; Palette^[I*4+3]:=A;
  End;
 End;
 Total:=LongInt(D.Width)*D.Height; D.RGBSize:=Total*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize));
 If D.RGB=Nil Then Begin
  If Palette<>Nil Then FreeMem(Palette,262144); Exit;
 End;
 Done:=0;
 While Done<Total Do Begin
  Run:=1; RepeatPixel:=False;
  If Kind>=9 Then Begin
   If D.Position>=D.Size Then Break;
   N:=D.Data^[D.Position]; Inc(D.Position);
   Run:=(N And 127)+1; RepeatPixel:=(N And 128)<>0;
  End;
  If Run>Total-Done Then Break;
  For I:=0 To Run-1 Do Begin
   If (I=0) Or Not RepeatPixel Then Begin
    N:=(D.Bits+7) Div 8;
    If D.Position>D.Size-N Then Begin Done:=-1; Break; End;
    If Base=1 Then Begin
     Index:=D.Data^[D.Position];
     If D.Bits=16 Then Index:=TGWord(D,D.Position);
     Inc(D.Position,N);
     If (Index<First) Or (Index>=First+Count) Then Begin
      Done:=-1; Break;
     End;
     R:=Palette^[Index*4]; G:=Palette^[Index*4+1];
     B:=Palette^[Index*4+2]; A:=Palette^[Index*4+3];
    End Else If Base=3 Then Begin
     R:=D.Data^[D.Position]; G:=R; B:=R; A:=255;
     If (D.Bits=16) And (Attributes=8) Then
      A:=D.Data^[D.Position+1];
     Inc(D.Position,N);
    End Else If Not TGColor(D,D.Bits,Attributes,R,G,B,A) Then Begin
     Done:=-1; Break;
    End;
   End;
   P:=Done+I; X:=P Mod D.Width; Y:=P Div D.Width;
   If Descriptor And 16<>0 Then X:=D.Width-1-X;
   If Descriptor And 32=0 Then Y:=D.Height-1-Y;
   Dest:=(LongInt(Y)*D.Width+X)*3;
   D.RGB^[Dest]:=(LongInt(R)*A+LongInt(255)*(255-A)+127) Div 255;
   D.RGB^[Dest+1]:=(LongInt(G)*A+LongInt(255)*(255-A)+127) Div 255;
   D.RGB^[Dest+2]:=(LongInt(B)*A+LongInt(255)*(255-A)+127) Div 255;
  End;
  If Done<0 Then Break; Inc(Done,Run);
 End;
 If Palette<>Nil Then FreeMem(Palette,262144);
 TGDecode:=Done=Total;
End;

Function TGRead(Const Name: String; Var D: TTGState): Boolean;
Var F: File; OldMode: Byte; Bytes: LongInt; Failed: Boolean;
Begin
 TGRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode; If IOResult<>0 Then Exit;
 {$I-}D.Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If Not Failed And (D.Size>=18) And (D.Size<=134217728) Then Begin
  D.Data:=PPNBytes(JDAllocate(D.Size));
  If D.Data<>Nil Then Begin
   {$I-}BlockRead(F,D.Data^,D.Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>D.Size);
  End Else Failed:=True;
 End Else Failed:=True;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Not Failed Then TGRead:=TGDecode(D);
End;

Function LoadTGA(FileName: String): Boolean;
Var D: PTGState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadTGA:=False; Pixels:=Nil; Q:=Nil;
 D:=PTGState(JDAllocate(SizeOf(TTGState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If TGRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
   PnImageBuffer.BitDepth:=D^.Bits;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_TARGA;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=False; FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0); PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadTGA:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TTGState));
End;
Function LoadICO(FileName: String): Boolean;
Var D: PCUState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadICO:=False; Pixels:=Nil; Q:=Nil;
 D:=PCUState(JDAllocate(SizeOf(TCUState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If ICRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=PnVGA_R[I]; Q^.Palette[I].G:=PnVGA_G[I]; Q^.Palette[I].B:=PnVGA_B[I]; Q^.Palette[I].A:=255; End;
   Used:=0; Exact:=True; Source:=PByte(D^.RGB); Dest:=Pixels;
   For N:=0 To Size-1 Do Begin
    R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Slot:=-1;
    For J:=0 To Used-1 Do If (Q^.Palette[J].R=R) And (Q^.Palette[J].G=G) And (Q^.Palette[J].B=B) Then Begin Slot:=J; Break; End;
    If Slot<0 Then Begin
     If Used=256 Then Begin Exact:=False; Break; End;
     Slot:=Used; Inc(Used); Q^.Palette[Slot].R:=R; Q^.Palette[Slot].G:=G; Q^.Palette[Slot].B:=B; Q^.Palette[Slot].A:=255;
    End;
    Dest^:=Slot; Inc(Dest);
   End;
   If Not Exact Then Begin
    Img.Width:=D^.Width; Img.Height:=D^.Height; Img.Pixels:=PByte(D^.RGB); JPBuildPalette(Q^,Img);
    Source:=Img.Pixels; Dest:=Pixels;
    For N:=0 To Size-1 Do Begin R:=Source^; Inc(Source); G:=Source^; Inc(Source); B:=Source^; Inc(Source); Dest^:=Q^.Map[JPBin(R,G,B)]; Inc(Dest); End;
   End;
   If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
   PnCanvasImage:=Pixels; Pixels:=Nil; PnCanvasImageW:=D^.Width; PnCanvasImageH:=D^.Height;
   PnImageBuffer.Width:=D^.Width; PnImageBuffer.Height:=D^.Height;
   PnImageBuffer.BitDepth:=D^.Bits;
   PnImageBuffer.FileName:=FileName; PnImageBuffer.Format:=PnFMT_ICO;
   PnImageBuffer.Modified:=False;
   PnImageBuffer.HasTransparency:=D^.Transparent;
   PnImageBuffer.HasHotspot:=False;
   PnImageBuffer.HotspotX:=D^.HotX; PnImageBuffer.HotspotY:=D^.HotY;
   PnImageBuffer.CursorImages:=D^.Count;
   FillChar(PnImageBuffer.TransparentColor,SizeOf(PnTRGBColor),0);
   PnImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}ImgNoPal(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}ImgNoPal(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadICO:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TCUState));
End;
{ ---------------- Point d'entree IMGLOAD ---------------- }
Function ImgUp(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:=S;
 For I:=1 To Length(R) Do If (R[I]>='a') And (R[I]<='z') Then R[I]:=Chr(Ord(R[I])-32);
 ImgUp:=R;
End;

Function ImgExtOf(Const FN: String): String;
Var I: Integer;
Begin
 ImgExtOf:='';
 For I:=Length(FN) DownTo 1 Do Begin
  If FN[I] In ['\','/',':'] Then Exit;
  If FN[I]='.' Then Begin ImgExtOf:=ImgUp(Copy(FN,I,Length(FN)-I+1)); Exit; End;
 End;
End;

{ Format PAINT d'apres l'extension (majuscules, avec le point) ; 255 = inconnu. }
Function ImgFmtOfExt(Const E: String): Byte;
Begin
 ImgFmtOfExt:=255;
 If (E='.BMP') Or (E='.DIB') Then ImgFmtOfExt:=PnFMT_DIB
 Else If E='.GIF' Then ImgFmtOfExt:=PnFMT_GIF
 Else If E='.PNG' Then ImgFmtOfExt:=PnFMT_PNG
 Else If E='.APNG' Then ImgFmtOfExt:=PnFMT_APNG
 Else If (E='.JPG') Or (E='.JPEG') Or (E='.JPE') Or (E='.JFIF') Then ImgFmtOfExt:=PnFMT_JPEG
 Else If E='.PCX' Then ImgFmtOfExt:=PnFMT_PCX
 Else If (E='.TGA') Or (E='.TARGA') Then ImgFmtOfExt:=PnFMT_TARGA
 Else If (E='.PPM') Or (E='.PGM') Or (E='.PBM') Or (E='.PNM') Then ImgFmtOfExt:=PnFMT_PPM
 Else If E='.XBM' Then ImgFmtOfExt:=PnFMT_XBM
 Else If (E='.LBM') Or (E='.ILBM') Or (E='.IFF') Then ImgFmtOfExt:=PnFMT_LBM
 Else If (E='.TIF') Or (E='.TIFF') Then ImgFmtOfExt:=PnFMT_TIFF
 Else If E='.BGX' Then ImgFmtOfExt:=PnFMT_BGX
 Else If E='.WPG' Then ImgFmtOfExt:=PnFMT_WPG
 Else If E='.MSP' Then ImgFmtOfExt:=PnFMT_MSP
 Else If (E='.MAC') Or (E='.PNTG') Then ImgFmtOfExt:=PnFMT_MAC
 Else If E='.ICO' Then ImgFmtOfExt:=PnFMT_ICO
 Else If E='.CUR' Then ImgFmtOfExt:=PnFMT_CUR
 Else If E='.DDS' Then ImgFmtOfExt:=PnFMT_DDS
 Else If (E='.HDR') Or (E='.RGBE') Then ImgFmtOfExt:=PnFMT_HDR
 Else If E='.EXR' Then ImgFmtOfExt:=PnFMT_EXR
 Else If E='.DNG' Then ImgFmtOfExt:=PnFMT_DNG
 Else If E='.CR2' Then ImgFmtOfExt:=PnFMT_CR2
 Else If E='.ARW' Then ImgFmtOfExt:=PnFMT_ARW
 Else If E='.DCM' Then ImgFmtOfExt:=PnFMT_DCM
 Else If E='.FAX' Then ImgFmtOfExt:=PnFMT_FAX;
End;

Function ImgKnownExt(Const Ext: String): Boolean;
Begin
 ImgKnownExt:=ImgFmtOfExt(ImgUp(Ext))<>255;
End;

{ Format d'apres la signature du fichier ; 255 = indetermine. }
Function ImgFmtOfSig(Const FN: String; Const Ext: String): Byte;
Var F: File; OldMode: Byte; H: Array[0..143] Of Byte; N: LongInt;
    R: Byte;
Begin
 R:=255; FillChar(H,SizeOf(H),0); N:=0;
 Assign(F,FN); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}
 FileMode:=OldMode;
 If IOResult<>0 Then Begin ImgFmtOfSig:=255; Exit; End;
 {$I-}BlockRead(F,H,SizeOf(H),N);{$I+}
 If IOResult<>0 Then N:=0;
 {$I-}Close(F);{$I+}
 If IOResult<>0 Then;
 If N>=4 Then Begin
  If (H[0]=$42) And (H[1]=$4D) Then R:=PnFMT_DIB
  Else If (H[0]=$47) And (H[1]=$49) And (H[2]=$46) And (H[3]=$38) Then R:=PnFMT_GIF
  Else If (H[0]=$89) And (H[1]=$50) And (H[2]=$4E) And (H[3]=$47) Then Begin
   If Ext='.APNG' Then R:=PnFMT_APNG Else R:=PnFMT_PNG;
  End
  Else If (H[0]=$FF) And (H[1]=$D8) Then R:=PnFMT_JPEG
  Else If ((H[0]=$49) And (H[1]=$49) And (H[2]=$2A) And (H[3]=0)) Or
          ((H[0]=$4D) And (H[1]=$4D) And (H[2]=0) And (H[3]=$2A)) Then Begin
   If Ext='.DNG' Then R:=PnFMT_DNG
   Else If Ext='.CR2' Then R:=PnFMT_CR2
   Else If Ext='.ARW' Then R:=PnFMT_ARW
   Else R:=PnFMT_TIFF;
  End
  Else If (H[0]=$46) And (H[1]=$4F) And (H[2]=$52) And (H[3]=$4D) Then R:=PnFMT_LBM
  Else If (H[0]=$44) And (H[1]=$44) And (H[2]=$53) And (H[3]=$20) Then R:=PnFMT_DDS
  Else If (H[0]=$23) And (H[1]=$3F) And (H[2]=$52) Then R:=PnFMT_HDR
  Else If (H[0]=$76) And (H[1]=$2F) And (H[2]=$31) And (H[3]=$01) Then R:=PnFMT_EXR
  Else If (H[0]=$50) And (H[1]>=$31) And (H[1]<=$36) And (H[2] In [9,10,13,32,35]) Then R:=PnFMT_PPM
  Else If (H[0]=$23) And (H[1]=$64) And (H[2]=$65) And (H[3]=$66) Then R:=PnFMT_XBM
  Else If (H[0]=$FF) And (H[1]=$57) And (H[2]=$50) And (H[3]=$43) Then R:=PnFMT_WPG
  Else If (H[0]=0) And (H[1]=0) And (H[2]=1) And (H[3]=0) Then R:=PnFMT_ICO
  Else If (H[0]=0) And (H[1]=0) And (H[2]=2) And (H[3]=0) Then R:=PnFMT_CUR
  Else If ((H[0]=$44) And (H[1]=$61) And (H[2]=$6E) And (H[3]=$4D)) Or
          ((H[0]=$4C) And (H[1]=$69) And (H[2]=$6E) And (H[3]=$53)) Then R:=PnFMT_MSP
  Else If (N>=132) And (H[128]=$44) And (H[129]=$49) And (H[130]=$43) And (H[131]=$4D) Then R:=PnFMT_DCM;
 End;
 ImgFmtOfSig:=R;
End;

{ PBM (P1 ASCII / P4 binaire) : non gere par LoadPPM. }
Function ImgPbmNum(D: PPNBytes; Size: LongInt; Var P: LongInt): LongInt;
Var V: LongInt;
Begin
 ImgPbmNum:=-1;
 While P<Size Do Begin
  If D^[P]=35 Then Begin
   While (P<Size) And (D^[P]<>10) And (D^[P]<>13) Do Inc(P);
  End Else If D^[P] In [9,10,11,12,13,32] Then Inc(P) Else Break;
 End;
 If (P>=Size) Or (D^[P]<48) Or (D^[P]>57) Then Exit;
 V:=0;
 While (P<Size) And (D^[P]>=48) And (D^[P]<=57) Do Begin
  V:=V*10+(D^[P]-48); Inc(P);
  If V>100000 Then Exit;
 End;
 ImgPbmNum:=V;
End;

Function ImgLoadPBM(Const FN: String): Boolean;
Var F: File; OldMode: Byte; Size,Got,P,W,H,X,Y,RB,K: LongInt;
    D: PPNBytes; Pix: PByte; Bin,Failed: Boolean; B: Byte;
Begin
 ImgLoadPBM:=False; D:=Nil; Pix:=Nil;
 Assign(F,FN); OldMode:=FileMode; FileMode:=0;
 {$I-}Reset(F,1);{$I+}
 FileMode:=OldMode;
 If IOResult<>0 Then Exit;
 {$I-}Size:=FileSize(F);{$I+}
 Failed:=(IOResult<>0) Or (Size<7) Or (Size>134217728);
 If Not Failed Then Begin
  D:=PPNBytes(JDAllocate(Size));
  If D=Nil Then Failed:=True
  Else Begin
   {$I-}BlockRead(F,D^,Size,Got);{$I+}
   Failed:=(IOResult<>0) Or (Got<>Size);
  End;
 End;
 {$I-}Close(F);{$I+}
 If IOResult<>0 Then Failed:=True;
 If Not Failed Then Begin
  If (D^[0]<>80) Or Not (D^[1] In [49,52]) Then Failed:=True;
 End;
 If Not Failed Then Begin
  Bin:=D^[1]=52; P:=2;
  W:=ImgPbmNum(D,Size,P); H:=ImgPbmNum(D,Size,P);
  If (W<1) Or (H<1) Or (W>PnMAX_IMAGE_WIDTH) Or (H>PnMAX_IMAGE_HEIGHT) Then Failed:=True;
 End;
 If Not Failed Then Begin
  Pix:=PByte(JDAllocate(W*H));
  If Pix=Nil Then Failed:=True;
 End;
 If Not Failed Then Begin
  If Bin Then Begin
   Inc(P); RB:=(W+7) Div 8;
   If Size-P<RB*H Then Failed:=True
   Else
    For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
     B:=D^[P+Y*RB+(X Shr 3)];
     PPNBytes(Pix)^[Y*W+X]:=(B Shr (7-(X And 7))) And 1;
    End;
  End Else Begin
   K:=0;
   While (Not Failed) And (K<W*H) Do Begin
    While (P<Size) And (D^[P] In [9,10,11,12,13,32]) Do Inc(P);
    If (P>=Size) Or ((D^[P]<>48) And (D^[P]<>49)) Then Failed:=True
    Else Begin PPNBytes(Pix)^[K]:=D^[P]-48; Inc(P); Inc(K); End;
   End;
  End;
 End;
 If D<>Nil Then FreeMem(D,Size);
 If Failed Then Begin
  If Pix<>Nil Then FreeMem(Pix,W*H);
  Exit;
 End;
 PnCanvasImage:=Pix; PnCanvasImageW:=W; PnCanvasImageH:=H;
 FillChar(PnImageBuffer.Palette,SizeOf(PnImageBuffer.Palette),0);
 PnImageBuffer.Palette[0].R:=255; PnImageBuffer.Palette[0].G:=255; PnImageBuffer.Palette[0].B:=255;
 ImgLoadPBM:=True;
End;

Function ImgLoadFmt(Fmt: Byte; Const FN: String): Boolean;
Begin
 Case Fmt Of
  PnFMT_BMP,PnFMT_DIB: ImgLoadFmt:=LoadDIB(FN);
  PnFMT_GIF: ImgLoadFmt:=LoadGIF(FN);
  PnFMT_PNG: ImgLoadFmt:=LoadPNG(FN);
  PnFMT_APNG: ImgLoadFmt:=LoadAPNG(FN) Or LoadPNG(FN);
  PnFMT_JPEG: ImgLoadFmt:=LoadJPEG(FN);
  PnFMT_PCX: ImgLoadFmt:=LoadPCX(FN);
  PnFMT_TARGA: ImgLoadFmt:=LoadTGA(FN);
  PnFMT_PPM: ImgLoadFmt:=LoadPPM(FN) Or ImgLoadPBM(FN);
  PnFMT_XBM: ImgLoadFmt:=LoadXBM(FN);
  PnFMT_LBM: ImgLoadFmt:=LoadLBM(FN);
  PnFMT_TIFF: ImgLoadFmt:=LoadTIFF(FN);
  PnFMT_BGX: ImgLoadFmt:=LoadBGX(FN);
  PnFMT_WPG: ImgLoadFmt:=LoadWPG(FN);
  PnFMT_MSP: ImgLoadFmt:=LoadMSP(FN);
  PnFMT_MAC: ImgLoadFmt:=LoadMAC(FN);
  PnFMT_ICO: ImgLoadFmt:=LoadICO(FN);
  PnFMT_CUR: ImgLoadFmt:=LoadCUR(FN);
  PnFMT_DDS: ImgLoadFmt:=LoadDDS(FN);
  PnFMT_HDR: ImgLoadFmt:=LoadHDR(FN);
  PnFMT_EXR: ImgLoadFmt:=LoadEXR(FN);
  PnFMT_DNG: ImgLoadFmt:=LoadDNG(FN);
  PnFMT_CR2: ImgLoadFmt:=LoadCR2(FN);
  PnFMT_ARW: ImgLoadFmt:=LoadARW(FN);
  PnFMT_DCM: ImgLoadFmt:=LoadDCM(FN);
  PnFMT_FAX: ImgLoadFmt:=LoadFAX(FN);
  Else ImgLoadFmt:=False;
 End;
End;

Procedure ImgRelease;
Begin
 If PnCanvasImage<>Nil Then FreeMem(PnCanvasImage,LongInt(PnCanvasImageW)*PnCanvasImageH);
 PnCanvasImage:=Nil; PnCanvasImageW:=0; PnCanvasImageH:=0;
 If ImgCapRGB<>Nil Then FreeMem(ImgCapRGB,ImgCapSize);
 ImgCapRGB:=Nil; ImgCapSize:=0; ImgCapW:=0; ImgCapH:=0;
End;

{ Convertit le resultat du decodeur en RGB24 et l'emet une fois. }
Function ImgEmitResult: Boolean;
Var Pix: PByte; N,I,Total: LongInt; W,H: Integer; P: PByte; S: PByte; C: Byte;
Begin
 ImgEmitResult:=False;
 W:=PnCanvasImageW; H:=PnCanvasImageH;
 If (PnCanvasImage=Nil) Or (W<1) Or (H<1) Then Exit;
 Total:=LongInt(W)*H;
 If (ImgCapRGB<>Nil) And (ImgCapW=W) And (ImgCapH=H) Then Begin
  { Pleine qualite : copie RGB interceptee avant la quantification. }
  ImgEmitResult:=True;
  ConfEmit(W,H,ImgCapRGB);
 End Else Begin
  Pix:=PByte(JDAllocate(Total*3));
  If Pix=Nil Then Exit;
  P:=Pix; S:=PnCanvasImage;
  For N:=1 To Total Do Begin
   C:=S^; Inc(S);
   P^:=PnImageBuffer.Palette[C].R; Inc(P);
   P^:=PnImageBuffer.Palette[C].G; Inc(P);
   P^:=PnImageBuffer.Palette[C].B; Inc(P);
  End;
  ImgEmitResult:=True;
  ConfEmit(W,H,Pix);
  FreeMem(Pix,Total*3);
 End;
End;

Function ImgConform(Const FN: String): Boolean;
Var Ext: String; FS,FE: Byte; OK: Boolean;
Begin
 ImgConform:=False;
 PnCanvasImage:=Nil; PnCanvasImageW:=0; PnCanvasImageH:=0;
 ImgCapRGB:=Nil; ImgCapSize:=0; ImgCapW:=0; ImgCapH:=0;
 FillChar(PnImageBuffer,SizeOf(PnImageBuffer),0);
 Ext:=ImgExtOf(FN);
 FS:=ImgFmtOfSig(FN,Ext);
 FE:=ImgFmtOfExt(Ext);
 If (FS=255) And (FE=255) Then Exit;
 OK:=False;
 If FS<>255 Then OK:=ImgLoadFmt(FS,FN);
 If (Not OK) And (FE<>255) And (FE<>FS) Then Begin
  ImgRelease;
  OK:=ImgLoadFmt(FE,FN);
 End;
 If OK Then ImgConform:=ImgEmitResult;
 ImgRelease;
End;
{$POP}
{$ELSE}
Function ImgKnownExt(Const Ext: String): Boolean;
Begin
 ImgKnownExt:=False;
End;

Function ImgConform(Const FN: String): Boolean;
Begin
 ImgConform:=False;
End;
{$ENDIF}
{ ======================================================================
  vidmisc.pas - importeurs video/audio divers, Pascal pur (prefixe V3) :
    V3AviConform  AVI (BI_RGB 1/4/8/16/24/32, MJPG, MSRLE, MSVC/CRAM, CVID)
    V3AviCodec    FourCC du flux video d'un AVI
    V3GifConform  GIF anime        V3Y4mConform  YUV4MPEG2
    V3FliConform  Autodesk FLI/FLC V3WavConform  WAV PCM -> crete audio
  Fragment a coller apres les declarations globales de l'hote (il attend
  ConfEmit, ConfSetFps, ConfProgress et ConfAudioEmit). Mode TP de FPC ;
  sous Turbo Pascal 7 les six fonctions sont des stubs qui retournent False.
  ====================================================================== }
{$IFDEF FPC}
{$PUSH}{$R-}{$Q-}{$I-}
Const
 V3JZig: Array[0..63] Of Byte =
  (0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,
   12,19,26,33,40,48,41,34,27,20,13,6,7,14,21,28,
   35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,
   58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63);
 { Tables de Huffman standard (T.81 annexe K.3), injectees si DHT absent. }
 V3JStdDCLN: Array[1..16] Of Byte = (0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0);
 V3JStdDCLV: Array[0..11] Of Byte =
  (0,1,2,3,4,5,6,7,8,9,10,11);
 V3JStdDCCN: Array[1..16] Of Byte = (0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0);
 V3JStdDCCV: Array[0..11] Of Byte =
  (0,1,2,3,4,5,6,7,8,9,10,11);
 V3JStdACLN: Array[1..16] Of Byte = (0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,125);
 V3JStdACLV: Array[0..161] Of Byte =
  (1,2,3,0,4,17,5,18,33,49,65,6,19,81,97,7,34,113,20,50,129,145,161,8,35,66,177,193,21,82,
   209,240,36,51,98,114,130,9,10,22,23,24,25,26,37,38,39,40,41,42,52,53,54,55,56,57,58,67,
   68,69,70,71,72,73,74,83,84,85,86,87,88,89,90,99,100,101,102,103,104,105,106,115,116,117,
   118,119,120,121,122,131,132,133,134,135,136,137,138,146,147,148,149,150,151,152,153,154,
   162,163,164,165,166,167,168,169,170,178,179,180,181,182,183,184,185,186,194,195,196,197,
   198,199,200,201,202,210,211,212,213,214,215,216,217,218,225,226,227,228,229,230,231,232,
   233,234,241,242,243,244,245,246,247,248,249,250);
 V3JStdACCN: Array[1..16] Of Byte = (0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,119);
 V3JStdACCV: Array[0..161] Of Byte =
  (0,1,2,3,17,4,5,33,49,6,18,65,81,7,97,113,19,34,50,129,8,20,66,145,161,177,193,9,35,51,
   82,240,21,98,114,209,10,22,36,52,225,37,241,23,24,25,26,38,39,40,41,42,53,54,55,56,57,
   58,67,68,69,70,71,72,73,74,83,84,85,86,87,88,89,90,99,100,101,102,103,104,105,106,115,
   116,117,118,119,120,121,122,130,131,132,133,134,135,136,137,138,146,147,148,149,150,151,
   152,153,154,162,163,164,165,166,167,168,169,170,178,179,180,181,182,183,184,185,186,194,
   195,196,197,198,199,200,201,202,210,211,212,213,214,215,216,217,218,226,227,228,229,230,
   231,232,233,234,242,243,244,245,246,247,248,249,250);
Type
 TV3Bytes = Array[0..134217726] Of Byte;
 PV3Bytes = ^TV3Bytes;
 TV3Longs = Array[0..33554430] Of LongInt;
 PV3Longs = ^TV3Longs;
 TV3Rd = Record
  F: File;
  Opened,Eof: Boolean;
  Size,Base: Int64;
  Len,Pos: LongInt;
  Buf: Array[0..32767] Of Byte;
 End;
 PV3Rd = ^TV3Rd;

Var
 V3Cnt: LongInt;      { images (ou fenetres audio) emises par l'import en cours }
 V3Stop: Boolean;     { l'hote a demande l'arret }

{ ---------------------------------------------------------------- outils }
Function V3Alloc(Size: LongInt): Pointer;
Var P: Pointer; Previous: Boolean;
Begin
 P:=Nil;
 If (Size>0) And (Size<1500000000) Then Begin
  Previous:=ReturnNilIfGrowHeapFails; ReturnNilIfGrowHeapFails:=True;
  GetMem(P,Size); ReturnNilIfGrowHeapFails:=Previous;
 End;
 V3Alloc:=P;
End;

Procedure V3Release(Var P: PV3Bytes);
Begin
 If P<>Nil Then FreeMem(P);
 P:=Nil;
End;

Function V3Put(W,H: LongInt; P: PV3Bytes): Boolean;
Begin
 Inc(V3Cnt);
 If Not ConfEmit(W,H,P) Then V3Stop:=True;
 V3Put:=Not V3Stop;
End;

Function V3Clip(V: LongInt): LongInt;
Begin
 If V<0 Then V3Clip:=0 Else If V>255 Then V3Clip:=255 Else V3Clip:=V;
End;

Function V3Gcd(A,B: LongInt): LongInt;
Var T: LongInt;
Begin
 While B<>0 Do Begin T:=A Mod B; A:=B; B:=T; End;
 V3Gcd:=A;
End;

{ ------------------------------------------------- lecteur de fichier }
Function V3RdOpen(Var R: TV3Rd; Const FN: String): Boolean;
Var Old: Byte;
Begin
 V3RdOpen:=False; R.Opened:=False; R.Eof:=False; R.Len:=0; R.Pos:=0;
 R.Base:=0; R.Size:=0;
 Assign(R.F,FN); Old:=FileMode; FileMode:=0;
 Reset(R.F,1); FileMode:=Old;
 If IOResult<>0 Then Exit;
 R.Size:=FileSize(R.F);
 If IOResult<>0 Then Begin Close(R.F); If IOResult=0 Then; Exit; End;
 R.Opened:=True; V3RdOpen:=True;
End;

Procedure V3RdClose(Var R: TV3Rd);
Begin
 If R.Opened Then Begin Close(R.F); If IOResult=0 Then; End;
 R.Opened:=False;
End;

Procedure V3RdFill(Var R: TV3Rd);
Var N: LongInt;
Begin
 Inc(R.Base,R.Len); R.Len:=0; R.Pos:=0; N:=0;
 If R.Opened Then Begin
  BlockRead(R.F,R.Buf,SizeOf(R.Buf),N);
  If IOResult<>0 Then N:=0;
 End;
 If N<=0 Then Begin N:=0; R.Eof:=True; End;
 R.Len:=N;
End;

Function V3RdByte(Var R: TV3Rd): LongInt;
Begin
 If R.Pos>=R.Len Then V3RdFill(R);
 If R.Pos>=R.Len Then Begin R.Eof:=True; V3RdByte:=-1; Exit; End;
 V3RdByte:=R.Buf[R.Pos]; Inc(R.Pos);
End;

Function V3RdTell(Var R: TV3Rd): Int64;
Begin
 V3RdTell:=R.Base+R.Pos;
End;

Procedure V3RdSeek(Var R: TV3Rd; P: Int64);
Begin
 If P<0 Then P:=0;
 If (P>=R.Base) And (P<R.Base+R.Len) Then Begin R.Pos:=P-R.Base; Exit; End;
 If P>R.Size Then P:=R.Size;
 Seek(R.F,P); If IOResult<>0 Then R.Eof:=True;
 R.Base:=P; R.Len:=0; R.Pos:=0;
End;

{ Lit N octets ; retourne le nombre d'octets lus (< N en fin de fichier). }
Function V3RdRead(Var R: TV3Rd; Dst: PV3Bytes; N: LongInt): LongInt;
Var Done,K,Got: LongInt;
Begin
 Done:=0;
 While Done<N Do Begin
  If R.Pos>=R.Len Then Begin
   If N-Done>=SizeOf(R.Buf) Then Begin
    Inc(R.Base,R.Len); R.Len:=0; R.Pos:=0; Got:=0;
    BlockRead(R.F,Dst^[Done],N-Done,Got);
    If IOResult<>0 Then Got:=0;
    Inc(R.Base,Got); Inc(Done,Got);
    If Got<=0 Then R.Eof:=True;
    Break;
   End;
   V3RdFill(R);
   If R.Len=0 Then Break;
  End;
  K:=R.Len-R.Pos; If K>N-Done Then K:=N-Done;
  Move(R.Buf[R.Pos],Dst^[Done],K); Inc(R.Pos,K); Inc(Done,K);
 End;
 V3RdRead:=Done;
End;

Function V3Rd16(Var R: TV3Rd): LongInt;
Var A: LongInt;
Begin
 A:=V3RdByte(R); V3Rd16:=A Or (V3RdByte(R) Shl 8);
End;

{ entier 32 bits non signe, retourne en Int64 }
Function V3Rd32(Var R: TV3Rd): Int64;
Var A,B,C: LongInt;
Begin
 A:=V3RdByte(R); B:=V3RdByte(R); C:=V3RdByte(R);
 V3Rd32:=Int64(A And 255)+Int64(B And 255)*256+Int64(C And 255)*65536+Int64(V3RdByte(R) And 255)*16777216;
End;

{ ------------------------------------- conversion YUV planaire -> RGB24 }
{ PU/PV nil => gris. CW/CH : dimensions des plans de chrominance (replication,
  comme swscale). Full : plage 0..255 (JFIF) sinon 16..235 (BT.601). }
Procedure V3YuvRgb(PY,PU,PV: PV3Bytes; SY,SU,SV,W,H,CW,CH: LongInt;
                   Full: Boolean; Dst: PV3Bytes);
Var X,Y,YY,CU,CV,RR,GG,BB,Q,D,RU,RV,SX,SYY: LongInt; XC: PV3Longs;
Begin
 If (W<1) Or (H<1) Then Exit;
 If PU=Nil Then Begin
  D:=0;
  For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
   YY:=PY^[Y*SY+X];
   If Not Full Then YY:=V3Clip(SarLongint((YY-16)*298+128,8));
   Dst^[D]:=YY; Dst^[D+1]:=YY; Dst^[D+2]:=YY; Inc(D,3);
  End;
  Exit;
 End;
 XC:=V3Alloc(W*4);
 If XC=Nil Then Exit;
 SX:=W Div CW; If SX<1 Then SX:=1;
 While (SX<W) And ((W+SX-1) Div SX>CW) Do Inc(SX);
 SYY:=H Div CH; If SYY<1 Then SYY:=1;
 While (SYY<H) And ((H+SYY-1) Div SYY>CH) Do Inc(SYY);
 For X:=0 To W-1 Do Begin
  XC^[X]:=X Div SX;
  If XC^[X]>CW-1 Then XC^[X]:=CW-1;
 End;
 D:=0;
 For Y:=0 To H-1 Do Begin
  RU:=Y Div SYY; If RU>CH-1 Then RU:=CH-1;
  RV:=RU*SV; RU:=RU*SU;
  For X:=0 To W-1 Do Begin
   YY:=PY^[Y*SY+X];
   CU:=PU^[RU+XC^[X]]-128; CV:=PV^[RV+XC^[X]]-128;
   If Full Then Begin
    RR:=YY+SarLongint(91881*CV+32768,16);
    GG:=YY-SarLongint(22554*CU+46802*CV+32768,16);
    BB:=YY+SarLongint(116130*CU+32768,16);
   End Else Begin
    Q:=(YY-16)*298+128;
    RR:=SarLongint(Q+409*CV,8);
    GG:=SarLongint(Q-100*CU-208*CV,8);
    BB:=SarLongint(Q+516*CU,8);
   End;
   Dst^[D]:=V3Clip(RR); Dst^[D+1]:=V3Clip(GG); Dst^[D+2]:=V3Clip(BB); Inc(D,3);
  End;
 End;
 FreeMem(XC);
End;

{ ================================================= decodeur JPEG baseline }
Type
 TV3JHuff = Record
  Ready: Boolean;
  LookNb: Array[0..255] Of Byte;
  LookSym: Array[0..255] Of Byte;
  MinCode,MaxCode,ValPtr: Array[1..16] Of LongInt;
  Vals: Array[0..255] Of Byte;
 End;
 TV3JComp = Record
  Id,H,V,Tq,Td,Ta: LongInt;
  BW,BH,Stride,RealW,RealH,Pred: LongInt;
  Plane: PV3Bytes;
  Cap: LongInt;
 End;
 TV3JBlk = Array[0..63] Of LongInt;

Var
 V3JQ: Array[0..3,0..63] Of LongInt;
 V3JQok: Array[0..3] Of Boolean;
 V3JHt: Array[0..1,0..3] Of TV3JHuff;
 V3JC: Array[0..3] Of TV3JComp;
 V3JNC,V3JW,V3JH,V3JMaxH,V3JMaxV,V3JMcuW,V3JMcuH,V3JRst: LongInt;
 V3JFrame,V3JScan,V3JBad,V3JAdobe: Boolean;
 V3JAdobeT: LongInt;
 V3JD: PV3Bytes;
 V3JLen,V3JPos: LongInt;
 V3JBuf: LongWord;
 V3JCnt,V3JPad: LongInt;
 V3JHit: Boolean;
 V3JOut: PV3Bytes; V3JOutCap: LongInt;

Procedure V3JFill;
Var B: LongInt;
Begin
 While V3JCnt<=24 Do Begin
  B:=0;
  If V3JHit Or (V3JPos>=V3JLen) Then Begin Inc(V3JPad,8); End
  Else Begin
   B:=V3JD^[V3JPos];
   If B=255 Then Begin
    If (V3JPos+1<V3JLen) And (V3JD^[V3JPos+1]=0) Then Inc(V3JPos,2)
    Else Begin V3JHit:=True; B:=0; Inc(V3JPad,8); End;
   End Else Inc(V3JPos);
  End;
  V3JBuf:=V3JBuf Or (LongWord(B) Shl (24-V3JCnt));
  Inc(V3JCnt,8);
 End;
End;

Procedure V3JBuild(Var H: TV3JHuff; Cnt: PV3Bytes; Vals: PV3Bytes);
Var L,N,I,K,C,Sh,E,Q: LongInt;
Begin
 FillChar(H.LookNb,SizeOf(H.LookNb),0);
 FillChar(H.LookSym,SizeOf(H.LookSym),0);
 K:=0; C:=0;
 For L:=1 To 16 Do Begin
  N:=Cnt^[L-1];
  H.ValPtr[L]:=K; H.MinCode[L]:=C;
  If N>0 Then H.MaxCode[L]:=C+N-1 Else H.MaxCode[L]:=-1;
  If (C+N>(LongInt(1) Shl L)) Or (K+N>256) Then Begin V3JBad:=True; Exit; End;
  For I:=0 To N-1 Do H.Vals[K+I]:=Vals^[K+I];
  If L<=8 Then
   For I:=0 To N-1 Do Begin
    Sh:=8-L; E:=(C+I) Shl Sh;
    For Q:=0 To (LongInt(1) Shl Sh)-1 Do Begin
     H.LookNb[E+Q]:=L; H.LookSym[E+Q]:=Vals^[K+I];
    End;
   End;
  Inc(K,N); C:=(C+N) Shl 1;
 End;
 H.Ready:=True;
End;

Function V3JSym(Var H: TV3JHuff): LongInt;
Var Look,L,Code: LongInt;
Begin
 V3JFill;
 Look:=V3JBuf Shr 24;
 L:=H.LookNb[Look];
 If L>0 Then Begin
  V3JBuf:=V3JBuf Shl L; Dec(V3JCnt,L); V3JSym:=H.LookSym[Look]; Exit;
 End;
 For L:=9 To 16 Do Begin
  Code:=V3JBuf Shr (32-L);
  If (H.MaxCode[L]>=0) And (Code<=H.MaxCode[L]) And (Code>=H.MinCode[L]) Then Begin
   V3JBuf:=V3JBuf Shl L; Dec(V3JCnt,L);
   V3JSym:=H.Vals[H.ValPtr[L]+Code-H.MinCode[L]]; Exit;
  End;
 End;
 V3JBad:=True; V3JSym:=0;
 V3JBuf:=V3JBuf Shl 16; Dec(V3JCnt,16);
End;

Function V3JRecv(S: LongInt): LongInt;
Var V: LongInt;
Begin
 If S=0 Then Begin V3JRecv:=0; Exit; End;
 If S>16 Then Begin V3JBad:=True; V3JRecv:=0; Exit; End;
 V3JFill;
 V:=V3JBuf Shr (32-S);
 V3JBuf:=V3JBuf Shl S; Dec(V3JCnt,S);
 If V<(LongInt(1) Shl (S-1)) Then V:=V-(LongInt(1) Shl S)+1;
 V3JRecv:=V;
End;

{ DCT inverse entiere (jidctint de l'IJG, 8 bits). }
Procedure V3JIdct(Var C: TV3JBlk; Dst: PV3Bytes; Stride: LongInt);
Var Ws: Array[0..63] Of LongInt; I,J,Z1,Z2,Z3,Z4,Z5,T0,T1,T2,T3,T10,T11,T12,T13,B: LongInt;
Begin
 For I:=0 To 7 Do Begin
  If (C[I+8]=0) And (C[I+16]=0) And (C[I+24]=0) And (C[I+32]=0) And
     (C[I+40]=0) And (C[I+48]=0) And (C[I+56]=0) Then Begin
   Z1:=C[I] Shl 2;
   For J:=0 To 7 Do Ws[I+J*8]:=Z1;
  End Else Begin
   Z2:=C[I+16]; Z3:=C[I+48];
   Z1:=(Z2+Z3)*4433; T2:=Z1-Z3*15137; T3:=Z1+Z2*6270;
   T0:=(C[I]+C[I+32]) Shl 13; T1:=(C[I]-C[I+32]) Shl 13;
   T10:=T0+T3; T13:=T0-T3; T11:=T1+T2; T12:=T1-T2;
   T0:=C[I+56]; T1:=C[I+40]; T2:=C[I+24]; T3:=C[I+8];
   Z1:=T0+T3; Z2:=T1+T2; Z3:=T0+T2; Z4:=T1+T3; Z5:=(Z3+Z4)*9633;
   T0:=T0*2446; T1:=T1*16819; T2:=T2*25172; T3:=T3*12299;
   Z1:=-Z1*7373; Z2:=-Z2*20995; Z3:=-Z3*16069+Z5; Z4:=-Z4*3196+Z5;
   Inc(T0,Z1+Z3); Inc(T1,Z2+Z4); Inc(T2,Z2+Z3); Inc(T3,Z1+Z4);
   Ws[I]:=SarLongint(T10+T3+1024,11);    Ws[I+56]:=SarLongint(T10-T3+1024,11);
   Ws[I+8]:=SarLongint(T11+T2+1024,11);  Ws[I+48]:=SarLongint(T11-T2+1024,11);
   Ws[I+16]:=SarLongint(T12+T1+1024,11); Ws[I+40]:=SarLongint(T12-T1+1024,11);
   Ws[I+24]:=SarLongint(T13+T0+1024,11); Ws[I+32]:=SarLongint(T13-T0+1024,11);
  End;
 End;
 For I:=0 To 7 Do Begin
  B:=I*8;
  Z2:=Ws[B+2]; Z3:=Ws[B+6];
  Z1:=(Z2+Z3)*4433; T2:=Z1-Z3*15137; T3:=Z1+Z2*6270;
  T0:=(Ws[B]+Ws[B+4]) Shl 13; T1:=(Ws[B]-Ws[B+4]) Shl 13;
  T10:=T0+T3; T13:=T0-T3; T11:=T1+T2; T12:=T1-T2;
  T0:=Ws[B+7]; T1:=Ws[B+5]; T2:=Ws[B+3]; T3:=Ws[B+1];
  Z1:=T0+T3; Z2:=T1+T2; Z3:=T0+T2; Z4:=T1+T3; Z5:=(Z3+Z4)*9633;
  T0:=T0*2446; T1:=T1*16819; T2:=T2*25172; T3:=T3*12299;
  Z1:=-Z1*7373; Z2:=-Z2*20995; Z3:=-Z3*16069+Z5; Z4:=-Z4*3196+Z5;
  Inc(T0,Z1+Z3); Inc(T1,Z2+Z4); Inc(T2,Z2+Z3); Inc(T3,Z1+Z4);
  J:=I*Stride;
  Dst^[J]:=V3Clip(SarLongint(T10+T3+131072,18)+128);
  Dst^[J+7]:=V3Clip(SarLongint(T10-T3+131072,18)+128);
  Dst^[J+1]:=V3Clip(SarLongint(T11+T2+131072,18)+128);
  Dst^[J+6]:=V3Clip(SarLongint(T11-T2+131072,18)+128);
  Dst^[J+2]:=V3Clip(SarLongint(T12+T1+131072,18)+128);
  Dst^[J+5]:=V3Clip(SarLongint(T12-T1+131072,18)+128);
  Dst^[J+3]:=V3Clip(SarLongint(T13+T0+131072,18)+128);
  Dst^[J+4]:=V3Clip(SarLongint(T13-T0+131072,18)+128);
 End;
End;

Procedure V3JBlock(Ci,BX,BY: LongInt);
Var Blk: TV3JBlk; S,R,K,Sym: LongInt;
Begin
 FillChar(Blk,SizeOf(Blk),0);
 With V3JC[Ci] Do Begin
  S:=V3JSym(V3JHt[0,Td]);
  If S>11 Then V3JBad:=True;
  If V3JBad Then Exit;
  Pred:=Pred+V3JRecv(S);
  Blk[0]:=Pred*V3JQ[Tq,0];
  K:=1;
  While K<64 Do Begin
   Sym:=V3JSym(V3JHt[1,Ta]);
   If V3JBad Then Exit;
   R:=Sym Shr 4; S:=Sym And 15;
   If S=0 Then Begin
    If R=15 Then Inc(K,16) Else Break;
   End Else Begin
    Inc(K,R);
    If K>63 Then Begin V3JBad:=True; Exit; End;
    Blk[V3JZig[K]]:=V3JRecv(S)*V3JQ[Tq,V3JZig[K]];
    Inc(K);
   End;
  End;
  V3JIdct(Blk,@Plane^[BY*8*Stride+BX*8],Stride);
 End;
End;

Function V3JW16(P: LongInt): LongInt;
Begin
 If P+1>=V3JLen Then V3JW16:=0 Else V3JW16:=V3JD^[P]*256+V3JD^[P+1];
End;

Procedure V3JDefaults;
Var K: LongInt;
Begin
 For K:=0 To 1 Do If Not V3JHt[0,K].Ready Then
  If K=0 Then V3JBuild(V3JHt[0,0],@V3JStdDCLN,@V3JStdDCLV)
  Else V3JBuild(V3JHt[0,1],@V3JStdDCCN,@V3JStdDCCV);
 For K:=0 To 1 Do If Not V3JHt[1,K].Ready Then
  If K=0 Then V3JBuild(V3JHt[1,0],@V3JStdACLN,@V3JStdACLV)
  Else V3JBuild(V3JHt[1,1],@V3JStdACCN,@V3JStdACCV);
End;

Procedure V3JFrameHdr(P,E: LongInt);
Var I,J,Sp,N: LongInt;
Begin
 If V3JFrame Or (E-P<6) Then Begin V3JBad:=True; Exit; End;
 If V3JD^[P]<>8 Then Begin V3JBad:=True; Exit; End;
 V3JH:=V3JW16(P+1); V3JW:=V3JW16(P+3); V3JNC:=V3JD^[P+5];
 If (V3JW<1) Or (V3JH<1) Or (V3JW>16384) Or (V3JH>16384) Or
    Not ((V3JNC=1) Or (V3JNC=3)) Or (E-P<>6+V3JNC*3) Then Begin V3JBad:=True; Exit; End;
 V3JMaxH:=1; V3JMaxV:=1;
 For I:=0 To V3JNC-1 Do With V3JC[I] Do Begin
  N:=P+6+I*3;
  Id:=V3JD^[N]; Sp:=V3JD^[N+1]; H:=Sp Shr 4; V:=Sp And 15; Tq:=V3JD^[N+2];
  If (H<1) Or (H>4) Or (V<1) Or (V>4) Or (Tq>3) Then Begin V3JBad:=True; Exit; End;
  For J:=0 To I-1 Do If V3JC[J].Id=Id Then Begin V3JBad:=True; Exit; End;
  If H>V3JMaxH Then V3JMaxH:=H;
  If V>V3JMaxV Then V3JMaxV:=V;
 End;
 V3JMcuW:=(V3JW+8*V3JMaxH-1) Div (8*V3JMaxH);
 V3JMcuH:=(V3JH+8*V3JMaxV-1) Div (8*V3JMaxV);
 For I:=0 To V3JNC-1 Do With V3JC[I] Do Begin
  BW:=V3JMcuW*H; BH:=V3JMcuH*V; Stride:=BW*8;
  RealW:=(V3JW*H+V3JMaxH-1) Div V3JMaxH;
  RealH:=(V3JH*V+V3JMaxV-1) Div V3JMaxV;
  N:=Stride*BH*8;
  If (Plane=Nil) Or (Cap<>N) Then Begin
   V3Release(Plane); Plane:=V3Alloc(N); Cap:=N;
   If Plane=Nil Then Begin V3JBad:=True; Exit; End;
  End;
  FillChar(Plane^,N,128);
 End;
 V3JFrame:=True;
End;

Procedure V3JScanData(P,E: LongInt);
Var NS,I,J,C,Id,Sp,SS,SE,Ah,AL,Mcu,Total,Across,Down,BX,BY,VY,HX: LongInt;
    Ord: Array[0..3] Of LongInt; Found: Boolean;
Begin
 If Not V3JFrame Then Begin V3JBad:=True; Exit; End;
 NS:=V3JD^[P]; Inc(P);
 If (NS<1) Or (NS>V3JNC) Or (E-P<>NS*2+3) Then Begin V3JBad:=True; Exit; End;
 For I:=0 To NS-1 Do Begin
  Id:=V3JD^[P]; Sp:=V3JD^[P+1]; Inc(P,2); Found:=False; C:=0;
  For J:=0 To V3JNC-1 Do If V3JC[J].Id=Id Then Begin C:=J; Found:=True; End;
  If Not Found Or ((Sp Shr 4)>1) Or ((Sp And 15)>1) Then Begin V3JBad:=True; Exit; End;
  Ord[I]:=C; V3JC[C].Td:=Sp Shr 4; V3JC[C].Ta:=Sp And 15;
  If Not V3JQok[V3JC[C].Tq] Then Begin V3JBad:=True; Exit; End;
 End;
 SS:=V3JD^[P]; SE:=V3JD^[P+1]; Ah:=V3JD^[P+2] Shr 4; AL:=V3JD^[P+2] And 15;
 If (SS<>0) Or (SE<>63) Or (Ah<>0) Or (AL<>0) Then Begin V3JBad:=True; Exit; End;
 V3JDefaults;
 If V3JBad Then Exit;
 V3JPos:=E; V3JBuf:=0; V3JCnt:=0; V3JPad:=0; V3JHit:=False;
 For I:=0 To V3JNC-1 Do V3JC[I].Pred:=0;
 If NS=1 Then Begin
  C:=Ord[0]; Across:=(V3JC[C].RealW+7) Div 8; Down:=(V3JC[C].RealH+7) Div 8;
 End Else Begin Across:=V3JMcuW; Down:=V3JMcuH; End;
 Total:=Across*Down;
 For Mcu:=0 To Total-1 Do Begin
  If (Mcu>0) And (V3JRst>0) And ((Mcu Mod V3JRst)=0) Then Begin
   V3JBuf:=0; V3JCnt:=0; V3JPad:=0; V3JHit:=False;
   While (V3JPos+1<V3JLen) And Not ((V3JD^[V3JPos]=255) And (V3JD^[V3JPos+1]>=$D0)
         And (V3JD^[V3JPos+1]<=$D7)) Do Inc(V3JPos);
   If V3JPos+1>=V3JLen Then Begin V3JBad:=True; Exit; End;
   Inc(V3JPos,2);
   For I:=0 To V3JNC-1 Do V3JC[I].Pred:=0;
  End;
  BX:=Mcu Mod Across; BY:=Mcu Div Across;
  For I:=0 To NS-1 Do Begin
   C:=Ord[I];
   If NS=1 Then V3JBlock(C,BX,BY)
   Else For VY:=0 To V3JC[C].V-1 Do For HX:=0 To V3JC[C].H-1 Do
    V3JBlock(C,BX*V3JC[C].H+HX,BY*V3JC[C].V+VY);
   If V3JBad Then Exit;
  End;
  If V3JCnt<V3JPad Then Begin V3JBad:=True; Exit; End;
 End;
 V3JScan:=True;
End;

{ Decode une trame JPEG (baseline) dans V3JC[].Plane. }
Function V3JDecode(Data: PV3Bytes; Len: LongInt): Boolean;
Var M,L,P,I,N,Spec,Tb: LongInt; Ended: Boolean; Cnt: Array[0..15] Of Byte;
    Pr,T,Total: LongInt;
Begin
 V3JDecode:=False;
 V3JD:=Data; V3JLen:=Len; V3JPos:=0; V3JBad:=False; V3JFrame:=False;
 V3JScan:=False; V3JRst:=0; V3JAdobe:=False; V3JAdobeT:=-1;
 FillChar(V3JQok,SizeOf(V3JQok),0);
 For I:=0 To 3 Do Begin V3JHt[0,I].Ready:=False; V3JHt[1,I].Ready:=False; End;
 { SOI }
 While (V3JPos+1<Len) And Not ((Data^[V3JPos]=255) And (Data^[V3JPos+1]=$D8)) Do Inc(V3JPos);
 If V3JPos+1>=Len Then Exit;
 Inc(V3JPos,2);
 Ended:=False;
 While Not V3JBad And Not Ended Do Begin
  { prochain marqueur }
  While (V3JPos<Len) And (Data^[V3JPos]<>255) Do Inc(V3JPos);
  While (V3JPos<Len) And (Data^[V3JPos]=255) Do Inc(V3JPos);
  If V3JPos>=Len Then Break;
  M:=Data^[V3JPos]; Inc(V3JPos);
  If M=0 Then Continue;
  If (M=$D9) Then Begin Ended:=True; Break; End;
  If (M=$01) Or (M=$D8) Or ((M>=$D0) And (M<=$D7)) Then Continue;
  If V3JPos+2>Len Then Break;
  L:=V3JW16(V3JPos);
  If (L<2) Or (V3JPos+L>Len) Then Begin V3JBad:=True; Break; End;
  P:=V3JPos+2; N:=V3JPos+L;
  Case M Of
   $DB: While (P<N) And Not V3JBad Do Begin
         Spec:=Data^[P]; Inc(P); Pr:=Spec Shr 4; Tb:=Spec And 15;
         If (Pr>1) Or (Tb>3) Or (N-P<64*(Pr+1)) Then Begin V3JBad:=True; Break; End;
         For I:=0 To 63 Do Begin
          If Pr=0 Then T:=Data^[P] Else T:=Data^[P]*256+Data^[P+1];
          Inc(P,Pr+1);
          V3JQ[Tb,V3JZig[I]]:=T;
         End;
         V3JQok[Tb]:=True;
        End;
   $C4: While (N-P>=17) And Not V3JBad Do Begin
         Spec:=Data^[P]; Tb:=Spec And 15; Pr:=Spec Shr 4;
         Total:=0;
         For I:=0 To 15 Do Begin Cnt[I]:=Data^[P+1+I]; Inc(Total,Cnt[I]); End;
         If (Pr>1) Or (Tb>3) Or (Total>256) Or (P+17+Total>N) Then Begin V3JBad:=True; Break; End;
         V3JBuild(V3JHt[Pr,Tb],@Cnt,@Data^[P+17]);
         Inc(P,17+Total);
        End;
   $C0,$C1: V3JFrameHdr(P,N);
   $C2,$C3,$C5,$C6,$C7,$C9,$CA,$CB,$CD,$CE,$CF: V3JBad:=True;
   $DD: If L=4 Then V3JRst:=V3JW16(P) Else V3JBad:=True;
   $EE: If (L>=14) And (Data^[P]=65) And (Data^[P+1]=100) And (Data^[P+2]=111) And
           (Data^[P+3]=98) And (Data^[P+4]=101) Then Begin
         V3JAdobe:=True; V3JAdobeT:=Data^[P+11];
        End;
   $DA: Begin
         V3JScanData(P,N);
         Continue;  { V3JPos est deja place a la fin des donnees entropiques }
        End;
  End;
  V3JPos:=N;
 End;
 V3JDecode:=Not V3JBad And V3JFrame And V3JScan;
End;

Procedure V3JFreeAll;
Var I: LongInt;
Begin
 For I:=0 To 3 Do Begin V3Release(V3JC[I].Plane); V3JC[I].Cap:=0; End;
 V3Release(V3JOut); V3JOutCap:=0;
End;

{ Convertit la derniere trame decodee en RGB24 (V3JOut) ; W/H en sortie. }
Function V3JToRgb(Var W,H: LongInt): Boolean;
Var N,X,Y: LongInt; P0,P1,P2: PV3Bytes;
Begin
 V3JToRgb:=False;
 W:=V3JW; H:=V3JH; N:=W*H*3;
 If (V3JOut=Nil) Or (V3JOutCap<>N) Then Begin
  V3Release(V3JOut); V3JOut:=V3Alloc(N); V3JOutCap:=N;
  If V3JOut=Nil Then Exit;
 End;
 If V3JNC=1 Then
  V3YuvRgb(V3JC[0].Plane,Nil,Nil,V3JC[0].Stride,0,0,W,H,0,0,True,V3JOut)
 Else Begin
  If (V3JC[0].H<>V3JMaxH) Or (V3JC[0].V<>V3JMaxV) Or (V3JC[1].H<>V3JC[2].H) Or
     (V3JC[1].V<>V3JC[2].V) Then Exit;
  If V3JAdobe And (V3JAdobeT=0) And (V3JC[1].H=V3JMaxH) And (V3JC[1].V=V3JMaxV) Then Begin
   P0:=V3JC[0].Plane; P1:=V3JC[1].Plane; P2:=V3JC[2].Plane; N:=0;
   For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
    V3JOut^[N]:=P0^[Y*V3JC[0].Stride+X]; V3JOut^[N+1]:=P1^[Y*V3JC[1].Stride+X];
    V3JOut^[N+2]:=P2^[Y*V3JC[2].Stride+X]; Inc(N,3);
   End;
  End Else
   V3YuvRgb(V3JC[0].Plane,V3JC[1].Plane,V3JC[2].Plane,V3JC[0].Stride,V3JC[1].Stride,
            V3JC[2].Stride,W,H,V3JC[1].RealW,V3JC[1].RealH,True,V3JOut);
 End;
 V3JToRgb:=True;
End;

{ ======================================================================= AVI }
Type
 TV3CvBook = Array[0..255,0..11] Of Byte;
 TV3CvStrip = Record V4,V1: TV3CvBook; End;

Var
 V3AHd: Array[0..7] Of Byte;     { en-tete du chunk RIFF courant }
 V3AHasVid,V3AGotFmt,V3AReady,V3AFlip,V3AEight,V3AHasPrev: Boolean;
 V3AVid,V3ACurStr,V3AKind,V3AW,V3AH,V3ABpp,V3AComp,V3AScale,V3ARate,V3ALen,V3AMicro: LongInt;
 V3AFcc: String[4];
 V3APal: Array[0..255,0..2] Of Byte;
 V3AMask: Array[0..2] Of LongInt;
 V3ACur,V3AIdx,V3ABuf,V3ACv,V3AEmit: PV3Bytes;
 V3ABufCap,V3AEW,V3AEH,V3ACvPW,V3ACvPH,V3ASega: LongInt;
 V3ACvS: Array[0..31] Of TV3CvStrip;
 V3AFrames,V3AYuv: LongInt;

Function V3AIs(Const S: String): Boolean;
Var I: LongInt;
Begin
 V3AIs:=False;
 For I:=1 To 4 Do If V3AHd[I-1]<>Ord(S[I]) Then Exit;
 V3AIs:=True;
End;

Function V3A32(Var B: Array Of Byte; P: LongInt): LongInt;
Begin
 V3A32:=LongInt(B[P] Or (B[P+1] Shl 8) Or (B[P+2] Shl 16) Or (LongWord(B[P+3]) Shl 24));
End;

Function V3AU32(Var B: Array Of Byte; P: LongInt): Int64;
Begin
 V3AU32:=Int64(B[P])+Int64(B[P+1])*256+Int64(B[P+2])*65536+Int64(B[P+3])*16777216;
End;

Function V3AFourCC(Var B: Array Of Byte; P: LongInt): String;
Var S: String; I: LongInt;
Begin
 S:='';
 For I:=0 To 3 Do If (B[P+I]>=32) And (B[P+I]<127) Then S:=S+Chr(B[P+I]) Else S:=S+'?';
 V3AFourCC:=S;
End;

Function V3AUp(Const S: String): String;
Var I: LongInt; T: String;
Begin
 T:=S;
 For I:=1 To Length(T) Do If (T[I]>='a') And (T[I]<='z') Then T[I]:=Chr(Ord(T[I])-32);
 V3AUp:=T;
End;

{ classe du codec : 1 BI_RGB, 2 RLE, 3 MJPG, 4 MSVC/CRAM, 5 CVID, 0 non pris en charge }
Function V3AClass: LongInt;
Var S: String;
Begin
 V3AClass:=0;
 If V3AComp=0 Then Begin
  If (V3ABpp=1) Or (V3ABpp=4) Or (V3ABpp=8) Or (V3ABpp=16) Or (V3ABpp=24) Or (V3ABpp=32) Then V3AClass:=1;
  Exit;
 End;
 If (V3AComp=3) And ((V3ABpp=16) Or (V3ABpp=32)) Then Begin V3AClass:=1; Exit; End;
 If (V3AComp=1) And (V3ABpp=8) Then Begin V3AClass:=2; Exit; End;
 If (V3AComp=2) And (V3ABpp=4) Then Begin V3AClass:=2; Exit; End;
 If V3AComp<=3 Then Exit;
 S:=V3AUp(V3AFcc);
 If (S='MRLE') And ((V3ABpp=8) Or (V3ABpp=4)) Then V3AClass:=2
 Else If (S='MJPG') Or (S='JPEG') Or (S='AVRN') Or (S='LJPG') Or (S='IJPG') Or (S='DMB1') Then V3AClass:=3
 Else If (S='MSVC') Or (S='CRAM') Or (S='WHAM') Then Begin
  If (V3ABpp=8) Or (V3ABpp=16) Or (V3ABpp=15) Then V3AClass:=4;
 End Else If S='CVID' Then Begin
  If (V3ABpp=24) Or (V3ABpp=8) Or (V3ABpp=40) Then V3AClass:=5;
 End Else Begin
  V3AYuv:=0;
  If (S='YUY2') Or (S='YUYV') Or (S='YUNV') Or (S='V422') Then V3AYuv:=1
  Else If (S='UYVY') Or (S='UYNV') Or (S='Y422') Or (S='HDYC') Then V3AYuv:=2
  Else If S='YVYU' Then V3AYuv:=3
  Else If (S='I420') Or (S='IYUV') Then V3AYuv:=4
  Else If S='YV12' Then V3AYuv:=5;
  If V3AYuv>0 Then V3AClass:=6;
 End;
End;

Function V3ABit(M: LongInt): LongInt; { nombre de bits a droite de M (decalage) }
Var N: LongInt;
Begin
 N:=0;
 If M=0 Then Begin V3ABit:=0; Exit; End;
 While (M And 1)=0 Do Begin M:=M Shr 1; Inc(N); End;
 V3ABit:=N;
End;

Function V3AExtract(V,M: LongInt): LongInt;
Var Sh,Mx,N,X,R: LongInt;
Begin
 If M=0 Then Begin V3AExtract:=0; Exit; End;
 Sh:=V3ABit(M); Mx:=(M Shr Sh); X:=(V And M) Shr Sh;
 N:=0; While (Mx Shr N)<>0 Do Inc(N);
 If N>=8 Then V3AExtract:=X Shr (N-8)
 Else Begin
  { replication des bits de poids fort (comme swscale) }
  R:=X Shl (8-N);
  If 2*N>=8 Then R:=R Or (X Shr (2*N-8)) Else If N>0 Then R:=R Or (R Shr N) Or (R Shr (2*N));
  V3AExtract:=R And 255;
 End;
End;

Procedure V3AIdxToRgb;
Var X,Y,S,D: LongInt;
Begin
 D:=0;
 For Y:=0 To V3AH-1 Do Begin
  If V3AFlip Then S:=(V3AH-1-Y)*V3AW Else S:=Y*V3AW;
  For X:=0 To V3AW-1 Do Begin
   V3ACur^[D]:=V3APal[V3AIdx^[S+X],0]; V3ACur^[D+1]:=V3APal[V3AIdx^[S+X],1];
   V3ACur^[D+2]:=V3APal[V3AIdx^[S+X],2]; Inc(D,3);
  End;
 End;
End;

{ ---- BI_RGB ---- }
Function V3ARaw(Src: PV3Bytes; N: LongInt): Boolean;
Var RowB,X,Y,S,D,V: LongInt;
Begin
 V3ARaw:=False;
 RowB:=((V3AW*V3ABpp+31) Div 32)*4;
 If N<RowB*V3AH Then Exit;
 D:=0;
 For Y:=0 To V3AH-1 Do Begin
  If V3AFlip Then S:=(V3AH-1-Y)*RowB Else S:=Y*RowB;
  Case V3ABpp Of
   24: For X:=0 To V3AW-1 Do Begin
        V3ACur^[D]:=Src^[S+X*3+2]; V3ACur^[D+1]:=Src^[S+X*3+1]; V3ACur^[D+2]:=Src^[S+X*3]; Inc(D,3);
       End;
   32: If V3AComp=3 Then
        For X:=0 To V3AW-1 Do Begin
         V:=LongInt(Src^[S+X*4] Or (Src^[S+X*4+1] Shl 8) Or (Src^[S+X*4+2] Shl 16) Or (LongWord(Src^[S+X*4+3]) Shl 24));
         V3ACur^[D]:=V3AExtract(V,V3AMask[0]); V3ACur^[D+1]:=V3AExtract(V,V3AMask[1]);
         V3ACur^[D+2]:=V3AExtract(V,V3AMask[2]); Inc(D,3);
        End
       Else
        For X:=0 To V3AW-1 Do Begin
         V3ACur^[D]:=Src^[S+X*4+2]; V3ACur^[D+1]:=Src^[S+X*4+1]; V3ACur^[D+2]:=Src^[S+X*4]; Inc(D,3);
        End;
   16: For X:=0 To V3AW-1 Do Begin
        V:=Src^[S+X*2] Or (Src^[S+X*2+1] Shl 8);
        V3ACur^[D]:=V3AExtract(V,V3AMask[0]); V3ACur^[D+1]:=V3AExtract(V,V3AMask[1]);
        V3ACur^[D+2]:=V3AExtract(V,V3AMask[2]); Inc(D,3);
       End;
   8: For X:=0 To V3AW-1 Do Begin
       V:=Src^[S+X];
       V3ACur^[D]:=V3APal[V,0]; V3ACur^[D+1]:=V3APal[V,1]; V3ACur^[D+2]:=V3APal[V,2]; Inc(D,3);
      End;
   4: For X:=0 To V3AW-1 Do Begin
       V:=Src^[S+(X Shr 1)];
       If Odd(X) Then V:=V And 15 Else V:=V Shr 4;
       V3ACur^[D]:=V3APal[V,0]; V3ACur^[D+1]:=V3APal[V,1]; V3ACur^[D+2]:=V3APal[V,2]; Inc(D,3);
      End;
   1: For X:=0 To V3AW-1 Do Begin
       V:=(Src^[S+(X Shr 3)] Shr (7-(X And 7))) And 1;
       V3ACur^[D]:=V3APal[V,0]; V3ACur^[D+1]:=V3APal[V,1]; V3ACur^[D+2]:=V3APal[V,2]; Inc(D,3);
      End;
  End;
 End;
 V3ARaw:=True;
End;

{ ---- RLE8 / RLE4 (images deltas : l'image precedente est conservee) ---- }
Function V3ARle(Src: PV3Bytes; N: LongInt; Is4: Boolean): Boolean;
Var P,X,Y,C,V,I,B,Q: LongInt;
 Procedure Put(Pix: LongInt);
 Begin
  If (X>=0) And (X<V3AW) And (Y>=0) And (Y<V3AH) Then V3AIdx^[Y*V3AW+X]:=Pix;
  Inc(X);
 End;
Begin
 V3ARle:=False;
 If N<2 Then Exit;
 P:=0; X:=0; Y:=0;
 While P+1<N Do Begin
  C:=Src^[P]; V:=Src^[P+1]; Inc(P,2);
  If C>0 Then Begin
   If Is4 Then Begin
    For I:=0 To C-1 Do If Odd(I) Then Put(V And 15) Else Put(V Shr 4);
   End Else For I:=1 To C Do Put(V);
  End Else Begin
   Case V Of
    0: Begin X:=0; Inc(Y); End;
    1: Begin V3ARle:=True; Exit; End;
    2: Begin
        If P+1>=N Then Break;
        Inc(X,Src^[P]); Inc(Y,Src^[P+1]); Inc(P,2);
       End;
    Else Begin
     If Is4 Then Begin
      B:=(V+1) Div 2;
      If P+B>N Then Exit;
      For I:=0 To V-1 Do Begin
       Q:=Src^[P+(I Shr 1)];
       If Odd(I) Then Put(Q And 15) Else Put(Q Shr 4);
      End;
      Inc(P,B+(B And 1));
     End Else Begin
      If P+V>N Then Exit;
      For I:=0 To V-1 Do Put(Src^[P+I]);
      Inc(P,V+(V And 1));
     End;
    End;
   End;
  End;
  If Y>=V3AH+1 Then Break;
 End;
 V3ARle:=True;
End;

{ ---- Microsoft Video 1 (MSVC/CRAM) ---- }
Function V3AMv1(Pk: PV3Bytes; Sz: LongInt): Boolean;
Var Sp,Skip,BW,BH,Total,By,Bx,BlockPtr,PixelPtr,PX,PY,K,A,B,Flg,RowDec: LongInt;
    Colors: Array[0..7] Of LongInt;
 Procedure Put(Ptr,V: LongInt);
 Var Q: LongInt;
 Begin
  If V3AEight Then V3AIdx^[Ptr]:=V
  Else Begin
   Q:=Ptr*3;
   V3ACur^[Q]:=V3AExtract(V,$7C00); V3ACur^[Q+1]:=V3AExtract(V,$3E0); V3ACur^[Q+2]:=V3AExtract(V,$1F);
  End;
 End;
Begin
 V3AMv1:=False;
 If (V3AW<4) Or (V3AH<4) Then Exit;
 Sp:=0; Skip:=0; BW:=V3AW Div 4; BH:=V3AH Div 4; Total:=BW*BH; RowDec:=V3AW+4;
 For By:=BH Downto 1 Do Begin
  BlockPtr:=(By*4-1)*V3AW;
  For Bx:=BW Downto 1 Do Begin
   If Skip>0 Then Begin Inc(BlockPtr,4); Dec(Skip); Dec(Total); Continue; End;
   PixelPtr:=BlockPtr;
   If Sp+2>Sz Then Begin V3AMv1:=True; Exit; End;
   A:=Pk^[Sp]; B:=Pk^[Sp+1]; Inc(Sp,2);
   If (A=0) And (B=0) And (Total=0) Then Begin V3AMv1:=True; Exit; End
   Else If (B And $FC)=$84 Then Skip:=((B-$84) Shl 8)+A-1
   Else If B<$80 Then Begin
    Flg:=(B Shl 8) Or A;
    If V3AEight Then Begin
     If Sp+2>Sz Then Exit;
     Colors[0]:=Pk^[Sp]; Colors[1]:=Pk^[Sp+1]; Inc(Sp,2);
     For PY:=0 To 3 Do Begin
      For PX:=0 To 3 Do Begin Put(PixelPtr,Colors[(Flg And 1) Xor 1]); Inc(PixelPtr); Flg:=Flg Shr 1; End;
      Dec(PixelPtr,RowDec);
     End;
    End Else Begin
     If Sp+4>Sz Then Exit;
     Colors[0]:=Pk^[Sp]+Pk^[Sp+1]*256; Colors[1]:=Pk^[Sp+2]+Pk^[Sp+3]*256; Inc(Sp,4);
     If (Colors[0] And $8000)<>0 Then Begin
      If Sp+12>Sz Then Exit;
      For K:=2 To 7 Do Begin Colors[K]:=Pk^[Sp]+Pk^[Sp+1]*256; Inc(Sp,2); End;
      For PY:=0 To 3 Do Begin
       For PX:=0 To 3 Do Begin
        Put(PixelPtr,Colors[((PY And 2) Shl 1)+(PX And 2)+((Flg And 1) Xor 1)]);
        Inc(PixelPtr); Flg:=Flg Shr 1;
       End;
       Dec(PixelPtr,RowDec);
      End;
     End Else Begin
      For PY:=0 To 3 Do Begin
       For PX:=0 To 3 Do Begin Put(PixelPtr,Colors[(Flg And 1) Xor 1]); Inc(PixelPtr); Flg:=Flg Shr 1; End;
       Dec(PixelPtr,RowDec);
      End;
     End;
    End;
   End Else If V3AEight And (B>=$90) Then Begin
    Flg:=(B Shl 8) Or A;
    If Sp+8>Sz Then Exit;
    For K:=0 To 7 Do Colors[K]:=Pk^[Sp+K];
    Inc(Sp,8);
    For PY:=0 To 3 Do Begin
     For PX:=0 To 3 Do Begin
      Put(PixelPtr,Colors[((PY And 2) Shl 1)+(PX And 2)+((Flg And 1) Xor 1)]);
      Inc(PixelPtr); Flg:=Flg Shr 1;
     End;
     Dec(PixelPtr,RowDec);
    End;
   End Else Begin
    If V3AEight Then Colors[0]:=A Else Colors[0]:=(B Shl 8) Or A;
    For PY:=0 To 3 Do Begin
     For PX:=0 To 3 Do Begin Put(PixelPtr,Colors[0]); Inc(PixelPtr); End;
     Dec(PixelPtr,RowDec);
    End;
   End;
   Inc(BlockPtr,4); Dec(Total);
  End;
 End;
 V3AMv1:=True;
End;

{ ---- Cinepak ---- }
Procedure V3ACvBook(Var Book: TV3CvBook; Id,Size: LongInt; D: PV3Bytes; Off: LongInt);
Var Cur,EOD,N,I,K,R,G,B,U,V,PP: LongInt; Flg,M2: LongWord;
Begin
 Cur:=Off; EOD:=Off+Size;
 If (Id And 4)<>0 Then N:=4 Else N:=6;
 Flg:=0; M2:=0;
 For I:=0 To 255 Do Begin
  If (Id And 1)<>0 Then Begin
   M2:=M2 Shr 1;
   If M2=0 Then Begin
    If Cur+4>EOD Then Break;
    Flg:=(LongWord(D^[Cur]) Shl 24) Or (LongWord(D^[Cur+1]) Shl 16) Or (LongWord(D^[Cur+2]) Shl 8) Or D^[Cur+3];
    Inc(Cur,4); M2:=$80000000;
   End;
  End;
  If ((Id And 1)=0) Or ((Flg And M2)<>0) Then Begin
   If Cur+N>EOD Then Break;
   PP:=0;
   For K:=0 To 3 Do Begin
    R:=D^[Cur]; Inc(Cur);
    Book[I,PP]:=R; Book[I,PP+1]:=R; Book[I,PP+2]:=R; Inc(PP,3);
   End;
   If N=6 Then Begin
    U:=ShortInt(D^[Cur]); V:=ShortInt(D^[Cur+1]); Inc(Cur,2);
    PP:=0;
    For K:=0 To 3 Do Begin
     R:=Book[I,PP]+V*2; G:=Book[I,PP]-(U Div 2)-V; B:=Book[I,PP+2]+U*2;
     Book[I,PP]:=V3Clip(R); Book[I,PP+1]:=V3Clip(G); Book[I,PP+2]:=V3Clip(B);
     Inc(PP,3);
    End;
   End;
  End;
 End;
End;

Function V3ACvVec(Var Strip: TV3CvStrip; Pal: Boolean; X1,Y1,X2,Y2,Id,Size: LongInt;
                  D: PV3Bytes; Off: LongInt): Boolean;
Var EOD,Y,X,Cur,I0,I1,I2,I3,Q,Bp,Stride,Z,C0,C1,C2,C3: LongInt; Flag,Mask: LongWord;
    Pic: PV3Bytes;
 Procedure Cp(Dst,Src: LongInt; Var Book: TV3CvBook; Idx,Cnt: LongInt);
 Var K: LongInt;
 Begin
  For K:=0 To Cnt-1 Do Pic^[Dst+K]:=Book[Idx,Src+K];
 End;
Begin
 V3ACvVec:=False;
 Cur:=Off; EOD:=Off+Size; Flag:=0; Mask:=0; Pic:=V3ACv;
 If Pal Then Bp:=1 Else Bp:=3;
 Stride:=V3ACvPW*Bp;
 Y:=Y1;
 While Y<Y2 Do Begin
  I0:=Y*Stride+X1*Bp; I1:=I0; I2:=I0; I3:=I0;
  If V3ACvPH-Y>1 Then Begin
   I1:=I0+Stride;
   If V3ACvPH-Y>2 Then Begin I2:=I1+Stride; If V3ACvPH-Y>3 Then I3:=I2+Stride; End;
  End;
  X:=X1;
  While X<X2 Do Begin
   If (Id And 1)<>0 Then Begin
    Mask:=Mask Shr 1;
    If Mask=0 Then Begin
     If Cur+4>EOD Then Exit;
     Flag:=(LongWord(D^[Cur]) Shl 24) Or (LongWord(D^[Cur+1]) Shl 16) Or (LongWord(D^[Cur+2]) Shl 8) Or D^[Cur+3];
     Inc(Cur,4); Mask:=$80000000;
    End;
   End;
   If ((Id And 1)=0) Or ((Flag And Mask)<>0) Then Begin
    If (Id And 2)=0 Then Begin
     Mask:=Mask Shr 1;
     If Mask=0 Then Begin
      If Cur+4>EOD Then Exit;
      Flag:=(LongWord(D^[Cur]) Shl 24) Or (LongWord(D^[Cur+1]) Shl 16) Or (LongWord(D^[Cur+2]) Shl 8) Or D^[Cur+3];
      Inc(Cur,4); Mask:=$80000000;
     End;
    End;
    If ((Id And 2)<>0) Or ((Not Flag And Mask)<>0) Then Begin
     If Cur>=EOD Then Exit;
     Q:=D^[Cur]; Inc(Cur);
     If Pal Then Begin
      Pic^[I3]:=Strip.V1[Q,6]; Pic^[I3+1]:=Strip.V1[Q,6]; Pic^[I2]:=Strip.V1[Q,6]; Pic^[I2+1]:=Strip.V1[Q,6];
      Pic^[I3+2]:=Strip.V1[Q,9]; Pic^[I3+3]:=Strip.V1[Q,9]; Pic^[I2+2]:=Strip.V1[Q,9]; Pic^[I2+3]:=Strip.V1[Q,9];
      Pic^[I1]:=Strip.V1[Q,0]; Pic^[I1+1]:=Strip.V1[Q,0]; Pic^[I0]:=Strip.V1[Q,0]; Pic^[I0+1]:=Strip.V1[Q,0];
      Pic^[I1+2]:=Strip.V1[Q,3]; Pic^[I1+3]:=Strip.V1[Q,3]; Pic^[I0+2]:=Strip.V1[Q,3]; Pic^[I0+3]:=Strip.V1[Q,3];
     End Else Begin
      Cp(I3,6,Strip.V1,Q,3); Cp(I3+3,6,Strip.V1,Q,3); Cp(I2,6,Strip.V1,Q,3); Cp(I2+3,6,Strip.V1,Q,3);
      Cp(I3+6,9,Strip.V1,Q,3); Cp(I3+9,9,Strip.V1,Q,3); Cp(I2+6,9,Strip.V1,Q,3); Cp(I2+9,9,Strip.V1,Q,3);
      Cp(I1,0,Strip.V1,Q,3); Cp(I1+3,0,Strip.V1,Q,3); Cp(I0,0,Strip.V1,Q,3); Cp(I0+3,0,Strip.V1,Q,3);
      Cp(I1+6,3,Strip.V1,Q,3); Cp(I1+9,3,Strip.V1,Q,3); Cp(I0+6,3,Strip.V1,Q,3); Cp(I0+9,3,Strip.V1,Q,3);
     End;
    End Else If (Flag And Mask)<>0 Then Begin
     If Cur+4>EOD Then Exit;
     C0:=D^[Cur]; C1:=D^[Cur+1]; C2:=D^[Cur+2]; C3:=D^[Cur+3]; Inc(Cur,4);
     If Pal Then Begin
      Pic^[I3]:=Strip.V4[C2,6]; Pic^[I3+1]:=Strip.V4[C2,9]; Pic^[I3+2]:=Strip.V4[C3,6]; Pic^[I3+3]:=Strip.V4[C3,9];
      Pic^[I2]:=Strip.V4[C2,0]; Pic^[I2+1]:=Strip.V4[C2,3]; Pic^[I2+2]:=Strip.V4[C3,0]; Pic^[I2+3]:=Strip.V4[C3,3];
      Pic^[I1]:=Strip.V4[C0,6]; Pic^[I1+1]:=Strip.V4[C0,9]; Pic^[I1+2]:=Strip.V4[C1,6]; Pic^[I1+3]:=Strip.V4[C1,9];
      Pic^[I0]:=Strip.V4[C0,0]; Pic^[I0+1]:=Strip.V4[C0,3]; Pic^[I0+2]:=Strip.V4[C1,0]; Pic^[I0+3]:=Strip.V4[C1,3];
     End Else Begin
      Cp(I3,6,Strip.V4,C2,6); Cp(I3+6,6,Strip.V4,C3,6);
      Cp(I2,0,Strip.V4,C2,6); Cp(I2+6,0,Strip.V4,C3,6);
      Cp(I1,6,Strip.V4,C0,6); Cp(I1+6,6,Strip.V4,C1,6);
      Cp(I0,0,Strip.V4,C0,6); Cp(I0+6,0,Strip.V4,C1,6);
     End;
    End;
   End;
   Z:=4*Bp; Inc(I0,Z); Inc(I1,Z); Inc(I2,Z); Inc(I3,Z);
   Inc(X,4);
  End;
  Inc(Y,4);
 End;
 V3ACvVec:=True;
End;

Function V3ACinepak(Pk: PV3Bytes; Size: LongInt): Boolean;
Var NumStrips,Enc,I,Cur,EOD,StripSize,FrameFlags,Y0,Id,CSize,SX1,SY1,SX2,SY2,Pos2,SEnd,Y: LongInt;
    Done,Res,Pal: Boolean;
 Function RB16(At: LongInt): LongInt;
 Begin RB16:=Pk^[At]*256+Pk^[At+1]; End;
 Function RB24(At: LongInt): LongInt;
 Begin RB24:=Pk^[At]*65536+Pk^[At+1]*256+Pk^[At+2]; End;
Begin
 V3ACinepak:=False;
 Pal:=V3ABpp<>24;
 If Size<10 Then Exit;
 NumStrips:=RB16(8);
 If NumStrips=0 Then Exit;
 Enc:=RB24(1);
 If Size<Enc*5 Div 100 Then Exit;
 If V3ASega=-1 Then Begin
  If Enc=0 Then Exit;
  If (Enc<>Size) And ((Size Mod Enc)<>0) Then Begin
   If (Size>=16) And (Pk^[10]=$FE) And (Pk^[11]=0) And (Pk^[12]=0) And (Pk^[13]=6) And
      (Pk^[14]=0) And (Pk^[15]=0) Then V3ASega:=6 Else V3ASega:=2;
  End Else V3ASega:=0;
 End;
 If Size<10+V3ASega+NumStrips*12 Then Exit;
 StripSize:=RB24(10+V3ASega+1);
 If (StripSize<12) Or (StripSize>Enc) Then Exit;
 EOD:=Size; FrameFlags:=Pk^[0]; Cur:=10+V3ASega; Y0:=0;
 If NumStrips>32 Then NumStrips:=32;
 For I:=0 To NumStrips-1 Do Begin
  If Cur+12>EOD Then Break;
  SY1:=RB16(Cur+4);
  If SY1=0 Then Begin SY1:=Y0; SY2:=SY1+RB16(Cur+8); End Else SY2:=RB16(Cur+8);
  SX1:=RB16(Cur+6); SX2:=RB16(Cur+10);
  StripSize:=RB24(Cur+1)-12;
  If StripSize<0 Then Break;
  Inc(Cur,12);
  If Cur+StripSize>EOD Then StripSize:=EOD-Cur;
  If (I>0) And ((FrameFlags And 1)=0) Then Begin
   V3ACvS[I].V4:=V3ACvS[I-1].V4; V3ACvS[I].V1:=V3ACvS[I-1].V1;
  End;
  If (SX2>V3ACvPW) Or (SY2>V3ACvPH) Or (SX1>=SX2) Or (SY1>=SY2) Then Break;
  Pos2:=Cur; SEnd:=Cur+StripSize; Done:=False; Res:=False;
  While (Pos2+4<=SEnd) And Not Done Do Begin
   Id:=Pk^[Pos2]; CSize:=RB24(Pos2+1)-4;
   If CSize<0 Then Break;
   Inc(Pos2,4);
   If Pos2+CSize>SEnd Then CSize:=SEnd-Pos2;
   Case Id Of
    $20,$21,$24,$25: V3ACvBook(V3ACvS[I].V4,Id,CSize,Pk,Pos2);
    $22,$23,$26,$27: V3ACvBook(V3ACvS[I].V1,Id,CSize,Pk,Pos2);
    $30,$31,$32: Begin
      Res:=V3ACvVec(V3ACvS[I],Pal,SX1,SY1,SX2,SY2,Id,CSize,Pk,Pos2); Done:=True;
     End;
   End;
   If Not Done Then Inc(Pos2,CSize);
  End;
  If Not Res Then Exit;
  Inc(Cur,StripSize);
  Y0:=SY2;
 End;
 { copie recadree vers l'image courante }
 For Y:=0 To V3AH-1 Do
  If Pal Then Move(V3ACv^[Y*V3ACvPW],V3AIdx^[Y*V3AW],V3AW)
  Else Move(V3ACv^[Y*V3ACvPW*3],V3ACur^[Y*V3AW*3],V3AW*3);
 V3ACinepak:=True;
End;

{ ---- mise en place et boucle principale ---- }
Procedure V3AFreeAll;
Begin
 V3Release(V3ACur); V3Release(V3AIdx); V3Release(V3ABuf); V3Release(V3ACv);
 V3ABufCap:=0; V3AEmit:=Nil;
 V3JFreeAll;
End;

Function V3ASetup: Boolean;
Var N,F100: LongInt; I: LongInt;
Begin
 V3ASetup:=False;
 If Not V3AHasVid Or Not V3AGotFmt Then Exit;
 V3AKind:=V3AClass;
 If V3AKind=0 Then Exit;
 If (V3AW<1) Or (V3AH<1) Or (V3AW>16384) Or (V3AH>16384) Or (V3AW*V3AH>40000000) Then Exit;
 V3AEight:=V3ABpp=8;
 If V3AKind>=3 Then V3AFlip:=False; { seuls BI_RGB et RLE sont de bas en haut }
 V3ACur:=V3Alloc(V3AW*V3AH*3);
 If V3ACur=Nil Then Exit;
 FillChar(V3ACur^,V3AW*V3AH*3,0);
 V3AIdx:=V3Alloc(V3AW*V3AH);
 If V3AIdx=Nil Then Begin V3AFreeAll; Exit; End;
 FillChar(V3AIdx^,V3AW*V3AH,0);
 If V3AKind=6 Then Begin
  V3ACv:=V3Alloc(V3AW*V3AH+2*((V3AW+1) Div 2)*V3AH+16);
  If V3ACv=Nil Then Begin V3AFreeAll; Exit; End;
 End;
 If V3AKind=5 Then Begin
  V3ACvPW:=(V3AW+3) And Not 3; V3ACvPH:=(V3AH+3) And Not 3;
  N:=V3ACvPW*V3ACvPH*3;
  V3ACv:=V3Alloc(N);
  If V3ACv=Nil Then Begin V3AFreeAll; Exit; End;
  FillChar(V3ACv^,N,0); FillChar(V3ACvS,SizeOf(V3ACvS),0); V3ASega:=-1;
  If V3ABpp=40 Then For I:=0 To 255 Do Begin
   V3APal[I,0]:=I; V3APal[I,1]:=I; V3APal[I,2]:=I;
  End;
 End;
 V3AEmit:=V3ACur; V3AEW:=V3AW; V3AEH:=V3AH; V3AHasPrev:=False;
 If (V3ARate>0) And (V3AScale>0) Then F100:=Round(Int64(V3ARate)*100/V3AScale)
 Else If V3AMicro>0 Then F100:=Round(100000000.0/V3AMicro)
 Else F100:=2500;
 If F100<1 Then F100:=1;
 If F100>100000 Then F100:=100000;
 ConfSetFps(F100);
 V3ASetup:=True;
End;

{ Decode une trame ; retourne True si V3AEmit/V3AEW/V3AEH ont ete mis a jour. }
Function V3ADecodeFrame(Sz: LongInt): Boolean;
Var Ok: Boolean; RowB,X,Y,CW,CH: LongInt; PU,PV: PV3Bytes;
Begin
 Ok:=False;
 Case V3AKind Of
  1: Begin Ok:=V3ARaw(V3ABuf,Sz); If Ok Then V3AEmit:=V3ACur; End;
  2: Begin
      RowB:=((V3AW*V3ABpp+31) Div 32)*4;
      If Sz=RowB*V3AH Then Begin
       { image non compressee dans un flux RLE : de bas en haut, remplace l'image }
       For Y:=0 To V3AH-1 Do
        For X:=0 To V3AW-1 Do
         If V3ABpp=8 Then V3AIdx^[Y*V3AW+X]:=V3ABuf^[Y*RowB+X]
         Else If Odd(X) Then V3AIdx^[Y*V3AW+X]:=V3ABuf^[Y*RowB+(X Shr 1)] And 15
         Else V3AIdx^[Y*V3AW+X]:=V3ABuf^[Y*RowB+(X Shr 1)] Shr 4;
       Ok:=True;
      End Else Ok:=V3ARle(V3ABuf,Sz,V3AComp=2);
      If Ok Then Begin V3AIdxToRgb; V3AEmit:=V3ACur; End;
     End;
  3: Begin
      Ok:=V3JDecode(V3ABuf,Sz);
      If Ok Then Ok:=V3JToRgb(V3AEW,V3AEH);
      If Ok Then V3AEmit:=V3JOut;
      If Ok Then Begin V3AEW:=V3JW; V3AEH:=V3JH; End;
     End;
  4: Begin
      Ok:=V3AMv1(V3ABuf,Sz);
      If Ok Then Begin
       If V3AEight Then V3AIdxToRgb;
       V3AEmit:=V3ACur;
      End;
     End;
  6: Begin
      CW:=(V3AW+1) Div 2; CH:=(V3AH+1) Div 2;
      If V3AYuv<=3 Then Begin
       If Sz>=CW*4*V3AH Then Begin
        Ok:=True; PU:=@V3ACv^[V3AW*V3AH]; PV:=@V3ACv^[V3AW*V3AH+CW*V3AH];
        For Y:=0 To V3AH-1 Do For X:=0 To CW-1 Do Begin
         RowB:=Y*CW*4+X*4;
         Case V3AYuv Of
          1: Begin V3ACv^[Y*V3AW+X*2]:=V3ABuf^[RowB]; If X*2+1<V3AW Then V3ACv^[Y*V3AW+X*2+1]:=V3ABuf^[RowB+2];
              PU^[Y*CW+X]:=V3ABuf^[RowB+1]; PV^[Y*CW+X]:=V3ABuf^[RowB+3]; End;
          2: Begin V3ACv^[Y*V3AW+X*2]:=V3ABuf^[RowB+1]; If X*2+1<V3AW Then V3ACv^[Y*V3AW+X*2+1]:=V3ABuf^[RowB+3];
              PU^[Y*CW+X]:=V3ABuf^[RowB]; PV^[Y*CW+X]:=V3ABuf^[RowB+2]; End;
          3: Begin V3ACv^[Y*V3AW+X*2]:=V3ABuf^[RowB]; If X*2+1<V3AW Then V3ACv^[Y*V3AW+X*2+1]:=V3ABuf^[RowB+2];
              PV^[Y*CW+X]:=V3ABuf^[RowB+1]; PU^[Y*CW+X]:=V3ABuf^[RowB+3]; End;
         End;
        End;
        V3YuvRgb(V3ACv,PU,PV,V3AW,CW,CW,V3AW,V3AH,CW,V3AH,False,V3ACur);
       End;
      End Else If Sz>=V3AW*V3AH+2*CW*CH Then Begin
       Ok:=True;
       If V3AYuv=4 Then Begin PU:=@V3ABuf^[V3AW*V3AH]; PV:=@V3ABuf^[V3AW*V3AH+CW*CH]; End
       Else Begin PV:=@V3ABuf^[V3AW*V3AH]; PU:=@V3ABuf^[V3AW*V3AH+CW*CH]; End;
       V3YuvRgb(V3ABuf,PU,PV,V3AW,CW,CW,V3AW,V3AH,CW,CH,False,V3ACur);
      End;
      If Ok Then V3AEmit:=V3ACur;
     End;
  5: Begin
      Ok:=V3ACinepak(V3ABuf,Sz);
      If Ok Then Begin
       If V3ABpp<>24 Then V3AIdxToRgb;
       V3AEmit:=V3ACur;
      End;
     End;
 End;
 If Ok And (V3AKind<>3) Then Begin V3AEW:=V3AW; V3AEH:=V3AH; End;
 V3ADecodeFrame:=Ok;
End;

Function V3AWalk(Var R: TV3Rd; Decode: Boolean): Boolean;
Var Strt,NextP,Sz: Int64; Tmp: Array[0..1599] Of Byte; I,K,L,T,Cnt,Num: LongInt;
    Gray,Seen: Boolean;
Begin
 V3AWalk:=False; Gray:=False; Seen:=False;
 V3AHasVid:=False; V3AGotFmt:=False; V3AReady:=False; V3ACurStr:=-1; V3AVid:=-1;
 V3AW:=0; V3AH:=0; V3ABpp:=0; V3AComp:=0; V3AFcc:=''; V3AScale:=0; V3ARate:=0; V3ALen:=0;
 V3AMicro:=0; V3AFlip:=False; V3AFrames:=0;
 FillChar(V3APal,SizeOf(V3APal),0);
 V3AMask[0]:=$7C00; V3AMask[1]:=$3E0; V3AMask[2]:=$1F;
 V3RdSeek(R,0);
 If V3RdRead(R,@Tmp,12)<12 Then Exit;
 If (Tmp[0]<>82) Or (Tmp[1]<>73) Or (Tmp[2]<>70) Or (Tmp[3]<>70) Or
    (Tmp[8]<>65) Or (Tmp[9]<>86) Or (Tmp[10]<>73) Then Exit;
 While Not R.Eof And Not V3Stop Do Begin
  If V3RdRead(R,@V3AHd,8)<8 Then Break;
  Sz:=V3AU32(V3AHd,4); Strt:=V3RdTell(R);
  If V3AIs('RIFF') Or V3AIs('LIST') Then Begin
   If Sz<4 Then Break;
   If V3RdRead(R,@Tmp,4)<4 Then Break;
   If (Tmp[0]=109) And (Tmp[1]=111) And (Tmp[2]=118) And (Tmp[3]=105) Then Begin { movi }
    If Not Seen Then Begin
     Seen:=True;
     If Not Decode Then Begin V3AWalk:=V3AHasVid And V3AGotFmt; Exit; End;
     If Not V3ASetup Then Exit;
     V3AReady:=True;
    End;
   End;
   Continue;
  End;
  NextP:=Strt+Sz+(Sz And 1);
  If Strt+Sz>R.Size Then Begin
   { chunk tronque : on n'essaie pas de le decoder }
   Break;
  End;
  If V3AIs('avih') Then Begin
   If (Sz>=4) And (V3RdRead(R,@Tmp,4)=4) Then V3AMicro:=V3A32(Tmp,0);
  End Else If V3AIs('strh') Then Begin
   Inc(V3ACurStr);
   L:=Sz; If L>56 Then L:=56;
   FillChar(Tmp,64,0);
   If (L>=36) And (V3RdRead(R,@Tmp,L)=L) Then Begin
    If (Tmp[0]=118) And (Tmp[1]=105) And (Tmp[2]=100) And (Tmp[3]=115) And Not V3AHasVid Then Begin
     V3AHasVid:=True; V3AVid:=V3ACurStr;
     V3AFcc:=V3AFourCC(Tmp,4);
     V3AScale:=V3A32(Tmp,20); V3ARate:=V3A32(Tmp,24); V3ALen:=V3A32(Tmp,32);
    End;
   End;
  End Else If V3AIs('strf') Then Begin
   If V3AHasVid And (V3ACurStr=V3AVid) And Not V3AGotFmt And (Sz>=40) Then Begin
    L:=Sz; If L>1600 Then L:=1600;
    If V3RdRead(R,@Tmp,L)=L Then Begin
     K:=V3A32(Tmp,0);
     V3AW:=V3A32(Tmp,4); V3AH:=V3A32(Tmp,8); V3ABpp:=Tmp[14]+Tmp[15]*256;
     V3AComp:=V3A32(Tmp,16);
     If V3AH<0 Then Begin V3AH:=-V3AH; V3AFlip:=False; End Else V3AFlip:=True;
     V3AFcc:='';
     If (V3AComp<0) Or (V3AComp>3) Then Begin
      V3AFcc:=V3AUp(V3AFourCC(Tmp,16));
      If (V3AFcc='DIB ') Or (V3AFcc='RGB ') Or (V3AFcc='RAW ') Then Begin V3AComp:=0; V3AFcc:=''; End;
      If ((V3AFcc='Y800') Or (V3AFcc='Y8  ') Or (V3AFcc='GREY')) And (V3ABpp=8) Then Begin
       V3AComp:=0; V3AFcc:=''; Gray:=True; V3AFlip:=False;
      End;
     End;
     Cnt:=V3A32(Tmp,32);
     If (Cnt<=0) Or (Cnt>256) Then Cnt:=256;
     If V3ABpp<=8 Then Begin
      If Cnt>(LongInt(1) Shl V3ABpp) Then Cnt:=LongInt(1) Shl V3ABpp;
      If (K<40) Or (K>L) Then K:=40;
      For I:=0 To Cnt-1 Do If K+I*4+3<L Then Begin
       V3APal[I,0]:=Tmp[K+I*4+2]; V3APal[I,1]:=Tmp[K+I*4+1]; V3APal[I,2]:=Tmp[K+I*4];
      End;
      { palette absente : niveaux de gris }
      If (V3ABpp<=8) And ((L<=40) Or Gray) Then
       For I:=0 To (LongInt(1) Shl V3ABpp)-1 Do Begin
        T:=I*255 Div ((LongInt(1) Shl V3ABpp)-1);
        V3APal[I,0]:=T; V3APal[I,1]:=T; V3APal[I,2]:=T;
       End;
     End;
     If (V3AComp=3) And (L>=52) Then Begin
      V3AMask[0]:=V3A32(Tmp,40); V3AMask[1]:=V3A32(Tmp,44); V3AMask[2]:=V3A32(Tmp,48);
     End;
     If V3ABpp=15 Then V3ABpp:=16;
     V3AGotFmt:=True;
    End;
   End;
  End Else If Decode And V3AReady And (V3AHd[0]>=48) And (V3AHd[0]<=57) And
              (V3AHd[1]>=48) And (V3AHd[1]<=57) Then Begin
   Num:=(V3AHd[0]-48)*10+(V3AHd[1]-48);
   If Num=V3AVid Then Begin
    If (V3AHd[2]=100) And ((V3AHd[3]=99) Or (V3AHd[3]=98)) Then Begin { dc / db }
     If Sz>67108864 Then Break;
     L:=Sz;
     If L+16>V3ABufCap Then Begin
      V3Release(V3ABuf); V3ABuf:=V3Alloc(L+16); V3ABufCap:=L+16;
      If V3ABuf=Nil Then Begin V3ABufCap:=0; Break; End;
     End;
     If L>0 Then If V3RdRead(R,V3ABuf,L)<L Then Break;
     FillChar(V3ABuf^[L],16,0);
     If (L>0) And V3ADecodeFrame(L) Then Begin
      V3AHasPrev:=True;
      If Not V3Put(V3AEW,V3AEH,V3AEmit) Then Break;
      Inc(V3AFrames);
     End Else Begin
      { image absente ou illisible : on repete la precedente ; si c'est la
        premiere image du flux, le fichier n'est pas exploitable }
      If (L>0) And Not V3AHasPrev And (V3AKind=3) Then Break;
      If (L>0) And Not V3AHasPrev Then Break;
      If V3AHasPrev Then Begin
       If Not V3Put(V3AEW,V3AEH,V3AEmit) Then Break;
       Inc(V3AFrames);
      End;
     End;
     If (V3AFrames And 15)=0 Then ConfProgress(V3AFrames,V3ALen);
    End Else If (V3AHd[2]=112) And (V3AHd[3]=99) And (Sz>=4) Then Begin { pc : changement de palette }
     L:=Sz; If L>1030 Then L:=1030;
     If V3RdRead(R,@Tmp,L)=L Then Begin
      K:=Tmp[0]; Cnt:=Tmp[1]; If Cnt=0 Then Cnt:=256;
      For I:=0 To Cnt-1 Do If (K+I<256) And (4+I*4+3<=L) Then Begin
       V3APal[K+I,0]:=Tmp[4+I*4]; V3APal[K+I,1]:=Tmp[5+I*4]; V3APal[K+I,2]:=Tmp[6+I*4];
      End;
     End;
    End;
   End;
  End;
  V3RdSeek(R,NextP);
 End;
 V3AWalk:=V3AReady And (V3Cnt>0);
End;

Function V3AviCodec(Const FN: String): String;
Var R: PV3Rd;
Begin
 V3AviCodec:=''; V3Stop:=False;
 New(R);
 If V3RdOpen(R^,FN) Then Begin
  If V3AWalk(R^,False) Then Begin
   If V3AComp=0 Then V3AviCodec:='DIB '
   Else If V3AComp=1 Then V3AviCodec:='RLE8'
   Else If V3AComp=2 Then V3AviCodec:='RLE4'
   Else If V3AComp=3 Then V3AviCodec:='BITF'
   Else V3AviCodec:=V3AFcc;
  End;
  V3RdClose(R^);
 End;
 Dispose(R);
End;

Function V3AviConform(Const FN: String): Boolean;
Var R: PV3Rd; Ok: Boolean;
Begin
 V3AviConform:=False; V3Cnt:=0; V3Stop:=False;
 New(R);
 If V3RdOpen(R^,FN) Then Begin
  Ok:=V3AWalk(R^,True);
  V3AFreeAll;
  V3RdClose(R^);
  V3AviConform:=Ok And (V3Cnt>0);
 End;
 Dispose(R);
End;

{ ======================================================================= GIF }
Var
 V3GW,V3GH,V3GTick: LongInt;
 V3GCanvas,V3GBackup: PV3Bytes;
 V3GPalG: Array[0..255,0..2] Of Byte;
 V3GPre: Array[0..4095] Of Word;
 V3GSuf: Array[0..4095] Of Byte;
 V3GStk: Array[0..4096] Of Byte;
 V3GImages,V3GGcd,V3GTotal: LongInt;

Function V3GRow(Y,H: LongInt): LongInt;
Var N1,N2,N3: LongInt;
Begin
 N1:=(H+7) Div 8; N2:=(H+3) Div 8; N3:=(H+1) Div 4;
 If Y<N1 Then Begin V3GRow:=Y*8; Exit; End;
 Dec(Y,N1);
 If Y<N2 Then Begin V3GRow:=4+Y*8; Exit; End;
 Dec(Y,N2);
 If Y<N3 Then Begin V3GRow:=2+Y*4; Exit; End;
 Dec(Y,N3);
 V3GRow:=1+Y*2;
End;

{ Saute les sous-blocs jusqu'au terminateur. }
Procedure V3GSkipBlocks(Var R: TV3Rd);
Var N: LongInt;
Begin
 Repeat
  N:=V3RdByte(R);
  If N<=0 Then Break;
  V3RdSeek(R,V3RdTell(R)+N);
 Until R.Eof;
End;

{ Decode les donnees LZW d'une image dans Idx (W*H indices). False si illisible. }
Function V3GLzw(Var R: TV3Rd; Idx: PV3Bytes; W,H: LongInt; Inter: Boolean): Boolean;
Var Mcs,Clear,Eoi,Avail,CSize,Mask,Old,First,Code,InCode,Sp,Blk,Bits,NBits,B,X,Y,Pos,Total: LongInt;
    Done,Ended: Boolean;
 Procedure Out(Pix: LongInt);
 Var Row: LongInt;
 Begin
  If Pos>=Total Then Exit;
  If Inter Then Row:=V3GRow(Y,H) Else Row:=Y;
  Idx^[Row*W+X]:=Pix;
  Inc(X); If X>=W Then Begin X:=0; Inc(Y); End;
  Inc(Pos);
 End;
Begin
 V3GLzw:=False;
 Mcs:=V3RdByte(R);
 If (Mcs<1) Or (Mcs>8) Then Exit;
 V3GLzw:=True;
 Clear:=LongInt(1) Shl Mcs; Eoi:=Clear+1; Avail:=Clear+2; CSize:=Mcs+1;
 Mask:=(LongInt(1) Shl CSize)-1; Old:=-1; First:=0; Bits:=0; NBits:=0; Blk:=0;
 X:=0; Y:=0; Pos:=0; Total:=W*H; Done:=False; Ended:=False;
 FillChar(Idx^,Total,0);
 While Not Done And (Pos<Total) Do Begin
  While NBits<CSize Do Begin
   If Blk=0 Then Begin
    Blk:=V3RdByte(R);
    If Blk<=0 Then Begin Blk:=0; Ended:=True; Break; End;
   End;
   B:=V3RdByte(R);
   If B<0 Then Begin Ended:=True; Break; End;
   Dec(Blk);
   Bits:=Bits Or (B Shl NBits); Inc(NBits,8);
  End;
  If Ended And (NBits<CSize) Then Break;
  Code:=Bits And Mask; Bits:=Bits Shr CSize; Dec(NBits,CSize);
  If Code=Clear Then Begin
   CSize:=Mcs+1; Mask:=(LongInt(1) Shl CSize)-1; Avail:=Clear+2; Old:=-1;
  End Else If Code=Eoi Then Done:=True
  Else If Old<0 Then Begin
   If Code>=Clear Then Break;
   Out(Code); Old:=Code; First:=Code;
  End Else Begin
   InCode:=Code; Sp:=0;
   If Code>=Avail Then Begin
    If Code>Avail Then Break;
    V3GStk[Sp]:=First; Inc(Sp); Code:=Old;
   End;
   While (Code>=Clear) And (Sp<4096) Do Begin
    V3GStk[Sp]:=V3GSuf[Code]; Inc(Sp); Code:=V3GPre[Code];
   End;
   If Code>=Clear Then Break;
   V3GStk[Sp]:=Code; Inc(Sp); First:=Code;
   If Avail<4096 Then Begin
    V3GPre[Avail]:=Old; V3GSuf[Avail]:=First; Inc(Avail);
    If ((Avail And Mask)=0) And (Avail<4096) Then Begin Inc(CSize); Mask:=(LongInt(1) Shl CSize)-1; End;
   End;
   Old:=InCode;
   While Sp>0 Do Begin Dec(Sp); Out(V3GStk[Sp]); End;
  End;
 End;
 { fin des sous-blocs }
 If Not Ended Then Begin
  If Blk>0 Then V3RdSeek(R,V3RdTell(R)+Blk);
  V3GSkipBlocks(R);
 End;
 If R.Eof And (Pos=0) Then V3GLzw:=False;
End;

Function V3GDelay(D: LongInt): LongInt;
Begin
 If D<=1 Then D:=10;
 V3GDelay:=D;
End;

Function V3GWalk(Var R: TV3Rd; Decode: Boolean): Boolean;
Var Tmp: Array[0..1023] Of Byte; B,L,T,Fl,I,Disp,Delay,TrIdx,IW,IH,Left,Top,X,Y,CX,CY,Px,Rep,Cum,Emitted,N,Sz: LongInt;
    HasTr,Inter,HasG,Okimg: Boolean; Idx: PV3Bytes; Pal: Array[0..255,0..2] Of Byte;
    PD,PL,PT,PW,PH: LongInt; Sig: Array[0..5] Of Byte;
Begin
 V3GWalk:=False; V3GImages:=0; V3GGcd:=0;
 V3GCanvas:=Nil; V3GBackup:=Nil; Idx:=Nil;
 V3RdSeek(R,0);
 If V3RdRead(R,@Sig,6)<6 Then Exit;
 If (Sig[0]<>71) Or (Sig[1]<>73) Or (Sig[2]<>70) Or (Sig[3]<>56) Or
    ((Sig[4]<>55) And (Sig[4]<>57)) Or (Sig[5]<>97) Then Exit;
 V3GW:=V3Rd16(R); V3GH:=V3Rd16(R); Fl:=V3RdByte(R); V3RdByte(R); V3RdByte(R);
 If R.Eof Then Exit;
 FillChar(V3GPalG,SizeOf(V3GPalG),0);
 HasG:=(Fl And $80)<>0;
 If HasG Then Begin
  N:=LongInt(1) Shl ((Fl And 7)+1);
  If V3RdRead(R,@Tmp,N*3)<N*3 Then Exit;
  For I:=0 To N-1 Do Begin V3GPalG[I,0]:=Tmp[I*3]; V3GPalG[I,1]:=Tmp[I*3+1]; V3GPalG[I,2]:=Tmp[I*3+2]; End;
 End;
 Disp:=0; Delay:=10; HasTr:=False; TrIdx:=-1; Cum:=0; Emitted:=0;
 PD:=0; PL:=0; PT:=0; PW:=0; PH:=0;
 While Not V3Stop Do Begin
  B:=V3RdByte(R);
  If B<0 Then Break;
  If B=$3B Then Break;
  If B=$21 Then Begin
   L:=V3RdByte(R);
   If L=$F9 Then Begin
    Sz:=V3RdByte(R);
    If (Sz<4) Or (Sz>16) Then Break;
    If V3RdRead(R,@Tmp,Sz)<Sz Then Break;
    Disp:=(Tmp[0] Shr 2) And 7; HasTr:=(Tmp[0] And 1)<>0;
    Delay:=Tmp[1]+Tmp[2]*256; TrIdx:=Tmp[3];
    V3GSkipBlocks(R);
   End Else V3GSkipBlocks(R);
  End Else If B=$2C Then Begin
   Left:=V3Rd16(R); Top:=V3Rd16(R); IW:=V3Rd16(R); IH:=V3Rd16(R); Fl:=V3RdByte(R);
   If R.Eof Then Break;
   Inter:=(Fl And $40)<>0;
   If (IW<1) Or (IH<1) Or (IW*IH>40000000) Then Break;
   If (Fl And $80)<>0 Then Begin
    N:=LongInt(1) Shl ((Fl And 7)+1);
    If V3RdRead(R,@Tmp,N*3)<N*3 Then Break;
    Move(V3GPalG,Pal,SizeOf(Pal));
    For I:=0 To N-1 Do Begin Pal[I,0]:=Tmp[I*3]; Pal[I,1]:=Tmp[I*3+1]; Pal[I,2]:=Tmp[I*3+2]; End;
   End Else Move(V3GPalG,Pal,SizeOf(Pal));
   If Not Decode Then Begin
    { passe 1 : sauter les donnees }
    If V3RdByte(R)<0 Then Break;
    V3GSkipBlocks(R);
    If R.Eof Then Break;
    Inc(V3GImages);
    If V3GGcd=0 Then V3GGcd:=V3GDelay(Delay) Else V3GGcd:=V3Gcd(V3GGcd,V3GDelay(Delay));
   End Else Begin
    If V3GCanvas=Nil Then Begin
     If (V3GW<1) Or (V3GH<1) Then Begin V3GW:=Left+IW; V3GH:=Top+IH; End;
     If (V3GW>16384) Or (V3GH>16384) Or (V3GW*V3GH>40000000) Then Break;
     V3GCanvas:=V3Alloc(V3GW*V3GH*3);
     V3GBackup:=V3Alloc(V3GW*V3GH*3);
     If (V3GCanvas=Nil) Or (V3GBackup=Nil) Then Break;
     { fond initial : noir (les pixels transparents restent noirs) }
     FillChar(V3GCanvas^,V3GW*V3GH*3,0);
    End;
    Idx:=V3Alloc(IW*IH);
    If Idx=Nil Then Break;
    Okimg:=V3GLzw(R,Idx,IW,IH,Inter);
    If Not Okimg Then Begin FreeMem(Idx); Idx:=Nil; Break; End;
    { elimination de l'image precedente }
    If PD=2 Then Begin
     For Y:=PT To PT+PH-1 Do If (Y>=0) And (Y<V3GH) Then
      For X:=PL To PL+PW-1 Do If (X>=0) And (X<V3GW) Then Begin
       CX:=(Y*V3GW+X)*3; V3GCanvas^[CX]:=0; V3GCanvas^[CX+1]:=0; V3GCanvas^[CX+2]:=0;
      End;
    End Else If PD=3 Then Move(V3GBackup^,V3GCanvas^,V3GW*V3GH*3);
    If Disp=3 Then Move(V3GCanvas^,V3GBackup^,V3GW*V3GH*3);
    For Y:=0 To IH-1 Do Begin
     CY:=Top+Y;
     If (CY>=0) And (CY<V3GH) Then
      For X:=0 To IW-1 Do Begin
       CX:=Left+X;
       If (CX>=0) And (CX<V3GW) Then Begin
        Px:=Idx^[Y*IW+X];
        If Not (HasTr And (Px=TrIdx)) Then Begin
         T:=(CY*V3GW+CX)*3;
         V3GCanvas^[T]:=Pal[Px,0]; V3GCanvas^[T+1]:=Pal[Px,1]; V3GCanvas^[T+2]:=Pal[Px,2];
        End;
       End;
      End;
    End;
    FreeMem(Idx); Idx:=Nil;
    Inc(V3GImages);
    If (V3GImages And 15)=0 Then ConfProgress(V3GImages,V3GTotal);
    Inc(Cum,V3GDelay(Delay));
    Rep:=(Cum+V3GTick Div 2) Div V3GTick-Emitted;
    If (Emitted=0) And (Rep<1) Then Rep:=1;
    For I:=1 To Rep Do If Not V3Stop Then V3Put(V3GW,V3GH,V3GCanvas);
    If Rep>0 Then Inc(Emitted,Rep);
    PD:=Disp; PL:=Left; PT:=Top; PW:=IW; PH:=IH;
   End;
   { les extensions de controle ne valent que pour l'image suivante }
   Disp:=0; Delay:=10; HasTr:=False; TrIdx:=-1;
  End Else Break;
 End;
 If Idx<>Nil Then FreeMem(Idx);
 V3Release(V3GCanvas); V3Release(V3GBackup);
 If Decode Then V3GWalk:=V3Cnt>0 Else V3GWalk:=V3GImages>0;
End;

Function V3GifConform(Const FN: String): Boolean;
Var R: PV3Rd; Ok: Boolean;
Begin
 V3GifConform:=False; V3Cnt:=0; V3Stop:=False;
 New(R);
 If V3RdOpen(R^,FN) Then Begin
  Ok:=V3GWalk(R^,False);
  If Ok Then Begin
   V3GTick:=V3GGcd; If V3GTick<2 Then V3GTick:=2;
   V3GTotal:=V3GImages;
   ConfSetFps(10000 Div V3GTick);
   V3GWalk(R^,True);
  End;
  V3RdClose(R^);
  V3GifConform:=V3Cnt>0;
 End;
 Dispose(R);
End;

{ ======================================================================= Y4M }
Function V3Y4mConform(Const FN: String): Boolean;
Var R: PV3Rd; Hdr: PV3Bytes; HL,I,J,W,H,Num,Den,CW,CH,Bps,FSz,YSz,CSz,Got,Depth,Sh,V,Fr,Alpha,Mono: LongInt;
    Tok: String; C: Char; Full: Boolean; Fb,P8,Out: PV3Bytes; Tmp: Array[0..255] Of Byte;
    CS: String; K: LongInt;
 Function Num32(Const S: String; Var P: LongInt): LongInt;
 Var N: LongInt;
 Begin
  N:=0;
  While (P<=Length(S)) And (S[P]>='0') And (S[P]<='9') Do Begin
   If N<100000000 Then N:=N*10+Ord(S[P])-48; Inc(P);
  End;
  Num32:=N;
 End;
Begin
 V3Y4mConform:=False; V3Cnt:=0; V3Stop:=False;
 W:=0; H:=0; Num:=25; Den:=1; CS:='420'; Full:=False;
 New(R);
 If Not V3RdOpen(R^,FN) Then Begin Dispose(R); Exit; End;
 Hdr:=V3Alloc(4096); Fb:=Nil; P8:=Nil; Out:=Nil;
 If Hdr=Nil Then Begin V3RdClose(R^); Dispose(R); Exit; End;
 HL:=0;
 Repeat
  I:=V3RdByte(R^);
  If I<0 Then Break;
  If I=10 Then Break;
  If HL<4000 Then Begin Hdr^[HL]:=I; Inc(HL); End;
 Until False;
 If (I<>10) Or (HL<10) Then Begin FreeMem(Hdr); V3RdClose(R^); Dispose(R); Exit; End;
 Tok:='';
 For I:=0 To HL Do Begin
  If (I<HL) And (Hdr^[I]<>32) Then Begin
   If Length(Tok)<250 Then Tok:=Tok+Chr(Hdr^[I]);
  End Else Begin
   If Tok='' Then Continue;
   If I<=HL Then Begin
    C:=Tok[1]; J:=2;
    Case C Of
     'W': W:=Num32(Tok,J);
     'H': H:=Num32(Tok,J);
     'F': Begin Num:=Num32(Tok,J); Inc(J); Den:=Num32(Tok,J); End;
     'C': CS:=Copy(Tok,2,250);
     'X': If Copy(Tok,1,16)='XCOLORRANGE=FULL' Then Full:=True;
    End;
   End;
   Tok:='';
  End;
 End;
 FreeMem(Hdr);
 { espace colorimetrique }
 Mono:=0; Alpha:=0; Depth:=8; CW:=0; CH:=0;
 If Copy(CS,1,4)='mono' Then Begin
  Mono:=1; CW:=0; CH:=0; J:=5;
  If Length(CS)>=5 Then Begin Depth:=Num32(CS,J); End;
 End Else Begin
  If Copy(CS,1,3)='420' Then Begin CW:=(W+1) Div 2; CH:=(H+1) Div 2; End
  Else If Copy(CS,1,3)='422' Then Begin CW:=(W+1) Div 2; CH:=H; End
  Else If Copy(CS,1,3)='444' Then Begin CW:=W; CH:=H; End
  Else If Copy(CS,1,3)='411' Then Begin CW:=(W+3) Div 4; CH:=H; End
  Else If Copy(CS,1,3)='440' Then Begin CW:=W; CH:=(H+1) Div 2; End
  Else Mono:=-1;
  If Pos('alpha',CS)>0 Then Alpha:=1;
  K:=Pos('p',CS);
  If (K>0) And (K<Length(CS)) And (CS[K+1]>='0') And (CS[K+1]<='9') Then Begin
   J:=K+1; Depth:=Num32(CS,J);
  End;
 End;
 If (Mono<0) Or (W<1) Or (H<1) Or (W>16384) Or (H>16384) Or (Depth<8) Or (Depth>16) Or
    (Num<=0) Or (Den<=0) Then Begin V3RdClose(R^); Dispose(R); Exit; End;
 If Depth>8 Then Bps:=2 Else Bps:=1;
 YSz:=W*H*Bps; CSz:=CW*CH*Bps;
 If Mono=1 Then FSz:=YSz Else FSz:=YSz+2*CSz+Alpha*YSz;
 If FSz>300000000 Then Begin V3RdClose(R^); Dispose(R); Exit; End;
 Fb:=V3Alloc(FSz); Out:=V3Alloc(W*H*3);
 If Bps=2 Then P8:=V3Alloc(W*H+2*CW*CH+16);
 If (Fb=Nil) Or (Out=Nil) Or ((Bps=2) And (P8=Nil)) Then Begin
  V3Release(Fb); V3Release(Out); V3Release(P8); V3RdClose(R^); Dispose(R); Exit;
 End;
 ConfSetFps(Round(Num*100.0/Den));
 Fr:=0;
 While Not V3Stop Do Begin
  { en-tete FRAME }
  HL:=0;
  Repeat
   I:=V3RdByte(R^);
   If I<0 Then Break;
   If I=10 Then Break;
   If HL<250 Then Begin Tmp[HL]:=I; Inc(HL); End;
  Until False;
  If (I<>10) Or (HL<5) Or (Tmp[0]<>70) Or (Tmp[1]<>82) Or (Tmp[2]<>65) Or (Tmp[3]<>77) Or (Tmp[4]<>69) Then Break;
  Got:=V3RdRead(R^,Fb,FSz);
  If Got<FSz Then Break;
  If Bps=2 Then Begin
   Sh:=Depth-8;
   For I:=0 To W*H+2*CW*CH-1 Do Begin
    If Mono=1 Then If I>=W*H Then Break;
    V:=Fb^[I*2] Or (Fb^[I*2+1] Shl 8);
    V:=V Shr Sh; If V>255 Then V:=255;
    P8^[I]:=V;
   End;
   If Mono=1 Then V3YuvRgb(P8,Nil,Nil,W,0,0,W,H,0,0,Full,Out)
   Else V3YuvRgb(P8,@P8^[W*H],@P8^[W*H+CW*CH],W,CW,CW,W,H,CW,CH,Full,Out);
  End Else Begin
   If Mono=1 Then V3YuvRgb(Fb,Nil,Nil,W,0,0,W,H,0,0,Full,Out)
   Else V3YuvRgb(Fb,@Fb^[W*H],@Fb^[W*H+CW*CH],W,CW,CW,W,H,CW,CH,Full,Out);
  End;
  Inc(Fr);
  If Not V3Put(W,H,Out) Then Break;
  If (Fr And 15)=0 Then ConfProgress(Fr,0);
 End;
 V3Release(Fb); V3Release(Out); V3Release(P8);
 V3RdClose(R^); Dispose(R);
 V3Y4mConform:=V3Cnt>0;
End;

{ ================================================================== FLI/FLC }
Var
 V3FW,V3FH: LongInt;
 V3FIdx,V3FRgb,V3FBuf: PV3Bytes;
 V3FPal: Array[0..255,0..2] Of Byte;

Function V3FChunks(D: PV3Bytes; Len: LongInt; NCh: LongInt): Boolean;
Var P,Typ,E,I,J,K,Cnt,Skip,NP,X,Y,Lines,B,Run,Op,Wd: LongInt; Sz: Int64; S6: Boolean;
 Function G8(At: LongInt): LongInt;
 Begin If (At>=0) And (At<Len) Then G8:=D^[At] Else G8:=0; End;
 Function G16(At: LongInt): LongInt;
 Begin G16:=G8(At)+G8(At+1)*256; End;
Begin
 V3FChunks:=True;
 P:=0;
 While (NCh>0) And (P+6<=Len) Do Begin
  Dec(NCh);
  Sz:=Int64(G8(P))+Int64(G8(P+1))*256+Int64(G8(P+2))*65536+Int64(G8(P+3))*16777216;
  Typ:=G16(P+4);
  If (Sz<6) Or (P+Sz>Len) Then Begin
   If (Sz<6) Then Begin V3FChunks:=False; Exit; End;
   Sz:=Len-P;
  End;
  E:=P+LongInt(Sz); K:=P+6;
  Case Typ Of
   4,11: Begin
     S6:=Typ=11;
     NP:=G16(K); Inc(K,2); X:=0;
     For I:=1 To NP Do Begin
      If K+2>E Then Break;
      Inc(X,G8(K)); Cnt:=G8(K+1); Inc(K,2);
      If Cnt=0 Then Cnt:=256;
      For J:=0 To Cnt-1 Do Begin
       If K+3>E Then Break;
       If X<256 Then
        For B:=0 To 2 Do Begin
         Wd:=G8(K+B);
         If S6 Then Wd:=((Wd And 63) Shl 2) Or ((Wd And 63) Shr 4);
         V3FPal[X,B]:=Wd;
        End;
       Inc(X); Inc(K,3);
      End;
     End;
    End;
   13: FillChar(V3FIdx^,V3FW*V3FH,0);
   16: Begin
     If E-K>=V3FW*V3FH Then Move(D^[K],V3FIdx^,V3FW*V3FH)
     Else Begin V3FChunks:=False; Exit; End;
    End;
   15: Begin
     For Y:=0 To V3FH-1 Do Begin
      If K>=E Then Break;
      Inc(K); { nombre de paquets : ignore }
      X:=0;
      While (X<V3FW) And (K<E) Do Begin
       Run:=ShortInt(D^[K]); Inc(K);
       If Run>=0 Then Begin
        If K>=E Then Break;
        B:=D^[K]; Inc(K);
        If Run=0 Then Run:=0;
        While (Run>0) And (X<V3FW) Do Begin V3FIdx^[Y*V3FW+X]:=B; Inc(X); Dec(Run); End;
       End Else Begin
        Run:=-Run;
        While (Run>0) And (X<V3FW) And (K<E) Do Begin V3FIdx^[Y*V3FW+X]:=D^[K]; Inc(X); Inc(K); Dec(Run); End;
       End;
      End;
     End;
    End;
   12: Begin
     Y:=G16(K); Lines:=G16(K+2); Inc(K,4);
     While (Lines>0) And (K<E) Do Begin
      Dec(Lines);
      NP:=D^[K]; Inc(K); X:=0;
      For I:=1 To NP Do Begin
       If K+2>E Then Break;
       Inc(X,D^[K]); Run:=ShortInt(D^[K+1]); Inc(K,2);
       If Run>=0 Then Begin
        For J:=1 To Run Do Begin
         If K>=E Then Break;
         If (X<V3FW) And (Y>=0) And (Y<V3FH) Then V3FIdx^[Y*V3FW+X]:=D^[K];
         Inc(X); Inc(K);
        End;
       End Else Begin
        Run:=-Run;
        If K>=E Then Break;
        B:=D^[K]; Inc(K);
        For J:=1 To Run Do Begin
         If (X<V3FW) And (Y>=0) And (Y<V3FH) Then V3FIdx^[Y*V3FW+X]:=B;
         Inc(X);
        End;
       End;
      End;
      Inc(Y);
     End;
    End;
   7: Begin
     Lines:=G16(K); Inc(K,2); Y:=0;
     While (Lines>0) And (K+2<=E) Do Begin
      Op:=G16(K); Inc(K,2);
      If (Op And $C000)=$C000 Then Inc(Y,65536-Op)
      Else If (Op And $C000)=$4000 Then Begin V3FChunks:=False; Exit; End
      Else If (Op And $C000)=$8000 Then Begin
       If (Y>=0) And (Y<V3FH) Then V3FIdx^[Y*V3FW+V3FW-1]:=Op And 255;
      End Else Begin
       Dec(Lines);
       X:=0;
       For I:=1 To Op Do Begin
        If K+2>E Then Break;
        Inc(X,D^[K]); Run:=ShortInt(D^[K+1]); Inc(K,2);
        If Run>=0 Then Begin
         For J:=1 To Run Do Begin
          If K+2>E Then Break;
          If (X+1<V3FW) And (Y>=0) And (Y<V3FH) Then Begin
           V3FIdx^[Y*V3FW+X]:=D^[K]; V3FIdx^[Y*V3FW+X+1]:=D^[K+1];
          End Else If (X<V3FW) And (Y>=0) And (Y<V3FH) Then V3FIdx^[Y*V3FW+X]:=D^[K];
          Inc(X,2); Inc(K,2);
         End;
        End Else Begin
         Run:=-Run;
         If K+2>E Then Break;
         B:=D^[K]; Skip:=D^[K+1]; Inc(K,2);
         For J:=1 To Run Do Begin
          If (X+1<V3FW) And (Y>=0) And (Y<V3FH) Then Begin
           V3FIdx^[Y*V3FW+X]:=B; V3FIdx^[Y*V3FW+X+1]:=Skip;
          End Else If (X<V3FW) And (Y>=0) And (Y<V3FH) Then V3FIdx^[Y*V3FW+X]:=B;
          Inc(X,2);
         End;
        End;
       End;
       Inc(Y);
      End;
     End;
    End;
  End;
  P:=E;
 End;
End;

Function V3FliConform(Const FN: String): Boolean;
Var R: PV3Rd; Hd: Array[0..127] Of Byte; Magic,Frames,Speed,Depth,I,FM,NCh,N,X,Y,Fr: LongInt; Fsz: Int64;
    Ms: Int64; Ok: Boolean; FliOld: Boolean; FrameStart: Int64; Fh: Array[0..15] Of Byte;
Begin
 V3FliConform:=False; V3Cnt:=0; V3Stop:=False;
 V3FIdx:=Nil; V3FRgb:=Nil; V3FBuf:=Nil;
 New(R);
 If Not V3RdOpen(R^,FN) Then Begin Dispose(R); Exit; End;
 If V3RdRead(R^,@Hd,128)<128 Then Begin V3RdClose(R^); Dispose(R); Exit; End;
 Magic:=Hd[4]+Hd[5]*256; Frames:=Hd[6]+Hd[7]*256;
 V3FW:=Hd[8]+Hd[9]*256; V3FH:=Hd[10]+Hd[11]*256; Depth:=Hd[12]+Hd[13]*256;
 FliOld:=Magic=$AF11;
 If ((Magic<>$AF11) And (Magic<>$AF12)) Or (V3FW<1) Or (V3FH<1) Or (V3FW>4096) Or (V3FH>4096) Or
    ((Depth<>8) And (Depth<>0)) Then Begin V3RdClose(R^); Dispose(R); Exit; End;
 If FliOld Then Begin
  Speed:=Hd[16]+Hd[17]*256;
  If Speed=0 Then Speed:=5;
  ConfSetFps(Round(7000.0/Speed));
 End Else Begin
  Ms:=Int64(Hd[16])+Hd[17]*256+Int64(Hd[18])*65536+Int64(Hd[19])*16777216;
  If (Ms<=0) Or (Ms>10000) Then Ms:=70;
  ConfSetFps(Round(100000.0/Ms));
 End;
 If Frames<1 Then Frames:=65535;
 V3FIdx:=V3Alloc(V3FW*V3FH); V3FRgb:=V3Alloc(V3FW*V3FH*3);
 If (V3FIdx=Nil) Or (V3FRgb=Nil) Then Begin
  V3Release(V3FIdx); V3Release(V3FRgb); V3RdClose(R^); Dispose(R); Exit;
 End;
 FillChar(V3FIdx^,V3FW*V3FH,0); FillChar(V3FPal,SizeOf(V3FPal),0);
 V3RdSeek(R^,128);
 Fr:=0;
 While (Fr<Frames) And Not V3Stop Do Begin
  FrameStart:=V3RdTell(R^);
  If V3RdRead(R^,@Fh,16)<16 Then Break;
  Fsz:=Int64(Fh[0])+Int64(Fh[1])*256+Int64(Fh[2])*65536+Int64(Fh[3])*16777216;
  FM:=Fh[4]+Fh[5]*256; NCh:=Fh[6]+Fh[7]*256;
  If Fsz<16 Then Break;
  If FM=$F100 Then Begin V3RdSeek(R^,FrameStart+Fsz); Continue; End;
  If Fsz>200000000 Then Break;
  If FM<>$F1FA Then Break;
  N:=Fsz-16;
  If N>0 Then Begin
   If N>67108864 Then Break;
   V3FBuf:=V3Alloc(N+16);
   If V3FBuf=Nil Then Break;
   If V3RdRead(R^,V3FBuf,N)<N Then Begin V3Release(V3FBuf); Break; End;
   Ok:=V3FChunks(V3FBuf,N,NCh);
   V3Release(V3FBuf);
   If Not Ok Then Begin If V3Cnt=0 Then Break; End;
  End;
  { conversion palette }
  X:=0;
  For Y:=0 To V3FW*V3FH-1 Do Begin
   I:=V3FIdx^[Y];
   V3FRgb^[X]:=V3FPal[I,0]; V3FRgb^[X+1]:=V3FPal[I,1]; V3FRgb^[X+2]:=V3FPal[I,2]; Inc(X,3);
  End;
  Inc(Fr);
  If Not V3Put(V3FW,V3FH,V3FRgb) Then Break;
  If (Fr And 15)=0 Then ConfProgress(Fr,Frames);
 End;
 V3Release(V3FIdx); V3Release(V3FRgb);
 V3RdClose(R^); Dispose(R);
 V3FliConform:=V3Cnt>0;
End;

{ ======================================================================= WAV }
Function V3WavConform(Const FN: String): Boolean;
Var R: PV3Rd; Hd: Array[0..39] Of Byte; Id: Array[0..7] Of Byte; Sz,Strt,DLen: Int64;
    Tag,Ch,Rate,Bits,Bps,FrSz,I,J,K,N,Blk,Cnt,Peak,PL,PR,V: LongInt;
    Buf: PV3Bytes; Got: LongInt; WinEnd,Fdone,Total: Int64; WinIdx: Int64;
    Sg: Single; Db: Double; Ok,Fmt,Dat: Boolean;
 Function PeakOf(P: LongInt): LongInt;  { crete 0..255 de l'echantillon a l'offset P }
 Var S: LongInt; X: Int64; F: Double;
 Begin
  PeakOf:=0;
  Case Tag Of
   1: Case Bits Of
       8: Begin S:=Buf^[P]-128; If S<0 Then S:=-S; S:=S*2; If S>255 Then S:=255; PeakOf:=S; End;
       16: Begin S:=SmallInt(Buf^[P] Or (Buf^[P+1] Shl 8)); If S<0 Then S:=-S; S:=S Shr 7; If S>255 Then S:=255; PeakOf:=S; End;
       24: Begin { 24 bits signes : on garde les 16 bits de poids fort }
            S:=SmallInt(Buf^[P+1] Or (Buf^[P+2] Shl 8));
            If S<0 Then S:=-S; S:=S Shr 7; If S>255 Then S:=255; PeakOf:=S; End;
       32: Begin X:=LongInt(LongWord(Buf^[P]) Or (LongWord(Buf^[P+1]) Shl 8) Or (LongWord(Buf^[P+2]) Shl 16) Or (LongWord(Buf^[P+3]) Shl 24));
            If X<0 Then X:=-X; X:=X Shr 23; If X>255 Then X:=255; PeakOf:=X; End;
      End;
   3: Begin
       { NaN / infini : exposant tout a 1, ecarte avant toute operation flottante }
       If ((Bits=32) And ((Buf^[P+3] And $7F)=$7F) And ((Buf^[P+2] And $80)<>0)) Or
          ((Bits=64) And ((Buf^[P+7] And $7F)=$7F) And ((Buf^[P+6] And $F0)=$F0)) Then PeakOf:=0
       Else Begin
        If Bits=32 Then Begin Move(Buf^[P],Sg,4); F:=Sg; End
        Else Begin Move(Buf^[P],Db,8); F:=Db; End;
        If F<0 Then F:=-F;
        If F>1.0 Then F:=1.0;
        PeakOf:=Round(F*255);
       End;
      End;
   6: Begin { A-law }
       S:=Buf^[P] Xor $55;
       K:=(S And $70) Shr 4; V:=(S And 15) Shl 4+8;
       If K>0 Then V:=(V+$100) Shl (K-1);
       V:=V Shr 7; If V>255 Then V:=255; PeakOf:=V;
      End;
   7: Begin { mu-law }
       S:=Not Buf^[P] And 255;
       K:=(S Shr 4) And 7; V:=(((S And 15) Shl 3)+$84) Shl K-$84;
       V:=V Shr 7; If V>255 Then V:=255; PeakOf:=V;
      End;
  End;
 End;
Begin
 V3WavConform:=False; V3Cnt:=0; V3Stop:=False;
 New(R);
 If Not V3RdOpen(R^,FN) Then Begin Dispose(R); Exit; End;
 Buf:=Nil; Fmt:=False; Dat:=False; Tag:=0; Ch:=0; Rate:=0; Bits:=0; DLen:=0;
 If (V3RdRead(R^,@Hd,12)<12) Or (Hd[0]<>82) Or (Hd[1]<>73) Or (Hd[2]<>70) Or (Hd[3]<>70) Or
    (Hd[8]<>87) Or (Hd[9]<>65) Or (Hd[10]<>86) Or (Hd[11]<>69) Then Begin V3RdClose(R^); Dispose(R); Exit; End;
 While Not R^.Eof Do Begin
  If V3RdRead(R^,@Id,8)<8 Then Break;
  Sz:=Int64(Id[4])+Int64(Id[5])*256+Int64(Id[6])*65536+Int64(Id[7])*16777216;
  Strt:=V3RdTell(R^);
  If (Id[0]=102) And (Id[1]=109) And (Id[2]=116) And (Id[3]=32) Then Begin
   N:=Sz; If N>40 Then N:=40;
   If N<16 Then Break;
   FillChar(Hd,SizeOf(Hd),0);
   If V3RdRead(R^,@Hd,N)<N Then Break;
   Tag:=Hd[0]+Hd[1]*256; Ch:=Hd[2]+Hd[3]*256;
   Rate:=Hd[4]+Hd[5]*256+Hd[6]*65536+Hd[7]*16777216; Bits:=Hd[14]+Hd[15]*256;
   If (Tag=$FFFE) And (N>=26) Then Tag:=Hd[24]+Hd[25]*256;
   Fmt:=True;
  End Else If (Id[0]=100) And (Id[1]=97) And (Id[2]=116) And (Id[3]=97) Then Begin
   Dat:=True;
   DLen:=Sz;
   If (Sz=0) Or (Strt+Sz>R^.Size) Then DLen:=R^.Size-Strt;
   Break;
  End;
  V3RdSeek(R^,Strt+Sz+(Sz And 1));
 End;
 If Not (Fmt And Dat) Or (Ch<1) Or (Ch>64) Or (Rate<50) Or (Rate>768000) Or (DLen<=0) Then Begin
  V3RdClose(R^); Dispose(R); Exit;
 End;
 Ok:=False;
 If (Tag=1) And ((Bits=8) Or (Bits=16) Or (Bits=24) Or (Bits=32)) Then Ok:=True
 Else If (Tag=3) And ((Bits=32) Or (Bits=64)) Then Ok:=True
 Else If ((Tag=6) Or (Tag=7)) And (Bits=8) Then Ok:=True;
 If Not Ok Then Begin V3RdClose(R^); Dispose(R); Exit; End;
 Bps:=Bits Div 8; FrSz:=Bps*Ch;
 Blk:=4096;
 Buf:=V3Alloc(Blk*FrSz+16);
 If Buf=Nil Then Begin V3RdClose(R^); Dispose(R); Exit; End;
 Total:=DLen Div FrSz;
 Fdone:=0; WinIdx:=0; WinEnd:=Int64(Rate) Div 50; If WinEnd<1 Then WinEnd:=1;
 PL:=0; PR:=0; Cnt:=0;
 While (Fdone<Total) And Not V3Stop Do Begin
  N:=Blk; If Total-Fdone<N Then N:=Total-Fdone;
  Got:=V3RdRead(R^,Buf,N*FrSz) Div FrSz;
  If Got<=0 Then Break;
  For I:=0 To Got-1 Do Begin
   For J:=0 To Ch-1 Do Begin
    Peak:=PeakOf(I*FrSz+J*Bps);
    If Odd(J) Then Begin If Peak>PR Then PR:=Peak; End
    Else If Peak>PL Then PL:=Peak;
   End;
   Inc(Cnt); Inc(Fdone);
   If Fdone>=WinEnd Then Begin
    If Ch=1 Then PR:=PL;
    If Not ConfAudioEmit(PL,PR) Then V3Stop:=True;
    Inc(V3Cnt);
    PL:=0; PR:=0; Cnt:=0; Inc(WinIdx);
    WinEnd:=((WinIdx+1)*Rate) Div 50;
    If V3Stop Then Break;
   End;
  End;
 End;
 If (Cnt>0) And Not V3Stop Then Begin
  If Ch=1 Then PR:=PL;
  If ConfAudioEmit(PL,PR) Then;
  Inc(V3Cnt);
 End;
 V3Release(Buf);
 V3RdClose(R^); Dispose(R);
 V3WavConform:=V3Cnt>0;
End;

{$POP}
{$ELSE}
Function V3AviConform(Const FN: String): Boolean;
Begin V3AviConform:=False; End;
Function V3AviCodec(Const FN: String): String;
Begin V3AviCodec:=''; End;
Function V3GifConform(Const FN: String): Boolean;
Begin V3GifConform:=False; End;
Function V3Y4mConform(Const FN: String): Boolean;
Begin V3Y4mConform:=False; End;
Function V3FliConform(Const FN: String): Boolean;
Begin V3FliConform:=False; End;
Function V3WavConform(Const FN: String): Boolean;
Begin V3WavConform:=False; End;
{$ENDIF}
{$IFDEF FPC}
{$PUSH}{$I-}{$R-}{$Q-}{$S-}
{ ======================================================================
  Decodeur video H.264 (MP4 / m4v / MOV / 3GP, FLV, AVI) en Pascal pur.
  Derive du decodeur H.264 natif du projet FFMPEG-0 (Sylvain Maltais,
  https://www.gladir.com/ffmpeg-0), lui-meme issu de tables de libavcodec
  (LGPL-2.1-or-later).  Progressif 4:2:0 8 bits, CAVLC et CABAC, I/P/B,
  transformee 8x8, deblocage.  Les images sont emises en ordre d'affichage
  (POC) par ConfEmit (RGB24).
  MPEG-4 partie 2 (DivX / Xvid / mp4v) dans AVI, MP4, MOV, 3GP : meme
  principe (decodeur de FFMPEG-0, libavcodec mpeg4videodec.c).
  Points d'entree :
    H4IsH264File(FN) / H4ConformFile(FN)    : H.264 (MP4, m4v, MOV, 3GP, FLV, AVI)
    H4IsMpeg4File(FN) / H4ConformMpeg4(FN)  : MPEG-4 partie 2 (AVI, MP4, MOV, 3GP)
  Necessite les routines ConfEmit / ConfSetFps / ConfProgress de l'hote.
  Limites : progressif 4:2:0 8 bits seulement (entrelace, 4:2:2/4:4:4, 10 bits,
  H.264 lossless : retourne False), MP4 fragmente = H.264 seulement,
  matrice BT.709 si VUI l'indique ou hauteur >= 720, sinon BT.601.
  ====================================================================== }
Type
 H4TBuf=Array[0..2147483000] Of Byte; H4PBuf=^H4TBuf;
 H4PI64=^H4TI64; H4TI64=Array[0..100000000] Of Int64;
 H4PLN=^H4TLN; H4TLN=Array[0..100000000] Of LongInt;
{ H264-BEGIN }
Const
 H4ChromaDcCoeffTokenLen: Array[0..19] Of Byte=(
  2,0,0,0,6,1,0,0,6,6,3,0,6,7,7,6,
  6,8,8,7
 );
 H4ChromaDcCoeffTokenBits: Array[0..19] Of Byte=(
  1,0,0,0,7,1,0,0,4,6,1,0,3,3,2,5,
  2,3,2,0
 );
 H4Chroma422DcCoeffTokenLen: Array[0..35] Of Byte=(
  1,0,0,0,7,2,0,0,7,7,3,0,9,7,7,5,
  9,9,7,6,10,10,9,7,11,11,10,7,12,12,11,10,
  13,12,12,11
 );
 H4Chroma422DcCoeffTokenBits: Array[0..35] Of Byte=(
  1,0,0,0,15,1,0,0,14,13,1,0,7,12,11,1,
  6,5,10,1,7,6,4,9,7,6,5,8,7,6,5,4,
  7,5,4,4
 );
 H4CoeffTokenLen: Array[0..271] Of Byte=(
  1,0,0,0,6,2,0,0,8,6,3,0,9,8,7,5,10,
  9,8,6,11,10,9,7,13,11,10,8,13,13,11,9,13,13,
  13,10,14,14,13,11,14,14,14,13,15,15,14,14,15,15,15,
  14,16,15,15,15,16,16,16,15,16,16,16,16,16,16,16,16,
  2,0,0,0,6,2,0,0,6,5,3,0,7,6,6,4,8,
  6,6,4,8,7,7,5,9,8,8,6,11,9,9,6,11,11,
  11,7,12,11,11,9,12,12,12,11,12,12,12,11,13,13,13,
  12,13,13,13,13,13,14,13,13,14,14,14,13,14,14,14,14,
  4,0,0,0,6,4,0,0,6,5,4,0,6,5,5,4,7,
  5,5,4,7,5,5,4,7,6,6,4,7,6,6,4,8,7,
  7,5,8,8,7,6,9,8,8,7,9,9,8,8,9,9,9,
  8,10,9,9,9,10,10,10,10,10,10,10,10,10,10,10,10,
  6,0,0,0,6,6,0,0,6,6,6,0,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
 );
 H4CoeffTokenBits: Array[0..271] Of Byte=(
  1,0,0,0,5,1,0,0,7,4,1,0,7,6,5,3,7,
  6,5,3,7,6,5,4,15,6,5,4,11,14,5,4,8,10,
  13,4,15,14,9,4,11,10,13,12,15,14,9,12,11,10,13,
  8,15,1,9,12,11,14,13,8,7,10,9,12,4,6,5,8,
  3,0,0,0,11,2,0,0,7,7,3,0,7,10,9,5,7,
  6,5,4,4,6,5,6,7,6,5,8,15,6,5,4,11,14,
  13,4,15,10,9,4,11,14,13,12,8,10,9,8,15,14,13,
  12,11,10,9,12,7,11,6,8,9,8,10,1,7,6,5,4,
  15,0,0,0,15,14,0,0,11,15,13,0,8,12,14,12,15,
  10,11,11,11,8,9,10,9,14,13,9,8,10,9,8,15,14,
  13,13,11,14,10,12,15,10,13,12,11,14,9,12,8,10,13,
  8,13,7,9,12,9,12,11,10,5,8,7,6,1,4,3,2,
  3,0,0,0,0,1,0,0,4,5,6,0,8,9,10,11,12,
  13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,
  30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,
  47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63
 );
 H4TotalZerosLen: Array[0..255] Of Byte=(
  1,3,3,4,4,5,5,6,6,7,7,8,8,9,9,9,
  3,3,3,3,3,4,4,4,4,5,5,6,6,6,6,0,
  4,3,3,3,4,4,3,3,4,5,5,6,5,6,0,0,
  5,3,4,4,3,3,3,4,3,4,5,5,5,0,0,0,
  4,4,4,3,3,3,3,3,4,5,4,5,0,0,0,0,
  6,5,3,3,3,3,3,3,4,3,6,0,0,0,0,0,
  6,5,3,3,3,2,3,4,3,6,0,0,0,0,0,0,
  6,4,5,3,2,2,3,3,6,0,0,0,0,0,0,0,
  6,6,4,2,2,3,2,5,0,0,0,0,0,0,0,0,
  5,5,3,2,2,2,4,0,0,0,0,0,0,0,0,0,
  4,4,3,3,1,3,0,0,0,0,0,0,0,0,0,0,
  4,4,2,1,3,0,0,0,0,0,0,0,0,0,0,0,
  3,3,1,2,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 );
 H4TotalZerosBits: Array[0..255] Of Byte=(
  1,3,2,3,2,3,2,3,2,3,2,3,2,3,2,1,
  7,6,5,4,3,5,4,3,2,3,2,3,2,1,0,0,
  5,7,6,5,4,3,4,3,2,3,2,1,1,0,0,0,
  3,7,5,4,6,5,4,3,3,2,2,1,0,0,0,0,
  5,4,3,7,6,5,4,3,2,1,1,0,0,0,0,0,
  1,1,7,6,5,4,3,2,1,1,0,0,0,0,0,0,
  1,1,5,4,3,3,2,1,1,0,0,0,0,0,0,0,
  1,1,1,3,3,2,2,1,0,0,0,0,0,0,0,0,
  1,0,1,3,2,1,1,1,0,0,0,0,0,0,0,0,
  1,0,1,3,2,1,1,0,0,0,0,0,0,0,0,0,
  0,1,1,2,1,3,0,0,0,0,0,0,0,0,0,0,
  0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,
  0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
  0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 );
 H4ChromaDcTotalZerosLen: Array[0..11] Of Byte=(
  1,2,3,3,
  1,2,2,0,
  1,1,0,0
 );
 H4ChromaDcTotalZerosBits: Array[0..11] Of Byte=(
  1,1,1,0,
  1,1,0,0,
  1,0,0,0
 );
 H4Chroma422DcTotalZerosLen: Array[0..55] Of Byte=(
  1,3,3,4,4,4,5,5,
  3,2,3,3,3,3,3,0,
  3,3,2,2,3,3,0,0,
  3,2,2,2,3,0,0,0,
  2,2,2,2,0,0,0,0,
  2,2,1,0,0,0,0,0,
  1,1,0,0,0,0,0,0
 );
 H4Chroma422DcTotalZerosBits: Array[0..55] Of Byte=(
  1,2,3,2,3,1,1,0,
  0,1,1,4,5,6,7,0,
  0,1,1,2,6,7,0,0,
  6,0,1,2,7,0,0,0,
  0,1,2,3,0,0,0,0,
  0,1,1,0,0,0,0,0,
  0,1,0,0,0,0,0,0
 );
 H4RunLen: Array[0..111] Of Byte=(
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,2,3,3,0,0,0,0,0,0,0,0,0,0,0,
  2,2,3,3,3,3,0,0,0,0,0,0,0,0,0,0,
  2,3,3,3,3,3,3,0,0,0,0,0,0,0,0,0,
  3,3,3,3,3,3,3,4,5,6,7,8,9,10,11,0
 );
 H4RunBits: Array[0..111] Of Byte=(
  1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,3,2,1,0,0,0,0,0,0,0,0,0,0,0,
  3,0,1,3,2,5,4,0,0,0,0,0,0,0,0,0,
  7,6,5,4,3,2,1,1,1,1,1,1,1,1,1,0
 );
 H4GolombToIntra4X4Cbp: Array[0..47] Of Byte=(
  47,31,15,0,23,27,29,30,7,11,13,14,39,43,45,46,
  16,3,5,10,12,19,21,26,28,35,37,42,44,1,2,4,
  8,17,18,20,24,6,9,22,25,32,33,34,36,40,38,41
 );
 H4GolombToInterCbp: Array[0..47] Of Byte=(
  0,16,1,2,4,8,32,3,5,10,12,15,47,7,11,13,
  14,6,9,31,35,37,42,44,33,34,36,40,39,43,45,46,
  17,18,20,24,19,21,26,28,23,27,29,30,22,25,38,41
 );
 H4CbpGrayIntra: Array[0..15] Of Byte=(
  15,0,7,11,13,14,3,5,10,12,1,2,4,8,6,9
 );
 H4CbpGrayInter: Array[0..15] Of Byte=(
  0,1,2,4,8,3,5,10,12,15,7,11,13,14,6,9
 );
 H4Alpha: Array[0..155] Of Byte=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,5,6,7,8,9,10,12,13,
  15,17,20,22,25,28,32,36,40,45,50,56,63,71,80,90,101,113,127,144,162,182,203,
   226,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
   255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
   255,255,255,255,255,255,255
 );
 H4Beta: Array[0..155] Of Byte=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,3,3,3,3,4,4,4,
  6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,
  18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,
  18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18
 );
 H4Tc0: Array[0..623] Of ShortInt=(
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,0,-1,0,0,0,-1,0,0,0,
  -1,0,0,1,-1,0,0,1,-1,0,0,1,
  -1,0,0,1,-1,0,1,1,-1,0,1,1,
  -1,1,1,1,-1,1,1,1,-1,1,1,1,
  -1,1,1,1,-1,1,1,2,-1,1,1,2,
  -1,1,1,2,-1,1,1,2,-1,1,2,3,
  -1,1,2,3,-1,2,2,3,-1,2,2,4,
  -1,2,3,4,-1,2,3,4,-1,3,3,5,
  -1,3,4,6,-1,3,4,6,-1,4,5,7,
  -1,4,5,8,-1,4,6,9,-1,5,7,10,
  -1,6,8,11,-1,6,8,13,-1,7,10,14,
  -1,8,11,16,-1,9,12,18,-1,10,13,20,
  -1,11,15,23,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25,
  -1,13,17,25,-1,13,17,25,-1,13,17,25
 );
 H4CabacInitI: Array[0..2047] Of ShortInt=(
  20,-15,2,54,3,74,20,-15,2,54,3,74,-28,127,-23,104,-6,53,-1,54,7,51,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,41,0,63,0,63,0,63,-9,83,4,86,0,97,-7,72,13,41,3,62,0,11,1,55,
  0,69,-17,127,-13,102,0,82,-7,74,-21,107,-27,127,-31,127,-24,127,-18,95,-27,
   127,-21,114,
  -30,127,-17,123,-12,115,-16,122,-11,115,-12,63,-2,68,-15,84,-13,104,-3,70,-8,
   93,-10,90,
  -30,127,-1,74,-6,97,-7,91,-20,127,-4,56,-5,82,-7,76,-22,125,-7,93,-11,87,-3,
   77,
  -5,71,-4,63,-4,68,-12,84,-7,62,-7,65,8,61,5,56,-2,66,1,64,0,61,-2,78,
  1,50,7,52,10,35,0,44,11,38,1,45,0,46,5,44,31,17,1,51,7,50,28,19,
  16,33,14,62,-13,108,-15,100,-13,101,-13,91,-12,94,-10,88,-16,84,-10,86,-7,83,-
   13,87,
  -19,94,1,70,0,72,-5,74,18,59,-8,102,-15,100,0,95,-4,75,2,72,-11,75,-3,71,
  15,46,-13,69,0,62,0,65,21,37,-15,72,9,57,16,54,0,62,12,72,24,0,15,9,
  8,25,13,18,15,9,13,19,10,37,12,18,6,29,20,33,15,30,4,45,1,58,0,62,
  7,61,12,38,11,45,15,39,11,42,13,44,16,45,12,41,10,49,30,34,18,42,10,55,
  17,51,17,46,0,89,26,-19,22,-17,26,-17,30,-25,28,-20,33,-23,37,-27,33,-23,40,-
   28,
  38,-17,33,-11,40,-15,41,-6,38,1,41,17,30,-6,27,3,26,22,37,-16,35,-4,38,-8,
  38,-3,37,3,38,5,42,0,35,16,39,22,14,48,27,37,21,60,12,68,2,97,-3,71,
  -6,42,-5,50,-3,54,-2,62,0,58,1,63,-2,72,-1,74,-9,91,-5,67,-5,27,-3,39,
  -2,44,0,46,-16,64,-8,68,-10,78,-6,77,-10,86,-12,92,-15,55,-10,60,-6,62,-4,65,
  -12,73,-8,76,-7,80,-9,88,-17,110,-11,97,-20,84,-11,79,-6,73,-4,74,-13,86,-13,
   96,
  -11,97,-19,117,-8,78,-5,33,-4,48,-2,53,-3,62,-13,71,-10,79,-12,86,-13,90,-14,
   97,
  0,0,-6,93,-6,84,-8,79,0,66,-1,71,0,62,-2,60,-2,59,-5,75,-3,62,-4,58,
  -9,66,-1,79,0,71,3,68,10,44,-7,62,15,36,14,40,16,27,12,29,1,44,20,36,
  18,32,5,42,1,48,10,62,17,46,9,64,-12,104,-11,97,-16,96,-7,88,-8,85,-7,85,
  -9,85,-13,88,4,66,-3,77,-3,76,-6,76,10,58,-1,76,-1,83,-7,99,-14,95,2,95,
  0,76,-5,74,0,70,-11,75,1,68,0,65,-14,73,3,62,4,62,-1,68,-13,75,11,55,
  5,64,12,70,15,6,6,19,7,16,12,14,18,13,13,11,13,15,15,16,12,23,13,23,
  15,20,14,26,14,44,17,40,17,47,24,17,21,21,25,22,31,27,22,29,19,35,14,50,
  10,57,7,63,-2,77,-4,82,-3,94,9,69,-12,109,36,-35,36,-34,32,-26,37,-30,44,-32,
  34,-18,34,-15,40,-15,33,-7,35,-5,33,0,38,2,33,13,23,35,13,58,29,-3,26,0,
  22,30,31,-7,35,-15,34,-3,34,3,36,-1,34,5,32,11,35,5,34,12,39,11,30,29,
  34,26,29,39,19,66,31,21,31,31,25,50,-17,120,-20,112,-18,114,-11,85,-15,92,-14,
   89,
  -26,71,-15,81,-14,80,0,68,-14,70,-24,56,-23,68,-24,50,-11,74,23,-13,26,-13,40,
   -15,
  49,-14,44,3,45,6,44,34,33,54,19,82,-3,75,-1,23,1,34,1,43,0,54,-2,55,
  0,61,1,64,0,68,-9,92,-14,106,-13,97,-15,90,-12,90,-18,88,-10,73,-9,79,-14,86,
  -10,73,-10,70,-10,69,-5,66,-9,64,-5,58,2,59,21,-10,24,-11,28,-8,28,-1,29,3,
  29,9,35,20,29,36,14,67,-17,123,-12,115,-16,122,-11,115,-12,63,-2,68,-15,84,-
   13,104,
  -3,70,-8,93,-10,90,-30,127,-17,123,-12,115,-16,122,-11,115,-12,63,-2,68,-15,
   84,-13,104,
  -3,70,-8,93,-10,90,-30,127,-7,93,-11,87,-3,77,-5,71,-4,63,-4,68,-12,84,-7,62,
  -7,65,8,61,5,56,-2,66,1,64,0,61,-2,78,1,50,7,52,10,35,0,44,11,38,
  1,45,0,46,5,44,31,17,1,51,7,50,28,19,16,33,14,62,-13,108,-15,100,-13,101,
  -13,91,-12,94,-10,88,-16,84,-10,86,-7,83,-13,87,-19,94,1,70,0,72,-5,74,18,59,
  -7,93,-11,87,-3,77,-5,71,-4,63,-4,68,-12,84,-7,62,-7,65,8,61,5,56,-2,66,
  1,64,0,61,-2,78,1,50,7,52,10,35,0,44,11,38,1,45,0,46,5,44,31,17,
  1,51,7,50,28,19,16,33,14,62,-13,108,-15,100,-13,101,-13,91,-12,94,-10,88,-16,
   84,
  -10,86,-7,83,-13,87,-19,94,1,70,0,72,-5,74,18,59,24,0,15,9,8,25,13,18,
  15,9,13,19,10,37,12,18,6,29,20,33,15,30,4,45,1,58,0,62,7,61,12,38,
  11,45,15,39,11,42,13,44,16,45,12,41,10,49,30,34,18,42,10,55,17,51,17,46,
  0,89,26,-19,22,-17,26,-17,30,-25,28,-20,33,-23,37,-27,33,-23,40,-28,38,-17,33,
   -11,
  40,-15,41,-6,38,1,41,17,24,0,15,9,8,25,13,18,15,9,13,19,10,37,12,18,
  6,29,20,33,15,30,4,45,1,58,0,62,7,61,12,38,11,45,15,39,11,42,13,44,
  16,45,12,41,10,49,30,34,18,42,10,55,17,51,17,46,0,89,26,-19,22,-17,26,-17,
  30,-25,28,-20,33,-23,37,-27,33,-23,40,-28,38,-17,33,-11,40,-15,41,-6,38,1,41,
   17,
  -17,120,-20,112,-18,114,-11,85,-15,92,-14,89,-26,71,-15,81,-14,80,0,68,-14,70,
   -24,56,
  -23,68,-24,50,-11,74,-14,106,-13,97,-15,90,-12,90,-18,88,-10,73,-9,79,-14,86,-
   10,73,
  -10,70,-10,69,-5,66,-9,64,-5,58,2,59,23,-13,26,-13,40,-15,49,-14,44,3,45,6,
  44,34,33,54,19,82,21,-10,24,-11,28,-8,28,-1,29,3,29,9,35,20,29,36,14,67,
  -3,75,-1,23,1,34,1,43,0,54,-2,55,0,61,1,64,0,68,-9,92,-17,120,-20,112,
  -18,114,-11,85,-15,92,-14,89,-26,71,-15,81,-14,80,0,68,-14,70,-24,56,-23,68,-
   24,50,
  -11,74,-14,106,-13,97,-15,90,-12,90,-18,88,-10,73,-9,79,-14,86,-10,73,-10,70,-
   10,69,
  -5,66,-9,64,-5,58,2,59,23,-13,26,-13,40,-15,49,-14,44,3,45,6,44,34,33,54,
  19,82,21,-10,24,-11,28,-8,28,-1,29,3,29,9,35,20,29,36,14,67,-3,75,-1,23,
  1,34,1,43,0,54,-2,55,0,61,1,64,0,68,-9,92,-6,93,-6,84,-8,79,0,66,
  -1,71,0,62,-2,60,-2,59,-5,75,-3,62,-4,58,-9,66,-1,79,0,71,3,68,10,44,
  -7,62,15,36,14,40,16,27,12,29,1,44,20,36,18,32,5,42,1,48,10,62,17,46,
  9,64,-12,104,-11,97,-16,96,-7,88,-8,85,-7,85,-9,85,-13,88,4,66,-3,77,-3,76,
  -6,76,10,58,-1,76,-1,83,-6,93,-6,84,-8,79,0,66,-1,71,0,62,-2,60,-2,59,
  -5,75,-3,62,-4,58,-9,66,-1,79,0,71,3,68,10,44,-7,62,15,36,14,40,16,27,
  12,29,1,44,20,36,18,32,5,42,1,48,10,62,17,46,9,64,-12,104,-11,97,-16,96,
  -7,88,-8,85,-7,85,-9,85,-13,88,4,66,-3,77,-3,76,-6,76,10,58,-1,76,-1,83,
  15,6,6,19,7,16,12,14,18,13,13,11,13,15,15,16,12,23,13,23,15,20,14,26,
  14,44,17,40,17,47,24,17,21,21,25,22,31,27,22,29,19,35,14,50,10,57,7,63,
  -2,77,-4,82,-3,94,9,69,-12,109,36,-35,36,-34,32,-26,37,-30,44,-32,34,-18,34,-
   15,
  40,-15,33,-7,35,-5,33,0,38,2,33,13,23,35,13,58,15,6,6,19,7,16,12,14,
  18,13,13,11,13,15,15,16,12,23,13,23,15,20,14,26,14,44,17,40,17,47,24,17,
  21,21,25,22,31,27,22,29,19,35,14,50,10,57,7,63,-2,77,-4,82,-3,94,9,69,
  -12,109,36,-35,36,-34,32,-26,37,-30,44,-32,34,-18,34,-15,40,-15,33,-7,35,-5,
   33,0,
  38,2,33,13,23,35,13,58,-3,71,-6,42,-5,50,-3,54,-2,62,0,58,1,63,-2,72,
  -1,74,-9,91,-5,67,-5,27,-3,39,-2,44,0,46,-16,64,-8,68,-10,78,-6,77,-10,86,
  -12,92,-15,55,-10,60,-6,62,-4,65,-12,73,-8,76,-7,80,-9,88,-17,110,-3,71,-6,42,
  -5,50,-3,54,-2,62,0,58,1,63,-2,72,-1,74,-9,91,-5,67,-5,27,-3,39,-2,44,
  0,46,-16,64,-8,68,-10,78,-6,77,-10,86,-12,92,-15,55,-10,60,-6,62,-4,65,-12,73,
  -8,76,-7,80,-9,88,-17,110,-3,70,-8,93,-10,90,-30,127,-3,70,-8,93,-10,90,-30,
   127,
  -3,70,-8,93,-10,90,-30,127
 );
 H4CabacInitPB: Array[0..6143] Of ShortInt=(
  20,-15,2,54,3,74,20,-15,2,54,3,74,-28,127,-23,104,-6,53,-1,54,7,51,23,33,
  23,2,21,0,1,9,0,49,-37,118,5,57,-13,78,-11,65,1,62,12,49,-4,73,17,50,
  18,64,9,43,29,0,26,67,16,90,9,104,-46,127,-20,104,1,67,-13,78,-11,65,1,62,
  -6,86,-17,95,-6,61,9,45,-3,69,-6,81,-11,96,6,55,7,67,-5,86,2,88,0,58,
  -3,76,-10,94,5,54,4,69,-3,81,0,88,-7,67,-5,74,-4,74,-5,80,-7,72,1,58,
  0,41,0,63,0,63,0,63,-9,83,4,86,0,97,-7,72,13,41,3,62,0,45,-4,78,
  -3,96,-27,126,-28,98,-25,101,-23,67,-28,82,-20,94,-16,83,-22,110,-21,91,-18,
   102,-13,93,
  -29,127,-7,92,-5,89,-7,96,-13,108,-3,46,-1,65,-1,57,-9,93,-3,74,-9,92,-8,87,
  -23,126,5,54,6,60,6,59,6,69,-1,48,0,68,-4,69,-8,88,-2,85,-6,78,-1,75,
  -7,77,2,54,5,50,-3,68,1,50,6,42,-4,81,1,63,-4,70,0,67,2,57,-2,76,
  11,35,4,64,1,61,11,35,18,25,12,24,13,29,13,36,-10,93,-7,73,-2,73,13,46,
  9,49,-7,100,9,53,2,53,5,53,-2,61,0,56,0,56,-13,63,-5,60,-1,62,4,57,
  -6,69,4,57,14,39,4,51,13,68,3,64,1,61,9,63,7,50,16,39,5,44,4,52,
  11,48,-5,60,-1,59,0,59,22,33,5,44,14,43,-1,78,0,60,9,69,11,28,2,40,
  3,44,0,49,0,46,2,44,2,51,0,47,4,39,2,62,6,46,0,54,3,54,2,58,
  4,63,6,51,6,57,7,53,6,52,6,55,11,45,14,36,8,53,-1,82,7,55,-3,78,
  15,46,22,31,-1,84,25,7,30,-7,28,3,28,4,32,0,34,-1,30,6,30,6,32,9,
  31,19,26,27,26,30,37,20,28,34,17,70,1,67,5,59,9,67,16,30,18,32,18,35,
  22,29,24,31,23,38,18,43,20,41,11,63,9,59,9,64,-1,94,-2,89,-9,108,-6,76,
  -2,44,0,45,0,52,-3,64,-2,59,-4,70,-4,75,-8,82,-17,102,-9,77,3,24,0,42,
  0,48,0,55,-6,59,-7,71,-12,83,-11,87,-30,119,1,58,-3,29,-1,36,1,38,2,43,
  -6,55,0,58,0,64,-3,74,-10,90,0,70,-4,29,5,31,7,42,1,59,-2,58,-3,72,
  -3,81,-11,97,0,58,8,5,10,14,14,18,13,27,2,40,0,58,-3,70,-6,79,-8,85,
  0,0,-13,106,-16,106,-10,87,-21,114,-18,110,-14,98,-22,110,-21,106,-18,103,-21,
   107,-23,108,
  -26,112,-10,96,-12,95,-5,91,-9,93,-22,94,-5,86,9,67,-4,80,-10,85,-1,70,7,60,
  9,58,5,61,12,50,15,50,18,49,17,54,10,41,7,46,-1,51,7,49,8,52,9,41,
  6,47,2,55,13,41,10,44,6,50,5,53,13,49,4,63,6,64,-2,69,-2,59,6,70,
  10,44,9,31,12,43,3,53,14,34,10,38,-3,52,13,40,17,32,7,44,7,38,13,50,
  10,57,26,43,14,11,11,14,9,11,18,11,21,9,23,-2,32,-15,32,-15,34,-21,39,-23,
  42,-33,41,-31,46,-28,38,-12,21,29,45,-24,53,-45,48,-26,65,-43,43,-19,39,-10,
   30,9,
  18,26,20,27,0,57,-14,82,-5,75,-19,97,-35,125,27,0,28,0,31,-4,27,6,34,8,
  30,10,24,22,33,19,22,32,26,31,21,41,26,44,23,47,16,65,14,71,8,60,6,63,
  17,65,21,24,23,20,26,23,27,32,28,23,28,24,23,40,24,32,28,29,23,42,19,57,
  22,53,22,61,11,86,12,40,11,51,14,59,-4,79,-7,71,-5,69,-9,70,-8,66,-10,68,
  -19,73,-12,69,-16,70,-15,67,-20,62,-19,70,-16,66,-22,65,-20,63,9,-2,26,-9,33,-
   9,
  39,-7,41,-2,45,3,49,9,45,27,36,59,-6,66,-7,35,-7,42,-8,45,-5,48,-12,56,
  -6,60,-5,62,-8,66,-8,76,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,
  -9,71,-9,67,-1,61,-8,66,-14,66,0,59,2,59,21,-13,33,-14,39,-7,46,-2,51,2,
  60,6,61,17,55,34,42,62,-7,92,-5,89,-7,96,-13,108,-3,46,-1,65,-1,57,-9,93,
  -3,74,-9,92,-8,87,-23,126,-7,92,-5,89,-7,96,-13,108,-3,46,-1,65,-1,57,-9,93,
  -3,74,-9,92,-8,87,-23,126,-2,85,-6,78,-1,75,-7,77,2,54,5,50,-3,68,1,50,
  6,42,-4,81,1,63,-4,70,0,67,2,57,-2,76,11,35,4,64,1,61,11,35,18,25,
  12,24,13,29,13,36,-10,93,-7,73,-2,73,13,46,9,49,-7,100,9,53,2,53,5,53,
  -2,61,0,56,0,56,-13,63,-5,60,-1,62,4,57,-6,69,4,57,14,39,4,51,13,68,
  -2,85,-6,78,-1,75,-7,77,2,54,5,50,-3,68,1,50,6,42,-4,81,1,63,-4,70,
  0,67,2,57,-2,76,11,35,4,64,1,61,11,35,18,25,12,24,13,29,13,36,-10,93,
  -7,73,-2,73,13,46,9,49,-7,100,9,53,2,53,5,53,-2,61,0,56,0,56,-13,63,
  -5,60,-1,62,4,57,-6,69,4,57,14,39,4,51,13,68,11,28,2,40,3,44,0,49,
  0,46,2,44,2,51,0,47,4,39,2,62,6,46,0,54,3,54,2,58,4,63,6,51,
  6,57,7,53,6,52,6,55,11,45,14,36,8,53,-1,82,7,55,-3,78,15,46,22,31,
  -1,84,25,7,30,-7,28,3,28,4,32,0,34,-1,30,6,30,6,32,9,31,19,26,27,
  26,30,37,20,28,34,17,70,11,28,2,40,3,44,0,49,0,46,2,44,2,51,0,47,
  4,39,2,62,6,46,0,54,3,54,2,58,4,63,6,51,6,57,7,53,6,52,6,55,
  11,45,14,36,8,53,-1,82,7,55,-3,78,15,46,22,31,-1,84,25,7,30,-7,28,3,
  28,4,32,0,34,-1,30,6,30,6,32,9,31,19,26,27,26,30,37,20,28,34,17,70,
  -4,79,-7,71,-5,69,-9,70,-8,66,-10,68,-19,73,-12,69,-16,70,-15,67,-20,62,-19,
   70,
  -16,66,-22,65,-20,63,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,-9,
   71,
  -9,67,-1,61,-8,66,-14,66,0,59,2,59,9,-2,26,-9,33,-9,39,-7,41,-2,45,3,
  49,9,45,27,36,59,21,-13,33,-14,39,-7,46,-2,51,2,60,6,61,17,55,34,42,62,
  -6,66,-7,35,-7,42,-8,45,-5,48,-12,56,-6,60,-5,62,-8,66,-8,76,-4,79,-7,71,
  -5,69,-9,70,-8,66,-10,68,-19,73,-12,69,-16,70,-15,67,-20,62,-19,70,-16,66,-22,
   65,
  -20,63,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,-9,71,-9,67,-1,61,
  -8,66,-14,66,0,59,2,59,9,-2,26,-9,33,-9,39,-7,41,-2,45,3,49,9,45,27,
  36,59,21,-13,33,-14,39,-7,46,-2,51,2,60,6,61,17,55,34,42,62,-6,66,-7,35,
  -7,42,-8,45,-5,48,-12,56,-6,60,-5,62,-8,66,-8,76,-13,106,-16,106,-10,87,-21,
   114,
  -18,110,-14,98,-22,110,-21,106,-18,103,-21,107,-23,108,-26,112,-10,96,-12,95,-
   5,91,-9,93,
  -22,94,-5,86,9,67,-4,80,-10,85,-1,70,7,60,9,58,5,61,12,50,15,50,18,49,
  17,54,10,41,7,46,-1,51,7,49,8,52,9,41,6,47,2,55,13,41,10,44,6,50,
  5,53,13,49,4,63,6,64,-13,106,-16,106,-10,87,-21,114,-18,110,-14,98,-22,110,-
   21,106,
  -18,103,-21,107,-23,108,-26,112,-10,96,-12,95,-5,91,-9,93,-22,94,-5,86,9,67,-
   4,80,
  -10,85,-1,70,7,60,9,58,5,61,12,50,15,50,18,49,17,54,10,41,7,46,-1,51,
  7,49,8,52,9,41,6,47,2,55,13,41,10,44,6,50,5,53,13,49,4,63,6,64,
  14,11,11,14,9,11,18,11,21,9,23,-2,32,-15,32,-15,34,-21,39,-23,42,-33,41,-31,
  46,-28,38,-12,21,29,45,-24,53,-45,48,-26,65,-43,43,-19,39,-10,30,9,18,26,20,
   27,
  0,57,-14,82,-5,75,-19,97,-35,125,27,0,28,0,31,-4,27,6,34,8,30,10,24,22,
  33,19,22,32,26,31,21,41,26,44,23,47,16,65,14,71,14,11,11,14,9,11,18,11,
  21,9,23,-2,32,-15,32,-15,34,-21,39,-23,42,-33,41,-31,46,-28,38,-12,21,29,45,-
   24,
  53,-45,48,-26,65,-43,43,-19,39,-10,30,9,18,26,20,27,0,57,-14,82,-5,75,-19,97,
  -35,125,27,0,28,0,31,-4,27,6,34,8,30,10,24,22,33,19,22,32,26,31,21,41,
  26,44,23,47,16,65,14,71,-6,76,-2,44,0,45,0,52,-3,64,-2,59,-4,70,-4,75,
  -8,82,-17,102,-9,77,3,24,0,42,0,48,0,55,-6,59,-7,71,-12,83,-11,87,-30,119,
  1,58,-3,29,-1,36,1,38,2,43,-6,55,0,58,0,64,-3,74,-10,90,-6,76,-2,44,
  0,45,0,52,-3,64,-2,59,-4,70,-4,75,-8,82,-17,102,-9,77,3,24,0,42,0,48,
  0,55,-6,59,-7,71,-12,83,-11,87,-30,119,1,58,-3,29,-1,36,1,38,2,43,-6,55,
  0,58,0,64,-3,74,-10,90,-3,74,-9,92,-8,87,-23,126,-3,74,-9,92,-8,87,-23,126,
  -3,74,-9,92,-8,87,-23,126,20,-15,2,54,3,74,20,-15,2,54,3,74,-28,127,-23,104,
  -6,53,-1,54,7,51,22,25,34,0,16,0,-2,9,4,41,-29,118,2,65,-6,71,-13,79,
  5,52,9,50,-3,70,10,54,26,34,19,22,40,0,57,2,41,36,26,69,-45,127,-15,101,
  -4,76,-6,71,-13,79,5,52,6,69,-13,90,0,52,8,43,-2,69,-5,82,-10,96,2,59,
  2,75,-3,87,-3,100,1,56,-3,74,-6,85,0,59,-3,81,-7,86,-5,95,-1,66,-1,77,
  1,70,-2,86,-5,72,0,61,0,41,0,63,0,63,0,63,-9,83,4,86,0,97,-7,72,
  13,41,3,62,13,15,7,51,2,80,-39,127,-18,91,-17,96,-26,81,-35,98,-24,102,-23,97,
  -27,119,-24,99,-21,110,-18,102,-36,127,0,80,-5,89,-7,94,-4,92,0,39,0,65,-15,
   84,
  -35,127,-2,73,-12,104,-9,91,-31,127,3,55,7,56,7,55,8,61,-3,53,0,68,-7,74,
  -9,88,-13,103,-13,91,-9,89,-14,92,-8,76,-12,87,-23,110,-24,105,-10,78,-20,112,
   -17,99,
  -78,127,-70,127,-50,127,-46,127,-4,66,-5,78,-4,71,-8,72,2,59,-1,55,-7,70,-6,
   75,
  -8,89,-34,119,-3,75,32,20,30,22,-44,127,0,54,-5,61,0,58,-1,60,-3,61,-8,67,
  -25,84,-14,74,-5,65,5,52,2,57,0,61,-9,69,-11,70,18,55,-4,71,0,58,7,61,
  9,41,18,25,9,32,5,43,9,47,0,44,0,51,2,46,19,38,-4,66,15,38,12,42,
  9,34,0,89,4,45,10,28,10,31,33,-11,52,-43,18,15,28,0,35,-22,38,-25,34,0,
  39,-18,32,-12,102,-94,0,0,56,-15,33,-4,29,10,37,-5,51,-29,39,-9,52,-34,69,-58,
  67,-63,44,-5,32,7,55,-29,32,1,0,0,27,36,33,-25,34,-30,36,-28,38,-28,38,-27,
  34,-18,35,-16,34,-14,32,-8,37,-6,35,0,30,10,28,18,26,25,29,41,0,75,2,72,
  8,77,14,35,18,31,17,35,21,30,17,45,20,42,18,45,27,26,16,54,7,66,16,56,
  11,73,10,67,-10,116,-23,112,-15,71,-7,61,0,53,-5,66,-11,77,-9,80,-9,84,-10,87,
  -34,127,-21,101,-3,39,-5,53,-7,61,-11,75,-15,77,-17,91,-25,107,-25,111,-28,
   122,-11,76,
  -10,44,-10,52,-10,57,-9,58,-16,72,-7,69,-4,69,-5,74,-9,86,2,66,-9,34,1,32,
  11,31,5,52,-2,55,-2,67,0,73,-8,89,3,52,7,4,10,8,17,8,16,19,3,37,
  -1,61,-5,73,-1,70,-4,78,0,0,-21,126,-23,124,-20,110,-26,126,-25,124,-17,105,-
   27,121,
  -27,117,-17,102,-26,117,-27,116,-33,122,-10,95,-14,100,-8,95,-17,111,-28,114,-
   6,89,-2,80,
  -4,82,-9,85,-8,81,-1,72,5,64,1,67,9,56,0,69,1,69,7,69,-7,69,-6,67,
  -16,77,-2,64,2,61,-6,67,-3,64,2,57,-3,65,-3,66,0,62,9,51,-1,66,-2,71,
  -2,75,-1,70,-9,72,14,60,16,37,0,47,18,35,11,37,12,41,10,41,2,48,12,41,
  13,41,0,59,3,50,19,40,3,66,18,50,19,-6,18,-6,14,0,26,-12,31,-16,33,-25,
  33,-22,37,-28,39,-30,42,-30,47,-42,45,-36,49,-34,41,-17,32,9,69,-71,63,-63,66,
   -64,
  77,-74,54,-39,52,-35,41,-10,36,0,40,-1,30,14,28,26,23,37,12,55,11,65,37,-33,
  39,-36,40,-37,38,-30,46,-33,42,-30,40,-24,49,-29,38,-12,40,-10,38,-3,46,-5,31,
   20,
  29,30,25,44,12,48,11,49,26,45,22,22,23,22,27,21,33,20,26,28,30,24,27,34,
  18,42,25,39,18,50,12,70,21,54,14,71,11,83,25,32,21,49,21,54,-5,85,-6,81,
  -10,77,-7,81,-17,80,-18,73,-4,74,-10,83,-9,71,-9,67,-1,61,-8,66,-14,66,0,59,
  2,59,17,-10,32,-13,42,-9,49,-5,53,0,64,3,68,10,66,27,47,57,-5,71,0,24,
  -1,36,-2,42,-2,52,-9,57,-6,63,-4,65,-4,67,-7,82,-3,81,-3,76,-7,72,-6,78,
  -12,72,-14,68,-3,70,-6,76,-5,66,-5,62,0,57,-4,61,-9,60,1,54,2,58,17,-10,
  32,-13,42,-9,49,-5,53,0,64,3,68,10,66,27,47,57,0,80,-5,89,-7,94,-4,92,
  0,39,0,65,-15,84,-35,127,-2,73,-12,104,-9,91,-31,127,0,80,-5,89,-7,94,-4,92,
  0,39,0,65,-15,84,-35,127,-2,73,-12,104,-9,91,-31,127,-13,103,-13,91,-9,89,-14,
   92,
  -8,76,-12,87,-23,110,-24,105,-10,78,-20,112,-17,99,-78,127,-70,127,-50,127,-
   46,127,-4,66,
  -5,78,-4,71,-8,72,2,59,-1,55,-7,70,-6,75,-8,89,-34,119,-3,75,32,20,30,22,
  -44,127,0,54,-5,61,0,58,-1,60,-3,61,-8,67,-25,84,-14,74,-5,65,5,52,2,57,
  0,61,-9,69,-11,70,18,55,-13,103,-13,91,-9,89,-14,92,-8,76,-12,87,-23,110,-24,
   105,
  -10,78,-20,112,-17,99,-78,127,-70,127,-50,127,-46,127,-4,66,-5,78,-4,71,-8,72,
   2,59,
  -1,55,-7,70,-6,75,-8,89,-34,119,-3,75,32,20,30,22,-44,127,0,54,-5,61,0,58,
  -1,60,-3,61,-8,67,-25,84,-14,74,-5,65,5,52,2,57,0,61,-9,69,-11,70,18,55,
  4,45,10,28,10,31,33,-11,52,-43,18,15,28,0,35,-22,38,-25,34,0,39,-18,32,-12,
  102,-94,0,0,56,-15,33,-4,29,10,37,-5,51,-29,39,-9,52,-34,69,-58,67,-63,44,-5,
  32,7,55,-29,32,1,0,0,27,36,33,-25,34,-30,36,-28,38,-28,38,-27,34,-18,35,-16,
  34,-14,32,-8,37,-6,35,0,30,10,28,18,26,25,29,41,4,45,10,28,10,31,33,-11,
  52,-43,18,15,28,0,35,-22,38,-25,34,0,39,-18,32,-12,102,-94,0,0,56,-15,33,-4,
  29,10,37,-5,51,-29,39,-9,52,-34,69,-58,67,-63,44,-5,32,7,55,-29,32,1,0,0,
  27,36,33,-25,34,-30,36,-28,38,-28,38,-27,34,-18,35,-16,34,-14,32,-8,37,-6,35,
   0,
  30,10,28,18,26,25,29,41,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,
  -9,71,-9,67,-1,61,-8,66,-14,66,0,59,2,59,-3,81,-3,76,-7,72,-6,78,-12,72,
  -14,68,-3,70,-6,76,-5,66,-5,62,0,57,-4,61,-9,60,1,54,2,58,17,-10,32,-13,
  42,-9,49,-5,53,0,64,3,68,10,66,27,47,57,17,-10,32,-13,42,-9,49,-5,53,0,
  64,3,68,10,66,27,47,57,-5,71,0,24,-1,36,-2,42,-2,52,-9,57,-6,63,-4,65,
  -4,67,-7,82,-5,85,-6,81,-10,77,-7,81,-17,80,-18,73,-4,74,-10,83,-9,71,-9,67,
  -1,61,-8,66,-14,66,0,59,2,59,-3,81,-3,76,-7,72,-6,78,-12,72,-14,68,-3,70,
  -6,76,-5,66,-5,62,0,57,-4,61,-9,60,1,54,2,58,17,-10,32,-13,42,-9,49,-5,
  53,0,64,3,68,10,66,27,47,57,17,-10,32,-13,42,-9,49,-5,53,0,64,3,68,10,
  66,27,47,57,-5,71,0,24,-1,36,-2,42,-2,52,-9,57,-6,63,-4,65,-4,67,-7,82,
  -21,126,-23,124,-20,110,-26,126,-25,124,-17,105,-27,121,-27,117,-17,102,-26,
   117,-27,116,-33,122,
  -10,95,-14,100,-8,95,-17,111,-28,114,-6,89,-2,80,-4,82,-9,85,-8,81,-1,72,5,64,
  1,67,9,56,0,69,1,69,7,69,-7,69,-6,67,-16,77,-2,64,2,61,-6,67,-3,64,
  2,57,-3,65,-3,66,0,62,9,51,-1,66,-2,71,-2,75,-21,126,-23,124,-20,110,-26,126,
  -25,124,-17,105,-27,121,-27,117,-17,102,-26,117,-27,116,-33,122,-10,95,-14,
   100,-8,95,-17,111,
  -28,114,-6,89,-2,80,-4,82,-9,85,-8,81,-1,72,5,64,1,67,9,56,0,69,1,69,
  7,69,-7,69,-6,67,-16,77,-2,64,2,61,-6,67,-3,64,2,57,-3,65,-3,66,0,62,
  9,51,-1,66,-2,71,-2,75,19,-6,18,-6,14,0,26,-12,31,-16,33,-25,33,-22,37,-28,
  39,-30,42,-30,47,-42,45,-36,49,-34,41,-17,32,9,69,-71,63,-63,66,-64,77,-74,54,
   -39,
  52,-35,41,-10,36,0,40,-1,30,14,28,26,23,37,12,55,11,65,37,-33,39,-36,40,-37,
  38,-30,46,-33,42,-30,40,-24,49,-29,38,-12,40,-10,38,-3,46,-5,31,20,29,30,25,
   44,
  19,-6,18,-6,14,0,26,-12,31,-16,33,-25,33,-22,37,-28,39,-30,42,-30,47,-42,45,-
   36,
  49,-34,41,-17,32,9,69,-71,63,-63,66,-64,77,-74,54,-39,52,-35,41,-10,36,0,40,-
   1,
  30,14,28,26,23,37,12,55,11,65,37,-33,39,-36,40,-37,38,-30,46,-33,42,-30,40,-
   24,
  49,-29,38,-12,40,-10,38,-3,46,-5,31,20,29,30,25,44,-23,112,-15,71,-7,61,0,53,
  -5,66,-11,77,-9,80,-9,84,-10,87,-34,127,-21,101,-3,39,-5,53,-7,61,-11,75,-15,
   77,
  -17,91,-25,107,-25,111,-28,122,-11,76,-10,44,-10,52,-10,57,-9,58,-16,72,-7,69,
   -4,69,
  -5,74,-9,86,-23,112,-15,71,-7,61,0,53,-5,66,-11,77,-9,80,-9,84,-10,87,-34,127,
  -21,101,-3,39,-5,53,-7,61,-11,75,-15,77,-17,91,-25,107,-25,111,-28,122,-11,76,
   -10,44,
  -10,52,-10,57,-9,58,-16,72,-7,69,-4,69,-5,74,-9,86,-2,73,-12,104,-9,91,-31,
   127,
  -2,73,-12,104,-9,91,-31,127,-2,73,-12,104,-9,91,-31,127,20,-15,2,54,3,74,20,-
   15,
  2,54,3,74,-28,127,-23,104,-6,53,-1,54,7,51,29,16,25,0,14,0,-10,51,-3,62,
  -27,99,26,16,-4,85,-24,102,5,57,6,57,-17,73,14,57,20,40,20,10,29,0,54,0,
  37,42,12,97,-32,127,-22,117,-2,74,-4,85,-24,102,5,57,-6,93,-14,88,-6,44,4,55,
  -11,89,-15,103,-21,116,19,57,20,58,4,84,6,96,1,63,-5,85,-13,106,5,63,6,75,
  -3,90,-1,101,3,55,-4,79,-2,75,-12,97,-7,50,1,60,0,41,0,63,0,63,0,63,
  -9,83,4,86,0,97,-7,72,13,41,3,62,7,34,-9,88,-20,127,-36,127,-17,91,-14,95,
  -25,84,-25,86,-12,89,-17,91,-31,127,-14,76,-18,103,-13,90,-37,127,11,80,5,76,
   2,84,
  5,78,-6,55,4,61,-14,83,-37,127,-5,79,-11,104,-11,91,-30,127,0,65,-2,79,0,72,
  -4,92,-6,56,3,68,-8,71,-13,98,-4,86,-12,88,-5,82,-3,72,-4,67,-8,72,-16,89,
  -9,69,-1,59,5,66,4,57,-4,71,-2,71,2,58,-1,74,-4,44,-1,69,0,62,-7,51,
  -4,47,-6,42,-3,41,-6,53,8,76,-9,78,-11,83,9,52,0,67,-5,90,1,67,-15,72,
  -5,75,-8,80,-21,83,-21,64,-13,31,-25,64,-29,94,9,75,17,63,-8,74,-5,35,-2,27,
  13,91,3,65,-7,69,8,77,-10,66,3,62,-3,68,-20,81,0,30,1,7,-3,23,-21,74,
  16,66,-23,124,17,37,44,-18,50,-34,-22,127,4,39,0,42,7,34,11,29,8,31,6,37,
  7,42,3,40,8,33,13,43,13,36,4,47,3,55,2,58,6,60,8,44,11,44,14,42,
  7,48,4,56,4,52,13,37,9,49,19,58,10,48,12,45,0,69,20,33,8,63,35,-18,
  33,-25,28,-3,24,10,27,0,34,-14,52,-44,39,-24,19,17,31,25,36,29,24,33,34,15,
  30,20,22,73,20,34,19,31,27,44,19,16,15,36,15,36,21,28,25,21,30,20,31,12,
  27,16,24,42,0,93,14,56,15,57,26,38,-24,127,-24,115,-22,82,-9,62,0,53,0,59,
  -14,85,-13,89,-13,94,-11,92,-29,127,-21,100,-14,57,-12,67,-11,71,-10,77,-21,
   85,-16,88,
  -23,104,-15,98,-37,127,-10,82,-8,48,-8,61,-8,66,-7,70,-14,75,-10,79,-9,83,-12,
   92,
  -18,108,-4,79,-22,69,-16,75,-2,58,1,58,-13,78,-9,83,-4,81,-13,99,-13,81,-6,38,
  -13,62,-6,58,-2,59,-16,73,-10,76,-13,86,-9,83,-10,87,0,0,-22,127,-25,127,-25,
   120,
  -27,127,-19,114,-23,117,-25,118,-26,117,-24,113,-28,118,-31,120,-37,124,-10,
   94,-15,102,-10,99,
  -13,106,-50,127,-5,92,17,57,-5,86,-13,94,-12,91,-2,77,0,71,-1,73,4,64,-7,81,
  5,64,15,57,1,67,0,68,-10,67,1,68,0,77,2,64,0,68,-5,78,7,55,5,59,
  2,65,14,54,15,44,5,60,2,70,-2,76,-18,86,12,70,5,64,-12,70,11,55,5,56,
  0,69,2,65,-6,74,5,54,7,54,-6,76,-11,82,-2,77,-2,77,25,42,17,-13,16,-9,
  17,-12,27,-21,37,-30,41,-40,42,-41,48,-47,39,-32,46,-40,52,-51,46,-41,52,-39,
   43,-19,
  32,11,61,-55,56,-46,62,-50,81,-67,45,-20,35,-2,28,15,34,1,39,1,30,17,20,38,
  18,45,15,54,0,79,36,-16,37,-14,37,-17,32,1,34,15,29,15,24,25,34,22,31,16,
  35,18,31,28,33,41,36,28,27,47,21,62,18,31,19,26,36,24,24,23,27,16,24,30,
  31,29,22,41,22,42,16,60,15,52,14,60,3,78,-16,123,21,53,22,56,25,61,21,33,
  19,50,17,61,-3,78,-8,74,-9,72,-10,72,-18,75,-12,71,-11,63,-5,70,-17,75,-14,72,
  -16,67,-8,53,-14,59,-9,52,-11,68,9,-2,30,-10,31,-4,33,-1,33,7,31,12,37,23,
  31,38,20,64,-9,71,-7,37,-8,44,-11,49,-10,56,-12,59,-8,63,-9,67,-6,68,-10,79,
  -3,78,-8,74,-9,72,-10,72,-18,75,-12,71,-11,63,-5,70,-17,75,-14,72,-16,67,-8,
   53,
  -14,59,-9,52,-11,68,9,-2,30,-10,31,-4,33,-1,33,7,31,12,37,23,31,38,20,64,
  11,80,5,76,2,84,5,78,-6,55,4,61,-14,83,-37,127,-5,79,-11,104,-11,91,-30,127,
  11,80,5,76,2,84,5,78,-6,55,4,61,-14,83,-37,127,-5,79,-11,104,-11,91,-30,127,
  -4,86,-12,88,-5,82,-3,72,-4,67,-8,72,-16,89,-9,69,-1,59,5,66,4,57,-4,71,
  -2,71,2,58,-1,74,-4,44,-1,69,0,62,-7,51,-4,47,-6,42,-3,41,-6,53,8,76,
  -9,78,-11,83,9,52,0,67,-5,90,1,67,-15,72,-5,75,-8,80,-21,83,-21,64,-13,31,
  -25,64,-29,94,9,75,17,63,-8,74,-5,35,-2,27,13,91,-4,86,-12,88,-5,82,-3,72,
  -4,67,-8,72,-16,89,-9,69,-1,59,5,66,4,57,-4,71,-2,71,2,58,-1,74,-4,44,
  -1,69,0,62,-7,51,-4,47,-6,42,-3,41,-6,53,8,76,-9,78,-11,83,9,52,0,67,
  -5,90,1,67,-15,72,-5,75,-8,80,-21,83,-21,64,-13,31,-25,64,-29,94,9,75,17,63,
  -8,74,-5,35,-2,27,13,91,4,39,0,42,7,34,11,29,8,31,6,37,7,42,3,40,
  8,33,13,43,13,36,4,47,3,55,2,58,6,60,8,44,11,44,14,42,7,48,4,56,
  4,52,13,37,9,49,19,58,10,48,12,45,0,69,20,33,8,63,35,-18,33,-25,28,-3,
  24,10,27,0,34,-14,52,-44,39,-24,19,17,31,25,36,29,24,33,34,15,30,20,22,73,
  4,39,0,42,7,34,11,29,8,31,6,37,7,42,3,40,8,33,13,43,13,36,4,47,
  3,55,2,58,6,60,8,44,11,44,14,42,7,48,4,56,4,52,13,37,9,49,19,58,
  10,48,12,45,0,69,20,33,8,63,35,-18,33,-25,28,-3,24,10,27,0,34,-14,52,-44,
  39,-24,19,17,31,25,36,29,24,33,34,15,30,20,22,73,-3,78,-8,74,-9,72,-10,72,
  -18,75,-12,71,-11,63,-5,70,-17,75,-14,72,-16,67,-8,53,-14,59,-9,52,-11,68,-3,
   78,
  -8,74,-9,72,-10,72,-18,75,-12,71,-11,63,-5,70,-17,75,-14,72,-16,67,-8,53,-14,
   59,
  -9,52,-11,68,9,-2,30,-10,31,-4,33,-1,33,7,31,12,37,23,31,38,20,64,9,-2,
  30,-10,31,-4,33,-1,33,7,31,12,37,23,31,38,20,64,-9,71,-7,37,-8,44,-11,49,
  -10,56,-12,59,-8,63,-9,67,-6,68,-10,79,-3,78,-8,74,-9,72,-10,72,-18,75,-12,71,
  -11,63,-5,70,-17,75,-14,72,-16,67,-8,53,-14,59,-9,52,-11,68,-3,78,-8,74,-9,72,
  -10,72,-18,75,-12,71,-11,63,-5,70,-17,75,-14,72,-16,67,-8,53,-14,59,-9,52,-11,
   68,
  9,-2,30,-10,31,-4,33,-1,33,7,31,12,37,23,31,38,20,64,9,-2,30,-10,31,-4,
  33,-1,33,7,31,12,37,23,31,38,20,64,-9,71,-7,37,-8,44,-11,49,-10,56,-12,59,
  -8,63,-9,67,-6,68,-10,79,-22,127,-25,127,-25,120,-27,127,-19,114,-23,117,-25,
   118,-26,117,
  -24,113,-28,118,-31,120,-37,124,-10,94,-15,102,-10,99,-13,106,-50,127,-5,92,
   17,57,-5,86,
  -13,94,-12,91,-2,77,0,71,-1,73,4,64,-7,81,5,64,15,57,1,67,0,68,-10,67,
  1,68,0,77,2,64,0,68,-5,78,7,55,5,59,2,65,14,54,15,44,5,60,2,70,
  -22,127,-25,127,-25,120,-27,127,-19,114,-23,117,-25,118,-26,117,-24,113,-28,
   118,-31,120,-37,124,
  -10,94,-15,102,-10,99,-13,106,-50,127,-5,92,17,57,-5,86,-13,94,-12,91,-2,77,0,
   71,
  -1,73,4,64,-7,81,5,64,15,57,1,67,0,68,-10,67,1,68,0,77,2,64,0,68,
  -5,78,7,55,5,59,2,65,14,54,15,44,5,60,2,70,17,-13,16,-9,17,-12,27,-21,
  37,-30,41,-40,42,-41,48,-47,39,-32,46,-40,52,-51,46,-41,52,-39,43,-19,32,11,
   61,-55,
  56,-46,62,-50,81,-67,45,-20,35,-2,28,15,34,1,39,1,30,17,20,38,18,45,15,54,
  0,79,36,-16,37,-14,37,-17,32,1,34,15,29,15,24,25,34,22,31,16,35,18,31,28,
  33,41,36,28,27,47,21,62,17,-13,16,-9,17,-12,27,-21,37,-30,41,-40,42,-41,48,-
   47,
  39,-32,46,-40,52,-51,46,-41,52,-39,43,-19,32,11,61,-55,56,-46,62,-50,81,-67,
   45,-20,
  35,-2,28,15,34,1,39,1,30,17,20,38,18,45,15,54,0,79,36,-16,37,-14,37,-17,
  32,1,34,15,29,15,24,25,34,22,31,16,35,18,31,28,33,41,36,28,27,47,21,62,
  -24,115,-22,82,-9,62,0,53,0,59,-14,85,-13,89,-13,94,-11,92,-29,127,-21,100,-
   14,57,
  -12,67,-11,71,-10,77,-21,85,-16,88,-23,104,-15,98,-37,127,-10,82,-8,48,-8,61,-
   8,66,
  -7,70,-14,75,-10,79,-9,83,-12,92,-18,108,-24,115,-22,82,-9,62,0,53,0,59,-14,
   85,
  -13,89,-13,94,-11,92,-29,127,-21,100,-14,57,-12,67,-11,71,-10,77,-21,85,-16,
   88,-23,104,
  -15,98,-37,127,-10,82,-8,48,-8,61,-8,66,-7,70,-14,75,-10,79,-9,83,-12,92,-18,
   108,
  -5,79,-11,104,-11,91,-30,127,-5,79,-11,104,-11,91,-30,127,-5,79,-11,104,-11,
   91,-30,127
 );
 H4Def4Intra: Array[0..15] Of Byte=(
  6,13,20,28,13,20,28,32,20,28,32,37,28,32,37,42
 );
 H4Def4Inter: Array[0..15] Of Byte=(
  10,14,20,24,14,20,24,27,20,24,27,30,24,27,30,34
 );
 H4Def8Intra: Array[0..63] Of Byte=(
  6,10,13,16,18,23,25,27,10,11,16,18,23,25,27,29,
  13,16,18,23,25,27,29,31,16,18,23,25,27,29,31,33,
  18,23,25,27,29,31,33,36,23,25,27,29,31,33,36,38,
  25,27,29,31,33,36,38,40,27,29,31,33,36,38,40,42
 );
 H4Def8Inter: Array[0..63] Of Byte=(
  9,13,15,17,19,21,22,24,13,13,17,19,21,22,24,25,
  15,17,19,21,22,24,25,27,17,19,21,22,24,25,27,28,
  19,21,22,24,25,27,28,30,21,22,24,25,27,28,30,32,
  22,24,25,27,28,30,32,33,24,25,27,28,30,32,33,35
 );

{ ---- H.264 / AVC (ITU-T H.264): decodeur progressif 4:2:0 8 bits, CAVLC et
 CABAC, I/P/B, transformee 8x8 ----
  Tables CAVLC/CABAC/deblocage extraites de libavcodec/h264_cavlc.c,
   h264_cabac.c, h264_loopfilter.c, h264data.c, h264_ps.c (LGPL-2.1-or-later). }
Type
 H4PWordArr=^H4TWordArr; H4TWordArr=Array[0..1048575] Of Word;
 H4PSmallArr=^H4TSmallArr; H4TSmallArr=Array[0..4800000] Of SmallInt;
 H4PLongArr=^H4TLongArr; H4TLongArr=Array[0..1048575] Of LongInt;
 TH4Sps=Record
  Valid: Boolean;
  ProfileIdc,ConstraintFlags,LevelIdc,SpsId,ChromaFormat,BitDepthY,BitDepthC,
   TransformBypass: LongInt;
  Log2MaxFrameNum,PocType,Log2MaxPocLsb,DeltaPicOrderAlwaysZero,
   OffsetForNonRefPic,OffsetForTopToBottom,PocCycleLength: LongInt;
  OffsetForRefFrame: Array[0..255] Of LongInt;
  RefFrameCount,GapsAllowed,MbW,MbH,FrameMbsOnly,Mbaff,Direct8x8Inference:
   LongInt;
  CropL,CropR,CropT,CropB: LongInt;
  VuiPresent,SarNum,SarDen,TimingInfo,FixedFrameRate,BitstreamRestriction,
   NumReorderFrames,MaxDecFrameBuffering: LongInt;
  NumUnitsInTick,TimeScale: Int64;
  ChromaLoc,FullRange,ColorDesc,ColorPrimaries,ColorTrc,ColorSpace: LongInt;
  ScalingPresent: LongInt;
  Sl4: Array[0..5,0..15] Of Byte; Sl8: Array[0..5,0..63] Of Byte;
 End;
 TH4Pps=Record
  Valid: Boolean;
  PpsId,SpsId,Cabac,BottomFieldPocPresent,NumSliceGroups,NumRefIdx0,NumRefIdx1,
   WeightedPred,WeightedBipred,InitQp,InitQs,ChromaQpOffset,ChromaQpOffset2:
   LongInt;
  DeblockCtrl,ConstrainedIntra,RedundantPicCnt,Transform8x8,ScalingPresent:
   LongInt;
  Sl4: Array[0..5,0..15] Of Byte; Sl8: Array[0..5,0..63] Of Byte;
 End;
 TH4Mmco=Record Op,A1,A2: LongInt; End;
 TH4Slice=Record
  FirstMb,SliceType,PpsId,FrameNum,FieldPic,BottomField,IdrPicId,PocLsb,
   DeltaPocBottom,RedundantPicCnt,DirectSpatial: LongInt;
  DeltaPoc: Array[0..1] Of LongInt;
  NumRef: Array[0..1] Of LongInt;
  ModFlag: Array[0..1] Of LongInt; ModCount: Array[0..1] Of LongInt;
  ModIdc,ModVal: Array[0..1,0..32] Of LongInt;
  LumaLog2Wd,ChromaLog2Wd: LongInt;
  LumaW,LumaO: Array[0..1,0..31] Of LongInt;
  ChromaW,ChromaO: Array[0..1,0..31,0..1] Of LongInt;
  LumaFlag,ChromaFlag: Array[0..1,0..31] Of LongInt;
  NoOutputPrior,LongTermRef,AdaptiveMarking,MmcoCount: LongInt;
  Mmco: Array[0..63] Of TH4Mmco;
  CabacInitIdc,QpDelta,Qp,SliceQs,DisableDeblock,AlphaOff,BetaOff,NalRefIdc,Idr:
   LongInt;
  SliceNum: LongInt;
 End;
Const
 H4MaxPics=40;
Var
 H4Rb: H4PBuf; H4RbSize: LongInt;       { RBSP courant (apres retrait des
  octets d'emulation) }
 H4Pos: LongInt;                            { position de lecture en bits }
 H4Sps: Array[0..31] Of TH4Sps; H4Pps: Array[0..255] Of TH4Pps;
 H4Err: Boolean;

Function H4Peek32: Int64;
Var B,I: LongInt; V: Int64;
Begin
 B:=H4Pos Shr 3; V:=0;
 For I:=0 To 4 Do Begin
  V:=V Shl 8;
  If B+I<H4RbSize Then V:=V Or H4Rb^[B+I];
 End;
 H4Peek32:=(V Shr (8-(H4Pos And 7))) And $FFFFFFFF;
End;
Function H4Bits(N: LongInt): LongInt;
Begin
 If N=0 Then Begin H4Bits:=0; Exit; End;
 H4Bits:=H4Peek32 Shr (32-N); Inc(H4Pos,N);
 If H4Pos>H4RbSize*8+64 Then H4Err:=True;
End;
Function H4Bit: LongInt;
Begin
 If (H4Pos Shr 3)<H4RbSize Then H4Bit:=(H4Rb^[H4Pos Shr 3] Shr (7-(H4Pos And
  7))) And 1 Else H4Bit:=0;
 Inc(H4Pos);
 If H4Pos>H4RbSize*8+64 Then H4Err:=True;
End;
Function H4Ue: LongInt;
Var Z,V: LongInt; P: Int64;
Begin
 Z:=0;
 P:=H4Peek32;
 While (Z<32) And ((P And (Int64(1) Shl (31-Z)))=0) Do Inc(Z);
 If Z>=32 Then Begin H4Err:=True; Inc(H4Pos,32); H4Ue:=0; Exit; End;
 If Z<=15 Then Begin
  V:=(P Shr (31-2*Z)) And ((Int64(1) Shl (Z+1))-1);
  Inc(H4Pos,2*Z+1); H4Ue:=V-1;
 End Else Begin
  Inc(H4Pos,Z+1); V:=H4Bits(Z); H4Ue:=((Int64(1) Shl Z)-1)+V;
 End;
End;
Function H4Se: LongInt;
Var K: LongInt;
Begin
 K:=H4Ue;
 If Odd(K) Then H4Se:=(K+1) Div 2 Else H4Se:=-(K Div 2);
End;
Function H4Te(Max: LongInt): LongInt;
Begin
 If Max>1 Then H4Te:=H4Ue Else H4Te:=1-H4Bit;
End;
Function H4Left: LongInt;Begin H4Left:=H4RbSize*8-H4Pos; End;
{ more_rbsp_data : reste-t-il des donnees avant le bit d'arret final ? }
Function H4MoreData: Boolean;
Var I,Last,B: LongInt;
Begin
 Last:=H4RbSize-1;
 While (Last>=0) And (H4Rb^[Last]=0) Do Dec(Last);
 If Last<0 Then Begin H4MoreData:=False; Exit; End;
 B:=H4Rb^[Last]; I:=0;
 While (B And 1)=0 Do Begin B:=B Shr 1; Inc(I); End;
 { bit d'arret a la position Last*8+7-I }
 H4MoreData:=H4Pos<Last*8+7-I;
End;

Const
 H4Zigzag4: Array[0..15] Of Byte=(0,1,4,8,5,2,3,6,9,12,13,10,7,11,14,15);
 H4Zigzag8: Array[0..63] Of Byte=(0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,
  26,33,40,48,41,34,27,20,13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,
  30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63);
 H4SarTab: Array[0..16,0..1] Of Word=((0,1),(1,1),(12,11),(10,11),(16,11),(40,
  33),(24,11),(20,11),(32,11),(80,33),(18,11),(15,11),(64,33),(160,99),(4,3),(3,
  2),(2,1));

Function H4Bits32: Int64;
Var V: Int64;
Begin
 V:=H4Peek32; Inc(H4Pos,32); H4Bits32:=V;
End;

{ lit une liste de ponderation (ordre de balayage -> raster) ; renvoie True si
 "liste par defaut" }
Function H4ReadList(Dst: H4PBuf; Size: LongInt): Boolean;
Var J,Last,Next,Idx: LongInt; UseDef: Boolean;
Begin
 Last:=8; Next:=8; UseDef:=False;
 For J:=0 To Size-1 Do Begin
  If Next<>0 Then Begin
   Next:=(Last+H4Se+256) And 255;
   If (J=0) And (Next=0) Then UseDef:=True;
  End;
  If Size=16 Then Idx:=H4Zigzag4[J] Else Idx:=H4Zigzag8[J];
  If Next=0 Then Dst^[Idx]:=Last Else Dst^[Idx]:=Next;
  Last:=Dst^[Idx];
 End;
 H4ReadList:=UseDef;
End;

{ decode_scaling_matrices ; Sp4/Sp8 = listes du SPS (regle B) si HaveSps, sinon
 valeurs par defaut (regle A) }
Procedure H4ParseScaling(D4,D8: H4PBuf; Count: LongInt; HaveSps: Boolean;
 Sp4,Sp8: H4PBuf);
Var I,Sz: LongInt; Pres,UseDef: Boolean; Tmp: Array[0..63] Of Byte;
Begin
 For I:=0 To Count-1 Do Begin
  Pres:=H4Bit<>0;
  If I<6 Then Sz:=16 Else Sz:=64;
  UseDef:=False;
  If Pres Then UseDef:=H4ReadList(@Tmp,Sz);
  If I<6 Then Begin
   If Pres And Not UseDef Then Move(Tmp,D4^[I*16],16)
   Else If Pres Then Begin If I<3 Then Move(H4Def4Intra,D4^[I*16],16) Else Move(
    H4Def4Inter,D4^[I*16],16); End
   Else Case I Of
    0: If HaveSps Then Move(Sp4^[0],D4^[0],16) Else Move(H4Def4Intra,D4^[0],16);
    3: If HaveSps Then Move(Sp4^[48],D4^[48],16) Else Move(H4Def4Inter,D4^[48],
     16);
   Else Move(D4^[(I-1)*16],D4^[I*16],16);
   End;
  End Else Begin
   If Pres And Not UseDef Then Move(Tmp,D8^[(I-6)*64],64)
   Else If Pres Then Begin If Odd(I) Then Move(H4Def8Inter,D8^[(I-6)*64],64)
    Else Move(H4Def8Intra,D8^[(I-6)*64],64); End
   Else Case I Of
    6: If HaveSps Then Move(Sp8^[0],D8^[0],64) Else Move(H4Def8Intra,D8^[0],64);
    7: If HaveSps Then Move(Sp8^[64],D8^[64],64) Else Move(H4Def8Inter,D8^[64],
     64);
   Else Move(D8^[(I-8)*64],D8^[(I-6)*64],64);
   End;
  End;
 End;
End;

Procedure H4ParseHrd;
Var Cnt,I: LongInt;
Begin
 Cnt:=H4Ue+1;
 H4Bits(4); H4Bits(4);
 For I:=1 To Cnt Do Begin H4Ue; H4Ue; H4Bit; End;
 H4Bits(5); H4Bits(5); H4Bits(5); H4Bits(5);
End;

Procedure H4ParseVui(Var S: TH4Sps);
Var Idc,Nal2: LongInt;
Begin
 S.VuiPresent:=1; S.SarNum:=0; S.SarDen:=1; S.ChromaLoc:=1; S.FullRange:=-1;
 If H4Bit<>0 Then Begin
  Idc:=H4Bits(8);
  If Idc=255 Then Begin S.SarNum:=H4Bits(16); S.SarDen:=H4Bits(16); End
  Else If (Idc>=1) And (Idc<=16) Then Begin S.SarNum:=H4SarTab[Idc,0];
   S.SarDen:=H4SarTab[Idc,1]; End;
 End;
 If H4Bit<>0 Then H4Bit;
 If H4Bit<>0 Then Begin
  H4Bits(3); S.FullRange:=H4Bit;
  If H4Bit<>0 Then Begin S.ColorDesc:=1; S.ColorPrimaries:=H4Bits(8);
   S.ColorTrc:=H4Bits(8); S.ColorSpace:=H4Bits(8); End;
 End;
 If H4Bit<>0 Then Begin
  Idc:=H4Ue; H4Ue;
  If Idc<=5 Then S.ChromaLoc:=Idc+1 Else S.ChromaLoc:=0;
 End;
 If H4Bit<>0 Then Begin
  S.TimingInfo:=1; S.NumUnitsInTick:=H4Bits32; S.TimeScale:=H4Bits32;
   S.FixedFrameRate:=H4Bit;
 End;
 Idc:=H4Bit; If Idc<>0 Then H4ParseHrd;
 Nal2:=H4Bit; If Nal2<>0 Then H4ParseHrd;
 If (Idc<>0) Or (Nal2<>0) Then H4Bit;
 H4Bit;
 If H4Bit<>0 Then Begin
  S.BitstreamRestriction:=1;
  H4Bit; H4Ue; H4Ue; H4Ue; H4Ue;
  S.NumReorderFrames:=H4Ue; S.MaxDecFrameBuffering:=H4Ue;
 End;
End;

{ SPS : renvoie 0 si ok, <0 sinon }
Function H4ParseSps: LongInt;
Var Prof,Id,I,T,Cnt: LongInt; S: TH4Sps; Hf: Boolean;
Begin
 H4ParseSps:=-1;
 FillChar(S,SizeOf(S),0);
 Prof:=H4Bits(8); S.ConstraintFlags:=H4Bits(8); S.LevelIdc:=H4Bits(8); Id:=H4Ue;
 If (Id>31) Or H4Err Then Exit;
 S.SpsId:=Id; S.ProfileIdc:=Prof;
 S.ChromaFormat:=1; S.BitDepthY:=8; S.BitDepthC:=8;
 FillChar(S.Sl4,SizeOf(S.Sl4),16); FillChar(S.Sl8,SizeOf(S.Sl8),16);
 If (Prof=100) Or (Prof=110) Or (Prof=122) Or (Prof=244) Or (Prof=44) Or (
  Prof=83) Or (Prof=86) Or (Prof=118) Or (Prof=128) Or (Prof=138) Or (Prof=144)
  Then Begin
  S.ChromaFormat:=H4Ue;
  If S.ChromaFormat>3 Then Exit;
  If S.ChromaFormat=3 Then If H4Bit<>0 Then Exit;
  S.BitDepthY:=H4Ue+8; S.BitDepthC:=H4Ue+8;
  If (S.BitDepthY<>S.BitDepthC) Or (S.BitDepthY<8) Or (S.BitDepthY>14) Then
   Exit;
  S.TransformBypass:=H4Bit;
  If H4Bit<>0 Then Begin
   S.ScalingPresent:=1;
   If S.ChromaFormat<>3 Then Cnt:=8 Else Cnt:=12;
   H4ParseScaling(@S.Sl4,@S.Sl8,Cnt,False,Nil,Nil);
  End;
 End;
 T:=H4Ue; If T>12 Then Exit; S.Log2MaxFrameNum:=T+4;
 S.PocType:=H4Ue;
 If S.PocType=0 Then Begin
  T:=H4Ue; If T>12 Then Exit; S.Log2MaxPocLsb:=T+4;
 End Else If S.PocType=1 Then Begin
  S.DeltaPicOrderAlwaysZero:=H4Bit; S.OffsetForNonRefPic:=H4Se;
   S.OffsetForTopToBottom:=H4Se;
  S.PocCycleLength:=H4Ue;
  If S.PocCycleLength>255 Then Exit;
  For I:=0 To S.PocCycleLength-1 Do S.OffsetForRefFrame[I]:=H4Se;
 End Else If S.PocType<>2 Then Exit;
 S.RefFrameCount:=H4Ue;
 If S.RefFrameCount>16 Then Exit;
 S.GapsAllowed:=H4Bit;
 S.MbW:=H4Ue+1; T:=H4Ue+1;
 S.FrameMbsOnly:=H4Bit;
 If S.FrameMbsOnly=0 Then S.Mbaff:=H4Bit;
 S.MbH:=T*(2-S.FrameMbsOnly);
 S.Direct8x8Inference:=H4Bit;
 If (S.MbW>1024) Or (S.MbH>1024) Or (S.MbW*S.MbH>139264) Then Exit;
 If H4Bit<>0 Then Begin
  S.CropL:=H4Ue; S.CropR:=H4Ue; S.CropT:=H4Ue; S.CropB:=H4Ue;
 End;
 S.ChromaLoc:=1; S.FullRange:=-1; S.SarNum:=0; S.SarDen:=1;
 If H4Bit<>0 Then H4ParseVui(S);
 If H4Err Then Exit;
 S.Valid:=True;
 H4Sps[Id]:=S;
 H4ParseSps:=0;
End;

Function H4ParsePps: LongInt;
Var P: TH4Pps; Id,Sid,Cnt: LongInt;
Begin
 H4ParsePps:=-1;
 FillChar(P,SizeOf(P),0);
 Id:=H4Ue; Sid:=H4Ue;
 If (Id>255) Or (Sid>31) Or H4Err Then Exit;
 If Not H4Sps[Sid].Valid Then Exit;
 P.PpsId:=Id; P.SpsId:=Sid;
 P.Cabac:=H4Bit; P.BottomFieldPocPresent:=H4Bit;
 P.NumSliceGroups:=H4Ue+1;
 If P.NumSliceGroups>1 Then Begin P.Valid:=True; H4Pps[Id]:=P; H4ParsePps:=0;
  Exit; End;
 P.NumRefIdx0:=H4Ue+1; P.NumRefIdx1:=H4Ue+1;
 If (P.NumRefIdx0>32) Or (P.NumRefIdx1>32) Then Exit;
 P.WeightedPred:=H4Bit; P.WeightedBipred:=H4Bits(2);
 P.InitQp:=H4Se+26; P.InitQs:=H4Se+26;
 P.ChromaQpOffset:=H4Se;
 P.DeblockCtrl:=H4Bit; P.ConstrainedIntra:=H4Bit; P.RedundantPicCnt:=H4Bit;
 P.ChromaQpOffset2:=P.ChromaQpOffset;
 Move(H4Sps[Sid].Sl4,P.Sl4,SizeOf(P.Sl4)); Move(H4Sps[Sid].Sl8,P.Sl8,SizeOf(
  P.Sl8));
 If H4MoreData Then Begin
  P.Transform8x8:=H4Bit;
  If H4Bit<>0 Then Begin
   P.ScalingPresent:=1;
   If H4Sps[Sid].ChromaFormat<>3 Then Cnt:=6+2*P.Transform8x8 Else Cnt:=6+6*
    P.Transform8x8;
   H4ParseScaling(@P.Sl4,@P.Sl8,Cnt,H4Sps[Sid].ScalingPresent<>0,@H4Sps[
    Sid].Sl4,@H4Sps[Sid].Sl8);
  End;
  P.ChromaQpOffset2:=H4Se;
 End;
 If H4Err Then Exit;
 P.Valid:=True;
 H4Pps[Id]:=P;
 H4ParsePps:=0;
End;

{ en-tete de tranche ; NalType/NalRef du NAL ; renvoie 0 si ok }
Function H4ParseSlice(Var Sh: TH4Slice; NalType,NalRef: LongInt): LongInt;
Var S: ^TH4Sps; P: ^TH4Pps; I,L,T,Idc,N,Mop: LongInt;
Begin
 H4ParseSlice:=-1;
 FillChar(Sh,SizeOf(Sh),0);
 Sh.NalRefIdc:=NalRef; Sh.Idr:=Ord(NalType=5);
 Sh.FirstMb:=H4Ue;
 T:=H4Ue; If T>9 Then Exit;
 Sh.SliceType:=T Mod 5;
 Sh.PpsId:=H4Ue;
 If Sh.PpsId>255 Then Exit;
 P:=@H4Pps[Sh.PpsId];
 If Not P^.Valid Then Exit;
 S:=@H4Sps[P^.SpsId];
 If Not S^.Valid Then Exit;
 If P^.NumSliceGroups>1 Then Exit;
 Sh.FrameNum:=H4Bits(S^.Log2MaxFrameNum);
 If S^.FrameMbsOnly=0 Then Begin
  Sh.FieldPic:=H4Bit;
  If Sh.FieldPic<>0 Then Sh.BottomField:=H4Bit;
 End;
 If Sh.Idr<>0 Then Sh.IdrPicId:=H4Ue;
 If S^.PocType=0 Then Begin
  Sh.PocLsb:=H4Bits(S^.Log2MaxPocLsb);
  If (P^.BottomFieldPocPresent<>0) And (Sh.FieldPic=0) Then Sh.DeltaPocBottom:=
   H4Se;
 End;
 If (S^.PocType=1) And (S^.DeltaPicOrderAlwaysZero=0) Then Begin
  Sh.DeltaPoc[0]:=H4Se;
  If (P^.BottomFieldPocPresent<>0) And (Sh.FieldPic=0) Then Sh.DeltaPoc[1]:=
   H4Se;
 End;
 If P^.RedundantPicCnt<>0 Then Sh.RedundantPicCnt:=H4Ue;
 If Sh.SliceType=1 Then Sh.DirectSpatial:=H4Bit;
 Sh.NumRef[0]:=0; Sh.NumRef[1]:=0;
 If (Sh.SliceType=0) Or (Sh.SliceType=1) Or (Sh.SliceType=3) Then Begin
  Sh.NumRef[0]:=P^.NumRefIdx0;
  If Sh.SliceType=1 Then Sh.NumRef[1]:=P^.NumRefIdx1;
  If H4Bit<>0 Then Begin
   Sh.NumRef[0]:=H4Ue+1;
   If Sh.SliceType=1 Then Sh.NumRef[1]:=H4Ue+1;
  End;
  If (Sh.NumRef[0]>32) Or (Sh.NumRef[1]>32) Then Exit;
 End;
 { modification des listes }
 For L:=0 To 1 Do Begin
  Sh.ModFlag[L]:=0; Sh.ModCount[L]:=0;
  If ((L=0) And (Sh.SliceType<>2) And (Sh.SliceType<>4)) Or ((L=1) And (
   Sh.SliceType=1)) Then Begin
   Sh.ModFlag[L]:=H4Bit;
   If Sh.ModFlag[L]<>0 Then Begin
    N:=0;
    Repeat
     Idc:=H4Ue;
     If Idc=3 Then Break;
     If (Idc>5) Or (N>=32) Or H4Err Then Exit;
     Sh.ModIdc[L,N]:=Idc; Sh.ModVal[L,N]:=H4Ue; Inc(N);
    Until False;
    Sh.ModCount[L]:=N;
   End;
  End;
 End;
 { table de ponderation }
 If ((P^.WeightedPred<>0) And ((Sh.SliceType=0) Or (Sh.SliceType=3))) Or ((
  P^.WeightedBipred=1) And (Sh.SliceType=1)) Then Begin
  Sh.LumaLog2Wd:=H4Ue; Sh.ChromaLog2Wd:=0;
  If S^.ChromaFormat<>0 Then Sh.ChromaLog2Wd:=H4Ue;
  If (Sh.LumaLog2Wd>7) Or (Sh.ChromaLog2Wd>7) Then Exit;
  For L:=0 To 1 Do Begin
   If (L=1) And (Sh.SliceType<>1) Then Break;
   For I:=0 To Sh.NumRef[L]-1 Do Begin
    Sh.LumaFlag[L,I]:=H4Bit;
    If Sh.LumaFlag[L,I]<>0 Then Begin Sh.LumaW[L,I]:=H4Se; Sh.LumaO[L,I]:=H4Se;
     End
    Else Begin Sh.LumaW[L,I]:=1 Shl Sh.LumaLog2Wd; Sh.LumaO[L,I]:=0; End;
    Sh.ChromaFlag[L,I]:=0;
    If S^.ChromaFormat<>0 Then Sh.ChromaFlag[L,I]:=H4Bit;
    If Sh.ChromaFlag[L,I]<>0 Then Begin
     For N:=0 To 1 Do Begin Sh.ChromaW[L,I,N]:=H4Se; Sh.ChromaO[L,I,N]:=H4Se;
      End;
    End Else Begin
     For N:=0 To 1 Do Begin Sh.ChromaW[L,I,N]:=1 Shl Sh.ChromaLog2Wd;
      Sh.ChromaO[L,I,N]:=0; End;
    End;
   End;
  End;
 End;
 { marquage des references }
 If NalRef<>0 Then Begin
  If Sh.Idr<>0 Then Begin
   Sh.NoOutputPrior:=H4Bit; Sh.LongTermRef:=H4Bit;
  End Else Begin
   Sh.AdaptiveMarking:=H4Bit;
   If Sh.AdaptiveMarking<>0 Then Begin
    N:=0;
    Repeat
     Mop:=H4Ue;
     If Mop=0 Then Break;
     If (Mop>6) Or (N>=64) Or H4Err Then Exit;
     Sh.Mmco[N].Op:=Mop; Sh.Mmco[N].A1:=0; Sh.Mmco[N].A2:=0;
     If (Mop=1) Or (Mop=3) Then Sh.Mmco[N].A1:=H4Ue;
     If Mop=2 Then Sh.Mmco[N].A1:=H4Ue;
     If Mop=3 Then Sh.Mmco[N].A2:=H4Ue
     Else If (Mop=6) Or (Mop=4) Then Sh.Mmco[N].A1:=H4Ue;
     Inc(N);
    Until False;
    Sh.MmcoCount:=N;
   End;
  End;
 End;
 If (P^.Cabac<>0) And (Sh.SliceType<>2) And (Sh.SliceType<>4) Then Begin
  Sh.CabacInitIdc:=H4Ue;
  If Sh.CabacInitIdc>2 Then Exit;
 End;
 Sh.QpDelta:=H4Se;
 Sh.Qp:=P^.InitQp+Sh.QpDelta;
 If (Sh.Qp<0) Or (Sh.Qp>51) Then Exit;
 If (Sh.SliceType=3) Or (Sh.SliceType=4) Then Begin
  If Sh.SliceType=3 Then H4Bit;
  Sh.SliceQs:=P^.InitQs+H4Se;
 End;
 Sh.DisableDeblock:=0; Sh.AlphaOff:=0; Sh.BetaOff:=0;
 If P^.DeblockCtrl<>0 Then Begin
  Sh.DisableDeblock:=H4Ue;
  If Sh.DisableDeblock>2 Then Exit;
  If Sh.DisableDeblock<>1 Then Begin
   Sh.AlphaOff:=H4Se*2; Sh.BetaOff:=H4Se*2;
   If (Sh.AlphaOff<-12) Or (Sh.AlphaOff>12) Or (Sh.BetaOff<-12) Or (
    Sh.BetaOff>12) Then Exit;
  End;
 End;
 If H4Err Then Exit;
 H4ParseSlice:=0;
End;


{ ---- images, DPB, POC, marquage, listes de references ---- }
Type
 TH4Pic=Record
  Used: Boolean;
  Y,U,V: H4PBuf;
  MbType: H4PWordArr;
  Mv: Array[0..1] Of Pointer; Ref: Array[0..1] Of Pointer; RefId: Array[0..1] Of
   Pointer;
  Id,FrameNum,FrameNumWrap,Poc,PocTop,PocBot,LongIdx,RefState: LongInt;
  Output,NonExist,Idr,Mmco5,Cleared: Boolean;
  Pts,Dur: Int64; Seq: LongInt;
  EmL,EmT,EmW,EmH,EmSY,EmSC,EmMat: LongInt;
 End;
Var
 H4Pics: Array[0..H4MaxPics-1] Of TH4Pic;
 H4W,H4H,H4MbW,H4MbH,H4MbNum,H4StrideY,H4StrideC,H4Seq: LongInt;
 H4ActSps: LongInt;
 H4Cur: LongInt;
 H4NextId: LongInt;
 { etat POC / numerotation }
 H4PrevPocMsb,H4PrevPocLsb,H4PrevFrameNumOffset,H4FrameNumOffset,H4PrevFrameNum,
  H4PrevRefFrameNum: LongInt;
 H4PrevHadMmco5: Boolean; H4MaxLongIdx: LongInt;
 H4CurSh: TH4Slice;
 H4FirstSh: TH4Slice;
 H4Started: Boolean;
 H4RefList: Array[0..1,0..32] Of LongInt;   { indices dans H4Pics, -1 si vide }
 H4RefCount: Array[0..1] Of LongInt;
 H4OutQueue: Array[0..H4MaxPics-1] Of LongInt; H4OutCount: LongInt;
 H4ReorderDepth: LongInt;

Procedure H4FreePic(I: LongInt);
Begin
 With H4Pics[I] Do Begin
  If Used Then Begin
   FreeMem(Y); FreeMem(U); FreeMem(V); FreeMem(MbType);
   FreeMem(Mv[0]); FreeMem(Mv[1]); FreeMem(Ref[0]); FreeMem(Ref[1]); FreeMem(
    RefId[0]); FreeMem(RefId[1]);
  End;
  Used:=False;
 End;
End;
Procedure H4FreeAll;
Var I: LongInt;
Begin
 For I:=0 To H4MaxPics-1 Do H4FreePic(I);
 H4OutCount:=0;
End;

{ nouvelle image : renvoie l'indice }
Function H4NewPic: LongInt;
Var I,J,Best: LongInt; Busy: Boolean;
Begin
 Best:=-1;
 For I:=0 To H4MaxPics-1 Do Begin
  Busy:=False;
  If H4Pics[I].Used Then Begin
   If (H4Pics[I].RefState<>0) Or H4Pics[I].Output Then Busy:=True;
   If I=H4Cur Then Busy:=True;
  End;
  If Not Busy Then Begin Best:=I; Break; End;
 End;
 If Best<0 Then Begin H4NewPic:=-1; Exit; End;
 With H4Pics[Best] Do Begin
  If Not Used Then Begin
   GetMem(Y,H4StrideY*H4MbH*16+64); GetMem(U,H4StrideC*H4MbH*8+64); GetMem(V,
    H4StrideC*H4MbH*8+64);
   GetMem(MbType,H4MbNum*2+16);
   For J:=0 To 1 Do Begin
    GetMem(Mv[J],H4MbNum*64+16); GetMem(Ref[J],H4MbNum*4+16); GetMem(RefId[J],
     H4MbNum*16+16);
   End;
   Used:=True;
  End;
  FillChar(MbType^,H4MbNum*2,0);
  For J:=0 To 1 Do Begin FillChar(Mv[J]^,H4MbNum*64,0); FillChar(Ref[J]^,
   H4MbNum*4,255); FillChar(RefId[J]^,H4MbNum*16,255); End;
  Id:=H4NextId; Inc(H4NextId);
  RefState:=0; Output:=False; NonExist:=False; Idr:=False; Mmco5:=False;
   LongIdx:=-1; Pts:=0; Poc:=0; PocTop:=0; PocBot:=0; FrameNum:=0;
   FrameNumWrap:=0;
  Seq:=H4Seq;
 End;
 H4NewPic:=Best;
End;

{ ---- POC (8.2.1) ---- }
Procedure H4ComputePoc(Var Sh: TH4Slice; Var S: TH4Sps; Var Top,Bot: LongInt);
Var Msb,Lsb,MaxLsb,I,AbsFn,CycleCnt,InCycle,Exp,DeltaCycle,Tmp,MaxFn: LongInt;
Begin
 MaxFn:=1 Shl S.Log2MaxFrameNum;
 If S.PocType=0 Then Begin
  MaxLsb:=1 Shl S.Log2MaxPocLsb;
  If Sh.Idr<>0 Then Begin H4PrevPocMsb:=0; H4PrevPocLsb:=0; End
  Else If H4PrevHadMmco5 Then Begin H4PrevPocMsb:=0; End;
  Lsb:=Sh.PocLsb;
  If (Lsb<H4PrevPocLsb) And (H4PrevPocLsb-Lsb>=MaxLsb Div 2) Then Msb:=
   H4PrevPocMsb+MaxLsb
  Else If (Lsb>H4PrevPocLsb) And (Lsb-H4PrevPocLsb>MaxLsb Div 2) Then Msb:=
   H4PrevPocMsb-MaxLsb
  Else Msb:=H4PrevPocMsb;
  Top:=Msb+Lsb; Bot:=Top+Sh.DeltaPocBottom;
  If Sh.NalRefIdc<>0 Then Begin H4PrevPocMsb:=Msb; H4PrevPocLsb:=Lsb; End;
 End Else Begin
  If Sh.Idr<>0 Then H4FrameNumOffset:=0
  Else Begin
   If H4PrevHadMmco5 Then H4PrevFrameNumOffset:=0;
   If H4PrevFrameNum>Sh.FrameNum Then H4FrameNumOffset:=H4PrevFrameNumOffset+
    MaxFn Else H4FrameNumOffset:=H4PrevFrameNumOffset;
  End;
  If S.PocType=1 Then Begin
   If S.PocCycleLength<>0 Then AbsFn:=H4FrameNumOffset+Sh.FrameNum Else AbsFn:=
    0;
   If (Sh.NalRefIdc=0) And (AbsFn>0) Then Dec(AbsFn);
   Exp:=0;
   If AbsFn>0 Then Begin
    CycleCnt:=(AbsFn-1) Div S.PocCycleLength; InCycle:=(AbsFn-1) Mod
     S.PocCycleLength;
    DeltaCycle:=0; For I:=0 To S.PocCycleLength-1 Do Inc(DeltaCycle,
     S.OffsetForRefFrame[I]);
    Exp:=CycleCnt*DeltaCycle;
    For I:=0 To InCycle Do Inc(Exp,S.OffsetForRefFrame[I]);
   End;
   If Sh.NalRefIdc=0 Then Inc(Exp,S.OffsetForNonRefPic);
   Top:=Exp+Sh.DeltaPoc[0];
   Bot:=Top+S.OffsetForTopToBottom+Sh.DeltaPoc[1];
  End Else Begin
   If Sh.Idr<>0 Then Tmp:=0
   Else If Sh.NalRefIdc=0 Then Tmp:=2*(H4FrameNumOffset+Sh.FrameNum)-1
   Else Tmp:=2*(H4FrameNumOffset+Sh.FrameNum);
   Top:=Tmp; Bot:=Tmp;
  End;
 End;
End;

{ ---- sortie ---- }
Var H4Sink: Pointer;
Procedure H4EmitPic(I: LongInt); Forward;
Procedure H4Bump(Flush: Boolean);
Var I,J,Best: LongInt; T: LongInt;
Begin
 While H4OutCount>0 Do Begin
  If (Not Flush) And (H4OutCount<=H4ReorderDepth) Then Break;
  Best:=0;
  For J:=1 To H4OutCount-1 Do
   If H4Pics[H4OutQueue[J]].Poc<H4Pics[H4OutQueue[Best]].Poc Then Best:=J;
  T:=H4OutQueue[Best];
  For J:=Best To H4OutCount-2 Do H4OutQueue[J]:=H4OutQueue[J+1];
  Dec(H4OutCount);
  H4Pics[T].Output:=False;
  If Not H4Pics[T].NonExist Then H4EmitPic(T);
 End;
End;

{ ---- marquage des references (8.2.5) ---- }
Procedure H4Unmark(I: LongInt);
Begin
 H4Pics[I].RefState:=0; H4Pics[I].LongIdx:=-1;
End;
Procedure H4Marking(Var Sh: TH4Slice; Var S: TH4Sps; Cur: LongInt);
Var I,J,N,MaxFn,CurNum,PicX,Op,A1,A2,NShort,NLong,Oldest,Mn: LongInt; Mark5:
 Boolean;
Begin
 MaxFn:=1 Shl S.Log2MaxFrameNum;
 H4Pics[Cur].Mmco5:=False;
 If Sh.NalRefIdc=0 Then Exit;
 If Sh.Idr<>0 Then Begin
  For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) Then H4Unmark(I);
  If Sh.LongTermRef<>0 Then Begin H4Pics[Cur].RefState:=2; H4Pics[Cur].LongIdx:=
   0; H4MaxLongIdx:=0; End
  Else Begin H4Pics[Cur].RefState:=1; H4MaxLongIdx:=-1; End;
  Exit;
 End;
 CurNum:=Sh.FrameNum;
 For I:=0 To H4MaxPics-1 Do
  If H4Pics[I].Used And (H4Pics[I].RefState=1) Then Begin
   If H4Pics[I].FrameNum>Sh.FrameNum Then H4Pics[I].FrameNumWrap:=H4Pics[
    I].FrameNum-MaxFn Else H4Pics[I].FrameNumWrap:=H4Pics[I].FrameNum;
  End;
 Mark5:=False;
 If Sh.AdaptiveMarking<>0 Then Begin
  For N:=0 To Sh.MmcoCount-1 Do Begin
   Op:=Sh.Mmco[N].Op; A1:=Sh.Mmco[N].A1; A2:=Sh.Mmco[N].A2;
   Case Op Of
    1: Begin
     PicX:=CurNum-(A1+1);
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (I<>Cur) And (H4Pics[I].RefState=1) And (H4Pics[
       I].FrameNumWrap=PicX) Then H4Unmark(I);
    End;
    2: For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (H4Pics[I].RefState=2) And (H4Pics[I].LongIdx=A1)
       Then H4Unmark(I);
    3: Begin
     PicX:=CurNum-(A1+1);
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (H4Pics[I].RefState=2) And (H4Pics[I].LongIdx=A2)
       Then H4Unmark(I);
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (I<>Cur) And (H4Pics[I].RefState=1) And (H4Pics[
       I].FrameNumWrap=PicX) Then Begin
       H4Pics[I].RefState:=2; H4Pics[I].LongIdx:=A2;
      End;
    End;
    4: Begin
     H4MaxLongIdx:=A1-1;
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (H4Pics[I].RefState=2) And (H4Pics[
       I].LongIdx>H4MaxLongIdx) Then H4Unmark(I);
    End;
    5: Begin
     For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) Then H4Unmark(I);
     H4MaxLongIdx:=-1; Mark5:=True;
    End;
    6: Begin
     For I:=0 To H4MaxPics-1 Do
      If H4Pics[I].Used And (I<>Cur) And (H4Pics[I].RefState=2) And (H4Pics[
       I].LongIdx=A1) Then H4Unmark(I);
     H4Pics[Cur].RefState:=2; H4Pics[Cur].LongIdx:=A1;
    End;
   End;
  End;
 End Else Begin
  { fenetre glissante }
  NShort:=0; NLong:=0;
  For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) Then Begin
   If H4Pics[I].RefState=1 Then Inc(NShort) Else If H4Pics[I].RefState=2 Then
    Inc(NLong);
  End;
  N:=S.RefFrameCount; If N<1 Then N:=1;
  If NShort+NLong>=N Then Begin
   Oldest:=-1; Mn:=High(LongInt);
   For I:=0 To H4MaxPics-1 Do
    If H4Pics[I].Used And (I<>Cur) And (H4Pics[I].RefState=1) And (H4Pics[
     I].FrameNumWrap<Mn) Then Begin Mn:=H4Pics[I].FrameNumWrap; Oldest:=I; End;
   If Oldest>=0 Then H4Unmark(Oldest);
  End;
 End;
 If H4Pics[Cur].RefState<>2 Then Begin H4Pics[Cur].RefState:=1; End;
 If Mark5 Then Begin H4Pics[Cur].Mmco5:=True; End;
End;

{ ---- listes de references (8.2.4) ---- }
Procedure H4BuildRefLists(Var Sh: TH4Slice; Var S: TH4Sps; Cur: LongInt);
Var I,J,K,L,N,MaxFn,CurNum,Pred,NoWrap,PicNum,Target,Cnt: LongInt; Tmp: Array[
 0..39] Of LongInt; Sh2: Array[0..39] Of LongInt;
 Short0,Short1,Long0: Array[0..39] Of LongInt; NS0,NS1,NL: LongInt; Key: Array[
  0..39] Of LongInt; Found: Boolean; Lst: Array[0..39] Of LongInt; Fill:
  LongInt;
 CurPoc: LongInt;
Procedure SortBy(Var A: Array Of LongInt; Cnt: LongInt; Desc: Boolean; Mode:
 LongInt);
Var P,Q,T,Ka,Kb: LongInt;
Begin
 For P:=0 To Cnt-2 Do For Q:=P+1 To Cnt-1 Do Begin
  If Mode=0 Then Begin Ka:=H4Pics[A[P]].FrameNumWrap; Kb:=H4Pics[A[
   Q]].FrameNumWrap; End
  Else If Mode=1 Then Begin Ka:=H4Pics[A[P]].Poc; Kb:=H4Pics[A[Q]].Poc; End
  Else Begin Ka:=H4Pics[A[P]].LongIdx; Kb:=H4Pics[A[Q]].LongIdx; End;
  If (Desc And (Kb>Ka)) Or ((Not Desc) And (Kb<Ka)) Then Begin T:=A[P]; A[P]:=A[
   Q]; A[Q]:=T; End;
 End;
End;
Begin
 MaxFn:=1 Shl S.Log2MaxFrameNum; CurNum:=Sh.FrameNum; CurPoc:=H4Pics[Cur].Poc;
 For L:=0 To 1 Do For I:=0 To 32 Do H4RefList[L,I]:=-1;
 H4RefCount[0]:=Sh.NumRef[0]; H4RefCount[1]:=Sh.NumRef[1];
 If (Sh.SliceType=2) Or (Sh.SliceType=4) Then Exit;
 For I:=0 To H4MaxPics-1 Do
  If H4Pics[I].Used And (H4Pics[I].RefState=1) Then Begin
   If H4Pics[I].FrameNum>Sh.FrameNum Then H4Pics[I].FrameNumWrap:=H4Pics[
    I].FrameNum-MaxFn Else H4Pics[I].FrameNumWrap:=H4Pics[I].FrameNum;
  End;
 NL:=0;
 For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) And (H4Pics[
  I].RefState=2) Then Begin Long0[NL]:=I; Inc(NL); End;
 SortBy(Long0,NL,False,2);
 If Sh.SliceType<>1 Then Begin
  NS0:=0;
  For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) And (H4Pics[
   I].RefState=1) Then Begin Short0[NS0]:=I; Inc(NS0); End;
  SortBy(Short0,NS0,True,0);
  K:=0; For I:=0 To NS0-1 Do Begin H4RefList[0,K]:=Short0[I]; Inc(K); End;
  For I:=0 To NL-1 Do Begin H4RefList[0,K]:=Long0[I]; Inc(K); End;
  Cnt:=K;
 End Else Begin
  { B : liste 0 : POC inferieurs decroissants puis superieurs croissants }
  NS0:=0; NS1:=0;
  For I:=0 To H4MaxPics-1 Do If H4Pics[I].Used And (I<>Cur) And (H4Pics[
   I].RefState=1) Then Begin
   If H4Pics[I].Poc<=CurPoc Then Begin Short0[NS0]:=I; Inc(NS0); End Else Begin
    Short1[NS1]:=I; Inc(NS1); End;
  End;
  SortBy(Short0,NS0,True,1); SortBy(Short1,NS1,False,1);
  K:=0;
  For I:=0 To NS0-1 Do Begin H4RefList[0,K]:=Short0[I]; Inc(K); End;
  For I:=0 To NS1-1 Do Begin H4RefList[0,K]:=Short1[I]; Inc(K); End;
  For I:=0 To NL-1 Do Begin H4RefList[0,K]:=Long0[I]; Inc(K); End;
  Cnt:=K;
  K:=0;
  For I:=0 To NS1-1 Do Begin H4RefList[1,K]:=Short1[I]; Inc(K); End;
  For I:=0 To NS0-1 Do Begin H4RefList[1,K]:=Short0[I]; Inc(K); End;
  For I:=0 To NL-1 Do Begin H4RefList[1,K]:=Long0[I]; Inc(K); End;
  If (K>1) Then Begin
   Found:=True;
   For I:=0 To K-1 Do If H4RefList[0,I]<>H4RefList[1,I] Then Found:=False;
   If Found Then Begin I:=H4RefList[1,0]; H4RefList[1,0]:=H4RefList[1,1];
    H4RefList[1,1]:=I; End;
  End;
  N:=K;
 End;
 { modification }
 For L:=0 To 1 Do Begin
  If (L=1) And (Sh.SliceType<>1) Then Break;
  If Sh.ModFlag[L]<>0 Then Begin
   Pred:=CurNum; K:=0;
   For I:=0 To Sh.ModCount[L]-1 Do Begin
    If Sh.ModIdc[L,I]<2 Then Begin
     If Sh.ModIdc[L,I]=0 Then Begin
      NoWrap:=Pred-(Sh.ModVal[L,I]+1); If NoWrap<0 Then Inc(NoWrap,MaxFn);
     End Else Begin
      NoWrap:=Pred+(Sh.ModVal[L,I]+1); If NoWrap>=MaxFn Then Dec(NoWrap,MaxFn);
     End;
     Pred:=NoWrap;
     If NoWrap>CurNum Then PicNum:=NoWrap-MaxFn Else PicNum:=NoWrap;
     Target:=-1;
     For J:=0 To H4MaxPics-1 Do If H4Pics[J].Used And (J<>Cur) And (H4Pics[
      J].RefState=1) And (H4Pics[J].FrameNumWrap=PicNum) Then Target:=J;
    End Else Begin
     Target:=-1;
     For J:=0 To H4MaxPics-1 Do If H4Pics[J].Used And (J<>Cur) And (H4Pics[
      J].RefState=2) And (H4Pics[J].LongIdx=Sh.ModVal[L,I]) Then Target:=J;
    End;
    If K<33 Then Begin
     { insertion en position K, decalage, suppression du doublon }
     For J:=32 DownTo K+1 Do H4RefList[L,J]:=H4RefList[L,J-1];
     H4RefList[L,K]:=Target; Inc(K);
     N:=K;
     For J:=K To 32 Do If H4RefList[L,J]<>Target Then Begin H4RefList[L,N]:=
      H4RefList[L,J]; Inc(N); End;
     For J:=N To 32 Do H4RefList[L,J]:=-1;
    End;
   End;
  End;
 End;
 { remplissage des entrees absentes par la premiere reference (comme ffmpeg) }
 For L:=0 To 1 Do Begin
  If (L=1) And (Sh.SliceType<>1) Then Break;
  Fill:=-1;
  For I:=0 To Sh.NumRef[L]-1 Do If H4RefList[L,I]>=0 Then Begin Fill:=H4RefList[
   L,I]; Break; End;
  For I:=0 To Sh.NumRef[L]-1 Do If H4RefList[L,I]<0 Then H4RefList[L,I]:=Fill;
 End;
End;


{ ---- CAVLC ---- }
Type
 TH4Vlc=Record Bits: LongInt; T: PWord; End;
Var
 H4CoeffTok: Array[0..2] Of TH4Vlc;       { nC 0-1, 2-3, 4-7 }
 H4ChromaDcTok,H4Chroma422Tok: TH4Vlc;
 H4TotZeros: Array[1..15] Of TH4Vlc;
 H4ChromaDcZeros: Array[1..3] Of TH4Vlc;
 H4Chroma422Zeros: Array[1..7] Of TH4Vlc;
 H4RunBefore: Array[1..7] Of TH4Vlc;
 H4TabsReady: Boolean;

{ construit une table de decodage : entree = (symbole shl 5) or longueur }
Procedure H4MakeVlc(Var V: TH4Vlc; N: LongInt; Lens,Codes: H4PBuf; Stride:
 LongInt; MaxBits: LongInt);
Var I,J,L,C,Cnt: LongInt;
Begin
 V.Bits:=MaxBits; Cnt:=1 Shl MaxBits;
 GetMem(V.T,Cnt*2);
 FillChar(V.T^,Cnt*2,0);
 For I:=0 To N-1 Do Begin
  L:=Lens^[I*Stride]; C:=Codes^[I*Stride];
  If L=0 Then Continue;
  For J:=0 To (1 Shl (MaxBits-L))-1 Do
   H4PWordArr(V.T)^[(C Shl (MaxBits-L))+J]:=(I Shl 5) Or L;
 End;
End;
Function H4GetVlc(Var V: TH4Vlc): LongInt;
Var E: Word; P: Int64;
Begin
 P:=H4Peek32;
 E:=H4PWordArr(V.T)^[P Shr (32-V.Bits)];
 If (E And 31)=0 Then Begin H4Err:=True; H4GetVlc:=-1; Exit; End;
 Inc(H4Pos,E And 31);
 H4GetVlc:=E Shr 5;
End;
Procedure H4InitTabs;
Var I,J: LongInt; Len1,Cod1: Array[0..255] Of Byte; N: LongInt;
Begin
 If H4TabsReady Then Exit;
 For I:=0 To 2 Do H4MakeVlc(H4CoeffTok[I],68,@H4CoeffTokenLen[I*68],
  @H4CoeffTokenBits[I*68],1,16);
 H4MakeVlc(H4ChromaDcTok,20,@H4ChromaDcCoeffTokenLen,@H4ChromaDcCoeffTokenBits,
  1,8);
 H4MakeVlc(H4Chroma422Tok,36,@H4Chroma422DcCoeffTokenLen,
  @H4Chroma422DcCoeffTokenBits,1,13);
 For I:=1 To 15 Do H4MakeVlc(H4TotZeros[I],16,@H4TotalZerosLen[(I-1)*16],
  @H4TotalZerosBits[(I-1)*16],1,9);
 For I:=1 To 3 Do H4MakeVlc(H4ChromaDcZeros[I],4,@H4ChromaDcTotalZerosLen[(I-1)*
  4],@H4ChromaDcTotalZerosBits[(I-1)*4],1,3);
 For I:=1 To 7 Do H4MakeVlc(H4Chroma422Zeros[I],8,@H4Chroma422DcTotalZerosLen[(
  I-1)*8],@H4Chroma422DcTotalZerosBits[(I-1)*8],1,5);
 For I:=1 To 7 Do H4MakeVlc(H4RunBefore[I],16,@H4RunLen[(I-1)*16],@H4RunBits[(I-
  1)*16],1,11);
 H4TabsReady:=True;
End;

{ libere les tables VLC (reconstruites a la prochaine utilisation) }
Procedure H4FreeVlcs;
Var I: LongInt;
Procedure F1(Var V: TH4Vlc);
Begin
 If V.T<>Nil Then FreeMem(V.T);
 V.T:=Nil;
End;
Begin
 If Not H4TabsReady Then Exit;
 For I:=0 To 2 Do F1(H4CoeffTok[I]);
 F1(H4ChromaDcTok); F1(H4Chroma422Tok);
 For I:=1 To 15 Do F1(H4TotZeros[I]);
 For I:=1 To 3 Do F1(H4ChromaDcZeros[I]);
 For I:=1 To 7 Do F1(H4Chroma422Zeros[I]);
 For I:=1 To 7 Do F1(H4RunBefore[I]);
 H4TabsReady:=False;
End;

{ residu CAVLC d'un bloc : renvoie TotalCoeff (ou -3 si erreur) ; Lev recoit les
 niveaux par position de balayage (0..MaxCoeff-1)
  NC = -1 : DC chroma 4:2:0 ; -2 : DC chroma 4:2:2 ; sinon contexte nC }
Function H4CavlcBlock(Var Lev: Array Of LongInt; MaxCoeff,NC: LongInt): LongInt;
Var Tok,Total,T1,I,Suffix,Prefix,LevelCode,SufSize,ZerosLeft,Coeff,Idx,Lv:
 LongInt;
 Vals,RunV: Array[0..15] Of LongInt; Vl: ^TH4Vlc;
Begin
 For I:=0 To MaxCoeff-1 Do Lev[I]:=0;
 H4CavlcBlock:=0;
 If NC=-1 Then Tok:=H4GetVlc(H4ChromaDcTok)
 Else If NC=-2 Then Tok:=H4GetVlc(H4Chroma422Tok)
 Else If NC>=8 Then Begin
  Tok:=H4Bits(6);
  If Tok=3 Then Tok:=0 Else Tok:=((Tok Shr 2)+1)*4+(Tok And 3);
 End Else Begin
  If NC<2 Then Idx:=0 Else If NC<4 Then Idx:=1 Else Idx:=2;
  Tok:=H4GetVlc(H4CoeffTok[Idx]);
 End;
 If Tok<0 Then Begin H4CavlcBlock:=-3; Exit; End;
 Total:=Tok Shr 2; T1:=Tok And 3;
 If Total=0 Then Exit;
 If Total>MaxCoeff Then Begin H4Err:=True; H4CavlcBlock:=-3; Exit; End;
 If (Total>10) And (T1<3) Then Suffix:=1 Else Suffix:=0;
 For I:=0 To Total-1 Do Begin
  If I<T1 Then Begin
   If H4Bit<>0 Then Vals[I]:=-1 Else Vals[I]:=1;
  End Else Begin
   Prefix:=0;
   While (H4Bit=0) And (Prefix<32) Do Inc(Prefix);
   If Prefix>=32 Then Begin H4Err:=True; H4CavlcBlock:=-3; Exit; End;
   If (Prefix=14) And (Suffix=0) Then SufSize:=4
   Else If Prefix>=15 Then SufSize:=Prefix-3
   Else SufSize:=Suffix;
   If Prefix<15 Then LevelCode:=Prefix Shl Suffix Else LevelCode:=15 Shl Suffix;
   If SufSize>0 Then Inc(LevelCode,H4Bits(SufSize));
   If (Prefix>=15) And (Suffix=0) Then Inc(LevelCode,15);
   If Prefix>=16 Then Inc(LevelCode,(1 Shl (Prefix-3))-4096);
   If (I=T1) And (T1<3) Then Inc(LevelCode,2);
   If (LevelCode And 1)=0 Then Lv:=(LevelCode+2) Shr 1 Else Lv:=(-LevelCode-1)
    Div 2;
   If Suffix=0 Then Suffix:=1;
   If (Abs(Lv)>(3 Shl (Suffix-1))) And (Suffix<6) Then Inc(Suffix);
   Vals[I]:=Lv;
  End;
 End;
 If Total<MaxCoeff Then Begin
  If NC=-1 Then Vl:=@H4ChromaDcZeros[Total]
  Else If NC=-2 Then Vl:=@H4Chroma422Zeros[Total]
  Else Vl:=@H4TotZeros[Total];
  ZerosLeft:=H4GetVlc(Vl^);
  If ZerosLeft<0 Then Begin H4CavlcBlock:=-3; Exit; End;
 End Else ZerosLeft:=0;
 For I:=0 To Total-2 Do Begin
  If ZerosLeft>0 Then Begin
   Idx:=ZerosLeft; If Idx>7 Then Idx:=7;
   RunV[I]:=H4GetVlc(H4RunBefore[Idx]);
   If RunV[I]<0 Then Begin H4CavlcBlock:=-3; Exit; End;
   Dec(ZerosLeft,RunV[I]);
   If ZerosLeft<0 Then Begin H4Err:=True; H4CavlcBlock:=-3; Exit; End;
  End Else RunV[I]:=0;
 End;
 RunV[Total-1]:=ZerosLeft;
 Coeff:=-1;
 For I:=Total-1 DownTo 0 Do Begin
  Inc(Coeff,RunV[I]+1);
  If Coeff>=MaxCoeff Then Begin H4Err:=True; H4CavlcBlock:=-3; Exit; End;
  Lev[Coeff]:=Vals[I];
 End;
 H4CavlcBlock:=Total;
End;


{ ---- prediction intra et transformees ---- }
Function H4Sar(V: LongInt; N: LongInt): LongInt;
Begin If V>=0 Then H4Sar:=V Shr N Else H4Sar:=-((-V+(1 Shl N)-1) Shr N); End;
Function H4Clip(V: LongInt): LongInt;
Begin If V<0 Then H4Clip:=0 Else If V>255 Then H4Clip:=255 Else H4Clip:=V; End;
Function H4Clip3(Lo,Hi,V: LongInt): LongInt;
Begin If V<Lo Then H4Clip3:=Lo Else If V>Hi Then H4Clip3:=Hi Else H4Clip3:=V;
 End;

{ le mode de prediction intra demande est-il realisable avec les voisins
 disponibles ? }
Function H4OkMode(Mode: LongInt; L,T,TL: Boolean): Boolean;
Begin
 Case Mode Of
  0,3,7: H4OkMode:=T;
  1,8: H4OkMode:=L;
  2: H4OkMode:=True;
 Else H4OkMode:=L And T And TL;
 End;
End;
Function H4OkMode16(Mode: LongInt; L,T,TL: Boolean): Boolean;
Begin
 Case Mode Of
  0: H4OkMode16:=T;
  1: H4OkMode16:=L;
  2: H4OkMode16:=True;
 Else H4OkMode16:=L And T And TL;
 End;
End;
Function H4OkModeC(Mode: LongInt; L,T,TL: Boolean): Boolean;
Begin
 Case Mode Of
  0: H4OkModeC:=True;
  1: H4OkModeC:=L;
  2: H4OkModeC:=T;
 Else H4OkModeC:=L And T And TL;
 End;
End;

Procedure H4Pred4x4(Pl: H4PBuf; Stride,X,Y,Mode: LongInt; AvL,AvT,AvTR,AvTL:
 Boolean);
Var T: Array[0..7] Of LongInt; L: Array[0..3] Of LongInt; Tl,I,J,Z,Sum,V,Q:
 LongInt; E: Array[0..8] Of LongInt; Pr: Array[0..3,0..3] Of LongInt;
Function Tt(Idx: LongInt): LongInt; { Idx -1 = coin }
Begin If Idx<0 Then Tt:=Tl Else Tt:=T[Idx]; End;
Function Ll(Idx: LongInt): LongInt;
Begin If Idx<0 Then Ll:=Tl Else Ll:=L[Idx]; End;
Begin
 If AvT Then Begin
  For I:=0 To 3 Do T[I]:=Pl^[(Y-1)*Stride+X+I];
  If AvTR Then For I:=4 To 7 Do T[I]:=Pl^[(Y-1)*Stride+X+I] Else For I:=4 To 7
   Do T[I]:=T[3];
 End;
 If AvL Then For I:=0 To 3 Do L[I]:=Pl^[(Y+I)*Stride+X-1];
 If AvTL Then Tl:=Pl^[(Y-1)*Stride+X-1];
 Case Mode Of
  0: For J:=0 To 3 Do For I:=0 To 3 Do Pr[J,I]:=T[I];
  1: For J:=0 To 3 Do For I:=0 To 3 Do Pr[J,I]:=L[J];
  2: Begin
   If AvT And AvL Then V:=(T[0]+T[1]+T[2]+T[3]+L[0]+L[1]+L[2]+L[3]+4) Shr 3
   Else If AvL Then V:=(L[0]+L[1]+L[2]+L[3]+2) Shr 2
   Else If AvT Then V:=(T[0]+T[1]+T[2]+T[3]+2) Shr 2
   Else V:=128;
   For J:=0 To 3 Do For I:=0 To 3 Do Pr[J,I]:=V;
  End;
  3: For J:=0 To 3 Do For I:=0 To 3 Do
      If (I=3) And (J=3) Then Pr[J,I]:=(T[6]+3*T[7]+2) Shr 2
      Else Pr[J,I]:=(T[I+J]+2*T[I+J+1]+T[I+J+2]+2) Shr 2;
  4: Begin
   E[0]:=L[3]; E[1]:=L[2]; E[2]:=L[1]; E[3]:=L[0]; E[4]:=Tl; E[5]:=T[0]; E[6]:=
    T[1]; E[7]:=T[2]; E[8]:=T[3];
   For J:=0 To 3 Do For I:=0 To 3 Do
    Pr[J,I]:=(E[4+I-J-1]+2*E[4+I-J]+E[4+I-J+1]+2) Shr 2;
  End;
  5: For J:=0 To 3 Do For I:=0 To 3 Do Begin
      Z:=2*I-J;
      If Z>=0 Then Begin
       If (Z And 1)=0 Then Pr[J,I]:=(Tt(I-(J Shr 1)-1)+Tt(I-(J Shr 1))+1) Shr 1
       Else Pr[J,I]:=(Tt(I-(J Shr 1)-2)+2*Tt(I-(J Shr 1)-1)+Tt(I-(J Shr 1))+2)
        Shr 2;
      End Else If Z=-1 Then Pr[J,I]:=(L[0]+2*Tl+T[0]+2) Shr 2
      Else Pr[J,I]:=(Ll(J-1)+2*Ll(J-2)+Ll(J-3)+2) Shr 2;
     End;
  6: For J:=0 To 3 Do For I:=0 To 3 Do Begin
      Z:=2*J-I;
      If Z>=0 Then Begin
       If (Z And 1)=0 Then Pr[J,I]:=(Ll(J-(I Shr 1)-1)+Ll(J-(I Shr 1))+1) Shr 1
       Else Pr[J,I]:=(Ll(J-(I Shr 1)-2)+2*Ll(J-(I Shr 1)-1)+Ll(J-(I Shr 1))+2)
        Shr 2;
      End Else If Z=-1 Then Pr[J,I]:=(L[0]+2*Tl+T[0]+2) Shr 2
      Else Pr[J,I]:=(Tt(I-1)+2*Tt(I-2)+Tt(I-3)+2) Shr 2;
     End;
  7: For J:=0 To 3 Do For I:=0 To 3 Do Begin
      If (J And 1)=0 Then Pr[J,I]:=(T[I+(J Shr 1)]+T[I+(J Shr 1)+1]+1) Shr 1
      Else Pr[J,I]:=(T[I+(J Shr 1)]+2*T[I+(J Shr 1)+1]+T[I+(J Shr 1)+2]+2) Shr
       2;
     End;
  8: For J:=0 To 3 Do For I:=0 To 3 Do Begin
      Z:=I+2*J;
      If Z>5 Then Pr[J,I]:=L[3]
      Else If Z=5 Then Pr[J,I]:=(L[2]+3*L[3]+2) Shr 2
      Else If (Z And 1)=0 Then Pr[J,I]:=(L[J+(I Shr 1)]+L[J+(I Shr 1)+1]+1) Shr
       1
      Else Pr[J,I]:=(L[J+(I Shr 1)]+2*L[J+(I Shr 1)+1]+L[J+(I Shr 1)+2]+2) Shr
       2;
     End;
 End;
 For J:=0 To 3 Do For I:=0 To 3 Do Pl^[(Y+J)*Stride+X+I]:=Pr[J,I];
End;

{ prediction 8x8 avec filtrage des echantillons de reference (8.3.2.2) }
Procedure H4Pred8x8(Pl: H4PBuf; Stride,X,Y,Mode: LongInt; AvL,AvT,AvTR,AvTL:
 Boolean);
Var P: Array[-1..15] Of LongInt;   { haut : P[0..15] ; coin : P[-1] }
 Q: Array[0..7] Of LongInt;         { gauche filtre/brut }
 F: Array[-1..15] Of LongInt; G: Array[0..7] Of LongInt; Lr: Array[0..7] Of
  LongInt;
 Ftl: LongInt; I,J,Z,V,Sum: LongInt; Pr: Array[0..7,0..7] Of LongInt;
 Raw: Array[0..15] Of LongInt; Lraw: Array[0..7] Of LongInt; Tlraw: LongInt;
Function Ft(Idx: LongInt): LongInt; Begin If Idx<0 Then Ft:=Ftl Else Ft:=F[Idx];
 End;
Function Gl(Idx: LongInt): LongInt; Begin If Idx<0 Then Gl:=Ftl Else Gl:=G[Idx];
 End;
Begin
 If AvT Then Begin
  For I:=0 To 7 Do Raw[I]:=Pl^[(Y-1)*Stride+X+I];
  If AvTR Then For I:=8 To 15 Do Raw[I]:=Pl^[(Y-1)*Stride+X+I] Else For I:=8 To
   15 Do Raw[I]:=Raw[7];
 End;
 If AvL Then For I:=0 To 7 Do Lraw[I]:=Pl^[(Y+I)*Stride+X-1];
 If AvTL Then Tlraw:=Pl^[(Y-1)*Stride+X-1];
 { filtrage }
 If AvT Then Begin
  If AvTL Then F[0]:=(Tlraw+2*Raw[0]+Raw[1]+2) Shr 2 Else F[0]:=(3*Raw[0]+Raw[
   1]+2) Shr 2;
  For I:=1 To 14 Do F[I]:=(Raw[I-1]+2*Raw[I]+Raw[I+1]+2) Shr 2;
  F[15]:=(Raw[14]+3*Raw[15]+2) Shr 2;
 End;
 If AvTL Then Begin
  If AvT And AvL Then Ftl:=(Raw[0]+2*Tlraw+Lraw[0]+2) Shr 2
  Else If AvT Then Ftl:=(3*Tlraw+Raw[0]+2) Shr 2
  Else If AvL Then Ftl:=(3*Tlraw+Lraw[0]+2) Shr 2
  Else Ftl:=Tlraw;
 End;
 If AvL Then Begin
  If AvTL Then G[0]:=(Tlraw+2*Lraw[0]+Lraw[1]+2) Shr 2 Else G[0]:=(3*Lraw[0]+
   Lraw[1]+2) Shr 2;
  For I:=1 To 6 Do G[I]:=(Lraw[I-1]+2*Lraw[I]+Lraw[I+1]+2) Shr 2;
  G[7]:=(Lraw[6]+3*Lraw[7]+2) Shr 2;
 End;
 Case Mode Of
  0: For J:=0 To 7 Do For I:=0 To 7 Do Pr[J,I]:=F[I];
  1: For J:=0 To 7 Do For I:=0 To 7 Do Pr[J,I]:=G[J];
  2: Begin
   Sum:=0;
   If AvT And AvL Then Begin For I:=0 To 7 Do Inc(Sum,F[I]+G[I]); V:=(Sum+8) Shr
    4; End
   Else If AvL Then Begin For I:=0 To 7 Do Inc(Sum,G[I]); V:=(Sum+4) Shr 3; End
   Else If AvT Then Begin For I:=0 To 7 Do Inc(Sum,F[I]); V:=(Sum+4) Shr 3; End
   Else V:=128;
   For J:=0 To 7 Do For I:=0 To 7 Do Pr[J,I]:=V;
  End;
  3: For J:=0 To 7 Do For I:=0 To 7 Do
      If (I=7) And (J=7) Then Pr[J,I]:=(F[14]+3*F[15]+2) Shr 2
      Else Pr[J,I]:=(F[I+J]+2*F[I+J+1]+F[I+J+2]+2) Shr 2;
  4: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      If I>J Then Pr[J,I]:=(Ft(I-J-2)+2*Ft(I-J-1)+Ft(I-J)+2) Shr 2
      Else If I<J Then Pr[J,I]:=(Gl(J-I-2)+2*Gl(J-I-1)+Gl(J-I)+2) Shr 2
      Else Pr[J,I]:=(F[0]+2*Ftl+G[0]+2) Shr 2;
     End;
  5: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      Z:=2*I-J;
      If Z>=0 Then Begin
       If (Z And 1)=0 Then Pr[J,I]:=(Ft(I-(J Shr 1)-1)+Ft(I-(J Shr 1))+1) Shr 1
       Else Pr[J,I]:=(Ft(I-(J Shr 1)-2)+2*Ft(I-(J Shr 1)-1)+Ft(I-(J Shr 1))+2)
        Shr 2;
      End Else If Z=-1 Then Pr[J,I]:=(G[0]+2*Ftl+F[0]+2) Shr 2
      Else Pr[J,I]:=(Gl(J-2*I-1)+2*Gl(J-2*I-2)+Gl(J-2*I-3)+2) Shr 2;
     End;
  6: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      Z:=2*J-I;
      If Z>=0 Then Begin
       If (Z And 1)=0 Then Pr[J,I]:=(Gl(J-(I Shr 1)-1)+Gl(J-(I Shr 1))+1) Shr 1
       Else Pr[J,I]:=(Gl(J-(I Shr 1)-2)+2*Gl(J-(I Shr 1)-1)+Gl(J-(I Shr 1))+2)
        Shr 2;
      End Else If Z=-1 Then Pr[J,I]:=(G[0]+2*Ftl+F[0]+2) Shr 2
      Else Pr[J,I]:=(Ft(I-2*J-1)+2*Ft(I-2*J-2)+Ft(I-2*J-3)+2) Shr 2;
     End;
  7: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      If (J And 1)=0 Then Pr[J,I]:=(F[I+(J Shr 1)]+F[I+(J Shr 1)+1]+1) Shr 1
      Else Pr[J,I]:=(F[I+(J Shr 1)]+2*F[I+(J Shr 1)+1]+F[I+(J Shr 1)+2]+2) Shr
       2;
     End;
  8: For J:=0 To 7 Do For I:=0 To 7 Do Begin
      Z:=I+2*J;
      If Z>13 Then Pr[J,I]:=G[7]
      Else If Z=13 Then Pr[J,I]:=(G[6]+3*G[7]+2) Shr 2
      Else If (Z And 1)=0 Then Pr[J,I]:=(G[J+(I Shr 1)]+G[J+(I Shr 1)+1]+1) Shr
       1
      Else Pr[J,I]:=(G[J+(I Shr 1)]+2*G[J+(I Shr 1)+1]+G[J+(I Shr 1)+2]+2) Shr
       2;
     End;
 End;
 For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(Y+J)*Stride+X+I]:=Pr[J,I];
End;

Procedure H4Pred16x16(Pl: H4PBuf; Stride,X,Y,Mode: LongInt; AvL,AvT:
 Boolean);
Var I,J,V,SumT,SumL,A,B,C,H,Vv: LongInt;
Begin
 Case Mode Of
  0: For J:=0 To 15 Do For I:=0 To 15 Do Pl^[(Y+J)*Stride+X+I]:=Pl^[(Y-1)*
   Stride+X+I];
  1: For J:=0 To 15 Do Begin V:=Pl^[(Y+J)*Stride+X-1]; For I:=0 To 15 Do Pl^[(Y+
   J)*Stride+X+I]:=V; End;
  2: Begin
   SumT:=0; SumL:=0;
   If AvT Then For I:=0 To 15 Do Inc(SumT,Pl^[(Y-1)*Stride+X+I]);
   If AvL Then For J:=0 To 15 Do Inc(SumL,Pl^[(Y+J)*Stride+X-1]);
   If AvT And AvL Then V:=(SumT+SumL+16) Shr 5
   Else If AvL Then V:=(SumL+8) Shr 4
   Else If AvT Then V:=(SumT+8) Shr 4
   Else V:=128;
   For J:=0 To 15 Do For I:=0 To 15 Do Pl^[(Y+J)*Stride+X+I]:=V;
  End;
  3: Begin
   H:=0; Vv:=0;
   For I:=0 To 7 Do Begin
    Inc(H,(I+1)*(Pl^[(Y-1)*Stride+X+8+I]-Pl^[(Y-1)*Stride+X+6-I]));
    Inc(Vv,(I+1)*(Pl^[(Y+8+I)*Stride+X-1]-Pl^[(Y+6-I)*Stride+X-1]));
   End;
   A:=16*(Pl^[(Y+15)*Stride+X-1]+Pl^[(Y-1)*Stride+X+15]);
   B:=H4Sar(5*H+32,6); C:=H4Sar(5*Vv+32,6);
   For J:=0 To 15 Do For I:=0 To 15 Do
    Pl^[(Y+J)*Stride+X+I]:=H4Clip(H4Sar(A+B*(I-7)+C*(J-7)+16,5));
  End;
 End;
End;

{ chroma 4:2:0 (8x8) : 0 DC, 1 horizontal, 2 vertical, 3 plan }
Procedure H4PredChroma(Pl: H4PBuf; Stride,X,Y,Mode: LongInt; AvL,AvT:
 Boolean);
Var I,J,V,A,B,C,H,Vv,Bx,By,S0,S1,SL0,SL1: LongInt;
Begin
 Case Mode Of
  0: For By:=0 To 1 Do For Bx:=0 To 1 Do Begin
      S0:=0; S1:=0;
      If AvT Then For I:=0 To 3 Do Inc(S0,Pl^[(Y-1)*Stride+X+Bx*4+I]);
      If AvL Then For J:=0 To 3 Do Inc(S1,Pl^[(Y+By*4+J)*Stride+X-1]);
      If (Bx=0) And (By=0) Or (Bx=1) And (By=1) Then Begin
       If AvT And AvL Then V:=(S0+S1+4) Shr 3
       Else If AvL Then V:=(S1+2) Shr 2
       Else If AvT Then V:=(S0+2) Shr 2
       Else V:=128;
      End Else If (Bx=1) And (By=0) Then Begin
       If AvT Then V:=(S0+2) Shr 2
       Else If AvL Then V:=(S1+2) Shr 2
       Else V:=128;
      End Else Begin
       If AvL Then V:=(S1+2) Shr 2
       Else If AvT Then V:=(S0+2) Shr 2
       Else V:=128;
      End;
      For J:=0 To 3 Do For I:=0 To 3 Do Pl^[(Y+By*4+J)*Stride+X+Bx*4+I]:=V;
     End;
  1: For J:=0 To 7 Do Begin V:=Pl^[(Y+J)*Stride+X-1]; For I:=0 To 7 Do Pl^[(Y+
   J)*Stride+X+I]:=V; End;
  2: For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(Y+J)*Stride+X+I]:=Pl^[(Y-1)*Stride+
   X+I];
  3: Begin
   H:=0; Vv:=0;
   For I:=0 To 3 Do Begin
    Inc(H,(I+1)*(Pl^[(Y-1)*Stride+X+4+I]-Pl^[(Y-1)*Stride+X+2-I]));
    Inc(Vv,(I+1)*(Pl^[(Y+4+I)*Stride+X-1]-Pl^[(Y+2-I)*Stride+X-1]));
   End;
   A:=16*(Pl^[(Y+7)*Stride+X-1]+Pl^[(Y-1)*Stride+X+7]);
   B:=H4Sar(34*H+32,6); C:=H4Sar(34*Vv+32,6);
   For J:=0 To 7 Do For I:=0 To 7 Do
    Pl^[(Y+J)*Stride+X+I]:=H4Clip(H4Sar(A+B*(I-3)+C*(J-3)+16,5));
  End;
 End;
End;

{ ---- transformees inverses ---- }
{ ajoute le residu 4x4 (D en raster, deja quantifie inverse) a l'image }
Procedure H4Idct4(Var D: Array Of LongInt; Pl: H4PBuf; Stride,X,Y: LongInt);
Var I,J,E0,E1,E2,E3: LongInt; T: Array[0..15] Of LongInt;
Begin
 For I:=0 To 3 Do Begin
  E0:=D[I*4]+D[I*4+2]; E1:=D[I*4]-D[I*4+2]; E2:=H4Sar(D[I*4+1],1)-D[I*4+3]; E3:=
   D[I*4+1]+H4Sar(D[I*4+3],1);
  T[I*4]:=E0+E3; T[I*4+1]:=E1+E2; T[I*4+2]:=E1-E2; T[I*4+3]:=E0-E3;
 End;
 For J:=0 To 3 Do Begin
  E0:=T[J]+T[8+J]; E1:=T[J]-T[8+J]; E2:=H4Sar(T[4+J],1)-T[12+J]; E3:=T[4+J]+
   H4Sar(T[12+J],1);
  Pl^[Y*Stride+X+J]:=H4Clip(Pl^[Y*Stride+X+J]+H4Sar(E0+E3+32,6));
  Pl^[(Y+1)*Stride+X+J]:=H4Clip(Pl^[(Y+1)*Stride+X+J]+H4Sar(E1+E2+32,6));
  Pl^[(Y+2)*Stride+X+J]:=H4Clip(Pl^[(Y+2)*Stride+X+J]+H4Sar(E1-E2+32,6));
  Pl^[(Y+3)*Stride+X+J]:=H4Clip(Pl^[(Y+3)*Stride+X+J]+H4Sar(E0-E3+32,6));
 End;
End;

Procedure H4Idct8(Var D: Array Of LongInt; Pl: H4PBuf; Stride,X,Y: LongInt);
Var I,J: LongInt; T: Array[0..63] Of LongInt; Cv: Array[0..7] Of LongInt; Out:
 Array[0..7] Of LongInt;
Procedure One(Var In0: Array Of LongInt);
Var A0,A1,A2,A3,A4,A5,A6,A7,B0,B1,B2,B3,B4,B5,B6,B7: LongInt;
Begin
 A0:=In0[0]+In0[4]; A4:=In0[0]-In0[4]; A2:=H4Sar(In0[2],1)-In0[6]; A6:=In0[2]+
  H4Sar(In0[6],1);
 B0:=A0+A6; B2:=A4+A2; B4:=A4-A2; B6:=A0-A6;
 A1:=-In0[3]+In0[5]-In0[7]-H4Sar(In0[7],1);
 A3:=In0[1]+In0[7]-In0[3]-H4Sar(In0[3],1);
 A5:=-In0[1]+In0[7]+In0[5]+H4Sar(In0[5],1);
 A7:=In0[3]+In0[5]+In0[1]+H4Sar(In0[1],1);
 B1:=A1+H4Sar(A7,2); B7:=A7-H4Sar(A1,2); B3:=A3+H4Sar(A5,2); B5:=H4Sar(A3,2)-A5;
 Out[0]:=B0+B7; Out[1]:=B2+B5; Out[2]:=B4+B3; Out[3]:=B6+B1; Out[4]:=B6-B1; Out[
  5]:=B4-B3; Out[6]:=B2-B5; Out[7]:=B0-B7;
End;
Begin
 For I:=0 To 7 Do Begin
  For J:=0 To 7 Do Cv[J]:=D[I*8+J];
  One(Cv);
  For J:=0 To 7 Do T[I*8+J]:=Out[J];
 End;
 For J:=0 To 7 Do Begin
  For I:=0 To 7 Do Cv[I]:=T[I*8+J];
  One(Cv);
  For I:=0 To 7 Do Pl^[(Y+I)*Stride+X+J]:=H4Clip(Pl^[(Y+I)*Stride+X+J]+H4Sar(
   Out[I]+32,6));
 End;
End;


{ ---- decodage de l'image courante ---- }
Const
 MT_I4=1; MT_I16=2; MT_PCM=4; MT_I8=8; MT_INTRA=15; MT_INTER=16; MT_SKIP=32;
  MT_DIRECT=64; MT_P8=128; MT_16X8=256; MT_8X16=512; MT_16X16=1024; MT_L0=2048;
  MT_L1=4096;
Var
 H4SliceTab: H4PLongArr;
 H4QpTab,H4NnzTab,H4IpmTab,H4CpmTab,H4Tx8Tab,H4MvdTab,H4Dir8Tab,H4CbfTab:
  H4PBuf;
 H4CbpTab: H4PWordArr;
 H4Sp: ^TH4Sps; H4Pp: ^TH4Pps;
 H4Ls4: Array[0..5,0..5,0..15] Of LongInt; H4Ls8: Array[0..1,0..5,0..63] Of
  LongInt;
 H4LsPps: LongInt; H4LsSps: LongInt;
 H4SliceNum,H4Qp,H4SliceType,H4LastDqp,H4MbAddr,H4MbX,H4MbY,H4MbsDone: LongInt;
 H4AvA,H4AvB,H4AvC,H4AvD: Boolean;     { disponibilite des macroblocs voisins }
 H4IiA,H4IiB,H4IiC,H4IiD: Boolean;     { disponibilite pour la prediction intra
  (contrainte intra) }
 H4Pw,H4Ph: LongInt;
 H4Coef: Array[0..767] Of LongInt;       { 16 blocs luma (raster 4x4 ou 4 blocs
  8x8), Cb, Cr }
 H4LumaDc: Array[0..15] Of LongInt; H4ChromaDc: Array[0..1,0..3] Of LongInt;
 H4CurType,H4CurCbp,H4I16Mode,H4ChromaMode,H4CurTx8: LongInt;
 H4Ipm: Array[0..15] Of LongInt;
 H4Nnz: Array[0..47] Of LongInt;        { luma 0..15, Cb 16..19, Cr 20..23 :
  nombres de coefficients du macrobloc courant }
 H4QpC: Array[0..1] Of LongInt;
 H4CabacOn: Boolean;
 H4CbSt: Array[0..1023] Of Byte;          { (etat shl 1) or valMPS }
 H4CbRange,H4CbOffset: LongInt;
 H4DcBits: LongInt;                        { bits 6,7 : DC chroma Cb/Cr ; bit 8
  : DC luma (comme cbp_table de libavcodec) }
 H4CurDir8: Array[0..3] Of Byte;           { blocs 8x8 predits en mode direct
  (macrobloc courant) }

Procedure H4SetupQuant;
Const N4: Array[0..5,0..2] Of Byte=((10,16,13),(11,18,14),(13,20,16),(14,23,18),
 (16,25,20),(18,29,23));
 N8: Array[0..5,0..5] Of Byte=((20,18,32,19,25,24),(22,19,35,21,28,26),(26,23,
  42,24,33,31),(28,25,45,26,35,33),(32,28,51,30,40,38),(36,32,58,34,46,43));
Var L,M,P,I,J,C: LongInt;
Begin
 For L:=0 To 5 Do For M:=0 To 5 Do For P:=0 To 15 Do Begin
  I:=P Shr 2; J:=P And 3;
  If ((I And 1)=0) And ((J And 1)=0) Then C:=N4[M,0] Else If ((I And 1)=1) And (
   (J And 1)=1) Then C:=N4[M,1] Else C:=N4[M,2];
  H4Ls4[L,M,P]:=H4Pp^.Sl4[L,P]*C;
 End;
 For L:=0 To 1 Do For M:=0 To 5 Do For P:=0 To 63 Do Begin
  I:=P Shr 3; J:=P And 7;
  If ((I And 3)=0) And ((J And 3)=0) Then C:=N8[M,0]
  Else If ((I And 1)=1) And ((J And 1)=1) Then C:=N8[M,1]
  Else If ((I And 3)=2) And ((J And 3)=2) Then C:=N8[M,2]
  Else If (((I And 3)=0) And ((J And 1)=1)) Or (((I And 1)=1) And ((J And 3)=0))
   Then C:=N8[M,3]
  Else If (((I And 3)=0) And ((J And 3)=2)) Or (((I And 3)=2) And ((J And 3)=0))
   Then C:=N8[M,4]
  Else C:=N8[M,5];
  H4Ls8[L,M,P]:=H4Pp^.Sl8[L,P]*C;
 End;
End;

Function H4ChromaQp(Qp,Off: LongInt): LongInt;
Const Tab: Array[0..21] Of Byte=(29,30,31,32,32,33,34,34,35,35,36,36,37,37,37,
 38,38,38,39,39,39,39);
Var Q: LongInt;
Begin
 Q:=H4Clip3(0,51,Qp+Off);
 If Q<30 Then H4ChromaQp:=Q Else H4ChromaQp:=Tab[Q-30];
End;

{ ---- voisinage ---- }
Procedure H4SetupNeighbors;
Var A: LongInt;
Begin
 A:=H4MbAddr;
 FillChar(H4MvdTab^[A*64],64,0); H4DcBits:=0; FillChar(H4CurDir8,4,0);
 H4AvA:=(H4MbX>0) And (H4SliceTab^[A-1]=H4SliceNum);
 H4AvB:=(H4MbY>0) And (H4SliceTab^[A-H4MbW]=H4SliceNum);
 H4AvC:=(H4MbY>0) And (H4MbX<H4MbW-1) And (H4SliceTab^[A-H4MbW+1]=H4SliceNum);
 H4AvD:=(H4MbX>0) And (H4MbY>0) And (H4SliceTab^[A-H4MbW-1]=H4SliceNum);
 H4IiA:=H4AvA; H4IiB:=H4AvB; H4IiC:=H4AvC; H4IiD:=H4AvD;
 If H4Pp^.ConstrainedIntra<>0 Then Begin
  If H4AvA Then H4IiA:=(H4Pics[H4Cur].MbType^[A-1] And MT_INTRA)<>0;
  If H4AvB Then H4IiB:=(H4Pics[H4Cur].MbType^[A-H4MbW] And MT_INTRA)<>0;
  If H4AvC Then H4IiC:=(H4Pics[H4Cur].MbType^[A-H4MbW+1] And MT_INTRA)<>0;
  If H4AvD Then H4IiD:=(H4Pics[H4Cur].MbType^[A-H4MbW-1] And MT_INTRA)<>0;
 End;
End;

{ nombre de coefficients voisins pour nC : Plane 0 luma, 1 Cb, 2 Cr ; (Bx,By)
 coordonnees de bloc }
Function H4NcAt(Plane,Bx,By: LongInt): LongInt;
Var NA,NB,Base,Gw,Mb: LongInt; HaveA,HaveB: Boolean;
Begin
 If Plane=0 Then Begin Gw:=4; Base:=0; End Else Begin Gw:=2; Base:=16+(Plane-1)*
  4; End;
 HaveA:=True; HaveB:=True;
 If Bx>0 Then NA:=H4Nnz[Base+By*Gw+Bx-1]
 Else If H4AvA Then NA:=H4NnzTab^[(H4MbAddr-1)*48+Base+By*Gw+Gw-1]
 Else Begin HaveA:=False; NA:=0; End;
 If By>0 Then NB:=H4Nnz[Base+(By-1)*Gw+Bx]
 Else If H4AvB Then NB:=H4NnzTab^[(H4MbAddr-H4MbW)*48+Base+(Gw-1)*Gw+Bx]
 Else Begin HaveB:=False; NB:=0; End;
 If HaveA And HaveB Then H4NcAt:=(NA+NB+1) Shr 1
 Else If HaveA Then H4NcAt:=NA
 Else If HaveB Then H4NcAt:=NB
 Else H4NcAt:=0;
End;

Const H4BlkX: Array[0..15] Of Byte=(0,1,0,1,2,3,2,3,0,1,0,1,2,3,2,3);
      H4BlkY: Array[0..15] Of Byte=(0,0,1,1,0,0,1,1,2,2,3,3,2,2,3,3);

{ quantification inverse d'un bloc 4x4 raster : C -> D ; Dc0 : valeur DC deja
 calculee (si Sep) }
Procedure H4Dequant4(Var C: Array Of LongInt; Off: LongInt; Var D: Array Of
 LongInt; List,Qp: LongInt; Sep: Boolean; Dc0: LongInt);
Var I,Qd,Qm,V: LongInt;
Begin
 Qd:=Qp Div 6; Qm:=Qp Mod 6;
 For I:=0 To 15 Do Begin
  V:=C[Off+I];
  If V=0 Then D[I]:=0
  Else If Qd>=4 Then D[I]:=(V*H4Ls4[List,Qm,I]) Shl (Qd-4)
  Else D[I]:=H4Sar(V*H4Ls4[List,Qm,I]+(1 Shl (3-Qd)),4-Qd);
 End;
 If Sep Then D[0]:=Dc0;
End;
Procedure H4Dequant8(Var C: Array Of LongInt; Off: LongInt; Var D: Array Of
 LongInt; List,Qp: LongInt);
Var I,Qd,Qm,V: LongInt;
Begin
 Qd:=Qp Div 6; Qm:=Qp Mod 6;
 For I:=0 To 63 Do Begin
  V:=C[Off+I];
  If V=0 Then D[I]:=0
  Else If Qd>=6 Then D[I]:=(V*H4Ls8[List,Qm,I]) Shl (Qd-6)
  Else D[I]:=H4Sar(V*H4Ls8[List,Qm,I]+(1 Shl (5-Qd)),6-Qd);
 End;
End;
{ DC luma Intra16x16 : Hadamard + mise a l'echelle ; Lv : 16 niveaux en raster
 4x4 ; Out en raster }
Procedure H4LumaDcTransform(Var Lv: Array Of LongInt; Var Out: Array Of LongInt;
 Qp: LongInt);
Var T,F: Array[0..15] Of LongInt; I,J,A,B,C,D,Qd,Qm,Ls: LongInt;
Begin
 For I:=0 To 3 Do Begin
  A:=Lv[I*4]; B:=Lv[I*4+1]; C:=Lv[I*4+2]; D:=Lv[I*4+3];
  T[I*4]:=A+B+C+D; T[I*4+1]:=A+B-C-D; T[I*4+2]:=A-B-C+D; T[I*4+3]:=A-B+C-D;
 End;
 For J:=0 To 3 Do Begin
  A:=T[J]; B:=T[4+J]; C:=T[8+J]; D:=T[12+J];
  F[J]:=A+B+C+D; F[4+J]:=A+B-C-D; F[8+J]:=A-B-C+D; F[12+J]:=A-B+C-D;
 End;
 Qd:=Qp Div 6; Qm:=Qp Mod 6; Ls:=H4Ls4[0,Qm,0];
 For I:=0 To 15 Do
  If Qd>=6 Then Out[I]:=(F[I]*Ls) Shl (Qd-6) Else Out[I]:=H4Sar(F[I]*Ls+(1 Shl (
   5-Qd)),6-Qd);
End;

Const
 H4CabacLps: Array[0..255] Of Byte=(
  128,176,208,240,128,167,197,227,128,158,187,216,123,150,178,205,
  116,142,169,195,111,135,160,185,105,128,152,175,100,122,144,166,
  95,116,137,158,90,110,130,150,85,104,123,142,81,99,117,135,
  77,94,111,128,73,89,105,122,69,85,100,116,66,80,95,110,
  62,76,90,104,59,72,86,99,56,69,81,94,53,65,77,89,
  51,62,73,85,48,59,69,80,46,56,66,76,43,53,63,72,
  41,50,59,69,39,48,56,65,37,45,54,62,35,43,51,59,
  33,41,48,56,32,39,46,53,30,37,43,50,29,35,41,48,
  27,33,39,45,26,31,37,43,24,30,35,41,23,28,33,39,
  22,27,32,37,21,26,30,35,20,24,29,33,19,23,27,31,
  18,22,26,30,17,21,25,28,16,20,23,27,15,19,22,25,
  14,18,21,24,14,17,20,23,13,16,19,22,12,15,18,21,
  12,14,17,20,11,14,16,19,11,13,15,18,10,12,15,17,
  10,12,14,16,9,11,13,15,9,11,12,14,8,10,12,14,
  8,9,11,13,7,9,11,12,7,9,10,12,7,8,10,11,
  6,8,9,11,6,7,9,10,6,7,8,9,2,2,2,2
 );
 H4CabacTransLps: Array[0..63] Of Byte=(
  0,0,1,2,2,4,4,5,6,7,8,9,9,11,11,12,
  13,13,15,15,16,16,18,18,19,19,21,21,22,22,23,24,
  24,25,26,26,27,27,28,29,29,30,30,30,31,32,32,33,
  33,33,34,34,35,35,35,36,36,36,37,37,37,38,38,63
 );
 H4CabacLast8: Array[0..62] Of Byte=(
  0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,
  5,5,5,5,6,6,6,6,7,7,7,7,8,8,8
 );
 H4CabacSig8: Array[0..62] Of Byte=(
  0,1,2,3,4,5,5,4,4,3,3,4,4,4,5,5,
  4,4,4,4,3,3,6,7,7,7,8,9,10,9,8,7,
  7,6,11,12,13,11,6,7,8,9,14,10,9,8,6,11,
  12,13,11,6,9,14,10,9,11,12,13,11,14,10,12
 );

{ ---- CABAC (9.3) : moteur arithmetique, elements de syntaxe et residu ---- }

Procedure H4CabacInit(SliceQp,InitIdc: LongInt; IsI: Boolean);
Var I,M,N,Pre: LongInt;
Begin
 For I:=0 To 1023 Do Begin
  If IsI Then Begin M:=H4CabacInitI[2*I]; N:=H4CabacInitI[2*I+1]; End
  Else Begin M:=H4CabacInitPB[InitIdc*2048+2*I]; N:=H4CabacInitPB[InitIdc*2048+
   2*I+1]; End;
  Pre:=H4Clip3(1,126,H4Sar(M*H4Clip3(0,51,SliceQp),4)+N);
  If Pre<=63 Then H4CbSt[I]:=(63-Pre)*2 Else H4CbSt[I]:=(Pre-64)*2+1;
 End;
 H4Pos:=(H4Pos+7) And -8;
 H4CbRange:=510; H4CbOffset:=H4Bits(9);
End;

Function H4CbDec(Ctx: LongInt): LongInt;
Var S,St,Mps,RLps,N: LongInt;
Begin
 S:=H4CbSt[Ctx]; St:=S Shr 1; Mps:=S And 1;
 RLps:=H4CabacLps[St*4+((H4CbRange Shr 6) And 3)];
 Dec(H4CbRange,RLps);
 If H4CbOffset>=H4CbRange Then Begin
  Dec(H4CbOffset,H4CbRange); H4CbRange:=RLps; H4CbDec:=1-Mps;
  If St=0 Then Mps:=1-Mps;
  St:=H4CabacTransLps[St];
 End Else Begin
  H4CbDec:=Mps;
  If St<62 Then Inc(St);
 End;
 H4CbSt[Ctx]:=St*2+Mps;
 If H4CbRange<256 Then Begin
  N:=0; While (H4CbRange Shl N)<256 Do Inc(N);
  H4CbRange:=H4CbRange Shl N; H4CbOffset:=(H4CbOffset Shl N) Or H4Bits(N);
 End;
End;
Function H4CbByp: LongInt;
Begin
 H4CbOffset:=(H4CbOffset Shl 1) Or H4Bit;
 If H4CbOffset>=H4CbRange Then Begin Dec(H4CbOffset,H4CbRange); H4CbByp:=1; End
  Else H4CbByp:=0;
End;
Function H4CbTerm: LongInt;
Begin
 Dec(H4CbRange,2);
 If H4CbOffset>=H4CbRange Then H4CbTerm:=1
 Else Begin
  H4CbTerm:=0;
  If H4CbRange<256 Then Begin H4CbRange:=H4CbRange Shl 1; H4CbOffset:=(
   H4CbOffset Shl 1) Or H4Bit; End;
 End;
End;

{ ---- elements de syntaxe ---- }
Function H4CbSkip: Boolean;
Var Ctx: LongInt;
Begin
 Ctx:=0;
 If H4AvA Then If (H4Pics[H4Cur].MbType^[H4MbAddr-1] And MT_SKIP)=0 Then Inc(
  Ctx);
 If H4AvB Then If (H4Pics[H4Cur].MbType^[H4MbAddr-H4MbW] And MT_SKIP)=0 Then
  Inc(Ctx);
 If H4SliceType=1 Then Inc(Ctx,13);
 H4CbSkip:=H4CbDec(11+Ctx)<>0;
End;

{ type de macrobloc intra : 0 I_NxN, 1..24 I16x16, 25 PCM ; Base 3 (tranche I) /
 17 (P) / 32 (B) }
Function H4CbIntraType(Base: LongInt; IntraSlice: Boolean): LongInt;
Var Ctx,S,T: LongInt;
Begin
 S:=Base;
 If IntraSlice Then Begin
  Ctx:=0;
  If H4AvA Then If (H4Pics[H4Cur].MbType^[H4MbAddr-1] And (MT_I16 Or MT_PCM))<>0
   Then Inc(Ctx);
  If H4AvB Then If (H4Pics[H4Cur].MbType^[H4MbAddr-H4MbW] And (MT_I16 Or
   MT_PCM))<>0 Then Inc(Ctx);
  If H4CbDec(S+Ctx)=0 Then Begin H4CbIntraType:=0; Exit; End;
  Inc(S,2);
 End Else Begin
  If H4CbDec(S)=0 Then Begin H4CbIntraType:=0; Exit; End;
 End;
 If H4CbTerm<>0 Then Begin H4CbIntraType:=25; Exit; End;
 T:=1;
 Inc(T,12*H4CbDec(S+1));
 If H4CbDec(S+2)<>0 Then Begin
  If IntraSlice Then Inc(T,4+4*H4CbDec(S+3)) Else Inc(T,4+4*H4CbDec(S+2));
 End;
 If IntraSlice Then Begin Inc(T,2*H4CbDec(S+4)); Inc(T,H4CbDec(S+5)); End
 Else Begin Inc(T,2*H4CbDec(S+3)); Inc(T,H4CbDec(S+3)); End;
 H4CbIntraType:=T;
End;

{ type de macrobloc d'une tranche P : 0..3 inter, 5+x intra }
Function H4CbMbTypeP: LongInt;
Begin
 If H4CbDec(14)=0 Then Begin
  If H4CbDec(15)=0 Then H4CbMbTypeP:=3*H4CbDec(16) Else H4CbMbTypeP:=2-H4CbDec(
   17);
 End Else H4CbMbTypeP:=5+H4CbIntraType(17,False);
End;

{ type de macrobloc d'une tranche B : 0..22 inter, 23+x intra }
Function H4CbMbTypeB: LongInt;
Var Ctx,Bits: LongInt;
Begin
 Ctx:=0;
 If H4AvA Then If (H4Pics[H4Cur].MbType^[H4MbAddr-1] And MT_DIRECT)=0 Then Inc(
  Ctx);
 If H4AvB Then If (H4Pics[H4Cur].MbType^[H4MbAddr-H4MbW] And MT_DIRECT)=0 Then
  Inc(Ctx);
 If H4CbDec(27+Ctx)=0 Then Begin H4CbMbTypeB:=0; Exit; End;
 If H4CbDec(27+3)=0 Then Begin H4CbMbTypeB:=1+H4CbDec(27+5); Exit; End;
 Bits:=H4CbDec(27+4) Shl 3;
 Bits:=Bits+(H4CbDec(27+5) Shl 2);
 Bits:=Bits+(H4CbDec(27+5) Shl 1);
 Bits:=Bits+H4CbDec(27+5);
 If Bits<8 Then H4CbMbTypeB:=Bits+3
 Else If Bits=13 Then H4CbMbTypeB:=23+H4CbIntraType(32,False)
 Else If Bits=14 Then H4CbMbTypeB:=11
 Else If Bits=15 Then H4CbMbTypeB:=22
 Else Begin
  Bits:=(Bits Shl 1)+H4CbDec(27+5);
  H4CbMbTypeB:=Bits-4;
 End;
End;

Function H4CbSubP: LongInt;
Begin
 If H4CbDec(21)<>0 Then Begin H4CbSubP:=0; Exit; End;
 If H4CbDec(22)=0 Then Begin H4CbSubP:=1; Exit; End;
 If H4CbDec(23)<>0 Then H4CbSubP:=2 Else H4CbSubP:=3;
End;
Function H4CbSubB: LongInt;
Var T: LongInt;
Begin
 If H4CbDec(36)=0 Then Begin H4CbSubB:=0; Exit; End;
 If H4CbDec(37)=0 Then Begin H4CbSubB:=1+H4CbDec(39); Exit; End;
 T:=3;
 If H4CbDec(38)<>0 Then Begin
  If H4CbDec(39)<>0 Then Begin H4CbSubB:=11+H4CbDec(39); Exit; End;
  Inc(T,4);
 End;
 Inc(T,2*H4CbDec(39));
 Inc(T,H4CbDec(39));
 H4CbSubB:=T;
End;

Function H4CbIpm(Pm: LongInt): LongInt;
Var M: LongInt;
Begin
 If H4CbDec(68)<>0 Then Begin H4CbIpm:=Pm; Exit; End;
 M:=H4CbDec(69);
 Inc(M,2*H4CbDec(69));
 Inc(M,4*H4CbDec(69));
 If M>=Pm Then Inc(M);
 H4CbIpm:=M;
End;

Function H4CbChromaMode: LongInt;
Var Ctx: LongInt;
Begin
 Ctx:=0;
 If H4AvA Then If H4CpmTab^[H4MbAddr-1]<>0 Then Inc(Ctx);
 If H4AvB Then If H4CpmTab^[H4MbAddr-H4MbW]<>0 Then Inc(Ctx);
 If H4CbDec(64+Ctx)=0 Then Begin H4CbChromaMode:=0; Exit; End;
 If H4CbDec(67)=0 Then Begin H4CbChromaMode:=1; Exit; End;
 If H4CbDec(67)=0 Then H4CbChromaMode:=2 Else H4CbChromaMode:=3;
End;

Function H4CbTx8: Boolean;
Var Ctx: LongInt;
Begin
 Ctx:=0;
 If H4AvA Then If H4Tx8Tab^[H4MbAddr-1]<>0 Then Inc(Ctx);
 If H4AvB Then If H4Tx8Tab^[H4MbAddr-H4MbW]<>0 Then Inc(Ctx);
 H4CbTx8:=H4CbDec(399+Ctx)<>0;
End;

Function H4CbCbp(Intra: Boolean): LongInt;
Var Lw,Tw,Cbp,Ctx,Ca,Cb: LongInt;
Begin
 If Intra Then Begin Lw:=$7CF; Tw:=$7CF; End Else Begin Lw:=$00F; Tw:=$00F; End;
 If H4AvA Then Lw:=H4CbpTab^[H4MbAddr-1];
 If H4AvB Then Tw:=H4CbpTab^[H4MbAddr-H4MbW];
 Ctx:=Ord((Lw And 2)=0)+2*Ord((Tw And 4)=0);
 Cbp:=H4CbDec(73+Ctx);
 Ctx:=Ord((Cbp And 1)=0)+2*Ord((Tw And 8)=0);
 Cbp:=Cbp+(H4CbDec(73+Ctx) Shl 1);
 Ctx:=Ord((Lw And 8)=0)+2*Ord((Cbp And 1)=0);
 Cbp:=Cbp+(H4CbDec(73+Ctx) Shl 2);
 Ctx:=Ord((Cbp And 4)=0)+2*Ord((Cbp And 2)=0);
 Cbp:=Cbp+(H4CbDec(73+Ctx) Shl 3);
 Ca:=(Lw Shr 4) And 3; Cb:=(Tw Shr 4) And 3;
 Ctx:=Ord(Ca>0)+2*Ord(Cb>0);
 If H4CbDec(77+Ctx)<>0 Then Begin
  Ctx:=4+Ord(Ca=2)+2*Ord(Cb=2);
  Cbp:=Cbp+((1+H4CbDec(77+Ctx)) Shl 4);
 End;
 H4CbCbp:=Cbp;
End;

Function H4CbDqp: LongInt;
Var Val,Ctx: LongInt;
Begin
 If H4CbDec(60+Ord(H4LastDqp<>0))=0 Then Begin H4CbDqp:=0; Exit; End;
 Val:=1; Ctx:=2;
 While H4CbDec(60+Ctx)<>0 Do Begin
  Ctx:=3; Inc(Val);
  If Val>104 Then Begin H4Err:=True; H4CbDqp:=0; Exit; End;
 End;
 If Odd(Val) Then H4CbDqp:=(Val+1) Div 2 Else H4CbDqp:=-((Val+1) Div 2);
End;

{ voisin pour l'indice de reference : R=-2 indisponible, -1 intra/liste
 inutilisee ; Dir : predit en mode direct }
Procedure H4NbRef(L,Bx,By: LongInt; Var R: LongInt; Var Dir: Boolean);
Var Addr,Blk,B8: LongInt; Ok: Boolean;
Begin
 R:=-2; Dir:=False; Addr:=H4MbAddr; Ok:=False; Blk:=0;
 If By<0 Then Begin Ok:=H4AvB; Addr:=H4MbAddr-H4MbW; Blk:=12+Bx; End
 Else If Bx<0 Then Begin Ok:=H4AvA; Addr:=H4MbAddr-1; Blk:=By*4+3; End
 Else Begin Ok:=True; Blk:=By*4+Bx; End;
 If Not Ok Then Exit;
 B8:=(Blk Shr 3)*2+((Blk And 3) Shr 1);
 R:=-1;
 If Addr<>H4MbAddr Then Begin
  If (H4Pics[H4Cur].MbType^[Addr] And MT_INTRA)<>0 Then Exit;
  Dir:=H4Dir8Tab^[Addr*4+B8]<>0;
 End Else Dir:=H4CurDir8[B8]<>0;
 R:=ShortInt(H4PBuf(H4Pics[H4Cur].Ref[L])^[Addr*4+B8]);
End;

Function H4CbRef(L,Bx,By: LongInt): LongInt;
Var Ra,Rb,Ctx,Ref: LongInt; Da,Db: Boolean;
Begin
 H4NbRef(L,Bx-1,By,Ra,Da); H4NbRef(L,Bx,By-1,Rb,Db);
 Ctx:=0;
 If (Ra>0) And Not Da Then Inc(Ctx);
 If (Rb>0) And Not Db Then Inc(Ctx,2);
 Ref:=0;
 While H4CbDec(54+Ctx)<>0 Do Begin
  Inc(Ref); Ctx:=(Ctx Shr 2)+4;
  If Ref>=32 Then Begin H4Err:=True; H4CbRef:=0; Exit; End;
 End;
 H4CbRef:=Ref;
End;

{ valeur absolue de mvd du voisin }
Function H4NbMvd(L,Bx,By,Comp: LongInt): LongInt;
Var Addr,Blk: LongInt;
Begin
 H4NbMvd:=0; Addr:=H4MbAddr;
 If By<0 Then Begin If Not H4AvB Then Exit; Addr:=H4MbAddr-H4MbW; Blk:=12+Bx;
  End
 Else If Bx<0 Then Begin If Not H4AvA Then Exit; Addr:=H4MbAddr-1; Blk:=By*4+3;
  End
 Else Blk:=By*4+Bx;
 H4NbMvd:=H4MvdTab^[(((Addr*2+L)*16+Blk) Shl 1)+Comp];
End;

Function H4CbMvd(CtxBase,Amvd: LongInt; Var Mva: LongInt): LongInt;
Var Mvd,K: LongInt;
Begin
 If Amvd<3 Then K:=0 Else If Amvd>32 Then K:=2 Else K:=1;
 If H4CbDec(CtxBase+K)=0 Then Begin Mva:=0; H4CbMvd:=0; Exit; End;
 Mvd:=1; K:=CtxBase+3;
 While (Mvd<9) And (H4CbDec(K)<>0) Do Begin
  If Mvd<4 Then Inc(K);
  Inc(Mvd);
 End;
 If Mvd>=9 Then Begin
  K:=3;
  While H4CbByp<>0 Do Begin
   Inc(Mvd,1 Shl K); Inc(K);
   If K>24 Then Begin H4Err:=True; Mva:=0; H4CbMvd:=0; Exit; End;
  End;
  While K>0 Do Begin Dec(K); Inc(Mvd,H4CbByp Shl K); End;
  If Mvd<70 Then Mva:=Mvd Else Mva:=70;
 End Else Mva:=Mvd;
 If H4CbByp<>0 Then H4CbMvd:=-Mvd Else H4CbMvd:=Mvd;
End;

{ ---- residu ---- }
Function H4CbResidual(Cat,MaxCoeff,CbfCtx: LongInt; Var Lev: Array Of LongInt):
 LongInt;
Const SigOff: Array[0..5] Of Word=(105,120,134,149,152,402);
 LastOff: Array[0..5] Of Word=(166,181,195,210,213,417);
 AbsOff: Array[0..5] Of Word=(227,237,247,257,266,426);
Var I,Count,SigI,LastI,K,Eq1,Gt1,Abs_,Ab,Cx,Mx: LongInt; Idx: Array[0..63] Of
 LongInt; Last: Boolean;
Begin
 For I:=0 To MaxCoeff-1 Do Lev[I]:=0;
 H4CbResidual:=0;
 If CbfCtx>=0 Then If H4CbDec(CbfCtx)=0 Then Exit;
 Count:=0; Last:=False;
 For I:=0 To MaxCoeff-2 Do Begin
  If Cat=5 Then Begin SigI:=H4CabacSig8[I]; LastI:=H4CabacLast8[I]; End
  Else If Cat=3 Then Begin If I<2 Then SigI:=I Else SigI:=2; LastI:=SigI; End
  Else Begin SigI:=I; LastI:=I; End;
  If H4CbDec(SigOff[Cat]+SigI)<>0 Then Begin
   Idx[Count]:=I; Inc(Count);
   If H4CbDec(LastOff[Cat]+LastI)<>0 Then Begin Last:=True; Break; End;
  End;
 End;
 If Not Last Then Begin Idx[Count]:=MaxCoeff-1; Inc(Count); End;
 H4CbResidual:=Count;
 Eq1:=0; Gt1:=0;
 If Cat=3 Then Mx:=3 Else Mx:=4;
 For K:=Count-1 DownTo 0 Do Begin
  If Gt1<>0 Then Cx:=0 Else Begin Cx:=1+Eq1; If Cx>4 Then Cx:=4; End;
  If H4CbDec(AbsOff[Cat]+Cx)=0 Then Begin
   Abs_:=1; Inc(Eq1);
  End Else Begin
   Cx:=Gt1; If Cx>Mx Then Cx:=Mx;
   Cx:=AbsOff[Cat]+5+Cx;
   Abs_:=2;
   While (Abs_<15) And (H4CbDec(Cx)<>0) Do Inc(Abs_);
   If Abs_>=15 Then Begin
    Ab:=0;
    While (H4CbByp<>0) And (Ab<23) Do Inc(Ab);
    Abs_:=1;
    While Ab>0 Do Begin Dec(Ab); Abs_:=Abs_+Abs_+H4CbByp; End;
    Inc(Abs_,14);
   End;
   Inc(Gt1);
  End;
  If H4CbByp<>0 Then Lev[Idx[K]]:=-Abs_ Else Lev[Idx[K]]:=Abs_;
 End;
End;

{ condition de voisinage pour le drapeau de bloc code d'un bloc 4x4 : Plane 0
 luma, 1/2 chroma }
Function H4CbfInc(Plane,Bx,By: LongInt): LongInt;
Var Base,Gw,Na,Nb: LongInt; Intra: Boolean;
Begin
 If Plane=0 Then Begin Gw:=4; Base:=0; End Else Begin Gw:=2; Base:=16+(Plane-1)*
  4; End;
 Intra:=(H4CurType And MT_INTRA)<>0;
 If Bx>0 Then Na:=H4Nnz[Base+By*Gw+Bx-1]
 Else If H4AvA Then Na:=H4NnzTab^[(H4MbAddr-1)*48+Base+By*Gw+Gw-1]
 Else Na:=Ord(Intra);
 If By>0 Then Nb:=H4Nnz[Base+(By-1)*Gw+Bx]
 Else If H4AvB Then Nb:=H4NnzTab^[(H4MbAddr-H4MbW)*48+Base+(Gw-1)*Gw+Bx]
 Else Nb:=Ord(Intra);
 H4CbfInc:=Ord(Na>0)+2*Ord(Nb>0);
End;
Function H4CbfDcInc(Bit: LongInt): LongInt;
Var Na,Nb,Def: LongInt;
Begin
 If (H4CurType And MT_INTRA)<>0 Then Def:=1 Else Def:=0;
 If H4AvA Then Na:=(H4CbpTab^[H4MbAddr-1] Shr Bit) And 1 Else Na:=Def;
 If H4AvB Then Nb:=(H4CbpTab^[H4MbAddr-H4MbW] Shr Bit) And 1 Else Nb:=Def;
 H4CbfDcInc:=Na+2*Nb;
End;

Function H4LumaCabac(Tx8,I16: Boolean; CbpL: LongInt): Boolean;
Var B8,I4,Blk,Bx,By,N,K,Mx,Cat: LongInt; Lev: Array[0..63] Of LongInt;
Begin
 H4LumaCabac:=False;
 FillChar(H4Coef,SizeOf(H4Coef),0);
 FillChar(H4LumaDc,SizeOf(H4LumaDc),0);
 If I16 Then Begin
  N:=H4CbResidual(0,16,85+H4CbfDcInc(8),Lev);
  If H4Err Then Exit;
  If N>0 Then H4DcBits:=H4DcBits Or $100;
  For K:=0 To 15 Do H4LumaDc[H4Zigzag4[K]]:=Lev[K];
 End;
 For B8:=0 To 3 Do Begin
  If ((CbpL Shr B8) And 1)<>0 Then Begin
   If Tx8 Then Begin
    N:=H4CbResidual(5,64,-1,Lev);
    If H4Err Then Exit;
    For K:=0 To 63 Do If Lev[K]<>0 Then H4Coef[B8*64+H4Zigzag8[K]]:=Lev[K];
    For I4:=0 To 3 Do Begin Blk:=B8*4+I4; H4Nnz[H4BlkY[Blk]*4+H4BlkX[Blk]]:=N;
     End;
   End Else Begin
    For I4:=0 To 3 Do Begin
     Blk:=B8*4+I4; Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
     If I16 Then Begin Cat:=1; Mx:=15; End Else Begin Cat:=2; Mx:=16; End;
     N:=H4CbResidual(Cat,Mx,85+4*Cat+H4CbfInc(0,Bx,By),Lev);
     If H4Err Then Exit;
     H4Nnz[By*4+Bx]:=N;
     If I16 Then Begin For K:=0 To 14 Do If Lev[K]<>0 Then H4Coef[Blk*16+
      H4Zigzag4[K+1]]:=Lev[K]; End
     Else For K:=0 To 15 Do If Lev[K]<>0 Then H4Coef[Blk*16+H4Zigzag4[K]]:=Lev[
      K];
    End;
   End;
  End Else Begin
   For I4:=0 To 3 Do Begin Blk:=B8*4+I4; H4Nnz[H4BlkY[Blk]*4+H4BlkX[Blk]]:=0;
    End;
  End;
 End;
 H4LumaCabac:=True;
End;

Function H4ChromaCabac(CbpC: LongInt): Boolean;
Var C,Blk,N,K: LongInt; Lev: Array[0..15] Of LongInt;
Begin
 H4ChromaCabac:=False;
 FillChar(H4ChromaDc,SizeOf(H4ChromaDc),0);
 If CbpC<>0 Then Begin
  For C:=0 To 1 Do Begin
   N:=H4CbResidual(3,4,97+H4CbfDcInc(6+C),Lev);
   If H4Err Then Exit;
   If N>0 Then H4DcBits:=H4DcBits Or ($40 Shl C);
   For K:=0 To 3 Do H4ChromaDc[C,K]:=Lev[K];
  End;
 End;
 For C:=0 To 1 Do For Blk:=0 To 3 Do H4Nnz[16+C*4+Blk]:=0;
 If CbpC=2 Then Begin
  For C:=0 To 1 Do For Blk:=0 To 3 Do Begin
   N:=H4CbResidual(4,15,101+H4CbfInc(1+C,Blk And 1,Blk Shr 1),Lev);
   If H4Err Then Exit;
   H4Nnz[16+C*4+Blk]:=N;
   For K:=0 To 14 Do If Lev[K]<>0 Then H4Coef[256+C*64+Blk*16+H4Zigzag4[K+1]]:=
    Lev[K];
  End;
 End;
 H4ChromaCabac:=True;
End;


{ ---- couche macrobloc : intra / residu CAVLC ---- }
Const H4BlkOrder: Array[0..15] Of Byte=(0,1,4,5,2,3,6,7,8,9,12,13,10,11,14,15);

Function H4NbIpm(Avail: Boolean; Addr,Idx: LongInt): LongInt;  { -1 : mode DC
 force }
Begin
 If Not Avail Then Begin H4NbIpm:=-1; Exit; End;
 If (H4Pics[H4Cur].MbType^[Addr] And MT_INTRA)=0 Then Begin
  If H4Pp^.ConstrainedIntra<>0 Then H4NbIpm:=-1 Else H4NbIpm:=2;
  Exit;
 End;
 If (H4Pics[H4Cur].MbType^[Addr] And (MT_I4 Or MT_I8))=0 Then H4NbIpm:=2 Else
  H4NbIpm:=ShortInt(H4IpmTab^[Addr*16+Idx]);
End;
Function H4PredIpm(Bx,By: LongInt): LongInt;
Var A,B: LongInt;
Begin
 If Bx>0 Then A:=H4Ipm[By*4+Bx-1] Else A:=H4NbIpm(H4AvA,H4MbAddr-1,By*4+3);
 If By>0 Then B:=H4Ipm[(By-1)*4+Bx] Else B:=H4NbIpm(H4AvB,H4MbAddr-H4MbW,12+Bx);
 If (A<0) Or (B<0) Then H4PredIpm:=2 Else If A<B Then H4PredIpm:=A Else
  H4PredIpm:=B;
End;

{ lecture du residu luma CAVLC ; Cbp : bits 0..3 ; I16 : DC + AC a 15
 coefficients }
Function H4LumaCavlc(Tx8,I16: Boolean; CbpL: LongInt): Boolean;
Var B8,I4,Blk,Bx,By,N,K,Nc,Mx: LongInt; Lev: Array[0..15] Of LongInt;
Begin
 H4LumaCavlc:=False;
 FillChar(H4Coef,SizeOf(H4Coef),0);
 FillChar(H4LumaDc,SizeOf(H4LumaDc),0);
 If I16 Then Begin
  Nc:=H4NcAt(0,0,0);
  N:=H4CavlcBlock(Lev,16,Nc);
  If N<0 Then Exit;
  For K:=0 To 15 Do H4LumaDc[H4Zigzag4[K]]:=Lev[K];
 End;
 For B8:=0 To 3 Do Begin
  If ((CbpL Shr B8) And 1)<>0 Then Begin
   For I4:=0 To 3 Do Begin
    Blk:=B8*4+I4; Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
    Nc:=H4NcAt(0,Bx,By);
    If I16 Then Mx:=15 Else Mx:=16;
    N:=H4CavlcBlock(Lev,Mx,Nc);
    If N<0 Then Exit;
    H4Nnz[By*4+Bx]:=N;
    If Tx8 Then Begin
     For K:=0 To 15 Do If Lev[K]<>0 Then H4Coef[B8*64+H4Zigzag8[4*K+I4]]:=Lev[
      K];
    End Else If I16 Then Begin
     For K:=0 To 14 Do If Lev[K]<>0 Then H4Coef[Blk*16+H4Zigzag4[K+1]]:=Lev[K];
    End Else Begin
     For K:=0 To 15 Do If Lev[K]<>0 Then H4Coef[Blk*16+H4Zigzag4[K]]:=Lev[K];
    End;
   End;
  End Else Begin
   For I4:=0 To 3 Do Begin Blk:=B8*4+I4; H4Nnz[H4BlkY[Blk]*4+H4BlkX[Blk]]:=0;
    End;
  End;
 End;
 H4LumaCavlc:=True;
End;
Function H4ChromaCavlc(CbpC: LongInt): Boolean;
Var C,Blk,N,K,Nc: LongInt; Lev: Array[0..15] Of LongInt;
Begin
 H4ChromaCavlc:=False;
 FillChar(H4ChromaDc,SizeOf(H4ChromaDc),0);
 If CbpC<>0 Then Begin
  For C:=0 To 1 Do Begin
   N:=H4CavlcBlock(Lev,4,-1);
   If N<0 Then Exit;
   For K:=0 To 3 Do H4ChromaDc[C,K]:=Lev[K];
  End;
 End;
 For C:=0 To 1 Do For Blk:=0 To 3 Do H4Nnz[16+C*4+Blk]:=0;
 If CbpC=2 Then Begin
  For C:=0 To 1 Do For Blk:=0 To 3 Do Begin
   Nc:=H4NcAt(1+C,Blk And 1,Blk Shr 1);
   N:=H4CavlcBlock(Lev,15,Nc);
   If N<0 Then Exit;
   H4Nnz[16+C*4+Blk]:=N;
   For K:=0 To 14 Do If Lev[K]<>0 Then H4Coef[256+C*64+Blk*16+H4Zigzag4[K+1]]:=
    Lev[K];
  End;
 End;
 H4ChromaCavlc:=True;
End;

{ ajoute le residu luma d'un bloc 4x4 (ou 8x8) deja decode }
Procedure H4AddLuma4(Blk,Qp,List: LongInt; Sep: Boolean; Dc0: LongInt);
Var D: Array[0..15] Of LongInt; Pl: H4PBuf; X,Y: LongInt;
Begin
 H4Dequant4(H4Coef,Blk*16,D,List,Qp,Sep,Dc0);
 X:=H4MbX*16+H4BlkX[Blk]*4; Y:=H4MbY*16+H4BlkY[Blk]*4;
 H4Idct4(D,H4Pics[H4Cur].Y,H4StrideY,X,Y);
End;
Procedure H4AddLuma8(B8,Qp,List: LongInt);
Var D: Array[0..63] Of LongInt; X,Y: LongInt;
Begin
 H4Dequant8(H4Coef,B8*64,D,List,Qp);
 X:=H4MbX*16+(B8 And 1)*8; Y:=H4MbY*16+(B8 Shr 1)*8;
 H4Idct8(D,H4Pics[H4Cur].Y,H4StrideY,X,Y);
End;
{ residu chroma (DC + AC) apres prediction }
Procedure H4AddChroma(Intra: Boolean);
Var C,Blk,Qp,List,Qd,Qm,A,B,Cc,Dd: LongInt; Dc: Array[0..3] Of LongInt; D:
 Array[0..15] Of LongInt; Pl: H4PBuf; HasAc: Boolean; F: Array[0..3] Of
 LongInt;
Begin
 For C:=0 To 1 Do Begin
  If (H4CurCbp Shr 4)=0 Then Break;
  Qp:=H4QpC[C];
  If Intra Then List:=1+C Else List:=4+C;
  Qd:=Qp Div 6; Qm:=Qp Mod 6;
  A:=H4ChromaDc[C,0]; B:=H4ChromaDc[C,1]; Cc:=H4ChromaDc[C,2]; Dd:=H4ChromaDc[C,
   3];
  F[0]:=A+B+Cc+Dd; F[1]:=A-B+Cc-Dd; F[2]:=A+B-Cc-Dd; F[3]:=A-B-Cc+Dd;
  For Blk:=0 To 3 Do Dc[Blk]:=H4Sar((F[Blk]*H4Ls4[List,Qm,0]) Shl Qd,5);
  If C=0 Then Pl:=H4Pics[H4Cur].U Else Pl:=H4Pics[H4Cur].V;
  For Blk:=0 To 3 Do Begin
   H4Dequant4(H4Coef,256+C*64+Blk*16,D,List,Qp,True,Dc[Blk]);
   H4Idct4(D,Pl,H4StrideC,H4MbX*8+(Blk And 1)*4,H4MbY*8+(Blk Shr 1)*4);
  End;
 End;
End;


{ ---- macrobloc intra (CAVLC) ---- }
Procedure H4StoreMb(Skip: Boolean);
Var A,I: LongInt;
Begin
 A:=H4MbAddr;
 H4SliceTab^[A]:=H4SliceNum;
 H4Pics[H4Cur].MbType^[A]:=H4CurType;
 If (H4CurType And MT_PCM)<>0 Then H4QpTab^[A]:=0 Else H4QpTab^[A]:=H4Qp;
 For I:=0 To 23 Do H4NnzTab^[A*48+I]:=H4Nnz[I];
 H4CbpTab^[A]:=(H4CurCbp And $3F) Or H4DcBits;
 For I:=0 To 3 Do H4Dir8Tab^[A*4+I]:=H4CurDir8[I];
 H4Tx8Tab^[A]:=H4CurTx8;
 H4CpmTab^[A]:=H4ChromaMode;
 If (H4CurType And (MT_I4 Or MT_I8))<>0 Then For I:=0 To 15 Do H4IpmTab^[A*16+
  I]:=H4Ipm[I]
 Else For I:=0 To 15 Do H4IpmTab^[A*16+I]:=2;
End;

Procedure H4DecodeIntraMb(T: LongInt);
Var I,J,Blk,Bx,By,B8,Prev,Rem,Pm,CbpL,CbpC,Dq,X0,Y0,Mode,Cm: LongInt; AvL,AvT,
 AvTR,AvTL: Boolean;
 Dc: Array[0..15] Of LongInt; Tx8: Boolean; Ok: Boolean; Pl: H4PBuf;
Begin
 X0:=H4MbX*16; Y0:=H4MbY*16;
 FillChar(H4Nnz,SizeOf(H4Nnz),0);
 H4CurTx8:=0; H4ChromaMode:=0; H4CurCbp:=0;
 If T=25 Then Begin
  { I_PCM }
  H4CurType:=MT_PCM;
  H4Pos:=(H4Pos+7) And -8;
  H4DcBits:=$1C0;
  Pl:=H4Pics[H4Cur].Y;
  For J:=0 To 15 Do For I:=0 To 15 Do Pl^[(Y0+J)*H4StrideY+X0+I]:=H4Bits(8);
  Pl:=H4Pics[H4Cur].U;
  For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(H4MbY*8+J)*H4StrideC+H4MbX*8+I]:=
   H4Bits(8);
  Pl:=H4Pics[H4Cur].V;
  For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(H4MbY*8+J)*H4StrideC+H4MbX*8+I]:=
   H4Bits(8);
  For I:=0 To 23 Do H4Nnz[I]:=16;
  If H4CabacOn Then Begin H4CbRange:=510; H4CbOffset:=H4Bits(9); End;
  H4CurCbp:=$2F; H4LastDqp:=0;
  H4StoreMb(False);
  Exit;
 End;
 Tx8:=False;
 If T=0 Then Begin
  If H4Pp^.Transform8x8<>0 Then Begin If H4CabacOn Then Tx8:=H4CbTx8 Else Tx8:=
   H4Bit<>0; End;
  If Tx8 Then H4CurType:=MT_I8 Else H4CurType:=MT_I4;
  If Tx8 Then H4CurTx8:=1;
  If Tx8 Then Begin
   For B8:=0 To 3 Do Begin
    Bx:=(B8 And 1)*2; By:=(B8 Shr 1)*2;
    Pm:=H4PredIpm(Bx,By);
    If H4CabacOn Then Mode:=H4CbIpm(Pm) Else Begin
     Prev:=H4Bit;
     If Prev<>0 Then Mode:=Pm Else Begin Rem:=H4Bits(3); If Rem<Pm Then Mode:=
      Rem Else Mode:=Rem+1; End;
    End;
    H4Ipm[By*4+Bx]:=Mode; H4Ipm[By*4+Bx+1]:=Mode; H4Ipm[(By+1)*4+Bx]:=Mode;
     H4Ipm[(By+1)*4+Bx+1]:=Mode;
   End;
  End Else Begin
   For Blk:=0 To 15 Do Begin
    Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
    Pm:=H4PredIpm(Bx,By);
    If H4CabacOn Then Mode:=H4CbIpm(Pm) Else Begin
     Prev:=H4Bit;
     If Prev<>0 Then Mode:=Pm Else Begin Rem:=H4Bits(3); If Rem<Pm Then Mode:=
      Rem Else Mode:=Rem+1; End;
    End;
    H4Ipm[By*4+Bx]:=Mode;
   End;
  End;
  If H4CabacOn Then H4ChromaMode:=H4CbChromaMode Else H4ChromaMode:=H4Ue;
  If H4ChromaMode>3 Then Begin H4Err:=True; Exit; End;
  If H4CabacOn Then H4CurCbp:=H4CbCbp(True) Else Begin
   I:=H4Ue;
   If I>47 Then Begin H4Err:=True; Exit; End;
   H4CurCbp:=H4GolombToIntra4X4Cbp[I];
  End;
 End Else Begin
  H4CurType:=MT_I16;
  Pm:=(T-1) And 3; CbpC:=((T-1) Shr 2) Mod 3; If T>=13 Then CbpL:=15 Else CbpL:=
   0;
  H4I16Mode:=Pm;
  H4CurCbp:=CbpL Or (CbpC Shl 4);
  If H4CabacOn Then H4ChromaMode:=H4CbChromaMode Else H4ChromaMode:=H4Ue;
  If H4ChromaMode>3 Then Begin H4Err:=True; Exit; End;
 End;
 CbpL:=H4CurCbp And 15; CbpC:=H4CurCbp Shr 4;
 If (H4CurCbp>0) Or (H4CurType=MT_I16) Then Begin
  If H4CabacOn Then Dq:=H4CbDqp Else Dq:=H4Se;
  If (Dq<-26) Or (Dq>25) Then Begin H4Err:=True; Exit; End;
  H4Qp:=(H4Qp+Dq+52) Mod 52;
  If Dq<>0 Then H4LastDqp:=1 Else H4LastDqp:=0;
 End Else H4LastDqp:=0;
 H4QpC[0]:=H4ChromaQp(H4Qp,H4Pp^.ChromaQpOffset); H4QpC[1]:=H4ChromaQp(H4Qp,
  H4Pp^.ChromaQpOffset2);
 If H4CabacOn Then Begin
  Ok:=H4LumaCabac(Tx8,H4CurType=MT_I16,CbpL);
  If Ok Then Ok:=H4ChromaCabac(CbpC);
 End Else Begin
  Ok:=H4LumaCavlc(Tx8,H4CurType=MT_I16,CbpL);
  If Ok Then Ok:=H4ChromaCavlc(CbpC);
 End;
 If Not Ok Then Begin H4Err:=True; Exit; End;
 { reconstruction luma }
 Pl:=H4Pics[H4Cur].Y;
 If H4CurType=MT_I4 Then Begin
  For Blk:=0 To 15 Do Begin
   Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
   AvL:=(Bx>0) Or H4IiA; AvT:=(By>0) Or H4IiB;
   If (Bx>0) And (By>0) Then AvTL:=True Else If Bx>0 Then AvTL:=H4IiB Else If
    By>0 Then AvTL:=H4IiA Else AvTL:=H4IiD;
   If By=0 Then Begin If Bx<3 Then AvTR:=H4IiB Else AvTR:=H4IiC; End
   Else If Bx=3 Then AvTR:=False
   Else AvTR:=H4BlkOrder[(By-1)*4+Bx+1]<H4BlkOrder[By*4+Bx];
   If Not H4OkMode(H4Ipm[By*4+Bx],AvL,AvT,AvTL) Then Begin H4Err:=True; Exit;
    End;
   H4Pred4x4(Pl,H4StrideY,X0+Bx*4,Y0+By*4,H4Ipm[By*4+Bx],AvL,AvT,AvTR,AvTL);
   If ((CbpL Shr (Blk Shr 2)) And 1)<>0 Then H4AddLuma4(Blk,H4Qp,0,False,0);
  End;
 End Else If H4CurType=MT_I8 Then Begin
  For B8:=0 To 3 Do Begin
   Bx:=(B8 And 1)*2; By:=(B8 Shr 1)*2;
   AvL:=(Bx>0) Or H4IiA; AvT:=(By>0) Or H4IiB;
   If (Bx>0) And (By>0) Then AvTL:=True Else If Bx>0 Then AvTL:=H4IiB Else If
    By>0 Then AvTL:=H4IiA Else AvTL:=H4IiD;
   Case B8 Of 0: AvTR:=H4IiB; 1: AvTR:=H4IiC; 2: AvTR:=True; Else AvTR:=False;
    End;
   If Not H4OkMode(H4Ipm[By*4+Bx],AvL,AvT,AvTL) Then Begin H4Err:=True; Exit;
    End;
   H4Pred8x8(Pl,H4StrideY,X0+Bx*4,Y0+By*4,H4Ipm[By*4+Bx],AvL,AvT,AvTR,AvTL);
   If ((CbpL Shr B8) And 1)<>0 Then H4AddLuma8(B8,H4Qp,0);
  End;
 End Else Begin
  If Not H4OkMode16(H4I16Mode,H4IiA,H4IiB,H4IiD) Then Begin H4Err:=True; Exit;
   End;
  H4Pred16x16(Pl,H4StrideY,X0,Y0,H4I16Mode,H4IiA,H4IiB);
  H4LumaDcTransform(H4LumaDc,Dc,H4Qp);
  For Blk:=0 To 15 Do Begin
   Bx:=H4BlkX[Blk]; By:=H4BlkY[Blk];
   H4AddLuma4(Blk,H4Qp,0,True,Dc[By*4+Bx]);
  End;
 End;
 { chroma }
 If Not H4OkModeC(H4ChromaMode,H4IiA,H4IiB,H4IiD) Then Begin H4Err:=True; Exit;
  End;
 H4PredChroma(H4Pics[H4Cur].U,H4StrideC,H4MbX*8,H4MbY*8,H4ChromaMode,H4IiA,
  H4IiB);
 H4PredChroma(H4Pics[H4Cur].V,H4StrideC,H4MbX*8,H4MbY*8,H4ChromaMode,H4IiA,
  H4IiB);
 H4AddChroma(True);
 H4StoreMb(False);
End;


{ ---- filtre de deblocage ---- }
Var H4SlDis,H4SlAlpha,H4SlBeta,H4SlCb,H4SlCr: H4PBuf;   { par numero de
 tranche }

Procedure H4FiltLuma(Pl: H4PBuf; Pos,Step,Bs,Alpha,Beta,Tc0: LongInt);
Var P0,P1,P2,P3,Q0,Q1,Q2,Q3,Ap,Aq,Tc,D,V: LongInt;
Begin
 P0:=Pl^[Pos-Step]; P1:=Pl^[Pos-2*Step]; Q0:=Pl^[Pos]; Q1:=Pl^[Pos+Step];
 If (Abs(P0-Q0)>=Alpha) Or (Abs(P1-P0)>=Beta) Or (Abs(Q1-Q0)>=Beta) Then Exit;
 P2:=Pl^[Pos-3*Step]; Q2:=Pl^[Pos+2*Step];
 Ap:=Abs(P2-P0); Aq:=Abs(Q2-Q0);
 If Bs<4 Then Begin
  Tc:=Tc0;
  If Ap<Beta Then Inc(Tc);
  If Aq<Beta Then Inc(Tc);
  D:=H4Clip3(-Tc,Tc,H4Sar(((Q0-P0) Shl 2)+(P1-Q1)+4,3));
  Pl^[Pos-Step]:=H4Clip(P0+D); Pl^[Pos]:=H4Clip(Q0-D);
  If Ap<Beta Then Pl^[Pos-2*Step]:=P1+H4Clip3(-Tc0,Tc0,H4Sar(P2+((P0+Q0+1) Shr
   1)-(P1 Shl 1),1));
  If Aq<Beta Then Pl^[Pos+Step]:=Q1+H4Clip3(-Tc0,Tc0,H4Sar(Q2+((P0+Q0+1) Shr 1)-
   (Q1 Shl 1),1));
 End Else Begin
  P3:=Pl^[Pos-4*Step]; Q3:=Pl^[Pos+3*Step];
  If (Ap<Beta) And (Abs(P0-Q0)<((Alpha Shr 2)+2)) Then Begin
   Pl^[Pos-Step]:=(P2+2*P1+2*P0+2*Q0+Q1+4) Shr 3;
   Pl^[Pos-2*Step]:=(P2+P1+P0+Q0+2) Shr 2;
   Pl^[Pos-3*Step]:=(2*P3+3*P2+P1+P0+Q0+4) Shr 3;
  End Else Pl^[Pos-Step]:=(2*P1+P0+Q1+2) Shr 2;
  If (Aq<Beta) And (Abs(P0-Q0)<((Alpha Shr 2)+2)) Then Begin
   Pl^[Pos]:=(P1+2*P0+2*Q0+2*Q1+Q2+4) Shr 3;
   Pl^[Pos+Step]:=(P0+Q0+Q1+Q2+2) Shr 2;
   Pl^[Pos+2*Step]:=(2*Q3+3*Q2+Q1+Q0+P0+4) Shr 3;
  End Else Pl^[Pos]:=(2*Q1+Q0+P1+2) Shr 2;
 End;
End;
Procedure H4FiltChroma(Pl: H4PBuf; Pos,Step,Bs,Alpha,Beta,Tc0: LongInt);
Var P0,P1,Q0,Q1,Tc,D: LongInt;
Begin
 P0:=Pl^[Pos-Step]; P1:=Pl^[Pos-2*Step]; Q0:=Pl^[Pos]; Q1:=Pl^[Pos+Step];
 If (Abs(P0-Q0)>=Alpha) Or (Abs(P1-P0)>=Beta) Or (Abs(Q1-Q0)>=Beta) Then Exit;
 If Bs<4 Then Begin
  Tc:=Tc0+1;
  D:=H4Clip3(-Tc,Tc,H4Sar(((Q0-P0) Shl 2)+(P1-Q1)+4,3));
  Pl^[Pos-Step]:=H4Clip(P0+D); Pl^[Pos]:=H4Clip(Q0-D);
 End Else Begin
  Pl^[Pos-Step]:=(2*P1+P0+Q1+2) Shr 2;
  Pl^[Pos]:=(2*Q1+Q0+P1+2) Shr 2;
 End;
End;

{ coefficients non nuls du bloc 4x4 (en tenant compte de la transformee 8x8) }
Function H4HasCoef(Addr,Blk: LongInt): Boolean;
Var Bx,By,B0: LongInt;
Begin
 If H4Tx8Tab^[Addr]<>0 Then Begin
  Bx:=Blk And 3; By:=Blk Shr 2; B0:=(By And 2)*4+(Bx And 2);
  H4HasCoef:=(H4NnzTab^[Addr*48+B0]+H4NnzTab^[Addr*48+B0+1]+H4NnzTab^[Addr*48+
   B0+4]+H4NnzTab^[Addr*48+B0+5])>0;
 End Else H4HasCoef:=H4NnzTab^[Addr*48+Blk]>0;
End;

Function H4BsInter(Addr,Blk,AddrP,BlkP: LongInt): LongInt; Forward;

Function H4Bs(AddrQ,BlkQ,AddrP,BlkP: LongInt; MbEdge: Boolean): LongInt;
Begin
 If ((H4Pics[H4Cur].MbType^[AddrQ] Or H4Pics[H4Cur].MbType^[AddrP]) And
  MT_INTRA)<>0 Then Begin
  If MbEdge Then H4Bs:=4 Else H4Bs:=3; Exit;
 End;
 If H4HasCoef(AddrQ,BlkQ) Or H4HasCoef(AddrP,BlkP) Then Begin H4Bs:=2; Exit;
  End;
 H4Bs:=H4BsInter(AddrQ,BlkQ,AddrP,BlkP);
End;

Procedure H4DeblockMb(Mx,My: LongInt);
Var Addr,Sn,AOff,BOff,E,Seg,Ln,Dir,X0,Y0,AddrP,BlkQ,BlkP,Bs: LongInt;
 Tx8,Edge0Ok: Boolean; Bsv: Array[0..3] Of LongInt; QpQ,QpP,QpAv,IdxA,IdxB,
  Alpha,Beta,Tc0,Pos,Step,Cq,Cp: LongInt; Pl: H4PBuf; Cb,Cr: LongInt;
 Qc: LongInt;
Begin
 Addr:=My*H4MbW+Mx; Sn:=H4SliceTab^[Addr];
 If Sn<0 Then Exit;
 If H4SlDis^[Sn]=1 Then Exit;
 AOff:=ShortInt(H4SlAlpha^[Sn]); BOff:=ShortInt(H4SlBeta^[Sn]);
 Tx8:=H4Tx8Tab^[Addr]<>0;
 X0:=Mx*16; Y0:=My*16;
 For Dir:=0 To 1 Do Begin
  { Dir 0 : bords verticaux ; 1 : bords horizontaux }
  For E:=0 To 3 Do Begin
   If Tx8 And Odd(E) Then Continue;
   If E=0 Then Begin
    If Dir=0 Then Begin
     If Mx=0 Then Continue;
     AddrP:=Addr-1;
    End Else Begin
     If My=0 Then Continue;
     AddrP:=Addr-H4MbW;
    End;
    If (H4SlDis^[Sn]=2) And (H4SliceTab^[AddrP]<>Sn) Then Continue;
   End Else AddrP:=Addr;
   For Seg:=0 To 3 Do Begin
    If Dir=0 Then Begin
     BlkQ:=Seg*4+E; If E=0 Then BlkP:=Seg*4+3 Else BlkP:=Seg*4+E-1;
    End Else Begin
     BlkQ:=E*4+Seg; If E=0 Then BlkP:=12+Seg Else BlkP:=(E-1)*4+Seg;
    End;
    Bsv[Seg]:=H4Bs(Addr,BlkQ,AddrP,BlkP,E=0);
   End;
   QpQ:=H4QpTab^[Addr]; QpP:=H4QpTab^[AddrP];
   { luma }
   QpAv:=(QpQ+QpP+1) Shr 1;
   IdxA:=H4Clip3(0,51,QpAv+AOff); IdxB:=H4Clip3(0,51,QpAv+BOff);
   Alpha:=H4Alpha[52+IdxA]; Beta:=H4Beta[52+IdxB];
   If (Alpha<>0) And (Beta<>0) Then
    For Seg:=0 To 3 Do If Bsv[Seg]>0 Then Begin
     If Bsv[Seg]<4 Then Tc0:=H4Tc0[(52+IdxA)*4+Bsv[Seg]] Else Tc0:=0;
     For Ln:=0 To 3 Do Begin
      If Dir=0 Then Begin Pos:=(Y0+Seg*4+Ln)*H4StrideY+X0+E*4; Step:=1; End
      Else Begin Pos:=(Y0+E*4)*H4StrideY+X0+Seg*4+Ln; Step:=H4StrideY; End;
      H4FiltLuma(H4Pics[H4Cur].Y,Pos,Step,Bsv[Seg],Alpha,Beta,Tc0);
     End;
    End;
   { chroma : aretes 0 et 2 }
   If (E=0) Or (E=2) Then
    For Cb:=0 To 1 Do Begin
     If Cb=0 Then Begin Pl:=H4Pics[H4Cur].U; Cq:=H4SlCb^[Sn]; End Else Begin
      Pl:=H4Pics[H4Cur].V; Cq:=H4SlCr^[Sn]; End;
     Qc:=H4ChromaQp(QpQ,ShortInt(Cq)); Cp:=H4ChromaQp(QpP,ShortInt(Cq));
     QpAv:=(Qc+Cp+1) Shr 1;
     IdxA:=H4Clip3(0,51,QpAv+AOff); IdxB:=H4Clip3(0,51,QpAv+BOff);
     Alpha:=H4Alpha[52+IdxA]; Beta:=H4Beta[52+IdxB];
     If (Alpha=0) Or (Beta=0) Then Continue;
     For Seg:=0 To 3 Do If Bsv[Seg]>0 Then Begin
      If Bsv[Seg]<4 Then Tc0:=H4Tc0[(52+IdxA)*4+Bsv[Seg]] Else Tc0:=0;
      For Ln:=0 To 1 Do Begin
       If Dir=0 Then Begin Pos:=(My*8+Seg*2+Ln)*H4StrideC+Mx*8+E*2; Step:=1; End
       Else Begin Pos:=(My*8+E*2)*H4StrideC+Mx*8+Seg*2+Ln; Step:=H4StrideC; End;
       H4FiltChroma(Pl,Pos,Step,Bsv[Seg],Alpha,Beta,Tc0);
      End;
     End;
    End;
  End;
 End;
End;




{ ---- gestion d'une image ---- }
Var
 H4NalBuf: H4PBuf; H4NalCap: LongInt;
 H4Began: Boolean;
 H4CurDur: Int64;
 H4FramesOut: LongInt;
 H4PicOpen: Boolean;            { une image est en cours de decodage }
 H4PicSeqW,H4PicSeqH: LongInt;
 H4ErrCount: LongInt;

Procedure H4FreeTabs;
Begin
 If H4SliceTab<>Nil Then Begin
  FreeMem(H4SliceTab); FreeMem(H4QpTab); FreeMem(H4NnzTab); FreeMem(H4IpmTab);
   FreeMem(H4CpmTab); FreeMem(H4Tx8Tab);
  FreeMem(H4MvdTab); FreeMem(H4Dir8Tab); FreeMem(H4CbfTab); FreeMem(H4CbpTab);
  FreeMem(H4SlDis); FreeMem(H4SlAlpha); FreeMem(H4SlBeta); FreeMem(H4SlCb);
   FreeMem(H4SlCr);
  H4SliceTab:=Nil;
 End;
End;
Procedure H4AllocTabs;
Begin
 H4FreeTabs;
 GetMem(H4SliceTab,H4MbNum*4+16); GetMem(H4QpTab,H4MbNum+16); GetMem(H4NnzTab,
  H4MbNum*48+16); GetMem(H4IpmTab,H4MbNum*16+16);
 GetMem(H4CpmTab,H4MbNum+16); GetMem(H4Tx8Tab,H4MbNum+16); GetMem(H4MvdTab,
  H4MbNum*64+16); GetMem(H4Dir8Tab,H4MbNum*4+16);
 GetMem(H4CbfTab,H4MbNum*48+16); GetMem(H4CbpTab,H4MbNum*2+16);
 GetMem(H4SlDis,H4MbNum+16); GetMem(H4SlAlpha,H4MbNum+16); GetMem(H4SlBeta,
  H4MbNum+16); GetMem(H4SlCb,H4MbNum+16); GetMem(H4SlCr,H4MbNum+16);
End;

{ active un SPS (nouvelle sequence) }
Function H4Activate(Id: LongInt): Boolean;
Var S: ^TH4Sps;
Begin
 H4Activate:=False;
 S:=@H4Sps[Id];
 If (S^.ChromaFormat<>1) Or (S^.BitDepthY<>8) Or (S^.BitDepthC<>8) Or (
  S^.FrameMbsOnly=0) Or (S^.TransformBypass<>0) Then Exit;
 If (Not H4Started) Or (H4ActSps<>Id) Or (H4MbW<>S^.MbW) Or (H4MbH<>S^.MbH) Then
  Begin
  If H4Started Then H4Bump(True);
  H4FreeAll;
  H4MbW:=S^.MbW; H4MbH:=S^.MbH; H4MbNum:=H4MbW*H4MbH; H4StrideY:=H4MbW*16;
   H4StrideC:=H4MbW*8;
  H4AllocTabs;
  H4ActSps:=Id; H4Started:=True; H4Cur:=-1; H4Seq:=H4Seq+1;
  If S^.BitstreamRestriction<>0 Then H4ReorderDepth:=S^.NumReorderFrames Else
   H4ReorderDepth:=15;
  If H4ReorderDepth>15 Then H4ReorderDepth:=15;
 End;
 H4Activate:=True;
End;



{ ---- sortie : recadrage, YUV 4:2:0 -> RGB24, appel du puits ---- }
Var
 H4Stop: Boolean;                     { le puits a demande l'arret }
 H4Rgb: H4PBuf; H4RgbCap: LongInt;    { image RGB24 de sortie }
 H4Fps100: LongInt; H4FpsSent: Boolean;
 H4TabMat: LongInt;
 H4TY,H4TRV,H4TGU,H4TGV,H4TBU: Array[0..255] Of LongInt;
 H4TClip: Array[0..1535] Of Byte;     { saturation, decalage 512 }

{ matrice : 0 = BT.601 limitee, 1 = BT.709 limitee, 2 = BT.601 pleine, 3 =
 BT.709 pleine }
Procedure H4SetupRgb(Mat: LongInt);
Var I: LongInt; Ys,Kr,Kgu,Kgv,Kb: Double; V: LongInt;
Begin
 If H4TabMat=Mat Then Exit;
 H4TabMat:=Mat;
 For I:=0 To 1535 Do Begin
  V:=I-512; If V<0 Then V:=0; If V>255 Then V:=255; H4TClip[I]:=V;
 End;
 If (Mat And 2)<>0 Then Ys:=1.0 Else Ys:=255.0/219.0;
 Case Mat Of
  0: Begin Kr:=1.596; Kgu:=0.392; Kgv:=0.813; Kb:=2.017; End;
  1: Begin Kr:=1.793; Kgu:=0.213; Kgv:=0.533; Kb:=2.112; End;
  2: Begin Kr:=1.402; Kgu:=0.344; Kgv:=0.714; Kb:=1.772; End;
 Else Begin Kr:=1.5748; Kgu:=0.1873; Kgv:=0.4681; Kb:=1.8556; End;
 End;
 For I:=0 To 255 Do Begin
  If (Mat And 2)<>0 Then H4TY[I]:=Round(I*65536.0)+512*65536+32768
  Else H4TY[I]:=Round((I-16)*Ys*65536.0)+512*65536+32768;
  H4TRV[I]:=Round((I-128)*Kr*65536.0);
  H4TGU[I]:=Round((I-128)*Kgu*65536.0);
  H4TGV[I]:=Round((I-128)*Kgv*65536.0);
  H4TBU[I]:=Round((I-128)*Kb*65536.0);
 End;
End;

{ convertit une image YUV 4:2:0 (fenetre L,T,W,H) en RGB24 et l'envoie au puits }
Procedure H4ShowYuv(SrcY,SrcU,SrcV: H4PBuf; SY,SC,L,T,W,H,Mat: LongInt);
Var X,Y,Need,Ru,Gu,Yv,Cb,Ro,Co,O: LongInt;
 PY,PU,PV,Dst: H4PBuf; S: ^TH4Sps; F: Double;
Begin
 If H4Stop Then Exit;
 If (W<=0) Or (H<=0) Or (W>16384) Or (H>16384) Then Exit;
 Need:=W*H*3+16;
 If H4RgbCap<Need Then Begin
  If H4Rgb<>Nil Then FreeMem(H4Rgb,H4RgbCap);
  H4Rgb:=Nil; H4RgbCap:=0;
  GetMem(H4Rgb,Need); H4RgbCap:=Need;
 End;
 H4SetupRgb(Mat);
 For Y:=0 To H-1 Do Begin
  Ro:=(T+Y)*SY+L;
  Co:=((T+Y) Div 2)*SC+L Div 2;
  PY:=H4PBuf(@SrcY^[Ro]); PU:=H4PBuf(@SrcU^[Co]); PV:=H4PBuf(@SrcV^[Co]);
  Dst:=H4PBuf(@H4Rgb^[Y*W*3]);
  O:=0;
  For X:=0 To W-1 Do Begin
   Cb:=X Shr 1;
   Yv:=H4TY[PY^[X]];
   Ru:=PV^[Cb]; Gu:=PU^[Cb];
   Dst^[O]:=H4TClip[(Yv+H4TRV[Ru]) Shr 16];
   Dst^[O+1]:=H4TClip[(Yv-H4TGU[Gu]-H4TGV[Ru]) Shr 16];
   Dst^[O+2]:=H4TClip[(Yv+H4TBU[Gu]) Shr 16];
   Inc(O,3);
  End;
 End;
 If Not H4FpsSent Then Begin
  H4FpsSent:=True;
  If (H4Fps100<=0) And (H4ActSps>=0) Then Begin
   S:=@H4Sps[H4ActSps];
   If (S^.TimingInfo<>0) And (S^.NumUnitsInTick>0) And (S^.TimeScale>0) Then
    Begin
    F:=S^.TimeScale/(2.0*S^.NumUnitsInTick);
    If (F>=1) And (F<=300) Then H4Fps100:=Round(F*100);
   End;
  End;
  If H4Fps100>0 Then ConfSetFps(H4Fps100);
 End;
 Inc(H4FramesOut);
 If Not ConfEmit(W,H,H4Rgb) Then H4Stop:=True;
End;

Procedure H4EmitPic(I: LongInt);
Var P: ^TH4Pic;
Begin
 P:=@H4Pics[I];
 H4ShowYuv(P^.Y,P^.U,P^.V,P^.EmSY,P^.EmSC,P^.EmL,P^.EmT,P^.EmW,P^.EmH,P^.EmMat);
End;

Procedure H4InitState;
Var I: LongInt;
Begin
 FillChar(H4Sps,SizeOf(H4Sps),0); FillChar(H4Pps,SizeOf(H4Pps),0);
 FillChar(H4Pics,SizeOf(H4Pics),0);
 H4Started:=False; H4PicOpen:=False; H4Began:=False; H4Cur:=-1; H4OutCount:=0;
  H4FramesOut:=0; H4ErrCount:=0;
 H4PrevPocMsb:=0; H4PrevPocLsb:=0; H4PrevFrameNumOffset:=0; H4FrameNumOffset:=0;
  H4PrevFrameNum:=0; H4PrevRefFrameNum:=0;
 H4CurDur:=0;
 H4PrevHadMmco5:=False; H4NextId:=1; H4Seq:=0; H4NalBuf:=Nil; H4NalCap:=0;
  H4SliceTab:=Nil; H4ActSps:=-1; H4MbW:=0; H4MbH:=0;
 H4Stop:=False; H4Rgb:=Nil; H4RgbCap:=0; H4Fps100:=0; H4FpsSent:=False;
 H4TabMat:=-1;
 H4InitTabs;
End;

{ libere tout ce que le decodeur a alloue }
Procedure H4Cleanup;
Begin
 H4FreeAll; H4FreeTabs;
 If H4NalBuf<>Nil Then FreeMem(H4NalBuf,H4NalCap); H4NalBuf:=Nil; H4NalCap:=0;
 If H4Rgb<>Nil Then FreeMem(H4Rgb,H4RgbCap); H4Rgb:=Nil; H4RgbCap:=0;
 H4FreeVlcs;
 H4Started:=False;
End;


{ recadrage et matrice de couleur d'une image, d'apres le SPS actif }
Procedure H4CropInfo(I: LongInt; Var S: TH4Sps);
Var CL,CR,CT,CB,W,H,Mat: LongInt;
Begin
 CL:=S.CropL*2; CR:=S.CropR*2; CT:=S.CropT*2; CB:=S.CropB*2;
 W:=H4MbW*16-CL-CR; H:=H4MbH*16-CT-CB;
 If (W<=0) Or (H<=0) Or (CL<0) Or (CR<0) Or (CT<0) Or (CB<0) Then Begin
  CL:=0; CR:=0; CT:=0; CB:=0; W:=H4MbW*16; H:=H4MbH*16; End;
 Mat:=0;
 If (S.VuiPresent<>0) And (S.ColorSpace=1) Then Mat:=1
 Else If (H>=720) And Not ((S.VuiPresent<>0) And ((S.ColorSpace=5) Or (
  S.ColorSpace=6))) Then Mat:=1;
 If (S.VuiPresent<>0) And (S.FullRange=1) Then Mat:=Mat+2;
 With H4Pics[I] Do Begin
  EmL:=CL; EmT:=CT; EmW:=W; EmH:=H; EmSY:=H4StrideY; EmSC:=H4StrideC;
  EmMat:=Mat;
 End;
End;

Procedure H4FinishPicture;
Var Mx,My,I,Mn: LongInt; S: ^TH4Sps; P: ^TH4Pic; Top,Bot: LongInt;
Begin
 If Not H4PicOpen Then Exit;
 H4PicOpen:=False;
 S:=@H4Sps[H4ActSps];
 For My:=0 To H4MbH-1 Do For Mx:=0 To H4MbW-1 Do H4DeblockMb(Mx,My);
 P:=@H4Pics[H4Cur];
 H4Marking(H4FirstSh,S^,H4Cur);
 If P^.Mmco5 Then Begin
  { effet de mmco5 sur la numerotation et le POC }
  Mn:=P^.PocTop; If P^.PocBot<Mn Then Mn:=P^.PocBot;
  P^.PocTop:=P^.PocTop-Mn; P^.PocBot:=P^.PocBot-Mn; P^.Poc:=P^.PocTop; If
   P^.PocBot<P^.Poc Then P^.Poc:=P^.PocBot;
  P^.FrameNum:=0;
  H4PrevPocMsb:=0; H4PrevPocLsb:=P^.PocTop; H4PrevHadMmco5:=True;
  H4PrevFrameNum:=0; H4PrevFrameNumOffset:=0; H4PrevRefFrameNum:=0;
 End Else Begin
  H4PrevHadMmco5:=False;
  H4PrevFrameNum:=H4FirstSh.FrameNum;
  H4PrevFrameNumOffset:=H4FrameNumOffset;
  If H4FirstSh.NalRefIdc<>0 Then H4PrevRefFrameNum:=H4FirstSh.FrameNum;
 End;
 If (H4FirstSh.Idr<>0) Or P^.Mmco5 Then H4Bump(True);
 P^.Output:=True;
 H4OutQueue[H4OutCount]:=H4Cur; Inc(H4OutCount);
 H4Bump(False);
End;

Procedure H4StartPicture(Var Sh: TH4Slice);
Var S: ^TH4Sps; Top,Bot,I: LongInt;
Begin
 S:=@H4Sps[H4ActSps];
 If Sh.Idr<>0 Then Begin
  H4PrevRefFrameNum:=0;
 End;
 H4Cur:=H4NewPic;
 If H4Cur<0 Then Begin
  { DPB plein : sortie forcee }
  H4Bump(True);
  H4Cur:=H4NewPic;
  If H4Cur<0 Then Begin H4Err:=True; Exit; End;
 End;
 H4ComputePoc(Sh,S^,Top,Bot);
 H4CropInfo(H4Cur,S^);
 With H4Pics[H4Cur] Do Begin
  PocTop:=Top; PocBot:=Bot; If Bot<Top Then Poc:=Bot Else Poc:=Top;
  FrameNum:=Sh.FrameNum; FrameNumWrap:=Sh.FrameNum; Idr:=Sh.Idr<>0;
  RefState:=0;
 End;
 FillChar(H4SliceTab^,H4MbNum*4,255);
 H4SliceNum:=-1;
 H4FirstSh:=Sh;
 H4PicOpen:=True;
End;


{ ---- donnees de tranche et unites NAL ---- }
Procedure H4InterMb(T: LongInt); Forward;   { macrobloc inter (P/B) : ajoute
 plus loin }
Procedure H4SkipMb; Forward;

Procedure H4SliceDataCabac(Var Sh: TH4Slice);
Var T: LongInt; Skip,Fin: Boolean;
Begin
 H4MbAddr:=Sh.FirstMb;
 If H4MbAddr>=H4MbNum Then Begin H4Err:=True; Exit; End;
 H4Qp:=Sh.Qp; H4LastDqp:=0; H4SliceType:=Sh.SliceType;
 H4CabacInit(Sh.Qp,Sh.CabacInitIdc,(Sh.SliceType=2) Or (Sh.SliceType=4));
 Repeat
  If H4MbAddr>=H4MbNum Then Break;
  H4MbX:=H4MbAddr Mod H4MbW; H4MbY:=H4MbAddr Div H4MbW;
  H4SetupNeighbors;
  Skip:=False;
  If (H4SliceType<>2) And (H4SliceType<>4) Then Skip:=H4CbSkip;
  If Skip Then H4SkipMb Else Begin
   Case H4SliceType Of
    2,4: T:=H4CbIntraType(3,True);
    1: T:=H4CbMbTypeB;
   Else T:=H4CbMbTypeP;
   End;
   If H4Err Then Exit;
   Case H4SliceType Of
    2,4: H4DecodeIntraMb(T);
    0,3: If T<5 Then H4InterMb(T) Else H4DecodeIntraMb(T-5);
    1: If T<23 Then H4InterMb(T) Else H4DecodeIntraMb(T-23);
   End;
  End;
  If H4Err Then Exit;
  Fin:=H4CbTerm<>0;
  Inc(H4MbAddr);
 Until Fin;
End;

Procedure H4SliceData(Var Sh: TH4Slice);
Var T,Run,I: LongInt; More,PrevSkipped: Boolean;
Begin
 H4CabacOn:=H4Pp^.Cabac<>0;
 If H4CabacOn Then Begin H4SliceDataCabac(Sh); Exit; End;
 H4MbAddr:=Sh.FirstMb;
 If H4MbAddr>=H4MbNum Then Begin H4Err:=True; Exit; End;
 H4Qp:=Sh.Qp; H4LastDqp:=0; H4SliceType:=Sh.SliceType;
 More:=True; PrevSkipped:=False;
 While More Do Begin
  If H4MbAddr>=H4MbNum Then Break;
  H4MbX:=H4MbAddr Mod H4MbW; H4MbY:=H4MbAddr Div H4MbW;
  If (H4SliceType<>2) And (H4SliceType<>4) Then Begin
   { mb_skip_run }
   Run:=H4Ue;
   If H4Err Then Exit;
   While Run>0 Do Begin
    If H4MbAddr>=H4MbNum Then Begin H4Err:=True; Exit; End;
    H4MbX:=H4MbAddr Mod H4MbW; H4MbY:=H4MbAddr Div H4MbW;
    H4SetupNeighbors;
    H4SkipMb;
    Inc(H4MbAddr); Dec(Run);
   End;
   More:=H4MoreData;
   If Not More Then Break;
   If H4MbAddr>=H4MbNum Then Break;
   H4MbX:=H4MbAddr Mod H4MbW; H4MbY:=H4MbAddr Div H4MbW;
  End;
  H4SetupNeighbors;
  T:=H4Ue;
  If H4Err Then Exit;
  Case H4SliceType Of
   2,4: Begin If T>25 Then Begin H4Err:=True; Exit; End; H4DecodeIntraMb(T);
    End;
   0,3: Begin
    If T<5 Then H4InterMb(T) Else Begin If T>30 Then Begin H4Err:=True; Exit;
     End; H4DecodeIntraMb(T-5); End;
   End;
   1: Begin
    If T<23 Then H4InterMb(T) Else Begin If T>48 Then Begin H4Err:=True; Exit;
     End; H4DecodeIntraMb(T-23); End;
   End;
  End;
  If H4Err Then Exit;
  Inc(H4MbAddr);
  More:=H4MoreData;
 End;
End;

{ detection d'un nouveau point d'acces (7.4.1.2.4) }
Function H4NewAu(Var Sh: TH4Slice): Boolean;
Var A: ^TH4Slice;
Begin
 A:=@H4FirstSh;
 H4NewAu:=(Sh.FrameNum<>A^.FrameNum) Or (Sh.PpsId<>A^.PpsId) Or (
  Sh.FieldPic<>A^.FieldPic) Or (Sh.BottomField<>A^.BottomField)
  Or ((Sh.NalRefIdc=0)<>(A^.NalRefIdc=0)) Or (Sh.Idr<>A^.Idr) Or ((Sh.Idr<>0)
   And (Sh.IdrPicId<>A^.IdrPicId))
  Or (Sh.PocLsb<>A^.PocLsb) Or (Sh.DeltaPocBottom<>A^.DeltaPocBottom) Or (
   Sh.DeltaPoc[0]<>A^.DeltaPoc[0]) Or (Sh.DeltaPoc[1]<>A^.DeltaPoc[1]);
End;

{ une unite NAL (sans code de debut) }
Procedure H4HandleNal(P: H4PBuf; Len: LongInt; Pts: Int64);
Var NalType,NalRef,I,J,Zeros,R: LongInt; Sh: TH4Slice; NewPic: Boolean; S:
 ^TH4Sps;
Begin
 If Len<2 Then Exit;
 NalType:=P^[0] And 31; NalRef:=(P^[0] Shr 5) And 3;
 If (NalType<>1) And (NalType<>5) And (NalType<>7) And (NalType<>8) And (
  NalType<>9) And (NalType<>11) And (NalType<>10) And (NalType<>6) Then Exit;
 { retrait des octets d'emulation }
 If H4NalCap<Len+64 Then Begin If H4NalBuf<>Nil Then FreeMem(H4NalBuf);
  H4NalCap:=Len+4096; GetMem(H4NalBuf,H4NalCap); End;
 J:=0; Zeros:=0;
 For I:=1 To Len-1 Do Begin
  If (Zeros>=2) And (P^[I]=3) Then Begin Zeros:=0; Continue; End;
  H4NalBuf^[J]:=P^[I]; Inc(J);
  If P^[I]=0 Then Inc(Zeros) Else Zeros:=0;
 End;
 FillChar(H4NalBuf^[J],16,0);
 H4Rb:=H4NalBuf; H4RbSize:=J; H4Pos:=0; H4Err:=False;
 Case NalType Of
  7: Begin H4FinishPicture; H4ParseSps; End;
  8: Begin H4FinishPicture; H4ParsePps; End;
  6,9,10,11: H4FinishPicture;
  1,5: Begin
   If H4ParseSlice(Sh,NalType,NalRef)<>0 Then Begin Inc(H4ErrCount); Exit; End;
   If Sh.RedundantPicCnt<>0 Then Exit;
   H4Pp:=@H4Pps[Sh.PpsId]; H4Sp:=@H4Sps[H4Pp^.SpsId];
   If Sh.FieldPic<>0 Then Begin Inc(H4ErrCount); Exit; End;
   NewPic:=(Not H4PicOpen) Or H4NewAu(Sh);
   If NewPic Then Begin
    H4FinishPicture;
    If Not H4Activate(H4Pp^.SpsId) Then Begin Inc(H4ErrCount); Exit; End;
    H4StartPicture(Sh);
    If H4Err Then Exit;
    H4Pics[H4Cur].Pts:=Pts; H4Pics[H4Cur].Dur:=H4CurDur;
   End;
   If Not H4PicOpen Then Exit;
   Inc(H4SliceNum);
   Sh.SliceNum:=H4SliceNum;
   H4SetupQuant;
   H4SlDis^[H4SliceNum]:=Sh.DisableDeblock; H4SlAlpha^[H4SliceNum]:=Sh.AlphaOff
    And 255; H4SlBeta^[H4SliceNum]:=Sh.BetaOff And 255;
   H4SlCb^[H4SliceNum]:=H4Pp^.ChromaQpOffset And 255; H4SlCr^[H4SliceNum]:=
    H4Pp^.ChromaQpOffset2 And 255;
   H4BuildRefLists(Sh,H4Sp^,H4Cur);
   H4CurSh:=Sh;
   H4SliceData(Sh);
   If H4Err Then Inc(H4ErrCount);
  End;
 End;
End;

{ ---- couche inter : vecteurs, direct, compensation de mouvement, ponderation
 ---- }
Const
 H4BPair: Array[0..8,0..1] Of Byte=((1,1),(2,2),(1,2),(2,1),(1,3),(2,3),(3,1),(
  3,2),(3,3));
 H4SubBPred: Array[0..12] Of Byte=(0,1,2,3,1,1,2,2,3,3,1,2,3);
 H4SubBShape: Array[0..12] Of Byte=(0,0,0,0,1,2,1,2,1,2,3,3,3);
Var
 H4Done: LongInt;                         { blocs 4x4 du macrobloc deja decodes
  (bit = ligne*4+colonne) }
 H4McT: Array[0..1,0..255] Of LongInt;    { predictions luma par liste (pas 16)
  }
 H4McC: Array[0..1,0..1,0..63] Of LongInt; { predictions chroma par liste et
  composante (pas 8) }

Function H4Ref8(L,Addr,B8: LongInt): LongInt;
Begin
 H4Ref8:=ShortInt(H4PBuf(H4Pics[H4Cur].Ref[L])^[Addr*4+B8]);
End;
Function H4MvX(L,Addr,Blk: LongInt): LongInt;
Begin H4MvX:=H4PSmallArr(H4Pics[H4Cur].Mv[L])^[(Addr*16+Blk)*2]; End;
Function H4MvY(L,Addr,Blk: LongInt): LongInt;
Begin H4MvY:=H4PSmallArr(H4Pics[H4Cur].Mv[L])^[(Addr*16+Blk)*2+1]; End;

{ voisin en coordonnees de blocs 4x4 relatives au macrobloc ; R=-2 :
 indisponible, -1 : intra ou liste non utilisee }
Procedure H4Nb(L,Bx,By: LongInt; Var R,Mx,My: LongInt);
Var Addr,Blk: LongInt; Ok: Boolean;
Begin
 R:=-2; Mx:=0; My:=0; Addr:=H4MbAddr; Blk:=0; Ok:=False;
 If By<0 Then Begin
  If Bx<0 Then Begin Ok:=H4AvD; Addr:=H4MbAddr-H4MbW-1; Blk:=15; End
  Else If Bx>3 Then Begin Ok:=H4AvC; Addr:=H4MbAddr-H4MbW+1; Blk:=12; End
  Else Begin Ok:=H4AvB; Addr:=H4MbAddr-H4MbW; Blk:=12+Bx; End;
 End Else If Bx<0 Then Begin Ok:=H4AvA; Addr:=H4MbAddr-1; Blk:=By*4+3; End
 Else If Bx>3 Then Ok:=False
 Else Begin Ok:=((H4Done Shr (By*4+Bx)) And 1)<>0; Blk:=By*4+Bx; End;
 If Not Ok Then Exit;
 R:=-1;
 If Addr<>H4MbAddr Then If (H4Pics[H4Cur].MbType^[Addr] And MT_INTRA)<>0 Then
  Exit;
 R:=H4Ref8(L,Addr,(Blk Shr 3)*2+((Blk And 3) Shr 1));
 If R>=0 Then Begin Mx:=H4MvX(L,Addr,Blk); My:=H4MvY(L,Addr,Blk); End;
End;

Function H4Median(A,B,C: LongInt): LongInt;
Var Lo,Hi: LongInt;
Begin
 If A<B Then Begin Lo:=A; Hi:=B; End Else Begin Lo:=B; Hi:=A; End;
 If C<Lo Then H4Median:=Lo Else If C>Hi Then H4Median:=Hi Else H4Median:=C;
End;

{ Shape : 0 normal, 1 16x8 haut, 2 16x8 bas, 3 8x16 gauche, 4 8x16 droite }
Procedure H4PredMv(L,Bx,By,W4,Ref,Shape: LongInt; Var Mx,My: LongInt);
Var Ra,Rb,Rc,Ax,Ay,Bx2,By2,Cx,Cy,Cnt: LongInt;
Begin
 H4Nb(L,Bx-1,By,Ra,Ax,Ay);
 H4Nb(L,Bx,By-1,Rb,Bx2,By2);
 H4Nb(L,Bx+W4,By-1,Rc,Cx,Cy);
 If Rc=-2 Then H4Nb(L,Bx-1,By-1,Rc,Cx,Cy);
 If (Shape=1) And (Rb=Ref) Then Begin Mx:=Bx2; My:=By2; Exit; End;
 If (Shape=2) And (Ra=Ref) Then Begin Mx:=Ax; My:=Ay; Exit; End;
 If (Shape=3) And (Ra=Ref) Then Begin Mx:=Ax; My:=Ay; Exit; End;
 If (Shape=4) And (Rc=Ref) Then Begin Mx:=Cx; My:=Cy; Exit; End;
 If (Rb=-2) And (Rc=-2) And (Ra<>-2) Then Begin Mx:=Ax; My:=Ay; Exit; End;
 Cnt:=Ord(Ra=Ref)+Ord(Rb=Ref)+Ord(Rc=Ref);
 If Cnt=1 Then Begin
  If Ra=Ref Then Begin Mx:=Ax; My:=Ay; End
  Else If Rb=Ref Then Begin Mx:=Bx2; My:=By2; End
  Else Begin Mx:=Cx; My:=Cy; End;
 End Else Begin
  Mx:=H4Median(Ax,Bx2,Cx); My:=H4Median(Ay,By2,Cy);
 End;
End;

Procedure H4SetPart(L,Bx,By,W4,Hp,Ref,Mx,My: LongInt);
Var I,J,Addr: LongInt;
Begin
 Addr:=H4MbAddr;
 If (Mx<-32768) Or (Mx>32767) Or (My<-32768) Or (My>32767) Then Begin H4Err:=
  True; Mx:=0; My:=0; End;
 For J:=By To By+Hp-1 Do For I:=Bx To Bx+W4-1 Do Begin
  H4PSmallArr(H4Pics[H4Cur].Mv[L])^[(Addr*16+J*4+I)*2]:=Mx;
  H4PSmallArr(H4Pics[H4Cur].Mv[L])^[(Addr*16+J*4+I)*2+1]:=My;
  H4PBuf(H4Pics[H4Cur].Ref[L])^[Addr*4+(J Shr 1)*2+(I Shr 1)]:=Ref And 255;
  H4Done:=H4Done Or (1 Shl (J*4+I));
 End;
End;

Procedure H4PutRef(L,Bx,By,W4,Hp,Ref: LongInt);
Var I,J: LongInt;
Begin
 For J:=By Shr 1 To (By+Hp-1) Shr 1 Do For I:=Bx Shr 1 To (Bx+W4-1) Shr 1 Do
  H4PBuf(H4Pics[H4Cur].Ref[L])^[H4MbAddr*4+J*2+I]:=Ref And 255;
End;

{ lecture d'une difference de vecteur (CAVLC : deux se(v) ; CABAC : contextes
 mvd) }
Procedure H4ReadMvd(L,Bx,By,W4,Hp: LongInt; Var Dx,Dy: LongInt);
Var Ax,Ay,Mx,My,I,J: LongInt;
Begin
 If Not H4CabacOn Then Begin Dx:=H4Se; Dy:=H4Se; Exit; End;
 Ax:=H4NbMvd(L,Bx-1,By,0)+H4NbMvd(L,Bx,By-1,0);
 Ay:=H4NbMvd(L,Bx-1,By,1)+H4NbMvd(L,Bx,By-1,1);
 Dx:=H4CbMvd(40,Ax,Mx);
 Dy:=H4CbMvd(47,Ay,My);
 For J:=By To By+Hp-1 Do For I:=Bx To Bx+W4-1 Do Begin
  H4MvdTab^[(((H4MbAddr*2+L)*16+J*4+I) Shl 1)]:=Mx;
  H4MvdTab^[(((H4MbAddr*2+L)*16+J*4+I) Shl 1)+1]:=My;
 End;
End;

{ ---- mode direct ---- }
Function H4MinPos(A,B: LongInt): LongInt;
Begin
 If (A>=0) And (B>=0) Then Begin If A<B Then H4MinPos:=A Else H4MinPos:=B; End
 Else Begin If A>B Then H4MinPos:=A Else H4MinPos:=B; End;
End;

{ informations du bloc colocalise (image RefList1[0], meme macrobloc) }
Procedure H4ColBlk(Blk: LongInt; Var Intra: Boolean; Var RefC,Mx,My,PicId:
 LongInt);
Var CP: ^TH4Pic; Addr,L,B8: LongInt;
Begin
 CP:=@H4Pics[H4RefList[1,0]]; Addr:=H4MbAddr; B8:=(Blk Shr 3)*2+((Blk And 3) Shr
  1);
 Intra:=(CP^.MbType^[Addr] And MT_INTRA)<>0;
 RefC:=-1; Mx:=0; My:=0; PicId:=-1;
 If Intra Then Exit;
 L:=0; RefC:=ShortInt(H4PBuf(CP^.Ref[0])^[Addr*4+B8]);
 If RefC<0 Then Begin L:=1; RefC:=ShortInt(H4PBuf(CP^.Ref[1])^[Addr*4+B8]);
  End;
 If RefC>=0 Then Begin
  Mx:=H4PSmallArr(CP^.Mv[L])^[(Addr*16+Blk)*2]; My:=H4PSmallArr(CP^.Mv[L])^[(Addr*
   16+Blk)*2+1];
  PicId:=H4PLongArr(CP^.RefId[L])^[Addr*4+B8];
 End;
End;

Procedure H4Direct(Mask8: LongInt);
Var B8,K,I,J,L,Blk,Bx0,By0,Cblk,Ra,Rb,Rc,Ax,Ay,Mx,My,RefC,CMx,CMy,PicId,R0,Tb,
 Td,Tx,Dsf,M0x,M0y,Poc0,Poc1,PocC: LongInt;
 Rr: Array[0..1] Of LongInt; Pm: Array[0..1,0..1] Of LongInt; Intra,Lt,ColZero,
  Zero: Boolean; P1: ^TH4Pic; Pic0: LongInt;
Begin
 If (H4RefList[1,0]<0) Or (H4RefList[0,0]<0) Then Begin H4Err:=True; Exit; End;
 P1:=@H4Pics[H4RefList[1,0]];
 Lt:=P1^.RefState=2;
 If H4CurSh.DirectSpatial<>0 Then Begin
  For L:=0 To 1 Do Begin
   H4Nb(L,-1,0,Ra,Ax,Ay); H4Nb(L,0,-1,Rb,Ax,Ay); H4Nb(L,4,-1,Rc,Ax,Ay);
   If Rc=-2 Then H4Nb(L,-1,-1,Rc,Ax,Ay);
   If Ra<0 Then Ra:=-1; If Rb<0 Then Rb:=-1; If Rc<0 Then Rc:=-1;
   Rr[L]:=H4MinPos(Ra,H4MinPos(Rb,Rc));
  End;
  Zero:=False;
  If (Rr[0]<0) And (Rr[1]<0) Then Begin Rr[0]:=0; Rr[1]:=0; Zero:=True; End;
  For L:=0 To 1 Do Begin
   Pm[L,0]:=0; Pm[L,1]:=0;
   If (Rr[L]>=0) And Not Zero Then Begin H4PredMv(L,0,0,4,Rr[L],0,Mx,My); Pm[L,
    0]:=Mx; Pm[L,1]:=My; End;
  End;
  For B8:=0 To 3 Do If ((Mask8 Shr B8) And 1)<>0 Then Begin
   Bx0:=(B8 And 1)*2; By0:=(B8 Shr 1)*2;
   For L:=0 To 1 Do H4PBuf(H4Pics[H4Cur].Ref[L])^[H4MbAddr*4+B8]:=Rr[L] And
    255;
   ColZero:=False;
   If H4Sp^.Direct8x8Inference<>0 Then Begin
    H4ColBlk((By0+(B8 Shr 1))*4+Bx0+(B8 And 1),Intra,RefC,CMx,CMy,PicId);
    ColZero:=(Not Intra) And (Not Lt) And (RefC=0) And (Abs(CMx)<=1) And (Abs(
     CMy)<=1);
   End;
   For J:=By0 To By0+1 Do For I:=Bx0 To Bx0+1 Do Begin
    Blk:=J*4+I;
    If H4Sp^.Direct8x8Inference=0 Then Begin
     H4ColBlk(Blk,Intra,RefC,CMx,CMy,PicId);
     ColZero:=(Not Intra) And (Not Lt) And (RefC=0) And (Abs(CMx)<=1) And (Abs(
      CMy)<=1);
    End;
    For L:=0 To 1 Do Begin
     If (Rr[L]=0) And ColZero Then Begin Mx:=0; My:=0; End Else Begin Mx:=Pm[L,
      0]; My:=Pm[L,1]; End;
     H4PSmallArr(H4Pics[H4Cur].Mv[L])^[(H4MbAddr*16+Blk)*2]:=Mx; H4PSmallArr(H4Pics[
      H4Cur].Mv[L])^[(H4MbAddr*16+Blk)*2+1]:=My;
    End;
   End;
  End;
 End Else Begin
  { direct temporel }
  Poc1:=P1^.Poc; PocC:=H4Pics[H4Cur].Poc;
  For B8:=0 To 3 Do If ((Mask8 Shr B8) And 1)<>0 Then Begin
   Bx0:=(B8 And 1)*2; By0:=(B8 Shr 1)*2;
   For J:=By0 To By0+1 Do For I:=Bx0 To Bx0+1 Do Begin
    Blk:=J*4+I;
    If H4Sp^.Direct8x8Inference<>0 Then Cblk:=(By0+(B8 Shr 1))*4+Bx0+(B8 And 1)
     Else Cblk:=Blk;
    H4ColBlk(Cblk,Intra,RefC,CMx,CMy,PicId);
    R0:=0;
    If (Not Intra) And (PicId>=0) Then
     For K:=H4CurSh.NumRef[0]-1 DownTo 0 Do If H4RefList[0,K]>=0 Then If H4Pics[
      H4RefList[0,K]].Id=PicId Then R0:=K;
    Pic0:=H4RefList[0,R0];
    If Pic0<0 Then Begin H4Err:=True; Exit; End;
    Poc0:=H4Pics[Pic0].Poc;
    Td:=H4Clip3(-128,127,Poc1-Poc0);
    If (Td=0) Or (H4Pics[Pic0].RefState=2) Then Begin M0x:=CMx; M0y:=CMy; Mx:=0;
     My:=0; End
    Else Begin
     Tb:=H4Clip3(-128,127,PocC-Poc0);
     Tx:=(16384+(Abs(Td) Shr 1)) Div Td;
     Dsf:=H4Clip3(-1024,1023,H4Sar(Tb*Tx+32,6));
     M0x:=H4Sar(Dsf*CMx+128,8); M0y:=H4Sar(Dsf*CMy+128,8);
     Mx:=M0x-CMx; My:=M0y-CMy;
    End;
    H4PBuf(H4Pics[H4Cur].Ref[0])^[H4MbAddr*4+B8]:=R0;
    H4PBuf(H4Pics[H4Cur].Ref[1])^[H4MbAddr*4+B8]:=0;
    H4PSmallArr(H4Pics[H4Cur].Mv[0])^[(H4MbAddr*16+Blk)*2]:=M0x; H4PSmallArr(H4Pics[
     H4Cur].Mv[0])^[(H4MbAddr*16+Blk)*2+1]:=M0y;
    H4PSmallArr(H4Pics[H4Cur].Mv[1])^[(H4MbAddr*16+Blk)*2]:=Mx; H4PSmallArr(H4Pics[
     H4Cur].Mv[1])^[(H4MbAddr*16+Blk)*2+1]:=My;
   End;
  End;
 End;
End;

{ ---- compensation de mouvement ---- }
Procedure H4McLuma(Src: H4PBuf; X,Y,Fx,Fy,Bw,Bh: LongInt; Dst: H4PLongArr);
Const PS=21;
Var P,Hb,Vh: Array[0..440] Of LongInt; Cx,Cy: Array[0..20] Of LongInt; R,C,I,J,
 PW,PH,G,V: LongInt;
Function Tap(A,B,Cc,D,E,F: LongInt): LongInt;
Begin Tap:=A-5*B+20*Cc+20*D-5*E+F; End;
Function Bq(Ii,Jj: LongInt): LongInt;
Begin Bq:=H4Clip(H4Sar(Hb[(Jj+2)*PS+Ii]+16,5)); End;
Function Sq(Ii,Jj: LongInt): LongInt;
Begin Sq:=H4Clip(H4Sar(Hb[(Jj+3)*PS+Ii]+16,5)); End;
Function Hq(Ii,Jj: LongInt): LongInt;
Begin Hq:=H4Clip(H4Sar(Vh[Jj*PS+Ii+2]+16,5)); End;
Function Mq(Ii,Jj: LongInt): LongInt;
Begin Mq:=H4Clip(H4Sar(Vh[Jj*PS+Ii+3]+16,5)); End;
Function Jq(Ii,Jj: LongInt): LongInt;
Begin Jq:=H4Clip(H4Sar(Tap(Hb[Jj*PS+Ii],Hb[(Jj+1)*PS+Ii],Hb[(Jj+2)*PS+Ii],Hb[(
 Jj+3)*PS+Ii],Hb[(Jj+4)*PS+Ii],Hb[(Jj+5)*PS+Ii])+512,10)); End;
Begin
 PW:=H4MbW*16; PH:=H4MbH*16;
 For C:=0 To Bw+4 Do Begin V:=X-2+C; If V<0 Then V:=0 Else If V>PW-1 Then V:=PW-
  1; Cx[C]:=V; End;
 For R:=0 To Bh+4 Do Begin V:=Y-2+R; If V<0 Then V:=0 Else If V>PH-1 Then V:=PH-
  1; Cy[R]:=V*PW; End;
 For R:=0 To Bh+4 Do For C:=0 To Bw+4 Do P[R*PS+C]:=Src^[Cy[R]+Cx[C]];
 If (Fx=0) And (Fy=0) Then Begin
  For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do Dst^[J*16+I]:=P[(J+2)*PS+I+2];
  Exit;
 End;
 If Fx<>0 Then
  For R:=0 To Bh+4 Do For C:=0 To Bw-1 Do
   Hb[R*PS+C]:=Tap(P[R*PS+C],P[R*PS+C+1],P[R*PS+C+2],P[R*PS+C+3],P[R*PS+C+4],P[
    R*PS+C+5]);
 If Fy<>0 Then
  For R:=0 To Bh-1 Do For C:=0 To Bw+4 Do
   Vh[R*PS+C]:=Tap(P[R*PS+C],P[(R+1)*PS+C],P[(R+2)*PS+C],P[(R+3)*PS+C],P[(R+4)*
    PS+C],P[(R+5)*PS+C]);
 For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do Begin
  G:=P[(J+2)*PS+I+2];
  Case Fy*4+Fx Of
   1: V:=(G+Bq(I,J)+1) Shr 1;
   2: V:=Bq(I,J);
   3: V:=(P[(J+2)*PS+I+3]+Bq(I,J)+1) Shr 1;
   4: V:=(G+Hq(I,J)+1) Shr 1;
   5: V:=(Bq(I,J)+Hq(I,J)+1) Shr 1;
   6: V:=(Bq(I,J)+Jq(I,J)+1) Shr 1;
   7: V:=(Bq(I,J)+Mq(I,J)+1) Shr 1;
   8: V:=Hq(I,J);
   9: V:=(Hq(I,J)+Jq(I,J)+1) Shr 1;
   10: V:=Jq(I,J);
   11: V:=(Jq(I,J)+Mq(I,J)+1) Shr 1;
   12: V:=(P[(J+3)*PS+I+2]+Hq(I,J)+1) Shr 1;
   13: V:=(Hq(I,J)+Sq(I,J)+1) Shr 1;
   14: V:=(Jq(I,J)+Sq(I,J)+1) Shr 1;
  Else V:=(Mq(I,J)+Sq(I,J)+1) Shr 1;
  End;
  Dst^[J*16+I]:=V;
 End;
End;

Procedure H4McChroma(Src: H4PBuf; X,Y,Fx,Fy,Bw,Bh: LongInt; Dst: H4PLongArr);
Var I,J,PW,PH,X0,X1,Y0,Y1: LongInt;
Begin
 PW:=H4MbW*8; PH:=H4MbH*8;
 For J:=0 To Bh-1 Do Begin
  Y0:=Y+J; If Y0<0 Then Y0:=0 Else If Y0>PH-1 Then Y0:=PH-1;
  Y1:=Y+J+1; If Y1<0 Then Y1:=0 Else If Y1>PH-1 Then Y1:=PH-1;
  For I:=0 To Bw-1 Do Begin
   X0:=X+I; If X0<0 Then X0:=0 Else If X0>PW-1 Then X0:=PW-1;
   X1:=X+I+1; If X1<0 Then X1:=0 Else If X1>PW-1 Then X1:=PW-1;
   Dst^[J*8+I]:=((8-Fx)*(8-Fy)*Src^[Y0*PW+X0]+Fx*(8-Fy)*Src^[Y0*PW+X1]+(8-Fx)*
    Fy*Src^[Y1*PW+X0]+Fx*Fy*Src^[Y1*PW+X1]+32) Shr 6;
  End;
 End;
End;

{ Mode 0 copie, 1 pondere (une liste), 2 moyenne, 3 pondere bi-predit }
Procedure H4PutBlock(Dst: H4PBuf; DStr,Bw,Bh: LongInt; A0,A1: H4PLongArr; PStr,
 Mode,W0,W1,O,Lg: LongInt);
Var I,J,V,P0,P1: LongInt;
Begin
 For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do Begin
  P0:=A0^[J*PStr+I]; P1:=0;
  If A1<>Nil Then P1:=A1^[J*PStr+I];
  Case Mode Of
   0: V:=P0;
   1: Begin
    If Lg>=1 Then V:=H4Sar(P0*W0+(1 Shl (Lg-1)),Lg)+O Else V:=P0*W0+O;
    V:=H4Clip(V);
   End;
   2: V:=(P0+P1+1) Shr 1;
  Else V:=H4Clip(H4Sar(P0*W0+P1*W1+(1 Shl Lg),Lg+1)+O);
  End;
  Dst^[J*DStr+I]:=V;
 End;
End;

{ mouvement identique sur tout le bloc (Bx,By,W4,Hp en blocs 4x4) : lit les
 tables de l'image courante }
Procedure H4McBlock(Bx,By,W4,Hp: LongInt);
Var L,B8,Blk,Bw,Bh,X0,Y0,PicIdx,Mode,W0,W1,O,Lg,C,Cnt,Lu,Poc0,Poc1,PocC,Tb,Td,
 Tx,Dsf,Wt: LongInt;
 R,Mx,My: Array[0..1] Of LongInt; Pc: Array[0..1] Of ^TH4Pic; Explicit,Implicit,
  Bipred: Boolean; Dst: H4PBuf;
Begin
 B8:=(By Shr 1)*2+(Bx Shr 1); Blk:=By*4+Bx; Bw:=W4*4; Bh:=Hp*4;
 X0:=H4MbX*16+Bx*4; Y0:=H4MbY*16+By*4;
 Cnt:=0; Lu:=0;
 For L:=0 To 1 Do Begin
  R[L]:=H4Ref8(L,H4MbAddr,B8); Pc[L]:=Nil; Mx[L]:=0; My[L]:=0;
  If R[L]>=0 Then Begin
   If R[L]>32 Then Begin H4Err:=True; Exit; End;
   PicIdx:=H4RefList[L,R[L]];
   If PicIdx<0 Then Begin H4Err:=True; Exit; End;
   Pc[L]:=@H4Pics[PicIdx]; Mx[L]:=H4MvX(L,H4MbAddr,Blk); My[L]:=H4MvY(L,
    H4MbAddr,Blk);
   H4McLuma(Pc[L]^.Y,X0+H4Sar(Mx[L],2),Y0+H4Sar(My[L],2),Mx[L] And 3,My[L] And
    3,Bw,Bh,@H4McT[L]);
   H4McChroma(Pc[L]^.U,(X0 Shr 1)+H4Sar(Mx[L],3),(Y0 Shr 1)+H4Sar(My[L],3),Mx[L]
    And 7,My[L] And 7,Bw Shr 1,Bh Shr 1,@H4McC[L,0]);
   H4McChroma(Pc[L]^.V,(X0 Shr 1)+H4Sar(Mx[L],3),(Y0 Shr 1)+H4Sar(My[L],3),Mx[L]
    And 7,My[L] And 7,Bw Shr 1,Bh Shr 1,@H4McC[L,1]);
   Inc(Cnt); Lu:=L;
  End;
 End;
 If Cnt=0 Then Begin H4Err:=True; Exit; End;
 Bipred:=Cnt=2;
 Explicit:=((H4SliceType<>1) And (H4Pp^.WeightedPred<>0)) Or ((H4SliceType=1)
  And (H4Pp^.WeightedBipred=1));
 Implicit:=(H4SliceType=1) And (H4Pp^.WeightedBipred=2);
 For C:=0 To 2 Do Begin
  If C=0 Then Begin Dst:=@H4Pics[H4Cur].Y^[Y0*H4StrideY+X0]; End
  Else If C=1 Then Dst:=@H4Pics[H4Cur].U^[(Y0 Shr 1)*H4StrideC+(X0 Shr 1)]
  Else Dst:=@H4Pics[H4Cur].V^[(Y0 Shr 1)*H4StrideC+(X0 Shr 1)];
  Mode:=0; W0:=0; W1:=0; O:=0; Lg:=0;
  If Not Bipred Then Begin
   If Explicit Then Begin
    Mode:=1;
    If C=0 Then Begin W0:=H4CurSh.LumaW[Lu,R[Lu]]; O:=H4CurSh.LumaO[Lu,R[Lu]];
     Lg:=H4CurSh.LumaLog2Wd; End
    Else Begin W0:=H4CurSh.ChromaW[Lu,R[Lu],C-1]; O:=H4CurSh.ChromaO[Lu,R[Lu],C-
     1]; Lg:=H4CurSh.ChromaLog2Wd; End;
   End;
  End Else Begin
   If Explicit Then Begin
    Mode:=3;
    If C=0 Then Begin
     W0:=H4CurSh.LumaW[0,R[0]]; W1:=H4CurSh.LumaW[1,R[1]]; O:=H4Sar(
      H4CurSh.LumaO[0,R[0]]+H4CurSh.LumaO[1,R[1]]+1,1); Lg:=H4CurSh.LumaLog2Wd;
    End Else Begin
     W0:=H4CurSh.ChromaW[0,R[0],C-1]; W1:=H4CurSh.ChromaW[1,R[1],C-1];
     O:=H4Sar(H4CurSh.ChromaO[0,R[0],C-1]+H4CurSh.ChromaO[1,R[1],C-1]+1,1); Lg:=
      H4CurSh.ChromaLog2Wd;
    End;
   End Else If Implicit Then Begin
    Poc0:=Pc[0]^.Poc; Poc1:=Pc[1]^.Poc; PocC:=H4Pics[H4Cur].Poc;
    Td:=H4Clip3(-128,127,Poc1-Poc0); W1:=32; W0:=32;
    If (Td<>0) And (Pc[0]^.RefState<>2) And (Pc[1]^.RefState<>2) Then Begin
     Tb:=H4Clip3(-128,127,PocC-Poc0); Tx:=(16384+(Abs(Td) Shr 1)) Div Td;
     Dsf:=H4Clip3(-1024,1023,H4Sar(Tb*Tx+32,6));
     Wt:=H4Sar(Dsf,2);
     If (Wt>=-64) And (Wt<=128) Then Begin W1:=Wt; W0:=64-Wt; End;
    End;
    Mode:=3; O:=0; Lg:=5;
   End Else Mode:=2;
  End;
  If C=0 Then Begin
   If Bipred Then H4PutBlock(Dst,H4StrideY,Bw,Bh,@H4McT[0],@H4McT[1],16,Mode,W0,
    W1,O,Lg)
   Else H4PutBlock(Dst,H4StrideY,Bw,Bh,@H4McT[Lu],Nil,16,Mode,W0,W1,O,Lg);
  End Else Begin
   If Bipred Then H4PutBlock(Dst,H4StrideC,Bw Shr 1,Bh Shr 1,@H4McC[0,C-1],
    @H4McC[1,C-1],8,Mode,W0,W1,O,Lg)
   Else H4PutBlock(Dst,H4StrideC,Bw Shr 1,Bh Shr 1,@H4McC[Lu,C-1],Nil,8,Mode,W0,
    W1,O,Lg);
  End;
 End;
End;

Function H4SameBlk(A,B: LongInt): Boolean;
Var L,Ra,Rb: LongInt;
Begin
 H4SameBlk:=False;
 For L:=0 To 1 Do Begin
  Ra:=H4Ref8(L,H4MbAddr,(A Shr 3)*2+((A And 3) Shr 1)); Rb:=H4Ref8(L,H4MbAddr,(B
   Shr 3)*2+((B And 3) Shr 1));
  If Ra<>Rb Then Exit;
  If Ra>=0 Then If (H4MvX(L,H4MbAddr,A)<>H4MvX(L,H4MbAddr,B)) Or (H4MvY(L,
   H4MbAddr,A)<>H4MvY(L,H4MbAddr,B)) Then Exit;
 End;
 H4SameBlk:=True;
End;

Procedure H4McMb;
Var B8,K,I,J,Bx,By: LongInt; All: Boolean;
Begin
 All:=True;
 For K:=1 To 15 Do If Not H4SameBlk(0,K) Then Begin All:=False; Break; End;
 If All Then Begin H4McBlock(0,0,4,4); Exit; End;
 For B8:=0 To 3 Do Begin
  Bx:=(B8 And 1)*2; By:=(B8 Shr 1)*2;
  If H4SameBlk(By*4+Bx,By*4+Bx+1) And H4SameBlk(By*4+Bx,(By+1)*4+Bx) And
   H4SameBlk(By*4+Bx,(By+1)*4+Bx+1) Then H4McBlock(Bx,By,2,2)
  Else For J:=0 To 1 Do For I:=0 To 1 Do H4McBlock(Bx+I,By+J,1,1);
  If H4Err Then Exit;
 End;
End;

Procedure H4SetRefIds;
Var L,B8,R,P: LongInt;
Begin
 For L:=0 To 1 Do For B8:=0 To 3 Do Begin
  R:=H4Ref8(L,H4MbAddr,B8); P:=-1;
  If (R>=0) And (R<=32) Then If H4RefList[L,R]>=0 Then P:=H4Pics[H4RefList[L,
   R]].Id;
  H4PLongArr(H4Pics[H4Cur].RefId[L])^[H4MbAddr*4+B8]:=P;
 End;
End;

{ ---- intensite de filtrage entre blocs inter ---- }
Function H4BsInter(Addr,Blk,AddrP,BlkP: LongInt): LongInt;
Var Cur: ^TH4Pic; Iq,Ip: Array[0..1] Of LongInt; Qx,Qy,Px,Py: Array[0..1] Of
 LongInt; L,Nq,Np,B8Q,B8P: LongInt;
Function Diff(Xa,Ya,Xb,Yb: LongInt): Boolean;
Begin Diff:=(Abs(Xa-Xb)>=4) Or (Abs(Ya-Yb)>=4); End;
Begin
 Cur:=@H4Pics[H4Cur]; H4BsInter:=1;
 B8Q:=(Blk Shr 3)*2+((Blk And 3) Shr 1); B8P:=(BlkP Shr 3)*2+((BlkP And 3) Shr
  1);
 Nq:=0; Np:=0;
 For L:=0 To 1 Do Begin
  Iq[L]:=-1; Ip[L]:=-1; Qx[L]:=0; Qy[L]:=0; Px[L]:=0; Py[L]:=0;
  If ShortInt(H4PBuf(Cur^.Ref[L])^[Addr*4+B8Q])>=0 Then Begin
   Iq[L]:=H4PLongArr(Cur^.RefId[L])^[Addr*4+B8Q]; Qx[L]:=H4MvX(L,Addr,Blk); Qy[
    L]:=H4MvY(L,Addr,Blk); Inc(Nq);
  End;
  If ShortInt(H4PBuf(Cur^.Ref[L])^[AddrP*4+B8P])>=0 Then Begin
   Ip[L]:=H4PLongArr(Cur^.RefId[L])^[AddrP*4+B8P]; Px[L]:=H4MvX(L,AddrP,BlkP); Py[
    L]:=H4MvY(L,AddrP,BlkP); Inc(Np);
  End;
 End;
 If Nq<>Np Then Exit;
 If Nq=1 Then Begin
  If Iq[0]>=0 Then L:=0 Else L:=1;
  If Ip[0]>=0 Then Begin
   If Iq[L]<>Ip[0] Then Exit;
   H4BsInter:=Ord(Diff(Qx[L],Qy[L],Px[0],Py[0]));
  End Else Begin
   If Iq[L]<>Ip[1] Then Exit;
   H4BsInter:=Ord(Diff(Qx[L],Qy[L],Px[1],Py[1]));
  End;
  Exit;
 End;
 If Not (((Iq[0]=Ip[0]) And (Iq[1]=Ip[1])) Or ((Iq[0]=Ip[1]) And (Iq[1]=Ip[0])))
  Then Exit;
 If Iq[0]<>Iq[1] Then Begin
  If Iq[0]=Ip[0] Then H4BsInter:=Ord(Diff(Qx[0],Qy[0],Px[0],Py[0]) Or Diff(Qx[
   1],Qy[1],Px[1],Py[1]))
  Else H4BsInter:=Ord(Diff(Qx[0],Qy[0],Px[1],Py[1]) Or Diff(Qx[1],Qy[1],Px[0],
   Py[0]));
 End Else
  H4BsInter:=Ord((Diff(Qx[0],Qy[0],Px[0],Py[0]) Or Diff(Qx[1],Qy[1],Px[1],Py[
   1])) And (Diff(Qx[0],Qy[0],Px[1],Py[1]) Or Diff(Qx[1],Qy[1],Px[0],Py[0])));
End;

{ ---- macroblocs inter ---- }
Procedure H4SkipMb;
Var Ra,Rb,Ax,Ay,Bx,By,Mx,My: LongInt;
Begin
 H4Done:=0; FillChar(H4Nnz,SizeOf(H4Nnz),0); H4CurTx8:=0; H4ChromaMode:=0;
  H4CurCbp:=0; H4LastDqp:=0;
 H4CurType:=MT_INTER Or MT_SKIP;
 If H4SliceType=1 Then Begin
  H4CurType:=H4CurType Or MT_DIRECT;
  FillChar(H4CurDir8,4,1);
  H4Direct(15);
  If H4Err Then Exit;
 End Else Begin
  H4Nb(0,-1,0,Ra,Ax,Ay); H4Nb(0,0,-1,Rb,Bx,By);
  If (Ra=-2) Or (Rb=-2) Or ((Ra=0) And (Ax=0) And (Ay=0)) Or ((Rb=0) And (Bx=0)
   And (By=0)) Then Begin Mx:=0; My:=0; End
  Else H4PredMv(0,0,0,4,0,0,Mx,My);
  H4SetPart(0,0,0,4,4,0,Mx,My);
  H4SetPart(1,0,0,4,4,-1,0,0);
 End;
 H4SetRefIds;
 H4McMb;
 H4StoreMb(True);
End;

Procedure H4InterMb(T: LongInt);
Var Shape,NP,I,J,K,L,B8,Lmax,Cbp,CbpL,CbpC,Dq,Mx,My,Dx,Dy,Bx,By,W4,Hp,Sh,
 DirMask,Blk: LongInt;
 PBx,PBy,PW4,PHp,PPred,PShape: Array[0..3] Of LongInt; SubShape,SubPred: Array[
  0..3] Of LongInt; SubDir: Array[0..3] Of Boolean;
 Rf: Array[0..1,0..3] Of LongInt; NRef: Array[0..1] Of LongInt; Ref0Mode,
  DirectAll,Small,Tx8,Ok: Boolean; Pr: LongInt;
Procedure Part(P,X,Y,W,H,Pred,Shp: LongInt);
Begin PBx[P]:=X; PBy[P]:=Y; PW4[P]:=W; PHp[P]:=H; PPred[P]:=Pred; PShape[P]:=
 Shp; End;
Begin
 H4Done:=0; FillChar(H4Nnz,SizeOf(H4Nnz),0); H4CurTx8:=0; H4ChromaMode:=0;
 H4CurType:=MT_INTER; DirectAll:=False; Small:=False; Ref0Mode:=False; DirMask:=
  0;
 NRef[0]:=H4CurSh.NumRef[0]; NRef[1]:=H4CurSh.NumRef[1];
 FillChar(Rf,SizeOf(Rf),0);
 For I:=0 To 3 Do Begin SubDir[I]:=False; SubShape[I]:=0; SubPred[I]:=0; End;
 Shape:=0; NP:=1;
 If H4SliceType=1 Then Begin
  Lmax:=1;
  If T=0 Then Begin DirectAll:=True; H4CurType:=H4CurType Or MT_DIRECT; End
  Else If T<=3 Then Begin Shape:=0; Part(0,0,0,4,4,T,0); End
  Else If T<22 Then Begin
   K:=(T-4) Div 2;
   If (T And 1)=0 Then Begin Shape:=1; Part(0,0,0,4,2,H4BPair[K,0],1); Part(1,0,
    2,4,2,H4BPair[K,1],2); End
   Else Begin Shape:=2; Part(0,0,0,2,4,H4BPair[K,0],3); Part(1,2,0,2,4,H4BPair[
    K,1],4); End;
   NP:=2;
  End Else Shape:=3;
 End Else Begin
  Lmax:=0;
  Case T Of
   0: Part(0,0,0,4,4,1,0);
   1: Begin Shape:=1; NP:=2; Part(0,0,0,4,2,1,1); Part(1,0,2,4,2,1,2); End;
   2: Begin Shape:=2; NP:=2; Part(0,0,0,2,4,1,3); Part(1,2,0,2,4,1,4); End;
  Else Begin Shape:=3; Ref0Mode:=T=4; End;
  End;
 End;
 If Shape=3 Then Begin
  For B8:=0 To 3 Do Begin
   If H4CabacOn Then Begin
    If H4SliceType=1 Then I:=H4CbSubB Else I:=H4CbSubP;
   End Else I:=H4Ue;
   If H4SliceType=1 Then Begin
    If I>12 Then Begin H4Err:=True; Exit; End;
    SubPred[B8]:=H4SubBPred[I]; SubShape[B8]:=H4SubBShape[I]; SubDir[B8]:=I=0;
    If I=0 Then Begin DirMask:=DirMask Or (1 Shl B8); H4CurDir8[B8]:=1; If
     H4Sp^.Direct8x8Inference=0 Then Small:=True; End;
   End Else Begin
    If I>3 Then Begin H4Err:=True; Exit; End;
    SubPred[B8]:=1; SubShape[B8]:=I;
   End;
   If (Not SubDir[B8]) And (SubShape[B8]<>0) Then Small:=True;
  End;
 End;
 If H4Err Then Exit;
 If DirectAll Then Begin
  FillChar(H4CurDir8,4,1);
  H4Direct(15);
  If H4Sp^.Direct8x8Inference=0 Then Small:=True;
  H4SetRefIds;
 End Else Begin
  If DirMask<>0 Then Begin H4Direct(DirMask); If H4Err Then Exit; End;
  { indices de reference }
  For L:=0 To 1 Do For B8:=0 To 3 Do If Not SubDir[B8] Then H4PBuf(H4Pics[
   H4Cur].Ref[L])^[H4MbAddr*4+B8]:=255;
  For L:=0 To Lmax Do Begin
   If Shape=3 Then Begin
    For B8:=0 To 3 Do If (Not SubDir[B8]) And ((SubPred[B8] And (1 Shl L))<>0)
     Then Begin
     If Ref0Mode Or (NRef[L]<=1) Then Rf[L,B8]:=0
     Else If H4CabacOn Then Rf[L,B8]:=H4CbRef(L,(B8 And 1)*2,(B8 Shr 1)*2)
     Else Rf[L,B8]:=H4Te(NRef[L]-1);
     If (Rf[L,B8]<0) Or (Rf[L,B8]>=NRef[L]) Or H4Err Then Begin H4Err:=True;
      Exit; End;
     H4PutRef(L,(B8 And 1)*2,(B8 Shr 1)*2,2,2,Rf[L,B8]);
    End;
   End Else
    For I:=0 To NP-1 Do If (PPred[I] And (1 Shl L))<>0 Then Begin
     If NRef[L]<=1 Then Rf[L,I]:=0
     Else If H4CabacOn Then Rf[L,I]:=H4CbRef(L,PBx[I],PBy[I])
     Else Rf[L,I]:=H4Te(NRef[L]-1);
     If (Rf[L,I]<0) Or (Rf[L,I]>=NRef[L]) Or H4Err Then Begin H4Err:=True; Exit;
      End;
     H4PutRef(L,PBx[I],PBy[I],PW4[I],PHp[I],Rf[L,I]);
    End;
  End;
  If H4Err Then Exit;
  { vecteurs }
  For L:=0 To Lmax Do Begin
   H4Done:=0;
   If Shape=3 Then Begin
    For B8:=0 To 3 Do Begin
     Bx:=(B8 And 1)*2; By:=(B8 Shr 1)*2;
     If SubDir[B8] Then Begin
      H4Done:=H4Done Or (51 Shl (By*4+Bx));
     End Else If (SubPred[B8] And (1 Shl L))=0 Then H4SetPart(L,Bx,By,2,2,-1,0,
      0)
     Else Begin
      Case SubShape[B8] Of
       0: Begin NP:=1; W4:=2; Hp:=2; End;
       1: Begin NP:=2; W4:=2; Hp:=1; End;
       2: Begin NP:=2; W4:=1; Hp:=2; End;
      Else Begin NP:=4; W4:=1; Hp:=1; End;
      End;
      For K:=0 To NP-1 Do Begin
       Case SubShape[B8] Of
        0: Begin I:=0; J:=0; End;
        1: Begin I:=0; J:=K; End;
        2: Begin I:=K; J:=0; End;
       Else Begin I:=K And 1; J:=K Shr 1; End;
       End;
       H4PredMv(L,Bx+I,By+J,W4,Rf[L,B8],0,Mx,My);
       H4ReadMvd(L,Bx+I,By+J,W4,Hp,Dx,Dy);
       H4SetPart(L,Bx+I,By+J,W4,Hp,Rf[L,B8],Mx+Dx,My+Dy);
      End;
     End;
    End;
   End Else
    For I:=0 To NP-1 Do Begin
     If (PPred[I] And (1 Shl L))=0 Then H4SetPart(L,PBx[I],PBy[I],PW4[I],PHp[I],
      -1,0,0)
     Else Begin
      H4PredMv(L,PBx[I],PBy[I],PW4[I],Rf[L,I],PShape[I],Mx,My);
      H4ReadMvd(L,PBx[I],PBy[I],PW4[I],PHp[I],Dx,Dy);
      H4SetPart(L,PBx[I],PBy[I],PW4[I],PHp[I],Rf[L,I],Mx+Dx,My+Dy);
     End;
    End;
  End;
  If H4SliceType<>1 Then H4SetPart(1,0,0,4,4,-1,0,0);
  H4SetRefIds;
 End;
 If H4Err Then Exit;
 H4McMb;
 If H4Err Then Exit;
 { residu }
 If H4CabacOn Then Cbp:=H4CbCbp(False) Else Begin
  I:=H4Ue;
  If I>47 Then Begin H4Err:=True; Exit; End;
  Cbp:=H4GolombToInterCbp[I];
 End;
 H4CurCbp:=Cbp; CbpL:=Cbp And 15; CbpC:=Cbp Shr 4;
 Tx8:=False;
 If (CbpL<>0) And (H4Pp^.Transform8x8<>0) And (Not Small) Then Begin If
  H4CabacOn Then Tx8:=H4CbTx8 Else Tx8:=H4Bit<>0; End;
 If Tx8 Then H4CurTx8:=1;
 If Cbp<>0 Then Begin
  If H4CabacOn Then Dq:=H4CbDqp Else Dq:=H4Se;
  If (Dq<-26) Or (Dq>25) Then Begin H4Err:=True; Exit; End;
  H4Qp:=(H4Qp+Dq+52) Mod 52;
  If Dq<>0 Then H4LastDqp:=1 Else H4LastDqp:=0;
 End Else H4LastDqp:=0;
 H4QpC[0]:=H4ChromaQp(H4Qp,H4Pp^.ChromaQpOffset); H4QpC[1]:=H4ChromaQp(H4Qp,
  H4Pp^.ChromaQpOffset2);
 If H4CabacOn Then Begin
  Ok:=H4LumaCabac(Tx8,False,CbpL);
  If Ok Then Ok:=H4ChromaCabac(CbpC);
 End Else Begin
  Ok:=H4LumaCavlc(Tx8,False,CbpL);
  If Ok Then Ok:=H4ChromaCavlc(CbpC);
 End;
 If Not Ok Then Begin H4Err:=True; Exit; End;
 If Tx8 Then Begin
  For B8:=0 To 3 Do If ((CbpL Shr B8) And 1)<>0 Then H4AddLuma8(B8,H4Qp,1);
 End Else
  For Blk:=0 To 15 Do If ((CbpL Shr (Blk Shr 2)) And 1)<>0 Then
   If H4Nnz[H4BlkY[Blk]*4+H4BlkX[Blk]]<>0 Then H4AddLuma4(Blk,H4Qp,3,False,0);
 H4AddChroma(False);
 H4StoreMb(False);
End;




{ ---- MP4 / MOV : tables d'echantillons ---- }
Type
 TH4Trk=Record
  Kind: LongInt;                       { 1 video, 2 audio, 0 autre }
  Ts: Int64; Fcc: String[4];
  Stts,Ctts,Stsz,Stsc,Stco,Elst: LongInt;
  SttsN,CttsN,SzN,ScN,CoN,ElN,FixedSz,ElVer: LongInt;
  CttsVer: LongInt; Co64: Boolean;
  Avcc,AvccLen,TrackId,Esds,EsdsLen: LongInt;
 End;
Var
 H4ZF: H4PBuf; H4ZSize: LongInt;
 H4ZTrk: Array[0..15] Of TH4Trk; H4ZNT: LongInt;
 H4ZMovieTs: Int64;

Function H4ZU32(At: LongInt): Int64;
Begin
 If (At<0) Or (At+4>H4ZSize) Then H4ZU32:=0
 Else H4ZU32:=(Int64(H4ZF^[At]) Shl 24) Or (Int64(H4ZF^[At+1]) Shl 16) Or (Int64(
  H4ZF^[At+2]) Shl 8) Or H4ZF^[At+3];
End;
Function H4ZL32(At: LongInt): LongInt;
Var V: Int64;
Begin
 V:=H4ZU32(At); If V>2000000000 Then V:=2000000000; H4ZL32:=V;
End;
Function H4ZS32(At: LongInt): LongInt;
Var V: Int64;
Begin
 V:=H4ZU32(At); If V>=2147483648 Then V:=V-4294967296; H4ZS32:=V;
End;
Function H4ZU64(At: LongInt): Int64;
Begin H4ZU64:=(H4ZU32(At) Shl 32) Or H4ZU32(At+4); End;
Function H4ZTag(At: LongInt): String;
Var I: LongInt; S: String;
Begin
 S:='';
 For I:=0 To 3 Do If (At+I>=0) And (At+I<H4ZSize) Then S:=S+Chr(H4ZF^[At+I]);
 H4ZTag:=S;
End;
{ cherche la prochaine boite de type Name dans [Start,Fin) ; P0..P1 = contenu ;
 Next = position suivante }
Function H4ZFind(Start,Fin: LongInt; Const Name: String; Var P0,P1,Next:
 LongInt): Boolean;
Var At,Hdr: LongInt; Sz: Int64;
Begin
 H4ZFind:=False; At:=Start;
 If Fin>H4ZSize Then Fin:=H4ZSize;
 While At+8<=Fin Do Begin
  Sz:=H4ZU32(At); Hdr:=8;
  If Sz=1 Then Begin Sz:=H4ZU64(At+8); Hdr:=16; End
  Else If Sz=0 Then Sz:=Fin-At;
  If (Sz<Hdr) Or (At+Sz>Fin) Then Begin
   If (Sz>=Hdr) And (At+Sz>Fin) Then Sz:=Fin-At Else Exit;
  End;
  If H4ZTag(At+4)=Name Then Begin P0:=At+Hdr; P1:=At+Sz; Next:=At+Sz; H4ZFind:=
   True; Exit; End;
  At:=At+Sz;
 End;
End;

Procedure H4ZParseTrak(P0,P1: LongInt);
Var T: TH4Trk; A0,A1,Nx,B0,B1,C0,C1,D0,D1,E0,E1,Ver,Cnt: LongInt;
Begin
 FillChar(T,SizeOf(T),0); T.Stts:=-1; T.Ctts:=-1; T.Stsz:=-1; T.Stsc:=-1;
  T.Stco:=-1; T.Elst:=-1; T.Avcc:=-1; T.Esds:=-1;
 If H4ZFind(P0,P1,'tkhd',A0,A1,Nx) Then Begin
  If H4ZF^[A0]=1 Then T.TrackId:=H4ZL32(A0+20) Else T.TrackId:=H4ZL32(A0+12);
 End;
 If Not H4ZFind(P0,P1,'mdia',A0,A1,Nx) Then Exit;
 If H4ZFind(A0,A1,'mdhd',B0,B1,Nx) Then Begin
  Ver:=H4ZF^[B0];
  If Ver=1 Then T.Ts:=H4ZU32(B0+20) Else T.Ts:=H4ZU32(B0+12);
 End;
 If H4ZFind(A0,A1,'hdlr',B0,B1,Nx) Then Begin
  If H4ZTag(B0+8)='vide' Then T.Kind:=1 Else If H4ZTag(B0+8)='soun' Then T.Kind:=
   2;
 End;
 If H4ZFind(A0,A1,'minf',B0,B1,Nx) Then
  If H4ZFind(B0,B1,'stbl',C0,C1,Nx) Then Begin
   If H4ZFind(C0,C1,'stsd',D0,D1,Nx) Then Begin
    If H4ZU32(D0+4)>=1 Then Begin
     T.Fcc:=Copy(H4ZTag(D0+12),1,4);
     If (T.Kind=1) And (D0+8+86<=D1) Then
      If H4ZFind(D0+8+86,D1,'avcC',E0,E1,Nx) Then Begin T.Avcc:=E0; T.AvccLen:=
       E1-E0; End;
     If (T.Kind=1) And (D0+8+86<=D1) Then
      If H4ZFind(D0+8+86,D1,'esds',E0,E1,Nx) Then Begin T.Esds:=E0; T.EsdsLen:=
       E1-E0; End;
    End;
   End;
   If H4ZFind(C0,C1,'stts',D0,D1,Nx) Then Begin T.SttsN:=H4ZL32(D0+4); T.Stts:=D0+
    8; End;
   If H4ZFind(C0,C1,'ctts',D0,D1,Nx) Then Begin T.CttsVer:=H4ZF^[D0]; T.CttsN:=
    H4ZL32(D0+4); T.Ctts:=D0+8; End;
   If H4ZFind(C0,C1,'stsz',D0,D1,Nx) Then Begin T.FixedSz:=H4ZL32(D0+4); T.SzN:=
    H4ZL32(D0+8); T.Stsz:=D0+12; End;
   If H4ZFind(C0,C1,'stsc',D0,D1,Nx) Then Begin T.ScN:=H4ZL32(D0+4); T.Stsc:=D0+8;
    End;
   If H4ZFind(C0,C1,'stco',D0,D1,Nx) Then Begin T.CoN:=H4ZL32(D0+4); T.Stco:=D0+8;
    End
   Else If H4ZFind(C0,C1,'co64',D0,D1,Nx) Then Begin T.CoN:=H4ZL32(D0+4); T.Stco:=
    D0+8; T.Co64:=True; End;
  End;
 If H4ZNT<16 Then Begin H4ZTrk[H4ZNT]:=T; Inc(H4ZNT); End;
End;

Procedure H4FeedNalPacket(P: H4PBuf; Len: LongInt; NalSz: LongInt; Pts:
 Int64);
{ NalSz=0 : flux Annex B (codes de debut) ; sinon unites precedees d'une
 longueur sur NalSz octets }
Var I,Start,E,N,K: LongInt; N64: Int64;
Begin
 If NalSz=0 Then Begin
  I:=0; Start:=-1;
  While I+2<Len Do Begin
   If (P^[I]=0) And (P^[I+1]=0) And (P^[I+2]=1) Then Begin
    If Start>=0 Then Begin
     E:=I; While (E>Start) And (P^[E-1]=0) Do Dec(E);
     H4HandleNal(H4PBuf(@P^[Start]),E-Start,Pts);
    End;
    Start:=I+3; Inc(I,3);
   End Else Inc(I);
  End;
  If Start>=0 Then Begin
   E:=Len; While (E>Start) And (P^[E-1]=0) Do Dec(E);
   H4HandleNal(H4PBuf(@P^[Start]),E-Start,Pts);
  End;
 End Else Begin
  I:=0;
  While I+NalSz<=Len Do Begin
   N64:=0; For K:=0 To NalSz-1 Do N64:=N64*256+P^[I+K];
   Inc(I,NalSz);
   If (N64<=0) Or (I+N64>Len) Then Break;
   N:=N64;
   H4HandleNal(H4PBuf(@P^[I]),N,Pts);
   Inc(I,N);
  End;
 End;
End;

{ lit un enregistrement avcC et alimente les SPS/PPS ; renvoie la taille du
 champ longueur }
Function H4FeedAvcc(Mp: H4PBuf; Len: LongInt): LongInt;
Var Pos,N,I,L: LongInt;
Begin
 H4FeedAvcc:=4;
 If (Len<7) Or (Mp^[0]<>1) Then Exit;
 H4FeedAvcc:=(Mp^[4] And 3)+1;
 Pos:=6; N:=Mp^[5] And 31;
 For I:=1 To N Do Begin
  If Pos+2>Len Then Exit;
  L:=Mp^[Pos]*256+Mp^[Pos+1]; Inc(Pos,2);
  If Pos+L>Len Then Exit;
  H4HandleNal(H4PBuf(@Mp^[Pos]),L,0); Inc(Pos,L);
 End;
 If Pos<Len Then Begin
  N:=Mp^[Pos]; Inc(Pos);
  For I:=1 To N Do Begin
   If Pos+2>Len Then Exit;
   L:=Mp^[Pos]*256+Mp^[Pos+1]; Inc(Pos,2);
   If Pos+L>Len Then Exit;
   H4HandleNal(H4PBuf(@Mp^[Pos]),L,0); Inc(Pos,L);
  End;
 End;
End;


Function H4AviIsH264(Const Fcc: String): Boolean;
Begin
 H4AviIsH264:=(Fcc='H264') Or (Fcc='h264') Or (Fcc='X264') Or (Fcc='x264') Or (
  Fcc='avc1') Or (Fcc='AVC1') Or (Fcc='DAVC') Or (Fcc='davc') Or (Fcc='VSSH') Or
  (Fcc='Q264') Or (Fcc='V264');
End;

{ ---- MPEG-4 Part 2 (DivX / Xvid / mp4v) : decodeur derive de FFMPEG-0, lui-meme
 adapte de libavcodec/mpeg4videodec.c, mpeg4video.c, h263.c, mpegvideo_motion.c
 (LGPL-2.1-or-later).  H3* = moteur H.263 commun, M4* = MPEG-4 ---- }
Function H4YAvSar(V: Int64; N: LongInt): Int64;
Begin
 If V>=0 Then H4YAvSar:=V Shr N Else H4YAvSar:=-1-((-1-V) Shr N);
End;
Procedure H4XUnsup(Const S: String);
Begin
 H4Stop:=True;     { flux non pris en charge : arret du decodage }
End;
{ ---- H.263 / H.261 / Sorenson Spark (FLV1): tables de libavcodec/h263data.c,
 h261data.c, mpegvideodata.c, LGPL-2.1-or-later ---- }
Const
 H4YIntraMcbpcCode: Array[0..8] Of Byte=(
  1,1,2,3,1,1,2,3,1);
 H4YIntraMcbpcBits: Array[0..8] Of Byte=(
  1,3,3,3,4,6,6,6,9);
 H4YInterMcbpcCode: Array[0..27] Of Byte=(
  1,3,2,5,3,4,3,3,3,7,6,5,4,4,3,2,
  2,5,4,5,1,0,0,0,2,12,14,15);
 H4YInterMcbpcBits: Array[0..27] Of Byte=(
  1,4,4,6,5,8,8,7,3,7,7,9,6,9,9,9,
  3,7,7,8,9,0,0,0,11,13,13,13);
 H4YCbpyTab: Array[0..31] Of Byte=(
  3,4,5,5,4,5,9,4,3,5,7,4,2,6,11,4,
  2,5,3,6,5,4,10,4,4,4,8,4,6,4,3,2);
 H4YMvTab: Array[0..65] Of Byte=(
  1,1,1,2,1,3,1,4,3,6,5,7,4,7,3,7,
  11,9,10,9,9,9,17,10,16,10,15,10,14,10,13,10,
  12,10,11,10,10,10,9,10,8,10,7,10,6,10,5,10,
  4,10,7,11,6,11,5,11,4,11,3,11,2,11,3,12,
  2,12);
 H4YInterVlc: Array[0..205] Of Word=(
  2,2,15,4,21,6,23,7,31,8,37,9,36,9,33,10,
  32,10,7,11,6,11,32,11,6,3,20,6,30,8,15,10,
  33,11,80,12,14,4,29,8,14,10,81,12,13,5,35,9,
  13,10,12,5,34,9,82,12,11,5,12,10,83,12,19,6,
  11,10,84,12,18,6,10,10,17,6,9,10,16,6,8,10,
  22,7,85,12,21,7,20,7,28,8,27,8,33,9,32,9,
  31,9,30,9,29,9,28,9,27,9,26,9,34,11,35,11,
  86,12,87,12,7,4,25,9,5,11,15,6,4,11,14,6,
  13,6,12,6,19,7,18,7,17,7,16,7,26,8,25,8,
  24,8,23,8,22,8,21,8,20,8,19,8,24,9,23,9,
  22,9,21,9,20,9,19,9,18,9,17,9,7,10,6,10,
  5,10,4,10,36,11,37,11,38,11,39,11,88,12,89,12,
  90,12,91,12,92,12,93,12,94,12,95,12,3,7);
 H4YInterLevel: Array[0..101] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,1,2,3,4,
  5,6,1,2,3,4,1,2,3,1,2,3,1,2,3,1,
  2,3,1,2,1,2,1,2,1,2,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,2,3,1,2,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1);
 H4YInterRun: Array[0..101] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,
  1,1,2,2,2,2,3,3,3,4,4,4,5,5,5,6,
  6,6,7,7,8,8,9,9,10,10,11,12,13,14,15,16,
  17,18,19,20,21,22,23,24,25,26,0,0,0,1,1,2,
  3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,
  19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,
  35,36,37,38,39,40);
 H4YIntraVlcAic: Array[0..205] Of Word=(
  2,2,6,3,14,4,12,5,13,5,16,6,17,6,18,6,
  22,7,27,8,32,9,33,9,26,9,27,9,28,9,29,9,
  30,9,31,9,35,11,34,11,87,12,86,12,85,12,84,12,
  83,12,15,4,20,6,20,7,30,8,15,10,33,11,80,12,
  11,5,21,7,14,10,9,10,21,6,29,8,13,10,81,12,
  19,6,35,9,7,11,23,7,34,9,82,12,28,8,12,10,
  31,8,11,10,37,9,10,10,36,9,6,11,33,10,32,10,
  8,10,32,11,7,4,12,6,16,7,19,8,17,9,18,9,
  4,10,39,11,38,11,95,12,15,6,19,9,5,10,37,11,
  14,6,20,9,36,11,13,6,6,10,94,12,17,7,7,10,
  19,7,93,12,18,7,92,12,20,8,91,12,21,8,26,8,
  25,8,24,8,23,8,22,8,25,9,21,9,22,9,24,9,
  23,9,4,11,5,11,88,12,89,12,90,12,3,7);
 H4YIntraRunAic: Array[0..101] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,
  2,2,2,2,3,3,3,3,4,4,4,5,5,5,6,6,
  7,7,8,8,9,9,10,11,12,13,0,0,0,0,0,0,
  0,0,0,0,1,1,1,1,2,2,2,3,3,3,4,4,
  5,5,6,6,7,7,8,9,10,11,12,13,14,15,16,17,
  18,19,20,21,22,23);
 H4YIntraLevelAic: Array[0..101] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  17,18,19,20,21,22,23,24,25,1,2,3,4,5,6,7,
  1,2,3,4,1,2,3,4,1,2,3,1,2,3,1,2,
  1,2,1,2,1,2,1,1,1,1,1,2,3,4,5,6,
  7,8,9,10,1,2,3,4,1,2,3,1,2,3,1,2,
  1,2,1,2,1,2,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1);
 H4YFormat: Array[0..15] Of Word=(
  0,0,128,96,176,144,352,288,704,576,1408,1152,0,0,0,0);
 H4YAicDcScale: Array[0..31] Of Byte=(
  0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,
  32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62);
 H4YModQuant: Array[0..63] Of Byte=(
  0,3,1,2,3,4,5,6,7,8,9,9,10,11,12,13,
  14,15,16,17,18,18,19,20,21,22,23,24,25,26,27,28,
  0,2,3,4,5,6,7,8,9,10,11,13,14,15,16,17,
  18,19,20,21,22,24,25,26,27,28,29,30,31,31,31,26);
 H4YChromaQ: Array[0..31] Of Byte=(
  0,1,2,3,4,5,6,6,7,8,9,9,10,10,11,11,
  12,12,12,13,13,13,14,14,14,14,14,15,15,15,15,15);
 H4YMbaMax: Array[0..5] Of Word=(
  47,98,395,1583,6335,9215);
 H4YMbaLength: Array[0..6] Of Byte=(
  6,7,9,11,13,14,14);
 H4YMbtypeB: Array[0..29] Of Byte=(
  1,1,3,3,1,5,4,4,5,4,6,6,2,4,3,4,
  7,6,4,6,5,6,1,6,1,10,1,7,1,8);
 H4YCbpcB: Array[0..7] Of Byte=(
  0,1,2,2,7,3,6,3);

Type
 TH3I16=Array[0..200000000] Of SmallInt; PH3I16=^TH3I16;
 TH3Blk=Array[0..63] Of SmallInt;
 TH3Vlc=Record Sym: Array[0..65535] Of SmallInt; Len: Array[0..65535] Of Byte;
  Bits: LongInt; End;
 TH3Pic=Record
  Y,U,V: H4PBuf;
  Mt: H4PLN;       { mb_type, decale de 2*mb_stride+1 }
  Mv: PH3I16;       { vecteurs (x,y) par bloc 8x8, decale de 4 blocs }
  Mv1: PH3I16;      { liste 1 (images B) }
  Qs: H4PBuf;    { qscale par macrobloc, decale de 2*mb_stride+1 }
 End;
Const
 H4Y_INTRA=1; H4Y_16X16=8; H4Y_8X8=64; H4Y_SKIP=2048; H4Y_ACPRED=512; H4Y_L0=12288;
  H4Y_DIRECT2=256; H4Y_QUANT=65536; H4Y_CBP=131072;
 H4YZigzag: Array[0..63] Of Byte=(0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,
  26,33,40,48,41,34,27,20,13,6,7,14,21,28,
  35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,
   61,54,47,55,62,63);
 H4YAltH: Array[0..63] Of Byte=(0,1,2,3,8,9,16,17,10,11,4,5,6,7,15,14,13,12,19,
  18,24,25,32,33,26,27,20,21,22,23,28,29,
  30,31,34,35,40,41,48,49,42,43,36,37,38,39,44,45,46,47,50,51,56,57,58,59,52,53,
   54,55,60,61,62,63);
 H4YAltV: Array[0..63] Of Byte=(0,8,16,24,1,9,2,10,17,25,32,40,48,56,57,49,41,33,
  26,18,3,11,4,12,19,27,34,42,50,58,35,43,
  51,59,20,28,5,13,6,14,21,29,36,44,52,60,37,45,53,61,22,30,7,15,23,31,38,46,54,
   62,39,47,55,63);
 H4YLoopStrength: Array[0..31] Of Byte=(0,1,1,2,2,3,3,4,4,4,5,5,6,6,7,7,7,8,8,8,
  9,9,9,10,10,10,11,11,11,12,12,12);
 H4YRoundTab: Array[0..15] Of Byte=(0,0,0,1,1,1,1,1,0,0,0,0,0,0,1,1);
Var
 { lecteur de bits }
 H4YBuf: H4PBuf; H4YSize,H4YPos: LongInt;
 { tables VLC }
 H4YVIntra,H4YVInter,H4YVCbpy,H4YVMv: TH3Vlc;
 H4YVRlInter,H4YVRlAic: TH3Vlc;   { sym: indice de table (0..102), 102 =
  echappement }
 H4YVMbB,H4YVCbpcB: TH3Vlc;
 H4YRunInter,H4YRunAic: Array[0..102] Of SmallInt;  { run+1 (+192 si dernier) }
 H4YLevInter,H4YLevAic: Array[0..102] Of SmallInt;
 H4YInit: Boolean;
 H4YRasterEnd: Array[0..63] Of Byte;
 H4YAltHRE,H4YAltVRE: Array[0..63] Of Byte;

Function H4YLeft: LongInt;Begin H4YLeft:=H4YSize*8-H4YPos; End;
Function H4YShow(N: LongInt): LongInt;
Var P: LongInt; V: Int64;
Begin
 If N=0 Then Begin H4YShow:=0; Exit; End;
 P:=H4YPos Shr 3;
 V:=(Int64(H4YBuf^[P]) Shl 32) Or (Int64(H4YBuf^[P+1]) Shl 24) Or (Int64(H4YBuf^[P+
  2]) Shl 16) Or (Int64(H4YBuf^[P+3]) Shl 8) Or Int64(H4YBuf^[P+4]);
 H4YShow:=(V Shr (40-(H4YPos And 7)-N)) And ((Int64(1) Shl N)-1);
End;
Function H4YBits(N: LongInt): LongInt;Begin H4YBits:=H4YShow(N); Inc(H4YPos,N); End;
Function H4YBit: LongInt;Begin H4YBit:=(H4YBuf^[H4YPos Shr 3] Shr (7-(H4YPos And 7)))
 And 1; Inc(H4YPos); End;
Procedure H4YSkip(N: LongInt);Begin Inc(H4YPos,N); End;
Function H4YSBits(N: LongInt): LongInt;
Var V: LongInt;
Begin V:=H4YShow(N); If V>=(LongInt(1) Shl (N-1)) Then V:=V-(LongInt(1) Shl N);
 H4YSBits:=V; End;
Procedure H4YAlign;Begin H4YPos:=(H4YPos+7) And -8; End;
Function H4YSar(V: LongInt; N: LongInt): LongInt;
Begin If V>=0 Then H4YSar:=V Shr N Else H4YSar:=-1-((-1-V) Shr N); End;
Function H4YMid(A,B,C: LongInt): LongInt;
Var Lo,Hi: LongInt;
Begin
 If A<B Then Begin Lo:=A; Hi:=B; End Else Begin Lo:=B; Hi:=A; End;
 If C<Hi Then Hi:=C;
 If Lo>Hi Then H4YMid:=Lo Else H4YMid:=Hi;
End;
Function H4YClip(V,Lo,Hi: LongInt): LongInt;Begin If V<Lo Then V:=Lo; If V>Hi
 Then V:=Hi; H4YClip:=V; End;

{ construit une table VLC directe a partir de (code,longueur); Pas = 1 (tables
 separees) ou 2 (paires) }
Procedure H4YBuildVlc(Var T: TH3Vlc; N: LongInt; Codes,Lens: H4PBuf;
 WideCodes: Boolean; Step: LongInt);
Var I,J,Len,Code,Span: LongInt;
Begin
 T.Bits:=0;
 For I:=0 To N-1 Do Begin
  Len:=Lens^[I*Step]; If Len>T.Bits Then T.Bits:=Len;
 End;
 For I:=0 To (LongInt(1) Shl T.Bits)-1 Do Begin T.Sym[I]:=-1; T.Len[I]:=0; End;
 For I:=0 To N-1 Do Begin
  Len:=Lens^[I*Step]; If Len=0 Then Continue;
  Code:=Codes^[I*Step];
  Span:=LongInt(1) Shl (T.Bits-Len);
  For J:=0 To Span-1 Do Begin
   T.Sym[(Code Shl (T.Bits-Len))+J]:=I; T.Len[(Code Shl (T.Bits-Len))+J]:=Len;
  End;
 End;
End;

Function H4YGetVlc(Var T: TH3Vlc): LongInt;
Var Ix: LongInt;
Begin
 Ix:=H4YShow(T.Bits);
 H4YGetVlc:=T.Sym[Ix]; Inc(H4YPos,T.Len[Ix]);
End;

Procedure H4YInitTables;
Var
 I,J: LongInt; Cd,Bt: Array[0..255] Of Byte; Cw: Array[0..255] Of Word;
 Tmp: Array[0..3] Of Byte;
Procedure BuildRl(Var T: TH3Vlc; Const Vl: Array Of Word; Const Run,Lev: Array
 Of ShortInt; Var RunO,LevO: Array Of SmallInt);
Var K,Len,J: LongInt;
Begin
 T.Bits:=0;
 For K:=0 To 102 Do Begin Len:=Vl[K*2+1]; If Len>T.Bits Then T.Bits:=Len; End;
 For K:=0 To (LongInt(1) Shl T.Bits)-1 Do Begin T.Sym[K]:=-1; T.Len[K]:=0; End;
 For K:=0 To 102 Do Begin
  Len:=Vl[K*2+1];
  For J:=0 To (LongInt(1) Shl (T.Bits-Len))-1 Do Begin
   T.Sym[(Vl[K*2] Shl (T.Bits-Len))+J]:=K; T.Len[(Vl[K*2] Shl (T.Bits-Len))+J]:=
    Len;
  End;
  If K<102 Then Begin
   RunO[K]:=Run[K]+1; If K>=58 Then Inc(RunO[K],192);
   LevO[K]:=Lev[K];
  End;
 End;
End;
Begin
 If H4YInit Then Exit;
 H4YInit:=True;
 H4YBuildVlc(H4YVIntra,9,@H4YIntraMcbpcCode,@H4YIntraMcbpcBits,False,1);
 H4YBuildVlc(H4YVInter,28,@H4YInterMcbpcCode,@H4YInterMcbpcBits,False,1);
 H4YBuildVlc(H4YVCbpy,16,@H4YCbpyTab,@H4YCbpyTab[1],False,2);
 H4YBuildVlc(H4YVMv,33,@H4YMvTab,@H4YMvTab[1],False,2);
 H4YBuildVlc(H4YVMbB,15,@H4YMbtypeB,@H4YMbtypeB[1],False,2);
 H4YBuildVlc(H4YVCbpcB,4,@H4YCbpcB,@H4YCbpcB[1],False,2);
 BuildRl(H4YVRlInter,H4YInterVlc,H4YInterRun,H4YInterLevel,H4YRunInter,H4YLevInter);
 BuildRl(H4YVRlAic,H4YIntraVlcAic,H4YIntraRunAic,H4YIntraLevelAic,H4YRunAic,
  H4YLevAic);
 J:=-1;
 For I:=0 To 63 Do Begin If H4YZigzag[I]>J Then J:=H4YZigzag[I]; H4YRasterEnd[I]:=
  J; End;
 J:=-1;
 For I:=0 To 63 Do Begin If H4YAltH[I]>J Then J:=H4YAltH[I]; H4YAltHRE[I]:=J; End;
 J:=-1;
 For I:=0 To 63 Do Begin If H4YAltV[I]>J Then J:=H4YAltV[I]; H4YAltVRE[I]:=J; End;
End;

Var
 { parametres de l'image / du flux }
 H4YWd,H4YHt,H4YMbW,H4YMbH,H4YMbStride,H4YB8Stride,H4YMbNum,H4YLY,H4YLC,H4YHEdge,H4YVEdge:
  LongInt;
 H4YPictType: LongInt;  { 0 I, 1 P, 2 B }
 H4YQscale,H4YChromaQscale,H4YYDcScale,H4YCDcScale: LongInt;
 H4YObmc,H4YUmvplus,H4YLongVec,H4YAic,H4YLoop,H4YSliceStruct,H4YAltInter,H4YModQ,
  H4YPbFrame,H4YNoRounding,H4YPlus,H4YCustomPcf,H4YFlv,H4YDroppable: LongInt;
 H4YPicNum,H4YLastNonB,H4YTime,H4YPpTime,H4YPbTime: LongInt;
 H4YAspect: Array[0..1] Of LongInt;  { sample_aspect_ratio num,den }
 H4YFpsN,H4YFpsD: LongInt;
 H4YChromaTab: Boolean;  { True: table de qscale chroma modifiee }
 H4YInited: Boolean;
 { etat macrobloc }
 H4YMbX,H4YMbY,H4YMbIntra,H4YAcPred,H4YAicDir,H4YMvType,H4YMbSkipped,H4YFirstLine,
  H4YResyncX,H4YResyncY: LongInt;
 H4YMv: Array[0..3,0..1] Of LongInt;
 H4YBlk: Array[0..5] Of TH3Blk;
 H4YBlkLast: Array[0..5] Of LongInt;
 H4YLastGb: LongInt;
 { images }
 H4YP: Array[0..2] Of TH3Pic;
 H4YCurI,H4YRefI: LongInt;  { indices dans H4YP; -1 = aucune }
 H4YDc: Array[0..2] Of PH3I16;   { dc_val: base ; acces par decalage }
 H4YAc: PH3I16;
 H4YDcOff: Array[0..2] Of LongInt;
 H4YIntra: H4PBuf;  { mbintra_table }
 H4YDcBase: PH3I16; H4YDcN,H4YAcN: LongInt;
 H4YErr: Boolean;
 { RealVideo 1.0/2.0 }
 H4YRvMode,H4YRv10Ver,H4YMbNumLeft: LongInt; H4YMvList,H4YMvDir,H4YBwdI,H4YAvg:
  LongInt; H4YMv1: Array[0..3,0..1] Of LongInt; H4YDirScale: Array[0..1,0..63] Of
  LongInt; H4YRvLastDc,H4YRvFirst: Array[0..2] Of LongInt;
 H4YRvLumSym,H4YRvChrSym: Array[0..1023] Of Byte; H4YRvLumCnt,H4YRvChrCnt,
  H4YRvLumFirst,H4YRvChrFirst,H4YRvLumOff,H4YRvChrOff: Array[0..17] Of LongInt;
  H4YRvInit: Boolean;


Function H4YSext(V,Bits: LongInt): LongInt;
Begin
 V:=V And ((LongInt(1) Shl Bits)-1);
 If V>=(LongInt(1) Shl (Bits-1)) Then V:=V-(LongInt(1) Shl Bits);
 H4YSext:=V;
End;


Function H4YDecMotion(Pred,FCode: LongInt): LongInt;
Var Code,Val,Sign,Shift: LongInt;
Begin
 Code:=H4YGetVlc(H4YVMv);
 If Code=0 Then Begin H4YDecMotion:=Pred; Exit; End;
 If Code<0 Then Begin H4YDecMotion:=$FFFF; Exit; End;
 Sign:=H4YBit;
 Shift:=FCode-1;
 Val:=Code;
 If Shift<>0 Then Begin
  Val:=(Val-1) Shl Shift;
  Val:=Val Or H4YBits(Shift);
  Inc(Val);
 End;
 If Sign<>0 Then Val:=-Val;
 Inc(Val,Pred);
 If H4YLongVec=0 Then Val:=H4YSext(Val,5+FCode)
 Else Begin
  If (Pred<-31) And (Val<-63) Then Inc(Val,64);
  If (Pred>32) And (Val>63) Then Dec(Val,64);
 End;
 H4YDecMotion:=Val;
End;

{ h263p_decode_umotion }

Procedure H4YIdct(Var Blk: TH3Blk; Dest: H4PBuf; Off,Stride: LongInt; Add:
 Boolean);
Const W1=22725; W2=21407; W3=19266; W4=16383; W5=12873; W6=8867; W7=4520;
Var
 I,K: Integer; A0,A1,A2,A3,B0,B1,B2,B3: Int64; R: Array[0..7] Of Int64; V:
  Int64;
Procedure Put(Col,Row: Integer; X: Int64);
Var D: Int64;
Begin
 X:=H4YAvSar(X,20);
 If Add Then X:=X+Dest^[Off+Row*Stride+Col];
 If X<0 Then X:=0; If X>255 Then X:=255;
 Dest^[Off+Row*Stride+Col]:=X;
End;
Begin
 For I:=0 To 7 Do Begin
  For K:=0 To 7 Do R[K]:=Blk[I*8+K];
  If (R[1] Or R[2] Or R[3] Or R[4] Or R[5] Or R[6] Or R[7])=0 Then Begin
   V:=SmallInt(R[0]*8); For K:=0 To 7 Do Blk[I*8+K]:=V;
  End Else Begin
   A0:=W4*R[0]+(1 Shl 10); A1:=A0; A2:=A0; A3:=A0;
   Inc(A0,W2*R[2]); Inc(A1,W6*R[2]); Dec(A2,W6*R[2]); Dec(A3,W2*R[2]);
   B0:=W1*R[1]+W3*R[3]; B1:=W3*R[1]-W7*R[3]; B2:=W5*R[1]-W1*R[3]; B3:=W7*R[1]-
    W5*R[3];
   If (R[4] Or R[5] Or R[6] Or R[7])<>0 Then Begin
    Inc(A0,W4*R[4]+W6*R[6]); Inc(A1,-W4*R[4]-W2*R[6]); Inc(A2,-W4*R[4]+W2*R[6]);
     Inc(A3,W4*R[4]-W6*R[6]);
    Inc(B0,W5*R[5]+W7*R[7]); Inc(B1,-W1*R[5]-W5*R[7]); Inc(B2,W7*R[5]+W3*R[7]);
     Inc(B3,W3*R[5]-W1*R[7]);
   End;
   Blk[I*8+0]:=SmallInt(H4YAvSar(A0+B0,11)); Blk[I*8+7]:=SmallInt(H4YAvSar(A0-B0,11));
   Blk[I*8+1]:=SmallInt(H4YAvSar(A1+B1,11)); Blk[I*8+6]:=SmallInt(H4YAvSar(A1-B1,11));
   Blk[I*8+2]:=SmallInt(H4YAvSar(A2+B2,11)); Blk[I*8+5]:=SmallInt(H4YAvSar(A2-B2,11));
   Blk[I*8+3]:=SmallInt(H4YAvSar(A3+B3,11)); Blk[I*8+4]:=SmallInt(H4YAvSar(A3-B3,11));
  End;
 End;
 For I:=0 To 7 Do Begin
  For K:=0 To 7 Do R[K]:=Blk[K*8+I];
  A0:=W4*(R[0]+32); A1:=A0; A2:=A0; A3:=A0;
  Inc(A0,W2*R[2]); Inc(A1,W6*R[2]); Dec(A2,W6*R[2]); Dec(A3,W2*R[2]);
  B0:=W1*R[1]+W3*R[3]; B1:=W3*R[1]-W7*R[3]; B2:=W5*R[1]-W1*R[3]; B3:=W7*R[1]-W5*
   R[3];
  If R[4]<>0 Then Begin Inc(A0,W4*R[4]); Dec(A1,W4*R[4]); Dec(A2,W4*R[4]); Inc(
   A3,W4*R[4]); End;
  If R[5]<>0 Then Begin Inc(B0,W5*R[5]); Dec(B1,W1*R[5]); Inc(B2,W7*R[5]); Inc(
   B3,W3*R[5]); End;
  If R[6]<>0 Then Begin Inc(A0,W6*R[6]); Dec(A1,W2*R[6]); Inc(A2,W2*R[6]); Dec(
   A3,W6*R[6]); End;
  If R[7]<>0 Then Begin Inc(B0,W7*R[7]); Dec(B1,W5*R[7]); Inc(B2,W3*R[7]); Dec(
   B3,W1*R[7]); End;
  Put(I,0,A0+B0); Put(I,1,A1+B1); Put(I,2,A2+B2); Put(I,3,A3+B3);
  Put(I,4,A3-B3); Put(I,5,A2-B2); Put(I,6,A1-B1); Put(I,7,A0-B0);
 End;
End;

{ ---- MPEG-4 Part 2 : decodeur (libavcodec/mpeg4videodec.c, mpeg4video.c,
 h263.c, mpegvideo_motion.c, qpeldsp.c,
       mpegvideodsp.c, LGPL-2.1-or-later) ---- }
Const
 H4XDcLum: Array[0..25] Of Byte=(
  3,3,3,2,2,2,2,3,1,3,1,4,1,5,1,6,
  1,7,1,8,1,9,1,10,1,11);
 H4XDcChr: Array[0..25] Of Byte=(
  3,2,2,2,1,2,1,3,1,4,1,5,1,6,1,7,
  1,8,1,9,1,10,1,11,1,12);
 H4XIntraVlc: Array[0..205] Of Word=(
  2,2,6,3,15,4,13,5,12,5,21,6,19,6,18,6,
  23,7,31,8,30,8,29,8,37,9,36,9,35,9,33,9,
  33,10,32,10,15,10,14,10,7,11,6,11,32,11,33,11,
  80,12,81,12,82,12,14,4,20,6,22,7,28,8,32,9,
  31,9,13,10,34,11,83,12,85,12,11,5,21,7,30,9,
  12,10,86,12,17,6,27,8,29,9,11,10,16,6,34,9,
  10,10,13,6,28,9,8,10,18,7,27,9,84,12,20,7,
  26,9,87,12,25,8,9,10,24,8,35,11,23,8,25,9,
  24,9,7,10,88,12,7,4,12,6,22,8,23,9,6,10,
  5,11,4,11,89,12,15,6,22,9,5,10,14,6,4,10,
  17,7,36,11,16,7,37,11,19,7,90,12,21,8,91,12,
  20,8,19,8,26,8,21,9,20,9,19,9,18,9,17,9,
  38,11,39,11,92,12,93,12,94,12,95,12,3,7);
 H4XIntraLev: Array[0..101] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  17,18,19,20,21,22,23,24,25,26,27,1,2,3,4,5,
  6,7,8,9,10,1,2,3,4,5,1,2,3,4,1,2,
  3,1,2,3,1,2,3,1,2,3,1,2,1,2,1,1,
  1,1,1,1,2,3,4,5,6,7,8,1,2,3,1,2,
  1,2,1,2,1,2,1,2,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1);
 H4XIntraRun: Array[0..101] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,
  1,1,1,1,1,2,2,2,2,2,3,3,3,3,4,4,
  4,5,5,5,6,6,6,7,7,7,8,8,9,9,10,11,
  12,13,14,0,0,0,0,0,0,0,0,1,1,1,2,2,
  3,3,4,4,5,5,6,6,7,8,9,10,11,12,13,14,
  15,16,17,18,19,20);
 H4XInterRvlc: Array[0..339] Of Word=(
  6,3,1,4,4,5,28,7,60,8,61,8,124,9,252,10,
  253,10,508,11,509,11,1020,12,2044,13,2045,13,3068,13,3069,13,
  4092,14,4093,14,8188,15,7,3,12,6,92,8,125,9,380,10,
  764,11,1021,12,3580,13,6140,14,6141,14,10,4,29,7,188,9,
  765,11,1532,12,7164,14,7165,14,5,5,93,8,381,10,1533,12,
  3581,13,7676,14,8189,15,8,5,108,8,892,11,3836,13,12284,15,
  9,5,189,9,893,11,3837,13,13,6,444,10,1788,12,7677,14,
  20,6,445,10,1789,12,12285,15,21,6,476,10,3964,13,44,7,
  477,10,7932,14,45,7,956,11,52,7,1916,12,109,8,3965,13,
  116,8,7933,14,117,8,8060,14,220,9,8061,14,221,9,8124,14,
  236,9,14332,15,492,10,493,10,500,10,957,11,988,11,989,11,
  1004,11,1005,11,1012,11,1917,12,1980,12,1981,12,4028,13,4029,13,
  4060,13,4061,13,8125,14,8156,14,8157,14,14333,15,15356,15,11,4,
  120,8,1013,11,4076,13,8172,14,18,5,237,9,2012,12,8173,14,
  15357,15,19,5,1016,11,15868,15,24,6,2013,12,25,6,2028,12,
  34,6,4077,13,35,6,4084,13,53,7,4085,13,56,7,4088,13,
  57,7,4089,13,66,7,8180,14,67,7,8181,14,121,8,8184,14,
  130,8,15869,15,131,8,244,9,245,9,248,9,249,9,258,9,
  259,9,501,10,504,10,505,10,514,10,515,10,1017,11,1026,11,
  1027,11,2029,12,2036,12,2037,12,2040,12,2041,12,2050,12,2051,12,
  4098,13,4099,13,8185,14,8194,14,8195,14,16124,15,16125,15,16252,15,
  16253,15,0,4);
 H4XInterRvlcRun: Array[0..168] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,1,1,1,1,1,1,1,1,1,1,2,2,2,
  2,2,2,2,3,3,3,3,3,3,3,4,4,4,4,4,
  5,5,5,5,6,6,6,6,7,7,7,7,8,8,8,9,
  9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,
  17,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,
  32,33,34,35,36,37,38,0,0,0,0,0,1,1,1,1,
  1,2,2,2,3,3,4,4,5,5,6,6,7,7,8,8,
  9,9,10,10,11,11,12,12,13,13,14,15,16,17,18,19,
  20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,
  36,37,38,39,40,41,42,43,44);
 H4XInterRvlcLev: Array[0..168] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  17,18,19,1,2,3,4,5,6,7,8,9,10,1,2,3,
  4,5,6,7,1,2,3,4,5,6,7,1,2,3,4,5,
  1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,1,
  2,3,1,2,1,2,1,2,1,2,1,2,1,2,1,2,
  1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,2,3,4,5,1,2,3,4,
  5,1,2,3,1,2,1,2,1,2,1,2,1,2,1,2,
  1,2,1,2,1,2,1,2,1,2,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1);
 H4XIntraRvlc: Array[0..339] Of Word=(
  6,3,7,3,10,4,9,5,20,6,21,6,52,7,116,8,
  117,8,221,9,236,9,492,10,493,10,500,10,1004,11,1005,11,
  1012,11,1917,12,1980,12,4029,13,4060,13,1981,12,4061,13,8125,14,
  8156,14,8157,14,8188,15,1,4,8,5,45,7,108,8,109,8,
  220,9,477,10,988,11,989,11,1916,12,4028,13,8061,14,8124,14,
  4,5,44,7,188,9,476,10,956,11,957,11,3837,13,3964,13,
  3965,13,7933,14,8060,14,5,5,92,8,189,9,893,11,1788,12,
  3836,13,7677,14,7932,14,8189,15,12,6,93,8,445,10,1021,12,
  1789,12,7165,14,13,6,125,9,764,11,1532,12,7164,14,7676,14,
  28,7,380,10,765,11,1533,12,12284,15,29,7,381,10,892,11,
  3581,13,12285,15,60,8,444,10,3069,13,6141,14,61,8,509,11,
  3580,13,14332,15,124,9,1020,12,252,10,3068,13,253,10,14333,15,
  508,11,2044,13,2045,13,4092,14,4093,14,6140,14,15356,15,11,4,
  120,8,1013,11,4076,13,8172,14,18,5,237,9,2012,12,8173,14,
  15357,15,19,5,1016,11,15868,15,24,6,2013,12,25,6,2028,12,
  34,6,4077,13,35,6,4084,13,53,7,4085,13,56,7,4088,13,
  57,7,4089,13,66,7,8180,14,67,7,8181,14,121,8,8184,14,
  130,8,15869,15,131,8,244,9,245,9,248,9,249,9,258,9,
  259,9,501,10,504,10,505,10,514,10,515,10,1017,11,1026,11,
  1027,11,2029,12,2036,12,2037,12,2040,12,2041,12,2050,12,2051,12,
  4098,13,4099,13,8185,14,8194,14,8195,14,16124,15,16125,15,16252,15,
  16253,15,0,4);
 H4XIntraRvlcRun: Array[0..168] Of ShortInt=(
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,
  1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,
  2,2,2,3,3,3,3,3,3,3,3,3,4,4,4,4,
  4,4,5,5,5,5,5,5,6,6,6,6,6,7,7,7,
  7,7,8,8,8,8,9,9,9,9,10,10,11,11,12,12,
  13,14,15,16,17,18,19,0,0,0,0,0,1,1,1,1,
  1,2,2,2,3,3,4,4,5,5,6,6,7,7,8,8,
  9,9,10,10,11,11,12,12,13,13,14,15,16,17,18,19,
  20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,
  36,37,38,39,40,41,42,43,44);
 H4XIntraRvlcLev: Array[0..168] Of ShortInt=(
  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  17,18,19,20,21,22,23,24,25,26,27,1,2,3,4,5,
  6,7,8,9,10,11,12,13,1,2,3,4,5,6,7,8,
  9,10,11,1,2,3,4,5,6,7,8,9,1,2,3,4,
  5,6,1,2,3,4,5,6,1,2,3,4,5,1,2,3,
  4,5,1,2,3,4,1,2,3,4,1,2,1,2,1,2,
  1,1,1,1,1,1,1,1,2,3,4,5,1,2,3,4,
  5,1,2,3,1,2,1,2,1,2,1,2,1,2,1,2,
  1,2,1,2,1,2,1,2,1,2,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1);
 H4XDefIntra: Array[0..63] Of Byte=(
  8,17,18,19,21,23,25,27,
  17,18,19,21,23,25,27,28,
  20,21,22,23,24,26,28,30,
  21,22,23,24,26,28,30,32,
  22,23,24,26,28,30,32,35,
  23,24,26,28,30,32,35,38,
  25,26,28,30,32,35,38,41,
  27,28,30,32,35,38,41,45);
 H4XDefInter: Array[0..63] Of Byte=(
  16,17,18,19,20,21,22,23,
  17,18,19,20,21,22,23,24,
  18,19,20,21,22,23,24,25,
  19,20,21,22,23,24,26,27,
  20,21,22,23,25,26,27,28,
  21,22,23,24,26,27,28,30,
  22,23,24,26,27,28,30,31,
  23,24,25,27,28,30,31,33);
 H4XYDcScale: Array[0..31] Of Byte=(
  0,8,8,8,8,10,12,14,16,17,18,19,20,21,22,23,
  24,25,26,27,28,29,30,31,32,34,36,38,40,42,44,46);
 H4XCDcScale: Array[0..31] Of Byte=(
  0,8,8,8,8,9,9,10,10,11,11,12,12,13,13,14,
  14,15,15,16,16,17,17,18,18,19,20,21,22,23,24,25);
Type
 TM4Rl=Record Vlc: TH3Vlc; N,Last: LongInt; Run,Lev: Array[0..199] Of SmallInt;
  MaxLev,MaxRun: Array[0..1,0..63] Of SmallInt; End;
 PM4Rl=^TM4Rl;
 TM4L32=Array[0..40000000] Of LongInt; PM4L32=^TM4L32;
 TM4Pic=Record Y,U,V,Ref,Qs,Sk: H4PBuf; Mt: PM4L32; Mv: PH3I16; IsRef,Used:
  Boolean; PType: LongInt; Time: Int64; End;
Const
 H4X_INTRA=1; H4X_16X16=2; H4X_8X8=4; H4X_16X8=8; H4X_INTERLACED=16; H4X_SKIP=32;
  H4X_ACPRED=64; H4X_DIRECT=128; H4X_GMC=256;
 H4X_L0=512; H4X_L1=1024;
 H4X_BUG_NOPAD=16; H4X_BUG_XVIDILACE=4; H4X_BUG_UMP4=8; H4X_BUG_QPELCH=64;
  H4X_BUG_QPELCH2=256; H4X_BUG_DIRBLK=512; H4X_BUG_EDGE=1024;
 H4X_BUG_HPELCH=2048; H4X_BUG_DCCLIP=4096; H4X_BUG_STDQPEL=128; H4X_BUG_AMV=32;
 H4X_SLICE_OK=0; H4X_SLICE_ERR=-1; H4X_SLICE_END=-2; H4X_SLICE_NOEND=-3;
 H4X_SKIPPED=-100;
 H4XDcThr: Array[0..7] Of Byte=(99,13,15,17,19,21,23,0);
 H4XSprLen: Array[0..14] Of Byte=(2,3,3,3,3,3,4,5,6,7,8,9,10,11,12);
 H4XAspect: Array[0..15,0..1] Of Byte=((0,1),(1,1),(12,11),(10,11),(16,11),(40,
  33),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1),(0,1));
Var
 H4XInit: Boolean;
 H4XRlIntra,H4XRlRvIntra,H4XRlRvInter,H4XRlInter: TM4Rl;
 H4XVDcL,H4XVDcC,H4XVSpr: TH3Vlc;
 { flux / VOL }
 H4XW,H4XH,H4XMbW,H4XMbH,H4XMbS,H4XB8S,H4XMbNum,H4XHEdge,H4XVEdge,H4XLY,H4XLC: LongInt;
 H4XAllocW,H4XAllocH: LongInt; H4XHave: Boolean;
 H4XVoType,H4XShape,H4XTIncBits,H4XRes,H4XFixedRate,H4XProg,H4XSprUsage,H4XNumWarp,
  H4XWarpAcc,H4XBrightChg,H4XQuantPrec,H4XMpegQuant,H4XQuarterS,
 H4XDataPart,H4XRvlc,H4XResyncMarker,H4XNewPred,H4XScal,H4XEnhType,H4XLowDelay,
  H4XVolCtl: LongInt;
 H4XCplxI,H4XCplxP,H4XCplxB: LongInt;
 H4XSarN,H4XSarD: LongInt;
 H4XIntraM,H4XInterM: Array[0..63] Of LongInt;
 H4XDivxVer,H4XDivxBuild,H4XXvidBuild,H4XLavcBuild,H4XBugs,H4XPadScore: LongInt;
  H4XDivxPacked: Boolean; H4XCTag: String[4];
 { image courante }
 H4XPType,H4XPart,H4XNoRnd,H4XIntraDcThr,H4XTff,H4XAltScan,H4XQscale,H4XFCode,H4XBCode:
  LongInt;
 H4XTime,H4XTimeBase,H4XLastTimeBase,H4XLastNonBTime,H4XPPTime,H4XPBTime,H4XTFrame,
  H4XPPField,H4XPBField: Int64;
 H4XPicNum: LongInt;
 H4XSpOff: Array[0..1,0..1] Of Int64; H4XSpDelta: Array[0..1,0..1] Of Int64;
  H4XSpShift: Array[0..1] Of LongInt; H4XRealWarp: LongInt;
 H4XDirScale: Array[0..1,0..63] Of LongInt;
 { macrobloc }
 H4XMbX,H4XMbY,H4XMbIntra,H4XAcPred,H4XIDct,H4XMvDir,H4XMvType,H4XMcSel,H4XSkip,
  H4XResyncX,H4XResyncY,H4XFirstLine,H4XMbLeft,
 H4XYDc,H4XCDc,H4XChromaQ: LongInt;
 H4XMv: Array[0..1,0..3,0..1] Of LongInt; H4XLastMv: Array[0..1,0..1,0..1] Of
  LongInt; H4XFieldSel: Array[0..1,0..1] Of LongInt;
 H4XBlk: Array[0..5] Of TH3Blk; H4XBlkLast: Array[0..5] Of LongInt;
 H4XResyncPos: LongInt;
 { images et tables de contexte }
 H4XP: Array[0..4] Of TM4Pic; H4XCurI,H4XLastI,H4XNextI: LongInt;
 H4XDc,H4XAc: Array[0..2] Of PH3I16; H4XDcN,H4XAcN: Array[0..2] Of LongInt;
 H4XIntraTab,H4XCbpTab,H4XDirTab: H4PBuf; H4XPField: PH3I16; H4XTabN: LongInt;
 H4XSkippedLast: Boolean; H4XPicHave: Boolean;
 H4XOutBuf: H4PBuf; H4XOutBegun,H4XOutCount: LongInt; H4XMode: LongInt; H4XTarget:
  String;
 H4XErr: Boolean;
 H4XMs: LongInt; H4XCodedBlk: H4PBuf; H4XYDcT,H4XCDcT: Array[0..31] Of Byte;

Function H4XSar(V,N: LongInt): LongInt;
Begin If V>=0 Then H4XSar:=V Shr N Else H4XSar:=-1-((-1-V) Shr N); End;
Function H4XSar64(V: Int64; N: LongInt): Int64;
Begin If V>=0 Then H4XSar64:=V Shr N Else H4XSar64:=-1-((-1-V) Shr N); End;

Procedure H4XBuildRl(Var R: TM4Rl; N,Last: LongInt; Const Vl: Array Of Word;
 Const Run,Lev: Array Of ShortInt);
Var K,Len,J,L,St,En,Rn,Lv,Code: LongInt;
Begin
 R.N:=N; R.Last:=Last; R.Vlc.Bits:=0;
 For K:=0 To N Do Begin Len:=Vl[K*2+1]; If Len>R.Vlc.Bits Then R.Vlc.Bits:=Len;
  End;
 For K:=0 To (LongInt(1) Shl R.Vlc.Bits)-1 Do Begin R.Vlc.Sym[K]:=-1; R.Vlc.Len[
  K]:=0; End;
 For K:=0 To N Do Begin
  Len:=Vl[K*2+1]; Code:=Vl[K*2];
  For J:=0 To (LongInt(1) Shl (R.Vlc.Bits-Len))-1 Do Begin
   R.Vlc.Sym[(Code Shl (R.Vlc.Bits-Len))+J]:=K; R.Vlc.Len[(Code Shl (R.Vlc.Bits-
    Len))+J]:=Len;
  End;
 End;
 FillChar(R.MaxLev,SizeOf(R.MaxLev),0); FillChar(R.MaxRun,SizeOf(R.MaxRun),0);
 For K:=0 To N-1 Do Begin R.Run[K]:=Run[K]; R.Lev[K]:=Lev[K]; End;
 For L:=0 To 1 Do Begin
  If L=0 Then Begin St:=0; En:=Last; End Else Begin St:=Last; En:=N; End;
  For K:=St To En-1 Do Begin
   Rn:=Run[K]; Lv:=Lev[K];
   If Lv>R.MaxLev[L,Rn] Then R.MaxLev[L,Rn]:=Lv;
   If Rn>R.MaxRun[L,Lv] Then R.MaxRun[L,Lv]:=Rn;
  End;
 End;
End;

Procedure H4XInitTables;
Var K,Len,J,Code: LongInt;
Procedure Dc(Var T: TH3Vlc; Const Tab: Array Of Byte);
Var Q,Ln,Cd,Sp: LongInt;
Begin
 T.Bits:=0;
 For Q:=0 To 9 Do If Tab[Q*2+1]>T.Bits Then T.Bits:=Tab[Q*2+1];
 For Q:=0 To (LongInt(1) Shl T.Bits)-1 Do Begin T.Sym[Q]:=-1; T.Len[Q]:=0; End;
 For Q:=0 To 9 Do Begin
  Ln:=Tab[Q*2+1]; Cd:=Tab[Q*2];
  For Sp:=0 To (LongInt(1) Shl (T.Bits-Ln))-1 Do Begin T.Sym[(Cd Shl (T.Bits-
   Ln))+Sp]:=Q; T.Len[(Cd Shl (T.Bits-Ln))+Sp]:=Ln; End;
 End;
End;
Begin
 If H4XInit Then Exit;
 H4XInit:=True;
 H4YInitTables;
 H4XBuildRl(H4XRlIntra,102,67,H4XIntraVlc,H4XIntraRun,H4XIntraLev);
 H4XBuildRl(H4XRlRvInter,169,103,H4XInterRvlc,H4XInterRvlcRun,H4XInterRvlcLev);
 H4XBuildRl(H4XRlRvIntra,169,103,H4XIntraRvlc,H4XIntraRvlcRun,H4XIntraRvlcLev);
 H4XBuildRl(H4XRlInter,102,58,H4YInterVlc,H4YInterRun,H4YInterLevel);
 Dc(H4XVDcL,H4XDcLum); Dc(H4XVDcC,H4XDcChr);
 H4XVSpr.Bits:=12;
 For K:=0 To 4095 Do Begin H4XVSpr.Sym[K]:=-1; H4XVSpr.Len[K]:=0; End;
 Code:=0;
 For Len:=1 To 12 Do Begin
  For K:=0 To 14 Do If H4XSprLen[K]=Len Then Begin
   For J:=0 To (LongInt(1) Shl (12-Len))-1 Do Begin H4XVSpr.Sym[(Code Shl (12-
    Len))+J]:=K; H4XVSpr.Len[(Code Shl (12-Len))+J]:=Len; End;
   Inc(Code);
  End;
  Code:=Code Shl 1;
 End;
End;

{ ---- petits utilitaires de lecture ---- }
Function H4XGetXbits(N: LongInt): LongInt;
Var V: LongInt;
Begin
 V:=H4YBits(N);
 If V<(LongInt(1) Shl (N-1)) Then V:=V-(LongInt(1) Shl N)+1;
 H4XGetXbits:=V;
End;

Function H4XMarker: LongInt;
Begin H4XMarker:=H4YBit; End;

Function H4XLog2(V: LongInt): LongInt;
Var R: LongInt;
Begin R:=0; While V>1 Do Begin V:=V Shr 1; Inc(R); End; H4XLog2:=R; End;

Procedure H4XSetQscale(Q: LongInt);
Begin
 If Q<1 Then Q:=1 Else If Q>31 Then Q:=31;
 H4XQscale:=Q; H4XChromaQ:=Q;
 H4XYDc:=H4XYDcT[Q]; H4XCDc:=H4XCDcT[Q];
End;

Function H4XDiv(A,B: LongInt): LongInt;   { division C : arrondi vers zero }
Begin H4XDiv:=A Div B; End;
Function H4XRDiv(A,B: LongInt): LongInt;  { ROUNDED_DIV }
Begin If A>=0 Then H4XRDiv:=(A+(B Shr 1)) Div B Else H4XRDiv:=(A-(B Shr 1)) Div B;
 End;
Function H4XRDiv64(A,B: Int64): Int64;
Begin If A>=0 Then H4XRDiv64:=(A+(B Shr 1)) Div B Else H4XRDiv64:=(A-(B Shr 1))
 Div B; End;

{ ---- en-tetes (mpeg4videodec.c) ---- }
Var H4XRange: LongInt;

Procedure H4XDefaultMatrices;
Var I: LongInt;
Begin
 For I:=0 To 63 Do Begin H4XIntraM[I]:=H4XDefIntra[I]; H4XInterM[I]:=H4XDefInter[I];
  End;
End;

Procedure H4XUserData;
Var Buf: String; I,Ver,Build,Ver2,Ver3,E: LongInt; Last: Char;
Function Num(Var P: LongInt; Var V: LongInt): Boolean;
Var Q: LongInt;
Begin
 Q:=P; V:=0;
 While (Q<=Length(Buf)) And (Buf[Q]>='0') And (Buf[Q]<='9') Do Begin If
  V<100000000 Then V:=V*10+Ord(Buf[Q])-48; Inc(Q); End;
 Num:=Q>P; P:=Q;
End;
Function StartsWith(Const S: String; Var P: LongInt): Boolean;
Var Ok: Boolean;
Begin
 Ok:=(Length(Buf)>=Length(S)) And (Copy(Buf,1,Length(S))=S);
 If Ok Then P:=Length(S)+1;
 StartsWith:=Ok;
End;
Var P: LongInt; Ok: Boolean; Hdr: Boolean;
Begin
 Buf:=''; I:=0;
 While (I<255) And (H4YPos<H4YSize*8) Do Begin
  If H4YShow(23)=0 Then Break;
  Buf:=Buf+Chr(H4YBits(8)); Inc(I);
 End;
 { detection DivX }
 Ver:=0; Build:=0; E:=0; Last:=#0; Hdr:=False;
 If StartsWith('DivX',P) Then Begin
  If Num(P,Ver) Then Begin
   If (P<=Length(Buf)) And (Copy(Buf,P,5)='Build') Then Begin
    Inc(P,5); If Num(P,Build) Then Begin E:=2; If P<=Length(Buf) Then Begin E:=
     3; Last:=Buf[P]; End; End;
   End Else If (P<=Length(Buf)) And (Buf[P]='b') Then Begin
    Inc(P); If Num(P,Build) Then Begin E:=2; If P<=Length(Buf) Then Begin E:=3;
     Last:=Buf[P]; End; End;
   End;
  End;
  If E>=2 Then Begin H4XDivxVer:=Ver; H4XDivxBuild:=Build; H4XDivxPacked:=(E=3) And
   (Last='p'); End;
 End;
 { detection libavcodec }
 E:=0; Ver:=0; Ver2:=0; Ver3:=0; Build:=0;
 If StartsWith('FFmpe',P) Then Begin
  { FFmpe%*[^b]b%d }
  While (P<=Length(Buf)) And (Buf[P]<>'b') Do Inc(P);
  If (P<=Length(Buf)) And (Buf[P]='b') Then Begin Inc(P); If Num(P,Build) Then
   E:=4; End;
 End;
 If (E<>4) And StartsWith('FFmpeg v',P) Then Begin
  If Num(P,Ver) And (P<=Length(Buf)) And (Buf[P]='.') Then Begin
   Inc(P);
   If Num(P,Ver2) And (P<=Length(Buf)) And (Buf[P]='.') Then Begin
    Inc(P);
    If Num(P,Ver3) Then Begin
     If Copy(Buf,P,Length(' / libavcodec build: '))=' / libavcodec build: ' Then
      Begin
      Inc(P,Length(' / libavcodec build: ')); If Num(P,Build) Then E:=4;
     End;
    End;
   End;
  End;
 End;
 If E<>4 Then Begin
  If StartsWith('Lavc',P) Then Begin
   If Num(P,Ver) Then Begin
    E:=2;
    If (P<=Length(Buf)) And (Buf[P]='.') Then Begin
     Inc(P);
     If Num(P,Ver2) Then Begin
      E:=3;
      If (P<=Length(Buf)) And (Buf[P]='.') Then Begin Inc(P); If Num(P,Ver3)
       Then E:=4; End;
     End;
    End;
    If E=4 Then Begin Build:=((Ver And $FF) Shl 16)+((Ver2 And $FF) Shl 8)+(Ver3
     And $FF); End
    Else E:=2;
   End;
  End;
  If (E<>4) And (Buf='ffmpeg') Then H4XLavcBuild:=4600;
 End;
 If E=4 Then H4XLavcBuild:=Build;
 { detection Xvid }
 If StartsWith('XviD',P) Then Begin
  If Num(P,Build) Then H4XXvidBuild:=Build;
 End;
End;

Procedure H4XGopHeader;
Var Hrs,Mn,Sec: LongInt;
Begin
 If H4YShow(23)=0 Then Exit;
 Hrs:=H4YBits(5); Mn:=H4YBits(6); H4XMarker; Sec:=H4YBits(6);
 H4XTimeBase:=Sec+60*(Mn+60*Hrs);
 H4YSkip(2);
End;

Procedure H4XVisualObject;
Var Id,Typ,Sig,Rng,Cd: LongInt;
Begin
 Id:=H4YBit;
 If Id<>0 Then H4YSkip(7);
 Typ:=H4YBits(4);
 If (Typ=1) Or (Typ=2) Then Begin
  Sig:=H4YBit;
  If Sig<>0 Then Begin
   H4YSkip(3); Rng:=H4YBit; Cd:=H4YBit;
   If Rng<>0 Then H4XRange:=2 Else H4XRange:=1;
   If Cd<>0 Then H4YSkip(24);
  End;
 End;
End;

Function H4XVolHeader: LongInt;
Var
 VerId,AspectInfo,ChromaFmt,I,V,Last,J,Pos0,Est,Wd,Ht: LongInt; GoNo: Boolean;
  Bak: LongInt;
 H1,H2,H4Yb,H4: LongInt; NoCplx: Boolean;
Begin
 H4XVolHeader:=-1;
 H4YSkip(1);
 H4XVoType:=H4YBits(8);
 If (H4XVoType=15) Or (H4XVoType=14) Then H4XUnsup(
  'mpeg4: profil Simple Studio non pris en charge.');
 If H4YBit<>0 Then Begin VerId:=H4YBits(4); H4YSkip(3); End Else VerId:=1;
 AspectInfo:=H4YBits(4);
 If AspectInfo=15 Then Begin H4XSarN:=H4YBits(8); H4XSarD:=H4YBits(8); End
 Else Begin H4XSarN:=H4XAspect[AspectInfo,0]; H4XSarD:=H4XAspect[AspectInfo,1]; End;
 H4XVolCtl:=H4YBit;
 If H4XVolCtl<>0 Then Begin
  ChromaFmt:=H4YBits(2);
  H4XLowDelay:=H4YBit;
  If H4YBit<>0 Then Begin
   H4YSkip(15); H4XMarker; H4YSkip(15); H4XMarker; H4YSkip(15); H4XMarker; H4YSkip(3);
    H4YSkip(11); H4XMarker; H4YSkip(15); H4XMarker;
  End;
 End Else Begin
  If H4XPicNum=0 Then Begin
   Case H4XVoType Of 1,17: H4XLowDelay:=1; Else H4XLowDelay:=0; End;
  End;
 End;
 H4XShape:=H4YBits(2);
 If H4XShape<>0 Then H4XUnsup(
  'mpeg4: seules les couches video rectangulaires sont prises en charge.');
 H4XMarker;
 H4XRes:=H4YBits(16);
 If H4XRes=0 Then Exit;
 H4XTIncBits:=H4XLog2(H4XRes-1)+1;
 If H4XTIncBits<1 Then H4XTIncBits:=1;
 H4XMarker;
 If H4YBit<>0 Then H4XFixedRate:=H4YBits(H4XTIncBits) Else H4XFixedRate:=1;
 H4XTFrame:=0;
 H4XMarker;
 Wd:=H4YBits(13); H4XMarker; Ht:=H4YBits(13); H4XMarker;
 If (Wd<>0) And (Ht<>0) And Not ((H4XW<>0) And (H4XCTag='MP4S')) Then Begin H4XW:=
  Wd; H4XH:=Ht; End;
 H4XProg:=H4YBit Xor 1;
 H4XIDct:=0;
 H4YBit;  { OBMC disable }
 If VerId=1 Then H4XSprUsage:=H4YBit Else H4XSprUsage:=H4YBits(2);
 If (H4XSprUsage=1) Or (H4XSprUsage=2) Then Begin
  If H4XSprUsage=1 Then Begin H4YSkip(13); H4XMarker; H4YSkip(13); H4XMarker; H4YSkip(
   13); H4XMarker; H4YSkip(13); H4XMarker; End;
  H4XNumWarp:=H4YBits(6);
  If H4XNumWarp>3 Then Begin H4XNumWarp:=0; Exit; End;
  H4XWarpAcc:=H4YBits(2);
  H4XBrightChg:=H4YBit;
  If H4XSprUsage=1 Then H4YBit;
 End;
 If H4YBit=1 Then Begin
  H4XQuantPrec:=H4YBits(4);
  H4YBits(4);
  If (H4XQuantPrec<3) Or (H4XQuantPrec>9) Then H4XQuantPrec:=5;
 End Else H4XQuantPrec:=5;
 H4XMpegQuant:=H4YBit;
 If H4XMpegQuant<>0 Then Begin
  H4XDefaultMatrices;
  If H4YBit<>0 Then Begin
   Last:=0; I:=0;
   While I<64 Do Begin
    If H4YLeft<8 Then Exit;
    V:=H4YBits(8);
    If V=0 Then Break;
    Last:=V; H4XIntraM[H4YZigzag[I]]:=Last; Inc(I);
   End;
   While I<64 Do Begin H4XIntraM[H4YZigzag[I]]:=Last; Inc(I); End;
  End;
  If H4YBit<>0 Then Begin
   Last:=0; I:=0;
   While I<64 Do Begin
    If H4YLeft<8 Then Exit;
    V:=H4YBits(8);
    If V=0 Then Break;
    Last:=V; H4XInterM[H4YZigzag[I]]:=V; Inc(I);
   End;
   While I<64 Do Begin H4XInterM[H4YZigzag[I]]:=Last; Inc(I); End;
  End;
 End;
 If VerId<>1 Then H4XQuarterS:=H4YBit Else H4XQuarterS:=0;
 If H4YLeft<4 Then Exit;
 NoCplx:=False;
 If H4YBit=0 Then Begin
  Pos0:=H4YPos;
  Est:=H4YBits(2);
  If Est<2 Then Begin
   If H4YBit=0 Then Begin
    Inc(H4XCplxI,8*H4YBit); Inc(H4XCplxI,8*H4YBit); Inc(H4XCplxI,8*H4YBit); Inc(
     H4XCplxI,8*H4YBit); Inc(H4XCplxI,8*H4YBit); Inc(H4XCplxI,8*H4YBit);
   End;
   If H4YBit=0 Then Begin
    Inc(H4XCplxI,8*H4YBit); Inc(H4XCplxP,8*H4YBit); Inc(H4XCplxP,8*H4YBit); Inc(
     H4XCplxI,8*H4YBit);
   End;
   If H4XMarker=0 Then Begin H4YPos:=Pos0; NoCplx:=True; End
   Else Begin
    If H4YBit=0 Then Begin
     Inc(H4XCplxI,8*H4YBit); Inc(H4XCplxI,8*H4YBit); Inc(H4XCplxI,8*H4YBit); Inc(
      H4XCplxI,4*H4YBit);
    End;
    If H4YBit=0 Then Begin
     Inc(H4XCplxP,8*H4YBit); Inc(H4XCplxP,8*H4YBit); Inc(H4XCplxB,8*H4YBit); Inc(
      H4XCplxP,8*H4YBit); Inc(H4XCplxP,8*H4YBit); Inc(H4XCplxP,8*H4YBit);
    End;
    If H4XMarker=0 Then Begin H4YPos:=Pos0; NoCplx:=True; End
    Else If Est=1 Then Begin Inc(H4XCplxI,8*H4YBit); Inc(H4XCplxP,8*H4YBit); End;
   End;
  End;
 End Else NoCplx:=True;
 If NoCplx Then Begin H4XCplxI:=0; H4XCplxP:=0; H4XCplxB:=0; End;
 H4XResyncMarker:=H4YBit Xor 1;
 H4XDataPart:=H4YBit;
 If H4XDataPart<>0 Then H4XRvlc:=H4YBit Else H4XRvlc:=0;
 If VerId<>1 Then Begin
  H4XNewPred:=H4YBit;
  If H4XNewPred<>0 Then Begin H4YSkip(2); H4YSkip(1); End;
  H4YBit;  { reduced_res_vop }
 End Else H4XNewPred:=0;
 H4XScal:=H4YBit;
 If H4XScal<>0 Then Begin
  Bak:=H4YPos;
  H4YSkip(1); H4YSkip(4); H4YSkip(1);
  H1:=H4YBits(5); H2:=H4YBits(5); H4Yb:=H4YBits(5); H4:=H4YBits(5);
  H4XEnhType:=H4YBit;
  If (H1=0) Or (H2=0) Or (H4Yb=0) Or (H4=0) Then Begin H4XScal:=0; H4YPos:=Bak;
   End;
 End;
 H4XVolHeader:=0;
 H4XHave:=True;
End;

Procedure H4XInitDirectMv;
Var I: LongInt;
Begin
 For I:=0 To 63 Do Begin
  H4XDirScale[0,I]:=SmallInt((I-32)*LongInt(H4XPBTime) Div LongInt(H4XPPTime));
  H4XDirScale[1,I]:=SmallInt((I-32)*(LongInt(H4XPBTime)-LongInt(H4XPPTime)) Div
   LongInt(H4XPPTime));
 End;
End;

Function H4XSpriteTrajectory: LongInt;
Var
 A,Rho,R,Alpha,Beta,W,H,MinAB,I,W2,H2,W3,H3,Len,X,Y,ShiftY,ShiftC,J: LongInt;
 SpriteRef: Array[0..3,0..1] Of Int64; VirtualRef: Array[0..1,0..1] Of Int64;
 SOff,SDel: Array[0..1,0..1] Of Int64; VopRef: Array[0..3,0..1] Of LongInt; D:
  Array[0..3,0..1] Of LongInt;
 Sd0,Sd1: Int64; Lim: Int64;
 Div500: Boolean;
Function Traj: LongInt;
Begin Traj:=H4YGetVlc(H4XVSpr); End;
Begin
 H4XSpriteTrajectory:=-1;
 A:=2 Shl H4XWarpAcc; Rho:=3-H4XWarpAcc; R:=16 Div A; Alpha:=1; Beta:=0; W:=H4XW;
  H:=H4XH;
 Div500:=(H4XDivxVer=500) And (H4XDivxBuild=413);
 If (W<=0) Or (H<=0) Then Exit;
 VopRef[0,0]:=0; VopRef[0,1]:=0; VopRef[1,0]:=W; VopRef[1,1]:=0; VopRef[2,0]:=0;
  VopRef[2,1]:=H; VopRef[3,0]:=W; VopRef[3,1]:=H;
 FillChar(D,SizeOf(D),0);
 For I:=0 To H4XNumWarp-1 Do Begin
  X:=0; Y:=0;
  Len:=Traj; If Len>0 Then X:=H4XGetXbits(Len);
  If Not Div500 Then H4XMarker;
  Len:=Traj; If Len>0 Then Y:=H4XGetXbits(Len);
  H4XMarker;
  D[I,0]:=X; D[I,1]:=Y;
 End;
 While (LongInt(1) Shl Alpha)<W Do Inc(Alpha);
 While (LongInt(1) Shl Beta)<H Do Inc(Beta);
 W2:=LongInt(1) Shl Alpha; H2:=LongInt(1) Shl Beta;
 If Div500 Then Begin
  SpriteRef[0,0]:=A*VopRef[0,0]+D[0,0]; SpriteRef[0,1]:=A*VopRef[0,1]+D[0,1];
  SpriteRef[1,0]:=A*VopRef[1,0]+D[0,0]+D[1,0]; SpriteRef[1,1]:=A*VopRef[1,1]+D[
   0,1]+D[1,1];
  SpriteRef[2,0]:=A*VopRef[2,0]+D[0,0]+D[2,0]; SpriteRef[2,1]:=A*VopRef[2,1]+D[
   0,1]+D[2,1];
 End Else Begin
  SpriteRef[0,0]:=(A Shr 1)*(2*VopRef[0,0]+D[0,0]); SpriteRef[0,1]:=(A Shr 1)*(
   2*VopRef[0,1]+D[0,1]);
  SpriteRef[1,0]:=(A Shr 1)*(2*VopRef[1,0]+D[0,0]+D[1,0]); SpriteRef[1,1]:=(A
   Shr 1)*(2*VopRef[1,1]+D[0,1]+D[1,1]);
  SpriteRef[2,0]:=(A Shr 1)*(2*VopRef[2,0]+D[0,0]+D[2,0]); SpriteRef[2,1]:=(A
   Shr 1)*(2*VopRef[2,1]+D[0,1]+D[2,1]);
 End;
 VirtualRef[0,0]:=16*(VopRef[0,0]+W2)+H4XRDiv64((W-W2)*(R*SpriteRef[0,0]-16*
  Int64(VopRef[0,0]))+W2*(R*SpriteRef[1,0]-16*Int64(VopRef[1,0])),W);
 VirtualRef[0,1]:=16*VopRef[0,1]+H4XRDiv64((W-W2)*(R*SpriteRef[0,1]-16*Int64(
  VopRef[0,1]))+W2*(R*SpriteRef[1,1]-16*Int64(VopRef[1,1])),W);
 VirtualRef[1,0]:=16*VopRef[0,0]+H4XRDiv64((H-H2)*(R*SpriteRef[0,0]-16*Int64(
  VopRef[0,0]))+H2*(R*SpriteRef[2,0]-16*Int64(VopRef[2,0])),H);
 VirtualRef[1,1]:=16*(VopRef[0,1]+H2)+H4XRDiv64((H-H2)*(R*SpriteRef[0,1]-16*
  Int64(VopRef[0,1]))+H2*(R*SpriteRef[2,1]-16*Int64(VopRef[2,1])),H);
 Case H4XNumWarp Of
  0: Begin
   SOff[0,0]:=0; SOff[0,1]:=0; SOff[1,0]:=0; SOff[1,1]:=0;
   SDel[0,0]:=A; SDel[0,1]:=0; SDel[1,0]:=0; SDel[1,1]:=A;
   H4XSpShift[0]:=0; H4XSpShift[1]:=0;
  End;
  1: Begin
   SOff[0,0]:=SpriteRef[0,0]-A*VopRef[0,0];
   SOff[0,1]:=SpriteRef[0,1]-A*VopRef[0,1];
   SOff[1,0]:=((SpriteRef[0,0] Shr 1) Or (SpriteRef[0,0] And 1))-A*(VopRef[0,0]
    Div 2);
   SOff[1,1]:=((SpriteRef[0,1] Shr 1) Or (SpriteRef[0,1] And 1))-A*(VopRef[0,1]
    Div 2);
   SDel[0,0]:=A; SDel[0,1]:=0; SDel[1,0]:=0; SDel[1,1]:=A;
   H4XSpShift[0]:=0; H4XSpShift[1]:=0;
  End;
  2: Begin
   SOff[0,0]:=SpriteRef[0,0]*(Int64(1) Shl (Alpha+Rho))+(-R*SpriteRef[0,0]+
    VirtualRef[0,0])*(-Int64(VopRef[0,0]))+
     (R*SpriteRef[0,1]-VirtualRef[0,1])*(-Int64(VopRef[0,1]))+(Int64(1) Shl (
      Alpha+Rho-1));
   SOff[0,1]:=SpriteRef[0,1]*(Int64(1) Shl (Alpha+Rho))+(-R*SpriteRef[0,1]+
    VirtualRef[0,1])*(-Int64(VopRef[0,0]))+
     (-R*SpriteRef[0,0]+VirtualRef[0,0])*(-Int64(VopRef[0,1]))+(Int64(1) Shl (
      Alpha+Rho-1));
   SOff[1,0]:=(-R*SpriteRef[0,0]+VirtualRef[0,0])*(-2*Int64(VopRef[0,0])+1)+(R*
    SpriteRef[0,1]-VirtualRef[0,1])*(-2*Int64(VopRef[0,1])+1)+
     2*W2*R*SpriteRef[0,0]-16*W2+(Int64(1) Shl (Alpha+Rho+1));
   SOff[1,1]:=(-R*SpriteRef[0,1]+VirtualRef[0,1])*(-2*Int64(VopRef[0,0])+1)+(-R*
    SpriteRef[0,0]+VirtualRef[0,0])*(-2*Int64(VopRef[0,1])+1)+
     2*W2*R*SpriteRef[0,1]-16*W2+(Int64(1) Shl (Alpha+Rho+1));
   SDel[0,0]:=(-R*SpriteRef[0,0]+VirtualRef[0,0]);
   SDel[0,1]:=(R*SpriteRef[0,1]-VirtualRef[0,1]);
   SDel[1,0]:=(-R*SpriteRef[0,1]+VirtualRef[0,1]);
   SDel[1,1]:=(-R*SpriteRef[0,0]+VirtualRef[0,0]);
   H4XSpShift[0]:=Alpha+Rho; H4XSpShift[1]:=Alpha+Rho+2;
  End;
  3: Begin
   If Alpha<Beta Then MinAB:=Alpha Else MinAB:=Beta;
   W3:=W2 Shr MinAB; H3:=H2 Shr MinAB;
   SOff[0,0]:=SpriteRef[0,0]*(Int64(1) Shl (Alpha+Beta+Rho-MinAB))+(-R*
    SpriteRef[0,0]+VirtualRef[0,0])*H3*(-Int64(VopRef[0,0]))+
     (-R*SpriteRef[0,0]+VirtualRef[1,0])*W3*(-Int64(VopRef[0,1]))+(Int64(1) Shl
      (Alpha+Beta+Rho-MinAB-1));
   SOff[0,1]:=SpriteRef[0,1]*(Int64(1) Shl (Alpha+Beta+Rho-MinAB))+(-R*
    SpriteRef[0,1]+VirtualRef[0,1])*H3*(-Int64(VopRef[0,0]))+
     (-R*SpriteRef[0,1]+VirtualRef[1,1])*W3*(-Int64(VopRef[0,1]))+(Int64(1) Shl
      (Alpha+Beta+Rho-MinAB-1));
   SOff[1,0]:=(-R*SpriteRef[0,0]+VirtualRef[0,0])*H3*(-2*Int64(VopRef[0,0])+1)+(
    -R*SpriteRef[0,0]+VirtualRef[1,0])*W3*(-2*Int64(VopRef[0,1])+1)+
     2*W2*H3*R*SpriteRef[0,0]-16*W2*H3+(Int64(1) Shl (Alpha+Beta+Rho-MinAB+1));
   SOff[1,1]:=(-R*SpriteRef[0,1]+VirtualRef[0,1])*H3*(-2*Int64(VopRef[0,0])+1)+(
    -R*SpriteRef[0,1]+VirtualRef[1,1])*W3*(-2*Int64(VopRef[0,1])+1)+
     2*W2*H3*R*SpriteRef[0,1]-16*W2*H3+(Int64(1) Shl (Alpha+Beta+Rho-MinAB+1));
   SDel[0,0]:=(-R*SpriteRef[0,0]+VirtualRef[0,0])*H3;
   SDel[0,1]:=(-R*SpriteRef[0,0]+VirtualRef[1,0])*W3;
   SDel[1,0]:=(-R*SpriteRef[0,1]+VirtualRef[0,1])*H3;
   SDel[1,1]:=(-R*SpriteRef[0,1]+VirtualRef[1,1])*W3;
   H4XSpShift[0]:=Alpha+Beta+Rho-MinAB; H4XSpShift[1]:=Alpha+Beta+Rho-MinAB+2;
  End;
 End;
 If (SDel[0,0]=Int64(A) Shl H4XSpShift[0]) And (SDel[0,1]=0) And (SDel[1,0]=0)
  And (SDel[1,1]=Int64(A) Shl H4XSpShift[0]) Then Begin
  SOff[0,0]:=H4XSar64(SOff[0,0],H4XSpShift[0]); SOff[0,1]:=H4XSar64(SOff[0,1],
   H4XSpShift[0]);
  SOff[1,0]:=H4XSar64(SOff[1,0],H4XSpShift[1]); SOff[1,1]:=H4XSar64(SOff[1,1],
   H4XSpShift[1]);
  SDel[0,0]:=A; SDel[0,1]:=0; SDel[1,0]:=0; SDel[1,1]:=A;
  H4XSpShift[0]:=0; H4XSpShift[1]:=0;
  H4XRealWarp:=1;
 End Else Begin
  ShiftY:=16-H4XSpShift[0]; ShiftC:=16-H4XSpShift[1];
  Lim:=2147483647;
  For I:=0 To 1 Do Begin
   If (ShiftC<0) Or (ShiftY<0) Or (Abs(SOff[0,I])>=(Lim Shr ShiftY)) Or (Abs(
    SOff[1,I])>=(Lim Shr ShiftC)) Or
    (Abs(SDel[0,I])>=(Lim Shr ShiftY)) Or (Abs(SDel[1,I])>=(Lim Shr ShiftY))
     Then Begin
    FillChar(H4XSpOff,SizeOf(H4XSpOff),0); FillChar(H4XSpDelta,SizeOf(H4XSpDelta),
     0); Exit;
   End;
  End;
  For I:=0 To 1 Do Begin
   SOff[0,I]:=SOff[0,I]*(Int64(1) Shl ShiftY); SOff[1,I]:=SOff[1,I]*(Int64(1)
    Shl ShiftC);
   SDel[0,I]:=SDel[0,I]*(Int64(1) Shl ShiftY); SDel[1,I]:=SDel[1,I]*(Int64(1)
    Shl ShiftY);
   H4XSpShift[I]:=16;
  End;
  For I:=0 To 1 Do Begin
   Sd0:=SDel[I,0]-Int64(A)*65536; Sd1:=SDel[I,1]-Int64(A)*65536;
   If (Abs(SOff[0,I]+SDel[I,0]*(W+16))>=Lim) Or (Abs(SOff[0,I]+SDel[I,1]*(H+
    16))>=Lim) Or
    (Abs(SOff[0,I]+SDel[I,0]*(W+16)+SDel[I,1]*(H+16))>=Lim) Or (Abs(SDel[I,0]*(
     W+16))>=Lim) Or (Abs(SDel[I,1]*(H+16))>=Lim) Or
    (Abs(Sd0)>=Lim) Or (Abs(Sd1)>=Lim) Or (Abs(SOff[0,I]+Sd0*(W+16))>=Lim) Or (
     Abs(SOff[0,I]+Sd1*(H+16))>=Lim) Or
    (Abs(SOff[0,I]+Sd0*(W+16)+Sd1*(H+16))>=Lim) Then Begin
    FillChar(H4XSpOff,SizeOf(H4XSpOff),0); FillChar(H4XSpDelta,SizeOf(H4XSpDelta),
     0); Exit;
   End;
  End;
  H4XRealWarp:=H4XNumWarp;
 End;
 For I:=0 To 3 Do Begin
  H4XSpOff[I And 1,I Shr 1]:=SOff[I And 1,I Shr 1];
  H4XSpDelta[I And 1,I Shr 1]:=SDel[I And 1,I Shr 1];
 End;
 H4XSpriteTrajectory:=0;
End;

Procedure H4XNewPredSkip;
Var Ln: LongInt;
Begin
 Ln:=H4XTIncBits+3; If Ln>15 Then Ln:=15;
 H4YBits(Ln);
 If H4YBit<>0 Then H4YBits(Ln);
 H4XMarker;
End;

Function H4XVopHeader: LongInt;
Var TimeIncr,TimeInc,I: LongInt;
Begin
 H4XVopHeader:=0;
 H4XMcSel:=0;
 H4XPType:=H4YBits(2);
 If (H4XPType=2) And (H4XLowDelay<>0) And (H4XVolCtl=0) Then H4XLowDelay:=0;
 If (H4XDataPart<>0) And (H4XPType<>2) Then H4XPart:=1 Else H4XPart:=0;
 TimeIncr:=0;
 While (H4YBit<>0) And (H4YPos<H4YSize*8) Do Inc(TimeIncr);
 H4XMarker;
 If (H4XTIncBits=0) Or ((H4YShow(H4XTIncBits+1) And 1)=0) Then Begin
  H4XTIncBits:=1;
  While H4XTIncBits<16 Do Begin
   If (H4XPType=1) Or ((H4XPType=3) And (H4XSprUsage=2)) Then Begin
    If (H4YShow(H4XTIncBits+6) And $37)=$30 Then Break;
   End Else If (H4YShow(H4XTIncBits+5) And $1F)=$18 Then Break;
   Inc(H4XTIncBits);
  End;
 End;
 TimeInc:=H4YBits(H4XTIncBits);
 If H4XPType<>2 Then Begin
  H4XLastTimeBase:=H4XTimeBase;
  H4XTimeBase:=H4XTimeBase+TimeIncr;
  H4XTime:=H4XTimeBase*H4XRes+TimeInc;
  If (H4XBugs And H4X_BUG_UMP4)<>0 Then Begin
   If H4XTime<H4XLastNonBTime Then Begin Inc(H4XTimeBase); Inc(H4XTime,H4XRes); End;
  End;
  H4XPPTime:=(H4XTime-H4XLastNonBTime) And $FFFF;
  H4XLastNonBTime:=H4XTime;
 End Else Begin
  H4XTime:=(H4XLastTimeBase+TimeIncr)*H4XRes+TimeInc;
  H4XPBTime:=(H4XPPTime-(H4XLastNonBTime-H4XTime)) And $FFFF;
  If (H4XPPTime<=H4XPBTime) Or (H4XPPTime<=H4XPPTime-H4XPBTime) Or (H4XPPTime<=0) Then
   Begin H4XVopHeader:=H4X_SKIPPED; Exit; End;
  H4XInitDirectMv;
  If H4XTFrame=0 Then H4XTFrame:=H4XPBTime;
  If H4XTFrame=0 Then H4XTFrame:=1;
  H4XPPField:=((H4XRDiv64(H4XLastNonBTime,H4XTFrame)-H4XRDiv64(H4XLastNonBTime-
   H4XPPTime,H4XTFrame))*2) And $FFFF;
  H4XPBField:=((H4XRDiv64(H4XTime,H4XTFrame)-H4XRDiv64(H4XLastNonBTime-H4XPPTime,
   H4XTFrame))*2) And $FFFF;
  If (H4XPPField<=H4XPBField) Or (H4XPBField<=1) Then Begin
   H4XPBField:=2; H4XPPField:=4;
   If H4XProg=0 Then Begin H4XVopHeader:=H4X_SKIPPED; Exit; End;
  End;
 End;
 H4XMarker;
 If H4YBit<>1 Then Begin H4XVopHeader:=H4X_SKIPPED; Exit; End;
 If H4XNewPred<>0 Then H4XNewPredSkip;
 If (H4XPType=1) Or ((H4XPType=3) And (H4XSprUsage=2)) Then H4XNoRnd:=H4YBit Else
  H4XNoRnd:=0;
 I:=H4XCplxI; If I>0 Then H4YSkip(I);
 If H4XPType<>0 Then Begin I:=H4XCplxP; If I>0 Then H4YSkip(I); End;
 If H4XPType=2 Then Begin I:=H4XCplxB; If I>0 Then H4YSkip(I); End;
 If H4YLeft<3 Then Begin H4XVopHeader:=-1; Exit; End;
 H4XIntraDcThr:=H4XDcThr[H4YBits(3)];
 If H4XProg=0 Then Begin H4XTff:=H4YBit; H4XAltScan:=H4YBit; End Else H4XAltScan:=0;
 If H4XPType=3 Then Begin
  If H4XSprUsage=2 Then Begin
   If H4XSpriteTrajectory<0 Then Begin H4XVopHeader:=-1; Exit; End;
  End Else If H4XSprUsage=1 Then H4XUnsup(
   'mpeg4: sprites statiques non pris en charge.')
  Else Begin FillChar(H4XSpOff,SizeOf(H4XSpOff),0); FillChar(H4XSpDelta,SizeOf(
   H4XSpDelta),0); End;
 End;
 H4XQscale:=H4YBits(H4XQuantPrec); H4XChromaQ:=H4XQscale;
 If H4XQscale=0 Then Begin H4XVopHeader:=-1; Exit; End;
 If H4XPType<>0 Then Begin
  H4XFCode:=H4YBits(3);
  If H4XFCode=0 Then Begin H4XFCode:=1; H4XVopHeader:=-1; Exit; End;
 End Else H4XFCode:=1;
 If H4XPType=2 Then Begin
  H4XBCode:=H4YBits(3);
  If H4XBCode=0 Then Begin H4XBCode:=1; H4XVopHeader:=-1; Exit; End;
 End Else H4XBCode:=1;
 If H4XScal<>0 Then Begin
  If H4XEnhType<>0 Then H4YBit;
  H4YSkip(2);
 End;
 If (H4XVoType=0) And (H4XVolCtl=0) And (H4XDivxVer=-1) And (H4XPicNum=0) Then
  H4XLowDelay:=1;
 Inc(H4XPicNum);
End;

{ ff_mpeg4_workaround_bugs : pas de variantes STD_QPEL (encodeurs anciens) }
Function H4XWorkaround: Boolean;
Begin
 H4XWorkaround:=False;
 If (H4XXvidBuild=-1) And (H4XDivxVer=-1) And (H4XLavcBuild=-1) Then Begin
  If (H4XCTag='XVID') Or (H4XCTag='XVIX') Or (H4XCTag='RMP4') Or (H4XCTag='ZMP4') Or
   (H4XCTag='SIPP') Then H4XXvidBuild:=0;
 End;
 If (H4XXvidBuild=-1) And (H4XDivxVer=-1) And (H4XLavcBuild=-1) Then
  If (H4XCTag='DIVX') And (H4XVoType=0) And (H4XVolCtl=0) Then H4XDivxVer:=400;
 If (H4XXvidBuild>=0) And (H4XDivxVer>=0) Then Begin H4XDivxVer:=-1; H4XDivxBuild:=-
  1; End;
 If (H4XCTag='XVIX') Then H4XBugs:=H4XBugs Or H4X_BUG_XVIDILACE;
 If (H4XCTag='UMP4') Then H4XBugs:=H4XBugs Or H4X_BUG_UMP4;
 If (H4XDivxVer>=500) And (H4XDivxBuild<1814) Then H4XBugs:=H4XBugs Or
  H4X_BUG_QPELCH;
 If (H4XDivxVer>502) And (H4XDivxBuild<1814) Then H4XBugs:=H4XBugs Or
  H4X_BUG_QPELCH2;
 If (H4XXvidBuild>=0) And (H4XXvidBuild<=3) Then H4XPadScore:=256*256*256*64;
 If (H4XXvidBuild>=0) And (H4XXvidBuild<=1) Then H4XBugs:=H4XBugs Or H4X_BUG_QPELCH;
 If (H4XXvidBuild>=0) And (H4XXvidBuild<=12) Then H4XBugs:=H4XBugs Or H4X_BUG_EDGE;
 If (H4XXvidBuild>=0) And (H4XXvidBuild<=32) Then H4XBugs:=H4XBugs Or H4X_BUG_DCCLIP;
 { les comparaisons C sont non signees : -1 devient grand }
 If (H4XLavcBuild>=0) And (H4XLavcBuild<4653) Then H4XBugs:=H4XBugs Or
  H4X_BUG_STDQPEL;
 If (H4XLavcBuild>=0) And (H4XLavcBuild<4655) Then H4XBugs:=H4XBugs Or
  H4X_BUG_DIRBLK;
 If (H4XLavcBuild>=0) And (H4XLavcBuild<4670) Then H4XBugs:=H4XBugs Or H4X_BUG_EDGE;
 If (H4XLavcBuild>=0) And (H4XLavcBuild<=4712) Then H4XBugs:=H4XBugs Or
  H4X_BUG_DCCLIP;
 If H4XDivxVer>=0 Then H4XBugs:=H4XBugs Or H4X_BUG_DIRBLK;
 If (H4XDivxVer=501) And (H4XDivxBuild=20020416) Then H4XPadScore:=256*256*256*64;
 If (H4XDivxVer>=0) And (H4XDivxVer<500) Then H4XBugs:=H4XBugs Or H4X_BUG_EDGE;
 If H4XDivxVer>=0 Then H4XBugs:=H4XBugs Or H4X_BUG_HPELCH;
 If (H4XBugs And H4X_BUG_STDQPEL)<>0 Then H4XUnsup(
  'mpeg4: flux d''un ancien encodeur libavcodec (qpel non standard) non pris e'+
  'n charge.');
End;

{ ---- tables de contexte, DC/AC (mpeg4video.h, mpeg4videodec.c) ---- }
Function H4XOff: LongInt;
Begin H4XOff:=H4XMbS+1; End;

Function H4XAcIx(N: LongInt): LongInt;   { indice (blocs de 16 valeurs) dans
 H4XDc/H4XAc }
Begin
 If N<4 Then H4XAcIx:=H4XB8S*(2*H4XMbY+(N Shr 1))+2*H4XMbX+(N And 1)+H4XB8S+1
 Else H4XAcIx:=H4XMbS*H4XMbY+H4XMbX+H4XMbS+1;
End;

Function H4XPredDc(N,Level: LongInt; Var Dir: LongInt): LongInt;
Var A,B,C,Wrap,Pred,Scale,Ret,Ix,Pl: LongInt; D: PH3I16;
Begin
 If N<4 Then Scale:=H4XYDc Else Scale:=H4XCDc;
 If N<4 Then Begin Pl:=0; Wrap:=H4XB8S; End Else Begin Pl:=N-3; Wrap:=H4XMbS; End;
 Ix:=H4XAcIx(N);
 D:=H4XDc[Pl];
 A:=D^[Ix-1]; B:=D^[Ix-1-Wrap]; C:=D^[Ix-Wrap];
 If (H4XFirstLine<>0) And (N<>3) Then Begin
  If N<>2 Then Begin B:=1024; C:=1024; End;
  If (N<>1) And (H4XMbX=H4XResyncX) Then Begin B:=1024; A:=1024; End;
 End;
 If (H4XMbX=H4XResyncX) And (H4XMbY=H4XResyncY+1) Then Begin
  If (N=0) Or (N=4) Or (N=5) Then B:=1024;
 End;
 If Abs(A-B)<Abs(B-C) Then Begin Pred:=C; Dir:=1; End Else Begin Pred:=A; Dir:=
  0; End;
 Pred:=(Pred+(Scale Shr 1)) Div Scale;
 Level:=Level+Pred; Ret:=Level;
 Level:=Level*Scale;
 If (Level And Not 2047)<>0 Then Begin
  If Level<0 Then Level:=0
  Else If (H4XBugs And H4X_BUG_DCCLIP)=0 Then Level:=2047;
 End;
 D^[Ix]:=SmallInt(Level);
 H4XPredDc:=Ret;
End;

Procedure H4XPredAc(N,Dir: LongInt);
Var Pl,Ix,Wrap,Xy,I,Base,Qo: LongInt; A: PH3I16; Qs: H4PBuf;
Begin
 If N<4 Then Pl:=0 Else Pl:=N-3;
 If N<4 Then Wrap:=H4XB8S Else Wrap:=H4XMbS;
 Ix:=H4XAcIx(N);
 A:=H4XAc[Pl];
 Qs:=H4XP[H4XCurI].Qs;
 If H4XAcPred<>0 Then Begin
  If Dir=0 Then Begin
   Xy:=H4XMbX-1+H4XMbY*H4XMbS+H4XOff;
   Base:=(Ix-1)*16;
   If (H4XMbX=0) Or (H4XQscale=Qs^[Xy]) Or (N=1) Or (N=3) Then Begin
    For I:=1 To 7 Do H4XBlk[N][I*8]:=SmallInt(H4XBlk[N][I*8]+A^[Base+I]);
   End Else Begin
    For I:=1 To 7 Do H4XBlk[N][I*8]:=SmallInt(H4XBlk[N][I*8]+H4XRDiv(A^[Base+I]*
     Qs^[Xy],H4XQscale));
   End;
  End Else Begin
   Xy:=H4XMbX+H4XMbY*H4XMbS-H4XMbS+H4XOff;
   Base:=(Ix-Wrap)*16;
   If (H4XMbY=0) Or (H4XQscale=Qs^[Xy]) Or (N=2) Or (N=3) Then Begin
    For I:=1 To 7 Do H4XBlk[N][I]:=SmallInt(H4XBlk[N][I]+A^[Base+I+8]);
   End Else Begin
    For I:=1 To 7 Do H4XBlk[N][I]:=SmallInt(H4XBlk[N][I]+H4XRDiv(A^[Base+I+8]*Qs^[
     Xy],H4XQscale));
   End;
  End;
 End;
 Base:=Ix*16;
 For I:=1 To 7 Do A^[Base+I]:=H4XBlk[N][I*8];
 For I:=1 To 7 Do A^[Base+8+I]:=H4XBlk[N][I];
End;

Procedure H4XCleanIntraEntries;   { ff_clean_intra_table_entries }
Var Ix,I,Cx: LongInt;
Begin
 Ix:=H4XAcIx(0);
 H4XDc[0]^[Ix]:=1024; H4XDc[0]^[Ix+1]:=1024; H4XDc[0]^[Ix+H4XB8S]:=1024; H4XDc[0]^[
  Ix+1+H4XB8S]:=1024;
 FillChar(H4XAc[0]^[Ix*16],64,0);
 FillChar(H4XAc[0]^[(Ix+H4XB8S)*16],64,0);
 Cx:=H4XAcIx(4);
 H4XDc[1]^[Cx]:=1024; H4XDc[2]^[Cx]:=1024;
 FillChar(H4XAc[1]^[Cx*16],32,0); FillChar(H4XAc[2]^[Cx*16],32,0);
 H4XIntraTab^[H4XMbX+H4XMbY*H4XMbS+H4XOff]:=0;
 If (H4XMs>=3) And (H4XCodedBlk<>Nil) Then Begin
  H4XCodedBlk^[Ix]:=0; H4XCodedBlk^[Ix+1]:=0; H4XCodedBlk^[Ix+H4XB8S]:=0;
   H4XCodedBlk^[Ix+1+H4XB8S]:=0;
 End;
End;

Procedure H4XCleanBuffers;   { ff_mpeg4_clean_buffers }
Var LXy,CXy: LongInt;
Begin
 LXy:=(2*H4XMbY-1)*H4XB8S+H4XMbX*2-1+H4XB8S+1;
 CXy:=(H4XMbY-1)*H4XMbS+H4XMbX-1+H4XMbS+1;
 FillChar(H4XAc[0]^[LXy*16],(H4XB8S*2+1)*32,0);
 FillChar(H4XAc[1]^[CXy*16],(H4XMbS+1)*32,0);
 FillChar(H4XAc[2]^[CXy*16],(H4XMbS+1)*32,0);
 H4XLastMv[0,0,0]:=0; H4XLastMv[0,0,1]:=0; H4XLastMv[1,0,0]:=0; H4XLastMv[1,0,1]:=0;
End;

Function H4XDecodeDc(N: LongInt; Var Dir: LongInt): LongInt;
Var Code,Level: LongInt;
Begin
 If N<4 Then Code:=H4YGetVlc(H4XVDcL) Else Code:=H4YGetVlc(H4XVDcC);
 If (Code<0) Or (Code>9) Then Begin H4XDecodeDc:=-1; Exit; End;
 If Code=0 Then Level:=0
 Else Begin
  Level:=H4XGetXbits(Code);
  If Code>8 Then H4YBit;
 End;
 H4XDecodeDc:=H4XPredDc(N,Level,Dir);
End;

{ ---- blocs ---- }
Function H4XBlock(N,Coded,Intra,UseDcVlc,Rvlc: LongInt): LongInt;
Var
 Level,I,Last,Run,Qmul,Qadd,Dir,Sym,Lev0,LastF,Sg,B1,B2: LongInt; Rl: PM4Rl;
  Scan: H4PBuf; Blk: ^TH3Blk;
Label NotCoded;
Begin
 H4XBlock:=-1;
 Blk:=@H4XBlk[N];
 Dir:=0; Qmul:=1; Qadd:=0; Rl:=@H4XRlIntra; Scan:=@H4YZigzag;
 If Intra<>0 Then Begin
  If UseDcVlc<>0 Then Begin
   If H4XPart<>0 Then Begin
    If N<4 Then Level:=H4XDc[0]^[H4XAcIx(N)] Else Level:=H4XDc[N-3]^[H4XAcIx(N)];
    If N<4 Then Level:=(Level+(H4XYDc Shr 1)) Div H4XYDc Else Level:=(Level+(H4XCDc
     Shr 1)) Div H4XCDc;
    Dir:=(H4XDirTab^[H4XMbX+H4XMbY*H4XMbS+H4XOff] Shl N) And 32;
   End Else Begin
    Level:=H4XDecodeDc(N,Dir);
    If Level<0 Then Exit;
   End;
   Blk^[0]:=SmallInt(Level);
   I:=0;
  End Else Begin
   I:=-1;
   H4XPredDc(N,0,Dir);
  End;
  If Coded=0 Then Goto NotCoded;
  If Rvlc<>0 Then Rl:=@H4XRlRvIntra Else Rl:=@H4XRlIntra;
  If H4XAcPred<>0 Then Begin
   If Dir=0 Then Begin If H4XAltScan<>0 Then Scan:=@H4YAltV Else Scan:=@H4YAltV;
    End   { gauche }
   Else Begin If H4XAltScan<>0 Then Scan:=@H4YAltV Else Scan:=@H4YAltH; End;
    { haut }
  End Else Begin
   If H4XAltScan<>0 Then Scan:=@H4YAltV Else Scan:=@H4YZigzag;
  End;
 End Else Begin
  I:=-1;
  If Coded=0 Then Begin H4XBlkLast[N]:=I; H4XBlock:=0; Exit; End;
  If Rvlc<>0 Then Rl:=@H4XRlRvInter Else Rl:=@H4XRlInter;
  If H4XAltScan<>0 Then Scan:=@H4YAltV Else Scan:=@H4YZigzag;
  If H4XMpegQuant=0 Then Begin Qmul:=H4XQscale Shl 1; Qadd:=(H4XQscale-1) Or 1;
   End;
 End;
 Repeat
  Sym:=H4YGetVlc(Rl^.Vlc);
  If Sym<0 Then Exit;
  If Sym=Rl^.N Then Begin
   If Rvlc<>0 Then Begin
    If H4YBit=0 Then Exit;
    Last:=H4YBit; Run:=H4YBits(6);
    If H4YBit=0 Then Exit;
    Level:=H4YBits(11);
    If H4YBits(5)<>$10 Then Exit;
    Level:=Level*Qmul+Qadd;
    If H4YBit<>0 Then Level:=-Level;
    Inc(I,Run+1);
    If Last<>0 Then Inc(I,192);
   End Else Begin
    B1:=H4YBit;
    If B1<>0 Then Begin
     B2:=H4YBit;
     If B2<>0 Then Begin
      { troisieme echappement }
      Last:=H4YBit; Run:=H4YBits(6);
      If H4YBit=0 Then Exit;
      Level:=H4YSBits(12); H4YSkip(12);
      If H4YBit=0 Then Exit;
      If Level>0 Then Level:=Level*Qmul+Qadd Else Level:=Level*Qmul-Qadd;
      If (Level+2048>4095) Or (Level+2048<0) Then Begin If Level<0 Then Level:=-
       2048 Else Level:=2047; End;
      Inc(I,Run+1);
      If Last<>0 Then Inc(I,192);
     End Else Begin
      { deuxieme echappement }
      Sym:=H4YGetVlc(Rl^.Vlc);
      If (Sym<0) Or (Sym=Rl^.N) Then Exit;
      Lev0:=Rl^.Lev[Sym]; LastF:=Ord(Sym>=Rl^.Last);
      Run:=Rl^.Run[Sym];
      Inc(I,Run+1+Rl^.MaxRun[LastF,Lev0]+1);
      If LastF<>0 Then Inc(I,192);
      Level:=Lev0*Qmul+Qadd;
      If H4YBit<>0 Then Level:=-Level;
     End;
    End Else Begin
     { premier echappement }
     Sym:=H4YGetVlc(Rl^.Vlc);
     If (Sym<0) Or (Sym=Rl^.N) Then Exit;
     Lev0:=Rl^.Lev[Sym]; LastF:=Ord(Sym>=Rl^.Last);
     Run:=Rl^.Run[Sym];
     Inc(I,Run+1);
     If LastF<>0 Then Inc(I,192);
     Level:=(Lev0+Rl^.MaxLev[LastF,Run])*Qmul+Qadd;
     If H4YBit<>0 Then Level:=-Level;
    End;
   End;
  End Else Begin
   Lev0:=Rl^.Lev[Sym]; LastF:=Ord(Sym>=Rl^.Last);
   Inc(I,Rl^.Run[Sym]+1);
   If LastF<>0 Then Inc(I,192);
   Level:=Lev0*Qmul+Qadd;
   If H4YBit<>0 Then Level:=-Level;
  End;
  If I>62 Then Begin
   Dec(I,192);
   If (I And Not 63)<>0 Then Exit;
   Blk^[Scan^[I]]:=SmallInt(Level);
   Break;
  End;
  Blk^[Scan^[I]]:=SmallInt(Level);
 Until False;
NotCoded:
 If Intra<>0 Then Begin
  If UseDcVlc=0 Then Begin
   Blk^[0]:=SmallInt(H4XPredDc(N,Blk^[0],Dir));
   If I=-1 Then I:=0;
  End;
  H4XPredAc(N,Dir);
  If H4XAcPred<>0 Then I:=63;
 End;
 H4XBlkLast[N]:=I;
 H4XBlock:=0;
End;

{ ---- vecteurs de mouvement ---- }
Function H4XMvOff: LongInt;
Begin H4XMvOff:=H4XB8S+8; End;

Function H4XMvGet(Pic,M,C: LongInt): LongInt;
Begin H4XMvGet:=H4XP[Pic].Mv^[(M+H4XB8S+8)*2+C]; End;
Procedure H4XMvSet(Pic,M,C,V: LongInt);
Begin H4XP[Pic].Mv^[(M+H4XB8S+8)*2+C]:=SmallInt(V); End;

Function H4XPredMotion(Block: LongInt; Var Px,Py: LongInt): LongInt;
Var Wrap,M,A0,A1,B0,B1,C0,C1,Off: LongInt;
Begin
 Wrap:=H4XB8S;
 M:=H4XB8S*2*H4XMbY+2*H4XMbX+(Block And 1)+(Block Shr 1)*H4XB8S;
 Case Block Of 0: Off:=2; 1,2: Off:=1; Else Off:=-1; End;
 A0:=H4XMvGet(H4XCurI,M-1,0); A1:=H4XMvGet(H4XCurI,M-1,1);
 If (H4XFirstLine<>0) And (Block<3) Then Begin
  If Block=0 Then Begin
   If H4XMbX=H4XResyncX Then Begin Px:=0; Py:=0; End
   Else If H4XMbX+1=H4XResyncX Then Begin
    C0:=H4XMvGet(H4XCurI,M+Off-Wrap,0); C1:=H4XMvGet(H4XCurI,M+Off-Wrap,1);
    If H4XMbX=0 Then Begin Px:=C0; Py:=C1; End Else Begin Px:=H4YMid(A0,0,C0);
     Py:=H4YMid(A1,0,C1); End;
   End Else Begin Px:=A0; Py:=A1; End;
  End Else If Block=1 Then Begin
   If H4XMbX+1=H4XResyncX Then Begin
    C0:=H4XMvGet(H4XCurI,M+Off-Wrap,0); C1:=H4XMvGet(H4XCurI,M+Off-Wrap,1);
    Px:=H4YMid(A0,0,C0); Py:=H4YMid(A1,0,C1);
   End Else Begin Px:=A0; Py:=A1; End;
  End Else Begin
   B0:=H4XMvGet(H4XCurI,M-Wrap,0); B1:=H4XMvGet(H4XCurI,M-Wrap,1);
   C0:=H4XMvGet(H4XCurI,M+Off-Wrap,0); C1:=H4XMvGet(H4XCurI,M+Off-Wrap,1);
   If H4XMbX=H4XResyncX Then Begin A0:=0; A1:=0; H4XMvSet(H4XCurI,M-1,0,0); H4XMvSet(
    H4XCurI,M-1,1,0); End;
   Px:=H4YMid(A0,B0,C0); Py:=H4YMid(A1,B1,C1);
  End;
 End Else Begin
  B0:=H4XMvGet(H4XCurI,M-Wrap,0); B1:=H4XMvGet(H4XCurI,M-Wrap,1);
  C0:=H4XMvGet(H4XCurI,M+Off-Wrap,0); C1:=H4XMvGet(H4XCurI,M+Off-Wrap,1);
  Px:=H4YMid(A0,B0,C0); Py:=H4YMid(A1,B1,C1);
 End;
 H4XPredMotion:=M;
End;

Procedure H4XFillMv4(Mx,My: LongInt);   { quatre blocs du macrobloc courant }
Var M: LongInt;
Begin
 M:=H4XB8S*2*H4XMbY+2*H4XMbX;
 H4XMvSet(H4XCurI,M,0,Mx); H4XMvSet(H4XCurI,M,1,My);
 H4XMvSet(H4XCurI,M+1,0,Mx); H4XMvSet(H4XCurI,M+1,1,My);
 H4XMvSet(H4XCurI,M+H4XB8S,0,Mx); H4XMvSet(H4XCurI,M+H4XB8S,1,My);
 H4XMvSet(H4XCurI,M+1+H4XB8S,0,Mx); H4XMvSet(H4XCurI,M+1+H4XB8S,1,My);
End;

Function H4XRshift(A,B: LongInt): LongInt;
Begin
 If A>0 Then H4XRshift:=H4XSar(A+((LongInt(1) Shl B) Shr 1),B)
 Else H4XRshift:=H4XSar(A+((LongInt(1) Shl B) Shr 1)-1,B);
End;

Function H4XGetAmv(N: LongInt): LongInt;
Var X,Y,MbV,Sum,Dx,Dy,Shift,Len,A,V: LongInt;
Begin
 Len:=LongInt(1) Shl (H4XFCode+4);
 A:=H4XWarpAcc;
 If (H4XBugs And H4X_BUG_AMV)<>0 Then Len:=Len Shr H4XQuarterS;
 If H4XRealWarp=1 Then Begin
  If (H4XDivxVer=500) And (H4XDivxBuild=413) And (A>=H4XQuarterS) Then Sum:=
   LongInt(H4XSpOff[0,N]) Div (LongInt(1) Shl (A-H4XQuarterS))
  Else Sum:=H4XRshift(LongInt(H4XSpOff[0,N])*(LongInt(1) Shl H4XQuarterS),A);
 End Else Begin
  Dx:=LongInt(H4XSpDelta[N,0]); Dy:=LongInt(H4XSpDelta[N,1]); Shift:=H4XSpShift[0];
  If N<>0 Then Dy:=Dy-(LongInt(1) Shl (Shift+A+1)) Else Dx:=Dx-(LongInt(1) Shl (
   Shift+A+1));
  MbV:=LongInt(H4XSpOff[0,N])+Dx*H4XMbX*16+Dy*H4XMbY*16;
  Sum:=0;
  For Y:=0 To 15 Do Begin
   V:=MbV+Dy*Y;
   For X:=0 To 15 Do Begin Sum:=Sum+H4XSar(V,Shift); V:=V+Dx; End;
  End;
  Sum:=H4XRshift(Sum,A+8-H4XQuarterS);
 End;
 If Sum<-Len Then Sum:=-Len Else If Sum>=Len Then Sum:=Len-1;
 H4XGetAmv:=Sum;
End;

Procedure H4XUpdateMotion;
Var MbXy,Mx,My,I: LongInt;
Begin
 MbXy:=H4XMbY*H4XMbS+H4XMbX+H4XOff;
 H4XP[H4XCurI].Sk^[MbXy]:=H4XSkip;
 If H4XMvType<>1 Then Begin
  If H4XMbIntra<>0 Then Begin Mx:=0; My:=0; End
  Else If H4XMvType=0 Then Begin Mx:=H4XMv[0,0,0]; My:=H4XMv[0,0,1]; End
  Else Begin
   Mx:=H4XMv[0,0,0]+H4XMv[0,1,0]; My:=H4XMv[0,0,1]+H4XMv[0,1,1];
   Mx:=H4XSar(Mx,1) Or (Mx And 1);
   For I:=0 To 1 Do Begin
    H4XPField^[(I*H4XTabN+MbXy)*2]:=SmallInt(H4XMv[0,I,0]); H4XPField^[(I*H4XTabN+
     MbXy)*2+1]:=SmallInt(H4XMv[0,I,1]);
   End;
   H4XP[H4XCurI].Ref^[4*MbXy]:=H4XFieldSel[0,0]; H4XP[H4XCurI].Ref^[4*MbXy+1]:=
    H4XFieldSel[0,0];
   H4XP[H4XCurI].Ref^[4*MbXy+2]:=H4XFieldSel[0,1]; H4XP[H4XCurI].Ref^[4*MbXy+3]:=
    H4XFieldSel[0,1];
  End;
  H4XFillMv4(Mx,My);
 End;
End;

{ ---- mode direct (mpeg4video.c) ---- }
Procedure H4XSetOneDirectMv(Mx,My,I: LongInt);
Var M,PMx,PMy,TimePP,TimePB,V0: LongInt;
Begin
 M:=H4XB8S*(2*H4XMbY+(I Shr 1))+2*H4XMbX+(I And 1);
 TimePP:=H4XPPTime And $FFFF; TimePB:=H4XPBTime And $FFFF;
 PMx:=H4XMvGet(H4XNextI,M,0);
 If (PMx+32>=0) And (PMx+32<64) Then Begin
  H4XMv[0,I,0]:=H4XDirScale[0,PMx+32]+Mx;
  If Mx<>0 Then H4XMv[1,I,0]:=H4XMv[0,I,0]-PMx Else H4XMv[1,I,0]:=H4XDirScale[1,PMx+
   32];
 End Else Begin
  H4XMv[0,I,0]:=PMx*TimePB Div TimePP+Mx;
  If Mx<>0 Then H4XMv[1,I,0]:=H4XMv[0,I,0]-PMx Else H4XMv[1,I,0]:=PMx*(TimePB-
   TimePP) Div TimePP;
 End;
 PMy:=H4XMvGet(H4XNextI,M,1);
 If (PMy+32>=0) And (PMy+32<64) Then Begin
  H4XMv[0,I,1]:=H4XDirScale[0,PMy+32]+My;
  If My<>0 Then H4XMv[1,I,1]:=H4XMv[0,I,1]-PMy Else H4XMv[1,I,1]:=H4XDirScale[1,PMy+
   32];
 End Else Begin
  H4XMv[0,I,1]:=PMy*TimePB Div TimePP+My;
  If My<>0 Then H4XMv[1,I,1]:=H4XMv[0,I,1]-PMy Else H4XMv[1,I,1]:=PMy*(TimePB-
   TimePP) Div TimePP;
 End;
End;

Function H4XSetDirectMv(Mx,My: LongInt): LongInt;
Var MbIndex,Col,I,FS,TimePP,TimePB,Xy: LongInt;
Begin
 MbIndex:=H4XMbX+H4XMbY*H4XMbS;
 Col:=H4XP[H4XNextI].Mt^[MbIndex+H4XOff];
 If (Col And H4X_8X8)<>0 Then Begin
  H4XMvType:=1;
  For I:=0 To 3 Do H4XSetOneDirectMv(Mx,My,I);
  H4XSetDirectMv:=H4X_DIRECT Or H4X_8X8 Or H4X_L0 Or H4X_L1;
 End Else If (Col And H4X_INTERLACED)<>0 Then Begin
  H4XMvType:=2;
  Xy:=MbIndex+H4XOff;
  For I:=0 To 1 Do Begin
   FS:=H4XP[H4XNextI].Ref^[4*Xy+2*I];
   H4XFieldSel[0,I]:=FS; H4XFieldSel[1,I]:=I;
   If H4XTff<>0 Then Begin TimePP:=(H4XPPField-FS+I) And $FFFF; TimePB:=(
    H4XPBField-FS+I) And $FFFF; End
   Else Begin TimePP:=(H4XPPField+FS-I) And $FFFF; TimePB:=(H4XPBField+FS-I) And
    $FFFF; End;
   H4XMv[0,I,0]:=H4XPField^[(I*H4XTabN+Xy)*2]*TimePB Div TimePP+Mx;
   H4XMv[0,I,1]:=H4XPField^[(I*H4XTabN+Xy)*2+1]*TimePB Div TimePP+My;
   If Mx<>0 Then H4XMv[1,I,0]:=H4XMv[0,I,0]-H4XPField^[(I*H4XTabN+Xy)*2]
   Else H4XMv[1,I,0]:=H4XPField^[(I*H4XTabN+Xy)*2]*(TimePB-TimePP) Div TimePP;
   If My<>0 Then H4XMv[1,I,1]:=H4XMv[0,I,1]-H4XPField^[(I*H4XTabN+Xy)*2+1]
   Else H4XMv[1,I,1]:=H4XPField^[(I*H4XTabN+Xy)*2+1]*(TimePB-TimePP) Div TimePP;
  End;
  H4XSetDirectMv:=H4X_DIRECT Or H4X_16X8 Or H4X_L0 Or H4X_L1 Or H4X_INTERLACED;
 End Else Begin
  H4XSetOneDirectMv(Mx,My,0);
  For I:=1 To 3 Do Begin
   H4XMv[0,I,0]:=H4XMv[0,0,0]; H4XMv[0,I,1]:=H4XMv[0,0,1];
   H4XMv[1,I,0]:=H4XMv[1,0,0]; H4XMv[1,I,1]:=H4XMv[1,0,1];
  End;
  If ((H4XBugs And H4X_BUG_DIRBLK)<>0) Or (H4XQuarterS=0) Then H4XMvType:=0 Else
   H4XMvType:=1;
  H4XSetDirectMv:=H4X_DIRECT Or H4X_16X16 Or H4X_L0 Or H4X_L1;
 End;
End;

{ ---- fin de tranche / paquets video ---- }
Function H4XPrefixLength: LongInt;
Var M: LongInt;
Begin
 Case H4XPType Of
  0: H4XPrefixLength:=16;
  1,3: H4XPrefixLength:=H4XFCode+15;
  2: Begin M:=H4XFCode; If H4XBCode>M Then M:=H4XBCode; If M<2 Then M:=2;
   H4XPrefixLength:=M+15; End;
  Else H4XPrefixLength:=-1;
 End;
End;

Function H4XIsResync: LongInt;
Var BitsCount,V,Len,MbNumBits,MbNum,Save: LongInt;
Const Prefix: Array[0..7] Of Word=($7F00,$7E00,$7C00,$7800,$7000,$6000,$4000,
 $0000);
Begin
 H4XIsResync:=0;
 BitsCount:=H4YPos;
 V:=H4YShow(16);
 If ((H4XBugs And H4X_BUG_NOPAD)<>0) And (H4XResyncMarker=0) Then Exit;
 While V<=$FF Do Begin
  If (H4XPType=2) Or ((V Shr (8-H4XPType))<>1) Or (H4XPart<>0) Then Break;
  H4YSkip(8+H4XPType);
  Inc(BitsCount,8+H4XPType);
  V:=H4YShow(16);
 End;
 If BitsCount+8>=H4YSize*8 Then Begin
  V:=V Shr 8;
  V:=V Or (($7F) Shr (7-(BitsCount And 7)));
  If V=$7F Then H4XIsResync:=H4XMbNum;
 End Else Begin
  If V=Prefix[BitsCount And 7] Then Begin
   MbNumBits:=H4XLog2(H4XMbNum-1)+1;
   Save:=H4YPos;
   H4YSkip(1);
   H4YAlign;
   Len:=0;
   While Len<32 Do Begin If H4YBit<>0 Then Break; Inc(Len); End;
   MbNum:=H4YBits(MbNumBits);
   If (MbNum=0) Or (MbNum>H4XMbNum) Or (H4YPos+6>H4YSize*8) Then MbNum:=-1;
   H4YPos:=Save;
   If Len>=H4XPrefixLength Then H4XIsResync:=MbNum;
  End;
 End;
End;

Function H4XVideoPacketHeader: LongInt;
Var MbNumBits,Len,MbNum,Q,HeaderExt,TimeIncr: LongInt;
Begin
 H4XVideoPacketHeader:=-1;
 MbNumBits:=H4XLog2(H4XMbNum-1)+1;
 HeaderExt:=0;
 If H4YPos>H4YSize*8-20 Then Exit;
 Len:=0;
 While Len<32 Do Begin If H4YBit<>0 Then Break; Inc(Len); End;
 If Len<>H4XPrefixLength Then Exit;
 MbNum:=H4YBits(MbNumBits);
 If (MbNum>=H4XMbNum) Or (MbNum=0) Then Exit;
 H4XMbX:=MbNum Mod H4XMbW; H4XMbY:=MbNum Div H4XMbW;
 Q:=H4YBits(H4XQuantPrec);
 If Q<>0 Then Begin H4XQscale:=Q; H4XChromaQ:=Q; End;
 HeaderExt:=H4YBit;
 If HeaderExt<>0 Then Begin
  TimeIncr:=0;
  While (H4YBit<>0) And (H4YPos<H4YSize*8) Do Inc(TimeIncr);
  H4XMarker;
  H4YSkip(H4XTIncBits);
  H4XMarker;
  H4YSkip(2);
  H4YSkip(3);
  If (H4XPType=3) And (H4XSprUsage=2) Then Begin
   If H4XSpriteTrajectory<0 Then Exit;
  End;
  If H4XPType<>0 Then H4YBits(3);
  If H4XPType=2 Then H4YBits(3);
 End;
 If H4XNewPred<>0 Then H4XNewPredSkip;
 H4XVideoPacketHeader:=0;
End;

{ ---- macroblocs ---- }
Const H4XQuantTab: Array[0..3] Of ShortInt=(-1,-2,1,2);

Procedure H4XClearBlocks;
Var I: LongInt;
Begin
 FillChar(H4XBlk,SizeOf(H4XBlk),0);
 For I:=0 To 5 Do H4XBlkLast[I]:=-1;
End;

Function H4XTypeIndex: LongInt;
Begin H4XTypeIndex:=H4XMbX+H4XMbY*H4XMbS+H4XOff; End;

Function H4XDecodeMb: LongInt;
Label Fin;
Var
 Cbpc,Cbpy,I,Cbp,Px,Py,Mx,My,Dquant,Xy,Modb1,Modb2,MbType,Next,Delta,M,UseDc,
  SelFlag: LongInt;
 IsIntra: Boolean; Mt: PM4L32;
Begin
 H4XDecodeMb:=H4X_SLICE_ERR;
 Mt:=H4XP[H4XCurI].Mt;
 Xy:=H4XTypeIndex;
 H4XClearBlocks;
 IsIntra:=False; Dquant:=0; Cbp:=0;
 If (H4XPType=1) Or (H4XPType=3) Then Begin
  Repeat
   If H4YBit<>0 Then Begin
    H4XMbIntra:=0;
    For I:=0 To 5 Do H4XBlkLast[I]:=-1;
    H4XMvDir:=1; H4XMvType:=0;
    If (H4XPType=3) And (H4XSprUsage=2) Then Begin
     Mt^[Xy]:=H4X_SKIP Or H4X_GMC Or H4X_16X16 Or H4X_L0;
     H4XMcSel:=1;
     H4XMv[0,0,0]:=H4XGetAmv(0); H4XMv[0,0,1]:=H4XGetAmv(1);
     H4XSkip:=0;
    End Else Begin
     Mt^[Xy]:=H4X_SKIP Or H4X_16X16 Or H4X_L0;
     H4XMcSel:=0;
     H4XMv[0,0,0]:=0; H4XMv[0,0,1]:=0;
     H4XSkip:=1;
    End;
    Goto Fin;
   End;
   Cbpc:=H4YGetVlc(H4YVInter);
   If Cbpc<0 Then Exit;
  Until Cbpc<>20;
  Dquant:=Cbpc And 8;
  H4XMbIntra:=Ord((Cbpc And 4)<>0);
  If H4XMbIntra<>0 Then IsIntra:=True
  Else Begin
   If (H4XPType=3) And (H4XSprUsage=2) And ((Cbpc And 16)=0) Then H4XMcSel:=H4YBit
    Else H4XMcSel:=0;
   Cbpy:=H4YGetVlc(H4YVCbpy);
   If Cbpy<0 Then Exit;
   Cbpy:=Cbpy Xor $F;
   Cbp:=(Cbpc And 3) Or (Cbpy Shl 2);
   If Dquant<>0 Then H4XSetQscale(H4XQscale+H4XQuantTab[H4YBits(2)]);
   If (H4XProg=0) And ((Cbp<>0) Or ((H4XBugs And H4X_BUG_XVIDILACE)<>0)) Then
    H4XIDct:=H4YBit;
   H4XMvDir:=1;
   If (Cbpc And 16)=0 Then Begin
    If H4XMcSel<>0 Then Begin
     Mt^[Xy]:=H4X_GMC Or H4X_16X16 Or H4X_L0;
     H4XMvType:=0;
     Mx:=H4XGetAmv(0); My:=H4XGetAmv(1);
     H4XMv[0,0,0]:=Mx; H4XMv[0,0,1]:=My;
    End Else If (H4XProg=0) And (H4YBit<>0) Then Begin
     Mt^[Xy]:=H4X_16X8 Or H4X_L0 Or H4X_INTERLACED;
     H4XMvType:=2;
     H4XFieldSel[0,0]:=H4YBit; H4XFieldSel[0,1]:=H4YBit;
     H4XPredMotion(0,Px,Py);
     For I:=0 To 1 Do Begin
      Mx:=H4YDecMotion(Px,H4XFCode);
      If Mx>=$FFFF Then Exit;
      My:=H4YDecMotion(Py Div 2,H4XFCode);
      If My>=$FFFF Then Exit;
      H4XMv[0,I,0]:=Mx; H4XMv[0,I,1]:=My;
     End;
    End Else Begin
     Mt^[Xy]:=H4X_16X16 Or H4X_L0;
     H4XMvType:=0;
     H4XPredMotion(0,Px,Py);
     Mx:=H4YDecMotion(Px,H4XFCode);
     If Mx>=$FFFF Then Exit;
     My:=H4YDecMotion(Py,H4XFCode);
     If My>=$FFFF Then Exit;
     H4XMv[0,0,0]:=Mx; H4XMv[0,0,1]:=My;
    End;
   End Else Begin
    Mt^[Xy]:=H4X_8X8 Or H4X_L0;
    H4XMvType:=1;
    For I:=0 To 3 Do Begin
     M:=H4XPredMotion(I,Px,Py);
     Mx:=H4YDecMotion(Px,H4XFCode);
     If Mx>=$FFFF Then Exit;
     My:=H4YDecMotion(Py,H4XFCode);
     If My>=$FFFF Then Exit;
     H4XMv[0,I,0]:=Mx; H4XMv[0,I,1]:=My;
     H4XMvSet(H4XCurI,M,0,Mx); H4XMvSet(H4XCurI,M,1,My);
    End;
   End;
  End;
 End Else If H4XPType=2 Then Begin
  H4XMbIntra:=0; H4XMcSel:=0;
  If H4XMbX=0 Then Begin
   For I:=0 To 1 Do Begin H4XLastMv[I,0,0]:=0; H4XLastMv[I,0,1]:=0; H4XLastMv[I,1,
    0]:=0; H4XLastMv[I,1,1]:=0; End;
  End;
  H4XSkip:=H4XP[H4XNextI].Sk^[H4XMbY*H4XMbS+H4XMbX+H4XOff];
  If H4XSkip<>0 Then Begin
   For I:=0 To 5 Do H4XBlkLast[I]:=-1;
   H4XMvDir:=1; H4XMvType:=0;
   H4XMv[0,0,0]:=0; H4XMv[0,0,1]:=0; H4XMv[1,0,0]:=0; H4XMv[1,0,1]:=0;
   Mt^[Xy]:=H4X_SKIP Or H4X_16X16 Or H4X_L0;
   Goto Fin;
  End;
  Modb1:=H4YBit;
  If Modb1<>0 Then Begin
   MbType:=H4X_DIRECT Or H4X_SKIP Or H4X_L0 Or H4X_L1;
   Cbp:=0;
  End Else Begin
   Modb2:=H4YBit;
   I:=0;
   While H4YBit=0 Do Begin
    Inc(I);
    If I>=3 Then Begin H4YBit; Break; End;
   End;
   Case I Of
    0: MbType:=H4X_DIRECT Or H4X_L0 Or H4X_L1;
    1: MbType:=H4X_L0 Or H4X_L1 Or H4X_16X16;
    2: MbType:=H4X_L1 Or H4X_16X16;
    Else MbType:=H4X_L0 Or H4X_16X16;
   End;
   If Modb2<>0 Then Cbp:=0 Else Cbp:=H4YBits(6);
   If ((MbType And H4X_DIRECT)=0) And (Cbp<>0) Then Begin
    If H4YBit<>0 Then H4XSetQscale(H4XQscale+H4YBit*4-2);
   End;
   If H4XProg=0 Then Begin
    If Cbp<>0 Then H4XIDct:=H4YBit;
    If ((MbType And H4X_DIRECT)=0) And (H4YBit<>0) Then Begin
     MbType:=(MbType Or H4X_16X8 Or H4X_INTERLACED) And Not H4X_16X16;
     If (MbType And H4X_L0)<>0 Then Begin H4XFieldSel[0,0]:=H4YBit; H4XFieldSel[0,
      1]:=H4YBit; End;
     If (MbType And H4X_L1)<>0 Then Begin H4XFieldSel[1,0]:=H4YBit; H4XFieldSel[1,
      1]:=H4YBit; End;
    End;
   End;
   H4XMvDir:=0;
   If (MbType And (H4X_DIRECT Or H4X_INTERLACED))=0 Then Begin
    H4XMvType:=0;
    If (MbType And H4X_L0)<>0 Then Begin
     H4XMvDir:=1;
     Mx:=H4YDecMotion(H4XLastMv[0,0,0],H4XFCode);
     My:=H4YDecMotion(H4XLastMv[0,0,1],H4XFCode);
     H4XLastMv[0,1,0]:=Mx; H4XLastMv[0,0,0]:=Mx; H4XMv[0,0,0]:=Mx;
     H4XLastMv[0,1,1]:=My; H4XLastMv[0,0,1]:=My; H4XMv[0,0,1]:=My;
    End;
    If (MbType And H4X_L1)<>0 Then Begin
     H4XMvDir:=H4XMvDir Or 2;
     Mx:=H4YDecMotion(H4XLastMv[1,0,0],H4XBCode);
     My:=H4YDecMotion(H4XLastMv[1,0,1],H4XBCode);
     H4XLastMv[1,1,0]:=Mx; H4XLastMv[1,0,0]:=Mx; H4XMv[1,0,0]:=Mx;
     H4XLastMv[1,1,1]:=My; H4XLastMv[1,0,1]:=My; H4XMv[1,0,1]:=My;
    End;
   End Else If (MbType And H4X_DIRECT)=0 Then Begin
    H4XMvType:=2;
    If (MbType And H4X_L0)<>0 Then Begin
     H4XMvDir:=1;
     For I:=0 To 1 Do Begin
      Mx:=H4YDecMotion(H4XLastMv[0,I,0],H4XFCode);
      My:=H4YDecMotion(H4XLastMv[0,I,1] Div 2,H4XFCode);
      H4XLastMv[0,I,0]:=Mx; H4XMv[0,I,0]:=Mx;
      H4XMv[0,I,1]:=My; H4XLastMv[0,I,1]:=My*2;
     End;
    End;
    If (MbType And H4X_L1)<>0 Then Begin
     H4XMvDir:=H4XMvDir Or 2;
     For I:=0 To 1 Do Begin
      Mx:=H4YDecMotion(H4XLastMv[1,I,0],H4XBCode);
      My:=H4YDecMotion(H4XLastMv[1,I,1] Div 2,H4XBCode);
      H4XLastMv[1,I,0]:=Mx; H4XMv[1,I,0]:=Mx;
      H4XMv[1,I,1]:=My; H4XLastMv[1,I,1]:=My*2;
     End;
    End;
   End;
  End;
  If (MbType And H4X_DIRECT)<>0 Then Begin
   If (MbType And H4X_SKIP)<>0 Then Begin Mx:=0; My:=0; End
   Else Begin Mx:=H4YDecMotion(0,1); My:=H4YDecMotion(0,1); End;
   H4XMvDir:=7;
   MbType:=MbType Or H4XSetDirectMv(Mx,My);
  End;
  Mt^[Xy]:=MbType;
 End Else Begin
  Repeat
   Cbpc:=H4YGetVlc(H4YVIntra);
   If Cbpc<0 Then Exit;
  Until Cbpc<>8;
  Dquant:=Cbpc And 4;
  H4XMbIntra:=1;
  IsIntra:=True;
 End;
 If IsIntra Then Begin
  H4XAcPred:=H4YBit;
  If H4XAcPred<>0 Then Mt^[Xy]:=H4X_INTRA Or H4X_ACPRED Else Mt^[Xy]:=H4X_INTRA;
  Cbpy:=H4YGetVlc(H4YVCbpy);
  If Cbpy<0 Then Exit;
  Cbp:=(Cbpc And 3) Or (Cbpy Shl 2);
  If H4XQscale<H4XIntraDcThr Then UseDc:=1 Else UseDc:=0;
  If Dquant<>0 Then H4XSetQscale(H4XQscale+H4XQuantTab[H4YBits(2)]);
  If H4XProg=0 Then H4XIDct:=H4YBit;
  For I:=0 To 5 Do Begin
   If H4XBlock(I,Cbp And 32,1,UseDc,0)<0 Then Exit;
   Cbp:=Cbp+Cbp;
  End;
  Goto Fin;
 End;
 For I:=0 To 5 Do Begin
  If H4XBlock(I,Cbp And 32,0,0,0)<0 Then Exit;
  Cbp:=Cbp+Cbp;
 End;
Fin:
 Next:=H4XIsResync;
 If Next<>0 Then Begin
  If H4XMbX+H4XMbY*H4XMbW+1>=Next Then Begin H4XDecodeMb:=H4X_SLICE_END; Exit; End;
  If H4XPType=2 Then Begin
   If H4XMbX+1=H4XMbW Then Delta:=2 Else Delta:=1;
   If H4XP[H4XNextI].Sk^[Xy+Delta]<>0 Then Begin H4XDecodeMb:=H4X_SLICE_OK; Exit;
    End;
  End;
  H4XDecodeMb:=H4X_SLICE_END; Exit;
 End;
 H4XDecodeMb:=H4X_SLICE_OK;
End;

{ ---- partitions de donnees (mpeg4_decode_partition_a/b, partitioned_mb) ---- }
Function H4XPartitionA: LongInt;
Var
 MbCount,Cbpc,I,Dir,Dc,Bits,Px,Py,Mx,My,M,Xy: LongInt; Mt: PM4L32; Done:
  Boolean;
Begin
 MbCount:=0;
 Mt:=H4XP[H4XCurI].Mt;
 H4XFirstLine:=1;
 While H4XMbY<H4XMbH Do Begin
  While H4XMbX<H4XMbW Do Begin
   Xy:=H4XTypeIndex;
   Inc(MbCount);
   If (H4XMbX=H4XResyncX) And (H4XMbY=H4XResyncY+1) Then H4XFirstLine:=0;
   If H4XPType=0 Then Begin
    Repeat
     If H4YShow(19)=$6B001 Then Begin H4XPartitionA:=MbCount-1; Exit; End;
     Cbpc:=H4YGetVlc(H4YVIntra);
     If Cbpc<0 Then Begin H4XPartitionA:=-1; Exit; End;
    Until Cbpc<>8;
    H4XCbpTab^[Xy]:=Cbpc And 3;
    Mt^[Xy]:=H4X_INTRA;
    H4XMbIntra:=1;
    If (Cbpc And 4)<>0 Then H4XSetQscale(H4XQscale+H4XQuantTab[H4YBits(2)]);
    H4XP[H4XCurI].Qs^[Xy]:=H4XQscale;
    H4XIntraTab^[Xy]:=1;
    Dir:=0;
    For I:=0 To 5 Do Begin
     Dc:=H4XDecodeDc(I,M);
     If Dc<0 Then Begin H4XPartitionA:=-1; Exit; End;
     Dir:=Dir Shl 1;
     If M<>0 Then Dir:=Dir Or 1;
    End;
    H4XDirTab^[Xy]:=Dir;
   End Else Begin
    Done:=False;
    Repeat
     Bits:=H4YShow(17);
     If Bits=$1F001 Then Begin H4XPartitionA:=MbCount-1; Exit; End;
     H4YSkip(1);
     If (Bits And $10000)<>0 Then Begin
      If (H4XPType=3) And (H4XSprUsage=2) Then Begin
       Mt^[Xy]:=H4X_SKIP Or H4X_16X16 Or H4X_GMC Or H4X_L0;
       Mx:=H4XGetAmv(0); My:=H4XGetAmv(1);
      End Else Begin
       Mt^[Xy]:=H4X_SKIP Or H4X_16X16 Or H4X_L0;
       Mx:=0; My:=0;
      End;
      H4XFillMv4(Mx,My);
      If H4XIntraTab^[Xy]<>0 Then H4XCleanIntraEntries;
      Done:=True; Cbpc:=-2;
     End Else Begin
      Cbpc:=H4YGetVlc(H4YVInter);
      If Cbpc<0 Then Begin H4XPartitionA:=-1; Exit; End;
     End;
    Until Done Or (Cbpc<>20);
    If Not Done Then Begin
     H4XCbpTab^[Xy]:=Cbpc And (8+3);
     H4XMbIntra:=Ord((Cbpc And 4)<>0);
     If H4XMbIntra<>0 Then Begin
      Mt^[Xy]:=H4X_INTRA;
      H4XIntraTab^[Xy]:=1;
      H4XFillMv4(0,0);
     End Else Begin
      If H4XIntraTab^[Xy]<>0 Then H4XCleanIntraEntries;
      If (H4XPType=3) And (H4XSprUsage=2) And ((Cbpc And 16)=0) Then H4XMcSel:=
       H4YBit Else H4XMcSel:=0;
      If (Cbpc And 16)=0 Then Begin
       H4XPredMotion(0,Px,Py);
       If H4XMcSel=0 Then Begin
        Mx:=H4YDecMotion(Px,H4XFCode);
        If Mx>=$FFFF Then Begin H4XPartitionA:=-1; Exit; End;
        My:=H4YDecMotion(Py,H4XFCode);
        If My>=$FFFF Then Begin H4XPartitionA:=-1; Exit; End;
        Mt^[Xy]:=H4X_16X16 Or H4X_L0;
       End Else Begin
        Mx:=H4XGetAmv(0); My:=H4XGetAmv(1);
        Mt^[Xy]:=H4X_16X16 Or H4X_GMC Or H4X_L0;
       End;
       H4XFillMv4(Mx,My);
      End Else Begin
       Mt^[Xy]:=H4X_8X8 Or H4X_L0;
       For I:=0 To 3 Do Begin
        M:=H4XPredMotion(I,Px,Py);
        Mx:=H4YDecMotion(Px,H4XFCode);
        If Mx>=$FFFF Then Begin H4XPartitionA:=-1; Exit; End;
        My:=H4YDecMotion(Py,H4XFCode);
        If My>=$FFFF Then Begin H4XPartitionA:=-1; Exit; End;
        H4XMvSet(H4XCurI,M,0,Mx); H4XMvSet(H4XCurI,M,1,My);
       End;
      End;
     End;
    End;
   End;
   Inc(H4XMbX);
  End;
  H4XMbX:=0;
  Inc(H4XMbY);
 End;
 H4XPartitionA:=MbCount;
End;

Function H4XPartitionB(MbCount: LongInt): LongInt;
Var MbNum,Xy,AcPred,Cbpy,I,Dir,Dc,M: LongInt; Mt: PM4L32;
Begin
 H4XPartitionB:=-1;
 MbNum:=0;
 Mt:=H4XP[H4XCurI].Mt;
 H4XMbX:=H4XResyncX;
 H4XFirstLine:=1;
 H4XMbY:=H4XResyncY;
 While MbNum<MbCount Do Begin
  While (MbNum<MbCount) And (H4XMbX<H4XMbW) Do Begin
   Xy:=H4XTypeIndex;
   Inc(MbNum);
   If (H4XMbX=H4XResyncX) And (H4XMbY=H4XResyncY+1) Then H4XFirstLine:=0;
   If H4XPType=0 Then Begin
    AcPred:=H4YBit;
    Cbpy:=H4YGetVlc(H4YVCbpy);
    If Cbpy<0 Then Exit;
    H4XCbpTab^[Xy]:=H4XCbpTab^[Xy] Or (Cbpy Shl 2);
    If AcPred<>0 Then Mt^[Xy]:=Mt^[Xy] Or H4X_ACPRED;
   End Else Begin
    If (Mt^[Xy] And H4X_INTRA)<>0 Then Begin
     Dir:=0;
     AcPred:=H4YBit;
     Cbpy:=H4YGetVlc(H4YVCbpy);
     If Cbpy<0 Then Exit;
     If (H4XCbpTab^[Xy] And 8)<>0 Then H4XSetQscale(H4XQscale+H4XQuantTab[H4YBits(
      2)]);
     H4XP[H4XCurI].Qs^[Xy]:=H4XQscale;
     H4XMbIntra:=1;
     For I:=0 To 5 Do Begin
      Dc:=H4XDecodeDc(I,M);
      If Dc<0 Then Exit;
      Dir:=Dir Shl 1;
      If M<>0 Then Dir:=Dir Or 1;
     End;
     H4XCbpTab^[Xy]:=H4XCbpTab^[Xy] And 3;
     H4XCbpTab^[Xy]:=H4XCbpTab^[Xy] Or (Cbpy Shl 2);
     If AcPred<>0 Then Mt^[Xy]:=Mt^[Xy] Or H4X_ACPRED;
     H4XDirTab^[Xy]:=Dir;
    End Else If (Mt^[Xy] And H4X_SKIP)<>0 Then Begin
     H4XP[H4XCurI].Qs^[Xy]:=H4XQscale;
     H4XCbpTab^[Xy]:=0;
    End Else Begin
     Cbpy:=H4YGetVlc(H4YVCbpy);
     If Cbpy<0 Then Exit;
     If (H4XCbpTab^[Xy] And 8)<>0 Then H4XSetQscale(H4XQscale+H4XQuantTab[H4YBits(
      2)]);
     H4XP[H4XCurI].Qs^[Xy]:=H4XQscale;
     H4XCbpTab^[Xy]:=H4XCbpTab^[Xy] And 3;
     H4XCbpTab^[Xy]:=H4XCbpTab^[Xy] Or ((Cbpy Xor $F) Shl 2);
    End;
   End;
   Inc(H4XMbX);
  End;
  If MbNum>=MbCount Then Begin H4XPartitionB:=0; Exit; End;
  H4XMbX:=0;
  Inc(H4XMbY);
 End;
 H4XPartitionB:=0;
End;

Function H4XPartitions: LongInt;
Var MbNum,Ret: LongInt;
Begin
 H4XPartitions:=-1;
 MbNum:=H4XPartitionA;
 If MbNum<=0 Then Exit;
 If H4XResyncX+H4XResyncY*H4XMbW+MbNum>H4XMbNum Then Exit;
 H4XMbLeft:=MbNum;
 If H4XPType=0 Then Begin
  While H4YShow(9)=1 Do H4YSkip(9);
  If H4YBits(19)<>$6B001 Then Exit;
 End Else Begin
  While H4YShow(10)=1 Do H4YSkip(10);
  If H4YBits(17)<>$1F001 Then Exit;
 End;
 Ret:=H4XPartitionB(MbNum);
 If Ret<0 Then Exit;
 H4XPartitions:=0;
End;

Function H4XPartitionedMb: LongInt;
Var Cbp,MbType,UseDc,I,Xy,Delta: LongInt; Mt: PM4L32;
Begin
 H4XPartitionedMb:=H4X_SLICE_ERR;
 Mt:=H4XP[H4XCurI].Mt;
 Xy:=H4XTypeIndex;
 MbType:=Mt^[Xy];
 Cbp:=H4XCbpTab^[Xy];
 If H4XQscale<H4XIntraDcThr Then UseDc:=1 Else UseDc:=0;
 If H4XP[H4XCurI].Qs^[Xy]<>H4XQscale Then H4XSetQscale(H4XP[H4XCurI].Qs^[Xy]);
 H4XClearBlocks;
 If (H4XPType=1) Or (H4XPType=3) Then Begin
  For I:=0 To 3 Do Begin
   H4XMv[0,I,0]:=H4XMvGet(H4XCurI,H4XB8S*(2*H4XMbY+(I Shr 1))+2*H4XMbX+(I And 1),0);
   H4XMv[0,I,1]:=H4XMvGet(H4XCurI,H4XB8S*(2*H4XMbY+(I Shr 1))+2*H4XMbX+(I And 1),1);
  End;
  H4XMbIntra:=Ord((MbType And H4X_INTRA)<>0);
  If (MbType And H4X_SKIP)<>0 Then Begin
   For I:=0 To 5 Do H4XBlkLast[I]:=-1;
   H4XMvDir:=1; H4XMvType:=0;
   If (H4XPType=3) And (H4XSprUsage=2) Then Begin H4XMcSel:=1; H4XSkip:=0; End
   Else Begin H4XMcSel:=0; H4XSkip:=1; End;
  End Else If H4XMbIntra<>0 Then Begin
   H4XAcPred:=Ord((MbType And H4X_ACPRED)<>0);
  End Else Begin
   H4XMvDir:=1;
   If (MbType And H4X_8X8)<>0 Then H4XMvType:=1 Else H4XMvType:=0;
  End;
 End Else Begin
  H4XMbIntra:=1;
  H4XAcPred:=Ord((MbType And H4X_ACPRED)<>0);
 End;
 If (MbType And H4X_SKIP)=0 Then Begin
  For I:=0 To 5 Do Begin
   If H4XBlock(I,Cbp And 32,H4XMbIntra,UseDc,H4XRvlc)<0 Then Exit;
   Cbp:=Cbp+Cbp;
  End;
 End;
 Dec(H4XMbLeft);
 If H4XMbLeft<=0 Then Begin
  If H4XIsResync<>0 Then H4XPartitionedMb:=H4X_SLICE_END Else H4XPartitionedMb:=
   H4X_SLICE_NOEND;
 End Else Begin
  H4XPartitionedMb:=H4X_SLICE_OK;
  If H4XIsResync<>0 Then Begin
   If H4XMbX+1=H4XMbW Then Delta:=2 Else Delta:=1;
   If H4XCbpTab^[Xy+Delta]<>0 Then H4XPartitionedMb:=H4X_SLICE_END;
  End;
 End;
End;

{ ---- compensation de mouvement (mpegvideo_motion.c, hpeldsp, qpeldsp,
 mpegvideodsp) ---- }
Type TM4Q=Array[0..24*24-1] Of LongInt;
Var
 H4XWin: Array[0..24*24-1] Of Byte;
 QF,QH,QH2,QV,QHV: TM4Q;

Procedure H4XFetch(Pl: H4PBuf; PStr: LongInt; X0,RowBase,RowStep,NW,NH,EW,EH:
 LongInt);
Var I,J,X,Y: LongInt;
Begin
 For J:=0 To NH-1 Do Begin
  Y:=RowBase+J*RowStep;
  If Y<0 Then Y:=0 Else If Y>=EH Then Y:=EH-1;
  For I:=0 To NW-1 Do Begin
   X:=X0+I;
   If X<0 Then X:=0 Else If X>=EW Then X:=EW-1;
   H4XWin[J*24+I]:=Pl^[Y*PStr+X];
  End;
 End;
End;

Procedure H4XHpel(Dst: H4PBuf; DOff,DStr,Dxy,W,H: LongInt; NoRnd,Avg:
 Boolean);
Var X,Y,A,B,C,D,V,P: LongInt;
Begin
 For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
  P:=Y*24+X;
  A:=H4XWin[P];
  Case Dxy Of
   0: V:=A;
   1: Begin B:=H4XWin[P+1]; If NoRnd Then V:=(A+B) Shr 1 Else V:=(A+B+1) Shr 1;
    End;
   2: Begin C:=H4XWin[P+24]; If NoRnd Then V:=(A+C) Shr 1 Else V:=(A+C+1) Shr 1;
    End;
   Else Begin
    B:=H4XWin[P+1]; C:=H4XWin[P+24]; D:=H4XWin[P+25];
    If NoRnd Then V:=(A+B+C+D+1) Shr 2 Else V:=(A+B+C+D+2) Shr 2;
   End;
  End;
  If Avg Then V:=(Dst^[DOff+Y*DStr+X]+V+1) Shr 1;
  Dst^[DOff+Y*DStr+X]:=V;
 End;
End;

Function H4XQcm(B,Rc: LongInt): LongInt;
Var V: LongInt;
Begin
 V:=H4XSar(B+Rc,5);
 If V<0 Then V:=0 Else If V>255 Then V:=255;
 H4XQcm:=V;
End;

Function H4XMir(J,W: LongInt): LongInt;
Begin
 If J<0 Then H4XMir:=-1-J Else If J>W Then H4XMir:=2*W+1-J Else H4XMir:=J;
End;

{ filtre passe-bas horizontal sur Rows lignes, W colonnes ; source de pas 24 }
Procedure H4XHLow(Var Src,Dst: TM4Q; SOff,Rows,W,Rc: LongInt);
Var I,J,K: LongInt; S: Array[0..16] Of LongInt;
Begin
 For J:=0 To Rows-1 Do Begin
  For K:=0 To W Do S[K]:=Src[SOff+J*24+K];
  For I:=0 To W-1 Do
   Dst[J*24+I]:=H4XQcm((S[I]+S[I+1])*20-(S[H4XMir(I-1,W)]+S[H4XMir(I+2,W)])*6+(S[
    H4XMir(I-2,W)]+S[H4XMir(I+3,W)])*3-(S[H4XMir(I-3,W)]+S[H4XMir(I+4,W)]),Rc);
 End;
End;

Procedure H4XVLow(Var Src,Dst: TM4Q; SOff,W,Rc: LongInt);
Var I,J,K: LongInt; S: Array[0..16] Of LongInt;
Begin
 For I:=0 To W-1 Do Begin
  For K:=0 To W Do S[K]:=Src[SOff+K*24+I];
  For J:=0 To W-1 Do
   Dst[J*24+I]:=H4XQcm((S[J]+S[J+1])*20-(S[H4XMir(J-1,W)]+S[H4XMir(J+2,W)])*6+(S[
    H4XMir(J-2,W)]+S[H4XMir(J+3,W)])*3-(S[H4XMir(J-3,W)]+S[H4XMir(J+4,W)]),Rc);
 End;
End;

{ Mode : 0 put, 1 put_no_rnd, 2 avg ; fenetre H4XWin de (W+1)x(W+1) pixels }
Procedure H4XQpel(Dst: H4PBuf; DOff,DStr,Dxy,W,Mode: LongInt);
Var X,Y,I,J,Rc,Mx,My,V: LongInt;
Function L2(A,B: LongInt): LongInt;
Begin If Mode=1 Then L2:=(A+B) Shr 1 Else L2:=(A+B+1) Shr 1; End;
Function L2p(A,B: LongInt): LongInt;
Begin If Mode=1 Then L2p:=(A+B) Shr 1 Else L2p:=(A+B+1) Shr 1; End;
Procedure Outp(PX,PY,Vv: LongInt);
Begin
 If Mode=2 Then Vv:=(Dst^[DOff+PY*DStr+PX]+Vv+1) Shr 1;
 Dst^[DOff+PY*DStr+PX]:=Vv;
End;
Begin
 If Mode=1 Then Rc:=15 Else Rc:=16;
 Mx:=Dxy And 3; My:=Dxy Shr 2;
 For J:=0 To W Do For I:=0 To W Do QF[J*24+I]:=H4XWin[J*24+I];
 Case My*4+Mx Of
  0: For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QF[Y*24+X]);
  1,3: Begin
   H4XHLow(QF,QH,0,W,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,L2(QF[Y*24+X+(Mx Shr 1)],QH[Y*
    24+X]));
  End;
  2: Begin
   H4XHLow(QF,QH,0,W,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QH[Y*24+X]);
  End;
  4,12: Begin
   H4XVLow(QF,QV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,L2(QF[(Y+(My Shr 1))*24+X],QV[
    Y*24+X]));
  End;
  8: Begin
   H4XVLow(QF,QV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QV[Y*24+X]);
  End;
  5,7,13,15: Begin
   H4XHLow(QF,QH,0,W+1,W,Rc);
   For J:=0 To W Do For I:=0 To W-1 Do QH[J*24+I]:=L2p(QH[J*24+I],QF[J*24+I+(Mx
    Shr 1)]);
   H4XVLow(QH,QHV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,L2(QH[(Y+(My Shr 1))*24+X],
    QHV[Y*24+X]));
  End;
  6,14: Begin
   H4XHLow(QF,QH,0,W+1,W,Rc);
   H4XVLow(QH,QHV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,L2(QH[(Y+(My Shr 1))*24+X],
    QHV[Y*24+X]));
  End;
  9,11: Begin
   H4XHLow(QF,QH,0,W+1,W,Rc);
   For J:=0 To W Do For I:=0 To W-1 Do QH[J*24+I]:=L2p(QH[J*24+I],QF[J*24+I+(Mx
    Shr 1)]);
   H4XVLow(QH,QHV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QHV[Y*24+X]);
  End;
  10: Begin
   H4XHLow(QF,QH,0,W+1,W,Rc);
   H4XVLow(QH,QHV,0,W,Rc);
   For Y:=0 To W-1 Do For X:=0 To W-1 Do Outp(X,Y,QHV[Y*24+X]);
  End;
 End;
End;

Procedure H4XGmc1(Dst: H4PBuf; DOff,DStr,H,X16,Y16,Rnd,WOff: LongInt);   {
 fenetre H4XWin ; 8 colonnes }
Var A,B,C,D,X,Y,P: LongInt;
Begin
 A:=(16-X16)*(16-Y16); B:=X16*(16-Y16); C:=(16-X16)*Y16; D:=X16*Y16;
 For Y:=0 To H-1 Do For X:=0 To 7 Do Begin
  P:=Y*24+X+WOff;
  Dst^[DOff+Y*DStr+X]:=(A*H4XWin[P]+B*H4XWin[P+1]+C*H4XWin[P+24]+D*H4XWin[P+25]+Rnd)
   Shr 8;
 End;
End;

Procedure H4XGmcPlane(Pl: H4PBuf; PStr: LongInt; Dst: H4PBuf; DOff,DStr,H:
 LongInt; Ox,Oy,Dxx,Dxy,Dyx,Dyy,Shift,R,Width,Height: LongInt);
Var Y,X,Vx,Vy,SrcX,SrcY,FracX,FracY,Index,S: LongInt;
Function Clip(V,Lo,Hi: LongInt): LongInt;
Begin If V<Lo Then V:=Lo Else If V>Hi Then V:=Hi; Clip:=V; End;
Begin
 S:=LongInt(1) Shl Shift;
 Dec(Width); Dec(Height);
 For Y:=0 To H-1 Do Begin
  Vx:=Ox; Vy:=Oy;
  For X:=0 To 7 Do Begin
   SrcX:=H4XSar(Vx,16); SrcY:=H4XSar(Vy,16);
   FracX:=SrcX And (S-1); FracY:=SrcY And (S-1);
   SrcX:=H4XSar(SrcX,Shift); SrcY:=H4XSar(SrcY,Shift);
   If (SrcX>=0) And (SrcX<Width) Then Begin
    If (SrcY>=0) And (SrcY<Height) Then Begin
     Index:=SrcX+SrcY*PStr;
     Dst^[DOff+Y*DStr+X]:=((Pl^[Index]*(S-FracX)+Pl^[Index+1]*FracX)*(S-FracY)+(
      Pl^[Index+PStr]*(S-FracX)+Pl^[Index+PStr+1]*FracX)*FracY+R) Shr (Shift*2);
    End Else Begin
     Index:=SrcX+Clip(SrcY,0,Height)*PStr;
     Dst^[DOff+Y*DStr+X]:=((Pl^[Index]*(S-FracX)+Pl^[Index+1]*FracX)*S+R) Shr (
      Shift*2);
    End;
   End Else Begin
    If (SrcY>=0) And (SrcY<Height) Then Begin
     Index:=Clip(SrcX,0,Width)+SrcY*PStr;
     Dst^[DOff+Y*DStr+X]:=((Pl^[Index]*(S-FracY)+Pl^[Index+PStr]*FracY)*S+R) Shr
      (Shift*2);
    End Else Begin
     Index:=Clip(SrcX,0,Width)+Clip(SrcY,0,Height)*PStr;
     Dst^[DOff+Y*DStr+X]:=Pl^[Index];
    End;
   End;
   Vx:=Vx+Dxx; Vy:=Vy+Dyx;
  End;
  Ox:=Ox+Dxy; Oy:=Oy+Dyy;
 End;
End;

Procedure H4XMcselMotion(Ref,DY,DC: LongInt);
Var Pc: ^TM4Pic; Mx,My,SrcX,SrcY,A,Ox,Oy,Dxy: LongInt; Cur: ^TM4Pic;
Begin
 Pc:=@H4XP[Ref]; Cur:=@H4XP[H4XCurI];
 A:=H4XWarpAcc;
 If H4XRealWarp=1 Then Begin
  Mx:=LongInt(H4XSpOff[0,0]); My:=LongInt(H4XSpOff[0,1]);
  SrcX:=H4XMbX*16+H4XSar(Mx,A+1); SrcY:=H4XMbY*16+H4XSar(My,A+1);
  Mx:=Mx*(LongInt(1) Shl (3-A)); My:=My*(LongInt(1) Shl (3-A));
  If SrcX<-16 Then SrcX:=-16 Else If SrcX>H4XW Then SrcX:=H4XW;
  If SrcX=H4XW Then Mx:=0;
  If SrcY<-16 Then SrcY:=-16 Else If SrcY>H4XH Then SrcY:=H4XH;
  If SrcY=H4XH Then My:=0;
  H4XFetch(Pc^.Y,H4XLY,SrcX,SrcY,1,17,17,H4XHEdge,H4XVEdge);
  If ((Mx Or My) And 7)<>0 Then Begin
   H4XGmc1(Cur^.Y,DY,H4XLY,16,Mx And 15,My And 15,128-H4XNoRnd,0);
   H4XGmc1(Cur^.Y,DY+8,H4XLY,16,Mx And 15,My And 15,128-H4XNoRnd,8);
  End Else Begin
   Dxy:=((H4XSar(Mx,3)) And 1) Or ((H4XSar(My,2)) And 2);
   H4XHpel(Cur^.Y,DY,H4XLY,Dxy,16,16,H4XNoRnd<>0,False);
  End;
  Mx:=LongInt(H4XSpOff[1,0]); My:=LongInt(H4XSpOff[1,1]);
  SrcX:=H4XMbX*8+H4XSar(Mx,A+1); SrcY:=H4XMbY*8+H4XSar(My,A+1);
  Mx:=Mx*(LongInt(1) Shl (3-A)); My:=My*(LongInt(1) Shl (3-A));
  If SrcX<-8 Then SrcX:=-8 Else If SrcX>(H4XW Shr 1) Then SrcX:=H4XW Shr 1;
  If SrcX=(H4XW Shr 1) Then Mx:=0;
  If SrcY<-8 Then SrcY:=-8 Else If SrcY>(H4XH Shr 1) Then SrcY:=H4XH Shr 1;
  If SrcY=(H4XH Shr 1) Then My:=0;
  H4XFetch(Pc^.U,H4XLC,SrcX,SrcY,1,9,9,H4XHEdge Shr 1,H4XVEdge Shr 1);
  H4XGmc1(Cur^.U,DC,H4XLC,8,Mx And 15,My And 15,128-H4XNoRnd,0);
  H4XFetch(Pc^.V,H4XLC,SrcX,SrcY,1,9,9,H4XHEdge Shr 1,H4XVEdge Shr 1);
  H4XGmc1(Cur^.V,DC,H4XLC,8,Mx And 15,My And 15,128-H4XNoRnd,0);
 End Else Begin
  Ox:=LongInt(H4XSpOff[0,0])+LongInt(H4XSpDelta[0,0])*H4XMbX*16+LongInt(H4XSpDelta[
   0,1])*H4XMbY*16;
  Oy:=LongInt(H4XSpOff[0,1])+LongInt(H4XSpDelta[1,0])*H4XMbX*16+LongInt(H4XSpDelta[
   1,1])*H4XMbY*16;
  H4XGmcPlane(Pc^.Y,H4XLY,Cur^.Y,DY,H4XLY,16,Ox,Oy,LongInt(H4XSpDelta[0,0]),LongInt(
   H4XSpDelta[0,1]),LongInt(H4XSpDelta[1,0]),LongInt(H4XSpDelta[1,1]),A+1,(LongInt(
   1) Shl (2*A+1))-H4XNoRnd,H4XHEdge,H4XVEdge);
  H4XGmcPlane(Pc^.Y,H4XLY,Cur^.Y,DY+8,H4XLY,16,Ox+LongInt(H4XSpDelta[0,0])*8,Oy+
   LongInt(H4XSpDelta[1,0])*8,LongInt(H4XSpDelta[0,0]),LongInt(H4XSpDelta[0,1]),
   LongInt(H4XSpDelta[1,0]),LongInt(H4XSpDelta[1,1]),A+1,(LongInt(1) Shl (2*A+1))-
   H4XNoRnd,H4XHEdge,H4XVEdge);
  Ox:=LongInt(H4XSpOff[1,0])+LongInt(H4XSpDelta[0,0])*H4XMbX*8+LongInt(H4XSpDelta[0,
   1])*H4XMbY*8;
  Oy:=LongInt(H4XSpOff[1,1])+LongInt(H4XSpDelta[1,0])*H4XMbX*8+LongInt(H4XSpDelta[1,
   1])*H4XMbY*8;
  H4XGmcPlane(Pc^.U,H4XLC,Cur^.U,DC,H4XLC,8,Ox,Oy,LongInt(H4XSpDelta[0,0]),LongInt(
   H4XSpDelta[0,1]),LongInt(H4XSpDelta[1,0]),LongInt(H4XSpDelta[1,1]),A+1,(LongInt(
   1) Shl (2*A+1))-H4XNoRnd,(H4XHEdge+1) Shr 1,(H4XVEdge+1) Shr 1);
  H4XGmcPlane(Pc^.V,H4XLC,Cur^.V,DC,H4XLC,8,Ox,Oy,LongInt(H4XSpDelta[0,0]),LongInt(
   H4XSpDelta[0,1]),LongInt(H4XSpDelta[1,0]),LongInt(H4XSpDelta[1,1]),A+1,(LongInt(
   1) Shl (2*A+1))-H4XNoRnd,(H4XHEdge+1) Shr 1,(H4XVEdge+1) Shr 1);
 End;
End;

{ mpeg_motion_internal (sortie H.263) : un vecteur demi-pel sur les trois
 composantes }
Procedure H4XMpegMotion(Ref,DOffY,DOffC,FB,Bottom,FSel,Mx,My,H: LongInt; NoRnd,
 Avg: Boolean);
Var
 Dxy,UvDxy,SrcX,SrcY,UvX,UvY,Mx2,My2,YStrD,CStrD,RowY,RowC,StepR,I: LongInt; Pc,
  Cur: ^TM4Pic;
Begin
 Pc:=@H4XP[Ref]; Cur:=@H4XP[H4XCurI];
 Dxy:=((My And 1) Shl 1) Or (Mx And 1);
 SrcX:=H4XMbX*16+H4XSar(Mx,1);
 SrcY:=(H4XMbY Shl (4-FB))+H4XSar(My,1);
 If ((H4XBugs And H4X_BUG_HPELCH)<>0) And (FB<>0) Then Begin
  Mx2:=H4XSar(Mx,1) Or (Mx And 1); My2:=H4XSar(My,1);
  UvDxy:=((My2 And 1) Shl 1) Or (Mx2 And 1);
  UvX:=H4XMbX*8+H4XSar(Mx2,1);
  UvY:=(H4XMbY Shl (3-FB))+H4XSar(My2,1);
 End Else Begin
  UvDxy:=Dxy Or (My And 2) Or ((Mx And 2) Shr 1);
  UvX:=H4XSar(SrcX,1); UvY:=H4XSar(SrcY,1);
 End;
 YStrD:=H4XLY Shl FB; CStrD:=H4XLC Shl FB;
 If FB<>0 Then Begin
  RowY:=2*SrcY+FSel; RowC:=2*UvY+FSel; StepR:=2;
 End Else Begin
  RowY:=SrcY; RowC:=UvY; StepR:=1;
 End;
 If Bottom<>0 Then Begin Inc(DOffY,H4XLY); Inc(DOffC,H4XLC); End;
 H4XFetch(Pc^.Y,H4XLY,SrcX,RowY,StepR,17,H+1,H4XHEdge,H4XVEdge);
 H4XHpel(Cur^.Y,DOffY,YStrD,Dxy,16,H,NoRnd,Avg);
 H4XFetch(Pc^.U,H4XLC,UvX,RowC,StepR,9,(H Shr 1)+1,H4XHEdge Shr 1,H4XVEdge Shr 1);
 H4XHpel(Cur^.U,DOffC,CStrD,UvDxy,8,H Shr 1,NoRnd,Avg);
 H4XFetch(Pc^.V,H4XLC,UvX,RowC,StepR,9,(H Shr 1)+1,H4XHEdge Shr 1,H4XVEdge Shr 1);
 H4XHpel(Cur^.V,DOffC,CStrD,UvDxy,8,H Shr 1,NoRnd,Avg);
End;

{ qpel_motion }
Procedure H4XQpelMotion(Ref,DOffY,DOffC,FB,Bottom,FSel,Mx,My,H: LongInt; NoRnd,
 Avg: Boolean);
Var
 Dxy,UvDxy,SrcX,SrcY,UvX,UvY,Cx,Cy,RowY,RowC,StepR,YStrD,CStrD,Mode: LongInt;
  Pc,Cur: ^TM4Pic;
Const RTab: Array[0..7] Of ShortInt=(0,0,1,1,0,0,0,1);
Begin
 Pc:=@H4XP[Ref]; Cur:=@H4XP[H4XCurI];
 If Avg Then Mode:=2 Else If NoRnd Then Mode:=1 Else Mode:=0;
 Dxy:=((My And 3) Shl 2) Or (Mx And 3);
 SrcX:=H4XMbX*16+H4XSar(Mx,2);
 SrcY:=H4XMbY*(16 Shr FB)+H4XSar(My,2);
 YStrD:=H4XLY Shl FB; CStrD:=H4XLC Shl FB;
 If FB<>0 Then Begin
  Cx:=Mx Div 2; Cy:=H4XSar(My,1);
 End Else If (H4XBugs And H4X_BUG_QPELCH2)<>0 Then Begin
  Cx:=H4XSar(Mx,1)+RTab[Mx And 7]; Cy:=H4XSar(My,1)+RTab[My And 7];
 End Else If (H4XBugs And H4X_BUG_QPELCH)<>0 Then Begin
  Cx:=H4XSar(Mx,1) Or (Mx And 1); Cy:=H4XSar(My,1) Or (My And 1);
 End Else Begin
  Cx:=Mx Div 2; Cy:=My Div 2;
 End;
 Cx:=H4XSar(Cx,1) Or (Cx And 1); Cy:=H4XSar(Cy,1) Or (Cy And 1);
 UvDxy:=(Cx And 1) Or ((Cy And 1) Shl 1);
 Cx:=H4XSar(Cx,1); Cy:=H4XSar(Cy,1);
 UvX:=H4XMbX*8+Cx;
 UvY:=H4XMbY*(8 Shr FB)+Cy;
 If FB<>0 Then Begin RowY:=2*SrcY+FSel; RowC:=2*UvY+FSel; StepR:=2; End
 Else Begin RowY:=SrcY; RowC:=UvY; StepR:=1; End;
 If FB=0 Then Begin
  H4XFetch(Pc^.Y,H4XLY,SrcX,RowY,StepR,17,17,H4XHEdge,H4XVEdge);
  H4XQpel(Cur^.Y,DOffY,YStrD,Dxy,16,Mode);
 End Else Begin
  If Bottom<>0 Then Begin Inc(DOffY,H4XLY); Inc(DOffC,H4XLC); End;
  H4XFetch(Pc^.Y,H4XLY,SrcX,RowY,StepR,17,9,H4XHEdge,H4XVEdge);
  H4XQpel(Cur^.Y,DOffY,YStrD,Dxy,8,Mode);
  { second bloc 8x8 : fenetre decalee de 8 colonnes }
  H4XFetch(Pc^.Y,H4XLY,SrcX+8,RowY,StepR,9,9,H4XHEdge,H4XVEdge);
  H4XQpel(Cur^.Y,DOffY+8,YStrD,Dxy,8,Mode);
 End;
 H4XFetch(Pc^.U,H4XLC,UvX,RowC,StepR,9,(H Shr 1)+1,H4XHEdge Shr 1,H4XVEdge Shr 1);
 H4XHpel(Cur^.U,DOffC,CStrD,UvDxy,8,H Shr 1,NoRnd,Avg);
 H4XFetch(Pc^.V,H4XLC,UvX,RowC,StepR,9,(H Shr 1)+1,H4XHEdge Shr 1,H4XVEdge Shr 1);
 H4XHpel(Cur^.V,DOffC,CStrD,UvDxy,8,H Shr 1,NoRnd,Avg);
End;

Function H4XRoundChroma(X: LongInt): LongInt;
Begin H4XRoundChroma:=H4YRoundTab[X And 15]+H4XSar(X,3); End;

{ apply_8x8 + chroma_4mv_motion }
Procedure H4XApply8x8(Dir,Ref,DOffY,DOffC: LongInt; NoRnd,Avg: Boolean);
Var
 I,Mx,My,Mvx,Mvy,Dxy,SrcX,SrcY,Mode,Off: LongInt; Pc,Cur: ^TM4Pic;
Begin
 Pc:=@H4XP[Ref]; Cur:=@H4XP[H4XCurI];
 If Avg Then Mode:=2 Else If NoRnd Then Mode:=1 Else Mode:=0;
 Mx:=0; My:=0;
 For I:=0 To 3 Do Begin
  Mvx:=H4XMv[Dir,I,0]; Mvy:=H4XMv[Dir,I,1];
  Off:=DOffY+(I And 1)*8+(I Shr 1)*8*H4XLY;
  If H4XQuarterS<>0 Then Begin
   Dxy:=((Mvy And 3) Shl 2) Or (Mvx And 3);
   SrcX:=H4XMbX*16+H4XSar(Mvx,2)+(I And 1)*8;
   SrcY:=H4XMbY*16+H4XSar(Mvy,2)+(I Shr 1)*8;
   If SrcX<-16 Then SrcX:=-16 Else If SrcX>H4XW Then SrcX:=H4XW;
   If SrcX=H4XW Then Dxy:=Dxy And Not 3;
   If SrcY<-16 Then SrcY:=-16 Else If SrcY>H4XH Then SrcY:=H4XH;
   If SrcY=H4XH Then Dxy:=Dxy And Not 12;
   H4XFetch(Pc^.Y,H4XLY,SrcX,SrcY,1,9,9,H4XHEdge,H4XVEdge);
   H4XQpel(Cur^.Y,Off,H4XLY,Dxy,8,Mode);
   Mx:=Mx+Mvx Div 2; My:=My+Mvy Div 2;
  End Else Begin
   SrcX:=H4XMbX*16+(I And 1)*8+H4XSar(Mvx,1);
   SrcY:=H4XMbY*16+(I Shr 1)*8+H4XSar(Mvy,1);
   Dxy:=0;
   If SrcX<-16 Then SrcX:=-16 Else If SrcX>H4XW Then SrcX:=H4XW;
   If SrcX<>H4XW Then Dxy:=Dxy Or (Mvx And 1);
   If SrcY<-16 Then SrcY:=-16 Else If SrcY>H4XH Then SrcY:=H4XH;
   If SrcY<>H4XH Then Dxy:=Dxy Or ((Mvy And 1) Shl 1);
   H4XFetch(Pc^.Y,H4XLY,SrcX,SrcY,1,9,9,H4XHEdge,H4XVEdge);
   H4XHpel(Cur^.Y,Off,H4XLY,Dxy,8,8,NoRnd,Avg);
   Mx:=Mx+Mvx; My:=My+Mvy;
  End;
 End;
 { chroma_4mv_motion }
 Mx:=H4XRoundChroma(Mx); My:=H4XRoundChroma(My);
 Dxy:=((My And 1) Shl 1) Or (Mx And 1);
 Mx:=H4XSar(Mx,1); My:=H4XSar(My,1);
 SrcX:=H4XMbX*8+Mx; SrcY:=H4XMbY*8+My;
 If SrcX<-8 Then SrcX:=-8 Else If SrcX>(H4XW Shr 1) Then SrcX:=H4XW Shr 1;
 If SrcX=(H4XW Shr 1) Then Dxy:=Dxy And Not 1;
 If SrcY<-8 Then SrcY:=-8 Else If SrcY>(H4XH Shr 1) Then SrcY:=H4XH Shr 1;
 If SrcY=(H4XH Shr 1) Then Dxy:=Dxy And Not 2;
 H4XFetch(Pc^.U,H4XLC,SrcX,SrcY,1,9,9,H4XHEdge Shr 1,H4XVEdge Shr 1);
 H4XHpel(Cur^.U,DOffC,H4XLC,Dxy,8,8,NoRnd,Avg);
 H4XFetch(Pc^.V,H4XLC,SrcX,SrcY,1,9,9,H4XHEdge Shr 1,H4XVEdge Shr 1);
 H4XHpel(Cur^.V,DOffC,H4XLC,Dxy,8,8,NoRnd,Avg);
End;

{ ff_mpv_motion pour une direction }
Procedure H4XMotion(Dir,Ref,DOffY,DOffC: LongInt; NoRnd,Avg: Boolean);
Var I: LongInt;
Begin
 Case H4XMvType Of
  0: Begin
   If H4XMcSel<>0 Then H4XMcselMotion(Ref,DOffY,DOffC)
   Else If H4XQuarterS<>0 Then H4XQpelMotion(Ref,DOffY,DOffC,0,0,0,H4XMv[Dir,0,0],
    H4XMv[Dir,0,1],16,NoRnd,Avg)
   Else H4XMpegMotion(Ref,DOffY,DOffC,0,0,0,H4XMv[Dir,0,0],H4XMv[Dir,0,1],16,NoRnd,
    Avg);
  End;
  1: H4XApply8x8(Dir,Ref,DOffY,DOffC,NoRnd,Avg);
  2: For I:=0 To 1 Do Begin
   If H4XQuarterS<>0 Then H4XQpelMotion(Ref,DOffY,DOffC,1,I,H4XFieldSel[Dir,I],
    H4XMv[Dir,I,0],H4XMv[Dir,I,1],8,NoRnd,Avg)
   Else H4XMpegMotion(Ref,DOffY,DOffC,1,I,H4XFieldSel[Dir,I],H4XMv[Dir,I,0],H4XMv[
    Dir,I,1],8,NoRnd,Avg);
  End;
 End;
End;

{ ---- dequantification ---- }
Procedure H4XDequantIntra(N: LongInt);
Var I,J,Level,Qmul,Qadd,NC,Q,Dcs: LongInt; Blk: ^TH3Blk; Scan: H4PBuf;
Begin
 Blk:=@H4XBlk[N];
 If N<4 Then Dcs:=H4XYDc Else Dcs:=H4XCDc;
 If N<4 Then Q:=H4XQscale Else Q:=H4XChromaQ;
 If H4XMpegQuant<>0 Then Begin
  Q:=Q Shl 1;
  If H4XAltScan<>0 Then Scan:=@H4YAltV Else Scan:=@H4YZigzag;
  If H4XAltScan<>0 Then NC:=63 Else NC:=H4XBlkLast[N];
  Blk^[0]:=SmallInt(Blk^[0]*Dcs);
  For I:=1 To NC Do Begin
   J:=Scan^[I];
   Level:=Blk^[J];
   If Level<>0 Then Begin
    If Level<0 Then Level:=-((-Level*Q*H4XIntraM[J]) Shr 4) Else Level:=(Level*Q*
     H4XIntraM[J]) Shr 4;
    Blk^[J]:=SmallInt(Level);
   End;
  End;
 End Else Begin
  Qmul:=Q Shl 1;
  Blk^[0]:=SmallInt(Blk^[0]*Dcs);
  Qadd:=(Q-1) Or 1;
  If H4XAcPred<>0 Then NC:=63
  Else If H4XAltScan<>0 Then NC:=H4YAltVRE[H4XBlkLast[N]] Else NC:=H4YRasterEnd[
   H4XBlkLast[N]];
  For I:=1 To NC Do Begin
   Level:=Blk^[I];
   If Level<>0 Then Begin
    If Level<0 Then Level:=Level*Qmul-Qadd Else Level:=Level*Qmul+Qadd;
    Blk^[I]:=SmallInt(Level);
   End;
  End;
 End;
End;

Procedure H4XDequantInterMpeg(N: LongInt);
Var I,J,Level,NC,Q,Sum: LongInt; Blk: ^TH3Blk; Scan: H4PBuf;
Begin
 Blk:=@H4XBlk[N];
 If N<4 Then Q:=H4XQscale Else Q:=H4XChromaQ;
 Q:=Q Shl 1;
 If H4XAltScan<>0 Then Scan:=@H4YAltV Else Scan:=@H4YZigzag;
 If H4XAltScan<>0 Then NC:=63 Else NC:=H4XBlkLast[N];
 Sum:=-1;
 For I:=0 To NC Do Begin
  J:=Scan^[I];
  Level:=Blk^[J];
  If Level<>0 Then Begin
   If Level<0 Then Level:=-((((-Level) Shl 1)+1)*Q*H4XInterM[J] Shr 5) Else
    Level:=((Level Shl 1)+1)*Q*H4XInterM[J] Shr 5;
   Blk^[J]:=SmallInt(Level);
   Sum:=Sum+Level;
  End;
 End;
 Blk^[63]:=SmallInt(Blk^[63] Xor (Sum And 1));
End;


{ ---- IDCT "xvid" (xvididct.c), utilisee quand le flux est identifie comme Xvid
 ---- }
Function H4XW32(X: Int64): LongInt;
Begin H4XW32:=LongInt(X And $FFFFFFFF); End;

Function H4XXvRow(Var R: Array Of SmallInt; Base: LongInt; Const Tab: Array Of
 LongInt; Rnd: LongInt): Boolean;
Var C1,C2,C3,C4,C5,C6,C7,K,A0,A1,A2,A3,B0,B1,B2,B3: LongInt; Left,Right:
 LongInt;
Begin
 C1:=Tab[0]; C2:=Tab[1]; C3:=Tab[2]; C4:=Tab[3]; C5:=Tab[4]; C6:=Tab[5]; C7:=
  Tab[6];
 Right:=R[Base+5] Or R[Base+6] Or R[Base+7];
 Left:=R[Base+1] Or R[Base+2] Or R[Base+3];
 H4XXvRow:=True;
 If (Right Or R[Base+4])=0 Then Begin
  K:=H4XW32(Int64(C4)*R[Base]+Rnd);
  If Left<>0 Then Begin
   A0:=H4XW32(Int64(K)+Int64(C2)*R[Base+2]); A1:=H4XW32(Int64(K)+Int64(C6)*R[Base+
    2]);
   A2:=H4XW32(Int64(K)-Int64(C6)*R[Base+2]); A3:=H4XW32(Int64(K)-Int64(C2)*R[Base+
    2]);
   B0:=H4XW32(Int64(C1)*R[Base+1]+Int64(C3)*R[Base+3]); B1:=H4XW32(Int64(C3)*R[
    Base+1]-Int64(C7)*R[Base+3]);
   B2:=H4XW32(Int64(C5)*R[Base+1]-Int64(C1)*R[Base+3]); B3:=H4XW32(Int64(C7)*R[
    Base+1]-Int64(C5)*R[Base+3]);
   R[Base]:=SmallInt(H4XSar(H4XW32(Int64(A0)+B0),11)); R[Base+1]:=SmallInt(H4XSar(
    H4XW32(Int64(A1)+B1),11));
   R[Base+2]:=SmallInt(H4XSar(H4XW32(Int64(A2)+B2),11)); R[Base+3]:=SmallInt(
    H4XSar(H4XW32(Int64(A3)+B3),11));
   R[Base+4]:=SmallInt(H4XSar(H4XW32(Int64(A3)-B3),11)); R[Base+5]:=SmallInt(
    H4XSar(H4XW32(Int64(A2)-B2),11));
   R[Base+6]:=SmallInt(H4XSar(H4XW32(Int64(A1)-B1),11)); R[Base+7]:=SmallInt(
    H4XSar(H4XW32(Int64(A0)-B0),11));
  End Else Begin
   A0:=H4XSar(K,11);
   If A0<>0 Then Begin
    For K:=0 To 7 Do R[Base+K]:=SmallInt(A0);
   End Else H4XXvRow:=False;
  End;
 End Else If (Left Or Right)=0 Then Begin
  A0:=H4XSar(H4XW32(Int64(Rnd)+Int64(C4)*(R[Base]+R[Base+4])),11);
  A1:=H4XSar(H4XW32(Int64(Rnd)+Int64(C4)*(R[Base]-R[Base+4])),11);
  R[Base]:=SmallInt(A0); R[Base+3]:=SmallInt(A0); R[Base+4]:=SmallInt(A0); R[
   Base+7]:=SmallInt(A0);
  R[Base+1]:=SmallInt(A1); R[Base+2]:=SmallInt(A1); R[Base+5]:=SmallInt(A1); R[
   Base+6]:=SmallInt(A1);
 End Else Begin
  K:=H4XW32(Int64(C4)*R[Base]+Rnd);
  A0:=H4XW32(Int64(K)+Int64(C2)*R[Base+2]+Int64(C4)*R[Base+4]+Int64(C6)*R[Base+
   6]);
  A1:=H4XW32(Int64(K)+Int64(C6)*R[Base+2]-Int64(C4)*R[Base+4]-Int64(C2)*R[Base+
   6]);
  A2:=H4XW32(Int64(K)-Int64(C6)*R[Base+2]-Int64(C4)*R[Base+4]+Int64(C2)*R[Base+
   6]);
  A3:=H4XW32(Int64(K)-Int64(C2)*R[Base+2]+Int64(C4)*R[Base+4]-Int64(C6)*R[Base+
   6]);
  B0:=H4XW32(Int64(C1)*R[Base+1]+Int64(C3)*R[Base+3]+Int64(C5)*R[Base+5]+Int64(
   C7)*R[Base+7]);
  B1:=H4XW32(Int64(C3)*R[Base+1]-Int64(C7)*R[Base+3]-Int64(C1)*R[Base+5]-Int64(
   C5)*R[Base+7]);
  B2:=H4XW32(Int64(C5)*R[Base+1]-Int64(C1)*R[Base+3]+Int64(C7)*R[Base+5]+Int64(
   C3)*R[Base+7]);
  B3:=H4XW32(Int64(C7)*R[Base+1]-Int64(C5)*R[Base+3]+Int64(C3)*R[Base+5]-Int64(
   C1)*R[Base+7]);
  R[Base]:=SmallInt(H4XSar(H4XW32(Int64(A0)+B0),11)); R[Base+1]:=SmallInt(H4XSar(
   H4XW32(Int64(A1)+B1),11));
  R[Base+2]:=SmallInt(H4XSar(H4XW32(Int64(A2)+B2),11)); R[Base+3]:=SmallInt(H4XSar(
   H4XW32(Int64(A3)+B3),11));
  R[Base+4]:=SmallInt(H4XSar(H4XW32(Int64(A3)-B3),11)); R[Base+5]:=SmallInt(H4XSar(
   H4XW32(Int64(A2)-B2),11));
  R[Base+6]:=SmallInt(H4XSar(H4XW32(Int64(A1)-B1),11)); R[Base+7]:=SmallInt(H4XSar(
   H4XW32(Int64(A0)-B0),11));
 End;
End;

Function H4XXvMult(C,X: LongInt; N: LongInt): LongInt;
Begin H4XXvMult:=H4XSar(H4XW32(Int64(C)*(X And $FFFFFFFF)),N); End;

Procedure H4XXvCol(Var R: Array Of SmallInt; Base,Kind: LongInt);
Var Mm0,Mm1,Mm2,Mm3,Mm4,Mm5,Mm6,Mm7,Sp: LongInt;
Const TAN1=$32EC; TAN2=$6A0A; TAN3=$AB0E; SQRT2=$5A82;
Procedure Bf(Var A,B: LongInt; Var Tmp: LongInt);
Begin Tmp:=H4XW32(Int64(A)+B); B:=H4XW32(Int64(A)-B); A:=Tmp; End;
Begin
 Case Kind Of
  8: Begin
   Mm4:=R[Base+56]; Mm5:=R[Base+40]; Mm6:=R[Base+24]; Mm7:=R[Base+8];
   Mm0:=H4XW32(Int64(H4XXvMult(TAN1,Mm4,16))+Mm7);
   Mm1:=H4XW32(Int64(H4XXvMult(TAN1,Mm7,16))-Mm4);
   Mm2:=H4XW32(Int64(H4XXvMult(TAN3,Mm5,16))+Mm6);
   Mm3:=H4XW32(Int64(H4XXvMult(TAN3,Mm6,16))-Mm5);
   Mm7:=H4XW32(Int64(Mm0)+Mm2); Mm4:=H4XW32(Int64(Mm1)-Mm3); Mm0:=H4XW32(Int64(
    Mm0)-Mm2); Mm1:=H4XW32(Int64(Mm1)+Mm3);
   Mm6:=H4XW32(Int64(Mm0)+Mm1); Mm5:=H4XW32(Int64(Mm0)-Mm1);
   Mm5:=H4XW32(2*Int64(H4XXvMult(SQRT2,Mm5,16)));
   Mm6:=H4XW32(2*Int64(H4XXvMult(SQRT2,Mm6,16)));
   Mm1:=R[Base+16]; Mm2:=R[Base+48];
   Mm3:=H4XW32(Int64(H4XXvMult(TAN2,Mm2,16))+Mm1);
   Mm2:=H4XW32(Int64(H4XXvMult(TAN2,Mm1,16))-Mm2);
   Mm0:=R[Base]+R[Base+32]; Mm1:=R[Base]-R[Base+32];
  End;
  4: Begin
   Mm0:=R[Base+8]; Mm2:=R[Base+24];
   Mm1:=H4XXvMult(TAN1,Mm0,16); Mm3:=H4XXvMult(TAN3,Mm2,16);
   Mm7:=H4XW32(Int64(Mm0)+Mm2); Mm4:=H4XW32(Int64(Mm1)-Mm3); Mm0:=H4XW32(Int64(
    Mm0)-Mm2); Mm1:=H4XW32(Int64(Mm1)+Mm3);
   Mm6:=H4XW32(Int64(Mm0)+Mm1); Mm5:=H4XW32(Int64(Mm0)-Mm1);
   Mm6:=H4XW32(2*Int64(H4XXvMult(SQRT2,Mm6,16)));
   Mm5:=H4XW32(2*Int64(H4XXvMult(SQRT2,Mm5,16)));
   Mm0:=R[Base]; Mm1:=Mm0; Mm3:=R[Base+16];
   Mm2:=H4XXvMult(TAN2,Mm3,16);
  End;
  Else Begin
   Mm7:=R[Base+8];
   Mm4:=H4XXvMult(TAN1,Mm7,16);
   Mm6:=H4XW32(Int64(Mm7)+Mm4); Mm5:=H4XW32(Int64(Mm7)-Mm4);
   Mm6:=H4XW32(2*Int64(H4XXvMult(SQRT2,Mm6,16)));
   Mm5:=H4XW32(2*Int64(H4XXvMult(SQRT2,Mm5,16)));
   Mm0:=R[Base]; Mm1:=Mm0; Mm3:=R[Base+16];
   Mm2:=H4XXvMult(TAN2,Mm3,16);
  End;
 End;
 Bf(Mm0,Mm3,Sp);
 Bf(Mm0,Mm7,Sp);
 R[Base]:=SmallInt(H4XSar(Mm0,6)); R[Base+56]:=SmallInt(H4XSar(Mm7,6));
 Bf(Mm3,Mm4,Mm0);
 R[Base+24]:=SmallInt(H4XSar(Mm3,6)); R[Base+32]:=SmallInt(H4XSar(Mm4,6));
 Bf(Mm1,Mm2,Mm0);
 Bf(Mm1,Mm6,Mm0);
 R[Base+8]:=SmallInt(H4XSar(Mm1,6)); R[Base+48]:=SmallInt(H4XSar(Mm6,6));
 Bf(Mm2,Mm5,Mm0);
 R[Base+16]:=SmallInt(H4XSar(Mm2,6)); R[Base+40]:=SmallInt(H4XSar(Mm5,6));
End;

Procedure H4XXvidIdct(Var Blk: TH3Blk);
Const
 T04: Array[0..6] Of LongInt=(22725,21407,19266,16384,12873,8867,4520);
 T17: Array[0..6] Of LongInt=(31521,29692,26722,22725,17855,12299,6270);
 T26: Array[0..6] Of LongInt=(29692,27969,25172,21407,16819,11585,5906);
 T35: Array[0..6] Of LongInt=(26722,25172,22654,19266,15137,10426,5315);
Var I,Rows: LongInt;
Begin
 Rows:=7;
 H4XXvRow(Blk,0,T04,65536);
 H4XXvRow(Blk,8,T17,3597);
 H4XXvRow(Blk,16,T26,2260);
 If H4XXvRow(Blk,24,T35,1203) Then Rows:=Rows Or 8;
 If H4XXvRow(Blk,32,T04,0) Then Rows:=Rows Or $10;
 If H4XXvRow(Blk,40,T35,120) Then Rows:=Rows Or $20;
 If H4XXvRow(Blk,48,T26,512) Then Rows:=Rows Or $40;
 If H4XXvRow(Blk,56,T17,512) Then Rows:=Rows Or $80;
 If (Rows And $F0)<>0 Then Begin For I:=0 To 7 Do H4XXvCol(Blk,I,8); End
 Else If (Rows And 8)<>0 Then Begin For I:=0 To 7 Do H4XXvCol(Blk,I,4); End
 Else Begin For I:=0 To 7 Do H4XXvCol(Blk,I,3); End;
End;

Procedure H4XIdctPut(Var Blk: TH3Blk; Dest: H4PBuf; Off,Stride: LongInt; Add:
 Boolean);
Var X,Y,V: LongInt;
Begin
 If H4XXvidBuild<0 Then Begin H4YIdct(Blk,Dest,Off,Stride,Add); Exit; End;
 H4XXvidIdct(Blk);
 For Y:=0 To 7 Do For X:=0 To 7 Do Begin
  V:=Blk[Y*8+X];
  If Add Then V:=V+Dest^[Off+Y*Stride+X];
  If V<0 Then V:=0 Else If V>255 Then V:=255;
  Dest^[Off+Y*Stride+X]:=V;
 End;
End;

{ ---- reconstruction d'un macrobloc (mpv_reconstruct_mb_internal) ---- }
Procedure H4XRecon;
Var
 Xy,I,DY,DC,DctStr,DctOff,Ref: LongInt; Cur: ^TM4Pic; NoRnd: Boolean;
Begin
 Cur:=@H4XP[H4XCurI];
 Xy:=H4XMbY*H4XMbS+H4XMbX+H4XOff;
 Cur^.Qs^[Xy]:=H4XQscale;
 If H4XMbIntra=0 Then Begin
  If H4XIntraTab^[Xy]<>0 Then H4XCleanIntraEntries;
 End Else H4XIntraTab^[Xy]:=1;
 If H4XSkip<>0 Then Begin H4XSkip:=0; Cur^.Sk^[Xy]:=1; End
 Else If Not Cur^.IsRef Then Cur^.Sk^[Xy]:=1 Else Cur^.Sk^[Xy]:=0;
 DY:=H4XMbY*16*H4XLY+H4XMbX*16;
 DC:=H4XMbY*8*H4XLC+H4XMbX*8;
 DctStr:=H4XLY Shl H4XIDct;
 If H4XIDct<>0 Then DctOff:=H4XLY Else DctOff:=H4XLY*8;
 If H4XMbIntra=0 Then Begin
  NoRnd:=(H4XNoRnd<>0) And (H4XPType<>2);
  If (H4XMvDir And 1)<>0 Then Begin
   H4XMotion(0,H4XLastI,DY,DC,NoRnd,False);
   If (H4XMvDir And 2)<>0 Then H4XMotion(1,H4XNextI,DY,DC,NoRnd,True);
  End Else If (H4XMvDir And 2)<>0 Then H4XMotion(1,H4XNextI,DY,DC,NoRnd,False);
  For I:=0 To 5 Do If H4XBlkLast[I]>=0 Then Begin
   If H4XMpegQuant<>0 Then H4XDequantInterMpeg(I);
   Case I Of
    0: H4XIdctPut(H4XBlk[0],Cur^.Y,DY,DctStr,True);
    1: H4XIdctPut(H4XBlk[1],Cur^.Y,DY+8,DctStr,True);
    2: H4XIdctPut(H4XBlk[2],Cur^.Y,DY+DctOff,DctStr,True);
    3: H4XIdctPut(H4XBlk[3],Cur^.Y,DY+DctOff+8,DctStr,True);
    4: H4XIdctPut(H4XBlk[4],Cur^.U,DC,H4XLC,True);
    5: H4XIdctPut(H4XBlk[5],Cur^.V,DC,H4XLC,True);
   End;
  End;
 End Else Begin
  For I:=0 To 5 Do Begin
   H4XDequantIntra(I);
   Case I Of
    0: H4XIdctPut(H4XBlk[0],Cur^.Y,DY,DctStr,False);
    1: H4XIdctPut(H4XBlk[1],Cur^.Y,DY+8,DctStr,False);
    2: H4XIdctPut(H4XBlk[2],Cur^.Y,DY+DctOff,DctStr,False);
    3: H4XIdctPut(H4XBlk[3],Cur^.Y,DY+DctOff+8,DctStr,False);
    4: H4XIdctPut(H4XBlk[4],Cur^.U,DC,H4XLC,False);
    5: H4XIdctPut(H4XBlk[5],Cur^.V,DC,H4XLC,False);
   End;
  End;
 End;
End;

{ ---- allocation et gestion des images ---- }
Type TM4I64=Array[0..100000000] Of Int64;
Procedure H4XFreeAll;
Var I: LongInt;
Begin
 For I:=0 To 4 Do With H4XP[I] Do Begin
  If Y<>Nil Then Begin FreeMem(Y); Y:=Nil; End;
  If U<>Nil Then Begin FreeMem(U); U:=Nil; End;
  If V<>Nil Then Begin FreeMem(V); V:=Nil; End;
  If Ref<>Nil Then Begin FreeMem(Ref); Ref:=Nil; End;
  If Qs<>Nil Then Begin FreeMem(Qs); Qs:=Nil; End;
  If Sk<>Nil Then Begin FreeMem(Sk); Sk:=Nil; End;
  If Mt<>Nil Then Begin FreeMem(Mt); Mt:=Nil; End;
  If Mv<>Nil Then Begin FreeMem(Mv); Mv:=Nil; End;
  Used:=False; IsRef:=False;
 End;
 For I:=0 To 2 Do Begin
  If H4XDc[I]<>Nil Then Begin FreeMem(H4XDc[I]); H4XDc[I]:=Nil; End;
  If H4XAc[I]<>Nil Then Begin FreeMem(H4XAc[I]); H4XAc[I]:=Nil; End;
 End;
 If H4XIntraTab<>Nil Then Begin FreeMem(H4XIntraTab); H4XIntraTab:=Nil; End;
 If H4XCbpTab<>Nil Then Begin FreeMem(H4XCbpTab); H4XCbpTab:=Nil; End;
 If H4XDirTab<>Nil Then Begin FreeMem(H4XDirTab); H4XDirTab:=Nil; End;
 If H4XPField<>Nil Then Begin FreeMem(H4XPField); H4XPField:=Nil; End;
 H4XCurI:=-1; H4XLastI:=-1; H4XNextI:=-1;
End;

Procedure H4XAlloc;
Var I,YSize,CSize,MbN,MvN,DcN0,DcN1,K: LongInt;
Begin
 H4XFreeAll;
 H4XMbW:=(H4XW+15) Div 16; H4XMbH:=(H4XH+15) Div 16;
 H4XMbS:=H4XMbW+1; H4XB8S:=2*H4XMbW+1; H4XMbNum:=H4XMbW*H4XMbH;
 H4XHEdge:=H4XMbW*16; H4XVEdge:=H4XMbH*16;
 H4XLY:=H4XMbW*16; H4XLC:=H4XMbW*8;
 YSize:=H4XLY*H4XMbH*16; CSize:=H4XLC*H4XMbH*8;
 MbN:=(H4XMbH+3)*H4XMbS+16; H4XTabN:=MbN;
 MvN:=2*(H4XB8S*(2*H4XMbH+3)+2*(H4XB8S+8)+16);
 For I:=0 To 4 Do With H4XP[I] Do Begin
  GetMem(Y,YSize+64); GetMem(U,CSize+64); GetMem(V,CSize+64);
  FillChar(Y^,YSize+64,128); FillChar(U^,CSize+64,128); FillChar(V^,CSize+64,
   128);
  GetMem(Ref,MbN*4); FillChar(Ref^,MbN*4,0);
  GetMem(Qs,MbN); FillChar(Qs^,MbN,0);
  GetMem(Sk,MbN); FillChar(Sk^,MbN,0);
  GetMem(Mt,MbN*4); FillChar(Mt^,MbN*4,0);
  GetMem(Mv,MvN*2); FillChar(Mv^,MvN*2,0);
  Used:=False; IsRef:=False; PType:=0;
 End;
 DcN0:=H4XB8S*(2*H4XMbH+4)+64; DcN1:=H4XMbS*(H4XMbH+4)+64;
 H4XDcN[0]:=DcN0; H4XDcN[1]:=DcN1; H4XDcN[2]:=DcN1;
 For I:=0 To 2 Do Begin
  GetMem(H4XDc[I],H4XDcN[I]*2); GetMem(H4XAc[I],H4XDcN[I]*32);
  For K:=0 To H4XDcN[I]-1 Do H4XDc[I]^[K]:=1024;
  FillChar(H4XAc[I]^,H4XDcN[I]*32,0);
 End;
 GetMem(H4XIntraTab,MbN); FillChar(H4XIntraTab^,MbN,1);
 GetMem(H4XCbpTab,MbN); FillChar(H4XCbpTab^,MbN,0);
 GetMem(H4XDirTab,MbN); FillChar(H4XDirTab^,MbN,0);
 GetMem(H4XPField,MbN*8); FillChar(H4XPField^,MbN*8,0);
 H4XAllocW:=H4XW; H4XAllocH:=H4XH;
End;

Function H4XFindFree: LongInt;
Var I: LongInt;
Begin
 H4XFindFree:=-1;
 For I:=0 To 4 Do If Not H4XP[I].Used Then Begin H4XFindFree:=I; Exit; End;
End;

Procedure H4XGray(I: LongInt);
Begin
 FillChar(H4XP[I].Y^,H4XLY*H4XMbH*16,128);
 FillChar(H4XP[I].U^,H4XLC*H4XMbH*8,128);
 FillChar(H4XP[I].V^,H4XLC*H4XMbH*8,128);
End;

Function H4XFrameStart: Boolean;
Var I,Pic: LongInt;
Begin
 H4XFrameStart:=False;
 H4XSkip:=0;
 If (H4XPType<>2) And (H4XLastI>=0) And (H4XLastI<>H4XNextI) Then H4XP[
  H4XLastI].Used:=False;
 For I:=0 To 4 Do
  If (Not H4XP[I].IsRef) Or ((I<>H4XLastI) And (I<>H4XNextI)) Then H4XP[I].Used:=
   False;
 Pic:=H4XFindFree;
 If Pic<0 Then Exit;
 H4XP[Pic].Used:=True;
 H4XP[Pic].IsRef:=(H4XPType<>2);
 H4XP[Pic].PType:=H4XPType;
 H4XCurI:=Pic;
 If H4XPType<>2 Then Begin
  H4XLastI:=H4XNextI;
  H4XNextI:=Pic;
 End;
 If ((H4XLastI<0) Or Not H4XP[H4XLastI].Used) And (H4XPType<>0) Then Begin
  I:=H4XFindFree; If I<0 Then Exit;
  H4XLastI:=I; H4XP[I].Used:=True; H4XP[I].IsRef:=True; H4XP[I].PType:=1; H4XGray(I);
 End;
 If ((H4XNextI<0) Or Not H4XP[H4XNextI].Used) And (H4XPType=2) Then Begin
  I:=H4XFindFree; If I<0 Then Exit;
  H4XNextI:=I; H4XP[I].Used:=True; H4XP[I].IsRef:=True; H4XP[I].PType:=1;
 End;
 If (H4XBugs And H4X_BUG_EDGE)<>0 Then Begin H4XHEdge:=H4XW; H4XVEdge:=H4XH; End
 Else Begin H4XHEdge:=H4XMbW*16; H4XVEdge:=H4XMbH*16; End;
 H4XFrameStart:=True;
End;

{ ---- boucle de decodage d'une tranche (decode_slice) ---- }
Function H4XDecodeSlice: LongInt;
Var Ret,Qsave,BitsLeft,BitsCount,V: LongInt; Cur: ^TM4Pic;
Begin
 H4XDecodeSlice:=-1;
 Cur:=@H4XP[H4XCurI];
 H4XResyncPos:=H4YPos;
 H4XFirstLine:=1;
 H4XResyncX:=H4XMbX; H4XResyncY:=H4XMbY;
 H4XSetQscale(H4XQscale);
 If H4XPart<>0 Then Begin
  Qsave:=H4XQscale;
  If H4XPartitions<0 Then Exit;
  H4XFirstLine:=1; H4XMbX:=H4XResyncX; H4XMbY:=H4XResyncY;
  H4XSetQscale(Qsave);
 End;
 While H4XMbY<H4XMbH Do Begin
  While H4XMbX<H4XMbW Do Begin
   If (H4XResyncX=H4XMbX) And (H4XResyncY+1=H4XMbY) Then H4XFirstLine:=0;
   H4XMvDir:=1; H4XMvType:=0;
   If H4XPart<>0 Then Ret:=H4XPartitionedMb Else Ret:=H4XDecodeMb;
   If H4XPType<>2 Then H4XUpdateMotion;
   If Ret<0 Then Begin
    If Ret=H4X_SLICE_END Then Begin
     H4XRecon;
     Dec(H4XPadScore);
     Inc(H4XMbX);
     If H4XMbX>=H4XMbW Then Begin H4XMbX:=0; Inc(H4XMbY); End;
     H4XDecodeSlice:=0; Exit;
    End Else Begin
     H4XErr:=True;
     Exit;
    End;
   End;
   H4XRecon;
   Inc(H4XMbX);
  End;
  H4XMbX:=0;
  Inc(H4XMbY);
 End;
 { detection du bug de remplissage }
 If (H4YLeft>=48) And (H4YShow(24)=$4010) And (H4XDataPart=0) Then Inc(H4XPadScore,
  32);
 BitsLeft:=H4YLeft;
 If (BitsLeft>=0) And (BitsLeft<137) And (H4XDataPart=0) Then Begin
  BitsCount:=H4YPos;
  If BitsLeft=0 Then Inc(H4XPadScore,16)
  Else If BitsLeft<>1 Then Begin
   V:=H4YShow(8);
   V:=V Or ($7F Shr (7-(BitsCount And 7)));
   If (V=$7F) And (BitsLeft<=8) Then Dec(H4XPadScore)
   Else If (V=$7F) And (((H4YPos+8) And 8)<>0) And (BitsLeft<=16) Then Inc(
    H4XPadScore,4)
   Else Inc(H4XPadScore);
  End;
 End;
 If (H4XPadScore>-2) And (H4XDataPart=0) Then H4XBugs:=H4XBugs Or H4X_BUG_NOPAD Else
  H4XBugs:=H4XBugs And Not H4X_BUG_NOPAD;
 If (H4XBugs And H4X_BUG_NOPAD)<>0 Then H4XDecodeSlice:=0;
End;

Function H4XResync: LongInt;
Var Left,Pos,Bak,Ret: LongInt;
Begin
 H4XResync:=-1;
 H4YSkip(1); H4YAlign;
 If H4YShow(16)=0 Then Begin
  Pos:=H4YPos;
  Ret:=H4XVideoPacketHeader;
  If Ret>=0 Then Begin H4XResync:=Pos; Exit; End;
 End;
 H4YPos:=H4XResyncPos; H4YAlign;
 Left:=H4YLeft;
 While Left>16+1+5+5 Do Begin
  If H4YShow(16)=0 Then Begin
   Bak:=H4YPos; Pos:=H4YPos;
   Ret:=H4XVideoPacketHeader;
   If Ret>=0 Then Begin H4XResync:=Pos; Exit; End;
   H4YPos:=Bak;
  End;
  H4YSkip(8);
  Dec(Left,8);
 End;
End;

{ ---- en-tete d'image : recherche des codes de debut
 (ff_mpeg4_decode_picture_header) ---- }
Function H4XPictureHeader: LongInt;
Var Start: Int64; V,Prof,Lev,Vol: LongInt;
Begin
 H4XPictureHeader:=-1;
 H4YAlign;
 Start:=$FF; Vol:=0;
 Repeat
  If H4YPos>=H4YSize*8 Then Begin
   If ((H4YSize*8=8) And ((H4XDivxVer>=0) Or (H4XXvidBuild>=0))) Or (H4XCTag='QMP4')
    Then H4XPictureHeader:=H4X_SKIPPED;
   Exit;
  End;
  V:=H4YBits(8);
  Start:=((Start Shl 8) Or V) And $FFFFFFFF;
  If (Start And $FFFFFF00)<>$100 Then Continue;
  If (Start>=$120) And (Start<=$12F) Then Begin
   If Vol<>0 Then Continue;
   Inc(Vol);
   If H4XVolHeader<0 Then Exit;
  End Else If Start=$1B2 Then H4XUserData
  Else If Start=$1B3 Then H4XGopHeader
  Else If Start=$1B0 Then Begin
   Prof:=H4YBits(4); Lev:=H4YBits(4);
   If (Prof=14) And (Lev>0) And (Lev<9) Then H4XUnsup(
    'mpeg4: profil Simple Studio non pris en charge.');
  End Else If Start=$1B5 Then H4XVisualObject
  Else If Start=$1B6 Then Break;
  H4YAlign;
  Start:=$FF;
 Until False;
 If H4XLowDelay<>0 Then ;
 If Not H4XHave Then Exit;
 H4XPictureHeader:=H4XVopHeader;
End;

{ ---- sortie ---- }
Var H4XInTag: String[4];
Procedure H4XEmit(P: LongInt);
Var Mat: LongInt;
Begin
 If H4Stop Then Exit;
 Mat:=0; If H4XH>=720 Then Mat:=1;
 If H4XRange=2 Then Mat:=Mat+2;
 H4ShowYuv(H4XP[P].Y,H4XP[P].U,H4XP[P].V,H4XLY,H4XLC,0,0,H4XW,H4XH,Mat);
 Inc(H4XOutCount);
End;

{ decode un paquet (une image) }
Procedure H4XPacket(Pk: H4PBuf; Len: LongInt);
Var Ret,Slice,PrevX,PrevY: LongInt;
Begin
 H4YBuf:=Pk; H4YSize:=Len; H4YPos:=0;
 FillChar(Pk^[Len],32,0);
 H4XSkippedLast:=False;
 Ret:=H4XPictureHeader;
 If Ret=H4X_SKIPPED Then Begin H4XSkippedLast:=True; Exit; End;
 If Ret<0 Then Exit;
 If (H4XW<=0) Or (H4XH<=0) Or (H4XW>8192) Or (H4XH>8192) Then Exit;
 If (H4XW<>H4XAllocW) Or (H4XH<>H4XAllocH) Then Begin H4XAlloc; H4XPicHave:=False;
  End;
 If (H4XPType<>2) And (H4XMbNum Div 2>H4YLeft) Then Exit;
 H4XWorkaround;
 If (H4XLastI<0) And (H4XPType=2) Then Exit;
 If Not H4XFrameStart Then Exit;
 H4XPicHave:=True; H4XP[H4XCurI].Time:=H4XTime;
 H4XMbX:=0; H4XMbY:=0; H4XErr:=False;
 Slice:=H4XDecodeSlice;
 While H4XMbY<H4XMbH Do Begin
  PrevX:=H4XMbX; PrevY:=H4XMbY;
  If H4XResync<0 Then Break;
  H4XCleanBuffers;
  If H4XDecodeSlice<0 Then Slice:=-1;
 End;
 If (H4XPType=2) Or (H4XLowDelay<>0) Then H4XEmit(H4XCurI)
 Else If H4XLastI>=0 Then H4XEmit(H4XLastI);
 H4XP[H4XCurI].PType:=H4XPType;
End;

Procedure H4XReset;
Var Ix: LongInt;
Begin
 H4XInit:=False; H4XInitTables;
 H4XHave:=False; H4XW:=0; H4XH:=0; H4XAllocW:=-1; H4XAllocH:=-1;
 H4XCurI:=-1; H4XLastI:=-1; H4XNextI:=-1;
 H4XDivxVer:=-1; H4XDivxBuild:=-1; H4XXvidBuild:=-1; H4XLavcBuild:=-1; H4XBugs:=1;
  H4XPadScore:=0; H4XDivxPacked:=False; H4XCTag:=H4XInTag;
 H4XVoType:=0; H4XShape:=0; H4XTIncBits:=4; H4XRes:=25; H4XFixedRate:=1; H4XProg:=1;
  H4XSprUsage:=0; H4XNumWarp:=0; H4XWarpAcc:=0;
 H4XBrightChg:=0; H4XQuantPrec:=5; H4XMpegQuant:=0; H4XQuarterS:=0; H4XDataPart:=0;
  H4XRvlc:=0; H4XResyncMarker:=1; H4XNewPred:=0; H4XScal:=0;
 H4XEnhType:=0; H4XLowDelay:=0; H4XVolCtl:=0; H4XCplxI:=0; H4XCplxP:=0; H4XCplxB:=0;
  H4XSarN:=0; H4XSarD:=1; H4XRange:=0;
 H4XTime:=0; H4XTimeBase:=0; H4XLastTimeBase:=0; H4XLastNonBTime:=0; H4XPPTime:=0;
  H4XPBTime:=0; H4XTFrame:=0; H4XPPField:=0; H4XPBField:=0;
 H4XPicNum:=0; H4XPType:=0; H4XPart:=0; H4XNoRnd:=0; H4XTff:=0; H4XAltScan:=0;
  H4XIDct:=0;
 FillChar(H4XSpOff,SizeOf(H4XSpOff),0); FillChar(H4XSpDelta,SizeOf(H4XSpDelta),0);
  H4XRealWarp:=0;
 H4XDefaultMatrices;
 H4XOutBuf:=Nil; H4XOutBegun:=0; H4XOutCount:=0; H4XSkippedLast:=False; H4XPicHave:=
  False;
 FillChar(H4XDc,SizeOf(H4XDc),0); FillChar(H4XAc,SizeOf(H4XAc),0);
 H4XIntraTab:=Nil; H4XCbpTab:=Nil; H4XDirTab:=Nil; H4XPField:=Nil;
 FillChar(H4XP,SizeOf(H4XP),0);
  H4YLongVec:=0;
 For Ix:=0 To 31 Do Begin H4XYDcT[Ix]:=H4XYDcScale[Ix]; H4XCDcT[Ix]:=H4XCDcScale[
  Ix]; End;
 H4XMs:=0; H4XCodedBlk:=Nil;
End;


Type
 H4PTrk=^TH4Trk;

{ ---- acces au fichier source par blocs (pas de chargement integral) ---- }
Var
 H4Fh: File; H4FIsOpen: Boolean; H4FSize: Int64;
 H4Io: H4PBuf; H4IoCap: LongInt;           { tampon de paquet }

Function H4FOpenRead(Const FN: String): Boolean;
Begin
 H4FOpenRead:=False; H4FIsOpen:=False; H4FSize:=0;
 Assign(H4Fh,FN);
 FileMode:=0;
 Reset(H4Fh,1);
 If IOResult<>0 Then Exit;
 H4FSize:=FileSize(H4Fh);
 If IOResult<>0 Then Begin Close(H4Fh); If IOResult<>0 Then ; Exit; End;
 H4FIsOpen:=True; H4FOpenRead:=True;
End;

Procedure H4FClose;
Begin
 If H4FIsOpen Then Begin Close(H4Fh); If IOResult<>0 Then ; End;
 H4FIsOpen:=False;
 If H4Io<>Nil Then FreeMem(H4Io,H4IoCap);
 H4Io:=Nil; H4IoCap:=0;
End;

{ lit N octets a la position Off ; retourne le nombre d'octets lus }
Function H4ReadAt(Off: Int64; Var Buf; N: LongInt): LongInt;
Var G: LongInt;
Begin
 H4ReadAt:=0;
 If (Not H4FIsOpen) Or (Off<0) Or (N<=0) Or (Off>=H4FSize) Then Exit;
 Seek(H4Fh,Off);
 If IOResult<>0 Then Exit;
 G:=0; BlockRead(H4Fh,Buf,N,G);
 If IOResult<>0 Then G:=0;
 H4ReadAt:=G;
End;

{ s'assure que le tampon de paquet fait au moins N octets }
Function H4IoNeed(N: LongInt): Boolean;
Begin
 H4IoNeed:=False;
 If (N<0) Or (N>200000000) Then Exit;
 If H4IoCap<N+64 Then Begin
  If H4Io<>Nil Then FreeMem(H4Io,H4IoCap);
  H4Io:=Nil; H4IoCap:=0;
  GetMem(H4Io,N+64+(N Shr 3)); H4IoCap:=N+64+(N Shr 3);
 End;
 H4IoNeed:=True;
End;

Function H4B32(Const B; At: LongInt): Int64;  { entier 32 bits grand-boutiste }
Var P: H4PBuf;
Begin
 P:=H4PBuf(@B);
 H4B32:=Int64(P^[At])*16777216+Int64(P^[At+1])*65536+Int64(P^[At+2])*256+Int64(
  P^[At+3]);
End;

Function H4L32(Const B; At: LongInt): Int64;  { entier 32 bits petit-boutiste }
Var P: H4PBuf;
Begin
 P:=H4PBuf(@B);
 H4L32:=Int64(P^[At])+Int64(P^[At+1])*256+Int64(P^[At+2])*65536+Int64(
  P^[At+3])*16777216;
End;

Procedure H4Progress(Pos: Int64);
Begin
 If H4FSize>0 Then ConfProgress(Pos Shr 10,H4FSize Shr 10);
End;


{ ---- aide MPEG-4 partie 2 : alimentation, esds, balises AVI ---- }
Const
 H4XTags4: String='|XVID|FMP4|DIVX|DX50|MP4S|H4ZS2|MP4V|UMP4|WV1F|SEDG|RMP4|3IV2|'+
  'WAWV|FFDS|FVFW|DCOD|MVXM|PM4V|SMP4|DXGM|VIDM|H4ZT3|GEOX|HDX4|DM4V|DMK2|DYM4|'+
  'DIGI|EPHV|EM4A|H4ZCC|SN40|VSPX|ULDX|GEOV|SIPP|SM4V|XVIX|DVX1|BLZ0|ZMP4|QMP4|';
 H4XMaxChunk=150000000;

Function H4XTag4(Const T0: String): Boolean;
Var T: String; K: LongInt;
Begin
 T:=T0; For K:=1 To Length(T) Do T[K]:=UpCase(T[K]);
 H4XTag4:=(Length(T)=4) And (Pos('|'+T+'|',H4XTags4)>0);
End;

Function H4AviMatch(Const Fcc: String; Codec: LongInt): Boolean;
Begin
 If Codec=0 Then H4AviMatch:=H4AviIsH264(Fcc) Else H4AviMatch:=H4XTag4(Fcc);
End;

Var H4XChunk: H4PBuf; H4XChunkCap: LongInt;

{ decode un paquet MPEG-4 : decoupe aux codes de debut de VOP (000001B6) ;
 le contenu est copie car le decodeur ecrit apres la fin du tampon }
Procedure H4XRun(F: H4PBuf; S,E: LongInt);
Begin
 If (E<=S) Or H4Stop Then Exit;
 If H4XChunkCap<E-S+64 Then Begin
  If H4XChunk<>Nil Then FreeMem(H4XChunk,H4XChunkCap);
  H4XChunk:=Nil; H4XChunkCap:=0;
  GetMem(H4XChunk,E-S+4096); H4XChunkCap:=E-S+4096;
 End;
 Move(F^[S],H4XChunk^[0],E-S);
 FillChar(H4XChunk^[E-S],48,0);
 H4XPacket(H4XChunk,E-S);
End;

Procedure H4XFeed(F: H4PBuf; Size: LongInt);
Var Start,I,P,Q: LongInt; Found: Boolean;
Begin
 Start:=0; I:=0;
 While (I<Size) And (Not H4Stop) Do Begin
  Found:=False; P:=I;
  While P+3<Size Do Begin
   If (F^[P]=0) And (F^[P+1]=0) And (F^[P+2]=1) And (F^[P+3]=$B6) Then Begin
    Found:=True; Break; End;
   Inc(P);
  End;
  If Not Found Then Break;
  Q:=P+4; Found:=False;
  While Q+3<Size Do Begin
   If (F^[Q]=0) And (F^[Q+1]=0) And (F^[Q+2]=1) And (F^[Q+3]<>$B7) And (F^[Q+
    3]<>$B8) Then Begin Found:=True; Break; End;
   Inc(Q);
  End;
  If Not Found Then Q:=Size;
  H4XRun(F,Start,Q);
  Start:=Q; I:=Q;
 End;
 If (Not H4Stop) And (Start<Size) And (I<Size) Then H4XRun(F,Start,Size);
End;

Procedure H4XFlush;
Begin
 If Not H4Stop Then Begin
  If (H4XLowDelay=0) And (H4XNextI>=0) And H4XPicHave Then H4XEmit(H4XNextI)
  Else If H4XSkippedLast And H4XPicHave And (H4XCurI>=0) Then H4XEmit(H4XCurI);
 End;
End;

Procedure H4XFree;
Begin
 H4XFreeAll;
 If H4XChunk<>Nil Then FreeMem(H4XChunk,H4XChunkCap);
 H4XChunk:=Nil; H4XChunkCap:=0;
End;

{ lit un descripteur MPEG-4 (tag + longueur variable) }
Function H4XDesc(Var P: LongInt; Fin: LongInt; Var Tag,Len: LongInt): Boolean;
Var K,B: LongInt;
Begin
 H4XDesc:=False;
 If P+2>Fin Then Exit;
 Tag:=H4ZF^[P]; Inc(P); Len:=0;
 For K:=1 To 4 Do Begin
  If P>=Fin Then Exit;
  B:=H4ZF^[P]; Inc(P);
  Len:=(Len Shl 7) Or (B And $7F);
  If (B And $80)=0 Then Break;
 End;
 H4XDesc:=True;
End;

{ esds -> DecoderSpecificInfo (en-tete VOL) alimente le decodeur }
Procedure H4XFeedEsds(E0,Len: LongInt);
Var P,Fin,Tag,L,Fl: LongInt; Cp: H4PBuf;
Begin
 P:=E0+4; Fin:=E0+Len; If Fin>H4ZSize Then Fin:=H4ZSize;
 If Not H4XDesc(P,Fin,Tag,L) Then Exit;
 If Tag<>3 Then Exit;
 Inc(P,2); If P>=Fin Then Exit;
 Fl:=H4ZF^[P]; Inc(P);
 If (Fl And $80)<>0 Then Inc(P,2);
 If (Fl And $40)<>0 Then Begin If P>=Fin Then Exit; Inc(P,H4ZF^[P]+1); End;
 If (Fl And $20)<>0 Then Inc(P,2);
 If Not H4XDesc(P,Fin,Tag,L) Then Exit;
 If Tag<>4 Then Exit;
 Inc(P,13);
 If Not H4XDesc(P,Fin,Tag,L) Then Exit;
 If (Tag<>5) Or (L<=0) Or (P+L>Fin) Or (L>65536) Then Exit;
 GetMem(Cp,L+64);
 Move(H4ZF^[P],Cp^[0],L);
 FillChar(Cp^[L],64,0);
 H4XFeed(Cp,L);
 FreeMem(Cp,L+64);
End;

{ ---- MP4 / MOV ---- }
Function H4Mp4Load: Boolean;  { charge la boite moov dans H4ZF }
Var At: Int64; Hd: Array[0..15] Of Byte; Sz: Int64; Hdr,G: LongInt;
 Cnt: LongInt;
Begin
 H4Mp4Load:=False; H4ZF:=Nil; H4ZSize:=0;
 At:=0; Cnt:=0;
 While (At+8<=H4FSize) And (Cnt<100000) Do Begin
  Inc(Cnt);
  FillChar(Hd,SizeOf(Hd),0);
  G:=H4ReadAt(At,Hd,16);
  If G<8 Then Exit;
  Sz:=H4B32(Hd,0); Hdr:=8;
  If Sz=1 Then Begin
   Sz:=H4B32(Hd,8)*4294967296+H4B32(Hd,12); Hdr:=16;
  End Else If Sz=0 Then Sz:=H4FSize-At;
  If Sz<Hdr Then Exit;
  If (Hd[4]=Ord('m')) And (Hd[5]=Ord('o')) And (Hd[6]=Ord('o')) And (
   Hd[7]=Ord('v')) Then Begin
   If At+Sz>H4FSize Then Sz:=H4FSize-At;
   If (Sz>300000000) Or (Sz<16) Then Exit;
   H4ZSize:=Sz;
   GetMem(H4ZF,H4ZSize+64); FillChar(H4ZF^[H4ZSize],64,0);
   If H4ReadAt(At,H4ZF^[0],H4ZSize)<>H4ZSize Then Begin
    FreeMem(H4ZF,H4ZSize+64); H4ZF:=Nil; H4ZSize:=0; Exit;
   End;
   H4Mp4Load:=True; Exit;
  End;
  At:=At+Sz;
 End;
End;

Procedure H4Mp4Free;
Begin
 If H4ZF<>Nil Then FreeMem(H4ZF,H4ZSize+64);
 H4ZF:=Nil; H4ZSize:=0;
End;

{ analyse de moov ; retourne l'indice de la premiere piste video avc1/avc3 }
Function H4Mp4Tracks(Codec: LongInt): LongInt;
Var A0,A1,B0,B1,Nx,I: LongInt;
Begin
 H4Mp4Tracks:=-1; H4ZNT:=0;
 If Not H4ZFind(0,H4ZSize,'moov',A0,A1,Nx) Then Exit;
 If H4ZFind(A0,A1,'mvhd',B0,B1,Nx) Then Begin
  If H4ZF^[B0]=1 Then H4ZMovieTs:=H4ZU32(B0+20) Else H4ZMovieTs:=H4ZU32(B0+12);
 End;
 Nx:=A0;
 While H4ZFind(Nx,A1,'trak',B0,B1,Nx) Do H4ZParseTrak(B0,B1);
 For I:=0 To H4ZNT-1 Do
  If (H4ZTrk[I].Kind=1) And (((Codec=0) And ((H4ZTrk[I].Fcc='avc1') Or (
   H4ZTrk[I].Fcc='avc3'))) Or ((Codec=1) And (H4ZTrk[I].Fcc='mp4v'))) Then
   Begin H4Mp4Tracks:=I; Exit; End;
End;

Function H4Mp4Probe(Codec: LongInt): Boolean;
Var Sel: LongInt;
Begin
 H4Mp4Probe:=False;
 If Not H4Mp4Load Then Exit;
 Sel:=H4Mp4Tracks(Codec);
 If Sel>=0 Then
  H4Mp4Probe:=((Codec=0) And (H4ZTrk[Sel].Avcc>=0)) Or (Codec=1);
 H4Mp4Free;
End;


{ MP4 fragmente (moof / traf / tfhd / trun) : echantillons dans l'ordre du
 fichier ; T = piste video choisie (tables de moov deja chargees dans H4ZF) }
Function H4Mp4DecodeFrag(T: H4PTrk): Boolean;
Var At,Sz,Base,DataPos: Int64; Hd: Array[0..15] Of Byte; Hdr,G,NalSz,Tid,Cnt,
 Iter,MfSize,A0,A1,B0,B1,C0,C1,D0,D1,Ni,Nj,Nx,P,Fl,Fl2,I,Ssz,Dsz,DefSz,Dur,
 DefDur,FDur,SaveSz,Bad: LongInt; Mf,SaveF: H4PBuf; Dpos: Int64;
Begin
 H4Mp4DecodeFrag:=False;
 NalSz:=H4FeedAvcc(H4PBuf(@H4ZF^[T^.Avcc]),T^.AvccLen);
 DefSz:=0; DefDur:=0;
 If H4ZFind(0,H4ZSize,'moov',A0,A1,Nx) Then
  If H4ZFind(A0,A1,'mvex',B0,B1,Nx) Then Begin
   Ni:=B0;
   While H4ZFind(Ni,B1,'trex',C0,C1,Ni) Do
    If H4ZU32(C0+4)=T^.TrackId Then Begin
     DefDur:=H4ZL32(C0+12); DefSz:=H4ZL32(C0+16); End;
  End;
 SaveF:=H4ZF; SaveSz:=H4ZSize;
 At:=0; Iter:=0; FDur:=0; Bad:=0;
 While (At+8<=H4FSize) And (Iter<10000000) And (Not H4Stop) Do Begin
  Inc(Iter);
  FillChar(Hd,SizeOf(Hd),0);
  G:=H4ReadAt(At,Hd,16);
  If G<8 Then Break;
  Sz:=H4B32(Hd,0); Hdr:=8;
  If Sz=1 Then Begin Sz:=H4B32(Hd,8)*4294967296+H4B32(Hd,12); Hdr:=16; End
  Else If Sz=0 Then Sz:=H4FSize-At;
  If Sz<Hdr Then Break;
  If (Hd[4]=Ord('m')) And (Hd[5]=Ord('o')) And (Hd[6]=Ord('o')) And (
   Hd[7]=Ord('f')) And (Sz<=64000000) And (At+Sz<=H4FSize) Then Begin
   MfSize:=Sz;
   GetMem(Mf,MfSize+64); FillChar(Mf^[MfSize],64,0);
   If H4ReadAt(At,Mf^[0],MfSize)=MfSize Then Begin
    H4ZF:=Mf; H4ZSize:=MfSize;
    If H4ZFind(0,MfSize,'moof',A0,A1,Nx) Then Begin
     Ni:=A0;
     While H4ZFind(Ni,A1,'traf',B0,B1,Ni) And (Not H4Stop) Do
      If H4ZFind(B0,B1,'tfhd',C0,C1,Nx) Then Begin
       Fl:=H4ZU32(C0) And $FFFFFF; Tid:=H4ZU32(C0+4); P:=C0+8;
       Base:=At; Dsz:=DefSz; Dur:=DefDur;
       If (Fl And 1)<>0 Then Begin Base:=H4ZU64(P); Inc(P,8); End;
       If (Fl And 2)<>0 Then Inc(P,4);
       If (Fl And 8)<>0 Then Begin Dur:=H4ZL32(P); Inc(P,4); End;
       If (Fl And $10)<>0 Then Begin Dsz:=H4ZL32(P); Inc(P,4); End;
       If Tid=T^.TrackId Then Begin
        DataPos:=Base;
        Nj:=B0;
        While H4ZFind(Nj,B1,'trun',D0,D1,Nj) And (Not H4Stop) Do Begin
         Fl2:=H4ZU32(D0) And $FFFFFF; Cnt:=H4ZL32(D0+4); P:=D0+8;
         If Cnt>1000000 Then Cnt:=1000000;
         If (Fl2 And 1)<>0 Then Begin DataPos:=Base+H4ZS32(P); Inc(P,4); End;
         If (Fl2 And 4)<>0 Then Inc(P,4);
         For I:=1 To Cnt Do Begin
          If P>MfSize Then Break;
          Ssz:=Dsz;
          If (Fl2 And $100)<>0 Then Begin
           If FDur=0 Then FDur:=H4ZL32(P);
           Inc(P,4); End Else If FDur=0 Then FDur:=Dur;
          If (Fl2 And $200)<>0 Then Begin Ssz:=H4ZL32(P); Inc(P,4); End;
          If (Fl2 And $400)<>0 Then Inc(P,4);
          If (Fl2 And $800)<>0 Then Inc(P,4);
          If (H4Fps100=0) And (FDur>0) And (T^.Ts>0) Then Begin
           H4Fps100:=(Int64(T^.Ts)*100+FDur Div 2) Div FDur;
           If (H4Fps100<100) Or (H4Fps100>30000) Then H4Fps100:=0;
          End;
          If (Ssz>NalSz) And (Ssz<=150000000) And (DataPos>=0) And (
           DataPos+Ssz<=H4FSize) Then Begin
           If H4IoNeed(Ssz) Then Begin
            If H4ReadAt(DataPos,H4Io^[0],Ssz)=Ssz Then
             H4FeedNalPacket(H4Io,Ssz,NalSz,0);
           End;
          End;
          If Ssz>0 Then DataPos:=DataPos+Ssz;
          If H4Stop Then Break;
         End;
        End;
       End;
      End;
    End;
    H4ZF:=SaveF; H4ZSize:=SaveSz;
   End;
   FreeMem(Mf,MfSize+64);
  End;
  At:=At+Sz;
  H4Progress(At);
 End;
 H4ZF:=SaveF; H4ZSize:=SaveSz;
 If Not H4Stop Then Begin H4FinishPicture; H4Bump(True); End;
 H4Mp4DecodeFrag:=H4FramesOut>0;
End;

Function H4Mp4Decode(Codec: LongInt): Boolean;
Var
 Sel,I,J,K,N,Cnt,V,Npk,Si,Spc,SscI,Pos,NalSz,Chunk,Mx,Nc: LongInt;
 SOff: H4PI64; SSz: H4PLN;
 T: ^TH4Trk; Cur: Int64; SumDur: Int64; Mp: H4PBuf; Ok: Boolean;
 Lim: Int64;
Begin
 H4Mp4Decode:=False; SOff:=Nil; SSz:=Nil;
 If Not H4Mp4Load Then Exit;
 Sel:=H4Mp4Tracks(Codec);
 If Sel<0 Then Begin H4Mp4Free; Exit; End;
 T:=@H4ZTrk[Sel];
 If (Codec=0) And (T^.Avcc>=0) And (T^.AvccLen>=7) And ((T^.SzN<=0) Or (
  T^.Stsz<0)) Then Begin
  H4Mp4Decode:=H4Mp4DecodeFrag(T); H4Mp4Free; Exit;
 End;
 If ((Codec=0) And ((T^.Avcc<0) Or (T^.AvccLen<7))) Or (T^.Stts<0) Or (
  T^.Stsz<0) Or (T^.Stsc<0) Or (T^.Stco<0) Or (T^.Ts<=0) Then Begin
  H4Mp4Free; Exit; End;
 Npk:=T^.SzN;
 If (Npk<=0) Or (Npk>8000000) Then Begin H4Mp4Free; Exit; End;
 If T^.FixedSz=0 Then Begin
  Lim:=(H4ZSize-T^.Stsz) Div 4; If Npk>Lim Then Npk:=Lim;
 End;
 Lim:=(H4ZSize-T^.Stsc) Div 12; If T^.ScN>Lim Then T^.ScN:=Lim;
 If T^.Co64 Then Lim:=(H4ZSize-T^.Stco) Div 8 Else Lim:=(H4ZSize-T^.Stco) Div 4;
 If T^.CoN>Lim Then T^.CoN:=Lim;
 Lim:=(H4ZSize-T^.Stts) Div 8; If T^.SttsN>Lim Then T^.SttsN:=Lim;
 If (Npk<=0) Or (T^.ScN<=0) Or (T^.CoN<=0) Then Begin H4Mp4Free; Exit; End;
 GetMem(SOff,Npk*8+16); GetMem(SSz,Npk*4+16);
 For I:=0 To Npk-1 Do
  If T^.FixedSz<>0 Then SSz^[I]:=T^.FixedSz Else SSz^[I]:=H4ZS32(T^.Stsz+I*4);
 { positions : chunks }
 Si:=0; SscI:=0;
 For Chunk:=1 To T^.CoN Do Begin
  While (SscI+1<T^.ScN) And (H4ZU32(T^.Stsc+(SscI+1)*12)<=Chunk) Do Inc(SscI);
  Spc:=H4ZU32(T^.Stsc+SscI*12+4);
  If T^.Co64 Then Cur:=H4ZU64(T^.Stco+(Chunk-1)*8) Else Cur:=H4ZU32(T^.Stco+(
   Chunk-1)*4);
  For J:=1 To Spc Do Begin
   If Si>=Npk Then Break;
   SOff^[Si]:=Cur; If SSz^[Si]>0 Then Inc(Cur,SSz^[Si]); Inc(Si);
  End;
  If Si>=Npk Then Break;
 End;
 If Si<Npk Then Npk:=Si;
 { cadence moyenne }
 SumDur:=0; Si:=0;
 For N:=0 To T^.SttsN-1 Do Begin
  Cnt:=H4ZU32(T^.Stts+N*8); V:=H4ZU32(T^.Stts+N*8+4);
  If Si+Cnt>Npk Then Cnt:=Npk-Si;
  If Cnt<=0 Then Break;
  SumDur:=SumDur+Int64(Cnt)*V; Inc(Si,Cnt);
 End;
 If (SumDur>0) And (Si>0) Then
  H4Fps100:=(Int64(T^.Ts)*Si*100+SumDur Div 2) Div SumDur;
 If (H4Fps100<100) Or (H4Fps100>30000) Then H4Fps100:=0;
 { SPS / PPS de avcC }
 NalSz:=0;
 If Codec=0 Then Begin
  Mp:=H4PBuf(@H4ZF^[T^.Avcc]);
  NalSz:=H4FeedAvcc(Mp,T^.AvccLen);
 End Else If T^.Esds>=0 Then H4XFeedEsds(T^.Esds,T^.EsdsLen);
 { echantillons }
 Mx:=0;
 For I:=0 To Npk-1 Do If SSz^[I]>Mx Then Mx:=SSz^[I];
 If Mx>150000000 Then Mx:=150000000;
 Ok:=H4IoNeed(Mx);
 If Ok Then
  For I:=0 To Npk-1 Do Begin
   If (SSz^[I]<=NalSz) Or (SSz^[I]>Mx) Or (SSz^[I]<=0) Then Continue;
   If SOff^[I]+SSz^[I]>H4FSize Then Break;
   If H4ReadAt(SOff^[I],H4Io^[0],SSz^[I])<>SSz^[I] Then Break;
   If Codec=0 Then H4FeedNalPacket(H4Io,SSz^[I],NalSz,0)
   Else H4XFeed(H4Io,SSz^[I]);
   If H4Stop Then Break;
   If (I And 63)=0 Then H4Progress(SOff^[I]);
  End;
 If Codec=0 Then Begin
  If Not H4Stop Then Begin H4FinishPicture; H4Bump(True); End;
 End Else H4XFlush;
 FreeMem(SOff,Npk*8+16); FreeMem(SSz,Npk*4+16);
 H4Mp4Free;
 H4Mp4Decode:=H4FramesOut>0;
End;

{ ---- FLV ---- }
{ Scan=True : sonde et pre-analyse (cadence) ; False : decodage }
Function H4FlvRun(Scan: Boolean): Boolean;
Var Hd: Array[0..15] Of Byte; At: Int64; Kind,N,I,K,Tags,NalSz,Nv: LongInt;
 Ts,Ts0,TsL: Int64; Got: LongInt; Bits: Int64; Fps: Double; HaveV,Avc: Boolean;
Begin
 H4FlvRun:=False; Nv:=0; Ts0:=0; TsL:=0; Fps:=0; HaveV:=False; Avc:=False;
 If H4ReadAt(0,Hd,9)<9 Then Exit;
 If (Hd[0]<>70) Or (Hd[1]<>76) Or (Hd[2]<>86) Or (Hd[3]<>1) Then Exit;
 At:=Int64(Hd[5])*16777216+Hd[6]*65536+Hd[7]*256+Hd[8];
 At:=At+4; NalSz:=4; Tags:=0;
 While At+11<=H4FSize Do Begin
  If Scan And (Tags>600) Then Break;
  Inc(Tags);
  If H4ReadAt(At,Hd,16)<12 Then Break;
  Kind:=Hd[0]; N:=Hd[1]*65536+Hd[2]*256+Hd[3];
  Ts:=Int64(Hd[4])*65536+Hd[5]*256+Hd[6]+Int64(Hd[7])*16777216;
  If At+11+N>H4FSize Then Break;
  If Kind=9 Then Begin
   If N>=5 Then Begin
    If (Hd[11] And 15)<>7 Then Begin
     If Scan And (Not Avc) Then Exit;   { codec video autre que H.264 }
    End Else Begin
     Avc:=True;
     If Scan Then Begin
      If Hd[12]=1 Then Begin
       If Nv=0 Then Ts0:=Ts; TsL:=Ts; Inc(Nv);
      End;
     End Else If (N>5) And ((Hd[11] Shr 4)<>5) Then Begin
      If H4IoNeed(N) Then Begin
       If H4ReadAt(At+16,H4Io^[0],N-5)<>N-5 Then Break;
       If Hd[12]=0 Then NalSz:=H4FeedAvcc(H4Io,N-5)
       Else If Hd[12]=1 Then H4FeedNalPacket(H4Io,N-5,NalSz,0);
       If H4Stop Then Break;
      End Else Break;
     End;
    End;
   End;
  End Else If Scan And (Kind=18) And (N>=24) Then Begin
   K:=N; If K>1500 Then K:=1500;
   If H4IoNeed(K) Then
    If H4ReadAt(At+11,H4Io^[0],K)=K Then
     For I:=0 To K-21 Do
      If (H4Io^[I]=0) And (H4Io^[I+1]=9) And (H4Io^[I+2]=102) And (H4Io^[I+3]=
       114) And (H4Io^[I+4]=97) And (H4Io^[I+5]=109) And (H4Io^[I+6]=101) And (
       H4Io^[I+7]=114) And (H4Io^[I+8]=97) And (H4Io^[I+9]=116) And (H4Io^[
       I+10]=101) And (H4Io^[I+11]=0) Then Begin
       Bits:=0; For Got:=0 To 7 Do Bits:=Bits*256+H4Io^[I+12+Got];
       Move(Bits,Fps,8);
       Break;
      End;
  End;
  If (Not Scan) And ((Tags And 63)=0) Then H4Progress(At);
  At:=At+11+N+4;
 End;
 If Scan Then Begin
  H4FlvRun:=Avc;
  If (Fps>=1) And (Fps<=300) Then H4Fps100:=Round(Fps*100)
  Else If (Nv>=3) And (TsL>Ts0) Then Begin
   Fps:=(Nv-1)*1000.0/(TsL-Ts0);
   If (Fps>=1) And (Fps<=300) Then H4Fps100:=Round(Fps*100);
  End;
 End Else Begin
  If Not H4Stop Then Begin H4FinishPicture; H4Bump(True); End;
  H4FlvRun:=H4FramesOut>0;
 End;
End;

{ ---- AVI ---- }
{ Probe=True : seulement verifier que le flux video est H.264 }
Function H4AviRun(Probe: Boolean; Codec: LongInt): Boolean;
Var At: Int64; Hd: Array[0..15] Of Byte; Id,Ty: String[4]; Sz: Int64; K,Cnt,
 NStr,CurStr,VidStr,Idx,NalSz,ExLen,G: LongInt; Scale,Rate: Int64; IsH264,
 Seen,First: Boolean; Fcc: String[4]; Ex: Array[0..4095] Of Byte; Sf: Array[
 0..63] Of Byte;
Begin
 H4AviRun:=False;
 If H4ReadAt(0,Hd,12)<12 Then Exit;
 If (Hd[0]<>82) Or (Hd[1]<>73) Or (Hd[2]<>70) Or (Hd[3]<>70) Or (Hd[8]<>65) Or (
  Hd[9]<>86) Or (Hd[10]<>73) Then Exit;
 At:=12; NStr:=0; VidStr:=-1; CurStr:=-1; IsH264:=False; NalSz:=4; ExLen:=0;
 First:=True; Scale:=1; Rate:=0; Cnt:=0;
 While (At+8<=H4FSize) And (Cnt<50000000) Do Begin
  Inc(Cnt);
  If H4ReadAt(At,Hd,12)<8 Then Break;
  Id:=Chr(Hd[0])+Chr(Hd[1])+Chr(Hd[2])+Chr(Hd[3]);
  Sz:=H4L32(Hd,4);
  If (Id='LIST') Or (Id='RIFF') Then Begin
   Ty:=Chr(Hd[8])+Chr(Hd[9])+Chr(Hd[10])+Chr(Hd[11]);
   If (Ty='movi') And Probe Then Break;
   If (Ty='hdrl') Or (Ty='strl') Or (Ty='movi') Or (Ty='rec ') Or (Ty=
    'AVIX') Then Begin Inc(At,12); Continue; End;
   Inc(At,8+Sz+(Sz And 1)); Continue;
  End;
  If Id='strh' Then Begin
   If Sz>=36 Then Begin
    FillChar(Sf,SizeOf(Sf),0);
    G:=H4ReadAt(At+8,Sf,36);
    Inc(NStr); CurStr:=NStr-1;
    If (G>=36) And (Sf[0]=118) And (Sf[1]=105) And (Sf[2]=100) And (Sf[3]=115)
     And (VidStr<0) Then Begin
     VidStr:=CurStr;
     Fcc:=Chr(Sf[4])+Chr(Sf[5])+Chr(Sf[6])+Chr(Sf[7]);
     Scale:=H4L32(Sf,20); Rate:=H4L32(Sf,24);
     If H4AviMatch(Fcc,Codec) Then IsH264:=True;
    End;
   End;
  End Else If (Id='strf') And (CurStr=VidStr) And (VidStr>=0) And (Sz>=40) And
   First Then Begin
   First:=False;
   FillChar(Sf,SizeOf(Sf),0);
   G:=H4ReadAt(At+8,Sf,40);
   If G>=40 Then Begin
    Fcc:=Chr(Sf[16])+Chr(Sf[17])+Chr(Sf[18])+Chr(Sf[19]);
    If H4AviMatch(Fcc,Codec) Then IsH264:=True;
    K:=H4L32(Sf,0);
    If (K>=40) And (K<Sz) Then Begin
     ExLen:=Sz-K; If ExLen>4096 Then ExLen:=0 Else
      If H4ReadAt(At+8+K,Ex,ExLen)<>ExLen Then ExLen:=0;
    End;
   End;
   If (Not IsH264) Then Exit;
   If (Rate>0) And (Scale>0) Then H4Fps100:=(Rate*100+Scale Div 2) Div Scale;
   If (H4Fps100<100) Or (H4Fps100>30000) Then H4Fps100:=0;
   If Probe Then Begin H4AviRun:=True; Exit; End;
   If Codec=0 Then Begin
    { extradata eventuelle : avcC ou Annex B }
    If (ExLen>=7) And (Ex[0]=1) Then NalSz:=H4FeedAvcc(H4PBuf(@Ex),ExLen)
    Else Begin
     NalSz:=0;
     If ExLen>4 Then H4FeedNalPacket(H4PBuf(@Ex),ExLen,0,0);
    End;
    NalSz:=-1;   { a determiner d'apres le premier paquet }
   End Else Begin
    H4XInTag:=Fcc; H4XCTag:=Fcc;
    If (ExLen>4) And (Ex[0]=0) And (Ex[1]=0) And (Ex[2]=1) Then
     H4XFeed(H4PBuf(@Ex),ExLen);
   End;
  End Else If (Not Probe) And (VidStr>=0) And (Sz>0) And (Hd[0]>=48) And (
   Hd[0]<=57) And (Hd[1]>=48) And (Hd[1]<=57) And (Hd[2]=100) And ((Hd[3]=99)
   Or (Hd[3]=98)) Then Begin
   Idx:=(Hd[0]-48)*10+(Hd[1]-48);
   If (Idx=VidStr) And (Sz<=150000000) And (At+8+Sz<=H4FSize) Then Begin
    If H4IoNeed(Sz) Then Begin
     If H4ReadAt(At+8,H4Io^[0],Sz)<>Sz Then Break;
     If Codec=1 Then H4XFeed(H4Io,Sz)
     Else Begin
     If NalSz<0 Then Begin
      If (Sz>=4) And (H4Io^[0]=0) And (H4Io^[1]=0) And ((H4Io^[2]=1) Or (
       (H4Io^[2]=0) And (H4Io^[3]=1))) Then NalSz:=0 Else NalSz:=4;
     End;
     H4FeedNalPacket(H4Io,Sz,NalSz,0);
     End;
     If H4Stop Then Break;
     If (Cnt And 63)=0 Then H4Progress(At);
    End Else Break;
   End;
  End;
  At:=At+8+Sz+(Sz And 1);
 End;
 If Not Probe Then Begin
  If Codec=0 Then Begin
   If Not H4Stop Then Begin H4FinishPicture; H4Bump(True); End;
  End Else H4XFlush;
  H4AviRun:=H4FramesOut>0;
 End;
End;

{ ---- points d'entree ---- }
Function H4Sniff: LongInt;   { 1 = MP4/MOV, 2 = FLV, 3 = AVI, 0 = autre }
Var Hd: Array[0..15] Of Byte; T: String[4];
Begin
 H4Sniff:=0;
 FillChar(Hd,SizeOf(Hd),0);
 If H4ReadAt(0,Hd,12)<12 Then Exit;
 If (Hd[0]=70) And (Hd[1]=76) And (Hd[2]=86) And (Hd[3]=1) Then Begin
  H4Sniff:=2; Exit; End;
 If (Hd[0]=82) And (Hd[1]=73) And (Hd[2]=70) And (Hd[3]=70) And (Hd[8]=65) And (
  Hd[9]=86) And (Hd[10]=73) Then Begin H4Sniff:=3; Exit; End;
 T:=Chr(Hd[4])+Chr(Hd[5])+Chr(Hd[6])+Chr(Hd[7]);
 If (T='ftyp') Or (T='moov') Or (T='mdat') Or (T='free') Or (T='wide') Or (T=
  'skip') Or (T='pnot') Then H4Sniff:=1;
End;

Function H4IsFileKind(Const FN: String; Codec: LongInt): Boolean;
Begin
 H4IsFileKind:=False;
 If Not H4FOpenRead(FN) Then Exit;
 H4Io:=Nil; H4IoCap:=0; H4ZF:=Nil; H4ZSize:=0; H4Fps100:=0;
 Case H4Sniff Of
  1: H4IsFileKind:=H4Mp4Probe(Codec);
  2: If Codec=0 Then H4IsFileKind:=H4FlvRun(True);
  3: H4IsFileKind:=H4AviRun(True,Codec);
 End;
 H4FClose;
End;

Function H4ConformGen(Const FN: String; Codec: LongInt): Boolean;
Var Kind: LongInt;
Begin
 H4ConformGen:=False;
 If Not H4FOpenRead(FN) Then Exit;
 H4Io:=Nil; H4IoCap:=0; H4ZF:=Nil; H4ZSize:=0;
 Kind:=H4Sniff;
 If (Kind<>0) And ((Codec=0) Or (Kind<>2)) Then Begin
  H4InitState;
  H4Fps100:=0;
  If Codec=1 Then Begin H4XChunk:=Nil; H4XChunkCap:=0; H4XInTag:='mp4v'; H4XReset; End;
  Case Kind Of
   1: H4ConformGen:=H4Mp4Decode(Codec);
   2: If H4FlvRun(True) Then H4ConformGen:=H4FlvRun(False);
   3: H4ConformGen:=H4AviRun(False,Codec);
  End;
  If Codec=1 Then H4XFree;
  H4Cleanup;
 End;
 H4FClose;
End;

{ sondage rapide : la piste video est-elle H.264 / MPEG-4 partie 2 ? }
Function H4IsH264File(Const FN: String): Boolean;
Begin
 H4IsH264File:=H4IsFileKind(FN,0);
End;
Function H4IsMpeg4File(Const FN: String): Boolean;
Begin
 H4IsMpeg4File:=H4IsFileKind(FN,1);
End;

{ decode toute la video H.264 et emet les images (RGB24) par ConfEmit }
Function H4ConformFile(Const FN: String): Boolean;
Begin
 H4ConformFile:=H4ConformGen(FN,0);
End;
{ idem pour MPEG-4 partie 2 (DivX / Xvid / mp4v) dans AVI et MP4 }
Function H4ConformMpeg4(Const FN: String): Boolean;
Begin
 H4ConformMpeg4:=H4ConformGen(FN,1);
End;

{$POP}
{$ELSE}
Function H4ConformFile(Const FN: String): Boolean;
Begin
 H4ConformFile:=False;
End;
Function H4IsH264File(Const FN: String): Boolean;
Begin
 H4IsH264File:=False;
End;
Function H4ConformMpeg4(Const FN: String): Boolean;
Begin
 H4ConformMpeg4:=False;
End;
Function H4IsMpeg4File(Const FN: String): Boolean;
Begin
 H4IsMpeg4File:=False;
End;
{$ENDIF}

{ ====================================================================== }
{  Importation de medias : repartition des formats et creation du media  }
{ ====================================================================== }

Const
 ImportExts = '.BMP;.DIB;.GIF;.PNG;.APNG;.JPG;.JPEG;.PCX;.TGA;.PPM;.PGM;.PBM;.XBM;.LBM;.IFF;' +
              '.ILBM;.TIF;.TIFF;.BGX;.WPG;.MSP;.MAC;.ICO;.CUR;.DDS;.HDR;.AVI;.MP4;.M4V;.MOV;' +
              '.3GP;.FLV;.FLI;.FLC;.Y4M;.WAV';

Function HexN(V: LongInt; N: Integer): String;
Const
 Dg: String[16] = '0123456789ABCDEF';
Var
 S: String;
 I: Integer;
Begin
 S := '';
 For I := 1 To N Do Begin
  S := Dg[(V And 15) + 1] + S;
  V := V Shr 4;
 End;
 HexN := S;
End;

{ Nom de cache deterministe pour un fichier source }
Function CacheNameFor(Const FN: String; IsAud: Boolean): String;
Var
 F: File;
 H: LongInt;
 I: Integer;
 S: String;
 Sz: LongInt;
Begin
 S := UpStr(FExpand(FN));
 H := 5381;
 For I := 1 To Length(S) Do H := ((H Shl 5) + H + Ord(S[I])) And $FFFFFF;
 Sz := 0;
 {$I-}
 Assign(F, FN);
 FileMode := 0;
 Reset(F, 1);
 FileMode := 2;
 {$I+}
 If IOResult = 0 Then Begin
  Sz := FileSize(F);
  Close(F);
 End;
 H := (H + Sz) And $FFFFFF;
 If IsAud Then CacheNameFor := 'PA' + HexN(H, 6) + '.PVA'
 Else CacheNameFor := 'PM' + HexN(H, 6) + '.PVC';
End;

{ Appelle le bon decodeur ; IsAud est positionne pour les fichiers audio }
Function DispatchConform(Const FN: String; Var IsAud: Boolean): Boolean;
Var
 E: String;
 R: Boolean;
Begin
 E := ExtOf(FN);
 IsAud := False;
 R := False;
 If E = '.WAV' Then Begin
  IsAud := True;
  R := V3WavConform(FN);
 End
 Else If (E = '.MP4') Or (E = '.M4V') Or (E = '.MOV') Or (E = '.3GP') Or (E = '.FLV') Then
  Begin
  R := H4ConformFile(FN);
  If (Not R) And (CnFrames = 0) Then R := H4ConformMpeg4(FN);
 End
 Else If E = '.AVI' Then Begin
  R := V3AviConform(FN);
  If (Not R) And (CnFrames = 0) Then R := H4ConformFile(FN);
  If (Not R) And (CnFrames = 0) Then R := H4ConformMpeg4(FN);
 End
 Else If E = '.GIF' Then Begin
  R := V3GifConform(FN);
  If (Not R) And (CnFrames = 0) Then R := ImgConform(FN);
 End
 Else If (E = '.FLI') Or (E = '.FLC') Then R := V3FliConform(FN)
 Else If E = '.Y4M' Then R := V3Y4mConform(FN)
 Else If ImgKnownExt(E) Then R := ImgConform(FN);
 DispatchConform := R;
End;

Function IsStillExt(Const E: String): Boolean;
Begin
 IsStillExt := (E <> '.GIF') And (E <> '.AVI') And (E <> '.MP4') And (E <> '.M4V') And
               (E <> '.MOV') And (E <> '.3GP') And (E <> '.FLV') And (E <> '.FLI') And
               (E <> '.FLC') And (E <> '.Y4M') And (E <> '.WAV');
End;

{ Recalcule la duree (en images de la sequence) des medias issus du cache }
Procedure RecalcMediaDurs;
Var
 I: Integer;
Begin
 For I := 0 To P.NM - 1 Do
  If P.Media[I].Kind = MK_VIDEO Then Begin
   If P.Media[I].Fps100 > 0 Then
    P.Media[I].Dur := Max(1, (P.Media[I].NF * P.Fps * 100) Div P.Media[I].Fps100);
  End Else If P.Media[I].Kind = MK_WAV Then
   P.Media[I].Dur := Max(1, (P.Media[I].NF * P.Fps) Div 50)
  Else If P.Media[I].Kind = MK_IMAGE Then P.Media[I].Dur := P.Fps * 5;
End;

{ Conforme un fichier dans son cache. Retourne le nombre d'images / fenetres (0 = echec). }
Function ConformInto(Const FN, Cache: String; MaxSec: LongInt; Var IsAud: Boolean;
                     Var Fps100: LongInt): LongInt;
Var
 R: Boolean;
 Nf: LongInt;
 Ttl: String;
Begin
 ConformInto := 0;
 IsAud := ExtOf(FN) = '.WAV';
 If IsAud Then Ttl := 'Analyse audio' Else Ttl := 'Importation du média';
 If Not ConfBegin(Cache, IsAud, MaxSec, Ttl, IsStillExt(ExtOf(FN))) Then Exit;
 R := DispatchConform(FN, IsAud);
 ConfEnd(Nf, Fps100);
 If R Then ConformInto := Nf Else ConformInto := 0;
End;

Procedure ImportDlg;
Var
 FN, S, Nm, Cache: String;
 MaxSec, Fps100, Nf: LongInt;
 IsAud: Boolean;
 M, K: Integer;
 E: String;
Begin
 FN := '';
 If Not FileDlg('Importer un fichier', ImportExts, FN) Then Exit;
 E := ExtOf(FN);
 If Pos(E, ImportExts) = 0 Then Begin
  MsgBox('Importer', 'Format non pris en charge : ' + E);
  Exit;
 End;
 If P.NM >= MAXMEDIA Then Begin
  MsgBox('Importer', 'Le projet contient trop de médias.');
  Exit;
 End;
 MaxSec := 30;
 If Not IsStillExt(E) And (E <> '.WAV') Then Begin
  S := '30';
  If Not InputBox('Importer une vidéo', 'Durée maximale à importer (secondes) :', S, 4) Then Exit;
  MaxSec := Clamp(StrVal(S, 30), 1, 600);
 End;
 If E = '.WAV' Then MaxSec := 600;
 Cache := CacheNameFor(FN, E = '.WAV');
 Nf := ConformInto(FN, Cache, MaxSec, IsAud, Fps100);
 If Nf < 1 Then Begin
  MsgBox('Importer', 'Impossible de lire ce fichier :|' + Fit(FN, 400) +
         '|(format non pris en charge, fichier corrompu ou codec absent)');
  Exit;
 End;
 Nm := FN;
 K := Length(Nm);
 While (K > 0) And (Nm[K] <> '\') And (Nm[K] <> '/') And (Nm[K] <> ':') Do Dec(K);
 Delete(Nm, 1, K);
 Nm := UpStr(Nm);
 PushUndo;
 If IsAud Then M := AddMedia(Nm, MK_WAV, 1, 0, '', FN)
 Else If Nf = 1 Then M := AddMedia(Nm, MK_IMAGE, P.Fps * 5, 0, '', FN)
 Else M := AddMedia(Nm, MK_VIDEO, 1, Integer(MaxSec), '', FN);
 If M < 0 Then Begin
  DropLastUndo;
  Exit;
 End;
 P.Media[M].Cache := Cache;
 P.Media[M].NF := Nf;
 P.Media[M].Fps100 := Integer(Fps100);
 P.Media[M].CW := Integer(CnCW);
 P.Media[M].CH := Integer(CnCH);
 RecalcMediaDurs;
 ProjSel := M;
 TabC := 0;
 ProjScroll := Max(0, P.NM - ProjRows);
 NeedAll := True;
 If CnCapped Then Msg('Importé (limité à ' + IStr(MaxSec) + ' s) : ' + FN)
 Else Msg('Importé : ' + FN);
End;

{ Verifie qu'un cache existe et qu'il est au format courant (video : RGB565, en-tete 'VC2'). }
Function CacheUsable(Var M: TMedia): Boolean;
Var
 F: File;
 H: Array[0..31] Of Byte;
 N: Word;
Begin
 CacheUsable := False;
 If M.Cache = '' Then Exit;
 {$I-}
 Assign(F, M.Cache);
 FileMode := 0;
 Reset(F, 1);
 FileMode := 2;
 {$I+}
 If IOResult <> 0 Then Exit;
 {$I-}
 BlockRead(F, H, 32, N);
 {$I+}
 If (IOResult = 0) And (N = 32) Then Begin
  If M.Kind = MK_WAV Then CacheUsable := (H[0] = Ord('A')) And (H[2] = Ord('1'))
  Else CacheUsable := (H[0] = Ord('V')) And (H[2] = Ord('2')) And (M.CW > 0) And (M.CH > 0) And
                      (LE16(H, 4) = M.CW) And (LE16(H, 6) = M.CH);
 End;
 Close(F);
End;

{ Reconforme les medias dont le cache a disparu ou n'est plus valide (Force : tous). }
Procedure EnsureCaches(Force: Boolean);
Var
 I: Integer;
 Nf, Fps100: LongInt;
 IsAud: Boolean;
Begin
 For I := 0 To P.NM - 1 Do
  If (P.Media[I].Kind = MK_IMAGE) Or (P.Media[I].Kind = MK_VIDEO) Or (P.Media[I].Kind = MK_WAV) Then
   If Force Or (Not CacheUsable(P.Media[I])) Then
    If P.Media[I].Path <> '' Then Begin
     If P.Media[I].Cache = '' Then P.Media[I].Cache := CacheNameFor(P.Media[I].Path,
                                                                    P.Media[I].Kind = MK_WAV);
     Nf := ConformInto(P.Media[I].Path, P.Media[I].Cache,
                       Max(1, Max(P.Media[I].Par, 30)), IsAud, Fps100);
     If Nf > 0 Then Begin
      P.Media[I].NF := Nf;
      If Not IsAud Then Begin
       P.Media[I].Fps100 := Integer(Fps100);
       P.Media[I].CW := Integer(CnCW);
       P.Media[I].CH := Integer(CnCH);
      End;
     End;
    End;
 RecalcMediaDurs;
End;


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

(* ======================================================================
  h264enc.pas : encodeur H.264 (Baseline contraint, CAVLC, Intra16x16 + P,
  sans deblocage) + muxeur MP4 (avc1 + audio PCM 'sowt'), pilotable image
  par image.  Extrait/adapte de FFMPEG.PAS (encodeur natif 'libx264').
  FPC 3.2.2 uniquement (mode TP, Integer = 16 bits) ; stubs sinon.

    Function  X4EBegin(Const FN: String; W, H, Fps100, Qp, Gop,
                       AudioRate: LongInt): Boolean;
    Function  X4EFrame(Pix: Pointer): Boolean;     { RGB24 haut en bas }
    Function  X4EEnd(Const AudioPcmFile: String): Boolean;
    Procedure X4EAbort;

  Notes :
   - W et H : 16..4096 ; si impair, la taille codee est arrondie a la valeur
     paire superieure (le cropping H.264 4:2:0 n'a qu'une granularite de 2
     pixels) : la derniere colonne/ligne est dupliquee. X4EOutW/X4EOutH
     donnent la taille reellement ecrite dans le fichier. Pix doit toujours
     avoir les dimensions W*H*3 demandees.
   - Les tailles non multiples de 16 sont exactes grace au cropping du SPS.
   - Les echantillons sont ecrits au fil de l'eau dans le 'mdat' du fichier
     final (aucun fichier temporaire) ; le 'moov' est ecrit a la fin.
   - Le fichier AudioPcmFile n'est jamais supprime ni modifie.
   - Maximum 4 Go de fichier (offsets 32 bits).
  ====================================================================== *)
{$IFDEF FPC}
{$PUSH}
{$I+}
Const
 X4EMaxMb=65536;
Type
 TX4Buf=Array[0..2147483000] Of Byte;
 PX4Buf=^TX4Buf;
 TX4LArr=Array[0..1048575] Of LongInt;
 PX4LArr=^TX4LArr;
Function X4ZClip(V: LongInt): LongInt;
Begin If V<0 Then X4ZClip:=0 Else If V>255 Then X4ZClip:=255 Else X4ZClip:=V; End;
Function X4ZClip3(Lo,Hi,V: LongInt): LongInt;
Begin If V<Lo Then X4ZClip3:=Lo Else If V>Hi Then X4ZClip3:=Hi Else X4ZClip3:=V;
 End;
Var X4ZMbW,X4ZMbH: LongInt;

Const
 X4ZChromaDcCoeffTokenLen: Array[0..19] Of Byte=(
  2,0,0,0,6,1,0,0,6,6,3,0,6,7,7,6,
  6,8,8,7
 );
 X4ZChromaDcCoeffTokenBits: Array[0..19] Of Byte=(
  1,0,0,0,7,1,0,0,4,6,1,0,3,3,2,5,
  2,3,2,0
 );
 X4ZCoeffTokenLen: Array[0..271] Of Byte=(
  1,0,0,0,6,2,0,0,8,6,3,0,9,8,7,5,10,
  9,8,6,11,10,9,7,13,11,10,8,13,13,11,9,13,13,
  13,10,14,14,13,11,14,14,14,13,15,15,14,14,15,15,15,
  14,16,15,15,15,16,16,16,15,16,16,16,16,16,16,16,16,
  2,0,0,0,6,2,0,0,6,5,3,0,7,6,6,4,8,
  6,6,4,8,7,7,5,9,8,8,6,11,9,9,6,11,11,
  11,7,12,11,11,9,12,12,12,11,12,12,12,11,13,13,13,
  12,13,13,13,13,13,14,13,13,14,14,14,13,14,14,14,14,
  4,0,0,0,6,4,0,0,6,5,4,0,6,5,5,4,7,
  5,5,4,7,5,5,4,7,6,6,4,7,6,6,4,8,7,
  7,5,8,8,7,6,9,8,8,7,9,9,8,8,9,9,9,
  8,10,9,9,9,10,10,10,10,10,10,10,10,10,10,10,10,
  6,0,0,0,6,6,0,0,6,6,6,0,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
 );
 X4ZCoeffTokenBits: Array[0..271] Of Byte=(
  1,0,0,0,5,1,0,0,7,4,1,0,7,6,5,3,7,
  6,5,3,7,6,5,4,15,6,5,4,11,14,5,4,8,10,
  13,4,15,14,9,4,11,10,13,12,15,14,9,12,11,10,13,
  8,15,1,9,12,11,14,13,8,7,10,9,12,4,6,5,8,
  3,0,0,0,11,2,0,0,7,7,3,0,7,10,9,5,7,
  6,5,4,4,6,5,6,7,6,5,8,15,6,5,4,11,14,
  13,4,15,10,9,4,11,14,13,12,8,10,9,8,15,14,13,
  12,11,10,9,12,7,11,6,8,9,8,10,1,7,6,5,4,
  15,0,0,0,15,14,0,0,11,15,13,0,8,12,14,12,15,
  10,11,11,11,8,9,10,9,14,13,9,8,10,9,8,15,14,
  13,13,11,14,10,12,15,10,13,12,11,14,9,12,8,10,13,
  8,13,7,9,12,9,12,11,10,5,8,7,6,1,4,3,2,
  3,0,0,0,0,1,0,0,4,5,6,0,8,9,10,11,12,
  13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,
  30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,
  47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63
 );
 X4ZTotalZerosLen: Array[0..255] Of Byte=(
  1,3,3,4,4,5,5,6,6,7,7,8,8,9,9,9,
  3,3,3,3,3,4,4,4,4,5,5,6,6,6,6,0,
  4,3,3,3,4,4,3,3,4,5,5,6,5,6,0,0,
  5,3,4,4,3,3,3,4,3,4,5,5,5,0,0,0,
  4,4,4,3,3,3,3,3,4,5,4,5,0,0,0,0,
  6,5,3,3,3,3,3,3,4,3,6,0,0,0,0,0,
  6,5,3,3,3,2,3,4,3,6,0,0,0,0,0,0,
  6,4,5,3,2,2,3,3,6,0,0,0,0,0,0,0,
  6,6,4,2,2,3,2,5,0,0,0,0,0,0,0,0,
  5,5,3,2,2,2,4,0,0,0,0,0,0,0,0,0,
  4,4,3,3,1,3,0,0,0,0,0,0,0,0,0,0,
  4,4,2,1,3,0,0,0,0,0,0,0,0,0,0,0,
  3,3,1,2,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 );
 X4ZTotalZerosBits: Array[0..255] Of Byte=(
  1,3,2,3,2,3,2,3,2,3,2,3,2,3,2,1,
  7,6,5,4,3,5,4,3,2,3,2,3,2,1,0,0,
  5,7,6,5,4,3,4,3,2,3,2,1,1,0,0,0,
  3,7,5,4,6,5,4,3,3,2,2,1,0,0,0,0,
  5,4,3,7,6,5,4,3,2,1,1,0,0,0,0,0,
  1,1,7,6,5,4,3,2,1,1,0,0,0,0,0,0,
  1,1,5,4,3,3,2,1,1,0,0,0,0,0,0,0,
  1,1,1,3,3,2,2,1,0,0,0,0,0,0,0,0,
  1,0,1,3,2,1,1,1,0,0,0,0,0,0,0,0,
  1,0,1,3,2,1,1,0,0,0,0,0,0,0,0,0,
  0,1,1,2,1,3,0,0,0,0,0,0,0,0,0,0,
  0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,
  0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
  0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 );
 X4ZChromaDcTotalZerosLen: Array[0..11] Of Byte=(
  1,2,3,3,
  1,2,2,0,
  1,1,0,0
 );
 X4ZChromaDcTotalZerosBits: Array[0..11] Of Byte=(
  1,1,1,0,
  1,1,0,0,
  1,0,0,0
 );
 X4ZRunLen: Array[0..111] Of Byte=(
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,2,3,3,0,0,0,0,0,0,0,0,0,0,0,
  2,2,3,3,3,3,0,0,0,0,0,0,0,0,0,0,
  2,3,3,3,3,3,3,0,0,0,0,0,0,0,0,0,
  3,3,3,3,3,3,3,4,5,6,7,8,9,10,11,0
 );
 X4ZRunBits: Array[0..111] Of Byte=(
  1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
  3,2,3,2,1,0,0,0,0,0,0,0,0,0,0,0,
  3,0,1,3,2,5,4,0,0,0,0,0,0,0,0,0,
  7,6,5,4,3,2,1,1,1,1,1,1,1,1,1,0
 );
Procedure X4ZPred16x16(Pl: PX4Buf; Stride,X,Y,Mode: LongInt; AvL,AvT:
 Boolean);
Var I,J,V,SumT,SumL,A,B,C,H,Vv: LongInt;
Begin
 Case Mode Of
  0: For J:=0 To 15 Do For I:=0 To 15 Do Pl^[(Y+J)*Stride+X+I]:=Pl^[(Y-1)*
   Stride+X+I];
  1: For J:=0 To 15 Do Begin V:=Pl^[(Y+J)*Stride+X-1]; For I:=0 To 15 Do Pl^[(Y+
   J)*Stride+X+I]:=V; End;
  2: Begin
   SumT:=0; SumL:=0;
   If AvT Then For I:=0 To 15 Do Inc(SumT,Pl^[(Y-1)*Stride+X+I]);
   If AvL Then For J:=0 To 15 Do Inc(SumL,Pl^[(Y+J)*Stride+X-1]);
   If AvT And AvL Then V:=(SumT+SumL+16) Shr 5
   Else If AvL Then V:=(SumL+8) Shr 4
   Else If AvT Then V:=(SumT+8) Shr 4
   Else V:=128;
   For J:=0 To 15 Do For I:=0 To 15 Do Pl^[(Y+J)*Stride+X+I]:=V;
  End;
  3: Begin
   H:=0; Vv:=0;
   For I:=0 To 7 Do Begin
    Inc(H,(I+1)*(Pl^[(Y-1)*Stride+X+8+I]-Pl^[(Y-1)*Stride+X+6-I]));
    Inc(Vv,(I+1)*(Pl^[(Y+8+I)*Stride+X-1]-Pl^[(Y+6-I)*Stride+X-1]));
   End;
   A:=16*(Pl^[(Y+15)*Stride+X-1]+Pl^[(Y-1)*Stride+X+15]);
   B:=SarLongint(5*H+32,6); C:=SarLongint(5*Vv+32,6);
   For J:=0 To 15 Do For I:=0 To 15 Do
    Pl^[(Y+J)*Stride+X+I]:=X4ZClip(SarLongint(A+B*(I-7)+C*(J-7)+16,5));
  End;
 End;
End;


Procedure X4ZPredChroma(Pl: PX4Buf; Stride,X,Y,Mode: LongInt; AvL,AvT:
 Boolean);
Var I,J,V,A,B,C,H,Vv,Bx,By,S0,S1,SL0,SL1: LongInt;
Begin
 Case Mode Of
  0: For By:=0 To 1 Do For Bx:=0 To 1 Do Begin
      S0:=0; S1:=0;
      If AvT Then For I:=0 To 3 Do Inc(S0,Pl^[(Y-1)*Stride+X+Bx*4+I]);
      If AvL Then For J:=0 To 3 Do Inc(S1,Pl^[(Y+By*4+J)*Stride+X-1]);
      If (Bx=0) And (By=0) Or (Bx=1) And (By=1) Then Begin
       If AvT And AvL Then V:=(S0+S1+4) Shr 3
       Else If AvL Then V:=(S1+2) Shr 2
       Else If AvT Then V:=(S0+2) Shr 2
       Else V:=128;
      End Else If (Bx=1) And (By=0) Then Begin
       If AvT Then V:=(S0+2) Shr 2
       Else If AvL Then V:=(S1+2) Shr 2
       Else V:=128;
      End Else Begin
       If AvL Then V:=(S1+2) Shr 2
       Else If AvT Then V:=(S0+2) Shr 2
       Else V:=128;
      End;
      For J:=0 To 3 Do For I:=0 To 3 Do Pl^[(Y+By*4+J)*Stride+X+Bx*4+I]:=V;
     End;
  1: For J:=0 To 7 Do Begin V:=Pl^[(Y+J)*Stride+X-1]; For I:=0 To 7 Do Pl^[(Y+
   J)*Stride+X+I]:=V; End;
  2: For J:=0 To 7 Do For I:=0 To 7 Do Pl^[(Y+J)*Stride+X+I]:=Pl^[(Y-1)*Stride+
   X+I];
  3: Begin
   H:=0; Vv:=0;
   For I:=0 To 3 Do Begin
    Inc(H,(I+1)*(Pl^[(Y-1)*Stride+X+4+I]-Pl^[(Y-1)*Stride+X+2-I]));
    Inc(Vv,(I+1)*(Pl^[(Y+4+I)*Stride+X-1]-Pl^[(Y+2-I)*Stride+X-1]));
   End;
   A:=16*(Pl^[(Y+7)*Stride+X-1]+Pl^[(Y-1)*Stride+X+7]);
   B:=SarLongint(34*H+32,6); C:=SarLongint(34*Vv+32,6);
   For J:=0 To 7 Do For I:=0 To 7 Do
    Pl^[(Y+J)*Stride+X+I]:=X4ZClip(SarLongint(A+B*(I-3)+C*(J-3)+16,5));
  End;
 End;
End;


Procedure X4ZIdct4(Var D: Array Of LongInt; Pl: PX4Buf; Stride,X,Y: LongInt);
Var I,J,E0,E1,E2,E3: LongInt; T: Array[0..15] Of LongInt;
Begin
 For I:=0 To 3 Do Begin
  E0:=D[I*4]+D[I*4+2]; E1:=D[I*4]-D[I*4+2]; E2:=SarLongint(D[I*4+1],1)-D[I*4+3]; E3:=
   D[I*4+1]+SarLongint(D[I*4+3],1);
  T[I*4]:=E0+E3; T[I*4+1]:=E1+E2; T[I*4+2]:=E1-E2; T[I*4+3]:=E0-E3;
 End;
 For J:=0 To 3 Do Begin
  E0:=T[J]+T[8+J]; E1:=T[J]-T[8+J]; E2:=SarLongint(T[4+J],1)-T[12+J]; E3:=T[4+J]+
   SarLongint(T[12+J],1);
  Pl^[Y*Stride+X+J]:=X4ZClip(Pl^[Y*Stride+X+J]+SarLongint(E0+E3+32,6));
  Pl^[(Y+1)*Stride+X+J]:=X4ZClip(Pl^[(Y+1)*Stride+X+J]+SarLongint(E1+E2+32,6));
  Pl^[(Y+2)*Stride+X+J]:=X4ZClip(Pl^[(Y+2)*Stride+X+J]+SarLongint(E1-E2+32,6));
  Pl^[(Y+3)*Stride+X+J]:=X4ZClip(Pl^[(Y+3)*Stride+X+J]+SarLongint(E0-E3+32,6));
 End;
End;


Function X4ZChromaQp(Qp,Off: LongInt): LongInt;
Const Tab: Array[0..21] Of Byte=(29,30,31,32,32,33,34,34,35,35,36,36,37,37,37,
 38,38,38,39,39,39,39);
Var Q: LongInt;
Begin
 Q:=X4ZClip3(0,51,Qp+Off);
 If Q<30 Then X4ZChromaQp:=Q Else X4ZChromaQp:=Tab[Q-30];
End;


Procedure X4ZMcLuma(Src: PX4Buf; X,Y,Fx,Fy,Bw,Bh: LongInt; Dst: PX4LArr);
Const PS=21;
Var P,Hb,Vh: Array[0..440] Of LongInt; A1,A2: Array[0..255] Of LongInt;
 Cx,Cy: Array[0..20] Of LongInt; R,C,I,J,PW,PH,V,K1,K2,R0,R1,Rn,Q: LongInt;
 Rp: PX4Buf;
 { composantes : 0 G, 1 droite, 2 dessous, 3 b, 4 s, 5 h, 6 m, 7 j }
 Procedure Comp(K: LongInt; Var A: Array Of LongInt);
 Var I2,J2,V2: LongInt;
 Begin
  Case K Of
   0: For J2:=0 To Bh-1 Do For I2:=0 To Bw-1 Do A[J2*16+I2]:=P[(J2+2)*PS+I2+2];
   1: For J2:=0 To Bh-1 Do For I2:=0 To Bw-1 Do A[J2*16+I2]:=P[(J2+2)*PS+I2+3];
   2: For J2:=0 To Bh-1 Do For I2:=0 To Bw-1 Do A[J2*16+I2]:=P[(J2+3)*PS+I2+2];
   3,4: Begin
    Q:=2; If K=4 Then Q:=3;
    For J2:=0 To Bh-1 Do For I2:=0 To Bw-1 Do Begin
     V2:=SarLongint(Hb[(J2+Q)*PS+I2]+16,5);
     If V2<0 Then V2:=0 Else If V2>255 Then V2:=255;
     A[J2*16+I2]:=V2;
    End;
   End;
   5,6: Begin
    Q:=2; If K=6 Then Q:=3;
    For J2:=0 To Bh-1 Do For I2:=0 To Bw-1 Do Begin
     V2:=SarLongint(Vh[J2*PS+I2+Q]+16,5);
     If V2<0 Then V2:=0 Else If V2>255 Then V2:=255;
     A[J2*16+I2]:=V2;
    End;
   End;
   7: For J2:=0 To Bh-1 Do For I2:=0 To Bw-1 Do Begin
     V2:=SarLongint(Hb[J2*PS+I2]-5*Hb[(J2+1)*PS+I2]+20*Hb[(J2+2)*PS+I2]
      +20*Hb[(J2+3)*PS+I2]-5*Hb[(J2+4)*PS+I2]+Hb[(J2+5)*PS+I2]+512,10);
     If V2<0 Then V2:=0 Else If V2>255 Then V2:=255;
     A[J2*16+I2]:=V2;
    End;
  End;
 End;
Begin
 PW:=X4ZMbW*16; PH:=X4ZMbH*16;
 If (X>=2) And (Y>=2) And (X+Bw+3<=PW) And (Y+Bh+3<=PH) Then Begin
  For R:=0 To Bh+4 Do Begin
   Rp:=PX4Buf(@Src^[(Y-2+R)*PW+X-2]);
   For C:=0 To Bw+4 Do P[R*PS+C]:=Rp^[C];
  End;
 End Else Begin
  For C:=0 To Bw+4 Do Begin V:=X-2+C; If V<0 Then V:=0 Else If V>PW-1 Then V:=PW-
   1; Cx[C]:=V; End;
  For R:=0 To Bh+4 Do Begin V:=Y-2+R; If V<0 Then V:=0 Else If V>PH-1 Then V:=PH-
   1; Cy[R]:=V*PW; End;
  For R:=0 To Bh+4 Do For C:=0 To Bw+4 Do P[R*PS+C]:=Src^[Cy[R]+Cx[C]];
 End;
 If (Fx=0) And (Fy=0) Then Begin
  For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do Dst^[J*16+I]:=P[(J+2)*PS+I+2];
  Exit;
 End;
 { choix des deux composantes selon la position au quart de pixel }
 K2:=-1;
 Case Fy*4+Fx Of
  1: Begin K1:=0; K2:=3; End;   2: K1:=3;   3: Begin K1:=1; K2:=3; End;
  4: Begin K1:=0; K2:=5; End;   5: Begin K1:=3; K2:=5; End;
  6: Begin K1:=3; K2:=7; End;   7: Begin K1:=3; K2:=6; End;
  8: K1:=5;                     9: Begin K1:=5; K2:=7; End;
  10: K1:=7;                    11: Begin K1:=7; K2:=6; End;
  12: Begin K1:=2; K2:=5; End;  13: Begin K1:=5; K2:=4; End;
  14: Begin K1:=7; K2:=4; End;
 Else Begin K1:=6; K2:=4; End;
 End;
 { intermediaires horizontaux (lignes R0..R1) et verticaux }
 If (K1=3) Or (K2=3) Or (K1=4) Or (K2=4) Or (K1=7) Or (K2=7) Then Begin
  If (K1=7) Or (K2=7) Then Begin R0:=0; R1:=Bh+4; End Else Begin R0:=2; R1:=Bh+2; End;
  For R:=R0 To R1 Do For C:=0 To Bw-1 Do
   Hb[R*PS+C]:=P[R*PS+C]-5*P[R*PS+C+1]+20*P[R*PS+C+2]+20*P[R*PS+C+3]
    -5*P[R*PS+C+4]+P[R*PS+C+5];
 End;
 If (K1=5) Or (K2=5) Or (K1=6) Or (K2=6) Then
  For R:=0 To Bh-1 Do For C:=2 To Bw+2 Do
   Vh[R*PS+C]:=P[R*PS+C]-5*P[(R+1)*PS+C]+20*P[(R+2)*PS+C]+20*P[(R+3)*PS+C]
    -5*P[(R+4)*PS+C]+P[(R+5)*PS+C];
 Comp(K1,A1);
 If K2<0 Then Begin
  For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do Dst^[J*16+I]:=A1[J*16+I];
 End Else Begin
  Comp(K2,A2);
  For J:=0 To Bh-1 Do For I:=0 To Bw-1 Do
   Dst^[J*16+I]:=(A1[J*16+I]+A2[J*16+I]+1) Shr 1;
 End;
End;

Procedure X4ZMcChroma(Src: PX4Buf; X,Y,Fx,Fy,Bw,Bh: LongInt; Dst: PX4LArr);
Var I,J,PW,PH,X0,X1,Y0,Y1: LongInt;
Begin
 PW:=X4ZMbW*8; PH:=X4ZMbH*8;
 For J:=0 To Bh-1 Do Begin
  Y0:=Y+J; If Y0<0 Then Y0:=0 Else If Y0>PH-1 Then Y0:=PH-1;
  Y1:=Y+J+1; If Y1<0 Then Y1:=0 Else If Y1>PH-1 Then Y1:=PH-1;
  For I:=0 To Bw-1 Do Begin
   X0:=X+I; If X0<0 Then X0:=0 Else If X0>PW-1 Then X0:=PW-1;
   X1:=X+I+1; If X1<0 Then X1:=0 Else If X1>PW-1 Then X1:=PW-1;
   Dst^[J*8+I]:=((8-Fx)*(8-Fy)*Src^[Y0*PW+X0]+Fx*(8-Fy)*Src^[Y0*PW+X1]+(8-Fx)*
    Fy*Src^[Y1*PW+X0]+Fx*Fy*Src^[Y1*PW+X1]+32) Shr 6;
  End;
 End;
End;
{ X264E-BEGIN }
{ ---- libx264 : encodeur H.264 natif (profil Baseline contraint, CAVLC, I/P,
 sans filtre de deblocage) vers flux brut Annex B ou MP4 ---- }
Const
 X4MF: Array[0..5,0..2] Of LongInt=((13107,5243,8066),(11916,4660,7490),(10082,
  4194,6554),(9362,3647,5825),(8192,3355,5243),(7282,2893,4559));
 X4V: Array[0..5,0..2] Of LongInt=((10,16,13),(11,18,14),(13,20,16),(14,23,18),(
  16,25,20),(18,29,23));
 X4Zig: Array[0..15] Of LongInt=(0,1,4,8,5,2,3,6,9,12,13,10,7,11,14,15);
 X4BlkX: Array[0..15] Of LongInt=(0,1,0,1,2,3,2,3,0,1,0,1,2,3,2,3);
 X4BlkY: Array[0..15] Of LongInt=(0,0,1,1,0,0,1,1,2,2,3,3,2,2,3,3);
Type
 X4Arr=Array[0..15] Of LongInt;
Var
 X4Rb: PX4Buf; X4RbBits: LongInt;           { RBSP en cours d'ecriture }
 X4Mbw,X4Mbh,X4Wp,X4Hp,X4Cw,X4Ch: LongInt;
 X4Src,X4Rec,X4Ref: PX4Buf;                  { Y puis U puis V, planes
  alignes sur les macroblocs }
 X4NnzY,X4NnzU,X4NnzV: PX4Buf; X4Kind: PX4Buf; X4Mvx,X4Mvy: PX4LArr;
 X4Qp,X4SkipRun,X4Lam: LongInt; X4Inter: Boolean;
 X4CbpInv: Array[0..47] Of Byte;
 X4RbCap,X4RbDirty: LongInt; X4Err: Boolean;             { capacite du tampon RBSP }

Procedure X4Put(V: Int64; N: LongInt);
Var K,Take,Room: LongInt; Bp: LongInt;
Begin
 If (X4RbBits Shr 3)+8>=X4RbCap Then Begin X4Err:=True; Exit; End;
 { ecriture par paquets de bits (<= 8 bits restants dans l'octet courant) }
 While N>0 Do Begin
  Bp:=X4RbBits And 7; Room:=8-Bp; Take:=N; If Take>Room Then Take:=Room;
  K:=LongInt((V Shr (N-Take)) And ((1 Shl Take)-1));
  X4Rb^[X4RbBits Shr 3]:=X4Rb^[X4RbBits Shr 3] Or Byte(K Shl (Room-Take));
  Inc(X4RbBits,Take); Dec(N,Take);
  If (X4RbBits Shr 3)+8>=X4RbCap Then Begin X4Err:=True; Exit; End;
 End;
End;
Procedure X4Ue(V: LongInt);
Var N,T: LongInt;
Begin
 Inc(V); N:=0; T:=V; While T>1 Do Begin T:=T Shr 1; Inc(N); End;
 X4Put(0,N); X4Put(V,N+1);
End;
Procedure X4Se(V: LongInt);
Begin If V>0 Then X4Ue(2*V-1) Else X4Ue(-2*V); End;
Procedure X4Trail;
Begin
 X4Put(1,1);
 If (X4RbBits And 7)<>0 Then X4Put(0,8-(X4RbBits And 7));
End;

{ ---- CAVLC ---- }
Procedure X4Level(Lc,Sl: LongInt);
Var Pre,Suf,Sz: LongInt;
Begin
 If Sl=0 Then Begin
  If Lc<14 Then Begin Pre:=Lc; Sz:=0; Suf:=0; End
  Else If Lc<30 Then Begin Pre:=14; Sz:=4; Suf:=Lc-14; End
  Else Begin Pre:=15; Sz:=12; Suf:=Lc-30; End;
 End Else Begin
  If Lc<(15 Shl Sl) Then Begin Pre:=Lc Shr Sl; Sz:=Sl; Suf:=Lc And ((1 Shl Sl)-
   1); End
  Else Begin Pre:=15; Sz:=12; Suf:=Lc-(15 Shl Sl); End;
 End;
 If Suf>4095 Then Suf:=4095;
 X4Put(0,Pre); X4Put(1,1);
 If Sz>0 Then X4Put(Suf,Sz);
End;
{ ecrit un bloc ; Lev en ordre de balayage ; NC=-1 DC chroma ; renvoie
 TotalCoeff }
Function X4Block(Const Lev: Array Of LongInt; MaxC,NC: LongInt): LongInt;
Var Total,T1,I,Sl,Lv,Lc,Zeros,Zl,Run,Idx: LongInt; Vals,Pos: X4Arr;
Begin
 Total:=0;
 For I:=MaxC-1 Downto 0 Do If Lev[I]<>0 Then Begin Vals[Total]:=Lev[I]; Pos[
  Total]:=I; Inc(Total); End;
 T1:=0; While (T1<Total) And (T1<3) And (Abs(Vals[T1])=1) Do Inc(T1);
 If NC=-1 Then Begin Idx:=Total*4+T1; X4Put(X4ZChromaDcCoeffTokenBits[Idx],
  X4ZChromaDcCoeffTokenLen[Idx]); End
 Else If NC>=8 Then Begin
  If Total=0 Then X4Put(3,6) Else X4Put(((Total-1) Shl 2) Or T1,6);
 End Else Begin
  If NC<2 Then Idx:=0 Else If NC<4 Then Idx:=1 Else Idx:=2;
  Idx:=Idx*68+Total*4+T1; X4Put(X4ZCoeffTokenBits[Idx],X4ZCoeffTokenLen[Idx]);
 End;
 X4Block:=Total;
 If Total=0 Then Exit;
 For I:=0 To T1-1 Do If Vals[I]<0 Then X4Put(1,1) Else X4Put(0,1);
 If (Total>10) And (T1<3) Then Sl:=1 Else Sl:=0;
 For I:=T1 To Total-1 Do Begin
  Lv:=Vals[I];
  If Lv>0 Then Lc:=2*Lv-2 Else Lc:=-2*Lv-1;
  If (I=T1) And (T1<3) Then Dec(Lc,2);
  X4Level(Lc,Sl);
  If Sl=0 Then Sl:=1;
  If (Abs(Lv)>(3 Shl (Sl-1))) And (Sl<6) Then Inc(Sl);
 End;
 Zeros:=Pos[0]+1-Total;
 If Total<MaxC Then Begin
  If NC=-1 Then Idx:=(Total-1)*4+Zeros Else Idx:=(Total-1)*16+Zeros;
  If NC=-1 Then X4Put(X4ZChromaDcTotalZerosBits[Idx],X4ZChromaDcTotalZerosLen[
   Idx])
  Else X4Put(X4ZTotalZerosBits[Idx],X4ZTotalZerosLen[Idx]);
 End;
 Zl:=Zeros;
 For I:=0 To Total-2 Do Begin
  If Zl<=0 Then Break;
  Run:=Pos[I]-Pos[I+1]-1;
  Idx:=Zl; If Idx>7 Then Idx:=7;
  Idx:=(Idx-1)*16+Run;
  X4Put(X4ZRunBits[Idx],X4ZRunLen[Idx]);
  Dec(Zl,Run);
 End;
End;

{ ---- transformees ---- }
Procedure X4Fdct(Var B: X4Arr);
Var I,A,Bb,C,D: LongInt; T: X4Arr;
Begin
 For I:=0 To 3 Do Begin
  A:=B[I*4]+B[I*4+3]; Bb:=B[I*4+1]+B[I*4+2]; C:=B[I*4+1]-B[I*4+2]; D:=B[I*4]-B[
   I*4+3];
  T[I*4]:=A+Bb; T[I*4+2]:=A-Bb; T[I*4+1]:=2*D+C; T[I*4+3]:=D-2*C;
 End;
 For I:=0 To 3 Do Begin
  A:=T[I]+T[12+I]; Bb:=T[4+I]+T[8+I]; C:=T[4+I]-T[8+I]; D:=T[I]-T[12+I];
  B[I]:=A+Bb; B[8+I]:=A-Bb; B[4+I]:=2*D+C; B[12+I]:=D-2*C;
 End;
End;
Function X4Cls(I: LongInt): LongInt;
Var R,C: LongInt;
Begin R:=I Shr 2; C:=I And 3; If ((R And 1)=0) And ((C And 1)=0) Then X4Cls:=0
 Else If ((R And 1)=1) And ((C And 1)=1) Then X4Cls:=1 Else X4Cls:=2; End;
Function X4Q(V,Mf,Qb,F: LongInt): LongInt;
Var A: Int64;
Begin
 A:=(Int64(Abs(V))*Mf+F) Shr Qb;
 If A>2047 Then A:=2047;
 If V<0 Then X4Q:=-A Else X4Q:=A;
End;
{ dequantification d'un coefficient AC (flat) }
Function X4Dq(C,Qp,Cls: LongInt): LongInt;
Var Ls: LongInt;
Begin
 Ls:=16*X4V[Qp Mod 6,Cls];
 If Qp>=24 Then X4Dq:=(C*Ls) Shl (Qp Div 6-4) Else X4Dq:=SarLongint(C*Ls+(1 Shl (3-Qp
  Div 6)),4-Qp Div 6);
End;

Function X4Sad(Pa,Pb: PX4Buf; Sa,Sb,W,H: LongInt): LongInt;
Var I,J,S,D: LongInt; Ra,Rb: PX4Buf;
Begin
 S:=0;
 For J:=0 To H-1 Do Begin
  Ra:=PX4Buf(@Pa^[J*Sa]); Rb:=PX4Buf(@Pb^[J*Sb]);
  For I:=0 To W-1 Do Begin D:=Ra^[I]-Rb^[I]; If D<0 Then D:=-D; Inc(S,D); End;
 End;
 X4Sad:=S;
End;

{ quantifie et reconstruit un bloc 4x4 (residu deja calcule dans Res) ; Lev
 recoit les niveaux en balayage ; renvoie nb de coefs non nuls ;
  Start : 0 ou 1 (le DC est traite a part) ; DcOut : coefficient DC transforme
   (non quantifie) }
Function X4QuantBlock(Var Res: X4Arr; Qp: LongInt; Intra: Boolean; Start:
 LongInt; Var Lev: Array Of LongInt; Var Dq: X4Arr; Var Dc: LongInt): LongInt;
Var I,K,Qb,F,N: LongInt; W: X4Arr;
Begin
 W:=Res; X4Fdct(W);
 Dc:=W[0];
 Qb:=15+Qp Div 6;
 If Intra Then F:=(1 Shl Qb) Div 3 Else F:=(1 Shl Qb) Div 6;
 N:=0; FillChar(Dq,SizeOf(Dq),0);
 For K:=Start To 15 Do Begin
  I:=X4Zig[K];
  Lev[K-Start]:=X4Q(W[I],X4MF[Qp Mod 6,X4Cls(I)],Qb,F);
  If Lev[K-Start]<>0 Then Begin Inc(N); Dq[I]:=X4Dq(Lev[K-Start],Qp,X4Cls(I));
   End;
 End;
 X4QuantBlock:=N;
End;

{ prediction de vecteur 16x16 (quarts de pixel) }
Procedure X4Mvp(Mx,My: LongInt; Var Px,Py: LongInt; Var AvA,AvB: Boolean; Var
 RefA,RefB: LongInt; Var MvAx,MvAy,MvBx,MvBy: LongInt);
Var Ia,Ib,Ic,RefC,MvCx,MvCy,Cnt: LongInt; AvC: Boolean;
 Function Med(A,B,C: LongInt): LongInt;
 Begin If A>B Then Begin If B>C Then Med:=B Else If A>C Then Med:=C Else Med:=A;
  End Else Begin If A>C Then Med:=A Else If B>C Then Med:=C Else Med:=B; End;
  End;
Begin
 AvA:=Mx>0; AvB:=My>0; AvC:=False; RefA:=-1; RefB:=-1; RefC:=-1; MvAx:=0; MvAy:=
  0; MvBx:=0; MvBy:=0; MvCx:=0; MvCy:=0;
 If AvA Then Begin Ia:=My*X4Mbw+Mx-1; If X4Kind^[Ia]>=1 Then Begin RefA:=0;
  MvAx:=X4Mvx^[Ia]; MvAy:=X4Mvy^[Ia]; End; End;
 If AvB Then Begin Ib:=(My-1)*X4Mbw+Mx; If X4Kind^[Ib]>=1 Then Begin RefB:=0;
  MvBx:=X4Mvx^[Ib]; MvBy:=X4Mvy^[Ib]; End; End;
 If My>0 Then Begin
  If Mx<X4Mbw-1 Then Begin Ic:=(My-1)*X4Mbw+Mx+1; AvC:=True; End
  Else If Mx>0 Then Begin Ic:=(My-1)*X4Mbw+Mx-1; AvC:=True; End;
  If AvC And (X4Kind^[Ic]>=1) Then Begin RefC:=0; MvCx:=X4Mvx^[Ic]; MvCy:=
   X4Mvy^[Ic]; End;
 End;
 If (Not AvB) And (Not AvC) And AvA Then Begin Px:=MvAx; Py:=MvAy; Exit; End;
 Cnt:=Ord(RefA=0)+Ord(RefB=0)+Ord(RefC=0);
 If Cnt=1 Then Begin
  If RefA=0 Then Begin Px:=MvAx; Py:=MvAy; End Else If RefB=0 Then Begin Px:=
   MvBx; Py:=MvBy; End Else Begin Px:=MvCx; Py:=MvCy; End;
 End Else Begin Px:=Med(MvAx,MvBx,MvCx); Py:=Med(MvAy,MvBy,MvCy); End;
End;

Function X4NcLuma(Gx,Gy: LongInt): LongInt;
Var A,B,Aa,Bb: LongInt;
Begin
 Aa:=Ord(Gx>0); Bb:=Ord(Gy>0);
 If Aa<>0 Then A:=X4NnzY^[Gy*X4Mbw*4+Gx-1] Else A:=0;
 If Bb<>0 Then B:=X4NnzY^[(Gy-1)*X4Mbw*4+Gx] Else B:=0;
 If (Aa<>0) And (Bb<>0) Then X4NcLuma:=(A+B+1) Shr 1 Else X4NcLuma:=A+B;
End;
Function X4NcChroma(Pl: PX4Buf; Gx,Gy: LongInt): LongInt;
Var A,B,Aa,Bb: LongInt;
Begin
 Aa:=Ord(Gx>0); Bb:=Ord(Gy>0);
 If Aa<>0 Then A:=Pl^[Gy*X4Mbw*2+Gx-1] Else A:=0;
 If Bb<>0 Then B:=Pl^[(Gy-1)*X4Mbw*2+Gx] Else B:=0;
 If (Aa<>0) And (Bb<>0) Then X4NcChroma:=(A+B+1) Shr 1 Else X4NcChroma:=A+B;
End;

Type X4Lum=Array[0..15] Of X4Arr;
Var
 X4LL: X4Lum; X4LNz: X4Arr; X4DcL: X4Arr; X4DcNz: LongInt;   { niveaux luma (AC
  par bloc), DC Intra16 }
 X4CL: Array[0..1,0..3] Of X4Arr; X4CNz: Array[0..1,0..3] Of LongInt; X4CDc:
  Array[0..1] Of X4Arr; X4CDcNz: Array[0..1] Of LongInt;
 X4DqL: X4Lum; X4DqC: Array[0..1,0..3] Of X4Arr;           { coefficients
  dequantifies }
 X4DcDq: X4Arr; X4CDcDq: Array[0..1] Of X4Arr;
 X4Mc: Array[0..255] Of LongInt; X4McC: Array[0..63] Of LongInt;
 X4Lamb: LongInt;

Function X4Plane(Base: PX4Buf; P: LongInt): PX4Buf;
Begin
 If P=0 Then X4Plane:=Base Else If P=1 Then X4Plane:=PX4Buf(@Base^[X4Wp*
  X4Hp]) Else X4Plane:=PX4Buf(@Base^[X4Wp*X4Hp+X4Cw*X4Ch]);
End;

{ Intra 16x16 : prediction dans Rec (mode), SAD vs source }
Function X4SadMb(Mx,My: LongInt): LongInt;
Begin
 X4SadMb:=X4Sad(PX4Buf(@X4Plane(X4Rec,0)^[My*16*X4Wp+Mx*16]),PX4Buf(
  @X4Plane(X4Src,0)^[My*16*X4Wp+Mx*16]),X4Wp,X4Wp,16,16);
End;
Procedure X4BestIntra(Mx,My: LongInt; Var BestMode,BestSad,BestCm,BestCsad:
 LongInt);
Var Mode,S,Sc: LongInt; AvL,AvT: Boolean;
Begin
 AvL:=Mx>0; AvT:=My>0;
 BestSad:=MaxLongInt; BestMode:=2;
 For Mode:=0 To 3 Do Begin
  If (Mode=0) And Not AvT Then Continue;
  If (Mode=1) And Not AvL Then Continue;
  If (Mode=3) And Not (AvL And AvT) Then Continue;
  X4ZPred16x16(X4Plane(X4Rec,0),X4Wp,Mx*16,My*16,Mode,AvL,AvT);
  S:=X4SadMb(Mx,My);
  If S<BestSad Then Begin BestSad:=S; BestMode:=Mode; End;
 End;
 BestCsad:=MaxLongInt; BestCm:=0;
 For Mode:=0 To 3 Do Begin
  If (Mode=1) And Not AvL Then Continue;
  If (Mode=2) And Not AvT Then Continue;
  If (Mode=3) And Not (AvL And AvT) Then Continue;
  X4ZPredChroma(X4Plane(X4Rec,1),X4Cw,Mx*8,My*8,Mode,AvL,AvT);
  X4ZPredChroma(X4Plane(X4Rec,2),X4Cw,Mx*8,My*8,Mode,AvL,AvT);
  Sc:=X4Sad(PX4Buf(@X4Plane(X4Rec,1)^[My*8*X4Cw+Mx*8]),PX4Buf(@X4Plane(
   X4Src,1)^[My*8*X4Cw+Mx*8]),X4Cw,X4Cw,8,8)
     +X4Sad(PX4Buf(@X4Plane(X4Rec,2)^[My*8*X4Cw+Mx*8]),PX4Buf(@X4Plane(
      X4Src,2)^[My*8*X4Cw+Mx*8]),X4Cw,X4Cw,8,8);
  If Sc<BestCsad Then Begin BestCsad:=Sc; BestCm:=Mode; End;
 End;
End;

{ residu 4x4 en (Bx,By) d'un plan : source - Rec (qui contient la prediction) }
Procedure X4Resid(P: LongInt; Bw,X,Y: LongInt; Var R: X4Arr);
Var I,J,Stride: LongInt; S,D: PX4Buf;
Begin
 If P=0 Then Stride:=X4Wp Else Stride:=X4Cw;
 S:=X4Plane(X4Src,P); D:=X4Plane(X4Rec,P);
 For J:=0 To 3 Do For I:=0 To 3 Do R[J*4+I]:=S^[(Y+J)*Stride+X+I]-D^[(Y+J)*
  Stride+X+I];
End;

{ ---- luma Intra16x16 : niveaux ---- }
Procedure X4LumaI16(Mx,My: LongInt);
Var B,K,I,Gx,Gy,Qb,F,Dc: LongInt; R: X4Arr; M,H,T: X4Arr; Lev15: Array[0..14] Of
 LongInt; Tmp: Array[0..15] Of LongInt; Z: LongInt;
Begin
 Qb:=15+X4Qp Div 6; F:=(1 Shl Qb) Div 3;
 For B:=0 To 15 Do Begin
  Gx:=X4BlkX[B]; Gy:=X4BlkY[B];
  X4Resid(0,0,Mx*16+Gx*4,My*16+Gy*4,R);
  X4LNz[B]:=X4QuantBlock(R,X4Qp,True,1,Tmp,X4DqL[B],Dc);
  For K:=0 To 14 Do X4LL[B][K]:=Tmp[K];
  M[Gy*4+Gx]:=Dc;
 End;
 { Hadamard 4x4 des DC }
 For I:=0 To 3 Do Begin
  T[I*4]:=M[I*4]+M[I*4+1]+M[I*4+2]+M[I*4+3];
  T[I*4+1]:=M[I*4]+M[I*4+1]-M[I*4+2]-M[I*4+3];
  T[I*4+2]:=M[I*4]-M[I*4+1]-M[I*4+2]+M[I*4+3];
  T[I*4+3]:=M[I*4]-M[I*4+1]+M[I*4+2]-M[I*4+3];
 End;
 For I:=0 To 3 Do Begin
  H[I]:=T[I]+T[4+I]+T[8+I]+T[12+I];
  H[4+I]:=T[I]+T[4+I]-T[8+I]-T[12+I];
  H[8+I]:=T[I]-T[4+I]-T[8+I]+T[12+I];
  H[12+I]:=T[I]-T[4+I]+T[8+I]-T[12+I];
 End;
 X4DcNz:=0;
 For K:=0 To 15 Do Begin
  X4DcL[K]:=X4Q(H[X4Zig[K]],X4MF[X4Qp Mod 6,0],Qb+2,4*F);
  If X4DcL[K]<>0 Then Inc(X4DcNz);
 End;
End;

{ reconstruction luma Intra16x16 selon Ac (blocs AC codes ou non) }
Procedure X4ReconI16(Mx,My: LongInt; Ac: Boolean);
Var B,I,Gx,Gy,K: LongInt; C,T,G: X4Arr; Ls: LongInt;
Begin
 FillChar(C,SizeOf(C),0);
 For K:=0 To 15 Do C[X4Zig[K]]:=X4DcL[K];
 For I:=0 To 3 Do Begin
  T[I*4]:=C[I*4]+C[I*4+1]+C[I*4+2]+C[I*4+3];
  T[I*4+1]:=C[I*4]+C[I*4+1]-C[I*4+2]-C[I*4+3];
  T[I*4+2]:=C[I*4]-C[I*4+1]-C[I*4+2]+C[I*4+3];
  T[I*4+3]:=C[I*4]-C[I*4+1]+C[I*4+2]-C[I*4+3];
 End;
 For I:=0 To 3 Do Begin
  G[I]:=T[I]+T[4+I]+T[8+I]+T[12+I];
  G[4+I]:=T[I]+T[4+I]-T[8+I]-T[12+I];
  G[8+I]:=T[I]-T[4+I]-T[8+I]+T[12+I];
  G[12+I]:=T[I]-T[4+I]+T[8+I]-T[12+I];
 End;
 Ls:=16*X4V[X4Qp Mod 6,0];
 For I:=0 To 15 Do
  If X4Qp>=36 Then G[I]:=(G[I]*Ls) Shl (X4Qp Div 6-6) Else G[I]:=SarLongint(G[I]*Ls+(
   1 Shl (5-X4Qp Div 6)),6-X4Qp Div 6);
 For B:=0 To 15 Do Begin
  Gx:=X4BlkX[B]; Gy:=X4BlkY[B];
  If Not Ac Then FillChar(X4DqL[B],SizeOf(X4Arr),0);
  X4DqL[B][0]:=G[Gy*4+Gx];
  X4ZIdct4(X4DqL[B],X4Plane(X4Rec,0),X4Wp,Mx*16+Gx*4,My*16+Gy*4);
 End;
End;

{ ---- luma inter : niveaux (16 coefficients par bloc) ---- }
Procedure X4LumaInter(Mx,My: LongInt);
Var B,K,Gx,Gy,Dc: LongInt; R: X4Arr; Tmp: Array[0..15] Of LongInt;
Begin
 For B:=0 To 15 Do Begin
  Gx:=X4BlkX[B]; Gy:=X4BlkY[B];
  X4Resid(0,0,Mx*16+Gx*4,My*16+Gy*4,R);
  X4LNz[B]:=X4QuantBlock(R,X4Qp,False,0,Tmp,X4DqL[B],Dc);
  For K:=0 To 15 Do X4LL[B][K]:=Tmp[K];
 End;
End;

{ ---- chroma : niveaux ; Intra selon prediction deja dans Rec ---- }
Procedure X4Chroma(Mx,My: LongInt; Intra: Boolean);
Var P,B,K,Bx,By,Qpc,Qb,F: LongInt; R: X4Arr; Tmp: Array[0..15] Of LongInt; Dc:
 LongInt; D: Array[0..3] Of LongInt; Fq: Array[0..3] Of LongInt;
Begin
 Qpc:=X4ZChromaQp(X4Qp,0); Qb:=15+Qpc Div 6;
 If Intra Then F:=(1 Shl Qb) Div 3 Else F:=(1 Shl Qb) Div 6;
 For P:=0 To 1 Do Begin
  For B:=0 To 3 Do Begin
   Bx:=B And 1; By:=B Shr 1;
   X4Resid(P+1,0,Mx*8+Bx*4,My*8+By*4,R);
   X4CNz[P,B]:=X4QuantBlock(R,Qpc,Intra,1,Tmp,X4DqC[P,B],Dc);
   For K:=0 To 14 Do X4CL[P,B][K]:=Tmp[K];
   D[B]:=Dc;
  End;
  Fq[0]:=D[0]+D[1]+D[2]+D[3]; Fq[1]:=D[0]-D[1]+D[2]-D[3]; Fq[2]:=D[0]+D[1]-D[2]-
   D[3]; Fq[3]:=D[0]-D[1]-D[2]+D[3];
  X4CDcNz[P]:=0;
  For K:=0 To 3 Do Begin
   X4CDc[P][K]:=X4Q(Fq[K],X4MF[Qpc Mod 6,0],Qb+1,2*F);
   If X4CDc[P][K]<>0 Then Inc(X4CDcNz[P]);
  End;
 End;
End;
{ reconstruction chroma : Mode 0 rien, 1 DC seulement, 2 DC + AC }
Procedure X4ReconChroma(Mx,My,Cbp: LongInt);
Var P,B,Bx,By,Qpc,Ls: LongInt; G: Array[0..3] Of LongInt; C: Array[0..3] Of
 LongInt;
Begin
 If Cbp=0 Then Exit;
 Qpc:=X4ZChromaQp(X4Qp,0); Ls:=16*X4V[Qpc Mod 6,0];
 For P:=0 To 1 Do Begin
  C[0]:=X4CDc[P][0]; C[1]:=X4CDc[P][1]; C[2]:=X4CDc[P][2]; C[3]:=X4CDc[P][3];
  G[0]:=C[0]+C[1]+C[2]+C[3]; G[1]:=C[0]-C[1]+C[2]-C[3]; G[2]:=C[0]+C[1]-C[2]-C[
   3]; G[3]:=C[0]-C[1]-C[2]+C[3];
  For B:=0 To 3 Do Begin
   Bx:=B And 1; By:=B Shr 1;
   If Cbp<2 Then FillChar(X4DqC[P,B],SizeOf(X4Arr),0);
   X4DqC[P,B][0]:=SarLongint((G[B]*Ls) Shl (Qpc Div 6),5);
   X4ZIdct4(X4DqC[P,B],X4Plane(X4Rec,P+1),X4Cw,Mx*8+Bx*4,My*8+By*4);
  End;
 End;
End;

{ ---- ecriture des residus ---- }
Procedure X4Lz(Var A: Array Of LongInt; N: LongInt); Var I: LongInt; Begin For
 I:=0 To N-1 Do A[I]:=0; End;
Procedure X4WriteChroma(Mx,My,Cbp: LongInt);
Var P,B,Bx,By,Nc,Tot: LongInt; Lv: X4Arr; Dc: Array[0..3] Of LongInt; Pl:
 PX4Buf;
Begin
 If Cbp=0 Then Exit;
 For P:=0 To 1 Do Begin
  For B:=0 To 3 Do Dc[B]:=X4CDc[P][B];
  X4Block(Dc,4,-1);
 End;
 If Cbp<2 Then Exit;
 For P:=0 To 1 Do Begin
  If P=0 Then Pl:=X4NnzU Else Pl:=X4NnzV;
  For B:=0 To 3 Do Begin
   Bx:=B And 1; By:=B Shr 1;
   Nc:=X4NcChroma(Pl,Mx*2+Bx,My*2+By);
   Tot:=X4Block(X4CL[P,B],15,Nc);
   Pl^[(My*2+By)*X4Mbw*2+Mx*2+Bx]:=Tot;
  End;
 End;
End;


{ ---- sortie : tampon croissant, NAL, MP4 ---- }
Const
 X4CbpTab: Array[0..47] Of Byte=(0,16,1,2,4,8,32,3,5,10,12,15,47,7,11,13,14,6,9,
  31,35,37,42,44,33,34,36,40,39,43,45,46,17,18,20,24,19,21,26,28,23,27,29,30,22,
  25,38,41);
Var
 X4O: PX4Buf; X4OLen,X4OCap: LongInt;
 X4Nb: PX4Buf; X4NbLen: LongInt;
 X4SpsB,X4PpsB: Array[0..255] Of Byte; X4SpsLen,X4PpsLen: LongInt;
 X4Fn,X4Fd: LongInt;

Procedure X4OB(V: Int64);
Begin
 If X4OLen>=X4OCap Then Begin X4OCap:=X4OCap*2; ReallocMem(Pointer(X4O),X4OCap);
  End;
 X4O^[X4OLen]:=Byte(V And 255); Inc(X4OLen);
End;
Procedure X4O32(V: Int64); Begin X4OB(V Shr 24); X4OB(V Shr 16); X4OB(V Shr
 8); X4OB(V); End;
Procedure X4O16(V: LongInt); Begin X4OB(V Shr 8); X4OB(V); End;
Procedure X4OTag(Const S: String); Var I: LongInt; Begin For I:=1 To 4 Do X4OB(
 Ord(S[I])); End;
Procedure X4OPatch32(At,V: LongInt);
Begin X4O^[At]:=(V Shr 24) And 255; X4O^[At+1]:=(V Shr 16) And 255;
 X4O^[At+2]:=(V Shr 8) And 255; X4O^[At+3]:=V And 255; End;
{ ouvre une boite : renvoie la position de sa taille }
Function X4BoxB(Const Tag: String): LongInt;
Begin X4BoxB:=X4OLen; X4O32(0); X4OTag(Tag); End;
Procedure X4BoxE(At: LongInt); Begin X4OPatch32(At,X4OLen-At); End;

{ construit le NAL (en-tete + RBSP echappe) dans X4Nb a partir de X4Rb (arret
 deja ecrit) }
Procedure X4NalBuild(RefIdc,Typ: LongInt);
Var I,N,Z: LongInt;
Begin
 N:=X4RbBits Shr 3; X4NbLen:=0;
 X4Nb^[0]:=(RefIdc Shl 5) Or Typ; X4NbLen:=1; Z:=0;
 For I:=0 To N-1 Do Begin
  If (Z>=2) And (X4Rb^[I]<=3) Then Begin X4Nb^[X4NbLen]:=3; Inc(X4NbLen); Z:=0;
   End;
  X4Nb^[X4NbLen]:=X4Rb^[I]; Inc(X4NbLen);
  If X4Rb^[I]=0 Then Inc(Z) Else Z:=0;
 End;
End;
Procedure X4EmitNal;
Var I: LongInt;
Begin
 X4O32(X4NbLen);
 For I:=0 To X4NbLen-1 Do X4OB(X4Nb^[I]);
End;

Procedure X4WriteSps(W,H: LongInt; Lvl: LongInt; Hd: Boolean);
Var CropX,CropY: LongInt;
Begin
 FillChar(X4Rb^,512,0); X4RbBits:=0;
 X4Put(66,8); X4Put($C0,8); X4Put(Lvl,8);
 X4Ue(0);                         { sps_id }
 X4Ue(4);                         { log2_max_frame_num-4 : 8 bits }
 X4Ue(2);                         { pic_order_cnt_type }
 X4Ue(1);                         { num_ref_frames }
 X4Put(0,1);                      { gaps }
 X4Ue(X4Mbw-1); X4Ue(X4Mbh-1);
 X4Put(1,1);                      { frame_mbs_only }
 X4Put(1,1);                      { direct_8x8_inference }
 CropX:=(X4Wp-W) Div 2; CropY:=(X4Hp-H) Div 2;
 If (CropX>0) Or (CropY>0) Then Begin
  X4Put(1,1); X4Ue(0); X4Ue(CropX); X4Ue(0); X4Ue(CropY);
 End Else X4Put(0,1);
 X4Put(1,1);                      { vui_parameters_present }
 X4Put(0,1);                      { aspect_ratio_info_present }
 X4Put(0,1);                      { overscan_info_present }
 X4Put(1,1); X4Put(5,3); X4Put(0,1); X4Put(1,1);  { video_signal_type : format
  non specifie, plage limitee, description des couleurs }
 If Hd Then Begin X4Put(1,8); X4Put(1,8); X4Put(1,8); End   { BT.709 }
 Else Begin X4Put(6,8); X4Put(6,8); X4Put(6,8); End;         { BT.601 }
 X4Put(0,1);                      { chroma_loc }
 X4Put(1,1);                      { timing_info_present }
 X4Put(X4Fd,32); X4Put(Int64(X4Fn)*2,32); X4Put(1,1);
 X4Put(0,1); X4Put(0,1);          { nal_hrd, vcl_hrd }
 X4Put(0,1);                      { pic_struct_present }
 X4Put(1,1);                      { bitstream_restriction }
 X4Put(1,1);                      { motion_vectors_over_pic_boundaries }
 X4Ue(0); X4Ue(0);                { max_bytes_per_pic_denom,
  max_bits_per_mb_denom }
 X4Ue(16); X4Ue(16);              { log2_max_mv_length }
 X4Ue(0); X4Ue(1);                { num_reorder_frames, max_dec_frame_buffering
  }
 X4Trail;
 X4NalBuild(3,7);
 X4SpsLen:=X4NbLen; Move(X4Nb^[0],X4SpsB[0],X4NbLen);
End;
Procedure X4WritePps;
Begin
 FillChar(X4Rb^,64,0); X4RbBits:=0;
 X4Ue(0); X4Ue(0); X4Put(0,1); X4Put(0,1);
 X4Ue(0);                         { num_slice_groups-1 }
 X4Ue(0); X4Ue(0);                { num_ref_idx_default-1 }
 X4Put(0,1); X4Put(0,2);          { weighted_pred, weighted_bipred }
 X4Se(0); X4Se(0); X4Se(0);       { pic_init_qp-26, qs, chroma_qp_index_offset }
 X4Put(1,1);                      { deblocking_filter_control_present }
 X4Put(0,1); X4Put(0,1);          { constrained_intra_pred,
  redundant_pic_cnt_present }
 X4Trail;
 X4NalBuild(3,8);
 X4PpsLen:=X4NbLen; Move(X4Nb^[0],X4PpsB[0],X4NbLen);
End;

{ ---- macroblocs ---- }
Procedure X4ClearNnz(Mx,My: LongInt);
Var I,J: LongInt;
Begin
 For J:=0 To 3 Do For I:=0 To 3 Do X4NnzY^[(My*4+J)*X4Mbw*4+Mx*4+I]:=0;
 For J:=0 To 1 Do For I:=0 To 1 Do Begin
  X4NnzU^[(My*2+J)*X4Mbw*2+Mx*2+I]:=0; X4NnzV^[(My*2+J)*X4Mbw*2+Mx*2+I]:=0;
 End;
End;
Procedure X4SetInfo(Mx,My,Kind,Vx,Vy: LongInt);
Begin X4Kind^[My*X4Mbw+Mx]:=Kind; X4Mvx^[My*X4Mbw+Mx]:=Vx; X4Mvy^[My*X4Mbw+Mx]:=
 Vy; End;

Procedure X4MbIntra(Mx,My,Mode,Cm: LongInt);
Var Ac,CAc,CDc,AvL,AvT: Boolean; CbpC,B,P,Gx,Gy,Nc,Tot: LongInt;
Begin
 AvL:=Mx>0; AvT:=My>0;
 X4ZPred16x16(X4Plane(X4Rec,0),X4Wp,Mx*16,My*16,Mode,AvL,AvT);
 X4ZPredChroma(X4Plane(X4Rec,1),X4Cw,Mx*8,My*8,Cm,AvL,AvT);
 X4ZPredChroma(X4Plane(X4Rec,2),X4Cw,Mx*8,My*8,Cm,AvL,AvT);
 X4LumaI16(Mx,My);
 Ac:=False; For B:=0 To 15 Do If X4LNz[B]>0 Then Ac:=True;
 X4Chroma(Mx,My,True);
 CAc:=False; CDc:=False;
 For P:=0 To 1 Do Begin
  If X4CDcNz[P]>0 Then CDc:=True;
  For B:=0 To 3 Do If X4CNz[P,B]>0 Then CAc:=True;
 End;
 If CAc Then CbpC:=2 Else If CDc Then CbpC:=1 Else CbpC:=0;
 X4ReconI16(Mx,My,Ac);
 X4ReconChroma(Mx,My,CbpC);
 If X4Inter Then Begin X4Ue(X4SkipRun); X4SkipRun:=0; End;
 X4ClearNnz(Mx,My);
 X4Ue(Ord(X4Inter)*5+1+Mode+4*CbpC+12*Ord(Ac));
 X4Ue(Cm); X4Se(0);
 X4Block(X4DcL,16,X4NcLuma(Mx*4,My*4));
 If Ac Then For B:=0 To 15 Do Begin
  Gx:=Mx*4+X4BlkX[B]; Gy:=My*4+X4BlkY[B];
  Nc:=X4NcLuma(Gx,Gy); Tot:=X4Block(X4LL[B],15,Nc);
  X4NnzY^[Gy*X4Mbw*4+Gx]:=Tot;
 End;
 X4WriteChroma(Mx,My,CbpC);
 X4SetInfo(Mx,My,0,0,0);
End;

Function X4Bits(V: LongInt): LongInt;
Var N: LongInt;
Begin
 If V<0 Then V:=-V;
 V:=2*V+1; N:=0; While V>1 Do Begin V:=V Shr 1; Inc(N); End;
 X4Bits:=2*N+1;
End;

{ SAD luma 16x16 a un vecteur au quart de pixel }
Function X4SadMv(Mx,My,Vx,Vy,Lim: LongInt): LongInt;
Var X,Y,Fx,Fy,I,J,S,D: LongInt; Sp,Rp,Ra,Rb: PX4Buf;
Begin
 X:=Mx*16+SarLongint(Vx,2); Y:=My*16+SarLongint(Vy,2); Fx:=Vx And 3; Fy:=Vy And 3;
 Sp:=X4Plane(X4Src,0); Rp:=X4Plane(X4Ref,0); S:=0;
 If (Fx=0) And (Fy=0) And (X>=0) And (Y>=0) And (X<=X4Wp-16) And (Y<=X4Hp-16)
  Then Begin
  For J:=0 To 15 Do Begin
   Ra:=PX4Buf(@Sp^[(My*16+J)*X4Wp+Mx*16]); Rb:=PX4Buf(@Rp^[(Y+J)*X4Wp+X]);
   For I:=0 To 15 Do Begin D:=Ra^[I]-Rb^[I]; If D<0 Then D:=-D; Inc(S,D); End;
   If S>Lim Then Break;
  End;
 End Else Begin
  X4ZMcLuma(Rp,X,Y,Fx,Fy,16,16,PX4LArr(@X4Mc));
  For J:=0 To 15 Do Begin
   Ra:=PX4Buf(@Sp^[(My*16+J)*X4Wp+Mx*16]);
   For I:=0 To 15 Do Begin D:=Ra^[I]-X4Mc[J*16+I]; If D<0 Then D:=-D; Inc(S,D);
    End;
   If S>Lim Then Break;
  End;
 End;
 X4SadMv:=S;
End;

Procedure X4MbInter(Mx,My: LongInt; Const Mvp: Array Of LongInt; SkipOk:
 Boolean; Vx,Vy,SkX,SkY: LongInt);
Var X,Y,Fx,Fy,I,J,B,B8,P,Cbp,CbpL,CbpC,Gx,Gy,Nc,Tot,Sum,K: LongInt; CAc,CDc:
 Boolean; Rp,Dp: PX4Buf;
Begin
 X:=Mx*16+SarLongint(Vx,2); Y:=My*16+SarLongint(Vy,2); Fx:=Vx And 3; Fy:=Vy And 3;
 Dp:=X4Plane(X4Rec,0);
 X4ZMcLuma(X4Plane(X4Ref,0),X,Y,Fx,Fy,16,16,PX4LArr(@X4Mc));
 For J:=0 To 15 Do For I:=0 To 15 Do Dp^[(My*16+J)*X4Wp+Mx*16+I]:=X4Mc[J*16+I];
 X:=Mx*8+SarLongint(Vx,3); Y:=My*8+SarLongint(Vy,3); Fx:=Vx And 7; Fy:=Vy And 7;
 For P:=1 To 2 Do Begin
  X4ZMcChroma(X4Plane(X4Ref,P),X,Y,Fx,Fy,8,8,PX4LArr(@X4McC));
  Dp:=X4Plane(X4Rec,P);
  For J:=0 To 7 Do For I:=0 To 7 Do Dp^[(My*8+J)*X4Cw+Mx*8+I]:=X4McC[J*8+I];
 End;
 X4LumaInter(Mx,My);
 CbpL:=0;
 For B8:=0 To 3 Do Begin
  Sum:=0;
  For B:=B8*4 To B8*4+3 Do For K:=0 To 15 Do Sum:=Sum+Abs(X4LL[B][K]);
  { elimination des groupes dont le residu est negligeable }
  If Sum<=2 Then Begin
   For B:=B8*4 To B8*4+3 Do Begin X4LNz[B]:=0; FillChar(X4DqL[B],SizeOf(X4Arr),
    0); FillChar(X4LL[B],SizeOf(X4Arr),0); End;
  End Else
   CbpL:=CbpL Or (1 Shl B8);
 End;
 For B:=0 To 15 Do X4ZIdct4(X4DqL[B],X4Plane(X4Rec,0),X4Wp,Mx*16+X4BlkX[B]*4,My*
  16+X4BlkY[B]*4);
 X4Chroma(Mx,My,False);
 CAc:=False; CDc:=False;
 For P:=0 To 1 Do Begin
  If X4CDcNz[P]>0 Then CDc:=True;
  For B:=0 To 3 Do If X4CNz[P,B]>0 Then CAc:=True;
 End;
 { chroma negligeable : un seul coefficient +-1 }
 If CAc Then CbpC:=2 Else If CDc Then CbpC:=1 Else CbpC:=0;
 X4ReconChroma(Mx,My,CbpC);
 Cbp:=CbpL Or (CbpC Shl 4);
 X4ClearNnz(Mx,My);
 If SkipOk And (Cbp=0) And (Vx=SkX) And (Vy=SkY) Then Begin
  Inc(X4SkipRun); X4SetInfo(Mx,My,2,Vx,Vy); Exit;
 End;
 X4Ue(X4SkipRun); X4SkipRun:=0;
 X4Ue(0);
 X4Se(Vx-Mvp[0]); X4Se(Vy-Mvp[1]);
 X4Ue(X4CbpInv[Cbp]);
 If Cbp<>0 Then Begin
  X4Se(0);
  For B8:=0 To 3 Do If (CbpL And (1 Shl B8))<>0 Then
   For B:=B8*4 To B8*4+3 Do Begin
    Gx:=Mx*4+X4BlkX[B]; Gy:=My*4+X4BlkY[B];
    Nc:=X4NcLuma(Gx,Gy); Tot:=X4Block(X4LL[B],16,Nc);
    X4NnzY^[Gy*X4Mbw*4+Gx]:=Tot;
   End;
  X4WriteChroma(Mx,My,CbpC);
 End;
 X4SetInfo(Mx,My,1,Vx,Vy);
End;

{ ---- image ---- }
Function X4EncodeFrame(Idr: Boolean; FrameNum,Qp,IdrId: LongInt): LongInt;
Var
 Mx,My,Mode,Cm,IS1,IS2,Cs,Best,Bx,By,Px,Py,Vx,Vy,Sx,Sy,It,Dx,Dy,C0,Bc,Si,Pmx,
  Pmy: LongInt;
 AvA,AvB: Boolean; RA,RB,Ax,Ay,Bx2,By2: LongInt; Mvp: Array[0..1] Of LongInt;
  Improved: Boolean; BestSad,IntraCost,InterCost,SkipCost: LongInt;
 Cand: Array[0..4,0..1] Of LongInt; Ci: LongInt;
 Function Cost(Ex,Ey: LongInt): LongInt;
 Var Lm: LongInt;
 Begin
  Lm:=X4Lam*(X4Bits(Ex-Mvp[0])+X4Bits(Ey-Mvp[1]));
  Cost:=X4SadMv(Mx,My,Ex,Ey,Bc-Lm)+Lm;
 End;
 Function Inside(Ex,Ey: LongInt): Boolean;
 Var Xp,Yp: LongInt;
 Begin
  Xp:=Mx*16+SarLongint(Ex,2); Yp:=My*16+SarLongint(Ey,2);
  Inside:=(Xp>=-8) And (Yp>=-8) And (Xp<=X4Wp-8) And (Yp<=X4Hp-8) And (Abs(
   Ex)<=128) And (Abs(Ey)<=128);
 End;
Begin
 X4Qp:=Qp; X4Inter:=Not Idr;
 X4Lam:=Round(Exp(Ln(2)*(Qp-12)/6)); If X4Lam<1 Then X4Lam:=1;
 FillChar(X4Rb^,X4RbDirty,0); X4RbBits:=0;
 X4ZMbW:=X4Mbw; X4ZMbH:=X4Mbh;
 { en-tete de tranche }
 X4Ue(0); If Idr Then X4Ue(7) Else X4Ue(5); X4Ue(0); X4Put(FrameNum And 255,8);
 If Idr Then X4Ue(IdrId And 1) Else Begin X4Put(0,1); X4Put(0,1); End;
 If Idr Then Begin X4Put(0,1); X4Put(0,1); End Else X4Put(0,1);
 X4Se(Qp-26); X4Ue(1);
 X4SkipRun:=0;
 FillChar(X4NnzY^,X4Mbw*X4Mbh*16,0); FillChar(X4NnzU^,X4Mbw*X4Mbh*4,0);
  FillChar(X4NnzV^,X4Mbw*X4Mbh*4,0);
 For My:=0 To X4Mbh-1 Do For Mx:=0 To X4Mbw-1 Do Begin
  X4BestIntra(Mx,My,Mode,IS1,Cm,IS2);
  IntraCost:=IS1+IS2 Div 2;
  If Idr Then Begin X4MbIntra(Mx,My,Mode,Cm); Continue; End;
  X4Mvp(Mx,My,Px,Py,AvA,AvB,RA,RB,Ax,Ay,Bx2,By2);
  Mvp[0]:=Px; Mvp[1]:=Py;
  { vecteur du saut }
  If (Not AvA) Or (Not AvB) Or ((RA=0) And (Ax=0) And (Ay=0)) Or ((RB=0) And (
   Bx2=0) And (By2=0)) Then Begin Sx:=0; Sy:=0; End Else Begin Sx:=Px; Sy:=Py;
   End;
  { recherche entiere }
  Cand[0,0]:=0; Cand[0,1]:=0;
  Cand[1,0]:=(Px+2) And Not 3; Cand[1,1]:=(Py+2) And Not 3;
  Cand[2,0]:=(Sx+2) And Not 3; Cand[2,1]:=(Sy+2) And Not 3;
  If Mx>0 Then Begin Cand[3,0]:=(X4Mvx^[My*X4Mbw+Mx-1]+2) And Not 3; Cand[3,1]:=
   (X4Mvy^[My*X4Mbw+Mx-1]+2) And Not 3; End Else Begin Cand[3,0]:=0; Cand[3,1]:=
   0; End;
  If My>0 Then Begin Cand[4,0]:=(X4Mvx^[(My-1)*X4Mbw+Mx]+2) And Not 3; Cand[4,
   1]:=(X4Mvy^[(My-1)*X4Mbw+Mx]+2) And Not 3; End Else Begin Cand[4,0]:=0; Cand[
   4,1]:=0; End;
  Vx:=0; Vy:=0; Bc:=MaxLongInt;
  For Ci:=0 To 4 Do If Inside(Cand[Ci,0],Cand[Ci,1]) Then Begin
   C0:=Cost(Cand[Ci,0],Cand[Ci,1]);
   If C0<Bc Then Begin Bc:=C0; Vx:=Cand[Ci,0]; Vy:=Cand[Ci,1]; End;
  End;
  For It:=1 To 48 Do Begin
   Improved:=False; Bx:=Vx; By:=Vy;
   For Si:=0 To 3 Do Begin
    Case Si Of 0: Begin Dx:=4; Dy:=0; End; 1: Begin Dx:=-4; Dy:=0; End; 2: Begin
     Dx:=0; Dy:=4; End; Else Begin Dx:=0; Dy:=-4; End; End;
    If Inside(Vx+Dx,Vy+Dy) Then Begin
     C0:=Cost(Vx+Dx,Vy+Dy);
     If C0<Bc Then Begin Bc:=C0; Bx:=Vx+Dx; By:=Vy+Dy; Improved:=True; End;
    End;
   End;
   Vx:=Bx; Vy:=By;
   If Not Improved Then Break;
  End;
  { demi puis quart de pixel (4 voisins) }
  For It:=0 To 1 Do Begin
   Bx:=Vx; By:=Vy; Dx:=2 Shr It;
   For Si:=0 To 3 Do Begin   { croix seulement : bon compromis vitesse/debit
     }
    Case Si Of 0: Begin Sx:=Dx; Sy:=0; End; 1: Begin Sx:=-Dx; Sy:=0; End; 2:
     Begin Sx:=0; Sy:=Dx; End; 3: Begin Sx:=0; Sy:=-Dx; End;
     4: Begin Sx:=Dx; Sy:=Dx; End; 5: Begin Sx:=-Dx; Sy:=Dx; End; 6: Begin Sx:=
      Dx; Sy:=-Dx; End; Else Begin Sx:=-Dx; Sy:=-Dx; End; End;
    If Inside(Vx+Sx,Vy+Sy) Then Begin
     C0:=Cost(Vx+Sx,Vy+Sy);
     If C0<Bc Then Begin Bc:=C0; Bx:=Vx+Sx; By:=Vy+Sy; End;
    End;
   End;
   Vx:=Bx; Vy:=By;
  End;
  { vecteur du saut recalcule (Sx,Sy ont ete reutilises) }
  If (Not AvA) Or (Not AvB) Or ((RA=0) And (Ax=0) And (Ay=0)) Or ((RB=0) And (
   Bx2=0) And (By2=0)) Then Begin Sx:=0; Sy:=0; End Else Begin Sx:=Px; Sy:=Py;
   End;
  InterCost:=Bc;
  If Inside(Sx,Sy) Then Begin
   SkipCost:=X4SadMv(Mx,My,Sx,Sy,Bc);
   If SkipCost<=Bc Then Begin Vx:=Sx; Vy:=Sy; InterCost:=SkipCost; End;
  End;
  If IntraCost+4*X4Lam*6<InterCost Then X4MbIntra(Mx,My,Mode,Cm)
  Else X4MbInter(Mx,My,Mvp,True,Vx,Vy,Sx,Sy);
 End;
 If X4SkipRun>0 Then Begin X4Ue(X4SkipRun); X4SkipRun:=0; End;
 X4Trail;
 X4RbDirty:=(X4RbBits Shr 3)+2; If X4RbDirty>X4RbCap Then X4RbDirty:=X4RbCap;
 X4EncodeFrame:=X4RbBits;
End;


{ ======================= API image par image + MP4 ======================= }
Type
 TX4LBig=Array[0..536870000] Of LongInt;
 PX4LBig=^TX4LBig;
Var
 X4EOn: Boolean;                 { session ouverte }
 X4EOutW,X4EOutH: LongInt;       { taille reellement codee (paire) }
 X4EF: File;                     { fichier MP4 en cours d'ecriture }
 X4EName: String;
 X4EReqW,X4EReqH,X4EGop,X4EQpv,X4EArate: LongInt;
 X4EN,X4ECap,X4EIdrCnt,X4EFrNum: LongInt;
 X4ESz: PX4LBig; X4EKey: PX4Buf;
 X4EPos: Int64;                  { position d'ecriture dans le fichier }
 X4EMdatAt: Int64;               { position de l'en-tete 'mdat' }
 X4EHd: Boolean;                 { BT.709 }
 X4ELvl: LongInt;
 X4EFail: Boolean;

Procedure X4ERelease;
Begin
 If X4Src<>Nil Then Begin FreeMem(X4Src); X4Src:=Nil; End;
 If X4Rec<>Nil Then Begin FreeMem(X4Rec); X4Rec:=Nil; End;
 If X4Ref<>Nil Then Begin FreeMem(X4Ref); X4Ref:=Nil; End;
 If X4Rb<>Nil Then Begin FreeMem(X4Rb); X4Rb:=Nil; End;
 If X4Nb<>Nil Then Begin FreeMem(X4Nb); X4Nb:=Nil; End;
 If X4NnzY<>Nil Then Begin FreeMem(X4NnzY); X4NnzY:=Nil; End;
 If X4NnzU<>Nil Then Begin FreeMem(X4NnzU); X4NnzU:=Nil; End;
 If X4NnzV<>Nil Then Begin FreeMem(X4NnzV); X4NnzV:=Nil; End;
 If X4Kind<>Nil Then Begin FreeMem(X4Kind); X4Kind:=Nil; End;
 If X4Mvx<>Nil Then Begin FreeMem(X4Mvx); X4Mvx:=Nil; End;
 If X4Mvy<>Nil Then Begin FreeMem(X4Mvy); X4Mvy:=Nil; End;
 If X4O<>Nil Then Begin FreeMem(X4O); X4O:=Nil; End;
 If X4ESz<>Nil Then Begin FreeMem(X4ESz); X4ESz:=Nil; End;
 If X4EKey<>Nil Then Begin FreeMem(X4EKey); X4EKey:=Nil; End;
 X4ECap:=0; X4OLen:=0; X4OCap:=0;
End;

Function X4EWr(Const Buf; N: LongInt): Boolean;
Var Done: LongInt;
Begin
 X4EWr:=False;
 If N<=0 Then Begin X4EWr:=True; Exit; End;
 If X4EPos+N>4000000000 Then Exit;
 {$I-}
 BlockWrite(X4EF,Buf,N,Done);
 {$I+}
 If (IOResult<>0) Or (Done<>N) Then Exit;
 Inc(X4EPos,N);
 X4EWr:=True;
End;

Function X4EGcd(A,B: LongInt): LongInt;
Var T: LongInt;
Begin While B<>0 Do Begin T:=A Mod B; A:=B; B:=T; End; X4EGcd:=A; End;

Procedure X4EAbort;
Begin
 If X4EOn Then Begin
  {$I-}
  Close(X4EF); If IOResult<>0 Then ;
  Erase(X4EF); If IOResult<>0 Then ;
  {$I+}
 End;
 X4EOn:=False;
 X4ERelease;
End;

Function X4EBegin(Const FN: String; W, H, Fps100, Qp, Gop: LongInt; AudioRate: LongInt): Boolean;
Var Used,I,G: LongInt;
Begin
 X4EBegin:=False;
 If X4EOn Then X4EAbort;
 X4Src:=Nil; X4Rec:=Nil; X4Ref:=Nil; X4Rb:=Nil; X4Nb:=Nil; X4NnzY:=Nil; X4NnzU:=Nil;
 X4NnzV:=Nil; X4Kind:=Nil; X4Mvx:=Nil; X4Mvy:=Nil; X4O:=Nil; X4ESz:=Nil; X4EKey:=Nil;
 If (W<16) Or (H<16) Or (W>4096) Or (H>4096) Then Exit;
 If (Fps100<1) Or (Fps100>6000000) Then Exit;
 If Qp<10 Then Qp:=10; If Qp>45 Then Qp:=45;
 If AudioRate<0 Then AudioRate:=0;
 If AudioRate>384000 Then Exit;
 X4EReqW:=W; X4EReqH:=H; X4EGop:=Gop; X4EQpv:=Qp; X4EArate:=AudioRate;
 X4EOutW:=W+(W And 1); X4EOutH:=H+(H And 1);
 X4Mbw:=(X4EOutW+15) Div 16; X4Mbh:=(X4EOutH+15) Div 16;
 X4Wp:=X4Mbw*16; X4Hp:=X4Mbh*16; X4Cw:=X4Wp Div 2; X4Ch:=X4Hp Div 2;
 If X4Mbw*X4Mbh>X4EMaxMb Then Exit;
 If X4Mbw*X4Mbh>36864 Then X4ELvl:=62 Else If X4Mbw*X4Mbh>8192 Then X4ELvl:=51
 Else X4ELvl:=40;
 X4EHd:=H>=720;
 G:=X4EGcd(Fps100,100); X4Fn:=Fps100 Div G; X4Fd:=100 Div G;
 X4EName:=FN;
 Assign(X4EF,FN);
 {$I-}
 Rewrite(X4EF,1);
 {$I+}
 If IOResult<>0 Then Exit;
 X4EOn:=True; X4EFail:=False; X4EPos:=0; X4EN:=0; X4EIdrCnt:=0; X4EFrNum:=0;
 Used:=X4Wp*X4Hp*3 Div 2;
 GetMem(X4Src,Used+64); GetMem(X4Rec,Used+64); GetMem(X4Ref,Used+64);
 FillChar(X4Src^,Used+64,128); FillChar(X4Rec^,Used+64,128);
 FillChar(X4Ref^,Used+64,128);
 X4RbCap:=Used*3+65536; X4RbDirty:=X4RbCap; X4RbBits:=0; X4Err:=False;
 GetMem(X4Rb,X4RbCap+16); FillChar(X4Rb^,X4RbCap+16,0);
 GetMem(X4Nb,X4RbCap+X4RbCap Div 2+64);
 GetMem(X4NnzY,X4Mbw*X4Mbh*16+16); GetMem(X4NnzU,X4Mbw*X4Mbh*4+16);
 GetMem(X4NnzV,X4Mbw*X4Mbh*4+16); GetMem(X4Kind,X4Mbw*X4Mbh+16);
 GetMem(X4Mvx,X4Mbw*X4Mbh*4+16); GetMem(X4Mvy,X4Mbw*X4Mbh*4+16);
 FillChar(X4Kind^,X4Mbw*X4Mbh+16,0); FillChar(X4Mvx^,X4Mbw*X4Mbh*4+16,0);
 FillChar(X4Mvy^,X4Mbw*X4Mbh*4+16,0);
 X4OCap:=1 Shl 16; GetMem(X4O,X4OCap); X4OLen:=0;
 X4ECap:=1024; GetMem(X4ESz,X4ECap*4); GetMem(X4EKey,X4ECap);
 For I:=0 To 47 Do X4CbpInv[X4CbpTab[I]]:=I;
 X4WriteSps(X4EOutW,X4EOutH,X4ELvl,X4EHd); X4WritePps;
 { ftyp + en-tete mdat }
 X4OLen:=0;
 X4O32(28); X4OTag('ftyp'); X4OTag('isom'); X4O32(512); X4OTag('isom');
 X4OTag('avc1'); X4OTag('mp41');
 X4EMdatAt:=X4OLen; X4O32(0); X4OTag('mdat');
 If Not X4EWr(X4O^[0],X4OLen) Then Begin X4EAbort; Exit; End;
 X4OLen:=0;
 X4EBegin:=True;
End;

{ RGB24 -> YUV 4:2:0 (plage limitee) dans X4Src, avec replication des bords }
Procedure X4EConvert(Pix: PX4Buf);
Var Cy,Cx,X0,X1,Y0,Y1,R,G,B,Sr,Sg,Sb,Yr,Yg,Yb,Ur,Ug,Ub,Vr,Vg,Vb,Yv,Uv,Vv,K,
 Wl,Hl: LongInt; Py,Pu,Pv: PX4Buf; Rows: Array[0..1] Of LongInt;
 Cols: Array[0..1] Of LongInt;
Begin
 If X4EHd Then Begin Yr:=47; Yg:=157; Yb:=16; Ur:=-26; Ug:=-87; Ub:=112;
  Vr:=112; Vg:=-102; Vb:=-10; End
 Else Begin Yr:=66; Yg:=129; Yb:=25; Ur:=-38; Ug:=-74; Ub:=112; Vr:=112;
  Vg:=-94; Vb:=-18; End;
 Wl:=X4EReqW; Hl:=X4EReqH;
 Py:=X4Plane(X4Src,0); Pu:=X4Plane(X4Src,1); Pv:=X4Plane(X4Src,2);
 For Cy:=0 To X4Ch-1 Do Begin
  Y0:=Cy*2; Y1:=Y0+1; If Y0>Hl-1 Then Y0:=Hl-1; If Y1>Hl-1 Then Y1:=Hl-1;
  Rows[0]:=Y0*Wl; Rows[1]:=Y1*Wl;
  For Cx:=0 To X4Cw-1 Do Begin
   X0:=Cx*2; X1:=X0+1; If X0>Wl-1 Then X0:=Wl-1; If X1>Wl-1 Then X1:=Wl-1;
   Cols[0]:=X0; Cols[1]:=X1;
   Sr:=0; Sg:=0; Sb:=0;
   For K:=0 To 3 Do Begin
    G:=(Rows[K Shr 1]+Cols[K And 1])*3;
    R:=Pix^[G]; B:=Pix^[G+2]; G:=Pix^[G+1];
    Inc(Sr,R); Inc(Sg,G); Inc(Sb,B);
    Yv:=16+((Yr*R+Yg*G+Yb*B+128) Shr 8);
    If Yv>235 Then Yv:=235;
    Py^[(Cy*2+(K Shr 1))*X4Wp+Cx*2+(K And 1)]:=Yv;
   End;
   Uv:=128+SarLongint(Ur*Sr+Ug*Sg+Ub*Sb+512,10);
   Vv:=128+SarLongint(Vr*Sr+Vg*Sg+Vb*Sb+512,10);
   If Uv<16 Then Uv:=16 Else If Uv>240 Then Uv:=240;
   If Vv<16 Then Vv:=16 Else If Vv>240 Then Vv:=240;
   Pu^[Cy*X4Cw+Cx]:=Uv; Pv^[Cy*X4Cw+Cx]:=Vv;
  End;
 End;
End;

Function X4EFrame(Pix: Pointer): Boolean;
Var Idr: Boolean; Tmp: PX4Buf; NewCap: LongInt;
Begin
 X4EFrame:=False;
 If (Not X4EOn) Or X4EFail Or (Pix=Nil) Then Exit;
 If X4EN>=X4ECap Then Begin
  NewCap:=X4ECap*2;
  ReallocMem(Pointer(X4ESz),NewCap*4); ReallocMem(Pointer(X4EKey),NewCap);
  X4ECap:=NewCap;
 End;
 X4EConvert(PX4Buf(Pix));
 Idr:=(X4EN=0) Or ((X4EGop>0) And (X4EN Mod X4EGop=0));
 If Idr Then Begin X4EFrNum:=0; Inc(X4EIdrCnt); End;
 X4Err:=False;
 X4EncodeFrame(Idr,X4EFrNum,X4EQpv,X4EIdrCnt);
 If X4Err Then Begin X4EFail:=True; Exit; End;
 If Idr Then X4NalBuild(3,5) Else X4NalBuild(2,1);
 X4OLen:=0; X4EmitNal;
 If Not X4EWr(X4O^[0],X4OLen) Then Begin X4EFail:=True; Exit; End;
 X4ESz^[X4EN]:=X4OLen; If Idr Then X4EKey^[X4EN]:=1 Else X4EKey^[X4EN]:=0;
 Inc(X4EN); Inc(X4EFrNum);
 X4OLen:=0;
 Tmp:=X4Rec; X4Rec:=X4Ref; X4Ref:=Tmp;
 X4EFrame:=True;
End;

{ ---- moov ---- }

Procedure X4EWriteMoov(VidOff: Int64; AudOff: Int64; AudFrames: LongInt);
Const Hv: String='VideoHandler'; Ha: String='SoundHandler';
Var Moov,Trak,Mdia,Minf,Stbl,Stsd,Avc1,AvcC,B,I,KeyCount,Dc,Dr,Chunks,Rem,
 NextId: LongInt; VidMs,AudMs,TotMs: Int64; Off: Int64; Ent: LongInt;
Begin
 VidMs:=Int64(X4EN)*X4Fd*1000 Div X4Fn;
 AudMs:=0;
 If AudFrames>0 Then AudMs:=Int64(AudFrames)*1000 Div X4EArate;
 TotMs:=VidMs; If AudMs>TotMs Then TotMs:=AudMs;
 If AudFrames>0 Then NextId:=3 Else NextId:=2;
 X4OLen:=0;
 Moov:=X4BoxB('moov');
 B:=X4BoxB('mvhd'); X4O32(0); X4O32(0); X4O32(0); X4O32(1000); X4O32(TotMs);
  X4O32($10000); X4O16($100); X4O16(0); X4O32(0); X4O32(0);
 X4O32($10000); X4O32(0); X4O32(0); X4O32(0); X4O32($10000); X4O32(0); X4O32(0);
  X4O32(0); X4O32($40000000);
 For I:=1 To 6 Do X4O32(0);
 X4O32(NextId); X4BoxE(B);
 { ----- piste video ----- }
 Trak:=X4BoxB('trak');
 B:=X4BoxB('tkhd'); X4O32(3); X4O32(0); X4O32(0); X4O32(1); X4O32(0); X4O32(
  VidMs); X4O32(0); X4O32(0); X4O16(0); X4O16(0); X4O16(0); X4O16(0);
 X4O32($10000); X4O32(0); X4O32(0); X4O32(0); X4O32($10000); X4O32(0); X4O32(0);
  X4O32(0); X4O32($40000000);
 X4O32(Int64(X4EOutW) Shl 16); X4O32(Int64(X4EOutH) Shl 16); X4BoxE(B);
 Mdia:=X4BoxB('mdia');
 B:=X4BoxB('mdhd'); X4O32(0); X4O32(0); X4O32(0); X4O32(X4Fn);
  X4O32(Int64(X4EN)*X4Fd); X4O16($55C4); X4O16(0); X4BoxE(B);
 B:=X4BoxB('hdlr'); X4O32(0); X4O32(0); X4OTag('vide'); X4O32(0); X4O32(0);
  X4O32(0);
 For I:=1 To 12 Do X4OB(Ord(Hv[I])); X4OB(0); X4BoxE(B);
 Minf:=X4BoxB('minf');
 B:=X4BoxB('vmhd'); X4O32(1); X4O32(0); X4O32(0); X4BoxE(B);
 B:=X4BoxB('dinf'); I:=X4BoxB('dref'); X4O32(0); X4O32(1); Stbl:=X4BoxB('url ');
  X4O32(1); X4BoxE(Stbl); X4BoxE(I); X4BoxE(B);
 Stbl:=X4BoxB('stbl');
 Stsd:=X4BoxB('stsd'); X4O32(0); X4O32(1);
 Avc1:=X4BoxB('avc1'); X4O32(0); X4O16(0); X4O16(1); X4O32(0); X4O32(0); X4O32(
  0); X4O32(0);
 X4O16(X4EOutW); X4O16(X4EOutH); X4O32($480000); X4O32($480000); X4O32(0);
  X4O16(1);
 For I:=1 To 32 Do X4OB(0);
 X4O16($18); X4O16($FFFF);
 AvcC:=X4BoxB('avcC'); X4OB(1); X4OB(66); X4OB($C0); X4OB(X4ELvl); X4OB($FF);
  X4OB($E1);
 X4O16(X4SpsLen); For I:=0 To X4SpsLen-1 Do X4OB(X4SpsB[I]);
 X4OB(1); X4O16(X4PpsLen); For I:=0 To X4PpsLen-1 Do X4OB(X4PpsB[I]);
 X4BoxE(AvcC); X4BoxE(Avc1); X4BoxE(Stsd);
 B:=X4BoxB('stts'); X4O32(0); X4O32(1); X4O32(X4EN); X4O32(X4Fd); X4BoxE(B);
 KeyCount:=0; For I:=0 To X4EN-1 Do If X4EKey^[I]<>0 Then Inc(KeyCount);
 If KeyCount<X4EN Then Begin
  B:=X4BoxB('stss'); X4O32(0); X4O32(KeyCount);
  For I:=0 To X4EN-1 Do If X4EKey^[I]<>0 Then X4O32(I+1);
  X4BoxE(B);
 End;
 B:=X4BoxB('stsc'); X4O32(0); X4O32(1); X4O32(1); X4O32(1); X4O32(1); X4BoxE(B);
 B:=X4BoxB('stsz'); X4O32(0); X4O32(0); X4O32(X4EN);
 For I:=0 To X4EN-1 Do X4O32(X4ESz^[I]); X4BoxE(B);
 B:=X4BoxB('stco'); X4O32(0); X4O32(X4EN); Off:=VidOff;
 For I:=0 To X4EN-1 Do Begin X4O32(Off); Inc(Off,X4ESz^[I]); End;
 X4BoxE(B);
 X4BoxE(Stbl); X4BoxE(Minf); X4BoxE(Mdia); X4BoxE(Trak);
 { ----- piste audio PCM 'sowt' ----- }
 If AudFrames>0 Then Begin
  Trak:=X4BoxB('trak');
  B:=X4BoxB('tkhd'); X4O32(3); X4O32(0); X4O32(0); X4O32(2); X4O32(0);
   X4O32(AudMs); X4O32(0); X4O32(0); X4O16(0); X4O16(0); X4O16($100); X4O16(0);
  X4O32($10000); X4O32(0); X4O32(0); X4O32(0); X4O32($10000); X4O32(0);
   X4O32(0); X4O32(0); X4O32($40000000);
  X4O32(0); X4O32(0); X4BoxE(B);
  Mdia:=X4BoxB('mdia');
  B:=X4BoxB('mdhd'); X4O32(0); X4O32(0); X4O32(0); X4O32(X4EArate);
   X4O32(AudFrames); X4O16($55C4); X4O16(0); X4BoxE(B);
  B:=X4BoxB('hdlr'); X4O32(0); X4O32(0); X4OTag('soun'); X4O32(0); X4O32(0);
   X4O32(0);
  For I:=1 To 12 Do X4OB(Ord(Ha[I])); X4OB(0); X4BoxE(B);
  Minf:=X4BoxB('minf');
  B:=X4BoxB('smhd'); X4O32(0); X4O32(0); X4BoxE(B);
  B:=X4BoxB('dinf'); I:=X4BoxB('dref'); X4O32(0); X4O32(1);
   Stbl:=X4BoxB('url '); X4O32(1); X4BoxE(Stbl); X4BoxE(I); X4BoxE(B);
  Stbl:=X4BoxB('stbl');
  Stsd:=X4BoxB('stsd'); X4O32(0); X4O32(1);
  Avc1:=X4BoxB('sowt'); X4O32(0); X4O16(0); X4O16(1);
   X4O16(0); X4O16(0); X4O32(0); X4O16(2); X4O16(16); X4O16(0); X4O16(0);
   If X4EArate<65536 Then X4O32(Int64(X4EArate) Shl 16) Else X4O32(0);
  X4BoxE(Avc1); X4BoxE(Stsd);
  B:=X4BoxB('stts'); X4O32(0); X4O32(1); X4O32(AudFrames); X4O32(1); X4BoxE(B);
  Dc:=X4EArate; Chunks:=AudFrames Div Dc; Rem:=AudFrames-Chunks*Dc;
  Ent:=0; If Chunks>0 Then Inc(Ent); If Rem>0 Then Inc(Ent);
  B:=X4BoxB('stsc'); X4O32(0); X4O32(Ent);
  If Chunks>0 Then Begin X4O32(1); X4O32(Dc); X4O32(1); End;
  If Rem>0 Then Begin X4O32(Chunks+1); X4O32(Rem); X4O32(1); End;
  X4BoxE(B);
  B:=X4BoxB('stsz'); X4O32(0); X4O32(4); X4O32(AudFrames); X4BoxE(B);
  If Rem>0 Then Inc(Chunks);
  B:=X4BoxB('stco'); X4O32(0); X4O32(Chunks); Off:=AudOff;
  For I:=0 To Chunks-1 Do Begin X4O32(Off); Inc(Off,Int64(Dc)*4); End;
  X4BoxE(B);
  X4BoxE(Stbl); X4BoxE(Minf); X4BoxE(Mdia); X4BoxE(Trak);
 End;
 X4BoxE(Moov);
End;

Function X4EEnd(Const AudioPcmFile: String): Boolean;
Var Fa: File; Sz,Left: Int64; OldMode: LongInt; Got,Chunk: LongInt; Buf: PX4Buf; AudOff: Int64;
 AudFrames: LongInt; VidOff: Int64; Ok: Boolean; Hdr: Array[0..3] Of Byte;
 Ret: Boolean;
Begin
 X4EEnd:=False;
 If Not X4EOn Then Exit;
 If X4EFail Or (X4EN=0) Then Begin X4EAbort; Exit; End;
 Ok:=True; VidOff:=X4EMdatAt+8; AudOff:=0; AudFrames:=0;
 { audio PCM : copie dans le mdat apres la video }
 If (X4EArate>0) And (AudioPcmFile<>'') Then Begin
  Assign(Fa,AudioPcmFile);
  {$I-}
  OldMode:=FileMode; FileMode:=0; Reset(Fa,1);
  {$I+}
  FileMode:=OldMode;
  If IOResult<>0 Then Ok:=False
  Else Begin
   {$I-}
   Sz:=FileSize(Fa);
   {$I+}
   If IOResult<>0 Then Sz:=0;
   AudFrames:=LongInt(Sz Div 4);
   If X4EPos+Int64(AudFrames)*4>3900000000 Then Begin AudFrames:=0; Ok:=False; End;
   If AudFrames>0 Then Begin
    AudOff:=X4EPos; Left:=Int64(AudFrames)*4;
    GetMem(Buf,65536);
    While Left>0 Do Begin
     If Left>65536 Then Chunk:=65536 Else Chunk:=LongInt(Left);
     Got:=0;
     {$I-}
     BlockRead(Fa,Buf^,Chunk,Got);
     {$I+}
     If (IOResult<>0) Or (Got<>Chunk) Then Begin Ok:=False; Break; End;
     If Not X4EWr(Buf^,Chunk) Then Begin Ok:=False; X4EFail:=True; Break; End;
     Dec(Left,Chunk);
    End;
    FreeMem(Buf);
    If Left>0 Then Begin
     { audio tronque : la piste n'est pas declaree }
     AudFrames:=0; If X4EFail Then Begin
      {$I-} Close(Fa); {$I+} If IOResult<>0 Then ;
      X4EAbort; Exit; End;
    End;
   End;
   {$I-} Close(Fa); {$I+} If IOResult<>0 Then ;
  End;
 End;
 { taille du mdat }
 Hdr[0]:=Byte((X4EPos-X4EMdatAt) Shr 24); Hdr[1]:=Byte((X4EPos-X4EMdatAt) Shr 16);
 Hdr[2]:=Byte((X4EPos-X4EMdatAt) Shr 8); Hdr[3]:=Byte(X4EPos-X4EMdatAt);
 {$I-}
 Seek(X4EF,X4EMdatAt);
 BlockWrite(X4EF,Hdr[0],4);
 Seek(X4EF,X4EPos);
 {$I+}
 If IOResult<>0 Then Begin X4EAbort; Exit; End;
 X4EWriteMoov(VidOff,AudOff,AudFrames);
 Ret:=X4EWr(X4O^[0],X4OLen);
 X4OLen:=0;
 {$I-}
 Close(X4EF);
 {$I+}
 If IOResult<>0 Then Ret:=False;
 X4EOn:=False;
 X4ERelease;
 If Not Ret Then Begin
  {$I-} Erase(X4EF); If IOResult<>0 Then ; {$I+}
 End;
 X4EEnd:=Ret And Ok;
End;
{$POP}
{$ELSE}
Function X4EBegin(Const FN: String; W, H, Fps100, Qp, Gop: LongInt; AudioRate: LongInt): Boolean;
Begin X4EBegin:=False; End;
Function X4EFrame(Pix: Pointer): Boolean;
Begin X4EFrame:=False; End;
Function X4EEnd(Const AudioPcmFile: String): Boolean;
Begin X4EEnd:=False; End;
Procedure X4EAbort;
Begin End;
{$ENDIF}

{ ====================================================================== }
{  Mixeur audio (WAV, tonalites), lecture sonore et exportations         }
{  WAV mixe et AVI MJPEG. Code FPC seulement (Int64, grands tableaux).   }
{ ====================================================================== }

{$IFDEF FPC}
Const
 AuRate = 22050;

Type
 TAuWav = Record
  Key: String[80];
  Ok: Boolean;
  DOfs, DLen, Rate: LongInt;
  Ch, Bits, Fmt: Integer;
 End;
 TAuS16 = Array[0..200000000] Of SmallInt;
 PAuS16 = ^TAuS16;
 TAuRaw = Array[0..65535] Of Byte;
 PAuRaw = ^TAuRaw;

Var
 AuInf: Array[0..5] Of TAuWav;
 AuInfN: Integer;
 AuGain: Array[0..52] Of LongInt;
 AuRaw: PAuRaw;
 AuAccL, AuAccR: Array[0..511] Of LongInt;
 AuF: Array[0..2] Of File;
 AuFName: Array[0..2] Of String[80];
 AuFNext: Integer;
 AuWavBuf: PBigBytes;
 AuWavSize: LongInt;
 AuVirt: Boolean;
 AuVClip: TClip;

{ ---------- Effets audio par clip : egaliseur 3 bandes, compresseur, porte, reverberation ---------- }
Type
 TRevBuf = Array[0..4095] Of LongInt;
 PRevBuf = ^TRevBuf;

Var
 FxLP: Array[0..MAXCLIPS - 1, 0..3] Of LongInt;
 FxEnv: Array[0..MAXCLIPS - 1] Of LongInt;
 FxEnd: Array[0..MAXCLIPS - 1] Of Int64;
 FxRev: Array[0..MAXCLIPS - 1] Of PRevBuf;
 FxPos: Array[0..MAXCLIPS - 1] Of LongInt;

Procedure FxReset(Ci: Integer);
Begin
 FillChar(FxLP[Ci], SizeOf(FxLP[Ci]), 0);
 FxEnv[Ci] := 0;
 FxPos[Ci] := 0;
 If FxRev[Ci] <> Nil Then FillChar(FxRev[Ci]^, SizeOf(TRevBuf), 0);
End;

Procedure FxFree;
Var
 I: Integer;
Begin
 For I := 0 To MAXCLIPS - 1 Do
  If FxRev[I] <> Nil Then Begin
   Dispose(FxRev[I]);
   FxRev[I] := Nil;
  End;
End;

Function ClipHasAudioFx(Var C: TClip): Boolean;
Begin
 ClipHasAudioFx := (C.EqL <> 0) Or (C.EqM <> 0) Or (C.EqH <> 0) Or (C.Comp > 0) Or
                   (C.Rev > 0) Or (C.Gate > 0);
End;

{ Applique les effets a l'echantillon stereo (L,R) du clip Ci }
Procedure FxApply(Ci: Integer; Var C: TClip; Var L, R: LongInt);
Var
 Lo, Hi, Mi, X, Mono, Wet, Lvl, Thr, Gn, D1, D2, D3, Q: LongInt;
 Ch: Integer;
Begin
 If (C.EqL <> 0) Or (C.EqM <> 0) Or (C.EqH <> 0) Then
  For Ch := 0 To 1 Do Begin
   If Ch = 0 Then X := L Else X := R;
   FxLP[Ci, Ch * 2] := FxLP[Ci, Ch * 2] + ((X - FxLP[Ci, Ch * 2]) * 5603) Div 65536;
   FxLP[Ci, Ch * 2 + 1] := FxLP[Ci, Ch * 2 + 1] + ((X - FxLP[Ci, Ch * 2 + 1]) * 37700) Div 65536;
   Lo := FxLP[Ci, Ch * 2];
   Hi := X - FxLP[Ci, Ch * 2 + 1];
   Mi := X - Lo - Hi;
   X := (Lo * AuGain[Clamp(C.EqL, -12, 12) + 40] + Mi * AuGain[Clamp(C.EqM, -12, 12) + 40] +
         Hi * AuGain[Clamp(C.EqH, -12, 12) + 40]) Div 256;
   If Ch = 0 Then L := X Else R := X;
  End;
 If (C.Comp > 0) Or (C.Gate > 0) Then Begin
  Lvl := Max(Abs(L), Abs(R));
  If Lvl > FxEnv[Ci] Then FxEnv[Ci] := FxEnv[Ci] + (Lvl - FxEnv[Ci]) Div 4
  Else FxEnv[Ci] := FxEnv[Ci] - (FxEnv[Ci] - Lvl) Div 512;
  If C.Comp > 0 Then Begin
   Thr := 6000;
   If FxEnv[Ci] > Thr Then Begin
    Gn := 256 - ((256 - (Thr * 256) Div FxEnv[Ci]) * C.Comp) Div 100;
    L := (L * Gn) Div 256;
    R := (R * Gn) Div 256;
   End;
   L := (L * (100 + C.Comp Div 3)) Div 100;
   R := (R * (100 + C.Comp Div 3)) Div 100;
  End;
  If C.Gate > 0 Then Begin
   Thr := C.Gate * 30;
   If FxEnv[Ci] < Thr Then Begin
    L := L Div 8;
    R := R Div 8;
   End;
  End;
 End;
 If C.Rev > 0 Then Begin
  If FxRev[Ci] = Nil Then Begin
   New(FxRev[Ci]);
   FillChar(FxRev[Ci]^, SizeOf(TRevBuf), 0);
  End;
  Mono := (L + R) Div 2;
  D1 := 1151;
  D2 := 1823;
  D3 := 2539;
  Wet := (FxRev[Ci]^[(FxPos[Ci] - D1) And 4095] + FxRev[Ci]^[(FxPos[Ci] - D2) And 4095] +
          FxRev[Ci]^[(FxPos[Ci] - D3) And 4095]) Div 3;
  FxRev[Ci]^[FxPos[Ci] And 4095] := Mono + (Wet * 62) Div 100;
  Inc(FxPos[Ci]);
  Q := (Wet * C.Rev) Div 100;
  L := L + Q;
  R := R + Q;
 End;
 If L > 32767 Then L := 32767 Else If L < -32768 Then L := -32768;
 If R > 32767 Then R := 32767 Else If R < -32768 Then R := -32768;
End;

Procedure PutTag(Var A: Array Of Byte; O: Integer; Const S: String);
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do A[O + I - 1] := Ord(S[I]);
End;

Procedure AuInit;
Var
 I: Integer;
Begin
 For I := 0 To 52 Do AuGain[I] := Round(256 * Exp((I - 40) * Ln(10) / 20));
 For I := 0 To 5 Do AuInf[I].Key := '';
 For I := 0 To MAXCLIPS - 1 Do Begin
  FxRev[I] := Nil;
  FxEnd[I] := -1;
 End;
 For I := 0 To 2 Do AuFName[I] := '';
 AuInfN := 0;
 AuFNext := 0;
 AuRaw := Nil;
 AuWavBuf := Nil;
 AuVirt := False;
End;

{ Ouvre (ou retrouve) le fichier WAV et lit son en-tete }
Function AuGetWav(Const Path: String): Integer;
Var
 F: File;
 H: Array[0..39] Of Byte;
 C: Array[0..7] Of Byte;
 I, Slot: Integer;
 Pos, Size, Sz: LongInt;
 N: Word;
 Tag: String[4];
 Found: Boolean;
Begin
 AuGetWav := -1;
 For I := 0 To 5 Do
  If AuInf[I].Key = Path Then Begin
   If AuInf[I].Ok Then AuGetWav := I;
   Exit;
  End;
 Slot := AuInfN;
 AuInfN := (AuInfN + 1) Mod 6;
 AuInf[Slot].Key := Path;
 AuInf[Slot].Ok := False;
 {$I-}
 Assign(F, Path);
 FileMode := 0;
 Reset(F, 1);
 FileMode := 2;
 {$I+}
 If IOResult <> 0 Then Exit;
 Size := FileSize(F);
 BlockRead(F, H, 12, N);
 If (N < 12) Or (H[0] <> Ord('R')) Or (H[8] <> Ord('W')) Then Begin
  Close(F);
  Exit;
 End;
 Pos := 12;
 Found := False;
 AuInf[Slot].Fmt := 0;
 While (Pos + 8 <= Size) And Not Found Do Begin
  Seek(F, Pos);
  BlockRead(F, C, 8, N);
  If N < 8 Then Break;
  Tag := Chr(C[0]) + Chr(C[1]) + Chr(C[2]) + Chr(C[3]);
  Sz := LE32(C, 4);
  If Sz < 0 Then Break;
  If Tag = 'fmt ' Then Begin
   FillChar(H, SizeOf(H), 0);
   BlockRead(F, H, Min(Sz, 40), N);
   AuInf[Slot].Fmt := LE16(H, 0);
   AuInf[Slot].Ch := LE16(H, 2);
   AuInf[Slot].Rate := LE32(H, 4);
   AuInf[Slot].Bits := LE16(H, 14);
   If (AuInf[Slot].Fmt = $FFFE) And (Sz >= 26) Then AuInf[Slot].Fmt := LE16(H, 24);
  End Else If Tag = 'data' Then Begin
   AuInf[Slot].DOfs := Pos + 8;
   AuInf[Slot].DLen := Min(Sz, Size - Pos - 8);
   Found := True;
  End;
  Pos := Pos + 8 + Sz + (Sz And 1);
 End;
 Close(F);
 If Found And (AuInf[Slot].Rate >= 4000) And (AuInf[Slot].Ch >= 1) And
    ((AuInf[Slot].Fmt = 1) Or (AuInf[Slot].Fmt = 3)) And
    ((AuInf[Slot].Bits = 8) Or (AuInf[Slot].Bits = 16) Or (AuInf[Slot].Bits = 24) Or
     (AuInf[Slot].Bits = 32)) Then Begin
  AuInf[Slot].Ok := True;
  AuGetWav := Slot;
 End;
End;

Function AuFileSlot(Const Path: String): Integer;
Var
 I: Integer;
Begin
 For I := 0 To 2 Do
  If AuFName[I] = Path Then Begin
   AuFileSlot := I;
   Exit;
  End;
 I := AuFNext;
 AuFNext := (AuFNext + 1) Mod 3;
 If AuFName[I] <> '' Then Begin
  Close(AuF[I]);
  AuFName[I] := '';
 End;
 {$I-}
 Assign(AuF[I], Path);
 FileMode := 0;
 Reset(AuF[I], 1);
 FileMode := 2;
 {$I+}
 If IOResult <> 0 Then Begin
  AuFileSlot := -1;
  Exit;
 End;
 AuFName[I] := Path;
 AuFileSlot := I;
End;

Procedure AuCloseFiles;
Var
 I: Integer;
Begin
 For I := 0 To 2 Do
  If AuFName[I] <> '' Then Begin
   Close(AuF[I]);
   AuFName[I] := '';
  End;
End;

{ Echantillon stereo (-32768..32767) de l'image Off du tampon brut }
Procedure AuSample(Off: LongInt; Var W: TAuWav; Var L, R: LongInt);
Var
 Sg: Single;
 B, C, C2: LongInt;
 Fr: Array[0..1] Of LongInt;
Begin
 For C := 0 To 1 Do Begin
  If C < W.Ch Then C2 := C Else C2 := 0;
  B := Off + C2 * (W.Bits Div 8);
  Case W.Bits Of
   8: Fr[C] := (AuRaw^[B] - 128) * 256;
   16: Fr[C] := SmallInt(AuRaw^[B] Or (AuRaw^[B + 1] Shl 8));
   24: Fr[C] := SmallInt(AuRaw^[B + 1] Or (AuRaw^[B + 2] Shl 8));
  Else Begin
    If W.Fmt = 3 Then Begin
     Move(AuRaw^[B], Sg, 4);
     If Sg > 1 Then Sg := 1;
     If Sg < -1 Then Sg := -1;
     Fr[C] := Round(Sg * 32767);
    End Else Fr[C] := SmallInt(AuRaw^[B + 2] Or (AuRaw^[B + 3] Shl 8));
   End;
  End;
 End;
 L := Fr[0];
 R := Fr[1];
End;

{ Position source (en echantillons) apres Tl echantillons de sequence, avec rampe de vitesse }
Function AuSrc(Var C: TClip; Tl, DurS: Int64): Int64;
Var
 S1, S2: Int64;
Begin
 S1 := C.Speed;
 S2 := C.Speed2;
 If S2 <= 0 Then S2 := S1;
 If (S1 = S2) Or (DurS < 1) Then AuSrc := (Tl * S1) Div 100
 Else AuSrc := (S1 * Tl + ((S2 - S1) * Tl * Tl) Div (2 * DurS)) Div 100;
End;

Function AuSynth(Kind, Par: Integer; SP: Int64): LongInt;
Var
 Beat, Ph, Hz, Env: LongInt;
Begin
 AuSynth := 0;
 Beat := AuRate Div 3;
 Case Kind Of
  MK_TONE: Begin
   Ph := ((SP * Par) Mod AuRate) * 256 Div AuRate;
   AuSynth := Sn(Ph) * 7000 Div 127;
  End;
  MK_PULSE: Begin
   If ((SP Div Beat) And 1) = 0 Then Begin
    Ph := ((SP * Par) Mod AuRate) * 256 Div AuRate;
    AuSynth := Sn(Ph) * 7000 Div 127;
   End;
  End;
  MK_MELODY: Begin
   Hz := MelodyHz[MelodyIdx[(SP Div Beat) And 7]];
   Env := 100 - ((SP Mod Beat) * 60) Div Beat;
   Ph := ((SP * Hz) Mod AuRate) * 256 Div AuRate;
   AuSynth := (Sn(Ph) * 7000 Div 127) * Env Div 100;
  End;
 End;
End;

{ Ajoute au bloc d'accumulation le son du clip C pour les echantillons [S0, S0+N) }
Procedure AuClipBlock(Var C: TClip; Ci: Integer; S0: Int64; N: Integer);
Var
 CS, CE, Lo, Hi, S, TL, SP, InBase, K, K0, K1: Int64;
 W, I, Bf, Kd, Fi, Fo, Idx: LongInt;
 L, R, G, G1, Gv, T2, Pn0, Pn1, PnV, GL, GR: LongInt;
 Slot: Integer;
 Got: Word;
 Vol: Integer;
 HasFx: Boolean;
Begin
 CS := Int64(C.Start) * AuRate Div P.Fps;
 CE := Int64(C.Start + C.Dur) * AuRate Div P.Fps;
 Lo := S0;
 If CS > Lo Then Lo := CS;
 Hi := S0 + N;
 If CE < Hi Then Hi := CE;
 If Hi <= Lo Then Exit;
 HasFx := (Ci >= 0) And ClipHasAudioFx(C);
 If HasFx Then Begin
  If FxEnd[Ci] <> Lo Then FxReset(Ci);
  FxEnd[Ci] := Hi;
 End;
 Kd := P.Media[C.Med].Kind;
 Vol := Integer(Clamp(KfEval(C, 8, ((Lo - CS) * P.Fps) Div AuRate, C.Vol), -40, 12));
 G := AuGain[Vol + 40];
 G1 := AuGain[Integer(Clamp(KfEval(C, 8, ((Hi - CS) * P.Fps) Div AuRate, C.Vol), -40, 12)) + 40];
 Pn0 := Clamp(KfEval(C, 9, ((Lo - CS) * P.Fps) Div AuRate, C.Pan), -100, 100);
 Pn1 := Clamp(KfEval(C, 9, ((Hi - CS) * P.Fps) Div AuRate, C.Pan), -100, 100);
 InBase := Int64(C.InPt) * AuRate Div P.Fps;
 Fi := 0;
 Fo := 0;
 If (C.TIn > 0) And (C.TInL > 0) Then Fi := (Int64(C.TInL) * AuRate) Div P.Fps;
 If (C.TOut > 0) And (C.TOutL > 0) Then Fo := (Int64(C.TOutL) * AuRate) Div P.Fps;
 If Kd = MK_WAV Then Begin
  W := AuGetWav(P.Media[C.Med].Path);
  If W < 0 Then Exit;
  Slot := AuFileSlot(P.Media[C.Med].Path);
  If Slot < 0 Then Exit;
  Bf := AuInf[W].Ch * (AuInf[W].Bits Div 8);
  K0 := (InBase + AuSrc(C, Lo - CS, CE - CS)) * AuInf[W].Rate Div AuRate;
  K1 := (InBase + AuSrc(C, Hi - 1 - CS, CE - CS)) * AuInf[W].Rate Div AuRate;
  If (K1 - K0 + 1) * Bf > 65000 Then Exit;
  If AuRaw = Nil Then New(AuRaw);
  FillChar(AuRaw^, 65536, 0);
  If K0 * Bf >= AuInf[W].DLen Then Exit;
  {$I-}
  Seek(AuF[Slot], AuInf[W].DOfs + K0 * Bf);
  BlockRead(AuF[Slot], AuRaw^, (K1 - K0 + 1) * Bf, Got);
  {$I+}
  If IOResult <> 0 Then Exit;
 End;
 For S := Lo To Hi - 1 Do Begin
  TL := S - CS;
  SP := InBase + AuSrc(C, TL, CE - CS);
  If Kd = MK_WAV Then Begin
   K := SP * AuInf[W].Rate Div AuRate - K0;
   If (K < 0) Or ((K + 1) * Bf > 65536) Then Begin
    L := 0;
    R := 0;
   End Else AuSample(K * Bf, AuInf[W], L, R);
  End Else Begin
   L := AuSynth(Kd, P.Media[C.Med].Par, SP);
   R := L;
  End;
  If HasFx Then FxApply(Ci, C, L, R);
  Gv := G + ((G1 - G) * (S - Lo)) Div Max(1, Hi - Lo);
  PnV := Pn0 + ((Pn1 - Pn0) * (S - Lo)) Div Max(1, Hi - Lo);
  If (Fi > 0) And (TL < Fi) Then Gv := (Gv * TL) Div Fi;
  T2 := (CE - CS) - 1 - TL;
  If (Fo > 0) And (T2 < Fo) Then Gv := (Gv * T2) Div Fo;
  Idx := S - S0;
  GL := (Gv * (100 - Max(0, PnV))) Div 100;
  GR := (Gv * (100 + Min(0, PnV))) Div 100;
  AuAccL[Idx] := AuAccL[Idx] + (L * GL) Div 256;
  AuAccR[Idx] := AuAccR[Idx] + (R * GR) Div 256;
 End;
End;

{ Mixe N images stereo a partir de l'echantillon S0 dans Dest (entrelace) }
Procedure AuMix(S0: Int64; N: LongInt; Dest: PAuS16);
Var
 Done, Blk, I, J: LongInt;
 V: LongInt;
Begin
 Done := 0;
 While Done < N Do Begin
  Blk := N - Done;
  If Blk > 512 Then Blk := 512;
  FillChar(AuAccL, SizeOf(AuAccL), 0);
  FillChar(AuAccR, SizeOf(AuAccR), 0);
  If AuVirt Then AuClipBlock(AuVClip, -1, S0 + Done, Blk)
  Else
   For I := 0 To P.NC - 1 Do
    If (Not IsVideoTrack(P.Clips[I].Trk)) And ((P.TrkF[P.Clips[I].Trk] And TF_HIDE) = 0) And
       ((P.Clips[I].Fl And CF_OFF) = 0) And (Not P.Clips[I].Mute) And
       (P.Media[P.Clips[I].Med].Kind >= 20) Then
     AuClipBlock(P.Clips[I], I, S0 + Done, Blk);
  For J := 0 To Blk - 1 Do Begin
   V := AuAccL[J];
   If V > 32767 Then V := 32767 Else If V < -32768 Then V := -32768;
   Dest^[(Done + J) * 2] := V;
   V := AuAccR[J];
   If V > 32767 Then V := 32767 Else If V < -32768 Then V := -32768;
   Dest^[(Done + J) * 2 + 1] := V;
  End;
  Done := Done + Blk;
 End;
End;

Function AuAnyAudio(F0, F1: LongInt): Boolean;
Var
 I: Integer;
Begin
 AuAnyAudio := False;
 If AuVirt Then Begin
  AuAnyAudio := True;
  Exit;
 End;
 For I := 0 To P.NC - 1 Do
  If (Not IsVideoTrack(P.Clips[I].Trk)) And ((P.TrkF[P.Clips[I].Trk] And TF_HIDE) = 0) And
     ((P.Clips[I].Fl And CF_OFF) = 0) And (Not P.Clips[I].Mute) And
     (P.Clips[I].Start < F1) And (ClipEnd(I) > F0) Then AuAnyAudio := True;
End;

Procedure AuWavHeader(Var H: Array Of Byte; N: LongInt);
Begin
 FillChar(H, 44, 0);
 H[0] := Ord('R'); H[1] := Ord('I'); H[2] := Ord('F'); H[3] := Ord('F');
 PutLE32(H, 4, 36 + N * 4);
 H[8] := Ord('W'); H[9] := Ord('A'); H[10] := Ord('V'); H[11] := Ord('E');
 H[12] := Ord('f'); H[13] := Ord('m'); H[14] := Ord('t'); H[15] := Ord(' ');
 PutLE32(H, 16, 16);
 H[20] := 1;
 H[22] := 2;
 PutLE32(H, 24, AuRate);
 PutLE32(H, 28, AuRate * 4);
 H[32] := 4;
 H[34] := 16;
 H[36] := Ord('d'); H[37] := Ord('a'); H[38] := Ord('t'); H[39] := Ord('a');
 PutLE32(H, 40, N * 4);
End;

{ Construit en memoire l'image d'un fichier WAV stereo 16 bits des images F0..F1 }
Function AuBuildWav(F0, F1: LongInt): Boolean;
Var
 S0, N: Int64;
Begin
 AuBuildWav := False;
 If AuWavBuf <> Nil Then Begin
  FreeMem(AuWavBuf, AuWavSize);
  AuWavBuf := Nil;
 End;
 S0 := Int64(F0) * AuRate Div P.Fps;
 N := Int64(F1) * AuRate Div P.Fps - S0;
 If (N < AuRate Div 20) Or (N > Int64(AuRate) * 600) Then Exit;
 AuWavSize := 44 + N * 4;
 GetMem(AuWavBuf, AuWavSize);
 If AuWavBuf = Nil Then Exit;
 AuWavHeader(AuWavBuf^, N);
 AuMix(S0, LongInt(N), PAuS16(@AuWavBuf^[44]));
 AuCloseFiles;
 AuBuildWav := True;
End;

{$IFDEF WINDOWS}
Function AuPlaySound(Snd: Pointer; Hm: PtrUInt; Fl: LongWord): LongInt;
 stdcall; external 'winmm.dll' name 'PlaySoundA';
{$ENDIF}

Procedure AuStopPlay;
Begin
 {$IFDEF WINDOWS}
 If AuWavBuf <> Nil Then AuPlaySound(Nil, 0, 0);
 {$ENDIF}
 If AuWavBuf <> Nil Then Begin
  FreeMem(AuWavBuf, AuWavSize);
  AuWavBuf := Nil;
 End;
 AuVirt := False;
End;

{ Demarre la lecture sonore reelle (Windows). Retourne False si impossible. }
Function AuStartPlay(Target: Integer; FromFrame: LongInt): Boolean;
Var
 EndF: LongInt;
 Okp: Boolean;
Begin
 AuStartPlay := False;
 AuStopPlay;
 {$IFDEF WINDOWS}
 AuVirt := False;
 If Target = 1 Then Begin
  EndF := SeqEnd;
  If P.OutM >= 0 Then EndF := Min(EndF, P.OutM);
 End Else Begin
  If (SrcMed < 0) Or (SrcMed >= P.NM) Or (P.Media[SrcMed].Kind < 20) Then Exit;
  FillChar(AuVClip, SizeOf(AuVClip), 0);
  AuVClip.Trk := AUDBASE;
  AuVClip.Med := SrcMed;
  AuVClip.Start := 0;
  AuVClip.Dur := P.Media[SrcMed].Dur;
  AuVClip.InPt := 0;
  AuVClip.Speed := 100;
  AuVirt := True;
  EndF := P.Media[SrcMed].Dur;
 End;
 If Not AuAnyAudio(FromFrame, EndF) Then Begin
  AuVirt := False;
  Exit;
 End;
 If AuBuildWav(FromFrame, EndF) Then Begin
  Okp := AuPlaySound(AuWavBuf, 0, 1 Or 2 Or 4) <> 0;
  If Not Okp Then AuStopPlay;
  AuStartPlay := Okp;
 End;
 AuVirt := False;
 {$ENDIF}
End;

{ ---------- Exportation WAV ---------- }

Procedure DoExportWav;
Var
 FN: String;
 F0, F1: LongInt;
 F: File;
Begin
 If SeqEnd = 0 Then Begin
  MsgBox('Exporter l''audio', 'La séquence est vide.');
  Exit;
 End;
 FN := 'AUDIO001.WAV';
 If Not InputBox('Exporter l''audio', 'Nom du fichier WAV (stéréo 16 bits) :', FN, 40) Then Exit;
 If ExtOf(FN) = '' Then FN := FN + '.WAV';
 F0 := 0;
 F1 := SeqEnd;
 If P.InM >= 0 Then F0 := P.InM;
 If (P.OutM >= 0) And (P.OutM > F0) Then F1 := Min(F1, P.OutM);
 AuVirt := False;
 If Not AuAnyAudio(F0, F1) Then Begin
  MsgBox('Exporter l''audio', 'Aucun clip audio dans la zone exportée.');
  Exit;
 End;
 If Not AuBuildWav(F0, F1) Then Begin
  MsgBox('Exporter l''audio', 'Zone trop courte ou trop longue (10 minutes maximum).');
  Exit;
 End;
 {$I-}
 Assign(F, FN);
 Rewrite(F, 1);
 BlockWrite(F, AuWavBuf^, AuWavSize);
 Close(F);
 {$I+}
 If IOResult = 0 Then
  MsgBox('Exporter l''audio', 'Audio exporté : ' + FN + '|' + TC(F1 - F0) + ' - 22050 Hz stéréo 16 bits')
 Else MsgBox('Exporter l''audio', 'Impossible d''écrire le fichier.');
 FreeMem(AuWavBuf, AuWavSize);
 AuWavBuf := Nil;
End;

{ ====================================================================== }
{  Encodeur JPEG baseline (4:4:4) et ecriture AVI MJPEG + PCM            }
{ ====================================================================== }

Const
 ExQLum: Array[0..63] Of Byte =
  (16,11,10,16,24,40,51,61,12,12,14,19,26,58,60,55,14,13,16,24,40,57,69,56,14,17,22,29,51,87,80,62,
   18,22,37,56,68,109,103,77,24,35,55,64,81,104,113,92,49,64,78,87,103,121,120,101,72,92,95,98,112,100,103,99);
 ExQChr: Array[0..63] Of Byte =
  (17,18,24,47,99,99,99,99,18,21,26,66,99,99,99,99,24,26,56,99,99,99,99,99,47,66,99,99,99,99,99,99,
   99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99);

Type
 TExSingles = Array[0..200000000] Of Single;
 PExSingles = ^TExSingles;
 TExLongs = Array[0..2000000] Of LongInt;
 PExLongs = ^TExLongs;
 TExHuff = Record
  Code: Array[0..255] Of Word;
  Size: Array[0..255] Of Byte;
 End;

Var
 ExQ: Array[0..1, 0..63] Of Integer;
 ExHuf: Array[0..3] Of TExHuff;
 ExCos: Array[0..7, 0..7] Of Single;
 ExOut: PBigBytes;
 ExPos: LongInt;
 ExAcc: LongInt;
 ExNb: LongInt;
 ExPrev: Array[0..2] Of Integer;
 ExSz: LongInt;
 Yp, Cbp, Crp: PExSingles;

Procedure ExBuildHuff(Var H: TExHuff; Const Bits: Array Of Byte; Const Vals: Array Of Byte);
Var
 Code, K, Len, I: LongInt;
Begin
 FillChar(H, SizeOf(H), 0);
 Code := 0;
 K := 0;
 For Len := 1 To 16 Do Begin
  For I := 1 To Bits[Len - 1] Do Begin
   H.Code[Vals[K]] := Code;
   H.Size[Vals[K]] := Len;
   Inc(Code);
   Inc(K);
  End;
  Code := Code Shl 1;
 End;
End;

Procedure ExInit(Quality: Integer);
Var
 I, U, X, Sc, V: Integer;
Begin
 If Quality < 1 Then Quality := 1;
 If Quality > 100 Then Quality := 100;
 If Quality < 50 Then Sc := 5000 Div Quality Else Sc := 200 - Quality * 2;
 For I := 0 To 63 Do Begin
  V := (ExQLum[I] * Sc + 50) Div 100;
  If V < 1 Then V := 1;
  If V > 255 Then V := 255;
  ExQ[0, I] := V;
  V := (ExQChr[I] * Sc + 50) Div 100;
  If V < 1 Then V := 1;
  If V > 255 Then V := 255;
  ExQ[1, I] := V;
 End;
 For U := 0 To 7 Do
  For X := 0 To 7 Do Begin
   ExCos[U, X] := Cos((2 * X + 1) * U * Pi / 16) / 2;
   If U = 0 Then ExCos[U, X] := ExCos[U, X] / Sqrt(2);
  End;
 ExBuildHuff(ExHuf[0], V3JStdDCLN, V3JStdDCLV);
 ExBuildHuff(ExHuf[1], V3JStdACLN, V3JStdACLV);
 ExBuildHuff(ExHuf[2], V3JStdDCCN, V3JStdDCCV);
 ExBuildHuff(ExHuf[3], V3JStdACCN, V3JStdACCV);
End;

Procedure ExPutBits(Code, Len: LongInt);
Var
 B: LongInt;
Begin
 ExAcc := (ExAcc Shl Len) Or (Code And ((1 Shl Len) - 1));
 Inc(ExNb, Len);
 While ExNb >= 8 Do Begin
  B := (ExAcc Shr (ExNb - 8)) And 255;
  ExOut^[ExPos] := B;
  Inc(ExPos);
  If B = 255 Then Begin
   ExOut^[ExPos] := 0;
   Inc(ExPos);
  End;
  Dec(ExNb, 8);
 End;
 ExAcc := ExAcc And ((1 Shl ExNb) - 1);
End;

Procedure ExFlushBits;
Begin
 If ExNb > 0 Then ExPutBits((1 Shl (8 - ExNb)) - 1, 8 - ExNb);
End;

Function ExCat(V: LongInt): LongInt;
Var
 N: LongInt;
Begin
 V := Abs(V);
 N := 0;
 While V > 0 Do Begin
  Inc(N);
  V := V Shr 1;
 End;
 ExCat := N;
End;

Procedure ExEncodeBlock(Var Blk: Array Of Single; Comp: Integer);
Var
 Tmp: Array[0..63] Of Single;
 Co: Array[0..63] Of LongInt;
 U, V, X, Y, I, Tbl: Integer;
 Q, Run, Cat, D: LongInt;
 S: Single;
 DcH, AcH: Integer;
Begin
 For Y := 0 To 7 Do
  For U := 0 To 7 Do Begin
   S := 0;
   For X := 0 To 7 Do S := S + Blk[Y * 8 + X] * ExCos[U, X];
   Tmp[Y * 8 + U] := S;
  End;
 If Comp = 0 Then Tbl := 0 Else Tbl := 1;
 For V := 0 To 7 Do
  For U := 0 To 7 Do Begin
   S := 0;
   For Y := 0 To 7 Do S := S + Tmp[Y * 8 + U] * ExCos[V, Y];
   Q := ExQ[Tbl, V * 8 + U];
   Co[V * 8 + U] := Round(S / Q);
  End;
 If Comp = 0 Then Begin
  DcH := 0;
  AcH := 1;
 End Else Begin
  DcH := 2;
  AcH := 3;
 End;
 D := Co[0] - ExPrev[Comp];
 ExPrev[Comp] := Co[0];
 Cat := ExCat(D);
 ExPutBits(ExHuf[DcH].Code[Cat], ExHuf[DcH].Size[Cat]);
 If Cat > 0 Then Begin
  If D < 0 Then D := D - 1;
  ExPutBits(D, Cat);
 End;
 Run := 0;
 For I := 1 To 63 Do Begin
  Q := Co[V3JZig[I]];
  If Q = 0 Then Inc(Run)
  Else Begin
   While Run > 15 Do Begin
    ExPutBits(ExHuf[AcH].Code[$F0], ExHuf[AcH].Size[$F0]);
    Dec(Run, 16);
   End;
   Cat := ExCat(Q);
   ExPutBits(ExHuf[AcH].Code[Run * 16 + Cat], ExHuf[AcH].Size[Run * 16 + Cat]);
   If Q < 0 Then Q := Q - 1;
   ExPutBits(Q, Cat);
   Run := 0;
  End;
 End;
 If Run > 0 Then ExPutBits(ExHuf[AcH].Code[0], ExHuf[AcH].Size[0]);
End;

Procedure ExPut8(V: LongInt);
Begin
 ExOut^[ExPos] := V And 255;
 Inc(ExPos);
End;

Procedure ExPut16(V: LongInt);
Begin
 ExPut8(V Shr 8);
 ExPut8(V);
End;

Procedure ExPutDht(Cls, Id: Integer; Const Bits: Array Of Byte; Const Vals: Array Of Byte; NV: Integer);
Var
 I: Integer;
Begin
 ExPut16($FFC4);
 ExPut16(2 + 1 + 16 + NV);
 ExPut8(Cls * 16 + Id);
 For I := 0 To 15 Do ExPut8(Bits[I]);
 For I := 0 To NV - 1 Do ExPut8(Vals[I]);
End;

{ Encode l'image composee de la sequence a l'image Tm ; retourne la taille }
Function ExEncodeFrame(Tm: LongInt): LongInt;
Var
 Bx, By, X, Y, C, I, XX, YY: Integer;
 Blk: Array[0..63] Of Single;
 R, G, B: Single;
Begin
 ExPos := 0;
 ExAcc := 0;
 ExNb := 0;
 FillChar(ExPrev, SizeOf(ExPrev), 0);
 ExPut16($FFD8);
 ExPut16($FFE0);
 ExPut16(16);
 ExPut8(Ord('J')); ExPut8(Ord('F')); ExPut8(Ord('I')); ExPut8(Ord('F')); ExPut8(0);
 ExPut16($0101);
 ExPut8(0);
 ExPut16(1);
 ExPut16(1);
 ExPut8(0);
 ExPut8(0);
 For C := 0 To 1 Do Begin
  ExPut16($FFDB);
  ExPut16(67);
  ExPut8(C);
  For I := 0 To 63 Do ExPut8(ExQ[C, V3JZig[I]]);
 End;
 ExPut16($FFC0);
 ExPut16(17);
 ExPut8(8);
 ExPut16(VH);
 ExPut16(VW);
 ExPut8(3);
 ExPut8(1); ExPut8($11); ExPut8(0);
 ExPut8(2); ExPut8($11); ExPut8(1);
 ExPut8(3); ExPut8($11); ExPut8(1);
 ExPutDht(0, 0, V3JStdDCLN, V3JStdDCLV, 12);
 ExPutDht(1, 0, V3JStdACLN, V3JStdACLV, 162);
 ExPutDht(0, 1, V3JStdDCCN, V3JStdDCCV, 12);
 ExPutDht(1, 1, V3JStdACCN, V3JStdACCV, 162);
 ExPut16($FFDA);
 ExPut16(12);
 ExPut8(3);
 ExPut8(1); ExPut8($00);
 ExPut8(2); ExPut8($11);
 ExPut8(3); ExPut8($11);
 ExPut8(0); ExPut8(63); ExPut8(0);
 BuildLayers(Tm);
 For Y := 0 To VH - 1 Do
  For X := 0 To VW - 1 Do Begin
   If NLay = 0 Then Begin
    AR := 0; AG := 0; AB := 0;
   End Else Compose(X, Y);
   R := AR;
   G := AG;
   B := AB;
   Yp^[Y * VW + X] := 0.299 * R + 0.587 * G + 0.114 * B - 128;
   Cbp^[Y * VW + X] := -0.168736 * R - 0.331264 * G + 0.5 * B;
   Crp^[Y * VW + X] := 0.5 * R - 0.418688 * G - 0.081312 * B;
  End;
 For By := 0 To (VH + 7) Div 8 - 1 Do
  For Bx := 0 To (VW + 7) Div 8 - 1 Do
   For C := 0 To 2 Do Begin
    For YY := 0 To 7 Do
     For XX := 0 To 7 Do Begin
      Y := By * 8 + YY;
      X := Bx * 8 + XX;
      If Y >= VH Then Y := VH - 1;
      If X >= VW Then X := VW - 1;
      Case C Of
       0: Blk[YY * 8 + XX] := Yp^[Y * VW + X];
       1: Blk[YY * 8 + XX] := Cbp^[Y * VW + X];
      Else Blk[YY * 8 + XX] := Crp^[Y * VW + X];
      End;
     End;
    ExEncodeBlock(Blk, C);
   End;
 ExFlushBits;
 ExPut16($FFD9);
 ExEncodeFrame := ExPos;
End;

Procedure ExShow(Title: String; Done, Total: LongInt);
Var
 X, Y, W, Pc: Integer;
Begin
 W := 340;
 X := (SW - W) Div 2;
 Y := (SH - 80) Div 2;
 HideMouse;
 DlgBox(X, Y, W, 80, Title);
 Txt(X + 12, Y + 26, IStr(Done) + ' / ' + IStr(Total) + ' images', Black);
 FillR(X + 12, Y + 42, X + W - 12, Y + 52, White);
 Frame(X + 12, Y + 42, X + W - 12, Y + 52, DarkGray);
 Pc := Integer((Done * (W - 26)) Div Max(1, Total));
 If Pc > 0 Then FillR(X + 13, Y + 43, X + 12 + Pc, Y + 51, Blue);
 Txt(X + 12, Y + 60, 'Echap : annuler', DarkGray);
 ShowMouse;
End;

Procedure ExportAviMjpeg;
Var
 FN, S: String;
 F: File;
 H: Array[0..323] Of Byte;
 Q, F0, F1, NFr, I, J: LongInt;
 JSz, ASz, Pos0, MoviStart, IdxN, MaxJ: LongInt;
 Cancel: Boolean;
 Abuf: PAuS16;
 Ent: Array[0..3] Of LongInt;
 IdxId, IdxOfs, IdxSz: PExLongs;
 Sa, Sb, TotSamples: Int64;
 Pad: Byte;
 Z: Array[0..3] Of Byte;
 Chunk: Array[0..7] Of Byte;
 T0: LongInt;
 Code: Integer;
Begin
 If SeqEnd = 0 Then Begin
  MsgBox('Exporter la vidéo', 'La séquence est vide.');
  Exit;
 End;
 FN := 'FILM001.AVI';
 If Not InputBox('Exporter la vidéo (AVI MJPEG)', 'Nom du fichier AVI :', FN, 40) Then Exit;
 If ExtOf(FN) = '' Then FN := FN + '.AVI';
 S := '85';
 If Not InputBox('Exporter la vidéo (AVI MJPEG)', 'Qualité JPEG (1 à 100) :', S, 3) Then Exit;
 Q := Clamp(StrVal(S, 85), 1, 100);
 F0 := 0;
 F1 := SeqEnd;
 If P.InM >= 0 Then F0 := P.InM;
 If (P.OutM >= 0) And (P.OutM > F0) Then F1 := Min(F1, P.OutM);
 NFr := F1 - F0;
 If NFr < 1 Then Exit;
 If NFr > 6000 Then Begin
  MsgBox('Exporter la vidéo', 'Trop d''images (' + IStr(NFr) + ', maximum 6000).|' +
         'Utilisez les marques d''entrée et de sortie.');
  Exit;
 End;
 If FileExists(FN) Then
  If Not Confirm('Exporter la vidéo', FN + ' existe déjà.|Le remplacer ?') Then Exit;
 {$I-}
 Assign(F, FN);
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  MsgBox('Exporter la vidéo', 'Impossible d''écrire le fichier.');
  Exit;
 End;
 ExInit(Integer(Q));
 ExSz := LongInt(VW) * VH * 3 + 65536;
 GetMem(ExOut, ExSz);
 GetMem(Yp, LongInt(VW) * VH * 4);
 GetMem(Cbp, LongInt(VW) * VH * 4);
 GetMem(Crp, LongInt(VW) * VH * 4);
 GetMem(Abuf, (AuRate Div 5 + 16) * 4);
 GetMem(IdxId, NFr * 2 * 4 + 16);
 GetMem(IdxOfs, NFr * 2 * 4 + 16);
 GetMem(IdxSz, NFr * 2 * 4 + 16);
 { En-tete AVI (324 octets) }
 FillChar(H, SizeOf(H), 0);
 PutTag(H, 0, 'RIFF'); PutTag(H, 8, 'AVI ');
 PutTag(H, 12, 'LIST'); PutLE32(H, 16, 292); PutTag(H, 20, 'hdrl');
 PutTag(H, 24, 'avih'); PutLE32(H, 28, 56);
 PutLE32(H, 32, 1000000 Div P.Fps);
 PutLE32(H, 44, $10);
 PutLE32(H, 48, NFr);
 PutLE32(H, 56, 2);
 PutLE32(H, 60, ExSz);
 PutLE32(H, 64, VW);
 PutLE32(H, 68, VH);
 PutTag(H, 88, 'LIST'); PutLE32(H, 92, 116); PutTag(H, 96, 'strl');
 PutTag(H, 100, 'strh'); PutLE32(H, 104, 56);
 PutTag(H, 108, 'vids'); PutTag(H, 112, 'MJPG');
 PutLE32(H, 128, 1);
 PutLE32(H, 132, P.Fps);
 PutLE32(H, 140, NFr);
 PutLE32(H, 144, ExSz);
 PutLE32(H, 148, -1);
 H[160] := VW And 255; H[161] := VW Shr 8;
 H[162] := VH And 255; H[163] := VH Shr 8;
 PutTag(H, 164, 'strf'); PutLE32(H, 168, 40);
 PutLE32(H, 172, 40);
 PutLE32(H, 176, VW);
 PutLE32(H, 180, VH);
 H[184] := 1;
 H[186] := 24;
 PutTag(H, 188, 'MJPG');
 PutLE32(H, 192, VW * VH * 3);
 PutTag(H, 212, 'LIST'); PutLE32(H, 216, 92); PutTag(H, 220, 'strl');
 PutTag(H, 224, 'strh'); PutLE32(H, 228, 56);
 PutTag(H, 232, 'auds');
 PutLE32(H, 252, 1);
 PutLE32(H, 256, AuRate);
 PutLE32(H, 268, 65536);
 PutLE32(H, 272, -1);
 PutLE32(H, 276, 4);
 PutTag(H, 288, 'strf'); PutLE32(H, 292, 16);
 H[296] := 1;
 H[298] := 2;
 PutLE32(H, 300, AuRate);
 PutLE32(H, 304, AuRate * 4);
 H[308] := 4;
 H[310] := 16;
 PutTag(H, 312, 'LIST'); PutLE32(H, 316, 0); PutTag(H, 320, 'movi');
 BlockWrite(F, H, 324);
 Pos0 := 324;
 MoviStart := 320;
 IdxN := 0;
 Cancel := False;
 TotSamples := 0;
 FillChar(Z, 4, 0);
 T0 := 0;
 AuVirt := False;
 For I := 0 To NFr - 1 Do Begin
  If Cancel Then Break;
  If TickDiff(Ticks, T0) >= 15 Then Begin
   T0 := Ticks;
   ExShow('Exportation AVI', I, NFr);
   Code := ReadKeyCode;
   If Code = 27 Then Cancel := True;
  End;
  JSz := ExEncodeFrame(F0 + I);
  Chunk[0] := Ord('0'); Chunk[1] := Ord('0'); Chunk[2] := Ord('d'); Chunk[3] := Ord('c');
  PutLE32(Chunk, 4, JSz);
  BlockWrite(F, Chunk, 8);
  BlockWrite(F, ExOut^, JSz);
  If (JSz And 1) <> 0 Then BlockWrite(F, Z, 1);
  IdxId^[IdxN] := 0;
  IdxOfs^[IdxN] := Pos0 - MoviStart;
  IdxSz^[IdxN] := JSz;
  Inc(IdxN);
  Pos0 := Pos0 + 8 + JSz + (JSz And 1);
  Sa := Int64(F0 + I) * AuRate Div P.Fps;
  Sb := Int64(F0 + I + 1) * AuRate Div P.Fps;
  If Sb - Sa > AuRate Div 5 Then Sb := Sa + AuRate Div 5;
  AuMix(Sa, LongInt(Sb - Sa), Abuf);
  ASz := (Sb - Sa) * 4;
  Chunk[0] := Ord('0'); Chunk[1] := Ord('1'); Chunk[2] := Ord('w'); Chunk[3] := Ord('b');
  PutLE32(Chunk, 4, ASz);
  BlockWrite(F, Chunk, 8);
  BlockWrite(F, Abuf^, ASz);
  IdxId^[IdxN] := 1;
  IdxOfs^[IdxN] := Pos0 - MoviStart;
  IdxSz^[IdxN] := ASz;
  Inc(IdxN);
  Pos0 := Pos0 + 8 + ASz;
  TotSamples := TotSamples + (Sb - Sa);
 End;
 AuCloseFiles;
 { Index idx1 }
 Chunk[0] := Ord('i'); Chunk[1] := Ord('d'); Chunk[2] := Ord('x'); Chunk[3] := Ord('1');
 PutLE32(Chunk, 4, IdxN * 16);
 BlockWrite(F, Chunk, 8);
 For J := 0 To IdxN - 1 Do Begin
  FillChar(Ent, SizeOf(Ent), 0);
  If IdxId^[J] = 0 Then Ent[0] := $63643030 Else Ent[0] := $62773130;
  Ent[1] := $10;
  Ent[2] := IdxOfs^[J];
  Ent[3] := IdxSz^[J];
  BlockWrite(F, Ent, 16);
 End;
 { Mise a jour des tailles }
 If Cancel Then NFr := IdxN Div 2;
 PutLE32(H, 4, Pos0 + 8 + IdxN * 16 - 8);
 PutLE32(H, 316, Pos0 - 320);
 PutLE32(H, 48, NFr);
 PutLE32(H, 140, NFr);
 PutLE32(H, 264, TotSamples);
 Seek(F, 0);
 BlockWrite(F, H, 324);
 Close(F);
 FreeMem(ExOut, ExSz);
 FreeMem(Yp, LongInt(VW) * VH * 4);
 FreeMem(Cbp, LongInt(VW) * VH * 4);
 FreeMem(Crp, LongInt(VW) * VH * 4);
 FreeMem(Abuf, (AuRate Div 5 + 16) * 4);
 FreeMem(IdxId, NFr * 2 * 4 + 16);
 FreeMem(IdxOfs, NFr * 2 * 4 + 16);
 FreeMem(IdxSz, NFr * 2 * 4 + 16);
 DrawAll;
 If Cancel Then MsgBox('Exporter la vidéo', 'Exportation annulée : ' + IStr(NFr) + ' image(s) écrite(s).')
 Else MsgBox('Exporter la vidéo', 'Vidéo exportée : ' + FN + '|' + IStr(NFr) + ' images, ' +
             IStr(VW) + 'x' + IStr(VH) + ', MJPEG qualité ' + IStr(Q) + ' + PCM stéréo');
End;

{ ---------- Exportation MP4 H.264 + PCM ---------- }

Procedure ExportMp4H264;
Var
 FN, S, Tmp: String;
 F0, F1, NFr, I, Qp, Gop: LongInt;
 Pix: PBigBytes;
 Abuf: PAuS16;
 PF: File;
 Sa, Sb: Int64;
 X, Y: Integer;
 Cancel, Ok: Boolean;
 T0: LongInt;
 Code: Integer;
 Sz: LongInt;
Begin
 If SeqEnd = 0 Then Begin
  MsgBox('Exporter la vidéo', 'La séquence est vide.');
  Exit;
 End;
 FN := 'FILM001.MP4';
 If Not InputBox('Exporter la vidéo (MP4 H.264)', 'Nom du fichier MP4 :', FN, 40) Then Exit;
 If ExtOf(FN) = '' Then FN := FN + '.MP4';
 S := '24';
 If Not InputBox('Exporter la vidéo (MP4 H.264)', 'Quantificateur QP (10 = excellent, 40 = faible) :', S, 3) Then Exit;
 Qp := Clamp(StrVal(S, 24), 10, 45);
 Gop := P.Fps * 2;
 F0 := 0;
 F1 := SeqEnd;
 If P.InM >= 0 Then F0 := P.InM;
 If (P.OutM >= 0) And (P.OutM > F0) Then F1 := Min(F1, P.OutM);
 NFr := F1 - F0;
 If NFr < 1 Then Exit;
 If NFr > 20000 Then Begin
  MsgBox('Exporter la vidéo', 'Trop d''images (maximum 20000).|Utilisez les marques d''entrée et de sortie.');
  Exit;
 End;
 If FileExists(FN) Then
  If Not Confirm('Exporter la vidéo', FN + ' existe déjà.|Le remplacer ?') Then Exit;
 Tmp := FN + '.PCM';
 {$I-}
 Assign(PF, Tmp);
 Rewrite(PF, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  MsgBox('Exporter la vidéo', 'Impossible d''écrire le fichier temporaire.');
  Exit;
 End;
 If Not X4EBegin(FN, VW, VH, P.Fps * 100, Qp, Gop, AuRate) Then Begin
  Close(PF);
  Erase(PF);
  MsgBox('Exporter la vidéo', 'Impossible de créer le fichier MP4.|Dimensions ' + IStr(VW) + 'x' + IStr(VH) + '.');
  Exit;
 End;
 Sz := LongInt(VW) * VH * 3;
 GetMem(Pix, Sz);
 GetMem(Abuf, (AuRate Div 5 + 16) * 4);
 AuVirt := False;
 Cancel := False;
 Ok := True;
 T0 := 0;
 For I := 0 To NFr - 1 Do Begin
  If Cancel Or (Not Ok) Then Break;
  If TickDiff(Ticks, T0) >= 15 Then Begin
   T0 := Ticks;
   ExShow('Exportation MP4 H.264', I, NFr);
   Code := ReadKeyCode;
   If Code = 27 Then Cancel := True;
  End;
  BuildLayers(F0 + I);
  For Y := 0 To VH - 1 Do
   For X := 0 To VW - 1 Do Begin
    If NLay = 0 Then Begin
     AR := 0; AG := 0; AB := 0;
    End Else Compose(X, Y);
    Pix^[(Y * VW + X) * 3] := AR;
    Pix^[(Y * VW + X) * 3 + 1] := AG;
    Pix^[(Y * VW + X) * 3 + 2] := AB;
   End;
  Ok := X4EFrame(Pix);
  Sa := Int64(F0 + I) * AuRate Div P.Fps;
  Sb := Int64(F0 + I + 1) * AuRate Div P.Fps;
  If Sb - Sa > AuRate Div 5 Then Sb := Sa + AuRate Div 5;
  AuMix(Sa, LongInt(Sb - Sa), Abuf);
  BlockWrite(PF, Abuf^, (Sb - Sa) * 4);
 End;
 AuCloseFiles;
 Close(PF);
 FreeMem(Pix, Sz);
 FreeMem(Abuf, (AuRate Div 5 + 16) * 4);
 If Ok Then Ok := X4EEnd(Tmp) Else X4EAbort;
 Erase(PF);
 If IOResult <> 0 Then ;
 DrawAll;
 If Not Ok Then MsgBox('Exporter la vidéo', 'Erreur pendant l''encodage H.264.')
 Else If Cancel Then MsgBox('Exporter la vidéo', 'Exportation arrêtée : le fichier contient les ' + IStr(I) + ' premières images.')
 Else MsgBox('Exporter la vidéo', 'Vidéo exportée : ' + FN + '|' + IStr(NFr) + ' images, ' + IStr(VW) + 'x' +
             IStr(VH) + ', H.264 QP ' + IStr(Qp) + ' + PCM stéréo');
End;

Procedure DoExportAvi;
Begin
 DlgCount := 2;
 DlgItems[0] := 'AVI - MJPEG + PCM (qualité JPEG)';
 DlgItems[1] := 'MP4 - H.264 + PCM (quantificateur QP)';
 Case ListDlg('Exporter la vidéo - format', 0) Of
  0: ExportAviMjpeg;
  1: ExportMp4H264;
 End;
End;

{$ELSE}
Var
 AuVirt: Boolean;

Procedure AuInit;
Begin
End;

Procedure AuStopPlay;
Begin
End;

Function AuStartPlay(Target: Integer; FromFrame: LongInt): Boolean;
Begin
 AuStartPlay := False;
End;

Procedure DoExportWav;
Begin
 MsgBox('Exporter l''audio', 'Disponible seulement avec Free Pascal.');
End;

Procedure DoExportAvi;
Begin
 MsgBox('Exporter la vidéo', 'Disponible seulement avec Free Pascal.');
End;
{$ENDIF}

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
 AuStopPlay;
 AuActive := False;
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
 AuActive := False;
 If AudioOn And (Speed = 1) Then AuActive := AuStartPlay(Target, PlayF0);
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
    AuActive := False;
    If AudioOn Then AuActive := AuStartPlay(1, PlayF0);
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
 If MediaAudio(M) Then DefaultTrackFor := AUDBASE Else DefaultTrackFor := 0;
End;

{ Un clip precedent touche-t-il le debut de I sur la meme piste ? }
Function HasPrevAdjacent(I: Integer): Boolean;
Var
 J: Integer;
Begin
 HasPrevAdjacent := False;
 For J := 0 To P.NC - 1 Do
  If (J <> I) And (P.Clips[J].Trk = P.Clips[I].Trk) And (ClipEnd(J) = P.Clips[I].Start) Then
   HasPrevAdjacent := True;
End;

Procedure MarkCut(I: Integer);
Begin
 If HasPrevAdjacent(I) Then P.Clips[I].Fl := P.Clips[I].Fl Or CF_TCUT
 Else P.Clips[I].Fl := P.Clips[I].Fl And (Not CF_TCUT);
End;

{ Selectionne aussi les clips lies a la selection }
Procedure SelectLinked;
Var
 I, J: Integer;
Begin
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel And (P.Clips[I].Link <> 0) Then
   For J := 0 To P.NC - 1 Do
    If (P.Clips[J].Link = P.Clips[I].Link) And (Not TrackLocked(P.Clips[J].Trk)) Then
     P.Clips[J].Sel := True;
End;

Function NewLinkId: Integer;
Var
 I, M: Integer;
Begin
 M := 0;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Link > M Then M := P.Clips[I].Link;
 NewLinkId := M + 1;
End;

Procedure LinkSel(Link: Boolean);
Var
 I, L: Integer;
Begin
 If SelCount = 0 Then Exit;
 PushUndo;
 If Link Then L := NewLinkId Else L := 0;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then P.Clips[I].Link := L;
 If Link Then Msg('Clips liés') Else Msg('Clips dissociés');
 NeedTL := True;
End;

Procedure AddTrack(Video: Boolean);
Var
 Avail: Integer;
Begin
 Avail := CY2 - 3 - 12 - 2 - TRY0;
 If Avail Div (P.NV + P.NA + 1) < 16 Then Begin
  Msg('Pas assez de place : agrandissez l''écran (-maxscreen)');
  Exit;
 End;
 If (Video And (P.NV >= 8)) Or ((Not Video) And (P.NA >= 8)) Then Begin
  Msg('Nombre maximal de pistes atteint (8)');
  Exit;
 End;
 PushUndo;
 If Video Then Inc(P.NV) Else Inc(P.NA);
 InitLayout;
 NeedAll := True;
 Msg('Piste ajoutée');
End;

Procedure DelTrack(Video: Boolean);
Var
 T, I: Integer;
Begin
 If Video Then Begin
  If P.NV <= 1 Then Exit;
  T := P.NV - 1;
 End Else Begin
  If P.NA <= 1 Then Exit;
  T := AUDBASE + P.NA - 1;
 End;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Trk = T Then Begin
   Msg('La piste ' + TrackName(T) + ' contient des clips : videz-la d''abord');
   Exit;
  End;
 PushUndo;
 If Video Then Dec(P.NV) Else Dec(P.NA);
 InitLayout;
 NeedAll := True;
 Msg('Piste supprimée');
End;

Procedure DropMedia(M, Track: Integer; F: LongInt);
Var
 T, I, K, LnkId: Integer;
 D: LongInt;
Begin
 If (M < 0) Or (M >= P.NM) Then Exit;
 T := Track;
 If MediaAudio(M) Then Begin
  If T < AUDBASE Then T := AUDBASE;
  If T > AUDBASE + P.NA - 1 Then T := AUDBASE + P.NA - 1;
 End Else If T >= AUDBASE Then T := 0;
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
  If (P.Media[M].Pair >= 0) And (P.Media[M].Pair < P.NM) And (Not MediaAudio(M)) Then Begin
   K := PlaceClip(AUDBASE, P.Media[M].Pair, Max(0, F), 0, Min(D, P.Media[P.Media[M].Pair].Dur));
   If K >= 0 Then Begin
    LnkId := NewLinkId;
    P.Clips[K].Link := LnkId;
    P.Clips[K].Sel := True;
    I := FindClip(T, Max(0, F));
    If I >= 0 Then P.Clips[I].Link := LnkId;
   End;
  End;
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
   If Video Then MarkCut(I);
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
    If Both Or Not AtEnd Then Begin TIn := E - 7; TInL := L; MarkCut(I); End;
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
 I, J: Integer;
 S, S2s: String;
 NS, NS2, ND, Gap, Lim, Span, Avg: LongInt;
Begin
 I := FirstSel;
 If I < 0 Then Exit;
 S := IStr(P.Clips[I].Speed);
 If Not InputBox('Vitesse/Durée du clip', 'Vitesse de début en % (25 à 400) :', S, 4) Then Exit;
 NS := Clamp(StrVal(S, 100), 25, 400);
 S2s := IStr(Max(0, P.Clips[I].Speed2));
 If Not InputBox('Rampe de vitesse', 'Vitesse de fin en % (0 = constante) :', S2s, 4) Then Exit;
 NS2 := StrVal(S2s, 0);
 If NS2 <> 0 Then NS2 := Clamp(NS2, 25, 400);
 If NS2 = NS Then NS2 := 0;
 PushUndo;
 For I := 0 To P.NC - 1 Do
  If P.Clips[I].Sel Then Begin
   Span := SrcOfs(P.Clips[I], P.Clips[I].Dur);
   If NS2 > 0 Then Avg := (NS + NS2) Div 2 Else Avg := NS;
   ND := Max(1, (Span * 100) Div Avg);
   Gap := 1000000;
   For J := 0 To P.NC - 1 Do
    If (J <> I) And (P.Clips[J].Trk = P.Clips[I].Trk) And (P.Clips[J].Start >= ClipEnd(I)) Then
     Gap := Min(Gap, P.Clips[J].Start - P.Clips[I].Start);
   If ND > Gap Then ND := Gap;
   If Not MediaUnlimited(P.Clips[I].Med) Then Begin
    Lim := ((MediaMax(P.Clips[I].Med) - P.Clips[I].InPt) * 100) Div Avg;
    If ND > Lim Then ND := Max(1, Lim);
   End;
   P.Clips[I].Speed := Integer(NS);
   P.Clips[I].Speed2 := Integer(NS2);
   P.Clips[I].Dur := ND;
  End;
 NeedTL := True;
 NeedProg := True;
 If NS2 > 0 Then Msg('Vitesse : ' + IStr(NS) + ' % vers ' + IStr(NS2) + ' %')
 Else Msg('Vitesse : ' + IStr(NS) + ' %');
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
  EnsureCaches(False);
  ZoomFit;
 End;
 InvAll;
End;

Procedure SeqSettings;
Const
 ResW: Array[0..4] Of Integer = (284, 640, 854, 1280, 1920);
 ResH: Array[0..4] Of Integer = (160, 360, 480, 720, 1080);
Var
 S: String;
 Sel, R, NR, OldW, OldH: Integer;
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
  RecalcMediaDurs;
 End;
 If TrueMode Then Begin
  DlgCount := 5;
  DlgItems[0] := '284 x 160 (aperçu)';
  DlgItems[1] := '640 x 360 (360p)';
  DlgItems[2] := '854 x 480 (480p)';
  DlgItems[3] := '1280 x 720 (HD)';
  DlgItems[4] := '1920 x 1080 (Full HD)';
  Sel := 1;
  For R := 0 To 4 Do
   If ResW[R] = VW Then Sel := R;
  NR := ListDlg('Résolution de la séquence', Sel);
  If (NR >= 0) And ((ResW[NR] <> VW) Or (ResH[NR] <> VH)) Then Begin
   VW := ResW[NR];
   VH := ResH[NR];
   InitLayout;
   CacheCloseAll;
   For R := 0 To MAXLAY - 1 Do LayOK[R] := False;
   If Confirm('Résolution', 'Réimporter les médias à la nouvelle résolution ?|' +
              '(sinon leur qualité reste celle de l''importation)') Then Begin
    EnsureCaches(True);
   End;
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
 I, J, K: Integer;
 S: String;
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
  CM_EXPAVI: DoExportAvi;
  CM_EXPWAV: DoExportWav;
  CM_QUIT: Begin
   If Modified Then Begin
    If Confirm('Quitter', 'Les modifications seront perdues.|Quitter quand même ?') Then Running := False;
   End Else Running := False;
  End;
  CM_UNDO: Begin DoUndo; InitLayout; NeedAll := True; Msg('Annulé'); End;
  CM_REDO: Begin DoRedo; InitLayout; NeedAll := True; Msg('Rétabli'); End;
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
  CM_ADDV: AddTrack(True);
  CM_ADDA: AddTrack(False);
  CM_DELV: DelTrack(True);
  CM_DELA: DelTrack(False);
  CM_LINK: LinkSel(True);
  CM_UNLINK: LinkSel(False);
  CM_INTERP0..CM_INTERP0 + 2: Begin
   DefInterp := Id - CM_INTERP0;
   If SelCount > 0 Then Begin
    PushUndo;
    For I := 0 To P.NC - 1 Do
     If P.Clips[I].Sel Then
      For K := 0 To NKP - 1 Do
       For J := 0 To P.Clips[I].Kn[K] - 1 Do P.Clips[I].Ki[K, J] := DefInterp;
    NeedAll := True;
   End;
  End;
  CM_LUT: Begin
   S := '';
   If FileDlg('Importer une LUT', '.CUBE', S) Then Begin
    I := LutLoad(S);
    If I > 0 Then Begin
     Msg('LUT chargée : ' + LutNames[I] + ' (choisissez-la dans Effets)');
     SetModified;
    End Else MsgBox('Importer une LUT', 'Fichier .CUBE invalide ou 4 LUT déjà chargées.');
   End;
  End;
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
  CM_AUDIO: Begin AudioOn := Not AudioOn; StopSound; If Not AudioOn Then Begin AuStopPlay; AuActive := False; End; End;
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
 DragKP: Integer;
 DragKT: LongInt;
 MoveA, MoveB: Array[0..MAXCLIPS-1] Of LongInt;
 MoveT: Array[0..MAXCLIPS-1] Of Integer;

Function CtlVideoOnly(Id: Integer): Boolean;
Begin
 CtlVideoOnly := ((Id >= 1) And (Id <= 8)) Or (Id = 12) Or ((Id >= 14) And (Id <= 22)) Or
                 ((Id >= 25) And (Id <= 28)) Or ((Id >= 32) And (Id <= 39));
End;

Function CtlAudioOnly(Id: Integer): Boolean;
Begin
 CtlAudioOnly := (Id = 9) Or (Id = 13) Or (Id = 23) Or ((Id >= 45) And (Id <= 50));
End;

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
   If CtlAudioOnly(Id) Then Ok := Not Vid
   Else If CtlVideoOnly(Id) Then Ok := Vid;
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
   If (CtlKP(Id) >= 0) And (MX >= AX1 + 3) And (MX <= AX1 + 16) Then Begin
    PushUndo;
    KfToggleKey(C, Id, False);
    NeedA := True;
    NeedProg := True;
    NeedTL := True;
   End Else If MX >= CtlSliderX1 - 4 Then Begin
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
   If V > CtlKindMax(Id, IsVideoTrack(P.Clips[C].Trk)) Then V := 0;
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
 If T >= AUDBASE Then T := Min(1, P.NV - 1);
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

Procedure SelectBack(I: Integer);
Var
 J: Integer;
 S: LongInt;
 T: Integer;
Begin
 T := P.Clips[I].Trk;
 S := P.Clips[I].Start;
 ClearSel;
 For J := 0 To P.NC - 1 Do
  If (P.Clips[J].Trk = T) And (P.Clips[J].Start <= S) Then P.Clips[J].Sel := True;
 SelectLinked;
 NeedTL := True;
 NeedA := True;
End;

{ Plume : valeur (opacite 0..100 ou volume -40..+12 dB) selon la hauteur dans le clip }
Procedure PenSet(I, KP: Integer; T: LongInt; Y: LongInt);
Var
 Y1, Y2, V: LongInt;
Begin
 Y1 := RowY(TrackRow(P.Clips[I].Trk)) + 10;
 Y2 := RowY(TrackRow(P.Clips[I].Trk)) + TRH - 3;
 If Y2 <= Y1 Then Exit;
 Y := Clamp(Y, Y1, Y2);
 If KP = 4 Then V := 100 - ((Y - Y1) * 100) Div (Y2 - Y1)
 Else V := 12 - ((Y - Y1) * 52) Div (Y2 - Y1);
 KfSet(P.Clips[I], KP, T, V, DefInterp);
End;

Procedure PressTrackArea;
Var
 Row, T, I, K2: Integer;
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
                  P.Clips[I].InPt + SrcOfs(P.Clips[I], P.Clips[I].Dur));
     Exit;
    End;
    X1 := FrameToX(P.Clips[I].Start);
    X2 := FrameToX(ClipEnd(I)) - 1;
    If Not P.Clips[I].Sel Then Begin
     ClearSel;
     P.Clips[I].Sel := True;
     SelectLinked;
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
  TL_TRACKBACK: If I >= 0 Then SelectBack(I);
  TL_SLIP, TL_SLIDE: Begin
   If (I >= 0) And (Not TrackLocked(T)) Then Begin
    ClearSel;
    P.Clips[I].Sel := True;
    DragClip := I;
    PushUndo;
    DragMoved := False;
    DragF0 := F;
    If CurTool = TL_SLIP Then DragMode := DM_SLIP Else DragMode := DM_SLIDE;
    NeedTL := True;
    NeedA := True;
   End;
  End;
  TL_PEN: Begin
   If (I >= 0) And (Not TrackLocked(T)) Then Begin
    ClearSel;
    P.Clips[I].Sel := True;
    DragClip := I;
    PushUndo;
    DragMoved := True;
    If IsVideoTrack(T) Then DragKP := 4 Else DragKP := 8;
    DragKT := F - P.Clips[I].Start;
    For K2 := 0 To P.Clips[I].Kn[DragKP] - 1 Do
     If Abs(FrameToX(P.Clips[I].Start + P.Clips[I].Kt[DragKP, K2]) - MX) <= 5 Then
      DragKT := P.Clips[I].Kt[DragKP, K2];
    If P.Clips[I].Kn[DragKP] = 0 Then Begin
     If DragKP = 4 Then KfSet(P.Clips[I], 4, 0, P.Clips[I].Opac, DefInterp)
     Else KfSet(P.Clips[I], 8, 0, P.Clips[I].Vol, DefInterp);
    End;
    PenSet(I, DragKP, DragKT, MY);
    DragMode := DM_PEN;
    NeedTL := True;
    NeedA := True;
    NeedProg := True;
   End;
  End;
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
 If (MX < TLX0) And (MY >= TRY0) And (MY < TRY0 + NRows * TRH) Then Begin
  Row := (MY - TRY0) Div TRH;
  T := RowTrack(Row);
  If InRect(MX, MY, LX1 + 26, TrkBtnTop(Row), LX1 + 38, TrkBtnTop(Row) + 12) Then Begin
   P.TrkF[T] := P.TrkF[T] Xor TF_HIDE;
   SetModified;
   NeedAll := True;
  End Else If InRect(MX, MY, LX1 + 42, TrkBtnTop(Row), LX1 + 54, TrkBtnTop(Row) + 12) Then Begin
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
 If (MX >= TLX0) And (MX <= TLX1) And (MY >= TRY0) And (MY < TRY0 + NRows * TRH) Then
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
   If R < P.NV Then Begin
    DMin := Integer(Max(DMin, -R));
    DMax := Integer(Min(DMax, P.NV - 1 - R));
   End Else Begin
    DMin := Integer(Max(DMin, P.NV - R));
    DMax := Integer(Min(DMax, P.NV + P.NA - 1 - R));
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
 If P.Clips[C].Speed2 > 0 Then Spd := (Spd + P.Clips[C].Speed2) Div 2;
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
 If (Not Ripple) And (P.Clips[C].Link <> 0) Then
  For J := 0 To P.NC - 1 Do
   If (J <> C) And (P.Clips[J].Link = P.Clips[C].Link) And (Not TrackLocked(P.Clips[J].Trk)) Then Begin
    If IsLeft Then Begin
     P.Clips[J].InPt := Max(0, P.Clips[J].InPt + SrcOfs(P.Clips[J], P.Clips[C].Start - OS));
     P.Clips[J].Dur := Max(1, P.Clips[J].Dur - (P.Clips[C].Start - OS));
     P.Clips[J].Start := P.Clips[J].Start + (P.Clips[C].Start - OS);
    End Else P.Clips[J].Dur := Max(1, P.Clips[J].Dur + (P.Clips[C].Dur - OD));
   End;
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
 If (MY < TRY0) Or (Row < 0) Or (Row >= NRows) Then Exit;
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

Procedure ApplySlip;
Var
 C: Integer;
 Base: PProject;
 DF, NewIn, Span, MaxIn: LongInt;
Begin
 If UndoCnt = 0 Then Exit;
 Base := UndoStk[UndoCnt - 1];
 P := Base^;
 C := DragClip;
 DF := XToFrame(MX) - DragF0;
 Span := SrcOfs(P.Clips[C], P.Clips[C].Dur);
 NewIn := P.Clips[C].InPt - (DF * P.Clips[C].Speed) Div 100;
 If NewIn < 0 Then NewIn := 0;
 If Not MediaUnlimited(P.Clips[C].Med) Then Begin
  MaxIn := MediaMax(P.Clips[C].Med) - Span;
  If MaxIn < 0 Then MaxIn := 0;
  If NewIn > MaxIn Then NewIn := MaxIn;
 End;
 DragMoved := NewIn <> P.Clips[C].InPt;
 P.Clips[C].InPt := NewIn;
 Msg('Glissement interne : entrée ' + TC(NewIn));
 NeedProg := True;
 NeedTL := True;
End;

Procedure ApplySlide;
Var
 C, J, J1, J2: Integer;
 Base: PProject;
 DF, Lo, Hi: LongInt;
Begin
 If UndoCnt = 0 Then Exit;
 Base := UndoStk[UndoCnt - 1];
 P := Base^;
 C := DragClip;
 J1 := -1;
 J2 := -1;
 For J := 0 To P.NC - 1 Do
  If (J <> C) And (P.Clips[J].Trk = P.Clips[C].Trk) Then Begin
   If ClipEnd(J) = P.Clips[C].Start Then J1 := J;
   If P.Clips[J].Start = ClipEnd(C) Then J2 := J;
  End;
 DF := XToFrame(MX) - DragF0;
 If J1 >= 0 Then Lo := -(P.Clips[J1].Dur - 1) Else Lo := -P.Clips[C].Start;
 If J2 >= 0 Then Hi := P.Clips[J2].Dur - 1 Else Hi := 100000;
 DF := Clamp(DF, Lo, Hi);
 DragMoved := DF <> 0;
 P.Clips[C].Start := P.Clips[C].Start + DF;
 If J1 >= 0 Then P.Clips[J1].Dur := P.Clips[J1].Dur + DF;
 If J2 >= 0 Then Begin
  P.Clips[J2].InPt := P.Clips[J2].InPt + SrcOfs(P.Clips[J2], DF);
  P.Clips[J2].Start := P.Clips[J2].Start + DF;
  P.Clips[J2].Dur := P.Clips[J2].Dur - DF;
 End;
 Msg('Glissement externe : ' + IStr(DF) + ' image(s)');
 NeedProg := True;
 NeedTL := True;
End;

Procedure OnRelease;
Begin
 Case DragMode Of
  DM_MOVE: FinishMove;
  DM_TRIML, DM_TRIMR, DM_RIPL, DM_RIPR, DM_SLIDER, DM_SLIP, DM_SLIDE:
   If Not DragMoved Then DropLastUndo;
  DM_MEDIA: Begin
   If (Abs(MX - DragX0) > 4) Or (Abs(MY - DragY0) > 4) Then Begin
    If InRect(MX, MY, TLX0, TRY0, TLX1, TRY0 + NRows * TRH - 1) Then DropOnTimeline(0)
    Else If InRect(MX, MY, BX1, BY1, BX2, BY2) Then
     DropMedia(DragItem, DefaultTrackFor(DragItem), Playhead)
    Else If InRect(MX, MY, AX1, AY1, AX2, AY2) Then OpenInSource(DragItem, 0, -1);
   End;
  End;
  DM_EFFECT: Begin
   If (Abs(MX - DragX0) > 4) Or (Abs(MY - DragY0) > 4) Then
    If InRect(MX, MY, TLX0, TRY0, TLX1, TRY0 + NRows * TRH - 1) Then DropOnTimeline(1);
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
   MqY1 := Clamp(MY, TRY0, TRY0 + NRows * TRH - 1);
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
  DM_SLIP: ApplySlip;
  DM_SLIDE: ApplySlide;
  DM_PEN: Begin
   PenSet(DragClip, DragKP, DragKT, MY);
   NeedTL := True;
   NeedProg := True;
   NeedA := True;
  End;
  DM_MEDIA: Msg('Glissez le média sur une piste de la séquence...');
  DM_EFFECT: Msg('Glissez l''effet sur un clip de la séquence...');
 End;
End;

Function ToolHint(B: Integer): String;
Begin
 If B <= 6 Then ToolHint := ToolNames[ToolSlot[B]] Else ToolHint := 'Magnétisme (S)';
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
 Else If InRect(MX, MY, TLX0, TRY0, TLX1, TRY0 + NRows * TRH - 1) Then Begin
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
    If (SlotOf(CurTool) = B) And (SlotGroupSize(B) > 1) Then SelectTool(NextVariant(CurTool))
    Else SelectTool(ToolSlot[B]);
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
  If InRect(MX, MY, TLX0, TRY0, TLX1, TRY0 + NRows * TRH - 1) Then Begin
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
   If (B >= 0) And (CtlKind[B] = 0) And (CtlKP(CtlId[B]) >= 0) And (MX <= AX1 + 16) And
      (FirstSel >= 0) Then Begin
    PushUndo;
    KfToggleKey(FirstSel, CtlId[B], True);
    NeedA := True;
    NeedProg := True;
    NeedTL := True;
   End Else If (B >= 0) And (CtlKind[B] = 2) And (FirstSel >= 0) Then Begin
    PushUndo;
    If CtlKind[B] = 2 Then Begin
     If CtlGet(FirstSel, CtlId[B]) = 0 Then
      CtlApply(CtlId[B], CtlKindMax(CtlId[B], IsVideoTrack(P.Clips[FirstSel].Trk)))
     Else CtlApply(CtlId[B], CtlGet(FirstSel, CtlId[B]) - 1);
    End;
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
  AuStopPlay;
  AuActive := False;
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
  Ord('v'), Ord('V'): SelectTool(TL_SELECT);
  Ord('a'), Ord('A'): SelectTool(TL_TRACKFWD);
  Ord('q'), Ord('Q'): SelectTool(TL_TRACKBACK);
  Ord('b'), Ord('B'): SelectTool(TL_RIPPLE);
  Ord('y'), Ord('Y'): SelectTool(TL_SLIP);
  Ord('u'), Ord('U'): SelectTool(TL_SLIDE);
  Ord('c'), Ord('C'): SelectTool(TL_RAZOR);
  Ord('p'), Ord('P'): SelectTool(TL_PEN);
  Ord('h'), Ord('H'): SelectTool(TL_HAND);
  Ord('z'), Ord('Z'): SelectTool(TL_ZOOM);
  Ord('t'), Ord('T'): SelectTool(TL_TYPE);
  Ord('['): DoCommand(CM_PREVMARK);
  Ord('i'), Ord('I'): DoCommand(CM_MARKIN);
  Ord('o'), Ord('O'): DoCommand(CM_MARKOUT);
  Ord('x'), Ord('X'): DoCommand(CM_CLEARIO);
  Ord('m'), Ord('M'): DoCommand(CM_ADDMARK);
  Ord('n'), Ord('N'): DoCommand(CM_NEXTMARK);
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
 If TrueMode Then Begin
  VW := 640;
  VH := 360;
 End Else Begin
  VW := 284;
  VH := 160;
 End;
 InitLayout;
 InitCache;
 AuInit;
 AuActive := False;
 DefInterp := 0;
 LutCnt := 0;
 NextLink := 1;
 ToolSlot[0] := TL_SELECT;
 ToolSlot[1] := TL_RIPPLE;
 ToolSlot[2] := TL_RAZOR;
 ToolSlot[3] := TL_PEN;
 ToolSlot[4] := TL_HAND;
 ToolSlot[5] := TL_ZOOM;
 ToolSlot[6] := TL_TYPE;
 CnBuf := Nil;
 CnOn := False;
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
 For I := 1 To ParamCount Do
  If ExtOf(ParamStr(I)) = '.PRP' Then
   If LoadProject(ParamStr(I)) Then Begin
    EnsureCaches(False);
    ZoomFit;
   End;
End;

{ Analyse de la ligne de commande : retourne True si l'aide a ete demandee. }
Function ParseCommandLine: Boolean;
Var
 I: Integer;
 A: String;
Begin
 ParseCommandLine := False;
 MaxScreen := False;
 MaxColors := False;
 For I := 1 To ParamCount Do Begin
  A := UpStr(ParamStr(I));
  If A = '-MAXSCREEN' Then MaxScreen := True
  Else If A = '-MAXCOLORS' Then MaxColors := True
  Else If (A = '/?') Or (A = '-H') Or (A = '--HELP') Then ParseCommandLine := True;
 End;
End;

Procedure ShowCommandLineHelp;
Var
 HelpOutput: Text;
Begin
 { Un flux distinct conserve la sortie console, meme avec les unites Crt. }
 Assign(HelpOutput, '');
 Rewrite(HelpOutput);
 WriteLn(HelpOutput, 'PREMIERE - Cette commande permet de lancer le clone de Premiere Pro (montage video).');
 WriteLn(HelpOutput);
 WriteLn(HelpOutput, 'Syntaxe : PREMIERE [-maxscreen] [-maxcolors] [<projet.PRP>] [/? | -h | --help]');
 WriteLn(HelpOutput);
 WriteLn(HelpOutput, '  Sans option          Lance l''application graphique en 640x480.');
 WriteLn(HelpOutput, '  -h, --help           Affichent egalement cette aide.');
 WriteLn(HelpOutput, '  -maxscreen           Utilise la resolution maximale disponible.');
 WriteLn(HelpOutput, '  -maxcolors           Utilise le nombre maximal de couleurs (couleurs vraies).');
 WriteLn(HelpOutput, '  /?                   Affiche cette aide et quitte.');
 WriteLn(HelpOutput, '  <projet.PRP>         Ouvre ce projet au demarrage.');
 WriteLn(HelpOutput);
 WriteLn(HelpOutput, 'Avec -maxscreen (Free Pascal seulement), les moniteurs sont agrandis par un');
 WriteLn(HelpOutput, 'facteur entier et la chronologie occupe tout l''espace disponible.');
 WriteLn(HelpOutput, 'Avec -maxcolors (Free Pascal seulement), l''image est rendue en couleurs vraies et');
 WriteLn(HelpOutput, 'la resolution de la sequence (jusqu''a 1920x1080) et l''exportation H.264/AVI sont');
 WriteLn(HelpOutput, 'disponibles. Sans cette option : 16 couleurs tramees, sequence 284x160.');
 WriteLn(HelpOutput, 'Sous Turbo Pascal, ces deux options sont ignorees (VGA 640x480).');
 Close(HelpOutput);
End;

BEGIN
 If ParseCommandLine Then Begin
  ShowCommandLineHelp;
  Halt(0);
 End;
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
 AuStopPlay;
 StopSound;
 FreeHistory;
 CloseGraph;
END.
