{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Free Pascal 3.2)
  @description(Clone d'Adobe Illustrator en Turbo Pascal/Free Pascal graphique)

  Prototype incomplet : formes, Bezier, crayon et texte editables.
  Les commandes non implementees sont grisees.
  AI10 est un ancien format prive, PAS un format Adobe Illustrator.
  Restent notamment : import/export Adobe, rotation/groupes,
  Formatage du texte, calques, historique, SVG et BMP.
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
 ZOOM_LEVELS: Array[0..5] Of Integer = (25,50,100,200,400,800);
 
 OBJ_RECT = 0;
 OBJ_ELLIPSE = 1;
 OBJ_LINE = 2;
 OBJ_PATH = 3;
 OBJ_TEXT = 4;
 OBJ_BEZIER = 5;
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
 If Not MenuActive And Not DrawingMode And Not TextActive And (DialogTitle = '') And
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
  OBJ_PATH:
  Begin
   SetColor(Obj.Path.StrokeColor);
   If Obj.Path.PointCount = 1 Then
    PutPixel(ScreenX(Obj.Path.Points[0].X),
             ScreenY(Obj.Path.Points[0].Y),Obj.Path.StrokeColor);
   For I := 1 To Obj.Path.PointCount-1 Do
    Line(ScreenX(Obj.Path.Points[I-1].X),
         ScreenY(Obj.Path.Points[I-1].Y),
         ScreenX(Obj.Path.Points[I].X),
         ScreenY(Obj.Path.Points[I].Y));
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
  OBJ_PATH, OBJ_BEZIER: If Obj.Path.PointCount > 0 Then Begin
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
Var B: TBounds; DX, DY, U, D, Margin: Real; I, J: Integer; P, Q: TPoint2D;
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
  OBJ_PATH:
   For I := 0 To Objects[Index].Path.PointCount-1 Do Begin
    J := I-1; If J < 0 Then J := 0;
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
  OBJ_PATH:
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
 If Obj.ObjType In [OBJ_PATH,OBJ_BEZIER] Then
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
 AddMenuItem(0, 'Ouvrir...', CMD_NONE);
 AddMenuItem(0, 'Enregistrer', CMD_NONE);
 AddMenuItem(0, 'Enregistrer sous...', CMD_NONE);
 AddMenuItem(0, 'Exporter...', CMD_NONE);
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
  CMD_NEW:
   If FileModified Then
    ShowDialog('Nouveau document',
               'Dessin modifie : Entree = effacer, Echap = annuler.')
   Else Begin
    ObjectCount := 0;
    SelectedObject := -1;
    CurrentFile := '';
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
   ShowDialog('Raccourcis', '1-9 : outils. H : Main. Z : Loupe. 0 : 100 %. F10 : menus.');
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
 If TextActive Then Begin
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
   If DialogTitle = 'Quitter' Then Running := False;
   If DialogTitle = 'Nouveau document' Then Begin
    ObjectCount := 0;
    SelectedObject := -1;
    CurrentFile := '';
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
  #15, #19: StatusMessage := 'Import/export Adobe Illustrator non implemente.';
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
 DrawToolTip;
 ShowMouse;
 NeedsRedraw := False;
End;

Procedure SaveFile(Filename: String);
Var
 F: File;
 Sig: Array[0..3] of Char;
 Ver: Word;
 I: Integer;
Begin
 Assign(F, Filename);
 Rewrite(F, 1);
 
 Sig[0] := 'A';
 Sig[1] := 'I';
 Sig[2] := '1';
 Sig[3] := '0';
 BlockWrite(F, Sig, 4);
 
 Ver := AI_VERSION;
 BlockWrite(F, Ver, 2);
 
 BlockWrite(F, ObjectCount, 2);
 
 For I := 0 To ObjectCount - 1 Do
  BlockWrite(F, Objects[I], SizeOf(TGraphicObject));
 
 Close(F);
 FileModified := False;
 CurrentFile := Filename;
End;

Procedure LoadFile(Filename: String);
Var
 F: File;
 Sig: Array[0..3] of Char;
 Ver: Word;
 I, Count: Integer;
 FileExists: Boolean;
Begin
 {$I-}
 Assign(F, Filename);
 Reset(F, 1);
 FileExists := (IOResult = 0);
 {$I+}
 
 If Not FileExists Then
  Exit;
 
 BlockRead(F, Sig, 4);
 If (Sig[0] <> 'A') Or (Sig[1] <> 'I') Or (Sig[2] <> '1') Or (Sig[3] <> '0') Then
 Begin
  Close(F);
  Exit;
 End;
 
 BlockRead(F, Ver, 2);
 BlockRead(F, Count, 2);
 
 ObjectCount := 0;
 For I := 0 To Count - 1 Do
 Begin
  If ObjectCount < MAX_OBJECTS Then
  Begin
   BlockRead(F, Objects[ObjectCount], SizeOf(TGraphicObject));
   Inc(ObjectCount);
  End;
 End;
 
 Close(F);
 FileModified := False;
 CurrentFile := Filename;
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