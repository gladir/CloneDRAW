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
 MAX_MENU_ITEMS = 16;
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
 CMD_UNDO = 16;
 CMD_REDO = 17;
 CMD_CUT = 18;
 CMD_COPY = 19;
 CMD_PASTE = 20;
 CMD_RULERS = 21;
 CMD_GUIDES = 22;
 CMD_CLEAR_GUIDES = 23;
 RULER_SIZE = 16;
 CMD_PROPS = 24;
 CMD_FRONT = 25;
 CMD_BACK = 26;
 CMD_FORWARD = 27;
 CMD_BACKWARD = 28;
 CMD_GROUP = 29;
 CMD_UNGROUP = 30;
 CMD_ALIGN = 31;
 CMD_DISTRIB = 32;
 CMD_TRANSFORM = 33;
 CMD_OPS = 34;
 CMD_SELALL = 35;
 CMD_PJOIN = 36;
 CMD_PSPLIT = 37;
 CMD_PCORNER = 38;
 CMD_PSMOOTH = 39;
 CMD_PSIMPL = 40;
 CMD_POFFSET = 41;
 CMD_GLYPHS = 42;
 CMD_TEXTPATH = 43;
 CMD_FONTS = 44;
 CMD_FORMATS = 45;
 CMD_TEXTVIEW = 46;
 PROP_W = 460;
 PROP_H = 240;
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
 
 PGraphicObject = ^TGraphicObject;
 PObjNode = ^TObjNode;
 TObjNode = Record
  Data: TGraphicObject;
  Prev, Next: PObjNode;
 End;
 { liste doublement chainee dans le tas : aucune limite du nombre d'objets }
 TObjList = Record
  Head, Tail, Cur: PObjNode;
  Count, CurIdx: Integer;
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
 MaxScreen: Boolean;
 ScreenWidth, ScreenHeight: Integer;
 Running: Boolean;
 CurrentTool: Byte;
 StrokeColor: Byte;
 FillColor: Byte;
 MouseX, MouseY: Integer;
 MouseButtons: Integer;
 OldMouseX, OldMouseY: Integer;
 OldMouseButtons: Integer;
 ObjList: TObjList;      { objets du dessin (liste chainee, tas) }
 DummyObject: TGraphicObject;
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
 DialogText: String[255];
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
 ImpList: TObjList;      { objets importes en cours de lecture }
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

{ ------------------------------------------------------------------
  Liste chainee des objets (tas) : aucune limite du nombre d'objets
  ------------------------------------------------------------------ }
Function ListNode(Var L: TObjList; I: Integer): PObjNode;
Var P: PObjNode; K, D1, D2, D3: Integer;
Begin
 ListNode := Nil;
 If (I < 0) Or (I >= L.Count) Then Exit;
 D1 := I; D2 := L.Count-1-I;
 If L.Cur <> Nil Then D3 := Abs(I-L.CurIdx) Else D3 := 32767;
 If (D3 <= D1) And (D3 <= D2) Then Begin P := L.Cur; K := L.CurIdx; End
 Else If D1 <= D2 Then Begin P := L.Head; K := 0; End
 Else Begin P := L.Tail; K := L.Count-1; End;
 While K < I Do Begin P := P^.Next; Inc(K); End;
 While K > I Do Begin P := P^.Prev; Dec(K); End;
 L.Cur := P; L.CurIdx := I;
 ListNode := P;
End;

Function ListAt(Var L: TObjList; I: Integer): PGraphicObject;
Var N: PObjNode;
Begin
 N := ListNode(L, I);
 If N = Nil Then Begin
  FillChar(DummyObject, SizeOf(DummyObject), 0);
  ListAt := @DummyObject;
 End Else ListAt := @N^.Data;
End;

Function ListAdd(Var L: TObjList; Var O: TGraphicObject): Boolean;
Var N: PObjNode;
    {$IFDEF FPC}Previous: Boolean;{$ENDIF}
Begin
 ListAdd := False;
 N := Nil;
 {$IFDEF FPC}
 Previous := ReturnNilIfGrowHeapFails;
 ReturnNilIfGrowHeapFails := True;
 GetMem(N, SizeOf(TObjNode));
 ReturnNilIfGrowHeapFails := Previous;
 {$ELSE}
 If MaxAvail >= SizeOf(TObjNode)+4096 Then GetMem(N, SizeOf(TObjNode));
 {$ENDIF}
 If N = Nil Then Exit;
 N^.Data := O;
 N^.Next := Nil;
 N^.Prev := L.Tail;
 If L.Tail <> Nil Then L.Tail^.Next := N Else L.Head := N;
 L.Tail := N;
 Inc(L.Count);
 ListAdd := True;
End;

Procedure ListDelete(Var L: TObjList; I: Integer);
Var N: PObjNode;
Begin
 N := ListNode(L, I);
 If N = Nil Then Exit;
 If N^.Prev <> Nil Then N^.Prev^.Next := N^.Next Else L.Head := N^.Next;
 If N^.Next <> Nil Then N^.Next^.Prev := N^.Prev Else L.Tail := N^.Prev;
 FreeMem(N, SizeOf(TObjNode));
 Dec(L.Count);
 L.Cur := Nil; L.CurIdx := 0;
End;

Procedure ListClear(Var L: TObjList);
Var N, M: PObjNode;
Begin
 N := L.Head;
 While N <> Nil Do Begin
  M := N^.Next;
  FreeMem(N, SizeOf(TObjNode));
  N := M;
 End;
 L.Head := Nil; L.Tail := Nil; L.Cur := Nil; L.Count := 0; L.CurIdx := 0;
End;

Function ObjAt(I: Integer): PGraphicObject;
Begin
 ObjAt := ListAt(ObjList, I);
End;

Procedure AppendObject(Var O: TGraphicObject);
Begin
 If Not ListAdd(ObjList, O) Then
  StatusMessage := 'Memoire insuffisante : objet non ajoute.';
 ObjectCount := ObjList.Count;
End;

Procedure DeleteObjectAt(I: Integer);
Begin
 ListDelete(ObjList, I);
 ObjectCount := ObjList.Count;
End;

Procedure ClearObjects;
Begin
 ListClear(ObjList);
 ObjectCount := 0;
End;

Function ImpAt(I: Integer): PGraphicObject;
Begin
 ImpAt := ListAt(ImpList, I);
End;

Procedure ImpAppend(Var O: TGraphicObject);
Begin
 If Not ListAdd(ImpList, O) Then ImportError := 'Memoire insuffisante pendant l''importation.';
 ImportCount := ImpList.Count;
End;

Procedure ImpClear;
Begin
 ListClear(ImpList);
 ImportCount := 0;
End;

{ Les objets importes deviennent le dessin }
Procedure AdoptImport;
Begin
 ClearObjects;
 ObjList := ImpList;
 ObjectCount := ObjList.Count;
 ImpList.Head := Nil; ImpList.Tail := Nil; ImpList.Cur := Nil;
 ImpList.Count := 0; ImportCount := 0;
End;

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

{ Mode graphique : VGA 640 x 480, ou, avec -maxscreen sous Free Pascal, la
  resolution maximale du pilote D8bit (sans effet sous Turbo Pascal). }
Procedure SelectScreenDriverMode(WantMaxScreen: Boolean;
 Var Driver, Mode: Integer);
{$IFDEF FPC}
Var LoMode, HiMode: SmallInt;
{$ENDIF}
Begin
 {$IFDEF FPC}
 Driver := VGA;
 Mode := VGAHi;
 If WantMaxScreen Then Begin
  Driver := D8bit;
  GetModeRange(Driver, LoMode, HiMode);
  If HiMode >= LoMode Then Mode := HiMode
  Else Begin Driver := VGA; Mode := VGAHi; End;
 End;
 {$ELSE}
 Driver := VGA;
 Mode := VGAHi;
 {$ENDIF}
End;

{ Les seize couleurs de l'interface restent identiques dans le pilote D8bit. }
Procedure InitializeScreenPalette;
{$IFDEF FPC}
Const
 RGB: Array[0..15, 0..2] of Byte = (
  (0,0,0), (0,0,170), (0,170,0), (0,170,170),
  (170,0,0), (170,0,170), (170,85,0), (170,170,170),
  (85,85,85), (85,85,255), (85,255,85), (85,255,255),
  (255,85,85), (255,85,255), (255,255,85), (255,255,255));
Var I: Integer;
{$ENDIF}
Begin
 {$IFDEF FPC}
 If GetMaxColor > 15 Then
  For I := 0 To 15 Do SetRGBPalette(I, RGB[I,0], RGB[I,1], RGB[I,2]);
 {$ENDIF}
End;

Procedure InitGraphics;
Var C, X, Y: Integer;
Begin
 SelectScreenDriverMode(MaxScreen, GraphDriver, GraphMode);
 InitGraph(GraphDriver, GraphMode, '');
 If GraphResult <> grOk Then
 Begin
  Writeln('Erreur graphique');
  Halt(1);
 End;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
 InitializeScreenPalette;
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

Type
 PGuide = ^TGuide;
 TGuide = Record
  Horiz: Boolean;       { True : repere horizontal (position Y) }
  Pos: Integer;         { position dans le document }
  Next: PGuide;
 End;

Var
 GuideHead, GuideCur: PGuide;   { liste chainee des reperes (tas) }
 RulersVisible, GuidesVisible, GuideDragging, GuideNew: Boolean;
 GuideOldPos: Integer;

Function RulerPx: Integer;
Begin
 If RulersVisible Then RulerPx := RULER_SIZE Else RulerPx := 0;
End;

Procedure ClearGuides;
Var G, N: PGuide;
Begin
 G := GuideHead;
 While G <> Nil Do Begin
  N := G^.Next;
  Dispose(G);
  G := N;
 End;
 GuideHead := Nil; GuideCur := Nil; GuideDragging := False;
End;

Procedure RemoveGuide(Target: PGuide);
Var G: PGuide;
Begin
 If Target = Nil Then Exit;
 If GuideHead = Target Then GuideHead := Target^.Next
 Else Begin
  G := GuideHead;
  While (G <> Nil) And (G^.Next <> Target) Do G := G^.Next;
  If G <> Nil Then G^.Next := Target^.Next;
 End;
 Dispose(Target);
End;

Procedure DrawGuides;
Var G: PGuide; P: Integer;
Begin
 If Not GuidesVisible Then Exit;
 SetColor(9);
 G := GuideHead;
 While G <> Nil Do Begin
  If G^.Horiz Then Begin
   P := ScreenY(G^.Pos);
   Line(0,P,ScreenWidth,P);
  End Else Begin
   P := ScreenX(G^.Pos);
   Line(P,0,P,ScreenHeight);
  End;
  G := G^.Next;
 End;
End;

Procedure DrawRulers;
Var W, H, K, V, X, Y, Step: LongInt; S: String;
Begin
 If Not RulersVisible Then Exit;
 W := ScreenWidth-TOOLBAR_WIDTH;
 H := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT;
 SetFillStyle(SolidFill,COLOR_BG);
 Bar(0,0,W-1,RULER_SIZE-1);
 Bar(0,0,RULER_SIZE-1,H-1);
 SetColor(COLOR_BORDER);
 Line(0,RULER_SIZE,W-1,RULER_SIZE);
 Line(RULER_SIZE,0,RULER_SIZE,H-1);
 SetColor(COLOR_TEXT);
 Step := 10;
 While Step*ZoomScale < 6 Do Step := Step*2;
 K := Trunc(ViewX/Step)-1;
 Repeat
  V := K*Step;
  X := ScreenX(V);
  If X >= RULER_SIZE Then Begin
   If K Mod 5 = 0 Then Line(X,RULER_SIZE-7,X,RULER_SIZE-1)
   Else Line(X,RULER_SIZE-4,X,RULER_SIZE-1);
   If K Mod 10 = 0 Then Begin Str(V,S); OutTextXY(X+2,0,S); End;
  End;
  Inc(K);
 Until X >= W;
 K := Trunc(ViewY/Step)-1;
 Repeat
  V := K*Step;
  Y := ScreenY(V);
  If Y >= RULER_SIZE Then Begin
   If K Mod 5 = 0 Then Line(RULER_SIZE-7,Y,RULER_SIZE-1,Y)
   Else Line(RULER_SIZE-4,Y,RULER_SIZE-1,Y);
   If K Mod 10 = 0 Then Begin Str(V Div 100,S); If Length(S) <= 2 Then OutTextXY(0,Y+2,S); End;
  End;
  Inc(K);
 Until Y >= H;
 SetFillStyle(SolidFill,COLOR_BG);
 Bar(0,0,RULER_SIZE-1,RULER_SIZE-1);
 SetColor(COLOR_BORDER);
 Rectangle(0,0,RULER_SIZE,RULER_SIZE);
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

{ Taille du texte : FontSize/8 (1 a 4) ; style : Rectangle.Width (sous-
  enregistrement inutilise d'un texte) = 1 gras, 2 italique, 4 souligne }
Var
 TextFrames, GreekText: Boolean;

Function TextScaleOf(Var O: TGraphicObject): Integer;
Var R: Real;
Begin
 R := O.TextObj.FontSize;
 If (R < 8) Or (R > 1000) Then TextScaleOf := 1
 Else If R >= 32 Then TextScaleOf := 4
 Else TextScaleOf := Round(R/8);
End;

Function TextStyleOf(Var O: TGraphicObject): Integer;
Var R: Real;
Begin
 R := O.Rectangle.Width;
 If (R >= 1) And (R < 8) Then TextStyleOf := Round(R) Else TextStyleOf := 0;
End;

Function GlyphPixel(Var Obj: TGraphicObject; Sc, SXr, Row: Integer): Boolean;
Var Cell, C: Integer;
Begin
 GlyphPixel := False;
 If (SXr < 0) Or (SXr >= Length(Obj.TextObj.Text)*8*Sc) Then Exit;
 Cell := SXr Div (8*Sc);
 C := Ord(Obj.TextObj.Text[Cell+1]);
 GlyphPixel := (GlyphRows[C,Row] And (1 Shl (((SXr Mod (8*Sc)) Div Sc)))) <> 0;
End;

Procedure DrawZoomedText(Obj: TGraphicObject);
Var X, Y, L, T, R, B, SXr, SYr, Sc, St, Shear, W, H, Pad: Integer; On: Boolean;
Begin
 Sc := TextScaleOf(Obj); St := TextStyleOf(Obj);
 W := Length(Obj.TextObj.Text)*8*Sc; H := 8*Sc;
 Pad := 0;
 If (St And 2) <> 0 Then Pad := 2*Sc;
 L := ScreenX(Obj.TextObj.X); T := ScreenY(Obj.TextObj.Y);
 R := ScreenX(Obj.TextObj.X+W+Pad)-1;
 B := ScreenY(Obj.TextObj.Y+H)-1;
 If L < 0 Then L := 0;
 If T < 0 Then T := 0;
 If R >= ScreenWidth-TOOLBAR_WIDTH Then R := ScreenWidth-TOOLBAR_WIDTH-1;
 If B >= ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT Then
  B := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1;
 For Y := T To B Do Begin
  SYr := Trunc(ViewY+(Y+0.5)/ZoomScale-Obj.TextObj.Y);
  If (SYr >= 0) And (SYr < H) Then Begin
   Shear := 0;
   If (St And 2) <> 0 Then Shear := (H-1-SYr) Div 4;
   For X := L To R Do Begin
    SXr := Trunc(ViewX+(X+0.5)/ZoomScale-Obj.TextObj.X)-Shear;
    On := GlyphPixel(Obj,Sc,SXr,SYr Div Sc);
    If Not On And ((St And 1) <> 0) Then On := GlyphPixel(Obj,Sc,SXr-1,SYr Div Sc);
    If ((St And 4) <> 0) And (SYr = H-1) And (SXr >= 0) And (SXr < W) Then On := True;
    If On Then PutPixel(X,Y,Obj.TextObj.Color);
   End;
  End;
 End;
End;

Procedure DrawGraphicObject(Obj: TGraphicObject);
Var
 X1, Y1, X2, Y2, I: Integer;
 P, Q: TPoint2D;
 Polygon: Array[0..99] Of PointType;
 Wd: Real;
Begin
 If Not Obj.Visible Then Exit;
 Case Obj.ObjType Of
  OBJ_RECT: Wd := Obj.Rectangle.StrokeWidth;
  OBJ_ELLIPSE: Wd := Obj.Ellipse.StrokeWidth;
  OBJ_LINE: Wd := Obj.Line.StrokeWidth;
  OBJ_BEZIER, OBJ_PATH, OBJ_FILLED_PATH: Wd := Obj.Path.StrokeWidth;
 Else Wd := 1;
 End;
 If Wd >= 2 Then SetLineStyle(SolidLn,0,ThickWidth);

 Case Obj.ObjType Of
  OBJ_RECT:
  Begin
   X1 := ScreenX(Obj.Rectangle.X);
   Y1 := ScreenY(Obj.Rectangle.Y);
   X2 := ScreenX(Obj.Rectangle.X+Obj.Rectangle.Width);
   Y2 := ScreenY(Obj.Rectangle.Y+Obj.Rectangle.Height);
   
   If Obj.Rectangle.FillColor <> 15 Then Begin
    Polygon[0].X := X1; Polygon[0].Y := Y1;
    Polygon[1].X := X2; Polygon[1].Y := Y1;
    Polygon[2].X := X2; Polygon[2].Y := Y2;
    Polygon[3].X := X1; Polygon[3].Y := Y2;
    SetFillStyle(SolidFill,Obj.Rectangle.FillColor);
    SetColor(Obj.Rectangle.FillColor);
    FillPoly(4,Polygon);
   End;
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
   
   If Obj.Ellipse.FillColor <> 15 Then Begin
    SetFillStyle(SolidFill,Obj.Ellipse.FillColor);
    SetColor(Obj.Ellipse.FillColor);
    FillEllipse(X1, Y1, Round(Obj.Ellipse.RX*ZoomScale),
                Round(Obj.Ellipse.RY*ZoomScale));
   End;
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
   If GreekText Then Begin
    I := TextScaleOf(Obj);
    SetFillStyle(SolidFill,Obj.TextObj.Color);
    Bar(ScreenX(Obj.TextObj.X),ScreenY(Obj.TextObj.Y+3*I),
        ScreenX(Obj.TextObj.X+Length(Obj.TextObj.Text)*8*I)-1,
        ScreenY(Obj.TextObj.Y+5*I));
   End Else If (ZoomIndex = 2) And (TextScaleOf(Obj) = 1) And
      (TextStyleOf(Obj) = 0) Then Begin
    SetColor(Obj.TextObj.Color);
    OutTextXY(ScreenX(Obj.TextObj.X),ScreenY(Obj.TextObj.Y),Obj.TextObj.Text);
   End Else DrawZoomedText(Obj);
   If TextFrames Then Begin
    I := TextScaleOf(Obj);
    SetColor(8);
    SetLineStyle(DottedLn,0,NormWidth);
    Rectangle(ScreenX(Obj.TextObj.X)-1,ScreenY(Obj.TextObj.Y)-1,
              ScreenX(Obj.TextObj.X+Length(Obj.TextObj.Text)*8*I),
              ScreenY(Obj.TextObj.Y+8*I));
    SetLineStyle(SolidLn,0,NormWidth);
   End;
  End;
 End;
 SetLineStyle(SolidLn,0,NormWidth);
End;

Procedure DrawObject(Index: Integer);
Begin
 DrawGraphicObject(ObjAt(Index)^);
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
   B.R := B.L+Length(Obj.TextObj.Text)*8*TextScaleOf(Obj)-1;
   If (TextStyleOf(Obj) And 2) <> 0 Then B.R := B.R+2*TextScaleOf(Obj);
   B.B := B.T+8*TextScaleOf(Obj)-1;
  End;
 End;
 ObjectBounds := B;
End;

{ ------------------------------------------------------------------
  Selection multiple et groupes.
  Le format des objets ne change pas : chaque objet n'utilise qu'un seul
  de ses sous-enregistrements (Rectangle, Ellipse, Ligne...). Le
  sous-enregistrement inutilise sert a ranger l'indicateur de selection
  et le numero de groupe (0 = hors groupe).
  ------------------------------------------------------------------ }
Type
 PBoolean = ^Boolean;
 PReal = ^Real;
 PLongArr = ^TLongArr;
 TLongArr = Array[0..1000000] Of LongInt;
 PRealArr = ^TRealArr;
 TRealArr = Array[0..500000] Of Real;

Var
 MarqueeActive: Boolean;
 MqX0, MqY0: Integer;
 LastPickX, LastPickY: Real;
 LastPickOk: Boolean;

{$IFDEF FPC}
{$IFDEF WIN32}
Function GetAsyncKeyState(vKey: LongInt): SmallInt; stdcall; external 'user32.dll' name 'GetAsyncKeyState';
{$ENDIF}
{$ENDIF}

Function ShiftPressed: Boolean;
Begin
 ShiftPressed := False;
 {$IFDEF FPC}
 {$IFDEF WIN32}
 ShiftPressed := (GetAsyncKeyState($10) And $8000) <> 0;
 {$ENDIF}
 {$ENDIF}
End;

Function SelFlagPtr(Var O: TGraphicObject): PBoolean;
Begin
 If O.ObjType = OBJ_RECT Then SelFlagPtr := PBoolean(@O.Line.Selected)
 Else SelFlagPtr := PBoolean(@O.Rectangle.Selected);
End;

Function GroupPtr(Var O: TGraphicObject): PReal;
Begin
 If O.ObjType = OBJ_RECT Then GroupPtr := PReal(@O.Line.X1)
 Else GroupPtr := PReal(@O.Rectangle.X);
End;

Function GroupOfObj(Var O: TGraphicObject): LongInt;
Var R: Real;
Begin
 R := GroupPtr(O)^;
 If (R >= 1) And (R < 1000000000.0) Then GroupOfObj := Round(R)
 Else GroupOfObj := 0;
End;

Procedure SetGroupOfObj(Var O: TGraphicObject; G: LongInt);
Begin
 GroupPtr(O)^ := G;
End;

Function IsFlagged(I: Integer): Boolean;
Begin
 IsFlagged := SelFlagPtr(ObjAt(I)^)^;
End;

Function IsSel(I: Integer): Boolean;
Begin
 IsSel := (I = SelectedObject) Or IsFlagged(I);
End;

Procedure ClearSelFlags;
Var I: Integer;
Begin
 For I := 0 To ObjectCount-1 Do SelFlagPtr(ObjAt(I)^)^ := False;
End;

{ Selectionne l'objet et tous les membres de son groupe }
Procedure SelectGroupOf(I: Integer);
Var J: Integer; G: LongInt;
Begin
 SelFlagPtr(ObjAt(I)^)^ := True;
 G := GroupOfObj(ObjAt(I)^);
 If G = 0 Then Exit;
 For J := 0 To ObjectCount-1 Do
  If GroupOfObj(ObjAt(J)^) = G Then SelFlagPtr(ObjAt(J)^)^ := True;
End;

Function SelCount: Integer;
Var I, N: Integer;
Begin
 N := 0;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) Then Inc(N);
 SelCount := N;
End;

Function OtherSelCount: Integer;
Var I, N: Integer;
Begin
 N := 0;
 For I := 0 To ObjectCount-1 Do
  If (I <> SelectedObject) And IsFlagged(I) Then Inc(N);
 OtherSelCount := N;
End;

Procedure ToggleSelection(I: Integer);
Var J: Integer; G: LongInt;
Begin
 G := GroupOfObj(ObjAt(I)^);
 SelFlagPtr(ObjAt(I)^)^ := False;
 If G <> 0 Then
  For J := 0 To ObjectCount-1 Do
   If GroupOfObj(ObjAt(J)^) = G Then SelFlagPtr(ObjAt(J)^)^ := False;
 If (SelectedObject >= 0) And Not IsFlagged(SelectedObject) Then Begin
  SelectedObject := -1;
  For J := ObjectCount-1 DownTo 0 Do
   If IsFlagged(J) Then Begin SelectedObject := J; Break; End;
 End;
End;

Function SelectionBounds: TBounds;
Var I: Integer; B, U: TBounds; First: Boolean;
Begin
 First := True;
 FillChar(U,SizeOf(U),0);
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And ObjAt(I)^.Visible Then Begin
   B := ObjectBounds(ObjAt(I)^);
   If First Then Begin U := B; First := False; End
   Else Begin
    U.L := MinReal(U.L,B.L); U.R := MaxReal(U.R,B.R);
    U.T := MinReal(U.T,B.T); U.B := MaxReal(U.B,B.B);
   End;
  End;
 SelectionBounds := U;
End;

Procedure FinishMarquee(Cancel: Boolean);
Var X0, Y0, X1, Y1, I, N: Integer; B: TBounds; L, T, R, Bt: Real; S: String;
Begin
 If Not MarqueeActive Then Exit;
 MarqueeActive := False;
 DrawingMode := False;
 NeedsRedraw := True;
 If Cancel Then Begin
  StatusMessage := 'Selection annulee.';
  Exit;
 End;
 X1 := DocumentX(MouseX); Y1 := DocumentY(MouseY);
 L := MinReal(MqX0,X1); R := MaxReal(MqX0,X1);
 T := MinReal(MqY0,Y1); Bt := MaxReal(MqY0,Y1);
 If (R-L < 3) And (Bt-T < 3) Then Begin
  StatusMessage := 'Aucun objet selectionne.';
  Exit;
 End;
 N := 0;
 For I := 0 To ObjectCount-1 Do
  If ObjAt(I)^.Visible Then Begin
   B := ObjectBounds(ObjAt(I)^);
   If (B.R >= L) And (B.L <= R) And (B.B >= T) And (B.T <= Bt) Then Begin
    SelectGroupOf(I);
    SelectedObject := I;
    Inc(N);
   End;
  End;
 N := SelCount;
 Str(N,S);
 If N = 0 Then StatusMessage := 'Aucun objet selectionne.'
 Else StatusMessage := S+' objet(s) selectionne(s).';
End;

Procedure DrawMarquee;
Begin
 If Not MarqueeActive Then Exit;
 SetColor(COLOR_HIGHLIGHT);
 SetLineStyle(DottedLn,0,NormWidth);
 Rectangle(ScreenX(MqX0),ScreenY(MqY0),MouseX-TOOLBAR_WIDTH,MouseY-MENUBAR_HEIGHT);
 SetLineStyle(SolidLn,0,NormWidth);
End;

Procedure HandlePosition(Index, Handle: Integer; Var X, Y: Integer);
Var B: TBounds;
Begin
 B := ObjectBounds(ObjAt(Index)^);
 If ObjAt(Index)^.ObjType = OBJ_BEZIER Then Begin
  X := Round(ObjAt(Index)^.Path.Points[Handle].X);
  Y := Round(ObjAt(Index)^.Path.Points[Handle].Y);
 End Else If ObjAt(Index)^.ObjType = OBJ_LINE Then Begin
  If Handle = 0 Then Begin
   X := Round(ObjAt(Index)^.Line.X1); Y := Round(ObjAt(Index)^.Line.Y1);
  End Else Begin
   X := Round(ObjAt(Index)^.Line.X2); Y := Round(ObjAt(Index)^.Line.Y2);
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
 If OtherSelCount > 0 Then Exit;
 If Not ObjAt(SelectedObject)^.Visible Then Exit;
 If ObjAt(SelectedObject)^.ObjType = OBJ_TEXT Then Exit;
 N := 8;
 If ObjAt(SelectedObject)^.ObjType = OBJ_BEZIER Then N := 4;
 If ObjAt(SelectedObject)^.ObjType = OBJ_LINE Then N := 2;
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
 If Not ObjAt(Index)^.Visible Then Exit;
 B := ObjectBounds(ObjAt(Index)^);
 Margin := 5/ZoomScale;
 Case ObjAt(Index)^.ObjType Of
  OBJ_RECT: ObjectHit := (X >= B.L-3/ZoomScale) And (X <= B.R+3/ZoomScale) And
                         (Y >= B.T-3/ZoomScale) And (Y <= B.B+3/ZoomScale);
  OBJ_ELLIPSE: Begin
   DX := MaxReal(ObjAt(Index)^.Ellipse.RX,1);
   DY := MaxReal(ObjAt(Index)^.Ellipse.RY,1);
   ObjectHit := Sqr((X-ObjAt(Index)^.Ellipse.CX)/(DX+3/ZoomScale))+
                Sqr((Y-ObjAt(Index)^.Ellipse.CY)/(DY+3/ZoomScale)) <= 1;
  End;
  OBJ_LINE: Begin
   DX := ObjAt(Index)^.Line.X2-ObjAt(Index)^.Line.X1;
   DY := ObjAt(Index)^.Line.Y2-ObjAt(Index)^.Line.Y1;
   D := Sqr(DX)+Sqr(DY);
   U := 0;
   If D > 0 Then U := ((X-ObjAt(Index)^.Line.X1)*DX+
                       (Y-ObjAt(Index)^.Line.Y1)*DY)/D;
   U := MaxReal(0,MinReal(1,U));
   ObjectHit := Sqr(X-ObjAt(Index)^.Line.X1-U*DX)+
                Sqr(Y-ObjAt(Index)^.Line.Y1-U*DY) <= Sqr(Margin);
  End;
  OBJ_BEZIER: Begin
   P := BezierPoint(ObjAt(Index)^,0);
   For I := 1 To BEZIER_STEPS Do Begin
    Q := BezierPoint(ObjAt(Index)^,I/BEZIER_STEPS);
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
   For I := 0 To ObjAt(Index)^.Path.PointCount-1 Do Begin
    J := I-1;
    If J < 0 Then
     If ObjAt(Index)^.Path.Closed Then J := ObjAt(Index)^.Path.PointCount-1
     Else J := 0;
    If (ObjAt(Index)^.ObjType = OBJ_FILLED_PATH) And
       ((ObjAt(Index)^.Path.Points[I].Y > Y) <>
        (ObjAt(Index)^.Path.Points[J].Y > Y)) Then
     If X < ObjAt(Index)^.Path.Points[I].X+
       (Y-ObjAt(Index)^.Path.Points[I].Y)*
       (ObjAt(Index)^.Path.Points[J].X-ObjAt(Index)^.Path.Points[I].X)/
       (ObjAt(Index)^.Path.Points[J].Y-ObjAt(Index)^.Path.Points[I].Y) Then
      Inside := Not Inside;
    DX := ObjAt(Index)^.Path.Points[I].X-ObjAt(Index)^.Path.Points[J].X;
    DY := ObjAt(Index)^.Path.Points[I].Y-ObjAt(Index)^.Path.Points[J].Y;
    D := Sqr(DX)+Sqr(DY); U := 0;
    If D > 0 Then U := ((X-ObjAt(Index)^.Path.Points[J].X)*DX+
                       (Y-ObjAt(Index)^.Path.Points[J].Y)*DY)/D;
    U := MaxReal(0,MinReal(1,U));
    If Sqr(X-ObjAt(Index)^.Path.Points[J].X-U*DX)+
       Sqr(Y-ObjAt(Index)^.Path.Points[J].Y-U*DY) <= Sqr(Margin) Then Begin
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
Var I, N, X, Y: Integer; B: TBounds; Multi: Boolean;
Begin
 If CurrentTool <> TOOL_SELECT Then Exit;
 DrawMarquee;
 Multi := False;
 For I := 0 To ObjectCount-1 Do
  If (I <> SelectedObject) And IsFlagged(I) And ObjAt(I)^.Visible Then Begin
   Multi := True;
   B := ObjectBounds(ObjAt(I)^);
   SetColor(COLOR_HIGHLIGHT);
   SetLineStyle(DottedLn,0,NormWidth);
   Rectangle(ScreenX(B.L)-2,ScreenY(B.T)-2,ScreenX(B.R)+2,ScreenY(B.B)+2);
   SetLineStyle(SolidLn,0,NormWidth);
   SetFillStyle(SolidFill,COLOR_HIGHLIGHT);
   Bar(ScreenX(B.L)-3,ScreenY(B.T)-3,ScreenX(B.L)-1,ScreenY(B.T)-1);
   Bar(ScreenX(B.R)+1,ScreenY(B.T)-3,ScreenX(B.R)+3,ScreenY(B.T)-1);
   Bar(ScreenX(B.L)-3,ScreenY(B.B)+1,ScreenX(B.L)-1,ScreenY(B.B)+3);
   Bar(ScreenX(B.R)+1,ScreenY(B.B)+1,ScreenX(B.R)+3,ScreenY(B.B)+3);
  End;
 If (SelectedObject < 0) Or (SelectedObject >= ObjectCount) Then Exit;
 If Not ObjAt(SelectedObject)^.Visible Then Exit;
 B := ObjectBounds(ObjAt(SelectedObject)^);
 SetColor(COLOR_HIGHLIGHT);
 SetLineStyle(DottedLn,0,NormWidth);
 Rectangle(ScreenX(B.L),ScreenY(B.T),ScreenX(B.R),ScreenY(B.B));
 SetLineStyle(SolidLn,0,NormWidth);
 If Multi Then Begin
  Rectangle(ScreenX(B.L)-2,ScreenY(B.T)-2,ScreenX(B.R)+2,ScreenY(B.B)+2);
  SetFillStyle(SolidFill,COLOR_HIGHLIGHT);
  Bar(ScreenX(B.L)-3,ScreenY(B.T)-3,ScreenX(B.L)-1,ScreenY(B.T)-1);
  Bar(ScreenX(B.R)+1,ScreenY(B.T)-3,ScreenX(B.R)+3,ScreenY(B.T)-1);
  Bar(ScreenX(B.L)-3,ScreenY(B.B)+1,ScreenX(B.L)-1,ScreenY(B.B)+3);
  Bar(ScreenX(B.R)+1,ScreenY(B.B)+1,ScreenX(B.R)+3,ScreenY(B.B)+3);
  Exit;
 End;
 If ObjAt(SelectedObject)^.ObjType = OBJ_BEZIER Then
  DrawBezierHandles(ObjAt(SelectedObject)^,False);
 N := 8;
 If ObjAt(SelectedObject)^.ObjType = OBJ_BEZIER Then N := 4;
 If ObjAt(SelectedObject)^.ObjType = OBJ_TEXT Then N := 0;
 If ObjAt(SelectedObject)^.ObjType = OBJ_LINE Then N := 2;
 For I := 0 To N-1 Do Begin
  HandlePosition(SelectedObject,I,X,Y);
  X := ScreenX(X); Y := ScreenY(Y);
  SetFillStyle(SolidFill,COLOR_WINDOW);
  Bar(X-3,Y-3,X+3,Y+3);
  Rectangle(X-3,Y-3,X+3,Y+3);
 End;
End;

{ ------------------------------------------------------------------
  Annuler / Retablir / Couper / Copier / Coller
  Chaque etat du dessin (objets, selection) est conserve dans un instantane
  place sur une pile ; l'instantane est pris AVANT chaque modification.
  ------------------------------------------------------------------ }
Type
 TSnapshot = Record
  Count, Sel: Integer;
  Modified: Boolean;
  Data: Pointer;
 End;

Const
 {$IFDEF FPC}
 MAX_UNDO = 30;
 {$ELSE}
 MAX_UNDO = 3;
 {$ENDIF}

Var
 UndoStack, RedoStack: Array[0..MAX_UNDO-1] Of TSnapshot;
 UndoCount, RedoCount: Integer;
 ClipObject: TGraphicObject;
 ClipFull: Boolean;

Procedure FreeSnapshot(Var Snap: TSnapshot);
Begin
 If Snap.Data <> Nil Then
  FreeMem(Snap.Data, LongInt(Snap.Count)*SizeOf(TGraphicObject));
 Snap.Data := Nil;
 Snap.Count := 0;
End;

Type
 TSnapBlock = Array[0..32000] Of Byte;
 PSnapBlock = ^TSnapBlock;

Function TakeSnapshot(Var Snap: TSnapshot): Boolean;
Var I: Integer;
{$IFDEF FPC}
    Previous: Boolean;
{$ENDIF}
Begin
 TakeSnapshot := False;
 Snap.Count := ObjectCount;
 Snap.Sel := SelectedObject;
 Snap.Modified := FileModified;
 Snap.Data := Nil;
 If ObjectCount > 0 Then Begin
  {$IFDEF FPC}
  Previous := ReturnNilIfGrowHeapFails;
  ReturnNilIfGrowHeapFails := True;
  GetMem(Snap.Data, LongInt(ObjectCount)*SizeOf(TGraphicObject));
  ReturnNilIfGrowHeapFails := Previous;
  If Snap.Data = Nil Then Exit;
  {$ELSE}
  If MaxAvail < LongInt(ObjectCount)*SizeOf(TGraphicObject)+8192 Then Exit;
  GetMem(Snap.Data, LongInt(ObjectCount)*SizeOf(TGraphicObject));
  {$ENDIF}
  For I := 0 To ObjectCount-1 Do
   Move(ObjAt(I)^, PSnapBlock(Snap.Data)^[LongInt(I)*SizeOf(TGraphicObject)],
        SizeOf(TGraphicObject));
 End;
 TakeSnapshot := True;
End;

Procedure RestoreSnapshot(Var Snap: TSnapshot);
Var I: Integer; O: TGraphicObject;
Begin
 ClearObjects;
 For I := 0 To Snap.Count-1 Do Begin
  Move(PSnapBlock(Snap.Data)^[LongInt(I)*SizeOf(TGraphicObject)], O, SizeOf(O));
  AppendObject(O);
 End;
 SelectedObject := Snap.Sel;
 If SelectedObject >= ObjectCount Then SelectedObject := -1;
 FileModified := True;
End;

Procedure ClearRedo;
Var I: Integer;
Begin
 For I := 0 To RedoCount-1 Do FreeSnapshot(RedoStack[I]);
 RedoCount := 0;
End;

Procedure ClearHistory;
Var I: Integer;
Begin
 For I := 0 To UndoCount-1 Do FreeSnapshot(UndoStack[I]);
 UndoCount := 0;
 ClearRedo;
End;

{ A appeler avant toute modification du dessin }
Procedure PushUndo;
Var I: Integer;
Begin
 ClearRedo;
 If UndoCount >= MAX_UNDO Then Begin
  FreeSnapshot(UndoStack[0]);
  For I := 1 To MAX_UNDO-1 Do UndoStack[I-1] := UndoStack[I];
  Dec(UndoCount);
 End;
 If TakeSnapshot(UndoStack[UndoCount]) Then Inc(UndoCount)
 Else StatusMessage := 'Memoire insuffisante : modification non annulable.';
End;

Function EditingBusy: Boolean;
Begin
 EditingBusy := DrawingMode Or EditingObject Or TextActive Or PencilActive Or
                (BezierStage <> 0);
End;

Procedure UndoCommand;
Begin
 If EditingBusy Then Begin
  StatusMessage := 'Terminer l''operation en cours avant d''annuler.';
  Exit;
 End;
 If UndoCount = 0 Then Begin
  StatusMessage := 'Rien a annuler.';
  Exit;
 End;
 If RedoCount >= MAX_UNDO Then Begin
  FreeSnapshot(RedoStack[0]);
  Move(RedoStack[1], RedoStack[0], (MAX_UNDO-1)*SizeOf(TSnapshot));
  Dec(RedoCount);
 End;
 If TakeSnapshot(RedoStack[RedoCount]) Then Inc(RedoCount);
 Dec(UndoCount);
 RestoreSnapshot(UndoStack[UndoCount]);
 FreeSnapshot(UndoStack[UndoCount]);
 StatusMessage := 'Annule.';
 NeedsRedraw := True;
End;

Procedure RedoCommand;
Begin
 If EditingBusy Then Begin
  StatusMessage := 'Terminer l''operation en cours avant de retablir.';
  Exit;
 End;
 If RedoCount = 0 Then Begin
  StatusMessage := 'Rien a retablir.';
  Exit;
 End;
 If UndoCount >= MAX_UNDO Then Begin
  FreeSnapshot(UndoStack[0]);
  Move(UndoStack[1], UndoStack[0], (MAX_UNDO-1)*SizeOf(TSnapshot));
  Dec(UndoCount);
 End;
 If TakeSnapshot(UndoStack[UndoCount]) Then Inc(UndoCount);
 Dec(RedoCount);
 RestoreSnapshot(RedoStack[RedoCount]);
 FreeSnapshot(RedoStack[RedoCount]);
 StatusMessage := 'Retabli.';
 NeedsRedraw := True;
End;

Var
 EditSnap: TSnapshot;
 EditMulti, EditMoved: Boolean;

Procedure OffsetObject(Var O: TGraphicObject; DX, DY: Real);
Var I: Integer;
Begin
 Case O.ObjType Of
  OBJ_RECT: Begin O.Rectangle.X := O.Rectangle.X+DX; O.Rectangle.Y := O.Rectangle.Y+DY; End;
  OBJ_ELLIPSE: Begin O.Ellipse.CX := O.Ellipse.CX+DX; O.Ellipse.CY := O.Ellipse.CY+DY; End;
  OBJ_LINE: Begin
   O.Line.X1 := O.Line.X1+DX; O.Line.Y1 := O.Line.Y1+DY;
   O.Line.X2 := O.Line.X2+DX; O.Line.Y2 := O.Line.Y2+DY;
  End;
  OBJ_TEXT: Begin O.TextObj.X := O.TextObj.X+DX; O.TextObj.Y := O.TextObj.Y+DY; End;
  OBJ_PATH, OBJ_BEZIER, OBJ_FILLED_PATH:
   For I := 0 To O.Path.PointCount-1 Do Begin
    O.Path.Points[I].X := O.Path.Points[I].X+DX;
    O.Path.Points[I].Y := O.Path.Points[I].Y+DY;
    O.Path.Points[I].CtrlX1 := O.Path.Points[I].CtrlX1+DX;
    O.Path.Points[I].CtrlY1 := O.Path.Points[I].CtrlY1+DY;
    O.Path.Points[I].CtrlX2 := O.Path.Points[I].CtrlX2+DX;
    O.Path.Points[I].CtrlY2 := O.Path.Points[I].CtrlY2+DY;
   End;
 End;
End;

Function HasSelection: Boolean;
Begin
 HasSelection := (SelectedObject >= 0) And (SelectedObject < ObjectCount) And
                 Not EditingBusy;
End;

Procedure CopyCommand;
Begin
 If Not HasSelection Then Begin
  StatusMessage := 'Selectionner un objet a copier.';
  Exit;
 End;
 ClipObject := ObjAt(SelectedObject)^;
 ClipFull := True;
 StatusMessage := 'Objet copie.';
End;

Procedure CutCommand;
Var I: Integer;
Begin
 If Not HasSelection Then Begin
  StatusMessage := 'Selectionner un objet a couper.';
  Exit;
 End;
 ClipObject := ObjAt(SelectedObject)^;
 ClipFull := True;
 PushUndo;
 DeleteObjectAt(SelectedObject);
 SelectedObject := -1;
 ClearSelFlags;
 FileModified := True;
 StatusMessage := 'Objet coupe.';
 NeedsRedraw := True;
End;

Procedure PasteCommand;
Begin
 If EditingBusy Then Begin
  StatusMessage := 'Terminer l''operation en cours avant de coller.';
  Exit;
 End;
 If Not ClipFull Then Begin
  StatusMessage := 'Le presse-papiers est vide.';
  Exit;
 End;
 PushUndo;
 OffsetObject(ClipObject, 12, 12);
 ClipObject.LayerIndex := CurrentLayer;
 ClipObject.Visible := True;
 ClearSelFlags;
 SetGroupOfObj(ClipObject,0);
 SelFlagPtr(ClipObject)^ := True;
 AppendObject(ClipObject);
 SelectedObject := ObjectCount-1;
 FileModified := True;
 StatusMessage := 'Objet colle.';
 NeedsRedraw := True;
End;

{ Les deux objets sont-ils identiques octet pour octet ? }
Type
 TByteBlock = Array[0..32000] Of Byte;
 PByteBlock = ^TByteBlock;

Function SameObject(Var A, B: TGraphicObject): Boolean;
Var PA, PB: PByteBlock; I: Integer; R: Boolean;
Begin
 R := True;
 PA := PByteBlock(@A); PB := PByteBlock(@B);
 For I := 0 To SizeOf(TGraphicObject)-1 Do
  If PA^[I] <> PB^[I] Then Begin R := False; Break; End;
 SameObject := R;
End;

Procedure CancelObjectEdit;
Begin
 If Not EditingObject Then Exit;
 If EditMulti Then Begin
  RestoreSnapshot(EditSnap);
  FreeSnapshot(EditSnap);
  EditMulti := False;
 End Else ObjAt(SelectedObject)^ := EditOriginal;
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
 If EditMulti And (EditHandle < 0) Then Begin
  DX := MaxReal(-B.L,MinReal(ScreenWidth-TOOLBAR_WIDTH-1-B.R,DX));
  DY := MaxReal(-B.T,MinReal(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-1-B.B,DY));
  For I := 0 To ObjectCount-1 Do
   If IsFlagged(I) Then Begin
    Move(PSnapBlock(EditSnap.Data)^[LongInt(I)*SizeOf(TGraphicObject)],Obj,SizeOf(Obj));
    OffsetObject(Obj,DX,DY);
    ObjAt(I)^ := Obj;
   End;
  EditMoved := (DX <> 0) Or (DY <> 0);
  FileModified := EditWasModified Or EditMoved;
  NeedsRedraw := True;
  Exit;
 End;
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
 ObjAt(SelectedObject)^ := Obj;
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
 If Index >= 0 Then TextObject := ObjAt(Index)^;
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
 I, Hit: Integer;
 Shift: Boolean;
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
 
 If CurrentTool <> TOOL_SELECT Then ClearSelFlags;
 Case CurrentTool Of
  TOOL_BEZIER, TOOL_PEN:
  Begin
   If BezierStage = 2 Then Begin
    UpdateBezier;
    BezierStage := 3;
   End Else Begin
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
    If (ObjAt(I)^.ObjType = OBJ_TEXT) And ObjectHit(I,CanvasX,CanvasY) Then Begin
     TextEditIndex := I;
     Break;
    End;
   If TextEditIndex < 0 Then Begin
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
   EditMulti := False;
   If EditHandle < 0 Then Begin
    Hit := -1;
    For I := ObjectCount-1 DownTo 0 Do
     If ObjectHit(I,CanvasX,CanvasY) Then Begin
      Hit := I;
      Break;
     End;
    Shift := ShiftPressed;
    If Hit < 0 Then Begin
     If Not Shift Then Begin ClearSelFlags; SelectedObject := -1; End;
     MarqueeActive := True; MqX0 := CanvasX; MqY0 := CanvasY;
     LastPickOk := False;
     DrawingMode := True;
     StatusMessage := 'Glisser : selection par rectangle (Maj : ajouter).';
     Exit;
    End;
    If Shift And IsSel(Hit) Then Begin
     ToggleSelection(Hit);
     StatusMessage := 'Objet retire de la selection.';
     Exit;
    End;
    If Not IsSel(Hit) Then Begin
     If Not Shift Then ClearSelFlags;
     SelectGroupOf(Hit);
    End;
    SelectedObject := Hit;
    LastPickX := CanvasX; LastPickY := CanvasY; LastPickOk := True;
   End;
   If SelectedObject >= 0 Then Begin
    EditOriginal := ObjAt(SelectedObject)^;
    EditBounds := ObjectBounds(EditOriginal);
    If (EditHandle < 0) And (OtherSelCount > 0) Then Begin
     EditBounds := SelectionBounds;
     EditMulti := TakeSnapshot(EditSnap);
     EditMoved := False;
    End;
    EditX := CanvasX; EditY := CanvasY;
    EditWasModified := FileModified;
    EditingObject := True;
    DrawingMode := True;
    If ObjAt(SelectedObject)^.ObjType = OBJ_TEXT Then
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
 NewSnap: TSnapshot;
Begin
 If MarqueeActive Then Begin
  FinishMarquee(False);
  Exit;
 End;
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
   PushUndo;
   AppendObject(BezierObject);
   FileModified := True;
   BezierStage := 0;
   DrawingMode := False;
   StatusMessage := 'Courbe creee. Fleche : deplacer ou modifier les quatre poignees.';
  End;
  Exit;
 End;
 If PencilActive Then Begin
  AddPencilPoint;
  PushUndo;
  AppendObject(PencilObject);
  FileModified := True;
  PencilActive := False;
  DrawingMode := False;
  Exit;
 End;
 If EditingObject Then Begin
  UpdateObjectEdit;
  If EditMulti Then Begin
   EditMulti := False;
   If EditMoved And TakeSnapshot(NewSnap) Then Begin
    RestoreSnapshot(EditSnap);
    PushUndo;
    RestoreSnapshot(NewSnap);
    FreeSnapshot(NewSnap);
   End;
   FreeSnapshot(EditSnap);
   FileModified := EditWasModified Or EditMoved;
  End Else
  { instantane de l'etat d'avant le deplacement ou le redimensionnement }
  If (SelectedObject >= 0) And (SelectedObject < ObjectCount) And
     Not SameObject(ObjAt(SelectedObject)^,EditOriginal) Then Begin
   NewObj := ObjAt(SelectedObject)^;
   ObjAt(SelectedObject)^ := EditOriginal;
   PushUndo;
   ObjAt(SelectedObject)^ := NewObj;
  End;
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
 
 If (MouseX < TOOLBAR_WIDTH) Or (MouseX >= ScreenWidth) Or
    (MouseY < MENUBAR_HEIGHT) Or
    (MouseY >= ScreenHeight-STATUSBAR_HEIGHT) Then Begin
  DrawingMode := False;
  Exit;
 End;
 
 If CurrentTool In [TOOL_RECTANGLE,TOOL_ELLIPSE,TOOL_LINE] Then PushUndo;
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
   AppendObject(NewObj);
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
   AppendObject(NewObj);
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
   AppendObject(NewObj);
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
 AddMenuItem(1, 'Annuler      Ctrl+Z', CMD_UNDO);
 AddMenuItem(1, 'Retablir     Ctrl+Y', CMD_REDO);
 AddMenuItem(1, '-', CMD_NONE);
 AddMenuItem(1, 'Couper       Ctrl+X', CMD_CUT);
 AddMenuItem(1, 'Copier       Ctrl+C', CMD_COPY);
 AddMenuItem(1, 'Coller       Ctrl+V', CMD_PASTE);
 AddMenuItem(1, 'Tout select.  Ctrl+A', CMD_SELALL);
 AddMenuItem(2, 'Zoom avant', CMD_ZOOM_IN);
 AddMenuItem(2, 'Zoom arriere', CMD_ZOOM_OUT);
 AddMenuItem(2, 'Adapter (100%)', CMD_ZOOM_RESET);
 AddMenuItem(2, 'Grille', CMD_GRID);
 AddMenuItem(2, 'Regles       Ctrl+R', CMD_RULERS);
 AddMenuItem(2, 'Reperes', CMD_GUIDES);
 AddMenuItem(2, 'Effacer reperes', CMD_CLEAR_GUIDES);
 AddMenuItem(3, 'Proprietes...', CMD_PROPS);
 AddMenuItem(3, 'Premier plan', CMD_FRONT);
 AddMenuItem(3, 'Avancer', CMD_FORWARD);
 AddMenuItem(3, 'Reculer', CMD_BACKWARD);
 AddMenuItem(3, 'Arriere-plan', CMD_BACK);
 AddMenuItem(3, 'Grouper', CMD_GROUP);
 AddMenuItem(3, 'Degrouper', CMD_UNGROUP);
 AddMenuItem(3, 'Aligner...', CMD_ALIGN);
 AddMenuItem(3, 'Distribuer...', CMD_DISTRIB);
 AddMenuItem(3, 'Transformer...', CMD_TRANSFORM);
 AddMenuItem(3, 'Operations...', CMD_OPS);
 AddMenuItem(4, 'Rejoindre', CMD_PJOIN);
 AddMenuItem(4, 'Scinder', CMD_PSPLIT);
 AddMenuItem(4, 'Cont. Coin', CMD_PCORNER);
 AddMenuItem(4, 'Cont. Courbe', CMD_PSMOOTH);
 AddMenuItem(4, 'Simplifier...', CMD_PSIMPL);
 AddMenuItem(4, 'Decalage...', CMD_POFFSET);
 AddMenuItem(5, 'Glyphes...', CMD_GLYPHS);
 AddMenuItem(5, 'Texte a chemin', CMD_TEXTPATH);
 AddMenuItem(5, 'Chemin a texte', CMD_NONE);
 AddMenuItem(5, 'Polices...', CMD_FONTS);
 AddMenuItem(5, 'Formats...', CMD_FORMATS);
 AddMenuItem(5, 'Affichage...', CMD_TEXTVIEW);
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

{ ------------------------------------------------------------------
  Boite a outils des dialogues : aspect Windows classique
  (face grise, relief 3D, barre de titre bleue, boutons, cases a cocher)
  ------------------------------------------------------------------ }
Type
 TLines = Array[0..7] Of String[60];

Procedure UiBevel(X1, Y1, X2, Y2: Integer; Raised: Boolean);
Begin
 If Raised Then Begin
  SetColor(15); Line(X1,Y1,X2-1,Y1); Line(X1,Y1,X1,Y2-1);
  SetColor(0); Line(X1,Y2,X2,Y2); Line(X2,Y1,X2,Y2);
  SetColor(8); Line(X1+1,Y2-1,X2-1,Y2-1); Line(X2-1,Y1+1,X2-1,Y2-1);
 End Else Begin
  SetColor(8); Line(X1,Y1,X2-1,Y1); Line(X1,Y1,X1,Y2-1);
  SetColor(15); Line(X1,Y2,X2,Y2); Line(X2,Y1,X2,Y2);
  SetColor(0); Line(X1+1,Y1+1,X2-2,Y1+1); Line(X1+1,Y1+1,X1+1,Y2-2);
 End;
End;

Procedure UiRaised(X1, Y1, X2, Y2: Integer);
Begin
 SetFillStyle(SolidFill,COLOR_BG);
 Bar(X1,Y1,X2,Y2);
 UiBevel(X1,Y1,X2,Y2,True);
End;

Procedure UiSunken(X1, Y1, X2, Y2: Integer);
Begin
 SetFillStyle(SolidFill,COLOR_WINDOW);
 Bar(X1,Y1,X2,Y2);
 UiBevel(X1,Y1,X2,Y2,False);
End;

{ cadre grave avec titre (groupe) }
Procedure UiGroup(X1, Y1, X2, Y2: Integer; Caption: String);
Begin
 SetColor(8); Rectangle(X1,Y1+6,X2-1,Y2-1);
 SetColor(15); Rectangle(X1+1,Y1+7,X2,Y2);
 If Caption <> '' Then Begin
  SetFillStyle(SolidFill,COLOR_BG);
  Bar(X1+8,Y1,X1+16+Length(Caption)*8,Y1+12);
  SetColor(COLOR_TEXT);
  OutTextXY(X1+12,Y1+2,Caption);
 End;
End;

Procedure UiText(X, Y: Integer; S: String);
Begin
 SetColor(COLOR_TEXT);
 OutTextXY(X,Y,S);
End;

Procedure UiCross(CX, CY, R: Integer);
Begin
 Line(CX-R,CY-R,CX+R,CY+R); Line(CX-R,CY+R,CX+R,CY-R);
 Line(CX-R+1,CY-R,CX+R+1,CY+R); Line(CX-R+1,CY+R,CX+R+1,CY-R);
End;

{ fenetre : relief, barre de titre bleue et bouton de fermeture }
Procedure UiWindow(X1, Y1, X2, Y2: Integer; Title: String);
Begin
 SetFillStyle(SolidFill,0);
 Bar(X1+4,Y1+4,X2+4,Y2+4);
 UiRaised(X1,Y1,X2,Y2);
 SetFillStyle(SolidFill,COLOR_HIGHLIGHT);
 Bar(X1+3,Y1+3,X2-3,Y1+20);
 SetColor(15);
 OutTextXY(X1+8,Y1+8,Title);
 OutTextXY(X1+9,Y1+8,Title);
 UiRaised(X2-19,Y1+5,X2-5,Y1+18);
 SetColor(0);
 UiCross(X2-12,Y1+11,3);
End;

Function UiInside(X1, Y1, X2, Y2: Integer): Boolean;
Begin
 UiInside := (MouseX >= X1) And (MouseX <= X2) And (MouseY >= Y1) And (MouseY <= Y2);
End;

Function UiCloseHit(X2, Y1: Integer): Boolean;
Begin
 UiCloseHit := UiInside(X2-19,Y1+5,X2-5,Y1+18);
End;

Procedure UiButton(X1, Y1, X2, Y2: Integer; Caption: String; Default, Enabled: Boolean);
Var Down: Boolean; TX, TY: Integer;
Begin
 Down := Enabled And ((MouseButtons And 1) <> 0) And UiInside(X1,Y1,X2,Y2);
 If Default Then Begin
  SetFillStyle(SolidFill,COLOR_BG);
  Bar(X1,Y1,X2,Y2);
  SetColor(0); Rectangle(X1,Y1,X2,Y2);
  UiBevel(X1+1,Y1+1,X2-1,Y2-1,Not Down);
 End Else Begin
  If Down Then Begin
   SetFillStyle(SolidFill,COLOR_BG); Bar(X1,Y1,X2,Y2);
   SetColor(0); Rectangle(X1,Y1,X2,Y2);
   SetColor(8); Rectangle(X1+1,Y1+1,X2-1,Y2-1);
  End Else UiRaised(X1,Y1,X2,Y2);
 End;
 TX := X1+((X2-X1)-Length(Caption)*8) Div 2;
 TY := Y1+((Y2-Y1)-7) Div 2;
 If Down Then Begin Inc(TX); Inc(TY); End;
 If Enabled Then Begin
  SetColor(COLOR_TEXT);
  OutTextXY(TX,TY,Caption);
 End Else Begin
  SetColor(15); OutTextXY(TX+1,TY+1,Caption);
  SetColor(8); OutTextXY(TX,TY,Caption);
 End;
 If Default And Enabled Then Begin
  SetColor(0);
  SetLineStyle(DottedLn,0,NormWidth);
  Rectangle(X1+4,Y1+4,X2-4,Y2-4);
  SetLineStyle(SolidLn,0,NormWidth);
 End;
End;

Procedure UiCheck(X, Y: Integer; Checked: Boolean; Caption: String);
Begin
 UiSunken(X,Y,X+12,Y+12);
 If Checked Then Begin
  SetColor(0);
  UiCross(X+5,Y+5,2);
 End;
 UiText(X+20,Y+3,Caption);
End;

Procedure UiArrow(CX, CY: Integer; Up: Boolean);
Var I: Integer;
Begin
 SetColor(0);
 For I := 0 To 3 Do
  If Up Then Line(CX-I,CY-2+I,CX+I,CY-2+I)
  Else Line(CX-I,CY+2-I,CX+I,CY+2-I);
End;

{ coupe un texte en lignes de Max caracteres au plus }
Function WrapLines(S: String; Max: Integer; Var L: TLines): Integer;
Var N, P, Cut: Integer;
Begin
 N := 0;
 While (S <> '') And (N < 8) Do Begin
  If Length(S) <= Max Then Begin L[N] := S; S := ''; Inc(N); End
  Else Begin
   Cut := Max;
   P := Max;
   While (P > 1) And (S[P] <> ' ') Do Dec(P);
   If P > 1 Then Cut := P;
   L[N] := Copy(S,1,Cut);
   Delete(S,1,Cut);
   While (S <> '') And (S[1] = ' ') Do Delete(S,1,1);
   Inc(N);
  End;
 End;
 WrapLines := N;
End;

Procedure UiIcon(X, Y: Integer; Warn: Boolean);
Var I: Integer;
Begin
 If Warn Then Begin
  SetFillStyle(SolidFill,14);
  For I := 0 To 27 Do Begin
   SetColor(14);
   Line(X+16-I Div 2,Y+3+I,X+16+I Div 2,Y+3+I);
  End;
  SetColor(0);
  Line(X+16,Y+3,X,Y+31); Line(X+16,Y+3,X+32,Y+31); Line(X,Y+31,X+32,Y+31);
  Bar(X+15,Y+12,X+17,Y+22);
  Bar(X+15,Y+25,X+17,Y+27);
 End Else Begin
  SetFillStyle(SolidFill,COLOR_HIGHLIGHT);
  FillEllipse(X+16,Y+16,15,15);
  SetColor(15);
  Ellipse(X+16,Y+16,0,360,15,15);
  SetFillStyle(SolidFill,15);
  Bar(X+14,Y+7,X+17,Y+10);
  Bar(X+14,Y+13,X+17,Y+25);
  Bar(X+12,Y+13,X+17,Y+15);
  Bar(X+12,Y+23,X+19,Y+25);
 End;
End;

Procedure DrawMenu;
Var I, X, Y, H: Integer;
Begin
 If Not MenuActive Then Exit;
 X := MenuLeft(ActiveMenu);
 H := Menus[ActiveMenu].ItemCount*MENU_ITEM_HEIGHT+4;
 SetFillStyle(SolidFill, COLOR_BG);
 Bar(X, MENUBAR_HEIGHT, X+Menus[ActiveMenu].Width, MENUBAR_HEIGHT+H);
 UiBevel(X, MENUBAR_HEIGHT, X+Menus[ActiveMenu].Width, MENUBAR_HEIGHT+H,True);
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
    Bar(X+3, Y, X+Menus[ActiveMenu].Width-3, Y+MENU_ITEM_HEIGHT-1);
    SetColor(COLOR_WINDOW);
   End Else Begin
    SetColor(COLOR_TEXT);
   End;
   If Menus[ActiveMenu].Items[I].Command = CMD_NONE Then Begin
    SetColor(15); OutTextXY(X+21, Y+6, Menus[ActiveMenu].Items[I].Caption);
    SetColor(8);
   End;
   OutTextXY(X+20, Y+5, Menus[ActiveMenu].Items[I].Caption);
   If ((Menus[ActiveMenu].Items[I].Command = CMD_GRID) And GridVisible) Or
      ((Menus[ActiveMenu].Items[I].Command = CMD_RULERS) And RulersVisible) Or
      ((Menus[ActiveMenu].Items[I].Command = CMD_GUIDES) And GuidesVisible) Then Begin
    Line(X+6,Y+9,X+8,Y+12); Line(X+8,Y+12,X+14,Y+5);
    Line(X+6,Y+10,X+8,Y+13); Line(X+8,Y+13,X+14,Y+6);
   End;
  End;
 End;
End;

{ ------------------------------------------------------------------
  Boite de dialogue "Proprietes..." de l'objet selectionne
  ------------------------------------------------------------------ }
Var
 PropActive: Boolean;
 PropObj: TGraphicObject;
 PropIdx: Integer;

Function PropHasFill: Boolean;
Begin
 PropHasFill := PropObj.ObjType In [OBJ_RECT,OBJ_ELLIPSE,OBJ_FILLED_PATH];
End;

Function PropStroke: Integer;
Begin
 Case PropObj.ObjType Of
  OBJ_RECT: PropStroke := PropObj.Rectangle.StrokeColor;
  OBJ_ELLIPSE: PropStroke := PropObj.Ellipse.StrokeColor;
  OBJ_LINE: PropStroke := PropObj.Line.StrokeColor;
  OBJ_TEXT: PropStroke := PropObj.TextObj.Color;
 Else PropStroke := PropObj.Path.StrokeColor;
 End;
End;

Procedure PropSetStroke(C: Integer);
Begin
 Case PropObj.ObjType Of
  OBJ_RECT: PropObj.Rectangle.StrokeColor := C;
  OBJ_ELLIPSE: PropObj.Ellipse.StrokeColor := C;
  OBJ_LINE: PropObj.Line.StrokeColor := C;
  OBJ_TEXT: PropObj.TextObj.Color := C;
 Else PropObj.Path.StrokeColor := C;
 End;
End;

Function PropFill: Integer;
Begin
 Case PropObj.ObjType Of
  OBJ_RECT: PropFill := PropObj.Rectangle.FillColor;
  OBJ_ELLIPSE: PropFill := PropObj.Ellipse.FillColor;
 Else PropFill := PropObj.Path.FillColor;
 End;
End;

Procedure PropSetFill(C: Integer);
Begin
 Case PropObj.ObjType Of
  OBJ_RECT: PropObj.Rectangle.FillColor := C;
  OBJ_ELLIPSE: PropObj.Ellipse.FillColor := C;
 Else PropObj.Path.FillColor := C;
 End;
End;

Function PropWidth: Integer;
Begin
 Case PropObj.ObjType Of
  OBJ_RECT: PropWidth := Round(PropObj.Rectangle.StrokeWidth);
  OBJ_ELLIPSE: PropWidth := Round(PropObj.Ellipse.StrokeWidth);
  OBJ_LINE: PropWidth := Round(PropObj.Line.StrokeWidth);
 Else PropWidth := Round(PropObj.Path.StrokeWidth);
 End;
End;

Procedure PropSetWidth(W: Integer);
Begin
 If W < 1 Then W := 1;
 If W > 10 Then W := 10;
 Case PropObj.ObjType Of
  OBJ_RECT: PropObj.Rectangle.StrokeWidth := W;
  OBJ_ELLIPSE: PropObj.Ellipse.StrokeWidth := W;
  OBJ_LINE: PropObj.Line.StrokeWidth := W;
 Else PropObj.Path.StrokeWidth := W;
 End;
End;

Function PropTypeName: String;
Begin
 Case PropObj.ObjType Of
  OBJ_RECT: PropTypeName := 'Rectangle';
  OBJ_ELLIPSE: PropTypeName := 'Ellipse';
  OBJ_LINE: PropTypeName := 'Ligne';
  OBJ_PATH: PropTypeName := 'Chemin';
  OBJ_TEXT: PropTypeName := 'Texte';
  OBJ_BEZIER: PropTypeName := 'Courbe de Bezier';
  OBJ_FILLED_PATH: PropTypeName := 'Chemin rempli';
 Else PropTypeName := 'Objet';
 End;
End;

Procedure OpenProps;
Begin
 If (SelectedObject < 0) Or (SelectedObject >= ObjectCount) Then Begin
  StatusMessage := 'Proprietes : aucun objet selectionne.';
  Exit;
 End;
 PropIdx := SelectedObject;
 PropObj := ObjAt(PropIdx)^;
 PropActive := True;
 NeedsRedraw := True;
End;

Procedure ClosePropsDialog(Apply: Boolean);
Begin
 PropActive := False;
 If Apply And (PropIdx < ObjectCount) Then Begin
  PushUndo;
  ObjAt(PropIdx)^ := PropObj;
  FileModified := True;
  StatusMessage := 'Proprietes appliquees.';
 End Else StatusMessage := 'Proprietes annulees.';
 NeedsRedraw := True;
End;

Function PropX: Integer;
Begin
 PropX := (ScreenWidth-PROP_W) Div 2;
End;

Function PropY: Integer;
Begin
 PropY := (ScreenHeight-PROP_H) Div 2;
End;

Procedure DrawSwatches(X, Y, Selected: Integer);
Var I: Integer;
Begin
 UiSunken(X-3,Y-3,X+16*19+1,Y+19);
 For I := 0 To 15 Do Begin
  SetFillStyle(SolidFill,I);
  Bar(X+I*19,Y,X+I*19+15,Y+15);
  SetColor(8);
  Rectangle(X+I*19,Y,X+I*19+15,Y+15);
  If I = Selected Then Begin
   SetColor(0);
   Rectangle(X+I*19-2,Y-2,X+I*19+17,Y+17);
   SetColor(15);
   Rectangle(X+I*19-1,Y-1,X+I*19+16,Y+16);
  End;
 End;
End;

Procedure DrawButton(X1, Y1, X2, Y2: Integer; Caption: String);
Begin
 UiButton(X1,Y1,X2,Y2,Caption,False,True);
End;

{ positions relatives a la fenetre : hauteur, groupe Contour, case Visible, boutons }
Procedure PropMetrics(Var HRel, CTop, VY, BY: Integer);
Begin
 If PropHasFill Then CTop := 186 Else CTop := 148;
 If PropObj.ObjType = OBJ_TEXT Then VY := CTop Else VY := CTop+54;
 BY := VY+30;
 HRel := BY+24+14;
End;

Procedure DrawPropDialog;
Var X, Y, HR, CT, VY, BY, W: Integer; B: TBounds; S, T: String;
Begin
 If Not PropActive Then Exit;
 PropMetrics(HR,CT,VY,BY);
 W := PROP_W;
 X := PropX; Y := (ScreenHeight-HR) Div 2;
 UiWindow(X,Y,X+W,Y+HR,'Proprietes de l''objet');
 UiGroup(X+12,Y+30,X+W-12,Y+82,'Objet');
 B := ObjectBounds(PropObj);
 S := PropTypeName;
 If PropObj.ObjType = OBJ_TEXT Then S := S+'  "'+Copy(PropObj.TextObj.Text,1,32)+'"';
 UiText(X+24,Y+48,S);
 S := 'X = '; Str(Round(B.L),T); S := S+T;
 S := S+'   Y = '; Str(Round(B.T),T); S := S+T;
 S := S+'   Largeur = '; Str(Round(B.R-B.L),T); S := S+T;
 S := S+'   Hauteur = '; Str(Round(B.B-B.T),T); S := S+T;
 UiText(X+24,Y+64,S);
 If PropHasFill Then UiGroup(X+12,Y+92,X+W-12,Y+176,'Couleurs')
 Else UiGroup(X+12,Y+92,X+W-12,Y+138,'Couleurs');
 If PropObj.ObjType = OBJ_TEXT Then UiText(X+24,Y+114,'Couleur')
 Else UiText(X+24,Y+114,'Trait');
 DrawSwatches(X+124,Y+108,PropStroke);
 If PropHasFill Then Begin
  UiText(X+24,Y+142,'Remplissage');
  DrawSwatches(X+124,Y+136,PropFill);
  If PropObj.ObjType <> OBJ_FILLED_PATH Then Begin
   SetColor(8);
   OutTextXY(X+124,Y+158,'Blanc = pas de remplissage');
  End;
 End;
 If PropObj.ObjType <> OBJ_TEXT Then Begin
  UiGroup(X+12,Y+CT,X+W-12,Y+CT+46,'Contour');
  UiText(X+24,Y+CT+25,'Epaisseur');
  UiSunken(X+108,Y+CT+16,X+150,Y+CT+36);
  Str(PropWidth,S);
  UiText(X+129-Length(S)*4,Y+CT+22,S);
  UiRaised(X+152,Y+CT+16,X+166,Y+CT+25);
  UiArrow(X+159,Y+CT+20,True);
  UiRaised(X+152,Y+CT+26,X+166,Y+CT+36);
  UiArrow(X+159,Y+CT+31,False);
  UiText(X+176,Y+CT+25,'pixels (1 a 10)');
 End;
 UiCheck(X+24,Y+VY,PropObj.Visible,'Objet visible');
 UiButton(X+W-196,Y+BY,X+W-108,Y+BY+24,'OK',True,True);
 UiButton(X+W-100,Y+BY,X+W-12,Y+BY+24,'Annuler',False,True);
End;

Procedure HandlePropMouse;
Var X, Y, I, HR, CT, VY, BY, W: Integer;
Begin
 NeedsRedraw := True;
 PropMetrics(HR,CT,VY,BY);
 W := PROP_W;
 X := PropX; Y := (ScreenHeight-HR) Div 2;
 If UiCloseHit(X+W,Y) Then Begin ClosePropsDialog(False); Exit; End;
 If UiInside(X+W-196,Y+BY,X+W-108,Y+BY+24) Then Begin ClosePropsDialog(True); Exit; End;
 If UiInside(X+W-100,Y+BY,X+W-12,Y+BY+24) Then Begin ClosePropsDialog(False); Exit; End;
 If UiInside(X+124,Y+106,X+124+303,Y+123) Then Begin
  I := (MouseX-X-124) Div 19;
  If I <= 15 Then PropSetStroke(I);
 End Else If PropHasFill And UiInside(X+124,Y+134,X+124+303,Y+151) Then Begin
  I := (MouseX-X-124) Div 19;
  If I <= 15 Then PropSetFill(I);
 End Else If (PropObj.ObjType <> OBJ_TEXT) And UiInside(X+152,Y+CT+16,X+166,Y+CT+25) Then
  PropSetWidth(PropWidth+1)
 Else If (PropObj.ObjType <> OBJ_TEXT) And UiInside(X+152,Y+CT+26,X+166,Y+CT+36) Then
  PropSetWidth(PropWidth-1)
 Else If UiInside(X+24,Y+VY-2,X+170,Y+VY+14) Then
  PropObj.Visible := Not PropObj.Visible;
End;

Procedure HandlePropKey(Key: Char);
Begin
 NeedsRedraw := True;
 Case Key Of
  #13: ClosePropsDialog(True);
  #27: ClosePropsDialog(False);
  '+': If PropObj.ObjType <> OBJ_TEXT Then PropSetWidth(PropWidth+1);
  '-': If PropObj.ObjType <> OBJ_TEXT Then PropSetWidth(PropWidth-1);
  'v','V': PropObj.Visible := Not PropObj.Visible;
 End;
End;

Procedure MoveSelectionToEnd(Front: Boolean);
Var N: TObjList; I, Pass, NewSel: Integer; Fail: Boolean;
Begin
 FillChar(N,SizeOf(N),0);
 NewSel := -1; Fail := False;
 For Pass := 0 To 1 Do
  For I := 0 To ObjectCount-1 Do
   If IsSel(I) = (Front = (Pass = 1)) Then Begin
    If I = SelectedObject Then NewSel := N.Count;
    If Not ListAdd(N,ObjAt(I)^) Then Fail := True;
   End;
 If Fail Then Begin
  ListClear(N);
  StatusMessage := 'Memoire insuffisante.';
  Exit;
 End;
 PushUndo;
 ListClear(ObjList);
 ObjList := N;
 ObjectCount := ObjList.Count;
 SelectedObject := NewSel;
 FileModified := True;
 If Front Then StatusMessage := 'Selection placee au premier plan.'
 Else StatusMessage := 'Selection placee a l''arriere-plan.';
 NeedsRedraw := True;
End;

Procedure SwapObjects(I, J: Integer);
Var T: TGraphicObject;
Begin
 T := ObjAt(I)^;
 ObjAt(I)^ := ObjAt(J)^;
 ObjAt(J)^ := T;
End;

{ Arrangement : Cmd = CMD_FRONT, CMD_BACK, CMD_FORWARD ou CMD_BACKWARD }
Procedure ArrangeObject(Cmd: Integer);
Var I, Target: Integer;
Begin
 If (SelectedObject < 0) Or (SelectedObject >= ObjectCount) Then Begin
  StatusMessage := 'Arrangement : aucun objet selectionne.';
  Exit;
 End;
 If (Cmd In [CMD_FRONT,CMD_BACK]) And (OtherSelCount > 0) Then Begin
  MoveSelectionToEnd(Cmd = CMD_FRONT);
  Exit;
 End;
 Case Cmd Of
  CMD_FRONT: Target := ObjectCount-1;
  CMD_BACK: Target := 0;
  CMD_FORWARD: Target := SelectedObject+1;
 Else Target := SelectedObject-1;
 End;
 If (Target < 0) Or (Target >= ObjectCount) Or (Target = SelectedObject) Then Begin
  If Cmd In [CMD_FRONT,CMD_FORWARD] Then StatusMessage := 'L''objet est deja au premier plan.'
  Else StatusMessage := 'L''objet est deja a l''arriere-plan.';
  Exit;
 End;
 PushUndo;
 I := SelectedObject;
 While I < Target Do Begin SwapObjects(I,I+1); Inc(I); End;
 While I > Target Do Begin SwapObjects(I,I-1); Dec(I); End;
 SelectedObject := Target;
 FileModified := True;
 StatusMessage := 'Objet deplace dans l''ordre d''empilement.';
 NeedsRedraw := True;
End;

{ ------------------------------------------------------------------
  Objet : Grouper, Degrouper, Aligner, Distribuer, Transformer, Operations
  ------------------------------------------------------------------ }
Const
 CH_ALIGN = 0;
 CH_DISTRIB = 1;
 CH_TRANSFORM = 2;
 CH_OPS = 3;
 TR_ROT = 0;
 TR_FLIPH = 1;
 TR_FLIPV = 2;
 TR_SCALE = 3;

Var
 ChoiceActive: Boolean;
 ChoiceKind, ChoiceCount: Integer;
 ChoiceItems: Array[0..11] Of String[40];
 ChoiceSel, ChoiceLastIdx: Integer;
 ChoiceLastClock: LongInt;

Function CollectSel(Var N: LongInt): PLongArr;
Var P: PLongArr; I: Integer;
Begin
 N := 0;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And ObjAt(I)^.Visible Then Inc(N);
 CollectSel := Nil;
 If N = 0 Then Exit;
 GetMem(P,N*4);
 N := 0;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And ObjAt(I)^.Visible Then Begin
   P^[N] := I; Inc(N);
  End;
 CollectSel := P;
End;

Procedure GroupCommand;
Var I, N, MaxG: Integer; G: LongInt; S: String;
Begin
 N := SelCount;
 If N < 2 Then Begin
  StatusMessage := 'Grouper : selectionner au moins deux objets (rectangle de selection).';
  Exit;
 End;
 MaxG := 0;
 For I := 0 To ObjectCount-1 Do
  If GroupOfObj(ObjAt(I)^) > MaxG Then MaxG := GroupOfObj(ObjAt(I)^);
 G := MaxG+1;
 PushUndo;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) Then SetGroupOfObj(ObjAt(I)^,G);
 FileModified := True;
 Str(N,S);
 StatusMessage := S+' objets groupes.';
 NeedsRedraw := True;
End;

Procedure UngroupCommand;
Var I, N: Integer; S: String;
Begin
 N := 0;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And (GroupOfObj(ObjAt(I)^) > 0) Then Inc(N);
 If N = 0 Then Begin
  StatusMessage := 'Degrouper : la selection ne contient aucun groupe.';
  Exit;
 End;
 PushUndo;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) Then SetGroupOfObj(ObjAt(I)^,0);
 FileModified := True;
 Str(N,S);
 StatusMessage := 'Groupe(s) defait(s) : '+S+' objets.';
 NeedsRedraw := True;
End;

Procedure AlignSelection(K: Integer);
Var P: PLongArr; N, J: LongInt; U, B: TBounds; DX, DY: Real;
Begin
 U := SelectionBounds;
 P := CollectSel(N);
 If P = Nil Then Exit;
 PushUndo;
 For J := 0 To N-1 Do Begin
  B := ObjectBounds(ObjAt(P^[J])^);
  DX := 0; DY := 0;
  Case K Of
   0: DX := U.L-B.L;
   1: DX := (U.L+U.R)/2-(B.L+B.R)/2;
   2: DX := U.R-B.R;
   3: DY := U.T-B.T;
   4: DY := (U.T+U.B)/2-(B.T+B.B)/2;
   5: DY := U.B-B.B;
  End;
  OffsetObject(ObjAt(P^[J])^,DX,DY);
 End;
 FreeMem(P,N*4);
 FileModified := True;
 StatusMessage := 'Objets alignes.';
 NeedsRedraw := True;
End;

Procedure DistributeSelection(K: Integer);
Var P: PLongArr; Key: PRealArr; N, J, M, H: LongInt; U, B: TBounds;
    DX, DY, T, C0, CN, SumW, Gap, Pos: Real; TI: LongInt;
Begin
 P := CollectSel(N);
 If P = Nil Then Exit;
 GetMem(Key,N*SizeOf(Real));
 For J := 0 To N-1 Do Begin
  B := ObjectBounds(ObjAt(P^[J])^);
  Case K Of
   0: Key^[J] := (B.L+B.R)/2;
   1: Key^[J] := (B.T+B.B)/2;
   2: Key^[J] := B.L;
  Else Key^[J] := B.T;
  End;
 End;
 { tri par insertion (cles croissantes) }
 For J := 1 To N-1 Do Begin
  T := Key^[J]; TI := P^[J]; M := J-1;
  While (M >= 0) And (Key^[M] > T) Do Begin
   Key^[M+1] := Key^[M]; P^[M+1] := P^[M]; Dec(M);
  End;
  Key^[M+1] := T; P^[M+1] := TI;
 End;
 PushUndo;
 If K < 2 Then Begin
  C0 := Key^[0]; CN := Key^[N-1];
  For J := 1 To N-2 Do Begin
   T := C0+J*(CN-C0)/(N-1);
   If K = 0 Then OffsetObject(ObjAt(P^[J])^,T-Key^[J],0)
   Else OffsetObject(ObjAt(P^[J])^,0,T-Key^[J]);
  End;
 End Else Begin
  U := SelectionBounds;
  SumW := 0;
  For J := 0 To N-1 Do Begin
   B := ObjectBounds(ObjAt(P^[J])^);
   If K = 2 Then SumW := SumW+(B.R-B.L) Else SumW := SumW+(B.B-B.T);
  End;
  If K = 2 Then Begin Gap := ((U.R-U.L)-SumW)/(N-1); Pos := U.L; End
  Else Begin Gap := ((U.B-U.T)-SumW)/(N-1); Pos := U.T; End;
  For J := 0 To N-1 Do Begin
   B := ObjectBounds(ObjAt(P^[J])^);
   If K = 2 Then Begin
    OffsetObject(ObjAt(P^[J])^,Pos-B.L,0);
    Pos := Pos+(B.R-B.L)+Gap;
   End Else Begin
    OffsetObject(ObjAt(P^[J])^,0,Pos-B.T);
    Pos := Pos+(B.B-B.T)+Gap;
   End;
  End;
 End;
 FreeMem(Key,N*SizeOf(Real));
 FreeMem(P,N*4);
 FileModified := True;
 StatusMessage := 'Objets distribues.';
 NeedsRedraw := True;
End;

{ ---- transformations ---- }
Procedure MapPoint(Kind: Integer; CX, CY, Par: Real; X, Y: Real; Var NX, NY: Real);
Var Co, Si: Real;
Begin
 Case Kind Of
  TR_ROT: Begin
   Co := Cos(Par); Si := Sin(Par);
   NX := CX+(X-CX)*Co-(Y-CY)*Si;
   NY := CY+(X-CX)*Si+(Y-CY)*Co;
  End;
  TR_FLIPH: Begin NX := 2*CX-X; NY := Y; End;
  TR_FLIPV: Begin NX := X; NY := 2*CY-Y; End;
 Else Begin NX := CX+(X-CX)*Par; NY := CY+(Y-CY)*Par; End;
 End;
 NX := Round(NX*1000)/1000;
 NY := Round(NY*1000)/1000;
End;

{ rectangle ou ellipse -> chemin (pour les rotations quelconques) }
Procedure ConvertToPath(Var O: TGraphicObject);
Var N: TGraphicObject; G: LongInt; I: Integer; A: Real; Fill, Stroke: Byte; W: Real;
    X0, Y0, X1, Y1, CX, CY, RX, RY: Real;
Begin
 If Not (O.ObjType In [OBJ_RECT,OBJ_ELLIPSE]) Then Exit;
 G := GroupOfObj(O);
 FillChar(N,SizeOf(N),0);
 N.Visible := O.Visible; N.LayerIndex := O.LayerIndex;
 If O.ObjType = OBJ_RECT Then Begin
  Fill := O.Rectangle.FillColor; Stroke := O.Rectangle.StrokeColor;
  W := O.Rectangle.StrokeWidth;
  X0 := O.Rectangle.X; Y0 := O.Rectangle.Y;
  X1 := X0+O.Rectangle.Width; Y1 := Y0+O.Rectangle.Height;
  N.Path.PointCount := 4;
  N.Path.Points[0].X := X0; N.Path.Points[0].Y := Y0;
  N.Path.Points[1].X := X1; N.Path.Points[1].Y := Y0;
  N.Path.Points[2].X := X1; N.Path.Points[2].Y := Y1;
  N.Path.Points[3].X := X0; N.Path.Points[3].Y := Y1;
 End Else Begin
  Fill := O.Ellipse.FillColor; Stroke := O.Ellipse.StrokeColor;
  W := O.Ellipse.StrokeWidth;
  CX := O.Ellipse.CX; CY := O.Ellipse.CY;
  RX := O.Ellipse.RX; RY := O.Ellipse.RY;
  N.Path.PointCount := 36;
  For I := 0 To 35 Do Begin
   A := I*Pi/18;
   N.Path.Points[I].X := Round((CX+RX*Cos(A))*1000)/1000;
   N.Path.Points[I].Y := Round((CY+RY*Sin(A))*1000)/1000;
  End;
 End;
 If Fill <> 15 Then N.ObjType := OBJ_FILLED_PATH Else N.ObjType := OBJ_PATH;
 N.Path.Closed := True;
 N.Path.StrokeColor := Stroke;
 N.Path.FillColor := Fill;
 N.Path.StrokeWidth := W;
 SetGroupOfObj(N,G);
 SelFlagPtr(N)^ := SelFlagPtr(O)^;
 O := N;
End;

Procedure TransformObj(Var O: TGraphicObject; Kind: Integer; CX, CY, Par: Real);
Var I: Integer; X0, Y0, X1, Y1, T: Real; Quarter, Tmp: Real; B: TBounds;
    Q: LongInt;
Begin
 Quarter := 0;
 If Kind = TR_ROT Then Begin
  Q := Round(Par/(Pi/2));
  If Abs(Par-Q*(Pi/2)) < 0.0001 Then Quarter := 1;
 End;
 If (O.ObjType In [OBJ_RECT,OBJ_ELLIPSE]) And (Kind = TR_ROT) And (Quarter = 0) Then
  ConvertToPath(O);
 Case O.ObjType Of
  OBJ_RECT: Begin
   MapPoint(Kind,CX,CY,Par,O.Rectangle.X,O.Rectangle.Y,X0,Y0);
   MapPoint(Kind,CX,CY,Par,O.Rectangle.X+O.Rectangle.Width,
            O.Rectangle.Y+O.Rectangle.Height,X1,Y1);
   O.Rectangle.X := MinReal(X0,X1); O.Rectangle.Y := MinReal(Y0,Y1);
   O.Rectangle.Width := Abs(X1-X0); O.Rectangle.Height := Abs(Y1-Y0);
  End;
  OBJ_ELLIPSE: Begin
   MapPoint(Kind,CX,CY,Par,O.Ellipse.CX,O.Ellipse.CY,X0,Y0);
   O.Ellipse.CX := X0; O.Ellipse.CY := Y0;
   If Kind = TR_ROT Then Begin
    If Odd(Round(Par/(Pi/2))) Then Begin
     T := O.Ellipse.RX; O.Ellipse.RX := O.Ellipse.RY; O.Ellipse.RY := T;
    End;
   End Else If Kind = TR_SCALE Then Begin
    O.Ellipse.RX := O.Ellipse.RX*Par; O.Ellipse.RY := O.Ellipse.RY*Par;
   End;
  End;
  OBJ_LINE: Begin
   MapPoint(Kind,CX,CY,Par,O.Line.X1,O.Line.Y1,X0,Y0);
   MapPoint(Kind,CX,CY,Par,O.Line.X2,O.Line.Y2,X1,Y1);
   O.Line.X1 := X0; O.Line.Y1 := Y0; O.Line.X2 := X1; O.Line.Y2 := Y1;
  End;
  OBJ_TEXT: Begin
   B := ObjectBounds(O);
   MapPoint(Kind,CX,CY,Par,(B.L+B.R)/2,(B.T+B.B)/2,X0,Y0);
   O.TextObj.X := Round(X0-(B.R-B.L)/2);
   O.TextObj.Y := Round(Y0-(B.B-B.T)/2);
  End;
  OBJ_PATH, OBJ_BEZIER, OBJ_FILLED_PATH:
   For I := 0 To O.Path.PointCount-1 Do Begin
    MapPoint(Kind,CX,CY,Par,O.Path.Points[I].X,O.Path.Points[I].Y,X0,Y0);
    O.Path.Points[I].X := X0; O.Path.Points[I].Y := Y0;
    MapPoint(Kind,CX,CY,Par,O.Path.Points[I].CtrlX1,O.Path.Points[I].CtrlY1,X0,Y0);
    O.Path.Points[I].CtrlX1 := X0; O.Path.Points[I].CtrlY1 := Y0;
    MapPoint(Kind,CX,CY,Par,O.Path.Points[I].CtrlX2,O.Path.Points[I].CtrlY2,X0,Y0);
    O.Path.Points[I].CtrlX2 := X0; O.Path.Points[I].CtrlY2 := Y0;
   End;
 End;
End;

Procedure TransformSelection(Kind: Integer; Par: Real);
Var P: PLongArr; N, J: LongInt; U, B: TBounds; CX, CY: Real; O: TGraphicObject;
    Ok: Boolean;
Begin
 U := SelectionBounds;
 CX := (U.L+U.R)/2; CY := (U.T+U.B)/2;
 P := CollectSel(N);
 If P = Nil Then Exit;
 Ok := True;
 For J := 0 To N-1 Do Begin
  O := ObjAt(P^[J])^;
  TransformObj(O,Kind,CX,CY,Par);
  B := ObjectBounds(O);
  If (B.L < 0) Or (B.T < 0) Or (B.R >= ScreenWidth-TOOLBAR_WIDTH) Or
     (B.B >= ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT) Then Ok := False;
 End;
 If Not Ok Then Begin
  FreeMem(P,N*4);
  StatusMessage := 'Transformation refusee : le resultat sortirait de la page.';
  Exit;
 End;
 PushUndo;
 For J := 0 To N-1 Do Begin
  O := ObjAt(P^[J])^;
  TransformObj(O,Kind,CX,CY,Par);
  ObjAt(P^[J])^ := O;
 End;
 FreeMem(P,N*4);
 FileModified := True;
 StatusMessage := 'Transformation appliquee.';
 NeedsRedraw := True;
End;

{ ---- operations sur la selection ---- }
Procedure SelectAllCommand;
Var I: Integer; S: String;
Begin
 ClearSelFlags;
 SelectedObject := -1;
 For I := 0 To ObjectCount-1 Do
  If ObjAt(I)^.Visible Then Begin
   SelFlagPtr(ObjAt(I)^)^ := True;
   SelectedObject := I;
  End;
 Str(SelCount,S);
 StatusMessage := S+' objet(s) selectionne(s).';
 NeedsRedraw := True;
End;

Procedure DeleteSelection;
Var I: Integer; N: Integer; S: String;
Begin
 N := SelCount;
 If N = 0 Then Begin
  StatusMessage := 'Supprimer : aucun objet selectionne.';
  Exit;
 End;
 PushUndo;
 For I := ObjectCount-1 DownTo 0 Do
  If IsSel(I) Then DeleteObjectAt(I);
 SelectedObject := -1;
 FileModified := True;
 Str(N,S);
 StatusMessage := S+' objet(s) supprime(s).';
 NeedsRedraw := True;
End;

Procedure DuplicateSelection;
Var I, N0, N: Integer; O: TGraphicObject; B: TBounds; U: TBounds; Off, MaxG: LongInt;
    G: LongInt; S: String;
Begin
 If SelCount = 0 Then Begin
  StatusMessage := 'Dupliquer : aucun objet selectionne.';
  Exit;
 End;
 U := SelectionBounds;
 Off := 12;
 If (U.R+12 >= ScreenWidth-TOOLBAR_WIDTH) Or
    (U.B+12 >= ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT) Then Off := -12;
 If (U.L+Off < 0) Or (U.T+Off < 0) Then Begin
  StatusMessage := 'Dupliquer : pas de place dans la page.';
  Exit;
 End;
 PushUndo;
 MaxG := 0;
 For I := 0 To ObjectCount-1 Do
  If GroupOfObj(ObjAt(I)^) > MaxG Then MaxG := GroupOfObj(ObjAt(I)^);
 N0 := ObjectCount; N := 0;
 For I := 0 To N0-1 Do
  If IsSel(I) Then Begin
   O := ObjAt(I)^;
   OffsetObject(O,Off,Off);
   G := GroupOfObj(O);
   If G > 0 Then SetGroupOfObj(O,G+MaxG);
   SelFlagPtr(O)^ := True;
   AppendObject(O);
   Inc(N);
  End;
 For I := 0 To N0-1 Do SelFlagPtr(ObjAt(I)^)^ := False;
 SelectedObject := ObjectCount-1;
 FileModified := True;
 Str(N,S);
 StatusMessage := S+' objet(s) duplique(s).';
 NeedsRedraw := True;
End;

Procedure InvertSelection;
Var I: Integer; Was: Boolean;
Begin
 For I := 0 To ObjectCount-1 Do Begin
  Was := IsSel(I);
  SelFlagPtr(ObjAt(I)^)^ := (Not Was) And ObjAt(I)^.Visible;
 End;
 SelectedObject := -1;
 For I := ObjectCount-1 DownTo 0 Do
  If IsFlagged(I) Then Begin SelectedObject := I; Break; End;
 StatusMessage := 'Selection inversee.';
 NeedsRedraw := True;
End;

Procedure DeselectAll;
Begin
 ClearSelFlags;
 SelectedObject := -1;
 StatusMessage := 'Selection annulee.';
 NeedsRedraw := True;
End;

{ ------------------------------------------------------------------
  Menu Chemin : Rejoindre, Scinder, Cont. Coin, Cont. Courbe,
  Simplifier, Decalage
  ------------------------------------------------------------------ }
Const
 CH_SIMPLIFY = 4;
 CH_OFFSET = 5;

Type
 TPoly = Record
  N: Integer;
  Closed: Boolean;
  P: Array[0..99] Of TPoint2D;
 End;
 TKeep = Array[0..99] Of Boolean;

Function PageW: Integer;
Begin
 PageW := ScreenWidth-TOOLBAR_WIDTH;
End;

Function PageH: Integer;
Begin
 PageH := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT;
End;

Function Dist2(X1, Y1, X2, Y2: Real): Real;
Begin
 Dist2 := Sqrt(Sqr(X2-X1)+Sqr(Y2-Y1));
End;

Function ObjFill(Var O: TGraphicObject): Integer;
Begin
 Case O.ObjType Of
  OBJ_RECT: ObjFill := O.Rectangle.FillColor;
  OBJ_ELLIPSE: ObjFill := O.Ellipse.FillColor;
  OBJ_FILLED_PATH: ObjFill := O.Path.FillColor;
 Else ObjFill := 15;
 End;
End;

Function ObjStroke(Var O: TGraphicObject): Integer;
Begin
 Case O.ObjType Of
  OBJ_RECT: ObjStroke := O.Rectangle.StrokeColor;
  OBJ_ELLIPSE: ObjStroke := O.Ellipse.StrokeColor;
  OBJ_LINE: ObjStroke := O.Line.StrokeColor;
  OBJ_TEXT: ObjStroke := O.TextObj.Color;
 Else ObjStroke := O.Path.StrokeColor;
 End;
End;

Function ObjWidthOf(Var O: TGraphicObject): Real;
Begin
 Case O.ObjType Of
  OBJ_RECT: ObjWidthOf := O.Rectangle.StrokeWidth;
  OBJ_ELLIPSE: ObjWidthOf := O.Ellipse.StrokeWidth;
  OBJ_LINE: ObjWidthOf := O.Line.StrokeWidth;
 Else ObjWidthOf := O.Path.StrokeWidth;
 End;
End;

{ objet -> suite de points (lignes, chemins, courbes aplaties, rectangles, ellipses) }
Function ObjToPoly(Var O: TGraphicObject; Var Q: TPoly): Boolean;
Var T: TGraphicObject; I: Integer; B: TPoint2D;
Begin
 ObjToPoly := False;
 FillChar(Q,SizeOf(Q),0);
 Case O.ObjType Of
  OBJ_LINE: Begin
   Q.N := 2;
   Q.P[0].X := O.Line.X1; Q.P[0].Y := O.Line.Y1;
   Q.P[1].X := O.Line.X2; Q.P[1].Y := O.Line.Y2;
   ObjToPoly := True;
  End;
  OBJ_PATH, OBJ_FILLED_PATH: Begin
   Q.N := O.Path.PointCount;
   Q.Closed := O.Path.Closed;
   For I := 0 To Q.N-1 Do Begin
    Q.P[I].X := O.Path.Points[I].X; Q.P[I].Y := O.Path.Points[I].Y;
   End;
   ObjToPoly := Q.N >= 2;
  End;
  OBJ_BEZIER: Begin
   Q.N := 17;
   For I := 0 To 16 Do Begin
    B := BezierPoint(O,I/16);
    Q.P[I].X := Round(B.X*1000)/1000; Q.P[I].Y := Round(B.Y*1000)/1000;
   End;
   ObjToPoly := True;
  End;
  OBJ_RECT, OBJ_ELLIPSE: Begin
   T := O;
   ConvertToPath(T);
   ObjToPoly := ObjToPoly(T,Q);
  End;
 End;
End;

{ suite de points -> objet, avec les attributs de Proto }
Procedure PolyToObj(Var Q: TPoly; Var Proto, Dst: TGraphicObject);
Var I: Integer; Fill: Integer; G: LongInt; Fl: Boolean;
Begin
 G := GroupOfObj(Proto);
 Fl := SelFlagPtr(Proto)^;
 FillChar(Dst,SizeOf(Dst),0);
 Dst.Visible := Proto.Visible;
 Dst.LayerIndex := Proto.LayerIndex;
 If (Q.N = 2) And Not Q.Closed And (Proto.ObjType = OBJ_LINE) Then Begin
  Dst.ObjType := OBJ_LINE;
  Dst.Line.X1 := Q.P[0].X; Dst.Line.Y1 := Q.P[0].Y;
  Dst.Line.X2 := Q.P[1].X; Dst.Line.Y2 := Q.P[1].Y;
  Dst.Line.StrokeColor := Proto.Line.StrokeColor;
  Dst.Line.StrokeWidth := Proto.Line.StrokeWidth;
 End Else Begin
  Fill := ObjFill(Proto);
  If Fill <> 15 Then Dst.ObjType := OBJ_FILLED_PATH Else Dst.ObjType := OBJ_PATH;
  Dst.Path.PointCount := Q.N;
  Dst.Path.Closed := Q.Closed;
  For I := 0 To Q.N-1 Do Begin
   Dst.Path.Points[I].X := Q.P[I].X; Dst.Path.Points[I].Y := Q.P[I].Y;
  End;
  Dst.Path.StrokeColor := ObjStroke(Proto);
  Dst.Path.FillColor := Fill;
  Dst.Path.StrokeWidth := ObjWidthOf(Proto);
 End;
 SetGroupOfObj(Dst,G);
 SelFlagPtr(Dst)^ := Fl;
End;

Procedure ClampPoly(Var Q: TPoly);
Var I: Integer;
Begin
 For I := 0 To Q.N-1 Do Begin
  Q.P[I].X := Round(MaxReal(0,MinReal(PageW-1,Q.P[I].X))*1000)/1000;
  Q.P[I].Y := Round(MaxReal(0,MinReal(PageH-1,Q.P[I].Y))*1000)/1000;
 End;
End;

Function PolyInPage(Var Q: TPoly): Boolean;
Var I: Integer; R: Boolean;
Begin
 R := True;
 For I := 0 To Q.N-1 Do
  If (Q.P[I].X < 0) Or (Q.P[I].Y < 0) Or (Q.P[I].X >= PageW) Or
     (Q.P[I].Y >= PageH) Then R := False;
 PolyInPage := R;
End;

Procedure RevPoly(Var Q: TPoly);
Var I: Integer; T: TPoint2D;
Begin
 For I := 0 To (Q.N Div 2)-1 Do Begin
  T := Q.P[I]; Q.P[I] := Q.P[Q.N-1-I]; Q.P[Q.N-1-I] := T;
 End;
End;

{ memoire des operations : l'etat d'avant est empile en annulation seulement
  si l'operation a vraiment modifie le dessin }
Function BeginOp(Var S0: TSnapshot): Boolean;
Begin
 BeginOp := TakeSnapshot(S0);
 If S0.Data = Nil Then S0.Count := S0.Count;
End;

Procedure EndOp(Var S0: TSnapshot; Changed: Boolean);
Var S1: TSnapshot;
Begin
 If Changed Then Begin
  If TakeSnapshot(S1) Then Begin
   RestoreSnapshot(S0);
   PushUndo;
   RestoreSnapshot(S1);
   FreeSnapshot(S1);
  End;
  FileModified := True;
 End;
 FreeSnapshot(S0);
 NeedsRedraw := True;
End;

{ ---- Rejoindre ---- }
Function MergePoly(Var C, D: TPoly; Mode: Integer): Boolean;
Var A, B, R: TPoly; I, Skip: Integer;
Begin
 MergePoly := False;
 Case Mode Of
  0: Begin A := C; B := D; End;
  1: Begin A := C; B := D; RevPoly(B); End;
  2: Begin A := D; B := C; End;
 Else Begin A := D; RevPoly(A); B := C; End;
 End;
 Skip := 0;
 If Dist2(A.P[A.N-1].X,A.P[A.N-1].Y,B.P[0].X,B.P[0].Y) < 0.5 Then Skip := 1;
 If A.N+B.N-Skip > 100 Then Exit;
 R := A;
 R.Closed := False;
 For I := Skip To B.N-1 Do Begin
  R.P[R.N] := B.P[I]; Inc(R.N);
 End;
 C := R;
 MergePoly := True;
End;

Procedure JoinCommand;
Var Idx, Used: PLongArr; N, J, Target, Best, Mode, Cnt, Moved: LongInt;
    S0: TSnapshot; C, D: TPoly; Proto, NewO: TGraphicObject; BD, D1, D2, D3, D4, M: Real;
    Fail, Found: Boolean;
Begin
 Idx := CollectSel(N);
 If Idx = Nil Then Begin
  StatusMessage := 'Rejoindre : aucun chemin selectionne.';
  Exit;
 End;
 GetMem(Used,N*4);
 Target := -1;
 For J := 0 To N-1 Do Begin
  Used^[J] := 2;
  If ObjAt(Idx^[J])^.ObjType <> OBJ_TEXT Then
   If ObjToPoly(ObjAt(Idx^[J])^,D) Then
    If Not D.Closed Then Begin
     Used^[J] := 0;
     If Target < 0 Then Target := J;
    End;
 End;
 If Target < 0 Then Begin
  FreeMem(Used,N*4); FreeMem(Idx,N*4);
  StatusMessage := 'Rejoindre : aucun chemin ouvert dans la selection.';
  Exit;
 End;
 Proto := ObjAt(Idx^[Target])^;
 ObjToPoly(Proto,C);
 Used^[Target] := 1; Cnt := 1; Fail := False;
 Repeat
  Found := False; BD := 1E30; Best := -1; Mode := 0;
  For J := 0 To N-1 Do
   If Used^[J] = 0 Then Begin
    ObjToPoly(ObjAt(Idx^[J])^,D);
    D1 := Dist2(C.P[C.N-1].X,C.P[C.N-1].Y,D.P[0].X,D.P[0].Y);
    D2 := Dist2(C.P[C.N-1].X,C.P[C.N-1].Y,D.P[D.N-1].X,D.P[D.N-1].Y);
    D3 := Dist2(C.P[0].X,C.P[0].Y,D.P[D.N-1].X,D.P[D.N-1].Y);
    D4 := Dist2(C.P[0].X,C.P[0].Y,D.P[0].X,D.P[0].Y);
    M := D1; If D2 < M Then M := D2; If D3 < M Then M := D3; If D4 < M Then M := D4;
    If M < BD Then Begin
     BD := M; Best := J; Found := True;
     If M = D1 Then Mode := 0 Else If M = D2 Then Mode := 1
     Else If M = D3 Then Mode := 2 Else Mode := 3;
    End;
   End;
  If Found Then Begin
   ObjToPoly(ObjAt(Idx^[Best])^,D);
   If MergePoly(C,D,Mode) Then Begin Used^[Best] := 1; Inc(Cnt); End
   Else Fail := True;
  End;
 Until Not Found Or Fail;
 If Fail Then Begin
  FreeMem(Used,N*4); FreeMem(Idx,N*4);
  StatusMessage := 'Rejoindre : plus de 100 points au total.';
  Exit;
 End;
 If Cnt = 1 Then Begin
  If C.N < 3 Then Begin
   FreeMem(Used,N*4); FreeMem(Idx,N*4);
   StatusMessage := 'Rejoindre : un chemin a refermer doit avoir trois points.';
   Exit;
  End;
  If Dist2(C.P[0].X,C.P[0].Y,C.P[C.N-1].X,C.P[C.N-1].Y) < 0.5 Then Dec(C.N);
  C.Closed := True;
 End;
 If Not BeginOp(S0) Then Begin
  FreeMem(Used,N*4); FreeMem(Idx,N*4);
  StatusMessage := 'Memoire insuffisante.';
  Exit;
 End;
 PolyToObj(C,Proto,NewO);
 NewO.Visible := True;
 ObjAt(Idx^[Target])^ := NewO;
 Moved := 0;
 For J := N-1 DownTo 0 Do
  If (Used^[J] = 1) And (J <> Target) Then Begin
   DeleteObjectAt(Idx^[J]);
   If J < Target Then Inc(Moved);
  End;
 ClearSelFlags;
 SelectedObject := Idx^[Target]-Moved;
 SelFlagPtr(ObjAt(SelectedObject)^)^ := True;
 If Cnt = 1 Then StatusMessage := 'Chemin referme.'
 Else StatusMessage := 'Chemins rejoints.';
 FreeMem(Used,N*4); FreeMem(Idx,N*4);
 EndOp(S0,True);
End;

{ ---- Scinder ---- }
Function NearestOnPoly(Var Q: TPoly; PX, PY: Real; Var Seg: Integer; Var U, QX, QY: Real): Boolean;
Var I, J, Cnt: Integer; DX, DY, D, T, X, Y, BestD: Real;
Begin
 NearestOnPoly := False;
 BestD := 1E30;
 Cnt := Q.N-1;
 If Q.Closed Then Cnt := Q.N;
 For I := 0 To Cnt-1 Do Begin
  J := (I+1) Mod Q.N;
  DX := Q.P[J].X-Q.P[I].X; DY := Q.P[J].Y-Q.P[I].Y;
  D := Sqr(DX)+Sqr(DY);
  T := 0;
  If D > 0 Then T := ((PX-Q.P[I].X)*DX+(PY-Q.P[I].Y)*DY)/D;
  T := MaxReal(0,MinReal(1,T));
  X := Q.P[I].X+T*DX; Y := Q.P[I].Y+T*DY;
  If Sqr(PX-X)+Sqr(PY-Y) < BestD Then Begin
   BestD := Sqr(PX-X)+Sqr(PY-Y);
   Seg := I; U := T; QX := X; QY := Y;
   NearestOnPoly := True;
  End;
 End;
End;

Procedure AddPt(Var Q: TPoly; X, Y: Real);
Begin
 If Q.N > 0 Then
  If Dist2(Q.P[Q.N-1].X,Q.P[Q.N-1].Y,X,Y) < 0.5 Then Exit;
 If Q.N >= 100 Then Exit;
 FillChar(Q.P[Q.N],SizeOf(TPoint2D),0);
 Q.P[Q.N].X := Round(X*1000)/1000; Q.P[Q.N].Y := Round(Y*1000)/1000;
 Inc(Q.N);
End;

Procedure SplitCommand;
Var O, A, B, Proto: TGraphicObject; Q, QA, QB: TPoly; Seg, I, K: Integer;
    U, QX, QY, PX, PY, BT, T, BD, D: Real; S0: TSnapshot; Bz: TBounds;
    P0, P1, P2, P3, Pa, Pb, Pc, Pd, Pe, Pf: TPoint2D;
Begin
 If (SelectedObject < 0) Or (SelectedObject >= ObjectCount) Then Begin
  StatusMessage := 'Scinder : selectionner un chemin (cliquer pres du point de coupe).';
  Exit;
 End;
 Proto := ObjAt(SelectedObject)^;
 If Proto.ObjType = OBJ_TEXT Then Begin
  StatusMessage := 'Scinder : ne s''applique pas au texte.';
  Exit;
 End;
 If LastPickOk Then Begin PX := LastPickX; PY := LastPickY; End
 Else Begin
  Bz := ObjectBounds(Proto);
  PX := (Bz.L+Bz.R)/2; PY := (Bz.T+Bz.B)/2;
 End;
 If Proto.ObjType = OBJ_BEZIER Then Begin
  BT := 0.5; BD := 1E30;
  For K := 1 To 63 Do Begin
   T := K/64;
   Pa := BezierPoint(Proto,T);
   D := Sqr(Pa.X-PX)+Sqr(Pa.Y-PY);
   If D < BD Then Begin BD := D; BT := T; End;
  End;
  P0 := Proto.Path.Points[0]; P1 := Proto.Path.Points[1];
  P2 := Proto.Path.Points[2]; P3 := Proto.Path.Points[3];
  Pa.X := P0.X+(P1.X-P0.X)*BT; Pa.Y := P0.Y+(P1.Y-P0.Y)*BT;
  Pb.X := P1.X+(P2.X-P1.X)*BT; Pb.Y := P1.Y+(P2.Y-P1.Y)*BT;
  Pc.X := P2.X+(P3.X-P2.X)*BT; Pc.Y := P2.Y+(P3.Y-P2.Y)*BT;
  Pd.X := Pa.X+(Pb.X-Pa.X)*BT; Pd.Y := Pa.Y+(Pb.Y-Pa.Y)*BT;
  Pe.X := Pb.X+(Pc.X-Pb.X)*BT; Pe.Y := Pb.Y+(Pc.Y-Pb.Y)*BT;
  Pf.X := Pd.X+(Pe.X-Pd.X)*BT; Pf.Y := Pd.Y+(Pe.Y-Pd.Y)*BT;
  A := Proto; B := Proto;
  A.Path.Points[1] := Pa; A.Path.Points[2] := Pd; A.Path.Points[3] := Pf;
  B.Path.Points[0] := Pf; B.Path.Points[1] := Pe; B.Path.Points[2] := Pc;
  If Not BeginOp(S0) Then Exit;
  ObjAt(SelectedObject)^ := A;
  AppendObject(B);
  StatusMessage := 'Courbe scindee en deux.';
  EndOp(S0,True);
  Exit;
 End;
 If Not ObjToPoly(Proto,Q) Then Begin
  StatusMessage := 'Scinder : objet non applicable.';
  Exit;
 End;
 If Not NearestOnPoly(Q,PX,PY,Seg,U,QX,QY) Then Exit;
 FillChar(QA,SizeOf(QA),0); FillChar(QB,SizeOf(QB),0);
 If Q.Closed Then Begin
  { le chemin ferme est ouvert au point de coupe }
  If Q.N+2 > 100 Then Begin
   StatusMessage := 'Scinder : trop de points.';
   Exit;
  End;
  AddPt(QA,QX,QY);
  For I := 1 To Q.N Do AddPt(QA,Q.P[(Seg+I) Mod Q.N].X,Q.P[(Seg+I) Mod Q.N].Y);
  AddPt(QA,QX,QY);
  If QA.N < 3 Then Begin StatusMessage := 'Scinder : chemin trop court.'; Exit; End;
  If Not BeginOp(S0) Then Exit;
  PolyToObj(QA,Proto,A);
  ObjAt(SelectedObject)^ := A;
  StatusMessage := 'Chemin ferme ouvert au point de coupe.';
  EndOp(S0,True);
  Exit;
 End;
 For I := 0 To Seg Do AddPt(QA,Q.P[I].X,Q.P[I].Y);
 AddPt(QA,QX,QY);
 AddPt(QB,QX,QY);
 For I := Seg+1 To Q.N-1 Do AddPt(QB,Q.P[I].X,Q.P[I].Y);
 If (QA.N < 2) Or (QB.N < 2) Then Begin
  StatusMessage := 'Scinder : cliquer sur le chemin, loin de ses extremites.';
  Exit;
 End;
 If Not BeginOp(S0) Then Exit;
 PolyToObj(QA,Proto,A);
 PolyToObj(QB,Proto,B);
 ObjAt(SelectedObject)^ := A;
 AppendObject(B);
 StatusMessage := 'Chemin scinde en deux.';
 EndOp(S0,True);
End;

{ ---- Cont. Coin / Cont. Courbe ---- }
Procedure CornerCommand;
Var I, N: Integer; S0: TSnapshot; S: String;
Begin
 N := 0;
 If Not BeginOp(S0) Then Exit;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And (ObjAt(I)^.ObjType = OBJ_BEZIER) Then Begin
   ObjAt(I)^.Path.Points[1].X := ObjAt(I)^.Path.Points[0].X;
   ObjAt(I)^.Path.Points[1].Y := ObjAt(I)^.Path.Points[0].Y;
   ObjAt(I)^.Path.Points[2].X := ObjAt(I)^.Path.Points[3].X;
   ObjAt(I)^.Path.Points[2].Y := ObjAt(I)^.Path.Points[3].Y;
   Inc(N);
  End;
 If N = 0 Then Begin
  StatusMessage := 'Cont. Coin : selectionner une courbe de Bezier (les autres chemins n''ont que des coins).';
  EndOp(S0,False);
  Exit;
 End;
 Str(N,S);
 StatusMessage := S+' courbe(s) ramenee(s) a des coins (poignees rentrees).';
 EndOp(S0,True);
End;

Procedure SmoothPath(Var Q: TPoly; Var R: TPoly; Var Ok: Boolean);
Var Segs, Steps, I, J, K: Integer; T, T2, T3, X, Y: Real;
    A, B, C, D: TPoint2D;
Begin
 Ok := False;
 FillChar(R,SizeOf(R),0);
 If Q.N < 3 Then Exit;
 Segs := Q.N-1;
 If Q.Closed Then Segs := Q.N;
 Steps := 99 Div Segs;
 If Steps > 6 Then Steps := 6;
 If Steps < 2 Then Exit;
 R.Closed := Q.Closed;
 For I := 0 To Segs-1 Do Begin
  If Q.Closed Then Begin
   A := Q.P[(I+Q.N-1) Mod Q.N]; B := Q.P[I]; C := Q.P[(I+1) Mod Q.N]; D := Q.P[(I+2) Mod Q.N];
  End Else Begin
   If I = 0 Then A := Q.P[0] Else A := Q.P[I-1];
   B := Q.P[I]; C := Q.P[I+1];
   If I+2 > Q.N-1 Then D := Q.P[Q.N-1] Else D := Q.P[I+2];
  End;
  For J := 0 To Steps-1 Do Begin
   T := J/Steps; T2 := T*T; T3 := T2*T;
   X := 0.5*((2*B.X)+(-A.X+C.X)*T+(2*A.X-5*B.X+4*C.X-D.X)*T2+(-A.X+3*B.X-3*C.X+D.X)*T3);
   Y := 0.5*((2*B.Y)+(-A.Y+C.Y)*T+(2*A.Y-5*B.Y+4*C.Y-D.Y)*T2+(-A.Y+3*B.Y-3*C.Y+D.Y)*T3);
   FillChar(R.P[R.N],SizeOf(TPoint2D),0);
   R.P[R.N].X := X; R.P[R.N].Y := Y;
   Inc(R.N);
  End;
 End;
 If Not Q.Closed Then Begin
  FillChar(R.P[R.N],SizeOf(TPoint2D),0);
  R.P[R.N].X := Q.P[Q.N-1].X; R.P[R.N].Y := Q.P[Q.N-1].Y;
  Inc(R.N);
 End;
 ClampPoly(R);
 Ok := True;
End;

Procedure CurveCommand;
Var I, N, Skipped: Integer; S0: TSnapshot; S: String; Q, R: TPoly; Ok: Boolean;
    O, NewO: TGraphicObject; DX, DY, L, NX, NY: Real; P0, P3: TPoint2D;
Begin
 N := 0; Skipped := 0;
 If Not BeginOp(S0) Then Exit;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) Then Begin
   O := ObjAt(I)^;
   If O.ObjType = OBJ_BEZIER Then Begin
    P0 := O.Path.Points[0]; P3 := O.Path.Points[3];
    DX := P3.X-P0.X; DY := P3.Y-P0.Y;
    L := Sqrt(Sqr(DX)+Sqr(DY));
    If L > 1 Then Begin
     NX := -DY/L; NY := DX/L;
     O.Path.Points[1].X := P0.X+DX/3+NX*L/4; O.Path.Points[1].Y := P0.Y+DY/3+NY*L/4;
     O.Path.Points[2].X := P3.X-DX/3+NX*L/4; O.Path.Points[2].Y := P3.Y-DY/3+NY*L/4;
     R.N := 0;
     O.Path.Points[1].X := MaxReal(0,MinReal(PageW-1,O.Path.Points[1].X));
     O.Path.Points[1].Y := MaxReal(0,MinReal(PageH-1,O.Path.Points[1].Y));
     O.Path.Points[2].X := MaxReal(0,MinReal(PageW-1,O.Path.Points[2].X));
     O.Path.Points[2].Y := MaxReal(0,MinReal(PageH-1,O.Path.Points[2].Y));
     ObjAt(I)^ := O;
     Inc(N);
    End;
   End Else If O.ObjType In [OBJ_PATH,OBJ_FILLED_PATH] Then Begin
    ObjToPoly(O,Q);
    SmoothPath(Q,R,Ok);
    If Ok Then Begin
     PolyToObj(R,O,NewO);
     NewO.Path.StrokeWidth := O.Path.StrokeWidth;
     NewO.ObjType := O.ObjType;
     NewO.Path.FillColor := O.Path.FillColor;
     ObjAt(I)^ := NewO;
     Inc(N);
    End Else Inc(Skipped);
   End;
  End;
 If N = 0 Then Begin
  If Skipped > 0 Then StatusMessage := 'Cont. Courbe : chemin trop court ou trop de points (max 100).'
  Else StatusMessage := 'Cont. Courbe : selectionner un chemin ou une courbe.';
  EndOp(S0,False);
  Exit;
 End;
 Str(N,S);
 StatusMessage := S+' objet(s) lisse(s) en courbe.';
 EndOp(S0,True);
End;

{ ---- Simplifier (Douglas-Peucker) ---- }
Procedure DPSimplify(Var Q: TPoly; Var Keep: TKeep; Lo, Hi: Integer; Eps: Real);
Var I, Far: Integer; DX, DY, D, T, X, Y, M, L2: Real;
Begin
 If Hi <= Lo+1 Then Exit;
 DX := Q.P[Hi].X-Q.P[Lo].X; DY := Q.P[Hi].Y-Q.P[Lo].Y;
 L2 := Sqr(DX)+Sqr(DY);
 M := -1; Far := Lo;
 For I := Lo+1 To Hi-1 Do Begin
  T := 0;
  If L2 > 0 Then T := ((Q.P[I].X-Q.P[Lo].X)*DX+(Q.P[I].Y-Q.P[Lo].Y)*DY)/L2;
  T := MaxReal(0,MinReal(1,T));
  X := Q.P[Lo].X+T*DX; Y := Q.P[Lo].Y+T*DY;
  D := Sqrt(Sqr(Q.P[I].X-X)+Sqr(Q.P[I].Y-Y));
  If D > M Then Begin M := D; Far := I; End;
 End;
 If M > Eps Then Begin
  Keep[Far] := True;
  DPSimplify(Q,Keep,Lo,Far,Eps);
  DPSimplify(Q,Keep,Far,Hi,Eps);
 End;
End;

Procedure SimplifySelection(Index: Integer);
Var I, J, K, N, Removed: Integer; S0: TSnapshot; S: String; Q, R: TPoly; Keep: TKeep;
    Eps: Real; O, NewO: TGraphicObject;
Begin
 Case Index Of
  0: Eps := 1; 1: Eps := 2; 2: Eps := 4;
 Else Eps := 8;
 End;
 N := 0; Removed := 0;
 If Not BeginOp(S0) Then Exit;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And (ObjAt(I)^.ObjType In [OBJ_PATH,OBJ_FILLED_PATH]) Then Begin
   O := ObjAt(I)^;
   ObjToPoly(O,Q);
   If Q.N >= 3 Then Begin
    FillChar(Keep,SizeOf(Keep),0);
    Keep[0] := True; Keep[Q.N-1] := True;
    DPSimplify(Q,Keep,0,Q.N-1,Eps);
    FillChar(R,SizeOf(R),0);
    R.Closed := Q.Closed;
    For J := 0 To Q.N-1 Do
     If Keep[J] Then Begin R.P[R.N] := Q.P[J]; Inc(R.N); End;
    If (R.N < Q.N) And (R.N >= 2) And (Not R.Closed Or (R.N >= 3)) Then Begin
     PolyToObj(R,O,NewO);
     NewO.ObjType := O.ObjType;
     NewO.Path.FillColor := O.Path.FillColor;
     ObjAt(I)^ := NewO;
     Removed := Removed+(Q.N-R.N);
     Inc(N);
    End;
   End;
  End;
 If N = 0 Then Begin
  StatusMessage := 'Simplifier : aucun point a retirer (ou aucun chemin selectionne).';
  EndOp(S0,False);
  Exit;
 End;
 Str(Removed,S);
 StatusMessage := 'Simplification : '+S+' point(s) retire(s).';
 EndOp(S0,True);
End;

{ ---- Decalage ---- }
Function OffsetPoly(Var Q: TPoly; D: Real; Var R: TPoly): Boolean;
Var I, N: Integer; Area, X0, Y0, X1, Y1, X2, Y2, E1X, E1Y, E2X, E2Y, L1, L2,
    N1X, N1Y, N2X, N2Y, BX, BY, BL, Cs, Sg, Miter: Real;
Begin
 OffsetPoly := False;
 R := Q;
 N := Q.N;
 If N < 3 Then Exit;
 Area := 0;
 For I := 0 To N-1 Do
  Area := Area+Q.P[I].X*Q.P[(I+1) Mod N].Y-Q.P[(I+1) Mod N].X*Q.P[I].Y;
 If Area = 0 Then Exit;
 If Area > 0 Then Sg := 1 Else Sg := -1;
 For I := 0 To N-1 Do Begin
  X0 := Q.P[(I+N-1) Mod N].X; Y0 := Q.P[(I+N-1) Mod N].Y;
  X1 := Q.P[I].X; Y1 := Q.P[I].Y;
  X2 := Q.P[(I+1) Mod N].X; Y2 := Q.P[(I+1) Mod N].Y;
  E1X := X1-X0; E1Y := Y1-Y0; E2X := X2-X1; E2Y := Y2-Y1;
  L1 := Sqrt(Sqr(E1X)+Sqr(E1Y)); L2 := Sqrt(Sqr(E2X)+Sqr(E2Y));
  If L1 = 0 Then Begin E1X := E2X; E1Y := E2Y; L1 := L2; End;
  If L2 = 0 Then Begin E2X := E1X; E2Y := E1Y; L2 := L1; End;
  If (L1 = 0) Or (L2 = 0) Then Exit;
  N1X := Sg*E1Y/L1; N1Y := -Sg*E1X/L1;
  N2X := Sg*E2Y/L2; N2Y := -Sg*E2X/L2;
  BX := N1X+N2X; BY := N1Y+N2Y;
  BL := Sqrt(Sqr(BX)+Sqr(BY));
  If BL < 0.0001 Then Begin BX := N1X; BY := N1Y; BL := 1; End;
  BX := BX/BL; BY := BY/BL;
  Cs := BX*N1X+BY*N1Y;
  If Cs < 0.3 Then Cs := 0.3;
  Miter := D/Cs;
  R.P[I].X := Round((X1+BX*Miter)*1000)/1000;
  R.P[I].Y := Round((Y1+BY*Miter)*1000)/1000;
 End;
 OffsetPoly := True;
End;

Procedure OffsetSelection(Index: Integer);
Var I, N: Integer; D: Real; S0: TSnapshot; S: String; O, NewO: TGraphicObject;
    Q, R: TPoly; Ok, Bad: Boolean; B: TBounds;
Begin
 Case Index Of
  0: D := 4; 1: D := 10; 2: D := -4;
 Else D := -10;
 End;
 N := 0; Bad := False;
 If Not BeginOp(S0) Then Exit;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) Then Begin
   O := ObjAt(I)^;
   Ok := False;
   Case O.ObjType Of
    OBJ_RECT: Begin
     If (O.Rectangle.Width+2*D > 1) And (O.Rectangle.Height+2*D > 1) Then Begin
      O.Rectangle.X := O.Rectangle.X-D; O.Rectangle.Y := O.Rectangle.Y-D;
      O.Rectangle.Width := O.Rectangle.Width+2*D;
      O.Rectangle.Height := O.Rectangle.Height+2*D;
      Ok := True;
     End Else Bad := True;
    End;
    OBJ_ELLIPSE: Begin
     If (O.Ellipse.RX+D > 1) And (O.Ellipse.RY+D > 1) Then Begin
      O.Ellipse.RX := O.Ellipse.RX+D; O.Ellipse.RY := O.Ellipse.RY+D;
      Ok := True;
     End Else Bad := True;
    End;
    OBJ_PATH, OBJ_FILLED_PATH: Begin
     If ObjToPoly(O,Q) And (O.Path.Closed Or (O.ObjType = OBJ_FILLED_PATH)) Then Begin
      Q.Closed := True;
      If OffsetPoly(Q,D,R) Then Begin
       PolyToObj(R,O,NewO);
       NewO.ObjType := O.ObjType;
       NewO.Path.FillColor := O.Path.FillColor;
       NewO.Path.Closed := O.Path.Closed;
       O := NewO;
       Ok := True;
      End Else Bad := True;
     End;
    End;
   End;
   If Ok Then Begin
    B := ObjectBounds(O);
    If (B.L < 0) Or (B.T < 0) Or (B.R >= PageW) Or (B.B >= PageH) Then Bad := True
    Else Begin ObjAt(I)^ := O; Inc(N); End;
   End;
  End;
 If N = 0 Then Begin
  If Bad Then StatusMessage := 'Decalage : resultat degenere ou hors de la page.'
  Else StatusMessage := 'Decalage : selectionner un chemin ferme, un rectangle ou une ellipse.';
  EndOp(S0,False);
  Exit;
 End;
 Str(N,S);
 StatusMessage := 'Decalage applique a '+S+' objet(s).';
 If Bad Then StatusMessage := StatusMessage+' (certains ignores)';
 EndOp(S0,True);
End;

{ ------------------------------------------------------------------
  Menu Texte : Glyphes, Texte a chemin, Polices, Formats, Affichage
  ------------------------------------------------------------------ }
Const
 CH_FONT = 6;
 CH_FORMAT = 7;
 CH_TEXTVIEW = 8;
 W_GLYPH_BTN = 212;

Var
 GlyphActive, GlyphUndone: Boolean;
 GlyphHover: Integer;

Procedure TextBoundsFit(Var O: TGraphicObject; Var Ok: Boolean);
Var B: TBounds; W, H: Real;
Begin
 B := ObjectBounds(O);
 W := B.R-B.L+1; H := B.B-B.T+1;
 Ok := (W <= PageW) And (H <= PageH);
 If Not Ok Then Exit;
 If O.TextObj.X+W > PageW Then O.TextObj.X := PageW-W;
 If O.TextObj.Y+H > PageH Then O.TextObj.Y := PageH-H;
 If O.TextObj.X < 0 Then O.TextObj.X := 0;
 If O.TextObj.Y < 0 Then O.TextObj.Y := 0;
End;

{ ---- Polices : style et taille des textes selectionnes ---- }
Procedure FontSelection(Index: Integer);
Var I, N, St, Bad: Integer; O: TGraphicObject; S0: TSnapshot; Ok: Boolean; S: String;
Begin
 N := 0; Bad := 0;
 If Not BeginOp(S0) Then Exit;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And (ObjAt(I)^.ObjType = OBJ_TEXT) Then Begin
   O := ObjAt(I)^;
   St := TextStyleOf(O);
   Case Index Of
    0: St := 0;
    1: St := St Xor 1;
    2: St := St Xor 2;
    3: St := St Xor 4;
   Else O.TextObj.FontSize := 8*(Index-3);
   End;
   O.Rectangle.Width := St;
   TextBoundsFit(O,Ok);
   If Ok Then Begin ObjAt(I)^ := O; Inc(N); End Else Inc(Bad);
  End;
 If N = 0 Then Begin
  If Bad > 0 Then StatusMessage := 'Polices : le texte serait plus large que la page.'
  Else StatusMessage := 'Polices : selectionner au moins un texte.';
  EndOp(S0,False);
  Exit;
 End;
 Str(N,S);
 StatusMessage := 'Police appliquee a '+S+' texte(s).';
 EndOp(S0,True);
End;

{ ---- Formats : casse et espaces ---- }
Function ChangeCase(T: String; Mode: Integer): String;
Var I: Integer; C: Char; NewWord: Boolean; R: String;
Begin
 R := T; NewWord := True;
 For I := 1 To Length(R) Do Begin
  C := R[I];
  Case Mode Of
   0: If (C >= 'a') And (C <= 'z') Then C := Chr(Ord(C)-32);
   1: If (C >= 'A') And (C <= 'Z') Then C := Chr(Ord(C)+32);
   2: Begin
    If NewWord Then Begin If (C >= 'a') And (C <= 'z') Then C := Chr(Ord(C)-32); End
    Else If (C >= 'A') And (C <= 'Z') Then C := Chr(Ord(C)+32);
   End;
   3: If (C >= 'a') And (C <= 'z') Then C := Chr(Ord(C)-32)
      Else If (C >= 'A') And (C <= 'Z') Then C := Chr(Ord(C)+32);
  End;
  NewWord := (C = ' ');
  R[I] := C;
 End;
 ChangeCase := R;
End;

Function TrimSpaces(T: String): String;
Var I: Integer; R: String; Prev: Boolean;
Begin
 R := ''; Prev := True;
 For I := 1 To Length(T) Do
  If T[I] = ' ' Then Begin
   If Not Prev Then R := R+' ';
   Prev := True;
  End Else Begin R := R+T[I]; Prev := False; End;
 If (Length(R) > 0) And (R[Length(R)] = ' ') Then Delete(R,Length(R),1);
 TrimSpaces := R;
End;

Procedure FormatSelection(Index: Integer);
Var I, N: Integer; T: String; S0: TSnapshot; S: String;
Begin
 N := 0;
 If Not BeginOp(S0) Then Exit;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And (ObjAt(I)^.ObjType = OBJ_TEXT) Then Begin
   If Index <= 3 Then T := ChangeCase(ObjAt(I)^.TextObj.Text,Index)
   Else T := TrimSpaces(ObjAt(I)^.TextObj.Text);
   If (T <> '') And (T <> ObjAt(I)^.TextObj.Text) Then Begin
    ObjAt(I)^.TextObj.Text := T;
    Inc(N);
   End;
  End;
 If N = 0 Then Begin
  StatusMessage := 'Formats : aucun texte a modifier dans la selection.';
  EndOp(S0,False);
  Exit;
 End;
 Str(N,S);
 StatusMessage := 'Format applique a '+S+' texte(s).';
 EndOp(S0,True);
End;

{ ---- Affichage du texte ---- }
Procedure TextViewChoice(Index: Integer);
Begin
 Case Index Of
  0: TextFrames := Not TextFrames;
  1: GreekText := Not GreekText;
 Else Begin TextFrames := False; GreekText := False; End;
 End;
 If GreekText Then StatusMessage := 'Texte en barres (apercu rapide).'
 Else If TextFrames Then StatusMessage := 'Cadres de texte affiches.'
 Else StatusMessage := 'Affichage du texte normal.';
 NeedsRedraw := True;
End;

{ ---- Texte a chemin ---- }
Procedure TextToPathCommand;
Var I, TIdx, PIdx, K, Seg, Cnt, Placed: Integer; N: LongInt; Idx: PLongArr;
    T, Pr: TGraphicObject; Q: TPoly; S0: TSnapshot; MaxG, Sc, J: LongInt;
    Total, D, SegL, U, X, Y: Real; Cum: Array[0..100] Of Real; C: TGraphicObject;
    Txt, S: String; Cut: Boolean; B: TBounds;
Begin
 TIdx := -1; PIdx := -1;
 For I := 0 To ObjectCount-1 Do
  If IsSel(I) And ObjAt(I)^.Visible Then Begin
   If (ObjAt(I)^.ObjType = OBJ_TEXT) Then Begin
    If (TIdx < 0) Or (I = SelectedObject) Then TIdx := I;
   End Else If PIdx < 0 Then PIdx := I;
  End;
 If (TIdx < 0) Or (PIdx < 0) Then Begin
  StatusMessage := 'Texte a chemin : selectionner un texte ET un chemin (rectangle de selection).';
  Exit;
 End;
 T := ObjAt(TIdx)^;
 If Not ObjToPoly(ObjAt(PIdx)^,Q) Then Begin
  StatusMessage := 'Texte a chemin : chemin non utilisable.';
  Exit;
 End;
 If Q.Closed Then Begin
  If Q.N >= 100 Then Dec(Q.N);
  Q.P[Q.N] := Q.P[0]; Inc(Q.N);
 End;
 Cum[0] := 0;
 For K := 1 To Q.N-1 Do
  Cum[K] := Cum[K-1]+Dist2(Q.P[K-1].X,Q.P[K-1].Y,Q.P[K].X,Q.P[K].Y);
 Total := Cum[Q.N-1];
 If Total < 1 Then Begin
  StatusMessage := 'Texte a chemin : chemin trop court.';
  Exit;
 End;
 Sc := TextScaleOf(T);
 Txt := T.TextObj.Text;
 If Not BeginOp(S0) Then Exit;
 MaxG := 0;
 For I := 0 To ObjectCount-1 Do
  If GroupOfObj(ObjAt(I)^) > MaxG Then MaxG := GroupOfObj(ObjAt(I)^);
 Placed := 0; Cut := False;
 Pr := T;
 For J := 1 To Length(Txt) Do Begin
  D := (J-1)*8*Sc+4*Sc;
  If D > Total Then Begin Cut := True; Break; End;
  If Txt[J] <> ' ' Then Begin
   Seg := 0;
   While (Seg < Q.N-2) And (Cum[Seg+1] < D) Do Inc(Seg);
   SegL := Cum[Seg+1]-Cum[Seg];
   U := 0;
   If SegL > 0 Then U := (D-Cum[Seg])/SegL;
   X := Q.P[Seg].X+U*(Q.P[Seg+1].X-Q.P[Seg].X)-4*Sc;
   Y := Q.P[Seg].Y+U*(Q.P[Seg+1].Y-Q.P[Seg].Y)-4*Sc;
   C := Pr;
   C.TextObj.Text := Txt[J];
   C.TextObj.X := MaxReal(0,MinReal(PageW-8*Sc,Round(X)));
   C.TextObj.Y := MaxReal(0,MinReal(PageH-8*Sc,Round(Y)));
   SetGroupOfObj(C,MaxG+1);
   SelFlagPtr(C)^ := True;
   AppendObject(C);
   Inc(Placed);
  End;
 End;
 If Placed = 0 Then Begin
  EndOp(S0,False);
  StatusMessage := 'Texte a chemin : rien a placer.';
  Exit;
 End;
 { le texte d'origine est remplace par ses caracteres poses sur le chemin }
 DeleteObjectAt(TIdx);
 ClearSelFlags;
 SelectedObject := ObjectCount-1;
 SelectGroupOf(SelectedObject);
 Str(Placed,S);
 StatusMessage := S+' caractere(s) poses sur le chemin (groupe).';
 If Cut Then StatusMessage := StatusMessage+' Texte tronque.';
 EndOp(S0,True);
End;

{ ---- Glyphes : table des caracteres ---- }
Function GlyphWX: Integer;
Begin
 GlyphWX := (ScreenWidth-312) Div 2;
End;

Function GlyphWY: Integer;
Begin
 GlyphWY := (ScreenHeight-372) Div 2;
End;

Function GlyphX0: Integer;
Begin
 GlyphX0 := GlyphWX+12;
End;

Function GlyphY0: Integer;
Begin
 GlyphY0 := GlyphWY+34;
End;

Procedure OpenGlyphs;
Begin
 GlyphActive := True; GlyphUndone := False; GlyphHover := -1;
 StatusMessage := 'Glyphes : cliquer un caractere pour l''ajouter au texte selectionne.';
 NeedsRedraw := True;
End;

Procedure CloseGlyphs;
Begin
 GlyphActive := False;
 NeedsRedraw := True;
End;

Procedure InsertGlyph(Code: Integer);
Var O: TGraphicObject; Ok: Boolean; B: TBounds;
Begin
 If (SelectedObject >= 0) And (SelectedObject < ObjectCount) And
    (ObjAt(SelectedObject)^.ObjType = OBJ_TEXT) Then Begin
  O := ObjAt(SelectedObject)^;
  If Length(O.TextObj.Text) >= 255 Then Begin
   StatusMessage := 'Glyphes : texte plein (255 caracteres).';
   Exit;
  End;
  O.TextObj.Text := O.TextObj.Text+Chr(Code);
  B := ObjectBounds(O);
  If B.R >= PageW Then Begin
   StatusMessage := 'Glyphes : bord de la page atteint.';
   Exit;
  End;
  If Not GlyphUndone Then Begin PushUndo; GlyphUndone := True; End;
  ObjAt(SelectedObject)^ := O;
 End Else Begin
  FillChar(O,SizeOf(O),0);
  O.ObjType := OBJ_TEXT;
  O.Visible := True;
  O.LayerIndex := CurrentLayer;
  O.TextObj.X := 100; O.TextObj.Y := 100;
  O.TextObj.Text := Chr(Code);
  O.TextObj.Color := StrokeColor;
  O.TextObj.FontSize := 8;
  If Not GlyphUndone Then Begin PushUndo; GlyphUndone := True; End;
  ClearSelFlags;
  AppendObject(O);
  SelectedObject := ObjectCount-1;
 End;
 FileModified := True;
 StatusMessage := 'Caractere ajoute.';
 NeedsRedraw := True;
End;

Function GlyphAt(X, Y: Integer): Integer;
Var CX, CY, I: Integer;
Begin
 GlyphAt := -1;
 CX := (X-GlyphX0) Div 18; CY := (Y-GlyphY0) Div 18;
 If (X < GlyphX0) Or (Y < GlyphY0) Or (CX < 0) Or (CX > 15) Or (CY < 0) Or (CY > 13) Then Exit;
 I := 33+CY*16+CX;
 If I <= 255 Then GlyphAt := I;
End;

Procedure DrawGlyphDialog;
Var WX, WY, X0, Y0, I, R, C, PX, PY, SY, SX: Integer; S: String;
Begin
 If Not GlyphActive Then Exit;
 WX := GlyphWX; WY := GlyphWY; X0 := GlyphX0; Y0 := GlyphY0;
 UiWindow(WX,WY,WX+312,WY+372,'Glyphes');
 UiSunken(X0-2,Y0-2,X0+16*18+1,Y0+14*18+1);
 GlyphHover := GlyphAt(MouseX,MouseY);
 For I := 33 To 255 Do Begin
  R := (I-33) Div 16; C := (I-33) Mod 16;
  PX := X0+C*18; PY := Y0+R*18;
  If I = GlyphHover Then Begin
   SetFillStyle(SolidFill,COLOR_HIGHLIGHT);
   Bar(PX,PY,PX+17,PY+17);
  End;
  For SY := 0 To 7 Do
   For SX := 0 To 7 Do
    If (GlyphRows[I,SY] And (1 Shl SX)) <> 0 Then Begin
     If I = GlyphHover Then PutPixel(PX+5+SX,PY+5+SY,COLOR_WINDOW)
     Else PutPixel(PX+5+SX,PY+5+SY,COLOR_TEXT);
    End;
 End;
 UiGroup(WX+12,WY+296,WX+200,WY+342,'Caractere');
 If GlyphHover >= 0 Then Begin
  Str(GlyphHover,S);
  UiText(WX+24,WY+318,'Code '+S);
  UiSunken(WX+130,WY+310,WX+170,WY+334);
  For SY := 0 To 7 Do
   For SX := 0 To 7 Do
    If (GlyphRows[GlyphHover,SY] And (1 Shl SX)) <> 0 Then Begin
     SetFillStyle(SolidFill,COLOR_TEXT);
     Bar(WX+136+SX*3,WY+312+SY*3,WX+138+SX*3,WY+314+SY*3);
    End;
 End Else UiText(WX+24,WY+318,'Survoler un signe');
 UiButton(WX+W_GLYPH_BTN,WY+310,WX+W_GLYPH_BTN+88,WY+334,'Fermer',True,True);
End;

Procedure HandleGlyphMouse;
Var I: Integer;
Begin
 NeedsRedraw := True;
 If UiCloseHit(GlyphWX+312,GlyphWY) Then Begin CloseGlyphs; Exit; End;
 If UiInside(GlyphWX+W_GLYPH_BTN,GlyphWY+310,GlyphWX+W_GLYPH_BTN+88,GlyphWY+334) Then Begin
  CloseGlyphs; Exit;
 End;
 I := GlyphAt(MouseX,MouseY);
 If I >= 0 Then InsertGlyph(I);
End;

Procedure HandleGlyphKey(Key: Char);
Begin
 NeedsRedraw := True;
 If (Key = #27) Or (Key = #13) Then CloseGlyphs;
End;

{ ---- boite de choix generique ---- }
Procedure OpenChoice(Kind: Integer);
Var N: Integer;
Begin
 N := SelCount;
 Case Kind Of
  CH_ALIGN: If N < 2 Then Begin
   StatusMessage := 'Aligner : selectionner au moins deux objets.'; Exit;
  End;
  CH_DISTRIB: If N < 3 Then Begin
   StatusMessage := 'Distribuer : selectionner au moins trois objets.'; Exit;
  End;
  CH_TRANSFORM: If N < 1 Then Begin
   StatusMessage := 'Transformer : aucun objet selectionne.'; Exit;
  End;
  CH_SIMPLIFY, CH_OFFSET: If N < 1 Then Begin
   StatusMessage := 'Chemin : aucun objet selectionne.'; Exit;
  End;
 End;
 ChoiceKind := Kind;
 ChoiceSel := 0; ChoiceLastIdx := -1;
 Case Kind Of
  CH_ALIGN: Begin
   ChoiceCount := 6;
   ChoiceItems[0] := 'Aligner a gauche'; ChoiceItems[1] := 'Centrer horizontalement';
   ChoiceItems[2] := 'Aligner a droite'; ChoiceItems[3] := 'Aligner en haut';
   ChoiceItems[4] := 'Centrer verticalement'; ChoiceItems[5] := 'Aligner en bas';
  End;
  CH_DISTRIB: Begin
   ChoiceCount := 4;
   ChoiceItems[0] := 'Centres horizontaux egaux'; ChoiceItems[1] := 'Centres verticaux egaux';
   ChoiceItems[2] := 'Espacement horizontal egal'; ChoiceItems[3] := 'Espacement vertical egal';
  End;
  CH_TRANSFORM: Begin
   ChoiceCount := 10;
   ChoiceItems[0] := 'Rotation 90 deg. horaire'; ChoiceItems[1] := 'Rotation 90 deg. antihoraire';
   ChoiceItems[2] := 'Rotation 180 deg.'; ChoiceItems[3] := 'Rotation 45 deg. horaire';
   ChoiceItems[4] := 'Miroir horizontal'; ChoiceItems[5] := 'Miroir vertical';
   ChoiceItems[6] := 'Echelle 50 %'; ChoiceItems[7] := 'Echelle 200 %';
   ChoiceItems[8] := 'Echelle 90 %'; ChoiceItems[9] := 'Echelle 110 %';
  End;
  CH_FONT: Begin
   ChoiceCount := 8;
   ChoiceItems[0] := 'Normal (retire les styles)'; ChoiceItems[1] := 'Gras (bascule)';
   ChoiceItems[2] := 'Italique (bascule)'; ChoiceItems[3] := 'Souligne (bascule)';
   ChoiceItems[4] := 'Taille x1 (8 px)'; ChoiceItems[5] := 'Taille x2 (16 px)';
   ChoiceItems[6] := 'Taille x3 (24 px)'; ChoiceItems[7] := 'Taille x4 (32 px)';
  End;
  CH_FORMAT: Begin
   ChoiceCount := 5;
   ChoiceItems[0] := 'MAJUSCULES'; ChoiceItems[1] := 'minuscules';
   ChoiceItems[2] := 'Casse de titre'; ChoiceItems[3] := 'Inverser la casse';
   ChoiceItems[4] := 'Retirer les espaces en trop';
  End;
  CH_TEXTVIEW: Begin
   ChoiceCount := 3;
   If TextFrames Then ChoiceItems[0] := '[x] Cadres de texte'
   Else ChoiceItems[0] := '[ ] Cadres de texte';
   If GreekText Then ChoiceItems[1] := '[x] Texte en barres (apercu)'
   Else ChoiceItems[1] := '[ ] Texte en barres (apercu)';
   ChoiceItems[2] := 'Reinitialiser l''affichage';
  End;
  CH_SIMPLIFY: Begin
   ChoiceCount := 4;
   ChoiceItems[0] := 'Tolerance 1 px (faible)'; ChoiceItems[1] := 'Tolerance 2 px';
   ChoiceItems[2] := 'Tolerance 4 px'; ChoiceItems[3] := 'Tolerance 8 px (forte)';
  End;
  CH_OFFSET: Begin
   ChoiceCount := 4;
   ChoiceItems[0] := 'Agrandir de 4 px'; ChoiceItems[1] := 'Agrandir de 10 px';
   ChoiceItems[2] := 'Reduire de 4 px'; ChoiceItems[3] := 'Reduire de 10 px';
  End;
 Else Begin
  ChoiceCount := 6;
  ChoiceItems[0] := 'Dupliquer'; ChoiceItems[1] := 'Supprimer';
  ChoiceItems[2] := 'Tout selectionner'; ChoiceItems[3] := 'Inverser la selection';
  ChoiceItems[4] := 'Deselectionner'; ChoiceItems[5] := 'Annuler';
 End;
 End;
 ChoiceActive := True;
 NeedsRedraw := True;
End;

Procedure CloseChoice(Index: Integer);
Var K: Integer;
Begin
 ChoiceActive := False;
 NeedsRedraw := True;
 K := ChoiceKind;
 If (Index < 0) Or (Index >= ChoiceCount) Then Begin
  If K <> CH_TEXTVIEW Then StatusMessage := 'Commande annulee.';
  Exit;
 End;
 Case K Of
  CH_ALIGN: AlignSelection(Index);
  CH_DISTRIB: DistributeSelection(Index);
  CH_SIMPLIFY: SimplifySelection(Index);
  CH_FONT: FontSelection(Index);
  CH_FORMAT: FormatSelection(Index);
  CH_TEXTVIEW: TextViewChoice(Index);
  CH_OFFSET: OffsetSelection(Index);
  CH_TRANSFORM: Case Index Of
   0: TransformSelection(TR_ROT,Pi/2);
   1: TransformSelection(TR_ROT,-Pi/2);
   2: TransformSelection(TR_ROT,Pi);
   3: TransformSelection(TR_ROT,Pi/4);
   4: TransformSelection(TR_FLIPH,0);
   5: TransformSelection(TR_FLIPV,0);
   6: TransformSelection(TR_SCALE,0.5);
   7: TransformSelection(TR_SCALE,2);
   8: TransformSelection(TR_SCALE,0.9);
   9: TransformSelection(TR_SCALE,1.1);
  End;
 Else Case Index Of
   0: DuplicateSelection;
   1: DeleteSelection;
   2: SelectAllCommand;
   3: InvertSelection;
   4: DeselectAll;
  End;
 End;
End;

Function ChoiceX: Integer;
Begin
 ChoiceX := (ScreenWidth-300) Div 2;
End;

Function ChoiceY: Integer;
Begin
 ChoiceY := (ScreenHeight-(50+ChoiceCount*20)) Div 2;
End;

{ geometrie de la boite de choix }
Procedure ChoiceGeom(Var X, Y, W, H, LH: Integer);
Begin
 W := 330;
 If ChoiceKind = CH_TEXTVIEW Then Begin
  LH := 0; H := 150;
 End Else Begin
  LH := ChoiceCount*18+6;
  H := 34+LH+14+24+14;
 End;
 X := (ScreenWidth-W) Div 2;
 Y := (ScreenHeight-H) Div 2;
End;

Function ChoiceTitle: String;
Begin
 Case ChoiceKind Of
  CH_ALIGN: ChoiceTitle := 'Aligner';
  CH_DISTRIB: ChoiceTitle := 'Distribuer';
  CH_TRANSFORM: ChoiceTitle := 'Transformer';
  CH_SIMPLIFY: ChoiceTitle := 'Simplifier le chemin';
  CH_OFFSET: ChoiceTitle := 'Decalage du chemin';
  CH_FONT: ChoiceTitle := 'Polices';
  CH_FORMAT: ChoiceTitle := 'Formats de texte';
  CH_TEXTVIEW: ChoiceTitle := 'Affichage du texte';
 Else ChoiceTitle := 'Operations';
 End;
End;

Procedure DrawChoice;
Var X, Y, W, H, LH, I: Integer;
Begin
 If Not ChoiceActive Then Exit;
 ChoiceGeom(X,Y,W,H,LH);
 UiWindow(X,Y,X+W,Y+H,ChoiceTitle);
 If ChoiceKind = CH_TEXTVIEW Then Begin
  UiGroup(X+12,Y+30,X+W-12,Y+92,'Afficher');
  UiCheck(X+28,Y+50,TextFrames,'Cadres autour des textes');
  UiCheck(X+28,Y+70,GreekText,'Texte en barres (apercu rapide)');
  UiButton(X+12,Y+108,X+148,Y+132,'Reinitialiser',False,True);
  UiButton(X+W-100,Y+108,X+W-12,Y+132,'Fermer',True,True);
  Exit;
 End;
 UiSunken(X+12,Y+34,X+W-12,Y+34+LH);
 For I := 0 To ChoiceCount-1 Do Begin
  If I = ChoiceSel Then Begin
   SetFillStyle(SolidFill,COLOR_HIGHLIGHT);
   Bar(X+15,Y+37+I*18,X+W-15,Y+37+I*18+17);
   SetColor(COLOR_WINDOW);
  End Else SetColor(COLOR_TEXT);
  OutTextXY(X+22,Y+37+I*18+5,ChoiceItems[I]);
 End;
 UiButton(X+W-196,Y+34+LH+14,X+W-108,Y+34+LH+38,'OK',True,True);
 UiButton(X+W-100,Y+34+LH+14,X+W-12,Y+34+LH+38,'Annuler',False,True);
End;

Procedure HandleChoiceMouse;
Var X, Y, W, H, LH, I: Integer; Now: LongInt;
Begin
 NeedsRedraw := True;
 ChoiceGeom(X,Y,W,H,LH);
 If UiCloseHit(X+W,Y) Then Begin CloseChoice(-1); Exit; End;
 If ChoiceKind = CH_TEXTVIEW Then Begin
  If UiInside(X+28,Y+48,X+W-20,Y+64) Then TextViewChoice(0)
  Else If UiInside(X+28,Y+68,X+W-20,Y+84) Then TextViewChoice(1)
  Else If UiInside(X+12,Y+108,X+148,Y+132) Then TextViewChoice(2)
  Else If UiInside(X+W-100,Y+108,X+W-12,Y+132) Then CloseChoice(-1);
  Exit;
 End;
 If UiInside(X+W-196,Y+34+LH+14,X+W-108,Y+34+LH+38) Then Begin
  CloseChoice(ChoiceSel); Exit;
 End;
 If UiInside(X+W-100,Y+34+LH+14,X+W-12,Y+34+LH+38) Then Begin
  CloseChoice(-1); Exit;
 End;
 If UiInside(X+15,Y+37,X+W-15,Y+37+ChoiceCount*18-1) Then Begin
  I := (MouseY-Y-37) Div 18;
  Now := ToolTipClock;
  If (I = ChoiceLastIdx) And (Now >= ChoiceLastClock) And (Now-ChoiceLastClock <= 50) Then
   CloseChoice(I)
  Else Begin
   ChoiceSel := I; ChoiceLastIdx := I; ChoiceLastClock := Now;
  End;
 End;
End;

Procedure HandleChoiceKey(Key, ExtKey: Char);
Var I: Integer;
Begin
 NeedsRedraw := True;
 If Key = #27 Then CloseChoice(-1)
 Else If ChoiceKind = CH_TEXTVIEW Then Begin
  If Key = #13 Then CloseChoice(-1)
  Else If Key = '1' Then TextViewChoice(0)
  Else If Key = '2' Then TextViewChoice(1);
 End
 Else If Key = #13 Then CloseChoice(ChoiceSel)
 Else If (Key = #0) And (ExtKey = #72) And (ChoiceSel > 0) Then Dec(ChoiceSel)
 Else If (Key = #0) And (ExtKey = #80) And (ChoiceSel < ChoiceCount-1) Then Inc(ChoiceSel)
 Else If (Key >= '1') And (Key <= '9') Then Begin
  I := Ord(Key)-Ord('1');
  If I < ChoiceCount Then CloseChoice(I);
 End Else If (Key = '0') And (ChoiceCount >= 10) Then CloseChoice(9);
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
 UiButton(X1,Y1,X2,Y2,Caption,Focused,True);
End;

Procedure DrawFileDialog;
Var I, K, Y, X1, X2, Count, TopIndex, Selected, ScrollX, ThumbY: Integer;
 S, SizeText, Info: String; DT: DateTime;

 Procedure Field(X1,Y1,X2,Y2,Focus: Integer; Value: String);
 Var Start, Caret: Integer; Visible: String;
 Begin
  UiSunken(X1,Y1,X2,Y2);
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
 SetFillStyle(SolidFill,0); Bar(24,48,624,441);
 UiRaised(20,44,620,437);
 SetFillStyle(SolidFill,COLOR_HIGHLIGHT); Bar(23,47,617,66);
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
  UiSunken(X1,128,X2,338);
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
   SetColor(COLOR_HIGHLIGHT); Rectangle(X1-2,126,X2+2,340);
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
  UiSunken(100,FileFilterTop,495,380);
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
   UiWindow(90,170,550,290,'Confirmer le remplacement');
   UiIcon(110,204,True);
   UiText(160,206,'Ce fichier existe deja. Le remplacer ?');
   UiText(160,226,Copy(PendingSaveName,1,45));
   FileButton(140,252,290,278,'Remplacer',True);
   FileButton(330,252,480,278,'Annuler',False);
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
  If (MouseY>=252) And (MouseY<=278) Then
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

{ ---- boite de message ---- }
Function IsConfirmDialog: Boolean;
Begin
 IsConfirmDialog := (DialogTitle = 'Ouvrir un document') Or (DialogTitle = 'Quitter') Or
                    (DialogTitle = 'Nouveau document');
End;

Procedure MsgGeometry(Var X, Y, W, H, TextH, N: Integer; Var L: TLines);
Begin
 W := 440;
 N := WrapLines(DialogText,44,L);
 TextH := N*12;
 If TextH < 36 Then TextH := 36;
 H := 34+TextH+22+24+16;
 X := (ScreenWidth-W) Div 2;
 Y := (ScreenHeight-H) Div 2;
End;

Procedure DrawMessage;
Var X, Y, W, H, TH, N, I: Integer; L: TLines;
Begin
 If DialogTitle = '' Then Exit;
 MsgGeometry(X,Y,W,H,TH,N,L);
 UiWindow(X,Y,X+W,Y+H,DialogTitle);
 UiIcon(X+20,Y+34,IsConfirmDialog);
 For I := 0 To N-1 Do UiText(X+68,Y+38+I*12,L[I]);
 If IsConfirmDialog Then Begin
  UiButton(X+W-196,Y+H-40,X+W-108,Y+H-16,'OK',True,True);
  UiButton(X+W-100,Y+H-40,X+W-12,Y+H-16,'Annuler',False,True);
 End Else UiButton(X+W-100,Y+H-40,X+W-12,Y+H-16,'OK',True,True);
End;

Procedure CloseMessage(Accept: Boolean);
Var T: String;
Begin
 T := DialogTitle;
 DialogTitle := '';
 NeedsRedraw := True;
 If Not Accept Then Exit;
 If T = 'Ouvrir un document' Then StartFileDialog;
 If T = 'Quitter' Then Running := False;
 If T = 'Nouveau document' Then Begin
  ClearObjects;
  ClearGuides;
  SelectedObject := -1;
  ClearHistory;
  CurrentFile := '';
  CurrentSaveFormat := 0;
  FileModified := False;
  ResetZoom;
 End;
End;

Procedure HandleMessageMouse;
Var X, Y, W, H, TH, N: Integer; L: TLines;
Begin
 NeedsRedraw := True;
 MsgGeometry(X,Y,W,H,TH,N,L);
 If UiCloseHit(X+W,Y) Then CloseMessage(False)
 Else If IsConfirmDialog Then Begin
  If UiInside(X+W-196,Y+H-40,X+W-108,Y+H-16) Then CloseMessage(True)
  Else If UiInside(X+W-100,Y+H-40,X+W-12,Y+H-16) Then CloseMessage(False);
 End Else If UiInside(X+W-100,Y+H-40,X+W-12,Y+H-16) Then CloseMessage(True);
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
     'Le dessin a ete modifie. Les changements non enregistres seront perdus. Ouvrir un autre document ?')
   Else StartFileDialog;
  CMD_NEW:
   If FileModified Then
    ShowDialog('Nouveau document',
               'Le dessin a ete modifie. Les changements non enregistres seront perdus. Creer un nouveau document ?')
   Else Begin
    ClearObjects;
    ClearGuides;
    SelectedObject := -1;
    ClearHistory;
    CurrentFile := '';
    CurrentSaveFormat := 0;
    FileModified := False;
    ResetZoom;
   End;
  CMD_UNDO: UndoCommand;
  CMD_REDO: RedoCommand;
  CMD_CUT: CutCommand;
  CMD_COPY: CopyCommand;
  CMD_PASTE: PasteCommand;
  CMD_EXIT:
   If FileModified Then
    ShowDialog('Quitter',
               'Le dessin a ete modifie. Les changements non enregistres seront perdus. Quitter le programme ?')
   Else Running := False;
  CMD_GRID: GridVisible := Not GridVisible;
  CMD_PROPS: OpenProps;
  CMD_GROUP: GroupCommand;
  CMD_UNGROUP: UngroupCommand;
  CMD_ALIGN: OpenChoice(CH_ALIGN);
  CMD_DISTRIB: OpenChoice(CH_DISTRIB);
  CMD_TRANSFORM: OpenChoice(CH_TRANSFORM);
  CMD_OPS: OpenChoice(CH_OPS);
  CMD_SELALL: SelectAllCommand;
  CMD_GLYPHS: OpenGlyphs;
  CMD_TEXTPATH: TextToPathCommand;
  CMD_FONTS: OpenChoice(CH_FONT);
  CMD_FORMATS: OpenChoice(CH_FORMAT);
  CMD_TEXTVIEW: OpenChoice(CH_TEXTVIEW);
  CMD_PJOIN: JoinCommand;
  CMD_PSPLIT: SplitCommand;
  CMD_PCORNER: CornerCommand;
  CMD_PSMOOTH: CurveCommand;
  CMD_PSIMPL: OpenChoice(CH_SIMPLIFY);
  CMD_POFFSET: OpenChoice(CH_OFFSET);
  CMD_FRONT, CMD_BACK, CMD_FORWARD, CMD_BACKWARD: ArrangeObject(Command);
  CMD_RULERS: Begin
   RulersVisible := Not RulersVisible;
   If RulersVisible Then StatusMessage := 'Regles affichees : glisser depuis une regle pour creer un repere.'
   Else StatusMessage := 'Regles masquees.';
  End;
  CMD_GUIDES: Begin
   GuidesVisible := Not GuidesVisible;
   If GuidesVisible Then StatusMessage := 'Reperes affiches.'
   Else StatusMessage := 'Reperes masques.';
  End;
  CMD_CLEAR_GUIDES: Begin
   ClearGuides;
   StatusMessage := 'Reperes effaces.';
  End;
  CMD_ZOOM_IN: ChangeZoom(1,TOOLBAR_WIDTH+(ScreenWidth-TOOLBAR_WIDTH) Div 2,
                          MENUBAR_HEIGHT+(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT) Div 2);
  CMD_ZOOM_OUT: ChangeZoom(-1,TOOLBAR_WIDTH+(ScreenWidth-TOOLBAR_WIDTH) Div 2,
                           MENUBAR_HEIGHT+(ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT) Div 2);
  CMD_ZOOM_RESET: ResetZoom;
  CMD_HELP:
   ShowDialog('Aide', 'CloneDRAW AI : dessin vectoriel inspire d''Adobe Illustrator. Les commandes grisees ne sont pas encore disponibles.');
  CMD_SHORTCUTS:
   ShowDialog('Raccourcis', 'Ctrl+O ouvrir, Ctrl+S enregistrer, Ctrl+Z annuler, Ctrl+Y retablir, Ctrl+X/C/V couper-copier-coller, Ctrl+A tout selectionner, Ctrl+R regles, F10 menus.');
  CMD_ABOUT:
   ShowDialog('A propos', 'CloneDRAW AI - editeur vectoriel ecrit en Pascal (Free Pascal). Ce n''est pas un clone complet d''Adobe Illustrator.');
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
   If TextObject.TextObj.Text <> ObjAt(TextEditIndex)^.TextObj.Text Then Begin
    PushUndo;
    ObjAt(TextEditIndex)^ := TextObject;
    FileModified := True;
   End;
  End Else Begin
   PushUndo;
   AppendObject(TextObject);
   FileModified := True;
  End;
  StatusMessage := 'Texte valide. Fleche : deplacer. Outil Texte : modifier.';
 End;
 TextActive := False;
 NeedsRedraw := True;
End;

Function GuideAt: PGuide;
Var G: PGuide; P: Integer;
Begin
 GuideAt := Nil;
 If Not GuidesVisible Then Exit;
 G := GuideHead;
 While G <> Nil Do Begin
  If G^.Horiz Then Begin
   P := MENUBAR_HEIGHT+ScreenY(G^.Pos);
   If (Abs(MouseY-P) <= 3) And (MouseX >= TOOLBAR_WIDTH+RulerPx) Then GuideAt := G;
  End Else Begin
   P := TOOLBAR_WIDTH+ScreenX(G^.Pos);
   If (Abs(MouseX-P) <= 3) And (MouseY >= MENUBAR_HEIGHT+RulerPx) Then GuideAt := G;
  End;
  G := G^.Next;
 End;
End;

Procedure UpdateGuide;
Var S: String;
Begin
 If GuideCur = Nil Then Exit;
 If GuideCur^.Horiz Then GuideCur^.Pos := DocumentY(MouseY)
 Else GuideCur^.Pos := DocumentX(MouseX);
 Str(GuideCur^.Pos,S);
 If GuideCur^.Horiz Then StatusMessage := 'Repere horizontal : y = '+S
 Else StatusMessage := 'Repere vertical : x = '+S;
 NeedsRedraw := True;
End;

Function TryStartGuide: Boolean;
Var LX, LY: Integer; G: PGuide;
Begin
 TryStartGuide := False;
 If DrawingMode Or EditingObject Or TextActive Or (BezierStage <> 0) Then Exit;
 If (MouseX < TOOLBAR_WIDTH) Or (MouseX >= ScreenWidth) Or
    (MouseY < MENUBAR_HEIGHT) Or (MouseY >= ScreenHeight-STATUSBAR_HEIGHT) Then Exit;
 LX := MouseX-TOOLBAR_WIDTH; LY := MouseY-MENUBAR_HEIGHT;
 If RulersVisible And ((LX < RULER_SIZE) Or (LY < RULER_SIZE)) Then Begin
  TryStartGuide := True;
  If (LX < RULER_SIZE) And (LY < RULER_SIZE) Then Exit;
  New(G);
  G^.Horiz := LY < RULER_SIZE;
  G^.Pos := 0;
  G^.Next := GuideHead;
  GuideHead := G;
  GuideCur := G; GuideNew := True; GuideOldPos := 0;
  GuidesVisible := True;
  GuideDragging := True;
  UpdateGuide;
  Exit;
 End;
 If CurrentTool = TOOL_SELECT Then Begin
  G := GuideAt;
  If G <> Nil Then Begin
   TryStartGuide := True;
   GuideCur := G; GuideNew := False; GuideOldPos := G^.Pos;
   GuideDragging := True;
   UpdateGuide;
  End;
 End;
End;

Procedure EndGuide(Cancel: Boolean);
Var Outside: Boolean;
Begin
 If Not GuideDragging Then Exit;
 GuideDragging := False;
 If GuideCur = Nil Then Exit;
 If Not Cancel Then UpdateGuide;
 If GuideCur^.Horiz Then
  Outside := (MouseY < MENUBAR_HEIGHT+RulerPx) Or (MouseY >= ScreenHeight-STATUSBAR_HEIGHT)
 Else Outside := (MouseX < TOOLBAR_WIDTH+RulerPx) Or (MouseX >= ScreenWidth);
 If Cancel Then Begin
  If GuideNew Then RemoveGuide(GuideCur) Else GuideCur^.Pos := GuideOldPos;
  StatusMessage := 'Repere annule.';
 End Else If Outside Then Begin
  RemoveGuide(GuideCur);
  StatusMessage := 'Repere supprime.';
 End Else StatusMessage := 'Repere place.';
 GuideCur := Nil;
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
 If GlyphActive Then Begin
  If Pressed Then HandleGlyphMouse;
 End Else If ChoiceActive Then Begin
  If Pressed Then HandleChoiceMouse;
 End Else If PropActive Then Begin
  If Pressed Then HandlePropMouse;
 End Else If FileDialogActive Then Begin
  If Pressed Then HandleFileMouse;
 End Else If TextActive Then Begin
  If Pressed Then Begin
   StatusMessage := 'Valider par un clic outil/menu ou Entree ; Echap annule.';
   NeedsRedraw := True;
  End;
 End Else If DialogTitle <> '' Then Begin
  If Pressed Then HandleMessageMouse;
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
    If Not TryStartGuide Then HandleMouseClick;
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
  End Else If MarqueeActive And ((MouseButtons And 1) <> 0) Then Begin
   If (MouseX <> OldMouseX) Or (MouseY <> OldMouseY) Then NeedsRedraw := True;
  End Else If GuideDragging And ((MouseButtons And 1) <> 0) Then Begin
   If (MouseX <> OldMouseX) Or (MouseY <> OldMouseY) Then UpdateGuide;
  End Else If Released Then Begin
   If GuideDragging Then EndGuide(False)
   Else If MenuMouseDown Then Begin
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
 If GlyphActive Then Begin HandleGlyphKey(Key); Exit; End;
 If ChoiceActive Then Begin HandleChoiceKey(Key,ExtKey); Exit; End;
 If PropActive Then Begin HandlePropKey(Key); Exit; End;
 If FileDialogActive Then Begin HandleFileKey(Key,ExtKey); Exit; End;
 If ((Key In [#15,#19]) Or ((Key=#0) And (ExtKey=#134))) And
    Not DrawingMode And (DialogTitle='') Then Begin
  If TextActive Then FinishText(True);
  If Key=#15 Then ExecuteMenuItem(MENU_FILE,1)
  Else If Key=#0 Then ExecuteMenuItem(MENU_FILE,3)
  Else ExecuteMenuItem(MENU_FILE,2);
  Exit;
 End;
 If GuideDragging Then Begin
  If Key = #27 Then EndGuide(True);
  Exit;
 End;
 If MarqueeActive Then Begin
  If Key = #27 Then FinishMarquee(True);
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
  If ObjAt(SelectedObject)^.Visible And
     (ObjAt(SelectedObject)^.ObjType = OBJ_TEXT) And
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
    Capacity := (ScreenWidth-TOOLBAR_WIDTH-Round(TextObject.TextObj.X)) Div (8*TextScaleOf(TextObject));
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
  If Key = #13 Then CloseMessage(True)
  Else If (Key = #27) Or (Key = ' ') Then CloseMessage(False);
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
  #26: UndoCommand;
  #25: RedoCommand;
  #24: CutCommand;
  #3: CopyCommand;
  #22: PasteCommand;
  #18: ExecuteMenuItem(2,4);
  #1: SelectAllCommand;
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
  I := ScreenX(TextObject.TextObj.X+TextCursor*8*TextScaleOf(TextObject));
  Line(I,ScreenY(TextObject.TextObj.Y),I,
       ScreenY(TextObject.TextObj.Y+8*TextScaleOf(TextObject))-1);
 End;
 If PencilActive Then DrawGraphicObject(PencilObject);
 If BezierStage <> 0 Then Begin
  DrawGraphicObject(BezierObject);
  DrawBezierHandles(BezierObject,True);
 End;
 DrawSelection;
 DrawGuides;
 DrawRulers;
 SetViewPort(0,0,ScreenWidth-1,ScreenHeight-1,True);
 DrawToolbar;
 DrawMenuBar;
 DrawStatusBar;
 { Les menus et dialogues doivent etre dessines APRES le document. }
 DrawMenu;
 DrawPropDialog;
 DrawChoice;
 DrawGlyphDialog;
 DrawMessage;
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
 Count, I, Code: Integer; Got: Word; Good: Boolean; Tmp0: TGraphicObject;
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
 Good := Good And (Code=0) And (Got=2) And (Count>=0) And (Count<=30000);
 If Good Then Begin
  Good := FileSize(F)=8+LongInt(Count)*SizeOf(TGraphicObject);
  Code := IOResult;
  Good := Good And (Code=0);
 End;
 {$I+}
 If Good Then
  For I := 0 To Count-1 Do Begin
   {$I-}
   BlockRead(F,Tmp0,SizeOf(TGraphicObject),Got);
   Code := IOResult;
   {$I+}
   If (Code<>0) Or (Got<>SizeOf(TGraphicObject)) Then Good := False
   Else If Not ValidImportObject(Tmp0) Then Good := False
   Else ImpAppend(Tmp0);
   If Not Good Then Break;
  End;
 {$I-} Close(F); Code := IOResult; {$I+}
 If Not Good Or (Code<>0) Then Begin
  ImportError := 'AI10 invalide, tronque ou incompatible avec cette version.';
  Exit;
 End;
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
  Path.ObjType := OBJ_PATH;
  If IsFill Then Path.ObjType := OBJ_FILLED_PATH;
  Path.Path.FillColor := Fill;
  Path.Path.StrokeColor := Stroke;
  If Not IsStroke Then Path.Path.StrokeColor := Fill;
  Path.Path.StrokeWidth := Width;
  ImpAppend(Path);
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
   FillChar(Curve,SizeOf(Curve),0); Curve.ObjType := OBJ_TEXT; Curve.Visible := True;
   Curve.TextObj.X := Path.Path.Points[0].X;
   Curve.TextObj.Y := Path.Path.Points[0].Y-7;
   Curve.TextObj.Text := Header; Curve.TextObj.Color := Stroke; Curve.TextObj.FontSize := 8;
   If Not ValidImportObject(Curve) Then Begin
    Fail('Texte hors de la page ou format non pris en charge.'); Break;
   End;
   ImpAppend(Curve);
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

{ ------------------------------------------------------------------
  Importation des fichiers Illustrator modernes (PDF) et repli tolerant
  pour le PostScript classique : les chemins, remplissages, traits, couleurs
  et textes simples sont lus ; courbes aplaties.
  ------------------------------------------------------------------ }
{$IFDEF FPC}
Const
 LBase:Array[0..28] of Integer=(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258);
 LExt:Array[0..28] of Integer=(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DBase:Array[0..29] of Integer=(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577);
 DExt:Array[0..29] of Integer=(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13);
 CLOrder:Array[0..18] of Integer=(16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);

Type
 TBig = Array[0..1999999999] Of Byte;
 PBig = ^TBig;
 THuff = Record
  Cnt: Array[0..15] Of LongInt;
  Sym: Array[0..287] Of Integer;
 End;
 TLens = Array[0..319] Of Integer;

Var
 InfIn, InfOut: PBig;
 InfInLen, InfInPos, InfOutLen, InfOutPos, InfBuf: LongInt;
 InfCnt: Integer;
 InfBad: Boolean;
 FixedLit, FixedDist: THuff;
 FixedReady: Boolean;

Function InfBits(Need:Integer):LongInt;
Var V:LongInt;
Begin
 V:=InfBuf;
 While InfCnt<Need Do Begin
  If InfInPos>=InfInLen Then Begin
   InfBad:=True;
   InfBits:=0;
   Exit;
  End;
  V:=V Or (LongInt(InfIn^[InfInPos]) Shl InfCnt);
  Inc(InfInPos);
  Inc(InfCnt,8);
 End;
 InfBuf:=V Shr Need;
 Dec(InfCnt,Need);
 InfBits:=V And ((LongInt(1) Shl Need)-1);
End;

Function InfBuild(Var H:THuff;Var L:TLens;Off,N:Integer):LongInt;
Var S,Len:Integer;
    Left:LongInt;
    Offs:Array[0..15] of Integer;
Begin
 For Len:=0 To 15 Do H.Cnt[Len]:=0;
 For S:=0 To N-1 Do Inc(H.Cnt[L[Off+S]]);
 If H.Cnt[0]=N Then Begin
  InfBuild:=0;
  Exit;
 End;
 Left:=1;
 For Len:=1 To 15 Do Begin
  Left:=Left Shl 1;
  Left:=Left-H.Cnt[Len];
  If Left<0 Then Begin
   InfBuild:=Left;
   Exit;
  End;
 End;
 Offs[1]:=0;
 For Len:=1 To 14 Do Offs[Len+1]:=Offs[Len]+H.Cnt[Len];
 For S:=0 To N-1 Do
  If L[Off+S]<>0 Then Begin
   H.Sym[Offs[L[Off+S]]]:=S;
   Inc(Offs[L[Off+S]]);
  End;
 InfBuild:=Left;
End;

Function InfDecode(Var H:THuff):Integer;
Var Code,First,Index,Count:LongInt;
    Len:Integer;
Begin
 Code:=0; First:=0; Index:=0;
 For Len:=1 To 15 Do Begin
  Code:=Code Or InfBits(1);
  If InfBad Then Break;
  Count:=H.Cnt[Len];
  If Code-Count<First Then Begin
   InfDecode:=H.Sym[Index+(Code-First)];
   Exit;
  End;
  Index:=Index+Count;
  First:=(First+Count) Shl 1;
  Code:=Code Shl 1;
 End;
 InfBad:=True;
 InfDecode:=-1;
End;

Procedure InfCodes(Var Lc,Dc:THuff);
Var Sym,Len,Dist:LongInt;
Begin
 Repeat
  Sym:=InfDecode(Lc);
  If InfBad Then Exit;
  If Sym<256 Then Begin
   If InfOutPos>=InfOutLen Then Begin InfBad:=True; Exit; End;
   InfOut^[InfOutPos]:=Sym;
   Inc(InfOutPos);
  End
   Else
  If Sym>256 Then Begin
   Sym:=Sym-257;
   If Sym>=29 Then Begin InfBad:=True; Exit; End;
   Len:=LBase[Sym]+InfBits(LExt[Sym]);
   Sym:=InfDecode(Dc);
   If InfBad or(Sym<0)or(Sym>=30)Then Begin InfBad:=True; Exit; End;
   Dist:=DBase[Sym]+InfBits(DExt[Sym]);
   If InfBad or(Dist>InfOutPos)or(InfOutPos+Len>InfOutLen)Then Begin InfBad:=True; Exit; End;
   While Len>0 Do Begin
    InfOut^[InfOutPos]:=InfOut^[InfOutPos-Dist];
    Inc(InfOutPos);
    Dec(Len);
   End;
  End;
 Until Sym=256;
End;

Procedure InfStored;
Var Len,Nlen:LongInt;
Begin
 InfBuf:=0;
 InfCnt:=0;
 If InfInPos+4>InfInLen Then Begin InfBad:=True; Exit; End;
 Len:=InfIn^[InfInPos]+256*InfIn^[InfInPos+1];
 Nlen:=InfIn^[InfInPos+2]+256*InfIn^[InfInPos+3];
 Inc(InfInPos,4);
 If(Len<>(Not Nlen)And $FFFF)or(InfInPos+Len>InfInLen)or(InfOutPos+Len>InfOutLen)Then Begin
  InfBad:=True;
  Exit;
 End;
 Move(InfIn^[InfInPos],InfOut^[InfOutPos],Len);
 Inc(InfInPos,Len);
 Inc(InfOutPos,Len);
End;

Procedure InfFixed;
Var L:TLens;
    S:Integer;
Begin
 If Not FixedReady Then Begin
  For S:=0 To 143 Do L[S]:=8;
  For S:=144 To 255 Do L[S]:=9;
  For S:=256 To 279 Do L[S]:=7;
  For S:=280 To 287 Do L[S]:=8;
  InfBuild(FixedLit,L,0,288);
  For S:=0 To 29 Do L[S]:=5;
  InfBuild(FixedDist,L,0,30);
  FixedReady:=True;
 End;
 InfCodes(FixedLit,FixedDist);
End;

Procedure InfDynamic;
Var Nlen,Ndist,Ncode,Idx,Sym,Rep,Prev,I:Integer;
    L:TLens;
    Lc,Dc:THuff;
    Err:LongInt;
Begin
 Nlen:=InfBits(5)+257;
 Ndist:=InfBits(5)+1;
 Ncode:=InfBits(4)+4;
 If InfBad or(Nlen>286)or(Ndist>30)Then Begin InfBad:=True; Exit; End;
 FillChar(L,SizeOf(L),0);
 For Idx:=0 To Ncode-1 Do L[CLOrder[Idx]]:=InfBits(3);
 Err:=InfBuild(Lc,L,0,19);
 If InfBad or(Err<>0)Then Begin InfBad:=True; Exit; End;
 Idx:=0;
 FillChar(L,SizeOf(L),0);
 While Idx<Nlen+Ndist Do Begin
  Sym:=InfDecode(Lc);
  If InfBad Then Exit;
  If Sym<16 Then Begin
   L[Idx]:=Sym;
   Inc(Idx);
  End
   Else Begin
    Prev:=0;
    If Sym=16 Then Begin
     If Idx=0 Then Begin InfBad:=True; Exit; End;
     Prev:=L[Idx-1];
     Rep:=3+InfBits(2);
    End
     Else
    If Sym=17 Then Rep:=3+InfBits(3)
     Else Rep:=11+InfBits(7);
    If Idx+Rep>Nlen+Ndist Then Begin InfBad:=True; Exit; End;
    For I:=1 To Rep Do Begin
     L[Idx]:=Prev;
     Inc(Idx);
    End;
   End;
 End;
 Err:=InfBuild(Lc,L,0,Nlen);
 If(Err<0)or((Err>0)and(Nlen-Lc.Cnt[0]<>1))Then Begin InfBad:=True; Exit; End;
 Err:=InfBuild(Dc,L,Nlen,Ndist);
 If(Err<0)or((Err>0)and(Ndist-Dc.Cnt[0]<>1))Then Begin InfBad:=True; Exit; End;
 InfCodes(Lc,Dc);
End;

{ Decompresse un flux zlib (2 octets d'en-tete + deflate) }
Function Inflate(Src:PBig;SrcLen:LongInt;Dst:PBig;DstLen:LongInt):Boolean;
Var Last,Typ:LongInt;
Begin
 InfIn:=Src;
 InfInLen:=SrcLen;
 InfInPos:=2;
 InfOut:=Dst;
 InfOutLen:=DstLen;
 InfOutPos:=0;
 InfBuf:=0;
 InfCnt:=0;
 InfBad:=False;
 If SrcLen<3 Then Begin
  Inflate:=False;
  Exit;
 End;
 Repeat
  Last:=InfBits(1);
  Typ:=InfBits(2);
  If InfBad Then Break;
  Case Typ Of
   0:InfStored;
   1:InfFixed;
   2:InfDynamic;
  Else InfBad:=True;
  End;
 Until(Last=1)or InfBad;
 Inflate:=Not InfBad;
End;

Const
 PA_MAXOBJ = 30000;
 PA_MAXPTS = 40000;
 PA_MAXSUB = 400;

Var
 PaBuf: PBig;
 PaLen: LongInt;
 PaOff: Array[1..PA_MAXOBJ] Of LongInt;
 PaSrc: Array[1..PA_MAXOBJ] Of Byte;
 PaXBuf: Array[1..12] Of PBig;
 PaXLen: Array[1..12] Of LongInt;
 PaXN: Integer;
 PaObjMax: LongInt;
 { etat de l'interprete }
 PaCB: PBig;                 { flux en cours d'interpretation }
 PaCP, PaCE: LongInt;
 PaStk: Array[0..63] Of Real;
 PaSN: Integer;
 PaStr, PaArr: String;
 PaInArr: Boolean;
 PaA, PaB, PaC, PaD, PaE, PaF: Real;           { matrice courante }
 PaGS: Array[0..31] Of Record
  A, B, C, D, E, F, LW: Real;
  Fi, St: Byte;
 End;
 PaGSP: Integer;
 PaFill, PaStroke: Byte;
 PaLW: Real;
 PaX0, PaY1, PaSc: Real;    { page -> document }
 PaPX, PaPY: Array[0..PA_MAXPTS-1] Of Real;   { points aplatis (page) }
 PaPN: LongInt;
 PaSub: Array[0..PA_MAXSUB] Of LongInt;
 PaSubCl: Array[0..PA_MAXSUB] Of Boolean;
 PaSubN: Integer;
 PaCurX, PaCurY, PaStX, PaStY: Real;
 PaTM, PaLM: Array[0..5] Of Real;             { matrice de texte et de debut de ligne }
 PaLead: Real;
 PaFS: Real;
 PaFull: Boolean;
 PaIsPdf: Boolean;
 PaDepth: Integer;
 PaRes: LongInt;            { dictionnaire de ressources courant : objet ou -1 }
 PaResSrc: Byte;
 PaResPos: LongInt;
 PaTruncated: Boolean;

Function PaByte(S: PBig; P, L: LongInt): Integer;
Begin
 If (P < 0) Or (P >= L) Then PaByte := 0 Else PaByte := S^[P];
End;

Function PaIsWs(C: Integer): Boolean;
Begin
 PaIsWs := (C = 32) Or (C = 9) Or (C = 10) Or (C = 13) Or (C = 12) Or (C = 0);
End;

Function PaIsDelim(C: Integer): Boolean;
Begin
 PaIsDelim := PaIsWs(C) Or (C = Ord('(')) Or (C = Ord(')')) Or (C = Ord('<')) Or
  (C = Ord('>')) Or (C = Ord('[')) Or (C = Ord(']')) Or (C = Ord('{')) Or
  (C = Ord('}')) Or (C = Ord('/')) Or (C = Ord('%'));
End;

{ ------------------------- analyse des objets ------------------------- }

Function PaSrcBuf(Src: Byte): PBig;
Begin
 If Src = 0 Then PaSrcBuf := PaBuf Else PaSrcBuf := PaXBuf[Src];
End;

Function PaSrcLen(Src: Byte): LongInt;
Begin
 If Src = 0 Then PaSrcLen := PaLen Else PaSrcLen := PaXLen[Src];
End;

Function PaSkip(S: PBig; P, L: LongInt): LongInt;
Begin
 While P < L Do Begin
  If PaIsWs(S^[P]) Then Inc(P)
  Else If S^[P] = Ord('%') Then Begin
   While (P < L) And (S^[P] <> 10) And (S^[P] <> 13) Do Inc(P);
  End Else Break;
 End;
 PaSkip := P;
End;

{ Jeton : K = 1 nombre, 2 nom, 3 '<<', 4 '>>', 5 '[', 6 ']', 7 chaine, 8 mot, 0 fin }
Function PaTok(S: PBig; Var P: LongInt; L: LongInt; Var A, B: LongInt): Integer;
Var C, D: Integer;
Begin
 PaTok := 0;
 P := PaSkip(S, P, L);
 If P >= L Then Exit;
 C := S^[P];
 A := P;
 If C = Ord('/') Then Begin
  Inc(P);
  A := P;
  While (P < L) And Not PaIsDelim(S^[P]) Do Inc(P);
  B := P; PaTok := 2; Exit;
 End;
 If (C = Ord('<')) And (PaByte(S, P+1, L) = Ord('<')) Then Begin
  Inc(P, 2); B := P; PaTok := 3; Exit;
 End;
 If (C = Ord('>')) And (PaByte(S, P+1, L) = Ord('>')) Then Begin
  Inc(P, 2); B := P; PaTok := 4; Exit;
 End;
 If C = Ord('[') Then Begin Inc(P); B := P; PaTok := 5; Exit; End;
 If C = Ord(']') Then Begin Inc(P); B := P; PaTok := 6; Exit; End;
 If C = Ord('(') Then Begin
  D := 1; Inc(P);
  While (P < L) And (D > 0) Do Begin
   If S^[P] = Ord('\') Then Inc(P)
   Else If S^[P] = Ord('(') Then Inc(D)
   Else If S^[P] = Ord(')') Then Dec(D);
   Inc(P);
  End;
  B := P; PaTok := 7; Exit;
 End;
 If C = Ord('<') Then Begin
  While (P < L) And (S^[P] <> Ord('>')) Do Inc(P);
  Inc(P); B := P; PaTok := 7; Exit;
 End;
 If (C = Ord('>')) Or (C = Ord(')')) Or (C = Ord('{')) Or (C = Ord('}')) Then Begin
  Inc(P); B := P; PaTok := 8; Exit;
 End;
 While (P < L) And Not PaIsDelim(S^[P]) Do Inc(P);
 B := P;
 If P = A Then Begin Inc(P); B := P; End;
 C := S^[A];
 If ((C >= Ord('0')) And (C <= Ord('9'))) Or (C = Ord('-')) Or (C = Ord('+')) Or (C = Ord('.')) Then
  PaTok := 1
 Else PaTok := 8;
End;

Function PaNum(S: PBig; A, B: LongInt): LongInt;
Var V: LongInt;
Begin
 V := 0;
 While (A < B) And (S^[A] >= Ord('0')) And (S^[A] <= Ord('9')) Do Begin
  V := V*10+S^[A]-Ord('0');
  Inc(A);
 End;
 PaNum := V;
End;

{ La valeur en P est-elle une reference "N G R" ? }
Function PaIsRef(S: PBig; P, L: LongInt; Var N: LongInt): Boolean;
Var Q, A, B, A2, B2, A3, B3: LongInt;
Begin
 PaIsRef := False;
 Q := P;
 If PaTok(S, Q, L, A, B) <> 1 Then Exit;
 If PaTok(S, Q, L, A2, B2) <> 1 Then Exit;
 If (PaTok(S, Q, L, A3, B3) <> 8) Or (B3-A3 <> 1) Or (S^[A3] <> Ord('R')) Then Exit;
 N := PaNum(S, A, B);
 PaIsRef := True;
End;

{ Saute une valeur complete en P (nombre, nom, dictionnaire, tableau, reference) }
Procedure PaSkipValue(S: PBig; Var P, L: LongInt);
Var K, A, B, D, Q, N: LongInt;
Begin
 If PaIsRef(S, P, L, N) Then Begin
  K := PaTok(S, P, L, A, B); K := PaTok(S, P, L, A, B); K := PaTok(S, P, L, A, B);
  Exit;
 End;
 K := PaTok(S, P, L, A, B);
 If (K = 3) Or (K = 5) Then Begin
  D := 1;
  While (D > 0) And (P < L) Do Begin
   K := PaTok(S, P, L, A, B);
   If K = 0 Then Break;
   If (K = 3) Or (K = 5) Then Inc(D)
   Else If (K = 4) Or (K = 6) Then Dec(D);
  End;
 End;
 Q := 0;
End;

{ Position de la valeur de la cle Key dans le dictionnaire commencant en P ('<<') }
Function PaDictFind(S: PBig; P, L: LongInt; Key: String): LongInt;
Var K, A, B, I: LongInt; Same: Boolean;
Begin
 PaDictFind := -1;
 P := PaSkip(S, P, L);
 If PaTok(S, P, L, A, B) <> 3 Then Exit;
 While P < L Do Begin
  K := PaTok(S, P, L, A, B);
  If (K = 4) Or (K = 0) Then Exit;
  If K <> 2 Then Continue;
  Same := (B-A = Length(Key));
  If Same Then
   For I := 1 To Length(Key) Do
    If S^[A+I-1] <> Ord(Key[I]) Then Same := False;
  If Same Then Begin
   PaDictFind := PaSkip(S, P, L);
   Exit;
  End;
  PaSkipValue(S, P, L);
 End;
End;

{ Le nom en P est-il egal a Name ? }
Function PaNameIs(S: PBig; P, L: LongInt; Name: String): Boolean;
Var K, A, B, I: LongInt; Same: Boolean;
Begin
 PaNameIs := False;
 If P < 0 Then Exit;
 If PaTok(S, P, L, A, B) <> 2 Then Exit;
 Same := (B-A = Length(Name));
 If Same Then
  For I := 1 To Length(Name) Do
   If S^[A+I-1] <> Ord(Name[I]) Then Same := False;
 PaNameIs := Same;
 K := 0;
End;

Procedure PaScanObjects;
Var I, N, G, J: LongInt;
Begin
 PaObjMax := 0;
 I := 0;
 While I < PaLen-6 Do Begin
  If (PaBuf^[I] >= Ord('0')) And (PaBuf^[I] <= Ord('9')) And
     ((I = 0) Or PaIsWs(PaBuf^[I-1])) Then Begin
   J := I; N := 0;
   While (J < PaLen) And (PaBuf^[J] >= Ord('0')) And (PaBuf^[J] <= Ord('9')) And (J-I < 9) Do Begin
    N := N*10+PaBuf^[J]-Ord('0'); Inc(J);
   End;
   If (J < PaLen) And (PaBuf^[J] = 32) Then Begin
    Inc(J);
    G := 0;
    While (J < PaLen) And (PaBuf^[J] >= Ord('0')) And (PaBuf^[J] <= Ord('9')) And (G < 100000) Do Begin
     G := G*10+PaBuf^[J]-Ord('0'); Inc(J);
    End;
    If (J+3 < PaLen) And (PaBuf^[J] = 32) And (PaBuf^[J+1] = Ord('o')) And
       (PaBuf^[J+2] = Ord('b')) And (PaBuf^[J+3] = Ord('j')) And
       (N >= 1) And (N <= PA_MAXOBJ) Then Begin
     PaOff[N] := J+4;
     PaSrc[N] := 0;
     If N > PaObjMax Then PaObjMax := N;
     I := J+4;
     Continue;
    End;
   End;
  End;
  Inc(I);
 End;
End;

{ Debut de la valeur d'un objet : (S,P,L) ; faux si l'objet n'existe pas }
Function PaBody(N: LongInt; Var S: PBig; Var P, L: LongInt): Boolean;
Begin
 PaBody := False;
 If (N < 1) Or (N > PaObjMax) Or (PaOff[N] = 0) Then Exit;
 S := PaSrcBuf(PaSrc[N]);
 L := PaSrcLen(PaSrc[N]);
 P := PaSkip(S, PaOff[N], L);
 PaBody := True;
End;

{ Suit une reference eventuelle : retourne le debut de la vraie valeur }
Function PaDeref(Var S: PBig; Var P, L: LongInt): Boolean;
Var N: LongInt; Guard: Integer;
Begin
 PaDeref := False;
 Guard := 0;
 While PaIsRef(S, P, L, N) And (Guard < 8) Do Begin
  If Not PaBody(N, S, P, L) Then Exit;
  Inc(Guard);
 End;
 PaDeref := P >= 0;
End;

{ Donnees decodees du flux de l'objet N (GetMem ; a liberer avec FreeMem(D,DL+16)) }
Function PaStream(N: LongInt; Var D: PBig; Var DL: LongInt): Boolean;
Var S: PBig; P, L, Q, A, B, Len, K, Start, E, Cap: LongInt;
    FV, Flate, Other: Boolean; Src: PBig; Ok: Boolean; T: LongInt;
Begin
 PaStream := False;
 D := Nil; DL := 0;
 If Not PaBody(N, S, P, L) Then Exit;
 Q := P;
 FV := False;
 If PaTok(S, Q, L, A, B) <> 3 Then Exit;
 Q := P;
 Len := -1;
 K := PaDictFind(S, P, L, 'Length');
 If K >= 0 Then Begin
  If PaIsRef(S, K, L, T) Then Begin
   If PaBody(T, Src, A, B) Then Begin
    Q := A;
    Len := 0;
    While (Q < B) And (Src^[Q] >= Ord('0')) And (Src^[Q] <= Ord('9')) Do Begin
     Len := Len*10+Src^[Q]-Ord('0'); Inc(Q);
    End;
   End;
  End Else Begin
   Len := 0; Q := K;
   While (Q < L) And (S^[Q] >= Ord('0')) And (S^[Q] <= Ord('9')) Do Begin
    Len := Len*10+S^[Q]-Ord('0'); Inc(Q);
   End;
  End;
 End;
 { fin du dictionnaire puis mot-cle stream }
 Q := P;
 PaSkipValue(S, Q, L);
 Q := PaSkip(S, Q, L);
 If Not ((Q+5 < L) And (S^[Q] = Ord('s')) And (S^[Q+1] = Ord('t')) And
         (S^[Q+2] = Ord('r')) And (S^[Q+3] = Ord('e')) And (S^[Q+4] = Ord('a')) And
         (S^[Q+5] = Ord('m'))) Then Exit;
 Start := Q+6;
 If PaByte(S, Start, L) = 13 Then Inc(Start);
 If PaByte(S, Start, L) = 10 Then Inc(Start);
 { verification de Length, sinon recherche de endstream }
 E := -1;
 If (Len >= 0) And (Start+Len <= L) Then Begin
  Q := Start+Len;
  While (Q < L) And (Q < Start+Len+4) And PaIsWs(S^[Q]) Do Inc(Q);
  If (Q+8 < L) And (S^[Q] = Ord('e')) And (S^[Q+1] = Ord('n')) And (S^[Q+2] = Ord('d')) And
     (S^[Q+3] = Ord('s')) Then E := Start+Len;
 End;
 If E < 0 Then Begin
  Q := Start;
  While Q+9 < L Do Begin
   If (S^[Q] = Ord('e')) And (S^[Q+1] = Ord('n')) And (S^[Q+2] = Ord('d')) And
      (S^[Q+3] = Ord('s')) And (S^[Q+4] = Ord('t')) And (S^[Q+5] = Ord('r')) Then Begin
    E := Q;
    If (E > Start) And (S^[E-1] = 10) Then Dec(E);
    If (E > Start) And (S^[E-1] = 13) Then Dec(E);
    Break;
   End;
   Inc(Q);
  End;
 End;
 If E < Start Then Exit;
 { filtres }
 Flate := False; Other := False;
 K := PaDictFind(S, P, L, 'Filter');
 If K >= 0 Then Begin
  Q := K;
  If PaTok(S, Q, L, A, B) = 5 Then Begin
   Repeat
    T := PaTok(S, Q, L, A, B);
    If T = 2 Then Begin
     If (B-A = 11) And (S^[A] = Ord('F')) Then Flate := True Else Other := True;
    End;
   Until (T <> 2);
  End Else Begin
   Q := K;
   If PaNameIs(S, Q, L, 'FlateDecode') Then Flate := True Else Other := True;
  End;
 End;
 If Other Then Exit;
 If Flate Then Begin
  If PaDictFind(S, P, L, 'DecodeParms') >= 0 Then Begin
   { predicteur : non pris en charge pour les contenus }
   K := PaDictFind(S, P, L, 'DecodeParms');
   Q := K;
   If PaDictFind(S, K, L, 'Predictor') >= 0 Then Exit;
  End;
  Cap := (E-Start)*40+4096;
  If Cap > 48000000 Then Cap := 48000000;
  GetMem(D, Cap+16);
  Ok := Inflate(PBig(@S^[Start]), E-Start, D, Cap);
  DL := InfOutPos;
  If DL <= 0 Then Begin FreeMem(D, Cap+16); D := Nil; Exit; End;
  If Ok Or (DL > 0) Then Begin
   { reduit a la taille utile }
   PaStream := True;
   D^[DL] := 0;
   Exit;
  End;
 End Else Begin
  DL := E-Start;
  GetMem(D, DL+16);
  Move(S^[Start], D^, DL);
  D^[DL] := 0;
  PaStream := True;
 End;
End;

Procedure PaFreeStream(D: PBig; DL: LongInt);
Begin
 If D <> Nil Then FreeMem(D, DL+16);
End;

{ Les objets contenus dans un flux d'objets (/Type /ObjStm) deviennent accessibles }
Procedure PaLoadObjStreams;
Var N, P, L, K, A, B, T, Cnt, First, I, Num, Off: LongInt;
    S, D: PBig; DL: LongInt; Q: LongInt;
Begin
 For N := 1 To PaObjMax Do
  If (PaOff[N] <> 0) And (PaSrc[N] = 0) Then Begin
   If Not PaBody(N, S, P, L) Then Continue;
   If PaByte(S, P, L) <> Ord('<') Then Continue;
   K := PaDictFind(S, P, L, 'Type');
   If Not PaNameIs(S, K, L, 'ObjStm') Then Continue;
   If PaXN >= 12 Then Break;
   K := PaDictFind(S, P, L, 'N');
   If K < 0 Then Continue;
   Q := K; T := PaTok(S, Q, L, A, B); Cnt := PaNum(S, A, B);
   K := PaDictFind(S, P, L, 'First');
   If K < 0 Then Continue;
   Q := K; T := PaTok(S, Q, L, A, B); First := PaNum(S, A, B);
   If Not PaStream(N, D, DL) Then Continue;
   Inc(PaXN);
   PaXBuf[PaXN] := D;
   PaXLen[PaXN] := DL;
   Q := 0;
   For I := 1 To Cnt Do Begin
    T := PaTok(D, Q, DL, A, B); Num := PaNum(D, A, B);
    T := PaTok(D, Q, DL, A, B); Off := PaNum(D, A, B);
    If (Num >= 1) And (Num <= PA_MAXOBJ) Then Begin
     PaOff[Num] := First+Off;
     PaSrc[Num] := PaXN;
     If Num > PaObjMax Then PaObjMax := Num;
    End;
   End;
  End;
End;

{ ------------------------- interprete graphique ------------------------- }

Function PaNext(Var Tok: String): Integer;
Var C, D, H, N: LongInt; V: Real; Cd: Integer;
 Function HexV(Ch: Integer): Integer;
 Begin
  If (Ch >= 48) And (Ch <= 57) Then HexV := Ch-48
  Else If (Ch >= 65) And (Ch <= 70) Then HexV := Ch-55
  Else If (Ch >= 97) And (Ch <= 102) Then HexV := Ch-87
  Else HexV := -1;
 End;
Begin
 Tok := '';
 PaNext := 0;
 While PaCP < PaCE Do Begin
  C := PaCB^[PaCP];
  If C <= 32 Then Begin Inc(PaCP); Continue; End;
  If C = Ord('%') Then Begin
   While (PaCP < PaCE) And (PaCB^[PaCP] <> 10) And (PaCB^[PaCP] <> 13) Do Inc(PaCP);
   Continue;
  End;
  If C = Ord('(') Then Begin
   Inc(PaCP); D := 1;
   While (PaCP < PaCE) And (D > 0) Do Begin
    C := PaCB^[PaCP]; Inc(PaCP);
    If C = Ord('\') Then Begin
     C := PaCB^[PaCP]; Inc(PaCP);
     If C = Ord('n') Then C := 10
     Else If C = Ord('r') Then C := 13
     Else If C = Ord('t') Then C := 9
     Else If (C >= 48) And (C <= 55) Then Begin
      N := C-48; H := 0;
      While (H < 2) And (PaCB^[PaCP] >= 48) And (PaCB^[PaCP] <= 55) Do Begin
       N := N*8+PaCB^[PaCP]-48; Inc(PaCP); Inc(H);
      End;
      C := N And 255;
     End;
     If Length(Tok) < 255 Then Tok := Tok+Chr(C);
    End Else Begin
     If C = Ord('(') Then Inc(D);
     If C = Ord(')') Then Dec(D);
     If (D > 0) And (Length(Tok) < 255) Then Tok := Tok+Chr(C);
    End;
   End;
   PaNext := 3; Exit;
  End;
  If C = Ord('<') Then Begin
   If PaCB^[PaCP+1] = Ord('<') Then Begin
    D := 0;
    While PaCP < PaCE Do Begin
     If (PaCB^[PaCP] = Ord('<')) And (PaCB^[PaCP+1] = Ord('<')) Then Begin Inc(D); Inc(PaCP, 2); End
     Else If (PaCB^[PaCP] = Ord('>')) And (PaCB^[PaCP+1] = Ord('>')) Then Begin
      Dec(D); Inc(PaCP, 2); If D <= 0 Then Break;
     End Else Inc(PaCP);
    End;
    Continue;
   End;
   Inc(PaCP); H := -1;
   While (PaCP < PaCE) And (PaCB^[PaCP] <> Ord('>')) Do Begin
    N := HexV(PaCB^[PaCP]);
    If N >= 0 Then Begin
     If H < 0 Then H := N Else Begin
      If Length(Tok) < 255 Then Tok := Tok+Chr(H*16+N);
      H := -1;
     End;
    End;
    Inc(PaCP);
   End;
   Inc(PaCP);
   PaNext := 3; Exit;
  End;
  If (C = Ord('[')) Or (C = Ord(']')) Then Begin
   Tok := Chr(C); Inc(PaCP); PaNext := 4; Exit;
  End;
  If (C = Ord('{')) Or (C = Ord('}')) Or (C = Ord(')')) Or (C = Ord('>')) Then Begin
   Inc(PaCP); Continue;
  End;
  If C = Ord('/') Then Begin
   Inc(PaCP); Tok := '/';
   While (PaCP < PaCE) And Not PaIsDelim(PaCB^[PaCP]) Do Begin
    If Length(Tok) < 60 Then Tok := Tok+Chr(PaCB^[PaCP]);
    Inc(PaCP);
   End;
   PaNext := 6; Exit;
  End;
  While (PaCP < PaCE) And Not PaIsDelim(PaCB^[PaCP]) Do Begin
   If Length(Tok) < 60 Then Tok := Tok+Chr(PaCB^[PaCP]);
   Inc(PaCP);
  End;
  If Tok = '' Then Begin Inc(PaCP); Continue; End;
  If Tok[1] = '.' Then Tok := '0'+Tok;
  If (Length(Tok) > 1) And (Tok[1] = '-') And (Tok[2] = '.') Then Tok := '-0'+Copy(Tok, 2, 60);
  If Tok[1] In ['0'..'9','-','+'] Then Begin
   Val(Tok, V, Cd);
   If Cd = 0 Then Begin PaNext := 1; Exit; End;
  End;
  PaNext := 2; Exit;
 End;
End;

Function PaArg(I: Integer): Real;
Begin
 If PaSN-I >= 0 Then PaArg := PaStk[PaSN-I] Else PaArg := 0;
End;

Procedure PaConcat(MA, MB, MC, MD, ME, MF: Real);
Var A, B, C, D, E, F: Real;
Begin
 A := MA*PaA+MB*PaC; B := MA*PaB+MB*PaD;
 C := MC*PaA+MD*PaC; D := MC*PaB+MD*PaD;
 E := ME*PaA+MF*PaC+PaE; F := ME*PaB+MF*PaD+PaF;
 PaA := A; PaB := B; PaC := C; PaD := D; PaE := E; PaF := F;
End;

{ page -> document : point (X,Y) du plan utilisateur }
Procedure PaMap(X, Y: Real; Var DX, DY: Real);
Var XP, YP: Real;
Begin
 XP := PaA*X+PaC*Y+PaE;
 YP := PaB*X+PaD*Y+PaF;
 DX := XP; DY := YP;
End;

Procedure PaPMove(X, Y: Real);
Begin
 If (PaSubN < PA_MAXSUB) And (PaPN < PA_MAXPTS) Then Begin
  PaSub[PaSubN] := PaPN;
  PaSubCl[PaSubN] := False;
  Inc(PaSubN);
  PaMap(X, Y, PaPX[PaPN], PaPY[PaPN]);
  Inc(PaPN);
 End;
 PaCurX := X; PaCurY := Y; PaStX := X; PaStY := Y;
End;

Procedure PaPLine(X, Y: Real);
Begin
 If PaSubN = 0 Then Begin PaPMove(X, Y); Exit; End;
 If PaPN < PA_MAXPTS Then Begin
  PaMap(X, Y, PaPX[PaPN], PaPY[PaPN]);
  Inc(PaPN);
 End;
 PaCurX := X; PaCurY := Y;
End;

Procedure PaPCurve(X1, Y1, X2, Y2, X3, Y3: Real);
Var I: Integer; T, U, AX, AY: Real; P0X, P0Y, A1X, A1Y, A2X, A2Y, A3X, A3Y: Real;
Begin
 If PaSubN = 0 Then PaPMove(X1, Y1);
 P0X := PaPX[PaPN-1]; P0Y := PaPY[PaPN-1];
 PaMap(X1, Y1, A1X, A1Y); PaMap(X2, Y2, A2X, A2Y); PaMap(X3, Y3, A3X, A3Y);
 For I := 1 To 10 Do Begin
  T := I/10; U := 1-T;
  If PaPN < PA_MAXPTS Then Begin
   PaPX[PaPN] := U*U*U*P0X+3*U*U*T*A1X+3*U*T*T*A2X+T*T*T*A3X;
   PaPY[PaPN] := U*U*U*P0Y+3*U*U*T*A1Y+3*U*T*T*A2Y+T*T*T*A3Y;
   Inc(PaPN);
  End;
 End;
 PaCurX := X3; PaCurY := Y3;
 AX := 0; AY := 0;
End;

Procedure PaPClose;
Begin
 If PaSubN = 0 Then Exit;
 PaSubCl[PaSubN-1] := True;
 PaCurX := PaStX; PaCurY := PaStY;
End;

Procedure PaPClear;
Begin
 PaPN := 0; PaSubN := 0;
End;

Procedure PaAdd(Var O: TGraphicObject);
Begin
 ImpAppend(O);
End;

Function PaDocX(X: Real): Real;
Var V: Real;
Begin
 V := (X-PaX0)*PaSc;
 If V < 0 Then V := 0;
 If V > ScreenWidth-TOOLBAR_WIDTH-2 Then V := ScreenWidth-TOOLBAR_WIDTH-2;
 PaDocX := V;
End;

Function PaDocY(Y: Real): Real;
Var V: Real;
Begin
 V := (PaY1-Y)*PaSc;
 If V < 0 Then V := 0;
 If V > ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-2 Then
  V := ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-2;
 PaDocY := V;
End;

Procedure PaPaint(DoFill, DoStroke: Boolean);
Var S, I, K, N, E: LongInt; O: TGraphicObject; Step: Real; W: Real;
Begin
 For S := 0 To PaSubN-1 Do Begin
  If S+1 < PaSubN Then E := PaSub[S+1]-1 Else E := PaPN-1;
  N := E-PaSub[S]+1;
  If N < 2 Then Continue;
  FillChar(O, SizeOf(O), 0);
  O.Visible := True;
  O.LayerIndex := 0;
  If DoFill And (N >= 3) Then O.ObjType := OBJ_FILLED_PATH Else O.ObjType := OBJ_PATH;
  If O.ObjType = OBJ_PATH Then DoStroke := True;
  If N > 99 Then Begin
   For K := 0 To 98 Do Begin
    I := PaSub[S]+(K*(N-1)) Div 98;
    O.Path.Points[K].X := PaDocX(PaPX[I]);
    O.Path.Points[K].Y := PaDocY(PaPY[I]);
   End;
   O.Path.PointCount := 99;
  End Else Begin
   For K := 0 To N-1 Do Begin
    O.Path.Points[K].X := PaDocX(PaPX[PaSub[S]+K]);
    O.Path.Points[K].Y := PaDocY(PaPY[PaSub[S]+K]);
   End;
   O.Path.PointCount := N;
  End;
  O.Path.Closed := PaSubCl[S] Or (O.ObjType = OBJ_FILLED_PATH);
  O.Path.FillColor := PaFill;
  If DoStroke Then O.Path.StrokeColor := PaStroke Else O.Path.StrokeColor := PaFill;
  W := PaLW*PaSc*Sqrt(Abs(PaA*PaD-PaB*PaC));
  If W < 1 Then W := 1;
  If W > 12 Then W := 12;
  O.Path.StrokeWidth := W;
  PaAdd(O);
 End;
End;

Procedure PaShowText(Const T: String);
Var O: TGraphicObject; X, Y: Real; I: Integer; S: String;
Begin
 S := '';
 For I := 1 To Length(T) Do
  If (T[I] >= #32) And (Length(S) < 255) Then S := S+T[I];
 If S = '' Then Exit;
 PaMap(PaTM[4], PaTM[5], X, Y);
 FillChar(O, SizeOf(O), 0);
 O.ObjType := OBJ_TEXT;
 O.Visible := True;
 O.TextObj.X := PaDocX(X);
 O.TextObj.Y := PaDocY(Y)-7;
 If O.TextObj.Y < 0 Then O.TextObj.Y := 0;
 O.TextObj.Text := S;
 O.TextObj.Color := PaFill;
 O.TextObj.FontSize := 8;
 PaAdd(O);
 PaTM[4] := PaTM[4]+Length(S)*PaFS*0.55*PaTM[0];
End;

Procedure PaGSave;
Begin
 If PaGSP < 32 Then Begin
  PaGS[PaGSP].A := PaA; PaGS[PaGSP].B := PaB; PaGS[PaGSP].C := PaC; PaGS[PaGSP].D := PaD;
  PaGS[PaGSP].E := PaE; PaGS[PaGSP].F := PaF; PaGS[PaGSP].LW := PaLW;
  PaGS[PaGSP].Fi := PaFill; PaGS[PaGSP].St := PaStroke;
  Inc(PaGSP);
 End;
End;

Procedure PaGRestore;
Begin
 If PaGSP > 0 Then Begin
  Dec(PaGSP);
  PaA := PaGS[PaGSP].A; PaB := PaGS[PaGSP].B; PaC := PaGS[PaGSP].C; PaD := PaGS[PaGSP].D;
  PaE := PaGS[PaGSP].E; PaF := PaGS[PaGSP].F; PaLW := PaGS[PaGSP].LW;
  PaFill := PaGS[PaGSP].Fi; PaStroke := PaGS[PaGSP].St;
 End;
End;

Function PaCmyk(C, M, Y, K: Real): Byte;
Begin
 PaCmyk := ImportPaletteColor(1-MinReal(1, C+K), 1-MinReal(1, M+K), 1-MinReal(1, Y+K));
End;

Procedure PaRunStream(D: PBig; DL: LongInt; ResS: Byte; ResP: LongInt); Forward;

{ Execute le formulaire XObject Name (ressource courante) }
Procedure PaDo(Const Name: String);
Var S: PBig; P, L, K, N, A, B, Q: LongInt; D: PBig; DL: LongInt;
    SA, SB, SC, SD, SE, SF: Real; Mat: Array[0..5] Of Real; T, I: Integer;
    FS: PBig; FP, FL: LongInt; RP: LongInt; RS: Byte;
Begin
 If (PaDepth > 6) Or (PaResPos < 0) Then Exit;
 S := PaSrcBuf(PaResSrc); L := PaSrcLen(PaResSrc);
 P := PaDictFind(S, PaResPos, L, 'XObject');
 If P < 0 Then Exit;
 If Not PaDeref(S, P, L) Then Exit;
 { cle = Name }
 K := PaDictFind(S, P, L, Copy(Name, 2, 60));
 If K < 0 Then Exit;
 If Not PaIsRef(S, K, L, N) Then Exit;
 If Not PaBody(N, FS, FP, FL) Then Exit;
 K := PaDictFind(FS, FP, FL, 'Subtype');
 If Not PaNameIs(FS, K, FL, 'Form') Then Exit;
 For I := 0 To 5 Do Mat[I] := 0;
 Mat[0] := 1; Mat[3] := 1;
 K := PaDictFind(FS, FP, FL, 'Matrix');
 If K >= 0 Then Begin
  Q := K;
  If PaTok(FS, Q, FL, A, B) = 5 Then
   For I := 0 To 5 Do Begin
    T := PaTok(FS, Q, FL, A, B);
    If T = 1 Then Mat[I] := PaNum(FS, A, B) * 1.0;
   End;
 End;
 If Not PaStream(N, D, DL) Then Exit;
 SA := PaA; SB := PaB; SC := PaC; SD := PaD; SE := PaE; SF := PaF;
 PaConcat(Mat[0], Mat[1], Mat[2], Mat[3], Mat[4], Mat[5]);
 RS := PaResSrc; RP := PaResPos;
 K := PaDictFind(FS, FP, FL, 'Resources');
 If K >= 0 Then Begin
  S := FS; P := K; L := FL;
  If PaDeref(S, P, L) Then Begin
   If S = PaBuf Then PaResSrc := 0 Else Begin
    PaResSrc := 0;
    For I := 1 To PaXN Do If S = PaXBuf[I] Then PaResSrc := I;
   End;
   PaResPos := P;
  End;
 End;
 Inc(PaDepth);
 PaRunStream(D, DL, PaResSrc, PaResPos);
 Dec(PaDepth);
 PaResSrc := RS; PaResPos := RP;
 PaA := SA; PaB := SB; PaC := SC; PaD := SD; PaE := SE; PaF := SF;
 PaFreeStream(D, DL);
End;

Procedure PaRunStream(D: PBig; DL: LongInt; ResS: Byte; ResP: LongInt);
Var Tok: String; K, I, N: Integer; SavB: PBig; SavP, SavE: LongInt; C: Real;
    LastName: String; Eo: Boolean;
Begin
 SavB := PaCB; SavP := PaCP; SavE := PaCE;
 PaCB := D; PaCP := 0; PaCE := DL;
 PaSN := 0; PaInArr := False; PaArr := ''; PaStr := ''; LastName := '';
 While PaCP < PaCE Do Begin
  K := PaNext(Tok);
  If K = 0 Then Break;
  If K = 1 Then Begin
   If PaSN < 64 Then Begin Val(Tok, PaStk[PaSN], I); Inc(PaSN); End;
   Continue;
  End;
  If K = 3 Then Begin
   PaStr := Tok;
   If PaInArr Then PaArr := PaArr+Tok;
   Continue;
  End;
  If K = 4 Then Begin
   If Tok = '[' Then Begin PaInArr := True; PaArr := ''; End Else PaInArr := False;
   Continue;
  End;
  If K = 6 Then Begin LastName := Tok; Continue; End;
  If (Tok = 'm') Or (Tok = 'moveto') Then PaPMove(PaArg(2), PaArg(1))
  Else If (Tok = 'l') Or (Tok = 'lineto') Then PaPLine(PaArg(2), PaArg(1))
  Else If (Tok = 'rmoveto') Then PaPMove(PaCurX+PaArg(2), PaCurY+PaArg(1))
  Else If (Tok = 'rlineto') Then PaPLine(PaCurX+PaArg(2), PaCurY+PaArg(1))
  Else If (Tok = 'c') Or (Tok = 'curveto') Then
   PaPCurve(PaArg(6), PaArg(5), PaArg(4), PaArg(3), PaArg(2), PaArg(1))
  Else If Tok = 'v' Then PaPCurve(PaCurX, PaCurY, PaArg(4), PaArg(3), PaArg(2), PaArg(1))
  Else If Tok = 'y' Then PaPCurve(PaArg(4), PaArg(3), PaArg(2), PaArg(1), PaArg(2), PaArg(1))
  Else If (Tok = 'h') Or (Tok = 'closepath') Or (Tok = 'H') Then PaPClose
  Else If Tok = 're' Then Begin
   PaPMove(PaArg(4), PaArg(3));
   PaPLine(PaArg(4)+PaArg(2), PaArg(3));
   PaPLine(PaArg(4)+PaArg(2), PaArg(3)+PaArg(1));
   PaPLine(PaArg(4), PaArg(3)+PaArg(1));
   PaPClose;
  End
  Else If (Tok = 'n') Or (Tok = 'N') Or (Tok = 'newpath') Then PaPClear
  Else If (Tok = 'f') Or (Tok = 'F') Or (Tok = 'f*') Or (Tok = 'fill') Or (Tok = 'eofill') Then Begin
   PaPaint(True, False); PaPClear;
  End
  Else If (Tok = 'S') Or (Tok = 'stroke') Then Begin PaPaint(False, True); PaPClear; End
  Else If (Tok = 's') Then Begin PaPClose; PaPaint(False, True); PaPClear; End
  Else If (Tok = 'B') Or (Tok = 'B*') Then Begin PaPaint(True, True); PaPClear; End
  Else If (Tok = 'b') Or (Tok = 'b*') Then Begin PaPClose; PaPaint(True, True); PaPClear; End
  Else If Tok = 'rg' Then PaFill := ImportPaletteColor(PaArg(3), PaArg(2), PaArg(1))
  Else If Tok = 'RG' Then PaStroke := ImportPaletteColor(PaArg(3), PaArg(2), PaArg(1))
  Else If Tok = 'g' Then PaFill := ImportPaletteColor(PaArg(1), PaArg(1), PaArg(1))
  Else If Tok = 'G' Then PaStroke := ImportPaletteColor(PaArg(1), PaArg(1), PaArg(1))
  Else If Tok = 'k' Then PaFill := PaCmyk(PaArg(4), PaArg(3), PaArg(2), PaArg(1))
  Else If Tok = 'K' Then PaStroke := PaCmyk(PaArg(4), PaArg(3), PaArg(2), PaArg(1))
  Else If (Tok = 'sc') Or (Tok = 'scn') Or (Tok = 'SC') Or (Tok = 'SCN') Then Begin
   If PaSN >= 4 Then N := PaCmyk(PaArg(4), PaArg(3), PaArg(2), PaArg(1))
   Else If PaSN = 3 Then N := ImportPaletteColor(PaArg(3), PaArg(2), PaArg(1))
   Else If PaSN = 1 Then N := ImportPaletteColor(PaArg(1), PaArg(1), PaArg(1))
   Else N := -1;
   If N >= 0 Then Begin
    If (Tok = 'sc') Or (Tok = 'scn') Then PaFill := N Else PaStroke := N;
   End;
  End
  Else If Tok = 'setrgbcolor' Then Begin
   PaFill := ImportPaletteColor(PaArg(3), PaArg(2), PaArg(1)); PaStroke := PaFill;
  End
  Else If Tok = 'setgray' Then Begin
   PaFill := ImportPaletteColor(PaArg(1), PaArg(1), PaArg(1)); PaStroke := PaFill;
  End
  Else If Tok = 'setcmykcolor' Then Begin
   PaFill := PaCmyk(PaArg(4), PaArg(3), PaArg(2), PaArg(1)); PaStroke := PaFill;
  End
  Else If (Tok = 'w') Or (Tok = 'setlinewidth') Then PaLW := PaArg(1)
  Else If Tok = 'cm' Then PaConcat(PaArg(6), PaArg(5), PaArg(4), PaArg(3), PaArg(2), PaArg(1))
  Else If Tok = 'translate' Then PaConcat(1, 0, 0, 1, PaArg(2), PaArg(1))
  Else If Tok = 'scale' Then PaConcat(PaArg(2), 0, 0, PaArg(1), 0, 0)
  Else If (Tok = 'q') Or (Tok = 'gsave') Then PaGSave
  Else If (Tok = 'Q') Or (Tok = 'grestore') Then PaGRestore
  Else If Tok = 'BT' Then Begin
   PaTM[0] := 1; PaTM[1] := 0; PaTM[2] := 0; PaTM[3] := 1; PaTM[4] := 0; PaTM[5] := 0;
   PaLM := PaTM;
  End
  Else If (Tok = 'Tf') Or (Tok = 'scalefont') Then PaFS := PaArg(1)
  Else If Tok = 'TL' Then PaLead := PaArg(1)
  Else If Tok = 'Tm' Then Begin
   For I := 0 To 5 Do PaTM[I] := PaArg(6-I);
   PaLM := PaTM;
  End
  Else If (Tok = 'Td') Or (Tok = 'TD') Or (Tok = 'T*') Then Begin
   If Tok = 'T*' Then Begin
    PaLM[4] := PaLM[4]-PaLead*PaLM[2]; PaLM[5] := PaLM[5]-PaLead*PaLM[3];
   End Else Begin
    If Tok = 'TD' Then PaLead := -PaArg(1);
    PaLM[4] := PaLM[4]+PaArg(2)*PaLM[0]+PaArg(1)*PaLM[2];
    PaLM[5] := PaLM[5]+PaArg(2)*PaLM[1]+PaArg(1)*PaLM[3];
   End;
   PaTM := PaLM;
  End
  Else If Tok = '''' Then Begin
   PaLM[4] := PaLM[4]-PaLead*PaLM[2]; PaLM[5] := PaLM[5]-PaLead*PaLM[3]; PaTM := PaLM;
   PaShowText(PaStr);
  End
  Else If Tok = 'Tj' Then PaShowText(PaStr)
  Else If Tok = 'TJ' Then PaShowText(PaArr)
  Else If Tok = 'show' Then Begin
   PaTM[0] := 1; PaTM[4] := PaCurX; PaTM[5] := PaCurY;
   PaShowText(PaStr);
  End
  Else If Tok = 'Do' Then PaDo(LastName)
  Else If Tok = 'BI' Then Begin
   While (PaCP < PaCE-2) And Not ((PaCB^[PaCP] <= 32) And (PaCB^[PaCP+1] = Ord('E')) And
                                  (PaCB^[PaCP+2] = Ord('I'))) Do Inc(PaCP);
   Inc(PaCP, 3);
  End;
  PaSN := 0;
  C := 0; Eo := False;
 End;
 PaCB := SavB; PaCP := SavP; PaCE := SavE;
End;

Procedure PaInitState;
Var I: Integer;
Begin
 PaA := 1; PaB := 0; PaC := 0; PaD := 1; PaE := 0; PaF := 0;
 PaGSP := 0; PaFill := 0; PaStroke := 0; PaLW := 1; PaFS := 12;
 PaPClear;
 For I := 0 To 5 Do PaTM[I] := 0;
 PaTM[0] := 1; PaTM[3] := 1;
 PaLM := PaTM; PaLead := 12;
 PaCurX := 0; PaCurY := 0; PaStX := 0; PaStY := 0;
 PaDepth := 0;
End;

Procedure PaSetPage(X0, Y0, X1, Y1: Real);
Begin
 If (X1-X0 < 1) Or (Y1-Y0 < 1) Then Begin X0 := 0; Y0 := 0; X1 := 612; Y1 := 792; End;
 PaX0 := X0;
 PaY1 := Y1;
 PaSc := MinReal((ScreenWidth-TOOLBAR_WIDTH-2)/(X1-X0),
                 (ScreenHeight-MENUBAR_HEIGHT-STATUSBAR_HEIGHT-2)/(Y1-Y0));
 If PaSc > 1 Then PaSc := 1;
End;

{ Lit les 4 nombres du tableau en P (S,L) }
Function PaFourNums(S: PBig; P, L: LongInt; Var V: Array Of Real): Boolean;
Var Q, A, B, I, T: LongInt; Sg: Real; Fr, Num: Real; K: LongInt; Neg: Boolean;
Begin
 PaFourNums := False;
 Q := P;
 If PaTok(S, Q, L, A, B) <> 5 Then Exit;
 For I := 0 To 3 Do Begin
  T := PaTok(S, Q, L, A, B);
  If T <> 1 Then Exit;
  Neg := S^[A] = Ord('-');
  Num := 0; Fr := 0; Sg := 1;
  K := A;
  If (S^[K] = Ord('-')) Or (S^[K] = Ord('+')) Then Inc(K);
  While (K < B) And (S^[K] >= Ord('0')) And (S^[K] <= Ord('9')) Do Begin
   Num := Num*10+S^[K]-Ord('0'); Inc(K);
  End;
  If (K < B) And (S^[K] = Ord('.')) Then Begin
   Inc(K); Sg := 0.1;
   While (K < B) And (S^[K] >= Ord('0')) And (S^[K] <= Ord('9')) Do Begin
    Fr := Fr+(S^[K]-Ord('0'))*Sg; Sg := Sg/10; Inc(K);
   End;
  End;
  Num := Num+Fr;
  If Neg Then Num := -Num;
  V[I] := Num;
 End;
 PaFourNums := True;
End;

Function PaReadFile(Name: String): Boolean;
Var F: File; Code: Integer; Got: LongInt;
Begin
 PaReadFile := False;
 PaBuf := Nil; PaLen := 0;
 {$I-} Assign(F, Name); Reset(F, 1); Code := IOResult; {$I+}
 If Code <> 0 Then Exit;
 {$I-} PaLen := FileSize(F); {$I+}
 If (PaLen < 8) Or (PaLen > 40000000) Then Begin Close(F); Exit; End;
 GetMem(PaBuf, PaLen+16);
 FillChar(PaBuf^[PaLen], 16, 0);
 {$I-} BlockRead(F, PaBuf^, PaLen, Got); {$I+}
 Close(F);
 PaReadFile := Got = PaLen;
End;

Procedure PaFreeAll;
Var I: Integer;
Begin
 If PaBuf <> Nil Then FreeMem(PaBuf, PaLen+16);
 PaBuf := Nil;
 For I := 1 To PaXN Do
  If PaXBuf[I] <> Nil Then FreeMem(PaXBuf[I], PaXLen[I]+16);
 PaXN := 0;
End;

{ AI moderne : le fichier est un PDF }
Function ReadPdfAiDocument(Name: String): Boolean;
Var N, P, L, K, Root, Pg, I, Guard, A, B: LongInt; S, PS: PBig; V: Array[0..3] Of Real;
    Pos0, PL: LongInt; Cont: PBig; CL: LongInt; D: PBig; DL: LongInt;
    HaveBox: Boolean; ResP, ResL: LongInt; ResSv: PBig; T: Integer;
    MbS: PBig; MbP, MbL: LongInt; Q: LongInt;
Begin
 ReadPdfAiDocument := False;
 PaXN := 0; PaTruncated := False;
 FillChar(PaOff, SizeOf(PaOff), 0);
 If Not PaReadFile(Name) Then Begin ImportError := 'Fichier PDF illisible ou trop gros.'; Exit; End;
 PaScanObjects;
 PaLoadObjStreams;
 { racine : derniere occurrence de /Root }
 Root := 0;
 I := PaLen-6;
 While I > 0 Do Begin
  If (PaBuf^[I] = Ord('/')) And (PaBuf^[I+1] = Ord('R')) And (PaBuf^[I+2] = Ord('o')) And
     (PaBuf^[I+3] = Ord('o')) And (PaBuf^[I+4] = Ord('t')) Then Begin
   Q := I+5;
   If PaIsRef(PaBuf, Q, PaLen, N) Then Begin Root := N; Break; End;
  End;
  Dec(I);
 End;
 { page : Root -> Pages -> Kids[0] -> ... }
 Pg := 0;
 HaveBox := False;
 MbS := Nil; ResP := -1; ResSv := Nil; ResL := 0;
 If Root > 0 Then Begin
  If PaBody(Root, S, P, L) Then Begin
   K := PaDictFind(S, P, L, 'Pages');
   Guard := 0;
   While (K >= 0) And (Guard < 12) Do Begin
    Inc(Guard);
    If Not PaIsRef(S, K, L, N) Then Break;
    If Not PaBody(N, S, P, L) Then Break;
    Pos0 := PaDictFind(S, P, L, 'MediaBox');
    If Pos0 >= 0 Then Begin MbS := S; MbP := Pos0; MbL := L; End;
    Pos0 := PaDictFind(S, P, L, 'Resources');
    If Pos0 >= 0 Then Begin ResSv := S; ResP := Pos0; ResL := L; End;
    Pos0 := PaDictFind(S, P, L, 'Kids');
    If Pos0 < 0 Then Begin Pg := N; Break; End;
    { premier enfant }
    Q := Pos0;
    If PaTok(S, Q, L, A, B) <> 5 Then Break;
    K := PaSkip(S, Q, L);
   End;
  End;
 End;
 If Pg = 0 Then Begin
  { repli : premier objet portant /Type /Page }
  For N := 1 To PaObjMax Do
   If PaBody(N, S, P, L) Then
    If PaByte(S, P, L) = Ord('<') Then Begin
     K := PaDictFind(S, P, L, 'Type');
     If PaNameIs(S, K, L, 'Page') Then Begin Pg := N; Break; End;
    End;
 End;
 If Pg = 0 Then Begin
  ImportError := 'Page PDF introuvable dans ce fichier AI.';
  PaFreeAll; Exit;
 End;
 PaBody(Pg, S, P, L);
 Pos0 := PaDictFind(S, P, L, 'MediaBox');
 If Pos0 >= 0 Then Begin MbS := S; MbP := Pos0; MbL := L; End;
 Pos0 := PaDictFind(S, P, L, 'Resources');
 If Pos0 >= 0 Then Begin ResSv := S; ResP := Pos0; ResL := L; End;
 Pos0 := PaDictFind(S, P, L, 'CropBox');
 If Pos0 >= 0 Then Begin MbS := S; MbP := Pos0; MbL := L; End;
 PaSetPage(0, 0, 612, 792);
 If MbS <> Nil Then Begin
  If PaDeref(MbS, MbP, MbL) Then
   If PaFourNums(MbS, MbP, MbL, V) Then PaSetPage(V[0], V[1], V[2], V[3]);
 End;
 { ressources de la page }
 PaResSrc := 0; PaResPos := -1;
 If ResSv <> Nil Then Begin
  If PaDeref(ResSv, ResP, ResL) Then Begin
   PaResSrc := 0;
   For I := 1 To PaXN Do If ResSv = PaXBuf[I] Then PaResSrc := I;
   PaResPos := ResP;
  End;
 End;
 { contenus }
 K := PaDictFind(S, P, L, 'Contents');
 PaInitState;
 PaFill := 0; PaStroke := 0;
 If K < 0 Then Begin ImportError := 'Page PDF sans contenu.'; PaFreeAll; Exit; End;
 If PaIsRef(S, K, L, N) Then Begin
  If PaBody(N, PS, Q, PL) Then Begin
   If PaByte(PS, Q, PL) = Ord('[') Then Begin
    { tableau de flux }
    PaTok(PS, Q, PL, A, B);
    While PaTok(PS, Q, PL, A, B) = 1 Do Begin
     N := PaNum(PS, A, B);
     PaTok(PS, Q, PL, A, B); PaTok(PS, Q, PL, A, B);
     If PaStream(N, D, DL) Then Begin
      PaRunStream(D, DL, PaResSrc, PaResPos);
      PaFreeStream(D, DL);
     End;
    End;
   End Else If PaStream(N, D, DL) Then Begin
    PaRunStream(D, DL, PaResSrc, PaResPos);
    PaFreeStream(D, DL);
   End;
  End;
 End Else Begin
  Q := K;
  If PaTok(S, Q, L, A, B) = 5 Then
   Repeat
    If Not PaIsRef(S, Q, L, N) Then Break;
    PaTok(S, Q, L, A, B); PaTok(S, Q, L, A, B); PaTok(S, Q, L, A, B);
    If PaStream(N, D, DL) Then Begin
     PaRunStream(D, DL, PaResSrc, PaResPos);
     PaFreeStream(D, DL);
    End;
   Until False;
 End;
 PaFreeAll;
 If ImportCount = 0 Then Begin
  ImportError := 'Aucun objet vectoriel pris en charge dans ce fichier AI (PDF).';
  Exit;
 End;
 ReadPdfAiDocument := True;
End;

{ PostScript / EPS classique : repli tolerant quand l'import strict echoue }
Function ReadPsAiLenient(Name: String): Boolean;
Var I, Start, E, Cd: LongInt; V: Array[0..3] Of Real; N, K: Integer; Tok: String;
    HaveBox: Boolean; Cmp: String;
 Function Find(Const S: String; From: LongInt): LongInt;
 Var X, Y: LongInt; Same: Boolean;
 Begin
  Find := -1;
  For X := From To PaLen-Length(S) Do Begin
   Same := True;
   For Y := 1 To Length(S) Do
    If PaBuf^[X+Y-1] <> Ord(S[Y]) Then Begin Same := False; Break; End;
   If Same Then Begin Find := X; Exit; End;
  End;
 End;
Begin
 ReadPsAiLenient := False;
 PaXN := 0; PaTruncated := False;
 If Not PaReadFile(Name) Then Begin ImportError := 'Fichier illisible ou trop gros.'; Exit; End;
 If Not ((PaBuf^[0] = Ord('%')) And (PaBuf^[1] = Ord('!'))) Then Begin
  ImportError := 'Format inconnu : AI PostScript/EPS ou AI10 attendu.';
  PaFreeAll; Exit;
 End;
 HaveBox := False;
 I := Find('%%BoundingBox:', 0);
 If I >= 0 Then Begin
  PaCB := PaBuf; PaCP := I+14; PaCE := PaLen;
  N := 0;
  While (N < 4) And (PaCP < PaCE) Do Begin
   K := PaNext(Tok);
   If K = 1 Then Begin Val(Tok, V[N], Cd); Inc(N); End
   Else Break;
  End;
  If N = 4 Then Begin HaveBox := True; PaSetPage(V[0], V[1], V[2], V[3]); End;
 End;
 If Not HaveBox Then Begin
  ImportError := 'BoundingBox absente ou invalide.';
  PaFreeAll; Exit;
 End;
 { le dessin suit le prologue / la configuration }
 Start := Find('%%EndSetup', 0);
 If Start < 0 Then Start := Find('%%EndProlog', 0);
 If Start < 0 Then Start := 0;
 E := Find('%%Trailer', Start);
 If E < 0 Then E := PaLen;
 PaInitState;
 PaResSrc := 0; PaResPos := -1;
 PaRunStream(PBig(@PaBuf^[Start]), E-Start, 0, -1);
 PaFreeAll;
 If ImportCount = 0 Then Begin
  ImportError := 'Aucun objet vectoriel pris en charge dans ce fichier AI/EPS.';
  Exit;
 End;
 ReadPsAiLenient := True;
End;
{$ELSE}
Function ReadPdfAiDocument(Name: String): Boolean;
Begin
 ImportError := 'AI base sur PDF non pris en charge sous Turbo Pascal.';
 ReadPdfAiDocument := False;
End;
Function ReadPsAiLenient(Name: String): Boolean;
Begin
 ReadPsAiLenient := False;
End;
{$ENDIF}


Function LoadDocument(Name: String): Boolean;
Var F: File; Sig: Array[0..3] Of Char; Got: Word; Code, I: Integer;
 Good, Legacy, IsPdfAi: Boolean; Size: LongInt; Err0: String;
Begin
 LoadDocument := False; ImportError := ''; ImpClear; IsPdfAi := False;
 {$I-} Assign(F,Name); Reset(F,1); Code := IOResult; {$I+}
 If Code<>0 Then Begin ImportError := 'Fichier introuvable ou acces refuse.'; Exit; End;
 {$I-}
 Size := FileSize(F); Code := IOResult;
 BlockRead(F,Sig,4,Got); I := IOResult;
 Close(F); Good := IOResult=0;
 {$I+}
 If (Code<>0) Or (I<>0) Or Not Good Or (Got<>4) Or
    (Size>40000000) Then Begin
  ImportError := 'Fichier illisible, trop court ou superieur a 40 Mo.'; Exit;
 End;
 Legacy := (Sig[0]='A') And (Sig[1]='I') And (Sig[2]='1') And (Sig[3]='0');
 If (Sig[0]='%') And (Sig[1]='P') And (Sig[2]='D') And (Sig[3]='F') Then Begin
  Good := ReadPdfAiDocument(Name);
  If Not Good Then Exit;
  IsPdfAi := True;
 End Else Begin
  If Legacy Then Good := ReadLegacyDocument(Name)
  Else Good := ReadIllustratorDocument(Name);
  If (Not Good) And Not Legacy Then Begin
   { import strict refuse : on retente avec l'interprete tolerant }
   Err0 := ImportError; ImportError := ''; ImpClear;
   Good := ReadPsAiLenient(Name);
   If Not Good Then ImportError := Err0;
  End;
 End;
 If Not Good Then Exit;
 AdoptImport;
 ClearSelFlags;
 ClearHistory;
 SelectedObject := -1; CurrentFile := Name; FileModified := False;
 If Legacy Then CurrentSaveFormat := 2
 Else Begin
  CurrentSaveFormat := 0;
  If UpperText(Copy(Name,Length(Name)-3,4))='.EPS' Then CurrentSaveFormat := 1;
 End;
 ResetZoom; NeedsRedraw := True;
 If Legacy Then StatusMessage := 'Format prive AI10 charge (pas Adobe Illustrator).'
 Else If IsPdfAi Then Begin
  StatusMessage := 'AI/PDF importe : couleurs VGA, courbes aplaties, 1re page.';
  {$IFDEF FPC}
  {$ENDIF}
 End
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
  Obj := ObjAt(I)^;
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
  BlockWrite(F,ObjAt(I)^,SizeOf(TGraphicObject),Got); Code := IOResult;
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
  Obj := ObjAt(I)^;
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
  Obj := ObjAt(Index)^; Mode := 0; NumPoints := 0; Geometry;
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
 For I := 0 To ObjectCount-1 Do If ObjAt(I)^.Visible Then Inc(VisibleCount);
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
 For I := 0 To ObjectCount-1 Do If ObjAt(I)^.Visible Then Begin
  Obj := ObjAt(I)^; ObjectColors;
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
  If ObjAt(I)^.Visible And Good Then WriteObject(I);
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
 If (Format<0) Or (Format>7) Or (Name='') Then Begin
  SaveError := 'Nom, format ou document invalide.'; Exit;
 End;
 If IsDirectory(Name) Then Begin SaveError := 'La cible est un dossier, pas un fichier.'; Exit; End;
 For I := 0 To ObjectCount-1 Do
  If Not ValidImportObject(ObjAt(I)^) Then Begin
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
 ClearObjects;
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
 PropActive := False;
 GlyphActive := False; ChoiceActive := False; MarqueeActive := False; EditMulti := False;
 RulersVisible := True; GuidesVisible := True;
 GuideHead := Nil; GuideCur := Nil; GuideDragging := False;
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
 
End;

Procedure Cleanup;
Begin
 ClearGuides;
 ClearObjects;
 ClearHistory;
 CloseGraph;
 Writeln('Au revoir!');
End;

Procedure ShowUsage;
Begin
 WriteLn(PROGRAM_NAME,' : clone d''Adobe Illustrator (dessin vectoriel).');
 WriteLn;
 WriteLn('Syntaxe : AI [-maxscreen] [fichier.ai|fichier.eps]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -maxscreen           Utilise la resolution maximale disponible.');
End;

Var ArgI, C0: Integer;
    Arg, ArgFile: String;

Begin
 MaxScreen := False;
 ArgFile := '';
 For ArgI := 1 To ParamCount Do Begin
  Arg := ParamStr(ArgI);
  If (ArgFile = '') And (Copy(Arg,1,1) <> '-') And (Copy(Arg,1,1) <> '/') Then ArgFile := Arg;
  For C0 := 1 To Length(Arg) Do Arg[C0] := UpCase(Arg[C0]);
  If (Arg = '-MAXSCREEN') Or (Arg = '/MAXSCREEN') Then MaxScreen := True
  Else If (Arg = '/?') Or (Arg = '-H') Or (Arg = '--HELP') Then Begin
   ShowUsage;
   Halt(0);
  End;
 End;
 Initialize;
 InitGraphics;
 InitMenus;
 InitMouse;
 ShowMouse;
 { Document passe en argument de ligne de commande }
 If ArgFile <> '' Then Begin
  If Not LoadDocument(ArgFile) Then StatusMessage := Copy(ImportError,1,75);
  NeedsRedraw := True;
 End;
 
 MainLoop;
 
 Cleanup;
End.