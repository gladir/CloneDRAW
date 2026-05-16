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
  Shortcut: String[10];
  Separator: Boolean;
 End;

 TMenu = Record
  Title: String[12];
  X, Width: Integer;
  ItemCount: Byte;
  Items: Array[0..15] of TMenuItem;
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

 Menus[MENU_FILE].ItemCount := 7;
 SetMenuItem(MENU_FILE, 0, 'Nouveau...',       'Ctrl+N', False);
 SetMenuItem(MENU_FILE, 1, 'Ouvrir...',        'Ctrl+O', False);
 SetMenuItem(MENU_FILE, 2, 'Enregistrer',      'Ctrl+S', False);
 SetMenuItem(MENU_FILE, 3, 'Enregistrer sous', '',       False);
 SetMenuItem(MENU_FILE, 4, '-',                '',       True);
 SetMenuItem(MENU_FILE, 5, 'Importer',         '',       False);
 SetMenuItem(MENU_FILE, 6, 'Quitter',          'Alt+F4', False);

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
End;

{ ============================================================
   Selecteur de fichiers style Photoshop
  ============================================================ }

Const
 FD_MAXENT = 256;
 FD_ROWH   = 10;
 FD_NUM_FILTERS = 9;
 FD_FILTER_LABELS: Array[0..FD_NUM_FILTERS-1] of String[36] = (
  'Tous formats images',
  'BMP (*.BMP;*.DIB)',
  'GIF (*.GIF)',
  'PNG (*.PNG)',
  'JPEG (*.JPG;*.JPEG)',
  'PCX (*.PCX)',
  'TGA (*.TGA)',
  'TIFF (*.TIF;*.TIFF)',
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
                      (E='.TIF') Or (E='.TIFF');
  1: FD_ExtMatches := (E='.BMP') Or (E='.DIB');
  2: FD_ExtMatches := E='.GIF';
  3: FD_ExtMatches := E='.PNG';
  4: FD_ExtMatches := (E='.JPG') Or (E='.JPEG');
  5: FD_ExtMatches := E='.PCX';
  6: FD_ExtMatches := E='.TGA';
  7: FD_ExtMatches := (E='.TIF') Or (E='.TIFF');
  8: FD_ExtMatches := True;
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
     If (FD_Focus = 0) And (Idx = FD_SelDir) Then DoActivate
     Else Begin FD_SelDir := Idx; FD_Focus := 0; RedrawAll; End;
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
Var FN, Ext: String;
Begin
 FN := '';
 If FD_Open('Ouvrir un fichier', FN) Then Begin
  Ext := ExtractExt(FN);
  If (Ext='.BMP') Or (Ext='.DIB') Then Begin
   If Not LoadBMP(FN) Then ShowDialog('Erreur', 'Impossible de charger : '+FN);
  End
  Else If Ext='.GIF' Then Begin
   If Not LoadGIF(FN) Then ShowDialog('Erreur', 'Impossible de charger : '+FN);
  End
  Else If (Ext='.PNG') Or (Ext='.JPG') Or (Ext='.JPEG') Or
          (Ext='.PCX') Or (Ext='.TGA') Or (Ext='.TIF') Or (Ext='.TIFF') Then
   ShowDialog('Format non supporte', 'Le decodage '+Ext+' n est pas encore implemente.')
  Else
   ShowDialog('Format inconnu', 'Extension '+Ext+' non reconnue.');
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
  End Else
   ShowDialog('Erreur', 'Echec de sauvegarde.');
 End;
End;

Procedure SaveAction;
Begin
 If CurrentFileName='' Then SaveAsAction
 Else If SaveBMP24(CurrentFileName) Then ImageModified := False
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

Procedure HandleMenuClick(MIdx, IIdx: Integer);
Begin
 MenuActive := False;
 DrawFullUI;
 Case MIdx Of
  MENU_FILE: Case IIdx Of
   0: Begin NewImage; DrawFullUI; End;
   1: Begin OpenFileAction; DrawFullUI; End;
   2: Begin SaveAction; DrawFullUI; End;
   3: Begin SaveAsAction; DrawFullUI; End;
   5: Begin ImportAction; DrawFullUI; End;
   6: Running := False;
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
