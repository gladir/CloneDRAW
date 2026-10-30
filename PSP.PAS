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

{ API HTTPS declaree localement, sans unite Windows. }
{$IFDEF WINDOWS}{$IFDEF FPC}{$DEFINE SKETCH_NATIVE}{$ENDIF}{$ENDIF}
{$IFDEF SKETCH_NATIVE}
{$PUSH}{$PACKRECORDS C}
Type TSketchInternetBuffer=Record
 Size:LongWord;Next:Pointer;Header:PChar;HeaderLength,HeaderTotal:LongWord;
 Buffer:Pointer;BufferLength,BufferTotal,OffsetLow,OffsetHigh:LongWord;
End;
{$POP}
Function SFInternetOpen(Agent:PChar;Access:LongWord;Proxy,Bypass:PChar;
 Flags:LongWord):Pointer;StdCall;External 'wininet.dll' Name 'InternetOpenA';
Function SFInternetConnect(H:Pointer;Host:PChar;Port:Word;User,Pass:PChar;
 Service,Flags:LongWord;Context:PtrUInt):Pointer;StdCall;
 External 'wininet.dll' Name 'InternetConnectA';
Function SFHttpOpen(H:Pointer;Verb,Path,Version,Referer:PChar;
 Accept:Pointer;Flags:LongWord;Context:PtrUInt):Pointer;StdCall;
 External 'wininet.dll' Name 'HttpOpenRequestA';
Function SFSetOption(H:Pointer;Option:LongWord;Data:Pointer;
 Size:LongWord):LongBool;StdCall;
 External 'wininet.dll' Name 'InternetSetOptionA';
Function SFSend(H:Pointer;Input,Output:Pointer;Flags:LongWord;
 Context:PtrUInt):LongBool;StdCall;
 External 'wininet.dll' Name 'HttpSendRequestExA';
Function SFWrite(H:Pointer;Data:Pointer;Size:LongWord;
 Var Written:LongWord):LongBool;StdCall;
 External 'wininet.dll' Name 'InternetWriteFile';
Function SFEnd(H:Pointer;Output:Pointer;Flags:LongWord;
 Context:PtrUInt):LongBool;StdCall;
 External 'wininet.dll' Name 'HttpEndRequestA';
Function SFQuery(H:Pointer;Info:LongWord;Data:Pointer;
 Var Size,Index:LongWord):LongBool;StdCall;
 External 'wininet.dll' Name 'HttpQueryInfoA';
Function SFRead(H:Pointer;Data:Pointer;Size:LongWord;
 Var Count:LongWord):LongBool;StdCall;
 External 'wininet.dll' Name 'InternetReadFile';
Function SFClose(H:Pointer):LongBool;StdCall;
 External 'wininet.dll' Name 'InternetCloseHandle';
Function SFLastError:LongWord;StdCall;
 External 'kernel32.dll' Name 'GetLastError';
Function SFOpenURL(Window:Pointer;Operation,FileName,Parameters,
 Directory:PChar;Show:LongInt):PtrInt;StdCall;
 External 'shell32.dll' Name 'ShellExecuteA';
{$ENDIF}

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
 MENU_3D      = 6;
 MENU_VIEW    = 7;
 MENU_WINDOW  = 8;
 MENU_HELP    = 9;
 NUM_MENUS    = 10;

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

 { Geometrie 3D immutable partagee par les calques et l'historique. }
 TMeshVector=Record X,Y,Z:Single;End;
 TMeshTriangle=Record A,B,C:LongInt;End;
 TMeshVertices=Array[0..119999] Of TMeshVector;
 TMeshTriangles=Array[0..39999] Of TMeshTriangle;
 PMeshVertices=^TMeshVertices;PMeshTriangles=^TMeshTriangles;
 TMeshOptions=Record
  RX,RY,RZ,Scale,OffsetX,OffsetY,Mode,Color:Integer;
  Perspective,Cull,Dither:Boolean;
 End;
 TMesh=Record
  References,VertexCount,TriangleCount,SourceSize,Groups,Materials:LongInt;
  Vertices:PMeshVertices;Triangles:PMeshTriangles;
  Minimum,Maximum:TMeshVector;
  Source:String;Format:String[16];
 End;
 PMesh=^TMesh;
 TLayer = Record
  Mesh:PMesh;
  MeshOptions:TMeshOptions;
  Name: String[20];
  Visible: Boolean;
  Opacity: Byte;
  Pixels: PByteArr;
  Used: Boolean;
 End;

 TRotationUndo = Record
  Saved:Array[0..MAX_LAYERS-1] Of TLayer;
  Width,Height,Count,Active:Integer;
  Modified,Selection:Boolean;
  DPI:Double;Brush:Byte;
  Rect:TRect;
 End;
 PRotationUndo=^TRotationUndo;

 TMenuItem = Record
  Caption: String[28];
  Shortcut: String[16];
  Separator: Boolean;
 End;

 TMenu = Record
  Title: String[12];
  X, Width: Integer;
  ItemCount: Byte;
  Items: Array[0..47] of TMenuItem;
 End;

 TToolDef = Record
  Name: String[20];
  Hint: String[28];
 End;

Var
 GraphDriver, GraphMode: Integer;
 ScreenWidth, ScreenHeight: Integer;
 Running: Boolean;
 FD_ModelMode:Boolean;

 MouseX, MouseY, MouseButtons: Integer;
 OldMouseX, OldMouseY, OldMouseButtons: Integer;
 MouseVisible: Boolean;

 CurrentTool: Byte;
 BrushSize: Byte;
 FgColor, BgColor: Byte;
 Tools: Array[0..MAX_TOOLS-1] of TToolDef;
 ToolTipVisible:Boolean;
 ToolTipCandidate,ToolTipX,ToolTipY:Integer;
 ToolTipStarted:LongInt;
 ToolTipPixels:Array[0..32767] Of Byte;

 Menus: Array[0..NUM_MENUS-1] of TMenu;
 MenuActive: Boolean;
 ActiveMenu, ActiveMenuItem: Integer;

 ImgW, ImgH: Integer;
 ImageDPI:Double;
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
 UndoSizes:Array[0..MAX_UNDO_LEVELS-1] Of LongInt;
 UndoLayer:Array[0..MAX_UNDO_LEVELS-1] Of Integer;
 RotationUndo:Array[0..MAX_UNDO_LEVELS-1] Of PRotationUndo;

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

Procedure RetainMesh(M:PMesh);
Begin If M<>Nil Then Inc(M^.References);End;
Procedure ReleaseMesh(Var M:PMesh);
Begin
 If M=Nil Then Exit;Dec(M^.References);
 If M^.References=0 Then Begin
  If M^.Vertices<>Nil Then FreeMem(M^.Vertices,SizeOf(TMeshVertices));
  If M^.Triangles<>Nil Then FreeMem(M^.Triangles,SizeOf(TMeshTriangles));
  FreeMem(M,SizeOf(TMesh));
 End;
 M:=Nil;
End;

Procedure AllocLayer(LIdx: Integer; Const Nm: String; Transparent: Boolean);
Var Sz: LongInt;
Begin
 If (LIdx<0) Or (LIdx>=MAX_LAYERS) Then Exit;
 Sz := LongInt(ImgW) * ImgH;
 GetMem(Layers[LIdx].Pixels, Sz);
 Layers[LIdx].Mesh:=Nil; FillChar(Layers[LIdx].MeshOptions,
 SizeOf(TMeshOptions), 0); 
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
 ReleaseMesh(Layers[LIdx].Mesh);
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

Function RotationAllocate(Size:LongInt):Pointer;
Begin
 RotationAllocate:=Nil;If Size<=0 Then Exit;
 {$IFDEF FPC}RotationAllocate:=SysGetMem(Size);
 {$ELSE}If MaxAvail>=Size Then GetMem(RotationAllocate,Size);{$ENDIF}
End;
Procedure ReleaseUndoSlot(Index:Integer);
Var I:Integer;R:PRotationUndo;
Begin
 If UndoBuffers[Index]<>Nil Then
  FreeMem(UndoBuffers[Index],UndoSizes[Index]);
 UndoBuffers[Index]:=Nil;R:=RotationUndo[Index];
 If R<>Nil Then Begin
  For I:=0 To MAX_LAYERS-1 Do Begin
   If R^.Saved[I].Pixels<>Nil Then
    FreeMem(R^.Saved[I].Pixels,LongInt(R^.Width)*R^.Height);
   ReleaseMesh(R^.Saved[I].Mesh);
  End;
  FreeMem(R,SizeOf(TRotationUndo));
 End;
 RotationUndo[Index]:=Nil;
End;
Procedure ClearUndoHistory;
Var I:Integer;
Begin
 For I:=0 To MAX_UNDO_LEVELS-1 Do ReleaseUndoSlot(I);UndoCount:=0;
End;
Procedure MakeUndoRoom;
Var I:Integer;
Begin
 If UndoCount<MAX_UNDO_LEVELS Then Exit;ReleaseUndoSlot(0);
 For I:=0 To MAX_UNDO_LEVELS-2 Do Begin
  UndoBuffers[I]:=UndoBuffers[I+1];UndoSizes[I]:=UndoSizes[I+1];
  UndoLayer[I]:=UndoLayer[I+1];RotationUndo[I]:=RotationUndo[I+1];
 End;
 Dec(UndoCount);UndoBuffers[UndoCount]:=Nil;
 RotationUndo[UndoCount]:=Nil;
End;
Procedure PushUndo;
Var Size:LongInt;P:PByteArr;
Begin
 If (ActiveLayer<0) Or (ActiveLayer>=MAX_LAYERS) Then Exit;
 If Not Layers[ActiveLayer].Used Then Exit;
 Size:=LongInt(ImgW)*ImgH;P:=PByteArr(RotationAllocate(Size));
 If P=Nil Then Exit;Move(Layers[ActiveLayer].Pixels^,P^,Size);
 MakeUndoRoom;UndoBuffers[UndoCount]:=P;UndoSizes[UndoCount]:=Size;
 UndoLayer[UndoCount]:=ActiveLayer;RotationUndo[UndoCount]:=Nil;
 Inc(UndoCount);
End;
Procedure DoUndo;
Var I:Integer;R:PRotationUndo;
Begin
 If UndoCount<=0 Then Exit;Dec(UndoCount);R:=RotationUndo[UndoCount];
 If R<>Nil Then Begin
  For I:=0 To MAX_LAYERS-1 Do FreeLayer(I);
  ImgW:=R^.Width;ImgH:=R^.Height;LayerCount:=R^.Count;
  ActiveLayer:=R^.Active;ImageModified:=R^.Modified;
  ImageDPI:=R^.DPI;BrushSize:=R^.Brush;
  SelectionActive:=R^.Selection;SelectionRect:=R^.Rect;
  For I:=0 To MAX_LAYERS-1 Do Begin
   Layers[I]:=R^.Saved[I];R^.Saved[I].Pixels:=Nil;R^.Saved[I].Mesh:=Nil;
  End;
 End Else Begin
  I:=UndoLayer[UndoCount];
  If (I>=0) And (I<MAX_LAYERS) Then
   If Layers[I].Used And (LongInt(ImgW)*ImgH=UndoSizes[UndoCount]) Then
    Begin
     Move(UndoBuffers[UndoCount]^,Layers[I].Pixels^,UndoSizes[UndoCount]);
     ImageModified:=True;
    End;
 End;
 ReleaseUndoSlot(UndoCount);
End;

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
 Menus[MENU_3D].Title      := '3D';
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

 Menus[MENU_IMAGE].ItemCount := 6;
 SetMenuItem(MENU_IMAGE, 0, 'Taille image...', '',       False);
 SetMenuItem(MENU_IMAGE, 1, 'Rotation 90 H',   '',       False);
 SetMenuItem(MENU_IMAGE, 2, 'Rotation 90 AH',  '',       False);
 SetMenuItem(MENU_IMAGE, 3, 'Sym. horiz.',     '',       False);
 SetMenuItem(MENU_IMAGE, 4, 'Sym. vert.',      '',       False);
 SetMenuItem(MENU_IMAGE, 5, 'Rotation...', '', False);

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
 SetMenuItem(MENU_FILTER, 4, 'Flou...',           '',       False);
 SetMenuItem(MENU_FILTER, 5, 'Nettete...',        '',       False);

 Menus[MENU_3D].ItemCount := 39;
 SetMenuItem(MENU_3D, 0,  'Nouveau calque 3D du fichier', '', False);
 SetMenuItem(MENU_3D, 1,  'Fusionner les calques 3D',   '', False);
 SetMenuItem(MENU_3D, 2,  'Exporter calque 3D...',      '', False);
 SetMenuItem(MENU_3D, 3,  'Panorama spherique',         '', False);
 SetMenuItem(MENU_3D, 4,  'Partager sur Sketchfab...',  '', False);
 SetMenuItem(MENU_3D, 5,  '-',                          '', True);
 SetMenuItem(MENU_3D, 6,  'Obtenir plus de contenu...', '', False);
 SetMenuItem(MENU_3D, 7,  '-',                          '', True);
 SetMenuItem(MENU_3D, 8,  'Extrusion 3D du calque',     '', False);
 SetMenuItem(MENU_3D, 9,  'Extrusion 3D du trace',      '', False);
 SetMenuItem(MENU_3D, 10, 'Extrusion 3D selection',     '', False);
 SetMenuItem(MENU_3D, 11, 'Maillage depuis calque',     '', False);
 SetMenuItem(MENU_3D, 12, '-',                          '', True);
 SetMenuItem(MENU_3D, 13, 'Grouper objets',             '', False);
 SetMenuItem(MENU_3D, 14, 'Grouper toute la scene',     '', False);
 SetMenuItem(MENU_3D, 15, 'Placer sur le sol',          '', False);
 SetMenuItem(MENU_3D, 16, 'Tasser objets au sol',       '', False);
 SetMenuItem(MENU_3D, 17, '-',                          '', True);
 SetMenuItem(MENU_3D, 18, 'Peinture mosaique calque',   '', False);
 SetMenuItem(MENU_3D, 19, 'Generer UV...',              '', False);
 SetMenuItem(MENU_3D, 20, 'Attenuation peinture...',    '', False);
 SetMenuItem(MENU_3D, 21, 'Systeme de peinture',        '', False);
 SetMenuItem(MENU_3D, 22, 'Peindre sur texture cible',  '', False);
 SetMenuItem(MENU_3D, 23, 'Selec. zones peignables',    '', False);
 SetMenuItem(MENU_3D, 24, 'Calque de peinture',         '', False);
 SetMenuItem(MENU_3D, 25, '-',                          '', True);
 SetMenuItem(MENU_3D, 26, 'Diviser extrusion',          '', False);
 SetMenuItem(MENU_3D, 27, 'Coupe sur la scene',         '', False);
 SetMenuItem(MENU_3D, 28, 'Unifier pour impression',    '', False);
 SetMenuItem(MENU_3D, 29, 'Simplifier maillage...',     '', False);
 SetMenuItem(MENU_3D, 30, 'Aff/Masq. polygones',        '', False);
 SetMenuItem(MENU_3D, 31, 'Trace depuis calque 3D',     '', False);
 SetMenuItem(MENU_3D, 32, '-',                          '', True);
 SetMenuItem(MENU_3D, 33, 'Rendu du calque 3D',         '', False);
 SetMenuItem(MENU_3D, 34, 'Rendu vers fichier...',      '', False);
 SetMenuItem(MENU_3D, 35, 'Esquisse au pinceau',        '', False);
 SetMenuItem(MENU_3D, 36, '-',                          '', True);
 SetMenuItem(MENU_3D, 37, 'Config. impression 3D...',   '', False);
 SetMenuItem(MENU_3D, 38, 'Imprimer en 3D...',          '', False);

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

{ Infobulles graphiques : fond sauvegarde avant affichage. }
Function ToolTipClock:LongInt;
Var H,M,S,HS:Word;
Begin
 GetTime(H,M,S,HS);
 ToolTipClock:=((LongInt(H)*60+M)*60+S)*100+HS;
End;
Procedure HideToolTip;
Begin
 If Not ToolTipVisible Then Exit;
 HideMouseCursor;
 PutImage(ToolTipX,ToolTipY,ToolTipPixels,CopyPut);
 ToolTipVisible:=False;ShowMouseCursor;
End;
Procedure ResetToolTip;
Begin HideToolTip;ToolTipCandidate:=-1;End;

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

{ Trace polygonal de travail en coordonnees normalisees du document. }
Type TVectorPoint=Record X,Y:Double;End;
 TVectorPath=Record
 Count:Integer;Closed:Boolean;Points:Array[0..127] Of TVectorPoint;
End;
Var WorkingPath:TVectorPath;WorkingPathSelected:Integer;

Function PathCross(Const A,B,C:TVectorPoint):Double;
Begin PathCross:=(B.X-A.X)*(C.Y-A.Y)-(B.Y-A.Y)*(C.X-A.X);End;
Procedure VectorPathPreset(Var P:TVectorPath;Kind:Integer);
Var I,N:Integer;A,R:Double;
Begin
 FillChar(P,SizeOf(P),0);P.Closed:=True;
 If Kind=0 Then Begin
  P.Count:=4;P.Points[0].X:=0.2;P.Points[0].Y:=0.2;
  P.Points[1].X:=0.8;P.Points[1].Y:=0.2;
  P.Points[2].X:=0.8;P.Points[2].Y:=0.8;
  P.Points[3].X:=0.2;P.Points[3].Y:=0.8;
 End Else Begin
  N:=32;If Kind=2 Then N:=10;P.Count:=N;
  For I:=0 To N-1 Do Begin
   A:=I*2*3.141592653589793/N-3.141592653589793/2;R:=0.4;
   If (Kind=2) And (I Mod 2=1) Then R:=0.18;
   P.Points[I].X:=0.5+Cos(A)*R;P.Points[I].Y:=0.5+Sin(A)*R;
  End;
 End;
End;

Procedure DrawWorkingPath;
Var I,J,X,Y,XX,YY:Integer;
Begin
 If Not (CurrentTool In [TOOL_PEN,TOOL_PATHSEL]) Or
  (WorkingPath.Count<1) Then Exit;
 SetViewPort(CanvasX,CanvasY,CanvasX+CanvasW-1,CanvasY+CanvasH-1,True);
 SetColor(Yellow);
 For I:=0 To WorkingPath.Count-1 Do Begin
  X:=Round(WorkingPath.Points[I].X*ImgW*ZoomLevel/100);
  Y:=Round(WorkingPath.Points[I].Y*ImgH*ZoomLevel/100);
  J:=(I+1) Mod WorkingPath.Count;
  If (I<WorkingPath.Count-1) Or WorkingPath.Closed Then Begin
   XX:=Round(WorkingPath.Points[J].X*ImgW*ZoomLevel/100);
   YY:=Round(WorkingPath.Points[J].Y*ImgH*ZoomLevel/100);Line(X,Y,XX,YY);
  End;
  Rectangle(X-2,Y-2,X+2,Y+2);
 End;
 SetViewPort(0,0,ScreenWidth-1,ScreenHeight-1,True);
End;
Function NearestWorkingPoint(IX,IY:Integer):Integer;
Var I:Integer;D,Best:Double;
Begin
 NearestWorkingPoint:=-1;Best:=Sqr(800.0/ZoomLevel);
 For I:=0 To WorkingPath.Count-1 Do Begin
  D:=Sqr(WorkingPath.Points[I].X*ImgW-IX)+
   Sqr(WorkingPath.Points[I].Y*ImgH-IY);
  If D<Best Then Begin Best:=D;NearestWorkingPoint:=I;End;
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
 DrawWorkingPath;
End;

Procedure DrawFullUI;
Begin
 ResetToolTip;
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

{ Angles en dixiemes de degre, sens horaire dans les coordonnees ecran. }
Procedure RotationBasis(Angle:Integer;Clockwise:Boolean;Var C,S:Double);
Var A:Integer;R:Double;
Begin
 A:=Angle Mod 3600;If Not Clockwise Then A:=(3600-A) Mod 3600;
 Case A Of
  0:Begin C:=1;S:=0;End;900:Begin C:=0;S:=1;End;
  1800:Begin C:=-1;S:=0;End;2700:Begin C:=0;S:=-1;End;
  Else Begin R:=A*Pi/1800;C:=Cos(R);S:=Sin(R);End;
 End;
End;
Procedure RotationSize(Angle:Integer;Clockwise,Expand:Boolean;
 Var W,H:Integer);
Var C,S,V:Double;N:LongInt;
Begin
 W:=ImgW;H:=ImgH;If Not Expand Then Exit;
 RotationBasis(Angle,Clockwise,C,S);
 V:=Abs(ImgW*C)+Abs(ImgH*S);N:=Trunc(V);
 If V-N>0.000001 Then Inc(N);W:=N;
 V:=Abs(ImgW*S)+Abs(ImgH*C);N:=Trunc(V);
 If V-N>0.000001 Then Inc(N);H:=N;
End;
Procedure RotationSource(X,Y,W,H:Integer;C,S:Double;Var SX,SY:Integer);
Var DX,DY:Double;
Begin
 DX:=X-(W-1)/2;DY:=Y-(H-1)/2;
 SX:=Trunc(C*DX+S*DY+(ImgW-1)/2+0.5+65536)-65536;
 SY:=Trunc(-S*DX+C*DY+(ImgH-1)/2+0.5+65536)-65536;
End;
Function ApplyRotation(Angle:Integer;Clockwise,Expand,AllLayers,
 Transparent:Boolean):Boolean;
Var W,H,I,X,Y,SX,SY:Integer;Size:LongInt;C,S:Double;
 R:PRotationUndo;NewPixels:Array[0..MAX_LAYERS-1] Of PByteArr;
 Fill:Byte;Failed:Boolean;
Begin
 ApplyRotation:=False;
 If (Angle<0) Or (Angle>3600) Then Exit;
 If Angle Mod 3600=0 Then Begin ApplyRotation:=True;Exit;End;
 RotationSize(Angle,Clockwise,Expand,W,H);
 If (W<1) Or (H<1) Or (W>4096) Or (H>4096) Then Exit;
 If (ActiveLayer<0) Or (ActiveLayer>=LayerCount) Then Exit;
 FillChar(NewPixels,SizeOf(NewPixels),0);Size:=LongInt(W)*H;
 R:=PRotationUndo(RotationAllocate(SizeOf(TRotationUndo)));
 If R=Nil Then Exit;Failed:=False;RotationBasis(Angle,Clockwise,C,S);
 For I:=0 To MAX_LAYERS-1 Do If Layers[I].Used Then Begin
  NewPixels[I]:=PByteArr(RotationAllocate(Size));
  If NewPixels[I]=Nil Then Begin Failed:=True;Break;End;
  Fill:=BgColor;If Transparent Then Fill:=255;
  FillChar(NewPixels[I]^,Size,Fill);
  For Y:=0 To H-1 Do For X:=0 To W-1 Do Begin
   If AllLayers Or (I=ActiveLayer) Then
    RotationSource(X,Y,W,H,C,S,SX,SY)
   Else Begin SX:=X-(W-ImgW) Div 2;SY:=Y-(H-ImgH) Div 2;End;
   If (SX>=0) And (SY>=0) And (SX<ImgW) And (SY<ImgH) Then
    NewPixels[I]^[LongInt(Y)*W+X]:=
     Layers[I].Pixels^[LongInt(SY)*ImgW+SX];
  End;
 End;
 If Failed Then Begin
  For I:=0 To MAX_LAYERS-1 Do If NewPixels[I]<>Nil Then
   FreeMem(NewPixels[I],Size);
  FreeMem(R,SizeOf(TRotationUndo));Exit;
 End;
 R^.Width:=ImgW;R^.Height:=ImgH;R^.Count:=LayerCount;
 R^.Active:=ActiveLayer;R^.Modified:=ImageModified;
 R^.Selection:=SelectionActive;R^.Rect:=SelectionRect;
 R^.DPI:=ImageDPI;R^.Brush:=BrushSize;
 For I:=0 To MAX_LAYERS-1 Do Begin
  R^.Saved[I]:=Layers[I];RetainMesh(R^.Saved[I].Mesh);
 End;
 MakeUndoRoom;RotationUndo[UndoCount]:=R;
 UndoBuffers[UndoCount]:=Nil;Inc(UndoCount);
 For I:=0 To MAX_LAYERS-1 Do Layers[I].Pixels:=NewPixels[I];
 ImgW:=W;ImgH:=H;SelectionActive:=False;ImageModified:=True;
 ApplyRotation:=True;
End;
{ Reechantillonnage en RGB, transparence premultipliee, retour palette VGA. }
Function ResizeWeight(T:Double;Method:Integer):Double;
Var A:Double;
Begin
 T:=Abs(T);ResizeWeight:=0;
 If Method=3 Then Begin
  If T<1 Then ResizeWeight:=(4-6*T*T+3*T*T*T)/6
   Else If T<2 Then ResizeWeight:=(2-T)*(2-T)*(2-T)/6;
 End Else Begin
  A:=-0.5;If Method=4 Then A:=-0.75;
  If T<1 Then ResizeWeight:=(A+2)*T*T*T-(A+3)*T*T+1
  Else If T<2 Then ResizeWeight:=A*T*T*T-5*A*T*T+8*A*T-4*A;
 End;
End;
Function ResizeSample(Layer:Integer;X,Y:Double;Method:Integer):Byte;
Var IX,IY,J,K,Color,Best:Integer;
 R,G,B,Alpha,Weight,WX,WY,DX,DY,Dist,BestDist:Double;
 Function Pixel(PX,PY:Integer):Byte;
 Begin
  PX:=Max(0,Min(ImgW-1,PX));PY:=Max(0,Min(ImgH-1,PY));
  If Layer<0 Then Pixel:=Composite(PX,PY)
   Else Pixel:=GetLayerPixel(Layer,PX,PY);
 End;
 Procedure Accumulate(PX,PY:Integer;Value:Double);
 Var V:Byte;
 Begin
  V:=Pixel(PX,PY);If V=255 Then Exit;V:=V And 15;
  Alpha:=Alpha+Value;R:=R+VGA_R[V]*Value;
  G:=G+VGA_G[V]*Value;B:=B+VGA_B[V]*Value;
 End;
Begin
 If Method=0 Then Begin
  ResizeSample:=Pixel(Trunc(X+0.5+65536)-65536,
   Trunc(Y+0.5+65536)-65536);Exit;
 End;
 IX:=Trunc(X+65536)-65536;IY:=Trunc(Y+65536)-65536;
 DX:=X-IX;DY:=Y-IY;R:=0;G:=0;B:=0;Alpha:=0;
 If Method=1 Then Begin
  For J:=0 To 1 Do For K:=0 To 1 Do Begin
   WX:=1-DX;If K=1 Then WX:=DX;
   WY:=1-DY;If J=1 Then WY:=DY;Accumulate(IX+K,IY+J,WX*WY);
  End;
 End Else For J:=-1 To 2 Do For K:=-1 To 2 Do Begin
  Weight:=ResizeWeight(K-DX,Method)*ResizeWeight(J-DY,Method);
  If Weight<>0 Then Accumulate(IX+K,IY+J,Weight);
 End;
 ResizeSample:=255;If Alpha<0.5 Then Exit;
 R:=R/Alpha;G:=G/Alpha;B:=B/Alpha;
 If R<0 Then R:=0 Else If R>255 Then R:=255;
 If G<0 Then G:=0 Else If G>255 Then G:=255;
 If B<0 Then B:=0 Else If B>255 Then B:=255;
 Best:=0;BestDist:=1E30;
 For Color:=0 To 15 Do Begin
  Dist:=Sqr(R-VGA_R[Color])+Sqr(G-VGA_G[Color])+Sqr(B-VGA_B[Color]);
  If Dist<BestDist Then Begin BestDist:=Dist;Best:=Color;End;
 End;
 ResizeSample:=Best;
End;
Function ApplyImageSize(W,H:Integer;DPI:Double;Method:Integer;
 ScaleBrush:Boolean):Boolean;
Var I,X,Y:Integer;Size:LongInt;R:PRotationUndo;Failed:Boolean;
 NewPixels:Array[0..MAX_LAYERS-1] Of PByteArr;SX,SY,Scale:Double;
Begin
 ApplyImageSize:=False;
 If (W<1) Or (H<1) Or (W>4096) Or (H>4096) Or
    (DPI<1) Or (DPI>9600) Or (Method<0) Or (Method>4) Then Exit;
 If (W=ImgW) And (H=ImgH) And (Abs(DPI-ImageDPI)<0.0001) Then Begin
  ApplyImageSize:=True;Exit;
 End;
 FillChar(NewPixels,SizeOf(NewPixels),0);Size:=LongInt(W)*H;
 R:=PRotationUndo(RotationAllocate(SizeOf(TRotationUndo)));
 If R=Nil Then Exit;Failed:=False;
 For I:=0 To MAX_LAYERS-1 Do If Layers[I].Used Then Begin
  NewPixels[I]:=PByteArr(RotationAllocate(Size));
  If NewPixels[I]=Nil Then Begin Failed:=True;Break;End;
  If (W=ImgW) And (H=ImgH) Then Move(Layers[I].Pixels^,NewPixels[I]^,Size)
  Else For Y:=0 To H-1 Do Begin
   SY:=(Y+0.5)*ImgH/H-0.5;
   For X:=0 To W-1 Do Begin
    SX:=(X+0.5)*ImgW/W-0.5;
    NewPixels[I]^[LongInt(Y)*W+X]:=ResizeSample(I,SX,SY,Method);
   End;
  End;
 End;
 If Failed Then Begin
  For I:=0 To MAX_LAYERS-1 Do If NewPixels[I]<>Nil Then
   FreeMem(NewPixels[I],Size);
  FreeMem(R,SizeOf(TRotationUndo));Exit;
 End;
 R^.Width:=ImgW;R^.Height:=ImgH;R^.Count:=LayerCount;
 R^.Active:=ActiveLayer;R^.Modified:=ImageModified;
 R^.Selection:=SelectionActive;R^.Rect:=SelectionRect;
 R^.DPI:=ImageDPI;R^.Brush:=BrushSize;
 For I:=0 To MAX_LAYERS-1 Do Begin
  R^.Saved[I]:=Layers[I];RetainMesh(R^.Saved[I].Mesh);
 End;
 MakeUndoRoom;RotationUndo[UndoCount]:=R;UndoBuffers[UndoCount]:=Nil;
 Inc(UndoCount);
 Scale:=Sqrt((W/ImgW)*(H/ImgH));
 If ScaleBrush Then BrushSize:=Max(1,Min(255,Round(BrushSize*Scale)));
 For I:=0 To MAX_LAYERS-1 Do Layers[I].Pixels:=NewPixels[I];
 ImgW:=W;ImgH:=H;ImageDPI:=DPI;ImageModified:=True;
 SelectionActive:=False;ApplyImageSize:=True;
End;

Type TBlurPixels=Array[0..MAX_LAYERS-1] Of PByteArr;
 TBlurOptions=Record
  Angle,Distance,Amount,Passes,Samples,Edges:Integer;
  AllLayers,Dither:Boolean;
 End;
Function BlurPalette(R,G,B:Double;X,Y:Integer;Dither:Boolean):Byte;
Const Bayer:Array[0..15] Of Byte=(0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5);
Var I,First,Second:Integer;D,D1,D2,T,Den,DR,DG,DB:Double;
Begin
 First:=0;Second:=0;D1:=1E30;D2:=1E30;
 For I:=0 To 15 Do Begin
  D:=Sqr(R-VGA_R[I])+Sqr(G-VGA_G[I])+Sqr(B-VGA_B[I]);
  If D<D1 Then Begin D2:=D1;Second:=First;D1:=D;First:=I;End
  Else If D<D2 Then Begin D2:=D;Second:=I;End;
 End;
 BlurPalette:=First;If Not Dither Or (D1<0.000001) Then Exit;
 DR:=VGA_R[Second]-VGA_R[First];DG:=VGA_G[Second]-VGA_G[First];
 DB:=VGA_B[Second]-VGA_B[First];Den:=DR*DR+DG*DG+DB*DB;
 If Den=0 Then Exit;
 T:=((R-VGA_R[First])*DR+(G-VGA_G[First])*DG+
  (B-VGA_B[First])*DB)/Den;
 If T>(Bayer[(Y And 3)*4+(X And 3)]+0.5)/16 Then BlurPalette:=Second;
End;
Function BlurCoordinate(V,Size,Edge:Integer):Integer;
Begin
 If Edge=0 Then V:=Max(0,Min(Size-1,V))
 Else If Edge=1 Then Begin
  If Size=1 Then V:=0
  Else Begin
   V:=V Mod (Size*2);If V<0 Then Inc(V,Size*2);
   If V>=Size Then V:=Size*2-1-V;
  End;
 End;
 BlurCoordinate:=V;
End;
Function BlurPixel(Source:PByteArr;X,Y:Integer;Const O:TBlurOptions;
 C,S:Double):Byte;
Var I,SX,SY,Value:Integer;T,R,G,B,A,Weight,OriginWeight:Double;
 Procedure Accumulate(PX,PY:Integer;W:Double);
 Var V:Byte;
 Begin
  PX:=BlurCoordinate(PX,ImgW,O.Edges);PY:=BlurCoordinate(PY,ImgH,O.Edges);
  If (PX<0) Or (PY<0) Or (PX>=ImgW) Or (PY>=ImgH) Then Exit;
  V:=Source^[LongInt(PY)*ImgW+PX];If V=255 Then Exit;
  V:=V And 15;A:=A+W;R:=R+VGA_R[V]*W;
  G:=G+VGA_G[V]*W;B:=B+VGA_B[V]*W;
 End;
Begin
 If (O.Distance=0) Or (O.Amount=0) Then Begin
  BlurPixel:=Source^[LongInt(Y)*ImgW+X];Exit;
 End;
 R:=0;G:=0;B:=0;A:=0;Weight:=O.Amount/(100.0*O.Samples);
 For I:=0 To O.Samples-1 Do Begin
  T:=(I/(O.Samples-1)-0.5)*O.Distance;
  SX:=Trunc(X+C*T+0.5+65536)-65536;
  SY:=Trunc(Y+S*T+0.5+65536)-65536;Accumulate(SX,SY,Weight);
 End;
 OriginWeight:=1-O.Amount/100.0;Accumulate(X,Y,OriginWeight);
 BlurPixel:=255;If A<0.5 Then Exit;
 BlurPixel:=BlurPalette(R/A,G/A,B/A,X,Y,O.Dither);
End;
Function BlurOptionsValid(Const O:TBlurOptions):Boolean;
Begin
 BlurOptionsValid:=(O.Angle>=0) And (O.Angle<=3600) And
  (O.Distance>=0) And (O.Distance<=512) And (O.Amount>=0) And
  (O.Amount<=100) And (O.Passes>=1) And (O.Passes<=8) And
  (O.Samples>=3) And (O.Samples<=1025) And (O.Edges>=0) And (O.Edges<=2);
End;
Function BuildBlurLayer(Source:PByteArr;Const O:TBlurOptions;
 Progress:Boolean;Var Output:PByteArr):Boolean;
Var A,B,Tmp:PByteArr;Size:LongInt;X,Y,Pass:Integer;C,S:Double;K:Char;
 Failed:Boolean;
Begin
 BuildBlurLayer:=False;Output:=Nil;Size:=LongInt(ImgW)*ImgH;
 A:=PByteArr(RotationAllocate(Size));B:=PByteArr(RotationAllocate(Size));
 If (A=Nil) Or (B=Nil) Then Begin
  If A<>Nil Then FreeMem(A,Size);If B<>Nil Then FreeMem(B,Size);Exit;
 End;
 Move(Source^,A^,Size);RotationBasis(O.Angle,True,C,S);Failed:=False;
 For Pass:=1 To O.Passes Do Begin
  For Y:=0 To ImgH-1 Do Begin
   If Progress And (Y Mod 16=0) Then Begin
    HideMouseCursor;
    FillRect(20,ScreenHeight-45,ScreenWidth-20,ScreenHeight-23,LightGray);
    SetColor(Black);OutTextXY(28,ScreenHeight-38,
     'Calcul du flou - passe '+IntToStr(Pass)+'/'+IntToStr(O.Passes)+
     ' - '+IntToStr(LongInt(Y)*100 Div ImgH)+'% - Echap : annuler');
    ShowMouseCursor;
   End;
   If Progress Then If KeyPressed Then Begin
    K:=ReadKey;If K=#27 Then Failed:=True;
   End;
   If Failed Then Break;
   For X:=0 To ImgW-1 Do B^[LongInt(Y)*ImgW+X]:=BlurPixel(A,X,Y,O,C,S);
  End;
  If Failed Then Break;Tmp:=A;A:=B;B:=Tmp;
 End;
 FreeMem(B,Size);
 If Failed Then FreeMem(A,Size)
 Else Begin Output:=A;BuildBlurLayer:=True;End;
End;
Procedure FreeBlurPixels(Var Pixels:TBlurPixels);
Var I:Integer;
Begin
 For I:=0 To MAX_LAYERS-1 Do If Pixels[I]<>Nil Then Begin
  FreeMem(Pixels[I],LongInt(ImgW)*ImgH);Pixels[I]:=Nil;
 End;
End;
Function BuildBlurPixels(Const O:TBlurOptions;Progress:Boolean;
 Var Pixels:TBlurPixels):Boolean;
Var I:Integer;Size:LongInt;OK:Boolean;
Begin
 BuildBlurPixels:=False;FillChar(Pixels,SizeOf(Pixels),0);
 If Not BlurOptionsValid(O) Or (ImgW<1) Or (ImgH<1) Or
  (ImgW>4096) Or (ImgH>4096) Then Exit;
 Size:=LongInt(ImgW)*ImgH;
 For I:=0 To MAX_LAYERS-1 Do If Layers[I].Used Then Begin
  If O.AllLayers Or (I=ActiveLayer) Then
   OK:=BuildBlurLayer(Layers[I].Pixels,O,Progress,Pixels[I])
  Else Begin
   Pixels[I]:=PByteArr(RotationAllocate(Size));OK:=Pixels[I]<>Nil;
   If OK Then Move(Layers[I].Pixels^,Pixels[I]^,Size);
  End;
  If Not OK Then Begin FreeBlurPixels(Pixels);Exit;End;
 End;
 BuildBlurPixels:=True;
End;
Function ApplyMotionBlur(Const O:TBlurOptions;Progress:Boolean):Boolean;
Var Pixels:TBlurPixels;R:PRotationUndo;I:Integer;
Begin
 ApplyMotionBlur:=False;If Not BlurOptionsValid(O) Then Exit;
 If (O.Amount=0) Or (O.Distance=0) Then Begin ApplyMotionBlur:=True;Exit;End;
 R:=PRotationUndo(RotationAllocate(SizeOf(TRotationUndo)));
 If R=Nil Then Exit;
 If Not BuildBlurPixels(O,Progress,Pixels) Then Begin
  FreeMem(R,SizeOf(TRotationUndo));Exit;
 End;
 R^.Width:=ImgW;R^.Height:=ImgH;R^.Count:=LayerCount;
 R^.Active:=ActiveLayer;R^.Modified:=ImageModified;
 R^.Selection:=SelectionActive;R^.Rect:=SelectionRect;
 R^.DPI:=ImageDPI;R^.Brush:=BrushSize;
 For I:=0 To MAX_LAYERS-1 Do Begin
  R^.Saved[I]:=Layers[I];RetainMesh(R^.Saved[I].Mesh);
 End;
 MakeUndoRoom;RotationUndo[UndoCount]:=R;UndoBuffers[UndoCount]:=Nil;
 Inc(UndoCount);
 For I:=0 To MAX_LAYERS-1 Do Layers[I].Pixels:=Pixels[I];
 ImageModified:=True;ApplyMotionBlur:=True;
End;

Type TSharpenOptions=Record
 Amount,Radius,Threshold,Halo:Integer;
 Luminance,AllLayers,Dither:Boolean;
 End;
 TSharpValue=Record R,G,B,A:Single;End;
 TSharpValues=Array[0..16777215] Of TSharpValue;
 PSharpValues=^TSharpValues;
Function SharpOptionsValid(Const O:TSharpenOptions):Boolean;
Begin
 SharpOptionsValid:=(O.Amount>=0) And (O.Amount<=500) And
  (O.Radius>=0) And (O.Radius<=200) And (O.Threshold>=0) And
  (O.Threshold<=255) And (O.Halo>=0) And (O.Halo<=100);
End;
Function SharpProgress(Const Phase:String;Row:Integer;Progress:Boolean):Boolean;
Var K:Char;
Begin
 SharpProgress:=True;If Not Progress Then Exit;
 If Row Mod 16=0 Then Begin
  HideMouseCursor;
  FillRect(20,ScreenHeight-45,ScreenWidth-20,ScreenHeight-23,LightGray);
  SetColor(Black);OutTextXY(28,ScreenHeight-38,
   'Nettete - '+Phase+' '+IntToStr(LongInt(Row)*100 Div ImgH)+
   '% - Echap : annuler');ShowMouseCursor;
 End;
 If KeyPressed Then Begin K:=ReadKey;SharpProgress:=K<>#27;End;
End;
Function BuildSharpLayer(Source:PByteArr;Const O:TSharpenOptions;
 Progress:Boolean;Var Output:PByteArr):Boolean;
Var Temp:PSharpValues;Size,TempSize,Index:LongInt;
 X,Y,J,R,XX,YY,Color:Integer;Kernel:Array[-60..60] Of Double;
 Sigma,Sum,W,Red,Green,Blue,Alpha,SR,SG,SB,DR,DG,DB,DY,
 Magnitude,Gain,V:Double;Failed:Boolean;
 Function Clamp(Value:Double):Double;
 Begin
  If Value<0 Then Value:=0 Else If Value>255 Then Value:=255;
  Clamp:=Value;
 End;
Begin
 BuildSharpLayer:=False;Output:=Nil;Size:=LongInt(ImgW)*ImgH;
 If (O.Amount=0) Or (O.Radius=0) Then Begin
  Output:=PByteArr(RotationAllocate(Size));If Output=Nil Then Exit;
  Move(Source^,Output^,Size);BuildSharpLayer:=True;Exit;
 End;
 TempSize:=Size*SizeOf(TSharpValue);
 Temp:=PSharpValues(RotationAllocate(TempSize));
 Output:=PByteArr(RotationAllocate(Size));
 If (Temp=Nil) Or (Output=Nil) Then Begin
  If Temp<>Nil Then FreeMem(Temp,TempSize);
  If Output<>Nil Then FreeMem(Output,Size);Output:=Nil;Exit;
 End;
 Sigma:=O.Radius/10.0;R:=Trunc(Sigma*3);
 If R<Sigma*3 Then Inc(R);R:=Min(60,Max(1,R));Sum:=0;
 For J:=-R To R Do Begin
  Kernel[J]:=Exp(-(J*1.0*J)/(2*Sigma*Sigma));Sum:=Sum+Kernel[J];
 End;
 For J:=-R To R Do Kernel[J]:=Kernel[J]/Sum;
 Failed:=False;
 For Y:=0 To ImgH-1 Do Begin
  If Not SharpProgress('horizontal',Y,Progress) Then Begin
  Failed:=True;Break;End;
  For X:=0 To ImgW-1 Do Begin
   Red:=0;Green:=0;Blue:=0;Alpha:=0;
   For J:=-R To R Do Begin
    XX:=Max(0,Min(ImgW-1,X+J));Color:=Source^[LongInt(Y)*ImgW+XX];
    If Color<>255 Then Begin
     Color:=Color And 15;W:=Kernel[J];Alpha:=Alpha+W;
     Red:=Red+VGA_R[Color]*W;Green:=Green+VGA_G[Color]*W;
     Blue:=Blue+VGA_B[Color]*W;
    End;
   End;
   Index:=LongInt(Y)*ImgW+X;Temp^[Index].R:=Red;Temp^[Index].G:=Green;
   Temp^[Index].B:=Blue;Temp^[Index].A:=Alpha;
  End;
 End;
 If Not Failed Then For Y:=0 To ImgH-1 Do Begin
  If Not SharpProgress('vertical',Y,Progress) Then Begin Failed:=True;Break;End;
  For X:=0 To ImgW-1 Do Begin
   Index:=LongInt(Y)*ImgW+X;Color:=Source^[Index];Output^[Index]:=Color;
   If Color=255 Then Continue;
   Red:=0;Green:=0;Blue:=0;Alpha:=0;
   For J:=-R To R Do Begin
    YY:=Max(0,Min(ImgH-1,Y+J));Index:=LongInt(YY)*ImgW+X;W:=Kernel[J];
    Red:=Red+Temp^[Index].R*W;Green:=Green+Temp^[Index].G*W;
    Blue:=Blue+Temp^[Index].B*W;Alpha:=Alpha+Temp^[Index].A*W;
   End;
   If Alpha<0.000001 Then Continue;
   Color:=Color And 15;SR:=VGA_R[Color];SG:=VGA_G[Color];SB:=VGA_B[Color];
   DR:=SR-Red/Alpha;DG:=SG-Green/Alpha;DB:=SB-Blue/Alpha;
   DY:=0.299*DR+0.587*DG+0.114*DB;
   If O.Luminance Then Magnitude:=Abs(DY)
   Else Begin
    Magnitude:=Abs(DR);If Abs(DG)>Magnitude Then Magnitude:=Abs(DG);
    If Abs(DB)>Magnitude Then Magnitude:=Abs(DB);
   End;
   If Magnitude<=O.Threshold Then Continue;
   V:=Magnitude/64;If V>1 Then V:=1;
   Gain:=O.Amount/100.0*(1-O.Halo/100.0*V);
   If O.Luminance Then Begin DR:=DY;DG:=DY;DB:=DY;End;
   Output^[LongInt(Y)*ImgW+X]:=BlurPalette(Clamp(SR+Gain*DR),
    Clamp(SG+Gain*DG),Clamp(SB+Gain*DB),X,Y,O.Dither);
  End;
 End;
 FreeMem(Temp,TempSize);
 If Failed Then Begin FreeMem(Output,Size);Output:=Nil;End
 Else BuildSharpLayer:=True;
End;
Function BuildSharpPixels(Const O:TSharpenOptions;Progress:Boolean;
 Var Pixels:TBlurPixels):Boolean;
Var I:Integer;Size:LongInt;OK:Boolean;
Begin
 BuildSharpPixels:=False;FillChar(Pixels,SizeOf(Pixels),0);
 If Not SharpOptionsValid(O) Or (ImgW<1) Or (ImgH<1) Or
  (ImgW>4096) Or (ImgH>4096) Then Exit;
 Size:=LongInt(ImgW)*ImgH;
 For I:=0 To MAX_LAYERS-1 Do If Layers[I].Used Then Begin
  If O.AllLayers Or (I=ActiveLayer) Then
   OK:=BuildSharpLayer(Layers[I].Pixels,O,Progress,Pixels[I])
  Else Begin
   Pixels[I]:=PByteArr(RotationAllocate(Size));OK:=Pixels[I]<>Nil;
   If OK Then Move(Layers[I].Pixels^,Pixels[I]^,Size);
  End;
  If Not OK Then Begin FreeBlurPixels(Pixels);Exit;End;
 End;
 BuildSharpPixels:=True;
End;
Function ApplySharpen(Const O:TSharpenOptions;Progress:Boolean):Boolean;
Var Pixels:TBlurPixels;R:PRotationUndo;I:Integer;
Begin
 ApplySharpen:=False;If Not SharpOptionsValid(O) Then Exit;
 If (O.Amount=0) Or (O.Radius=0) Then Begin ApplySharpen:=True;Exit;End;
 R:=PRotationUndo(RotationAllocate(SizeOf(TRotationUndo)));
 If R=Nil Then Exit;
 If Not BuildSharpPixels(O,Progress,Pixels) Then Begin
  FreeMem(R,SizeOf(TRotationUndo));Exit;
 End;
 R^.Width:=ImgW;R^.Height:=ImgH;R^.Count:=LayerCount;
 R^.Active:=ActiveLayer;R^.Modified:=ImageModified;
 R^.Selection:=SelectionActive;R^.Rect:=SelectionRect;
 R^.DPI:=ImageDPI;R^.Brush:=BrushSize;
 For I:=0 To MAX_LAYERS-1 Do Begin
  R^.Saved[I]:=Layers[I];RetainMesh(R^.Saved[I].Mesh);
 End;
 MakeUndoRoom;RotationUndo[UndoCount]:=R;UndoBuffers[UndoCount]:=Nil;
 Inc(UndoCount);
 For I:=0 To MAX_LAYERS-1 Do Layers[I].Pixels:=Pixels[I];
 ImageModified:=True;ApplySharpen:=True;
End;

Type TMeshBytes=Array[0..33554431] Of Byte;PMeshBytes=^TMeshBytes;
Function MeshNumber(Const Text:String;Var Value:Double):Boolean;
Var I,Code:Integer;
Begin
 MeshNumber:=False;If Text='' Then Exit;
 For I:=1 To Length(Text) Do
  If Not (Text[I] In ['0'..'9','+','-','.','e','E']) Then Exit;
 Val(Text,Value,Code);If Code<>0 Then Exit;
 MeshNumber:=(Value>=-1E12) And (Value<=1E12) And
  ((Value=0) Or (Abs(Value)>=1E-30));
End;
Function MeshToken(Var Line:String):String;
Var I:Integer;
Begin
 While Length(Line)>0 Do Begin
  If Ord(Line[1])>32 Then Break;Delete(Line,1,1);
 End;
 I:=1;While I<=Length(Line) Do Begin If Ord(Line[I])<=32 Then Break;Inc(I);End;
 MeshToken:=Copy(Line,1,I-1);Delete(Line,1,I);
End;
Function MeshVertex(M:PMesh;X,Y,Z:Double):Boolean;
Var I:LongInt;
Begin
 MeshVertex:=False;If M^.VertexCount>=120000 Then Exit;
 I:=M^.VertexCount;M^.Vertices^[I].X:=X;M^.Vertices^[I].Y:=Y;
 M^.Vertices^[I].Z:=Z;
 If I=0 Then Begin M^.Minimum:=M^.Vertices^[I];M^.Maximum:=M^.Vertices^[I];End
 Else Begin
  If X<M^.Minimum.X Then M^.Minimum.X:=X;
  If Y<M^.Minimum.Y Then M^.Minimum.Y:=Y;
  If Z<M^.Minimum.Z Then M^.Minimum.Z:=Z;
  If X>M^.Maximum.X Then M^.Maximum.X:=X;
  If Y>M^.Maximum.Y Then M^.Maximum.Y:=Y;
  If Z>M^.Maximum.Z Then M^.Maximum.Z:=Z;
 End;
 Inc(M^.VertexCount);MeshVertex:=True;
End;
Function MeshFace(M:PMesh;A,B,C:LongInt):Boolean;
Var I:LongInt;
Begin
 MeshFace:=False;
 If (M^.TriangleCount>=40000) Or (A<0) Or (B<0) Or (C<0) Or
  (A>=M^.VertexCount) Or (B>=M^.VertexCount) Or (C>=M^.VertexCount) Then Exit;
 I:=M^.TriangleCount;M^.Triangles^[I].A:=A;M^.Triangles^[I].B:=B;
 M^.Triangles^[I].C:=C;Inc(M^.TriangleCount);MeshFace:=True;
End;
Function MeshLong(Data:PMeshBytes;P:LongInt):LongWord;
Begin
 MeshLong:=LongWord(Data^[P]) Or (LongWord(Data^[P+1]) Shl 8) Or
  (LongWord(Data^[P+2]) Shl 16) Or (LongWord(Data^[P+3]) Shl 24);
End;
Function MeshFloat(Data:PMeshBytes;P:LongInt;Var Value:Double):Boolean;
Var Bits:LongWord;S:Single;
Begin
 MeshFloat:=False;Bits:=MeshLong(Data,P);
 If Bits And $7F800000=$7F800000 Then Exit;
 If (Bits And $7F800000=0) And (Bits And $007FFFFF<>0) Then Exit;
 Move(Bits,S,4);Value:=S;MeshFloat:=(Value>=-1E12) And (Value<=1E12) And
  ((Value=0) Or (Abs(Value)>=1E-30));
End;
Function ReadMesh(Const Name:String;Var Model:PMesh;Var Error:String):Boolean;
Var F:File;Data:PMeshBytes;Size,Bytes,P,Start,N,FaceIndex,First,Last,
 Index:LongInt;OldMode:Byte;M:PMesh;Failed,Binary,OBJ,LongLine:Boolean;
 Line,Key,Token:String;X,Y,Z:Double;I,J,Code,VerticesInFace:Integer;
 Function Number:Double;
 Var V:Double;
 Begin
  Token:=MeshToken(Line);V:=0;
  If Not MeshNumber(Token,V) Then Failed:=True;Number:=V;
 End;
Begin
 ReadMesh:=False;Model:=Nil;Data:=Nil;Error:='';M:=Nil;
 OBJ:=ExtractExt(Name)='.OBJ';
 If Not OBJ And (ExtractExt(Name)<>'.STL') Then Begin
  Error:='Formats acceptes : OBJ et STL.';Exit;
 End;
 Assign(F,Name);OldMode:=FileMode;FileMode:=0;
 {$I-}Reset(F,1);{$I+}FileMode:=OldMode;
 If IOResult<>0 Then Begin Error:='Fichier inaccessible.';Exit;End;
 {$I-}Size:=FileSize(F);{$I+}Failed:=IOResult<>0;
 If (Size<1) Or (Size>33554432) Then Failed:=True;
 If Not Failed Then Begin
  Data:=PMeshBytes(RotationAllocate(Size));If Data=Nil Then Failed:=True;
  If Not Failed Then Begin
   {$I-}BlockRead(F,Data^,Size,Bytes);{$I+}
   Failed:=(IOResult<>0) Or (Bytes<>Size);
  End;
 End;
 {$I-}Close(F);{$I+}If IOResult<>0 Then Failed:=True;
 If Not Failed Then Begin
  M:=PMesh(RotationAllocate(SizeOf(TMesh)));
  If M<>Nil Then Begin
   FillChar(M^,SizeOf(M^),0);M^.References:=1;M^.Source:=Name;
   M^.SourceSize:=Size;
   M^.Vertices:=PMeshVertices(RotationAllocate(SizeOf(TMeshVertices))); 
   M^.Triangles:=PMeshTriangles(RotationAllocate(SizeOf(TMeshTriangles)));
   Failed:=(M^.Vertices=Nil) Or (M^.Triangles=Nil);
  End Else Failed:=True;
 End;
 If Not Failed Then Begin
  Binary:=False;N:=0;
  If Not OBJ And (Size>=84) Then Begin
   N:=MeshLong(Data,80);
   If (N>0) And (N<=40000) Then Binary:=Size=84+N*50;
  End;
  If Binary Then Begin
   M^.Format:='STL binaire';P:=84;
   For FaceIndex:=0 To N-1 Do Begin
    First:=M^.VertexCount;Inc(P,12);
    For J:=0 To 2 Do Begin
     If Not MeshFloat(Data,P,X) Then Failed:=True;
     If Not MeshFloat(Data,P+4,Y) Then Failed:=True;
     If Not MeshFloat(Data,P+8,Z) Then Failed:=True;Inc(P,12);
     If Not Failed Then If Not MeshVertex(M,X,Y,Z) Then Failed:=True;
    End;
    If Failed Then Break;
    If Not MeshFace(M,First,First+1,First+2) Then Begin Failed:=True;Break;End;
    Inc(P,2);
   End;
  End Else Begin
   If OBJ Then M^.Format:='Wavefront OBJ' Else M^.Format:='STL ASCII';
   P:=0;VerticesInFace:=0;First:=0;
   If Size>=3 Then If (Data^[0]=239) And (Data^[1]=187) And
    (Data^[2]=191) Then P:=3;
   While (P<Size) And Not Failed Do Begin
    Line:='';LongLine:=False;
    While P<Size Do Begin
     I:=Data^[P];Inc(P);If I In [10,13] Then Break;
     If Length(Line)<255 Then Line:=Line+Chr(I) Else LongLine:=True;
    End;
    I:=Pos('#',Line);If I>0 Then Delete(Line,I,255);
    Key:=UpperStr(MeshToken(Line));If Key='' Then Continue;
    If LongLine Then Begin Error:='Ligne geometrique trop longue (255).';
    Failed:=True; Break; End; 
    If (OBJ And (Key='V')) Or (Not OBJ And (Key='VERTEX')) Then Begin
     X:=Number;Y:=Number;Z:=Number;
     If Not Failed Then If Not MeshVertex(M,X,Y,Z) Then Failed:=True;
     If Not OBJ Then Begin
      Inc(VerticesInFace);
      If VerticesInFace=3 Then Begin
       First:=M^.VertexCount-3;
       If Not MeshFace(M,First,First+1,First+2) Then Failed:=True;
       VerticesInFace:=0;
      End;
     End;
    End Else If OBJ And (Key='F') Then Begin
     I:=0;First:=-1;Last:=-1;
     Repeat
      Token:=MeshToken(Line);If Token='' Then Break;
      J:=Pos('/',Token);If J>0 Then Delete(Token,J,255);
      Val(Token,Index,Code);
      If (Code<>0) Or (Index=0) Then Begin Failed:=True;Break;End;
      If Index<0 Then Index:=M^.VertexCount+Index Else Dec(Index);
      If (Index<0) Or (Index>=M^.VertexCount) Then Begin Failed:=True;Break;End;
      If I=0 Then First:=Index Else If I>1 Then
       If Not MeshFace(M,First,Last,Index) Then Failed:=True;
      Last:=Index;Inc(I);
     Until Failed;
     If I<3 Then Failed:=True;
    End Else If OBJ Then Begin
     If (Key='O') Or (Key='G') Then Inc(M^.Groups);
     If Key='USEMTL' Then Inc(M^.Materials);
    End;
   End;
   If Not OBJ And (VerticesInFace<>0) Then Failed:=True;
  End;
  If (M^.TriangleCount=0) Or (M^.VertexCount<3) Then Failed:=True;
  If Not Failed Then If (M^.Minimum.X=M^.Maximum.X) And
   (M^.Minimum.Y=M^.Maximum.Y) And (M^.Minimum.Z=M^.Maximum.Z) Then
   Failed:=True; 
 End;
 If Data<>Nil Then FreeMem(Data,Size);
 If Failed Then Begin
  ReleaseMesh(M);If Error='' Then
   Error:='Modele invalide ou limite : 120000 sommets / 40000 triangles.';
 End Else Begin Model:=M;ReadMesh:=True;End;
End;

Type TMeshProjected=Record X,Y,Z,WX,WY,WZ:Single;End;
 TMeshProjection=Array[0..119999] Of TMeshProjected;
 PMeshProjection=^TMeshProjection;
 TMeshDepth=Array[0..16777215] Of Single;PMeshDepth=^TMeshDepth;
Function MeshMin(A,B:Double):Double;
Begin If A<B Then MeshMin:=A Else MeshMin:=B;End;
Function MeshMax(A,B:Double):Double;
Begin If A>B Then MeshMax:=A Else MeshMax:=B;End;
Function MeshOptionsValid(Const O:TMeshOptions):Boolean;
Begin
 MeshOptionsValid:=(O.RX>=-3600) And (O.RX<=3600) And
  (O.RY>=-3600) And (O.RY<=3600) And (O.RZ>=-3600) And (O.RZ<=3600)
  And (O.Scale>=10) And (O.Scale<=400) And
  (O.OffsetX>=-100) And (O.OffsetX<=100) And
  (O.OffsetY>=-100) And (O.OffsetY<=100) And
  (O.Mode>=0) And (O.Mode<=2) And (O.Color>=0) And (O.Color<=15);
End;
Procedure DefaultMeshOptions(Var O:TMeshOptions);
Begin
 FillChar(O,SizeOf(O),0);O.RX:=200;O.RY:=-300;O.Scale:=100;
 O.Color:=7;O.Mode:=2;O.Perspective:=True;O.Dither:=True;
End;
Function RenderMesh(M:PMesh;Const O:TMeshOptions;W,H:Integer;
 Progress:Boolean;Var Pixels:PByteArr):Boolean;
Var P:PMeshProjection;Depth:PMeshDepth;Size,I,J:LongInt;
 C1,S1,C2,S2,C3,S3,Extent,CX,CY,CZ,VX,VY,VZ,T,Scale,F,
 NX,NY,NZ,Len,Light,Den,A,B,C,Z,XX,YY,MinX,MaxX,MinY,MaxY:Double;
 AIndex,BIndex,CIndex:LongInt;PA,PB,PC:TMeshProjected;
 X,Y,X1,Y1,X2,Y2:Integer;Failed:Boolean;K:Char;
 Procedure Pixel(PX,PY:Integer;Distance:Double;Color:Byte);
 Var Offset:LongInt;
 Begin
  If (PX<0) Or (PY<0) Or (PX>=W) Or (PY>=H) Then Exit;
  Offset:=LongInt(PY)*W+PX;
  If Distance>=Depth^[Offset]-0.000001 Then Begin
   Depth^[Offset]:=Distance;Pixels^[Offset]:=Color;
  End;
 End;
 Procedure Edge(Const A,B:TMeshProjected;Color:Byte);
 Var Steps,J,PX,PY:Integer;T:Double;
 Begin
  Steps:=Trunc(MeshMax(Abs(B.X-A.X),Abs(B.Y-A.Y)))+1;
  For J:=0 To Steps Do Begin
   T:=J/Steps;PX:=Round(A.X+(B.X-A.X)*T);PY:=Round(A.Y+(B.Y-A.Y)*T);
   Pixel(PX,PY,A.Z+(B.Z-A.Z)*T+0.000002,Color);
  End;
 End;
Begin
 RenderMesh:=False;Pixels:=Nil;
 If (M=Nil) Or Not MeshOptionsValid(O) Or (W<1) Or (H<1) Or
  (W>4096) Or (H>4096) Then Exit;
 Size:=LongInt(W)*H;
 Pixels:=PByteArr(RotationAllocate(Size));
 Depth:=PMeshDepth(RotationAllocate(Size*4));
 P:=PMeshProjection(RotationAllocate(SizeOf(TMeshProjection)));
 If (Pixels=Nil) Or (Depth=Nil) Or (P=Nil) Then Begin
  If Pixels<>Nil Then FreeMem(Pixels,Size);Pixels:=Nil;
  If Depth<>Nil Then FreeMem(Depth,Size*4);
  If P<>Nil Then FreeMem(P,SizeOf(TMeshProjection));Exit;
 End;
 FillChar(Pixels^,Size,255);For I:=0 To Size-1 Do Depth^[I]:=-1E30;
 CX:=(M^.Minimum.X+M^.Maximum.X)/2;CY:=(M^.Minimum.Y+M^.Maximum.Y)/2;
 CZ:=(M^.Minimum.Z+M^.Maximum.Z)/2;
 Extent:=MeshMax(M^.Maximum.X-M^.Minimum.X,M^.Maximum.Y-M^.Minimum.Y);
 Extent:=MeshMax(Extent,M^.Maximum.Z-M^.Minimum.Z);
 If Extent<=0 Then Extent:=1;
 RotationBasis(O.RX,True,C1,S1);RotationBasis(O.RY,True,C2,S2);
 RotationBasis(O.RZ,True,C3,S3);Scale:=Min(W,H)*0.75*O.Scale/100;
 MinX:=1E30;MinY:=1E30;MaxX:=-1E30;MaxY:=-1E30;
 For I:=0 To M^.VertexCount-1 Do Begin
  VX:=(M^.Vertices^[I].X-CX)/Extent;
  VY:=(M^.Vertices^[I].Y-CY)/Extent;VZ:=(M^.Vertices^[I].Z-CZ)/Extent;
  T:=VY*C1-VZ*S1;VZ:=VY*S1+VZ*C1;VY:=T;
  T:=VX*C2+VZ*S2;VZ:=-VX*S2+VZ*C2;VX:=T;
  T:=VX*C3-VY*S3;VY:=VX*S3+VY*C3;VX:=T;
  P^[I].WX:=VX;P^[I].WY:=VY;P^[I].WZ:=VZ;
  F:=1;P^[I].Z:=VZ;
  If O.Perspective Then Begin F:=3/(3-VZ);P^[I].Z:=1/(3-VZ);End;
  P^[I].X:=VX*F;P^[I].Y:=-VY*F;
  MinX:=MeshMin(MinX,P^[I].X);MaxX:=MeshMax(MaxX,P^[I].X);
  MinY:=MeshMin(MinY,P^[I].Y);MaxY:=MeshMax(MaxY,P^[I].Y);
 End;
 Scale:=0.9*MeshMin((W-1)/MeshMax(0.000001,MaxX-MinX),
  (H-1)/MeshMax(0.000001,MaxY-MinY))*O.Scale/100;
 For I:=0 To M^.VertexCount-1 Do Begin
  P^[I].X:=(W-1)/2+(P^[I].X-(MinX+MaxX)/2)*Scale+O.OffsetX*W/100;
  P^[I].Y:=(H-1)/2+(P^[I].Y-(MinY+MaxY)/2)*Scale+O.OffsetY*H/100;
 End;
 Failed:=False;
 For I:=0 To M^.TriangleCount-1 Do Begin
  If Progress And (I Mod 64=0) Then Begin
   HideMouseCursor;
   FillRect(20,ScreenHeight-45,ScreenWidth-20,ScreenHeight-23,LightGray);
   SetColor(Black);OutTextXY(28,ScreenHeight-38,
    'Rendu 3D : '+IntToStr(I*100 Div M^.TriangleCount)+'% - Echap : annuler');
   ShowMouseCursor;
   If KeyPressed Then Begin K:=ReadKey; If K=#27 Then Begin Failed:=True; Break;
   End; End; 
  End;
  AIndex:=M^.Triangles^[I].A;BIndex:=M^.Triangles^[I].B;
  CIndex:=M^.Triangles^[I].C;PA:=P^[AIndex];PB:=P^[BIndex];PC:=P^[CIndex];
  NX:=(PB.WY-PA.WY)*(PC.WZ-PA.WZ)-(PB.WZ-PA.WZ)*(PC.WY-PA.WY);
  NY:=(PB.WZ-PA.WZ)*(PC.WX-PA.WX)-(PB.WX-PA.WX)*(PC.WZ-PA.WZ);
  NZ:=(PB.WX-PA.WX)*(PC.WY-PA.WY)-(PB.WY-PA.WY)*(PC.WX-PA.WX);
  Len:=Sqrt(NX*NX+NY*NY+NZ*NZ);If Len<1E-12 Then Continue;
  If O.Cull And (NX*(-PA.WX)+NY*(-PA.WY)+NZ*(3-PA.WZ)<=0) Then Continue;
  Light:=0.2+0.8*Abs((-0.4*NX+0.7*NY+NZ)/(Len*Sqrt(1.65)));
  Den:=(PB.Y-PC.Y)*(PA.X-PC.X)+(PC.X-PB.X)*(PA.Y-PC.Y);
  If Abs(Den)<1E-10 Then Begin
   If O.Mode<>0 Then Begin
    Edge(PA,PB,Black);Edge(PB,PC,Black);Edge(PC,PA,Black);
   End;
   Continue;
  End;
  If O.Mode<>1 Then Begin
   X1:=Max(0,Trunc(MeshMin(PA.X,MeshMin(PB.X,PC.X))));
   Y1:=Max(0,Trunc(MeshMin(PA.Y,MeshMin(PB.Y,PC.Y))));
   X2:=Min(W-1,Trunc(MeshMax(PA.X,MeshMax(PB.X,PC.X)))+1);
   Y2:=Min(H-1,Trunc(MeshMax(PA.Y,MeshMax(PB.Y,PC.Y)))+1);
   For Y:=Y1 To Y2 Do For X:=X1 To X2 Do Begin
    XX:=X+0.5;YY:=Y+0.5;
    A:=((PB.Y-PC.Y)*(XX-PC.X)+(PC.X-PB.X)*(YY-PC.Y))/Den;
    B:=((PC.Y-PA.Y)*(XX-PC.X)+(PA.X-PC.X)*(YY-PC.Y))/Den;C:=1-A-B;
    If (A>=-0.000001) And (B>=-0.000001) And (C>=-0.000001) Then Begin
     Z:=A*PA.Z+B*PB.Z+C*PC.Z;
     Pixel(X,Y,Z,BlurPalette(VGA_R[O.Color]*Light,VGA_G[O.Color]*Light,
      VGA_B[O.Color]*Light,X,Y,O.Dither));
    End;
   End;
  End;
  If O.Mode<>0 Then Begin
   J:=Black;If O.Color=Black Then J:=White;
   Edge(PA,PB,J);Edge(PB,PC,J);Edge(PC,PA,J);
  End;
 End;
 FreeMem(Depth,Size*4);FreeMem(P,SizeOf(TMeshProjection));
 If Failed Then Begin FreeMem(Pixels,Size);Pixels:=Nil;End
 Else RenderMesh:=True;
End;
Function MeshUndoCopy:PRotationUndo;
Var R:PRotationUndo;I:Integer;Size:LongInt;Failed:Boolean;
Begin
 MeshUndoCopy:=Nil;R:=PRotationUndo(RotationAllocate(SizeOf(TRotationUndo)));
 If R=Nil Then Exit;FillChar(R^,SizeOf(R^),0);
 R^.Width:=ImgW;R^.Height:=ImgH;R^.Count:=LayerCount;
 R^.Active:=ActiveLayer; R^.Modified:=ImageModified;
 R^.Selection:=SelectionActive; 
 R^.Rect:=SelectionRect;R^.DPI:=ImageDPI;R^.Brush:=BrushSize;
 Size:=LongInt(ImgW)*ImgH;Failed:=False;
 For I:=0 To MAX_LAYERS-1 Do Begin
  R^.Saved[I]:=Layers[I];R^.Saved[I].Pixels:=Nil;RetainMesh(R^.Saved[I].Mesh);
  If Layers[I].Pixels<>Nil Then Begin
   R^.Saved[I].Pixels:=PByteArr(RotationAllocate(Size));
   If R^.Saved[I].Pixels=Nil Then Begin Failed:=True;Break;End;
   Move(Layers[I].Pixels^,R^.Saved[I].Pixels^,Size);
  End;
 End;
 If Failed Then Begin
  For I:=0 To MAX_LAYERS-1 Do Begin
   If R^.Saved[I].Pixels<>Nil Then FreeMem(R^.Saved[I].Pixels,Size);
   ReleaseMesh(R^.Saved[I].Mesh);
  End;
  FreeMem(R,SizeOf(TRotationUndo));Exit;
 End;
 MeshUndoCopy:=R;
End;
Function ImportMeshLayer(M:PMesh;Const O:TMeshOptions;Target:Integer):Boolean;
Var Pixels:PByteArr;R:PRotationUndo;Name:String;I:Integer;
Begin
 ImportMeshLayer:=False;
 If (Target<0) And (LayerCount>=MAX_LAYERS) Then Exit;
 If Target>=LayerCount Then Exit;
 If Not RenderMesh(M,O,ImgW,ImgH,True,Pixels) Then Exit;
 R:=MeshUndoCopy;
 If R=Nil Then Begin FreeMem(Pixels,LongInt(ImgW)*ImgH);Exit;End;
 MakeUndoRoom; RotationUndo[UndoCount]:=R; UndoBuffers[UndoCount]:=Nil;
 Inc(UndoCount); 
 If Target<0 Then Begin
  Target:=LayerCount;Inc(LayerCount);FillChar(Layers[Target],SizeOf(TLayer),0);
  Layers[Target].Used:=True; Layers[Target].Visible:=True;
  Layers[Target].Opacity:=100; 
  Name:=M^.Source;
  For I:=Length(Name) DownTo 1 Do If Name[I] In ['\','/'] Then Begin
   Delete(Name,1,I);Break;
  End;
  Layers[Target].Name:='3D '+Copy(Name,1,17);
 End Else Begin
  If Layers[Target].Pixels<>Nil Then FreeMem(Layers[Target].Pixels,
  LongInt(ImgW)*ImgH); 
  ReleaseMesh(Layers[Target].Mesh);
 End;
 Layers[Target].Pixels:=Pixels;Layers[Target].Mesh:=M;RetainMesh(M);
 Layers[Target].MeshOptions:=O;ActiveLayer:=Target;
 SelectionActive:=False;ImageModified:=True;ImportMeshLayer:=True;
End;

Type TMeshSelection=Array[0..MAX_LAYERS-1] Of Boolean;

{ Assemblage geometrique, sans soudure ni operation booleenne. }
Function BuildMergedMesh(Const Selected:TMeshSelection;
 Transform,Spread:Boolean;Var M:PMesh;Var Error:String):Boolean;
Var I,N:Integer;J,Base,VCount,TCount:LongInt;S:PMesh;O:TMeshOptions;
 VX,VY,VZ,T,CX,CY,CZ,Extent,C1,S1,C2,S2,C3,S3,Shift,ObjectMin,ObjectMax:Double;
Begin
 BuildMergedMesh:=False;M:=Nil;Error:='';N:=0;VCount:=0;TCount:=0;
 For I:=0 To LayerCount-1 Do If Selected[I] Then Begin
  S:=Layers[I].Mesh;
  If (S=Nil) Or Not Layers[I].Used Then Begin
   Error:='La selection contient un calque sans geometrie.';Exit;
  End;
  Inc(N);Inc(VCount,S^.VertexCount);Inc(TCount,S^.TriangleCount);
 End;
 If N<2 Then Begin Error:='Selectionnez au moins deux calques 3D.';
  Exit;End;
 If (VCount>120000) Or (TCount>40000) Then Begin
  Error:='Limite : 120000 sommets et 40000 triangles.';Exit;
 End;
 M:=PMesh(RotationAllocate(SizeOf(TMesh)));
 If M=Nil Then Begin Error:='Memoire insuffisante.';Exit;End;
 FillChar(M^,SizeOf(TMesh),0);M^.References:=1;
 M^.Vertices:=PMeshVertices(RotationAllocate(SizeOf(TMeshVertices)));
 M^.Triangles:=PMeshTriangles(RotationAllocate(SizeOf(TMeshTriangles)));
 If (M^.Vertices=Nil) Or (M^.Triangles=Nil) Then Begin
  ReleaseMesh(M);Error:='Memoire insuffisante.';Exit;
 End;
 M^.Source:='Fusion 3D';M^.Format:='Scene fusionnee';
 M^.Minimum.X:=1E30;M^.Minimum.Y:=1E30;M^.Minimum.Z:=1E30;
 M^.Maximum.X:=-1E30;M^.Maximum.Y:=-1E30;M^.Maximum.Z:=-1E30;N:=0;
 For I:=0 To LayerCount-1 Do If Selected[I] Then Begin
  S:=Layers[I].Mesh;O:=Layers[I].MeshOptions;Base:=M^.VertexCount;
  CX:=(S^.Minimum.X+S^.Maximum.X)/2;
  CY:=(S^.Minimum.Y+S^.Maximum.Y)/2;
  CZ:=(S^.Minimum.Z+S^.Maximum.Z)/2;
  Extent:=MeshMax(S^.Maximum.X-S^.Minimum.X,
   MeshMax(S^.Maximum.Y-S^.Minimum.Y,S^.Maximum.Z-S^.Minimum.Z));
  If Extent<=0 Then Extent:=1;
  ObjectMin:=1E30;ObjectMax:=-1E30;
  RotationBasis(O.RX,True,C1,S1);RotationBasis(O.RY,True,C2,S2);
  RotationBasis(O.RZ,True,C3,S3);
  For J:=0 To S^.VertexCount-1 Do Begin
   VX:=S^.Vertices^[J].X;VY:=S^.Vertices^[J].Y;VZ:=S^.Vertices^[J].Z;
   If Transform Then Begin
    VX:=(VX-CX)/Extent;VY:=(VY-CY)/Extent;VZ:=(VZ-CZ)/Extent;
    T:=VY*C1-VZ*S1;VZ:=VY*S1+VZ*C1;VY:=T;
    T:=VX*C2+VZ*S2;VZ:=-VX*S2+VZ*C2;VX:=T;
    T:=VX*C3-VY*S3;VY:=VX*S3+VY*C3;VX:=T;
    VX:=VX*O.Scale/100+O.OffsetX/100;
    VY:=VY*O.Scale/100-O.OffsetY/100;VZ:=VZ*O.Scale/100;
   End;
   ObjectMin:=MeshMin(ObjectMin,VX);
   ObjectMax:=MeshMax(ObjectMax,VX);
   M^.Vertices^[M^.VertexCount].X:=VX;
   M^.Vertices^[M^.VertexCount].Y:=VY;
   M^.Vertices^[M^.VertexCount].Z:=VZ;Inc(M^.VertexCount);
   M^.Minimum.Y:=MeshMin(M^.Minimum.Y,VY);
   M^.Minimum.Z:=MeshMin(M^.Minimum.Z,VZ);
   M^.Maximum.Y:=MeshMax(M^.Maximum.Y,VY);
   M^.Maximum.Z:=MeshMax(M^.Maximum.Z,VZ);
  End;
  Shift:=0;
  If Spread And (N>0) Then
   Shift:=M^.Maximum.X-ObjectMin+
    MeshMax(0.05,(ObjectMax-ObjectMin)*0.15);
  For J:=Base To M^.VertexCount-1 Do
   M^.Vertices^[J].X:=M^.Vertices^[J].X+Shift;
  M^.Minimum.X:=MeshMin(M^.Minimum.X,ObjectMin+Shift);
  M^.Maximum.X:=MeshMax(M^.Maximum.X,ObjectMax+Shift);
  For J:=0 To S^.TriangleCount-1 Do Begin
   M^.Triangles^[M^.TriangleCount].A:=S^.Triangles^[J].A+Base;
   M^.Triangles^[M^.TriangleCount].B:=S^.Triangles^[J].B+Base;
   M^.Triangles^[M^.TriangleCount].C:=S^.Triangles^[J].C+Base;
   Inc(M^.TriangleCount);
  End;
  Inc(M^.SourceSize,S^.SourceSize);Inc(M^.Groups,S^.Groups);Inc(N);
 End;
 M^.Materials:=1;BuildMergedMesh:=True;
End;

Function CommitMergedMesh(M:PMesh;Const Selected:TMeshSelection;
 Const O:TMeshOptions;Keep:Boolean;Const Name:String):Boolean;
Var Pixels:PByteArr;R:PRotationUndo;I,J,N:Integer;
Begin
 CommitMergedMesh:=False;N:=0;
 For I:=0 To LayerCount-1 Do If Selected[I] Then Begin
  If Layers[I].Mesh=Nil Then Exit;Inc(N);
 End;
 If (M=Nil) Or (N<2) Then Exit;
 If Keep And (LayerCount>=MAX_LAYERS) Then Exit;
 If Not RenderMesh(M,O,ImgW,ImgH,True,Pixels) Then Exit;
 R:=MeshUndoCopy;
 If R=Nil Then Begin FreeMem(Pixels,LongInt(ImgW)*ImgH);Exit;End;
 MakeUndoRoom;RotationUndo[UndoCount]:=R;UndoBuffers[UndoCount]:=Nil;
 Inc(UndoCount);
 If Not Keep Then Begin
  J:=0;
  For I:=0 To LayerCount-1 Do Begin
   If Selected[I] Then FreeLayer(I)
   Else Begin
    If I<>J Then Begin
     Layers[J]:=Layers[I];FillChar(Layers[I],SizeOf(TLayer),0);
    End;
    Inc(J);
   End;
  End;
  LayerCount:=J;
 End;
 I:=LayerCount;Inc(LayerCount);FillChar(Layers[I],SizeOf(TLayer),0);
 Layers[I].Used:=True;Layers[I].Visible:=True;Layers[I].Opacity:=100;
 Layers[I].Name:=Copy(Name,1,20);Layers[I].Pixels:=Pixels;
 Layers[I].Mesh:=M;RetainMesh(M);Layers[I].MeshOptions:=O;
 ActiveLayer:=I;ImageModified:=True;SelectionActive:=False;
 CommitMergedMesh:=True;
End;

{ Panorama : source equirectangulaire, longitude horizontale et latitude. }
Type TPanoramaOptions=Record
 Yaw,Pitch,Roll,FOV,Mode,Method:Integer;
 CompositeSource,Wrap,Dither,NewLayer:Boolean;
End;
Procedure DefaultPanoramaOptions(Var O:TPanoramaOptions);
Begin
 FillChar(O,SizeOf(O),0);O.FOV:=900;O.Method:=1;
 O.Wrap:=True;O.Dither:=True;O.NewLayer:=True;
End;
Function PanoramaOptionsValid(Const O:TPanoramaOptions):Boolean;
Begin
 PanoramaOptionsValid:=(O.Yaw>=-1800) And (O.Yaw<=1800) And
  (O.Pitch>=-900) And (O.Pitch<=900) And
  (O.Roll>=-1800) And (O.Roll<=1800) And
  (O.Mode>=0) And (O.Mode<=2) And (O.Method>=0) And (O.Method<=2) And
  (O.FOV>=100) And (O.FOV<=3300) And
  ((O.Mode<>0) Or (O.FOV<=1500));
End;
Function PanoramaAtan2(Y,X:Double):Double;
Const PI_VALUE=3.141592653589793;
Begin
 If Abs(X)<1E-30 Then Begin
  If Y>0 Then PanoramaAtan2:=PI_VALUE/2
  Else If Y<0 Then PanoramaAtan2:=-PI_VALUE/2
  Else PanoramaAtan2:=0;
 End Else Begin
  PanoramaAtan2:=ArcTan(Y/X);
  If X<0 Then Begin
   If Y>=0 Then PanoramaAtan2:=ArcTan(Y/X)+PI_VALUE
   Else PanoramaAtan2:=ArcTan(Y/X)-PI_VALUE;
  End;
 End;
End;
Procedure PanoramaCoordinates(Const O:TPanoramaOptions;X,Y:Double;
 W,H:Integer;Var SX,SY:Double);
Const PI_VALUE=3.141592653589793;
Var VX,VY,VZ,T,R,A,C,S,Longitude,Latitude:Double;
Begin
 VX:=2*(X+0.5)/W-1;VY:=(1-2*(Y+0.5)/H)*H/W;
 If O.Mode=1 Then Begin
  Longitude:=VX*PI_VALUE;Latitude:=(0.5-(Y+0.5)/H)*PI_VALUE;
  VX:=Sin(Longitude)*Cos(Latitude);VY:=Sin(Latitude);
  VZ:=Cos(Longitude)*Cos(Latitude);
 End Else Begin
  A:=O.FOV*PI_VALUE/3600;
  If O.Mode=2 Then A:=A/2;
  T:=Sin(A)/Cos(A);VX:=VX*T;VY:=VY*T;VZ:=1;
  If O.Mode=2 Then Begin
   R:=Sqrt(VX*VX+VY*VY);A:=2*ArcTan(R);VZ:=Cos(A);
   If R>1E-30 Then Begin T:=Sin(A)/R;VX:=VX*T;VY:=VY*T;End;
  End;
 End;
 { Roulis dans le plan de la camera, puis latitude et longitude. }
 A:=O.Roll*PI_VALUE/1800;C:=Cos(A);S:=Sin(A);
 T:=VX*C-VY*S;VY:=VX*S+VY*C;VX:=T;
 A:=O.Pitch*PI_VALUE/1800;C:=Cos(A);S:=Sin(A);
 T:=VY*C+VZ*S;VZ:=-VY*S+VZ*C;VY:=T;
 A:=O.Yaw*PI_VALUE/1800;C:=Cos(A);S:=Sin(A);
 T:=VX*C+VZ*S;VZ:=-VX*S+VZ*C;VX:=T;
 Longitude:=PanoramaAtan2(VX,VZ);
 Latitude:=PanoramaAtan2(VY,Sqrt(VX*VX+VZ*VZ));
 SX:=(Longitude/(2*PI_VALUE)+0.5)*ImgW-0.5;
 SY:=(0.5-Latitude/PI_VALUE)*ImgH-0.5;
End;
Function PanoramaSample(Const O:TPanoramaOptions;SX,SY:Double;
 DX,DY:Integer):Byte;
Var IX,IY,J,K:Integer;FX,FY,WX,WY,Weight,Alpha,R,G,B:Double;
 Function Pixel(X,Y:Integer):Byte;
 Begin
  If O.Wrap Then Begin X:=X Mod ImgW;If X<0 Then Inc(X,ImgW);End
  Else X:=Max(0,Min(ImgW-1,X));Y:=Max(0,Min(ImgH-1,Y));
  If O.CompositeSource Then Pixel:=Composite(X,Y)
  Else Pixel:=GetLayerPixel(ActiveLayer,X,Y);
 End;
 Procedure Add(X,Y:Integer;Weight:Double);
 Var V:Byte;
 Begin
  V:=Pixel(X,Y);If V=255 Then Exit;V:=V And 15;
  Alpha:=Alpha+Weight;R:=R+VGA_R[V]*Weight;
  G:=G+VGA_G[V]*Weight;B:=B+VGA_B[V]*Weight;
 End;
Begin
 If O.Method=0 Then Begin
  PanoramaSample:=Pixel(Trunc(SX+65536.5)-65536,
   Trunc(SY+65536.5)-65536);Exit;
 End;
 IX:=Trunc(SX+65536)-65536;IY:=Trunc(SY+65536)-65536;
 FX:=SX-IX;FY:=SY-IY;Alpha:=0;R:=0;G:=0;B:=0;
 If O.Method=1 Then Begin
  For J:=0 To 1 Do For K:=0 To 1 Do Begin
   WX:=1-FX;If K=1 Then WX:=FX;WY:=1-FY;If J=1 Then WY:=FY;
   Add(IX+K,IY+J,WX*WY);
  End;
 End Else For J:=-1 To 2 Do For K:=-1 To 2 Do Begin
  Weight:=ResizeWeight(K-FX,2)*ResizeWeight(J-FY,2);
  Add(IX+K,IY+J,Weight);
 End;
 PanoramaSample:=255;If Alpha<0.5 Then Exit;
 R:=MeshMax(0,MeshMin(255,R/Alpha));
 G:=MeshMax(0,MeshMin(255,G/Alpha));
 B:=MeshMax(0,MeshMin(255,B/Alpha));
 PanoramaSample:=BlurPalette(R,G,B,DX,DY,O.Dither);
End;
{ L'apercu echantillonne les memes pixels que le rendu final. }
Function BuildPanorama(Const O:TPanoramaOptions;W,H:Integer;
 Progress:Boolean;Var Pixels:PByteArr):Boolean;
Var X,Y,DX,DY:Integer;SX,SY:Double;K:Char;Failed:Boolean;
Begin
 BuildPanorama:=False;Pixels:=Nil;
 If Not PanoramaOptionsValid(O) Or (W<1) Or (H<1) Or (W>4096) Or
  (H>4096) Or (ImgW<1) Or (ImgH<1) Or (ImgW>4096) Or (ImgH>4096)
  Then Exit;
 Pixels:=PByteArr(RotationAllocate(LongInt(W)*H));If Pixels=Nil Then Exit;
 Failed:=False;
 For Y:=0 To H-1 Do Begin
  If Progress And (Y Mod 16=0) Then Begin
   HideMouseCursor;
   FillRect(20,ScreenHeight-45,ScreenWidth-20,ScreenHeight-23,LightGray);
   SetColor(Black);OutTextXY(28,ScreenHeight-38,
    'Panorama : '+IntToStr(LongInt(Y)*100 Div H)+'% - Echap : annuler');
   ShowMouseCursor;
   If KeyPressed Then Begin K:=ReadKey;If K=#27 Then Failed:=True;End;
   If Failed Then Break;
  End;
  DY:=Min(ImgH-1,Trunc((Y+0.5)*ImgH/H));
  For X:=0 To W-1 Do Begin
   DX:=Min(ImgW-1,Trunc((X+0.5)*ImgW/W));
   PanoramaCoordinates(O,DX,DY,ImgW,ImgH,SX,SY);
   Pixels^[LongInt(Y)*W+X]:=PanoramaSample(O,SX,SY,DX,DY);
  End;
 End;
 If Failed Then Begin FreeMem(Pixels,LongInt(W)*H);Pixels:=Nil;End
 Else BuildPanorama:=True;
End;
Function ApplyPanorama(Const O:TPanoramaOptions):Boolean;
Var Pixels:PByteArr;R:PRotationUndo;Target:Integer;
Begin
 ApplyPanorama:=False;
 If O.NewLayer And (LayerCount>=MAX_LAYERS) Then Exit;
 If Not BuildPanorama(O,ImgW,ImgH,True,Pixels) Then Exit;
 R:=MeshUndoCopy;
 If R=Nil Then Begin FreeMem(Pixels,LongInt(ImgW)*ImgH);Exit;End;
 MakeUndoRoom;RotationUndo[UndoCount]:=R;UndoBuffers[UndoCount]:=Nil;
 Inc(UndoCount);Target:=ActiveLayer;
 If O.NewLayer Then Begin
  Target:=LayerCount;Inc(LayerCount);FillChar(Layers[Target],
   SizeOf(TLayer),0);Layers[Target].Used:=True;
  Layers[Target].Visible:=True;Layers[Target].Opacity:=100;
  Layers[Target].Name:='Panorama spherique';
 End Else Begin
  If Layers[Target].Pixels<>Nil Then FreeMem(Layers[Target].Pixels,
   LongInt(ImgW)*ImgH);
  ReleaseMesh(Layers[Target].Mesh);
  FillChar(Layers[Target].MeshOptions,SizeOf(TMeshOptions),0);
 End;
 Layers[Target].Pixels:=Pixels;ActiveLayer:=Target;
 SelectionActive:=False;ImageModified:=True;ApplyPanorama:=True;
End;

Type TExtrudeOptions=Record
 Depth,Resolution,Segments,Taper,Twist,Mode,Threshold,Coverage:Integer;
 CompositeSource,SelectionOnly,Invert,Caps,NewLayer:Boolean;
End;
 TExtrudeStats=Record
 Width,Height,Cells,Edges,Groups:Integer;
 Vertices,Triangles:LongInt;
 Mask:Array[0..4095] Of Byte;
End;
 TExtrudeWork=Record
 Parent:Array[0..16383] Of Integer;
 Index:Array[0..16383] Of LongInt;
 Visited:Array[0..4095] Of Byte;
 Queue:Array[0..4095] Of Integer;
End;
 PExtrudeWork=^TExtrudeWork;
Procedure DefaultExtrudeOptions(Var E:TExtrudeOptions);
Begin
 FillChar(E,SizeOf(E),0);E.Depth:=250;E.Resolution:=32;E.Segments:=1;
 E.Threshold:=128;E.Coverage:=50;E.Caps:=True;E.NewLayer:=True;
End;
Function ExtrudeOptionsValid(Const E:TExtrudeOptions):Boolean;
Begin
 ExtrudeOptionsValid:=(E.Depth>=1) And (E.Depth<=10000) And
  (E.Resolution>=8) And (E.Resolution<=64) And
  (E.Segments>=1) And (E.Segments<=8) And
  (E.Taper>=-80) And (E.Taper<=200) And
  (E.Twist>=-1800) And (E.Twist<=1800) And
  (Abs(E.Twist)<=E.Segments*450) And (E.Mode>=0) And (E.Mode<=3) And
  (E.Threshold>=0) And (E.Threshold<=255) And
  (E.Coverage>=1) And (E.Coverage<=100);
End;
Function BuildExtrusionBounds(Const E:TExtrudeOptions;Progress:Boolean;
 UseBounds:Boolean;Const Bounds:TRect;
 Var M:PMesh;Var Stats:TExtrudeStats;Var Error:String):Boolean;
Const CX:Array[0..3] Of Integer=(0,1,1,0);
 CY:Array[0..3] Of Integer=(0,0,1,1);
Var Work:PExtrudeWork;L,T,R,B,SW,SH,GW,GH,X,Y,SX,SY,I,J,N,
 Matches,RootCount,Head,Tail,Cell,NX,NY,DX,DY:Integer;
 A0,A1,B0,B1:LongInt;Scale:Double;
 Color:Byte;Lum:LongInt;Failed:Boolean;Key:Char;
 Function Solid(X,Y:Integer):Boolean;
 Begin
  Solid:=False;If (X<0) Or (Y<0) Or (X>=GW) Or (Y>=GH) Then Exit;
  Solid:=Stats.Mask[Y*GW+X]<>0;
 End;
 Function Root(Node:Integer):Integer;
 Begin
  While Work^.Parent[Node]<>Node Do Begin
   Work^.Parent[Node]:=Work^.Parent[Work^.Parent[Node]];
   Node:=Work^.Parent[Node];
  End;Root:=Node;
 End;
 Procedure Join(A,B:Integer);
 Begin A:=Root(A);B:=Root(B);If A<>B Then Work^.Parent[B]:=A;End;
 Function Cancelled:Boolean;
 Begin
  Cancelled:=False;
  If Progress And KeyPressed Then Begin Key:=ReadKey;
   Cancelled:=Key=#27;End;
 End;
 Function Vertex(Cell,Corner:Integer):LongInt;
 Var N,J,GX,GY:Integer;Base:LongInt;U,V,Q,A,C,S:Double;
 Begin
  N:=Root(Cell*4+Corner);Base:=Work^.Index[N];
  If Base<0 Then Begin
   Base:=M^.VertexCount;Work^.Index[N]:=Base;
   GX:=Cell Mod GW+CX[Corner];GY:=Cell Div GW+CY[Corner];
   U:=(GX/GW-0.5)*SW/Max(SW,SH);
   V:=(0.5-GY/GH)*SH/Max(SW,SH);
   For J:=0 To E.Segments Do Begin
    Q:=J/E.Segments;A:=E.Twist*3.141592653589793/1800*Q;
    C:=Cos(A);S:=Sin(A);Scale:=1+E.Taper/100.0*Q;
    If Not MeshVertex(M,(U*C-V*S)*Scale,(U*S+V*C)*Scale,
     E.Depth/1000.0*(0.5-Q)) Then Failed:=True;
   End;
  End;Vertex:=Base;
 End;
 Procedure Triangle(A,B,C:LongInt);
 Begin If Not MeshFace(M,A,B,C) Then Failed:=True;End;
 Procedure Enqueue(X,Y:Integer);
 Var N:Integer;
 Begin
  If Not Solid(X,Y) Then Exit;N:=Y*GW+X;
  If Work^.Visited[N]<>0 Then Exit;
  Work^.Visited[N]:=1;Work^.Queue[Tail]:=N;Inc(Tail);
 End;
Begin
 BuildExtrusionBounds:=False;M:=Nil;Work:=Nil;Error:='';
 FillChar(Stats,SizeOf(Stats),0);
 If Not ExtrudeOptionsValid(E) Then Begin
  Error:='Parametres invalides (torsion : 45 deg maximum par segment).';Exit;
 End;
 If (ImgW<1) Or (ImgH<1) Or (ImgW>4096) Or (ImgH>4096) Then Begin
  Error:='Dimensions de source invalides.';Exit;End;
 L:=0;T:=0;R:=ImgW-1;B:=ImgH-1;
 If UseBounds Then Begin
  L:=Max(0,Min(Bounds.L,Bounds.R));T:=Max(0,Min(Bounds.T,Bounds.B));
  R:=Min(ImgW-1,Max(Bounds.L,Bounds.R));
  B:=Min(ImgH-1,Max(Bounds.T,Bounds.B));
  If (L>R) Or (T>B) Then Begin Error:='Zone hors de l''image.';Exit;End;
 End Else If E.SelectionOnly Then Begin
  If Not SelectionActive Then Begin Error:='Aucune selection active.';
   Exit;End;
  L:=Max(0,Min(SelectionRect.L,SelectionRect.R));
  T:=Max(0,Min(SelectionRect.T,SelectionRect.B));
  R:=Min(ImgW-1,Max(SelectionRect.L,SelectionRect.R));
  B:=Min(ImgH-1,Max(SelectionRect.T,SelectionRect.B));
  If (L>R) Or (T>B) Then Begin Error:='Selection hors de l''image.';Exit;End;
 End;
 SW:=R-L+1;SH:=B-T+1;
 GW:=E.Resolution;GH:=Max(1,Round(E.Resolution*1.0*SH/SW));
 If SH>SW Then Begin GH:=E.Resolution;
  GW:=Max(1,Round(E.Resolution*1.0*SW/SH));End;
 Stats.Width:=GW;Stats.Height:=GH;
 Work:=PExtrudeWork(RotationAllocate(SizeOf(TExtrudeWork)));
 If Work=Nil Then Begin Error:='Memoire insuffisante.';Exit;End;
 FillChar(Work^,SizeOf(Work^),0);
 For I:=0 To GW*GH*4-1 Do Begin Work^.Parent[I]:=I;
  Work^.Index[I]:=-1;End;
 Failed:=False;
 For Y:=0 To GH-1 Do Begin
  If Cancelled Then Begin Failed:=True;Break;End;
  For X:=0 To GW-1 Do Begin
   Matches:=0;
   For SY:=0 To 2 Do For SX:=0 To 2 Do Begin
    I:=L+Min(SW-1,Trunc((X+(SX+0.5)/3)*SW/GW));
    J:=T+Min(SH-1,Trunc((Y+(SY+0.5)/3)*SH/GH));
    If E.CompositeSource Then Color:=Composite(I,J)
    Else Color:=GetLayerPixel(ActiveLayer,I,J);
    If Color<>255 Then Begin
     Color:=Color And 15;
     Lum:=LongInt(VGA_R[Color])*299+LongInt(VGA_G[Color])*587+
      LongInt(VGA_B[Color])*114;
     If (E.Mode=0) Or ((E.Mode=1) And
      (Lum>=LongInt(E.Threshold)*1000)) Or ((E.Mode=2) And
      (Lum<=LongInt(E.Threshold)*1000)) Or
      ((E.Mode=3) And (Color=(FgColor And 15))) Then Inc(Matches);
    End;
   End;
   If E.Invert Then Matches:=9-Matches;
   If Matches*100>=E.Coverage*9 Then Begin
    Stats.Mask[Y*GW+X]:=1;Inc(Stats.Cells);
   End;
  End;
 End;
 If Not Failed And (Stats.Cells=0) Then Begin
  Error:='Masque vide : modifier source, seuil ou inversion.';Failed:=True;
 End;
 RootCount:=0;
 If Not Failed Then For Y:=0 To GH-1 Do For X:=0 To GW-1 Do
  If Solid(X,Y) Then Begin
   Cell:=Y*GW+X;
   If Solid(X+1,Y) Then Begin
    Join(Cell*4+1,(Cell+1)*4);Join(Cell*4+2,(Cell+1)*4+3);
   End;
   If Solid(X,Y+1) Then Begin
    Join(Cell*4+3,(Cell+GW)*4);Join(Cell*4+2,(Cell+GW)*4+1);
   End;
   If Not Solid(X,Y-1) Then Inc(Stats.Edges);
   If Not Solid(X+1,Y) Then Inc(Stats.Edges);
   If Not Solid(X,Y+1) Then Inc(Stats.Edges);
   If Not Solid(X-1,Y) Then Inc(Stats.Edges);
   If Work^.Visited[Cell]=0 Then Begin
    Inc(Stats.Groups);Head:=0;Tail:=0;Enqueue(X,Y);
    While Head<Tail Do Begin
     N:=Work^.Queue[Head];Inc(Head);NX:=N Mod GW;NY:=N Div GW;
     Enqueue(NX-1,NY);Enqueue(NX+1,NY);Enqueue(NX,NY-1);Enqueue(NX,NY+1);
    End;
   End;
  End;
 If Not Failed Then Begin
  { Compter les racines sans fusionner les contacts diagonaux. }
  For I:=0 To GW*GH-1 Do If Stats.Mask[I]<>0 Then
   For J:=0 To 3 Do Begin N:=Root(I*4+J);
    If Work^.Index[N]<0 Then Begin Inc(RootCount);Work^.Index[N]:=0;End;
   End;
  For I:=0 To GW*GH*4-1 Do Work^.Index[I]:=-1;
  Stats.Vertices:=LongInt(RootCount)*(E.Segments+1);
  Stats.Triangles:=LongInt(Stats.Edges)*E.Segments*2;
  If E.Caps Then Inc(Stats.Triangles,LongInt(Stats.Cells)*4);
  If (Stats.Vertices>120000) Or (Stats.Triangles>40000) Then Begin
   Error:='Maillage trop dense : reduire precision ou segments.';Failed:=True;
  End;
 End;
 If Not Failed Then Begin
  M:=PMesh(RotationAllocate(SizeOf(TMesh)));
  If M=Nil Then Failed:=True
  Else Begin
   FillChar(M^,SizeOf(TMesh),0);M^.References:=1;
   M^.Vertices:=PMeshVertices(RotationAllocate(SizeOf(TMeshVertices)));
   M^.Triangles:=PMeshTriangles(RotationAllocate(SizeOf(TMeshTriangles)));
   If (M^.Vertices=Nil) Or (M^.Triangles=Nil) Then Failed:=True;
  End;
 End;
 If Not Failed Then For Y:=0 To GH-1 Do Begin
  If Cancelled Then Begin Failed:=True;Break;End;
  For X:=0 To GW-1 Do If Solid(X,Y) Then Begin
   Cell:=Y*GW+X;
   If E.Caps Then Begin
    A0:=Vertex(Cell,0);A1:=Vertex(Cell,1);
    B0:=Vertex(Cell,2);B1:=Vertex(Cell,3);
    Triangle(A0,B1,B0);Triangle(A0,B0,A1);
    Triangle(A0+E.Segments,A1+E.Segments,B0+E.Segments);
    Triangle(A0+E.Segments,B0+E.Segments,B1+E.Segments);
   End;
   For I:=0 To 3 Do Begin
    DX:=0;DY:=0;
    Case I Of 0:DY:=-1;1:DX:=1;2:DY:=1;3:DX:=-1;End;
    If Not Solid(X+DX,Y+DY) Then Begin
     A0:=Vertex(Cell,I);A1:=Vertex(Cell,(I+1) Mod 4);
     For J:=0 To E.Segments-1 Do Begin
      Triangle(A0+J,A1+J,A1+J+1);Triangle(A0+J,A1+J+1,A0+J+1);
     End;
    End;
   End;
  End;
 End;
 FreeMem(Work,SizeOf(TExtrudeWork));
 If Failed Then Begin
  ReleaseMesh(M);
  If Error='' Then Error:='Generation annulee ou memoire faible.';
  Exit;
 End;
 M^.Source:='Extrusion '+Layers[ActiveLayer].Name;
 M^.Format:='Extrusion solide';M^.Groups:=Stats.Groups;M^.Materials:=1;
 Stats.Vertices:=M^.VertexCount;Stats.Triangles:=M^.TriangleCount;
 BuildExtrusionBounds:=True;
End;
Function BuildExtrusion(Const E:TExtrudeOptions;Progress:Boolean;
 Var M:PMesh;Var Stats:TExtrudeStats;Var Error:String):Boolean;
Begin
 BuildExtrusion:=BuildExtrusionBounds(E,Progress,False,SelectionRect,
  M,Stats,Error);
End;

Function BuildPathExtrusion(Const Path:TVectorPath;
 Const E:TExtrudeOptions;Var M:PMesh;Var Stats:TExtrudeStats;
 Var Error:String):Boolean;
Const EPS=1E-10;
Var P:Array[0..127] Of TVectorPoint;Order:Array[0..127] Of Integer;
 N,I,J,K,A,B,C,Prev,Next,Remaining,RemoveAt:Integer;
 Area,MinX,MaxX,MinY,MaxY,Extent,U,V,T,Scale,Angle,CosA,SinA:Double;
 Temp:TVectorPoint;Failed,Found:Boolean;
 Function OnLine(Const A,B,C:TVectorPoint):Boolean;
 Begin OnLine:=(Abs(PathCross(A,B,C))<EPS) And
  (C.X>=MeshMin(A.X,B.X)-EPS) And (C.X<=MeshMax(A.X,B.X)+EPS) And
  (C.Y>=MeshMin(A.Y,B.Y)-EPS) And (C.Y<=MeshMax(A.Y,B.Y)+EPS);End;
 Function Intersects(Const A,B,C,D:TVectorPoint):Boolean;
 Var X,Y,Z,W:Double;Hit:Boolean;
 Begin
  X:=PathCross(A,B,C);Y:=PathCross(A,B,D);
  Z:=PathCross(C,D,A);W:=PathCross(C,D,B);
  Hit:=(((X>EPS) And (Y<-EPS)) Or ((X<-EPS) And (Y>EPS))) And
   (((Z>EPS) And (W<-EPS)) Or ((Z<-EPS) And (W>EPS)));
  Intersects:=Hit Or OnLine(A,B,C) Or OnLine(A,B,D) Or
   OnLine(C,D,A) Or OnLine(C,D,B);
 End;
 Procedure Face(A,B,C:LongInt);
 Begin If Not MeshFace(M,A,B,C) Then Failed:=True;End;
 Procedure Cap(A,B,C:Integer);
 Var S:LongInt;
 Begin
  If Not E.Caps Then Exit;S:=E.Segments+1;
  Face(A*S,B*S,C*S);
  Face(A*S+E.Segments,C*S+E.Segments,B*S+E.Segments);
 End;
Begin
 BuildPathExtrusion:=False;M:=Nil;Error:='';
 FillChar(Stats,SizeOf(Stats),0);N:=Path.Count;
 If (ImgW<1) Or (ImgH<1) Or (ImgW>4096) Or (ImgH>4096) Then Begin
  Error:='Dimensions du document invalides.';Exit;End;
 If Not ExtrudeOptionsValid(E) Then Begin
  Error:='Parametres invalides (torsion : 45 deg par segment).';Exit;End;
 If (N<3) Or (N>128) Or Not Path.Closed Then Begin
  Error:='Un trace ferme de 3 a 128 points est necessaire.';Exit;End;
 MinX:=1E30;MinY:=1E30;MaxX:=-1E30;MaxY:=-1E30;
 For I:=0 To N-1 Do Begin
  If Not ((Path.Points[I].X>=0) And (Path.Points[I].X<=1) And
   (Path.Points[I].Y>=0) And (Path.Points[I].Y<=1)) Then Begin
   Error:='Point hors du document.';Exit;
  End;
  P[I].X:=Path.Points[I].X*ImgW;P[I].Y:=-Path.Points[I].Y*ImgH;
  MinX:=MeshMin(MinX,P[I].X);MaxX:=MeshMax(MaxX,P[I].X);
  MinY:=MeshMin(MinY,P[I].Y);MaxY:=MeshMax(MaxY,P[I].Y);
 End;
 Extent:=MeshMax(MaxX-MinX,MaxY-MinY);
 If Extent<0.000001 Then Begin Error:='Trace trop petit.';Exit;End;
 For I:=0 To N-1 Do Begin
  P[I].X:=(P[I].X-(MinX+MaxX)/2)/Extent;
  P[I].Y:=(P[I].Y-(MinY+MaxY)/2)/Extent;
 End;
 For I:=0 To N-1 Do Begin
  J:=(I+1) Mod N;
  If Sqr(P[I].X-P[J].X)+Sqr(P[I].Y-P[J].Y)<EPS*EPS Then Begin
   Error:='Deux points consecutifs sont identiques.';Exit;End;
 End;
 For I:=0 To N-1 Do For J:=I+1 To N-1 Do
  If (J<>((I+1) Mod N)) And (I<>((J+1) Mod N)) Then
   If Intersects(P[I],P[(I+1) Mod N],P[J],P[(J+1) Mod N]) Then Begin
    Error:='Le trace se croise ou se touche lui-meme.';Exit;
   End;
 { Supprimer les points alignes sans changer le trace de travail. }
 Repeat
  RemoveAt:=-1;
  For I:=0 To N-1 Do Begin
   Prev:=(I+N-1) Mod N;Next:=(I+1) Mod N;
   If Abs(PathCross(P[Prev],P[I],P[Next]))<EPS Then Begin
    If (P[Prev].X-P[I].X)*(P[Next].X-P[I].X)+
     (P[Prev].Y-P[I].Y)*(P[Next].Y-P[I].Y)>=0 Then Begin
     Error:='Le trace revient sur un segment.';Exit;
    End;
    RemoveAt:=I;Break;
   End;
  End;
  If RemoveAt>=0 Then Begin
   For I:=RemoveAt To N-2 Do P[I]:=P[I+1];Dec(N);
  End;
 Until (RemoveAt<0) Or (N<3);
 If N<3 Then Begin Error:='Trace aligne : aucune surface.';Exit;End;
 Area:=0;For I:=0 To N-1 Do Begin J:=(I+1) Mod N;
  Area:=Area+P[I].X*P[J].Y-P[J].X*P[I].Y;End;
 If Abs(Area)<EPS Then Begin Error:='Surface du trace nulle.';Exit;End;
 If Area<0 Then For I:=0 To N Div 2-1 Do Begin
  Temp:=P[I];P[I]:=P[N-1-I];P[N-1-I]:=Temp;End;
 M:=PMesh(RotationAllocate(SizeOf(TMesh)));
 If M=Nil Then Begin Error:='Memoire insuffisante.';Exit;End;
 FillChar(M^,SizeOf(TMesh),0);M^.References:=1;
 M^.Vertices:=PMeshVertices(RotationAllocate(SizeOf(TMeshVertices)));
 M^.Triangles:=PMeshTriangles(RotationAllocate(SizeOf(TMeshTriangles)));
 If (M^.Vertices=Nil) Or (M^.Triangles=Nil) Then Begin
  ReleaseMesh(M);Error:='Memoire insuffisante.';Exit;End;
 Failed:=False;
 For I:=0 To N-1 Do For J:=0 To E.Segments Do Begin
  T:=J/E.Segments;Scale:=1+E.Taper/100.0*T;
  Angle:=E.Twist*3.141592653589793/1800*T;
  CosA:=Cos(Angle);SinA:=Sin(Angle);U:=P[I].X;V:=P[I].Y;
  If Not MeshVertex(M,(U*CosA-V*SinA)*Scale,(U*SinA+V*CosA)*Scale,
   E.Depth/1000.0*(0.5-T)) Then Failed:=True;
 End;
 For I:=0 To N-1 Do Order[I]:=I;Remaining:=N;
 While Remaining>3 Do Begin
  Found:=False;
  For I:=0 To Remaining-1 Do Begin
   A:=Order[(I+Remaining-1) Mod Remaining];B:=Order[I];
   C:=Order[(I+1) Mod Remaining];
   If PathCross(P[A],P[B],P[C])>EPS Then Begin
    Found:=True;
    For J:=0 To Remaining-1 Do Begin
     K:=Order[J];If (K=A) Or (K=B) Or (K=C) Then Continue;
     If (PathCross(P[A],P[B],P[K])>=-EPS) And
      (PathCross(P[B],P[C],P[K])>=-EPS) And
      (PathCross(P[C],P[A],P[K])>=-EPS) Then Found:=False;
    End;
    If Found Then Begin
     Cap(A,B,C);For J:=I To Remaining-2 Do Order[J]:=Order[J+1];
     Dec(Remaining);Break;
    End;
   End;
  End;
  If Not Found Then Begin Failed:=True;Break;End;
 End;
 If Not Failed Then Cap(Order[0],Order[1],Order[2]);
 For I:=0 To N-1 Do For J:=0 To E.Segments-1 Do Begin
  A:=I*(E.Segments+1)+J;B:=((I+1) Mod N)*(E.Segments+1)+J;
  Face(A,B+1,B);Face(A,A+1,B+1);
 End;
 If Failed Then Begin ReleaseMesh(M);
  Error:='Impossible de trianguler ce contour.';Exit;End;
 M^.Source:='Extrusion trace';M^.Format:='Trace vectoriel';
 M^.Groups:=1;M^.Materials:=1;Stats.Cells:=N;Stats.Groups:=1;Stats.Edges:=N;
 Stats.Vertices:=M^.VertexCount;Stats.Triangles:=M^.TriangleCount;
 BuildPathExtrusion:=True;
End;

{ Zone d'extrusion locale : aucune modification de la selection du document. }
Type TSelectionExtrude=Record
 Bounds:TRect;Shape,Radius,Border:Integer;
End;
Function SelectionExtrudeValid(Const R:TSelectionExtrude):Boolean;
Begin
 SelectionExtrudeValid:=(R.Bounds.L>=0) And (R.Bounds.T>=0) And
  (R.Bounds.R>=R.Bounds.L) And (R.Bounds.B>=R.Bounds.T) And
  (R.Bounds.R<ImgW) And (R.Bounds.B<ImgH) And
  (R.Shape>=0) And (R.Shape<=4) And (R.Radius>=1) And
  (R.Radius<=49) And (R.Border>=1) And (R.Border<=49);
End;
Procedure DefaultSelectionExtrude(Var R:TSelectionExtrude);
Begin
 FillChar(R,SizeOf(R),0);R.Radius:=20;R.Border:=15;
 R.Bounds.L:=0;R.Bounds.T:=0;R.Bounds.R:=ImgW-1;R.Bounds.B:=ImgH-1;
 If SelectionActive Then Begin
  R.Bounds.L:=Max(0,Min(SelectionRect.L,SelectionRect.R));
  R.Bounds.T:=Max(0,Min(SelectionRect.T,SelectionRect.B));
  R.Bounds.R:=Min(ImgW-1,Max(SelectionRect.L,SelectionRect.R));
  R.Bounds.B:=Min(ImgH-1,Max(SelectionRect.T,SelectionRect.B));
 End;
 If Not SelectionExtrudeValid(R) Then Begin
  R.Bounds.L:=0;R.Bounds.T:=0;R.Bounds.R:=ImgW-1;R.Bounds.B:=ImgH-1;
 End;
End;
Procedure SelectionExtrudePath(Const R:TSelectionExtrude;Precision:Integer;
 Var P:TVectorPath);
Var I,J,N,Corner,Steps:Integer;L,T,W,H,Radius,A,CX,CY:Double;
Begin
 FillChar(P,SizeOf(P),0);P.Closed:=True;
 If Not SelectionExtrudeValid(R) Then Exit;
 L:=R.Bounds.L;T:=R.Bounds.T;W:=R.Bounds.R-L+1;H:=R.Bounds.B-T+1;
 If R.Shape=1 Then Begin
  N:=Max(8,Min(64,Precision));P.Count:=N;
  For I:=0 To N-1 Do Begin
   A:=I*2*3.141592653589793/N;
   P.Points[I].X:=(L+W/2+Cos(A)*W/2)/ImgW;
   P.Points[I].Y:=(T+H/2+Sin(A)*H/2)/ImgH;
  End;
 End Else If R.Shape=2 Then Begin
  Steps:=Max(2,Min(16,Precision Div 4));Radius:=Min(Round(W),Round(H))*
   R.Radius/100.0;N:=0;
  For Corner:=0 To 3 Do Begin
   Case Corner Of
    0:Begin CX:=L+W-Radius;CY:=T+Radius;End;
    1:Begin CX:=L+W-Radius;CY:=T+H-Radius;End;
    2:Begin CX:=L+Radius;CY:=T+H-Radius;End;
    3:Begin CX:=L+Radius;CY:=T+Radius;End;
   End;
   For J:=0 To Steps Do Begin
    A:=(-90+Corner*90+J*90.0/Steps)*3.141592653589793/180;
    P.Points[N].X:=(CX+Radius*Cos(A))/ImgW;
    P.Points[N].Y:=(CY+Radius*Sin(A))/ImgH;Inc(N);
   End;
  End;P.Count:=N;
 End Else Begin
  P.Count:=4;
  P.Points[0].X:=L/ImgW;P.Points[0].Y:=T/ImgH;
  P.Points[1].X:=(L+W)/ImgW;P.Points[1].Y:=T/ImgH;
  P.Points[2].X:=(L+W)/ImgW;P.Points[2].Y:=(T+H)/ImgH;
  P.Points[3].X:=L/ImgW;P.Points[3].Y:=(T+H)/ImgH;
 End;
 For I:=0 To P.Count-1 Do Begin
  P.Points[I].X:=MeshMax(0,MeshMin(1,P.Points[I].X));
  P.Points[I].Y:=MeshMax(0,MeshMin(1,P.Points[I].Y));
 End;
End;
Function BuildSelectionExtrusion(Const R:TSelectionExtrude;
 Const E:TExtrudeOptions;Progress:Boolean;Var M:PMesh;
 Var Stats:TExtrudeStats;Var Error:String):Boolean;
Var P:TVectorPath;I,J,K,N,GW,GH,X,Y:Integer;
 A,B,C,D:LongInt;U,V,W,H,S,T,Angle,Scale,XX,YY,Inset:Double;
 Good,Inside:Boolean;Options:TExtrudeOptions;
 Procedure Face(A,B,C:LongInt);
 Begin If Not MeshFace(M,A,B,C) Then Good:=False;End;
 Function Node(Point,Ring:Integer):LongInt;
 Begin Node:=LongInt(Point)*(E.Segments+1)+Ring;End;
Begin
 BuildSelectionExtrusion:=False;M:=Nil;Error:='';
 FillChar(Stats,SizeOf(Stats),0);
 If Not SelectionExtrudeValid(R) Or Not ExtrudeOptionsValid(E) Then Begin
  Error:='Zone ou parametres d''extrusion invalides.';Exit;End;
 If R.Shape=4 Then Begin
  Options:=E;Options.SelectionOnly:=False;
  BuildSelectionExtrusion:=BuildExtrusionBounds(Options,Progress,True,
   R.Bounds,M,Stats,Error);
  If M<>Nil Then Begin M^.Source:='Extrusion selection';
   M^.Format:='Selection 3D';End;Exit;
 End;
 SelectionExtrudePath(R,E.Resolution,P);
 If R.Shape<>3 Then Begin
  If Not BuildPathExtrusion(P,E,M,Stats,Error) Then Exit;
 End Else Begin
  W:=R.Bounds.R-R.Bounds.L+1;H:=R.Bounds.B-R.Bounds.T+1;
  S:=MeshMax(W,H);Inset:=MeshMin(W,H)*R.Border/100.0;
  P.Count:=8;
  P.Points[4].X:=(R.Bounds.L+Inset)/ImgW;
  P.Points[4].Y:=(R.Bounds.T+Inset)/ImgH;
  P.Points[5].X:=(R.Bounds.R+1-Inset)/ImgW;
  P.Points[5].Y:=(R.Bounds.T+Inset)/ImgH;
  P.Points[6].X:=(R.Bounds.R+1-Inset)/ImgW;
  P.Points[6].Y:=(R.Bounds.B+1-Inset)/ImgH;
  P.Points[7].X:=(R.Bounds.L+Inset)/ImgW;
  P.Points[7].Y:=(R.Bounds.B+1-Inset)/ImgH;
  M:=PMesh(RotationAllocate(SizeOf(TMesh)));
  If M=Nil Then Begin Error:='Memoire insuffisante.';Exit;End;
  FillChar(M^,SizeOf(TMesh),0);M^.References:=1;
  M^.Vertices:=PMeshVertices(RotationAllocate(SizeOf(TMeshVertices)));
  M^.Triangles:=PMeshTriangles(RotationAllocate(SizeOf(TMeshTriangles)));
  If (M^.Vertices=Nil) Or (M^.Triangles=Nil) Then Begin
   ReleaseMesh(M);Error:='Memoire insuffisante.';Exit;End;
  Good:=True;
  For I:=0 To 7 Do For J:=0 To E.Segments Do Begin
   U:=(P.Points[I].X*ImgW-(R.Bounds.L+W/2))/S;
   V:=((R.Bounds.T+H/2)-P.Points[I].Y*ImgH)/S;
   T:=J/E.Segments;Scale:=1+E.Taper/100.0*T;
   Angle:=E.Twist*3.141592653589793/1800*T;
   XX:=(U*Cos(Angle)-V*Sin(Angle))*Scale;
   YY:=(U*Sin(Angle)+V*Cos(Angle))*Scale;
   If Not MeshVertex(M,XX,YY,E.Depth/1000.0*(0.5-T)) Then Good:=False;
  End;
  For I:=0 To 3 Do Begin
   J:=(I+1) Mod 4;
   If E.Caps Then Begin
    A:=Node(I,0);B:=Node(I+4,0);C:=Node(J+4,0);D:=Node(J,0);
    Face(A,B,C);Face(A,C,D);
    A:=Node(I,E.Segments);B:=Node(I+4,E.Segments);
    C:=Node(J+4,E.Segments);D:=Node(J,E.Segments);
    Face(A,C,B);Face(A,D,C);
   End;
   For K:=0 To E.Segments-1 Do Begin
    A:=Node(I,K);B:=Node(J,K);Face(A,B,B+1);Face(A,B+1,A+1);
    A:=Node(I+4,K);B:=Node(J+4,K);Face(A,B+1,B);Face(A,A+1,B+1);
   End;
  End;
  If Not Good Then Begin ReleaseMesh(M);
   Error:='Impossible de construire le cadre.';Exit;End;
  Stats.Cells:=8;Stats.Groups:=1;Stats.Edges:=8;
 End;
 M^.Source:='Extrusion selection';M^.Format:='Selection 3D';
 M^.Groups:=1;M^.Materials:=1;Stats.Vertices:=M^.VertexCount;
 Stats.Triangles:=M^.TriangleCount;
 { Masque de controle seulement : la geometrie reste vectorielle. }
 W:=R.Bounds.R-R.Bounds.L+1;H:=R.Bounds.B-R.Bounds.T+1;
 GW:=E.Resolution;GH:=Max(1,Round(E.Resolution*1.0*H/W));
 If H>W Then Begin GH:=E.Resolution;
  GW:=Max(1,Round(E.Resolution*1.0*W/H));End;
 Stats.Width:=GW;Stats.Height:=GH;
 For Y:=0 To GH-1 Do For X:=0 To GW-1 Do Begin
  U:=(R.Bounds.L+(X+0.5)*W/GW)/ImgW;
  V:=(R.Bounds.T+(Y+0.5)*H/GH)/ImgH;Inside:=False;
  N:=P.Count;If R.Shape=3 Then N:=4;
  J:=N-1;
  For I:=0 To N-1 Do Begin
   If (P.Points[I].Y>V)<>(P.Points[J].Y>V) Then
    If U<(P.Points[J].X-P.Points[I].X)*(V-P.Points[I].Y)/
     (P.Points[J].Y-P.Points[I].Y)+P.Points[I].X Then Inside:=Not Inside;
   J:=I;
  End;
  If R.Shape=3 Then Begin
   XX:=U*ImgW-R.Bounds.L;YY:=V*ImgH-R.Bounds.T;
   If (XX>Inset) And (XX<W-Inset) And (YY>Inset) And (YY<H-Inset)
    Then Inside:=False;
  End;
  If Inside Then Stats.Mask[Y*GW+X]:=1;
 End;
 BuildSelectionExtrusion:=True;
End;

Function ApplyExtrusion(const E:TExtrudeOptions;Const View:TMeshOptions;
 Var Error:String):Boolean;
Var M:PMesh;Stats:TExtrudeStats;Target:Integer;Success:Boolean;
Begin
 ApplyExtrusion:=False;
 If E.NewLayer And (LayerCount>=MAX_LAYERS) Then Begin
  Error:='Huit calques maximum : choisir Remplacer le calque.';Exit;
 End;
 If Not BuildExtrusion(E,True,M,Stats,Error) Then Exit;
 Target:=ActiveLayer;If E.NewLayer Then Target:=-1;
 Success:=ImportMeshLayer(M,View,Target);ReleaseMesh(M);
 ApplyExtrusion:=Success;
 If Not Success Then Error:='Operation annulee ou memoire faible.';
End;

Procedure RotateLayer90(Clockwise:Boolean);
Begin
 If ApplyRotation(900,Clockwise,True,True,True) Then;
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
 IH.biXPelsPerMeter:=Round(ImageDPI/0.0254);
 IH.biYPelsPerMeter:=IH.biXPelsPerMeter;

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

{ ============================================================
   PSD Save (Adobe Photoshop, Mode 3 RGB, 8 bits, no compression)
  ============================================================ }

Function SavePSD(Const FileName: String): Boolean;
Var
 F: File;
 Hdr: Array[0..25] of Byte;
 Sect: Array[0..3] of Byte;
 Comp: Array[0..1] of Byte;
 RowBuf: Array[0..4095] of Byte;
 X, Y, Ch: Integer;
 V: Byte;
Begin
 SavePSD := False;
 If (ImgW < 1) Or (ImgH < 1) Or (ImgW > 4096) Then Exit;

 Assign(F, FileName);
 {$I-} Rewrite(F, 1); {$I+}
 If IOResult <> 0 Then Exit;

 FillChar(Hdr, SizeOf(Hdr), 0);
 { '8BPS' }
 Hdr[0]:=$38; Hdr[1]:=$42; Hdr[2]:=$50; Hdr[3]:=$53;
 { Version BE16 = 1 }
 Hdr[4]:=0; Hdr[5]:=1;
 { Reserved 6 zeros : Hdr[6..11] }
 { NumChans BE16 = 3 }
 Hdr[12]:=0; Hdr[13]:=3;
 { Height BE32 }
 Hdr[14] := Byte((LongInt(ImgH) Shr 24) And $FF);
 Hdr[15] := Byte((LongInt(ImgH) Shr 16) And $FF);
 Hdr[16] := Byte((LongInt(ImgH) Shr 8) And $FF);
 Hdr[17] := Byte(LongInt(ImgH) And $FF);
 { Width BE32 }
 Hdr[18] := Byte((LongInt(ImgW) Shr 24) And $FF);
 Hdr[19] := Byte((LongInt(ImgW) Shr 16) And $FF);
 Hdr[20] := Byte((LongInt(ImgW) Shr 8) And $FF);
 Hdr[21] := Byte(LongInt(ImgW) And $FF);
 { Depth BE16 = 8 }
 Hdr[22]:=0; Hdr[23]:=8;
 { ColorMode BE16 = 3 (RGB) }
 Hdr[24]:=0; Hdr[25]:=3;
 BlockWrite(F, Hdr, 26);

 { Color Mode Data : longueur 0 }
 FillChar(Sect, 4, 0); BlockWrite(F, Sect, 4);
 { Image Resources : longueur 0 }
 BlockWrite(F, Sect, 4);
 { Layer and Mask Info : longueur 0 }
 BlockWrite(F, Sect, 4);

 { Compression BE16 = 0 (raw) }
 Comp[0]:=0; Comp[1]:=0;
 BlockWrite(F, Comp, 2);

 { Donnees planaires : R complet, puis G complet, puis B complet }
 For Ch := 0 To 2 Do
  For Y := 0 To ImgH-1 Do Begin
   For X := 0 To ImgW-1 Do Begin
    V := Composite(X, Y);
    If V=255 Then V:=15;
    If V>15 Then V:=0;
    Case Ch Of
     0: RowBuf[X] := VGA_R[V];
     1: RowBuf[X] := VGA_G[V];
     2: RowBuf[X] := VGA_B[V];
    End;
   End;
   BlockWrite(F, RowBuf, ImgW);
  End;

 Close(F);
 SavePSD := True;
End;

{ ============================================================
   TGA Save (Targa, 24-bit BGR, uncompressed, top-down)
  ============================================================ }

Function SaveTGA24(Const FileName: String): Boolean;
Var
 F: File;
 Hdr: Array[0..17] of Byte;
 RowBuf: Array[0..4095] of Byte;
 X, Y: Integer;
 V: Byte;
Begin
 SaveTGA24 := False;
 If (ImgW < 1) Or (ImgH < 1) Or (ImgW > 4096) Then Exit;

 Assign(F, FileName);
 {$I-} Rewrite(F, 1); {$I+}
 If IOResult <> 0 Then Exit;

 FillChar(Hdr, SizeOf(Hdr), 0);
 Hdr[2] := 2;                        { Uncompressed truecolor }
 Hdr[12] := Byte(ImgW And $FF);
 Hdr[13] := Byte((ImgW Shr 8) And $FF);
 Hdr[14] := Byte(ImgH And $FF);
 Hdr[15] := Byte((ImgH Shr 8) And $FF);
 Hdr[16] := 24;                      { Pixel depth }
 Hdr[17] := $20;                     { Top-down, no alpha bits }
 BlockWrite(F, Hdr, 18);

 For Y := 0 To ImgH-1 Do Begin
  For X := 0 To ImgW-1 Do Begin
   V := Composite(X, Y);
   If V=255 Then V:=15;
   If V>15 Then V:=0;
   RowBuf[X*3]   := VGA_B[V];
   RowBuf[X*3+1] := VGA_G[V];
   RowBuf[X*3+2] := VGA_R[V];
  End;
  BlockWrite(F, RowBuf, ImgW*3);
 End;

 Close(F);
 SaveTGA24 := True;
End;

{ ============================================================
   PPM Save (Portable Pixmap, P6 binary RGB)
  ============================================================ }

Function SavePPM(Const FileName: String): Boolean;
Var
 F: File;
 RowBuf: Array[0..4095] of Byte;
 Header: String;
 SW, SH: String;
 X, Y: Integer;
 V: Byte;
Begin
 SavePPM := False;
 If (ImgW < 1) Or (ImgH < 1) Or (ImgW > 4096) Then Exit;

 Assign(F, FileName);
 {$I-} Rewrite(F, 1); {$I+}
 If IOResult <> 0 Then Exit;

 Str(ImgW, SW);
 Str(ImgH, SH);
 Header := 'P6'+#10+SW+' '+SH+#10+'255'+#10;
 BlockWrite(F, Header[1], Length(Header));

 For Y := 0 To ImgH-1 Do Begin
  For X := 0 To ImgW-1 Do Begin
   V := Composite(X, Y);
   If V=255 Then V:=15;
   If V>15 Then V:=0;
   RowBuf[X*3]   := VGA_R[V];
   RowBuf[X*3+1] := VGA_G[V];
   RowBuf[X*3+2] := VGA_B[V];
  End;
  BlockWrite(F, RowBuf, ImgW*3);
 End;

 Close(F);
 SavePPM := True;
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
 ImageDPI:=72;
 If (IH.biXPelsPerMeter>=39) And (IH.biXPelsPerMeter<=377953) Then
  ImageDPI:=IH.biXPelsPerMeter*0.0254;
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
Const
 CHAR_W    = 8;
 LINE_H    = 12;
 PAD_X     = 16;
 PAD_TOP   = 28;
 PAD_BOT   = 12;
 BTN_W     = 60;
 BTN_H     = 18;
 MIN_W     = 240;
 MAX_LINES = 32;
Var X1, Y1, X2, Y2, BX1, BY1, BX2, BY2: Integer;
    Ch: Char; Done, BtnDown, InRect: Boolean;
    MX, MY, MB, OldMB: Integer;
    Lines: Array[0..MAX_LINES-1] of String;
    NLines, MaxLineLen, MaxChars, DlgW, DlgH, TextY, I: Integer;
    Para, Line, W: String;
    PStart, PEnd, Pos2, WordStart, WLen, TitleW, ContentW: Integer;

 Procedure AddLine(Const S: String);
 Begin
  If NLines < MAX_LINES Then Begin
   Lines[NLines] := S;
   If Length(S) > MaxLineLen Then MaxLineLen := Length(S);
   Inc(NLines);
  End;
 End;

 Procedure WrapParagraph(Const Pa: String);
 Begin
  Line := '';
  Pos2 := 1;
  If Pa = '' Then Begin AddLine(''); Exit; End;
  While Pos2 <= Length(Pa) Do Begin
   While (Pos2 <= Length(Pa)) And (Pa[Pos2] = ' ') Do Inc(Pos2);
   WordStart := Pos2;
   While (Pos2 <= Length(Pa)) And (Pa[Pos2] <> ' ') Do Inc(Pos2);
   WLen := Pos2 - WordStart;
   If WLen <= 0 Then Break;
   W := Copy(Pa, WordStart, WLen);
   While Length(W) > MaxChars Do Begin
    If Length(Line) > 0 Then Begin AddLine(Line); Line := ''; End;
    AddLine(Copy(W, 1, MaxChars));
    W := Copy(W, MaxChars+1, Length(W));
   End;
   If Line = '' Then Line := W
   Else If Length(Line) + 1 + Length(W) <= MaxChars Then Line := Line + ' ' + W
   Else Begin AddLine(Line); Line := W; End;
  End;
  If Line <> '' Then AddLine(Line);
 End;

Begin
 HideMouseCursor;

 { Wrap message into lines, splitting on #10 / #13 paragraph breaks }
 NLines := 0;
 MaxLineLen := 0;
 MaxChars := (ScreenWidth - 60) Div CHAR_W;
 If MaxChars > 80 Then MaxChars := 80;
 If MaxChars < 30 Then MaxChars := 30;
 PStart := 1;
 PEnd := 1;
 While PEnd <= Length(Msg) Do Begin
  If (Msg[PEnd] = #10) Or (Msg[PEnd] = #13) Then Begin
   Para := Copy(Msg, PStart, PEnd - PStart);
   WrapParagraph(Para);
   If (PEnd < Length(Msg)) And ((Msg[PEnd]=#13) And (Msg[PEnd+1]=#10)) Then Inc(PEnd);
   PStart := PEnd + 1;
  End;
  Inc(PEnd);
 End;
 If PStart <= Length(Msg) Then
  WrapParagraph(Copy(Msg, PStart, Length(Msg) - PStart + 1))
 Else If NLines = 0 Then
  AddLine('');

 { Compute dialog size }
 TitleW   := (Length(Title) + 2) * CHAR_W;
 ContentW := MaxLineLen * CHAR_W + 2*PAD_X;
 DlgW := MIN_W;
 If ContentW > DlgW Then DlgW := ContentW;
 If TitleW + 24 > DlgW Then DlgW := TitleW + 24;
 If DlgW > ScreenWidth - 20 Then DlgW := ScreenWidth - 20;

 DlgH := PAD_TOP + NLines * LINE_H + PAD_BOT + BTN_H + 10;
 If DlgH < 90 Then DlgH := 90;
 If DlgH > ScreenHeight - 40 Then DlgH := ScreenHeight - 40;

 X1 := (ScreenWidth  - DlgW) Div 2;
 Y1 := (ScreenHeight - DlgH) Div 2;
 X2 := X1 + DlgW;
 Y2 := Y1 + DlgH;

 FillRect(X1, Y1, X2, Y2, UI_BG_PANEL);
 DrawBevel(X1, Y1, X2, Y2, True);
 FillRect(X1+1, Y1+1, X2-1, Y1+18, UI_BG_DARK);
 SetColor(UI_TEXT_LITE);
 OutTextXY(X1+8, Y1+5, Title);
 SetColor(UI_TEXT);
 TextY := Y1 + PAD_TOP;
 For I := 0 To NLines-1 Do
  OutTextXY(X1 + PAD_X, TextY + I*LINE_H, Lines[I]);

 BX1 := X1 + (DlgW - BTN_W) Div 2;
 BY1 := Y2 - BTN_H - 8;
 BX2 := BX1 + BTN_W;
 BY2 := BY1 + BTN_H;
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
 FI_AddField(9, 'Resolution', IntToStr(Round(ImageDPI))+' dpi', False);

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
 Layers[LayerCount].Mesh:=Layers[ActiveLayer].Mesh;
 RetainMesh(Layers[LayerCount].Mesh);
 Layers[LayerCount].MeshOptions:=Layers[ActiveLayer].MeshOptions;
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
 Layers[LayerCount-1].Mesh:=Nil;
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
 WorkingPath.Count:=0;WorkingPath.Closed:=False;
 ImgW := 400; ImgH := 300;ImageDPI:=72;
 AllocLayer(0, 'Arriere-plan', False);
 LayerCount := 1;
 ActiveLayer := 0;
 CurrentFileName := '';
 ImageModified := False;
 ClearUndoHistory;
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
 FD_NUM_FILTERS = 11;
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
  'Tous fichiers (*.*)',
  'PPM Portable Pixmap (*.PPM)' );

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
Begin
 If FD_ModelMode Then FD_FilterLabel:='Modeles OBJ / STL'
 Else FD_FilterLabel:=FD_FILTER_LABELS[FD_FilterIdx];
End;

Function FD_ExtMatches(Const Nm: String): Boolean;
Var E: String;
Begin
 E := ExtractExt(Nm);
 If FD_ModelMode Then Begin
  FD_ExtMatches:=(E='.OBJ') Or (E='.STL');Exit;
 End;
 Case FD_FilterIdx Of
  0: FD_ExtMatches := (E='.BMP') Or (E='.DIB') Or (E='.GIF') Or (E='.PNG') Or
                      (E='.JPG') Or (E='.JPEG') Or (E='.PCX') Or (E='.TGA') Or
                      (E='.TIF') Or (E='.TIFF') Or (E='.PSD') Or (E='.PPM');
  1: FD_ExtMatches := (E='.BMP') Or (E='.DIB');
  2: FD_ExtMatches := E='.GIF';
  3: FD_ExtMatches := E='.PNG';
  4: FD_ExtMatches := (E='.JPG') Or (E='.JPEG');
  5: FD_ExtMatches := E='.PCX';
  6: FD_ExtMatches := E='.TGA';
  7: FD_ExtMatches := (E='.TIF') Or (E='.TIFF');
  8: FD_ExtMatches := E='.PSD';
  9: FD_ExtMatches := True;
  10: FD_ExtMatches := E='.PPM';
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
  If FD_ModelMode Then Exit;
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

{ ============================================================
   Dialogue Yes/No (confirmation, ecrasement fichier)
  ============================================================ }

Function YesNoDialog(Const Title, Msg: String): Boolean;
Var
 X1, Y1, X2, Y2: Integer;
 YX1, YY1, YX2, YY2: Integer;
 NX1, NY1, NX2, NY2: Integer;
 Ch: Char; Done, Res: Boolean;
 MX, MY, MB, OldMB: Integer;
Begin
 HideMouseCursor;
 X1 := ScreenWidth Div 2 - 180;
 Y1 := ScreenHeight Div 2 - 55;
 X2 := X1 + 360; Y2 := Y1 + 110;
 FillRect(X1, Y1, X2, Y2, UI_BG_PANEL);
 DrawBevel(X1, Y1, X2, Y2, True);
 FillRect(X1+1, Y1+1, X2-1, Y1+18, UI_BG_DARK);
 SetColor(UI_TEXT_LITE); OutTextXY(X1+8, Y1+5, Title);
 SetColor(UI_TEXT); OutTextXY(X1+12, Y1+38, Msg);
 YX1 := X1+90;  YY1 := Y2-32; YX2 := YX1+70; YY2 := YY1+20;
 NX1 := X1+200; NY1 := Y2-32; NX2 := NX1+70; NY2 := NY1+20;
 DrawDlgButton(YX1, YY1, YX2, YY2, 'Oui', False);
 DrawDlgButton(NX1, NY1, NX2, NY2, 'Non', False);
 ShowMouseCursor;
 While KeyPressed Do ReadKey;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 Done := False; Res := False; OldMB := 0;
 Repeat
  If KeyPressed Then Begin
   Ch := ReadKey;
   If Ch = #0 Then ReadKey
   Else If (Ch=#13) Or (UpCase(Ch)='O') Or (UpCase(Ch)='Y') Then Begin Res:=True; Done:=True; End
   Else If (Ch=#27) Or (UpCase(Ch)='N') Then Begin Res:=False; Done:=True; End;
  End;
  GetMouseStateLocal(MX, MY, MB);
  If (OldMB And 1 = 0) And (MB And 1 <> 0) Then Begin
   If (MX>=YX1) And (MX<=YX2) And (MY>=YY1) And (MY<=YY2) Then Begin Res:=True; Done:=True; End
   Else If (MX>=NX1) And (MX<=NX2) And (MY>=NY1) And (MY<=NY2) Then Begin Res:=False; Done:=True; End;
  End;
  OldMB := MB;
 Until Done;
 Repeat GetMouseStateLocal(MX, MY, MB); Until MB And 1 = 0;
 MouseButtons := 0; OldMouseButtons := 0;
 YesNoDialog := Res;
End;

Function FileExistsLocal(Const FN: String): Boolean;
Var F: File;
Begin
 Assign(F, FN);
 {$I-} Reset(F, 1); {$I+}
 If IOResult = 0 Then Begin Close(F); FileExistsLocal := True; End
 Else FileExistsLocal := False;
End;

{ ============================================================
   Selecteur de fichiers : dialogue "Enregistrer sous"
  ============================================================ }

Const
 FD_SAVE_NUM = 4;
 FD_SAVE_LABELS: Array[0..FD_SAVE_NUM-1] of String[24] = (
  'BMP (*.BMP)',
  'Photoshop PSD (*.PSD)',
  'Targa TGA (*.TGA)',
  'Portable Pixmap (*.PPM)' );
 FD_SAVE_EXT: Array[0..FD_SAVE_NUM-1] of String[4] = (
  '.BMP', '.PSD', '.TGA', '.PPM' );
 FD_SAVE_FILTERMAP: Array[0..FD_SAVE_NUM-1] of Integer = (1, 8, 6, 10);

Var
 FD_SaveFilterIdx: Integer;
 FD_MeshExportFormat:Integer;

Function FD_Save(Const Title: String; Var FN: String; Var SaveExt: String): Boolean;
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
 PathStr, Nm, Candidate, ChosenExt: String;

 Function CurFilterLabel: String;
 Begin
  If FD_MeshExportFormat=1 Then CurFilterLabel:='OBJ Wavefront'
  Else If FD_MeshExportFormat>1 Then CurFilterLabel:='STL 3D'
  Else CurFilterLabel:=FD_SAVE_LABELS[FD_SaveFilterIdx];
 End;

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
  SetColor(UI_TEXT);OutTextXY(DX1+62, DY1+22, PathStr);
  OutTextXY(DirX1, DY1+38, 'Dossiers');
  OutTextXY(FilX1, DY1+38, 'Fichiers existants');
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
  OutTextXY(TypX1+4, NamY1+4, CurFilterLabel);
  OutTextXY(TypX2-12, NamY1+4, 'v');
  ShowMouseCursor;
  DrawDlgButton(OkX1, OkY1, OkX2, OkY2, 'Enregistrer', False);
  DrawDlgButton(CcX1, CcY1, CcX2, CcY2, 'Annuler', False);
 End;

 Procedure RescanForFilter;
 Begin
  FD_FilterIdx := FD_SAVE_FILTERMAP[FD_SaveFilterIdx];
  FD_Scan;
 End;

 Procedure StripExtIfMatchesAny(Var S: String);
 Var E: String;
 Begin
  E := ExtractExt(S);
  If (E='.BMP') Or (E='.DIB') Or (E='.PSD') Or (E='.GIF') Or (E='.PNG') Or
     (E='.JPG') Or (E='.JPEG') Or (E='.PCX') Or (E='.TGA') Or (E='.TIF') Or (E='.TIFF') Or
     (E='.PPM') Then
   S := Copy(S, 1, Length(S) - Length(E));
 End;

 Procedure DoActivate;
 Var Sel, Curr: String; I: Integer;
 Begin
  If (FD_Focus = 0) And (FD_NDirs > 0) And (FD_SelDir < FD_NDirs) Then Begin
   Sel := FD_Dirs[FD_SelDir].Name;
   {$I-} ChDir(Sel); {$I+}
   If IOResult = 0 Then Begin RescanForFilter; RedrawAll; End;
   Exit;
  End;
  Sel := FD_NameBuf;
  If Sel = '' Then Exit;
  For I := 0 To FD_NDirs-1 Do
   If UpperStr(FD_Dirs[I].Name) = UpperStr(Sel) Then Begin
    {$I-} ChDir(Sel); {$I+}
    If IOResult = 0 Then Begin
     FD_NameBuf := ''; RescanForFilter; RedrawAll; Exit;
    End;
   End;
  ChosenExt := FD_SAVE_EXT[FD_SaveFilterIdx];
  If FD_MeshExportFormat>0 Then Begin
   If FD_MeshExportFormat=1 Then ChosenExt:='.OBJ' Else ChosenExt:='.STL';
   Curr:=ExtractExt(Sel);
   If Curr<>'' Then Delete(Sel,Length(Sel)-Length(Curr)+1,Length(Curr));
  End;
  Curr := ExtractExt(Sel);
  If Curr = '' Then Sel := Sel + ChosenExt
  Else If (Curr <> '.BMP') And (Curr <> '.DIB') And (Curr <> '.PSD') And
          (Curr <> '.TGA') And (Curr <> '.PPM') Then Begin
   StripExtIfMatchesAny(Sel);
   Sel := Sel + ChosenExt;
  End Else ChosenExt := Curr;
  If (Length(Sel) >= 2) And (Sel[2] = ':') Then Candidate := Sel
  Else If (Length(Sel) >= 1) And (Sel[1] = '\') Then Candidate := Sel
  Else Begin
   Candidate := FD_CurDir;
   If (Length(Candidate) > 0) And (Candidate[Length(Candidate)] <> '\') Then Candidate := Candidate + '\';
   Candidate := Candidate + Sel;
  End;
  If (FD_MeshExportFormat=0) And FileExistsLocal(Candidate) Then
   If Not YesNoDialog('Confirmation', 'Le fichier existe deja. L ecraser ?') Then Begin
    RedrawAll; Exit;
   End;
  FN := Candidate;
  SaveExt := ChosenExt;
  ResultVal := True;
  Done := True;
 End;

 Procedure DoFilterDropdown;
 Var
  DDX1, DDY1, DDX2, DDY2: Integer;
  SelF, VisRows: Integer;
  DDone: Boolean; Ch2: Char;
  DMX, DMY, DMB, DOldMB: Integer;
  Idx2: Integer;

  Procedure DrawDD;
  Var Q, RowY: Integer;
  Begin
   HideMouseCursor;
   FillRect(DDX1, DDY1, DDX2, DDY2, White);
   DrawBevel(DDX1, DDY1, DDX2, DDY2, False);
   For Q:=0 To VisRows-1 Do Begin
    RowY := DDY1+2 + Q*FD_ROWH;
    If Q = SelF Then Begin
     FillRect(DDX1+1, RowY-1, DDX2-1, RowY+FD_ROWH-2, Blue);
     SetColor(UI_TEXT_LITE);
    End Else SetColor(UI_TEXT);
    OutTextXY(DDX1+4, RowY, FD_SAVE_LABELS[Q]);
   End;
   ShowMouseCursor;
  End;

 Begin
  If FD_MeshExportFormat>0 Then Exit;
  SelF := FD_SaveFilterIdx;
  VisRows := FD_SAVE_NUM;
  DDX1 := TypX1; DDY1 := NamY2+1;
  DDX2 := TypX2; DDY2 := DDY1 + VisRows*FD_ROWH + 4;
  DrawDD;
  Repeat GetMouseStateLocal(DMX, DMY, DMB); Until DMB And 1 = 0;
  DOldMB := 0; DDone := False;
  Repeat
   If KeyPressed Then Begin
    Ch2 := ReadKey;
    If Ch2 = #0 Then Begin
     Ch2 := ReadKey;
     Case Ch2 Of
      #72: If SelF > 0 Then Begin Dec(SelF); DrawDD; End;
      #80: If SelF < FD_SAVE_NUM-1 Then Begin Inc(SelF); DrawDD; End;
     End;
    End Else Begin
     Case Ch2 Of
      #27: DDone := True;
      #13: Begin FD_SaveFilterIdx := SelF; RescanForFilter; DDone := True; End;
     End;
    End;
   End;
   GetMouseStateLocal(DMX, DMY, DMB);
   If (DOldMB And 1 = 0) And (DMB And 1 <> 0) Then Begin
    If (DMX < DDX1) Or (DMX > DDX2) Or (DMY < DDY1) Or (DMY > DDY2) Then DDone := True
    Else Begin
     Idx2 := (DMY - DDY1 - 2) Div FD_ROWH;
     If (Idx2 >= 0) And (Idx2 < FD_SAVE_NUM) Then Begin
      FD_SaveFilterIdx := Idx2; RescanForFilter; DDone := True;
     End;
    End;
   End;
   DOldMB := DMB;
  Until DDone;
  Repeat GetMouseStateLocal(DMX, DMY, DMB); Until DMB And 1 = 0;
  RedrawAll;
 End;

Begin
 FD_Save := False;
 SaveExt := '';
 { Heriter du nom propose par l'appelant }
 If FN <> '' Then Begin
  Nm := FN;
  { isoler le nom de fichier seul }
  Idx := Length(Nm);
  While (Idx > 0) And (Nm[Idx] <> '\') And (Nm[Idx] <> '/') And (Nm[Idx] <> ':') Do Dec(Idx);
  If Idx > 0 Then FD_NameBuf := Copy(Nm, Idx+1, Length(Nm)-Idx)
  Else FD_NameBuf := Nm;
 End Else FD_NameBuf := '';
 { Choisir le filtre selon l'extension proposee }
 ChosenExt := ExtractExt(FD_NameBuf);
 If ChosenExt = '.PSD' Then FD_SaveFilterIdx := 1
 Else FD_SaveFilterIdx := 0;
 FD_Focus := 2;
 FD_SelDir := 0; FD_SelFile := 0;
 RescanForFilter;
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
     FD_SelFile := Idx; FD_Focus := 1;
     FD_NameBuf := FD_Files[Idx].Name;
     RedrawAll;
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
 FD_Save := ResultVal;
End;

Function LoadFileByExt(Const FN: String; Var ErrMsg: String): Boolean;
Var Ext: String;Loaded:Boolean;
Begin
 Loaded := False;
 Loaded:=False;ErrMsg := '';
 Ext := ExtractExt(FN);
 If (Ext='.BMP') Or (Ext='.DIB') Then Loaded := LoadBMP(FN)
 Else If Ext='.GIF' Then Loaded := LoadGIF(FN)
 Else If (Ext='.JPG') Or (Ext='.JPEG') Then Loaded := LoadJPEG(FN)
 Else If Ext='.PNG' Then Loaded := LoadPNG(FN)
 Else If Ext='.PCX' Then Loaded := LoadPCX(FN)
 Else If Ext='.PSD' Then Loaded := LoadPSD(FN)
 Else If (Ext='.TGA') Or (Ext='.TIF') Or (Ext='.TIFF') Then
  ErrMsg := 'Le decodage '+Ext+' n est pas encore implemente.'
 Else
  ErrMsg := 'Extension '+Ext+' non reconnue.';
 If Loaded And (Ext<>'.BMP') And (Ext<>'.DIB') Then ImageDPI:=72;
 If Loaded Then Begin WorkingPath.Count:=0;WorkingPath.Closed:=False;End;
 LoadFileByExt:=Loaded;
End;

Procedure OpenFileAction;
Var FN, ErrMsg: String; Loaded: Boolean;
Begin
 FN := '';
 If FD_Open('Ouvrir un fichier', FN) Then Begin
  Loaded := LoadFileByExt(FN, ErrMsg);
  If Loaded Then Begin
   FI_ResetMetadata;
   FI_LoadSidecar(FN);
  End Else If ErrMsg<>'' Then
   ShowDialog('Format', ErrMsg)
  Else
   ShowDialog('Erreur', 'Impossible de charger : '+FN);
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

Function SaveByExt(Const FN: String): Boolean;
Var Ext: String;
Begin
 Ext := ExtractExt(FN);
 If Ext = '.PSD' Then SaveByExt := SavePSD(FN)
 Else If Ext = '.TGA' Then SaveByExt := SaveTGA24(FN)
 Else If Ext = '.PPM' Then SaveByExt := SavePPM(FN)
 Else SaveByExt := SaveBMP24(FN);
End;

Procedure SaveAsAction;
Var FN, SaveExt: String;
Begin
 FN := CurrentFileName;
 If FN='' Then FN := 'image.bmp';
 If FD_Save('Enregistrer sous', FN, SaveExt) Then Begin
  If SaveByExt(FN) Then Begin
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
 Else If SaveByExt(CurrentFileName) Then Begin
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
Var FN, SaveExt, BaseName: String;
    DotPos, I: Integer;
Begin
 { Pre-fill the export name from current document, swapping to .PNG-like
   suggestion is overkill; reuse current name with .TGA as a Photoshop-ish
   default for "Export As". The format dropdown lets the user pick BMP,
   PSD, TGA or PPM. }
 FN := CurrentFileName;
 If FN = '' Then BaseName := 'image'
 Else Begin
  BaseName := FN;
  DotPos := 0;
  For I := Length(BaseName) DownTo 1 Do
   If BaseName[I] = '.' Then Begin DotPos := I; Break; End
   Else If (BaseName[I] = '\') Or (BaseName[I] = '/') Or (BaseName[I] = ':') Then Break;
  If DotPos > 0 Then BaseName := Copy(BaseName, 1, DotPos-1);
 End;
 FN := BaseName + '.TGA';
 FD_SaveFilterIdx := 2;  { default to TGA in the export dialog }
 If FD_Save('Exporter sous', FN, SaveExt) Then Begin
  If SaveByExt(FN) Then
   ShowDialog('Exporter', 'Image exportee : '+FN)
  Else
   ShowDialog('Erreur', 'Echec de l export : '+FN);
 End;
 { Restore default save filter to BMP so Save As is unaffected }
 FD_SaveFilterIdx := 0;
End;

Procedure GenerateAction;
Var I, J, Count, Failed, DotPos: Integer;
    SavedVis: Array[0..MAX_LAYERS-1] of Boolean;
    Ext, LayerName, OutDir, OutPath, BaseDir, DocBase, Msg, NumStr: String;
Begin
 { Photoshop "Image Assets" generator : tout calque dont le nom se termine
   par une extension d'image reconnue (.BMP/.DIB/.PSD/.TGA/.PPM) est
   exporte comme actif individuel dans <document>-assets\. }

 If CurrentFileName <> '' Then Begin
  BaseDir := '';
  DocBase := CurrentFileName;
  For J := Length(DocBase) DownTo 1 Do
   If (DocBase[J]='\') Or (DocBase[J]='/') Or (DocBase[J]=':') Then Begin
    BaseDir := Copy(DocBase, 1, J);
    DocBase := Copy(DocBase, J+1, 255);
    Break;
   End;
  DotPos := 0;
  For J := Length(DocBase) DownTo 1 Do
   If DocBase[J] = '.' Then Begin DotPos := J; Break; End;
  If DotPos > 0 Then DocBase := Copy(DocBase, 1, DotPos-1);
  If DocBase = '' Then DocBase := 'image';
  OutDir := BaseDir + DocBase + '-assets';
 End Else
  OutDir := 'image-assets';

 {$I-} MkDir(OutDir); {$I+}
 If IOResult <> 0 Then ;  { ignore : repertoire deja existant }

 For I := 0 To MAX_LAYERS-1 Do SavedVis[I] := Layers[I].Visible;

 Count := 0;
 Failed := 0;
 For I := 0 To LayerCount-1 Do Begin
  If Not Layers[I].Used Then Continue;
  LayerName := Layers[I].Name;
  Ext := ExtractExt(LayerName);
  If (Ext='.BMP') Or (Ext='.DIB') Or (Ext='.PSD') Or
     (Ext='.TGA') Or (Ext='.PPM') Then Begin
   For J := 0 To MAX_LAYERS-1 Do Layers[J].Visible := False;
   Layers[I].Visible := True;
   OutPath := OutDir + '\' + LayerName;
   If SaveByExt(OutPath) Then Inc(Count) Else Inc(Failed);
  End;
 End;

 For I := 0 To MAX_LAYERS-1 Do Layers[I].Visible := SavedVis[I];

 If (Count = 0) And (Failed = 0) Then
  Msg := 'Aucun calque ne porte un nom se terminant par une extension '+
         'd image reconnue. Renommez vos calques avec un suffixe '+
         '.BMP, .PSD, .TGA, .PPM ou .DIB pour generer des actifs.'
 Else Begin
  Str(Count, NumStr);
  Msg := NumStr + ' actif(s) genere(s) dans ' + OutDir;
  If Failed > 0 Then Begin
   Str(Failed, NumStr);
   Msg := Msg + #13#10 + NumStr + ' echec(s) d ecriture.';
  End;
 End;

 ShowDialog('Generer', Msg);
End;

Procedure ScriptsAction;
Const
 MAX_ERRS = 8;
Var
 ScriptFN, Line, Verb, Arg, ErrMsg, Summary, NumStr: String;
 F: Text;
 LineNo, Executed, Errs, I, V, NewIdx, NumCol: Integer;
 ErrLines: Array[0..MAX_ERRS-1] of Integer;
 Ok: Boolean;

 Procedure NoteError(Ln: Integer);
 Begin
  If Errs < MAX_ERRS Then ErrLines[Errs] := Ln;
  Inc(Errs);
 End;

 Function UpCaseStr(Const S: String): String;
 Var II: Integer; T: String;
 Begin
  T := S;
  For II := 1 To Length(T) Do
   If (T[II]>='a') And (T[II]<='z') Then T[II] := Chr(Ord(T[II]) - 32);
  UpCaseStr := T;
 End;

 Procedure SplitVerbArg(Const Src: String; Var Vrb, A: String);
 Var P, II: Integer;
 Begin
  Vrb := ''; A := '';
  II := 1;
  While (II <= Length(Src)) And ((Src[II]=' ') Or (Src[II]=#9)) Do Inc(II);
  P := II;
  While (P <= Length(Src)) And (Src[P]<>' ') And (Src[P]<>#9) Do Inc(P);
  Vrb := UpCaseStr(Copy(Src, II, P-II));
  While (P <= Length(Src)) And ((Src[P]=' ') Or (Src[P]=#9)) Do Inc(P);
  A := Copy(Src, P, Length(Src) - P + 1);
  { trim trailing whitespace }
  While (Length(A) > 0) And ((A[Length(A)]=' ') Or (A[Length(A)]=#9) Or
        (A[Length(A)]=#13) Or (A[Length(A)]=#10)) Do
   A := Copy(A, 1, Length(A)-1);
 End;

 Function ParseInt(Const S: String; Var N: Integer): Boolean;
 Var Code: Integer;
 Begin
  Val(S, N, Code);
  ParseInt := Code = 0;
 End;

Begin
 ScriptFN := '';
 If Not FD_Open('Executer un script (.PSP)', ScriptFN) Then Exit;

 Assign(F, ScriptFN);
 {$I-} Reset(F); {$I+}
 If IOResult <> 0 Then Begin
  ShowDialog('Scripts', 'Impossible d ouvrir le script : '+ScriptFN);
  Exit;
 End;

 LineNo := 0;
 Executed := 0;
 Errs := 0;

 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  Inc(LineNo);
  { trim leading whitespace }
  While (Length(Line)>0) And ((Line[1]=' ') Or (Line[1]=#9)) Do Line := Copy(Line, 2, 255);
  If Line = '' Then Continue;
  If (Line[1] = '#') Or (Line[1] = ';') Then Continue;
  If (Length(Line) >= 2) And (Line[1]='/') And (Line[2]='/') Then Continue;

  SplitVerbArg(Line, Verb, Arg);
  If Verb = '' Then Continue;

  Ok := True;
  If Verb = 'OPEN' Then Begin
   Ok := LoadFileByExt(Arg, ErrMsg);
  End
  Else If Verb = 'SAVE' Then Begin
   If Arg = '' Then Begin
    If CurrentFileName = '' Then Ok := False
    Else Ok := SaveByExt(CurrentFileName);
   End Else Begin
    Ok := SaveByExt(Arg);
    If Ok Then Begin CurrentFileName := Arg; ImageModified := False; End;
   End;
  End
  Else If Verb = 'EXPORT' Then Begin
   If Arg = '' Then Ok := False Else Ok := SaveByExt(Arg);
  End
  Else If Verb = 'NEW' Then Begin
   NewImage;
  End
  Else If Verb = 'FILL' Then Begin
   If Not ParseInt(Arg, V) Then Ok := False
   Else If (V<0) Or (V>15) Then Ok := False
   Else Begin
    PushUndo;
    For NumCol := 0 To ImgH-1 Do
     For I := 0 To ImgW-1 Do
      SetLayerPixel(ActiveLayer, I, NumCol, Byte(V));
    ImageModified := True;
   End;
  End
  Else If Verb = 'FLIPH' Then FlipH
  Else If Verb = 'FLIPV' Then FlipV
  Else If Verb = 'ROTATE' Then Begin
   If UpCaseStr(Arg) = 'CW' Then RotateLayer90(True)
   Else If UpCaseStr(Arg) = 'CCW' Then RotateLayer90(False)
   Else Ok := False;
  End
  Else If Verb = 'INVERT'   Then FilterInvert
  Else If Verb = 'GRAY'     Then FilterGray
  Else If Verb = 'BLUR'     Then FilterBlur
  Else If Verb = 'SHARPEN'  Then FilterSharpen
  Else If Verb = 'BRIGHTER' Then FilterBrighter
  Else If Verb = 'DARKER'   Then FilterDarker
  Else If Verb = 'LAYER' Then Begin
   If LayerCount >= MAX_LAYERS Then Ok := False
   Else Begin
    NewIdx := LayerCount;
    If Arg = '' Then Arg := 'Calque';
    AllocLayer(NewIdx, Arg, True);
    Inc(LayerCount);
    ActiveLayer := NewIdx;
   End;
  End
  Else If Verb = 'ACTIVE' Then Begin
   If Not ParseInt(Arg, V) Then Ok := False
   Else If (V<0) Or (V>=LayerCount) Or (Not Layers[V].Used) Then Ok := False
   Else ActiveLayer := V;
  End
  Else If Verb = 'VISIBLE' Then Begin
   If Not ParseInt(Arg, V) Then Ok := False
   Else If (ActiveLayer<0) Or (Not Layers[ActiveLayer].Used) Then Ok := False
   Else Layers[ActiveLayer].Visible := V <> 0;
  End
  Else If Verb = 'ECHO' Then Begin
   ShowDialog('Script', Arg);
  End
  Else Ok := False;

  If Ok Then Inc(Executed) Else NoteError(LineNo);
 End;
 Close(F);

 Str(Executed, NumStr);
 Summary := NumStr + ' commande(s) executee(s)';
 If Errs > 0 Then Begin
  Str(Errs, NumStr);
  Summary := Summary + ', ' + NumStr + ' erreur(s)';
  Summary := Summary + ' (lignes:';
  For I := 0 To Errs-1 Do Begin
   If I >= MAX_ERRS Then Break;
   Str(ErrLines[I], NumStr);
   Summary := Summary + ' ' + NumStr;
  End;
  If Errs > MAX_ERRS Then Summary := Summary + ' ...';
  Summary := Summary + ').';
 End Else
  Summary := Summary + '.';

 ShowDialog('Scripts', Summary);
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

Procedure RotationDialog;
Var X,Y,W,H,Angle,NW,NH,MX,MY,MB,Previous,I,Code:Integer;
 Clockwise,Expand,AllLayers,Transparent,Dirty,Done,Drag,ReplaceText:Boolean;
 Edit,Message:String;K,E:Char;C,S,V,DX,DY,A:Double;
 Procedure SetAngle(Value:Integer);
 Var T:String;
 Begin
  Angle:=Max(0,Min(3600,Value));Str(Angle/10:0:1,T);Edit:=T;
  ReplaceText:=True;Message:='';Dirty:=True;
 End;
 Procedure ResetSettings;
 Begin
  Clockwise:=True;Expand:=True;AllLayers:=True;Transparent:=True;
  SetAngle(0);
 End;
 Function ValidAngle:Boolean;
 Var T:String;J:Integer;
 Begin
  T:=Edit;For J:=1 To Length(T) Do If T[J]=',' Then T[J]:='.';
  Val(T,V,Code);ValidAngle:=(Code=0) And (V>=0) And (V<=360);
  If ValidAngle Then Angle:=Round(V*10);
 End;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Procedure Button(L,T,BW:Integer;Const Text:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+24,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+24,True);SetColor(Black);
  OutTextXY(X+L+8,Y+T+8,Text);
 End;
 Procedure Option(L,T:Integer;Checked:Boolean;Const Text:String);
 Begin
  SetColor(Black);Rectangle(X+L,Y+T,X+L+12,Y+T+12);
  If Checked Then Begin
   Line(X+L+2,Y+T+6,X+L+5,Y+T+10);
   Line(X+L+5,Y+T+10,X+L+11,Y+T+2);
  End;
  OutTextXY(X+L+20,Y+T+3,Text);
 End;
 Procedure Draw;
 Var J,PX,PY,SX,SY,CX,CY,TX,TY,Radius:Integer;
     Scale:Double;Color:Byte;Text:String;
 Begin
  HideMouseCursor;FillRect(X,Y,X+W,Y+H,LightGray);
  DrawBevel(X,Y,X+W,Y+H,True);
  FillRect(X+3,Y+3,X+W-3,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Rotation de l''image - angle precis');
  SetColor(Black);
  CX:=X+126;CY:=Y+139;Radius:=72;
  SetFillStyle(SolidFill,White);FillEllipse(CX,CY,Radius,Radius);
  SetColor(DarkGray);Circle(CX,CY,Radius);
  For J:=0 To 71 Do Begin
   A:=J*Pi/36;
   TX:=Round(Sin(A)*(Radius+4));TY:=Round(-Cos(A)*(Radius+4));
   PX:=Round(Sin(A)*(Radius+8));PY:=Round(-Cos(A)*(Radius+8));
   If J Mod 3=0 Then Begin PX:=Round(Sin(A)*(Radius+13));
    PY:=Round(-Cos(A)*(Radius+13));End;
   Line(CX+TX,CY+TY,CX+PX,CY+PY);
  End;
  OutTextXY(CX-4,CY-101,'0');OutTextXY(CX+93,CY-3,'90');
  OutTextXY(CX-12,CY+94,'180');OutTextXY(CX-111,CY-3,'270');
  A:=Angle*Pi/1800;PX:=CX+Round(Sin(A)*60);PY:=CY-Round(Cos(A)*60);
  SetColor(Blue);SetLineStyle(SolidLn,0,ThickWidth);Line(CX,CY,PX,PY);
  SetLineStyle(SolidLn,0,NormWidth);SetFillStyle(SolidFill,Blue);
  FillEllipse(PX,PY,6,6);SetColor(Black);
  OutTextXY(CX-24,CY+20,Edit+' deg');
  Button(20,244,32,'-');Button(213,244,32,'+');
  FillRect(X+62,Y+244,X+203,Y+268,White);
  Rectangle(X+62,Y+244,X+203,Y+268);
  OutTextXY(X+70,Y+252,Edit+' deg');
  For J:=0 To 3 Do Button(20+J*58,278,52,IntToStr(J*90));
  RotationSize(Angle,Clockwise,Expand,NW,NH);
  RotationBasis(Angle,Clockwise,C,S);
  Scale:=Min(280000 Div Max(1,NW),184000 Div Max(1,NH))/1000;
  If Scale<=0 Then Scale:=0.001;
  For PY:=0 To 199 Do For PX:=0 To 299 Do Begin
   TX:=Trunc((PX-149.5)/Scale+(NW-1)/2+0.5+65536)-65536;
   TY:=Trunc((PY-99.5)/Scale+(NH-1)/2+0.5+65536)-65536;
   Color:=LightGray;If ((PX Div 8+PY Div 8) And 1)=0 Then Color:=White;
   If (TX>=0) And (TY>=0) And (TX<NW) And (TY<NH) Then Begin
    RotationSource(TX,TY,NW,NH,C,S,SX,SY);
    If (SX>=0) And (SY>=0) And (SX<ImgW) And (SY<ImgH) Then Begin
     If AllLayers Then Color:=Composite(SX,SY)
      Else Color:=GetLayerPixel(ActiveLayer,SX,SY);
     If Color=255 Then Begin
      Color:=LightGray;
      If ((PX Div 8+PY Div 8) And 1)=0 Then Color:=White;
     End;
    End Else If Not Transparent Then Color:=BgColor;
   End;
   PutPixel(X+290+PX,Y+58+PY,Color);
  End;
  SetColor(Black);Rectangle(X+289,Y+57,X+590,Y+258);
  OutTextXY(X+290,Y+39,'Apercu - pixels au plus proche');
  If Clockwise Then Option(290,278,True,'Sens horaire (S)')
   Else Option(290,278,False,'Sens antihoraire (S)');
  Option(290,300,Expand,'Agrandir le cadre (F)');
  If AllLayers Then Option(290,322,True,'Tous les calques (L)')
   Else Option(290,322,False,'Calque actif uniquement (L)');
  If Transparent Then Option(290,344,True,'Fond transparent (T)')
   Else Option(290,344,False,'Couleur de fond (T)');
  OutTextXY(X+20,Y+315,'Source : '+IntToStr(ImgW)+' x '+IntToStr(ImgH));
  OutTextXY(X+20,Y+333,'Sortie : '+IntToStr(NW)+' x '+IntToStr(NH));
  Str(LongInt(NW)*NH/1024:0:1,Text);
  OutTextXY(X+20,Y+351,Text+' Ko par calque');
  If (NW>4096) Or (NH>4096) Then Message:='Limite : 4096 pixels par axe.';
  If Message<>'' Then SetColor(Red);
  If Message<>'' Then OutTextXY(X+20,Y+374,Message)
  Else OutTextXY(X+20,Y+374,
   'Fleches : 1 deg. Haut/Bas : 0.1 deg. Entree : appliquer.');
  Button(20,394,120,'Reinitialiser');Button(350,394,110,'Annuler');
  Button(480,394,110,'Appliquer');
  ShowMouseCursor;Dirty:=False;
 End;
 Procedure Apply;
 Begin
  If Not ValidAngle Then Begin
   Message:='Angle attendu : 0 a 360 degres.';Dirty:=True;Exit;
  End;
  If ApplyRotation(Angle,Clockwise,Expand,AllLayers,Transparent) Then
   Done:=True
  Else Begin
  Message:='Rotation impossible : taille ou memoire.';Dirty:=True;End;
 End;
 Procedure Dial;
 Begin
  DX:=MX-(X+126);DY:=MY-(Y+139);
  If Abs(DX)+Abs(DY)<4 Then Exit;
  If DY=0 Then Begin If DX>0 Then A:=90 Else A:=270;End
  Else Begin
   A:=ArcTan(DX/-DY)*180/Pi;
   If DY>0 Then A:=A+180;If A<0 Then A:=A+360;
  End;
  SetAngle(Round(A*10));
 End;
Begin
 ResetToolTip;MenuActive:=False;W:=620;H:=428;
 X:=(ScreenWidth-W) Div 2;Y:=(ScreenHeight-H) Div 2;
 Angle:=0;Edit:='0.0';Message:='';Clockwise:=True;Expand:=True;
 AllLayers:=True;Transparent:=True;Dirty:=True;Done:=False;
 ReplaceText:=True;Drag:=False;GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;
  GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(35,48,216,230) Then Begin Drag:=True;Dial;End
   Else If Hit(62,244,203,268) Then ReplaceText:=True
   Else If Hit(20,244,52,268) Then SetAngle(Angle-10)
   Else If Hit(213,244,245,268) Then SetAngle(Angle+10)
   Else If Hit(20,278,245,302) Then Begin
    I:=(MX-X-20) Div 58;If I<=3 Then SetAngle(I*900);
   End Else If Hit(290,278,600,290) Then Begin
    Clockwise:=Not Clockwise;Dirty:=True;
   End Else If Hit(290,300,600,312) Then Begin
    Expand:=Not Expand;Message:='';Dirty:=True;
   End Else If Hit(290,322,600,334) Then Begin
    AllLayers:=Not AllLayers;Dirty:=True;
   End Else If Hit(290,344,600,356) Then Begin
    Transparent:=Not Transparent;Dirty:=True;
   End Else If Hit(20,394,140,418) Then ResetSettings
   Else If Hit(350,394,460,418) Then Done:=True
   Else If Hit(480,394,590,418) Then Apply;
  End;
  If Drag And ((MB And 1)<>0) Then Dial;
  If (MB And 1)=0 Then Drag:=False;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then Begin
    E:=ReadKey;
    Case E Of
     #75:SetAngle(Angle-10);#77:SetAngle(Angle+10);
     #72:SetAngle(Angle+1);#80:SetAngle(Angle-1);
     #71:SetAngle(0);#79:SetAngle(3600);
     #73:SetAngle(Angle+900);#81:SetAngle(Angle-900);
    End;
   End Else Case K Of
    #27:Done:=True;#13:Apply;
    #8:Begin
     If ReplaceText Then Edit:='' Else Delete(Edit,Length(Edit),1);
     ReplaceText:=False;Dirty:=True;
    End;
    '0'..'9','.',',':Begin
     If ReplaceText Then Edit:='';ReplaceText:=False;
     If Length(Edit)<8 Then Edit:=Edit+K;
     If ValidAngle Then Message:='' Else Message:='Angle invalide (0..360).';
     Dirty:=True;
    End;
    'r','R':ResetSettings;
    's','S':Begin Clockwise:=Not Clockwise;Dirty:=True;End;
    'f','F':Begin Expand:=Not Expand;Message:='';Dirty:=True;End;
    'l','L':Begin AllLayers:=Not AllLayers;Dirty:=True;End;
    't','T':Begin Transparent:=Not Transparent;Dirty:=True;End;
   End;
  End;
  Delay(10);
 Until Done;
 GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Procedure ImageSizeDialog;
Var X,Y,W,H,NW,NH,Field,PixelUnit,DocUnit,Method,MX,MY,MB,Previous,
 I,Code,BaseW,BaseH:Integer;DPI,BaseDPI,V,TW,TH,TD:Double;
 LockRatio,Resample,ScaleBrush,Dirty,Done,ReplaceText,Before,Valid:Boolean;
 Texts:Array[0..4] Of String;Message:String;K,E:Char;
 Function Decimal(Value:Double):String;
 Var T:String;
 Begin Str(Value:0:2,T);Decimal:=T;End;
 Function UnitFactor:Double;
 Begin
  Case DocUnit Of 0:UnitFactor:=2.54;1:UnitFactor:=25.4;
   Else UnitFactor:=1;End;
 End;
 Function UnitName:String;
 Begin Case DocUnit Of 0:UnitName:='cm';1:UnitName:='mm';Else
 UnitName:='pouces';End;End;
 Procedure Sync(Keep:Integer);
 Begin
  If PixelUnit=0 Then Begin
   If Keep<>0 Then Texts[0]:=IntToStr(NW);
   If Keep<>1 Then Texts[1]:=IntToStr(NH);
  End Else Begin
   If Keep<>0 Then Texts[0]:=Decimal(NW*100.0/ImgW);
   If Keep<>1 Then Texts[1]:=Decimal(NH*100.0/ImgH);
  End;
  If Keep<>2 Then Texts[2]:=Decimal(DPI);
  If Keep<>3 Then Texts[3]:=Decimal(NW/DPI*UnitFactor);
  If Keep<>4 Then Texts[4]:=Decimal(NH/DPI*UnitFactor);
  Dirty:=True;
 End;
 Procedure Focus(N:Integer);
 Begin
  Field:=N;ReplaceText:=True;BaseW:=NW;BaseH:=NH;BaseDPI:=DPI;
 End;
 Procedure Reset;
 Begin
  NW:=ImgW;NH:=ImgH;DPI:=ImageDPI;LockRatio:=True;Resample:=True;
  ScaleBrush:=False;Method:=2;PixelUnit:=0;DocUnit:=0;
  Before:=False;Message:='';Valid:=True;Sync(-1);Focus(0);
 End;
 Procedure Change;
 Var T:String;J:Integer;
 Begin
  T:=Texts[Field];For J:=1 To Length(T) Do If T[J]=',' Then T[J]:='.';
  Val(T,V,Code);Valid:=(Code=0) And (V>0);Dirty:=True;
  If Not Valid Then Begin Message:='Valeur positive attendue.';Exit;End;
  TW:=NW;TH:=NH;TD:=DPI;
  Case Field Of
   0,1:Begin
    If Not Resample Then Begin
    Valid:=False;Message:='Pixels verrouilles.';Exit;End;
    If Field=0 Then Begin
     TW:=V;If PixelUnit=1 Then TW:=ImgW*V/100;
     If LockRatio Then TH:=TW*ImgH/ImgW;
    End Else Begin
     TH:=V;If PixelUnit=1 Then TH:=ImgH*V/100;
     If LockRatio Then TW:=TH*ImgW/ImgH;
    End;
   End;
   2:Begin
    TD:=V;
    If Resample Then Begin TW:=BaseW*TD/BaseDPI;TH:=BaseH*TD/BaseDPI;End;
   End;
   3,4:Begin
    If Resample Then Begin
     If Field=3 Then Begin
      TW:=V/UnitFactor*DPI;If LockRatio Then TH:=TW*ImgH/ImgW;
     End Else Begin
      TH:=V/UnitFactor*DPI;If LockRatio Then TW:=TH*ImgW/ImgH;
     End;
    End Else If Field=3 Then TD:=ImgW*UnitFactor/V
     Else TD:=ImgH*UnitFactor/V;
   End;
  End;
  Valid:=(TW>=0.5) And (TH>=0.5) And (TW<4096.5) And (TH<4096.5)
   And (TD>=1) And (TD<=9600);
  If Not Valid Then Begin
   Message:='Pixels : 1..4096, ppp : 1..9600.';Exit;
  End;
  NW:=Max(1,Round(TW));NH:=Max(1,Round(TH));DPI:=TD;
  Message:='';Sync(Field);
 End;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+24,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+24,True);SetColor(Black);
  OutTextXY(X+L+7,Y+T+8,Caption);
 End;
 Procedure Option(T:Integer;Checked:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+302,Y+T,X+314,Y+T+12);
  If Checked Then Begin
   Line(X+304,Y+T+6,X+307,Y+T+10);Line(X+307,Y+T+10,X+313,Y+T+2);
  End;
  OutTextXY(X+322,Y+T+3,Caption);
 End;
 Function MethodName:String;
 Begin
  Case Method Of
   0:MethodName:='Au plus proche';1:MethodName:='Bilineaire';
   2:MethodName:='Bicubique';3:MethodName:='Bicubique plus lisse';
   Else MethodName:='Bicubique plus net';
  End;
 End;
 Procedure Draw;
 Var J,T,PX,PY,OX,OY,PW,PH,LCount:Integer;Scale,SX,SY:Double;
     Color:Byte;S:String;
 Begin
  HideMouseCursor;FillRect(X,Y,X+W,Y+H,LightGray);
  DrawBevel(X,Y,X+W,Y+H,True);
  FillRect(X+3,Y+3,X+W-3,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Taille de l''image - dimensions et impression');
  SetColor(Black);OutTextXY(X+20,Y+40,'Apercu - palette VGA 16 couleurs');
  PW:=NW;PH:=NH;If Before Then Begin PW:=ImgW;PH:=ImgH;End;
  Scale:=Min(242000 Div PW,200000 Div PH)/1000;
  If Scale<=0 Then Scale:=0.001;
  For PY:=0 To 211 Do For PX:=0 To 259 Do Begin
   OX:=Trunc((PX-129.5)/Scale+(PW-1)/2+0.5+65536)-65536;
   OY:=Trunc((PY-105.5)/Scale+(PH-1)/2+0.5+65536)-65536;
   Color:=LightGray;If ((PX Div 8+PY Div 8) And 1)=0 Then Color:=White;
   If (OX>=0) And (OY>=0) And (OX<PW) And (OY<PH) Then Begin
    If Before Or ((NW=ImgW) And (NH=ImgH)) Then
     Color:=Composite(OX,OY)
    Else Begin
     SX:=(OX+0.5)*ImgW/NW-0.5;SY:=(OY+0.5)*ImgH/NH-0.5;
     Color:=ResizeSample(-1,SX,SY,Method);
    End;
    If Color=255 Then Begin Color:=LightGray;
     If ((PX Div 8+PY Div 8) And 1)=0 Then Color:=White;End;
   End;
   PutPixel(X+20+PX,Y+59+PY,Color);
  End;
  SetColor(Black);Rectangle(X+19,Y+58,X+280,Y+271);
  If Before Then S:='AVANT' Else S:='APRES';
  OutTextXY(X+28,Y+65,S);Button(20,279,115,'Avant / Apres');
  Button(148,279,132,'Unite : '+UnitName);
  OutTextXY(X+302,Y+40,'Dimensions des pixels');
  For J:=0 To 4 Do Begin
   Case J Of
    0:Begin T:=64;S:='Largeur';End;
    1:Begin T:=98;S:='Hauteur';End;
    2:Begin T:=132;S:='Resolution';End;
    3:Begin T:=204;S:='Largeur';End;
    4:Begin T:=238;S:='Hauteur';End;
   End;
   SetColor(Black);OutTextXY(X+302,Y+T+8,S);
   Color:=White;If (J<2) And Not Resample Then Color:=LightGray;
   FillRect(X+392,Y+T,X+494,Y+T+23,Color);
   If J=Field Then SetColor(Blue) Else SetColor(DarkGray);
   Rectangle(X+392,Y+T,X+494,Y+T+23);SetColor(Black);
   OutTextXY(X+399,Y+T+8,Texts[J]);
   If J<2 Then Begin
    S:='pixels';If PixelUnit=1 Then S:='%';Button(505,T,90,S+' v');
   End Else If J=2 Then OutTextXY(X+507,Y+T+8,'px/pouce')
    Else OutTextXY(X+507,Y+T+8,UnitName);
  End;
  SetColor(Black);OutTextXY(X+302,Y+182,'Taille d''impression');
  Option(277,LockRatio,'Conserver les proportions');
  Option(299,Resample,'Reechantillonnage');
  Option(321,ScaleBrush,'Pinceau a l''echelle');
  Button(302,343,293,MethodName+' v');
  SetColor(Black);
  OutTextXY(X+20,Y+318,'Avant : '+IntToStr(ImgW)+' x '+IntToStr(ImgH));
  OutTextXY(X+20,Y+334,'Apres : '+IntToStr(NW)+' x '+IntToStr(NH));
  LCount:=0;For J:=0 To MAX_LAYERS-1 Do If Layers[J].Used Then Inc(LCount);
  S:=Decimal(LongInt(NW)*NH*(LCount*1.0)/1048576);
  OutTextXY(X+20,Y+350,'Calques : '+S+' Mo ('+IntToStr(LCount)+')');
  S:=Decimal(LongInt(NW)*NH*3/1048576);
  OutTextXY(X+20,Y+366,'RGB24 estime : '+S+' Mo');
  If Message<>'' Then Begin SetColor(Red);OutTextXY(X+302,Y+374,Message);End;
  Button(20,396,105,'Reinitialiser');Button(136,396,55,'50%');
  Button(202,396,60,'200%');Button(380,396,96,'Annuler');
  Button(490,396,105,'Appliquer');ShowMouseCursor;Dirty:=False;
 End;
 Procedure Choose(Kind:Integer);
 Var Items:Array[0..4] Of String;Count,Sel,L,T,BW,J,OldB,B,XM,YM:Integer;
     Finish,Accept:Boolean;Ch,Ext:Char;
 Begin
  L:=302;T:=233;BW:=293;Count:=5;Sel:=Method;
  If Kind=0 Then Begin
   Items[0]:='pixels';Items[1]:='%';Count:=2;Sel:=PixelUnit;
   L:=505;T:=166;BW:=90;
  End Else If Kind=1 Then Begin
   Items[0]:='cm';Items[1]:='mm';Items[2]:='pouces';
   Count:=3;Sel:=DocUnit;L:=148;T:=303;BW:=132;
  End Else Begin
   Items[0]:='Au plus proche';Items[1]:='Bilineaire';
   Items[2]:='Bicubique';Items[3]:='Bicubique plus lisse';
   Items[4]:='Bicubique plus net';
  End;
  Finish:=False;Accept:=False;OldB:=MB;
  Repeat
   HideMouseCursor;FillRect(X+L,Y+T,X+L+BW,Y+T+Count*22,White);
   For J:=0 To Count-1 Do Begin
    If J=Sel Then Begin
     FillRect(X+L+1,Y+T+J*22+1,X+L+BW-1,Y+T+(J+1)*22,Blue);
     SetColor(White);
    End Else SetColor(Black);
    OutTextXY(X+L+6,Y+T+J*22+7,Items[J]);
   End;
   SetColor(Black);Rectangle(X+L,Y+T,X+L+BW,Y+T+Count*22);
   ShowMouseCursor;
   Repeat
    GetMouseStateLocal(XM,YM,B);
    If ((B And 1)<>0) And ((OldB And 1)=0) Then Begin
     If (XM>=X+L) And (XM<=X+L+BW) And
        (YM>=Y+T) And (YM<Y+T+Count*22) Then Begin
      Sel:=(YM-Y-T) Div 22;Accept:=True;
     End;
     Finish:=True;
    End;
    OldB:=B;
    If KeyPressed Then Begin
     Ch:=ReadKey;
     If Ch=#0 Then Begin
      Ext:=ReadKey;
      If Ext=#72 Then Begin Sel:=(Sel+Count-1) Mod Count;Break;End;
      If Ext=#80 Then Begin Sel:=(Sel+1) Mod Count;Break;End;
     End Else If Ch=#27 Then Finish:=True
      Else If Ch=#13 Then Begin Finish:=True;Accept:=True;End;
    End;
    Delay(10);
   Until Finish;
  Until Finish;
  If Accept Then Begin
   Valid:=True;Message:='';
   If Kind=0 Then PixelUnit:=Sel
    Else If Kind=1 Then DocUnit:=Sel Else Method:=Sel;
   Sync(-1);
   If Kind=0 Then Begin
    If Resample Then Focus(0) Else Focus(2);
   End Else If Kind=1 Then Focus(3);
  End;
  GetMouseStateLocal(MX,MY,MB);Dirty:=True;
 End;
 Procedure Apply;
 Begin
  If Not Valid Then Begin Dirty:=True;Exit;End;
  If ApplyImageSize(NW,NH,DPI,Method,ScaleBrush And Resample) Then Done:=True
   Else Begin Message:='Echec : dimensions ou memoire.';Dirty:=True;End;
 End;
 Procedure Preset(Percent:Integer);
 Begin
  If Not Resample Then Exit;
  TW:=ImgW*Percent/100;TH:=ImgH*Percent/100;
  If (TW>4096) Or (TH>4096) Then Begin
   Message:='Le preset depasse 4096 pixels.';Dirty:=True;Exit;
  End;
  NW:=Max(1,Round(TW));NH:=Max(1,Round(TH));Valid:=True;
  Message:='';Sync(-1);Focus(0);
 End;
Begin
 ResetToolTip;MenuActive:=False;W:=620;H:=430;
 X:=(ScreenWidth-W) Div 2;Y:=(ScreenHeight-H) Div 2;
 Done:=False;Reset;GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(392,64,494,87) And Resample Then Focus(0)
   Else If Hit(392,98,494,121) And Resample Then Focus(1)
   Else If Hit(392,132,494,155) Then Focus(2)
   Else If Hit(392,204,494,227) Then Focus(3)
   Else If Hit(392,238,494,261) Then Focus(4)
   Else If Hit(505,64,595,121) Then Begin
    Choose(0);
   End Else If Hit(148,279,280,303) Then Begin
    Choose(1);
   End Else If Hit(20,279,135,303) Then Begin Before:=Not Before;Dirty:=True;End
   Else If Hit(302,277,600,289) And Resample Then Begin
    LockRatio:=Not LockRatio;Dirty:=True;
   End Else If Hit(302,299,600,311) Then Begin
    Resample:=Not Resample;
    If Not Resample Then Begin NW:=ImgW;NH:=ImgH;LockRatio:=True;End;
    Valid:=True;Message:='';Sync(-1);Focus(2);
   End Else If Hit(302,321,600,333) And Resample Then Begin
    ScaleBrush:=Not ScaleBrush;Dirty:=True;
   End Else If Hit(302,343,595,367) Then Begin
    Choose(2);
   End Else If Hit(20,396,125,420) Then Reset
   Else If Hit(136,396,191,420) Then Preset(50)
   Else If Hit(202,396,262,420) Then Preset(200)
   Else If Hit(380,396,476,420) Then Done:=True
   Else If Hit(490,396,595,420) Then Apply;
  End;
  Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then Begin
    E:=ReadKey;
    If E In [#72,#80] Then Begin
     Val(Texts[Field],V,Code);If Code=0 Then Begin
      If E=#72 Then V:=V+1 Else V:=V-1;
      Texts[Field]:=Decimal(V);Change;ReplaceText:=True;
     End;
    End;
   End Else Case K Of
    #27:Done:=True;#13:Apply;#9:Begin
     I:=(Field+1) Mod 5;If Not Resample And (I<2) Then I:=2;Focus(I);
    End;
    #8:Begin
     If ReplaceText Then Texts[Field]:=''
      Else Delete(Texts[Field],Length(Texts[Field]),1);
     ReplaceText:=False;Change;
    End;
    '0'..'9','.',',':Begin
     If ReplaceText Then Texts[Field]:='';ReplaceText:=False;
     If Length(Texts[Field])<9 Then Texts[Field]:=Texts[Field]+K;Change;
    End;
    'r','R':Reset;'v','V':Begin Before:=Not Before;Dirty:=True;End;
   End;
  End;
  Delay(10);
 Until Done;
 GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Procedure MotionBlurDialog;
Var O:TBlurOptions;Cache:TBlurPixels;CacheDirty,CacheReady,Before,
 AutoPreview,Dirty,Done,ReplaceText,Valid:Boolean;
 X,Y,W,H,Field,Quality,MX,MY,MB,Previous,I,Code,Drag:Integer;
 Texts:Array[0..3] Of String;Message:String;LastChange:LongInt;
 K,E:Char;V,A,DX,DY:Double;
 Procedure Sync;
 Var T:String;
 Begin
  Str(O.Angle/10:0:1,T);Texts[0]:=T;
  Texts[1]:=IntToStr(O.Distance);Texts[2]:=IntToStr(O.Amount);
  Texts[3]:=IntToStr(O.Passes);
 End;
 Procedure Changed;
 Begin
  CacheDirty:=True;Dirty:=True;LastChange:=ToolTipClock;Message:='';
  Case Quality Of 0:O.Samples:=17;1:O.Samples:=33;2:O.Samples:=65;
   3:O.Samples:=129;4:O.Samples:=Min(1025,Max(3,O.Distance*2+1));End;
 End;
 Procedure Reset;
 Begin
  O.Angle:=0;O.Distance:=10;O.Amount:=100;O.Passes:=1;O.Edges:=0;
  O.AllLayers:=False;O.Dither:=True;Quality:=0;
  Before:=False;AutoPreview:=True;Field:=0;ReplaceText:=True;Valid:=True;
  Sync;Changed;
 End;
 Procedure Change;
 Var T:String;J:Integer;
 Begin
  T:=Texts[Field];For J:=1 To Length(T) Do If T[J]=',' Then T[J]:='.';
  Val(T,V,Code);Valid:=(Code=0);Dirty:=True;
  If Valid Then Case Field Of
   0:Valid:=(V>=0) And (V<=360);
   1:Valid:=(V>=0) And (V<=512) And (V=Trunc(V));
   2:Valid:=(V>=0) And (V<=100) And (V=Trunc(V));
   3:Valid:=(V>=1) And (V<=8) And (V=Trunc(V));
  End;
  If Not Valid Then Begin Message:='Valeur hors limites.';Exit;End;
  Case Field Of 0:O.Angle:=Round(V*10);1:O.Distance:=Round(V);
   2:O.Amount:=Round(V);3:O.Passes:=Round(V);End;
  Changed;
 End;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+24,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+24,True);SetColor(Black);
  OutTextXY(X+L+7,Y+T+8,Caption);
 End;
 Procedure Option(T:Integer;Checked:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+20,Y+T,X+32,Y+T+12);
  If Checked Then Begin
   Line(X+22,Y+T+6,X+25,Y+T+10);Line(X+25,Y+T+10,X+31,Y+T+2);
  End;
  OutTextXY(X+40,Y+T+3,Caption);
 End;
 Function QualityName:String;
 Begin QualityName:=IntToStr(O.Samples)+' echantillons';End;
 Function EdgeName:String;
 Begin Case O.Edges Of 0:EdgeName:='Repeter';1:EdgeName:='Miroir';
   Else EdgeName:='Transparent';End;End;
 Procedure RefreshPreview;
 Begin
  If Not Valid Then Exit;FreeBlurPixels(Cache);CacheReady:=False;
  CacheReady:=BuildBlurPixels(O,True,Cache);CacheDirty:=False;
  If Not CacheReady Then Message:='Apercu annule ou memoire insuffisante.';
  Dirty:=True;
 End;
 Procedure Draw;
 Var PX,PY,SX,SY,J,CX,CY,R,TX,TY,T:Integer;Scale:Double;
     Color:Byte;Caption:String;
 Begin
  HideMouseCursor;FillRect(X,Y,X+W,Y+H,LightGray);
  DrawBevel(X,Y,X+W,Y+H,True);
  FillRect(X+3,Y+3,X+W-3,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Flou directionnel - angle, distance et passes');
  SetColor(Black);OutTextXY(X+20,Y+40,'Apercu - palette VGA 16 couleurs');
  Scale:=Min(244000 Div ImgW,182000 Div ImgH)/1000;
  If Scale<=0 Then Scale:=0.001;
  For PY:=0 To 193 Do For PX:=0 To 259 Do Begin
   SX:=Trunc((PX-129.5)/Scale+(ImgW-1)/2+0.5+65536)-65536;
   SY:=Trunc((PY-96.5)/Scale+(ImgH-1)/2+0.5+65536)-65536;
   Color:=255;
   If (SX>=0) And (SY>=0) And (SX<ImgW) And (SY<ImgH) Then Begin
    If Before Or Not CacheReady Then Color:=Composite(SX,SY)
    Else For J:=LayerCount-1 DownTo 0 Do
     If Layers[J].Used And Layers[J].Visible Then Begin
      Color:=Cache[J]^[LongInt(SY)*ImgW+SX];If Color<>255 Then Break;
     End;
   End;
   If Color=255 Then Begin Color:=LightGray;
    If ((PX Div 8+PY Div 8) And 1)=0 Then Color:=White;End;
   PutPixel(X+20+PX,Y+54+PY,Color);
  End;
  SetColor(Black);Rectangle(X+19,Y+53,X+280,Y+248);
  If Before Then Caption:='AVANT' Else If CacheDirty Then
  Caption:='A ACTUALISER'
   Else Caption:='APRES';OutTextXY(X+28,Y+61,Caption);
  Button(20,254,115,'Avant / Apres');Button(148,254,132,'Actualiser (P)');
  Option(286,O.AllLayers,'Tous les calques');
  Option(308,O.Dither,'Tramage des couleurs');
  Option(330,AutoPreview,'Apercu automatique');
  Button(20,354,260,'Bords : '+EdgeName+' >');
  CX:=X+450;CY:=Y+126;R:=62;
  SetFillStyle(SolidFill,White);FillEllipse(CX,CY,R,R);
  SetColor(DarkGray);Circle(CX,CY,R);
  For J:=0 To 35 Do Begin
   A:=J*Pi/18;Line(CX+Round(Cos(A)*66),CY+Round(Sin(A)*66),
    CX+Round(Cos(A)*71),CY+Round(Sin(A)*71));
  End;
  SetColor(Black);OutTextXY(CX+78,CY-3,'0');
  OutTextXY(CX-8,CY+79,'90');OutTextXY(CX-104,CY-3,'180');
  OutTextXY(CX-12,CY-87,'270');
  A:=O.Angle*Pi/1800;TX:=Round(Cos(A)*52);TY:=Round(Sin(A)*52);
  SetColor(Blue);SetLineStyle(SolidLn,0,ThickWidth);
  Line(CX-TX,CY-TY,CX+TX,CY+TY);SetLineStyle(SolidLn,0,NormWidth);
  SetFillStyle(SolidFill,Blue);FillEllipse(CX+TX,CY+TY,5,5);
  For J:=0 To 3 Do Begin
   T:=228+J*32;SetColor(Black);
   Case J Of 0:Caption:='Angle (deg)';1:Caption:='Distance';
    2:Caption:='Force (%)';3:Caption:='Passes';End;
   OutTextXY(X+302,Y+T+8,Caption);
   FillRect(X+393,Y+T,X+497,Y+T+23,White);
   If J=Field Then SetColor(Blue) Else SetColor(DarkGray);
   Rectangle(X+393,Y+T,X+497,Y+T+23);SetColor(Black);
   OutTextXY(X+400,Y+T+8,Texts[J]);
   Button(506,T,32,'-');Button(550,T,36,'+');
  End;
  SetColor(DarkGray);Line(X+302,Y+287,X+594,Y+287);
  SetFillStyle(SolidFill,Blue);
  FillEllipse(X+302+Round(O.Distance*292.0/512),Y+287,4,4);
  Button(302,356,292,'Qualite : '+QualityName+' >');
  SetColor(Black);Caption:=Message;
  If Caption='' Then
  Caption:='Distance : 0..512 px. Passes : 1..8. Echap annule.';
  OutTextXY(X+20,Y+383,Caption);
  Button(20,400,105,'Reinitialiser');Button(136,400,55,'0 deg');
  Button(202,400,65,'90 deg');Button(380,400,96,'Annuler');
  Button(490,400,105,'Appliquer');ShowMouseCursor;Dirty:=False;
 End;
 Procedure Adjust(Delta:Integer);
 Begin
  Case Field Of
   0:O.Angle:=Max(0,Min(3600,O.Angle+Delta));
   1:O.Distance:=Max(0,Min(512,O.Distance+Delta));
   2:O.Amount:=Max(0,Min(100,O.Amount+Delta));
   3:O.Passes:=Max(1,Min(8,O.Passes+Delta));
  End;
  Valid:=True;Sync;Changed;ReplaceText:=True;
 End;
 Procedure Dial;
 Begin
  DX:=MX-(X+450);DY:=MY-(Y+126);If Abs(DX)+Abs(DY)<4 Then Exit;
  If DX=0 Then Begin If DY>=0 Then A:=90 Else A:=270;End
  Else Begin A:=ArcTan(DY/DX)*180/Pi;
   If DX<0 Then A:=A+180;If A<0 Then A:=A+360;End;
  O.Angle:=Round(A*10);Valid:=True;Sync;Changed;
 End;
 Procedure Slider;
 Begin
  O.Distance:=Max(0,Min(512,Round((MX-X-302)*512.0/292)));
  Valid:=True;Sync;Changed;
 End;
 Procedure Apply;
 Begin
  If Not Valid Then Exit;
  If ApplyMotionBlur(O,True) Then Done:=True
   Else Begin Message:='Calcul annule ou memoire insuffisante.';Dirty:=True;End;
 End;
Begin
 ResetToolTip;MenuActive:=False;FillChar(Cache,SizeOf(Cache),0);
 CacheReady:=False;W:=620;H:=430;X:=(ScreenWidth-W) Div 2;
 Y:=(ScreenHeight-H) Div 2;Done:=False;Drag:=0;Reset;
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If AutoPreview And CacheDirty And Valid And Not Before And
   ((Previous And 1)=0) Then Begin
   I:=0;V:=ToolTipClock-LastChange;If V<0 Then V:=V+8640000;
   If V>=30 Then I:=1;
   If I=1 Then RefreshPreview;
  End;
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(373,49,527,204) Then Begin Drag:=1;Dial;End
   Else If Hit(302,282,595,291) Then Begin Drag:=2;Slider;End
   Else If Hit(393,228,497,347) Then Begin
    Field:=(MY-Y-228) Div 32;Field:=Min(3,Field);ReplaceText:=True;
    Dirty:=True;
   End Else If Hit(506,228,586,347) Then Begin
    Field:=Min(3,(MY-Y-228) Div 32);
    I:=1;If MX<X+542 Then I:=-1;
    If Field=0 Then I:=I*10;Adjust(I);
   End Else If Hit(20,254,135,278) Then Begin Before:=Not Before;Dirty:=True;End
   Else If Hit(148,254,280,278) Then RefreshPreview
   Else If Hit(20,286,280,298) Then Begin O.AllLayers:=Not
   O.AllLayers;Changed;End
   Else If Hit(20,308,280,320) Then Begin O.Dither:=Not O.Dither;Changed;End
   Else If Hit(20,330,280,342) Then Begin AutoPreview:=Not
   AutoPreview;Dirty:=True;End
   Else If Hit(20,354,280,378) Then Begin O.Edges:=(O.Edges+1) Mod 3;Changed;End
   Else If Hit(302,356,594,380) Then Begin Quality:=(Quality+1) Mod
   5;Changed;End
   Else If Hit(20,400,125,424) Then Reset
   Else If Hit(136,400,191,424) Then Begin O.Angle:=0;Sync;Changed;End
   Else If Hit(202,400,267,424) Then Begin O.Angle:=900;Sync;Changed;End
   Else If Hit(380,400,476,424) Then Done:=True
   Else If Hit(490,400,595,424) Then Apply;
  End;
  If (MB And 1)<>0 Then Begin
   If Drag=1 Then Dial Else If Drag=2 Then Slider;
  End;
  If (MB And 1)=0 Then Drag:=0;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then Begin E:=ReadKey;
    If E=#72 Then Adjust(1) Else If E=#80 Then Adjust(-1);
    If E=#75 Then Begin Field:=0;Adjust(-10);End;
    If E=#77 Then Begin Field:=0;Adjust(10);End;
   End Else Case K Of
    #27:Done:=True;#13:Apply;#9:Begin Field:=(Field+1) Mod
    4;ReplaceText:=True;Dirty:=True;End;
    #8:Begin
     If ReplaceText Then Texts[Field]:=''
      Else Delete(Texts[Field],Length(Texts[Field]),1);
     ReplaceText:=False;Change;
    End;
    '0'..'9','.',',':Begin
     If ReplaceText Then Texts[Field]:='';ReplaceText:=False;
     If Length(Texts[Field])<8 Then Texts[Field]:=Texts[Field]+K;Change;
    End;
    'r','R':Reset;'p','P':RefreshPreview;
    'v','V':Begin Before:=Not Before;Dirty:=True;End;
   End;
  End;
  Delay(10);
 Until Done;
 FreeBlurPixels(Cache);GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Procedure SharpenDialog;
Var O:TSharpenOptions;Cache:TBlurPixels;CacheDirty,CacheReady,Before,
 AutoPreview,Dirty,Done,Drag,ReplaceText,Valid:Boolean;
 X,Y,W,H,Field,Preset,MX,MY,MB,Previous,I,Code:Integer;
 Texts:Array[0..3] Of String;Message:String;LastChange:LongInt;
 K,E:Char;V:Double;
 Procedure Sync;
 Var T:String;
 Begin
  Texts[0]:=IntToStr(O.Amount);Str(O.Radius/10:0:1,T);Texts[1]:=T;
  Texts[2]:=IntToStr(O.Threshold);Texts[3]:=IntToStr(O.Halo);
 End;
 Procedure Changed;
 Begin
  CacheDirty:=True;Dirty:=True;LastChange:=ToolTipClock;Message:='';Preset:=-1;
 End;
 Procedure SetPreset(Value:Integer);
 Begin
  O.Luminance:=True;
  Case Value Of
   0:Begin O.Amount:=100;O.Radius:=10;O.Threshold:=3;O.Halo:=25;End;
   1:Begin O.Amount:=60;O.Radius:=8;O.Threshold:=2;O.Halo:=35;End;
   2:Begin O.Amount:=180;O.Radius:=15;O.Threshold:=5;O.Halo:=15;End;
   3:Begin O.Amount:=70;O.Radius:=12;O.Threshold:=8;O.Halo:=50;End;
   4:Begin O.Amount:=160;O.Radius:=5;O.Threshold:=1;O.Halo:=20;End;
  End;
  Valid:=True;ReplaceText:=True;Sync;Changed;Preset:=Value;
 End;
 Procedure Reset;
 Begin
  O.AllLayers:=False;O.Dither:=True;Before:=False;AutoPreview:=True;
  Field:=0;SetPreset(0);
 End;
 Procedure Change;
 Var T:String;J:Integer;
 Begin
  T:=Texts[Field];For J:=1 To Length(T) Do If T[J]=',' Then T[J]:='.';
  Val(T,V,Code);Valid:=(Code=0);Dirty:=True;
  If Valid Then Case Field Of
   0:Valid:=(V>=0) And (V<=500) And (V=Trunc(V));
   1:Valid:=(V>=0) And (V<=20);
   2:Valid:=(V>=0) And (V<=255) And (V=Trunc(V));
   3:Valid:=(V>=0) And (V<=100) And (V=Trunc(V));
  End;
  If Not Valid Then Begin Message:='Valeur hors limites.';Exit;End;
  Case Field Of 0:O.Amount:=Round(V);1:O.Radius:=Round(V*10);
   2:O.Threshold:=Round(V);3:O.Halo:=Round(V);End;
  Changed;
 End;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+24,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+24,True);SetColor(Black);
  OutTextXY(X+L+7,Y+T+8,Caption);
 End;
 Procedure Option(T:Integer;Checked:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+20,Y+T,X+32,Y+T+12);
  If Checked Then Begin
   Line(X+22,Y+T+6,X+25,Y+T+10);Line(X+25,Y+T+10,X+31,Y+T+2);
  End;
  OutTextXY(X+40,Y+T+3,Caption);
 End;
 Function PresetName:String;
 Begin
  Case Preset Of 0:PresetName:='Standard';1:PresetName:='Doux';
   2:PresetName:='Fort';3:PresetName:='Portrait';4:PresetName:='Details';
   Else PresetName:='Personnalise';End;
 End;
 Procedure RefreshPreview;
 Begin
  If Not Valid Then Exit;FreeBlurPixels(Cache);CacheReady:=False;
  CacheReady:=BuildSharpPixels(O,True,Cache);CacheDirty:=False;
  If Not CacheReady Then Message:='Apercu annule ou memoire insuffisante.';
  Dirty:=True;
 End;
 Procedure Draw;
 Var PX,PY,SX,SY,J,T:Integer;Scale:Double;
     Color:Byte;Caption:String;
 Begin
  HideMouseCursor;FillRect(X,Y,X+W,Y+H,LightGray);
  DrawBevel(X,Y,X+W,Y+H,True);
  FillRect(X+3,Y+3,X+W-3,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Nettete - quantite, rayon et seuil');
  SetColor(Black);OutTextXY(X+20,Y+40,'Apercu - palette VGA 16 couleurs');
  Scale:=Min(244000 Div ImgW,182000 Div ImgH)/1000;
  If Scale<=0 Then Scale:=0.001;
  For PY:=0 To 193 Do For PX:=0 To 259 Do Begin
   SX:=Trunc((PX-129.5)/Scale+(ImgW-1)/2+0.5+65536)-65536;
   SY:=Trunc((PY-96.5)/Scale+(ImgH-1)/2+0.5+65536)-65536;
   Color:=255;
   If (SX>=0) And (SY>=0) And (SX<ImgW) And (SY<ImgH) Then Begin
    If Before Or Not CacheReady Then Color:=Composite(SX,SY)
    Else For J:=LayerCount-1 DownTo 0 Do
     If Layers[J].Used And Layers[J].Visible Then Begin
      Color:=Cache[J]^[LongInt(SY)*ImgW+SX];If Color<>255 Then Break;
     End;
   End;
   If Color=255 Then Begin Color:=LightGray;
    If ((PX Div 8+PY Div 8) And 1)=0 Then Color:=White;End;
   PutPixel(X+20+PX,Y+54+PY,Color);
  End;
  SetColor(Black);Rectangle(X+19,Y+53,X+280,Y+248);
  If Before Then Caption:='AVANT' Else If CacheDirty Then
  Caption:='A ACTUALISER'
   Else Caption:='APRES';OutTextXY(X+28,Y+61,Caption);
  Button(20,254,115,'Avant / Apres');Button(148,254,132,'Actualiser (P)');
  Option(286,O.AllLayers,'Tous les calques');
  Option(308,O.Dither,'Tramage des couleurs');
  Option(330,AutoPreview,'Apercu automatique');
  SetColor(Black);OutTextXY(X+302,Y+40,'Masque flou gaussien');
  For J:=0 To 3 Do Begin
   T:=64+J*38;SetColor(Black);
   Case J Of 0:Caption:='Gain (%)';1:Caption:='Rayon (px)';
    2:Caption:='Seuil';3:Caption:='Anti-halos';End;
   OutTextXY(X+302,Y+T+8,Caption);
   FillRect(X+393,Y+T,X+497,Y+T+23,White);
   If J=Field Then SetColor(Blue) Else SetColor(DarkGray);
   Rectangle(X+393,Y+T,X+497,Y+T+23);SetColor(Black);
   OutTextXY(X+400,Y+T+8,Texts[J]);
   Button(506,T,32,'-');Button(550,T,36,'+');
  End;
  SetColor(Black);OutTextXY(X+302,Y+212,'Gain');
  SetColor(DarkGray);Line(X+393,Y+216,X+594,Y+216);
  SetFillStyle(SolidFill,Blue);
  FillEllipse(X+393+Round(O.Amount*201.0/500),Y+216,4,4);
  Button(302,232,292,'Prereglage : '+PresetName+' >');
  SetColor(Black);Rectangle(X+302,Y+274,X+314,Y+286);
  If O.Luminance Then Begin
   Line(X+304,Y+280,X+307,Y+284);Line(X+307,Y+284,X+313,Y+276);
  End;
  OutTextXY(X+322,Y+277,'Luminance uniquement');
  OutTextXY(X+302,Y+304,'Transparence preservee');
  OutTextXY(X+302,Y+325,'Rayon : 0..20 pixels');
  OutTextXY(X+302,Y+346,'Seuil : 0..255, halos : 0..100');
  Str(LongInt(ImgW)*ImgH*16.0/1048576:0:2,Caption);
  OutTextXY(X+302,Y+367,'Tampon : '+Caption+' Mo / calque');
  SetColor(Black);Caption:=Message;
  If Caption='' Then
  Caption:='Le seuil protege les details faibles. Echap annule le calcul.';
  OutTextXY(X+20,Y+383,Caption);
  Button(20,400,105,'Reinitialiser');Button(136,400,55,'Doux');
  Button(202,400,65,'Fort');Button(380,400,96,'Annuler');
  Button(490,400,105,'Appliquer');ShowMouseCursor;Dirty:=False;
 End;
 Procedure Adjust(Delta:Integer);
 Begin
  Case Field Of
   0:O.Amount:=Max(0,Min(500,O.Amount+Delta));
   1:O.Radius:=Max(0,Min(200,O.Radius+Delta));
   2:O.Threshold:=Max(0,Min(255,O.Threshold+Delta));
   3:O.Halo:=Max(0,Min(100,O.Halo+Delta));
  End;
  Valid:=True;Sync;Changed;ReplaceText:=True;
 End;
 Procedure Slider;
 Begin
  O.Amount:=Max(0,Min(500,Round((MX-X-393)*500.0/201)));
  Valid:=True;Sync;Changed;
 End;
 Procedure Apply;
 Begin
  If Not Valid Then Exit;
  If ApplySharpen(O,True) Then Done:=True
   Else Begin Message:='Calcul annule ou memoire insuffisante.';Dirty:=True;End;
 End;
Begin
 ResetToolTip;MenuActive:=False;FillChar(Cache,SizeOf(Cache),0);
 CacheReady:=False;W:=620;H:=430;X:=(ScreenWidth-W) Div 2;
 Y:=(ScreenHeight-H) Div 2;Done:=False;Drag:=False;Reset;
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If AutoPreview And CacheDirty And Valid And Not Before And
   ((Previous And 1)=0) Then Begin
   I:=0;V:=ToolTipClock-LastChange;If V<0 Then V:=V+8640000;
   If V>=30 Then I:=1;
   If I=1 Then RefreshPreview;
  End;
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(393,211,595,222) Then Begin Drag:=True;Field:=0;Slider;End
   Else If Hit(393,64,497,201) Then Begin
    Field:=Min(3,(MY-Y-64) Div 38);ReplaceText:=True;Dirty:=True;
   End Else If Hit(506,64,586,201) Then Begin
    Field:=Min(3,(MY-Y-64) Div 38);I:=1;If MX<X+542 Then I:=-1;
    If Field=0 Then I:=I*10;Adjust(I);
   End Else If Hit(302,232,594,256) Then SetPreset((Preset+1) Mod 5)
   Else If Hit(302,274,600,286) Then Begin
    O.Luminance:=Not O.Luminance;Changed;
   End
Else If Hit(20,254,135,278) Then Begin Before:=Not Before;Dirty:=True;End
   Else If Hit(148,254,280,278) Then RefreshPreview
   Else If Hit(20,286,280,298) Then Begin O.AllLayers:=Not
   O.AllLayers;Changed;End
   Else If Hit(20,308,280,320) Then Begin O.Dither:=Not O.Dither;Changed;End
   Else If Hit(20,330,280,342) Then Begin AutoPreview:=Not
   AutoPreview;Dirty:=True;End
   Else If Hit(20,400,125,424) Then Reset
   Else If Hit(136,400,191,424) Then SetPreset(1)
   Else If Hit(202,400,267,424) Then SetPreset(2)
   Else If Hit(380,400,476,424) Then Done:=True
   Else If Hit(490,400,595,424) Then Apply;
  End;
  If Drag And ((MB And 1)<>0) Then Slider;
  If (MB And 1)=0 Then Drag:=False;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then Begin E:=ReadKey;
    If E=#72 Then Adjust(1) Else If E=#80 Then Adjust(-1);
    If E=#75 Then Adjust(-1);
    If E=#77 Then Adjust(1);
   End Else Case K Of
    #27:Done:=True;#13:Apply;#9:Begin Field:=(Field+1) Mod
    4;ReplaceText:=True;Dirty:=True;End;
    #8:Begin
     If ReplaceText Then Texts[Field]:=''
      Else Delete(Texts[Field],Length(Texts[Field]),1);
     ReplaceText:=False;Change;
    End;
    '0'..'9','.',',':Begin
     If ReplaceText Then Texts[Field]:='';ReplaceText:=False;
     If Length(Texts[Field])<8 Then Texts[Field]:=Texts[Field]+K;Change;
    End;
    'r','R':Reset;'p','P':RefreshPreview;
    'v','V':Begin Before:=Not Before;Dirty:=True;End;
   End;
  End;
  Delay(10);
 Until Done;
 FreeBlurPixels(Cache);GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Function MeshExportExists(Const Name:String):Boolean;
Var SR:SearchRec;
Begin
 FindFirst(Name,AnyFile,SR);MeshExportExists:=DosError=0;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
End;

{ Export de geometrie autonome : les cameras restent dans le document. }
Function PrepareMeshExport(Source:PMesh;Const O:TMeshOptions;
 Transform,Center,SwapAxes,Reverse:Boolean;Factor:Double;
 Var M:PMesh;Var Error:String):Boolean;
Var I:LongInt;A:LongInt;VX,VY,VZ,T,CX,CY,CZ,Extent:Double;
 C1,S1,C2,S2,C3,S3:Double;
Begin
 PrepareMeshExport:=False;M:=Nil;Error:='';
 If (Source=Nil) Or (Factor<0.000001) Or (Factor>1000000) Then Begin
  Error:='Echelle entre 0.000001 et 1000000.';Exit;
 End;
 M:=PMesh(RotationAllocate(SizeOf(TMesh)));
 If M=Nil Then Begin Error:='Memoire insuffisante.';Exit;End;
 FillChar(M^,SizeOf(TMesh),0);M^.References:=1;
 M^.Vertices:=PMeshVertices(RotationAllocate(SizeOf(TMeshVertices)));
 M^.Triangles:=PMeshTriangles(RotationAllocate(SizeOf(TMeshTriangles)));
 If (M^.Vertices=Nil) Or (M^.Triangles=Nil) Then Begin
  ReleaseMesh(M);Error:='Memoire insuffisante.';Exit;
 End;
 CX:=(Source^.Minimum.X+Source^.Maximum.X)/2;
 CY:=(Source^.Minimum.Y+Source^.Maximum.Y)/2;
 CZ:=(Source^.Minimum.Z+Source^.Maximum.Z)/2;
 Extent:=MeshMax(Source^.Maximum.X-Source^.Minimum.X,
  MeshMax(Source^.Maximum.Y-Source^.Minimum.Y,
   Source^.Maximum.Z-Source^.Minimum.Z));
 If Extent<=0 Then Extent:=1;
 RotationBasis(O.RX,True,C1,S1);RotationBasis(O.RY,True,C2,S2);
 RotationBasis(O.RZ,True,C3,S3);
 For I:=0 To Source^.VertexCount-1 Do Begin
  VX:=Source^.Vertices^[I].X;VY:=Source^.Vertices^[I].Y;
  VZ:=Source^.Vertices^[I].Z;
  If Center Or Transform Then Begin VX:=VX-CX;VY:=VY-CY;VZ:=VZ-CZ;End;
  If Transform Then Begin
   VX:=VX/Extent;VY:=VY/Extent;VZ:=VZ/Extent;
   T:=VY*C1-VZ*S1;VZ:=VY*S1+VZ*C1;VY:=T;
   T:=VX*C2+VZ*S2;VZ:=-VX*S2+VZ*C2;VX:=T;
   T:=VX*C3-VY*S3;VY:=VX*S3+VY*C3;VX:=T;
   VX:=VX*O.Scale/100+O.OffsetX/100;
   VY:=VY*O.Scale/100-O.OffsetY/100;VZ:=VZ*O.Scale/100;
  End;
  If SwapAxes Then Begin T:=VY;VY:=VZ;VZ:=T;End;
  VX:=VX*Factor;VY:=VY*Factor;VZ:=VZ*Factor;
  If (Abs(VX)>1E12) Or (Abs(VY)>1E12) Or (Abs(VZ)>1E12) Or
   ((VX<>0) And (Abs(VX)<1E-30)) Or
   ((VY<>0) And (Abs(VY)<1E-30)) Or
   ((VZ<>0) And (Abs(VZ)<1E-30)) Then Begin
   ReleaseMesh(M);Error:='Coordonnees hors limites apres conversion.';Exit;
  End;
  MeshVertex(M,VX,VY,VZ);
 End;
 M^.TriangleCount:=Source^.TriangleCount;
 For I:=0 To M^.TriangleCount-1 Do Begin
  M^.Triangles^[I]:=Source^.Triangles^[I];
  { L'echange Y/Z change la parite du repere : corriger les faces. }
  If SwapAxes<>Reverse Then Begin
   A:=M^.Triangles^[I].B;M^.Triangles^[I].B:=M^.Triangles^[I].C;
   M^.Triangles^[I].C:=A;
  End;
 End;
 M^.Source:=Source^.Source;M^.Format:=Source^.Format;
 M^.Groups:=Source^.Groups;M^.Materials:=0;
 { Centrage final aussi apres application des decalages du calque. }
 If Center And Transform Then Begin
  CX:=(M^.Minimum.X+M^.Maximum.X)/2;
  CY:=(M^.Minimum.Y+M^.Maximum.Y)/2;
  CZ:=(M^.Minimum.Z+M^.Maximum.Z)/2;
  For I:=0 To M^.VertexCount-1 Do Begin
   M^.Vertices^[I].X:=M^.Vertices^[I].X-CX;
   M^.Vertices^[I].Y:=M^.Vertices^[I].Y-CY;
   M^.Vertices^[I].Z:=M^.Vertices^[I].Z-CZ;
  End;
  M^.Minimum.X:=M^.Minimum.X-CX;M^.Maximum.X:=M^.Maximum.X-CX;
  M^.Minimum.Y:=M^.Minimum.Y-CY;M^.Maximum.Y:=M^.Maximum.Y-CY;
  M^.Minimum.Z:=M^.Minimum.Z-CZ;M^.Maximum.Z:=M^.Maximum.Z-CZ;
 End;
 PrepareMeshExport:=True;
End;

Function MeshExportNumber(V:Double):String;
Var S:String;
Begin
 Str(V:24,S);While (Length(S)>0) And (S[1]=' ') Do Delete(S,1,1);
 MeshExportNumber:=S;
End;
Procedure MeshExportNormal(M:PMesh;I:LongInt;Var N:TMeshVector);
Var A,B,C:TMeshVector;X,Y,Z,L:Double;
Begin
 A:=M^.Vertices^[M^.Triangles^[I].A];
 B:=M^.Vertices^[M^.Triangles^[I].B];
 C:=M^.Vertices^[M^.Triangles^[I].C];
 X:=(Double(B.Y)-A.Y)*(Double(C.Z)-A.Z)-(Double(B.Z)-A.Z)*(Double(C.Y)-A.Y);
 Y:=(Double(B.Z)-A.Z)*(Double(C.X)-A.X)-(Double(B.X)-A.X)*(Double(C.Z)-A.Z);
 Z:=(Double(B.X)-A.X)*(Double(C.Y)-A.Y)-(Double(B.Y)-A.Y)*(Double(C.X)-A.X);
 L:=Sqrt(X*X+Y*Y+Z*Z);If L=0 Then L:=1;
 N.X:=X/L;N.Y:=Y/L;N.Z:=Z/L;
End;
{ Meme encodeur pour mesurer exactement et pour ecrire. }
Function MeshExportStream(M:PMesh;Format:Integer;Normals,Writing,
 Progress:Boolean;Var F:File;Var Bytes:LongInt):Boolean;
Var Failed:Boolean;I,J,Index:LongInt;N,V:TMeshVector;
 Header:Array[0..83] Of Byte;RecordData:Array[0..49] Of Byte;
 S:String;K:Char;
 Procedure Emit(Var Data;Size:LongInt);
 Var Written:LongInt;
 Begin
  If Failed Then Exit;
  If Writing Then Begin
   {$I-}BlockWrite(F,Data,Size,Written);{$I+}
   Failed:=(IOResult<>0) Or (Written<>Size);
  End;
  Inc(Bytes,Size);
 End;
 Procedure Line(S:String);
 Begin S:=S+#13#10;Emit(S[1],Length(S));End;
 Function VectorText(Const V:TMeshVector):String;
 Begin VectorText:=MeshExportNumber(V.X)+' '+MeshExportNumber(V.Y)+
  ' '+MeshExportNumber(V.Z);End;
 Procedure PutLong(Var Data;Position:Integer;Value:LongWord);
 Var P:^Byte;J:Integer;
 Begin
  P:=@Data;Inc(P,Position);
  For J:=0 To 3 Do Begin P^:=Value And 255;Value:=Value Shr 8;Inc(P);End;
 End;
 Procedure PutFloat(Position:Integer;Value:Single);
 Var Bits:LongWord;
 Begin Move(Value,Bits,4);PutLong(RecordData,Position,Bits);End;
Begin
 MeshExportStream:=False;Bytes:=0;Failed:=False;
 If (M=Nil) Or (Format<0) Or (Format>2) Then Exit;
 If Format=0 Then Begin
  Line('# CloneDRAW PSP - geometry only');Line('o CloneDRAW');
  For I:=0 To M^.VertexCount-1 Do Line('v '+VectorText(M^.Vertices^[I]));
 End Else If Format=1 Then Line('solid CloneDRAW')
 Else Begin
  FillChar(Header,SizeOf(Header),0);S:='CloneDRAW PSP binary STL';
  Move(S[1],Header[0],Length(S));
  PutLong(Header,80,M^.TriangleCount);Emit(Header,SizeOf(Header));
 End;
 For I:=0 To M^.TriangleCount-1 Do Begin
  If Writing And Progress And (I Mod 128=0) Then Begin
   HideMouseCursor;
   FillRect(20,ScreenHeight-45,ScreenWidth-20,ScreenHeight-23,LightGray);
   SetColor(Black);OutTextXY(28,ScreenHeight-38,
    'Export 3D : '+IntToStr(I*100 Div M^.TriangleCount)+'% - Echap : annuler');
   ShowMouseCursor;
   If KeyPressed Then Begin K:=ReadKey;If K=#27 Then Failed:=True;End;
  End;
  If Failed Then Break;MeshExportNormal(M,I,N);
  If Format=0 Then Begin
   If Normals Then Line('vn '+VectorText(N));S:='f';
   For J:=0 To 2 Do Begin
    Case J Of 0:Index:=M^.Triangles^[I].A;1:Index:=M^.Triangles^[I].B;
     2:Index:=M^.Triangles^[I].C;End;
    S:=S+' '+IntToStr(Index+1);
    If Normals Then S:=S+'//'+IntToStr(I+1);
   End;
   Line(S);
  End Else Begin
   If Format=1 Then Begin Line(' facet normal '+VectorText(N));
    Line('  outer loop');End
   Else Begin FillChar(RecordData,SizeOf(RecordData),0);
    PutFloat(0,N.X);PutFloat(4,N.Y);PutFloat(8,N.Z);End;
   For J:=0 To 2 Do Begin
    Case J Of 0:Index:=M^.Triangles^[I].A;1:Index:=M^.Triangles^[I].B;
     2:Index:=M^.Triangles^[I].C;End;
    V:=M^.Vertices^[Index];
    If Format=1 Then Line('   vertex '+VectorText(V))
    Else Begin PutFloat(12+J*12,V.X);PutFloat(16+J*12,V.Y);
     PutFloat(20+J*12,V.Z);End;
   End;
   If Format=1 Then Begin Line('  endloop');Line(' endfacet');End
   Else Emit(RecordData,SizeOf(RecordData));
  End;
 End;
 If Format=1 Then Line('endsolid CloneDRAW');
 MeshExportStream:=Not Failed;
End;

Function WriteMeshExport(M:PMesh;Const Name:String;Format:Integer;
 Normals,Progress:Boolean;Var Error:String):Boolean;
Var F,B:File;SR:SearchRec;Temp,Backup:String;I,Code:Integer;Bytes:LongInt;
 Good,HadOld:Boolean;
 Procedure RemoveTemp;
 Begin Assign(F,Temp);{$I-}Erase(F);{$I+}Code:=IOResult;End;
Begin
 WriteMeshExport:=False;Error:='';
 If (M=Nil) Or (Name='') Or (Length(Name)>230) Then Begin
  Error:='Nom vide, trop long ou geometrie absente.';Exit;
 End;
 If (Format<0) Or (Format>2) Then Begin Error:='Format invalide.';Exit;End;
 FindFirst(Name,AnyFile,SR);Good:=DosError=0;
 If Good Then Good:=(SR.Attr And Directory)<>0;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 If Good Then Begin Error:='La destination est un dossier.';Exit;End;
 I:=0;
 Repeat
  Temp:=Name+'.~3d'+IntToStr(I);Backup:=Temp+'.bak';Inc(I);
 Until (Not MeshExportExists(Temp) And Not MeshExportExists(Backup)) Or
  (I=1000);
 If I=1000 Then Begin Error:='Impossible de creer un fichier temporaire.';
  Exit;End;
 Assign(F,Temp);{$I-}Rewrite(F,1);{$I+}
 If IOResult<>0 Then Begin Error:='Dossier inaccessible en ecriture.';Exit;End;
 Good:=MeshExportStream(M,Format,Normals,True,Progress,F,Bytes);
 {$I-}Close(F);{$I+}If IOResult<>0 Then Good:=False;
 If Not Good Then Begin RemoveTemp;
  Error:='Export annule ou erreur disque. Original conserve.';Exit;End;
 HadOld:=MeshExportExists(Name);
 If HadOld Then Begin
  Assign(B,Name);{$I-}Rename(B,Backup);{$I+}
  If IOResult<>0 Then Begin RemoveTemp;
   Error:='Fichier destination verrouille. Original conserve.';Exit;End;
 End;
 Assign(F,Temp);{$I-}Rename(F,Name);{$I+}
 If IOResult<>0 Then Begin
  If HadOld Then Begin Assign(B,Backup);{$I-}Rename(B,Name);{$I+}
   If IOResult<>0 Then Begin
    Error:='Original preserve dans : '+Backup;RemoveTemp;Exit;
   End;
  End;
  RemoveTemp;Error:='Impossible de finaliser le fichier.';Exit;
 End;
 If HadOld Then Begin Assign(B,Backup);{$I-}Erase(B);{$I+}
  If IOResult<>0 Then Error:='Export termine. Ancien fichier : '+Backup;
 End;
 WriteMeshExport:=True;
End;

Type TSketchMetadata=Record
 Title:String[48];Description:Array[0..3] Of String;Tags:String;
 PrivateModel,Published,AgeRestricted:Boolean;Password:String[64];
End;
 TSketchBuffer=Record Data:Array[0..8191] Of Byte;Count:Integer;End;
 TSketchResponse=Record Data:Array[0..16383] Of Char;Count:Integer;End;
Procedure ClearSketchSecrets(Var Token:String;Var D:TSketchMetadata);
Begin
 FillChar(Token[1],Length(Token),0);Token:='';
 FillChar(D.Password,SizeOf(D.Password),0);
End;
Function SketchTokenValid(Const Token:String):Boolean;
Var I:Integer;
Begin
 SketchTokenValid:=False;If (Length(Token)<8) Or (Length(Token)>128)
  Then Exit;
 For I:=1 To Length(Token) Do If Not (Token[I] In
  ['0'..'9','a'..'z','A'..'Z']) Then Exit;
 SketchTokenValid:=True;
End;
Function SketchUIDValid(Const UID:String):Boolean;
Var I:Integer;
Begin
 SketchUIDValid:=False;If Length(UID)<>32 Then Exit;
 For I:=1 To Length(UID) Do If Not (UID[I] In ['0'..'9','a'..'f']) Then Exit;
 SketchUIDValid:=True;
End;
Function SketchMetadataValid(Const D:TSketchMetadata;
 Var Error:String):Boolean;
Var I,J,N,L:Integer;S:String;NonBlank:Boolean;
Begin
 SketchMetadataValid:=False;Error:='';NonBlank:=False;
 For I:=1 To Length(D.Title) Do If D.Title[I]>' ' Then NonBlank:=True;
 If Not NonBlank Then Begin Error:='Le titre est obligatoire (48 maximum).';
  Exit;End;
 If (D.Password<>'') And Not D.PrivateModel Then Begin
  Error:='Le mot de passe necessite le mode prive.';Exit;
 End;
 N:=0;L:=0;
 For I:=1 To Length(D.Tags)+1 Do Begin
  If I<=Length(D.Tags) Then S:=D.Tags[I] Else S:=' ';
  If S=' ' Then Begin
   If L>0 Then Inc(N);L:=0;
  End Else Begin
   If Not (S[1] In ['a'..'z','A'..'Z','0'..'9','-','_']) Then Begin
    Error:='Tags : lettres, chiffres, tirets et espaces.';Exit;
   End;
   Inc(L);If L>48 Then Begin Error:='Un tag depasse 48 caracteres.';Exit;End;
  End;
 End;
 If N>42 Then Begin Error:='42 tags maximum.';Exit;End;
 For J:=-2 To 4 Do Begin
  If J=-2 Then S:=D.Title Else If J=-1 Then S:=D.Tags
  Else If J=4 Then S:=D.Password Else S:=D.Description[J];
  For I:=1 To Length(S) Do If Ord(S[I])<32 Then Begin
   Error:='Les champs contiennent un caractere de controle.';Exit;
  End;
 End;
 SketchMetadataValid:=True;
End;
Function SketchBoundary(Const D:TSketchMetadata):String;
Var H,M,S,C:Word;B:String;I,N:Integer;Collision:Boolean;
Begin
 GetTime(H,M,S,C);N:=0;
 Repeat
  B:='----CloneDRAWPSP'+IntToStr(H)+IntToStr(M)+IntToStr(S)+
   IntToStr(C)+'x'+IntToStr(N);Inc(N);
  Collision:=(Pos(B,D.Title)>0) Or (Pos(B,D.Tags)>0) Or
   (Pos(B,D.Password)>0);
  For I:=0 To 3 Do Collision:=Collision Or (Pos(B,D.Description[I])>0);
 Until Not Collision;SketchBoundary:=B;
End;
Function BuildSketchMultipart(Const D:TSketchMetadata;Const Boundary:String;
 Format:Integer;Var Prefix,Suffix:TSketchBuffer):Boolean;
Var Good:Boolean;I:Integer;Dummy:String;
 Procedure Add(Var B:TSketchBuffer;Const S:String);
 Var I:Integer;
 Begin
  If B.Count+Length(S)>SizeOf(B.Data) Then Begin Good:=False;Exit;End;
  For I:=1 To Length(S) Do Begin B.Data[B.Count]:=Ord(S[I]);Inc(B.Count);End;
 End;
 Procedure Field(Const Name,Value:String);
 Begin
  Add(Prefix,'--'+Boundary+#13#10);
  Add(Prefix,'Content-Disposition: form-data; name="'+Name+'"'+#13#10);
  Add(Prefix,#13#10);Add(Prefix,Value);Add(Prefix,#13#10);
 End;
 Function Bool(B:Boolean):String;
 Begin If B Then Bool:='true' Else Bool:='false';End;
Begin
 Prefix.Count:=0;Suffix.Count:=0;Good:=True;BuildSketchMultipart:=False;
 If Not SketchMetadataValid(D,Dummy) Or (Length(Boundary)<8) Or
  (Length(Boundary)>70) Or (Format<0) Or (Format>2) Then Exit;
 For I:=1 To Length(Boundary) Do If Not (Boundary[I] In
  ['a'..'z','A'..'Z','0'..'9','-']) Then Exit;
 Field('name',D.Title);Field('tags',D.Tags);
 Field('private',Bool(D.PrivateModel));Field('isPublished',Bool(D.Published));
 Field('isAgeRestricted',Bool(D.AgeRestricted));
 If D.PrivateModel And (D.Password<>'') Then Field('password',D.Password);
 Add(Prefix,'--'+Boundary+#13#10);
 Add(Prefix,'Content-Disposition: form-data; name="description"'+#13#10);
 Add(Prefix,#13#10);
 For I:=0 To 3 Do Begin
  Add(Prefix,D.Description[I]);If I<3 Then Add(Prefix,#10);
 End;
 Add(Prefix,#13#10+'--'+Boundary+#13#10);
 Dummy:='model.obj';If Format>0 Then Dummy:='model.stl';
 Add(Prefix,'Content-Disposition: form-data; name="modelFile"; filename="');
 Add(Prefix,Dummy+'"'+#13#10+'Content-Type: application/octet-stream');
 Add(Prefix,#13#10+#13#10);Add(Suffix,#13#10+'--'+Boundary+'--'+#13#10);
 BuildSketchMultipart:=Good;
End;
{ Extraction JSON bornee. Aucun texte serveur n'est affiche comme secret. }
Function SketchJSON(const R:TSketchResponse;Const Key:String):String;
Var P,Depth:Integer;Name,Value:String;Escaped:Boolean;
 Function ReadString:String;
 Var S:String;C:Char;Closed:Boolean;
 Begin
  S:='';Inc(P);Escaped:=False;Closed:=False;
  While P<R.Count Do Begin
   C:=R.Data[P];Inc(P);
   If Escaped Then Begin
    If C In ['"','\','/'] Then S:=S+C Else S:=S+'?';Escaped:=False;
   End Else If C='\' Then Escaped:=True
   Else If C='"' Then Begin Closed:=True;Break;End
   Else If Length(S)<255 Then S:=S+C;
  End;If Not Closed Then S:='';ReadString:=S;
 End;
Begin
 SketchJSON:='';P:=0;Depth:=0;
 While P<R.Count Do Begin
  If R.Data[P]='"' Then Begin
   Name:=ReadString;
   While (P<R.Count) And (R.Data[P]<=' ') Do Inc(P);
   If (Name=Key) And ((Key<>'uid') Or (Depth=1)) And
    (P<R.Count) And (R.Data[P]=':') Then Begin
    Inc(P);While (P<R.Count) And (R.Data[P]<=' ') Do Inc(P);
    If (P<R.Count) And (R.Data[P]='"') Then SketchJSON:=ReadString;
    Exit;
   End;
  End Else Begin
   If R.Data[P] In ['{','['] Then Inc(Depth);
   If R.Data[P] In ['}',']'] Then Dec(Depth);Inc(P);
  End;
 End;
End;
Function SketchLocationUID(Location:String):String;
Begin
 SketchLocationUID:='';
 While (Length(Location)>0) And (Location[Length(Location)]='/') Do
  Delete(Location,Length(Location),1);
 If Copy(Location,1,36)='https://api.sketchfab.com/v3/models/' Then
  Delete(Location,1,36)
 Else If Copy(Location,1,11)='/v3/models/' Then Delete(Location,1,11)
 Else Exit;
 If SketchUIDValid(Location) Then SketchLocationUID:=Location;
End;
Function SketchHTTPError(Code:LongWord):String;
Begin
 Case Code Of
  400:SketchHTTPError:='Champs refuses par Sketchfab. Verifier les options.';
  401:SketchHTTPError:='Cle API invalide ou expiree.';
  403:SketchHTTPError:='Acces refuse. Verifier droits et offre du compte.';
  404:SketchHTTPError:='Modele ou ressource introuvable.';
  413:SketchHTTPError:='Fichier trop volumineux pour ce compte.';
  429:SketchHTTPError:='Limite API atteinte. Attendre avant de reessayer.';
  300..399:SketchHTTPError:=
   'Redirection refusee. Verifier le service officiel.';
  500..599:SketchHTTPError:=
   'Service Sketchfab indisponible. Reessayer plus tard.';
  Else SketchHTTPError:='Reponse Sketchfab inattendue : HTTP '+IntToStr(Code);
 End;
End;
Function SketchRequest(Const Token,Verb,Path,ModelPath,Boundary:String;
 Const Prefix,Suffix:TSketchBuffer;Var Code:LongWord;
 Var Response:TSketchResponse;Var Error:String):Boolean;
Var ValidateI:Integer;
{$IFDEF SKETCH_NATIVE}
 Session,Connection,Request:Pointer;Input:TSketchInternetBuffer;
 F:File;Opened,Good,Cancelled:Boolean;Target:String;
 Headers:AnsiString;OldMode:Byte;
 Count,Written,Size,Index,Timeout,Flags:LongWord;Total,Sent:LongInt;
 Chunk:Array[0..8191] Of Byte;ReadCount:LongInt;K:Char;
 Location:Array[0..511] Of Char;LocationText,FoundUID:String;
 Procedure CloseAll;
 Begin
  If Opened Then Begin {$I-}Close(F);{$I+}ReadCount:=IOResult;End;
  If Request<>Nil Then SFClose(Request);
  If Connection<>Nil Then SFClose(Connection);
  If Session<>Nil Then SFClose(Session);
  If Length(Headers)>0 Then FillChar(Headers[1],Length(Headers),0);
  Headers:='';
 End;
 Procedure Send(Data:Pointer;Length:LongWord);
 Var P:^Byte;N:LongWord;
 Begin
  P:=Data;
  While Good And (Length>0) Do Begin
   N:=0;Good:=SFWrite(Request,P,Length,N) And (N>0) And (N<=Length);
   If Good Then Begin Inc(P,N);Dec(Length,N);Inc(Sent,N);End;
  End;
 End;
{$ENDIF}
Begin
 SketchRequest:=False;Code:=0;Response.Count:=0;Error:='';
 If Not SketchTokenValid(Token) Then Begin Error:='Cle API invalide.';Exit;End;
 If Verb='POST' Then Begin
  If (Prefix.Count<1) Or (Prefix.Count>SizeOf(Prefix.Data)) Or
   (Suffix.Count<4) Or (Suffix.Count>SizeOf(Suffix.Data)) Or
   (Length(Boundary)<8) Or (Length(Boundary)>70) Then Begin
   Error:='Donnees multipart invalides.';Exit;
  End;
  For ValidateI:=1 To Length(Boundary) Do If Not (Boundary[ValidateI] In
   ['a'..'z','A'..'Z','0'..'9','-']) Then Begin
   Error:='Separateur multipart invalide.';Exit;
  End;
 End;
 If (Verb<>'GET') And (Verb<>'POST') Then Begin Error:='Methode invalide.';
  Exit;End;
 If (Path<>'/v3/me') And (Path<>'/v3/models') And
  (Copy(Path,1,11)<>'/v3/models/') Then Begin
  Error:='Adresse API non autorisee.';Exit;
 End;
 If (Copy(Path,1,11)='/v3/models/') And
  Not SketchUIDValid(Copy(Path,12,255)) Then Begin
  Error:='Identifiant de modele invalide.';Exit;
 End;
{$IFDEF SKETCH_NATIVE}
 Session:=Nil;Connection:=Nil;Request:=Nil;Opened:=False;
 Good:=True;Cancelled:=False;Sent:=0;Total:=0;
 If Verb='POST' Then Begin
  Assign(F,ModelPath);OldMode:=FileMode;FileMode:=0;{$I-}Reset(F,1);{$I+}
  FileMode:=OldMode;If IOResult<>0 Then Begin
   Error:='Fichier prepare inaccessible.';Exit;End;Opened:=True;
  {$I-}Total:=FileSize(F);{$I+}
  If (IOResult<>0) Or (Total<1) Or (Total>33554432) Then Begin
   Error:='Taille du modele invalide.';CloseAll;Exit;
  End;
  Inc(Total,Prefix.Count+Suffix.Count);
 End;
 Session:=SFInternetOpen('CloneDRAW-PSP/1.0',0,Nil,Nil,0);
 Timeout:=15000;
 If Session<>Nil Then Begin
  SFSetOption(Session,2,@Timeout,4);SFSetOption(Session,5,@Timeout,4);
  SFSetOption(Session,6,@Timeout,4);
  Connection:=SFInternetConnect(Session,'api.sketchfab.com',443,
   Nil,Nil,3,0,0);
 End;
 { TLS valide, sans cookies, ni redirection, ni authentification implicite. }
 Flags:=$80000000 Or $00800000 Or $00200000 Or $04000000 Or
  $00080000 Or $00040000 Or $00000200;
 Target:=Path+#0;
 If Connection<>Nil Then Begin
  Headers:=Verb+#0;
  Request:=SFHttpOpen(Connection,@Headers[1],@Target[1],Nil,Nil,Nil,Flags,0);
 End;
 If Request=Nil Then Begin Error:='Connexion HTTPS impossible.';
  CloseAll;Exit;End;
 Headers:='Authorization: Token '+Token+#13#10+'Accept: application/json';
 If Verb='POST' Then Headers:=Headers+#13#10+
  'Content-Type: multipart/form-data; boundary='+Boundary;
 Headers:=Headers+#13#10+#0;
 FillChar(Input,SizeOf(Input),0);Input.Size:=SizeOf(Input);
 Input.Header:=@Headers[1];Input.HeaderLength:=Length(Headers)-1;
 Input.HeaderTotal:=Input.HeaderLength;Input.BufferTotal:=Total;
 Good:=SFSend(Request,@Input,Nil,0,0);
 If Good And (Verb='POST') Then Begin
  Send(@Prefix.Data[0],Prefix.Count);
  Repeat
   {$I-}BlockRead(F,Chunk,SizeOf(Chunk),ReadCount);{$I+}
   Good:=Good And (IOResult=0);
   If Good And (ReadCount>0) Then Send(@Chunk[0],ReadCount);
   HideMouseCursor;
   FillRect(20,ScreenHeight-45,ScreenWidth-20,ScreenHeight-23,LightGray);
   SetColor(Black);OutTextXY(28,ScreenHeight-38,
    'Sketchfab : '+IntToStr(Round(Sent*100.0/Total))+'% - Echap : interrompre');
   ShowMouseCursor;
   If KeyPressed Then Begin K:=ReadKey;If K=#27 Then Begin
    Cancelled:=True;Good:=False;End;End;
  Until Not Good Or (ReadCount=0);
  If Good Then Send(@Suffix.Data[0],Suffix.Count);
 End;
 If Good Then Good:=SFEnd(Request,Nil,0,0);
 If Good Then Begin
  Size:=4;Index:=0;Good:=SFQuery(Request,19 Or $20000000,@Code,Size,Index);
 End;
 If Good Then Repeat
  Count:=0;Size:=SizeOf(Response.Data)-Response.Count;
  If Size=0 Then Break;
  Good:=SFRead(Request,@Response.Data[Response.Count],Size,Count);
  If Count>Size Then Good:=False Else Inc(Response.Count,Count);
 Until Not Good Or (Count=0);
 If Good And (Code=201) And (Verb='POST') And
  Not SketchUIDValid(SketchJSON(Response,'uid')) Then Begin
  Size:=SizeOf(Location);Index:=0;
  If SFQuery(Request,33,@Location[0],Size,Index) And
   (Size>0) And (Size<SizeOf(Location)) Then Begin
   LocationText:='';
   For ValidateI:=0 To Min(254,Size-1) Do
    LocationText:=LocationText+Location[ValidateI];
   FoundUID:=SketchLocationUID(LocationText);
   If FoundUID<>'' Then Begin
    LocationText:='{"uid":"'+FoundUID+'"}';
    Response.Count:=Length(LocationText);
    Move(LocationText[1],Response.Data[0],Response.Count);
   End;
  End;
 End;
 CloseAll;
 If Cancelled Then
  Error:='Envoi interrompu. Verifier le compte avant de renvoyer.'
 Else If Not Good Then
  Error:='Erreur HTTPS. Envoi incertain : verifier le compte avant renvoi.'
 Else If (Code<200) Or (Code>=300) Then Error:=SketchHTTPError(Code)
 Else SketchRequest:=True;
{$ELSE}
 Error:='Envoi HTTPS disponible sous Windows avec Free Pascal.';
{$ENDIF}
End;

Procedure MeshImportDialog(Target:Integer);
Var M,Loaded:PMesh;O:TMeshOptions;Preview:PByteArr;
 X,Y,W,H,MX,MY,MB,Previous,Field,I,Code,OldX,OldY,PreviewW,PreviewH:Integer;
 Dirty,Done,Drag,ReplaceText,Valid,Info,PreviewDirty:Boolean;
 Name,Message,Error:String;Texts:Array[0..5] Of String;
 K,E:Char;V:Double;
 Function Decimal(Value:Double):String;
 Var T:String;
 Begin Str(Value:0:2,T);Decimal:=T;End;
 Procedure Sync;
 Begin
  Texts[0]:=Decimal(O.RX/10);Texts[1]:=Decimal(O.RY/10);
  Texts[2]:=Decimal(O.RZ/10);Texts[3]:=IntToStr(O.Scale);
  Texts[4]:=IntToStr(O.OffsetX);Texts[5]:=IntToStr(O.OffsetY);
 End;
 Procedure Changed;
 Begin Dirty:=True;PreviewDirty:=True;Message:='';Valid:=True;End;
 Procedure Load;
 Begin
  If ReadMesh(Name,Loaded,Error) Then Begin
   ReleaseMesh(M);M:=Loaded;DefaultMeshOptions(O);Sync;Changed;
   Message:='Geometrie chargee. Textures non importees.';Info:=False;
  End Else Begin Message:=Error;Dirty:=True;End;
 End;
 Procedure Browse;
 Begin
  FD_ModelMode:=True;
  If FD_Open('Modele 3D - OBJ / STL',Name) Then Load;
  FD_ModelMode:=False;Dirty:=True;
  GetMouseStateLocal(MX,MY,Previous);
 End;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+24,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+24,True);SetColor(Black);
  OutTextXY(X+L+7,Y+T+8,Caption);
 End;
 Procedure Option(T:Integer;Checked:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+320,Y+T,X+332,Y+T+12);
  If Checked Then Begin Line(X+322,Y+T+6,X+325,Y+T+10);
   Line(X+325,Y+T+10,X+331,Y+T+2);End;
  OutTextXY(X+340,Y+T+3,Caption);
 End;
 Procedure Change;
 Var T:String;J,N:Integer;
 Begin
  T:=Texts[Field-1];For J:=1 To Length(T) Do If T[J]=',' Then T[J]:='.';
  Val(T,V,Code);Valid:=Code=0;Dirty:=True;
  If Valid Then Case Field Of
   1..3:Valid:=(V>=-360) And (V<=360);
   4:Valid:=(V>=10) And (V<=400);
   5,6:Valid:=(V>=-100) And (V<=100);
  End;
  If Not Valid Then Begin Message:='Valeur hors limites.';Exit;End;
  N:=Round(V);If Field<=3 Then N:=Round(V*10);
  Case Field Of 1:O.RX:=N;2:O.RY:=N;3:O.RZ:=N;4:O.Scale:=N;
   5:O.OffsetX:=N;6:O.OffsetY:=N;End;Changed;
 End;
 Procedure Draw;
 Var PX,PY,T,I,OX,OY:Integer;Color:Byte;S:String;
 Begin
  If PreviewDirty And (M<>Nil) And Valid Then Begin
   If Preview<>Nil Then FreeMem(Preview,LongInt(PreviewW)*PreviewH);
   Preview:=Nil;
   If LongInt(ImgW)*214>LongInt(ImgH)*280 Then Begin
    PreviewW:=280;PreviewH:=Max(1,Round(ImgH*280.0/ImgW));
   End Else Begin
    PreviewH:=214;PreviewW:=Max(1,Round(ImgW*214.0/ImgH));
   End;
   If Not RenderMesh(M,O,PreviewW,PreviewH,True,Preview) Then
    Message:='Apercu annule ou memoire insuffisante.';
   PreviewDirty:=False;
  End;
  HideMouseCursor;FillRect(X,Y,X+W,Y+H,LightGray);DrawBevel(X,Y,X+W,Y+H,True);
  FillRect(X+3,Y+3,X+W-3,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Calque 3D - importer et placer une geometrie');
  FillRect(X+20,Y+40,X+472,Y+64,White);
  If Field=0 Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X+20,Y+40,X+472,Y+64);SetColor(Black);S:=Name;
  If Length(S)>54 Then S:='...'+Copy(S,Length(S)-50,51);
  OutTextXY(X+26,Y+48,S);Button(490,40,105,'Choisir...');
  For PY:=0 To 213 Do For PX:=0 To 279 Do Begin
   Color:=LightGray;If ((PX Div 10+PY Div 10) And 1)=0 Then Color:=White;
   OX:=PX-(280-PreviewW) Div 2;OY:=PY-(214-PreviewH) Div 2;
   If Not Info And (Preview<>Nil) And (OX>=0) And (OY>=0) And
    (OX<PreviewW) And (OY<PreviewH) Then
     If Preview^[LongInt(OY)*PreviewW+OX]<>255 Then
      Color:=Preview^[LongInt(OY)*PreviewW+OX];
   PutPixel(X+20+PX,Y+82+PY,Color);
  End;
  SetColor(Black);Rectangle(X+19,Y+81,X+300,Y+296);
  If Info And (M<>Nil) Then Begin
   FillRect(X+21,Y+83,X+298,Y+294,White);SetColor(Black);
   OutTextXY(X+28,Y+94,'Format : '+M^.Format);
   OutTextXY(X+28,Y+116,'Sommets : '+IntToStr(M^.VertexCount));
   OutTextXY(X+28,Y+138,'Triangles : '+IntToStr(M^.TriangleCount));
   OutTextXY(X+28,Y+160,'Taille : '+IntToStr(M^.SourceSize)+' octets');
   OutTextXY(X+28,Y+182,'X : '+Decimal(M^.Maximum.X-M^.Minimum.X));
   OutTextXY(X+28,Y+202,'Y : '+Decimal(M^.Maximum.Y-M^.Minimum.Y));
   OutTextXY(X+28,Y+222,'Z : '+Decimal(M^.Maximum.Z-M^.Minimum.Z));
   OutTextXY(X+28,Y+244,'Groupes : '+IntToStr(M^.Groups)+
    ' Mat : '+IntToStr(M^.Materials));
   OutTextXY(X+28,Y+266,'Unites : celles du fichier');
  End Else If M=Nil Then Begin
   OutTextXY(X+35,Y+160,'Choisir un modele OBJ ou STL');
  End;
  For I:=0 To 5 Do Begin
   T:=82+I*33;
   Case I Of 0:S:='Rotation X';1:S:='Rotation Y';2:S:='Rotation Z';
    3:S:='Echelle %';4:S:='Decal. X %';5:S:='Decal. Y %';End;
   SetColor(Black);OutTextXY(X+320,Y+T+8,S);
   FillRect(X+420,Y+T,X+592,Y+T+23,White);
   If Field=I+1 Then SetColor(Blue) Else SetColor(DarkGray);
   Rectangle(X+420,Y+T,X+592,Y+T+23);SetColor(Black);
   OutTextXY(X+428,Y+T+8,Texts[I]);
  End;
  S:='Orthographique';If O.Perspective Then S:='Perspective';
  Button(20,307,135,S);
  Case O.Mode Of 0:S:='Solide';1:S:='Fil de fer';2:S:='Solide + fil';End;
  Button(165, 307, 135, S+' >'); Button(20, 339, 135,
  'Matiere : '+IntToStr(O.Color)+' >'); 
  Button(165,339,135,'Informations');
  Option(287, O.Cull, 'Cacher faces arriere'); Option(310, O.Dither,
  'Tramage des couleurs'); 
  OutTextXY(X+320,Y+338,'Glisser l''apercu : orbite');
  OutTextXY(X+320,Y+356,'Geometrie en memoire');
  SetColor(Black);S:=Message;
  If S='' Then S:='OBJ/STL sans textures. Rendu sur calque transparent.';
  If Length(S)>73 Then S:=Copy(S,1,73);OutTextXY(X+20,Y+378,S);
  Button(20,399,110,'Reinitialiser');Button(142,399,65,'Face');
  Button(219,399,81,'Iso 3D');Button(380,399,96,'Annuler');
  S:='Importer';If Target>=0 Then S:='Appliquer';Button(490,399,105,S);
  ShowMouseCursor;Dirty:=False;
 End;
 Procedure Apply;
 Begin
  If Not Valid Then Exit;
  If M=Nil Then Load Else If Name<>M^.Source Then Load;
  If M=Nil Then Begin Dirty:=True;Exit;End;
  If Name<>M^.Source Then Begin Dirty:=True;Exit;End;
  If ImportMeshLayer(M,O,Target) Then Done:=True
   Else Begin Message:='Import annule, memoire ou limite de calques.';
   Dirty:=True; End; 
 End;
Begin
 ResetToolTip;MenuActive:=False;M:=Nil;Preview:=Nil;
 PreviewW:=0;PreviewH:=0;Name:='';Message:='';
 If (Target>=0) And (Target<LayerCount) Then Begin
  M:=Layers[Target].Mesh;RetainMesh(M);
  If M<>Nil Then Begin Name:=M^.Source;O:=Layers[Target].MeshOptions;End;
 End;
 If M=Nil Then DefaultMeshOptions(O);
 W:=620;H:=430;X:=(ScreenWidth-W) Div 2;Y:=(ScreenHeight-H) Div 2;
 Field:=0;Info:=False;Done:=False;Dirty:=True;Valid:=True;
 Drag:=False;ReplaceText:=True;PreviewDirty:=True;Sync;
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(490,40,595,64) Then Browse
   Else If Hit(20, 40, 472, 64) Then Begin Field:=0; ReplaceText:=True;
   Dirty:=True; End
   Else If Hit(420,82,592,270) Then Begin
    Field:=Min(6,1+(MY-Y-82) Div 33);ReplaceText:=True;Dirty:=True;
   End Else If Hit(20,82,300,296) And Not Info Then Begin
    Drag:=True;OldX:=MX;OldY:=MY;
   End Else If Hit(20, 307, 155, 331) Then Begin O.Perspective:=Not
   O.Perspective; Changed; End
   Else If Hit(165,307,300,331) Then Begin O.Mode:=(O.Mode+1) Mod 3;Changed;End
   Else If Hit(20, 339, 155, 363) Then Begin O.Color:=(O.Color+1) Mod 16;
   Changed; End
   Else If Hit(165,339,300,363) Then Begin Info:=Not Info;Dirty:=True;End
   Else If Hit(320,287,600,299) Then Begin O.Cull:=Not O.Cull;Changed;End
   Else If Hit(320,310,600,322) Then Begin O.Dither:=Not O.Dither;Changed;End
   Else If Hit(20,399,130,423) Or Hit(219,399,300,423) Then Begin
    DefaultMeshOptions(O);Sync;Changed;
   End Else If Hit(142,399,207,423) Then Begin
    O.RX:=0;O.RY:=0;O.RZ:=0;Sync;Changed;
   End Else If Hit(380,399,476,423) Then Done:=True
   Else If Hit(490,399,595,423) Then Apply;
  End;
  If Drag And ((MB And 1)<>0) And
   ((MX<>OldX) Or (MY<>OldY)) Then Begin
   O.RY:=Max(-3600,Min(3600,O.RY+(MX-OldX)*5));
   O.RX:=Max(-3600,Min(3600,O.RX+(MY-OldY)*5));
   OldX:=MX;OldY:=MY;Sync;Changed;
  End;
  If (MB And 1)=0 Then Drag:=False;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then Begin
    E:=ReadKey;
    If Field>0 Then Begin
     Val(Texts[Field-1],V,Code);
     If Code=0 Then Begin
      If E=#72 Then V:=V+1 Else If E=#80 Then V:=V-1;
      Texts[Field-1]:=Decimal(V);Change;ReplaceText:=True;
     End;
    End;
   End Else Case K Of
    #27:Done:=True; #15:Browse; #9:Begin Field:=(Field+1) Mod 7;
    ReplaceText:=True; Dirty:=True; End; 
    #13:If Field=0 Then Load Else Apply;
    #1:ReplaceText:=True;
    #8:Begin
     If Field=0 Then Begin
      If ReplaceText Then Name:='' Else Delete(Name,Length(Name),1);Dirty:=True;
     End Else Begin
      If ReplaceText Then Texts[Field-1]:=''
       Else Delete(Texts[Field-1],Length(Texts[Field-1]),1);Change;
     End;
     ReplaceText:=False;
    End;
    Else If K>=' ' Then Begin
     If Field=0 Then Begin
      If ReplaceText Then Name:=''; If Length(Name)<255 Then Name:=Name+K;
      Dirty:=True; 
     End Else If K In ['0'..'9','+','-','.',','] Then Begin
      If ReplaceText Then Texts[Field-1]:='';
      If Length(Texts[Field-1])<9 Then Texts[Field-1]:=Texts[Field-1]+K;Change;
     End;
     ReplaceText:=False;
    End;
   End;
  End;
  Delay(10);
 Until Done;
 If Preview<>Nil Then FreeMem(Preview,LongInt(PreviewW)*PreviewH);
 ReleaseMesh(M);
 GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Procedure MeshMergeDialog;
Var Selected:TMeshSelection;M:PMesh;O:TMeshOptions;Preview:PByteArr;
 X,Y,MX,MY,MB,Previous,I,J,PW,PH,OX,OY,Focus,Count:Integer;
 OldX,OldY:Integer;VC,TC,Bytes:LongInt;Color:Byte;K,E:Char;
 Dirty,Rebuild,Done,Keep,Transform,Spread,Drag,ReplaceText,Info:Boolean;
 Name,Message,Error,S:String;
 Function Decimal(V:Double):String;
 Var T:String;
 Begin Str(V:0:3,T);Decimal:=T;End;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Procedure Changed(Geometry:Boolean);
 Begin Rebuild:=Rebuild Or Geometry;Dirty:=True;Message:='';End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+23,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+23,True);SetColor(Black);
  OutTextXY(X+L+6,Y+T+8,Caption);
 End;
 Procedure Check(L,T:Integer;Value:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+L,Y+T,X+L+12,Y+T+12);
  If Value Then Begin Line(X+L+2,Y+T+6,X+L+5,Y+T+10);
   Line(X+L+5,Y+T+10,X+L+11,Y+T+2);End;
  OutTextXY(X+L+18,Y+T+3,Caption);
 End;
 Procedure Draw;
 Var PX,PY,I,OutputCount:Integer;
 Begin
  If Rebuild Then Begin
   ReleaseMesh(M);BuildMergedMesh(Selected,Transform,Spread,M,Error);
   Message:=Error;Rebuild:=False;
  End;
  If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);Preview:=Nil;
  If M<>Nil Then If Not RenderMesh(M,O,PW,PH,True,Preview) Then
   Message:='Apercu annule ou memoire insuffisante.';
  Count:=0;VC:=0;TC:=0;
  For I:=0 To LayerCount-1 Do If Selected[I] Then Begin
   Inc(Count);Inc(VC,Layers[I].Mesh^.VertexCount);
   Inc(TC,Layers[I].Mesh^.TriangleCount);
  End;
  Bytes:=VC*SizeOf(TMeshVector)+TC*SizeOf(TMeshTriangle);
  HideMouseCursor;FillRect(X,Y,X+620,Y+440,LightGray);
  DrawBevel(X,Y,X+620,Y+440,True);
  FillRect(X+3,Y+3,X+617,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Fusionner les calques 3D - assemblage de scene');
  SetColor(Black);OutTextXY(X+16,Y+39,'Sources 3D (Espace : choisir)');
  For I:=0 To MAX_LAYERS-1 Do Begin
   FillRect(X+14,Y+57+I*22,X+302,Y+77+I*22,White);
   If I<LayerCount Then Begin
    If Focus=I Then Begin SetColor(Blue);
     Rectangle(X+14,Y+57+I*22,X+302,Y+77+I*22);End;
    If Layers[I].Mesh<>Nil Then Begin
     S:=Copy(Layers[I].Name,1,20);
     If Not Layers[I].Visible Then S:=S+' (M)';
     Check(20,61+I*22,Selected[I],S);
    End Else Begin SetColor(DarkGray);
     OutTextXY(X+22,Y+64+I*22,Copy(Layers[I].Name,1,20)+' [2D]');End;
   End;
  End;
  Button(14,239,88,'Tous 3D');Button(110,239,88,'Visibles');
  Button(206,239,96,'Aucun');
  For PY:=0 To 169 Do For PX:=0 To 279 Do Begin
   Color:=White;If ((PX Div 10+PY Div 10) And 1)=0 Then Color:=LightGray;
   OX:=PX-(280-PW) Div 2;OY:=PY-(170-PH) Div 2;
   If (Preview<>Nil) And (OX>=0) And (OY>=0) And (OX<PW) And
    (OY<PH) Then If Preview^[LongInt(OY)*PW+OX]<>255 Then
     Color:=Preview^[LongInt(OY)*PW+OX];
   PutPixel(X+320+PX,Y+57+PY,Color);
  End;
  SetColor(Black);Rectangle(X+319,Y+56,X+600,Y+227);
  OutTextXY(X+320,Y+39,'Apercu / infos (I) - glisser');
  If Info And (M<>Nil) Then Begin
   FillRect(X+321,Y+58,X+599,Y+225,White);SetColor(Black);
   OutTextXY(X+328,Y+68,'Etendue de la scene (unites)');
   OutTextXY(X+328,Y+88,'X : '+Decimal(M^.Maximum.X-M^.Minimum.X));
   OutTextXY(X+328,Y+106,'Y : '+Decimal(M^.Maximum.Y-M^.Minimum.Y));
   OutTextXY(X+328,Y+124,'Z : '+Decimal(M^.Maximum.Z-M^.Minimum.Z));
   OutTextXY(X+328,Y+144,'Groupes source : '+IntToStr(M^.Groups));
   OutTextXY(X+328,Y+162,'Image : '+IntToStr(ImgW)+' x '+IntToStr(ImgH));
   OutTextXY(X+328,Y+180,'Rendu indexe : '+
    IntToStr(LongInt(ImgW)*ImgH)+' o');
   OutTextXY(X+328,Y+198,'Maillage alloue : '+
    IntToStr(SizeOf(TMeshVertices)+SizeOf(TMeshTriangles))+' o');
   OutTextXY(X+328,Y+214,'Sortie visible / opacite 100%');
  End;
  OutputCount:=LayerCount-Count+1;
  If Keep Then OutputCount:=LayerCount+1;
  OutTextXY(X+320,Y+240,'Sources : '+IntToStr(Count)+' / sortie : '+
   IntToStr(OutputCount)+' calques');
  OutTextXY(X+320,Y+256,IntToStr(VC)+' sommets / '+
   IntToStr(TC)+' triangles');
  OutTextXY(X+320,Y+272,'Geometrie utile : '+IntToStr(Bytes)+' o');
  Check(16,278,Keep,'Conserver les sources');
  Check(16,300,Transform,'Appliquer les transformations');
  Check(16,322,Spread,'Disposer cote a cote');
  Check(320,294,O.Cull,'Masquer faces arriere');
  Check(320,316,O.Dither,'Tramage des couleurs');
  S:='Orthographique';If O.Perspective Then S:='Perspective';
  Button(14,349,140,S);
  Case O.Mode Of 0:S:='Solide';1:S:='Fil de fer';2:S:='Solide + fil';End;
  Button(162,349,140,S);
  Button(320,349,140,'Couleur : '+IntToStr(O.Color));
  Button(468,349,132,'Vue initiale');
  SetColor(Black);OutTextXY(X+16,Y+385,'Nom :');
  FillRect(X+64,Y+379,X+302,Y+400,White);
  If Focus=MAX_LAYERS Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X+64,Y+379,X+302,Y+400);SetColor(Black);
  OutTextXY(X+70,Y+386,Name);
  Button(320,379,132,'Annuler');Button(468,379,132,'Fusionner');
  SetColor(Black);OutTextXY(X+16,Y+409,
   'Camera/couleur communes. Sans soudure. Geometrie en memoire.');
  If Message<>'' Then Begin SetColor(Red);
   OutTextXY(X+16,Y+425,Copy(Message,1,74));End;
  ShowMouseCursor;Dirty:=False;
 End;
 Procedure Apply;
 Begin
  If Rebuild Then Draw;
  If M=Nil Then Begin Dirty:=True;Exit;End;
  If Name='' Then Begin Message:='Saisissez un nom de calque.';
   Dirty:=True;Exit;End;
  If Keep And (LayerCount>=MAX_LAYERS) Then Begin
   Message:='Huit calques maximum : decochez Conserver les sources.';
   Dirty:=True;Exit;
  End;
  If CommitMergedMesh(M,Selected,O,Keep,Name) Then Done:=True
  Else Begin Message:='Fusion annulee ou memoire insuffisante.';
   Dirty:=True;End;
 End;
Begin
 ResetToolTip;MenuActive:=False;FillChar(Selected,SizeOf(Selected),0);
 Count:=0;
 For I:=0 To LayerCount-1 Do If Layers[I].Mesh<>Nil Then Begin
  Inc(Count);Selected[I]:=Layers[I].Visible;
 End;
 If Count<2 Then Begin
  ShowDialog('Fusion 3D','Importez au moins deux calques 3D.');Exit;
 End;
 M:=Nil;Preview:=Nil;DefaultMeshOptions(O);O.RX:=0;O.RY:=0;
 O.Perspective:=False;Name:='Scene 3D fusionnee';Message:='';
 Keep:=False;Transform:=True;Spread:=False;Rebuild:=True;Info:=False;
 X:=(ScreenWidth-620) Div 2;Y:=(ScreenHeight-440) Div 2;
 If LongInt(ImgW)*170>LongInt(ImgH)*280 Then Begin
  PW:=280;PH:=Max(1,Round(ImgH*280.0/ImgW));
 End Else Begin PH:=170;PW:=Max(1,Round(ImgW*170.0/ImgH));End;
 Focus:=0;ReplaceText:=True;Done:=False;Dirty:=True;Drag:=False;
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(14,57,302,232) Then Begin
    J:=(MY-Y-57) Div 22;Focus:=J;
    If (J<LayerCount) And (Layers[J].Mesh<>Nil) Then Begin
     Selected[J]:=Not Selected[J];Changed(True);
    End;
   End Else If Hit(14,239,302,262) Then Begin
    For J:=0 To LayerCount-1 Do
     Selected[J]:=(Layers[J].Mesh<>Nil) And (MX<X+206) And
      ((MX<X+110) Or Layers[J].Visible);
    Changed(True);
   End Else If Hit(16,278,302,292) Then Begin
    Keep:=Not Keep;Changed(False);
   End Else If Hit(16,300,302,314) Then Begin
    Transform:=Not Transform;Changed(True);
   End Else If Hit(16,322,302,336) Then Begin
    Spread:=Not Spread;Changed(True);
   End Else If Hit(320,294,600,308) Then Begin
    O.Cull:=Not O.Cull;Changed(False);
   End Else If Hit(320,316,600,330) Then Begin
    O.Dither:=Not O.Dither;Changed(False);
   End Else If Hit(14,349,154,372) Then Begin
    O.Perspective:=Not O.Perspective;Changed(False);
   End Else If Hit(162,349,302,372) Then Begin
    O.Mode:=(O.Mode+1) Mod 3;Changed(False);
   End Else If Hit(320,349,460,372) Then Begin
    O.Color:=(O.Color+1) Mod 16;Changed(False);
   End Else If Hit(468,349,600,372) Then Begin
    O.RX:=0;O.RY:=0;O.RZ:=0;Changed(False);
   End Else If Hit(64,379,302,400) Then Begin
    Focus:=MAX_LAYERS;ReplaceText:=True;Dirty:=True;
   End Else If Hit(320,379,452,402) Then Done:=True
   Else If Hit(468,379,600,402) Then Apply
   Else If Hit(320,32,600,51) Then Begin
    Info:=Not Info;Dirty:=True;
   End Else If Hit(320,57,600,227) And Not Info Then Begin
    Drag:=True;OldX:=MX;OldY:=MY;
   End;
  End;
  If Drag And ((MB And 1)<>0) And
   ((MX<>OldX) Or (MY<>OldY)) Then Begin
   O.RY:=Max(-3600,Min(3600,O.RY+(MX-OldX)*5));
   O.RX:=Max(-3600,Min(3600,O.RX+(MY-OldY)*5));
   OldX:=MX;OldY:=MY;Changed(False);
  End;
  If (MB And 1)=0 Then Drag:=False;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then Begin
    E:=ReadKey;
    If E=#72 Then Focus:=(Focus+MAX_LAYERS) Mod (MAX_LAYERS+1);
    If E=#80 Then Focus:=(Focus+1) Mod (MAX_LAYERS+1);
    Dirty:=True;
   End Else Case K Of
    #27:Done:=True;
    #13:Apply;
    #9:Begin Focus:=(Focus+1) Mod (MAX_LAYERS+1);
     ReplaceText:=True;Dirty:=True;End;
    #1:ReplaceText:=True;
    'i','I':If Focus<>MAX_LAYERS Then Begin
     Info:=Not Info;Dirty:=True;
    End Else Begin
     If ReplaceText Then Name:='';If Length(Name)<20 Then Name:=Name+K;
     ReplaceText:=False;Dirty:=True;
    End;
    #8:If Focus=MAX_LAYERS Then Begin
     If ReplaceText Then Name:='' Else Delete(Name,Length(Name),1);
     ReplaceText:=False;Dirty:=True;
    End;
    Else If Focus=MAX_LAYERS Then Begin
     If K>=' ' Then Begin
      If ReplaceText Then Name:='';If Length(Name)<20 Then Name:=Name+K;
      ReplaceText:=False;Dirty:=True;
     End;
    End Else If (K=' ') And (Focus<LayerCount) Then
     If Layers[Focus].Mesh<>Nil Then Begin
      Selected[Focus]:=Not Selected[Focus];Changed(True);
     End;
   End;
  End;
  Delay(10);
 Until Done;
 If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);ReleaseMesh(M);
 GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Procedure MeshExportDialog;
Var M:PMesh;View:TMeshOptions;Preview:PByteArr;F:File;
 X,Y,MX,MY,MB,Previous,Source,Format,Field,PW,PH,I,J,Code:Integer;
 OldX,OldY:Integer;Bytes:LongInt;Factor:Double;
 Transform,Center,SwapAxes,Reverse,Normals,Info,Dirty,Rebuild,
 PreviewDirty,Done,Drag,ReplaceText,Valid:Boolean;
 Name,ScaleText,Message,Error,S:String;K,E:Char;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Function Decimal(V:Double):String;
 Var T:String;
 Begin
  If ((V<>0) And (Abs(V)<0.001)) Or (Abs(V)>=1E9) Then
   T:=MeshExportNumber(V) Else Str(V:0:3,T);
  Decimal:=T;
 End;
 Function Extension:String;
 Begin If Format=0 Then Extension:='.obj' Else Extension:='.stl';End;
 Procedure FixExtension;
 Var Ext:String;
 Begin
  Ext:=ExtractExt(Name);
  If Ext<>'' Then Delete(Name,Length(Name)-Length(Ext)+1,Length(Ext));
  Name:=Name+Extension;
 End;
 Procedure Changed(Geometry:Boolean);
 Begin Rebuild:=Rebuild Or Geometry;PreviewDirty:=True;Dirty:=True;
  Message:='';End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+23,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+23,True);SetColor(Black);
  OutTextXY(X+L+6,Y+T+8,Caption);
 End;
 Procedure Check(T:Integer;Value:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+320,Y+T,X+332,Y+T+12);
  If Value Then Begin Line(X+322,Y+T+6,X+325,Y+T+10);
   Line(X+325,Y+T+10,X+331,Y+T+2);End;
  OutTextXY(X+340,Y+T+3,Caption);
 End;
 Procedure Browse;
 Var Ext:String;OldFilter,OldSave:Integer;OldModel:Boolean;
 Begin
  OldFilter:=FD_FilterIdx;OldSave:=FD_SaveFilterIdx;
  OldModel:=FD_ModelMode;FD_ModelMode:=True;
  FD_MeshExportFormat:=Format+1;
  FD_Save('Destination du modele 3D',Name,Ext);
  FD_MeshExportFormat:=0;FD_ModelMode:=OldModel;
  FD_FilterIdx:=OldFilter;FD_SaveFilterIdx:=OldSave;Dirty:=True;
  GetMouseStateLocal(MX,MY,Previous);
 End;
 Procedure Draw;
 Var PX,PY,OX,OY,J:Integer;Color:Byte;
 Begin
  If Rebuild Then Begin
   ReleaseMesh(M);Valid:=MeshNumber(ScaleText,Factor) And
    (Factor>=0.000001) And (Factor<=1000000);
   If Valid Then Begin
    Valid:=PrepareMeshExport(Layers[Source].Mesh,
     Layers[Source].MeshOptions,Transform,Center,SwapAxes,Reverse,
     Factor,M,Error);If Not Valid Then Message:=Error;
   End Else Message:='Echelle entre 0.000001 et 1000000.';
   Rebuild:=False;
  End;
  If PreviewDirty Then Begin
   If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);Preview:=Nil;
   If M<>Nil Then Begin
    If Not RenderMesh(M,View,PW,PH,True,Preview) Then
     Message:='Apercu annule ou memoire insuffisante.';
    MeshExportStream(M,Format,Normals,False,False,F,Bytes);
   End Else Bytes:=0;
   PreviewDirty:=False;
  End;
  HideMouseCursor;FillRect(X,Y,X+620,Y+440,LightGray);
  DrawBevel(X,Y,X+620,Y+440,True);
  FillRect(X+3,Y+3,X+617,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Exporter un calque 3D - geometrie OBJ / STL');
  FillRect(X+20,Y+40,X+472,Y+64,White);
  If Field=0 Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X+20,Y+40,X+472,Y+64);SetColor(Black);S:=Name;
  If Length(S)>54 Then S:='...'+Copy(S,Length(S)-50,51);
  OutTextXY(X+26,Y+48,S);Button(490,40,110,'Parcourir');
  For PY:=0 To 195 Do For PX:=0 To 279 Do Begin
   Color:=White;If ((PX Div 10+PY Div 10) And 1)=0 Then Color:=LightGray;
   OX:=PX-(280-PW) Div 2;OY:=PY-(196-PH) Div 2;
   If (Preview<>Nil) And (OX>=0) And (OY>=0) And (OX<PW) And
    (OY<PH) Then If Preview^[LongInt(OY)*PW+OX]<>255 Then
     Color:=Preview^[LongInt(OY)*PW+OX];
   PutPixel(X+20+PX,Y+82+PY,Color);
  End;
  SetColor(Black);Rectangle(X+19,Y+81,X+300,Y+278);
  If Info And (M<>Nil) Then Begin
   FillRect(X+21,Y+83,X+299,Y+276,White);SetColor(Black);
   OutTextXY(X+28,Y+94,'Coordonnees de sortie');
   OutTextXY(X+28,Y+116,'Largeur X : '+
    Decimal(M^.Maximum.X-M^.Minimum.X));
   OutTextXY(X+28,Y+138,'Hauteur Y : '+
    Decimal(M^.Maximum.Y-M^.Minimum.Y));
   OutTextXY(X+28,Y+160,'Profondeur Z : '+
    Decimal(M^.Maximum.Z-M^.Minimum.Z));
   OutTextXY(X+28,Y+186,'Memoire geometrie : '+
    IntToStr(SizeOf(TMeshVertices)+SizeOf(TMeshTriangles))+' o');
   OutTextXY(X+28,Y+208,'Faces triangulees uniquement');
   OutTextXY(X+28,Y+230,'Normales par face, recalculees');
   OutTextXY(X+28,Y+252,'Camera d''apercu non exportee');
  End;
  Button(320,82,280,'Calque : '+Copy(Layers[Source].Name,1,22));
  For J:=0 To 2 Do Begin
   SetColor(Black);Circle(X+326,Y+126+J*22,6);
   If J=Format Then Begin SetFillStyle(SolidFill,Black);
    FillEllipse(X+326,Y+126+J*22,3,3);End;
   Case J Of 0:S:='OBJ Wavefront';1:S:='STL ASCII';2:S:='STL binaire';End;
   OutTextXY(X+340,Y+123+J*22,S);
  End;
  Check(200,Transform,'Appliquer transformations');
  Check(222,Center,'Centrer la geometrie');
  Check(244,SwapAxes,'Echanger les axes Y / Z');
  Check(266,Reverse,'Inverser les faces');
  Check(288,Normals,'Normales OBJ (STL : oui)');
  SetColor(Black);
  If M<>Nil Then Begin
   OutTextXY(X+20,Y+291,IntToStr(M^.VertexCount)+' sommets / '+
    IntToStr(M^.TriangleCount)+' triangles');
   OutTextXY(X+20,Y+309,'Taille exacte : '+IntToStr(Bytes)+' o');
  End Else OutTextXY(X+20,Y+291,'Parametres invalides');
  OutTextXY(X+20,Y+331,'Echelle des coordonnees :');
  FillRect(X+20,Y+348,X+160,Y+371,White);
  If Field=1 Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X+20,Y+348,X+160,Y+371);SetColor(Black);
  OutTextXY(X+26,Y+356,ScaleText);Button(170,348,130,'x1 / x0.001');
  S:='Orthographique';If View.Perspective Then S:='Perspective';
  Button(320,318,140,S);Button(468,318,132,'Solide / fil');
  Button(20,379,130,'Informations');Button(170,379,130,'Vue initiale');
  Button(320,379,132,'Annuler');Button(468,379,132,'Exporter');
  OutTextXY(X+20,Y+409,
   'Geometrie seule : sans textures/couleurs. Glisser : vue 3D.');
  If Message<>'' Then Begin SetColor(Red);
   OutTextXY(X+20,Y+425,Copy(Message,1,73));End;
  ShowMouseCursor;Dirty:=False;
 End;
 Procedure Apply;
 Begin
  If Rebuild Then Draw;
  If Not Valid Or (M=Nil) Then Exit;
  If Name='' Then Begin Message:='Choisissez le fichier destination.';
   Dirty:=True;Exit;End;
  FixExtension;
  If MeshExportExists(Name) Then
   If Not YesNoDialog('Export 3D','Remplacer le fichier existant ?') Then
    Begin Dirty:=True;Exit;End;
  If WriteMeshExport(M,Name,Format,Normals,True,Error) Then Begin
   If Error<>'' Then ShowDialog('Export 3D',Error)
   Else ShowDialog('Export 3D','Modele 3D exporte avec succes.');
   Done:=True;
  End Else Begin Message:=Error;Dirty:=True;End;
 End;
Begin
 ResetToolTip;MenuActive:=False;Source:=ActiveLayer;
 If Layers[Source].Mesh=Nil Then Begin
  Source:=-1;For I:=0 To LayerCount-1 Do
   If (Source<0) And (Layers[I].Mesh<>Nil) Then Source:=I;
 End;
 If Source<0 Then Begin
  ShowDialog('Export 3D','Aucun calque ne contient de geometrie 3D.');Exit;
 End;
 M:=Nil;Preview:=Nil;Format:=0;Bytes:=0;DefaultMeshOptions(View);
 Transform:=False;Center:=False;SwapAxes:=False;Reverse:=False;
 Normals:=True;Info:=False;ScaleText:='1';Factor:=1;
 Name:=Layers[Source].Mesh^.Source;
 If (Name='') Or (ExtractExt(Name)='') Then Name:='modele';
 S:=ExtractExt(Name);
 If S<>'' Then Delete(Name,Length(Name)-Length(S)+1,Length(S));
 Name:=Name+'-export.obj';Message:='';Field:=0;ReplaceText:=True;
 X:=(ScreenWidth-620) Div 2;Y:=(ScreenHeight-440) Div 2;
 If LongInt(ImgW)*196>LongInt(ImgH)*280 Then Begin
  PW:=280;PH:=Max(1,Round(ImgH*280.0/ImgW));
 End Else Begin PH:=196;PW:=Max(1,Round(ImgW*196.0/ImgH));End;
 Dirty:=True;Rebuild:=True;PreviewDirty:=True;Done:=False;Drag:=False;
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(490,40,600,64) Then Browse
   Else If Hit(20,40,472,64) Or Hit(20,348,160,371) Then Begin
    Field:=0;If MY>Y+300 Then Field:=1;ReplaceText:=True;Dirty:=True;
   End Else If Hit(320,82,600,105) Then Begin
    Repeat Source:=(Source+1) Mod LayerCount;
    Until Layers[Source].Mesh<>Nil;Changed(True);
   End Else If Hit(320,118,600,180) Then Begin
    Format:=Min(2,(MY-Y-118) Div 22);FixExtension;Changed(False);
   End Else If Hit(320,200,600,212) Then Begin
    Transform:=Not Transform;Changed(True);
   End Else If Hit(320,222,600,234) Then Begin
    Center:=Not Center;Changed(True);
   End Else If Hit(320,244,600,256) Then Begin
    SwapAxes:=Not SwapAxes;Changed(True);
   End Else If Hit(320,266,600,278) Then Begin
    Reverse:=Not Reverse;Changed(True);
   End Else If Hit(320,288,600,300) Then Begin
    Normals:=Not Normals;Changed(False);
   End Else If Hit(320,318,460,341) Then Begin
    View.Perspective:=Not View.Perspective;Changed(False);
   End Else If Hit(468,318,600,341) Then Begin
    View.Mode:=(View.Mode+1) Mod 3;Changed(False);
   End Else If Hit(170,348,300,371) Then Begin
    If ScaleText='1' Then ScaleText:='0.001' Else ScaleText:='1';
    Changed(True);
   End Else If Hit(20,379,150,402) Then Begin Info:=Not Info;Dirty:=True;
   End Else If Hit(170,379,300,402) Then Begin
    DefaultMeshOptions(View);Changed(False);
   End Else If Hit(320,379,452,402) Then Done:=True
   Else If Hit(468,379,600,402) Then Apply
   Else If Hit(20,82,300,278) And Not Info Then Begin
    Drag:=True;OldX:=MX;OldY:=MY;
   End;
  End;
  If Drag And ((MB And 1)<>0) And
   ((MX<>OldX) Or (MY<>OldY)) Then Begin
   View.RY:=Max(-3600,Min(3600,View.RY+(MX-OldX)*5));
   View.RX:=Max(-3600,Min(3600,View.RX+(MY-OldY)*5));
   OldX:=MX;OldY:=MY;Changed(False);
  End;
  If (MB And 1)=0 Then Drag:=False;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then E:=ReadKey Else Case K Of
    #27:Done:=True;#15:Browse;#13:Apply;
    #9:Begin Field:=1-Field;ReplaceText:=True;Dirty:=True;End;
    #1:ReplaceText:=True;
    #8:Begin
     If Field=0 Then Begin
      If ReplaceText Then Name:='' Else Delete(Name,Length(Name),1);
     End Else Begin
      If ReplaceText Then ScaleText:=''
      Else Delete(ScaleText,Length(ScaleText),1);Changed(True);
     End;
     ReplaceText:=False;Dirty:=True;
    End;
    Else If K>=' ' Then Begin
     If Field=0 Then Begin
      If ReplaceText Then Name:='';If Length(Name)<230 Then Name:=Name+K;
     End Else If K In ['0'..'9','e','E','+','-','.',','] Then Begin
      If ReplaceText Then ScaleText:='';If K=',' Then K:='.';
      If Length(ScaleText)<16 Then ScaleText:=ScaleText+K;Changed(True);
     End;
     ReplaceText:=False;Dirty:=True;
    End;
   End;
  End;
  Delay(10);
 Until Done;
 If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);ReleaseMesh(M);
 GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Procedure PanoramaDialog;
Var O,Original:TPanoramaOptions;Preview:PByteArr;Texts:Array[0..3] Of String;
 X,Y,MX,MY,MB,Previous,Field,PW,PH,I,Code,OldX,OldY:Integer;
 Dirty,PreviewDirty,Done,Drag,Dial,ReplaceText,Valid,Info,Before,
 Guides:Boolean;Message,S,T:String;K,E:Char;V:Double;A:Double;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Function Decimal(V:Double):String;
 Var S:String;
 Begin Str(V:0:1,S);Decimal:=S;End;
 Procedure Sync;
 Begin
  Texts[0]:=Decimal(O.Yaw/10);Texts[1]:=Decimal(O.Pitch/10);
  Texts[2]:=Decimal(O.Roll/10);Texts[3]:=Decimal(O.FOV/10);
 End;
 Procedure Changed;
 Begin Dirty:=True;PreviewDirty:=True;Message:='';Valid:=True;End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+23,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+23,True);SetColor(Black);
  OutTextXY(X+L+6,Y+T+8,Caption);
 End;
 Procedure Check(T:Integer;Value:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+320,Y+T,X+332,Y+T+12);
  If Value Then Begin Line(X+322,Y+T+6,X+325,Y+T+10);
   Line(X+325,Y+T+10,X+331,Y+T+2);End;
  OutTextXY(X+340,Y+T+3,Caption);
 End;
 Procedure ChangeField;
 Var I,J:Integer;
 Begin
  Valid:=True;
  For J:=0 To 3 Do Begin
   T:=Texts[J];For I:=1 To Length(T) Do If T[I]=',' Then T[I]:='.';
   Val(T,V,Code);
   If Code<>0 Then Valid:=False Else Begin
    If J=1 Then Begin If (V<-90) Or (V>90) Then Valid:=False;End
    Else If J=3 Then Begin
     If (V<10) Or (V>330) Or ((O.Mode=0) And (V>150)) Then Valid:=False;
    End Else If (V<-180) Or (V>180) Then Valid:=False;
   End;
  End;
  Dirty:=True;
  If Not Valid Then Begin
   Message:='Angles invalides. Vue : 10-150 deg, planete : 10-330 deg.';
   Exit;
  End;
  For J:=0 To 3 Do Begin
   T:=Texts[J];For I:=1 To Length(T) Do If T[I]=',' Then T[I]:='.';
   Val(T,V,Code);
   Case J Of 0:O.Yaw:=Round(V*10);1:O.Pitch:=Round(V*10);
    2:O.Roll:=Round(V*10);3:O.FOV:=Round(V*10);End;
  End;
  Changed;
 End;
 Procedure Draw;
 Var PX,PY,OX,OY,J,N:Integer;Color:Byte;Size,UndoSize:LongInt;
 Begin
  If PreviewDirty And Valid Then Begin
   If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);Preview:=Nil;
   Original:=O;
   If Before Then Begin Original.Mode:=1;Original.Yaw:=0;
    Original.Pitch:=0;Original.Roll:=0;End;
   If Not BuildPanorama(Original,PW,PH,True,Preview) Then
    Message:='Apercu annule ou memoire insuffisante.';
   PreviewDirty:=False;
  End;
  HideMouseCursor;FillRect(X,Y,X+620,Y+440,LightGray);
  DrawBevel(X,Y,X+620,Y+440,True);
  FillRect(X+3,Y+3,X+617,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Panorama spherique - explorer et reprojeter');
  S:='Source : calque actif';If O.CompositeSource Then
   S:='Source : calques visibles';Button(20,40,280,S);
  S:='Voir avant';If Before Then S:='Voir apres';Button(320,40,132,S);
  Button(468,40,132,'Informations');
  For PY:=0 To 195 Do For PX:=0 To 279 Do Begin
   Color:=White;If ((PX Div 10+PY Div 10) And 1)=0 Then Color:=LightGray;
   OX:=PX-(280-PW) Div 2;OY:=PY-(196-PH) Div 2;
   If (Preview<>Nil) And (OX>=0) And (OY>=0) And (OX<PW) And
    (OY<PH) Then If Preview^[LongInt(OY)*PW+OX]<>255 Then
     Color:=Preview^[LongInt(OY)*PW+OX];
   PutPixel(X+20+PX,Y+82+PY,Color);
  End;
  SetColor(Black);Rectangle(X+19,Y+81,X+300,Y+278);
  If Guides And Not Info Then Begin
   SetColor(Yellow);Line(X+155,Y+180,X+165,Y+180);
   Line(X+160,Y+175,X+160,Y+185);
   SetLineStyle(DottedLn,0,NormWidth);
   Line(X+113,Y+83,X+113,Y+276);Line(X+206,Y+83,X+206,Y+276);
   Line(X+21,Y+147,X+298,Y+147);Line(X+21,Y+212,X+298,Y+212);
   SetLineStyle(SolidLn,0,NormWidth);
  End;
  Size:=LongInt(ImgW)*ImgH;N:=0;
  For J:=0 To MAX_LAYERS-1 Do If Layers[J].Pixels<>Nil Then Inc(N);
  UndoSize:=Size*N+SizeOf(TRotationUndo);
  If Info Then Begin
   FillRect(X+21,Y+83,X+299,Y+276,White);SetColor(Black);
   OutTextXY(X+28,Y+94,'Source equirectangulaire');
   OutTextXY(X+28,Y+116,'Couverture : 360 x 180 deg');
   OutTextXY(X+28,Y+138,'Image : '+IntToStr(ImgW)+' x '+IntToStr(ImgH));
   OutTextXY(X+28,Y+160,'Sortie indexee : '+IntToStr(Size)+' o');
   OutTextXY(X+28,Y+182,'Copie annulation : '+IntToStr(UndoSize)+' o');
   OutTextXY(X+28,Y+204,'Allocation : '+IntToStr(UndoSize+Size)+' o');
   S:='Horizontal : raccord 360 deg';
   If Not O.Wrap Then S:='Horizontal : bords limites';
   OutTextXY(X+28,Y+226,S);
   OutTextXY(X+28,Y+248,'Vertical : poles limites');
  End;
  For J:=0 To 3 Do Begin
   Case J Of 0:S:='Longitude';1:S:='Latitude';2:S:='Roulis';3:S:='Champ H';End;
   SetColor(Black);OutTextXY(X+320,Y+90+J*33,S+' deg');
   FillRect(X+440,Y+82+J*33,X+600,Y+105+J*33,White);
   If Field=J Then SetColor(Blue) Else SetColor(DarkGray);
   Rectangle(X+440,Y+82+J*33,X+600,Y+105+J*33);SetColor(Black);
   S:=Texts[J];If (O.Mode=1) And (J=3) Then S:='360 (fixe)';
   OutTextXY(X+448,Y+90+J*33,S);
  End;
  Check(225,O.Wrap,'Raccord 360 deg');Check(247,O.Dither,'Tramage VGA');
  Check(269,Guides,'Guides apercu');
  SetColor(Black);Circle(X+558,Y+255,28);
  OutTextXY(X+554,Y+216,'N');OutTextXY(X+554,Y+289,'S');
  OutTextXY(X+594,Y+251,'E');OutTextXY(X+514,Y+251,'O');
  A:=O.Yaw*3.141592653589793/1800;
  Line(X+558,Y+255,X+558+Round(Sin(A)*24),Y+255-Round(Cos(A)*24));
  Case O.Mode Of 0:S:='Vue perspective';1:S:='Sphere 360 x 180';
   2:S:='Petite planete';End;
  Button(20,287,280,'Projection : '+S);
  Case O.Method Of 0:S:='Au plus proche';1:S:='Bilineaire';2:S:='Bicubique';End;
  Button(20,318,280,'Filtre : '+S);
  S:='Remplacer calque actif';If O.NewLayer Then S:='Nouveau calque';
  Button(320,318,280,S);
  Button(20,349,88,'Face');Button(116,349,88,'Droite');
  Button(212,349,88,'Arriere');Button(320,349,88,'Zenith');
  Button(416,349,88,'Nadir');Button(512,349,88,'Reset');
  Button(20,379,88,'Zoom +');Button(116,379,88,'Zoom -');
  Button(212,379,88,'Aide');Button(320,379,132,'Annuler');
  Button(468,379,132,'Appliquer');
  SetColor(Black);
  If ImgW=LongInt(ImgH)*2 Then S:='Source 2:1. Glisser : orientation.'
  Else S:='Source non 2:1 : elle est interpretee sur 360 x 180 deg.';
  OutTextXY(X+20,Y+409,S);
  If Message<>'' Then Begin SetColor(Red);
   OutTextXY(X+20,Y+425,Copy(Message,1,73));End;
  ShowMouseCursor;Dirty:=False;
 End;
 Procedure Apply;
 Begin
  ChangeField;If Not Valid Then Exit;
  If O.NewLayer And (LayerCount>=MAX_LAYERS) Then Begin
   Message:='Huit calques maximum : choisissez Remplacer calque actif.';
   Dirty:=True;Exit;
  End;
  If ApplyPanorama(O) Then Done:=True
  Else Begin Message:='Operation annulee ou memoire insuffisante.';
   Dirty:=True;End;
 End;
 Procedure Zoom(Delta:Integer);
 Begin
  If O.Mode=1 Then Begin
   Message:='La projection spherique couvre toujours 360 x 180 deg.';
   Dirty:=True;Exit;
  End;
  O.FOV:=Max(100,Min(3300,O.FOV+Delta));
  If O.Mode=0 Then O.FOV:=Min(1500,O.FOV);Sync;Changed;
 End;
Begin
 ResetToolTip;MenuActive:=False;DefaultPanoramaOptions(O);Sync;
 X:=(ScreenWidth-620) Div 2;Y:=(ScreenHeight-440) Div 2;
 If LongInt(ImgW)*196>LongInt(ImgH)*280 Then Begin
  PW:=280;PH:=Max(1,Round(ImgH*280.0/ImgW));
 End Else Begin PH:=196;PW:=Max(1,Round(ImgW*196.0/ImgH));End;
 Preview:=Nil;Field:=0;ReplaceText:=True;Info:=False;Before:=False;
 Guides:=False;Done:=False;Dirty:=True;PreviewDirty:=True;Valid:=True;
 Drag:=False;Dial:=False;Message:='';
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(20,40,300,63) Then Begin
    O.CompositeSource:=Not O.CompositeSource;Changed;
   End Else If Hit(320,40,452,63) Then Begin Before:=Not Before;Changed;
   End Else If Hit(468,40,600,63) Then Begin Info:=Not Info;Dirty:=True;
   End Else If Hit(440,82,600,204) Then Begin
    Field:=Min(3,(MY-Y-82) Div 33);
    If (O.Mode=1) And (Field=3) Then Field:=0;
    ReplaceText:=True;Dirty:=True;
   End Else If Hit(320,225,505,237) Then Begin O.Wrap:=Not O.Wrap;Changed;
   End Else If Hit(320,247,505,259) Then Begin O.Dither:=Not O.Dither;Changed;
   End Else If Hit(320,269,505,281) Then Begin
    Guides:=Not Guides;Dirty:=True;
   End Else If Hit(525,223,590,286) Then Dial:=True
   Else If Hit(20,287,300,310) Then Begin
    O.Mode:=(O.Mode+1) Mod 3;
    If O.Mode=0 Then O.FOV:=900;
    If O.Mode=2 Then Begin O.Pitch:=-900;O.FOV:=2500;End;
    If (O.Mode=1) And (Field=3) Then Field:=0;
    Sync;Changed;
   End Else If Hit(20,318,300,341) Then Begin
    O.Method:=(O.Method+1) Mod 3;Changed;
   End Else If Hit(320,318,600,341) Then Begin
    O.NewLayer:=Not O.NewLayer;Dirty:=True;
   End Else If Hit(20,349,600,372) Then Begin
    If MX<X+110 Then Begin O.Yaw:=0;O.Pitch:=0;O.Roll:=0;End
    Else If MX<X+206 Then Begin O.Yaw:=900;O.Pitch:=0;O.Roll:=0;End
    Else If MX<X+310 Then Begin O.Yaw:=1800;O.Pitch:=0;O.Roll:=0;End
    Else If MX<X+410 Then O.Pitch:=900
    Else If MX<X+506 Then O.Pitch:=-900
    Else DefaultPanoramaOptions(O);Sync;Changed;
   End Else If Hit(20,379,108,402) Then Zoom(-100)
   Else If Hit(116,379,204,402) Then Zoom(100)
   Else If Hit(212,379,300,402) Then Begin
    ShowDialog('Panorama spherique',
     'Ouvrir une image 360x180. Glisser : vue. Fleches : 1 deg.');
    Dirty:=True;GetMouseStateLocal(MX,MY,Previous);
   End Else If Hit(320,379,452,402) Then Done:=True
   Else If Hit(468,379,600,402) Then Apply
   Else If Hit(20,82,300,278) And Not Info Then Begin
    Drag:=True;OldX:=MX;OldY:=MY;Before:=False;
   End;
  End;
  If Drag And ((MB And 1)<>0) And
   ((MX<>OldX) Or (MY<>OldY)) Then Begin
   O.Yaw:=O.Yaw-(MX-OldX)*5;
   While O.Yaw>1800 Do Dec(O.Yaw,3600);
   While O.Yaw<-1800 Do Inc(O.Yaw,3600);
   O.Pitch:=Max(-900,Min(900,O.Pitch+(MY-OldY)*5));
   OldX:=MX;OldY:=MY;Sync;Changed;
  End;
  If Dial And ((MB And 1)<>0) Then Begin
   I:=Round(PanoramaAtan2(MX-X-558,Y+255-MY)*1800/3.141592653589793);
   If I<>O.Yaw Then Begin O.Yaw:=I;Sync;Changed;End;
  End;
  If (MB And 1)=0 Then Begin Drag:=False;Dial:=False;End;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then Begin
    E:=ReadKey;
    If E=#75 Then O.Yaw:=Max(-1800,O.Yaw-10);
    If E=#77 Then O.Yaw:=Min(1800,O.Yaw+10);
    If E=#72 Then O.Pitch:=Min(900,O.Pitch+10);
    If E=#80 Then O.Pitch:=Max(-900,O.Pitch-10);Sync;Changed;
   End Else Case K Of
    #27:Done:=True;#13:Apply;
    #9:Begin Field:=(Field+1) Mod 4;
     If (O.Mode=1) And (Field=3) Then Field:=0;
     ReplaceText:=True;Dirty:=True;End;
    #1:ReplaceText:=True;
    #8:Begin
     If ReplaceText Then Texts[Field]:=''
     Else Delete(Texts[Field],Length(Texts[Field]),1);
     ReplaceText:=False;ChangeField;
    End;
    Else If K In ['0'..'9','-','+','.',','] Then Begin
     If ReplaceText Then Texts[Field]:='';
     If Length(Texts[Field])<8 Then Texts[Field]:=Texts[Field]+K;
     ReplaceText:=False;ChangeField;
    End;
   End;
  End;
  Delay(10);
 Until Done;
 If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);
 GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Function SketchTempName(Var Name:String):Boolean;
Var I:Integer;H,M,S,C:Word;Base:String;
Begin
 SketchTempName:=False;Base:=GetEnv('TEMP');If Base='' Then Base:='.';
 If Base[Length(Base)]<>'\' Then Base:=Base+'\';
 GetTime(H,M,S,C);Base:=Base+'psp-sketch-'+IntToStr(H)+IntToStr(M)+
  IntToStr(S)+IntToStr(C)+'-';
 For I:=0 To 999 Do Begin
  Name:=Base+IntToStr(I)+'.obj';
  If (Length(Name)<=230) And Not MeshExportExists(Name) Then Begin
   SketchTempName:=True;Exit;
  End;
 End;
End;
Procedure RemoveSketchTemp(Const Name:String);
Var F:File;Code:Integer;
Begin
 If Name='' Then Exit;Assign(F,Name);{$I-}Erase(F);{$I+}Code:=IOResult;
End;
Function SketchOpenPage(Const UID:String;Page:Integer):Boolean;
Var URL:String;
Begin
 SketchOpenPage:=False;
 If Page=0 Then URL:='https://sketchfab.com/settings/password'
 Else If Page=1 Then URL:='https://sketchfab.com/models'
 Else Begin
  If Not SketchUIDValid(UID) Then Exit;
  URL:='https://sketchfab.com/3d-models/'+UID;
 End;
 {$IFDEF SKETCH_NATIVE}
 URL:=URL+#0;
 SketchOpenPage:=SFOpenURL(Nil,'open',@URL[1],Nil,Nil,1)>32;
 {$ENDIF}
End;

Procedure SketchfabDialog;
Var D:TSketchMetadata;M:PMesh;O:TMeshOptions;
 Prefix,Suffix:TSketchBuffer;Response:TSketchResponse;F:File;
 Preview:PByteArr;Token,UID,Status,Message,Error,Name,Boundary,S,T:String;
 X,Y,MX,MY,MB,Previous,Source,Tab,Field,PW,PH,I,J,OldX,OldY:Integer;
 Code:LongWord;Bytes,LastPoll:LongInt;
 Dirty,Rebuild,PreviewDirty,Done,Drag,ReplaceText,Info,Transform,
 Center,SwapAxes,Uncertain,ShowToken:Boolean;
 K,E:Char;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Procedure Changed(Geometry:Boolean);
 Begin Rebuild:=Rebuild Or Geometry;PreviewDirty:=True;Dirty:=True;End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+23,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+23,True);SetColor(Black);
  OutTextXY(X+L+6,Y+T+8,Caption);
 End;
 Procedure Check(L,T:Integer;Value:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+L,Y+T,X+L+12,Y+T+12);
  If Value Then Begin Line(X+L+2,Y+T+6,X+L+5,Y+T+10);
   Line(X+L+5,Y+T+10,X+L+11,Y+T+2);End;
  OutTextXY(X+L+18,Y+T+3,Caption);
 End;
 Function FieldText(N:Integer):String;
 Begin
  Case N Of 0:FieldText:=D.Title;1:FieldText:=D.Tags;
   2..5:FieldText:=D.Description[N-2];6:FieldText:=Token;
   7:FieldText:=D.Password;Else FieldText:='';End;
 End;
 Procedure SetField(N:Integer;Const T:String);
 Begin
  Case N Of 0:D.Title:=Copy(T,1,48);1:D.Tags:=T;
   2..5:D.Description[N-2]:=T;6:Token:=Copy(T,1,128);
   7:D.Password:=Copy(T,1,64);End;
 End;
 Procedure Edit(N,L,T,BW:Integer;Masked:Boolean);
 Var Text:String;J,Limit:Integer;
 Begin
  Text:=FieldText(N);
  If Masked Then For J:=1 To Length(Text) Do Text[J]:='*';
  Limit:=(BW-12) Div 8;
  If Length(Text)>Limit Then Text:=Copy(Text,Length(Text)-Limit+1,Limit);
  FillRect(X+L,Y+T,X+L+BW,Y+T+21,White);
  If Field=N Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X+L,Y+T,X+L+BW,Y+T+21);SetColor(Black);
  OutTextXY(X+L+6,Y+T+7,Text);
 End;
 Procedure Draw;
 Var PX,PY,OX,OY,J:Integer;Color:Byte;
 Begin
  If Rebuild Then Begin
   ReleaseMesh(M);
   If Not PrepareMeshExport(Layers[Source].Mesh,Layers[Source].MeshOptions,
    Transform,Center,SwapAxes,False,1,M,Error) Then Message:=Error;
   Rebuild:=False;
  End;
  If PreviewDirty Then Begin
   If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);Preview:=Nil;
   If M<>Nil Then Begin
    If Not RenderMesh(M,O,PW,PH,True,Preview) Then
     Message:='Apercu annule ou memoire insuffisante.';
    MeshExportStream(M,0,True,False,False,F,Bytes);
   End;
   PreviewDirty:=False;
  End;
  HideMouseCursor;FillRect(X,Y,X+620,Y+440,LightGray);
  DrawBevel(X,Y,X+620,Y+440,True);
  FillRect(X+3,Y+3,X+617,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,'Partager sur Sketchfab - modele et publication');
  Button(20,40,180,'1. Modele');Button(210,40,180,'2. Publication');
  Button(400,40,200,'3. Connexion / suivi');
  SetColor(Blue);Line(X+20+Tab*190,Y+65,X+195+Tab*190,Y+65);
  For PY:=0 To 195 Do For PX:=0 To 279 Do Begin
   Color:=White;If ((PX Div 10+PY Div 10) And 1)=0 Then Color:=LightGray;
   OX:=PX-(280-PW) Div 2;OY:=PY-(196-PH) Div 2;
   If (Preview<>Nil) And (OX>=0) And (OY>=0) And (OX<PW) And
    (OY<PH) Then If Preview^[LongInt(OY)*PW+OX]<>255 Then
     Color:=Preview^[LongInt(OY)*PW+OX];
   PutPixel(X+20+PX,Y+82+PY,Color);
  End;
  SetColor(Black);Rectangle(X+19,Y+81,X+300,Y+278);
  If Info And (M<>Nil) Then Begin
   FillRect(X+21,Y+83,X+299,Y+276,White);SetColor(Black);
   OutTextXY(X+28,Y+98,'Geometrie OBJ triangulee');
   OutTextXY(X+28,Y+126,IntToStr(M^.VertexCount)+' sommets');
   OutTextXY(X+28,Y+150,IntToStr(M^.TriangleCount)+' triangles');
   OutTextXY(X+28,Y+174,'Poids OBJ : '+IntToStr(Bytes)+' o');
   OutTextXY(X+28,Y+198,'Normales par face exportees');
   OutTextXY(X+28,Y+222,'Sans textures ni couleurs');
   OutTextXY(X+28,Y+246,'Camera locale non envoyee');
  End;
  SetColor(Black);
  If M<>Nil Then OutTextXY(X+20,Y+292,IntToStr(M^.TriangleCount)+
   ' triangles / '+IntToStr(Bytes)+' octets');
  Button(20,312,132,'Informations');Button(168,312,132,'Vue initiale');
  S:='Orthographique';If O.Perspective Then S:='Perspective';
  Button(20,343,132,S);Button(168,343,132,'Solide / fil');
  If Tab=0 Then Begin
   Button(320,82,280,'Calque : '+Layers[Source].Name);
   Check(320,125,Transform,'Appliquer transformations');
   Check(320,150,Center,'Centrer le modele');
   Check(320,175,SwapAxes,'Echanger Y / Z');
   SetColor(Black);OutTextXY(X+320,Y+210,'Format : OBJ + normales');
   OutTextXY(X+320,Y+234,'Geometrie seule. Pas de textures.');
   OutTextXY(X+320,Y+258,'Glisser l''apercu pour tourner.');
   OutTextXY(X+320,Y+282,'La vue locale n''est pas publiee.');
   OutTextXY(X+320,Y+316,'Destination : api.sketchfab.com');
   OutTextXY(X+320,Y+340,'TLS et proxy du systeme Windows');
  End Else If Tab=1 Then Begin
   OutTextXY(X+320,Y+82,'Titre (48)');Edit(0,320,98,280,False);
   OutTextXY(X+320,Y+126,'Tags (espaces)');Edit(1,320,142,280,False);
   OutTextXY(X+320,Y+170,'Description (4 lignes, 1023 max)');
   For J:=0 To 3 Do Edit(2+J,320,188+J*25,280,False);
   Check(320,300,D.PrivateModel,'Prive (offre compatible)');
   Check(320,323,D.Published,'Publier apres traitement');
   Check(320,346,D.AgeRestricted,'Contenu reserve aux adultes');
  End Else Begin
   OutTextXY(X+320,Y+82,'Cle API (non enregistree)');
   Edit(6,320,98,280,Not ShowToken);
   Check(320,132,ShowToken,'Afficher la cle');
   Button(320,157,132,'Obtenir cle');Button(468,157,132,'Tester compte');
   SetColor(Black);OutTextXY(X+320,Y+197,'Mot de passe modele prive');
   Edit(7,320,214,280,True);
   OutTextXY(X+320,Y+251,'Etat : '+Copy(Status,1,25));
   OutTextXY(X+320,Y+274,'UID : '+Copy(UID,1,16));
   OutTextXY(X+368,Y+288,Copy(UID,17,16));
   Button(320,300,132,'Verifier etat');Button(468,300,132,'Voir modele');
   Button(320,335,280,'Ouvrir Sketchfab / mes modeles');
  End;
  Button(20,385,180,'Aide');S:='Annuler';If UID<>'' Then S:='Fermer';
  Button(320,385,132,S);S:='Envoyer';If UID<>'' Then S:='Envoye';
  Button(468,385,132,S);SetColor(Black);
  S:='Brouillon';If D.Published Then S:='Publication demandee';
  If D.PrivateModel Then S:=S+' / prive' Else S:=S+' / non prive';
  OutTextXY(X+20,Y+413,S);
  If Message<>'' Then OutTextXY(X+20,Y+429,Copy(Message,1,73));
  ShowMouseCursor;Dirty:=False;
 End;
 Procedure CheckAccount;
 Begin
  Prefix.Count:=0;Suffix.Count:=0;
  If SketchRequest(Token,'GET','/v3/me','','',Prefix,Suffix,
   Code,Response,Error) Then Begin
   S:=SketchJSON(Response,'username');
   If S='' Then S:='Compte authentifie';Message:='Compte : '+S;
  End Else Message:=Error;Dirty:=True;
 End;
 Procedure CheckStatus;
 Var H,Mn,Sec,Hund:Word;NowValue,Delta:LongInt;
 Begin
  GetTime(H,Mn,Sec,Hund);NowValue:=LongInt(H)*3600+Mn*60+Sec;
  Delta:=NowValue-LastPoll;If Delta<0 Then Inc(Delta,86400);
  If (LastPoll>=0) And (Delta<5) Then Begin
   Message:='Attendre cinq secondes avant une nouvelle verification.';
   Dirty:=True;Exit;
  End;
  LastPoll:=NowValue;
  If Not SketchUIDValid(UID) Then Begin Message:='Aucun modele envoye.';
   Dirty:=True;Exit;End;
  Prefix.Count:=0;Suffix.Count:=0;
  If SketchRequest(Token,'GET','/v3/models/'+UID,'','',Prefix,Suffix,
   Code,Response,Error) Then Begin
   S:=UpperStr(SketchJSON(Response,'processing'));
   If S='' Then S:=UpperStr(SketchJSON(Response,'processingStatus'));
   If S='SUCCEEDED' Then Status:='Traitement termine'
   Else If S='FAILED' Then Status:='Traitement echoue'
   Else If S='PENDING' Then Status:='En attente'
   Else If S='PROCESSING' Then Status:='Traitement en cours'
   Else Status:='Etat non disponible';Message:=Status;
  End Else Message:=Error;Dirty:=True;
 End;
 Procedure Share;
 Begin
  If Rebuild Then Draw;
  If UID<>'' Then Begin Message:='Modele deja envoye. Utiliser Verifier etat.';
   Tab:=2;Dirty:=True;Exit;End;
  If Not SketchMetadataValid(D,Error) Then Begin
   Message:=Error;Tab:=1;Dirty:=True;Exit;End;
  If Not SketchTokenValid(Token) Then Begin
   Message:='Saisir une cle API valide.';Tab:=2;Field:=6;
   Dirty:=True;Exit;End;
  If M=Nil Then Begin Message:='Geometrie indisponible.';Dirty:=True;Exit;End;
  If Uncertain Then
   If Not YesNoDialog('Envoi precedent incertain',
    'Risque de doublon. Renvoyer quand meme ?') Then
    Begin Dirty:=True;Exit;End;
  Boundary:=SketchBoundary(D);
  If Not BuildSketchMultipart(D,Boundary,0,Prefix,Suffix) Then Begin
   Message:='Impossible de preparer les informations.';Dirty:=True;Exit;End;
  If Not SketchTempName(Name) Then Begin
   Message:='Dossier temporaire indisponible.';Dirty:=True;Exit;End;
  If Not WriteMeshExport(M,Name,0,True,True,Error) Then Begin
   Message:=Error;Dirty:=True;Exit;End;
  S:='Envoyer en brouillon';If D.Published Then S:='Publier apres traitement';
  If D.PrivateModel Then S:=S+' (prive)' Else S:=S+' (non prive)';
  If Not YesNoDialog(S,
   'Envoyer modele + infos a Sketchfab ?') Then
   Begin RemoveSketchTemp(Name);Name:='';Dirty:=True;Exit;End;
  If SketchRequest(Token,'POST','/v3/models',Name,Boundary,Prefix,Suffix,
   Code,Response,Error) Then Begin
   UID:=SketchJSON(Response,'uid');
   If SketchUIDValid(UID) Then Begin
    Status:='Envoi accepte';Message:='Verifier ensuite le traitement.';
    Uncertain:=False;
   End Else Begin UID:='';Uncertain:=True;
    Message:='Envoi accepte sans UID lisible. Verifier le compte.';End;
  End Else Begin
   Uncertain:=(Code=0) Or (Code>=500) Or
    ((Code>=200) And (Code<300));Message:=Error;
  End;
  RemoveSketchTemp(Name);Name:='';FillChar(Prefix,SizeOf(Prefix),0);
  FillChar(Suffix,SizeOf(Suffix),0);Tab:=2;Dirty:=True;
  GetMouseStateLocal(MX,MY,Previous);
 End;
Begin
 ResetToolTip;MenuActive:=False;Source:=ActiveLayer;
 If Layers[Source].Mesh=Nil Then Begin
  Source:=-1;For I:=0 To LayerCount-1 Do
   If (Source<0) And (Layers[I].Mesh<>Nil) Then Source:=I;
 End;
 If Source<0 Then Begin
  ShowDialog('Sketchfab','Importez un modele 3D avant de le partager.');Exit;
 End;
 FillChar(D,SizeOf(D),0);D.Title:=Layers[Source].Name;
 Token:='';UID:='';Status:='Non envoye';Message:='';Name:='';LastPoll:=-1;
 M:=Nil;Preview:=Nil;Bytes:=0;DefaultMeshOptions(O);
 Transform:=False;Center:=False;SwapAxes:=False;Uncertain:=False;
 ShowToken:=False;Info:=False;Tab:=0;Field:=0;ReplaceText:=True;
 X:=(ScreenWidth-620) Div 2;Y:=(ScreenHeight-440) Div 2;
 If LongInt(ImgW)*196>LongInt(ImgH)*280 Then Begin
  PW:=280;PH:=Max(1,Round(ImgH*280.0/ImgW));
 End Else Begin PH:=196;PW:=Max(1,Round(ImgW*196.0/ImgH));End;
 Done:=False;Dirty:=True;Rebuild:=True;PreviewDirty:=True;Drag:=False;
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(20,40,600,63) Then Begin
    Tab:=Min(2,(MX-X-20) Div 190);Field:=0;
    If Tab=2 Then Field:=6;ReplaceText:=True;Dirty:=True;
   End Else If Hit(20,312,152,335) Then Begin Info:=Not Info;Dirty:=True;
   End Else If Hit(168,312,300,335) Then Begin
    DefaultMeshOptions(O);Changed(False);
   End Else If Hit(20,343,152,366) Then Begin
    O.Perspective:=Not O.Perspective;Changed(False);
   End Else If Hit(168,343,300,366) Then Begin
    O.Mode:=(O.Mode+1) Mod 3;Changed(False);
   End Else If Hit(20,385,200,408) Then Begin
    ShowDialog('Partager sur Sketchfab',
     'Brouillon par defaut. Prive/mot de passe selon votre offre Sketchfab.');
    Dirty:=True;GetMouseStateLocal(MX,MY,Previous);
   End Else If Hit(320,385,452,408) Then Done:=True
   Else If Hit(468,385,600,408) Then Share
   Else If Hit(20,82,300,278) And Not Info Then Begin
    Drag:=True;OldX:=MX;OldY:=MY;
   End Else If Tab=0 Then Begin
    If Hit(320,82,600,105) And (UID='') Then Begin
     Repeat Source:=(Source+1) Mod LayerCount;
     Until Layers[Source].Mesh<>Nil;Changed(True);
    End Else If Hit(320,125,600,137) Then Begin
     Transform:=Not Transform;Changed(True);
    End Else If Hit(320,150,600,162) Then Begin
     Center:=Not Center;Changed(True);
    End Else If Hit(320,175,600,187) Then Begin
     SwapAxes:=Not SwapAxes;Changed(True);
    End;
   End Else If Tab=1 Then Begin
    If Hit(320,98,600,119) Then Field:=0
    Else If Hit(320,142,600,163) Then Field:=1
    Else If Hit(320,188,600,284) Then
     Field:=2+Min(3,(MY-Y-188) Div 25)
    Else If Hit(320,300,600,312) Then D.PrivateModel:=Not D.PrivateModel
    Else If Hit(320,323,600,335) Then D.Published:=Not D.Published
    Else If Hit(320,346,600,358) Then D.AgeRestricted:=Not D.AgeRestricted;
    ReplaceText:=True;Dirty:=True;
   End Else Begin
    If Hit(320,98,600,119) Then Begin Field:=6;ReplaceText:=True;End
    Else If Hit(320,214,600,235) Then Begin Field:=7;ReplaceText:=True;End
    Else If Hit(320,132,600,144) Then ShowToken:=Not ShowToken
    Else If Hit(320,157,452,180) Then SketchOpenPage('',0)
    Else If Hit(468,157,600,180) Then CheckAccount
    Else If Hit(320,300,452,323) Then CheckStatus
    Else If Hit(468,300,600,323) Then Begin
     If Not SketchOpenPage(UID,2) Then Message:='Aucun lien de modele valide.';
    End Else If Hit(320,335,600,358) Then SketchOpenPage('',1);
    Dirty:=True;GetMouseStateLocal(MX,MY,Previous);
   End;
  End;
  If Drag And ((MB And 1)<>0) And
   ((MX<>OldX) Or (MY<>OldY)) Then Begin
   O.RY:=Max(-3600,Min(3600,O.RY+(MX-OldX)*5));
   O.RX:=Max(-3600,Min(3600,O.RX+(MY-OldY)*5));
   OldX:=MX;OldY:=MY;Changed(False);
  End;
  If (MB And 1)=0 Then Drag:=False;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then E:=ReadKey Else Case K Of
    #27:Done:=True;
    #13:If Tab=1 Then Begin
     If Field<2 Then Inc(Field) Else Field:=2+(Field-1) Mod 4;
     ReplaceText:=True;Dirty:=True;End;
    #9:Begin
     If Tab=1 Then Field:=(Field+1) Mod 6
     Else If Tab=2 Then Field:=6+(Field+1) Mod 2;
     ReplaceText:=True;Dirty:=True;
    End;
    #1:ReplaceText:=True;
    #8:If Tab>0 Then Begin
     S:=FieldText(Field);If ReplaceText Then S:=''
     Else Delete(S,Length(S),1);SetField(Field,S);
     ReplaceText:=False;Dirty:=True;
    End;
    Else If (K>=' ') And (Tab>0) Then Begin
     S:=FieldText(Field);If ReplaceText Then S:='';
     If Length(S)<255 Then S:=S+K;SetField(Field,S);
     ReplaceText:=False;Dirty:=True;
    End;
   End;
  End;
  Delay(10);
 Until Done;
 If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);ReleaseMesh(M);
 ClearSketchSecrets(Token,D);FillChar(Prefix,SizeOf(Prefix),0);
 FillChar(Response,SizeOf(Response),0);
 FillChar(S,SizeOf(S),0);FillChar(T,SizeOf(T),0);
 GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Function EditVectorPath(Var Path:TVectorPath):Boolean;
Var P,Undo:TVectorPath;X,Y,W,H,OX,OY,MX,MY,MB,Previous,I,J,Selected,
 Field,Code:Integer;Dirty,Done,Accepted,Drag,ReplaceText:Boolean;
 TextDirty,TextValid:Boolean;
 XS,YS,S,Message:String;K:Char;Value,Distance,Best:Double;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Procedure Sync;
 Begin
  TextDirty:=False;TextValid:=True;
  XS:='';YS:='';If (Selected<0) Or (Selected>=P.Count) Then Exit;
  Str(P.Points[Selected].X*ImgW:0:3,XS);
  Str(P.Points[Selected].Y*ImgH:0:3,YS);
 End;
 Procedure SaveUndo;
 Begin Undo:=P;End;
 Procedure Button(L,T,BW:Integer;Const Text:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+23,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+23,True);SetColor(Black);
  OutTextXY(X+L+6,Y+T+8,Text);
 End;
 Procedure MovePoint;
 Begin
  If Selected<0 Then Exit;
  P.Points[Selected].X:=MeshMax(0,MeshMin(1,(MX-X-OX)/W));
  P.Points[Selected].Y:=MeshMax(0,MeshMin(1,(MY-Y-OY)/H));
  Sync;Dirty:=True;
 End;
 Procedure Parse;
 Var TX,TY:Double;I:Integer;T:String;
 Begin
  TextValid:=False;
  If Selected<0 Then Begin Message:='Selectionner un point.';Exit;End;
  T:=XS;
  For I:=1 To Length(T) Do If T[I]=',' Then T[I]:='.';
  Val(T,TX,Code);If Code<>0 Then Begin Message:='Coordonnee X invalide.';
   Dirty:=True;Exit;End;
  T:=YS;For I:=1 To Length(T) Do If T[I]=',' Then T[I]:='.';
  Val(T,TY,Code);
  If (Code<>0) Or (TX<0) Or (TX>ImgW) Or (TY<0) Or (TY>ImgH) Then Begin
   Message:='Coordonnees hors du document.';Dirty:=True;Exit;
  End;
  SaveUndo;P.Points[Selected].X:=TX/ImgW;P.Points[Selected].Y:=TY/ImgH;
  Message:='';TextDirty:=False;TextValid:=True;Dirty:=True;
 End;
 Procedure Draw;
 Var I,J,PX,PY,QX,QY:Integer;
 Begin
  HideMouseCursor;FillRect(X,Y,X+620,Y+440,LightGray);
  DrawBevel(X,Y,X+620,Y+440,True);
  FillRect(X+3,Y+3,X+617,Y+26,Blue);SetColor(White);
  OutTextXY(X+12,Y+10,
   'Trace vectoriel - ajouter, deplacer et regler les points');
  FillRect(X+20,Y+45,X+410,Y+345,DarkGray);
  FillRect(X+OX,Y+OY,X+OX+W,Y+OY+H,White);
  SetColor(LightGray);
  For I:=1 To 9 Do Begin
   Line(X+OX+W*I Div 10,Y+OY,X+OX+W*I Div 10,Y+OY+H);
   Line(X+OX,Y+OY+H*I Div 10,X+OX+W,Y+OY+H*I Div 10);
  End;
  For I:=0 To P.Count-1 Do Begin
   PX:=X+OX+Round(P.Points[I].X*W);PY:=Y+OY+Round(P.Points[I].Y*H);
   J:=I+1;If J=P.Count Then J:=0;
   If (I<P.Count-1) Or P.Closed Then Begin
    QX:=X+OX+Round(P.Points[J].X*W);QY:=Y+OY+Round(P.Points[J].Y*H);
    SetColor(Blue);Line(PX,PY,QX,QY);
   End;
   SetColor(Blue);If I=Selected Then SetColor(Red);
   Rectangle(PX-3,PY-3,PX+3,PY+3);
  End;
  SetColor(Black);OutTextXY(X+430,Y+48,IntToStr(P.Count)+' / 128 points');
  Button(430,76,170,'Rectangle');Button(430,107,170,'Ellipse 32 points');
  Button(430,138,170,'Etoile');Button(430,169,170,'Nouveau trace');
  S:='Fermer le contour';If P.Closed Then S:='Ouvrir le contour';
  Button(430,200,170,S);Button(430,231,170,'Supprimer point');
  OutTextXY(X+430,Y+270,'X en pixels');
  FillRect(X+430,Y+285,X+600,Y+308,White);
  If Field=0 Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X+430,Y+285,X+600,Y+308);SetColor(Black);
  OutTextXY(X+436,Y+293,XS);
  OutTextXY(X+430,Y+320,'Y en pixels');
  FillRect(X+430,Y+335,X+600,Y+358,White);
  If Field=1 Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X+430,Y+335,X+600,Y+358);SetColor(Black);
  OutTextXY(X+436,Y+343,YS);
  Button(20,367,120,'Annuler point');Button(150,367,120,'Inserer apres');
  Button(280,367,130,'Appliquer X/Y');Button(430,367,170,'Sens inverse');
  Button(320,400,132,'Annuler');Button(468,400,132,'Utiliser');
  OutTextXY(X+20,Y+407,'Clic : ajouter ou glisser.');
  If Message<>'' Then Begin SetColor(Red);
   OutTextXY(X+20,Y+430,Copy(Message,1,73));End;
  ShowMouseCursor;Dirty:=False;
 End;
Begin
 EditVectorPath:=False;P:=Path;Undo:=P;Selected:=-1;
 X:=(ScreenWidth-620) Div 2;Y:=(ScreenHeight-440) Div 2;
 W:=390;H:=Max(1,Round(ImgH*390.0/ImgW));
 If H>300 Then Begin H:=300;W:=Max(1,Round(ImgW*300.0/ImgH));End;
 OX:=20+(390-W) Div 2;OY:=45+(300-H) Div 2;
 Field:=0;ReplaceText:=True;Message:='';XS:='';YS:='';
 TextDirty:=False;TextValid:=True;
 Dirty:=True;Done:=False;Accepted:=False;Drag:=False;
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(OX,OY,OX+W,OY+H) Then Begin
    Selected:=-1;Best:=64;
    For I:=0 To P.Count-1 Do Begin
     Distance:=Sqr(MX-X-OX-P.Points[I].X*W)+
      Sqr(MY-Y-OY-P.Points[I].Y*H);
     If Distance<Best Then Begin Best:=Distance;Selected:=I;End;
    End;
    SaveUndo;
    If (Selected<0) And (P.Count<128) Then Begin
     Selected:=P.Count;Inc(P.Count);MovePoint;
    End;
    Drag:=Selected>=0;Sync;Dirty:=True;
   End Else If Hit(430,76,600,161) Then Begin
    SaveUndo;I:=Min(2,(MY-Y-76) Div 31);VectorPathPreset(P,I);
    Selected:=0;Sync;Dirty:=True;
   End Else If Hit(430,169,600,192) Then Begin
    SaveUndo;P.Count:=0;P.Closed:=False;Selected:=-1;Sync;Dirty:=True;
   End Else If Hit(430,200,600,223) Then Begin
    SaveUndo;P.Closed:=Not P.Closed;Dirty:=True;
   End Else If Hit(430,231,600,254) Then Begin
    If Selected>=0 Then Begin SaveUndo;
     For I:=Selected To P.Count-2 Do P.Points[I]:=P.Points[I+1];
     Dec(P.Count);Selected:=Min(Selected,P.Count-1);Sync;Dirty:=True;End;
   End Else If Hit(430,285,600,308) Or Hit(430,335,600,358) Then Begin
    Field:=0;If MY>Y+320 Then Field:=1;ReplaceText:=True;Dirty:=True;
   End Else If Hit(20,367,140,390) Then Begin
    P:=Undo;Selected:=-1;Sync;Dirty:=True;
   End Else If Hit(150,367,270,390) Then Begin
    If (Selected>=0) And (P.Count<128) Then Begin
     SaveUndo;J:=(Selected+1) Mod P.Count;
     For I:=P.Count DownTo Selected+2 Do P.Points[I]:=P.Points[I-1];
     P.Points[Selected+1].X:=(P.Points[Selected].X+P.Points[J].X)/2;
     P.Points[Selected+1].Y:=(P.Points[Selected].Y+P.Points[J].Y)/2;
     Inc(P.Count);Inc(Selected);Sync;Dirty:=True;
    End;
   End Else If Hit(280,367,410,390) Then Parse
   Else If Hit(430,367,600,390) Then Begin
    SaveUndo;For I:=0 To P.Count Div 2-1 Do Begin
     Value:=P.Points[I].X;P.Points[I].X:=P.Points[P.Count-1-I].X;
     P.Points[P.Count-1-I].X:=Value;
     Value:=P.Points[I].Y;P.Points[I].Y:=P.Points[P.Count-1-I].Y;
     P.Points[P.Count-1-I].Y:=Value;
    End;Selected:=-1;Sync;Dirty:=True;
   End Else If Hit(320,400,452,423) Then Done:=True
   Else If Hit(468,400,600,423) Then Begin
    If TextDirty Then Parse;
    If Not TextValid Then Dirty:=True
    Else If P.Count<3 Then Begin
     Message:='Trois points minimum.';Dirty:=True;End
    Else If Not P.Closed Then Begin
     Message:='Fermer le contour avant de l''utiliser.';Dirty:=True;End
    Else Begin Accepted:=True;Done:=True;End;
   End;
  End;
  If Drag And ((MB And 1)<>0) Then MovePoint;
  If (MB And 1)=0 Then Drag:=False;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   Case K Of
    #27:Done:=True;#13:Parse;#9:Begin Field:=1-Field;
     ReplaceText:=True;Dirty:=True;End;
    #1:ReplaceText:=True;
    #0:K:=ReadKey;
    Else If (K=#8) Or (K In ['0'..'9','.','-',',']) Then Begin
     S:=XS;If Field=1 Then S:=YS;
     If ReplaceText Then S:='';
     If K=#8 Then Delete(S,Length(S),1)
     Else If Length(S)<15 Then S:=S+K;
     If Field=0 Then XS:=S Else YS:=S;
     ReplaceText:=False;TextDirty:=True;Dirty:=True;
    End;
   End;
  End;
  Delay(10);
 Until Done;
 If Accepted Then Begin Path:=P;EditVectorPath:=True;End;
End;

Procedure ExtrudeDialogFor(PathMode,SelectionMode:Boolean);
Var LocalPath:TVectorPath;E:TExtrudeOptions;View:TMeshOptions;
 Stats:TExtrudeStats;Region,CapturedRegion:TSelectionExtrude;
 M:PMesh;Preview:PByteArr;Texts:Array[0..15] Of String;
 X,Y,MX,MY,MB,Previous,Field,Tab,PW,PH,Display,Code,OldX,OldY:Integer;
 Target:Integer;V:Double;Message,Error,S,T:String;K,Key:Char;
 Dirty,Rebuild,PreviewDirty,Done,Drag,ReplaceText,Valid:Boolean;
 Function Hit(L,T,R,B:Integer):Boolean;
 Begin Hit:=(MX>=X+L) And (MX<=X+R) And (MY>=Y+T) And (MY<=Y+B);End;
 Function Decimal(V:Double):String;
 Var T:String;
 Begin Str(V:0:1,T);Decimal:=T;End;
 Function Memory(N:LongInt):String;
 Var T:String;
 Begin
  If N>=1048576 Then Begin Str(N/1048576.0:0:2,T);T:=T+' Mo';End
  Else If N>=1024 Then Begin Str(N/1024.0:0:1,T);T:=T+' Ko';End
  Else T:=IntToStr(N)+' o';Memory:=T;
 End;
 Procedure Sync;
 Begin
  Texts[0]:=Decimal(E.Depth/10);Texts[1]:=IntToStr(E.Resolution);
  Texts[2]:=IntToStr(E.Segments);Texts[3]:=IntToStr(E.Taper);
  Texts[4]:=Decimal(E.Twist/10);Texts[5]:=IntToStr(E.Threshold);
  Texts[6]:=IntToStr(E.Coverage);Texts[7]:=Decimal(View.RX/10);
  Texts[8]:=Decimal(View.RY/10);Texts[9]:=Decimal(View.RZ/10);
  Texts[10]:=IntToStr(Region.Bounds.L);Texts[11]:=IntToStr(Region.Bounds.T);
  Texts[12]:=IntToStr(Region.Bounds.R-Region.Bounds.L+1);
  Texts[13]:=IntToStr(Region.Bounds.B-Region.Bounds.T+1);
  Texts[14]:=IntToStr(Region.Radius);Texts[15]:=IntToStr(Region.Border);
 End;
 Procedure Changed(Geometry:Boolean);
 Begin Rebuild:=Rebuild Or Geometry;PreviewDirty:=True;Dirty:=True;
  Message:='';Valid:=True;End;
 Procedure Parse;
 Var I,J,Minimum,Maximum:Integer;Values:Array[0..15] Of Double;
 Begin
  Valid:=False;Dirty:=True;
  For J:=0 To 15 Do Begin
   T:=Texts[J];For I:=1 To Length(T) Do If T[I]=',' Then T[I]:='.';
   Val(T,V,Code);
   Case J Of 0:Begin Minimum:=0;Maximum:=1000;End;
    1:Begin Minimum:=8;Maximum:=64;End;
    2:Begin Minimum:=1;Maximum:=8;End;
    3:Begin Minimum:=-80;Maximum:=200;End;
    4:Begin Minimum:=-180;Maximum:=180;End;
    5:Begin Minimum:=0;Maximum:=255;End;
    6:Begin Minimum:=1;Maximum:=100;End;
    10:Begin Minimum:=0;Maximum:=ImgW-1;End;
    11:Begin Minimum:=0;Maximum:=ImgH-1;End;
    12:Begin Minimum:=1;Maximum:=ImgW;End;
    13:Begin Minimum:=1;Maximum:=ImgH;End;
    14,15:Begin Minimum:=1;Maximum:=49;End;
    Else Begin Minimum:=-360;Maximum:=360;End;
   End;
   If (Code<>0) Or (V<Minimum) Or (V>Maximum) Or
    ((J=0) And (V<0.1)) Then Begin
    Message:='Champ invalide : verifier les valeurs et les limites.';Exit;
   End;
   If (J In [1,2,3,5,6,10..15]) And (Abs(V-Round(V))>0.000001) Then Begin
    Message:='Precision, segments, effilement et seuils : nombres entiers.';
    Exit;
   End;
   Values[J]:=V;
  End;
  If Abs(Values[4])>Values[2]*45 Then Begin
   Message:='Torsion : ajouter des segments (45 deg maximum par segment).';
   Exit;
  End;
  If (Values[10]+Values[12]>ImgW) Or
   (Values[11]+Values[13]>ImgH) Then Begin
   Message:='La zone depasse le document.';Exit;
  End;
  Region.Bounds.L:=Round(Values[10]);Region.Bounds.T:=Round(Values[11]);
  Region.Bounds.R:=Region.Bounds.L+Round(Values[12])-1;
  Region.Bounds.B:=Region.Bounds.T+Round(Values[13])-1;
  Region.Radius:=Round(Values[14]);Region.Border:=Round(Values[15]);
  E.Depth:=Round(Values[0]*10);E.Resolution:=Round(Values[1]);
  E.Segments:=Round(Values[2]);E.Taper:=Round(Values[3]);
  E.Twist:=Round(Values[4]*10);E.Threshold:=Round(Values[5]);
  E.Coverage:=Round(Values[6]);View.RX:=Round(Values[7]*10);
  View.RY:=Round(Values[8]*10);View.RZ:=Round(Values[9]*10);
  Changed((Field<7) Or (Field>=10));
 End;
 Procedure Button(L,T,BW:Integer;Const Caption:String);
 Begin
  FillRect(X+L,Y+T,X+L+BW,Y+T+23,LightGray);
  DrawBevel(X+L,Y+T,X+L+BW,Y+T+23,True);SetColor(Black);
  OutTextXY(X+L+6,Y+T+8,Caption);
 End;
 Procedure Check(L,T:Integer;Value:Boolean;Const Caption:String);
 Begin
  SetColor(Black);Rectangle(X+L,Y+T,X+L+12,Y+T+12);
  If Value Then Begin Line(X+L+2,Y+T+6,X+L+5,Y+T+10);
   Line(X+L+5,Y+T+10,X+L+11,Y+T+2);End;
  OutTextXY(X+L+18,Y+T+3,Caption);
 End;
 Procedure Edit(N,T:Integer;Const LabelText:String);
 Begin
  SetColor(Black);OutTextXY(X+320,Y+T+8,LabelText);
  FillRect(X+460,Y+T,X+600,Y+T+22,White);
  If Field=N Then SetColor(Blue) Else SetColor(DarkGray);
  Rectangle(X+460,Y+T,X+600,Y+T+22);SetColor(Black);
  OutTextXY(X+468,Y+T+8,Texts[N]);
 End;
 Procedure Draw;
 Var PX,PY,OX,OY,MW,MH,GX,GY,Shown:Integer;Color:Byte;
 Begin
  Shown:=Display;
  If SelectionMode Then Case Display Of
   1:Shown:=3;2:Shown:=1;3:Shown:=2;End;
  If Rebuild And Valid Then Begin
   ReleaseMesh(M);
   If SelectionMode Then Begin
    If Not BuildSelectionExtrusion(Region,E,True,M,Stats,Error) Then
     Message:=Error;
   End Else If PathMode Then Begin
    If Not BuildPathExtrusion(LocalPath,E,M,Stats,Error) Then Message:=Error;
   End Else If Not BuildExtrusion(E,True,M,Stats,Error) Then Message:=Error;
   Rebuild:=False;
  End;
  If PreviewDirty And Valid Then Begin
   If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);Preview:=Nil;
   If M<>Nil Then If Not RenderMesh(M,View,PW,PH,True,Preview) Then
    Message:='Apercu annule ou memoire insuffisante.';
   PreviewDirty:=False;
  End;
  HideMouseCursor;FillRect(X,Y,X+620,Y+440,LightGray);
  DrawBevel(X,Y,X+620,Y+440,True);
  FillRect(X+3,Y+3,X+617,Y+26,Blue);SetColor(White);
  S:='Extrusion 3D du calque - silhouette et volume';
  If PathMode Then S:='Extrusion 3D du trace - contour vectoriel';
  If SelectionMode Then S:='Extrusion 3D selection - zone et volume';
  OutTextXY(X+12,Y+10,S);
  Button(20,40,180,'1. Geometrie');S:='2. Contour';
  If PathMode Then S:='2. Trace';
  If SelectionMode Then S:='2. Zone';Button(210,40,180,S);
  Button(400,40,200,'3. Rendu');SetColor(Blue);
  Line(X+20+Tab*190,Y+65,X+195+Tab*190,Y+65);
  MW:=0;MH:=0;
  If (Stats.Width>0) And (Stats.Height>0) Then Begin
   If LongInt(Stats.Width)*196>LongInt(Stats.Height)*280 Then Begin
    MW:=280;MH:=Max(1,Round(Stats.Height*280.0/Stats.Width));
   End Else Begin MH:=196;
    MW:=Max(1,Round(Stats.Width*196.0/Stats.Height));End;
  End;
  For PY:=0 To 195 Do For PX:=0 To 279 Do Begin
   Color:=White;If ((PX Div 10+PY Div 10) And 1)=0 Then Color:=LightGray;
   OX:=PX-(280-PW) Div 2;OY:=PY-(196-PH) Div 2;
   If (Shown=0) And (Preview<>Nil) And (OX>=0) And (OY>=0) And
    (OX<PW) And (OY<PH) Then
    If Preview^[LongInt(OY)*PW+OX]<>255 Then
     Color:=Preview^[LongInt(OY)*PW+OX];
   If (Shown=3) And (OX>=0) And (OY>=0) And (OX<PW) And (OY<PH) Then
   Begin
    GX:=Min(ImgW-1,Trunc((OX+0.5)*ImgW/PW));
    GY:=Min(ImgH-1,Trunc((OY+0.5)*ImgH/PH));
    If E.CompositeSource Then Color:=Composite(GX,GY)
    Else Color:=GetLayerPixel(ActiveLayer,GX,GY);
    If Color=255 Then Begin Color:=White;
     If ((PX Div 10+PY Div 10) And 1)=0 Then Color:=LightGray;End;
   End;
   OX:=PX-(280-MW) Div 2;OY:=PY-(196-MH) Div 2;
   If Not PathMode And (Shown=1) And (OX>=0) And (OY>=0) And (OX<MW) And
    (OY<MH) Then Begin
    GX:=OX*Stats.Width Div MW;GY:=OY*Stats.Height Div MH;
    If Stats.Mask[GY*Stats.Width+GX]<>0 Then Color:=Blue;
   End;
   PutPixel(X+20+PX,Y+82+PY,Color);
  End;
  If PathMode And (Shown=1) Then Begin
   SetColor(Blue);
   For GX:=0 To LocalPath.Count-1 Do Begin
    GY:=(GX+1) Mod LocalPath.Count;
    If (GX<LocalPath.Count-1) Or LocalPath.Closed Then
     Line(X+20+(280-PW) Div 2+Round(LocalPath.Points[GX].X*PW),
      Y+82+(196-PH) Div 2+Round(LocalPath.Points[GX].Y*PH),
      X+20+(280-PW) Div 2+Round(LocalPath.Points[GY].X*PW),
      Y+82+(196-PH) Div 2+Round(LocalPath.Points[GY].Y*PH));
   End;
  End;
  If Shown=3 Then Begin
   SetColor(Yellow);
   Rectangle(X+20+(280-PW) Div 2+Round(Region.Bounds.L*1.0*PW/ImgW),
    Y+82+(196-PH) Div 2+Round(Region.Bounds.T*1.0*PH/ImgH),
    X+20+(280-PW) Div 2+Round((Region.Bounds.R+1.0)*PW/ImgW),
    Y+82+(196-PH) Div 2+Round((Region.Bounds.B+1.0)*PH/ImgH));
  End;
  SetColor(Black);Rectangle(X+19,Y+81,X+300,Y+278);
  If Shown=2 Then Begin
   FillRect(X+21,Y+83,X+299,Y+276,White);SetColor(Black);
   If SelectionMode Then Begin
    OutTextXY(X+28,Y+94,'Zone : '+IntToStr(Region.Bounds.L)+', '+
     IntToStr(Region.Bounds.T));
    OutTextXY(X+28,Y+116,'Dimensions : '+Texts[12]+' x '+Texts[13]);
   End Else If PathMode Then Begin
    OutTextXY(X+28,Y+94,'Contour vectoriel exact');
    OutTextXY(X+28,Y+116,'Points utiles : '+IntToStr(Stats.Cells));
   End Else Begin
    OutTextXY(X+28,Y+94,'Grille : '+IntToStr(Stats.Width)+' x '+
     IntToStr(Stats.Height));
    OutTextXY(X+28,Y+116,'Cellules : '+IntToStr(Stats.Cells));End;
   OutTextXY(X+28,Y+138,'Objets : '+IntToStr(Stats.Groups));
   OutTextXY(X+28,Y+160,'Sommets : '+IntToStr(Stats.Vertices));
   OutTextXY(X+28,Y+182,'Triangles : '+IntToStr(Stats.Triangles));
   OutTextXY(X+28,Y+204,'Donnees : '+Memory((Stats.Vertices+
    Stats.Triangles)*12));
   OutTextXY(X+28,Y+226,'Maillage alloue : '+Memory(
    SizeOf(TMeshVertices)+SizeOf(TMeshTriangles)+SizeOf(TMesh)));
   S:='Avant et arriere fermes';If Not E.Caps Then S:='Maillage ouvert';
   OutTextXY(X+28,Y+248,S);
  End;
  SetColor(Black);OutTextXY(X+20,Y+292,IntToStr(Stats.Triangles)+
   ' triangles / '+IntToStr(Stats.Groups)+' objets');
  Case Display Of 0:S:='Vue 3D';1:S:='Masque';2:S:='Informations';End;
  If PathMode And (Shown=1) Then S:='Trace 2D';
  If SelectionMode Then Case Display Of 1:S:='Source et zone';
   2:S:='Masque de controle';3:S:='Informations';End;
  Button(20,312,280,'Apercu : '+S+' >');
  Button(20,343,132,'Vue de face');Button(168,343,132,'Vue isometrique');
  If (Tab=0) And PathMode Then Begin
   Edit(0,82,'Profondeur %');Edit(2,115,'Segments 1-8');
   Edit(3,148,'Effilement %');Edit(4,181,'Torsion deg');
   Check(320,225,E.Caps,'Fermer avant / arriere');
   SetColor(Black);OutTextXY(X+320,Y+266,'Profondeur / taille du trace');
   OutTextXY(X+320,Y+290,'Torsion : 45 deg par segment');
   OutTextXY(X+320,Y+314,'Triangulation des concavites');
  End Else If Tab=0 Then Begin
   Edit(0,82,'Profondeur %');Edit(1,115,'Precision 8-64');
   Edit(2,148,'Segments 1-8');Edit(3,181,'Effilement %');
   Edit(4,214,'Torsion deg');
   Check(320,253,E.Caps,'Fermer avant / arriere');
   SetColor(Black);OutTextXY(X+320,Y+286,'Profondeur : 0.1 a 1000 %');
   OutTextXY(X+320,Y+309,'Effilement : -80 a +200 %');
   OutTextXY(X+320,Y+330,'45 deg max par segment');
   If SelectionMode Then Begin
    If Region.Shape=4 Then Begin
     Case E.Mode Of 0:S:='Opaques';1:S:='Clairs';2:S:='Sombres';
      3:S:='Premier plan';End;
     Button(320,282,280,'Contenu : '+S+' >');Edit(5,313,'Seuil 0-255');
    End Else Begin
     FillRect(X+318,Y+280,X+602,Y+344,LightGray);SetColor(Black);
     OutTextXY(X+320,Y+286,'Selection pleine : pixels ignores.');
     OutTextXY(X+320,Y+312,'Profondeur / taille de la zone');
    End;
   End;
  End Else If (Tab=1) And PathMode Then Begin
   Button(320,82,280,'Modifier le trace...');
   Button(320,115,280,'Rectangle');Button(320,148,280,'Ellipse');
   Button(320,181,280,'Etoile');Button(320,214,280,'Reprendre trace Plume');
   SetColor(Black);OutTextXY(X+320,Y+258,
    IntToStr(LocalPath.Count)+' points (128 maximum)');
   OutTextXY(X+320,Y+282,'Un seul contour ferme.');
   OutTextXY(X+320,Y+306,'Croisements et contacts refuses.');
   OutTextXY(X+320,Y+330,'Trace de travail garde en memoire.');
  End Else If (Tab=1) And SelectionMode Then Begin
   Case Region.Shape Of 0:S:='Selection pleine';1:S:='Ellipse';
    2:S:='Rectangle arrondi';3:S:='Cadre';4:S:='Contenu de la zone';End;
   Button(320,82,280,S+' >');Edit(10,115,'X en pixels');
   Edit(11,148,'Y en pixels');Edit(12,181,'Largeur px');
   Edit(13,214,'Hauteur px');Button(320,247,132,'Selection');
   Button(468,247,132,'Image entiere');
   If Region.Shape=2 Then Edit(14,280,'Rayon %')
   Else If Region.Shape=3 Then Edit(15,280,'Epaisseur %')
   Else If Region.Shape=1 Then Edit(1,280,'Facettes 8-64')
   Else If Region.Shape=4 Then Edit(6,280,'Couverture %')
   Else Begin SetColor(Black);
    OutTextXY(X+320,Y+288,'Rectangle vectoriel exact.');End;
   Check(320,318,E.CompositeSource,'Source : calques visibles');
  End Else If Tab=1 Then Begin
   Case E.Mode Of 0:S:='Pixels opaques';1:S:='Pixels clairs';
    2:S:='Pixels sombres';3:S:='Couleur premier plan';End;
   Button(320,82,280,S+' >');Edit(5,124,'Seuil 0-255');
   Edit(6,167,'Couverture %');
   Check(320,212,E.SelectionOnly,'Limiter a la selection');
   Check(320,237,E.CompositeSource,'Calques visibles');
   Check(320,262,E.Invert,'Inverser le masque');
   SetColor(Black);OutTextXY(X+320,Y+292,'9 echantillons par cellule.');
   OutTextXY(X+320,Y+312,'Fond opaque : masque rectangulaire.');
   OutTextXY(X+320,Y+332,'Pour decouper : transparence/seuil.');
  End Else Begin
   Edit(7,82,'Rotation X deg');Edit(8,115,'Rotation Y deg');
   Edit(9,148,'Rotation Z deg');
   Button(320,192,280,'Matiere VGA : '+IntToStr(View.Color)+' >');
   S:='Orthographique';If View.Perspective Then S:='Perspective';
   Button(320,225,280,S+' >');
   Case View.Mode Of 0:S:='Solide';1:S:='Fil de fer';2:S:='Solide + fil';End;
   Button(320,258,280,S+' >');
   Check(320,295,View.Cull,'Masquer faces arriere');
   Check(320,320,View.Dither,'Tramage des couleurs');
  End;
  S:='Remplacer calque actif';If E.NewLayer Then S:='Nouveau calque 3D';
  Button(320,349,280,S);
  Button(20,379,132,'Reinitialiser');Button(168,379,132,'Aide');
  Button(320,379,132,'Annuler');Button(468,379,132,'Creer');
  SetColor(Black);S:=
   'Contour approche par grille. Trous conserves. Matiere uniforme.';
  If PathMode Then S:=
   'Contour vectoriel simple, ferme. Sans trous. Matiere uniforme.';
  If SelectionMode Then S:=
   'Selection rectangulaire ou forme derivee. Matiere uniforme.';
  OutTextXY(X+20,Y+413,S);
  If Message<>'' Then Begin SetColor(Red);
   OutTextXY(X+20,Y+429,Copy(Message,1,73));End;
  ShowMouseCursor;Dirty:=False;
 End;
 Procedure Apply;
 Begin
  Parse;If Not Valid Then Exit;
  If E.NewLayer And (LayerCount>=MAX_LAYERS) Then Begin
   Message:='Huit calques maximum : choisir Remplacer calque actif.';
   Dirty:=True;Exit;
  End;
  If Rebuild Then Draw;
  If M=Nil Then Exit;
  Target:=ActiveLayer;If E.NewLayer Then Target:=-1;
  If ImportMeshLayer(M,View,Target) Then Begin
   If PathMode Then WorkingPath:=LocalPath;Done:=True;End
  Else Begin Message:='Operation annulee ou memoire insuffisante.';
   Dirty:=True;End;
 End;
Begin
 ResetToolTip;MenuActive:=False;LocalPath:=WorkingPath;
 DefaultExtrudeOptions(E);DefaultSelectionExtrude(Region);
 DefaultMeshOptions(View);View.Mode:=0;Sync;FillChar(Stats,SizeOf(Stats),0);
 M:=Nil;Preview:=Nil;Field:=0;Tab:=0;Display:=0;Message:='';
 If PathMode And (LocalPath.Count<3) Then Begin Tab:=1;Display:=1;End;
 If SelectionMode And Not SelectionActive Then
  Message:='Aucune selection : image entiere proposee, zone modifiable.';
 X:=(ScreenWidth-620) Div 2;Y:=(ScreenHeight-440) Div 2;
 If LongInt(ImgW)*196>LongInt(ImgH)*280 Then Begin
  PW:=280;PH:=Max(1,Round(ImgH*280.0/ImgW));
 End Else Begin PH:=196;PW:=Max(1,Round(ImgW*196.0/ImgH));End;
 Dirty:=True;Rebuild:=True;PreviewDirty:=True;Done:=False;
 Drag:=False;ReplaceText:=True;Valid:=True;
 GetMouseStateLocal(MX,MY,Previous);
 Repeat
  If Dirty Then Draw;GetMouseStateLocal(MX,MY,MB);
  If ((MB And 1)<>0) And ((Previous And 1)=0) Then Begin
   If Hit(20,40,600,63) Then Begin
    Tab:=Min(2,(MX-X-20) Div 190);
    Case Tab Of 0:Field:=0;1:Field:=5;2:Field:=7;End;
    If SelectionMode And (Tab=1) Then Field:=10;
    ReplaceText:=True;Dirty:=True;
   End Else If Hit(20,312,300,335) Then Begin
    If SelectionMode Then Display:=(Display+1) Mod 4
    Else Display:=(Display+1) Mod 3;Dirty:=True;
   End Else If Hit(20,343,152,366) Then Begin
    View.RX:=0;View.RY:=0;View.RZ:=0;Sync;Changed(False);
   End Else If Hit(168,343,300,366) Then Begin
    View.RX:=200;View.RY:=-300;View.RZ:=0;Sync;Changed(False);
   End Else If Hit(320,349,600,372) Then Begin
    E.NewLayer:=Not E.NewLayer;Dirty:=True;
   End Else If Hit(20,379,152,402) Then Begin
    DefaultExtrudeOptions(E);DefaultMeshOptions(View);View.Mode:=0;
    DefaultSelectionExtrude(Region);
    Sync;Changed(True);
   End Else If Hit(168,379,300,402) Then Begin
    ShowDialog('Extrusion du calque',
     'Transparence ou seuil pour le contour. Export OBJ/STL apres creation.');
    Dirty:=True;GetMouseStateLocal(MX,MY,Previous);
   End Else If Hit(320,379,452,402) Then Done:=True
   Else If Hit(468,379,600,402) Then Apply
   Else If Hit(20,82,300,278) And (Display=0) Then Begin
    Drag:=True;OldX:=MX;OldY:=MY;
   End Else If (Tab=0) And PathMode Then Begin
    If Hit(460,82,600,203) Then Begin
     Field:=Min(3,(MY-Y-82) Div 33);
     If Field>0 Then Inc(Field);ReplaceText:=True;Dirty:=True;
    End Else If Hit(320,225,600,237) Then Begin
     E.Caps:=Not E.Caps;Changed(True);
    End;
   End Else If (Tab=1) And PathMode Then Begin
    If Hit(320,82,600,105) Then Begin
     If EditVectorPath(LocalPath) Then Changed(True);
     Dirty:=True;GetMouseStateLocal(MX,MY,Previous);
    End Else If Hit(320,115,600,204) Then Begin
     Target:=Min(2,(MY-Y-115) Div 33);
     VectorPathPreset(LocalPath,Target);Changed(True);
    End Else If Hit(320,214,600,237) Then Begin
     LocalPath:=WorkingPath;Changed(True);
    End;
   End Else If (Tab=1) And SelectionMode Then Begin
    If Hit(320,82,600,105) Then Begin
     Region.Shape:=(Region.Shape+1) Mod 5;Changed(True);
    End Else If Hit(460,115,600,236) Then Begin
     Field:=10+Min(3,(MY-Y-115) Div 33);ReplaceText:=True;Dirty:=True;
    End Else If Hit(320,247,452,270) Then Begin
     If SelectionActive Then Begin
      DefaultSelectionExtrude(CapturedRegion);
      Region.Bounds:=CapturedRegion.Bounds;
      Sync;Changed(True);End
     Else Begin Message:='Aucune selection active.';Dirty:=True;End;
    End Else If Hit(468,247,600,270) Then Begin
     Region.Bounds.L:=0;Region.Bounds.T:=0;
     Region.Bounds.R:=ImgW-1;Region.Bounds.B:=ImgH-1;
     Sync;Changed(True);
    End Else If (Region.Shape<>0) And Hit(460,280,600,302) Then Begin
     Field:=6;If Region.Shape=1 Then Field:=1;If Region.Shape=2 Then Field:=14;
     If Region.Shape=3 Then Field:=15;ReplaceText:=True;Dirty:=True;
    End Else If Hit(320,318,600,330) Then Begin
     E.CompositeSource:=Not E.CompositeSource;Changed(True);
    End;
   End Else If Tab=0 Then Begin
    If SelectionMode And (Region.Shape=4) And Hit(320,282,600,305) Then
    Begin E.Mode:=(E.Mode+1) Mod 4;Changed(True);End
    Else If SelectionMode And (Region.Shape=4) And
     Hit(460,313,600,335) Then Begin
     Field:=5;ReplaceText:=True;Dirty:=True;
    End Else If Hit(460,82,600,236) Then Begin
     Field:=Min(4,(MY-Y-82) Div 33);ReplaceText:=True;Dirty:=True;
    End Else If Hit(320,253,600,265) Then Begin
     E.Caps:=Not E.Caps;Changed(True);
    End;
   End Else If Tab=1 Then Begin
    If Hit(320,82,600,105) Then Begin E.Mode:=(E.Mode+1) Mod 4;
     Sync;Changed(True);
    End Else If Hit(460,124,600,146) Then Begin
     Field:=5;ReplaceText:=True;Dirty:=True;
    End Else If Hit(460,167,600,189) Then Begin
     Field:=6;ReplaceText:=True;Dirty:=True;
    End Else If Hit(320,212,600,224) Then Begin
     E.SelectionOnly:=Not E.SelectionOnly;Changed(True);
    End Else If Hit(320,237,600,249) Then Begin
     E.CompositeSource:=Not E.CompositeSource;Changed(True);
    End Else If Hit(320,262,600,274) Then Begin
     E.Invert:=Not E.Invert;Changed(True);
    End;
   End Else Begin
    If Hit(460,82,600,170) Then Begin
     Field:=7+Min(2,(MY-Y-82) Div 33);ReplaceText:=True;Dirty:=True;
    End Else If Hit(320,192,600,215) Then Begin
     View.Color:=(View.Color+1) Mod 16;Changed(False);
    End Else If Hit(320,225,600,248) Then Begin
     View.Perspective:=Not View.Perspective;Changed(False);
    End Else If Hit(320,258,600,281) Then Begin
     View.Mode:=(View.Mode+1) Mod 3;Changed(False);
    End Else If Hit(320,295,600,307) Then Begin
     View.Cull:=Not View.Cull;Changed(False);
    End Else If Hit(320,320,600,332) Then Begin
     View.Dither:=Not View.Dither;Changed(False);
    End;
   End;
  End;
  If Drag And ((MB And 1)<>0) And
   ((MX<>OldX) Or (MY<>OldY)) Then Begin
   View.RY:=Max(-3600,Min(3600,View.RY+(MX-OldX)*5));
   View.RX:=Max(-3600,Min(3600,View.RX+(MY-OldY)*5));
   OldX:=MX;OldY:=MY;Sync;Changed(False);
  End;
  If (MB And 1)=0 Then Drag:=False;Previous:=MB;
  If KeyPressed Then Begin
   K:=ReadKey;
   If K=#0 Then Begin
    Key:=ReadKey;Val(Texts[Field],V,Code);
    If Code=0 Then Begin
     If Key=#72 Then V:=V+1 Else If Key=#80 Then V:=V-1;
     Texts[Field]:=Decimal(V);Parse;ReplaceText:=True;
    End;
   End Else Case K Of
    #27:Done:=True;#13:Apply;
    #9:Begin
     Case Tab Of 0:Begin Field:=(Field+1) Mod 5;
      If PathMode And (Field=1) Then Field:=2;End;1:Begin
       If SelectionMode Then Begin Field:=Field+1;
        If Field>13 Then Begin Field:=6;
         If Region.Shape=0 Then Field:=10;
         If Region.Shape=1 Then Field:=1;
         If Region.Shape=2 Then Field:=14;
         If Region.Shape=3 Then Field:=15;End
        Else If Field<10 Then Field:=10;
       End Else Field:=5+(Field+1) Mod 2;
      End;
      2:Field:=7+(Field-6) Mod 3;End;
     ReplaceText:=True;Dirty:=True;
    End;
    #1:ReplaceText:=True;
    #8:If Not (PathMode And (Tab=1)) Then Begin
     If ReplaceText Then Texts[Field]:=''
     Else Delete(Texts[Field],Length(Texts[Field]),1);
     ReplaceText:=False;Parse;
    End;
    Else If (K In ['0'..'9','-','+','.',',']) And
     Not (PathMode And (Tab=1)) Then Begin
     If ReplaceText Then Texts[Field]:='';
     If Length(Texts[Field])<8 Then Texts[Field]:=Texts[Field]+K;
     ReplaceText:=False;Parse;
    End;
   End;
  End;
  Delay(10);
 Until Done;
 If Preview<>Nil Then FreeMem(Preview,LongInt(PW)*PH);ReleaseMesh(M);
 GetMouseStateLocal(MouseX,MouseY,MouseButtons);
 OldMouseButtons:=MouseButtons;Drawing:=False;DrawFullUI;
End;

Procedure ExtrudeDialog;
Begin ExtrudeDialogFor(False,False);End;
Procedure ExtrudePathDialog;
Begin ExtrudeDialogFor(True,False);End;

Procedure ExtrudeSelectionDialog;
Begin ExtrudeDialogFor(False,True);End;

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
   0: ImageSizeDialog;
   1: Begin RotateLayer90(True); DrawFullUI; End;
   2: Begin RotateLayer90(False); DrawFullUI; End;
   3: Begin FlipH; DrawFullUI; End;
   4: Begin FlipV; DrawFullUI; End;
   5: RotationDialog;
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
   4: MotionBlurDialog;
   5: SharpenDialog;
  End;
  MENU_3D: Case IIdx Of
   0:MeshImportDialog(-1);
   1:MeshMergeDialog;
   2:MeshExportDialog;
   3:PanoramaDialog;
   4:SketchfabDialog;
   8:ExtrudeDialog;
   9:ExtrudePathDialog;
   10:ExtrudeSelectionDialog;
   33:If Layers[ActiveLayer].Mesh<>Nil Then MeshImportDialog(ActiveLayer)
    Else ShowDialog('3D','Le calque actif ne contient pas de geometrie 3D.');
   Else ShowDialog('3D','Cette autre commande 3D n''est pas implementee.');
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

Procedure ShowToolTip(Index:Integer);
Var S:String;W,H,X,Y,PreviousColor:Integer;
 PreviousFill:FillSettingsType;PreviousLine:LineSettingsType;
Begin
 If (Index<0) Or (Index>=MAX_TOOLS) Then Exit;
 S:=Tools[Index].Hint;If S='' Then Exit;
 W:=TextWidth(S)+14;H:=TextHeight(S)+12;
 If (W+4>ScreenWidth) Or (H+4>ScreenHeight) Then Exit;
 X:=2+(Index Mod 2)*26;
 Y:=MENUBAR_HEIGHT+OPTIONSBAR_H+4+(Index Div 2)*26-H-5;
 X:=Max(0,Min(X,ScreenWidth-W-4));
 Y:=Max(0,Min(Y,ScreenHeight-H-4));
 If ImageSize(X,Y,X+W+3,Y+H+3)>SizeOf(ToolTipPixels) Then Exit;
 HideMouseCursor;GetImage(X,Y,X+W+3,Y+H+3,ToolTipPixels);
 PreviousColor:=GetColor;GetFillSettings(PreviousFill);
 GetLineSettings(PreviousLine);
 SetWriteMode(CopyPut);SetLineStyle(SolidLn,0,NormWidth);
 SetFillStyle(SolidFill,DarkGray);Bar(X+3,Y+3,X+W+3,Y+H+3);
 SetFillStyle(SolidFill,Yellow);Bar(X,Y,X+W,Y+H);
 SetColor(Black);Rectangle(X,Y,X+W,Y+H);OutTextXY(X+7,Y+6,S);
 SetColor(PreviousColor);
 SetFillStyle(PreviousFill.Pattern,PreviousFill.Color);
 SetLineStyle(PreviousLine.LineStyle,PreviousLine.Pattern,
  PreviousLine.Thickness);
 ToolTipX:=X;ToolTipY:=Y;ToolTipVisible:=True;ShowMouseCursor;
End;
Procedure UpdateToolTip;
Var Index:Integer;Now,Elapsed:LongInt;
Begin
 Index:=-1;
 If Not MenuActive And Not Drawing And (MouseButtons=0) Then
  Index:=ToolHitTest(MouseX,MouseY);
 Now:=ToolTipClock;
 If Index<>ToolTipCandidate Then Begin
  HideToolTip;ToolTipCandidate:=Index;ToolTipStarted:=Now;
 End;
 If Index<0 Then Exit;
 Elapsed:=Now-ToolTipStarted;
 If Elapsed<0 Then Inc(Elapsed,8640000);
 If Not ToolTipVisible And (Elapsed>=50) Then ShowToolTip(Index);
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
Var IX,IY,N:Integer;
Begin
 If Not ScreenToImg(SX, SY, IX, IY) Then Exit;
 StartX := IX; StartY := IY;
 EndX := IX; EndY := IY;
 Drawing := True;
 Case CurrentTool Of
  TOOL_PEN:Begin
   Drawing:=False;
   If Not WorkingPath.Closed Then Begin
    N:=NearestWorkingPoint(IX,IY);
    If (N=0) And (WorkingPath.Count>=3) Then WorkingPath.Closed:=True
    Else If WorkingPath.Count<128 Then Begin
     N:=WorkingPath.Count;Inc(WorkingPath.Count);
     WorkingPath.Points[N].X:=IX/ImgW;
     WorkingPath.Points[N].Y:=IY/ImgH;
    End;
   End;
   RefreshCanvas;
  End;
  TOOL_PATHSEL:Begin
   WorkingPathSelected:=NearestWorkingPoint(IX,IY);
   Drawing:=WorkingPathSelected>=0;
  End;
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
  TOOL_PATHSEL:If (WorkingPathSelected>=0) And
   (WorkingPathSelected<WorkingPath.Count) Then Begin
   WorkingPath.Points[WorkingPathSelected].X:=IX/ImgW;
   WorkingPath.Points[WorkingPathSelected].Y:=IY/ImgH;DrawCanvasArea;
  End;
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
Var MIdx,TIdx,SwIdx,LIdx,IIdx,OldTool:Integer;
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
   OldTool:=CurrentTool;CurrentTool := TIdx;
   DrawToolbar;
   DrawOptionsBar;
   If (OldTool In [TOOL_PEN,TOOL_PATHSEL]) Or
    (CurrentTool In [TOOL_PEN,TOOL_PATHSEL]) Then RefreshCanvas;
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
 If (MouseX<>OldMouseX) Or (MouseY<>OldMouseY) Or
    (MouseButtons<>0) Then ResetToolTip;

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
Var Tmp:Byte;OldTool:Integer;
Begin
 OldTool:=CurrentTool;
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
 If (OldTool<>CurrentTool) And
  ((OldTool In [TOOL_PEN,TOOL_PATHSEL]) Or
   (CurrentTool In [TOOL_PEN,TOOL_PATHSEL])) Then RefreshCanvas;
End;

Procedure HandleKeyboardEvent;
Var Ch, Ch2: Char;
Begin
 If Not KeyPressed Then Exit;
 ResetToolTip;
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
  #8:If CurrentTool In [TOOL_PEN,TOOL_PATHSEL] Then Begin
   If WorkingPath.Count>0 Then Dec(WorkingPath.Count);
   WorkingPath.Closed:=False;RefreshCanvas;
  End;
  #13: Begin
   If Not MenuActive And (CurrentTool=TOOL_PEN) And
    (WorkingPath.Count>=3) Then Begin
    WorkingPath.Closed:=True;RefreshCanvas;
   End;
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
 ToolTipVisible:=False;ToolTipCandidate:=-1;ToolTipStarted:=0;
 InitSwatches;
 For I:=0 To MAX_LAYERS-1 Do Begin
  Layers[I].Used := False;
  Layers[I].Pixels := Nil;
 End;
 For I:=0 To MAX_UNDO_LEVELS-1 Do Begin
  UndoBuffers[I]:=Nil;RotationUndo[I]:=Nil;UndoSizes[I]:=0;
 End;
 UndoCount := 0;
 ImgW := 400; ImgH := 300;ImageDPI:=72;
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
 ClearUndoHistory;
 HideMouseCursor;
 CloseGraph;
End;

Procedure MainLoop;
Begin
 While Running Do Begin
  HandleMouseEvent;
  HandleKeyboardEvent;
  UpdateToolTip;
 End;
End;

Procedure HandleCmdLine;
Var FN, ErrMsg: String;
Begin
 If ParamCount < 1 Then Exit;
 FN := ParamStr(1);
 If LoadFileByExt(FN, ErrMsg) Then Begin
  FI_ResetMetadata;
  FI_LoadSidecar(FN);
  DrawFullUI;
 End Else If ErrMsg<>'' Then
  ShowDialog('Format', ErrMsg)
 Else
  ShowDialog('Erreur', 'Impossible de charger : '+FN);
End;

BEGIN
 Initialize;
 HandleCmdLine;
 MainLoop;
 Cleanup;
END.
