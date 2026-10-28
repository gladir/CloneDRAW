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
 If (Ext = '.BMP') or (Ext = '.DIB') Then
  GetImageFormat := FMT_BMP
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
  PosStr := IntToStr(MouseX - CanvasX) + ', ' + IntToStr(MouseY - CanvasY);
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
 CX, CY, CW, CH: Integer;
 P: PByte;
Begin
 { Fond du canvas (zone de dessin) }
 SetFillStyle(SolidFill, White);
 Bar(CanvasX, CanvasY, CanvasX + Min(CanvasWidth, ImageBuffer.Width) - 1,
     CanvasY + Min(CanvasHeight, ImageBuffer.Height) - 1);

 { Redessiner les pixels de l'image chargée si présents }
 If (CanvasImage <> Nil) and (CanvasImageW > 0) and (CanvasImageH > 0) Then Begin
  CW := Min(CanvasImageW, CanvasWidth);
  CH := Min(CanvasImageH, CanvasHeight);
  P := CanvasImage;
  For CY := 0 to CanvasImageH - 1 do Begin
   If CY < CH Then
    For CX := 0 to CanvasImageW - 1 do Begin
     If CX < CW Then PutPixel(CanvasX + CX, CanvasY + CY, P^);
     Inc(P);
    End
   Else
    Inc(P, CanvasImageW);
  End;
 End;

 { Bordure du canvas }
 SetColor(DarkGray);
 Rectangle(CanvasX - 1, CanvasY - 1,
           CanvasX + Min(CanvasWidth, ImageBuffer.Width),
           CanvasY + Min(CanvasHeight, ImageBuffer.Height));

 { Grille si zoom > 400% }
 If ZoomLevel >= 400 Then Begin
  SetColor(LightGray);
  { Dessiner la grille... }
 End;
End;

Procedure DrawSelection;
Const
 AntsPatterns: Array[0..3] of Word = ($CCCC, $9999, $3333, $6666);
Begin
 If SelectionActive And (Not AntsValid) Then Begin
  { Trace en XOR avec un motif rotatif pour effet "marching ants". }
  SetWriteMode(XORPut);
  SetColor(White);
  SetLineStyle(UserBitLn, AntsPatterns[AntsPhase and 3], NormWidth);
  Rectangle(SelectionRect.Left, SelectionRect.Top,
            SelectionRect.Right, SelectionRect.Bottom);
  SetLineStyle(SolidLn, 0, NormWidth);
  SetWriteMode(CopyPut);
  AntsValid := True;
 End;
End;

Procedure EraseSelection;
Const
 AntsPatterns: Array[0..3] of Word = ($CCCC, $9999, $3333, $6666);
Begin
 If SelectionActive And AntsValid Then Begin
  { Re-applique le meme motif XOR -> efface les pixels precedents. }
  SetWriteMode(XORPut);
  SetColor(White);
  SetLineStyle(UserBitLn, AntsPatterns[AntsPhase and 3], NormWidth);
  Rectangle(SelectionRect.Left, SelectionRect.Top,
            SelectionRect.Right, SelectionRect.Bottom);
  SetLineStyle(SolidLn, 0, NormWidth);
  SetWriteMode(CopyPut);
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
Begin
 SetWriteMode(XORPut);
 SetColor(White);
 SetLineStyle(DottedLn, 0, NormWidth);
 Rectangle(L, T, R, B);
 SetLineStyle(SolidLn, 0, NormWidth);
 SetWriteMode(CopyPut);
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
Begin
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

Procedure RedrawInterface;
Begin
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
 RowBuffer: Array[0..4095] of Byte;
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
   If (X < CanvasWidth) and (SrcY < CanvasHeight) Then Begin
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
    PutPixel(CanvasX + X, CanvasY + SrcY, PixelColor);
    { Mémoriser le pixel pour pouvoir redessiner le canvas après un menu. }
    If (CanvasImage <> Nil) and (X < CanvasImageW) and (SrcY < CanvasImageH) Then
     PByte(PtrUInt(CanvasImage) + PtrUInt(SrcY) * PtrUInt(CanvasImageW) + PtrUInt(X))^ := PixelColor;
   End;
  End;
 End;

 Close(F);
 LoadBMP := True;
End;

Function LoadGIF(FileName: String): Boolean;
Var
 F: File;
 Header: TGIFHeader;
 BytesRead: Word;
 GlobalPalette: Array[0..255, 0..2] of Byte;
 PaletteSize: Integer;
 Flags, BackgroundIdx: Byte;
 HasGlobalPalette: Boolean;
 ColorResolution: Byte;
 BlockType: Byte;
 ImageDescriptor: Record
  Left, Top, Width, Height: Word;
  Flags: Byte;
 End;
 LZWMinCodeSize: Byte;
 SubBlockSize: Byte;
 CompressedData: Array[0..255] of Byte;
 I, X, Y: Integer;
 PixelColor: Byte;
 ClearCode, EndCode: Integer;
Begin
 LoadGIF := False;

 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire l'en-tête GIF }
 BlockRead(F, Header, SizeOf(TGIFHeader), BytesRead);
 If BytesRead <> SizeOf(TGIFHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Vérifier la signature }
 If (Copy(Header.Signature, 1, 3) <> 'GIF') Then Begin
  Close(F);
  Exit;
 End;

 { Mettre à jour les informations de l'image }
 ImageBuffer.Width := Header.ScreenWidth;
 ImageBuffer.Height := Header.ScreenHeight;
 ImageBuffer.FileName := FileName;
 ImageBuffer.Format := FMT_GIF;
 ImageBuffer.Modified := False;

 { Analyser les drapeaux }
 Flags := Header.Flags;
 HasGlobalPalette := (Flags and $80) <> 0;
 ColorResolution := ((Flags shr 4) and $07) + 1;
 PaletteSize := 1 shl ((Flags and $07) + 1);

 { Vérifier la transparence (GIF89a) }
 If Copy(Header.Signature, 1, 6) = GIF89_SIGNATURE Then Begin
  ImageBuffer.HasTransparency := True;
 End Else Begin
  ImageBuffer.HasTransparency := False;
 End;

 { Lire la palette globale si présente }
 If HasGlobalPalette Then Begin
  BlockRead(F, GlobalPalette, PaletteSize * 3, BytesRead);
  If BytesRead <> PaletteSize * 3 Then Begin
   Close(F);
   Exit;
  End;

  { Appliquer la palette au système graphique }
  For I := 0 to PaletteSize - 1 do Begin
   ImageBuffer.Palette[I].R := GlobalPalette[I, 0];
   ImageBuffer.Palette[I].G := GlobalPalette[I, 1];
   ImageBuffer.Palette[I].B := GlobalPalette[I, 2];
   SetRGBPalette(I, GlobalPalette[I, 0] shr 2,
                    GlobalPalette[I, 1] shr 2,
                    GlobalPalette[I, 2] shr 2);
  End;
 End;

 { Effacer la zone de dessin }
 SetFillStyle(SolidFill, Header.BackgroundColor);
 Bar(CanvasX, CanvasY, CanvasX + CanvasWidth - 1, CanvasY + CanvasHeight - 1);

 { Lire les blocs jusqu'au descripteur d'image }
 Repeat
  BlockRead(F, BlockType, 1, BytesRead);
  If BytesRead <> 1 Then Begin
   Close(F);
   Exit;
  End;

  Case BlockType of
   $21: Begin { Extension block }
    BlockRead(F, SubBlockSize, 1, BytesRead); { Extension type }
    { Sauter les sous-blocs de l'extension }
    Repeat
     BlockRead(F, SubBlockSize, 1, BytesRead);
     If SubBlockSize > 0 Then
      Seek(F, FilePos(F) + SubBlockSize);
    Until SubBlockSize = 0;
   End;

   $2C: Begin { Image descriptor }
    BlockRead(F, ImageDescriptor, 9, BytesRead);
    If BytesRead <> 9 Then Begin
     Close(F);
     Exit;
    End;

    { Lire le code minimum LZW }
    BlockRead(F, LZWMinCodeSize, 1, BytesRead);

    { Lire et décoder les données compressées LZW }
    ClearCode := 1 shl LZWMinCodeSize;
    EndCode := ClearCode + 1;

    { Lecture simplifiée: sauter les données compressées }
    { Une implémentation complète nécessiterait un décodeur LZW complet }
    Y := 0;
    X := 0;
    Repeat
     BlockRead(F, SubBlockSize, 1, BytesRead);
     If SubBlockSize > 0 Then Begin
      BlockRead(F, CompressedData, SubBlockSize, BytesRead);
      { Simulation simplifiée: utiliser les octets comme indices de couleur }
      For I := 0 to SubBlockSize - 1 do Begin
       If (X < ImageDescriptor.Width) and (Y < ImageDescriptor.Height) Then Begin
        PixelColor := CompressedData[I] mod PaletteSize;
        If (ImageDescriptor.Left + X < CanvasWidth) and
           (ImageDescriptor.Top + Y < CanvasHeight) Then Begin
         PutPixel(CanvasX + ImageDescriptor.Left + X,
                  CanvasY + ImageDescriptor.Top + Y, PixelColor);
        End;
        Inc(X);
        If X >= ImageDescriptor.Width Then Begin
         X := 0;
         Inc(Y);
        End;
       End;
      End;
     End;
    Until SubBlockSize = 0;
   End;

   $3B: Begin { Trailer }
    { Fin du fichier GIF }
   End;
  End;
 Until (BlockType = $3B) or (BytesRead = 0);

 Close(F);
 LoadGIF := True;
End;

Function LoadPNG(FileName: String): Boolean;
Var
 F: File;
 Signature: Array[0..7] of Byte;
 BytesRead: Word;
 I, X, Y: Integer;
 ValidSig: Boolean;
 ChunkLength: LongInt;
 ChunkType: Array[0..3] of Char;
 ChunkCRC: LongInt;
 IHDRData: Record
  Width, Height: LongInt;
  BitDepth, ColorType: Byte;
  Compression, Filter, Interlace: Byte;
 End;
 PNGPalette: Array[0..255, 0..2] of Byte;
 PaletteSize: Integer;
 DataBuffer: Array[0..4095] of Byte;
 PixelColor: Byte;
 Done: Boolean;

 Function SwapLong(L: LongInt): LongInt;
 Var
  B: Array[0..3] of Byte absolute L;
  R: Array[0..3] of Byte;
  Resultat:LongInt;
 Begin
  R[0] := B[3];
  R[1] := B[2];
  R[2] := B[1];
  R[3] := B[0];
  Move(R, Resultat, 4);
  SwapLong:=Resultat;
 End;

Begin
 LoadPNG := False;

 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire la signature PNG }
 BlockRead(F, Signature, 8, BytesRead);
 If BytesRead <> 8 Then Begin
  Close(F);
  Exit;
 End;

 { Vérifier la signature }
 ValidSig := True;
 For I := 0 to 7 do
  If Signature[I] <> PNG_SIGNATURE[I] Then ValidSig := False;

 If Not ValidSig Then Begin
  Close(F);
  Exit;
 End;

 ImageBuffer.FileName := FileName;
 ImageBuffer.Format := FMT_PNG;
 ImageBuffer.Modified := False;
 ImageBuffer.HasTransparency := True; { PNG supporte la transparence }
 PaletteSize := 0;

 { Lire les chunks PNG }
 Done := False;
 While Not Done do Begin
  { Lire la longueur du chunk }
  BlockRead(F, ChunkLength, 4, BytesRead);
  If BytesRead <> 4 Then Begin
   Close(F);
   Exit;
  End;
  ChunkLength := SwapLong(ChunkLength);

  { Lire le type du chunk }
  BlockRead(F, ChunkType, 4, BytesRead);
  If BytesRead <> 4 Then Begin
   Close(F);
   Exit;
  End;

  { Traiter selon le type de chunk }
  If ChunkType = 'IHDR' Then Begin
   { Lire les informations de l'en-tête }
   BlockRead(F, IHDRData, 13, BytesRead);
   IHDRData.Width := SwapLong(IHDRData.Width);
   IHDRData.Height := SwapLong(IHDRData.Height);
   ImageBuffer.Width := IHDRData.Width;
   ImageBuffer.Height := IHDRData.Height;
   ImageBuffer.BitDepth := IHDRData.BitDepth;

   { Vérifier le type de couleur pour la transparence }
   If (IHDRData.ColorType and 4) <> 0 Then
    ImageBuffer.HasTransparency := True
   Else
    ImageBuffer.HasTransparency := False;

   { Lire le CRC }
   BlockRead(F, ChunkCRC, 4, BytesRead);
  End
  Else If ChunkType = 'PLTE' Then Begin
   { Lire la palette }
   PaletteSize := ChunkLength div 3;
   If PaletteSize > 256 Then PaletteSize := 256;
   BlockRead(F, PNGPalette, PaletteSize * 3, BytesRead);

   { Appliquer la palette }
   For I := 0 to PaletteSize - 1 do Begin
    ImageBuffer.Palette[I].R := PNGPalette[I, 0];
    ImageBuffer.Palette[I].G := PNGPalette[I, 1];
    ImageBuffer.Palette[I].B := PNGPalette[I, 2];
    SetRGBPalette(I, PNGPalette[I, 0] shr 2,
                     PNGPalette[I, 1] shr 2,
                     PNGPalette[I, 2] shr 2);
   End;

   { Lire le CRC }
   BlockRead(F, ChunkCRC, 4, BytesRead);
  End
  Else If ChunkType = 'IDAT' Then Begin
   { Données compressées de l'image }
   { Note: PNG utilise DEFLATE/zlib, implémentation simplifiée ici }

   { Effacer la zone de dessin }
   SetFillStyle(SolidFill, White);
   Bar(CanvasX, CanvasY, CanvasX + CanvasWidth - 1, CanvasY + CanvasHeight - 1);

   { Lecture simplifiée: afficher un placeholder }
   Y := 0;
   X := 0;
   While ChunkLength > 0 do Begin
    If ChunkLength > 4096 Then
     BlockRead(F, DataBuffer, 4096, BytesRead)
    Else
     BlockRead(F, DataBuffer, ChunkLength, BytesRead);

    { Simulation: utiliser les données compressées comme pixels }
    For I := 0 to BytesRead - 1 do Begin
     If (X < ImageBuffer.Width) and (Y < ImageBuffer.Height) Then Begin
      If PaletteSize > 0 Then
       PixelColor := DataBuffer[I] mod PaletteSize
      Else
       PixelColor := DataBuffer[I] mod 16;

      If (X < CanvasWidth) and (Y < CanvasHeight) Then
       PutPixel(CanvasX + X, CanvasY + Y, PixelColor);

      Inc(X);
      If X >= ImageBuffer.Width Then Begin
       X := 0;
       Inc(Y);
      End;
     End;
    End;

    Dec(ChunkLength, BytesRead);
   End;

   { Lire le CRC }
   BlockRead(F, ChunkCRC, 4, BytesRead);
  End
  Else If ChunkType = 'IEND' Then Begin
   { Fin de l'image }
   Done := True;
  End
  Else Begin
   { Chunk inconnu, le sauter }
   If ChunkLength > 0 Then
    Seek(F, FilePos(F) + ChunkLength);
   BlockRead(F, ChunkCRC, 4, BytesRead);
  End;
 End;

 Close(F);
 LoadPNG := True;
End;

Function LoadJPEG(FileName: String): Boolean;
Var
 F: File;
 Marker: Word;
 BytesRead: Word;
 SegmentLength: Word;
 SOFFound: Boolean;
 Width, Height: Word;
 Components: Byte;
 DataBuffer: Array[0..4095] of Byte;
 I, X, Y: Integer;
 PixelColor: Byte;

 Function ReadMarker: Word;
 Var
  M: Word;
 Begin
  BlockRead(F, M, 2, BytesRead);
  ReadMarker := Swap(M);
 End;

Begin
 LoadJPEG := False;

 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire le marqueur SOI }
 Marker := ReadMarker;
 If Marker <> JPEG_SOI Then Begin
  Close(F);
  Exit;
 End;

 ImageBuffer.FileName := FileName;
 ImageBuffer.Format := FMT_JPEG;
 ImageBuffer.Modified := False;
 ImageBuffer.HasTransparency := False; { JPEG ne supporte pas la transparence }

 { Lire les segments JPEG }
 SOFFound := False;
 Width := 640;
 Height := 480;

 While Not SOFFound do Begin
  Marker := ReadMarker;
  If BytesRead <> 2 Then Begin
   Close(F);
   Exit;
  End;

  Case Marker of
   $FFC0, $FFC1, $FFC2: Begin { SOF0, SOF1, SOF2 - Start of Frame }
    BlockRead(F, SegmentLength, 2, BytesRead);
    SegmentLength := Swap(SegmentLength);

    { Sauter la précision }
    Seek(F, FilePos(F) + 1);

    { Lire la hauteur et la largeur }
    BlockRead(F, Height, 2, BytesRead);
    Height := Swap(Height);
    BlockRead(F, Width, 2, BytesRead);
    Width := Swap(Width);
    BlockRead(F, Components, 1, BytesRead);

    ImageBuffer.Width := Width;
    ImageBuffer.Height := Height;
    ImageBuffer.BitDepth := 24;
    SOFFound := True;

    { Sauter le reste du segment }
    Seek(F, FilePos(F) + SegmentLength - 8);
   End;

   $FFD8: Begin { SOI - déjà traité }
   End;

   $FFD9: Begin { EOI - End of Image }
    SOFFound := True; { Sortir de la boucle }
   End;

   $FFDA: Begin { SOS - Start of Scan }
    { Lire la longueur du segment }
    BlockRead(F, SegmentLength, 2, BytesRead);
    SegmentLength := Swap(SegmentLength);

    { Sauter l'en-tête SOS }
    Seek(F, FilePos(F) + SegmentLength - 2);

    { Les données d'image commencent ici }
    { Effacer la zone de dessin }
    SetFillStyle(SolidFill, White);
    Bar(CanvasX, CanvasY, CanvasX + CanvasWidth - 1, CanvasY + CanvasHeight - 1);

    { Lecture simplifiée des données compressées }
    Y := 0;
    X := 0;
    While (Y < ImageBuffer.Height) and (Y < CanvasHeight) do Begin
     BlockRead(F, DataBuffer, 4096, BytesRead);
     If BytesRead = 0 Then Break;

     { Simulation: utiliser les données comme niveau de gris }
     For I := 0 to BytesRead - 1 do Begin
      { Éviter les marqueurs JPEG }
      If DataBuffer[I] <> $FF Then Begin
       PixelColor := DataBuffer[I] mod 16;
       If (X < ImageBuffer.Width) and (X < CanvasWidth) and
          (Y < ImageBuffer.Height) and (Y < CanvasHeight) Then Begin
        PutPixel(CanvasX + X, CanvasY + Y, PixelColor);
       End;
       Inc(X);
       If X >= ImageBuffer.Width Then Begin
        X := 0;
        Inc(Y);
       End;
      End;
     End;
    End;

    SOFFound := True;
   End;

   Else Begin
    { Autre segment, le sauter }
    If (Marker and $FF00) = $FF00 Then Begin
     BlockRead(F, SegmentLength, 2, BytesRead);
     If BytesRead = 2 Then Begin
      SegmentLength := Swap(SegmentLength);
      If SegmentLength > 2 Then
       Seek(F, FilePos(F) + SegmentLength - 2);
     End;
    End;
   End;
  End;
 End;

 Close(F);
 LoadJPEG := True;
End;

Function LoadImage(FileName: String): Boolean;
Var
 Format: Byte;
 F: File;
 Ext: String;
Begin
 LoadImage := False;

 { Verifier que le fichier existe et est lisible }
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;
 {$I-} Close(F); {$I+}
 If IOResult <> 0 Then;

 { Refuser les extensions inconnues plutot que de tenter un BMP au hasard }
 Ext := ExtractFileExt(FileName);
 If (Ext <> '.BMP') and (Ext <> '.DIB') and
    (Ext <> '.GIF') and (Ext <> '.PNG') and
    (Ext <> '.JPG') and (Ext <> '.JPEG') Then Exit;

 Format := GetImageFormat(FileName);

 Case Format of
  FMT_BMP: LoadImage := LoadBMP(FileName);
  FMT_GIF: LoadImage := LoadGIF(FileName);
  FMT_PNG: LoadImage := LoadPNG(FileName);
  FMT_JPEG: LoadImage := LoadJPEG(FileName);
  Else LoadImage := False;
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
 RowBuffer: Array[0..4095] of Byte;
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

Function SaveGIF(FileName: String): Boolean;
Var
 F: File;
 Header: TGIFHeader;
 BytesWritten: Word;
 GIFPalette: Array[0..255, 0..2] of Byte;
 ImageDescriptor: Array[0..9] of Byte;
 LZWMinCodeSize: Byte;
 RowBuffer: Array[0..4095] of Byte;
 SubBlockSize: Byte;
 Trailer: Byte;
 I, X, Y: Integer;
 PixelColor: Byte;
 DataPos: Integer;
 SrcP: PByte;
Begin
 SaveGIF := False;

 { Préparer l'en-tête GIF }
 If ImageBuffer.HasTransparency Then
  Move(GIF89_SIGNATURE[1], Header.Signature, 6)
 Else
  Move(GIF87_SIGNATURE[1], Header.Signature, 6);

 Header.ScreenWidth := ImageBuffer.Width;
 Header.ScreenHeight := ImageBuffer.Height;
 Header.Flags := $F7; { Palette globale, 256 couleurs, 8 bits par couleur primaire }
 Header.BackgroundColor := 0;
 Header.AspectRatio := 0;

 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Écrire l'en-tête }
 BlockWrite(F, Header, SizeOf(TGIFHeader), BytesWritten);
 If BytesWritten <> SizeOf(TGIFHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Écrire la palette globale (256 couleurs) }
 For I := 0 to 255 do Begin
  GIFPalette[I, 0] := ImageBuffer.Palette[I].R;
  GIFPalette[I, 1] := ImageBuffer.Palette[I].G;
  GIFPalette[I, 2] := ImageBuffer.Palette[I].B;
 End;
 BlockWrite(F, GIFPalette, 768, BytesWritten);
 If BytesWritten <> 768 Then Begin
  Close(F);
  Exit;
 End;

 { Écrire l'extension de contrôle graphique pour la transparence (GIF89a) }
 If ImageBuffer.HasTransparency Then Begin
  { Extension introducer }
  SubBlockSize := $21;
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
  { Graphic control label }
  SubBlockSize := $F9;
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
  { Block size }
  SubBlockSize := 4;
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
  { Flags: transparent color flag }
  SubBlockSize := 1;
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
  { Delay time }
  SubBlockSize := 0;
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
  { Transparent color index }
  SubBlockSize := 0;
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
  { Block terminator }
  SubBlockSize := 0;
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
 End;

 { Écrire le descripteur d'image }
 ImageDescriptor[0] := $2C; { Image separator }
 ImageDescriptor[1] := 0; { Left position low }
 ImageDescriptor[2] := 0; { Left position high }
 ImageDescriptor[3] := 0; { Top position low }
 ImageDescriptor[4] := 0; { Top position high }
 ImageDescriptor[5] := Lo(ImageBuffer.Width);
 ImageDescriptor[6] := Hi(ImageBuffer.Width);
 ImageDescriptor[7] := Lo(ImageBuffer.Height);
 ImageDescriptor[8] := Hi(ImageBuffer.Height);
 ImageDescriptor[9] := 0; { Pas de palette locale, pas d'entrelacement }
 BlockWrite(F, ImageDescriptor, 10, BytesWritten);
 If BytesWritten <> 10 Then Begin
  Close(F);
  Exit;
 End;

 { Code minimum LZW (8 bits pour 256 couleurs) }
 LZWMinCodeSize := 8;
 BlockWrite(F, LZWMinCodeSize, 1, BytesWritten);

 { Écrire les données d'image (version simplifiée sans compression LZW réelle) }
 { Note: Une implémentation complète nécessiterait un encodeur LZW complet }
 { Ici on écrit les données brutes en blocs de 255 octets max }
 DataPos := 0;
 For Y := 0 to ImageBuffer.Height - 1 do Begin
  For X := 0 to ImageBuffer.Width - 1 do Begin
   { Lecture depuis CanvasImage (pas l'ecran) pour eviter de capturer
     un menu deroulant ou le curseur souris. }
   If (CanvasImage <> Nil) and
      (X < CanvasImageW) and (Y < CanvasImageH) Then Begin
    SrcP := CanvasImage;
    Inc(SrcP, LongInt(Y) * LongInt(CanvasImageW) + X);
    PixelColor := SrcP^;
   End
   Else
    PixelColor := 0;

   RowBuffer[DataPos] := PixelColor;
   Inc(DataPos);

   { Écrire un sous-bloc quand il est plein }
   If DataPos >= 255 Then Begin
    SubBlockSize := 255;
    BlockWrite(F, SubBlockSize, 1, BytesWritten);
    BlockWrite(F, RowBuffer, 255, BytesWritten);
    DataPos := 0;
   End;
  End;
 End;

 { Écrire le dernier sous-bloc }
 If DataPos > 0 Then Begin
  SubBlockSize := DataPos;
  BlockWrite(F, SubBlockSize, 1, BytesWritten);
  BlockWrite(F, RowBuffer, DataPos, BytesWritten);
 End;

 { Terminateur de bloc }
 SubBlockSize := 0;
 BlockWrite(F, SubBlockSize, 1, BytesWritten);

 { Écrire le terminateur GIF }
 Trailer := $3B;
 BlockWrite(F, Trailer, 1, BytesWritten);

 Close(F);
 ImageBuffer.FileName := FileName;
 ImageBuffer.Modified := False;
 SaveGIF := True;
End;

Function SavePNG(FileName: String): Boolean;
Var
 F: File;
 BytesWritten: Word;
 IHDRChunk: Record
  Width, Height: LongInt;
  BitDepth, ColorType: Byte;
  Compression, Filter, Interlace: Byte;
 End;
 ChunkLength: LongInt;
 ChunkType: Array[0..3] of Char;
 ChunkCRC: LongInt;
 PNGPalette: Array[0..255, 0..2] of Byte;
 RowBuffer: Array[0..4096] of Byte;
 I, X, Y: Integer;
 PixelColor: Byte;
 DataPos: Integer;
 SrcP: PByte;

 Function SwapLong(L: LongInt): LongInt;
 Var
  B: Array[0..3] of Byte absolute L;
  R: Array[0..3] of Byte;
  Resultat:LongInt;
 Begin
  R[0] := B[3];
  R[1] := B[2];
  R[2] := B[1];
  R[3] := B[0];
  Move(R, Resultat, 4);
  SwapLong:=Resultat;
 End;

 Function CalculateCRC32(Data: Pointer; Len: Integer): LongInt;
 { Calcul CRC32 simplifié }
 Var
  I, J: Integer;
  CRC: LongInt;
  B: PByte;
 Begin
  CRC := LongInt($FFFFFFFF);
  B := Data;
  For I := 0 to Len - 1 do Begin
   CRC := CRC xor B^;
   For J := 0 to 7 do Begin
    If (CRC and 1) <> 0 Then
     CRC := (CRC shr 1) xor $EDB88320
    Else
     CRC := CRC shr 1;
   End;
   Inc(B);
  End;
  CalculateCRC32 := CRC xor $FFFFFFFF;
 End;

Begin
 SavePNG := False;

 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Écrire la signature PNG }
 BlockWrite(F, PNG_SIGNATURE, 8, BytesWritten);
 If BytesWritten <> 8 Then Begin
  Close(F);
  Exit;
 End;

 { Écrire le chunk IHDR }
 ChunkLength := SwapLong(13);
 ChunkType := 'IHDR';
 BlockWrite(F, ChunkLength, 4, BytesWritten);
 BlockWrite(F, ChunkType, 4, BytesWritten);

 IHDRChunk.Width := SwapLong(ImageBuffer.Width);
 IHDRChunk.Height := SwapLong(ImageBuffer.Height);
 IHDRChunk.BitDepth := 8;
 IHDRChunk.ColorType := 3; { Indexed color }
 IHDRChunk.Compression := 0;
 IHDRChunk.Filter := 0;
 IHDRChunk.Interlace := 0;
 BlockWrite(F, IHDRChunk, 13, BytesWritten);

 { Calculer et écrire le CRC }
 ChunkCRC := SwapLong(CalculateCRC32(@ChunkType, 17));
 BlockWrite(F, ChunkCRC, 4, BytesWritten);

 { Écrire le chunk PLTE (palette) }
 ChunkLength := SwapLong(768); { 256 * 3 }
 ChunkType := 'PLTE';
 BlockWrite(F, ChunkLength, 4, BytesWritten);
 BlockWrite(F, ChunkType, 4, BytesWritten);

 For I := 0 to 255 do Begin
  PNGPalette[I, 0] := ImageBuffer.Palette[I].R;
  PNGPalette[I, 1] := ImageBuffer.Palette[I].G;
  PNGPalette[I, 2] := ImageBuffer.Palette[I].B;
 End;
 BlockWrite(F, PNGPalette, 768, BytesWritten);

 ChunkCRC := SwapLong(CalculateCRC32(@ChunkType, 772));
 BlockWrite(F, ChunkCRC, 4, BytesWritten);

 { Écrire le chunk tRNS pour la transparence si nécessaire }
 If ImageBuffer.HasTransparency Then Begin
  ChunkLength := SwapLong(1);
  ChunkType := 'tRNS';
  BlockWrite(F, ChunkLength, 4, BytesWritten);
  BlockWrite(F, ChunkType, 4, BytesWritten);
  PixelColor := 0; { Index de couleur transparente }
  BlockWrite(F, PixelColor, 1, BytesWritten);
  ChunkCRC := SwapLong(CalculateCRC32(@ChunkType, 5));
  BlockWrite(F, ChunkCRC, 4, BytesWritten);
 End;

 { Écrire le chunk IDAT (données non compressées - format simplifié) }
 { Note: PNG nécessite normalement la compression DEFLATE/zlib }
 { Cette version écrit les données avec un wrapper zlib minimal }
 DataPos := ImageBuffer.Width * ImageBuffer.Height + ImageBuffer.Height;
 ChunkLength := SwapLong(DataPos + 11); { Données + en-tête zlib }
 ChunkType := 'IDAT';
 BlockWrite(F, ChunkLength, 4, BytesWritten);
 BlockWrite(F, ChunkType, 4, BytesWritten);

 { En-tête zlib minimal (données non compressées) }
 PixelColor := $78; { CMF }
 BlockWrite(F, PixelColor, 1, BytesWritten);
 PixelColor := $01; { FLG }
 BlockWrite(F, PixelColor, 1, BytesWritten);

 { Écrire les lignes d'image avec le filtre type 0 (None) }
 For Y := 0 to ImageBuffer.Height - 1 do Begin
  { Bloc non compressé }
  If Y = ImageBuffer.Height - 1 Then
   PixelColor := 1 { Dernier bloc }
  Else
   PixelColor := 0;
  BlockWrite(F, PixelColor, 1, BytesWritten);

  { Taille du bloc (2 octets little-endian + complément) }
  DataPos := ImageBuffer.Width + 1;
  RowBuffer[0] := Lo(DataPos);
  RowBuffer[1] := Hi(DataPos);
  RowBuffer[2] := Lo(DataPos) xor $FF;
  RowBuffer[3] := Hi(DataPos) xor $FF;
  BlockWrite(F, RowBuffer, 4, BytesWritten);

  { Type de filtre (0 = None) }
  PixelColor := 0;
  BlockWrite(F, PixelColor, 1, BytesWritten);

  { Données de la ligne. Lecture depuis CanvasImage (pas l'ecran)
    pour ne pas capturer un menu deroulant ou le curseur souris. }
  For X := 0 to ImageBuffer.Width - 1 do Begin
   If (CanvasImage <> Nil) and
      (X < CanvasImageW) and (Y < CanvasImageH) Then Begin
    SrcP := CanvasImage;
    Inc(SrcP, LongInt(Y) * LongInt(CanvasImageW) + X);
    RowBuffer[X] := SrcP^;
   End
   Else
    RowBuffer[X] := 0;
  End;
  BlockWrite(F, RowBuffer, ImageBuffer.Width, BytesWritten);
 End;

 { Adler-32 checksum (simplifié) }
 ChunkCRC := SwapLong(1);
 BlockWrite(F, ChunkCRC, 4, BytesWritten);

 { CRC du chunk IDAT }
 ChunkCRC := SwapLong(0);
 BlockWrite(F, ChunkCRC, 4, BytesWritten);

 { Écrire le chunk IEND }
 ChunkLength := SwapLong(0);
 ChunkType := 'IEND';
 BlockWrite(F, ChunkLength, 4, BytesWritten);
 BlockWrite(F, ChunkType, 4, BytesWritten);
 ChunkCRC := SwapLong(LongInt($AE426082)); { CRC fixe pour IEND vide }
 BlockWrite(F, ChunkCRC, 4, BytesWritten);

 Close(F);
 ImageBuffer.FileName := FileName;
 ImageBuffer.Modified := False;
 SavePNG := True;
End;

Function SaveImage(FileName: String; Format: Byte): Boolean;
Begin
 Case Format of
  FMT_BMP: SaveImage := SaveBMP(FileName);
  FMT_GIF: SaveImage := SaveGIF(FileName);
  FMT_PNG: SaveImage := SavePNG(FileName);
  Else SaveImage := False;
 End;
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
 { Effacer l'image (remplir avec la couleur d'arrière-plan) }
 SetFillStyle(SolidFill, BackgroundColor);
 Bar(CanvasX, CanvasY, CanvasX + Min(CanvasWidth, ImageBuffer.Width) - 1,
     CanvasY + Min(CanvasHeight, ImageBuffer.Height) - 1);
 ImageBuffer.Modified := True;
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
 End;

Procedure SaveHistoryPalette(Data: PHistoryData);
Begin
 Data^.SavedColors := ImageBuffer.Palette;
 Move(StandardPalette,Data^.SavedSwatches,SizeOf(StandardPalette));
 Data^.SavedForeground := CurrentColor;
 Data^.SavedBackground := BackgroundColor;
 Data^.SavedDepth := ImageBuffer.BitDepth;
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

Procedure DrawPixel(X, Y: Integer; Color: Byte);
Var
 BX, BY: Integer;
 ImgP: PByte;
Begin
 If (X >= CanvasX) and (X < CanvasX + ImageBuffer.Width) and
    (Y >= CanvasY) and (Y < CanvasY + ImageBuffer.Height) Then Begin
  PutPixel(X, Y, Color);
  { Synchroniser le buffer image. }
  If CanvasImage <> Nil Then Begin
   BX := X - CanvasX;
   BY := Y - CanvasY;
   If (BX >= 0) and (BX < CanvasImageW) and
      (BY >= 0) and (BY < CanvasImageH) Then Begin
    ImgP := CanvasImage;
    Inc(ImgP, LongInt(BY) * LongInt(CanvasImageW) + BX);
    ImgP^ := Color;
   End;
  End;
  ImageBuffer.Modified := True;
 End;
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
 SetColor(CurrentColor);
 OutTextXY(TextX, TextY, S);
 TextPrevW := TextWidth(S) + 1;
 TextPrevH := TextHeight('M') + 1;
End;

Procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte);
Begin
 SetColor(Color);
 Line(X1, Y1, X2, Y2);
 SyncCanvasImage(X1, Y1, X2, Y2);
 ImageBuffer.Modified := True;
End;

Procedure DrawRectangle(X1, Y1, X2, Y2: Integer; Color: Byte; Filled: Boolean);
Begin
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

Procedure FloodFillArea(X, Y: Integer; FillColor, BorderColor: Byte);
Begin
 SetFillStyle(SolidFill, FillColor);
 {$IFDEF FPC}
 PtcGraph.FloodFill(X, Y, BorderColor);
 {$ELSE}
 Graph.FloodFill(X, Y, BorderColor);
 {$ENDIF}
 { Le remplissage peut toucher tout le canvas. }
 SyncCanvasImage(CanvasX, CanvasY,
                 CanvasX + CanvasImageW - 1, CanvasY + CanvasImageH - 1);
 ImageBuffer.Modified := True;
End;

Procedure DrawText(X, Y: Integer; Text: String; Color: Byte);
Var
 W, H: Integer;
Begin
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

Procedure ColorPicker(X, Y: Integer);
Begin
 If (X >= CanvasX) and (X < CanvasX + ImageBuffer.Width) and
    (Y >= CanvasY) and (Y < CanvasY + ImageBuffer.Height) Then Begin
  CurrentColor := GetPixel(X, Y);
  DrawColorPalette;
 End;
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

Function SaveCurrentImage: Boolean;
{ Sauvegarde l'image courante. Si pas de nom de fichier, demande un nom.
  Retourne True en cas de succes, False si annule ou erreur. }
Var
 NewName: String;
 Fmt: Byte;
Begin
 SaveCurrentImage := False;
 If ImageBuffer.FileName <> '' Then Begin
  If SaveImage(ImageBuffer.FileName, ImageBuffer.Format) Then Begin
   ImageBuffer.Modified := False;
   SaveCurrentImage := True;
  End
  Else
   ShowMessage('Erreur', 'Echec de l''enregistrement.');
 End
 Else Begin
  NewName := '';
  If PromptString('Enregistrer sous', 'Nom du fichier :', NewName) and
     (NewName <> '') Then Begin
   NewName := EnsureSaveExtension(NewName);
   Fmt := GetImageFormat(NewName);
   If SaveImage(NewName, Fmt) Then Begin
    ImageBuffer.FileName := NewName;
    ImageBuffer.Format := Fmt;
    ImageBuffer.Modified := False;
    DrawStatusBar;
    SaveCurrentImage := True;
   End
   Else
    ShowMessage('Erreur', 'Echec de l''enregistrement.');
  End;
 End;
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
   'Enregistrer les modifications avant de quitter ?');
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


Procedure HandleMenuClick(MenuIndex, ItemIndex: Integer);
Var
 NewName: String;
 Fmt: Byte;
 InfoMsg: String;
 NewW, NewH, ValErr: Integer;
Begin
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
     ClearImage;
     If (CanvasImage <> Nil) and (CanvasImageW > 0) and (CanvasImageH > 0) Then
      FillChar(CanvasImage^, CanvasImageW * CanvasImageH, BackgroundColor);
     ImageBuffer.FileName := '';
     ImageBuffer.Modified := False;
     DrawStatusBar;
    End;
    1: Begin { Ouvrir }
     NewName := '';
     If PromptString('Ouvrir', 'Nom du fichier :', NewName) and (NewName <> '') Then Begin
      If LoadImage(NewName) Then Begin
       ImageBuffer.Modified := False;
       DrawStatusBar;
      End
      Else
       ShowMessage('Erreur', 'Impossible d''ouvrir : ' + NewName);
     End;
    End;
    2: Begin { Enregistrer }
     If ImageBuffer.FileName <> '' Then Begin
      If SaveImage(ImageBuffer.FileName, ImageBuffer.Format) Then Begin
       ImageBuffer.Modified := False;
       ShowMessage('Enregistrer', 'Enregistre : ' + ImageBuffer.FileName);
      End
      Else
       ShowMessage('Erreur', 'Echec de l''enregistrement.');
     End
     Else Begin
      NewName := '';
      If PromptString('Enregistrer sous', 'Nom du fichier :', NewName) and (NewName <> '') Then Begin
       NewName := EnsureSaveExtension(NewName);
       Fmt := GetImageFormat(NewName);
       If SaveImage(NewName, Fmt) Then Begin
        ImageBuffer.FileName := NewName;
        ImageBuffer.Format := Fmt;
        ImageBuffer.Modified := False;
        DrawStatusBar;
       End
       Else
        ShowMessage('Erreur', 'Echec de l''enregistrement.');
      End;
     End;
    End;
    3: Begin { Enregistrer sous }
     NewName := ImageBuffer.FileName;
     If PromptString('Enregistrer sous', 'Nom du fichier :', NewName) and (NewName <> '') Then Begin
      NewName := EnsureSaveExtension(NewName);
      Fmt := GetImageFormat(NewName);
      If SaveImage(NewName, Fmt) Then Begin
       ImageBuffer.FileName := NewName;
       ImageBuffer.Format := Fmt;
       ImageBuffer.Modified := False;
       DrawStatusBar;
      End
      Else
       ShowMessage('Erreur', 'Echec de l''enregistrement.');
     End;
    End;
    5: Begin { Imprimer }
     ShowMessage('Imprimer', 'Impression non disponible.');
    End;
    7: Begin { Propriétés }
     Str(ImageBuffer.Width, InfoMsg);
     InfoMsg := 'Taille : ' + InfoMsg + ' x ';
     Str(ImageBuffer.Height, NewName);
     InfoMsg := InfoMsg + NewName + '  -  ';
     Str(ImageBuffer.BitDepth, NewName);
     InfoMsg := InfoMsg + NewName + ' bpp';
     ShowMessage('Proprietes', InfoMsg);
    End;
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
      SetFillStyle(SolidFill, BackgroundColor);
      Bar(SelectionRect.Left, SelectionRect.Top,
          SelectionRect.Right, SelectionRect.Bottom);
      SyncCanvasImage(SelectionRect.Left, SelectionRect.Top,
                      SelectionRect.Right, SelectionRect.Bottom);
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
    4: Begin { Zoom avant }
     If ZoomLevel < 800 Then Begin
      ZoomLevel := ZoomLevel * 2;
      If ZoomLevel > 800 Then ZoomLevel := 800;
     End;
    End;
    5: Begin { Zoom arrière }
     If ZoomLevel > 25 Then Begin
      ZoomLevel := ZoomLevel div 2;
      If ZoomLevel < 25 Then ZoomLevel := 25;
     End;
    End;
    7: Begin { Plein écran }
    End;
   End;
  End;
  MENU_IMAGE: Begin
   Case ItemIndex of
    0: Begin { Retourner/Pivoter }
     NewName := '';
     If PromptString('Retourner / Pivoter',
                     'H=horizontal V=vertical L=90gauche R=90droite I=180',
                     NewName) and (NewName <> '') Then Begin
      Case UpCase(NewName[1]) of
       'H': Begin AddSnapshotToHistory(TOOL_PENCIL); FlipHorizontal; End;
       'V': Begin AddSnapshotToHistory(TOOL_PENCIL); FlipVertical; End;
       'L': Begin AddSnapshotToHistory(TOOL_PENCIL); RotateImage(270); End;
       'R': Begin AddSnapshotToHistory(TOOL_PENCIL); RotateImage(90); End;
       'I': Begin AddSnapshotToHistory(TOOL_PENCIL); RotateImage(180); End;
      End;
     End;
    End;
    1: Begin { Étirer/Incliner }
     Str(ImageBuffer.Width, NewName);
     Str(ImageBuffer.Height, InfoMsg);
     NewName := NewName + 'x' + InfoMsg;
     If PromptString('Etirer',
                     'Nouvelle taille (LARGEURxHAUTEUR) :',
                     NewName) and (NewName <> '') Then Begin
      Fmt := Pos('x', NewName);
      If Fmt = 0 Then Fmt := Pos('X', NewName);
      If Fmt > 1 Then Begin
       Val(Copy(NewName, 1, Fmt - 1), NewW, ValErr);
       If ValErr = 0 Then Val(Copy(NewName, Fmt + 1, Length(NewName) - Fmt),
                              NewH, ValErr);
       If (ValErr = 0) and (NewW > 0) and (NewH > 0) Then Begin
        AddSnapshotToHistory(TOOL_PENCIL);
        StretchCanvas(NewW, NewH);
       End
       Else
        ShowMessage('Erreur', 'Dimensions invalides.');
      End
      Else
       ShowMessage('Erreur', 'Format attendu : LARGEURxHAUTEUR.');
     End;
    End;
    2: Begin AddSnapshotToHistory(TOOL_PENCIL); InvertColors; End;
    4: Begin { Redimensionner }
     Str(ImageBuffer.Width, NewName);
     Str(ImageBuffer.Height, InfoMsg);
     NewName := NewName + 'x' + InfoMsg;
     If PromptString('Redimensionner',
                     'Nouvelle taille (LARGEURxHAUTEUR) :',
                     NewName) and (NewName <> '') Then Begin
      Fmt := Pos('x', NewName);
      If Fmt = 0 Then Fmt := Pos('X', NewName);
      If Fmt > 1 Then Begin
       Val(Copy(NewName, 1, Fmt - 1), NewW, ValErr);
       If ValErr = 0 Then Val(Copy(NewName, Fmt + 1, Length(NewName) - Fmt),
                              NewH, ValErr);
       If (ValErr = 0) and (NewW > 0) and (NewH > 0) Then Begin
        AddSnapshotToHistory(TOOL_PENCIL);
        StretchCanvas(NewW, NewH);
       End
       Else
        ShowMessage('Erreur', 'Dimensions invalides.');
      End;
     End;
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
    7: Begin { Attributs }
     Str(ImageBuffer.Width, InfoMsg);
     InfoMsg := 'Largeur : ' + InfoMsg;
     Str(ImageBuffer.Height, NewName);
     InfoMsg := InfoMsg + '  Hauteur : ' + NewName;
     ShowMessage('Attributs', InfoMsg);
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
 If Drawing Then Exit;

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
   FloodFillArea(X, Y, CurrentColor, GetPixel(X, Y));
   AddToHistory(TOOL_FILL);
  End;
  TOOL_PICKER: Begin
   ColorPicker(X, Y);
  End;
  TOOL_MAGNIFY: Begin
   If ZoomLevel < 800 Then
    ZoomLevel := ZoomLevel * 2;
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
  TOOL_LINE, TOOL_RECT, TOOL_ELLIPSE, TOOL_ROUNDRECT, TOOL_CURVE, TOOL_POLYGON: Begin
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
   DrawLine(OldMouseX, OldMouseY, X, Y, CurrentColor);
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
   AddToHistory(TOOL_LINE);
  End;
  TOOL_RECT: Begin
   DrawRectangle(StartX, StartY, X, Y, CurrentColor, FillStyle > 0);
   AddToHistory(TOOL_RECT);
  End;
  TOOL_ELLIPSE: Begin
   CenterX := (StartX + X) div 2;
   CenterY := (StartY + Y) div 2;
   RadiusX := Abs(X - StartX) div 2;
   RadiusY := Abs(Y - StartY) div 2;
   DrawEllipse(CenterX, CenterY, RadiusX, RadiusY, CurrentColor, FillStyle > 0);
   AddToHistory(TOOL_ELLIPSE);
  End;
  TOOL_ROUNDRECT: Begin
   DrawRoundRectShape(StartX, StartY, X, Y, 10, 10, CurrentColor, FillStyle > 0);
   AddToHistory(TOOL_ROUNDRECT);
  End;
 End;
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

 If ButtonPressed Then Begin
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
   HandleCanvasClick(MouseX, MouseY);
  End;
 End
 Else If ((MouseButtons and 1) <> 0) and Drawing Then Begin
  { Bouton maintenu : continuer le trace sur le canvas }
  If (MouseX >= CanvasX) and (MouseX < CanvasX + CanvasWidth) and
     (MouseY >= CanvasY) and (MouseY < CanvasY + CanvasHeight) Then
   HandleCanvasDrag(MouseX, MouseY);
 End
 Else If ((MouseButtons and 1) = 0) and ((OldMouseButtons and 1) <> 0) Then Begin
  { Bouton relache (front descendant) }
  If Drawing Then
   HandleCanvasRelease(MouseX, MouseY);
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

 Key := ReadKey;

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
   #72: Begin { Flèche haut }
    If BrushSize < 50 Then Inc(BrushSize);
    DrawToolbar;
   End;
   #80: Begin { Flèche bas }
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
    #26: Begin Undo; Exit; End;          { Ctrl+Z }
    #25: Begin Redo; Exit; End;          { Ctrl+Y }
   End;
  End;
  { Mode saisie de texte }
  If TextInsertMode Then Begin
   If Key = #13 Then Begin { Entrée }
    ErasePreviewText;
    DrawText(TextX, TextY, TextInput, CurrentColor);
    TextInsertMode := False;
    TextInput := '';
    AddToHistory(TOOL_TEXT);
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
    '+': If ZoomLevel < 800 Then ZoomLevel := ZoomLevel * 2;
    '-': If ZoomLevel > 25 Then ZoomLevel := ZoomLevel div 2;
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
  If SelectionActive And (Not Drawing) And (Not MenuActive) Then Begin
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
  WriteLn('Syntaxe: PAINT [fichier.bmp|gif|png|jpg]');
  WriteLn;
  WriteLn('Fonctionnalit'+#130+'s:');
  WriteLn(' - Interface graphique compl'+#138+'te avec menus et barre d''outils');
  WriteLn(' - Support de la souris (Int 33h / PtcMouse)');
  WriteLn(' - Outils de dessin: Crayon, Pinceau, A'+#130+'rographe, Ligne, Rectangle, Ellipse...');
  WriteLn(' - Support des formats: BMP, GIF, PNG, JPEG');
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
