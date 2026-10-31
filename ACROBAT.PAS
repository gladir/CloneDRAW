{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application ACROBAT

  Visionneuse / éditeur de documents PDF en mode graphique :
   - Ouverture de fichiers PDF (flux Flate, ASCIIHex, ASCII85, flux d'objets,
     texte, graphiques vectoriels, annotations simples)
   - Création de documents, pages, rotation, recadrage, filigrane, numérotation
   - Commentaires : texte, note, surlignage, soulignement, barré, crayon,
     ligne, flèche, rectangle, ovale, tampon, signature, biffure
   - Recherche de texte, vignettes, panneau des commentaires, zoom, défilement
   - Enregistrement en PDF 1.4, exportation en texte et en image BMP
   - Annuler / Rétablir

  Tout le code est contenu dans ce seul fichier (aucun $I, aucune unité
  externe autre que DOS, Crt et le module graphique).
}

Program ACROBAT;

{$IFDEF FPC}
 {$MODE OBJFPC}
 {$H-}
 {$Q-}
 {$R-}
 {$OVERFLOWCHECKS OFF}
{$ELSE}
 {$R-,Q-,S-}
 {$M 32768,0,655360}
{$ENDIF}

Uses {$IFDEF FPC}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

Const
 { Disposition de l'écran }
 MENU_H   = 20;
 TOOL_H   = 26;
 STATUS_H = 18;
 NAV_W    = 108;
 SBAR     = 16;

 {$IFDEF FPC}
 OBLK      = 256;
 PGBLK     = 64;
 PLBLK     = 2048;
 IMBLK     = 16;
 MAXIMG    = 65000;
 MAXPDFOBJ = 16000000;
 UNDO_MAX  = 24;
 UNDO_MEM  = 8000000;
 BUFSZ     = 500000;
 {$ELSE}
 OBLK      = 32;
 PGBLK     = 16;
 PLBLK     = 512;
 IMBLK     = 4;
 MAXIMG    = 1;
 MAXPDFOBJ = 3000;
 UNDO_MAX  = 6;
 UNDO_MEM  = 150000;
 BUFSZ     = 30000;
 {$ENDIF}

 { Types d'objets }
 K_TEXT   = 1;  K_LINE   = 2;  K_RECT   = 3;  K_OVAL   = 4;
 K_POLY   = 5;  K_INK    = 6;  K_IMAGE  = 7;  K_STAMP  = 8;
 K_REDACT = 9;  K_HILITE = 10; K_UNDER  = 11; K_STRIKE = 12;
 K_NOTE   = 13; K_ARROW  = 14;

 { Outils }
 TL_SELECT = 0; TL_HAND   = 1; TL_ZOOM   = 2; TL_TEXT   = 3;
 TL_NOTE   = 4; TL_HILITE = 5; TL_UNDER  = 6; TL_STRIKE = 7;
 TL_PENCIL = 8; TL_LINE   = 9; TL_ARROW  = 10; TL_RECT  = 11;
 TL_OVAL   = 12; TL_STAMP = 13; TL_SIGN  = 14; TL_REDACT = 15;
 TL_COUNT  = 16;

 { Menus }
 MN_FILE = 0; MN_EDIT = 1; MN_VIEW = 2; MN_PAGE = 3; MN_TOOLS = 4; MN_HELP = 5;
 MN_COUNT = 6;

 { Commandes }
 CM_NONE=0;    CM_NEW=1;      CM_OPEN=2;     CM_SAVE=3;     CM_SAVEAS=4;
 CM_EXPTXT=5;  CM_EXPBMP=6;   CM_INSFILE=7;  CM_PROPS=8;    CM_QUIT=9;
 CM_UNDO=10;   CM_REDO=11;    CM_DELETE=12;  CM_DUP=13;     CM_COPY=14;
 CM_PASTE=15;  CM_CUT=16;     CM_DESEL=17;   CM_EDITTXT=18; CM_OBJPROPS=19;
 CM_FIND=20;   CM_FINDNEXT=21; CM_COLOR=22;  CM_WIDTH=23;
 CM_ZOOMIN=30; CM_ZOOMOUT=31; CM_FITW=32;    CM_FITP=33;    CM_Z100=34;
 CM_ZOOMSET=35; CM_CONT=36;   CM_NAV=37;     CM_FULL=38;    CM_PREV=39;
 CM_NEXT=40;   CM_FIRST=41;   CM_LAST=42;    CM_GOTO=43;    CM_NAVMODE=44;
 CM_PGINS=50;  CM_PGDEL=51;   CM_PGDUP=52;   CM_ROTR=53;    CM_ROTL=54;
 CM_PGUP=55;   CM_PGDOWN=56;  CM_CROP=57;    CM_PGSIZE=58;  CM_NUMBER=59;
 CM_WATER=60;  CM_EXTRACT=61;
 CM_TOOL0=70;  { 70..85 : outils }
 CM_APPLYRED=90; CM_FLATTEN=91; CM_CLEARALL=92;
 CM_HELP=100;  CM_ABOUT=101;  CM_KEYS=102;

Type
 TImgRec = Record
  W, H: Integer;            { dimensions réduites }
  Pix: Pointer;             { RVB 5-6-5 (Word), W*H ; Nil pour un masque }
  Alpha: Pointer;           { Byte, W*H ou Nil }
  Raw: Pointer;             { flux d'origine (encore encodé) }
  RawLen: LongInt;
  OW, OH: LongInt;          { dimensions d'origine }
  CS, BPC: Byte;            { 1 gris, 3 RVB, 4 CMJN, 5 indexé }
  NF: Byte;
  Flt: Array[0..3] Of String[24];
  Pred, Cols, Clr: Integer;
  Pal: Pointer;
  PalN: Integer;
  PalBase: Byte;
  Mask, IsSM, Keep: Boolean;
  SMIdx: Integer;
  Decode: String[48];
  SrcObj: LongInt;          { n° d'objet PDF d'origine de l'image }
 End;
 PImgRec = ^TImgRec;
 PImgBlock = ^TImgBlock;
 TImgBlock = Record
  Next: PImgBlock;
  Items: Array[0..IMBLK - 1] Of TImgRec;
 End;

 TObjRec = Record
  Kind: Byte;
  Page: LongInt;
  X1, Y1, X2, Y2: Integer;
  Rgb, Rgb2: LongInt;
  Wd, Size, Style, Fill: Byte;
  P0, PN: LongInt;
  Src: Byte;                { 0 nouveau, 1 contenu d'origine, 2 annotation d'origine, 3 aperçu seul }
  SrcNum: LongInt;          { n° d'objet PDF d'origine (annotations) }
  SrcCnt: Integer;          { nombre d'éléments issus de la même annotation }
  Sum: LongInt;             { somme de contrôle à l'import (détection des modifications) }
  Txt: String[119];
 End;
 PObjRec = ^TObjRec;

 { Listes chaînées de blocs allouées dans le tas : aucune limite fixe. }
 PObjBlock = ^TObjBlock;
 TObjBlock = Record
  Next: PObjBlock;
  Items: Array[0..OBLK - 1] Of TObjRec;
 End;

 TPageRec = Record
  W, H: Integer;
  Rot: Byte;
  Top: LongInt;
  SrcPage: LongInt;         { n° d'objet de la page d'origine (0 : page nouvelle) }
  SrcCount: LongInt;        { nombre d'objets de contenu importés }
  OrigW, OrigH, OrigRot: Integer;
  MbX0, MbY1: Real;         { origine de la boîte de la page d'origine }
  SrcAnnObjs: LongInt;      { nombre d'objets issus des annotations d'origine }
 End;
 PPageRec = ^TPageRec;
 PPageBlock = ^TPageBlock;
 TPageBlock = Record
  Next: PPageBlock;
  Items: Array[0..PGBLK - 1] Of TPageRec;
 End;

 PPoolBlock = ^TPoolBlock;
 TPoolBlock = Record
  Next: PPoolBlock;
  X, Y: Array[0..PLBLK - 1] Of SmallInt;
 End;

 TMenuItem = Record
  Caption: String[40];
  Shortcut: String[12];
  Cmd: Integer;
  Separator: Boolean;
  Checked: Boolean;
 End;
 TMenu = Record
  Title: String[14];
  Items: Array[0..22] Of TMenuItem;
  ItemCount: Integer;
  X, Width: Integer;
 End;

 TUndoRec = Record
  Objs: Pointer;
  Pgs: Pointer;
  Cnt, PgCnt, Cur: Integer;
  Mem: LongInt;
 End;

 TField = Record
  Kind: Byte;        { 0 texte, 1 nombre, 2 choix, 3 couleur, 4 case, 9 étiquette }
  Lbl: String[30];
  Val: String[119];
  Choices: String[120];
  Mn, Mx: LongInt;
  Cur: Integer;
 End;

 TByteBuf = Array[0..{$IFDEF FPC}134217727{$ELSE}BUFSZ+16{$ENDIF}] Of Byte;
 PByteBuf = ^TByteBuf;
 TLArr = Array[0..{$IFDEF FPC}134217727{$ELSE}8000{$ENDIF}] Of LongInt;
 PLArr = ^TLArr;
 TXArr = Array[0..{$IFDEF FPC}134217727{$ELSE}8000{$ENDIF}] Of LongInt;
 PXArr = ^TXArr;
 TWArr = Array[0..{$IFDEF FPC}134217727{$ELSE}8000{$ENDIF}] Of Word;
 PWArr = ^TWArr;

Var
 { Document }
 ObjHead, ObjCurBlk: PObjBlock;
 ObjCurNo, ObjBlocks: LongInt;
 ImgHead, ImgCurBlk: PImgBlock;
 ImgCurNo, ImgBlocks: LongInt;
 ImgCount: LongInt;
 ObjCount: LongInt;
 PgHead, PgCurBlk: PPageBlock;
 PgCurNo, PgBlocks: LongInt;
 PageCount, CurPage: LongInt;
 PoolHead, PoolCurBlk: PPoolBlock;
 PoolCurNo, PoolBlocks: LongInt;
 PoolCount: LongInt;
 DocName: String;
 DocTitle, DocAuthor, DocSubject, DocKeywords, DocCreator: String[79];
 Modified: Boolean;
 DocEncrypted: Boolean;
 SrcFile: String;           { fichier PDF d'origine (mise à jour incrémentale) }
 SrcValid, InfoDirty, NeedFullRewrite: Boolean;
 SrcSize: LongInt;
 OrigOrder: PLArr;          { n° d'objets des pages d'origine, dans l'ordre }
 OrigPageCnt: LongInt;
 LoadNotice: String;

 { Vue }
 Zoom, FitMode: Integer;
 Scale: LongInt;
 ScrollX, ScrollY: LongInt;
 DocW, DocH: LongInt;
 ViewL, ViewT, ViewR, ViewB, ViewW, ViewH: Integer;
 Continuous, NavVisible, ToolbarVisible, NavTab: Integer;
 NavScroll: Integer;
 FullScreen: Boolean;

 { Sélection / outils }
 CurTool: Integer;
 SelObj: Integer;
 FindObj: Integer;
 FindText: String[79];
 FindCase: Boolean;
 ToolRgb: Array[0..TL_COUNT-1] Of LongInt;
 CurWidth, CurSize, CurFam, CurStyle, CurAngle: Integer;
 Clip: TObjRec;
 ClipValid: Boolean;
 ClipPts: Array[0..199] Of Integer;
 ClipPtCount: Integer;

 { Édition de texte en ligne }
 Editing: Boolean;
 EditObj, EditCaret: Integer;
 EditBlink: LongInt;

 { Souris / clavier }
 MX_, MY_, MB_, OMX, OMY, OMB: LongInt;
 Running: Boolean;
 MaxScreen: Boolean;
 MouseOK: Boolean;
 LastClickT: LongInt;
 LastClickX, LastClickY: LongInt;

 { Menus }
 Menus: Array[0..MN_COUNT-1] Of TMenu;
 MenuActive: Boolean;
 ActiveMenu, ActiveItem: Integer;
 UnderBuf: Pointer;
 UnderSize: LongInt;
 UnderX, UnderY, UnderW, UnderH: Integer;
 UnderValid: Boolean;

 { Annuler / rétablir }
 UndoStack: Array[0..UNDO_MAX-1] Of TUndoRec;
 UndoTop: Integer;
 RedoStack: Array[0..UNDO_MAX-1] Of TUndoRec;
 RedoTop: Integer;

 { Formulaires }
 Fields: Array[0..11] Of TField;
 NFields: Integer;

 { État du dernier survol (barre d'état) }
 HintText: String;
 StatusMsg: String;

 { Géométrie du contexte de page courant }
 GPg: Integer;
 GOX, GOY, GSc: LongInt;
 GRot: Integer;
 GPW, GPH: LongInt;

 { Pages -> écran }
 DragMode: Integer;
 DragX0, DragY0, DragX1, DragY1: LongInt;
 DragObj: Integer;
 DragHandle: Integer;
 DragPg: Integer;
 DragOX, DragOY: LongInt;
 InkCount0: Integer;
 PreviewOn: Boolean;
 PrevX1, PrevY1, PrevX2, PrevY2: LongInt;
 SBDragKind, SBDragOfs: LongInt;

{ ---------------------------------------------------------------------- }
{ Squelette : graphique et souris                                         }
{ ---------------------------------------------------------------------- }

{ Les seize couleurs de l'interface restent identiques dans le pilote D8bit. }
Procedure InitializeScreenPalette;
{$IFDEF FPC}
Const
 VgaRGB: Array[0..15, 0..2] Of Byte = (
  (0,0,0), (0,0,170), (0,170,0), (0,170,170),
  (170,0,0), (170,0,170), (170,85,0), (170,170,170),
  (85,85,85), (85,85,255), (85,255,85), (85,255,255),
  (255,85,85), (255,85,255), (255,255,85), (255,255,255));
Var
 I: Integer;
{$ENDIF}
Begin
 {$IFDEF FPC}
 If GetMaxColor > 15 Then
  For I := 0 To 15 Do SetRGBPalette(I, VgaRGB[I, 0], VgaRGB[I, 1], VgaRGB[I, 2]);
 {$ENDIF}
End;

Procedure InitializeGraphics;
Var
 {$IFDEF FPC}
 Driver, Mode: SmallInt;
 {$ELSE}
 Driver, Mode: Integer;
 {$ENDIF}
 ErrCode: Integer;
 {$IFDEF FPC}
 LoMode, HiMode: SmallInt;
 {$ENDIF}
Begin
 {$IFDEF FPC}
  If MaxScreen Then Begin
   { Option -maxscreen : palette indexée et résolution maximale disponible }
   Driver:=D8bit;
   GetModeRange(Driver,LoMode,HiMode);
   If HiMode>=LoMode Then Mode:=HiMode
   Else Begin Driver:=Detect; Mode:=0; End;
  End
   Else
  Begin
   Driver:=VGA;
   Mode:=VGAHi;
  End;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
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

{ ---------------------------------------------------------------------- }
{ Utilitaires                                                              }
{ ---------------------------------------------------------------------- }

Function IMin(A, B: LongInt): LongInt;
Begin
 If A < B Then IMin := A Else IMin := B;
End;

Function IMax(A, B: LongInt): LongInt;
Begin
 If A > B Then IMax := A Else IMax := B;
End;

Function IAbs(A: LongInt): LongInt;
Begin
 If A < 0 Then IAbs := -A Else IAbs := A;
End;

Function C16(V: LongInt): Integer;
Begin
 If V < -30000 Then V := -30000;
 If V > 30000 Then V := 30000;
 C16 := V;
End;

Function IStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IStr := S;
End;

Function StrInt(Const S: String; Def: LongInt): LongInt;
Var
 V: LongInt;
 Code: Integer;
Begin
 Val(S, V, Code);
 If Code <> 0 Then StrInt := Def Else StrInt := V;
End;

Function UpStr(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'a') And (S[I] <= 'z') Then S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

Function Pad2(N: LongInt): String;
Begin
 If N < 10 Then Pad2 := '0' + IStr(N) Else Pad2 := IStr(N);
End;

{ Réel -> texte PDF (2 décimales au maximum) }
Function RStr(R: Real): String;
Var
 S: String;
 L: LongInt;
 Neg: Boolean;
 F: LongInt;
Begin
 Neg := R < 0;
 If Neg Then R := -R;
 L := Trunc(R);
 F := Round((R - L) * 100);
 If F >= 100 Then Begin Inc(L); F := 0; End;
 S := IStr(L);
 If F > 0 Then Begin
  If F < 10 Then S := S + '.0' + IStr(F)
  Else Begin
   S := S + '.' + IStr(F);
   If S[Length(S)] = '0' Then Delete(S, Length(S), 1);
  End;
 End;
 If Neg And (S <> '0') Then S := '-' + S;
 RStr := S;
End;

{ Réel -> texte PDF avec 4 décimales (matrices de rotation) }
Function RStr4(R: Real): String;
Var
 L, F: LongInt;
 Neg: Boolean;
 S, T: String;
Begin
 Neg := R < 0;
 If Neg Then R := -R;
 L := Trunc(R);
 F := Round((R - L) * 10000);
 If F >= 10000 Then Begin Inc(L); F := 0; End;
 S := IStr(L);
 If F > 0 Then Begin
  T := IStr(F);
  While Length(T) < 4 Do T := '0' + T;
  While T[Length(T)] = '0' Do Delete(T, Length(T), 1);
  S := S + '.' + T;
 End;
 If Neg And (S <> '0') Then S := '-' + S;
 RStr4 := S;
End;

Function FileExists(Const Name: String): Boolean;
Var
 F: File;
 Attr: Word;
Begin
 Assign(F, Name);
 GetFAttr(F, Attr);
 FileExists := (DosError = 0) And ((Attr And Directory) = 0);
End;

Function ExtOf(Const Name: String): String;
Var
 I: Integer;
Begin
 I := Length(Name);
 While (I > 0) And (Name[I] <> '.') And (Name[I] <> '\') And (Name[I] <> '/') Do Dec(I);
 If (I > 0) And (Name[I] = '.') Then ExtOf := UpStr(Copy(Name, I, 255)) Else ExtOf := '';
End;

Function BaseName(Const Name: String): String;
Var
 I: Integer;
Begin
 I := Length(Name);
 While (I > 0) And (Name[I] <> '\') And (Name[I] <> '/') Do Dec(I);
 BaseName := Copy(Name, I + 1, 255);
End;

Function NowMs: LongInt;
Var
 H, M, S, S100: Word;
Begin
 GetTime(H, M, S, S100);
 NowMs := ((LongInt(H) * 60 + M) * 60 + S) * 1000 + S100 * 10;
End;

{ Conversion WinAnsi -> glyphe CP437 de la police 8x8 }
Function Win2Glyph(C: Integer): Integer;
Begin
 Win2Glyph := C;
 If C < 128 Then Exit;
 Case C Of
  199: Win2Glyph := 128; 252: Win2Glyph := 129; 233: Win2Glyph := 130;
  226: Win2Glyph := 131; 228: Win2Glyph := 132; 224: Win2Glyph := 133;
  229: Win2Glyph := 134; 231: Win2Glyph := 135; 234: Win2Glyph := 136;
  235: Win2Glyph := 137; 232: Win2Glyph := 138; 239: Win2Glyph := 139;
  238: Win2Glyph := 140; 236: Win2Glyph := 141; 196: Win2Glyph := 142;
  197: Win2Glyph := 143; 201: Win2Glyph := 144; 230: Win2Glyph := 145;
  198: Win2Glyph := 146; 244: Win2Glyph := 147; 246: Win2Glyph := 148;
  242: Win2Glyph := 149; 251: Win2Glyph := 150; 249: Win2Glyph := 151;
  255: Win2Glyph := 152; 214: Win2Glyph := 153; 220: Win2Glyph := 154;
  162: Win2Glyph := 155; 163: Win2Glyph := 156; 165: Win2Glyph := 157;
  131: Win2Glyph := 159; 225: Win2Glyph := 160; 237: Win2Glyph := 161;
  243: Win2Glyph := 162; 250: Win2Glyph := 163; 241: Win2Glyph := 164;
  209: Win2Glyph := 165; 170: Win2Glyph := 166; 186: Win2Glyph := 167;
  191: Win2Glyph := 168; 172: Win2Glyph := 170; 189: Win2Glyph := 171;
  188: Win2Glyph := 172; 161: Win2Glyph := 173; 171: Win2Glyph := 174;
  187: Win2Glyph := 175; 223: Win2Glyph := 225; 181: Win2Glyph := 230;
  177: Win2Glyph := 241; 247: Win2Glyph := 246; 176: Win2Glyph := 248;
  183: Win2Glyph := 250; 178: Win2Glyph := 253;
  192,193,194,195: Win2Glyph := Ord('A');
  200,202,203: Win2Glyph := Ord('E');
  204,205,206,207: Win2Glyph := Ord('I');
  210,211,212,213: Win2Glyph := Ord('O');
  217,218,219: Win2Glyph := Ord('U');
  145,146,130: Win2Glyph := Ord('''');
  147,148,132: Win2Glyph := Ord('"');
  150,151: Win2Glyph := Ord('-');
  149: Win2Glyph := 7;
  133: Win2Glyph := Ord('.');
  128: Win2Glyph := Ord('E');
  160: Win2Glyph := 32;
 Else
  Win2Glyph := Ord('?');
 End;
End;

{ CP437 (clavier) -> WinAnsi (document) }
Function Dos2Win(C: Integer): Integer;
Var
 I: Integer;
Begin
 Dos2Win := C;
 If C < 128 Then Exit;
 For I := 160 To 255 Do
  If (Win2Glyph(I) = C) And (Not (I In [192..195, 200, 202..207, 210..213, 217..219, 160])) Then Begin
   Dos2Win := I;
   Exit;
  End;
 Dos2Win := Ord('?');
End;

{ UTF-8 (source) -> CP437 pour l'interface }
Function U2C(Const S: String): String;
Var
 I: Integer;
 R: String;
 C: Integer;
Begin
 R := '';
 I := 1;
 While I <= Length(S) Do Begin
  C := Ord(S[I]);
  If (C = $C3) And (I < Length(S)) Then Begin
   R := R + Chr(Win2Glyph(Ord(S[I + 1]) + 64));
   Inc(I, 2);
  End
  Else If (C = $C2) And (I < Length(S)) Then Begin
   R := R + Chr(Win2Glyph(Ord(S[I + 1])));
   Inc(I, 2);
  End
  Else If (C = $E2) And (I + 2 <= Length(S)) Then Begin
   R := R + '-';
   Inc(I, 3);
  End
  Else Begin
   R := R + S[I];
   Inc(I);
  End;
 End;
 U2C := R;
End;

{ UTF-8 (source) -> WinAnsi pour le document }
Function U2W(Const S: String): String;
Var
 I: Integer;
 R: String;
 C: Integer;
Begin
 R := '';
 I := 1;
 While I <= Length(S) Do Begin
  C := Ord(S[I]);
  If (C = $C3) And (I < Length(S)) Then Begin
   R := R + Chr(Ord(S[I + 1]) + 64);
   Inc(I, 2);
  End
  Else If (C = $C2) And (I < Length(S)) Then Begin
   R := R + S[I + 1];
   Inc(I, 2);
  End
  Else Begin
   R := R + S[I];
   Inc(I);
  End;
 End;
 U2W := R;
End;

Function TW(Const S: String): Integer;
Begin
 TW := Length(U2C(S)) * 8;
End;

Procedure DS(X, Y: Integer; Const S: String);
Begin
 OutTextXY(X, Y, U2C(S));
End;

Procedure DSC(X, Y, W: Integer; Const S: String);
Begin
 DS(X + (W - TW(S)) Div 2, Y, S);
End;

Procedure DSA(X, Y: Integer; Const S: String; ACol: Integer);
Begin
 SetColor(ACol);
 DS(X, Y, S);
End;

{ ---------------------------------------------------------------------- }
{ Listes chaînées de blocs (tas) : objets, pages, points de tracé, images  }
{ L'accès par indice parcourt la chaîne ; un curseur mémorise le dernier   }
{ bloc atteint, ce qui rend les boucles séquentielles très rapides.        }
{ ---------------------------------------------------------------------- }

Function NewObjBlock: PObjBlock;
Var
 B: PObjBlock;
Begin
 GetMem(B, SizeOf(TObjBlock));
 If B <> Nil Then Begin
  FillChar(B^, SizeOf(TObjBlock), 0);
  B^.Next := Nil;
 End;
 NewObjBlock := B;
End;

{ S'assure que l'indice I existe ; retourne False si le tas est épuisé }
Function ObjEnsure(I: LongInt): Boolean;
Var
 B, T: PObjBlock;
Begin
 ObjEnsure := True;
 While I >= ObjBlocks * OBLK Do Begin
  B := NewObjBlock;
  If B = Nil Then Begin ObjEnsure := False; Exit; End;
  If ObjHead = Nil Then ObjHead := B
  Else Begin
   T := ObjHead;
   If ObjCurBlk <> Nil Then If ObjCurNo = ObjBlocks - 1 Then T := ObjCurBlk Else T := ObjHead;
   While T^.Next <> Nil Do T := T^.Next;
   T^.Next := B;
  End;
  Inc(ObjBlocks);
 End;
End;

Function ObjP(I: LongInt): PObjRec;
Var
 BNo, K: LongInt;
 B: PObjBlock;
Begin
 BNo := I Div OBLK;
 If (ObjCurBlk <> Nil) And (BNo >= ObjCurNo) Then Begin B := ObjCurBlk; K := ObjCurNo; End
 Else Begin B := ObjHead; K := 0; End;
 While (K < BNo) And (B <> Nil) Do Begin B := B^.Next; Inc(K); End;
 If B = Nil Then B := ObjHead;
 ObjCurBlk := B; ObjCurNo := BNo;
 ObjP := @B^.Items[I Mod OBLK];
End;

Procedure ObjsFree;
Var
 B, N: PObjBlock;
Begin
 B := ObjHead;
 While B <> Nil Do Begin N := B^.Next; FreeMem(B, SizeOf(TObjBlock)); B := N; End;
 ObjHead := Nil; ObjCurBlk := Nil; ObjCurNo := 0; ObjBlocks := 0; ObjCount := 0;
End;

Function PgEnsure(I: LongInt): Boolean;
Var
 B, T: PPageBlock;
Begin
 PgEnsure := True;
 While I > PgBlocks * PGBLK Do Begin
  GetMem(B, SizeOf(TPageBlock));
  If B = Nil Then Begin PgEnsure := False; Exit; End;
  FillChar(B^, SizeOf(TPageBlock), 0);
  If PgHead = Nil Then PgHead := B
  Else Begin
   T := PgHead;
   While T^.Next <> Nil Do T := T^.Next;
   T^.Next := B;
  End;
  Inc(PgBlocks);
 End;
End;

{ Pages numérotées à partir de 1 }
Function PgP(I: LongInt): PPageRec;
Var
 BNo, K: LongInt;
 B: PPageBlock;
Begin
 BNo := (I - 1) Div PGBLK;
 If (PgCurBlk <> Nil) And (BNo >= PgCurNo) Then Begin B := PgCurBlk; K := PgCurNo; End
 Else Begin B := PgHead; K := 0; End;
 While (K < BNo) And (B <> Nil) Do Begin B := B^.Next; Inc(K); End;
 If B = Nil Then B := PgHead;
 PgCurBlk := B; PgCurNo := BNo;
 PgP := @B^.Items[(I - 1) Mod PGBLK];
End;

Procedure PgsFree;
Var
 B, N: PPageBlock;
Begin
 B := PgHead;
 While B <> Nil Do Begin N := B^.Next; FreeMem(B, SizeOf(TPageBlock)); B := N; End;
 PgHead := Nil; PgCurBlk := Nil; PgCurNo := 0; PgBlocks := 0; PageCount := 0;
End;

Function PoolEnsure(I: LongInt): Boolean;
Var
 B, T: PPoolBlock;
Begin
 PoolEnsure := True;
 While I > PoolBlocks * PLBLK Do Begin
  GetMem(B, SizeOf(TPoolBlock));
  If B = Nil Then Begin PoolEnsure := False; Exit; End;
  FillChar(B^, SizeOf(TPoolBlock), 0);
  If PoolHead = Nil Then PoolHead := B
  Else Begin
   T := PoolHead;
   While T^.Next <> Nil Do T := T^.Next;
   T^.Next := B;
  End;
  Inc(PoolBlocks);
 End;
End;

Function PoolBlk(I: LongInt): PPoolBlock;
Var
 BNo, K: LongInt;
 B: PPoolBlock;
Begin
 BNo := I Div PLBLK;
 If (PoolCurBlk <> Nil) And (BNo >= PoolCurNo) Then Begin B := PoolCurBlk; K := PoolCurNo; End
 Else Begin B := PoolHead; K := 0; End;
 While (K < BNo) And (B <> Nil) Do Begin B := B^.Next; Inc(K); End;
 If B = Nil Then B := PoolHead;
 PoolCurBlk := B; PoolCurNo := BNo;
 PoolBlk := B;
End;

Function PoolXP(I: LongInt): PSmallInt;
Begin
 PoolXP := @PoolBlk(I)^.X[I Mod PLBLK];
End;

Function PoolYP(I: LongInt): PSmallInt;
Begin
 PoolYP := @PoolBlk(I)^.Y[I Mod PLBLK];
End;

Procedure PoolFree;
Var
 B, N: PPoolBlock;
Begin
 B := PoolHead;
 While B <> Nil Do Begin N := B^.Next; FreeMem(B, SizeOf(TPoolBlock)); B := N; End;
 PoolHead := Nil; PoolCurBlk := Nil; PoolCurNo := 0; PoolBlocks := 0; PoolCount := 0;
End;

Function ImgEnsure(I: LongInt): Boolean;
Var
 B, T: PImgBlock;
Begin
 ImgEnsure := True;
 While I > ImgBlocks * IMBLK Do Begin
  GetMem(B, SizeOf(TImgBlock));
  If B = Nil Then Begin ImgEnsure := False; Exit; End;
  FillChar(B^, SizeOf(TImgBlock), 0);
  If ImgHead = Nil Then ImgHead := B
  Else Begin
   T := ImgHead;
   While T^.Next <> Nil Do T := T^.Next;
   T^.Next := B;
  End;
  Inc(ImgBlocks);
 End;
End;

{ Images numérotées à partir de 1 }
Function ImgP(I: LongInt): PImgRec;
Var
 BNo, K: LongInt;
 B: PImgBlock;
Begin
 BNo := (I - 1) Div IMBLK;
 If (ImgCurBlk <> Nil) And (BNo >= ImgCurNo) Then Begin B := ImgCurBlk; K := ImgCurNo; End
 Else Begin B := ImgHead; K := 0; End;
 While (K < BNo) And (B <> Nil) Do Begin B := B^.Next; Inc(K); End;
 If B = Nil Then B := ImgHead;
 ImgCurBlk := B; ImgCurNo := BNo;
 ImgP := @B^.Items[(I - 1) Mod IMBLK];
End;

Procedure ImgListFree;
Var
 B, N: PImgBlock;
Begin
 B := ImgHead;
 While B <> Nil Do Begin N := B^.Next; FreeMem(B, SizeOf(TImgBlock)); B := N; End;
 ImgHead := Nil; ImgCurBlk := Nil; ImgCurNo := 0; ImgBlocks := 0; ImgCount := 0;
End;

{ Tables de la compression deflate (RFC 1951) }
Const
 LBase: Array[0..28] Of Word = (3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258);
 LExtra: Array[0..28] Of Byte = (0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DBase: Array[0..29] Of Word = (1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577);
 DExtra: Array[0..29] Of Byte = (0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13);
 CLOrder: Array[0..18] Of Byte = (16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);

{ ---------------------------------------------------------------------- }
{ Couleurs                                                                 }
{ ---------------------------------------------------------------------- }

Const
 PalRgb: Array[0..15] Of LongInt = (
  $000000,$0000C0,$00A000,$00A0A0,$C00000,$A000A0,$A05000,$B0B0B0,
  $606060,$4040FF,$40E040,$40E0E0,$FF4040,$FF40FF,$FFFF00,$FFFFFF);

Function RGBOf(R, G, B: LongInt): LongInt;
Begin
 If R < 0 Then R := 0; If R > 255 Then R := 255;
 If G < 0 Then G := 0; If G > 255 Then G := 255;
 If B < 0 Then B := 0; If B > 255 Then B := 255;
 RGBOf := (R Shl 16) Or (G Shl 8) Or B;
End;

Function Nearest16(Rgb: LongInt): Integer;
Var
 I, Best: Integer;
 D, BD, DR, DG, DB: LongInt;
Begin
 Best := 0;
 BD := MaxLongInt;
 For I := 0 To 15 Do Begin
  DR := ((Rgb Shr 16) And 255) - ((PalRgb[I] Shr 16) And 255);
  DG := ((Rgb Shr 8) And 255) - ((PalRgb[I] Shr 8) And 255);
  DB := (Rgb And 255) - (PalRgb[I] And 255);
  D := DR * DR * 3 + DG * DG * 4 + DB * DB * 2;
  If D < BD Then Begin BD := D; Best := I; End;
 End;
 Nearest16 := Best;
End;

{ ---------------------------------------------------------------------- }
{ Polices : glyphes 8x8 mis à l'échelle + largeurs Helvetica               }
{ ---------------------------------------------------------------------- }

Const
 HelvW: Array[32..126] Of Word = (
  278,278,355,556,556,889,667,191,333,333,389,584,278,333,278,278,
  556,556,556,556,556,556,556,556,556,556,278,278,584,584,584,556,
  1015,667,667,722,722,667,611,778,722,278,500,667,556,833,722,778,
  667,778,722,667,611,722,667,944,667,667,611,278,278,278,469,556,
  333,556,556,500,556,556,278,556,556,222,222,500,222,833,556,556,
  556,556,333,500,278,556,500,722,500,500,500,334,260,334,584);

Const
 VFirst = 32;
 VLast = 255;
 VFData: Array[32..255] Of String[60] = (
  '0',
  '2 ->l>J -><>>',
  '9 -@l@` -JlJ`',
  'B -F<Ll -R<Xl -@J^J ->\\\',
  '@ ~Z`RfJhBd>^BVLRVNZFV@L>B@<F -L8Ln',
  'D -@<^l ~BlHhBb<hBl ~\HbD\>VD\H',
  'A ~\<DVBbHhNhRbLV@J@BH<P>\L',
  '2 ->l>`',
  '6 ~Fp@d>T@BF6',
  '6 ~>pDdFTDB>6',
  ': -FlFX ->fN^ ->^Nf',
  '@ -@TXT -L`LH',
  '2 ->>>:<4',
  ': ->PNP',
  '2 -><>>',
  '9 -<8Nl',
  '@ ~LlXf\TXBL<@B<T@fLl',
  '9 ->dHlH<',
  '@ ~>bDjLlThX`TVHH>< -><Z<',
  '@ ~>fFlPlXfX^PVHTPRZJZBR<F<>B',
  '@ -T<Tl<J\J',
  '@ -XlBl@V ~@VFZPZXTZJV@N<D<>B',
  '@ ~VhNlFj@`<N@BJ<T@XJTTJXBV<N',
  '@ -<lZlH<',
  '@ ~LlThT`LXD`DhLl ~LXVTZJV@L<B@>JBTLX',
  '@ ~B@J<R>XH\ZXfNlDh@^DTNPVR\Z',
  '2 -><>> ->T>V',
  '2 ->T>V ->>>:<4',
  '= -T\>NT@',
  '> ->XVX ->JVJ',
  '= ->\TN>@',
  '> ~>dDjLlThV`RXJRJJ -J<J>',
  'F ~b@X8L6B>>NB`Nh\ff\fL`FZHZP ~ZVTZNVLNPHVHZV',
  'D -<<Pld< -DN\N',
  '@ -><>l ~>lPlXfX\PV>V ~>VRVZNZDR<><',
  'B ~^bVjNlDh>^>JD@N<V>^F',
  'A -><>l ~>lLlXd\TXDL<><',
  '> -Vl>l><V< ->TRT',
  '= -><>lVl ->TRT',
  'C ~^bVjNlDh>^>JD@N<Z@^J^P -PP^P',
  '@ -><>l -Z<Zl ->TZT',
  '2 -><>l',
  '< ~RlRHN>F<@@<H',
  'A -><>l -Zl>L -FR\<',
  '= ->l><T<',
  'D -><>lPBblb<',
  '@ -><>lZ<Zl',
  'D ~Pl^fbT^BP<BB>TBfPl',
  '? -><>l ~>lPlXfX\PT>T',
  'D ~Pl^fbT^BP<BB>TBfPl -TFb8',
  '@ -><>l ~>lRlZfZ\RT>T -NT\<',
  '@ ~ZdRjJlBh>bBZLTVPZHV@L<B><D',
  '@ -<l\l -LlL<',
  '@ ~>l>JB@L<V@ZJZl',
  'B -<lN<`l',
  'J -<lH<V`d<pl',
  'A -<l^< -<<^l',
  'B -<lNR`l -NRN<',
  '@ ->lZl><Z<',
  '6 -Fp>p>4F4',
  '9 -<lN8',
  '6 ->pFpF4>4',
  ': ->\FhN\',
  '> -<2X2',
  '5 ->lDd',
  '> ~VNRZJ^BZ>NBBJ<RBVN -V^V<',
  '> ->l>< ~>NBZJ^RZVNRBJ<BB>N',
  '= ~VXP^H^@X<N@BH<P<VB',
  '> -VlV< ~VNRZJ^BZ>NBBJ<RBVN',
  '> ~<NXNVXN^H^@Z<N@BH<P<VB',
  '< ~H<HdJjPlTj -@^P^',
  '> ~VNRZJ^BZ>NBBJ<RBVN ~V^V:R2H0@4',
  '= ->l>< ~>RD\L^RZTRT<',
  '2 ->^>< ->f>j',
  '6 ~F^F6D2>0 -FfFj',
  '= ->l>< -T^>H -FNV<',
  '2 ->l><',
  'F ->^>< ~>RB\J^PZRRR< ~RRV\^^dZfRf<',
  '= ->^>< ~>RD\L^RZTRT<',
  '> ~J^TXXNTBJ<@B<N@XJ^',
  '> ->^>0 ~>NBZJ^RZVNRBJ<BB>N',
  '> -V^V0 ~VNRZJ^BZ>NBBJ<RBVN',
  ': ->^>< ~>RB\J^P\',
  '< ~TXN^F^@Z@TFNNJTDR>J<B><D',
  '; -FhFD ~FDH>N<R> ->^P^',
  '= ->^>H ~>H@@H<P@TH -T^T<',
  '> -<^J<X^',
  'F -<^F<RX^<h^',
  '= -<^V< -<<V^',
  '> -<^J< -X^F0',
  '= ->^T^><T<',
  '8 ~JpDlD\>TDLD<J6',
  '2 ->p>4',
  '8 ~>pDlD\JTDLD<>6',
  '< ~<LBTHRNJTR',
  '2 ->^><',
  '@ ~^bVjNlDh>^>JD@N<V>^F -<XRX -<PRP',
  '',
  '2 ->>>:<4',
  '',
  '9 -@l@` -JlJ`',
  '> -><>> -H<H> -R<R>',
  '',
  '',
  '',
  '',
  '@ ~ZdRjJlBh>bBZLTVPZHV@L<B><D -FvLnRv',
  '',
  'P ~Pl^fbT^BP<BB>TBfPl -|ldld<|< -dTxT',
  '',
  '@ ->lZl><Z< -FvLnRv',
  '',
  '',
  '2 ->l>`',
  '2 ->l>`',
  '9 -@l@` -JlJ`',
  '9 -@l@` -JlJ`',
  '8 ~DVJRDN>RDV ~DTFRDPBRDT',
  '> -<PXP',
  'D -<PdP',
  '',
  'F -<pOp -FpFS -SRSj\UejeR',
  '< ~TXN^F^@Z@TFNNJTDR>J<B><D -BhH`Nh',
  '',
  'K ~J^TXXNTBJ<@B<N@XJ^ ~VNrNpXh^b^ZZVNZBb<j<pB',
  '',
  '= ->^T^><T< -ChI`Oh',
  '',
  '0',
  '2 -><>^ ->l>j',
  '= ~VXP^H^@X<N@BH<P<VB -JhJ6',
  '> ~VfPlHlBfBX@H<> -<<V< -<RLR',
  '',
  'B -<lNR`l -NRN< -BRZR -BHZH',
  '2 ->p>V ->N>4',
  '> ~RfLjDhB`JZRTRJJFBH ~JZBTBJJD',
  '8 ->l>j -JlJj',
  'F ~RlbdfRb@R<B@>RBdRl ~ZZT^NZLRNJTHZL',
  '9 ~LbIiDl@i=b@[DWI[Lb -LlLW',
  '@ -L\BPLD -X\NPXD',
  '> ->TVTVH',
  ': ->PNP',
  'F ~RlbdfRb@R<B@>RBdRl -LHL\ ~L\T\XXTRLR -RRXH',
  ': -<lPl',
  '6 ~BlHhBb<hBl',
  '> -@\T\ -JhJP -@DTD',
  '8 ~=n@rEsIqKlIgC_=Y -=YLY',
  '8 ~=pBsGsKpKkGgCfGeL`L\HYBY=\',
  '5 ->dDl',
  '= ->^>H ~>H@@H<P@TH -T^T< ->^>0',
  '',
  '2 ->P>R',
  '5 -@<@8<4',
  '5 -=oCsCY',
  '9 ~DlJhMbJ[DW>[<b>hDl',
  '@ -@\JP@D -L\VPLD',
  'J -=mCrCU -N<^d -j7jT\@o@',
  'J -=mCrCU -N<^d ~]NaSfTjRmMjGc>]7 -]7n7',
  'J ~=nBrHrMnMjHeCdHbN^NYIUBU=Y -N<^d -j7jT\@o@',
  '> ~>DD>L<T@VHRPJVJ^ -JlJj',
  'D -<<Pld< -DN\N -JvRn',
  'D -<<Pld< -DN\N -NnVv',
  'D -<<Pld< -DN\N -JnPvVn',
  'D -<<Pld< -DN\N ~HpLvRrXv',
  'D -<<Pld< -DN\N -JrJt -VrVt',
  'D -<<Pld< -DN\N ~PxTtPpLtPx',
  'P -<<Pld< -DN\N -xl`l`<x< -`TtT',
  'B ~^bVjNlDh>^>JD@N<V>^F -N<N8J4',
  '> -Vl>l><V< ->TRT -DvLn',
  '> -Vl>l><V< ->TRT -HnPv',
  '> -Vl>l><V< ->TRT -DnJvPn',
  '> -Vl>l><V< ->TRT -DrDt -PrPt',
  '2 -><>l -8v@n',
  '2 -><>l -<nDv',
  '2 -><>l -8n>vDn',
  '2 -><>l -8r8t -DrDt',
  '',
  '@ -><>lZ<Zl ~DpHvNrTv',
  'D ~Pl^fbT^BP<BB>TBfPl -JvRn',
  'D ~Pl^fbT^BP<BB>TBfPl -NnVv',
  'D ~Pl^fbT^BP<BB>TBfPl -JnPvVn',
  'D ~Pl^fbT^BP<BB>TBfPl ~HpLvRrXv',
  'D ~Pl^fbT^BP<BB>TBfPl -JrJt -VrVt',
  '> -@\TH -@HT\',
  'D ~Pl^fbT^BP<BB>TBfPl ->:bl',
  '@ ~>l>JB@L<V@ZJZl -FvNn',
  '@ ~>l>JB@L<V@ZJZl -JnRv',
  '@ ~>l>JB@L<V@ZJZl -FnLvRn',
  '@ ~>l>JB@L<V@ZJZl -FrFt -RrRt',
  'B -<lNR`l -NRN< -LnTv',
  '',
  '= -><>h ~>`BjJlRhR`JZRTTHN>D<',
  '> ~VNRZJ^BZ>NBBJ<RBVN -V^V< -DhL`',
  '> ~VNRZJ^BZ>NBBJ<RBVN -V^V< -H`Ph',
  '> ~VNRZJ^BZ>NBBJ<RBVN -V^V< -D`JhP`',
  '> ~VNRZJ^BZ>NBBJ<RBVN -V^V< ~BbFhLdRh',
  '> ~VNRZJ^BZ>NBBJ<RBVN -V^V< -DdDf -PdPf',
  '> ~VNRZJ^BZ>NBBJ<RBVN -V^V< ~JjNfJbFfJj',
  'K ~VNRZJ^BZ>NBBJ<RBVN -V^V< ~VNrNpXh^b^ZZVNZBb<j<pB',
  '= ~VXP^H^@X<N@BH<P<VB -I<I8E4',
  '> ~<NXNVXN^H^@Z<N@BH<P<VB -DhL`',
  '> ~<NXNVXN^H^@Z<N@BH<P<VB -H`Ph',
  '> ~<NXNVXN^H^@Z<N@BH<P<VB -D`JhP`',
  '> ~<NXNVXN^H^@Z<N@BH<P<VB -DdDf -PdPf',
  '2 ->^>< -8h@`',
  '2 ->^>< -<`Dh',
  '2 ->^>< -8`>hD`',
  '2 ->^>< -8d8f -DdDf',
  '',
  '= ->^>< ~>RD\L^RZTRT< ~AbEhKdQh',
  '> ~J^TXXNTBJ<@B<N@XJ^ -DhL`',
  '> ~J^TXXNTBJ<@B<N@XJ^ -H`Ph',
  '> ~J^TXXNTBJ<@B<N@XJ^ -D`JhP`',
  '> ~J^TXXNTBJ<@B<N@XJ^ ~BbFhLdRh',
  '> ~J^TXXNTBJ<@B<N@XJ^ -DdDf -PdPf',
  '> -@RTR -J^J` -JDJF',
  '> ~J^TXXNTBJ<@B<N@XJ^ ->:V`',
  '= ->^>H ~>H@@H<P@TH -T^T< -ChK`',
  '= ->^>H ~>H@@H<P@TH -T^T< -G`Oh',
  '= ->^>H ~>H@@H<P@TH -T^T< -C`IhO`',
  '= ->^>H ~>H@@H<P@TH -T^T< -CdCf -OdOf',
  '> -<^J< -X^F0 -H`Ph',
  '',
  '> -<^J< -X^F0 -DdDf -PdPf');

{ Largeur d'un caractère en 1/1000 d'em }
Function CharW(Fam, Style, C: Integer): Integer;
Var
 W: Integer;
Begin
 If Fam = 2 Then Begin CharW := 600; Exit; End;
 If (C >= 32) And (C <= 126) Then W := HelvW[C]
 Else If C >= 160 Then W := 556
 Else W := 500;
 If Fam = 1 Then W := W * 9 Div 10;
 If (Style And 1) <> 0 Then W := W * 106 Div 100;
 CharW := W;
End;

Function TextLenPts(Const S: String; Size, Fam, Style: Integer): LongInt;
Var
 I: Integer;
 T: LongInt;
Begin
 T := 0;
 For I := 1 To Length(S) Do T := T + CharW(Fam, Style, Ord(S[I]));
 TextLenPts := (T * Size + 999) Div 1000;
End;

{ ---------------------------------------------------------------------- }
{ Géométrie de page                                                         }
{ ---------------------------------------------------------------------- }

Procedure SetCtx(Pg: Integer; OX, OY, Sc: LongInt);
Begin
 GPg := Pg;
 GOX := OX;
 GOY := OY;
 GSc := Sc;
 GRot := PgP(Pg)^.Rot And 3;
 GPW := PgP(Pg)^.W;
 GPH := PgP(Pg)^.H;
End;

Function PU(U: LongInt): LongInt;
Begin
 PU := (U * GSc) Div 1024;
End;

Function MXp(X, Y: LongInt): LongInt;
Var
 U: LongInt;
Begin
 Case GRot Of
  0: U := X;
  1: U := GPH - Y;
  2: U := GPW - X;
 Else U := Y;
 End;
 MXp := GOX + PU(U);
End;

Function MYp(X, Y: LongInt): LongInt;
Var
 V: LongInt;
Begin
 Case GRot Of
  0: V := Y;
  1: V := X;
  2: V := GPH - Y;
 Else V := GPW - X;
 End;
 MYp := GOY + PU(V);
End;

{ Variantes en réels (positions fractionnaires en points) }
Function MXr(X, Y: Real): LongInt;
Var
 U: Real;
Begin
 Case GRot Of
  0: U := X;
  1: U := GPH - Y;
  2: U := GPW - X;
 Else U := Y;
 End;
 MXr := GOX + Round(U * GSc / 1024);
End;

Function MYr(X, Y: Real): LongInt;
Var
 V: Real;
Begin
 Case GRot Of
  0: V := Y;
  1: V := X;
  2: V := GPH - Y;
 Else V := GPW - X;
 End;
 MYr := GOY + Round(V * GSc / 1024);
End;

Procedure Unmap(SX, SY: LongInt; Var X, Y: LongInt);
Var
 U, V: LongInt;
Begin
 If GSc < 1 Then GSc := 1;
 U := ((SX - GOX) * 1024) Div GSc;
 V := ((SY - GOY) * 1024) Div GSc;
 Case GRot Of
  0: Begin X := U; Y := V; End;
  1: Begin Y := GPH - U; X := V; End;
  2: Begin X := GPW - U; Y := GPH - V; End;
 Else
  Begin Y := U; X := GPW - V; End;
 End;
End;

Function DispWOf(Pg: Integer; Sc: LongInt): LongInt;
Begin
 If (PgP(Pg)^.Rot And 1) <> 0 Then DispWOf := (LongInt(PgP(Pg)^.H) * Sc) Div 1024
 Else DispWOf := (LongInt(PgP(Pg)^.W) * Sc) Div 1024;
End;

Function DispHOf(Pg: Integer; Sc: LongInt): LongInt;
Begin
 If (PgP(Pg)^.Rot And 1) <> 0 Then DispHOf := (LongInt(PgP(Pg)^.W) * Sc) Div 1024
 Else DispHOf := (LongInt(PgP(Pg)^.H) * Sc) Div 1024;
End;

{ ---------------------------------------------------------------------- }
{ Primitives de dessin                                                      }
{ ---------------------------------------------------------------------- }

Var
 CullW, CullH: LongInt;

Procedure ThickLine(X1, Y1, X2, Y2, W, Col: LongInt);
Var
 I, O1, O2: LongInt;
Begin
 SetColor(Col);
 If W <= 1 Then Begin
  Line(C16(X1), C16(Y1), C16(X2), C16(Y2));
  Exit;
 End;
 O1 := -((W - 1) Div 2);
 O2 := W Div 2;
 If IAbs(X2 - X1) >= IAbs(Y2 - Y1) Then
  For I := O1 To O2 Do Line(C16(X1), C16(Y1 + I), C16(X2), C16(Y2 + I))
 Else
  For I := O1 To O2 Do Line(C16(X1 + I), C16(Y1), C16(X2 + I), C16(Y2));
End;

Procedure FillMultiply(X1, Y1, X2, Y2, Col: LongInt);
Var
 X, Y: LongInt;
Begin
 If X1 < 0 Then X1 := 0;
 If Y1 < 0 Then Y1 := 0;
 If X2 > CullW Then X2 := CullW;
 If Y2 > CullH Then Y2 := CullH;
 For Y := Y1 To Y2 Do Begin
  X := X1;
  While X <= X2 Do Begin
   If GetPixel(X, Y) = White Then Begin
    { Rechercher la fin du segment blanc }
    PutPixel(X, Y, Col);
   End;
   Inc(X);
  End;
 End;
End;

{ Police vectorielle : traits définis sur une grille de demi-unités
  (ligne de base 6, hauteur des minuscules 23, capitale 30). Les traits
  "lissés" sont arrondis par subdivision de Chaikin au démarrage. }
Const
 {$IFDEF FPC}
 VPOOLMAX = 24000;
 {$ELSE}
 VPOOLMAX = 9000;
 {$ENDIF}
 VSEP = -32768;

Type
 TVPt = Record
  X, Y: SmallInt;
 End;
 TVPool = Array[0..VPOOLMAX - 1] Of TVPt;
 PVPool = ^TVPool;
 TRPt = Record
  X, Y: Real;
 End;

Var
 VPool: PVPool;
 VCount: Integer;
 VStart: Array[0..255] Of Word;
 VLen: Array[0..255] Of Word;
 VW: Array[0..255] Of Byte;
 VCov: Array[0..159, 0..159] Of Byte;

Procedure VAddPoint(X, Y: Real);
Begin
 If VCount >= VPOOLMAX - 2 Then Exit;
 VPool^[VCount].X := Round(X * 16);
 VPool^[VCount].Y := Round(Y * 16);
 Inc(VCount);
End;

Procedure BuildVFont;
Var
 C, I, N, K, It, M: Integer;
 S: String;
 Smooth, Closed: Boolean;
 P, Q: Array[0..399] Of TRPt;
Begin
 GetMem(VPool, SizeOf(TVPool));
 VCount := 0;
 For C := 0 To 255 Do Begin VLen[C] := 0; VW[C] := 0; VStart[C] := 0; End;
 For C := VFirst To VLast Do Begin
  S := VFData[C];
  If S = '' Then Continue;
  VW[C] := Ord(S[1]) - 48;
  VStart[C] := VCount;
  I := 2;
  While I <= Length(S) Do Begin
   If S[I] = ' ' Then Begin
    Smooth := S[I + 1] = '~';
    Inc(I, 2);
    N := 0;
    While (I < Length(S)) And (S[I] <> ' ') And (N < 60) Do Begin
     P[N].X := (Ord(S[I]) - 48 - 12) / 2;
     P[N].Y := (Ord(S[I + 1]) - 48) / 2;
     Inc(N);
     Inc(I, 2);
    End;
    If Smooth And (N >= 3) Then Begin
     Closed := (P[0].X = P[N - 1].X) And (P[0].Y = P[N - 1].Y);
     For It := 1 To 2 Do Begin
      M := 0;
      If Not Closed Then Begin Q[M] := P[0]; Inc(M); End;
      For K := 0 To N - 2 Do Begin
       Q[M].X := 0.75 * P[K].X + 0.25 * P[K + 1].X; Q[M].Y := 0.75 * P[K].Y + 0.25 * P[K + 1].Y; Inc(M);
       Q[M].X := 0.25 * P[K].X + 0.75 * P[K + 1].X; Q[M].Y := 0.25 * P[K].Y + 0.75 * P[K + 1].Y; Inc(M);
      End;
      If Closed Then Begin Q[M] := Q[0]; Inc(M); End
      Else Begin Q[M] := P[N - 1]; Inc(M); End;
      For K := 0 To M - 1 Do P[K] := Q[K];
      N := M;
      If N > 90 Then Break;
     End;
    End;
    For K := 0 To N - 1 Do VAddPoint(P[K].X, P[K].Y);
    If VCount < VPOOLMAX Then Begin
     VPool^[VCount].X := VSEP;
     VPool^[VCount].Y := 0;
     Inc(VCount);
    End;
   End
   Else Inc(I);
  End;
  VLen[C] := VCount - VStart[C];
 End;
End;

{ Projection page -> écran en réels (sans arrondi) }
Procedure MapF(X, Y: Real; Var SX, SY: Real);
Var
 U, V: Real;
Begin
 Case GRot Of
  0: Begin U := X; V := Y; End;
  1: Begin U := GPH - Y; V := X; End;
  2: Begin U := GPW - X; V := GPH - Y; End;
 Else
  Begin U := Y; V := GPW - X; End;
 End;
 SX := GOX + U * GSc / 1024;
 SY := GOY + V * GSc / 1024;
End;

Function WinCode(C: Integer): Integer;
Begin
 WinCode := C;
 If (C < 32) Or (C > 255) Then WinCode := 63;
 If (C >= 127) And (C < 128) Then WinCode := 63;
End;

{ Trace un glyphe. Les points de dessin sont transformés par l'affine
  (écran = O + u*Ax + v*Ay), u et v en points. }
Procedure VGlyph(Code: Integer; CellU, Adv, Size: Real; OX, OY, AXx, AXy, AYx, AYy: Real;
                 Col: Integer; Bold, Ital: Boolean);
Const
 MAXP = 220;
Var
 Pt: Array[0..MAXP - 1] Of TRPt;
 Brk: Array[0..MAXP - 1] Of Boolean;
 N, I, K, W: Integer;
 U, V, DX, DY, X, Y: Real;
 MnX, MnY, MxX, MxY: Real;
 HW, D, T, L2, CX, CY, Cv, Sh: Real;
 BX0, BY0, BX1, BY1, PX, PY, YY, XX: Integer;
 SX0, SX1, SY0, SY1: Integer;
 Bg, Lvl: Integer;
 Ci: Integer;
 A, B: TRPt;
 DesignW: Real;
Begin
 If (Code < 0) Or (Code > 255) Then Exit;
 If VLen[Code] = 0 Then Exit;
 DesignW := VW[Code];
 If DesignW < 1 Then DesignW := 1;
 N := 0;
 For I := VStart[Code] To VStart[Code] + VLen[Code] - 1 Do Begin
  If VPool^[I].X = VSEP Then Begin
   If N > 0 Then Brk[N - 1] := True;
  End
  Else If N < MAXP Then Begin
   X := VPool^[I].X / 16;
   Y := VPool^[I].Y / 16;
   U := CellU + Adv * (0.07 + 0.86 * X / DesignW);
   V := Size * (0.8 - (Y - 6) * 0.03);
   If Ital Then U := U + (Size * 0.8 - V) * 0.2;
   Pt[N].X := OX + U * AXx + V * AYx;
   Pt[N].Y := OY + U * AXy + V * AYy;
   Brk[N] := False;
   Inc(N);
  End;
 End;
 If N < 1 Then Exit;
 HW := Size * Sqrt(AXx * AXx + AXy * AXy) * 0.05;
 If Bold Then HW := HW * 1.45;
 If HW < 0.42 Then HW := 0.42;
 MnX := Pt[0].X; MxX := MnX; MnY := Pt[0].Y; MxY := MnY;
 For I := 1 To N - 1 Do Begin
  If Pt[I].X < MnX Then MnX := Pt[I].X;
  If Pt[I].X > MxX Then MxX := Pt[I].X;
  If Pt[I].Y < MnY Then MnY := Pt[I].Y;
  If Pt[I].Y > MxY Then MxY := Pt[I].Y;
 End;
 BX0 := Trunc(MnX - HW - 1); BY0 := Trunc(MnY - HW - 1);
 BX1 := Trunc(MxX + HW + 1); BY1 := Trunc(MxY + HW + 1);
 If (BX1 < 0) Or (BY1 < 0) Or (BX0 > CullW) Or (BY0 > CullH) Then Exit;
 If (BX1 - BX0 >= 160) Or (BY1 - BY0 >= 160) Then Begin
  { très grand glyphe : traits épais directs }
  For I := 0 To N - 2 Do
   If Not Brk[I] Then
    ThickLine(Round(Pt[I].X), Round(Pt[I].Y), Round(Pt[I + 1].X), Round(Pt[I + 1].Y), IMax(1, Round(HW * 2)), Col);
  Exit;
 End;
 For I := 0 To N - 1 Do Begin
  A := Pt[I];
  If (I < N - 1) And (Not Brk[I]) Then B := Pt[I + 1] Else B := A;
  If (I < N - 1) And Brk[I] Then Continue;
  SX0 := Trunc(IMin(Trunc(A.X), Trunc(B.X)) - HW - 1) - BX0;
  SX1 := Trunc(IMax(Trunc(A.X + 1), Trunc(B.X + 1)) + HW + 1) - BX0;
  SY0 := Trunc(IMin(Trunc(A.Y), Trunc(B.Y)) - HW - 1) - BY0;
  SY1 := Trunc(IMax(Trunc(A.Y + 1), Trunc(B.Y + 1)) + HW + 1) - BY0;
  If SX0 < 0 Then SX0 := 0;
  If SY0 < 0 Then SY0 := 0;
  If SX1 > BX1 - BX0 Then SX1 := BX1 - BX0;
  If SY1 > BY1 - BY0 Then SY1 := BY1 - BY0;
  DX := B.X - A.X; DY := B.Y - A.Y;
  L2 := DX * DX + DY * DY;
  For PY := SY0 To SY1 Do
   For PX := SX0 To SX1 Do Begin
    CX := BX0 + PX + 0.5; CY := BY0 + PY + 0.5;
    If L2 < 0.0001 Then T := 0
    Else Begin
     T := ((CX - A.X) * DX + (CY - A.Y) * DY) / L2;
     If T < 0 Then T := 0 Else If T > 1 Then T := 1;
    End;
    X := CX - (A.X + T * DX);
    Y := CY - (A.Y + T * DY);
    D := Sqrt(X * X + Y * Y);
    Cv := HW + 0.5 - D;
    If Cv > 0 Then Begin
     If Cv > 1 Then Cv := 1;
     Ci := Round(Cv * 255);
     If Ci > VCov[PY, PX] Then VCov[PY, PX] := Ci;
    End;
   End;
 End;
 For PY := 0 To BY1 - BY0 Do
  For PX := 0 To BX1 - BX0 Do Begin
   Ci := VCov[PY, PX];
   If Ci = 0 Then Continue;
   VCov[PY, PX] := 0;
   XX := BX0 + PX; YY := BY0 + PY;
   If (XX < 0) Or (YY < 0) Or (XX > CullW) Or (YY > CullH) Then Continue;
   Cv := Ci / 255 * 1.25;
   If Cv >= 0.78 Then PutPixel(XX, YY, Col)
   Else If Cv >= 0.18 Then Begin
    Bg := GetPixel(XX, YY);
    If Bg = White Then Begin
     If Col = Black Then Begin
      If Cv >= 0.45 Then PutPixel(XX, YY, DarkGray) Else PutPixel(XX, YY, LightGray);
     End
     Else Begin
      If Cv >= 0.45 Then PutPixel(XX, YY, Col) Else PutPixel(XX, YY, LightGray);
     End;
    End
    Else If Cv >= 0.5 Then PutPixel(XX, YY, Col);
   End;
  End;
End;

{ ---- Texte à angle libre -------------------------------------------------
  Pour un K_TEXT : PN = angle en dixièmes de degré (sens anti-horaire),
  P0 = longueur de la ligne (points), Rgb2 = origine (coin supérieur gauche
  de la ligne dans son repère pivoté) emballée, utilisée si PN <> 0.
  X1..Y2 contiennent toujours la boîte englobante alignée sur les axes. }

Function TextLenOf(Const O: TObjRec): LongInt;
Begin
 If (O.Kind = K_TEXT) And (O.P0 > 0) Then TextLenOf := O.P0
 Else TextLenOf := IAbs(O.X2 - O.X1);
End;

Function TextLineH(Const O: TObjRec): LongInt;
Begin
 TextLineH := (LongInt(O.Size) * 6 + 4) Div 5;
End;

Function TextAng(Const O: TObjRec): Integer;
Begin
 If O.Kind = K_TEXT Then TextAng := O.PN Mod 3600 Else TextAng := 0;
End;

Procedure TextDirs(Tenths: Integer; Var Dx, Dy, Vx, Vy: Real);
Var
 A: Real;
Begin
 Tenths := ((Tenths Mod 3600) + 3600) Mod 3600;
 Case Tenths Of
  0: Begin Dx := 1; Dy := 0; End;
  900: Begin Dx := 0; Dy := -1; End;
  1800: Begin Dx := -1; Dy := 0; End;
  2700: Begin Dx := 0; Dy := 1; End;
 Else
  Begin
   A := Tenths * Pi / 1800;
   Dx := Cos(A); Dy := -Sin(A);
  End;
 End;
 { direction "vers le bas" du glyphe : perpendiculaire (rotation de 90° dans le repère page, y vers le bas) }
 Vx := -Dy; Vy := Dx;
End;

Procedure PackOrigin(Var O: TObjRec; Ox, Oy: LongInt);
Begin
 If Ox < -16384 Then Ox := -16384;
 If Ox > 16383 Then Ox := 16383;
 If Oy < -16384 Then Oy := -16384;
 If Oy > 16383 Then Oy := 16383;
 O.Rgb2 := (Ox + 16384) * 32768 + (Oy + 16384);
End;

Procedure TextOrigin(Const O: TObjRec; Var Ox, Oy: Real);
Begin
 If TextAng(O) = 0 Then Begin Ox := O.X1; Oy := O.Y1; End
 Else Begin
  Ox := (O.Rgb2 Div 32768) - 16384;
  Oy := (O.Rgb2 Mod 32768) - 16384;
 End;
End;

{ Coins de la ligne de texte (espace page) : 0 origine, 1 fin de ligne, 2 fin + bas, 3 bas }
Procedure TextCorners(Const O: TObjRec; Var CX, CY: Array Of Real);
Var
 Ox, Oy, Dx, Dy, Vx, Vy, L, H: Real;
Begin
 TextOrigin(O, Ox, Oy);
 TextDirs(TextAng(O), Dx, Dy, Vx, Vy);
 L := TextLenOf(O); H := TextLineH(O);
 CX[0] := Ox; CY[0] := Oy;
 CX[1] := Ox + L * Dx; CY[1] := Oy + L * Dy;
 CX[2] := CX[1] + H * Vx; CY[2] := CY[1] + H * Vy;
 CX[3] := Ox + H * Vx; CY[3] := Oy + H * Vy;
End;

{ Recalcule la boîte englobante d'un texte à partir de son origine }
Procedure SetTextBox(Var O: TObjRec; Ox, Oy: Real);
Var
 CX, CY: Array[0..3] Of Real;
 Dx, Dy, Vx, Vy, L, H: Real;
 I: Integer;
 MnX, MxX, MnY, MxY: Real;
Begin
 TextDirs(TextAng(O), Dx, Dy, Vx, Vy);
 L := TextLenOf(O); H := TextLineH(O);
 CX[0] := Ox; CY[0] := Oy;
 CX[1] := Ox + L * Dx; CY[1] := Oy + L * Dy;
 CX[2] := CX[1] + H * Vx; CY[2] := CY[1] + H * Vy;
 CX[3] := Ox + H * Vx; CY[3] := Oy + H * Vy;
 MnX := CX[0]; MxX := MnX; MnY := CY[0]; MxY := MnY;
 For I := 1 To 3 Do Begin
  If CX[I] < MnX Then MnX := CX[I];
  If CX[I] > MxX Then MxX := CX[I];
  If CY[I] < MnY Then MnY := CY[I];
  If CY[I] > MxY Then MxY := CY[I];
 End;
 O.X1 := C16(Round(MnX)); O.Y1 := C16(Round(MnY));
 O.X2 := C16(Round(MxX)); O.Y2 := C16(Round(MxY));
 If TextAng(O) = 0 Then Begin O.X1 := C16(Round(Ox)); O.Y1 := C16(Round(Oy)); O.X2 := C16(O.X1 + Round(L)); O.Y2 := C16(O.Y1 + Round(H)); End
 Else PackOrigin(O, Round(Ox), Round(Oy));
End;

{ Dessine une chaîne de document. (XPt, YPt) : coin supérieur gauche de la
  boîte du texte (en points), WPt : longueur imposée le long du texte,
  AngT : angle en dixièmes de degré (anti-horaire). }
Procedure DrawRun(Const S: String; XPt, YPt: Real; WPt: Real; Size, Fam, Style: Integer;
                  Rgb: LongInt; AngT: Integer);
Var
 I, N, C, Em, Col: Integer;
 Sum: LongInt;
 Ratio, Acc, Adv, H: Real;
 OX, OY, ODX, ODY, OAX, OAY, DxX, DxY, DyX, DyY: Real;
 PX0, PY0, PX1, PY1: Real;
 SX0, SY0, SX1, SY1: Real;
 Bold, Ital: Boolean;
Begin
 N := Length(S);
 If N = 0 Then Exit;
 Col := Nearest16(Rgb);
 Bold := (Style And 1) <> 0;
 Ital := (Style And 2) <> 0;
 Em := Round(Size * GSc / 1024.0);
 Sum := 0;
 For I := 1 To N Do Sum := Sum + CharW(Fam, Style, Ord(S[I]));
 If Sum = 0 Then Exit;
 If WPt < 1 Then WPt := Sum * Size / 1000.0;
 H := Size * 1.2;
 Ratio := WPt / (Sum * Size / 1000.0);
 TextDirs(AngT, DxX, DxY, DyX, DyY);
 PX0 := XPt; PY0 := YPt;
 MapF(PX0, PY0, OX, OY);
 MapF(PX0 + DxX, PY0 + DxY, SX0, SY0);
 MapF(PX0 + DyX, PY0 + DyY, SX1, SY1);
 OAX := SX0 - OX; OAY := SY0 - OY;
 ODX := SX1 - OX; ODY := SY1 - OY;
 If Em < 5 Then Begin
  { texte "grisé" : une barre le long de la ligne }
  MapF(PX0 + DyX * Size * 0.45, PY0 + DyY * Size * 0.45, SX0, SY0);
  MapF(PX0 + DyX * Size * 0.45 + DxX * WPt, PY0 + DyY * Size * 0.45 + DxY * WPt, SX1, SY1);
  If Col = 0 Then Col := DarkGray;
  If Em >= 2 Then ThickLine(Round(SX0), Round(SY0), Round(SX1), Round(SY1), 1, Col)
  Else If Col <> White Then Begin
   SetColor(Col);
   Line(C16(Round(SX0)), C16(Round(SY0)), C16(Round(SX1)), C16(Round(SY1)));
  End;
  Exit;
 End;
 Acc := 0;
 For I := 1 To N Do Begin
  C := WinCode(Ord(S[I]));
  If C = 160 Then C := 32;
  Adv := CharW(Fam, Style, Ord(S[I])) * Size / 1000.0 * Ratio;
  If C > 32 Then VGlyph(C, Acc, Adv, Size, OX, OY, OAX, OAY, ODX, ODY, Col, Bold, Ital);
  Acc := Acc + Adv;
 End;
End;

Procedure NormBox(Const O: TObjRec; Var X1, Y1, X2, Y2: LongInt);
Begin
 X1 := IMin(O.X1, O.X2); X2 := IMax(O.X1, O.X2);
 Y1 := IMin(O.Y1, O.Y2); Y2 := IMax(O.Y1, O.Y2);
End;

{ Boîte écran normalisée d'un objet }
Procedure ScrBox(Const O: TObjRec; Var SX1, SY1, SX2, SY2: LongInt);
Var
 A, B, C, D: LongInt;
Begin
 NormBox(O, A, B, C, D);
 SX1 := IMin(MXp(A, B), MXp(C, D)); SX2 := IMax(MXp(A, B), MXp(C, D));
 SY1 := IMin(MYp(A, B), MYp(C, D)); SY2 := IMax(MYp(A, B), MYp(C, D));
End;

Procedure DrawArrowHead(X1, Y1, X2, Y2, W, Col: LongInt);
Var
 DX, DY, L: Real;
 HL: Real;
 PX, PY: Real;
Begin
 DX := X2 - X1; DY := Y2 - Y1;
 L := Sqrt(DX * DX + DY * DY);
 If L < 1 Then Exit;
 DX := DX / L; DY := DY / L;
 HL := 5 + W * 2;
 PX := X2 - DX * HL; PY := Y2 - DY * HL;
 ThickLine(X2, Y2, Round(PX - DY * HL * 0.45), Round(PY + DX * HL * 0.45), W, Col);
 ThickLine(X2, Y2, Round(PX + DY * HL * 0.45), Round(PY - DX * HL * 0.45), W, Col);
End;

Type
 TPolyPts = Array[0..255] Of PointType;

Procedure DrawPolyObj(Const O: TObjRec; FillIt, Outline, Closed: Boolean; Col, FCol, W: LongInt);
Var
 Pts: TPolyPts;
 N, I, Step: Integer;
 Base: Integer;
 PX, PY: LongInt;
 LX, LY: LongInt;
Begin
 If (O.PN < 2) Or (PoolHead = Nil) Then Exit;
 Step := 1;
 If O.PN > 250 Then Step := (O.PN + 249) Div 250;
 N := 0;
 I := 0;
 While I < O.PN Do Begin
  Base := O.P0 + I;
  PX := MXp(PoolXP(Base)^, PoolYP(Base)^);
  PY := MYp(PoolXP(Base)^, PoolYP(Base)^);
  If N < 255 Then Begin
   Pts[N].X := C16(PX); Pts[N].Y := C16(PY);
   Inc(N);
  End;
  Inc(I, Step);
 End;
 If N < 2 Then Exit;
 If FillIt And (N >= 3) Then Begin
  SetFillStyle(SolidFill, FCol);
  SetColor(FCol);
  FillPoly(N, Pts);
 End;
 If Outline Then Begin
  For I := 0 To N - 2 Do
   ThickLine(Pts[I].X, Pts[I].Y, Pts[I + 1].X, Pts[I + 1].Y, W, Col);
  If Closed Then ThickLine(Pts[N - 1].X, Pts[N - 1].Y, Pts[0].X, Pts[0].Y, W, Col);
 End;
End;


Type
 TWordPix = Array[0..67108863] Of Word;
 PWordPix = ^TWordPix;
 TBytePix = Array[0..134217727] Of Byte;
 PBytePix = ^TBytePix;

Const
 Bayer4: Array[0..3, 0..3] Of Byte = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5));

Var
 DLut: Array[0..4095] Of Byte;
 DLutReady: Boolean;

Procedure InitDLut;
Var
 R, G, B: Integer;
Begin
 For R := 0 To 15 Do
  For G := 0 To 15 Do
   For B := 0 To 15 Do
    DLut[(R Shl 8) Or (G Shl 4) Or B] := Nearest16(RGBOf(R * 17, G * 17, B * 17));
 DLutReady := True;
End;

Function ImageDrawable(I: Integer): Boolean;
Begin
 ImageDrawable := (I > 0) And (I <= ImgCount) And ((ImgP(I)^.Pix <> Nil) Or (ImgP(I)^.Mask And (ImgP(I)^.Alpha <> Nil)));
End;

{ Dessine l'image réduite dans le rectangle écran (X1,Y1)-(X2,Y2) avec
  tramage ordonné vers les 16 couleurs. }
Procedure DrawImageData(Const O: TObjRec; X1, Y1, X2, Y2: LongInt);
Var
 I, DW, DH, X, Y, XA, XB, YA, YB, SX, SY, U, V, IW_, IH_, R, G, B, Off: LongInt;
 PU_, PV_, BW, BH: LongInt;
 Pw: PWordPix;
 Al: PBytePix;
 HF, VF: Boolean;
 MaskCol: Integer;
 Vv: Word;
Begin
 If Not DLutReady Then InitDLut;
 I := O.P0;
 DW := X2 - X1 + 1;
 DH := Y2 - Y1 + 1;
 If (DW < 1) Or (DH < 1) Then Exit;
 IW_ := ImgP(I)^.W; IH_ := ImgP(I)^.H;
 Pw := PWordPix(ImgP(I)^.Pix);
 Al := PBytePix(ImgP(I)^.Alpha);
 HF := (O.Style And 1) <> 0;
 VF := (O.Style And 2) <> 0;
 MaskCol := Nearest16(O.Rgb);
 XA := IMax(X1, 0); XB := IMin(X2, CullW);
 YA := IMax(Y1, 0); YB := IMin(Y2, CullH);
 For Y := YA To YB Do
  For X := XA To XB Do Begin
   U := X - X1; V := Y - Y1;
   { coordonnées dans l'espace page (compensation de la rotation de la page) }
   Case GRot Of
    0: Begin PU_ := U; PV_ := V; BW := DW; BH := DH; End;
    1: Begin PU_ := V; PV_ := DW - 1 - U; BW := DH; BH := DW; End;
    2: Begin PU_ := DW - 1 - U; PV_ := DH - 1 - V; BW := DW; BH := DH; End;
   Else
    Begin PU_ := DH - 1 - V; PV_ := U; BW := DH; BH := DW; End;
   End;
   If (O.Style And 4) = 0 Then Begin
    SX := (PU_ * IW_) Div BW; SY := (PV_ * IH_) Div BH;
   End
   Else Begin
    SX := (PV_ * IW_) Div BH; SY := (PU_ * IH_) Div BW;
   End;
   If HF Then SX := IW_ - 1 - SX;
   If VF Then SY := IH_ - 1 - SY;
   If SX < 0 Then SX := 0;
   If SX >= IW_ Then SX := IW_ - 1;
   If SY < 0 Then SY := 0;
   If SY >= IH_ Then SY := IH_ - 1;
   If Al <> Nil Then If Al^[SY * IW_ + SX] < 128 Then Continue;
   If Pw = Nil Then PutPixel(X, Y, MaskCol)
   Else Begin
    Vv := Pw^[SY * IW_ + SX];
    R := ((Vv Shr 11) And 31) * 255 Div 31;
    G := ((Vv Shr 5) And 63) * 255 Div 63;
    B := (Vv And 31) * 255 Div 31;
    Off := Bayer4[Y And 3, X And 3] * 5 - 38;
    R := R + Off; G := G + Off; B := B + Off;
    If R < 0 Then R := 0; If R > 255 Then R := 255;
    If G < 0 Then G := 0; If G > 255 Then G := 255;
    If B < 0 Then B := 0; If B > 255 Then B := 255;
    PutPixel(X, Y, DLut[((R Shr 4) Shl 8) Or ((G Shr 4) Shl 4) Or (B Shr 4)]);
   End;
  End;
End;

Procedure DrawObj(Const O: TObjRec; Pass: Integer);
Var
 SX1, SY1, SX2, SY2: LongInt;
 Col, FCol: Integer;
 W: LongInt;
 CX, CY, RX, RY, I: LongInt;
 NX1, NY1, NX2, NY2: LongInt;
 Sz: Integer;
 TW_: Real;
 TOx, TOy: Real;
Begin
 ScrBox(O, SX1, SY1, SX2, SY2);
 If (SX2 < -4) Or (SY2 < -4) Or (SX1 > CullW + 4) Or (SY1 > CullH + 4) Then Exit;
 Col := Nearest16(O.Rgb);
 FCol := Nearest16(O.Rgb2);
 W := (LongInt(O.Wd) * GSc) Div 1024;
 If W < 1 Then W := 1;
 If Pass = 1 Then Begin
  Case O.Kind Of
   K_TEXT:
    begin
     TextOrigin(O, TOx, TOy);
     DrawRun(O.Txt, TOx, TOy, TextLenOf(O), O.Size, O.Style Shr 2, O.Style And 3, O.Rgb, TextAng(O));
    end;
   K_LINE, K_ARROW: Begin
    ThickLine(MXp(O.X1, O.Y1), MYp(O.X1, O.Y1), MXp(O.X2, O.Y2), MYp(O.X2, O.Y2), W, Col);
    If O.Kind = K_ARROW Then
     DrawArrowHead(MXp(O.X1, O.Y1), MYp(O.X1, O.Y1), MXp(O.X2, O.Y2), MYp(O.X2, O.Y2), W, Col);
   End;
   K_RECT: Begin
    If O.Fill <> 0 Then Begin
     SetFillStyle(SolidFill, FCol);
     If (SX2 - SX1 < 1) Then SX2 := SX1;
     If (SY2 - SY1 < 1) Then SY2 := SY1;
     Bar(C16(SX1), C16(SY1), C16(SX2), C16(SY2));
    End;
    If O.Fill <> 1 Then Begin
     ThickLine(SX1, SY1, SX2, SY1, W, Col);
     ThickLine(SX2, SY1, SX2, SY2, W, Col);
     ThickLine(SX2, SY2, SX1, SY2, W, Col);
     ThickLine(SX1, SY2, SX1, SY1, W, Col);
    End;
   End;
   K_OVAL: Begin
    CX := (SX1 + SX2) Div 2; CY := (SY1 + SY2) Div 2;
    RX := (SX2 - SX1) Div 2; RY := (SY2 - SY1) Div 2;
    If (RX > 0) And (RY > 0) And (RX < 2000) And (RY < 2000) Then Begin
     If O.Fill <> 0 Then Begin
      SetFillStyle(SolidFill, FCol);
      SetColor(FCol);
      FillEllipse(C16(CX), C16(CY), C16(RX), C16(RY));
     End;
     If O.Fill <> 1 Then Begin
      SetColor(Col);
      For I := 0 To W - 1 Do
       If (RX - I > 0) And (RY - I > 0) Then
        Ellipse(C16(CX), C16(CY), 0, 360, C16(RX - I), C16(RY - I));
     End;
    End;
   End;
   K_POLY:
    DrawPolyObj(O, O.Fill <> 0, O.Fill <> 1, (O.Style And 1) <> 0, Col, FCol, W);
   K_INK:
    DrawPolyObj(O, False, True, False, Col, FCol, W);
   K_IMAGE: If ImageDrawable(O.P0) Then DrawImageData(O, SX1, SY1, SX2, SY2)
   Else Begin
    SetFillStyle(SolidFill, LightGray);
    Bar(C16(SX1), C16(SY1), C16(SX2), C16(SY2));
    SetColor(DarkGray);
    Rectangle(C16(SX1), C16(SY1), C16(SX2), C16(SY2));
    If SX2 - SX1 > 12 Then Begin
     Line(C16(SX1), C16(SY1), C16(SX2), C16(SY2));
     Line(C16(SX1), C16(SY2), C16(SX2), C16(SY1));
    End;
   End;
   K_STAMP: Begin
    ThickLine(SX1, SY1, SX2, SY1, W + 1, Col);
    ThickLine(SX2, SY1, SX2, SY2, W + 1, Col);
    ThickLine(SX2, SY2, SX1, SY2, W + 1, Col);
    ThickLine(SX1, SY2, SX1, SY1, W + 1, Col);
    DrawRun(O.Txt, IMin(O.X1, O.X2) + 6, IMin(O.Y1, O.Y2) + 4, IAbs(O.X2 - O.X1) - 12, O.Size, 0, 1, O.Rgb, 0);
   End;
  End;
 End
 Else If Pass = 2 Then Begin
  If O.Kind = K_HILITE Then FillMultiply(SX1, SY1, SX2, SY2, Col);
 End
 Else If Pass = 3 Then Begin
  Case O.Kind Of
   K_UNDER: ThickLine(SX1, SY2, SX2, SY2, IMax(1, W Div 2), Col);
   K_STRIKE: ThickLine(SX1, (SY1 + SY2) Div 2, SX2, (SY1 + SY2) Div 2, IMax(1, W Div 2), Col);
   K_NOTE: Begin
    SetFillStyle(SolidFill, Yellow);
    Bar(C16(SX1), C16(SY1), C16(SX2), C16(SY2));
    SetColor(Black);
    Rectangle(C16(SX1), C16(SY1), C16(SX2), C16(SY2));
    If SX2 - SX1 > 8 Then Begin
     Line(C16(SX1 + 3), C16(SY1 + 4), C16(SX2 - 3), C16(SY1 + 4));
     Line(C16(SX1 + 3), C16(SY1 + 7), C16(SX2 - 3), C16(SY1 + 7));
     Line(C16(SX1 + 3), C16(SY1 + 10), C16(SX2 - 6), C16(SY1 + 10));
    End;
   End;
   K_REDACT: Begin
    SetColor(LightRed);
    Rectangle(C16(SX1), C16(SY1), C16(SX2), C16(SY2));
    Rectangle(C16(SX1 + 1), C16(SY1 + 1), C16(SX2 - 1), C16(SY2 - 1));
    If SX2 - SX1 > 20 Then DS(C16(SX1 + 3), C16(SY1 + 3), 'REDACT');
   End;
  End;
 End;
End;

{ Coins d'un objet dans l'espace page : 1=(X1,Y1) 2=(X2,Y1) 3=(X1,Y2) 4=(X2,Y2) }
Procedure CornerOf(Const O: TObjRec; K: Integer; Var X, Y: LongInt);
Var
 A, B, C, D: LongInt;
Begin
 NormBox(O, A, B, C, D);
 If (K = 1) Or (K = 3) Then X := A Else X := C;
 If (K = 1) Or (K = 2) Then Y := B Else Y := D;
End;

Function IsBoxKind(K: Integer): Boolean;
Begin
 IsBoxKind := K In [K_RECT, K_OVAL, K_IMAGE, K_REDACT, K_HILITE, K_STAMP, K_UNDER, K_STRIKE];
End;

Procedure DrawTextBoxRot(Const O: TObjRec);
Var
 CX, CY: Array[0..3] Of Real;
 I, J: Integer;
Begin
 TextCorners(O, CX, CY);
 SetLineStyle(DashedLn, 0, 1);
 For I := 0 To 3 Do Begin
  J := (I + 1) And 3;
  Line(C16(MXr(CX[I], CY[I])), C16(MYr(CX[I], CY[I])), C16(MXr(CX[J], CY[J])), C16(MYr(CX[J], CY[J])));
 End;
 SetLineStyle(SolidLn, 0, 1);
End;

Procedure DrawSelectionBox(Const O: TObjRec);
Var
 SX1, SY1, SX2, SY2, PX, PY, CX, CY: LongInt;
 I: Integer;
Begin
 SetFillStyle(SolidFill, LightBlue);
 SetColor(Blue);
 If (O.Kind = K_TEXT) And (TextAng(O) <> 0) Then Begin
  DrawTextBoxRot(O);
  Exit;
 End;
 If O.Kind In [K_LINE, K_ARROW] Then Begin
  For I := 1 To 2 Do Begin
   If I = 1 Then Begin CX := O.X1; CY := O.Y1; End Else Begin CX := O.X2; CY := O.Y2; End;
   PX := MXp(CX, CY); PY := MYp(CX, CY);
   Bar(C16(PX - 3), C16(PY - 3), C16(PX + 3), C16(PY + 3));
   Rectangle(C16(PX - 3), C16(PY - 3), C16(PX + 3), C16(PY + 3));
  End;
  Exit;
 End;
 ScrBox(O, SX1, SY1, SX2, SY2);
 SetLineStyle(DashedLn, 0, 1);
 Rectangle(C16(SX1 - 2), C16(SY1 - 2), C16(SX2 + 2), C16(SY2 + 2));
 SetLineStyle(SolidLn, 0, 1);
 If IsBoxKind(O.Kind) Then
  For I := 1 To 4 Do Begin
   CornerOf(O, I, CX, CY);
   PX := MXp(CX, CY); PY := MYp(CX, CY);
   Bar(C16(PX - 3), C16(PY - 3), C16(PX + 3), C16(PY + 3));
   Rectangle(C16(PX - 3), C16(PY - 3), C16(PX + 3), C16(PY + 3));
  End;
End;

{ Dessine une page complète. OX, OY : coin supérieur gauche (coordonnées
  de la fenêtre graphique courante). }
Procedure RenderPage(Pg: Integer; OX, OY, Sc: LongInt; Full: Boolean);
Var
 DW, DH, I: LongInt;
 SX1, SY1, SX2, SY2: LongInt;
Begin
 SetCtx(Pg, OX, OY, Sc);
 DW := DispWOf(Pg, Sc);
 DH := DispHOf(Pg, Sc);
 If Full Then Begin
  SetFillStyle(SolidFill, Black);
  Bar(C16(OX + 3), C16(OY + 3), C16(OX + DW + 3), C16(OY + DH + 3));
 End;
 SetFillStyle(SolidFill, White);
 Bar(C16(OX), C16(OY), C16(OX + DW), C16(OY + DH));
 SetColor(Black);
 Rectangle(C16(OX), C16(OY), C16(OX + DW), C16(OY + DH));
 For I := 1 To 3 Do Begin
  For SX1 := 0 To ObjCount - 1 Do
   If ObjP(SX1)^.Page = Pg Then DrawObj(ObjP(SX1)^, I);
 End;
 If Full Then Begin
  If (FindObj >= 0) And (FindObj < ObjCount) Then
   If ObjP(FindObj)^.Page = Pg Then Begin
    ScrBox(ObjP(FindObj)^, SX1, SY1, SX2, SY2);
    SetColor(LightRed);
    Rectangle(C16(SX1 - 2), C16(SY1 - 2), C16(SX2 + 2), C16(SY2 + 2));
    Rectangle(C16(SX1 - 3), C16(SY1 - 3), C16(SX2 + 3), C16(SY2 + 3));
   End;
  If (SelObj >= 0) And (SelObj < ObjCount) Then
   If ObjP(SelObj)^.Page = Pg Then DrawSelectionBox(ObjP(SelObj)^);
 End;
End;

{ ---------------------------------------------------------------------- }
{ Gestion du document                                                       }
{ ---------------------------------------------------------------------- }

Procedure AllocDoc;
Begin
 ObjHead := Nil; ObjCurBlk := Nil; ObjBlocks := 0; ObjCount := 0;
 PgHead := Nil; PgCurBlk := Nil; PgBlocks := 0; PageCount := 0;
 PoolHead := Nil; PoolCurBlk := Nil; PoolBlocks := 0; PoolCount := 0;
 ImgHead := Nil; ImgCurBlk := Nil; ImgBlocks := 0; ImgCount := 0;
 ObjEnsure(0);
 PgEnsure(1);
 PoolEnsure(1);
End;

Procedure FreeUndoRec(Var U: TUndoRec);
Begin
 If U.Objs <> Nil Then FreeMem(U.Objs, U.Cnt * SizeOf(TObjRec));
 If U.Pgs <> Nil Then FreeMem(U.Pgs, U.PgCnt * SizeOf(TPageRec));
 U.Objs := Nil;
 U.Pgs := Nil;
 U.Cnt := 0;
 U.PgCnt := 0;
 U.Mem := 0;
End;

Procedure ClearUndo;
Var
 I: Integer;
Begin
 For I := 0 To UndoTop - 1 Do FreeUndoRec(UndoStack[I]);
 For I := 0 To RedoTop - 1 Do FreeUndoRec(RedoStack[I]);
 UndoTop := 0;
 RedoTop := 0;
End;

Procedure ClearRedo;
Var
 I: Integer;
Begin
 For I := 0 To RedoTop - 1 Do FreeUndoRec(RedoStack[I]);
 RedoTop := 0;
End;

Procedure MakeSnap(Var U: TUndoRec);
Var
 I: LongInt;
Begin
 U.Cnt := ObjCount;
 U.PgCnt := PageCount;
 U.Cur := CurPage;
 U.Objs := Nil;
 U.Pgs := Nil;
 U.Mem := 0;
 If ObjCount > 0 Then Begin
  GetMem(U.Objs, ObjCount * SizeOf(TObjRec));
  For I := 0 To ObjCount - 1 Do Move(ObjP(I)^, Pointer(PtrUInt(U.Objs) + PtrUInt(I) * SizeOf(TObjRec))^, SizeOf(TObjRec));
  U.Mem := ObjCount * SizeOf(TObjRec);
 End;
 If PageCount > 0 Then Begin
  GetMem(U.Pgs, PageCount * SizeOf(TPageRec));
  For I := 1 To PageCount Do Move(PgP(I)^, Pointer(PtrUInt(U.Pgs) + PtrUInt(I - 1) * SizeOf(TPageRec))^, SizeOf(TPageRec));
 End;
End;

Function UndoMemory: LongInt;
Var
 I: Integer;
 T: LongInt;
Begin
 T := 0;
 For I := 0 To UndoTop - 1 Do T := T + UndoStack[I].Mem;
 For I := 0 To RedoTop - 1 Do T := T + RedoStack[I].Mem;
 UndoMemory := T;
End;

{ À appeler avant toute modification du document }
Procedure PushUndo;
Var
 I: Integer;
Begin
 ClearRedo;
 While (UndoTop >= UNDO_MAX) Or ((UndoTop > 0) And (UndoMemory > UNDO_MEM)) Do Begin
  FreeUndoRec(UndoStack[0]);
  For I := 1 To UndoTop - 1 Do UndoStack[I - 1] := UndoStack[I];
  Dec(UndoTop);
 End;
 MakeSnap(UndoStack[UndoTop]);
 Inc(UndoTop);
 Modified := True;
End;

Procedure ApplySnap(Var U: TUndoRec);
Var
 I: LongInt;
Begin
 ObjCount := U.Cnt;
 PageCount := U.PgCnt;
 For I := 0 To U.Cnt - 1 Do Begin
  ObjEnsure(I);
  Move(Pointer(PtrUInt(U.Objs) + PtrUInt(I) * SizeOf(TObjRec))^, ObjP(I)^, SizeOf(TObjRec));
 End;
 PgEnsure(U.PgCnt);
 For I := 1 To U.PgCnt Do Move(Pointer(PtrUInt(U.Pgs) + PtrUInt(I - 1) * SizeOf(TPageRec))^, PgP(I)^, SizeOf(TPageRec));
 CurPage := U.Cur;
 If CurPage > PageCount Then CurPage := PageCount;
 If CurPage < 1 Then CurPage := 1;
 SelObj := -1;
 FindObj := -1;
End;

Function CanUndo: Boolean;
Begin
 CanUndo := UndoTop > 0;
End;

Function CanRedo: Boolean;
Begin
 CanRedo := RedoTop > 0;
End;

Procedure DoUndo;
Begin
 If UndoTop = 0 Then Exit;
 If RedoTop < UNDO_MAX Then Begin
  MakeSnap(RedoStack[RedoTop]);
  Inc(RedoTop);
 End;
 Dec(UndoTop);
 ApplySnap(UndoStack[UndoTop]);
 FreeUndoRec(UndoStack[UndoTop]);
 Modified := True;
End;

Procedure DoRedo;
Begin
 If RedoTop = 0 Then Exit;
 MakeSnap(UndoStack[UndoTop]);
 Inc(UndoTop);
 Dec(RedoTop);
 ApplySnap(RedoStack[RedoTop]);
 FreeUndoRec(RedoStack[RedoTop]);
 Modified := True;
End;

Procedure InitObj(Var O: TObjRec; Kind, Pg: Integer);
Begin
 FillChar(O, SizeOf(O), 0);
 O.Kind := Kind;
 O.Page := Pg;
 O.Wd := 1;
 O.Size := 12;
 O.Rgb := 0;
 O.Rgb2 := $FFFFFF;
End;

{ Somme de contrôle d'un objet (détection des modifications depuis l'import) }
Function ObjSum(Idx: LongInt): LongInt;
Var
 T: TObjRec;
 P: PByteBuf;
 A, B: LongInt;
 I, N: LongInt;
 Procedure Add(V: LongInt);
 Begin
  A := (A + (V And 255) + 1) Mod 65521; B := (B + A) Mod 65521;
  A := (A + ((V Shr 8) And 255)) Mod 65521; B := (B + A) Mod 65521;
 End;
Begin
 T := ObjP(Idx)^;
 T.Sum := 0;
 P := PByteBuf(@T);
 A := 1; B := 0;
 For I := 0 To SizeOf(TObjRec) - 1 Do Begin
  A := (A + P^[I]) Mod 65521;
  B := (B + A) Mod 65521;
 End;
 If T.Kind In [K_POLY, K_INK] Then
  For I := 0 To T.PN - 1 Do Begin
   Add(PoolXP(T.P0 + I)^);
   Add(PoolYP(T.P0 + I)^);
  End;
 ObjSum := (B Mod 32749) * 65536 + A;
End;

Function NewObj(Kind, Pg: Integer): Integer;
Begin
 If Not ObjEnsure(ObjCount) Then Begin
  NewObj := -1;
  Exit;
 End;
 InitObj(ObjP(ObjCount)^, Kind, Pg);
 NewObj := ObjCount;
 Inc(ObjCount);
End;

Procedure DelObj(I: LongInt);
Var
 J: LongInt;
Begin
 If (I < 0) Or (I >= ObjCount) Then Exit;
 For J := I To ObjCount - 2 Do ObjP(J)^ := ObjP(J + 1)^;
 Dec(ObjCount);
 If SelObj = I Then SelObj := -1 Else If SelObj > I Then Dec(SelObj);
 If FindObj = I Then FindObj := -1 Else If FindObj > I Then Dec(FindObj);
End;

Function PoolAlloc(N: Integer): Integer;
Begin
 If Not PoolEnsure(PoolCount + N) Then PoolAlloc := -1
 Else Begin
  PoolAlloc := PoolCount;
  Inc(PoolCount, N);
 End;
End;

Procedure RecalcBox(Idx: Integer);
Var
 I: Integer;
 Len: LongInt;
 Ox, Oy: Real;
 MnX, MnY, MxX, MxY: Integer;
 O: ^TObjRec;
Begin
 O := @ObjP(Idx)^;
 If O^.Kind = K_TEXT Then Begin
  Len := TextLenPts(O^.Txt, O^.Size, O^.Style Shr 2, O^.Style And 3);
  If Len < 1 Then Len := O^.Size Div 2 + 1;
  O^.P0 := Len;
  TextOrigin(O^, Ox, Oy);
  SetTextBox(O^, Ox, Oy);
 End
 Else If (O^.Kind In [K_POLY, K_INK]) And (O^.PN > 0) Then Begin
  MnX := 32000; MnY := 32000; MxX := -32000; MxY := -32000;
  For I := O^.P0 To O^.P0 + O^.PN - 1 Do Begin
   If PoolXP(I)^ < MnX Then MnX := PoolXP(I)^;
   If PoolXP(I)^ > MxX Then MxX := PoolXP(I)^;
   If PoolYP(I)^ < MnY Then MnY := PoolYP(I)^;
   If PoolYP(I)^ > MxY Then MxY := PoolYP(I)^;
  End;
  O^.X1 := MnX; O^.Y1 := MnY; O^.X2 := MxX; O^.Y2 := MxY;
 End
 Else If O^.Kind = K_NOTE Then Begin
  O^.X2 := O^.X1 + 16;
  O^.Y2 := O^.Y1 + 16;
 End;
End;

Procedure MoveObj(Idx: Integer; DX, DY: LongInt);
Var
 I: Integer;
Begin
 With ObjP(Idx)^ Do Begin
  X1 := X1 + DX; X2 := X2 + DX;
  Y1 := Y1 + DY; Y2 := Y2 + DY;
  If (Kind = K_TEXT) And (PN Mod 3600 <> 0) Then PackOrigin(ObjP(Idx)^, (Rgb2 Div 32768) - 16384 + DX, (Rgb2 Mod 32768) - 16384 + DY);
  If Kind In [K_POLY, K_INK] Then
   For I := P0 To P0 + PN - 1 Do Begin
    PoolXP(I)^ := PoolXP(I)^ + DX;
    PoolYP(I)^ := PoolYP(I)^ + DY;
   End;
 End;
End;

{ Change l'angle d'un texte en le faisant pivoter autour du centre de sa ligne }
Procedure SetTextAngle(Idx: Integer; Tenths: Integer);
Var
 Ox, Oy, Dx, Dy, Vx, Vy, L, H, Cx, Cy: Real;
Begin
 With ObjP(Idx)^ Do Begin
  TextOrigin(ObjP(Idx)^, Ox, Oy);
  TextDirs(TextAng(ObjP(Idx)^), Dx, Dy, Vx, Vy);
  L := TextLenOf(ObjP(Idx)^); H := TextLineH(ObjP(Idx)^);
  Cx := Ox + (L * Dx + H * Vx) / 2;
  Cy := Oy + (L * Dy + H * Vy) / 2;
  PN := ((Tenths Mod 3600) + 3600) Mod 3600;
  TextDirs(PN, Dx, Dy, Vx, Vy);
  Ox := Cx - (L * Dx + H * Vx) / 2;
  Oy := Cy - (L * Dy + H * Vy) / 2;
 End;
 SetTextBox(ObjP(Idx)^, Ox, Oy);
End;

{ Redimensionne un polygone / une encre vers une nouvelle boîte }
Procedure ScaleObjTo(Idx: Integer; NX1, NY1, NX2, NY2: LongInt);
Var
 I: Integer;
 OX1, OY1, OW, OH, NW, NH: LongInt;
Begin
 With ObjP(Idx)^ Do Begin
  If Kind In [K_POLY, K_INK] Then Begin
   OX1 := X1; OY1 := Y1;
   OW := IMax(1, X2 - X1); OH := IMax(1, Y2 - Y1);
   NW := NX2 - NX1; NH := NY2 - NY1;
   For I := P0 To P0 + PN - 1 Do Begin
    PoolXP(I)^ := NX1 + ((PoolXP(I)^ - OX1) * NW) Div OW;
    PoolYP(I)^ := NY1 + ((PoolYP(I)^ - OY1) * NH) Div OH;
   End;
  End;
  X1 := NX1; Y1 := NY1; X2 := NX2; Y2 := NY2;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Pages                                                                     }
{ ---------------------------------------------------------------------- }

Procedure InsertPageAt(After, W, H: Integer);
Var
 I: Integer;
Begin
 If Not PgEnsure(PageCount + 1) Then Exit;
 For I := 0 To ObjCount - 1 Do
  If ObjP(I)^.Page > After Then Inc(ObjP(I)^.Page);
 For I := PageCount DownTo After + 1 Do PgP(I + 1)^ := PgP(I)^;
 Inc(PageCount);
 FillChar(PgP(After + 1)^, SizeOf(TPageRec), 0);
 PgP(After + 1)^.W := W;
 PgP(After + 1)^.H := H;
 PgP(After + 1)^.Rot := 0;
 PgP(After + 1)^.Top := 0;
End;

Procedure DeletePageAt(P: Integer);
Var
 I, J: Integer;
Begin
 If PageCount <= 1 Then Exit;
 J := 0;
 For I := 0 To ObjCount - 1 Do Begin
  If ObjP(I)^.Page <> P Then Begin
   If ObjP(I)^.Page > P Then Dec(ObjP(I)^.Page);
   If I <> J Then ObjP(J)^ := ObjP(I)^;
   Inc(J);
  End;
 End;
 ObjCount := J;
 For I := P To PageCount - 1 Do PgP(I)^ := PgP(I + 1)^;
 Dec(PageCount);
 If CurPage > PageCount Then CurPage := PageCount;
 SelObj := -1;
 FindObj := -1;
End;

Procedure DupPageAt(P: Integer);
Var
 I, N, J: Integer;
Begin
 InsertPageAt(P, PgP(P)^.W, PgP(P)^.H);
 PgP(P + 1)^.Rot := PgP(P)^.Rot;
 N := ObjCount;
 For I := 0 To N - 1 Do
  If ObjP(I)^.Page = P Then Begin
   J := NewObj(1, P + 1);
   If J < 0 Then Break;
   ObjP(J)^ := ObjP(I)^;
   ObjP(J)^.Page := P + 1;
  End;
End;

Procedure SwapPages(A, B: Integer);
Var
 T: TPageRec;
 I: Integer;
Begin
 T := PgP(A)^; PgP(A)^ := PgP(B)^; PgP(B)^ := T;
 For I := 0 To ObjCount - 1 Do
  If ObjP(I)^.Page = A Then ObjP(I)^.Page := B
  Else If ObjP(I)^.Page = B Then ObjP(I)^.Page := A;
End;

Procedure FreeImages; Forward;

Procedure NewDocument;
Begin
 FreeImages;
 ObjsFree; PgsFree; PoolFree;
 ObjEnsure(0); PgEnsure(1); PoolEnsure(1);
 ObjCount := 0;
 PoolCount := 0;
 PageCount := 1;
 CurPage := 1;
 FillChar(PgP(1)^, SizeOf(TPageRec), 0);
 PgP(1)^.W := 612; PgP(1)^.H := 792; PgP(1)^.Rot := 0;
 SelObj := -1; FindObj := -1;
 DocName := '';
 SrcValid := False; InfoDirty := False; NeedFullRewrite := False; SrcFile := '';
 DocTitle := ''; DocAuthor := ''; DocSubject := ''; DocKeywords := ''; DocCreator := '';
 Modified := False;
 DocEncrypted := False;
 ScrollX := 0; ScrollY := 0;
 ClearUndo;
End;

{ ---------------------------------------------------------------------- }
{ Sélection d'objets                                                        }
{ ---------------------------------------------------------------------- }

Function DistSeg(PX, PY, AX, AY, BX, BY: Real): Real;
Var
 DX, DY, T, L2, CX, CY: Real;
Begin
 DX := BX - AX; DY := BY - AY;
 L2 := DX * DX + DY * DY;
 If L2 < 0.0001 Then T := 0
 Else T := ((PX - AX) * DX + (PY - AY) * DY) / L2;
 If T < 0 Then T := 0;
 If T > 1 Then T := 1;
 CX := AX + T * DX; CY := AY + T * DY;
 DistSeg := Sqrt((PX - CX) * (PX - CX) + (PY - CY) * (PY - CY));
End;

Function HitObj(Pg: Integer; X, Y: LongInt; Tol: Real): Integer;
Var
 I, J: Integer;
 NX1, NY1, NX2, NY2: LongInt;
 Hit: Boolean;
 CX, CY, RX, RY, V, DTmp: Real;
 O: ^TObjRec;
Begin
 HitObj := -1;
 For I := ObjCount - 1 DownTo 0 Do Begin
  O := @ObjP(I)^;
  If O^.Page <> Pg Then Continue;
  NormBox(O^, NX1, NY1, NX2, NY2);
  Hit := False;
  Case O^.Kind Of
   K_TEXT: Begin
    If TextAng(O^) = 0 Then
     Hit := (X >= NX1 - Tol) And (X <= NX2 + Tol) And (Y >= NY1 - Tol) And (Y <= NY2 + Tol)
    Else Begin
     TextOrigin(O^, CX, CY);
     TextDirs(TextAng(O^), RX, RY, V, DTmp);
     { (RX,RY) direction du texte ; (-RY,RX) vers le bas du glyphe }
     DTmp := (X - CX) * RX + (Y - CY) * RY;
     V := (X - CX) * (-RY) + (Y - CY) * RX;
     Hit := (DTmp >= -Tol) And (DTmp <= TextLenOf(O^) + Tol) And (V >= -Tol) And (V <= TextLineH(O^) + Tol);
    End;
   End;
   K_LINE, K_ARROW:
    Hit := DistSeg(X, Y, O^.X1, O^.Y1, O^.X2, O^.Y2) <= Tol + O^.Wd / 2;
   K_RECT:
    If (X >= NX1 - Tol) And (X <= NX2 + Tol) And (Y >= NY1 - Tol) And (Y <= NY2 + Tol) Then Begin
     If O^.Fill <> 0 Then Hit := True
     Else Hit := (X <= NX1 + Tol) Or (X >= NX2 - Tol) Or (Y <= NY1 + Tol) Or (Y >= NY2 - Tol);
    End;
   K_OVAL: Begin
    CX := (NX1 + NX2) / 2; CY := (NY1 + NY2) / 2;
    RX := (NX2 - NX1) / 2 + Tol; RY := (NY2 - NY1) / 2 + Tol;
    If (RX > 0) And (RY > 0) Then Begin
     V := (X - CX) * (X - CX) / (RX * RX) + (Y - CY) * (Y - CY) / (RY * RY);
     If O^.Fill <> 0 Then Hit := V <= 1
     Else Begin
      RX := RX - 2 * Tol; RY := RY - 2 * Tol;
      If (RX <= 0) Or (RY <= 0) Then Hit := V <= 1
      Else Hit := (V <= 1) And ((X - CX) * (X - CX) / (RX * RX) + (Y - CY) * (Y - CY) / (RY * RY) >= 1);
     End;
    End;
   End;
   K_POLY, K_INK: Begin
    If (X >= NX1 - Tol) And (X <= NX2 + Tol) And (Y >= NY1 - Tol) And (Y <= NY2 + Tol) Then Begin
     For J := O^.P0 To O^.P0 + O^.PN - 2 Do
      If DistSeg(X, Y, PoolXP(J)^, PoolYP(J)^, PoolXP(J + 1)^, PoolYP(J + 1)^) <= Tol + O^.Wd / 2 Then Hit := True;
     If (O^.Kind = K_POLY) And (O^.Fill <> 0) Then Hit := True;
    End;
   End;
  Else
   Hit := (X >= NX1 - Tol) And (X <= NX2 + Tol) And (Y >= NY1 - Tol) And (Y <= NY2 + Tol);
  End;
  If Hit Then Begin
   HitObj := I;
   Exit;
  End;
 End;
End;

{ Poignée sous le pointeur (coordonnées écran, contexte de page courant) }
Function HandleAt(Idx: Integer; SX, SY: LongInt): Integer;
Var
 K: Integer;
 CX, CY, PX, PY: LongInt;
Begin
 HandleAt := 0;
 If (Idx < 0) Or (Idx >= ObjCount) Then Exit;
 With ObjP(Idx)^ Do Begin
  If Kind In [K_LINE, K_ARROW] Then Begin
   If (IAbs(SX - MXp(X1, Y1)) <= 5) And (IAbs(SY - MYp(X1, Y1)) <= 5) Then HandleAt := 5
   Else If (IAbs(SX - MXp(X2, Y2)) <= 5) And (IAbs(SY - MYp(X2, Y2)) <= 5) Then HandleAt := 6;
   Exit;
  End;
  If Not IsBoxKind(Kind) Then Exit;
  For K := 1 To 4 Do Begin
   CornerOf(ObjP(Idx)^, K, CX, CY);
   PX := MXp(CX, CY); PY := MYp(CX, CY);
   If (IAbs(SX - PX) <= 5) And (IAbs(SY - PY) <= 5) Then Begin
    HandleAt := K;
    Exit;
   End;
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Écriture PDF                                                              }
{ ---------------------------------------------------------------------- }

Var
 OutF: File;
 OutPos: LongInt;
 OutErr: Boolean;
 XOfs: Array[0..1] Of LongInt;
 XRef: PXArr;

Var
 CapOn: Boolean;
 CapBuf: PByteBuf;
 CapLen, CapSize: LongInt;

{ Écriture dans un tampon (pour compresser un flux avant de l'écrire) }
Procedure CapAppend(Const S: String);
Var
 P: Pointer;
Begin
 If CapLen + Length(S) + 16 > CapSize Then Begin
  CapSize := CapSize * 2 + Length(S) + 4096;
  P := CapBuf;
  ReAllocMem(P, CapSize);
  CapBuf := P;
 End;
 If Length(S) > 0 Then Move(S[1], CapBuf^[CapLen], Length(S));
 CapLen := CapLen + Length(S);
End;

Procedure WS(Const S: String);
Begin
 If CapOn Then Begin CapAppend(S); Exit; End;
 If OutErr Or (Length(S) = 0) Then Exit;
 {$I-}
 BlockWrite(OutF, S[1], Length(S));
 {$I+}
 If IOResult <> 0 Then OutErr := True;
 OutPos := OutPos + Length(S);
End;

Procedure WL(Const S: String);
Begin
 WS(S + #10);
End;

Function PdfStr(Const S: String): String;
Var
 I: Integer;
 R: String;
 C: Integer;
Begin
 R := '(';
 For I := 1 To Length(S) Do Begin
  C := Ord(S[I]);
  If (C = 40) Or (C = 41) Or (C = 92) Then R := R + '\' + S[I]
  Else If (C < 32) Or (C > 126) Then Begin
   R := R + '\' + Chr(48 + (C Shr 6)) + Chr(48 + ((C Shr 3) And 7)) + Chr(48 + (C And 7));
  End
  Else R := R + S[I];
  If Length(R) > 240 Then Break;
 End;
 PdfStr := R + ')';
End;

Function ColStr(Rgb: LongInt): String;
Begin
 ColStr := RStr(((Rgb Shr 16) And 255) / 255) + ' ' + RStr(((Rgb Shr 8) And 255) / 255) + ' ' +
           RStr((Rgb And 255) / 255);
End;

{ ---------------------------------------------------------------------- }
{ Compression Flate (zlib) : LZ77 + codes de Huffman fixes                  }
{ ---------------------------------------------------------------------- }

{$IFDEF FPC}
Var
 DfOut: PByteBuf;
 DfPos: LongInt;
 DfBitBuf: LongWord;
 DfBitCnt: Integer;

Procedure DfPutBits(V: LongWord; N: Integer);
Begin
 DfBitBuf := DfBitBuf Or (V Shl DfBitCnt);
 Inc(DfBitCnt, N);
 While DfBitCnt >= 8 Do Begin
  DfOut^[DfPos] := DfBitBuf And 255;
  Inc(DfPos);
  DfBitBuf := DfBitBuf Shr 8;
  Dec(DfBitCnt, 8);
 End;
End;

Procedure DfPutCode(Code: LongWord; N: Integer);
Var
 R: LongWord;
 I: Integer;
Begin
 R := 0;
 For I := 1 To N Do Begin
  R := (R Shl 1) Or (Code And 1);
  Code := Code Shr 1;
 End;
 DfPutBits(R, N);
End;

Procedure DfLit(Sym: Integer);
Begin
 If Sym < 144 Then DfPutCode($30 + Sym, 8)
 Else If Sym < 256 Then DfPutCode($190 + Sym - 144, 9)
 Else If Sym < 280 Then DfPutCode(Sym - 256, 7)
 Else DfPutCode($C0 + Sym - 280, 8);
End;

{ Compresse Src (SLen octets) ; Dst est alloué ici (à libérer avec FreeMem). }
Function DeflateBuf(Src: PByteBuf; SLen: LongInt; Var Dst: PByteBuf; Var DLen: LongInt): Boolean;
Var
 Head: Array[0..32767] Of LongInt;
 Prev: Array[0..32767] Of LongInt;
 Pos, I, K, Best, BestD, Cand, Tries, L, MaxL, Lim: LongInt;
 A, B: LongWord;
 H: LongInt;
 Cap: LongInt;
 Function Hash3(P: LongInt): LongInt;
 Begin
  Hash3 := ((Src^[P] Shl 10) Xor (Src^[P + 1] Shl 5) Xor Src^[P + 2]) And 32767;
 End;
 Procedure Insert(P: LongInt);
 Var
  HH: LongInt;
 Begin
  If P + 2 < SLen Then Begin
   HH := Hash3(P);
   Prev[P And 32767] := Head[HH];
   Head[HH] := P;
  End;
 End;
Begin
 DeflateBuf := False;
 Dst := Nil; DLen := 0;
 If SLen < 1 Then Exit;
 Cap := SLen + SLen Div 6 + 128;
 GetMem(Dst, Cap);
 If Dst = Nil Then Exit;
 DfOut := Dst; DfPos := 0; DfBitBuf := 0; DfBitCnt := 0;
 DfOut^[0] := $78; DfOut^[1] := $9C; DfPos := 2;
 FillChar(Head, SizeOf(Head), $FF);
 FillChar(Prev, SizeOf(Prev), $FF);
 DfPutBits(1, 1);      { BFINAL }
 DfPutBits(1, 2);      { BTYPE = 01 : Huffman fixe }
 Pos := 0;
 While Pos < SLen Do Begin
  Best := 0; BestD := 0;
  If Pos + 2 < SLen Then Begin
   H := Hash3(Pos);
   Cand := Head[H];
   Tries := 0;
   MaxL := SLen - Pos;
   If MaxL > 258 Then MaxL := 258;
   While (Cand >= 0) And (Pos - Cand <= 32768) And (Tries < 28) Do Begin
    If Src^[Cand + Best] = Src^[Pos + Best] Then Begin
     L := 0;
     While (L < MaxL) And (Src^[Cand + L] = Src^[Pos + L]) Do Inc(L);
     If L > Best Then Begin Best := L; BestD := Pos - Cand; If L >= MaxL Then Break; End;
    End;
    I := Prev[Cand And 32767];
    If (I >= Cand) Then Break;
    Cand := I;
    Inc(Tries);
   End;
  End;
  If Best >= 3 Then Begin
   K := 28;
   While LBase[K] > Best Do Dec(K);
   DfLit(257 + K);
   If LExtra[K] > 0 Then DfPutBits(Best - LBase[K], LExtra[K]);
   K := 29;
   While DBase[K] > BestD Do Dec(K);
   DfPutCode(K, 5);
   If DExtra[K] > 0 Then DfPutBits(BestD - DBase[K], DExtra[K]);
   For I := 0 To Best - 1 Do Insert(Pos + I);
   Inc(Pos, Best);
  End
  Else Begin
   DfLit(Src^[Pos]);
   Insert(Pos);
   Inc(Pos);
  End;
  If DfPos > Cap - 64 Then Begin FreeMem(Dst, Cap); Dst := Nil; Exit; End;
 End;
 DfLit(256);
 If DfBitCnt > 0 Then DfPutBits(0, 8 - DfBitCnt);
 A := 1; B := 0;
 For I := 0 To SLen - 1 Do Begin
  A := (A + Src^[I]) Mod 65521;
  B := (B + A) Mod 65521;
 End;
 DfOut^[DfPos] := (B Shr 8) And 255; Inc(DfPos);
 DfOut^[DfPos] := B And 255; Inc(DfPos);
 DfOut^[DfPos] := (A Shr 8) And 255; Inc(DfPos);
 DfOut^[DfPos] := A And 255; Inc(DfPos);
 DLen := DfPos;
 DeflateBuf := True;
End;
{$ENDIF}

Procedure WriteBytes(P: PByteBuf; N: LongInt);
Var
 K, L16: LongInt;
Begin
 K := 0;
 While (K < N) And (Not OutErr) Do Begin
  If N - K > 16384 Then L16 := 16384 Else L16 := N - K;
  {$I-}
  BlockWrite(OutF, P^[K], L16);
  {$I+}
  If IOResult <> 0 Then OutErr := True;
  OutPos := OutPos + L16;
  Inc(K, L16);
 End;
End;

Var
 IncMode: Boolean;
 XList: PLArr;
 XCnt, XCap: LongInt;

Procedure IncAdd(N, Ofs: LongInt);
Var
 P: Pointer;
Begin
 If XCnt + 2 > XCap Then Begin
  XCap := XCap * 2 + 1024;
  P := XList; ReAllocMem(P, XCap * 2 * SizeOf(LongInt)); XList := P;
 End;
 XList^[XCnt * 2] := N; XList^[XCnt * 2 + 1] := Ofs;
 Inc(XCnt);
End;

Procedure BeginObj(N: Integer);
Begin
 If IncMode Then IncAdd(N, OutPos) Else XRef^[N] := OutPos;
 WL(IStr(N) + ' 0 obj');
End;

Procedure EndObj;
Begin
 WL('endobj');
End;

Function PY_(Pg: Integer; Y: LongInt): String;
Begin
 PY_ := RStr(PgP(Pg)^.H - Y);
End;

Function PdfDate: String;
Var
 Y, M, D, DW, H, Mi, S, S1: Word;
Begin
 GetDate(Y, M, D, DW);
 GetTime(H, Mi, S, S1);
 PdfDate := 'D:' + IStr(Y) + Pad2(M) + Pad2(D) + Pad2(H) + Pad2(Mi) + Pad2(S);
End;

Function ImgKept(I: Integer): Boolean;
Begin
 ImgKept := (I > 0) And (I <= ImgCount) And ImgP(I)^.Keep And (ImgP(I)^.Raw <> Nil);
End;

Var
 CMode: Integer;           { 0 tout, 1 nouveautés avant l'original, 2 nouveautés après }
 CFirstOrig: LongInt;
 CDrop: PLArr;
 CDropN: LongInt;
 FPre, IPre: String[4];

Function InDrop(N: LongInt): Boolean;
Var
 K: LongInt;
Begin
 InDrop := False;
 For K := 0 To CDropN - 1 Do If CDrop^[K] = N Then Begin InDrop := True; Exit; End;
End;

{ Cet objet est-il écrit dans le flux de contenu selon le mode courant ? }
Function ObjEmits(Const O: TObjRec; I: LongInt): Boolean;
Begin
 ObjEmits := False;
 If O.Src = 3 Then Exit;
 Case CMode Of
  0: If (O.Src = 2) And (Not InDrop(O.SrcNum)) Then Exit;
  1: If (Not ((O.Src = 0) Or ((O.Src = 2) And InDrop(O.SrcNum)))) Or (I >= CFirstOrig) Then Exit;
  2: If (Not ((O.Src = 0) Or ((O.Src = 2) And InDrop(O.SrcNum)))) Or (I < CFirstOrig) Then Exit;
 End;
 ObjEmits := True;
End;

Procedure ContentOf(Pg: Integer; Var Cnt: LongInt);
Var
 I, J: Integer;
 H: LongInt;
 O: ^TObjRec;
 S: String;
 X1, Y1, X2, Y2: LongInt;
 Nat, Tz: Real;
 K: Real;
 TX, TY, TOx, TOy, TDx, TDy, TVx, TVy: Real;
 BW_, BH_, Sg0, Sg1, Ex, Ey_, Fx, Fy, AX, AY: LongInt;
 Mt: String[40];
 CX, CY, RX, RY: Real;
 Op: String;
Begin
 H := PgP(Pg)^.H;
 For I := 0 To ObjCount - 1 Do Begin
  O := @ObjP(I)^;
  If O^.Page <> Pg Then Continue;
  If Not ObjEmits(O^, I) Then Continue;
  NormBox(O^, X1, Y1, X2, Y2);
  If (O^.Kind = K_IMAGE) And ImgKept(O^.P0) Then Begin
   S := 'q ';
   If ImgP(O^.P0)^.Mask Then S := S + ColStr(O^.Rgb) + ' rg ';
   BW_ := X2 - X1; BH_ := Y2 - Y1;
   If (O^.Style And 1) <> 0 Then Sg0 := -1 Else Sg0 := 1;
   If (O^.Style And 2) <> 0 Then Sg1 := -1 Else Sg1 := 1;
   If (O^.Style And 4) = 0 Then Begin
    Ex := Sg0 * BW_; Ey_ := 0; Fx := 0; Fy := Sg1 * BH_;
   End
   Else Begin
    Ex := 0; Ey_ := Sg0 * BH_; Fx := Sg1 * BW_; Fy := 0;
   End;
   { coin supérieur gauche de l'image dans la page }
   AX := X1; AY := Y1;
   If (Ex < 0) Or (Fx < 0) Then AX := X2;
   If (Ey_ < 0) Or (Fy < 0) Then AY := Y2;
   S := S + IStr(Ex) + ' ' + IStr(-Ey_) + ' ' + IStr(-Fx) + ' ' + IStr(Fy) + ' ' +
        IStr(AX + Fx) + ' ' + IStr(H - (AY + Fy));
   WL(S + ' cm /' + IPre + IStr(O^.P0) + ' Do Q');
   Continue;
  End;
  Case O^.Kind Of
   K_TEXT: Begin
    If O^.Txt = '' Then Continue;
    Nat := TextLenPts(O^.Txt, O^.Size, O^.Style Shr 2, O^.Style And 3);
    Tz := 100;
    If Nat > 0 Then Tz := TextLenOf(O^) * 100.0 / Nat;
    If (Tz < 60) Or (Tz > 160) Then Tz := 100;
    If Abs(Tz - 100) < 3 Then Tz := 100;
       TextOrigin(O^, TOx, TOy);
    TextDirs(TextAng(O^), TDx, TDy, TVx, TVy);
    TX := TOx + TVx * O^.Size * 4 / 5;
    TY := TOy + TVy * O^.Size * 4 / 5;
    Mt := RStr4(TDx) + ' ' + RStr4(-TDy) + ' ' + RStr4(TDy) + ' ' + RStr4(TDx);
    WL('q BT /' + FPre + IStr((O^.Style Shr 2) * 4 + (O^.Style And 3) + 1) + ' ' + IStr(O^.Size) + ' Tf ' +
       ColStr(O^.Rgb) + ' rg ' + RStr(Tz) + ' Tz ' + Mt + ' ' + RStr(TX) + ' ' +
       RStr(H - TY) + ' Tm ' + PdfStr(O^.Txt) + ' Tj ET Q');
   End;
   K_LINE, K_ARROW: Begin
    WL('q ' + ColStr(O^.Rgb) + ' RG ' + IStr(O^.Wd) + ' w 1 J ' + IStr(O^.X1) + ' ' + PY_(Pg, O^.Y1) + ' m ' +
       IStr(O^.X2) + ' ' + PY_(Pg, O^.Y2) + ' l S Q');
    If O^.Kind = K_ARROW Then Begin
     CX := O^.X2 - O^.X1; CY := O^.Y2 - O^.Y1;
     RX := Sqrt(CX * CX + CY * CY);
     If RX > 1 Then Begin
      CX := CX / RX; CY := CY / RX;
      K := 6 + O^.Wd * 2;
      WL('q ' + ColStr(O^.Rgb) + ' RG ' + IStr(O^.Wd) + ' w ' +
         RStr(O^.X2 - CX * K + CY * K * 0.45) + ' ' + RStr(H - (O^.Y2 - CY * K - CX * K * 0.45)) + ' m ' +
         IStr(O^.X2) + ' ' + PY_(Pg, O^.Y2) + ' l ' +
         RStr(O^.X2 - CX * K - CY * K * 0.45) + ' ' + RStr(H - (O^.Y2 - CY * K + CX * K * 0.45)) + ' l S Q');
     End;
    End;
   End;
   K_RECT, K_REDACT, K_IMAGE, K_STAMP: Begin
    S := 'q ';
    If O^.Kind = K_IMAGE Then S := S + '0.8 g 0.4 G 1 w '
    Else If O^.Kind = K_REDACT Then S := S + '1 0 0 RG 1.5 w '
    Else Begin
     S := S + ColStr(O^.Rgb2) + ' rg ' + ColStr(O^.Rgb) + ' RG ' + IStr(O^.Wd) + ' w ';
     If O^.Kind = K_STAMP Then S := S + '2 w ';
    End;
    S := S + IStr(X1) + ' ' + RStr(H - Y2) + ' ' + IStr(X2 - X1) + ' ' + IStr(Y2 - Y1) + ' re ';
    If O^.Kind = K_IMAGE Then S := S + 'B Q'
    Else If O^.Kind = K_REDACT Then S := S + 'S Q'
    Else If O^.Kind = K_STAMP Then S := S + 'S Q'
    Else Case O^.Fill Of
     0: S := S + 'S Q';
     1: S := S + 'f Q';
    Else S := S + 'B Q';
    End;
    WL(S);
    If O^.Kind = K_STAMP Then
     WL('q BT /' + FPre + '2 ' + IStr(O^.Size) + ' Tf ' + ColStr(O^.Rgb) + ' rg 1 0 0 1 ' + IStr(X1 + 6) + ' ' +
        RStr(H - Y1 - 4 - O^.Size * 4 / 5) + ' Tm ' + PdfStr(O^.Txt) + ' Tj ET Q');
   End;
   K_OVAL: Begin
    CX := (X1 + X2) / 2; CY := H - (Y1 + Y2) / 2;
    RX := (X2 - X1) / 2; RY := (Y2 - Y1) / 2;
    S := 'q ' + ColStr(O^.Rgb2) + ' rg ' + ColStr(O^.Rgb) + ' RG ' + IStr(O^.Wd) + ' w ' +
         RStr(CX + RX) + ' ' + RStr(CY) + ' m ' +
         RStr(CX + RX) + ' ' + RStr(CY + RY * 0.5523) + ' ' + RStr(CX + RX * 0.5523) + ' ' + RStr(CY + RY) + ' ' + RStr(CX) + ' ' + RStr(CY + RY) + ' c ' +
         RStr(CX - RX * 0.5523) + ' ' + RStr(CY + RY) + ' ' + RStr(CX - RX) + ' ' + RStr(CY + RY * 0.5523) + ' ' + RStr(CX - RX) + ' ' + RStr(CY) + ' c ';
    WS(S);
    S := RStr(CX - RX) + ' ' + RStr(CY - RY * 0.5523) + ' ' + RStr(CX - RX * 0.5523) + ' ' + RStr(CY - RY) + ' ' + RStr(CX) + ' ' + RStr(CY - RY) + ' c ' +
         RStr(CX + RX * 0.5523) + ' ' + RStr(CY - RY) + ' ' + RStr(CX + RX) + ' ' + RStr(CY - RY * 0.5523) + ' ' + RStr(CX + RX) + ' ' + RStr(CY) + ' c h ';
    Case O^.Fill Of
     0: S := S + 'S Q';
     1: S := S + 'f Q';
    Else S := S + 'B Q';
    End;
    WL(S);
   End;
   K_POLY, K_INK: Begin
    If O^.PN < 2 Then Continue;
    WS('q ' + ColStr(O^.Rgb2) + ' rg ' + ColStr(O^.Rgb) + ' RG ' + IStr(O^.Wd) + ' w 1 J 1 j ');
    For J := 0 To O^.PN - 1 Do Begin
     If J = 0 Then Op := ' m ' Else Op := ' l ';
     WS(IStr(PoolXP(O^.P0 + J)^) + ' ' + IStr(H - PoolYP(O^.P0 + J)^) + Op);
     If (J Mod 8) = 7 Then WL('');
    End;
    If O^.Kind = K_INK Then WL('S Q')
    Else Begin
     If (O^.Style And 1) <> 0 Then WS('h ');
     Case O^.Fill Of
      0: WL('S Q');
      1: WL('f Q');
     Else WL('B Q');
     End;
    End;
   End;
  End;
 End;
End;

Function AnnotOf(Pg, I: Integer): String;
Var
 O: ^TObjRec;
 X1, Y1, X2, Y2, H: LongInt;
 S, Sub: String;
 YT, YB: String;
Begin
 O := @ObjP(I)^;
 H := PgP(Pg)^.H;
 NormBox(O^, X1, Y1, X2, Y2);
 YT := IStr(H - Y1);
 YB := IStr(H - Y2);
 Case O^.Kind Of
  K_HILITE: Sub := 'Highlight';
  K_UNDER: Sub := 'Underline';
  K_STRIKE: Sub := 'StrikeOut';
 Else Sub := 'Text';
 End;
 S := '<< /Type /Annot /Subtype /' + Sub + ' /Rect [' + IStr(X1) + ' ' + YB + ' ' + IStr(X2) + ' ' + YT + '] /F 4 /C [' +
      ColStr(O^.Rgb) + ']';
 If O^.Kind In [K_HILITE, K_UNDER, K_STRIKE] Then
  S := S + ' /QuadPoints [' + IStr(X1) + ' ' + YT + ' ' + IStr(X2) + ' ' + YT + ' ' + IStr(X1) + ' ' + YB + ' ' + IStr(X2) + ' ' + YB + ']'
 Else S := S + ' /Name /Note /Open false';
 If DocAuthor <> '' Then S := S + ' /T ' + PdfStr(DocAuthor);
 If O^.Txt <> '' Then S := S + ' /Contents ' + PdfStr(O^.Txt);
 AnnotOf := S + ' >>';
End;

Function IsAnnot(K: Integer): Boolean;
Begin
 IsAnnot := K In [K_HILITE, K_UNDER, K_STRIKE, K_NOTE];
End;

{ Écrit le XObject image Idx sous le numéro No (SMNo : masque doux ou 0) }
Procedure WriteImageXObj(Idx, No, SMNo: LongInt);
Var
 S, Hx: String;
 K, J2: LongInt;
Begin
 With ImgP(Idx)^ Do Begin
   BeginObj(No);
   S := '<< /Type /XObject /Subtype /Image /Width ' + IStr(OW) + ' /Height ' + IStr(OH);
   If Mask Then S := S + ' /ImageMask true /BitsPerComponent 1'
   Else Begin
    Case CS Of
     1: S := S + ' /ColorSpace /DeviceGray';
     3: S := S + ' /ColorSpace /DeviceRGB';
     4: S := S + ' /ColorSpace /DeviceCMYK';
    End;
    If CS = 5 Then Begin
     S := S + ' /ColorSpace [/Indexed ';
     Case PalBase Of
      1: S := S + '/DeviceGray ';
      4: S := S + '/DeviceCMYK ';
     Else S := S + '/DeviceRGB ';
     End;
     S := S + IStr(PalN Div PalBase - 1) + ' <';
     WS(S);
     S := '';
     For K := 0 To PalN - 1 Do Begin
      Hx := '0123456789ABCDEF';
      S := S + Hx[(PByteBuf(Pal)^[K] Shr 4) + 1] + Hx[(PByteBuf(Pal)^[K] And 15) + 1];
      If Length(S) > 200 Then Begin WS(S); S := ''; End;
     End;
     S := S + '>]';
    End;
    S := S + ' /BitsPerComponent ' + IStr(BPC);
   End;
   If Decode <> '' Then S := S + ' /Decode [' + Decode + ']';
   If NF > 0 Then Begin
    S := S + ' /Filter [';
    For K := 0 To NF - 1 Do S := S + '/' + Flt[K] + ' ';
    S := S + ']';
    S := S + ' /DecodeParms [';
    For K := 0 To NF - 1 Do
     If (Flt[K] = 'FlateDecode') And (Pred > 1) Then
      S := S + '<< /Predictor ' + IStr(Pred) + ' /Columns ' + IStr(Cols) + ' /Colors ' + IStr(Clr) + ' /BitsPerComponent ' + IStr(BPC) + ' >> '
     Else S := S + 'null ';
    S := S + ']';
   End;
   If SMNo > 0 Then S := S + ' /SMask ' + IStr(SMNo) + ' 0 R';
   WL(S + ' /Length ' + IStr(RawLen) + ' >>');
   WL('stream');
   J2 := 0;
   While (J2 < RawLen) And (Not OutErr) Do Begin
    K := RawLen - J2;
    If K > 16384 Then K := 16384;
    {$I-}
    BlockWrite(OutF, PByteBuf(Raw)^[J2], K);
    {$I+}
    If IOResult <> 0 Then OutErr := True;
    OutPos := OutPos + K;
    Inc(J2, K);
   End;
   WL('');
   WL('endstream');
   EndObj;
  End;
End;

Const
 FontNames: Array[0..11] Of String[24] = ('Helvetica', 'Helvetica-Bold', 'Helvetica-Oblique',
  'Helvetica-BoldOblique', 'Times-Roman', 'Times-Bold', 'Times-Italic', 'Times-BoldItalic',
  'Courier', 'Courier-Bold', 'Courier-Oblique', 'Courier-BoldOblique');

Procedure WriteFontObjs(Base: Integer);
Var
 I: Integer;
Begin
 For I := 0 To 11 Do Begin
  BeginObj(Base + I);
  WL('<< /Type /Font /Subtype /Type1 /BaseFont /' + FontNames[I] + ' /Encoding /WinAnsiEncoding >>');
  EndObj;
 End;
End;

Function SaveAsPDF(Const FileName: String): Boolean;
Var
 I, J, Pg, NObj, FirstPage, AnnBase, AnnNext, NAnn: Integer;
 StartLen, Cnt: LongInt;
 S: String;
 XStart: LongInt;
 PagesOff: Integer;
 HasAnn: Boolean;
 ImgNo: PLArr;
 Used: Array[0..19] Of Integer;
 NUsed: Integer;
 K, J2: LongInt;
 Hx: String;
 Comp: PByteBuf;
 CompLen: LongInt;
Begin
 SaveAsPDF := False;
 OutErr := False;
 OutPos := 0;
 IncMode := False; CMode := 0; CDropN := 0; FPre := 'F'; IPre := 'Im';
 NAnn := 0;
 For I := 0 To ObjCount - 1 Do If IsAnnot(ObjP(I)^.Kind) Then Inc(NAnn);
 FirstPage := 16;
 AnnBase := FirstPage + PageCount * 3;
 NObj := AnnBase + NAnn;
 GetMem(ImgNo, (ImgCount + 2) * SizeOf(LongInt));
 FillChar(ImgNo^, (ImgCount + 2) * SizeOf(LongInt), 0);
 FillChar(Used, SizeOf(Used), 0);
 For I := 0 To ObjCount - 1 Do
  If (ObjP(I)^.Kind = K_IMAGE) And ImgKept(ObjP(I)^.P0) Then Begin
   ImgNo^[ObjP(I)^.P0] := 1;
   If ImgP(ObjP(I)^.P0)^.SMIdx > 0 Then ImgNo^[ImgP(ObjP(I)^.P0)^.SMIdx] := 1;
  End;
 For I := 1 To ImgCount Do
  If ImgNo^[I] <> 0 Then Begin ImgNo^[I] := NObj; Inc(NObj); End;
 GetMem(XRef, (NObj + 2) * SizeOf(LongInt));
 FillChar(XRef^, (NObj + 2) * SizeOf(LongInt), 0);
 {$I-}
 Assign(OutF, FileName);
 Rewrite(OutF, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  FreeMem(XRef, (NObj + 2) * SizeOf(LongInt));
  FreeMem(ImgNo, (ImgCount + 2) * SizeOf(LongInt));
  Exit;
 End;
 WL('%PDF-1.4');
 WL('%' + #226#227#207#211);
 BeginObj(1);
 WL('<< /Type /Catalog /Pages 2 0 R >>');
 EndObj;
 BeginObj(2);
 S := '<< /Type /Pages /Count ' + IStr(PageCount) + ' /Kids [';
 WS(S);
 For Pg := 1 To PageCount Do WS(IStr(FirstPage + (Pg - 1) * 3) + ' 0 R ');
 WL('] >>');
 EndObj;
 BeginObj(3);
 S := '<< /Producer (CloneDRAW ACROBAT) /CreationDate (' + PdfDate + ')';
 If DocTitle <> '' Then S := S + ' /Title ' + PdfStr(DocTitle);
 If DocAuthor <> '' Then S := S + ' /Author ' + PdfStr(DocAuthor);
 If DocSubject <> '' Then S := S + ' /Subject ' + PdfStr(DocSubject);
 If DocKeywords <> '' Then S := S + ' /Keywords ' + PdfStr(DocKeywords);
 If DocCreator <> '' Then S := S + ' /Creator ' + PdfStr(DocCreator);
 WL(S + ' >>');
 EndObj;
 WriteFontObjs(4);
 AnnNext := AnnBase;
 For Pg := 1 To PageCount Do Begin
  BeginObj(FirstPage + (Pg - 1) * 3);
  S := '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' + IStr(PgP(Pg)^.W) + ' ' + IStr(PgP(Pg)^.H) + ']';
  If PgP(Pg)^.Rot <> 0 Then S := S + ' /Rotate ' + IStr((PgP(Pg)^.Rot And 3) * 90);
  S := S + ' /Resources << /Font <<';
  For I := 0 To 11 Do S := S + ' /F' + IStr(I + 1) + ' ' + IStr(4 + I) + ' 0 R';
  S := S + ' >>';
  NUsed := 0;
  For I := 0 To ObjCount - 1 Do
   If (ObjP(I)^.Page = Pg) And (ObjP(I)^.Kind = K_IMAGE) And ImgKept(ObjP(I)^.P0) And (NUsed < 20) Then Begin
    K := 0;
    For J2 := 0 To NUsed - 1 Do If Used[J2] = ObjP(I)^.P0 Then K := 1;
    If K = 0 Then Begin Used[NUsed] := ObjP(I)^.P0; Inc(NUsed); End;
   End;
  If NUsed > 0 Then Begin
   WS(S);
   S := ' /XObject <<';
   For J2 := 0 To NUsed - 1 Do Begin
    S := S + ' /Im' + IStr(Used[J2]) + ' ' + IStr(ImgNo^[Used[J2]]) + ' 0 R';
    If Length(S) > 200 Then Begin WS(S); S := ''; End;
   End;
   S := S + ' >>';
  End;
  S := S + ' >> /Contents ' + IStr(FirstPage + (Pg - 1) * 3 + 1) + ' 0 R';
  WS(S);
  HasAnn := False;
  For I := 0 To ObjCount - 1 Do
   If (ObjP(I)^.Page = Pg) And IsAnnot(ObjP(I)^.Kind) Then Begin
    If Not HasAnn Then Begin WS(' /Annots ['); HasAnn := True; End;
    WS(IStr(AnnNext) + ' 0 R ');
    Inc(AnnNext);
   End;
  If HasAnn Then WS(']');
  WL(' >>');
  EndObj;
  BeginObj(FirstPage + (Pg - 1) * 3 + 1);
  { le contenu est d'abord mis en tampon pour être compressé }
  CapLen := 0;
  If CapBuf = Nil Then Begin CapSize := 65536; GetMem(CapBuf, CapSize); End;
  CapOn := True;
  Cnt := 0;
  ContentOf(Pg, Cnt);
  CapOn := False;
  Comp := Nil; CompLen := 0;
  {$IFDEF FPC}
  If CapLen > 64 Then
   If DeflateBuf(CapBuf, CapLen, Comp, CompLen) Then
    If CompLen >= CapLen Then Begin FreeMem(Comp, CapLen + CapLen Div 6 + 128); Comp := Nil; End;
  {$ENDIF}
  If Comp <> Nil Then Begin
   WL('<< /Length ' + IStr(FirstPage + (Pg - 1) * 3 + 2) + ' 0 R /Filter /FlateDecode >>');
   WL('stream');
   WriteBytes(Comp, CompLen);
   Cnt := CompLen;
   FreeMem(Comp, CapLen + CapLen Div 6 + 128);
  End
  Else Begin
   WL('<< /Length ' + IStr(FirstPage + (Pg - 1) * 3 + 2) + ' 0 R >>');
   WL('stream');
   WriteBytes(CapBuf, CapLen);
   Cnt := CapLen;
  End;
  WL('');
  WL('endstream');
  EndObj;
  BeginObj(FirstPage + (Pg - 1) * 3 + 2);
  WL(IStr(Cnt));
  EndObj;
 End;
 AnnNext := AnnBase;
 For Pg := 1 To PageCount Do
  For I := 0 To ObjCount - 1 Do
   If (ObjP(I)^.Page = Pg) And IsAnnot(ObjP(I)^.Kind) Then Begin
    BeginObj(AnnNext);
    WL(AnnotOf(Pg, I));
    EndObj;
    Inc(AnnNext);
   End;
 For I := 1 To ImgCount Do
  If ImgNo^[I] <> 0 Then Begin
   If (ImgP(I)^.SMIdx > 0) And (ImgNo^[ImgP(I)^.SMIdx] <> 0) Then WriteImageXObj(I, ImgNo^[I], ImgNo^[ImgP(I)^.SMIdx])
   Else WriteImageXObj(I, ImgNo^[I], 0);
  End;
 XStart := OutPos;
 WL('xref');
 WL('0 ' + IStr(NObj));
 WL('0000000000 65535 f ');
 For I := 1 To NObj - 1 Do Begin
  S := IStr(XRef^[I]);
  While Length(S) < 10 Do S := '0' + S;
  WL(S + ' 00000 n ');
 End;
 WL('trailer');
 WL('<< /Size ' + IStr(NObj) + ' /Root 1 0 R /Info 3 0 R >>');
 WL('startxref');
 WL(IStr(XStart));
 WL('%%EOF');
 {$I-}
 Close(OutF);
 {$I+}
 If IOResult <> 0 Then OutErr := True;
 FreeMem(XRef, (NObj + 2) * SizeOf(LongInt));
 FreeMem(ImgNo, (ImgCount + 2) * SizeOf(LongInt));
 If CapBuf <> Nil Then Begin FreeMem(CapBuf, CapSize); CapBuf := Nil; End;
 SaveAsPDF := Not OutErr;
End;

{ ---------------------------------------------------------------------- }
{ Import PDF : couche de lecture                                           }
{ ---------------------------------------------------------------------- }

Const
 T_EOF = 0; T_NUM = 1; T_NAME = 2; T_STR = 3; T_OP = 4;
 T_AB = 5; T_AE = 6; T_DB = 7; T_DE = 8;

Var
 PF: File;
 PFSize: LongInt;
 RBuf: Array[0..4095] Of Byte;
 RBase: LongInt;
 RLen: Integer;
 SrcMode: Integer;       { 0 fichier, 1 flux d'objets, 2 contenu, 3 ToUnicode }
 StmBuf, CBuf, TuBuf, RawBuf, Buf2: PByteBuf;
 StmLen, CLen, TuLen: LongInt;
 StmCacheNum: Integer;
 CBufs: Array[0..3] Of PByteBuf;
 TokS: String;
 StrBuf: Array[0..1023] Of Byte;
 StrLen: Integer;
 DecCap: LongInt;
 TokR: Real;
 TokInt: Boolean;
 ObjPos: PLArr;
 ObjStmNo, ObjStmOff: PWArr;
 PdfCap: LongInt;
 MaxObjNum: Integer;
 RootNum, InfoNum: Integer;
 PdfBuffersReady: Boolean;
 ImgByObj: PWArr;

Function SB(Pos: LongInt): Integer;
Var
 RW: Word;
Begin
 Case SrcMode Of
  0: Begin
   If (Pos < 0) Or (Pos >= PFSize) Then Begin SB := -1; Exit; End;
   If (Pos < RBase) Or (Pos >= RBase + RLen) Then Begin
    RBase := Pos - (Pos Mod 4096);
    Seek(PF, RBase);
    RW := 0;
    BlockRead(PF, RBuf, 4096, RW);
    RLen := RW;
    If Pos >= RBase + RLen Then Begin SB := -1; Exit; End;
   End;
   SB := RBuf[Pos - RBase];
  End;
  1: If (Pos < 0) Or (Pos >= StmLen) Then SB := -1 Else SB := StmBuf^[Pos];
  2: If (Pos < 0) Or (Pos >= CLen) Then SB := -1 Else SB := CBuf^[Pos];
 Else
  If (Pos < 0) Or (Pos >= TuLen) Then SB := -1 Else SB := TuBuf^[Pos];
 End;
End;

Function IsWs(C: Integer): Boolean;
Begin
 IsWs := (C = 32) Or (C = 10) Or (C = 13) Or (C = 9) Or (C = 0) Or (C = 12);
End;

Function IsDelim(C: Integer): Boolean;
Begin
 IsDelim := (C = 40) Or (C = 41) Or (C = 60) Or (C = 62) Or (C = 91) Or (C = 93) Or
            (C = 123) Or (C = 125) Or (C = 47) Or (C = 37);
End;

Function HexVal(C: Integer): Integer;
Begin
 If (C >= 48) And (C <= 57) Then HexVal := C - 48
 Else If (C >= 65) And (C <= 70) Then HexVal := C - 55
 Else If (C >= 97) And (C <= 102) Then HexVal := C - 87
 Else HexVal := -1;
End;

Function NextTok(Var P: LongInt): Integer;
Var
 C, C2, Depth, V, H, N: Integer;
 Neg, Dot: Boolean;
 Scale: Real;
 Digits: Integer;
Begin
 TokS := '';
 NextTok := T_EOF;
 Repeat
  C := SB(P);
  If C = 37 Then Begin
   While (C <> -1) And (C <> 10) And (C <> 13) Do Begin Inc(P); C := SB(P); End;
  End;
  If IsWs(C) Then Inc(P);
 Until Not (IsWs(C) Or (C = 37));
 If C = -1 Then Exit;
 Case C Of
  47: Begin
   Inc(P);
   NextTok := T_NAME;
   While True Do Begin
    C := SB(P);
    If (C = -1) Or IsWs(C) Or IsDelim(C) Then Break;
    If (C = 35) And (HexVal(SB(P + 1)) >= 0) And (HexVal(SB(P + 2)) >= 0) Then Begin
     C := HexVal(SB(P + 1)) * 16 + HexVal(SB(P + 2));
     Inc(P, 2);
    End;
    If Length(TokS) < 255 Then TokS := TokS + Chr(C);
    Inc(P);
   End;
  End;
  40: Begin
   Inc(P);
   NextTok := T_STR;
   StrLen := 0;
   Depth := 1;
   While True Do Begin
    C := SB(P);
    If C = -1 Then Break;
    Inc(P);
    If C = 92 Then Begin
     C2 := SB(P);
     Inc(P);
     Case C2 Of
      110: C := 10; 114: C := 13; 116: C := 9; 98: C := 8; 102: C := 12;
      40, 41, 92: C := C2;
      13: Begin
       If SB(P) = 10 Then Inc(P);
       C := -2;
      End;
      10: C := -2;
      48..55: Begin
       V := C2 - 48;
       C2 := SB(P);
       If (C2 >= 48) And (C2 <= 55) Then Begin
        V := V * 8 + C2 - 48; Inc(P);
        C2 := SB(P);
        If (C2 >= 48) And (C2 <= 55) Then Begin V := V * 8 + C2 - 48; Inc(P); End;
       End;
       C := V And 255;
      End;
     Else C := C2;
     End;
    End
    Else If C = 40 Then Inc(Depth)
    Else If C = 41 Then Begin
     Dec(Depth);
     If Depth = 0 Then Break;
    End;
    If C >= 0 Then Begin
     If Length(TokS) < 255 Then TokS := TokS + Chr(C);
     If StrLen < 1024 Then Begin StrBuf[StrLen] := C; Inc(StrLen); End;
    End;
   End;
  End;
  60: Begin
   If SB(P + 1) = 60 Then Begin
    Inc(P, 2);
    NextTok := T_DB;
   End
   Else Begin
    Inc(P);
    NextTok := T_STR;
    StrLen := 0;
    H := -1;
    While True Do Begin
     C := SB(P);
     If C = -1 Then Break;
     Inc(P);
     If C = 62 Then Break;
     V := HexVal(C);
     If V < 0 Then Continue;
     If H < 0 Then H := V
     Else Begin
      If Length(TokS) < 255 Then TokS := TokS + Chr(H * 16 + V);
      If StrLen < 1024 Then Begin StrBuf[StrLen] := H * 16 + V; Inc(StrLen); End;
      H := -1;
     End;
    End;
    If H >= 0 Then If Length(TokS) < 255 Then TokS := TokS + Chr(H * 16);
   End;
  End;
  62: Begin
   If SB(P + 1) = 62 Then Begin
    Inc(P, 2);
    NextTok := T_DE;
   End
   Else Begin
    Inc(P);
    NextTok := NextTok(P);
   End;
  End;
  91: Begin Inc(P); NextTok := T_AB; End;
  93: Begin Inc(P); NextTok := T_AE; End;
  123, 125: Begin Inc(P); NextTok := T_OP; TokS := Chr(C); End;
  41: Begin Inc(P); NextTok := NextTok(P); End;
  43, 45, 46, 48..57: Begin
   Neg := False; Dot := False; TokR := 0; Scale := 1; Digits := 0;
   While (C = 43) Or (C = 45) Do Begin
    If C = 45 Then Neg := True;
    Inc(P); C := SB(P);
   End;
   While True Do Begin
    If (C >= 48) And (C <= 57) Then Begin
     If Dot Then Begin
      Scale := Scale / 10;
      TokR := TokR + (C - 48) * Scale;
     End
     Else TokR := TokR * 10 + (C - 48);
     Inc(Digits);
    End
    Else If (C = 46) And (Not Dot) Then Dot := True
    Else If C = 45 Then { signe parasite dans le nombre : ignorer }
    Else Break;
    Inc(P);
    C := SB(P);
   End;
   If Neg Then TokR := -TokR;
   TokInt := Not Dot;
   NextTok := T_NUM;
   If Digits = 0 Then Begin TokR := 0; End;
  End;
 Else
  NextTok := T_OP;
  While True Do Begin
   C := SB(P);
   If (C = -1) Or IsWs(C) Or IsDelim(C) Then Break;
   If Length(TokS) < 255 Then TokS := TokS + Chr(C);
   Inc(P);
  End;
  If TokS = '' Then Begin Inc(P); End;
 End;
End;

Procedure SkipValue(Var P: LongInt);
Var
 T: Integer;
 Q, Q2: LongInt;
Begin
 T := NextTok(P);
 Case T Of
  T_AB: Begin
   While True Do Begin
    Q := P;
    T := NextTok(P);
    If (T = T_AE) Or (T = T_EOF) Then Break;
    P := Q;
    SkipValue(P);
   End;
  End;
  T_DB: Begin
   While True Do Begin
    T := NextTok(P);
    If (T = T_DE) Or (T = T_EOF) Then Break;
    If T = T_NAME Then SkipValue(P);
   End;
  End;
  T_NUM: Begin
   If TokInt Then Begin
    Q := P;
    If NextTok(Q) = T_NUM Then
     If TokInt Then Begin
      Q2 := Q;
      If NextTok(Q2) = T_OP Then
       If TokS = 'R' Then P := Q2;
     End;
   End;
  End;
 End;
End;

{ P pointe sur '<<'. Retourne la position de la valeur de la clé, ou -1. }
Function DictFind(P: LongInt; Const Key: String): LongInt;
Var
 T: Integer;
Begin
 DictFind := -1;
 If NextTok(P) <> T_DB Then Exit;
 While True Do Begin
  T := NextTok(P);
  If (T = T_DE) Or (T = T_EOF) Then Exit;
  If T = T_NAME Then Begin
   If TokS = Key Then Begin
    DictFind := P;
    Exit;
   End;
   SkipValue(P);
  End;
 End;
End;

{ Y a-t-il une référence "N G R" en P ? }
Function RefAt(P: LongInt): Integer;
Var
 N: LongInt;
Begin
 RefAt := 0;
 If NextTok(P) <> T_NUM Then Exit;
 If Not TokInt Then Exit;
 If (TokR < 1) Or (TokR > MAXPDFOBJ) Then Exit;
 N := Round(TokR);
 If NextTok(P) <> T_NUM Then Exit;
 If NextTok(P) <> T_OP Then Exit;
 If TokS = 'R' Then RefAt := N;
End;

Type
 TSrcState = Record
  Mode, Stm: Integer;
 End;

Function LoadObjStm(N: Integer): Boolean; Forward;
Function EnterObj(Num: Integer): LongInt; Forward;

Procedure SaveSrc(Var S: TSrcState);
Begin
 S.Mode := SrcMode;
 S.Stm := StmCacheNum;
End;

Procedure RestoreSrc(Const S: TSrcState);
Begin
 If S.Mode = 1 Then Begin
  If StmCacheNum <> S.Stm Then LoadObjStm(S.Stm);
  SrcMode := 1;
 End
 Else SrcMode := S.Mode;
End;

{ Valeur numérique en P (suit les références indirectes) }
Function ValNum(P: LongInt; Def: Real): Real;
Var
 N: Integer;
 S: TSrcState;
 Q: LongInt;
 R: Real;
Begin
 ValNum := Def;
 If P < 0 Then Exit;
 N := RefAt(P);
 If N > 0 Then Begin
  SaveSrc(S);
  Q := EnterObj(N);
  If Q >= 0 Then Begin
   If NextTok(Q) = T_NUM Then R := TokR Else R := Def;
   ValNum := R;
  End;
  RestoreSrc(S);
 End
 Else If NextTok(P) = T_NUM Then ValNum := TokR;
End;

Function ValInt(P: LongInt; Def: LongInt): LongInt;
Var
 R: Real;
Begin
 R := ValNum(P, Def);
 If R > 2000000000.0 Then R := 2000000000.0;
 If R < -2000000000.0 Then R := -2000000000.0;
 ValInt := Round(R);
End;

Function ValName(P: LongInt): String;
Begin
 ValName := '';
 If P < 0 Then Exit;
 If NextTok(P) = T_NAME Then ValName := TokS;
End;

{ Lit n nombres d'un tableau à partir de P. Retourne le nombre lu. }
Function ReadNums(P: LongInt; Var A: Array Of Real; Max: Integer): Integer;
Var
 N: Integer;
 T: Integer;
 Q: LongInt;
Begin
 N := 0;
 ReadNums := 0;
 If P < 0 Then Exit;
 If NextTok(P) <> T_AB Then Exit;
 While N < Max Do Begin
  Q := P;
  T := NextTok(P);
  If T = T_NUM Then Begin
   A[N] := TokR;
   Inc(N);
   { ignorer une éventuelle référence "G R" }
   Q := P;
   If NextTok(Q) = T_NUM Then Begin
    If NextTok(Q) = T_OP Then
     If TokS = 'R' Then Begin Dec(N); P := Q; A[N] := 0; End;
   End;
  End
  Else If T = T_AE Then Break
  Else If T = T_EOF Then Break
  Else Begin P := Q; SkipValue(P); End;
 End;
 ReadNums := N;
End;

{ Décodage d'une chaîne de texte PDF (PDFDocEncoding / UTF-16BE) }
Function PdfText(Const S: String): String;
Var
 I: Integer;
 R: String;
Begin
 If (Length(S) >= 2) And (S[1] = #254) And (S[2] = #255) Then Begin
  R := '';
  I := 3;
  While I < Length(S) Do Begin
   If Ord(S[I]) = 0 Then R := R + S[I + 1]
   Else If (Ord(S[I]) = 32) And (Ord(S[I + 1]) = 19) Then R := R + '-'
   Else R := R + '?';
   Inc(I, 2);
  End;
  PdfText := R;
 End
 Else PdfText := S;
End;

{ ---------------------------------------------------------------------- }
{ Décompression : Flate, ASCIIHex, ASCII85                                  }
{ ---------------------------------------------------------------------- }

Type
 TInflTree = Record
  Counts: Array[0..15] Of Word;
  Syms: Array[0..287] Of Word;
 End;

Var
 IS_: PByteBuf;
 ISLen, ISPos: LongInt;
 ITag: LongInt;
 IBits: Integer;
 IDst: PByteBuf;
 IDLen, IDMax: LongInt;
 IErr: Boolean;
 LTree, DTree: TInflTree;


Function GetBit: Integer;
Begin
 If IBits = 0 Then Begin
  If ISPos >= ISLen Then Begin IErr := True; GetBit := 0; Exit; End;
  ITag := IS_^[ISPos];
  Inc(ISPos);
  IBits := 8;
 End;
 GetBit := ITag And 1;
 ITag := ITag Shr 1;
 Dec(IBits);
End;

Function GetBits(N: Integer): LongInt;
Var
 I: Integer;
 V: LongInt;
Begin
 V := 0;
 For I := 0 To N - 1 Do V := V Or (LongInt(GetBit) Shl I);
 GetBits := V;
End;

Procedure BuildTree(Var T: TInflTree; Const Lens: Array Of Byte; Off, Num: Integer);
Var
 I: Integer;
 Offs: Array[0..16] Of Word;
Begin
 For I := 0 To 15 Do T.Counts[I] := 0;
 For I := 0 To Num - 1 Do Inc(T.Counts[Lens[Off + I]]);
 T.Counts[0] := 0;
 Offs[1] := 0;
 For I := 1 To 15 Do Offs[I + 1] := Offs[I] + T.Counts[I];
 For I := 0 To Num - 1 Do
  If Lens[Off + I] <> 0 Then Begin
   T.Syms[Offs[Lens[Off + I]]] := I;
   Inc(Offs[Lens[Off + I]]);
  End;
End;

Function DecodeSym(Var T: TInflTree): Integer;
Var
 Sum, Cur, Len: LongInt;
Begin
 Sum := 0; Cur := 0; Len := 0;
 Repeat
  Cur := 2 * Cur + GetBit;
  Inc(Len);
  If Len > 15 Then Begin IErr := True; DecodeSym := 0; Exit; End;
  Sum := Sum + T.Counts[Len];
  Cur := Cur - T.Counts[Len];
 Until (Cur < 0) Or IErr;
 If Sum + Cur > 287 Then Begin IErr := True; DecodeSym := 0; Exit; End;
 DecodeSym := T.Syms[Sum + Cur];
End;

Procedure InflateCodes;
Var
 Sym, Len, Dist, I: Integer;
 Src: LongInt;
Begin
 While Not IErr Do Begin
  Sym := DecodeSym(LTree);
  If IErr Then Exit;
  If Sym < 256 Then Begin
   If IDLen >= IDMax Then Begin IErr := True; Exit; End;
   IDst^[IDLen] := Sym;
   Inc(IDLen);
  End
  Else If Sym = 256 Then Exit
  Else Begin
   Sym := Sym - 257;
   If Sym > 28 Then Begin IErr := True; Exit; End;
   Len := LBase[Sym] + GetBits(LExtra[Sym]);
   Dist := DecodeSym(DTree);
   If Dist > 29 Then Begin IErr := True; Exit; End;
   Dist := DBase[Dist] + GetBits(DExtra[Dist]);
   If Dist > IDLen Then Begin IErr := True; Exit; End;
   If IDLen + Len > IDMax Then Begin IErr := True; Exit; End;
   Src := IDLen - Dist;
   For I := 1 To Len Do Begin
    IDst^[IDLen] := IDst^[Src];
    Inc(IDLen);
    Inc(Src);
   End;
  End;
 End;
End;

Procedure FixedTrees;
Var
 L: Array[0..287] Of Byte;
 D: Array[0..29] Of Byte;
 I: Integer;
Begin
 For I := 0 To 143 Do L[I] := 8;
 For I := 144 To 255 Do L[I] := 9;
 For I := 256 To 279 Do L[I] := 7;
 For I := 280 To 287 Do L[I] := 8;
 For I := 0 To 29 Do D[I] := 5;
 BuildTree(LTree, L, 0, 288);
 BuildTree(DTree, D, 0, 30);
End;

Procedure DynamicTrees;
Var
 L: Array[0..319] Of Byte;
 CL: Array[0..18] Of Byte;
 CT: TInflTree;
 HLit, HDist, HCLen, I, Num, Sym, Prev, Rep: Integer;
Begin
 HLit := GetBits(5) + 257;
 HDist := GetBits(5) + 1;
 HCLen := GetBits(4) + 4;
 If (HLit > 286) Or (HDist > 30) Then Begin IErr := True; Exit; End;
 For I := 0 To 18 Do CL[I] := 0;
 For I := 0 To HCLen - 1 Do CL[CLOrder[I]] := GetBits(3);
 BuildTree(CT, CL, 0, 19);
 Num := 0;
 Prev := 0;
 While (Num < HLit + HDist) And (Not IErr) Do Begin
  Sym := DecodeSym(CT);
  If Sym < 16 Then Begin L[Num] := Sym; Prev := Sym; Inc(Num); End
  Else Begin
   If Sym = 16 Then Begin Rep := 3 + GetBits(2); End
   Else If Sym = 17 Then Begin Rep := 3 + GetBits(3); Prev := 0; End
   Else Begin Rep := 11 + GetBits(7); Prev := 0; End;
   If Num + Rep > HLit + HDist Then Begin IErr := True; Exit; End;
   While Rep > 0 Do Begin L[Num] := Prev; Inc(Num); Dec(Rep); End;
  End;
 End;
 If IErr Then Exit;
 BuildTree(LTree, L, 0, HLit);
 BuildTree(DTree, L, HLit, HDist);
End;

Function FlateDec(Src: PByteBuf; SLen: LongInt; Dst: PByteBuf; Var DLen: LongInt): Boolean;
Var
 Final, BType: Integer;
 Len, NLen, I: LongInt;
Begin
 IS_ := Src; ISLen := SLen; ISPos := 0; ITag := 0; IBits := 0;
 IDst := Dst; IDLen := 0; IDMax := DecCap; IErr := False;
 If SLen < 2 Then Begin DLen := 0; FlateDec := False; Exit; End;
 If (Src^[0] And 15) = 8 Then ISPos := 2;
 Repeat
  Final := GetBit;
  BType := GetBits(2);
  If IErr Then Break;
  Case BType Of
   0: Begin
    IBits := 0;
    If ISPos + 4 > ISLen Then Begin IErr := True; Break; End;
    Len := Src^[ISPos] + Src^[ISPos + 1] * 256;
    NLen := Src^[ISPos + 2] + Src^[ISPos + 3] * 256;
    Inc(ISPos, 4);
    If Len <> (NLen Xor $FFFF) Then Begin IErr := True; Break; End;
    For I := 1 To Len Do Begin
     If (ISPos >= ISLen) Or (IDLen >= IDMax) Then Begin IErr := True; Break; End;
     Dst^[IDLen] := Src^[ISPos];
     Inc(IDLen); Inc(ISPos);
    End;
   End;
   1: Begin FixedTrees; InflateCodes; End;
   2: Begin DynamicTrees; If Not IErr Then InflateCodes; End;
  Else IErr := True;
  End;
 Until (Final = 1) Or IErr;
 DLen := IDLen;
 FlateDec := (Not IErr) Or (IDLen > 0);
End;

Function AHexDec(Src: PByteBuf; SLen: LongInt; Dst: PByteBuf; Var DLen: LongInt): Boolean;
Var
 I: LongInt;
 H, V: Integer;
Begin
 DLen := 0; H := -1;
 For I := 0 To SLen - 1 Do Begin
  If Src^[I] = 62 Then Break;
  V := HexVal(Src^[I]);
  If V < 0 Then Continue;
  If H < 0 Then H := V
  Else Begin
   If DLen < DecCap Then Begin Dst^[DLen] := H * 16 + V; Inc(DLen); End;
   H := -1;
  End;
 End;
 If (H >= 0) And (DLen < DecCap) Then Begin Dst^[DLen] := H * 16; Inc(DLen); End;
 AHexDec := True;
End;

Function A85Dec(Src: PByteBuf; SLen: LongInt; Dst: PByteBuf; Var DLen: LongInt): Boolean;
Var
 I: LongInt;
 Grp: Array[0..4] Of Integer;
 N, K: Integer;
 V: LongInt;
 C: Integer;
 Procedure Flush(Cnt: Integer);
 Var
  J: Integer;
  W: Real;
  Q: LongInt;
 Begin
  For J := Cnt To 4 Do Grp[J] := 84;
  W := 0;
  For J := 0 To 4 Do W := W * 85 + Grp[J];
  For J := 0 To Cnt - 2 Do Begin
   Q := Trunc(W / 16777216.0);
   If DLen < DecCap Then Begin Dst^[DLen] := Q And 255; Inc(DLen); End;
   W := W - Q * 16777216.0;
   W := W * 256;
  End;
 End;
Begin
 DLen := 0; N := 0;
 For I := 0 To SLen - 1 Do Begin
  C := Src^[I];
  If C = 126 Then Break;
  If IsWs(C) Then Continue;
  If C = 122 Then Begin
   For K := 1 To 4 Do If DLen < DecCap Then Begin Dst^[DLen] := 0; Inc(DLen); End;
   Continue;
  End;
  If (C < 33) Or (C > 117) Then Continue;
  Grp[N] := C - 33;
  Inc(N);
  If N = 5 Then Begin Flush(5); N := 0; End;
 End;
 If N > 1 Then Flush(N);
 A85Dec := True;
End;

{ ---------------------------------------------------------------------- }
{ Table d'objets                                                            }
{ ---------------------------------------------------------------------- }

Function AllocBuf: PByteBuf;
Var
 P: PByteBuf;
Begin
 GetMem(P, BUFSZ + 17);
 AllocBuf := P;
End;

{ Agrandit les tables d'objets PDF (tas) selon le plus grand numéro rencontré }
Procedure EnsurePdfCap(Need: LongInt);
Var
 NewCap, I: LongInt;
 P: Pointer;
Begin
 If Need < PdfCap Then Exit;
 NewCap := PdfCap * 2;
 If NewCap < Need + 1 Then NewCap := Need + 1;
 If NewCap < 4096 Then NewCap := 4096;
 P := ObjPos; ReAllocMem(P, NewCap * SizeOf(LongInt)); ObjPos := P;
 P := ObjStmNo; ReAllocMem(P, NewCap * SizeOf(Word)); ObjStmNo := P;
 P := ObjStmOff; ReAllocMem(P, NewCap * SizeOf(Word)); ObjStmOff := P;
 P := ImgByObj; ReAllocMem(P, NewCap * SizeOf(Word)); ImgByObj := P;
 For I := PdfCap To NewCap - 1 Do Begin
  ObjPos^[I] := -1; ObjStmNo^[I] := 0; ObjStmOff^[I] := 0; ImgByObj^[I] := 0;
 End;
 PdfCap := NewCap;
End;

Procedure InitPdfBuffers;
Var
 I: Integer;
Begin
 If PdfBuffersReady Then Exit;
 StmBuf := AllocBuf; TuBuf := AllocBuf; RawBuf := AllocBuf; Buf2 := AllocBuf;
 For I := 0 To 3 Do CBufs[I] := AllocBuf;
 PdfCap := 0;
 ObjPos := Nil; ObjStmNo := Nil; ObjStmOff := Nil; ImgByObj := Nil;
 EnsurePdfCap(4096);
 DecCap := BUFSZ;
 PdfBuffersReady := True;
End;

Function FindStreamData(Var DStart: LongInt; Var DLen: LongInt; LenVal: LongInt): Boolean;
Var
 P, Q: LongInt;
 C, K: Integer;
 Probe: LongInt;
Begin
 FindStreamData := False;
 P := DStart;
 { sauter l'EOL après le mot "stream" }
 If SB(P) = 13 Then Begin
  Inc(P);
  If SB(P) = 10 Then Inc(P);
 End
 Else If SB(P) = 10 Then Inc(P);
 DStart := P;
 If LenVal >= 0 Then Begin
  Probe := P + LenVal;
  Q := Probe;
  While IsWs(SB(Q)) And (Q < Probe + 4) Do Inc(Q);
  If (SB(Q) = 101) And (SB(Q + 1) = 110) And (SB(Q + 2) = 100) And (SB(Q + 3) = 115) Then Begin
   DLen := LenVal;
   FindStreamData := True;
   Exit;
  End;
 End;
 { Longueur douteuse : chercher "endstream" }
 Q := P;
 While True Do Begin
  C := SB(Q);
  If C = -1 Then Break;
  If (C = 101) And (SB(Q + 1) = 110) And (SB(Q + 2) = 100) And (SB(Q + 3) = 115) And
     (SB(Q + 4) = 116) And (SB(Q + 5) = 114) Then Begin
   K := 0;
   DLen := Q - P;
   If (DLen > 0) And (SB(P + DLen - 1) = 10) Then Dec(DLen);
   If (DLen > 0) And (SB(P + DLen - 1) = 13) Then Dec(DLen);
   FindStreamData := True;
   Exit;
  End;
  Inc(Q);
 End;
End;

{ Charge et décode le flux de l'objet Num dans Dst. }
Function LoadStream(Num: Integer; Dst: PByteBuf; Var OutLen: LongInt): Boolean;
Var
 P, DictP, V, Q, DStart, RawLen: LongInt;
 LenVal: LongInt;
 Filters: Array[0..3] Of String[24];
 NF, K, T: Integer;
 S: TSrcState;
 Cur, Nxt: PByteBuf;
 CurLen, NxtLen: LongInt;
 Got: Word;
 ToRead, Done: LongInt;
 Ok: Boolean;
Begin
 LoadStream := False;
 OutLen := 0;
 SaveSrc(S);
 P := EnterObj(Num);
 If (P < 0) Or (SrcMode <> 0) Then Begin RestoreSrc(S); Exit; End;
 DictP := P;
 NF := 0;
 V := DictFind(DictP, 'Filter');
 If V >= 0 Then Begin
  Q := V;
  T := NextTok(Q);
  If T = T_NAME Then Begin Filters[0] := TokS; NF := 1; End
  Else If T = T_AB Then Begin
   While NF < 4 Do Begin
    T := NextTok(Q);
    If T = T_NAME Then Begin Filters[NF] := TokS; Inc(NF); End Else Break;
   End;
  End;
 End;
 V := DictFind(DictP, 'Length');
 LenVal := -1;
 If V >= 0 Then LenVal := ValInt(V, -1);
 SrcMode := 0;
 { position après le dictionnaire }
 Q := DictP;
 SkipValue(Q);
 If NextTok(Q) <> T_OP Then Begin RestoreSrc(S); Exit; End;
 If TokS <> 'stream' Then Begin RestoreSrc(S); Exit; End;
 DStart := Q;
 If Not FindStreamData(DStart, RawLen, LenVal) Then Begin RestoreSrc(S); Exit; End;
 If RawLen > BUFSZ Then RawLen := BUFSZ;
 Seek(PF, DStart);
 Done := 0;
 While Done < RawLen Do Begin
  ToRead := RawLen - Done;
  If ToRead > 4096 Then ToRead := 4096;
  Got := 0;
  BlockRead(PF, RawBuf^[Done], ToRead, Got);
  If Got = 0 Then Break;
  Done := Done + Got;
 End;
 RBase := -1; RLen := 0;
 RawLen := Done;
 Cur := RawBuf; CurLen := RawLen;
 Ok := True;
 For K := 0 To NF - 1 Do Begin
  If K = NF - 1 Then Nxt := Dst
  Else If Cur = RawBuf Then Nxt := Buf2 Else Nxt := RawBuf;
  If (Filters[K] = 'FlateDecode') Or (Filters[K] = 'Fl') Then Ok := FlateDec(Cur, CurLen, Nxt, NxtLen)
  Else If (Filters[K] = 'ASCIIHexDecode') Or (Filters[K] = 'AHx') Then Ok := AHexDec(Cur, CurLen, Nxt, NxtLen)
  Else If (Filters[K] = 'ASCII85Decode') Or (Filters[K] = 'A85') Then Ok := A85Dec(Cur, CurLen, Nxt, NxtLen)
  Else Ok := False;
  If Not Ok Then Break;
  Cur := Nxt; CurLen := NxtLen;
 End;
 If Ok Then Begin
  If NF = 0 Then Move(RawBuf^, Dst^, CurLen);
  OutLen := CurLen;
  LoadStream := True;
 End;
 SrcMode := 0;
 RestoreSrc(S);
End;

Function LoadObjStm(N: Integer): Boolean;
Var
 L: LongInt;
Begin
 LoadObjStm := False;
 If StmCacheNum = N Then Begin SrcMode := 1; LoadObjStm := True; Exit; End;
 SrcMode := 0;
 StmCacheNum := 0;
 If LoadStream(N, StmBuf, L) Then Begin
  StmLen := L;
  StmCacheNum := N;
  SrcMode := 1;
  LoadObjStm := True;
 End;
End;

{ Entre dans l'objet Num : retourne la position du corps de l'objet. }
Function EnterObj(Num: Integer): LongInt;
Begin
 EnterObj := -1;
 If (Num <= 0) Or (Num > MaxObjNum) Or (Num >= PdfCap) Then Exit;
 If ObjPos^[Num] >= 0 Then Begin
  SrcMode := 0;
  EnterObj := ObjPos^[Num];
 End
 Else If ObjStmNo^[Num] <> 0 Then Begin
  If LoadObjStm(ObjStmNo^[Num]) Then EnterObj := ObjStmOff^[Num];
 End;
End;

Procedure ShowProgress(Const Msg: String); Forward;

{ ---------------------------------------------------------------------- }
{ Import PDF : analyse du fichier                                           }
{ ---------------------------------------------------------------------- }

Var
 XRefBest: Integer;
 XRefBestPos: LongInt;
 TrPos: Array[0..7] Of LongInt;
 TrCount: Integer;
 StmList: Array[0..255] Of Word;
 StmListN: Integer;

Function IsDigitC(C: Integer): Boolean;
Begin
 IsDigitC := (C >= 48) And (C <= 57);
End;

Procedure TryObjHeader(Q: LongInt);
Var
 C: Integer;
 P, E, S2, E2: LongInt;
 Num: LongInt;
 I: LongInt;
Begin
 If Q > 0 Then If Not IsWs(SB(Q - 1)) Then Exit;
 C := SB(Q + 3);
 If (C <> -1) And (Not IsWs(C)) And (Not IsDelim(C)) Then Exit;
 P := Q - 1;
 While (P > 0) And IsWs(SB(P)) Do Dec(P);
 E := P;
 While (P > 0) And IsDigitC(SB(P)) Do Dec(P);
 If P = E Then Exit;
 S2 := P;
 While (P > 0) And IsWs(SB(P)) Do Dec(P);
 If P = S2 Then Exit;
 E2 := P;
 While (P >= 0) And IsDigitC(SB(P)) Do Dec(P);
 If P = E2 Then Exit;
 If E2 - P > 7 Then Exit;
 C := SB(P);
 If (C <> -1) And (Not IsWs(C)) And (Not IsDelim(C)) Then Exit;
 Num := 0;
 For I := P + 1 To E2 Do Num := Num * 10 + (SB(I) - 48);
 If (Num < 1) Or (Num > MAXPDFOBJ) Then Exit;
 EnsurePdfCap(Num);
 ObjPos^[Num] := Q + 3;
 ObjStmNo^[Num] := 0;
 If Num > MaxObjNum Then MaxObjNum := Num;
End;

Procedure ScanFile;
Var
 Pos: LongInt;
 N, I: LongInt;
 Got: Word;
 Chunk: PByteBuf;
 Lim: LongInt;
 Eof: Boolean;
 Q: LongInt;
Begin
 Chunk := RawBuf;
 Pos := 0;
 TrCount := 0;
 SrcMode := 0;
 Repeat
  Seek(PF, Pos);
  Got := 0;
  BlockRead(PF, Chunk^, 60000, Got);
  N := Got;
  Eof := Pos + N >= PFSize;
  If Eof Then Lim := N - 3 Else Lim := N - 10;
  For I := 0 To Lim - 1 Do Begin
   If Chunk^[I] = 111 Then Begin
    If (Chunk^[I + 1] = 98) And (Chunk^[I + 2] = 106) Then Begin
     RBase := -1; RLen := 0;
     TryObjHeader(Pos + I);
    End;
   End
   Else If Chunk^[I] = 116 Then Begin
    If (Chunk^[I + 1] = 114) And (Chunk^[I + 2] = 97) And (Chunk^[I + 3] = 105) And
       (Chunk^[I + 4] = 108) And (Chunk^[I + 5] = 101) And (Chunk^[I + 6] = 114) Then
     Begin
      If TrCount >= 8 Then Begin
       For Q := 0 To 6 Do TrPos[Q] := TrPos[Q + 1];
       TrCount := 7;
      End;
      TrPos[TrCount] := Pos + I + 7;
      Inc(TrCount);
     End;
   End;
  End;
  If Eof Then Break;
  Pos := Pos + Lim;
 Until False;
 RBase := -1; RLen := 0;
End;

Procedure ProcessObjects;
Var
 N, I, K: Integer;
 P, V: LongInt;
 Nm: String;
 First, Cnt, L, Q: LongInt;
 ON, OO: LongInt;
Begin
 SrcMode := 0;
 StmListN := 0;
 XRefBest := 0; XRefBestPos := -1;
 For I := 0 To TrCount - 1 Do Begin
  V := DictFind(TrPos[I], 'Root');
  If V >= 0 Then Begin N := RefAt(V); If N > 0 Then RootNum := N; End;
  V := DictFind(TrPos[I], 'Info');
  If V >= 0 Then Begin N := RefAt(V); If N > 0 Then InfoNum := N; End;
  If DictFind(TrPos[I], 'Encrypt') >= 0 Then DocEncrypted := True;
 End;
 For N := 1 To MaxObjNum Do Begin
  If ObjPos^[N] < 0 Then Continue;
  P := ObjPos^[N];
  V := DictFind(P, 'Type');
  If V < 0 Then Continue;
  Nm := ValName(V);
  If Nm = 'Catalog' Then RootNum := N
  Else If Nm = 'XRef' Then Begin
   If ObjPos^[N] > XRefBestPos Then Begin XRefBestPos := ObjPos^[N]; XRefBest := N; End;
   V := DictFind(P, 'Root');
   If V >= 0 Then If RefAt(V) > 0 Then RootNum := RefAt(V);
   V := DictFind(P, 'Info');
   If V >= 0 Then If RefAt(V) > 0 Then InfoNum := RefAt(V);
   If DictFind(P, 'Encrypt') >= 0 Then DocEncrypted := True;
  End
  Else If Nm = 'ObjStm' Then Begin
   If StmListN < 256 Then Begin StmList[StmListN] := N; Inc(StmListN); End;
  End;
 End;
 For I := 0 To StmListN - 1 Do Begin
  N := StmList[I];
  SrcMode := 0;
  P := ObjPos^[N];
  First := ValInt(DictFind(P, 'First'), 0);
  Cnt := ValInt(DictFind(P, 'N'), 0);
  StmCacheNum := 0;
  If Not LoadStream(N, StmBuf, L) Then Continue;
  StmLen := L;
  StmCacheNum := N;
  SrcMode := 1;
  Q := 0;
  For K := 1 To Cnt Do Begin
   If NextTok(Q) <> T_NUM Then Break;
   ON := Round(TokR);
   If NextTok(Q) <> T_NUM Then Break;
   OO := Round(TokR);
   If (ON >= 1) And (ON <= MAXPDFOBJ) And (First + OO < 65000) Then Begin
    EnsurePdfCap(ON);
    If ObjPos^[ON] < 0 Then Begin
     ObjStmNo^[ON] := N;
     ObjStmOff^[ON] := First + OO;
     If ON > MaxObjNum Then MaxObjNum := ON;
    End;
   End;
  End;
 End;
 SrcMode := 0;
End;

{ ---------------------------------------------------------------------- }
{ Polices et ressources                                                      }
{ ---------------------------------------------------------------------- }

Const
 FMAX = 28;
 XMAX = 64;

Type
 TRange = Record
  Lo, Hi, Dst, Dst2: Word;
 End;
 TRangeArr = Array[0..299] Of TRange;
 PRangeArr = ^TRangeArr;
 TWdArr = Array[0..255] Of Integer;
 PWdArr = ^TWdArr;
 TFontRec = Record
  Name: String[63];
  Fam, Style: Integer;
  Wide, HasWd: Boolean;
  First: Integer;
  Wd: PWdArr;
  DW: Integer;
  CW: PRangeArr;
  NCW: Integer;
  TU: PRangeArr;
  NTU: Integer;
 End;
 TXObj = Record
  Name: String[63];
  Num: Integer;
  IsForm: Boolean;
 End;

Var
 Fonts: Array[0..FMAX-1] Of TFontRec;
 NFonts: Integer;
 XObjs: Array[0..XMAX-1] Of TXObj;
 NXObjs: Integer;

Procedure FreeFontsTo(Base: Integer);
Begin
 While NFonts > Base Do Begin
  Dec(NFonts);
  With Fonts[NFonts] Do Begin
   If Wd <> Nil Then FreeMem(Wd, SizeOf(TWdArr));
   If CW <> Nil Then FreeMem(CW, SizeOf(TRangeArr));
   If TU <> Nil Then FreeMem(TU, SizeOf(TRangeArr));
   Wd := Nil; CW := Nil; TU := Nil;
  End;
 End;
End;

Function W16(V: LongInt): Word;
Begin
 If V < 0 Then V := 0;
 If V > 65535 Then V := 65535;
 W16 := V;
End;

Procedure AddRange(Var Arr: PRangeArr; Var N: Integer; Lo, Hi, D1, D2: LongInt);
Begin
 If Arr = Nil Then GetMem(Arr, SizeOf(TRangeArr));
 If N >= 300 Then Exit;
 Arr^[N].Lo := W16(Lo); Arr^[N].Hi := W16(Hi); Arr^[N].Dst := W16(D1); Arr^[N].Dst2 := W16(D2);
 Inc(N);
End;

Function BEVal(Const S: String): LongInt;
Var
 I: Integer;
 V: LongInt;
Begin
 V := 0;
 For I := 1 To Length(S) Do Begin
  If I > 3 Then Break;
  V := V * 256 + Ord(S[I]);
 End;
 BEVal := V;
End;

Procedure ParseToUnicode(Var F: TFontRec);
Var
 P: LongInt;
 T, T2: Integer;
 Lo, Hi, D1, D2: LongInt;
 K: Integer;
 Procedure DstOf(Const S: String; Var A, B: LongInt);
 Begin
  A := 0; B := 0;
  If Length(S) >= 2 Then A := Ord(S[1]) * 256 + Ord(S[2])
  Else If Length(S) = 1 Then A := Ord(S[1]);
  If (Length(S) >= 4) And ((A < $D800) Or (A > $DBFF)) Then B := Ord(S[3]) * 256 + Ord(S[4]);
 End;
Begin
 SrcMode := 3;
 P := 0;
 While True Do Begin
  T := NextTok(P);
  If T = T_EOF Then Break;
  If T = T_OP Then Begin
   If TokS = 'beginbfchar' Then Begin
    While True Do Begin
     T := NextTok(P);
     If T <> T_STR Then Break;
     Lo := BEVal(TokS);
     T2 := NextTok(P);
     If T2 <> T_STR Then Break;
     DstOf(TokS, D1, D2);
     AddRange(F.TU, F.NTU, Lo, Lo, D1, D2);
    End;
   End
   Else If TokS = 'beginbfrange' Then Begin
    While True Do Begin
     T := NextTok(P);
     If T <> T_STR Then Break;
     Lo := BEVal(TokS);
     If NextTok(P) <> T_STR Then Break;
     Hi := BEVal(TokS);
     T2 := NextTok(P);
     If T2 = T_STR Then Begin
      DstOf(TokS, D1, D2);
      AddRange(F.TU, F.NTU, Lo, Hi, D1, D2);
     End
     Else If T2 = T_AB Then Begin
      K := 0;
      While True Do Begin
       T2 := NextTok(P);
       If T2 <> T_STR Then Break;
       DstOf(TokS, D1, D2);
       AddRange(F.TU, F.NTU, Lo + K, Lo + K, D1, D2);
       Inc(K);
      End;
     End
     Else Break;
    End;
   End;
  End;
 End;
End;

Procedure LoadCIDWidths(Var F: TFontRec; DescNum: Integer);
Var
 P, V, Q: LongInt;
 N: Integer;
 T: Integer;
 C1, C2: LongInt;
 W: LongInt;
 K: Integer;
Begin
 P := EnterObj(DescNum);
 If P < 0 Then Exit;
 F.DW := ValInt(DictFind(P, 'DW'), 1000);
 V := DictFind(P, 'W');
 If V < 0 Then Exit;
 N := RefAt(V);
 If N > 0 Then Begin
  V := EnterObj(N);
  If V < 0 Then Exit;
 End;
 Q := V;
 If NextTok(Q) <> T_AB Then Exit;
 While True Do Begin
  T := NextTok(Q);
  If T <> T_NUM Then Break;
  C1 := Round(TokR);
  T := NextTok(Q);
  If T = T_AB Then Begin
   K := 0;
   While True Do Begin
    T := NextTok(Q);
    If T <> T_NUM Then Break;
    AddRange(F.CW, F.NCW, C1 + K, C1 + K, Round(TokR), 0);
    Inc(K);
   End;
  End
  Else If T = T_NUM Then Begin
   C2 := Round(TokR);
   If NextTok(Q) <> T_NUM Then Break;
   W := Round(TokR);
   AddRange(F.CW, F.NCW, C1, C2, W, 0);
  End
  Else Break;
 End;
End;

Procedure LoadFont(Const Name: String; Num: Integer);
Var
 S: TSrcState;
 P, V, Q: LongInt;
 Sub, Base, LB: String;
 DescNum, TuNum, N, I, Cnt: Integer;
 Arr: Array[0..255] Of Real;
 TL: LongInt;
 F: ^TFontRec;
Begin
 If NFonts >= FMAX Then Exit;
 SaveSrc(S);
 P := EnterObj(Num);
 If P >= 0 Then Begin
  F := @Fonts[NFonts];
  FillChar(F^, SizeOf(TFontRec), 0);
  F^.Name := Name;
  F^.DW := 1000;
  Sub := ValName(DictFind(P, 'Subtype'));
  Base := ValName(DictFind(P, 'BaseFont'));
  LB := Base;
  For I := 1 To Length(LB) Do If (LB[I] >= 'A') And (LB[I] <= 'Z') Then LB[I] := Chr(Ord(LB[I]) + 32);
  If (Length(LB) > 7) And (LB[7] = '+') Then Delete(LB, 1, 7);
  F^.Fam := 0; F^.Style := 0;
  If (Pos('courier', LB) > 0) Or (Pos('mono', LB) > 0) Or (Pos('consol', LB) > 0) Then F^.Fam := 2
  Else If (Pos('times', LB) > 0) Or (Pos('serif', LB) > 0) And (Pos('sans', LB) = 0) Or (Pos('roman', LB) > 0) Or
          (Pos('georgia', LB) > 0) Or (Pos('cambria', LB) > 0) Or (Pos('garamond', LB) > 0) Or
          (Pos('minion', LB) > 0) Or (Pos('palatino', LB) > 0) Then F^.Fam := 1;
  If (Pos('bold', LB) > 0) Or (Pos('black', LB) > 0) Or (Pos('heavy', LB) > 0) Or (Pos('semibold', LB) > 0) Then F^.Style := F^.Style Or 1;
  If (Pos('italic', LB) > 0) Or (Pos('oblique', LB) > 0) Then F^.Style := F^.Style Or 2;
  DescNum := 0;
  TuNum := RefAt(DictFind(P, 'ToUnicode'));
  If Sub = 'Type0' Then Begin
   F^.Wide := True;
   V := DictFind(P, 'DescendantFonts');
   If V >= 0 Then Begin
    N := RefAt(V);
    If N > 0 Then V := EnterObj(N);
    If V >= 0 Then Begin
     Q := V;
     If NextTok(Q) = T_AB Then DescNum := RefAt(Q);
    End;
   End;
  End
  Else Begin
   F^.First := ValInt(DictFind(P, 'FirstChar'), 0);
   V := DictFind(P, 'Widths');
   If V >= 0 Then Begin
    N := RefAt(V);
    If N > 0 Then V := EnterObj(N);
    If V >= 0 Then Begin
     Cnt := ReadNums(V, Arr, 256);
     If Cnt > 0 Then Begin
      GetMem(F^.Wd, SizeOf(TWdArr));
      FillChar(F^.Wd^, SizeOf(TWdArr), 0);
      For I := 0 To Cnt - 1 Do F^.Wd^[I] := Round(Arr[I]);
      F^.HasWd := True;
      F^.DW := Cnt;
     End;
    End;
   End;
  End;
  RestoreSrc(S);
  If DescNum > 0 Then Begin
   LoadCIDWidths(F^, DescNum);
   RestoreSrc(S);
  End;
  If TuNum > 0 Then Begin
   SrcMode := 0;
   If LoadStream(TuNum, TuBuf, TL) Then Begin
    TuLen := TL;
    ParseToUnicode(F^);
   End;
  End;
  Inc(NFonts);
 End;
 RestoreSrc(S);
End;

Function FontIndex(Const Name: String): Integer;
Var
 I: Integer;
Begin
 FontIndex := -1;
 For I := NFonts - 1 DownTo 0 Do
  If Fonts[I].Name = Name Then Begin FontIndex := I; Exit; End;
End;

Function UniToStr(U: LongInt): String;
Begin
 Case U Of
  0..255: UniToStr := Chr(U);
  8216, 8217, 8218: UniToStr := '''';
  8220, 8221, 8222: UniToStr := '"';
  8211, 8212, 8722: UniToStr := '-';
  8226: UniToStr := #149;
  8230: UniToStr := '...';
  8364: UniToStr := #128;
  64256: UniToStr := 'ff';
  64257: UniToStr := 'fi';
  64258: UniToStr := 'fl';
  64259: UniToStr := 'ffi';
  64260: UniToStr := 'ffl';
  352: UniToStr := 'S'; 353: UniToStr := 's';
  338: UniToStr := 'OE'; 339: UniToStr := 'oe';
 Else UniToStr := '?';
 End;
End;

Function MapCode(Var F: TFontRec; Code: LongInt): String;
Var
 I: Integer;
 U: LongInt;
 R: String;
Begin
 If F.Wide Or (F.NTU > 0) Then Begin
  For I := 0 To F.NTU - 1 Do
   If (Code >= F.TU^[I].Lo) And (Code <= F.TU^[I].Hi) Then Begin
    U := F.TU^[I].Dst + (Code - F.TU^[I].Lo);
    R := UniToStr(U);
    If F.TU^[I].Dst2 <> 0 Then R := R + UniToStr(F.TU^[I].Dst2);
    MapCode := R;
    Exit;
   End;
  If F.Wide Then MapCode := '' Else If Code < 32 Then MapCode := '' Else MapCode := Chr(Code And 255);
  Exit;
 End;
 If Code < 32 Then MapCode := '' Else MapCode := Chr(Code And 255);
End;

Function GlyphW(Var F: TFontRec; Code: LongInt): Integer;
Var
 I: Integer;
Begin
 If F.Wide Then Begin
  For I := 0 To F.NCW - 1 Do
   If (Code >= F.CW^[I].Lo) And (Code <= F.CW^[I].Hi) Then Begin
    GlyphW := F.CW^[I].Dst;
    Exit;
   End;
  GlyphW := F.DW;
  Exit;
 End;
 If F.HasWd And (Code >= F.First) And (Code < F.First + F.DW) Then Begin
  If F.Wd^[Code - F.First] > 0 Then Begin GlyphW := F.Wd^[Code - F.First]; Exit; End;
 End;
 GlyphW := CharW(F.Fam, 0, Code And 255);
End;

{ Charge les polices et XObjects de la ressource "Resources" de l'objet Node. }
Function LoadResources(Node: Integer): Boolean;
Var
 S: TSrcState;
 P, V, R, Q, FD: LongInt;
 N, I, NP: Integer;
 Names: Array[0..FMAX-1] Of String[63];
 Nums: Array[0..FMAX-1] Of Integer;
 XNames: Array[0..XMAX-1] Of String[63];
 XNums: Array[0..XMAX-1] Of Integer;
 NX: Integer;
 T: Integer;
 Sub: String;
 SS: TSrcState;
 InRes: TSrcState;
Begin
 LoadResources := False;
 SaveSrc(S);
 P := EnterObj(Node);
 If P < 0 Then Begin RestoreSrc(S); Exit; End;
 V := DictFind(P, 'Resources');
 If V < 0 Then Begin RestoreSrc(S); Exit; End;
 N := RefAt(V);
 If N > 0 Then V := EnterObj(N);
 If V < 0 Then Begin RestoreSrc(S); Exit; End;
 R := V;
 SaveSrc(InRes);
 NP := 0;
 FD := DictFind(R, 'Font');
 If FD >= 0 Then Begin
  N := RefAt(FD);
  If N > 0 Then FD := EnterObj(N);
  If FD >= 0 Then Begin
   Q := FD;
   If NextTok(Q) = T_DB Then
    While NP < FMAX Do Begin
     T := NextTok(Q);
     If T <> T_NAME Then Break;
     Names[NP] := TokS;
     Nums[NP] := RefAt(Q);
     SkipValue(Q);
     If Nums[NP] > 0 Then Inc(NP);
    End;
  End;
 End;
 RestoreSrc(InRes);
 NX := 0;
 FD := DictFind(R, 'XObject');
 If FD >= 0 Then Begin
  N := RefAt(FD);
  If N > 0 Then FD := EnterObj(N);
  If FD >= 0 Then Begin
   Q := FD;
   If NextTok(Q) = T_DB Then
    While NX < XMAX Do Begin
     T := NextTok(Q);
     If T <> T_NAME Then Break;
     XNames[NX] := TokS;
     XNums[NX] := RefAt(Q);
     SkipValue(Q);
     If XNums[NX] > 0 Then Inc(NX);
    End;
  End;
 End;
 RestoreSrc(S);
 For I := 0 To NP - 1 Do LoadFont(Names[I], Nums[I]);
 For I := 0 To NX - 1 Do Begin
  If NXObjs >= XMAX Then Break;
  SaveSrc(SS);
  Q := EnterObj(XNums[I]);
  Sub := '';
  If Q >= 0 Then Sub := ValName(DictFind(Q, 'Subtype'));
  RestoreSrc(SS);
  XObjs[NXObjs].Name := XNames[I];
  XObjs[NXObjs].Num := XNums[I];
  XObjs[NXObjs].IsForm := Sub = 'Form';
  Inc(NXObjs);
 End;
 LoadResources := True;
End;
{$IFDEF FPC}
Const
 MAX_IMAGE_WIDTH = 12000;
 MAX_IMAGE_HEIGHT = 12000;
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
 If (D.Width<1) Or (D.Height<1) Or (D.Width>MAX_IMAGE_WIDTH) Or
    (D.Height>MAX_IMAGE_HEIGHT) Or Not (D.Components In [1,3,4]) Or
    (Limit-D.Position<>D.Components*3) Then Begin D.Bad:=True; Exit; End;
 D.Progressive:=Marker=$C2; D.MaxH:=1; D.MaxV:=1; Blocks:=0;
 For I:=0 To D.Components-1 Do With D.Component[I] Do Begin
  ID:=JDByte(D); Spec:=JDByte(D); H:=Spec Shr 4; V:=Spec And 15; TQ:=JDByte(D);
  If (H<1) Or (H>4) Or (V<1) Or (V>4) Or (TQ>3) Then Begin D.Bad:=True; Exit; End;
  For J:=0 To I-1 Do If ID=D.Component[J].ID Then Begin D.Bad:=True; Exit; End;
  Inc(Blocks,H*V); D.MaxH:=IMax(D.MaxH,H); D.MaxV:=IMax(D.MaxV,V);
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

Function JDDecodeMem(Src: Pointer; SrcSize: LongInt; Var Img: TJDImage): Boolean;
Var D: PJDState; M,I: Integer; L,Limit: LongInt;
    Ended: Boolean;
Begin
 JDDecodeMem:=False; FillChar(Img,SizeOf(Img),0);
 D:=PJDState(JDAllocate(SizeOf(TJDState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0); D^.AdobeTransform:=-1; Ended:=False;
 D^.Size:=SrcSize;
 If (D^.Size>=4) And (D^.Size<=134217728) Then Begin
  D^.Data:=PJDBytes(JDAllocate(D^.Size));
  If D^.Data<>Nil Then Move(Src^,D^.Data^,D^.Size) Else D^.Bad:=True;
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
 JDDecodeMem:=Not D^.Bad And Ended And D^.FrameFound And D^.ScanFound And (Img.Pixels<>Nil);
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


{$ENDIF}

{ ---------------------------------------------------------------------- }
{ Images : décodage (JPEG, Flate brut, palettes, masques)                   }
{ ---------------------------------------------------------------------- }

{$IFDEF FPC}
Const
 IMGMAXDIM = 384;
 IMGMAXBYTES = 100000000;

Type
 TBigBytes = Array[0..134217727] Of Byte;
 PBigBytes = ^TBigBytes;

Var
 IW, IH, IBpc, ICS, IComps, IPalBase, IRow: LongInt;
 IInv, IMaskImg, IJpeg: Boolean;
 IData: PBigBytes;
 IRGB: PBigBytes;
 IPal: Array[0..767] Of Byte;
 IPalN: Integer;
 IFlt: Array[0..3] Of String[24];
 INF, IPred, ICols, IClr: Integer;

{ Analyse d'un espace colorimétrique à la position V }
Function ParseCS(V: LongInt; Depth: Integer; Var CS, Comps, PalBase: LongInt): Boolean;
Var
 S: TSrcState;
 N, T, Hi, K: Integer;
 Q, Q2, P2: LongInt;
 Nm: String;
 BCS, BC, BP: LongInt;
 L: LongInt;
Begin
 ParseCS := False;
 If (V < 0) Or (Depth > 3) Then Exit;
 SaveSrc(S);
 N := RefAt(V);
 If N > 0 Then V := EnterObj(N);
 If V < 0 Then Begin RestoreSrc(S); Exit; End;
 Q := V;
 T := NextTok(Q);
 If T = T_NAME Then Begin
  Nm := TokS;
  If (Nm = 'DeviceGray') Or (Nm = 'G') Or (Nm = 'CalGray') Then Begin CS := 1; Comps := 1; ParseCS := True; End
  Else If (Nm = 'DeviceRGB') Or (Nm = 'RGB') Or (Nm = 'CalRGB') Then Begin CS := 3; Comps := 3; ParseCS := True; End
  Else If (Nm = 'DeviceCMYK') Or (Nm = 'CMYK') Then Begin CS := 4; Comps := 4; ParseCS := True; End;
 End
 Else If T = T_AB Then Begin
  T := NextTok(Q);
  Nm := TokS;
  If T = T_NAME Then Begin
   If (Nm = 'DeviceGray') Or (Nm = 'CalGray') Then Begin CS := 1; Comps := 1; ParseCS := True; End
   Else If (Nm = 'DeviceRGB') Or (Nm = 'CalRGB') Or (Nm = 'Lab') Then Begin CS := 3; Comps := 3; ParseCS := True; End
   Else If Nm = 'DeviceCMYK' Then Begin CS := 4; Comps := 4; ParseCS := True; End
   Else If Nm = 'ICCBased' Then Begin
    N := RefAt(Q);
    If N > 0 Then Begin
     P2 := EnterObj(N);
     If P2 >= 0 Then Begin
      K := ValInt(DictFind(P2, 'N'), 3);
      If K = 1 Then CS := 1 Else If K = 4 Then CS := 4 Else CS := 3;
      Comps := K;
      If K = 1 Then Comps := 1 Else If K = 4 Then Comps := 4 Else Comps := 3;
      ParseCS := True;
     End;
    End;
   End
   Else If Nm = 'Separation' Then Begin CS := 6; Comps := 1; ParseCS := True; End
   Else If (Nm = 'Indexed') Or (Nm = 'I') Then Begin
    Q2 := Q;
    If ParseCS(Q2, Depth + 1, BCS, BC, BP) And (BCS <> 5) And (BCS <> 6) Then Begin
     SkipValue(Q);
     If NextTok(Q) = T_NUM Then Begin
      Hi := Round(TokR);
      If Hi > 255 Then Hi := 255;
      N := RefAt(Q);
      IPalN := 0;
      If N > 0 Then Begin
       SkipValue(Q);
       SrcMode := 0;
       If LoadStream(N, TuBuf, L) Then Begin
        K := L;
        If K > 768 Then K := 768;
        Move(TuBuf^[0], IPal[0], K);
        IPalN := K;
       End;
      End
      Else If NextTok(Q) = T_STR Then Begin
       K := StrLen;
       If K > 768 Then K := 768;
       Move(StrBuf[0], IPal[0], K);
       IPalN := K;
      End;
      If IPalN > 0 Then Begin CS := 5; Comps := 1; PalBase := BC; ParseCS := True; End;
     End;
    End;
   End;
  End;
 End;
 RestoreSrc(S);
End;

{ Lecture du flux brut (encore encodé) de l'objet en P }
Function ReadRawStream(P: LongInt; Var Raw: Pointer; Var RawLen: LongInt): Boolean;
Var
 V, Q, DStart, Len, Done, ToRead: LongInt;
 LenVal: LongInt;
 Got: Word;
 Buf: PBigBytes;
Begin
 ReadRawStream := False;
 Raw := Nil;
 RawLen := 0;
 SrcMode := 0;
 V := DictFind(P, 'Length');
 LenVal := -1;
 If V >= 0 Then LenVal := ValInt(V, -1);
 SrcMode := 0;
 Q := P;
 SkipValue(Q);
 If NextTok(Q) <> T_OP Then Exit;
 If TokS <> 'stream' Then Exit;
 DStart := Q;
 If Not FindStreamData(DStart, Len, LenVal) Then Exit;
 If (Len < 1) Or (Len > IMGMAXBYTES) Then Exit;
 GetMem(Buf, Len + 16);
 Seek(PF, DStart);
 Done := 0;
 While Done < Len Do Begin
  ToRead := Len - Done;
  If ToRead > 32768 Then ToRead := 32768;
  Got := 0;
  BlockRead(PF, Buf^[Done], ToRead, Got);
  If Got = 0 Then Break;
  Done := Done + Got;
 End;
 RBase := -1; RLen := 0;
 If Done < 1 Then Begin FreeMem(Buf, Len + 16); Exit; End;
 Raw := Buf;
 RawLen := Done;
 ReadRawStream := True;
End;

Procedure ReadFiltersAndParms(P: LongInt);
Var
 V, Q, Pos0, DP: LongInt;
 T: Integer;
Begin
 INF := 0; IPred := 1; ICols := 1; IClr := 1;
 SrcMode := 0;
 V := DictFind(P, 'Filter');
 If V < 0 Then V := DictFind(P, 'F');
 If V >= 0 Then Begin
  Q := V;
  T := NextTok(Q);
  If T = T_NAME Then Begin IFlt[0] := TokS; INF := 1; End
  Else If T = T_AB Then
   While INF < 4 Do Begin
    T := NextTok(Q);
    If T = T_NAME Then Begin IFlt[INF] := TokS; Inc(INF); End Else Break;
   End;
 End;
 V := DictFind(P, 'DecodeParms');
 If V < 0 Then V := DictFind(P, 'DP');
 If V >= 0 Then Begin
  DP := -1;
  Q := V;
  Pos0 := Q;
  T := NextTok(Q);
  If T = T_DB Then DP := Pos0
  Else If T = T_AB Then
   While True Do Begin
    Pos0 := Q;
    T := NextTok(Q);
    If T = T_DB Then Begin DP := Pos0; Q := Pos0; SkipValue(Q); End
    Else If (T = T_AE) Or (T = T_EOF) Then Break;
   End;
  If DP >= 0 Then Begin
   IPred := ValInt(DictFind(DP, 'Predictor'), 1);
   ICols := ValInt(DictFind(DP, 'Columns'), 1);
   IClr := ValInt(DictFind(DP, 'Colors'), 1);
  End;
 End;
End;

{ Annule le filtre de prédiction PNG : retourne un nouveau tampon }
Function Unpredict(Src: PBigBytes; SLen: LongInt; RowBytes, Rows, Bpp: LongInt): PBigBytes;
Var
 Dst: PBigBytes;
 Y, X, Pos: LongInt;
 Ft, A, B, C, Pa, Pb, Pc, Px: Integer;
Begin
 GetMem(Dst, RowBytes * Rows + 16);
 FillChar(Dst^, RowBytes * Rows, 0);
 Pos := 0;
 For Y := 0 To Rows - 1 Do Begin
  If Pos >= SLen Then Break;
  Ft := Src^[Pos]; Inc(Pos);
  For X := 0 To RowBytes - 1 Do Begin
   If Pos >= SLen Then Break;
   Px := Src^[Pos]; Inc(Pos);
   If X >= Bpp Then A := Dst^[Y * RowBytes + X - Bpp] Else A := 0;
   If Y > 0 Then B := Dst^[(Y - 1) * RowBytes + X] Else B := 0;
   If (Y > 0) And (X >= Bpp) Then C := Dst^[(Y - 1) * RowBytes + X - Bpp] Else C := 0;
   Case Ft Of
    1: Px := Px + A;
    2: Px := Px + B;
    3: Px := Px + (A + B) Div 2;
    4: Begin
     Pa := Abs(B - C); Pb := Abs(A - C); Pc := Abs(A + B - 2 * C);
     If (Pa <= Pb) And (Pa <= Pc) Then Px := Px + A
     Else If Pb <= Pc Then Px := Px + B
     Else Px := Px + C;
    End;
   End;
   Dst^[Y * RowBytes + X] := Px And 255;
  End;
 End;
 Unpredict := Dst;
End;

{ Échantillon brut -> RVB }
Procedure SampleRaw(X, Y: LongInt; Var R, G, B: Integer);
Var
 C: Integer;
 V: Array[0..3] Of Integer;
 BitPos, Mx: LongInt;
 Idx: Integer;
Begin
 For C := 0 To IComps - 1 Do Begin
  If IBpc = 8 Then V[C] := IData^[Y * IRow + X * IComps + C]
  Else If IBpc = 16 Then V[C] := IData^[Y * IRow + (X * IComps + C) * 2]
  Else Begin
   BitPos := (X * IComps + C) * IBpc;
   Mx := (1 Shl IBpc) - 1;
   V[C] := (IData^[Y * IRow + (BitPos Shr 3)] Shr (8 - IBpc - (BitPos And 7))) And Mx;
   If ICS <> 5 Then V[C] := V[C] * 255 Div Mx;
  End;
 End;
 If IInv And (ICS <> 5) Then For C := 0 To IComps - 1 Do V[C] := 255 - V[C];
 Case ICS Of
  1: Begin R := V[0]; G := V[0]; B := V[0]; End;
  6: Begin R := 255 - V[0]; G := R; B := R; End;
  3: Begin R := V[0]; G := V[1]; B := V[2]; End;
  4: Begin
   R := (255 - V[0]) * (255 - V[3]) Div 255;
   G := (255 - V[1]) * (255 - V[3]) Div 255;
   B := (255 - V[2]) * (255 - V[3]) Div 255;
  End;
 Else
  Begin
   Idx := V[0];
   If (Idx * IPalBase + IPalBase - 1) < IPalN Then Begin
    If IPalBase = 1 Then Begin R := IPal[Idx]; G := R; B := R; End
    Else If IPalBase = 3 Then Begin R := IPal[Idx * 3]; G := IPal[Idx * 3 + 1]; B := IPal[Idx * 3 + 2]; End
    Else Begin
     R := (255 - IPal[Idx * 4]) * (255 - IPal[Idx * 4 + 3]) Div 255;
     G := (255 - IPal[Idx * 4 + 1]) * (255 - IPal[Idx * 4 + 3]) Div 255;
     B := (255 - IPal[Idx * 4 + 2]) * (255 - IPal[Idx * 4 + 3]) Div 255;
    End;
   End
   Else Begin R := 0; G := 0; B := 0; End;
  End;
 End;
End;

Procedure SampleJpeg(X, Y: LongInt; Var R, G, B: Integer);
Var
 O: LongInt;
Begin
 O := (Y * IW + X) * 3;
 R := IRGB^[O]; G := IRGB^[O + 1]; B := IRGB^[O + 2];
End;


Type
 TWordsBig = Array[0..67108863] Of Word;
 PWordsBig = ^TWordsBig;

Procedure FreeImages;
Var
 I: Integer;
Begin
 For I := 1 To ImgCount Do Begin
  If ImgP(I)^.Pix <> Nil Then FreeMem(ImgP(I)^.Pix, LongInt(ImgP(I)^.W) * ImgP(I)^.H * 2);
  If ImgP(I)^.Alpha <> Nil Then FreeMem(ImgP(I)^.Alpha, LongInt(ImgP(I)^.W) * ImgP(I)^.H);
  If ImgP(I)^.Raw <> Nil Then FreeMem(ImgP(I)^.Raw, ImgP(I)^.RawLen + 16);
  If ImgP(I)^.Pal <> Nil Then FreeMem(ImgP(I)^.Pal, ImgP(I)^.PalN);
 End;
 ImgListFree;
End;

{ Réduit l'image courante (contexte I*) à au plus IMGMAXDIM pixels }
Procedure Downsample(Var TW_, TH_: LongInt; Var Pix: PWordsBig; Var Alpha: PBigBytes);
Var
 X, Y, I, J, NX, NY, X0, X1, Y0, Y1, SX, SY, Cnt: LongInt;
 SR, SG, SB: LongInt;
 R, G, B: Integer;
Begin
 If IW >= IH Then Begin
  TW_ := IMin(IW, IMGMAXDIM);
  TH_ := IMax(1, (IH * TW_) Div IW);
 End
 Else Begin
  TH_ := IMin(IH, IMGMAXDIM);
  TW_ := IMax(1, (IW * TH_) Div IH);
 End;
 NX := IMin(3, IMax(1, (IW + TW_ - 1) Div TW_));
 NY := IMin(3, IMax(1, (IH + TH_ - 1) Div TH_));
 Pix := Nil; Alpha := Nil;
 If IMaskImg Then Begin
  GetMem(Alpha, TW_ * TH_);
 End
 Else GetMem(Pix, TW_ * TH_ * 2);
 For Y := 0 To TH_ - 1 Do Begin
  Y0 := (Y * IH) Div TH_;
  Y1 := IMax(Y0, ((Y + 1) * IH) Div TH_ - 1);
  For X := 0 To TW_ - 1 Do Begin
   X0 := (X * IW) Div TW_;
   X1 := IMax(X0, ((X + 1) * IW) Div TW_ - 1);
   SR := 0; SG := 0; SB := 0; Cnt := 0;
   For J := 0 To NY - 1 Do Begin
    SY := Y0 + ((Y1 - Y0 + 1) * J) Div NY;
    For I := 0 To NX - 1 Do Begin
     SX := X0 + ((X1 - X0 + 1) * I) Div NX;
     If IJpeg Then SampleJpeg(SX, SY, R, G, B) Else SampleRaw(SX, SY, R, G, B);
     SR := SR + R; SG := SG + G; SB := SB + B; Inc(Cnt);
    End;
   End;
   If IMaskImg Then Alpha^[Y * TW_ + X] := 255 - SG Div Cnt
   Else Begin
    R := SR Div Cnt; G := SG Div Cnt; B := SB Div Cnt;
    Pix^[Y * TW_ + X] := ((R And $F8) Shl 8) Or ((G And $FC) Shl 3) Or (B Shr 3);
   End;
  End;
 End;
End;

Function ImportImageObj(Num: Integer; AsSM: Boolean): Integer;
Var
 S0: TSrcState;
 P, V: LongInt;
 W, H, Bpc, CS, Comps, PalBase, RowBytes, Exp, CurLen, OutLen, TW_, TH_: LongInt;
 IsMask, Ok, Unsup, FinalDCT, Keep, Owned: Boolean;
 Raw: Pointer;
 RawLen: LongInt;
 Dec: Array[0..7] Of Real;
 ND, K, SMNum, Idx, M: Integer;
 Cur, Tmp, Pred: PBigBytes;
 Pix: PWordsBig;
 Alpha: PBigBytes;
 DecStr, Nm: String;
 Ji: TJDImage;
 X, Y: LongInt;
 AA: PBigBytes;
 SW, SH: LongInt;
Begin
 ImportImageObj := 0;
 If (Num < 1) Or (Num > MAXPDFOBJ) Then Exit;
 If ImgByObj^[Num] <> 0 Then Begin
  If ImgByObj^[Num] <> 65535 Then ImportImageObj := ImgByObj^[Num];
  Exit;
 End;
 If ImgCount >= MAXIMG Then Exit;
 ImgByObj^[Num] := 65535;
 SaveSrc(S0);
 SrcMode := 0;
 P := EnterObj(Num);
 If (P < 0) Or (SrcMode <> 0) Then Begin RestoreSrc(S0); Exit; End;
 W := ValInt(DictFind(P, 'Width'), 0);
 H := ValInt(DictFind(P, 'Height'), 0);
 If (W < 1) Or (H < 1) Or (W > 30000) Or (H > 30000) Or (W * H > 150000000) Then Begin RestoreSrc(S0); Exit; End;
 IsMask := False;
 V := DictFind(P, 'ImageMask');
 If V >= 0 Then If NextTok(V) = T_OP Then IsMask := TokS = 'true';
 Bpc := ValInt(DictFind(P, 'BitsPerComponent'), 8);
 If IsMask Then Bpc := 1;
 CS := 0; Comps := 0; PalBase := 0; IPalN := 0;
 If IsMask Then Begin CS := 1; Comps := 1; End
 Else If Not ParseCS(DictFind(P, 'ColorSpace'), 0, CS, Comps, PalBase) Then CS := 0;
 SrcMode := 0;
 P := EnterObj(Num);
 ND := ReadNums(DictFind(P, 'Decode'), Dec, 8);
 DecStr := '';
 For K := 0 To ND - 1 Do Begin
  If K > 0 Then DecStr := DecStr + ' ';
  DecStr := DecStr + RStr(Dec[K]);
 End;
 IInv := (ND >= 2) And (Dec[0] > Dec[1]);
 ReadFiltersAndParms(P);
 SMNum := 0;
 V := DictFind(P, 'SMask');
 If V >= 0 Then SMNum := RefAt(V);
 Ok := ReadRawStream(P, Raw, RawLen);
 RestoreSrc(S0);
 If Not Ok Then Exit;
 If (Bpc <> 1) And (Bpc <> 2) And (Bpc <> 4) And (Bpc <> 8) And (Bpc <> 16) Then Bpc := 8;
 { chaîne de filtres admise pour la réécriture ? }
 Keep := (CS In [1, 3, 4, 5]) Or IsMask;
 For K := 0 To INF - 1 Do Begin
  Nm := IFlt[K];
  If Not ((Nm = 'FlateDecode') Or (Nm = 'DCTDecode') Or (Nm = 'ASCII85Decode') Or (Nm = 'ASCIIHexDecode')) Then Keep := False;
 End;
 Cur := PBigBytes(Raw); CurLen := RawLen; Owned := False;
 FinalDCT := False; Unsup := False;
 Pred := Nil;
 For K := 0 To INF - 1 Do Begin
  Nm := IFlt[K];
  If (Nm = 'DCTDecode') Or (Nm = 'DCT') Then Begin FinalDCT := True; Break; End
  Else If (Nm = 'FlateDecode') Or (Nm = 'Fl') Then Begin
   If CS = 0 Then Exp := W * H * 4 + H Else Begin
    RowBytes := (W * Comps * Bpc + 7) Div 8;
    Exp := RowBytes * H;
    If IPred >= 10 Then Exp := Exp + H;
   End;
   If Exp > IMGMAXBYTES Then Begin Unsup := True; Break; End;
   GetMem(Tmp, Exp + 64);
   FillChar(Tmp^, Exp + 64, 0);
   DecCap := Exp + 64;
   Ok := FlateDec(PByteBuf(Cur), CurLen, PByteBuf(Tmp), OutLen);
   DecCap := BUFSZ;
   If Owned Then FreeMem(Cur, CurLen + 64);
   If (Not Ok) Or (OutLen < 1) Then Begin FreeMem(Tmp, Exp + 64); Cur := Nil; Owned := False; Unsup := True; Break; End;
   Cur := Tmp; CurLen := Exp; Owned := True;
   { la taille libérée plus tard : on garde CurLen = Exp (+64 à la libération) }
  End
  Else If (Nm = 'ASCII85Decode') Or (Nm = 'A85') Or (Nm = 'ASCIIHexDecode') Or (Nm = 'AHx') Then Begin
   GetMem(Tmp, CurLen + 64);
   DecCap := CurLen + 64;
   If (Nm = 'ASCII85Decode') Or (Nm = 'A85') Then A85Dec(PByteBuf(Cur), CurLen, PByteBuf(Tmp), OutLen)
   Else AHexDec(PByteBuf(Cur), CurLen, PByteBuf(Tmp), OutLen);
   DecCap := BUFSZ;
   If Owned Then FreeMem(Cur, CurLen + 64);
   Cur := Tmp; CurLen := OutLen; Owned := True;
   { rétablir une taille cohérente pour FreeMem : on réalloue exactement }
   If CurLen < 1 Then Begin Unsup := True; Break; End;
  End
  Else Begin Unsup := True; Break; End;
 End;
 TW_ := 0; TH_ := 0; Pix := Nil; Alpha := Nil;
 IJpeg := False; IRGB := Nil; IMaskImg := IsMask;
 If Not Unsup Then Begin
  If FinalDCT Then Begin
   FillChar(Ji, SizeOf(Ji), 0);
   If JDDecodeMem(Cur, CurLen, Ji) And (Ji.Pixels <> Nil) Then Begin
    IW := Ji.Width; IH := Ji.Height;
    IRGB := PBigBytes(Ji.Pixels);
    IJpeg := True;
    IMaskImg := False;
    Downsample(TW_, TH_, Pix, Alpha);
    FreeMem(Ji.Pixels, LongInt(Ji.Width) * Ji.Height * 3);
    IRGB := Nil;
   End
   Else Unsup := True;
  End
  Else Begin
   If CS = 0 Then Begin
    If Bpc = 8 Then Begin
     If IPred >= 10 Then Comps := (CurLen Div H - 1) Div W Else Comps := CurLen Div (W * H);
     If Comps = 1 Then CS := 1 Else If Comps = 3 Then CS := 3 Else If Comps = 4 Then CS := 4 Else CS := 0;
    End;
   End;
   If CS = 0 Then Unsup := True
   Else Begin
    RowBytes := (W * Comps * Bpc + 7) Div 8;
    If IPred >= 10 Then Begin
     Pred := Unpredict(Cur, CurLen, RowBytes, H, IMax(1, (Comps * Bpc) Div 8));
     IData := Pred;
    End
    Else Begin
     IData := Cur;
     If CurLen < RowBytes * H Then Unsup := True;
    End;
    If Not Unsup Then Begin
     IW := W; IH := H; IBpc := Bpc; ICS := CS; IComps := Comps; IRow := RowBytes; IPalBase := PalBase;
     If IsMask Then ICS := 1;
     If (CS = 5) And (IPalN < 1) Then Unsup := True
     Else Downsample(TW_, TH_, Pix, Alpha);
    End;
   End;
  End;
 End;
 If Owned And (Cur <> Nil) Then FreeMem(Cur, CurLen + 64);
 If Pred <> Nil Then FreeMem(Pred, RowBytes * H + 16);
 If Unsup Then Begin
  { affichage impossible : conserver seulement si la réécriture est possible }
  If Not Keep Then Begin FreeMem(Raw, RawLen + 16); Exit; End;
  TW_ := 0; TH_ := 0;
 End;
 { masque doux }
 If (SMNum > 0) And (Not AsSM) And (Pix <> Nil) Then Begin
  M := ImportImageObj(SMNum, True);
  If M > 0 Then If ImgP(M)^.Pix <> Nil Then Begin
   GetMem(Alpha, TW_ * TH_);
   SW := ImgP(M)^.W; SH := ImgP(M)^.H;
   For Y := 0 To TH_ - 1 Do
    For X := 0 To TW_ - 1 Do
     Alpha^[Y * TW_ + X] := ((PWordsBig(ImgP(M)^.Pix)^[((Y * SH) Div TH_) * SW + (X * SW) Div TW_] Shr 5) And 63) * 4;
  End;
 End
 Else If (SMNum > 0) And (Not AsSM) Then M := ImportImageObj(SMNum, True) Else M := 0;
 If ImgCount >= MAXIMG Then Begin
  If Pix <> Nil Then FreeMem(Pix, TW_ * TH_ * 2);
  If Alpha <> Nil Then FreeMem(Alpha, TW_ * TH_);
  FreeMem(Raw, RawLen + 16);
  Exit;
 End;
 If Not ImgEnsure(ImgCount + 1) Then Begin
  If Pix <> Nil Then FreeMem(Pix, TW_ * TH_ * 2);
  If Alpha <> Nil Then FreeMem(Alpha, TW_ * TH_);
  FreeMem(Raw, RawLen + 16);
  Exit;
 End;
 Inc(ImgCount);
 Idx := ImgCount;
 FillChar(ImgP(Idx)^, SizeOf(TImgRec), 0);
 ImgP(Idx)^.W := TW_; ImgP(Idx)^.H := TH_;
 ImgP(Idx)^.Pix := Pix; ImgP(Idx)^.Alpha := Alpha;
 ImgP(Idx)^.OW := W; ImgP(Idx)^.OH := H;
 If Keep Then Begin ImgP(Idx)^.Raw := Raw; ImgP(Idx)^.RawLen := RawLen; End
 Else FreeMem(Raw, RawLen + 16);
 ImgP(Idx)^.Keep := Keep;
 ImgP(Idx)^.CS := CS; ImgP(Idx)^.BPC := Bpc; ImgP(Idx)^.NF := INF;
 For K := 0 To INF - 1 Do ImgP(Idx)^.Flt[K] := IFlt[K];
 ImgP(Idx)^.Pred := IPred; ImgP(Idx)^.Cols := ICols; ImgP(Idx)^.Clr := IClr;
 ImgP(Idx)^.Mask := IsMask; ImgP(Idx)^.IsSM := AsSM;
 ImgP(Idx)^.SMIdx := M;
 ImgP(Idx)^.Decode := DecStr;
 If (CS = 5) And (IPalN > 0) Then Begin
  GetMem(ImgP(Idx)^.Pal, IPalN);
  Move(IPal[0], ImgP(Idx)^.Pal^, IPalN);
  ImgP(Idx)^.PalN := IPalN;
  ImgP(Idx)^.PalBase := PalBase;
 End;
 ImgByObj^[Num] := Idx;
 ImportImageObj := Idx;
End;
{$ELSE}
Procedure FreeImages;
Begin
End;

Function ImportImageObj(Num: Integer; AsSM: Boolean): Integer;
Begin
 ImportImageObj := 0;
End;
{$ENDIF}

{ ---------------------------------------------------------------------- }
{ Import PDF : interprétation des flux de contenu                           }
{ ---------------------------------------------------------------------- }

Const
 GSMAX = 28;
 SUBMAX = 400;
 {$IFDEF FPC}
 PATHMAX = 4000;
 {$ELSE}
 PATHMAX = 300;
 {$ENDIF}

Type
 TMat = Array[0..5] Of Real;
 TGS = Record
  CTM: TMat;
  Stroke, Fill: LongInt;
  LW: Real;
  Tc, Tw, Th, TL, Ts, TSize: Real;
  TFont, TMode: Integer;
 End;

Var
 GS: TGS;
 GStack: Array[0..GSMAX-1] Of TGS;
 GSP: Integer;
 TmM, TlmM: TMat;
 PathX, PathY: Array[0..PATHMAX-1] Of Real;
 NPts, NSub: Integer;
 SubStart: Array[0..SUBMAX-1] Of Integer;
 SubClosed, SubRect: Array[0..SUBMAX-1] Of Boolean;
 Opnd: Array[0..39] Of Real;
 NOpnd: Integer;
 LastName, LastStr: String;
 ImpPg: Integer;
 ImpSrcKind: Integer;
 ImpAnnNum: LongInt;
 ImpKeepSrc: Boolean;
 MbX0, MbY1: Real;
 ImpFull: Boolean;
 CLens: Array[0..3] Of LongInt;
 SkippedText: Integer;
 KidStack: Array[0..65535] Of Word;
 KidSP: Integer;

Procedure MatMul(Const A, B: TMat; Var R: TMat);
Var
 T: TMat;
Begin
 T[0] := A[0] * B[0] + A[1] * B[2];
 T[1] := A[0] * B[1] + A[1] * B[3];
 T[2] := A[2] * B[0] + A[3] * B[2];
 T[3] := A[2] * B[1] + A[3] * B[3];
 T[4] := A[4] * B[0] + A[5] * B[2] + B[4];
 T[5] := A[4] * B[1] + A[5] * B[3] + B[5];
 R := T;
End;

Procedure MatIdent(Var M: TMat);
Begin
 M[0] := 1; M[1] := 0; M[2] := 0; M[3] := 1; M[4] := 0; M[5] := 0;
End;

Function RI(R: Real): LongInt;
Begin
 If R > 1000000.0 Then R := 1000000.0;
 If R < -1000000.0 Then R := -1000000.0;
 RI := Round(R);
End;

Function PgX(X: Real): LongInt;
Begin
 PgX := C16(RI(X - MbX0));
End;

Function PgY(Y: Real): LongInt;
Begin
 PgY := C16(RI(MbY1 - Y));
End;

Function GrayRgb(G: Real): LongInt;
Begin
 GrayRgb := RGBOf(RI(G * 255), RI(G * 255), RI(G * 255));
End;

Function CmykRgb(C, M, Y, K: Real): LongInt;
Begin
 CmykRgb := RGBOf(RI(255 * (1 - C) * (1 - K)), RI(255 * (1 - M) * (1 - K)), RI(255 * (1 - Y) * (1 - K)));
End;

Var
 AnnSet: PByteBuf;
 AnnSetCap: LongInt;

{ Ensemble des numéros d'annotations d'origine importées dans le modèle }
Procedure AnnSetMark(N: LongInt);
Var
 P: Pointer;
 NewCap: LongInt;
Begin
 If N + 1 > AnnSetCap Then Begin
  NewCap := AnnSetCap * 2;
  If NewCap < N + 1024 Then NewCap := N + 1024;
  P := AnnSet; ReAllocMem(P, NewCap); AnnSet := P;
  FillChar(AnnSet^[AnnSetCap], NewCap - AnnSetCap, 0);
  AnnSetCap := NewCap;
 End;
 AnnSet^[N] := 1;
End;

Function AnnSetHas(N: LongInt): Boolean;
Begin
 AnnSetHas := (N >= 0) And (N < AnnSetCap) And (AnnSet^[N] <> 0);
End;

Function NewImpObj(Kind: Integer): Integer;
Var
 I: Integer;
Begin
 I := NewObj(Kind, ImpPg);
 If I < 0 Then Begin
  ImpFull := True;
  LoadNotice := 'Document tronqué : mémoire insuffisante.';
 End
 Else Begin
  If ImpKeepSrc Then ObjP(I)^.Src := ImpSrcKind Else ObjP(I)^.Src := 0;
  ObjP(I)^.SrcNum := ImpAnnNum;
 End;
 NewImpObj := I;
End;

Procedure PushGS;
Begin
 If GSP < GSMAX Then Begin
  GStack[GSP] := GS;
  Inc(GSP);
 End;
End;

Procedure PopGS;
Begin
 If GSP > 0 Then Begin
  Dec(GSP);
  GS := GStack[GSP];
 End;
End;

Procedure AddPt(X, Y: Real);
Begin
 If NPts >= PATHMAX Then Exit;
 PathX[NPts] := GS.CTM[0] * X + GS.CTM[2] * Y + GS.CTM[4];
 PathY[NPts] := GS.CTM[1] * X + GS.CTM[3] * Y + GS.CTM[5];
 Inc(NPts);
End;

Procedure NewSub;
Begin
 If NSub >= SUBMAX Then Exit;
 SubStart[NSub] := NPts;
 SubClosed[NSub] := False;
 SubRect[NSub] := False;
 Inc(NSub);
End;

Procedure CurveTo(X1, Y1, X2, Y2, X3, Y3: Real);
Var
 SX, SY, AX, AY, BX, BY, CX, CY, T, U: Real;
 I: Integer;
 P1X, P1Y, P2X, P2Y, P3X, P3Y: Real;
Begin
 If NPts = 0 Then Exit;
 SX := PathX[NPts - 1]; SY := PathY[NPts - 1];
 P1X := GS.CTM[0] * X1 + GS.CTM[2] * Y1 + GS.CTM[4]; P1Y := GS.CTM[1] * X1 + GS.CTM[3] * Y1 + GS.CTM[5];
 P2X := GS.CTM[0] * X2 + GS.CTM[2] * Y2 + GS.CTM[4]; P2Y := GS.CTM[1] * X2 + GS.CTM[3] * Y2 + GS.CTM[5];
 P3X := GS.CTM[0] * X3 + GS.CTM[2] * Y3 + GS.CTM[4]; P3Y := GS.CTM[1] * X3 + GS.CTM[3] * Y3 + GS.CTM[5];
 For I := 1 To 10 Do Begin
  T := I / 10; U := 1 - T;
  AX := U * U * U * SX + 3 * U * U * T * P1X + 3 * U * T * T * P2X + T * T * T * P3X;
  AY := U * U * U * SY + 3 * U * U * T * P1Y + 3 * U * T * T * P2Y + T * T * T * P3Y;
  If NPts < PATHMAX Then Begin PathX[NPts] := AX; PathY[NPts] := AY; Inc(NPts); End;
 End;
End;

Function StrokeW: Integer;
Var
 Det: Real;
 W: LongInt;
Begin
 Det := Abs(GS.CTM[0] * GS.CTM[3] - GS.CTM[1] * GS.CTM[2]);
 W := RI(GS.LW * Sqrt(Det));
 If W < 1 Then W := 1;
 If W > 40 Then W := 40;
 StrokeW := W;
End;

Procedure EmitPath(DoFill, DoStroke, Close: Boolean);
Var
 K, S, E, N, I, Idx, Pool: Integer;
 MnX, MnY, MxX, MxY: Real;
 IsRect, Closed: Boolean;
 Tol: Real;
Begin
 For K := 0 To NSub - 1 Do Begin
  If ImpFull Then Break;
  S := SubStart[K];
  If K < NSub - 1 Then E := SubStart[K + 1] - 1 Else E := NPts - 1;
  N := E - S + 1;
  If N < 2 Then Continue;
  Closed := SubClosed[K] Or Close;
  MnX := PathX[S]; MxX := MnX; MnY := PathY[S]; MxY := MnY;
  For I := S To E Do Begin
   If PathX[I] < MnX Then MnX := PathX[I];
   If PathX[I] > MxX Then MxX := PathX[I];
   If PathY[I] < MnY Then MnY := PathY[I];
   If PathY[I] > MxY Then MxY := PathY[I];
  End;
  IsRect := False;
  If SubRect[K] And (N = 4) Then Begin
   Tol := 0.02 * (MxX - MnX + MxY - MnY) + 0.01;
   IsRect := True;
   For I := S To E Do
    If Not (((Abs(PathX[I] - MnX) < Tol) Or (Abs(PathX[I] - MxX) < Tol)) And
            ((Abs(PathY[I] - MnY) < Tol) Or (Abs(PathY[I] - MxY) < Tol))) Then IsRect := False;
  End;
  If IsRect Then Begin
   Idx := NewImpObj(K_RECT);
   If Idx < 0 Then Exit;
   With ObjP(Idx)^ Do Begin
    X1 := PgX(MnX); X2 := PgX(MxX); Y1 := PgY(MxY); Y2 := PgY(MnY);
    Wd := StrokeW;
    Rgb := GS.Stroke; Rgb2 := GS.Fill;
    If DoFill And DoStroke Then Fill := 2
    Else If DoFill Then Begin Fill := 1; Rgb := GS.Fill; End
    Else Fill := 0;
   End;
  End
  Else If (N = 2) And DoStroke And (Not DoFill) Then Begin
   Idx := NewImpObj(K_LINE);
   If Idx < 0 Then Exit;
   With ObjP(Idx)^ Do Begin
    X1 := PgX(PathX[S]); Y1 := PgY(PathY[S]);
    X2 := PgX(PathX[E]); Y2 := PgY(PathY[E]);
    Wd := StrokeW;
    Rgb := GS.Stroke;
   End;
  End
  Else If (DoFill Or DoStroke) Then Begin
   If N > 1500 Then N := 1500;
   Pool := PoolAlloc(N);
   If Pool < 0 Then Begin ImpFull := True; LoadNotice := 'Document tronqué : mémoire des tracés pleine.'; Exit; End;
   Idx := NewImpObj(K_POLY);
   If Idx < 0 Then Exit;
   For I := 0 To N - 1 Do Begin
    PoolXP(Pool + I)^ := PgX(PathX[S + I]);
    PoolYP(Pool + I)^ := PgY(PathY[S + I]);
   End;
   With ObjP(Idx)^ Do Begin
    P0 := Pool; PN := N;
    Wd := StrokeW;
    Rgb := GS.Stroke; Rgb2 := GS.Fill;
    If Closed Then Style := 1;
    If DoFill And DoStroke Then Fill := 2
    Else If DoFill Then Begin Fill := 1; Rgb := GS.Fill; End
    Else Fill := 0;
   End;
   RecalcBox(Idx);
  End;
 End;
 NPts := 0;
 NSub := 0;
End;

Procedure EmitImage(ImgIdx: Integer);
Var
 I: Integer;
 X, Y: Array[0..3] Of Real;
 MnX, MnY, MxX, MxY: Real;
 Idx: Integer;
Begin
 X[0] := GS.CTM[4]; Y[0] := GS.CTM[5];
 X[1] := GS.CTM[0] + GS.CTM[4]; Y[1] := GS.CTM[1] + GS.CTM[5];
 X[2] := GS.CTM[2] + GS.CTM[4]; Y[2] := GS.CTM[3] + GS.CTM[5];
 X[3] := GS.CTM[0] + GS.CTM[2] + GS.CTM[4]; Y[3] := GS.CTM[1] + GS.CTM[3] + GS.CTM[5];
 MnX := X[0]; MxX := X[0]; MnY := Y[0]; MxY := Y[0];
 For I := 1 To 3 Do Begin
  If X[I] < MnX Then MnX := X[I];
  If X[I] > MxX Then MxX := X[I];
  If Y[I] < MnY Then MnY := Y[I];
  If Y[I] > MxY Then MxY := Y[I];
 End;
 Idx := NewImpObj(K_IMAGE);
 If Idx < 0 Then Exit;
 With ObjP(Idx)^ Do Begin
  X1 := PgX(MnX); X2 := PgX(MxX); Y1 := PgY(MxY); Y2 := PgY(MnY);
  If ImgIdx > 0 Then Begin
   P0 := ImgIdx;
   Rgb := GS.Fill;
   { axes de l'image dans la page (y vers le bas) : ex = axe horizontal de l'image,
     ey = axe vers le bas de l'image. bit 0/1 : axes inversés, bit 2 : image tournée de 90° }
   Style := 0;
   If Abs(GS.CTM[0]) >= Abs(GS.CTM[1]) Then Begin
    If GS.CTM[0] < 0 Then Style := Style Or 1;
    If GS.CTM[3] < 0 Then Style := Style Or 2;
   End
   Else Begin
    Style := 4;
    If GS.CTM[1] > 0 Then Style := Style Or 1;
    If GS.CTM[2] > 0 Then Style := Style Or 2;
   End;
  End;
 End;
End;

Procedure EmitText(Const Txt: String; Adv: Real);
Var
 M: TMat;
 SY, SXH, PX, PYv, WPt, Ang: Real;
 FSz, K, E, L, I, Idx, Sp, Tn: Integer;
 Part: String;
 F0, F1: Real;
 AnyCh: Boolean;
 Fam, Sty: Integer;
 Dx, Dy, Vx, Vy, Asc: Real;
 BX, BY: Real;
 Len: LongInt;
Begin
 If (Txt = '') Or (GS.TMode = 3) Or (GS.TMode = 7) Then Exit;
 AnyCh := False;
 For I := 1 To Length(Txt) Do If Txt[I] <> ' ' Then AnyCh := True;
 If Not AnyCh Then Exit;
 MatMul(TmM, GS.CTM, M);
 SXH := Sqrt(M[0] * M[0] + M[1] * M[1]);
 SY := Sqrt(M[2] * M[2] + M[3] * M[3]) * GS.TSize;
 { angle du texte (anti-horaire, en dixièmes de degré) }
 If M[0] = 0 Then Begin
  If M[1] >= 0 Then Ang := 90 Else Ang := 270;
 End
 Else Begin
  Ang := ArcTan(M[1] / M[0]) * 180 / Pi;
  If M[0] < 0 Then Ang := Ang + 180;
 End;
 If Ang < 0 Then Ang := Ang + 360;
 Tn := Round(Ang * 10) Mod 3600;
 { accrochage aux angles droits à 0,3° près }
 For I := 0 To 4 Do
  If Abs(Tn - I * 900) <= 3 Then Tn := (I * 900) Mod 3600;
 TextDirs(Tn, Dx, Dy, Vx, Vy);
 FSz := RI(SY);
 If FSz < 1 Then FSz := 1;
 If FSz > 200 Then FSz := 200;
 Asc := FSz * 0.8;
 PX := M[4] + GS.Ts * M[2];
 PYv := M[5] + GS.Ts * M[3];
 WPt := Abs(Adv * SXH);
 BX := PX - MbX0;
 BY := MbY1 - PYv;
 If (BX < -200) Or (BX > PgP(ImpPg)^.W + 200) Or (BY < -200) Or (BY > PgP(ImpPg)^.H + 200) Then Exit;
 If GS.TFont >= 0 Then Begin Fam := Fonts[GS.TFont].Fam; Sty := Fonts[GS.TFont].Style; End
 Else Begin Fam := 0; Sty := 0; End;
 L := Length(Txt);
 K := 1;
 While K <= L Do Begin
  E := K + 117;
  If E >= L Then E := L
  Else Begin
   Sp := E;
   While (Sp > K + 30) And (Txt[Sp] <> ' ') Do Dec(Sp);
   If Txt[Sp] = ' ' Then E := Sp;
  End;
  Part := Copy(Txt, K, E - K + 1);
  F0 := (K - 1) / L;
  F1 := E / L;
  Len := RI(WPt * (F1 - F0));
  If Len < 1 Then Len := 1;
  Idx := NewImpObj(K_TEXT);
  If Idx < 0 Then Exit;
  With ObjP(Idx)^ Do Begin
   Size := FSz;
   Style := Fam * 4 + Sty;
   Rgb := GS.Fill;
   Txt := Part;
   P0 := Len;
   PN := Tn;
  End;
  { origine = début de la ligne de base, remontée de l'ascendante }
  SetTextBox(ObjP(Idx)^, BX + Dx * WPt * F0 - Vx * Asc, BY + Dy * WPt * F0 - Vy * Asc);
  K := E + 1;
 End;
End;

{ Ajoute les caractères de S (octets d'une chaîne PDF) à Out ; avance Adv. }
Procedure ShowStr(Const S: String; Var Out: String; Var Adv: Real);
Var
 I, Step: Integer;
 Code: LongInt;
 F: ^TFontRec;
 W: Real;
 Mapped: String;
Begin
 If GS.TFont >= 0 Then F := @Fonts[GS.TFont] Else F := Nil;
 I := 1;
 While I <= Length(S) Do Begin
  If (F <> Nil) And F^.Wide Then Begin
   If I < Length(S) Then Code := Ord(S[I]) * 256 + Ord(S[I + 1]) Else Code := Ord(S[I]);
   Step := 2;
  End
  Else Begin Code := Ord(S[I]); Step := 1; End;
  If F <> Nil Then Begin
   Mapped := MapCode(F^, Code);
   W := GlyphW(F^, Code);
  End
  Else Begin
   If Code < 32 Then Mapped := '' Else Mapped := Chr(Code And 255);
   W := CharW(0, 0, Code And 255);
  End;
  If Length(Out) + Length(Mapped) < 250 Then Out := Out + Mapped;
  Adv := Adv + (W / 1000 * GS.TSize + GS.Tc + ((Ord(Code = 32) And Ord(Step = 1)) * GS.Tw)) * GS.Th;
  Inc(I, Step);
 End;
End;

Procedure TextMove(TX, TY: Real);
Var
 T: TMat;
Begin
 T[0] := 1; T[1] := 0; T[2] := 0; T[3] := 1; T[4] := TX; T[5] := TY;
 MatMul(T, TlmM, TlmM);
 TmM := TlmM;
End;

Procedure ShowAndEmit(Const S: String);
Var
 Out: String;
 Adv: Real;
 T: TMat;
Begin
 Out := '';
 Adv := 0;
 ShowStr(S, Out, Adv);
 EmitText(Out, Adv);
 T[0] := 1; T[1] := 0; T[2] := 0; T[3] := 1; T[4] := Adv; T[5] := 0;
 MatMul(T, TmM, TmM);
End;

Procedure ShowTJ(ArrPos: LongInt);
Var
 P: LongInt;
 T: Integer;
 Out: String;
 Adv: Real;
 M: TMat;
Begin
 P := ArrPos;
 If NextTok(P) <> T_AB Then Exit;
 Out := '';
 Adv := 0;
 While True Do Begin
  T := NextTok(P);
  If (T = T_AE) Or (T = T_EOF) Then Break;
  If T = T_STR Then ShowStr(TokS, Out, Adv)
  Else If T = T_NUM Then Begin
   Adv := Adv - TokR / 1000 * GS.TSize * GS.Th;
   If (TokR <= -250) And (Out <> '') And (Out[Length(Out)] <> ' ') And (Length(Out) < 250) Then Out := Out + ' ';
  End;
 End;
 EmitText(Out, Adv);
 M[0] := 1; M[1] := 0; M[2] := 0; M[3] := 1; M[4] := Adv; M[5] := 0;
 MatMul(M, TmM, TmM);
End;

Procedure RunContent(Depth: Integer); Forward;

Procedure DoXObject(Const Name: String; Depth: Integer);
Var
 I, Idx: Integer;
 L: LongInt;
 P, V: LongInt;
 Mat: TMat;
 Arr: Array[0..5] Of Real;
 FBase, XBase, Num: Integer;
 S: TSrcState;
Begin
 Idx := -1;
 For I := NXObjs - 1 DownTo 0 Do
  If XObjs[I].Name = Name Then Begin Idx := I; Break; End;
 If Idx < 0 Then Exit;
 If Not XObjs[Idx].IsForm Then Begin EmitImage(ImportImageObj(XObjs[Idx].Num, False)); Exit; End;
 If Depth >= 3 Then Exit;
 Num := XObjs[Idx].Num;
 FBase := NFonts; XBase := NXObjs;
 SrcMode := 0;
 If Not LoadStream(Num, CBufs[Depth + 1], L) Then Exit;
 CLens[Depth + 1] := L;
 MatIdent(Mat);
 SrcMode := 0;
 P := EnterObj(Num);
 If P >= 0 Then Begin
  V := DictFind(P, 'Matrix');
  If V >= 0 Then If ReadNums(V, Arr, 6) = 6 Then
   For I := 0 To 5 Do Mat[I] := Arr[I];
  If DictFind(P, 'Resources') >= 0 Then LoadResources(Num);
 End;
 PushGS;
 MatMul(Mat, GS.CTM, GS.CTM);
 RunContent(Depth + 1);
 PopGS;
 FreeFontsTo(FBase);
 NXObjs := XBase;
End;

Procedure ExecOp(Const Op: String; Var P: LongInt; ArrPos: LongInt; Depth: Integer);
Var
 C: Char;
 T: TMat;
 I, T2, N: Integer;
 Q: LongInt;
 X, Y, W, H: Real;
 Prev: Char;
Begin
 C := Op[1];
 N := NOpnd;
 Case Length(Op) Of
  1: Case C Of
   'q': PushGS;
   'Q': PopGS;
   'w': If N >= 1 Then GS.LW := Opnd[N - 1];
   'm': If N >= 2 Then Begin NewSub; AddPt(Opnd[N - 2], Opnd[N - 1]); End;
   'l': If N >= 2 Then Begin If NPts = 0 Then NewSub; AddPt(Opnd[N - 2], Opnd[N - 1]); End;
   'c': If (N >= 6) And (NPts > 0) Then CurveTo(Opnd[N - 6], Opnd[N - 5], Opnd[N - 4], Opnd[N - 3], Opnd[N - 2], Opnd[N - 1]);
   'v': If (N >= 4) And (NPts > 0) Then Begin
    X := PathX[NPts - 1]; Y := PathY[NPts - 1];
    { point courant en espace utilisateur approximé : inversion non requise, on utilise le point transformé }
    CurveTo(Opnd[N - 4], Opnd[N - 3], Opnd[N - 4], Opnd[N - 3], Opnd[N - 2], Opnd[N - 1]);
   End;
   'y': If (N >= 4) And (NPts > 0) Then
    CurveTo(Opnd[N - 4], Opnd[N - 3], Opnd[N - 2], Opnd[N - 1], Opnd[N - 2], Opnd[N - 1]);
   'h': If NSub > 0 Then SubClosed[NSub - 1] := True;
   'S': EmitPath(False, True, False);
   's': EmitPath(False, True, True);
   'f', 'F': EmitPath(True, False, False);
   'B': EmitPath(True, True, False);
   'b': EmitPath(True, True, True);
   'n': Begin NPts := 0; NSub := 0; End;
   'W': ;
   'g': If N >= 1 Then GS.Fill := GrayRgb(Opnd[N - 1]);
   'G': If N >= 1 Then GS.Stroke := GrayRgb(Opnd[N - 1]);
   'k': If N >= 4 Then GS.Fill := CmykRgb(Opnd[N - 4], Opnd[N - 3], Opnd[N - 2], Opnd[N - 1]);
   'K': If N >= 4 Then GS.Stroke := CmykRgb(Opnd[N - 4], Opnd[N - 3], Opnd[N - 2], Opnd[N - 1]);
   '''': Begin TextMove(0, -GS.TL); ShowAndEmit(LastStr); End;
   '"': Begin
    If N >= 2 Then Begin GS.Tw := Opnd[N - 2]; GS.Tc := Opnd[N - 1]; End;
    TextMove(0, -GS.TL); ShowAndEmit(LastStr);
   End;
  End;
  2: Begin
   Prev := Op[2];
   If Op = 'cm' Then Begin
    If N >= 6 Then Begin
     For I := 0 To 5 Do T[I] := Opnd[N - 6 + I];
     MatMul(T, GS.CTM, GS.CTM);
    End;
   End
   Else If Op = 're' Then Begin
    If N >= 4 Then Begin
     X := Opnd[N - 4]; Y := Opnd[N - 3]; W := Opnd[N - 2]; H := Opnd[N - 1];
     NewSub;
     If NSub > 0 Then SubRect[NSub - 1] := True;
     AddPt(X, Y); AddPt(X + W, Y); AddPt(X + W, Y + H); AddPt(X, Y + H);
     If NSub > 0 Then SubClosed[NSub - 1] := True;
    End;
   End
   Else If Op = 'f*' Then EmitPath(True, False, False)
   Else If Op = 'B*' Then EmitPath(True, True, False)
   Else If Op = 'b*' Then EmitPath(True, True, True)
   Else If Op = 'W*' Then
   Else If Op = 'BT' Then Begin MatIdent(TmM); MatIdent(TlmM); End
   Else If Op = 'ET' Then
   Else If Op = 'Tc' Then Begin If N >= 1 Then GS.Tc := Opnd[N - 1]; End
   Else If Op = 'Tw' Then Begin If N >= 1 Then GS.Tw := Opnd[N - 1]; End
   Else If Op = 'Tz' Then Begin If N >= 1 Then GS.Th := Opnd[N - 1] / 100; End
   Else If Op = 'TL' Then Begin If N >= 1 Then GS.TL := Opnd[N - 1]; End
   Else If Op = 'Ts' Then Begin If N >= 1 Then GS.Ts := Opnd[N - 1]; End
   Else If Op = 'Tr' Then Begin If N >= 1 Then GS.TMode := Round(Opnd[N - 1]); End
   Else If Op = 'Tf' Then Begin
    If N >= 1 Then GS.TSize := Opnd[N - 1];
    GS.TFont := FontIndex(LastName);
   End
   Else If Op = 'Td' Then Begin If N >= 2 Then TextMove(Opnd[N - 2], Opnd[N - 1]); End
   Else If Op = 'TD' Then Begin
    If N >= 2 Then Begin GS.TL := -Opnd[N - 1]; TextMove(Opnd[N - 2], Opnd[N - 1]); End;
   End
   Else If Op = 'Tm' Then Begin
    If N >= 6 Then Begin
     For I := 0 To 5 Do TmM[I] := Opnd[N - 6 + I];
     TlmM := TmM;
    End;
   End
   Else If Op = 'T*' Then TextMove(0, -GS.TL)
   Else If Op = 'Tj' Then ShowAndEmit(LastStr)
   Else If Op = 'TJ' Then Begin If ArrPos >= 0 Then ShowTJ(ArrPos); End
   Else If Op = 'rg' Then Begin If N >= 3 Then GS.Fill := RGBOf(RI(Opnd[N - 3] * 255), RI(Opnd[N - 2] * 255), RI(Opnd[N - 1] * 255)); End
   Else If Op = 'RG' Then Begin If N >= 3 Then GS.Stroke := RGBOf(RI(Opnd[N - 3] * 255), RI(Opnd[N - 2] * 255), RI(Opnd[N - 1] * 255)); End
   Else If (Op = 'sc') Or (Op = 'SC') Then Begin
    If N = 1 Then Begin If Op = 'sc' Then GS.Fill := GrayRgb(Opnd[0]) Else GS.Stroke := GrayRgb(Opnd[0]); End
    Else If N = 3 Then Begin
     If Op = 'sc' Then GS.Fill := RGBOf(RI(Opnd[0] * 255), RI(Opnd[1] * 255), RI(Opnd[2] * 255))
     Else GS.Stroke := RGBOf(RI(Opnd[0] * 255), RI(Opnd[1] * 255), RI(Opnd[2] * 255));
    End
    Else If N = 4 Then Begin
     If Op = 'sc' Then GS.Fill := CmykRgb(Opnd[0], Opnd[1], Opnd[2], Opnd[3])
     Else GS.Stroke := CmykRgb(Opnd[0], Opnd[1], Opnd[2], Opnd[3]);
    End;
   End
   Else If Op = 'Do' Then DoXObject(LastName, Depth)
   Else If Op = 'BI' Then Begin
    { image en ligne : sauter jusqu'à EI }
    While True Do Begin
     T2 := NextTok(P);
     If T2 = T_EOF Then Break;
     If (T2 = T_OP) And (TokS = 'ID') Then Break;
    End;
    Inc(P);
    While True Do Begin
     I := SB(P);
     If I = -1 Then Break;
     If IsWs(I) And (SB(P + 1) = 69) And (SB(P + 2) = 73) And (IsWs(SB(P + 3)) Or (SB(P + 3) = -1)) Then Begin
      Inc(P, 3);
      Break;
     End;
     Inc(P);
    End;
    EmitImage(0);
   End;
  End;
 Else
  If (Op = 'scn') Or (Op = 'SCN') Then Begin
   If N = 1 Then Begin If Op = 'scn' Then GS.Fill := GrayRgb(Opnd[0]) Else GS.Stroke := GrayRgb(Opnd[0]); End
   Else If N = 3 Then Begin
    If Op = 'scn' Then GS.Fill := RGBOf(RI(Opnd[0] * 255), RI(Opnd[1] * 255), RI(Opnd[2] * 255))
    Else GS.Stroke := RGBOf(RI(Opnd[0] * 255), RI(Opnd[1] * 255), RI(Opnd[2] * 255));
   End
   Else If N = 4 Then Begin
    If Op = 'scn' Then GS.Fill := CmykRgb(Opnd[0], Opnd[1], Opnd[2], Opnd[3])
    Else GS.Stroke := CmykRgb(Opnd[0], Opnd[1], Opnd[2], Opnd[3]);
   End;
  End;
 End;
 NOpnd := 0;
End;

Procedure RunContent(Depth: Integer);
Var
 P, Q0, ArrPos: LongInt;
 T: Integer;
 Op: String;
 SaveGSP: Integer;
 Count: LongInt;
Begin
 SaveGSP := GSP;
 P := 0;
 NOpnd := 0;
 ArrPos := -1;
 Count := 0;
 While Not ImpFull Do Begin
  SrcMode := 2;
  CBuf := CBufs[Depth];
  CLen := CLens[Depth];
  Q0 := P;
  T := NextTok(P);
  Inc(Count);
  If T = T_EOF Then Break;
  Case T Of
   T_NUM: Begin
    If NOpnd >= 40 Then Begin
     Move(Opnd[1], Opnd[0], 39 * SizeOf(Real));
     NOpnd := 39;
    End;
    Opnd[NOpnd] := TokR;
    Inc(NOpnd);
   End;
   T_NAME: LastName := TokS;
   T_STR: LastStr := TokS;
   T_AB: Begin ArrPos := Q0; P := Q0; SkipValue(P); End;
   T_DB: Begin P := Q0; SkipValue(P); End;
   T_OP: Begin
    Op := TokS;
    ExecOp(Op, P, ArrPos, Depth);
    If (Op = 'TJ') Or (Op = 'd') Then ArrPos := -1;
   End;
  End;
  If (Count And 1023) = 0 Then Begin
   If KeyPressed Then If ReadKey = #27 Then Begin ImpFull := True; LoadNotice := 'Chargement interrompu.'; End;
  End;
 End;
 While GSP > SaveGSP Do PopGS;
 SrcMode := 0;
End;

{ ---------------------------------------------------------------------- }
{ Import PDF : pages, annotations                                           }
{ ---------------------------------------------------------------------- }

Function StrAtPos(P: LongInt): String;
Var
 N: Integer;
 S: TSrcState;
 Q: LongInt;
Begin
 StrAtPos := '';
 If P < 0 Then Exit;
 N := RefAt(P);
 If N > 0 Then Begin
  SaveSrc(S);
  Q := EnterObj(N);
  If Q >= 0 Then If NextTok(Q) = T_STR Then StrAtPos := TokS;
  RestoreSrc(S);
 End
 Else If NextTok(P) = T_STR Then StrAtPos := TokS;
End;

Function AnnColor(P: LongInt; Def: LongInt): LongInt;
Var
 A: Array[0..3] Of Real;
 N: Integer;
Begin
 AnnColor := Def;
 If P < 0 Then Exit;
 N := ReadNums(P, A, 4);
 If N = 1 Then AnnColor := GrayRgb(A[0])
 Else If N = 3 Then AnnColor := RGBOf(RI(A[0] * 255), RI(A[1] * 255), RI(A[2] * 255))
 Else If N = 4 Then AnnColor := CmykRgb(A[0], A[1], A[2], A[3]);
End;

Procedure ImportAnnot(Num: Integer);
Var
 P, V, Q: LongInt;
 Sub, ATxt: String;
 R: Array[0..3] Of Real;
 QA: Array[0..31] Of Real;
 LA: Array[0..3] Of Real;
 N, I, K, Idx, Kind, Pool, Cnt: Integer;
 Col, ICol: LongInt;
 AX1, AY1, AX2, AY2: LongInt;
 BW: LongInt;
 T: Integer;
 MnX, MnY, MxX, MxY: Real;
 HasIC: Boolean;
 Px, Py: Array[0..199] Of Integer;
Begin
 SrcMode := 0;
 P := EnterObj(Num);
 If P < 0 Then Exit;
 Sub := ValName(DictFind(P, 'Subtype'));
 If (Sub <> 'Highlight') And (Sub <> 'Underline') And (Sub <> 'StrikeOut') And (Sub <> 'Squiggly') And
    (Sub <> 'Text') And (Sub <> 'FreeText') And (Sub <> 'Square') And (Sub <> 'Circle') And
    (Sub <> 'Line') And (Sub <> 'Ink') Then Exit;
 If ReadNums(DictFind(P, 'Rect'), R, 4) < 4 Then Exit;
 AX1 := PgX(R[0]); AX2 := PgX(R[2]); AY1 := PgY(R[3]); AY2 := PgY(R[1]);
 If AX1 > AX2 Then Begin I := AX1; AX1 := AX2; AX2 := I; End;
 If AY1 > AY2 Then Begin I := AY1; AY1 := AY2; AY2 := I; End;
 ATxt := PdfText(StrAtPos(DictFind(P, 'Contents')));
 If Length(ATxt) > 119 Then ATxt := Copy(ATxt, 1, 119);
 Col := AnnColor(DictFind(P, 'C'), -1);
 V := DictFind(P, 'IC');
 HasIC := V >= 0;
 ICol := AnnColor(V, $FFFFFF);
 BW := 1;
 V := DictFind(P, 'BS');
 If V >= 0 Then BW := ValInt(DictFind(V, 'W'), 1);
 If BW < 1 Then BW := 1;
 If BW > 20 Then BW := 20;
 If (Sub = 'Highlight') Or (Sub = 'Underline') Or (Sub = 'StrikeOut') Or (Sub = 'Squiggly') Then Begin
  If Sub = 'Highlight' Then Begin Kind := K_HILITE; If Col < 0 Then Col := $FFFF00; End
  Else If Sub = 'StrikeOut' Then Begin Kind := K_STRIKE; If Col < 0 Then Col := $FF0000; End
  Else Begin Kind := K_UNDER; If Col < 0 Then Col := $FF0000; End;
  N := ReadNums(DictFind(P, 'QuadPoints'), QA, 32);
  K := N Div 8;
  If K = 0 Then Begin
   Idx := NewImpObj(Kind);
   If Idx < 0 Then Exit;
   With ObjP(Idx)^ Do Begin X1 := AX1; Y1 := AY1; X2 := AX2; Y2 := AY2; Rgb := Col; Txt := ATxt; End;
  End
  Else For I := 0 To K - 1 Do Begin
   MnX := QA[I * 8]; MxX := MnX; MnY := QA[I * 8 + 1]; MxY := MnY;
   For T := 0 To 3 Do Begin
    If QA[I * 8 + T * 2] < MnX Then MnX := QA[I * 8 + T * 2];
    If QA[I * 8 + T * 2] > MxX Then MxX := QA[I * 8 + T * 2];
    If QA[I * 8 + T * 2 + 1] < MnY Then MnY := QA[I * 8 + T * 2 + 1];
    If QA[I * 8 + T * 2 + 1] > MxY Then MxY := QA[I * 8 + T * 2 + 1];
   End;
   Idx := NewImpObj(Kind);
   If Idx < 0 Then Exit;
   With ObjP(Idx)^ Do Begin
    X1 := PgX(MnX); X2 := PgX(MxX); Y1 := PgY(MxY); Y2 := PgY(MnY);
    Rgb := Col;
    If I = 0 Then Txt := ATxt;
   End;
  End;
 End
 Else If Sub = 'Text' Then Begin
  Idx := NewImpObj(K_NOTE);
  If Idx < 0 Then Exit;
  With ObjP(Idx)^ Do Begin X1 := AX1; Y1 := AY1; X2 := AX1 + 16; Y2 := AY1 + 16; Rgb := $FFFF00; Txt := ATxt; End;
 End
 Else If Sub = 'FreeText' Then Begin
  If ATxt = '' Then Exit;
  Idx := NewImpObj(K_TEXT);
  If Idx < 0 Then Exit;
  With ObjP(Idx)^ Do Begin X1 := AX1 + 2; Y1 := AY1 + 2; Size := 12; Rgb := 0; Txt := ATxt; End;
  RecalcBox(Idx);
 End
 Else If (Sub = 'Square') Or (Sub = 'Circle') Then Begin
  If Sub = 'Square' Then Idx := NewImpObj(K_RECT) Else Idx := NewImpObj(K_OVAL);
  If Idx < 0 Then Exit;
  With ObjP(Idx)^ Do Begin
   X1 := AX1; Y1 := AY1; X2 := AX2; Y2 := AY2;
   If Col < 0 Then Col := $FF0000;
   Rgb := Col; Rgb2 := ICol; Wd := BW;
   If HasIC Then Fill := 2 Else Fill := 0;
  End;
 End
 Else If Sub = 'Line' Then Begin
  If ReadNums(DictFind(P, 'L'), LA, 4) < 4 Then Exit;
  Idx := NewImpObj(K_LINE);
  If Idx < 0 Then Exit;
  With ObjP(Idx)^ Do Begin
   X1 := PgX(LA[0]); Y1 := PgY(LA[1]); X2 := PgX(LA[2]); Y2 := PgY(LA[3]);
   If Col < 0 Then Col := $FF0000;
   Rgb := Col; Wd := BW;
  End;
 End
 Else If Sub = 'Ink' Then Begin
  V := DictFind(P, 'InkList');
  If V < 0 Then Exit;
  Q := V;
  If NextTok(Q) <> T_AB Then Exit;
  If NextTok(Q) <> T_AB Then Exit;
  Cnt := 0;
  While Cnt < 100 Do Begin
   If NextTok(Q) <> T_NUM Then Break;
   MnX := TokR;
   If NextTok(Q) <> T_NUM Then Break;
   Px[Cnt] := PgX(MnX); Py[Cnt] := PgY(TokR);
   Inc(Cnt);
  End;
  If Cnt < 2 Then Exit;
  Pool := PoolAlloc(Cnt);
  If Pool < 0 Then Exit;
  Idx := NewImpObj(K_INK);
  If Idx < 0 Then Exit;
  For I := 0 To Cnt - 1 Do Begin PoolXP(Pool + I)^ := Px[I]; PoolYP(Pool + I)^ := Py[I]; End;
  If Col < 0 Then Col := $FF0000;
  With ObjP(Idx)^ Do Begin P0 := Pool; PN := Cnt; Rgb := Col; Wd := BW; End;
  RecalcBox(Idx);
 End;
End;

Procedure ImportAnnots(Node: Integer);
Var
 P, V, Q: LongInt;
 N, NR, I: Integer;
 Refs: Array[0..1999] Of Integer;
 AStart, J: LongInt;
Begin
 SrcMode := 0;
 P := EnterObj(Node);
 If P < 0 Then Exit;
 V := DictFind(P, 'Annots');
 If V < 0 Then Exit;
 N := RefAt(V);
 If N > 0 Then V := EnterObj(N);
 If V < 0 Then Exit;
 Q := V;
 If NextTok(Q) <> T_AB Then Exit;
 NR := 0;
 While NR < 2000 Do Begin
  I := RefAt(Q);
  If I > 0 Then Begin Refs[NR] := I; Inc(NR); SkipValue(Q); End
  Else Break;
 End;
 For I := 0 To NR - 1 Do Begin
  If ImpFull Then Break;
  AStart := ObjCount;
  ImpSrcKind := 2;
  ImpAnnNum := Refs[I];
  ImportAnnot(Refs[I]);
  ImpAnnNum := 0;
  For J := AStart To ObjCount - 1 Do ObjP(J)^.SrcCnt := ObjCount - AStart;
  If ImpKeepSrc And (ObjCount > AStart) Then AnnSetMark(Refs[I]);
 End;
 ImpSrcKind := 1;
End;

Procedure ImportPage(Node: Integer; B0, B1, B2, B3: Real; Rot, ResNode: Integer);
Var
 P, V, Q: LongInt;
 N, I, NC, UseRes, FBase, XBase: Integer;
 Refs: Array[0..255] Of Integer;
 L: LongInt;
 W, H: LongInt;
 PStart, J: LongInt;
 S: TSrcState;
 R: Integer;
Begin
 If Not PgEnsure(PageCount + 1) Then Begin
  ImpFull := True;
  LoadNotice := 'Document tronqué : mémoire insuffisante.';
  Exit;
 End;
 Inc(PageCount);
 ImpPg := PageCount;
 FillChar(PgP(ImpPg)^, SizeOf(TPageRec), 0);
 W := RI(Abs(B2 - B0)); H := RI(Abs(B3 - B1));
 If W < 20 Then W := 612;
 If H < 20 Then H := 792;
 If W > 14400 Then W := 14400;
 If H > 14400 Then H := 14400;
 R := Rot;
 While R < 0 Do R := R + 360;
 R := (R Div 90) And 3;
 PgP(ImpPg)^.W := W; PgP(ImpPg)^.H := H; PgP(ImpPg)^.Rot := R; PgP(ImpPg)^.Top := 0;
 If B0 < B2 Then MbX0 := B0 Else MbX0 := B2;
 If B1 > B3 Then MbY1 := B1 Else MbY1 := B3;
 FBase := NFonts; XBase := NXObjs;
 PStart := ObjCount;
 ImpSrcKind := 1; ImpAnnNum := 0;
 If ImpKeepSrc Then Begin
  PgP(ImpPg)^.SrcPage := Node;
  PgP(ImpPg)^.OrigW := W; PgP(ImpPg)^.OrigH := H; PgP(ImpPg)^.OrigRot := R;
  PgP(ImpPg)^.MbX0 := MbX0; PgP(ImpPg)^.MbY1 := MbY1;
 End;
 SrcMode := 0;
 P := EnterObj(Node);
 If P < 0 Then Exit;
 If DictFind(P, 'Resources') >= 0 Then UseRes := Node Else UseRes := ResNode;
 NC := 0;
 V := DictFind(P, 'Contents');
 If V >= 0 Then Begin
  N := RefAt(V);
  If N > 0 Then Begin
   Q := EnterObj(N);
   If Q >= 0 Then Begin
    V := Q;
    SaveSrc(S);
    If NextTok(Q) = T_AB Then Begin
     While NC < 256 Do Begin
      I := RefAt(Q);
      If I > 0 Then Begin Refs[NC] := I; Inc(NC); SkipValue(Q); End
      Else Break;
     End;
    End
    Else Begin Refs[0] := N; NC := 1; End;
   End;
  End
  Else Begin
   Q := V;
   If NextTok(Q) = T_AB Then
    While NC < 256 Do Begin
     I := RefAt(Q);
     If I > 0 Then Begin Refs[NC] := I; Inc(NC); SkipValue(Q); End
     Else Break;
    End;
  End;
 End;
 SrcMode := 0;
 If UseRes > 0 Then LoadResources(UseRes);
 GS.TFont := -1;
 MatIdent(GS.CTM);
 GS.Stroke := 0; GS.Fill := 0; GS.LW := 1;
 GS.Tc := 0; GS.Tw := 0; GS.Th := 1; GS.TL := 0; GS.Ts := 0; GS.TSize := 12; GS.TMode := 0;
 MatIdent(TmM); MatIdent(TlmM);
 GSP := 0; NPts := 0; NSub := 0; NOpnd := 0;
 For I := 0 To NC - 1 Do Begin
  If ImpFull Then Break;
  SrcMode := 0;
  If LoadStream(Refs[I], CBufs[0], L) Then Begin
   CLens[0] := L;
   RunContent(0);
  End;
 End;
 FreeFontsTo(FBase);
 NXObjs := XBase;
 PgP(ImpPg)^.SrcCount := ObjCount - PStart;
 If Not ImpFull Then ImportAnnots(Node);
 PgP(ImpPg)^.SrcAnnObjs := ObjCount - PStart - PgP(ImpPg)^.SrcCount;
 SrcMode := 0;
 If ImpKeepSrc Then
  For J := PStart To ObjCount - 1 Do ObjP(J)^.Sum := ObjSum(J);
End;

Procedure WalkPages(Node, Depth: Integer; B0, B1, B2, B3: Real; HaveBox: Boolean; Rot, ResNode: Integer);
Var
 P, V, Q: LongInt;
 Nm: String;
 A: Array[0..3] Of Real;
 N, Base, EndK, I, Kid: Integer;
Begin
 If (Depth > 14) Or ImpFull Then Exit;
 SrcMode := 0;
 P := EnterObj(Node);
 If P < 0 Then Exit;
 Nm := ValName(DictFind(P, 'Type'));
 V := DictFind(P, 'MediaBox');
 If V >= 0 Then If ReadNums(V, A, 4) = 4 Then Begin
  B0 := A[0]; B1 := A[1]; B2 := A[2]; B3 := A[3]; HaveBox := True;
 End;
 V := DictFind(P, 'Rotate');
 If V >= 0 Then Rot := ValInt(V, 0);
 SrcMode := 0;
 P := EnterObj(Node);
 If DictFind(P, 'Resources') >= 0 Then ResNode := Node;
 V := DictFind(P, 'Kids');
 If (V >= 0) And (Nm <> 'Page') Then Begin
  Base := KidSP;
  N := RefAt(V);
  If N > 0 Then V := EnterObj(N);
  If V >= 0 Then Begin
   Q := V;
   If NextTok(Q) = T_AB Then
    While KidSP < 65535 Do Begin
     I := RefAt(Q);
     If I > 0 Then Begin KidStack[KidSP] := I; Inc(KidSP); SkipValue(Q); End
     Else Break;
    End;
  End;
  EndK := KidSP;
  For I := Base To EndK - 1 Do Begin
   If ImpFull Then Break;
   Kid := KidStack[I];
   WalkPages(Kid, Depth + 1, B0, B1, B2, B3, HaveBox, Rot, ResNode);
  End;
  KidSP := Base;
 End
 Else Begin
  If Not HaveBox Then Begin B0 := 0; B1 := 0; B2 := 612; B3 := 792; End;
  ImportPage(Node, B0, B1, B2, B3, Rot, ResNode);
  If (PageCount Mod 4) = 0 Then ShowProgress('Chargement de la page ' + IStr(PageCount) + '...');
 End;
End;

{ Ouvre un fichier PDF. Si Append est vrai, les pages sont ajoutées à la fin. }
Function ImportPDF(Const Name: String; Append: Boolean; Var Err: String): Boolean;
Var
 I, N: Integer;
 P, V: LongInt;
 PagesNum: Integer;
Begin
 ImportPDF := False;
 Err := '';
 LoadNotice := '';
 InitPdfBuffers;
 {$I-}
 Assign(PF, Name);
 Reset(PF, 1);
 {$I+}
 If IOResult <> 0 Then Begin Err := 'Impossible d''ouvrir le fichier.'; Exit; End;
 PFSize := FileSize(PF);
 For I := 0 To PdfCap - 1 Do Begin ObjPos^[I] := -1; ObjStmNo^[I] := 0; ObjStmOff^[I] := 0; ImgByObj^[I] := 0; End;
 DecCap := BUFSZ;
 MaxObjNum := 0; RootNum := 0; InfoNum := 0; StmCacheNum := 0; RBase := -1; RLen := 0; SrcMode := 0;
 NFonts := 0; NXObjs := 0; KidSP := 0; SkippedText := 0;
 ImpFull := False;
 ImpKeepSrc := Not Append;
 If (Not Append) And (AnnSet <> Nil) Then FillChar(AnnSet^, AnnSetCap, 0);
 ImpSrcKind := 1; ImpAnnNum := 0;
 DocEncrypted := False;
 ShowProgress('Analyse du fichier PDF...');
 ScanFile;
 ProcessObjects;
 If DocEncrypted Then Begin
  Err := 'Document chiffré (protégé) : non pris en charge.';
  Close(PF);
  Exit;
 End;
 If (RootNum = 0) And (MaxObjNum = 0) Then Begin
  Err := 'Fichier PDF invalide ou endommagé (aucun objet trouvé).';
  Close(PF);
  Exit;
 End;
 SrcMode := 0;
 PagesNum := 0;
 If RootNum > 0 Then P := EnterObj(RootNum) Else P := -1;
 If P >= 0 Then Begin
  V := DictFind(P, 'Pages');
  If V >= 0 Then PagesNum := RefAt(V);
 End;
 If (PagesNum = 0) And (RootNum = 0) Then Begin
  { réparation : rechercher les objets /Type /Page dans l'ordre du fichier }
  PagesNum := -1;
 End;
 If PagesNum = 0 Then Begin
  Err := 'Arborescence des pages introuvable.';
  Close(PF);
  Exit;
 End;
 If Not Append Then Begin
  FreeImages;
  ObjsFree; PgsFree; PoolFree;
  ObjEnsure(0); PgEnsure(1); PoolEnsure(1);
 End;
 N := PageCount;
 If PagesNum > 0 Then WalkPages(PagesNum, 0, 0, 0, 612, 792, False, 0, 0)
 Else Begin
  For I := 1 To MaxObjNum Do Begin
   If ImpFull Then Break;
   If ObjPos^[I] < 0 Then Continue;
   SrcMode := 0;
   P := ObjPos^[I];
   If ValName(DictFind(P, 'Type')) = 'Page' Then WalkPages(I, 0, 0, 0, 612, 792, False, 0, 0);
  End;
  If PageCount > N Then LoadNotice := 'Fichier endommagé : structure reconstruite, pages récupérées : ' + IStr(PageCount - N) + '.';
 End;
 If PageCount = N Then Begin
  Err := 'Aucune page lisible dans ce document.';
  Close(PF);
  Exit;
 End;
 If Not Append Then Begin
  SrcFile := FExpand(Name);
  SrcValid := True;
  SrcSize := PFSize;
  InfoDirty := False;
  NeedFullRewrite := False;
  If OrigOrder <> Nil Then FreeMem(OrigOrder, (OrigPageCnt + 1) * SizeOf(LongInt));
  OrigPageCnt := PageCount;
  GetMem(OrigOrder, (OrigPageCnt + 1) * SizeOf(LongInt));
  For I := 1 To PageCount Do OrigOrder^[I - 1] := PgP(I)^.SrcPage;
 End;
 If (Not Append) And (InfoNum > 0) Then Begin
  SrcMode := 0;
  P := EnterObj(InfoNum);
  If P >= 0 Then Begin
   DocTitle := Copy(PdfText(StrAtPos(DictFind(P, 'Title'))), 1, 79);
   DocAuthor := Copy(PdfText(StrAtPos(DictFind(P, 'Author'))), 1, 79);
   DocSubject := Copy(PdfText(StrAtPos(DictFind(P, 'Subject'))), 1, 79);
   DocKeywords := Copy(PdfText(StrAtPos(DictFind(P, 'Keywords'))), 1, 79);
   DocCreator := Copy(PdfText(StrAtPos(DictFind(P, 'Creator'))), 1, 79);
  End;
 End;
 If (SkippedText > 0) And (LoadNotice = '') Then
  LoadNotice := IStr(SkippedText) + ' texte(s) pivoté(s) non affiché(s).';
 Close(PF);
 SrcMode := 0;
 ImportPDF := True;
End;

{ ---------------------------------------------------------------------- }
{ Enregistrement incrémental                                                }
{ Le fichier d'origine est recopié tel quel (polices incorporées, liens,   }
{ formulaires, signets, signatures...) ; seules les modifications sont     }
{ ajoutées à la suite, avec une nouvelle table des références.             }
{ ---------------------------------------------------------------------- }

Type
 TRawEnt = Record
  Key: String[63];
  St: TSrcState;
  A, B: LongInt;
  Ref: LongInt;
 End;
 PRawEnt = ^TRawEnt;
 TRawArr = Array[0..4095] Of TRawEnt;
 PRawArr = ^TRawArr;

Var
 IncNext: LongInt;               { prochain numéro d'objet libre }
 IncFontBase: LongInt;           { numéro des 12 polices ajoutées (0 : aucune) }
 IncImgNo: PLArr;
 IncRoot, IncPagesRoot, IncInfo, IncSize, IncPrev: LongInt;
 IncXStream: Boolean;
 IncTreeChanged: Boolean;
 IncPgNo: PLArr;                 { n° d'objet de chaque page du modèle }
 PgFirst, PgIdx: PLArr;          { objets du modèle regroupés par page }
 IncKeep, IncDrop: Array[0..4095] Of LongInt;
 IncKeepN, IncDropN: Integer;
 IncErr: String;

{ Copie brute des octets A..B-1 d'une source }
Procedure CopyRaw(Const St: TSrcState; A, B: LongInt);
Var
 S0: TSrcState;
 Buf: String;
 C: Integer;
 P: LongInt;
Begin
 SaveSrc(S0);
 RestoreSrc(St);
 Buf := '';
 P := A;
 While P < B Do Begin
  C := SB(P);
  If C < 0 Then Break;
  Buf := Buf + Chr(C);
  Inc(P);
  If Length(Buf) >= 200 Then Begin WS(Buf); Buf := ''; End;
 End;
 If Buf <> '' Then WS(Buf);
 RestoreSrc(S0);
End;

{ Entrées de premier niveau d'un dictionnaire (valeur en ValPos, éventuellement indirecte) }
Function CollectDict(ValPos: LongInt; E: PRawArr; Max: Integer): Integer;
Var
 S0: TSrcState;
 N, Cnt, T: Integer;
 P, Q: LongInt;
Begin
 CollectDict := 0;
 If ValPos < 0 Then Exit;
 SaveSrc(S0);
 N := RefAt(ValPos);
 If N > 0 Then P := EnterObj(N) Else P := ValPos;
 Cnt := 0;
 If P >= 0 Then Begin
  Q := P;
  If NextTok(Q) = T_DB Then
   While Cnt < Max Do Begin
    T := NextTok(Q);
    If T <> T_NAME Then Break;
    E^[Cnt].Key := Copy(TokS, 1, 63);
    SaveSrc(E^[Cnt].St);
    E^[Cnt].A := Q;
    SkipValue(Q);
    E^[Cnt].B := Q;
    E^[Cnt].Ref := 0;
    Inc(Cnt);
   End;
 End;
 RestoreSrc(S0);
 CollectDict := Cnt;
End;

{ Éléments d'un tableau (références ou valeurs directes) }
Function CollectArray(Const St: TSrcState; ValPos: LongInt; E: PRawArr; Max: Integer): Integer;
Var
 S0: TSrcState;
 N, Cnt: Integer;
 P, Q, R0: LongInt;
 T: Integer;
Begin
 CollectArray := 0;
 SaveSrc(S0);
 RestoreSrc(St);
 N := RefAt(ValPos);
 If N > 0 Then P := EnterObj(N) Else P := ValPos;
 Cnt := 0;
 If P >= 0 Then Begin
  Q := P;
  If NextTok(Q) = T_AB Then
   While Cnt < Max Do Begin
    R0 := Q;
    T := NextTok(Q);
    If (T = T_AE) Or (T = T_EOF) Then Break;
    Q := R0;
    E^[Cnt].Key := '';
    SaveSrc(E^[Cnt].St);
    E^[Cnt].A := Q;
    E^[Cnt].Ref := RefAt(Q);
    SkipValue(Q);
    E^[Cnt].B := Q;
    Inc(Cnt);
   End;
 End;
 RestoreSrc(S0);
 CollectArray := Cnt;
End;

{ Valeur héritée (MediaBox, Rotate, Resources...) en remontant l'arbre des pages }
Function FindInh(Node: LongInt; Const Key: String; Var E: TRawEnt): Boolean;
Var
 S0: TSrcState;
 D: Integer;
 Cur, P, V, Q: LongInt;
 Par: Integer;
Begin
 FindInh := False;
 SaveSrc(S0);
 Cur := Node;
 For D := 0 To 24 Do Begin
  SrcMode := 0;
  P := EnterObj(Cur);
  If P < 0 Then Break;
  V := DictFind(P, Key);
  If V >= 0 Then Begin
   E.Key := Key;
   SaveSrc(E.St);
   E.A := V;
   Q := V;
   SkipValue(Q);
   E.B := Q;
   E.Ref := 0;
   FindInh := True;
   Break;
  End;
  V := DictFind(P, 'Parent');
  If V < 0 Then Break;
  Par := RefAt(V);
  If Par <= 0 Then Break;
  Cur := Par;
 End;
 RestoreSrc(S0);
End;

Function ObjSubtypeOf(N: LongInt): String;
Var
 S0: TSrcState;
 P: LongInt;
Begin
 ObjSubtypeOf := '';
 SaveSrc(S0);
 SrcMode := 0;
 P := EnterObj(N);
 If P >= 0 Then ObjSubtypeOf := ValName(DictFind(P, 'Subtype'));
 RestoreSrc(S0);
End;

{ Regroupe les objets du modèle par page (tri par comptage) }
Procedure BuildPageLists;
Var
 I, K, Pg: LongInt;
Begin
 GetMem(PgFirst, (PageCount + 3) * SizeOf(LongInt));
 GetMem(PgIdx, (ObjCount + 2) * SizeOf(LongInt));
 FillChar(PgFirst^, (PageCount + 3) * SizeOf(LongInt), 0);
 For I := 0 To ObjCount - 1 Do Begin
  Pg := ObjP(I)^.Page;
  If (Pg >= 1) And (Pg <= PageCount) Then Inc(PgFirst^[Pg + 1]);
 End;
 For I := 1 To PageCount + 1 Do PgFirst^[I] := PgFirst^[I] + PgFirst^[I - 1];
 { PgFirst[p] = début de la page p (p de 1 à PageCount), PgFirst[p+1] = fin }
 For I := 0 To ObjCount - 1 Do Begin
  Pg := ObjP(I)^.Page;
  If (Pg >= 1) And (Pg <= PageCount) Then Begin
   K := PgFirst^[Pg];
   PgIdx^[K] := I;
   Inc(PgFirst^[Pg]);
  End;
 End;
 { remettre les débuts }
 For I := PageCount + 1 DownTo 1 Do PgFirst^[I] := PgFirst^[I - 1];
 PgFirst^[0] := 0;
End;

Procedure FreePageLists;
Begin
 If PgFirst <> Nil Then FreeMem(PgFirst, (PageCount + 3) * SizeOf(LongInt));
 If PgIdx <> Nil Then FreeMem(PgIdx, (ObjCount + 2) * SizeOf(LongInt));
 PgFirst := Nil; PgIdx := Nil;
End;

{ Décision sur les annotations d'origine d'une page : conservées (inchangées)
  ou à réécrire. Remplit IncKeep / IncDrop. }
Procedure DecideAnnots(Pg: LongInt);
Var
 A, B, K, J, N, C: LongInt;
 AllOk: Boolean;
 O, O2: PObjRec;
Begin
 IncKeepN := 0; IncDropN := 0;
 A := PgFirst^[Pg]; B := PgFirst^[Pg + 1];
 For K := A To B - 1 Do Begin
  O := ObjP(PgIdx^[K]);
  If O^.Src <> 2 Then Continue;
  N := O^.SrcNum;
  For J := 0 To IncKeepN - 1 Do If IncKeep[J] = N Then Begin N := -1; Break; End;
  If N < 0 Then Continue;
  For J := 0 To IncDropN - 1 Do If IncDrop[J] = N Then Begin N := -1; Break; End;
  If N < 0 Then Continue;
  C := 0; AllOk := True;
  For J := A To B - 1 Do Begin
   O2 := ObjP(PgIdx^[J]);
   If (O2^.Src = 2) And (O2^.SrcNum = N) Then Begin
    Inc(C);
    If ObjSum(PgIdx^[J]) <> O2^.Sum Then AllOk := False;
   End;
  End;
  If AllOk And (C = O^.SrcCnt) Then Begin
   If IncKeepN < 4096 Then Begin IncKeep[IncKeepN] := N; Inc(IncKeepN); End;
  End
  Else If IncDropN < 4096 Then Begin IncDrop[IncDropN] := N; Inc(IncDropN); End;
 End;
End;

Function InKeep(N: LongInt): Boolean;
Var
 K: Integer;
Begin
 InKeep := False;
 For K := 0 To IncKeepN - 1 Do If IncKeep[K] = N Then Begin InKeep := True; Exit; End;
End;

{ Image XObject (et son masque doux) écrit à la demande }
Function EnsureImg(I: LongInt): LongInt;
Var
 SM, No: LongInt;
Begin
 EnsureImg := 0;
 If Not ImgKept(I) Then Exit;
 If IncImgNo^[I] = 0 Then Begin
  SM := 0;
  If (ImgP(I)^.SMIdx > 0) And ImgKept(ImgP(I)^.SMIdx) Then SM := EnsureImg(ImgP(I)^.SMIdx);
  No := IncNext; Inc(IncNext);
  WriteImageXObj(I, No, SM);
  IncImgNo^[I] := No;
 End;
 EnsureImg := IncImgNo^[I];
End;

{ Écrit un flux de contenu (compressé) pour la page Pg selon le mode ; 0 si vide }
Function WriteContentObj(Pg, Mode: Integer): LongInt;
Var
 Cnt, CompLen, No: LongInt;
 Comp: PByteBuf;
Begin
 WriteContentObj := 0;
 CMode := Mode;
 CapLen := 0;
 If CapBuf = Nil Then Begin CapSize := 65536; GetMem(CapBuf, CapSize); End;
 CapOn := True;
 Cnt := 0;
 ContentOf(Pg, Cnt);
 CapOn := False;
 If CapLen = 0 Then Exit;
 Comp := Nil; CompLen := 0;
 {$IFDEF FPC}
 If CapLen > 64 Then
  If DeflateBuf(CapBuf, CapLen, Comp, CompLen) Then
   If CompLen >= CapLen Then Begin FreeMem(Comp, CapLen + CapLen Div 6 + 128); Comp := Nil; End;
 {$ENDIF}
 No := IncNext; Inc(IncNext);
 BeginObj(No);
 If Comp <> Nil Then Begin
  WL('<< /Length ' + IStr(CompLen) + ' /Filter /FlateDecode >>');
  WL('stream');
  WriteBytes(Comp, CompLen);
  FreeMem(Comp, CapLen + CapLen Div 6 + 128);
 End
 Else Begin
  WL('<< /Length ' + IStr(CapLen) + ' >>');
  WL('stream');
  WriteBytes(CapBuf, CapLen);
 End;
 WL('');
 WL('endstream');
 EndObj;
 WriteContentObj := No;
End;

{ Images utilisées par le contenu émis dans le mode courant : écrit les XObjects }
Procedure CollectPageImages(Pg: Integer; Mode: Integer; Var L: Array Of LongInt; Var N: Integer);
Var
 K, I, J, Idx, Img: LongInt;
 Dup: Boolean;
Begin
 CMode := Mode;
 For K := PgFirst^[Pg] To PgFirst^[Pg + 1] - 1 Do Begin
  Idx := PgIdx^[K];
  If (ObjP(Idx)^.Kind = K_IMAGE) And ObjEmits(ObjP(Idx)^, Idx) Then Begin
   Img := ObjP(Idx)^.P0;
   If ImgKept(Img) Then Begin
    Dup := False;
    For J := 0 To N - 1 Do If L[J] = Img Then Dup := True;
    If (Not Dup) And (N <= High(L)) Then Begin L[N] := Img; Inc(N); EnsureImg(Img); End;
   End;
  End;
 End;
End;

Procedure NeedFonts;
Begin
 If IncFontBase = 0 Then Begin IncFontBase := IncNext; Inc(IncNext, 12); End;
End;

Procedure WriteOurFonts;
Var
 I: Integer;
Begin
 For I := 0 To 11 Do WS(' /AF' + IStr(I + 1) + ' ' + IStr(IncFontBase + I) + ' 0 R');
End;

Procedure WriteOurImages(Const L: Array Of LongInt; N: Integer);
Var
 I: Integer;
Begin
 For I := 0 To N - 1 Do WS(' /AIm' + IStr(L[I]) + ' ' + IStr(IncImgNo^[L[I]]) + ' 0 R');
End;

{ Contenu d'un tableau /Contents : copie des éléments sans les crochets }
Procedure CopyArrayInner(Const St: TSrcState; A, B: LongInt);
Var
 S0: TSrcState;
 P, L, R: LongInt;
 C: Integer;
 Buf: String;
Begin
 SaveSrc(S0);
 RestoreSrc(St);
 P := A; L := -1;
 While P < B Do Begin
  C := SB(P);
  If C = 91 Then Begin L := P; Break; End;
  Inc(P);
 End;
 R := B - 1;
 While R > P Do Begin
  C := SB(R);
  If C = 93 Then Break;
  Dec(R);
 End;
 RestoreSrc(S0);
 If (L >= 0) And (R > L) Then CopyRaw(St, L + 1, R) Else CopyRaw(St, A, B);
End;

Function EntIndex(E: PRawArr; N: Integer; Const Key: String): Integer;
Var
 I: Integer;
Begin
 EntIndex := -1;
 For I := 0 To N - 1 Do If E^[I].Key = Key Then Begin EntIndex := I; Exit; End;
End;

{ Écrit l'objet page numéro PgNo pour la page Pg du modèle }
Procedure WriteIncPage(Pg: Integer);
Var
 PRec: PPageRec;
 NE, NR, NA, NF, I, J, K: Integer;
 PageObj, A, B, FirstOrig, Idx, Cb, Ca, NewAnnCnt: LongInt;
 Flat, IsNew, GeoCh, RotCh, HasNewContent, Merge: Boolean;
 Ents, ResE, SubE: PRawArr;
 Inh: TRawEnt;
 Imgs: Array[0..63] Of LongInt;
 NImg: Integer;
 NewAnn: PLArr;
 OrigAnn: PRawArr;
 NOA: Integer;
 Sub: String;
 O: PObjRec;
 Alive, AnnAlive: LongInt;
 S0: TSrcState;
 X0, Y1v: Real;
 Own: Boolean;
 Skip: Boolean;
Begin
 PRec := PgP(Pg);
 PageObj := IncPgNo^[Pg];
 IsNew := PRec^.SrcPage = 0;
 NImg := 0;
 Cb := 0; Ca := 0;
 NewAnnCnt := 0;
 GetMem(Ents, SizeOf(TRawArr));
 GetMem(ResE, SizeOf(TRawArr));
 GetMem(SubE, SizeOf(TRawArr));
 GetMem(OrigAnn, SizeOf(TRawArr));
 GetMem(NewAnn, (PgFirst^[Pg + 1] - PgFirst^[Pg] + 2) * SizeOf(LongInt));
 NE := 0;
 SaveSrc(S0);
 If Not IsNew Then Begin
  SrcMode := 0;
  A := EnterObj(PRec^.SrcPage);
  NE := CollectDict(A, Ents, 4096);
 End;
 { --- état du contenu d'origine --- }
 CDropN := 0;
 FirstOrig := 0; Alive := 0; AnnAlive := 0;
 Flat := IsNew;
 HasNewContent := False;
 DecideAnnots(Pg);
 If Not IsNew Then Begin
  FirstOrig := -1;
  For K := PgFirst^[Pg] To PgFirst^[Pg + 1] - 1 Do Begin
   Idx := PgIdx^[K];
   O := ObjP(Idx);
   If O^.Src = 1 Then Begin
    If FirstOrig < 0 Then FirstOrig := Idx;
    Inc(Alive);
    If ObjSum(Idx) <> O^.Sum Then Begin
     Flat := True;
    End;
   End;
  End;
  If Alive <> PRec^.SrcCount Then Flat := True;
  If FirstOrig < 0 Then FirstOrig := 0;
 End;
 CFirstOrig := FirstOrig;
 { annotations d'origine à réécrire comme contenu / nouvelles annotations }
 If IncDropN > 0 Then For K := 0 To IncDropN - 1 Do If CDropN < 4096 Then Begin
  If CDrop = Nil Then GetMem(CDrop, 4100 * SizeOf(LongInt));
  CDrop^[CDropN] := IncDrop[K]; Inc(CDropN);
 End;
 If CDrop = Nil Then GetMem(CDrop, 4100 * SizeOf(LongInt));
 { --- images et flux de contenu --- }
 If Flat Then Begin
  CollectPageImages(Pg, 0, Imgs, NImg);
  Ca := WriteContentObj(Pg, 0);
 End
 Else Begin
  CollectPageImages(Pg, 1, Imgs, NImg);
  CollectPageImages(Pg, 2, Imgs, NImg);
  Cb := WriteContentObj(Pg, 1);
  Ca := WriteContentObj(Pg, 2);
 End;
 HasNewContent := (Cb <> 0) Or (Ca <> 0);
 If Flat Or HasNewContent Then NeedFonts;
 { --- annotations nouvelles ou réécrites --- }
 For K := PgFirst^[Pg] To PgFirst^[Pg + 1] - 1 Do Begin
  Idx := PgIdx^[K];
  O := ObjP(Idx);
  If IsAnnot(O^.Kind) Then Begin
   If (O^.Src = 2) And InKeep(O^.SrcNum) Then Continue;
   If O^.Src = 3 Then Continue;
   NewAnn^[NewAnnCnt] := IncNext;
   BeginObj(IncNext); Inc(IncNext);
   WL(AnnotOf(Pg, Idx));
   EndObj;
   Inc(NewAnnCnt);
  End;
 End;
 { --- géométrie --- }
 GeoCh := (Not IsNew) And ((PRec^.W <> PRec^.OrigW) Or (PRec^.H <> PRec^.OrigH));
 RotCh := (Not IsNew) And (PRec^.Rot <> PRec^.OrigRot);
 { --- dictionnaire de la page --- }
 BeginObj(PageObj);
 WS('<< /Type /Page');
 If IncTreeChanged Or IsNew Then WS(' /Parent ' + IStr(IncPagesRoot) + ' 0 R')
 Else Begin
  J := EntIndex(Ents, NE, 'Parent');
  If J >= 0 Then Begin WS(' /Parent'); CopyRaw(Ents^[J].St, Ents^[J].A, Ents^[J].B); End;
 End;
 { MediaBox }
 If IsNew Or GeoCh Then Begin
  If IsNew Then Begin X0 := 0; Y1v := PRec^.H; End Else Begin X0 := PRec^.MbX0; Y1v := PRec^.MbY1; End;
  WS(' /MediaBox [' + RStr(X0) + ' ' + RStr(Y1v - PRec^.H) + ' ' + RStr(X0 + PRec^.W) + ' ' + RStr(Y1v) + ']');
 End
 Else Begin
  J := EntIndex(Ents, NE, 'MediaBox');
  If J >= 0 Then Begin WS(' /MediaBox'); CopyRaw(Ents^[J].St, Ents^[J].A, Ents^[J].B); End
  Else If FindInh(PRec^.SrcPage, 'MediaBox', Inh) Then Begin WS(' /MediaBox'); CopyRaw(Inh.St, Inh.A, Inh.B); End;
 End;
 { Rotate }
 If IsNew Or RotCh Then Begin
  If PRec^.Rot <> 0 Then WS(' /Rotate ' + IStr((PRec^.Rot And 3) * 90));
  If RotCh And (PRec^.Rot = 0) Then WS(' /Rotate 0');
 End
 Else Begin
  J := EntIndex(Ents, NE, 'Rotate');
  If J >= 0 Then Begin WS(' /Rotate'); CopyRaw(Ents^[J].St, Ents^[J].A, Ents^[J].B); End
  Else If FindInh(PRec^.SrcPage, 'Rotate', Inh) Then Begin WS(' /Rotate'); CopyRaw(Inh.St, Inh.A, Inh.B); End;
 End;
 { Contents }
 If Flat Then Begin
  If Ca <> 0 Then WS(' /Contents ' + IStr(Ca) + ' 0 R');
 End
 Else If HasNewContent Then Begin
  WS(' /Contents [');
  If Cb <> 0 Then WS(' ' + IStr(Cb) + ' 0 R');
  J := EntIndex(Ents, NE, 'Contents');
  If J >= 0 Then Begin
   WS(' ');
   CopyArrayInner(Ents^[J].St, Ents^[J].A, Ents^[J].B);
  End;
  If Ca <> 0 Then WS(' ' + IStr(Ca) + ' 0 R');
  WS(' ]');
 End
 Else Begin
  J := EntIndex(Ents, NE, 'Contents');
  If J >= 0 Then Begin WS(' /Contents'); CopyRaw(Ents^[J].St, Ents^[J].A, Ents^[J].B); End;
 End;
 { Resources }
 If Flat Or IsNew Then Begin
  WS(' /Resources << /Font <<');
  WriteOurFonts;
  WS(' >>');
  If NImg > 0 Then Begin WS(' /XObject <<'); WriteOurImages(Imgs, NImg); WS(' >>'); End;
  WS(' >>');
 End
 Else If HasNewContent Then Begin
  Own := EntIndex(Ents, NE, 'Resources') >= 0;
  NR := 0;
  If Own Then Begin
   J := EntIndex(Ents, NE, 'Resources');
   RestoreSrc(Ents^[J].St);
   NR := CollectDict(Ents^[J].A, ResE, 4096);
  End
  Else If FindInh(PRec^.SrcPage, 'Resources', Inh) Then Begin
   RestoreSrc(Inh.St);
   NR := CollectDict(Inh.A, ResE, 4096);
  End;
  WS(' /Resources <<');
  For J := 0 To NR - 1 Do
   If (ResE^[J].Key <> 'Font') And (ResE^[J].Key <> 'XObject') Then Begin
    WS(' /' + ResE^[J].Key);
    CopyRaw(ResE^[J].St, ResE^[J].A, ResE^[J].B);
   End;
  WS(' /Font <<');
  J := EntIndex(ResE, NR, 'Font');
  If J >= 0 Then Begin
   RestoreSrc(ResE^[J].St);
   NF := CollectDict(ResE^[J].A, SubE, 4096);
   For K := 0 To NF - 1 Do Begin WS(' /' + SubE^[K].Key); CopyRaw(SubE^[K].St, SubE^[K].A, SubE^[K].B); End;
  End;
  WriteOurFonts;
  WS(' >>');
  J := EntIndex(ResE, NR, 'XObject');
  If (J >= 0) Or (NImg > 0) Then Begin
   WS(' /XObject <<');
   If J >= 0 Then Begin
    RestoreSrc(ResE^[J].St);
    NF := CollectDict(ResE^[J].A, SubE, 4096);
    For K := 0 To NF - 1 Do Begin WS(' /' + SubE^[K].Key); CopyRaw(SubE^[K].St, SubE^[K].A, SubE^[K].B); End;
   End;
   WriteOurImages(Imgs, NImg);
   WS(' >>');
  End;
  WS(' >>');
  RestoreSrc(S0);
 End
 Else Begin
  J := EntIndex(Ents, NE, 'Resources');
  If J >= 0 Then Begin WS(' /Resources'); CopyRaw(Ents^[J].St, Ents^[J].A, Ents^[J].B); End
  Else If IncTreeChanged Then
   If FindInh(PRec^.SrcPage, 'Resources', Inh) Then Begin WS(' /Resources'); CopyRaw(Inh.St, Inh.A, Inh.B); End;
 End;
 { Annots }
 NOA := 0;
 J := EntIndex(Ents, NE, 'Annots');
 If J >= 0 Then NOA := CollectArray(Ents^[J].St, Ents^[J].A, OrigAnn, 4096);
 If (NOA > 0) Or (NewAnnCnt > 0) Then Begin
  WS(' /Annots [');
  For K := 0 To NOA - 1 Do Begin
   Skip := False;
   If OrigAnn^[K].Ref > 0 Then
    If AnnSetHas(OrigAnn^[K].Ref) And (Not InKeep(OrigAnn^[K].Ref)) Then Skip := True;
   If Not Skip Then Begin
    WS(' ');
    CopyRaw(OrigAnn^[K].St, OrigAnn^[K].A, OrigAnn^[K].B);
   End;
  End;
  For K := 0 To NewAnnCnt - 1 Do WS(' ' + IStr(NewAnn^[K]) + ' 0 R');
  WS(' ]');
 End;
 { autres entrées d'origine }
 For J := 0 To NE - 1 Do Begin
  If (Ents^[J].Key = 'Type') Or (Ents^[J].Key = 'Parent') Or (Ents^[J].Key = 'MediaBox') Or
     (Ents^[J].Key = 'Rotate') Or (Ents^[J].Key = 'Contents') Or (Ents^[J].Key = 'Resources') Or
     (Ents^[J].Key = 'Annots') Then Continue;
  If GeoCh And (Ents^[J].Key = 'CropBox') Then Continue;
  WS(' /' + Ents^[J].Key);
  CopyRaw(Ents^[J].St, Ents^[J].A, Ents^[J].B);
 End;
 WL(' >>');
 EndObj;
 RestoreSrc(S0);
 FreeMem(Ents, SizeOf(TRawArr));
 FreeMem(ResE, SizeOf(TRawArr));
 FreeMem(SubE, SizeOf(TRawArr));
 FreeMem(OrigAnn, SizeOf(TRawArr));
 FreeMem(NewAnn, (PgFirst^[Pg + 1] - PgFirst^[Pg] + 2) * SizeOf(LongInt));
End;

{ La page a-t-elle besoin d'être réécrite ? }
Function PageNeedsWrite(Pg: Integer): Boolean;
Var
 PRec: PPageRec;
 K, Idx, Alive, AnnAlive: LongInt;
 O: PObjRec;
Begin
 PageNeedsWrite := True;
 PRec := PgP(Pg);
 If PRec^.SrcPage = 0 Then Exit;
 If IncTreeChanged Then Exit;
 If (PRec^.W <> PRec^.OrigW) Or (PRec^.H <> PRec^.OrigH) Or (PRec^.Rot <> PRec^.OrigRot) Then Exit;
 Alive := 0; AnnAlive := 0;
 For K := PgFirst^[Pg] To PgFirst^[Pg + 1] - 1 Do Begin
  Idx := PgIdx^[K];
  O := ObjP(Idx);
  Case O^.Src Of
   0: Exit;
   1: Begin
    Inc(Alive);
    If ObjSum(Idx) <> O^.Sum Then Exit;
   End;
   2: Begin
    Inc(AnnAlive);
    If ObjSum(Idx) <> O^.Sum Then Exit;
   End;
  End;
 End;
 If Alive <> PRec^.SrcCount Then Exit;
 If AnnAlive <> PRec^.SrcAnnObjs Then Exit;
 PageNeedsWrite := False;
End;

Procedure SortXList;
Var
 Gap, I, J: LongInt;
 TN, TO_: LongInt;
Begin
 Gap := XCnt Div 2;
 While Gap > 0 Do Begin
  For I := Gap To XCnt - 1 Do Begin
   TN := XList^[I * 2]; TO_ := XList^[I * 2 + 1];
   J := I;
   While (J >= Gap) And (XList^[(J - Gap) * 2] > TN) Do Begin
    XList^[J * 2] := XList^[(J - Gap) * 2];
    XList^[J * 2 + 1] := XList^[(J - Gap) * 2 + 1];
    Dec(J, Gap);
   End;
   XList^[J * 2] := TN; XList^[J * 2 + 1] := TO_;
  End;
  Gap := Gap Div 2;
 End;
End;

Procedure WriteBE(Var Buf: PByteBuf; Var Len: LongInt; V: LongInt; N: Integer);
Var
 I: Integer;
Begin
 For I := N - 1 DownTo 0 Do Begin
  Buf^[Len] := (V Shr (I * 8)) And 255;
  Inc(Len);
 End;
End;

{ Dernier "startxref" du fichier d'origine ; détecte une table ou un flux de références }
Function ReadStartXref(Var Prev: LongInt; Var IsStream: Boolean): Boolean;
Var
 Buf: Array[0..1499] Of Byte;
 N: Integer;
 Got: Word;
 I, J: Integer;
 V: LongInt;
 Sz: LongInt;
 Found: Boolean;
Begin
 ReadStartXref := False;
 Sz := FileSize(PF);
 If Sz > 1500 Then Seek(PF, Sz - 1500) Else Seek(PF, 0);
 Got := 0;
 BlockRead(PF, Buf, 1500, Got);
 N := Got;
 I := N - 9;
 Found := False;
 While I >= 0 Do Begin
  If (Buf[I] = 115) And (Buf[I + 1] = 116) And (Buf[I + 2] = 97) And (Buf[I + 3] = 114) And (Buf[I + 4] = 116) And
     (Buf[I + 5] = 120) And (Buf[I + 6] = 114) And (Buf[I + 7] = 101) And (Buf[I + 8] = 102) Then Begin Found := True; Break; End;
  Dec(I);
 End;
 If Not Found Then Exit;
 J := I + 9;
 While (J < N) And ((Buf[J] < 48) Or (Buf[J] > 57)) Do Inc(J);
 V := 0;
 While (J < N) And (Buf[J] >= 48) And (Buf[J] <= 57) Do Begin V := V * 10 + (Buf[J] - 48); Inc(J); End;
 Prev := V;
 SrcMode := 0;
 RBase := -1; RLen := 0;
 J := V;
 While IsWs(SB(J)) Do Inc(J);
 IsStream := Not ((SB(J) = 120) And (SB(J + 1) = 114) And (SB(J + 2) = 101) And (SB(J + 3) = 102));
 ReadStartXref := True;
End;

Procedure WriteXrefSection(Var StartPos: LongInt; Const IDRaw: TRawEnt; HasID: Boolean);
Var
 I, RunStart, RunN: LongInt;
 S: String;
 XNo: LongInt;
 Buf: PByteBuf;
 Len: LongInt;
 Last: LongInt;
 SzVal: LongInt;
Begin
 If IncXStream Then Begin
  XNo := IncNext; Inc(IncNext);
  IncAdd(XNo, OutPos);
 End;
 SortXList;
 SzVal := IncNext;
 If IncXStream Then Begin
  GetMem(Buf, XCnt * 7 + 64);
  Len := 0;
  For I := 0 To XCnt - 1 Do Begin
   Buf^[Len] := 1; Inc(Len);
   WriteBE(Buf, Len, XList^[I * 2 + 1], 4);
   WriteBE(Buf, Len, 0, 2);
  End;
  StartPos := OutPos;
  WL(IStr(XNo) + ' 0 obj');
  WS('<< /Type /XRef /Size ' + IStr(SzVal) + ' /W [1 4 2] /Index [');
  I := 0;
  While I < XCnt Do Begin
   RunStart := XList^[I * 2];
   RunN := 1;
   While (I + RunN < XCnt) And (XList^[(I + RunN) * 2] = RunStart + RunN) Do Inc(RunN);
   WS(IStr(RunStart) + ' ' + IStr(RunN) + ' ');
   I := I + RunN;
  End;
  S := '] /Root ' + IStr(IncRoot) + ' 0 R /Prev ' + IStr(IncPrev);
  If IncInfo > 0 Then S := S + ' /Info ' + IStr(IncInfo) + ' 0 R';
  WS(S);
  If HasID Then Begin WS(' /ID'); CopyRaw(IDRaw.St, IDRaw.A, IDRaw.B); End;
  WL(' /Length ' + IStr(Len) + ' >>');
  WL('stream');
  WriteBytes(Buf, Len);
  WL('');
  WL('endstream');
  WL('endobj');
  FreeMem(Buf, XCnt * 7 + 64);
 End
 Else Begin
  StartPos := OutPos;
  WL('xref');
  I := 0;
  While I < XCnt Do Begin
   RunStart := XList^[I * 2];
   RunN := 1;
   While (I + RunN < XCnt) And (XList^[(I + RunN) * 2] = RunStart + RunN) Do Inc(RunN);
   WL(IStr(RunStart) + ' ' + IStr(RunN));
   For Last := 0 To RunN - 1 Do Begin
    S := IStr(XList^[(I + Last) * 2 + 1]);
    While Length(S) < 10 Do S := '0' + S;
    WL(S + ' 00000 n ');
   End;
   I := I + RunN;
  End;
  WL('trailer');
  S := '<< /Size ' + IStr(SzVal) + ' /Root ' + IStr(IncRoot) + ' 0 R /Prev ' + IStr(IncPrev);
  If IncInfo > 0 Then S := S + ' /Info ' + IStr(IncInfo) + ' 0 R';
  WS(S);
  If HasID Then Begin WS(' /ID'); CopyRaw(IDRaw.St, IDRaw.A, IDRaw.B); End;
  WL(' >>');
 End;
End;

Procedure PdfInfoObj(No: LongInt);
Var
 S: String;
Begin
 BeginObj(No);
 S := '<< /Producer (CloneDRAW ACROBAT) /ModDate (' + PdfDate + ')';
 If DocTitle <> '' Then S := S + ' /Title ' + PdfStr(DocTitle);
 If DocAuthor <> '' Then S := S + ' /Author ' + PdfStr(DocAuthor);
 If DocSubject <> '' Then S := S + ' /Subject ' + PdfStr(DocSubject);
 If DocKeywords <> '' Then S := S + ' /Keywords ' + PdfStr(DocKeywords);
 If DocCreator <> '' Then S := S + ' /Creator ' + PdfStr(DocCreator);
 WL(S + ' >>');
 EndObj;
End;

Function SaveIncremental(Const OutName: String; Var Err: String): Boolean;
Var
 I, Pg: LongInt;
 TmpName: String;
 Buf: PByteBuf;
 Got: Word;
 Done: LongInt;
 P, V, Q: LongInt;
 MaxN: LongInt;
 TrP: LongInt;
 IDEnt: TRawEnt;
 HasID: Boolean;
 XStart: LongInt;
 Ok: Boolean;
 PagesNum: LongInt;
 SrcSz: LongInt;
Begin
 SaveIncremental := False;
 Err := '';
 If (Not SrcValid) Or (SrcFile = '') Or (Not FileExists(SrcFile)) Then Begin Err := 'Fichier d''origine introuvable.'; Exit; End;
 InitPdfBuffers;
 {$I-}
 Assign(PF, SrcFile);
 Reset(PF, 1);
 {$I+}
 If IOResult <> 0 Then Begin Err := 'Impossible de relire le fichier d''origine.'; Exit; End;
 PFSize := FileSize(PF);
 If PFSize <> SrcSize Then Begin
  Close(PF);
  Err := 'Le fichier d''origine a été modifié depuis son ouverture.';
  Exit;
 End;
 For I := 0 To PdfCap - 1 Do Begin ObjPos^[I] := -1; ObjStmNo^[I] := 0; ObjStmOff^[I] := 0; End;
 MaxObjNum := 0; RootNum := 0; InfoNum := 0; StmCacheNum := 0; RBase := -1; RLen := 0; SrcMode := 0;
 DocEncrypted := False;
 NFonts := 0; NXObjs := 0;
 ScanFile;
 ProcessObjects;
 If DocEncrypted Or (RootNum = 0) Then Begin Close(PF); Err := 'Structure du fichier d''origine non exploitable.'; Exit; End;
 SrcMode := 0;
 If Not ReadStartXref(IncPrev, IncXStream) Then Begin Close(PF); Err := 'Table des références introuvable.'; Exit; End;
 IncRoot := RootNum;
 { arbre des pages }
 SrcMode := 0;
 P := EnterObj(RootNum);
 IncPagesRoot := 0;
 If P >= 0 Then Begin V := DictFind(P, 'Pages'); If V >= 0 Then IncPagesRoot := RefAt(V); End;
 If IncPagesRoot = 0 Then Begin Close(PF); Err := 'Arbre des pages introuvable.'; Exit; End;
 { trailer d'origine : /Size et /ID }
 HasID := False;
 IncSize := MaxObjNum + 1;
 SrcMode := 0;
 TrP := -1;
 If IncXStream Then Begin If XRefBest > 0 Then TrP := ObjPos^[XRefBest]; End
 Else If TrCount > 0 Then TrP := TrPos[TrCount - 1];
 If TrP >= 0 Then Begin
  V := DictFind(TrP, 'Size');
  If V >= 0 Then Begin I := ValInt(V, 0); If I > IncSize Then IncSize := I; End;
  V := DictFind(TrP, 'ID');
  If V >= 0 Then Begin
   HasID := True;
   IDEnt.Key := 'ID'; SaveSrc(IDEnt.St); IDEnt.A := V; Q := V; SkipValue(Q); IDEnt.B := Q;
  End;
 End;
 IncInfo := InfoNum;
 { préparation }
 BuildPageLists;
 GetMem(IncPgNo, (PageCount + 2) * SizeOf(LongInt));
 GetMem(IncImgNo, (ImgCount + 2) * SizeOf(LongInt));
 FillChar(IncImgNo^, (ImgCount + 2) * SizeOf(LongInt), 0);
 IncNext := IncSize;
 IncFontBase := 0;
 IncTreeChanged := PageCount <> OrigPageCnt;
 For Pg := 1 To PageCount Do
  If (Pg <= OrigPageCnt) And (PgP(Pg)^.SrcPage <> OrigOrder^[Pg - 1]) Then IncTreeChanged := True;
 For Pg := 1 To PageCount Do
  If PgP(Pg)^.SrcPage = 0 Then IncTreeChanged := True;
 For Pg := 1 To PageCount Do
  If PgP(Pg)^.SrcPage > 0 Then IncPgNo^[Pg] := PgP(Pg)^.SrcPage
  Else Begin IncPgNo^[Pg] := IncNext; Inc(IncNext); End;
 { fichier de sortie : copie de l'original dans un fichier temporaire }
 TmpName := OutName + '.tmp';
 {$I-}
 Assign(OutF, TmpName);
 Rewrite(OutF, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  Close(PF); FreePageLists; FreeMem(IncPgNo, (PageCount + 2) * SizeOf(LongInt));
  FreeMem(IncImgNo, (ImgCount + 2) * SizeOf(LongInt));
  Err := 'Impossible de créer le fichier de sortie.'; Exit;
 End;
 OutErr := False; OutPos := 0;
 GetMem(Buf, 32768);
 Seek(PF, 0);
 Done := 0;
 While Done < PFSize Do Begin
  Got := 0;
  BlockRead(PF, Buf^, 32768, Got);
  If Got = 0 Then Break;
  {$I-}
  BlockWrite(OutF, Buf^, Got);
  {$I+}
  If IOResult <> 0 Then OutErr := True;
  Done := Done + Got;
 End;
 FreeMem(Buf, 32768);
 OutPos := Done;
 RBase := -1; RLen := 0;
 IncMode := True;
 XCnt := 0;
 If XList = Nil Then Begin XCap := 1024; GetMem(XList, XCap * 2 * SizeOf(LongInt)); End;
 FPre := 'AF'; IPre := 'AIm';
 If CDrop = Nil Then GetMem(CDrop, 4100 * SizeOf(LongInt));
 { séparateur }
 WL('');
 { pages }
 For Pg := 1 To PageCount Do Begin
  If OutErr Then Break;
  If PageNeedsWrite(Pg) Then WriteIncPage(Pg);
 End;
 { racine de l'arbre des pages }
 If (Not OutErr) And IncTreeChanged Then Begin
  BeginObj(IncPagesRoot);
  WS('<< /Type /Pages /Count ' + IStr(PageCount) + ' /Kids [');
  For Pg := 1 To PageCount Do Begin
   WS(' ' + IStr(IncPgNo^[Pg]) + ' 0 R');
  End;
  WL(' ] >>');
  EndObj;
 End;
 { polices ajoutées }
 If IncFontBase > 0 Then WriteFontObjs(IncFontBase);
 { informations du document }
 If InfoDirty Then Begin
  If IncInfo = 0 Then Begin IncInfo := IncNext; Inc(IncNext); End;
  PdfInfoObj(IncInfo);
 End;
 WriteXrefSection(XStart, IDEnt, HasID);
 WL('startxref');
 WL(IStr(XStart));
 WL('%%EOF');
 {$I-}
 Close(OutF);
 {$I+}
 If IOResult <> 0 Then OutErr := True;
 IncMode := False;
 FreePageLists;
 FreeMem(IncPgNo, (PageCount + 2) * SizeOf(LongInt));
 FreeMem(IncImgNo, (ImgCount + 2) * SizeOf(LongInt));
 If CapBuf <> Nil Then Begin FreeMem(CapBuf, CapSize); CapBuf := Nil; End;
 Close(PF);
 CMode := 0; CDropN := 0; FPre := 'F'; IPre := 'Im';
 If OutErr Then Begin
  {$I-} Erase(OutF); {$I+}
  If IOResult <> 0 Then ;
  Err := 'Erreur d''écriture.';
  Exit;
 End;
 { remplacement du fichier de destination }
 If FileExists(OutName) Then Begin
  {$I-}
  Assign(OutF, OutName);
  Erase(OutF);
  {$I+}
  If IOResult <> 0 Then Begin Err := 'Impossible de remplacer le fichier de destination.'; Exit; End;
 End;
 {$I-}
 Assign(OutF, TmpName);
 Rename(OutF, OutName);
 {$I+}
 If IOResult <> 0 Then Begin Err := 'Impossible de renommer le fichier enregistré.'; Exit; End;
 SaveIncremental := True;
End;

{ ---------------------------------------------------------------------- }
{ Interface : primitives                                                    }
{ ---------------------------------------------------------------------- }

Const
 PathSep = {$IFDEF FPC} DirectorySeparator {$ELSE} '\' {$ENDIF};
 ZoomSteps: Array[0..11] Of Integer = (25, 33, 50, 63, 75, 100, 125, 150, 200, 300, 400, 800);

Procedure Bevel(X1, Y1, X2, Y2: Integer; Raised: Boolean);
Begin
 If Raised Then SetColor(White) Else SetColor(Black);
 Line(X1, Y1, X2 - 1, Y1);
 Line(X1, Y1, X1, Y2 - 1);
 If Raised Then SetColor(Black) Else SetColor(White);
 Line(X2, Y1, X2, Y2);
 Line(X1, Y2, X2, Y2);
 If Raised Then SetColor(DarkGray) Else SetColor(DarkGray);
 If Raised Then Begin
  Line(X2 - 1, Y1 + 1, X2 - 1, Y2 - 1);
  Line(X1 + 1, Y2 - 1, X2 - 1, Y2 - 1);
 End;
End;

Procedure Panel(X1, Y1, X2, Y2: Integer; Raised: Boolean);
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(X1, Y1, X2, Y2);
 Bevel(X1, Y1, X2, Y2, Raised);
End;

Procedure Field3D(X1, Y1, X2, Y2: Integer);
Begin
 SetFillStyle(SolidFill, White);
 Bar(X1, Y1, X2, Y2);
 SetColor(DarkGray);
 Line(X1, Y1, X2, Y1);
 Line(X1, Y1, X1, Y2);
 SetColor(Black);
 Line(X1 + 1, Y1 + 1, X2 - 1, Y1 + 1);
 Line(X1 + 1, Y1 + 1, X1 + 1, Y2 - 1);
 SetColor(White);
 Line(X2, Y1, X2, Y2);
 Line(X1, Y2, X2, Y2);
End;

Procedure PushButton(X1, Y1, X2, Y2: Integer; Const Cap: String; Down: Boolean);
Begin
 SetFillStyle(SolidFill, LightGray);
 Bar(X1, Y1, X2, Y2);
 If Down Then Bevel(X1, Y1, X2, Y2, False) Else Bevel(X1, Y1, X2, Y2, True);
 SetColor(Black);
 If Down Then DSC(X1 + 1, (Y1 + Y2) Div 2 - 3, X2 - X1, Cap) Else DSC(X1, (Y1 + Y2) Div 2 - 4, X2 - X1, Cap);
End;

Procedure Tri(X1, Y1, X2, Y2, X3, Y3, Col: Integer);
Var
 P: Array[0..2] Of PointType;
Begin
 P[0].X := X1; P[0].Y := Y1; P[1].X := X2; P[1].Y := Y2; P[2].X := X3; P[2].Y := Y3;
 SetFillStyle(SolidFill, Col);
 SetColor(Col);
 FillPoly(3, P);
End;

Procedure SetFullView;
Begin
 SetViewPort(0, 0, GetMaxX, GetMaxY, True);
End;

Procedure ShowProgress(Const Msg: String);
Begin
 SetFullView;
 SetFillStyle(SolidFill, LightGray);
 Bar(0, GetMaxY - STATUS_H + 1, GetMaxX, GetMaxY);
 SetColor(Black);
 DS(6, GetMaxY - STATUS_H + 6, Msg);
End;

{ ---------------------------------------------------------------------- }
{ Mise en page de la fenêtre                                                }
{ ---------------------------------------------------------------------- }

Procedure CalcLayout;
Begin
 If FullScreen Then Begin
  ViewL := 0;
  ViewT := MENU_H;
 End
 Else Begin
  If NavVisible <> 0 Then ViewL := NAV_W Else ViewL := 0;
  If ToolbarVisible <> 0 Then ViewT := MENU_H + TOOL_H Else ViewT := MENU_H;
 End;
 ViewR := GetMaxX - SBAR;
 ViewB := GetMaxY - STATUS_H - SBAR;
 ViewW := ViewR - ViewL + 1;
 ViewH := ViewB - ViewT + 1;
End;

Function PageHeightPx(I: Integer): LongInt;
Begin
 PageHeightPx := DispHOf(I, Scale);
End;

Procedure Relayout;
Var
 I: Integer;
 Y: LongInt;
 MW, W: LongInt;
 PW, PH: Real;
Begin
 CalcLayout;
 If Zoom < 10 Then Zoom := 10;
 If Zoom > 1600 Then Zoom := 1600;
 Scale := (LongInt(Zoom) * 1024 + 37) Div 75;
 Y := 8;
 MW := 0;
 For I := 1 To PageCount Do Begin
  W := DispWOf(I, Scale);
  If W > MW Then MW := W;
  If Continuous <> 0 Then Begin
   PgP(I)^.Top := Y;
   Y := Y + DispHOf(I, Scale) + 8;
  End
  Else Begin
   PgP(I)^.Top := 8;
  End;
 End;
 If Continuous = 0 Then Y := DispHOf(CurPage, Scale) + 16;
 DocH := Y;
 DocW := MW + 16;
 If ScrollY > DocH - ViewH Then ScrollY := DocH - ViewH;
 If ScrollY < 0 Then ScrollY := 0;
 If ScrollX > DocW - ViewW Then ScrollX := DocW - ViewW;
 If ScrollX < 0 Then ScrollX := 0;
End;

Procedure ApplyFit;
Var
 PW, PH, ZW, ZP: Real;
 R: Integer;
Begin
 CalcLayout;
 If (FitMode = 0) Or (PageCount = 0) Then Exit;
 If (PgP(CurPage)^.Rot And 1) <> 0 Then Begin PW := PgP(CurPage)^.H; PH := PgP(CurPage)^.W; End
 Else Begin PW := PgP(CurPage)^.W; PH := PgP(CurPage)^.H; End;
 ZW := (ViewW - 24) / PW * 75;
 ZP := (ViewH - 20) / PH * 75;
 If FitMode = 1 Then Zoom := Trunc(ZW)
 Else If ZW < ZP Then Zoom := Trunc(ZW)
 Else Zoom := Trunc(ZP);
 If Zoom < 10 Then Zoom := 10;
End;

Procedure ClampScroll;
Begin
 If ScrollY > DocH - ViewH Then ScrollY := DocH - ViewH;
 If ScrollY < 0 Then ScrollY := 0;
 If ScrollX > DocW - ViewW Then ScrollX := DocW - ViewW;
 If ScrollX < 0 Then ScrollX := 0;
End;

{ Origine (dans la fenêtre graphique de la vue) de la page I }
Procedure PageOrigin(I: Integer; Var OX, OY: LongInt);
Var
 W: LongInt;
Begin
 W := DispWOf(I, Scale);
 If DocW > ViewW Then OX := (DocW - W) Div 2 - ScrollX
 Else OX := (ViewW - W) Div 2;
 OY := PgP(I)^.Top - ScrollY;
End;

Function PageVisible(I: Integer): Boolean;
Var
 OX, OY: LongInt;
Begin
 If (Continuous = 0) And (I <> CurPage) Then Begin PageVisible := False; Exit; End;
 PageOrigin(I, OX, OY);
 PageVisible := (OY + DispHOf(I, Scale) >= -4) And (OY <= ViewH + 4);
End;

{ Page sous le pointeur ; configure le contexte (coordonnées d'écran) }
Function PageAt(SX, SY: LongInt; Var Pg: Integer; Var PXp, PYp: LongInt; Strict: Boolean): Boolean;
Var
 I, Best: Integer;
 OX, OY, W, H: LongInt;
 Dist, BD: LongInt;
Begin
 PageAt := False;
 Best := 0;
 BD := MaxLongInt;
 For I := 1 To PageCount Do Begin
  If (Continuous = 0) And (I <> CurPage) Then Continue;
  PageOrigin(I, OX, OY);
  OX := OX + ViewL; OY := OY + ViewT;
  W := DispWOf(I, Scale); H := DispHOf(I, Scale);
  If (SX >= OX) And (SX <= OX + W) And (SY >= OY) And (SY <= OY + H) Then Begin
   Best := I; BD := 0; Break;
  End;
  If SY < OY Then Dist := OY - SY Else If SY > OY + H Then Dist := SY - OY - H Else Dist := 0;
  If Dist < BD Then Begin BD := Dist; Best := I; End;
 End;
 If Best = 0 Then Exit;
 If Strict And (BD <> 0) Then Exit;
 Pg := Best;
 PageOrigin(Best, OX, OY);
 SetCtx(Best, OX + ViewL, OY + ViewT, Scale);
 Unmap(SX, SY, PXp, PYp);
 PageAt := True;
End;

Procedure UpdateCurPage;
Var
 I: Integer;
 Mid: LongInt;
Begin
 If Continuous = 0 Then Exit;
 Mid := ScrollY + ViewH Div 3;
 For I := PageCount DownTo 1 Do
  If PgP(I)^.Top <= Mid Then Begin
   CurPage := I;
   Exit;
  End;
 CurPage := 1;
End;

Procedure GotoPage(N: Integer);
Begin
 If N < 1 Then N := 1;
 If N > PageCount Then N := PageCount;
 CurPage := N;
 If Continuous <> 0 Then Begin
  ScrollY := PgP(N)^.Top - 8;
  Relayout;
 End
 Else Begin
  ScrollY := 0;
  Relayout;
 End;
 If FitMode <> 0 Then Begin
  ApplyFit;
  Relayout;
 End;
End;

Procedure ScrollToObj(I: Integer);
Var
 OX, OY: LongInt;
 SX1, SY1, SX2, SY2: LongInt;
 Pg: Integer;
Begin
 If (I < 0) Or (I >= ObjCount) Then Exit;
 Pg := ObjP(I)^.Page;
 If Continuous = 0 Then CurPage := Pg;
 Relayout;
 PageOrigin(Pg, OX, OY);
 SetCtx(Pg, OX, OY, Scale);
 ScrBox(ObjP(I)^, SX1, SY1, SX2, SY2);
 If (SY1 < 20) Or (SY2 > ViewH - 20) Then ScrollY := ScrollY + SY1 - ViewH Div 3;
 If (SX1 < 10) Or (SX2 > ViewW - 10) Then ScrollX := ScrollX + SX1 - ViewW Div 3;
 ClampScroll;
 If Continuous <> 0 Then UpdateCurPage;
End;

{ ---------------------------------------------------------------------- }
{ Menus                                                                      }
{ ---------------------------------------------------------------------- }

Procedure MItem(M: Integer; Const Cap, Sc: String; Cmd: Integer);
Begin
 With Menus[M] Do Begin
  Items[ItemCount].Caption := Cap;
  Items[ItemCount].Shortcut := Sc;
  Items[ItemCount].Cmd := Cmd;
  Items[ItemCount].Separator := False;
  Items[ItemCount].Checked := False;
  Inc(ItemCount);
 End;
End;

Procedure MSep(M: Integer);
Begin
 With Menus[M] Do Begin
  Items[ItemCount].Caption := '';
  Items[ItemCount].Shortcut := '';
  Items[ItemCount].Cmd := 0;
  Items[ItemCount].Separator := True;
  Items[ItemCount].Checked := False;
  Inc(ItemCount);
 End;
End;

Procedure InitMenus;
Var
 M, I, Need: Integer;
Begin
 FillChar(Menus, SizeOf(Menus), 0);
 Menus[MN_FILE].Title := 'Fichier';
 MItem(MN_FILE, 'Nouveau', 'Ctrl+N', CM_NEW);
 MItem(MN_FILE, 'Ouvrir...', 'Ctrl+O', CM_OPEN);
 MItem(MN_FILE, 'Enregistrer', 'Ctrl+S', CM_SAVE);
 MItem(MN_FILE, 'Enregistrer sous...', 'F2', CM_SAVEAS);
 MSep(MN_FILE);
 MItem(MN_FILE, 'Insérer un fichier PDF...', '', CM_INSFILE);
 MItem(MN_FILE, 'Extraire des pages...', '', CM_EXTRACT);
 MItem(MN_FILE, 'Exporter en texte...', '', CM_EXPTXT);
 MItem(MN_FILE, 'Exporter la page en BMP...', '', CM_EXPBMP);
 MSep(MN_FILE);
 MItem(MN_FILE, 'Propriétés du document...', 'Ctrl+D', CM_PROPS);
 MSep(MN_FILE);
 MItem(MN_FILE, 'Quitter', 'Ctrl+Q', CM_QUIT);

 Menus[MN_EDIT].Title := 'Édition';
 MItem(MN_EDIT, 'Annuler', 'Ctrl+Z', CM_UNDO);
 MItem(MN_EDIT, 'Rétablir', 'Ctrl+Y', CM_REDO);
 MSep(MN_EDIT);
 MItem(MN_EDIT, 'Couper', 'Ctrl+X', CM_CUT);
 MItem(MN_EDIT, 'Copier', 'Ctrl+C', CM_COPY);
 MItem(MN_EDIT, 'Coller', 'Ctrl+V', CM_PASTE);
 MItem(MN_EDIT, 'Supprimer', 'Suppr', CM_DELETE);
 MItem(MN_EDIT, 'Dupliquer', 'Ctrl+J', CM_DUP);
 MItem(MN_EDIT, 'Désélectionner', 'Échap', CM_DESEL);
 MSep(MN_EDIT);
 MItem(MN_EDIT, 'Modifier le texte', 'Entrée', CM_EDITTXT);
 MItem(MN_EDIT, 'Propriétés de l''objet...', 'Ctrl+P', CM_OBJPROPS);
 MItem(MN_EDIT, 'Couleur...', '', CM_COLOR);
 MSep(MN_EDIT);
 MItem(MN_EDIT, 'Rechercher...', 'Ctrl+F', CM_FIND);
 MItem(MN_EDIT, 'Rechercher le suivant', 'F3', CM_FINDNEXT);

 Menus[MN_VIEW].Title := 'Affichage';
 MItem(MN_VIEW, 'Zoom avant', '+', CM_ZOOMIN);
 MItem(MN_VIEW, 'Zoom arrière', '-', CM_ZOOMOUT);
 MItem(MN_VIEW, 'Zoom à 100 %', '1', CM_Z100);
 MItem(MN_VIEW, 'Ajuster à la largeur', '2', CM_FITW);
 MItem(MN_VIEW, 'Page entière', '3', CM_FITP);
 MItem(MN_VIEW, 'Zoom...', '', CM_ZOOMSET);
 MSep(MN_VIEW);
 MItem(MN_VIEW, 'Défilement continu', '', CM_CONT);
 MItem(MN_VIEW, 'Volet de navigation', 'F4', CM_NAV);
 MItem(MN_VIEW, 'Pages / Commentaires', 'F5', CM_NAVMODE);
 MItem(MN_VIEW, 'Plein écran', 'Ctrl+L', CM_FULL);
 MSep(MN_VIEW);
 MItem(MN_VIEW, 'Page précédente', 'PgPréc', CM_PREV);
 MItem(MN_VIEW, 'Page suivante', 'PgSuiv', CM_NEXT);
 MItem(MN_VIEW, 'Première page', 'Début', CM_FIRST);
 MItem(MN_VIEW, 'Dernière page', 'Fin', CM_LAST);
 MItem(MN_VIEW, 'Aller à la page...', 'Ctrl+G', CM_GOTO);

 Menus[MN_PAGE].Title := 'Page';
 MItem(MN_PAGE, 'Insérer une page vierge', '', CM_PGINS);
 MItem(MN_PAGE, 'Dupliquer la page', '', CM_PGDUP);
 MItem(MN_PAGE, 'Supprimer la page', '', CM_PGDEL);
 MSep(MN_PAGE);
 MItem(MN_PAGE, 'Pivoter à droite', '', CM_ROTR);
 MItem(MN_PAGE, 'Pivoter à gauche', '', CM_ROTL);
 MItem(MN_PAGE, 'Déplacer vers le haut', '', CM_PGUP);
 MItem(MN_PAGE, 'Déplacer vers le bas', '', CM_PGDOWN);
 MSep(MN_PAGE);
 MItem(MN_PAGE, 'Recadrer la page...', '', CM_CROP);
 MItem(MN_PAGE, 'Taille de la page...', '', CM_PGSIZE);
 MItem(MN_PAGE, 'Numéroter les pages...', '', CM_NUMBER);
 MItem(MN_PAGE, 'Ajouter un filigrane...', '', CM_WATER);

 Menus[MN_TOOLS].Title := 'Outils';
 MItem(MN_TOOLS, 'Sélection', 'V', CM_TOOL0 + TL_SELECT);
 MItem(MN_TOOLS, 'Main', 'H', CM_TOOL0 + TL_HAND);
 MItem(MN_TOOLS, 'Loupe', 'Z', CM_TOOL0 + TL_ZOOM);
 MSep(MN_TOOLS);
 MItem(MN_TOOLS, 'Ajouter du texte', 'T', CM_TOOL0 + TL_TEXT);
 MItem(MN_TOOLS, 'Note adhésive', 'N', CM_TOOL0 + TL_NOTE);
 MItem(MN_TOOLS, 'Surligner', 'K', CM_TOOL0 + TL_HILITE);
 MItem(MN_TOOLS, 'Souligner', 'U', CM_TOOL0 + TL_UNDER);
 MItem(MN_TOOLS, 'Barrer', 'S', CM_TOOL0 + TL_STRIKE);
 MItem(MN_TOOLS, 'Crayon', 'P', CM_TOOL0 + TL_PENCIL);
 MItem(MN_TOOLS, 'Ligne', 'L', CM_TOOL0 + TL_LINE);
 MItem(MN_TOOLS, 'Flèche', 'A', CM_TOOL0 + TL_ARROW);
 MItem(MN_TOOLS, 'Rectangle', 'R', CM_TOOL0 + TL_RECT);
 MItem(MN_TOOLS, 'Ovale', 'O', CM_TOOL0 + TL_OVAL);
 MItem(MN_TOOLS, 'Tampon', 'M', CM_TOOL0 + TL_STAMP);
 MItem(MN_TOOLS, 'Signer', 'G', CM_TOOL0 + TL_SIGN);
 MItem(MN_TOOLS, 'Biffer', 'X', CM_TOOL0 + TL_REDACT);
 MSep(MN_TOOLS);
 MItem(MN_TOOLS, 'Appliquer les biffures', '', CM_APPLYRED);
 MItem(MN_TOOLS, 'Supprimer les commentaires', '', CM_CLEARALL);
 MItem(MN_TOOLS, 'Épaisseur du trait...', '', CM_WIDTH);

 Menus[MN_HELP].Title := 'Aide';
 MItem(MN_HELP, 'Raccourcis clavier', 'F1', CM_HELP);
 MItem(MN_HELP, 'À propos d''Acrobat...', '', CM_ABOUT);

 For M := 0 To MN_COUNT - 1 Do Begin
  Menus[M].Width := 120;
  For I := 0 To Menus[M].ItemCount - 1 Do
   If Not Menus[M].Items[I].Separator Then Begin
    Need := 28 + TW(Menus[M].Items[I].Caption);
    If Menus[M].Items[I].Shortcut <> '' Then Need := Need + 20 + TW(Menus[M].Items[I].Shortcut);
    If Need > Menus[M].Width Then Menus[M].Width := Need;
   End;
 End;
End;

Function CmdEnabled(Cmd: Integer): Boolean;
Begin
 Case Cmd Of
  CM_UNDO: CmdEnabled := CanUndo;
  CM_REDO: CmdEnabled := CanRedo;
  CM_DELETE, CM_DUP, CM_COPY, CM_CUT, CM_DESEL, CM_OBJPROPS: CmdEnabled := SelObj >= 0;
  CM_EDITTXT: CmdEnabled := (SelObj >= 0) And (ObjP(SelObj)^.Kind In [K_TEXT, K_NOTE, K_STAMP, K_HILITE, K_UNDER, K_STRIKE]);
  CM_PASTE: CmdEnabled := ClipValid;
  CM_PGDEL: CmdEnabled := PageCount > 1;
  CM_PGUP: CmdEnabled := CurPage > 1;
  CM_PGDOWN: CmdEnabled := CurPage < PageCount;
  CM_FINDNEXT: CmdEnabled := FindText <> '';
 Else CmdEnabled := True;
 End;
End;

Function CmdChecked(Cmd: Integer): Boolean;
Begin
 CmdChecked := False;
 If (Cmd >= CM_TOOL0) And (Cmd < CM_TOOL0 + TL_COUNT) Then CmdChecked := CurTool = Cmd - CM_TOOL0
 Else If Cmd = CM_CONT Then CmdChecked := Continuous <> 0
 Else If Cmd = CM_NAV Then CmdChecked := NavVisible <> 0
 Else If Cmd = CM_FULL Then CmdChecked := FullScreen;
End;

Procedure DrawMenuBar;
Var
 I, X: Integer;
Begin
 SetFullView;
 SetFillStyle(SolidFill, LightGray);
 Bar(0, 0, GetMaxX, MENU_H - 1);
 SetColor(DarkGray);
 Line(0, MENU_H - 1, GetMaxX, MENU_H - 1);
 X := 6;
 For I := 0 To MN_COUNT - 1 Do Begin
  Menus[I].X := X;
  If MenuActive And (ActiveMenu = I) Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(X - 4, 2, X + TW(Menus[I].Title) + 4, MENU_H - 3);
   SetColor(White);
  End
  Else SetColor(Black);
  DS(X, 6, Menus[I].Title);
  X := X + TW(Menus[I].Title) + 16;
 End;
End;

Procedure DrawDropdown(M: Integer);
Var
 I, X, Y, W, H, IH: Integer;
 En: Boolean;
Begin
 If (M < 0) Or (M >= MN_COUNT) Then Exit;
 SetFullView;
 IH := 18;
 X := Menus[M].X - 4;
 If X + Menus[M].Width > GetMaxX Then X := GetMaxX - Menus[M].Width - 2;
 Menus[M].X := X + 4;
 Y := MENU_H;
 W := Menus[M].Width;
 H := Menus[M].ItemCount * IH + 4;
 SetFillStyle(SolidFill, LightGray);
 Bar(X, Y, X + W, Y + H);
 SetColor(White);
 Line(X, Y, X + W, Y);
 Line(X, Y, X, Y + H);
 SetColor(DarkGray);
 Line(X + W, Y, X + W, Y + H);
 Line(X, Y + H, X + W, Y + H);
 SetColor(Black);
 Line(X + W + 1, Y + 1, X + W + 1, Y + H + 1);
 Line(X + 1, Y + H + 1, X + W + 1, Y + H + 1);
 For I := 0 To Menus[M].ItemCount - 1 Do Begin
  If Menus[M].Items[I].Separator Then Begin
   SetColor(DarkGray);
   Line(X + 3, Y + 2 + I * IH + IH Div 2, X + W - 3, Y + 2 + I * IH + IH Div 2);
   SetColor(White);
   Line(X + 3, Y + 3 + I * IH + IH Div 2, X + W - 3, Y + 3 + I * IH + IH Div 2);
  End
  Else Begin
   En := CmdEnabled(Menus[M].Items[I].Cmd);
   If ActiveItem = I Then Begin
    SetFillStyle(SolidFill, Blue);
    Bar(X + 2, Y + 2 + I * IH, X + W - 2, Y + 1 + (I + 1) * IH);
    If En Then SetColor(White) Else SetColor(LightGray);
   End
   Else If En Then SetColor(Black) Else SetColor(DarkGray);
   If CmdChecked(Menus[M].Items[I].Cmd) Then DS(X + 6, Y + 6 + I * IH, #251);
   DS(X + 20, Y + 6 + I * IH, Menus[M].Items[I].Caption);
   If Menus[M].Items[I].Shortcut <> '' Then
    DS(X + W - TW(Menus[M].Items[I].Shortcut) - 8, Y + 6 + I * IH, Menus[M].Items[I].Shortcut);
  End;
 End;
End;

Function MenuBarHit(MX, MY: LongInt): Integer;
Var
 I: Integer;
Begin
 MenuBarHit := -1;
 If MY >= MENU_H Then Exit;
 For I := 0 To MN_COUNT - 1 Do
  If (MX >= Menus[I].X - 4) And (MX <= Menus[I].X + TW(Menus[I].Title) + 4) Then Begin
   MenuBarHit := I;
   Exit;
  End;
End;

Function MenuItemHit(MX, MY: LongInt; M: Integer): Integer;
Var
 Idx: Integer;
Begin
 MenuItemHit := -1;
 If (M < 0) Or (M >= MN_COUNT) Then Exit;
 If (MX < Menus[M].X - 4) Or (MX > Menus[M].X - 4 + Menus[M].Width) Then Exit;
 If (MY < MENU_H + 2) Or (MY > MENU_H + Menus[M].ItemCount * 18 + 2) Then Exit;
 Idx := (MY - MENU_H - 2) Div 18;
 If (Idx < 0) Or (Idx >= Menus[M].ItemCount) Then Exit;
 If Menus[M].Items[Idx].Separator Then Exit;
 MenuItemHit := Idx;
End;

{ Sauvegarde / restauration de la zone sous un menu déroulant }
Procedure SaveUnder(M: Integer);
Var
 X, Y, W, H: Integer;
Begin
 SetFullView;
 X := Menus[M].X - 4;
 If X + Menus[M].Width > GetMaxX Then X := GetMaxX - Menus[M].Width - 2;
 Y := MENU_H;
 W := Menus[M].Width + 3;
 H := Menus[M].ItemCount * 18 + 8;
 UnderX := X; UnderY := Y; UnderW := W; UnderH := H;
 UnderSize := ImageSize(X, Y, X + W, Y + H);
 If UnderSize > 0 Then Begin
  GetMem(UnderBuf, UnderSize);
  GetImage(X, Y, X + W, Y + H, UnderBuf^);
  UnderValid := True;
 End;
End;

Procedure RestoreUnder;
Begin
 If UnderValid Then Begin
  SetFullView;
  PutImage(UnderX, UnderY, UnderBuf^, NormalPut);
  FreeMem(UnderBuf, UnderSize);
  UnderValid := False;
 End;
End;

Procedure OpenMenu(M: Integer);
Begin
 If UnderValid Then RestoreUnder;
 MenuActive := True;
 ActiveMenu := M;
 ActiveItem := -1;
 HideMouse;
 DrawMenuBar;
 SaveUnder(M);
 DrawDropdown(M);
 ShowMouse;
End;

Procedure CloseMenu;
Begin
 If Not MenuActive Then Exit;
 HideMouse;
 RestoreUnder;
 MenuActive := False;
 ActiveItem := -1;
 DrawMenuBar;
 ShowMouse;
End;

{ ---------------------------------------------------------------------- }
{ Barre d'outils                                                             }
{ ---------------------------------------------------------------------- }

Type
 TTB = Record
  X, W: Integer;
  Cmd, Icon: Integer;
  Hint: String[44];
 End;

Var
 TBar: Array[0..39] Of TTB;
 TBCount: Integer;
 TBPageX1, TBPageX2, TBZoomX1, TBZoomX2: Integer;

Procedure DrawIcon(Id, X, Y: Integer);
Var
 P: Array[0..9] Of PointType;
Begin
 SetColor(Black);
 SetFillStyle(SolidFill, Black);
 Case Id Of
  0: Begin
   SetFillStyle(SolidFill, Yellow);
   Bar(X + 1, Y + 5, X + 14, Y + 13);
   SetColor(Black);
   Rectangle(X + 1, Y + 5, X + 14, Y + 13);
   Line(X + 1, Y + 5, X + 3, Y + 3); Line(X + 3, Y + 3, X + 6, Y + 3); Line(X + 6, Y + 3, X + 7, Y + 5);
  End;
  1: Begin
   SetFillStyle(SolidFill, Blue);
   Bar(X + 2, Y + 2, X + 13, Y + 13);
   SetFillStyle(SolidFill, White);
   Bar(X + 4, Y + 2, X + 11, Y + 6);
   SetFillStyle(SolidFill, LightGray);
   Bar(X + 5, Y + 9, X + 10, Y + 13);
   SetColor(Black);
   Rectangle(X + 2, Y + 2, X + 13, Y + 13);
  End;
  2: Tri(X + 11, Y + 2, X + 11, Y + 13, X + 4, Y + 8, Black);
  3: Tri(X + 4, Y + 2, X + 4, Y + 13, X + 11, Y + 8, Black);
  4, 5, 8: Begin
   SetColor(Black);
   Circle(X + 6, Y + 6, 4);
   Circle(X + 6, Y + 6, 3);
   Line(X + 9, Y + 9, X + 14, Y + 14);
   Line(X + 10, Y + 9, X + 14, Y + 13);
   If Id = 4 Then Line(X + 4, Y + 6, X + 8, Y + 6);
   If Id = 5 Then Begin Line(X + 4, Y + 6, X + 8, Y + 6); Line(X + 6, Y + 4, X + 6, Y + 8); End;
  End;
  6: Begin
   P[0].X := X + 3; P[0].Y := Y + 1; P[1].X := X + 3; P[1].Y := Y + 13; P[2].X := X + 6; P[2].Y := Y + 10;
   P[3].X := X + 9; P[3].Y := Y + 15; P[4].X := X + 11; P[4].Y := Y + 14; P[5].X := X + 8; P[5].Y := Y + 9;
   P[6].X := X + 12; P[6].Y := Y + 9;
   SetFillStyle(SolidFill, White);
   FillPoly(7, P);
   SetColor(Black);
   DrawPoly(7, P);
   Line(X + 12, Y + 9, X + 3, Y + 1);
  End;
  7: Begin
   SetFillStyle(SolidFill, White);
   Bar(X + 4, Y + 7, X + 12, Y + 14);
   SetColor(Black);
   Rectangle(X + 4, Y + 7, X + 12, Y + 14);
   Line(X + 5, Y + 7, X + 5, Y + 2); Line(X + 7, Y + 7, X + 7, Y + 1);
   Line(X + 9, Y + 7, X + 9, Y + 2); Line(X + 11, Y + 7, X + 11, Y + 3);
   Line(X + 2, Y + 8, X + 4, Y + 10);
  End;
  9: Begin
   SetColor(Black);
   Line(X + 3, Y + 3, X + 12, Y + 3); Line(X + 3, Y + 4, X + 12, Y + 4);
   Line(X + 7, Y + 4, X + 7, Y + 13); Line(X + 8, Y + 4, X + 8, Y + 13);
   Line(X + 5, Y + 13, X + 10, Y + 13);
  End;
  10: Begin
   SetFillStyle(SolidFill, Yellow);
   Bar(X + 2, Y + 2, X + 13, Y + 12);
   SetColor(Black);
   Rectangle(X + 2, Y + 2, X + 13, Y + 12);
   Line(X + 4, Y + 5, X + 11, Y + 5); Line(X + 4, Y + 7, X + 11, Y + 7); Line(X + 4, Y + 9, X + 8, Y + 9);
   Line(X + 4, Y + 12, X + 3, Y + 14); Line(X + 3, Y + 14, X + 7, Y + 12);
  End;
  11: Begin
   SetFillStyle(SolidFill, Yellow);
   Bar(X + 1, Y + 4, X + 14, Y + 11);
   SetColor(Black);
   DS(X + 4, Y + 4, 'ab');
  End;
  12: Begin
   DS(X + 4, Y + 2, 'U');
   SetColor(Red);
   Line(X + 2, Y + 13, X + 13, Y + 13);
  End;
  13: Begin
   DS(X + 4, Y + 4, 'S');
   SetColor(Red);
   Line(X + 1, Y + 8, X + 14, Y + 8);
  End;
  14: Begin
   SetColor(Black);
   Line(X + 3, Y + 12, X + 11, Y + 4); Line(X + 4, Y + 13, X + 12, Y + 5);
   Line(X + 11, Y + 4, X + 13, Y + 6); Line(X + 3, Y + 12, X + 2, Y + 14); Line(X + 4, Y + 13, X + 2, Y + 14);
   SetColor(Red);
   Line(X + 1, Y + 15, X + 4, Y + 15);
  End;
  15: Begin
   SetColor(Black);
   Line(X + 2, Y + 13, X + 13, Y + 2); Line(X + 3, Y + 13, X + 14, Y + 2);
  End;
  16: Begin
   SetColor(Black);
   Line(X + 2, Y + 13, X + 12, Y + 3); Line(X + 3, Y + 13, X + 13, Y + 3);
   Tri(X + 14, Y + 1, X + 8, Y + 3, X + 12, Y + 7, Black);
  End;
  17: Begin
   SetColor(Black);
   Rectangle(X + 2, Y + 3, X + 13, Y + 12); Rectangle(X + 3, Y + 4, X + 12, Y + 11);
  End;
  18: Begin
   SetColor(Black);
   Ellipse(X + 8, Y + 8, 0, 360, 6, 5); Ellipse(X + 8, Y + 8, 0, 360, 5, 4);
  End;
  19: Begin
   SetColor(Red);
   Rectangle(X + 1, Y + 3, X + 14, Y + 12); Rectangle(X + 2, Y + 4, X + 13, Y + 11);
   DS(X + 4, Y + 4, 'OK');
  End;
  20: Begin
   SetColor(Blue);
   Line(X + 1, Y + 10, X + 4, Y + 4); Line(X + 4, Y + 4, X + 6, Y + 11); Line(X + 6, Y + 11, X + 9, Y + 5);
   Line(X + 9, Y + 5, X + 11, Y + 10); Line(X + 11, Y + 10, X + 14, Y + 7);
   SetColor(Black);
   Line(X + 1, Y + 13, X + 14, Y + 13);
  End;
  21: Begin
   SetFillStyle(SolidFill, Black);
   Bar(X + 2, Y + 4, X + 13, Y + 11);
   SetColor(LightRed);
   Rectangle(X + 1, Y + 3, X + 14, Y + 12);
  End;
 End;
End;

Function AddTB(Cmd, Icon, W: Integer; Const Hint: String): Integer;
Var
 X: Integer;
Begin
 If TBCount = 0 Then X := 4 Else X := TBar[TBCount - 1].X + TBar[TBCount - 1].W;
 TBar[TBCount].X := X;
 TBar[TBCount].W := W;
 TBar[TBCount].Cmd := Cmd;
 TBar[TBCount].Icon := Icon;
 TBar[TBCount].Hint := Hint;
 Inc(TBCount);
 AddTB := X;
End;

Procedure InitToolbar;
Var
 X: Integer;
Begin
 TBCount := 0;
 AddTB(CM_OPEN, 0, 22, 'Ouvrir un fichier PDF (Ctrl+O)');
 AddTB(CM_SAVE, 1, 22, 'Enregistrer (Ctrl+S)');
 AddTB(-1, -1, 6, '');
 AddTB(CM_PREV, 2, 22, 'Page précédente');
 TBPageX1 := AddTB(CM_GOTO, -2, 66, 'Aller à la page (Ctrl+G)');
 AddTB(CM_NEXT, 3, 22, 'Page suivante');
 AddTB(-1, -1, 6, '');
 AddTB(CM_ZOOMOUT, 4, 22, 'Zoom arrière (-)');
 TBZoomX1 := AddTB(CM_ZOOMSET, -3, 44, 'Niveau de zoom');
 AddTB(CM_ZOOMIN, 5, 22, 'Zoom avant (+)');
 AddTB(-1, -1, 6, '');
 AddTB(CM_TOOL0 + TL_SELECT, 6, 22, 'Outil de sélection (V)');
 AddTB(CM_TOOL0 + TL_HAND, 7, 22, 'Outil main (H)');
 AddTB(CM_TOOL0 + TL_ZOOM, 8, 22, 'Loupe (Z)');
 AddTB(-1, -1, 6, '');
 AddTB(CM_TOOL0 + TL_TEXT, 9, 22, 'Ajouter du texte (T)');
 AddTB(CM_TOOL0 + TL_NOTE, 10, 22, 'Note adhésive (N)');
 AddTB(CM_TOOL0 + TL_HILITE, 11, 22, 'Surligner le texte (K)');
 AddTB(CM_TOOL0 + TL_UNDER, 12, 22, 'Souligner le texte (U)');
 AddTB(CM_TOOL0 + TL_STRIKE, 13, 22, 'Barrer le texte (S)');
 AddTB(CM_TOOL0 + TL_PENCIL, 14, 22, 'Crayon (P)');
 AddTB(CM_TOOL0 + TL_LINE, 15, 22, 'Ligne (L)');
 AddTB(CM_TOOL0 + TL_ARROW, 16, 22, 'Flèche (A)');
 AddTB(CM_TOOL0 + TL_RECT, 17, 22, 'Rectangle (R)');
 AddTB(CM_TOOL0 + TL_OVAL, 18, 22, 'Ovale (O)');
 AddTB(CM_TOOL0 + TL_STAMP, 19, 22, 'Tampon (M)');
 AddTB(CM_TOOL0 + TL_SIGN, 20, 22, 'Signer (G)');
 AddTB(CM_TOOL0 + TL_REDACT, 21, 22, 'Biffer (X)');
 TBPageX2 := TBPageX1 + 66;
 TBZoomX2 := TBZoomX1 + 44;
End;

Procedure DrawToolbar;
Var
 I: Integer;
 X, Y: Integer;
 Active: Boolean;
 S: String;
Begin
 If (ToolbarVisible = 0) Or FullScreen Then Exit;
 SetFullView;
 SetFillStyle(SolidFill, LightGray);
 Bar(0, MENU_H, GetMaxX, MENU_H + TOOL_H - 1);
 SetColor(DarkGray);
 Line(0, MENU_H + TOOL_H - 1, GetMaxX, MENU_H + TOOL_H - 1);
 Y := MENU_H + 2;
 For I := 0 To TBCount - 1 Do Begin
  X := TBar[I].X;
  If TBar[I].Cmd = -1 Then Begin
   SetColor(DarkGray);
   Line(X + 2, Y + 1, X + 2, Y + 20);
   SetColor(White);
   Line(X + 3, Y + 1, X + 3, Y + 20);
  End
  Else If TBar[I].Icon = -2 Then Begin
   Field3D(X, Y + 1, X + TBar[I].W - 2, Y + 20);
   SetColor(Black);
   S := IStr(CurPage) + ' / ' + IStr(PageCount);
   DSC(X, Y + 7, TBar[I].W - 2, S);
  End
  Else If TBar[I].Icon = -3 Then Begin
   Field3D(X, Y + 1, X + TBar[I].W - 2, Y + 20);
   SetColor(Black);
   DSC(X, Y + 7, TBar[I].W - 2, IStr(Zoom) + '%');
  End
  Else Begin
   Active := (TBar[I].Cmd >= CM_TOOL0) And (TBar[I].Cmd < CM_TOOL0 + TL_COUNT) And (CurTool = TBar[I].Cmd - CM_TOOL0);
   If Active Then Begin
    SetFillStyle(SolidFill, White);
    Bar(X, Y, X + TBar[I].W - 2, Y + 21);
    Bevel(X, Y, X + TBar[I].W - 2, Y + 21, False);
   End
   Else Bevel(X, Y, X + TBar[I].W - 2, Y + 21, True);
   DrawIcon(TBar[I].Icon, X + 2, Y + 3);
  End;
 End;
End;

Function ToolbarHit(MX, MY: LongInt): Integer;
Var
 I: Integer;
Begin
 ToolbarHit := -1;
 If (ToolbarVisible = 0) Or FullScreen Then Exit;
 If (MY < MENU_H) Or (MY >= MENU_H + TOOL_H) Then Exit;
 For I := 0 To TBCount - 1 Do
  If (TBar[I].Cmd <> -1) And (MX >= TBar[I].X) And (MX < TBar[I].X + TBar[I].W - 1) Then Begin
   ToolbarHit := I;
   Exit;
  End;
End;

{ ---------------------------------------------------------------------- }
{ Barres de défilement génériques                                           }
{ ---------------------------------------------------------------------- }

Procedure SBGeom(X1, Y1, X2, Y2: Integer; Vert: Boolean; Pos, Range, Page: LongInt;
                 Var TrackA, TrackLen, ThumbA, ThumbLen: LongInt);
Var
 Total: LongInt;
Begin
 If Vert Then Total := Y2 - Y1 + 1 Else Total := X2 - X1 + 1;
 TrackLen := Total - 2 * SBAR;
 If TrackLen < 4 Then TrackLen := 4;
 If Vert Then TrackA := Y1 + SBAR Else TrackA := X1 + SBAR;
 If Range <= Page Then Begin
  ThumbLen := TrackLen;
  ThumbA := TrackA;
 End
 Else Begin
  ThumbLen := (TrackLen * Page) Div Range;
  If ThumbLen < 12 Then ThumbLen := 12;
  If ThumbLen > TrackLen Then ThumbLen := TrackLen;
  ThumbA := TrackA + ((TrackLen - ThumbLen) * Pos) Div (Range - Page);
 End;
End;

Procedure DrawSB(X1, Y1, X2, Y2: Integer; Vert: Boolean; Pos, Range, Page: LongInt);
Var
 TrackA, TrackLen, ThumbA, ThumbLen: LongInt;
Begin
 SBGeom(X1, Y1, X2, Y2, Vert, Pos, Range, Page, TrackA, TrackLen, ThumbA, ThumbLen);
 SetFillStyle(SolidFill, LightGray);
 Bar(X1, Y1, X2, Y2);
 If Vert Then Begin
  PushButton(X1, Y1, X2, Y1 + SBAR - 1, '', False);
  Tri(X1 + 4, Y1 + 10, X1 + 11, Y1 + 10, X1 + 8, Y1 + 5, Black);
  PushButton(X1, Y2 - SBAR + 1, X2, Y2, '', False);
  Tri(X1 + 4, Y2 - 10, X1 + 11, Y2 - 10, X1 + 8, Y2 - 5, Black);
  If Range > Page Then Begin
   SetFillStyle(SolidFill, LightGray);
   Bar(X1, ThumbA, X2, ThumbA + ThumbLen - 1);
   Bevel(X1, ThumbA, X2, ThumbA + ThumbLen - 1, True);
  End;
 End
 Else Begin
  PushButton(X1, Y1, X1 + SBAR - 1, Y2, '', False);
  Tri(X1 + 10, Y1 + 4, X1 + 10, Y1 + 11, X1 + 5, Y1 + 8, Black);
  PushButton(X2 - SBAR + 1, Y1, X2, Y2, '', False);
  Tri(X2 - 10, Y1 + 4, X2 - 10, Y1 + 11, X2 - 5, Y1 + 8, Black);
  If Range > Page Then Begin
   SetFillStyle(SolidFill, LightGray);
   Bar(ThumbA, Y1, ThumbA + ThumbLen - 1, Y2);
   Bevel(ThumbA, Y1, ThumbA + ThumbLen - 1, Y2, True);
  End;
 End;
End;

{ Retourne : 0 rien, 1 flèche -, 2 flèche +, 3 page -, 4 page +, 5 curseur }
Function SBHit(X1, Y1, X2, Y2: Integer; Vert: Boolean; Pos, Range, Page, MX, MY: LongInt;
               Var Ofs: LongInt): Integer;
Var
 TrackA, TrackLen, ThumbA, ThumbLen, M: LongInt;
Begin
 SBHit := 0;
 If (MX < X1) Or (MX > X2) Or (MY < Y1) Or (MY > Y2) Then Exit;
 SBGeom(X1, Y1, X2, Y2, Vert, Pos, Range, Page, TrackA, TrackLen, ThumbA, ThumbLen);
 If Vert Then M := MY Else M := MX;
 If M < TrackA Then Begin SBHit := 1; Exit; End;
 If M >= TrackA + TrackLen Then Begin SBHit := 2; Exit; End;
 If Range <= Page Then Exit;
 If M < ThumbA Then SBHit := 3
 Else If M >= ThumbA + ThumbLen Then SBHit := 4
 Else Begin SBHit := 5; Ofs := M - ThumbA; End;
End;

Function SBDragPos(X1, Y1, X2, Y2: Integer; Vert: Boolean; Range, Page, MX, MY, Ofs: LongInt): LongInt;
Var
 TrackA, TrackLen, ThumbA, ThumbLen, M, R: LongInt;
Begin
 SBGeom(X1, Y1, X2, Y2, Vert, 0, Range, Page, TrackA, TrackLen, ThumbA, ThumbLen);
 If Vert Then M := MY Else M := MX;
 If TrackLen - ThumbLen <= 0 Then Begin SBDragPos := 0; Exit; End;
 R := ((M - Ofs - TrackA) * (Range - Page)) Div (TrackLen - ThumbLen);
 If R < 0 Then R := 0;
 If R > Range - Page Then R := Range - Page;
 SBDragPos := R;
End;

{ ---------------------------------------------------------------------- }
{ Volet de navigation                                                        }
{ ---------------------------------------------------------------------- }

Var
 NavRowsTotal: Integer;

Function ThumbScale(I: Integer): LongInt;
Var
 W, H: LongInt;
 S1, S2: LongInt;
Begin
 If (PgP(I)^.Rot And 1) <> 0 Then Begin W := PgP(I)^.H; H := PgP(I)^.W; End
 Else Begin W := PgP(I)^.W; H := PgP(I)^.H; End;
 S1 := (74 * 1024) Div W;
 S2 := (92 * 1024) Div H;
 If S1 < S2 Then ThumbScale := S1 Else ThumbScale := S2;
End;

Function ThumbCellH(I: Integer): LongInt;
Begin
 ThumbCellH := DispHOf(I, ThumbScale(I)) + 22;
End;

Function ThumbTop(I: Integer): LongInt;
Var
 J: Integer;
 T: LongInt;
Begin
 T := 4;
 For J := 1 To I - 1 Do T := T + ThumbCellH(J);
 ThumbTop := T;
End;

Function NavDocHeight: LongInt;
Var
 I: Integer;
 T: LongInt;
Begin
 T := 4;
 For I := 1 To PageCount Do T := T + ThumbCellH(I);
 NavDocHeight := T;
End;

Function IsCommentKind(K: Integer): Boolean;
Begin
 IsCommentKind := K In [K_HILITE, K_UNDER, K_STRIKE, K_NOTE, K_STAMP];
End;

Function KindName(K: Integer): String;
Begin
 Case K Of
  K_TEXT: KindName := 'Texte';
  K_LINE: KindName := 'Ligne';
  K_ARROW: KindName := 'Flèche';
  K_RECT: KindName := 'Rectangle';
  K_OVAL: KindName := 'Ovale';
  K_POLY: KindName := 'Tracé';
  K_INK: KindName := 'Crayon';
  K_IMAGE: KindName := 'Image';
  K_STAMP: KindName := 'Tampon';
  K_REDACT: KindName := 'Biffure';
  K_HILITE: KindName := 'Surlignage';
  K_UNDER: KindName := 'Soulignement';
  K_STRIKE: KindName := 'Barré';
  K_NOTE: KindName := 'Note';
 Else KindName := '?';
 End;
End;

{ Texte sous un surlignage / soulignement }
Function TextUnder(Idx: Integer): String;
Var
 I: Integer;
 R: String;
 Cx1, Cx2, Cy1, Cy2: LongInt;
 O: ^TObjRec;
 X1, Y1, X2, Y2: LongInt;
Begin
 R := '';
 NormBox(ObjP(Idx)^, Cx1, Cy1, Cx2, Cy2);
 For I := 0 To ObjCount - 1 Do Begin
  O := @ObjP(I)^;
  If (O^.Page = ObjP(Idx)^.Page) And (O^.Kind = K_TEXT) Then Begin
   NormBox(O^, X1, Y1, X2, Y2);
   If (X1 < Cx2) And (X2 > Cx1) And ((Y1 + Y2) Div 2 >= Cy1) And ((Y1 + Y2) Div 2 <= Cy2) Then Begin
    If Length(R) + Length(O^.Txt) < 60 Then R := R + O^.Txt + ' ';
   End;
  End;
 End;
 TextUnder := R;
End;

Procedure CommentRow(N: Integer; Var Idx: Integer);
Var
 I, C: Integer;
Begin
 Idx := -1;
 C := 0;
 For I := 0 To ObjCount - 1 Do
  If IsCommentKind(ObjP(I)^.Kind) Then Begin
   If C = N Then Begin Idx := I; Exit; End;
   Inc(C);
  End;
End;

Function CommentCount: Integer;
Var
 I, C: Integer;
Begin
 C := 0;
 For I := 0 To ObjCount - 1 Do If IsCommentKind(ObjP(I)^.Kind) Then Inc(C);
 CommentCount := C;
End;

Procedure DrawNav;
Var
 I, Y0, Y1, R, Idx, Rows, N: Integer;
 T, TY, TRun: LongInt;
 Sc: LongInt;
 DW, DH, OX: LongInt;
 S: String;
Begin
 If (NavVisible = 0) Or FullScreen Then Exit;
 SetFullView;
 SetFillStyle(SolidFill, LightGray);
 Bar(0, ViewT, NAV_W - 1, GetMaxY - STATUS_H);
 { onglets }
 If NavTab = 0 Then SetFillStyle(SolidFill, White) Else SetFillStyle(SolidFill, LightGray);
 Bar(0, ViewT, 53, ViewT + 14);
 If NavTab = 1 Then SetFillStyle(SolidFill, White) Else SetFillStyle(SolidFill, LightGray);
 Bar(54, ViewT, NAV_W - 1, ViewT + 14);
 SetColor(Black);
 DS(5, ViewT + 4, 'Pages');
 DS(58, ViewT + 4, 'Notes');
 Line(0, ViewT + 15, NAV_W - 1, ViewT + 15);
 Line(53, ViewT, 53, ViewT + 15);
 Y0 := ViewT + 16;
 Y1 := ViewB;
 SetViewPort(0, Y0, NAV_W - SBAR - 1, Y1, True);
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, 0, NAV_W, Y1 - Y0);
 CullW := NAV_W; CullH := Y1 - Y0;
 If NavTab = 0 Then Begin
  TRun := 4;
  For I := 1 To PageCount Do Begin
   T := TRun - NavScroll;
   TRun := TRun + ThumbCellH(I);
   If T > Y1 - Y0 Then Break;
   If T + ThumbCellH(I) < 0 Then Continue;
   Sc := ThumbScale(I);
   DW := DispWOf(I, Sc);
   OX := (NAV_W - SBAR - DW) Div 2;
   If I = CurPage Then Begin
    SetColor(LightRed);
    Rectangle(C16(OX - 3), C16(T - 3), C16(OX + DW + 3), C16(T + DispHOf(I, Sc) + 3));
    Rectangle(C16(OX - 2), C16(T - 2), C16(OX + DW + 2), C16(T + DispHOf(I, Sc) + 2));
   End;
   RenderPage(I, OX, T, Sc, False);
   SetColor(White);
   S := IStr(I);
   DS(C16((NAV_W - SBAR) Div 2 - Length(S) * 4), C16(T + DispHOf(I, Sc) + 7), S);
  End;
 End
 Else Begin
  Rows := (Y1 - Y0 + 1) Div 24;
  N := CommentCount;
  If N = 0 Then Begin
   SetColor(White);
   DS(4, 6, 'Aucun');
   DS(4, 16, 'commentaire');
  End;
  For R := 0 To Rows - 1 Do Begin
   CommentRow(NavScroll + R, Idx);
   If Idx < 0 Then Break;
   TY := R * 24;
   If Idx = SelObj Then SetFillStyle(SolidFill, Blue) Else SetFillStyle(SolidFill, DarkGray);
   Bar(0, TY, NAV_W - SBAR - 1, TY + 22);
   SetColor(Yellow);
   DS(3, C16(TY + 2), 'p' + IStr(ObjP(Idx)^.Page) + ' ' + KindName(ObjP(Idx)^.Kind));
   SetColor(White);
   S := ObjP(Idx)^.Txt;
   If S = '' Then S := TextUnder(Idx);
   DS(3, C16(TY + 12), Copy(S, 1, 11));
  End;
 End;
 SetFullView;
 If NavTab = 0 Then DrawSB(NAV_W - SBAR, Y0, NAV_W - 1, Y1, True, NavScroll, NavDocHeight, Y1 - Y0 + 1)
 Else DrawSB(NAV_W - SBAR, Y0, NAV_W - 1, Y1, True, NavScroll, IMax(CommentCount, 1), (Y1 - Y0 + 1) Div 24);
 SetColor(Black);
 Line(NAV_W - 1, ViewT, NAV_W - 1, GetMaxY - STATUS_H);
End;

{ ---------------------------------------------------------------------- }
{ Vue du document                                                            }
{ ---------------------------------------------------------------------- }

Procedure DrawEditCaret;
Var
 O: ^TObjRec;
 OX, OY, T: LongInt;
 Pg: Integer;
 Ox_, Oy_, Dx, Dy, Vx, Vy, U: Real;
Begin
 If Not Editing Then Exit;
 If (EditObj < 0) Or (EditObj >= ObjCount) Then Exit;
 O := @ObjP(EditObj)^;
 Pg := O^.Page;
 If Not PageVisible(Pg) Then Exit;
 SetViewPort(ViewL, ViewT, ViewR, ViewB, True);
 PageOrigin(Pg, OX, OY);
 SetCtx(Pg, OX, OY, Scale);
 TextOrigin(O^, Ox_, Oy_);
 TextDirs(TextAng(O^), Dx, Dy, Vx, Vy);
 U := TextLenPts(Copy(O^.Txt, 1, EditCaret), O^.Size, O^.Style Shr 2, O^.Style And 3);
 SetColor(Blue);
 Line(C16(MXr(Ox_ + U * Dx + O^.Size * 0.1 * Vx, Oy_ + U * Dy + O^.Size * 0.1 * Vy)),
      C16(MYr(Ox_ + U * Dx + O^.Size * 0.1 * Vx, Oy_ + U * Dy + O^.Size * 0.1 * Vy)),
      C16(MXr(Ox_ + U * Dx + O^.Size * 1.1 * Vx, Oy_ + U * Dy + O^.Size * 1.1 * Vy)),
      C16(MYr(Ox_ + U * Dx + O^.Size * 1.1 * Vx, Oy_ + U * Dy + O^.Size * 1.1 * Vy)));
 SetColor(LightBlue);
 DrawTextBoxRot(O^);
 SetFullView;
End;

Procedure DrawView;
Var
 I: Integer;
 OX, OY: LongInt;
Begin
 SetViewPort(ViewL, ViewT, ViewR, ViewB, True);
 CullW := ViewW - 1; CullH := ViewH - 1;
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, 0, ViewW, ViewH);
 For I := 1 To PageCount Do
  If PageVisible(I) Then Begin
   PageOrigin(I, OX, OY);
   RenderPage(I, OX, OY, Scale, True);
  End;
 SetFullView;
 DrawEditCaret;
End;

Procedure DrawScrollBars;
Begin
 SetFullView;
 DrawSB(ViewR + 1, ViewT, GetMaxX, ViewB, True, ScrollY, DocH, ViewH);
 DrawSB(ViewL, ViewB + 1, ViewR, GetMaxY - STATUS_H, False, ScrollX, DocW, ViewW);
 SetFillStyle(SolidFill, LightGray);
 Bar(ViewR + 1, ViewB + 1, GetMaxX, GetMaxY - STATUS_H);
End;

Procedure DrawStatus;
Var
 S, R: String;
 Y: Integer;
Begin
 SetFullView;
 Y := GetMaxY - STATUS_H + 1;
 SetFillStyle(SolidFill, LightGray);
 Bar(0, Y, GetMaxX, GetMaxY);
 SetColor(DarkGray);
 Line(0, Y, GetMaxX, Y);
 SetColor(White);
 Line(0, Y + 1, GetMaxX, Y + 1);
 SetColor(Black);
 If HintText <> '' Then S := HintText Else If StatusMsg <> '' Then S := StatusMsg
 Else Begin
  S := BaseName(DocName);
  If S = '' Then S := 'Sans titre.pdf';
  If Modified Then S := S + ' *';
 End;
 If Length(S) > 52 Then S := Copy(S, 1, 52);
 DS(6, Y + 6, S);
 R := IStr(PgP(CurPage)^.W) + ' x ' + IStr(PgP(CurPage)^.H) + ' pt   Page ' + IStr(CurPage) + '/' + IStr(PageCount);
 DS(GetMaxX - TW(R) - 8, Y + 6, R);
End;

Procedure RedrawView;
Begin
 HideMouse;
 DrawView;
 DrawScrollBars;
 DrawStatus;
 ShowMouse;
End;

Procedure RedrawAll;
Begin
 HideMouse;
 SetFullView;
 If (FitMode <> 0) And (PageCount > 0) Then ApplyFit;
 Relayout;
 SetFillStyle(SolidFill, LightGray);
 Bar(0, 0, GetMaxX, GetMaxY);
 DrawMenuBar;
 DrawToolbar;
 DrawView;
 DrawNav;
 SetFullView;
 DrawScrollBars;
 DrawStatus;
 If MenuActive Then Begin
  If UnderValid Then Begin FreeMem(UnderBuf, UnderSize); UnderValid := False; End;
  SaveUnder(ActiveMenu);
  DrawDropdown(ActiveMenu);
 End;
 ShowMouse;
End;

Procedure SetStatus(Const S: String);
Begin
 StatusMsg := S;
 DrawStatus;
End;

{ ---------------------------------------------------------------------- }
{ Dialogues                                                                 }
{ ---------------------------------------------------------------------- }

Var
 DlgX1, DlgY1, DlgX2, DlgY2: Integer;
 LastDir: String;
 FileMaskAll: Boolean;

Procedure PollMouse;
Begin
 OMX := MX_; OMY := MY_; OMB := MB_;
 GetMouseState(MX_, MY_, MB_);
End;

Function MouseClicked: Boolean;
Begin
 MouseClicked := ((MB_ And 1) <> 0) And ((OMB And 1) = 0);
End;

Function GetKeyEx(Var Ext: Boolean): Integer;
Var
 C: Char;
Begin
 GetKeyEx := -1;
 Ext := False;
 If Not KeyPressed Then Exit;
 C := ReadKey;
 If C = #0 Then Begin
  Ext := True;
  If KeyPressed Then GetKeyEx := Ord(ReadKey) Else GetKeyEx := 0;
 End
 Else GetKeyEx := Ord(C);
End;

Procedure WaitMouseUp;
Begin
 Repeat
  PollMouse;
  Delay(5);
 Until (MB_ And 1) = 0;
 OMB := 0;
End;

Procedure DlgFrame(W, H: Integer; Const Title: String);
Begin
 SetFullView;
 DlgX1 := (GetMaxX + 1 - W) Div 2;
 DlgY1 := (GetMaxY + 1 - H) Div 2;
 DlgX2 := DlgX1 + W - 1;
 DlgY2 := DlgY1 + H - 1;
 SetFillStyle(SolidFill, Black);
 Bar(DlgX1 + 4, DlgY1 + 4, DlgX2 + 4, DlgY2 + 4);
 Panel(DlgX1, DlgY1, DlgX2, DlgY2, True);
 SetFillStyle(SolidFill, Blue);
 Bar(DlgX1 + 3, DlgY1 + 3, DlgX2 - 3, DlgY1 + 17);
 SetColor(White);
 DS(DlgX1 + 8, DlgY1 + 7, Title);
End;

Function InRect(X, Y, X1, Y1, X2, Y2: LongInt): Boolean;
Begin
 InRect := (X >= X1) And (X <= X2) And (Y >= Y1) And (Y <= Y2);
End;

{ Boîte de message : 0 = OK ; 1 = OK/Annuler ; 2 = Oui/Non/Annuler
  Retour : 1 OK/Oui, 2 Non, 0 Annuler }
Function MsgBox(Const Title, Msg: String; Buttons: Integer): Integer;
Var
 Lines: Array[0..15] Of String[60];
 NL, I, W, H, BW, NB, BX, BY, Hit, Res: Integer;
 S, Cur, Word_: String;
 Done: Boolean;
 Caps: Array[0..2] Of String[12];
 Ext: Boolean;
 K: Integer;
 Pressed: Integer;
Begin
 NL := 0;
 S := U2C(Msg) + '|';
 Cur := '';
 While (S <> '') And (NL < 16) Do Begin
  I := Pos('|', S);
  If I = 0 Then I := Length(S) + 1;
  Word_ := Copy(S, 1, I - 1);
  Delete(S, 1, I);
  While Length(Word_) > 52 Do Begin
   K := 52;
   While (K > 20) And (Word_[K] <> ' ') Do Dec(K);
   If NL < 16 Then Begin Lines[NL] := Copy(Word_, 1, K); Inc(NL); End;
   Delete(Word_, 1, K);
  End;
  If NL < 16 Then Begin Lines[NL] := Word_; Inc(NL); End;
 End;
 Case Buttons Of
  0: Begin NB := 1; Caps[0] := 'OK'; End;
  1: Begin NB := 2; Caps[0] := 'OK'; Caps[1] := 'Annuler'; End;
 Else
  Begin NB := 3; Caps[0] := 'Oui'; Caps[1] := 'Non'; Caps[2] := 'Annuler'; End;
 End;
 W := 400;
 H := 66 + NL * 12;
 BW := 80;
 HideMouse;
 DlgFrame(W, H, Title);
 SetColor(Black);
 For I := 0 To NL - 1 Do OutTextXY(DlgX1 + 14, DlgY1 + 28 + I * 12, Lines[I]);
 BY := DlgY2 - 28;
 BX := DlgX1 + (W - (NB * (BW + 10) - 10)) Div 2;
 For I := 0 To NB - 1 Do PushButton(BX + I * (BW + 10), BY, BX + I * (BW + 10) + BW, BY + 20, Caps[I], False);
 ShowMouse;
 Res := 0;
 Done := False;
 PollMouse;
 OMB := MB_;
 While Not Done Do Begin
  PollMouse;
  If MouseClicked Then Begin
   For I := 0 To NB - 1 Do
    If InRect(MX_, MY_, BX + I * (BW + 10), BY, BX + I * (BW + 10) + BW, BY + 20) Then Begin
     HideMouse;
     PushButton(BX + I * (BW + 10), BY, BX + I * (BW + 10) + BW, BY + 20, Caps[I], True);
     ShowMouse;
     WaitMouseUp;
     If (Buttons = 0) Or (Buttons = 1) Then Begin If I = 0 Then Res := 1 Else Res := 0; End
     Else Begin If I = 0 Then Res := 1 Else If I = 1 Then Res := 2 Else Res := 0; End;
     Done := True;
    End;
  End;
  K := GetKeyEx(Ext);
  If (K >= 0) And Not Ext Then Begin
   If K = 13 Then Begin Res := 1; Done := True; End
   Else If K = 27 Then Begin
    If Buttons = 0 Then Res := 1 Else Res := 0;
    Done := True;
   End
   Else If (Buttons = 2) And ((K = 79) Or (K = 111) Or (K = 111)) Then Begin Res := 1; Done := True; End
   Else If (Buttons = 2) And ((K = 78) Or (K = 110)) Then Begin Res := 2; Done := True; End;
  End;
  Delay(10);
 End;
 MsgBox := Res;
End;

Procedure Notice(Const Msg: String);
Var
 R: Integer;
Begin
 R := MsgBox('Acrobat', Msg, 0);
End;

{ ---------------------------------------------------------------------- }
{ Sélecteur de couleur                                                      }
{ ---------------------------------------------------------------------- }

Function PickColor(Const Title: String; Cur: LongInt): LongInt;
Var
 I, X, Y, Sel: Integer;
 Done, Ext: Boolean;
 K: Integer;
 Res: LongInt;
Begin
 HideMouse;
 DlgFrame(260, 112, Title);
 For I := 0 To 15 Do Begin
  X := DlgX1 + 12 + (I Mod 8) * 30;
  Y := DlgY1 + 28 + (I Div 8) * 30;
  SetFillStyle(SolidFill, I);
  Bar(X, Y, X + 26, Y + 26);
  If Nearest16(Cur) = I Then Begin
   SetColor(White); Rectangle(X - 2, Y - 2, X + 28, Y + 28);
   SetColor(Black); Rectangle(X - 1, Y - 1, X + 27, Y + 27);
  End
  Else Begin SetColor(Black); Rectangle(X, Y, X + 26, Y + 26); End;
 End;
 SetColor(Black);
 DS(DlgX1 + 12, DlgY2 - 20, 'Cliquez sur une couleur - Échap annule');
 ShowMouse;
 Res := -1;
 Done := False;
 PollMouse; OMB := MB_;
 While Not Done Do Begin
  PollMouse;
  If MouseClicked Then Begin
   For I := 0 To 15 Do Begin
    X := DlgX1 + 12 + (I Mod 8) * 30;
    Y := DlgY1 + 28 + (I Div 8) * 30;
    If InRect(MX_, MY_, X, Y, X + 26, Y + 26) Then Begin Res := PalRgb[I]; Done := True; End;
   End;
   If Not InRect(MX_, MY_, DlgX1, DlgY1, DlgX2, DlgY2) Then Done := True;
  End;
  K := GetKeyEx(Ext);
  If (K = 27) And Not Ext Then Done := True;
  Delay(10);
 End;
 WaitMouseUp;
 PickColor := Res;
End;

{ ---------------------------------------------------------------------- }
{ Formulaires                                                                }
{ ---------------------------------------------------------------------- }

Procedure FldInit;
Begin
 NFields := 0;
 FillChar(Fields, SizeOf(Fields), 0);
End;

Procedure FldText(Const Lbl, Val: String; Max: Integer);
Begin
 Fields[NFields].Kind := 0; Fields[NFields].Lbl := Lbl; Fields[NFields].Val := Val; Fields[NFields].Mx := Max;
 Inc(NFields);
End;

Procedure FldNum(Const Lbl: String; Val, Mn, Mx: LongInt);
Begin
 Fields[NFields].Kind := 1; Fields[NFields].Lbl := Lbl; Fields[NFields].Val := IStr(Val);
 Fields[NFields].Mn := Mn; Fields[NFields].Mx := Mx;
 Inc(NFields);
End;

Procedure FldChoice(Const Lbl, Choices: String; Idx: Integer);
Begin
 Fields[NFields].Kind := 2; Fields[NFields].Lbl := Lbl; Fields[NFields].Choices := Choices;
 Fields[NFields].Cur := Idx;
 Inc(NFields);
End;

Procedure FldColor(Const Lbl: String; Rgb: LongInt);
Begin
 Fields[NFields].Kind := 3; Fields[NFields].Lbl := Lbl; Fields[NFields].Mn := Rgb;
 Inc(NFields);
End;

Procedure FldCheck(Const Lbl: String; On: Boolean);
Begin
 Fields[NFields].Kind := 4; Fields[NFields].Lbl := Lbl;
 If On Then Fields[NFields].Cur := 1 Else Fields[NFields].Cur := 0;
 Inc(NFields);
End;

Procedure FldLabel(Const Txt: String);
Begin
 Fields[NFields].Kind := 9; Fields[NFields].Lbl := Copy(Txt, 1, 30); Fields[NFields].Val := Txt;
 Inc(NFields);
End;

Function FInt(I: Integer): LongInt;
Begin
 Case Fields[I].Kind Of
  1: FInt := StrInt(Fields[I].Val, Fields[I].Mn);
  2, 4: FInt := Fields[I].Cur;
  3: FInt := Fields[I].Mn;
 Else FInt := 0;
 End;
End;

Function ChoiceText(Const Choices: String; Idx: Integer): String;
Var
 S: String;
 I, K: Integer;
Begin
 S := Choices + '|';
 For I := 0 To Idx - 1 Do Begin
  K := Pos('|', S);
  If K = 0 Then Break;
  Delete(S, 1, K);
 End;
 K := Pos('|', S);
 If K = 0 Then ChoiceText := S Else ChoiceText := Copy(S, 1, K - 1);
End;

Function ChoiceCount(Const Choices: String): Integer;
Var
 I, N: Integer;
Begin
 N := 1;
 For I := 1 To Length(Choices) Do If Choices[I] = '|' Then Inc(N);
 ChoiceCount := N;
End;

Var
 FormLblW: Integer;

Procedure DrawFormRow(I, Focus: Integer; Blink: Boolean; ReplaceMode: Boolean);
Var
 Y, X0, W, C: Integer;
 S: String;
Begin
 Y := DlgY1 + 26 + I * 24;
 X0 := DlgX1 + FormLblW;
 W := DlgX2 - X0 - 12;
 SetFillStyle(SolidFill, LightGray);
 Bar(DlgX1 + 4, Y, DlgX2 - 4, Y + 22);
 If Fields[I].Kind = 9 Then Begin
  SetColor(Black);
  DS(DlgX1 + 14, Y + 8, Fields[I].Val);
  Exit;
 End;
 SetColor(Black);
 DS(DlgX1 + 12, Y + 7, Fields[I].Lbl);
 Case Fields[I].Kind Of
  0, 1: Begin
   Field3D(X0, Y + 1, X0 + W, Y + 19);
   S := Fields[I].Val;
   If ReplaceMode And (I = Focus) Then Begin
    SetFillStyle(SolidFill, Blue);
    Bar(X0 + 3, Y + 3, X0 + 3 + TW(S) - 1, Y + 17);
    SetColor(White);
   End
   Else SetColor(Black);
   While TW(S) > W - 8 Do Delete(S, 1, 1);
   DS(X0 + 4, Y + 7, S);
   If (I = Focus) And Blink And Not ReplaceMode Then Begin
    SetColor(Black);
    Line(X0 + 4 + TW(S), Y + 4, X0 + 4 + TW(S), Y + 16);
   End;
  End;
  2: Begin
   Field3D(X0, Y + 1, X0 + W, Y + 19);
   SetColor(Black);
   DS(X0 + 4, Y + 7, ChoiceText(Fields[I].Choices, Fields[I].Cur));
   Tri(X0 + W - 14, Y + 7, X0 + W - 6, Y + 7, X0 + W - 10, Y + 13, Black);
  End;
  3: Begin
   Field3D(X0, Y + 1, X0 + 46, Y + 19);
   SetFillStyle(SolidFill, Nearest16(Fields[I].Mn));
   Bar(X0 + 3, Y + 4, X0 + 43, Y + 16);
   SetColor(Black);
   DS(X0 + 54, Y + 7, 'Cliquer pour changer');
  End;
  4: Begin
   Field3D(X0, Y + 3, X0 + 14, Y + 17);
   If Fields[I].Cur <> 0 Then Begin
    SetColor(Black);
    Line(X0 + 3, Y + 9, X0 + 6, Y + 14); Line(X0 + 6, Y + 14, X0 + 12, Y + 5);
    Line(X0 + 4, Y + 9, X0 + 7, Y + 14); Line(X0 + 7, Y + 14, X0 + 13, Y + 5);
   End;
  End;
 End;
 If I = Focus Then Begin
  SetColor(Blue);
  SetLineStyle(DottedLn, 0, 1);
  Rectangle(DlgX1 + 6, Y, DlgX2 - 6, Y + 22);
  SetLineStyle(SolidLn, 0, 1);
 End;
End;

Function FormDialog(Const Title: String): Boolean;
Var
 W, H, I, Focus, K, BY, L, Cnt: Integer;
 Done, OK, Ext, Replace, Blink: Boolean;
 T0: LongInt;
 X0, Y, C: LongInt;
 Col: LongInt;
 N: LongInt;
 Ch: Char;
Begin
 FormLblW := 150;
 For I := 0 To NFields - 1 Do
  If (Fields[I].Kind <> 9) And (TW(Fields[I].Lbl) + 24 > FormLblW) Then FormLblW := TW(Fields[I].Lbl) + 24;
 W := FormLblW + 270;
 If W > 640 Then W := 640;
 H := 78 + NFields * 24;
 Focus := 0;
 While (Focus < NFields) And (Fields[Focus].Kind = 9) Do Inc(Focus);
 If Focus >= NFields Then Focus := 0;
 Replace := True;
 HideMouse;
 DlgFrame(W, H, Title);
 For I := 0 To NFields - 1 Do DrawFormRow(I, Focus, True, Replace);
 BY := DlgY2 - 30;
 PushButton(DlgX1 + W Div 2 - 90, BY, DlgX1 + W Div 2 - 10, BY + 22, 'OK', False);
 PushButton(DlgX1 + W Div 2 + 10, BY, DlgX1 + W Div 2 + 90, BY + 22, 'Annuler', False);
 ShowMouse;
 Done := False; OK := False;
 PollMouse; OMB := MB_;
 T0 := NowMs;
 Blink := True;
 While Not Done Do Begin
  PollMouse;
  If MouseClicked Then Begin
   If InRect(MX_, MY_, DlgX1 + W Div 2 - 90, BY, DlgX1 + W Div 2 - 10, BY + 22) Then Begin OK := True; Done := True; End
   Else If InRect(MX_, MY_, DlgX1 + W Div 2 + 10, BY, DlgX1 + W Div 2 + 90, BY + 22) Then Done := True
   Else Begin
    For I := 0 To NFields - 1 Do Begin
     Y := DlgY1 + 26 + I * 24;
     If (Fields[I].Kind <> 9) And InRect(MX_, MY_, DlgX1 + 6, Y, DlgX2 - 6, Y + 22) Then Begin
      L := Focus;
      Focus := I;
      Replace := False;
      Case Fields[I].Kind Of
       2: Begin
        Cnt := ChoiceCount(Fields[I].Choices);
        Fields[I].Cur := (Fields[I].Cur + 1) Mod Cnt;
       End;
       3: Begin
        WaitMouseUp;
        Col := PickColor(Fields[I].Lbl, Fields[I].Mn);
        If Col >= 0 Then Fields[I].Mn := Col;
        HideMouse;
        DlgFrame(W, H, Title);
        For K := 0 To NFields - 1 Do DrawFormRow(K, Focus, Blink, Replace);
        PushButton(DlgX1 + W Div 2 - 90, BY, DlgX1 + W Div 2 - 10, BY + 22, 'OK', False);
        PushButton(DlgX1 + W Div 2 + 10, BY, DlgX1 + W Div 2 + 90, BY + 22, 'Annuler', False);
        ShowMouse;
       End;
       4: Fields[I].Cur := 1 - Fields[I].Cur;
      End;
      HideMouse;
      DrawFormRow(L, Focus, Blink, Replace);
      DrawFormRow(I, Focus, Blink, Replace);
      ShowMouse;
     End;
    End;
   End;
  End;
  K := GetKeyEx(Ext);
  If K >= 0 Then Begin
   If Ext Then Begin
    Case K Of
     72: Begin
      L := Focus;
      Repeat Focus := (Focus + NFields - 1) Mod NFields Until Fields[Focus].Kind <> 9;
      Replace := True;
      HideMouse; DrawFormRow(L, Focus, Blink, Replace); DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
     End;
     80: Begin
      L := Focus;
      Repeat Focus := (Focus + 1) Mod NFields Until Fields[Focus].Kind <> 9;
      Replace := True;
      HideMouse; DrawFormRow(L, Focus, Blink, Replace); DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
     End;
     75, 77: Begin
      If Fields[Focus].Kind = 2 Then Begin
       Cnt := ChoiceCount(Fields[Focus].Choices);
       If K = 77 Then Fields[Focus].Cur := (Fields[Focus].Cur + 1) Mod Cnt
       Else Fields[Focus].Cur := (Fields[Focus].Cur + Cnt - 1) Mod Cnt;
       HideMouse; DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
      End;
     End;
     15: Begin
      L := Focus;
      Repeat Focus := (Focus + NFields - 1) Mod NFields Until Fields[Focus].Kind <> 9;
      Replace := True;
      HideMouse; DrawFormRow(L, Focus, Blink, Replace); DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
     End;
    End;
   End
   Else Begin
    Case K Of
     13: Begin OK := True; Done := True; End;
     27: Done := True;
     9: Begin
      L := Focus;
      Repeat Focus := (Focus + 1) Mod NFields Until Fields[Focus].Kind <> 9;
      Replace := True;
      HideMouse; DrawFormRow(L, Focus, Blink, Replace); DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
     End;
     8: If Fields[Focus].Kind In [0, 1] Then Begin
      If Replace Then Fields[Focus].Val := ''
      Else If Length(Fields[Focus].Val) > 0 Then Delete(Fields[Focus].Val, Length(Fields[Focus].Val), 1);
      Replace := False;
      HideMouse; DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
     End;
     32: Begin
      If Fields[Focus].Kind = 4 Then Fields[Focus].Cur := 1 - Fields[Focus].Cur
      Else If Fields[Focus].Kind = 2 Then Fields[Focus].Cur := (Fields[Focus].Cur + 1) Mod ChoiceCount(Fields[Focus].Choices)
      Else If Fields[Focus].Kind = 0 Then Begin
       If Replace Then Begin Fields[Focus].Val := ''; Replace := False; End;
       If Length(Fields[Focus].Val) < 119 Then Fields[Focus].Val := Fields[Focus].Val + ' ';
      End;
      HideMouse; DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
     End;
    Else
     If (K >= 33) And (Fields[Focus].Kind In [0, 1]) Then Begin
      If Fields[Focus].Kind = 1 Then Begin
       If Not ((K >= 48) And (K <= 57)) And (K <> 45) Then K := 0;
      End;
      If K > 0 Then Begin
       If Replace Then Begin Fields[Focus].Val := ''; Replace := False; End;
       If K >= 128 Then K := Dos2Win(K);
       L := Fields[Focus].Mx;
       If (Fields[Focus].Kind = 1) Or (L <= 0) Or (L > 119) Then L := 119;
       If Fields[Focus].Kind = 1 Then L := 7;
       If Length(Fields[Focus].Val) < L Then Fields[Focus].Val := Fields[Focus].Val + Chr(K);
       HideMouse; DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
      End;
     End;
    End;
   End;
  End;
  If ((NowMs - T0) Div 500) Mod 2 = 0 Then C := 1 Else C := 0;
  If (C = 1) <> Blink Then Begin
   Blink := C = 1;
   If Fields[Focus].Kind In [0, 1] Then Begin
    HideMouse; DrawFormRow(Focus, Focus, Blink, Replace); ShowMouse;
   End;
  End;
  Delay(10);
 End;
 WaitMouseUp;
 If OK Then Begin
  For I := 0 To NFields - 1 Do
   If Fields[I].Kind = 1 Then Begin
    N := StrInt(Fields[I].Val, Fields[I].Mn);
    If N < Fields[I].Mn Then N := Fields[I].Mn;
    If N > Fields[I].Mx Then N := Fields[I].Mx;
    Fields[I].Val := IStr(N);
   End;
 End;
 FormDialog := OK;
End;

Function InputBox(Const Title, Prompt: String; Var S: String; Max: Integer): Boolean;
Begin
 FldInit;
 FldText(Prompt, S, Max);
 If FormDialog(Title) Then Begin
  S := Fields[0].Val;
  InputBox := True;
 End
 Else InputBox := False;
End;

{ ---------------------------------------------------------------------- }
{ Sélecteur de fichiers                                                      }
{ ---------------------------------------------------------------------- }

Type
 TFileEnt = Record
  Name: String[60];
  Dir: Boolean;
 End;
 TFileArr = Array[0..399] Of TFileEnt;
 PFileArr = ^TFileArr;

Var
 FEnts: PFileArr;
 FCount: Integer;

Function JoinPath(Const Dir, Name: String): String;
Begin
 If Dir = '' Then JoinPath := Name
 Else If (Dir[Length(Dir)] = '\') Or (Dir[Length(Dir)] = '/') Then JoinPath := Dir + Name
 Else JoinPath := Dir + PathSep + Name;
End;

Function ParentDir(Const Dir: String): String;
Var
 I: Integer;
Begin
 I := Length(Dir);
 If (I > 1) And ((Dir[I] = '\') Or (Dir[I] = '/')) Then Dec(I);
 While (I > 1) And (Dir[I] <> '\') And (Dir[I] <> '/') Do Dec(I);
 If I <= 1 Then ParentDir := Copy(Dir, 1, 1)
 Else If (I = 3) And (Dir[2] = ':') Then ParentDir := Copy(Dir, 1, 3)
 Else ParentDir := Copy(Dir, 1, I - 1);
End;

Function MatchExt(Const Name: String; All: Boolean): Boolean;
Begin
 If All Then MatchExt := True Else MatchExt := ExtOf(Name) = '.PDF';
End;

Procedure ScanDir(Const Dir: String; All: Boolean);
Var
 SR: SearchRec;
 I, J: Integer;
 T: TFileEnt;
 Lower: Boolean;
Begin
 FCount := 0;
 If Length(Dir) > 1 Then Begin
  FEnts^[0].Name := '..'; FEnts^[0].Dir := True; FCount := 1;
 End;
 FindFirst(JoinPath(Dir, '*'), AnyFile, SR);
 While DosError = 0 Do Begin
  If (SR.Name <> '.') And (SR.Name <> '..') And (FCount < 400) Then Begin
   If (SR.Attr And Directory) <> 0 Then Begin
    FEnts^[FCount].Name := SR.Name; FEnts^[FCount].Dir := True; Inc(FCount);
   End
   Else If MatchExt(SR.Name, All) Then Begin
    FEnts^[FCount].Name := SR.Name; FEnts^[FCount].Dir := False; Inc(FCount);
   End;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 For I := 1 To FCount - 1 Do Begin
  T := FEnts^[I];
  J := I - 1;
  While J >= 0 Do Begin
   If FEnts^[J].Name = '..' Then Lower := False
   Else If T.Name = '..' Then Lower := True
   Else If FEnts^[J].Dir <> T.Dir Then Lower := T.Dir
   Else Lower := UpStr(T.Name) < UpStr(FEnts^[J].Name);
   If Not Lower Then Break;
   FEnts^[J + 1] := FEnts^[J];
   Dec(J);
  End;
  FEnts^[J + 1] := T;
 End;
End;

Function FileDialog(Const Title: String; Var FileName: String; Save: Boolean; Const DefExt: String): Boolean;
Const
 ROWS = 12;
Var
 W, H, I, Top, Sel, K, LX1, LY1, LX2, LY2, Hit, BY: Integer;
 NameF: String;
 Done, OK, Ext, Dirty, DblC: Boolean;
 Ofs, LastT: LongInt;
 SBPos: LongInt;
 Dragging, Fresh: Boolean;
 Idx: LongInt;
 Full: String;
 R: Integer;

 Procedure Draw;
 Var
  J, Y: Integer;
  S: String;
 Begin
  HideMouse;
  DlgFrame(W, H, Title);
  SetColor(Black);
  S := LastDir;
  While TW(S) > W - 28 Do Delete(S, 1, 1);
  DS(DlgX1 + 12, DlgY1 + 24, S);
  LX1 := DlgX1 + 12; LY1 := DlgY1 + 38; LX2 := DlgX2 - 12 - SBAR; LY2 := LY1 + ROWS * 12 + 3;
  Field3D(LX1, LY1, LX2, LY2);
  For J := 0 To ROWS - 1 Do Begin
   If Top + J >= FCount Then Break;
   Y := LY1 + 3 + J * 12;
   If Top + J = Sel Then Begin
    SetFillStyle(SolidFill, Blue);
    Bar(LX1 + 3, Y - 1, LX2 - 3, Y + 10);
    SetColor(White);
   End
   Else SetColor(Black);
   If FEnts^[Top + J].Dir Then S := '[' + FEnts^[Top + J].Name + ']' Else S := FEnts^[Top + J].Name;
   DS(LX1 + 6, Y + 1, Copy(S, 1, (LX2 - LX1 - 12) Div 8));
  End;
  DrawSB(LX2 + 1, LY1, LX2 + SBAR, LY2, True, Top, IMax(FCount, ROWS), ROWS);
  SetColor(Black);
  DS(DlgX1 + 12, LY2 + 10, 'Nom :');
  Field3D(DlgX1 + 56, LY2 + 6, DlgX2 - 12, LY2 + 22);
  S := NameF;
  While TW(S) > DlgX2 - 12 - DlgX1 - 56 - 10 Do Delete(S, 1, 1);
  SetColor(Black);
  DS(DlgX1 + 60, LY2 + 10, S);
  Line(DlgX1 + 60 + TW(S), LY2 + 8, DlgX1 + 60 + TW(S), LY2 + 20);
  BY := DlgY2 - 28;
  If Save Then PushButton(DlgX1 + 12, BY, DlgX1 + 112, BY + 20, 'Enregistrer', False)
  Else PushButton(DlgX1 + 12, BY, DlgX1 + 112, BY + 20, 'Ouvrir', False);
  PushButton(DlgX1 + 122, BY, DlgX1 + 202, BY + 20, 'Annuler', False);
  If FileMaskAll Then PushButton(DlgX1 + 212, BY, DlgX2 - 12, BY + 20, 'Type : Tous', False)
  Else PushButton(DlgX1 + 212, BY, DlgX2 - 12, BY + 20, 'Type : PDF', False);
  ShowMouse;
 End;

 Procedure Rescan;
 Begin
  ScanDir(LastDir, FileMaskAll);
  Top := 0; Sel := -1;
 End;

 Procedure Enter(Idx: Integer);
 Begin
  If FEnts^[Idx].Name = '..' Then LastDir := ParentDir(LastDir)
  Else LastDir := JoinPath(LastDir, FEnts^[Idx].Name);
  Rescan;
 End;

Begin
 W := 440;
 H := 38 + ROWS * 12 + 90;
 If FEnts = Nil Then GetMem(FEnts, SizeOf(TFileArr));
 If LastDir = '' Then GetDir(0, LastDir);
 NameF := BaseName(FileName);
 Fresh := NameF <> '';
 Rescan;
 Draw;
 Done := False; OK := False;
 Dragging := False;
 Ofs := 0;
 LastT := 0;
 PollMouse; OMB := MB_;
 While Not Done Do Begin
  PollMouse;
  If Dragging Then Begin
   If (MB_ And 1) = 0 Then Dragging := False
   Else Begin
    Top := SBDragPos(LX2 + 1, LY1, LX2 + SBAR, LY2, True, IMax(FCount, ROWS), ROWS, MX_, MY_, Ofs);
    HideMouse; Draw; ShowMouse;
   End;
  End
  Else If MouseClicked Then Begin
   Dirty := False;
   If InRect(MX_, MY_, LX1, LY1, LX2, LY2) Then Begin
    I := (MY_ - LY1 - 3) Div 12 + Top;
    If (I >= 0) And (I < FCount) And (MY_ >= LY1 + 3) Then Begin
     DblC := (I = Sel) And (NowMs - LastT < 450);
     Sel := I;
     LastT := NowMs;
     If FEnts^[I].Dir Then Begin
      If DblC Then Enter(I);
     End
     Else Begin
      NameF := FEnts^[I].Name;
      Fresh := False;
      If DblC Then Begin OK := True; Done := True; End;
     End;
     Dirty := True;
    End;
   End
   Else If InRect(MX_, MY_, LX2 + 1, LY1, LX2 + SBAR, LY2) Then Begin
    Hit := SBHit(LX2 + 1, LY1, LX2 + SBAR, LY2, True, Top, IMax(FCount, ROWS), ROWS, MX_, MY_, Ofs);
    Case Hit Of
     1: Dec(Top);
     2: Inc(Top);
     3: Dec(Top, ROWS);
     4: Inc(Top, ROWS);
     5: Dragging := True;
    End;
    If Top > FCount - ROWS Then Top := FCount - ROWS;
    If Top < 0 Then Top := 0;
    Dirty := True;
   End
   Else If InRect(MX_, MY_, DlgX1 + 12, BY, DlgX1 + 112, BY + 20) Then Begin OK := True; Done := True; End
   Else If InRect(MX_, MY_, DlgX1 + 122, BY, DlgX1 + 202, BY + 20) Then Done := True
   Else If InRect(MX_, MY_, DlgX1 + 212, BY, DlgX2 - 12, BY + 20) Then Begin
    FileMaskAll := Not FileMaskAll;
    Rescan;
    Dirty := True;
   End;
   If Dirty Then Draw;
  End;
  K := GetKeyEx(Ext);
  If K >= 0 Then Begin
   If Ext Then Begin
    Case K Of
     72: If Sel > 0 Then Begin Dec(Sel); If Sel < Top Then Top := Sel; End;
     80: If Sel < FCount - 1 Then Begin Inc(Sel); If Sel >= Top + ROWS Then Top := Sel - ROWS + 1; End;
     73: Begin Dec(Top, ROWS); If Top < 0 Then Top := 0; End;
     81: Begin Inc(Top, ROWS); If Top > FCount - ROWS Then Top := FCount - ROWS; If Top < 0 Then Top := 0; End;
    End;
    If (K = 72) Or (K = 80) Then If (Sel >= 0) And Not FEnts^[Sel].Dir Then NameF := FEnts^[Sel].Name;
    Draw;
   End
   Else Begin
    Case K Of
     27: Done := True;
     13: Begin
      If (NameF = '') And (Sel >= 0) And FEnts^[Sel].Dir Then Begin Enter(Sel); Draw; End
      Else If NameF <> '' Then Begin OK := True; Done := True; End;
     End;
     8: Begin
      If Fresh Then NameF := ''
      Else If Length(NameF) > 0 Then Delete(NameF, Length(NameF), 1);
      Fresh := False;
      Draw;
     End;
    Else
     If (K >= 32) And (Length(NameF) < 100) Then Begin
      If Fresh Then NameF := '';
      Fresh := False;
      NameF := NameF + Chr(K);
      Draw;
     End;
    End;
   End;
  End;
  If OK And Done Then Begin
   { répertoire saisi ? }
   If NameF = '' Then Begin OK := False; Done := False; End
   Else Begin
    Full := NameF;
    If (Pos('/', Full) = 0) And (Pos('\', Full) = 0) Then Full := JoinPath(LastDir, Full)
    Else Full := FExpand(Full);
    If Save Then Begin
     If ExtOf(Full) = '' Then Full := Full + DefExt;
     If FileExists(Full) Then Begin
      R := MsgBox('Enregistrer', BaseName(Full) + ' existe déjà.|Voulez-vous le remplacer ?', 1);
      If R = 0 Then Begin OK := False; Done := False; Draw; End;
     End;
    End
    Else Begin
     If Not FileExists(Full) Then Begin
      R := MsgBox('Ouvrir', 'Fichier introuvable :|' + Full, 0);
      OK := False; Done := False; Draw;
     End;
    End;
   End;
  End;
  Delay(10);
 End;
 WaitMouseUp;
 If OK Then Begin
  FileName := Full;
  FileDialog := True;
 End
 Else FileDialog := False;
End;

{ ---------------------------------------------------------------------- }
{ Dialogues d'information                                                    }
{ ---------------------------------------------------------------------- }

Var
 InfoLines: Array[0..39] Of String[78];
 InfoN: Integer;

Procedure InfoBegin;
Begin
 InfoN := 0;
End;

Procedure InfoAdd(Const S: String);
Begin
 If InfoN < 40 Then Begin
  InfoLines[InfoN] := Copy(U2C(S), 1, 78);
  Inc(InfoN);
 End;
End;

Procedure InfoDialog(Const Title: String; W: Integer);
Var
 I, H, K: Integer;
 Done, Ext: Boolean;
Begin
 H := 70 + InfoN * 11;
 HideMouse;
 DlgFrame(W, H, Title);
 SetColor(Black);
 For I := 0 To InfoN - 1 Do OutTextXY(DlgX1 + 14, DlgY1 + 26 + I * 11, InfoLines[I]);
 PushButton(DlgX1 + W Div 2 - 40, DlgY2 - 28, DlgX1 + W Div 2 + 40, DlgY2 - 8, 'OK', False);
 ShowMouse;
 Done := False;
 PollMouse; OMB := MB_;
 While Not Done Do Begin
  PollMouse;
  If MouseClicked Then
   If InRect(MX_, MY_, DlgX1 + W Div 2 - 40, DlgY2 - 28, DlgX1 + W Div 2 + 40, DlgY2 - 8) Then Done := True;
  K := GetKeyEx(Ext);
  If (K = 13) Or (K = 27) Then Done := True;
  Delay(10);
 End;
 WaitMouseUp;
End;

{ ---------------------------------------------------------------------- }
{ Opérations sur le document                                               }
{ ---------------------------------------------------------------------- }

Var
 Imported: Boolean;
 EditNew: Boolean;
 EditBackup: String;
 SigName: String;
 InkX, InkY: Array[0..399] Of Integer;
 InkN: Integer;
 LastNavPage: Integer;
 SortIdx: PLArr;
 LastHintX, LastHintY: LongInt;
 MoveDX, MoveDY: LongInt;

Const
 StampNames: String = 'APPROUVÉ|REFUSÉ|CONFIDENTIEL|BROUILLON|FINAL|URGENT|COPIE|POUR COMMENTAIRE';
 StampCols: Array[0..7] Of LongInt = ($00A000, $FF0000, $FF0000, $0000C0, $00A000, $FF0000, $0000C0, $0000C0);

Procedure DropUndo;
Begin
 If UndoTop > 0 Then Begin
  Dec(UndoTop);
  FreeUndoRec(UndoStack[UndoTop]);
 End;
End;

Procedure FullRefresh;
Begin
 Relayout;
 RedrawAll;
End;

Procedure ZoomTo(Z: Integer; CX, CY: LongInt);
Var
 FX, FY: Real;
Begin
 If Z < 10 Then Z := 10;
 If Z > 1600 Then Z := 1600;
 FX := (ScrollX + CX) / Scale;
 FY := (ScrollY + CY) / Scale;
 Zoom := Z;
 FitMode := 0;
 Relayout;
 ScrollY := Round(FY * Scale) - CY;
 ScrollX := Round(FX * Scale) - CX;
 ClampScroll;
 If Continuous <> 0 Then UpdateCurPage;
 RedrawAll;
End;

Procedure StepZoom(Dir: Integer);
Var
 I, Z: Integer;
Begin
 Z := Zoom;
 If Dir > 0 Then Begin
  Z := ZoomSteps[11];
  For I := 11 DownTo 0 Do If ZoomSteps[I] > Zoom Then Z := ZoomSteps[I];
  If Zoom >= 800 Then Z := Zoom;
 End
 Else Begin
  Z := ZoomSteps[0];
  For I := 0 To 11 Do If ZoomSteps[I] < Zoom Then Z := ZoomSteps[I];
  If Zoom <= 25 Then Z := Zoom;
 End;
 ZoomTo(Z, ViewW Div 2, ViewH Div 2);
End;

Procedure SetTool(T: Integer);
Begin
 CurTool := T;
 DragMode := 0;
 DrawToolbar;
End;

Function ConfirmDiscard: Boolean;
Forward;

Procedure OpenFileByName(Const Name: String);
Var
 Err: String;
Begin
 ShowProgress('Ouverture de ' + BaseName(Name) + '... (Échap pour interrompre)');
 If ImportPDF(Name, False, Err) Then Begin
  DocName := Name;
  Modified := False;
  Imported := True;
  CurPage := 1;
  SelObj := -1; FindObj := -1;
  ClearUndo;
  ScrollX := 0; ScrollY := 0;
  FitMode := 1;
  NavScroll := 0;
  FullRefresh;
  If LoadNotice <> '' Then Notice(LoadNotice);
 End
 Else Begin
  If PageCount = 0 Then NewDocument;
  FullRefresh;
  Notice(Err);
 End;
End;

{ Enregistre sous Name : mise à jour incrémentale si le document vient d'un
  PDF (le contenu d'origine est conservé), sinon écriture complète. Le
  document est ensuite rechargé depuis le fichier enregistré. }
Function SaveTo(Const Name: String): Boolean;
Var
 Err: String;
 R: Integer;
 SP, SZ, SF: LongInt;
 SSY: LongInt;
 Ok: Boolean;
Begin
 SaveTo := False;
 ShowProgress('Enregistrement...');
 Ok := False;
 If SrcValid And NeedFullRewrite Then Begin
  RedrawAll;
  If MsgBox('Enregistrer', 'Les biffures doivent supprimer définitivement le contenu : le document va être réécrit complètement (les polices incorporées d''origine seront remplacées).', 1) = 0 Then Exit;
  ShowProgress('Enregistrement...');
 End
 Else If SrcValid Then Begin
  Ok := SaveIncremental(Name, Err);
  If Not Ok Then Begin
   RedrawAll;
   R := MsgBox('Enregistrer', Err + '|Réécrire le document complet ? Les polices incorporées d''origine seraient alors remplacées.', 1);
   If R = 0 Then Exit;
   ShowProgress('Enregistrement...');
  End;
 End;
 If Not Ok Then Begin
  If Not SaveAsPDF(Name) Then Begin
   RedrawAll;
   Notice('Impossible d''enregistrer le fichier.');
   Exit;
  End;
 End;
 { rechargement du fichier enregistré en conservant la vue }
 SP := CurPage; SZ := Zoom; SF := FitMode; SSY := ScrollY;
 OpenFileByName(Name);
 If PageCount >= 1 Then Begin
  Zoom := SZ; FitMode := SF;
  Relayout;
  GotoPage(SP);
  If (Continuous <> 0) And (FitMode = 0) Then ScrollY := SSY;
  ClampScroll;
  RedrawAll;
 End;
 SetStatus('Document enregistré : ' + BaseName(Name));
 SaveTo := True;
End;

Function DoSaveAs: Boolean;
Var
 Name: String;
Begin
 DoSaveAs := False;
 Name := DocName;
 If Name = '' Then Name := 'document.pdf';
 FileMaskAll := False;
 If Not FileDialog('Enregistrer sous', Name, True, '.pdf') Then Begin RedrawAll; Exit; End;
 DoSaveAs := SaveTo(Name);
End;

Function DoSave: Boolean;
Begin
 If DocName = '' Then DoSave := DoSaveAs
 Else DoSave := SaveTo(DocName);
End;

Function ConfirmDiscard: Boolean;
Var
 R: Integer;
Begin
 ConfirmDiscard := True;
 If Not Modified Then Exit;
 R := MsgBox('Acrobat', 'Enregistrer les modifications apportées au document ?', 2);
 If R = 0 Then ConfirmDiscard := False
 Else If R = 1 Then Begin
  If Not DoSave Then ConfirmDiscard := False;
 End;
End;

Function ChangeExt_(Const Name, NewExt: String): String;
Var
 I: Integer;
Begin
 If Name = '' Then Begin ChangeExt_ := 'document' + NewExt; Exit; End;
 I := Length(Name);
 While (I > 0) And (Name[I] <> '.') And (Name[I] <> '\') And (Name[I] <> '/') Do Dec(I);
 If (I > 0) And (Name[I] = '.') Then ChangeExt_ := Copy(Name, 1, I - 1) + NewExt Else ChangeExt_ := Name + NewExt;
End;

Procedure ExportText(Const Name: String);
Var
 T: Text;
 Pg, I, J, N, K: Integer;
 Lower: Boolean;
 LastY: LongInt;
 First: Boolean;
 PrevX2: LongInt;
 A, B: ^TObjRec;
Begin
 GetMem(SortIdx, (ObjCount + 2) * SizeOf(LongInt));
 {$I-}
 Assign(T, Name);
 Rewrite(T);
 {$I+}
 If IOResult <> 0 Then Begin FreeMem(SortIdx, (ObjCount + 2) * SizeOf(LongInt)); Notice('Impossible de créer le fichier.'); Exit; End;
 For Pg := 1 To PageCount Do Begin
  WriteLn(T, '--- Page ', Pg, ' ---');
  N := 0;
  For I := 0 To ObjCount - 1 Do
   If (ObjP(I)^.Page = Pg) And (ObjP(I)^.Kind = K_TEXT) Then Begin
    K := N - 1;
    While K >= 0 Do Begin
     A := @ObjP(SortIdx^[K])^;
     B := @ObjP(I)^;
     If IAbs(A^.Y1 - B^.Y1) <= B^.Size Div 2 Then Lower := B^.X1 < A^.X1 Else Lower := B^.Y1 < A^.Y1;
     If Not Lower Then Break;
     SortIdx^[K + 1] := SortIdx^[K];
     Dec(K);
    End;
    SortIdx^[K + 1] := I;
    Inc(N);
   End;
  First := True;
  LastY := 0; PrevX2 := 0;
  For J := 0 To N - 1 Do Begin
   A := @ObjP(SortIdx^[J])^;
   If Not First Then Begin
    If IAbs(A^.Y1 - LastY) > A^.Size Div 2 + 1 Then WriteLn(T)
    Else If A^.X1 - PrevX2 > 1 Then Write(T, ' ');
   End;
   Write(T, A^.Txt);
   LastY := A^.Y1; PrevX2 := A^.X2;
   First := False;
  End;
  If Not First Then WriteLn(T);
  WriteLn(T);
 End;
 Close(T);
 FreeMem(SortIdx, (ObjCount + 2) * SizeOf(LongInt));
End;

Procedure ExportBMP(Const Name: String);
Var
 F: File;
 W, H, Bands, BandH, B, Y, X, Row, RowBytes, I, Sc: LongInt;
 Hdr: Array[0..53] Of Byte;
 Pal: Array[0..15, 0..3] Of Byte;
 Line_: Array[0..399] Of Byte;
 DW, DH: LongInt;
 FileSz: LongInt;
 SavedZoom: Integer;
 Pix: Array[0..1] Of Byte;
 YY: LongInt;
Begin
 DW := DispWOf(CurPage, 1024);
 DH := DispHOf(CurPage, 1024);
 Sc := (500 * 1024) Div IMax(1, DW);
 If Sc > 2048 Then Sc := 2048;
 W := DispWOf(CurPage, Sc);
 H := DispHOf(CurPage, Sc);
 If W > 500 Then W := 500;
 RowBytes := ((W + 1) Div 2 + 3) And (Not 3);
 FillChar(Hdr, SizeOf(Hdr), 0);
 Hdr[0] := 66; Hdr[1] := 77;
 FileSz := 54 + 64 + RowBytes * H;
 Hdr[2] := FileSz And 255; Hdr[3] := (FileSz Shr 8) And 255; Hdr[4] := (FileSz Shr 16) And 255; Hdr[5] := FileSz Shr 24;
 Hdr[10] := 118; Hdr[14] := 40;
 Hdr[18] := W And 255; Hdr[19] := W Shr 8;
 Hdr[22] := H And 255; Hdr[23] := H Shr 8;
 Hdr[26] := 1; Hdr[28] := 4;
 Hdr[34] := (RowBytes * H) And 255; Hdr[35] := ((RowBytes * H) Shr 8) And 255; Hdr[36] := ((RowBytes * H) Shr 16) And 255;
 Hdr[46] := 16;
 For I := 0 To 15 Do Begin
  Pal[I, 0] := (PalRgb[I] And 255); Pal[I, 1] := (PalRgb[I] Shr 8) And 255; Pal[I, 2] := (PalRgb[I] Shr 16) And 255; Pal[I, 3] := 0;
 End;
 {$I-}
 Assign(F, Name);
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin Notice('Impossible de créer le fichier.'); Exit; End;
 BlockWrite(F, Hdr, 54);
 BlockWrite(F, Pal, 64);
 BandH := ViewH;
 Bands := (H + BandH - 1) Div BandH;
 For B := Bands - 1 DownTo 0 Do Begin
  HideMouse;
  SetViewPort(ViewL, ViewT, ViewR, ViewB, True);
  CullW := ViewW - 1; CullH := ViewH - 1;
  SetFillStyle(SolidFill, White);
  Bar(0, 0, ViewW, ViewH);
  RenderPage(CurPage, 0, -B * BandH, Sc, False);
  Y := IMin(BandH - 1, H - 1 - B * BandH);
  While Y >= 0 Do Begin
   FillChar(Line_, SizeOf(Line_), 0);
   X := 0;
   While X < W Do Begin
    Pix[0] := GetPixel(X, Y) And 15;
    If X + 1 < W Then Pix[1] := GetPixel(X + 1, Y) And 15 Else Pix[1] := 0;
    Line_[X Div 2] := (Pix[0] Shl 4) Or Pix[1];
    Inc(X, 2);
   End;
   BlockWrite(F, Line_, RowBytes);
   Dec(Y);
  End;
 End;
 SetFullView;
 Close(F);
 ShowMouse;
 FullRefresh;
End;

{ ---------------------------------------------------------------------- }
{ Création d'objets                                                         }
{ ---------------------------------------------------------------------- }

Function CreateText(Pg: Integer; X, Y: LongInt): Integer;
Var
 I: Integer;
 Tdx, Tdy, Tvx, Tvy: Real;
Begin
 PushUndo;
 I := NewObj(K_TEXT, Pg);
 If I < 0 Then Begin DropUndo; Notice('Limite d''objets atteinte.'); CreateText := -1; Exit; End;
 With ObjP(I)^ Do Begin
  X1 := X; Y1 := Y - CurSize Div 2;
  Size := CurSize;
  Style := CurFam * 4 + CurStyle;
  Rgb := ToolRgb[TL_TEXT];
  Txt := '';
  PN := (CurAngle Mod 360) * 10;
 End;
 { origine : le point cliqué est au milieu du début de la ligne }
 TextDirs(ObjP(I)^.PN, Tdx, Tdy, Tvx, Tvy);
 ObjP(I)^.X1 := Round(X - Tvx * TextLineH(ObjP(I)^) / 2);
 ObjP(I)^.Y1 := Round(Y - Tvy * TextLineH(ObjP(I)^) / 2);
 If ObjP(I)^.PN <> 0 Then PackOrigin(ObjP(I)^, ObjP(I)^.X1, ObjP(I)^.Y1);
 RecalcBox(I);
 CreateText := I;
End;

Procedure StartEdit(Idx: Integer; IsNew: Boolean);
Begin
 Editing := True;
 EditObj := Idx;
 EditNew := IsNew;
 EditBackup := ObjP(Idx)^.Txt;
 EditCaret := Length(ObjP(Idx)^.Txt);
 SelObj := Idx;
 If Not IsNew Then PushUndo;
 RedrawView;
End;

Procedure EndEdit(Commit: Boolean);
Begin
 If Not Editing Then Exit;
 Editing := False;
 If (EditObj >= 0) And (EditObj < ObjCount) Then Begin
  If (Not Commit) Or (ObjP(EditObj)^.Txt = '') Then Begin
   If EditNew Or (ObjP(EditObj)^.Txt = '') Then Begin
    DelObj(EditObj);
    If EditNew Then DropUndo;
   End
   Else Begin
    ObjP(EditObj)^.Txt := EditBackup;
    RecalcBox(EditObj);
    DropUndo;
   End;
  End
  Else RecalcBox(EditObj);
 End;
 EditObj := -1;
 RedrawView;
End;

Procedure EditKey(K: Integer; Ext: Boolean);
Var
 O: ^TObjRec;
Begin
 If (EditObj < 0) Or (EditObj >= ObjCount) Then Begin Editing := False; Exit; End;
 O := @ObjP(EditObj)^;
 If Ext Then Begin
  Case K Of
   75: If EditCaret > 0 Then Dec(EditCaret);
   77: If EditCaret < Length(O^.Txt) Then Inc(EditCaret);
   71: EditCaret := 0;
   79: EditCaret := Length(O^.Txt);
   83: If EditCaret < Length(O^.Txt) Then Delete(O^.Txt, EditCaret + 1, 1);
  End;
 End
 Else Begin
  Case K Of
   13: Begin EndEdit(True); Exit; End;
   27: Begin EndEdit(False); Exit; End;
   8: If EditCaret > 0 Then Begin Delete(O^.Txt, EditCaret, 1); Dec(EditCaret); End;
  Else
   If (K >= 32) And (K <> 127) And (Length(O^.Txt) < 118) Then Begin
    If K >= 128 Then K := Dos2Win(K);
    Insert(Chr(K), O^.Txt, EditCaret + 1);
    Inc(EditCaret);
   End;
  End;
 End;
 RecalcBox(EditObj);
 RedrawView;
End;

Function NewShape(Kind, Pg: Integer; AX1, AY1, AX2, AY2: LongInt; Tool: Integer): Integer;
Var
 I: Integer;
Begin
 I := NewObj(Kind, Pg);
 NewShape := I;
 If I < 0 Then Exit;
 With ObjP(I)^ Do Begin
  X1 := AX1; Y1 := AY1; X2 := AX2; Y2 := AY2;
  Rgb := ToolRgb[Tool];
  Wd := CurWidth;
 End;
End;

{ Marque le texte dans le rectangle (surlignage, soulignement, barré) }
Procedure MarkText(Kind, Pg: Integer; RX1, RY1, RX2, RY2: LongInt; Tool: Integer);
Var
 I, N, J, A, B, L, Idx, Made: Integer;
 TX1, TY1, TX2, TY2, CY: LongInt;
 Tot, Acc, Wc: Real;
 O: ^TObjRec;
 S: LongInt;
 NX1, NX2: LongInt;
Begin
 If RX1 > RX2 Then Begin S := RX1; RX1 := RX2; RX2 := S; End;
 If RY1 > RY2 Then Begin S := RY1; RY1 := RY2; RY2 := S; End;
 PushUndo;
 N := ObjCount;
 Made := 0;
 For I := 0 To N - 1 Do Begin
  O := @ObjP(I)^;
  If (O^.Page <> Pg) Or (O^.Kind <> K_TEXT) Or (TextAng(O^) <> 0) Then Continue;
  NormBox(O^, TX1, TY1, TX2, TY2);
  CY := (TY1 + TY2) Div 2;
  If (CY < RY1) Or (CY > RY2) Or (TX2 <= RX1) Or (TX1 >= RX2) Then Continue;
  L := Length(O^.Txt);
  If L = 0 Then Continue;
  Tot := 0;
  For J := 1 To L Do Tot := Tot + CharW(O^.Style Shr 2, O^.Style And 3, Ord(O^.Txt[J]));
  If Tot < 1 Then Continue;
  A := 0; B := 0;
  Acc := 0;
  For J := 1 To L Do Begin
   Wc := CharW(O^.Style Shr 2, O^.Style And 3, Ord(O^.Txt[J]));
   If (TX1 + (Acc + Wc / 2) / Tot * (TX2 - TX1) >= RX1) And (TX1 + (Acc + Wc / 2) / Tot * (TX2 - TX1) <= RX2) Then Begin
    If A = 0 Then A := J;
    B := J;
   End;
   Acc := Acc + Wc;
  End;
  If A = 0 Then Continue;
  Acc := 0;
  NX1 := TX1; NX2 := TX2;
  For J := 1 To L Do Begin
   Wc := CharW(O^.Style Shr 2, O^.Style And 3, Ord(O^.Txt[J]));
   If J = A Then NX1 := TX1 + Round(Acc / Tot * (TX2 - TX1));
   If J = B Then NX2 := TX1 + Round((Acc + Wc) / Tot * (TX2 - TX1));
   Acc := Acc + Wc;
  End;
  Idx := NewShape(Kind, Pg, NX1, TY1, NX2, TY2, Tool);
  If Idx < 0 Then Break;
  Inc(Made);
  If Made >= 150 Then Break;
 End;
 If Made = 0 Then Begin
  If (RX2 - RX1 < 3) Or (RY2 - RY1 < 3) Then Begin DropUndo; Exit; End;
  Idx := NewShape(Kind, Pg, RX1, RY1, RX2, RY2, Tool);
  If Idx < 0 Then Begin DropUndo; Exit; End;
 End;
 SelObj := ObjCount - 1;
End;

Procedure ChoiceStamp(Pg: Integer; CX, CY: LongInt);
Var
 I, K: Integer;
 Txt: String;
 W, H: LongInt;
Begin
 FldInit;
 FldChoice('Tampon', StampNames, 0);
 If Not FormDialog('Ajouter un tampon') Then Begin RedrawAll; Exit; End;
 K := Fields[0].Cur;
 Txt := U2W(ChoiceText(StampNames, K));
 PushUndo;
 I := NewObj(K_STAMP, Pg);
 If I < 0 Then Begin DropUndo; RedrawAll; Exit; End;
 W := TextLenPts(Txt, 18, 0, 1) + 12;
 H := 32;
 With ObjP(I)^ Do Begin
  X1 := CX - W Div 2; Y1 := CY - H Div 2; X2 := X1 + W; Y2 := Y1 + H;
  Size := 18; Style := 1; Wd := 2;
  Rgb := StampCols[K]; Rgb2 := $FFFFFF;
 End;
 ObjP(I)^.Txt := Txt;
 SelObj := I;
 RedrawAll;
End;

Procedure PlaceSignature(Pg: Integer; CX, CY: LongInt);
Var
 Nm, Reason, S1, S2: String;
 Y, M, D, DW, H, Mi, S, S1_: Word;
 I: Integer;
 W: LongInt;
Begin
 FldInit;
 FldText('Nom du signataire', SigName, 40);
 FldText('Motif (facultatif)', '', 40);
 FldColor('Couleur', $0000C0);
 If Not FormDialog('Signer le document') Then Begin RedrawAll; Exit; End;
 SigName := Fields[0].Val;
 If SigName = '' Then SigName := 'Signataire';
 Nm := U2W(SigName);
 Reason := U2W(Fields[1].Val);
 GetDate(Y, M, D, DW);
 GetTime(H, Mi, S, S1_);
 PushUndo;
 W := TextLenPts(Nm, 22, 1, 3) + 8;
 If W < 120 Then W := 120;
 I := NewObj(K_TEXT, Pg);
 If I >= 0 Then With ObjP(I)^ Do Begin
  X1 := CX - W Div 2 + 4; Y1 := CY - 30; Size := 22; Style := 1 * 4 + 3; Rgb := Fields[2].Mn; Txt := Nm;
  RecalcBox(I);
 End;
 I := NewObj(K_LINE, Pg);
 If I >= 0 Then With ObjP(I)^ Do Begin
  X1 := CX - W Div 2; Y1 := CY + 2; X2 := CX + W Div 2; Y2 := CY + 2; Wd := 1; Rgb := 0;
 End;
 S1 := 'Signé numériquement par ' + SigName;
 S2 := 'Date : ' + IStr(Y) + '.' + Pad2(M) + '.' + Pad2(D) + ' ' + Pad2(H) + ':' + Pad2(Mi) + ':' + Pad2(S);
 I := NewObj(K_TEXT, Pg);
 If I >= 0 Then With ObjP(I)^ Do Begin
  X1 := CX - W Div 2; Y1 := CY + 4; Size := 7; Style := 0; Rgb := $606060; Txt := U2W(S1);
  RecalcBox(I);
 End;
 I := NewObj(K_TEXT, Pg);
 If I >= 0 Then With ObjP(I)^ Do Begin
  X1 := CX - W Div 2; Y1 := CY + 12; Size := 7; Style := 0; Rgb := $606060; Txt := S2;
  RecalcBox(I);
 End;
 If Reason <> '' Then Begin
  I := NewObj(K_TEXT, Pg);
  If I >= 0 Then With ObjP(I)^ Do Begin
   X1 := CX - W Div 2; Y1 := CY + 20; Size := 7; Style := 0; Rgb := $606060; Txt := 'Motif : ' + Reason;
   RecalcBox(I);
  End;
 End;
 SelObj := -1;
 RedrawAll;
End;

Procedure FinishInk(Pg: Integer);
Var
 I, K, Pool: Integer;
Begin
 If InkN < 2 Then Exit;
 PushUndo;
 Pool := PoolAlloc(InkN);
 If Pool < 0 Then Begin DropUndo; Notice('Mémoire des tracés pleine.'); Exit; End;
 I := NewObj(K_INK, Pg);
 If I < 0 Then Begin DropUndo; Exit; End;
 For K := 0 To InkN - 1 Do Begin PoolXP(Pool + K)^ := InkX[K]; PoolYP(Pool + K)^ := InkY[K]; End;
 With ObjP(I)^ Do Begin
  P0 := Pool; PN := InkN; Wd := CurWidth; Rgb := ToolRgb[TL_PENCIL];
 End;
 RecalcBox(I);
 SelObj := I;
End;

{ ---------------------------------------------------------------------- }
{ Presse-papiers interne                                                     }
{ ---------------------------------------------------------------------- }

Procedure DoCopy;
Var
 K, Step: Integer;
Begin
 If (SelObj < 0) Or (SelObj >= ObjCount) Then Exit;
 Clip := ObjP(SelObj)^;
 ClipPtCount := 0;
 If Clip.Kind In [K_POLY, K_INK] Then Begin
  Step := (Clip.PN + 98) Div 99;
  If Step < 1 Then Step := 1;
  K := 0;
  While (K < Clip.PN) And (ClipPtCount < 99) Do Begin
   ClipPts[ClipPtCount * 2] := PoolXP(Clip.P0 + K)^;
   ClipPts[ClipPtCount * 2 + 1] := PoolYP(Clip.P0 + K)^;
   Inc(ClipPtCount);
   Inc(K, Step);
  End;
 End;
 ClipValid := True;
End;

Procedure DoPaste(DX, DY: LongInt);
Var
 I, K, Pool: Integer;
Begin
 If Not ClipValid Then Exit;
 PushUndo;
 Pool := 0;
 If Clip.Kind In [K_POLY, K_INK] Then Begin
  Pool := PoolAlloc(ClipPtCount);
  If Pool < 0 Then Begin DropUndo; Exit; End;
 End;
 I := NewObj(Clip.Kind, CurPage);
 If I < 0 Then Begin DropUndo; Exit; End;
 ObjP(I)^ := Clip;
 ObjP(I)^.Page := CurPage;
 If Clip.Kind In [K_POLY, K_INK] Then Begin
  For K := 0 To ClipPtCount - 1 Do Begin
   PoolXP(Pool + K)^ := ClipPts[K * 2];
   PoolYP(Pool + K)^ := ClipPts[K * 2 + 1];
  End;
  ObjP(I)^.P0 := Pool;
  ObjP(I)^.PN := ClipPtCount;
 End;
 MoveObj(I, DX, DY);
 SelObj := I;
End;

{ ---------------------------------------------------------------------- }
{ Recherche                                                                  }
{ ---------------------------------------------------------------------- }

Function ContainsText(Const Hay, Needle: String; CaseS: Boolean): Boolean;
Begin
 If CaseS Then ContainsText := Pos(Needle, Hay) > 0
 Else ContainsText := Pos(UpStr(Needle), UpStr(Hay)) > 0;
End;

Procedure FindNext;
Var
 Start, P, I, Pass, FirstI: Integer;
 Found: Integer;
Begin
 If FindText = '' Then Exit;
 Found := -1;
 If (FindObj >= 0) And (FindObj < ObjCount) Then Begin
  Start := ObjP(FindObj)^.Page; FirstI := FindObj + 1;
 End
 Else Begin Start := CurPage; FirstI := 0; End;
 For Pass := 0 To PageCount Do Begin
  P := ((Start - 1 + Pass) Mod PageCount) + 1;
  For I := 0 To ObjCount - 1 Do Begin
   If ObjP(I)^.Page <> P Then Continue;
   If ObjP(I)^.Kind <> K_TEXT Then Continue;
   If (Pass = 0) And (I < FirstI) Then Continue;
   If (Pass = PageCount) And (I >= FirstI) Then Continue;
   If ContainsText(ObjP(I)^.Txt, FindText, FindCase) Then Begin Found := I; Break; End;
  End;
  If Found >= 0 Then Break;
 End;
 If Found < 0 Then Begin
  FindObj := -1;
  RedrawAll;
  Notice('Aucune occurrence de "' + FindText + '" trouvée.');
  Exit;
 End;
 FindObj := Found;
 ScrollToObj(Found);
 RedrawAll;
End;

{ ---------------------------------------------------------------------- }
{ Propriétés                                                                 }
{ ---------------------------------------------------------------------- }

Procedure DocProperties;
Var
 S: String;
Begin
 FldInit;
 FldText('Titre', DocTitle, 79);
 FldText('Auteur', DocAuthor, 79);
 FldText('Sujet', DocSubject, 79);
 FldText('Mots-clés', DocKeywords, 79);
 FldText('Application', DocCreator, 79);
 FldLabel('Fichier : ' + Copy(BaseName(DocName), 1, 36));
 FldLabel('Pages : ' + IStr(PageCount) + '   Objets : ' + IStr(ObjCount));
 If FormDialog('Propriétés du document') Then Begin
  DocTitle := Fields[0].Val; DocAuthor := Fields[1].Val; DocSubject := Fields[2].Val;
  DocKeywords := Fields[3].Val; DocCreator := Fields[4].Val;
  Modified := True;
  InfoDirty := True;
 End;
 RedrawAll;
End;

Procedure ObjProperties;
Var
 O: ^TObjRec;
 K: Integer;
 Style: Integer;
Begin
 If (SelObj < 0) Or (SelObj >= ObjCount) Then Exit;
 O := @ObjP(SelObj)^;
 K := O^.Kind;
 FldInit;
 FldLabel('Type : ' + KindName(K) + '   Page ' + IStr(O^.Page));
 Case K Of
  K_TEXT: Begin
   FldText('Texte', O^.Txt, 118);
   FldNum('Taille (pt)', O^.Size, 4, 200);
   FldChoice('Police', 'Helvetica|Times|Courier', O^.Style Shr 2);
   FldCheck('Gras', (O^.Style And 1) <> 0);
   FldCheck('Italique', (O^.Style And 2) <> 0);
   FldColor('Couleur', O^.Rgb);
   FldNum('Angle (degrés)', TextAng(O^) Div 10, 0, 359);
  End;
  K_LINE, K_ARROW, K_INK: Begin
   FldNum('Épaisseur (pt)', O^.Wd, 1, 20);
   FldColor('Couleur', O^.Rgb);
  End;
  K_RECT, K_OVAL, K_POLY: Begin
   FldNum('Épaisseur (pt)', O^.Wd, 1, 20);
   FldColor('Couleur du contour', O^.Rgb);
   FldChoice('Remplissage', 'Aucun|Plein|Contour et plein', O^.Fill);
   FldColor('Couleur de remplissage', O^.Rgb2);
  End;
  K_HILITE, K_UNDER, K_STRIKE, K_NOTE: Begin
   FldColor('Couleur', O^.Rgb);
   FldText('Commentaire', O^.Txt, 118);
  End;
  K_STAMP: Begin
   FldText('Texte', O^.Txt, 40);
   FldColor('Couleur', O^.Rgb);
  End;
 Else
  Begin
   FldLabel('Aucune propriété modifiable.');
  End;
 End;
 If FormDialog('Propriétés de l''objet') Then Begin
  PushUndo;
  O := @ObjP(SelObj)^;
  Case K Of
   K_TEXT: Begin
    O^.Txt := U2W(Fields[1].Val); O^.Size := FInt(2);
    O^.Style := FInt(3) * 4 + FInt(4) + FInt(5) * 2;
    O^.Rgb := FInt(6);
    RecalcBox(SelObj);
    SetTextAngle(SelObj, FInt(7) * 10);
   End;
   K_LINE, K_ARROW, K_INK: Begin O^.Wd := FInt(1); O^.Rgb := FInt(2); End;
   K_RECT, K_OVAL, K_POLY: Begin
    O^.Wd := FInt(1); O^.Rgb := FInt(2); O^.Fill := FInt(3); O^.Rgb2 := FInt(4);
    If (O^.Fill = 1) Then O^.Rgb := O^.Rgb2;
   End;
   K_HILITE, K_UNDER, K_STRIKE, K_NOTE: Begin O^.Rgb := FInt(1); O^.Txt := U2W(Fields[2].Val); End;
   K_STAMP: Begin
    O^.Txt := U2W(Fields[1].Val); O^.Rgb := FInt(2);
    O^.X2 := O^.X1 + TextLenPts(O^.Txt, O^.Size, 0, 1) + 12;
   End;
  End;
 End;
 RedrawAll;
End;

Procedure EditSelected;
Var
 S: String;
 K, I: Integer;
Begin
 If (SelObj < 0) Or (SelObj >= ObjCount) Then Exit;
 K := ObjP(SelObj)^.Kind;
 Case K Of
  K_TEXT: StartEdit(SelObj, False);
  K_NOTE, K_HILITE, K_UNDER, K_STRIKE: Begin
   S := ObjP(SelObj)^.Txt;
   If InputBox('Commentaire', 'Texte', S, 118) Then Begin
    PushUndo;
    ObjP(SelObj)^.Txt := U2W(S);
   End;
   RedrawAll;
  End;
  K_STAMP: ObjProperties;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Opérations de pages                                                        }
{ ---------------------------------------------------------------------- }

Procedure InsertObjFirst(Pg: Integer; Var Idx: Integer);
Var
 J: LongInt;
Begin
 Idx := -1;
 If Not ObjEnsure(ObjCount) Then Exit;
 For J := ObjCount DownTo 1 Do ObjP(J)^ := ObjP(J - 1)^;
 Inc(ObjCount);
 InitObj(ObjP(0)^, K_TEXT, Pg);
 If SelObj >= 0 Then Inc(SelObj);
 If FindObj >= 0 Then Inc(FindObj);
 Idx := 0;
End;

Procedure PageNumbering;
Var
 Fmt, T: String;
 Pg, Start, Sz, PosC, I: Integer;
 RgbV: LongInt;
 W, PX, PY: LongInt;
Begin
 FldInit;
 FldText('Format (# = n°, % = total)', 'Page # / %', 40);
 FldChoice('Position', 'Bas centre|Bas droite|Bas gauche|Haut centre|Haut droite|Haut gauche', 0);
 FldNum('Taille (pt)', 10, 5, 40);
 FldNum('Premier numéro', 1, 0, 9999);
 FldColor('Couleur', 0);
 If Not FormDialog('Numérotation des pages') Then Begin RedrawAll; Exit; End;
 Fmt := U2W(Fields[0].Val);
 PosC := Fields[1].Cur; Sz := FInt(2); Start := FInt(3); RgbV := FInt(4);
 PushUndo;
 For Pg := 1 To PageCount Do Begin
  T := '';
  For I := 1 To Length(Fmt) Do
   If Fmt[I] = '#' Then T := T + IStr(Start + Pg - 1)
   Else If Fmt[I] = '%' Then T := T + IStr(PageCount + Start - 1)
   Else T := T + Fmt[I];
  If T = '' Then Continue;
  I := NewObj(K_TEXT, Pg);
  If I < 0 Then Break;
  W := TextLenPts(T, Sz, 0, 0);
  Case PosC Mod 3 Of
   0: PX := (PgP(Pg)^.W - W) Div 2;
   1: PX := PgP(Pg)^.W - W - 36;
  Else PX := 36;
  End;
  If PosC < 3 Then PY := PgP(Pg)^.H - 36 - Sz Else PY := 28;
  ObjP(I)^.X1 := PX;
  ObjP(I)^.Y1 := PY;
  ObjP(I)^.Size := Sz;
  ObjP(I)^.Style := 0;
  ObjP(I)^.Rgb := RgbV;
  ObjP(I)^.Txt := T;
  RecalcBox(I);
 End;
 RedrawAll;
End;

Procedure Watermark;
Var
 T: String;
 Pg, Sz, I, Idx: Integer;
 RgbV, W: LongInt;
Begin
 FldInit;
 FldText('Texte du filigrane', 'CONFIDENTIEL', 40);
 FldNum('Taille (pt)', 60, 10, 200);
 FldColor('Couleur', $B0B0B0);
 FldChoice('Style', 'Normal|Gras', 1);
 If Not FormDialog('Ajouter un filigrane') Then Begin RedrawAll; Exit; End;
 T := U2W(Fields[0].Val);
 If T = '' Then Begin RedrawAll; Exit; End;
 Sz := FInt(1); RgbV := FInt(2);
 PushUndo;
 For Pg := 1 To PageCount Do Begin
  InsertObjFirst(Pg, Idx);
  If Idx < 0 Then Break;
  ObjP(Idx)^.Kind := K_TEXT;
  ObjP(Idx)^.Size := Sz;
  ObjP(Idx)^.Style := Fields[3].Cur;
  ObjP(Idx)^.Rgb := RgbV;
  ObjP(Idx)^.Txt := T;
  W := TextLenPts(T, Sz, 0, Fields[3].Cur);
  ObjP(Idx)^.X1 := (PgP(Pg)^.W - W) Div 2;
  ObjP(Idx)^.Y1 := (PgP(Pg)^.H - Sz) Div 2;
  RecalcBox(Idx);
 End;
 RedrawAll;
End;

Procedure CropPage;
Var
 T, B, L, R, NW, NH: LongInt;
 I: Integer;
Begin
 FldInit;
 FldNum('Marge du haut (pt)', 0, 0, 2000);
 FldNum('Marge du bas (pt)', 0, 0, 2000);
 FldNum('Marge de gauche (pt)', 0, 0, 2000);
 FldNum('Marge de droite (pt)', 0, 0, 2000);
 If Not FormDialog('Recadrer la page') Then Begin RedrawAll; Exit; End;
 T := FInt(0); B := FInt(1); L := FInt(2); R := FInt(3);
 NW := PgP(CurPage)^.W - L - R;
 NH := PgP(CurPage)^.H - T - B;
 If (NW < 36) Or (NH < 36) Then Begin Notice('Les marges sont trop grandes.'); RedrawAll; Exit; End;
 PushUndo;
 For I := 0 To ObjCount - 1 Do
  If ObjP(I)^.Page = CurPage Then MoveObj(I, -L, -T);
 PgP(CurPage)^.W := NW;
 PgP(CurPage)^.H := NH;
 FullRefresh;
End;

Procedure PageSizeDlg;
Const
 SW_: Array[0..4] Of Integer = (612, 595, 612, 842, 420);
 SH_: Array[0..4] Of Integer = (792, 842, 1008, 1191, 595);
Var
 Kd, NW, NH, T, P, Lo, Hi: Integer;
Begin
 FldInit;
 FldChoice('Format', 'Lettre (612 x 792)|A4 (595 x 842)|Légal (612 x 1008)|A3 (842 x 1191)|A5 (420 x 595)|Personnalisé', 0);
 FldNum('Largeur perso (pt)', PgP(CurPage)^.W, 36, 5000);
 FldNum('Hauteur perso (pt)', PgP(CurPage)^.H, 36, 5000);
 FldChoice('Orientation', 'Portrait|Paysage', 0);
 FldChoice('Appliquer à', 'Cette page|Toutes les pages', 0);
 If Not FormDialog('Taille de la page') Then Begin RedrawAll; Exit; End;
 Kd := Fields[0].Cur;
 If Kd < 5 Then Begin NW := SW_[Kd]; NH := SH_[Kd]; End
 Else Begin NW := FInt(1); NH := FInt(2); End;
 If Fields[3].Cur = 1 Then Begin T := NW; NW := NH; NH := T; End;
 PushUndo;
 If Fields[4].Cur = 0 Then Begin Lo := CurPage; Hi := CurPage; End Else Begin Lo := 1; Hi := PageCount; End;
 For P := Lo To Hi Do Begin
  PgP(P)^.W := NW;
  PgP(P)^.H := NH;
 End;
 FullRefresh;
End;

Procedure ExtractPages;
Var
 Lo, Hi, I, P: Integer;
 Name: String;
 Snap: TUndoRec;
 Ok: Boolean;
Begin
 FldInit;
 FldNum('De la page', CurPage, 1, PageCount);
 FldNum('À la page', CurPage, 1, PageCount);
 If Not FormDialog('Extraire des pages') Then Begin RedrawAll; Exit; End;
 Lo := FInt(0); Hi := FInt(1);
 If Lo > Hi Then Begin P := Lo; Lo := Hi; Hi := P; End;
 Name := 'extrait.pdf';
 FileMaskAll := False;
 If Not FileDialog('Enregistrer les pages extraites', Name, True, '.pdf') Then Begin RedrawAll; Exit; End;
 MakeSnap(Snap);
 For P := PageCount DownTo 1 Do
  If (P < Lo) Or (P > Hi) Then DeletePageAt(P);
 Ok := SaveAsPDF(Name);
 ApplySnap(Snap);
 FreeUndoRec(Snap);
 RedrawAll;
 If Ok Then SetStatus('Pages ' + IStr(Lo) + ' à ' + IStr(Hi) + ' extraites vers ' + BaseName(Name))
 Else Notice('Impossible d''enregistrer le fichier.');
End;

Procedure InsertFromFile;
Var
 Name: String;
 Before, Added, Pos_, K, J: Integer;
 Err: String;
 Snap: TUndoRec;
Begin
 Name := '';
 FileMaskAll := False;
 If Not FileDialog('Insérer des pages depuis un fichier PDF', Name, False, '.pdf') Then Begin RedrawAll; Exit; End;
 FldInit;
 FldNum('Insérer après la page', CurPage, 0, PageCount);
 If Not FormDialog('Insérer des pages') Then Begin RedrawAll; Exit; End;
 Pos_ := FInt(0);
 PushUndo;
 Before := PageCount;
 ShowProgress('Importation...');
 If Not ImportPDF(Name, True, Err) Then Begin
  If PageCount <> Before Then ApplySnap(UndoStack[UndoTop - 1]);
  DropUndo;
  RedrawAll;
  Notice(Err);
  Exit;
 End;
 Added := PageCount - Before;
 For K := 1 To Added Do
  For J := Before + K DownTo Pos_ + K + 1 Do SwapPages(J, J - 1);
 CurPage := Pos_ + 1;
 FullRefresh;
 If LoadNotice <> '' Then Notice(LoadNotice);
End;

Procedure ApplyRedactions;
Var
 I, J, N, Cnt: Integer;
 RX1, RY1, RX2, RY2, TX1, TY1, TX2, TY2: LongInt;
 Pg: Integer;
Begin
 Cnt := 0;
 For I := 0 To ObjCount - 1 Do If ObjP(I)^.Kind = K_REDACT Then Inc(Cnt);
 If Cnt = 0 Then Begin Notice('Aucune biffure à appliquer.'); Exit; End;
 If MsgBox('Biffer', 'Appliquer ' + IStr(Cnt) + ' biffure(s) ? Le contenu situé dessous sera supprimé définitivement.', 1) = 0 Then Begin
  RedrawAll; Exit;
 End;
 PushUndo;
 For I := 0 To ObjCount - 1 Do
  If ObjP(I)^.Kind = K_REDACT Then Begin
   Pg := ObjP(I)^.Page;
   NormBox(ObjP(I)^, RX1, RY1, RX2, RY2);
   For J := 0 To ObjCount - 1 Do Begin
    If (J = I) Or (ObjP(J)^.Page <> Pg) Or (ObjP(J)^.Kind = K_REDACT) Then Continue;
    NormBox(ObjP(J)^, TX1, TY1, TX2, TY2);
    If (TX1 < RX2) And (TX2 > RX1) And (TY1 < RY2) And (TY2 > RY1) Then ObjP(J)^.Page := 0;
   End;
  End;
 J := 0;
 For I := 0 To ObjCount - 1 Do
  If ObjP(I)^.Page <> 0 Then Begin
   If I <> J Then ObjP(J)^ := ObjP(I)^;
   Inc(J);
  End;
 ObjCount := J;
 SelObj := -1; FindObj := -1;
 NeedFullRewrite := True;
 For I := 0 To ObjCount - 1 Do
  If ObjP(I)^.Kind = K_REDACT Then Begin
   ObjP(I)^.Kind := K_RECT;
   ObjP(I)^.Fill := 1;
   ObjP(I)^.Rgb := 0;
   ObjP(I)^.Rgb2 := 0;
  End;
 RedrawAll;
 SetStatus(IStr(Cnt) + ' biffure(s) appliquée(s).');
End;

Procedure ClearComments;
Var
 I, J: Integer;
Begin
 If CommentCount = 0 Then Begin Notice('Aucun commentaire à supprimer.'); Exit; End;
 If MsgBox('Supprimer les commentaires', 'Supprimer tous les commentaires (surlignages, notes, tampons) du document ?', 1) = 0 Then Begin
  RedrawAll; Exit;
 End;
 PushUndo;
 J := 0;
 For I := 0 To ObjCount - 1 Do
  If Not IsCommentKind(ObjP(I)^.Kind) Then Begin
   If I <> J Then ObjP(J)^ := ObjP(I)^;
   Inc(J);
  End;
 ObjCount := J;
 SelObj := -1; FindObj := -1;
 RedrawAll;
End;

Procedure ShowHelp;
Begin
 InfoBegin;
 InfoAdd('Fichier   Ctrl+N Nouveau  Ctrl+O Ouvrir  Ctrl+S Enregistrer');
 InfoAdd('          F2 Enregistrer sous  Ctrl+Q Quitter');
 InfoAdd('Édition   Ctrl+Z Annuler  Ctrl+Y Rétablir  Suppr Supprimer');
 InfoAdd('          Ctrl+C / Ctrl+X / Ctrl+V  Copier / Couper / Coller');
 InfoAdd('          Ctrl+J Dupliquer  Entrée Modifier le texte');
 InfoAdd('          Ctrl+P Propriétés  Ctrl+F Rechercher  F3 Suivant');
 InfoAdd('Affichage + / -  Zoom   1 = 100 %   2 Largeur   3 Page entière');
 InfoAdd('          PgPréc / PgSuiv  Page   Début / Fin  Première / dernière');
 InfoAdd('          Flèches  Défilement   Ctrl+G  Aller à la page');
 InfoAdd('          F4 Volet de navigation   F5 Pages / Commentaires');
 InfoAdd('          Ctrl+L Plein écran   Alt+lettre ou F10  Menus');
 InfoAdd('Outils    V Sélection  H Main  Z Loupe  T Texte  N Note');
 InfoAdd('          K Surligner  U Souligner  S Barrer  P Crayon');
 InfoAdd('          L Ligne  A Flèche  R Rectangle  O Ovale');
 InfoAdd('          M Tampon  G Signer  X Biffer');
 InfoAdd('Souris    Glisser pour tracer, surligner, déplacer ou');
 InfoAdd('          redimensionner ; double-clic pour modifier un objet.');
 InfoAdd('          Loupe : clic = zoom avant, clic droit = zoom arrière.');
 InfoDialog('Raccourcis clavier', 620);
End;

Procedure ShowAbout;
Begin
 InfoBegin;
 InfoAdd('ACROBAT - Clone d''Adobe Acrobat');
 InfoAdd('Version 1.00 - Free Pascal / Turbo Pascal');
 InfoAdd('');
 InfoAdd('Visionneuse et éditeur de documents PDF en mode graphique :');
 InfoAdd('lecture, annotations, organisation des pages, recherche,');
 InfoAdd('signature visuelle, biffure et exportation.');
 InfoAdd('');
 InfoAdd('Sylvain Maltais (support@gladir.com)');
 InfoAdd('https://www.gladir.com/clonedraw');
 InfoDialog('À propos d''Acrobat', 480);
End;

{ ---------------------------------------------------------------------- }
{ Commandes                                                                  }
{ ---------------------------------------------------------------------- }

Procedure ExecCmd(Cmd: Integer);
Var
 I, R: Integer;
 Name: String;
 Col: LongInt;
Begin
 If (Cmd >= CM_TOOL0) And (Cmd < CM_TOOL0 + TL_COUNT) Then Begin
  If Editing Then EndEdit(True);
  SetTool(Cmd - CM_TOOL0);
  Exit;
 End;
 If Editing Then EndEdit(True);
 Case Cmd Of
  CM_NEW: Begin
   If ConfirmDiscard Then Begin
    NewDocument; Imported := False; FitMode := 1;
    FullRefresh;
   End
   Else RedrawAll;
  End;
  CM_OPEN: Begin
   If ConfirmDiscard Then Begin
    Name := '';
    FileMaskAll := False;
    If FileDialog('Ouvrir', Name, False, '.pdf') Then OpenFileByName(Name) Else RedrawAll;
   End
   Else RedrawAll;
  End;
  CM_SAVE: R := Ord(DoSave);
  CM_SAVEAS: R := Ord(DoSaveAs);
  CM_EXPTXT: Begin
   Name := ChangeExt_(DocName, '.txt');
   FileMaskAll := True;
   If FileDialog('Exporter en texte', Name, True, '.txt') Then Begin ExportText(Name); RedrawAll; SetStatus('Texte exporté : ' + BaseName(Name)); End
   Else RedrawAll;
   FileMaskAll := False;
  End;
  CM_EXPBMP: Begin
   Name := ChangeExt_(DocName, '.bmp');
   FileMaskAll := True;
   If FileDialog('Exporter la page en BMP', Name, True, '.bmp') Then Begin ExportBMP(Name); SetStatus('Image exportée : ' + BaseName(Name)); End
   Else RedrawAll;
   FileMaskAll := False;
  End;
  CM_INSFILE: InsertFromFile;
  CM_EXTRACT: ExtractPages;
  CM_PROPS: DocProperties;
  CM_QUIT: Begin
   If ConfirmDiscard Then Running := False Else RedrawAll;
  End;
  CM_UNDO: Begin DoUndo; FullRefresh; End;
  CM_REDO: Begin DoRedo; FullRefresh; End;
  CM_DELETE: If SelObj >= 0 Then Begin PushUndo; DelObj(SelObj); RedrawAll; End;
  CM_DUP: If SelObj >= 0 Then Begin DoCopy; DoPaste(10, 10); RedrawAll; End;
  CM_COPY: DoCopy;
  CM_CUT: If SelObj >= 0 Then Begin DoCopy; PushUndo; DelObj(SelObj); RedrawAll; End;
  CM_PASTE: Begin DoPaste(12, 12); RedrawAll; End;
  CM_DESEL: Begin SelObj := -1; FindObj := -1; RedrawView; End;
  CM_EDITTXT: EditSelected;
  CM_OBJPROPS: ObjProperties;
  CM_FIND: Begin
   FldInit;
   FldText('Rechercher', FindText, 60);
   FldCheck('Respecter la casse', FindCase);
   If FormDialog('Rechercher') Then Begin
    FindText := Fields[0].Val;
    FindCase := Fields[1].Cur = 1;
    FindObj := -1;
    FindNext;
   End
   Else RedrawAll;
  End;
  CM_FINDNEXT: FindNext;
  CM_COLOR: Begin
   If SelObj >= 0 Then Col := ObjP(SelObj)^.Rgb Else Col := ToolRgb[CurTool];
   Col := PickColor('Couleur', Col);
   If Col >= 0 Then Begin
    If SelObj >= 0 Then Begin
     PushUndo;
     ObjP(SelObj)^.Rgb := Col;
     If (ObjP(SelObj)^.Kind In [K_RECT, K_OVAL, K_POLY]) And (ObjP(SelObj)^.Fill = 1) Then ObjP(SelObj)^.Rgb2 := Col;
    End
    Else ToolRgb[CurTool] := Col;
   End;
   RedrawAll;
  End;
  CM_WIDTH: Begin
   FldInit;
   FldNum('Épaisseur du trait (pt)', CurWidth, 1, 20);
   FldNum('Taille du texte (pt)', CurSize, 4, 200);
   FldChoice('Police du texte', 'Helvetica|Times|Courier', CurFam);
   FldCheck('Gras', (CurStyle And 1) <> 0);
   FldCheck('Italique', (CurStyle And 2) <> 0);
   FldNum('Angle du texte (degrés)', CurAngle, 0, 359);
   If FormDialog('Attributs des outils') Then Begin
    CurWidth := FInt(0); CurSize := FInt(1); CurFam := FInt(2);
    CurStyle := FInt(3) + FInt(4) * 2;
    CurAngle := FInt(5);
   End;
   RedrawAll;
  End;
  CM_ZOOMIN: StepZoom(1);
  CM_ZOOMOUT: StepZoom(-1);
  CM_Z100: ZoomTo(100, ViewW Div 2, ViewH Div 2);
  CM_FITW: Begin FitMode := 1; ScrollX := 0; GotoPage(CurPage); RedrawAll; End;
  CM_FITP: Begin FitMode := 2; ScrollX := 0; GotoPage(CurPage); RedrawAll; End;
  CM_ZOOMSET: Begin
   FldInit;
   FldNum('Niveau de zoom (%)', Zoom, 10, 1600);
   If FormDialog('Zoom') Then ZoomTo(FInt(0), ViewW Div 2, ViewH Div 2) Else RedrawAll;
  End;
  CM_CONT: Begin Continuous := 1 - Continuous; ScrollX := 0; GotoPage(CurPage); RedrawAll; End;
  CM_NAV: Begin NavVisible := 1 - NavVisible; FullScreen := False; RedrawAll; End;
  CM_NAVMODE: Begin NavTab := 1 - NavTab; NavScroll := 0; NavVisible := 1; FullScreen := False; RedrawAll; End;
  CM_FULL: Begin FullScreen := Not FullScreen; RedrawAll; End;
  CM_PREV: Begin GotoPage(CurPage - 1); RedrawAll; End;
  CM_NEXT: Begin GotoPage(CurPage + 1); RedrawAll; End;
  CM_FIRST: Begin GotoPage(1); RedrawAll; End;
  CM_LAST: Begin GotoPage(PageCount); RedrawAll; End;
  CM_GOTO: Begin
   FldInit;
   FldNum('Aller à la page (1-' + IStr(PageCount) + ')', CurPage, 1, PageCount);
   If FormDialog('Aller à la page') Then GotoPage(FInt(0));
   RedrawAll;
  End;
  CM_PGINS: Begin
   PushUndo;
   InsertPageAt(CurPage, PgP(CurPage)^.W, PgP(CurPage)^.H);
   GotoPage(CurPage + 1);
   FullRefresh;
  End;
  CM_PGDUP: Begin
   PushUndo;
   DupPageAt(CurPage);
   GotoPage(CurPage + 1);
   FullRefresh;
  End;
  CM_PGDEL: Begin
   If PageCount > 1 Then
    If MsgBox('Supprimer la page', 'Supprimer la page ' + IStr(CurPage) + ' ?', 1) <> 0 Then Begin
     PushUndo;
     DeletePageAt(CurPage);
     GotoPage(CurPage);
    End;
   FullRefresh;
  End;
  CM_ROTR: Begin PushUndo; PgP(CurPage)^.Rot := (PgP(CurPage)^.Rot + 1) And 3; FullRefresh; End;
  CM_ROTL: Begin PushUndo; PgP(CurPage)^.Rot := (PgP(CurPage)^.Rot + 3) And 3; FullRefresh; End;
  CM_PGUP: If CurPage > 1 Then Begin PushUndo; SwapPages(CurPage, CurPage - 1); GotoPage(CurPage - 1); FullRefresh; End;
  CM_PGDOWN: If CurPage < PageCount Then Begin PushUndo; SwapPages(CurPage, CurPage + 1); GotoPage(CurPage + 1); FullRefresh; End;
  CM_CROP: CropPage;
  CM_PGSIZE: PageSizeDlg;
  CM_NUMBER: PageNumbering;
  CM_WATER: Watermark;
  CM_APPLYRED: ApplyRedactions;
  CM_CLEARALL: ClearComments;
  CM_HELP: Begin ShowHelp; RedrawAll; End;
  CM_ABOUT: Begin ShowAbout; RedrawAll; End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Aperçus XOR                                                                }
{ ---------------------------------------------------------------------- }

Var
 PrevKind: Integer;

Procedure XorPreview(Kind: Integer; X1, Y1, X2, Y2: LongInt);
Var
 CX, CY, RX, RY: LongInt;
Begin
 SetViewPort(ViewL, ViewT, ViewR, ViewB, True);
 SetWriteMode(XORPut);
 SetColor(White);
 X1 := X1 - ViewL; X2 := X2 - ViewL; Y1 := Y1 - ViewT; Y2 := Y2 - ViewT;
 Case Kind Of
  0: Rectangle(C16(X1), C16(Y1), C16(X2), C16(Y2));
  1: Line(C16(X1), C16(Y1), C16(X2), C16(Y2));
  2: Begin
   CX := (X1 + X2) Div 2; CY := (Y1 + Y2) Div 2;
   RX := IAbs(X2 - X1) Div 2; RY := IAbs(Y2 - Y1) Div 2;
   If (RX > 0) And (RY > 0) Then Ellipse(C16(CX), C16(CY), 0, 360, C16(RX), C16(RY));
  End;
 End;
 SetWriteMode(NormalPut);
 SetFullView;
End;

Procedure ErasePreview;
Begin
 If PreviewOn Then Begin
  HideMouse;
  XorPreview(PrevKind, PrevX1, PrevY1, PrevX2, PrevY2);
  ShowMouse;
  PreviewOn := False;
 End;
End;

Procedure ShowPreview(Kind: Integer; X1, Y1, X2, Y2: LongInt);
Begin
 If PreviewOn And (PrevKind = Kind) And (PrevX1 = X1) And (PrevY1 = Y1) And (PrevX2 = X2) And (PrevY2 = Y2) Then Exit;
 HideMouse;
 If PreviewOn Then XorPreview(PrevKind, PrevX1, PrevY1, PrevX2, PrevY2);
 XorPreview(Kind, X1, Y1, X2, Y2);
 ShowMouse;
 PreviewOn := True;
 PrevKind := Kind; PrevX1 := X1; PrevY1 := Y1; PrevX2 := X2; PrevY2 := Y2;
End;

Procedure RefreshSel;
Begin
 HideMouse;
 DrawView;
 DrawScrollBars;
 DrawNav;
 DrawStatus;
 ShowMouse;
End;

Procedure SyncNav;
Var
 T, H: LongInt;
Begin
 If (NavVisible = 0) Or (NavTab <> 0) Then Exit;
 If LastNavPage = CurPage Then Exit;
 LastNavPage := CurPage;
 H := ViewB - ViewT - 15;
 T := ThumbTop(CurPage);
 If T < NavScroll Then NavScroll := T - 4;
 If T + ThumbCellH(CurPage) > NavScroll + H Then NavScroll := T + ThumbCellH(CurPage) - H;
 If NavScroll < 0 Then NavScroll := 0;
End;

{ ---------------------------------------------------------------------- }
{ Souris                                                                     }
{ ---------------------------------------------------------------------- }

Procedure SetPageCtx(Pg: Integer);
Var
 OX, OY: LongInt;
Begin
 PageOrigin(Pg, OX, OY);
 SetCtx(Pg, OX + ViewL, OY + ViewT, Scale);
End;

Procedure ClampToPage(Pg: Integer; Var X, Y: LongInt);
Begin
 If X < 0 Then X := 0;
 If Y < 0 Then Y := 0;
 If X > PgP(Pg)^.W Then X := PgP(Pg)^.W;
 If Y > PgP(Pg)^.H Then Y := PgP(Pg)^.H;
End;

Procedure HandleViewDown(Dbl: Boolean);
Var
 Pg: Integer;
 PX, PY: LongInt;
 I, H: Integer;
 Tol: Real;
 S: String;
Begin
 Case CurTool Of
  TL_HAND: Begin
   DragMode := 4; DragX0 := MX_; DragY0 := MY_; DragOX := ScrollX; DragOY := ScrollY;
   Exit;
  End;
  TL_ZOOM: Begin
   DragMode := 8; DragX0 := MX_; DragY0 := MY_; PreviewOn := False;
   Exit;
  End;
 End;
 If Not PageAt(MX_, MY_, Pg, PX, PY, True) Then Begin
  If (CurTool = TL_SELECT) And (SelObj >= 0) Then Begin SelObj := -1; RefreshSel; End;
  Exit;
 End;
 Tol := 5 * 1024.0 / Scale;
 Case CurTool Of
  TL_SELECT: Begin
   If (SelObj >= 0) And (SelObj < ObjCount) Then
    If ObjP(SelObj)^.Page = Pg Then Begin
     H := HandleAt(SelObj, MX_, MY_);
     If H <> 0 Then Begin
      DragMode := 3; DragHandle := H; DragObj := SelObj; DragPg := Pg; PreviewOn := False;
      Exit;
     End;
    End;
   I := HitObj(Pg, PX, PY, Tol);
   If I >= 0 Then Begin
    SelObj := I;
    If Continuous <> 0 Then CurPage := Pg;
    If Dbl Then Begin RefreshSel; EditSelected; End
    Else Begin
     DragMode := 2; DragObj := I; DragPg := Pg; DragX0 := PX; DragY0 := PY; PreviewOn := False;
     RefreshSel;
    End;
   End
   Else Begin
    SelObj := -1;
    CurPage := Pg;
    RefreshSel;
   End;
  End;
  TL_TEXT: Begin
   I := HitObj(Pg, PX, PY, Tol);
   If (I >= 0) And (ObjP(I)^.Kind = K_TEXT) Then StartEdit(I, False)
   Else Begin
    I := CreateText(Pg, PX, PY);
    If I >= 0 Then StartEdit(I, True);
   End;
  End;
  TL_NOTE: Begin
   PushUndo;
   I := NewObj(K_NOTE, Pg);
   If I < 0 Then Begin DropUndo; Exit; End;
   ObjP(I)^.X1 := PX; ObjP(I)^.Y1 := PY; ObjP(I)^.Rgb := ToolRgb[TL_NOTE];
   RecalcBox(I);
   S := '';
   If InputBox('Note adhésive', 'Texte de la note', S, 118) And (S <> '') Then Begin
    ObjP(I)^.Txt := U2W(S);
    SelObj := I;
   End
   Else Begin DelObj(I); DropUndo; End;
   RedrawAll;
  End;
  TL_HILITE, TL_UNDER, TL_STRIKE, TL_LINE, TL_ARROW, TL_RECT, TL_OVAL, TL_REDACT: Begin
   DragMode := 1; DragPg := Pg; DragX0 := PX; DragY0 := PY; PreviewOn := False;
  End;
  TL_PENCIL: Begin
   DragMode := 5; DragPg := Pg; InkN := 1; InkX[0] := PX; InkY[0] := PY;
  End;
  TL_STAMP: ChoiceStamp(Pg, PX, PY);
  TL_SIGN: PlaceSignature(Pg, PX, PY);
 End;
End;

Procedure FinishShape(Pg: Integer; PX, PY: LongInt);
Var
 I: Integer;
 DX, DY: LongInt;
Begin
 DX := IAbs(PX - DragX0); DY := IAbs(PY - DragY0);
 Case CurTool Of
  TL_HILITE: MarkText(K_HILITE, Pg, DragX0, DragY0, PX, PY, TL_HILITE);
  TL_UNDER: MarkText(K_UNDER, Pg, DragX0, DragY0, PX, PY, TL_UNDER);
  TL_STRIKE: MarkText(K_STRIKE, Pg, DragX0, DragY0, PX, PY, TL_STRIKE);
  TL_LINE, TL_ARROW: If DX + DY >= 4 Then Begin
   PushUndo;
   If CurTool = TL_LINE Then I := NewShape(K_LINE, Pg, DragX0, DragY0, PX, PY, CurTool)
   Else I := NewShape(K_ARROW, Pg, DragX0, DragY0, PX, PY, CurTool);
   If I < 0 Then DropUndo Else SelObj := I;
  End;
  TL_RECT, TL_OVAL, TL_REDACT: If (DX >= 3) And (DY >= 3) Then Begin
   PushUndo;
   If CurTool = TL_RECT Then I := NewShape(K_RECT, Pg, DragX0, DragY0, PX, PY, CurTool)
   Else If CurTool = TL_OVAL Then I := NewShape(K_OVAL, Pg, DragX0, DragY0, PX, PY, CurTool)
   Else I := NewShape(K_REDACT, Pg, DragX0, DragY0, PX, PY, CurTool);
   If I < 0 Then DropUndo
   Else Begin
    SelObj := I;
    If CurTool = TL_REDACT Then ObjP(I)^.Rgb := $FF4040;
   End;
  End;
 End;
End;

Procedure HandleDrag(Up: Boolean);
Var
 PX, PY, DX, DY, X1, Y1, X2, Y2, CX, CY: LongInt;
 O: TObjRec;
 SX1, SY1, SX2, SY2, NX1, NY1, NX2, NY2: LongInt;
 Kind, I: Integer;
 NZ: Integer;
 RW, RH: Real;
Begin
 Case DragMode Of
  1: Begin
   SetPageCtx(DragPg);
   Unmap(MX_, MY_, PX, PY);
   ClampToPage(DragPg, PX, PY);
   If CurTool In [TL_LINE, TL_ARROW] Then Kind := 1
   Else If CurTool = TL_OVAL Then Kind := 2 Else Kind := 0;
   X1 := MXp(DragX0, DragY0); Y1 := MYp(DragX0, DragY0);
   X2 := MXp(PX, PY); Y2 := MYp(PX, PY);
   If Not Up Then ShowPreview(Kind, X1, Y1, X2, Y2)
   Else Begin
    ErasePreview;
    DragMode := 0;
    FinishShape(DragPg, PX, PY);
    RedrawAll;
   End;
  End;
  2: Begin
   SetPageCtx(DragPg);
   Unmap(MX_, MY_, PX, PY);
   DX := PX - DragX0; DY := PY - DragY0;
   O := ObjP(DragObj)^;
   O.X1 := O.X1 + DX; O.X2 := O.X2 + DX; O.Y1 := O.Y1 + DY; O.Y2 := O.Y2 + DY;
   If Not Up Then Begin
    If (DX <> 0) Or (DY <> 0) Or PreviewOn Then Begin
     If O.Kind In [K_LINE, K_ARROW] Then
      ShowPreview(1, MXp(O.X1, O.Y1), MYp(O.X1, O.Y1), MXp(O.X2, O.Y2), MYp(O.X2, O.Y2))
     Else Begin
      ScrBox(O, SX1, SY1, SX2, SY2);
      ShowPreview(0, SX1 - 2, SY1 - 2, SX2 + 2, SY2 + 2);
     End;
    End;
   End
   Else Begin
    ErasePreview;
    DragMode := 0;
    If (DX <> 0) Or (DY <> 0) Then Begin
     PushUndo;
     MoveObj(DragObj, DX, DY);
    End;
    RedrawAll;
   End;
  End;
  3: Begin
   SetPageCtx(DragPg);
   Unmap(MX_, MY_, PX, PY);
   ClampToPage(DragPg, PX, PY);
   O := ObjP(DragObj)^;
   If DragHandle >= 5 Then Begin
    If DragHandle = 5 Then Begin O.X1 := PX; O.Y1 := PY; End Else Begin O.X2 := PX; O.Y2 := PY; End;
    NX1 := O.X1; NY1 := O.Y1; NX2 := O.X2; NY2 := O.Y2;
    If Not Up Then ShowPreview(1, MXp(O.X1, O.Y1), MYp(O.X1, O.Y1), MXp(O.X2, O.Y2), MYp(O.X2, O.Y2));
   End
   Else Begin
    NormBox(O, NX1, NY1, NX2, NY2);
    Case DragHandle Of
     1: Begin NX1 := PX; NY1 := PY; End;
     2: Begin NX2 := PX; NY1 := PY; End;
     3: Begin NX1 := PX; NY2 := PY; End;
    Else Begin NX2 := PX; NY2 := PY; End;
    End;
    If NX1 > NX2 Then Begin X1 := NX1; NX1 := NX2; NX2 := X1; End;
    If NY1 > NY2 Then Begin Y1 := NY1; NY1 := NY2; NY2 := Y1; End;
    O.X1 := NX1; O.Y1 := NY1; O.X2 := NX2; O.Y2 := NY2;
    If Not Up Then Begin
     ScrBox(O, SX1, SY1, SX2, SY2);
     ShowPreview(0, SX1, SY1, SX2, SY2);
    End;
   End;
   If Up Then Begin
    ErasePreview;
    DragMode := 0;
    PushUndo;
    If DragHandle >= 5 Then Begin
     ObjP(DragObj)^.X1 := O.X1; ObjP(DragObj)^.Y1 := O.Y1; ObjP(DragObj)^.X2 := O.X2; ObjP(DragObj)^.Y2 := O.Y2;
    End
    Else ScaleObjTo(DragObj, NX1, NY1, NX2, NY2);
    RedrawAll;
   End;
  End;
  4: Begin
   ScrollX := DragOX - (MX_ - DragX0);
   ScrollY := DragOY - (MY_ - DragY0);
   ClampScroll;
   If Continuous <> 0 Then UpdateCurPage;
   If Up Then Begin DragMode := 0; RedrawAll; End
   Else If (MX_ <> OMX) Or (MY_ <> OMY) Then Begin
    HideMouse; DrawView; DrawScrollBars; ShowMouse;
   End;
  End;
  5: Begin
   SetPageCtx(DragPg);
   Unmap(MX_, MY_, PX, PY);
   ClampToPage(DragPg, PX, PY);
   If (PX <> InkX[InkN - 1]) Or (PY <> InkY[InkN - 1]) Then Begin
    If InkN < 400 Then Begin
     InkX[InkN] := PX; InkY[InkN] := PY;
     HideMouse;
     SetViewPort(ViewL, ViewT, ViewR, ViewB, True);
     ThickLine(MXp(InkX[InkN - 1], InkY[InkN - 1]) - ViewL, MYp(InkX[InkN - 1], InkY[InkN - 1]) - ViewT,
               MXp(PX, PY) - ViewL, MYp(PX, PY) - ViewT, IMax(1, PU(CurWidth)), Nearest16(ToolRgb[TL_PENCIL]));
     SetFullView;
     ShowMouse;
     Inc(InkN);
    End;
   End;
   If Up Then Begin
    DragMode := 0;
    FinishInk(DragPg);
    RedrawAll;
   End;
  End;
  6: Begin
   ScrollY := SBDragPos(ViewR + 1, ViewT, GetMaxX, ViewB, True, DocH, ViewH, MX_, MY_, SBDragOfs);
   If Continuous <> 0 Then UpdateCurPage;
   If Up Then Begin DragMode := 0; RedrawAll; End
   Else If MY_ <> OMY Then Begin HideMouse; DrawView; DrawScrollBars; ShowMouse; End;
  End;
  7: Begin
   ScrollX := SBDragPos(ViewL, ViewB + 1, ViewR, GetMaxY - STATUS_H, False, DocW, ViewW, MX_, MY_, SBDragOfs);
   If Up Then Begin DragMode := 0; RedrawAll; End
   Else If MX_ <> OMX Then Begin HideMouse; DrawView; DrawScrollBars; ShowMouse; End;
  End;
  8: Begin
   If Not Up Then ShowPreview(0, DragX0, DragY0, MX_, MY_)
   Else Begin
    ErasePreview;
    DragMode := 0;
    DX := IAbs(MX_ - DragX0); DY := IAbs(MY_ - DragY0);
    If (DX < 6) And (DY < 6) Then Begin
     If (MB_ And 2) <> 0 Then StepZoom(-1)
     Else ZoomTo(Zoom * 3 Div 2 + 1, MX_ - ViewL, MY_ - ViewT);
    End
    Else Begin
     RW := ViewW / IMax(1, DX);
     RH := ViewH / IMax(1, DY);
     If RW > RH Then RW := RH;
     NZ := Trunc(Zoom * RW);
     If NZ > 1600 Then NZ := 1600;
     ZoomTo(NZ, (DragX0 + MX_) Div 2 - ViewL, (DragY0 + MY_) Div 2 - ViewT);
    End;
   End;
  End;
  9: Begin
   If NavTab = 0 Then
    NavScroll := SBDragPos(NAV_W - SBAR, ViewT + 16, NAV_W - 1, ViewB, True, NavDocHeight, ViewB - ViewT - 15, MX_, MY_, SBDragOfs)
   Else
    NavScroll := SBDragPos(NAV_W - SBAR, ViewT + 16, NAV_W - 1, ViewB, True, IMax(CommentCount, 1), (ViewB - ViewT - 15) Div 24, MX_, MY_, SBDragOfs);
   If Up Then DragMode := 0;
   HideMouse; DrawNav; ShowMouse;
  End;
 Else
  DragMode := 0;
 End;
End;

Procedure NavClick(Dbl: Boolean);
Var
 I, Hit, Rows, Idx: Integer;
 Y: LongInt;
 T: LongInt;
 Y0, Y1: Integer;
 Ofs: LongInt;
 Total, PageSz: LongInt;
Begin
 Ofs := 0;
 Y0 := ViewT + 16; Y1 := ViewB;
 If MY_ < ViewT + 15 Then Begin
  If MX_ < 54 Then NavTab := 0 Else NavTab := 1;
  NavScroll := 0;
  LastNavPage := -1;
  SyncNav;
  HideMouse; DrawNav; ShowMouse;
  Exit;
 End;
 If NavTab = 0 Then Begin Total := NavDocHeight; PageSz := Y1 - Y0 + 1; End
 Else Begin Total := IMax(CommentCount, 1); PageSz := (Y1 - Y0 + 1) Div 24; End;
 If MX_ >= NAV_W - SBAR Then Begin
  Hit := SBHit(NAV_W - SBAR, Y0, NAV_W - 1, Y1, True, NavScroll, Total, PageSz, MX_, MY_, Ofs);
  Case Hit Of
   1: If NavTab = 0 Then Dec(NavScroll, 30) Else Dec(NavScroll);
   2: If NavTab = 0 Then Inc(NavScroll, 30) Else Inc(NavScroll);
   3: Dec(NavScroll, PageSz);
   4: Inc(NavScroll, PageSz);
   5: Begin DragMode := 9; SBDragOfs := Ofs; End;
  End;
  If NavScroll > Total - PageSz Then NavScroll := Total - PageSz;
  If NavScroll < 0 Then NavScroll := 0;
  HideMouse; DrawNav; ShowMouse;
  Exit;
 End;
 If NavTab = 0 Then Begin
  Y := MY_ - Y0 + NavScroll;
  For I := 1 To PageCount Do Begin
   T := ThumbTop(I);
   If (Y >= T - 4) And (Y < T + ThumbCellH(I) - 4) Then Begin
    GotoPage(I);
    RedrawAll;
    Exit;
   End;
  End;
 End
 Else Begin
  Rows := (MY_ - Y0) Div 24;
  CommentRow(NavScroll + Rows, Idx);
  If Idx >= 0 Then Begin
   SelObj := Idx;
   ScrollToObj(Idx);
   RedrawAll;
   If Dbl Then EditSelected;
  End;
 End;
End;

Procedure MenuRun(M, Item: Integer);
Var
 Cmd: Integer;
Begin
 If (Item < 0) Or (Item >= Menus[M].ItemCount) Then Exit;
 If Menus[M].Items[Item].Separator Then Exit;
 Cmd := Menus[M].Items[Item].Cmd;
 If Not CmdEnabled(Cmd) Then Exit;
 CloseMenu;
 ExecCmd(Cmd);
End;

Procedure HandleMouse;
Var
 Down, Dbl, RDown: Boolean;
 Bar_, Item, TB, Hit: Integer;
 Ofs: LongInt;
 NewHint: String;
Begin
 Ofs := 0;
 PollMouse;
 Down := MouseClicked;
 RDown := ((MB_ And 2) <> 0) And ((OMB And 2) = 0);
 Dbl := False;
 If Down Then Begin
  Dbl := (NowMs - LastClickT < 450) And (IAbs(MX_ - LastClickX) < 5) And (IAbs(MY_ - LastClickY) < 5);
  LastClickT := NowMs; LastClickX := MX_; LastClickY := MY_;
  If Dbl Then LastClickT := 0;
 End;
 If MenuActive Then Begin
  If (MX_ <> OMX) Or (MY_ <> OMY) Then Begin
   Bar_ := MenuBarHit(MX_, MY_);
   If (Bar_ >= 0) And (Bar_ <> ActiveMenu) Then OpenMenu(Bar_)
   Else Begin
    Item := MenuItemHit(MX_, MY_, ActiveMenu);
    If Item <> ActiveItem Then Begin
     ActiveItem := Item;
     HideMouse; DrawDropdown(ActiveMenu); ShowMouse;
    End;
   End;
  End;
  If Down Then Begin
   Bar_ := MenuBarHit(MX_, MY_);
   If Bar_ = ActiveMenu Then CloseMenu
   Else If Bar_ >= 0 Then OpenMenu(Bar_)
   Else Begin
    Item := MenuItemHit(MX_, MY_, ActiveMenu);
    If Item >= 0 Then MenuRun(ActiveMenu, Item) Else CloseMenu;
   End;
  End;
  Exit;
 End;
 If DragMode <> 0 Then Begin
  HandleDrag((MB_ And 1) = 0);
  Exit;
 End;
 If Down Then Begin
  If Editing Then EndEdit(True);
  If MY_ < MENU_H Then Begin
   Bar_ := MenuBarHit(MX_, MY_);
   If Bar_ >= 0 Then OpenMenu(Bar_);
  End
  Else If (ToolbarVisible <> 0) And Not FullScreen And (MY_ < MENU_H + TOOL_H) Then Begin
   TB := ToolbarHit(MX_, MY_);
   If TB >= 0 Then ExecCmd(TBar[TB].Cmd);
  End
  Else If (NavVisible <> 0) And Not FullScreen And (MX_ < NAV_W) And (MY_ >= ViewT) And (MY_ <= ViewB) Then
   NavClick(Dbl)
  Else If (MX_ > ViewR) And (MY_ >= ViewT) And (MY_ <= ViewB) Then Begin
   Hit := SBHit(ViewR + 1, ViewT, GetMaxX, ViewB, True, ScrollY, DocH, ViewH, MX_, MY_, Ofs);
   Case Hit Of
    1: ScrollY := ScrollY - 40;
    2: ScrollY := ScrollY + 40;
    3: ScrollY := ScrollY - ViewH + 20;
    4: ScrollY := ScrollY + ViewH - 20;
    5: Begin DragMode := 6; SBDragOfs := Ofs; End;
   End;
   If Hit <> 0 Then Begin
    ClampScroll;
    If Continuous <> 0 Then UpdateCurPage;
    RedrawAll;
   End;
  End
  Else If (MY_ > ViewB) And (MY_ <= GetMaxY - STATUS_H) And (MX_ >= ViewL) And (MX_ <= ViewR) Then Begin
   Hit := SBHit(ViewL, ViewB + 1, ViewR, GetMaxY - STATUS_H, False, ScrollX, DocW, ViewW, MX_, MY_, Ofs);
   Case Hit Of
    1: ScrollX := ScrollX - 40;
    2: ScrollX := ScrollX + 40;
    3: ScrollX := ScrollX - ViewW + 20;
    4: ScrollX := ScrollX + ViewW - 20;
    5: Begin DragMode := 7; SBDragOfs := Ofs; End;
   End;
   If Hit <> 0 Then Begin ClampScroll; RedrawAll; End;
  End
  Else If (MX_ >= ViewL) And (MX_ <= ViewR) And (MY_ >= ViewT) And (MY_ <= ViewB) Then
   HandleViewDown(Dbl);
 End
 Else If RDown And (CurTool = TL_ZOOM) And (MX_ >= ViewL) And (MX_ <= ViewR) And (MY_ >= ViewT) And (MY_ <= ViewB) Then
  StepZoom(-1);
 If (MX_ <> OMX) Or (MY_ <> OMY) Then Begin
  NewHint := '';
  TB := ToolbarHit(MX_, MY_);
  If TB >= 0 Then NewHint := TBar[TB].Hint;
  If NewHint <> HintText Then Begin
   HintText := NewHint;
   HideMouse; DrawStatus; ShowMouse;
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Clavier                                                                    }
{ ---------------------------------------------------------------------- }

Procedure MenuNextItem(Step: Integer);
Var
 N, I: Integer;
Begin
 N := Menus[ActiveMenu].ItemCount;
 If N <= 0 Then Exit;
 If ActiveItem < 0 Then Begin
  If Step > 0 Then ActiveItem := -1 Else ActiveItem := N;
 End;
 For I := 1 To N Do Begin
  ActiveItem := ActiveItem + Step;
  If ActiveItem < 0 Then ActiveItem := N - 1;
  If ActiveItem >= N Then ActiveItem := 0;
  If Not Menus[ActiveMenu].Items[ActiveItem].Separator Then Break;
 End;
 HideMouse; DrawDropdown(ActiveMenu); ShowMouse;
End;

Procedure ScrollBy(DX, DY: LongInt);
Begin
 ScrollX := ScrollX + DX;
 ScrollY := ScrollY + DY;
 ClampScroll;
 If Continuous <> 0 Then UpdateCurPage;
 RedrawView;
 If Continuous <> 0 Then Begin
  HideMouse;
  SyncNav;
  DrawNav;
  ShowMouse;
 End;
End;

Procedure HandleKeys;
Var
 K: Integer;
 Ext: Boolean;
 C: Char;
Begin
 K := GetKeyEx(Ext);
 If K < 0 Then Exit;
 If Editing Then Begin EditKey(K, Ext); Exit; End;
 If MenuActive Then Begin
  If Ext Then Begin
   Case K Of
    72: MenuNextItem(-1);
    80: MenuNextItem(1);
    75: OpenMenu((ActiveMenu + MN_COUNT - 1) Mod MN_COUNT);
    77: OpenMenu((ActiveMenu + 1) Mod MN_COUNT);
   End;
  End
  Else Begin
   If K = 13 Then MenuRun(ActiveMenu, ActiveItem)
   Else If K = 27 Then CloseMenu;
  End;
  Exit;
 End;
 If Ext Then Begin
  Case K Of
   59: ExecCmd(CM_HELP);
   61: ExecCmd(CM_FINDNEXT);
   62: ExecCmd(CM_NAV);
   63: ExecCmd(CM_NAVMODE);
   68: OpenMenu(MN_FILE);
   60, 134: ExecCmd(CM_SAVEAS);
   33: OpenMenu(MN_FILE);
   18: OpenMenu(MN_EDIT);
   47: OpenMenu(MN_VIEW);
   25: OpenMenu(MN_PAGE);
   24: OpenMenu(MN_TOOLS);
   35: OpenMenu(MN_HELP);
   107: ExecCmd(CM_QUIT);
   72: ScrollBy(0, -40);
   80: ScrollBy(0, 40);
   75: ScrollBy(-40, 0);
   77: ScrollBy(40, 0);
   73: ExecCmd(CM_PREV);
   81: ExecCmd(CM_NEXT);
   71: ExecCmd(CM_FIRST);
   79: ExecCmd(CM_LAST);
   83: ExecCmd(CM_DELETE);
  End;
  Exit;
 End;
 Case K Of
  14: ExecCmd(CM_NEW);
  15: ExecCmd(CM_OPEN);
  19: ExecCmd(CM_SAVE);
  26: ExecCmd(CM_UNDO);
  25: ExecCmd(CM_REDO);
  6: ExecCmd(CM_FIND);
  7: ExecCmd(CM_GOTO);
  4: ExecCmd(CM_PROPS);
  3: Begin
   { Ctrl+C : copier ; sans sélection, c'est aussi ce que PtcCrt envoie
     quand on ferme la fenêtre : demander la fermeture. }
   If SelObj >= 0 Then ExecCmd(CM_COPY)
   Else If MsgBox('Quitter', 'Voulez-vous quitter Acrobat ?', 1) <> 0 Then ExecCmd(CM_QUIT)
   Else RedrawAll;
  End;
  22: ExecCmd(CM_PASTE);
  24: ExecCmd(CM_CUT);
  17: ExecCmd(CM_QUIT);
  16: ExecCmd(CM_OBJPROPS);
  12: ExecCmd(CM_FULL);
  10: ExecCmd(CM_DUP);
  27: Begin
   If MenuActive Then CloseMenu
   Else If SelObj >= 0 Then ExecCmd(CM_DESEL)
   Else If FullScreen Then ExecCmd(CM_FULL);
  End;
  13: If SelObj >= 0 Then ExecCmd(CM_EDITTXT);
  43, 61: ExecCmd(CM_ZOOMIN);
  45: ExecCmd(CM_ZOOMOUT);
  49: ExecCmd(CM_Z100);
  50: ExecCmd(CM_FITW);
  51: ExecCmd(CM_FITP);
 Else
  Begin
   C := UpCase(Chr(K));
   Case C Of
    'V': ExecCmd(CM_TOOL0 + TL_SELECT);
    'H': ExecCmd(CM_TOOL0 + TL_HAND);
    'Z': ExecCmd(CM_TOOL0 + TL_ZOOM);
    'T': ExecCmd(CM_TOOL0 + TL_TEXT);
    'N': ExecCmd(CM_TOOL0 + TL_NOTE);
    'K': ExecCmd(CM_TOOL0 + TL_HILITE);
    'U': ExecCmd(CM_TOOL0 + TL_UNDER);
    'S': ExecCmd(CM_TOOL0 + TL_STRIKE);
    'P': ExecCmd(CM_TOOL0 + TL_PENCIL);
    'L': ExecCmd(CM_TOOL0 + TL_LINE);
    'A': ExecCmd(CM_TOOL0 + TL_ARROW);
    'R': ExecCmd(CM_TOOL0 + TL_RECT);
    'O': ExecCmd(CM_TOOL0 + TL_OVAL);
    'M': ExecCmd(CM_TOOL0 + TL_STAMP);
    'G': ExecCmd(CM_TOOL0 + TL_SIGN);
    'X': ExecCmd(CM_TOOL0 + TL_REDACT);
   End;
  End;
 End;
End;

Procedure MainLoop;
Begin
 While Running Do Begin
  HandleMouse;
  HandleKeys;
  Delay(8);
 End;
End;

Procedure InitVars;
Var
 I: Integer;
Begin
 ObjCount := 0; PageCount := 1; CurPage := 1; PoolCount := 0;
 Zoom := 100; FitMode := 1; Continuous := 1; NavVisible := 1; ToolbarVisible := 1; NavTab := 0;
 FullScreen := False;
 NavScroll := 0;
 CurTool := TL_SELECT;
 SelObj := -1; FindObj := -1; FindText := ''; FindCase := False;
 For I := 0 To TL_COUNT - 1 Do ToolRgb[I] := $FF0000;
 ToolRgb[TL_TEXT] := 0;
 ToolRgb[TL_NOTE] := $FFFF00;
 ToolRgb[TL_HILITE] := $FFFF00;
 ToolRgb[TL_REDACT] := 0;
 CurWidth := 2; CurSize := 12; CurFam := 0; CurStyle := 0; CurAngle := 0;
 ClipValid := False;
 Editing := False; EditObj := -1;
 MenuActive := False; ActiveMenu := -1; ActiveItem := -1; UnderValid := False;
 UndoTop := 0; RedoTop := 0;
 DragMode := 0; PreviewOn := False;
 Running := True;
 DocName := ''; Modified := False; Imported := False;
 HintText := ''; StatusMsg := '';
 SigName := '';
 LastDir := '';
 FileMaskAll := False;
 FEnts := Nil;
 SortIdx := Nil;
 PdfBuffersReady := False;
 LastClickT := 0; LastClickX := 0; LastClickY := 0;
 MX_ := 0; MY_ := 0; MB_ := 0; OMX := 0; OMY := 0; OMB := 0;
 LastNavPage := -1;
 FillChar(UndoStack, SizeOf(UndoStack), 0);
 FillChar(RedoStack, SizeOf(RedoStack), 0);
End;

Var
 Dummy: Boolean;
 StartFile, Arg, UpArg: String;
 ArgI: Integer;
 WantHelp: Boolean;
 HelpOutput: Text;

BEGIN
 StartFile := '';
 MaxScreen := False;
 WantHelp := False;
 For ArgI := 1 To ParamCount Do Begin
  Arg := ParamStr(ArgI);
  UpArg := UpStr(Arg);
  If UpArg = '-MAXSCREEN' Then MaxScreen := True
  Else If (UpArg = '/?') Or (UpArg = '--HELP') Or (UpArg = '-H') Then WantHelp := True
  Else If StartFile = '' Then StartFile := Arg;
 End;
 If WantHelp Then Begin
  { Un flux distinct conserve la sortie console, même avec l'unité Crt. }
  Assign(HelpOutput, '');
  Rewrite(HelpOutput);
  WriteLn(HelpOutput, 'ACROBAT : Visionneuse et éditeur de documents PDF (clone d''Adobe Acrobat).');
  WriteLn(HelpOutput);
  WriteLn(HelpOutput, 'Syntaxe : ACROBAT [fichier.pdf] [-maxscreen] [/? | -h | --help]');
  WriteLn(HelpOutput);
  WriteLn(HelpOutput, '  Sans option          Lance l''application graphique en 640x480.');
  WriteLn(HelpOutput, '  -h, --help           Affichent également cette aide.');
  WriteLn(HelpOutput, '  -maxscreen           Utilise la resolution maximale disponible.');
  WriteLn(HelpOutput, '  /?                   Affiche cette aide et quitte.');
  WriteLn(HelpOutput);
  WriteLn(HelpOutput, 'Raccourcis : Ctrl+O Ouvrir, Ctrl+S Enregistrer, Ctrl+Z Annuler, F1 Aide, Ctrl+Q Quitter');
  Close(HelpOutput);
  Halt;
 End;
 {$IFDEF FPC}
 ReturnNilIfGrowHeapFails := True;
 {$ENDIF}
 InitVars;
 InitializeGraphics;
 {$IFDEF FPC}
 Dummy := PtcMouse.InitMouse;
 PtcMouse.ShowMouse;
 {$ELSE}
 If MouseDriverFound Then ShowMouse;
 {$ENDIF}
 SetTextStyle(DefaultFont, HorizDir, 1);
 AllocDoc;
 BuildVFont;
 InitMenus;
 InitToolbar;
 NewDocument;
 CalcLayout;
 If StartFile <> '' Then Begin
  RedrawAll;
  OpenFileByName(StartFile);
 End
 Else RedrawAll;
 MainLoop;
 HideMouse;
 CloseGraph;
END.
