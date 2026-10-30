{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Free Pascal 3.2)
  @description(Clone d'Adobe Illustrator en Turbo Pascal/Free Pascal graphique)

  Prototype incomplet : formes, Bezier, crayon et texte editables.
  Les commandes non implementees sont grisees.
  AI10 est un ancien format prive, PAS un format Adobe Illustrator.
  Import AI classique limite et ancien AI10 prive avec navigateur graphique.
  Enregistrement AI/EPS classique et AI10 prive.
  Restent notamment : AI moderne/PDF, rotation/groupes,
  formatage du texte, calques et historique.
}

Program AdobeIllustrator;

{$A-}
{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$OVERFLOWCHECKS OFF}
 {$R-}
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
 PROGRAM_NAME = 'Adobe Illustrator Clone v1.0';
 
 MENUBAR_HEIGHT = 18;
 TOOLBAR_WIDTH = 48;
 TOOL_BUTTON_LEFT = 8;
 TOOL_BUTTON_WIDTH = 30;
 TOOL_BUTTON_HEIGHT = 23;
 TOOL_BUTTON_STEP = 25;
 TOOLTIP_DELAY = 50; { Centiemes de seconde, comme PAINT.PAS. }
 STATUSBAR_HEIGHT = 20;
 
 COLOR_BG = 7;
 COLOR_TEXT = 0;
 COLOR_HIGHLIGHT = 1;
 COLOR_BORDER = 8;
 COLOR_WINDOW = 15;
 
 TOOL_SELECT = 0;
 TOOL_RECTANGLE = 1;
 TOOL_ELLIPSE = 2;
 TOOL_LINE = 3;
 TOOL_BEZIER = 4;
 TOOL_PENCIL = 5;
 TOOL_PEN = 6;
 TOOL_TEXT = 7;
 TOOL_ZOOM = 8;
 TOOL_HAND = 9;
 MAX_TOOLS = 10;
 
 MENU_FILE = 0;
 MENU_EDIT = 1;
 MENU_VIEW = 2;
 MENU_OBJECT = 3;
 MENU_PATH = 4;
 MENU_TEXT = 5;
 MENU_HELP = 6;
 MAX_MENUS = 7;
 MAX_MENU_ITEMS = 10;
 MENU_ITEM_HEIGHT = 18;
 CMD_NONE = 0;
 CMD_NEW = 1;
 CMD_EXIT = 2;
 CMD_GRID = 3;
 CMD_HELP = 4;
 CMD_SHORTCUTS = 5;
 CMD_ABOUT = 6;
 CMD_RESOURCES = 7;
 CMD_TIPS = 8;
 CMD_ZOOM_IN = 9;
 CMD_ZOOM_OUT = 10;
 CMD_ZOOM_RESET = 11;
 CMD_OPEN = 12;
 CMD_SAVE = 13;
 CMD_SAVE_AS = 14;
 CMD_EXPORT = 15;
 FD_MAX_ENTRIES = 512;
 FD_ROWS = 13;
 ZOOM_LEVELS: Array[0..5] Of Integer = (25,50,100,200,400,800);
 
 OBJ_RECT = 0;
 OBJ_ELLIPSE = 1;
 OBJ_LINE = 2;
 OBJ_PATH = 3;
 OBJ_TEXT = 4;
 OBJ_BEZIER = 5;
 OBJ_FILLED_PATH = 6;
 BEZIER_STEPS = 128;
 MAX_OBJECTS = 100;
 
 MAX_LAYERS = 20;
 MAX_HISTORY = 50;
 
 AI_SIGNATURE = 'AI10';
 AI_VERSION = 100;

Type
 TBounds = Record
  L, T, R, B: Real;
 End;
 TMenuItem = Record
  Caption: String[30];
  Command: Byte;
 End;

 TMenu = Record
  Title: String[15];
  X, TitleWidth, Width, ItemCount: Integer;
  Items: Array[0..MAX_MENU_ITEMS-1] Of TMenuItem;
 End;

 TPoint2D = Record
  X, Y: Real;
  CtrlX1, CtrlY1: Real;
  CtrlX2, CtrlY2: Real;
 End;
 
 TRectVector = Record
  X, Y: Real;
  Width, Height: Real;
  StrokeColor: Byte;
  FillColor: Byte;
  StrokeWidth: Real;
  Selected: Boolean;
 End;
 
 TEllipseVector = Record
  CX, CY: Real;
  RX, RY: Real;
  StrokeColor: Byte;
  FillColor: Byte;
  StrokeWidth: Real;
  Selected: Boolean;
 End;
 
 TLineVector = Record
  X1, Y1, X2, Y2: Real;
  StrokeColor: Byte;
  StrokeWidth: Real;
  Selected: Boolean;
 End;
 
 TPathVector = Record
  Points: Array[0..99] of TPoint2D;
  PointCount: Integer;
  StrokeColor: Byte;
  FillColor: Byte;
  StrokeWidth: Real;
  Closed: Boolean;
  Selected: Boolean;
 End;
 
 TTextVector = Record
  X, Y: Real;
  Text: String[255];
  FontSize: Real;
  Color: Byte;
  Selected: Boolean;
 End;
 
 TGraphicObject = Record
  ObjType: Byte;
  Rectangle: TRectVector;
  Ellipse: TEllipseVector;
  Line: TLineVector;
  Path: TPathVector;
  TextObj: TTextVector;
  LayerIndex: Byte;
  Visible: Boolean;
 End;
 
 TLayer = Record
  Name: String[30];
  Visible: Boolean;
  Locked: Boolean;
  Opacity: Byte;
  BlendMode: Byte;
 End;
 
 THistoryAction = Record
  ActionType: Byte;
  Data: TGraphicObject;
  ObjectIndex: Integer;
 End;
 TFileEntry = Record
  Name: String;
  Size: LongInt;
  Stamp: LongInt;
 End;

Var
 GraphDriver, GraphMode: Integer;
 ScreenWidth, ScreenHeight: Integer;
 Running: Boolean;
 CurrentTool: Byte;
 StrokeColor: Byte;
 FillColor: Byte;
 MouseX, MouseY: Integer;
 MouseButtons: Integer;
 OldMouseX, OldMouseY: Integer;
 OldMouseButtons: Integer;
 Objects: Array[0..MAX_OBJECTS-1] of TGraphicObject;
 ObjectCount: Integer;
 SelectedObject: Integer;
 DrawingMode: Boolean;
 StartX, StartY: Real;
 EndX, EndY: Real;
 History: Array[0..MAX_HISTORY-1] of THistoryAction;
 HistoryCount: Integer;
 UndoPos: Integer;
 CurrentFile: String;
 FileModified: Boolean;
 Layers: Array[0..MAX_LAYERS-1] of TLayer;
 LayerCount: Integer;
 CurrentLayer: Integer;
 MenuActive: Boolean;
 ActiveMenu, ActiveMenuItem: Integer;
 Menus: Array[0..MAX_MENUS-1] Of TMenu;
 MenuMouseDown, NeedsRedraw, GridVisible: Boolean;
 DialogTitle: String[40];
 DialogText: String[65];
 StatusMessage: String[75];
 ToolTipVisible: Boolean;
 ToolTipCandidate: Integer;
 ToolTipStarted: LongInt;
 EditingObject, EditWasModified: Boolean;
 EditHandle: Integer;
 EditOriginal: TGraphicObject;
 EditBounds: TBounds;
 EditX, EditY: Integer;
 PencilActive: Boolean;
 PencilObject: TGraphicObject;
 TextActive: Boolean;
 TextObject: TGraphicObject;
 TextEditIndex, TextCursor: Integer;
 BezierStage: Integer;
 BezierObject: TGraphicObject;
 ZoomIndex: Integer;
 ViewX, ViewY: Real;
 GlyphRows: Array[0..255,0..7] Of Byte;
 Panning: Boolean;
 PanX, PanY: Integer;
 PanViewX, PanViewY: Real;
 ImportObjects: Array[0..MAX_OBJECTS-1] Of TGraphicObject;
 ImportCount: Integer;
 ImportError: String;
 FileDialogActive, FileFilterOpen: Boolean;
 FileDirs, FileEntries: Array[0..FD_MAX_ENTRIES-1] Of TFileEntry;
 FileDirCount, FileEntryCount, FileDirSel, FileSel: Integer;
 FileDirTop, FileTop, FileFocus, FileFilter, FileCursor: Integer;
 FilePath, FileNameInput, FilePathInput, FileDialogError: String;
 FileLastClick: LongInt;
 FileLastList, FileLastIndex: Integer;
 FileReplace: Boolean;
 FileFilterSaved: Integer;
 FileSaveMode, FileOverwrite: Boolean;
 PendingSaveName, SaveError: String;
 CurrentSaveFormat: Integer;
 FileExportMode: Boolean;

Function LoadDocument(Name: String): Boolean; Forward;
 Function SaveDocument(Name: String; Format: Integer): Boolean; Forward;
 Function ExportDocument(Name: String; Format: Integer): Boolean; Forward;
 Procedure RedrawInterface; Forward;

Function OutputExtension(Format: Integer): String;
Begin
 Case Format Of
  0,6: OutputExtension := '.ai';
  1,5: OutputExtension := '.eps';
  2: OutputExtension := '.ai10';
  3: OutputExtension := '.svg';
  4: OutputExtension := '.bmp';
  7: OutputExtension := '.cdr';
  Else OutputExtension := '';
 End;
End;

Function ZoomScale: Real;
Begin
 ZoomScale := ZOOM_LEVELS[ZoomIndex]/100;
End;

Function ScreenX(X: Real): Integer;
Begin
 { Coordonnees locales au viewport de dessin, sans les barres d'interface. }
 ScreenX := Round((X-ViewX)*ZoomScale);
End;

Function ScreenY(Y: Real): Integer;
Begin
 ScreenY := Round((Y-ViewY)*ZoomScale);
End;

Function DocumentX(X: Integer): Integer;
Begin
 DocumentX := Round(ViewX+(X-TOOLBAR_WIDTH)/ZoomScale);
End;

Function DocumentY(Y: Integer): Integer;
Begin
 DocumentY := Round(ViewY+(Y-MENUBAR_HEIGHT)/ZoomScale);
End;

Procedure ResetZoom;
Begin
 ZoomIndex := 2;
 ViewX := 0;
 ViewY := 0;
 StatusMessage := 'Zoom 100 %.';
 NeedsRedraw := True;
End;

Procedure ClampView;
Var VisibleW, VisibleH: Real;
Begin
 VisibleW := (ScreenWidth-TOOLBAR_WIDTH)/ZoomScale;
 VisibleH := (ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT)/ZoomScale;
 If VisibleW >= ScreenWidth-TOOLBAR_WIDTH Then
  ViewX := (ScreenWidth-TOOLBAR_WIDTH-VisibleW)/2
 Else Begin
  If ViewX < 0 Then ViewX := 0;
  If ViewX > ScreenWidth-TOOLBAR_WIDTH-VisibleW Then
   ViewX := ScreenWidth-TOOLBAR_WIDTH-VisibleW;
 End;
 If VisibleH >= ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT Then
  ViewY := (ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-VisibleH)/2
 Else Begin
  If ViewY < 0 Then ViewY := 0;
  If ViewY > ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-VisibleH Then
   ViewY := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-VisibleH;
 End;
End;

Procedure ChangeZoom(Step, X, Y: Integer);
Var PX, PY: Real; S: String;
Begin
 If (ZoomIndex+Step < 0) Or (ZoomIndex+Step > 5) Then Begin
  StatusMessage := 'Limite de zoom atteinte (25 % a 800 %).';
  NeedsRedraw := True;
  Exit;
 End;
 PX := ViewX+(X-TOOLBAR_WIDTH)/ZoomScale;
 PY := ViewY+(Y-MENUBAR_HEIGHT)/ZoomScale;
 Inc(ZoomIndex,Step);
 ViewX := PX-(X-TOOLBAR_WIDTH)/ZoomScale;
 ViewY := PY-(Y-MENUBAR_HEIGHT)/ZoomScale;
 ClampView;
 Str(ZOOM_LEVELS[ZoomIndex],S);
 StatusMessage := 'Zoom '+S+' % : clic gauche = agrandir, droit = reduire.';
 NeedsRedraw := True;
End;

Procedure UpdatePan;
Begin
 ViewX := PanViewX-(MouseX-PanX)/ZoomScale;
 ViewY := PanViewY-(MouseY-PanY)/ZoomScale;
 ClampView;
 NeedsRedraw := True;
End;

Procedure InitMouse;
{$IFNDEF FPC}
Var Regs: Registers;
{$ENDIF}
Begin
{$IFDEF FPC}
 PtcMouse.InitMouse;
{$ELSE}
 Regs.AX := $0000;
 Intr($33, Regs);
{$ENDIF}
End;

Procedure ShowMouse;
{$IFNDEF FPC}
Var Regs: Registers;
{$ENDIF}
Begin
{$IFDEF FPC}
 PtcMouse.ShowMouse;
{$ELSE}
 Regs.AX := $0001;
 Intr($33, Regs);
{$ENDIF}
End;

Procedure HideMouse;
{$IFNDEF FPC}
Var Regs: Registers;
{$ENDIF}
Begin
{$IFDEF FPC}
 PtcMouse.HideMouse;
{$ELSE}
 Regs.AX := $0002;
 Intr($33, Regs);
{$ENDIF}
End;

Procedure GetMouseStateLocal(Var X, Y, Buttons: Integer);
Var
{$IFDEF FPC}
 LX, LY: LongInt;
 LB: LongInt;
{$ELSE}
 Regs: Registers;
{$ENDIF}
Begin
{$IFDEF FPC}
 PtcMouse.GetMouseState(LX, LY, LB);
 X := LX;
 Y := LY;
 Buttons := LB;
{$ELSE}
 Regs.AX := $0003;
 Intr($33, Regs);
 X := Regs.CX;
 Y := Regs.DX;
 Buttons := Regs.BX;
{$ENDIF}
End;

Procedure InitGraphics;
Var C, X, Y: Integer;
Begin
 GraphDriver := VGA;
 GraphMode := VGAHi;
 InitGraph(GraphDriver, GraphMode, '');
 If GraphResult <> grOk Then
 Begin
  Writeln('Erreur graphique');
  Halt(1);
 End;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
 { En mode VGA, SetBkColor remappe la couleur 0 : conserver le noir.
   Les fonds de l'interface sont peints explicitement avec Bar. }
 SetBkColor(COLOR_TEXT);
 ClearDevice;
 SetTextStyle(DefaultFont,HorizDir,1);
 FillChar(GlyphRows,SizeOf(GlyphRows),0);
 For C := 32 To 255 Do Begin
  SetFillStyle(SolidFill,COLOR_TEXT);
  Bar(0,0,7,7);
  SetColor(COLOR_WINDOW);
  OutTextXY(0,0,Chr(C));
  For Y := 0 To 7 Do
   For X := 0 To 7 Do
    If GetPixel(X,Y)=COLOR_WINDOW Then
     GlyphRows[C,Y] := GlyphRows[C,Y] Or (1 Shl X);
 End;
 ClearDevice;
End;

Procedure DrawMenuBar;
Var
 I: Integer;
Begin
 SetFillStyle(SolidFill, COLOR_BG);
 Bar(0, 0, ScreenWidth - 1, MENUBAR_HEIGHT - 1);
 SetColor(COLOR_BORDER);
 Line(0, MENUBAR_HEIGHT - 1, ScreenWidth - 1, MENUBAR_HEIGHT - 1);
 
 For I := 0 To MAX_MENUS-1 Do
 Begin
  If MenuActive And (ActiveMenu = I) Then Begin
   SetFillStyle(SolidFill, COLOR_HIGHLIGHT);
   Bar(Menus[I].X, 1, Menus[I].X+Menus[I].TitleWidth-1,
       MENUBAR_HEIGHT-2);
   SetColor(COLOR_WINDOW);
  End Else SetColor(COLOR_TEXT);
  OutTextXY(Menus[I].X+6, 5, Menus[I].Title);
 End;
End;

Function ToolButtonTop(Index: Integer): Integer;
Begin
 ToolButtonTop := MENUBAR_HEIGHT+5+Index*TOOL_BUTTON_STEP;
End;

Function ToolHitTest(X, Y: Integer): Integer;
Var I: Integer;
Begin
 ToolHitTest := -1;
 If (X < TOOL_BUTTON_LEFT) Or
    (X >= TOOL_BUTTON_LEFT+TOOL_BUTTON_WIDTH) Or
    (Y < ToolButtonTop(0)) Then Exit;
 I := (Y-ToolButtonTop(0)) Div TOOL_BUTTON_STEP;
 If I >= MAX_TOOLS Then Exit;
 If Y < ToolButtonTop(I)+TOOL_BUTTON_HEIGHT Then ToolHitTest := I;
End;

Function ToolTipText(Index: Integer): String;
Var S: String;
Begin
 S := '';
 Case Index Of
  TOOL_SELECT: S := 'Selection (1) - deplacer / poignees pour agrandir';
  TOOL_RECTANGLE: S := 'Rectangle (2) - glisser pour dessiner';
  TOOL_ELLIPSE: S := 'Ellipse / cercle (3) - glisser pour dessiner';
  TOOL_LINE: S := 'Ligne (4) - glisser pour dessiner';
  TOOL_BEZIER: S := 'Bezier (5 / B) - deux ancrages par cliquer-glisser';
  TOOL_PENCIL: S := 'Crayon (6 / N) - tracer a main levee';
  TOOL_PEN: S := 'Plume (7 / P) - courbe par deux cliquer-glisser';
  TOOL_TEXT: S := 'Texte (8 / T) - cliquer puis saisir / modifier';
  TOOL_ZOOM: S := 'Loupe (9 / Z) - gauche : agrandir, droit : reduire';
  TOOL_HAND: S := 'Main (H) - glisser pour deplacer la vue';
 End;
 ToolTipText := S;
End;

Function ToolTipClock: LongInt;
Var H, M, S, HS: Word;
Begin
 GetTime(H, M, S, HS);
 ToolTipClock := ((LongInt(H)*60+M)*60+S)*100+HS;
End;

Procedure ResetToolTip;
Begin
 If ToolTipVisible Then NeedsRedraw := True;
 ToolTipVisible := False;
 ToolTipCandidate := -1;
End;

Procedure UpdateToolTipAt(Now: LongInt);
Var Index: Integer; Elapsed: LongInt;
Begin
 Index := -1;
 If Not FileDialogActive And Not MenuActive And Not DrawingMode And Not TextActive And (DialogTitle = '') And
    (MouseButtons = 0) Then Index := ToolHitTest(MouseX, MouseY);
 If (Index <> ToolTipCandidate) Or (MouseX <> OldMouseX) Or
    (MouseY <> OldMouseY) Then Begin
  ResetToolTip;
  ToolTipCandidate := Index;
  ToolTipStarted := Now;
 End;
 If Index < 0 Then Exit;
 Elapsed := Now-ToolTipStarted;
 If Elapsed < 0 Then Inc(Elapsed, 8640000);
 If Not ToolTipVisible And (Elapsed >= TOOLTIP_DELAY) Then Begin
  ToolTipVisible := True;
  NeedsRedraw := True;
 End;
End;

Procedure DrawToolTip;
Var S: String; X, Y, W, H: Integer;
Begin
 If Not ToolTipVisible Then Exit;
 S := ToolTipText(ToolTipCandidate);
 W := TextWidth(S)+16;
 H := TextHeight(S)+12;
 X := TOOLBAR_WIDTH+6;
 Y := ToolButtonTop(ToolTipCandidate)+TOOL_BUTTON_HEIGHT;
 If X+W+3 >= ScreenWidth Then X := ScreenWidth-W-4;
 If Y+H+3 >= ScreenHeight-STATUSBAR_HEIGHT Then
  Y := ScreenHeight-STATUSBAR_HEIGHT-H-4;
 SetFillStyle(SolidFill, COLOR_BORDER);
 Bar(X+3, Y+3, X+W+3, Y+H+3);
 SetFillStyle(SolidFill, Yellow);
 Bar(X, Y, X+W, Y+H);
 SetColor(COLOR_TEXT);
 Rectangle(X, Y, X+W, Y+H);
 OutTextXY(X+8, Y+6, S);
End;

Procedure DrawToolIcon(X, Y, Index: Integer);
Begin
 Case Index Of
  TOOL_SELECT: Begin
   Line(X+3,Y+1,X+3,Y+15);
   Line(X+3,Y+1,X+13,Y+10);
   Line(X+3,Y+15,X+7,Y+11);
   Line(X+7,Y+11,X+10,Y+17);
   Line(X+10,Y+17,X+13,Y+16);
   Line(X+13,Y+16,X+10,Y+10);
   Line(X+10,Y+10,X+13,Y+10);
  End;
  TOOL_RECTANGLE: Rectangle(X+1,Y+4,X+16,Y+14);
  TOOL_ELLIPSE: Ellipse(X+9,Y+9,0,360,8,6);
  TOOL_LINE: Line(X+1,Y+16,X+17,Y+1);
  TOOL_BEZIER: Begin
   Arc(X+8,Y+9,0,180,6);
   Line(X+2,Y+9,X+2,Y+16);
   Line(X+14,Y+9,X+14,Y+2);
   Rectangle(X,Y+14,X+4,Y+18);
   Rectangle(X+12,Y,X+16,Y+4);
  End;
  TOOL_PENCIL: Begin
   Line(X+2,Y+13,X+13,Y+2);
   Line(X+13,Y+2,X+16,Y+5);
   Line(X+16,Y+5,X+5,Y+16);
   Line(X+5,Y+16,X+1,Y+17);
   Line(X+1,Y+17,X+2,Y+13);
   Line(X+11,Y+4,X+14,Y+7);
  End;
  TOOL_PEN: Begin
   Line(X+9,Y+1,X+2,Y+11);
   Line(X+9,Y+1,X+16,Y+11);
   Line(X+2,Y+11,X+5,Y+16);
   Line(X+16,Y+11,X+13,Y+16);
   Line(X+5,Y+16,X+13,Y+16);
   Line(X+9,Y+1,X+9,Y+10);
   Circle(X+9,Y+11,2);
  End;
  TOOL_TEXT: Begin
   Line(X+2,Y+3,X+16,Y+3);
   Line(X+2,Y+3,X+2,Y+6);
   Line(X+16,Y+3,X+16,Y+6);
   Line(X+9,Y+3,X+9,Y+16);
   Line(X+6,Y+16,X+12,Y+16);
  End;
  TOOL_ZOOM: Begin
   Circle(X+7,Y+7,6);
   Line(X+11,Y+12,X+17,Y+18);
   Line(X+12,Y+11,X+18,Y+17);
  End;
  TOOL_HAND: Begin
   Line(X+5,Y+16,X+1,Y+10);
   Line(X+1,Y+10,X+3,Y+8);
   Line(X+3,Y+8,X+6,Y+11);
   Line(X+6,Y+11,X+6,Y+3);
   Line(X+6,Y+3,X+8,Y+3);
   Line(X+8,Y+3,X+8,Y+8);
   Line(X+8,Y+8,X+8,Y+1);
   Line(X+8,Y+1,X+10,Y+1);
   Line(X+10,Y+1,X+10,Y+8);
   Line(X+10,Y+8,X+12,Y+3);
   Line(X+12,Y+3,X+14,Y+4);
   Line(X+14,Y+4,X+14,Y+9);
   Line(X+14,Y+9,X+16,Y+6);
   Line(X+16,Y+6,X+18,Y+7);
   Line(X+18,Y+7,X+16,Y+16);
   Line(X+16,Y+16,X+5,Y+16);
  End;
 End;
End;

Procedure DrawToolbar;
Var I, X, Y, R, B: Integer;
Begin
 SetFillStyle(SolidFill, COLOR_BG);
 Bar(0, MENUBAR_HEIGHT, TOOLBAR_WIDTH - 1, ScreenHeight - STATUSBAR_HEIGHT - 1);
 SetColor(COLOR_BORDER);
 Line(TOOLBAR_WIDTH - 1, MENUBAR_HEIGHT, TOOLBAR_WIDTH - 1, ScreenHeight - STATUSBAR_HEIGHT - 1);
 
 SetLineStyle(SolidLn, 0, NormWidth);
 X := TOOL_BUTTON_LEFT;
 For I := 0 To MAX_TOOLS-1 Do Begin
  Y := ToolButtonTop(I);
  R := X+TOOL_BUTTON_WIDTH-1;
  B := Y+TOOL_BUTTON_HEIGHT-1;
  If I = CurrentTool Then SetFillStyle(SolidFill, COLOR_HIGHLIGHT)
  Else SetFillStyle(SolidFill, COLOR_BG);
  Bar(X,Y,R,B);
  If I = CurrentTool Then SetColor(COLOR_BORDER)
  Else SetColor(COLOR_WINDOW);
  Line(X,Y,R,Y);
  Line(X,Y,X,B);
  If I = CurrentTool Then SetColor(COLOR_WINDOW)
  Else SetColor(COLOR_BORDER);
  Line(X,B,R,B);
  Line(R,Y,R,B);
  If I = CurrentTool Then SetColor(COLOR_WINDOW)
  Else SetColor(COLOR_TEXT);
  DrawToolIcon(X+6,Y+2,I);
 End;
End;

Procedure DrawStatusBar;
Var S, Z: String;
Begin
 SetFillStyle(SolidFill, COLOR_BG);
 Bar(0, ScreenHeight - STATUSBAR_HEIGHT, ScreenWidth - 1, ScreenHeight - 1);
 SetColor(COLOR_BORDER);
 Line(0, ScreenHeight - STATUSBAR_HEIGHT, ScreenWidth - 1, ScreenHeight - STATUSBAR_HEIGHT);
 
 SetColor(COLOR_TEXT);
 Str(ObjectCount, S);
 Str(ZOOM_LEVELS[ZoomIndex],Z);
 OutTextXY(5, ScreenHeight - STATUSBAR_HEIGHT + 5,
           'Objets: '+S+'  '+Z+'%  '+StatusMessage);
End;

Procedure DrawCanvas;
Var
 X1, Y1: Integer;
Begin
 SetFillStyle(SolidFill, COLOR_BORDER);
 Bar(0,0,ScreenWidth-TOOLBAR_WIDTH-1,
     ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1);
 SetFillStyle(SolidFill,COLOR_WINDOW);
 Bar(ScreenX(0),ScreenY(0),ScreenX(ScreenWidth-TOOLBAR_WIDTH)-1,
     ScreenY(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT)-1);
 If Not GridVisible Then Exit;
 
 SetColor(14);
 X1 := 20;
 While X1 < ScreenWidth-TOOLBAR_WIDTH Do
 Begin
  Line(ScreenX(X1),ScreenY(0),ScreenX(X1),
       ScreenY(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT)-1);
  X1 := X1 + 20;
 End;
 
 Y1 := 20;
 While Y1 < ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT Do
 Begin
  Line(ScreenX(0),ScreenY(Y1),ScreenX(ScreenWidth-TOOLBAR_WIDTH)-1,ScreenY(Y1));
  Y1 := Y1 + 20;
 End;
End;

Function BezierPoint(Obj: TGraphicObject; T: Real): TPoint2D;
Var P: TPoint2D; U: Real;
Begin
 FillChar(P,SizeOf(P),0);
 U := 1-T;
 P.X := U*U*U*Obj.Path.Points[0].X+
        3*U*U*T*Obj.Path.Points[1].X+
        3*U*T*T*Obj.Path.Points[2].X+T*T*T*Obj.Path.Points[3].X;
 P.Y := U*U*U*Obj.Path.Points[0].Y+
        3*U*U*T*Obj.Path.Points[1].Y+
        3*U*T*T*Obj.Path.Points[2].Y+T*T*T*Obj.Path.Points[3].Y;
 BezierPoint := P;
End;

Procedure DrawBezierHandles(Obj: TGraphicObject; Mirrors: Boolean);
Var I, A, C, AX, AY, CX, CY: Integer;
Begin
 SetColor(COLOR_HIGHLIGHT);
 For I := 0 To 1 Do Begin
  A := I*3; C := I+1;
  AX := ScreenX(Obj.Path.Points[A].X);
  AY := ScreenY(Obj.Path.Points[A].Y);
  CX := ScreenX(Obj.Path.Points[C].X);
  CY := ScreenY(Obj.Path.Points[C].Y);
  Line(AX,AY,CX,CY);
  Rectangle(AX-3,AY-3,AX+3,AY+3);
  Circle(CX,CY,3);
  If Mirrors Then Begin
   CX := 2*AX-CX; CY := 2*AY-CY;
   If CX < 0 Then CX := 0;
   If CX >= ScreenWidth-TOOLBAR_WIDTH Then CX := ScreenWidth-TOOLBAR_WIDTH-1;
   If CY < 0 Then CY := 0;
   If CY >= ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT Then
    CY := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1;
   Line(AX,AY,CX,CY);
   Circle(CX,CY,3);
  End;
 End;
End;

Procedure DrawZoomedText(Obj: TGraphicObject);
Var X, Y, L, T, R, B, SX, SY, C: Integer;
Begin
 L := ScreenX(Obj.TextObj.X); T := ScreenY(Obj.TextObj.Y);
 R := ScreenX(Obj.TextObj.X+Length(Obj.TextObj.Text)*8)-1;
 B := ScreenY(Obj.TextObj.Y+8)-1;
 If L < 0 Then L := 0;
 If T < 0 Then T := 0;
 If R >= ScreenWidth-TOOLBAR_WIDTH Then R := ScreenWidth-TOOLBAR_WIDTH-1;
 If B >= ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT Then
  B := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1;
 For Y := T To B Do
  For X := L To R Do Begin
   SX := Trunc(ViewX+(X+0.5)/ZoomScale-Obj.TextObj.X);
   SY := Trunc(ViewY+(Y+0.5)/ZoomScale-Obj.TextObj.Y);
   If (SX >= 0) And (SX < Length(Obj.TextObj.Text)*8) And
      (SY >= 0) And (SY < 8) Then Begin
    C := Ord(Obj.TextObj.Text[SX Div 8+1]);
    If (GlyphRows[C,SY] And (1 Shl (SX Mod 8))) <> 0 Then
     PutPixel(X,Y,Obj.TextObj.Color);
   End;
  End;
End;

Procedure DrawGraphicObject(Obj: TGraphicObject);
Var
 X1, Y1, X2, Y2, I: Integer;
 P, Q: TPoint2D;
 Polygon: Array[0..99] Of PointType;
Begin
 If Not Obj.Visible Then Exit;
 
 Case Obj.ObjType Of
  OBJ_RECT:
  Begin
   X1 := ScreenX(Obj.Rectangle.X);
   Y1 := ScreenY(Obj.Rectangle.Y);
   X2 := ScreenX(Obj.Rectangle.X+Obj.Rectangle.Width);
   Y2 := ScreenY(Obj.Rectangle.Y+Obj.Rectangle.Height);
   
   SetColor(Obj.Rectangle.StrokeColor);
   Rectangle(X1, Y1, X2, Y2);
   
   If Obj.Rectangle.Selected Then
   Begin
    SetColor(COLOR_HIGHLIGHT);
    Circle(X1, Y1, 2);
    Circle(X2, Y1, 2);
    Circle(X1, Y2, 2);
    Circle(X2, Y2, 2);
   End;
  End;

  OBJ_ELLIPSE:
  Begin
   X1 := ScreenX(Obj.Ellipse.CX);
   Y1 := ScreenY(Obj.Ellipse.CY);
   
   SetColor(Obj.Ellipse.StrokeColor);
   Ellipse(X1, Y1, 0, 360, Round(Obj.Ellipse.RX*ZoomScale),
           Round(Obj.Ellipse.RY*ZoomScale));
   
   If Obj.Ellipse.Selected Then
   Begin
    SetColor(COLOR_HIGHLIGHT);
    Circle(X1, Y1, Round(Obj.Ellipse.RX*ZoomScale) + 2);
   End;
  End;
  
  OBJ_LINE:
  Begin
   X1 := ScreenX(Obj.Line.X1);
   Y1 := ScreenY(Obj.Line.Y1);
   X2 := ScreenX(Obj.Line.X2);
   Y2 := ScreenY(Obj.Line.Y2);
   
   SetColor(Obj.Line.StrokeColor);
   Line(X1, Y1, X2, Y2);
   
   If Obj.Line.Selected Then
   Begin
    SetColor(COLOR_HIGHLIGHT);
    Circle(X1, Y1, 3);
    Circle(X2, Y2, 3);
   End;
  End;
  
  OBJ_BEZIER:
  Begin
   SetColor(Obj.Path.StrokeColor);
   P := BezierPoint(Obj,0);
   For I := 1 To BEZIER_STEPS Do Begin
    Q := BezierPoint(Obj,I/BEZIER_STEPS);
    Line(ScreenX(P.X),ScreenY(P.Y),ScreenX(Q.X),ScreenY(Q.Y));
    P := Q;
   End;
  End;
  OBJ_PATH, OBJ_FILLED_PATH:
  Begin
   If (Obj.ObjType = OBJ_FILLED_PATH) And (Obj.Path.PointCount >= 3) Then Begin
    For I := 0 To Obj.Path.PointCount-1 Do Begin
     Polygon[I].X := ScreenX(Obj.Path.Points[I].X);
     Polygon[I].Y := ScreenY(Obj.Path.Points[I].Y);
    End;
    SetFillStyle(SolidFill,Obj.Path.FillColor);
    SetColor(Obj.Path.FillColor);
    FillPoly(Obj.Path.PointCount,Polygon);
   End;
   SetColor(Obj.Path.StrokeColor);
   If Obj.Path.PointCount = 1 Then
    PutPixel(ScreenX(Obj.Path.Points[0].X),
             ScreenY(Obj.Path.Points[0].Y),Obj.Path.StrokeColor);
   For I := 1 To Obj.Path.PointCount-1 Do
    Line(ScreenX(Obj.Path.Points[I-1].X),
         ScreenY(Obj.Path.Points[I-1].Y),
         ScreenX(Obj.Path.Points[I].X),
         ScreenY(Obj.Path.Points[I].Y));
   If Obj.Path.Closed And (Obj.Path.PointCount > 1) Then
    Line(ScreenX(Obj.Path.Points[Obj.Path.PointCount-1].X),
         ScreenY(Obj.Path.Points[Obj.Path.PointCount-1].Y),
         ScreenX(Obj.Path.Points[0].X),ScreenY(Obj.Path.Points[0].Y));
  End;
  OBJ_TEXT:
  Begin
   If ZoomIndex = 2 Then Begin
    SetColor(Obj.TextObj.Color);
    OutTextXY(ScreenX(Obj.TextObj.X),ScreenY(Obj.TextObj.Y),Obj.TextObj.Text);
   End Else DrawZoomedText(Obj);
  End;
 End;
End;

Procedure DrawObject(Index: Integer);
Begin
 DrawGraphicObject(Objects[Index]);
End;

Function MinReal(A, B: Real): Real;
Begin
 If A < B Then MinReal := A Else MinReal := B;
End;

Function MaxReal(A, B: Real): Real;
Begin
 If A > B Then MaxReal := A Else MaxReal := B;
End;

Function ObjectBounds(Obj: TGraphicObject): TBounds;
Var B: TBounds; I: Integer;
Begin
 FillChar(B, SizeOf(B), 0);
 Case Obj.ObjType Of
  OBJ_RECT: Begin
   B.L := MinReal(Obj.Rectangle.X, Obj.Rectangle.X+Obj.Rectangle.Width);
   B.R := MaxReal(Obj.Rectangle.X, Obj.Rectangle.X+Obj.Rectangle.Width);
   B.T := MinReal(Obj.Rectangle.Y, Obj.Rectangle.Y+Obj.Rectangle.Height);
   B.B := MaxReal(Obj.Rectangle.Y, Obj.Rectangle.Y+Obj.Rectangle.Height);
  End;
  OBJ_ELLIPSE: Begin
   B.L := Obj.Ellipse.CX-Obj.Ellipse.RX;
   B.R := Obj.Ellipse.CX+Obj.Ellipse.RX;
   B.T := Obj.Ellipse.CY-Obj.Ellipse.RY;
   B.B := Obj.Ellipse.CY+Obj.Ellipse.RY;
  End;
  OBJ_LINE: Begin
   B.L := MinReal(Obj.Line.X1, Obj.Line.X2);
   B.R := MaxReal(Obj.Line.X1, Obj.Line.X2);
   B.T := MinReal(Obj.Line.Y1, Obj.Line.Y2);
   B.B := MaxReal(Obj.Line.Y1, Obj.Line.Y2);
  End;
  OBJ_PATH, OBJ_BEZIER, OBJ_FILLED_PATH: If Obj.Path.PointCount > 0 Then Begin
   B.L := Obj.Path.Points[0].X; B.R := B.L;
   B.T := Obj.Path.Points[0].Y; B.B := B.T;
   For I := 1 To Obj.Path.PointCount-1 Do Begin
    B.L := MinReal(B.L,Obj.Path.Points[I].X);
    B.R := MaxReal(B.R,Obj.Path.Points[I].X);
    B.T := MinReal(B.T,Obj.Path.Points[I].Y);
    B.B := MaxReal(B.B,Obj.Path.Points[I].Y);
   End;
  End;
  OBJ_TEXT: Begin
   B.L := Obj.TextObj.X; B.T := Obj.TextObj.Y;
   B.R := B.L+Length(Obj.TextObj.Text)*8-1;
   B.B := B.T+7;
  End;
 End;
 ObjectBounds := B;
End;

Procedure HandlePosition(Index, Handle: Integer; Var X, Y: Integer);
Var B: TBounds;
Begin
 B := ObjectBounds(Objects[Index]);
 If Objects[Index].ObjType = OBJ_BEZIER Then Begin
  X := Round(Objects[Index].Path.Points[Handle].X);
  Y := Round(Objects[Index].Path.Points[Handle].Y);
 End Else If Objects[Index].ObjType = OBJ_LINE Then Begin
  If Handle = 0 Then Begin
   X := Round(Objects[Index].Line.X1); Y := Round(Objects[Index].Line.Y1);
  End Else Begin
   X := Round(Objects[Index].Line.X2); Y := Round(Objects[Index].Line.Y2);
  End;
 End Else Begin
  X := Round((B.L+B.R)/2); Y := Round((B.T+B.B)/2);
  If Handle In [0,6,7] Then X := Round(B.L);
  If Handle In [2,3,4] Then X := Round(B.R);
  If Handle In [0,1,2] Then Y := Round(B.T);
  If Handle In [4,5,6] Then Y := Round(B.B);
 End;
End;

Function SelectionHandleHit(X, Y: Integer): Integer;
Var I, N, HX, HY: Integer;
Begin
 SelectionHandleHit := -1;
 If SelectedObject < 0 Then Exit;
 If Not Objects[SelectedObject].Visible Then Exit;
 If Objects[SelectedObject].ObjType = OBJ_TEXT Then Exit;
 N := 8;
 If Objects[SelectedObject].ObjType = OBJ_BEZIER Then N := 4;
 If Objects[SelectedObject].ObjType = OBJ_LINE Then N := 2;
 For I := 0 To N-1 Do Begin
  HandlePosition(SelectedObject,I,HX,HY);
  If (Abs((X-HX)*ZoomScale) <= 4) And
     (Abs((Y-HY)*ZoomScale) <= 4) Then Begin
   SelectionHandleHit := I;
   Exit;
  End;
 End;
End;

Function ObjectHit(Index, X, Y: Integer): Boolean;
Var B: TBounds; DX, DY, U, D, Margin: Real; I, J: Integer;
 P, Q: TPoint2D; Inside: Boolean;
Begin
 ObjectHit := False;
 If Not Objects[Index].Visible Then Exit;
 B := ObjectBounds(Objects[Index]);
 Margin := 5/ZoomScale;
 Case Objects[Index].ObjType Of
  OBJ_RECT: ObjectHit := (X >= B.L-3/ZoomScale) And (X <= B.R+3/ZoomScale) And
                         (Y >= B.T-3/ZoomScale) And (Y <= B.B+3/ZoomScale);
  OBJ_ELLIPSE: Begin
   DX := MaxReal(Objects[Index].Ellipse.RX,1);
   DY := MaxReal(Objects[Index].Ellipse.RY,1);
   ObjectHit := Sqr((X-Objects[Index].Ellipse.CX)/(DX+3/ZoomScale))+
                Sqr((Y-Objects[Index].Ellipse.CY)/(DY+3/ZoomScale)) <= 1;
  End;
  OBJ_LINE: Begin
   DX := Objects[Index].Line.X2-Objects[Index].Line.X1;
   DY := Objects[Index].Line.Y2-Objects[Index].Line.Y1;
   D := Sqr(DX)+Sqr(DY);
   U := 0;
   If D > 0 Then U := ((X-Objects[Index].Line.X1)*DX+
                       (Y-Objects[Index].Line.Y1)*DY)/D;
   U := MaxReal(0,MinReal(1,U));
   ObjectHit := Sqr(X-Objects[Index].Line.X1-U*DX)+
                Sqr(Y-Objects[Index].Line.Y1-U*DY) <= Sqr(Margin);
  End;
  OBJ_BEZIER: Begin
   P := BezierPoint(Objects[Index],0);
   For I := 1 To BEZIER_STEPS Do Begin
    Q := BezierPoint(Objects[Index],I/BEZIER_STEPS);
    DX := Q.X-P.X; DY := Q.Y-P.Y;
    D := Sqr(DX)+Sqr(DY); U := 0;
    If D > 0 Then U := ((X-P.X)*DX+(Y-P.Y)*DY)/D;
    U := MaxReal(0,MinReal(1,U));
    If Sqr(X-P.X-U*DX)+Sqr(Y-P.Y-U*DY) <= Sqr(Margin) Then Begin
     ObjectHit := True; Exit;
    End;
    P := Q;
   End;
  End;
  OBJ_PATH, OBJ_FILLED_PATH: Begin
   Inside := False;
   For I := 0 To Objects[Index].Path.PointCount-1 Do Begin
    J := I-1;
    If J < 0 Then
     If Objects[Index].Path.Closed Then J := Objects[Index].Path.PointCount-1
     Else J := 0;
    If (Objects[Index].ObjType = OBJ_FILLED_PATH) And
       ((Objects[Index].Path.Points[I].Y > Y) <>
        (Objects[Index].Path.Points[J].Y > Y)) Then
     If X < Objects[Index].Path.Points[I].X+
       (Y-Objects[Index].Path.Points[I].Y)*
       (Objects[Index].Path.Points[J].X-Objects[Index].Path.Points[I].X)/
       (Objects[Index].Path.Points[J].Y-Objects[Index].Path.Points[I].Y) Then
      Inside := Not Inside;
    DX := Objects[Index].Path.Points[I].X-Objects[Index].Path.Points[J].X;
    DY := Objects[Index].Path.Points[I].Y-Objects[Index].Path.Points[J].Y;
    D := Sqr(DX)+Sqr(DY); U := 0;
    If D > 0 Then U := ((X-Objects[Index].Path.Points[J].X)*DX+
                       (Y-Objects[Index].Path.Points[J].Y)*DY)/D;
    U := MaxReal(0,MinReal(1,U));
    If Sqr(X-Objects[Index].Path.Points[J].X-U*DX)+
       Sqr(Y-Objects[Index].Path.Points[J].Y-U*DY) <= Sqr(Margin) Then Begin
     ObjectHit := True; Exit;
    End;
   End;
   ObjectHit := Inside;
  End;
  OBJ_TEXT: ObjectHit := (X >= B.L) And (X <= B.R) And
                         (Y >= B.T) And (Y <= B.B);
 End;
End;

Procedure DrawSelection;
Var I, N, X, Y: Integer; B: TBounds;
Begin
 If (SelectedObject < 0) Or (CurrentTool <> TOOL_SELECT) Then Exit;
 If Not Objects[SelectedObject].Visible Then Exit;
 B := ObjectBounds(Objects[SelectedObject]);
 SetColor(COLOR_HIGHLIGHT);
 SetLineStyle(DottedLn,0,NormWidth);
 Rectangle(ScreenX(B.L),ScreenY(B.T),ScreenX(B.R),ScreenY(B.B));
 SetLineStyle(SolidLn,0,NormWidth);
 If Objects[SelectedObject].ObjType = OBJ_BEZIER Then
  DrawBezierHandles(Objects[SelectedObject],False);
 N := 8;
 If Objects[SelectedObject].ObjType = OBJ_BEZIER Then N := 4;
 If Objects[SelectedObject].ObjType = OBJ_TEXT Then N := 0;
 If Objects[SelectedObject].ObjType = OBJ_LINE Then N := 2;
 For I := 0 To N-1 Do Begin
  HandlePosition(SelectedObject,I,X,Y);
  X := ScreenX(X); Y := ScreenY(Y);
  SetFillStyle(SolidFill,COLOR_WINDOW);
  Bar(X-3,Y-3,X+3,Y+3);
  Rectangle(X-3,Y-3,X+3,Y+3);
 End;
End;

Procedure CancelObjectEdit;
Begin
 If Not EditingObject Then Exit;
 Objects[SelectedObject] := EditOriginal;
 FileModified := EditWasModified;
 EditingObject := False;
 DrawingMode := False;
 NeedsRedraw := True;
End;

Procedure UpdateObjectEdit;
Var X, Y, I: Integer; DX, DY: Real; B: TBounds; Obj: TGraphicObject;
Begin
 If Not EditingObject Then Exit;
 X := Round(MaxReal(0,MinReal(ScreenWidth-TOOLBAR_WIDTH-1,
                             DocumentX(MouseX))));
 Y := Round(MaxReal(0,MinReal(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1,
                             DocumentY(MouseY))));
 Obj := EditOriginal;
 B := EditBounds;
 DX := X-EditX; DY := Y-EditY;
 If EditHandle < 0 Then Begin
  DX := MaxReal(-B.L,MinReal(ScreenWidth-TOOLBAR_WIDTH-1-B.R,DX));
  DY := MaxReal(-B.T,MinReal(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1-B.B,DY));
  B.L := B.L+DX; B.R := B.R+DX;
  B.T := B.T+DY; B.B := B.B+DY;
  If Obj.ObjType = OBJ_LINE Then Begin
   Obj.Line.X1 := Obj.Line.X1+DX; Obj.Line.X2 := Obj.Line.X2+DX;
   Obj.Line.Y1 := Obj.Line.Y1+DY; Obj.Line.Y2 := Obj.Line.Y2+DY;
  End;
 End Else If Obj.ObjType = OBJ_BEZIER Then Begin
  If EditHandle In [0,3] Then Begin
   I := 1; If EditHandle = 3 Then I := 2;
   DX := X-Obj.Path.Points[EditHandle].X;
   DY := Y-Obj.Path.Points[EditHandle].Y;
   DX := MaxReal(-MinReal(Obj.Path.Points[EditHandle].X,Obj.Path.Points[I].X),
     MinReal(ScreenWidth-TOOLBAR_WIDTH-1-
       MaxReal(Obj.Path.Points[EditHandle].X,Obj.Path.Points[I].X),DX));
   DY := MaxReal(-MinReal(Obj.Path.Points[EditHandle].Y,Obj.Path.Points[I].Y),
     MinReal(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1-
       MaxReal(Obj.Path.Points[EditHandle].Y,Obj.Path.Points[I].Y),DY));
   Obj.Path.Points[EditHandle].X := Obj.Path.Points[EditHandle].X+DX;
   Obj.Path.Points[EditHandle].Y := Obj.Path.Points[EditHandle].Y+DY;
   Obj.Path.Points[I].X := Obj.Path.Points[I].X+DX;
   Obj.Path.Points[I].Y := Obj.Path.Points[I].Y+DY;
  End Else Begin
   Obj.Path.Points[EditHandle].X := X;
   Obj.Path.Points[EditHandle].Y := Y;
  End;
 End Else If Obj.ObjType = OBJ_LINE Then Begin
  If EditHandle = 0 Then Begin Obj.Line.X1 := X; Obj.Line.Y1 := Y; End
  Else Begin Obj.Line.X2 := X; Obj.Line.Y2 := Y; End;
 End Else Begin
  If EditHandle In [0,6,7] Then B.L := MaxReal(0,MinReal(B.R-1,B.L+DX));
  If EditHandle In [2,3,4] Then
   B.R := MinReal(ScreenWidth-TOOLBAR_WIDTH-1,MaxReal(B.L+1,B.R+DX));
  If EditHandle In [0,1,2] Then B.T := MaxReal(0,MinReal(B.B-1,B.T+DY));
  If EditHandle In [4,5,6] Then
   B.B := MinReal(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1,
                  MaxReal(B.T+1,B.B+DY));
 End;
 Case Obj.ObjType Of
  OBJ_RECT: Begin
   Obj.Rectangle.X := B.L; Obj.Rectangle.Y := B.T;
   Obj.Rectangle.Width := B.R-B.L; Obj.Rectangle.Height := B.B-B.T;
  End;
  OBJ_ELLIPSE: Begin
   Obj.Ellipse.CX := (B.L+B.R)/2; Obj.Ellipse.CY := (B.T+B.B)/2;
   Obj.Ellipse.RX := (B.R-B.L)/2; Obj.Ellipse.RY := (B.B-B.T)/2;
  End;
  OBJ_PATH, OBJ_FILLED_PATH:
   For I := 0 To Obj.Path.PointCount-1 Do Begin
    If EditHandle < 0 Then Begin
     Obj.Path.Points[I].X := Obj.Path.Points[I].X+DX;
     Obj.Path.Points[I].Y := Obj.Path.Points[I].Y+DY;
    End Else Begin
     If EditBounds.R > EditBounds.L Then
      Obj.Path.Points[I].X := B.L+(Obj.Path.Points[I].X-EditBounds.L)*
                             (B.R-B.L)/(EditBounds.R-EditBounds.L);
     If EditBounds.B > EditBounds.T Then
      Obj.Path.Points[I].Y := B.T+(Obj.Path.Points[I].Y-EditBounds.T)*
                             (B.B-B.T)/(EditBounds.B-EditBounds.T);
    End;
   End;
  OBJ_BEZIER:
    If EditHandle < 0 Then
     For I := 0 To 3 Do Begin
      Obj.Path.Points[I].X := Obj.Path.Points[I].X+DX;
      Obj.Path.Points[I].Y := Obj.Path.Points[I].Y+DY;
     End;
  OBJ_TEXT: Begin
   Obj.TextObj.X := B.L; Obj.TextObj.Y := B.T;
  End;
 End;
 Objects[SelectedObject] := Obj;
 FileModified := EditWasModified Or
  (Obj.Rectangle.X <> EditOriginal.Rectangle.X) Or
  (Obj.Rectangle.Y <> EditOriginal.Rectangle.Y) Or
  (Obj.Rectangle.Width <> EditOriginal.Rectangle.Width) Or
  (Obj.Rectangle.Height <> EditOriginal.Rectangle.Height) Or
  (Obj.Ellipse.CX <> EditOriginal.Ellipse.CX) Or
  (Obj.Ellipse.CY <> EditOriginal.Ellipse.CY) Or
  (Obj.Ellipse.RX <> EditOriginal.Ellipse.RX) Or
  (Obj.Ellipse.RY <> EditOriginal.Ellipse.RY) Or
  (Obj.Line.X1 <> EditOriginal.Line.X1) Or
  (Obj.Line.Y1 <> EditOriginal.Line.Y1) Or
  (Obj.Line.X2 <> EditOriginal.Line.X2) Or
  (Obj.Line.Y2 <> EditOriginal.Line.Y2);
 If Obj.ObjType = OBJ_TEXT Then
  FileModified := EditWasModified Or
   (Obj.TextObj.X <> EditOriginal.TextObj.X) Or
   (Obj.TextObj.Y <> EditOriginal.TextObj.Y);
 If Obj.ObjType In [OBJ_PATH,OBJ_BEZIER,OBJ_FILLED_PATH] Then
  For I := 0 To Obj.Path.PointCount-1 Do
   If (Obj.Path.Points[I].X <> EditOriginal.Path.Points[I].X) Or
      (Obj.Path.Points[I].Y <> EditOriginal.Path.Points[I].Y) Then
    FileModified := True;
 NeedsRedraw := True;
End;

Procedure AddPencilPoint;
Var X, Y, N: Integer;
Begin
 X := Round(MaxReal(0,MinReal(ScreenWidth-TOOLBAR_WIDTH-1,
                             DocumentX(MouseX))));
 Y := Round(MaxReal(0,MinReal(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1,
                             DocumentY(MouseY))));
 N := PencilObject.Path.PointCount;
 If N > 0 Then
  If (PencilObject.Path.Points[N-1].X=X) And
     (PencilObject.Path.Points[N-1].Y=Y) Then Exit;
 If N = 100 Then Begin
  StatusMessage := 'Limite de 100 points : relacher puis commencer un autre trait.';
  NeedsRedraw := True;
  Exit;
 End;
 PencilObject.Path.Points[N].X := X;
 PencilObject.Path.Points[N].Y := Y;
 Inc(PencilObject.Path.PointCount);
 NeedsRedraw := True;
End;

Procedure CancelBezier;
Begin
 BezierStage := 0;
 DrawingMode := False;
 StatusMessage := 'Courbe provisoire annulee.';
 NeedsRedraw := True;
End;

Procedure UpdateBezier;
Var X, Y, I: Integer;
Begin
 X := Round(MaxReal(0,MinReal(ScreenWidth-TOOLBAR_WIDTH-1,
                             DocumentX(MouseX))));
 Y := Round(MaxReal(0,MinReal(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1,
                             DocumentY(MouseY))));
 Case BezierStage Of
  1: Begin
   BezierObject.Path.Points[1].X := X;
   BezierObject.Path.Points[1].Y := Y;
   For I := 2 To 3 Do
    BezierObject.Path.Points[I] := BezierObject.Path.Points[0];
  End;
  2: Begin
   For I := 2 To 3 Do Begin
    BezierObject.Path.Points[I].X := X;
    BezierObject.Path.Points[I].Y := Y;
   End;
  End;
  3: Begin
   { La poignee entrante est le miroir du glissement a l'arrivee. }
   BezierObject.Path.Points[2].X := MaxReal(0,MinReal(
    ScreenWidth-TOOLBAR_WIDTH-1,2*BezierObject.Path.Points[3].X-X));
   BezierObject.Path.Points[2].Y := MaxReal(0,MinReal(
    ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1,
    2*BezierObject.Path.Points[3].Y-Y));
  End;
 End;
 NeedsRedraw := True;
End;

Procedure BeginTextInput(Index: Integer);
Begin
 TextEditIndex := Index;
 If Index >= 0 Then TextObject := Objects[Index];
 TextCursor := Length(TextObject.TextObj.Text);
 TextActive := True;
 CurrentTool := TOOL_TEXT;
 SelectedObject := -1;
 ResetToolTip;
 StatusMessage := 'Texte : clic outil/menu ou Entree = valider, Echap = annuler.';
End;

Procedure HandleMouseClick;
Var
 CanvasX, CanvasY: Integer;
 I: Integer;
Begin
 If (MouseX < 0) Or (MouseY < MENUBAR_HEIGHT) Or
    (MouseY >= ScreenHeight-STATUSBAR_HEIGHT) Or
    (MouseX >= ScreenWidth) Then Exit;
 If MouseX < TOOLBAR_WIDTH Then Begin
  I := ToolHitTest(MouseX, MouseY);
  If I >= 0 Then
   CurrentTool := I;
  Exit;
 End;
 
 If CurrentTool = TOOL_ZOOM Then Begin
  ChangeZoom(1,MouseX,MouseY);
  Exit;
 End;
 If CurrentTool = TOOL_HAND Then Begin
  PanX := MouseX; PanY := MouseY;
  PanViewX := ViewX; PanViewY := ViewY;
  Panning := True;
  DrawingMode := True;
  ResetToolTip;
  If ZoomIndex <= 2 Then
   StatusMessage := 'Page entiere visible : agrandir avec la Loupe pour la deplacer.'
  Else StatusMessage := 'Main : glisser la vue, relacher pour terminer, Echap pour annuler.';
  Exit;
 End;
 CanvasX := DocumentX(MouseX);
 CanvasY := DocumentY(MouseY);
 If (CanvasX < 0) Or (CanvasX >= ScreenWidth-TOOLBAR_WIDTH) Or
    (CanvasY < 0) Or
    (CanvasY >= ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT) Then Begin
  StatusMessage := 'Cliquer dans la page pour dessiner.';
  Exit;
 End;
 
 Case CurrentTool Of
  TOOL_BEZIER, TOOL_PEN:
  Begin
   If BezierStage = 2 Then Begin
    UpdateBezier;
    BezierStage := 3;
   End Else Begin
    If ObjectCount >= MAX_OBJECTS Then Begin
     StatusMessage := 'Limite de 100 objets atteinte.';
     Exit;
    End;
    FillChar(BezierObject,SizeOf(BezierObject),0);
    BezierObject.ObjType := OBJ_BEZIER;
    BezierObject.Visible := True;
    BezierObject.LayerIndex := CurrentLayer;
    BezierObject.Path.PointCount := 4;
    BezierObject.Path.StrokeColor := StrokeColor;
    BezierObject.Path.StrokeWidth := 1;
    For I := 0 To 3 Do Begin
     BezierObject.Path.Points[I].X := CanvasX;
     BezierObject.Path.Points[I].Y := CanvasY;
    End;
    BezierStage := 1;
    DrawingMode := True;
    SelectedObject := -1;
    ResetToolTip;
    StatusMessage := 'Glisser au depart, relacher, puis cliquer-glisser a l''arrivee.';
   End;
  End;
  TOOL_TEXT:
  Begin
   TextEditIndex := -1;
   For I := ObjectCount-1 DownTo 0 Do
    If (Objects[I].ObjType = OBJ_TEXT) And ObjectHit(I,CanvasX,CanvasY) Then Begin
     TextEditIndex := I;
     Break;
    End;
   If TextEditIndex < 0 Then Begin
    If ObjectCount >= MAX_OBJECTS Then Begin
     StatusMessage := 'Limite de 100 objets atteinte.';
     Exit;
    End;
    FillChar(TextObject,SizeOf(TextObject),0);
    TextObject.ObjType := OBJ_TEXT;
    TextObject.Visible := True;
    TextObject.LayerIndex := CurrentLayer;
    TextObject.TextObj.X := MinReal(CanvasX,ScreenWidth-TOOLBAR_WIDTH-8);
    TextObject.TextObj.Y := MinReal(CanvasY,ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-8);
    TextObject.TextObj.Color := StrokeColor;
    TextObject.TextObj.FontSize := 8;
   End;
   BeginTextInput(TextEditIndex);
  End;
  TOOL_PENCIL:
  Begin
   If ObjectCount >= MAX_OBJECTS Then Begin
    StatusMessage := 'Limite de 100 objets atteinte.';
    Exit;
   End;
   FillChar(PencilObject,SizeOf(PencilObject),0);
   PencilObject.ObjType := OBJ_PATH;
   PencilObject.Visible := True;
   PencilObject.LayerIndex := CurrentLayer;
   PencilObject.Path.StrokeColor := StrokeColor;
   PencilObject.Path.StrokeWidth := 1;
   PencilActive := True;
   DrawingMode := True;
   SelectedObject := -1;
   StatusMessage := 'Crayon : tracer, relacher pour terminer, Echap pour annuler.';
   AddPencilPoint;
  End;
  TOOL_SELECT:
  Begin
   EditHandle := SelectionHandleHit(CanvasX,CanvasY);
   If EditHandle < 0 Then Begin
    SelectedObject := -1;
    For I := ObjectCount-1 DownTo 0 Do
     If ObjectHit(I,CanvasX,CanvasY) Then Begin
      SelectedObject := I;
      Break;
     End;
   End;
   If SelectedObject >= 0 Then Begin
    EditOriginal := Objects[SelectedObject];
    EditBounds := ObjectBounds(EditOriginal);
    EditX := CanvasX; EditY := CanvasY;
    EditWasModified := FileModified;
    EditingObject := True;
    DrawingMode := True;
    If Objects[SelectedObject].ObjType = OBJ_TEXT Then
     StatusMessage := 'Texte selectionne : taper pour modifier, glisser pour deplacer.'
    Else StatusMessage := 'Glisser : deplacer / poignees : taille / Echap : annuler';
   End Else StatusMessage := 'Aucun objet selectionne.';
  End;
  
  TOOL_RECTANGLE:
  Begin
   StartX := CanvasX;
   StartY := CanvasY;
   DrawingMode := True;
  End;
  
  TOOL_ELLIPSE:
  Begin
   StartX := CanvasX;
   StartY := CanvasY;
   DrawingMode := True;
  End;
  
  TOOL_LINE:
  Begin
   StartX := CanvasX;
   StartY := CanvasY;
   DrawingMode := True;
  End;
 End;
End;

Procedure HandleMouseRelease;
Var
 CanvasX, CanvasY: Integer;
 NewObj: TGraphicObject;
Begin
 If Panning Then Begin
  UpdatePan;
  Panning := False;
  DrawingMode := False;
  Exit;
 End;
 If BezierStage <> 0 Then Begin
  UpdateBezier;
  If BezierStage = 1 Then Begin
   BezierStage := 2;
   StatusMessage := 'Cliquer-glisser a l''arrivee ; Echap annule la courbe.';
  End Else If BezierStage = 3 Then Begin
   Objects[ObjectCount] := BezierObject;
   Inc(ObjectCount);
   FileModified := True;
   BezierStage := 0;
   DrawingMode := False;
   StatusMessage := 'Courbe creee. Fleche : deplacer ou modifier les quatre poignees.';
  End;
  Exit;
 End;
 If PencilActive Then Begin
  AddPencilPoint;
  Objects[ObjectCount] := PencilObject;
  Inc(ObjectCount);
  FileModified := True;
  PencilActive := False;
  DrawingMode := False;
  Exit;
 End;
 If EditingObject Then Begin
  UpdateObjectEdit;
  EditingObject := False;
  DrawingMode := False;
  Exit;
 End;
 If Not DrawingMode Then Exit;
 
 CanvasX := DocumentX(MouseX);
 CanvasY := DocumentY(MouseY);
 If CanvasX < 0 Then CanvasX := 0;
 If CanvasY < 0 Then CanvasY := 0;
 If CanvasX >= ScreenWidth-TOOLBAR_WIDTH Then CanvasX := ScreenWidth-TOOLBAR_WIDTH-1;
 If CanvasY >= ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT Then
  CanvasY := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1;
 
 If ObjectCount >= MAX_OBJECTS Then Begin
  DrawingMode := False;
  StatusMessage := 'Limite de 100 objets atteinte.';
  Exit;
 End;
 If (MouseX < TOOLBAR_WIDTH) Or (MouseX >= ScreenWidth) Or
    (MouseY < MENUBAR_HEIGHT) Or
    (MouseY >= ScreenHeight-STATUSBAR_HEIGHT) Then Begin
  DrawingMode := False;
  Exit;
 End;
 
 FillChar(NewObj, SizeOf(NewObj), 0);
 NewObj.Visible := True;
 NewObj.LayerIndex := CurrentLayer;
 
 Case CurrentTool Of
  TOOL_RECTANGLE:
  Begin
   NewObj.ObjType := OBJ_RECT;
   NewObj.Rectangle.X := StartX;
   NewObj.Rectangle.Y := StartY;
   NewObj.Rectangle.Width := CanvasX - StartX;
   NewObj.Rectangle.Height := CanvasY - StartY;
   If NewObj.Rectangle.Width < 0 Then Begin
    NewObj.Rectangle.X := CanvasX;
    NewObj.Rectangle.Width := -NewObj.Rectangle.Width;
   End;
   If NewObj.Rectangle.Height < 0 Then Begin
    NewObj.Rectangle.Y := CanvasY;
    NewObj.Rectangle.Height := -NewObj.Rectangle.Height;
   End;
   NewObj.Rectangle.StrokeColor := StrokeColor;
   NewObj.Rectangle.FillColor := FillColor;
   NewObj.Rectangle.StrokeWidth := 1.0;
   Objects[ObjectCount] := NewObj;
   Inc(ObjectCount);
  End;
  
  TOOL_ELLIPSE:
  Begin
   NewObj.ObjType := OBJ_ELLIPSE;
   NewObj.Ellipse.CX := (StartX + CanvasX) / 2;
   NewObj.Ellipse.CY := (StartY + CanvasY) / 2;
   NewObj.Ellipse.RX := Abs(CanvasX - StartX) / 2;
   NewObj.Ellipse.RY := Abs(CanvasY - StartY) / 2;
   NewObj.Ellipse.StrokeColor := StrokeColor;
   NewObj.Ellipse.FillColor := FillColor;
   NewObj.Ellipse.StrokeWidth := 1.0;
   Objects[ObjectCount] := NewObj;
   Inc(ObjectCount);
  End;
  
  TOOL_LINE:
  Begin
   NewObj.ObjType := OBJ_LINE;
   NewObj.Line.X1 := StartX;
   NewObj.Line.Y1 := StartY;
   NewObj.Line.X2 := CanvasX;
   NewObj.Line.Y2 := CanvasY;
   NewObj.Line.StrokeColor := StrokeColor;
   NewObj.Line.StrokeWidth := 1.0;
   Objects[ObjectCount] := NewObj;
   Inc(ObjectCount);
  End;
 End;
 
 DrawingMode := False;
 FileModified := True;
End;

Procedure AddMenuItem(M: Integer; Caption: String; Command: Byte);
Var N: Integer;
Begin
 N := Menus[M].ItemCount;
 Menus[M].Items[N].Caption := Caption;
 Menus[M].Items[N].Command := Command;
 Inc(Menus[M].ItemCount);
End;

Procedure InitMenus;
Var I, J, X, W: Integer;
Begin
 FillChar(Menus, SizeOf(Menus), 0);
 Menus[0].Title := 'Fichier';
 Menus[1].Title := 'Edition';
 Menus[2].Title := 'Affichage';
 Menus[3].Title := 'Objet';
 Menus[4].Title := 'Chemin';
 Menus[5].Title := 'Texte';
 Menus[6].Title := 'Aide';
 AddMenuItem(0, 'Nouveau', CMD_NEW);
 AddMenuItem(0, 'Ouvrir...', CMD_OPEN);
 AddMenuItem(0, 'Enregistrer', CMD_SAVE);
 AddMenuItem(0, 'Enregistrer sous...', CMD_SAVE_AS);
 AddMenuItem(0, 'Exporter...', CMD_EXPORT);
 AddMenuItem(0, '-', CMD_NONE);
 AddMenuItem(0, 'Quitter', CMD_EXIT);
 AddMenuItem(1, 'Annuler', CMD_NONE);
 AddMenuItem(1, 'Retablir', CMD_NONE);
 AddMenuItem(1, '-', CMD_NONE);
 AddMenuItem(1, 'Couper', CMD_NONE);
 AddMenuItem(1, 'Copier', CMD_NONE);
 AddMenuItem(1, 'Coller', CMD_NONE);
 AddMenuItem(2, 'Zoom avant', CMD_ZOOM_IN);
 AddMenuItem(2, 'Zoom arriere', CMD_ZOOM_OUT);
 AddMenuItem(2, 'Adapter (100%)', CMD_ZOOM_RESET);
 AddMenuItem(2, 'Grille', CMD_GRID);
 AddMenuItem(2, 'Regles', CMD_NONE);
 AddMenuItem(2, 'Reperes', CMD_NONE);
 AddMenuItem(3, 'Proprietes...', CMD_NONE);
 AddMenuItem(3, 'Arrangement', CMD_NONE);
 AddMenuItem(3, 'Grouper', CMD_NONE);
 AddMenuItem(3, 'Degrouper', CMD_NONE);
 AddMenuItem(3, 'Aligner', CMD_NONE);
 AddMenuItem(3, 'Distribuer', CMD_NONE);
 AddMenuItem(3, 'Transformer', CMD_NONE);
 AddMenuItem(3, 'Operations', CMD_NONE);
 AddMenuItem(4, 'Rejoindre', CMD_NONE);
 AddMenuItem(4, 'Scinder', CMD_NONE);
 AddMenuItem(4, 'Cont. Coin', CMD_NONE);
 AddMenuItem(4, 'Cont. Courbe', CMD_NONE);
 AddMenuItem(4, 'Simplifier', CMD_NONE);
 AddMenuItem(4, 'Decalage', CMD_NONE);
 AddMenuItem(5, 'Glyphes', CMD_NONE);
 AddMenuItem(5, 'Texte a chemin', CMD_NONE);
 AddMenuItem(5, 'Chemin a texte', CMD_NONE);
 AddMenuItem(5, 'Polices', CMD_NONE);
 AddMenuItem(5, 'Formats', CMD_NONE);
 AddMenuItem(5, 'Affichage', CMD_NONE);
 AddMenuItem(6, 'Aide', CMD_HELP);
 AddMenuItem(6, 'Raccourcis', CMD_SHORTCUTS);
 AddMenuItem(6, 'A propos', CMD_ABOUT);
 AddMenuItem(6, 'Ressources', CMD_RESOURCES);
 AddMenuItem(6, 'Astuces', CMD_TIPS);
 X := 5;
 For I := 0 To MAX_MENUS-1 Do Begin
  Menus[I].X := X;
  Menus[I].TitleWidth := TextWidth(Menus[I].Title)+12;
  Menus[I].Width := 180;
  For J := 0 To Menus[I].ItemCount-1 Do Begin
   W := TextWidth(Menus[I].Items[J].Caption)+30;
   If W > Menus[I].Width Then Menus[I].Width := W;
  End;
  X := X+Menus[I].TitleWidth;
 End;
End;

Function MenuLeft(M: Integer): Integer;
Var X: Integer;
Begin
 X := Menus[M].X;
 If X+Menus[M].Width >= ScreenWidth Then
  X := ScreenWidth-Menus[M].Width-1;
 MenuLeft := X;
End;

Function MenuBarHitTest(X, Y: Integer): Integer;
Var I: Integer;
Begin
 MenuBarHitTest := -1;
 If (Y < 0) Or (Y >= MENUBAR_HEIGHT) Then Exit;
 For I := 0 To MAX_MENUS-1 Do
  If (X >= Menus[I].X) And
     (X < Menus[I].X+Menus[I].TitleWidth) Then Begin
   MenuBarHitTest := I;
   Exit;
  End;
End;

Function MenuItemHitTest(X, Y, M: Integer): Integer;
Var I: Integer;
Begin
 MenuItemHitTest := -1;
 If (M < 0) Or (M >= MAX_MENUS) Then Exit;
 If (X < MenuLeft(M)+2) Or
    (X >= MenuLeft(M)+Menus[M].Width-2) Or
    (Y < MENUBAR_HEIGHT+2) Or
    (Y >= MENUBAR_HEIGHT+2+Menus[M].ItemCount*MENU_ITEM_HEIGHT) Then Exit;
 I := (Y-MENUBAR_HEIGHT-2) Div MENU_ITEM_HEIGHT;
 If Menus[M].Items[I].Caption <> '-' Then MenuItemHitTest := I;
End;

Procedure CloseMenu;
Begin
 MenuActive := False;
 ActiveMenu := -1;
 ActiveMenuItem := -1;
 NeedsRedraw := True;
End;

Procedure OpenMenu(M: Integer);
Begin
 ResetToolTip;
 MenuActive := True;
 ActiveMenu := M;
 ActiveMenuItem := -1;
 DrawingMode := False;
 NeedsRedraw := True;
End;

Procedure DrawMenu;
Var I, X, Y, H: Integer;
Begin
 If Not MenuActive Then Exit;
 X := MenuLeft(ActiveMenu);
 H := Menus[ActiveMenu].ItemCount*MENU_ITEM_HEIGHT+4;
 SetFillStyle(SolidFill, COLOR_BG);
 Bar(X, MENUBAR_HEIGHT, X+Menus[ActiveMenu].Width, MENUBAR_HEIGHT+H);
 SetColor(COLOR_BORDER);
 Rectangle(X, MENUBAR_HEIGHT, X+Menus[ActiveMenu].Width, MENUBAR_HEIGHT+H);
 For I := 0 To Menus[ActiveMenu].ItemCount-1 Do Begin
  Y := MENUBAR_HEIGHT+2+I*MENU_ITEM_HEIGHT;
  If Menus[ActiveMenu].Items[I].Caption = '-' Then Begin
   SetColor(COLOR_BORDER);
   Line(X+4, Y+MENU_ITEM_HEIGHT Div 2,
        X+Menus[ActiveMenu].Width-4, Y+MENU_ITEM_HEIGHT Div 2);
  End Else Begin
   If (I = ActiveMenuItem) And
      (Menus[ActiveMenu].Items[I].Command <> CMD_NONE) Then Begin
    SetFillStyle(SolidFill, COLOR_HIGHLIGHT);
    Bar(X+2, Y, X+Menus[ActiveMenu].Width-2, Y+MENU_ITEM_HEIGHT-1);
    SetColor(COLOR_WINDOW);
   End Else Begin
    SetColor(COLOR_TEXT);
   End;
   OutTextXY(X+20, Y+5, Menus[ActiveMenu].Items[I].Caption);
   If Menus[ActiveMenu].Items[I].Command = CMD_NONE Then
    OutTextXY(X+5, Y+5, 'x');
   If (Menus[ActiveMenu].Items[I].Command = CMD_GRID) And GridVisible Then
    OutTextXY(X+5, Y+5, '*');
  End;
 End;
End;

Procedure ShowDialog(Title, MessageText: String);
Begin
 ResetToolTip;
 DialogTitle := Title;
 DialogText := MessageText;
 NeedsRedraw := True;
End;

Function UpperText(S: String): String;
Var I: Integer;
Begin
 For I := 1 To Length(S) Do S[I] := UpCase(S[I]);
 UpperText := S;
End;

Function FileJoin(DirName, Leaf: String): String;
Begin
 FileJoin := '';
 If (Length(Leaf)>1) And (Leaf[2]=':') Then FileJoin := FExpand(Leaf)
 Else If (Leaf<>'') And (Leaf[1]='\') Then Begin
  If ((Length(Leaf)>1) And (Leaf[2]='\')) Or
     (Length(DirName)<2) Or (DirName[2]<>':') Then FileJoin := FExpand(Leaf)
  Else If Length(Leaf)<=253 Then FileJoin := FExpand(Copy(DirName,1,2)+Leaf);
 End
 Else Begin
  If Length(DirName)+Length(Leaf)+1>255 Then Begin
   FileDialogError := 'Chemin trop long (255 caracteres maximum).'; Exit;
  End;
  If (DirName<>'') And (DirName[Length(DirName)]<>'\') Then
   DirName := DirName+'\';
  FileJoin := FExpand(DirName+Leaf);
 End;
End;

Function IsDirectory(Name: String): Boolean;
Var F: File; Attr: Word; Code: Integer;
Begin
 Assign(F,Name);
 GetFAttr(F,Attr); Code := DosError;
 IsDirectory := (Code=0) And ((Attr And Directory)<>0);
End;

Function FileMatches(Name: String): Boolean;
Var D: DirStr; N: NameStr; E: ExtStr;
Begin
 FSplit(Name,D,N,E); E := UpperText(E);
 If FileExportMode Then Begin
  FileMatches := E=UpperText(OutputExtension(FileFilter+3));
  Exit;
 End;
 If FileSaveMode Then Begin
  Case FileFilter Of
   0: FileMatches := E='.AI';
   1: FileMatches := E='.EPS';
   Else FileMatches := (E='.AI10') Or (E='.CDRA');
  End;
  Exit;
 End;
 Case FileFilter Of
  0: FileMatches := (E='.AI') Or (E='.EPS') Or (E='.AI10') Or (E='.CDRA');
  1: FileMatches := (E='.AI') Or (E='.EPS');
  2: FileMatches := (E='.AI10') Or (E='.CDRA');
  Else FileMatches := True;
 End;
End;

Function FileFilterLabel(Index: Integer): String;
Begin
 If FileExportMode Then Begin
  Case Index Of
   0: FileFilterLabel := 'SVG vectoriel (*.svg)';
   1: FileFilterLabel := 'BMP bitmap 24 bits (*.bmp)';
   2: FileFilterLabel := 'PostScript EPS (*.eps)';
   3: FileFilterLabel := 'Illustrator classique (*.ai)';
   Else FileFilterLabel := 'CorelDRAW 9 natif (*.cdr)';
  End;
  Exit;
 End;
 If FileSaveMode Then Begin
  Case Index Of
   0: FileFilterLabel := 'Illustrator classique (*.ai)';
   1: FileFilterLabel := 'PostScript EPS (*.eps)';
   Else FileFilterLabel := 'Prive AI10 - objets exacts (*.ai10)';
  End;
  Exit;
 End;
 Case Index Of
  0: FileFilterLabel := 'Illustrator / AI10 (*.ai;*.eps;*.ai10;*.cdra)';
  1: FileFilterLabel := 'Illustrator classique (*.ai;*.eps)';
  2: FileFilterLabel := 'Prive AI10 (*.ai10;*.cdra)';
  Else FileFilterLabel := 'Tous fichiers (*.*)';
 End;
End;

Function FileFilterCount: Integer;
Begin
 If FileExportMode Then FileFilterCount := 5
 Else If FileSaveMode Then FileFilterCount := 3
 Else FileFilterCount := 4;
End;

Function FileFilterTop: Integer;
Begin
 If FileExportMode Then FileFilterTop := 271 Else FileFilterTop := 292;
End;

Function ScanFileDirectory(NewPath: String): Boolean;
Var SR: SearchRec; I, J, Err: Integer; Temp: TFileEntry;
 Truncated: Boolean;
Begin
 ScanFileDirectory := False;
 If NewPath='' Then Begin FileDialogError := 'Chemin vide ou trop long.'; Exit; End;
 NewPath := FExpand(NewPath);
 While (Length(NewPath)>3) And (NewPath[Length(NewPath)]='\') Do
  Delete(NewPath,Length(NewPath),1);
 If Not IsDirectory(NewPath) Then Begin
  FileDialogError := 'Dossier introuvable ou acces refuse.';
  Exit;
 End;
 FindFirst(FileJoin(NewPath,'*.*'),AnyFile,SR);
 Err := DosError;
 If (Err<>0) And (Err<>18) And (Err<>2) Then Begin
  FileDialogError := 'Impossible de lire ce dossier.';
  Exit;
 End;
 FileDirCount := 0; FileEntryCount := 0; Truncated := False;
 While DosError=0 Do Begin
  If (SR.Name<>'.') And (SR.Name<>'..') And ((SR.Attr And VolumeID)=0) Then
   If (SR.Attr And Directory)<>0 Then Begin
    If FileDirCount=FD_MAX_ENTRIES Then Truncated := True
    Else Begin
     FileDirs[FileDirCount].Name := SR.Name;
     FileDirs[FileDirCount].Size := SR.Size;
     FileDirs[FileDirCount].Stamp := SR.Time;
     Inc(FileDirCount);
    End;
   End Else If FileMatches(SR.Name) Then Begin
    If FileEntryCount=FD_MAX_ENTRIES Then Truncated := True
    Else Begin
     FileEntries[FileEntryCount].Name := SR.Name;
     FileEntries[FileEntryCount].Size := SR.Size;
     FileEntries[FileEntryCount].Stamp := SR.Time;
     Inc(FileEntryCount);
    End;
   End;
  FindNext(SR);
 End;
 Err := DosError;
 {$IFDEF FPC} FindClose(SR); {$ENDIF}
 For I := 1 To FileDirCount-1 Do Begin
  Temp := FileDirs[I]; J := I;
  While J>0 Do Begin
   If UpperText(FileDirs[J-1].Name)<=UpperText(Temp.Name) Then Break;
   FileDirs[J] := FileDirs[J-1]; Dec(J);
  End;
  FileDirs[J] := Temp;
 End;
 For I := 1 To FileEntryCount-1 Do Begin
  Temp := FileEntries[I]; J := I;
  While J>0 Do Begin
   If UpperText(FileEntries[J-1].Name)<=UpperText(Temp.Name) Then Break;
   FileEntries[J] := FileEntries[J-1]; Dec(J);
  End;
  FileEntries[J] := Temp;
 End;
 FilePath := NewPath; FilePathInput := FilePath;
 If FileFocus=3 Then FileCursor := Length(FilePathInput);
 FileSel := -1; FileDirSel := -1; FileTop := 0; FileDirTop := 0;
 FileLastIndex := -1; FileLastList := -1;
 FileDialogError := '';
 If Truncated Then
  FileDialogError := 'Liste limitee a 512 entrees par volet ; utiliser un nom ou un filtre.';
 If (Err<>18) And (Err<>2) Then
  FileDialogError := 'Lecture du dossier interrompue (erreur DOS).';
 NeedsRedraw := True;
 ScanFileDirectory := True;
End;

Procedure StartFileDialog;
Var D: DirStr; N: NameStr; E: ExtStr; Initial: String;
Begin
 ResetToolTip;
 FileDialogActive := True; FileFilterOpen := False;
 FileSaveMode := False; FileOverwrite := False;
 FileExportMode := False;
 FileFocus := 1; FileFilter := 0; FileNameInput := ''; FileCursor := 0;
 FileReplace := False; FileDialogError := '';
 GetDir(0,Initial);
 If CurrentFile<>'' Then Begin
  FSplit(CurrentFile,D,N,E);
  If D<>'' Then Initial := D;
 End;
 If Not ScanFileDirectory(Initial) Then Begin
  GetDir(0,Initial);
  If ScanFileDirectory(Initial) Then
   FileDialogError := 'Dossier initial inaccessible ; repertoire courant affiche.'
  Else Begin
   FilePath := Initial; FilePathInput := Initial;
   FileDirCount := 0; FileEntryCount := 0;
  End;
 End;
 NeedsRedraw := True;
End;

Procedure StartSaveDialog;
Var D: DirStr; N: NameStr; E: ExtStr; Ext: String;
Begin
 StartFileDialog;
 FileSaveMode := True;
 FileFilter := CurrentSaveFormat;
 If (FileFilter<0) Or (FileFilter>2) Then FileFilter := 0;
 If ScanFileDirectory(FilePath) Then Begin
  If CurrentFile<>'' Then Begin
   FSplit(CurrentFile,D,N,E);
   Case FileFilter Of
    0: Ext := '.ai';
    1: Ext := '.eps';
    Else Ext := '.ai10';
   End;
   FileNameInput := N+Ext;
  End Else FileNameInput := 'Sans titre.ai';
  FileFocus := 2; FileCursor := Length(FileNameInput); FileReplace := True;
 End;
End;

Procedure StartExportDialog;
Var D: DirStr; N: NameStr; E: ExtStr;
Begin
 StartFileDialog;
 FileSaveMode := True; FileExportMode := True; FileFilter := 0;
 If ScanFileDirectory(FilePath) Then Begin
  If CurrentFile<>'' Then Begin
   FSplit(CurrentFile,D,N,E); FileNameInput := N+'.svg';
  End Else FileNameInput := 'Sans titre.svg';
  FileFocus := 2; FileCursor := Length(FileNameInput); FileReplace := True;
 End;
End;

Procedure ApplyFileFilter(NewFilter: Integer);
Var D: DirStr; N: NameStr; E: ExtStr; Ext: String;
Begin
 FileFilter := NewFilter;
 If FileSaveMode And (FileNameInput<>'') Then Begin
  FSplit(FileNameInput,D,N,E);
  If (E='') Or (UpperText(E)='.AI') Or (UpperText(E)='.EPS') Or
     (UpperText(E)='.AI10') Or (UpperText(E)='.CDRA') Or
     (UpperText(E)='.SVG') Or (UpperText(E)='.BMP') Or
     (UpperText(E)='.CDR') Then Begin
   If FileExportMode Then Ext := OutputExtension(FileFilter+3)
   Else Ext := OutputExtension(FileFilter);
   If Length(D)+Length(N)+Length(Ext)<=255 Then FileNameInput := D+N+Ext
   Else FileDialogError := 'Nom trop long pour changer l''extension.';
  End;
 End;
 If ScanFileDirectory(FilePath) Then
  If Not FileSaveMode Then FileNameInput := '';
End;

Function FileExistsChecked(Name: String; Var Exists: Boolean): Boolean;
Var F: File; Attr: Word; Code: Integer;
Begin
 Assign(F,Name); GetFAttr(F,Attr); Code := DosError;
 Exists := Code=0;
 FileExistsChecked := (Code=0) Or (Code=2) Or (Code=3);
End;

Procedure CompleteDialogSave;
Var Good: Boolean;
Begin
 FileOverwrite := False;
 If FileExportMode Then Good := ExportDocument(PendingSaveName,FileFilter)
 Else Good := SaveDocument(PendingSaveName,FileFilter);
 If Good Then Begin
  FileDialogActive := False; FileFilterOpen := False;
 End Else FileDialogError := SaveError;
 NeedsRedraw := True;
End;

Procedure ActivateFileChoice;
Var Name, Ext: String; D: DirStr; N: NameStr; E: ExtStr; Exists: Boolean;
Begin
 FileDialogError := '';
 If (FileFocus=0) Or ((FileFocus=5) And (FileNameInput='') And (FileDirSel>=0)) Then Begin
  If (FileDirSel>=0) And (FileDirSel<FileDirCount) Then Begin
   Name := FileJoin(FilePath,FileDirs[FileDirSel].Name);
   If ScanFileDirectory(Name) Then FileNameInput := '';
  End;
  Exit;
 End;
 If FileFocus=3 Then Name := FilePathInput Else Name := FileNameInput;
 If Name='' Then Begin FileDialogError := 'Selectionner ou saisir un nom de fichier.'; Exit; End;
 Name := FileJoin(FilePath,Name);
 If IsDirectory(Name) Then Begin
  If ScanFileDirectory(Name) Then Begin FileNameInput := ''; FileFocus := 1; End;
  Exit;
 End;
 If FileFocus=3 Then Begin
  FileDialogError := 'Le chemin doit designer un dossier.'; Exit;
 End;
 If FileSaveMode Then Begin
  FSplit(Name,D,N,E);
  If FileExportMode Then Ext := OutputExtension(FileFilter+3)
  Else Ext := OutputExtension(FileFilter);
  If (N='') Or (Pos('*',Name)>0) Or (Pos('?',Name)>0) Then Begin
   FileDialogError := 'Nom de fichier invalide.'; Exit;
  End;
  If E='' Then Begin
   If Length(Name)+Length(Ext)>255 Then Begin
    FileDialogError := 'Chemin trop long.'; Exit;
   End;
   Name := Name+Ext;
  End Else If (UpperText(E)<>UpperText(Ext)) And
    Not (Not FileExportMode And (FileFilter=2) And (UpperText(E)='.CDRA')) Then Begin
   FileDialogError := 'Extension incompatible : choisir le bon type ou modifier le nom.';
   Exit;
  End;
  If Not FileExistsChecked(Name,Exists) Then Begin
   FileDialogError := 'Impossible de verifier le fichier cible (acces refuse).'; Exit;
  End;
  PendingSaveName := Name;
  If Exists Then Begin FileOverwrite := True; NeedsRedraw := True; End
  Else CompleteDialogSave;
  Exit;
 End;
 If LoadDocument(Name) Then Begin
  FileDialogActive := False; FileFilterOpen := False;
 End Else FileDialogError := ImportError;
 NeedsRedraw := True;
End;

Procedure FileEnsureVisible;
Begin
 If FileSel<FileTop Then FileTop := FileSel;
 If FileSel>=FileTop+FD_ROWS Then FileTop := FileSel-FD_ROWS+1;
 If FileTop<0 Then FileTop := 0;
 If FileDirSel<FileDirTop Then FileDirTop := FileDirSel;
 If FileDirSel>=FileDirTop+FD_ROWS Then FileDirTop := FileDirSel-FD_ROWS+1;
 If FileDirTop<0 Then FileDirTop := 0;
End;

Procedure FileButton(X1,Y1,X2,Y2: Integer; Caption: String; Focused: Boolean);
Begin
 SetFillStyle(SolidFill,COLOR_BG); Bar(X1,Y1,X2,Y2);
 SetColor(COLOR_WINDOW); Line(X1,Y1,X2,Y1); Line(X1,Y1,X1,Y2);
 SetColor(COLOR_BORDER); Line(X1,Y2,X2,Y2); Line(X2,Y1,X2,Y2);
 SetColor(COLOR_TEXT);
 If Focused Then Rectangle(X1+2,Y1+2,X2-2,Y2-2);
 OutTextXY(X1+(X2-X1-TextWidth(Caption)) Div 2,Y1+(Y2-Y1-8) Div 2,Caption);
End;

Procedure DrawFileDialog;
Var I, K, Y, X1, X2, Count, TopIndex, Selected, ScrollX, ThumbY: Integer;
 S, SizeText, Info: String; DT: DateTime;

 Procedure Field(X1,Y1,X2,Y2,Focus: Integer; Value: String);
 Var Start, Caret: Integer; Visible: String;
 Begin
  SetFillStyle(SolidFill,COLOR_WINDOW); Bar(X1,Y1,X2,Y2);
  SetColor(COLOR_BORDER); Rectangle(X1,Y1,X2,Y2);
  Start := 1;
  If FileFocus=Focus Then Begin
   Start := FileCursor-(X2-X1-12) Div 8+1;
   If Start<1 Then Start := 1;
  End Else If Length(Value)>(X2-X1-8) Div 8 Then
   Start := Length(Value)-(X2-X1-8) Div 8+1;
  Visible := Copy(Value,Start,(X2-X1-8) Div 8);
  If (FileFocus=Focus) And FileReplace Then Begin
   SetFillStyle(SolidFill,COLOR_HIGHLIGHT); Bar(X1+2,Y1+2,X2-2,Y2-2);
   SetColor(COLOR_WINDOW);
  End Else SetColor(COLOR_TEXT);
  OutTextXY(X1+4,Y1+7,Visible);
  If FileFocus=Focus Then Begin
   Caret := X1+4+(FileCursor-Start+1)*8;
   Line(Caret,Y1+5,Caret,Y1+14);
  End;
 End;

Begin
 SetFillStyle(SolidFill,COLOR_BG); Bar(20,44,620,437);
 SetColor(COLOR_BORDER); Rectangle(20,44,620,437);
 SetFillStyle(SolidFill,COLOR_HIGHLIGHT); Bar(22,46,618,66);
 SetColor(COLOR_WINDOW);
 If FileExportMode Then OutTextXY(30,52,'Exporter - SVG / BMP / EPS / AI / CorelDRAW 9')
 Else If FileSaveMode Then OutTextXY(30,52,'Enregistrer sous - Illustrator / AI10')
 Else OutTextXY(30,52,'Ouvrir un fichier - Illustrator / AI10');
 FileButton(590,47,615,64,'X',False);
 SetColor(COLOR_TEXT); OutTextXY(30,87,'Dossier:');
 Field(100,77,478,99,3,FilePathInput);
 FileButton(488,77,540,99,'Haut',False);
 FileButton(548,77,607,99,'Relire',False);
 SetColor(COLOR_TEXT); OutTextXY(32,113,'Dossiers');
 OutTextXY(224,113,'Fichiers'); OutTextXY(520,113,'Octets');
 For K := 0 To 1 Do Begin
  If K=0 Then Begin
   X1 := 32; X2 := 210; Count := FileDirCount; TopIndex := FileDirTop; Selected := FileDirSel;
  End Else Begin
   X1 := 222; X2 := 607; Count := FileEntryCount; TopIndex := FileTop; Selected := FileSel;
  End;
  ScrollX := X2-14;
  SetFillStyle(SolidFill,COLOR_WINDOW); Bar(X1,128,X2,338);
  SetColor(COLOR_BORDER); Rectangle(X1,128,X2,338);
  For I := 0 To FD_ROWS-1 Do Begin
   If TopIndex+I>=Count Then Break;
   Y := 131+I*16;
   If TopIndex+I=Selected Then Begin
    SetFillStyle(SolidFill,COLOR_HIGHLIGHT);
    Bar(X1+1,Y-1,ScrollX-1,Y+13); SetColor(COLOR_WINDOW);
   End Else SetColor(COLOR_TEXT);
   If K=0 Then S := FileDirs[TopIndex+I].Name
   Else S := FileEntries[TopIndex+I].Name;
   If K=0 Then S := Copy(S,1,18) Else S := Copy(S,1,32);
   OutTextXY(X1+4,Y+2,S);
   If K=1 Then Begin
    Str(FileEntries[TopIndex+I].Size,SizeText);
    OutTextXY(ScrollX-4-Length(SizeText)*8,Y+2,SizeText);
   End;
  End;
  If FileFocus=K Then Begin
   SetColor(COLOR_HIGHLIGHT); Rectangle(X1-1,127,X2+1,339);
  End;
  FileButton(ScrollX,129,X2-1,145,'^',False);
  FileButton(ScrollX,321,X2-1,337,'v',False);
  SetFillStyle(SolidFill,COLOR_BG); Bar(ScrollX,146,X2-1,320);
  If Count>FD_ROWS Then Begin
   ThumbY := 146+LongInt(TopIndex)*150 Div (Count-FD_ROWS);
   FileButton(ScrollX,ThumbY,X2-1,ThumbY+24,'',False);
  End;
 End;
 SetColor(COLOR_TEXT); OutTextXY(32,358,'Nom:');
 Field(100,348,495,372,2,FileNameInput);
 If FileExportMode Then FileButton(510,348,607,372,'Exporter',FileFocus=5)
 Else If FileSaveMode Then FileButton(510,348,607,372,'Enregistrer',FileFocus=5)
 Else FileButton(510,348,607,372,'Ouvrir',FileFocus=5);
 SetColor(COLOR_TEXT); OutTextXY(32,391,'Type:');
 FileButton(100,382,495,406,Copy(FileFilterLabel(FileFilter),1,46)+' v',FileFocus=4);
 FileButton(510,382,607,406,'Annuler',FileFocus=6);
 Info := 'Tab : champ | Entree : valider | Echap : annuler';
 If FileExportMode Then
  Info := 'Page entiere. SVG/CDR9 : texte converti en courbes.'
 Else If FileSaveMode Then
  If FileFilter=2 Then Info := 'AI10 prive : conserve les objets ; pas un format Adobe.'
  Else Info := 'AI/EPS : texte Courier, contours fins ; AI10 pour les objets exacts.';
 If (FileSel>=0) And (FileSel<FileEntryCount) Then Begin
  UnpackTime(FileEntries[FileSel].Stamp,DT);
  Str(DT.Year,Info); Str(DT.Month,S); Info := Info+'-'+S;
  Str(DT.Day,S); Info := Info+'-'+S;
  Info := FileEntries[FileSel].Name+'  '+Info;
 End;
 SetColor(COLOR_TEXT);
 If FileDialogError<>'' Then Begin
  OutTextXY(30,412,Copy(FileDialogError,1,72));
  OutTextXY(30,426,Copy(FileDialogError,73,72));
 End Else OutTextXY(30,420,Copy(Info,1,72));
 If FileFilterOpen Then Begin
  SetFillStyle(SolidFill,COLOR_BG); Bar(100,FileFilterTop,495,380);
  SetColor(COLOR_TEXT); Rectangle(100,FileFilterTop,495,380);
  For I := 0 To FileFilterCount-1 Do Begin
   Y := FileFilterTop+2+I*21;
   If I=FileFilter Then Begin
    SetFillStyle(SolidFill,COLOR_HIGHLIGHT); Bar(102,Y,493,Y+20);
    SetColor(COLOR_WINDOW);
   End Else SetColor(COLOR_TEXT);
   OutTextXY(106,Y+6,Copy(FileFilterLabel(I),1,47));
  End;
 End;
 If FileOverwrite Then Begin
   SetFillStyle(SolidFill,COLOR_BG); Bar(90,170,550,290);
   SetColor(COLOR_TEXT); Rectangle(90,170,550,290);
   OutTextXY(105,185,'Ce fichier existe. Le remplacer ?');
   OutTextXY(105,207,Copy(PendingSaveName,1,53));
   FileButton(140,244,290,274,'Remplacer',True);
   FileButton(330,244,480,274,'Annuler',False);
 End;
End;

Procedure FileSelect(Index, List: Integer);
Begin
 FileFocus := List; FileReplace := False;
 If List=0 Then FileDirSel := Index
 Else Begin
  FileSel := Index;
  If (Index>=0) And (Index<FileEntryCount) Then
   FileNameInput := FileEntries[Index].Name;
 End;
 FileEnsureVisible;
 NeedsRedraw := True;
End;

Procedure HandleFileMouse;
Var List, Index, Count, TopIndex, SX, Delta: Integer; Now: LongInt;
Begin
 NeedsRedraw := True;
 If FileOverwrite Then Begin
  If (MouseY>=244) And (MouseY<=274) Then
   If (MouseX>=140) And (MouseX<=290) Then CompleteDialogSave
   Else If (MouseX>=330) And (MouseX<=480) Then FileOverwrite := False;
  Exit;
 End;
 If FileFilterOpen Then Begin
  If (MouseX>=100) And (MouseX<=495) And (MouseY>=FileFilterTop+2) And
     (MouseY<FileFilterTop+2+FileFilterCount*21) Then Begin
   ApplyFileFilter((MouseY-FileFilterTop-2) Div 21);
  End Else FileFilter := FileFilterSaved;
  FileFilterOpen := False; Exit;
 End;
 If ((MouseX>=590) And (MouseX<=615) And (MouseY>=47) And (MouseY<=64)) Or
    ((MouseX>=510) And (MouseX<=607) And (MouseY>=382) And (MouseY<=406)) Then Begin
  FileDialogActive := False; Exit;
 End;
 If (MouseY>=77) And (MouseY<=99) Then Begin
  If (MouseX>=100) And (MouseX<=478) Then Begin
   FileFocus := 3; FileCursor := Length(FilePathInput); FileReplace := True;
  End Else If (MouseX>=488) And (MouseX<=540) Then Begin
   If ScanFileDirectory(FileJoin(FilePath,'..')) Then FileNameInput := '';
  End Else If (MouseX>=548) And (MouseX<=607) Then ScanFileDirectory(FilePath);
  Exit;
 End;
 If (MouseX>=100) And (MouseX<=495) And (MouseY>=348) And (MouseY<=372) Then Begin
  FileFocus := 2; FileCursor := Length(FileNameInput); FileReplace := True; Exit;
 End;
 If (MouseX>=100) And (MouseX<=495) And (MouseY>=382) And (MouseY<=406) Then Begin
  FileFocus := 4; FileFilterSaved := FileFilter; FileFilterOpen := True; Exit;
 End;
 If (MouseX>=510) And (MouseX<=607) And (MouseY>=348) And (MouseY<=372) Then Begin
  FileFocus := 5; ActivateFileChoice; Exit;
 End;
 If (MouseY<129) Or (MouseY>337) Then Exit;
 List := -1;
 If (MouseX>=32) And (MouseX<=210) Then List := 0;
 If (MouseX>=222) And (MouseX<=607) Then List := 1;
 If List<0 Then Exit;
 If List=0 Then Begin Count := FileDirCount; TopIndex := FileDirTop; SX := 196; End
 Else Begin Count := FileEntryCount; TopIndex := FileTop; SX := 593; End;
 If MouseX>=SX Then Begin
  Delta := 0;
  If MouseY<146 Then Delta := -1
  Else If MouseY>320 Then Delta := 1
  Else If Count>FD_ROWS Then TopIndex :=
   LongInt(MouseY-146)*(Count-FD_ROWS) Div 174;
  Inc(TopIndex,Delta);
  If TopIndex>Count-FD_ROWS Then TopIndex := Count-FD_ROWS;
  If TopIndex<0 Then TopIndex := 0;
  If List=0 Then FileDirTop := TopIndex Else FileTop := TopIndex;
  Exit;
 End;
 Index := TopIndex+(MouseY-130) Div 16;
 If (Index<0) Or (Index>=Count) Then Exit;
 Now := ToolTipClock;
 FileSelect(Index,List);
 If (FileLastList=List) And (FileLastIndex=Index) And
    (Now>=FileLastClick) And (Now-FileLastClick<=50) Then Begin
  ActivateFileChoice;
  FileLastList := -1; FileLastIndex := -1;
 End Else Begin
  FileLastList := List; FileLastIndex := Index; FileLastClick := Now;
 End;
End;

Procedure HandleFileKey(Key, ExtKey: Char);
Var S: String; Index, Count, Step: Integer;
Begin
 NeedsRedraw := True;
 FileLastIndex := -1; FileLastList := -1;
 If FileOverwrite Then Begin
  If Key=#27 Then FileOverwrite := False
  Else If Key=#13 Then CompleteDialogSave;
  Exit;
 End;
 If Key=#27 Then Begin
  If FileFilterOpen Then Begin
   FileFilter := FileFilterSaved; FileFilterOpen := False;
  End Else FileDialogActive := False;
  Exit;
 End;
 If FileFilterOpen Then Begin
  If (Key=#0) And (ExtKey=#72) And (FileFilter>0) Then Dec(FileFilter);
  If (Key=#0) And (ExtKey=#80) And (FileFilter<FileFilterCount-1) Then Inc(FileFilter);
  If Key=#13 Then Begin
   FileFilterOpen := False;
   ApplyFileFilter(FileFilter);
  End;
  Exit;
 End;
 If (Key=#9) Or ((Key=#0) And (ExtKey=#15)) Then Begin
  If Key=#9 Then FileFocus := (FileFocus+1) Mod 7
  Else FileFocus := (FileFocus+6) Mod 7;
  FileReplace := FileFocus In [2,3];
  If FileFocus=2 Then FileCursor := Length(FileNameInput);
  If FileFocus=3 Then FileCursor := Length(FilePathInput);
  Exit;
 End;
 If Key=#13 Then Begin
  If FileFocus=6 Then FileDialogActive := False
  Else If FileFocus=4 Then Begin
   FileFilterSaved := FileFilter; FileFilterOpen := True;
  End
  Else ActivateFileChoice;
  Exit;
 End;
 If (Key=#0) And (ExtKey=#63) Then Begin ScanFileDirectory(FilePath); Exit; End;
 If FileFocus In [2,3] Then Begin
  If FileFocus=2 Then S := FileNameInput Else S := FilePathInput;
  If Key=#1 Then Begin FileReplace := True; FileCursor := Length(S); Exit; End;
  If (Key=#8) Or (Key>=#32) Or ((Key=#0) And (ExtKey=#83)) Then Begin
   If FileReplace Then Begin S := ''; FileCursor := 0; End;
   FileReplace := False;
   If Key=#8 Then Begin
    If FileCursor>0 Then Begin Delete(S,FileCursor,1); Dec(FileCursor); End;
   End Else If Key=#0 Then Delete(S,FileCursor+1,1)
   Else If Length(S)<255 Then Begin Insert(Key,S,FileCursor+1); Inc(FileCursor); End
   Else FileDialogError := 'Nom ou chemin limite a 255 caracteres.';
  End Else If Key=#0 Then Begin
   FileReplace := False;
   Case ExtKey Of
    #75: If FileCursor>0 Then Dec(FileCursor);
    #77: If FileCursor<Length(S) Then Inc(FileCursor);
    #71: FileCursor := 0;
    #79: FileCursor := Length(S);
   End;
  End;
  If FileFocus=2 Then FileNameInput := S Else FilePathInput := S;
  Exit;
 End;
 If FileFocus In [0,1] Then Begin
  If Key=#8 Then Begin
   If ScanFileDirectory(FileJoin(FilePath,'..')) Then FileNameInput := '';
   Exit;
  End;
  If FileFocus=0 Then Begin Index := FileDirSel; Count := FileDirCount; End
  Else Begin Index := FileSel; Count := FileEntryCount; End;
  If Count=0 Then Exit;
  Step := 0;
  If Key=#0 Then Case ExtKey Of
   #72: Step := -1;
   #80: Step := 1;
   #73: Step := -FD_ROWS;
   #81: Step := FD_ROWS;
   #71: Index := 0;
   #79: Index := Count-1;
  End;
  Inc(Index,Step);
  If Index<0 Then Index := 0;
  If Index>=Count Then Index := Count-1;
  If Key=#0 Then FileSelect(Index,FileFocus);
 End;
End;

Procedure ExecuteMenuItem(M, I: Integer);
Var Command: Byte;
Begin
 Command := Menus[M].Items[I].Command;
 If Command = CMD_NONE Then Begin
  StatusMessage := 'Commande non implementee.';
  NeedsRedraw := True;
  Exit;
 End;
 CloseMenu;
 Case Command Of
  CMD_EXPORT: StartExportDialog;
  CMD_SAVE_AS: StartSaveDialog;
  CMD_SAVE:
   If CurrentFile='' Then StartSaveDialog
   Else If Not SaveDocument(CurrentFile,CurrentSaveFormat) Then Begin
    StartSaveDialog;
    FileDialogError := SaveError;
   End;
  CMD_OPEN:
   If FileModified Then
    ShowDialog('Ouvrir un document',
     'Dessin modifie : Entree = ouvrir sans enregistrer, Echap = annuler.')
   Else StartFileDialog;
  CMD_NEW:
   If FileModified Then
    ShowDialog('Nouveau document',
               'Dessin modifie : Entree = effacer, Echap = annuler.')
   Else Begin
    ObjectCount := 0;
    SelectedObject := -1;
    CurrentFile := '';
    CurrentSaveFormat := 0;
    FileModified := False;
    ResetZoom;
   End;
  CMD_EXIT:
   If FileModified Then
    ShowDialog('Quitter',
               'Dessin modifie : Entree = quitter, Echap = annuler.')
   Else Running := False;
  CMD_GRID: GridVisible := Not GridVisible;
  CMD_ZOOM_IN: ChangeZoom(1,TOOLBAR_WIDTH+(ScreenWidth-TOOLBAR_WIDTH) Div 2,
                          MENUBAR_HEIGHT+(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT) Div 2);
  CMD_ZOOM_OUT: ChangeZoom(-1,TOOLBAR_WIDTH+(ScreenWidth-TOOLBAR_WIDTH) Div 2,
                           MENUBAR_HEIGHT+(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT) Div 2);
  CMD_ZOOM_RESET: ResetZoom;
  CMD_HELP:
   ShowDialog('Aide', 'Prototype incomplet. Les commandes grisees sont indisponibles.');
  CMD_SHORTCUTS:
   ShowDialog('Raccourcis', 'Ctrl+O/S : ouvrir/sauver. F12 : sauver sous. F10 : menus.');
  CMD_ABOUT:
   ShowDialog('A propos', 'CloneDRAW AI - prototype Pascal, pas un clone complet.');
  CMD_RESOURCES:
   ShowDialog('Ressources', 'https://www.gladir.com/clonedraw');
  CMD_TIPS:
   ShowDialog('Astuces', 'Cliquez un menu, survolez ses lignes, cliquez pour agir.');
 End;
End;

Procedure FinishText(CancelEmpty: Boolean);
Begin
 If TextObject.TextObj.Text = '' Then Begin
  If Not CancelEmpty Then Begin
   StatusMessage := 'Texte vide : saisir du texte ou Echap pour annuler.';
   Exit;
  End;
  StatusMessage := 'Saisie vide annulee.';
 End Else Begin
  If TextEditIndex >= 0 Then Begin
   If TextObject.TextObj.Text <> Objects[TextEditIndex].TextObj.Text Then Begin
    Objects[TextEditIndex] := TextObject;
    FileModified := True;
   End;
  End Else Begin
   Objects[ObjectCount] := TextObject;
   Inc(ObjectCount);
   FileModified := True;
  End;
  StatusMessage := 'Texte valide. Fleche : deplacer. Outil Texte : modifier.';
 End;
 TextActive := False;
 NeedsRedraw := True;
End;

Procedure HandleMouseEvent;
Var BarHit, ItemHit: Integer; Pressed, Released, RightPressed: Boolean;
Begin
 Pressed := ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0);
 Released := ((MouseButtons And 1) = 0) And ((OldMouseButtons And 1) <> 0);
 RightPressed := ((MouseButtons And 2) <> 0) And ((OldMouseButtons And 2) = 0);
 If (BezierStage <> 0) And Pressed Then
  If (MenuBarHitTest(MouseX,MouseY) >= 0) Or
     (ToolHitTest(MouseX,MouseY) >= 0) Then CancelBezier;
 If TextActive And Pressed Then
  If (MenuBarHitTest(MouseX,MouseY) >= 0) Or
     (ToolHitTest(MouseX,MouseY) >= 0) Then FinishText(True);
 If FileDialogActive Then Begin
  If Pressed Then HandleFileMouse;
 End Else If TextActive Then Begin
  If Pressed Then Begin
   StatusMessage := 'Valider par un clic outil/menu ou Entree ; Echap annule.';
   NeedsRedraw := True;
  End;
 End Else If DialogTitle <> '' Then Begin
  If Pressed Then Begin
   DialogTitle := '';
   NeedsRedraw := True;
  End;
 End Else Begin
  BarHit := MenuBarHitTest(MouseX, MouseY);
  If MenuActive And
     ((MouseX <> OldMouseX) Or (MouseY <> OldMouseY)) Then Begin
   { Ne pas basculer avant le clic : un second clic doit fermer le titre. }
   If (BarHit >= 0) And (BarHit <> ActiveMenu) And Not Pressed Then
    OpenMenu(BarHit);
   ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
   If ItemHit <> ActiveMenuItem Then Begin
    ActiveMenuItem := ItemHit;
    StatusMessage := '';
    If ItemHit >= 0 Then
     If Menus[ActiveMenu].Items[ItemHit].Command = CMD_NONE Then
      StatusMessage := 'Commande non implementee.';
    NeedsRedraw := True;
   End;
  End;
  If RightPressed And Not Pressed And (CurrentTool = TOOL_ZOOM) And
     Not MenuActive And Not DrawingMode And
     (MouseX >= TOOLBAR_WIDTH) And (MouseX < ScreenWidth) And
     (MouseY >= MENUBAR_HEIGHT) And
     (MouseY < ScreenHeight-STATUSBAR_HEIGHT) Then Begin
   ChangeZoom(-1,MouseX,MouseY);
  End Else If Pressed Then Begin
   If BarHit >= 0 Then Begin
    MenuMouseDown := True;
    If MenuActive And (ActiveMenu = BarHit) Then CloseMenu
    Else OpenMenu(BarHit);
   End Else If MenuActive Then Begin
    MenuMouseDown := True;
    ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
    If ItemHit >= 0 Then ExecuteMenuItem(ActiveMenu, ItemHit)
    Else CloseMenu;
   End Else Begin
    HandleMouseClick;
    NeedsRedraw := True;
   End;
  End Else If Panning And ((MouseButtons And 1) <> 0) Then Begin
   If (MouseX <> OldMouseX) Or (MouseY <> OldMouseY) Then UpdatePan;
  End Else If (BezierStage <> 0) And Not Released And
              ((MouseX <> OldMouseX) Or (MouseY <> OldMouseY)) Then Begin
   UpdateBezier;
  End Else If PencilActive And ((MouseButtons And 1) <> 0) Then Begin
   AddPencilPoint;
  End Else If EditingObject And ((MouseButtons And 1) <> 0) Then Begin
   If (MouseX <> OldMouseX) Or (MouseY <> OldMouseY) Then UpdateObjectEdit;
  End Else If Released Then Begin
   If MenuMouseDown Then Begin
    { Autorise aussi appuyer sur le titre, glisser, puis relacher sur un item. }
    If MenuActive Then Begin
     ItemHit := MenuItemHitTest(MouseX, MouseY, ActiveMenu);
     If ItemHit >= 0 Then ExecuteMenuItem(ActiveMenu, ItemHit);
    End;
   End Else Begin
    HandleMouseRelease;
    NeedsRedraw := True;
   End;
  End;
 End;
 If Released Then MenuMouseDown := False;
 UpdateToolTipAt(ToolTipClock);
 OldMouseButtons := MouseButtons;
 OldMouseX := MouseX;
 OldMouseY := MouseY;
End;

Procedure MenuNextItem(Step: Integer);
Var I, N, Item: Integer;
Begin
 N := Menus[ActiveMenu].ItemCount;
 Item := ActiveMenuItem;
 If (Item < 0) And (Step < 0) Then Item := N;
 For I := 1 To N Do Begin
  Item := (Item+Step+N) Mod N;
  If Menus[ActiveMenu].Items[Item].Command <> CMD_NONE Then Begin
   ActiveMenuItem := Item;
   NeedsRedraw := True;
   Exit;
  End;
 End;
End;

Procedure HandleKey(Key, ExtKey: Char);
Var S: String; Capacity: Integer;
Begin
 ResetToolTip;
 NeedsRedraw := True;
 If FileDialogActive Then Begin HandleFileKey(Key,ExtKey); Exit; End;
 If ((Key In [#15,#19]) Or ((Key=#0) And (ExtKey=#134))) And
    Not DrawingMode And (DialogTitle='') Then Begin
  If TextActive Then FinishText(True);
  If Key=#15 Then ExecuteMenuItem(MENU_FILE,1)
  Else If Key=#0 Then ExecuteMenuItem(MENU_FILE,3)
  Else ExecuteMenuItem(MENU_FILE,2);
  Exit;
 End;
 If Panning Then Begin
  If Key = #27 Then Begin
   ViewX := PanViewX; ViewY := PanViewY;
   Panning := False;
   DrawingMode := False;
   StatusMessage := 'Deplacement de la vue annule.';
  End;
  Exit;
 End;
 If BezierStage <> 0 Then Begin
  If Key = #27 Then CancelBezier;
  Exit;
 End;
 If Not TextActive And Not MenuActive And (DialogTitle = '') And
    Not DrawingMode And Not EditingObject And (CurrentTool = TOOL_SELECT) And
    (SelectedObject >= 0) And (SelectedObject < ObjectCount) Then
  If Objects[SelectedObject].Visible And
     (Objects[SelectedObject].ObjType = OBJ_TEXT) And
     ((Key >= #32) Or (Key = #8) Or
      ((Key = #0) And (ExtKey In [#75,#77,#71,#79,#83]))) Then
   BeginTextInput(SelectedObject);
 If TextActive Then Begin
  S := TextObject.TextObj.Text;
  Case Key Of
   #27: Begin
    TextActive := False;
    StatusMessage := 'Saisie annulee.';
   End;
   #13: FinishText(False);
   #8: If TextCursor > 0 Then Begin
    Delete(S,TextCursor,1); Dec(TextCursor);
   End;
   #0: Case ExtKey Of
    #75: If TextCursor > 0 Then Dec(TextCursor);
    #77: If TextCursor < Length(S) Then Inc(TextCursor);
    #71: TextCursor := 0;
    #79: TextCursor := Length(S);
    #83: If TextCursor < Length(S) Then Delete(S,TextCursor+1,1);
   End;
   #32..#255: Begin
    Capacity := (ScreenWidth-TOOLBAR_WIDTH-Round(TextObject.TextObj.X)) Div 8;
    If (Length(S) < 255) And (Length(S) < Capacity) Then Begin
     Insert(Key,S,TextCursor+1);
     Inc(TextCursor);
    End Else StatusMessage := 'Limite de texte / bord de page atteint.';
   End;
  End;
  TextObject.TextObj.Text := S;
  Exit;
 End;
 If PencilActive Then Begin
  If Key = #27 Then Begin
   PencilActive := False;
   DrawingMode := False;
   StatusMessage := 'Trait annule.';
  End;
  Exit;
 End;
 If EditingObject Then Begin
  If Key = #27 Then CancelObjectEdit;
  Exit;
 End;
 If DialogTitle <> '' Then Begin
  If Key = #13 Then Begin
   If DialogTitle = 'Ouvrir un document' Then StartFileDialog;
   If DialogTitle = 'Quitter' Then Running := False;
   If DialogTitle = 'Nouveau document' Then Begin
    ObjectCount := 0;
    SelectedObject := -1;
    CurrentFile := '';
    CurrentSaveFormat := 0;
    FileModified := False;
    ResetZoom;
   End;
  End;
  DialogTitle := '';
  Exit;
 End;
 If (Key = #0) And (ExtKey = #68) Then Begin
  If MenuActive Then CloseMenu Else OpenMenu(MENU_FILE);
  Exit;
 End;
 If MenuActive Then Begin
  Case Key Of
   #27: CloseMenu;
   #13: If ActiveMenuItem >= 0 Then ExecuteMenuItem(ActiveMenu, ActiveMenuItem);
   #0: Case ExtKey Of
    #75: OpenMenu((ActiveMenu+MAX_MENUS-1) Mod MAX_MENUS);
    #77: OpenMenu((ActiveMenu+1) Mod MAX_MENUS);
    #72: MenuNextItem(-1);
    #80: MenuNextItem(1);
   End;
  End;
  Exit;
 End;
 Case Key Of
  #27: ExecuteMenuItem(MENU_FILE, 6);
  '1': Begin
   CurrentTool := TOOL_SELECT;
   StatusMessage := 'Cliquer un objet, glisser pour deplacer, poignees pour la taille.';
  End;
  '2': CurrentTool := TOOL_RECTANGLE;
  '3': CurrentTool := TOOL_ELLIPSE;
  '4': CurrentTool := TOOL_LINE;
  '5','b','B': CurrentTool := TOOL_BEZIER;
  '7','p','P': CurrentTool := TOOL_PEN;
  '6','n','N': CurrentTool := TOOL_PENCIL;
  '8','t','T': CurrentTool := TOOL_TEXT;
  '9','z','Z': Begin
   CurrentTool := TOOL_ZOOM;
   StatusMessage := 'Loupe : clic gauche = agrandir, droit = reduire ; 0 = 100 %.';
  End;
  'h','H': Begin
   CurrentTool := TOOL_HAND;
   StatusMessage := 'Main : cliquer-glisser pour deplacer la vue agrandie.';
  End;
  '0': ResetZoom;
  #15: ExecuteMenuItem(MENU_FILE,1);
  #19: ExecuteMenuItem(MENU_FILE,2);
 End;
End;

Procedure RedrawInterface;
Var I: Integer;
Begin
 HideMouse;
 SetViewPort(TOOLBAR_WIDTH,MENUBAR_HEIGHT,ScreenWidth-1,
             ScreenHeight-STATUSBAR_HEIGHT-1,True);
 DrawCanvas;
 For I := 0 To ObjectCount-1 Do
  If Not TextActive Or (I <> TextEditIndex) Then DrawObject(I);
 If TextActive Then Begin
  DrawGraphicObject(TextObject);
  SetColor(COLOR_TEXT);
  I := ScreenX(TextObject.TextObj.X+TextCursor*8);
  Line(I,ScreenY(TextObject.TextObj.Y),I,ScreenY(TextObject.TextObj.Y+8)-1);
 End;
 If PencilActive Then DrawGraphicObject(PencilObject);
 If BezierStage <> 0 Then Begin
  DrawGraphicObject(BezierObject);
  DrawBezierHandles(BezierObject,True);
 End;
 DrawSelection;
 SetViewPort(0,0,ScreenWidth-1,ScreenHeight-1,True);
 DrawToolbar;
 DrawMenuBar;
 DrawStatusBar;
 { Les menus et dialogues doivent etre dessines APRES le document. }
 DrawMenu;
 If DialogTitle <> '' Then Begin
  SetFillStyle(SolidFill, COLOR_WINDOW);
  Bar(45, 160, ScreenWidth-45, 280);
  SetColor(COLOR_TEXT);
  Rectangle(45, 160, ScreenWidth-45, 280);
  OutTextXY(58, 175, DialogTitle);
  OutTextXY(58, 205, DialogText);
  OutTextXY(58, 250, 'Entree / Echap. Un clic ferme sans confirmer.');
 End;
 If FileDialogActive Then DrawFileDialog;
 DrawToolTip;
 ShowMouse;
 NeedsRedraw := False;
End;

Function ValidImportObject(Obj: TGraphicObject): Boolean;
Var B: TBounds; I: Integer;
Begin
 ValidImportObject := False;
 If Obj.ObjType > OBJ_FILLED_PATH Then Exit;
 If Obj.ObjType In [OBJ_PATH,OBJ_BEZIER,OBJ_FILLED_PATH] Then Begin
  If (Obj.Path.PointCount < 1) Or (Obj.Path.PointCount > 100) Then Exit;
  If (Obj.ObjType = OBJ_BEZIER) And (Obj.Path.PointCount <> 4) Then Exit;
  For I := 0 To Obj.Path.PointCount-1 Do
   If Not ((Obj.Path.Points[I].X >= 0) And
           (Obj.Path.Points[I].X < ScreenWidth-TOOLBAR_WIDTH) And
           (Obj.Path.Points[I].Y >= 0) And
           (Obj.Path.Points[I].Y <
            ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT)) Then Exit;
  If (Obj.Path.StrokeColor > 15) Or (Obj.Path.FillColor > 15) Then Exit;
 End;
 If Obj.ObjType = OBJ_TEXT Then
  If (Obj.TextObj.Text = '') Or (Obj.TextObj.Color > 15) Then Exit;
 If Obj.ObjType = OBJ_TEXT Then
  For I := 1 To Length(Obj.TextObj.Text) Do
   If Obj.TextObj.Text[I]<#32 Then Exit;
 If Obj.ObjType = OBJ_RECT Then
  If Not ((Obj.Rectangle.Width >= 0) And (Obj.Rectangle.Height >= 0)) Or
     (Obj.Rectangle.StrokeColor > 15) Or (Obj.Rectangle.FillColor > 15) Then Exit;
 If Obj.ObjType = OBJ_ELLIPSE Then
  If Not ((Obj.Ellipse.RX >= 0) And (Obj.Ellipse.RY >= 0)) Or
     (Obj.Ellipse.StrokeColor > 15) Or (Obj.Ellipse.FillColor > 15) Then Exit;
 If Obj.ObjType = OBJ_LINE Then
  If Obj.Line.StrokeColor > 15 Then Exit;
 B := ObjectBounds(Obj);
 ValidImportObject := (B.L >= 0) And (B.T >= 0) And
  (B.R >= B.L) And (B.B >= B.T) And
  (B.R < ScreenWidth-TOOLBAR_WIDTH) And
  (B.B < ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT);
End;

Function ReadLegacyDocument(Name: String): Boolean;
Var F: File; Sig: Array[0..3] Of Char; Ver: Word;
 Count, I, Code: Integer; Got: Word; Good: Boolean;
Begin
 ReadLegacyDocument := False;
 {$I-}
 Assign(F,Name); Reset(F,1); Code := IOResult;
 {$I+}
 If Code <> 0 Then Begin ImportError := 'Impossible de lire le fichier AI10.'; Exit; End;
 {$I-}
 BlockRead(F,Sig,4,Got); Code := IOResult;
 Good := (Code=0) And (Got=4);
 BlockRead(F,Ver,2,Got); Code := IOResult;
 Good := Good And (Code=0) And (Got=2) And (Ver=AI_VERSION);
 BlockRead(F,Count,2,Got); Code := IOResult;
 Good := Good And (Code=0) And (Got=2) And (Count>=0) And (Count<=MAX_OBJECTS);
 If Good Then Begin
  Good := FileSize(F)=8+LongInt(Count)*SizeOf(TGraphicObject);
  Code := IOResult;
  Good := Good And (Code=0);
 End;
 {$I+}
 If Good Then
  For I := 0 To Count-1 Do Begin
   {$I-}
   BlockRead(F,ImportObjects[I],SizeOf(TGraphicObject),Got);
   Code := IOResult;
   {$I+}
   If (Code<>0) Or (Got<>SizeOf(TGraphicObject)) Then Good := False
   Else If Not ValidImportObject(ImportObjects[I]) Then Good := False;
   If Not Good Then Break;
  End;
 {$I-} Close(F); Code := IOResult; {$I+}
 If Not Good Or (Code<>0) Then Begin
  ImportError := 'AI10 invalide, tronque ou incompatible avec cette version.';
  Exit;
 End;
 ImportCount := Count;
 ReadLegacyDocument := True;
End;

Function ImportPaletteColor(R, G, B: Real): Byte;
Const
 RGB: Array[0..15,0..2] Of Byte =
  ((0,0,0),(0,0,170),(0,170,0),(0,170,170),
   (170,0,0),(170,0,170),(170,85,0),(170,170,170),
   (85,85,85),(85,85,255),(85,255,85),(85,255,255),
   (255,85,85),(255,85,255),(255,255,85),(255,255,255));
Var I: Integer; D, Best: Real;
Begin
 Best := 1E20; ImportPaletteColor := 0;
 For I := 0 To 15 Do Begin
  D := Sqr(R*255-RGB[I,0])+Sqr(G*255-RGB[I,1])+Sqr(B*255-RGB[I,2]);
  If D < Best Then Begin Best := D; ImportPaletteColor := I; End;
 End;
End;

Function ReadIllustratorDocument(Name: String): Boolean;
Var F: Text; Ch: Char; Token, Comment, Header: String;
 Stack: Array[0..31] Of Real; SP, Code, I, J, SkipDepth: Integer;
 N, Scale, Left, Bottom, Right, Top, R, G, B: Real;
 HaveBox, Done, PageEnded, StringToken: Boolean; Stroke, Fill: Byte; Width: Real;
 FontStage: Integer;
 Path, Curve: TGraphicObject; P: TPoint2D;

 Procedure Fail(S: String);
 Begin
  If ImportError = '' Then ImportError := S;
 End;

 Function Numbers(S: String; Count: Integer): Boolean;
 Var T: String; Posn, K, Err: Integer;
 Begin
  Numbers := False; Posn := 1;
  For K := 0 To Count-1 Do Begin
   While (Posn<=Length(S)) And (S[Posn]<=' ') Do Inc(Posn);
   T := '';
   While (Posn<=Length(S)) And (S[Posn]>' ') Do Begin
    T := T+S[Posn]; Inc(Posn);
   End;
   Val(T,Stack[K],Err);
   If (Err<>0) Or Not ((Stack[K]>=-1000000) And
                        (Stack[K]<=1000000)) Then Exit;
  End;
  While (Posn<=Length(S)) And (S[Posn]<=' ') Do Inc(Posn);
  Numbers := Posn>Length(S);
 End;

 Function NextToken: Boolean;
 Begin
  Token := ''; NextToken := False; StringToken := False;
  While Not Eof(F) And (ImportError='') Do Begin
   Read(F,Ch);
   If IOResult<>0 Then Begin Fail('Erreur de lecture PostScript.'); Exit; End;
   If Ch='%' Then Begin
    ReadLn(F,Comment);
    If IOResult<>0 Then Begin Fail('Erreur de lecture PostScript.'); Exit; End;
    If (Comment='%BeginProlog') Or (Pos('%BeginResource:',Comment)=1) Then
     Inc(SkipDepth);
    If (Comment='%EndProlog') Or (Comment='%EndResource') Then Begin
     If SkipDepth>0 Then Dec(SkipDepth);
    End;
    If (Pos('%BoundingBox:',Comment)=1) And Not HaveBox Then Begin
     If Numbers(Copy(Comment,14,255),4) Then Begin
      Left := Stack[0]; Bottom := Stack[1]; Right := Stack[2]; Top := Stack[3];
      If (Right<=Left) Or (Top<=Bottom) Then Fail('BoundingBox invalide.')
      Else Begin
       Scale := MinReal((ScreenWidth-TOOLBAR_WIDTH-1)/(Right-Left),
        (ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1)/(Top-Bottom));
       If Scale>1 Then Scale := 1;
       HaveBox := True;
      End;
     End Else Fail('BoundingBox numerique requise avant le dessin.');
    End;
    If (Comment='%Trailer') Or (Comment='%EOF') Then Begin
     Done := True; Exit;
    End;
   End Else If (SkipDepth=0) And (Ch='(') Then Begin
    StringToken := True;
    While Not Eof(F) Do Begin
     Read(F,Ch);
     If IOResult<>0 Then Begin Fail('Erreur de lecture du texte.'); Exit; End;
     If Ch=')' Then Begin NextToken := True; Exit; End;
     If Ch='\' Then Begin
      If Eof(F) Then Break;
      Read(F,Ch);
      If IOResult<>0 Then Begin Fail('Erreur de lecture du texte.'); Exit; End;
      If Not (Ch In ['(',')','\']) Then Begin
       Fail('Echappement PostScript non pris en charge.'); Exit;
      End;
     End Else If Ch='(' Then Begin Fail('Texte imbrique non pris en charge.'); Exit; End;
     If (Ch<#32) Or (Length(Token)=255) Then Begin
      Fail('Texte PostScript invalide ou trop long.'); Exit;
     End;
     Token := Token+Ch;
    End;
    Fail('Texte PostScript non termine.'); Exit;
   End Else If (SkipDepth=0) And (Ch>' ') Then Begin
    Token := Ch;
    While Not Eof(F) Do Begin
     Read(F,Ch);
     If IOResult<>0 Then Begin Fail('Erreur de lecture PostScript.'); Exit; End;
     If Ch<=' ' Then Break;
     If Length(Token)=255 Then Begin Fail('Jeton PostScript trop long.'); Exit; End;
     Token := Token+Ch;
    End;
    NextToken := True; Exit;
   End;
  End;
 End;

 Function Need(Count: Integer): Boolean;
 Begin
  Need := (SP=Count) And HaveBox;
  If Not HaveBox Then Fail('BoundingBox absente.')
  Else If SP<>Count Then Fail('Operandes invalides pour '+Token+'.');
 End;

 Procedure AddPoint(X,Y: Real);
 Var K: Integer;
 Begin
  If ImportError<>'' Then Exit;
  If (X<Left) Or (X>Right) Or (Y<Bottom) Or (Y>Top) Then Begin
   Fail('Point hors BoundingBox : import refuse.'); Exit;
  End;
  K := Path.Path.PointCount;
  If K=100 Then Begin Fail('Limite : 100 points par chemin importe.'); Exit; End;
  Path.Path.Points[K].X := (X-Left)*Scale;
  Path.Path.Points[K].Y := (Top-Y)*Scale;
  Inc(Path.Path.PointCount);
 End;

 Procedure PaintPath;
 Var IsFill, IsStroke: Boolean;
 Begin
  If Not Need(0) Then Exit;
  If Path.Path.PointCount=0 Then Begin Fail('Chemin vide.'); Exit; End;
  If (Token='n') Or (Token='N') Or (Token='newpath') Then Begin
   Path.Path.PointCount := 0; Path.Path.Closed := False; Exit;
  End;
  IsFill := (Token='f') Or (Token='F') Or (Token='fill') Or
            (Token='B') Or (Token='b');
  IsStroke := Not ((Token='f') Or (Token='F') Or (Token='fill'));
  If (Token='s') Or (Token='b') Or IsFill Then Path.Path.Closed := True;
  If IsFill And (Path.Path.PointCount<3) Then Begin Fail('Remplissage invalide.'); Exit; End;
  If ImportCount=MAX_OBJECTS Then Begin Fail('Limite : 100 objets par document.'); Exit; End;
  Path.ObjType := OBJ_PATH;
  If IsFill Then Path.ObjType := OBJ_FILLED_PATH;
  Path.Path.FillColor := Fill;
  Path.Path.StrokeColor := Stroke;
  If Not IsStroke Then Path.Path.StrokeColor := Fill;
  Path.Path.StrokeWidth := Width;
  ImportObjects[ImportCount] := Path;
  Inc(ImportCount);
  Path.Path.PointCount := 0; Path.Path.Closed := False;
 End;

Begin
 ReadIllustratorDocument := False;
 {$I-} Assign(F,Name); Reset(F); Code := IOResult; {$I+}
 If Code<>0 Then Begin ImportError := 'Impossible de lire le fichier.'; Exit; End;
 HaveBox := False; Done := False; PageEnded := False; SkipDepth := 0; SP := 0;
 FontStage := 0;
 Stroke := 0; Fill := 0; Width := 1;
 FillChar(Path,SizeOf(Path),0); Path.Visible := True;
 {$I-}
 ReadLn(F,Header); Code := IOResult;
 {$I+}
 If (Code<>0) Or (Copy(Header,1,4)<>'%!PS') Then
  Fail('Format inconnu : AI PostScript/EPS ou AI10 attendu.');
 {$I-}
 While (ImportError='') And Not Done And Not Eof(F) Do Begin
  If Not NextToken Then Break;
  Code := IOResult;
  If Code<>0 Then Begin Fail('Erreur de lecture PostScript.'); Break; End;
  If PageEnded Then Begin Fail('Documents multipages non pris en charge.'); Break; End;
  If StringToken Then Begin
   Header := Token;
   If Not NextToken Or (Token<>'show') Or (FontStage<>3) Or (SP<>0) Or
      (Path.Path.PointCount<>1) Or (Header='') Then Begin
    Fail('Texte PostScript non pris en charge.'); Break;
   End;
   If ImportCount=MAX_OBJECTS Then Begin Fail('Limite : 100 objets.'); Break; End;
   FillChar(Curve,SizeOf(Curve),0); Curve.ObjType := OBJ_TEXT; Curve.Visible := True;
   Curve.TextObj.X := Path.Path.Points[0].X;
   Curve.TextObj.Y := Path.Path.Points[0].Y-7;
   Curve.TextObj.Text := Header; Curve.TextObj.Color := Stroke; Curve.TextObj.FontSize := 8;
   If Not ValidImportObject(Curve) Then Begin
    Fail('Texte hors de la page ou format non pris en charge.'); Break;
   End;
   ImportObjects[ImportCount] := Curve; Inc(ImportCount);
   Path.Path.PointCount := 0; Path.Path.Closed := False;
   Continue;
  End;
  Val(Token,N,Code);
  If Code=0 Then Begin
   If Not ((N>=-1000000) And (N<=1000000)) Then Fail('Nombre hors limites.')
   Else If SP=32 Then Fail('Pile PostScript trop longue.')
   Else Begin Stack[SP] := N; Inc(SP); End;
  End Else Begin
   If Token='/Courier' Then Begin
    If Not Need(0) Then Break;
    FontStage := 1;
   End Else If Token='findfont' Then Begin
    If (FontStage<>1) Or Not Need(0) Then Begin Fail('Police non prise en charge.'); Break; End;
   End Else If Token='scalefont' Then Begin
    If (FontStage<>1) Or Not Need(1) Then Begin Fail('Police non prise en charge.'); Break; End;
    If Abs(Stack[0]-13.333333)>0.00001 Then Begin
     Fail('Taille de texte non prise en charge.'); Break;
    End;
    FontStage := 2;
   End Else If Token='setfont' Then Begin
    If (FontStage<>2) Or Not Need(0) Then Begin Fail('Police non prise en charge.'); Break; End;
    FontStage := 3;
   End Else If (Token='m') Or (Token='moveto') Then Begin
    If Need(2) Then
     If Path.Path.PointCount<>0 Then Fail('Chemins composes non pris en charge.')
     Else AddPoint(Stack[0],Stack[1]);
   End Else If (Token='l') Or (Token='lineto') Then Begin
    If Need(2) Then
     If Path.Path.PointCount=0 Then Fail('Ligne sans point de depart.')
     Else If Path.Path.Closed Then Fail('Segment apres fermeture non pris en charge.')
     Else AddPoint(Stack[0],Stack[1]);
   End Else If (Token='c') Or (Token='curveto') Or (Token='v') Or (Token='y') Then Begin
    J := 6; If (Token='v') Or (Token='y') Then J := 4;
    If Need(J) Then Begin
     I := Path.Path.PointCount-1;
     If I<0 Then Fail('Courbe sans point de depart.')
     Else If Path.Path.Closed Then Fail('Segment apres fermeture non pris en charge.')
     Else Begin
      Curve.Path.Points[0].X := Left+Path.Path.Points[I].X/Scale;
      Curve.Path.Points[0].Y := Top-Path.Path.Points[I].Y/Scale;
      If Token='v' Then Begin
       Curve.Path.Points[1] := Curve.Path.Points[0];
       Curve.Path.Points[2].X := Stack[0]; Curve.Path.Points[2].Y := Stack[1];
       Curve.Path.Points[3].X := Stack[2]; Curve.Path.Points[3].Y := Stack[3];
      End Else Begin
       Curve.Path.Points[1].X := Stack[0]; Curve.Path.Points[1].Y := Stack[1];
       Curve.Path.Points[2].X := Stack[2]; Curve.Path.Points[2].Y := Stack[3];
       Curve.Path.Points[3] := Curve.Path.Points[2];
       If J=6 Then Begin
        Curve.Path.Points[3].X := Stack[4]; Curve.Path.Points[3].Y := Stack[5];
       End;
      End;
      For I := 1 To 24 Do Begin
       P := BezierPoint(Curve,I/24); AddPoint(P.X,P.Y);
      End;
     End;
    End;
   End Else If (Token='h') Or (Token='closepath') Then Begin
    If Need(0) Then
     If Path.Path.PointCount=0 Then Fail('Fermeture sans chemin.')
     Else Path.Path.Closed := True;
   End Else If (Token='S') Or (Token='s') Or (Token='stroke') Or
    (Token='f') Or (Token='F') Or (Token='fill') Or (Token='B') Or
    (Token='b') Or (Token='n') Or (Token='N') Then PaintPath
   Else If Token='newpath' Then Begin
    If Need(0) Then Begin Path.Path.PointCount := 0; Path.Path.Closed := False; End;
   End Else If (Token='g') Or (Token='G') Or (Token='setgray') Or
    (Token='rg') Or (Token='RG') Or
    (Token='k') Or (Token='K') Or (Token='setrgbcolor') Or
    (Token='setcmykcolor') Then Begin
    J := 1;
    If (Token='rg') Or (Token='RG') Or (Token='setrgbcolor') Then J := 3;
    If (Token='k') Or (Token='K') Or (Token='setcmykcolor') Then J := 4;
    If Need(J) Then Begin
     For I := 0 To J-1 Do
      If (Stack[I]<0) Or (Stack[I]>1) Then Fail('Couleur hors limites.');
     R := Stack[0]; G := R; B := R;
     If J=3 Then Begin G := Stack[1]; B := Stack[2]; End;
     If J=4 Then Begin
      R := 1-MinReal(1,Stack[0]+Stack[3]);
      G := 1-MinReal(1,Stack[1]+Stack[3]);
      B := 1-MinReal(1,Stack[2]+Stack[3]);
     End;
     If Copy(Token,1,3)='set' Then Begin
      Stroke := ImportPaletteColor(R,G,B); Fill := Stroke;
     End Else If (Token='G') Or (Token='RG') Or (Token='K') Then
      Stroke := ImportPaletteColor(R,G,B)
     Else Fill := ImportPaletteColor(R,G,B);
    End;
   End Else If (Token='w') Or (Token='setlinewidth') Then Begin
    If Need(1) Then
     If (Stack[0]<0) Or (Stack[0]>1000) Then Fail('Epaisseur invalide.')
     Else Width := Stack[0];
   End Else If (Token='j') Or (Token='J') Or (Token='M') Then Begin
    If Need(1) Then
     If ((Token='M') And (Stack[0]<>10)) Or
        ((Token<>'M') And (Stack[0]<>0)) Then
      Fail('Jointure/extremite speciale non prise en charge.');
   End Else If Token='showpage' Then Begin
    If Not Need(0) Then Break;
    PageEnded := True;
   End Else If (Token='u') Or (Token='U') Then Begin
    If Not Need(0) Then Break;
   End Else Fail('Operateur non pris en charge : '+Copy(Token,1,80));
   SP := 0;
  End;
 End;
 Code := IOResult;
 Close(F); I := IOResult;
 {$I+}
 If (Code<>0) Or (I<>0) Then Fail('Erreur de lecture ou fermeture du fichier.');
 If Not HaveBox Then Fail('BoundingBox absente.');
 If (SP<>0) Or (SkipDepth<>0) Or (Path.Path.PointCount<>0) Then
  Fail('Fichier PostScript incomplet.');
 If (ImportCount=0) And Not PageEnded Then Fail('Aucun objet vectoriel pris en charge.');
 ReadIllustratorDocument := ImportError='';
End;

Function LoadDocument(Name: String): Boolean;
Var F: File; Sig: Array[0..3] Of Char; Got: Word; Code, I: Integer;
 Good, Legacy: Boolean; Size: LongInt;
Begin
 LoadDocument := False; ImportError := ''; ImportCount := 0;
 {$I-} Assign(F,Name); Reset(F,1); Code := IOResult; {$I+}
 If Code<>0 Then Begin ImportError := 'Fichier introuvable ou acces refuse.'; Exit; End;
 {$I-}
 Size := FileSize(F); Code := IOResult;
 BlockRead(F,Sig,4,Got); I := IOResult;
 Close(F); Good := IOResult=0;
 {$I+}
 If (Code<>0) Or (I<>0) Or Not Good Or (Got<>4) Or
    (Size>4194304) Then Begin
  ImportError := 'Fichier illisible, trop court ou superieur a 4 Mo.'; Exit;
 End;
 Legacy := (Sig[0]='A') And (Sig[1]='I') And (Sig[2]='1') And (Sig[3]='0');
 If (Sig[0]='%') And (Sig[1]='P') And (Sig[2]='D') And (Sig[3]='F') Then Begin
  ImportError := 'AI base sur PDF non pris en charge. Utiliser AI/EPS classique.';
  Exit;
 End;
 If Legacy Then Good := ReadLegacyDocument(Name)
 Else Good := ReadIllustratorDocument(Name);
 If Not Good Then Exit;
 For I := 0 To ImportCount-1 Do Objects[I] := ImportObjects[I];
 ObjectCount := ImportCount;
 SelectedObject := -1; CurrentFile := Name; FileModified := False;
 If Legacy Then CurrentSaveFormat := 2
 Else Begin
  CurrentSaveFormat := 0;
  If UpperText(Copy(Name,Length(Name)-3,4))='.EPS' Then CurrentSaveFormat := 1;
 End;
 ResetZoom; NeedsRedraw := True;
 If Legacy Then StatusMessage := 'Format prive AI10 charge (pas Adobe Illustrator).'
 Else StatusMessage := 'AI classique importe : couleurs VGA, courbes approximees, traits fins.';
 LoadDocument := True;
End;

Function WriteClassicDocument(Name: String): Boolean;
Var F: Text; I, J, Code: Integer; Obj: TGraphicObject;
 X, Y, RX, RY: Real; S: String;
Const
 RGB: Array[0..15,0..2] Of Byte =
  ((0,0,0),(0,0,170),(0,170,0),(0,170,170),
   (170,0,0),(170,0,170),(170,85,0),(170,170,170),
   (85,85,85),(85,85,255),(85,255,85),(85,255,255),
   (255,85,85),(255,85,255),(255,255,85),(255,255,255));

 Function Num(V: Real): String;
 Var T: String;
 Begin
  Str(V:0:6,T);
  While (Length(T)>1) And (T[Length(T)]='0') Do Delete(T,Length(T),1);
  If T[Length(T)]='.' Then Delete(T,Length(T),1);
  Num := T;
 End;

 Procedure Point(X,Y: Real; Op: String);
 Begin
  Writeln(F,Num(X),' ',Num(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1-Y),' ',Op);
 End;

 Procedure Color(C: Byte; Op: String);
 Begin
  Writeln(F,Num(RGB[C,0]/255),' ',Num(RGB[C,1]/255),' ',Num(RGB[C,2]/255),' ',Op);
 End;

 Procedure Cubic(X1,Y1,X2,Y2,X3,Y3: Real);
 Var H: Integer;
 Begin
  H := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1;
  Writeln(F,Num(X1),' ',Num(H-Y1),' ',Num(X2),' ',Num(H-Y2),' ',
          Num(X3),' ',Num(H-Y3),' c');
 End;

Begin
 WriteClassicDocument := False;
 {$I-} Assign(F,Name); Rewrite(F); Code := IOResult; {$I+}
 If Code<>0 Then Begin SaveError := 'Impossible de creer le fichier temporaire.'; Exit; End;
 {$I-}
 Writeln(F,'%!PS-Adobe-3.0 EPSF-3.0');
 Writeln(F,'%%Creator: CloneDRAW AI');
 Writeln(F,'%%BoundingBox: 0 0 ',ScreenWidth-TOOLBAR_WIDTH-1,' ',
  ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1);
 Writeln(F,'%%EndComments');
 Writeln(F,'%%BeginProlog');
 Writeln(F,'/m { moveto } bind def /l { lineto } bind def');
 Writeln(F,'/c { curveto } bind def /h { closepath } bind def');
 Writeln(F,'/CDStroke [0 0 0] def /CDFill [0 0 0] def');
 Writeln(F,'/S { CDStroke aload pop setrgbcolor stroke } bind def');
 Writeln(F,'/s { closepath S } bind def');
 Writeln(F,'/B { gsave CDFill aload pop setrgbcolor fill grestore S } bind def');
 Writeln(F,'/RG { 3 array astore /CDStroke exch def CDStroke aload pop setrgbcolor } bind def');
 Writeln(F,'/rg { 3 array astore /CDFill exch def } bind def');
 Writeln(F,'%%EndProlog');
 Writeln(F,'1 setlinewidth');
 For I := 0 To ObjectCount-1 Do Begin
  Obj := Objects[I];
  If Obj.Visible Then Case Obj.ObjType Of
   OBJ_RECT: Begin
    Color(Obj.Rectangle.StrokeColor,'RG');
    X := Obj.Rectangle.X; Y := Obj.Rectangle.Y;
    Point(X,Y,'m'); Point(X+Obj.Rectangle.Width,Y,'l');
    Point(X+Obj.Rectangle.Width,Y+Obj.Rectangle.Height,'l');
    Point(X,Y+Obj.Rectangle.Height,'l'); Writeln(F,'s');
   End;
   OBJ_ELLIPSE: Begin
    Color(Obj.Ellipse.StrokeColor,'RG');
    X := Obj.Ellipse.CX; Y := Obj.Ellipse.CY;
    RX := Obj.Ellipse.RX; RY := Obj.Ellipse.RY;
    Point(X+RX,Y,'m');
    Cubic(X+RX,Y+RY*0.55228475,X+RX*0.55228475,Y+RY,X,Y+RY);
    Cubic(X-RX*0.55228475,Y+RY,X-RX,Y+RY*0.55228475,X-RX,Y);
    Cubic(X-RX,Y-RY*0.55228475,X-RX*0.55228475,Y-RY,X,Y-RY);
    Cubic(X+RX*0.55228475,Y-RY,X+RX,Y-RY*0.55228475,X+RX,Y);
    Writeln(F,'s');
   End;
   OBJ_LINE: Begin
    Color(Obj.Line.StrokeColor,'RG');
    Point(Obj.Line.X1,Obj.Line.Y1,'m'); Point(Obj.Line.X2,Obj.Line.Y2,'l');
    Writeln(F,'S');
   End;
   OBJ_BEZIER: Begin
    Color(Obj.Path.StrokeColor,'RG');
    Point(Obj.Path.Points[0].X,Obj.Path.Points[0].Y,'m');
    Cubic(Obj.Path.Points[1].X,Obj.Path.Points[1].Y,
          Obj.Path.Points[2].X,Obj.Path.Points[2].Y,
          Obj.Path.Points[3].X,Obj.Path.Points[3].Y);
    Writeln(F,'S');
   End;
   OBJ_PATH, OBJ_FILLED_PATH: Begin
    Color(Obj.Path.StrokeColor,'RG');
    If Obj.ObjType=OBJ_FILLED_PATH Then Color(Obj.Path.FillColor,'rg');
    Point(Obj.Path.Points[0].X,Obj.Path.Points[0].Y,'m');
    If Obj.Path.PointCount=1 Then Point(Obj.Path.Points[0].X,Obj.Path.Points[0].Y,'l');
    For J := 1 To Obj.Path.PointCount-1 Do
     Point(Obj.Path.Points[J].X,Obj.Path.Points[J].Y,'l');
    If Obj.Path.Closed Then Writeln(F,'h');
    If Obj.ObjType=OBJ_FILLED_PATH Then Writeln(F,'B') Else Writeln(F,'S');
   End;
   OBJ_TEXT: Begin
    Color(Obj.TextObj.Color,'RG');
    Writeln(F,'/Courier findfont 13.333333 scalefont setfont');
    Point(Obj.TextObj.X,Obj.TextObj.Y+7,'m');
    S := '(';
    For J := 1 To Length(Obj.TextObj.Text) Do Begin
     If Length(S)>235 Then Begin
      Writeln(F,S,') show');
      Point(Obj.TextObj.X+(J-1)*8,Obj.TextObj.Y+7,'m');
      S := '(';
     End;
     If Obj.TextObj.Text[J] In ['(',')','\'] Then S := S+'\';
     S := S+Obj.TextObj.Text[J];
    End;
    Writeln(F,S,') show');
   End;
  End;
 End;
 Writeln(F,'showpage'); Writeln(F,'%%Trailer'); Writeln(F,'%%EOF');
 Code := IOResult; Close(F); J := IOResult;
 {$I+}
 If (Code<>0) Or (J<>0) Then SaveError := 'Erreur pendant l''ecriture ou fermeture.'
 Else WriteClassicDocument := True;
End;

Function WriteLegacyDocument(Name: String): Boolean;
Var F: File; Ver: Word; I, Code, CloseCode: Integer; Got: Word; Good: Boolean;
 Sig: Array[0..3] Of Char;
Begin
 WriteLegacyDocument := False;
 {$I-} Assign(F,Name); Rewrite(F,1); Code := IOResult; {$I+}
 If Code<>0 Then Begin SaveError := 'Creation AI10 impossible.'; Exit; End;
 Sig[0] := 'A'; Sig[1] := 'I'; Sig[2] := '1'; Sig[3] := '0'; Ver := AI_VERSION;
 {$I-}
 BlockWrite(F,Sig,4,Got); Code := IOResult; Good := (Code=0) And (Got=4);
 BlockWrite(F,Ver,2,Got); Code := IOResult; Good := Good And (Code=0) And (Got=2);
 BlockWrite(F,ObjectCount,2,Got); Code := IOResult; Good := Good And (Code=0) And (Got=2);
 For I := 0 To ObjectCount-1 Do Begin
  If Not Good Then Break;
  BlockWrite(F,Objects[I],SizeOf(TGraphicObject),Got); Code := IOResult;
  Good := (Code=0) And (Got=SizeOf(TGraphicObject));
 End;
 Close(F); CloseCode := IOResult;
 {$I+}
 If Not Good Or (CloseCode<>0) Then SaveError := 'Ecriture AI10 incomplete.'
 Else WriteLegacyDocument := True;
End;

Function WriteSVGDocument(Name: String): Boolean;
Const Colors: Array[0..15] Of String[7] =
 ('#000000','#0000AA','#00AA00','#00AAAA','#AA0000','#AA00AA',
  '#AA5500','#AAAAAA','#555555','#5555FF','#55FF55','#55FFFF',
  '#FF5555','#FF55FF','#FFFF55','#FFFFFF');
Var F: Text; I, J, X, Y, Start, Code, CloseCode: Integer; Obj: TGraphicObject;

 Function Num(V: Real): String;
 Var S: String;
 Begin
  Str(V:0:6,S);
  While (Length(S)>1) And (S[Length(S)]='0') Do Delete(S,Length(S),1);
  If S[Length(S)]='.' Then Delete(S,Length(S),1);
  Num := S;
 End;

 Procedure Point(X,Y: Real);
 Begin
  Write(F,Num(X),' ',Num(Y),' ');
 End;

Begin
 WriteSVGDocument := False;
 {$I-} Assign(F,Name); Rewrite(F); Code := IOResult; {$I+}
 If Code<>0 Then Begin SaveError := 'Creation SVG impossible.'; Exit; End;
 {$I-}
 Writeln(F,'<?xml version="1.0" encoding="UTF-8"?>');
 Writeln(F,'<svg xmlns="http://www.w3.org/2000/svg" width="',
  ScreenWidth-TOOLBAR_WIDTH,'" height="',ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT,
  '" viewBox="0 0 ',ScreenWidth-TOOLBAR_WIDTH,' ',
  ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT,'">');
 Writeln(F,'<title>CloneDRAW vector export</title>');
 For I := 0 To ObjectCount-1 Do Begin
  Obj := Objects[I];
  If Obj.Visible Then Case Obj.ObjType Of
   OBJ_RECT:
    Writeln(F,'<rect x="',Num(Obj.Rectangle.X),'" y="',Num(Obj.Rectangle.Y),
     '" width="',Num(Obj.Rectangle.Width),'" height="',Num(Obj.Rectangle.Height),
     '" fill="none" stroke="',Colors[Obj.Rectangle.StrokeColor],'"/>');
   OBJ_ELLIPSE:
    Writeln(F,'<ellipse cx="',Num(Obj.Ellipse.CX),'" cy="',Num(Obj.Ellipse.CY),
     '" rx="',Num(Obj.Ellipse.RX),'" ry="',Num(Obj.Ellipse.RY),
     '" fill="none" stroke="',Colors[Obj.Ellipse.StrokeColor],'"/>');
   OBJ_LINE:
    Writeln(F,'<line x1="',Num(Obj.Line.X1),'" y1="',Num(Obj.Line.Y1),
     '" x2="',Num(Obj.Line.X2),'" y2="',Num(Obj.Line.Y2),
     '" stroke="',Colors[Obj.Line.StrokeColor],'"/>');
   OBJ_BEZIER: Begin
    Write(F,'<path fill="none" stroke="',Colors[Obj.Path.StrokeColor],'" d="M ');
    Point(Obj.Path.Points[0].X,Obj.Path.Points[0].Y); Write(F,'C ');
    For J := 1 To 3 Do Point(Obj.Path.Points[J].X,Obj.Path.Points[J].Y);
    Writeln(F,'"/>');
   End;
   OBJ_PATH, OBJ_FILLED_PATH: Begin
    If Obj.Path.PointCount=1 Then
     Writeln(F,'<rect x="',Num(Obj.Path.Points[0].X),'" y="',
      Num(Obj.Path.Points[0].Y),'" width="1" height="1" fill="',
      Colors[Obj.Path.StrokeColor],'"/>')
    Else Begin
     Write(F,'<path stroke="',Colors[Obj.Path.StrokeColor],'" fill="');
     If Obj.ObjType=OBJ_FILLED_PATH Then Write(F,Colors[Obj.Path.FillColor])
     Else Write(F,'none');
     Write(F,'" d="M '); Point(Obj.Path.Points[0].X,Obj.Path.Points[0].Y);
     For J := 1 To Obj.Path.PointCount-1 Do Begin
      Write(F,'L '); Point(Obj.Path.Points[J].X,Obj.Path.Points[J].Y);
     End;
     If Obj.Path.Closed Then Write(F,'Z');
     Writeln(F,'"/>');
    End;
   End;
   OBJ_TEXT: Begin
    Writeln(F,'<g fill="',Colors[Obj.TextObj.Color],'">');
    For J := 1 To Length(Obj.TextObj.Text) Do
     For Y := 0 To 7 Do Begin
      X := 0;
      While X<8 Do Begin
       If (GlyphRows[Ord(Obj.TextObj.Text[J]),Y] And (1 Shl X))<>0 Then Begin
        Start := X;
        Repeat Inc(X);
        Until (X=8) Or ((GlyphRows[Ord(Obj.TextObj.Text[J]),Y] And (1 Shl X))=0);
        Writeln(F,'<rect x="',Num(Obj.TextObj.X+(J-1)*8+Start),'" y="',
         Num(Obj.TextObj.Y+Y),'" width="',X-Start,'" height="1"/>');
       End Else Inc(X);
      End;
     End;
    Writeln(F,'</g>');
   End;
  End;
 End;
 Writeln(F,'</svg>');
 Code := IOResult; Close(F); CloseCode := IOResult;
 {$I+}
 If (Code<>0) Or (CloseCode<>0) Then SaveError := 'Ecriture SVG incomplete.'
 Else WriteSVGDocument := True;
End;

Function WriteBMPDocument(Name: String): Boolean;
Const RGB: Array[0..15,0..2] Of Byte =
  ((0,0,0),(0,0,170),(0,170,0),(0,170,170),
   (170,0,0),(170,0,170),(170,85,0),(170,170,170),
   (85,85,85),(85,85,255),(85,255,85),(85,255,255),
   (255,85,85),(255,85,255),(255,255,85),(255,255,255));
Var F: File; Header: Array[0..53] Of Byte; Row: Array[0..1919] Of Byte;
 W,H,Stride,X,Y,C,I,Code,CloseCode,OldZoom: Integer; Got: Word;
 OldX,OldY: Real; OldGrid,Good: Boolean;

 Procedure DWordAt(Index: Integer; Value: LongInt);
 Var K: Integer;
 Begin
  For K := 0 To 3 Do Header[Index+K] := (Value Shr (K*8)) And 255;
 End;

Begin
 WriteBMPDocument := False;
 W := ScreenWidth-TOOLBAR_WIDTH; H := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT;
 Stride := ((W*3+3) Div 4)*4;
 If (W<=0) Or (H<=0) Or (Stride>SizeOf(Row)) Then Begin
  SaveError := 'Dimensions BMP non prises en charge.'; Exit;
 End;
 {$I-} Assign(F,Name); Rewrite(F,1); Code := IOResult; {$I+}
 If Code<>0 Then Begin SaveError := 'Creation BMP impossible.'; Exit; End;
 FillChar(Header,SizeOf(Header),0);
 Header[0] := Ord('B'); Header[1] := Ord('M');
 DWordAt(2,54+LongInt(Stride)*H); DWordAt(10,54); DWordAt(14,40);
 DWordAt(18,W); DWordAt(22,H); Header[26] := 1; Header[28] := 24;
 DWordAt(34,LongInt(Stride)*H);
 {$I-} BlockWrite(F,Header,SizeOf(Header),Got); Code := IOResult; {$I+}
 Good := (Code=0) And (Got=SizeOf(Header));
 OldZoom := ZoomIndex; OldX := ViewX; OldY := ViewY; OldGrid := GridVisible;
 HideMouse;
 ZoomIndex := 2; ViewX := 0; ViewY := 0; GridVisible := False;
 SetViewPort(TOOLBAR_WIDTH,MENUBAR_HEIGHT,ScreenWidth-1,
  ScreenHeight-STATUSBAR_HEIGHT-1,True);
 DrawCanvas;
 For I := 0 To ObjectCount-1 Do DrawObject(I);
 For Y := H-1 DownTo 0 Do Begin
  If Not Good Then Break;
  FillChar(Row,SizeOf(Row),0);
  For X := 0 To W-1 Do Begin
   C := GetPixel(X,Y);
   If (C<0) Or (C>15) Then Begin Good := False; Break; End;
   Row[X*3] := RGB[C,2]; Row[X*3+1] := RGB[C,1]; Row[X*3+2] := RGB[C,0];
  End;
  If Good Then Begin
   {$I-} BlockWrite(F,Row,Stride,Got); Code := IOResult; {$I+}
   Good := (Code=0) And (Got=Stride);
  End;
 End;
 {$I-} Close(F); CloseCode := IOResult; {$I+}
 ZoomIndex := OldZoom; ViewX := OldX; ViewY := OldY; GridVisible := OldGrid;
 SetViewPort(0,0,ScreenWidth-1,ScreenHeight-1,True);
 ShowMouse;
 RedrawInterface;
 If Not Good Or (CloseCode<>0) Then SaveError := 'Ecriture BMP incomplete.'
 Else WriteBMPDocument := True;
End;

Function WriteCDR9Document(Name: String): Boolean;
Const
 Palette: Array[0..15] Of LongInt =
  ($000000,$0000AA,$00AA00,$00AAAA,$AA0000,$AA00AA,$AA5500,$AAAAAA,
   $555555,$5555FF,$55FF55,$55FFFF,$FF5555,$FF55FF,$FFFF55,$FFFFFF);
 Kappa = 0.552284749830793;
Var F: File; Good: Boolean; Code, CloseCode, I, J, VisibleCount: Integer;
 RootPos, DocPos, TablePos, EntryPos, PagePos, GroupPos, LayerPos: LongInt;
 NumPoints: LongInt; Mode, FillIndex, LineIndex: Integer;
 Obj: TGraphicObject; Bounds: TBounds; Settings: Array[0..211] Of LongInt;

 Procedure Bytes(Var Data; Count: Word);
 Var Got: Word; Error: Integer;
 Begin
  If Not Good Then Exit;
  {$I-} BlockWrite(F,Data,Count,Got); Error := IOResult; {$I+}
  Good := (Error=0) And (Got=Count);
 End;

 Procedure ByteValue(V: Byte);
 Begin Bytes(V,1); End;

 Procedure WordValue(V: Word);
 Var B: Array[0..1] Of Byte;
 Begin B[0] := V And 255; B[1] := V Shr 8; Bytes(B,2); End;

 Procedure LongValue(V: LongInt);
 Var B: Array[0..3] Of Byte; K: Integer;
 Begin
  For K := 0 To 3 Do B[K] := (V Shr (K*8)) And 255;
  Bytes(B,4);
 End;

 Procedure StringBytes(S: String);
 Begin If S<>'' Then Bytes(S[1],Length(S)); End;

 Function Position: LongInt;
 Var P: LongInt; Error: Integer;
 Begin
  P := 0;
  If Good Then Begin
   {$I-} P := FilePos(F); Error := IOResult; {$I+}
   Good := Error=0;
  End;
  Position := P;
 End;

 Procedure SeekTo(P: LongInt);
 Var Error: Integer;
 Begin
  If Not Good Then Exit;
  {$I-} Seek(F,P); Error := IOResult; {$I+}
  Good := Error=0;
 End;

 Function Chunk(Tag: String): LongInt;
 Begin
  Chunk := Position;
  StringBytes(Tag); LongValue(0);
 End;

 Function List(Kind: String): LongInt;
 Begin List := Chunk('LIST'); StringBytes(Kind); End;

 Procedure EndChunk(P: LongInt);
 Var Last, Size: LongInt;
 Begin
  If Not Good Then Exit;
  Last := Position; Size := Last-P-8;
  SeekTo(P+4); LongValue(Size); SeekTo(Last);
  If Odd(Size) Then ByteValue(0);
 End;

 Procedure NumberChunk(Tag: String; V: LongInt);
 Var P: LongInt;
 Begin P := Chunk(Tag); LongValue(V); EndChunk(P); End;

 Procedure ColorValue(Index: Integer);
 Begin
  WordValue(5); WordValue(5); LongValue(0); LongValue(Palette[Index]);
 End;

 Procedure IdentityTransform;
 Var P, T, D: LongInt; K: Integer;
 Begin
  P := List('trfl'); T := Chunk('trfd');
  LongValue(80); LongValue(1); LongValue(16); LongValue(65535);
  LongValue(24); LongValue(80); WordValue(8);
  WordValue(0); LongValue(0);
  For K := 0 To 5 Do Begin
   LongValue(0);
   If (K=0) Or (K=4) Then D := $3FF00000 Else D := 0;
   LongValue(D);
  End;
  EndChunk(T); EndChunk(P);
 End;

 Procedure Point(X,Y: Real);
 Begin
  { CDR9 : 254000 unites/pouce, origine au centre, Y vers le haut. }
  LongValue(Round((X-(ScreenWidth-TOOLBAR_WIDTH)/2)*2540));
  LongValue(Round(((ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT)/2-Y)*2540));
 End;

 Procedure BoundingBox(Tag: String; B: TBounds; Twice: Boolean);
 Var P: LongInt; K, Count: Integer;
 Begin
  P := Chunk(Tag);
  If Twice Then Count := 2 Else Count := 1;
  For K := 1 To Count Do Begin Point(B.L,B.T); Point(B.R,B.B); End;
  EndChunk(P);
 End;

 Procedure Node(X,Y: Real; Kind: Byte);
 Begin
  If Mode=1 Then Point(X,Y)
  Else If Mode=2 Then ByteValue(Kind)
  Else Begin
   If NumPoints=0 Then Begin
    Bounds.L := X; Bounds.R := X; Bounds.T := Y; Bounds.B := Y;
   End Else Begin
    If X<Bounds.L Then Bounds.L := X;
    If X>Bounds.R Then Bounds.R := X;
    If Y<Bounds.T Then Bounds.T := Y;
    If Y>Bounds.B Then Bounds.B := Y;
   End;
   Inc(NumPoints);
  End;
 End;

 Procedure RectanglePath(X,Y,W,H: Real);
 Begin
  Node(X,Y,12); Node(X+W,Y,68); Node(X+W,Y+H,68);
  Node(X,Y+H,68); Node(X,Y,72);
 End;

 Procedure Geometry;
 Var K, Row, Column, Start: Integer; X,Y,RX,RY,CX,CY: Real;

  Procedure Cubic(X1,Y1,X2,Y2,X3,Y3: Real; Last: Boolean);
  Begin
   Node(X1,Y1,196); Node(X2,Y2,196);
   If Last Then Node(X3,Y3,136) Else Node(X3,Y3,132);
  End;

 Begin
  Case Obj.ObjType Of
   OBJ_RECT: With Obj.Rectangle Do RectanglePath(X,Y,Width,Height);
   OBJ_ELLIPSE: Begin
    CX := Obj.Ellipse.CX; CY := Obj.Ellipse.CY;
    RX := Obj.Ellipse.RX; RY := Obj.Ellipse.RY;
    X := RX*Kappa; Y := RY*Kappa;
    Node(CX+RX,CY,12);
    Cubic(CX+RX,CY+Y,CX+X,CY+RY,CX,CY+RY,False);
    Cubic(CX-X,CY+RY,CX-RX,CY+Y,CX-RX,CY,False);
    Cubic(CX-RX,CY-Y,CX-X,CY-RY,CX,CY-RY,False);
    Cubic(CX+X,CY-RY,CX+RX,CY-Y,CX+RX,CY,True);
   End;
   OBJ_LINE: With Obj.Line Do Begin Node(X1,Y1,4); Node(X2,Y2,68); End;
   OBJ_BEZIER: Begin
    With Obj.Path.Points[0] Do Node(X,Y,4);
    With Obj.Path.Points[1] Do Node(X,Y,196);
    With Obj.Path.Points[2] Do Node(X,Y,196);
    With Obj.Path.Points[3] Do Node(X,Y,132);
   End;
   OBJ_PATH, OBJ_FILLED_PATH: Begin
    If Obj.Path.PointCount=1 Then
     With Obj.Path.Points[0] Do RectanglePath(X,Y,1,1)
    Else Begin
     With Obj.Path.Points[0] Do
      If Obj.Path.Closed Or (Obj.ObjType=OBJ_FILLED_PATH) Then Node(X,Y,12)
      Else Node(X,Y,4);
     For K := 1 To Obj.Path.PointCount-1 Do
      With Obj.Path.Points[K] Do Node(X,Y,68);
     If Obj.Path.Closed Or (Obj.ObjType=OBJ_FILLED_PATH) Then
      With Obj.Path.Points[0] Do Node(X,Y,72);
    End;
   End;
   OBJ_TEXT:
    For K := 1 To Length(Obj.TextObj.Text) Do
     For Row := 0 To 7 Do Begin
      Column := 0;
      While Column<8 Do Begin
       If (GlyphRows[Ord(Obj.TextObj.Text[K]),Row] And (1 Shl Column))<>0 Then Begin
        Start := Column;
        Repeat Inc(Column);
        Until (Column=8) Or
         ((GlyphRows[Ord(Obj.TextObj.Text[K]),Row] And (1 Shl Column))=0);
        RectanglePath(Obj.TextObj.X+(K-1)*8+Start,Obj.TextObj.Y+Row,Column-Start,1);
       End Else Inc(Column);
      End;
     End;
  End;
 End;

 Procedure ObjectColors;
 Begin
  FillIndex := 16; LineIndex := 16;
  Case Obj.ObjType Of
   OBJ_RECT: LineIndex := Obj.Rectangle.StrokeColor;
   OBJ_ELLIPSE: LineIndex := Obj.Ellipse.StrokeColor;
   OBJ_LINE: LineIndex := Obj.Line.StrokeColor;
   OBJ_BEZIER, OBJ_PATH, OBJ_FILLED_PATH: Begin
    LineIndex := Obj.Path.StrokeColor;
    If Obj.ObjType=OBJ_FILLED_PATH Then FillIndex := Obj.Path.FillColor;
    If Obj.Path.PointCount=1 Then Begin
     FillIndex := LineIndex; LineIndex := 16;
    End;
   End;
   OBJ_TEXT: FillIndex := Obj.TextObj.Color;
  End;
 End;

 Procedure StyleRecord(Id, Parent: LongInt; Fill, Line: Integer; Default: Boolean);
 Begin
  LongValue(1); LongValue(Id); LongValue(Parent);
  If Default Then Begin
   LongValue(1); LongValue(1); LongValue(16); StringBytes('Default Graphic'+#0);
  End Else Begin LongValue(0); LongValue(0); LongValue(1); ByteValue(0); End;
  LongValue(1000+Fill); LongValue(2000+Line);
 End;

 Procedure LayerHeader(Kind: Integer; Flags: LongInt; Name: String);
 Var G, L: LongInt; N, Size: Integer;
 Begin
  NumberChunk('flgs',Flags);
  G := List('lgob'); L := Chunk('loda');
  N := 1; Size := 44;
  If Name<>'' Then Begin N := 2; Size := 53+Length(Name); End;
  LongValue(Size); LongValue(N); LongValue(20); LongValue(24+N*4);
  LongValue(Kind);
  If N=2 Then Begin
   LongValue(40); LongValue(52); LongValue(Size); LongValue(1000); LongValue(2000);
  End Else Begin LongValue(32); LongValue(44); LongValue(2000); End;
  ColorValue(0);
  If Name<>'' Then StringBytes(Name+#0);
  EndChunk(L); EndChunk(G);
 End;

 Procedure EmptyLayer(Kind: Integer; Flags: LongInt; Name: String);
 Var P: LongInt;
 Begin P := List('layr'); LayerHeader(Kind,Flags,Name); EndChunk(P); End;

 Procedure WriteObject(Index: Integer);
 Var P, G, L: LongInt; Size: LongInt;
 Begin
  Obj := Objects[Index]; Mode := 0; NumPoints := 0; Geometry;
  If NumPoints=0 Then Exit;
  If NumPoints>65535 Then Begin
   Good := False; SaveError := 'CDR9 : trop de noeuds dans un objet.'; Exit;
  End;
  P := List('obj ');
  NumberChunk('flgs',$08000A00);
  BoundingBox('bbox',Bounds,False); BoundingBox('obbx',Bounds,True);
  NumberChunk('usdn',Index+5);
  G := List('lgob'); L := Chunk('loda'); Size := 80+12+NumPoints*9;
  LongValue(Size); LongValue(5); LongValue(20); LongValue(44); LongValue(3);
  LongValue(64); LongValue(68); LongValue(72); LongValue(76); LongValue(80);
  LongValue(Size);
  LongValue(30); LongValue(100); LongValue(200); LongValue(12000); LongValue(12030);
  LongValue(0); LongValue(0); LongValue(3100+Index); LongValue(Index+5);
  WordValue(Word(NumPoints)); WordValue(0);
  Mode := 1; Geometry; Mode := 2; Geometry;
  LongValue(0); LongValue(0);
  EndChunk(L); IdentityTransform; EndChunk(G); EndChunk(P);
 End;

Begin
 WriteCDR9Document := False;
 {$I-} Assign(F,Name); Rewrite(F,1); Code := IOResult; {$I+}
 If Code<>0 Then Begin SaveError := 'Creation CDR9 impossible.'; Exit; End;
 Good := True; VisibleCount := 0;
 For I := 0 To ObjectCount-1 Do If Objects[I].Visible Then Inc(VisibleCount);
 RootPos := Chunk('RIFF'); StringBytes('CDR9');
 EntryPos := Chunk('vrsn'); WordValue(900); EndChunk(EntryPos);
 DocPos := List('doc '); EntryPos := Chunk('mcfg');
 FillChar(Settings,SizeOf(Settings),0);
 Settings[0] := 8; Settings[1] := (ScreenWidth-TOOLBAR_WIDTH)*2540;
 Settings[2] := (ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT)*2540;
 Settings[3] := 3; Settings[4] := 1; Settings[7] := 1; Settings[8] := 1;
 For I := 0 To 211 Do LongValue(Settings[I]);
 EndChunk(EntryPos);
 TablePos := List('filt');
 For I := 0 To 16 Do Begin
  GroupPos := List('filc'); EntryPos := Chunk('fild'); LongValue(I+1);
  If I=16 Then Begin WordValue(0); WordValue(0); End
  Else Begin
   WordValue(1); WordValue(0); ColorValue(I);
   For J := 1 To 4 Do LongValue(0);
  End;
  EndChunk(EntryPos); EndChunk(GroupPos);
 End;
 EndChunk(TablePos);
 TablePos := List('otlt');
 For I := 0 To 16 Do Begin
  EntryPos := Chunk('outl'); LongValue(I+1);
  If I=16 Then WordValue(1) Else WordValue(2);
  WordValue(0); WordValue(0); WordValue(0);
  LongValue(2540); WordValue(100); WordValue(0); LongValue(0);
  For J := 1 To 13 Do
   If (J=3) Or (J=11) Then LongValue($3FF00000) Else LongValue(0);
  If I=16 Then ColorValue(0) Else ColorValue(I);
  For J := 1 To 13 Do LongValue(0);
  EndChunk(EntryPos);
 End;
 EndChunk(TablePos);
 TablePos := List('stlt'); LongValue(VisibleCount+2);
 LongValue(17);
 For I := 0 To 16 Do Begin LongValue(1000+I); LongValue(0); LongValue(I+1); End;
 LongValue(17);
 For I := 0 To 16 Do Begin LongValue(2000+I); LongValue(0); LongValue(I+1); End;
 For I := 1 To 10 Do LongValue(0);
 StyleRecord(3000,0,16,0,True); StyleRecord(3001,3000,16,0,False);
 For I := 0 To ObjectCount-1 Do If Objects[I].Visible Then Begin
  Obj := Objects[I]; ObjectColors;
  StyleRecord(3100+I,3000,FillIndex,LineIndex,False);
 End;
 EndChunk(TablePos); EndChunk(DocPos);
 Bounds.L := (ScreenWidth-TOOLBAR_WIDTH)/2;
 Bounds.R := Bounds.L; Bounds.T := (ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT)/2;
 Bounds.B := Bounds.T;
 PagePos := List('page'); NumberChunk('flgs',LongInt($90010000));
 BoundingBox('bbox',Bounds,False); GroupPos := List('gobj');
 EmptyLayer(12,LongInt($9801000A),'Guides');
 EmptyLayer(17,LongInt($98010008),'Desktop');
 EmptyLayer(0,LongInt($98000000),'Layer 1');
 EmptyLayer(11,LongInt($9801011A),'Grid');
 EndChunk(GroupPos); EndChunk(PagePos);
 Bounds.L := 0; Bounds.T := 0; Bounds.R := ScreenWidth-TOOLBAR_WIDTH;
 Bounds.B := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT;
 PagePos := List('page'); NumberChunk('flgs',LongInt($90000000));
 BoundingBox('bbox',Bounds,False); BoundingBox('obbx',Bounds,True);
 GroupPos := List('gobj');
 EmptyLayer(12,LongInt($9801000A),''); EmptyLayer(17,LongInt($98010008),'');
 LayerPos := List('layr'); LayerHeader(0,LongInt($98000000),'');
 { Les objets CDR sont stockes du premier plan vers l'arriere-plan. }
 For I := ObjectCount-1 DownTo 0 Do
  If Objects[I].Visible And Good Then WriteObject(I);
 EndChunk(LayerPos); EmptyLayer(11,LongInt($9801011A),''); EndChunk(GroupPos);
 GroupPos := List('lgob'); EntryPos := Chunk('loda');
 LongValue(48); LongValue(2); LongValue(20); LongValue(32); LongValue(0);
 LongValue(40); LongValue(44); LongValue(48); LongValue(100); LongValue(12000);
 LongValue(0); LongValue(ObjectCount+5);
 EndChunk(EntryPos); IdentityTransform; EndChunk(GroupPos); EndChunk(PagePos);
 EndChunk(RootPos);
 {$I-} Close(F); CloseCode := IOResult; {$I+}
 If Not Good Or (CloseCode<>0) Then Begin
  If SaveError='' Then SaveError := 'Ecriture ou fermeture CDR9 incomplete.';
 End Else WriteCDR9Document := True;
End;

Function SaveDocument(Name: String; Format: Integer): Boolean;
Var TempName, BackupName, S: String; F: File;
 D: DirStr; N: NameStr; E: ExtStr; I, Code: Integer;
 Exists, HadFile, Good: Boolean;

 Function RenameChecked(FromName, ToName: String): Boolean;
 Begin
  Assign(F,FromName);
  {$I-} Rename(F,ToName); Code := IOResult; {$I+}
  RenameChecked := Code=0;
 End;

 Procedure RemoveTemporary;
 Begin
  Assign(F,TempName);
  {$I-} Erase(F); Code := IOResult; {$I+}
  If (Code<>0) And (Code<>2) And (Code<>3) Then
   SaveError := SaveError+' Temporaire non supprime : '+TempName;
 End;

Begin
 SaveDocument := False; SaveError := '';
 If (Format<0) Or (Format>7) Or (Name='') Or (ObjectCount>MAX_OBJECTS) Then Begin
  SaveError := 'Nom, format ou document invalide.'; Exit;
 End;
 If IsDirectory(Name) Then Begin SaveError := 'La cible est un dossier, pas un fichier.'; Exit; End;
 For I := 0 To ObjectCount-1 Do
  If Not ValidImportObject(Objects[I]) Then Begin
   SaveError := 'Objet invalide : enregistrement refuse.'; Exit;
  End;
 If Not FileExistsChecked(Name,HadFile) Then Begin
  SaveError := 'Acces refuse au fichier cible.'; Exit;
 End;
 Name := FExpand(Name); FSplit(Name,D,N,E);
 If Length(D)>240 Then Begin SaveError := 'Chemin trop long pour une ecriture sure.'; Exit; End;
 TempName := '';
 For I := 0 To 999 Do Begin
  Str(I,S); S := D+'~AI'+S+'.TMP';
  If Not FileExistsChecked(S,Exists) Then Break;
  If Not Exists Then Begin TempName := S; Break; End;
 End;
 If TempName='' Then Begin SaveError := 'Aucun fichier temporaire disponible.'; Exit; End;
 Case Format Of
  2: Good := WriteLegacyDocument(TempName);
  3: Good := WriteSVGDocument(TempName);
  4: Good := WriteBMPDocument(TempName);
  7: Good := WriteCDR9Document(TempName);
  Else Good := WriteClassicDocument(TempName);
 End;
 If Not Good Then Begin RemoveTemporary; Exit; End;
 BackupName := '';
 If HadFile Then Begin
  For I := 0 To 999 Do Begin
   Str(I,S); S := D+'~AI'+S+'.BAK';
   If Not FileExistsChecked(S,Exists) Then Break;
   If Not Exists Then Begin BackupName := S; Break; End;
  End;
  If (BackupName='') Or Not RenameChecked(Name,BackupName) Then Begin
   SaveError := 'Remplacement refuse ; fichier original conserve.';
   RemoveTemporary; Exit;
  End;
 End;
 If Not RenameChecked(TempName,Name) Then Begin
  SaveError := 'Installation du nouveau fichier impossible.';
  If HadFile Then
   If Not RenameChecked(BackupName,Name) Then
    SaveError := 'Restauration impossible. Original conserve dans '+BackupName;
  RemoveTemporary; Exit;
 End;
 If HadFile Then Begin
  Assign(F,BackupName);
  {$I-} Erase(F); Code := IOResult; {$I+}
  If Code<>0 Then Begin
   SaveError := 'Fichier ecrit ; ancienne copie non supprimee : '+BackupName;
   Exit;
  End;
 End;
 CurrentFile := Name; CurrentSaveFormat := Format; FileModified := False;
 If Format=2 Then StatusMessage := 'AI10 prive enregistre : objets conserves exactement.'
 Else StatusMessage := 'AI/EPS enregistre : texte Courier, palette VGA, contours fins.';
 NeedsRedraw := True; SaveDocument := True;
End;

Function ExportDocument(Name: String; Format: Integer): Boolean;
Var OldName: String; OldFormat: Integer; OldModified,Good: Boolean;
Begin
 ExportDocument := False;
 If (Format<0) Or (Format>4) Then Begin
  SaveError := 'Format d''export non implemente.'; Exit;
 End;
 OldName := CurrentFile; OldFormat := CurrentSaveFormat; OldModified := FileModified;
 Good := SaveDocument(Name,Format+3);
 CurrentFile := OldName; CurrentSaveFormat := OldFormat; FileModified := OldModified;
 If Good Then Begin
  If Format=4 Then StatusMessage := 'CDR9 natif exporte : formes et texte convertis en courbes.'
  Else If Format>=2 Then StatusMessage := 'Export AI/EPS termine : texte Courier, contours fins.'
  Else StatusMessage := 'Export termine : page entiere, document courant inchange.';
 End;
 NeedsRedraw := True;
 ExportDocument := Good;
End;

Procedure SaveFile(Filename: String);
Begin
 If Not SaveDocument(Filename,2) Then Begin
  StatusMessage := Copy(SaveError,1,75); NeedsRedraw := True;
 End;
End;

Procedure LoadFile(Filename: String);
Begin
 If Not LoadDocument(Filename) Then Begin
  StatusMessage := Copy(ImportError,1,75);
  NeedsRedraw := True;
 End;
End;

Procedure MainLoop;
Var
 Key, ExtKey: Char;
Begin
 While Running Do
 Begin
  GetMouseStateLocal(MouseX, MouseY, MouseButtons);
  HandleMouseEvent;
  If KeyPressed Then
  Begin
   Key := ReadKey;
   ExtKey := #0;
   If Key = #0 Then ExtKey := ReadKey;
   HandleKey(Key, ExtKey);
  End;
  If NeedsRedraw Then RedrawInterface;
  Delay(10);
 End;
End;

Procedure Initialize;
Var
 I: Integer;
Begin
 Running := True;
 FileDialogActive := False;
 FileFilterOpen := False;
 FileSaveMode := False; FileOverwrite := False; CurrentSaveFormat := 0;
 FileExportMode := False;
 ResetZoom;
 ObjectCount := 0;
 SelectedObject := -1;
 CurrentTool := TOOL_SELECT;
 StrokeColor := 0;
 FillColor := 15;
 FileModified := False;
 CurrentFile := '';
 DrawingMode := False;
 EditingObject := False;
 PencilActive := False;
 Panning := False;
 BezierStage := 0;
 TextActive := False;
 TextEditIndex := -1;
 EditHandle := -1;
 MenuActive := False;
 ActiveMenu := -1;
 ActiveMenuItem := -1;
 MenuMouseDown := False;
 NeedsRedraw := True;
 GridVisible := True;
 DialogTitle := '';
 DialogText := '';
 StatusMessage := 'Prototype incomplet - F10 : menus';
 OldMouseButtons := 0;
 OldMouseX := -1;
 OldMouseY := -1;
 ToolTipVisible := False;
 ToolTipCandidate := -1;
 ToolTipStarted := 0;
 LayerCount := 1;
 CurrentLayer := 0;
 
 Layers[0].Name := 'Calque 1';
 Layers[0].Visible := True;
 Layers[0].Locked := False;
 Layers[0].Opacity := 255;
 
 For I := 0 To MAX_OBJECTS - 1 Do
  Objects[I].Visible := False;
End;

Procedure Cleanup;
Begin
 CloseGraph;
 Writeln('Au revoir!');
End;

Begin
 Initialize;
 InitGraphics;
 InitMenus;
 InitMouse;
 ShowMouse;
 
 MainLoop;
 
 Cleanup;
End.