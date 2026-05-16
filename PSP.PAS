{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal)
  @description(Clone simplifie d'Adobe Photoshop, inspire de PAINT.PAS.
   Interface signature de Photoshop : fond gris fonce, barre d'outils
   verticale a gauche, panneau Calques a droite, barre d'options sous
   le menu, canvas central avec damier de transparence.
   Outils : Deplacement, Rectangle de selection, Lasso, Baguette magique,
   Recadrage, Pipette, Pinceau, Tampon, Pinceau historique, Gomme,
   Degrade, Pot de peinture, Flou, Densite-, Plume, Texte, Selection
   tracee, Forme, Main, Loupe. Save/Load BMP. Calques en memoire
   (jusqu'a 8). Undo/Redo simplifies. Filtres : Inverser, Niveaux de
   gris, Lumiere+, Lumiere-, Flou simple, Nettete.)
}

Program PSP;

{$A-}
{$R-}

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$OVERFLOWCHECKS OFF}
 {$RANGECHECKS OFF}
{$ENDIF}

Uses
 {$IFDEF FPC}
  Crt, PtcGraph, PtcCrt, PtcMouse, Dos
 {$ELSE}
  Crt, Graph, Dos
 {$ENDIF};

Const
 VERSION_MAJOR = 1;
 VERSION_MINOR = 0;
 PROGRAM_NAME = 'PSP - Clone Photoshop';

 MENUBAR_HEIGHT  = 16;
 OPTIONSBAR_H    = 22;
 TOOLBAR_WIDTH   = 56;
 LAYERS_WIDTH    = 110;
 STATUSBAR_HEIGHT= 16;

 UI_BG_DARK   = 8;
 UI_BG_PANEL  = 7;
 UI_HILITE    = 15;
 UI_SHADOW    = 0;
 UI_TEXT      = 0;
 UI_TEXT_LITE = 15;
 UI_ACCENT    = 9;
 UI_ICON      = 0;

 MAX_TOOLS    = 24;
 TOOL_MOVE     = 0;
 TOOL_MARQUEE  = 1;
 TOOL_LASSO    = 2;
 TOOL_WAND     = 3;
 TOOL_CROP     = 4;
 TOOL_PICKER   = 5;
 TOOL_BRUSH    = 6;
 TOOL_STAMP    = 7;
 TOOL_HISTBR   = 8;
 TOOL_ERASER   = 9;
 TOOL_GRAD     = 10;
 TOOL_FILL     = 11;
 TOOL_BLUR     = 12;
 TOOL_BURN     = 13;
 TOOL_PEN      = 14;
 TOOL_TEXT     = 15;
 TOOL_PATHSEL  = 16;
 TOOL_SHAPE    = 17;
 TOOL_HAND     = 18;
 TOOL_ZOOM     = 19;
 TOOL_PENCIL   = 20;
 TOOL_LINE     = 21;
 TOOL_RECT     = 22;
 TOOL_ELLIPSE  = 23;

 MENU_FILE    = 0;
 MENU_EDIT    = 1;
 MENU_IMAGE   = 2;
 MENU_LAYER   = 3;
 MENU_SELECT  = 4;
 MENU_FILTER  = 5;
 MENU_VIEW    = 6;
 MENU_WINDOW  = 7;
 MENU_HELP    = 8;
 NUM_MENUS    = 9;

 MAX_LAYERS   = 8;
 MAX_UNDO_LEVELS = 4;
 BMP_SIGNATURE = $4D42;

 VGA_R: Array[0..15] of Byte =
   (  0,   0,   0,   0, 168, 168, 168, 168,  84,  84,  84,  84, 252, 252, 252, 252);
 VGA_G: Array[0..15] of Byte =
   (  0,   0, 168, 168,   0,   0,  84, 168,  84,  84, 252, 252,  84,  84, 252, 252);
 VGA_B: Array[0..15] of Byte =
   (  0, 168,   0, 168,   0, 168,   0, 168,  84, 252,  84, 252,  84, 252,  84, 252);

Type
 TPoint = Record X, Y: Integer; End;
 TRect  = Record L, T, R, B: Integer; End;

 TBMPFileHeader = Packed Record
  bfType: Word;
  bfSize: LongInt;
  bfReserved1, bfReserved2: Word;
  bfOffBits: LongInt;
 End;

 TBMPInfoHeader = Packed Record
  biSize: LongInt;
  biWidth, biHeight: LongInt;
  biPlanes, biBitCount: Word;
  biCompression, biSizeImage: LongInt;
  biXPelsPerMeter, biYPelsPerMeter: LongInt;
  biClrUsed, biClrImportant: LongInt;
 End;

 TRGBQuad = Packed Record Blue, Green, Red, Reserved: Byte; End;

 PByteArr = ^TByteArr;
 TByteArr = Array[0..16777215] of Byte;

 TLayer = Record
  Name: String[20];
  Visible: Boolean;
  Opacity: Byte;
  Pixels: PByteArr;
  Used: Boolean;
 End;

 TMenuItem = Record
  Caption: String[28];
  Shortcut: String[16];
  Separator: Boolean;
 End;

 TMenu = Record
  Title: String[12];
  X, Width: Integer;
  ItemCount: Byte;
  Items: Array[0..27] of TMenuItem;
 End;

 TToolDef = Record
  Name: String[20];
  Hint: String[28];
 End;

Var
 GraphDriver, GraphMode: Integer;
 ScreenWidth, ScreenHeight: Integer;
 Running: Boolean;

 MouseX, MouseY, MouseButtons: Integer;
 OldMouseX, OldMouseY, OldMouseButtons: Integer;
 MouseVisible: Boolean;

 CurrentTool: Byte;
 BrushSize: Byte;
 FgColor, BgColor: Byte;
 Tools: Array[0..MAX_TOOLS-1] of TToolDef;

 Menus: Array[0..NUM_MENUS-1] of TMenu;
 MenuActive: Boolean;
 ActiveMenu, ActiveMenuItem: Integer;

 ImgW, ImgH: Integer;
 CanvasX, CanvasY: Integer;
 CanvasW, CanvasH: Integer;
 ZoomLevel: Integer;
 ImageModified: Boolean;
 CurrentFileName: String;

 Layers: Array[0..MAX_LAYERS-1] of TLayer;
 LayerCount: Integer;
 ActiveLayer: Integer;

 SelectionActive: Boolean;
 SelectionRect: TRect;

 Drawing: Boolean;
 StartX, StartY, EndX, EndY: Integer;

 PreviewActive: Boolean;
 PrevX1, PrevY1, PrevX2, PrevY2: Integer;
 PrevTool: Integer;

 BatchDrawing: Boolean;

 UndoBuffers: Array[0..MAX_UNDO_LEVELS-1] of PByteArr;
 UndoCount: Integer;

 Swatches: Array[0..15] of Byte;

{ ============================================================
   Utilitaires
  ============================================================ }

Function Min(A, B: Integer): Integer;
Begin If A<B Then Min:=A Else Min:=B; End;

Function Max(A, B: Integer): Integer;
Begin If A>B Then Max:=A Else Max:=B; End;

Function IntToStr(N: LongInt): String;
Var S: String; Begin Str(N, S); IntToStr:=S; End;

Function UpperStr(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do
  If (S[I]>='a') And (S[I]<='z') Then S[I]:=Chr(Ord(S[I])-32);
 UpperStr:=S;
End;

Function ExtractExt(FN: String): String;
Var I: Integer; E: String;
Begin
 E:='';
 For I:=Length(FN) DownTo 1 Do
  If FN[I]='.' Then Begin E:=Copy(FN, I, 255); Break; End;
 ExtractExt:=UpperStr(E);
End;

{ ============================================================
   Souris
  ============================================================ }

{$IFNDEF FPC}
Procedure InitMouseDriver;
Var Regs: Registers;
Begin
 Regs.AX:=$0000; Intr($33, Regs);
 MouseVisible:=(Regs.AX=$FFFF);
End;
Procedure ShowMouseCursor;
Var Regs: Registers;
Begin If MouseVisible Then Begin Regs.AX:=$0001; Intr($33, Regs); End; End;
Procedure HideMouseCursor;
Var Regs: Registers;
Begin If MouseVisible Then Begin Regs.AX:=$0002; Intr($33, Regs); End; End;
Procedure GetMouseStateLocal(Var X, Y, B: Integer);
Var Regs: Registers;
Begin
 Regs.AX:=$0003; Intr($33, Regs);
 X:=Regs.CX; Y:=Regs.DX; B:=Regs.BX;
End;
{$ELSE}
Procedure InitMouseDriver;
Begin PtcMouse.InitMouse; MouseVisible:=True; End;
Procedure ShowMouseCursor;
Begin PtcMouse.ShowMouse; End;
Procedure HideMouseCursor;
Begin PtcMouse.HideMouse; End;
Procedure GetMouseStateLocal(Var X, Y, B: Integer);
Var LX, LY, LB: LongInt;
Begin
 PtcMouse.GetMouseState(LX, LY, LB);
 X:=LX; Y:=LY; B:=LB;
End;
{$ENDIF}

{ ============================================================
   Calques
  ============================================================ }

Function PixelOffset(X, Y: Integer): LongInt;
Begin PixelOffset := LongInt(Y) * ImgW + X; End;

Procedure ClearLayer(LIdx: Integer; Color: Byte);
Var Sz, I: LongInt;
Begin
 If (LIdx<0) Or (LIdx>=MAX_LAYERS) Then Exit;
 If Layers[LIdx].Pixels=Nil Then Exit;
 Sz := LongInt(ImgW) * ImgH;
 For I:=0 To Sz-1 Do Layers[LIdx].Pixels^[I] := Color;
End;

Procedure AllocLayer(LIdx: Integer; Const Nm: String; Transparent: Boolean);
Var Sz: LongInt;
Begin
 If (LIdx<0) Or (LIdx>=MAX_LAYERS) Then Exit;
 Sz := LongInt(ImgW) * ImgH;
 GetMem(Layers[LIdx].Pixels, Sz);
 Layers[LIdx].Name := Nm;
 Layers[LIdx].Visible := True;
 Layers[LIdx].Opacity := 100;
 Layers[LIdx].Used := True;
 If Transparent Then ClearLayer(LIdx, 255) Else ClearLayer(LIdx, White);
End;

Procedure FreeLayer(LIdx: Integer);
Var Sz: LongInt;
Begin
 If (LIdx<0) Or (LIdx>=MAX_LAYERS) Then Exit;
 If Layers[LIdx].Pixels<>Nil Then Begin
  Sz := LongInt(ImgW) * ImgH;
  FreeMem(Layers[LIdx].Pixels, Sz);
  Layers[LIdx].Pixels := Nil;
 End;
 Layers[LIdx].Used := False;
End;

Procedure SetLayerPixel(LIdx, X, Y: Integer; Color: Byte);
Var Off: LongInt;
Begin
 If (LIdx<0) Or (LIdx>=MAX_LAYERS) Then Exit;
 If Layers[LIdx].Pixels=Nil Then Exit;
 If (X<0) Or (Y<0) Or (X>=ImgW) Or (Y>=ImgH) Then Exit;
 Off := PixelOffset(X, Y);
 Layers[LIdx].Pixels^[Off] := Color;
End;

Function GetLayerPixel(LIdx, X, Y: Integer): Byte;
Var Off: LongInt;
Begin
 GetLayerPixel := 255;
 If (LIdx<0) Or (LIdx>=MAX_LAYERS) Then Exit;
 If Layers[LIdx].Pixels=Nil Then Exit;
 If (X<0) Or (Y<0) Or (X>=ImgW) Or (Y>=ImgH) Then Exit;
 Off := PixelOffset(X, Y);
 GetLayerPixel := Layers[LIdx].Pixels^[Off];
End;

Function Composite(X, Y: Integer): Byte;
Var I: Integer; V: Byte;
Begin
 Composite := 255;
 For I:=LayerCount-1 DownTo 0 Do Begin
  If Not Layers[I].Used Then Continue;
  If Not Layers[I].Visible Then Continue;
  V := GetLayerPixel(I, X, Y);
  If V<>255 Then Begin Composite := V; Exit; End;
 End;
End;

{ ============================================================
   Undo simplifie
  ============================================================ }

Procedure PushUndo;
Var Sz: LongInt; I: Integer;
Begin
 If (ActiveLayer<0) Or (Not Layers[ActiveLayer].Used) Then Exit;
 Sz := LongInt(ImgW) * ImgH;
 If UndoCount=MAX_UNDO_LEVELS Then Begin
  If UndoBuffers[0]<>Nil Then FreeMem(UndoBuffers[0], Sz);
  For I:=0 To MAX_UNDO_LEVELS-2 Do UndoBuffers[I] := UndoBuffers[I+1];
  UndoBuffers[MAX_UNDO_LEVELS-1] := Nil;
  Dec(UndoCount);
 End;
 GetMem(UndoBuffers[UndoCount], Sz);
 Move(Layers[ActiveLayer].Pixels^, UndoBuffers[UndoCount]^, Sz);
 Inc(UndoCount);
End;

Procedure DoUndo;
Var Sz: LongInt;
Begin
 If UndoCount<=0 Then Exit;
 If (ActiveLayer<0) Or (Not Layers[ActiveLayer].Used) Then Exit;
 Sz := LongInt(ImgW) * ImgH;
 Dec(UndoCount);
 Move(UndoBuffers[UndoCount]^, Layers[ActiveLayer].Pixels^, Sz);
 FreeMem(UndoBuffers[UndoCount], Sz);
 UndoBuffers[UndoCount] := Nil;
End;

{ ============================================================
   Initialisation graphique
  ============================================================ }

Procedure InitGraphics;
Begin
 {$IFDEF FPC}
  GraphDriver := VGA;
  GraphMode := VGAHi;
 {$ELSE}
  GraphDriver := Detect;
 {$ENDIF}
 InitGraph(GraphDriver, GraphMode, '');
 If GraphResult<>grOk Then Begin
  WriteLn('Erreur d''initialisation graphique!');
  Halt(1);
 End;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
End;

{ ============================================================
   Menus
  ============================================================ }

Procedure SetMenuItem(MIdx, IIdx: Integer; Const Cap, Sc: String; Sep: Boolean);
Begin
 Menus[MIdx].Items[IIdx].Caption := Cap;
 Menus[MIdx].Items[IIdx].Shortcut := Sc;
 Menus[MIdx].Items[IIdx].Separator := Sep;
End;

Procedure InitMenus;
Var I, X: Integer;
Begin
 Menus[MENU_FILE].Title    := 'Fichier';
 Menus[MENU_EDIT].Title    := 'Edition';
 Menus[MENU_IMAGE].Title   := 'Image';
 Menus[MENU_LAYER].Title   := 'Calque';
 Menus[MENU_SELECT].Title  := 'Selection';
 Menus[MENU_FILTER].Title  := 'Filtre';
 Menus[MENU_VIEW].Title    := 'Affichage';
 Menus[MENU_WINDOW].Title  := 'Fenetre';
 Menus[MENU_HELP].Title    := 'Aide';

 Menus[MENU_FILE].ItemCount := 24;
 SetMenuItem(MENU_FILE, 0,  'Nouveau...',         'Ctrl+N',         False);
 SetMenuItem(MENU_FILE, 1,  'Ouvrir...',          'Ctrl+O',         False);
 SetMenuItem(MENU_FILE, 2,  'Ouvrir sous...',     'Alt+Ctrl+O',     False);
 SetMenuItem(MENU_FILE, 3,  'Ouvrir recent',      '',               False);
 SetMenuItem(MENU_FILE, 4,  '-',                  '',               True);
 SetMenuItem(MENU_FILE, 5,  'Fermer',             'Ctrl+W',         False);
 SetMenuItem(MENU_FILE, 6,  'Fermer tout',        'Alt+Ctrl+W',     False);
 SetMenuItem(MENU_FILE, 7,  'Revenir',            'F12',            False);
 SetMenuItem(MENU_FILE, 8,  '-',                  '',               True);
 SetMenuItem(MENU_FILE, 9,  'Enregistrer',        'Ctrl+S',         False);
 SetMenuItem(MENU_FILE, 10, 'Enregistrer sous...','Maj+Ctrl+S',     False);
 SetMenuItem(MENU_FILE, 11, '-',                  '',               True);
 SetMenuItem(MENU_FILE, 12, 'Importer',           '',               False);
 SetMenuItem(MENU_FILE, 13, 'Exporter',           '',               False);
 SetMenuItem(MENU_FILE, 14, 'Generer',            '',               False);
 SetMenuItem(MENU_FILE, 15, 'Scripts',            '',               False);
 SetMenuItem(MENU_FILE, 16, 'Automatiser',        '',               False);
 SetMenuItem(MENU_FILE, 17, '-',                  '',               True);
 SetMenuItem(MENU_FILE, 18, 'Info fichier...',    'Alt+Maj+Ctrl+I', False);
 SetMenuItem(MENU_FILE, 19, '-',                  '',               True);
 SetMenuItem(MENU_FILE, 20, 'Imprimer...',        'Ctrl+P',         False);
 SetMenuItem(MENU_FILE, 21, 'Imprimer une copie', 'Alt+Maj+Ctrl+P', False);
 SetMenuItem(MENU_FILE, 22, '-',                  '',               True);
 SetMenuItem(MENU_FILE, 23, 'Quitter',            'Ctrl+Q',         False);

 Menus[MENU_EDIT].ItemCount := 7;
 SetMenuItem(MENU_EDIT, 0, 'Annuler',          'Ctrl+Z', False);
 SetMenuItem(MENU_EDIT, 1, 'Retablir',         'Ctrl+Y', False);
 SetMenuItem(MENU_EDIT, 2, '-',                '',       True);
 SetMenuItem(MENU_EDIT, 3, 'Couper',           'Ctrl+X', False);
 SetMenuItem(MENU_EDIT, 4, 'Copier',           'Ctrl+C', False);
 SetMenuItem(MENU_EDIT, 5, 'Coller',           'Ctrl+V', False);
 SetMenuItem(MENU_EDIT, 6, 'Effacer',          'Del',    False);

 Menus[MENU_IMAGE].ItemCount := 5;
 SetMenuItem(MENU_IMAGE, 0, 'Taille image...', '',       False);
 SetMenuItem(MENU_IMAGE, 1, 'Rotation 90 H',   '',       False);
 SetMenuItem(MENU_IMAGE, 2, 'Rotation 90 AH',  '',       False);
 SetMenuItem(MENU_IMAGE, 3, 'Sym. horiz.',     '',       False);
 SetMenuItem(MENU_IMAGE, 4, 'Sym. vert.',      '',       False);

 Menus[MENU_LAYER].ItemCount := 5;
 SetMenuItem(MENU_LAYER, 0, 'Nouveau calque',  'Ctrl+N', False);
 SetMenuItem(MENU_LAYER, 1, 'Dupliquer',       '',       False);
 SetMenuItem(MENU_LAYER, 2, 'Supprimer',       '',       False);
 SetMenuItem(MENU_LAYER, 3, '-',               '',       True);
 SetMenuItem(MENU_LAYER, 4, 'Aplatir',         '',       False);

 Menus[MENU_SELECT].ItemCount := 4;
 SetMenuItem(MENU_SELECT, 0, 'Tout',           'Ctrl+A', False);
 SetMenuItem(MENU_SELECT, 1, 'Deselect.',      'Ctrl+D', False);
 SetMenuItem(MENU_SELECT, 2, 'Inverser',       '',       False);
 SetMenuItem(MENU_SELECT, 3, 'Recadrer',       '',       False);

 Menus[MENU_FILTER].ItemCount := 6;
 SetMenuItem(MENU_FILTER, 0, 'Inverser',       '',       False);
 SetMenuItem(MENU_FILTER, 1, 'Niveaux gris',   '',       False);
 SetMenuItem(MENU_FILTER, 2, 'Lumiere +',      '',       False);
 SetMenuItem(MENU_FILTER, 3, 'Lumiere -',      '',       False);
 SetMenuItem(MENU_FILTER, 4, 'Flou',           '',       False);
 SetMenuItem(MENU_FILTER, 5, 'Nettete',        '',       False);

 Menus[MENU_VIEW].ItemCount := 4;
 SetMenuItem(MENU_VIEW, 0, 'Zoom +',           'Ctrl++', False);
 SetMenuItem(MENU_VIEW, 1, 'Zoom -',           'Ctrl+-', False);
 SetMenuItem(MENU_VIEW, 2, '100%',             '',       False);
 SetMenuItem(MENU_VIEW, 3, 'Plein ecran',      '',       False);

 Menus[MENU_WINDOW].ItemCount := 3;
 SetMenuItem(MENU_WINDOW, 0, 'Outils',         '',       False);
 SetMenuItem(MENU_WINDOW, 1, 'Calques',        'F7',     False);
 SetMenuItem(MENU_WINDOW, 2, 'Couleurs',       '',       False);

 Menus[MENU_HELP].ItemCount := 2;
 SetMenuItem(MENU_HELP, 0, 'A propos...',      '',       False);
 SetMenuItem(MENU_HELP, 1, 'Raccourcis',       'F1',     False);

 X := 4;
 For I:=0 To NUM_MENUS-1 Do Begin
  Menus[I].X := X;
  Menus[I].Width := Length(Menus[I].Title) * 8 + 12;
  X := X + Menus[I].Width;
 End;
End;

Procedure InitTools;
Begin
 Tools[TOOL_MOVE].Name    := 'Deplacement';   Tools[TOOL_MOVE].Hint    := 'V - Deplacer';
 Tools[TOOL_MARQUEE].Name := 'Rect.Selection';Tools[TOOL_MARQUEE].Hint := 'M - Selection rect.';
 Tools[TOOL_LASSO].Name   := 'Lasso';         Tools[TOOL_LASSO].Hint   := 'L - Lasso libre';
 Tools[TOOL_WAND].Name    := 'Baguette';      Tools[TOOL_WAND].Hint    := 'W - Baguette magique';
 Tools[TOOL_CROP].Name    := 'Recadrage';     Tools[TOOL_CROP].Hint    := 'C - Recadrer';
 Tools[TOOL_PICKER].Name  := 'Pipette';       Tools[TOOL_PICKER].Hint  := 'I - Pipette';
 Tools[TOOL_BRUSH].Name   := 'Pinceau';       Tools[TOOL_BRUSH].Hint   := 'B - Pinceau';
 Tools[TOOL_STAMP].Name   := 'Tampon';        Tools[TOOL_STAMP].Hint   := 'S - Tampon';
 Tools[TOOL_HISTBR].Name  := 'Pinc.Hist.';    Tools[TOOL_HISTBR].Hint  := 'Y - Pinc.historique';
 Tools[TOOL_ERASER].Name  := 'Gomme';         Tools[TOOL_ERASER].Hint  := 'E - Gomme';
 Tools[TOOL_GRAD].Name    := 'Degrade';       Tools[TOOL_GRAD].Hint    := 'G - Degrade';
 Tools[TOOL_FILL].Name    := 'Pot peinture';  Tools[TOOL_FILL].Hint    := 'K - Pot de peinture';
 Tools[TOOL_BLUR].Name    := 'Flou';          Tools[TOOL_BLUR].Hint    := 'R - Flou';
 Tools[TOOL_BURN].Name    := 'Densite-';      Tools[TOOL_BURN].Hint    := 'O - Densite -';
 Tools[TOOL_PEN].Name     := 'Plume';         Tools[TOOL_PEN].Hint     := 'P - Plume';
 Tools[TOOL_TEXT].Name    := 'Texte';         Tools[TOOL_TEXT].Hint    := 'T - Texte';
 Tools[TOOL_PATHSEL].Name := 'Sel.Trace';     Tools[TOOL_PATHSEL].Hint := 'A - Selection trace';
 Tools[TOOL_SHAPE].Name   := 'Forme';         Tools[TOOL_SHAPE].Hint   := 'U - Forme';
 Tools[TOOL_HAND].Name    := 'Main';          Tools[TOOL_HAND].Hint    := 'H - Main';
 Tools[TOOL_ZOOM].Name    := 'Loupe';         Tools[TOOL_ZOOM].Hint    := 'Z - Loupe';
 Tools[TOOL_PENCIL].Name  := 'Crayon';        Tools[TOOL_PENCIL].Hint  := 'N - Crayon';
 Tools[TOOL_LINE].Name    := 'Ligne';         Tools[TOOL_LINE].Hint    := 'Ligne droite';
 Tools[TOOL_RECT].Name    := 'Rectangle';     Tools[TOOL_RECT].Hint    := 'Rectangle';
 Tools[TOOL_ELLIPSE].Name := 'Ellipse';       Tools[TOOL_ELLIPSE].Hint := 'Ellipse';
End;

Procedure InitSwatches;
Begin
 Swatches[0]  := Black;
 Swatches[1]  := DarkGray;
 Swatches[2]  := LightGray;
 Swatches[3]  := White;
 Swatches[4]  := Red;
 Swatches[5]  := LightRed;
 Swatches[6]  := Brown;
 Swatches[7]  := Yellow;
 Swatches[8]  := Green;
 Swatches[9]  := LightGreen;
 Swatches[10] := Cyan;
 Swatches[11] := LightCyan;
 Swatches[12] := Blue;
 Swatches[13] := LightBlue;
 Swatches[14] := Magenta;
 Swatches[15] := LightMagenta;
End;

{ ============================================================
   Dessin de l'interface
  ============================================================ }

Procedure DrawBevel(X1, Y1, X2, Y2: Integer; Up: Boolean);
Var HC, SC: Byte;
Begin
 If Up Then Begin HC:=UI_HILITE; SC:=UI_SHADOW; End
       Else Begin HC:=UI_SHADOW; SC:=UI_HILITE; End;
 SetColor(HC);
 Line(X1, Y1, X2, Y1);
 Line(X1, Y1, X1, Y2);
 SetColor(SC);
 Line(X1, Y2, X2, Y2);
 Line(X2, Y1, X2, Y2);
End;

Procedure FillRect(X1, Y1, X2, Y2: Integer; Color: Byte);
Begin
 SetFillStyle(SolidFill, Color);
 Bar(X1, Y1, X2, Y2);
End;

Procedure DrawMenuBar;
Var I: Integer;
Begin
 FillRect(0, 0, ScreenWidth-1, MENUBAR_HEIGHT-1, UI_BG_DARK);
 SetColor(UI_SHADOW);
 Line(0, MENUBAR_HEIGHT-1, ScreenWidth-1, MENUBAR_HEIGHT-1);
 SetTextStyle(DefaultFont, HorizDir, 1);
 For I:=0 To NUM_MENUS-1 Do Begin
  If MenuActive And (ActiveMenu=I) Then
   FillRect(Menus[I].X-2, 1, Menus[I].X+Menus[I].Width-4, MENUBAR_HEIGHT-2, UI_ACCENT);
  SetColor(UI_TEXT_LITE);
  OutTextXY(Menus[I].X+4, 4, Menus[I].Title);
 End;
End;

Procedure DrawOptionsBar;
Var Y: Integer; S: String;
Begin
 Y := MENUBAR_HEIGHT;
 FillRect(0, Y, ScreenWidth-1, Y+OPTIONSBAR_H-1, UI_BG_PANEL);
 SetColor(UI_SHADOW);
 Line(0, Y+OPTIONSBAR_H-1, ScreenWidth-1, Y+OPTIONSBAR_H-1);
 SetColor(UI_TEXT);
 OutTextXY(6, Y+6, 'Outil:');
 SetColor(UI_ACCENT);
 If (CurrentTool<MAX_TOOLS) Then OutTextXY(50, Y+6, Tools[CurrentTool].Name);
 SetColor(UI_TEXT);
 S := 'Taille:';
 OutTextXY(180, Y+6, S);
 DrawBevel(220, Y+4, 268, Y+OPTIONSBAR_H-5, False);
 SetColor(UI_TEXT);
 OutTextXY(225, Y+6, IntToStr(BrushSize) + ' px');
 OutTextXY(300, Y+6, 'Zoom:'+IntToStr(ZoomLevel)+'%');
 If (CurrentTool<MAX_TOOLS) Then Begin
  SetColor(DarkGray);
  OutTextXY(390, Y+6, Tools[CurrentTool].Hint);
 End;
End;

Procedure DrawToolButton(IX, IY: Integer; ToolIdx: Byte; Selected: Boolean);
Var CX, CY: Integer;
Begin
 If Selected Then FillRect(IX, IY, IX+23, IY+23, UI_ACCENT)
             Else FillRect(IX, IY, IX+23, IY+23, UI_BG_PANEL);
 DrawBevel(IX, IY, IX+23, IY+23, Not Selected);
 CX := IX+12; CY := IY+12;
 SetColor(UI_ICON);
 Case ToolIdx Of
  TOOL_MOVE: Begin
   Line(CX-7, CY, CX+7, CY); Line(CX, CY-7, CX, CY+7);
   Line(CX-5, CY-2, CX-7, CY); Line(CX-5, CY+2, CX-7, CY);
   Line(CX+5, CY-2, CX+7, CY); Line(CX+5, CY+2, CX+7, CY);
   Line(CX-2, CY-5, CX, CY-7); Line(CX+2, CY-5, CX, CY-7);
   Line(CX-2, CY+5, CX, CY+7); Line(CX+2, CY+5, CX, CY+7);
  End;
  TOOL_MARQUEE: Rectangle(CX-7, CY-5, CX+7, CY+5);
  TOOL_LASSO: Begin
   Ellipse(CX, CY-2, 0, 360, 6, 4);
   Line(CX-2, CY+2, CX-4, CY+7);
  End;
  TOOL_WAND: Begin
   Line(CX-7, CY+7, CX+3, CY-3);
   Line(CX+3, CY-7, CX+5, CY-5);
   Line(CX+7, CY-3, CX+5, CY-5);
   Line(CX+5, CY-3, CX+5, CY-7);
   Line(CX+3, CY-5, CX+7, CY-5);
  End;
  TOOL_CROP: Begin
   Line(CX-7, CY-3, CX-7, CY+7); Line(CX-7, CY+7, CX+3, CY+7);
   Line(CX-3, CY-7, CX+7, CY-7); Line(CX+7, CY-7, CX+7, CY+3);
  End;
  TOOL_PICKER: Begin
   Line(CX-7, CY+7, CX-2, CY+2);
   Line(CX-2, CY+2, CX+3, CY-3);
   Line(CX+3, CY-3, CX+6, CY+0);
   Line(CX+6, CY+0, CX+2, CY+4);
   Line(CX+3, CY-3, CX+6, CY-6);
  End;
  TOOL_BRUSH: Begin
   Line(CX-7, CY+7, CX+2, CY-2);
   Line(CX+2, CY-2, CX+5, CY-5);
   Line(CX+5, CY-5, CX+7, CY-3);
   Line(CX+7, CY-3, CX+4, CY+0);
   Line(CX+4, CY+0, CX-5, CY+7);
  End;
  TOOL_STAMP: Begin
   Ellipse(CX, CY+5, 0, 360, 7, 2);
   Line(CX-3, CY+3, CX-3, CY-3); Line(CX+3, CY+3, CX+3, CY-3);
   Line(CX-3, CY-3, CX+3, CY-3);
   Line(CX, CY-3, CX, CY-7);
  End;
  TOOL_HISTBR: Begin
   Line(CX-7, CY+7, CX+5, CY-5);
   Line(CX+5, CY-5, CX+7, CY-3);
   Line(CX-5, CY-5, CX-3, CY-5);
   Line(CX-5, CY-5, CX-5, CY-3);
  End;
  TOOL_ERASER: Begin
   Rectangle(CX-7, CY+0, CX+1, CY+7);
   Line(CX-7, CY, CX-3, CY-4); Line(CX-3, CY-4, CX+5, CY-4);
   Line(CX+5, CY-4, CX+1, CY);
   Line(CX+1, CY+7, CX+5, CY+3); Line(CX+5, CY-4, CX+5, CY+3);
  End;
  TOOL_GRAD: Begin
   Rectangle(CX-7, CY-5, CX+7, CY+5);
   Line(CX-5, CY-3, CX-5, CY+3);
   Line(CX-2, CY-3, CX-2, CY+3);
   Line(CX+2, CY-3, CX+2, CY+3);
   Line(CX+5, CY-3, CX+5, CY+3);
  End;
  TOOL_FILL: Begin
   Line(CX-6, CY-2, CX-2, CY-6); Line(CX-2, CY-6, CX+4, CY+0);
   Line(CX+4, CY+0, CX+0, CY+4); Line(CX+0, CY+4, CX-6, CY-2);
   Line(CX+4, CY+0, CX+6, CY+3);
   Line(CX+6, CY+3, CX+6, CY+6);
  End;
  TOOL_BLUR: Begin
   Ellipse(CX, CY+1, 0, 360, 4, 5);
   Line(CX, CY-4, CX-2, CY-7);
   Line(CX, CY-4, CX+2, CY-7);
  End;
  TOOL_BURN: Begin
   Circle(CX, CY, 6);
   PutPixel(CX-2, CY-2, UI_ICON);
   PutPixel(CX+2, CY-2, UI_ICON);
  End;
  TOOL_PEN: Begin
   Line(CX-7, CY+7, CX+3, CY-3);
   Line(CX+3, CY-3, CX+7, CY-7);
   Line(CX-7, CY+7, CX-3, CY+5);
   Line(CX+3, CY-3, CX+5, CY+1);
  End;
  TOOL_TEXT: Begin
   Line(CX-6, CY-6, CX+6, CY-6);
   Line(CX, CY-6, CX, CY+7);
  End;
  TOOL_PATHSEL: Begin
   Line(CX-5, CY-6, CX-5, CY+5);
   Line(CX-5, CY-6, CX+3, CY+2);
   Line(CX-5, CY+5, CX-1, CY+1);
   Line(CX-1, CY+1, CX+3, CY+2);
  End;
  TOOL_SHAPE: Rectangle(CX-6, CY-5, CX+6, CY+5);
  TOOL_HAND: Begin
   Rectangle(CX-5, CY-2, CX+5, CY+6);
   Line(CX-5, CY-2, CX-5, CY-6);
   Line(CX-2, CY-2, CX-2, CY-7);
   Line(CX+1, CY-2, CX+1, CY-7);
   Line(CX+5, CY-2, CX+5, CY-5);
  End;
  TOOL_ZOOM: Begin
   Circle(CX-1, CY-1, 5);
   Line(CX+3, CY+3, CX+7, CY+7);
  End;
  TOOL_PENCIL: Begin
   Line(CX-7, CY+7, CX+4, CY-4);
   Line(CX+4, CY-4, CX+6, CY-2);
   Line(CX+6, CY-2, CX-5, CY+7);
  End;
  TOOL_LINE: Line(CX-7, CY+7, CX+7, CY-7);
  TOOL_RECT: Rectangle(CX-7, CY-5, CX+7, CY+5);
  TOOL_ELLIPSE: Ellipse(CX, CY, 0, 360, 7, 5);
 End;
End;

Procedure DrawToolbar;
Var I, Col, Row, X, Y: Integer;
Begin
 FillRect(0, MENUBAR_HEIGHT+OPTIONSBAR_H, TOOLBAR_WIDTH-1,
          ScreenHeight-STATUSBAR_HEIGHT-1, UI_BG_PANEL);
 SetColor(UI_SHADOW);
 Line(TOOLBAR_WIDTH-1, MENUBAR_HEIGHT+OPTIONSBAR_H,
      TOOLBAR_WIDTH-1, ScreenHeight-STATUSBAR_HEIGHT-1);
 For I:=0 To MAX_TOOLS-1 Do Begin
  Col := I Mod 2;
  Row := I Div 2;
  X := 2 + Col*26;
  Y := MENUBAR_HEIGHT + OPTIONSBAR_H + 4 + Row*26;
  DrawToolButton(X, Y, I, I=CurrentTool);
 End;
End;

Procedure DrawColorSwatchBox;
Var X, Y: Integer;
Begin
 X := 6;
 Y := ScreenHeight - STATUSBAR_HEIGHT - 38;
 FillRect(X+10, Y+10, X+26, Y+26, BgColor);
 SetColor(UI_SHADOW); Rectangle(X+10, Y+10, X+26, Y+26);
 FillRect(X, Y, X+16, Y+16, FgColor);
 SetColor(UI_SHADOW); Rectangle(X, Y, X+16, Y+16);
 SetColor(UI_TEXT);
 Line(X+22, Y+2, X+28, Y+2);
 Line(X+28, Y+2, X+26, Y+0);
 Line(X+28, Y+2, X+26, Y+4);
 Line(X+22, Y+2, X+24, Y+0);
 Line(X+22, Y+2, X+24, Y+4);
End;

Procedure DrawLayersPanel;
Var
 PX1, PY1, PX2, PY2, Y, I: Integer;
 S: String;
Begin
 PX1 := ScreenWidth - LAYERS_WIDTH;
 PY1 := MENUBAR_HEIGHT + OPTIONSBAR_H;
 PX2 := ScreenWidth - 1;
 PY2 := ScreenHeight - STATUSBAR_HEIGHT - 1;
 FillRect(PX1, PY1, PX2, PY2, UI_BG_PANEL);
 SetColor(UI_SHADOW);
 Line(PX1, PY1, PX1, PY2);
 FillRect(PX1, PY1, PX2, PY1+14, UI_BG_DARK);
 SetColor(UI_TEXT_LITE);
 OutTextXY(PX1+6, PY1+4, 'Calques');
 Y := PY1 + 20;
 For I:=LayerCount-1 DownTo 0 Do Begin
  If I=ActiveLayer Then FillRect(PX1+2, Y, PX2-2, Y+18, UI_ACCENT);
  SetColor(UI_SHADOW);
  Rectangle(PX1+4, Y+2, PX1+22, Y+16);
  If Layers[I].Visible Then Begin
   SetColor(UI_TEXT);
   Circle(PX1+30, Y+9, 3);
  End;
  SetColor(UI_TEXT);
  S := Layers[I].Name;
  OutTextXY(PX1+38, Y+5, S);
  Y := Y + 20;
  If Y > PY2-44 Then Break;
 End;
 SetColor(UI_SHADOW);
 Line(PX1, PY2-18, PX2, PY2-18);
 SetColor(UI_TEXT);
 OutTextXY(PX1+4,  PY2-14, '[+]');
 OutTextXY(PX1+28, PY2-14, '[D]');
 OutTextXY(PX1+52, PY2-14, '[X]');
 OutTextXY(PX1+76, PY2-14, '[F]');
End;

Procedure DrawSwatchesBar;
Var PX1, PY1, X, I: Integer;
Begin
 PX1 := ScreenWidth - LAYERS_WIDTH;
 PY1 := ScreenHeight - STATUSBAR_HEIGHT - 32;
 SetColor(UI_SHADOW);
 Line(PX1, PY1-1, ScreenWidth-1, PY1-1);
 For I:=0 To 15 Do Begin
  X := PX1 + 4 + (I Mod 8)*12;
  FillRect(X, PY1 + (I Div 8)*10, X+10, PY1 + (I Div 8)*10 + 8, Swatches[I]);
 End;
End;

Procedure DrawStatusBar;
Var Y: Integer; S: String;
Begin
 Y := ScreenHeight - STATUSBAR_HEIGHT;
 FillRect(0, Y, ScreenWidth-1, ScreenHeight-1, UI_BG_DARK);
 SetColor(UI_HILITE);
 Line(0, Y, ScreenWidth-1, Y);
 SetColor(UI_TEXT_LITE);
 S := IntToStr(ImgW)+' x '+IntToStr(ImgH)+'  Zoom:'+IntToStr(ZoomLevel)+'%';
 OutTextXY(6, Y+4, S);
 S := 'X:'+IntToStr(MouseX)+' Y:'+IntToStr(MouseY);
 OutTextXY(180, Y+4, S);
 If (ActiveLayer>=0) And (ActiveLayer<LayerCount) Then Begin
  S := 'Calque:'+Layers[ActiveLayer].Name;
  OutTextXY(290, Y+4, S);
 End;
 If ImageModified Then Begin
  SetColor(UI_ACCENT);
  OutTextXY(ScreenWidth-100, Y+4, '* Modifie');
 End;
End;

Procedure DrawCanvasArea;
Var
 X, Y, IX, IY, SCX, SCY: Integer;
 V: Byte;
 Light: Boolean;
Begin
 CanvasX := TOOLBAR_WIDTH + 8;
 CanvasY := MENUBAR_HEIGHT + OPTIONSBAR_H + 8;
 CanvasW := (ScreenWidth - LAYERS_WIDTH - TOOLBAR_WIDTH - 16);
 CanvasH := (ScreenHeight - STATUSBAR_HEIGHT - MENUBAR_HEIGHT - OPTIONSBAR_H - 16);
 FillRect(TOOLBAR_WIDTH, MENUBAR_HEIGHT+OPTIONSBAR_H,
          ScreenWidth-LAYERS_WIDTH-1, ScreenHeight-STATUSBAR_HEIGHT-1, UI_BG_DARK);
 SetColor(UI_SHADOW);
 Rectangle(CanvasX-1, CanvasY-1, CanvasX+CanvasW, CanvasY+CanvasH);
 For Y:=0 To CanvasH-1 Do
  For X:=0 To CanvasW-1 Do Begin
   IX := LongInt(X) * 100 Div ZoomLevel;
   IY := LongInt(Y) * 100 Div ZoomLevel;
   SCX := CanvasX + X;
   SCY := CanvasY + Y;
   If (IX>=0) And (IX<ImgW) And (IY>=0) And (IY<ImgH) Then Begin
    V := Composite(IX, IY);
    If V=255 Then Begin
     Light := ((IX Div 8) + (IY Div 8)) And 1 = 0;
     If Light Then PutPixel(SCX, SCY, LightGray)
              Else PutPixel(SCX, SCY, White);
    End Else
     PutPixel(SCX, SCY, V);
   End Else
    PutPixel(SCX, SCY, UI_BG_DARK);
  End;
End;

Procedure DrawFullUI;
Begin
 HideMouseCursor;
 FillRect(0, 0, ScreenWidth-1, ScreenHeight-1, UI_BG_DARK);
 DrawCanvasArea;
 DrawMenuBar;
 DrawOptionsBar;
 DrawToolbar;
 DrawColorSwatchBox;
 DrawLayersPanel;
 DrawSwatchesBar;
 DrawStatusBar;
 ShowMouseCursor;
End;

Procedure RefreshCanvas;
Begin
 HideMouseCursor;
 DrawCanvasArea;
 DrawStatusBar;
 ShowMouseCursor;
End;

{ ============================================================
   Conversion ecran <-> image
  ============================================================ }

Function ScreenToImg(SX, SY: Integer; Var IX, IY: Integer): Boolean;
Begin
 ScreenToImg := False;
 If (SX<CanvasX) Or (SY<CanvasY) Then Exit;
 If (SX>=CanvasX+CanvasW) Or (SY>=CanvasY+CanvasH) Then Exit;
 IX := LongInt(SX - CanvasX) * 100 Div ZoomLevel;
 IY := LongInt(SY - CanvasY) * 100 Div ZoomLevel;
 If (IX<0) Or (IX>=ImgW) Or (IY<0) Or (IY>=ImgH) Then Exit;
 ScreenToImg := True;
End;

Procedure ImgToScreen(IX, IY: Integer; Var SX, SY: Integer);
Begin
 SX := CanvasX + LongInt(IX) * ZoomLevel Div 100;
 SY := CanvasY + LongInt(IY) * ZoomLevel Div 100;
End;

Procedure DrawImgPixel(IX, IY: Integer; Color: Byte);
Var SX, SY, Z, DX, DY: Integer;
Begin
 If (IX<0) Or (IY<0) Or (IX>=ImgW) Or (IY>=ImgH) Then Exit;
 SetLayerPixel(ActiveLayer, IX, IY, Color);
 ImageModified := True;
 ImgToScreen(IX, IY, SX, SY);
 Z := ZoomLevel Div 100;
 If Z<1 Then Z:=1;
 If Not BatchDrawing Then HideMouseCursor;
 If Z=1 Then Begin
  If Color=255 Then PutPixel(SX, SY, White) Else PutPixel(SX, SY, Color);
 End Else Begin
  For DY:=0 To Z-1 Do
   For DX:=0 To Z-1 Do
    If Color=255 Then PutPixel(SX+DX, SY+DY, White)
                 Else PutPixel(SX+DX, SY+DY, Color);
 End;
 If Not BatchDrawing Then ShowMouseCursor;
End;

{ ============================================================
   Algorithmes de dessin
  ============================================================ }

Procedure ImgLine(X1, Y1, X2, Y2: Integer; Color: Byte);
Var DX, DY, SX, SY, Err, E2: Integer;
Begin
 DX := Abs(X2-X1); DY := Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 Err := DX - DY;
 Repeat
  DrawImgPixel(X1, Y1, Color);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2 := 2*Err;
  If E2 > -DY Then Begin Err:=Err-DY; X1:=X1+SX; End;
  If E2 <  DX Then Begin Err:=Err+DX; Y1:=Y1+SY; End;
 Until False;
End;

Procedure ImgRect(X1, Y1, X2, Y2: Integer; Color: Byte; Filled: Boolean);
Var X, Y, T: Integer;
Begin
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T; End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T; End;
 If Filled Then Begin
  For Y:=Y1 To Y2 Do
   For X:=X1 To X2 Do DrawImgPixel(X, Y, Color);
 End Else Begin
  ImgLine(X1, Y1, X2, Y1, Color);
  ImgLine(X1, Y2, X2, Y2, Color);
  ImgLine(X1, Y1, X1, Y2, Color);
  ImgLine(X2, Y1, X2, Y2, Color);
 End;
End;

Procedure ImgEllipse(CX, CY, RX, RY: Integer; Color: Byte);
Var
 X, Y: Integer;
 D1, D2, DX, DY: LongInt;
 RX2, RY2: LongInt;
Begin
 If (RX<=0) Or (RY<=0) Then Exit;
 RX2 := LongInt(RX)*RX;
 RY2 := LongInt(RY)*RY;
 X := 0; Y := RY;
 D1 := RY2 - RX2*RY + (RX2 Div 4);
 DX := 2*RY2*X;
 DY := 2*RX2*Y;
 While DX < DY Do Begin
  DrawImgPixel(CX+X, CY+Y, Color);
  DrawImgPixel(CX-X, CY+Y, Color);
  DrawImgPixel(CX+X, CY-Y, Color);
  DrawImgPixel(CX-X, CY-Y, Color);
  If D1 < 0 Then Begin
   Inc(X); DX:=DX + 2*RY2; D1:=D1 + DX + RY2;
  End Else Begin
   Inc(X); Dec(Y); DX:=DX + 2*RY2; DY:=DY - 2*RX2;
   D1:=D1 + DX - DY + RY2;
  End;
 End;
 D2 := Round(RY2*(X+0.5)*(X+0.5) + RX2*LongInt(Y-1)*(Y-1) - RX2*RY2);
 While Y >= 0 Do Begin
  DrawImgPixel(CX+X, CY+Y, Color);
  DrawImgPixel(CX-X, CY+Y, Color);
  DrawImgPixel(CX+X, CY-Y, Color);
  DrawImgPixel(CX-X, CY-Y, Color);
  If D2 > 0 Then Begin
   Dec(Y); DY:=DY - 2*RX2; D2:=D2 + RX2 - DY;
  End Else Begin
   Dec(Y); Inc(X); DX:=DX + 2*RY2; DY:=DY - 2*RX2;
   D2:=D2 + DX - DY + RX2;
  End;
 End;
End;

Procedure FloodFill(X, Y: Integer; NewColor: Byte);
Const STACK_MAX = 4096;
Var
 StackX, StackY: Array[0..STACK_MAX-1] of Integer;
 Top: Integer;
 TargetColor: Byte;
 CX, CY: Integer;

 Procedure Push(PX, PY: Integer);
 Begin
  If Top<STACK_MAX Then Begin
   StackX[Top]:=PX; StackY[Top]:=PY; Inc(Top);
  End;
 End;

Begin
 If (X<0) Or (Y<0) Or (X>=ImgW) Or (Y>=ImgH) Then Exit;
 TargetColor := GetLayerPixel(ActiveLayer, X, Y);
 If TargetColor=NewColor Then Exit;
 Top := 0;
 Push(X, Y);
 While Top>0 Do Begin
  Dec(Top);
  CX := StackX[Top]; CY := StackY[Top];
  If (CX<0) Or (CY<0) Or (CX>=ImgW) Or (CY>=ImgH) Then Continue;
  If GetLayerPixel(ActiveLayer, CX, CY)<>TargetColor Then Continue;
  DrawImgPixel(CX, CY, NewColor);
  Push(CX+1, CY); Push(CX-1, CY);
  Push(CX, CY+1); Push(CX, CY-1);
 End;
End;

Procedure DrawWithBrush(IX, IY: Integer; Color: Byte);
Var DX, DY, R: Integer;
Begin
 R := BrushSize Div 2;
 If R<1 Then R:=1;
 For DY:=-R To R Do
  For DX:=-R To R Do
   If DX*DX + DY*DY <= R*R Then
    DrawImgPixel(IX+DX, IY+DY, Color);
End;

Procedure DrawWithPencil(IX, IY: Integer; Color: Byte);
Begin DrawImgPixel(IX, IY, Color); End;

Procedure EraseAt(IX, IY: Integer);
Var DX, DY, R: Integer;
Begin
 R := BrushSize Div 2;
 If R<1 Then R:=1;
 For DY:=-R To R Do
  For DX:=-R To R Do
   If DX*DX + DY*DY <= R*R Then
    DrawImgPixel(IX+DX, IY+DY, 255);
End;

{ ============================================================
   Filtres
  ============================================================ }

Procedure FilterInvert;
Var X, Y: Integer; V, NV: Byte;
Begin
 PushUndo;
 For Y:=0 To ImgH-1 Do
  For X:=0 To ImgW-1 Do Begin
   V := GetLayerPixel(ActiveLayer, X, Y);
   If V=255 Then Continue;
   If V>15 Then NV := 15 Else NV := Byte(15 - V);
   SetLayerPixel(ActiveLayer, X, Y, NV);
  End;
 ImageModified := True;
End;

Procedure FilterGray;
Var X, Y: Integer; V: Byte;
Begin
 PushUndo;
 For Y:=0 To ImgH-1 Do
  For X:=0 To ImgW-1 Do Begin
   V := GetLayerPixel(ActiveLayer, X, Y);
   If V=255 Then Continue;
   Case V Of
    Black, Blue, Green, Cyan, Red, Magenta, Brown, DarkGray:
     SetLayerPixel(ActiveLayer, X, Y, DarkGray);
    LightGray, LightBlue, LightGreen, LightCyan, LightRed, LightMagenta, Yellow:
     SetLayerPixel(ActiveLayer, X, Y, LightGray);
    White: SetLayerPixel(ActiveLayer, X, Y, White);
   End;
  End;
 ImageModified := True;
End;

Procedure FilterBrighter;
Var X, Y: Integer; V: Byte;
Begin
 PushUndo;
 For Y:=0 To ImgH-1 Do
  For X:=0 To ImgW-1 Do Begin
   V := GetLayerPixel(ActiveLayer, X, Y);
   If V=255 Then Continue;
   If (V<8) Then SetLayerPixel(ActiveLayer, X, Y, V + 8);
  End;
 ImageModified := True;
End;

Procedure FilterDarker;
Var X, Y: Integer; V: Byte;
Begin
 PushUndo;
 For Y:=0 To ImgH-1 Do
  For X:=0 To ImgW-1 Do Begin
   V := GetLayerPixel(ActiveLayer, X, Y);
   If V=255 Then Continue;
   If (V>=8) And (V<=15) Then SetLayerPixel(ActiveLayer, X, Y, V - 8);
  End;
 ImageModified := True;
End;

Procedure FilterBlur;
Var
 X, Y, DX, DY: Integer;
 Sum, Cnt: Integer;
 V: Byte;
 Tmp: PByteArr;
 Sz: LongInt;
Begin
 PushUndo;
 Sz := LongInt(ImgW) * ImgH;
 GetMem(Tmp, Sz);
 Move(Layers[ActiveLayer].Pixels^, Tmp^, Sz);
 For Y:=0 To ImgH-1 Do
  For X:=0 To ImgW-1 Do Begin
   Sum:=0; Cnt:=0;
   For DY:=-1 To 1 Do
    For DX:=-1 To 1 Do Begin
     If (X+DX<0) Or (X+DX>=ImgW) Or (Y+DY<0) Or (Y+DY>=ImgH) Then Continue;
     V := Tmp^[LongInt(Y+DY)*ImgW + (X+DX)];
     If V=255 Then Continue;
     Sum:=Sum + V;
     Inc(Cnt);
    End;
   If Cnt>0 Then SetLayerPixel(ActiveLayer, X, Y, Byte(Sum Div Cnt));
  End;
 FreeMem(Tmp, Sz);
 ImageModified := True;
End;

Procedure FilterSharpen;
Var
 X, Y: Integer;
 Val: Integer;
 C: Byte;
 Tmp: PByteArr;
 Sz: LongInt;
Begin
 PushUndo;
 Sz := LongInt(ImgW) * ImgH;
 GetMem(Tmp, Sz);
 Move(Layers[ActiveLayer].Pixels^, Tmp^, Sz);
 For Y:=1 To ImgH-2 Do
  For X:=1 To ImgW-2 Do Begin
   C := Tmp^[LongInt(Y)*ImgW + X];
   If C=255 Then Continue;
   Val := 5*C
         - Tmp^[LongInt(Y-1)*ImgW + X]
         - Tmp^[LongInt(Y+1)*ImgW + X]
         - Tmp^[LongInt(Y)*ImgW + (X-1)]
         - Tmp^[LongInt(Y)*ImgW + (X+1)];
   If Val<0 Then Val:=0;
   If Val>15 Then Val:=15;
   SetLayerPixel(ActiveLayer, X, Y, Byte(Val));
  End;
 FreeMem(Tmp, Sz);
 ImageModified := True;
End;

{ ============================================================
   Rotation / Symetrie
  ============================================================ }

Procedure RotateLayer90(Clockwise: Boolean);
Var
 NewBuf: PByteArr;
 Sz: LongInt;
 X, Y, NW, NH, I, ActCount: Integer;
Begin
 PushUndo;
 NW := ImgH; NH := ImgW;
 Sz := LongInt(NW)*NH;
 GetMem(NewBuf, Sz);
 For Y:=0 To ImgH-1 Do
  For X:=0 To ImgW-1 Do Begin
   If Clockwise Then
    NewBuf^[LongInt(X)*NW + (NW-1-Y)] := Layers[ActiveLayer].Pixels^[LongInt(Y)*ImgW + X]
   Else
    NewBuf^[LongInt(NH-1-X)*NW + Y] := Layers[ActiveLayer].Pixels^[LongInt(Y)*ImgW + X];
  End;
 FreeMem(Layers[ActiveLayer].Pixels, LongInt(ImgW)*ImgH);
 Layers[ActiveLayer].Pixels := NewBuf;
 ActCount := 0;
 For I:=0 To LayerCount-1 Do If Layers[I].Used Then Inc(ActCount);
 If ActCount=1 Then Begin ImgW := NW; ImgH := NH; End;
 ImageModified := True;
End;

Procedure FlipH;
Var X, Y, T: Integer; V1, V2: Byte;
Begin
 PushUndo;
 For Y:=0 To ImgH-1 Do
  For X:=0 To (ImgW Div 2)-1 Do Begin
   T := ImgW-1-X;
   V1 := GetLayerPixel(ActiveLayer, X, Y);
   V2 := GetLayerPixel(ActiveLayer, T, Y);
   SetLayerPixel(ActiveLayer, X, Y, V2);
   SetLayerPixel(ActiveLayer, T, Y, V1);
  End;
 ImageModified := True;
End;

Procedure FlipV;
Var X, Y, T: Integer; V1, V2: Byte;
Begin
 PushUndo;
 For X:=0 To ImgW-1 Do
  For Y:=0 To (ImgH Div 2)-1 Do Begin
   T := ImgH-1-Y;
   V1 := GetLayerPixel(ActiveLayer, X, Y);
   V2 := GetLayerPixel(ActiveLayer, X, T);
   SetLayerPixel(ActiveLayer, X, Y, V2);
   SetLayerPixel(ActiveLayer, X, T, V1);
  End;
 ImageModified := True;
End;

{ ============================================================
   BMP Save / Load
  ============================================================ }

Function SaveBMP24(Const FileName: String): Boolean;
Var
 F: File;
 FH: TBMPFileHeader;
 IH: TBMPInfoHeader;
 RowSize, Pad, X, Y: Integer;
 V: Byte;
 RowBuf: Array[0..4095] of Byte;
Begin
 SaveBMP24 := False;
 RowSize := ((LongInt(ImgW) * 24 + 31) Div 32) * 4;
 Pad := RowSize - ImgW*3;

 Assign(F, FileName);
 {$I-} Rewrite(F, 1); {$I+}
 If IOResult<>0 Then Exit;

 FillChar(FH, SizeOf(FH), 0);
 FH.bfType := BMP_SIGNATURE;
 FH.bfOffBits := SizeOf(FH) + SizeOf(IH);
 FH.bfSize := FH.bfOffBits + LongInt(RowSize)*ImgH;

 FillChar(IH, SizeOf(IH), 0);
 IH.biSize := SizeOf(IH);
 IH.biWidth := ImgW;
 IH.biHeight := ImgH;
 IH.biPlanes := 1;
 IH.biBitCount := 24;
 IH.biCompression := 0;
 IH.biSizeImage := LongInt(RowSize)*ImgH;

 BlockWrite(F, FH, SizeOf(FH));
 BlockWrite(F, IH, SizeOf(IH));

 For Y:=ImgH-1 DownTo 0 Do Begin
  For X:=0 To ImgW-1 Do Begin
   V := Composite(X, Y);
   If V=255 Then V:=15;  { transparent -> blanc a l'export }
   If V>15 Then V:=0;
   RowBuf[X*3]   := VGA_B[V];
   RowBuf[X*3+1] := VGA_G[V];
   RowBuf[X*3+2] := VGA_R[V];
  End;
  For X:=0 To Pad-1 Do RowBuf[ImgW*3 + X] := 0;
  BlockWrite(F, RowBuf, RowSize);
 End;

 Close(F);
 SaveBMP24 := True;
End;

Function LoadBMP(Const FileName: String): Boolean;
Var
 F: File;
 FH: TBMPFileHeader;
 IH: TBMPInfoHeader;
 BytesRead: Word;
 RowSize, X, Y, SrcY, I, Best: Integer;
 RowBuf: Array[0..4095] of Byte;
 R, G, B: Byte;
 DR, DG, DB, Dist, BestDist: LongInt;
 BMPPal: Array[0..255] of TRGBQuad;
 PalRemap: Array[0..255] of Byte;
 PaletteEntries: Integer;
 V: Byte;
 BitPos: Integer;
 ByteVal: Byte;
Begin
 LoadBMP := False;
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult<>0 Then Exit;
 BlockRead(F, FH, SizeOf(FH), BytesRead);
 If (BytesRead<>SizeOf(FH)) Or (FH.bfType<>BMP_SIGNATURE) Then Begin Close(F); Exit; End;
 BlockRead(F, IH, SizeOf(IH), BytesRead);
 If BytesRead<>SizeOf(IH) Then Begin Close(F); Exit; End;

 If (IH.biWidth<>ImgW) Or (Abs(IH.biHeight)<>ImgH) Then Begin
  For I:=0 To MAX_LAYERS-1 Do If Layers[I].Used Then FreeLayer(I);
  ImgW := IH.biWidth;
  ImgH := Abs(IH.biHeight);
  If ImgW>1024 Then ImgW:=1024;
  If ImgH>1024 Then ImgH:=1024;
  AllocLayer(0, 'Arriere-plan', False);
  LayerCount := 1;
  ActiveLayer := 0;
 End;

 RowSize := ((LongInt(IH.biWidth) * IH.biBitCount + 31) Div 32) * 4;

 If IH.biBitCount<=8 Then Begin
  If IH.biClrUsed>0 Then PaletteEntries := IH.biClrUsed
                    Else PaletteEntries := 1 Shl IH.biBitCount;
  BlockRead(F, BMPPal, PaletteEntries*4, BytesRead);
  For X:=0 To PaletteEntries-1 Do Begin
   Best := 0; BestDist := MaxLongInt;
   For I:=0 To 15 Do Begin
    DR := LongInt(BMPPal[X].Red) - VGA_R[I];
    DG := LongInt(BMPPal[X].Green) - VGA_G[I];
    DB := LongInt(BMPPal[X].Blue) - VGA_B[I];
    Dist := DR*DR + DG*DG + DB*DB;
    If Dist<BestDist Then Begin BestDist:=Dist; Best:=I; End;
   End;
   PalRemap[X] := Byte(Best);
  End;
  For X:=PaletteEntries To 255 Do PalRemap[X]:=0;
 End;

 Seek(F, FH.bfOffBits);

 For Y:=0 To ImgH-1 Do Begin
  If IH.biHeight<0 Then SrcY := Y Else SrcY := ImgH-1-Y;
  BlockRead(F, RowBuf, RowSize, BytesRead);
  For X:=0 To ImgW-1 Do Begin
   V := 0;
   Case IH.biBitCount Of
    1: Begin
     ByteVal := RowBuf[X Div 8];
     BitPos := 7 - (X Mod 8);
     V := PalRemap[(ByteVal Shr BitPos) And 1];
    End;
    4: Begin
     ByteVal := RowBuf[X Div 2];
     If (X And 1)=0 Then V := PalRemap[(ByteVal Shr 4) And 15]
                    Else V := PalRemap[ByteVal And 15];
    End;
    8: V := PalRemap[RowBuf[X]];
    24: Begin
     B := RowBuf[X*3]; G := RowBuf[X*3+1]; R := RowBuf[X*3+2];
     Best := 0; BestDist := MaxLongInt;
     For I:=0 To 15 Do Begin
      DR := LongInt(R) - VGA_R[I];
      DG := LongInt(G) - VGA_G[I];
      DB := LongInt(B) - VGA_B[I];
      Dist := DR*DR + DG*DG + DB*DB;
      If Dist<BestDist Then Begin BestDist:=Dist; Best:=I; End;
     End;
     V := Byte(Best);
    End;
   End;
   SetLayerPixel(ActiveLayer, X, SrcY, V);
  End;
 End;

 Close(F);
 CurrentFileName := FileName;
 ImageModified := False;
 LoadBMP := True;
End;

{ ============================================================
   Decodeur GIF (LZW complet, GIF87a/GIF89a, 1ere frame)
  ============================================================ }

Function LoadGIF(Const FileName: String): Boolean;
Var
 F: File;
 BytesRead: Word;
 Hdr: Packed Record
  Sig: Array[0..5] of Char;
  ScrW, ScrH: Word;
  Flags: Byte;
  BgColor: Byte;
  Aspect: Byte;
 End;
 GP: Array[0..255, 0..2] of Byte;
 LP: Array[0..255, 0..2] of Byte;
 PalSize, LocalPalSize: Integer;
 PalRemap: Array[0..255] of Byte;
 I, X, Best: Integer;
 DR, DG, DB, Dist, BestDist: LongInt;
 BlockType, ExtLabel, SubSize: Byte;
 ImgL, ImgT, ImgWid, ImgHei: Word;
 ImgFlags, LZWMin, B: Byte;
 HasLocalPal, Interlaced: Boolean;

 SubBuf: Array[0..255] of Byte;
 SubLen, SubPos: Integer;
 EOFData: Boolean;
 BitBuf: LongInt;
 BitCnt: Integer;
 ClearCode, EOICode: Integer;
 CodeSize, NextCode, PrevCode: Integer;
 PrefixTab: Array[0..4095] of Integer;
 SuffixTab: Array[0..4095] of Byte;
 Stack: Array[0..4095] of Byte;
 SP: Integer;
 OutX, OutY, ImgRow, InterlacePass: Integer;
 Code, IncomingCode, FirstChar: Integer;
 BrTmp: Word;
 Tmp16: Word;

 Function NextDataByte(Var Bv: Byte): Boolean;
 Var Br: Word; H: Byte;
 Begin
  NextDataByte := False;
  If EOFData Then Exit;
  If SubPos >= SubLen Then Begin
   BlockRead(F, H, 1, Br);
   If Br <> 1 Then Begin EOFData := True; Exit; End;
   If H = 0 Then Begin EOFData := True; Exit; End;
   SubLen := H;
   BlockRead(F, SubBuf, SubLen, Br);
   If Br <> Word(SubLen) Then Begin EOFData := True; Exit; End;
   SubPos := 0;
  End;
  Bv := SubBuf[SubPos];
  Inc(SubPos);
  NextDataByte := True;
 End;

 Function NextCodeF: Integer;
 Var Bv: Byte;
 Begin
  While BitCnt < CodeSize Do Begin
   If Not NextDataByte(Bv) Then Begin NextCodeF := -1; Exit; End;
   BitBuf := BitBuf Or (LongInt(Bv) Shl BitCnt);
   Inc(BitCnt, 8);
  End;
  NextCodeF := Integer(BitBuf And ((LongInt(1) Shl CodeSize) - 1));
  BitBuf := BitBuf Shr CodeSize;
  Dec(BitCnt, CodeSize);
 End;

 Procedure NextInterlaceRow;
 Begin
  Case InterlacePass Of
   1: Begin Inc(ImgRow, 8);
       If ImgRow >= ImgHei Then Begin InterlacePass := 2; ImgRow := 4; End; End;
   2: Begin Inc(ImgRow, 8);
       If ImgRow >= ImgHei Then Begin InterlacePass := 3; ImgRow := 2; End; End;
   3: Begin Inc(ImgRow, 4);
       If ImgRow >= ImgHei Then Begin InterlacePass := 4; ImgRow := 1; End; End;
   4: Inc(ImgRow, 2);
  End;
 End;

 Procedure EmitPixel(PixIdx: Byte);
 Var DstX, DstY: Integer;
 Begin
  DstX := ImgL + OutX;
  If Interlaced Then DstY := ImgT + ImgRow Else DstY := ImgT + OutY;
  If (DstX >= 0) And (DstX < ImgW) And (DstY >= 0) And (DstY < ImgH) Then
   SetLayerPixel(ActiveLayer, DstX, DstY, PalRemap[PixIdx]);
  Inc(OutX);
  If OutX >= ImgWid Then Begin
   OutX := 0;
   If Interlaced Then NextInterlaceRow Else Inc(OutY);
  End;
 End;

 Procedure BuildRemapFrom(Var PP: Array of Byte; N: Integer);
 Var II, BB, K: Integer; DDR, DDG, DDB, DD, BD: LongInt;
 Begin
  For K := 0 To N-1 Do Begin
   BB := 0; BD := MaxLongInt;
   For II := 0 To 15 Do Begin
    DDR := LongInt(PP[K*3])   - VGA_R[II];
    DDG := LongInt(PP[K*3+1]) - VGA_G[II];
    DDB := LongInt(PP[K*3+2]) - VGA_B[II];
    DD := DDR*DDR + DDG*DDG + DDB*DDB;
    If DD < BD Then Begin BD := DD; BB := II; End;
   End;
   PalRemap[K] := Byte(BB);
  End;
  For K := N To 255 Do PalRemap[K] := 0;
 End;

Begin
 LoadGIF := False;
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;
 BlockRead(F, Hdr, SizeOf(Hdr), BytesRead);
 If BytesRead <> SizeOf(Hdr) Then Begin Close(F); Exit; End;
 If (Hdr.Sig[0]<>'G') Or (Hdr.Sig[1]<>'I') Or (Hdr.Sig[2]<>'F') Then
  Begin Close(F); Exit; End;

 If (Hdr.ScrW <> ImgW) Or (Hdr.ScrH <> ImgH) Then Begin
  For I:=0 To MAX_LAYERS-1 Do If Layers[I].Used Then FreeLayer(I);
  ImgW := Hdr.ScrW; ImgH := Hdr.ScrH;
  If ImgW > 1024 Then ImgW := 1024;
  If ImgH > 1024 Then ImgH := 1024;
  AllocLayer(0, 'Arriere-plan', False);
  LayerCount := 1;
  ActiveLayer := 0;
 End Else Begin
  For X := 0 To ImgW-1 Do
   For I := 0 To ImgH-1 Do
    SetLayerPixel(ActiveLayer, X, I, 0);
 End;

 PalSize := 0;
 If (Hdr.Flags And $80) <> 0 Then Begin
  PalSize := 1 Shl ((Hdr.Flags And 7) + 1);
  BlockRead(F, GP, PalSize*3, BytesRead);
  If BytesRead <> Word(PalSize*3) Then Begin Close(F); Exit; End;
  BuildRemapFrom(GP[0,0], PalSize);
 End Else
  For I := 0 To 255 Do PalRemap[I] := Byte(I And 15);

 Repeat
  BlockRead(F, BlockType, 1, BrTmp);
  If BrTmp <> 1 Then Begin Close(F); Exit; End;
  If BlockType = $3B Then Break;
  If BlockType = $21 Then Begin
   BlockRead(F, ExtLabel, 1, BrTmp);
   Repeat
    BlockRead(F, SubSize, 1, BrTmp);
    If SubSize > 0 Then Seek(F, FilePos(F) + SubSize);
   Until SubSize = 0;
  End Else If BlockType = $2C Then Begin
   BlockRead(F, Tmp16, 2, BrTmp); ImgL := Tmp16;
   BlockRead(F, Tmp16, 2, BrTmp); ImgT := Tmp16;
   BlockRead(F, Tmp16, 2, BrTmp); ImgWid := Tmp16;
   BlockRead(F, Tmp16, 2, BrTmp); ImgHei := Tmp16;
   BlockRead(F, ImgFlags, 1, BrTmp);
   HasLocalPal := (ImgFlags And $80) <> 0;
   Interlaced  := (ImgFlags And $40) <> 0;
   If HasLocalPal Then Begin
    LocalPalSize := 1 Shl ((ImgFlags And 7) + 1);
    BlockRead(F, LP, LocalPalSize*3, BrTmp);
    BuildRemapFrom(LP[0,0], LocalPalSize);
   End;
   BlockRead(F, LZWMin, 1, BrTmp);

   ClearCode := 1 Shl LZWMin;
   EOICode := ClearCode + 1;
   CodeSize := LZWMin + 1;
   NextCode := EOICode + 1;
   PrevCode := -1;
   BitBuf := 0; BitCnt := 0;
   SubLen := 0; SubPos := 0; EOFData := False;
   For I := 0 To ClearCode - 1 Do Begin
    PrefixTab[I] := -1;
    SuffixTab[I] := Byte(I);
   End;
   SP := 0;
   OutX := 0; OutY := 0; ImgRow := 0; InterlacePass := 1;
   FirstChar := 0;

   Repeat
    Code := NextCodeF;
    If Code < 0 Then Break;
    If Code = EOICode Then Break;
    If Code = ClearCode Then Begin
     CodeSize := LZWMin + 1;
     NextCode := EOICode + 1;
     PrevCode := -1;
    End Else Begin
     IncomingCode := Code;
     If Code >= NextCode Then Begin
      If PrevCode < 0 Then Break;
      Stack[SP] := Byte(FirstChar); Inc(SP);
      Code := PrevCode;
     End;
     While Code >= ClearCode Do Begin
      Stack[SP] := SuffixTab[Code]; Inc(SP);
      Code := PrefixTab[Code];
      If Code < 0 Then Break;
     End;
     If Code >= 0 Then Begin
      Stack[SP] := SuffixTab[Code]; Inc(SP);
      FirstChar := SuffixTab[Code];
     End;
     While SP > 0 Do Begin
      Dec(SP);
      EmitPixel(Stack[SP]);
     End;
     If (PrevCode >= 0) And (NextCode < 4096) Then Begin
      PrefixTab[NextCode] := PrevCode;
      SuffixTab[NextCode] := Byte(FirstChar);
      Inc(NextCode);
      If (NextCode = (1 Shl CodeSize)) And (CodeSize < 12) Then Inc(CodeSize);
     End;
     PrevCode := IncomingCode;
    End;
   Until False;

   While Not EOFData Do
    If Not NextDataByte(B) Then EOFData := True;
   Break;
  End Else Break;
 Until False;

 Close(F);
 CurrentFileName := FileName;
 ImageModified := False;
 LoadGIF := True;
End;

{ ------------------------------------------------------------
   LoadJPEG : decodeur baseline (SOF0) Huffman + IDCT
  ------------------------------------------------------------ }

Function LoadJPEG(Const FileName: String): Boolean;
Type
 THTbl = Record
  MinC, MaxC: Array[1..16] of LongInt;
  ValPtr: Array[1..16] of Integer;
  Vals: Array[0..255] of Byte;
  Defined: Boolean;
 End;
Const
 ZZ: Array[0..63] of Byte = (
   0, 1, 8,16, 9, 2, 3,10, 17,24,32,25,18,11, 4, 5,
  12,19,26,33,40,48,41,34, 27,20,13, 6, 7,14,21,28,
  35,42,49,56,57,50,43,36, 29,22,15,23,30,37,44,51,
  58,59,52,45,38,31,39,46, 53,60,61,54,47,55,62,63);
 SQRT_HALF = 0.70710678118654752;
Var
 F: File;
 InBuf: Array[0..16383] of Byte;
 InLen, InPos: Integer;
 InEOF: Boolean;
 PendingMk: Integer;     { marker byte awaiting service (0 = none) }
 JW, JH, Prec, NComp: Integer;
 CID, CH, CV, CTq, CTd, CTa: Array[0..3] of Integer;
 MaxH, MaxV, MCUW, MCUH, NMCUx, NMCUy: Integer;
 QT: Array[0..3, 0..63] of LongInt;
 HDC, HAC: Array[0..3] of THTbl;
 RestartInt: Integer;
 RstCount: Integer;
 PrevDC: Array[0..3] of LongInt;
 BBuf: LongInt; BCnt: Integer;
 EntEOF: Boolean;
 CompPix: Array[0..2, 0..15, 0..15] of Integer;
 BlkDeq: Array[0..63] of LongInt;
 BlkOut: Array[0..63] of Integer;
 CosT: Array[0..7, 0..7] of Double;
 K, K2, K3: Integer;
 OK: Boolean;
 Got: Word;

 Function R1: Integer;
 Begin
  If InPos >= InLen Then Begin
   If InEOF Then Begin R1 := -1; Exit; End;
   BlockRead(F, InBuf, 16384, Got);
   InLen := Got; InPos := 0;
   If Got = 0 Then Begin InEOF := True; R1 := -1; Exit; End;
  End;
  R1 := InBuf[InPos]; Inc(InPos);
 End;

 Function R2: Integer;
 Var A, B: Integer;
 Begin
  A := R1; B := R1;
  R2 := (A Shl 8) Or (B And $FF);
 End;

 Function NextEntByte: Integer;
 Var B, B2: Integer;
 Begin
  If EntEOF Then Begin NextEntByte := -1; Exit; End;
  B := R1;
  If B < 0 Then Begin EntEOF := True; NextEntByte := -1; Exit; End;
  If B = $FF Then Begin
   B2 := R1;
   While B2 = $FF Do B2 := R1;     { fill bytes }
   If B2 = 0 Then NextEntByte := $FF
   Else Begin
    PendingMk := B2;
    EntEOF := True;
    NextEntByte := -1;
   End;
  End Else NextEntByte := B;
 End;

 Function GetBit: Integer;
 Var B: Integer;
 Begin
  If BCnt = 0 Then Begin
   B := NextEntByte;
   If B < 0 Then Begin GetBit := 0; Exit; End;
   BBuf := B; BCnt := 8;
  End;
  Dec(BCnt);
  GetBit := Integer((BBuf Shr BCnt) And 1);
 End;

 Function GetBits(N: Integer): LongInt;
 Var V: LongInt; I: Integer;
 Begin
  V := 0;
  For I := 0 To N-1 Do V := (V Shl 1) Or GetBit;
  GetBits := V;
 End;

 Function Extend(V: LongInt; N: Integer): LongInt;
 Var Vt: LongInt;
 Begin
  If N = 0 Then Begin Extend := 0; Exit; End;
  Vt := LongInt(1) Shl (N-1);
  If V < Vt Then Extend := V + ((LongInt(-1) Shl N) + 1)
  Else Extend := V;
 End;

 Function HuffDec(Var T: THTbl): Integer;
 Var I: Integer; Code: LongInt;
 Begin
  Code := GetBit;
  I := 1;
  While Code > T.MaxC[I] Do Begin
   Code := (Code Shl 1) Or GetBit;
   Inc(I);
   If I > 16 Then Begin HuffDec := -1; Exit; End;
  End;
  HuffDec := T.Vals[T.ValPtr[I] + Integer(Code - T.MinC[I])];
 End;

 Procedure BuildHuff(Var T: THTbl; Const Bits: Array of Byte; Const HV: Array of Byte; NV: Integer);
 Var I, J, P, SI: Integer; Code: LongInt;
     HSize: Array[0..256] of Integer;
     HCode: Array[0..256] of LongInt;
 Begin
  P := 0;
  For I := 1 To 16 Do
   For J := 1 To Bits[I-1] Do Begin HSize[P] := I; Inc(P); End;
  HSize[P] := 0;
  SI := P;
  Code := 0; J := HSize[0]; P := 0;
  While HSize[P] <> 0 Do Begin
   While (HSize[P] = J) And (HSize[P] <> 0) Do Begin
    HCode[P] := Code; Inc(Code); Inc(P);
   End;
   If HSize[P] = 0 Then Break;
   While HSize[P] <> J Do Begin Code := Code Shl 1; Inc(J); End;
  End;
  P := 0;
  For I := 1 To 16 Do Begin
   If Bits[I-1] = 0 Then Begin
    T.MaxC[I] := -1;
   End Else Begin
    T.ValPtr[I] := P;
    T.MinC[I]  := HCode[P];
    Inc(P, Bits[I-1]);
    T.MaxC[I]  := HCode[P-1];
   End;
  End;
  For I := 0 To NV-1 Do T.Vals[I] := HV[I];
  T.Defined := True;
 End;

 Procedure ResetEntropy;
 Var I: Integer;
 Begin
  BBuf := 0; BCnt := 0; EntEOF := False;
  For I := 0 To 3 Do PrevDC[I] := 0;
  RstCount := RestartInt;
 End;

 Procedure IDCT;
 Var X, Y, U, V: Integer; S, Cu, Cv: Double; G: Array[0..7,0..7] of Double;
 Begin
  For Y := 0 To 7 Do
   For U := 0 To 7 Do Begin
    S := 0;
    For V := 0 To 7 Do Begin
     If V = 0 Then Cv := SQRT_HALF Else Cv := 1.0;
     S := S + Cv * BlkDeq[V*8+U] * CosT[Y, V];
    End;
    G[Y, U] := S;
   End;
  For Y := 0 To 7 Do
   For X := 0 To 7 Do Begin
    S := 0;
    For U := 0 To 7 Do Begin
     If U = 0 Then Cu := SQRT_HALF Else Cu := 1.0;
     S := S + Cu * G[Y, U] * CosT[X, U];
    End;
    BlkOut[Y*8+X] := Round(S / 4.0) + 128;
   End;
 End;

 Function DecodeBlock(Ci: Integer): Boolean;
 Var I, S, R, RS, Cat: Integer; DCDiff, V: LongInt;
 Begin
  DecodeBlock := False;
  For I := 0 To 63 Do BlkDeq[I] := 0;
  Cat := HuffDec(HDC[CTd[Ci]]);
  If Cat < 0 Then Exit;
  If Cat > 0 Then DCDiff := Extend(GetBits(Cat), Cat) Else DCDiff := 0;
  PrevDC[Ci] := PrevDC[Ci] + DCDiff;
  BlkDeq[0] := PrevDC[Ci] * QT[CTq[Ci], 0];
  I := 1;
  While I < 64 Do Begin
   RS := HuffDec(HAC[CTa[Ci]]);
   If RS < 0 Then Exit;
   S := RS And 15; R := (RS Shr 4) And 15;
   If S = 0 Then Begin
    If R = 15 Then Inc(I, 16)         { ZRL }
    Else Break;                       { EOB }
   End Else Begin
    Inc(I, R);
    If I >= 64 Then Break;
    V := Extend(GetBits(S), S);
    BlkDeq[ZZ[I]] := V * QT[CTq[Ci], ZZ[I]];
    Inc(I);
   End;
  End;
  IDCT;
  DecodeBlock := True;
 End;

 Procedure YCbCr2RGB(Y, Cb, Cr: Integer; Var R, G, B: Integer);
 Var Cr2, Cb2: Integer;
 Begin
  Cr2 := Cr - 128; Cb2 := Cb - 128;
  R := Y + ((LongInt(91881) * Cr2 + 32768) Shr 16);
  G := Y - ((LongInt(22554) * Cb2 + LongInt(46802) * Cr2 + 32768) Shr 16);
  B := Y + ((LongInt(116130) * Cb2 + 32768) Shr 16);
  If R < 0 Then R := 0 Else If R > 255 Then R := 255;
  If G < 0 Then G := 0 Else If G > 255 Then G := 255;
  If B < 0 Then B := 0 Else If B > 255 Then B := 255;
 End;

 Function NearestVGA16(R, G, B: Integer): Byte;
 Var II, Best: Integer; D, BD, DR, DG, DB: LongInt;
 Begin
  Best := 0; BD := MaxLongInt;
  For II := 0 To 15 Do Begin
   DR := LongInt(R) - VGA_R[II];
   DG := LongInt(G) - VGA_G[II];
   DB := LongInt(B) - VGA_B[II];
   D := DR*DR + DG*DG + DB*DB;
   If D < BD Then Begin BD := D; Best := II; End;
  End;
  NearestVGA16 := Byte(Best);
 End;

 Function DecodeScan: Boolean;
 Var MX, MY, Ci, BlV, BlH, PX, PY, I, J: Integer;
     Gx, Gy, SX, SY: Integer;
     Yv, Cbv, Crv, Rv, Gv, Bv: Integer;
 Begin
  DecodeScan := False;
  ResetEntropy;
  For MY := 0 To NMCUy-1 Do
   For MX := 0 To NMCUx-1 Do Begin
    For Ci := 0 To NComp-1 Do
     For BlV := 0 To CV[Ci]-1 Do
      For BlH := 0 To CH[Ci]-1 Do Begin
       If Not DecodeBlock(Ci) Then Exit;
       For PY := 0 To 7 Do
        For PX := 0 To 7 Do
         CompPix[Ci, BlV*8+PY, BlH*8+PX] := BlkOut[PY*8+PX];
      End;
    { ecrire les pixels de cette MCU dans le calque }
    For PY := 0 To MCUH-1 Do Begin
     Gy := MY*MCUH + PY;
     If Gy >= JH Then Continue;
     For PX := 0 To MCUW-1 Do Begin
      Gx := MX*MCUW + PX;
      If Gx >= JW Then Continue;
      If NComp = 1 Then Begin
       SX := PX*CH[0] Div MaxH;
       SY := PY*CV[0] Div MaxV;
       Yv := CompPix[0, SY, SX];
       If Yv < 0 Then Yv := 0 Else If Yv > 255 Then Yv := 255;
       Rv := Yv; Gv := Yv; Bv := Yv;
      End Else Begin
       SX := PX*CH[0] Div MaxH; SY := PY*CV[0] Div MaxV;
       Yv := CompPix[0, SY, SX];
       SX := PX*CH[1] Div MaxH; SY := PY*CV[1] Div MaxV;
       Cbv := CompPix[1, SY, SX];
       SX := PX*CH[2] Div MaxH; SY := PY*CV[2] Div MaxV;
       Crv := CompPix[2, SY, SX];
       YCbCr2RGB(Yv, Cbv, Crv, Rv, Gv, Bv);
      End;
      If (Gx < ImgW) And (Gy < ImgH) Then
       SetLayerPixel(ActiveLayer, Gx, Gy, NearestVGA16(Rv, Gv, Bv));
     End;
    End;
    { restart marker ? }
    If RestartInt > 0 Then Begin
     Dec(RstCount);
     If RstCount = 0 Then Begin
      { aligner sur octet, consommer le marqueur RSTn }
      BCnt := 0; BBuf := 0;
      If PendingMk = 0 Then NextEntByte;   { force lecture de l'octet de marqueur }
      I := PendingMk; PendingMk := 0;
      If (I < $D0) Or (I > $D7) Then Begin
       { pas de RST trouve ; tolere }
      End;
      EntEOF := False;
      For J := 0 To 3 Do PrevDC[J] := 0;
      RstCount := RestartInt;
     End;
    End;
   End;
  DecodeScan := True;
 End;

 Function ParseDQT(Len: Integer): Boolean;
 Var Pq, Tq, I, B: Integer;
 Begin
  ParseDQT := False;
  Dec(Len, 2);
  While Len > 0 Do Begin
   B := R1; Dec(Len);
   If B < 0 Then Exit;
   Pq := (B Shr 4) And 15; Tq := B And 15;
   If (Tq > 3) Or (Pq > 1) Then Exit;
   For I := 0 To 63 Do Begin
    If Pq = 0 Then Begin
     B := R1; Dec(Len);
    End Else Begin
     B := R2; Dec(Len, 2);
    End;
    If B < 0 Then Exit;
    QT[Tq, ZZ[I]] := B;
   End;
  End;
  ParseDQT := True;
 End;

 Function ParseDHT(Len: Integer): Boolean;
 Var TcTh, Tc, Th, I, NV, B: Integer;
     Bits: Array[0..15] of Byte;
     Vals: Array[0..255] of Byte;
 Begin
  ParseDHT := False;
  Dec(Len, 2);
  While Len > 0 Do Begin
   B := R1; Dec(Len);
   If B < 0 Then Exit;
   TcTh := B; Tc := (TcTh Shr 4) And 15; Th := TcTh And 15;
   If (Tc > 1) Or (Th > 3) Then Exit;
   NV := 0;
   For I := 0 To 15 Do Begin
    B := R1; Dec(Len);
    If B < 0 Then Exit;
    Bits[I] := B; Inc(NV, B);
   End;
   If NV > 256 Then Exit;
   For I := 0 To NV-1 Do Begin
    B := R1; Dec(Len);
    If B < 0 Then Exit;
    Vals[I] := B;
   End;
   If Tc = 0 Then BuildHuff(HDC[Th], Bits, Vals, NV)
   Else            BuildHuff(HAC[Th], Bits, Vals, NV);
  End;
  ParseDHT := True;
 End;

 Function ParseSOF0(Len: Integer): Boolean;
 Var I, B, HV: Integer;
 Begin
  ParseSOF0 := False;
  Prec := R1;
  JH := R2; JW := R2;
  NComp := R1;
  If (Prec <> 8) Or (NComp < 1) Or (NComp > 3) Then Exit;
  If (JW <= 0) Or (JH <= 0) Then Exit;
  For I := 0 To NComp-1 Do Begin
   CID[I] := R1;
   HV := R1;
   CH[I] := (HV Shr 4) And 15;
   CV[I] := HV And 15;
   CTq[I] := R1;
   If (CH[I] < 1) Or (CH[I] > 4) Or (CV[I] < 1) Or (CV[I] > 4) Then Exit;
   If CTq[I] > 3 Then Exit;
  End;
  MaxH := CH[0]; MaxV := CV[0];
  For I := 1 To NComp-1 Do Begin
   If CH[I] > MaxH Then MaxH := CH[I];
   If CV[I] > MaxV Then MaxV := CV[I];
  End;
  MCUW := MaxH * 8; MCUH := MaxV * 8;
  NMCUx := (JW + MCUW - 1) Div MCUW;
  NMCUy := (JH + MCUH - 1) Div MCUH;
  ParseSOF0 := True;
 End;

 Function ParseSOS(Len: Integer): Boolean;
 Var Ns, I, J, CS, TT: Integer;
 Begin
  ParseSOS := False;
  Ns := R1;
  If Ns <> NComp Then Exit;
  For I := 0 To Ns-1 Do Begin
   CS := R1; TT := R1;
   For J := 0 To NComp-1 Do
    If CID[J] = CS Then Begin
     CTd[J] := (TT Shr 4) And 15;
     CTa[J] := TT And 15;
    End;
  End;
  R1; R1; R1;   { Ss, Se, Ah|Al }
  ParseSOS := True;
 End;

Begin
 LoadJPEG := False;
 InLen := 0; InPos := 0; InEOF := False; PendingMk := 0;
 RestartInt := 0;
 For K := 0 To 3 Do Begin
  HDC[K].Defined := False; HAC[K].Defined := False;
  For K2 := 0 To 63 Do QT[K, K2] := 1;
 End;

 { precompute cosines }
 For K := 0 To 7 Do
  For K2 := 0 To 7 Do
   CosT[K, K2] := Cos((2.0*K + 1.0) * K2 * PI / 16.0);

 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;

 { signature SOI = FFD8 }
 K  := R1; K2 := R1;
 If (K <> $FF) Or (K2 <> $D8) Then Begin Close(F); Exit; End;

 OK := False;
 { boucle marqueurs jusqu'a SOS }
 Repeat
  K := R1;
  If K < 0 Then Begin Close(F); Exit; End;
  If K <> $FF Then Begin Close(F); Exit; End;
  While K = $FF Do K := R1;
  Case K Of
   $C0: Begin
         K2 := R2;
         If Not ParseSOF0(K2) Then Begin Close(F); Exit; End;
        End;
   $C4: Begin
         K2 := R2;
         If Not ParseDHT(K2) Then Begin Close(F); Exit; End;
        End;
   $DB: Begin
         K2 := R2;
         If Not ParseDQT(K2) Then Begin Close(F); Exit; End;
        End;
   $DD: Begin
         K2 := R2;
         RestartInt := R2;
        End;
   $DA: Begin
         K2 := R2;
         If Not ParseSOS(K2) Then Begin Close(F); Exit; End;
         OK := True;
        End;
   $D9: Begin Close(F); Exit; End;
   { SOF1..SOF15 sauf SOF4 = non-baseline non gere }
   $C1, $C2, $C3, $C5, $C6, $C7, $C9, $CA, $CB, $CD, $CE, $CF:
        Begin Close(F); Exit; End;
   Else Begin
    { tout autre marqueur avec longueur : on saute }
    K2 := R2;
    For K3 := 1 To K2-2 Do R1;
   End;
  End;
 Until OK;

 { redimensionner le calque si necessaire }
 If (JW <> ImgW) Or (JH <> ImgH) Then Begin
  For K := 0 To MAX_LAYERS-1 Do If Layers[K].Used Then FreeLayer(K);
  ImgW := JW; ImgH := JH;
  If ImgW > 1024 Then ImgW := 1024;
  If ImgH > 1024 Then ImgH := 1024;
  AllocLayer(0, 'Arriere-plan', False);
  LayerCount := 1;
  ActiveLayer := 0;
 End Else Begin
  For K := 0 To ImgW-1 Do
   For K2 := 0 To ImgH-1 Do
    SetLayerPixel(ActiveLayer, K, K2, 0);
 End;

 If Not DecodeScan Then Begin Close(F); Exit; End;

 Close(F);
 CurrentFileName := FileName;
 ImageModified := False;
 LoadJPEG := True;
End;

{ ------------------------------------------------------------
   LoadPNG : signature + chunks + DEFLATE + filtres
  ------------------------------------------------------------ }

Function LoadPNG(Const FileName: String): Boolean;
Type
 PByteArr = ^TByteArr;
 TByteArr = Array[0..0] of Byte;
 THuf = Record
  Counts: Array[0..15] of Integer;
  Symbols: Array[0..287] of Integer;
 End;
Const
 PngSig: Array[0..7] of Byte = ($89,$50,$4E,$47,$0D,$0A,$1A,$0A);
 LenBaseT: Array[0..28] of Integer =
   (3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,
    35,43,51,59,67,83,99,115,131,163,195,227,258);
 LenExtT: Array[0..28] of Integer =
   (0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DistBaseT: Array[0..29] of LongInt =
   (1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,
    1025,1537,2049,3073,4097,6145,8193,12289,16385,24577);
 DistExtT: Array[0..29] of Integer =
   (0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13);
 ClenOrd: Array[0..18] of Byte =
   (16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);
Var
 F: File;
 FBuf: Array[0..16383] of Byte;
 FLen, FPos: Integer;
 FEOF: Boolean;
 Got: Word;
 Sig: Array[0..7] of Byte;
 PngW, PngH: LongInt;
 Depth, ColorT, IntlcM: Integer;
 Channels, BPP: Integer;
 BytesPerScan: LongInt;
 PalR, PalG, PalB: Array[0..255] of Byte;
 PalCount: Integer;
 HasPal: Boolean;
 PalRemap: Array[0..255] of Byte;
 IDATTotal, IDATIdx: LongInt;
 IDATBuf: PByteArr;
 DecBuf: PByteArr;
 DecSize, DecWP: LongInt;
 BBuf: LongInt;
 BCnt: Integer;
 EndStream: Boolean;
 HLitTab, HDistTab: THuf;
 ChunkLen: LongInt;
 ChunkType: Array[0..3] of Char;
 K, K2: LongInt;
 OkSig: Boolean;
 FilePtr: LongInt;
 SeekOrigPos: LongInt;

 Function R1: Integer;
 Begin
  If FPos >= FLen Then Begin
   If FEOF Then Begin R1 := -1; Exit; End;
   BlockRead(F, FBuf, 16384, Got);
   FLen := Got; FPos := 0;
   If Got = 0 Then Begin FEOF := True; R1 := -1; Exit; End;
  End;
  R1 := FBuf[FPos]; Inc(FPos);
 End;

 Function R4: LongInt;
 Var A, B, C, D: Integer;
 Begin
  A := R1; B := R1; C := R1; D := R1;
  R4 := (LongInt(A And $FF) Shl 24)
     Or (LongInt(B And $FF) Shl 16)
     Or (LongInt(C And $FF) Shl 8)
     Or  LongInt(D And $FF);
 End;

 Function ReadChunkHdr: Boolean;
 Var I: Integer;
 Begin
  ChunkLen := R4;
  For I := 0 To 3 Do ChunkType[I] := Chr(R1 And $FF);
  ReadChunkHdr := Not FEOF;
 End;

 Function CT(A, B, C, D: Char): Boolean;
 Begin
  CT := (ChunkType[0]=A) And (ChunkType[1]=B)
    And (ChunkType[2]=C) And (ChunkType[3]=D);
 End;

 Procedure SkipChunkData;
 Var I: LongInt;
 Begin
  For I := 1 To ChunkLen Do R1;
  R4;   { CRC }
 End;

 Function NextRawByte: Integer;
 Begin
  If IDATIdx >= IDATTotal Then Begin NextRawByte := -1; Exit; End;
  NextRawByte := IDATBuf^[IDATIdx]; Inc(IDATIdx);
 End;

 Function GetBit: Integer;
 Var B: Integer;
 Begin
  If BCnt = 0 Then Begin
   B := NextRawByte;
   If B < 0 Then Begin EndStream := True; GetBit := 0; Exit; End;
   BBuf := B; BCnt := 8;
  End;
  GetBit := Integer(BBuf And 1);
  BBuf := BBuf Shr 1;
  Dec(BCnt);
 End;

 Function GetBits(N: Integer): LongInt;
 Var V: LongInt; I: Integer;
 Begin
  V := 0;
  For I := 0 To N-1 Do V := V Or (LongInt(GetBit) Shl I);
  GetBits := V;
 End;

 Procedure BuildHuf(Var H: THuf; Const Lens: Array of Integer; N: Integer);
 Var I, J: Integer; Offs: Array[0..16] of Integer;
 Begin
  For I := 0 To 15 Do H.Counts[I] := 0;
  For I := 0 To N-1 Do
   If (Lens[I] >= 0) And (Lens[I] <= 15) Then Inc(H.Counts[Lens[I]]);
  H.Counts[0] := 0;
  Offs[1] := 0;
  For I := 1 To 15 Do Offs[I+1] := Offs[I] + H.Counts[I];
  For I := 0 To N-1 Do
   If (Lens[I] > 0) And (Lens[I] <= 15) Then Begin
    H.Symbols[Offs[Lens[I]]] := I;
    Inc(Offs[Lens[I]]);
   End;
 End;

 Function DecSym(Var H: THuf): Integer;
 Var Code, First, Idx, Count, Len: Integer;
 Begin
  Code := 0; First := 0; Idx := 0;
  For Len := 1 To 15 Do Begin
   Code := (Code Shl 1) Or GetBit;
   Count := H.Counts[Len];
   If Code - Count < First Then Begin
    DecSym := H.Symbols[Idx + (Code - First)];
    Exit;
   End;
   Inc(Idx, Count);
   First := (First + Count) Shl 1;
  End;
  DecSym := -1;
 End;

 Procedure EmitDec(B: Byte);
 Begin
  If DecWP < DecSize Then DecBuf^[DecWP] := B;
  Inc(DecWP);
 End;

 Procedure BuildFixed;
 Var L: Array[0..287] of Integer; LD: Array[0..29] of Integer; I: Integer;
 Begin
  For I := 0   To 143 Do L[I] := 8;
  For I := 144 To 255 Do L[I] := 9;
  For I := 256 To 279 Do L[I] := 7;
  For I := 280 To 287 Do L[I] := 8;
  BuildHuf(HLitTab, L, 288);
  For I := 0 To 29 Do LD[I] := 5;
  BuildHuf(HDistTab, LD, 30);
 End;

 Function ReadDynamic: Boolean;
 Var HLit, HDistN, HCLen: Integer;
     CLens: Array[0..18] of Integer;
     HClenTab: THuf;
     LitDistLens: Array[0..319] of Integer;
     I, N, Sym, Rep, Prev: Integer;
 Begin
  ReadDynamic := False;
  HLit  := Integer(GetBits(5)) + 257;
  HDistN:= Integer(GetBits(5)) + 1;
  HCLen := Integer(GetBits(4)) + 4;
  For I := 0 To 18 Do CLens[I] := 0;
  For I := 0 To HCLen-1 Do CLens[ClenOrd[I]] := Integer(GetBits(3));
  BuildHuf(HClenTab, CLens, 19);
  N := 0;
  While N < HLit + HDistN Do Begin
   Sym := DecSym(HClenTab);
   If Sym < 0 Then Exit;
   If Sym < 16 Then Begin
    LitDistLens[N] := Sym; Inc(N);
   End Else If Sym = 16 Then Begin
    If N = 0 Then Exit;
    Prev := LitDistLens[N-1];
    Rep := Integer(GetBits(2)) + 3;
    While (Rep > 0) And (N < HLit + HDistN) Do Begin
     LitDistLens[N] := Prev; Inc(N); Dec(Rep);
    End;
   End Else If Sym = 17 Then Begin
    Rep := Integer(GetBits(3)) + 3;
    While (Rep > 0) And (N < HLit + HDistN) Do Begin
     LitDistLens[N] := 0; Inc(N); Dec(Rep);
    End;
   End Else If Sym = 18 Then Begin
    Rep := Integer(GetBits(7)) + 11;
    While (Rep > 0) And (N < HLit + HDistN) Do Begin
     LitDistLens[N] := 0; Inc(N); Dec(Rep);
    End;
   End Else Exit;
  End;
  BuildHuf(HLitTab, LitDistLens, HLit);
  { decales pour la table distance }
  For I := 0 To HDistN-1 Do LitDistLens[I] := LitDistLens[HLit + I];
  BuildHuf(HDistTab, LitDistLens, HDistN);
  ReadDynamic := True;
 End;

 Function DecodeData: Boolean;
 Var Sym, LIdx, DSym: Integer; L: LongInt; D: LongInt; I: LongInt;
 Begin
  DecodeData := False;
  Repeat
   Sym := DecSym(HLitTab);
   If Sym < 0 Then Exit;
   If Sym < 256 Then EmitDec(Byte(Sym))
   Else If Sym = 256 Then Begin DecodeData := True; Exit; End
   Else Begin
    LIdx := Sym - 257;
    If LIdx > 28 Then Exit;
    L := LenBaseT[LIdx] + GetBits(LenExtT[LIdx]);
    DSym := DecSym(HDistTab);
    If (DSym < 0) Or (DSym > 29) Then Exit;
    D := DistBaseT[DSym] + GetBits(DistExtT[DSym]);
    If D > DecWP Then Exit;
    For I := 1 To L Do
     If DecWP < DecSize Then Begin
      DecBuf^[DecWP] := DecBuf^[DecWP - D];
      Inc(DecWP);
     End Else Inc(DecWP);
   End;
  Until False;
 End;

 Function Inflate: Boolean;
 Var BFINAL, BTYPE: Integer; LEN, NLEN, I, B: LongInt;
 Begin
  Inflate := False;
  BBuf := 0; BCnt := 0; EndStream := False;
  { zlib header CMF, FLG }
  NextRawByte; NextRawByte;
  Repeat
   BFINAL := GetBit;
   BTYPE  := Integer(GetBits(2));
   Case BTYPE Of
    0: Begin
        BCnt := 0; BBuf := 0;
        LEN  := NextRawByte; LEN  := LEN  Or (LongInt(NextRawByte) Shl 8);
        NLEN := NextRawByte; NLEN := NLEN Or (LongInt(NextRawByte) Shl 8);
        For I := 1 To LEN Do Begin
         B := NextRawByte;
         If B < 0 Then Exit;
         EmitDec(Byte(B));
        End;
       End;
    1: Begin
        BuildFixed;
        If Not DecodeData Then Exit;
       End;
    2: Begin
        If Not ReadDynamic Then Exit;
        If Not DecodeData Then Exit;
       End;
    Else Exit;
   End;
  Until BFINAL = 1;
  Inflate := True;
 End;

 Function PaethPred(A, B, C: Integer): Integer;
 Var P, PA, PB, PC: Integer;
 Begin
  P := A + B - C;
  PA := P - A; If PA < 0 Then PA := -PA;
  PB := P - B; If PB < 0 Then PB := -PB;
  PC := P - C; If PC < 0 Then PC := -PC;
  If (PA <= PB) And (PA <= PC) Then PaethPred := A
  Else If PB <= PC Then PaethPred := B
  Else PaethPred := C;
 End;

 Procedure UnfilterAll;
 Var Y, X: LongInt; FT: Integer; RowOff, PrevOff: LongInt;
     A, B, C, Recon: Integer;
 Begin
  For Y := 0 To PngH-1 Do Begin
   RowOff := Y * (BytesPerScan + 1);
   If RowOff >= DecSize Then Break;
   FT := DecBuf^[RowOff];
   If Y = 0 Then PrevOff := -1 Else PrevOff := (Y-1) * (BytesPerScan + 1) + 1;
   For X := 0 To BytesPerScan-1 Do Begin
    If X >= BPP Then A := DecBuf^[RowOff + 1 + X - BPP] Else A := 0;
    If PrevOff >= 0 Then B := DecBuf^[PrevOff + X] Else B := 0;
    If (PrevOff >= 0) And (X >= BPP) Then C := DecBuf^[PrevOff + X - BPP] Else C := 0;
    Case FT Of
     0: Recon := DecBuf^[RowOff + 1 + X];
     1: Recon := (DecBuf^[RowOff + 1 + X] + A) And $FF;
     2: Recon := (DecBuf^[RowOff + 1 + X] + B) And $FF;
     3: Recon := (DecBuf^[RowOff + 1 + X] + ((A + B) Div 2)) And $FF;
     4: Recon := (DecBuf^[RowOff + 1 + X] + PaethPred(A, B, C)) And $FF;
     Else Recon := DecBuf^[RowOff + 1 + X];
    End;
    DecBuf^[RowOff + 1 + X] := Byte(Recon);
   End;
  End;
 End;

 Function GetSample(RowOff: LongInt; X: LongInt): Integer;
 Var ByteOff, BitOff, V: LongInt;
 Begin
  GetSample := 0;
  Case Depth Of
   1: Begin
       ByteOff := X Shr 3; BitOff := 7 - (X And 7);
       V := DecBuf^[RowOff + 1 + ByteOff];
       GetSample := Integer((V Shr BitOff) And 1);
      End;
   2: Begin
       ByteOff := X Shr 2; BitOff := 6 - 2*(X And 3);
       V := DecBuf^[RowOff + 1 + ByteOff];
       GetSample := Integer((V Shr BitOff) And 3);
      End;
   4: Begin
       ByteOff := X Shr 1; BitOff := 4 - 4*(X And 1);
       V := DecBuf^[RowOff + 1 + ByteOff];
       GetSample := Integer((V Shr BitOff) And 15);
      End;
   8: GetSample := DecBuf^[RowOff + 1 + X];
   16: GetSample := DecBuf^[RowOff + 1 + X*2];     { MSB }
  End;
 End;

 Function NearestVGA(R, G, B: Integer): Byte;
 Var II, Best: Integer; D, BD, DR, DG, DB: LongInt;
 Begin
  Best := 0; BD := MaxLongInt;
  For II := 0 To 15 Do Begin
   DR := LongInt(R) - VGA_R[II];
   DG := LongInt(G) - VGA_G[II];
   DB := LongInt(B) - VGA_B[II];
   D := DR*DR + DG*DG + DB*DB;
   If D < BD Then Begin BD := D; Best := II; End;
  End;
  NearestVGA := Byte(Best);
 End;

 Procedure EmitPixels;
 Var Y, X: LongInt; RowOff: LongInt;
     R, G, B, Idx, Sv: Integer;
     S0, S1, S2, S3: Integer; ByteOff: LongInt;
     PixIdx: Byte;
 Begin
  For Y := 0 To PngH-1 Do Begin
   If Y >= ImgH Then Break;
   RowOff := Y * (BytesPerScan + 1);
   If RowOff >= DecSize Then Break;
   For X := 0 To PngW-1 Do Begin
    If X >= ImgW Then Break;
    Case ColorT Of
     0: Begin
         Sv := GetSample(RowOff, X);
         Case Depth Of
          1: Sv := Sv * 255;
          2: Sv := Sv * 85;
          4: Sv := Sv * 17;
         End;
         R := Sv; G := Sv; B := Sv;
         PixIdx := NearestVGA(R, G, B);
        End;
     2: Begin
         If Depth = 8 Then Begin
          ByteOff := RowOff + 1 + X*3;
          R := DecBuf^[ByteOff];
          G := DecBuf^[ByteOff+1];
          B := DecBuf^[ByteOff+2];
         End Else Begin   { 16-bit }
          ByteOff := RowOff + 1 + X*6;
          R := DecBuf^[ByteOff];
          G := DecBuf^[ByteOff+2];
          B := DecBuf^[ByteOff+4];
         End;
         PixIdx := NearestVGA(R, G, B);
        End;
     3: Begin
         Idx := GetSample(RowOff, X);
         If Idx >= PalCount Then Idx := 0;
         PixIdx := PalRemap[Idx];
        End;
     4: Begin
         If Depth = 8 Then Begin
          ByteOff := RowOff + 1 + X*2;
          Sv := DecBuf^[ByteOff];
         End Else Begin
          ByteOff := RowOff + 1 + X*4;
          Sv := DecBuf^[ByteOff];
         End;
         R := Sv; G := Sv; B := Sv;
         PixIdx := NearestVGA(R, G, B);
        End;
     6: Begin
         If Depth = 8 Then Begin
          ByteOff := RowOff + 1 + X*4;
          R := DecBuf^[ByteOff];
          G := DecBuf^[ByteOff+1];
          B := DecBuf^[ByteOff+2];
         End Else Begin
          ByteOff := RowOff + 1 + X*8;
          R := DecBuf^[ByteOff];
          G := DecBuf^[ByteOff+2];
          B := DecBuf^[ByteOff+4];
         End;
         PixIdx := NearestVGA(R, G, B);
        End;
     Else PixIdx := 0;
    End;
    SetLayerPixel(ActiveLayer, X, Y, PixIdx);
   End;
  End;
 End;

 Procedure BuildPalRemap;
 Var K3: Integer; DR, DG, DB, D, BD: LongInt; Best, II: Integer;
 Begin
  For K3 := 0 To PalCount-1 Do Begin
   Best := 0; BD := MaxLongInt;
   For II := 0 To 15 Do Begin
    DR := LongInt(PalR[K3]) - VGA_R[II];
    DG := LongInt(PalG[K3]) - VGA_G[II];
    DB := LongInt(PalB[K3]) - VGA_B[II];
    D := DR*DR + DG*DG + DB*DB;
    If D < BD Then Begin BD := D; Best := II; End;
   End;
   PalRemap[K3] := Byte(Best);
  End;
  For K3 := PalCount To 255 Do PalRemap[K3] := 0;
 End;

Begin
 LoadPNG := False;
 IDATBuf := Nil; DecBuf := Nil;
 FLen := 0; FPos := 0; FEOF := False;
 IDATTotal := 0; PalCount := 0; HasPal := False;

 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;

 { lire signature }
 For K := 0 To 7 Do Sig[K] := R1 And $FF;
 OkSig := True;
 For K := 0 To 7 Do If Sig[K] <> PngSig[K] Then OkSig := False;
 If Not OkSig Then Begin Close(F); Exit; End;

 { Pass 1 : parser IHDR/PLTE, accumuler taille IDAT }
 SeekOrigPos := FilePos(F) - (FLen - FPos);
 Repeat
  If Not ReadChunkHdr Then Begin Close(F); Exit; End;
  If CT('I','H','D','R') Then Begin
   If ChunkLen < 13 Then Begin Close(F); Exit; End;
   PngW := R4; PngH := R4;
   Depth := R1; ColorT := R1;
   R1; { compression method, doit etre 0 }
   R1; { filter method, doit etre 0 }
   IntlcM := R1;
   For K := 14 To ChunkLen Do R1;
   R4; { CRC }
   If (PngW <= 0) Or (PngH <= 0) Then Begin Close(F); Exit; End;
   If IntlcM <> 0 Then Begin Close(F); Exit; End;     { Adam7 non gere }
  End Else If CT('P','L','T','E') Then Begin
   PalCount := Integer(ChunkLen Div 3);
   If PalCount > 256 Then PalCount := 256;
   For K := 0 To PalCount-1 Do Begin
    PalR[K] := R1; PalG[K] := R1; PalB[K] := R1;
   End;
   For K := LongInt(PalCount)*3 To ChunkLen-1 Do R1;
   R4;
   HasPal := True;
  End Else If CT('I','D','A','T') Then Begin
   Inc(IDATTotal, ChunkLen);
   SkipChunkData;
  End Else If CT('I','E','N','D') Then Begin
   SkipChunkData;
   Break;
  End Else SkipChunkData;
 Until False;

 { valider color type / depth }
 Case ColorT Of
  0: Channels := 1;
  2: Channels := 3;
  3: Channels := 1;
  4: Channels := 2;
  6: Channels := 4;
  Else Begin Close(F); Exit; End;
 End;
 Case Depth Of
  1, 2, 4: If (ColorT <> 0) And (ColorT <> 3) Then Begin Close(F); Exit; End;
  8, 16  : ;
  Else Begin Close(F); Exit; End;
 End;
 If (ColorT = 3) And (Depth = 16) Then Begin Close(F); Exit; End;

 BPP := (Channels * Depth + 7) Div 8;
 BytesPerScan := (PngW * Channels * Depth + 7) Div 8;
 DecSize := PngH * (BytesPerScan + 1);
 If IDATTotal <= 0 Then Begin Close(F); Exit; End;
 If DecSize > 16777216 Then Begin Close(F); Exit; End;     { > 16 MB : refus }
 If IDATTotal > 16777216 Then Begin Close(F); Exit; End;

 GetMem(IDATBuf, IDATTotal);
 GetMem(DecBuf, DecSize);
 If (IDATBuf = Nil) Or (DecBuf = Nil) Then Begin
  If IDATBuf <> Nil Then FreeMem(IDATBuf, IDATTotal);
  If DecBuf  <> Nil Then FreeMem(DecBuf, DecSize);
  Close(F); Exit;
 End;

 { Pass 2 : relire le fichier pour copier les IDAT }
 Close(F);
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Begin FreeMem(IDATBuf, IDATTotal); FreeMem(DecBuf, DecSize); Exit; End;
 FLen := 0; FPos := 0; FEOF := False;
 For K := 0 To 7 Do R1;     { signature }

 IDATIdx := 0;
 Repeat
  If Not ReadChunkHdr Then Break;
  If CT('I','D','A','T') Then Begin
   For K := 1 To ChunkLen Do Begin
    K2 := R1;
    If (IDATIdx < IDATTotal) And (K2 >= 0) Then Begin
     IDATBuf^[IDATIdx] := Byte(K2); Inc(IDATIdx);
    End;
   End;
   R4;     { CRC }
  End Else If CT('I','E','N','D') Then Begin
   SkipChunkData; Break;
  End Else SkipChunkData;
 Until False;
 Close(F);

 { redimensionner le calque }
 If (PngW <> ImgW) Or (PngH <> ImgH) Then Begin
  For K := 0 To MAX_LAYERS-1 Do If Layers[K].Used Then FreeLayer(K);
  ImgW := PngW; ImgH := PngH;
  If ImgW > 1024 Then ImgW := 1024;
  If ImgH > 1024 Then ImgH := 1024;
  AllocLayer(0, 'Arriere-plan', False);
  LayerCount := 1;
  ActiveLayer := 0;
 End Else Begin
  For K := 0 To ImgW-1 Do
   For K2 := 0 To ImgH-1 Do
    SetLayerPixel(ActiveLayer, K, K2, 0);
 End;

 IDATIdx := 0;
 DecWP := 0;
 If Not Inflate Then Begin
  FreeMem(IDATBuf, IDATTotal); FreeMem(DecBuf, DecSize);
  Exit;
 End;

 UnfilterAll;

 If ColorT = 3 Then Begin
  If Not HasPal Then PalCount := 0;
  BuildPalRemap;
 End;

 EmitPixels;

 FreeMem(IDATBuf, IDATTotal);
 FreeMem(DecBuf, DecSize);

 CurrentFileName := FileName;
 ImageModified := False;
 LoadPNG := True;
End;

{ ------------------------------------------------------------
   LoadPCX : PCX ZSoft, RLE par plan
  ------------------------------------------------------------ }

Function LoadPCX(Const FileName: String): Boolean;
Type
 TPCXHdr = Packed Record
  Manuf, Ver, Enc, BPP: Byte;
  Xmin, Ymin, Xmax, Ymax: Word;
  HDpi, VDpi: Word;
  EgaPal: Array[0..47] of Byte;
  Reserved: Byte;
  NPlanes: Byte;
  BytesPerLine: Word;
  PalInfo: Word;
  HScrSize, VScrSize: Word;
  Filler: Array[0..53] of Byte;
 End;
Var
 F: File;
 H: TPCXHdr;
 Got: Word;
 FBuf: Array[0..16383] of Byte;
 FLen, FPos: Integer;
 FEOFf: Boolean;
 PcxW, PcxH: LongInt;
 ScanBytes: LongInt;
 Scan: Array[0..16383] of Byte;
 PalR, PalG, PalB: Array[0..255] of Byte;
 PalRemap: Array[0..255] of Byte;
 PalCount: Integer;
 HasPal8: Boolean;
 K, K2: LongInt;
 FSize: LongInt;
 TailByte: Byte;
 TailBuf: Array[0..768] of Byte;
 X, Y, I, II, Best: LongInt;
 R, G, B: Integer;
 BitIdx, ByteOff: LongInt;
 Plane, Bit: Integer;
 Idx: Integer;
 DR, DG, DB, Dist, BD: LongInt;
 BR: Word;

 Function R1: Integer;
 Begin
  If FPos >= FLen Then Begin
   If FEOFf Then Begin R1 := -1; Exit; End;
   BlockRead(F, FBuf, 16384, Got);
   FLen := Got; FPos := 0;
   If Got = 0 Then Begin FEOFf := True; R1 := -1; Exit; End;
  End;
  R1 := FBuf[FPos]; Inc(FPos);
 End;

 Function ReadScanline: Boolean;
 Var Cnt, Val, J: Integer; P: LongInt;
 Begin
  ReadScanline := False;
  P := 0;
  While P < ScanBytes Do Begin
   Val := R1;
   If Val < 0 Then Exit;
   If (Val And $C0) = $C0 Then Begin
    Cnt := Val And $3F;
    Val := R1;
    If Val < 0 Then Exit;
    For J := 1 To Cnt Do Begin
     If P < ScanBytes Then Scan[P] := Byte(Val);
     Inc(P);
    End;
   End Else Begin
    Scan[P] := Byte(Val); Inc(P);
   End;
  End;
  ReadScanline := True;
 End;

 Function NearestVGA(Rv, Gv, Bv: Integer): Byte;
 Var Jj, Bb: Integer; D, BBd, Dd1, Dd2, Dd3: LongInt;
 Begin
  Bb := 0; BBd := MaxLongInt;
  For Jj := 0 To 15 Do Begin
   Dd1 := LongInt(Rv) - VGA_R[Jj];
   Dd2 := LongInt(Gv) - VGA_G[Jj];
   Dd3 := LongInt(Bv) - VGA_B[Jj];
   D := Dd1*Dd1 + Dd2*Dd2 + Dd3*Dd3;
   If D < BBd Then Begin BBd := D; Bb := Jj; End;
  End;
  NearestVGA := Byte(Bb);
 End;

Begin
 LoadPCX := False;
 FLen := 0; FPos := 0; FEOFf := False;
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;

 BlockRead(F, H, SizeOf(H), Got);
 If Got <> SizeOf(H) Then Begin Close(F); Exit; End;
 If H.Manuf <> $0A Then Begin Close(F); Exit; End;
 If H.Enc <> 1 Then Begin Close(F); Exit; End;
 If (H.BPP <> 1) And (H.BPP <> 2) And (H.BPP <> 4) And (H.BPP <> 8) Then Begin Close(F); Exit; End;
 If (H.NPlanes < 1) Or (H.NPlanes > 4) Then Begin Close(F); Exit; End;

 PcxW := LongInt(H.Xmax) - H.Xmin + 1;
 PcxH := LongInt(H.Ymax) - H.Ymin + 1;
 If (PcxW <= 0) Or (PcxH <= 0) Then Begin Close(F); Exit; End;
 If (PcxW > 1024) Or (PcxH > 1024) Then Begin Close(F); Exit; End;

 ScanBytes := LongInt(H.BytesPerLine) * H.NPlanes;
 If ScanBytes <= 0 Then Begin Close(F); Exit; End;
 If ScanBytes > 16384 Then Begin Close(F); Exit; End;

 { palette : pour 8bpp 1 plan, regarder la queue du fichier }
 HasPal8 := False; PalCount := 0;
 If (H.BPP = 8) And (H.NPlanes = 1) Then Begin
  FSize := FileSize(F);
  If FSize >= 769 Then Begin
   Seek(F, FSize - 769);
   FLen := 0; FPos := 0; FEOFf := False;
   BlockRead(F, TailBuf, 769, BR);
   If (BR = 769) And (TailBuf[0] = $0C) Then Begin
    HasPal8 := True; PalCount := 256;
    For K := 0 To 255 Do Begin
     PalR[K] := TailBuf[1 + K*3];
     PalG[K] := TailBuf[1 + K*3 + 1];
     PalB[K] := TailBuf[1 + K*3 + 2];
    End;
   End;
  End;
  { revenir apres l'en-tete }
  Seek(F, 128);
  FLen := 0; FPos := 0; FEOFf := False;
 End;

 { palette EGA 16 couleurs depuis en-tete (pour 1bpp x 1..4 planes, ou 4bpp 1 plane) }
 If (Not HasPal8) Then Begin
  PalCount := 16;
  For K := 0 To 15 Do Begin
   PalR[K] := H.EgaPal[K*3];
   PalG[K] := H.EgaPal[K*3 + 1];
   PalB[K] := H.EgaPal[K*3 + 2];
  End;
  { cas monochrome (1 plan, 1 bpp) : noir/blanc force }
  If (H.NPlanes = 1) And (H.BPP = 1) Then Begin
   PalR[0]:=0; PalG[0]:=0; PalB[0]:=0;
   PalR[1]:=255; PalG[1]:=255; PalB[1]:=255;
  End;
 End;

 { construire PalRemap (sauf pour mode 24-bit) }
 If Not ((H.NPlanes = 3) And (H.BPP = 8)) Then Begin
  For I := 0 To PalCount-1 Do Begin
   Best := 0; BD := MaxLongInt;
   For II := 0 To 15 Do Begin
    DR := LongInt(PalR[I]) - VGA_R[II];
    DG := LongInt(PalG[I]) - VGA_G[II];
    DB := LongInt(PalB[I]) - VGA_B[II];
    Dist := DR*DR + DG*DG + DB*DB;
    If Dist < BD Then Begin BD := Dist; Best := II; End;
   End;
   PalRemap[I] := Byte(Best);
  End;
  For I := PalCount To 255 Do PalRemap[I] := 0;
 End;

 { redimensionner le calque }
 If (PcxW <> ImgW) Or (PcxH <> ImgH) Then Begin
  For K := 0 To MAX_LAYERS-1 Do If Layers[K].Used Then FreeLayer(K);
  ImgW := PcxW; ImgH := PcxH;
  AllocLayer(0, 'Arriere-plan', False);
  LayerCount := 1;
  ActiveLayer := 0;
 End Else Begin
  For K := 0 To ImgW-1 Do
   For K2 := 0 To ImgH-1 Do
    SetLayerPixel(ActiveLayer, K, K2, 0);
 End;

 { decodage RLE ligne par ligne }
 For Y := 0 To PcxH-1 Do Begin
  If Not ReadScanline Then Begin Close(F); Exit; End;
  If Y >= ImgH Then Continue;
  For X := 0 To PcxW-1 Do Begin
   If X >= ImgW Then Break;
   If (H.NPlanes = 1) And (H.BPP = 8) Then Begin
    Idx := Scan[X];
    SetLayerPixel(ActiveLayer, X, Y, PalRemap[Idx]);
   End
   Else If (H.NPlanes = 3) And (H.BPP = 8) Then Begin
    R := Scan[X];
    G := Scan[H.BytesPerLine + X];
    B := Scan[2*H.BytesPerLine + X];
    SetLayerPixel(ActiveLayer, X, Y, NearestVGA(R, G, B));
   End
   Else If (H.NPlanes = 1) And (H.BPP = 1) Then Begin
    ByteOff := X Shr 3; BitIdx := 7 - (X And 7);
    Idx := (Scan[ByteOff] Shr BitIdx) And 1;
    SetLayerPixel(ActiveLayer, X, Y, PalRemap[Idx]);
   End
   Else If (H.NPlanes = 1) And (H.BPP = 4) Then Begin
    ByteOff := X Shr 1;
    If (X And 1) = 0 Then Idx := (Scan[ByteOff] Shr 4) And 15
    Else                  Idx := Scan[ByteOff] And 15;
    SetLayerPixel(ActiveLayer, X, Y, PalRemap[Idx]);
   End
   Else If (H.NPlanes = 1) And (H.BPP = 2) Then Begin
    ByteOff := X Shr 2;
    Bit := 6 - 2*(X And 3);
    Idx := (Scan[ByteOff] Shr Bit) And 3;
    SetLayerPixel(ActiveLayer, X, Y, PalRemap[Idx]);
   End
   Else If (H.BPP = 1) And (H.NPlanes >= 2) And (H.NPlanes <= 4) Then Begin
    { plans bit : combiner les bits a la meme position }
    ByteOff := X Shr 3; BitIdx := 7 - (X And 7);
    Idx := 0;
    For Plane := 0 To H.NPlanes-1 Do
     If ((Scan[Plane*H.BytesPerLine + ByteOff] Shr BitIdx) And 1) <> 0 Then
      Idx := Idx Or (1 Shl Plane);
    SetLayerPixel(ActiveLayer, X, Y, PalRemap[Idx]);
   End;
  End;
 End;

 Close(F);
 CurrentFileName := FileName;
 ImageModified := False;
 LoadPCX := True;
End;

{ ------------------------------------------------------------
   LoadPSD : Adobe Photoshop natif
   - Signature "8BPS", version 1
   - Profondeur 8 bits
   - Modes : 1=Grayscale, 2=Indexed (palette 768o), 3=RGB
   - Compression : 0=brut, 1=PackBits RLE
   - Image composite seulement (layers ignores)
  ------------------------------------------------------------ }

{$PUSH}{$R-}
Function LoadPSD(Const FileName: String): Boolean;
Type
 PByteArr = ^TByteArr;
 TByteArr = Array[0..1048575] of Byte;
Var
 F: File;
 BytesRead: Word;
 Sig: Array[0..3] of Byte;
 Buf2: Array[0..1] of Byte;
 Buf4: Array[0..3] of Byte;
 Skip6: Array[0..5] of Byte;
 Version, NumChanFile, Depth, ColorMode, Compression: Word;
 PW, PH: LongInt;
 SectLen: LongInt;
 PSDPal: Array[0..767] of Byte;
 HasPal: Boolean;
 ChanBuf: Array[0..2] of PByteArr;
 ChanNeed: Integer;
 X, Y, I, C, Best: Integer;
 R, G, B, Vidx, PalIdx: Byte;
 DR, DG, DB, Dist, BestDist: LongInt;
 PalRemap: Array[0..255] of Byte;
 RowCountsPtr: PByteArr;
 RowCountBytes: LongInt;
 RowIdx, ChannelIdx: Integer;
 EncLen: Word;
 PixOff: LongInt;
 LineBuf: PByteArr;
 ChanBytes: LongInt;

 Function ReadBE16: Word;
 Begin
  BlockRead(F, Buf2, 2, BytesRead);
  ReadBE16 := (Word(Buf2[0]) Shl 8) Or Word(Buf2[1]);
 End;

 Function ReadBE32: LongInt;
 Begin
  BlockRead(F, Buf4, 4, BytesRead);
  ReadBE32 := (LongInt(Buf4[0]) Shl 24) Or (LongInt(Buf4[1]) Shl 16) Or
              (LongInt(Buf4[2]) Shl 8) Or LongInt(Buf4[3]);
 End;

 Procedure DecodeRLERow(ByteCount: Word; Dest: PByteArr; OutW: LongInt);
 Var RP: LongInt; OutPos: LongInt; N, J: Integer; RH, Bv: Byte;
 Begin
  RP := 0; OutPos := 0;
  While (RP < ByteCount) And (OutPos < OutW) Do Begin
   BlockRead(F, RH, 1, BytesRead); Inc(RP);
   If RH < 128 Then Begin
    N := Integer(RH) + 1;
    For J := 0 To N-1 Do Begin
     BlockRead(F, Bv, 1, BytesRead); Inc(RP);
     If OutPos < OutW Then Begin Dest^[OutPos] := Bv; Inc(OutPos); End;
    End;
   End Else If RH > 128 Then Begin
    N := 257 - Integer(RH);
    BlockRead(F, Bv, 1, BytesRead); Inc(RP);
    For J := 0 To N-1 Do Begin
     If OutPos < OutW Then Begin Dest^[OutPos] := Bv; Inc(OutPos); End;
    End;
   End;
   { RH = 128 : no-op selon spec PackBits }
  End;
 End;

Begin
 LoadPSD := False;
 ChanBuf[0] := Nil; ChanBuf[1] := Nil; ChanBuf[2] := Nil;
 RowCountsPtr := Nil; LineBuf := Nil; ChanBytes := 0;
 RowCountBytes := 0;
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;

 BlockRead(F, Sig, 4, BytesRead);
 If (BytesRead<>4) Or (Sig[0]<>$38) Or (Sig[1]<>$42) Or
    (Sig[2]<>$50) Or (Sig[3]<>$53) Then Begin Close(F); Exit; End;

 Version := ReadBE16;
 If Version <> 1 Then Begin Close(F); Exit; End;

 BlockRead(F, Skip6, 6, BytesRead);
 NumChanFile := ReadBE16;
 PH := ReadBE32;
 PW := ReadBE32;
 Depth := ReadBE16;
 ColorMode := ReadBE16;

 If Depth <> 8 Then Begin Close(F); Exit; End;
 If (ColorMode <> 1) And (ColorMode <> 2) And (ColorMode <> 3) Then Begin Close(F); Exit; End;
 If (PW < 1) Or (PH < 1) Or (NumChanFile < 1) Or (NumChanFile > 56) Then Begin Close(F); Exit; End;

 { Color Mode Data }
 SectLen := ReadBE32;
 HasPal := False;
 If (ColorMode = 2) And (SectLen = 768) Then Begin
  BlockRead(F, PSDPal, 768, BytesRead);
  HasPal := True;
 End Else If SectLen > 0 Then
  Seek(F, FilePos(F) + SectLen);

 { Image Resources }
 SectLen := ReadBE32;
 If SectLen > 0 Then Seek(F, FilePos(F) + SectLen);

 { Layer and Mask Information }
 SectLen := ReadBE32;
 If SectLen > 0 Then Seek(F, FilePos(F) + SectLen);

 { Image Data : composite global }
 Compression := ReadBE16;
 If (Compression <> 0) And (Compression <> 1) Then Begin Close(F); Exit; End;

 If PW > 1024 Then PW := 1024;
 If PH > 1024 Then PH := 1024;

 If ColorMode = 3 Then ChanNeed := 3 Else ChanNeed := 1;
 If NumChanFile < ChanNeed Then Begin Close(F); Exit; End;

 GetMem(LineBuf, PW + 16);
 ChanBytes := PW * PH;
 For I := 0 To ChanNeed-1 Do GetMem(ChanBuf[I], ChanBytes);

 If Compression = 1 Then Begin
  RowCountBytes := LongInt(PH) * NumChanFile * 2;
  GetMem(RowCountsPtr, RowCountBytes);
  BlockRead(F, RowCountsPtr^, RowCountBytes, BytesRead);
 End;

 For ChannelIdx := 0 To NumChanFile - 1 Do
  For RowIdx := 0 To PH - 1 Do Begin
   If Compression = 0 Then Begin
    BlockRead(F, LineBuf^, PW, BytesRead);
   End Else Begin
    PixOff := (LongInt(ChannelIdx) * PH + RowIdx) * 2;
    EncLen := (Word(RowCountsPtr^[PixOff]) Shl 8) Or Word(RowCountsPtr^[PixOff+1]);
    DecodeRLERow(EncLen, LineBuf, PW);
   End;
   If ChannelIdx < ChanNeed Then
    Move(LineBuf^, ChanBuf[ChannelIdx]^[LongInt(RowIdx) * PW], PW);
  End;

 Close(F);

 { Palette indexed (PSD : 256 R puis 256 G puis 256 B) }
 If (ColorMode = 2) And HasPal Then Begin
  For I := 0 To 255 Do Begin
   R := PSDPal[I]; G := PSDPal[256+I]; B := PSDPal[512+I];
   Best := 0; BestDist := MaxLongInt;
   For C := 0 To 15 Do Begin
    DR := LongInt(R) - VGA_R[C];
    DG := LongInt(G) - VGA_G[C];
    DB := LongInt(B) - VGA_B[C];
    Dist := DR*DR + DG*DG + DB*DB;
    If Dist < BestDist Then Begin BestDist := Dist; Best := C; End;
   End;
   PalRemap[I] := Byte(Best);
  End;
 End;

 { Redimensionner si necessaire }
 If (PW <> ImgW) Or (PH <> ImgH) Then Begin
  For I := 0 To MAX_LAYERS-1 Do If Layers[I].Used Then FreeLayer(I);
  ImgW := PW; ImgH := PH;
  AllocLayer(0, 'Arriere-plan', False);
  LayerCount := 1; ActiveLayer := 0;
 End;

 For Y := 0 To PH - 1 Do
  For X := 0 To PW - 1 Do Begin
   Vidx := 0;
   Case ColorMode Of
    1: Begin
     R := ChanBuf[0]^[LongInt(Y)*PW + X]; G := R; B := R;
     Best := 0; BestDist := MaxLongInt;
     For C := 0 To 15 Do Begin
      DR := LongInt(R) - VGA_R[C];
      DG := LongInt(G) - VGA_G[C];
      DB := LongInt(B) - VGA_B[C];
      Dist := DR*DR + DG*DG + DB*DB;
      If Dist < BestDist Then Begin BestDist := Dist; Best := C; End;
     End;
     Vidx := Byte(Best);
    End;
    2: Begin
     PalIdx := ChanBuf[0]^[LongInt(Y)*PW + X];
     If HasPal Then Vidx := PalRemap[PalIdx] Else Vidx := PalIdx And 15;
    End;
    3: Begin
     R := ChanBuf[0]^[LongInt(Y)*PW + X];
     G := ChanBuf[1]^[LongInt(Y)*PW + X];
     B := ChanBuf[2]^[LongInt(Y)*PW + X];
     Best := 0; BestDist := MaxLongInt;
     For C := 0 To 15 Do Begin
      DR := LongInt(R) - VGA_R[C];
      DG := LongInt(G) - VGA_G[C];
      DB := LongInt(B) - VGA_B[C];
      Dist := DR*DR + DG*DG + DB*DB;
      If Dist < BestDist Then Begin BestDist := Dist; Best := C; End;
     End;
     Vidx := Byte(Best);
    End;
   End;
   SetLayerPixel(ActiveLayer, X, Y, Vidx);
  End;

 For I := 0 To ChanNeed-1 Do
  If ChanBuf[I] <> Nil Then FreeMem(ChanBuf[I], ChanBytes);
 If LineBuf <> Nil Then FreeMem(LineBuf, PW + 16);
 If RowCountsPtr <> Nil Then FreeMem(RowCountsPtr, RowCountBytes);

 CurrentFileName := FileName;
 ImageModified := False;
 LoadPSD := True;
End;
{$POP}

{ ============================================================
   Dialogues
  ============================================================ }

Procedure DrawDlgButton(BX1, BY1, BX2, BY2: Integer; Const Cap: String; Pressed: Boolean);
Var TX: Integer;
Begin
 HideMouseCursor;
 FillRect(BX1, BY1, BX2, BY2, UI_BG_PANEL);
 DrawBevel(BX1, BY1, BX2, BY2, Pressed);
 SetColor(UI_TEXT);
 TX := BX1 + ((BX2-BX1) - Length(Cap)*8) Div 2;
 If Pressed Then OutTextXY(TX+1, BY1+6, Cap)
 Else OutTextXY(TX, BY1+5, Cap);
 ShowMouseCursor;
End;

Procedure ShowDialog(Const Title, Msg: String);
Var X1, Y1, X2, Y2, BX1, BY1, BX2, BY2: Integer;
    Ch: Char; Done, BtnDown, InRect: Boolean;
    MX, MY, MB, OldMB: Integer;
Begin
 HideMouseCursor;
 X1 := ScreenWidth Div 2 - 160;
 Y1 := ScreenHeight Div 2 - 50;
 X2 := X1 + 320;
 Y2 := Y1 + 100;
 FillRect(X1, Y1, X2, Y2, UI_BG_PANEL);
 DrawBevel(X1, Y1, X2, Y2, True);
 FillRect(X1+1, Y1+1, X2-1, Y1+18, UI_BG_DARK);
 SetColor(UI_TEXT_LITE);
 OutTextXY(X1+8, Y1+5, Title);
 SetColor(UI_TEXT);
 OutTextXY(X1+12, Y1+40, Msg);
 BX1 := X1 + 130; BY1 := Y2 - 28;
 BX2 := BX1 + 60; BY2 := BY1 + 18;
 DrawDlgButton(BX1, BY1, BX2, BY2, 'OK', False);
 ShowMouseCursor;
 While KeyPressed Do ReadKey;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 Done := False;
 BtnDown := False;
 OldMB := 0;
 Repeat
  If KeyPressed Then Begin
   Ch := ReadKey;
   If Ch=#0 Then ReadKey
   Else If (Ch=#13) Or (Ch=#27) Or (Ch=' ') Then Done := True;
  End;
  GetMouseStateLocal(MX, MY, MB);
  InRect := (MX>=BX1) And (MX<=BX2) And (MY>=BY1) And (MY<=BY2);
  If (OldMB And 1 = 0) And (MB And 1 <> 0) And InRect Then Begin
   BtnDown := True;
   DrawDlgButton(BX1, BY1, BX2, BY2, 'OK', True);
  End;
  If BtnDown And (OldMB And 1 <> 0) And (MB And 1 = 0) Then Begin
   DrawDlgButton(BX1, BY1, BX2, BY2, 'OK', False);
   BtnDown := False;
   If InRect Then Done := True;
  End;
  OldMB := MB;
 Until Done;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 MouseButtons := 0; OldMouseButtons := 0;
 DrawFullUI;
End;

Function PromptStr(Const Title, Prompt: String; Var Value: String): Boolean;
Var
 X1, Y1, X2, Y2: Integer;
 OKx1, OKy1, OKx2, OKy2: Integer;
 CXx1, CYy1, CXx2, CYy2: Integer;
 Ch: Char;
 Done, Ok: Boolean;
 MX, MY, MB, OldMB: Integer;
Begin
 Ok := False;
 HideMouseCursor;
 X1 := ScreenWidth Div 2 - 160;
 Y1 := ScreenHeight Div 2 - 50;
 X2 := X1 + 320;
 Y2 := Y1 + 100;
 FillRect(X1, Y1, X2, Y2, UI_BG_PANEL);
 DrawBevel(X1, Y1, X2, Y2, True);
 FillRect(X1+1, Y1+1, X2-1, Y1+18, UI_BG_DARK);
 SetColor(UI_TEXT_LITE);
 OutTextXY(X1+8, Y1+5, Title);
 SetColor(UI_TEXT);
 OutTextXY(X1+12, Y1+30, Prompt);
 DrawBevel(X1+12, Y1+50, X2-12, Y1+68, False);
 OKx1 := X1+90;  OKy1 := Y2-26; OKx2 := OKx1+60; OKy2 := OKy1+18;
 CXx1 := X1+170; CYy1 := Y2-26; CXx2 := CXx1+80; CYy2 := CYy1+18;
 FillRect(OKx1, OKy1, OKx2, OKy2, UI_BG_PANEL); DrawBevel(OKx1, OKy1, OKx2, OKy2, False);
 FillRect(CXx1, CYy1, CXx2, CYy2, UI_BG_PANEL); DrawBevel(CXx1, CYy1, CXx2, CYy2, False);
 SetColor(UI_TEXT);
 OutTextXY(OKx1+20, OKy1+5, 'OK');
 OutTextXY(CXx1+16, CYy1+5, 'Annuler');
 ShowMouseCursor;
 While KeyPressed Do ReadKey;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 Done := False;
 OldMB := 0;
 Repeat
  HideMouseCursor;
  FillRect(X1+13, Y1+51, X2-13, Y1+67, White);
  SetColor(UI_TEXT);
  OutTextXY(X1+16, Y1+55, Value+'_');
  ShowMouseCursor;
  Repeat
   If KeyPressed Then Break;
   GetMouseStateLocal(MX, MY, MB);
   If (OldMB And 1 = 0) And (MB And 1 <> 0) Then Begin
    If (MX>=OKx1) And (MX<=OKx2) And (MY>=OKy1) And (MY<=OKy2) Then Begin
     Done := True; Ok := True; OldMB := MB; Break;
    End;
    If (MX>=CXx1) And (MX<=CXx2) And (MY>=CYy1) And (MY<=CYy2) Then Begin
     Done := True; Ok := False; OldMB := MB; Break;
    End;
   End;
   OldMB := MB;
  Until False;
  If Done Then Break;
  Ch := ReadKey;
  Case Ch Of
   #13: Begin Done := True; Ok := True; End;
   #27: Begin Done := True; Ok := False; End;
   #8 : If Length(Value)>0 Then Delete(Value, Length(Value), 1);
   #0 : ReadKey;
  Else
   If (Ch>=' ') And (Length(Value)<60) Then Value := Value + Ch;
  End;
 Until Done;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 ShowMouseCursor;
 PromptStr := Ok;
End;

{ ============================================================
   Info fichier - dialogue type Adobe Photoshop
   ============================================================
   Composition :
   - Liste de categories a gauche (Basique, Donnees camera,
     Origine, IPTC, GPS, Audio, Video, Photoshop, DICOM,
     Donnees brutes).
   - Panneau de champs editables (saisie clavier) ou en lecture
     seule (auto-renseignes : nom, format, dimensions, taille,
     date du fichier...).
   - Boutons OK / Annuler.
   - Navigation clavier : Tab/Maj+Tab entre champs editables,
     fleches haut/bas pour changer de categorie, Suppr pour vider
     un champ, Enter=OK, Esc=Annuler.
   - Souris : clic categorie a gauche, clic champ a droite,
     clic boutons en bas.
  ============================================================ }

Const
 FI_DLG_W        = 600;
 FI_DLG_H        = 430;
 FI_LIST_W       = 134;
 FI_ROW_H        = 22;
 FI_FIELDLABEL_W = 132;
 FI_CAT_COUNT    = 10;
 FI_MAX_FIELDS   = 16;
 FI_VALUE_MAX    = 80;

Type
 TFI_Field = Record
  Lbl     : String[28];
  Value   : String[FI_VALUE_MAX];
  Editable: Boolean;
 End;

 TFI_Category = Record
  Name  : String[24];
  Count : Byte;
  Fields: Array[0..FI_MAX_FIELDS-1] of TFI_Field;
 End;

Var
 FICats   : Array[0..FI_CAT_COUNT-1] of TFI_Category;
 FICurCat : Integer;
 FIFocus  : Integer;
 FIScroll : Integer;
 FIDirty  : Boolean;
 FIInit   : Boolean;
 FIX1, FIY1, FIX2, FIY2     : Integer;
 FILX1, FILY1, FILX2, FILY2 : Integer;
 FIRX1, FIRY1, FIRX2, FIRY2 : Integer;
 FIOKx1, FIOKy1, FIOKx2, FIOKy2 : Integer;
 FICX1, FICY1, FICX2, FICY2     : Integer;

Procedure FI_AddField(Cat: Integer; Const L, V: String; Edit: Boolean);
Var N: Integer;
Begin
 N := FICats[Cat].Count;
 If N >= FI_MAX_FIELDS Then Exit;
 FICats[Cat].Fields[N].Lbl := L;
 FICats[Cat].Fields[N].Value := V;
 FICats[Cat].Fields[N].Editable := Edit;
 FICats[Cat].Count := N + 1;
End;

Procedure FI_ResetCategories;
Var I: Integer;
Begin
 For I := 0 To FI_CAT_COUNT-1 Do FICats[I].Count := 0;
End;

Function FI_FileSizeStr(Sz: LongInt): String;
Var Frac: LongInt;
Begin
 If Sz < 1024 Then
  FI_FileSizeStr := IntToStr(Sz) + ' octets'
 Else If Sz < 1048576 Then Begin
  Frac := (Sz * 10) Div 1024;
  FI_FileSizeStr := IntToStr(Frac Div 10) + ',' + IntToStr(Frac Mod 10) + ' Ko';
 End Else Begin
  Frac := (Sz Div 1024 * 10) Div 1024;
  FI_FileSizeStr := IntToStr(Frac Div 10) + ',' + IntToStr(Frac Mod 10) + ' Mo';
 End;
End;

Function FI_TwoDig(N: Integer): String;
Var S: String;
Begin
 S := IntToStr(N);
 If Length(S) < 2 Then S := '0' + S;
 FI_TwoDig := S;
End;

Function FI_UpperExt(Const Fn: String): String;
Var I, DotPos: Integer; E: String;
Begin
 DotPos := 0;
 For I := Length(Fn) DownTo 1 Do
  If Fn[I] = '.' Then Begin DotPos := I; Break; End;
 If DotPos = 0 Then Begin FI_UpperExt := ''; Exit; End;
 E := Copy(Fn, DotPos + 1, 8);
 For I := 1 To Length(E) Do E[I] := UpCase(E[I]);
 FI_UpperExt := E;
End;

Function FI_FormatName(Const Ext: String): String;
Begin
 If (Ext = 'JPG') Or (Ext = 'JPEG') Then
  FI_FormatName := 'JPEG (Joint Photographic Experts Group)'
 Else If Ext = 'PNG' Then
  FI_FormatName := 'PNG (Portable Network Graphics)'
 Else If Ext = 'GIF' Then
  FI_FormatName := 'GIF (Graphics Interchange Format)'
 Else If (Ext = 'BMP') Or (Ext = 'DIB') Then
  FI_FormatName := 'Windows Bitmap'
 Else If Ext = 'PCX' Then
  FI_FormatName := 'ZSoft PCX'
 Else If Ext = 'TGA' Then
  FI_FormatName := 'Truevision Targa'
 Else If (Ext = 'TIF') Or (Ext = 'TIFF') Then
  FI_FormatName := 'Tagged Image File Format'
 Else If Ext = 'PSD' Then
  FI_FormatName := 'Adobe Photoshop Document'
 Else If Ext = '' Then
  FI_FormatName := '(aucun)'
 Else
  FI_FormatName := Ext;
End;

Procedure FI_InitDefaults;
Begin
 { 0 : General }
 FICats[0].Name := 'General';
 FI_AddField(0, 'Titre du document',     '',         True);
 FI_AddField(0, 'Auteur',                '',         True);
 FI_AddField(0, 'Titre auteur',          '',         True);
 FI_AddField(0, 'Description',           '',         True);
 FI_AddField(0, 'Mots-cles',             '',         True);
 FI_AddField(0, 'Note',                  '0',        True);
 FI_AddField(0, 'Redacteur description', '',         True);
 FI_AddField(0, 'Statut copyright',      'Inconnu',  True);
 FI_AddField(0, 'Avis copyright',        '',         True);
 FI_AddField(0, 'URL copyright',         '',         True);

 { 1 : Donnees camera }
 FICats[1].Name := 'Donnees camera';
 FI_AddField(1, 'Marque',                '',         True);
 FI_AddField(1, 'Modele',                '',         True);
 FI_AddField(1, 'Date/heure prise',      '',         True);
 FI_AddField(1, 'Vitesse obturation',    '',         True);
 FI_AddField(1, 'Ouverture',             '',         True);
 FI_AddField(1, 'ISO',                   '',         True);
 FI_AddField(1, 'Distance focale',       '',         True);
 FI_AddField(1, 'Flash',                 'Non',      True);
 FI_AddField(1, 'Mode mesure',           '',         True);
 FI_AddField(1, 'Balance des blancs',    'Auto',     True);
 FI_AddField(1, 'Compensation expo',     '0 EV',     True);

 { 2 : Origine }
 FICats[2].Name := 'Origine';
 FI_AddField(2, 'Date de creation',      '',         True);
 FI_AddField(2, 'Ville',                 '',         True);
 FI_AddField(2, 'Etat/Province',         '',         True);
 FI_AddField(2, 'Pays',                  '',         True);
 FI_AddField(2, 'Code postal',           '',         True);
 FI_AddField(2, 'Source',                '',         True);
 FI_AddField(2, 'Titre du travail',      '',         True);
 FI_AddField(2, 'Instructions',          '',         True);
 FI_AddField(2, 'Credit',                '',         True);

 { 3 : IPTC }
 FICats[3].Name := 'IPTC';
 FI_AddField(3, 'Createur',              '',         True);
 FI_AddField(3, 'Adresse createur',      '',         True);
 FI_AddField(3, 'Ville createur',        '',         True);
 FI_AddField(3, 'Etat/Province',         '',         True);
 FI_AddField(3, 'Code postal',           '',         True);
 FI_AddField(3, 'Pays',                  '',         True);
 FI_AddField(3, 'Telephone',             '',         True);
 FI_AddField(3, 'Courriel',              '',         True);
 FI_AddField(3, 'Site web',              '',         True);
 FI_AddField(3, 'Titre du poste',        '',         True);

 { 4 : Donnees GPS }
 FICats[4].Name := 'Donnees GPS';
 FI_AddField(4, 'Latitude',              '',         True);
 FI_AddField(4, 'Longitude',             '',         True);
 FI_AddField(4, 'Altitude',              '',         True);
 FI_AddField(4, 'Direction',             '',         True);
 FI_AddField(4, 'Vitesse',               '',         True);
 FI_AddField(4, 'Date/heure UTC',        '',         True);

 { 5 : Donnees audio }
 FICats[5].Name := 'Donnees audio';
 FI_AddField(5, 'Artiste',               '',         True);
 FI_AddField(5, 'Album',                 '',         True);
 FI_AddField(5, 'Piste',                 '',         True);
 FI_AddField(5, 'Genre',                 '',         True);
 FI_AddField(5, 'Annee',                 '',         True);
 FI_AddField(5, 'Compositeur',           '',         True);

 { 6 : Donnees video }
 FICats[6].Name := 'Donnees video';
 FI_AddField(6, 'Codec',                 '',         True);
 FI_AddField(6, 'Frequence images',      '',         True);
 FI_AddField(6, 'Duree',                 '',         True);
 FI_AddField(6, 'Realisateur',           '',         True);
 FI_AddField(6, 'Camera',                '',         True);

 { 7 : Photoshop }
 FICats[7].Name := 'Photoshop';
 FI_AddField(7, 'Categorie',             '',         True);
 FI_AddField(7, 'Mots-cles supp.',       '',         True);
 FI_AddField(7, 'Urgence',               '0',        True);
 FI_AddField(7, 'Instructions',          '',         True);

 { 8 : DICOM }
 FICats[8].Name := 'DICOM';
 FI_AddField(8, 'Patient ID',            '',         True);
 FI_AddField(8, 'Nom patient',           '',         True);
 FI_AddField(8, 'Sexe',                  '',         True);
 FI_AddField(8, 'Date naissance',        '',         True);
 FI_AddField(8, 'Description etude',     '',         True);
 FI_AddField(8, 'Description serie',     '',         True);
End;

Procedure FI_ResetMetadata;
Begin
 FI_ResetCategories;
 FIInit := False;
End;

Function FI_SidecarName(Const Fn: String): String;
Begin
 If Fn = '' Then FI_SidecarName := '' Else FI_SidecarName := Fn + '.meta';
End;

Procedure FI_SaveSidecar(Const Fn: String);
Var Tf: Text; SF: String; C, Fld: Integer;
    AnyVal: Boolean;
Begin
 SF := FI_SidecarName(Fn);
 If SF = '' Then Exit;
 If Not FIInit Then Exit;
 AnyVal := False;
 For C := 0 To FI_CAT_COUNT - 2 Do
  For Fld := 0 To FICats[C].Count - 1 Do
   If FICats[C].Fields[Fld].Editable Then
    If FICats[C].Fields[Fld].Value <> '' Then Begin AnyVal := True; Break; End;
 If Not AnyVal Then Exit;
 Assign(Tf, SF);
 {$I-} Rewrite(Tf); {$I+}
 If IOResult <> 0 Then Exit;
 Writeln(Tf, '# PSP metadata sidecar v1');
 For C := 0 To FI_CAT_COUNT - 2 Do
  For Fld := 0 To FICats[C].Count - 1 Do
   If FICats[C].Fields[Fld].Editable Then
    If FICats[C].Fields[Fld].Value <> '' Then
     Writeln(Tf, IntToStr(C), '|', IntToStr(Fld), '=',
             FICats[C].Fields[Fld].Value);
 Close(Tf);
End;

Procedure FI_LoadSidecar(Const Fn: String);
Var Tf: Text; SF, Line, NumStr, ValStr: String;
    C, Fld, P, Q, Code: Integer;
Begin
 SF := FI_SidecarName(Fn);
 If SF = '' Then Exit;
 Assign(Tf, SF);
 {$I-} Reset(Tf); {$I+}
 If IOResult <> 0 Then Exit;
 If Not FIInit Then Begin
  FI_ResetCategories;
  FI_InitDefaults;
  FIInit := True;
 End;
 While Not Eof(Tf) Do Begin
  {$I-} Readln(Tf, Line); {$I+}
  If IOResult <> 0 Then Break;
  If Line = '' Then Continue;
  If Line[1] = '#' Then Continue;
  P := Pos('|', Line);
  Q := Pos('=', Line);
  If (P = 0) Or (Q = 0) Or (P > Q) Then Continue;
  NumStr := Copy(Line, 1, P - 1);
  Val(NumStr, C, Code); If Code <> 0 Then Continue;
  NumStr := Copy(Line, P + 1, Q - P - 1);
  Val(NumStr, Fld, Code); If Code <> 0 Then Continue;
  ValStr := Copy(Line, Q + 1, FI_VALUE_MAX);
  If (C < 0) Or (C >= FI_CAT_COUNT - 1) Then Continue;
  If (Fld < 0) Or (Fld >= FICats[C].Count) Then Continue;
  If Not FICats[C].Fields[Fld].Editable Then Continue;
  FICats[C].Fields[Fld].Value := ValStr;
 End;
 Close(Tf);
End;

Procedure FI_GatherInfo;
Var SR: SearchRec; DT: DateTime;
    FSize: LongInt;
    FYr, FMo, FDy, FHr, FMn: Integer;
    Ext: String;
    Has: Boolean;
Begin
 If Not FIInit Then Begin
  FI_ResetCategories;
  FI_InitDefaults;
  FIInit := True;
 End;

 { 9 : Donnees brutes (auto, lecture seule) - toujours regenere }
 FICats[9].Count := 0;
 FICats[9].Name := 'Donnees brutes';
 If CurrentFileName = '' Then
  FI_AddField(9, 'Nom du fichier',  '(sans titre)',   False)
 Else
  FI_AddField(9, 'Nom du fichier',  CurrentFileName,  False);

 Ext := FI_UpperExt(CurrentFileName);
 FI_AddField(9, 'Format',           FI_FormatName(Ext),  False);
 FI_AddField(9, 'Largeur',          IntToStr(ImgW) + ' pixels', False);
 FI_AddField(9, 'Hauteur',          IntToStr(ImgH) + ' pixels', False);
 FI_AddField(9, 'Mode couleur',     'Indexe 16 (VGA)',          False);
 FI_AddField(9, 'Profondeur',       '4 bits/pixel',             False);
 FI_AddField(9, 'Calques',          IntToStr(LayerCount),       False);
 FI_AddField(9, 'Resolution',       '72 dpi',                   False);

 Has := False;
 FSize := 0; FYr := 0; FMo := 0; FDy := 0; FHr := 0; FMn := 0;
 If CurrentFileName <> '' Then Begin
  FindFirst(CurrentFileName, AnyFile, SR);
  If DosError = 0 Then Begin
   FSize := SR.Size;
   UnpackTime(SR.Time, DT);
   FYr := DT.Year; FMo := DT.Month; FDy := DT.Day;
   FHr := DT.Hour; FMn := DT.Min;
   Has := True;
  End;
  FindClose(SR);
 End;
 If Has Then Begin
  FI_AddField(9, 'Taille fichier', FI_FileSizeStr(FSize), False);
  FI_AddField(9, 'Date modif.',
   FI_TwoDig(FYr Mod 100) + '/' + FI_TwoDig(FMo) + '/' +
   FI_TwoDig(FDy) + ' ' + FI_TwoDig(FHr) + ':' + FI_TwoDig(FMn), False);
 End Else Begin
  FI_AddField(9, 'Taille fichier', 'N/A', False);
  FI_AddField(9, 'Date modif.',    'N/A', False);
 End;

 FIFocus := -1;
 FIScroll := 0;
 FIDirty := False;
End;

Procedure FI_FieldRect(FIdx: Integer; Var X1, Y1, X2, Y2: Integer);
Begin
 X1 := FIRX1 + 8 + FI_FIELDLABEL_W;
 X2 := FIRX2 - 8;
 Y1 := FIRY1 + 8 + FIdx * FI_ROW_H - FIScroll;
 Y2 := Y1 + FI_ROW_H - 6;
End;

Procedure FI_DrawCategoryList;
Var I, ItemY: Integer; Sel: Boolean;
Begin
 HideMouseCursor;
 FillRect(FILX1, FILY1, FILX2, FILY2, UI_BG_DARK);
 DrawBevel(FILX1, FILY1, FILX2, FILY2, False);
 For I := 0 To FI_CAT_COUNT-1 Do Begin
  ItemY := FILY1 + 4 + I * FI_ROW_H;
  Sel := (I = FICurCat);
  If Sel Then FillRect(FILX1+2, ItemY-2, FILX2-2, ItemY + FI_ROW_H - 4, UI_ACCENT);
  SetColor(UI_TEXT_LITE);
  OutTextXY(FILX1 + 6, ItemY + 3, FICats[I].Name);
 End;
 ShowMouseCursor;
End;

Procedure FI_DrawField(FIdx: Integer; Focused: Boolean);
Var FX1, FY1, FX2, FY2: Integer;
    BG: Byte; V: String; AvailW, CurPx: Integer;
Begin
 FI_FieldRect(FIdx, FX1, FY1, FX2, FY2);
 If (FY2 < FIRY1 + 8) Or (FY1 > FIRY2 - 8) Then Exit;
 HideMouseCursor;
 { Etiquette }
 FillRect(FIRX1 + 4, FY1, FX1 - 2, FY2, UI_BG_PANEL);
 SetColor(UI_TEXT_LITE);
 OutTextXY(FIRX1 + 10, FY1 + 4, FICats[FICurCat].Fields[FIdx].Lbl + ' :');
 { Boite saisie }
 If FICats[FICurCat].Fields[FIdx].Editable Then BG := White Else BG := UI_BG_DARK;
 FillRect(FX1, FY1, FX2, FY2, BG);
 DrawBevel(FX1, FY1, FX2, FY2, False);
 If Focused Then Begin
  SetColor(UI_ACCENT);
  Rectangle(FX1 - 1, FY1 - 1, FX2 + 1, FY2 + 1);
 End;
 V := FICats[FICurCat].Fields[FIdx].Value;
 AvailW := (FX2 - FX1 - 6) Div 8;
 If AvailW < 1 Then AvailW := 1;
 If Length(V) > AvailW Then V := Copy(V, Length(V) - AvailW + 1, AvailW);
 If FICats[FICurCat].Fields[FIdx].Editable Then SetColor(UI_TEXT)
                                          Else SetColor(UI_TEXT_LITE);
 OutTextXY(FX1 + 4, FY1 + 4, V);
 If Focused Then Begin
  CurPx := FX1 + 4 + Length(V) * 8;
  If CurPx > FX2 - 2 Then CurPx := FX2 - 2;
  SetColor(UI_TEXT);
  Line(CurPx, FY1 + 3, CurPx, FY2 - 3);
 End;
 ShowMouseCursor;
End;

Procedure FI_DrawFields;
Var I: Integer;
Begin
 HideMouseCursor;
 FillRect(FIRX1, FIRY1 - 16, FIRX2, FIRY1 - 2, UI_BG_PANEL);
 FillRect(FIRX1, FIRY1, FIRX2, FIRY2, UI_BG_PANEL);
 DrawBevel(FIRX1, FIRY1, FIRX2, FIRY2, False);
 SetColor(UI_TEXT_LITE);
 OutTextXY(FIRX1 + 4, FIRY1 - 12, 'Categorie : ' + FICats[FICurCat].Name);
 ShowMouseCursor;
 For I := 0 To FICats[FICurCat].Count - 1 Do
  FI_DrawField(I, I = FIFocus);
End;

Procedure FI_DrawButtons(OkDown, CancelDown: Boolean);
Begin
 DrawDlgButton(FIOKx1, FIOKy1, FIOKx2, FIOKy2, 'OK',      OkDown);
 DrawDlgButton(FICX1,  FICY1,  FICX2,  FICY2, 'Annuler', CancelDown);
End;

Procedure FI_DrawDialog;
Var TitleStr: String;
Begin
 HideMouseCursor;
 FillRect(FIX1, FIY1, FIX2, FIY2, UI_BG_PANEL);
 DrawBevel(FIX1, FIY1, FIX2, FIY2, True);
 FillRect(FIX1 + 1, FIY1 + 1, FIX2 - 1, FIY1 + 18, UI_BG_DARK);
 SetColor(UI_TEXT_LITE);
 TitleStr := 'Info fichier';
 If CurrentFileName <> '' Then TitleStr := TitleStr + ' - ' + CurrentFileName;
 OutTextXY(FIX1 + 8, FIY1 + 5, TitleStr);
 SetColor(UI_TEXT);
 OutTextXY(FIX1 + 12, FIY2 - 30,
  'Tab/Maj-Tab: champ  Fleches: categorie  Suppr: vider');
 ShowMouseCursor;
 FI_DrawCategoryList;
 FI_DrawFields;
 FI_DrawButtons(False, False);
End;

Function FI_HitCategory(MX, MY: Integer): Integer;
Var I, ItemY: Integer;
Begin
 FI_HitCategory := -1;
 If (MX < FILX1) Or (MX > FILX2) Then Exit;
 If (MY < FILY1) Or (MY > FILY2) Then Exit;
 For I := 0 To FI_CAT_COUNT - 1 Do Begin
  ItemY := FILY1 + 4 + I * FI_ROW_H;
  If (MY >= ItemY - 2) And (MY <= ItemY + FI_ROW_H - 4) Then Begin
   FI_HitCategory := I; Exit;
  End;
 End;
End;

Function FI_HitField(MX, MY: Integer): Integer;
Var I, FX1, FY1, FX2, FY2: Integer;
Begin
 FI_HitField := -1;
 For I := 0 To FICats[FICurCat].Count - 1 Do Begin
  FI_FieldRect(I, FX1, FY1, FX2, FY2);
  If (MX >= FX1) And (MX <= FX2) And (MY >= FY1) And (MY <= FY2) Then Begin
   FI_HitField := I; Exit;
  End;
 End;
End;

Procedure FI_NextEditable(Dir: Integer);
Var Idx, N, Tries: Integer;
Begin
 N := FICats[FICurCat].Count;
 If N = 0 Then Exit;
 If FIFocus < 0 Then Begin
  If Dir > 0 Then Idx := 0 Else Idx := N - 1;
 End Else Idx := FIFocus + Dir;
 Tries := 0;
 While Tries < N * 2 Do Begin
  If Idx < 0 Then Idx := N - 1;
  If Idx >= N Then Idx := 0;
  If FICats[FICurCat].Fields[Idx].Editable Then Begin
   FIFocus := Idx; Exit;
  End;
  Idx := Idx + Dir;
  Inc(Tries);
 End;
End;

Function FI_Run: Boolean;
Var Ch, Ch2: Char;
    Done, Ok: Boolean;
    MX, MY, MB, OldMB: Integer;
    NewCat, Hit: Integer;
    OkInRect, CXInRect, BtnOkDown, BtnCxDown: Boolean;
Begin
 FI_GatherInfo;
 FIX1 := (ScreenWidth - FI_DLG_W) Div 2;
 FIY1 := (ScreenHeight - FI_DLG_H) Div 2;
 If FIY1 < MENUBAR_HEIGHT + 2 Then FIY1 := MENUBAR_HEIGHT + 2;
 If FIX1 < 4 Then FIX1 := 4;
 FIX2 := FIX1 + FI_DLG_W;
 FIY2 := FIY1 + FI_DLG_H;
 FILX1 := FIX1 + 8;          FILY1 := FIY1 + 40;
 FILX2 := FILX1 + FI_LIST_W; FILY2 := FIY2 - 50;
 FIRX1 := FILX2 + 10;        FIRY1 := FIY1 + 40;
 FIRX2 := FIX2 - 8;          FIRY2 := FIY2 - 50;
 FIOKx1 := FIX2 - 180; FIOKy1 := FIY2 - 36;
 FIOKx2 := FIOKx1 + 70; FIOKy2 := FIOKy1 + 24;
 FICX1  := FIX2 - 96;  FICY1 := FIY2 - 36;
 FICX2  := FICX1 + 86; FICY2 := FICY1 + 24;

 FI_DrawDialog;
 While KeyPressed Do ReadKey;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 Done := False; Ok := False; OldMB := 0;
 BtnOkDown := False; BtnCxDown := False;

 Repeat
  If KeyPressed Then Begin
   Ch := ReadKey;
   If Ch = #0 Then Begin
    Ch2 := ReadKey;
    Case Ch2 Of
     #72: Begin
      If FICurCat > 0 Then Begin
       Dec(FICurCat); FIFocus := -1; FIScroll := 0;
       FI_DrawCategoryList; FI_DrawFields;
      End;
     End;
     #80: Begin
      If FICurCat < FI_CAT_COUNT - 1 Then Begin
       Inc(FICurCat); FIFocus := -1; FIScroll := 0;
       FI_DrawCategoryList; FI_DrawFields;
      End;
     End;
     #15: Begin
      FI_NextEditable(-1);
      FI_DrawFields;
     End;
     #83: Begin
      If (FIFocus >= 0) And FICats[FICurCat].Fields[FIFocus].Editable Then Begin
       FICats[FICurCat].Fields[FIFocus].Value := '';
       FIDirty := True;
       FI_DrawField(FIFocus, True);
      End;
     End;
     #71: Begin   { Home : premiere categorie }
      If FICurCat <> 0 Then Begin
       FICurCat := 0; FIFocus := -1; FIScroll := 0;
       FI_DrawCategoryList; FI_DrawFields;
      End;
     End;
     #79: Begin   { End : derniere categorie }
      If FICurCat <> FI_CAT_COUNT - 1 Then Begin
       FICurCat := FI_CAT_COUNT - 1; FIFocus := -1; FIScroll := 0;
       FI_DrawCategoryList; FI_DrawFields;
      End;
     End;
    End;
   End Else Begin
    Case Ch Of
     #9 : Begin FI_NextEditable(+1); FI_DrawFields; End;
     #13: Begin Done := True; Ok := True; End;
     #27: Begin Done := True; Ok := False; End;
     #8 : Begin
      If (FIFocus >= 0) And FICats[FICurCat].Fields[FIFocus].Editable Then
       If Length(FICats[FICurCat].Fields[FIFocus].Value) > 0 Then Begin
        Delete(FICats[FICurCat].Fields[FIFocus].Value,
               Length(FICats[FICurCat].Fields[FIFocus].Value), 1);
        FIDirty := True;
        FI_DrawField(FIFocus, True);
       End;
     End;
    Else
     If (Ch >= ' ') And (Ord(Ch) < 127) Then
      If (FIFocus >= 0) And FICats[FICurCat].Fields[FIFocus].Editable Then
       If Length(FICats[FICurCat].Fields[FIFocus].Value) < FI_VALUE_MAX Then Begin
        FICats[FICurCat].Fields[FIFocus].Value :=
         FICats[FICurCat].Fields[FIFocus].Value + Ch;
        FIDirty := True;
        FI_DrawField(FIFocus, True);
       End;
    End;
   End;
  End;

  GetMouseStateLocal(MX, MY, MB);
  OkInRect := (MX>=FIOKx1) And (MX<=FIOKx2) And (MY>=FIOKy1) And (MY<=FIOKy2);
  CXInRect := (MX>=FICX1)  And (MX<=FICX2)  And (MY>=FICY1)  And (MY<=FICY2);

  If (OldMB And 1 = 0) And (MB And 1 <> 0) Then Begin
   If OkInRect Then Begin
    BtnOkDown := True; FI_DrawButtons(True, False);
   End Else If CXInRect Then Begin
    BtnCxDown := True; FI_DrawButtons(False, True);
   End Else Begin
    NewCat := FI_HitCategory(MX, MY);
    If NewCat >= 0 Then Begin
     If NewCat <> FICurCat Then Begin
      FICurCat := NewCat; FIFocus := -1; FIScroll := 0;
      FI_DrawCategoryList; FI_DrawFields;
     End;
    End Else Begin
     Hit := FI_HitField(MX, MY);
     If (Hit >= 0) And FICats[FICurCat].Fields[Hit].Editable Then Begin
      FIFocus := Hit;
      FI_DrawFields;
     End;
    End;
   End;
  End;

  If (OldMB And 1 <> 0) And (MB And 1 = 0) Then Begin
   If BtnOkDown Then Begin
    BtnOkDown := False; FI_DrawButtons(False, False);
    If OkInRect Then Begin Done := True; Ok := True; End;
   End;
   If BtnCxDown Then Begin
    BtnCxDown := False; FI_DrawButtons(False, False);
    If CXInRect Then Begin Done := True; Ok := False; End;
   End;
  End;

  OldMB := MB;
 Until Done;

 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 MouseButtons := 0; OldMouseButtons := 0;
 DrawFullUI;
 FI_Run := Ok;
End;

{ ============================================================
   Gestion calques
  ============================================================ }

Procedure NewLayerAction;
Var N: String;
Begin
 If LayerCount>=MAX_LAYERS Then Begin
  ShowDialog('Calques', 'Nombre maximum de calques atteint.');
  Exit;
 End;
 N := 'Calque ' + IntToStr(LayerCount+1);
 AllocLayer(LayerCount, N, True);
 ActiveLayer := LayerCount;
 Inc(LayerCount);
 ImageModified := True;
End;

Procedure DuplicateLayerAction;
Var Sz: LongInt;
Begin
 If LayerCount>=MAX_LAYERS Then Begin
  ShowDialog('Calques', 'Nombre maximum de calques atteint.');
  Exit;
 End;
 AllocLayer(LayerCount, 'Copie ' + Layers[ActiveLayer].Name, True);
 Sz := LongInt(ImgW) * ImgH;
 Move(Layers[ActiveLayer].Pixels^, Layers[LayerCount].Pixels^, Sz);
 ActiveLayer := LayerCount;
 Inc(LayerCount);
 ImageModified := True;
End;

Procedure DeleteLayerAction;
Var I: Integer;
Begin
 If LayerCount<=1 Then Begin
  ShowDialog('Calques', 'Au moins un calque doit rester.');
  Exit;
 End;
 FreeLayer(ActiveLayer);
 For I:=ActiveLayer To LayerCount-2 Do Layers[I] := Layers[I+1];
 Layers[LayerCount-1].Used := False;
 Layers[LayerCount-1].Pixels := Nil;
 Dec(LayerCount);
 If ActiveLayer>=LayerCount Then ActiveLayer := LayerCount-1;
 ImageModified := True;
End;

Procedure FlattenLayers;
Var X, Y, I: Integer; V: Byte;
Begin
 If LayerCount<=1 Then Exit;
 PushUndo;
 For Y:=0 To ImgH-1 Do
  For X:=0 To ImgW-1 Do Begin
   V := Composite(X, Y);
   If V=255 Then V := White;
   SetLayerPixel(0, X, Y, V);
  End;
 For I:=1 To LayerCount-1 Do FreeLayer(I);
 LayerCount := 1;
 ActiveLayer := 0;
 Layers[0].Name := 'Arriere-plan';
 ImageModified := True;
End;

{ ============================================================
   Actions de menu
  ============================================================ }

Procedure NewImage;
Var I: Integer;
Begin
 For I:=0 To MAX_LAYERS-1 Do If Layers[I].Used Then FreeLayer(I);
 ImgW := 400; ImgH := 300;
 AllocLayer(0, 'Arriere-plan', False);
 LayerCount := 1;
 ActiveLayer := 0;
 CurrentFileName := '';
 ImageModified := False;
 UndoCount := 0;
 ZoomLevel := 100;
 FI_ResetMetadata;
 FICurCat := 0;
End;

{ ============================================================
   Selecteur de fichiers style Photoshop
  ============================================================ }

Const
 FD_MAXENT = 256;
 FD_ROWH   = 10;
 FD_NUM_FILTERS = 10;
 FD_FILTER_LABELS: Array[0..FD_NUM_FILTERS-1] of String[36] = (
  'Tous formats images',
  'BMP (*.BMP;*.DIB)',
  'GIF (*.GIF)',
  'PNG (*.PNG)',
  'JPEG (*.JPG;*.JPEG)',
  'PCX (*.PCX)',
  'TGA (*.TGA)',
  'TIFF (*.TIF;*.TIFF)',
  'PSD (*.PSD)',
  'Tous fichiers (*.*)' );

Type
 TFDEntry = Record
  Name: String[60];
  IsDir: Boolean;
  Size: LongInt;
  Yr, Mo, Dy: Word;
 End;

Var
 FD_Dirs:  Array[0..FD_MAXENT-1] of TFDEntry;
 FD_Files: Array[0..FD_MAXENT-1] of TFDEntry;
 FD_NDirs, FD_NFiles: Integer;
 FD_SelDir, FD_SelFile: Integer;
 FD_TopDir, FD_TopFile: Integer;
 FD_Focus: Integer;
 FD_NameBuf: String;
 FD_FilterIdx: Integer;
 FD_CurDir: String;

Function FD_FilterLabel: String;
Begin FD_FilterLabel := FD_FILTER_LABELS[FD_FilterIdx]; End;

Function FD_ExtMatches(Const Nm: String): Boolean;
Var E: String;
Begin
 E := ExtractExt(Nm);
 Case FD_FilterIdx Of
  0: FD_ExtMatches := (E='.BMP') Or (E='.DIB') Or (E='.GIF') Or (E='.PNG') Or
                      (E='.JPG') Or (E='.JPEG') Or (E='.PCX') Or (E='.TGA') Or
                      (E='.TIF') Or (E='.TIFF') Or (E='.PSD');
  1: FD_ExtMatches := (E='.BMP') Or (E='.DIB');
  2: FD_ExtMatches := E='.GIF';
  3: FD_ExtMatches := E='.PNG';
  4: FD_ExtMatches := (E='.JPG') Or (E='.JPEG');
  5: FD_ExtMatches := E='.PCX';
  6: FD_ExtMatches := E='.TGA';
  7: FD_ExtMatches := (E='.TIF') Or (E='.TIFF');
  8: FD_ExtMatches := E='.PSD';
  9: FD_ExtMatches := True;
 Else FD_ExtMatches := False; End;
End;

Procedure FD_Pad2(Var S: String);
Begin While Length(S)<2 Do S:='0'+S; End;

Function FD_FmtDate(Const E: TFDEntry): String;
Var S, T: String;
Begin
 Str(E.Yr, S); Str(E.Mo, T); FD_Pad2(T); S:=S+'-'+T;
 Str(E.Dy, T); FD_Pad2(T); FD_FmtDate := S+'-'+T;
End;

Function FD_FmtSize(Sz: LongInt): String;
Var S: String;
Begin
 Str(Sz, S);
 While Length(S)<8 Do S:=' '+S;
 FD_FmtSize := S;
End;

Procedure FD_SortArr(Var A: Array of TFDEntry; N: Integer);
Var I, J: Integer; T: TFDEntry;
Begin
 For I:=0 To N-2 Do
  For J:=0 To N-2-I Do
   If UpperStr(A[J].Name) > UpperStr(A[J+1].Name) Then Begin
    T:=A[J]; A[J]:=A[J+1]; A[J+1]:=T;
   End;
End;

Procedure FD_Scan;
Var SR: SearchRec; DT: DateTime; E: TFDEntry;
Begin
 FD_NDirs:=0; FD_NFiles:=0;
 GetDir(0, FD_CurDir);
 FindFirst('*.*', Directory, SR);
 While DosError = 0 Do Begin
  If (SR.Attr And Directory) <> 0 Then
   If (SR.Name <> '.') And (FD_NDirs < FD_MAXENT) Then Begin
    E.Name := SR.Name; E.IsDir := True; E.Size := 0;
    UnpackTime(SR.Time, DT);
    E.Yr := DT.Year; E.Mo := DT.Month; E.Dy := DT.Day;
    FD_Dirs[FD_NDirs] := E; Inc(FD_NDirs);
   End;
  FindNext(SR);
 End;
 FindClose(SR);
 FindFirst('*.*', AnyFile, SR);
 While DosError = 0 Do Begin
  If ((SR.Attr And Directory) = 0) And ((SR.Attr And VolumeID) = 0) Then
   If FD_ExtMatches(SR.Name) And (FD_NFiles < FD_MAXENT) Then Begin
    E.Name := SR.Name; E.IsDir := False; E.Size := SR.Size;
    UnpackTime(SR.Time, DT);
    E.Yr := DT.Year; E.Mo := DT.Month; E.Dy := DT.Day;
    FD_Files[FD_NFiles] := E; Inc(FD_NFiles);
   End;
  FindNext(SR);
 End;
 FindClose(SR);
 FD_SortArr(FD_Dirs, FD_NDirs);
 FD_SortArr(FD_Files, FD_NFiles);
 If FD_SelDir >= FD_NDirs Then FD_SelDir := 0;
 If FD_SelFile >= FD_NFiles Then FD_SelFile := 0;
 FD_TopDir := 0; FD_TopFile := 0;
End;

Procedure FD_EnsureVisible(Var Top: Integer; Sel, Rows: Integer);
Begin
 If Sel < Top Then Top := Sel;
 If Sel >= Top + Rows Then Top := Sel - Rows + 1;
 If Top < 0 Then Top := 0;
End;

Procedure FD_DrawDirs(X1, Y1, X2, Y2: Integer; Active: Boolean);
Var Rows, I, Idx, RY: Integer; Nm: String; Bg: Byte;
Begin
 HideMouseCursor;
 FillRect(X1+1, Y1+1, X2-1, Y2-1, White);
 Rows := (Y2 - Y1 - 2) Div FD_ROWH;
 For I:=0 To Rows-1 Do Begin
  Idx := FD_TopDir + I;
  If Idx >= FD_NDirs Then Break;
  RY := Y1 + 2 + I * FD_ROWH;
  If Idx = FD_SelDir Then Begin
   If Active Then Bg := Blue Else Bg := DarkGray;
   FillRect(X1+1, RY-1, X2-1, RY+FD_ROWH-2, Bg);
   SetColor(UI_TEXT_LITE);
  End Else SetColor(UI_TEXT);
  Nm := '['+FD_Dirs[Idx].Name+']';
  If Length(Nm) > 18 Then Nm := Copy(Nm, 1, 18);
  OutTextXY(X1+4, RY, Nm);
 End;
 DrawBevel(X1, Y1, X2, Y2, False);
 ShowMouseCursor;
End;

Procedure FD_DrawFiles(X1, Y1, X2, Y2: Integer; Active: Boolean);
Var Rows, I, Idx, RY: Integer; Nm: String; Bg: Byte;
Begin
 HideMouseCursor;
 FillRect(X1+1, Y1+1, X2-1, Y2-1, White);
 Rows := (Y2 - Y1 - 2) Div FD_ROWH;
 For I:=0 To Rows-1 Do Begin
  Idx := FD_TopFile + I;
  If Idx >= FD_NFiles Then Break;
  RY := Y1 + 2 + I * FD_ROWH;
  If Idx = FD_SelFile Then Begin
   If Active Then Bg := Blue Else Bg := DarkGray;
   FillRect(X1+1, RY-1, X2-1, RY+FD_ROWH-2, Bg);
   SetColor(UI_TEXT_LITE);
  End Else SetColor(UI_TEXT);
  Nm := FD_Files[Idx].Name;
  If Length(Nm) > 22 Then Nm := Copy(Nm, 1, 22);
  OutTextXY(X1+4, RY, Nm);
  OutTextXY(X1+200, RY, FD_FmtSize(FD_Files[Idx].Size));
  OutTextXY(X1+285, RY, FD_FmtDate(FD_Files[Idx]));
 End;
 DrawBevel(X1, Y1, X2, Y2, False);
 ShowMouseCursor;
End;

Function FD_Open(Const Title: String; Var FN: String): Boolean;
Var
 DX1, DY1, DX2, DY2: Integer;
 DirX1, DirY1, DirX2, DirY2: Integer;
 FilX1, FilY1, FilX2, FilY2: Integer;
 NamX1, NamY1, NamX2, NamY2: Integer;
 TypX1, TypX2: Integer;
 OkX1, OkY1, OkX2, OkY2: Integer;
 CcX1, CcY1, CcX2, CcY2: Integer;
 DirRows, FileRows: Integer;
 Done, ResultVal: Boolean;
 Ch: Char;
 MX, MY, MB, OldMB: Integer;
 Idx: Integer;
 PathStr, Nm: String;

 Procedure RedrawAll;
 Begin
  HideMouseCursor;
  FillRect(DX1, DY1, DX2, DY2, UI_BG_PANEL);
  DrawBevel(DX1, DY1, DX2, DY2, True);
  FillRect(DX1+1, DY1+1, DX2-1, DY1+16, UI_BG_DARK);
  SetColor(UI_TEXT_LITE); OutTextXY(DX1+8, DY1+5, Title);
  SetColor(UI_TEXT);
  OutTextXY(DX1+5, DY1+22, 'Chemin:');
  FillRect(DX1+58, DY1+19, DX2-8, DY1+33, White);
  DrawBevel(DX1+58, DY1+19, DX2-8, DY1+33, False);
  PathStr := FD_CurDir;
  If Length(PathStr) > 65 Then PathStr := '...'+Copy(PathStr, Length(PathStr)-61, 62);
  OutTextXY(DX1+62, DY1+22, PathStr);
  OutTextXY(DirX1, DY1+38, 'Dossiers');
  OutTextXY(FilX1, DY1+38, 'Fichiers');
  ShowMouseCursor;
  FD_DrawDirs(DirX1, DirY1, DirX2, DirY2, FD_Focus=0);
  FD_DrawFiles(FilX1, FilY1, FilX2, FilY2, FD_Focus=1);
  HideMouseCursor;
  SetColor(UI_TEXT);
  OutTextXY(DX1+10, NamY1+4, 'Nom:');
  FillRect(NamX1, NamY1, NamX2, NamY2, White);
  DrawBevel(NamX1, NamY1, NamX2, NamY2, False);
  SetColor(UI_TEXT);
  OutTextXY(NamX1+4, NamY1+4, FD_NameBuf);
  If FD_Focus=2 Then OutTextXY(NamX1+4+Length(FD_NameBuf)*8, NamY1+4, '_');
  OutTextXY(DX2-220, NamY1+4, 'Type:');
  FillRect(TypX1, NamY1, TypX2, NamY2, UI_BG_PANEL);
  DrawBevel(TypX1, NamY1, TypX2, NamY2, True);
  SetColor(UI_TEXT);
  OutTextXY(TypX1+4, NamY1+4, FD_FilterLabel);
  OutTextXY(TypX2-12, NamY1+4, 'v');
  ShowMouseCursor;
  DrawDlgButton(OkX1, OkY1, OkX2, OkY2, 'Ouvrir', False);
  DrawDlgButton(CcX1, CcY1, CcX2, CcY2, 'Annuler', False);
 End;

 Procedure DoActivate;
 Var Sel: String; I: Integer;
 Begin
  If (FD_Focus = 0) And (FD_NDirs > 0) And (FD_SelDir < FD_NDirs) Then Begin
   Sel := FD_Dirs[FD_SelDir].Name;
   {$I-} ChDir(Sel); {$I+}
   If IOResult = 0 Then Begin FD_NameBuf := ''; FD_Scan; RedrawAll; End;
   Exit;
  End;
  Sel := FD_NameBuf;
  If Sel = '' Then
   If (FD_NFiles > 0) And (FD_SelFile < FD_NFiles) Then Sel := FD_Files[FD_SelFile].Name;
  If Sel = '' Then Exit;
  For I := 0 To FD_NDirs-1 Do
   If UpperStr(FD_Dirs[I].Name) = UpperStr(Sel) Then Begin
    {$I-} ChDir(Sel); {$I+}
    If IOResult = 0 Then Begin
     FD_NameBuf := ''; FD_Scan; RedrawAll; Exit;
    End;
   End;
  If (Length(Sel) >= 2) And (Sel[2] = ':') Then FN := Sel
  Else If (Length(Sel) >= 1) And (Sel[1] = '\') Then FN := Sel
  Else Begin
   FN := FD_CurDir;
   If (Length(FN) > 0) And (FN[Length(FN)] <> '\') Then FN := FN + '\';
   FN := FN + Sel;
  End;
  ResultVal := True;
  Done := True;
 End;

 Procedure DoFilterDropdown;
 Var
  DDX1, DDY1, DDX2, DDY2: Integer;
  UpX1, UpY1, UpX2, UpY2: Integer;
  DnX1, DnY1, DnX2, DnY2: Integer;
  SbX1, SbX2, SbTop, SbBot: Integer;
  ThY1, ThY2: Integer;
  TopF, SelF, VisRows: Integer;
  DDone: Boolean; Ch2: Char;
  DMX, DMY, DMB, DOldMB: Integer;
  Idx2: Integer;

  Procedure DrawDD;
  Var Q, II, RowY: Integer;
  Begin
   HideMouseCursor;
   FillRect(DDX1, DDY1, DDX2, DDY2, White);
   DrawBevel(DDX1, DDY1, DDX2, DDY2, False);
   FillRect(UpX1+1, UpY1+1, UpX2-1, UpY2-1, UI_BG_PANEL);
   DrawBevel(UpX1, UpY1, UpX2, UpY2, True);
   SetColor(UI_TEXT);
   Line(UpX1+6, UpY1+3, UpX1+2, UpY1+8);
   Line(UpX1+6, UpY1+3, UpX1+10, UpY1+8);
   Line(UpX1+2, UpY1+8, UpX1+10, UpY1+8);
   FillRect(DnX1+1, DnY1+1, DnX2-1, DnY2-1, UI_BG_PANEL);
   DrawBevel(DnX1, DnY1, DnX2, DnY2, True);
   Line(DnX1+2, DnY1+3, DnX1+10, DnY1+3);
   Line(DnX1+2, DnY1+3, DnX1+6, DnY1+8);
   Line(DnX1+10, DnY1+3, DnX1+6, DnY1+8);
   FillRect(SbX1, SbTop, SbX2, SbBot, DarkGray);
   If FD_NUM_FILTERS > VisRows Then Begin
    ThY1 := SbTop + (LongInt(TopF) * (SbBot-SbTop)) Div FD_NUM_FILTERS;
    ThY2 := SbTop + (LongInt(TopF+VisRows) * (SbBot-SbTop)) Div FD_NUM_FILTERS;
    If ThY2-ThY1 < 8 Then ThY2 := ThY1+8;
    If ThY2 > SbBot Then ThY2 := SbBot;
    FillRect(SbX1, ThY1, SbX2, ThY2, UI_BG_PANEL);
    DrawBevel(SbX1, ThY1, SbX2, ThY2, True);
   End Else FillRect(SbX1, SbTop, SbX2, SbBot, UI_BG_PANEL);
   For Q:=0 To VisRows-1 Do Begin
    II := TopF + Q;
    If II >= FD_NUM_FILTERS Then Break;
    RowY := DDY1+2 + Q*FD_ROWH;
    If II = SelF Then Begin
     FillRect(DDX1+1, RowY-1, SbX1-1, RowY+FD_ROWH-2, Blue);
     SetColor(UI_TEXT_LITE);
    End Else SetColor(UI_TEXT);
    OutTextXY(DDX1+4, RowY, FD_FILTER_LABELS[II]);
   End;
   ShowMouseCursor;
  End;

 Begin
  SelF := FD_FilterIdx;
  VisRows := FD_NUM_FILTERS; If VisRows > 6 Then VisRows := 6;
  DDX1 := TypX1; DDY1 := NamY2+1;
  DDX2 := TypX2; DDY2 := DDY1 + VisRows*FD_ROWH + 4;
  SbX2 := DDX2-2; SbX1 := SbX2-10;
  UpX1 := SbX1; UpY1 := DDY1+1; UpX2 := SbX2; UpY2 := UpY1+11;
  DnX1 := SbX1; DnY2 := DDY2-1; DnX2 := SbX2; DnY1 := DnY2-11;
  SbTop := UpY2+1; SbBot := DnY1-1;
  TopF := 0; If SelF >= VisRows Then TopF := SelF - VisRows + 1;
  DrawDD;
  Repeat GetMouseStateLocal(DMX, DMY, DMB); Until DMB And 1 = 0;
  DOldMB := 0; DDone := False;
  Repeat
   If KeyPressed Then Begin
    Ch2 := ReadKey;
    If Ch2 = #0 Then Begin
     Ch2 := ReadKey;
     Case Ch2 Of
      #72: If SelF > 0 Then Begin Dec(SelF); If SelF < TopF Then TopF := SelF; DrawDD; End;
      #80: If SelF < FD_NUM_FILTERS-1 Then Begin Inc(SelF);
            If SelF >= TopF+VisRows Then TopF := SelF-VisRows+1; DrawDD; End;
      #71: Begin SelF := 0; TopF := 0; DrawDD; End;
      #79: Begin SelF := FD_NUM_FILTERS-1;
            If SelF >= VisRows Then TopF := SelF-VisRows+1; DrawDD; End;
     End;
    End Else Begin
     Case Ch2 Of
      #27: DDone := True;
      #13: Begin FD_FilterIdx := SelF; FD_Scan; DDone := True; End;
     End;
    End;
   End;
   GetMouseStateLocal(DMX, DMY, DMB);
   If (DOldMB And 1 = 0) And (DMB And 1 <> 0) Then Begin
    If (DMX < DDX1) Or (DMX > DDX2) Or (DMY < DDY1) Or (DMY > DDY2) Then DDone := True
    Else If (DMX>=UpX1) And (DMX<=UpX2) And (DMY>=UpY1) And (DMY<=UpY2) Then Begin
     If TopF > 0 Then Begin Dec(TopF); DrawDD; End;
    End Else If (DMX>=DnX1) And (DMX<=DnX2) And (DMY>=DnY1) And (DMY<=DnY2) Then Begin
     If TopF < FD_NUM_FILTERS - VisRows Then Begin Inc(TopF); DrawDD; End;
    End Else If (DMX>=SbX1) And (DMX<=SbX2) And (DMY>=SbTop) And (DMY<=SbBot) Then Begin
     TopF := (LongInt(DMY-SbTop) * FD_NUM_FILTERS) Div (SbBot-SbTop) - VisRows Div 2;
     If TopF < 0 Then TopF := 0;
     If TopF > FD_NUM_FILTERS - VisRows Then TopF := FD_NUM_FILTERS - VisRows;
     DrawDD;
    End Else Begin
     Idx2 := TopF + (DMY - DDY1 - 2) Div FD_ROWH;
     If (Idx2 >= 0) And (Idx2 < FD_NUM_FILTERS) Then Begin
      If Idx2 = SelF Then Begin FD_FilterIdx := SelF; FD_Scan; DDone := True; End
      Else Begin SelF := Idx2; DrawDD; End;
     End;
    End;
   End;
   DOldMB := DMB;
  Until DDone;
  Repeat GetMouseStateLocal(DMX, DMY, DMB); Until DMB And 1 = 0;
  RedrawAll;
 End;

Begin
 FD_Open := False;
 FD_FilterIdx := 0;
 FD_NameBuf := '';
 FD_Focus := 1;
 FD_SelDir := 0; FD_SelFile := 0;
 FD_Scan;
 DX1 := (ScreenWidth - 600) Div 2; If DX1<0 Then DX1:=0;
 DY1 := (ScreenHeight - 420) Div 2; If DY1<0 Then DY1:=0;
 DX2 := DX1 + 600; DY2 := DY1 + 420;
 DirX1:=DX1+5;   DirY1:=DY1+50; DirX2:=DX1+165; DirY2:=DY2-82;
 FilX1:=DX1+170; FilY1:=DY1+50; FilX2:=DX2-5;   FilY2:=DY2-82;
 NamX1:=DX1+50;  NamY1:=DY2-76; NamX2:=DX2-220; NamY2:=DY2-60;
 TypX1:=DX2-175; TypX2:=DX2-10;
 OkX1:=DX2-180; OkY1:=DY2-50; OkX2:=DX2-100; OkY2:=DY2-32;
 CcX1:=DX2-90;  CcY1:=DY2-50; CcX2:=DX2-10;  CcY2:=DY2-32;
 DirRows  := (DirY2 - DirY1 - 2) Div FD_ROWH;
 FileRows := (FilY2 - FilY1 - 2) Div FD_ROWH;
 RedrawAll;
 While KeyPressed Do ReadKey;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 Done := False; ResultVal := False; OldMB := 0;
 Repeat
  If KeyPressed Then Begin
   Ch := ReadKey;
   If Ch = #0 Then Begin
    Ch := ReadKey;
    Case Ch Of
     #72: Begin
      If FD_Focus = 0 Then Begin If FD_SelDir > 0 Then Dec(FD_SelDir);
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows); End
      Else If FD_Focus = 1 Then Begin If FD_SelFile > 0 Then Dec(FD_SelFile);
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
       If FD_SelFile < FD_NFiles Then FD_NameBuf := FD_Files[FD_SelFile].Name; End;
      RedrawAll;
     End;
     #80: Begin
      If FD_Focus = 0 Then Begin If FD_SelDir < FD_NDirs-1 Then Inc(FD_SelDir);
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows); End
      Else If FD_Focus = 1 Then Begin If FD_SelFile < FD_NFiles-1 Then Inc(FD_SelFile);
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
       If FD_SelFile < FD_NFiles Then FD_NameBuf := FD_Files[FD_SelFile].Name; End;
      RedrawAll;
     End;
     #73: Begin
      If FD_Focus = 0 Then Begin Dec(FD_SelDir, DirRows); If FD_SelDir < 0 Then FD_SelDir := 0;
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows); End
      Else If FD_Focus = 1 Then Begin Dec(FD_SelFile, FileRows); If FD_SelFile < 0 Then FD_SelFile := 0;
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows); End;
      RedrawAll;
     End;
     #81: Begin
      If FD_Focus = 0 Then Begin Inc(FD_SelDir, DirRows); If FD_SelDir >= FD_NDirs Then FD_SelDir := FD_NDirs-1;
       FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows); End
      Else If FD_Focus = 1 Then Begin Inc(FD_SelFile, FileRows); If FD_SelFile >= FD_NFiles Then FD_SelFile := FD_NFiles-1;
       FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows); End;
      RedrawAll;
     End;
     #71: Begin
      If FD_Focus = 0 Then Begin FD_SelDir := 0; FD_TopDir := 0; End
      Else If FD_Focus = 1 Then Begin FD_SelFile := 0; FD_TopFile := 0; End;
      RedrawAll;
     End;
     #79: Begin
      If FD_Focus = 0 Then Begin FD_SelDir := FD_NDirs-1; FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows); End
      Else If FD_Focus = 1 Then Begin FD_SelFile := FD_NFiles-1; FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows); End;
      RedrawAll;
     End;
    End;
   End Else Begin
    Case Ch Of
     #27: Done := True;
     #13: DoActivate;
     #9 : Begin FD_Focus := (FD_Focus + 1) Mod 3; RedrawAll; End;
     #8 : If FD_Focus = 2 Then Begin
           If Length(FD_NameBuf) > 0 Then Delete(FD_NameBuf, Length(FD_NameBuf), 1);
           RedrawAll;
          End;
    Else
     If Ch >= ' ' Then Begin
      If FD_Focus = 2 Then Begin
       If Length(FD_NameBuf) < 60 Then FD_NameBuf := FD_NameBuf + Ch;
       RedrawAll;
      End Else If FD_Focus = 0 Then Begin
       For Idx:=0 To FD_NDirs-1 Do Begin
        Nm := FD_Dirs[Idx].Name;
        If (Length(Nm)>0) And (UpCase(Nm[1])=UpCase(Ch)) Then Begin
         FD_SelDir := Idx;
         FD_EnsureVisible(FD_TopDir, FD_SelDir, DirRows);
         Break;
        End;
       End;
       RedrawAll;
      End Else If FD_Focus = 1 Then Begin
       For Idx:=0 To FD_NFiles-1 Do Begin
        Nm := FD_Files[Idx].Name;
        If (Length(Nm)>0) And (UpCase(Nm[1])=UpCase(Ch)) Then Begin
         FD_SelFile := Idx;
         FD_EnsureVisible(FD_TopFile, FD_SelFile, FileRows);
         FD_NameBuf := Nm;
         Break;
        End;
       End;
       RedrawAll;
      End;
     End;
    End;
   End;
  End;
  GetMouseStateLocal(MX, MY, MB);
  If (OldMB And 1 = 0) And (MB And 1 <> 0) Then Begin
   If (MX>=DirX1) And (MX<=DirX2) And (MY>=DirY1) And (MY<=DirY2) Then Begin
    Idx := FD_TopDir + (MY - DirY1 - 2) Div FD_ROWH;
    If (Idx >= 0) And (Idx < FD_NDirs) Then Begin
     FD_SelDir := Idx; FD_Focus := 0; RedrawAll; DoActivate;
    End Else Begin FD_Focus := 0; RedrawAll; End;
   End
   Else If (MX>=FilX1) And (MX<=FilX2) And (MY>=FilY1) And (MY<=FilY2) Then Begin
    Idx := FD_TopFile + (MY - FilY1 - 2) Div FD_ROWH;
    If (Idx >= 0) And (Idx < FD_NFiles) Then Begin
     If (FD_Focus = 1) And (Idx = FD_SelFile) Then Begin
      FD_NameBuf := FD_Files[Idx].Name; DoActivate;
     End Else Begin
      FD_SelFile := Idx; FD_Focus := 1;
      FD_NameBuf := FD_Files[Idx].Name;
      RedrawAll;
     End;
    End Else Begin FD_Focus := 1; RedrawAll; End;
   End
   Else If (MX>=NamX1) And (MX<=NamX2) And (MY>=NamY1) And (MY<=NamY2) Then Begin
    FD_Focus := 2; RedrawAll;
   End
   Else If (MX>=TypX1) And (MX<=TypX2) And (MY>=NamY1) And (MY<=NamY2) Then Begin
    DoFilterDropdown;
   End
   Else If (MX>=OkX1) And (MX<=OkX2) And (MY>=OkY1) And (MY<=OkY2) Then DoActivate
   Else If (MX>=CcX1) And (MX<=CcX2) And (MY>=CcY1) And (MY<=CcY2) Then Done := True;
  End;
  OldMB := MB;
 Until Done;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 MouseButtons := 0; OldMouseButtons := 0;
 DrawFullUI;
 FD_Open := ResultVal;
End;

Procedure OpenFileAction;
Var FN, Ext: String; Loaded: Boolean;
Begin
 FN := '';
 Loaded := False;
 If FD_Open('Ouvrir un fichier', FN) Then Begin
  Ext := ExtractExt(FN);
  If (Ext='.BMP') Or (Ext='.DIB') Then Begin
   If LoadBMP(FN) Then Loaded := True
   Else ShowDialog('Erreur', 'Impossible de charger : '+FN);
  End
  Else If Ext='.GIF' Then Begin
   If LoadGIF(FN) Then Loaded := True
   Else ShowDialog('Erreur', 'Impossible de charger : '+FN);
  End
  Else If (Ext='.JPG') Or (Ext='.JPEG') Then Begin
   If LoadJPEG(FN) Then Loaded := True
   Else ShowDialog('Erreur', 'Impossible de charger : '+FN);
  End
  Else If Ext='.PNG' Then Begin
   If LoadPNG(FN) Then Loaded := True
   Else ShowDialog('Erreur', 'Impossible de charger : '+FN);
  End
  Else If Ext='.PCX' Then Begin
   If LoadPCX(FN) Then Loaded := True
   Else ShowDialog('Erreur', 'Impossible de charger : '+FN);
  End
  Else If Ext='.PSD' Then Begin
   If LoadPSD(FN) Then Loaded := True
   Else ShowDialog('Erreur', 'Impossible de charger : '+FN);
  End
  Else If (Ext='.TGA') Or (Ext='.TIF') Or (Ext='.TIFF') Then
   ShowDialog('Format non supporte', 'Le decodage '+Ext+' n est pas encore implemente.')
  Else
   ShowDialog('Format inconnu', 'Extension '+Ext+' non reconnue.');
  If Loaded Then Begin
   FI_ResetMetadata;
   FI_LoadSidecar(FN);
  End;
 End;
End;

Function ImportBMPAsLayer(Const FileName: String): Boolean;
Var
 F: File;
 FH: TBMPFileHeader;
 IH: TBMPInfoHeader;
 BytesRead: Word;
 RowSize, X, Y, SrcY, DstY, I, Best, NewIdx: Integer;
 SrcW, SrcH: Integer;
 RowBuf: Array[0..4095] of Byte;
 R, G, B: Byte;
 DR, DG, DB, Dist, BestDist: LongInt;
 BMPPal: Array[0..255] of TRGBQuad;
 PalRemap: Array[0..255] of Byte;
 PaletteEntries: Integer;
 V: Byte;
 BitPos: Integer;
 ByteVal: Byte;
 LayerName: String;
Begin
 ImportBMPAsLayer := False;
 If LayerCount>=MAX_LAYERS Then Begin
  ShowDialog('Importer', 'Nombre maximum de calques atteint.');
  Exit;
 End;
 Assign(F, FileName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult<>0 Then Exit;
 BlockRead(F, FH, SizeOf(FH), BytesRead);
 If (BytesRead<>SizeOf(FH)) Or (FH.bfType<>BMP_SIGNATURE) Then Begin Close(F); Exit; End;
 BlockRead(F, IH, SizeOf(IH), BytesRead);
 If BytesRead<>SizeOf(IH) Then Begin Close(F); Exit; End;

 SrcW := IH.biWidth;
 SrcH := Abs(IH.biHeight);
 RowSize := ((LongInt(SrcW) * IH.biBitCount + 31) Div 32) * 4;

 If IH.biBitCount<=8 Then Begin
  If IH.biClrUsed>0 Then PaletteEntries := IH.biClrUsed
                    Else PaletteEntries := 1 Shl IH.biBitCount;
  BlockRead(F, BMPPal, PaletteEntries*4, BytesRead);
  For X:=0 To PaletteEntries-1 Do Begin
   Best := 0; BestDist := MaxLongInt;
   For I:=0 To 15 Do Begin
    DR := LongInt(BMPPal[X].Red) - VGA_R[I];
    DG := LongInt(BMPPal[X].Green) - VGA_G[I];
    DB := LongInt(BMPPal[X].Blue) - VGA_B[I];
    Dist := DR*DR + DG*DG + DB*DB;
    If Dist<BestDist Then Begin BestDist:=Dist; Best:=I; End;
   End;
   PalRemap[X] := Byte(Best);
  End;
  For X:=PaletteEntries To 255 Do PalRemap[X]:=0;
 End;

 Seek(F, FH.bfOffBits);

 NewIdx := LayerCount;
 LayerName := 'Import';
 AllocLayer(NewIdx, LayerName, True);
 Inc(LayerCount);
 ActiveLayer := NewIdx;

 For Y:=0 To SrcH-1 Do Begin
  If IH.biHeight<0 Then SrcY := Y Else SrcY := SrcH-1-Y;
  BlockRead(F, RowBuf, RowSize, BytesRead);
  If BytesRead<>RowSize Then Break;
  DstY := SrcY;
  If (DstY<0) Or (DstY>=ImgH) Then Continue;
  For X:=0 To SrcW-1 Do Begin
   If X>=ImgW Then Break;
   V := 0;
   Case IH.biBitCount Of
    1: Begin
     ByteVal := RowBuf[X Div 8];
     BitPos := 7 - (X Mod 8);
     V := PalRemap[(ByteVal Shr BitPos) And 1];
    End;
    4: Begin
     ByteVal := RowBuf[X Div 2];
     If (X And 1)=0 Then V := PalRemap[(ByteVal Shr 4) And 15]
                    Else V := PalRemap[ByteVal And 15];
    End;
    8: V := PalRemap[RowBuf[X]];
    24: Begin
     B := RowBuf[X*3]; G := RowBuf[X*3+1]; R := RowBuf[X*3+2];
     Best := 0; BestDist := MaxLongInt;
     For I:=0 To 15 Do Begin
      DR := LongInt(R) - VGA_R[I];
      DG := LongInt(G) - VGA_G[I];
      DB := LongInt(B) - VGA_B[I];
      Dist := DR*DR + DG*DG + DB*DB;
      If Dist<BestDist Then Begin BestDist:=Dist; Best:=I; End;
     End;
     V := Byte(Best);
    End;
   End;
   SetLayerPixel(NewIdx, X, DstY, V);
  End;
 End;

 Close(F);
 ImageModified := True;
 ImportBMPAsLayer := True;
End;

Procedure ImportAction;
Var FN: String;
Begin
 FN := '';
 If FD_Open('Importer un fichier', FN) Then Begin
  If Not ImportBMPAsLayer(FN) Then
   ShowDialog('Erreur', 'Echec de l import : '+FN);
 End;
End;

Procedure SaveAsAction;
Var FN: String;
Begin
 FN := CurrentFileName;
 If FN='' Then FN := 'image.bmp';
 If PromptStr('Enregistrer sous', 'Nom du fichier .BMP :', FN) Then Begin
  If ExtractExt(FN)='' Then FN := FN + '.bmp';
  If SaveBMP24(FN) Then Begin
   CurrentFileName := FN;
   ImageModified := False;
   FI_SaveSidecar(FN);
  End Else
   ShowDialog('Erreur', 'Echec de sauvegarde.');
 End;
End;

Procedure SaveAction;
Begin
 If CurrentFileName='' Then SaveAsAction
 Else If SaveBMP24(CurrentFileName) Then Begin
  ImageModified := False;
  FI_SaveSidecar(CurrentFileName);
 End
 Else ShowDialog('Erreur', 'Echec de sauvegarde.');
End;

Procedure SelectAll;
Begin
 SelectionActive := True;
 SelectionRect.L := 0; SelectionRect.T := 0;
 SelectionRect.R := ImgW-1; SelectionRect.B := ImgH-1;
End;

Procedure Deselect;
Begin SelectionActive := False; End;

Procedure CloseAction;
Var K: Integer;
Begin
 If ImageModified Then
  ShowDialog('Fermer', 'Document modifie - changements perdus.');
 For K := 0 To MAX_LAYERS-1 Do
  If Layers[K].Used Then FreeLayer(K);
 LayerCount := 0; ActiveLayer := 0;
 ImgW := 800; ImgH := 600;
 AllocLayer(0, 'Arriere-plan', False);
 LayerCount := 1; ActiveLayer := 0;
 CurrentFileName := '';
 ImageModified := False;
End;

Procedure CloseAllAction;
Begin
 CloseAction;
End;

Procedure RevertAction;
Begin
 If CurrentFileName='' Then Begin
  ShowDialog('Revenir', 'Aucun fichier de reference.'); Exit;
 End;
 ShowDialog('Revenir', 'Rechargement depuis : '+CurrentFileName);
End;

Procedure OpenAsAction;
Begin
 OpenFileAction;
End;

Procedure OpenRecentAction;
Begin
 If CurrentFileName='' Then
  ShowDialog('Ouvrir recent', 'Aucun fichier recent.')
 Else
  ShowDialog('Ouvrir recent', CurrentFileName);
End;

Procedure ExportAction;
Begin
 ShowDialog('Exporter', 'Exportation non implementee.');
End;

Procedure GenerateAction;
Begin
 ShowDialog('Generer', 'Generation d''actifs non implementee.');
End;

Procedure ScriptsAction;
Begin
 ShowDialog('Scripts', 'Execution de scripts non implementee.');
End;

Procedure AutomateAction;
Begin
 ShowDialog('Automatiser', 'Automatisation non implementee.');
End;

Procedure FileInfoAction;
Begin
 If FI_Run Then
  If FIDirty Then ImageModified := True;
End;

Procedure PrintAction;
Begin
 ShowDialog('Imprimer', 'Impression non implementee.');
End;

Procedure PrintOneCopyAction;
Begin
 ShowDialog('Imprimer une copie', 'Impression non implementee.');
End;

Procedure HandleMenuClick(MIdx, IIdx: Integer);
Begin
 MenuActive := False;
 DrawFullUI;
 Case MIdx Of
  MENU_FILE: Case IIdx Of
   0:  Begin NewImage; DrawFullUI; End;
   1:  Begin OpenFileAction; DrawFullUI; End;
   2:  Begin OpenAsAction; DrawFullUI; End;
   3:  Begin OpenRecentAction; DrawFullUI; End;
   5:  Begin CloseAction; DrawFullUI; End;
   6:  Begin CloseAllAction; DrawFullUI; End;
   7:  Begin RevertAction; DrawFullUI; End;
   9:  Begin SaveAction; DrawFullUI; End;
   10: Begin SaveAsAction; DrawFullUI; End;
   12: Begin ImportAction; DrawFullUI; End;
   13: Begin ExportAction; DrawFullUI; End;
   14: Begin GenerateAction; DrawFullUI; End;
   15: Begin ScriptsAction; DrawFullUI; End;
   16: Begin AutomateAction; DrawFullUI; End;
   18: Begin FileInfoAction; DrawFullUI; End;
   20: Begin PrintAction; DrawFullUI; End;
   21: Begin PrintOneCopyAction; DrawFullUI; End;
   23: Running := False;
  End;
  MENU_EDIT: Case IIdx Of
   0: Begin DoUndo; DrawFullUI; End;
   1: ShowDialog('Retablir', 'Refaire non implemente.');
   6: Begin ClearLayer(ActiveLayer, 255); ImageModified:=True; DrawFullUI; End;
  End;
  MENU_IMAGE: Case IIdx Of
   0: ShowDialog('Taille image', 'Largeur:'+IntToStr(ImgW)+' Hauteur:'+IntToStr(ImgH));
   1: Begin RotateLayer90(True); DrawFullUI; End;
   2: Begin RotateLayer90(False); DrawFullUI; End;
   3: Begin FlipH; DrawFullUI; End;
   4: Begin FlipV; DrawFullUI; End;
  End;
  MENU_LAYER: Case IIdx Of
   0: Begin NewLayerAction; DrawFullUI; End;
   1: Begin DuplicateLayerAction; DrawFullUI; End;
   2: Begin DeleteLayerAction; DrawFullUI; End;
   4: Begin FlattenLayers; DrawFullUI; End;
  End;
  MENU_SELECT: Case IIdx Of
   0: Begin SelectAll; DrawFullUI; End;
   1: Begin Deselect; DrawFullUI; End;
  End;
  MENU_FILTER: Case IIdx Of
   0: Begin FilterInvert; DrawFullUI; End;
   1: Begin FilterGray; DrawFullUI; End;
   2: Begin FilterBrighter; DrawFullUI; End;
   3: Begin FilterDarker; DrawFullUI; End;
   4: Begin FilterBlur; DrawFullUI; End;
   5: Begin FilterSharpen; DrawFullUI; End;
  End;
  MENU_VIEW: Case IIdx Of
   0: Begin If ZoomLevel<400 Then ZoomLevel := ZoomLevel + 50; DrawFullUI; End;
   1: Begin If ZoomLevel>50 Then ZoomLevel := ZoomLevel - 50; DrawFullUI; End;
   2: Begin ZoomLevel := 100; DrawFullUI; End;
  End;
  MENU_HELP: Case IIdx Of
   0: ShowDialog('A propos', 'PSP - Clone Photoshop v1.0 - 2026');
   1: ShowDialog('Raccourcis', 'V/M/B/E/G/K/T/Z - Outils. Ctrl+S/O/N/Z.');
  End;
 End;
End;

Function MenuDropdownWidth(MIdx: Integer): Integer;
Var I, CapLen, ScLen, MaxCap, MaxSc, W: Integer;
Begin
 MaxCap := 0; MaxSc := 0;
 For I:=0 To Menus[MIdx].ItemCount-1 Do Begin
  If Menus[MIdx].Items[I].Separator Then Continue;
  CapLen := Length(Menus[MIdx].Items[I].Caption);
  ScLen  := Length(Menus[MIdx].Items[I].Shortcut);
  If CapLen>MaxCap Then MaxCap := CapLen;
  If ScLen >MaxSc  Then MaxSc  := ScLen;
 End;
 W := 8 + MaxCap*8 + 16;
 If MaxSc>0 Then W := W + MaxSc*8 + 8;
 If W<120 Then W := 120;
 MenuDropdownWidth := W;
End;

Procedure DrawMenuDropdown(MIdx: Integer);
Var
 X1, Y1, X2, Y2, ItemY, I, W, ScW: Integer;
Begin
 W := MenuDropdownWidth(MIdx);
 X1 := Menus[MIdx].X;
 If X1 + W >= ScreenWidth Then X1 := ScreenWidth - W - 1;
 Y1 := MENUBAR_HEIGHT;
 X2 := X1 + W;
 Y2 := Y1 + Menus[MIdx].ItemCount*16 + 4;
 HideMouseCursor;
 FillRect(X1, Y1, X2, Y2, UI_BG_PANEL);
 DrawBevel(X1, Y1, X2, Y2, True);
 ItemY := Y1 + 3;
 For I:=0 To Menus[MIdx].ItemCount-1 Do Begin
  If Menus[MIdx].Items[I].Separator Then Begin
   SetColor(UI_SHADOW);
   Line(X1+4, ItemY+6, X2-4, ItemY+6);
  End Else Begin
   If I=ActiveMenuItem Then Begin
    FillRect(X1+1, ItemY-1, X2-1, ItemY+13, UI_ACCENT);
    SetColor(UI_TEXT_LITE);
   End Else
    SetColor(UI_TEXT);
   OutTextXY(X1+8, ItemY+2, Menus[MIdx].Items[I].Caption);
   If Menus[MIdx].Items[I].Shortcut<>'' Then Begin
    ScW := Length(Menus[MIdx].Items[I].Shortcut)*8;
    OutTextXY(X2-ScW-8, ItemY+2, Menus[MIdx].Items[I].Shortcut);
   End;
  End;
  ItemY := ItemY + 16;
 End;
 ShowMouseCursor;
End;

Function MenuItemHitTest(MX, MY: Integer): Integer;
Var I, Y, W, X1: Integer;
Begin
 MenuItemHitTest := -1;
 If Not MenuActive Then Exit;
 W := MenuDropdownWidth(ActiveMenu);
 X1 := Menus[ActiveMenu].X;
 If X1 + W >= ScreenWidth Then X1 := ScreenWidth - W - 1;
 If MX<X1 Then Exit;
 If MX>X1+W Then Exit;
 Y := MENUBAR_HEIGHT + 3;
 For I:=0 To Menus[ActiveMenu].ItemCount-1 Do Begin
  If Menus[ActiveMenu].Items[I].Separator Then Begin
   Y := Y + 16; Continue;
  End;
  If (MY>=Y-1) And (MY<Y+13) Then Begin
   MenuItemHitTest := I; Exit;
  End;
  Y := Y + 16;
 End;
End;

Function MenuBarHitTest(MX, MY: Integer): Integer;
Var I: Integer;
Begin
 MenuBarHitTest := -1;
 If (MY<0) Or (MY>=MENUBAR_HEIGHT) Then Exit;
 For I:=0 To NUM_MENUS-1 Do
  If (MX>=Menus[I].X-2) And (MX<Menus[I].X+Menus[I].Width-4) Then Begin
   MenuBarHitTest := I; Exit;
  End;
End;

Function ToolHitTest(MX, MY: Integer): Integer;
Var I, Col, Row, X, Y: Integer;
Begin
 ToolHitTest := -1;
 For I:=0 To MAX_TOOLS-1 Do Begin
  Col := I Mod 2;
  Row := I Div 2;
  X := 2 + Col*26;
  Y := MENUBAR_HEIGHT + OPTIONSBAR_H + 4 + Row*26;
  If (MX>=X) And (MX<X+24) And (MY>=Y) And (MY<Y+24) Then Begin
   ToolHitTest := I; Exit;
  End;
 End;
End;

Function SwatchHitTest(MX, MY: Integer): Integer;
Var PX1, PY1, I, X, Y: Integer;
Begin
 SwatchHitTest := -1;
 PX1 := ScreenWidth - LAYERS_WIDTH;
 PY1 := ScreenHeight - STATUSBAR_HEIGHT - 32;
 For I:=0 To 15 Do Begin
  X := PX1 + 4 + (I Mod 8)*12;
  Y := PY1 + (I Div 8)*10;
  If (MX>=X) And (MX<X+10) And (MY>=Y) And (MY<Y+8) Then Begin
   SwatchHitTest := I; Exit;
  End;
 End;
End;

Function LayerHitTest(MX, MY: Integer): Integer;
Var PX1, PY1, PX2, Y, I: Integer;
Begin
 LayerHitTest := -1;
 PX1 := ScreenWidth - LAYERS_WIDTH;
 PY1 := MENUBAR_HEIGHT + OPTIONSBAR_H;
 PX2 := ScreenWidth - 1;
 If (MX<PX1) Or (MX>PX2) Then Exit;
 Y := PY1 + 20;
 For I:=LayerCount-1 DownTo 0 Do Begin
  If (MY>=Y) And (MY<Y+18) Then Begin
   LayerHitTest := I; Exit;
  End;
  Y := Y + 20;
 End;
End;

Procedure MenuSwitch(NewMenu: Integer);
Begin
 If (NewMenu<0) Or (NewMenu>=NUM_MENUS) Then Exit;
 If NewMenu=ActiveMenu Then Exit;
 ActiveMenu := NewMenu;
 ActiveMenuItem := -1;
 DrawFullUI;
 DrawMenuDropdown(ActiveMenu);
End;

Procedure MenuNextItem(Step: Integer);
Var N, I: Integer;
Begin
 If (ActiveMenu<0) Or (ActiveMenu>=NUM_MENUS) Then Exit;
 N := Menus[ActiveMenu].ItemCount;
 If N<=0 Then Exit;
 If ActiveMenuItem<0 Then Begin
  If Step>0 Then ActiveMenuItem := -1
            Else ActiveMenuItem := N;
 End;
 For I:=1 To N Do Begin
  ActiveMenuItem := ActiveMenuItem + Step;
  If ActiveMenuItem<0 Then ActiveMenuItem := N-1;
  If ActiveMenuItem>=N Then ActiveMenuItem := 0;
  If Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator Then Exit;
 End;
End;

{ ============================================================
   Gestion souris : clic/drag/release
  ============================================================ }

Procedure RubberBandDraw(X1, Y1, X2, Y2, ToolKind: Integer);
Var L, T, R, B, CX, CY, RX, RY: Integer;
Begin
 SetWriteMode(XORPut);
 SetLineStyle(DottedLn, 0, NormWidth);
 SetColor(White);
 Case ToolKind Of
  TOOL_LINE: Line(X1, Y1, X2, Y2);
  TOOL_RECT, TOOL_SHAPE, TOOL_MARQUEE: Begin
   L := Min(X1, X2); T := Min(Y1, Y2);
   R := Max(X1, X2); B := Max(Y1, Y2);
   Rectangle(L, T, R, B);
  End;
  TOOL_ELLIPSE: Begin
   CX := (X1 + X2) Div 2; CY := (Y1 + Y2) Div 2;
   RX := Abs(X2 - X1) Div 2; RY := Abs(Y2 - Y1) Div 2;
   If RX < 1 Then RX := 1;
   If RY < 1 Then RY := 1;
   Ellipse(CX, CY, 0, 360, RX, RY);
  End;
 End;
 SetWriteMode(NormalPut);
 SetLineStyle(SolidLn, 0, NormWidth);
End;

Procedure ClearRubberBand;
Begin
 If Not PreviewActive Then Exit;
 HideMouseCursor;
 RubberBandDraw(PrevX1, PrevY1, PrevX2, PrevY2, PrevTool);
 ShowMouseCursor;
 PreviewActive := False;
End;

Procedure HandleCanvasPress(SX, SY: Integer);
Var IX, IY: Integer;
Begin
 If Not ScreenToImg(SX, SY, IX, IY) Then Exit;
 StartX := IX; StartY := IY;
 EndX := IX; EndY := IY;
 Drawing := True;
 Case CurrentTool Of
  TOOL_PENCIL: Begin PushUndo; DrawWithPencil(IX, IY, FgColor); End;
  TOOL_BRUSH: Begin PushUndo; DrawWithBrush(IX, IY, FgColor); End;
  TOOL_ERASER: Begin PushUndo; EraseAt(IX, IY); End;
  TOOL_FILL: Begin PushUndo; FloodFill(IX, IY, FgColor); RefreshCanvas; End;
  TOOL_PICKER: Begin
   FgColor := Composite(IX, IY);
   If FgColor=255 Then FgColor := White;
   DrawColorSwatchBox; DrawOptionsBar;
   Drawing := False;
  End;
  TOOL_ZOOM: Begin
   If ZoomLevel<400 Then ZoomLevel := ZoomLevel + 50;
   DrawFullUI;
   Drawing := False;
  End;
  TOOL_LINE, TOOL_RECT, TOOL_ELLIPSE, TOOL_SHAPE, TOOL_MARQUEE: Begin
   PushUndo;
   PreviewActive := False;
  End;
 End;
End;

Procedure HandleCanvasDrag(SX, SY: Integer);
Var IX, IY, SX1, SY1, SX2, SY2: Integer;
Begin
 If Not Drawing Then Exit;
 If Not ScreenToImg(SX, SY, IX, IY) Then Exit;
 EndX := IX; EndY := IY;
 HideMouseCursor;
 BatchDrawing := True;
 Case CurrentTool Of
  TOOL_PENCIL: Begin
   ImgLine(StartX, StartY, IX, IY, FgColor);
   StartX := IX; StartY := IY;
  End;
  TOOL_BRUSH: Begin
   DrawWithBrush(IX, IY, FgColor);
   ImgLine(StartX, StartY, IX, IY, FgColor);
   StartX := IX; StartY := IY;
  End;
  TOOL_ERASER: Begin
   EraseAt(IX, IY);
   StartX := IX; StartY := IY;
  End;
  TOOL_LINE, TOOL_RECT, TOOL_ELLIPSE, TOOL_SHAPE, TOOL_MARQUEE: Begin
   If PreviewActive Then
    RubberBandDraw(PrevX1, PrevY1, PrevX2, PrevY2, PrevTool);
   ImgToScreen(StartX, StartY, SX1, SY1);
   ImgToScreen(IX, IY, SX2, SY2);
   RubberBandDraw(SX1, SY1, SX2, SY2, CurrentTool);
   PrevX1 := SX1; PrevY1 := SY1;
   PrevX2 := SX2; PrevY2 := SY2;
   PrevTool := CurrentTool;
   PreviewActive := True;
  End;
 End;
 BatchDrawing := False;
 ShowMouseCursor;
 DrawStatusBar;
End;

Procedure HandleCanvasRelease(SX, SY: Integer);
Var IX, IY: Integer;
Begin
 If Not Drawing Then Exit;
 If ScreenToImg(SX, SY, IX, IY) Then Begin EndX := IX; EndY := IY; End;
 ClearRubberBand;
 HideMouseCursor;
 BatchDrawing := True;
 Case CurrentTool Of
  TOOL_LINE: ImgLine(StartX, StartY, EndX, EndY, FgColor);
  TOOL_RECT: ImgRect(StartX, StartY, EndX, EndY, FgColor, False);
  TOOL_SHAPE: ImgRect(StartX, StartY, EndX, EndY, FgColor, True);
  TOOL_ELLIPSE: ImgEllipse((StartX+EndX) Div 2, (StartY+EndY) Div 2,
                            Abs(EndX-StartX) Div 2, Abs(EndY-StartY) Div 2, FgColor);
  TOOL_MARQUEE: Begin
   SelectionActive := True;
   SelectionRect.L := Min(StartX, EndX);
   SelectionRect.T := Min(StartY, EndY);
   SelectionRect.R := Max(StartX, EndX);
   SelectionRect.B := Max(StartY, EndY);
  End;
 End;
 BatchDrawing := False;
 ShowMouseCursor;
 Drawing := False;
 DrawStatusBar;
End;

Procedure HandleClick(MX, MY: Integer);
Var MIdx, TIdx, SwIdx, LIdx, IIdx: Integer;
Begin
 If MenuActive Then Begin
  IIdx := MenuItemHitTest(MX, MY);
  If IIdx>=0 Then Begin
   HandleMenuClick(ActiveMenu, IIdx);
   Exit;
  End;
  MIdx := MenuBarHitTest(MX, MY);
  If MIdx>=0 Then Begin
   ActiveMenu := MIdx;
   DrawFullUI;
   DrawMenuDropdown(ActiveMenu);
   Exit;
  End;
  MenuActive := False;
  DrawFullUI;
  Exit;
 End;

 MIdx := MenuBarHitTest(MX, MY);
 If MIdx>=0 Then Begin
  MenuActive := True;
  ActiveMenu := MIdx;
  ActiveMenuItem := -1;
  DrawFullUI;
  DrawMenuDropdown(ActiveMenu);
  Exit;
 End;

 If MX<TOOLBAR_WIDTH Then Begin
  TIdx := ToolHitTest(MX, MY);
  If TIdx>=0 Then Begin
   CurrentTool := TIdx;
   DrawToolbar;
   DrawOptionsBar;
   Exit;
  End;
 End;

 SwIdx := SwatchHitTest(MX, MY);
 If SwIdx>=0 Then Begin
  FgColor := Swatches[SwIdx];
  DrawColorSwatchBox;
  DrawOptionsBar;
  Exit;
 End;

 LIdx := LayerHitTest(MX, MY);
 If LIdx>=0 Then Begin
  ActiveLayer := LIdx;
  DrawLayersPanel;
  DrawStatusBar;
  Exit;
 End;

 If (MX>=CanvasX) And (MY>=CanvasY) And
    (MX<CanvasX+CanvasW) And (MY<CanvasY+CanvasH) Then
  HandleCanvasPress(MX, MY);
End;

Procedure HandleMouseEvent;
Var
 LB, OldLB: Boolean;
 IIdx, BarHit: Integer;
Begin
 OldMouseX := MouseX;
 OldMouseY := MouseY;
 OldMouseButtons := MouseButtons;
 GetMouseStateLocal(MouseX, MouseY, MouseButtons);

 LB := (MouseButtons And 1)<>0;
 OldLB := (OldMouseButtons And 1)<>0;

 If MenuActive And ((MouseX<>OldMouseX) Or (MouseY<>OldMouseY)) Then Begin
  BarHit := MenuBarHitTest(MouseX, MouseY);
  If (BarHit>=0) And (BarHit<>ActiveMenu) Then Begin
   MenuSwitch(BarHit);
  End Else Begin
   IIdx := MenuItemHitTest(MouseX, MouseY);
   If IIdx<>ActiveMenuItem Then Begin
    ActiveMenuItem := IIdx;
    DrawMenuDropdown(ActiveMenu);
   End;
  End;
 End;

 If LB And Not OldLB Then HandleClick(MouseX, MouseY)
 Else If LB And OldLB Then HandleCanvasDrag(MouseX, MouseY)
 Else If OldLB And Not LB Then HandleCanvasRelease(MouseX, MouseY);

 If (MouseX<>OldMouseX) Or (MouseY<>OldMouseY) Then DrawStatusBar;
End;

{ ============================================================
   Clavier
  ============================================================ }

Procedure HandleKey(Ch: Char);
Var Tmp: Byte;
Begin
 Case UpCase(Ch) Of
  'V': Begin CurrentTool := TOOL_MOVE;    DrawToolbar; DrawOptionsBar; End;
  'M': Begin CurrentTool := TOOL_MARQUEE; DrawToolbar; DrawOptionsBar; End;
  'L': Begin CurrentTool := TOOL_LASSO;   DrawToolbar; DrawOptionsBar; End;
  'W': Begin CurrentTool := TOOL_WAND;    DrawToolbar; DrawOptionsBar; End;
  'C': Begin CurrentTool := TOOL_CROP;    DrawToolbar; DrawOptionsBar; End;
  'I': Begin CurrentTool := TOOL_PICKER;  DrawToolbar; DrawOptionsBar; End;
  'B': Begin CurrentTool := TOOL_BRUSH;   DrawToolbar; DrawOptionsBar; End;
  'S': Begin CurrentTool := TOOL_STAMP;   DrawToolbar; DrawOptionsBar; End;
  'Y': Begin CurrentTool := TOOL_HISTBR;  DrawToolbar; DrawOptionsBar; End;
  'E': Begin CurrentTool := TOOL_ERASER;  DrawToolbar; DrawOptionsBar; End;
  'G': Begin CurrentTool := TOOL_GRAD;    DrawToolbar; DrawOptionsBar; End;
  'K': Begin CurrentTool := TOOL_FILL;    DrawToolbar; DrawOptionsBar; End;
  'R': Begin CurrentTool := TOOL_BLUR;    DrawToolbar; DrawOptionsBar; End;
  'O': Begin CurrentTool := TOOL_BURN;    DrawToolbar; DrawOptionsBar; End;
  'P': Begin CurrentTool := TOOL_PEN;     DrawToolbar; DrawOptionsBar; End;
  'T': Begin CurrentTool := TOOL_TEXT;    DrawToolbar; DrawOptionsBar; End;
  'A': Begin CurrentTool := TOOL_PATHSEL; DrawToolbar; DrawOptionsBar; End;
  'U': Begin CurrentTool := TOOL_SHAPE;   DrawToolbar; DrawOptionsBar; End;
  'H': Begin CurrentTool := TOOL_HAND;    DrawToolbar; DrawOptionsBar; End;
  'Z': Begin CurrentTool := TOOL_ZOOM;    DrawToolbar; DrawOptionsBar; End;
  'N': Begin CurrentTool := TOOL_PENCIL;  DrawToolbar; DrawOptionsBar; End;
  '[': Begin If BrushSize>1  Then Dec(BrushSize); DrawOptionsBar; End;
  ']': Begin If BrushSize<32 Then Inc(BrushSize); DrawOptionsBar; End;
  '+', '=': Begin If ZoomLevel<400 Then Begin ZoomLevel:=ZoomLevel+50; DrawFullUI; End; End;
  '-': Begin If ZoomLevel>50 Then Begin ZoomLevel:=ZoomLevel-50; DrawFullUI; End; End;
  'X': Begin Tmp := FgColor; FgColor := BgColor; BgColor := Tmp; DrawColorSwatchBox; End;
  'D': Begin FgColor := Black; BgColor := White; DrawColorSwatchBox; End;
 End;
End;

Procedure HandleKeyboardEvent;
Var Ch, Ch2: Char;
Begin
 If Not KeyPressed Then Exit;
 Ch := ReadKey;
 If Ch=#0 Then Begin
  Ch2 := ReadKey;
  If MenuActive Then Begin
   Case Ch2 Of
    #72: Begin MenuNextItem(-1); DrawMenuDropdown(ActiveMenu); Exit; End;
    #80: Begin MenuNextItem(+1); DrawMenuDropdown(ActiveMenu); Exit; End;
    #75: Begin MenuSwitch((ActiveMenu + NUM_MENUS - 1) Mod NUM_MENUS); Exit; End;
    #77: Begin MenuSwitch((ActiveMenu + 1) Mod NUM_MENUS); Exit; End;
   End;
  End;
  Case Ch2 Of
   #59: ShowDialog('Aide', 'V/M/B/E/G/K - Outils. [ ] - Taille pinceau. + - Zoom.');
   #68: Begin
    MenuActive := True;
    ActiveMenu := MENU_FILE;
    ActiveMenuItem := -1;
    DrawFullUI;
    DrawMenuDropdown(ActiveMenu);
   End;
   #134: Begin RevertAction; DrawFullUI; End;              { F12 }
  End;
  Exit;
 End;
 Case Ch Of
  #27: Begin
   If MenuActive Then Begin MenuActive := False; DrawFullUI; End
   Else Running := False;
  End;
  #13: Begin
   If MenuActive And (ActiveMenuItem>=0) Then
    If Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator Then
     HandleMenuClick(ActiveMenu, ActiveMenuItem);
  End;
  #14: Begin NewImage; DrawFullUI; End;                    { Ctrl+N }
  #15: Begin OpenFileAction; DrawFullUI; End;              { Ctrl+O }
  #19: Begin SaveAction; DrawFullUI; End;                  { Ctrl+S }
  #23: Begin CloseAction; DrawFullUI; End;                 { Ctrl+W }
  #16: Begin PrintAction; DrawFullUI; End;                 { Ctrl+P }
  #17: Running := False;                                   { Ctrl+Q }
  #26: Begin DoUndo; DrawFullUI; End;                      { Ctrl+Z }
  #25: ShowDialog('Retablir', 'Refaire non implemente.');  { Ctrl+Y }
  #24: ShowDialog('Couper', 'Couper non implemente.');     { Ctrl+X }
  #3:  ShowDialog('Copier', 'Copier non implemente.');     { Ctrl+C }
  #22: ShowDialog('Coller', 'Coller non implemente.');     { Ctrl+V }
  #1:  Begin SelectAll; DrawFullUI; End;                   { Ctrl+A }
  #4:  Begin Deselect; DrawFullUI; End;                    { Ctrl+D }
  Else HandleKey(Ch);
 End;
End;

{ ============================================================
   Initialisation / Main loop
  ============================================================ }

Procedure Initialize;
Var I: Integer;
Begin
 InitGraphics;
 InitMouseDriver;
 InitMenus;
 InitTools;
 InitSwatches;
 For I:=0 To MAX_LAYERS-1 Do Begin
  Layers[I].Used := False;
  Layers[I].Pixels := Nil;
 End;
 For I:=0 To MAX_UNDO_LEVELS-1 Do UndoBuffers[I] := Nil;
 UndoCount := 0;
 ImgW := 400; ImgH := 300;
 AllocLayer(0, 'Arriere-plan', False);
 LayerCount := 1;
 ActiveLayer := 0;
 ZoomLevel := 100;
 CurrentTool := TOOL_BRUSH;
 BrushSize := 4;
 FgColor := Black;
 BgColor := White;
 ImageModified := False;
 CurrentFileName := '';
 Running := True;
 MenuActive := False;
 ActiveMenu := -1;
 ActiveMenuItem := -1;
 SelectionActive := False;
 Drawing := False;
 MouseX := 0; MouseY := 0; MouseButtons := 0;
 OldMouseX := 0; OldMouseY := 0; OldMouseButtons := 0;
 DrawFullUI;
End;

Procedure Cleanup;
Var I: Integer; Sz: LongInt;
Begin
 Sz := LongInt(ImgW)*ImgH;
 For I:=0 To MAX_LAYERS-1 Do If Layers[I].Used Then FreeLayer(I);
 For I:=0 To MAX_UNDO_LEVELS-1 Do
  If UndoBuffers[I]<>Nil Then FreeMem(UndoBuffers[I], Sz);
 HideMouseCursor;
 CloseGraph;
End;

Procedure MainLoop;
Begin
 While Running Do Begin
  HandleMouseEvent;
  HandleKeyboardEvent;
 End;
End;

BEGIN
 Initialize;
 MainLoop;
 Cleanup;
END.
