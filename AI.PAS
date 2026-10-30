{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Free Pascal 3.2)
  @description(Clone d'Adobe Illustrator en Turbo Pascal/Free Pascal graphique)

  Prototype incomplet : rectangles, cercles et lignes.
  Les commandes non implementees sont grisees.
  AI10 est un ancien format prive, PAS un format Adobe Illustrator.
  Restent notamment : import/export Adobe, selection/transformations,
  Bezier, texte, calques, historique, SVG et BMP.
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
 
 OBJ_RECT = 0;
 OBJ_ELLIPSE = 1;
 OBJ_LINE = 2;
 OBJ_PATH = 3;
 OBJ_TEXT = 4;
 MAX_OBJECTS = 100;
 
 MAX_LAYERS = 20;
 MAX_HISTORY = 50;
 
 AI_SIGNATURE = 'AI10';
 AI_VERSION = 100;

Type
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
  TOOL_SELECT: S := 'Selection - non implementee';
  TOOL_RECTANGLE: S := 'Rectangle (2) - glisser pour dessiner';
  TOOL_ELLIPSE: S := 'Cercle (3) - glisser pour dessiner';
  TOOL_LINE: S := 'Ligne (4) - glisser pour dessiner';
  TOOL_BEZIER: S := 'Courbe de Bezier - non implementee';
  TOOL_PENCIL: S := 'Crayon - non implemente';
  TOOL_PEN: S := 'Plume - non implementee';
  TOOL_TEXT: S := 'Texte - non implemente';
  TOOL_ZOOM: S := 'Loupe - non implementee';
  TOOL_HAND: S := 'Main - non implementee';
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
 If Not MenuActive And Not DrawingMode And (DialogTitle = '') And
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
  Else If I > TOOL_LINE Then SetColor(COLOR_BORDER)
  Else SetColor(COLOR_TEXT);
  DrawToolIcon(X+6,Y+2,I);
 End;
End;

Procedure DrawStatusBar;
Var S: String;
Begin
 SetFillStyle(SolidFill, COLOR_BG);
 Bar(0, ScreenHeight - STATUSBAR_HEIGHT, ScreenWidth - 1, ScreenHeight - 1);
 SetColor(COLOR_BORDER);
 Line(0, ScreenHeight - STATUSBAR_HEIGHT, ScreenWidth - 1, ScreenHeight - STATUSBAR_HEIGHT);
 
 SetColor(COLOR_TEXT);
 Str(ObjectCount, S);
 OutTextXY(5, ScreenHeight - STATUSBAR_HEIGHT + 5,
           'Objets: '+S+'  '+StatusMessage);
End;

Procedure DrawCanvas;
Var
 X1, Y1: Integer;
Begin
 SetFillStyle(SolidFill, 15);
 Bar(TOOLBAR_WIDTH, MENUBAR_HEIGHT, ScreenWidth - 1, ScreenHeight - STATUSBAR_HEIGHT - 1);
 If Not GridVisible Then Exit;
 
 SetColor(14);
 X1 := TOOLBAR_WIDTH + 20;
 While X1 < ScreenWidth Do
 Begin
  Line(X1, MENUBAR_HEIGHT, X1, ScreenHeight - STATUSBAR_HEIGHT - 1);
  X1 := X1 + 20;
 End;
 
 Y1 := MENUBAR_HEIGHT + 20;
 While Y1 < ScreenHeight - STATUSBAR_HEIGHT Do
 Begin
  Line(TOOLBAR_WIDTH, Y1, ScreenWidth - 1, Y1);
  Y1 := Y1 + 20;
 End;
End;

Procedure DrawObject(Index: Integer);
Var
 Obj: TGraphicObject;
 X1, Y1, X2, Y2: Integer;
Begin
 Obj := Objects[Index];
 If Not Obj.Visible Then Exit;
 
 Case Obj.ObjType Of
  OBJ_RECT:
  Begin
   X1 := Trunc(TOOLBAR_WIDTH + Obj.Rectangle.X);
   Y1 := Trunc(MENUBAR_HEIGHT + Obj.Rectangle.Y);
   X2 := Trunc(X1 + Obj.Rectangle.Width);
   Y2 := Trunc(Y1 + Obj.Rectangle.Height);
   
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
   X1 := Trunc(TOOLBAR_WIDTH + Obj.Ellipse.CX);
   Y1 := Trunc(MENUBAR_HEIGHT + Obj.Ellipse.CY);
   
   SetColor(Obj.Ellipse.StrokeColor);
   Circle(X1, Y1, Trunc(Obj.Ellipse.RX));
   
   If Obj.Ellipse.Selected Then
   Begin
    SetColor(COLOR_HIGHLIGHT);
    Circle(X1, Y1, Trunc(Obj.Ellipse.RX) + 2);
   End;
  End;
  
  OBJ_LINE:
  Begin
   X1 := Trunc(TOOLBAR_WIDTH + Obj.Line.X1);
   Y1 := Trunc(MENUBAR_HEIGHT + Obj.Line.Y1);
   X2 := Trunc(TOOLBAR_WIDTH + Obj.Line.X2);
   Y2 := Trunc(MENUBAR_HEIGHT + Obj.Line.Y2);
   
   SetColor(Obj.Line.StrokeColor);
   Line(X1, Y1, X2, Y2);
   
   If Obj.Line.Selected Then
   Begin
    SetColor(COLOR_HIGHLIGHT);
    Circle(X1, Y1, 3);
    Circle(X2, Y2, 3);
   End;
  End;
  
  OBJ_TEXT:
  Begin
   X1 := Trunc(TOOLBAR_WIDTH + Obj.TextObj.X);
   Y1 := Trunc(MENUBAR_HEIGHT + Obj.TextObj.Y);
   
   SetColor(Obj.TextObj.Color);
   OutTextXY(X1, Y1, Obj.TextObj.Text);
  End;
 End;
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
   If I <= TOOL_LINE Then CurrentTool := I
   Else StatusMessage := 'Outil non implemente.';
  Exit;
 End;
 
 CanvasX := MouseX - TOOLBAR_WIDTH;
 CanvasY := MouseY - MENUBAR_HEIGHT;
 
 Case CurrentTool Of
  TOOL_SELECT:
  Begin
   For I := ObjectCount - 1 DownTo 0 Do
   Begin
    Objects[I].Rectangle.Selected := False;
    Objects[I].Ellipse.Selected := False;
    Objects[I].Line.Selected := False;
    Objects[I].TextObj.Selected := False;
   End;
   If SelectedObject >= 0 Then
    SelectedObject := -1;
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
 If Not DrawingMode Then Exit;
 
 CanvasX := MouseX - TOOLBAR_WIDTH;
 CanvasY := MouseY - MENUBAR_HEIGHT;
 
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
 AddMenuItem(2, 'Zoom avant', CMD_NONE);
 AddMenuItem(2, 'Zoom arriere', CMD_NONE);
 AddMenuItem(2, 'Adapter', CMD_NONE);
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
   End;
  CMD_EXIT:
   If FileModified Then
    ShowDialog('Quitter',
               'Dessin modifie : Entree = quitter, Echap = annuler.')
   Else Running := False;
  CMD_GRID: GridVisible := Not GridVisible;
  CMD_HELP:
   ShowDialog('Aide', 'Prototype incomplet. Les commandes grisees sont indisponibles.');
  CMD_SHORTCUTS:
   ShowDialog('Raccourcis', '1-4 : outils. F10 : menus. Fleches, Entree, Echap.');
  CMD_ABOUT:
   ShowDialog('A propos', 'CloneDRAW AI - prototype Pascal, pas un clone complet.');
  CMD_RESOURCES:
   ShowDialog('Ressources', 'https://www.gladir.com/clonedraw');
  CMD_TIPS:
   ShowDialog('Astuces', 'Cliquez un menu, survolez ses lignes, cliquez pour agir.');
 End;
End;

Procedure HandleMouseEvent;
Var BarHit, ItemHit: Integer; Pressed, Released: Boolean;
Begin
 Pressed := ((MouseButtons And 1) <> 0) And ((OldMouseButtons And 1) = 0);
 Released := ((MouseButtons And 1) = 0) And ((OldMouseButtons And 1) <> 0);
 If DialogTitle <> '' Then Begin
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
  If Pressed Then Begin
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
Begin
 ResetToolTip;
 NeedsRedraw := True;
 If DialogTitle <> '' Then Begin
  If Key = #13 Then Begin
   If DialogTitle = 'Quitter' Then Running := False;
   If DialogTitle = 'Nouveau document' Then Begin
    ObjectCount := 0;
    SelectedObject := -1;
    CurrentFile := '';
    FileModified := False;
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
  '1': CurrentTool := TOOL_SELECT;
  '2': CurrentTool := TOOL_RECTANGLE;
  '3': CurrentTool := TOOL_ELLIPSE;
  '4': CurrentTool := TOOL_LINE;
  #15, #19: StatusMessage := 'Import/export Adobe Illustrator non implemente.';
 End;
End;

Procedure RedrawInterface;
Var I: Integer;
Begin
 HideMouse;
 DrawCanvas;
 For I := 0 To ObjectCount-1 Do DrawObject(I);
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
 ObjectCount := 0;
 SelectedObject := -1;
 CurrentTool := TOOL_SELECT;
 StrokeColor := 0;
 FillColor := 15;
 FileModified := False;
 CurrentFile := '';
 DrawingMode := False;
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