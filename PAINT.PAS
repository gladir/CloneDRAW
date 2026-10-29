{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Free Pascal 3.2)
  @description(Clone complet de Microsoft Paint en Turbo Pascal/Free Pascal)

  TODO Liste des 25 points à implémenter:
  ----------------------------------------
  TODO 1: Créer la structure du programme avec directives pour Turbo Pascal et Free Pascal
  TODO 2: Implémenter l'initialisation du mode graphique (VGA 640x480)
  TODO 3: Dessiner la barre de menu (Fichier, Edition, Affichage, Image, Couleurs, Aide)
  TODO 4: Dessiner la barre d'outils à gauche avec les 16 icônes d'outils
  TODO 5: Dessiner la palette de couleurs en bas de l'écran
  TODO 6: Implémenter la zone de dessin principale (canvas)
  TODO 7: Implémenter la gestion de la souris (clic, déplacement, relâchement)
  TODO 8: Implémenter l'outil Crayon (TOOL_PENCIL) - dessin pixel par pixel
  TODO 9: Implémenter l'outil Pinceau (TOOL_BRUSH) - dessin avec différentes formes
  TODO 10: Implémenter l'outil Gomme (TOOL_ERASER) - effacement avec couleur de fond
  TODO 11: Implémenter l'outil Ligne (TOOL_LINE) - tracé de lignes droites
  TODO 12: Implémenter l'outil Rectangle (TOOL_RECT) - rectangles pleins ou vides
  TODO 13: Implémenter l'outil Ellipse (TOOL_ELLIPSE) - cercles et ellipses
  TODO 14: Implémenter l'outil Rectangle arrondi (TOOL_ROUNDRECT)
  TODO 15: Implémenter l'outil Polygone (TOOL_POLYGON) - formes à plusieurs côtés
  TODO 16: Implémenter l'outil Remplissage (TOOL_FILL) - algorithme flood fill
  TODO 17: Implémenter l'outil Pipette (TOOL_PICKER) - sélection de couleur
  TODO 18: Implémenter l'outil Texte (TOOL_TEXT) - insertion de texte
  TODO 19: Implémenter l'outil Aérographe (TOOL_AIRBRUSH) - spray de points
  TODO 20: Implémenter l'outil Courbe (TOOL_CURVE) - courbes de Bézier
  TODO 21: Implémenter l'outil Loupe (TOOL_MAGNIFY) - zoom sur l'image
  TODO 22: Implémenter l'outil Sélection (TOOL_SELECT) - sélection rectangulaire
  TODO 23: Implémenter sauvegarde/chargement fichiers BMP
  TODO 24: Implémenter le menu Fichier (Nouveau, Ouvrir, Enregistrer, Quitter)
  TODO 25: Implémenter Annuler/Rétablir (Undo/Redo) avec buffer mémoire
}

Program Paint;

{$A-}

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$OVERFLOWCHECKS OFF}
{$ENDIF}

Uses
 {$IFDEF FPC}
  Crt, PtcGraph, PtcCrt, PtcMouse, Dos
 {$ELSE}
  Crt, Graph, Dos
 {$ENDIF};

{$IFDEF WINDOWS}
{ Declarations minimales des API du presse-papiers, sans l'unite Windows.
  BOOL et UINT restent sur 32 bits ; HANDLE et SIZE_T suivent le pointeur.
  stdcall correspond a l'ABI Win32 et est adapte par FPC sous Win64. }
Type
 TPaintWinBool = LongBool;
 TPaintWinUInt = LongWord;
 TPaintWinHandle = PtrUInt;
 TPaintWinSize = PtrUInt;

Const
 PAINT_CF_TEXT = 1;
 PAINT_GMEM_MOVEABLE = $0002;

Function PaintWinOpenClipboard(Owner: TPaintWinHandle): TPaintWinBool;
 stdcall; external 'user32.dll' name 'OpenClipboard';
Function PaintWinGetClipboardData(Format: TPaintWinUInt): TPaintWinHandle;
 stdcall; external 'user32.dll' name 'GetClipboardData';
Function PaintWinCloseClipboard: TPaintWinBool;
 stdcall; external 'user32.dll' name 'CloseClipboard';
Function PaintWinEmptyClipboard: TPaintWinBool;
 stdcall; external 'user32.dll' name 'EmptyClipboard';
Function PaintWinSetClipboardData(Format: TPaintWinUInt;
                                Memory: TPaintWinHandle): TPaintWinHandle;
 stdcall; external 'user32.dll' name 'SetClipboardData';
Function PaintWinGlobalAlloc(Flags: TPaintWinUInt;
                            Bytes: TPaintWinSize): TPaintWinHandle;
 stdcall; external 'kernel32.dll' name 'GlobalAlloc';
Function PaintWinGlobalLock(Memory: TPaintWinHandle): Pointer;
 stdcall; external 'kernel32.dll' name 'GlobalLock';
Function PaintWinGlobalUnlock(Memory: TPaintWinHandle): TPaintWinBool;
 stdcall; external 'kernel32.dll' name 'GlobalUnlock';
Function PaintWinGlobalFree(Memory: TPaintWinHandle): TPaintWinHandle;
 stdcall; external 'kernel32.dll' name 'GlobalFree';
{$ENDIF}

Const
 { Constantes de version }
 VERSION_MAJOR = 1;
 VERSION_MINOR = 0;
 PROGRAM_NAME = 'PAINT - Clone de MS Paint';

 { Constantes de l'interface }
 TOOLBAR_WIDTH = 50;
 MENUBAR_HEIGHT = 20;
 STATUSBAR_HEIGHT = 20;
 COLORBAR_HEIGHT = 40;

 { Nombre maximum d'outils }
 MAX_TOOLS = 16;

 { Constantes d'outils }
 TOOL_SELECT = 0;
 TOOL_ERASER = 1;
 TOOL_FILL = 2;
 TOOL_PICKER = 3;
 TOOL_MAGNIFY = 4;
 TOOL_PENCIL = 5;
 TOOL_BRUSH = 6;
 TOOL_AIRBRUSH = 7;
 TOOL_TEXT = 8;
 TOOL_LINE = 9;
 TOOL_CURVE = 10;
 TOOL_RECT = 11;
 TOOL_POLYGON = 12;
 TOOL_ELLIPSE = 13;
 TOOL_ROUNDRECT = 14;

 { Constantes de menu }
 MENU_FILE = 0;
 MENU_EDIT = 1;
 MENU_VIEW = 2;
 MENU_IMAGE = 3;
 MENU_COLORS = 4;
 MENU_HELP = 5;

 { Constantes pour les formats d'image }
 FMT_BMP = 0;
 FMT_GIF = 1;
 FMT_PNG = 2;
 FMT_JPEG = 3;
 FMT_PCX = 4;
 FMT_TARGA = 5;
 FMT_TIFF = 6;
 FMT_XBM = 7;
 FMT_WPG = 8;
 FMT_LBM = 9;
 FMT_HDR = 10;
 FMT_FAX = 11;
 FMT_EXR = 12;
 FMT_DNG = 13;
 FMT_BGX = 14;
 FMT_DDS = 15;
 FMT_DCM = 16;
 FMT_APNG = 17;
 FMT_ARW = 18;
 FMT_CR2 = 19;
 FMT_PPM = 20;
 FMT_DIB = 21;
 FMT_CUR = 22;
 FMT_MSP = 23;
 FMT_MAC = 24;
 FMT_PAS = 25;
 FMT_ICO = 26;

 { Profondeurs de couleur supportées }
 DEPTH_2 = 1;
 DEPTH_4 = 2;
 DEPTH_8 = 3;
 DEPTH_16 = 4;
 DEPTH_32 = 5;
 DEPTH_64 = 6;
 DEPTH_128 = 7;
 DEPTH_256 = 8;
 DEPTH_4096 = 12;
 DEPTH_32768 = 15;
 DEPTH_65536 = 16;
 DEPTH_16M = 24;
 DEPTH_32BIT = 32;

 { Taille maximale de l'image en mémoire }
 MAX_IMAGE_WIDTH = 4096;
 MAX_IMAGE_HEIGHT = 4096;

 { Constantes pour les fichiers BMP }
 BMP_SIGNATURE = $4D42;  { 'BM' }

 { Constantes pour les fichiers GIF }
 GIF87_SIGNATURE = 'GIF87a';
 GIF89_SIGNATURE = 'GIF89a';

 { Constantes pour les fichiers PNG }
 PNG_SIGNATURE: Array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

 { Constantes pour les fichiers JPEG }
 JPEG_SOI = $FFD8;
 JPEG_EOI = $FFD9;

Type
 { Types de données pour la gestion des couleurs }
 TRGBColor = Record
  R, G, B: Byte;
  A: Byte;  { Alpha pour la transparence }
 End;

 TRGBQuad = Record
  Blue, Green, Red, Reserved: Byte;
 End;

 TPalette = Array[0..255] of TRGBColor;

 { Type pour les coordonnées }
 TPoint = Record
  X, Y: Integer;
 End;

 TRect = Record
  Left, Top, Right, Bottom: Integer;
 End;

 { Structure de l'en-tête BMP }
 { Packed Record obligatoire : layout binaire mappé au fichier (14 octets).
   Sans Packed, FPC -Mtp insère 2 octets de padding entre bfType (Word) et
   bfSize (LongInt), portant SizeOf à 16 et décalant toute la lecture. }
 TBMPFileHeader = Packed Record
  bfType: Word;
  bfSize: LongInt;
  bfReserved1: Word;
  bfReserved2: Word;
  bfOffBits: LongInt;
 End;

 TBMPInfoHeader = Packed Record
  biSize: LongInt;
  biWidth: LongInt;
  biHeight: LongInt;
  biPlanes: Word;
  biBitCount: Word;
  biCompression: LongInt;
  biSizeImage: LongInt;
  biXPelsPerMeter: LongInt;
  biYPelsPerMeter: LongInt;
  biClrUsed: LongInt;
  biClrImportant: LongInt;
 End;

 { Structure pour l'en-tête GIF }
 TGIFHeader = Packed Record
  Signature: Array[0..5] of Char;
  ScreenWidth: Word;
  ScreenHeight: Word;
  Flags: Byte;
  BackgroundColor: Byte;
  AspectRatio: Byte;
 End;

 { Structure pour l'image en mémoire }
 TPaintMetadata = Record
  Values: Array[0..5] Of String; { Titre, auteur, droits, logiciel, description, note }
  Limited: Boolean;
 End;
 PImageBuffer = ^TImageBuffer;
 TImageBuffer = Record
  Width, Height: Integer;
  BitDepth: Byte;
  HasTransparency: Boolean;
  TransparentColor: TRGBColor;
  Palette: TPalette;
  Modified: Boolean;
  FileName: String;
  Format: Byte;
  Metadata: TPaintMetadata;
  HasHotspot: Boolean;
  HotspotX,HotspotY,CursorImages: Integer;
 End;

 { Structure pour l'historique (Undo/Redo) }
 PHistoryItem = ^THistoryItem;
 THistoryItem = Record
  Action: Byte;
  Data: Pointer;
  DataSize: LongInt;
  Next, Prev: PHistoryItem;
 End;

 { Structure pour les menus }
 TMenuItem = Record
  Caption: String[30];
  Shortcut: String[10];
  Enabled: Boolean;
  Checked: Boolean;
  Separator: Boolean;
 End;

 TMenu = Record
  Title: String[15];
  Items: Array[0..15] of TMenuItem;
  ItemCount: Byte;
  X, Width: Integer;
 End;

 { Structure pour les outils }
 TTool = Record
  Name: String[15];
  Icon: Array[0..15, 0..15] of Byte;
  Selected: Boolean;
 End;

Var
 Language:(_French,_English,_Germany,_Italian,_Spain,_Albanian,_Portuguese,_Swedish,_Danish,_Japanese);
 TmpLanguage:String;
 { Variables globales de l'application }
 GraphDriver, GraphMode: Integer;
 ScreenWidth, ScreenHeight: Integer;
 Running: Boolean;
 CurrentTool: Byte;
 CurrentColor: Byte;
 BackgroundColor: Byte;
 BrushSize: Byte;
 LineWidth: Byte;
 FillStyle: Byte;

 { Variables de la souris }
 MouseX, MouseY: Integer;
 MouseButtons: Integer;
 MouseVisible: Boolean;
 OldMouseX, OldMouseY: Integer;
 OldMouseButtons: Integer;
 { Survol des icones : infobulle jaune apres une demi-seconde. }
 ToolTipVisible: Boolean;
 ToolTipCandidate,ToolTipX,ToolTipY: Integer;
 ToolTipStarted: LongInt;
 ToolTipPixels: Array[0..32767] Of Byte;

 { Rubber-band XOR pour la selection en cours }
 RubberValid: Boolean;
 RubberL, RubberT, RubberR, RubberB: Integer;
 { Apercu XOR pour les formes (ligne, rectangle, ellipse, rectarrondi) }
 PreviewValid: Boolean;
 PreviewTool: Byte;
 PreviewL, PreviewT, PreviewR, PreviewB: Integer;
 { Marching ants : animation du contour de la selection }
 AntsPhase: Integer;
 AntsCounter: Integer;
 AntsValid: Boolean;

 { Variables de l'image }
 ImageBuffer: TImageBuffer;
 CanvasX, CanvasY: Integer;
 CanvasWidth, CanvasHeight: Integer;
 ZoomLevel: Integer;
 ZOriginX, ZOriginY: Integer;

 { Variables pour la sélection }
 SelectionActive: Boolean;
 SelectionRect: TRect;
 CropActive: Boolean;

 { Variables pour les menus }
 Menus: Array[0..5] of TMenu;
 MenuActive: Boolean;
 ActiveMenu: Integer;
 ActiveMenuItem: Integer;

 { Variables pour l'historique }
 UndoList, RedoList: PHistoryItem;
 UndoCount, RedoCount: Integer;
 MaxUndoLevels: Integer;

 { Palette de couleurs standard }
 StandardPalette: Array[0..27] of Byte;

 { Variable pour l'affichage texte }
 TextInput: String;
 TextInsertMode: Boolean;
 TextX, TextY: Integer;
 TextPrevW, TextPrevH: Integer;  { Taille du dernier apercu pour effacement }

 { Variables pour le dessin }
 Drawing: Boolean;
 PolygonCount,PolygonMouseX,PolygonMouseY: Integer;
 PolygonX,PolygonY: Array[0..255] Of Integer;
 PolygonHover,PolygonOverlayValid: Boolean;
 PolygonLastClick: LongInt;

 StartX, StartY: Integer;
 EndX, EndY: Integer;

 { Sauvegarde des pixels du canvas (image chargée) pour redessin
   après effacement par le menu/interface. }
 CanvasImage: PByte;
 CanvasImageW, CanvasImageH: Integer;

Function StrToUpper(Const S:String):String;
Var I:Integer; R:String;
Begin
 R:=S;
 For I:=1 To Length(R) Do
  If(R[I]>='a')And(R[I]<='z')Then R[I]:=Chr(Ord(R[I])-32);
 StrToUpper:=R;
End;

{$IFNDEF FPC}
{ Procédures pour la gestion de la souris en Turbo Pascal via Int 33h }

Procedure InitMouse;
Var
 Regs: Registers;
Begin
 Regs.AX := $0000;
 Intr($33, Regs);
 If Regs.AX = $FFFF Then
  MouseVisible := True
 Else
  MouseVisible := False;
End;

Procedure ShowMouse;
Var
 Regs: Registers;
Begin
 If MouseVisible Then Begin
  Regs.AX := $0001;
  Intr($33, Regs);
 End;
End;

Procedure HideMouse;
Var
 Regs: Registers;
Begin
 If MouseVisible Then Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;
End;

Procedure GetMouseStateLocal(Var X, Y, Buttons: Integer);
Var
 Regs: Registers;
Begin
 Regs.AX := $0003;
 Intr($33, Regs);
 X := Regs.CX;
 Y := Regs.DX;
 Buttons := Regs.BX;
End;

Procedure SetMousePosition(X, Y: Integer);
Var
 Regs: Registers;
Begin
 Regs.AX := $0004;
 Regs.CX := X;
 Regs.DX := Y;
 Intr($33, Regs);
End;

Procedure SetMouseBounds(X1, Y1, X2, Y2: Integer);
Var
 Regs: Registers;
Begin
 { Limites horizontales }
 Regs.AX := $0007;
 Regs.CX := X1;
 Regs.DX := X2;
 Intr($33, Regs);
 { Limites verticales }
 Regs.AX := $0008;
 Regs.CX := Y1;
 Regs.DX := Y2;
 Intr($33, Regs);
End;

{$ELSE}
{ Wrappers pour Free Pascal avec PtcMouse }

Procedure InitMouseDriver;
Begin
 PtcMouse.InitMouse;
 MouseVisible := True;
End;

Procedure ShowMouseCursor;
Begin
 PtcMouse.ShowMouse;
End;

Procedure HideMouseCursor;
Begin
 PtcMouse.HideMouse;
End;

Procedure GetMouseStateLocal(Var X, Y, Buttons: Integer);
Var
 LX, LY, LB: LongInt;
Begin
 PtcMouse.GetMouseState(LX, LY, LB);
 X := LX;
 Y := LY;
 Buttons := LB;
End;

Procedure SetMousePosition(X, Y: Integer);
Begin
 PtcMouse.SetMousePos(X, Y);
End;

Procedure SetMouseBounds(X1, Y1, X2, Y2: Integer);
Begin
 { Cette fonction n'est pas disponible dans PtcMouse }
End;
{$ENDIF}

{ Procédures utilitaires }

Procedure DrawRoundedRect(X1, Y1, X2, Y2, RX, RY: Integer);
{ Dessine un rectangle arrondi compatible avec tous les compilateurs }
Begin
 { Lignes horizontales }
 Line(X1 + RX, Y1, X2 - RX, Y1);
 Line(X1 + RX, Y2, X2 - RX, Y2);
 { Lignes verticales }
 Line(X1, Y1 + RY, X1, Y2 - RY);
 Line(X2, Y1 + RY, X2, Y2 - RY);
 { Coins arrondis }
 Arc(X1 + RX, Y1 + RY, 90, 180, RX);
 Arc(X2 - RX, Y1 + RY, 0, 90, RX);
 Arc(X1 + RX, Y2 - RY, 180, 270, RX);
 Arc(X2 - RX, Y2 - RY, 270, 360, RX);
End;

Function Min(A, B: Integer): Integer;
Begin
 If A < B Then Min := A Else Min := B;
End;

Function Max(A, B: Integer): Integer;
Begin
 If A > B Then Max := A Else Max := B;
End;

Function IntToStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

Function StrToInt(S: String): LongInt;
Var
 N: LongInt;
 Code: Integer;
Begin
 Val(S, N, Code);
 If Code <> 0 Then N := 0;
 StrToInt := N;
End;

Function UpperCase(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 to Length(S) do
  S[I] := UpCase(S[I]);
 UpperCase := S;
End;

Function ExtractFileExt(FileName: String): String;
Var
 I: Integer;
 Ext: String;
Begin
 Ext := '';
 For I := Length(FileName) downto 1 do Begin
  If FileName[I] In ['\','/',':'] Then Break;
  If FileName[I] = '.' Then Begin
   Ext := Copy(FileName, I, Length(FileName) - I + 1);
   Break;
  End;
 End;
 ExtractFileExt := UpperCase(Ext);
End;

Function GetImageFormat(FileName: String): Byte;
Var
 Ext: String;
Begin
 Ext := ExtractFileExt(FileName);
 If Ext = '.BMP' Then
  GetImageFormat := FMT_BMP
 Else If Ext = '.DIB' Then
  GetImageFormat := FMT_DIB
 Else If Ext = '.GIF' Then
  GetImageFormat := FMT_GIF
 Else If Ext = '.PNG' Then
  GetImageFormat := FMT_PNG
 Else If (Ext = '.JPG') or (Ext = '.JPEG') Then
  GetImageFormat := FMT_JPEG
 Else If Ext = '.PCX' Then
  GetImageFormat := FMT_PCX
 Else If (Ext = '.TGA') or (Ext = '.TARGA') Then
  GetImageFormat := FMT_TARGA
 Else If Ext = '.PAS' Then
  GetImageFormat := FMT_PAS
 Else If (Ext = '.MAC') Or (Ext = '.PNTG') Then
  GetImageFormat := FMT_MAC
 Else If Ext = '.MSP' Then
  GetImageFormat := FMT_MSP
 Else If Ext = '.ICO' Then
  GetImageFormat := FMT_ICO
 Else If Ext = '.CUR' Then
  GetImageFormat := FMT_CUR
 Else If Ext = '.PPM' Then
  GetImageFormat := FMT_PPM
 Else If Ext = '.CR2' Then
  GetImageFormat := FMT_CR2
 Else If Ext = '.ARW' Then
  GetImageFormat := FMT_ARW
 Else If Ext = '.APNG' Then
  GetImageFormat := FMT_APNG
 Else If Ext = '.DCM' Then
  GetImageFormat := FMT_DCM
 Else If Ext = '.DDS' Then
  GetImageFormat := FMT_DDS
 Else If Ext = '.BGX' Then
  GetImageFormat := FMT_BGX
 Else If Ext = '.DNG' Then
  GetImageFormat := FMT_DNG
 Else If Ext = '.EXR' Then
  GetImageFormat := FMT_EXR
 Else If Ext = '.FAX' Then
  GetImageFormat := FMT_FAX
 Else If (Ext = '.HDR') or (Ext = '.RGBE') Then
  GetImageFormat := FMT_HDR
 Else If (Ext = '.LBM') or (Ext = '.ILBM') or (Ext = '.IFF') Then
  GetImageFormat := FMT_LBM
 Else If Ext = '.WPG' Then
  GetImageFormat := FMT_WPG
 Else If Ext = '.XBM' Then
  GetImageFormat := FMT_XBM
 Else If (Ext = '.TIF') or (Ext = '.TIFF') Then
  GetImageFormat := FMT_TIFF
 Else
  GetImageFormat := FMT_BMP;
End;

Function EnsureSaveExtension(FileName: String): String;
{ Si l'utilisateur n'a pas indique d'extension reconnue, ajoute .BMP. }
Var
 Ext: String;
Begin
 Ext := ExtractFileExt(FileName);
 If (Ext = '.BMP') or (Ext = '.DIB') or
    (Ext = '.GIF') or (Ext = '.PNG') or
    (Ext = '.JPG') or (Ext = '.JPEG') or
    (Ext = '.PCX') or (Ext = '.TGA') or (Ext = '.TARGA') or
    (Ext = '.TIF') or (Ext = '.TIFF') Then
  EnsureSaveExtension := FileName
 Else
  EnsureSaveExtension := FileName + '.bmp';
End;

{ Procédures d'initialisation }

{ Les outils conservent des coordonnees logiques CanvasX+pixel image.
  Seul l'affichage utilise le facteur de zoom et l'origine de la vue. }
Function ZFloorDiv(Value: LongInt; Divisor: Integer): LongInt;
Begin
 If Value>=0 Then ZFloorDiv := Value Div Divisor
 Else ZFloorDiv := -((-Value+Divisor-1) Div Divisor);
End;

Function ZCeilDiv(Value: LongInt; Divisor: Integer): LongInt;
Begin
 ZCeilDiv := -ZFloorDiv(-Value,Divisor);
End;

Function ZScreenX(X: Integer): Integer;
Begin
 ZScreenX := ZOriginX+ZFloorDiv(LongInt(X-CanvasX)*100,ZoomLevel);
End;

Function ZScreenY(Y: Integer): Integer;
Begin
 ZScreenY := ZOriginY+ZFloorDiv(LongInt(Y-CanvasY)*100,ZoomLevel);
End;

Function ZEventX(X: Integer): Integer;
Begin ZEventX := CanvasX+ZScreenX(X); End;

Function ZEventY(Y: Integer): Integer;
Begin ZEventY := CanvasY+ZScreenY(Y); End;

Function ZViewX(X: Integer): Integer;
Var V: LongInt;
Begin
 V := ZFloorDiv(LongInt(X-CanvasX-ZOriginX)*ZoomLevel,100);
 If V < -30000 Then V := -30000;
 If V > 30000 Then V := 30000;
 ZViewX := V;
End;

Function ZViewY(Y: Integer): Integer;
Var V: LongInt;
Begin
 V := ZFloorDiv(LongInt(Y-CanvasY-ZOriginY)*ZoomLevel,100);
 If V < -30000 Then V := -30000;
 If V > 30000 Then V := 30000;
 ZViewY := V;
End;

Function ZTransformed: Boolean;
Begin ZTransformed := (ZoomLevel<>100) Or (ZOriginX<>0) Or (ZOriginY<>0); End;

Procedure ZClampView;
Var W, H: Integer;
Begin
 If ZoomLevel<25 Then ZoomLevel := 25;
 If ZoomLevel>800 Then ZoomLevel := 800;
 W := ZCeilDiv(LongInt(CanvasWidth)*100,ZoomLevel);
 H := ZCeilDiv(LongInt(CanvasHeight)*100,ZoomLevel);
 ZOriginX := Max(0,Min(ZOriginX,Max(0,CanvasImageW-W)));
 ZOriginY := Max(0,Min(ZOriginY,Max(0,CanvasImageH-H)));
End;

Function ZDisplayWidth: Integer;
Var W: LongInt;
Begin
 W:=ZCeilDiv(LongInt(CanvasImageW-ZOriginX)*ZoomLevel,100);
 If W<0 Then W:=0;
 If W>CanvasWidth Then W:=CanvasWidth;
 ZDisplayWidth:=W;
End;

Function ZDisplayHeight: Integer;
Var H: LongInt;
Begin
 H:=ZCeilDiv(LongInt(CanvasImageH-ZOriginY)*ZoomLevel,100);
 If H<0 Then H:=0;
 If H>CanvasHeight Then H:=CanvasHeight;
 ZDisplayHeight:=H;
End;

Function ZHitCanvas(X, Y: Integer): Boolean;
Begin
 ZHitCanvas := (X>=CanvasX) And (Y>=CanvasY) And
               (X<CanvasX+ZDisplayWidth) And (Y<CanvasY+ZDisplayHeight);
End;

Function ZImagePixel(X, Y: Integer): Byte;
Var P: PByte;
Begin
 ZImagePixel := BackgroundColor;
 If (CanvasImage=Nil) Or (X<0) Or (Y<0) Or
    (X>=CanvasImageW) Or (Y>=CanvasImageH) Then Exit;
 P := CanvasImage; Inc(P,LongInt(Y)*CanvasImageW+X);
 ZImagePixel := P^;
End;

Procedure ZPutImagePixel(X, Y: Integer; Color: Byte);
Var P: PByte;
Begin
 If (CanvasImage=Nil) Or (X<0) Or (Y<0) Or
    (X>=CanvasImageW) Or (Y>=CanvasImageH) Then Exit;
 P := CanvasImage; Inc(P,LongInt(Y)*CanvasImageW+X);
 P^ := Color;
End;

Procedure ZRenderPixel(X, Y: Integer; Color: Byte);
Var L, T, R, B: Integer;
Begin
 If (X<0) Or (Y<0) Or (X>=CanvasImageW) Or (Y>=CanvasImageH) Then Exit;
 L := ZCeilDiv(LongInt(X-ZOriginX)*ZoomLevel,100);
 T := ZCeilDiv(LongInt(Y-ZOriginY)*ZoomLevel,100);
 R := ZCeilDiv(LongInt(X-ZOriginX+1)*ZoomLevel,100)-1;
 B := ZCeilDiv(LongInt(Y-ZOriginY+1)*ZoomLevel,100)-1;
 L := Max(0,L); T := Max(0,T);
 R := Min(CanvasWidth-1,R); B := Min(CanvasHeight-1,B);
 If (L>R) Or (T>B) Then Exit;
 SetFillStyle(SolidFill,Color);
 Bar(CanvasX+L,CanvasY+T,CanvasX+R,CanvasY+B);
End;

Procedure ZBeginView(Var Previous: ViewPortType);
Begin
 GetViewSettings(Previous);
 SetViewPort(CanvasX,CanvasY,CanvasX+Max(0,ZDisplayWidth-1),
             CanvasY+Max(0,ZDisplayHeight-1),True);
End;

Procedure ZEndView(Const Previous: ViewPortType);
Begin
 SetViewPort(Previous.X1,Previous.Y1,Previous.X2,Previous.Y2,Previous.Clip);
End;

Procedure ZLine(X1,Y1,X2,Y2: Integer; Color: Byte);
Var DX,DY,SX,SY,Error,E2: LongInt;
Begin
 DX := Abs(X2-X1); DY := -Abs(Y2-Y1);
 SX := 1; If X1>X2 Then SX := -1;
 SY := 1; If Y1>Y2 Then SY := -1;
 Error := DX+DY;
 Repeat
  ZPutImagePixel(X1,Y1,Color);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2 := 2*Error;
  If E2>=DY Then Begin Error := Error+DY; X1 := X1+SX; End;
  If E2<=DX Then Begin Error := Error+DX; Y1 := Y1+SY; End;
 Until False;
End;

Procedure ZRectangle(X1,Y1,X2,Y2: Integer; Color: Byte; Filled: Boolean);
Var X,Y,T: Integer;
Begin
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
 If Filled Then Begin
  For Y:=Max(0,Y1) To Min(CanvasImageH-1,Y2) Do
   For X:=Max(0,X1) To Min(CanvasImageW-1,X2) Do ZPutImagePixel(X,Y,Color);
 End
 Else Begin
  ZLine(X1,Y1,X2,Y1,Color); ZLine(X2,Y1,X2,Y2,Color);
  ZLine(X2,Y2,X1,Y2,Color); ZLine(X1,Y2,X1,Y1,Color);
 End;
End;

Procedure ZEllipse(CX,CY,RX,RY: Integer; Color: Byte; Filled: Boolean);
Var X,Y,Span: Integer;
Begin
 RX:=Abs(RX); RY:=Abs(RY);
 If RX=0 Then Begin ZLine(CX,CY-RY,CX,CY+RY,Color); Exit; End;
 If RY=0 Then Begin ZLine(CX-RX,CY,CX+RX,CY,Color); Exit; End;
 For Y:=-RY To RY Do Begin
  Span:=Round(RX*Sqrt(Abs(1-Y*1.0*Y/(RY*1.0*RY))));
  If Filled Then ZLine(CX-Span,CY+Y,CX+Span,CY+Y,Color)
  Else Begin ZPutImagePixel(CX-Span,CY+Y,Color); ZPutImagePixel(CX+Span,CY+Y,Color); End;
 End;
 If Not Filled Then
  For X:=-RX To RX Do Begin
   Span:=Round(RY*Sqrt(Abs(1-X*1.0*X/(RX*1.0*RX))));
   ZPutImagePixel(CX+X,CY-Span,Color); ZPutImagePixel(CX+X,CY+Span,Color);
  End;
End;

Procedure ZRoundRectangle(X1,Y1,X2,Y2,RX,RY: Integer; Color: Byte; Filled: Boolean);
Var X,Y,T,Span,Inset,PrevInset: Integer;
Begin
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
 RX:=Min(Abs(RX),(X2-X1) Div 2); RY:=Min(Abs(RY),(Y2-Y1) Div 2);
 If (RX=0) Or (RY=0) Then Begin ZRectangle(X1,Y1,X2,Y2,Color,Filled); Exit; End;
 PrevInset:=RX;
 For Y:=Y1 To Y2 Do Begin
  Inset:=0;
  If Y<Y1+RY Then Begin
   T:=Y1+RY-Y;
   Inset:=RX-Round(RX*Sqrt(Abs(1-T*1.0*T/(RY*1.0*RY))));
  End;
  If Y>Y2-RY Then Begin
   T:=Y-(Y2-RY);
   Inset:=RX-Round(RX*Sqrt(Abs(1-T*1.0*T/(RY*1.0*RY))));
  End;
  If Filled Or (Y=Y1) Or (Y=Y2) Then ZLine(X1+Inset,Y,X2-Inset,Y,Color)
  Else Begin
   ZLine(X1+Min(Inset,PrevInset),Y,X1+Max(Inset,PrevInset),Y,Color);
   ZLine(X2-Max(Inset,PrevInset),Y,X2-Min(Inset,PrevInset),Y,Color);
  End;
  PrevInset:=Inset;
 End;
End;

Procedure ZRasterText(X,Y: Integer; Const S: String; Color: Byte; ModifyImage: Boolean);
Var
 Saved: Array[0..4095] of Byte;
 Mask: Array[0..31,0..31] of Boolean;
 I,PX,PY,W,H,Advance: Integer;
 Glyph: String[1];
Begin
 W:=TextWidth('M'); H:=TextHeight('M');
 If (W<1) Or (H<1) Or (W>32) Or (H>32) Then Exit;
 If ImageSize(0,0,W-1,H-1)>SizeOf(Saved) Then Exit;
 HideMouse;
 Advance:=0;
 For I:=1 To Length(S) Do Begin
  Glyph:=S[I];
  GetImage(0,0,W-1,H-1,Saved);
  SetFillStyle(SolidFill,Black); Bar(0,0,W-1,H-1);
  SetColor(White); OutTextXY(0,0,Glyph);
  For PY:=0 To H-1 Do
   For PX:=0 To W-1 Do Mask[PX,PY]:=GetPixel(PX,PY)=White;
  PutImage(0,0,Saved,CopyPut);
  For PY:=0 To H-1 Do
   For PX:=0 To W-1 Do
    If Mask[PX,PY] Then Begin
     If ModifyImage Then ZPutImagePixel(X+Advance+PX,Y+PY,Color)
     Else ZRenderPixel(X+Advance+PX,Y+PY,Color);
    End;
  Inc(Advance,TextWidth(Glyph));
 End;
 ShowMouse;
End;


Function ZPrepareBuffer(W,H: Integer; FillColor: Byte): Boolean;
Var
 P:PByte;
 {$IFDEF FPC}Previous:Boolean;{$ENDIF}
Begin
 ZPrepareBuffer:=False;
 If (W<1) Or (H<1) Or (W>MAX_IMAGE_WIDTH) Or (H>MAX_IMAGE_HEIGHT) Then Exit;
 P:=Nil;
 {$IFDEF FPC}
 Previous:=ReturnNilIfGrowHeapFails; ReturnNilIfGrowHeapFails:=True;
 GetMem(P,LongInt(W)*H);
 ReturnNilIfGrowHeapFails:=Previous;
 {$ELSE}
 If MaxAvail>=LongInt(W)*H Then GetMem(P,LongInt(W)*H);
 {$ENDIF}
 If P=Nil Then Exit;
 FillChar(P^,LongInt(W)*H,FillColor);
 If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
 CanvasImage:=P; CanvasImageW:=W; CanvasImageH:=H;
 ZPrepareBuffer:=True;
End;

Procedure InitGraphics;
{$IFDEF FPC}
Begin
 { 256 indices : couleurs du dessin separees de celles de l interface. }
 GraphDriver := D8bit;
 GraphMode := m640x480;
 InitGraph(GraphDriver, GraphMode, '');
 If GraphResult <> grOk Then Begin
  WriteLn('Erreur d''initialisation graphique!');
  Halt(1);
 End;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
End;
{$ELSE}
Begin
 GraphDriver := Detect;
 InitGraph(GraphDriver, GraphMode, '');
 If GraphResult <> grOk Then Begin
  WriteLn('Erreur d''initialisation graphique!');
  Halt(1);
 End;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
End;
{$ENDIF}

Procedure InitPalette;
Var
 I: Integer;
Begin
 { Palette standard similaire à MS Paint }
 StandardPalette[0] := Black;
 StandardPalette[1] := White;
 StandardPalette[2] := Red;
 StandardPalette[3] := Green;
 StandardPalette[4] := Blue;
 StandardPalette[5] := Yellow;
 StandardPalette[6] := Cyan;
 StandardPalette[7] := Magenta;
 StandardPalette[8] := LightGray;
 StandardPalette[9] := DarkGray;
 StandardPalette[10] := LightRed;
 StandardPalette[11] := LightGreen;
 StandardPalette[12] := LightBlue;
 StandardPalette[13] := LightCyan;
 StandardPalette[14] := LightMagenta;
 StandardPalette[15] := Brown;

 { Couleurs supplémentaires }
 For I := 16 to 27 do
  StandardPalette[I] := I mod 16;

 { Initialiser les couleurs par défaut }
 CurrentColor := Black;
 BackgroundColor := White;
End;

Procedure InitMenus;
Var
 MI, II, Need: Integer;
Begin
 { Menu Fichier }
 Menus[MENU_FILE].Title := 'Fichier';
 Menus[MENU_FILE].X := 5;
 Menus[MENU_FILE].Width := 120;
 Menus[MENU_FILE].ItemCount := 10;
 Menus[MENU_FILE].Items[0].Caption := 'Nouveau';
 Menus[MENU_FILE].Items[0].Shortcut := 'Ctrl+N';
 Menus[MENU_FILE].Items[0].Enabled := True;
 Menus[MENU_FILE].Items[1].Caption := 'Ouvrir...';
 Menus[MENU_FILE].Items[1].Shortcut := 'Ctrl+O';
 Menus[MENU_FILE].Items[1].Enabled := True;
 Menus[MENU_FILE].Items[2].Caption := 'Enregistrer';
 Menus[MENU_FILE].Items[2].Shortcut := 'Ctrl+S';
 Menus[MENU_FILE].Items[2].Enabled := True;
 Menus[MENU_FILE].Items[3].Caption := 'Enregistrer sous...';
 Menus[MENU_FILE].Items[3].Shortcut := '';
 Menus[MENU_FILE].Items[3].Enabled := True;
 Menus[MENU_FILE].Items[4].Separator := True;
 Menus[MENU_FILE].Items[5].Caption := 'Imprimer...';
 Menus[MENU_FILE].Items[5].Shortcut := 'Ctrl+P';
 Menus[MENU_FILE].Items[5].Enabled := True;
 Menus[MENU_FILE].Items[6].Separator := True;
 Menus[MENU_FILE].Items[7].Caption := 'Proprietes...';
 Menus[MENU_FILE].Items[7].Shortcut := '';
 Menus[MENU_FILE].Items[7].Enabled := True;
 Menus[MENU_FILE].Items[8].Separator := True;
 Menus[MENU_FILE].Items[9].Caption := 'Quitter';
 Menus[MENU_FILE].Items[9].Shortcut := 'Alt+F4';
 Menus[MENU_FILE].Items[9].Enabled := True;

 { Menu Modifier }
 Menus[MENU_EDIT].Title := 'Modifier';
 Menus[MENU_EDIT].X := 60;
 Menus[MENU_EDIT].Width := 130;
 Menus[MENU_EDIT].ItemCount := 9;
 Menus[MENU_EDIT].Items[0].Caption := 'Annuler';
 Menus[MENU_EDIT].Items[0].Shortcut := 'Ctrl+Z';
 Menus[MENU_EDIT].Items[0].Enabled := True;
 Menus[MENU_EDIT].Items[1].Caption := 'Retablir';
 Menus[MENU_EDIT].Items[1].Shortcut := 'Ctrl+Y';
 Menus[MENU_EDIT].Items[1].Enabled := True;
 Menus[MENU_EDIT].Items[2].Separator := True;
 Menus[MENU_EDIT].Items[3].Caption := 'Couper';
 Menus[MENU_EDIT].Items[3].Shortcut := 'Ctrl+X';
 Menus[MENU_EDIT].Items[3].Enabled := True;
 Menus[MENU_EDIT].Items[4].Caption := 'Copier';
 Menus[MENU_EDIT].Items[4].Shortcut := 'Ctrl+C';
 Menus[MENU_EDIT].Items[4].Enabled := True;
 Menus[MENU_EDIT].Items[5].Caption := 'Coller';
 Menus[MENU_EDIT].Items[5].Shortcut := 'Ctrl+V';
 Menus[MENU_EDIT].Items[5].Enabled := True;
 Menus[MENU_EDIT].Items[6].Caption := 'Effacer selection';
 Menus[MENU_EDIT].Items[6].Shortcut := 'Suppr';
 Menus[MENU_EDIT].Items[6].Enabled := True;
 Menus[MENU_EDIT].Items[7].Separator := True;
 Menus[MENU_EDIT].Items[8].Caption := 'Tout selectionner';
 Menus[MENU_EDIT].Items[8].Shortcut := 'Ctrl+A';
 Menus[MENU_EDIT].Items[8].Enabled := True;

 { Menu Affichage }
 Menus[MENU_VIEW].Title := 'Affichage';
 Menus[MENU_VIEW].X := 125;
 Menus[MENU_VIEW].Width := 140;
 Menus[MENU_VIEW].ItemCount := 8;
 Menus[MENU_VIEW].Items[0].Caption := 'Barre d''outils';
 Menus[MENU_VIEW].Items[0].Shortcut := '';
 Menus[MENU_VIEW].Items[0].Enabled := True;
 Menus[MENU_VIEW].Items[0].Checked := True;
 Menus[MENU_VIEW].Items[1].Caption := 'Barre de couleurs';
 Menus[MENU_VIEW].Items[1].Shortcut := '';
 Menus[MENU_VIEW].Items[1].Enabled := True;
 Menus[MENU_VIEW].Items[1].Checked := True;
 Menus[MENU_VIEW].Items[2].Caption := 'Barre d''etat';
 Menus[MENU_VIEW].Items[2].Shortcut := '';
 Menus[MENU_VIEW].Items[2].Enabled := True;
 Menus[MENU_VIEW].Items[2].Checked := True;
 Menus[MENU_VIEW].Items[3].Separator := True;
 Menus[MENU_VIEW].Items[4].Caption := 'Zoom avant';
 Menus[MENU_VIEW].Items[4].Shortcut := 'Ctrl++';
 Menus[MENU_VIEW].Items[4].Enabled := True;
 Menus[MENU_VIEW].Items[5].Caption := 'Zoom arrire';
 Menus[MENU_VIEW].Items[5].Shortcut := 'Ctrl+-';
 Menus[MENU_VIEW].Items[5].Enabled := True;
 Menus[MENU_VIEW].Items[6].Separator := True;
 Menus[MENU_VIEW].Items[7].Caption := 'Plein ecran';
 Menus[MENU_VIEW].Items[7].Shortcut := 'F11';
 Menus[MENU_VIEW].Items[7].Enabled := True;

 { Menu Image }
 Menus[MENU_IMAGE].Title := 'Image';
 Menus[MENU_IMAGE].X := 195;
 Menus[MENU_IMAGE].Width := 150;
 Menus[MENU_IMAGE].ItemCount := 10;
 Menus[MENU_IMAGE].Items[0].Caption := 'Retourner/Pivoter...';
 Menus[MENU_IMAGE].Items[0].Shortcut := '';
 Menus[MENU_IMAGE].Items[0].Enabled := True;
 Menus[MENU_IMAGE].Items[1].Caption := 'Etirer/Incliner...';
 Menus[MENU_IMAGE].Items[1].Shortcut := '';
 Menus[MENU_IMAGE].Items[1].Enabled := True;
 Menus[MENU_IMAGE].Items[2].Caption := 'Inverser couleurs';
 Menus[MENU_IMAGE].Items[2].Shortcut := '';
 Menus[MENU_IMAGE].Items[2].Enabled := True;
 Menus[MENU_IMAGE].Items[3].Separator := True;
 Menus[MENU_IMAGE].Items[4].Caption := 'Redimensionner...';
 Menus[MENU_IMAGE].Items[4].Shortcut := 'Ctrl+W';
 Menus[MENU_IMAGE].Items[4].Enabled := True;
 Menus[MENU_IMAGE].Items[5].Caption := 'Rogner (Crop)';
 Menus[MENU_IMAGE].Items[5].Shortcut := '';
 Menus[MENU_IMAGE].Items[5].Enabled := True;
 Menus[MENU_IMAGE].Items[6].Separator := True;
 Menus[MENU_IMAGE].Items[7].Caption := 'Attributs...';
 Menus[MENU_IMAGE].Items[7].Shortcut := '';
 Menus[MENU_IMAGE].Items[7].Enabled := True;
 Menus[MENU_IMAGE].Items[8].Separator := True;
 Menus[MENU_IMAGE].Items[9].Caption := 'Effacer l''image';
 Menus[MENU_IMAGE].Items[9].Shortcut := '';
 Menus[MENU_IMAGE].Items[9].Enabled := True;

 { Menu Couleurs }
 Menus[MENU_COLORS].Title := 'Couleurs';
 Menus[MENU_COLORS].X := 255;
 Menus[MENU_COLORS].Width := 130;
 Menus[MENU_COLORS].ItemCount := 2;
 Menus[MENU_COLORS].Items[0].Caption := 'Modifier palette...';
 Menus[MENU_COLORS].Items[0].Shortcut := '';
 Menus[MENU_COLORS].Items[0].Enabled := True;
 Menus[MENU_COLORS].Items[1].Caption := 'Obtenir couleurs...';
 Menus[MENU_COLORS].Items[1].Shortcut := '';
 Menus[MENU_COLORS].Items[1].Enabled := True;

 { Menu Aide }
 Menus[MENU_HELP].Title := '?';
 Menus[MENU_HELP].X := 325;
 Menus[MENU_HELP].Width := 100;
 Menus[MENU_HELP].ItemCount := 2;
 Menus[MENU_HELP].Items[0].Caption := 'Aide';
 Menus[MENU_HELP].Items[0].Shortcut := 'F1';
 Menus[MENU_HELP].Items[0].Enabled := True;
 Menus[MENU_HELP].Items[1].Caption := 'A propos...';
 Menus[MENU_HELP].Items[1].Shortcut := '';
 Menus[MENU_HELP].Items[1].Enabled := True;

 { Ajuster dynamiquement la largeur de chaque menu déroulant pour que le
   raccourci ne chevauche pas la légende. Layout d'une ligne :
     [coche/20px] + Caption + [16px d'espace] + Shortcut + [10px marge] }
 For MI := 0 to 5 do Begin
  For II := 0 to Menus[MI].ItemCount - 1 do Begin
   If Not Menus[MI].Items[II].Separator Then Begin
    Need := 20 + TextWidth(Menus[MI].Items[II].Caption) + 10;
    If Menus[MI].Items[II].Shortcut <> '' Then
     Need := Need + 16 + TextWidth(Menus[MI].Items[II].Shortcut);
    If Need > Menus[MI].Width Then Menus[MI].Width := Need;
   End;
  End;
 End;
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

Procedure PMByte(Var M: TPaintMetadata; Index,B: Integer);
Begin
 If Length(M.Values[Index])<255 Then M.Values[Index]:=M.Values[Index]+Chr(B)
 Else M.Limited:=True;
End;

Procedure InitImage;
Const
 VGA_R: Array[0..15] of Byte =
   (  0,   0,   0,   0, 168, 168, 168, 168,  84,  84,  84,  84, 252, 252, 252, 252);
 VGA_G: Array[0..15] of Byte =
   (  0,   0, 168, 168,   0,   0,  84, 168,  84,  84, 252, 252,  84,  84, 252, 252);
 VGA_B: Array[0..15] of Byte =
   (  0, 168,   0, 168,   0, 168,   0, 168,  84, 252,  84, 252,  84, 252,  84, 252);
Var
 I: Integer;
Begin
 ImageBuffer.Width := 640;
 ImageBuffer.Height := 480;
 ImageBuffer.BitDepth := 8;
 ImageBuffer.HasTransparency := False;
 ImageBuffer.Modified := False;
 ImageBuffer.FileName := '';
 ImageBuffer.Format := FMT_BMP;
 FillChar(ImageBuffer.Metadata,SizeOf(TPaintMetadata),0);
 ImageBuffer.HasHotspot:=False;
 ImageBuffer.HotspotX:=0; ImageBuffer.HotspotY:=0;
 ImageBuffer.CursorImages:=0;

 { Initialiser la palette : 16 couleurs VGA standard puis degrade de gris.
   Sans cela ImageBuffer.Palette reste a zero -> Save* ecrit une palette
   tout-noire et l'image rechargee parait entierement noire. }
 For I := 0 to 15 do Begin
  ImageBuffer.Palette[I].R := VGA_R[I];
  ImageBuffer.Palette[I].G := VGA_G[I];
  ImageBuffer.Palette[I].B := VGA_B[I];
  ImageBuffer.Palette[I].A := 255;
 End;
 For I := 16 to 255 do Begin
  ImageBuffer.Palette[I].R := Byte(I);
  ImageBuffer.Palette[I].G := Byte(I);
  ImageBuffer.Palette[I].B := Byte(I);
  ImageBuffer.Palette[I].A := 255;
 End;

 CanvasX := TOOLBAR_WIDTH + 5;
 CanvasY := MENUBAR_HEIGHT + 5;
 CanvasWidth := ScreenWidth - TOOLBAR_WIDTH - 10;
 CanvasHeight := ScreenHeight - MENUBAR_HEIGHT - STATUSBAR_HEIGHT - COLORBAR_HEIGHT - 10;

 ZoomLevel := 100;
 ZOriginX:=0; ZOriginY:=0;
End;

Procedure InitTools;
Begin
 CurrentTool := TOOL_PENCIL;
 BrushSize := 3;
 LineWidth := 1;
 FillStyle := 0;
End;

Procedure InitHistory;
Begin
 UndoList := Nil;
 RedoList := Nil;
 UndoCount := 0;
 RedoCount := 0;
 MaxUndoLevels := 20;
End;

{ Procédures de dessin de l'interface }

Procedure DrawMenuBar;
Var
 I: Integer;
 X: Integer;
Begin
 { Fond de la barre de menu }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, 0, ScreenWidth - 1, MENUBAR_HEIGHT - 1);
 SetColor(DarkGray);
 Line(0, MENUBAR_HEIGHT - 1, ScreenWidth - 1, MENUBAR_HEIGHT - 1);

 { Dessiner les titres des menus }
 SetColor(Black);
 X := 5;
 For I := 0 to 5 do Begin
  Menus[I].X := X;
  If (MenuActive) and (ActiveMenu = I) Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(X - 2, 2, X + TextWidth(Menus[I].Title) + 2, MENUBAR_HEIGHT - 3);
   SetColor(White);
  End Else Begin
   SetColor(Black);
  End;
  OutTextXY(X, 5, Menus[I].Title);
  X := X + TextWidth(Menus[I].Title) + 15;
 End;
End;

Procedure DrawToolIcon(X, Y: Integer; ToolIndex: Byte; Selected: Boolean);
Var
 IconSize: Integer;
Begin
 IconSize := 20;

 { Fond du bouton }
 If Selected Then Begin
  SetFillStyle(SolidFill, DarkGray);
  Bar(X, Y, X + IconSize, Y + IconSize);
  SetColor(White);
 End Else Begin
  SetFillStyle(SolidFill, LightGray);
  Bar(X, Y, X + IconSize, Y + IconSize);
  SetColor(Black);
 End;

 { Dessiner l'icône selon l'outil }
 Case ToolIndex of
  TOOL_SELECT: Begin
   { Rectangle de sélection en pointillés }
   SetLineStyle(DottedLn, 0, NormWidth);
   Rectangle(X + 4, Y + 4, X + IconSize - 4, Y + IconSize - 4);
   SetLineStyle(SolidLn, 0, NormWidth);
  End;
  TOOL_ERASER: Begin
   { Gomme }
   SetFillStyle(SolidFill, White);
   Bar(X + 5, Y + 8, X + IconSize - 5, Y + IconSize - 4);
   Rectangle(X + 5, Y + 8, X + IconSize - 5, Y + IconSize - 4);
  End;
  TOOL_FILL: Begin
   { Pot de peinture }
   Arc(X + 10, Y + 12, 0, 180, 5);
   Line(X + 5, Y + 12, X + 5, Y + 16);
   Line(X + 15, Y + 12, X + 15, Y + 16);
   Line(X + 5, Y + 16, X + 15, Y + 16);
  End;
  TOOL_PICKER: Begin
   { Pipette }
   Line(X + 6, Y + 6, X + 14, Y + 14);
   Circle(X + 14, Y + 14, 3);
  End;
  TOOL_MAGNIFY: Begin
   { Loupe }
   Circle(X + 10, Y + 9, 5);
   Line(X + 13, Y + 13, X + 17, Y + 17);
  End;
  TOOL_PENCIL: Begin
   { Crayon }
   Line(X + 5, Y + 15, X + 15, Y + 5);
   Line(X + 5, Y + 15, X + 7, Y + 17);
   Line(X + 7, Y + 17, X + 17, Y + 7);
   Line(X + 15, Y + 5, X + 17, Y + 7);
  End;
  TOOL_BRUSH: Begin
   { Pinceau }
   SetFillStyle(SolidFill, CurrentColor);
   FillEllipse(X + 10, Y + 10, 5, 3);
   Line(X + 10, Y + 13, X + 10, Y + 18);
  End;
  TOOL_AIRBRUSH: Begin
   { Aérographe - points dispersés }
   PutPixel(X + 8, Y + 8, CurrentColor);
   PutPixel(X + 10, Y + 7, CurrentColor);
   PutPixel(X + 12, Y + 9, CurrentColor);
   PutPixel(X + 9, Y + 11, CurrentColor);
   PutPixel(X + 11, Y + 12, CurrentColor);
   PutPixel(X + 13, Y + 10, CurrentColor);
   PutPixel(X + 7, Y + 10, CurrentColor);
  End;
  TOOL_TEXT: Begin
   { Lettre A }
   OutTextXY(X + 6, Y + 5, 'A');
  End;
  TOOL_LINE: Begin
   { Ligne }
   Line(X + 5, Y + 15, X + 15, Y + 5);
  End;
  TOOL_CURVE: Begin
   { Courbe }
   Arc(X + 10, Y + 15, 0, 180, 7);
  End;
  TOOL_RECT: Begin
   { Rectangle }
   Rectangle(X + 4, Y + 6, X + 16, Y + 14);
  End;
  TOOL_POLYGON: Begin
   { Polygone }
   Line(X + 10, Y + 4, X + 16, Y + 10);
   Line(X + 16, Y + 10, X + 13, Y + 16);
   Line(X + 13, Y + 16, X + 7, Y + 16);
   Line(X + 7, Y + 16, X + 4, Y + 10);
   Line(X + 4, Y + 10, X + 10, Y + 4);
  End;
  TOOL_ELLIPSE: Begin
   { Ellipse }
   Ellipse(X + 10, Y + 10, 0, 360, 6, 4);
  End;
  TOOL_ROUNDRECT: Begin
   { Rectangle arrondi }
   DrawRoundedRect(X + 4, Y + 6, X + 16, Y + 14, 4, 4);
  End;
 End;

 { Bordure du bouton }
 If Selected Then Begin
  SetColor(White);
  Line(X, Y, X + IconSize, Y);
  Line(X, Y, X, Y + IconSize);
  SetColor(DarkGray);
  Line(X + IconSize, Y, X + IconSize, Y + IconSize);
  Line(X, Y + IconSize, X + IconSize, Y + IconSize);
 End Else Begin
  SetColor(White);
  Line(X, Y, X + IconSize, Y);
  Line(X, Y, X, Y + IconSize);
  SetColor(DarkGray);
  Line(X + IconSize, Y, X + IconSize, Y + IconSize);
  Line(X, Y + IconSize, X + IconSize, Y + IconSize);
 End;
End;

{ Infobulles BGI : chaque icone possede son propre texte. Les pixels de
  l'ecran sont sauvegardes, sans toucher aux pixels du document/historique. }
Function ToolTipHit(X,Y: Integer): Integer;
Var Col,Row,Left,Top,Index: Integer;
Begin
 ToolTipHit:=-1;
 If (X<5) Or (Y<MENUBAR_HEIGHT+5) Then Exit;
 Col:=(X-5) Div 23; Row:=(Y-MENUBAR_HEIGHT-5) Div 23;
 If (Col>1) Or (Row>7) Then Exit;
 Left:=5+Col*23; Top:=MENUBAR_HEIGHT+5+Row*23; Index:=Row*2+Col;
 If (Index>14) Or (X>Left+20) Or (Y>Top+20) Then Exit;
 ToolTipHit:=Index;
End;

Function ToolTipText(Index: Integer): String;
Begin
 Case Index Of
  TOOL_SELECT: ToolTipText:='Selection : delimiter une zone de l''image';
  TOOL_ERASER: ToolTipText:='Gomme : effacer avec la couleur de fond';
  TOOL_FILL: ToolTipText:='Remplissage : colorier une zone fermee';
  TOOL_PICKER: ToolTipText:='Pipette : prelever une couleur de l''image';
  TOOL_MAGNIFY: ToolTipText:='Loupe : agrandir ou reduire la vue';
  TOOL_PENCIL: ToolTipText:='Crayon : dessiner un trait fin a main levee';
  TOOL_BRUSH: ToolTipText:='Pinceau : peindre avec la taille choisie';
  TOOL_AIRBRUSH: ToolTipText:='Aerographe : pulveriser des points de couleur';
  TOOL_TEXT: ToolTipText:='Texte : cliquer puis saisir du texte';
  TOOL_LINE: ToolTipText:='Ligne : tracer un segment droit';
  TOOL_CURVE: ToolTipText:='Courbe : tracer une ligne courbe';
  TOOL_POLYGON: ToolTipText:='Polygone : clics = sommets, Entree = fermer';
  TOOL_RECT: ToolTipText:='Rectangle : tracer une forme rectangulaire';
  TOOL_ELLIPSE: ToolTipText:='Ellipse : dessiner un ovale ou un cercle';
  TOOL_ROUNDRECT: ToolTipText:='Rectangle arrondi : tracer des coins arrondis';
  Else ToolTipText:='';
 End;
End;

Function ToolTipClock: LongInt;
Var H,M,S,HS: Word;
Begin
 GetTime(H,M,S,HS); ToolTipClock:=((LongInt(H)*60+M)*60+S)*100+HS;
End;

Procedure HideToolTip;
Begin
 If ToolTipVisible Then Begin
  HideMouse;
  PutImage(ToolTipX,ToolTipY,ToolTipPixels,CopyPut);
  ShowMouse;
  ToolTipVisible:=False;
 End;
End;

Procedure ResetToolTip;
Begin
 HideToolTip; ToolTipCandidate:=-1;
End;

Procedure ShowToolTip(Index: Integer);
Var S: String; W,H,X,Y,PreviousColor: Integer;
    PreviousFill: FillSettingsType; PreviousLine: LineSettingsType;
Begin
 S:=ToolTipText(Index); If S='' Then Exit;
 W:=TextWidth(S)+16; H:=TextHeight(S)+14;
 X:=TOOLBAR_WIDTH+8; Y:=MENUBAR_HEIGHT+5+(Index Div 2)*23+22;
 X:=Max(0,Min(X,ScreenWidth-W-4)); Y:=Max(0,Min(Y,ScreenHeight-H-4));
 If ImageSize(X,Y,X+W+3,Y+H+3)>SizeOf(ToolTipPixels) Then Exit;
 HideMouse;
 GetImage(X,Y,X+W+3,Y+H+3,ToolTipPixels);
 PreviousColor:=GetColor; GetFillSettings(PreviousFill); GetLineSettings(PreviousLine);
 SetWriteMode(CopyPut); SetLineStyle(SolidLn,0,NormWidth);
 SetFillStyle(SolidFill,DarkGray); Bar(X+3,Y+3,X+W+3,Y+H+3);
 SetFillStyle(SolidFill,Yellow); Bar(X,Y,X+W,Y+H);
 SetColor(Black); Rectangle(X,Y,X+W,Y+H); OutTextXY(X+8,Y+7,S);
 SetColor(PreviousColor); SetFillStyle(PreviousFill.Pattern,PreviousFill.Color);
 SetLineStyle(PreviousLine.LineStyle,PreviousLine.Pattern,PreviousLine.Thickness);
 ToolTipX:=X; ToolTipY:=Y; ToolTipVisible:=True;
 ShowMouse;
End;

Procedure UpdateToolTip;
Var Index: Integer; Now,Elapsed: LongInt;
Begin
 Index:=-1;
 If Not MenuActive And Not Drawing And Not TextInsertMode And (PolygonCount=0) And (MouseButtons=0) Then
  Index:=ToolTipHit(MouseX,MouseY);
 Now:=ToolTipClock;
 If Index<>ToolTipCandidate Then Begin
  HideToolTip; ToolTipCandidate:=Index; ToolTipStarted:=Now;
 End;
 If Index<0 Then Exit;
 Elapsed:=Now-ToolTipStarted; If Elapsed<0 Then Inc(Elapsed,8640000);
 If Not ToolTipVisible And (Elapsed>=50) Then ShowToolTip(Index);
End;


Procedure DrawToolbar;
Var
 I: Integer;
 X, Y: Integer;
 ToolsPerRow: Integer;
Begin
 { Fond de la barre d'outils }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, MENUBAR_HEIGHT, TOOLBAR_WIDTH - 1, ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT - 1);

 { Bordure droite }
 SetColor(DarkGray);
 Line(TOOLBAR_WIDTH - 1, MENUBAR_HEIGHT, TOOLBAR_WIDTH - 1, ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT - 1);

 { Dessiner les icônes d'outils }
 ToolsPerRow := 2;
 For I := 0 to 14 do Begin
  X := 5 + (I mod ToolsPerRow) * 23;
  Y := MENUBAR_HEIGHT + 5 + (I div ToolsPerRow) * 23;
  DrawToolIcon(X, Y, I, I = CurrentTool);
 End;

 { Section de taille de pinceau }
 Y := MENUBAR_HEIGHT + 185;
 SetColor(Black);
 OutTextXY(5, Y, 'Taille:');
 SetFillStyle(SolidFill, White);
 Bar(5, Y + 12, 45, Y + 32);
 SetColor(Black);
 Rectangle(5, Y + 12, 45, Y + 32);
 OutTextXY(20, Y + 17, IntToStr(BrushSize));
End;

Procedure DrawColorPalette;
Var
 I: Integer;
 X, Y: Integer;
 ColorBoxSize: Integer;
 PaletteY: Integer;
Begin
 PaletteY := ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT;
 ColorBoxSize := 16;

 { Fond de la barre de couleurs }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, PaletteY, ScreenWidth - 1, ScreenHeight - STATUSBAR_HEIGHT - 1);

 { Bordure supérieure }
 SetColor(DarkGray);
 Line(0, PaletteY, ScreenWidth - 1, PaletteY);

 { Afficher la couleur actuelle et l'arrière-plan }
 X := 10;
 Y := PaletteY + 5;

 { Couleur d'arrière-plan (en dessous) }
 SetFillStyle(SolidFill, BackgroundColor);
 Bar(X + 8, Y + 8, X + 28, Y + 28);
 SetColor(Black);
 Rectangle(X + 8, Y + 8, X + 28, Y + 28);

 { Couleur de premier plan (au-dessus) }
 SetFillStyle(SolidFill, CurrentColor);
 Bar(X, Y, X + 20, Y + 20);
 SetColor(Black);
 Rectangle(X, Y, X + 20, Y + 20);

 { Palette de couleurs }
 X := 50;
 For I := 0 to 27 do Begin
  SetFillStyle(SolidFill, StandardPalette[I]);
  Bar(X + (I mod 14) * (ColorBoxSize + 2), Y + (I div 14) * (ColorBoxSize + 2),
      X + (I mod 14) * (ColorBoxSize + 2) + ColorBoxSize,
      Y + (I div 14) * (ColorBoxSize + 2) + ColorBoxSize);
  SetColor(Black);
  Rectangle(X + (I mod 14) * (ColorBoxSize + 2), Y + (I div 14) * (ColorBoxSize + 2),
            X + (I mod 14) * (ColorBoxSize + 2) + ColorBoxSize,
            Y + (I div 14) * (ColorBoxSize + 2) + ColorBoxSize);
 End;
End;

Procedure DrawStatusBar;
Var
 StatusY: Integer;
 PosStr: String;
Begin
 StatusY := ScreenHeight - STATUSBAR_HEIGHT;

 { Fond de la barre d'état }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, StatusY, ScreenWidth - 1, ScreenHeight - 1);

 { Bordure supérieure }
 SetColor(DarkGray);
 Line(0, StatusY, ScreenWidth - 1, StatusY);

 { Afficher les informations }
 SetColor(Black);

 { Position de la souris }
 If (MouseX >= CanvasX) and (MouseX < CanvasX + CanvasWidth) and
    (MouseY >= CanvasY) and (MouseY < CanvasY + CanvasHeight) Then Begin
  PosStr := IntToStr(ZScreenX(MouseX)) + ', ' + IntToStr(ZScreenY(MouseY));
  OutTextXY(10, StatusY + 5, PosStr);
 End;

 { Taille de l'image }
 PosStr := IntToStr(ImageBuffer.Width) + ' x ' + IntToStr(ImageBuffer.Height) + ' px';
 OutTextXY(150, StatusY + 5, PosStr);

 { Zoom }
 PosStr := IntToStr(ZoomLevel) + '%';
 OutTextXY(300, StatusY + 5, PosStr);

 { Nom du fichier ou état modifié }
 If ImageBuffer.FileName <> '' Then
  OutTextXY(400, StatusY + 5, ImageBuffer.FileName)
 Else
  OutTextXY(400, StatusY + 5, 'Sans titre');

 If ImageBuffer.Modified Then
  OutTextXY(550, StatusY + 5, '*');
End;

Procedure DrawCanvas;
Var
 X,Y,SX,SY,W,H: Integer;
 P: PByte;
Begin
 ZClampView;
 SetFillStyle(SolidFill,DarkGray);
 Bar(CanvasX,CanvasY,CanvasX+CanvasWidth-1,CanvasY+CanvasHeight-1);
 W:=ZDisplayWidth; H:=ZDisplayHeight;
 If CanvasImage<>Nil Then
  For Y:=0 To H-1 Do Begin
   SY:=ZOriginY+(LongInt(Y)*100) Div ZoomLevel;
   P:=CanvasImage; Inc(P,LongInt(SY)*CanvasImageW);
   For X:=0 To W-1 Do Begin
    SX:=ZOriginX+(LongInt(X)*100) Div ZoomLevel;
    PutPixel(CanvasX+X,CanvasY+Y,PByte(PtrUInt(P)+PtrUInt(SX))^);
   End;
  End;
 SetColor(DarkGray);
 Rectangle(CanvasX-1,CanvasY-1,CanvasX+W,CanvasY+H);
 { Les pixels sont agrandis sans interpolation : le zoom ne change pas
   les donnees de l'image et n'est pas un redimensionnement. }
End;


Procedure DrawSelection;
Const
 AntsPatterns: Array[0..3] of Word = ($CCCC, $9999, $3333, $6666);
Var
 Previous: ViewPortType;
 L,T,R,B: Integer;
Begin
 If SelectionActive And (Not AntsValid) Then Begin
  { Trace en XOR avec un motif rotatif pour effet "marching ants". }
  ZBeginView(Previous);
  L:=ZViewX(SelectionRect.Left); T:=ZViewY(SelectionRect.Top);
  R:=Max(L,ZViewX(SelectionRect.Right+1)-1);
  B:=Max(T,ZViewY(SelectionRect.Bottom+1)-1);
  SetWriteMode(XORPut);
  SetColor(White);
  SetLineStyle(UserBitLn, AntsPatterns[AntsPhase and 3], NormWidth);
  Rectangle(L,T,R,B);
  SetLineStyle(SolidLn, 0, NormWidth);
  SetWriteMode(CopyPut);
  ZEndView(Previous);
  AntsValid := True;
 End;
End;

Procedure EraseSelection;
Const
 AntsPatterns: Array[0..3] of Word = ($CCCC, $9999, $3333, $6666);
Var
 Previous: ViewPortType;
 L,T,R,B: Integer;
Begin
 If SelectionActive And AntsValid Then Begin
  { Re-applique le meme motif XOR -> efface les pixels precedents. }
  ZBeginView(Previous);
  L:=ZViewX(SelectionRect.Left); T:=ZViewY(SelectionRect.Top);
  R:=Max(L,ZViewX(SelectionRect.Right+1)-1);
  B:=Max(T,ZViewY(SelectionRect.Bottom+1)-1);
  SetWriteMode(XORPut);
  SetColor(White);
  SetLineStyle(UserBitLn, AntsPatterns[AntsPhase and 3], NormWidth);
  Rectangle(L,T,R,B);
  SetLineStyle(SolidLn, 0, NormWidth);
  SetWriteMode(CopyPut);
  ZEndView(Previous);
  AntsValid := False;
 End;
End;

Procedure ToggleAnts;
{ Anime le contour de la selection. Efface l'ancien motif XOR (meme phase),
  fait progresser la phase, puis redessine. }
Begin
 If Not SelectionActive Then Exit;
 EraseSelection;
 AntsPhase := (AntsPhase + 1) and 3;
 DrawSelection;
End;

Procedure XorRubberRect(L, T, R, B: Integer);
{ Trace un rectangle en XOR : un second appel avec les memes coordonnees
  efface exactement le precedent. }
Var Previous: ViewPortType;
Begin
 ZBeginView(Previous);
 L:=ZViewX(L); R:=ZViewX(R); T:=ZViewY(T); B:=ZViewY(B);
 SetWriteMode(XORPut);
 SetColor(White);
 SetLineStyle(DottedLn, 0, NormWidth);
 Rectangle(L, T, R, B);
 SetLineStyle(SolidLn, 0, NormWidth);
 SetWriteMode(CopyPut);
 ZEndView(Previous);
End;

Procedure XorEllipsePreview(CX, CY, RX, RY: Integer);
{ Trace une ellipse d'apercu en XOR + DottedLn en l'approximant par une
  polyligne de N segments. On utilise Line() du BGI qui, contrairement a
  Ellipse(), respecte SetWriteMode(XORPut) et SetLineStyle(DottedLn) :
  un second appel avec les memes parametres efface exactement le precedent
  (pas de GetPixel/PutPixel, donc pas de corruption par le curseur souris). }
Const
 PiOver180 = 3.14159265358979 / 180.0;
Var
 I, N: Integer;
 Step: Integer;
 X1, Y1, X2, Y2: Integer;
 Theta: Real;
Begin
 If (RX <= 0) or (RY <= 0) Then Exit;
 { Densite de segments proportionnelle au perimetre approximatif. }
 N := (RX + RY) Div 2;
 If N < 16 Then N := 16;
 If N > 72 Then N := 72;
 { S'assurer que N divise 360 sans reste pour fermer proprement. }
 Step := 360 Div N;
 If Step < 5 Then Step := 5;
 X1 := CX + RX;
 Y1 := CY;
 I := Step;
 While I <= 360 Do Begin
  Theta := I * PiOver180;
  X2 := CX + Round(RX * Cos(Theta));
  Y2 := CY + Round(RY * Sin(Theta));
  Line(X1, Y1, X2, Y2);
  X1 := X2;
  Y1 := Y2;
  Inc(I, Step);
 End;
 { Fermer le contour vers le point de depart si la division n'a pas boucle. }
 If (X1 <> CX + RX) or (Y1 <> CY) Then
  Line(X1, Y1, CX + RX, CY);
End;

Procedure XorPreviewShape(Tool: Byte; X1, Y1, X2, Y2: Integer);
{ Apercu XOR d'une ligne / rectangle / ellipse / rectarrondi pendant le drag.
  Un second appel avec les memes coordonnees efface le precedent.
  Le contour est en pointilles (DottedLn) pour un rendu "marching ants"
  plutot qu'un trait blanc plein. }
Var
 CX, CY, RX, RY: Integer;
 Previous: ViewPortType;
Begin
 ZBeginView(Previous);
 X1:=ZViewX(X1); X2:=ZViewX(X2); Y1:=ZViewY(Y1); Y2:=ZViewY(Y2);
 SetWriteMode(XORPut);
 SetColor(White);
 SetLineStyle(DottedLn, 0, NormWidth);
 Case Tool of
  TOOL_LINE: Line(X1, Y1, X2, Y2);
  TOOL_RECT: Rectangle(X1, Y1, X2, Y2);
  TOOL_ROUNDRECT: Rectangle(X1, Y1, X2, Y2);
  TOOL_ELLIPSE: Begin
   CX := (X1 + X2) Div 2;
   CY := (Y1 + Y2) Div 2;
   RX := Abs(X2 - X1) Div 2;
   RY := Abs(Y2 - Y1) Div 2;
   XorEllipsePreview(CX, CY, RX, RY);
  End;
 End;
 SetLineStyle(SolidLn, 0, NormWidth);
 SetWriteMode(CopyPut);
 ZEndView(Previous);
End;

Procedure DrawMenu(MenuIndex: Integer);
Var
 I: Integer;
 X, Y, W, H: Integer;
 ItemHeight: Integer;
Begin
 If (MenuIndex < 0) or (MenuIndex > 5) Then Exit;

 ItemHeight := 18;
 X := Menus[MenuIndex].X;
 Y := MENUBAR_HEIGHT;
 W := Menus[MenuIndex].Width;
 H := Menus[MenuIndex].ItemCount * ItemHeight + 4;

 { Fond du menu }
 SetFillStyle(SolidFill, LightGray);
 Bar(X, Y, X + W, Y + H);

 { Bordure }
 SetColor(White);
 Line(X, Y, X + W, Y);
 Line(X, Y, X, Y + H);
 SetColor(DarkGray);
 Line(X + W, Y, X + W, Y + H);
 Line(X, Y + H, X + W, Y + H);
 SetColor(Black);
 Line(X + W + 1, Y + 1, X + W + 1, Y + H + 1);
 Line(X + 1, Y + H + 1, X + W + 1, Y + H + 1);

 { Éléments du menu }
 For I := 0 to Menus[MenuIndex].ItemCount - 1 do Begin
  If Menus[MenuIndex].Items[I].Separator Then Begin
   SetColor(DarkGray);
   Line(X + 2, Y + 2 + I * ItemHeight + ItemHeight div 2,
        X + W - 2, Y + 2 + I * ItemHeight + ItemHeight div 2);
  End Else Begin
   { Fond de l'élément sélectionné }
   If (ActiveMenuItem = I) Then Begin
    SetFillStyle(SolidFill, Blue);
    Bar(X + 2, Y + 2 + I * ItemHeight, X + W - 2, Y + 2 + (I + 1) * ItemHeight);
    SetColor(White);
   End Else Begin
    If Menus[MenuIndex].Items[I].Enabled Then
     SetColor(Black)
    Else
     SetColor(DarkGray);
   End;

   { Coche si activé }
   If Menus[MenuIndex].Items[I].Checked Then
    OutTextXY(X + 5, Y + 4 + I * ItemHeight, #251);

   { Texte de l'élément }
   OutTextXY(X + 20, Y + 4 + I * ItemHeight, Menus[MenuIndex].Items[I].Caption);

   { Raccourci clavier }
   If Menus[MenuIndex].Items[I].Shortcut <> '' Then
    OutTextXY(X + W - TextWidth(Menus[MenuIndex].Items[I].Shortcut) - 10,
              Y + 4 + I * ItemHeight, Menus[MenuIndex].Items[I].Shortcut);
  End;
 End;
End;

Procedure PolygonPreview; Forward;

Procedure RedrawInterface;
Begin
 { Le redessin complet remplace aussi toute infobulle affichee. }
 ToolTipVisible:=False; ToolTipCandidate:=-1;
 PolygonOverlayValid:=False;
 {$IFDEF FPC}
 HideMouse;
 {$ELSE}
 HideMouse;
 {$ENDIF}

 { Effacer l'écran }
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, 0, ScreenWidth - 1, ScreenHeight - 1);
 { L'ecran est vide : les anciennes "marching ants" XOR sont effacees. }
 AntsValid := False;
 PreviewValid := False;
 RubberValid := False;

 { Dessiner les éléments de l'interface }
 DrawMenuBar;
 DrawToolbar;
 DrawCanvas;
 DrawColorPalette;
 DrawStatusBar;
 DrawSelection;
 PolygonPreview;

 { Dessiner le menu actif si nécessaire }
 If MenuActive Then
  DrawMenu(ActiveMenu);

 {$IFDEF FPC}
 ShowMouse;
 {$ELSE}
 ShowMouse;
 {$ENDIF}
End;

{ Procédures de gestion des fichiers image }

Function LoadBMP(FileName: String): Boolean;
{ Couleurs VGA standard 0..15 en RGB 0..255 (palette EGA/VGA classique). }
Const
 VGA_R: Array[0..15] of Byte =
   (  0,   0,   0,   0, 168, 168, 168, 168,  84,  84,  84,  84, 252, 252, 252, 252);
 VGA_G: Array[0..15] of Byte =
   (  0,   0, 168, 168,   0,   0,  84, 168,  84,  84, 252, 252,  84,  84, 252, 252);
 VGA_B: Array[0..15] of Byte =
   (  0, 168,   0, 168,   0, 168,   0, 168,  84, 252,  84, 252,  84, 252,  84, 252);
Var
 F: File;
 FileHeader: TBMPFileHeader;
 InfoHeader: TBMPInfoHeader;
 BytesRead: Word;
 PaletteEntries: Integer;
 BMPPalette: Array[0..255] of TRGBQuad;
 RowBuffer: Array[0..12287] of Byte;
 RowSize, PadBytes: Integer;
 X, Y, SrcY: Integer;
 PixelColor: Byte;
 ByteVal: Byte;
 BitPos: Integer;
 TopDown: Boolean;
 PalRemap: Array[0..255] of Byte;
 I, Best, NextColor: Integer;
 DR, DG, DB, Dist, BestDist: LongInt;
Begin
 LoadBMP := False;

 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire l'en-tête du fichier }
 BlockRead(F, FileHeader, SizeOf(TBMPFileHeader), BytesRead);
 If (BytesRead <> SizeOf(TBMPFileHeader)) or (FileHeader.bfType <> BMP_SIGNATURE) Then Begin
  Close(F);
  Exit;
 End;

 { Lire l'en-tête d'information }
 BlockRead(F, InfoHeader, SizeOf(TBMPInfoHeader), BytesRead);
 If BytesRead <> SizeOf(TBMPInfoHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Vérifier si l'image est en mode top-down (hauteur négative) }
 TopDown := InfoHeader.biHeight < 0;

 { Mettre à jour les informations de l'image }
 ImageBuffer.Width := InfoHeader.biWidth;
 ImageBuffer.Height := Abs(InfoHeader.biHeight);
 ImageBuffer.BitDepth := InfoHeader.biBitCount;
 ImageBuffer.FileName := FileName;
 ImageBuffer.Format := FMT_BMP;
 ImageBuffer.Modified := False;

 { (Re)allouer le buffer de pixels du canvas pour la persistance d'affichage }
 If CanvasImage <> Nil Then FreeMem(CanvasImage, CanvasImageW * CanvasImageH);
 CanvasImageW := ImageBuffer.Width;
 CanvasImageH := ImageBuffer.Height;
 GetMem(CanvasImage, CanvasImageW * CanvasImageH);
 FillChar(CanvasImage^, CanvasImageW * CanvasImageH, White);

 { Calculer la taille de la ligne avec padding (alignement 4 octets) }
 RowSize := ((InfoHeader.biWidth * InfoHeader.biBitCount + 31) div 32) * 4;
 PadBytes := RowSize - ((InfoHeader.biWidth * InfoHeader.biBitCount + 7) div 8);

 { Lire la palette si nécessaire (images <= 8 bits) }
 If InfoHeader.biBitCount <= 8 Then Begin
  If InfoHeader.biClrUsed > 0 Then
   PaletteEntries := InfoHeader.biClrUsed
  Else
   PaletteEntries := 1 shl InfoHeader.biBitCount;

  If (PaletteEntries < 1) Or (PaletteEntries > 256) Then Begin
   Close(F);
   Exit;
  End;
  BlockRead(F, BMPPalette, PaletteEntries * 4, BytesRead);
  If BytesRead <> PaletteEntries * 4 Then Begin
   Close(F);
   Exit;
  End;

  { Reserver les 16 couleurs de l'interface. En mode 256 couleurs,
    conserver les couleurs BMP exactes dans les autres registres, au lieu
    de perdre les couleurs personnalisees lors de la reouverture. }
  For I := 0 To 15 Do Begin
   ImageBuffer.Palette[I].R := VGA_R[I];
   ImageBuffer.Palette[I].G := VGA_G[I];
   ImageBuffer.Palette[I].B := VGA_B[I];
   ImageBuffer.Palette[I].A := 255;
  End;
  NextColor := 16;
  For X := 0 To PaletteEntries-1 Do Begin
   Best := 0;
   BestDist := MaxLongInt;
   For I := 0 To NextColor-1 Do Begin
    DR := LongInt(BMPPalette[X].Red)-ImageBuffer.Palette[I].R;
    DG := LongInt(BMPPalette[X].Green)-ImageBuffer.Palette[I].G;
    DB := LongInt(BMPPalette[X].Blue)-ImageBuffer.Palette[I].B;
    Dist := DR*DR+DG*DG+DB*DB;
    If Dist < BestDist Then Begin
     BestDist := Dist;
     Best := I;
    End;
   End;
   If (BestDist <> 0) And (GetMaxColor >= 255) And (NextColor < 256) Then Begin
    Best := NextColor;
    ImageBuffer.Palette[Best].R := BMPPalette[X].Red;
    ImageBuffer.Palette[Best].G := BMPPalette[X].Green;
    ImageBuffer.Palette[Best].B := BMPPalette[X].Blue;
    ImageBuffer.Palette[Best].A := 255;
    Inc(NextColor);
   End;
   PalRemap[X] := Byte(Best);
  End;
  For I := 0 To NextColor-1 Do Begin
   {$IFDEF FPC}
   SetRGBPalette(I,ImageBuffer.Palette[I].R,
                   ImageBuffer.Palette[I].G,ImageBuffer.Palette[I].B);
   {$ELSE}
   SetRGBPalette(I,ImageBuffer.Palette[I].R Shr 2,
                   ImageBuffer.Palette[I].G Shr 2,ImageBuffer.Palette[I].B Shr 2);
   {$ENDIF}
  End;
  { Entrees non lues : mapper sur noir par defaut. }
  For X := PaletteEntries to 255 do PalRemap[X] := 0;
 End
 Else Begin
  { Pas de palette indexee : remap identite pour le code partage plus bas. }
  For X := 0 to 255 do PalRemap[X] := Byte(X);
 End;

 { Se positionner au début des données de l'image }
 Seek(F, FileHeader.bfOffBits);

 { Effacer la zone de dessin }
 SetFillStyle(SolidFill, White);
 Bar(CanvasX, CanvasY, CanvasX + CanvasWidth - 1, CanvasY + CanvasHeight - 1);

 { Lire les données de l'image ligne par ligne }
 For Y := 0 to ImageBuffer.Height - 1 do Begin
  { Calculer la ligne source (BMP stocke de bas en haut par défaut) }
  If TopDown Then
   SrcY := Y
  Else
   SrcY := ImageBuffer.Height - 1 - Y;

  BlockRead(F, RowBuffer, RowSize, BytesRead);
  If BytesRead <> RowSize Then Begin
   Close(F);
   Exit;
  End;

  { Dessiner les pixels de cette ligne }
  For X := 0 to ImageBuffer.Width - 1 do Begin
   Begin
    Case InfoHeader.biBitCount of
     1: Begin
      ByteVal := RowBuffer[X div 8];
      BitPos := 7 - (X mod 8);
      PixelColor := PalRemap[(ByteVal shr BitPos) and 1];
     End;
     4: Begin
      ByteVal := RowBuffer[X div 2];
      If (X mod 2) = 0 Then
       PixelColor := PalRemap[(ByteVal shr 4) and $0F]
      Else
       PixelColor := PalRemap[ByteVal and $0F];
     End;
     8: Begin
      PixelColor := PalRemap[RowBuffer[X]];
     End;
     24: Begin
      { Pour les images 24 bits, trouver la couleur la plus proche }
      PixelColor := (RowBuffer[X * 3 + 2] shr 5) shl 5 +
                    (RowBuffer[X * 3 + 1] shr 5) shl 2 +
                    (RowBuffer[X * 3] shr 6);
     End;
     Else
      PixelColor := 0;
    End;
    If (X<CanvasWidth) And (SrcY<CanvasHeight) Then
     PutPixel(CanvasX+X,CanvasY+SrcY,PixelColor);
    { Mémoriser le pixel pour pouvoir redessiner le canvas après un menu. }
    If (CanvasImage <> Nil) and (X < CanvasImageW) and (SrcY < CanvasImageH) Then
     PByte(PtrUInt(CanvasImage) + PtrUInt(SrcY) * PtrUInt(CanvasImageW) + PtrUInt(X))^ := PixelColor;
   End;
  End;
 End;

 Close(F);
 LoadBMP := True;
End;

{ Decodeur GIF87a/GIF89a integre, conforme a la structure GIF89a et a son
  annexe F : LZW a codes de 3..12 bits, Clear, EOI et dictionnaire plein.
  Le document importe la premiere image d'un GIF anime, comme image fixe.
  Tout est prepare hors du document ; aucune mutation en cas de refus. }
Type
 TGFBytes = Array[0..134217727] Of Byte;
 PGFBytes = ^TGFBytes;
 TGFState = Record
  Data: PGFBytes;
  Size,Position: LongInt;
  Bad,HaveImage,HaveGlobal,Transparent: Boolean;
  Width,Height,GlobalCount,ColorCount,BackgroundIndex,TransparentIndex: Integer;
  GlobalPalette,Colors: TPalette;
  Background: TRGBColor;
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
  Metadata: TPaintMetadata;
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

Procedure GFReadPalette(Var D: TGFState; Var Colors: TPalette; Count: Integer);
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
 If (Signature<>GIF87_SIGNATURE) And (Signature<>GIF89_SIGNATURE) Then Begin D^.Bad:=True; Exit; End;
 D^.Width:=GFWord(D^); D^.Height:=GFWord(D^);
 If (D^.Width<1) Or (D^.Height<1) Or (D^.Width>MAX_IMAGE_WIDTH) Or
    (D^.Height>MAX_IMAGE_HEIGHT) Then Begin D^.Bad:=True; Exit; End;
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

Function GFDistance(Const A,B: TRGBColor): LongInt;
Var R,G,Blue: LongInt;
Begin
 R:=LongInt(A.R)-B.R; G:=LongInt(A.G)-B.G; Blue:=LongInt(A.B)-B.B;
 GFDistance:=R*R+G*G+Blue*Blue;
End;

Procedure GFMakePalette(Var D: TGFState; Var Palette: TPalette;
                        Var Map: Array Of Byte; Var BackgroundSlot: Byte);
Const
 R: Array[0..15] Of Byte = (0,0,0,0,168,168,168,168,84,84,84,84,252,252,252,252);
 G: Array[0..15] Of Byte = (0,0,168,168,0,0,84,168,84,84,252,252,84,84,252,252);
 B: Array[0..15] Of Byte = (0,168,0,168,0,168,0,168,84,252,84,252,84,252,84,252);
Var Counts: Array[0..256] Of LongInt; Done: Array[0..256] Of Boolean;
    I,J,N,Best,Slot,Used: Integer; K,Weight,Dist,BestDist: LongInt; C: TRGBColor;
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
Var D: PGFState; Pixels: PGFBytes; Palette: TPalette; Map: Array[0..255] Of Byte;
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
  If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
  CanvasImage:=PByte(Pixels); Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
  ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
  ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_GIF; ImageBuffer.BitDepth:=8;
  ImageBuffer.HasTransparency:=D^.Transparent; ImageBuffer.TransparentColor:=D^.Background;
  ImageBuffer.Modified:=False; ImageBuffer.Palette:=Palette; ImageBuffer.Metadata:=D^.Metadata;
  For I:=0 To 255 Do Begin
   {$IFDEF FPC}SetRGBPalette(I,Palette[I].R,Palette[I].G,Palette[I].B);
   {$ELSE}SetRGBPalette(I,Palette[I].R Shr 2,Palette[I].G Shr 2,Palette[I].B Shr 2);{$ENDIF}
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
  Metadata: TPaintMetadata;
  AllowShort: Boolean;
  Palette: TPalette;
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
 For I:=0 To 7 Do If D.FileData^[I]<>PNG_SIGNATURE[I] Then Exit;
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
   N:=PNBE(D.FileData,Start); If (N=0) Or (N>MAX_IMAGE_WIDTH) Then Exit; D.Width:=N;
   N:=PNBE(D.FileData,Start+4); If (N=0) Or (N>MAX_IMAGE_HEIGHT) Then Exit; D.Height:=N;
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
 If (D.Width<1) Or (D.Height<1) Or (D.Width>MAX_IMAGE_WIDTH) Or
    (D.Height>MAX_IMAGE_HEIGHT) Or Not (D.Components In [1,3,4]) Or
    (Limit-D.Position<>D.Components*3) Then Begin D.Bad:=True; Exit; End;
 D.Progressive:=Marker=$C2; D.MaxH:=1; D.MaxV:=1; Blocks:=0;
 For I:=0 To D.Components-1 Do With D.Component[I] Do Begin
  ID:=JDByte(D); Spec:=JDByte(D); H:=Spec Shr 4; V:=Spec And 15; TQ:=JDByte(D);
  If (H<1) Or (H>4) Or (V<1) Or (V>4) Or (TQ>3) Then Begin D.Bad:=True; Exit; End;
  For J:=0 To I-1 Do If ID=D.Component[J].ID Then Begin D.Bad:=True; Exit; End;
  Inc(Blocks,H*V); D.MaxH:=Max(D.MaxH,H); D.MaxV:=Max(D.MaxV,V);
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
 VGA_R: Array[0..15] of Byte =
   (  0,   0,   0,   0, 168, 168, 168, 168,  84,  84,  84,  84, 252, 252, 252, 252);
 VGA_G: Array[0..15] of Byte =
   (  0,   0, 168, 168,   0,   0,  84, 168,  84,  84, 252, 252,  84,  84, 252, 252);
 VGA_B: Array[0..15] of Byte =
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
  Palette: TPalette;
  Used,BoxCount: LongInt;
 End;
 PJPQuantizer = ^TJPQuantizer;

Function JPBin(R,G,B: Byte): Word;
Begin
 JPBin:=(Word(R Shr 3) Shl 10) Or (Word(G Shr 3) Shl 5) Or (B Shr 3);
End;

Procedure JPMeasure(Var Q: TJPQuantizer; N: LongInt);
Var I,V,R,G,B: LongInt;
Begin
 With Q.Boxes[N] Do Begin
  LowR:=31; LowG:=31; LowB:=31; HighR:=0; HighG:=0; HighB:=0; Count:=0;
  For I:=First To Last Do Begin
   V:=Q.Bins[I]; R:=V Shr 10; G:=(V Shr 5) And 31; B:=V And 31;
   If R<LowR Then LowR:=R; If R>HighR Then HighR:=R;
   If G<LowG Then LowG:=G; If G>HighG Then HighG:=G;
   If B<LowB Then LowB:=B; If B>HighB Then HighB:=B;
   Inc(Count,Q.Histogram[V]);
  End;
 End;
End;

Function JPAxisValue(V,Axis: LongInt): LongInt;
Begin
 Case Axis Of
  0: JPAxisValue:=V Shr 10;
  1: JPAxisValue:=(V Shr 5) And 31;
  Else JPAxisValue:=V And 31;
 End;
End;

Function JPSplit(Var Q: TJPQuantizer; N: LongInt): Boolean;
Var Axis,Range,I,J,V,Cut,MaxValue: LongInt; Total: LongInt;
    Counts: Array[0..31] Of LongInt; T: Word;
Begin
 JPSplit:=False;
 With Q.Boxes[N] Do Begin
  If First>=Last Then Exit;
  Axis:=0; Range:=HighR-LowR; MaxValue:=HighR;
  If HighG-LowG>Range Then Begin Axis:=1; Range:=HighG-LowG; MaxValue:=HighG; End;
  If HighB-LowB>Range Then Begin Axis:=2; Range:=HighB-LowB; MaxValue:=HighB; End;
  If Range=0 Then Exit;
  FillChar(Counts,SizeOf(Counts),0);
  For I:=First To Last Do Begin
   V:=Q.Bins[I]; Inc(Counts[JPAxisValue(V,Axis)],Q.Histogram[V]);
  End;
  Total:=0; Cut:=0;
  While Cut<MaxValue-1 Do Begin
   Inc(Total,Counts[Cut]);
   If Total>=(Count+1) Div 2 Then Break;
   Inc(Cut);
  End;
  I:=First; J:=Last;
  While I<=J Do Begin
   While (I<=J) And (JPAxisValue(Q.Bins[I],Axis)<=Cut) Do Inc(I);
   While (I<=J) And (JPAxisValue(Q.Bins[J],Axis)>Cut) Do Dec(J);
   If I<J Then Begin T:=Q.Bins[I]; Q.Bins[I]:=Q.Bins[J]; Q.Bins[J]:=T; Inc(I); Dec(J); End;
  End;
  If (I<=First) Or (I>Last) Then Exit;
  Q.Boxes[Q.BoxCount].First:=I; Q.Boxes[Q.BoxCount].Last:=Last;
  Last:=I-1;
 End;
 JPMeasure(Q,N); JPMeasure(Q,Q.BoxCount); Inc(Q.BoxCount);
 JPSplit:=True;
End;

Procedure JPBuildPalette(Var Q: TJPQuantizer; Const Img: TJDImage);
Var X,Y,I,J,N,V,R,G,B,DR,DG,DB,Best,Range: LongInt;
    P: PByte; R8,G8,B8: Byte; Weight,Score,BestScore,SumR,SumG,SumB: Int64;
    Dist,BestDist: LongInt;
Begin
 FillChar(Q,SizeOf(Q),0);
 Q.Palette:=ImageBuffer.Palette;
 For I:=0 To 15 Do Begin
  Q.Palette[I].R:=VGA_R[I]; Q.Palette[I].G:=VGA_G[I];
  Q.Palette[I].B:=VGA_B[I]; Q.Palette[I].A:=255;
 End;
 P:=Img.Pixels;
 For Y:=0 To Img.Height-1 Do For X:=0 To Img.Width-1 Do Begin
  R8:=P^; Inc(P); G8:=P^; Inc(P); B8:=P^; Inc(P);
  V:=JPBin(R8,G8,B8);
  Inc(Q.Histogram[V]);
 End;
 For I:=0 To JPBinCount-1 Do If Q.Histogram[I]>0 Then Begin
  Q.Bins[Q.Used]:=I; Inc(Q.Used);
 End;
 Q.BoxCount:=1; Q.Boxes[0].First:=0; Q.Boxes[0].Last:=Q.Used-1;
 JPMeasure(Q,0);
 While Q.BoxCount<240 Do Begin
  Best:=-1; BestScore:=-1;
  For I:=0 To Q.BoxCount-1 Do With Q.Boxes[I] Do Begin
   Range:=Max(HighR-LowR,Max(HighG-LowG,HighB-LowB));
   If (First<Last) And (Range>0) Then Begin
    Score:=Int64(Range)*Range*Count;
    If Score>BestScore Then Begin BestScore:=Score; Best:=I; End;
   End;
  End;
  If Best<0 Then Break;
  If Not JPSplit(Q,Best) Then Break;
 End;
 For N:=0 To Q.BoxCount-1 Do Begin
  SumR:=0; SumG:=0; SumB:=0; Weight:=Q.Boxes[N].Count;
  For I:=Q.Boxes[N].First To Q.Boxes[N].Last Do Begin
   V:=Q.Bins[I];
   SumR:=SumR+Int64((V Shr 10)*255 Div 31)*Q.Histogram[V];
   SumG:=SumG+Int64(((V Shr 5) And 31)*255 Div 31)*Q.Histogram[V];
   SumB:=SumB+Int64((V And 31)*255 Div 31)*Q.Histogram[V];
  End;
  Q.Palette[N+JPFirstColor].R:=SumR Div Weight;
  Q.Palette[N+JPFirstColor].G:=SumG Div Weight;
  Q.Palette[N+JPFirstColor].B:=SumB Div Weight;
  Q.Palette[N+JPFirstColor].A:=255;
 End;
 { Table de correspondance des couleurs presentes : un seul calcul par
   couleur de l'histogramme plutot que 256 recherches pour chaque pixel. }
 For I:=0 To Q.Used-1 Do Begin
  V:=Q.Bins[I]; R:=(V Shr 10)*255 Div 31;
  G:=((V Shr 5) And 31)*255 Div 31; B:=(V And 31)*255 Div 31;
  Best:=0; BestDist:=MaxLongInt;
  For J:=0 To JPFirstColor+Q.BoxCount-1 Do Begin
   DR:=R-Q.Palette[J].R; DG:=G-Q.Palette[J].G; DB:=B-Q.Palette[J].B;
   Dist:=LongInt(DR)*DR+LongInt(DG)*DG+LongInt(DB)*DB;
   If Dist<BestDist Then Begin BestDist:=Dist; Best:=J; End;
  End;
  Q.Map[V]:=Best;
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
  If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
  CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=Img.Width; CanvasImageH:=Img.Height;
  ImageBuffer.Width:=Img.Width; ImageBuffer.Height:=Img.Height;
  ImageBuffer.BitDepth:=24; ImageBuffer.FileName:=FileName;
  ImageBuffer.Format:=FMT_JPEG; ImageBuffer.HasTransparency:=False;
  ImageBuffer.Modified:=False; ImageBuffer.Palette:=Q^.Palette;
  For I:=0 To 255 Do Begin
   {$IFDEF FPC}
   SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
   {$ELSE}
   SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);
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
   Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255;
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
  If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
  CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
  ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=D^.Depth*D^.Channels;
  ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_PNG; ImageBuffer.Modified:=False;
  ImageBuffer.Palette:=Q^.Palette; ImageBuffer.HasTransparency:=D^.HasTransparency; ImageBuffer.Metadata:=D^.Metadata;
  ImageBuffer.TransparentColor.R:=255; ImageBuffer.TransparentColor.G:=255;
  ImageBuffer.TransparentColor.B:=255; ImageBuffer.TransparentColor.A:=0;
  For I:=0 To 255 Do Begin
   {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
   {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
   Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255;
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
  If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
  CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
  ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=D^.Depth*D^.Channels;
  ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_APNG; ImageBuffer.Modified:=False;
  ImageBuffer.Palette:=Q^.Palette; ImageBuffer.HasTransparency:=D^.HasTransparency; ImageBuffer.Metadata:=D^.Metadata;
  ImageBuffer.TransparentColor.R:=255; ImageBuffer.TransparentColor.G:=255;
  ImageBuffer.TransparentColor.B:=255; ImageBuffer.TransparentColor.A:=0;
  For I:=0 To 255 Do Begin
   {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
   {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
 If (Length(S)>2) And (Copy(UpperCase(S),1,2)='0X') Then Begin Base:=16; Start:=3; End
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
     If (Value<1) Or (Value>MAX_IMAGE_WIDTH) Then Exit;
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
   If (Width<1) Or (Height<1) Or (Width>MAX_IMAGE_WIDTH) Or (Height>MAX_IMAGE_HEIGHT) Then Exit;
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
    Pixels,Dest,Source: PByte; RGB: PByte; Q: PJPQuantizer; Palette: TPalette;
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
     For J:=0 To 15 Do Begin Palette[J].R:=VGA_R[J]; Palette[J].G:=VGA_G[J]; Palette[J].B:=VGA_B[J]; Palette[J].A:=255; End;
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
      If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
      CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=W; CanvasImageH:=H;
      ImageBuffer.Width:=W; ImageBuffer.Height:=H; ImageBuffer.BitDepth:=Mode;
      ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_XBM; ImageBuffer.Modified:=False;
      ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0);
      ImageBuffer.Palette:=Palette;
      For J:=0 To 255 Do Begin
       {$IFDEF FPC}SetRGBPalette(J,Palette[J].R,Palette[J].G,Palette[J].B);
       {$ELSE}SetRGBPalette(J,Palette[J].R Shr 2,Palette[J].G Shr 2,Palette[J].B Shr 2);{$ENDIF}
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
  Palette: TPalette;
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
 If (W<1) Or (H<1) Or (W>MAX_IMAGE_WIDTH) Or (H>MAX_IMAGE_HEIGHT) Or
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
 A:=Max(0,A); B:=Min(D.Width-1,B);
 For X:=A To B Do WGPixel(D,X,Y,Index);
End;

Procedure WGPolygon(Var D: TWGState; Closed: Boolean);
Var Cross: Array[0..4095] Of Integer; I,J,K,Y,Low,High,N,T: Integer; V: Int64;
Begin
 If D.Count<2 Then Exit;
 If Closed And (D.FillMode<>0) Then Begin
  Low:=D.Y[0]; High:=Low;
  For I:=1 To D.Count-1 Do Begin Low:=Min(Low,D.Y[I]); High:=Max(High,D.Y[I]); End;
  Low:=Max(0,Low); High:=Min(D.Height-1,High);
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
 Steps:=Min(1024,Max(32,Max(Min(RX,4096),Min(RY,4096))*2));
 D.Count:=Steps;
 For I:=0 To Steps-1 Do Begin A:=2*Pi*I/Steps; D.X[I]:=WGClampCoordinate(CX+Round(RX*Cos(A))); D.Y[I]:=WGClampCoordinate(CY+Round(RY*Sin(A))); End;
 WGPolygon(D,True);
End;

Procedure WGDecodeBitmap(Var D: TWGState; Kind: Integer);
Var Raw: PPNBytes; RowBytes,Total,OutPos,I,Src,Dest: LongInt;
    B,V,Count,X,Y,TX,TY,FX,FY,Angle: Integer; C: TRGBColor;
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
 For I:=0 To 15 Do Begin D.Palette[I].R:=VGA_R[I]; D.Palette[I].G:=VGA_G[I]; D.Palette[I].B:=VGA_B[I]; End;
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
  If (Width>MAX_IMAGE_WIDTH) Or (Height>MAX_IMAGE_HEIGHT) Then Begin
   If Width>=Height Then Begin Height:=Max(1,Round(Height*1024.0/Width)); Width:=1024; End
   Else Begin Width:=Max(1,Round(Width*1024.0/Height)); Height:=1024; End;
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
     If Stop-Start>=4 Then D.Stroke:=Max(1,Min(32,Abs(WGScale(WGWord(D),D.Width,D.PictureWidth))));
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=D^.Depth;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_WPG; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
  Palette: TPalette;
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
   If (D.Width<1) Or (D.Height<1) Or (D.Width>MAX_IMAGE_WIDTH) Or (D.Height>MAX_IMAGE_HEIGHT) Or
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   { Validation terminee : remplacer maintenant le document, jamais avant. }
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=D^.Planes;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_LBM; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=D^.HasTransparency; ImageBuffer.Palette:=Q^.Palette;
   ImageBuffer.TransparentColor.R:=255; ImageBuffer.TransparentColor.G:=255; ImageBuffer.TransparentColor.B:=255; ImageBuffer.TransparentColor.A:=0;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
  If Pos('CloneDRAW BMP2HDR',S)>0 Then D.CloneDRAW:=True;
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
 Val(N1,V1,Code); If (Code<>0) Or (V1<1) Or (V1>MAX_IMAGE_WIDTH) Then Exit;
 Val(N2,V2,Code); If (Code<>0) Or (V2<1) Or (V2>MAX_IMAGE_HEIGHT) Then Exit;
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=24;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_HDR; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
   Inc(Tokens); If Tokens>MAX_IMAGE_WIDTH*2+128 Then Exit;
   If R>MAX_IMAGE_WIDTH-X-Pending Then Exit;
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
   Inc(Y); If Y>MAX_IMAGE_HEIGHT Then Exit;
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
  If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
  CanvasImage:=PByte(D^.Pixels); D^.Pixels:=Nil;
  CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
  ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=1;
  ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_FAX; ImageBuffer.Modified:=False;
  ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0);
  FillChar(ImageBuffer.Palette,SizeOf(ImageBuffer.Palette),0);
  For I:=0 To 15 Do Begin ImageBuffer.Palette[I].R:=VGA_R[I]; ImageBuffer.Palette[I].G:=VGA_G[I]; ImageBuffer.Palette[I].B:=VGA_B[I]; End;
  ImageBuffer.Palette[16].R:=255; ImageBuffer.Palette[16].G:=255; ImageBuffer.Palette[16].B:=255;
  For I:=0 To 255 Do Begin
   ImageBuffer.Palette[I].A:=255;
   {$IFDEF FPC}SetRGBPalette(I,ImageBuffer.Palette[I].R,ImageBuffer.Palette[I].G,ImageBuffer.Palette[I].B);
   {$ELSE}SetRGBPalette(I,ImageBuffer.Palette[I].R Shr 2,ImageBuffer.Palette[I].G Shr 2,ImageBuffer.Palette[I].B Shr 2);{$ENDIF}
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
   If (W<1) Or (W>MAX_IMAGE_WIDTH) Or (H<1) Or (H>MAX_IMAGE_HEIGHT) Then Exit;
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=24;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_EXR; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
  Metadata: TPaintMetadata;
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.OutWidth; CanvasImageH:=D^.OutHeight;
   ImageBuffer.Width:=D^.OutWidth; ImageBuffer.Height:=D^.OutHeight; ImageBuffer.BitDepth:=24;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_DNG; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.OutWidth; CanvasImageH:=D^.OutHeight;
   ImageBuffer.Width:=D^.OutWidth; ImageBuffer.Height:=D^.OutHeight; ImageBuffer.BitDepth:=24;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_CR2; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.OutWidth; CanvasImageH:=D^.OutHeight;
   ImageBuffer.Width:=D^.OutWidth; ImageBuffer.Height:=D^.OutHeight; ImageBuffer.BitDepth:=24;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_ARW; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
 If (Bytes<1) Or (Bytes>MAX_IMAGE_WIDTH) Then Exit; D.Width:=Bytes;
 Bytes:=LongInt(D.Data^[6])+LongInt(D.Data^[7])*256;
 If (Bytes<1) Or (Bytes>MAX_IMAGE_HEIGHT) Then Exit; D.Height:=Bytes;
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
    Else If Index<16 Then Begin R:=VGA_R[Index]; G:=VGA_G[Index]; B:=VGA_B[Index]; End
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=D^.Bits;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_BGX; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
 V:=DSLong(D,16); If (V<1) Or (V>MAX_IMAGE_WIDTH) Then Exit; D.Width:=V;
 V:=DSLong(D,12); If (V<1) Or (V>MAX_IMAGE_HEIGHT) Then Exit; D.Height:=V;
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
  W:=Max(1,W Div 2); H:=Max(1,H Div 2);
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=24;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_DDS; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
    $00280010: Begin If (V<1) Or (V>MAX_IMAGE_HEIGHT) Then Exit; D.Height:=V; End;
    $00280011: Begin If (V<1) Or (V>MAX_IMAGE_WIDTH) Then Exit; D.Width:=V; End;
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height; ImageBuffer.BitDepth:=24;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_DCM; ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
 V:=PMNumber(D,MAX_IMAGE_WIDTH); If D.Bad Or (V=0) Then Exit;
 D.Width:=V;
 V:=PMNumber(D,MAX_IMAGE_HEIGHT); If D.Bad Or (V=0) Then Exit;
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=D^.Channels*D^.BytesPerSample*8;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_PPM;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
  Palette: TPalette;
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=D^.Bits;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_DIB;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
  For J:=0 To 7 Do If D.Data^[Offset+J]<>PNG_SIGNATURE[J]
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=D^.Bits;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_CUR;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=D^.Transparent;
   ImageBuffer.HasHotspot:=True;
   ImageBuffer.HotspotX:=D^.HotX; ImageBuffer.HotspotY:=D^.HotY;
   ImageBuffer.CursorImages:=D^.Count;
   FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0);
   ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
  Palette: TPalette;
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
 If (D.Bits=8) And (D.Planes In [1,3]) Then D.Depth:=D.Bits*D.Planes
 Else If (D.Bits In [1,2,4]) And (D.Planes>=1) And
         (D.Planes*D.Bits<=4) Then D.Depth:=D.Bits*D.Planes
 Else Exit;
 V:=LongInt(PXWord(D,8))-LongInt(PXWord(D,4))+1;
 If (V<1) Or (V>MAX_IMAGE_WIDTH) Then Exit; D.Width:=V;
 V:=LongInt(PXWord(D,10))-LongInt(PXWord(D,6))+1;
 If (V<1) Or (V>MAX_IMAGE_HEIGHT) Then Exit; D.Height:=V;
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
    D.Palette[I].R:=VGA_R[I]; D.Palette[I].G:=VGA_G[I];
    D.Palette[I].B:=VGA_B[I];
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
 PXRead:=D.Position=D.Limit;
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=D^.Depth;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_PCX;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=1;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_MSP;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
Function TFStrip(Var D: TDNState; Offset,Count,Dest,Needed: LongInt): Boolean;
Var P,Stop,OutPos: LongInt; Code,N,Value: Integer; Z: PPNState;
Begin
 TFStrip:=False;
 If D.TFCompression=1 Then Begin
  If Count<>Needed Then Exit;
  Move(D.Data^[Offset],D.Raw^[Dest],Needed); TFStrip:=True; Exit;
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
    Color: Array[0..2] Of Integer; Palette: TPalette;
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
 If Not ((V=1) Or (V=8) Or (V=32946) Or (V=32773)) Then Exit;
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.OutWidth; CanvasImageH:=D^.OutHeight;
   ImageBuffer.Width:=D^.OutWidth; ImageBuffer.Height:=D^.OutHeight;
   ImageBuffer.BitDepth:=D^.Bits*D^.TFSamples;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_TIFF;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=D^.TFAlpha<>0;
   FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0);
   ImageBuffer.Palette:=Q^.Palette;
   ImageBuffer.Metadata:=D^.Metadata;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=1;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_MAC;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
{ Import de constantes Pascal, jamais compilation ni execution du texte.
  Conventions BMP2PAS, PPM2PAS, XBM2PAS : dimensions et BitmapData.
  RGB par defaut, ColorOrder='BGR' et LSBFirst/HasAlpha optionnels.
  Sans palette explicite : VGA 0..15 puis gris, comme le canevas PAINT. }
Type
 TPSConstant = Record Name: String[63]; Value: LongInt; End;
 TPSState = Record
  Data,Bytes,RGB: PPNBytes;
  Size,Position,Count,Declared,RGBSize,Stride,Number: LongInt;
  Width,Height,Bits,Symbols,Depth: Integer;
  Constants: Array[0..127] Of TPSConstant;
  Token,Text: String;
  Palette: TPalette;
  PaletteCount: Integer;
  Bad,SwapRB,OrderSet,LSBFirst,Alpha,BottomUp: Boolean;
 End;
 PPSState = ^TPSState;

Procedure PSNext(Var D: TPSState);
Var C,Q: Byte; N,Base,Digit,Level: Integer; Closed: Boolean;
Begin
 D.Token:=''; D.Text:=''; If D.Bad Then Exit;
 Repeat
  While D.Position<D.Size Do Begin
   If D.Data^[D.Position]>32 Then Break; Inc(D.Position);
  End;
  If D.Position>=D.Size Then Exit;
  C:=D.Data^[D.Position];
  If (C=123) Or ((C=40) And (D.Position+1<D.Size) And
     (D.Data^[D.Position+1]=42)) Then Begin
   Q:=C; Inc(D.Position); If Q=40 Then Inc(D.Position);
   Level:=1;
   While (D.Position<D.Size) And (Level>0) Do Begin
    C:=D.Data^[D.Position]; Inc(D.Position);
    If Q=123 Then Begin
     If C=123 Then Inc(Level) Else If C=125 Then Dec(Level);
    End Else If (D.Position<D.Size) And (C=42) And
       (D.Data^[D.Position]=41) Then Begin Inc(D.Position); Dec(Level); End
    Else If (D.Position<D.Size) And (C=40) And
       (D.Data^[D.Position]=42) Then Begin Inc(D.Position); Inc(Level); End;
    If Level>32 Then Begin D.Bad:=True; Exit; End;
   End;
   If Level<>0 Then Begin D.Bad:=True; Exit; End;
  End Else If (C=47) And (D.Position+1<D.Size) And
     (D.Data^[D.Position+1]=47) Then Begin
   While D.Position<D.Size Do Begin
    C:=D.Data^[D.Position]; Inc(D.Position); If C In [10,13] Then Break;
   End;
  End Else Break;
 Until D.Bad;
 If D.Position>=D.Size Then Exit;
 C:=D.Data^[D.Position]; Inc(D.Position);
 If C=39 Then Begin
  Closed:=False;
  While D.Position<D.Size Do Begin
   C:=D.Data^[D.Position]; Inc(D.Position);
   If C=39 Then Begin
    If (D.Position<D.Size) And (D.Data^[D.Position]=39) Then
     Inc(D.Position)
    Else Begin Closed:=True; Break; End;
   End;
   If Length(D.Text)=255 Then Begin D.Bad:=True; Exit; End;
   D.Text:=D.Text+Chr(C);
  End;
  If Not Closed Then D.Bad:=True;
  D.Token:='STRING'; Exit;
 End;
 If Chr(C) In ['A'..'Z','a'..'z','_'] Then Begin
  D.Token:=UpCase(Chr(C));
  While D.Position<D.Size Do Begin
   C:=D.Data^[D.Position];
   If Not (Chr(C) In ['A'..'Z','a'..'z','_','0'..'9']) Then Break;
   If Length(D.Token)>=63 Then Begin D.Bad:=True; Exit; End;
   D.Token:=D.Token+UpCase(Chr(C)); Inc(D.Position);
  End;
  Exit;
 End;
 If (Chr(C) In ['0'..'9']) Or (C In [36,37,38]) Then Begin
  Base:=10; D.Number:=0; N:=0;
  If C=36 Then Base:=16 Else If C=37 Then Base:=2
  Else If C=38 Then Base:=8 Else Dec(D.Position);
  While D.Position<D.Size Do Begin
   C:=D.Data^[D.Position];
   Digit:=Pos(UpCase(Chr(C)),'0123456789ABCDEF')-1;
   If (Digit<0) Or (Digit>=Base) Then Break;
   If D.Number>(67108864-Digit) Div Base Then Begin
    D.Bad:=True; Exit;
   End;
   D.Number:=D.Number*Base+Digit; Inc(D.Position); Inc(N);
  End;
  If N=0 Then D.Bad:=True; D.Token:='NUMBER'; Exit;
 End;
 D.Token:=Chr(C);
 If (C=46) And (D.Position<D.Size) Then
  If D.Data^[D.Position]=46 Then Begin
   D.Token:='..'; Inc(D.Position);
  End;
End;

Function PSExpression(Var D: TPSState): LongInt; Forward;

Function PSFactor(Var D: TPSState): LongInt;
Var I: Integer; V: LongInt; Negative,Found: Boolean;
Begin
 PSFactor:=0; If D.Bad Then Exit;
 Inc(D.Depth); If D.Depth>16 Then Begin D.Bad:=True; Exit; End;
 Negative:=False;
 If (D.Token='+') Or (D.Token='-') Then Begin
  Negative:=D.Token='-'; PSNext(D);
 End;
 V:=0;
 If D.Token='(' Then Begin
  PSNext(D); V:=PSExpression(D);
  If D.Token<>')' Then D.Bad:=True Else PSNext(D);
 End Else If D.Token='NUMBER' Then Begin V:=D.Number; PSNext(D); End
 Else If (D.Token='TRUE') Or (D.Token='FALSE') Then Begin
  V:=Ord(D.Token='TRUE'); PSNext(D);
 End Else Begin
  Found:=False;
  For I:=0 To D.Symbols-1 Do If D.Constants[I].Name=D.Token Then Begin
   V:=D.Constants[I].Value; Found:=True; Break;
  End;
  If Not Found Then D.Bad:=True Else PSNext(D);
 End;
 If Negative Then V:=-V; Dec(D.Depth); PSFactor:=V;
End;

Function PSTerm(Var D: TPSState): LongInt;
Var A,B: LongInt; V: Double; Op: String;
Begin
 A:=PSFactor(D);
 While Not D.Bad Do Begin
  Op:=D.Token;
  If (Op<>'*') And (Op<>'DIV') And (Op<>'MOD') And
     (Op<>'SHL') And (Op<>'SHR') And (Op<>'AND') Then Break;
  PSNext(D); B:=PSFactor(D); V:=A;
  If Op='*' Then V:=A*(B*1.0)
  Else If (Op='DIV') Or (Op='MOD') Then Begin
   If B=0 Then D.Bad:=True
   Else If Op='DIV' Then V:=A Div B Else V:=A Mod B;
  End Else If Op='AND' Then V:=A And B
  Else Begin
   If (B<0) Or (B>24) Or (A<0) Then D.Bad:=True
   Else If Op='SHL' Then V:=A*Exp(B*Ln(2)) Else V:=A Shr B;
  End;
  If Abs(V)>67108864 Then D.Bad:=True;
  If Not D.Bad Then A:=Round(V);
 End;
 PSTerm:=A;
End;

Function PSExpression(Var D: TPSState): LongInt;
Var A,B: LongInt; V: Double; Op: String;
Begin
 A:=PSTerm(D);
 While Not D.Bad Do Begin
  Op:=D.Token;
  If (Op<>'+') And (Op<>'-') And (Op<>'OR') And (Op<>'XOR') Then Break;
  PSNext(D); B:=PSTerm(D); V:=A;
  If Op='+' Then V:=A+(B*1.0) Else If Op='-' Then V:=A-(B*1.0)
  Else If Op='OR' Then V:=A Or B Else V:=A Xor B;
  If Abs(V)>67108864 Then D.Bad:=True;
  If Not D.Bad Then A:=Round(V);
 End;
 PSExpression:=A;
End;

Procedure PSList(Var D: TPSState; Buffer: PPNBytes;
                 Var Count: LongInt; ElementSize,Level: Integer);
Var V: LongInt;
Begin
 If D.Bad Then Exit;
 If (Level>8) Or (D.Token<>'(') Then Begin D.Bad:=True; Exit; End;
 PSNext(D);
 While Not D.Bad And (D.Token<>')') Do Begin
  If D.Token='' Then Begin D.Bad:=True; Exit; End;
  If D.Token=',' Then Begin PSNext(D); Continue; End;
  If D.Token='(' Then PSList(D,Buffer,Count,ElementSize,Level+1)
  Else Begin
   V:=PSExpression(D);
   If (V<0) Or ((ElementSize=1) And (V>255)) Or (V>65535) Or
      (Count>D.Size-ElementSize) Then Begin D.Bad:=True; Exit; End;
   Buffer^[Count]:=V And 255; Inc(Count);
   If ElementSize=2 Then Begin Buffer^[Count]:=V Shr 8; Inc(Count); End;
  End;
  If (D.Token<>',') And (D.Token<>')') Then D.Bad:=True;
 End;
 If Not D.Bad Then PSNext(D);
End;

Procedure PSArray(Var D: TPSState; Const Name: String);
Var Low,High,Elements,Count: LongInt; Size,I: Integer;
    V: Double; Buffer: PPNBytes; Candidate,Palette: Boolean;
Begin
 PSNext(D); If D.Token<>'[' Then Begin D.Bad:=True; Exit; End;
 Elements:=1;
 Repeat
  PSNext(D); Low:=PSExpression(D);
  If D.Token<>'..' Then Begin D.Bad:=True; Exit; End;
  PSNext(D); High:=PSExpression(D);
  V:=(High-Low+1)*(Elements*1.0);
  If (High<Low) Or (V<1) Or (V>67108864) Then Begin
   D.Bad:=True; Exit;
  End;
  Elements:=Round(V);
 Until (D.Token<>',') Or D.Bad;
 If D.Token<>']' Then Begin D.Bad:=True; Exit; End;
 PSNext(D); If D.Token<>'OF' Then Begin D.Bad:=True; Exit; End;
 PSNext(D); Size:=1;
 If D.Token='WORD' Then Size:=2 Else If D.Token<>'BYTE' Then Begin
  D.Bad:=True; Exit;
 End;
 PSNext(D); If D.Token<>'=' Then Begin D.Bad:=True; Exit; End;
 PSNext(D); Buffer:=PPNBytes(JDAllocate(D.Size));
 If Buffer=Nil Then Begin D.Bad:=True; Exit; End;
 Count:=0; PSList(D,Buffer,Count,Size,0);
 Palette:=(Name='PALETTE') Or (Name='BITMAPPALETTE') Or
          (Name='PALETTEDATA');
 Candidate:=(Pos('BITMAP',Name)>0) Or (Name='IMAGEDATA') Or
            (Name='IMAGEBYTES');
 If Not Candidate And Not Palette And (Count>=12) Then
  Candidate:=((Buffer^[0]=66) And (Buffer^[1]=77)) Or
   ((Buffer^[0]=137) And (Buffer^[1]=80) And (Buffer^[2]=78));
 If Not D.Bad Then Begin
  If Palette Then Begin
   If (Size<>1) Or (Count<3) Or (Count>768) Or (Count Mod 3<>0) Or
   (Count<>Elements*Size)
    Then D.Bad:=True
   Else Begin
    D.PaletteCount:=Count Div 3;
    For I:=0 To D.PaletteCount-1 Do Begin
     D.Palette[I].R:=Buffer^[I*3]; D.Palette[I].G:=Buffer^[I*3+1];
     D.Palette[I].B:=Buffer^[I*3+2];
    End;
   End;
  End Else If Candidate And (D.Bytes=Nil) Then Begin
   D.Bytes:=Buffer; Buffer:=Nil; D.Count:=Count;
   D.Declared:=Elements*Size;
  End;
 End;
 If Buffer<>Nil Then FreeMem(Buffer,D.Size);
 If D.Token<>';' Then D.Bad:=True Else PSNext(D);
End;

Function PSConstants(Var D: TPSState): Boolean;
Var Name,S: String; V: LongInt; Active: Boolean; I: Integer;
Begin
 PSConstants:=False; Active:=False; PSNext(D);
 While Not D.Bad And (D.Token<>'') Do Begin
  If D.Token='CONST' Then Begin
   If Active And (D.Bytes<>Nil) Then Break;
   Active:=True; PSNext(D); Continue;
  End;
  If (D.Token='BEGIN') Or (D.Token='VAR') Or (D.Token='TYPE') Or
     (D.Token='PROCEDURE') Or (D.Token='FUNCTION') Then Begin
   If D.Bytes<>Nil Then Break;
   Active:=False;
  End;
  If Not Active Then Begin PSNext(D); Continue; End;
  Name:=D.Token; PSNext(D);
  If D.Token=':' Then Begin
   PSNext(D); If D.Token='PACKED' Then PSNext(D);
   If D.Token='ARRAY' Then Begin
    PSArray(D,Name); Continue;
   End;
   If (D.Token='BYTE') Or (D.Token='WORD') Or (D.Token='INTEGER') Or
      (D.Token='LONGINT') Or (D.Token='BOOLEAN') Or
      (D.Token='STRING') Then PSNext(D);
  End;
  If D.Token<>'=' Then Continue;
  PSNext(D);
  If D.Token='STRING' Then Begin
   If (Name='COLORORDER') Or (Name='PIXELORDER') Then Begin
    S:=D.Text; For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
    If (S<>'RGB') And (S<>'BGR') Then D.Bad:=True;
    D.SwapRB:=S='BGR'; D.OrderSet:=True;
   End;
   PSNext(D);
  End Else Begin
   V:=PSExpression(D); If D.Bad Then Exit;
   If D.Symbols=128 Then Exit;
   D.Constants[D.Symbols].Name:=Name;
   D.Constants[D.Symbols].Value:=V; Inc(D.Symbols);
   If (Name='NUMXPIXELS') Or (Name='WIDTH') Then Begin
    If (V<1) Or (V>4096) Then Exit; D.Width:=V;
   End Else If (Name='NUMYPIXELS') Or (Name='HEIGHT') Then Begin
    If (V<1) Or (V>4096) Then Exit; D.Height:=V;
   End Else If (Name='BITSPERPIXEL') Or (Name='BPP') Then Begin
    If Not (V In [1,2,4,8,15,16,24,32]) Then Exit; D.Bits:=V;
   End Else If Name='BYTESPERLINE' Then Begin
    If (V<1) Or (V>1048576) Then Exit; D.Stride:=V;
   End Else If Name='LSBFIRST' Then D.LSBFirst:=V<>0
   Else If Name='HASALPHA' Then D.Alpha:=V<>0
   Else If Name='BOTTOMUP' Then D.BottomUp:=V<>0;
  End;
  If D.Token<>';' Then Begin D.Bad:=True; Exit; End; PSNext(D);
 End;
 PSConstants:=Not D.Bad And (D.Bytes<>Nil) And (D.Count>0);
End;

Function PSEmbedded(Var D: TPSState): Boolean;
Var B: PIBState; P: PPNState; PNG: Boolean; I: Integer;
Begin
 PSEmbedded:=False; If D.Count<>D.Declared Then Exit;
 PNG:=D.Count>=45;
 If PNG Then For I:=0 To 7 Do
  If D.Bytes^[I]<>PNG_SIGNATURE[I] Then PNG:=False;
 If PNG Then Begin
  P:=PPNState(JDAllocate(SizeOf(TPNState))); If P=Nil Then Exit;
  FillChar(P^,SizeOf(P^),0); FillChar(P^.Alpha,SizeOf(P^.Alpha),255);
  P^.FileData:=D.Bytes; P^.FileSize:=D.Count;
  If PNParseChunks(P^) Then If PNInflate(P^) Then
   If PNReconstruct(P^) Then Begin
    D.Width:=P^.Width; D.Height:=P^.Height;
    D.Bits:=P^.Depth*P^.Channels; D.RGB:=P^.RGB;
    D.RGBSize:=P^.RGBSize; P^.RGB:=Nil; PSEmbedded:=True;
   End;
  P^.FileData:=Nil; PNFree(P); Exit;
 End;
 B:=PIBState(JDAllocate(SizeOf(TIBState))); If B=Nil Then Exit;
 FillChar(B^,SizeOf(B^),0); B^.Data:=D.Bytes; B^.Size:=D.Count;
 If IBHeader(B^) Then If IBRaster(B^) Then Begin
  D.Width:=B^.Width; D.Height:=B^.Height; D.Bits:=B^.Bits;
  D.RGB:=B^.RGB; D.RGBSize:=B^.RGBSize; B^.RGB:=Nil;
  PSEmbedded:=True;
 End;
 If B^.RGB<>Nil Then FreeMem(B^.RGB,B^.RGBSize);
 FreeMem(B,SizeOf(TIBState));
End;

Function PSDecode(Var D: TPSState): Boolean;
Var Row,Minimum,Needed,P,Dest: LongInt; X,Y,YY,I,Index,R,G,B,A: Integer;
    V: Word; Legacy: Boolean;
Begin
 PSDecode:=False;
 If (D.Width=0) Or (D.Height=0) Or (D.Bits=0) Then Begin
  PSDecode:=PSEmbedded(D); Exit;
 End;
 Minimum:=(LongInt(D.Width)*D.Bits+7) Div 8;
 If D.Bits=15 Then Minimum:=LongInt(D.Width)*2;
 If D.Stride=0 Then D.Stride:=Minimum;
 If D.Stride<Minimum Then Exit;
 If D.Stride>67108864 Div D.Height-1 Then Exit;
 Row:=D.Stride; Needed:=Row*D.Height; Legacy:=False;
 If (D.Declared=Needed) And (D.Count<>Needed) Then Begin
  If (D.Bits=8) And (D.Count=(Row+1)*D.Height) Then Begin
   Inc(Row); Legacy:=True;
  End Else If (D.Bits=24) And
    (D.Count=(((Row+1)*D.Height) Div 3)*3) And
    (D.Count>Needed) Then Begin Inc(Row); Legacy:=True; End
  Else If (D.Bits=4) And (D.Count=Minimum*D.Height) Then Row:=Minimum
  Else Exit;
 End Else If (D.Count<>Needed) Or (D.Declared<>D.Count) Then Exit;
 If (LongInt(D.Height)-1)*Row+Minimum>D.Count Then Exit;
 If Legacy And Not D.OrderSet Then D.SwapRB:=D.Bits=24;
 If D.PaletteCount=0 Then Begin
  D.PaletteCount:=256;
  For I:=0 To 255 Do Begin
   If I<16 Then Begin
    D.Palette[I].R:=VGA_R[I]; D.Palette[I].G:=VGA_G[I];
    D.Palette[I].B:=VGA_B[I];
   End Else Begin
    D.Palette[I].R:=I; D.Palette[I].G:=I; D.Palette[I].B:=I;
   End;
  End;
  If D.Bits=1 Then Begin
   D.Palette[1].R:=255; D.Palette[1].G:=255; D.Palette[1].B:=255;
  End;
 End;
 D.RGBSize:=LongInt(D.Width)*D.Height*3;
 D.RGB:=PPNBytes(JDAllocate(D.RGBSize)); If D.RGB=Nil Then Exit;
 For Y:=0 To D.Height-1 Do For X:=0 To D.Width-1 Do Begin
  YY:=Y; If D.BottomUp Then YY:=D.Height-1-Y;
  P:=LongInt(YY)*Row; R:=0; G:=0; B:=0; A:=255;
  Case D.Bits Of
   1,2,4,8: Begin
    If D.Bits=8 Then Index:=D.Bytes^[P+X]
    Else If D.LSBFirst Then
     Index:=(D.Bytes^[P+(X*D.Bits) Div 8] Shr ((X*D.Bits) And 7))
      And ((1 Shl D.Bits)-1)
    Else Index:=(D.Bytes^[P+(X*D.Bits) Div 8] Shr
      (8-D.Bits-((X*D.Bits) And 7))) And ((1 Shl D.Bits)-1);
    If Index>=D.PaletteCount Then Exit;
    R:=D.Palette[Index].R; G:=D.Palette[Index].G;
    B:=D.Palette[Index].B;
   End;
   15,16: Begin
    Inc(P,LongInt(X)*2);
    V:=Word(D.Bytes^[P]) Or (Word(D.Bytes^[P+1]) Shl 8);
    If D.Bits=15 Then Begin
     R:=((V Shr 10) And 31)*255 Div 31;
     G:=((V Shr 5) And 31)*255 Div 31;
    End Else Begin
     R:=((V Shr 11) And 31)*255 Div 31;
     G:=((V Shr 5) And 63)*255 Div 63;
    End;
    B:=(V And 31)*255 Div 31;
   End;
   24,32: Begin
    Inc(P,LongInt(X)*(D.Bits Div 8));
    R:=D.Bytes^[P]; G:=D.Bytes^[P+1]; B:=D.Bytes^[P+2];
    If D.SwapRB Then Begin I:=R; R:=B; B:=I; End;
    If (D.Bits=32) And D.Alpha Then A:=D.Bytes^[P+3];
   End;
  End;
  Dest:=(LongInt(Y)*D.Width+X)*3;
  D.RGB^[Dest]:=(LongInt(R)*A+LongInt(255)*(255-A)+127) Div 255;
  D.RGB^[Dest+1]:=(LongInt(G)*A+LongInt(255)*(255-A)+127) Div 255;
  D.RGB^[Dest+2]:=(LongInt(B)*A+LongInt(255)*(255-A)+127) Div 255;
 End;
 PSDecode:=True;
End;

Function PSRead(Const Name: String; Var D: TPSState): Boolean;
Var F: File; OldMode: Byte; Bytes: LongInt; Failed: Boolean;
Begin
 PSRead:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
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
 If Failed Then Exit;
 If D.Size>=3 Then If (D.Data^[0]=239) And (D.Data^[1]=187) And
  (D.Data^[2]=191) Then D.Position:=3;
 If PSConstants(D) Then PSRead:=PSDecode(D);
End;

Function LoadPAS(FileName: String): Boolean;
Var D: PPSState; Q: PJPQuantizer; Img: TJDImage; Pixels,Source,Dest: PByte;
    Size,N: LongInt; I,J,Used,Slot: Integer; R,G,B: Byte; Exact: Boolean;
Begin
 LoadPAS:=False; Pixels:=Nil; Q:=Nil;
 D:=PPSState(JDAllocate(SizeOf(TPSState))); If D=Nil Then Exit;
 FillChar(D^,SizeOf(D^),0);
 If PSRead(FileName,D^) Then Begin
  Size:=LongInt(D^.Width)*D^.Height; Pixels:=PByte(JDAllocate(Size)); Q:=PJPQuantizer(JDAllocate(SizeOf(TJPQuantizer)));
  If (Pixels<>Nil) And (Q<>Nil) Then Begin
   FillChar(Q^,SizeOf(Q^),0);
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=D^.Bits;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_PAS;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
   End;
   LoadPAS:=True;
  End;
  If Pixels<>Nil Then FreeMem(Pixels,Size);
 End;
 If Q<>Nil Then FreeMem(Q,SizeOf(TJPQuantizer));
 If D^.RGB<>Nil Then FreeMem(D^.RGB,D^.RGBSize);
 If D^.Bytes<>Nil Then FreeMem(D^.Bytes,D^.Size);
 If D^.Data<>Nil Then FreeMem(D^.Data,D^.Size);
 FreeMem(D,SizeOf(TPSState));
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=D^.Bits;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_TARGA;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=False; FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0); ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
   For I:=0 To 15 Do Begin Q^.Palette[I].R:=VGA_R[I]; Q^.Palette[I].G:=VGA_G[I]; Q^.Palette[I].B:=VGA_B[I]; Q^.Palette[I].A:=255; End;
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
   If CanvasImage<>Nil Then FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
   CanvasImage:=Pixels; Pixels:=Nil; CanvasImageW:=D^.Width; CanvasImageH:=D^.Height;
   ImageBuffer.Width:=D^.Width; ImageBuffer.Height:=D^.Height;
   ImageBuffer.BitDepth:=D^.Bits;
   ImageBuffer.FileName:=FileName; ImageBuffer.Format:=FMT_ICO;
   ImageBuffer.Modified:=False;
   ImageBuffer.HasTransparency:=D^.Transparent;
   ImageBuffer.HasHotspot:=False;
   ImageBuffer.HotspotX:=D^.HotX; ImageBuffer.HotspotY:=D^.HotY;
   ImageBuffer.CursorImages:=D^.Count;
   FillChar(ImageBuffer.TransparentColor,SizeOf(TRGBColor),0);
   ImageBuffer.Palette:=Q^.Palette;
   For I:=0 To 255 Do Begin
    {$IFDEF FPC}SetRGBPalette(I,Q^.Palette[I].R,Q^.Palette[I].G,Q^.Palette[I].B);
    {$ELSE}SetRGBPalette(I,Q^.Palette[I].R Shr 2,Q^.Palette[I].G Shr 2,Q^.Palette[I].B Shr 2);{$ENDIF}
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
Function LoadImage(FileName: String): Boolean;
Var
 Format,OldFileMode: Byte;
 Succeeded: Boolean;
 F: File;
 Ext: String;
Begin
 LoadImage := False;

 { Verifier que le fichier existe et est lisible }
 Assign(F, FileName);
 OldFileMode:=FileMode; FileMode:=0;
 {$I-} Reset(F, 1); {$I+}
 FileMode:=OldFileMode;
 If IOResult <> 0 Then Exit;
 {$I-} Close(F); {$I+}
 If IOResult <> 0 Then;

 { Refuser les extensions inconnues plutot que de tenter un BMP au hasard }
 Ext := ExtractFileExt(FileName);
 If (Ext <> '.BMP') and (Ext <> '.DIB') and
    (Ext <> '.GIF') and (Ext <> '.PNG') and
    (Ext <> '.JPG') and (Ext <> '.JPEG') and (Ext <> '.XBM') and (Ext <> '.WPG') and
    (Ext <> '.LBM') and (Ext <> '.ILBM') and (Ext <> '.IFF') and
    (Ext <> '.HDR') and (Ext <> '.RGBE') and (Ext <> '.FAX') and (Ext <> '.EXR')
    and (Ext <> '.DNG') and (Ext <> '.BGX') and (Ext <> '.DDS') and (Ext <>
    '.DCM') and (Ext <> '.APNG') and (Ext <> '.ARW') and (Ext <> '.CR2') and
    (Ext <> '.PPM') and (Ext <> '.CUR') and (Ext <> '.PCX') and
    (Ext <> '.MSP') and
    (Ext <> '.TIF') and (Ext <> '.TIFF') and
    (Ext <> '.MAC') and (Ext <> '.PNTG') and
    (Ext <> '.PAS') and (Ext <> '.TGA') and
    (Ext <> '.TARGA') and (Ext <> '.ICO') Then Exit;

 Format := GetImageFormat(FileName);

 Case Format of
  FMT_BMP: Succeeded := LoadBMP(FileName);
  FMT_GIF: Succeeded := LoadGIF(FileName);
  FMT_PNG: Succeeded := LoadPNG(FileName);
  FMT_JPEG: Succeeded := LoadJPEG(FileName);
  FMT_XBM: Succeeded := LoadXBM(FileName);
  FMT_WPG: Succeeded := LoadWPG(FileName);
  FMT_LBM: Succeeded := LoadLBM(FileName);
  FMT_HDR: Succeeded := LoadHDR(FileName);
  FMT_FAX: Succeeded := LoadFAX(FileName);
  FMT_EXR: Succeeded := LoadEXR(FileName);
  FMT_DNG: Succeeded := LoadDNG(FileName);
  FMT_BGX: Succeeded := LoadBGX(FileName);
  FMT_DDS: Succeeded := LoadDDS(FileName);
  FMT_DCM: Succeeded := LoadDCM(FileName);
  FMT_APNG: Succeeded := LoadAPNG(FileName);
  FMT_ARW: Succeeded := LoadARW(FileName);
  FMT_CR2: Succeeded := LoadCR2(FileName);
  FMT_PPM: Succeeded := LoadPPM(FileName);
  FMT_DIB: Succeeded := LoadDIB(FileName);
  FMT_CUR: Succeeded := LoadCUR(FileName);
  FMT_ICO: Succeeded := LoadICO(FileName);
  FMT_PCX: Succeeded := LoadPCX(FileName);
  FMT_MSP: Succeeded := LoadMSP(FileName);
  FMT_TIFF: Succeeded := LoadTIFF(FileName);
  FMT_MAC: Succeeded := LoadMAC(FileName);
  FMT_PAS: Succeeded := LoadPAS(FileName);
  FMT_TARGA: Succeeded := LoadTGA(FileName);
  Else Succeeded := False;
 End;
 LoadImage:=Succeeded;
 If Succeeded Then Begin
  If Format<>FMT_CUR Then Begin
   ImageBuffer.HasHotspot:=False; ImageBuffer.HotspotX:=0;
   ImageBuffer.HotspotY:=0; ImageBuffer.CursorImages:=0;
  End;
  If Not (Format In [FMT_GIF,FMT_PNG,FMT_APNG,FMT_TIFF]) Then
  FillChar(ImageBuffer.Metadata,SizeOf(TPaintMetadata),0);
  RedrawInterface;
 End;
End;

Function SaveBMP(FileName: String): Boolean;
Var
 F: File;
 FileHeader: TBMPFileHeader;
 InfoHeader: TBMPInfoHeader;
 BytesWritten: Word;
 RowSize: LongInt;
 ImageSize: LongInt;
 BMPPalette: Array[0..255] of TRGBQuad;
 RowBuffer: Array[0..12287] of Byte;
 X, Y, SrcY: Integer;
 PixelColor: Byte;
 PaletteEntries: Integer;
 PadBytes: Integer;
 I: Integer;
 SrcP: PByte;
Begin
 SaveBMP := False;

 { Calculer la taille de la ligne (alignée sur 4 octets) }
 RowSize := ((ImageBuffer.Width * ImageBuffer.BitDepth + 31) div 32) * 4;
 ImageSize := RowSize * ImageBuffer.Height;
 PadBytes := RowSize - ((ImageBuffer.Width * ImageBuffer.BitDepth + 7) div 8);

 { Calculer le nombre d'entrées de palette }
 If ImageBuffer.BitDepth <= 8 Then
  PaletteEntries := 1 shl ImageBuffer.BitDepth
 Else
  PaletteEntries := 0;

 { Préparer l'en-tête du fichier }
 FileHeader.bfType := BMP_SIGNATURE;
 FileHeader.bfSize := SizeOf(TBMPFileHeader) + SizeOf(TBMPInfoHeader) +
                      PaletteEntries * 4 + ImageSize;
 FileHeader.bfReserved1 := 0;
 FileHeader.bfReserved2 := 0;
 FileHeader.bfOffBits := SizeOf(TBMPFileHeader) + SizeOf(TBMPInfoHeader) +
                         PaletteEntries * 4;

 { Préparer l'en-tête d'information }
 InfoHeader.biSize := SizeOf(TBMPInfoHeader);
 InfoHeader.biWidth := ImageBuffer.Width;
 InfoHeader.biHeight := ImageBuffer.Height;
 InfoHeader.biPlanes := 1;
 InfoHeader.biBitCount := ImageBuffer.BitDepth;
 InfoHeader.biCompression := 0;
 InfoHeader.biSizeImage := ImageSize;
 InfoHeader.biXPelsPerMeter := 2835;
 InfoHeader.biYPelsPerMeter := 2835;
 InfoHeader.biClrUsed := PaletteEntries;
 InfoHeader.biClrImportant := 0;

 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Écrire l'en-tête du fichier }
 BlockWrite(F, FileHeader, SizeOf(TBMPFileHeader), BytesWritten);
 If BytesWritten <> SizeOf(TBMPFileHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Écrire l'en-tête d'information }
 BlockWrite(F, InfoHeader, SizeOf(TBMPInfoHeader), BytesWritten);
 If BytesWritten <> SizeOf(TBMPInfoHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Écrire la palette si nécessaire }
 If ImageBuffer.BitDepth <= 8 Then Begin
  { Convertir la palette interne au format BMP (BGRA) }
  For I := 0 to PaletteEntries - 1 do Begin
   BMPPalette[I].Blue := ImageBuffer.Palette[I].B;
   BMPPalette[I].Green := ImageBuffer.Palette[I].G;
   BMPPalette[I].Red := ImageBuffer.Palette[I].R;
   BMPPalette[I].Reserved := 0;
  End;
  BlockWrite(F, BMPPalette, PaletteEntries * 4, BytesWritten);
  If BytesWritten <> PaletteEntries * 4 Then Begin
   Close(F);
   Exit;
  End;
 End;

 { Écrire les données de l'image ligne par ligne (de bas en haut).
   On lit depuis CanvasImage (et non l'ecran via GetPixel) pour ne pas
   capturer un menu deroulant, le curseur souris, ou tout autre overlay
   d'interface qui pourrait masquer la zone canvas au moment de la
   sauvegarde. CanvasImage est tenu a jour par SyncCanvasImage apres
   chaque primitive de dessin. }
 For Y := ImageBuffer.Height - 1 downto 0 do Begin
  { Initialiser le buffer de ligne à zéro }
  FillChar(RowBuffer, RowSize, 0);

  { Lire les pixels depuis le buffer canvas en memoire }
  For X := 0 to ImageBuffer.Width - 1 do Begin
   If (CanvasImage <> Nil) and
      (X < CanvasImageW) and (Y < CanvasImageH) Then Begin
    SrcP := CanvasImage;
    Inc(SrcP, LongInt(Y) * LongInt(CanvasImageW) + X);
    PixelColor := SrcP^;
   End Else Begin
    PixelColor := 0;
   End;

   { Écrire le pixel dans le buffer selon la profondeur de couleur }
   Case ImageBuffer.BitDepth of
    1: Begin
     If (PixelColor and 1) <> 0 Then
      RowBuffer[X div 8] := RowBuffer[X div 8] or (1 shl (7 - (X mod 8)));
    End;
    4: Begin
     If (X mod 2) = 0 Then
      RowBuffer[X div 2] := (PixelColor and $0F) shl 4
     Else
      RowBuffer[X div 2] := RowBuffer[X div 2] or (PixelColor and $0F);
    End;
    8: Begin
     RowBuffer[X] := PixelColor;
    End;
    24: Begin
     { Convertir la couleur d'index vers RGB }
     RowBuffer[X * 3] := ImageBuffer.Palette[PixelColor].B;
     RowBuffer[X * 3 + 1] := ImageBuffer.Palette[PixelColor].G;
     RowBuffer[X * 3 + 2] := ImageBuffer.Palette[PixelColor].R;
    End;
   End;
  End;

  { Écrire la ligne avec le padding }
  BlockWrite(F, RowBuffer, RowSize, BytesWritten);
  If BytesWritten <> RowSize Then Begin
   Close(F);
   Exit;
  End;
 End;

 Close(F);
 ImageBuffer.FileName := FileName;
 ImageBuffer.Modified := False;
 SaveBMP := True;
End;

{ Ecriture GIF/PNG integree. Les pixels proviennent du document, jamais
  de l'ecran : menus, curseur et apercus ne peuvent pas entrer dans le fichier. }
Function SaveGIF(FileName: String): Boolean;
Var F: File; Header: TGIFHeader; Bad: Boolean; Wrote: LongInt;
    Palette: Array[0..767] Of Byte; Descriptor: Array[0..9] Of Byte;
    Block: Array[0..254] Of Byte; Count,Bits,SinceClear,I,X,Y: Integer;
    Acc: LongInt; B: Byte;
 Procedure WriteData(Var Data; N: LongInt);
 Begin
  If Bad Then Exit;
  {$I-}BlockWrite(F,Data,N,Wrote);{$I+}
  If (IOResult<>0) Or (Wrote<>N) Then Bad:=True;
 End;
 Procedure WriteByte(V: Byte);
 Begin B:=V; WriteData(B,1); End;
 Procedure Flush;
 Begin
  If Count=0 Then Exit;
  WriteByte(Count); WriteData(Block,Count); Count:=0;
 End;
 Procedure PackedByte(V: Byte);
 Begin
  Block[Count]:=V; Inc(Count); If Count=255 Then Flush;
 End;
 Procedure Code(V: Integer);
 Begin
  Acc:=Acc Or (LongInt(V) Shl Bits); Inc(Bits,9);
  While Bits>=8 Do Begin PackedByte(Acc And 255); Acc:=Acc Shr 8; Dec(Bits,8); End;
 End;
Begin
 SaveGIF:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<>ImageBuffer.Width) Or (CanvasImageH<>ImageBuffer.Height) Then Exit;
 Assign(F,FileName); {$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Bad:=False; Count:=0; Bits:=0; Acc:=0; SinceClear:=0;
 FillChar(Header,SizeOf(Header),0); Move(GIF87_SIGNATURE[1],Header.Signature,6);
 If ImageBuffer.Metadata.Values[5]<>'' Then Move(GIF89_SIGNATURE[1],Header.Signature,6);
 Header.ScreenWidth:=CanvasImageW; Header.ScreenHeight:=CanvasImageH; Header.Flags:=$F7;
 WriteData(Header,SizeOf(Header));
 For I:=0 To 255 Do Begin
  Palette[I*3]:=ImageBuffer.Palette[I].R; Palette[I*3+1]:=ImageBuffer.Palette[I].G;
  Palette[I*3+2]:=ImageBuffer.Palette[I].B;
 End;
 WriteData(Palette,768);
 If ImageBuffer.Metadata.Values[5]<>'' Then Begin
  WriteByte($21); WriteByte($FE); WriteByte(Length(ImageBuffer.Metadata.Values[5]));
  WriteData(ImageBuffer.Metadata.Values[5][1],Length(ImageBuffer.Metadata.Values[5])); WriteByte(0);
 End;
 FillChar(Descriptor,SizeOf(Descriptor),0);
 Descriptor[0]:=$2C; Descriptor[5]:=Lo(CanvasImageW); Descriptor[6]:=Hi(CanvasImageW);
 Descriptor[7]:=Lo(CanvasImageH); Descriptor[8]:=Hi(CanvasImageH);
 WriteData(Descriptor,10); WriteByte(8); Code(256);
 { Codes litteraux LZW avec Clear periodique : flux valide a neuf bits,
   sans dictionnaire volumineux. Le resultat conserve exactement la palette. }
 For Y:=0 To CanvasImageH-1 Do For X:=0 To CanvasImageW-1 Do Begin
  If SinceClear=200 Then Begin Code(256); SinceClear:=0; End;
  Code(ZImagePixel(X,Y)); Inc(SinceClear);
 End;
 Code(257); If Bits>0 Then PackedByte(Acc And 255);
 Flush; WriteByte(0); WriteByte($3B);
 {$I-}Close(F);{$I+}If IOResult<>0 Then Bad:=True;
 SaveGIF:=Not Bad;
End;

Function SavePNGContainer(FileName: String; Animated: Boolean): Boolean;
Var F: File; D: PPNState; Data: PPNBytes; RawSize,Size,Pos,Offset,N,I,X,Y: LongInt;
    Header: Array[0..12] Of Byte; Palette: Array[0..767] Of Byte;
    Bytes: Array[0..3] Of Byte; AdlerA,AdlerB,C: LongWord;
    Bad: Boolean; Wrote: LongInt;
    Animation:Array[0..7] Of Byte; Frame:Array[0..25] Of Byte;
 Procedure WriteData(Var Buffer; Count: LongInt);
 Begin
  If Bad Then Exit;
  {$I-}BlockWrite(F,Buffer,Count,Wrote);{$I+}
  If (IOResult<>0) Or (Wrote<>Count) Then Bad:=True;
 End;
 Procedure BE(Value: LongWord);
 Begin
  Bytes[0]:=Value Shr 24; Bytes[1]:=Value Shr 16; Bytes[2]:=Value Shr 8; Bytes[3]:=Value;
 End;
 Procedure Chunk(Const Kind: String; Buffer: Pointer; Count: LongInt);
 Var J: LongInt; P: PPNBytes; K: Array[0..3] Of Char;
 Begin
  BE(Count); WriteData(Bytes,4); C:=$FFFFFFFF;
  For J:=0 To 3 Do Begin K[J]:=Kind[J+1]; C:=D^.CRC[(C Xor Ord(K[J])) And 255] Xor (C Shr 8); End;
  WriteData(K,4); P:=PPNBytes(Buffer);
  If Count>0 Then Begin
   WriteData(P^,Count);
   For J:=0 To Count-1 Do C:=D^.CRC[(C Xor P^[J]) And 255] Xor (C Shr 8);
  End;
  BE(C Xor $FFFFFFFF); WriteData(Bytes,4);
 End;
 Procedure TextChunk(Index: Integer);
 Var Buffer: Array[0..511] Of Byte; Key,Value: String; J,N: Integer;
 Begin
  Value:=ImageBuffer.Metadata.Values[Index]; If Value='' Then Exit;
  Key:=PMKey(Index); N:=0;
  For J:=1 To Length(Key) Do Begin Buffer[N]:=Ord(Key[J]); Inc(N); End;
  Buffer[N]:=0; Inc(N);
  For J:=1 To Length(Value) Do Begin Buffer[N]:=Ord(Value[J]); Inc(N); End;
  Chunk('tEXt',@Buffer,N);
 End;

Begin
 SavePNGContainer:=False; Data:=Nil;
 If (CanvasImage=Nil) Or (CanvasImageW<>ImageBuffer.Width) Or (CanvasImageH<>ImageBuffer.Height) Then Exit;
 RawSize:=(LongInt(CanvasImageW)+1)*CanvasImageH;
 Size:=2+RawSize+((RawSize+65534) Div 65535)*5+4;
 Data:=PPNBytes(JDAllocate(Size)); D:=PPNState(JDAllocate(SizeOf(TPNState)));
 If (Data=Nil) Or (D=Nil) Then Begin
  If Data<>Nil Then FreeMem(Data,Size); If D<>Nil Then FreeMem(D,SizeOf(TPNState)); Exit;
 End;
 FillChar(D^,SizeOf(D^),0); PNInitCRC(D^);
 { Zlib + blocs DEFLATE non compresses : encodage sans perte et autonome. }
 Data^[0]:=$78; Data^[1]:=$01; Pos:=2; Offset:=0; AdlerA:=1; AdlerB:=0;
 While Offset<RawSize Do Begin
  N:=RawSize-Offset; If N>65535 Then N:=65535;
  If Offset+N=RawSize Then Data^[Pos]:=1 Else Data^[Pos]:=0; Inc(Pos);
  Data^[Pos]:=N And 255; Data^[Pos+1]:=N Shr 8;
  Data^[Pos+2]:=(N Xor 65535) And 255; Data^[Pos+3]:=(N Xor 65535) Shr 8; Inc(Pos,4);
  For I:=0 To N-1 Do Begin
   X:=(Offset+I) Mod (CanvasImageW+1); Y:=(Offset+I) Div (CanvasImageW+1);
   If X=0 Then Data^[Pos]:=0 Else Data^[Pos]:=ZImagePixel(X-1,Y);
   AdlerA:=(AdlerA+Data^[Pos]) Mod 65521; AdlerB:=(AdlerB+AdlerA) Mod 65521; Inc(Pos);
  End;
  Inc(Offset,N);
 End;
 BE((AdlerB Shl 16) Or AdlerA); Move(Bytes,Data^[Pos],4); Inc(Pos,4);
 FillChar(Header,SizeOf(Header),0); BE(CanvasImageW); Move(Bytes,Header[0],4);
 BE(CanvasImageH); Move(Bytes,Header[4],4); Header[8]:=8; Header[9]:=3;
 For I:=0 To 255 Do Begin
  Palette[I*3]:=ImageBuffer.Palette[I].R; Palette[I*3+1]:=ImageBuffer.Palette[I].G; Palette[I*3+2]:=ImageBuffer.Palette[I].B;
 End;
 Assign(F,FileName); {$I-}Rewrite(F,1);{$I+}Bad:=IOResult<>0;
 If Not Bad Then Begin
  WriteData(PNG_SIGNATURE,8); Chunk('IHDR',@Header,13); Chunk('PLTE',@Palette,768);
  For X:=0 To 5 Do TextChunk(X);
  If Animated Then Begin
   FillChar(Animation,SizeOf(Animation),0);Animation[3]:=1;
   Chunk('acTL',@Animation,8);
   FillChar(Frame,SizeOf(Frame),0);
   BE(CanvasImageW);Move(Bytes,Frame[4],4);
   BE(CanvasImageH);Move(Bytes,Frame[8],4);
   Frame[21]:=1;Frame[23]:=10;
   Chunk('fcTL',@Frame,26);
  End;
  Chunk('IDAT',Data,Pos); Chunk('IEND',Nil,0);
  {$I-}Close(F);{$I+}If IOResult<>0 Then Bad:=True;
 End;
 FreeMem(Data,Size); FreeMem(D,SizeOf(TPNState)); SavePNGContainer:=Not Bad;
End;

Function SavePNG(FileName: String): Boolean;
Begin SavePNG:=SavePNGContainer(FileName,False); End;

Function SaveAPNG(FileName: String): Boolean;
Begin SaveAPNG:=SavePNGContainer(FileName,True); End;

Var PaintSaveError: String;

{ PCX version 5 : un plan indexe 8 bits, RLE par ligne, palette VGA.
  Le canevas et sa palette sont conserves exactement, sans quantification. }
Function SavePCX(FileName: String): Boolean;
Var F: File; Header: Array[0..127] Of Byte;
    Output: Array[0..8191] Of Byte; Palette: Array[0..768] Of Byte;
    X,Y,I,Run,Used,Stride: Integer; Value,Next: Byte;
    Written: LongInt; Failed: Boolean;
 Procedure PutWord(P,V: Integer);
 Begin Header[P]:=V And 255; Header[P+1]:=V Shr 8; End;
 Procedure WriteBytes(Var Buffer; Count: LongInt);
 Begin
  If Failed Then Exit;
  {$I-}BlockWrite(F,Buffer,Count,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Count);
 End;
Begin
 SavePCX:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 FillChar(Header,SizeOf(Header),0);
 Header[0]:=10; Header[1]:=5; Header[2]:=1; Header[3]:=8;
 PutWord(8,CanvasImageW-1); PutWord(10,CanvasImageH-1);
 PutWord(12,72); PutWord(14,72);
 For I:=0 To 15 Do Begin
  Header[16+I*3]:=ImageBuffer.Palette[I].R;
  Header[17+I*3]:=ImageBuffer.Palette[I].G;
  Header[18+I*3]:=ImageBuffer.Palette[I].B;
 End;
 Stride:=(CanvasImageW+1) And $FFFE;
 Header[65]:=1; PutWord(66,Stride); PutWord(68,1);
 PutWord(70,CanvasImageW); PutWord(72,CanvasImageH);
 Palette[0]:=12;
 For I:=0 To 255 Do Begin
  Palette[1+I*3]:=ImageBuffer.Palette[I].R;
  Palette[2+I*3]:=ImageBuffer.Palette[I].G;
  Palette[3+I*3]:=ImageBuffer.Palette[I].B;
 End;
 Assign(F,FileName); {$I-}Rewrite(F,1);{$I+}
 If IOResult<>0 Then Exit;
 Failed:=False; WriteBytes(Header,SizeOf(Header));
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break; X:=0; Used:=0;
  While X<Stride Do Begin
   Value:=0; If X<CanvasImageW Then Value:=ZImagePixel(X,Y);
   Run:=1;
   While (Run<63) And (X+Run<Stride) Do Begin
    Next:=0;
    If X+Run<CanvasImageW Then Next:=ZImagePixel(X+Run,Y);
    If Next<>Value Then Break; Inc(Run);
   End;
   If (Run>1) Or (Value>=192) Then Begin
    Output[Used]:=192 Or Run; Inc(Used);
   End;
   Output[Used]:=Value; Inc(Used); Inc(X,Run);
  End;
  WriteBytes(Output,Used);
 End;
 WriteBytes(Palette,SizeOf(Palette));
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SavePCX:=Not Failed;
End;


{ Encodeur JPEG integre,  adapte de BMP2JPEG.PAS : JFIF baseline, 
  qualite 90,  YCbCr 4:4:4,  DCT separable et tables Huffman standard. }
Function SaveJPEG(FileName: String): Boolean;
Const
 OneOverSqrt2=0.70710678118654752440;
 MarkerSOI=$D8;
 MarkerEOI=$D9;
 MarkerSOF0=$C0;
 MarkerDHT=$C4;
 MarkerDQT=$DB;
 MarkerSOS=$DA;
 MarkerAPP0=$E0;
 ZigZag:Array[0..63]of Byte=(
   0,  1,  8, 16,  9,  2,  3, 10, 
  17, 24, 32, 25, 18, 11,  4,  5, 
  12, 19, 26, 33, 40, 48, 41, 34, 
  27, 20, 13,  6,  7, 14, 21, 28, 
  35, 42, 49, 56, 57, 50, 43, 36, 
  29, 22, 15, 23, 30, 37, 44, 51, 
  58, 59, 52, 45, 38, 31, 39, 46, 
  53, 60, 61, 54, 47, 55, 62, 63);
 StdQTLuma:Array[0..63]of Byte=(
  16, 11, 10, 16,  24,  40,  51,  61, 
  12, 12, 14, 19,  26,  58,  60,  55, 
  14, 13, 16, 24,  40,  57,  69,  56, 
  14, 17, 22, 29,  51,  87,  80,  62, 
  18, 22, 37, 56,  68, 109, 103,  77, 
  24, 35, 55, 64,  81, 104, 113,  92, 
  49, 64, 78, 87, 103, 121, 120, 101, 
  72, 92, 95, 98, 112, 100, 103,  99);
 StdQTChroma:Array[0..63]of Byte=(
  17, 18, 24, 47, 99, 99, 99, 99, 
  18, 21, 26, 66, 99, 99, 99, 99, 
  24, 26, 56, 99, 99, 99, 99, 99, 
  47, 66, 99, 99, 99, 99, 99, 99, 
  99, 99, 99, 99, 99, 99, 99, 99, 
  99, 99, 99, 99, 99, 99, 99, 99, 
  99, 99, 99, 99, 99, 99, 99, 99, 
  99, 99, 99, 99, 99, 99, 99, 99);
 StdDCLumaCounts:Array[0..15]of Byte=
   (0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0);
 StdDCLumaValues:Array[0..11]of Byte=
   (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
 StdDCChromaCounts:Array[0..15]of Byte=
   (0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0);
 StdDCChromaValues:Array[0..11]of Byte=
   (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
 StdACLumaCounts:Array[0..15]of Byte=
   (0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, $7D);
 StdACLumaValues:Array[0..161]of Byte=(
  $01, $02, $03, $00, $04, $11, $05, $12, $21, $31, $41, $06, $13, $51, $61,
  $07, 
  $22, $71, $14, $32, $81, $91, $A1, $08, $23, $42, $B1, $C1, $15, $52, $D1,
  $F0, 
  $24, $33, $62, $72, $82, $09, $0A, $16, $17, $18, $19, $1A, $25, $26, $27,
  $28, 
  $29, $2A, $34, $35, $36, $37, $38, $39, $3A, $43, $44, $45, $46, $47, $48,
  $49, 
  $4A, $53, $54, $55, $56, $57, $58, $59, $5A, $63, $64, $65, $66, $67, $68,
  $69, 
  $6A, $73, $74, $75, $76, $77, $78, $79, $7A, $83, $84, $85, $86, $87, $88,
  $89, 
  $8A, $92, $93, $94, $95, $96, $97, $98, $99, $9A, $A2, $A3, $A4, $A5, $A6,
  $A7, 
  $A8, $A9, $AA, $B2, $B3, $B4, $B5, $B6, $B7, $B8, $B9, $BA, $C2, $C3, $C4,
  $C5, 
  $C6, $C7, $C8, $C9, $CA, $D2, $D3, $D4, $D5, $D6, $D7, $D8, $D9, $DA, $E1,
  $E2, 
  $E3, $E4, $E5, $E6, $E7, $E8, $E9, $EA, $F1, $F2, $F3, $F4, $F5, $F6, $F7,
  $F8, 
  $F9, $FA);
 StdACChromaCounts:Array[0..15]of Byte=
   (0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, $77);
 StdACChromaValues:Array[0..161]of Byte=(
  $00, $01, $02, $03, $11, $04, $05, $21, $31, $06, $12, $41, $51, $07, $61,
  $71, 
  $13, $22, $32, $81, $08, $14, $42, $91, $A1, $B1, $C1, $09, $23, $33, $52,
  $F0, 
  $15, $62, $72, $D1, $0A, $16, $24, $34, $E1, $25, $F1, $17, $18, $19, $1A,
  $26, 
  $27, $28, $29, $2A, $35, $36, $37, $38, $39, $3A, $43, $44, $45, $46, $47,
  $48, 
  $49, $4A, $53, $54, $55, $56, $57, $58, $59, $5A, $63, $64, $65, $66, $67,
  $68, 
  $69, $6A, $73, $74, $75, $76, $77, $78, $79, $7A, $82, $83, $84, $85, $86,
  $87, 
  $88, $89, $8A, $92, $93, $94, $95, $96, $97, $98, $99, $9A, $A2, $A3, $A4,
  $A5, 
  $A6, $A7, $A8, $A9, $AA, $B2, $B3, $B4, $B5, $B6, $B7, $B8, $B9, $BA, $C2,
  $C3, 
  $C4, $C5, $C6, $C7, $C8, $C9, $CA, $D2, $D3, $D4, $D5, $D6, $D7, $D8, $D9,
  $DA, 
  $E2, $E3, $E4, $E5, $E6, $E7, $E8, $E9, $EA, $F2, $F3, $F4, $F5, $F6, $F7,
  $F8, 
  $F9, $FA);
Type
 Block64=Array[0..63] Of Real;
 IBlock64=Array[0..63] Of Integer;
 TByteArr=Array[0..32767] Of Byte;
 PByteArr=^TByteArr;
Var
 DestJPEG:File; Failed:Boolean;
 Output:Array[0..8191] Of Byte; OutputCount:Integer;
 LineBuf:Array[0..12287] Of Byte;
 I:Integer; BlockY, BlockCb, BlockCr:Block64; ZZBlock:IBlock64;
 MCUCol, ValidRows:Word; Y, Y2, SourceRow:LongInt;
 QTLuma, QTChroma:Array[0..63]of Byte;
 DCLumaCode, ACLumaCode, DCChromaCode, ACChromaCode:Array[0..255]of Word;
 DCLumaSize, ACLumaSize, DCChromaSize, ACChromaSize:Array[0..255]of Byte;
 CosTab:Array[0..7, 0..7]of Real;
 YBuf, CbBuf, CrBuf:Pointer;
 StripeWidth:Word;
 StripeBytes:Word;
 ImageWidth, ImageHeight:Word;
 BitBuffer:LongInt;
 BitsInBuffer:Integer;
 PrevDCY, PrevDCCb, PrevDCCr:Integer;
Procedure FlushOutput;
Var Written:LongInt;
Begin
 If Failed Or (OutputCount=0) Then Exit;
 {$I-}BlockWrite(DestJPEG, Output, OutputCount, Written);{$I+}
 Failed:=(IOResult<>0) Or (Written<>OutputCount); OutputCount:=0;
End;
Procedure WriteRaw(Var Buffer; Count:Integer);
Var P:PByte; J:Integer;
Begin
 If Failed Then Exit; P:=@Buffer;
 For J:=1 To Count Do Begin
  Output[OutputCount]:=P^;Inc(P);Inc(OutputCount);
  If OutputCount=SizeOf(Output) Then FlushOutput;
  If Failed Then Exit;
 End;
End;
Procedure WriteByteToFile(B:Byte);
Begin WriteRaw(B, 1); End;
Procedure WriteWordToFile(W:Word);
Begin WriteByteToFile(W Shr 8);WriteByteToFile(W And 255); End;
Procedure WriteMarker(M:Byte);
Begin WriteByteToFile(255);WriteByteToFile(M); End;
Procedure ReadBmpRowAsRGB(RowIndex:LongInt);
Var X:Integer; C:TRGBColor;
Begin
 For X:=0 To CanvasImageW-1 Do Begin
  C:=ImageBuffer.Palette[ZImagePixel(X, RowIndex)];
  LineBuf[X*3]:=C.B;LineBuf[X*3+1]:=C.G;LineBuf[X*3+2]:=C.R;
 End;
End;
Procedure InitCosTab;
Var
 I, J:Integer;
Begin
 For I:=0 to 7 Do
  For J:=0 to 7 Do
   CosTab[I, J]:=Cos((2*I+1)*J*Pi/16);
End;
Procedure BuildQuantTables(Q:Integer);
Var
 I:Integer;
 Scale, V:LongInt;
Begin
 If Q<1 Then Q:=1;
 If Q>100 Then Q:=100;
 If Q<50 Then Scale:=LongInt(5000)div LongInt(Q)
         Else Scale:=200-2*LongInt(Q);
 For I:=0 to 63 Do Begin
  V:=(LongInt(StdQTLuma[I])*Scale+50)div 100;
  If V<1 Then V:=1;
  If V>255 Then V:=255;
  QTLuma[I]:=Byte(V);
  V:=(LongInt(StdQTChroma[I])*Scale+50)div 100;
  If V<1 Then V:=1;
  If V>255 Then V:=255;
  QTChroma[I]:=Byte(V);
 End;
End;
Procedure BuildHuffTable(Const Counts:Array of Byte;Const Values:Array of Byte;
                         NumValues:Integer;
                         Var Codes:Array of Word;Var Sizes:Array of Byte);
Var
 I, J, K:Integer;
 Code:Word;
 Size:Integer;
 HuffSize:Array[0..256]of Byte;
 HuffCode:Array[0..256]of Word;
Begin
 K:=0;
 For I:=1 to 16 Do
  For J:=1 to Counts[I-1] Do Begin
   HuffSize[K]:=Byte(I);
   Inc(K);
  End;
 HuffSize[K]:=0;
 Code:=0;
 Size:=HuffSize[0];
 K:=0;
 While HuffSize[K]<>0 Do Begin
  While(HuffSize[K]<>0)and(Integer(HuffSize[K])=Size)Do Begin
   HuffCode[K]:=Code;
   Inc(Code);
   Inc(K);
  End;
  If HuffSize[K]=0 Then Break;
  Repeat
   Code:=Word(Code shl 1);
   Inc(Size);
  Until Integer(HuffSize[K])=Size;
 End;
 For I:=0 to 255 Do Begin
  Codes[I]:=0;
  Sizes[I]:=0;
 End;
 For I:=0 to NumValues-1 Do Begin
  Codes[Values[I]]:=HuffCode[I];
  Sizes[Values[I]]:=HuffSize[I];
 End;
End;
Procedure BuildAllHuffTables;
Begin
 BuildHuffTable(StdDCLumaCounts, StdDCLumaValues, 12, DCLumaCode, DCLumaSize);
 BuildHuffTable(StdDCChromaCounts, StdDCChromaValues, 12, DCChromaCode,
 DCChromaSize);
 BuildHuffTable(StdACLumaCounts, StdACLumaValues, 162, ACLumaCode, ACLumaSize);
 BuildHuffTable(StdACChromaCounts, StdACChromaValues, 162, ACChromaCode,
 ACChromaSize);
End;
Procedure ForwardDCT(Var Block:Block64);
Var U, V, X, Y:Integer; Sum, Cu, Cv:Real; Tmp:Block64;
Begin
 For Y:=0 To 7 Do For U:=0 To 7 Do Begin
  Sum:=0;
  For X:=0 To 7 Do Sum:=Sum+Block[Y*8+X]*CosTab[X, U];
  Tmp[Y*8+U]:=Sum;
 End;
 For V:=0 To 7 Do For U:=0 To 7 Do Begin
  Sum:=0;
  For Y:=0 To 7 Do Sum:=Sum+Tmp[Y*8+U]*CosTab[Y, V];
  Cu:=1; Cv:=1;
  If U=0 Then Cu:=OneOverSqrt2;
  If V=0 Then Cv:=OneOverSqrt2;
  Block[V*8+U]:=0.25*Cu*Cv*Sum;
 End;
End;
Procedure QuantizeAndZigZag(Const Src:Block64;Const QT:Array of Byte;
                            Var Dst:IBlock64);
Var
 I:Integer;
 V:Real;
 Q:Integer;
Begin
 For I:=0 to 63 Do Begin
  V:=Src[ZigZag[I]];
  Q:=QT[ZigZag[I]];
  If V>=0 Then Dst[I]:=Trunc((V+Q/2)/Q)
          Else Dst[I]:=-Trunc((-V+Q/2)/Q);
 End;
End;
Procedure WriteBits(Bits:Word;Size:Integer);
Var
 B:Byte;
 Mask:LongInt;
 Pad:Byte;
Begin
 If Size=0 Then Exit;
 Mask:=(LongInt(1)shl Size)-1;
 BitBuffer:=(BitBuffer shl Size)or(LongInt(Bits)and Mask);
 Inc(BitsInBuffer, Size);
 While BitsInBuffer>=8 Do Begin
  Dec(BitsInBuffer, 8);
  B:=Byte((BitBuffer shr BitsInBuffer)and $FF);
  WriteRaw(B, 1);
  If B=$FF Then Begin
   Pad:=0;
   WriteRaw(Pad, 1);
  End;
 End;
End;
Procedure FlushBits;
Var
 B, Pad:Byte;
 Pad1:Integer;
Begin
 If BitsInBuffer>0 Then Begin
  Pad1:=8-BitsInBuffer;
  BitBuffer:=(BitBuffer shl Pad1)or((LongInt(1)shl Pad1)-1);
  BitsInBuffer:=8;
  Dec(BitsInBuffer, 8);
  B:=Byte(BitBuffer and $FF);
  WriteRaw(B, 1);
  If B=$FF Then Begin
   Pad:=0;
   WriteRaw(Pad, 1);
  End;
 End;
 BitBuffer:=0;
 BitsInBuffer:=0;
End;
Procedure EncodeCoef(Value:Integer;Var Size:Integer;Var Bits:Word);
Var
 AV:Integer;
Begin
 AV:=Abs(Value);
 Size:=0;
 While AV<>0 Do Begin
  Inc(Size);
  AV:=AV shr 1;
 End;
 If Value<0 Then
  Bits:=Word((Value+(LongInt(1)shl Size)-1)and((LongInt(1)shl Size)-1))
  Else
  Bits:=Word(Value);
End;
Procedure EncodeBlock(Const ZZ:IBlock64;Var PrevDC:Integer;
                      Const DCCode:Array of Word;Const DCSize:Array of Byte;
                      Const ACCode:Array of Word;Const ACSize:Array of Byte);
Var
 K, RunLen, Size:Integer;
 Diff:Integer;
 Bits:Word;
 RS:Integer;
Begin
 Diff:=ZZ[0]-PrevDC;
 PrevDC:=ZZ[0];
 EncodeCoef(Diff, Size, Bits);
 WriteBits(DCCode[Size], DCSize[Size]);
 If Size>0 Then WriteBits(Bits, Size);
 K:=1;
 While K<=63 Do Begin
  RunLen:=0;
  While(K<=63)and(ZZ[K]=0)Do Begin
   Inc(K); Inc(RunLen);
  End;
  If K>63 Then Begin
   WriteBits(ACCode[$00], ACSize[$00]);
   Break;
  End;
  While RunLen>=16 Do Begin
   WriteBits(ACCode[$F0], ACSize[$F0]);
   Dec(RunLen, 16);
  End;
  EncodeCoef(ZZ[K], Size, Bits);
  RS:=(RunLen shl 4)or Size;
  WriteBits(ACCode[RS], ACSize[RS]);
  If Size>0 Then WriteBits(Bits, Size);
  Inc(K);
 End;
End;
Function ClampByte(V:Real):Byte;
Begin
 If V<0.0 Then ClampByte:=0
  Else
 If V>255.0 Then ClampByte:=255
  Else
 ClampByte:=Byte(Trunc(V+0.5));
End;
Procedure ConvertRowToYCbCr(Y8:PByteArr;Cb8:PByteArr;Cr8:PByteArr;
                            DstRowOffset:Word);
Var
 X:Word;
 R, G, B:Byte;
 YV, CbV, CrV:Real;
 LastB, LastG, LastR:Byte;
Begin
 LastB:=0; LastG:=0; LastR:=0;
 For X:=0 to StripeWidth-1 Do Begin
  If X<ImageWidth Then Begin
   B:=LineBuf[X*3];
   G:=LineBuf[X*3+1];
   R:=LineBuf[X*3+2];
   LastB:=B; LastG:=G; LastR:=R;
  End
   Else
  Begin
   B:=LastB; G:=LastG; R:=LastR;
  End;
  YV :=  0.299*R+0.587*G+0.114*B;
  CbV:= -0.168736*R-0.331264*G+0.5*B+128.0;
  CrV:=  0.5*R-0.418688*G-0.081312*B+128.0;
  Y8^[DstRowOffset+X]:=ClampByte(YV);
  Cb8^[DstRowOffset+X]:=ClampByte(CbV);
  Cr8^[DstRowOffset+X]:=ClampByte(CrV);
 End;
End;
Procedure ExtractBlock(Buf:PByteArr;ColX:Word;ValidRows:Word;Var Block:Block64);
Var
 R, C:Integer;
 SrcRow:Word;
Begin
 For R:=0 to 7 Do Begin
  If Word(R)<ValidRows Then SrcRow:=Word(R)
                       Else SrcRow:=ValidRows-1;
  For C:=0 to 7 Do
   Block[R*8+C]:=Integer(Buf^[SrcRow*StripeWidth+ColX+Word(C)])-128;
 End;
End;
Procedure WriteJFIFHeader;
Var
 ID:Array[0..4]of Char;
Begin
 WriteMarker(MarkerAPP0);
 WriteWordToFile(16);
 ID[0]:='J'; ID[1]:='F'; ID[2]:='I'; ID[3]:='F'; ID[4]:=#0;
 WriteRaw(ID, 5);
 WriteByteToFile(1);
 WriteByteToFile(1);
 WriteByteToFile(0);
 WriteWordToFile(1);
 WriteWordToFile(1);
 WriteByteToFile(0);
 WriteByteToFile(0);
End;
Procedure WriteDQT(TableID:Byte;Const QT:Array of Byte);
Var
 I:Integer;
 B:Byte;
Begin
 WriteMarker(MarkerDQT);
 WriteWordToFile(67);
 WriteByteToFile(TableID);
 For I:=0 to 63 Do Begin
  B:=QT[ZigZag[I]];
  WriteByteToFile(B);
 End;
End;
Procedure WriteSOF0;
Begin
 WriteMarker(MarkerSOF0);
 WriteWordToFile(17);
 WriteByteToFile(8);
 WriteWordToFile(ImageHeight);
 WriteWordToFile(ImageWidth);
 WriteByteToFile(3);
 WriteByteToFile(1); WriteByteToFile($11); WriteByteToFile(0);
 WriteByteToFile(2); WriteByteToFile($11); WriteByteToFile(1);
 WriteByteToFile(3); WriteByteToFile($11); WriteByteToFile(1);
End;
Procedure WriteDHT(TableClassAndID:Byte;Const Counts:Array of Byte;
                   Const Values:Array of Byte;NumValues:Integer);
Var
 I:Integer;
Begin
 WriteMarker(MarkerDHT);
 WriteWordToFile(Word(2+1+16+NumValues));
 WriteByteToFile(TableClassAndID);
 For I:=0 to 15 Do WriteByteToFile(Counts[I]);
 For I:=0 to NumValues-1 Do WriteByteToFile(Values[I]);
End;
Procedure WriteSOS;
Begin
 WriteMarker(MarkerSOS);
 WriteWordToFile(12);
 WriteByteToFile(3);
 WriteByteToFile(1); WriteByteToFile($00);
 WriteByteToFile(2); WriteByteToFile($11);
 WriteByteToFile(3); WriteByteToFile($11);
 WriteByteToFile(0);
 WriteByteToFile(63);
 WriteByteToFile(0);
End;
Begin
 SaveJPEG:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 ImageWidth:=CanvasImageW;ImageHeight:=CanvasImageH;
 StripeWidth:=((ImageWidth+7) Shr 3) Shl 3;
 StripeBytes:=StripeWidth*8;
 YBuf:=JDAllocate(StripeBytes);CbBuf:=JDAllocate(StripeBytes);
 CrBuf:=JDAllocate(StripeBytes);
 If (YBuf<>Nil) And (CbBuf<>Nil) And (CrBuf<>Nil) Then Begin
  InitCosTab;BuildQuantTables(90);BuildAllHuffTables;
  Assign(DestJPEG, FileName);{$I-}Rewrite(DestJPEG, 1);{$I+}
  If IOResult=0 Then Begin
   Failed:=False;OutputCount:=0;
 WriteMarker(MarkerSOI);
 WriteJFIFHeader;
 WriteDQT($00, QTLuma);
 WriteDQT($01, QTChroma);
 WriteSOF0;
 WriteDHT($00, StdDCLumaCounts, StdDCLumaValues, 12);
 WriteDHT($10, StdACLumaCounts, StdACLumaValues, 162);
 WriteDHT($01, StdDCChromaCounts, StdDCChromaValues, 12);
 WriteDHT($11, StdACChromaCounts, StdACChromaValues, 162);
 WriteSOS;
 BitBuffer:=0;
 BitsInBuffer:=0;
 PrevDCY:=0; PrevDCCb:=0; PrevDCCr:=0;
 Y:=0;
 While (Y<LongInt(ImageHeight)) And Not Failed Do Begin
  If Y+8<=LongInt(ImageHeight)Then ValidRows:=8
                              Else ValidRows:=Word(LongInt(ImageHeight)-Y);
  For Y2:=0 to LongInt(ValidRows)-1 Do Begin
   SourceRow:=Y+Y2;
   ReadBmpRowAsRGB(SourceRow);
   ConvertRowToYCbCr(YBuf, CbBuf, CrBuf, Word(Y2)*StripeWidth);
  End;
  MCUCol:=0;
  While MCUCol<StripeWidth Do Begin
   ExtractBlock(YBuf, MCUCol, ValidRows, BlockY);
   ForwardDCT(BlockY);
   QuantizeAndZigZag(BlockY, QTLuma, ZZBlock);
   EncodeBlock(ZZBlock, PrevDCY, DCLumaCode, DCLumaSize, 
               ACLumaCode, ACLumaSize);
   ExtractBlock(CbBuf, MCUCol, ValidRows, BlockCb);
   ForwardDCT(BlockCb);
   QuantizeAndZigZag(BlockCb, QTChroma, ZZBlock);
   EncodeBlock(ZZBlock, PrevDCCb, DCChromaCode, DCChromaSize, 
               ACChromaCode, ACChromaSize);
   ExtractBlock(CrBuf, MCUCol, ValidRows, BlockCr);
   ForwardDCT(BlockCr);
   QuantizeAndZigZag(BlockCr, QTChroma, ZZBlock);
   EncodeBlock(ZZBlock, PrevDCCr, DCChromaCode, DCChromaSize, 
               ACChromaCode, ACChromaSize);
   Inc(MCUCol, 8);
  End;
  Inc(Y, 8);
 End;
 FlushBits;
 WriteMarker(MarkerEOI);
   FlushOutput;
   {$I-}Close(DestJPEG);{$I+}If IOResult<>0 Then Failed:=True;
   SaveJPEG:=Not Failed;
  End;
 End;
 If YBuf<>Nil Then FreeMem(YBuf, StripeBytes);
 If CbBuf<>Nil Then FreeMem(CbBuf, StripeBytes);
 If CrBuf<>Nil Then FreeMem(CrBuf, StripeBytes);
End;

{ Pascal Bitmap : constantes compatibles avec les convertisseurs *2PAS.
  Palette RGB explicite et donnees indexees, sans perte de couleur. }
Function SavePAS(FileName: String): Boolean;
Const HexDigits: String[16]='0123456789ABCDEF';
Var F:File; Buffer:Array[0..8191] Of Byte; Used:Integer;
    Failed:Boolean; I,X,Y:Integer; N,Total:LongInt; Line:String;
 Procedure Flush;
 Var Written:LongInt;
 Begin
  If Failed Or (Used=0) Then Exit;
  {$I-}BlockWrite(F,Buffer,Used,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Used);Used:=0;
 End;
 Procedure PutLine(Const S:String);
 Var J:Integer; Text:String;
 Begin
  If Failed Then Exit;Text:=S+#13+#10;
  For J:=1 To Length(Text) Do Begin
   Buffer[Used]:=Ord(Text[J]);Inc(Used);
   If Used=SizeOf(Buffer) Then Flush;
   If Failed Then Exit;
  End;
 End;
 Procedure PutValue(Value:Byte; Last:Boolean);
 Begin
  Line:=Line+'$'+HexDigits[(Value Shr 4)+1]+
   HexDigits[(Value And 15)+1];
  If Not Last Then Line:=Line+',';
  If (Length(Line)>=65) Or Last Then Begin
   PutLine(Line);Line:='  ';
  End;
 End;
Begin
 SavePAS:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Used:=0;Failed:=False;Total:=LongInt(CanvasImageW)*CanvasImageH;
 PutLine('{ Pascal Bitmap - PAINT / CloneDRAW }');PutLine('Const');
 PutLine(' NumXPixels = '+IntToStr(CanvasImageW)+';');
 PutLine(' NumYPixels = '+IntToStr(CanvasImageH)+';');
 PutLine(' BitsPerPixel = 8;');
 PutLine(' BytesPerLine = '+IntToStr(CanvasImageW)+';');
 PutLine(' { Palette RGB : rouge, vert, bleu pour chaque index. }');
 PutLine(' BitmapPalette: Array[0..767] Of Byte = (');Line:='  ';
 For I:=0 To 255 Do Begin
  PutValue(ImageBuffer.Palette[I].R,False);
  PutValue(ImageBuffer.Palette[I].G,False);
  PutValue(ImageBuffer.Palette[I].B,I=255);
 End;
 PutLine(' );');
 PutLine(' { Pixels : de gauche a droite, lignes de haut en bas. }');
 PutLine(' BitmapData: Array[0..'+IntToStr(Total-1)+'] Of Byte = (');
 Line:='  ';N:=0;
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;
  For X:=0 To CanvasImageW-1 Do Begin
   Inc(N);PutValue(ZImagePixel(X,Y),N=Total);
   If Failed Then Break;
  End;
 End;
 PutLine(' );');Flush;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SavePAS:=Not Failed;
End;


{ BGX1 MonsterBook : RGB 24 bits, lignes de haut en bas, sans palette. }
Function SaveBGX(FileName: String): Boolean;
Var F:File; Header:Array[0..8] Of Byte;
    Row:Array[0..12287] Of Byte; X,Y:Integer; C:TRGBColor;
    Written,RowSize:LongInt; Failed:Boolean;
 Procedure WriteBytes(Var Buffer; Count:LongInt);
 Begin
  If Failed Then Exit;
  {$I-}BlockWrite(F,Buffer,Count,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Count);
 End;
Begin
 SaveBGX:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 Header[0]:=Ord('B');Header[1]:=Ord('G');
 Header[2]:=Ord('X');Header[3]:=Ord('1');
 Header[4]:=CanvasImageW And 255;Header[5]:=CanvasImageW Shr 8;
 Header[6]:=CanvasImageH And 255;Header[7]:=CanvasImageH Shr 8;
 Header[8]:=24;RowSize:=LongInt(CanvasImageW)*3;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Failed:=False;WriteBytes(Header,SizeOf(Header));
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;
  For X:=0 To CanvasImageW-1 Do Begin
   C:=ImageBuffer.Palette[ZImagePixel(X,Y)];
   Row[X*3]:=C.R;Row[X*3+1]:=C.G;Row[X*3+2]:=C.B;
  End;
  WriteBytes(Row,RowSize);
 End;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveBGX:=Not Failed;
End;


{ X Bitmap standard : un bit par pixel, noir=1, bit faible en premier. }
Function SaveXBM(FileName: String): Boolean;
Const HexDigits:String[16]='0123456789ABCDEF';
Var F:File; Buffer:Array[0..8191] Of Byte; Used:Integer;
    Failed:Boolean; X,Y,K,Stride,V:Integer; C:TRGBColor;
    Line:String;
 Procedure Flush;
 Var Written:LongInt;
 Begin
  If Failed Or (Used=0) Then Exit;
  {$I-}BlockWrite(F,Buffer,Used,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Used);Used:=0;
 End;
 Procedure PutLine(Const S:String);
 Var J:Integer; T:String;
 Begin
  If Failed Then Exit;T:=S+#13+#10;
  For J:=1 To Length(T) Do Begin
   Buffer[Used]:=Ord(T[J]);Inc(Used);
   If Used=SizeOf(Buffer) Then Flush;
   If Failed Then Exit;
  End;
 End;
Begin
 SaveXBM:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Used:=0;Failed:=False;Stride:=(CanvasImageW+7) Div 8;
 PutLine('#define paint_width '+IntToStr(CanvasImageW));
 PutLine('#define paint_height '+IntToStr(CanvasImageH));
 PutLine('static unsigned char paint_bits[] = {');Line:='  ';
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;
  For X:=0 To Stride-1 Do Begin
   V:=0;
   For K:=0 To 7 Do If X*8+K<CanvasImageW Then Begin
    C:=ImageBuffer.Palette[ZImagePixel(X*8+K,Y)];
    If LongInt(C.R)*299+LongInt(C.G)*587+LongInt(C.B)*114<128000
     Then V:=V Or (1 Shl K);
   End;
   Line:=Line+'0x'+HexDigits[(V Shr 4)+1]+HexDigits[(V And 15)+1];
   If (Y<CanvasImageH-1) Or (X<Stride-1) Then Line:=Line+',';
   If Length(Line)>=62 Then Begin PutLine(Line);Line:='  ';End;
  End;
 End;
 If Length(Line)>2 Then PutLine(Line);
 PutLine('};');Flush;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveXBM:=Not Failed;
End;


{ PPM P6 : RGB 24 bits binaire, maximum 255, lignes de haut en bas. }
Function SavePPM(FileName: String): Boolean;
Var F:File; Header:String;
    Row:Array[0..12287] Of Byte; X,Y:Integer; C:TRGBColor;
    Written,RowSize:LongInt; Failed:Boolean;
 Procedure WriteBytes(Var Buffer; Count:LongInt);
 Begin
  If Failed Then Exit;
  {$I-}BlockWrite(F,Buffer,Count,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Count);
 End;
Begin
 SavePPM:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 Header:='P6'#10+IntToStr(CanvasImageW)+' '+
  IntToStr(CanvasImageH)+#10+'255'#10;
 RowSize:=LongInt(CanvasImageW)*3;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Failed:=False;WriteBytes(Header[1],Length(Header));
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;
  For X:=0 To CanvasImageW-1 Do Begin
   C:=ImageBuffer.Palette[ZImagePixel(X,Y)];
   Row[X*3]:=C.R;Row[X*3+1]:=C.G;Row[X*3+2]:=C.B;
  End;
  WriteBytes(Row,RowSize);
 End;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SavePPM:=Not Failed;
End;


{ ARW synthetique, suivant BMP2ARW : TIFF CFA RGGB 16 bits non compresse.
  Ce fichier ne recree ni les mesures capteur ni les MakerNotes Sony. }
Function SaveARW(FileName:String):Boolean;
Const MakeText='SONY'#0; ModelText='CloneDRAW synthetic RAW'#0;
 SoftwareText='CloneDRAW PAINT ARW'#0;
 CameraText='CloneDRAW synthetic RGGB'#0;
Var F:File;Buffer:Array[0..8191] Of Byte;Used,X,Y,I:Integer;
 Failed:Boolean;C:TRGBColor;V:Byte;
 XRes,YRes,MakePos,ModelPos,SoftPos,CameraPos,MatrixPos,StripPos:LongInt;
 Procedure Flush;
 Var Written:LongInt;
 Begin
  If Failed Or (Used=0) Then Exit;
  {$I-}BlockWrite(F,Buffer,Used,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Used);Used:=0;
 End;
 Procedure B(Value:Byte);
 Begin
  If Failed Then Exit;Buffer[Used]:=Value;Inc(Used);
  If Used=SizeOf(Buffer) Then Flush;
 End;
 Procedure W(Value:Word);
 Begin B(Value And 255);B(Value Shr 8);End;
 Procedure L(Value:LongWord);
 Begin W(Value And 65535);W(Value Shr 16);End;
 Procedure Entry(Tag,Kind:Word;Count,Value:LongWord);
 Begin W(Tag);W(Kind);L(Count);L(Value);End;
 Procedure TextData(Const S:String);
 Var J:Integer;
 Begin
  For J:=1 To Length(S) Do B(Ord(S[J]));
  If Odd(Length(S)) Then B(0);
 End;
Begin
 SaveARW:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 XRes:=314;YRes:=XRes+8;MakePos:=YRes+8;
 ModelPos:=MakePos+((Length(MakeText)+1) And $FFFE);
 SoftPos:=ModelPos+((Length(ModelText)+1) And $FFFE);
 CameraPos:=SoftPos+((Length(SoftwareText)+1) And $FFFE);
 MatrixPos:=CameraPos+((Length(CameraText)+1) And $FFFE);StripPos:=MatrixPos+72;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Used:=0;Failed:=False;
 W($4949);W(42);L(8);W(25);
 Entry(256,4,1,CanvasImageW);Entry(257,4,1,CanvasImageH);
 Entry(258,3,1,16);Entry(259,3,1,1);Entry(262,3,1,32803);
 Entry(271,2,Length(MakeText),MakePos);
 Entry(272,2,Length(ModelText),ModelPos);Entry(273,4,1,StripPos);
 Entry(277,3,1,1);Entry(278,4,1,CanvasImageH);
 Entry(279,4,1,LongInt(CanvasImageW)*CanvasImageH*2);
 Entry(282,5,1,XRes);Entry(283,5,1,YRes);Entry(296,3,1,2);
 Entry(305,2,Length(SoftwareText),SoftPos);
 Entry(33421,3,2,$00020002);Entry(33422,1,4,$02010100);
 Entry(50706,1,4,$00000401);Entry(50707,1,4,$00000101);
 Entry(50708,2,Length(CameraText),CameraPos);
 Entry(50710,1,3,$00020100);Entry(50711,3,1,1);
 Entry(50717,4,1,65535);Entry(50721,10,9,MatrixPos);
 Entry(50778,3,1,21);L(0);
 L(72);L(1);L(72);L(1);
 TextData(MakeText);TextData(ModelText);TextData(SoftwareText);
 TextData(CameraText);
 For I:=0 To 8 Do Begin
  If I In [0,4,8] Then L(1) Else L(0);L(1);
 End;
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;
  For X:=0 To CanvasImageW-1 Do Begin
   C:=ImageBuffer.Palette[ZImagePixel(X,Y)];
   If (Y And 1)=0 Then Begin
    If (X And 1)=0 Then V:=C.R Else V:=C.G;
   End Else Begin
    If (X And 1)=0 Then V:=C.G Else V:=C.B;
   End;
   W(Word(V)*257);
  End;
 End;
 Flush;{$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveARW:=Not Failed;
End;


{ CR2 synthetique : TIFF CFA RGGB 16 bits, suivant BMP2CR2.PAS. }
Function SaveCR2(FileName:String):Boolean;
Const MakeText='Canon'#0; ModelText='CloneDRAW synthetic RAW'#0;
 SoftwareText='CloneDRAW PAINT CR2'#0;

Var F:File;Buffer:Array[0..8191] Of Byte;Used,X,Y,I:Integer;
 Failed:Boolean;C:TRGBColor;V:Byte;DateText:String;
 Year,Month,Day,WeekDay,Hour,Minute,Second,Hundredth:Word;
 XRes,YRes,MakePos,ModelPos,SoftPos,DatePos,MatrixPos,StripPos:LongInt;
 Procedure Flush;
 Var Written:LongInt;
 Begin
  If Failed Or (Used=0) Then Exit;
  {$I-}BlockWrite(F,Buffer,Used,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Used);Used:=0;
 End;
 Procedure B(Value:Byte);
 Begin
  If Failed Then Exit;Buffer[Used]:=Value;Inc(Used);
  If Used=SizeOf(Buffer) Then Flush;
 End;
 Procedure W(Value:Word);
 Begin B(Value And 255);B(Value Shr 8);End;
 Procedure L(Value:LongWord);
 Begin W(Value And 65535);W(Value Shr 16);End;
 Procedure Entry(Tag,Kind:Word;Count,Value:LongWord);
 Begin W(Tag);W(Kind);L(Count);L(Value);End;
 Procedure TextData(Const S:String);
 Var J:Integer;
 Begin
  For J:=1 To Length(S) Do B(Ord(S[J]));
  If Odd(Length(S)) Then B(0);
 End;
Function Two(Value:Word):String;
 Var T:String;
 Begin T:=IntToStr(Value);If Length(T)<2 Then T:='0'+T;Two:=T;End;
Begin
 SaveCR2:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 GetDate(Year,Month,Day,WeekDay);
 GetTime(Hour,Minute,Second,Hundredth);
 DateText:=IntToStr(Year)+':'+Two(Month)+':'+Two(Day)+' '+
  Two(Hour)+':'+Two(Minute)+':'+Two(Second)+#0;
 XRes:=322;YRes:=XRes+8;MakePos:=YRes+8;
 ModelPos:=MakePos+((Length(MakeText)+1) And $FFFE);
 SoftPos:=ModelPos+((Length(ModelText)+1) And $FFFE);
 DatePos:=SoftPos+((Length(SoftwareText)+1) And $FFFE);
 MatrixPos:=DatePos+((Length(DateText)+1) And $FFFE);StripPos:=MatrixPos+72;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Used:=0;Failed:=False;
 W($4949);W(42);L(16);B(Ord('C'));B(Ord('R'));W(2);L(0);W(25);
 Entry(256,4,1,CanvasImageW);Entry(257,4,1,CanvasImageH);
 Entry(258,3,1,16);Entry(259,3,1,1);Entry(262,3,1,32803);
 Entry(271,2,Length(MakeText),MakePos);
 Entry(272,2,Length(ModelText),ModelPos);Entry(273,4,1,StripPos);
 Entry(274,3,1,1);Entry(277,3,1,1);Entry(278,4,1,CanvasImageH);
 Entry(279,4,1,LongInt(CanvasImageW)*CanvasImageH*2);
 Entry(282,5,1,XRes);Entry(283,5,1,YRes);Entry(284,3,1,1);Entry(296,3,1,2);
 Entry(305,2,Length(SoftwareText),SoftPos);
 Entry(306,2,Length(DateText),DatePos);
 Entry(33421,3,2,$00020002);Entry(33422,1,4,$02010100);


 Entry(50710,1,3,$00020100);Entry(50711,3,1,1);
 Entry(50714,4,1,0);Entry(50717,4,1,65535);Entry(50721,10,9,MatrixPos);
 L(0);
 L(72);L(1);L(72);L(1);
 TextData(MakeText);TextData(ModelText);TextData(SoftwareText);
 TextData(DateText);
 For I:=0 To 8 Do Begin
  If I In [0,4,8] Then L(1) Else L(0);L(1);
 End;
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;
  For X:=0 To CanvasImageW-1 Do Begin
   C:=ImageBuffer.Palette[ZImagePixel(X,Y)];
   If (Y And 1)=0 Then Begin
    If (X And 1)=0 Then V:=C.R Else V:=C.G;
   End Else Begin
    If (X And 1)=0 Then V:=C.G Else V:=C.B;
   End;
   W(Word(V)*257);
  End;
 End;
 Flush;{$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveCR2:=Not Failed;
End;


{ DICOM Part 10, Secondary Capture, Explicit VR Little Endian, RGB8. }
Var DCSaveSerial:LongInt;
Function SaveDCM(FileName:String):Boolean;
Const SOPClass='1.2.840.10008.5.1.4.1.1.7';
 TransferSyntax='1.2.840.10008.1.2.1';
 ImplementationUID='2.25.28377616209933487502189927845026860456';
Var F:File;Buffer:Array[0..8191] Of Byte;Used,I,X,Y:Integer;
 Failed:Boolean;Position,MetaEnd,PixelSize:LongInt;C:TRGBColor;
 Year,Month,Day,WeekDay,Hour,Minute,Second,Hundredth:Word;
 DateText,TimeText,InstanceUID,StudyUID,SeriesUID,BaseUID:String;
 Procedure Flush;
 Var Written:LongInt;
 Begin
  If Failed Or (Used=0) Then Exit;
  {$I-}BlockWrite(F,Buffer,Used,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Used);Used:=0;
 End;
 Procedure B(Value:Byte);
 Begin
  If Failed Then Exit;Buffer[Used]:=Value;Inc(Used);Inc(Position);
  If Used=SizeOf(Buffer) Then Flush;
 End;
 Procedure W(Value:Word);
 Begin B(Value And 255);B(Value Shr 8);End;
 Procedure L(Value:LongWord);
 Begin W(Value And 65535);W(Value Shr 16);End;
 Procedure TextData(Const S:String);
 Var J:Integer;
 Begin For J:=1 To Length(S) Do B(Ord(S[J]));End;
 Procedure Tag(Group,Element:Word;Const VR:String);
 Begin W(Group);W(Element);TextData(VR);End;
 Procedure TextElement(Group,Element:Word;Const VR,Value:String);
 Begin
  Tag(Group,Element,VR);W((Length(Value)+1) And $FFFE);
  TextData(Value);
  If Odd(Length(Value)) Then
   If VR='UI' Then B(0) Else B(32);
 End;
 Procedure US(Group,Element,Value:Word);
 Begin Tag(Group,Element,'US');W(2);W(Value);End;
 Function Two(Value:Word):String;
 Var T:String;
 Begin T:=IntToStr(Value);If Length(T)<2 Then T:='0'+T;Two:=T;End;
Begin
 SaveDCM:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 GetDate(Year,Month,Day,WeekDay);GetTime(Hour,Minute,Second,Hundredth);
 DateText:=IntToStr(Year)+Two(Month)+Two(Day);
 TimeText:=Two(Hour)+Two(Minute)+Two(Second)+'.'+Two(Hundredth);
 If DCSaveSerial>=999999 Then DCSaveSerial:=0;Inc(DCSaveSerial);
 BaseUID:='2.25.'+DateText+Two(Hour)+Two(Minute)+Two(Second)+
  Two(Hundredth)+IntToStr(DCSaveSerial)+IntToStr(Random(32768))+
  IntToStr(Random(32768));
 InstanceUID:=BaseUID+'1';StudyUID:=BaseUID+'2';SeriesUID:=BaseUID+'3';
 PixelSize:=LongInt(CanvasImageW)*CanvasImageH*3;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Failed:=False;Used:=0;Position:=0;
 For I:=1 To 128 Do B(0);TextData('DICM');
 Tag(2,0,'UL');W(4);L(0);
 Tag(2,1,'OB');W(0);L(2);B(0);B(1);
 TextElement(2,2,'UI',SOPClass);TextElement(2,3,'UI',InstanceUID);
 TextElement(2,16,'UI',TransferSyntax);
 TextElement(2,18,'UI',ImplementationUID);
 TextElement(2,19,'SH','CLONEDRAW_PAINT');MetaEnd:=Position;
 TextElement(8,8,'CS','DERIVED\SECONDARY');
 TextElement(8,22,'UI',SOPClass);TextElement(8,24,'UI',InstanceUID);
 TextElement(8,32,'DA',DateText);TextElement(8,35,'DA',DateText);
 TextElement(8,48,'TM',TimeText);TextElement(8,51,'TM',TimeText);
 TextElement(8,80,'SH','');TextElement(8,96,'CS','OT');
 TextElement(8,100,'CS','WSD');
 TextElement(8,112,'LO','CloneDRAW');TextElement(8,144,'PN','');
 TextElement(8,$103E,'LO','CloneDRAW canvas export');
 TextElement(16,16,'PN','');TextElement(16,32,'LO','');
 TextElement(16,48,'DA','');TextElement(16,64,'CS','');
 TextElement(32,13,'UI',StudyUID);TextElement(32,14,'UI',SeriesUID);
 TextElement(32,16,'SH','');TextElement(32,17,'IS','1');
 TextElement(32,19,'IS','1');US(40,2,3);
 TextElement(40,4,'CS','RGB');US(40,6,0);
 US(40,16,CanvasImageH);US(40,17,CanvasImageW);
 US(40,256,8);US(40,257,8);US(40,258,7);US(40,259,0);
 TextElement(40,$2110,'CS','00');
 Tag($7FE0,16,'OB');W(0);L((PixelSize+1) And $FFFFFFFE);
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;
  For X:=0 To CanvasImageW-1 Do Begin
   C:=ImageBuffer.Palette[ZImagePixel(X,Y)];B(C.R);B(C.G);B(C.B);
  End;
 End;
 If Odd(PixelSize) Then B(0);Flush;
 If Not Failed Then Begin
  {$I-}Seek(F,140);{$I+}Failed:=IOResult<>0;
  If Not Failed Then Begin L(MetaEnd-144);Flush;End;
 End;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveDCM:=Not Failed;
End;


{ DDS classique A8R8G8B8 non compresse, une texture 2D sans mipmaps. }
Function SaveDDS(FileName:String):Boolean;
Var F:File;Header:Array[0..127] Of Byte;
 Row:Array[0..16383] Of Byte;X,Y:Integer;C:TRGBColor;
 Written,RowSize:LongInt;Failed:Boolean;
 Procedure PutLong(P:Integer;V:LongWord);
 Begin
  Header[P]:=V And 255;Header[P+1]:=(V Shr 8) And 255;
  Header[P+2]:=(V Shr 16) And 255;Header[P+3]:=V Shr 24;
 End;
 Procedure WriteBytes(Var Buffer;Count:LongInt);
 Begin
  If Failed Then Exit;
  {$I-}BlockWrite(F,Buffer,Count,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Count);
 End;
Begin
 SaveDDS:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 FillChar(Header,SizeOf(Header),0);
 Header[0]:=Ord('D');Header[1]:=Ord('D');Header[2]:=Ord('S');
 Header[3]:=32;RowSize:=LongInt(CanvasImageW)*4;
 PutLong(4,124);PutLong(8,$100F);PutLong(12,CanvasImageH);
 PutLong(16,CanvasImageW);PutLong(20,RowSize);
 PutLong(76,32);PutLong(80,$41);PutLong(88,32);
 PutLong(92,$00FF0000);PutLong(96,$0000FF00);
 PutLong(100,$000000FF);PutLong(104,$FF000000);PutLong(108,$1000);
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Failed:=False;WriteBytes(Header,SizeOf(Header));
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;
  For X:=0 To CanvasImageW-1 Do Begin
   C:=ImageBuffer.Palette[ZImagePixel(X,Y)];
   Row[X*4]:=C.B;Row[X*4+1]:=C.G;Row[X*4+2]:=C.R;
   Row[X*4+3]:=255;
  End;
  WriteBytes(Row,RowSize);
 End;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveDDS:=Not Failed;
End;


{ WPG1 : profil BMP2WPG / PCX2WPG, palette RGB, bitmap 8 bits RLE.
  Les paquets litteraux sont limites a 127 octets et a une seule ligne. }
Function SaveWPG(FileName:String):Boolean;
Var F:File;Buffer:Array[0..8191] Of Byte;Used,I,X,Y,N,J:Integer;
 Failed:Boolean;BitmapSize:LongInt;
 Procedure Flush;
 Var Written:LongInt;
 Begin
  If Failed Or (Used=0) Then Exit;
  {$I-}BlockWrite(F,Buffer,Used,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Used);Used:=0;
 End;
 Procedure B(V:Byte);
 Begin
  If Failed Then Exit;Buffer[Used]:=V;Inc(Used);
  If Used=SizeOf(Buffer) Then Flush;
 End;
 Procedure W(V:Word);
 Begin B(V Shr 8);B(V And 255);End;
 Procedure RecordHeader(Kind:Byte;Size:LongInt);
 Begin
  B(Kind);
  If Size<255 Then B(Size)
  Else Begin
   B(255);
   If Size<=32767 Then W(Size)
   Else Begin W($8000 Or (Size Shr 16));W(Size And 65535);End;
  End;
 End;
Begin
 SaveWPG:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 BitmapSize:=10+(LongInt(CanvasImageW)+
  (LongInt(CanvasImageW)+126) Div 127)*CanvasImageH;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Failed:=False;Used:=0;
 B(255);B(87);B(80);B(67);W(0);W(16);
 B(1);B(22);B(1);B(0);W(0);W(0);
 RecordHeader(15,6);B(1);B(0);
 W(Word(LongInt(CanvasImageW)*8));W(Word(LongInt(CanvasImageH)*8));
 RecordHeader(14,772);W(0);W(256);
 For I:=0 To 255 Do Begin
  B(ImageBuffer.Palette[I].R);B(ImageBuffer.Palette[I].G);
  B(ImageBuffer.Palette[I].B);
 End;
 RecordHeader(11,BitmapSize);W(CanvasImageW);W(CanvasImageH);
 W(8);W(150);W(150);
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;X:=0;
  While X<CanvasImageW Do Begin
   N:=CanvasImageW-X;If N>127 Then N:=127;B(N);
   For J:=0 To N-1 Do B(ZImagePixel(X+J,Y));Inc(X,N);
  End;
 End;
 RecordHeader(16,0);Flush;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveWPG:=Not Failed;
End;


{ OpenEXR v2 scanline, B/G/R HALF, non compresse, profil BMP2EXR. }
Function SaveEXR(FileName:String):Boolean;
Var F:File;Buffer:Array[0..8191] Of Byte;Used,X,Y,Channel,I:Integer;
 Failed:Boolean;Position,Offset,ChunkSize:LongInt;C:TRGBColor;
 Half:Array[0..255] Of Word;
 Procedure Flush;
 Var Written:LongInt;
 Begin
  If Failed Or (Used=0) Then Exit;
  {$I-}BlockWrite(F,Buffer,Used,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Used);Used:=0;
 End;
 Procedure B(V:Byte);
 Begin
  If Failed Then Exit;Buffer[Used]:=V;Inc(Used);Inc(Position);
  If Used=SizeOf(Buffer) Then Flush;
 End;
 Procedure W(V:Word);
 Begin B(V And 255);B(V Shr 8);End;
 Procedure L(V:LongWord);
 Begin W(V And 65535);W(V Shr 16);End;
 Procedure CString(Const S:String);
 Var J:Integer;
 Begin For J:=1 To Length(S) Do B(Ord(S[J]));B(0);End;
 Procedure Attribute(Const Name,Kind:String;Size:LongInt);
 Begin CString(Name);CString(Kind);L(Size);End;
 Procedure WriteChannel(Const Name:String);
 Begin CString(Name);L(1);L(0);L(1);L(1);End;
 Procedure Window(Const Name:String);
 Begin
  Attribute(Name,'box2i',16);L(0);L(0);
  L(CanvasImageW-1);L(CanvasImageH-1);
 End;
 Function ByteToHalf(Value:Byte):Word;
 Var V:Double;Exponent:Integer;Mantissa:LongInt;
 Begin
  ByteToHalf:=0;If Value=0 Then Exit;
  V:=Value/255.0;Exponent:=0;
  While V<1 Do Begin V:=V*2;Dec(Exponent);End;
  Mantissa:=Round((V-1)*1024);
  If Mantissa=1024 Then Begin Mantissa:=0;Inc(Exponent);End;
  ByteToHalf:=((Exponent+15) Shl 10) Or Mantissa;
 End;
Begin
 SaveEXR:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 For I:=0 To 255 Do Half[I]:=ByteToHalf(I);
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Used:=0;Position:=0;Failed:=False;
 L(20000630);L(2);Attribute('channels','chlist',55);
 WriteChannel('B');WriteChannel('G');WriteChannel('R');B(0);
 Attribute('compression','compression',1);B(0);
 Window('dataWindow');Window('displayWindow');
 Attribute('lineOrder','lineOrder',1);B(0);
 Attribute('pixelAspectRatio','float',4);L($3F800000);
 Attribute('screenWindowCenter','v2f',8);L(0);L(0);
 Attribute('screenWindowWidth','float',4);L($3F800000);B(0);
 Offset:=Position+LongInt(CanvasImageH)*8;
 ChunkSize:=8+LongInt(CanvasImageW)*6;
 For Y:=0 To CanvasImageH-1 Do Begin L(Offset);L(0);Inc(Offset,ChunkSize);End;
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;L(Y);L(LongInt(CanvasImageW)*6);
  For Channel:=0 To 2 Do For X:=0 To CanvasImageW-1 Do Begin
   C:=ImageBuffer.Palette[ZImagePixel(X,Y)];
   Case Channel Of 0:W(Half[C.B]);1:W(Half[C.G]);2:W(Half[C.R]);End;
  End;
 End;
 Flush;{$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveEXR:=Not Failed;
End;


{ FAX brut CCITT T.4 Group 3 1D, suivant BMP2FAX.PAS. }
Function SaveFAX(FileName:String):Boolean;
Const EOLCode='000000000001';
Var F:File;Buffer:Array[0..8191] Of Byte;Used,X,Y,I:Integer;
 Failed,CurrentBlack,NewBlack:Boolean;Run:Word;C:TRGBColor;
 OutByte:Byte;OutBits:Integer;
 Procedure Flush;
 Var Written:LongInt;
 Begin
  If Failed Or (Used=0) Then Exit;
  {$I-}BlockWrite(F,Buffer,Used,Written);{$I+}
  Failed:=(IOResult<>0) Or (Written<>Used);Used:=0;
 End;
 Procedure Emit(B:Byte);
 Begin
  If Failed Then Exit;Buffer[Used]:=B;Inc(Used);
  If Used=SizeOf(Buffer) Then Flush;
 End;
 Procedure WriteCode(Const Code:String);
 Var J:Integer;
 Begin
  For J:=1 To Length(Code) Do Begin
   OutByte:=(OutByte Shl 1) Or Ord(Code[J]='1');Inc(OutBits);
   If OutBits=8 Then Begin Emit(OutByte);OutByte:=0;OutBits:=0;End;
  End;
 End;
Function WhiteTerminatingCode(Run:Byte):String;
Begin
 Case Run of
  0:WhiteTerminatingCode:='00110101'; 1:WhiteTerminatingCode:='000111';
  2:WhiteTerminatingCode:='0111'; 3:WhiteTerminatingCode:='1000';
  4:WhiteTerminatingCode:='1011'; 5:WhiteTerminatingCode:='1100';
  6:WhiteTerminatingCode:='1110'; 7:WhiteTerminatingCode:='1111';
  8:WhiteTerminatingCode:='10011'; 9:WhiteTerminatingCode:='10100';
  10:WhiteTerminatingCode:='00111'; 11:WhiteTerminatingCode:='01000';
  12:WhiteTerminatingCode:='001000'; 13:WhiteTerminatingCode:='000011';
  14:WhiteTerminatingCode:='110100'; 15:WhiteTerminatingCode:='110101';
  16:WhiteTerminatingCode:='101010'; 17:WhiteTerminatingCode:='101011';
  18:WhiteTerminatingCode:='0100111'; 19:WhiteTerminatingCode:='0001100';
  20:WhiteTerminatingCode:='0001000'; 21:WhiteTerminatingCode:='0010111';
  22:WhiteTerminatingCode:='0000011'; 23:WhiteTerminatingCode:='0000100';
  24:WhiteTerminatingCode:='0101000'; 25:WhiteTerminatingCode:='0101011';
  26:WhiteTerminatingCode:='0010011'; 27:WhiteTerminatingCode:='0100100';
  28:WhiteTerminatingCode:='0011000'; 29:WhiteTerminatingCode:='00000010';
  30:WhiteTerminatingCode:='00000011'; 31:WhiteTerminatingCode:='00011010';
  32:WhiteTerminatingCode:='00011011'; 33:WhiteTerminatingCode:='00010010';
  34:WhiteTerminatingCode:='00010011'; 35:WhiteTerminatingCode:='00010100';
  36:WhiteTerminatingCode:='00010101'; 37:WhiteTerminatingCode:='00010110';
  38:WhiteTerminatingCode:='00010111'; 39:WhiteTerminatingCode:='00101000';
  40:WhiteTerminatingCode:='00101001'; 41:WhiteTerminatingCode:='00101010';
  42:WhiteTerminatingCode:='00101011'; 43:WhiteTerminatingCode:='00101100';
  44:WhiteTerminatingCode:='00101101'; 45:WhiteTerminatingCode:='00000100';
  46:WhiteTerminatingCode:='00000101'; 47:WhiteTerminatingCode:='00001010';
  48:WhiteTerminatingCode:='00001011'; 49:WhiteTerminatingCode:='01010010';
  50:WhiteTerminatingCode:='01010011'; 51:WhiteTerminatingCode:='01010100';
  52:WhiteTerminatingCode:='01010101'; 53:WhiteTerminatingCode:='00100100';
  54:WhiteTerminatingCode:='00100101'; 55:WhiteTerminatingCode:='01011000';
  56:WhiteTerminatingCode:='01011001'; 57:WhiteTerminatingCode:='01011010';
  58:WhiteTerminatingCode:='01011011'; 59:WhiteTerminatingCode:='01001010';
  60:WhiteTerminatingCode:='01001011'; 61:WhiteTerminatingCode:='00110010';
  62:WhiteTerminatingCode:='00110011'; Else WhiteTerminatingCode:='00110100';
 End;
End;

Function BlackTerminatingCode(Run:Byte):String;
Begin
 Case Run of
  0:BlackTerminatingCode:='0000110111'; 1:BlackTerminatingCode:='010';
  2:BlackTerminatingCode:='11'; 3:BlackTerminatingCode:='10';
  4:BlackTerminatingCode:='011'; 5:BlackTerminatingCode:='0011';
  6:BlackTerminatingCode:='0010'; 7:BlackTerminatingCode:='00011';
  8:BlackTerminatingCode:='000101'; 9:BlackTerminatingCode:='000100';
  10:BlackTerminatingCode:='0000100'; 11:BlackTerminatingCode:='0000101';
  12:BlackTerminatingCode:='0000111'; 13:BlackTerminatingCode:='00000100';
  14:BlackTerminatingCode:='00000111'; 15:BlackTerminatingCode:='000011000';
  16:BlackTerminatingCode:='0000010111'; 17:BlackTerminatingCode:='0000011000';
  18:BlackTerminatingCode:='0000001000'; 19:BlackTerminatingCode:='00001100111';
  20:BlackTerminatingCode:='00001101000';
  21:BlackTerminatingCode:='00001101100';
  22:BlackTerminatingCode:='00000110111';
  23:BlackTerminatingCode:='00000101000';
  24:BlackTerminatingCode:='00000010111';
  25:BlackTerminatingCode:='00000011000';
  26:BlackTerminatingCode:='000011001010';
  27:BlackTerminatingCode:='000011001011';
  28:BlackTerminatingCode:='000011001100';
  29:BlackTerminatingCode:='000011001101';
  30:BlackTerminatingCode:='000001101000';
  31:BlackTerminatingCode:='000001101001';
  32:BlackTerminatingCode:='000001101010';
  33:BlackTerminatingCode:='000001101011';
  34:BlackTerminatingCode:='000011010010';
  35:BlackTerminatingCode:='000011010011';
  36:BlackTerminatingCode:='000011010100';
  37:BlackTerminatingCode:='000011010101';
  38:BlackTerminatingCode:='000011010110';
  39:BlackTerminatingCode:='000011010111';
  40:BlackTerminatingCode:='000001101100';
  41:BlackTerminatingCode:='000001101101';
  42:BlackTerminatingCode:='000011011010';
  43:BlackTerminatingCode:='000011011011';
  44:BlackTerminatingCode:='000001010100';
  45:BlackTerminatingCode:='000001010101';
  46:BlackTerminatingCode:='000001010110';
  47:BlackTerminatingCode:='000001010111';
  48:BlackTerminatingCode:='000001100100';
  49:BlackTerminatingCode:='000001100101';
  50:BlackTerminatingCode:='000001010010';
  51:BlackTerminatingCode:='000001010011';
  52:BlackTerminatingCode:='000000100100';
  53:BlackTerminatingCode:='000000110111';
  54:BlackTerminatingCode:='000000111000';
  55:BlackTerminatingCode:='000000100111';
  56:BlackTerminatingCode:='000000101000';
  57:BlackTerminatingCode:='000001011000';
  58:BlackTerminatingCode:='000001011001';
  59:BlackTerminatingCode:='000000101011';
  60:BlackTerminatingCode:='000000101100';
  61:BlackTerminatingCode:='000001011010';
  62:BlackTerminatingCode:='000001100110'; Else
  BlackTerminatingCode:='000001100111';
 End;
End;

Function MakeupCode(Run:Word;Black:Boolean):String;
Begin
 Case Run of
  64:If Black Then MakeupCode:='0000001111'Else MakeupCode:='11011';
  128:If Black Then MakeupCode:='000011001000'Else MakeupCode:='10010';
  192:If Black Then MakeupCode:='000011001001'Else MakeupCode:='010111';
  256:If Black Then MakeupCode:='000001011011'Else MakeupCode:='0110111';
  320:If Black Then MakeupCode:='000000110011'Else MakeupCode:='00110110';
  384:If Black Then MakeupCode:='000000110100'Else MakeupCode:='00110111';
  448:If Black Then MakeupCode:='000000110101'Else MakeupCode:='01100100';
  512:If Black Then MakeupCode:='0000001101100'Else MakeupCode:='01100101';
  576:If Black Then MakeupCode:='0000001101101'Else MakeupCode:='01101000';
  640:If Black Then MakeupCode:='0000001001010'Else MakeupCode:='01100111';
  704:If Black Then MakeupCode:='0000001001011'Else MakeupCode:='011001100';
  768:If Black Then MakeupCode:='0000001001100'Else MakeupCode:='011001101';
  832:If Black Then MakeupCode:='0000001001101'Else MakeupCode:='011010010';
  896:If Black Then MakeupCode:='0000001110010'Else MakeupCode:='011010011';
  960:If Black Then MakeupCode:='0000001110011'Else MakeupCode:='011010100';
  1024:If Black Then MakeupCode:='0000001110100'Else MakeupCode:='011010101';
  1088:If Black Then MakeupCode:='0000001110101'Else MakeupCode:='011010110';
  1152:If Black Then MakeupCode:='0000001110110'Else MakeupCode:='011010111';
  1216:If Black Then MakeupCode:='0000001110111'Else MakeupCode:='011011000';
  1280:If Black Then MakeupCode:='0000001010010'Else MakeupCode:='011011001';
  1344:If Black Then MakeupCode:='0000001010011'Else MakeupCode:='011011010';
  1408:If Black Then MakeupCode:='0000001010100'Else MakeupCode:='011011011';
  1472:If Black Then MakeupCode:='0000001010101'Else MakeupCode:='010011000';
  1536:If Black Then MakeupCode:='0000001011010'Else MakeupCode:='010011001';
  1600:If Black Then MakeupCode:='0000001011011'Else MakeupCode:='010011010';
  1664:If Black Then MakeupCode:='0000001100100'Else MakeupCode:='011000';
  1728:If Black Then MakeupCode:='0000001100101'Else MakeupCode:='010011011';
  1792:MakeupCode:='00000001000'; 1856:MakeupCode:='00000001100';
  1920:MakeupCode:='00000001101'; 1984:MakeupCode:='000000010010';
  2048:MakeupCode:='000000010011'; 2112:MakeupCode:='000000010100';
  2176:MakeupCode:='000000010101'; 2240:MakeupCode:='000000010110';
  2304:MakeupCode:='000000010111'; 2368:MakeupCode:='000000011100';
  2432:MakeupCode:='000000011101'; 2496:MakeupCode:='000000011110';
  Else MakeupCode:='000000011111';
 End;
End;

Procedure WriteRun(Run:Word;Black:Boolean);
Var
 Makeup:Word;
Begin
 While Run>=2560 Do Begin
  WriteCode(MakeupCode(2560,Black));
  Dec(Run,2560);
 End;
 If Run>=64 Then Begin
  Makeup:=(Run div 64)*64;
  WriteCode(MakeupCode(Makeup,Black));
  Run:=Run mod 64;
 End;
 If Black Then WriteCode(BlackTerminatingCode(Byte(Run)))
          Else WriteCode(WhiteTerminatingCode(Byte(Run)));
End;


Begin
 SaveFAX:=False;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>4096) Or (CanvasImageH>4096) Then Exit;
 Assign(F,FileName);{$I-}Rewrite(F,1);{$I+}If IOResult<>0 Then Exit;
 Used:=0;Failed:=False;OutByte:=0;OutBits:=0;
 For Y:=0 To CanvasImageH-1 Do Begin
  If Failed Then Break;WriteCode(EOLCode);CurrentBlack:=False;Run:=0;
  For X:=0 To CanvasImageW-1 Do Begin
   C:=ImageBuffer.Palette[ZImagePixel(X,Y)];
   NewBlack:=LongInt(C.R)*299+LongInt(C.G)*587+LongInt(C.B)*114<128000;
   If NewBlack=CurrentBlack Then Inc(Run)
   Else Begin WriteRun(Run,CurrentBlack);CurrentBlack:=NewBlack;Run:=1;End;
  End;
  WriteRun(Run,CurrentBlack);
 End;
 For I:=1 To 6 Do WriteCode(EOLCode);
 If OutBits<>0 Then Emit(OutByte Shl (8-OutBits));Flush;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 SaveFAX:=Not Failed;
End;


Function SaveImage(FileName: String; Format: Byte): Boolean;
Var Old: TImageBuffer; F,T,B: File; R: SearchRec; Folder,Temp,Backup: String;
    I,Pos,Code: Integer; Exists,OK,MovedOld: Boolean;
 Function Present(Const Name: String): Boolean;
 Begin
  FindFirst(Name,AnyFile,R); Present:=DosError=0;
  {$IFDEF FPC}FindClose(R);{$ENDIF}
 End;
 Procedure RemoveTemp;
 Begin
  Assign(T,Temp); {$I-}Erase(T);{$I+}If IOResult<>0 Then;
 End;
Begin
 SaveImage:=False; PaintSaveError:='';
 If ImageBuffer.Metadata.Limited And (Format In [FMT_GIF,FMT_PNG,FMT_APNG]) Then
 Begin
  PaintSaveError:='Textes longs ou Unicode : validez leur remplacement dans Proprietes avant de sauvegarder.'; Exit;
 End;
 If (CanvasImage=Nil) Or (CanvasImageW<1) Or (CanvasImageH<1) Or
    (CanvasImageW>MAX_IMAGE_WIDTH) Or (CanvasImageH>MAX_IMAGE_HEIGHT) Or
    (CanvasImageW<>ImageBuffer.Width) Or (CanvasImageH<>ImageBuffer.Height) Then Begin
  PaintSaveError:='Image absente ou dimensions incoherentes.'; Exit;
 End;
 If Not (Format In
 [FMT_BMP,FMT_GIF,FMT_PNG,FMT_PCX,FMT_JPEG,FMT_PAS,
 FMT_BGX,FMT_XBM,FMT_PPM,FMT_APNG,FMT_ARW,FMT_CR2,FMT_DCM,
 FMT_DDS,FMT_WPG,FMT_EXR,FMT_FAX])
 Then
 Begin
 PaintSaveError:='Choisissez un format propose dans Enregistrer sous.';
 Exit;
 End;
 Old:=ImageBuffer; Exists:=Present(FileName);
 If Exists And ((R.Attr And (Directory+ReadOnly))<>0) Then Begin PaintSaveError:='Cible en lecture seule ou dossier.'; Exit; End;
 Pos:=Length(FileName); While (Pos>0) And Not (FileName[Pos] In ['\','/']) Do Dec(Pos);
 Folder:=Copy(FileName,1,Pos); Temp:=''; Backup:='';
 For I:=0 To 9999 Do Begin
  Temp:=Folder+'~paint'+IntToStr(I)+'.tmp'; Backup:=Folder+'~paint'+IntToStr(I)+'.bak';
  If Not Present(Temp) And Not Present(Backup) And (Temp<>FileName) And (Backup<>FileName) Then Break;
 End;
 If (Length(Folder)>232) Or Present(Temp) Or Present(Backup) Then Begin PaintSaveError:='Impossible de creer un fichier temporaire.'; Exit; End;
 { Normaliser uniquement la sortie BMP : le document est toujours indexe,
   meme apres l'importation d'un PNG 16 bits ou d'un JPEG. }
 If Format=FMT_BMP Then ImageBuffer.BitDepth:=8;
 Case Format Of
  FMT_BMP: OK:=SaveBMP(Temp);
  FMT_GIF: OK:=SaveGIF(Temp);
  FMT_PCX: OK:=SavePCX(Temp);
  FMT_JPEG: OK:=SaveJPEG(Temp);
  FMT_PAS: OK:=SavePAS(Temp);
  FMT_BGX: OK:=SaveBGX(Temp);
  FMT_XBM: OK:=SaveXBM(Temp);
  FMT_PPM: OK:=SavePPM(Temp);
  FMT_APNG: OK:=SaveAPNG(Temp);
  FMT_ARW: OK:=SaveARW(Temp);
  FMT_CR2: OK:=SaveCR2(Temp);
  FMT_DCM: OK:=SaveDCM(Temp);
  FMT_DDS: OK:=SaveDDS(Temp);
  FMT_WPG: OK:=SaveWPG(Temp);
  FMT_EXR: OK:=SaveEXR(Temp);
  FMT_FAX: OK:=SaveFAX(Temp);
  Else OK:=SavePNG(Temp);
 End;
 ImageBuffer:=Old;
 If Not OK Then Begin RemoveTemp; PaintSaveError:='Ecriture impossible (acces, espace disque ou image invalide).'; Exit; End;
 MovedOld:=False;
 If Exists Then Begin
  Assign(F,FileName); {$I-}Rename(F,Backup);{$I+}Code:=IOResult;
  If Code<>0 Then Begin RemoveTemp; PaintSaveError:='Le fichier existant ne peut pas etre remplace.'; Exit; End;
  MovedOld:=True;
 End;
 Assign(T,Temp); {$I-}Rename(T,FileName);{$I+}Code:=IOResult;
 If Code<>0 Then Begin
  If MovedOld Then Begin
   Assign(B,Backup); {$I-}Rename(B,FileName);{$I+}
   If IOResult<>0 Then PaintSaveError:='Original conserve dans : '+Backup;
  End;
  RemoveTemp;
  If PaintSaveError='' Then PaintSaveError:='Impossible de finaliser le fichier.';
  Exit;
 End;
 If MovedOld Then Begin Assign(B,Backup); {$I-}Erase(B);{$I+}If IOResult<>0 Then; End;
 ImageBuffer.FileName:=FileName; ImageBuffer.Format:=Format; ImageBuffer.Modified:=False;
 SaveImage:=True;
End;


{ Procédures de manipulation d'image }

Procedure ResizeImage(NewWidth, NewHeight: Integer);
Begin
 If (NewWidth < 1) or (NewHeight < 1) Then Exit;
 If (NewWidth > MAX_IMAGE_WIDTH) or (NewHeight > MAX_IMAGE_HEIGHT) Then Exit;

 { Redimensionner l'image }
 ImageBuffer.Width := NewWidth;
 ImageBuffer.Height := NewHeight;
 ImageBuffer.Modified := True;

 RedrawInterface;
End;

Procedure CropImage;
Var
 L, T, R, B, NW, NH, X, Y: Integer;
 NewBuf: PByte;
Begin
 If Not SelectionActive Then Exit;
 If (CanvasImage = Nil) or (CanvasImageW <= 0) or (CanvasImageH <= 0) Then Exit;

 { Convertir SelectionRect (coords ecran) en coords canvas-buffer. }
 L := SelectionRect.Left - CanvasX;
 T := SelectionRect.Top - CanvasY;
 R := SelectionRect.Right - CanvasX;
 B := SelectionRect.Bottom - CanvasY;
 If L > R Then Begin X := L; L := R; R := X; End;
 If T > B Then Begin X := T; T := B; B := X; End;
 If L < 0 Then L := 0;
 If T < 0 Then T := 0;
 If R >= CanvasImageW Then R := CanvasImageW - 1;
 If B >= CanvasImageH Then B := CanvasImageH - 1;

 NW := R - L + 1;
 NH := B - T + 1;
 If (NW <= 0) or (NH <= 0) Then Begin
  SelectionActive := False;
  Exit;
 End;

 GetMem(NewBuf, NW * NH);
 For Y := 0 To NH - 1 Do
  For X := 0 To NW - 1 Do
   PByte(PtrUInt(NewBuf) + PtrUInt(Y) * PtrUInt(NW) + PtrUInt(X))^ :=
    PByte(PtrUInt(CanvasImage) +
          PtrUInt(T + Y) * PtrUInt(CanvasImageW) +
          PtrUInt(L + X))^;

 FreeMem(CanvasImage, CanvasImageW * CanvasImageH);
 CanvasImage := NewBuf;
 CanvasImageW := NW;
 CanvasImageH := NH;
 ImageBuffer.Width := NW;
 ImageBuffer.Height := NH;
 ImageBuffer.Modified := True;

 SelectionActive := False;
 RedrawInterface;
End;

Procedure SetColorDepth(Depth: Byte);
Begin
 Case Depth of
  DEPTH_2: ImageBuffer.BitDepth := 1;
  DEPTH_4: ImageBuffer.BitDepth := 2;
  DEPTH_8: ImageBuffer.BitDepth := 3;
  DEPTH_16: ImageBuffer.BitDepth := 4;
  DEPTH_32: ImageBuffer.BitDepth := 5;
  DEPTH_64: ImageBuffer.BitDepth := 6;
  DEPTH_128: ImageBuffer.BitDepth := 7;
  DEPTH_256: ImageBuffer.BitDepth := 8;
  DEPTH_4096: ImageBuffer.BitDepth := 12;
  DEPTH_32768: ImageBuffer.BitDepth := 15;
  DEPTH_65536: ImageBuffer.BitDepth := 16;
  DEPTH_16M: ImageBuffer.BitDepth := 24;
  DEPTH_32BIT: ImageBuffer.BitDepth := 32;
 End;
 ImageBuffer.Modified := True;
End;

Procedure FlipHorizontal;
Var
 X, Y: Integer;
 Row: PByte;
 T: Byte;
Begin
 If (CanvasImage = Nil) or (CanvasImageW <= 0) or (CanvasImageH <= 0) Then Exit;
 For Y := 0 To CanvasImageH - 1 Do Begin
  Row := PByte(PtrUInt(CanvasImage) + PtrUInt(Y) * PtrUInt(CanvasImageW));
  For X := 0 To (CanvasImageW Div 2) - 1 Do Begin
   T := PByte(PtrUInt(Row) + PtrUInt(X))^;
   PByte(PtrUInt(Row) + PtrUInt(X))^ :=
    PByte(PtrUInt(Row) + PtrUInt(CanvasImageW - 1 - X))^;
   PByte(PtrUInt(Row) + PtrUInt(CanvasImageW - 1 - X))^ := T;
  End;
 End;
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure FlipVertical;
Var
 X, Y: Integer;
 R1, R2: PByte;
 T: Byte;
Begin
 If (CanvasImage = Nil) or (CanvasImageW <= 0) or (CanvasImageH <= 0) Then Exit;
 For Y := 0 To (CanvasImageH Div 2) - 1 Do Begin
  R1 := PByte(PtrUInt(CanvasImage) + PtrUInt(Y) * PtrUInt(CanvasImageW));
  R2 := PByte(PtrUInt(CanvasImage) +
              PtrUInt(CanvasImageH - 1 - Y) * PtrUInt(CanvasImageW));
  For X := 0 To CanvasImageW - 1 Do Begin
   T := PByte(PtrUInt(R1) + PtrUInt(X))^;
   PByte(PtrUInt(R1) + PtrUInt(X))^ := PByte(PtrUInt(R2) + PtrUInt(X))^;
   PByte(PtrUInt(R2) + PtrUInt(X))^ := T;
  End;
 End;
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure RotateImage(Degrees: Integer);
Var
 NewBuf: PByte;
 NW, NH, X, Y: Integer;
 Src, Dst: PByte;
Begin
 If (CanvasImage = Nil) or (CanvasImageW <= 0) or (CanvasImageH <= 0) Then Exit;
 Case Degrees of
  180: Begin
   FlipHorizontal;
   FlipVertical;
   Exit;
  End;
  90, 270: Begin
   NW := CanvasImageH;
   NH := CanvasImageW;
   GetMem(NewBuf, NW * NH);
   For Y := 0 To CanvasImageH - 1 Do
    For X := 0 To CanvasImageW - 1 Do Begin
     Src := PByte(PtrUInt(CanvasImage) +
                  PtrUInt(Y) * PtrUInt(CanvasImageW) + PtrUInt(X));
     If Degrees = 90 Then
      { Rotation horaire : new(x', y') ou x' = H-1-y, y' = x }
      Dst := PByte(PtrUInt(NewBuf) +
                   PtrUInt(X) * PtrUInt(NW) +
                   PtrUInt(CanvasImageH - 1 - Y))
     Else
      { 270 horaire = 90 antihoraire : x' = y, y' = W-1-x }
      Dst := PByte(PtrUInt(NewBuf) +
                   PtrUInt(CanvasImageW - 1 - X) * PtrUInt(NW) +
                   PtrUInt(Y));
     Dst^ := Src^;
    End;
   FreeMem(CanvasImage, CanvasImageW * CanvasImageH);
   CanvasImage := NewBuf;
   CanvasImageW := NW;
   CanvasImageH := NH;
   ImageBuffer.Width := NW;
   ImageBuffer.Height := NH;
  End;
 End;
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure InvertColors;
Var
 I, Total: LongInt;
 Mask: Byte;
 P: PByte;
Begin
 If (CanvasImage = Nil) or (CanvasImageW <= 0) or (CanvasImageH <= 0) Then Exit;
 If ImageBuffer.BitDepth >= 8 Then Mask := 255
 Else If ImageBuffer.BitDepth > 0 Then Mask := (1 shl ImageBuffer.BitDepth) - 1
 Else Mask := 15;
 Total := LongInt(CanvasImageW) * LongInt(CanvasImageH);
 P := CanvasImage;
 For I := 0 To Total - 1 Do Begin
  P^ := P^ Xor Mask;
  Inc(P);
 End;
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure StretchCanvas(NewW, NewH: Integer);
Var
 NewBuf: PByte;
 X, Y, SX, SY: Integer;
Begin
 If (CanvasImage = Nil) or (CanvasImageW <= 0) or (CanvasImageH <= 0) Then Exit;
 If (NewW <= 0) or (NewH <= 0) Then Exit;
 If (NewW > MAX_IMAGE_WIDTH) or (NewH > MAX_IMAGE_HEIGHT) Then Exit;
 GetMem(NewBuf, NewW * NewH);
 For Y := 0 To NewH - 1 Do Begin
  SY := (LongInt(Y) * LongInt(CanvasImageH)) Div LongInt(NewH);
  For X := 0 To NewW - 1 Do Begin
   SX := (LongInt(X) * LongInt(CanvasImageW)) Div LongInt(NewW);
   PByte(PtrUInt(NewBuf) + PtrUInt(Y) * PtrUInt(NewW) + PtrUInt(X))^ :=
    PByte(PtrUInt(CanvasImage) +
          PtrUInt(SY) * PtrUInt(CanvasImageW) + PtrUInt(SX))^;
  End;
 End;
 FreeMem(CanvasImage, CanvasImageW * CanvasImageH);
 CanvasImage := NewBuf;
 CanvasImageW := NewW;
 CanvasImageH := NewH;
 ImageBuffer.Width := NewW;
 ImageBuffer.Height := NewH;
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure ClearImage;
Begin
 If CanvasImage<>Nil Then
  FillChar(CanvasImage^,LongInt(CanvasImageW)*CanvasImageH,BackgroundColor);
 ImageBuffer.Modified:=True;
 DrawCanvas;
End;

{ Procédures d'historique (Undo/Redo) }

{ Structure pour stocker les données de l'historique }
Type
 PHistoryData = ^THistoryData;
 THistoryData = Record
  X1, Y1, X2, Y2: Integer;  { Zone affectée }
  PixelData: Pointer;        { Données de pixels sauvegardées }
  DataSize: LongInt;
  IsFullSnapshot: Boolean;   { True = snapshot complet de CanvasImage (taille variable) }
  ImgW, ImgH: Integer;       { Dimensions du buffer image pour les snapshots }
  SavedColors: TPalette;
  SavedSwatches: Array[0..27] of Byte;
  SavedForeground, SavedBackground, SavedDepth: Byte;
  SavedSelectionActive: Boolean;
  SavedSelectionRect: TRect;
 End;

Procedure SaveHistoryPalette(Data: PHistoryData);
Begin
 Data^.SavedColors := ImageBuffer.Palette;
 Move(StandardPalette,Data^.SavedSwatches,SizeOf(StandardPalette));
 Data^.SavedForeground := CurrentColor;
 Data^.SavedBackground := BackgroundColor;
 Data^.SavedDepth := ImageBuffer.BitDepth;
 Data^.SavedSelectionActive := SelectionActive;
 Data^.SavedSelectionRect := SelectionRect;
End;

Procedure RestoreHistoryPalette(Data: PHistoryData);
Var
 I: Integer;
Begin
 ImageBuffer.Palette := Data^.SavedColors;
 Move(Data^.SavedSwatches,StandardPalette,SizeOf(StandardPalette));
 CurrentColor := Data^.SavedForeground;
 BackgroundColor := Data^.SavedBackground;
 ImageBuffer.BitDepth := Data^.SavedDepth;
 SelectionActive := Data^.SavedSelectionActive;
 SelectionRect := Data^.SavedSelectionRect;
 AntsValid := False;
 For I := 0 To 255 Do
  If I <= GetMaxColor Then Begin
   {$IFDEF FPC}
   SetRGBPalette(I,ImageBuffer.Palette[I].R,
                   ImageBuffer.Palette[I].G,ImageBuffer.Palette[I].B);
   {$ELSE}
   SetRGBPalette(I,ImageBuffer.Palette[I].R Shr 2,
                   ImageBuffer.Palette[I].G Shr 2,ImageBuffer.Palette[I].B Shr 2);
   {$ENDIF}
  End;
 ImageBuffer.Modified := True;
End;

Function SaveCanvasRegion(X1, Y1, X2, Y2: Integer): PHistoryData;
Var
 Data: PHistoryData;
 Width, Height: Integer;
 PixelBuffer: PByte;
 X, Y: Integer;
 Offset: LongInt;
Begin
 SaveCanvasRegion := Nil;

 { Normaliser les coordonnées }
 If X1 > X2 Then Begin Width := X1; X1 := X2; X2 := Width; End;
 If Y1 > Y2 Then Begin Height := Y1; Y1 := Y2; Y2 := Height; End;

 { Limiter aux bornes du canevas }
 If X1 < CanvasX Then X1 := CanvasX;
 If Y1 < CanvasY Then Y1 := CanvasY;
 If X2 >= CanvasX + CanvasWidth Then X2 := CanvasX + CanvasWidth - 1;
 If Y2 >= CanvasY + CanvasHeight Then Y2 := CanvasY + CanvasHeight - 1;

 Width := X2 - X1 + 1;
 Height := Y2 - Y1 + 1;

 If (Width <= 0) or (Height <= 0) Then Exit;

 { Allouer la structure de données }
 New(Data);
 SaveHistoryPalette(Data);
 Data^.X1 := X1;
 Data^.Y1 := Y1;
 Data^.X2 := X2;
 Data^.Y2 := Y2;
 Data^.DataSize := LongInt(Width) * LongInt(Height);
 Data^.IsFullSnapshot := False;
 Data^.ImgW := 0;
 Data^.ImgH := 0;

 { Allouer le buffer pour les pixels }
 GetMem(Data^.PixelData, Data^.DataSize);
 PixelBuffer := Data^.PixelData;

 { Sauvegarder les pixels }
 Offset := 0;
 For Y := Y1 to Y2 do Begin
  For X := X1 to X2 do Begin
   PixelBuffer^ := GetPixel(X, Y);
   Inc(PixelBuffer);
  End;
 End;

 SaveCanvasRegion := Data;
End;

Procedure RestoreCanvasRegion(Data: PHistoryData);
Var
 PixelBuffer: PByte;
 X, Y, BX, BY: Integer;
 ImgP: PByte;
Begin
 If Data = Nil Then Exit;
 If Data^.PixelData = Nil Then Exit;
 RestoreHistoryPalette(Data);

 PixelBuffer := Data^.PixelData;

 { Restaurer les pixels dans le buffer image ET sur l'ecran. RedrawInterface
   re-bliter CanvasImage par dessus, donc la mise a jour du buffer est
   indispensable pour que l'Annuler soit visible. }
 For Y := Data^.Y1 to Data^.Y2 do Begin
  For X := Data^.X1 to Data^.X2 do Begin
   PutPixel(X, Y, PixelBuffer^);
   If (CanvasImage <> Nil) Then Begin
    BX := X - CanvasX;
    BY := Y - CanvasY;
    If (BX >= 0) and (BX < CanvasImageW) and
       (BY >= 0) and (BY < CanvasImageH) Then Begin
     ImgP := CanvasImage;
     Inc(ImgP, LongInt(BY) * LongInt(CanvasImageW) + BX);
     ImgP^ := PixelBuffer^;
    End;
   End;
   Inc(PixelBuffer);
  End;
 End;
End;

Procedure FreeHistoryData(Data: PHistoryData);
Begin
 If Data <> Nil Then Begin
  If Data^.PixelData <> Nil Then
   FreeMem(Data^.PixelData, Data^.DataSize);
  Dispose(Data);
 End;
End;

Function SaveFullSnapshot: PHistoryData;
{ Capture l'integralite de CanvasImage et ses dimensions courantes.
  Utilise par les actions qui peuvent redimensionner ou remplacer
  entierement l'image (Rogner, Retourner, Pivoter, Etirer, Inverser, Effacer). }
Var
 Data: PHistoryData;
 Sz: LongInt;
Begin
 SaveFullSnapshot := Nil;
 If (CanvasImage = Nil) or (CanvasImageW <= 0) or (CanvasImageH <= 0) Then Exit;
 New(Data);
 SaveHistoryPalette(Data);
 Data^.X1 := 0;
 Data^.Y1 := 0;
 Data^.X2 := CanvasImageW - 1;
 Data^.Y2 := CanvasImageH - 1;
 Data^.IsFullSnapshot := True;
 Data^.ImgW := CanvasImageW;
 Data^.ImgH := CanvasImageH;
 Sz := LongInt(CanvasImageW) * LongInt(CanvasImageH);
 Data^.DataSize := Sz;
 GetMem(Data^.PixelData, Sz);
 Move(CanvasImage^, Data^.PixelData^, Sz);
 SaveFullSnapshot := Data;
End;

Procedure RestoreFullSnapshot(Data: PHistoryData);
{ Remplace CanvasImage par le contenu du snapshot. Met a jour les dimensions
  et ImageBuffer.Width/Height. RedrawInterface doit etre appele apres. }
Var
 Sz: LongInt;
Begin
 If Data = Nil Then Exit;
 If Not Data^.IsFullSnapshot Then Exit;
 If Data^.PixelData = Nil Then Exit;
 RestoreHistoryPalette(Data);
 Sz := LongInt(Data^.ImgW) * LongInt(Data^.ImgH);
 If CanvasImage <> Nil Then
  FreeMem(CanvasImage, LongInt(CanvasImageW) * LongInt(CanvasImageH));
 GetMem(CanvasImage, Sz);
 Move(Data^.PixelData^, CanvasImage^, Sz);
 CanvasImageW := Data^.ImgW;
 CanvasImageH := Data^.ImgH;
 ImageBuffer.Width := Data^.ImgW;
 ImageBuffer.Height := Data^.ImgH;
End;

Procedure AddSnapshotToHistory(Action: Byte);
{ Pousse un snapshot complet de l'image courante dans la liste Undo.
  A appeler AVANT de modifier CanvasImage pour les operations destructives
  (Rogner, Retourner, Pivoter, Etirer, Inverser, Effacer). }
Var
 NewItem, OldItem: PHistoryItem;
 Data: PHistoryData;
 Count: Integer;
Begin
 Data := SaveFullSnapshot;
 If Data = Nil Then Exit;

 New(NewItem);
 NewItem^.Action := Action;
 NewItem^.Data := Data;
 NewItem^.DataSize := Data^.DataSize;
 NewItem^.Next := UndoList;
 NewItem^.Prev := Nil;

 If UndoList <> Nil Then
  UndoList^.Prev := NewItem;

 UndoList := NewItem;
 Inc(UndoCount);

 { Limiter le nombre d'éléments dans l'historique. }
 If UndoCount > MaxUndoLevels Then Begin
  OldItem := UndoList;
  Count := 1;
  While (OldItem^.Next <> Nil) and (Count < MaxUndoLevels) do Begin
   OldItem := OldItem^.Next;
   Inc(Count);
  End;
  While OldItem^.Next <> Nil do Begin
   NewItem := OldItem^.Next;
   OldItem^.Next := NewItem^.Next;
   FreeHistoryData(PHistoryData(NewItem^.Data));
   Dispose(NewItem);
   Dec(UndoCount);
  End;
 End;

 { Vider la liste Redo. }
 While RedoList <> Nil do Begin
  NewItem := RedoList;
  RedoList := RedoList^.Next;
  FreeHistoryData(PHistoryData(NewItem^.Data));
  Dispose(NewItem);
 End;
 RedoCount := 0;
End;

Procedure AddToHistory(Action: Byte);
Var
 NewItem, OldItem: PHistoryItem;
 Data: PHistoryData;
 Count: Integer;
Begin
 { Sauvegarder l'état actuel de tout le canevas }
 Data := SaveCanvasRegion(CanvasX, CanvasY,
                          CanvasX + CanvasWidth - 1,
                          CanvasY + CanvasHeight - 1);

 If Data = Nil Then Exit;

 New(NewItem);
 NewItem^.Action := Action;
 NewItem^.Data := Data;
 NewItem^.DataSize := Data^.DataSize;
 NewItem^.Next := UndoList;
 NewItem^.Prev := Nil;

 If UndoList <> Nil Then
  UndoList^.Prev := NewItem;

 UndoList := NewItem;
 Inc(UndoCount);

 { Limiter le nombre d'éléments dans l'historique }
 If UndoCount > MaxUndoLevels Then Begin
  { Trouver le dernier élément }
  OldItem := UndoList;
  Count := 1;
  While (OldItem^.Next <> Nil) and (Count < MaxUndoLevels) do Begin
   OldItem := OldItem^.Next;
   Inc(Count);
  End;

  { Supprimer les éléments au-delà de la limite }
  While OldItem^.Next <> Nil do Begin
   NewItem := OldItem^.Next;
   OldItem^.Next := NewItem^.Next;
   FreeHistoryData(PHistoryData(NewItem^.Data));
   Dispose(NewItem);
   Dec(UndoCount);
  End;
 End;

 { Vider la liste Redo }
 While RedoList <> Nil do Begin
  NewItem := RedoList;
  RedoList := RedoList^.Next;
  FreeHistoryData(PHistoryData(NewItem^.Data));
  Dispose(NewItem);
 End;
 RedoCount := 0;
End;

Procedure AddToHistoryRegion(Action: Byte; X1, Y1, X2, Y2: Integer);
Var
 NewItem, OldItem: PHistoryItem;
 Data: PHistoryData;
 Count: Integer;
Begin
 { Sauvegarder seulement la région affectée }
 Data := SaveCanvasRegion(X1, Y1, X2, Y2);

 If Data = Nil Then Exit;

 New(NewItem);
 NewItem^.Action := Action;
 NewItem^.Data := Data;
 NewItem^.DataSize := Data^.DataSize;
 NewItem^.Next := UndoList;
 NewItem^.Prev := Nil;

 If UndoList <> Nil Then
  UndoList^.Prev := NewItem;

 UndoList := NewItem;
 Inc(UndoCount);

 { Limiter le nombre d'éléments dans l'historique }
 If UndoCount > MaxUndoLevels Then Begin
  OldItem := UndoList;
  Count := 1;
  While (OldItem^.Next <> Nil) and (Count < MaxUndoLevels) do Begin
   OldItem := OldItem^.Next;
   Inc(Count);
  End;

  While OldItem^.Next <> Nil do Begin
   NewItem := OldItem^.Next;
   OldItem^.Next := NewItem^.Next;
   FreeHistoryData(PHistoryData(NewItem^.Data));
   Dispose(NewItem);
   Dec(UndoCount);
  End;
 End;

 { Vider la liste Redo }
 While RedoList <> Nil do Begin
  NewItem := RedoList;
  RedoList := RedoList^.Next;
  FreeHistoryData(PHistoryData(NewItem^.Data));
  Dispose(NewItem);
 End;
 RedoCount := 0;
End;

Procedure Undo;
Var
 Item: PHistoryItem;
 CurrentData, OldData: PHistoryData;
Begin
 If UndoList = Nil Then Exit;

 Item := UndoList;
 OldData := PHistoryData(Item^.Data);

 If OldData = Nil Then Begin
  { Pas de données, juste déplacer l'item }
  UndoList := UndoList^.Next;
  If UndoList <> Nil Then
   UndoList^.Prev := Nil;
  Dec(UndoCount);

  Item^.Next := RedoList;
  Item^.Prev := Nil;
  If RedoList <> Nil Then
   RedoList^.Prev := Item;
  RedoList := Item;
  Inc(RedoCount);

  RedrawInterface;
  Exit;
 End;

 { Sauvegarder l'état actuel pour le redo }
 If OldData^.IsFullSnapshot Then
  CurrentData := SaveFullSnapshot
 Else
  CurrentData := SaveCanvasRegion(OldData^.X1, OldData^.Y1,
                                   OldData^.X2, OldData^.Y2);

 { Restaurer l'ancien état }
 If OldData^.IsFullSnapshot Then
  RestoreFullSnapshot(OldData)
 Else
  RestoreCanvasRegion(OldData);

 { Déplacer l'item de Undo vers Redo }
 UndoList := UndoList^.Next;
 If UndoList <> Nil Then
  UndoList^.Prev := Nil;
 Dec(UndoCount);

 { Remplacer les données par l'état actuel pour le redo }
 FreeHistoryData(OldData);
 Item^.Data := CurrentData;
 If CurrentData <> Nil Then
  Item^.DataSize := CurrentData^.DataSize
 Else
  Item^.DataSize := 0; { Ajouter à la liste Redo }
 Item^.Next := RedoList;
 Item^.Prev := Nil;
 If RedoList <> Nil Then
  RedoList^.Prev := Item;
 RedoList := Item;
 Inc(RedoCount);

 RedrawInterface;
End;

Procedure Redo;
Var
 Item: PHistoryItem;
 CurrentData, OldData: PHistoryData;
Begin
 If RedoList = Nil Then Exit;

 Item := RedoList;
 OldData := PHistoryData(Item^.Data);

 If OldData = Nil Then Begin
  { Pas de données, juste déplacer l'item }
  RedoList := RedoList^.Next;
  If RedoList <> Nil Then
   RedoList^.Prev := Nil;
  Dec(RedoCount);

  Item^.Next := UndoList;
  Item^.Prev := Nil;
  If UndoList <> Nil Then
   UndoList^.Prev := Item;
  UndoList := Item;
  Inc(UndoCount);

  RedrawInterface;
  Exit;
 End;

 { Sauvegarder l'état actuel pour le undo }
 If OldData^.IsFullSnapshot Then
  CurrentData := SaveFullSnapshot
 Else
  CurrentData := SaveCanvasRegion(OldData^.X1, OldData^.Y1,
                                   OldData^.X2, OldData^.Y2);

 { Restaurer l'état du redo }
 If OldData^.IsFullSnapshot Then
  RestoreFullSnapshot(OldData)
 Else
  RestoreCanvasRegion(OldData);

 { Déplacer l'item de Redo vers Undo }
 RedoList := RedoList^.Next;
 If RedoList <> Nil Then
  RedoList^.Prev := Nil;
 Dec(RedoCount);

 { Remplacer les données par l'état actuel pour le undo }
 FreeHistoryData(OldData);
 Item^.Data := CurrentData;
 If CurrentData <> Nil Then
  Item^.DataSize := CurrentData^.DataSize
 Else
  Item^.DataSize := 0;

 { Ajouter à la liste Undo }
 Item^.Next := UndoList;
 Item^.Prev := Nil;
 If UndoList <> Nil Then
  UndoList^.Prev := Item;
 UndoList := Item;
 Inc(UndoCount);

 RedrawInterface;
End;

{ Procédures de dessin }

Procedure DrawPixel(X,Y: Integer; Color: Byte);
Begin
 X:=X-CanvasX; Y:=Y-CanvasY;
 If (X<0) Or (Y<0) Or (X>=CanvasImageW) Or (Y>=CanvasImageH) Then Exit;
 ZPutImagePixel(X,Y,Color);
 ZRenderPixel(X,Y,Color);
 ImageBuffer.Modified:=True;
End;

Procedure SyncCanvasImage(X1, Y1, X2, Y2: Integer);
{ Copie les pixels de l'ecran dans CanvasImage pour la zone donnee. A appeler
  apres toute primitive de dessin pour que RedrawInterface (qui re-blitte
  CanvasImage) ne fasse pas disparaitre le trace, et pour que Undo capture
  l'etat reel via CanvasImage. }
Var
 X, Y, BX, BY, T: Integer;
 ImgP: PByte;
Begin
 If ZTransformed Then Exit;
 If CanvasImage = Nil Then Exit;
 { Normaliser }
 If X1 > X2 Then Begin T := X1; X1 := X2; X2 := T; End;
 If Y1 > Y2 Then Begin T := Y1; Y1 := Y2; Y2 := T; End;
 { Clipper au canvas a l'ecran ET a la taille du buffer image. }
 If X1 < CanvasX Then X1 := CanvasX;
 If Y1 < CanvasY Then Y1 := CanvasY;
 If X2 >= CanvasX + CanvasImageW Then X2 := CanvasX + CanvasImageW - 1;
 If Y2 >= CanvasY + CanvasImageH Then Y2 := CanvasY + CanvasImageH - 1;
 If (X1 > X2) or (Y1 > Y2) Then Exit;
 For Y := Y1 to Y2 do Begin
  BY := Y - CanvasY;
  For X := X1 to X2 do Begin
   BX := X - CanvasX;
   ImgP := CanvasImage;
   Inc(ImgP, LongInt(BY) * LongInt(CanvasImageW) + BX);
   ImgP^ := GetPixel(X, Y);
  End;
 End;
End;

Procedure BlitCanvasRect(X1, Y1, X2, Y2: Integer);
{ Re-affiche les pixels stockes dans CanvasImage sur la zone ecran donnee.
  Sert a effacer un apercu en restaurant le canvas en dessous. }
Var
 X, Y, BX, BY, T: Integer;
 P: PByte;
Begin
 If ZTransformed Then Begin DrawCanvas; Exit; End;
 If CanvasImage = Nil Then Exit;
 If X1 > X2 Then Begin T := X1; X1 := X2; X2 := T; End;
 If Y1 > Y2 Then Begin T := Y1; Y1 := Y2; Y2 := T; End;
 If X1 < CanvasX Then X1 := CanvasX;
 If Y1 < CanvasY Then Y1 := CanvasY;
 If X2 >= CanvasX + CanvasImageW Then X2 := CanvasX + CanvasImageW - 1;
 If Y2 >= CanvasY + CanvasImageH Then Y2 := CanvasY + CanvasImageH - 1;
 If (X1 > X2) or (Y1 > Y2) Then Exit;
 For Y := Y1 to Y2 do Begin
  BY := Y - CanvasY;
  For X := X1 to X2 do Begin
   BX := X - CanvasX;
   P := CanvasImage;
   Inc(P, LongInt(BY) * LongInt(CanvasImageW) + BX);
   PutPixel(X, Y, P^);
  End;
 End;
End;

Procedure ErasePreviewText;
{ Restaure le canvas sous l'apercu de texte en cours. }
Begin
 If (TextPrevW > 0) and (TextPrevH > 0) Then
  BlitCanvasRect(TextX, TextY, TextX + TextPrevW, TextY + TextPrevH);
 TextPrevW := 0;
 TextPrevH := 0;
End;

Procedure DrawTextPreview;
{ Efface l'ancien apercu puis dessine le texte courant (sans modifier
  CanvasImage) avec un curseur '_' en fin. }
Var
 S: String;
Begin
 ErasePreviewText;
 S := TextInput + '_';
 If ZTransformed Then Begin
  ZRasterText(TextX-CanvasX,TextY-CanvasY,S,CurrentColor,False);
  TextPrevW:=TextWidth(S)+1; TextPrevH:=TextHeight('M')+1;
  Exit;
 End;
 SetColor(CurrentColor);
 OutTextXY(TextX, TextY, S);
 TextPrevW := TextWidth(S) + 1;
 TextPrevH := TextHeight('M') + 1;
End;

Procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte);
Begin
 If ZTransformed Then Begin
  ZLine(X1-CanvasX,Y1-CanvasY,X2-CanvasX,Y2-CanvasY,Color);
  ImageBuffer.Modified:=True;
  DrawCanvas;
  Exit;
 End;
 SetColor(Color);
 Line(X1, Y1, X2, Y2);
 SyncCanvasImage(X1, Y1, X2, Y2);
 ImageBuffer.Modified := True;
End;

Procedure DrawRectangle(X1, Y1, X2, Y2: Integer; Color: Byte; Filled: Boolean);
Begin
 If ZTransformed Then Begin
  ZRectangle(X1-CanvasX,Y1-CanvasY,X2-CanvasX,Y2-CanvasY,Color,Filled);
  ImageBuffer.Modified:=True;
  DrawCanvas;
  Exit;
 End;
 SetColor(Color);
 If Filled Then Begin
  SetFillStyle(SolidFill, Color);
  Bar(X1, Y1, X2, Y2);
 End Else Begin
  Rectangle(X1, Y1, X2, Y2);
 End;
 SyncCanvasImage(X1, Y1, X2, Y2);
 ImageBuffer.Modified := True;
End;

Procedure DrawEllipse(X, Y, RadiusX, RadiusY: Integer; Color: Byte; Filled: Boolean);
Begin
 If ZTransformed Then Begin
  ZEllipse(X-CanvasX,Y-CanvasY,RadiusX,RadiusY,Color,Filled);
  ImageBuffer.Modified:=True;
  DrawCanvas;
  Exit;
 End;
 SetColor(Color);
 If Filled Then Begin
  SetFillStyle(SolidFill, Color);
  FillEllipse(X, Y, RadiusX, RadiusY);
 End Else Begin
  Ellipse(X, Y, 0, 360, RadiusX, RadiusY);
 End;
 SyncCanvasImage(X - RadiusX - 1, Y - RadiusY - 1,
                 X + RadiusX + 1, Y + RadiusY + 1);
 ImageBuffer.Modified := True;
End;

Procedure DrawCircle(X, Y, Radius: Integer; Color: Byte; Filled: Boolean);
Begin
 DrawEllipse(X, Y, Radius, Radius, Color, Filled);
End;

Procedure DrawRoundRectShape(X1, Y1, X2, Y2, RadiusX, RadiusY: Integer; Color: Byte; Filled: Boolean);
Begin
 If ZTransformed Then Begin
  ZRoundRectangle(X1-CanvasX,Y1-CanvasY,X2-CanvasX,Y2-CanvasY,RadiusX,RadiusY,Color,Filled);
  ImageBuffer.Modified:=True;
  DrawCanvas;
  Exit;
 End;
 SetColor(Color);
 If Filled Then Begin
  SetFillStyle(SolidFill, Color);
  { Dessiner un rectangle arrondi rempli }
  Bar(X1 + RadiusX, Y1, X2 - RadiusX, Y2);
  Bar(X1, Y1 + RadiusY, X2, Y2 - RadiusY);
  FillEllipse(X1 + RadiusX, Y1 + RadiusY, RadiusX, RadiusY);
  FillEllipse(X2 - RadiusX, Y1 + RadiusY, RadiusX, RadiusY);
  FillEllipse(X1 + RadiusX, Y2 - RadiusY, RadiusX, RadiusY);
  FillEllipse(X2 - RadiusX, Y2 - RadiusY, RadiusX, RadiusY);
 End Else Begin
  DrawRoundedRect(X1, Y1, X2, Y2, RadiusX, RadiusY);
 End;
 SyncCanvasImage(X1, Y1, X2, Y2);
 ImageBuffer.Modified := True;
End;

Procedure FloodFillArea(X,Y: Integer; FillColor,BorderColor: Byte);
Var
 Queue: PLongInt;
 Head,Tail,Count,ID: LongInt;
 PX,PY: Integer;
 Target: Byte;
 {$IFDEF FPC}Previous: Boolean;{$ENDIF}

 Procedure Enqueue(NX,NY: Integer);
 Begin
  If (NX<0) Or (NY<0) Or (NX>=CanvasImageW) Or (NY>=CanvasImageH) Then Exit;
  If ZImagePixel(NX,NY)<>Target Then Exit;
  ZPutImagePixel(NX,NY,FillColor);
  PLongInt(PtrUInt(Queue)+PtrUInt(Tail)*SizeOf(LongInt))^:=LongInt(NY)*CanvasImageW+NX;
  Inc(Tail);
 End;

Begin
 X:=X-CanvasX; Y:=Y-CanvasY;
 If (CanvasImage=Nil) Or (X<0) Or (Y<0) Or
    (X>=CanvasImageW) Or (Y>=CanvasImageH) Then Exit;
 Target:=ZImagePixel(X,Y);
 If FillColor=Target Then Exit;
 Count:=LongInt(CanvasImageW)*CanvasImageH;
 Queue:=Nil;
 {$IFDEF FPC}
 Previous:=ReturnNilIfGrowHeapFails;
 ReturnNilIfGrowHeapFails:=True;
 GetMem(Queue,Count*SizeOf(LongInt));
 ReturnNilIfGrowHeapFails:=Previous;
 {$ELSE}
 If MaxAvail>=Count*SizeOf(LongInt) Then GetMem(Queue,Count*SizeOf(LongInt));
 {$ENDIF}
 If Queue=Nil Then Exit;
 Head:=0; Tail:=0;
 Enqueue(X,Y);
 While Head<Tail Do Begin
  ID:=PLongInt(PtrUInt(Queue)+PtrUInt(Head)*SizeOf(LongInt))^;
  Inc(Head);
  PX:=ID Mod CanvasImageW; PY:=ID Div CanvasImageW;
  Enqueue(PX-1,PY); Enqueue(PX+1,PY);
  Enqueue(PX,PY-1); Enqueue(PX,PY+1);
 End;
 FreeMem(Queue,Count*SizeOf(LongInt));
 ImageBuffer.Modified:=True;
 RedrawInterface;
End;

Procedure DrawText(X, Y: Integer; Text: String; Color: Byte);
Var
 W, H: Integer;
Begin
 If ZTransformed Then Begin
  ZRasterText(X-CanvasX,Y-CanvasY,Text,Color,True);
  ImageBuffer.Modified:=True;
  DrawCanvas;
  Exit;
 End;
 W := TextWidth(Text);
 H := TextHeight(Text);
 If H < 8 Then H := 8;
 HideMouse;
 SetColor(Color);
 OutTextXY(X, Y, Text);
 { Synchroniser une zone genereuse pour eviter que SyncCanvasImage rate
   des pixels du glyphe (descenders, etc.) ou capture le curseur souris. }
 SyncCanvasImage(X, Y, X + W + 2, Y + H + 2);
 ShowMouse;
 ImageBuffer.Modified := True;
End;

Procedure DrawWithBrush(X, Y: Integer; Color: Byte);
Var
 I, J: Integer;
 HalfSize: Integer;
Begin
 HalfSize := BrushSize div 2;
 For I := -HalfSize to HalfSize do
  For J := -HalfSize to HalfSize do
   If (I * I + J * J) <= (HalfSize * HalfSize) Then
    DrawPixel(X + I, Y + J, Color);
End;

Procedure DrawWithAirbrush(X, Y: Integer; Color: Byte);
Var
 I: Integer;
 RandX, RandY: Integer;
Begin
 For I := 1 to BrushSize * 5 do Begin
  RandX := X + Random(BrushSize * 2) - BrushSize;
  RandY := Y + Random(BrushSize * 2) - BrushSize;
  If Random(3) = 0 Then
   DrawPixel(RandX, RandY, Color);
 End;
End;

Procedure EraseTool(X, Y: Integer);
Begin
 DrawWithBrush(X, Y, BackgroundColor);
End;

Procedure ColorPicker(X,Y: Integer);
Begin
 X:=X-CanvasX; Y:=Y-CanvasY;
 If (X<0) Or (Y<0) Or (X>=CanvasImageW) Or (Y>=CanvasImageH) Then Exit;
 CurrentColor:=ZImagePixel(X,Y);
 DrawColorPalette;
End;

{ Procédures de gestion des événements }

Procedure ShowMessage(Const Title, Msg: String);
Var
 BoxX, BoxY, BoxW, BoxH: Integer;
 BtnX1, BtnY1, BtnX2, BtnY2: Integer;
 K: Char;
 MX, MY, MB: Integer;
 PrevB: Integer;
 Lines: Array[1..16] of String;
 LineCount, I, StartPos: Integer;
Begin
 { Messages multilignes, separes par LF (ou CR/LF). }
 LineCount := 0;
 StartPos := 1;
 For I := 1 To Length(Msg) + 1 Do Begin
  If I <= Length(Msg) Then Begin
   If Msg[I] <> #10 Then Continue;
  End;
  If LineCount < 16 Then Begin
   Inc(LineCount);
   Lines[LineCount] := Copy(Msg, StartPos, I - StartPos);
   If Length(Lines[LineCount]) > 0 Then
    If Lines[LineCount][Length(Lines[LineCount])] = #13 Then
     Delete(Lines[LineCount], Length(Lines[LineCount]), 1);
  End;
  StartPos := I + 1;
 End;
 BoxW := 240;
 For I := 1 To LineCount Do
  If TextWidth(Lines[I]) + 40 > BoxW Then
   BoxW := TextWidth(Lines[I]) + 40;
 If TextWidth(Title) + 40 > BoxW Then BoxW := TextWidth(Title) + 40;
 If BoxW < 240 Then BoxW := 240;
 BoxH := 90 + (LineCount - 1) * 16;
 BoxX := (ScreenWidth - BoxW) div 2;
 BoxY := (ScreenHeight - BoxH) div 2;

 SetFillStyle(SolidFill, LightGray);
 Bar(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);
 SetColor(DarkGray);
 Rectangle(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);
 SetFillStyle(SolidFill, Blue);
 Bar(BoxX + 1, BoxY + 1, BoxX + BoxW - 1, BoxY + 18);
 SetColor(White);
 OutTextXY(BoxX + 8, BoxY + 5, Title);
 SetColor(Black);
 For I := 1 To LineCount Do
  OutTextXY(BoxX + 20, BoxY + 35 + (I - 1) * 16, Lines[I]);
 BtnX1 := BoxX + BoxW div 2 - 30;
 BtnY1 := BoxY + BoxH - 25;
 BtnX2 := BoxX + BoxW div 2 + 30;
 BtnY2 := BoxY + BoxH - 8;
 SetFillStyle(SolidFill, DarkGray);
 Bar(BtnX1, BtnY1, BtnX2, BtnY2);
 SetColor(White);
 OutTextXY(BoxX + BoxW div 2 - 8, BoxY + BoxH - 22, 'OK');

 { Attendre Entree/Espace/Echap OU clic sur OK }
 GetMouseStateLocal(MX, MY, PrevB);
 Repeat
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then ReadKey;
   If (K = #13) or (K = #27) or (K = ' ') Then Begin
    RedrawInterface;
    Exit;
   End;
  End;
  GetMouseStateLocal(MX, MY, MB);
  If ((MB and 1) <> 0) and ((PrevB and 1) = 0) Then Begin
   If (MX >= BtnX1) and (MX <= BtnX2) and
      (MY >= BtnY1) and (MY <= BtnY2) Then Begin
    RedrawInterface;
    Exit;
   End;
  End;
  PrevB := MB;
  Delay(10);
 Until False;
End;

Function PromptString(Const Title, Prompt: String; Var Value: String): Boolean;
Var
 BoxX, BoxY, BoxW, BoxH: Integer;
 K: Char;
 InputX, InputY, InputW: Integer;
 OkX1, OkY1, OkX2, OkY2: Integer;
 CaX1, CaY1, CaX2, CaY2: Integer;
 MX, MY, MB, PrevB: Integer;

 Procedure DrawInput;
 Begin
  SetFillStyle(SolidFill, White);
  Bar(InputX, InputY, InputX + InputW, InputY + 16);
  SetColor(DarkGray);
  Rectangle(InputX, InputY, InputX + InputW, InputY + 16);
  SetColor(Black);
  OutTextXY(InputX + 4, InputY + 3, Value + '_');
 End;

 Procedure DrawButtons;
 Begin
  SetFillStyle(SolidFill, DarkGray);
  Bar(OkX1, OkY1, OkX2, OkY2);
  SetColor(White);
  OutTextXY(OkX1 + (OkX2 - OkX1 - TextWidth('OK')) div 2,
            OkY1 + 4, 'OK');
  SetFillStyle(SolidFill, DarkGray);
  Bar(CaX1, CaY1, CaX2, CaY2);
  SetColor(White);
  OutTextXY(CaX1 + (CaX2 - CaX1 - TextWidth('Annuler')) div 2,
            CaY1 + 4, 'Annuler');
 End;

Begin
 PromptString := False;
 BoxW := 380;
 BoxH := 130;
 BoxX := (ScreenWidth - BoxW) div 2;
 BoxY := (ScreenHeight - BoxH) div 2;

 SetFillStyle(SolidFill, LightGray);
 Bar(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);
 SetColor(DarkGray);
 Rectangle(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);
 SetFillStyle(SolidFill, Blue);
 Bar(BoxX + 1, BoxY + 1, BoxX + BoxW - 1, BoxY + 18);
 SetColor(White);
 OutTextXY(BoxX + 8, BoxY + 5, Title);
 SetColor(Black);
 OutTextXY(BoxX + 10, BoxY + 30, Prompt);
 OutTextXY(BoxX + 10, BoxY + BoxH - 18,
           'Entree = OK   Echap = Annuler');

 InputX := BoxX + 10;
 InputY := BoxY + 50;
 InputW := BoxW - 20;
 DrawInput;

 OkX1 := BoxX + BoxW div 2 - 90;
 OkY1 := BoxY + BoxH - 45;
 OkX2 := OkX1 + 70;
 OkY2 := OkY1 + 20;
 CaX1 := BoxX + BoxW div 2 + 20;
 CaY1 := OkY1;
 CaX2 := CaX1 + 70;
 CaY2 := OkY2;
 DrawButtons;

 GetMouseStateLocal(MX, MY, PrevB);
 Repeat
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then Begin
    ReadKey; { ignorer touche etendue }
   End
   Else If K = #13 Then Begin
    PromptString := True;
    RedrawInterface;
    Exit;
   End
   Else If K = #27 Then Begin
    RedrawInterface;
    Exit;
   End
   Else If K = #8 Then Begin
    If Length(Value) > 0 Then Begin
     Delete(Value, Length(Value), 1);
     DrawInput;
    End;
   End
   Else If (K >= ' ') and (Length(Value) < 200) Then Begin
    Value := Value + K;
    DrawInput;
   End;
  End;
  GetMouseStateLocal(MX, MY, MB);
  If ((MB and 1) <> 0) and ((PrevB and 1) = 0) Then Begin
   If (MX >= OkX1) and (MX <= OkX2) and
      (MY >= OkY1) and (MY <= OkY2) Then Begin
    PromptString := True;
    RedrawInterface;
    Exit;
   End;
   If (MX >= CaX1) and (MX <= CaX2) and
      (MY >= CaY1) and (MY <= CaY2) Then Begin
    RedrawInterface;
    Exit;
   End;
  End;
  PrevB := MB;
  Delay(10);
 Until False;
End;

Function PromptYesNoCancel(Const Title, Msg: String): Integer;
{ Boite de dialogue 3 etats : 1=Oui, 2=Non, 0=Annuler. }
Var
 BoxX, BoxY, BoxW, BoxH: Integer;
 K: Char;
 YX1, YY1, YX2, YY2: Integer;
 NX1, NY1, NX2, NY2: Integer;
 CX1, CY1, CX2, CY2: Integer;
 MX, MY, MB, PrevB: Integer;

 Procedure DrawBtn(X1, Y1, X2, Y2: Integer; Const Lbl: String);
 Begin
  SetFillStyle(SolidFill, DarkGray);
  Bar(X1, Y1, X2, Y2);
  SetColor(White);
  OutTextXY(X1 + (X2 - X1 - TextWidth(Lbl)) div 2, Y1 + 4, Lbl);
 End;

Begin
 PromptYesNoCancel := 0;
 BoxW := TextWidth(Msg) + 40;
 If TextWidth(Title) + 40 > BoxW Then BoxW := TextWidth(Title) + 40;
 If BoxW < 360 Then BoxW := 360;
 BoxH := 130;
 BoxX := (ScreenWidth - BoxW) div 2;
 BoxY := (ScreenHeight - BoxH) div 2;

 SetFillStyle(SolidFill, LightGray);
 Bar(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);
 SetColor(DarkGray);
 Rectangle(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);
 SetFillStyle(SolidFill, Blue);
 Bar(BoxX + 1, BoxY + 1, BoxX + BoxW - 1, BoxY + 18);
 SetColor(White);
 OutTextXY(BoxX + 8, BoxY + 5, Title);
 SetColor(Black);
 OutTextXY(BoxX + 20, BoxY + 35, Msg);
 OutTextXY(BoxX + 10, BoxY + BoxH - 18,
           'O = Oui   N = Non   Echap = Annuler');

 YX1 := BoxX + 20;
 YY1 := BoxY + BoxH - 50;
 YX2 := YX1 + 70;
 YY2 := YY1 + 20;
 NX1 := BoxX + (BoxW - 70) div 2;
 NY1 := YY1;
 NX2 := NX1 + 70;
 NY2 := YY2;
 CX1 := BoxX + BoxW - 90;
 CY1 := YY1;
 CX2 := CX1 + 70;
 CY2 := YY2;
 DrawBtn(YX1, YY1, YX2, YY2, 'Oui');
 DrawBtn(NX1, NY1, NX2, NY2, 'Non');
 DrawBtn(CX1, CY1, CX2, CY2, 'Annuler');

 GetMouseStateLocal(MX, MY, PrevB);
 Repeat
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then ReadKey
   Else Begin
    K := UpCase(K);
    If (K = 'O') or (K = 'Y') or (K = #13) Then Begin
     PromptYesNoCancel := 1;
     RedrawInterface;
     Exit;
    End;
    If K = 'N' Then Begin
     PromptYesNoCancel := 2;
     RedrawInterface;
     Exit;
    End;
    If K = #27 Then Begin
     PromptYesNoCancel := 0;
     RedrawInterface;
     Exit;
    End;
   End;
  End;
  GetMouseStateLocal(MX, MY, MB);
  If ((MB and 1) <> 0) and ((PrevB and 1) = 0) Then Begin
   If (MX >= YX1) and (MX <= YX2) and
      (MY >= YY1) and (MY <= YY2) Then Begin
    PromptYesNoCancel := 1;
    RedrawInterface;
    Exit;
   End;
   If (MX >= NX1) and (MX <= NX2) and
      (MY >= NY1) and (MY <= NY2) Then Begin
    PromptYesNoCancel := 2;
    RedrawInterface;
    Exit;
   End;
   If (MX >= CX1) and (MX <= CX2) and
      (MY >= CY1) and (MY <= CY2) Then Begin
    PromptYesNoCancel := 0;
    RedrawInterface;
    Exit;
   End;
  End;
  PrevB := MB;
  Delay(10);
 Until False;
End;

Function SaveAsCurrentImage: Boolean; Forward;

Function SaveCurrentImage: Boolean;
Begin
 SaveCurrentImage:=False;
 If (ImageBuffer.FileName='') Or Not (ImageBuffer.Format In
 [FMT_BMP,FMT_GIF,FMT_PNG,FMT_PCX,FMT_JPEG,FMT_PAS,
 FMT_BGX,FMT_XBM,FMT_PPM,FMT_APNG,FMT_ARW,FMT_CR2,FMT_DCM,
 FMT_DDS,FMT_WPG,FMT_EXR,FMT_FAX])
 Then Begin
  SaveCurrentImage:=SaveAsCurrentImage; Exit;
 End;
 If SaveImage(ImageBuffer.FileName,ImageBuffer.Format) Then Begin SaveCurrentImage:=True; DrawStatusBar; End
 Else ShowMessage('Enregistrement impossible',PaintSaveError);
End;

Function ConfirmDiscardChanges: Boolean;
{ Si des modifications non sauvegardees existent, demande a l'utilisateur.
  - Oui     : sauvegarde et retourne True si OK, False si echec.
  - Non     : abandonne les modifs, retourne True.
  - Annuler : retourne False (l'appelant ne doit PAS quitter). }
Var
 R: Integer;
Begin
 If Not ImageBuffer.Modified Then Begin
  ConfirmDiscardChanges := True;
  Exit;
 End;
 R := PromptYesNoCancel('Modifications non enregistrees',
   'Enregistrer les modifications avant de continuer ?');
 Case R of
  1: ConfirmDiscardChanges := SaveCurrentImage;
  2: ConfirmDiscardChanges := True;
 Else
  ConfirmDiscardChanges := False;
 End;
End;

{ Editeur de couleurs PAINT : travail transactionnel jusqu'a validation.
  Les indices 0..15 restent reserves aux elements de l'interface.
  Les cases de la barre utilisent 16..43 en mode 256 couleurs.
  Le dialogue utilise 44..63 pour ses echantillons et 64..255
  pour un cube RVB temporaire. Ces entrees sont restaurees a la sortie.
  Aucune capture du dialogue ne doit etre synchronisee dans CanvasImage. }

Const
 PE_BASIC_COUNT = 48;
 PE_CUSTOM_COUNT = 16;
 PE_SLOT_COUNT = 28;
 PE_FIELD_COUNT = 7;
 PE_BUTTON_COUNT = 10;
 PE_FOCUS_BASIC = 0;
 PE_FOCUS_CUSTOM = 1;
 PE_FOCUS_SLOTS = 2;
 PE_FOCUS_PLANE = 3;
 PE_FOCUS_LUMA = 4;
 PE_FOCUS_FIELD = 5;
 PE_FOCUS_BUTTON = 12;
 PE_FOCUS_LAST = 21;
 PE_PREVIEW = 44;
 PE_OLD_PREVIEW = 45;
 PE_CUSTOM_FIRST = 46;
 PE_CUBE_FIRST = 64;
 PE_DIALOG_W = 620;
 PE_DIALOG_H = 430;
 PE_COMPACT_W = 304;
 PE_COMPACT_H = 430;

Type
 TPECustomColors = Array[0..PE_CUSTOM_COUNT-1] of TRGBColor;
 TPESlotColors = Array[0..PE_SLOT_COUNT-1] of TRGBColor;
 TPEFields = Array[0..PE_FIELD_COUNT-1] of String[8];
 TPEButtons = Array[0..PE_BUTTON_COUNT-1] of TRect;
 TPEFieldRects = Array[0..PE_FIELD_COUNT-1] of TRect;
 TPEState = Record
  X, Y, W, H: Integer;
  Expanded: Boolean;
  Done, Accepted: Boolean;
  Dirty, PlaneDirty: Boolean;
  Focus: Integer;
  BasicIndex, CustomIndex, SlotIndex: Integer;
  TargetBackground: Boolean;
  RGB, Original, Previous: TRGBColor;
  Hue, Saturation, Luminance: Integer;
  Slots: TPESlotColors;
  Customs: TPECustomColors;
  Fields: TPEFields;
  FieldRects: TPEFieldRects;
  Buttons: TPEButtons;
  FieldSelected: Boolean;
  FieldError: Integer;
  Status: String[76];
  MX, MY, MB, PrevButtons: Integer;
  DragKind: Integer;
  LastX, LastY: Integer;
  SavedPalette: TPalette;
 End;

Var
 PaintCustomColors: TPECustomColors;
 PaintCustomReady: Boolean;
 ActivePaletteSlot: Integer;

Function PEClamp(Value, LowValue, HighValue: Integer): Integer;
Begin
 If Value < LowValue Then
  Value := LowValue;
 If Value > HighValue Then
  Value := HighValue;
 PEClamp := Value;
End;

Function PERGB(R, G, B: Integer): TRGBColor;
Var
 C: TRGBColor;
Begin
 C.R := PEClamp(R, 0, 255);
 C.G := PEClamp(G, 0, 255);
 C.B := PEClamp(B, 0, 255);
 C.A := 255;
 PERGB := C;
End;

Function PESameColor(Const A, B: TRGBColor): Boolean;
Begin
 PESameColor := (A.R = B.R) And (A.G = B.G) And (A.B = B.B);
End;

Function PEDefaultColor(Index: Integer): TRGBColor;
Const
 Values: Array[0..15, 0..2] of Byte = (
  (0,0,0), (0,0,168), (0,168,0), (0,168,168),
  (168,0,0), (168,0,168), (168,84,0), (168,168,168),
  (84,84,84), (84,84,252), (84,252,84), (84,252,252),
  (252,84,84), (252,84,252), (252,252,84), (252,252,252));
Begin
 Index := PEClamp(Index, 0, 15);
 PEDefaultColor := PERGB(Values[Index,0], Values[Index,1], Values[Index,2]);
End;

Function PEBasicColor(Index: Integer): TRGBColor;
Const
 Values: Array[0..PE_BASIC_COUNT-1, 0..2] of Byte = (
  (255,128,128), (255,255,128), (128,255,128), (0,255,128),
  (128,255,255), (0,128,255), (255,128,192), (255,128,255),
  (255,0,0), (255,255,0), (128,255,0), (0,255,64),
  (0,255,255), (0,128,192), (128,128,192), (255,0,255),
  (128,64,64), (255,128,64), (0,255,0), (0,128,128),
  (0,64,128), (128,128,255), (128,0,64), (255,0,128),
  (128,0,0), (255,128,0), (0,128,0), (0,128,64),
  (0,0,255), (0,0,160), (128,0,128), (128,0,255),
  (64,0,0), (128,64,0), (0,64,0), (0,64,64),
  (0,0,128), (0,0,64), (64,0,64), (64,0,128),
  (0,0,0), (128,128,0), (128,128,64), (128,128,128),
  (64,128,128), (192,192,192), (64,0,64), (255,255,255));
Begin
 Index := PEClamp(Index, 0, PE_BASIC_COUNT-1);
 PEBasicColor := PERGB(Values[Index,0], Values[Index,1], Values[Index,2]);
End;

Function PEHueComponent(P, Q, T: Real): Real;
Begin
 While T < 0 Do
  T := T + 1;
 While T > 1 Do
  T := T - 1;
 If T < 1.0/6 Then
  PEHueComponent := P + (Q-P)*6*T
 Else If T < 0.5 Then
  PEHueComponent := Q
 Else If T < 2.0/3 Then
  PEHueComponent := P + (Q-P)*(2.0/3-T)*6
 Else
  PEHueComponent := P;
End;

Function PEHSLToRGB(Hue, Sat, Lum: Integer): TRGBColor;
Var
 H, S, L, P, Q: Real;
Begin
 H := PEClamp(Hue, 0, 239) / 240.0;
 S := PEClamp(Sat, 0, 240) / 240.0;
 L := PEClamp(Lum, 0, 240) / 240.0;
 If Sat = 0 Then Begin
  PEHSLToRGB := PERGB(Round(L*255), Round(L*255), Round(L*255));
  Exit;
 End;
 If L < 0.5 Then
  Q := L*(1+S)
 Else
  Q := L+S-L*S;
 P := 2*L-Q;
 PEHSLToRGB := PERGB(
  Round(255*PEHueComponent(P,Q,H+1.0/3)),
  Round(255*PEHueComponent(P,Q,H)),
  Round(255*PEHueComponent(P,Q,H-1.0/3)));
End;

Procedure PERGBToHSL(Const C: TRGBColor; Var H, S, L: Integer);
Var
 R, G, B, Highest, Lowest, Delta, HF, SF, LF: Real;
Begin
 R := C.R/255.0;
 G := C.G/255.0;
 B := C.B/255.0;
 Highest := R;
 If G > Highest Then
  Highest := G;
 If B > Highest Then
  Highest := B;
 Lowest := R;
 If G < Lowest Then
  Lowest := G;
 If B < Lowest Then
  Lowest := B;
 Delta := Highest-Lowest;
 LF := (Highest+Lowest)/2;
 If Delta < 0.000001 Then Begin
  { Conserver la teinte choisie lorsque la couleur devient grise. }
  S := 0;
  L := PEClamp(Round(LF*240),0,240);
  Exit;
 End;
 If LF > 0.5 Then
  SF := Delta/(2-Highest-Lowest)
 Else
  SF := Delta/(Highest+Lowest);
 If Highest = R Then Begin
  HF := (G-B)/Delta;
  If G < B Then
   HF := HF+6;
 End
 Else If Highest = G Then
  HF := (B-R)/Delta+2
 Else
  HF := (R-G)/Delta+4;
 H := Round(HF*40) Mod 240;
 S := PEClamp(Round(SF*240),0,240);
 L := PEClamp(Round(LF*240),0,240);
End;

Function PEHexDigit(Value: Integer): Char;
Const
 Digits: String[16] = '0123456789ABCDEF';
Begin
 PEHexDigit := Digits[(Value And 15)+1];
End;

Function PEHexByte(Value: Byte): String;
Begin
 PEHexByte := PEHexDigit(Value Shr 4)+PEHexDigit(Value And 15);
End;

Function PEHexColor(Const C: TRGBColor): String;
Begin
 PEHexColor := PEHexByte(C.R)+PEHexByte(C.G)+PEHexByte(C.B);
End;

Function PEHexValue(C: Char): Integer;
Begin
 C := UpCase(C);
 If (C >= '0') And (C <= '9') Then
  PEHexValue := Ord(C)-Ord('0')
 Else If (C >= 'A') And (C <= 'F') Then
  PEHexValue := Ord(C)-Ord('A')+10
 Else
  PEHexValue := -1;
End;

Function PEParseHex(S: String; Var C: TRGBColor): Boolean;
Var
 I, D: Integer;
 Value: LongInt;
Begin
 PEParseHex := False;
 If (Length(S) > 0) And (S[1] = '#') Then
  Delete(S,1,1);
 If Length(S) <> 6 Then
  Exit;
 Value := 0;
 For I := 1 To 6 Do Begin
  D := PEHexValue(S[I]);
  If D < 0 Then
   Exit;
  Value := Value*16+D;
 End;
 C := PERGB((Value Shr 16) And 255, (Value Shr 8) And 255, Value And 255);
 PEParseHex := True;
End;

Function PENumber(Value: Integer): String;
Var
 S: String;
Begin
 Str(Value,S);
 PENumber := S;
End;

Function PEInside(X, Y: Integer; Const R: TRect): Boolean;
Begin
 PEInside := (X >= R.Left) And (X <= R.Right) And
             (Y >= R.Top) And (Y <= R.Bottom);
End;

Procedure PERect(Var R: TRect; X, Y, W, H: Integer);
Begin
 R.Left := X;
 R.Top := Y;
 R.Right := X+W-1;
 R.Bottom := Y+H-1;
End;

Procedure PEHideMouse;
Begin
 {$IFDEF FPC}
 HideMouseCursor;
 {$ELSE}
 HideMouse;
 {$ENDIF}
End;

Procedure PEShowMouse;
Begin
 {$IFDEF FPC}
 ShowMouseCursor;
 {$ELSE}
 ShowMouse;
 {$ENDIF}
End;

Procedure PESetHardwareColor(Index: Integer; Const C: TRGBColor);
Begin
 If (Index < 0) Or (Index > GetMaxColor) Then
  Exit;
 {$IFDEF FPC}
 { Le pilote PtcGraph 256 couleurs utilise toute la plage 0..255. }
 SetRGBPalette(Index,C.R,C.G,C.B);
 {$ELSE}
 { Le pilote BGI VGA utilise des registres DAC sur 6 bits. }
 SetRGBPalette(Index,C.R Shr 2,C.G Shr 2,C.B Shr 2);
 {$ENDIF}
End;

Function PENearestVGA(Const C: TRGBColor): Integer;
Var
 I, Best: Integer;
 DR, DG, DB, Distance, BestDistance: LongInt;
 D: TRGBColor;
Begin
 Best := 0;
 BestDistance := 200000;
 For I := 0 To 15 Do Begin
  D := PEDefaultColor(I);
  DR := LongInt(C.R)-D.R;
  DG := LongInt(C.G)-D.G;
  DB := LongInt(C.B)-D.B;
  Distance := DR*DR+DG*DG+DB*DB;
  If Distance < BestDistance Then Begin
   BestDistance := Distance;
   Best := I;
  End;
 End;
 PENearestVGA := Best;
End;

Function PEDisplayColor(Const C: TRGBColor): Integer;
Var
 R, G, B: Integer;
Begin
 If GetMaxColor < 255 Then Begin
  PEDisplayColor := PENearestVGA(C);
  Exit;
 End;
 R := (LongInt(C.R)*5+127) Div 255;
 G := (LongInt(C.G)*7+127) Div 255;
 B := (LongInt(C.B)*3+127) Div 255;
 PEDisplayColor := PE_CUBE_FIRST+R*32+G*4+B;
End;

Procedure PEBuildDisplayPalette;
Var
 R, G, B, Index: Integer;
 C: TRGBColor;
Begin
 If GetMaxColor < 255 Then
  Exit;
 For R := 0 To 5 Do
  For G := 0 To 7 Do
   For B := 0 To 3 Do Begin
    Index := PE_CUBE_FIRST+R*32+G*4+B;
    C := PERGB(R*51,(G*255+3) Div 7,B*85);
    PESetHardwareColor(Index,C);
   End;
End;

Procedure PESyncFields(Var D: TPEState);
Begin
 D.Fields[0] := PENumber(D.Hue);
 D.Fields[1] := PENumber(D.Saturation);
 D.Fields[2] := PENumber(D.Luminance);
 D.Fields[3] := PENumber(D.RGB.R);
 D.Fields[4] := PENumber(D.RGB.G);
 D.Fields[5] := PENumber(D.RGB.B);
 D.Fields[6] := PEHexColor(D.RGB);
 D.FieldError := -1;
End;

Procedure PESelectRGB(Var D: TPEState; Const C: TRGBColor);
Begin
 D.Previous := D.RGB;
 D.RGB := C;
 D.RGB.A := 255;
 PERGBToHSL(D.RGB,D.Hue,D.Saturation,D.Luminance);
 PESyncFields(D);
 D.Dirty := True;
End;

Procedure PESelectHSL(Var D: TPEState);
Begin
 D.Previous := D.RGB;
 D.RGB := PEHSLToRGB(D.Hue,D.Saturation,D.Luminance);
 PESyncFields(D);
 D.Dirty := True;
End;

Function PEFieldMaximum(Index: Integer): Integer;
Begin
 Case Index Of
  0: PEFieldMaximum := 239;
  1,2: PEFieldMaximum := 240;
 Else
  PEFieldMaximum := 255;
 End;
End;

Function PEApplyField(Var D: TPEState; Index: Integer): Boolean;
Var
 Value, Code: Integer;
 C: TRGBColor;
Begin
 PEApplyField := False;
 If (Index < 0) Or (Index >= PE_FIELD_COUNT) Then
  Exit;
 If Index = 6 Then Begin
  If Not PEParseHex(D.Fields[Index],C) Then Begin
   D.FieldError := Index;
   D.Status := 'Hexadecimal : saisir exactement 6 chiffres, de 000000 a FFFFFF.';
   D.Dirty := True;
   Exit;
  End;
  PESelectRGB(D,C);
 End
 Else Begin
  Val(D.Fields[Index],Value,Code);
  If (Code <> 0) Or (Value < 0) Or (Value > PEFieldMaximum(Index)) Then Begin
   D.FieldError := Index;
   D.Status := 'Valeur attendue : 0 a '+PENumber(PEFieldMaximum(Index))+'.';
   D.Dirty := True;
   Exit;
  End;
  Case Index Of
   0: D.Hue := Value;
   1: D.Saturation := Value;
   2: D.Luminance := Value;
   3: D.RGB.R := Value;
   4: D.RGB.G := Value;
   5: D.RGB.B := Value;
  End;
  If Index < 3 Then
   PESelectHSL(D)
  Else
   PESelectRGB(D,D.RGB);
 End;
 D.Status := 'Couleur : #'+PEHexColor(D.RGB)+'. Validez avec OK pour appliquer.';
 PEApplyField := True;
End;

Function PELeaveField(Var D: TPEState): Boolean;
Begin
 PELeaveField := True;
 If (D.Focus >= PE_FOCUS_FIELD) And (D.Focus < PE_FOCUS_BUTTON) Then
  PELeaveField := PEApplyField(D,D.Focus-PE_FOCUS_FIELD);
End;

Procedure PELayout(Var D: TPEState);
Var
 I, Col, Row: Integer;
Begin
 If D.Expanded Then
  D.W := PE_DIALOG_W
 Else
  D.W := PE_COMPACT_W;
 D.H := PE_DIALOG_H;
 D.X := (ScreenWidth-D.W) Div 2;
 D.Y := (ScreenHeight-D.H) Div 2;
 For I := 0 To 5 Do Begin
  Col := I Div 3;
  Row := I Mod 3;
  If Col = 0 Then
   PERect(D.FieldRects[I],D.X+375,D.Y+244+Row*25,43,20)
  Else
   PERect(D.FieldRects[I],D.X+499,D.Y+244+Row*25,35,20);
 End;
 PERect(D.FieldRects[6],D.X+375,D.Y+320,90,20);
 PERect(D.Buttons[0],D.X+12,D.Y+389,82,25);
 PERect(D.Buttons[1],D.X+104,D.Y+389,82,25);
 PERect(D.Buttons[2],D.X+196,D.Y+389,94,25);
 PERect(D.Buttons[3],D.X+12,D.Y+310,278,25);
 PERect(D.Buttons[4],D.X+12,D.Y+342,86,25);
 PERect(D.Buttons[5],D.X+108,D.Y+342,86,25);
 PERect(D.Buttons[6],D.X+204,D.Y+342,86,25);
 PERect(D.Buttons[7],D.X+314,D.Y+350,288,25);
 PERect(D.Buttons[8],D.X+476,D.Y+318,126,25);
 PERect(D.Buttons[9],D.X+314,D.Y+389,288,25);
 D.PlaneDirty := True;
 D.Dirty := True;
End;

Procedure PEBevel(Const R: TRect; Pressed: Boolean);
Var
 Light, Shadow: Integer;
Begin
 Light := White;
 Shadow := DarkGray;
 If Pressed Then Begin
  Light := DarkGray;
  Shadow := White;
 End;
 SetColor(Light);
 Line(R.Left,R.Bottom,R.Left,R.Top);
 Line(R.Left,R.Top,R.Right,R.Top);
 SetColor(Shadow);
 Line(R.Right,R.Top,R.Right,R.Bottom);
 Line(R.Right,R.Bottom,R.Left,R.Bottom);
End;

Procedure PEFill(Const R: TRect; Color: Integer);
Begin
 SetFillStyle(SolidFill,Color);
 Bar(R.Left,R.Top,R.Right,R.Bottom);
End;

Procedure PEFocusRect(Const R: TRect);
Begin
 SetColor(Black);
 SetLineStyle(DottedLn,0,NormWidth);
 Rectangle(R.Left+3,R.Top+3,R.Right-3,R.Bottom-3);
 SetLineStyle(SolidLn,0,NormWidth);
End;

Procedure PELabel(X, Y: Integer; Const Caption: String);
Begin
 SetColor(Black);
 OutTextXY(X,Y,Caption);
End;

Procedure PEButton(Const R: TRect; Const Caption: String; Focused: Boolean);
Var
 TX, TY: Integer;
Begin
 PEFill(R,LightGray);
 PEBevel(R,False);
 TX := R.Left+(R.Right-R.Left+1-TextWidth(Caption)) Div 2;
 TY := R.Top+(R.Bottom-R.Top+1-TextHeight(Caption)) Div 2;
 PELabel(TX,TY,Caption);
 If Focused Then
  PEFocusRect(R);
End;

Procedure PESwatch(Const R: TRect; Const C: TRGBColor; Selected: Boolean);
Var
 Inner: TRect;
Begin
 PEFill(R,LightGray);
 PEBevel(R,True);
 Inner := R;
 Inc(Inner.Left,3);
 Inc(Inner.Top,3);
 Dec(Inner.Right,3);
 Dec(Inner.Bottom,3);
 PEFill(Inner,PEDisplayColor(C));
 If Selected Then Begin
  SetColor(Black);
  Rectangle(R.Left-2,R.Top-2,R.Right+2,R.Bottom+2);
  SetColor(White);
  Rectangle(Inner.Left-1,Inner.Top-1,Inner.Right+1,Inner.Bottom+1);
 End;
End;

Procedure PEGridRect(Const D: TPEState; Grid, Index: Integer; Var R: TRect);
Var
 X, Y, Columns, CellW, CellH: Integer;
Begin
 X := D.X+14;
 Columns := 8;
 CellW := 34;
 CellH := 22;
 Case Grid Of
  PE_FOCUS_BASIC: Y := D.Y+45;
  PE_FOCUS_CUSTOM: Y := D.Y+205;
 Else
  Begin
   Y := D.Y+270;
   Columns := 14;
   CellW := 19;
   CellH := 17;
  End;
 End;
 PERect(R,X+(Index Mod Columns)*CellW,Y+(Index Div Columns)*CellH,
        CellW-5,CellH-5);
End;

Procedure PEDrawGrids(Const D: TPEState);
Var
 I: Integer;
 R: TRect;
Begin
 PELabel(D.X+12,D.Y+30,'Couleurs de base :');
 For I := 0 To PE_BASIC_COUNT-1 Do Begin
  PEGridRect(D,PE_FOCUS_BASIC,I,R);
  PESwatch(R,PEBasicColor(I),(I = D.BasicIndex) And (D.Focus = PE_FOCUS_BASIC));
 End;
 PELabel(D.X+12,D.Y+188,'Couleurs personnalisees :');
 For I := 0 To PE_CUSTOM_COUNT-1 Do Begin
  PESetHardwareColor(PE_CUSTOM_FIRST+I,D.Customs[I]);
  PEGridRect(D,PE_FOCUS_CUSTOM,I,R);
  PESwatch(R,D.Customs[I],I = D.CustomIndex);
  If GetMaxColor >= 255 Then Begin
   SetFillStyle(SolidFill,PE_CUSTOM_FIRST+I);
   Bar(R.Left+3,R.Top+3,R.Right-3,R.Bottom-3);
  End;
 End;
 PELabel(D.X+12,D.Y+253,'Case de la palette a modifier :');
 For I := 0 To PE_SLOT_COUNT-1 Do Begin
  PEGridRect(D,PE_FOCUS_SLOTS,I,R);
  PESwatch(R,D.Slots[I],I = D.SlotIndex);
 End;
End;

Procedure PEDrawPlane(Const D: TPEState);
Var
 X, Y, PX, PY: Integer;
 C: TRGBColor;
Begin
 { La zone conserve une luminosite mediane : les teintes restent visibles
   meme lorsque la couleur selectionnee est actuellement noire ou blanche. }
 For Y := 0 To 159 Do
  For X := 0 To 255 Do Begin
   C := PEHSLToRGB((LongInt(X)*239) Div 255,
                 240-(LongInt(Y)*240) Div 159,120);
   PutPixel(D.X+314+X,D.Y+45+Y,PEDisplayColor(C));
  End;
 SetColor(DarkGray);
 Rectangle(D.X+313,D.Y+44,D.X+570,D.Y+205);
 PX := D.X+314+(LongInt(D.Hue)*255) Div 239;
 PY := D.Y+45+159-(LongInt(D.Saturation)*159) Div 240;
 SetColor(White);
 Circle(PX,PY,5);
 SetColor(Black);
 Circle(PX,PY,4);
 Line(PX-7,PY,PX-3,PY);
 Line(PX+3,PY,PX+7,PY);
 Line(PX,PY-7,PX,PY-3);
 Line(PX,PY+3,PX,PY+7);
End;

Procedure PEDrawLuminance(Const D: TPEState);
Var
 Y, Marker: Integer;
 C: TRGBColor;
Begin
 For Y := 0 To 159 Do Begin
  C := PEHSLToRGB(D.Hue,D.Saturation,240-(LongInt(Y)*240) Div 159);
  SetColor(PEDisplayColor(C));
  Line(D.X+582,D.Y+45+Y,D.X+594,D.Y+45+Y);
 End;
 SetColor(DarkGray);
 Rectangle(D.X+581,D.Y+44,D.X+595,D.Y+205);
 Marker := D.Y+45+159-(LongInt(D.Luminance)*159) Div 240;
 SetColor(Black);
 Line(D.X+597,Marker,D.X+603,Marker-4);
 Line(D.X+597,Marker,D.X+603,Marker+4);
 Line(D.X+603,Marker-4,D.X+603,Marker+4);
End;

Procedure PEDrawPreview(Const D: TPEState);
Var
 R: TRect;
 C1, C2: Integer;
Begin
 C1 := PEDisplayColor(D.Original);
 C2 := PEDisplayColor(D.RGB);
 If GetMaxColor >= 255 Then Begin
  PESetHardwareColor(PE_OLD_PREVIEW,D.Original);
  PESetHardwareColor(PE_PREVIEW,D.RGB);
  C1 := PE_OLD_PREVIEW;
  C2 := PE_PREVIEW;
 End;
 PERect(R,D.X+314,D.Y+215,132,22);
 PEFill(R,C1);
 PEBevel(R,True);
 PERect(R,D.X+450,D.Y+215,152,22);
 PEFill(R,C2);
 PEBevel(R,True);
End;

Procedure PEDrawField(Const D: TPEState; Index: Integer);
Const
 Labels: Array[0..6] of String[8] =
  ('Teinte:','Satur.:','Lumin.:','Rouge:','Vert:','Bleu:','Hexa: #');
Var
 R: TRect;
 S: String;
 Focused: Boolean;
Begin
 R := D.FieldRects[Index];
 Focused := D.Focus = PE_FOCUS_FIELD+Index;
 PELabel(R.Left-61,R.Top+6,Labels[Index]);
 PEFill(R,White);
 PEBevel(R,True);
 If Focused And D.FieldSelected Then Begin
  SetFillStyle(SolidFill,Blue);
  Bar(R.Left+3,R.Top+3,R.Right-3,R.Bottom-3);
  SetColor(White);
 End
 Else
  SetColor(Black);
 S := D.Fields[Index];
 OutTextXY(R.Left+5,R.Top+6,S);
 If Focused And Not D.FieldSelected Then Begin
  SetColor(Black);
  Line(R.Left+5+TextWidth(S),R.Top+4,
       R.Left+5+TextWidth(S),R.Bottom-4);
 End;
 If D.FieldError = Index Then Begin
  SetColor(Red);
  Rectangle(R.Left-1,R.Top-1,R.Right+1,R.Bottom+1);
 End;
End;

Procedure PEDrawSliders(Const D: TPEState);
Var
 Channel, X, Y, Value: Integer;
 C: TRGBColor;
Begin
 For Channel := 0 To 2 Do Begin
  Y := D.Y+248+Channel*25;
  For X := 0 To 57 Do Begin
   C := D.RGB;
   Value := (LongInt(X)*255) Div 57;
   Case Channel Of
    0: C.R := Value;
    1: C.G := Value;
    2: C.B := Value;
   End;
   SetColor(PEDisplayColor(C));
   Line(D.X+538+X,Y,D.X+538+X,Y+9);
  End;
  Case Channel Of
   0: Value := D.RGB.R;
   1: Value := D.RGB.G;
   2: Value := D.RGB.B;
  End;
  X := D.X+538+(LongInt(Value)*57) Div 255;
  SetColor(Black);
  Line(X-2,Y+12,X,Y+10);
  Line(X,Y+10,X+2,Y+12);
 End;
End;

Procedure PEDrawButtons(Const D: TPEState);
Const
 Captions: Array[0..9] of String[35] = (
  'OK','Annuler','Aide (F1)','Definir les couleurs >>',
  'Importer','Exporter','Reinitial.','Ajouter aux couleurs personnalisees',
  'Originale','Appliquer a la case selectionnee');
Var
 I: Integer;
 S: String;
Begin
 For I := 0 To PE_BUTTON_COUNT-1 Do Begin
  If (I < 7) Or D.Expanded Then Begin
   S := Captions[I];
   If (I = 3) And D.Expanded Then
    S := '<< Masquer les reglages avances';
   PEButton(D.Buttons[I],S,D.Focus = PE_FOCUS_BUTTON+I);
  End;
 End;
End;

Procedure PEDrawTarget(Const D: TPEState);
Var
 R: TRect;
Begin
 PERect(R,D.X+12,D.Y+369,278,15);
 PEFill(R,LightGray);
 If D.TargetBackground Then
  PELabel(R.Left,R.Top+3,'( ) Premier plan  (*) Arriere-plan')
 Else
  PELabel(R.Left,R.Top+3,'(*) Premier plan  ( ) Arriere-plan');
End;

Procedure PEDraw(Var D: TPEState);
Var
 R: TRect;
 I: Integer;
Begin
 PEHideMouse;
 SetWriteMode(CopyPut);
 SetLineStyle(SolidLn,0,NormWidth);
 PERect(R,D.X,D.Y,D.W,D.H);
 PEFill(R,LightGray);
 PEBevel(R,False);
 SetFillStyle(SolidFill,Blue);
 Bar(D.X+3,D.Y+3,D.X+D.W-4,D.Y+21);
 SetColor(White);
 OutTextXY(D.X+9,D.Y+7,'Modifier les couleurs - PAINT');
 OutTextXY(D.X+D.W-18,D.Y+7,'X');
 PEDrawGrids(D);
 PEDrawButtons(D);
 PEDrawTarget(D);
 If D.Expanded Then Begin
  PELabel(D.X+314,D.Y+30,'Teinte / saturation');
  PEDrawPlane(D);
  PEDrawLuminance(D);
  PEDrawPreview(D);
  For I := 0 To PE_FIELD_COUNT-1 Do
   PEDrawField(D,I);
  PEDrawSliders(D);
  { Statut place au-dessus du dialogue, dans une bande reservee. }
 End;
 SetFillStyle(SolidFill,LightGray);
 Bar(0,ScreenHeight-STATUSBAR_HEIGHT,ScreenWidth-1,ScreenHeight-1);
 PELabel(5,ScreenHeight-STATUSBAR_HEIGHT+5,D.Status);
 PEShowMouse;
 D.Dirty := False;
 D.PlaneDirty := False;
End;

Procedure PEChooseBasic(Var D: TPEState; Index: Integer);
Begin
 D.BasicIndex := PEClamp(Index,0,PE_BASIC_COUNT-1);
 D.Focus := PE_FOCUS_BASIC;
 PESelectRGB(D,PEBasicColor(D.BasicIndex));
 D.Status := 'Couleur de base selectionnee. OK : utiliser cette couleur.';
End;

Procedure PEChooseCustom(Var D: TPEState; Index: Integer);
Begin
 D.CustomIndex := PEClamp(Index,0,PE_CUSTOM_COUNT-1);
 D.Focus := PE_FOCUS_CUSTOM;
 PESelectRGB(D,D.Customs[D.CustomIndex]);
 D.Status := 'Couleur personnalisee '+PENumber(D.CustomIndex+1)+' selectionnee.';
End;

Procedure PEChooseSlot(Var D: TPEState; Index: Integer);
Begin
 D.SlotIndex := PEClamp(Index,0,PE_SLOT_COUNT-1);
 D.Focus := PE_FOCUS_SLOTS;
 PESelectRGB(D,D.Slots[D.SlotIndex]);
 D.Status := 'Case '+PENumber(D.SlotIndex+1)+' : choisissez sa nouvelle couleur.';
End;

Procedure PEAddCustom(Var D: TPEState);
Begin
 D.Customs[D.CustomIndex] := D.RGB;
 D.Status := 'Couleur memorisee en case personnalisee '+
             PENumber(D.CustomIndex+1)+'.';
 D.CustomIndex := (D.CustomIndex+1) Mod PE_CUSTOM_COUNT;
 D.Dirty := True;
End;

Procedure PEStageSlot(Var D: TPEState);
Begin
 D.Slots[D.SlotIndex] := D.RGB;
 D.Status := 'Case '+PENumber(D.SlotIndex+1)+' preparee. OK pour enregistrer.';
 D.Dirty := True;
End;

Procedure PEResetSlots(Var D: TPEState);
Const
 DefaultIndices: Array[0..15] of Byte =
  (0,15,4,2,1,14,3,5,7,8,12,10,9,11,13,6);
Var
 I: Integer;
Begin
 For I := 0 To PE_SLOT_COUNT-1 Do Begin
  If I < 16 Then
   D.Slots[I] := PEDefaultColor(DefaultIndices[I])
  Else
   D.Slots[I] := PEDefaultColor(I Mod 16);
 End;
 For I := 0 To PE_CUSTOM_COUNT-1 Do
  D.Customs[I] := PERGB(255,255,255);
 PESelectRGB(D,D.Slots[D.SlotIndex]);
 D.Status := 'Palette par defaut preparee. Annuler restaure la palette precedente.';
End;

Procedure PEHelp(Var D: TPEState);
Begin
 ShowMessage('Aide - Modifier les couleurs',
  'Tab : controle suivant ; fleches : ajuster.'+#10+
  'RVB 0..255 ; teinte 0..239 ; S/L 0..240.'+#10+
  'Hexa : RRVVBB. Entree valide, Echap annule.'+#10+
  'F2 : memoriser ; F3 : appliquer a la case.'+#10+
  'Importer/Exporter : fichier JASC-PAL.');
 D.Status := 'F1 aide | Tab navigation | Entree OK | Echap annuler';
 D.Dirty := True;
End;

Function PEReadPaletteLine(Var F: Text; Var S: String): Boolean;
Begin
 PEReadPaletteLine := False;
 If Eof(F) Then
  Exit;
 {$I-}
 ReadLn(F,S);
 {$I+}
 If IOResult <> 0 Then
  Exit;
 PEReadPaletteLine := True;
End;

Function PEParseTriplet(Const S: String; Var C: TRGBColor): Boolean;
Var
 I, Start, Count, Value, Code: Integer;
 Values: Array[0..2] of Integer;
 Token: String;
Begin
 PEParseTriplet := False;
 I := 1;
 Count := 0;
 While I <= Length(S) Do Begin
  While (I <= Length(S)) And ((S[I] = ' ') Or (S[I] = #9)) Do
   Inc(I);
  If I > Length(S) Then
   Break;
  If Count >= 3 Then
   Exit;
  Start := I;
  While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do
   Inc(I);
  Token := Copy(S,Start,I-Start);
  Val(Token,Value,Code);
  If (Code <> 0) Or (Value < 0) Or (Value > 255) Then
   Exit;
  Values[Count] := Value;
  Inc(Count);
 End;
 If Count <> 3 Then
  Exit;
 C := PERGB(Values[0],Values[1],Values[2]);
 PEParseTriplet := True;
End;

Function PELoadPalette(Const FileName: String; Var D: TPEState): Boolean;
Var
 F: Text;
 S: String;
 Count, Code, I, CloseError: Integer;
 C: TRGBColor;
 NewSlots: TPESlotColors;
 NewCustoms: TPECustomColors;
 Valid: Boolean;
Begin
 PELoadPalette := False;
 Assign(F,FileName);
 {$I-}
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Begin
  D.Status := 'Impossible d ouvrir cette palette.';
  Exit;
 End;
 NewSlots := D.Slots;
 NewCustoms := D.Customs;
 Valid := PEReadPaletteLine(F,S);
 If Valid Then
  Valid := S = 'JASC-PAL';
 If Valid Then
  Valid := PEReadPaletteLine(F,S);
 If Valid Then
  Valid := S = '0100';
 If Valid Then
  Valid := PEReadPaletteLine(F,S);
 Count := 0;
 If Valid Then Begin
  Val(S,Count,Code);
  Valid := (Code = 0) And (Count >= 1) And (Count <= 256);
 End;
 I := 0;
 While Valid And (I < Count) Do Begin
  Valid := PEReadPaletteLine(F,S);
  If Valid Then
   Valid := PEParseTriplet(S,C);
  If Valid Then Begin
   If I < PE_SLOT_COUNT Then
    NewSlots[I] := C
   Else If I < PE_SLOT_COUNT+PE_CUSTOM_COUNT Then
    NewCustoms[I-PE_SLOT_COUNT] := C;
  End;
  Inc(I);
 End;
 {$I-}
 Close(F);
 {$I+}
 CloseError := IOResult;
 If Not Valid Or (CloseError <> 0) Then Begin
  D.Status := 'Palette invalide : fichier JASC-PAL 0100 attendu, RVB entre 0 et 255.';
  Exit;
 End;
 D.Slots := NewSlots;
 D.Customs := NewCustoms;
 PESelectRGB(D,D.Slots[D.SlotIndex]);
 D.Status := PENumber(Count)+' couleurs lues. OK pour appliquer la palette.';
 PELoadPalette := True;
End;

Function PESavePalette(Const FileName: String; Const D: TPEState): Boolean;
Var
 F: Text;
 I, ErrorCode, CloseError: Integer;
 C: TRGBColor;
Begin
 PESavePalette := False;
 Assign(F,FileName);
 {$I-}
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then
  Exit;
 {$I-}
 WriteLn(F,'JASC-PAL');
 WriteLn(F,'0100');
 WriteLn(F,PE_SLOT_COUNT+PE_CUSTOM_COUNT);
 {$I+}
 ErrorCode := IOResult;
 I := 0;
 While (I < PE_SLOT_COUNT+PE_CUSTOM_COUNT) And (ErrorCode = 0) Do Begin
  If I < PE_SLOT_COUNT Then
   C := D.Slots[I]
  Else
   C := D.Customs[I-PE_SLOT_COUNT];
  {$I-}
  WriteLn(F,C.R,' ',C.G,' ',C.B);
  {$I+}
  ErrorCode := IOResult;
  Inc(I);
 End;
 {$I-}
 Close(F);
 {$I+}
 CloseError := IOResult;
 PESavePalette := (ErrorCode = 0) And (CloseError = 0);
End;

Procedure PEFileAction(Var D: TPEState; Exporting: Boolean);
Var
 FileName, Title: String;
 Exists: SearchRec;
 Saved: TPESlotColors;
Begin
 FileName := 'PAINT.PAL';
 If Exporting Then
  Title := 'Exporter la palette JASC-PAL'
 Else
  Title := 'Importer une palette JASC-PAL';
 If PromptString(Title,'Fichier .PAL :',FileName) And (FileName <> '') Then Begin
  If ExtractFileExt(FileName) = '' Then
   FileName := FileName+'.PAL';
  If Exporting Then Begin
   FindFirst(FileName,AnyFile,Exists);
   If DosError = 0 Then Begin
    If PromptYesNoCancel('Remplacer la palette',
                        'Ce fichier existe. Le remplacer ?') <> 1 Then Begin
     D.Dirty := True;
     Exit;
    End;
   End;
   { Exporter aussi la couleur actuellement en cours de reglage. }
   Saved := D.Slots;
   D.Slots[D.SlotIndex] := D.RGB;
   If PESavePalette(FileName,D) Then
    D.Status := 'Palette exportee : 28 cases et 16 couleurs personnalisees.'
   Else
    D.Status := 'Echec d ecriture. Verifiez le chemin et les droits du fichier.';
   D.Slots := Saved;
  End
  Else
   If Not PELoadPalette(FileName,D) Then
    D.FieldError := -1;
 End;
 D.Dirty := True;
End;

Procedure PEActivateButton(Var D: TPEState; Index: Integer);
Begin
 If Index = 1 Then Begin
  D.Done := True;
  D.Accepted := False;
  Exit;
 End;
 If Not PELeaveField(D) Then
  Exit;
 Case Index Of
  0: Begin
   PEStageSlot(D);
   D.Accepted := True;
   D.Done := True;
  End;
  2: PEHelp(D);
  3: Begin
   D.Expanded := Not D.Expanded;
   { Effacer le precedent dialogue depuis le vrai buffer du dessin. }
   RedrawInterface;
   PELayout(D);
  End;
  4: PEFileAction(D,False);
  5: PEFileAction(D,True);
  6: PEResetSlots(D);
  7: PEAddCustom(D);
  8: Begin
   PESelectRGB(D,D.Original);
   D.Status := 'Couleur d origine restauree dans les reglages.';
  End;
  9: PEStageSlot(D);
 End;
End;

Procedure PEFocus(Var D: TPEState; NewFocus: Integer);
Begin
 If Not PELeaveField(D) Then
  Exit;
 D.Focus := NewFocus;
 D.FieldSelected := (NewFocus >= PE_FOCUS_FIELD) And
                    (NewFocus < PE_FOCUS_BUTTON);
 D.FieldError := -1;
 D.Dirty := True;
End;

Procedure PENextFocus(Var D: TPEState; Backwards: Boolean);
Var
 Next: Integer;
 Valid: Boolean;
Begin
 Next := D.Focus;
 Repeat
  If Backwards Then
   Dec(Next)
  Else
   Inc(Next);
  If Next > PE_FOCUS_LAST Then
   Next := 0;
  If Next < 0 Then
   Next := PE_FOCUS_LAST;
  Valid := True;
  If Not D.Expanded Then Begin
   If (Next >= PE_FOCUS_PLANE) And (Next < PE_FOCUS_BUTTON) Then
    Valid := False;
   If Next >= PE_FOCUS_BUTTON+7 Then
    Valid := False;
  End;
 Until Valid;
 PEFocus(D,Next);
End;

Procedure PEChangeField(Var D: TPEState; Delta: Integer);
Var
 Index, Value, Code: Integer;
 C: TRGBColor;
Begin
 Index := D.Focus-PE_FOCUS_FIELD;
 If Index = 6 Then Begin
  If Not PEParseHex(D.Fields[6],C) Then
   Exit;
  C.R := PEClamp(Integer(C.R)+Delta,0,255);
  C.G := PEClamp(Integer(C.G)+Delta,0,255);
  C.B := PEClamp(Integer(C.B)+Delta,0,255);
  PESelectRGB(D,C);
 End
 Else Begin
  Val(D.Fields[Index],Value,Code);
  If Code <> 0 Then
   Value := 0;
  Value := PEClamp(Value+Delta,0,PEFieldMaximum(Index));
  D.Fields[Index] := PENumber(Value);
  If PEApplyField(D,Index) Then
   D.FieldSelected := True;
 End;
End;

Procedure PEArrow(Var D: TPEState; DX, DY: Integer);
Var
 Index: Integer;
Begin
 Case D.Focus Of
  PE_FOCUS_BASIC: Begin
   Index := PEClamp(D.BasicIndex+DX+DY*8,0,PE_BASIC_COUNT-1);
   PEChooseBasic(D,Index);
  End;
  PE_FOCUS_CUSTOM: Begin
   Index := PEClamp(D.CustomIndex+DX+DY*8,0,PE_CUSTOM_COUNT-1);
   PEChooseCustom(D,Index);
  End;
  PE_FOCUS_SLOTS: Begin
   Index := PEClamp(D.SlotIndex+DX+DY*14,0,PE_SLOT_COUNT-1);
   PEChooseSlot(D,Index);
  End;
  PE_FOCUS_PLANE: Begin
   D.Hue := PEClamp(D.Hue+DX,0,239);
   D.Saturation := PEClamp(D.Saturation-DY,0,240);
   PESelectHSL(D);
  End;
  PE_FOCUS_LUMA: Begin
   D.Luminance := PEClamp(D.Luminance-DY+DX,0,240);
   PESelectHSL(D);
  End;
 Else
  If (D.Focus >= PE_FOCUS_FIELD) And (D.Focus < PE_FOCUS_BUTTON) Then
   PEChangeField(D,DX-DY);
 End;
End;

Procedure PEFieldKey(Var D: TPEState; K: Char);
Var
 Index, Limit: Integer;
 S: String;
 Allowed: Boolean;
Begin
 Index := D.Focus-PE_FOCUS_FIELD;
 If (Index < 0) Or (Index >= PE_FIELD_COUNT) Then
  Exit;
 S := D.Fields[Index];
 If K = #1 Then Begin
  D.FieldSelected := True;
  D.Dirty := True;
  Exit;
 End;
 If K = #8 Then Begin
  If D.FieldSelected Then
   S := ''
  Else If Length(S) > 0 Then
   Delete(S,Length(S),1);
 End
 Else Begin
  K := UpCase(K);
  Allowed := (K >= '0') And (K <= '9');
  Limit := 3;
  If Index = 6 Then Begin
   Allowed := PEHexValue(K) >= 0;
   Limit := 6;
  End;
  If Not Allowed Then
   Exit;
  If D.FieldSelected Then
   S := '';
  If Length(S) < Limit Then
   S := S+K;
 End;
 D.Fields[Index] := S;
 D.FieldSelected := False;
 D.FieldError := -1;
 D.Status := 'Entree ou Tab valide le champ ; fleches ajustent sa valeur.';
 D.Dirty := True;
End;

Procedure PEKeyboard(Var D: TPEState);
Var
 K, Extended: Char;
 Temp: TRGBColor;
Begin
 K := ReadKey;
 If K = #0 Then Begin
  Extended := ReadKey;
  Case Ord(Extended) Of
   15: PENextFocus(D,True);
   59: PEHelp(D);
   60: If PELeaveField(D) Then PEAddCustom(D);
   61: If PELeaveField(D) Then PEStageSlot(D);
   72: PEArrow(D,0,-1);
   80: PEArrow(D,0,1);
   75: PEArrow(D,-1,0);
   77: PEArrow(D,1,0);
   73: PEArrow(D,0,-10);
   81: PEArrow(D,0,10);
   83: If (D.Focus >= PE_FOCUS_FIELD) And
          (D.Focus < PE_FOCUS_BUTTON) Then Begin
    D.Fields[D.Focus-PE_FOCUS_FIELD] := '';
    D.FieldSelected := False;
    D.Dirty := True;
   End;
  End;
  Exit;
 End;
 Case K Of
  #27: Begin
   D.Done := True;
   D.Accepted := False;
  End;
  #9: PENextFocus(D,False);
  #13: Begin
   If D.Focus >= PE_FOCUS_BUTTON Then
    PEActivateButton(D,D.Focus-PE_FOCUS_BUTTON)
   Else If (D.Focus >= PE_FOCUS_FIELD) And (D.Focus < PE_FOCUS_BUTTON) Then Begin
    If PEApplyField(D,D.Focus-PE_FOCUS_FIELD) Then
     PEFocus(D,PE_FOCUS_BUTTON);
   End
   Else
    PEActivateButton(D,0);
  End;
  #26: Begin
   Temp := D.Previous;
   PESelectRGB(D,Temp);
   D.Status := 'Reglage precedent restaure (Ctrl+Z).';
  End;
  ' ': Begin
   If D.Focus >= PE_FOCUS_BUTTON Then
    PEActivateButton(D,D.Focus-PE_FOCUS_BUTTON);
  End;
 Else
  If D.Expanded Then
   PEFieldKey(D,K);
 End;
End;

Procedure PEPlaneMouse(Var D: TPEState; X, Y: Integer);
Begin
 X := PEClamp(X-D.X-314,0,255);
 Y := PEClamp(Y-D.Y-45,0,159);
 D.Hue := (LongInt(X)*239+127) Div 255;
 D.Saturation := 240-(LongInt(Y)*240+79) Div 159;
 PESelectHSL(D);
 D.Status := 'Glissez dans le spectre pour choisir teinte et saturation.';
End;

Procedure PELuminanceMouse(Var D: TPEState; Y: Integer);
Begin
 Y := PEClamp(Y-D.Y-45,0,159);
 D.Luminance := 240-(LongInt(Y)*240+79) Div 159;
 PESelectHSL(D);
 D.Status := 'Luminosite : 0 = noir, 120 = couleur mediane, 240 = blanc.';
End;

Procedure PESliderMouse(Var D: TPEState; Channel, X: Integer);
Var
 Value: Integer;
 C: TRGBColor;
Begin
 X := PEClamp(X-D.X-538,0,57);
 Value := (LongInt(X)*255+28) Div 57;
 C := D.RGB;
 Case Channel Of
  0: C.R := Value;
  1: C.G := Value;
  2: C.B := Value;
 End;
 PESelectRGB(D,C);
 D.Status := 'Curseur RVB : glissez pour ajuster la composante.';
End;

Procedure PEMouseDown(Var D: TPEState);
Var
 I, Grid, Count, Channel: Integer;
 R: TRect;
Begin
 { La fermeture et Annuler restent possibles meme avec un champ invalide. }
 If (D.MY >= D.Y+3) And (D.MY <= D.Y+21) And
    (D.MX >= D.X+D.W-25) And (D.MX < D.X+D.W) Then Begin
  PEActivateButton(D,1);
  Exit;
 End;
 If PEInside(D.MX,D.MY,D.Buttons[1]) Then Begin
  PEActivateButton(D,1);
  Exit;
 End;
 For I := 0 To PE_BUTTON_COUNT-1 Do Begin
  If (I < 7) Or D.Expanded Then
   If PEInside(D.MX,D.MY,D.Buttons[I]) Then Begin
    If Not PELeaveField(D) Then
     Exit;
    D.Focus := PE_FOCUS_BUTTON+I;
    PEActivateButton(D,I);
    Exit;
   End;
 End;
 If Not PELeaveField(D) Then
  Exit;
 For Grid := PE_FOCUS_BASIC To PE_FOCUS_SLOTS Do Begin
  Case Grid Of
   PE_FOCUS_BASIC: Count := PE_BASIC_COUNT;
   PE_FOCUS_CUSTOM: Count := PE_CUSTOM_COUNT;
  Else
   Count := PE_SLOT_COUNT;
  End;
  For I := 0 To Count-1 Do Begin
   PEGridRect(D,Grid,I,R);
   If PEInside(D.MX,D.MY,R) Then Begin
    Case Grid Of
     PE_FOCUS_BASIC: PEChooseBasic(D,I);
     PE_FOCUS_CUSTOM: PEChooseCustom(D,I);
     PE_FOCUS_SLOTS: PEChooseSlot(D,I);
    End;
    Exit;
   End;
  End;
 End;
 PERect(R,D.X+12,D.Y+369,278,15);
 If PEInside(D.MX,D.MY,R) Then Begin
  D.TargetBackground := D.MX >= D.X+150;
  D.Status := 'La couleur choisie sera utilisee pour le plan selectionne.';
  D.Dirty := True;
  Exit;
 End;
 If Not D.Expanded Then
  Exit;
 For I := 0 To PE_FIELD_COUNT-1 Do
  If PEInside(D.MX,D.MY,D.FieldRects[I]) Then Begin
   PEFocus(D,PE_FOCUS_FIELD+I);
   Exit;
  End;
 PERect(R,D.X+314,D.Y+45,256,160);
 If PEInside(D.MX,D.MY,R) Then Begin
  D.Focus := PE_FOCUS_PLANE;
  D.DragKind := 1;
  PEPlaneMouse(D,D.MX,D.MY);
  Exit;
 End;
 PERect(R,D.X+578,D.Y+43,29,164);
 If PEInside(D.MX,D.MY,R) Then Begin
  D.Focus := PE_FOCUS_LUMA;
  D.DragKind := 2;
  PELuminanceMouse(D,D.MY);
  Exit;
 End;
 For Channel := 0 To 2 Do Begin
  PERect(R,D.X+536,D.Y+245+Channel*25,64,19);
  If PEInside(D.MX,D.MY,R) Then Begin
   D.Focus := PE_FOCUS_FIELD+3+Channel;
   D.FieldSelected := True;
   D.DragKind := 3+Channel;
   PESliderMouse(D,Channel,D.MX);
   Exit;
  End;
 End;
End;

Procedure PEMouse(Var D: TPEState);
Begin
 GetMouseStateLocal(D.MX,D.MY,D.MB);
 If ((D.MB And 1) <> 0) And ((D.PrevButtons And 1) = 0) Then
  PEMouseDown(D)
 Else If ((D.MB And 1) <> 0) And (D.DragKind <> 0) Then Begin
  If (D.MX <> D.LastX) Or (D.MY <> D.LastY) Then
   Case D.DragKind Of
    1: PEPlaneMouse(D,D.MX,D.MY);
    2: PELuminanceMouse(D,D.MY);
    3..5: PESliderMouse(D,D.DragKind-3,D.MX);
   End;
 End;
 If (D.MB And 1) = 0 Then
  D.DragKind := 0;
 D.LastX := D.MX;
 D.LastY := D.MY;
 D.PrevButtons := D.MB;
End;

Procedure PEInitialize(Var D: TPEState);
Var
 I: Integer;
Begin
 FillChar(D,SizeOf(D),0);
 D.Expanded := True;
 D.SlotIndex := PEClamp(ActivePaletteSlot,0,PE_SLOT_COUNT-1);
 D.CustomIndex := 0;
 D.FieldError := -1;
 D.BasicIndex := 0;
 D.Focus := PE_FOCUS_BASIC;
 D.SavedPalette := ImageBuffer.Palette;
 For I := 0 To PE_SLOT_COUNT-1 Do
  D.Slots[I] := ImageBuffer.Palette[StandardPalette[I]];
 If Not PaintCustomReady Then Begin
  For I := 0 To PE_CUSTOM_COUNT-1 Do
   PaintCustomColors[I] := PERGB(255,255,255);
  PaintCustomReady := True;
 End;
 D.Customs := PaintCustomColors;
 D.Original := ImageBuffer.Palette[CurrentColor];
 D.Previous := D.Original;
 D.RGB := D.Original;
 D.Hue := 0;
 PERGBToHSL(D.RGB,D.Hue,D.Saturation,D.Luminance);
 PESyncFields(D);
 D.Status := 'F1 aide | Tab navigation | Entree OK | Echap annuler';
 If GetMaxColor < 255 Then
  D.Status := 'Mode 16 couleurs : apercu et dessin arrondis a la couleur VGA proche.';
 PELayout(D);
 GetMouseStateLocal(D.MX,D.MY,D.PrevButtons);
 D.LastX := D.MX;
 D.LastY := D.MY;
End;

Procedure PERestoreHardware(Const D: TPEState);
Var
 I: Integer;
Begin
 { Retablir la palette reelle : le cube n'appartient pas au document. }
 For I := 16 To 255 Do
  If I <= GetMaxColor Then
   PESetHardwareColor(I,D.SavedPalette[I]);
End;

Procedure PECommit(Const D: TPEState);
Var
 I, Index: Integer;
 Changed: Boolean;
Begin
 Changed := False;
 { Le snapshot garde les indices ET les couleurs pour Annuler/Retablir. }
 AddSnapshotToHistory(TOOL_PICKER);
 If GetMaxColor >= 255 Then Begin
  For I := 0 To PE_SLOT_COUNT-1 Do Begin
   Index := 16+I;
   If Not PESameColor(ImageBuffer.Palette[Index],D.Slots[I]) Then
    Changed := True;
   ImageBuffer.Palette[Index] := D.Slots[I];
   PESetHardwareColor(Index,D.Slots[I]);
   StandardPalette[I] := Index;
  End;
  Index := 16+D.SlotIndex;
 End
 Else Begin
  { Aucun changement des registres systeme en mode VGA 16 couleurs. }
  For I := 0 To PE_SLOT_COUNT-1 Do
   StandardPalette[I] := PENearestVGA(D.Slots[I]);
  Index := StandardPalette[D.SlotIndex];
 End;
 If D.TargetBackground Then
  BackgroundColor := Index
 Else
  CurrentColor := Index;
 ActivePaletteSlot := D.SlotIndex;
 PaintCustomColors := D.Customs;
 PaintCustomReady := True;
 If Changed Then Begin
  { Une image 1/4 bits doit pouvoir enregistrer les nouveaux indices. }
  If ImageBuffer.BitDepth < 8 Then
   ImageBuffer.BitDepth := 8;
  ImageBuffer.Modified := True;
 End;
End;

Procedure PEInstallDocumentPalette;
Var
 I: Integer;
Begin
 { Synchroniser les registres graphiques et les couleurs sauvegardees. }
 For I := 0 To 255 Do
  If I <= GetMaxColor Then
   PESetHardwareColor(I,ImageBuffer.Palette[I]);
End;

Procedure EditPaintPalette;
Var
 D: TPEState;
Begin
 { Un dialogue modal ne doit pas laisser le menu ou les fourmis de
   selection dans le buffer de l'image. Le canvas reste la source de verite. }
 MenuActive := False;
 RedrawInterface;
 PEInitialize(D);
 PEHideMouse;
 PEBuildDisplayPalette;
 PEShowMouse;
 While Not D.Done Do Begin
  If D.Dirty Then
   PEDraw(D);
  If KeyPressed Then
   PEKeyboard(D);
  If Not D.Done Then
   PEMouse(D);
  Delay(10);
 End;
 PEHideMouse;
 PERestoreHardware(D);
 If D.Accepted Then
  PECommit(D);
 PEShowMouse;
 { Consommer le relachement pour eviter un trait dans le dessin dessous. }
 Repeat
  GetMouseStateLocal(D.MX,D.MY,D.MB);
  If (D.MB And 1) <> 0 Then
   Delay(10);
 Until (D.MB And 1) = 0;
 OldMouseButtons := 0;
 MouseButtons := 0;
 RedrawInterface;
End;


{ Obtenir des couleurs : lecture du document indexe, jamais du dialogue.
  Toutes les couleurs, cases personnalisees et captures restent locales
  jusqu'a OK. Les pixels de CanvasImage ne sont jamais modifies ici. }

Const
 PG_HISTORY_COUNT = 32;
 PG_DOMINANT_COUNT = 16;
 PG_BUTTON_COUNT = 15;
 PG_MODE_COUNT = 6;
 PG_MAX_RADIUS = 8;
 PG_MAX_SAMPLES = 289;
 PG_FOCUS_LAST = 22;

Type
 TPGHistogram = Array[0..255] of LongInt;
 TPGHistory = Array[0..PG_HISTORY_COUNT-1] of TRGBColor;
 TPGSamples = Array[0..PG_MAX_SAMPLES-1] of Byte;
 TPGButtons = Array[0..PG_BUTTON_COUNT-1] of TRect;
 TPGState = Record
  PaletteData: TPEState;
  X, Y: Integer;
  ImageX, ImageY: Integer;
  Source: Integer;
  Method: Integer;
  Radius: Integer;
  Magnification: Integer;
  IgnoreBackground: Boolean;
  ShowGrid: Boolean;
  TargetBackground: Boolean;
  AddToBar: Boolean;
  Accepted, Done, Dirty: Boolean;
  ValidSample: Boolean;
  RGB, Original: TRGBColor;
  SampleCount: Integer;
  SampleRect: TRect;
  Histogram: TPGHistogram;
  DominantIndices: Array[0..PG_DOMINANT_COUNT-1] of Integer;
  DominantCounts: Array[0..PG_DOMINANT_COUNT-1] of LongInt;
  DominantCount: Integer;
  TotalPixels: LongInt;
  History: TPGHistory;
  HistoryCount: Integer;
  HistoryIndex: Integer;
  CustomIndex: Integer;
  DominantIndex: Integer;
  Focus: Integer;
  CoordText: Array[0..1] of String[5];
  CoordSelected: Boolean;
  CoordError: Integer;
  Buttons: TPGButtons;
  CoordRects: Array[0..1] of TRect;
  Thumbnail: TRect;
  ThumbnailImage: TRect;
  Loupe: TRect;
  Status: String[77];
  MX, MY, MB, PreviousButtons: Integer;
  LastMouseX, LastMouseY: Integer;
  DragThumbnail: Boolean;
 End;

Var
 PaintCapturedColors: TPGHistory;
 PaintCapturedCount: Integer;

Function PGHasImage: Boolean;
Begin
 PGHasImage := (CanvasImage <> Nil) And (CanvasImageW > 0) And
               (CanvasImageH > 0);
End;

Function PGReadIndex(X, Y: Integer; Var Index: Byte): Boolean;
Var
 P: PByte;
Begin
 PGReadIndex := False;
 If Not PGHasImage Then
  Exit;
 If (X < 0) Or (Y < 0) Or (X >= CanvasImageW) Or (Y >= CanvasImageH) Then
  Exit;
 P := CanvasImage;
 Inc(P,LongInt(Y)*LongInt(CanvasImageW)+X);
 Index := P^;
 PGReadIndex := True;
End;

Function PGReadRGB(X, Y: Integer; Var C: TRGBColor): Boolean;
Var
 Index: Byte;
 Valid: Boolean;
Begin
 Valid := PGReadIndex(X,Y,Index);
 If Valid Then
  C := ImageBuffer.Palette[Index];
 PGReadRGB := Valid;
End;

Function PGBrightness(Const C: TRGBColor): LongInt;
Begin
 { Ponderation entiere Rec.601, sans virgule flottante. }
 PGBrightness := LongInt(C.R)*299+LongInt(C.G)*587+LongInt(C.B)*114;
End;

Function PGDistance(Const A, B: TRGBColor): LongInt;
Var
 R, G, Bl: LongInt;
Begin
 R := LongInt(A.R)-B.R;
 G := LongInt(A.G)-B.G;
 Bl := LongInt(A.B)-B.B;
 PGDistance := R*R+G*G+Bl*Bl;
End;

Procedure PGSourceBounds(Const D: TPGState; Var R: TRect);
Begin
 R.Left := 0;
 R.Top := 0;
 R.Right := CanvasImageW-1;
 R.Bottom := CanvasImageH-1;
 If (D.Source = 1) And SelectionActive Then Begin
  R.Left := PEClamp(SelectionRect.Left-CanvasX,0,CanvasImageW-1);
  R.Top := PEClamp(SelectionRect.Top-CanvasY,0,CanvasImageH-1);
  R.Right := PEClamp(SelectionRect.Right-CanvasX,0,CanvasImageW-1);
  R.Bottom := PEClamp(SelectionRect.Bottom-CanvasY,0,CanvasImageH-1);
 End;
 If D.Source = 2 Then Begin
  R.Left:=ZOriginX; R.Top:=ZOriginY;
  R.Right:=Min(CanvasImageW-1,ZOriginX+ZCeilDiv(LongInt(CanvasWidth)*100,ZoomLevel)-1);
  R.Bottom:=Min(CanvasImageH-1,ZOriginY+ZCeilDiv(LongInt(CanvasHeight)*100,ZoomLevel)-1);
 End;
End;

Function PGAcceptColor(Const D: TPGState; Const C: TRGBColor): Boolean;
Begin
 PGAcceptColor := True;
 If D.IgnoreBackground Then
  PGAcceptColor := Not PESameColor(C,ImageBuffer.Palette[BackgroundColor]);
End;

Procedure PGSortSamples(Var Values: TPGSamples; Count: Integer);
Var
 I, J: Integer;
 Value: Byte;
Begin
 { Tri par insertion : au plus 289 echantillons, sans allocation. }
 For I := 1 To Count-1 Do Begin
  Value := Values[I];
  J := I-1;
  While J >= 0 Do Begin
   If Values[J] <= Value Then
    Break;
   Values[J+1] := Values[J];
   Dec(J);
  End;
  Values[J+1] := Value;
 End;
End;

Function PGMedian(Var Values: TPGSamples; Count: Integer): Integer;
Begin
 PGSortSamples(Values,Count);
 If (Count And 1) <> 0 Then
  PGMedian := Values[Count Div 2]
 Else
  PGMedian := (Integer(Values[Count Div 2-1])+Values[Count Div 2]) Div 2;
End;

Procedure PGSyncCoordinates(Var D: TPGState);
Begin
 D.CoordText[0] := PENumber(D.ImageX);
 D.CoordText[1] := PENumber(D.ImageY);
 D.CoordError := -1;
End;

Procedure PGSetColor(Var D: TPGState; Const C: TRGBColor);
Begin
 D.RGB := C;
 D.RGB.A := 255;
 D.ValidSample := True;
 D.Dirty := True;
End;

Function PGSampleAt(Var D: TPGState; X, Y: Integer): Boolean;
Var
 Region: TRect;
 SX, SY, I, J, Best, Count: Integer;
 Index: Byte;
 Reds, Greens, Blues: TPGSamples;
 Counts: TPGHistogram;
 SumR, SumG, SumB: LongInt;
 Weight, BestWeight: LongInt;
 C, ResultColor: TRGBColor;
Begin
 PGSampleAt := False;
 If Not PGHasImage Then Begin
  D.Status := 'Aucune image a echantillonner.';
  D.Dirty := True;
  Exit;
 End;
 PGSourceBounds(D,Region);
 X := PEClamp(X,Region.Left,Region.Right);
 Y := PEClamp(Y,Region.Top,Region.Bottom);
 D.ImageX := X;
 D.ImageY := Y;
 PGSyncCoordinates(D);
 D.SampleRect.Left := Max(Region.Left,X-D.Radius);
 D.SampleRect.Top := Max(Region.Top,Y-D.Radius);
 D.SampleRect.Right := Min(Region.Right,X+D.Radius);
 D.SampleRect.Bottom := Min(Region.Bottom,Y+D.Radius);
 If D.Method = 0 Then Begin
  PERect(D.SampleRect,X,Y,1,1);
 End;
 Count := 0;
 SumR := 0;
 SumG := 0;
 SumB := 0;
 FillChar(Counts,SizeOf(Counts),0);
 BestWeight := 0;
 If D.Method = 5 Then
  BestWeight := MaxLongInt;
 ResultColor := D.RGB;
 For SY := D.SampleRect.Top To D.SampleRect.Bottom Do
  For SX := D.SampleRect.Left To D.SampleRect.Right Do Begin
   If PGReadIndex(SX,SY,Index) Then Begin
    C := ImageBuffer.Palette[Index];
    If PGAcceptColor(D,C) Then Begin
     Reds[Count] := C.R;
     Greens[Count] := C.G;
     Blues[Count] := C.B;
     SumR := SumR+C.R;
     SumG := SumG+C.G;
     SumB := SumB+C.B;
     Inc(Counts[Index]);
     Weight := PGBrightness(C);
     If (Count = 0) Or
        ((D.Method = 4) And (Weight > BestWeight)) Or
        ((D.Method = 5) And (Weight < BestWeight)) Then Begin
      BestWeight := Weight;
      ResultColor := C;
     End;
     Inc(Count);
    End;
   End;
  End;
 D.SampleCount := Count;
 If Count = 0 Then Begin
  D.Status := 'Aucun pixel retenu : desactivez Ignorer le fond ou deplacez la pipette.';
  D.ValidSample := False;
  D.Dirty := True;
  Exit;
 End;
 Case D.Method Of
  1: ResultColor := PERGB((SumR+Count Div 2) Div Count,
                         (SumG+Count Div 2) Div Count,
                         (SumB+Count Div 2) Div Count);
  2: ResultColor := PERGB(PGMedian(Reds,Count),PGMedian(Greens,Count),
                         PGMedian(Blues,Count));
  3: Begin
   { Fusionner les indices qui representent le meme triplet RVB. }
   For I := 0 To 254 Do
    If Counts[I] > 0 Then
     For J := I+1 To 255 Do
      If (Counts[J] > 0) And PESameColor(ImageBuffer.Palette[I],
                                        ImageBuffer.Palette[J]) Then Begin
       Counts[I] := Counts[I]+Counts[J];
       Counts[J] := 0;
      End;
   Best := 0;
   For I := 1 To 255 Do
    If Counts[I] > Counts[Best] Then
     Best := I;
   ResultColor := ImageBuffer.Palette[Best];
  End;
 End;
 PGSetColor(D,ResultColor);
 D.Status := 'Position '+PENumber(X)+','+PENumber(Y)+' : '+
             PENumber(Count)+' pixel(s), #'+PEHexColor(D.RGB)+'.';
 PGSampleAt := True;
End;

Procedure PGAddHistory(Var D: TPGState);
Var
 I, Found, Last: Integer;
 C: TRGBColor;
Begin
 If Not D.ValidSample Then
  Exit;
 C := D.RGB;
 Found := -1;
 For I := 0 To D.HistoryCount-1 Do
  If PESameColor(D.History[I],C) Then
   Found := I;
 If Found >= 0 Then
  Last := Found
 Else Begin
  Last := Min(D.HistoryCount,PG_HISTORY_COUNT-1);
  If D.HistoryCount < PG_HISTORY_COUNT Then
   Inc(D.HistoryCount);
 End;
 For I := Last DownTo 1 Do
  D.History[I] := D.History[I-1];
 D.History[0] := C;
 D.HistoryIndex := 0;
 D.Status := 'Capture ajoutee a l historique : #'+PEHexColor(C)+'.';
 D.Dirty := True;
End;

Procedure PGHistogram(Var D: TPGState);
Var
 Region: TRect;
 X, Y, I, J, K, Best: Integer;
 P: PByte;
 Working: TPGHistogram;
 Counted: LongInt;
Begin
 FillChar(D.Histogram,SizeOf(D.Histogram),0);
 FillChar(D.DominantCounts,SizeOf(D.DominantCounts),0);
 For I := 0 To PG_DOMINANT_COUNT-1 Do
  D.DominantIndices[I] := -1;
 D.DominantCount := 0;
 D.TotalPixels := 0;
 If Not PGHasImage Then
  Exit;
 PGSourceBounds(D,Region);
 For Y := Region.Top To Region.Bottom Do Begin
  P := CanvasImage;
  Inc(P,LongInt(Y)*CanvasImageW+Region.Left);
  For X := Region.Left To Region.Right Do Begin
   If PGAcceptColor(D,ImageBuffer.Palette[P^]) Then Begin
    Inc(D.Histogram[P^]);
    Inc(D.TotalPixels);
   End;
   Inc(P);
  End;
 End;
 Working := D.Histogram;
 { Les frequences sont calculees sur toute la source, sans sous-echantillon. }
 For I := 0 To 254 Do
  If Working[I] > 0 Then
   For J := I+1 To 255 Do
    If (Working[J] > 0) And PESameColor(ImageBuffer.Palette[I],
                                      ImageBuffer.Palette[J]) Then Begin
     Working[I] := Working[I]+Working[J];
     Working[J] := 0;
    End;
 For K := 0 To PG_DOMINANT_COUNT-1 Do Begin
  Best := -1;
  Counted := 0;
  For I := 0 To 255 Do
   If Working[I] > Counted Then Begin
    Best := I;
    Counted := Working[I];
   End;
  If Best < 0 Then
   Break;
  D.DominantIndices[K] := Best;
  D.DominantCounts[K] := Counted;
  Inc(D.DominantCount);
  Working[Best] := 0;
 End;
 D.DominantIndex := 0;
 D.Dirty := True;
End;

Procedure PGChooseDominant(Var D: TPGState; Index: Integer);
Var
 ColorIndex: Integer;
 Percent: Real;
 S: String;
Begin
 If (Index < 0) Or (Index >= D.DominantCount) Then
  Exit;
 D.DominantIndex := Index;
 ColorIndex := D.DominantIndices[Index];
 PGSetColor(D,ImageBuffer.Palette[ColorIndex]);
 Percent := 0;
 If D.TotalPixels > 0 Then
  Percent := D.DominantCounts[Index]*100.0/D.TotalPixels;
 Str(Percent:0:1,S);
 D.Status := 'Couleur dominante '+PENumber(Index+1)+' : '+S+
             '% des pixels retenus, #'+PEHexColor(D.RGB)+'.';
End;

Procedure PGChooseHistory(Var D: TPGState; Index: Integer);
Begin
 If (Index < 0) Or (Index >= D.HistoryCount) Then
  Exit;
 D.HistoryIndex := Index;
 PGSetColor(D,D.History[Index]);
 D.Status := 'Capture precedente '+PENumber(Index+1)+' : #'+PEHexColor(D.RGB)+'.';
End;

Procedure PGChooseCustom(Var D: TPGState; Index: Integer);
Begin
 D.CustomIndex := PEClamp(Index,0,PE_CUSTOM_COUNT-1);
 PGSetColor(D,D.PaletteData.Customs[D.CustomIndex]);
 D.Status := 'Couleur personnalisee '+PENumber(D.CustomIndex+1)+' selectionnee.';
End;

Procedure PGAddCustom(Var D: TPGState);
Begin
 If Not D.ValidSample Then
  Exit;
 D.PaletteData.Customs[D.CustomIndex] := D.RGB;
 D.Status := 'Case personnalisee '+PENumber(D.CustomIndex+1)+
             ' preparee. OK conserve les modifications.';
 D.CustomIndex := (D.CustomIndex+1) Mod PE_CUSTOM_COUNT;
 D.Dirty := True;
End;

Function PGCommitCoordinates(Var D: TPGState): Boolean;
Var
 X, Y, Code: Integer;
Begin
 PGCommitCoordinates := False;
 If Not PGHasImage Then
  Exit;
 Val(D.CoordText[0],X,Code);
 If (Code <> 0) Or (X < 0) Or (X >= CanvasImageW) Then Begin
  D.CoordError := 0;
  D.Focus := 0;
  D.Status := 'X doit etre compris entre 0 et '+PENumber(CanvasImageW-1)+'.';
  D.Dirty := True;
  Exit;
 End;
 Val(D.CoordText[1],Y,Code);
 If (Code <> 0) Or (Y < 0) Or (Y >= CanvasImageH) Then Begin
  D.CoordError := 1;
  D.Focus := 1;
  D.Status := 'Y doit etre compris entre 0 et '+PENumber(CanvasImageH-1)+'.';
  D.Dirty := True;
  Exit;
 End;
 PGCommitCoordinates := PGSampleAt(D,X,Y);
End;

Procedure PGLayout(Var D: TPGState);
Begin
 D.X := (ScreenWidth-620) Div 2;
 D.Y := (ScreenHeight-430) Div 2;
 PERect(D.Thumbnail,D.X+12,D.Y+42,288,150);
 PERect(D.Loupe,D.X+314,D.Y+42,112,112);
 PERect(D.CoordRects[0],D.X+35,D.Y+199,60,20);
 PERect(D.CoordRects[1],D.X+134,D.Y+199,60,20);
 PERect(D.Buttons[0],D.X+12,D.Y+389,82,25);
 PERect(D.Buttons[1],D.X+104,D.Y+389,82,25);
 PERect(D.Buttons[2],D.X+196,D.Y+389,104,25);
 PERect(D.Buttons[3],D.X+208,D.Y+198,92,23);
 PERect(D.Buttons[4],D.X+12,D.Y+227,140,24);
 PERect(D.Buttons[5],D.X+158,D.Y+227,142,24);
 PERect(D.Buttons[6],D.X+12,D.Y+257,140,24);
 PERect(D.Buttons[7],D.X+158,D.Y+257,142,24);
 PERect(D.Buttons[8],D.X+314,D.Y+326,142,24);
 PERect(D.Buttons[9],D.X+462,D.Y+326,140,24);
 PERect(D.Buttons[10],D.X+314,D.Y+357,142,24);
 PERect(D.Buttons[11],D.X+462,D.Y+357,140,24);
 PERect(D.Buttons[12],D.X+314,D.Y+389,142,25);
 PERect(D.Buttons[13],D.X+462,D.Y+389,140,25);
 PERect(D.Buttons[14],D.X+314,D.Y+158,112,23);
End;

Procedure PGThumbnailBounds(Var D: TPGState);
Var
 Region: TRect;
 W, H, DrawW, DrawH: Integer;
Begin
 PGSourceBounds(D,Region);
 W := Region.Right-Region.Left+1;
 H := Region.Bottom-Region.Top+1;
 DrawW := 284;
 DrawH := 146;
 If (W <= 0) Or (H <= 0) Then Begin
  PERect(D.ThumbnailImage,D.Thumbnail.Left+2,D.Thumbnail.Top+2,1,1);
  Exit;
 End;
 If LongInt(W)*146 > LongInt(H)*284 Then
  DrawH := Max(1,(LongInt(H)*284) Div W)
 Else
  DrawW := Max(1,(LongInt(W)*146) Div H);
 PERect(D.ThumbnailImage,
        D.Thumbnail.Left+(288-DrawW) Div 2,
        D.Thumbnail.Top+(150-DrawH) Div 2,DrawW,DrawH);
End;

Procedure PGDrawThumbnail(Var D: TPGState);
Var
 Region: TRect;
 X, Y, SX, SY, W, H, PX, PY: Integer;
 C: TRGBColor;
Begin
 PEFill(D.Thumbnail,DarkGray);
 PEBevel(D.Thumbnail,True);
 If Not PGHasImage Then
  Exit;
 PGThumbnailBounds(D);
 PGSourceBounds(D,Region);
 W := D.ThumbnailImage.Right-D.ThumbnailImage.Left+1;
 H := D.ThumbnailImage.Bottom-D.ThumbnailImage.Top+1;
 For Y := 0 To H-1 Do Begin
  SY := Region.Top+(LongInt(Y)*(Region.Bottom-Region.Top+1)) Div H;
  For X := 0 To W-1 Do Begin
   SX := Region.Left+(LongInt(X)*(Region.Right-Region.Left+1)) Div W;
   If PGReadRGB(SX,SY,C) Then
    PutPixel(D.ThumbnailImage.Left+X,D.ThumbnailImage.Top+Y,PEDisplayColor(C));
  End;
 End;
 PX := D.ThumbnailImage.Left+
       (LongInt(D.ImageX-Region.Left)*W) Div (Region.Right-Region.Left+1);
 PY := D.ThumbnailImage.Top+
       (LongInt(D.ImageY-Region.Top)*H) Div (Region.Bottom-Region.Top+1);
 SetColor(White);
 Circle(PX,PY,4);
 SetColor(Black);
 Circle(PX,PY,3);
 Line(PX-6,PY,PX-2,PY);
 Line(PX+2,PY,PX+6,PY);
 Line(PX,PY-6,PX,PY-2);
 Line(PX,PY+2,PX,PY+6);
End;

Procedure PGDrawLoupe(Const D: TPGState);
Var
 Cells, Half, CellSize, Left, Top: Integer;
 X, Y, SX, SY: Integer;
 R: TRect;
 C: TRGBColor;
Begin
 PEFill(D.Loupe,DarkGray);
 PEBevel(D.Loupe,True);
 CellSize := D.Magnification;
 Cells := 108 Div CellSize;
 If (Cells And 1) = 0 Then
  Dec(Cells);
 Half := Cells Div 2;
 Left := D.Loupe.Left+(112-Cells*CellSize) Div 2;
 Top := D.Loupe.Top+(112-Cells*CellSize) Div 2;
 For Y := 0 To Cells-1 Do
  For X := 0 To Cells-1 Do Begin
   SX := D.ImageX+X-Half;
   SY := D.ImageY+Y-Half;
   PERect(R,Left+X*CellSize,Top+Y*CellSize,CellSize,CellSize);
   If PGReadRGB(SX,SY,C) Then
    PEFill(R,PEDisplayColor(C))
   Else Begin
    If ((X+Y) And 1) = 0 Then
     PEFill(R,LightGray)
    Else
     PEFill(R,DarkGray);
   End;
   If D.ShowGrid And (CellSize >= 8) Then Begin
    SetColor(DarkGray);
    Rectangle(R.Left,R.Top,R.Right,R.Bottom);
   End;
  End;
 { Le pixel central reste encadre, y compris dans une zone uniforme. }
 PERect(R,Left+Half*CellSize,Top+Half*CellSize,CellSize,CellSize);
 SetColor(White);
 Rectangle(R.Left-1,R.Top-1,R.Right+1,R.Bottom+1);
 SetColor(Black);
 Rectangle(R.Left,R.Top,R.Right,R.Bottom);
End;

Procedure PGDrawInfo(Const D: TPGState);
Var
 R: TRect;
 H, S, L, C1, C2: Integer;
 Text: String;
Begin
 PESetHardwareColor(PE_PREVIEW,D.RGB);
 PESetHardwareColor(PE_OLD_PREVIEW,D.Original);
 C1 := PEDisplayColor(D.Original);
 C2 := PEDisplayColor(D.RGB);
 If GetMaxColor >= 255 Then Begin
  C1 := PE_OLD_PREVIEW;
  C2 := PE_PREVIEW;
 End;
 PERect(R,D.X+438,D.Y+42,80,40);
 PEFill(R,C1);
 PEBevel(R,True);
 PERect(R,D.X+522,D.Y+42,80,40);
 PEFill(R,C2);
 PEBevel(R,True);
 PELabel(D.X+438,D.Y+87,'Avant     Capture');
 PELabel(D.X+438,D.Y+104,'R:'+PENumber(D.RGB.R)+' V:'+PENumber(D.RGB.G));
 PELabel(D.X+438,D.Y+118,'B:'+PENumber(D.RGB.B));
 PELabel(D.X+438,D.Y+135,'#'+PEHexColor(D.RGB));
 H := 0;
 PERGBToHSL(D.RGB,H,S,L);
 PELabel(D.X+438,D.Y+153,'T:'+PENumber(H)+' S:'+PENumber(S));
 PELabel(D.X+438,D.Y+167,'L:'+PENumber(L));
 Text := 'X:'+PENumber(D.ImageX)+' Y:'+PENumber(D.ImageY);
 PELabel(D.X+314,D.Y+30,Text);
End;

Procedure PGCellRect(Const D: TPGState; Group, Index: Integer; Var R: TRect);
Var
 X, Y, Columns, CW, CH: Integer;
Begin
 Columns := 8;
 CW := 36;
 CH := 23;
 X := D.X+314;
 Case Group Of
  0: Y := D.Y+207;
  1: Y := D.Y+278;
 Else
  Begin
   X := D.X+13;
   Y := D.Y+342;
   Columns := 16;
   CW := 18;
   CH := 18;
  End;
 End;
 PERect(R,X+(Index Mod Columns)*CW,Y+(Index Div Columns)*CH,CW-5,CH-5);
End;

Procedure PGDrawCells(Const D: TPGState);
Var
 I: Integer;
 R: TRect;
 C: TRGBColor;
Begin
 PELabel(D.X+314,D.Y+190,'Couleurs dominantes :');
 For I := 0 To PG_DOMINANT_COUNT-1 Do Begin
  PGCellRect(D,0,I,R);
  If I < D.DominantCount Then Begin
   C := ImageBuffer.Palette[D.DominantIndices[I]];
   PESwatch(R,C,(D.Focus = 20) And (I = D.DominantIndex));
  End
  Else Begin
   PEFill(R,LightGray);
   PEBevel(R,True);
  End;
 End;
 PELabel(D.X+314,D.Y+262,'Couleurs personnalisees :');
 For I := 0 To PE_CUSTOM_COUNT-1 Do Begin
  PGCellRect(D,1,I,R);
  PESwatch(R,D.PaletteData.Customs[I],I = D.CustomIndex);
 End;
 PELabel(D.X+12,D.Y+327,'Historique des captures :');
 For I := 0 To PG_HISTORY_COUNT-1 Do Begin
  PGCellRect(D,2,I,R);
  If I < D.HistoryCount Then
   PESwatch(R,D.History[I],(D.Focus = 22) And (I = D.HistoryIndex))
  Else Begin
   PEFill(R,LightGray);
   PEBevel(R,True);
  End;
 End;
End;

Function PGMethodName(Method: Integer): String;
Begin
 Case Method Of
  0: PGMethodName := 'Pixel';
  1: PGMethodName := 'Moyenne';
  2: PGMethodName := 'Mediane';
  3: PGMethodName := 'Dominante';
  4: PGMethodName := 'Plus claire';
 Else
  PGMethodName := 'Plus sombre';
 End;
End;

Function PGSourceName(Source: Integer): String;
Begin
 Case Source Of
  0: PGSourceName := 'Image';
  1: PGSourceName := 'Selection';
 Else
  PGSourceName := 'Zone visible';
 End;
End;

Procedure PGDrawButtons(Const D: TPGState);
Var
 I: Integer;
 Caption: String;
Begin
 For I := 0 To PG_BUTTON_COUNT-1 Do Begin
  Case I Of
   0: Caption := 'OK';
   1: Caption := 'Annuler';
   2: Caption := 'Aide (F1)';
   3: Caption := 'Pipette';
   4: Caption := PGSourceName(D.Source);
   5: Caption := PGMethodName(D.Method);
   6: Caption := 'Zone '+PENumber(D.Radius*2+1)+'x'+PENumber(D.Radius*2+1);
   7: Caption := 'Loupe x'+PENumber(D.Magnification);
   8: Caption := 'Personnaliser';
   9: Caption := 'Memoriser (F2)';
   10: Caption := 'Copier #RVB';
   11: Caption := 'Copier RVB';
   12: Begin
    If D.AddToBar Then
     Caption := '[x] Palette'
    Else
     Caption := '[ ] Palette';
   End;
   13: Caption := 'Rechercher #';
   14: Begin
    If D.ShowGrid Then
     Caption := '[x] Grille'
    Else
     Caption := '[ ] Grille';
   End;
  End;
  PEButton(D.Buttons[I],Caption,D.Focus = I+2);
 End;
End;

Procedure PGDrawCoordinates(Const D: TPGState);
Var
 I: Integer;
 R: TRect;
Begin
 PELabel(D.X+12,D.Y+205,'X :');
 PELabel(D.X+111,D.Y+205,'Y :');
 For I := 0 To 1 Do Begin
  R := D.CoordRects[I];
  PEFill(R,White);
  PEBevel(R,True);
  If (D.Focus = I) And D.CoordSelected Then Begin
   SetFillStyle(SolidFill,Blue);
   Bar(R.Left+3,R.Top+3,R.Right-3,R.Bottom-3);
   SetColor(White);
  End
  Else
   SetColor(Black);
  OutTextXY(R.Left+4,R.Top+6,D.CoordText[I]);
  If D.CoordError = I Then Begin
   SetColor(Red);
   Rectangle(R.Left-1,R.Top-1,R.Right+1,R.Bottom+1);
  End;
 End;
End;

Procedure PGDrawOptions(Const D: TPGState);
Var
 Mark: String;
Begin
 If D.IgnoreBackground Then
  Mark := '[x]'
 Else
  Mark := '[ ]';
 PELabel(D.X+13,D.Y+291,Mark+' Ignorer la couleur de fond');
 If D.Focus = 18 Then Begin
  SetColor(Black);
  Rectangle(D.X+11,D.Y+287,D.X+299,D.Y+303);
 End;
 If D.TargetBackground Then
  Mark := '( ) Premier plan (*) Fond'
 Else
  Mark := '(*) Premier plan ( ) Fond';
 PELabel(D.X+13,D.Y+309,Mark);
 If D.Focus = 19 Then Begin
  SetColor(Black);
  Rectangle(D.X+11,D.Y+305,D.X+299,D.Y+321);
 End;
End;

Procedure PGDraw(Var D: TPGState);
Var
 R: TRect;
Begin
 PEHideMouse;
 SetWriteMode(CopyPut);
 SetLineStyle(SolidLn,0,NormWidth);
 PERect(R,D.X,D.Y,620,430);
 PEFill(R,LightGray);
 PEBevel(R,False);
 SetFillStyle(SolidFill,Blue);
 Bar(D.X+3,D.Y+3,D.X+616,D.Y+21);
 SetColor(White);
 OutTextXY(D.X+9,D.Y+7,'Obtenir des couleurs - PAINT');
 OutTextXY(D.X+602,D.Y+7,'X');
 PGDrawThumbnail(D);
 PGDrawLoupe(D);
 PGDrawInfo(D);
 PGDrawCoordinates(D);
 PGDrawButtons(D);
 PGDrawOptions(D);
 PGDrawCells(D);
 SetFillStyle(SolidFill,LightGray);
 Bar(0,ScreenHeight-STATUSBAR_HEIGHT,ScreenWidth-1,ScreenHeight-1);
 PELabel(5,ScreenHeight-STATUSBAR_HEIGHT+5,D.Status);
 PEShowMouse;
 D.Dirty := False;
End;

Procedure PGHelp(Var D: TPGState);
Begin
 ShowMessage('Aide - Obtenir des couleurs',
  'Cliquez la miniature ou utilisez la Pipette (F4).'+#10+
  'Fleches : viser ; Entree : valider ; Echap : annuler.'+#10+
  'Tab : controle suivant ; F2 : memoriser la capture.'+#10+
  'M : methode ; Z : loupe ; G : grille.'+#10+
  'OK applique ; Annuler ne change pas la palette.');
 D.Dirty := True;
End;

Procedure PGAdvanceSource(Var D: TPGState);
Begin
 D.Source := (D.Source+1) Mod 3;
 If (D.Source = 1) And Not SelectionActive Then
  D.Source := 2;
 PGHistogram(D);
 If PGSampleAt(D,D.ImageX,D.ImageY) Then
  D.Status := 'Source : '+PGSourceName(D.Source)+'. Couleurs dominantes recalculees.';
End;

Procedure PGAdvanceMethod(Var D: TPGState);
Begin
 D.Method := (D.Method+1) Mod PG_MODE_COUNT;
 If PGSampleAt(D,D.ImageX,D.ImageY) Then
  D.Status := 'Echantillonnage : '+PGMethodName(D.Method)+'.';
End;

Procedure PGAdvanceRadius(Var D: TPGState);
Begin
 Case D.Radius Of
  0: D.Radius := 1;
  1: D.Radius := 2;
  2: D.Radius := 4;
  4: D.Radius := 8;
 Else
  D.Radius := 0;
 End;
 If PGSampleAt(D,D.ImageX,D.ImageY) Then
  D.Status := 'Zone : '+PENumber(D.Radius*2+1)+'x'+PENumber(D.Radius*2+1)+'.';
End;

Procedure PGAdvanceZoom(Var D: TPGState);
Begin
 Case D.Magnification Of
  4: D.Magnification := 8;
  8: D.Magnification := 12;
  12: D.Magnification := 16;
 Else
  D.Magnification := 4;
 End;
 D.Status := 'Loupe : un pixel de l image occupe '+
             PENumber(D.Magnification)+' pixels a l ecran.';
 D.Dirty := True;
End;

Function PGFindColor(Var D: TPGState; Const Wanted: TRGBColor): Boolean;
Var
 Region: TRect;
 I, Best, X, Y: Integer;
 Distance, BestDistance: LongInt;
 P: PByte;
Begin
 PGFindColor := False;
 Best := -1;
 BestDistance := MaxLongInt;
 For I := 0 To 255 Do
  If D.Histogram[I] > 0 Then Begin
   Distance := PGDistance(Wanted,ImageBuffer.Palette[I]);
   If Distance < BestDistance Then Begin
    Best := I;
    BestDistance := Distance;
   End;
  End;
 If Best < 0 Then Begin
  D.Status := 'La source ne contient aucun pixel retenu.';
  D.Dirty := True;
  Exit;
 End;
 PGSourceBounds(D,Region);
 For Y := Region.Top To Region.Bottom Do Begin
  P := CanvasImage;
  Inc(P,LongInt(Y)*CanvasImageW+Region.Left);
  For X := Region.Left To Region.Right Do Begin
   If P^ = Best Then Begin
    D.ImageX := X;
    D.ImageY := Y;
    PGSyncCoordinates(D);
    PGSetColor(D,ImageBuffer.Palette[Best]);
    If BestDistance = 0 Then
     D.Status := 'Couleur exacte trouvee a '+PENumber(X)+','+PENumber(Y)+'.'
    Else
     D.Status := 'Couleur la plus proche trouvee : #'+PEHexColor(D.RGB)+'.';
    PGFindColor := True;
    Exit;
   End;
   Inc(P);
  End;
 End;
End;

Procedure PGSearch(Var D: TPGState);
Var
 S: String;
 C: TRGBColor;
Begin
 S := PEHexColor(D.RGB);
 If PromptString('Rechercher une couleur','Hexadecimal RRVVBB :',S) Then Begin
  If PEParseHex(S,C) Then Begin
   If Not PGFindColor(D,C) Then
    D.Status := 'Aucune couleur disponible dans la source choisie.';
  End
  Else
   D.Status := 'Couleur invalide : six chiffres hexadecimaux sont attendus.';
 End;
 D.Dirty := True;
End;

Function PGCopyText(Const Value: String): Boolean;
{$IFDEF WINDOWS}
Var
 Memory: TPaintWinHandle;
 Buffer: PChar;
 I: Integer;
Begin
 PGCopyText := False;
 If Not PaintWinOpenClipboard(0) Then
  Exit;
 Memory := PaintWinGlobalAlloc(PAINT_GMEM_MOVEABLE,Length(Value)+1);
 If Memory = 0 Then Begin
  PaintWinCloseClipboard;
  Exit;
 End;
 Buffer := PChar(PaintWinGlobalLock(Memory));
 If Buffer = Nil Then Begin
  PaintWinGlobalFree(Memory);
  PaintWinCloseClipboard;
  Exit;
 End;
 For I := 1 To Length(Value) Do
  Buffer[I-1] := Value[I];
 Buffer[Length(Value)] := #0;
 PaintWinGlobalUnlock(Memory);
 If PaintWinEmptyClipboard Then
  If PaintWinSetClipboardData(PAINT_CF_TEXT,Memory) <> 0 Then Begin
   PGCopyText := True;
   Memory := 0;
  End;
 If Memory <> 0 Then
  PaintWinGlobalFree(Memory);
 PaintWinCloseClipboard;
End;
{$ELSE}
Begin
 PGCopyText := False;
End;
{$ENDIF}

Procedure PGCopyColor(Var D: TPGState; Hexadecimal: Boolean);
Var
 S: String;
Begin
 If Not D.ValidSample Then
  Exit;
 If Hexadecimal Then
  S := '#'+PEHexColor(D.RGB)
 Else
  S := PENumber(D.RGB.R)+', '+PENumber(D.RGB.G)+', '+PENumber(D.RGB.B);
 If PGCopyText(S) Then
  D.Status := 'Copie dans le presse-papiers : '+S
 Else
  D.Status := 'Presse-papiers indisponible. Valeur : '+S;
 D.Dirty := True;
End;

Procedure PGCaptureCanvas(Var D: TPGState);
Var
 X, Y, Buttons, PreviousButtons, LastX, LastY: Integer;
 OldX, OldY: Integer;
 K: Char;
 Finished, Captured, Inside: Boolean;
 OldRGB: TRGBColor;
 OldValid: Boolean;
 R: TRect;
Begin
 OldX := D.ImageX;
 OldY := D.ImageY;
 OldRGB := D.RGB;
 OldValid := D.ValidSample;
 PEHideMouse;
 PERestoreHardware(D.PaletteData);
 PEShowMouse;
 RedrawInterface;
 Finished := False;
 Captured := False;
 LastX := -1;
 LastY := -1;
 GetMouseStateLocal(X,Y,PreviousButtons);
 Repeat
  GetMouseStateLocal(X,Y,Buttons);
  Inside := ZHitCanvas(X,Y);
  If Inside And ((X <> LastX) Or (Y <> LastY)) Then Begin
   If PGSampleAt(D,ZScreenX(X),ZScreenY(Y)) Then Begin
    PEHideMouse;
    SetFillStyle(SolidFill,LightGray);
    Bar(0,ScreenHeight-STATUSBAR_HEIGHT,ScreenWidth-1,ScreenHeight-1);
    PELabel(5,ScreenHeight-STATUSBAR_HEIGHT+5,
     'Pipette '+PENumber(D.ImageX)+','+PENumber(D.ImageY)+
     ' #'+PEHexColor(D.RGB)+' | clic : capturer ; Echap : retour');
    PEShowMouse;
   End;
  End;
  If Inside And ((Buttons And 1) <> 0) And
     ((PreviousButtons And 1) = 0) Then Begin
   Captured := D.ValidSample;
   Finished := True;
  End;
  If (Buttons And 2) <> 0 Then
   Finished := True;
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then Begin
    K := ReadKey;
    Case Ord(K) Of
     75: If PGSampleAt(D,D.ImageX-1,D.ImageY) Then D.Dirty := True;
     77: If PGSampleAt(D,D.ImageX+1,D.ImageY) Then D.Dirty := True;
     72: If PGSampleAt(D,D.ImageX,D.ImageY-1) Then D.Dirty := True;
     80: If PGSampleAt(D,D.ImageX,D.ImageY+1) Then D.Dirty := True;
    End;
   End
   Else If K = #27 Then
    Finished := True
   Else If K = #13 Then Begin
    Captured := D.ValidSample;
    Finished := True;
   End;
  End;
  LastX := X;
  LastY := Y;
  PreviousButtons := Buttons;
  Delay(10);
 Until Finished;
 Repeat
  GetMouseStateLocal(X,Y,Buttons);
  If (Buttons And 3) <> 0 Then
   Delay(10);
 Until (Buttons And 3) = 0;
 If Captured Then
  PGAddHistory(D)
 Else Begin
  D.ImageX := OldX;
  D.ImageY := OldY;
  D.RGB := OldRGB;
  D.ValidSample := OldValid;
  PGSyncCoordinates(D);
  D.Status := 'Prelevement annule. La couleur precedente est conservee.';
 End;
 PEHideMouse;
 PEBuildDisplayPalette;
 PEShowMouse;
 D.PreviousButtons := 0;
 D.DragThumbnail := False;
 D.Dirty := True;
End;

Procedure PGActivate(Var D: TPGState; Button: Integer);
Begin
 If Button = 1 Then Begin
  D.Accepted := False;
  D.Done := True;
  Exit;
 End;
 If (D.Focus <= 1) And (Button <> 2) Then
  If Not PGCommitCoordinates(D) Then
   Exit;
 Case Button Of
  0: Begin
   If D.ValidSample Then Begin
    PGAddHistory(D);
    D.Accepted := True;
    D.Done := True;
   End
   Else Begin
    D.Status := 'Choisissez une couleur avant de valider.';
    D.Dirty := True;
   End;
  End;
  2: PGHelp(D);
  3: PGCaptureCanvas(D);
  4: PGAdvanceSource(D);
  5: PGAdvanceMethod(D);
  6: PGAdvanceRadius(D);
  7: PGAdvanceZoom(D);
  8: PGAddCustom(D);
  9: PGAddHistory(D);
  10: PGCopyColor(D,True);
  11: PGCopyColor(D,False);
  12: Begin
   D.AddToBar := Not D.AddToBar;
   D.Dirty := True;
  End;
  13: PGSearch(D);
  14: Begin
   D.ShowGrid := Not D.ShowGrid;
   D.Dirty := True;
  End;
 End;
End;

Procedure PGSetFocus(Var D: TPGState; Focus: Integer);
Begin
 If D.Focus <= 1 Then
  If Not PGCommitCoordinates(D) Then
   Exit;
 D.Focus := Focus;
 D.CoordSelected := Focus <= 1;
 D.Dirty := True;
End;

Procedure PGNextFocus(Var D: TPGState; Backwards: Boolean);
Var
 Next: Integer;
Begin
 Next := D.Focus;
 If Backwards Then
  Dec(Next)
 Else
  Inc(Next);
 If Next > PG_FOCUS_LAST Then
  Next := 0;
 If Next < 0 Then
  Next := PG_FOCUS_LAST;
 { Le focus 17 correspond a la miniature. }
 PGSetFocus(D,Next);
End;

Procedure PGCoordinateKey(Var D: TPGState; K: Char);
Var
 S: String;
Begin
 If (D.Focus < 0) Or (D.Focus > 1) Then
  Exit;
 S := D.CoordText[D.Focus];
 If K = #1 Then Begin
  D.CoordSelected := True;
  D.Dirty := True;
  Exit;
 End;
 If K = #8 Then Begin
  If D.CoordSelected Then
   S := ''
  Else If Length(S) > 0 Then
   Delete(S,Length(S),1);
 End
 Else If (K >= '0') And (K <= '9') Then Begin
  If D.CoordSelected Then
   S := '';
  If Length(S) < 5 Then
   S := S+K;
 End
 Else
  Exit;
 D.CoordText[D.Focus] := S;
 D.CoordSelected := False;
 D.CoordError := -1;
 D.Status := 'Coordonnees en pixels. Entree ou Tab pour echantillonner.';
 D.Dirty := True;
End;

Procedure PGArrow(Var D: TPGState; DX, DY: Integer);
Var
 Index: Integer;
Begin
 Case D.Focus Of
  20: Begin
   Index := PEClamp(D.DominantIndex+DX+DY*8,0,Max(0,D.DominantCount-1));
   PGChooseDominant(D,Index);
  End;
  21: Begin
   Index := PEClamp(D.CustomIndex+DX+DY*8,0,PE_CUSTOM_COUNT-1);
   PGChooseCustom(D,Index);
  End;
  22: Begin
   Index := PEClamp(D.HistoryIndex+DX+DY*16,0,Max(0,D.HistoryCount-1));
   PGChooseHistory(D,Index);
  End;
 Else
  If PGSampleAt(D,D.ImageX+DX,D.ImageY+DY) Then
   D.Dirty := True;
 End;
End;

Procedure PGKeyboard(Var D: TPGState);
Var
 K: Char;
Begin
 K := ReadKey;
 If K = #0 Then Begin
  K := ReadKey;
  Case Ord(K) Of
   15: PGNextFocus(D,True);
   59: PGHelp(D);
   60: PGAddHistory(D);
   61: PGAddCustom(D);
   62: PGCaptureCanvas(D);
   72: PGArrow(D,0,-1);
   80: PGArrow(D,0,1);
   75: PGArrow(D,-1,0);
   77: PGArrow(D,1,0);
   73: PGArrow(D,0,-10);
   81: PGArrow(D,0,10);
   83: If D.Focus <= 1 Then Begin
    D.CoordText[D.Focus] := '';
    D.CoordSelected := False;
    D.Dirty := True;
   End;
  End;
  Exit;
 End;
 Case K Of
  #27: PGActivate(D,1);
  #9: PGNextFocus(D,False);
  #13: Begin
   If D.Focus <= 1 Then Begin
    If PGCommitCoordinates(D) Then
     PGSetFocus(D,2);
   End
   Else If D.Focus <= 16 Then
    PGActivate(D,D.Focus-2)
   Else
    PGActivate(D,0);
  End;
  ' ': Begin
   If (D.Focus >= 2) And (D.Focus <= 16) Then
    PGActivate(D,D.Focus-2)
   Else If D.Focus = 18 Then Begin
    D.IgnoreBackground := Not D.IgnoreBackground;
    PGHistogram(D);
    If PGSampleAt(D,D.ImageX,D.ImageY) Then D.Dirty := True;
   End
   Else If D.Focus = 19 Then Begin
    D.TargetBackground := Not D.TargetBackground;
    D.Dirty := True;
   End;
  End;
 Else
  If D.Focus <= 1 Then
   PGCoordinateKey(D,K)
  Else Case UpCase(K) Of
   'M': PGAdvanceMethod(D);
   'Z': PGAdvanceZoom(D);
   'G': Begin D.ShowGrid := Not D.ShowGrid; D.Dirty := True; End;
   'S': PGAdvanceSource(D);
   'R': PGAdvanceRadius(D);
  End;
 End;
End;

Procedure PGThumbnailMouse(Var D: TPGState; X, Y: Integer);
Var
 Region: TRect;
 W, H, SX, SY: Integer;
Begin
 If Not PGHasImage Then
  Exit;
 PGSourceBounds(D,Region);
 W := D.ThumbnailImage.Right-D.ThumbnailImage.Left+1;
 H := D.ThumbnailImage.Bottom-D.ThumbnailImage.Top+1;
 X := PEClamp(X-D.ThumbnailImage.Left,0,W-1);
 Y := PEClamp(Y-D.ThumbnailImage.Top,0,H-1);
 SX := Region.Left+(LongInt(X)*(Region.Right-Region.Left+1)) Div W;
 SY := Region.Top+(LongInt(Y)*(Region.Bottom-Region.Top+1)) Div H;
 If PGSampleAt(D,SX,SY) Then
  D.Dirty := True;
End;

Procedure PGLoupeMouse(Var D: TPGState; X, Y: Integer);
Var
 Cells, Left, Top, SX, SY: Integer;
Begin
 Cells := 108 Div D.Magnification;
 If (Cells And 1) = 0 Then
  Dec(Cells);
 Left := D.Loupe.Left+(112-Cells*D.Magnification) Div 2;
 Top := D.Loupe.Top+(112-Cells*D.Magnification) Div 2;
 If (X < Left) Or (Y < Top) Or
    (X >= Left+Cells*D.Magnification) Or
    (Y >= Top+Cells*D.Magnification) Then
  Exit;
 SX := D.ImageX+(X-Left) Div D.Magnification-Cells Div 2;
 SY := D.ImageY+(Y-Top) Div D.Magnification-Cells Div 2;
 If PGSampleAt(D,SX,SY) Then
  D.Dirty := True;
End;

Procedure PGMouseDown(Var D: TPGState);
Var
 I, Group, Count: Integer;
 R: TRect;
Begin
 If (D.MX >= D.X+596) And (D.MX <= D.X+617) And
    (D.MY >= D.Y+3) And (D.MY <= D.Y+21) Then Begin
  PGActivate(D,1);
  Exit;
 End;
 If PEInside(D.MX,D.MY,D.Buttons[1]) Then Begin
  PGActivate(D,1);
  Exit;
 End;
 For I := 0 To PG_BUTTON_COUNT-1 Do
  If PEInside(D.MX,D.MY,D.Buttons[I]) Then Begin
   If D.Focus <= 1 Then
    If Not PGCommitCoordinates(D) Then
     Exit;
   D.Focus := I+2;
   PGActivate(D,I);
   Exit;
  End;
 For I := 0 To 1 Do
  If PEInside(D.MX,D.MY,D.CoordRects[I]) Then Begin
   PGSetFocus(D,I);
   Exit;
  End;
 If D.Focus <= 1 Then
  If Not PGCommitCoordinates(D) Then
   Exit;
 If PEInside(D.MX,D.MY,D.ThumbnailImage) Then Begin
  D.Focus := 17;
  D.DragThumbnail := True;
  PGThumbnailMouse(D,D.MX,D.MY);
  Exit;
 End;
 If PEInside(D.MX,D.MY,D.Loupe) Then Begin
  D.Focus := 17;
  PGLoupeMouse(D,D.MX,D.MY);
  Exit;
 End;
 PERect(R,D.X+12,D.Y+286,288,18);
 If PEInside(D.MX,D.MY,R) Then Begin
  D.Focus := 18;
  D.IgnoreBackground := Not D.IgnoreBackground;
  PGHistogram(D);
  If PGSampleAt(D,D.ImageX,D.ImageY) Then D.Dirty := True;
  Exit;
 End;
 PERect(R,D.X+12,D.Y+305,288,18);
 If PEInside(D.MX,D.MY,R) Then Begin
  D.Focus := 19;
  D.TargetBackground := D.MX >= D.X+158;
  D.Dirty := True;
  Exit;
 End;
 For Group := 0 To 2 Do Begin
  Case Group Of
   0: Count := D.DominantCount;
   1: Count := PE_CUSTOM_COUNT;
  Else
   Count := D.HistoryCount;
  End;
  For I := 0 To Count-1 Do Begin
   PGCellRect(D,Group,I,R);
   If PEInside(D.MX,D.MY,R) Then Begin
    D.Focus := 20+Group;
    Case Group Of
     0: PGChooseDominant(D,I);
     1: PGChooseCustom(D,I);
     2: PGChooseHistory(D,I);
    End;
    Exit;
   End;
  End;
 End;
End;

Procedure PGMouse(Var D: TPGState);
Begin
 GetMouseStateLocal(D.MX,D.MY,D.MB);
 If ((D.MB And 1) <> 0) And ((D.PreviousButtons And 1) = 0) Then
  PGMouseDown(D)
 Else If ((D.MB And 1) <> 0) And D.DragThumbnail Then Begin
  If (D.MX <> D.LastMouseX) Or (D.MY <> D.LastMouseY) Then
   PGThumbnailMouse(D,D.MX,D.MY);
 End;
 If ((D.MB And 1) = 0) And D.DragThumbnail Then Begin
  D.DragThumbnail := False;
  PGAddHistory(D);
 End;
 D.LastMouseX := D.MX;
 D.LastMouseY := D.MY;
 D.PreviousButtons := D.MB;
End;

Procedure PGInitialize(Var D: TPGState);
Begin
 FillChar(D,SizeOf(D),0);
 PEInitialize(D.PaletteData);
 D.RGB := ImageBuffer.Palette[CurrentColor];
 D.Original := D.RGB;
 D.ValidSample := True;
 D.Radius := 1;
 D.Magnification := 8;
 D.ShowGrid := True;
 D.AddToBar := True;
 D.CoordError := -1;
 D.Focus := 17;
 D.History := PaintCapturedColors;
 D.HistoryCount := PEClamp(PaintCapturedCount,0,PG_HISTORY_COUNT);
 If PGHasImage Then Begin
  D.ImageX := CanvasImageW Div 2;
  D.ImageY := CanvasImageH Div 2;
 End;
 PGSyncCoordinates(D);
 PGLayout(D);
 PGHistogram(D);
 D.Status := 'Miniature : cliquez ou glissez. Pipette (F4) : prelever sur le dessin.';
 GetMouseStateLocal(D.MX,D.MY,D.PreviousButtons);
 D.LastMouseX := D.MX;
 D.LastMouseY := D.MY;
 D.Dirty := True;
End;

Function PGFindPaletteIndex(Const C: TRGBColor; Var Exact: Boolean): Integer;
Var
 I, Best: Integer;
 Distance, BestDistance: LongInt;
Begin
 Best := 0;
 BestDistance := MaxLongInt;
 For I := 0 To Min(GetMaxColor,255) Do Begin
  Distance := PGDistance(C,ImageBuffer.Palette[I]);
  If Distance < BestDistance Then Begin
   BestDistance := Distance;
   Best := I;
  End;
 End;
 Exact := BestDistance = 0;
 PGFindPaletteIndex := Best;
End;

Function PGFreePaletteIndex: Integer;
Var
 Used: Array[0..255] of Boolean;
 I: Integer;
 Count: LongInt;
 P: PByte;
Begin
 FillChar(Used,SizeOf(Used),0);
 For I := 0 To 15 Do
  Used[I] := True;
 For I := 0 To 27 Do
  Used[StandardPalette[I]] := True;
 Used[CurrentColor] := True;
 Used[BackgroundColor] := True;
 If PGHasImage Then Begin
  Count := LongInt(CanvasImageW)*CanvasImageH;
  P := CanvasImage;
  While Count > 0 Do Begin
   Used[P^] := True;
   Inc(P);
   Dec(Count);
  End;
 End;
 PGFreePaletteIndex := -1;
 For I := Min(GetMaxColor,255) DownTo 16 Do
  If Not Used[I] Then Begin
   PGFreePaletteIndex := I;
   Exit;
  End;
End;

Procedure PGCommit(Var D: TPGState);
Var
 Index, FreeIndex, Slot: Integer;
 Exact: Boolean;
Begin
 If Not D.ValidSample Then
  Exit;
 Index := PGFindPaletteIndex(D.RGB,Exact);
 FreeIndex := -1;
 If Not Exact Then
  FreeIndex := PGFreePaletteIndex;
 { Snapshot complet : les indices, les cases et la profondeur sont annulates. }
 AddSnapshotToHistory(TOOL_PICKER);
 If FreeIndex >= 16 Then Begin
  Index := FreeIndex;
  ImageBuffer.Palette[Index] := D.RGB;
  PESetHardwareColor(Index,D.RGB);
  If ImageBuffer.BitDepth < 8 Then
   ImageBuffer.BitDepth := 8;
  ImageBuffer.Modified := True;
 End;
 If D.TargetBackground Then
  BackgroundColor := Index
 Else
  CurrentColor := Index;
 If D.AddToBar Then Begin
  Slot := PEClamp(ActivePaletteSlot,0,27);
  StandardPalette[Slot] := Index;
 End;
 PaintCustomColors := D.PaletteData.Customs;
 PaintCustomReady := True;
 PaintCapturedColors := D.History;
 PaintCapturedCount := D.HistoryCount;
End;

Procedure ObtainPaintColors;
Var
 D: TPGState;
 Approximation: Boolean;
 Index: Integer;
Begin
 MenuActive := False;
 RedrawInterface;
 PGInitialize(D);
 PEHideMouse;
 PEBuildDisplayPalette;
 PEShowMouse;
 While Not D.Done Do Begin
  If D.Dirty Then
   PGDraw(D);
  If KeyPressed Then
   PGKeyboard(D);
  If Not D.Done Then
   PGMouse(D);
  Delay(10);
 End;
 PEHideMouse;
 PERestoreHardware(D.PaletteData);
 If D.Accepted Then Begin
  Index := PGFindPaletteIndex(D.RGB,Approximation);
  { Une palette saturee ne doit pas recolorer les pixels deja presents. }
  If (Not Approximation) And (PGFreePaletteIndex < 0) Then Begin
   PEShowMouse;
   If PromptYesNoCancel('Palette pleine',
      'Utiliser la couleur disponible la plus proche ?') = 1 Then Begin
    PEHideMouse;
    PGCommit(D);
    PEShowMouse;
   End;
   PEHideMouse;
  End
  Else
   PGCommit(D);
 End;
 PEShowMouse;
 Repeat
  GetMouseStateLocal(D.MX,D.MY,D.MB);
  If (D.MB And 3) <> 0 Then
   Delay(10);
 Until (D.MB And 3) = 0;
 OldMouseButtons := 0;
 MouseButtons := 0;
 RedrawInterface;
End;


{ Retourner/Pivoter : une meme transformation de coordonnees est utilisee
  pour les icones, l'apercu et les pixels definitifs. Aucune interpolation
  ni conversion de palette : les rotations par quarts de tour sont exactes. }

Const
 RF_ORIGINAL = 0;
 RF_HORIZONTAL = 1;
 RF_VERTICAL = 2;
 RF_LEFT = 3;
 RF_RIGHT = 4;
 RF_HALF = 5;
 RF_MODE_COUNT = 6;
 RF_FOCUS_SCOPE = 6;
 RF_FOCUS_APPLY = 7;
 RF_FOCUS_CANCEL = 8;
 RF_FOCUS_RESET = 9;
 RF_FOCUS_HELP = 10;

Type
 TRFState = Record
  X, Y: Integer;
  Mode, Focus: Integer;
  UseSelection, HasSelection: Boolean;
  Done, Accepted, Dirty: Boolean;
  Source: TRect;
  Destination: TRect;
  SourceW, SourceH, ResultW, ResultH: Integer;
  ValidResult: Boolean;
  Tiles: Array[0..RF_MODE_COUNT-1] of TRect;
  BeforeBox, AfterBox: TRect;
  ApplyButton, CancelButton, ResetButton, HelpButton: TRect;
  ScopeBox: TRect;
  PaletteData: TPEState;
  Status: String[77];
  MX, MY, MB, PreviousButtons: Integer;
 End;

Procedure RFDimensions(Mode, W, H: Integer; Var NW, NH: Integer);
Begin
 NW := W;
 NH := H;
 If (Mode = RF_LEFT) Or (Mode = RF_RIGHT) Then Begin
  NW := H;
  NH := W;
 End;
End;

Procedure RFMapPixel(Mode, W, H, X, Y: Integer; Var SX, SY: Integer);
Begin
 SX := X;
 SY := Y;
 Case Mode Of
  RF_HORIZONTAL: SX := W-1-X;
  RF_VERTICAL: SY := H-1-Y;
  RF_LEFT: Begin
   SX := W-1-Y;
   SY := X;
  End;
  RF_RIGHT: Begin
   SX := Y;
   SY := H-1-X;
  End;
  RF_HALF: Begin
   SX := W-1-X;
   SY := H-1-Y;
  End;
 End;
End;

Procedure RFSourceBounds(Var D: TRFState);
Var
 T: Integer;
Begin
 PERect(D.Source,0,0,CanvasImageW,CanvasImageH);
 If D.UseSelection And D.HasSelection Then Begin
  D.Source.Left := SelectionRect.Left-CanvasX;
  D.Source.Top := SelectionRect.Top-CanvasY;
  D.Source.Right := SelectionRect.Right-CanvasX;
  D.Source.Bottom := SelectionRect.Bottom-CanvasY;
  If D.Source.Left > D.Source.Right Then Begin
   T := D.Source.Left;
   D.Source.Left := D.Source.Right;
   D.Source.Right := T;
  End;
  If D.Source.Top > D.Source.Bottom Then Begin
   T := D.Source.Top;
   D.Source.Top := D.Source.Bottom;
   D.Source.Bottom := T;
  End;
  D.Source.Left := Max(0,D.Source.Left);
  D.Source.Top := Max(0,D.Source.Top);
  D.Source.Right := Min(CanvasImageW-1,D.Source.Right);
  D.Source.Bottom := Min(CanvasImageH-1,D.Source.Bottom);
 End;
 D.SourceW := D.Source.Right-D.Source.Left+1;
 D.SourceH := D.Source.Bottom-D.Source.Top+1;
End;

Procedure RFUpdateResult(Var D: TRFState);
Var
 Left, Top: Integer;
Begin
 RFSourceBounds(D);
 RFDimensions(D.Mode,D.SourceW,D.SourceH,D.ResultW,D.ResultH);
 D.ValidResult := PGHasImage And (D.SourceW > 0) And (D.SourceH > 0) And
                  (D.ResultW <= MAX_IMAGE_WIDTH) And
                  (D.ResultH <= MAX_IMAGE_HEIGHT);
 If D.UseSelection Then Begin
  { Conserver le centre de la selection, puis ajuster sa position pour
    qu'elle reste dans l'image. Ne jamais tronquer silencieusement. }
  If (D.ResultW > CanvasImageW) Or (D.ResultH > CanvasImageH) Then
   D.ValidResult := False;
  Left := D.Source.Left+(D.SourceW-D.ResultW) Div 2;
  Top := D.Source.Top+(D.SourceH-D.ResultH) Div 2;
  If D.ValidResult Then Begin
   Left := PEClamp(Left,0,CanvasImageW-D.ResultW);
   Top := PEClamp(Top,0,CanvasImageH-D.ResultH);
  End;
 End
 Else Begin
  Left := 0;
  Top := 0;
 End;
 PERect(D.Destination,Left,Top,D.ResultW,D.ResultH);
 If Not D.ValidResult Then
  D.Status := 'Selection pivotee trop grande. Choisissez Image entiere.'
 Else If D.Mode = RF_ORIGINAL Then
  D.Status := 'Choisissez une transformation illustree. Rien n est encore modifie.'
 Else If D.UseSelection Then
  D.Status := 'Selection centree ; ancien emplacement rempli avec la couleur de fond.'
 Else
  D.Status := 'Image entiere : aucun pixel perdu. Entree applique ; Echap annule.';
 D.Dirty := True;
End;

Procedure RFLayout(Var D: TRFState);
Var
 I: Integer;
Begin
 D.X := (ScreenWidth-620) Div 2;
 D.Y := (ScreenHeight-430) Div 2;
 For I := 0 To RF_MODE_COUNT-1 Do
  PERect(D.Tiles[I],D.X+12+(I Mod 2)*120,D.Y+55+(I Div 2)*80,112,74);
 PERect(D.BeforeBox,D.X+264,D.Y+65,164,164);
 PERect(D.AfterBox,D.X+442,D.Y+65,164,164);
 PERect(D.ScopeBox,D.X+12,D.Y+307,232,52);
 PERect(D.ApplyButton,D.X+12,D.Y+389,120,25);
 PERect(D.CancelButton,D.X+144,D.Y+389,108,25);
 PERect(D.ResetButton,D.X+264,D.Y+389,150,25);
 PERect(D.HelpButton,D.X+442,D.Y+389,164,25);
End;

Function RFModeTitle(Mode: Integer): String;
Begin
 Case Mode Of
  RF_ORIGINAL: RFModeTitle := 'Original';
  RF_HORIZONTAL: RFModeTitle := 'Horizontal';
  RF_VERTICAL: RFModeTitle := 'Vertical';
  RF_LEFT: RFModeTitle := '90 deg gauche';
  RF_RIGHT: RFModeTitle := '90 deg droite';
  RF_HALF: RFModeTitle := '180 deg';
 Else
  RFModeTitle := '';
 End;
End;

Function RFModeSubtitle(Mode: Integer): String;
Begin
 Case Mode Of
  RF_ORIGINAL: RFModeSubtitle := 'Sans effet';
  RF_HORIZONTAL: RFModeSubtitle := 'Gauche/droite';
  RF_VERTICAL: RFModeSubtitle := 'Haut/bas';
  RF_LEFT: RFModeSubtitle := 'Quart de tour';
  RF_RIGHT: RFModeSubtitle := 'Quart de tour';
  RF_HALF: RFModeSubtitle := 'Demi-tour';
 Else
  RFModeSubtitle := '';
 End;
End;

Procedure RFExplanation(Mode: Integer; Var Line1, Line2, Line3: String);
Begin
 Case Mode Of
  RF_ORIGINAL: Begin
   Line1 := 'Aucune transformation selectionnee.';
   Line2 := 'Comparez les symboles puis choisissez';
   Line3 := 'le resultat dans les boutons a gauche.';
  End;
  RF_HORIZONTAL: Begin
   Line1 := 'Miroir selon un axe vertical.';
   Line2 := 'La gauche et la droite sont echangees.';
   Line3 := 'La largeur et la hauteur sont conservees.';
  End;
  RF_VERTICAL: Begin
   Line1 := 'Miroir selon un axe horizontal.';
   Line2 := 'Le haut et le bas sont echanges.';
   Line3 := 'La largeur et la hauteur sont conservees.';
  End;
  RF_LEFT: Begin
   Line1 := '90 deg vers la gauche : antihoraire.';
   Line2 := 'Equivalent a 270 deg vers la droite.';
   Line3 := 'La largeur et la hauteur sont echangees.';
  End;
  RF_RIGHT: Begin
   Line1 := '90 deg vers la droite : sens horaire.';
   Line2 := 'Equivalent a 270 deg vers la gauche.';
   Line3 := 'La largeur et la hauteur sont echangees.';
  End;
  RF_HALF: Begin
   Line1 := '180 deg : un demi-tour complet.';
   Line2 := 'Le haut devient le bas, et inversement.';
   Line3 := 'La largeur et la hauteur sont conservees.';
  End;
 End;
End;

Procedure RFCenteredText(Const R: TRect; Y: Integer; Const S: String);
Begin
 OutTextXY(R.Left+(R.Right-R.Left+1-TextWidth(S)) Div 2,Y,S);
End;

Procedure RFArrowHead(X, Y, Direction: Integer);
Begin
 Case Direction Of
  0: Begin Line(X,Y,X+4,Y-4); Line(X,Y,X+4,Y+4); End;
  1: Begin Line(X,Y,X-4,Y-4); Line(X,Y,X-4,Y+4); End;
  2: Begin Line(X,Y,X-4,Y+4); Line(X,Y,X+4,Y+4); End;
  3: Begin Line(X,Y,X-4,Y-4); Line(X,Y,X+4,Y-4); End;
 End;
End;

Procedure RFDrawIcon(Const R: TRect; Mode: Integer; Selected: Boolean);
Const
 Letter: Array[0..6] of Byte = ($7C,$40,$40,$78,$40,$40,$40);
Var
 X, Y, SX, SY, Left, Top, Ink: Integer;
Begin
 Left := R.Left+24;
 Top := R.Top+8;
 Ink := Blue;
 If Selected Then
  Ink := White;
 { La lettre F asymetrique rend les deux miroirs faciles a distinguer. }
 For Y := 0 To 6 Do
  For X := 0 To 6 Do Begin
   RFMapPixel(Mode,7,7,X,Y,SX,SY);
   If (Letter[SY] And (1 Shl (6-SX))) <> 0 Then Begin
    SetFillStyle(SolidFill,Ink);
    Bar(Left+X*4,Top+Y*4,Left+X*4+3,Top+Y*4+3);
   End;
  End;
 SetColor(Ink);
 Case Mode Of
  RF_HORIZONTAL: Begin
   Line(R.Left+62,R.Top+22,R.Left+96,R.Top+22);
   RFArrowHead(R.Left+62,R.Top+22,0);
   RFArrowHead(R.Left+96,R.Top+22,1);
  End;
  RF_VERTICAL: Begin
   Line(R.Left+82,R.Top+8,R.Left+82,R.Top+36);
   RFArrowHead(R.Left+82,R.Top+8,2);
   RFArrowHead(R.Left+82,R.Top+36,3);
  End;
  RF_LEFT: Begin
   Arc(R.Left+82,R.Top+22,25,310,13);
   RFArrowHead(R.Left+93,R.Top+16,3);
  End;
  RF_RIGHT: Begin
   Arc(R.Left+82,R.Top+22,230,155,13);
   RFArrowHead(R.Left+71,R.Top+16,3);
  End;
  RF_HALF: Begin
   Arc(R.Left+82,R.Top+22,0,180,13);
   RFArrowHead(R.Left+69,R.Top+22,3);
   RFArrowHead(R.Left+95,R.Top+22,2);
  End;
 End;
End;

Procedure RFDrawTile(Const D: TRFState; Index: Integer);
Var
 R: TRect;
 Selected: Boolean;
Begin
 R := D.Tiles[Index];
 Selected := D.Mode = Index;
 If Selected Then
  PEFill(R,Blue)
 Else
  PEFill(R,LightGray);
 PEBevel(R,Selected);
 RFDrawIcon(R,Index,Selected);
 If Selected Then
  SetColor(White)
 Else
  SetColor(Black);
 RFCenteredText(R,R.Top+48,RFModeTitle(Index));
 RFCenteredText(R,R.Top+61,RFModeSubtitle(Index));
 If D.Focus = Index Then Begin
  SetLineStyle(DottedLn,0,NormWidth);
  Rectangle(R.Left+3,R.Top+3,R.Right-3,R.Bottom-3);
  SetLineStyle(SolidLn,0,NormWidth);
 End;
End;

Procedure RFChecker(const R: TRect);
Var
 X, Y, Right, Bottom: Integer;
Begin
 Y := R.Top;
 While Y <= R.Bottom Do Begin
  X := R.Left;
  While X <= R.Right Do Begin
   If (((X-R.Left) Div 8+(Y-R.Top) Div 8) And 1) = 0 Then
    SetFillStyle(SolidFill,LightGray)
   Else
    SetFillStyle(SolidFill,White);
   Right := Min(X+7,R.Right);
   Bottom := Min(Y+7,R.Bottom);
   Bar(X,Y,Right,Bottom);
   Inc(X,8);
  End;
  Inc(Y,8);
 End;
End;

Procedure RFFitSize(W, H, MaxW, MaxH: Integer; Var DrawW, DrawH: Integer);
Begin
 DrawW := 1;
 DrawH := 1;
 If (W <= 0) Or (H <= 0) Then
  Exit;
 If LongInt(W)*MaxH >= LongInt(H)*MaxW Then Begin
  DrawW := MaxW;
  DrawH := Max(1,(LongInt(H)*MaxW) Div W);
 End
 Else Begin
  DrawH := MaxH;
  DrawW := Max(1,(LongInt(W)*MaxH) Div H);
 End;
End;

Procedure RFDrawPreview(Const D: TRFState; Const R: TRect; After: Boolean);
Var
 W, H, Mode, DrawW, DrawH: Integer;
 X, Y, DX, DY, SX, SY, Left, Top: Integer;
 Inner: TRect;
 C: TRGBColor;
Begin
 Inner := R;
 Inc(Inner.Left,2);
 Inc(Inner.Top,2);
 Dec(Inner.Right,2);
 Dec(Inner.Bottom,2);
 RFChecker(Inner);
 PEBevel(R,True);
 If Not PGHasImage Or (D.SourceW <= 0) Or (D.SourceH <= 0) Then
  Exit;
 W := D.SourceW;
 H := D.SourceH;
 Mode := RF_ORIGINAL;
 If After Then Begin
  W := D.ResultW;
  H := D.ResultH;
  Mode := D.Mode;
 End;
 RFFitSize(W,H,156,156,DrawW,DrawH);
 Left := R.Left+(R.Right-R.Left+1-DrawW) Div 2;
 Top := R.Top+(R.Bottom-R.Top+1-DrawH) Div 2;
 For Y := 0 To DrawH-1 Do Begin
  DY := Min(H-1,(LongInt(Y)*H+H Div 2) Div DrawH);
  For X := 0 To DrawW-1 Do Begin
   DX := Min(W-1,(LongInt(X)*W+W Div 2) Div DrawW);
   RFMapPixel(Mode,D.SourceW,D.SourceH,DX,DY,SX,SY);
   If PGReadRGB(D.Source.Left+SX,D.Source.Top+SY,C) Then
    PutPixel(Left+X,Top+Y,PEDisplayColor(C));
  End;
 End;
 SetColor(DarkGray);
 Rectangle(Left-1,Top-1,Left+DrawW,Top+DrawH);
End;

Procedure RFDrawScope(Const D: TRFState);
Begin
 PELabel(D.X+12,D.Y+307,'Zone a transformer :');
 If D.UseSelection Then Begin
  PELabel(D.X+12,D.Y+325,'( ) Image entiere');
  PELabel(D.X+12,D.Y+344,'(*) Selection active');
 End
 Else Begin
  PELabel(D.X+12,D.Y+325,'(*) Image entiere');
  If D.HasSelection Then
   PELabel(D.X+12,D.Y+344,'( ) Selection active')
  Else Begin
   SetColor(DarkGray);
   OutTextXY(D.X+12,D.Y+344,'( ) Selection indisponible');
  End;
 End;
 If D.Focus = RF_FOCUS_SCOPE Then Begin
  SetColor(Black);
  SetLineStyle(DottedLn,0,NormWidth);
  Rectangle(D.ScopeBox.Left-2,D.ScopeBox.Top-2,
            D.ScopeBox.Right+2,D.ScopeBox.Bottom+2);
  SetLineStyle(SolidLn,0,NormWidth);
 End;
End;

Procedure RFDrawExplanation(Const D: TRFState);
Var
 L1, L2, L3: String;
Begin
 RFExplanation(D.Mode,L1,L2,L3);
 PELabel(D.X+264,D.Y+274,L1);
 PELabel(D.X+264,D.Y+291,L2);
 PELabel(D.X+264,D.Y+308,L3);
 If D.UseSelection Then Begin
  PELabel(D.X+264,D.Y+337,'Apercu de la zone selectionnee.');
  PELabel(D.X+264,D.Y+353,'Le reste du dessin est conserve.');
 End
 Else Begin
  PELabel(D.X+264,D.Y+337,'Apercu de l image entiere.');
  PELabel(D.X+264,D.Y+353,'Transformation sans perte de couleur.');
 End;
End;

Procedure RFDraw(Var D: TRFState);
Var
 R: TRect;
 I: Integer;
Begin
 PEHideMouse;
 SetWriteMode(CopyPut);
 SetLineStyle(SolidLn,0,NormWidth);
 PERect(R,D.X,D.Y,620,430);
 PEFill(R,LightGray);
 PEBevel(R,False);
 SetFillStyle(SolidFill,Blue);
 Bar(D.X+3,D.Y+3,D.X+616,D.Y+21);
 SetColor(White);
 OutTextXY(D.X+9,D.Y+7,'Retourner / Pivoter - PAINT');
 OutTextXY(D.X+602,D.Y+7,'X');
 PELabel(D.X+12,D.Y+33,'Choisissez le resultat souhaite :');
 For I := 0 To RF_MODE_COUNT-1 Do
  RFDrawTile(D,I);
 PELabel(D.X+264,D.Y+49,'AVANT');
 PELabel(D.X+442,D.Y+49,'APRES');
 RFDrawPreview(D,D.BeforeBox,False);
 RFDrawPreview(D,D.AfterBox,True);
 PELabel(D.X+264,D.Y+239,PENumber(D.SourceW)+' x '+PENumber(D.SourceH)+' px');
 PELabel(D.X+442,D.Y+239,PENumber(D.ResultW)+' x '+PENumber(D.ResultH)+' px');
 PELabel(D.X+264,D.Y+255,'Apercus ajustes aux proportions.');
 RFDrawScope(D);
 RFDrawExplanation(D);
 PEButton(D.ApplyButton,'Appliquer',D.Focus = RF_FOCUS_APPLY);
 If (D.Mode = RF_ORIGINAL) Or Not D.ValidResult Then Begin
  PEFill(D.ApplyButton,LightGray);
  PEBevel(D.ApplyButton,False);
  SetColor(DarkGray);
  RFCenteredText(D.ApplyButton,D.ApplyButton.Top+8,'Appliquer');
 End;
 PEButton(D.CancelButton,'Annuler',D.Focus = RF_FOCUS_CANCEL);
 PEButton(D.ResetButton,'Reinitialiser',D.Focus = RF_FOCUS_RESET);
 PEButton(D.HelpButton,'Aide (F1)',D.Focus = RF_FOCUS_HELP);
 SetFillStyle(SolidFill,LightGray);
 Bar(0,ScreenHeight-STATUSBAR_HEIGHT,ScreenWidth-1,ScreenHeight-1);
 PELabel(5,ScreenHeight-STATUSBAR_HEIGHT+5,D.Status);
 PEShowMouse;
 D.Dirty := False;
End;

Procedure RFChoose(Var D: TRFState; Mode: Integer);
Begin
 D.Mode := PEClamp(Mode,0,RF_MODE_COUNT-1);
 D.Focus := D.Mode;
 RFUpdateResult(D);
End;

Procedure RFHelp(Var D: TRFState);
Begin
 ShowMessage('Aide - Retourner / Pivoter',
  'Horizontal : echange gauche et droite.'+#10+
  'Vertical : echange haut et bas.'+#10+
  '90 deg : quart de tour ; 180 deg : demi-tour.'+#10+
  'H/V : miroirs ; G/D : gauche/droite ; I : 180.'+#10+
  'Entree applique ; Echap annule ; Ctrl+Z ensuite.');
 D.Dirty := True;
End;

Procedure RFActivate(Var D: TRFState; Action: Integer);
Begin
 Case Action Of
  RF_FOCUS_APPLY: Begin
   If D.ValidResult And (D.Mode <> RF_ORIGINAL) Then Begin
    D.Accepted := True;
    D.Done := True;
   End;
  End;
  RF_FOCUS_CANCEL: Begin
   D.Accepted := False;
   D.Done := True;
  End;
  RF_FOCUS_RESET: RFChoose(D,RF_ORIGINAL);
  RF_FOCUS_HELP: RFHelp(D);
  RF_FOCUS_SCOPE: Begin
   If D.HasSelection Then Begin
    D.UseSelection := Not D.UseSelection;
    RFUpdateResult(D);
   End;
  End;
 Else
  If (Action >= 0) And (Action < RF_MODE_COUNT) Then
   RFChoose(D,Action);
 End;
End;

Procedure RFKeyboard(Var D: TRFState);
Var
 K: Char;
 Next: Integer;
Begin
 K := ReadKey;
 If K = #0 Then Begin
  K := ReadKey;
  Case Ord(K) Of
   15: Begin
    D.Focus := (D.Focus+RF_FOCUS_HELP) Mod (RF_FOCUS_HELP+1);
    D.Dirty := True;
   End;
   59: RFHelp(D);
   72,75,77,80: Begin
    If D.Focus < RF_MODE_COUNT Then Begin
     Next := D.Focus;
     Case Ord(K) Of
      72: Dec(Next,2);
      80: Inc(Next,2);
      75: Dec(Next);
      77: Inc(Next);
     End;
     Next := (Next+RF_MODE_COUNT) Mod RF_MODE_COUNT;
     RFChoose(D,Next);
    End;
   End;
  End;
  Exit;
 End;
 Case K Of
  #27: RFActivate(D,RF_FOCUS_CANCEL);
  #9: Begin
   D.Focus := (D.Focus+1) Mod (RF_FOCUS_HELP+1);
   D.Dirty := True;
  End;
  #13: Begin
   If D.Focus >= RF_FOCUS_SCOPE Then
    RFActivate(D,D.Focus)
   Else
    RFActivate(D,RF_FOCUS_APPLY);
  End;
  ' ': RFActivate(D,D.Focus);
 Else
  Case UpCase(K) Of
   'H': RFChoose(D,RF_HORIZONTAL);
   'V': RFChoose(D,RF_VERTICAL);
   'G','L': RFChoose(D,RF_LEFT);
   'D','R': RFChoose(D,RF_RIGHT);
   'I': RFChoose(D,RF_HALF);
   'O','0': RFChoose(D,RF_ORIGINAL);
  End;
 End;
End;

Procedure RFMouse(Var D: TRFState);
Var
 I: Integer;
Begin
 GetMouseStateLocal(D.MX,D.MY,D.MB);
 If ((D.MB And 1) <> 0) And ((D.PreviousButtons And 1) = 0) Then Begin
  If (D.MX >= D.X+596) And (D.MX <= D.X+617) And
     (D.MY >= D.Y+3) And (D.MY <= D.Y+21) Then
   RFActivate(D,RF_FOCUS_CANCEL)
  Else If PEInside(D.MX,D.MY,D.ApplyButton) Then
   RFActivate(D,RF_FOCUS_APPLY)
  Else If PEInside(D.MX,D.MY,D.CancelButton) Then
   RFActivate(D,RF_FOCUS_CANCEL)
  Else If PEInside(D.MX,D.MY,D.ResetButton) Then
   RFActivate(D,RF_FOCUS_RESET)
  Else If PEInside(D.MX,D.MY,D.HelpButton) Then
   RFActivate(D,RF_FOCUS_HELP)
  Else If PEInside(D.MX,D.MY,D.ScopeBox) And D.HasSelection Then Begin
   D.UseSelection := D.MY >= D.Y+338;
   D.Focus := RF_FOCUS_SCOPE;
   RFUpdateResult(D);
  End
  Else
   For I := 0 To RF_MODE_COUNT-1 Do
    If PEInside(D.MX,D.MY,D.Tiles[I]) Then
     RFChoose(D,I);
 End;
 D.PreviousButtons := D.MB;
End;

Procedure RFInitialize(Var D: TRFState);
Begin
 FillChar(D,SizeOf(D),0);
 PEInitialize(D.PaletteData);
 D.HasSelection := SelectionActive;
 D.UseSelection := D.HasSelection;
 RFLayout(D);
 RFUpdateResult(D);
 GetMouseStateLocal(D.MX,D.MY,D.PreviousButtons);
End;

Function RFBuildResult(Const D: TRFState; Var Buffer: PByte): Boolean;
Var
 X, Y, SX, SY: Integer;
 Dest: PByte;
 Index: Byte;
 Size: LongInt;
Begin
 Buffer := Nil;
 RFBuildResult := False;
 If Not D.ValidResult Or (D.Mode = RF_ORIGINAL) Then
  Exit;
 Size := LongInt(D.ResultW)*D.ResultH;
 If Size <= 0 Then
  Exit;
 GetMem(Buffer,Size);
 Dest := Buffer;
 For Y := 0 To D.ResultH-1 Do
  For X := 0 To D.ResultW-1 Do Begin
   RFMapPixel(D.Mode,D.SourceW,D.SourceH,X,Y,SX,SY);
   If Not PGReadIndex(D.Source.Left+SX,D.Source.Top+SY,Index) Then Begin
    FreeMem(Buffer,Size);
    Buffer := Nil;
    Exit;
   End;
   Dest^ := Index;
   Inc(Dest);
  End;
 RFBuildResult := True;
End;

Function RFApply(Const D: TRFState): Boolean;
Var
 Buffer, SourceRow, DestRow: PByte;
 X, Y: Integer;
Begin
 RFApply := False;
 If Not RFBuildResult(D,Buffer) Then
  Exit;
 { Aucun changement du document avant que le resultat soit disponible. }
 AddSnapshotToHistory(TOOL_PENCIL);
 If D.UseSelection Then Begin
  For Y := D.Source.Top To D.Source.Bottom Do Begin
   DestRow := CanvasImage;
   Inc(DestRow,LongInt(Y)*CanvasImageW+D.Source.Left);
   FillChar(DestRow^,D.SourceW,BackgroundColor);
  End;
  SourceRow := Buffer;
  For Y := 0 To D.ResultH-1 Do Begin
   DestRow := CanvasImage;
   Inc(DestRow,LongInt(D.Destination.Top+Y)*CanvasImageW+D.Destination.Left);
   For X := 0 To D.ResultW-1 Do Begin
    DestRow^ := SourceRow^;
    Inc(DestRow);
    Inc(SourceRow);
   End;
  End;
  FreeMem(Buffer,LongInt(D.ResultW)*D.ResultH);
  SelectionRect.Left := CanvasX+D.Destination.Left;
  SelectionRect.Top := CanvasY+D.Destination.Top;
  SelectionRect.Right := CanvasX+D.Destination.Right;
  SelectionRect.Bottom := CanvasY+D.Destination.Bottom;
  SelectionActive := True;
 End
 Else Begin
  FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
  CanvasImage := Buffer;
  CanvasImageW := D.ResultW;
  CanvasImageH := D.ResultH;
  ImageBuffer.Width := D.ResultW;
  ImageBuffer.Height := D.ResultH;
  SelectionActive := False;
 End;
 AntsValid := False;
 RubberValid := False;
 PreviewValid := False;
 ImageBuffer.Modified := True;
 RFApply := True;
End;

Procedure FlipRotateDialog;
Var
 D: TRFState;
Begin
 If Not PGHasImage Then Begin
  ShowMessage('Retourner / Pivoter','Aucune image a transformer.');
  Exit;
 End;
 MenuActive := False;
 RedrawInterface;
 RFInitialize(D);
 PEHideMouse;
 PEBuildDisplayPalette;
 PEShowMouse;
 While Not D.Done Do Begin
  If D.Dirty Then
   RFDraw(D);
  If KeyPressed Then
   RFKeyboard(D);
  If Not D.Done Then
   RFMouse(D);
  Delay(10);
 End;
 PEHideMouse;
 PERestoreHardware(D.PaletteData);
 If D.Accepted Then
  If Not RFApply(D) Then Begin
   PEShowMouse;
   ShowMessage('Retourner / Pivoter','Transformation impossible. Le dessin est conserve.');
   PEHideMouse;
  End;
 PEShowMouse;
 Repeat
  GetMouseStateLocal(D.MX,D.MY,D.MB);
  If (D.MB And 1) <> 0 Then
   Delay(10);
 Until (D.MB And 1) = 0;
 OldMouseButtons := 0;
 MouseButtons := 0;
 RedrawInterface;
End;


{ Etirer/Incliner : geometrie inverse, reechantillonnage RVB et palette
  adaptee. Le document indexe reste intact jusqu'a la fin du calcul.
  Les apercus interrogent exactement les memes filtres que le rendu final. }

Const
 ST_NEAREST = 0;
 ST_BILINEAR = 1;
 ST_BICUBIC = 2;
 ST_SMOOTH = 3;
 ST_SHARP = 4;
 ST_PI = 3.14159265358979323846;
 ST_HIST_SIZE = 32768;
 ST_MAX_BOXES = 240;
 ST_FIELD_COUNT = 4;
 ST_FOCUS_APPLY = 19;
 ST_FOCUS_CANCEL = 20;
 ST_FOCUS_RESET = 21;
 ST_FOCUS_HELP = 22;

Type
 PSTHistogram = ^TSTHistogram;
 TSTHistogram = Record
  Counts: Array[0..ST_HIST_SIZE-1] of LongInt;
  Reds, Greens, Blues: Array[0..ST_HIST_SIZE-1] of Real;
 End;
 PSTLookup = ^TSTLookup;
 TSTLookup = Array[0..ST_HIST_SIZE-1] of Byte;
 TSTBox = Record
  R0, R1, G0, G1, B0, B1: Integer;
  Count: LongInt;
  SumR, SumG, SumB: Real;
 End;
 TSTBoxes = Array[0..ST_MAX_BOXES-1] of TSTBox;
 TSTState = Record
  X, Y: Integer;
  OriginalW, OriginalH: Integer;
  ScaledW, ScaledH: Integer;
  ResultW, ResultH: Integer;
  PercentUnits, KeepAspect, ExpandCanvas: Boolean;
  ResizeOnly: Boolean;
  SkewX, SkewY: Integer;
  KX, KY, Determinant, OriginX, OriginY: Real;
  Method: Integer;
  Fields: Array[0..ST_FIELD_COUNT-1] of String[12];
  FieldRects: Array[0..ST_FIELD_COUNT-1] of TRect;
  MinusRects, PlusRects: Array[0..ST_FIELD_COUNT-1] of TRect;
  Presets: Array[0..3] of TRect;
  BeforeBox, AfterBox, PercentRect, PixelsRect: TRect;
  LockRect, ExpandRect: TRect;
  MethodRects: Array[0..4] of TRect;
  ApplyRect, CancelRect, ResetRect, HelpRect: TRect;
  RefreshRect, ZeroAnglesRect: TRect;
  Focus, FieldError: Integer;
  FieldSelected, Dirty, ValidResult, Done, Accepted: Boolean;
  Status: String[77];
  PaletteData: TPEState;
  MX, MY, MB, PreviousButtons: Integer;
 End;

Function STFloor(Value: Real): LongInt;
Var
 N: LongInt;
Begin
 N := Trunc(Value);
 If N > Value Then
  Dec(N);
 STFloor := N;
End;

Function STCeil(Value: Real): LongInt;
Begin
 STCeil := -STFloor(-Value);
End;

Function STNumber(Value: Real): String;
Var
 S: String;
Begin
 Str(Value:0:2,S);
 While (Length(S)>0) And (S[Length(S)]='0') Do
  Delete(S,Length(S),1);
 If (Length(S)>0) And (S[Length(S)]='.') Then
  Delete(S,Length(S),1);
 STNumber := S;
End;

Function STMemoryText(Bytes: LongInt): String;
Var
 S: String;
 I: Integer;
Begin
 If Bytes < 1024 Then
  S := PENumber(Bytes)+' o'
 Else If Bytes < 1024*1024 Then
  S := STNumber(Bytes/1024.0)+' Ko'
 Else
  S := STNumber(Bytes/1048576.0)+' Mo';
 For I := 1 To Length(S) Do
  If S[I]='.' Then
   S[I] := ',';
 STMemoryText := S;
End;

Function STParseNumber(S: String; Var Value: Real): Boolean;
Var
 I, Code: Integer;
Begin
 STParseNumber := False;
 If Length(S)=0 Then
  Exit;
 For I := 1 To Length(S) Do
  If S[I]=',' Then
   S[I] := '.';
 Val(S,Value,Code);
 STParseNumber := Code=0;
End;

Procedure STSyncFields(Var D: TSTState);
Begin
 If D.PercentUnits Then Begin
  D.Fields[0] := STNumber(D.ScaledW*100.0/D.OriginalW);
  D.Fields[1] := STNumber(D.ScaledH*100.0/D.OriginalH);
 End
 Else Begin
  D.Fields[0] := PENumber(D.ScaledW);
  D.Fields[1] := PENumber(D.ScaledH);
 End;
 D.Fields[2] := PENumber(D.SkewX);
 D.Fields[3] := PENumber(D.SkewY);
 D.FieldError := -1;
End;

Procedure STUpdateGeometry(Var D: TSTState);
Var
 MinX, MaxX, MinY, MaxY: Real;
 W, H: LongInt;
Begin
 D.KX := Sin(D.SkewX*ST_PI/180)/Cos(D.SkewX*ST_PI/180);
 D.KY := Sin(D.SkewY*ST_PI/180)/Cos(D.SkewY*ST_PI/180);
 D.Determinant := 1-D.KX*D.KY;
 MinX := 0;
 MaxX := D.ScaledW;
 MinY := 0;
 MaxY := D.ScaledH;
 If D.KX < 0 Then
  MinX := D.KX*D.ScaledH
 Else
  MaxX := MaxX+D.KX*D.ScaledH;
 If D.KY < 0 Then
  MinY := D.KY*D.ScaledW
 Else
  MaxY := MaxY+D.KY*D.ScaledW;
 If D.ExpandCanvas Then Begin
  W := STCeil(MaxX-MinX-0.0000001);
  H := STCeil(MaxY-MinY-0.0000001);
  D.OriginX := MinX;
  D.OriginY := MinY;
 End
 Else Begin
  W := D.ScaledW;
  H := D.ScaledH;
  D.OriginX := (MinX+MaxX-W)/2;
  D.OriginY := (MinY+MaxY-H)/2;
 End;
 D.ValidResult := (W>=1) And (W<=MAX_IMAGE_WIDTH) And
                  (H>=1) And (H<=MAX_IMAGE_HEIGHT) And
                  (Abs(D.Determinant)>0.000001) And (D.FieldError<0);
 If W<1 Then D.ResultW := 1
 Else If W>MAX_IMAGE_WIDTH Then D.ResultW := MAX_IMAGE_WIDTH
 Else D.ResultW := W;
 If H<1 Then D.ResultH := 1
 Else If H>MAX_IMAGE_HEIGHT Then D.ResultH := MAX_IMAGE_HEIGHT
 Else D.ResultH := H;
 If Abs(D.Determinant)<=0.000001 Then
  D.Status := 'Ces deux angles aplatissent l image. Modifiez une inclinaison.'
 Else If (W>MAX_IMAGE_WIDTH) Or (H>MAX_IMAGE_HEIGHT) Then
  D.Status := 'Resultat trop grand : maximum 4096 x 4096 pixels. Reduisez les valeurs.'
 Else If Not D.ExpandCanvas And ((D.SkewX<>0) Or (D.SkewY<>0)) Then
  D.Status := 'Cadre fixe : les parties qui depassent seront coupees.'
 Else
  D.Status := 'Apercu automatique. Entree applique ; Echap conserve le dessin original.';
 D.Dirty := True;
End;

Function STChanged(Const D: TSTState): Boolean;
Begin
 STChanged := (D.ScaledW<>D.OriginalW) Or (D.ScaledH<>D.OriginalH) Or
              (D.SkewX<>0) Or (D.SkewY<>0);
End;

Function STValidateField(Var D: TSTState; Index: Integer): Boolean;
Var
 Value: Real;
 W, H, Angle: LongInt;
 I: Integer;
 Saved: String;
Begin
 STValidateField := False;
 If (Index<0) Or (Index>=ST_FIELD_COUNT) Then
  Exit;
 If Not STParseNumber(D.Fields[Index],Value) Then Begin
  D.Status := 'Saisissez une valeur numerique ; virgule ou point pour les pourcentages.';
  D.FieldError := Index;
  D.Dirty := True;
  Exit;
 End;
 W := D.ScaledW;
 H := D.ScaledH;
 If Index<2 Then Begin
  If D.PercentUnits Then Begin
   If (Value<=0) Or (Value>409600) Then Begin
    D.Status := 'Pourcentage positif attendu ; les dimensions finales sont limitees a 4096 px.';
    D.FieldError := Index;
    D.Dirty := True;
    Exit;
   End;
   If Index=0 Then Begin
    W := Round(D.OriginalW*Value/100);
    If W<1 Then W := 1;
   End
   Else Begin
    H := Round(D.OriginalH*Value/100);
    If H<1 Then H := 1;
   End;
  End
  Else Begin
   If (Value<1) Or (Value>4096) Or (Abs(Value-Round(Value))>0.000001) Then Begin
    D.Status := 'La taille en pixels doit etre un entier compris entre 1 et 4096.';
    D.FieldError := Index;
    D.Dirty := True;
    Exit;
   End;
   If Index=0 Then
    W := Round(Value)
   Else
    H := Round(Value);
  End;
  If D.KeepAspect Then Begin
   If Index=0 Then Begin
    H := Round(W*1.0*D.OriginalH/D.OriginalW);
    If H<1 Then H := 1;
   End
   Else Begin
    W := Round(H*1.0*D.OriginalW/D.OriginalH);
    If W<1 Then W := 1;
   End;
  End;
  If (W>4096) Or (H>4096) Then Begin
   D.Status := 'Ces dimensions depassent 4096 pixels. Reduisez la taille demandee.';
   D.FieldError := Index;
   D.Dirty := True;
   Exit;
  End;
  D.ScaledW := W;
  D.ScaledH := H;
 End
 Else Begin
  If (Value < -89) Or (Value>89) Or (Abs(Value-Round(Value))>0.000001) Then Begin
   D.Status := 'L inclinaison doit etre un nombre entier de -89 a +89 degres.';
   D.FieldError := Index;
   D.Dirty := True;
   Exit;
  End;
  Angle := Round(Value);
  If Index=2 Then
   D.SkewX := Angle
  Else
   D.SkewY := Angle;
 End;
 Saved := D.Fields[Index];
 STSyncFields(D);
 D.Fields[Index] := Saved;
 D.FieldError := -1;
 STUpdateGeometry(D);
 STValidateField := True;
End;

Function STLeaveField(Var D: TSTState): Boolean;
Var
 Valid: Boolean;
Begin
 Valid := True;
 If D.Focus<ST_FIELD_COUNT Then Begin
  Valid := STValidateField(D,D.Focus);
  If Valid Then STSyncFields(D);
 End;
 STLeaveField := Valid;
End;

Procedure STMapPoint(Const D: TSTState; X, Y: Real; Var SX, SY: Real);
Var
 TX, TY, UX, UY: Real;
Begin
 TX := X+0.5+D.OriginX;
 TY := Y+0.5+D.OriginY;
 UX := (TX-D.KX*TY)/D.Determinant;
 UY := (TY-D.KY*TX)/D.Determinant;
 SX := UX*D.OriginalW/D.ScaledW-0.5;
 SY := UY*D.OriginalH/D.ScaledH-0.5;
End;

Function STChannel(Value: Real): Integer;
Begin
 If Value<0 Then
  STChannel := 0
 Else If Value>255 Then
  STChannel := 255
 Else
  STChannel := Round(Value);
End;

Function STSourceRGB(X, Y: Integer): TRGBColor;
Var
 C: TRGBColor;
Begin
 X := PEClamp(X,0,CanvasImageW-1);
 Y := PEClamp(Y,0,CanvasImageH-1);
 If Not PGReadRGB(X,Y,C) Then
  C := ImageBuffer.Palette[BackgroundColor];
 STSourceRGB := C;
End;

Function STCubicWeight(X, B, C: Real): Real;
Begin
 X := Abs(X);
 If X<1 Then
  STCubicWeight := ((12-9*B-6*C)*X*X*X+(-18+12*B+6*C)*X*X+6-2*B)/6
 Else If X<2 Then
  STCubicWeight := ((-B-6*C)*X*X*X+(6*B+30*C)*X*X+
                   (-12*B-48*C)*X+8*B+24*C)/6
 Else
  STCubicWeight := 0;
End;

Function STInterpolate(Const D: TSTState; SX, SY: Real): TRGBColor;
Var
 X0, Y0, X, Y: Integer;
 FX, FY, WX, WY, Weight, Total: Real;
 R, G, Bl, B, C: Real;
 Pixel: TRGBColor;
Begin
 If (SX < -0.5) Or (SY < -0.5) Or
    (SX > D.OriginalW-0.5) Or (SY > D.OriginalH-0.5) Then Begin
  STInterpolate := ImageBuffer.Palette[BackgroundColor];
  Exit;
 End;
 If D.Method=ST_NEAREST Then Begin
  STInterpolate := STSourceRGB(STFloor(SX+0.5),STFloor(SY+0.5));
  Exit;
 End;
 X0 := STFloor(SX);
 Y0 := STFloor(SY);
 FX := SX-X0;
 FY := SY-Y0;
 R := 0;
 G := 0;
 Bl := 0;
 Total := 0;
 If D.Method=ST_BILINEAR Then Begin
  For Y := 0 To 1 Do
   For X := 0 To 1 Do Begin
    If X=0 Then WX := 1-FX Else WX := FX;
    If Y=0 Then WY := 1-FY Else WY := FY;
    Weight := WX*WY;
    Pixel := STSourceRGB(X0+X,Y0+Y);
    R := R+Pixel.R*Weight;
    G := G+Pixel.G*Weight;
    Bl := Bl+Pixel.B*Weight;
   End;
 End
 Else Begin
  B := 0;
  C := 0.5;
  If D.Method=ST_SMOOTH Then Begin B := 1; C := 0; End;
  If D.Method=ST_SHARP Then C := 0.75;
  For Y := -1 To 2 Do Begin
   WY := STCubicWeight(Y-FY,B,C);
   For X := -1 To 2 Do Begin
    WX := STCubicWeight(X-FX,B,C);
    Weight := WX*WY;
    Pixel := STSourceRGB(X0+X,Y0+Y);
    R := R+Pixel.R*Weight;
    G := G+Pixel.G*Weight;
    Bl := Bl+Pixel.B*Weight;
    Total := Total+Weight;
   End;
  End;
  If Abs(Total)>0.000001 Then Begin
   R := R/Total;
   G := G/Total;
   Bl := Bl/Total;
  End;
 End;
 STInterpolate := PERGB(STChannel(R),STChannel(G),STChannel(Bl));
End;

Function STOutputRGB(Const D: TSTState; X, Y: Real): TRGBColor;
Var
 SX, SY: Real;
Begin
 STMapPoint(D,X,Y,SX,SY);
 STOutputRGB := STInterpolate(D,SX,SY);
End;

Function STBin(Const C: TRGBColor): Integer;
Begin
 STBin := (Integer(C.R Shr 3) Shl 10)+(Integer(C.G Shr 3) Shl 5)+(C.B Shr 3);
End;

Function STAllocate(Var P: Pointer; Size: LongInt): Boolean;
{$IFDEF FPC}
Var
 Previous: Boolean;
{$ENDIF}
Begin
 P := Nil;
 If Size<=0 Then Begin STAllocate := False; Exit; End;
 {$IFDEF FPC}
 Previous := ReturnNilIfGrowHeapFails;
 ReturnNilIfGrowHeapFails := True;
 GetMem(P,Size);
 ReturnNilIfGrowHeapFails := Previous;
 {$ELSE}
 If MaxAvail>=Size Then GetMem(P,Size);
 {$ENDIF}
 STAllocate := P<>Nil;
End;

Procedure STBoxStats(Var B: TSTBox; Histogram: PSTHistogram);
Var
 R, G, Bl, MinR, MaxR, MinG, MaxG, MinB, MaxB, Index: Integer;
 Count: LongInt;
Begin
 B.Count := 0;
 B.SumR := 0;
 B.SumG := 0;
 B.SumB := 0;
 MinR := 31; MaxR := 0;
 MinG := 31; MaxG := 0;
 MinB := 31; MaxB := 0;
 For R := B.R0 To B.R1 Do
  For G := B.G0 To B.G1 Do
   For Bl := B.B0 To B.B1 Do Begin
    Index := (R Shl 10)+(G Shl 5)+Bl;
    Count := Histogram^.Counts[Index];
    If Count>0 Then Begin
     B.Count := B.Count+Count;
     B.SumR := B.SumR+Histogram^.Reds[Index];
     B.SumG := B.SumG+Histogram^.Greens[Index];
     B.SumB := B.SumB+Histogram^.Blues[Index];
     MinR := Min(MinR,R); MaxR := Max(MaxR,R);
     MinG := Min(MinG,G); MaxG := Max(MaxG,G);
     MinB := Min(MinB,Bl); MaxB := Max(MaxB,Bl);
    End;
   End;
 If B.Count>0 Then Begin
  B.R0 := MinR; B.R1 := MaxR;
  B.G0 := MinG; B.G1 := MaxG;
  B.B0 := MinB; B.B1 := MaxB;
 End;
End;

Function STSplitBox(Var A, B: TSTBox; Histogram: PSTHistogram): Boolean;
Var
 Axis, Range, I, R, G, Bl, Index, Low, High, Split: Integer;
 Counts: Array[0..31] of LongInt;
 Sum: LongInt;
Begin
 STSplitBox := False;
 Axis := 0;
 Range := A.R1-A.R0;
 If A.G1-A.G0>Range Then Begin Axis := 1; Range := A.G1-A.G0; End;
 If A.B1-A.B0>Range Then Begin Axis := 2; Range := A.B1-A.B0; End;
 If Range=0 Then Exit;
 FillChar(Counts,SizeOf(Counts),0);
 For R := A.R0 To A.R1 Do
  For G := A.G0 To A.G1 Do
   For Bl := A.B0 To A.B1 Do Begin
    Index := (R Shl 10)+(G Shl 5)+Bl;
    Case Axis Of
     0: I := R;
     1: I := G;
    Else I := Bl;
    End;
    Counts[I] := Counts[I]+Histogram^.Counts[Index];
   End;
 Case Axis Of
  0: Begin Low := A.R0; High := A.R1; End;
  1: Begin Low := A.G0; High := A.G1; End;
 Else Begin Low := A.B0; High := A.B1; End;
 End;
 Sum := 0;
 Split := Low;
 For I := Low To High-1 Do Begin
  Sum := Sum+Counts[I];
  Split := I;
  If Sum>=A.Count Div 2 Then Break;
 End;
 B := A;
 Case Axis Of
  0: Begin A.R1 := Split; B.R0 := Split+1; End;
  1: Begin A.G1 := Split; B.G0 := Split+1; End;
  2: Begin A.B1 := Split; B.B0 := Split+1; End;
 End;
 STBoxStats(A,Histogram);
 STBoxStats(B,Histogram);
 STSplitBox := (A.Count>0) And (B.Count>0);
End;

Procedure STMakePalette(Histogram: PSTHistogram; Var Palette: TPalette);
Var
 Boxes: TSTBoxes;
 I, Best, Count, Range: Integer;
 Score, BestScore: Real;
 A, B: TSTBox;
Begin
 Palette := ImageBuffer.Palette;
 FillChar(Boxes,SizeOf(Boxes),0);
 Boxes[0].R1 := 31;
 Boxes[0].G1 := 31;
 Boxes[0].B1 := 31;
 STBoxStats(Boxes[0],Histogram);
 Count := 1;
 While Count<ST_MAX_BOXES Do Begin
  Best := -1;
  BestScore := 0;
  For I := 0 To Count-1 Do Begin
   Range := Max(Boxes[I].R1-Boxes[I].R0,
                Max(Boxes[I].G1-Boxes[I].G0,Boxes[I].B1-Boxes[I].B0));
   Score := Range*1.0*Boxes[I].Count;
   If Score>BestScore Then Begin
    BestScore := Score;
    Best := I;
   End;
  End;
  If Best<0 Then Break;
  A := Boxes[Best];
  If Not STSplitBox(A,B,Histogram) Then Break;
  Boxes[Best] := A;
  Boxes[Count] := B;
  Inc(Count);
 End;
 For I := 0 To Count-1 Do
  If Boxes[I].Count>0 Then
   Palette[16+I] := PERGB(STChannel(Boxes[I].SumR/Boxes[I].Count),
                         STChannel(Boxes[I].SumG/Boxes[I].Count),
                         STChannel(Boxes[I].SumB/Boxes[I].Count));
End;

Function STNearestColor(Const C: TRGBColor; Const Palette: TPalette): Byte;
Var
 I, Best: Integer;
 Distance, BestDistance: LongInt;
Begin
 Best := 0;
 BestDistance := MaxLongInt;
 For I := 0 To 255 Do Begin
  Distance := PGDistance(C,Palette[I]);
  If Distance<BestDistance Then Begin
   BestDistance := Distance;
   Best := I;
   If Distance=0 Then Break;
  End;
 End;
 STNearestColor := Best;
End;

Function STProgress(Row, Total: Integer; Const Stage: String; Interactive: Boolean): Boolean;
Var
 K: Char;
 R: TRect;
Begin
 STProgress := True;
 If Not Interactive Then Exit;
 If (Row Mod 16=0) Or (Row=Total-1) Then Begin
  PEHideMouse;
  PERect(R,160,ScreenHeight Div 2-32,320,65);
  PEFill(R,LightGray);
  PEBevel(R,False);
  PELabel(R.Left+12,R.Top+10,Stage+' - Echap annule');
  SetColor(Black);
  Rectangle(R.Left+12,R.Top+28,R.Right-12,R.Top+46);
  SetFillStyle(SolidFill,Blue);
  Bar(R.Left+14,R.Top+30,R.Left+14+(LongInt(Row+1)*290) Div Total,R.Top+44);
  PEShowMouse;
 End;
 While KeyPressed Do Begin
  K := ReadKey;
  If K=#0 Then K := ReadKey
  Else If K=#27 Then STProgress := False;
 End;
End;

Function STBuildResult(Const D: TSTState; Var Buffer: PByte;
                       Var Palette: TPalette; Interactive: Boolean): Boolean;
Var
 RGBBuffer, OutPixel, RGBPixel, Src: PByte;
 Histogram: PSTHistogram;
 Lookup: PSTLookup;
 Memory: Pointer;
 Pixels, I: LongInt;
 X, Y, Index: Integer;
 SX, SY: Real;
 C: TRGBColor;
 Successful: Boolean;
Begin
 STBuildResult := False;
 Buffer := Nil;
 RGBBuffer := Nil;
 Histogram := Nil;
 Lookup := Nil;
 Palette := ImageBuffer.Palette;
 If Not D.ValidResult Or (D.FieldError>=0) Or Not PGHasImage Then Exit;
 Pixels := LongInt(D.ResultW)*D.ResultH;
 If Not STAllocate(Memory,Pixels) Then Exit;
 Buffer := Memory;
 If D.Method=ST_NEAREST Then Begin
  OutPixel := Buffer;
  Successful := True;
  For Y := 0 To D.ResultH-1 Do Begin
   If Not STProgress(Y,D.ResultH,'Transformation',Interactive) Then Begin
    Successful := False;
    Break;
   End;
   For X := 0 To D.ResultW-1 Do Begin
    STMapPoint(D,X,Y,SX,SY);
    OutPixel^ := BackgroundColor;
    If (SX>=-0.5) And (SY>=-0.5) And
       (SX<D.OriginalW-0.5) And (SY<D.OriginalH-0.5) Then
     If PGReadIndex(PEClamp(STFloor(SX+0.5),0,D.OriginalW-1),
                    PEClamp(STFloor(SY+0.5),0,D.OriginalH-1),OutPixel^) Then
      Successful := True;
    Inc(OutPixel);
   End;
  End;
  If Successful Then STBuildResult := True
  Else Begin FreeMem(Buffer,Pixels); Buffer := Nil; End;
  Exit;
 End;
 Successful := STAllocate(Memory,Pixels*3);
 If Successful Then RGBBuffer := Memory;
 If Successful Then Begin
  Successful := STAllocate(Memory,SizeOf(TSTHistogram));
  If Successful Then Histogram := Memory;
 End;
 If Successful Then Begin
  Successful := STAllocate(Memory,SizeOf(TSTLookup));
  If Successful Then Lookup := Memory;
 End;
 If Successful Then Begin
  FillChar(Histogram^,SizeOf(TSTHistogram),0);
  RGBPixel := RGBBuffer;
  For Y := 0 To D.ResultH-1 Do Begin
   If Not STProgress(Y,D.ResultH,'Reechantillonnage RVB',Interactive) Then Begin
    Successful := False;
    Break;
   End;
   For X := 0 To D.ResultW-1 Do Begin
    C := STOutputRGB(D,X,Y);
    RGBPixel^ := C.R; Inc(RGBPixel);
    RGBPixel^ := C.G; Inc(RGBPixel);
    RGBPixel^ := C.B; Inc(RGBPixel);
    Index := STBin(C);
    Inc(Histogram^.Counts[Index]);
    Histogram^.Reds[Index] := Histogram^.Reds[Index]+C.R;
    Histogram^.Greens[Index] := Histogram^.Greens[Index]+C.G;
    Histogram^.Blues[Index] := Histogram^.Blues[Index]+C.B;
   End;
  End;
 End;
 If Successful Then Begin
  STMakePalette(Histogram,Palette);
  For Index := 0 To ST_HIST_SIZE-1 Do Begin
   If Index Mod 128=0 Then
    If Not STProgress(Index Div 128,256,'Adaptation des couleurs',Interactive) Then Begin
     Successful := False;
     Break;
    End;
   C := PERGB(((Index Shr 10) And 31)*8+4,
              ((Index Shr 5) And 31)*8+4,(Index And 31)*8+4);
   Lookup^[Index] := STNearestColor(C,Palette);
  End;
 End;
 If Successful Then Begin
  RGBPixel := RGBBuffer;
  OutPixel := Buffer;
  For I := 0 To Pixels-1 Do Begin
   C.R := RGBPixel^; Inc(RGBPixel);
   C.G := RGBPixel^; Inc(RGBPixel);
   C.B := RGBPixel^; Inc(RGBPixel);
   OutPixel^ := Lookup^[STBin(C)];
   Inc(OutPixel);
  End;
  STBuildResult := True;
 End;
 If RGBBuffer<>Nil Then FreeMem(RGBBuffer,Pixels*3);
 If Histogram<>Nil Then FreeMem(Histogram,SizeOf(TSTHistogram));
 If Lookup<>Nil Then FreeMem(Lookup,SizeOf(TSTLookup));
 If Not Successful Then Begin FreeMem(Buffer,Pixels); Buffer := Nil; End;
End;

Function STApply(Const D: TSTState; Interactive: Boolean): Boolean;
Var
 Buffer: PByte;
 Palette: TPalette;
 ForegroundRGB, BackgroundRGB: TRGBColor;
 Swatches: Array[0..27] of TRGBColor;
 I: Integer;
Begin
 STApply := False;
 If Not STChanged(D) Then Exit;
 If Not STBuildResult(D,Buffer,Palette,Interactive) Then Exit;
 ForegroundRGB := ImageBuffer.Palette[CurrentColor];
 BackgroundRGB := ImageBuffer.Palette[BackgroundColor];
 For I := 0 To 27 Do Swatches[I] := ImageBuffer.Palette[StandardPalette[I]];
 AddSnapshotToHistory(TOOL_PENCIL);
 FreeMem(CanvasImage,LongInt(CanvasImageW)*CanvasImageH);
 CanvasImage := Buffer;
 CanvasImageW := D.ResultW;
 CanvasImageH := D.ResultH;
 ImageBuffer.Width := D.ResultW;
 ImageBuffer.Height := D.ResultH;
 ImageBuffer.Palette := Palette;
 ImageBuffer.BitDepth := 8;
 ImageBuffer.Modified := True;
 If D.Method<>ST_NEAREST Then Begin
  CurrentColor := STNearestColor(ForegroundRGB,Palette);
  BackgroundColor := STNearestColor(BackgroundRGB,Palette);
  For I := 0 To 27 Do StandardPalette[I] := STNearestColor(Swatches[I],Palette);
 End;
 SelectionActive := False;
 AntsValid := False;
 PreviewValid := False;
 RubberValid := False;
 PEInstallDocumentPalette;
 STApply := True;
End;

Procedure STLayout(Var D: TSTState);
Var
 I, Y: Integer;
Begin
 D.X := (ScreenWidth-620) Div 2;
 D.Y := (ScreenHeight-440) Div 2;
 PERect(D.PercentRect,D.X+12,D.Y+47,132,20);
 PERect(D.PixelsRect,D.X+154,D.Y+47,132,20);
 For I := 0 To 3 Do Begin
  Case I Of
   0: Y := 77;
   1: Y := 111;
   2: Y := 217;
  Else Y := 251;
  End;
  PERect(D.FieldRects[I],D.X+168,D.Y+Y,68,22);
  PERect(D.MinusRects[I],D.X+241,D.Y+Y,21,22);
  PERect(D.PlusRects[I],D.X+267,D.Y+Y,21,22);
 End;
 PERect(D.LockRect,D.X+12,D.Y+143,280,19);
 For I := 0 To 3 Do PERect(D.Presets[I],D.X+12+I*70,D.Y+165,63,23);
 For I := 0 To 4 Do PERect(D.MethodRects[I],D.X+12,D.Y+301+I*18,280,17);
 PERect(D.BeforeBox,D.X+314,D.Y+52,137,126);
 PERect(D.AfterBox,D.X+465,D.Y+52,137,126);
 PERect(D.ExpandRect,D.X+314,D.Y+330,288,18);
 PERect(D.RefreshRect,D.X+314,D.Y+373,130,22);
 PERect(D.ZeroAnglesRect,D.X+454,D.Y+373,148,22);
 PERect(D.ApplyRect,D.X+12,D.Y+406,124,25);
 PERect(D.CancelRect,D.X+148,D.Y+406,120,25);
 PERect(D.ResetRect,D.X+280,D.Y+406,146,25);
 PERect(D.HelpRect,D.X+438,D.Y+406,164,25);
End;

Function STMethodName(Method: Integer): String;
Begin
 Case Method Of
  ST_NEAREST: STMethodName := 'Au plus proche';
  ST_BILINEAR: STMethodName := 'Bilineaire';
  ST_BICUBIC: STMethodName := 'Bicubique';
  ST_SMOOTH: STMethodName := 'Bicubique plus lisse';
  ST_SHARP: STMethodName := 'Bicubique plus net';
 Else STMethodName := '';
 End;
End;

Procedure STAxisIcon(X, Y: Integer; Vertical, Skew: Boolean);
Begin
 SetColor(Blue);
 If Vertical Then Begin
  Line(X+10,Y+1,X+10,Y+20);
  RFArrowHead(X+10,Y+1,2);
  RFArrowHead(X+10,Y+20,3);
 End
 Else Begin
  Line(X,Y+10,X+22,Y+10);
  RFArrowHead(X,Y+10,0);
  RFArrowHead(X+22,Y+10,1);
 End;
 If Skew Then Begin
  SetColor(DarkGray);
  Line(X+2,Y+18,X+7,Y+3);
  Line(X+7,Y+3,X+22,Y+3);
  Line(X+22,Y+3,X+17,Y+18);
  Line(X+17,Y+18,X+2,Y+18);
 End;
End;

Procedure STDrawField(Const D: TSTState; Index: Integer);
Var
 R: TRect;
 S: String;
Begin
 R := D.FieldRects[Index];
 STAxisIcon(D.X+14,R.Top,(Index And 1)<>0,Index>=2);
 If (Index And 1)=0 Then S := 'Horizontal' Else S := 'Vertical';
 PELabel(D.X+48,R.Top+7,S);
 PEFill(R,White);
 PEBevel(R,True);
 If (D.Focus=Index) And D.FieldSelected Then Begin
  SetFillStyle(SolidFill,Blue);
  Bar(R.Left+3,R.Top+3,R.Right-3,R.Bottom-3);
  SetColor(White);
 End
 Else SetColor(Black);
 OutTextXY(R.Left+5,R.Top+7,Copy(D.Fields[Index],1,7));
 If (D.Focus=Index) And Not D.FieldSelected Then Begin
  SetColor(Black);
  Line(Min(R.Right-3,R.Left+5+TextWidth(D.Fields[Index])),R.Top+4,
       Min(R.Right-3,R.Left+5+TextWidth(D.Fields[Index])),R.Bottom-4);
 End;
 If D.FieldError=Index Then Begin
  SetColor(Red);
  Rectangle(R.Left-1,R.Top-1,R.Right+1,R.Bottom+1);
 End;
 PEButton(D.MinusRects[Index],'-',False);
 PEButton(D.PlusRects[Index],'+',False);
End;

Procedure STDrawRadio(Const R: TRect; const LabelText: String;
                      Selected, Focused: Boolean);
Var
 S: String;
Begin
 If Selected Then S := '(*) ' Else S := '( ) ';
 PELabel(R.Left,R.Top+4,S+LabelText);
 If Focused Then Begin
  SetColor(Black);
  SetLineStyle(DottedLn,0,NormWidth);
  Rectangle(R.Left-2,R.Top-1,R.Right+1,R.Bottom);
  SetLineStyle(SolidLn,0,NormWidth);
 End;
End;

Procedure STDrawPreview(Const D: TSTState; Const R: TRect; After: Boolean);
Var
 W, H, DW, DH, Left, Top, X, Y: Integer;
 DX, DY: Real;
 Inner: TRect;
 C: TRGBColor;
Begin
 Inner := R;
 Inc(Inner.Left,2); Inc(Inner.Top,2);
 Dec(Inner.Right,2); Dec(Inner.Bottom,2);
 RFChecker(Inner);
 PEBevel(R,True);
 If After And (Not D.ValidResult Or (D.FieldError>=0)) Then Begin
  PELabel(R.Left+14,R.Top+53,'Valeurs a');
  PELabel(R.Left+14,R.Top+67,'corriger');
  Exit;
 End;
 W := D.OriginalW; H := D.OriginalH;
 If After Then Begin W := D.ResultW; H := D.ResultH; End;
 RFFitSize(W,H,129,118,DW,DH);
 Left := R.Left+(137-DW) Div 2;
 Top := R.Top+(126-DH) Div 2;
 For Y := 0 To DH-1 Do
  For X := 0 To DW-1 Do Begin
   DX := (X+0.5)*W/DW-0.5;
   DY := (Y+0.5)*H/DH-0.5;
   If After Then Begin
    { Afficher les pixels du resultat, pas une nouvelle interpolation du
      document original a la taille du panneau. Important en reduction. }
    DX := STFloor((X+0.5)*W/DW);
    DY := STFloor((Y+0.5)*H/DH);
    C := STOutputRGB(D,DX,DY);
   End
   Else C := STSourceRGB(STFloor(DX+0.5),STFloor(DY+0.5));
   PutPixel(Left+X,Top+Y,PEDisplayColor(C));
  End;
 SetColor(DarkGray);
 Rectangle(Left-1,Top-1,Left+DW,Top+DH);
End;

Procedure STDrawEstimate(Const D: TSTState);
Var
 Pixels, SourcePixels, Work: LongInt;
 S: String;
 R: TRect;
Begin
 Pixels := LongInt(D.ResultW)*D.ResultH;
 SourcePixels := LongInt(D.OriginalW)*D.OriginalH;
 Work := Pixels+SourcePixels;
 If D.Method<>ST_NEAREST Then Work := Work+Pixels*3+SizeOf(TSTHistogram)+SizeOf(TSTLookup);
 PERect(R,D.X+314,D.Y+207,288,112);
 PEBevel(R,True);
 PELabel(R.Left+8,R.Top+8,'Resultat : '+PENumber(D.ResultW)+' x '+PENumber(D.ResultH));
 Str(Pixels,S);
 PELabel(R.Left+8,R.Top+27,'Pixels : '+S);
 PELabel(R.Left+8,R.Top+46,'Image indexee : '+STMemoryText(Pixels+1024));
 PELabel(R.Left+8,R.Top+65,'RVB 24 bits : '+STMemoryText(Pixels*3));
 PELabel(R.Left+8,R.Top+84,'Travail en plus : '+STMemoryText(Work));
End;

Procedure RDDraw(Var D: TSTState);
Var
 R: TRect;
 I: Integer;
 S, Description: String;
Begin
 PEHideMouse;
 SetWriteMode(CopyPut);
 SetLineStyle(SolidLn,0,NormWidth);
 PERect(R,D.X,D.Y,620,440);
 PEFill(R,LightGray);
 PEBevel(R,False);
 SetFillStyle(SolidFill,Blue);
 Bar(D.X+3,D.Y+3,D.X+616,D.Y+21);
 SetColor(White);
 OutTextXY(D.X+9,D.Y+7,'Redimensionner l image - PAINT');
 OutTextXY(D.X+602,D.Y+7,'X');
 PELabel(D.X+12,D.Y+32,'NOUVELLE TAILLE');
 STDrawRadio(D.PercentRect,'Pourcentage',D.PercentUnits,D.Focus=4);
 STDrawRadio(D.PixelsRect,'Pixels',Not D.PercentUnits,D.Focus=5);
 STDrawField(D,0);
 STDrawField(D,1);
 If D.KeepAspect Then S := '[x] ' Else S := '[ ] ';
 PELabel(D.LockRect.Left,D.LockRect.Top+4,S+'Conserver les proportions');
 If D.Focus=6 Then PEFocusRect(D.LockRect);
 PEButton(D.Presets[0],'25 %',D.Focus=13);
 PEButton(D.Presets[1],'50 %',D.Focus=14);
 PEButton(D.Presets[2],'100 %',D.Focus=15);
 PEButton(D.Presets[3],'200 %',D.Focus=16);
 PELabel(D.X+12,D.Y+202,'DIMENSIONS ET PROPORTIONS');
 PELabel(D.X+12,D.Y+223,'Origine : '+PENumber(D.OriginalW)+' x '+PENumber(D.OriginalH)+' px');
 PELabel(D.X+12,D.Y+242,'Echelle : '+STNumber(D.ScaledW*100.0/D.OriginalW)+' % x '+
                              STNumber(D.ScaledH*100.0/D.OriginalH)+' %');
 If D.KeepAspect Then S := 'Largeur et hauteur liees.'
 Else S := 'Largeur et hauteur independantes.';
 PELabel(D.X+12,D.Y+261,S);
 PELabel(D.X+12,D.Y+286,'REECHANTILLONNAGE');
 For I := 0 To 4 Do
  STDrawRadio(D.MethodRects[I],STMethodName(I),D.Method=I,D.Focus=7+I);
 PELabel(D.X+314,D.Y+32,'AVANT');
 PELabel(D.X+465,D.Y+32,'APRES');
 STDrawPreview(D,D.BeforeBox,False);
 STDrawPreview(D,D.AfterBox,True);
 PELabel(D.X+314,D.Y+186,PENumber(D.OriginalW)+'x'+PENumber(D.OriginalH)+' px');
 PELabel(D.X+465,D.Y+186,PENumber(D.ResultW)+'x'+PENumber(D.ResultH)+' px');
 STDrawEstimate(D);
 Case D.Method Of
  ST_NEAREST: Description := 'Pixels nets : dessins et pixel art.';
  ST_BILINEAR: Description := 'Lissage par melange des voisins.';
  ST_BICUBIC: Description := 'Lissage bicubique equilibre.';
  ST_SMOOTH: Description := 'Contours plus doux, moins d angles.';
  ST_SHARP: Description := 'Contours renforces, rendu plus net.';
 End;
 PELabel(D.X+314,D.Y+334,Description);
 PELabel(D.X+314,D.Y+353,'Image entiere ; 256 couleurs max.');
 PEButton(D.RefreshRect,'Actualiser',D.Focus=18);
 PEButton(D.ZeroAnglesRect,'Taille origine',D.Focus=17);
 PEButton(D.ApplyRect,'Appliquer',D.Focus=ST_FOCUS_APPLY);
 If Not D.ValidResult Or (D.FieldError>=0) Or Not STChanged(D) Then Begin
  PEFill(D.ApplyRect,LightGray);
  PEBevel(D.ApplyRect,False);
  SetColor(DarkGray);
  RFCenteredText(D.ApplyRect,D.ApplyRect.Top+8,'Appliquer');
 End;
 PEButton(D.CancelRect,'Annuler',D.Focus=ST_FOCUS_CANCEL);
 PEButton(D.ResetRect,'Reinitialiser',D.Focus=ST_FOCUS_RESET);
 PEButton(D.HelpRect,'Aide (F1)',D.Focus=ST_FOCUS_HELP);
 SetFillStyle(SolidFill,LightGray);
 Bar(0,ScreenHeight-STATUSBAR_HEIGHT,ScreenWidth-1,ScreenHeight-1);
 PELabel(5,ScreenHeight-STATUSBAR_HEIGHT+5,D.Status);
 PEShowMouse;
 D.Dirty := False;
End;


Procedure STDraw(Var D: TSTState);
Var
 R: TRect;
 I: Integer;
 S: String;
Begin
 If D.ResizeOnly Then Begin RDDraw(D); Exit; End;
 PEHideMouse;
 SetWriteMode(CopyPut);
 SetLineStyle(SolidLn,0,NormWidth);
 PERect(R,D.X,D.Y,620,440);
 PEFill(R,LightGray);
 PEBevel(R,False);
 SetFillStyle(SolidFill,Blue);
 Bar(D.X+3,D.Y+3,D.X+616,D.Y+21);
 SetColor(White);
 OutTextXY(D.X+9,D.Y+7,'Etirer / Incliner - PAINT');
 OutTextXY(D.X+602,D.Y+7,'X');
 PELabel(D.X+12,D.Y+32,'ETIREMENT');
 STDrawRadio(D.PercentRect,'Pourcentage',D.PercentUnits,D.Focus=4);
 STDrawRadio(D.PixelsRect,'Pixels',Not D.PercentUnits,D.Focus=5);
 For I := 0 To 3 Do STDrawField(D,I);
 If D.KeepAspect Then S := '[x] ' Else S := '[ ] ';
 PELabel(D.LockRect.Left,D.LockRect.Top+4,S+'Conserver les proportions');
 If D.Focus=6 Then PEFocusRect(D.LockRect);
 PEButton(D.Presets[0],'25 %',D.Focus=13);
 PEButton(D.Presets[1],'50 %',D.Focus=14);
 PEButton(D.Presets[2],'100 %',D.Focus=15);
 PEButton(D.Presets[3],'200 %',D.Focus=16);
 PELabel(D.X+12,D.Y+198,'INCLINAISON (degres, -89 a +89)');
 PELabel(D.X+12,D.Y+286,'REECHANTILLONNAGE');
 For I := 0 To 4 Do
  STDrawRadio(D.MethodRects[I],STMethodName(I),D.Method=I,D.Focus=7+I);
 PELabel(D.X+314,D.Y+32,'AVANT');
 PELabel(D.X+465,D.Y+32,'APRES');
 STDrawPreview(D,D.BeforeBox,False);
 STDrawPreview(D,D.AfterBox,True);
 PELabel(D.X+314,D.Y+186,PENumber(D.OriginalW)+'x'+PENumber(D.OriginalH)+' px');
 PELabel(D.X+465,D.Y+186,PENumber(D.ResultW)+'x'+PENumber(D.ResultH)+' px');
 STDrawEstimate(D);
 If D.ExpandCanvas Then S := '[x] ' Else S := '[ ] ';
 PELabel(D.ExpandRect.Left,D.ExpandRect.Top+4,S+'Agrandir pour tout conserver');
 If D.Focus=12 Then PEFocusRect(D.ExpandRect);
 PELabel(D.X+314,D.Y+353,'Fond : couleur d arriere-plan');
 PEButton(D.RefreshRect,'Actualiser',D.Focus=18);
 PEButton(D.ZeroAnglesRect,'Angles a zero',D.Focus=17);
 PEButton(D.ApplyRect,'Appliquer',D.Focus=ST_FOCUS_APPLY);
 If Not D.ValidResult Or (D.FieldError>=0) Or Not STChanged(D) Then Begin
  PEFill(D.ApplyRect,LightGray); PEBevel(D.ApplyRect,False);
  SetColor(DarkGray); RFCenteredText(D.ApplyRect,D.ApplyRect.Top+8,'Appliquer');
 End;
 PEButton(D.CancelRect,'Annuler',D.Focus=ST_FOCUS_CANCEL);
 PEButton(D.ResetRect,'Reinitialiser',D.Focus=ST_FOCUS_RESET);
 PEButton(D.HelpRect,'Aide (F1)',D.Focus=ST_FOCUS_HELP);
 SetFillStyle(SolidFill,LightGray);
 Bar(0,ScreenHeight-STATUSBAR_HEIGHT,ScreenWidth-1,ScreenHeight-1);
 PELabel(5,ScreenHeight-STATUSBAR_HEIGHT+5,D.Status);
 PEShowMouse;
 D.Dirty := False;
End;

Procedure STReset(Var D: TSTState);
Begin
 D.ScaledW := D.OriginalW;
 D.ScaledH := D.OriginalH;
 D.SkewX := 0; D.SkewY := 0;
 D.PercentUnits := True;
 D.KeepAspect := True;
 D.ExpandCanvas := True;
 D.Method := ST_NEAREST;
 D.FieldError := -1;
 STSyncFields(D);
 STUpdateGeometry(D);
End;

Procedure STInitialize(Var D: TSTState);
Begin
 FillChar(D,SizeOf(D),0);
 PEInitialize(D.PaletteData);
 D.OriginalW := CanvasImageW;
 D.OriginalH := CanvasImageH;
 STLayout(D);
 STReset(D);
 D.FieldSelected := True;
 GetMouseStateLocal(D.MX,D.MY,D.PreviousButtons);
End;

Procedure STHelp(Var D: TSTState);
Begin
 If D.ResizeOnly Then Begin
  ShowMessage('Aide - Redimensionner',
   'Horizontal = largeur ; vertical = hauteur.'+#10+
   '100 % conserve la taille ; 200 % la double.'+#10+
   'Proportions liees : modifier une seule dimension.'+#10+
   'Choisissez le lissage et comparez les apercus.'+#10+
   'Appliquer valide ; Echap annule ; Ctrl+Z ensuite.');
  D.Dirty := True;
  Exit;
 End;
 ShowMessage('Aide - Etirer / Incliner',
  'Pourcentage : 100 = taille originale ; 200 = double.'+#10+
  'Pixels : largeur et hauteur exactes avant inclinaison.'+#10+
  'Angles : deformation horizontale / verticale.'+#10+
  'Plus proche : pixels nets ; autres : lissage RVB.'+#10+
  'Sortie indexee : 256 couleurs. Echap annule.');
 D.Dirty := True;
End;

Procedure STStepField(Var D: TSTState; Index, Delta: Integer);
Var
 Value: Real;
Begin
 If Not STParseNumber(D.Fields[Index],Value) Then Value := 0;
 Value := Value+Delta;
 If Index<2 Then Begin
  If D.PercentUnits Then Begin
   If Value<1 Then Value := 1;
   If Value>409600 Then Value := 409600;
  End
  Else Value := PEClamp(Round(Value),1,4096);
 End
 Else Value := PEClamp(Round(Value),-89,89);
 D.Fields[Index] := STNumber(Value);
 D.Focus := Index;
 D.FieldSelected := True;
 If STValidateField(D,Index) Then STSyncFields(D);
End;

Procedure STActivate(Var D: TSTState; Action: Integer);
Var
 Percent: Integer;
 NewW, NewH: LongInt;
Begin
 If Action=ST_FOCUS_CANCEL Then Begin D.Done := True; D.Accepted := False; Exit; End;
 If Action=ST_FOCUS_RESET Then Begin STReset(D); Exit; End;
 If Action=ST_FOCUS_HELP Then Begin STHelp(D); Exit; End;
 If Not STLeaveField(D) Then Exit;
 D.Focus := Action;
 Case Action Of
  4,5: Begin D.PercentUnits := Action=4; STSyncFields(D); D.Dirty := True; End;
  6: Begin
   D.KeepAspect := Not D.KeepAspect;
   If D.KeepAspect Then Begin
    D.Fields[0] := STNumber(D.ScaledW);
    If D.PercentUnits Then D.Fields[0] := STNumber(D.ScaledW*100.0/D.OriginalW);
    If STValidateField(D,0) Then STSyncFields(D);
   End;
   D.Dirty := True;
  End;
  7..11: Begin D.Method := Action-7; D.Dirty := True; End;
  12: Begin D.ExpandCanvas := Not D.ExpandCanvas; STUpdateGeometry(D); End;
  13..16: Begin
   Case Action Of
    13: Percent := 25;
    14: Percent := 50;
    15: Percent := 100;
   Else Percent := 200;
   End;
   NewW := Round(D.OriginalW*Percent/100.0);
   NewH := Round(D.OriginalH*Percent/100.0);
   If NewW<1 Then NewW := 1;
   If NewH<1 Then NewH := 1;
   If (NewW>4096) Or (NewH>4096) Then Begin
    D.Status := 'Ce prereglage depasse 4096 pixels. Les dimensions restent inchangees.';
    D.Dirty := True;
    Exit;
   End;
   D.ScaledW := NewW;
   D.ScaledH := NewH;
   STSyncFields(D); STUpdateGeometry(D);
  End;
  17: Begin
   D.SkewX := 0; D.SkewY := 0;
   If D.ResizeOnly Then Begin
    D.ScaledW := D.OriginalW;
    D.ScaledH := D.OriginalH;
   End;
   STSyncFields(D); STUpdateGeometry(D);
  End;
  18: Begin STUpdateGeometry(D); D.Dirty := True; End;
  ST_FOCUS_APPLY: If D.ValidResult And (D.FieldError<0) And STChanged(D) Then Begin
   D.Accepted := True; D.Done := True;
  End;
 End;
End;

Procedure STSetFocus(Var D: TSTState; Focus: Integer);
Begin
 If Not STLeaveField(D) Then Exit;
 D.Focus := Focus;
 D.FieldSelected := Focus<ST_FIELD_COUNT;
 D.Dirty := True;
End;

Procedure STFieldKey(Var D: TSTState; K: Char);
Var
 S: String;
 Allowed: Boolean;
Begin
 If D.Focus>=ST_FIELD_COUNT Then Exit;
 S := D.Fields[D.Focus];
 If K=#1 Then Begin D.FieldSelected := True; D.Dirty := True; Exit; End;
 If K=#8 Then Begin
  If D.FieldSelected Then S := ''
  Else If Length(S)>0 Then Delete(S,Length(S),1);
 End
 Else Begin
  Allowed := (K>='0') And (K<='9');
  If D.PercentUnits And (D.Focus<2) And ((K='.') Or (K=',')) Then
   Allowed := (Pos('.',S)=0) And (Pos(',',S)=0) Or D.FieldSelected;
  If (D.Focus>=2) And (K='-') Then Allowed := (Length(S)=0) Or D.FieldSelected;
  If Not Allowed Then Exit;
  If D.FieldSelected Then S := '';
  If Length(S)<9 Then S := S+K;
 End;
 D.Fields[D.Focus] := S;
 D.FieldSelected := False;
 D.FieldError := -1;
 If Not STValidateField(D,D.Focus) Then D.Dirty := True;
End;

Function STNextFocus(Const D: TSTState; Backwards: Boolean): Integer;
Var
 Next: Integer;
Begin
 Next := D.Focus;
 Repeat
  If Backwards Then Dec(Next) Else Inc(Next);
  If Next<0 Then Next := ST_FOCUS_HELP;
  If Next>ST_FOCUS_HELP Then Next := 0;
 Until Not D.ResizeOnly Or ((Next<>2) And (Next<>3) And (Next<>12));
 STNextFocus := Next;
End;

Procedure STKeyboard(Var D: TSTState);
Var
 K: Char;
 Next: Integer;
Begin
 K := ReadKey;
 If K=#0 Then Begin
  K := ReadKey;
  Case Ord(K) Of
   15: Begin Next := STNextFocus(D,True); STSetFocus(D,Next); End;
   59: STHelp(D);
   72,80,73,81: If D.Focus<ST_FIELD_COUNT Then Begin
    Case Ord(K) Of
     72: STStepField(D,D.Focus,1);
     80: STStepField(D,D.Focus,-1);
     73: STStepField(D,D.Focus,10);
     81: STStepField(D,D.Focus,-10);
    End;
   End;
   83: If D.Focus<ST_FIELD_COUNT Then Begin
    D.Fields[D.Focus] := ''; D.FieldSelected := False; D.Dirty := True;
   End;
  End;
  Exit;
 End;
 Case K Of
  #27: STActivate(D,ST_FOCUS_CANCEL);
  #9: STSetFocus(D,STNextFocus(D,False));
  #13: If D.Focus<ST_FIELD_COUNT Then Begin
   If STLeaveField(D) Then STSetFocus(D,ST_FOCUS_APPLY);
  End Else If D.Focus>=ST_FOCUS_APPLY Then STActivate(D,D.Focus)
  Else STActivate(D,ST_FOCUS_APPLY);
  ' ': If D.Focus>=ST_FIELD_COUNT Then STActivate(D,D.Focus);
 Else STFieldKey(D,K);
 End;
End;

Procedure STMouse(Var D: TSTState);
Var
 I: Integer;
Begin
 GetMouseStateLocal(D.MX,D.MY,D.MB);
 If ((D.MB And 1)<>0) And ((D.PreviousButtons And 1)=0) Then Begin
  If ((D.MX>=D.X+596) And (D.MX<=D.X+617) And
      (D.MY>=D.Y+3) And (D.MY<=D.Y+21)) Or
     PEInside(D.MX,D.MY,D.CancelRect) Then STActivate(D,ST_FOCUS_CANCEL)
  Else If PEInside(D.MX,D.MY,D.ResetRect) Then STActivate(D,ST_FOCUS_RESET)
  Else If PEInside(D.MX,D.MY,D.HelpRect) Then STActivate(D,ST_FOCUS_HELP)
  Else If PEInside(D.MX,D.MY,D.ApplyRect) Then STActivate(D,ST_FOCUS_APPLY)
  Else If PEInside(D.MX,D.MY,D.PercentRect) Then STActivate(D,4)
  Else If PEInside(D.MX,D.MY,D.PixelsRect) Then STActivate(D,5)
  Else If PEInside(D.MX,D.MY,D.LockRect) Then STActivate(D,6)
  Else If PEInside(D.MX,D.MY,D.ExpandRect) Then STActivate(D,12)
  Else If PEInside(D.MX,D.MY,D.RefreshRect) Then STActivate(D,18)
  Else If PEInside(D.MX,D.MY,D.ZeroAnglesRect) Then STActivate(D,17)
  Else Begin
   For I := 0 To 3 Do Begin
    If PEInside(D.MX,D.MY,D.FieldRects[I]) Then STSetFocus(D,I);
    If PEInside(D.MX,D.MY,D.MinusRects[I]) Then STStepField(D,I,-1);
    If PEInside(D.MX,D.MY,D.PlusRects[I]) Then STStepField(D,I,1);
    If PEInside(D.MX,D.MY,D.Presets[I]) Then STActivate(D,13+I);
   End;
   For I := 0 To 4 Do
    If PEInside(D.MX,D.MY,D.MethodRects[I]) Then STActivate(D,7+I);
  End;
 End;
 D.PreviousButtons := D.MB;
End;

Procedure StretchSkewDialog;
Var
 D: TSTState;
 Applied: Boolean;
Begin
 If Not PGHasImage Then Begin ShowMessage('Etirer / Incliner','Aucune image a transformer.'); Exit; End;
 MenuActive := False;
 RedrawInterface;
 STInitialize(D);
 PEHideMouse; PEBuildDisplayPalette; PEShowMouse;
 While Not D.Done Do Begin
  If D.Dirty Then STDraw(D);
  If KeyPressed Then STKeyboard(D);
  If Not D.Done Then STMouse(D);
  Delay(10);
 End;
 PEHideMouse; PERestoreHardware(D.PaletteData); PEShowMouse;
 If D.Accepted Then Begin
  Applied := STApply(D,True);
  If Not Applied Then ShowMessage('Etirer / Incliner',
   'Operation annulee ou memoire insuffisante. Le dessin original est conserve.');
 End;
 Repeat
  GetMouseStateLocal(D.MX,D.MY,D.MB);
  If (D.MB And 1)<>0 Then Delay(10);
 Until (D.MB And 1)=0;
 OldMouseButtons := 0; MouseButtons := 0;
 RedrawInterface;
End;


{ Dialogue dedie au redimensionnement. Les filtres, la validation des
  dimensions, les apercus et l'application transactionnelle sont partages
  avec Etirer/Incliner ; aucun angle n'est expose dans ce dialogue. }

Procedure RDLayout(Var D: TSTState);
Var
 I: Integer;
Begin
 STLayout(D);
 For I := 2 To 3 Do Begin
  PERect(D.FieldRects[I],-1000,-1000,1,1);
  PERect(D.MinusRects[I],-1000,-1000,1,1);
  PERect(D.PlusRects[I],-1000,-1000,1,1);
 End;
 PERect(D.ExpandRect,-1000,-1000,1,1);
End;

Procedure RDInitialize(Var D: TSTState);
Begin
 STInitialize(D);
 D.ResizeOnly := True;
 RDLayout(D);
 D.Status := 'Pourcentage ou pixels : ajustez largeur et hauteur, puis cliquez Appliquer.';
End;

Procedure ResizeImageDialog;
Var
 D: TSTState;
 Applied: Boolean;
Begin
 If Not PGHasImage Then Begin
  ShowMessage('Redimensionner','Aucune image a redimensionner.');
  Exit;
 End;
 MenuActive := False;
 RedrawInterface;
 RDInitialize(D);
 PEHideMouse;
 PEBuildDisplayPalette;
 PEShowMouse;
 While Not D.Done Do Begin
  If D.Dirty Then STDraw(D);
  If KeyPressed Then STKeyboard(D);
  If Not D.Done Then STMouse(D);
  Delay(10);
 End;
 PEHideMouse;
 PERestoreHardware(D.PaletteData);
 PEShowMouse;
 If D.Accepted Then Begin
  Applied := STApply(D,True);
  If Not Applied Then
   ShowMessage('Redimensionner',
    'Operation annulee ou memoire insuffisante. L image originale est conservee.');
 End;
 Repeat
  GetMouseStateLocal(D.MX,D.MY,D.MB);
  If (D.MB And 1)<>0 Then Delay(10);
 Until (D.MB And 1)=0;
 OldMouseButtons := 0;
 MouseButtons := 0;
 RedrawInterface;
End;


Procedure ZSetZoom(NewLevel, AnchorX, AnchorY: Integer);
Var ImageX,ImageY: Integer;
Begin
 If Drawing Then Exit;
 ImageX:=ZScreenX(AnchorX);
 ImageY:=ZScreenY(AnchorY);
 If NewLevel<25 Then NewLevel:=25;
 If NewLevel>800 Then NewLevel:=800;
 If NewLevel=ZoomLevel Then Exit;
 ZoomLevel:=NewLevel;
 ZOriginX:=ImageX-(LongInt(AnchorX-CanvasX)*100) Div ZoomLevel;
 ZOriginY:=ImageY-(LongInt(AnchorY-CanvasY)*100) Div ZoomLevel;
 ZClampView;
 TextPrevW:=0; TextPrevH:=0;
 RedrawInterface;
 If TextInsertMode Then DrawTextPreview;
End;

Procedure ZZoomStep(ZoomIn: Boolean);
Var Level: Integer;
Begin
 Level:=ZoomLevel;
 If ZoomIn Then Level:=Level*2 Else Level:=Level Div 2;
 ZSetZoom(Level,CanvasX+ZDisplayWidth Div 2,CanvasY+ZDisplayHeight Div 2);
End;

Procedure ZPan(DX,DY: Integer);
Begin
 If Drawing Then Exit;
 ZOriginX:=ZOriginX+DX; ZOriginY:=ZOriginY+DY;
 ZClampView;
 TextPrevW:=0; TextPrevH:=0;
 RedrawInterface;
 If TextInsertMode Then DrawTextPreview;
End;


{ Attributs du document : lecture du buffer image, jamais des pixels du
  dialogue. Les tailles de fichier, de stockage estime et de memoire sont
  distinguees. Seul le bouton Redimensionner ouvre une operation d'edition. }

Const
 AP_TAB_COUNT = 4;
 AP_BUTTON_COUNT = 6;
 AP_CHART_COUNT = 9;

Type
 TAPReport = Record
  Count: Integer;
  Lines: Array[0..63] of String[160];
 End;
 TAPChart = Record
  Count: Integer;
  Values: Array[0..AP_CHART_COUNT-1] of LongInt;
  Labels: Array[0..AP_CHART_COUNT-1] of String[24];
  Colors: Array[0..AP_CHART_COUNT-1] of TRGBColor;
  Total: LongInt;
 End;
 TAPState = Record
  X,Y,Tab,Focus,SelectedColor: Integer;
  Tabs: Array[0..AP_TAB_COUNT-1] of TRect;
  Buttons: Array[0..AP_BUTTON_COUNT-1] of TRect;
  Colors: TAPChart;
  Memory: TAPChart;
  PixelCount,PixelBytes,PaletteBytes,MetadataBytes: LongInt;
  UndoBytes,RedoBytes,TotalBytes,DiskBytes: LongInt;
  UsedIndices,DistinctColors: Integer;
  MeanColor: TRGBColor;
  MinLight,MaxLight: Integer;
  HasDiskFile: Boolean;
  FileDate: String[32];
  SavedPalette: TPalette;
  Histogram: TPGHistogram;
  Status: String[77];
  Done,Dirty: Boolean;
  MX,MY,MB,PreviousButtons: Integer;
 End;

Function APFormatName(Format: Byte): String;
Begin
 Case Format Of
  FMT_BMP: APFormatName:='BMP';
  FMT_GIF: APFormatName:='GIF';
  FMT_PNG: APFormatName:='PNG';
  FMT_JPEG: APFormatName:='JPEG';
  FMT_PCX: APFormatName:='PCX';
  FMT_TARGA: APFormatName:='TGA';
  FMT_TIFF: APFormatName:='TIFF';
  FMT_XBM: APFormatName:='XBM';
  FMT_WPG: APFormatName:='WPG';
  FMT_LBM: APFormatName:='LBM/IFF';
  FMT_HDR: APFormatName:='HDR/RGBE';
  FMT_FAX: APFormatName:='FAX G3 1D';
  FMT_EXR: APFormatName:='OpenEXR';
  FMT_DNG: APFormatName:='DNG Bayer';
  FMT_BGX: APFormatName:='BGX MonsterBook';
  FMT_DDS: APFormatName:='DDS';
  FMT_DCM: APFormatName:='DICOM';
  FMT_APNG: APFormatName:='APNG (premiere trame)';
  FMT_ARW: APFormatName:='ARW Bayer';
  FMT_CR2: APFormatName:='CR2 Bayer';
  FMT_PPM: APFormatName:='PPM / Netpbm';
  FMT_DIB: APFormatName:='DIB';
  FMT_CUR: APFormatName:='CUR Windows';
  FMT_ICO: APFormatName:='ICO Icone Windows';
  FMT_MSP: APFormatName:='MSP Microsoft Paint';
  FMT_MAC: APFormatName:='MAC MacPaint';
  FMT_PAS: APFormatName:='PAS constantes Pascal';
 Else APFormatName:='Non renseigne';
 End;
End;

Function APPercent(Part,Total: LongInt): String;
Var S:String; I:Integer;
Begin
 If Total<=0 Then S:='0,0'
 Else Begin
  Str(Part*100.0/Total:0:1,S);
  For I:=1 To Length(S) Do If S[I]='.' Then S[I]:=',';
 End;
 APPercent:=S+' %';
End;

Function APTwoDigits(N:Integer):String;
Var S:String;
Begin
 Str(N,S);
 If Length(S)<2 Then S:='0'+S;
 APTwoDigits:=S;
End;

Function APHistoryBytes(Item:PHistoryItem):LongInt;
Var Total:LongInt; Data:PHistoryData;
Begin
 Total:=0;
 While Item<>Nil Do Begin
  Total:=Total+SizeOf(THistoryItem);
  Data:=PHistoryData(Item^.Data);
  If Data<>Nil Then Begin
   Total:=Total+SizeOf(THistoryData);
   If Data^.PixelData<>Nil Then Total:=Total+Data^.DataSize;
  End;
  Item:=Item^.Next;
 End;
 APHistoryBytes:=Total;
End;

Function APBMPEstimate(W,H,Bits:Integer):LongInt;
Var Row,PaletteSize:LongInt;
Begin
 PaletteSize:=0;
 If Bits<=8 Then PaletteSize:=(LongInt(1) Shl Bits)*4;
 Row:=((LongInt(W)*Bits+31) Div 32)*4;
 APBMPEstimate:=54+PaletteSize+Row*H;
End;

Procedure APClearChart(Var C:TAPChart);
Begin FillChar(C,SizeOf(C),0); End;

Procedure APAddChart(Var C:TAPChart; const LabelText:String;
                      Value:LongInt; const Color:TRGBColor);
Begin
 If (C.Count>=AP_CHART_COUNT) Or (Value<0) Then Exit;
 C.Labels[C.Count]:=LabelText;
 C.Values[C.Count]:=Value;
 C.Colors[C.Count]:=Color;
 C.Total:=C.Total+Value;
 Inc(C.Count);
End;

Procedure APReadFile(Var D:TAPState);
Var Info:SearchRec; Stamp:DateTime;
Begin
 D.HasDiskFile:=False;
 D.DiskBytes:=0;
 D.FileDate:='Non disponible';
 If ImageBuffer.FileName='' Then Exit;
 FindFirst(ImageBuffer.FileName,AnyFile,Info);
 If DosError<>0 Then Exit;
 If (Info.Attr And Directory)<>0 Then Exit;
 D.HasDiskFile:=True;
 D.DiskBytes:=Info.Size;
 UnpackTime(Info.Time,Stamp);
 D.FileDate:=APTwoDigits(Stamp.Day)+'/'+APTwoDigits(Stamp.Month)+'/'+
             IntToStr(Stamp.Year)+' '+APTwoDigits(Stamp.Hour)+':'+APTwoDigits(Stamp.Min);
End;

Procedure APRefresh(Var D:TAPState);
Var
 Work:TPGState;
 I,J,Light:Integer;
 Duplicate:Boolean;
 SumR,SumG,SumB:Real;
 Counted:LongInt;
Begin
 D.SavedPalette:=ImageBuffer.Palette;
 FillChar(Work,SizeOf(Work),0);
 Work.Source:=0;
 PGHistogram(Work);
 D.Histogram:=Work.Histogram;
 D.PixelCount:=Work.TotalPixels;
 D.PixelBytes:=0;
 If PGHasImage Then D.PixelBytes:=LongInt(CanvasImageW)*CanvasImageH;
 D.PaletteBytes:=SizeOf(TPalette);
 D.MetadataBytes:=SizeOf(TImageBuffer)-SizeOf(TPalette);
 D.UndoBytes:=APHistoryBytes(UndoList);
 D.RedoBytes:=APHistoryBytes(RedoList);
 D.TotalBytes:=D.PixelBytes+D.PaletteBytes+D.MetadataBytes+D.UndoBytes+D.RedoBytes;
 D.UsedIndices:=0;
 D.DistinctColors:=0;
 D.MinLight:=255;
 D.MaxLight:=0;
 SumR:=0; SumG:=0; SumB:=0;
 For I:=0 To 255 Do
  If D.Histogram[I]>0 Then Begin
   Inc(D.UsedIndices);
   SumR:=SumR+ImageBuffer.Palette[I].R*1.0*D.Histogram[I];
   SumG:=SumG+ImageBuffer.Palette[I].G*1.0*D.Histogram[I];
   SumB:=SumB+ImageBuffer.Palette[I].B*1.0*D.Histogram[I];
   Light:=PGBrightness(ImageBuffer.Palette[I]) Div 1000;
   D.MinLight:=Min(D.MinLight,Light);
   D.MaxLight:=Max(D.MaxLight,Light);
   Duplicate:=False;
   For J:=0 To I-1 Do
    If (D.Histogram[J]>0) And PESameColor(ImageBuffer.Palette[I],ImageBuffer.Palette[J]) Then
     Duplicate:=True;
   If Not Duplicate Then Inc(D.DistinctColors);
  End;
 D.MeanColor:=PERGB(0,0,0);
 If D.PixelCount>0 Then
  D.MeanColor:=PERGB(Round(SumR/D.PixelCount),Round(SumG/D.PixelCount),Round(SumB/D.PixelCount))
 Else D.MinLight:=0;
 APClearChart(D.Colors);
 Counted:=0;
 For I:=0 To Min(Work.DominantCount,8)-1 Do Begin
  J:=Work.DominantIndices[I];
  APAddChart(D.Colors,'#'+PEHexColor(ImageBuffer.Palette[J]),
             Work.DominantCounts[I],ImageBuffer.Palette[J]);
  Counted:=Counted+Work.DominantCounts[I];
 End;
 If Counted<D.PixelCount Then
  APAddChart(D.Colors,'Autres couleurs',D.PixelCount-Counted,PERGB(168,168,168));
 APClearChart(D.Memory);
 APAddChart(D.Memory,'Pixels',D.PixelBytes,PERGB(32,128,240));
 APAddChart(D.Memory,'Palette',D.PaletteBytes,PERGB(32,192,96));
 APAddChart(D.Memory,'Metadonnees',D.MetadataBytes,PERGB(240,192,32));
 APAddChart(D.Memory,'Annuler',D.UndoBytes,PERGB(208,80,208));
 APAddChart(D.Memory,'Retablir',D.RedoBytes,PERGB(240,112,48));
 APReadFile(D);
 D.SelectedColor:=PEClamp(D.SelectedColor,0,Max(0,D.Colors.Count-1));
 D.Status:='Attributs calcules sur l image entiere, independamment du zoom.';
 D.Dirty:=True;
End;

Procedure APRestorePalette(Const D:TAPState);
Var I:Integer;
Begin
 For I:=16 To Min(GetMaxColor,255) Do PESetHardwareColor(I,D.SavedPalette[I]);
End;

Procedure APLayout(Var D:TAPState);
Var I:Integer;
Begin
 D.X:=(ScreenWidth-620) Div 2;
 D.Y:=(ScreenHeight-440) Div 2;
 For I:=0 To AP_TAB_COUNT-1 Do PERect(D.Tabs[I],D.X+12+I*150,D.Y+32,144,25);
 PERect(D.Buttons[0],D.X+12,D.Y+406,84,25);
 PERect(D.Buttons[1],D.X+104,D.Y+406,128,25);
 PERect(D.Buttons[2],D.X+240,D.Y+406,96,25);
 PERect(D.Buttons[3],D.X+344,D.Y+406,72,25);
 PERect(D.Buttons[4],D.X+424,D.Y+406,80,25);
 PERect(D.Buttons[5],D.X+512,D.Y+406,90,25);
End;

Procedure APKeyValue(X,Y:Integer; const LabelText,Value:String);
Begin
 PELabel(X,Y,LabelText);
 PELabel(X+186,Y,Value);
End;

Procedure APPreview(Const R:TRect);
Var Inner:TRect; W,H,X,Y,SX,SY,Left,Top:Integer; C:TRGBColor;
Begin
 Inner:=R;
 Inc(Inner.Left,2); Inc(Inner.Top,2); Dec(Inner.Right,2); Dec(Inner.Bottom,2);
 RFChecker(Inner);
 PEBevel(R,True);
 If Not PGHasImage Then Exit;
 RFFitSize(CanvasImageW,CanvasImageH,R.Right-R.Left-7,R.Bottom-R.Top-7,W,H);
 Left:=R.Left+(R.Right-R.Left+1-W) Div 2;
 Top:=R.Top+(R.Bottom-R.Top+1-H) Div 2;
 For Y:=0 To H-1 Do
  For X:=0 To W-1 Do Begin
   SX:=(LongInt(X)*CanvasImageW) Div W;
   SY:=(LongInt(Y)*CanvasImageH) Div H;
   If PGReadRGB(SX,SY,C) Then PutPixel(Left+X,Top+Y,PEDisplayColor(C));
  End;
End;

Function APSectorAt(Const C:TAPChart; Angle:Real):Integer;
Var I:Integer; Sum:LongInt;
Begin
 APSectorAt:=-1;
 If C.Total<=0 Then Exit;
 Sum:=0;
 For I:=0 To C.Count-1 Do Begin
  Sum:=Sum+C.Values[I];
  If Angle<Sum*360.0/C.Total Then Begin APSectorAt:=I; Exit; End;
 End;
 APSectorAt:=C.Count-1;
End;

Function APAngle(DX,DY:Integer):Real;
Var A:Real;
Begin
 If DX=0 Then Begin
  If DY>=0 Then A:=90 Else A:=270;
 End
 Else Begin
  A:=ArcTan(DY*1.0/DX)*180/ST_PI;
  If DX<0 Then A:=A+180;
  If A<0 Then A:=A+360;
 End;
 APAngle:=A;
End;

Procedure APPie(const C:TAPChart; CX,CY,Radius:Integer);
Var X,Y,Index:Integer;
Begin
 If C.Total<=0 Then Begin
  SetColor(DarkGray); Circle(CX,CY,Radius);
  PELabel(CX-48,CY-4,'Aucune donnee');
  Exit;
 End;
 For Y:=-Radius To Radius Do
  For X:=-Radius To Radius Do
   If LongInt(X)*X+LongInt(Y)*Y<=LongInt(Radius)*Radius Then Begin
    Index:=APSectorAt(C,APAngle(X,-Y));
    If Index>=0 Then PutPixel(CX+X,CY+Y,PEDisplayColor(C.Colors[Index]));
   End;
 SetColor(Black); Circle(CX,CY,Radius);
End;

Procedure APBars(Const C:TAPChart; X,Y,Step,BarW:Integer; MemoryUnits:Boolean; Selected:Integer);
Var I,W:Integer; Largest:LongInt; R:TRect; S:String;
Begin
 { Une bande complete represente 100 % du total, comme le camembert. }
 Largest:=C.Total;
 For I:=0 To C.Count-1 Do Begin
  S:=C.Labels[I];
  If Length(S)>13 Then S:=Copy(S,1,12)+'.';
  PELabel(X,Y+I*Step,S);
  PERect(R,X+112,Y+I*Step-2,BarW,13);
  PEFill(R,White); PEBevel(R,True);
  W:=0;
  If Largest>0 Then W:=Round((BarW-4)*1.0*C.Values[I]/Largest);
  If W>0 Then Begin
   SetFillStyle(SolidFill,PEDisplayColor(C.Colors[I]));
   Bar(R.Left+2,R.Top+2,R.Left+1+W,R.Bottom-2);
  End;
  If MemoryUnits Then S:=STMemoryText(C.Values[I]) Else S:=APPercent(C.Values[I],C.Total);
  PELabel(R.Right+10,Y+I*Step,S);
  If I=Selected Then Begin
   SetColor(Black); SetLineStyle(DottedLn,0,NormWidth);
   Rectangle(X-3,Y+I*Step-5,R.Right+79,Y+I*Step+12);
   SetLineStyle(SolidLn,0,NormWidth);
  End;
 End;
End;

Procedure APDrawSummary(Const D:TAPState);
Var R:TRect; S:String;
Begin
 APKeyValue(D.X+20,D.Y+80,'Dimensions',IntToStr(CanvasImageW)+' x '+IntToStr(CanvasImageH)+' px');
 APKeyValue(D.X+20,D.Y+103,'Nombre de pixels',IntToStr(D.PixelCount));
 APKeyValue(D.X+20,D.Y+126,'Couleurs distinctes',IntToStr(D.DistinctColors));
 APKeyValue(D.X+20,D.Y+149,'Indices utilises',IntToStr(D.UsedIndices)+' / 256');
 APKeyValue(D.X+20,D.Y+172,'Profondeur declaree',IntToStr(ImageBuffer.BitDepth)+' bits');
 APKeyValue(D.X+20,D.Y+195,'Buffer de pixels',STMemoryText(D.PixelBytes));
 APKeyValue(D.X+20,D.Y+218,'Palette',STMemoryText(D.PaletteBytes));
 APKeyValue(D.X+20,D.Y+241,'Format indique',APFormatName(ImageBuffer.Format));
 APKeyValue(D.X+20,D.Y+264,'Zoom de la vue',IntToStr(ZoomLevel)+' %');
 If ImageBuffer.Modified Then S:='Modifiee' Else S:='Non modifiee';
 APKeyValue(D.X+20,D.Y+287,'Image en memoire',S);
 PELabel(D.X+366,D.Y+65,'APERCU DE L IMAGE');
 PERect(R,D.X+366,D.Y+82,230,146); APPreview(R);
 If SelectionActive Then Begin
  S:=IntToStr(Abs(SelectionRect.Right-SelectionRect.Left)+1)+' x '+
     IntToStr(Abs(SelectionRect.Bottom-SelectionRect.Top)+1)+' px';
  PELabel(D.X+366,D.Y+246,'Selection : '+S);
 End
 Else PELabel(D.X+366,D.Y+246,'Selection : aucune');
 PELabel(D.X+366,D.Y+267,'Moyenne : #'+PEHexColor(D.MeanColor));
 PERect(R,D.X+20,D.Y+325,576,58); PEBevel(R,True);
 PELabel(R.Left+10,R.Top+11,'Image + palette : '+STMemoryText(D.PixelBytes+D.PaletteBytes));
 PELabel(R.Left+10,R.Top+32,'Image et historique : '+STMemoryText(D.TotalBytes));
End;

Procedure APDrawColors(Const D:TAPState);
Var Index:Integer; S:String;
Begin
 PELabel(D.X+24,D.Y+73,'REPARTITION DES PIXELS');
 APPie(D.Colors,D.X+112,D.Y+164,72);
 PELabel(D.X+24,D.Y+255,IntToStr(D.DistinctColors)+' couleurs distinctes');
 PELabel(D.X+24,D.Y+277,IntToStr(D.UsedIndices)+' indices de palette');
 PELabel(D.X+24,D.Y+299,'Luminosite : '+IntToStr(D.MinLight)+' a '+IntToStr(D.MaxLight));
 PELabel(D.X+234,D.Y+73,'COULEURS DOMINANTES');
 APBars(D.Colors,D.X+234,D.Y+100,25,158,False,D.SelectedColor);
 Index:=D.SelectedColor;
 If (Index>=0) And (Index<D.Colors.Count) Then Begin
  S:=D.Colors.Labels[Index]+' : '+IntToStr(D.Colors.Values[Index])+' pixels';
  PELabel(D.X+24,D.Y+349,S);
  PELabel(D.X+24,D.Y+370,APPercent(D.Colors.Values[Index],D.PixelCount)+' de l image. Cliquez une bande pour le detail.');
 End;
End;

Procedure APDrawMemory(Const D:TAPState);
Const Depths:Array[0..4]of Integer=(1,4,8,24,32);
Var I:Integer;
Begin
 PELabel(D.X+24,D.Y+73,'IMAGE ET HISTORIQUE');
 APPie(D.Memory,D.X+112,D.Y+155,66);
 APBars(D.Memory,D.X+234,D.Y+99,28,142,True,-1);
 PELabel(D.X+24,D.Y+239,'Total estime : '+STMemoryText(D.TotalBytes));
 PELabel(D.X+24,D.Y+266,'ESTIMATIONS BMP NON COMPRESSE (palette + alignement inclus)');
 For I:=0 To 4 Do Begin
  PELabel(D.X+24,D.Y+290+I*18,IntToStr(Depths[I])+' bits / pixel');
  PELabel(D.X+210,D.Y+290+I*18,STMemoryText(APBMPEstimate(CanvasImageW,CanvasImageH,Depths[I])));
 End;
 PELabel(D.X+348,D.Y+296,'Le total inclut Annuler/Retablir.');
 PELabel(D.X+348,D.Y+319,'Hors moteur graphique et systeme.');
 PELabel(D.X+348,D.Y+350,'PNG/JPEG : taille variable selon');
 PELabel(D.X+348,D.Y+368,'le contenu et la compression.');
End;

Procedure APDrawFile(Const D:TAPState);
Var S,Part:String; Row,Start:Integer;
Begin
 PELabel(D.X+24,D.Y+76,'CHEMIN DU DOCUMENT');
 S:=ImageBuffer.FileName;
 If S='' Then S:='Sans titre - aucun fichier associe';
 Start:=1; Row:=0;
 Repeat
  Part:=Copy(S,Start,70);
  PELabel(D.X+24,D.Y+99+Row*17,Part);
  Inc(Start,70); Inc(Row);
 Until (Start>Length(S)) Or (Row=4);
 APKeyValue(D.X+24,D.Y+184,'Format indique',APFormatName(ImageBuffer.Format));
 If D.HasDiskFile Then S:=STMemoryText(D.DiskBytes)+' ('+IntToStr(D.DiskBytes)+' o)'
 Else S:='Non disponible';
 APKeyValue(D.X+24,D.Y+208,'Fichier sur disque',S);
 APKeyValue(D.X+24,D.Y+232,'Date du fichier',D.FileDate);
 If ImageBuffer.Modified Then S:='Modifications non enregistrees' Else S:='Aucune modification signalee';
 APKeyValue(D.X+24,D.Y+256,'Etat en memoire',S);
 If ImageBuffer.HasTransparency Then S:='Oui (metadonnees)' Else S:='Non';
 APKeyValue(D.X+24,D.Y+280,'Transparence declaree',S);
 APKeyValue(D.X+24,D.Y+304,'Dimensions declarees',IntToStr(ImageBuffer.Width)+' x '+IntToStr(ImageBuffer.Height));
 PELabel(D.X+24,D.Y+347,'La taille sur disque concerne la derniere version enregistree.');
 PELabel(D.X+24,D.Y+370,'Les estimations memoire ne sont pas des tailles de fichiers compresses.');
End;

Procedure APDraw(Var D:TAPState);
Const
 TabLabels:Array[0..3]of String[12]=('Resume','Couleurs','Memoire','Fichier');
 ButtonLabels:Array[0..5]of String[14]=('Fermer','Redimensionner','Actualiser','Copier','Exporter','Aide (F1)');
Var R:TRect; I:Integer;
Begin
 PEHideMouse;
 SetWriteMode(CopyPut); SetLineStyle(SolidLn,0,NormWidth);
 PERect(R,D.X,D.Y,620,440); PEFill(R,LightGray); PEBevel(R,False);
 SetFillStyle(SolidFill,Blue); Bar(D.X+3,D.Y+3,D.X+616,D.Y+21);
 SetColor(White); OutTextXY(D.X+9,D.Y+7,'Attributs de l image - PAINT');
 OutTextXY(D.X+602,D.Y+7,'X');
 For I:=0 To AP_TAB_COUNT-1 Do Begin
  PEButton(D.Tabs[I],TabLabels[I],D.Focus=I);
  If D.Tab=I Then Begin
   SetColor(Blue);
   Line(D.Tabs[I].Left+4,D.Tabs[I].Bottom-3,D.Tabs[I].Right-4,D.Tabs[I].Bottom-3);
  End;
 End;
 Case D.Tab Of
  0: APDrawSummary(D);
  1: APDrawColors(D);
  2: APDrawMemory(D);
  3: APDrawFile(D);
 End;
 For I:=0 To AP_BUTTON_COUNT-1 Do PEButton(D.Buttons[I],ButtonLabels[I],D.Focus=4+I);
 SetFillStyle(SolidFill,LightGray);
 Bar(0,ScreenHeight-STATUSBAR_HEIGHT,ScreenWidth-1,ScreenHeight-1);
 PELabel(5,ScreenHeight-STATUSBAR_HEIGHT+5,D.Status);
 PEShowMouse; D.Dirty:=False;
End;

Procedure APReportLine(Var Report:TAPReport; S:String);
Begin
 While (Length(S)>160) And (Report.Count<64) Do Begin
  Report.Lines[Report.Count]:=Copy(S,1,160); Inc(Report.Count);
  Delete(S,1,160);
 End;
 If Report.Count>=64 Then Exit;
 Report.Lines[Report.Count]:=S; Inc(Report.Count);
End;

Procedure APBuildReport(Const D:TAPState; Var Report:TAPReport);
Const Depths:Array[0..4]of Integer=(1,4,8,24,32);
Var I:Integer; S:String;
Begin
 FillChar(Report,SizeOf(Report),0);
 APReportLine(Report,'PAINT - Attributs de l image');
 S:=ImageBuffer.FileName; If S='' Then S:='Sans titre';
 APReportLine(Report,'Fichier :');
 APReportLine(Report,S);
 APReportLine(Report,'Format indique : '+APFormatName(ImageBuffer.Format));
 APReportLine(Report,'Dimensions : '+IntToStr(CanvasImageW)+' x '+IntToStr(CanvasImageH)+' pixels');
 APReportLine(Report,'Nombre de pixels : '+IntToStr(D.PixelCount));
 APReportLine(Report,'Profondeur declaree : '+IntToStr(ImageBuffer.BitDepth)+' bits');
 APReportLine(Report,'Buffer indexe : 8 bits par pixel');
 APReportLine(Report,'Couleurs distinctes : '+IntToStr(D.DistinctColors));
 APReportLine(Report,'Indices de palette utilises : '+IntToStr(D.UsedIndices));
 APReportLine(Report,'Couleur moyenne : #'+PEHexColor(D.MeanColor));
 APReportLine(Report,'Luminosite : '+IntToStr(D.MinLight)+' a '+IntToStr(D.MaxLight));
 APReportLine(Report,'Zoom de la vue : '+IntToStr(ZoomLevel)+' %');
 If ImageBuffer.Modified Then S:='oui' Else S:='non';
 APReportLine(Report,'Modifications non enregistrees : '+S);
 If ImageBuffer.HasTransparency Then S:='oui' Else S:='non';
 APReportLine(Report,'Transparence declaree : '+S);
 APReportLine(Report,'');
 APReportLine(Report,'MEMOIRE ESTIMEE (hors moteur graphique et systeme)');
 For I:=0 To D.Memory.Count-1 Do
  APReportLine(Report,D.Memory.Labels[I]+' : '+STMemoryText(D.Memory.Values[I])+ ' ('+IntToStr(D.Memory.Values[I])+' octets)');
 APReportLine(Report,'Total image et historique : '+STMemoryText(D.TotalBytes));
 If D.HasDiskFile Then Begin
  APReportLine(Report,'Fichier sur disque : '+STMemoryText(D.DiskBytes)+' ('+IntToStr(D.DiskBytes)+' octets)');
  APReportLine(Report,'Date du fichier : '+D.FileDate);
 End Else APReportLine(Report,'Fichier sur disque : non disponible');
 APReportLine(Report,'');
 APReportLine(Report,'ESTIMATIONS BMP NON COMPRESSE');
 For I:=0 To 4 Do
  APReportLine(Report,IntToStr(Depths[I])+' bits : '+STMemoryText(APBMPEstimate(CanvasImageW,CanvasImageH,Depths[I])));
 APReportLine(Report,'Palette et alignement des lignes inclus ; PNG/JPEG selon contenu et compression.');
 APReportLine(Report,'');
 APReportLine(Report,'COULEURS DOMINANTES');
 For I:=0 To D.Colors.Count-1 Do
  APReportLine(Report,D.Colors.Labels[I]+' : '+IntToStr(D.Colors.Values[I])+' pixels ; '+APPercent(D.Colors.Values[I],D.PixelCount));
End;

Function APCopyReport(Const Report:TAPReport):Boolean;
{$IFDEF WINDOWS}
Var Memory:TPaintWinHandle; Buffer:PChar; I,J:Integer; Bytes,Pos:LongInt;
Begin
 APCopyReport:=False;
 Bytes:=1;
 For I:=0 To Report.Count-1 Do Bytes:=Bytes+Length(Report.Lines[I])+2;
 If Not PaintWinOpenClipboard(0) Then Exit;
 Memory:=PaintWinGlobalAlloc(PAINT_GMEM_MOVEABLE,Bytes);
 If Memory=0 Then Begin PaintWinCloseClipboard; Exit; End;
 Buffer:=PChar(PaintWinGlobalLock(Memory));
 If Buffer=Nil Then Begin PaintWinGlobalFree(Memory); PaintWinCloseClipboard; Exit; End;
 Pos:=0;
 For I:=0 To Report.Count-1 Do Begin
  For J:=1 To Length(Report.Lines[I]) Do Begin Buffer[Pos]:=Report.Lines[I][J]; Inc(Pos); End;
  Buffer[Pos]:=#13; Inc(Pos); Buffer[Pos]:=#10; Inc(Pos);
 End;
 Buffer[Pos]:=#0;
 PaintWinGlobalUnlock(Memory);
 If PaintWinEmptyClipboard Then
  If PaintWinSetClipboardData(PAINT_CF_TEXT,Memory)<>0 Then Begin
   Memory:=0; APCopyReport:=True;
  End;
 If Memory<>0 Then PaintWinGlobalFree(Memory);
 PaintWinCloseClipboard;
End;
{$ELSE}
Begin APCopyReport:=False; End;
{$ENDIF}

Function APSaveReport(Const FileName:String; Const Report:TAPReport):Boolean;
Var F:Text; I,ErrorCode,CloseError:Integer;
Begin
 APSaveReport:=False;
 Assign(F,FileName); {$I-}Rewrite(F);{$I+}
 If IOResult<>0 Then Exit;
 ErrorCode:=0;
 For I:=0 To Report.Count-1 Do Begin
  {$I-}WriteLn(F,Report.Lines[I]);{$I+}
  ErrorCode:=IOResult;
  If ErrorCode<>0 Then Break;
 End;
 {$I-}Close(F);{$I+} CloseError:=IOResult;
 APSaveReport:=(ErrorCode=0) And (CloseError=0);
End;

Procedure APExport(Var D:TAPState; Const Report:TAPReport);
Var Name:String; Info:SearchRec;
Begin
 Name:='PAINT-ATTRIBUTS.TXT';
 If PromptString('Exporter les attributs','Rapport texte :',Name) And (Name<>'') Then Begin
  If ExtractFileExt(Name)='' Then Name:=Name+'.TXT';
  FindFirst(Name,AnyFile,Info);
  If DosError=0 Then
   If PromptYesNoCancel('Remplacer le rapport','Ce fichier existe. Le remplacer ?')<>1 Then Begin
    D.Dirty:=True; Exit;
   End;
  If APSaveReport(Name,Report) Then D.Status:='Rapport des attributs exporte.'
  Else D.Status:='Echec d ecriture du rapport. Verifiez le chemin.';
 End;
 D.Dirty:=True;
End;

Procedure APHelp(Var D:TAPState);
Begin
 ShowMessage('Aide - Attributs',
  '1..4 : onglets ; Tab : commande suivante.'+#10+
  'Secteurs et bandes : proportion du total.'+#10+
  'Memoire : pixels, palette et historique inclus.'+#10+
  'Disque : derniere version enregistree du fichier.'+#10+
  'F5 actualise ; Echap ferme ; Ctrl+C copie le rapport.');
 D.Dirty:=True;
End;

Procedure APActivate(Var D:TAPState; Action:Integer);
Var Report:TAPReport;
Begin
 If (Action>=0) And (Action<AP_TAB_COUNT) Then Begin
  D.Tab:=Action; D.Focus:=Action; D.Dirty:=True; Exit;
 End;
 Case Action Of
  4: D.Done:=True;
  5: Begin
   PEHideMouse; APRestorePalette(D); PEShowMouse;
   ResizeImageDialog;
   APRefresh(D);
   PEHideMouse; PEBuildDisplayPalette; PEShowMouse;
  End;
  6: Begin APRefresh(D); PEHideMouse; PEBuildDisplayPalette; PEShowMouse; End;
  7: Begin
   APBuildReport(D,Report);
   If APCopyReport(Report) Then D.Status:='Rapport complet copie dans le presse-papiers.'
   Else D.Status:='Presse-papiers indisponible. Utilisez Exporter.';
   D.Dirty:=True;
  End;
  8: Begin APBuildReport(D,Report); APExport(D,Report); End;
  9: APHelp(D);
 End;
End;

Procedure APKeyboard(Var D:TAPState);
Var K:Char; Next:Integer;
Begin
 K:=ReadKey;
 If K=#0 Then Begin
  K:=ReadKey;
  Case Ord(K) Of
   15: Begin D.Focus:=D.Focus-1; If D.Focus<0 Then D.Focus:=9; D.Dirty:=True; End;
   59: APHelp(D);
   63: APActivate(D,6);
   73: APActivate(D,(D.Tab+3) Mod AP_TAB_COUNT);
   81: APActivate(D,(D.Tab+1) Mod AP_TAB_COUNT);
   75,77: If D.Focus<4 Then Begin
    Next:=D.Tab+1; If Ord(K)=75 Then Next:=D.Tab+3;
    APActivate(D,Next Mod AP_TAB_COUNT);
   End;
   72,80: If D.Tab=1 Then Begin
    If Ord(K)=72 Then Dec(D.SelectedColor) Else Inc(D.SelectedColor);
    D.SelectedColor:=PEClamp(D.SelectedColor,0,Max(0,D.Colors.Count-1));
    D.Dirty:=True;
   End;
  End;
  Exit;
 End;
 Case K Of
  #27: D.Done:=True;
  #9: Begin Inc(D.Focus); If D.Focus>9 Then D.Focus:=0; D.Dirty:=True; End;
  #13,' ': APActivate(D,D.Focus);
  #3: APActivate(D,7);
  '1'..'4': APActivate(D,Ord(K)-Ord('1'));
 End;
End;

Procedure APMouse(Var D:TAPState);
Var I,DX,DY:Integer;
Begin
 GetMouseStateLocal(D.MX,D.MY,D.MB);
 If ((D.MB And 1)<>0) And ((D.PreviousButtons And 1)=0) Then Begin
  If (D.MX>=D.X+596) And (D.MX<=D.X+617) And
     (D.MY>=D.Y+3) And (D.MY<=D.Y+21) Then D.Done:=True
  Else Begin
   For I:=0 To AP_TAB_COUNT-1 Do
    If PEInside(D.MX,D.MY,D.Tabs[I]) Then APActivate(D,I);
   For I:=0 To AP_BUTTON_COUNT-1 Do
    If PEInside(D.MX,D.MY,D.Buttons[I]) Then Begin D.Focus:=I+4; APActivate(D,I+4); End;
   If D.Tab=1 Then Begin
    DX:=D.MX-(D.X+112); DY:=(D.Y+164)-D.MY;
    If LongInt(DX)*DX+LongInt(DY)*DY<=72*72 Then Begin
     I:=APSectorAt(D.Colors,APAngle(DX,DY));
     If I>=0 Then Begin D.SelectedColor:=I; D.Dirty:=True; End;
    End;
    If (D.MX>=D.X+231) And (D.MX<=D.X+604) And
       (D.MY>=D.Y+95) And (D.MY<D.Y+95+D.Colors.Count*25) Then Begin
     D.SelectedColor:=(D.MY-D.Y-95) Div 25;
     D.Dirty:=True;
    End;
   End;
  End;
 End;
 D.PreviousButtons:=D.MB;
End;

Procedure ImageAttributesDialog;
Var D:TAPState;
Begin
 MenuActive:=False;
 RedrawInterface;
 FillChar(D,SizeOf(D),0);
 D.Focus:=4;
 APLayout(D);
 APRefresh(D);
 GetMouseStateLocal(D.MX,D.MY,D.PreviousButtons);
 PEHideMouse; PEBuildDisplayPalette; PEShowMouse;
 While Not D.Done Do Begin
  If D.Dirty Then APDraw(D);
  If KeyPressed Then APKeyboard(D);
  If Not D.Done Then APMouse(D);
  Delay(10);
 End;
 PEHideMouse; APRestorePalette(D); PEShowMouse;
 Repeat
  GetMouseStateLocal(D.MX,D.MY,D.MB);
  If (D.MB And 1)<>0 Then Delay(10);
 Until (D.MB And 1)=0;
 OldMouseButtons:=0; MouseButtons:=0;
 RedrawInterface;
End;


{ Explorateur de fichiers dessine exclusivement avec les primitives BGI.
  Aucune boite de dialogue du systeme, aucun changement de repertoire global. }
Const
 OFMaxFiles = 2048;
 OFMaxTree = 512;
Type
 TOFEntry = Record
  Name: String;
  Size: LongInt;
  Stamp: LongInt;
 End;
 TOFTree = Record
  Path: String;
  Depth: Integer;
  Expanded: Boolean;
 End;
 TOFState = Record
  X,Y,W,H,Rows: Integer;
  Folder,Name,Address,Notice,Clip: String;
  Files: Array[0..OFMaxFiles-1] Of TOFEntry;
  Tree: Array[0..OFMaxTree-1] Of TOFTree;
  Count,TreeCount,Selected,Top,TreeTop,TreeSelected: Integer;
  Filter,Focus,Cursor,Anchor: Integer;
  Back: Array[0..31] Of String;
  BackCount: Integer;
  LastIndex: Integer;
  LastClick: LongInt;
  Truncated,Accepted,Done,Dirty,SaveMode: Boolean;
 End;
 POFState = ^TOFState;

Function OFJoin(Const Folder,Name: String): String;
Begin
 If (Folder<>'') And (Folder[Length(Folder)]<>'\') And
    (Folder[Length(Folder)]<>'/') Then OFJoin:=Folder+'\'+Name
 Else OFJoin:=Folder+Name;
End;

Function OFParent(Const Folder: String): String;
Var S: String; I: Integer;
Begin
 S:=Folder;
 While (Length(S)>3) And (S[Length(S)] In ['\','/']) Do Delete(S,Length(S),1);
 I:=Length(S);
 While (I>0) And Not (S[I] In ['\','/']) Do Dec(I);
 If I=3 Then OFParent:=Copy(S,1,3)
 Else If I>0 Then OFParent:=Copy(S,1,I-1)
 Else OFParent:=S;
End;

Function OFBase(Const Path: String): String;
Var I: Integer;
Begin
 I:=Length(Path);
 While (I>0) And Not (Path[I] In ['\','/']) Do Dec(I);
 OFBase:=Copy(Path,I+1,255);
End;

Function OFUpper(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 OFUpper:=S;
End;

Function OFMatches(Const Name: String; Filter: Integer): Boolean;
Var E: String;
Begin
 E:=OFUpper(ExtractFileExt(Name));
 Case Filter Of
  0: OFMatches:=(E='.BMP') Or (E='.DIB') Or (E='.GIF') Or
                (E='.PNG') Or (E='.JPG') Or (E='.JPEG') Or (E='.XBM') Or
                (E='.WPG') Or (E='.LBM') Or (E='.ILBM') Or (E='.IFF') Or
                (E='.HDR') Or (E='.RGBE') Or (E='.FAX') Or (E='.EXR') Or
                (E='.DNG') Or (E='.BGX') Or (E='.DDS') Or (E='.DCM') Or
                (E='.APNG') Or (E='.ARW') Or (E='.CR2') Or (E='.PPM') Or
                (E='.CUR') Or (E='.PCX') Or (E='.MSP') Or
                (E='.TIF') Or (E='.TIFF') Or
                (E='.MAC') Or (E='.PNTG') Or (E='.PAS') Or
                (E='.TGA') Or (E='.TARGA') Or (E='.ICO');
  1: OFMatches:=(E='.BMP') Or (E='.DIB');
  2: OFMatches:=E='.GIF';
  3: OFMatches:=E='.PNG';
  4: OFMatches:=(E='.JPG') Or (E='.JPEG');
  5: OFMatches:=E='.XBM';
  6: OFMatches:=E='.WPG';
  7: OFMatches:=(E='.LBM') Or (E='.ILBM') Or (E='.IFF');
  8: OFMatches:=(E='.HDR') Or (E='.RGBE');
  9: OFMatches:=E='.FAX';
  10: OFMatches:=E='.EXR';
  11: OFMatches:=E='.DNG';
  12: OFMatches:=E='.BGX';
  13: OFMatches:=E='.DDS';
  14: OFMatches:=E='.DCM';
  15: OFMatches:=E='.APNG';
  16: OFMatches:=E='.ARW';
  17: OFMatches:=E='.CR2';
  18: OFMatches:=E='.PPM';
  19: OFMatches:=E='.DIB';
  20: OFMatches:=E='.CUR';
  21: OFMatches:=E='.PCX';
  22: OFMatches:=E='.MSP';
  23: OFMatches:=(E='.TIF') Or (E='.TIFF');
  24: OFMatches:=(E='.MAC') Or (E='.PNTG');
  25: OFMatches:=(E='.PAS');
  26: OFMatches:=(E='.TGA') Or (E='.TARGA');
  27: OFMatches:=E='.ICO';
  Else OFMatches:=True;
 End;
End;

Function OFFilterLabel(N: Integer): String;
Begin
 Case N Of
  0: OFFilterLabel:='Images : tous les formats pris en charge';
  1: OFFilterLabel:='Bitmap : *.bmp; *.dib';
  2: OFFilterLabel:='GIF : *.gif';
  3: OFFilterLabel:='PNG : *.png';
  4: OFFilterLabel:='JPEG : *.jpg; *.jpeg';
  5: OFFilterLabel:='X Bitmap : *.xbm';
  6: OFFilterLabel:='WordPerfect Graphics : *.wpg';
  7: OFFilterLabel:='IFF / LBM : *.lbm; *.ilbm; *.iff';
  8: OFFilterLabel:='Radiance HDR : *.hdr; *.rgbe';
  9: OFFilterLabel:='FAX Group 3 1D : *.fax';
  10: OFFilterLabel:='OpenEXR non compresse : *.exr';
  11: OFFilterLabel:='DNG Bayer non compresse : *.dng';
  12: OFFilterLabel:='MonsterBook BGX : *.bgx';
  13: OFFilterLabel:='DirectDraw Surface : *.dds';
  14: OFFilterLabel:='DICOM non compresse : *.dcm';
  15: OFFilterLabel:='APNG : *.apng';
  16: OFFilterLabel:='ARW Bayer non compresse : *.arw';
  17: OFFilterLabel:='CR2 Bayer non compresse : *.cr2';
  18: OFFilterLabel:='PPM Portable Pixmap : *.ppm';
  19: OFFilterLabel:='DIB Device Independent Bitmap : *.dib';
  20: OFFilterLabel:='CUR Curseur Windows : *.cur';
  21: OFFilterLabel:='PCX ZSoft Paintbrush : *.pcx';
  22: OFFilterLabel:='MSP Microsoft Paint : *.msp';
  23: OFFilterLabel:='TIFF : *.tif; *.tiff';
  24: OFFilterLabel:='MacPaint : *.mac; *.pntg';
  25: OFFilterLabel:='Pascal Bitmap : *.pas';
  26: OFFilterLabel:='Targa : *.tga; *.targa';
  27: OFFilterLabel:='ICO Icone Windows : *.ico';
  Else OFFilterLabel:='Tous les fichiers : *.*';
 End;
End;

Function OFDirectory(Const Path: String): Boolean;
Var R: SearchRec;
Begin
 FindFirst(Path,AnyFile,R);
 OFDirectory:=(DosError=0) And ((R.Attr And Directory)<>0);
 {$IFDEF FPC}FindClose(R);{$ENDIF}
End;

Procedure OFScan(Var D: TOFState);
Var R: SearchRec; I,J: Integer; E: TOFEntry;
Begin
 D.Count:=0; D.Top:=0; D.Selected:=-1; D.Truncated:=False;
 D.LastIndex:=-1; D.LastClick:=0;
 FindFirst(OFJoin(D.Folder,'*.*'),AnyFile,R);
 While DosError=0 Do Begin
  If ((R.Attr And (Directory+VolumeID))=0) And OFMatches(R.Name,D.Filter) Then Begin
   If D.Count<OFMaxFiles Then Begin
    D.Files[D.Count].Name:=R.Name;
    D.Files[D.Count].Size:=R.Size;
    D.Files[D.Count].Stamp:=R.Time;
    Inc(D.Count);
   End Else D.Truncated:=True;
  End;
  FindNext(R);
 End;
 {$IFDEF FPC}FindClose(R);{$ENDIF}
 { Tri insensible a la casse, sans dependance a une unite systeme. }
 For I:=1 To D.Count-1 Do Begin
  E:=D.Files[I]; J:=I-1;
  While J>=0 Do Begin
   If OFUpper(D.Files[J].Name)<=OFUpper(E.Name) Then Break;
   D.Files[J+1]:=D.Files[J]; Dec(J);
  End;
  D.Files[J+1]:=E;
 End;
 Str(D.Count,D.Notice); D.Notice:=D.Notice+' fichier(s)';
 If D.Truncated Then D.Notice:=D.Notice+' - limite 2048, affinez le filtre';
 If D.Count=0 Then D.Notice:='Aucun fichier pour ce type. Changez le filtre.';
 D.Dirty:=True;
End;

Procedure OFExpand(Var D: TOFState; Index: Integer);
Var R: SearchRec; I,J,First,Last: Integer; T: TOFTree;
Begin
 If (Index<0) Or (Index>=D.TreeCount) Then Exit;
 If D.Tree[Index].Expanded Then Begin
  J:=Index+1;
  While (J<D.TreeCount) And (D.Tree[J].Depth>D.Tree[Index].Depth) Do Inc(J);
  I:=J-Index-1;
  For J:=Index+1 To D.TreeCount-I-1 Do D.Tree[J]:=D.Tree[J+I];
  Dec(D.TreeCount,I); D.Tree[Index].Expanded:=False;
 End Else Begin
  First:=Index+1; Last:=First;
  FindFirst(OFJoin(D.Tree[Index].Path,'*.*'),AnyFile,R);
  While DosError=0 Do Begin
   If ((R.Attr And Directory)<>0) And (R.Name<>'.') And (R.Name<>'..') Then Begin
    If D.TreeCount<OFMaxTree Then Begin
     For J:=D.TreeCount DownTo Last+1 Do D.Tree[J]:=D.Tree[J-1];
     D.Tree[Last].Path:=OFJoin(D.Tree[Index].Path,R.Name);
     D.Tree[Last].Depth:=D.Tree[Index].Depth+1;
     D.Tree[Last].Expanded:=False;
     Inc(Last); Inc(D.TreeCount);
    End Else D.Notice:='Arbre limite a 512 dossiers : repliez une branche.';
   End;
   FindNext(R);
  End;
  {$IFDEF FPC}FindClose(R);{$ENDIF}
  For I:=First+1 To Last-1 Do Begin
   T:=D.Tree[I]; J:=I-1;
   While J>=First Do Begin
    If OFUpper(D.Tree[J].Path)<=OFUpper(T.Path) Then Break;
    D.Tree[J+1]:=D.Tree[J]; Dec(J);
   End;
   D.Tree[J+1]:=T;
  End;
  D.Tree[Index].Expanded:=True;
 End;
 D.TreeSelected:=Index;
 D.TreeTop:=Min(D.TreeTop,Max(0,D.TreeCount-D.Rows));
 D.Dirty:=True;
End;

Procedure OFNavigate(Var D: TOFState; S: String; Remember: Boolean);
Var I: Integer;
Begin
 If S='' Then Exit;
 S:=FExpand(S);
 If Not OFDirectory(S) Then Begin D.Notice:='Dossier inexistant ou inaccessible.'; D.Dirty:=True; Exit; End;
 If Remember And (OFUpper(S)<>OFUpper(D.Folder)) Then Begin
  If D.BackCount=32 Then Begin
   For I:=1 To 31 Do D.Back[I-1]:=D.Back[I];
   Dec(D.BackCount);
  End;
  D.Back[D.BackCount]:=D.Folder; Inc(D.BackCount);
 End;
 D.Folder:=S; D.Address:=S;
 If D.SaveMode Then D.Name:=OFBase(D.Name) Else D.Name:='';
 D.Cursor:=Length(D.Name); D.Anchor:=0;
 OFScan(D);
End;

Function OFShort(S: String; Width: Integer): String;
Begin
 If Width<24 Then Begin OFShort:=''; Exit; End;
 If TextWidth(S)>Width Then Begin
  While (Length(S)>0) And (TextWidth(S+'...')>Width) Do Delete(S,Length(S),1);
  S:=S+'...';
 End;
 OFShort:=S;
End;

Procedure OFButton(X,Y,W: Integer; Const S: String; Active: Boolean);
Begin
 SetFillStyle(SolidFill,LightGray); Bar(X,Y,X+W,Y+22);
 SetColor(White); Line(X,Y,X+W,Y); Line(X,Y,X,Y+22);
 SetColor(DarkGray); Line(X+W,Y,X+W,Y+22); Line(X,Y+22,X+W,Y+22);
 If Active Then SetColor(Blue) Else SetColor(Black);
 OutTextXY(X+Max(3,(W-TextWidth(S)) Div 2),Y+7,S);
End;

Procedure OFDraw(Var D: TOFState);
Var I,N,Y,CX,Lo,Hi: Integer; S: String;
 Procedure EditBox(X,Y,W: Integer; Const Value: String; Which: Integer);
 Var V: String; Offset,PosX,PosEnd: Integer;
 Begin
  SetFillStyle(SolidFill,White); Bar(X,Y,X+W,Y+22);
  If D.Focus=Which Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X,Y,X+W,Y+22);
  Offset:=0;
  If D.Focus=Which Then While TextWidth(Copy(Value,Offset+1,D.Cursor-Offset))+12>W Do Inc(Offset);
  V:=OFShort(Copy(Value,Offset+1,255),W-12);
  SetColor(Black); OutTextXY(X+5,Y+7,V);
  If D.Focus=Which Then Begin
   Lo:=Min(D.Cursor,D.Anchor); Hi:=Max(D.Cursor,D.Anchor);
   PosX:=X+5+TextWidth(Copy(Value,Offset+1,Max(0,Lo-Offset)));
   PosEnd:=Min(X+W-4,X+5+TextWidth(Copy(Value,Offset+1,Max(0,Hi-Offset))));
   If Hi>Lo Then Begin
    SetFillStyle(SolidFill,LightBlue); Bar(PosX,Y+4,PosEnd,Y+18);
    SetColor(Black); OutTextXY(PosX,Y+7,OFShort(Copy(Value,Max(Lo,Offset)+1,Hi-Max(Lo,Offset)),PosEnd-PosX));
   End;
   PosX:=X+5+TextWidth(Copy(Value,Offset+1,D.Cursor-Offset));
   SetColor(Black); Line(PosX,Y+4,PosX,Y+18);
  End;
 End;
Begin
 HideMouse;
 SetFillStyle(SolidFill,LightGray); Bar(D.X,D.Y,D.X+D.W,D.Y+D.H);
 SetColor(DarkGray); Rectangle(D.X,D.Y,D.X+D.W,D.Y+D.H);
 SetFillStyle(SolidFill,Blue); Bar(D.X+1,D.Y+1,D.X+D.W-1,D.Y+23);
 SetColor(White);
 If D.SaveMode Then OutTextXY(D.X+10,D.Y+8,'Enregistrer sous - explorateur PAINT')
 Else OutTextXY(D.X+10,D.Y+8,'Ouvrir une image - explorateur PAINT');
 OFButton(D.X+8,D.Y+30,62,'Retour',False);
 OFButton(D.X+76,D.Y+30,62,'Parent',False);
 OFButton(D.X+144,D.Y+30,90,'Actualiser',False);
 If D.SaveMode Then OFButton(D.X+240,D.Y+30,120,'Nouv. dossier',False);
 OFButton(D.X+D.W-70,D.Y+30,60,'Aide',False);
 EditBox(D.X+8,D.Y+60,D.W-88,D.Address,3);
 OFButton(D.X+D.W-72,D.Y+60,62,'Aller',D.Focus=3);
 SetColor(Black); OutTextXY(D.X+10,D.Y+91,'Dossiers (+/-)');
 OutTextXY(D.X+220,D.Y+91,'Nom du fichier');
 OutTextXY(D.X+D.W-94,D.Y+91,'Taille');
 SetFillStyle(SolidFill,White);
 Bar(D.X+8,D.Y+105,D.X+205,D.Y+105+D.Rows*16);
 Bar(D.X+216,D.Y+105,D.X+D.W-9,D.Y+105+D.Rows*16);
 SetColor(DarkGray); Rectangle(D.X+8,D.Y+105,D.X+205,D.Y+105+D.Rows*16);
 Rectangle(D.X+216,D.Y+105,D.X+D.W-9,D.Y+105+D.Rows*16);
 For I:=0 To D.Rows-1 Do Begin
  Y:=D.Y+108+I*16; N:=D.TreeTop+I;
  If N<D.TreeCount Then Begin
   If N=D.TreeSelected Then Begin
    SetFillStyle(SolidFill,LightCyan); Bar(D.X+9,Y-1,D.X+204,Y+12);
   End;
   CX:=D.X+12+Min(D.Tree[N].Depth,7)*12;
   SetColor(Blue);
   If D.Tree[N].Expanded Then S:='-' Else S:='+';
   OutTextXY(CX,Y,S);
   SetColor(Brown); Rectangle(CX+10,Y,CX+21,Y+9);
   S:=OFBase(D.Tree[N].Path); If S='' Then S:=D.Tree[N].Path;
   SetColor(Black); OutTextXY(CX+25,Y,OFShort(S,D.X+200-CX-25));
  End;
  N:=D.Top+I;
  If N<D.Count Then Begin
   If N=D.Selected Then Begin
    SetFillStyle(SolidFill,LightBlue); Bar(D.X+217,Y-1,D.X+D.W-10,Y+12);
   End;
   SetColor(Black); OutTextXY(D.X+222,Y,OFShort(D.Files[N].Name,D.W-322));
   Str(D.Files[N].Size Div 1024,S); If D.Files[N].Size<1024 Then S:='<1';
   OutTextXY(D.X+D.W-94,Y,S+' Ko');
  End;
 End;
 Y:=D.Y+109+D.Rows*16;
 OFButton(D.X+8,Y,44,'Haut',False); OFButton(D.X+58,Y,44,'Bas',False);
 OFButton(D.X+216,Y,62,'Prec.',False); OFButton(D.X+284,Y,62,'Suiv.',False);
 S:=D.Notice;
 SetColor(Black); OutTextXY(D.X+10,Y+30,OFShort(S,D.W-20));
 Y:=D.Y+D.H-116;
 OutTextXY(D.X+10,Y+7,'Nom :'); EditBox(D.X+66,Y,D.W-78,D.Name,0);
 Y:=Y+29; SetColor(Black); OutTextXY(D.X+10,Y+7,'Type :');
 OFButton(D.X+66,Y,D.W-100,OFShort(OFFilterLabel(D.Filter),D.W-116),D.Focus=4);
 OFButton(D.X+D.W-34,Y,22,'v',D.Focus=4);
 Y:=D.Y+D.H-56;
 OFButton(D.X+10,Y,62,'Copier',False); OFButton(D.X+78,Y,62,'Coller',False);
 OFButton(D.X+146,Y,72,'Effacer',False);
 If D.SaveMode Then OFButton(D.X+D.W-204,Y,104,'Enregistrer',D.Focus=5)
 Else OFButton(D.X+D.W-180,Y,80,'Ouvrir',D.Focus=5);
 OFButton(D.X+D.W-92,Y,80,'Annuler',D.Focus=6);
 SetColor(DarkGray);
 If D.SaveMode Then OutTextXY(D.X+10,D.Y+D.H-19,'Entree : enregistrer | Echap : annuler | Ctrl+A/C/X/V : edition')
 Else OutTextXY(D.X+10,D.Y+D.H-19,'Tab : focus | Entree : ouvrir | F5 : actualiser | Echap : annuler');
 ShowMouse; D.Dirty:=False;
End;

Function OFPaste: String;
{$IFDEF WINDOWS}
Var M: TPaintWinHandle; P: PChar; S: String; I: Integer;
Begin
 S:='';
 If PaintWinOpenClipboard(0) Then Begin
  M:=PaintWinGetClipboardData(PAINT_CF_TEXT);
  If M<>0 Then Begin
   P:=PChar(PaintWinGlobalLock(M));
   If P<>Nil Then Begin
    I:=0;
    While (I<255) And (P[I]<>#0) And (P[I]<>#13) And (P[I]<>#10) Do Begin
     If P[I]>=' ' Then S:=S+P[I]; Inc(I);
    End;
    PaintWinGlobalUnlock(M);
   End;
  End;
  PaintWinCloseClipboard;
 End;
 OFPaste:=S;
End;
{$ELSE}
Begin OFPaste:=''; End;
{$ENDIF}

Procedure OFEdit(Var D: TOFState; K,E: Char);
Var S,T: String; Lo,Hi: Integer;
Begin
 If D.Focus=3 Then S:=D.Address Else S:=D.Name;
 D.Cursor:=Min(D.Cursor,Length(S)); D.Anchor:=Min(D.Anchor,Length(S));
 Lo:=Min(D.Cursor,D.Anchor); Hi:=Max(D.Cursor,D.Anchor);
 Case K Of
  #1: Begin D.Anchor:=0; D.Cursor:=Length(S); End;
  #3,#24: Begin
   If Hi>Lo Then T:=Copy(S,Lo+1,Hi-Lo) Else T:=S;
   D.Clip:=T;
   If Not PGCopyText(T) Then D.Notice:='Copie interne disponible dans cette boite.';
   If K=#24 Then Begin
    If Hi=Lo Then Begin Lo:=0; Hi:=Length(S); End;
    Delete(S,Lo+1,Hi-Lo); D.Cursor:=Lo; D.Anchor:=Lo;
   End;
  End;
  #22: Begin
   T:=OFPaste; If T='' Then T:=D.Clip;
   If Length(S)-(Hi-Lo)+Length(T)<=255 Then Begin
    Delete(S,Lo+1,Hi-Lo); Insert(T,S,Lo+1);
    D.Cursor:=Lo+Length(T); D.Anchor:=D.Cursor;
   End Else D.Notice:='Chemin trop long : maximum 255 caracteres.';
  End;
  #8: Begin
   If Hi>Lo Then Delete(S,Lo+1,Hi-Lo)
   Else If Lo>0 Then Begin Delete(S,Lo,1); Dec(Lo); End;
   D.Cursor:=Lo; D.Anchor:=Lo;
  End;
  #0: Case E Of
   #75: Begin D.Cursor:=Max(0,D.Cursor-1); D.Anchor:=D.Cursor; End;
   #77: Begin D.Cursor:=Min(Length(S),D.Cursor+1); D.Anchor:=D.Cursor; End;
   #71: Begin D.Cursor:=0; D.Anchor:=0; End;
   #79: Begin D.Cursor:=Length(S); D.Anchor:=D.Cursor; End;
   #83: Begin
    If Hi>Lo Then Delete(S,Lo+1,Hi-Lo) Else Delete(S,Lo+1,1);
    D.Cursor:=Lo; D.Anchor:=Lo;
   End;
  End;
  Else If K>=' ' Then Begin
   If Length(S)-(Hi-Lo)<255 Then Begin
    Delete(S,Lo+1,Hi-Lo); Insert(K,S,Lo+1); D.Cursor:=Lo+1; D.Anchor:=D.Cursor;
   End;
  End;
 End;
 If D.Focus=3 Then D.Address:=S Else D.Name:=S;
 D.Dirty:=True;
End;

Procedure OFSelect(Var D: TOFState; N: Integer);
Var DT: DateTime; S,T: String;
Begin
 If D.Count=0 Then Exit;
 D.Selected:=Max(0,Min(D.Count-1,N)); D.Name:=D.Files[D.Selected].Name;
 D.Cursor:=Length(D.Name); D.Anchor:=0;
 UnpackTime(D.Files[D.Selected].Stamp,DT);
 Str(DT.Day,S); Str(DT.Month,T); S:=S+'/'+T; Str(DT.Year,T); S:=S+'/'+T;
 Str(D.Files[D.Selected].Size,T); D.Notice:=T+' octets - modifie le '+S;
 If D.Selected<D.Top Then D.Top:=D.Selected;
 If D.Selected>=D.Top+D.Rows Then D.Top:=D.Selected-D.Rows+1;
 D.Dirty:=True;
End;

Function OFSaveExtension(Filter: Integer): String;
Begin
 Case Filter Of 2: OFSaveExtension:='.gif'; 3: OFSaveExtension:='.png';
 21: OFSaveExtension:='.pcx';
 4: OFSaveExtension:='.jpg';
 25: OFSaveExtension:='.pas';
 12: OFSaveExtension:='.bgx';
 5: OFSaveExtension:='.xbm';
 18: OFSaveExtension:='.ppm';
 15: OFSaveExtension:='.apng';
 16: OFSaveExtension:='.arw';
 17: OFSaveExtension:='.cr2';
 14: OFSaveExtension:='.dcm';
 13: OFSaveExtension:='.dds';
 6: OFSaveExtension:='.wpg';
 10: OFSaveExtension:='.exr';
 9: OFSaveExtension:='.fax'; Else OFSaveExtension:='.bmp'; End;
End;

Function OFSaveName(Const Name: String; Filter: Integer): String;
Var E,S: String;
Begin
 S:=Name; E:=ExtractFileExt(S);
 If E<>'' Then Delete(S,Length(S)-Length(E)+1,Length(E));
 OFSaveName:=S+OFSaveExtension(Filter);
End;

Function OFValidName(Const S: String): Boolean;
Var Base: String; I: Integer;
Begin
 OFValidName:=False;
 If (S='') Or (S='.') Or (S='..') Then Exit;
 If S[Length(S)] In [' ','.'] Then Exit;
 For I:=1 To Length(S) Do If (S[I]<' ') Or (S[I] In ['\','/',':','*','?','"','<','>','|']) Then Exit;
 Base:=OFUpper(S); I:=Pos('.',Base); If I>0 Then Base:=Copy(Base,1,I-1);
 If (Base='CON') Or (Base='PRN') Or (Base='AUX') Or (Base='NUL') Or
    (Base='CONIN$') Or (Base='CONOUT$') Then Exit;
 If (Length(Base)=4) And ((Copy(Base,1,3)='COM') Or (Copy(Base,1,3)='LPT')) And (Base[4] In ['1'..'9']) Then Exit;
 OFValidName:=True;
End;

Procedure OFNewFolder(Var D: TOFState);
Var Name,Path: String; Code,I: Integer;
Begin
 Name:='';
 If Not PromptString('Nouveau dossier','Nom du nouveau dossier :',Name) Then Begin D.Dirty:=True; Exit; End;
 D.Dirty:=True;
 If Not OFValidName(Name) Then Begin D.Notice:='Nom de dossier invalide.'; Exit; End;
 If Length(D.Folder)+Length(Name)+1>255 Then Begin D.Notice:='Chemin trop long (255 caracteres).'; Exit; End;
 Path:=OFJoin(D.Folder,Name);
 {$I-}MkDir(Path);{$I+}Code:=IOResult;
 If Code<>0 Then Begin D.Notice:='Creation impossible : dossier existant ou acces refuse.'; Exit; End;
 For I:=0 To D.TreeCount-1 Do If OFUpper(D.Tree[I].Path)=OFUpper(D.Folder) Then Begin
  If D.Tree[I].Expanded Then OFExpand(D,I);
  OFExpand(D,I); Break;
 End;
 OFNavigate(D,Path,True);
End;

Procedure OFSaveAccept(Var D: TOFState);
Var S,E,Base,Parent: String; R: SearchRec; Exists: Boolean; Answer: Integer;
Begin
 D.Dirty:=True; S:=D.Name;
 While (Length(S)>0) And (S[1]=' ') Do Delete(S,1,1);
 If (Length(S)>=2) And (S[1]='"') And (S[Length(S)]='"') Then S:=Copy(S,2,Length(S)-2);
 If S='' Then Begin D.Notice:='Saisissez le nom du fichier a enregistrer.'; Exit; End;
 If (Pos('*',S)>0) Or (Pos('?',S)>0) Then Begin D.Notice:='Les caracteres * et ? sont interdits dans le nom.'; Exit; End;
 If (Pos(':',S)=0) And (S[1]<>'\') And (S[1]<>'/') Then Begin
  If Length(D.Folder)+Length(S)+1>255 Then Begin D.Notice:='Chemin trop long (255 caracteres).'; Exit; End;
  S:=OFJoin(D.Folder,S);
 End;
 S:=FExpand(S);
 If OFDirectory(S) Then Begin OFNavigate(D,S,True); Exit; End;
 Base:=OFBase(S); Parent:=OFParent(S);
 If Not OFValidName(Base) Then Begin D.Notice:='Nom invalide ou reserve par le systeme.'; Exit; End;
 If Not OFDirectory(Parent) Then Begin D.Notice:='Le dossier de destination n''existe pas.'; Exit; End;
 E:=ExtractFileExt(Base);
 If (E<>'') And (E<>'.BMP') And (E<>'.DIB') And (E<>'.PNG') And (E<>'.GIF') Then Begin
  D.Notice:='Extensions disponibles : .bmp, .gif, .png. Changez le nom ou le type.'; Exit;
 End;
 If Length(S)-Length(E)+4>255 Then Begin D.Notice:='Chemin trop long apres ajout de l''extension.'; Exit; End;
 If (E<>'') And (E<>OFUpper(OFSaveExtension(D.Filter))) Then Begin
  D.Name:=OFSaveName(S,D.Filter); D.Cursor:=Length(D.Name); D.Anchor:=0;
  D.Notice:='Extension adaptee au type choisi. Validez a nouveau pour enregistrer.'; Exit;
 End;
 If E='' Then S:=S+OFSaveExtension(D.Filter);
 FindFirst(S,AnyFile,R); Exists:=DosError=0;
 If Exists And ((R.Attr And (Directory+ReadOnly))<>0) Then Begin
  {$IFDEF FPC}FindClose(R);{$ENDIF}
  D.Notice:='La cible est un dossier ou un fichier en lecture seule.'; Exit;
 End;
 {$IFDEF FPC}FindClose(R);{$ENDIF}
 If Exists Then Begin
  Answer:=PromptYesNoCancel('Remplacer le fichier existant ?',OFShort(OFBase(S),380));
  If Answer<>1 Then Begin D.Notice:='Fichier conserve. Choisissez un autre nom.'; Exit; End;
 End;
 D.Name:=S; D.Accepted:=True; D.Done:=True;
End;


Procedure OFAccept(Var D: TOFState);
Var S: String; R: SearchRec;
Begin
 If D.SaveMode Then Begin OFSaveAccept(D); Exit; End;
 S:=D.Name;
 If (Length(S)>=2) And (S[1]='"') And (S[Length(S)]='"') Then S:=Copy(S,2,Length(S)-2);
 If S='' Then Begin D.Notice:='Selectionnez un fichier ou saisissez son nom.'; D.Dirty:=True; Exit; End;
 If (Pos('*',S)>0) Or (Pos('?',S)>0) Then Begin
  D.Notice:='Choisissez un type avec le bouton Changer.'; D.Dirty:=True; Exit;
 End;
 If (Pos(':',S)=0) And (S[1]<>'\') And (S[1]<>'/') Then Begin
  If Length(D.Folder)+Length(S)+1>255 Then Begin D.Notice:='Chemin trop long (255 caracteres).'; D.Dirty:=True; Exit; End;
  S:=OFJoin(D.Folder,S);
 End;
 S:=FExpand(S);
 If OFDirectory(S) Then Begin OFNavigate(D,S,True); Exit; End;
 FindFirst(S,AnyFile,R);
 If DosError<>0 Then Begin D.Notice:='Fichier introuvable ou inaccessible.'; D.Dirty:=True; Exit; End;
 {$IFDEF FPC}FindClose(R);{$ENDIF}
 If Not OFMatches(S,0) Then Begin
  D.Notice:='Formats ouvrables : BMP, DIB, GIF, PNG, JPG, JPEG, XBM, WPG, L' +
  'BM, HDR, FAX, EXR, DNG, BGX, DDS, DCM, APNG, ARW, CR2, PPM.'; D.Dirty:=True;
  Exit;
 End;
 D.Name:=S; D.Accepted:=True; D.Done:=True;
End;

Type TOFFilterOrder = Array[0..28] Of Integer;

Procedure OFSortedFilters(Saving: Boolean; Var Order: TOFFilterOrder; Var Count: Integer);
Var I,J,T: Integer;
Begin
 Count:=29; If Saving Then Count:=17;
 For I:=0 To Count-1 Do Begin
  Order[I]:=I; If Saving Then Begin
   Order[I]:=I+1; If I=3 Then Order[I]:=21;
   If I=4 Then Order[I]:=4; If I=5 Then Order[I]:=25; If I=6 Then Order[I]:=12;
   If I=7 Then Order[I]:=5; If I=8 Then Order[I]:=18; If I=9 Then Order[I]:=15;
   If I=13 Then Order[I]:=13; If I=14 Then Order[I]:=6; If I=15 Then
   Order[I]:=10;
   If I=16 Then Order[I]:=9;
   If I=10 Then Order[I]:=16; If I=11 Then Order[I]:=17; If I=12 Then
   Order[I]:=14;
  End;
 End;
 { Trier uniquement la presentation, sans changer les identifiants des formats. }
 For I:=1 To Count-1 Do Begin
  T:=Order[I]; J:=I;
  While J>0 Do Begin
   If OFUpper(OFFilterLabel(Order[J-1]))<=OFUpper(OFFilterLabel(T)) Then Break;
   Order[J]:=Order[J-1]; Dec(J);
  End;
  Order[J]:=T;
 End;
End;

Procedure OFChooseFilter(Var D: TOFState);
Var X,Y,W,I,N,MX,MY,B,Prev,Count,RowHeight,PopupHeight,Top,Visible,Hit: Integer;
    K,E: Char; Done,Accept: Boolean; OldName: String; Order: TOFFilterOrder;
Begin
 OFSortedFilters(D.SaveMode,Order,Count); N:=0;
 For I:=0 To Count-1 Do If Order[I]=D.Filter Then N:=I;
 X:=D.X+66; W:=D.W-78; RowHeight:=20;
 { La liste est rattachee au bord superieur du champ Type. }
 Visible:=Min(Count,Max(1,(D.Y+D.H-87-8) Div RowHeight));
 PopupHeight:=Visible*RowHeight+2;
 Y:=D.Y+D.H-87-PopupHeight;
 Top:=Max(0,Min(N-Visible+1,Count-Visible));
 Done:=False; Accept:=False;
 GetMouseStateLocal(MX,MY,Prev);
 Repeat
  If N<Top Then Top:=N;
  If N>=Top+Visible Then Top:=N-Visible+1;
  HideMouse;
  SetFillStyle(SolidFill,White); Bar(X,Y,X+W,Y+PopupHeight);
  SetColor(Black); Rectangle(X,Y,X+W,Y+PopupHeight);
  For I:=0 To Visible-1 Do Begin
   If Top+I=N Then Begin SetFillStyle(SolidFill,Blue); SetColor(White); End
   Else Begin SetFillStyle(SolidFill,White); SetColor(Black); End;
   Bar(X+1,Y+1+I*RowHeight,X+W-1,Y+(I+1)*RowHeight);
   OutTextXY(X+7,Y+7+I*RowHeight,OFShort(OFFilterLabel(Order[Top+I]),W-24));
  End;
  { Indicateurs pour les petits modes graphiques necessitant un defilement. }
  SetColor(DarkGray);
  If Top>0 Then OutTextXY(X+W-12,Y+4,'^');
  If Top+Visible<Count Then OutTextXY(X+W-12,Y+PopupHeight-12,'v');
  ShowMouse;
  Repeat
   If KeyPressed Then Begin
    K:=ReadKey; E:=#0; If K=#0 Then E:=ReadKey;
    Case K Of
     #27: Done:=True;
     #13: Begin Accept:=True; Done:=True; End;
     #0: Case E Of
      #72: N:=Max(0,N-1);
      #80: N:=Min(Count-1,N+1);
      #71: N:=0;
      #79: N:=Count-1;
      #73: N:=Max(0,N-Visible);
      #81: N:=Min(Count-1,N+Visible);
     End;
    End;
    Break;
   End;
   GetMouseStateLocal(MX,MY,B);
   If ((B And 1)<>0) And ((Prev And 1)=0) Then Begin
    If (MX>X) And (MX<X+W) And (MY>Y) And (MY<Y+PopupHeight) Then Begin
     Hit:=(MY-Y-1) Div RowHeight;
     If (MX>=X+W-20) And (Hit=0) And (Top>0) Then Begin
      N:=Max(0,Top-1); Break;
     End Else If (MX>=X+W-20) And (Hit=Visible-1) And (Top+Visible<Count) Then Begin
      N:=Min(Count-1,Top+Visible); Break;
     End Else If Hit<Visible Then Begin N:=Top+Hit; Accept:=True; End;
    End;
    Done:=True;
   End;
   Prev:=B; Delay(10);
  Until Done;
  { Ne pas traiter deux fois un clic maintenu sur une fleche de defilement. }
  If Not Done Then Begin
   GetMouseStateLocal(MX,MY,Prev);
  End;
 Until Done;
 If Accept Then Begin
  D.Filter:=Order[N];
  If D.SaveMode Then Begin
   OldName:=D.Name;
   If OldName<>'' Then D.Name:=OFSaveName(OldName,D.Filter);
   D.Cursor:=Length(D.Name); D.Anchor:=0;
  End;
  OFScan(D);
  If D.SaveMode Then Begin
   D.Notice:='Type choisi : '+OFFilterLabel(D.Filter);
   If D.Filter=9 Then
    D.Notice:='FAX Group 3 1D brut : conversion en noir et blanc, seuil 128.';
   If D.Filter=17 Then
    D.Notice:='CR2 synthetique : Bayer 16 bits avec perte, sans RAW Canon.';
   If D.Filter=16 Then
    D.Notice:='ARW synthetique : Bayer 16 bits, perte de couleurs, sans RAW' +
    ' Sony.';
   If D.Filter=15 Then
    D.Notice:='APNG : une seule image, sans perte de couleur.';
   If D.Filter=5 Then
    D.Notice:='XBM standard : conversion en noir et blanc, seuil 128.';
   If D.Filter=4 Then
    D.Notice:='JPEG : compression avec pertes, qualite 90, couleurs 4:4:4.';
  End;
 End;
 D.Dirty:=True;
End;

Function PaintFileDialog(Var FileName: String; Saving: Boolean; Var SaveFormat: Byte): Boolean;
Var D: POFState; MX,MY,MB,PrevB,I,N,Y,BX,BY: Integer; K,E: Char;
    S: String; Ticks: LongInt; HH,MM,SS,HS: Word;
 Procedure Focus(N: Integer);
 Begin
  D^.Focus:=N;
  If N=3 Then D^.Cursor:=Length(D^.Address) Else D^.Cursor:=Length(D^.Name);
  D^.Anchor:=0; D^.Dirty:=True;
 End;
 Procedure Help;
 Begin
  If Saving Then Begin
   ShowMessage('Enregistrer sous - aide','Choisissez le dossier, le nom et le type. Un fichier existant demande confirmation.');
   ShowMessage('Formats disponibles','BMP, GIF, PNG et PCX conservent les c' +
   'ouleurs du canevas. F7 : nouveau dossier.');
  End Else ShowMessage('Ouvrir - aide','Arbre : +/- deplie, nom = naviguer. Liste : double-clic ou Entree.');
  ShowMessage('Saisie et navigation','Ctrl+A/C/X/V : selectionner/copier/couper/coller. Alt+Haut : parent.');
  D^.Dirty:=True;
 End;
Begin
 MenuActive:=False;
 PaintFileDialog:=False; New(D); FillChar(D^,SizeOf(D^),0); D^.SaveMode:=Saving;
 D^.W:=Min(760,ScreenWidth-16); D^.H:=Min(540,ScreenHeight-16);
 D^.X:=(ScreenWidth-D^.W) Div 2; D^.Y:=(ScreenHeight-D^.H) Div 2;
 D^.Rows:=(D^.H-285) Div 16; D^.Rows:=Max(4,D^.Rows);
 GetDir(0,S); D^.Folder:=S;
 If Saving Then Begin
  D^.Filter:=1; If SaveFormat=FMT_GIF Then D^.Filter:=2 Else If
  SaveFormat=FMT_PNG Then D^.Filter:=3
   Else If SaveFormat=FMT_PCX Then D^.Filter:=21
   Else If SaveFormat=FMT_JPEG Then D^.Filter:=4
   Else If SaveFormat=FMT_PAS Then D^.Filter:=25
   Else If SaveFormat=FMT_BGX Then D^.Filter:=12
   Else If SaveFormat=FMT_XBM Then D^.Filter:=5
   Else If SaveFormat=FMT_PPM Then D^.Filter:=18
   Else If SaveFormat=FMT_APNG Then D^.Filter:=15
   Else If SaveFormat=FMT_ARW Then D^.Filter:=16
   Else If SaveFormat=FMT_CR2 Then D^.Filter:=17
   Else If SaveFormat=FMT_DCM Then D^.Filter:=14
   Else If SaveFormat=FMT_DDS Then D^.Filter:=13
   Else If SaveFormat=FMT_WPG Then D^.Filter:=6
   Else If SaveFormat=FMT_EXR Then D^.Filter:=10
   Else If SaveFormat=FMT_FAX Then D^.Filter:=9;
  If FileName<>'' Then Begin
   S:=OFParent(FExpand(FileName)); If OFDirectory(S) Then D^.Folder:=S;
  End;
 End;
 D^.Focus:=0; D^.Selected:=-1; D^.LastIndex:=-1;
 { Les lecteurs sont les racines de l'arbre. Les branches se deploient
   dans la boite Pascal ; aucune fenetre native n'est creee. }
 For I:=Ord('A') To Ord('Z') Do Begin
  S:=Chr(I)+':\';
  If OFDirectory(S) Then Begin
   D^.Tree[D^.TreeCount].Path:=S; Inc(D^.TreeCount);
  End;
 End;
 If D^.TreeCount=0 Then Begin D^.Tree[0].Path:=D^.Folder; D^.TreeCount:=1; End;
 OFNavigate(D^,D^.Folder,False);
 { Ouvrir automatiquement les ancetres du repertoire courant. }
 I:=0;
 While I<D^.TreeCount Do Begin
  S:=D^.Tree[I].Path;
  If (OFUpper(S)=OFUpper(D^.Folder)) Or
     (Pos(OFUpper(OFJoin(S,'')),OFUpper(OFJoin(D^.Folder,'')))=1) Then Begin
   OFExpand(D^,I);
   If OFUpper(S)=OFUpper(D^.Folder) Then D^.TreeSelected:=I;
  End;
  Inc(I);
 End;
 If Saving Then Begin
  D^.Name:=OFBase(FileName); If D^.Name='' Then D^.Name:='Sans titre';
  D^.Name:=OFSaveName(D^.Name,D^.Filter); D^.Cursor:=Length(D^.Name); D^.Anchor:=0;
  D^.Notice:='Exports : APNG, BMP, GIF, PNG, PCX, JPG, PAS, BGX, XBM, PPM. ' +
  'Autres' +
  ' form' +
  'ats :' +
  ' ouve' +
  'rture' +
  ' seule.';
  If SaveFormat=FMT_FAX Then
   D^.Notice:='FAX Group 3 1D brut : conversion en noir et blanc, seuil 128.';
  If SaveFormat=FMT_CR2 Then
   D^.Notice:='CR2 synthetique : Bayer 16 bits avec perte, sans RAW Canon.';
  If SaveFormat=FMT_ARW Then
   D^.Notice:='ARW synthetique : Bayer 16 bits, perte de couleurs, sans RAW' +
   ' Sony.';
  If SaveFormat=FMT_APNG Then
   D^.Notice:='APNG : une seule image, sans perte de couleur.';
  If SaveFormat=FMT_XBM Then
   D^.Notice:='XBM standard : conversion en noir et blanc, seuil 128.';
  If SaveFormat=FMT_JPEG Then
   D^.Notice:='JPEG : compression avec pertes, qualite 90, couleurs 4:4:4.';
  If ImageBuffer.HasTransparency Then D^.Notice:='Transparence importee : enregistrement sur fond blanc.';
 End;
 D^.TreeTop:=Max(0,D^.TreeSelected-D^.Rows+1);
 GetMouseStateLocal(MX,MY,PrevB);
 Repeat
  If D^.Dirty Then OFDraw(D^);
  If KeyPressed Then Begin
   K:=ReadKey; E:=#0; If K=#0 Then E:=ReadKey;
   Case K Of
    #27: D^.Done:=True;
    #9: Focus((D^.Focus+1) Mod 7);
    #13: Case D^.Focus Of
     3: OFNavigate(D^,D^.Address,True);
     4: OFChooseFilter(D^);
     6: D^.Done:=True;
     1: If D^.TreeSelected<D^.TreeCount Then OFNavigate(D^,D^.Tree[D^.TreeSelected].Path,True);
     Else OFAccept(D^);
    End;
    #0: Begin
     Case E Of
      #59: Help;
      #63: OFScan(D^);
      #65: If Saving Then OFNewFolder(D^);
      #15: Focus((D^.Focus+6) Mod 7);
      #141: OFNavigate(D^,OFParent(D^.Folder),True);
      Else Begin
       If D^.Focus=2 Then Case E Of
        #72: OFSelect(D^,D^.Selected-1);
        #80: OFSelect(D^,D^.Selected+1);
        #73: OFSelect(D^,D^.Selected-D^.Rows);
        #81: OFSelect(D^,D^.Selected+D^.Rows);
        #71: OFSelect(D^,0);
        #79: OFSelect(D^,D^.Count-1);
       End
       Else If D^.Focus=1 Then Begin
        Case E Of
         #72: D^.TreeSelected:=Max(0,D^.TreeSelected-1);
         #80: D^.TreeSelected:=Min(D^.TreeCount-1,D^.TreeSelected+1);
         #77: If Not D^.Tree[D^.TreeSelected].Expanded Then OFExpand(D^,D^.TreeSelected);
         #75: If D^.Tree[D^.TreeSelected].Expanded Then OFExpand(D^,D^.TreeSelected);
        End;
        D^.TreeTop:=Max(0,Min(D^.TreeTop,D^.TreeSelected));
        If D^.TreeSelected>=D^.TreeTop+D^.Rows Then D^.TreeTop:=D^.TreeSelected-D^.Rows+1;
        D^.Dirty:=True;
       End Else If D^.Focus In [0,3] Then OFEdit(D^,K,E);
      End;
     End;
    End;
    Else If D^.Focus In [0,3] Then OFEdit(D^,K,E);
   End;
  End;
  GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((PrevB And 1)=0) Then Begin
   BX:=MX-D^.X; BY:=MY-D^.Y;
   If (BY>=30) And (BY<=52) Then Begin
    If (BX>=8) And (BX<=70) And (D^.BackCount>0) Then Begin
     Dec(D^.BackCount); OFNavigate(D^,D^.Back[D^.BackCount],False);
    End;
    If (BX>=76) And (BX<=138) Then OFNavigate(D^,OFParent(D^.Folder),True);
    If (BX>=144) And (BX<=234) Then OFScan(D^);
    If Saving And (BX>=240) And (BX<=360) Then OFNewFolder(D^);
    If BX>=D^.W-70 Then Help;
   End;
   If (BY>=60) And (BY<=82) Then Begin
    If BX<D^.W-80 Then Focus(3) Else OFNavigate(D^,D^.Address,True);
   End;
   If (BY>=105) And (BY<105+D^.Rows*16) Then Begin
    I:=(BY-105) Div 16;
    If (BX>=8) And (BX<=205) Then Begin
     Focus(1); N:=D^.TreeTop+I;
     If N<D^.TreeCount Then Begin
      D^.TreeSelected:=N;
      If BX<36+Min(D^.Tree[N].Depth,7)*12 Then OFExpand(D^,N)
      Else OFNavigate(D^,D^.Tree[N].Path,True);
     End;
    End;
    If (BX>=216) And (BX<=D^.W-9) Then Begin
     Focus(2); N:=D^.Top+I;
     If N<D^.Count Then Begin
      OFSelect(D^,N); GetTime(HH,MM,SS,HS); Ticks:=((LongInt(HH)*60+MM)*60+SS)*100+HS;
      If (D^.LastIndex=N) And (Ticks>=D^.LastClick) And (Ticks-D^.LastClick<45) Then OFAccept(D^);
      D^.LastIndex:=N; D^.LastClick:=Ticks;
     End;
    End;
   End;
   Y:=109+D^.Rows*16;
   If (BY>=Y) And (BY<=Y+22) Then Begin
    If (BX>=8) And (BX<=52) Then D^.TreeTop:=Max(0,D^.TreeTop-D^.Rows);
    If (BX>=58) And (BX<=102) Then D^.TreeTop:=Min(Max(0,D^.TreeCount-D^.Rows),D^.TreeTop+D^.Rows);
    If (BX>=216) And (BX<=278) Then OFSelect(D^,D^.Selected-D^.Rows);
    If (BX>=284) And (BX<=346) Then OFSelect(D^,D^.Selected+D^.Rows);
    D^.Dirty:=True;
   End;
   If (BY>=D^.H-116) And (BY<=D^.H-94) Then Focus(0);
   If (BY>=D^.H-87) And (BY<=D^.H-65) Then Begin
    Focus(4); OFChooseFilter(D^);
   End;
   If (BY>=D^.H-56) And (BY<=D^.H-34) Then Begin
    If (BX>=10) And (BX<=72) Then Begin If D^.Focus<>3 Then Focus(0); OFEdit(D^,#3,#0); End;
    If (BX>=78) And (BX<=140) Then Begin If D^.Focus<>3 Then Focus(0); OFEdit(D^,#22,#0); End;
    If (BX>=146) And (BX<=218) Then Begin
     If D^.Focus=3 Then D^.Address:='' Else D^.Name:='';
     D^.Cursor:=0; D^.Anchor:=0; D^.Dirty:=True;
    End;
    If (BX>=D^.W-180-24*Ord(Saving)) And (BX<=D^.W-100) Then OFAccept(D^);
    If (BX>=D^.W-92) And (BX<=D^.W-12) Then D^.Done:=True;
   End;
  End;
  PrevB:=MB; Delay(10);
 Until D^.Done;
 If D^.Accepted Then Begin
  FileName:=D^.Name; PaintFileDialog:=True;
  If Saving Then Case D^.Filter Of 2: SaveFormat:=FMT_GIF; 3:
  SaveFormat:=FMT_PNG;
   21: SaveFormat:=FMT_PCX;
   4: SaveFormat:=FMT_JPEG;
   25: SaveFormat:=FMT_PAS;
   12: SaveFormat:=FMT_BGX;
   5: SaveFormat:=FMT_XBM;
   18: SaveFormat:=FMT_PPM;
   15: SaveFormat:=FMT_APNG;
   16: SaveFormat:=FMT_ARW;
   17: SaveFormat:=FMT_CR2;
   14: SaveFormat:=FMT_DCM;
   13: SaveFormat:=FMT_DDS;
   6: SaveFormat:=FMT_WPG;
   10: SaveFormat:=FMT_EXR;
   9: SaveFormat:=FMT_FAX; Else SaveFormat:=FMT_BMP; End;
 End;
 Dispose(D); MenuActive:=False; RedrawInterface;
End;

Function OpenImageDialog(Var FileName: String): Boolean;
Var Format: Byte;
Begin
 Format:=FMT_BMP; OpenImageDialog:=PaintFileDialog(FileName,False,Format);
End;

Function SaveAsCurrentImage: Boolean;
Var Name: String; Format: Byte;
Begin
 SaveAsCurrentImage:=False; Name:=ImageBuffer.FileName; Format:=ImageBuffer.Format;
 If Not (Format In
 [FMT_BMP,FMT_GIF,FMT_PNG,FMT_PCX,FMT_JPEG,FMT_PAS,
 FMT_BGX,FMT_XBM,FMT_PPM,FMT_APNG,FMT_ARW,FMT_CR2,FMT_DCM,
 FMT_DDS,FMT_WPG,FMT_EXR,FMT_FAX])
 Then
 Format:=FMT_PNG;
 Repeat
  If Not PaintFileDialog(Name,True,Format) Then Exit;
  If SaveImage(Name,Format) Then Begin SaveAsCurrentImage:=True; RedrawInterface; Exit; End;
  ShowMessage('Enregistrement impossible',PaintSaveError);
 Until False;
End;


Procedure OpenImageCommand;
Var Name: String; Backup: PHistoryData; Metadata: TImageBuffer;
    OldZoom,OldX,OldY: Integer; Item: PHistoryItem;
Begin
 Name:='';
 If Not OpenImageDialog(Name) Then Exit;
 If Not ConfirmDiscardChanges Then Exit;
 Backup:=SaveFullSnapshot;
 If Backup=Nil Then Begin ShowMessage('Ouvrir','Impossible de proteger l''image courante.'); Exit; End;
 Metadata:=ImageBuffer; OldZoom:=ZoomLevel; OldX:=ZOriginX; OldY:=ZOriginY;
 If LoadImage(Name) Then Begin
  While UndoList<>Nil Do Begin
   Item:=UndoList; UndoList:=Item^.Next;
   FreeHistoryData(PHistoryData(Item^.Data)); Dispose(Item);
  End;
  While RedoList<>Nil Do Begin
   Item:=RedoList; RedoList:=Item^.Next;
   FreeHistoryData(PHistoryData(Item^.Data)); Dispose(Item);
  End;
  UndoCount:=0; RedoCount:=0; ImageBuffer.Modified:=False;
  ZoomLevel:=100; ZOriginX:=0; ZOriginY:=0;
  SelectionActive:=False;
 End Else Begin
  RestoreFullSnapshot(Backup); ImageBuffer:=Metadata;
  ZoomLevel:=OldZoom; ZOriginX:=OldX; ZOriginY:=OldY;
  RedrawInterface;
  ShowMessage('Ouvrir','Fichier invalide, format non reconnu ou lecture impossible. Image conservee.');
 End;
 FreeHistoryData(Backup); RedrawInterface;
End;


{ Construction temporaire d'un polygone : aucun pixel du document n'est
  modifie avant validation. Une seule entree Annuler pour la forme complete. }
Procedure PolygonPaint;
Var I,X,Y: Integer; Previous: ViewPortType;
Begin
 If (PolygonCount=0) Or (CurrentTool<>TOOL_POLYGON) Then Exit;
 ZBeginView(Previous); SetWriteMode(XORPut); SetColor(White);
 SetLineStyle(SolidLn,0,NormWidth);
 For I:=1 To PolygonCount-1 Do
  Line(ZViewX(PolygonX[I-1]),ZViewY(PolygonY[I-1]),ZViewX(PolygonX[I]),ZViewY(PolygonY[I]));
 If PolygonHover Then Begin
  SetLineStyle(DottedLn,0,NormWidth);
  Line(ZViewX(PolygonX[PolygonCount-1]),ZViewY(PolygonY[PolygonCount-1]),
       ZViewX(PolygonMouseX),ZViewY(PolygonMouseY));
  If PolygonCount>=2 Then Line(ZViewX(PolygonMouseX),ZViewY(PolygonMouseY),ZViewX(PolygonX[0]),ZViewY(PolygonY[0]));
 End;
 SetLineStyle(SolidLn,0,NormWidth);
 For I:=0 To PolygonCount-1 Do Begin
  X:=ZViewX(PolygonX[I]); Y:=ZViewY(PolygonY[I]);
  Rectangle(X-2,Y-2,X+2,Y+2);
 End;
 SetWriteMode(CopyPut); ZEndView(Previous);
End;

Procedure PolygonPreview;
Begin
 PolygonPaint;
 PolygonOverlayValid:=(PolygonCount>0) And (CurrentTool=TOOL_POLYGON);
End;

Procedure ErasePolygonPreview;
Begin
 If PolygonOverlayValid Then PolygonPaint;
 PolygonOverlayValid:=False;
End;

Procedure PolygonCancel;
Begin
 If PolygonCount=0 Then Exit;
 PolygonCount:=0; PolygonHover:=False; RedrawInterface;
End;

Procedure PolygonFinish;
Var I,J,K,Count,MinY,MaxY,Y,SwapX: Integer;
    Crossings: Array[0..255] Of Integer; CX: LongInt;
Begin
 If PolygonCount<3 Then Begin PolygonCancel; Exit; End;
 AddSnapshotToHistory(TOOL_POLYGON);
 If FillStyle>0 Then Begin
  MinY:=PolygonY[0]; MaxY:=MinY;
  For I:=1 To PolygonCount-1 Do Begin MinY:=Min(MinY,PolygonY[I]); MaxY:=Max(MaxY,PolygonY[I]); End;
  { Remplissage pair/impair, sommets superieurs exclus pour eviter de
    compter deux fois une intersection commune a deux aretes. }
  For Y:=MinY To MaxY Do Begin
   Count:=0; J:=PolygonCount-1;
   For I:=0 To PolygonCount-1 Do Begin
    If ((PolygonY[I]<=Y) And (PolygonY[J]>Y)) Or
       ((PolygonY[J]<=Y) And (PolygonY[I]>Y)) Then Begin
     CX:=PolygonX[I]+LongInt(Y-PolygonY[I])*(PolygonX[J]-PolygonX[I]) Div (PolygonY[J]-PolygonY[I]);
     Crossings[Count]:=CX; Inc(Count);
    End;
    J:=I;
   End;
   For I:=1 To Count-1 Do Begin
    SwapX:=Crossings[I]; K:=I-1;
    While K>=0 Do Begin
     If Crossings[K]<=SwapX Then Break;
     Crossings[K+1]:=Crossings[K]; Dec(K);
    End;
    Crossings[K+1]:=SwapX;
   End;
   I:=0;
   While I+1<Count Do Begin ZLine(Crossings[I]-CanvasX,Y-CanvasY,Crossings[I+1]-CanvasX,Y-CanvasY,CurrentColor); Inc(I,2); End;
  End;
 End;
 J:=PolygonCount-1;
 For I:=0 To PolygonCount-1 Do Begin ZLine(PolygonX[J]-CanvasX,PolygonY[J]-CanvasY,PolygonX[I]-CanvasX,PolygonY[I]-CanvasY,CurrentColor); J:=I; End;
 ImageBuffer.Modified:=True;
 PolygonCount:=0; PolygonHover:=False; RedrawInterface;
End;

Function PolygonNear(X,Y,PX,PY: Integer): Boolean;
Begin
 PolygonNear:=(Abs(LongInt(X)-PX)*ZoomLevel<=500) And (Abs(LongInt(Y)-PY)*ZoomLevel<=500);
End;

Procedure PolygonClick(X,Y: Integer);
Var Now,Elapsed: LongInt;
Begin
 Now:=ToolTipClock; Elapsed:=Now-PolygonLastClick;
 If Elapsed<0 Then Inc(Elapsed,8640000);
 If PolygonCount>=3 Then Begin
  If PolygonNear(X,Y,PolygonX[0],PolygonY[0]) Or
     ((Elapsed<45) And PolygonNear(X,Y,PolygonX[PolygonCount-1],PolygonY[PolygonCount-1])) Then Begin
   PolygonFinish; Exit;
  End;
 End;
 If PolygonCount>0 Then
  If (X=PolygonX[PolygonCount-1]) And (Y=PolygonY[PolygonCount-1]) Then Exit;
 If PolygonCount>=256 Then Exit;
 PolygonX[PolygonCount]:=X; PolygonY[PolygonCount]:=Y; Inc(PolygonCount);
 PolygonMouseX:=X; PolygonMouseY:=Y; PolygonHover:=True; PolygonLastClick:=Now;
 EraseSelection; SelectionActive:=False; RedrawInterface;
End;


{ Proprietes du document : informations calculees et metadonnees persistantes.
  Les changements restent locaux jusqu'a Appliquer/OK/Enregistrer. }
Procedure ImagePropertiesDialog;
Var Draft: TPaintMetadata; Editor: POFState; X,Y,W,H,Tab,Focus,I,J,MX,MY,B,Prev,Used: Integer;
    Colors: Array[0..255] Of Boolean; R: SearchRec; DT: DateTime; Preview: TRect;
    DiskSize,N: LongInt; Stamp,Attributes,Notice,S,T: String; K,E: Char;
    Done,Dirty,Exists,Changed,Saved: Boolean;
 Function Editable(Index: Integer): Boolean;
 Begin
  Editable:=(ImageBuffer.Format=FMT_PNG) Or ((ImageBuffer.Format=FMT_GIF) And (Index=5));
 End;
 Function FieldName(Index: Integer): String;
 Begin
  Case Index Of
   0: FieldName:='Titre'; 1: FieldName:='Auteur'; 2: FieldName:='Copyright';
   3: FieldName:='Logiciel'; 4: FieldName:='Description'; 5: FieldName:='Note (GIF/PNG)';
  Else FieldName:=''; End;
 End;
 Function YesNo(Value: Boolean): String;
 Begin If Value Then YesNo:='Oui' Else YesNo:='Non'; End;
 Procedure StoreField;
 Begin If (Tab=1) And (Focus<6) And Editable(Focus) Then Draft.Values[Focus]:=Editor^.Name; End;
 Procedure SetFocus(Value: Integer);
 Begin
  StoreField; Focus:=Value;
  If Focus<6 Then Begin
   Editor^.Name:=Draft.Values[Focus]; Editor^.Cursor:=Length(Editor^.Name); Editor^.Anchor:=Editor^.Cursor;
  End;
  Dirty:=True;
 End;
 Procedure FileDetails;
 Begin
  DiskSize:=0; Stamp:='Non enregistre'; Attributes:=''; Exists:=False;
  If ImageBuffer.FileName='' Then Exit;
  FindFirst(ImageBuffer.FileName,AnyFile,R);
  If DosError=0 Then Begin
   Exists:=True; DiskSize:=R.Size; UnpackTime(R.Time,DT);
   Stamp:=APTwoDigits(DT.Day)+'/'+APTwoDigits(DT.Month)+'/'+IntToStr(DT.Year)+' '+APTwoDigits(DT.Hour)+':'+APTwoDigits(DT.Min);
   If (R.Attr And ReadOnly)<>0 Then Attributes:='Lecture seule ' Else Attributes:='Accessible en ecriture ';
   If (R.Attr And Hidden)<>0 Then Attributes:=Attributes+' / cache';
  End;
  {$IFDEF FPC}FindClose(R);{$ENDIF}
 End;
 Function Apply: Boolean;
 Begin
  Apply:=False; StoreField;
  Changed:=CompareByte(Draft,ImageBuffer.Metadata,SizeOf(Draft))<>0;
  If Draft.Limited Then Begin
   If PromptYesNoCancel('Remplacement des textes importes',
    'Certains textes depassent 255 caracteres ou Latin-1. Remplacer par les champs affiches ?')<>1 Then Begin Dirty:=True; Exit; End;
   Draft.Limited:=False; Changed:=True;
  End;
  If Changed Then Begin ImageBuffer.Metadata:=Draft; ImageBuffer.Modified:=True; End;
  Notice:='Champs appliques au document. Enregistrer pour les ecrire dans le fichier.';
  Apply:=True; Dirty:=True;
 End;
 Procedure Activate(Button: Integer);
 Begin
  Case Button Of
   0: If Apply Then Done:=True;
   1: Apply;
   2: Done:=True;
   3: If Apply Then Begin
    Saved:=SaveCurrentImage; FileDetails;
    If Saved Then Notice:='Fichier enregistre avec les champs disponibles dans ce format.';
    Dirty:=True;
   End;
   4: Begin
    ShowMessage('Textes et enregistrement','PNG : titre, auteur, droits, logiciel, description et commentaire. GIF : commentaire seul.');
    ShowMessage('Edition','255 caracteres Latin-1 par champ. Tab, fleches, Ctrl+A/C/X/V. Appliquer ne modifie pas encore le fichier.');
    Dirty:=True;
   End;
  End;
 End;
 Procedure KeyValue(Row: Integer; Const LabelText,Value: String);
 Begin
  SetColor(DarkGray); OutTextXY(X+14,Y+82+Row*22,LabelText);
  SetColor(Black); OutTextXY(X+168,Y+82+Row*22,OFShort(Value,W-390));
 End;
 Procedure Field(Index: Integer);
 Var XX,YY,WW,Offset,Lo,Hi,LeftPos,RightPos,Caret: Integer; Value: String;
 Begin
  XX:=X+158; YY:=Y+124+Index*39; WW:=W-174;
  SetColor(Black); OutTextXY(X+12,YY+7,FieldName(Index));
  If Editable(Index) Then SetFillStyle(SolidFill,White) Else SetFillStyle(SolidFill,LightGray);
  Bar(XX,YY,XX+WW,YY+23);
  If Focus=Index Then SetColor(Blue) Else SetColor(DarkGray); Rectangle(XX,YY,XX+WW,YY+23);
  Value:=Draft.Values[Index]; If Focus=Index Then Value:=Editor^.Name;
  { Les sauts de ligne importes restent stockes, mais se lisent sur une ligne. }
  For Caret:=1 To Length(Value) Do If Value[Caret]<' ' Then Value[Caret]:=' ';
  Offset:=0;
  If Focus=Index Then While TextWidth(Copy(Value,Offset+1,Editor^.Cursor-Offset))+12>WW Do Inc(Offset);
  SetColor(Black); If Not Editable(Index) Then SetColor(DarkGray);
  OutTextXY(XX+5,YY+7,OFShort(Copy(Value,Offset+1,255),WW-12));
  If (Focus=Index) And Editable(Index) Then Begin
   Lo:=Min(Editor^.Cursor,Editor^.Anchor); Hi:=Max(Editor^.Cursor,Editor^.Anchor);
   LeftPos:=XX+5+TextWidth(Copy(Value,Offset+1,Max(0,Lo-Offset)));
   RightPos:=Min(XX+WW-4,XX+5+TextWidth(Copy(Value,Offset+1,Max(0,Hi-Offset))));
   If (Hi>Lo) And (RightPos>LeftPos) Then Begin
    SetFillStyle(SolidFill,LightBlue); Bar(LeftPos,YY+4,RightPos,YY+19);
    SetColor(Black); OutTextXY(LeftPos,YY+7,OFShort(Copy(Value,Max(Lo,Offset)+1,Hi-Max(Lo,Offset)),RightPos-LeftPos));
   End;
   Caret:=XX+5+TextWidth(Copy(Value,Offset+1,Editor^.Cursor-Offset));
   SetColor(Black); Line(Caret,YY+4,Caret,YY+19);
  End;
 End;
 Procedure DrawPreview;
 Var PW,PH,PX,PY,L,T: Integer;
 Begin
  PERect(Preview,X+W-200,Y+80,184,154); RFChecker(Preview); PEBevel(Preview,True);
  If Not PGHasImage Then Exit;
  RFFitSize(CanvasImageW,CanvasImageH,176,146,PW,PH);
  L:=Preview.Left+(184-PW) Div 2; T:=Preview.Top+(154-PH) Div 2;
  For PY:=0 To PH-1 Do For PX:=0 To PW-1 Do
   PutPixel(L+PX,T+PY,ZImagePixel((LongInt(PX)*CanvasImageW) Div PW,(LongInt(PY)*CanvasImageH) Div PH));
 End;
 Procedure Draw;
 Var I: Integer;
 Begin
  HideMouse; SetFillStyle(SolidFill,LightGray); Bar(X,Y,X+W,Y+H);
  SetColor(DarkGray); Rectangle(X,Y,X+W,Y+H);
  SetFillStyle(SolidFill,Blue); Bar(X+1,Y+1,X+W-1,Y+24);
  SetColor(White); OutTextXY(X+12,Y+8,'Proprietes de l''image');
  OFButton(X+12,Y+32,150,'Informations',Tab=0); OFButton(X+168,Y+32,150,'Metadonnees',Tab=1);
  If Tab=0 Then Begin
   S:=OFBase(ImageBuffer.FileName); If S='' Then S:='Sans titre';
   KeyValue(0,'Nom',S); KeyValue(1,'Format source',APFormatName(ImageBuffer.Format));
   KeyValue(2,'Dimensions',IntToStr(ImageBuffer.Width)+' x '+IntToStr(ImageBuffer.Height)+' px');
   KeyValue(3,'Profondeur source',IntToStr(ImageBuffer.BitDepth)+' bits / pixel');
   KeyValue(4,'Canevas PAINT','8 bits indexes / 256 entrees');
   KeyValue(5,'Couleurs utilisees',IntToStr(Used));
   KeyValue(6,'Transparence',YesNo(ImageBuffer.HasTransparency));
   KeyValue(7,'Modifications',YesNo(ImageBuffer.Modified));
   If Exists Then KeyValue(8,'Taille sur disque',STMemoryText(DiskSize)+' ('+IntToStr(DiskSize)+' octets)')
   Else KeyValue(8,'Taille sur disque','Fichier absent / nouveau');
   KeyValue(9,'Memoire des pixels',STMemoryText(LongInt(CanvasImageW)*CanvasImageH));
   KeyValue(10,'Date du fichier',Stamp); KeyValue(11,'Acces',Attributes);
   DrawPreview;
   SetColor(Black); OutTextXY(X+W-198,Y+244,'Apercu du document');
   OutTextXY(X+W-198,Y+270,'Exports : 17 formats disponibles');
   OutTextXY(X+W-198,Y+288,'GIF : note uniquement');
   OutTextXY(X+W-198,Y+306,'PNG : six champs texte');
   If ImageBuffer.HasHotspot Then Begin
    OutTextXY(X+W-198,Y+324,'Point chaud : '+
     IntToStr(ImageBuffer.HotspotX)+', '+IntToStr(ImageBuffer.HotspotY));
    OutTextXY(X+W-198,Y+342,'Images CUR : '+
     IntToStr(ImageBuffer.CursorImages));
   End;
   OutTextXY(X+12,Y+354,'Chemin : '+OFShort(ImageBuffer.FileName,W-100));
  End Else Begin
   SetColor(Black);
   If ImageBuffer.Format=FMT_PNG Then S:='PNG : les six champs sont lus et enregistres dans le fichier.'
   Else If ImageBuffer.Format=FMT_GIF Then S:='GIF : seule la note / le commentaire peut etre modifie.'
   Else S:='Lecture seule pour ce format. Enregistrez en PNG pour editer ces champs.';
   OutTextXY(X+12,Y+78,OFShort(S,W-24));
   If Draft.Limited Then Begin SetColor(Red); S:='Textes longs / Unicode : remplacement soumis a confirmation.'; End
   Else Begin SetColor(DarkGray); S:='255 caracteres par champ. Ctrl+A/C/X/V : selection et presse-papiers.'; End;
   OutTextXY(X+12,Y+100,OFShort(S,W-24));
   For I:=0 To 5 Do Field(I);
  End;
  SetColor(DarkGray); OutTextXY(X+12,Y+H-65,OFShort(Notice,W-24));
  For I:=0 To 4 Do Begin
   Case I Of 0:S:='OK'; 1:S:='Appliquer'; 2:S:='Annuler'; 3:S:='Enregistrer'; 4:S:='Aide'; End;
   OFButton(X+12+I*((W-24) Div 5),Y+H-40,(W-34) Div 5,S,Focus=I+6);
  End;
  ShowMouse; Dirty:=False;
 End;
Begin
 Editor:=POFState(JDAllocate(SizeOf(TOFState))); If Editor=Nil Then Exit;
 FillChar(Editor^,SizeOf(TOFState),0); Draft:=ImageBuffer.Metadata;
 X:=10; W:=Min(760,ScreenWidth-20); H:=Min(520,ScreenHeight-20);
 X:=(ScreenWidth-W) Div 2; Y:=(ScreenHeight-H) Div 2;
 Tab:=0; Focus:=6; Done:=False; Dirty:=True; Used:=0;
 FillChar(Colors,SizeOf(Colors),0);
 If CanvasImage<>Nil Then For N:=0 To LongInt(CanvasImageW)*CanvasImageH-1 Do Colors[PPNBytes(CanvasImage)^[N]]:=True;
 For I:=0 To 255 Do If Colors[I] Then Inc(Used);
 FileDetails; Notice:='F1 : informations   F2 : metadonnees   Echap : annuler';
 GetMouseStateLocal(MX,MY,Prev);
 Repeat
  If Dirty Then Draw;
  If KeyPressed Then Begin
   K:=ReadKey; E:=#0; If K=#0 Then E:=ReadKey;
   If K=#27 Then Done:=True
   Else If (K=#0) And (E In [#59,#60]) Then Begin StoreField; Tab:=Ord(E)-59; SetFocus(6); End
   Else If K=#9 Then Begin
    J:=Focus;
    Repeat J:=(J+1) Mod 11; Until (J>=6) Or ((Tab=1) And Editable(J));
    SetFocus(J);
   End Else If K=#13 Then Begin If Focus>=6 Then Activate(Focus-6) Else Activate(0); End
   Else If (K=' ') And (Focus>=6) Then Activate(Focus-6)
   Else If (Tab=1) And (Focus<6) And (Editable(Focus) Or (K In [#1,#3])) Then Begin OFEdit(Editor^,K,E); Dirty:=True; End;
  End;
  GetMouseStateLocal(MX,MY,B);
  If ((B And 1)<>0) And ((Prev And 1)=0) Then Begin
   If (MY>=Y+32) And (MY<=Y+54) Then Begin
    If (MX>=X+12) And (MX<=X+162) Then Begin StoreField; Tab:=0; SetFocus(6); End;
    If (MX>=X+168) And (MX<=X+318) Then Begin StoreField; Tab:=1; SetFocus(6); End;
   End;
   If Tab=1 Then For J:=0 To 5 Do
    If (MX>=X+158) And (MX<=X+W-16) And (MY>=Y+124+J*39) And (MY<=Y+147+J*39) Then SetFocus(J);
   If (MY>=Y+H-40) And (MY<=Y+H-18) And (MX>=X+12) And (MX<X+W-12) Then Begin
    J:=(MX-X-12) Div ((W-24) Div 5); If J<=4 Then Begin SetFocus(J+6); Activate(J); End;
   End;
  End;
  Prev:=B; Delay(10);
 Until Done;
 FreeMem(Editor,SizeOf(TOFState)); RedrawInterface;
End;

Procedure HandleMenuClick(MenuIndex, ItemIndex: Integer);
Var
 NewName: String;
 Fmt: Byte;
 InfoMsg: String;
 NewW, NewH, ValErr: Integer;
Begin
 PolygonCancel;
 Case MenuIndex of
  MENU_FILE: Begin
   Case ItemIndex of
    0: Begin { Nouveau }
     AddSnapshotToHistory(TOOL_PENCIL);
     { Reinitialiser la palette aux 16 couleurs VGA standard. Si une image
       avait ete chargee, sa palette restait active et etait sauvegardee
       avec la nouvelle image. }
     InitImage;
     InitPalette;
     ActivePaletteSlot := 0;
     PEInstallDocumentPalette;
     If Not ZPrepareBuffer(ImageBuffer.Width,ImageBuffer.Height,BackgroundColor) Then Begin
      ShowMessage('Nouveau','Memoire insuffisante.'); Exit;
     End;
     ClearImage;
     If (CanvasImage <> Nil) and (CanvasImageW > 0) and (CanvasImageH > 0) Then
      FillChar(CanvasImage^, CanvasImageW * CanvasImageH, BackgroundColor);
     ImageBuffer.FileName := '';
     ImageBuffer.Modified := False;
     DrawStatusBar;
    End;
    1: OpenImageCommand; { Ouvrir : explorateur graphique Pascal }
    2: Begin SaveCurrentImage; End;
    3: Begin SaveAsCurrentImage; End;
    5: Begin { Imprimer }
     ShowMessage('Imprimer', 'Impression non disponible.');
    End;
    7: ImagePropertiesDialog; { Proprietes detaillees et textes persistants }
    9: If ConfirmDiscardChanges Then Running := False; { Quitter }
   End;
  End;
  MENU_EDIT: Begin
   Case ItemIndex of
    0: Undo;
    1: Redo;
    3: Begin { Couper }
    End;
    4: Begin { Copier }
    End;
    5: Begin { Coller }
    End;
    6: Begin { Effacer sélection }
     If SelectionActive Then Begin
      AddSnapshotToHistory(TOOL_SELECT);
      EraseSelection;
      DrawRectangle(SelectionRect.Left,SelectionRect.Top,
                    SelectionRect.Right,SelectionRect.Bottom,BackgroundColor,True);
      SelectionActive := False;
      ImageBuffer.Modified := True;
     End;
    End;
    8: Begin { Tout sélectionner }
     SelectionActive := True;
     SelectionRect.Left := CanvasX;
     SelectionRect.Top := CanvasY;
     SelectionRect.Right := CanvasX + ImageBuffer.Width - 1;
     SelectionRect.Bottom := CanvasY + ImageBuffer.Height - 1;
    End;
   End;
  End;
  MENU_VIEW: Begin
   Case ItemIndex of
    0: Begin { Barre d'outils }
     Menus[MENU_VIEW].Items[0].Checked := Not Menus[MENU_VIEW].Items[0].Checked;
    End;
    1: Begin { Barre de couleurs }
     Menus[MENU_VIEW].Items[1].Checked := Not Menus[MENU_VIEW].Items[1].Checked;
    End;
    2: Begin { Barre d'état }
     Menus[MENU_VIEW].Items[2].Checked := Not Menus[MENU_VIEW].Items[2].Checked;
    End;
    4: Begin ZZoomStep(True); End;
    5: Begin ZZoomStep(False); End;
    7: Begin { Plein écran }
    End;
   End;
  End;
  MENU_IMAGE: Begin
   Case ItemIndex of
    0: Begin { Retourner/Pivoter : choix visuel et apercu avant/apres }
     FlipRotateDialog;
    End;
    1: Begin { Etirer/Incliner : reglages visuels, filtres RVB et apercus }
     StretchSkewDialog;
    End;
    2: Begin AddSnapshotToHistory(TOOL_PENCIL); InvertColors; End;
    4: Begin { Redimensionner : dialogue visuel dedie }
     ResizeImageDialog;
    End;
    5: Begin { Rogner }
     If SelectionActive Then Begin
      AddSnapshotToHistory(TOOL_PENCIL);
      CropImage;
     End
     Else
      ShowMessage('Rogner',
                  'Selectionnez d''abord une zone avec l''outil Selection.');
    End;
    7: Begin { Attributs : statistiques, graphiques et rapport }
     ImageAttributesDialog;
    End;
    9: Begin AddSnapshotToHistory(TOOL_PENCIL); ClearImage; End;
   End;
  End;
  MENU_COLORS: Begin
   Case ItemIndex of
    0: Begin { Modifier palette }
     EditPaintPalette;
    End;
    1: Begin { Obtenir couleurs }
     ObtainPaintColors;
    End;
   End;
  End;
  MENU_HELP: Begin
   Case ItemIndex of
    0: Begin { Aide }
    End;
    1: Begin { À propos }
      Str(VERSION_MAJOR, InfoMsg);
      Str(VERSION_MINOR, NewName);
      ShowMessage('A propos de PAINT',
            PROGRAM_NAME + #10 +
            'Version : ' + InfoMsg + '.' + NewName + #10 +
            'Auteur : Sylvain Maltais' + #10 +
            'Creation du produit : 2024' + #10 +
            'Copyright (c) 2026 Sylvain Maltais' + #10 +
            'Licence : MIT (voir LICENSE)' + #10 +
            'Contact : support@gladir.com' + #10 +
            'www.gladir.com/clonedraw');
    End;
   End;
  End;
 End;

 MenuActive := False;
 RedrawInterface;
End;

Procedure HandleToolbarClick(X, Y: Integer);
Var
 ToolIndex: Integer;
 ToolsPerRow: Integer;
 ToolX, ToolY: Integer;
Begin
 ToolsPerRow := 2;
 ToolX := (X - 5) div 23;
 ToolY := (Y - MENUBAR_HEIGHT - 5) div 23;

 If (ToolX >= 0) and (ToolX < ToolsPerRow) and (ToolY >= 0) and (ToolY < 8) Then Begin
  ToolIndex := ToolY * ToolsPerRow + ToolX;
  If (ToolIndex >= 0) and (ToolIndex <= 14) Then Begin
   If CurrentTool<>ToolIndex Then PolygonCancel;
   CurrentTool := ToolIndex;
   DrawToolbar;
  End;
 End;
End;

Procedure HandleColorClick(X, Y: Integer);
Var
 PaletteY: Integer;
 ColorBoxSize: Integer;
 ColorIndex: Integer;
 ColorX, ColorY: Integer;
Begin
 PaletteY := ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT;
 ColorBoxSize := 16;

 { Vérifier si le clic est dans la palette }
 If (X >= 50) and (Y >= PaletteY + 5) Then Begin
  ColorX := (X - 50) div (ColorBoxSize + 2);
  ColorY := (Y - PaletteY - 5) div (ColorBoxSize + 2);

  If (ColorX >= 0) and (ColorX < 14) and (ColorY >= 0) and (ColorY < 2) Then Begin
   ColorIndex := ColorY * 14 + ColorX;
   If ColorIndex < 28 Then Begin
   ActivePaletteSlot := ColorIndex;
    If (MouseButtons and 1) <> 0 Then
     CurrentColor := StandardPalette[ColorIndex]
    Else If (MouseButtons and 2) <> 0 Then
     BackgroundColor := StandardPalette[ColorIndex];
    DrawColorPalette;
   End;
  End;
 End;
End;

Procedure HandleCanvasClick(X, Y: Integer);
Begin
 If CurrentTool=TOOL_POLYGON Then Begin PolygonClick(X,Y); Exit; End;
 If Drawing Then Exit;
 If CurrentTool In [TOOL_ERASER,TOOL_FILL,TOOL_PENCIL,TOOL_BRUSH,
                    TOOL_AIRBRUSH,TOOL_LINE,TOOL_RECT,TOOL_ELLIPSE,TOOL_ROUNDRECT] Then
  AddSnapshotToHistory(CurrentTool);
 If (CurrentTool<>TOOL_SELECT) And (CurrentTool<>TOOL_MAGNIFY) And
    (CurrentTool<>TOOL_PICKER) Then Begin EraseSelection; SelectionActive:=False; End;

 Case CurrentTool of
  TOOL_SELECT: Begin
   { Effacer les anciennes "marching ants" si presentes. }
   EraseSelection;
   SelectionActive := True;
   SelectionRect.Left := X;
   SelectionRect.Top := Y;
   SelectionRect.Right := X;
   SelectionRect.Bottom := Y;
   Drawing := True;
   StartX := X;
   StartY := Y;
   RubberValid := False;
  End;
  TOOL_ERASER: Begin
   Drawing := True;
   EraseTool(X, Y);
  End;
  TOOL_FILL: Begin
   FloodFillArea(X,Y,CurrentColor,ZImagePixel(X-CanvasX,Y-CanvasY));
  End;
  TOOL_PICKER: Begin
   ColorPicker(X, Y);
  End;
  TOOL_MAGNIFY: Begin
   ZSetZoom(ZoomLevel*2,CanvasX+ZViewX(X),CanvasY+ZViewY(Y));
  End;
  TOOL_PENCIL: Begin
   Drawing := True;
   DrawPixel(X, Y, CurrentColor);
  End;
  TOOL_BRUSH: Begin
   Drawing := True;
   DrawWithBrush(X, Y, CurrentColor);
  End;
  TOOL_AIRBRUSH: Begin
   Drawing := True;
   DrawWithAirbrush(X, Y, CurrentColor);
  End;
  TOOL_TEXT: Begin
   TextX := X;
   TextY := Y;
   TextInsertMode := True;
   TextInput := '';
   TextPrevW := 0;
   TextPrevH := 0;
   DrawTextPreview;
  End;
  TOOL_LINE, TOOL_RECT, TOOL_ELLIPSE, TOOL_ROUNDRECT, TOOL_CURVE: Begin
   Drawing := True;
   StartX := X;
   StartY := Y;
   EndX := X;
   EndY := Y;
   PreviewValid := False;
  End;
 End;
End;

Procedure HandleCanvasDrag(X, Y: Integer);
Begin
 If Not Drawing Then Exit;

 Case CurrentTool of
  TOOL_SELECT: Begin
   { Effacer le rectangle precedent (XOR) puis dessiner le nouveau. }
   If RubberValid Then
    XorRubberRect(RubberL, RubberT, RubberR, RubberB);
   SelectionRect.Right := X;
   SelectionRect.Bottom := Y;
   RubberL := SelectionRect.Left;
   RubberT := SelectionRect.Top;
   RubberR := X;
   RubberB := Y;
   XorRubberRect(RubberL, RubberT, RubberR, RubberB);
   RubberValid := True;
  End;
  TOOL_ERASER: Begin
   EraseTool(X, Y);
  End;
  TOOL_PENCIL: Begin
   DrawLine(ZEventX(OldMouseX),ZEventY(OldMouseY),X,Y,CurrentColor);
  End;
  TOOL_BRUSH: Begin
   DrawWithBrush(X, Y, CurrentColor);
  End;
  TOOL_AIRBRUSH: Begin
   DrawWithAirbrush(X, Y, CurrentColor);
  End;
  TOOL_LINE, TOOL_RECT, TOOL_ELLIPSE, TOOL_ROUNDRECT: Begin
   { Effacer l'aperçu précédent et dessiner le nouveau }
   If PreviewValid Then
    XorPreviewShape(PreviewTool, PreviewL, PreviewT, PreviewR, PreviewB);
   EndX := X;
   EndY := Y;
   PreviewTool := CurrentTool;
   PreviewL := StartX;
   PreviewT := StartY;
   PreviewR := X;
   PreviewB := Y;
   XorPreviewShape(PreviewTool, PreviewL, PreviewT, PreviewR, PreviewB);
   PreviewValid := True;
  End;
 End;
End;

Procedure HandleCanvasRelease(X, Y: Integer);
Var
 CenterX, CenterY, RadiusX, RadiusY: Integer;
Begin
 If (CurrentTool=TOOL_POLYGON) And (PolygonCount=1) Then Begin
  If Not PolygonNear(X,Y,PolygonX[0],PolygonY[0]) Then PolygonClick(X,Y);
  Exit;
 End;
 If Not Drawing Then Exit;
 Drawing := False;

 { Effacer l'apercu XOR des formes (ligne/rect/ellipse/rectarrondi). }
 If PreviewValid Then Begin
  XorPreviewShape(PreviewTool, PreviewL, PreviewT, PreviewR, PreviewB);
  PreviewValid := False;
 End;

 Case CurrentTool of
  TOOL_SELECT: Begin
   { Effacer le dernier rectangle XOR temporaire. }
   If RubberValid Then Begin
    XorRubberRect(RubberL, RubberT, RubberR, RubberB);
    RubberValid := False;
   End;
   SelectionRect.Right := X;
   SelectionRect.Bottom := Y;
   { Normaliser le rectangle de sélection }
   If SelectionRect.Left > SelectionRect.Right Then Begin
    CenterX := SelectionRect.Left;
    SelectionRect.Left := SelectionRect.Right;
    SelectionRect.Right := CenterX;
   End;
   If SelectionRect.Top > SelectionRect.Bottom Then Begin
    CenterX := SelectionRect.Top;
    SelectionRect.Top := SelectionRect.Bottom;
    SelectionRect.Bottom := CenterX;
   End;
   AntsPhase := 0;
   AntsCounter := 0;
   AntsValid := False;
   DrawSelection;
  End;
  TOOL_LINE: Begin
   DrawLine(StartX, StartY, X, Y, CurrentColor);
  End;
  TOOL_RECT: Begin
   DrawRectangle(StartX, StartY, X, Y, CurrentColor, FillStyle > 0);
  End;
  TOOL_ELLIPSE: Begin
   CenterX := (StartX + X) div 2;
   CenterY := (StartY + Y) div 2;
   RadiusX := Abs(X - StartX) div 2;
   RadiusY := Abs(Y - StartY) div 2;
   DrawEllipse(CenterX, CenterY, RadiusX, RadiusY, CurrentColor, FillStyle > 0);
  End;
  TOOL_ROUNDRECT: Begin
   DrawRoundRectShape(StartX, StartY, X, Y, 10, 10, CurrentColor, FillStyle > 0);
  End;
 End;
 If CurrentTool<>TOOL_SELECT Then RedrawInterface;
End;

{ --- Menu : hit-test et navigation (inspire de DEV-COOLS\DEVENV.PAS) --- }

Function MenuBarHitTest(MX, MY: Integer): Integer;
Var
 I, X1, X2: Integer;
Begin
 MenuBarHitTest := -1;
 If MY >= MENUBAR_HEIGHT Then Exit;
 For I := 0 to 5 do Begin
  X1 := Menus[I].X - 2;
  X2 := Menus[I].X + TextWidth(Menus[I].Title) + 2;
  If (MX >= X1) and (MX <= X2) Then Begin
   MenuBarHitTest := I;
   Exit;
  End;
 End;
End;

Function MenuItemHitTest(MX, MY, MenuIdx: Integer): Integer;
Var
 Idx, Top, Bot: Integer;
Begin
 MenuItemHitTest := -1;
 If (MenuIdx < 0) or (MenuIdx > 5) Then Exit;
 Top := MENUBAR_HEIGHT;
 Bot := Top + Menus[MenuIdx].ItemCount * 18 + 4;
 If (MX < Menus[MenuIdx].X) or
    (MX > Menus[MenuIdx].X + Menus[MenuIdx].Width) or
    (MY < Top) or (MY > Bot) Then Exit;
 Idx := (MY - Top - 2) div 18;
 If (Idx < 0) or (Idx >= Menus[MenuIdx].ItemCount) Then Exit;
 MenuItemHitTest := Idx;
End;

Procedure MenuNextItem(Step: Integer);
{ Step = +1 (suivant) ou -1 (precedent), saute les separateurs. }
Var
 N, I: Integer;
Begin
 If (ActiveMenu < 0) or (ActiveMenu > 5) Then Exit;
 N := Menus[ActiveMenu].ItemCount;
 If N <= 0 Then Exit;
 If ActiveMenuItem < 0 Then Begin
  If Step > 0 Then ActiveMenuItem := -1
  Else ActiveMenuItem := N;
 End;
 For I := 1 to N do Begin
  ActiveMenuItem := ActiveMenuItem + Step;
  If ActiveMenuItem < 0 Then ActiveMenuItem := N - 1;
  If ActiveMenuItem >= N Then ActiveMenuItem := 0;
  If Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator Then Exit;
 End;
End;

Procedure MenuSwitch(NewMenu: Integer);
Begin
 If (NewMenu < 0) or (NewMenu > 5) then Exit;
 ActiveMenu := NewMenu;
 ActiveMenuItem := -1;
 RedrawInterface;
End;

Procedure HandleMouseEvent;
Var
 NewButtons: Integer;
 ButtonPressed: Boolean;
 BarHit, ItemHit: Integer;
Begin
 GetMouseStateLocal(MouseX, MouseY, MouseButtons);
 If MouseButtons<>0 Then ResetToolTip;
 UpdateToolTip;

 { Detection de front montant du bouton gauche (evite la repetition
   d'action tant que l'utilisateur maintient le bouton enfonce). }
 ButtonPressed := ((MouseButtons and 1) <> 0) and ((OldMouseButtons and 1) = 0);

 { Survol : si un menu est ouvert, suivre la souris pour changer de menu
   ou mettre en evidence l'element sous le pointeur. }
 If MenuActive and ((MouseX <> OldMouseX) or (MouseY <> OldMouseY)) Then Begin
  BarHit := MenuBarHitTest(MouseX, MouseY);
  If (BarHit >= 0) and (BarHit <> ActiveMenu) Then Begin
   MenuSwitch(BarHit);
  End Else Begin
   ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
   If ItemHit <> ActiveMenuItem Then Begin
    ActiveMenuItem := ItemHit;
    DrawMenu(ActiveMenu);
   End;
  End;
 End;

 If (PolygonCount>0) And ((MouseButtons And 2)<>0) And ((OldMouseButtons And 2)=0) Then
  PolygonFinish;
 If ButtonPressed Then Begin
  If MenuBarHitTest(MouseX,MouseY)>=0 Then PolygonCancel;
  BarHit := MenuBarHitTest(MouseX, MouseY);
  If BarHit >= 0 Then Begin
   { Clic sur la barre de menu : ouvrir/basculer/fermer }
   If MenuActive and (ActiveMenu = BarHit) Then Begin
    MenuActive := False;
    RedrawInterface;
   End Else Begin
    MenuActive := True;
    ActiveMenu := BarHit;
    ActiveMenuItem := -1;
    RedrawInterface;
   End;
  End
  Else If MenuActive Then Begin
   { Clic dans un menu deroulant ouvert }
   ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
   If ItemHit >= 0 Then Begin
    If Not Menus[ActiveMenu].Items[ItemHit].Separator Then Begin
     ActiveMenuItem := ItemHit;
     HandleMenuClick(ActiveMenu, ItemHit);
     MenuActive := False;
     RedrawInterface;
    End;
   End Else Begin
    { Clic ailleurs : fermer le menu }
    MenuActive := False;
    RedrawInterface;
   End;
  End
  Else If (MouseX < TOOLBAR_WIDTH) and (MouseY > MENUBAR_HEIGHT) and
          (MouseY < ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT) Then Begin
   HandleToolbarClick(MouseX, MouseY);
  End
  Else If (MouseY >= ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT) and
          (MouseY < ScreenHeight - STATUSBAR_HEIGHT) Then Begin
   HandleColorClick(MouseX, MouseY);
  End
  Else If (MouseX >= CanvasX) and (MouseX < CanvasX + CanvasWidth) and
          (MouseY >= CanvasY) and (MouseY < CanvasY + CanvasHeight) Then Begin
   If ZHitCanvas(MouseX,MouseY) Then HandleCanvasClick(ZEventX(MouseX),ZEventY(MouseY));
  End;
 End
 Else If ((MouseButtons and 1) <> 0) and Drawing Then Begin
  { Bouton maintenu : continuer le trace sur le canvas }
  If (MouseX >= CanvasX) and (MouseX < CanvasX + CanvasWidth) and
     (MouseY >= CanvasY) and (MouseY < CanvasY + CanvasHeight) Then
   HandleCanvasDrag(ZEventX(MouseX),ZEventY(MouseY));
 End
 Else If ((MouseButtons and 1) = 0) and ((OldMouseButtons and 1) <> 0) Then Begin
  { Bouton relache (front descendant) }
  If Drawing Then
   HandleCanvasRelease(ZEventX(Min(CanvasX+ZDisplayWidth-1,Max(CanvasX,MouseX))),
                       ZEventY(Min(CanvasY+ZDisplayHeight-1,Max(CanvasY,MouseY))));
 End;

 { Apercu du prochain segment, meme sans bouton enfonce. }
 If (PolygonCount>0) And ((MouseX<>OldMouseX) Or (MouseY<>OldMouseY)) Then Begin
  HideMouse; ErasePolygonPreview;
  PolygonHover:=ZHitCanvas(MouseX,MouseY);
  If PolygonHover Then Begin PolygonMouseX:=ZEventX(MouseX); PolygonMouseY:=ZEventY(MouseY); End;
  PolygonPreview; ShowMouse;
 End;
 { Mise a jour de la barre d'etat si la souris a bouge }
 If (MouseX <> OldMouseX) or (MouseY <> OldMouseY) Then Begin
  DrawStatusBar;
  OldMouseX := MouseX;
  OldMouseY := MouseY;
 End;
 OldMouseButtons := MouseButtons;
End;

Procedure HandleKeyboardEvent;
Var
 Key: Char;
 ExtKey: Char;
Begin
 If Not KeyPressed Then Exit;
 ResetToolTip;

 Key := ReadKey;
 If PolygonCount>0 Then Begin
  Case Key Of
   #13: Begin PolygonFinish; Exit; End;
   #27,#26: Begin PolygonCancel; Exit; End;
   #8: Begin
    Dec(PolygonCount); RedrawInterface; Exit;
   End;
  End;
 End;

 { Touche étendue }
 If Key = #0 Then Begin
  ExtKey := ReadKey;
  { Navigation clavier dans un menu ouvert (inspire de DEVENV.PAS) }
  If MenuActive Then Begin
   Case ExtKey of
    #72: Begin { Fleche haut : item precedent }
     MenuNextItem(-1);
     RedrawInterface;
     Exit;
    End;
    #80: Begin { Fleche bas : item suivant }
     MenuNextItem(+1);
     RedrawInterface;
     Exit;
    End;
    #75: Begin { Fleche gauche : menu precedent }
     MenuSwitch((ActiveMenu + 5) mod 6);
     Exit;
    End;
    #77: Begin { Fleche droite : menu suivant }
     MenuSwitch((ActiveMenu + 1) mod 6);
     Exit;
    End;
   End;
  End;
  Case ExtKey of
   #59: Begin { F1 - Aide }
   End;
   #60: Begin { F2 }
   End;
   #68: If ConfirmDiscardChanges Then Running := False; { F10 - Quitter }
   #107: If ConfirmDiscardChanges Then Running := False; { Alt+F4 - Quitter }
   #33: Begin { Alt+F - Menu Fichier }
    MenuActive := True;
    ActiveMenu := MENU_FILE;
    ActiveMenuItem := -1;
    RedrawInterface;
   End;
   #50: Begin { Alt+M - Menu Modifier }
    MenuActive := True;
    ActiveMenu := MENU_EDIT;
    ActiveMenuItem := -1;
    RedrawInterface;
   End;
   #30: Begin { Alt+A - Menu Affichage }
    MenuActive := True;
    ActiveMenu := MENU_VIEW;
    ActiveMenuItem := -1;
    RedrawInterface;
   End;
   #23: Begin { Alt+I - Menu Image }
    MenuActive := True;
    ActiveMenu := MENU_IMAGE;
    ActiveMenuItem := -1;
    RedrawInterface;
   End;
   #46: Begin { Alt+C - Menu Couleurs }
    MenuActive := True;
    ActiveMenu := MENU_COLORS;
    ActiveMenuItem := -1;
    RedrawInterface;
   End;
   #53: Begin { Alt+? (touche /) - Menu Aide }
    MenuActive := True;
    ActiveMenu := MENU_HELP;
    ActiveMenuItem := -1;
    RedrawInterface;
   End;
   #75: ZPan(-Max(1,CanvasWidth*100 Div ZoomLevel Div 8),0);
   #77: ZPan(Max(1,CanvasWidth*100 Div ZoomLevel Div 8),0);
   #73: ZPan(0,-Max(1,CanvasHeight*100 Div ZoomLevel Div 2));
   #81: ZPan(0,Max(1,CanvasHeight*100 Div ZoomLevel Div 2));
   #71: ZPan(-ZOriginX,-ZOriginY);
   #72: Begin { Fleche haut : deplacement de la vue agrandie }
    If ZoomLevel<>100 Then Begin ZPan(0,-Max(1,CanvasHeight*100 Div ZoomLevel Div 8)); Exit; End;
    If BrushSize < 50 Then Inc(BrushSize);
    DrawToolbar;
   End;
   #80: Begin { Fleche bas : deplacement de la vue agrandie }
    If ZoomLevel<>100 Then Begin ZPan(0,Max(1,CanvasHeight*100 Div ZoomLevel Div 8)); Exit; End;
    If BrushSize > 1 Then Dec(BrushSize);
    DrawToolbar;
   End;
  End;
 End
 Else Begin
  { Validation au clavier d'un item de menu ouvert }
  If MenuActive and (Key = #13) Then Begin
   If (ActiveMenuItem >= 0) and
      (ActiveMenuItem < Menus[ActiveMenu].ItemCount) and
      (Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator) Then Begin
    HandleMenuClick(ActiveMenu, ActiveMenuItem);
    MenuActive := False;
    RedrawInterface;
   End;
   Exit;
  End;
  { Raccourcis Ctrl+lettre (codes ASCII 1..26) }
  If Not TextInsertMode Then Begin
   Case Key of
    #15: Begin HandleMenuClick(MENU_FILE,1); Exit; End; { Ctrl+O }
    #19: Begin HandleMenuClick(MENU_FILE,2); Exit; End; { Ctrl+S }
    #23: Begin HandleMenuClick(MENU_IMAGE,4); Exit; End; { Ctrl+W }
    #26: Begin Undo; Exit; End;          { Ctrl+Z }
    #25: Begin Redo; Exit; End;          { Ctrl+Y }
   End;
  End;
  { Mode saisie de texte }
  If TextInsertMode Then Begin
   If Key = #13 Then Begin { Entrée }
    ErasePreviewText;
    AddSnapshotToHistory(TOOL_TEXT);
    DrawText(TextX, TextY, TextInput, CurrentColor);
    TextInsertMode := False;
    TextInput := '';
    RedrawInterface;
   End
   Else If Key = #27 Then Begin { Échap }
    ErasePreviewText;
    TextInsertMode := False;
    TextInput := '';
   End
   Else If Key = #8 Then Begin { Retour arrière }
    If Length(TextInput) > 0 Then
     Delete(TextInput, Length(TextInput), 1);
    DrawTextPreview;
   End
   Else Begin
    TextInput := TextInput + Key;
    DrawTextPreview;
   End;
  End
  Else Begin
   { Raccourcis clavier - implémentation simplifiée }
   Case UpCase(Key) of
    '+': ZZoomStep(True);
    '-': ZZoomStep(False);
    'Q': If ConfirmDiscardChanges Then Running := False; { Quitter rapidement }
    #27: Begin { Échap }
     If MenuActive Then Begin
      MenuActive := False;
      RedrawInterface;
     End
     Else If SelectionActive Then Begin
      SelectionActive := False;
      RedrawInterface;
     End;
    End;
   End;
  End;
 End;
End;

{ Procédure principale }

Procedure Initialize;
Begin
 { Initialiser le générateur de nombres aléatoires }
 Randomize;

 { Initialiser les graphiques }
 InitGraphics;

 { Initialiser la souris }
 {$IFDEF FPC}
 InitMouse;
 {$ELSE}
 InitMouse;
 {$ENDIF}

 { Initialiser les composants de l'application }
 InitPalette;
 InitMenus;
 InitImage;
 PEInstallDocumentPalette;
 InitTools;
 InitHistory;

 { Variables d'état }
 Running := True;
 PolygonCount:=0; PolygonHover:=False;
 ToolTipVisible:=False; ToolTipCandidate:=-1;
 MenuActive := False;
 ActiveMenu := -1;
 ActiveMenuItem := -1;
 SelectionActive := False;
 Drawing := False;
 TextInsertMode := False;
 { Allouer un buffer de canvas blanc par defaut. Sans ce buffer,
   SyncCanvasImage est un no-op et chaque RedrawInterface (declenche
   par AddToHistory apres un trace ligne/rect/ellipse/etc.) efface
   le dessin de l'ecran (page blanche apparente). }
 CanvasImageW := ImageBuffer.Width;
 CanvasImageH := ImageBuffer.Height;
 GetMem(CanvasImage, LongInt(CanvasImageW) * LongInt(CanvasImageH));
 FillChar(CanvasImage^, LongInt(CanvasImageW) * LongInt(CanvasImageH), White);
 RubberValid := False;
 AntsPhase := 0;
 AntsCounter := 0;
 AntsValid := False;
 PreviewValid := False;

 { Dessiner l'interface }
 RedrawInterface;

 { Afficher la souris }
 {$IFDEF FPC}
 ShowMouse;
 {$ELSE}
 ShowMouse;
 {$ENDIF}
End;

Procedure Cleanup;
Var
 Tmp: PHistoryItem;
Begin
 { Masquer la souris }
 {$IFDEF FPC}
 HideMouse;
 {$ELSE}
 HideMouse;
 {$ENDIF}

 { Libérer le buffer de pixels du canvas }
 If CanvasImage <> Nil Then Begin
  FreeMem(CanvasImage, CanvasImageW * CanvasImageH);
  CanvasImage := Nil;
 End;

 { Libérer l'historique avec les données }
 While UndoList <> Nil do Begin
  Tmp := UndoList;
  UndoList := UndoList^.Next;
  FreeHistoryData(PHistoryData(Tmp^.Data));
  Dispose(Tmp);
 End;

 While RedoList <> Nil do Begin
  Tmp := RedoList;
  RedoList := RedoList^.Next;
  FreeHistoryData(PHistoryData(Tmp^.Data));
  Dispose(Tmp);
 End;

 { Fermer le mode graphique }
 CloseGraph;
End;

Procedure MainLoop;
Begin
 While Running do Begin
  HandleMouseEvent;
  HandleKeyboardEvent;
  { Animation "marching ants" : ~1 seconde par phase (Delay(10) x 100). }
  If SelectionActive And (Not Drawing) And (Not MenuActive) And (Not ToolTipVisible) Then Begin
   Inc(AntsCounter);
   If AntsCounter >= 100 Then Begin
    AntsCounter := 0;
    ToggleAnts;
   End;
  End;
  Delay(10);
 End;
End;

{ Point d'entrée du programme }
BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 { Initialiser la langue }
 Language:=_French;
 TmpLanguage:=GetEnv('LANGUAGE');
 If TmpLanguage<>''Then Begin
  If TmpLanguage[1]='"'Then TmpLanguage:=Copy(TmpLanguage,2,255);
  If StrToUpper(Copy(TmpLanguage,1,2))='EN'Then Language:=_English Else
  If StrToUpper(Copy(TmpLanguage,1,2))='GR'Then Language:=_Germany Else
  If StrToUpper(Copy(TmpLanguage,1,2))='IT'Then Language:=_Italian Else
  If StrToUpper(Copy(TmpLanguage,1,2))='SP'Then Language:=_Spain Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='SQ')or
    (StrToUpper(Copy(TmpLanguage,1,3))='ALB')Then Language:=_Albanian Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='PT')or
    (StrToUpper(Copy(TmpLanguage,1,3))='PRT')Then Language:=_Portuguese Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='SE')or
    (StrToUpper(Copy(TmpLanguage,1,3))='SWE')Then Language:=_Swedish Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='DK')or
    (StrToUpper(Copy(TmpLanguage,1,3))='DNK')Then Language:=_Danish Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='JP')or
    (StrToUpper(Copy(TmpLanguage,1,3))='JPN')Then Language:=_Japanese;
 End;
 If (ParamStr(1) = '/?') or (ParamStr(1) = '--help') or (ParamStr(1) = '-h') Then Begin
  WriteLn('PAINT: Cette commande permet de laner le programme de dessin Bitamp (Paint).');
  WriteLn;
  WriteLn('Syntaxe: PAINT [fichier.bmp|gif|png|jpg|xbm|wpg|lbm|hdr|fax|exr|' +
  'dng|bgx|dds|dcm|apng|arw|cr2|ppm|dib|cur|pcx|msp|tif|mac|pas]');
  WriteLn;
  WriteLn('Fonctionnalit'+#130+'s:');
  WriteLn(' - Interface graphique compl'+#138+'te avec menus et barre d''outils');
  WriteLn(' - Support de la souris (Int 33h / PtcMouse)');
  WriteLn(' - Outils de dessin: Crayon, Pinceau, A'+#130+'rographe, Ligne, Rectangle, Ellipse...');
  WriteLn(' - Formats: BMP, GIF, PNG, JPEG, XBM, WPG, LBM (ILBM/PBM), HDR (' +
  'RGBE), FAX (G3 1D), EXR, DNG, BGX, DDS, DCM, APNG, ARW, CR2, PPM');
  WriteLn(' - Support de la transparence pour GIF et PNG');
  WriteLn(' - Redimensionnement et rognage d''image');
  WriteLn(' - Support de 2 a 32 bits de profondeur de couleur');
  WriteLn(' - Historique Annuler/Retablir');
  WriteLn;
  WriteLn('Raccourcis clavier:');
  WriteLn(' Ctrl+N  Nouveau fichier');
  WriteLn(' Ctrl+O  Ouvrir fichier');
  WriteLn(' Ctrl+S  Enregistrer');
  WriteLn(' Ctrl+Z  Annuler');
  WriteLn(' Ctrl+Y  Retablir');
  WriteLn(' Ctrl+A  Tout selectionner');
  WriteLn(' +/-     Zoom avant/arriere');
  WriteLn(' Echap   Annuler operation en cours');
  WriteLn(' F10     Quitter');
 End
 Else Begin
  Initialize;

  { Charger un fichier si spécifié en ligne de commande }
  If ParamCount > 0 Then Begin
   { L'interface est déjà dessinée par Initialize ; LoadImage trace les pixels
     dans le canvas. Ne PAS rappeler RedrawInterface ici, sinon les pixels
     du BMP/GIF/etc. sont effacés avant même d'être visibles. }
   If LoadImage(ParamStr(1)) Then
    DrawStatusBar
   Else
    ShowMessage('Erreur de chargement',
                'Impossible de charger : ' + ParamStr(1));
  End;

  MainLoop;
  Cleanup;
 End;
END.
