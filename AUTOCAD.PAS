{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application AutoCAD
}

{ TODO: Liste des 25 points pour un clone complet d'AutoCAD

  === INTERFACE UTILISATEUR ET MENUS ===
  1. [DONE] Implémenter le menu principal avec File, Edit, View, Insert, Format, Tools, Draw, Dimension, Modify, Window, Help
  2. [DONE] Créer le menu Draw avec toutes les options : Line, Ray, Construction Line, Polyline, Polygon, Rectangle, Arc, Circle, Spline, Ellipse, Point, Hatch, Region, Text, Surface, Solid
  3. [DONE] Créer le menu Modify avec : Erase, Copy, Mirror, Offset, Array, Move, Rotate, Scale, Stretch, Trim, Extend, Break, Chamfer, Fillet, Explode
  4. [DONE] Créer le menu Format avec : Layer, Color, Linetype, Text Style, Dimension Style, Point Style, Units, Drawing Limits
  5. [DONE] Créer les barres d'outils flottantes et ancrables pour un accès rapide aux commandes

  === SUPPORT DE LA SOURIS ===
  6. [DONE] Implémenter la gestion complète de la souris avec clic gauche, clic droit, molette et déplacement
  7. [DONE] Ajouter le zoom par molette de souris et le pan par clic milieu
  8. [DONE] Créer le curseur de précision (crosshair) avec affichage des coordonnées en temps réel
  9. [DONE] Implémenter le système de sélection d'objets par clic, fenêtre et fenêtre croisée
  10. Ajouter les poignées de manipulation (grips) pour éditer les objets sélectionnés

  === INTERPRÉTEUR AUTOLISP ===
  11. Créer un analyseur lexical (tokenizer) pour le langage AutoLISP
  12. Implémenter un parseur pour construire l'arbre syntaxique des expressions LISP
  13. Développer l'évaluateur d'expressions avec support des fonctions mathématiques (+, -, *, /, sin, cos, sqrt, etc.)
  14. Implémenter les fonctions de dessin AutoLISP : command, entmake, entmod, entget, entsel, ssget, ssadd
  15. Ajouter les fonctions de manipulation de chaînes, listes et variables : setq, defun, if, cond, while, foreach, mapcar

  === MODIFICATION DES OBJETS ET PROPRIÉTÉS ===
  16. Créer le panneau de propriétés pour modifier couleur, calque, type de ligne, épaisseur
  17. Implémenter la modification géométrique des objets (déplacer sommets, changer rayon, etc.)
  18. Ajouter le système de calques (layers) avec visibilité, verrouillage, couleur et type de ligne
  19. Créer les outils de cotation : linéaire, alignée, angulaire, radiale, diamètre, ordonnée
  20. Implémenter les blocs et références externes (XREFs) avec insertion et édition

  === FORMATS DE FICHIERS ===
  21. Implémenter la lecture et écriture du format DWG (Drawing) d'AutoCAD
  22. Ajouter le support du format DXF (Drawing Exchange Format) pour l'interopérabilité
  23. Créer l'importation et exportation du format Visio (VSD/VSDX)
  24. Implémenter l'exportation SVG (Scalable Vector Graphics) pour le web
  25. Ajouter l'importation SVG avec conversion des éléments en entités AutoCAD
}

Program AUTOCAD;

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}

Uses {$IFDEF FPC}
      Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      Crt,Graph,Dos
     {$ENDIF};

Const
 { Constantes de version }
 VERSION_MAJOR = 1;
 VERSION_MINOR = 0;
 PROGRAM_NAME = 'AUTOCAD - Clone d''AutoCAD';

 { Constantes de l'interface }
 MENUBAR_HEIGHT = 20;
 TOOLBAR_HEIGHT = 30;
 COMMANDLINE_HEIGHT = 40;
 STATUSBAR_HEIGHT = 20;

 { Constantes de menu - 11 menus comme AutoCAD }
 MENU_FILE = 0;
 MENU_EDIT = 1;
 MENU_VIEW = 2;
 MENU_INSERT = 3;
 MENU_FORMAT = 4;
 MENU_TOOLS = 5;
 MENU_DRAW = 6;
 MENU_DIMENSION = 7;
 MENU_MODIFY = 8;
 MENU_WINDOW = 9;
 MENU_HELP = 10;

 MAX_MENUS = 11;
 MAX_MENU_ITEMS = 20;

 { Constantes pour les barres d'outils - TODO 5 }
 MAX_TOOLBARS = 5;
 MAX_TOOLBAR_BUTTONS = 15;
 TOOLBAR_BUTTON_SIZE = 24;
 TOOLBAR_SPACING = 2;

 { Identifiants des barres d'outils }
 TOOLBAR_STANDARD = 0;
 TOOLBAR_DRAW = 1;
 TOOLBAR_MODIFY = 2;
 TOOLBAR_LAYERS = 3;
 TOOLBAR_PROPERTIES = 4;

 { Constantes pour la gestion de la souris - TODO 6 }
 MOUSE_BUTTON_LEFT = 1;
 MOUSE_BUTTON_RIGHT = 2;
 MOUSE_BUTTON_MIDDLE = 4;
 
 { Éléments du menu contextuel }
 MAX_CONTEXT_ITEMS = 10;
 CONTEXT_REPEAT = 0;
 CONTEXT_RECENT_INPUT = 1;
 CONTEXT_CUT = 2;
 CONTEXT_COPY = 3;
 CONTEXT_PASTE = 4;
 CONTEXT_ERASE = 5;
 CONTEXT_PAN = 6;
 CONTEXT_ZOOM = 7;
 CONTEXT_PROPERTIES = 8;
 CONTEXT_OPTIONS = 9;

 { Modes de souris }
 MOUSE_MODE_NORMAL = 0;
 MOUSE_MODE_PAN = 1;
 MOUSE_MODE_ZOOM = 2;
 MOUSE_MODE_SELECT = 3;
 MOUSE_MODE_DRAW = 4;

 { Constantes pour le curseur crosshair - TODO 8 }
 CROSSHAIR_SIZE_SMALL = 20;      { Petite taille }
 CROSSHAIR_SIZE_MEDIUM = 50;     { Taille moyenne }
 CROSSHAIR_SIZE_LARGE = 100;     { Grande taille }
 CROSSHAIR_SIZE_FULLSCREEN = 0;  { Plein écran (0 = infini) }
 
 { Style de coordonnées affichées }
 COORD_DISPLAY_NONE = 0;         { Pas d'affichage }
 COORD_DISPLAY_TOOLTIP = 1;      { Tooltip près du curseur }
 COORD_DISPLAY_STATUSBAR = 2;    { Barre d'état seulement }
 COORD_DISPLAY_BOTH = 3;         { Les deux }

 { Constantes pour la sélection d'objets - TODO 9 }
 MAX_OBJECTS = 1000;             { Nombre maximum d'objets dans le dessin }
 MAX_SELECTED = 100;             { Nombre maximum d'objets sélectionnés }
 
 { Modes de sélection }
 SELECT_MODE_NONE = 0;           { Pas de sélection en cours }
 SELECT_MODE_POINT = 1;          { Sélection par point (clic) }
 SELECT_MODE_WINDOW = 2;         { Fenêtre de sélection (gauche à droite) }
 SELECT_MODE_CROSSING = 3;       { Fenêtre croisée (droite à gauche) }
 
 { Types d'objets géométriques }
 OBJ_NONE = 0;
 OBJ_LINE = 1;
 OBJ_CIRCLE = 2;
 OBJ_ARC = 3;
 OBJ_RECTANGLE = 4;
 OBJ_POLYLINE = 5;
 OBJ_POINT = 6;
 OBJ_TEXT = 7;
 OBJ_ELLIPSE = 8;
 
 { Tolérance de sélection (en pixels) }
 PICK_TOLERANCE = 5;

Type
 { Structure pour les éléments de menu }
 TMenuItem = Record
  Caption: String[30];
  Shortcut: String[15];
  Enabled: Boolean;
  Checked: Boolean;
  Separator: Boolean;
 End;

 TMenu = Record
  Title: String[15];
  Items: Array[0..MAX_MENU_ITEMS-1] of TMenuItem;
  ItemCount: Byte;
  X, Width: Integer;
 End;

 { Structure pour les boutons de barre d'outils - TODO 5 }
 TToolbarButton = Record
  Caption: String[20];      { Nom du bouton pour tooltip }
  Symbol: Char;             { Caractère symbole à afficher }
  Command: String[20];      { Commande associée }
  Enabled: Boolean;
  Separator: Boolean;       { Séparateur visuel }
 End;

 { Structure pour les barres d'outils - TODO 5 }
 TToolbar = Record
  Title: String[20];        { Nom de la barre d'outils }
  Buttons: Array[0..MAX_TOOLBAR_BUTTONS-1] of TToolbarButton;
  ButtonCount: Byte;
  X, Y: Integer;            { Position (pour barres flottantes) }
  Docked: Boolean;          { True si ancrée, False si flottante }
  DockPosition: Byte;       { 0=top, 1=left, 2=right, 3=bottom }
  Visible: Boolean;
 End;

 { Structure pour le menu contextuel - TODO 6 }
 TContextMenuItem = Record
  Caption: String[25];
  Enabled: Boolean;
  Separator: Boolean;
 End;

 { Structure pour un objet géométrique - TODO 9 }
 TDrawObject = Record
  ObjType: Byte;              { Type d'objet (OBJ_LINE, OBJ_CIRCLE, etc.) }
  X1, Y1: Real;               { Point 1 / Centre }
  X2, Y2: Real;               { Point 2 / (non utilisé pour cercle) }
  Radius: Real;               { Rayon (pour cercle, arc) }
  StartAngle, EndAngle: Real; { Angles (pour arc, ellipse) }
  Color: Integer;             { Couleur de l'objet }
  LineType: Byte;             { Type de ligne (continu, pointillé, etc.) }
  LayerIndex: Byte;           { Index du calque }
  Selected: Boolean;          { True si l'objet est sélectionné }
  Visible: Boolean;           { True si l'objet est visible }
 End;

 { Structure pour le jeu de sélection - TODO 9 }
 TSelectionSet = Record
  Objects: Array[0..MAX_SELECTED-1] of Integer;  { Indices des objets sélectionnés }
  Count: Integer;                                { Nombre d'objets sélectionnés }
 End;

Var
 { Variables globales de l'application }
 ScreenWidth, ScreenHeight: Integer;
 Running: Boolean;

 { Variables de la souris }
 MouseX, MouseY: Integer;
 MouseButtons: Integer;

 { Variables avancées de la souris - TODO 6 }
 MouseMode: Integer;            { Mode actuel de la souris }
 MouseDragging: Boolean;        { True si en train de faire un drag }
 DragStartX, DragStartY: Integer; { Point de départ du drag }
 LastMouseX, LastMouseY: Integer; { Dernière position connue }
 MouseWheelDelta: Integer;      { Valeur de la molette }
 ContextMenuActive: Boolean;    { Menu contextuel visible }
 ContextMenuX, ContextMenuY: Integer; { Position du menu contextuel }
 ContextMenuItems: Array[0..MAX_CONTEXT_ITEMS-1] of TContextMenuItem;
 ContextMenuItemCount: Integer;
 ActiveContextItem: Integer;    { Élément survolé dans le menu contextuel }

 { Variables pour le pan et zoom }
 ViewOffsetX, ViewOffsetY: Real; { Décalage de la vue (pan) }
 ZoomLevel: Real;               { Niveau de zoom actuel }

 { Variables pour le curseur crosshair - TODO 8 }
 CrosshairSize: Integer;        { Taille du crosshair (0 = plein écran) }
 CrosshairColor: Integer;       { Couleur du crosshair }
 CoordDisplayMode: Integer;     { Mode d'affichage des coordonnées }
 ShowPickBox: Boolean;          { Afficher la boîte de sélection au centre }
 PickBoxSize: Integer;          { Taille de la boîte de sélection }

 { Variables pour les menus }
 Menus: Array[0..MAX_MENUS-1] of TMenu;
 MenuActive: Boolean;
 ActiveMenu: Integer;
 ActiveMenuItem: Integer;

 { Variables pour les barres d'outils - TODO 5 }
 Toolbars: Array[0..MAX_TOOLBARS-1] of TToolbar;
 HoveredToolbar: Integer;
 HoveredButton: Integer;

 { Variables pour le système de sélection - TODO 9 }
 DrawObjects: Array[0..MAX_OBJECTS-1] of TDrawObject;  { Tous les objets du dessin }
 ObjectCount: Integer;                                 { Nombre total d'objets }
 SelectionSet: TSelectionSet;                          { Jeu de sélection actuel }
 SelectMode: Integer;                                  { Mode de sélection en cours }
 SelectStartX, SelectStartY: Integer;                  { Point de départ de la fenêtre de sélection }
 SelectEndX, SelectEndY: Integer;                      { Point de fin de la fenêtre de sélection }
 SelectionActive: Boolean;                             { True si en train de faire une sélection par fenêtre }

{ Forward declarations - TODO 6 }
Procedure DrawContextMenu; Forward;
Procedure HandleContextMenuHover(X, Y: Integer); Forward;
Procedure HandleMouseDrag(X, Y: Integer); Forward;
Function GetContextMenuItemAt(X, Y: Integer): Integer; Forward;
Procedure ExecuteContextAction(Action: Integer); Forward;
Procedure HandleRightClick(X, Y: Integer); Forward;
Procedure HandleMiddleClick(X, Y: Integer); Forward;

{ Forward declarations - TODO 7 }
Procedure HandleMouseWheel(Delta: Integer); Forward;
Function ScreenToWorldX(SX: Integer): Real; Forward;
Function ScreenToWorldY(SY: Integer): Real; Forward;

{ Forward declarations - TODO 8 }
Procedure DrawCrosshairCursor(X, Y: Integer); Forward;
Procedure DrawCoordinateTooltip(X, Y: Integer); Forward;
Procedure InitCrosshairSettings; Forward;

{ Forward declarations - TODO 9 - Système de sélection }
Procedure InitSelectionSystem; Forward;
Procedure ClearSelection; Forward;
Procedure AddToSelection(ObjIndex: Integer); Forward;
Procedure RemoveFromSelection(ObjIndex: Integer); Forward;
Function IsSelected(ObjIndex: Integer): Boolean; Forward;
Function SelectObjectAtPoint(X, Y: Integer): Integer; Forward;
Procedure SelectObjectsInWindow(X1, Y1, X2, Y2: Integer; Crossing: Boolean); Forward;
Procedure DrawSelectionRectangle(X1, Y1, X2, Y2: Integer; IsCrossing: Boolean); Forward;
Procedure StartWindowSelection(X, Y: Integer); Forward;
Procedure UpdateWindowSelection(X, Y: Integer); Forward;
Procedure FinishWindowSelection; Forward;
Function PointNearLine(PX, PY, X1, Y1, X2, Y2: Real; Tolerance: Real): Boolean; Forward;
Function PointNearCircle(PX, PY, CX, CY, Radius: Real; Tolerance: Real): Boolean; Forward;
Function ObjectIntersectsRect(ObjIndex: Integer; RX1, RY1, RX2, RY2: Real): Boolean; Forward;
Function ObjectInsideRect(ObjIndex: Integer; RX1, RY1, RX2, RY2: Real): Boolean; Forward;
Procedure DrawSelectedObjects; Forward;

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
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

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  LX, LY, LB: LongInt;
 Begin
  PtcMouse.GetMouseState(LX, LY, LB);
  X := LX;
  Y := LY;
  Button := LB;
 End;

 { Obtenir le delta de la molette de souris - TODO 7 }
 Function GetMouseWheelDelta: Integer;
 Begin
  { PtcMouse: la molette est gérée via les événements de souris }
  { Pour simplifier, on utilise les touches clavier + et - comme alternative }
  GetMouseWheelDelta := 0;
 End;
{$ENDIF}

{ Procédures pour obtenir le delta de la molette via clavier - TODO 7 }
Procedure ProcessMouseWheelFromKeyboard(Key: Char);
Begin
 Case Key of
  '+', '=': HandleMouseWheel(1);  { Zoom avant }
  '-', '_': HandleMouseWheel(-1); { Zoom arrière }
 End;
End;

{ ============================================================================ }
{ Procédure d'initialisation des menus - TODO 1                                }
{ Implémente le menu principal avec File, Edit, View, Insert, Format, Tools,  }
{ Draw, Dimension, Modify, Window, Help                                        }
{ ============================================================================ }

Procedure InitMenus;
Begin
 { Menu File (Fichier) }
 Menus[MENU_FILE].Title := 'File';
 Menus[MENU_FILE].X := 5;
 Menus[MENU_FILE].Width := 160;
 Menus[MENU_FILE].ItemCount := 14;
 Menus[MENU_FILE].Items[0].Caption := 'New...';
 Menus[MENU_FILE].Items[0].Shortcut := 'Ctrl+N';
 Menus[MENU_FILE].Items[0].Enabled := True;
 Menus[MENU_FILE].Items[1].Caption := 'Open...';
 Menus[MENU_FILE].Items[1].Shortcut := 'Ctrl+O';
 Menus[MENU_FILE].Items[1].Enabled := True;
 Menus[MENU_FILE].Items[2].Caption := 'Save';
 Menus[MENU_FILE].Items[2].Shortcut := 'Ctrl+S';
 Menus[MENU_FILE].Items[2].Enabled := True;
 Menus[MENU_FILE].Items[3].Caption := 'Save As...';
 Menus[MENU_FILE].Items[3].Shortcut := 'Ctrl+Shift+S';
 Menus[MENU_FILE].Items[3].Enabled := True;
 Menus[MENU_FILE].Items[4].Separator := True;
 Menus[MENU_FILE].Items[5].Caption := 'Import...';
 Menus[MENU_FILE].Items[5].Shortcut := '';
 Menus[MENU_FILE].Items[5].Enabled := True;
 Menus[MENU_FILE].Items[6].Caption := 'Export...';
 Menus[MENU_FILE].Items[6].Shortcut := '';
 Menus[MENU_FILE].Items[6].Enabled := True;
 Menus[MENU_FILE].Items[7].Separator := True;
 Menus[MENU_FILE].Items[8].Caption := 'Print...';
 Menus[MENU_FILE].Items[8].Shortcut := 'Ctrl+P';
 Menus[MENU_FILE].Items[8].Enabled := True;
 Menus[MENU_FILE].Items[9].Caption := 'Print Preview';
 Menus[MENU_FILE].Items[9].Shortcut := '';
 Menus[MENU_FILE].Items[9].Enabled := True;
 Menus[MENU_FILE].Items[10].Separator := True;
 Menus[MENU_FILE].Items[11].Caption := 'Drawing Properties';
 Menus[MENU_FILE].Items[11].Shortcut := '';
 Menus[MENU_FILE].Items[11].Enabled := True;
 Menus[MENU_FILE].Items[12].Separator := True;
 Menus[MENU_FILE].Items[13].Caption := 'Exit';
 Menus[MENU_FILE].Items[13].Shortcut := 'Alt+F4';
 Menus[MENU_FILE].Items[13].Enabled := True;

 { Menu Edit }
 Menus[MENU_EDIT].Title := 'Edit';
 Menus[MENU_EDIT].X := 35;
 Menus[MENU_EDIT].Width := 150;
 Menus[MENU_EDIT].ItemCount := 12;
 Menus[MENU_EDIT].Items[0].Caption := 'Undo';
 Menus[MENU_EDIT].Items[0].Shortcut := 'Ctrl+Z';
 Menus[MENU_EDIT].Items[0].Enabled := True;
 Menus[MENU_EDIT].Items[1].Caption := 'Redo';
 Menus[MENU_EDIT].Items[1].Shortcut := 'Ctrl+Y';
 Menus[MENU_EDIT].Items[1].Enabled := True;
 Menus[MENU_EDIT].Items[2].Separator := True;
 Menus[MENU_EDIT].Items[3].Caption := 'Cut';
 Menus[MENU_EDIT].Items[3].Shortcut := 'Ctrl+X';
 Menus[MENU_EDIT].Items[3].Enabled := True;
 Menus[MENU_EDIT].Items[4].Caption := 'Copy';
 Menus[MENU_EDIT].Items[4].Shortcut := 'Ctrl+C';
 Menus[MENU_EDIT].Items[4].Enabled := True;
 Menus[MENU_EDIT].Items[5].Caption := 'Copy with Base Point';
 Menus[MENU_EDIT].Items[5].Shortcut := 'Ctrl+Shift+C';
 Menus[MENU_EDIT].Items[5].Enabled := True;
 Menus[MENU_EDIT].Items[6].Caption := 'Paste';
 Menus[MENU_EDIT].Items[6].Shortcut := 'Ctrl+V';
 Menus[MENU_EDIT].Items[6].Enabled := True;
 Menus[MENU_EDIT].Items[7].Caption := 'Paste as Block';
 Menus[MENU_EDIT].Items[7].Shortcut := 'Ctrl+Shift+V';
 Menus[MENU_EDIT].Items[7].Enabled := True;
 Menus[MENU_EDIT].Items[8].Separator := True;
 Menus[MENU_EDIT].Items[9].Caption := 'Clear';
 Menus[MENU_EDIT].Items[9].Shortcut := 'Del';
 Menus[MENU_EDIT].Items[9].Enabled := True;
 Menus[MENU_EDIT].Items[10].Separator := True;
 Menus[MENU_EDIT].Items[11].Caption := 'Select All';
 Menus[MENU_EDIT].Items[11].Shortcut := 'Ctrl+A';
 Menus[MENU_EDIT].Items[11].Enabled := True;

 { Menu View }
 Menus[MENU_VIEW].Title := 'View';
 Menus[MENU_VIEW].X := 65;
 Menus[MENU_VIEW].Width := 150;
 Menus[MENU_VIEW].ItemCount := 14;
 Menus[MENU_VIEW].Items[0].Caption := 'Redraw';
 Menus[MENU_VIEW].Items[0].Shortcut := 'R';
 Menus[MENU_VIEW].Items[0].Enabled := True;
 Menus[MENU_VIEW].Items[1].Caption := 'Regen';
 Menus[MENU_VIEW].Items[1].Shortcut := '';
 Menus[MENU_VIEW].Items[1].Enabled := True;
 Menus[MENU_VIEW].Items[2].Separator := True;
 Menus[MENU_VIEW].Items[3].Caption := 'Zoom In';
 Menus[MENU_VIEW].Items[3].Shortcut := 'Z+';
 Menus[MENU_VIEW].Items[3].Enabled := True;
 Menus[MENU_VIEW].Items[4].Caption := 'Zoom Out';
 Menus[MENU_VIEW].Items[4].Shortcut := 'Z-';
 Menus[MENU_VIEW].Items[4].Enabled := True;
 Menus[MENU_VIEW].Items[5].Caption := 'Zoom Window';
 Menus[MENU_VIEW].Items[5].Shortcut := 'Z W';
 Menus[MENU_VIEW].Items[5].Enabled := True;
 Menus[MENU_VIEW].Items[6].Caption := 'Zoom Extents';
 Menus[MENU_VIEW].Items[6].Shortcut := 'Z E';
 Menus[MENU_VIEW].Items[6].Enabled := True;
 Menus[MENU_VIEW].Items[7].Caption := 'Zoom All';
 Menus[MENU_VIEW].Items[7].Shortcut := 'Z A';
 Menus[MENU_VIEW].Items[7].Enabled := True;
 Menus[MENU_VIEW].Items[8].Separator := True;
 Menus[MENU_VIEW].Items[9].Caption := 'Pan';
 Menus[MENU_VIEW].Items[9].Shortcut := 'P';
 Menus[MENU_VIEW].Items[9].Enabled := True;
 Menus[MENU_VIEW].Items[10].Separator := True;
 Menus[MENU_VIEW].Items[11].Caption := 'Named Views...';
 Menus[MENU_VIEW].Items[11].Shortcut := 'V';
 Menus[MENU_VIEW].Items[11].Enabled := True;
 Menus[MENU_VIEW].Items[12].Caption := '3D Views';
 Menus[MENU_VIEW].Items[12].Shortcut := '';
 Menus[MENU_VIEW].Items[12].Enabled := True;
 Menus[MENU_VIEW].Items[13].Caption := 'Viewports';
 Menus[MENU_VIEW].Items[13].Shortcut := '';
 Menus[MENU_VIEW].Items[13].Enabled := True;

 { Menu Insert }
 Menus[MENU_INSERT].Title := 'Insert';
 Menus[MENU_INSERT].X := 100;
 Menus[MENU_INSERT].Width := 150;
 Menus[MENU_INSERT].ItemCount := 10;
 Menus[MENU_INSERT].Items[0].Caption := 'Block...';
 Menus[MENU_INSERT].Items[0].Shortcut := 'I';
 Menus[MENU_INSERT].Items[0].Enabled := True;
 Menus[MENU_INSERT].Items[1].Caption := 'DWG Reference...';
 Menus[MENU_INSERT].Items[1].Shortcut := '';
 Menus[MENU_INSERT].Items[1].Enabled := True;
 Menus[MENU_INSERT].Items[2].Caption := 'Image Reference...';
 Menus[MENU_INSERT].Items[2].Shortcut := '';
 Menus[MENU_INSERT].Items[2].Enabled := True;
 Menus[MENU_INSERT].Items[3].Separator := True;
 Menus[MENU_INSERT].Items[4].Caption := 'Layout';
 Menus[MENU_INSERT].Items[4].Shortcut := '';
 Menus[MENU_INSERT].Items[4].Enabled := True;
 Menus[MENU_INSERT].Items[5].Separator := True;
 Menus[MENU_INSERT].Items[6].Caption := '3D Studio...';
 Menus[MENU_INSERT].Items[6].Shortcut := '';
 Menus[MENU_INSERT].Items[6].Enabled := True;
 Menus[MENU_INSERT].Items[7].Caption := 'ACIS File...';
 Menus[MENU_INSERT].Items[7].Shortcut := '';
 Menus[MENU_INSERT].Items[7].Enabled := True;
 Menus[MENU_INSERT].Items[8].Separator := True;
 Menus[MENU_INSERT].Items[9].Caption := 'OLE Object...';
 Menus[MENU_INSERT].Items[9].Shortcut := '';
 Menus[MENU_INSERT].Items[9].Enabled := True;

 { Menu Format }
 Menus[MENU_FORMAT].Title := 'Format';
 Menus[MENU_FORMAT].X := 145;
 Menus[MENU_FORMAT].Width := 160;
 Menus[MENU_FORMAT].ItemCount := 12;
 Menus[MENU_FORMAT].Items[0].Caption := 'Layer...';
 Menus[MENU_FORMAT].Items[0].Shortcut := 'LA';
 Menus[MENU_FORMAT].Items[0].Enabled := True;
 Menus[MENU_FORMAT].Items[1].Caption := 'Color...';
 Menus[MENU_FORMAT].Items[1].Shortcut := 'COL';
 Menus[MENU_FORMAT].Items[1].Enabled := True;
 Menus[MENU_FORMAT].Items[2].Caption := 'Linetype...';
 Menus[MENU_FORMAT].Items[2].Shortcut := 'LT';
 Menus[MENU_FORMAT].Items[2].Enabled := True;
 Menus[MENU_FORMAT].Items[3].Caption := 'Lineweight...';
 Menus[MENU_FORMAT].Items[3].Shortcut := 'LW';
 Menus[MENU_FORMAT].Items[3].Enabled := True;
 Menus[MENU_FORMAT].Items[4].Separator := True;
 Menus[MENU_FORMAT].Items[5].Caption := 'Text Style...';
 Menus[MENU_FORMAT].Items[5].Shortcut := 'ST';
 Menus[MENU_FORMAT].Items[5].Enabled := True;
 Menus[MENU_FORMAT].Items[6].Caption := 'Dimension Style...';
 Menus[MENU_FORMAT].Items[6].Shortcut := 'D';
 Menus[MENU_FORMAT].Items[6].Enabled := True;
 Menus[MENU_FORMAT].Items[7].Caption := 'Point Style...';
 Menus[MENU_FORMAT].Items[7].Shortcut := '';
 Menus[MENU_FORMAT].Items[7].Enabled := True;
 Menus[MENU_FORMAT].Items[8].Separator := True;
 Menus[MENU_FORMAT].Items[9].Caption := 'Units...';
 Menus[MENU_FORMAT].Items[9].Shortcut := 'UN';
 Menus[MENU_FORMAT].Items[9].Enabled := True;
 Menus[MENU_FORMAT].Items[10].Caption := 'Drawing Limits';
 Menus[MENU_FORMAT].Items[10].Shortcut := '';
 Menus[MENU_FORMAT].Items[10].Enabled := True;
 Menus[MENU_FORMAT].Items[11].Caption := 'Rename...';
 Menus[MENU_FORMAT].Items[11].Shortcut := 'REN';
 Menus[MENU_FORMAT].Items[11].Enabled := True;

 { Menu Tools }
 Menus[MENU_TOOLS].Title := 'Tools';
 Menus[MENU_TOOLS].X := 195;
 Menus[MENU_TOOLS].Width := 170;
 Menus[MENU_TOOLS].ItemCount := 14;
 Menus[MENU_TOOLS].Items[0].Caption := 'Spelling';
 Menus[MENU_TOOLS].Items[0].Shortcut := 'SP';
 Menus[MENU_TOOLS].Items[0].Enabled := True;
 Menus[MENU_TOOLS].Items[1].Caption := 'Quick Select...';
 Menus[MENU_TOOLS].Items[1].Shortcut := '';
 Menus[MENU_TOOLS].Items[1].Enabled := True;
 Menus[MENU_TOOLS].Items[2].Separator := True;
 Menus[MENU_TOOLS].Items[3].Caption := 'Draw Order';
 Menus[MENU_TOOLS].Items[3].Shortcut := '';
 Menus[MENU_TOOLS].Items[3].Enabled := True;
 Menus[MENU_TOOLS].Items[4].Caption := 'Inquiry';
 Menus[MENU_TOOLS].Items[4].Shortcut := '';
 Menus[MENU_TOOLS].Items[4].Enabled := True;
 Menus[MENU_TOOLS].Items[5].Separator := True;
 Menus[MENU_TOOLS].Items[6].Caption := 'Load Application...';
 Menus[MENU_TOOLS].Items[6].Shortcut := 'AP';
 Menus[MENU_TOOLS].Items[6].Enabled := True;
 Menus[MENU_TOOLS].Items[7].Caption := 'Run Script...';
 Menus[MENU_TOOLS].Items[7].Shortcut := 'SCR';
 Menus[MENU_TOOLS].Items[7].Enabled := True;
 Menus[MENU_TOOLS].Items[8].Separator := True;
 Menus[MENU_TOOLS].Items[9].Caption := 'AutoLISP';
 Menus[MENU_TOOLS].Items[9].Shortcut := '';
 Menus[MENU_TOOLS].Items[9].Enabled := True;
 Menus[MENU_TOOLS].Items[10].Separator := True;
 Menus[MENU_TOOLS].Items[11].Caption := 'Drafting Settings...';
 Menus[MENU_TOOLS].Items[11].Shortcut := 'DS';
 Menus[MENU_TOOLS].Items[11].Enabled := True;
 Menus[MENU_TOOLS].Items[12].Caption := 'Customize';
 Menus[MENU_TOOLS].Items[12].Shortcut := '';
 Menus[MENU_TOOLS].Items[12].Enabled := True;
 Menus[MENU_TOOLS].Items[13].Caption := 'Options...';
 Menus[MENU_TOOLS].Items[13].Shortcut := 'OP';
 Menus[MENU_TOOLS].Items[13].Enabled := True;

 { Menu Draw - TODO 2                                                         }
 { Contient: Line, Ray, Construction Line, Polyline, Polygon, Rectangle,     }
 { Arc, Circle, Spline, Ellipse, Point, Hatch, Region, Text, Surface, Solid  }
 Menus[MENU_DRAW].Title := 'Draw';
 Menus[MENU_DRAW].X := 235;
 Menus[MENU_DRAW].Width := 160;
 Menus[MENU_DRAW].ItemCount := 20;
 Menus[MENU_DRAW].Items[0].Caption := 'Line';
 Menus[MENU_DRAW].Items[0].Shortcut := 'L';
 Menus[MENU_DRAW].Items[0].Enabled := True;
 Menus[MENU_DRAW].Items[1].Caption := 'Ray';
 Menus[MENU_DRAW].Items[1].Shortcut := 'RAY';
 Menus[MENU_DRAW].Items[1].Enabled := True;
 Menus[MENU_DRAW].Items[2].Caption := 'Construction Line';
 Menus[MENU_DRAW].Items[2].Shortcut := 'XL';
 Menus[MENU_DRAW].Items[2].Enabled := True;
 Menus[MENU_DRAW].Items[3].Separator := True;
 Menus[MENU_DRAW].Items[4].Caption := 'Polyline';
 Menus[MENU_DRAW].Items[4].Shortcut := 'PL';
 Menus[MENU_DRAW].Items[4].Enabled := True;
 Menus[MENU_DRAW].Items[5].Caption := 'Polygon';
 Menus[MENU_DRAW].Items[5].Shortcut := 'POL';
 Menus[MENU_DRAW].Items[5].Enabled := True;
 Menus[MENU_DRAW].Items[6].Caption := 'Rectangle';
 Menus[MENU_DRAW].Items[6].Shortcut := 'REC';
 Menus[MENU_DRAW].Items[6].Enabled := True;
 Menus[MENU_DRAW].Items[7].Separator := True;
 Menus[MENU_DRAW].Items[8].Caption := 'Arc';
 Menus[MENU_DRAW].Items[8].Shortcut := 'A';
 Menus[MENU_DRAW].Items[8].Enabled := True;
 Menus[MENU_DRAW].Items[9].Caption := 'Circle';
 Menus[MENU_DRAW].Items[9].Shortcut := 'C';
 Menus[MENU_DRAW].Items[9].Enabled := True;
 Menus[MENU_DRAW].Items[10].Caption := 'Spline';
 Menus[MENU_DRAW].Items[10].Shortcut := 'SPL';
 Menus[MENU_DRAW].Items[10].Enabled := True;
 Menus[MENU_DRAW].Items[11].Caption := 'Ellipse';
 Menus[MENU_DRAW].Items[11].Shortcut := 'EL';
 Menus[MENU_DRAW].Items[11].Enabled := True;
 Menus[MENU_DRAW].Items[12].Separator := True;
 Menus[MENU_DRAW].Items[13].Caption := 'Point';
 Menus[MENU_DRAW].Items[13].Shortcut := 'PO';
 Menus[MENU_DRAW].Items[13].Enabled := True;
 Menus[MENU_DRAW].Items[14].Caption := 'Hatch...';
 Menus[MENU_DRAW].Items[14].Shortcut := 'H';
 Menus[MENU_DRAW].Items[14].Enabled := True;
 Menus[MENU_DRAW].Items[15].Caption := 'Region';
 Menus[MENU_DRAW].Items[15].Shortcut := 'REG';
 Menus[MENU_DRAW].Items[15].Enabled := True;
 Menus[MENU_DRAW].Items[16].Separator := True;
 Menus[MENU_DRAW].Items[17].Caption := 'Text';
 Menus[MENU_DRAW].Items[17].Shortcut := 'T';
 Menus[MENU_DRAW].Items[17].Enabled := True;
 Menus[MENU_DRAW].Items[18].Caption := 'Surface';
 Menus[MENU_DRAW].Items[18].Shortcut := 'SUR';
 Menus[MENU_DRAW].Items[18].Enabled := True;
 Menus[MENU_DRAW].Items[19].Caption := 'Solid';
 Menus[MENU_DRAW].Items[19].Shortcut := 'SO';
 Menus[MENU_DRAW].Items[19].Enabled := True;

 { Menu Dimension }
 Menus[MENU_DIMENSION].Title := 'Dimension';
 Menus[MENU_DIMENSION].X := 280;
 Menus[MENU_DIMENSION].Width := 160;
 Menus[MENU_DIMENSION].ItemCount := 14;
 Menus[MENU_DIMENSION].Items[0].Caption := 'Quick Dimension';
 Menus[MENU_DIMENSION].Items[0].Shortcut := 'QDIM';
 Menus[MENU_DIMENSION].Items[0].Enabled := True;
 Menus[MENU_DIMENSION].Items[1].Separator := True;
 Menus[MENU_DIMENSION].Items[2].Caption := 'Linear';
 Menus[MENU_DIMENSION].Items[2].Shortcut := 'DLI';
 Menus[MENU_DIMENSION].Items[2].Enabled := True;
 Menus[MENU_DIMENSION].Items[3].Caption := 'Aligned';
 Menus[MENU_DIMENSION].Items[3].Shortcut := 'DAL';
 Menus[MENU_DIMENSION].Items[3].Enabled := True;
 Menus[MENU_DIMENSION].Items[4].Caption := 'Arc Length';
 Menus[MENU_DIMENSION].Items[4].Shortcut := '';
 Menus[MENU_DIMENSION].Items[4].Enabled := True;
 Menus[MENU_DIMENSION].Items[5].Caption := 'Ordinate';
 Menus[MENU_DIMENSION].Items[5].Shortcut := 'DOR';
 Menus[MENU_DIMENSION].Items[5].Enabled := True;
 Menus[MENU_DIMENSION].Items[6].Separator := True;
 Menus[MENU_DIMENSION].Items[7].Caption := 'Radius';
 Menus[MENU_DIMENSION].Items[7].Shortcut := 'DRA';
 Menus[MENU_DIMENSION].Items[7].Enabled := True;
 Menus[MENU_DIMENSION].Items[8].Caption := 'Diameter';
 Menus[MENU_DIMENSION].Items[8].Shortcut := 'DDI';
 Menus[MENU_DIMENSION].Items[8].Enabled := True;
 Menus[MENU_DIMENSION].Items[9].Caption := 'Angular';
 Menus[MENU_DIMENSION].Items[9].Shortcut := 'DAN';
 Menus[MENU_DIMENSION].Items[9].Enabled := True;
 Menus[MENU_DIMENSION].Items[10].Separator := True;
 Menus[MENU_DIMENSION].Items[11].Caption := 'Baseline';
 Menus[MENU_DIMENSION].Items[11].Shortcut := 'DBA';
 Menus[MENU_DIMENSION].Items[11].Enabled := True;
 Menus[MENU_DIMENSION].Items[12].Caption := 'Continue';
 Menus[MENU_DIMENSION].Items[12].Shortcut := 'DCO';
 Menus[MENU_DIMENSION].Items[12].Enabled := True;
 Menus[MENU_DIMENSION].Items[13].Caption := 'Leader';
 Menus[MENU_DIMENSION].Items[13].Shortcut := 'LE';
 Menus[MENU_DIMENSION].Items[13].Enabled := True;

 { Menu Modify - TODO 3                                                       }
 { Contient: Erase, Copy, Mirror, Offset, Array, Move, Rotate, Scale,         }
 { Stretch, Trim, Extend, Break, Chamfer, Fillet, Explode                      }
 Menus[MENU_MODIFY].Title := 'Modify';
 Menus[MENU_MODIFY].X := 350;
 Menus[MENU_MODIFY].Width := 150;
 Menus[MENU_MODIFY].ItemCount := 19;
 Menus[MENU_MODIFY].Items[0].Caption := 'Properties';
 Menus[MENU_MODIFY].Items[0].Shortcut := 'PR';
 Menus[MENU_MODIFY].Items[0].Enabled := True;
 Menus[MENU_MODIFY].Items[1].Caption := 'Match Properties';
 Menus[MENU_MODIFY].Items[1].Shortcut := 'MA';
 Menus[MENU_MODIFY].Items[1].Enabled := True;
 Menus[MENU_MODIFY].Items[2].Separator := True;
 Menus[MENU_MODIFY].Items[3].Caption := 'Erase';
 Menus[MENU_MODIFY].Items[3].Shortcut := 'E';
 Menus[MENU_MODIFY].Items[3].Enabled := True;
 Menus[MENU_MODIFY].Items[4].Caption := 'Copy';
 Menus[MENU_MODIFY].Items[4].Shortcut := 'CO';
 Menus[MENU_MODIFY].Items[4].Enabled := True;
 Menus[MENU_MODIFY].Items[5].Caption := 'Mirror';
 Menus[MENU_MODIFY].Items[5].Shortcut := 'MI';
 Menus[MENU_MODIFY].Items[5].Enabled := True;
 Menus[MENU_MODIFY].Items[6].Caption := 'Offset';
 Menus[MENU_MODIFY].Items[6].Shortcut := 'O';
 Menus[MENU_MODIFY].Items[6].Enabled := True;
 Menus[MENU_MODIFY].Items[7].Caption := 'Array';
 Menus[MENU_MODIFY].Items[7].Shortcut := 'AR';
 Menus[MENU_MODIFY].Items[7].Enabled := True;
 Menus[MENU_MODIFY].Items[8].Caption := 'Move';
 Menus[MENU_MODIFY].Items[8].Shortcut := 'M';
 Menus[MENU_MODIFY].Items[8].Enabled := True;
 Menus[MENU_MODIFY].Items[9].Caption := 'Rotate';
 Menus[MENU_MODIFY].Items[9].Shortcut := 'RO';
 Menus[MENU_MODIFY].Items[9].Enabled := True;
 Menus[MENU_MODIFY].Items[10].Caption := 'Scale';
 Menus[MENU_MODIFY].Items[10].Shortcut := 'SC';
 Menus[MENU_MODIFY].Items[10].Enabled := True;
 Menus[MENU_MODIFY].Items[11].Caption := 'Stretch';
 Menus[MENU_MODIFY].Items[11].Shortcut := 'S';
 Menus[MENU_MODIFY].Items[11].Enabled := True;
 Menus[MENU_MODIFY].Items[12].Separator := True;
 Menus[MENU_MODIFY].Items[13].Caption := 'Trim';
 Menus[MENU_MODIFY].Items[13].Shortcut := 'TR';
 Menus[MENU_MODIFY].Items[13].Enabled := True;
 Menus[MENU_MODIFY].Items[14].Caption := 'Extend';
 Menus[MENU_MODIFY].Items[14].Shortcut := 'EX';
 Menus[MENU_MODIFY].Items[14].Enabled := True;
 Menus[MENU_MODIFY].Items[15].Caption := 'Break';
 Menus[MENU_MODIFY].Items[15].Shortcut := 'BR';
 Menus[MENU_MODIFY].Items[15].Enabled := True;
 Menus[MENU_MODIFY].Items[16].Caption := 'Chamfer';
 Menus[MENU_MODIFY].Items[16].Shortcut := 'CHA';
 Menus[MENU_MODIFY].Items[16].Enabled := True;
 Menus[MENU_MODIFY].Items[17].Caption := 'Fillet';
 Menus[MENU_MODIFY].Items[17].Shortcut := 'F';
 Menus[MENU_MODIFY].Items[17].Enabled := True;
 Menus[MENU_MODIFY].Items[18].Caption := 'Explode';
 Menus[MENU_MODIFY].Items[18].Shortcut := 'X';
 Menus[MENU_MODIFY].Items[18].Enabled := True;

 { Menu Window }
 Menus[MENU_WINDOW].Title := 'Window';
 Menus[MENU_WINDOW].X := 410;
 Menus[MENU_WINDOW].Width := 140;
 Menus[MENU_WINDOW].ItemCount := 6;
 Menus[MENU_WINDOW].Items[0].Caption := 'Close';
 Menus[MENU_WINDOW].Items[0].Shortcut := '';
 Menus[MENU_WINDOW].Items[0].Enabled := True;
 Menus[MENU_WINDOW].Items[1].Caption := 'Close All';
 Menus[MENU_WINDOW].Items[1].Shortcut := '';
 Menus[MENU_WINDOW].Items[1].Enabled := True;
 Menus[MENU_WINDOW].Items[2].Separator := True;
 Menus[MENU_WINDOW].Items[3].Caption := 'Cascade';
 Menus[MENU_WINDOW].Items[3].Shortcut := '';
 Menus[MENU_WINDOW].Items[3].Enabled := True;
 Menus[MENU_WINDOW].Items[4].Caption := 'Tile Horizontally';
 Menus[MENU_WINDOW].Items[4].Shortcut := '';
 Menus[MENU_WINDOW].Items[4].Enabled := True;
 Menus[MENU_WINDOW].Items[5].Caption := 'Tile Vertically';
 Menus[MENU_WINDOW].Items[5].Shortcut := '';
 Menus[MENU_WINDOW].Items[5].Enabled := True;

 { Menu Help }
 Menus[MENU_HELP].Title := 'Help';
 Menus[MENU_HELP].X := 470;
 Menus[MENU_HELP].Width := 130;
 Menus[MENU_HELP].ItemCount := 6;
 Menus[MENU_HELP].Items[0].Caption := 'Help';
 Menus[MENU_HELP].Items[0].Shortcut := 'F1';
 Menus[MENU_HELP].Items[0].Enabled := True;
 Menus[MENU_HELP].Items[1].Caption := 'InfoCenter';
 Menus[MENU_HELP].Items[1].Shortcut := '';
 Menus[MENU_HELP].Items[1].Enabled := True;
 Menus[MENU_HELP].Items[2].Separator := True;
 Menus[MENU_HELP].Items[3].Caption := 'New Features';
 Menus[MENU_HELP].Items[3].Shortcut := '';
 Menus[MENU_HELP].Items[3].Enabled := True;
 Menus[MENU_HELP].Items[4].Separator := True;
 Menus[MENU_HELP].Items[5].Caption := 'About AutoCAD';
 Menus[MENU_HELP].Items[5].Shortcut := '';
 Menus[MENU_HELP].Items[5].Enabled := True;

 { Initialisation des variables de menu }
 MenuActive := False;
 ActiveMenu := -1;
 ActiveMenuItem := -1;
End;

{ ============================================================================ }
{ Procédure d'initialisation des barres d'outils - TODO 5                      }
{ Créer les barres d'outils flottantes et ancrables pour un accès rapide       }
{ aux commandes                                                                 }
{ ============================================================================ }

Procedure InitToolbars;
Var
 I: Integer;
Begin
 { Initialiser toutes les barres d'outils à vide }
 For I := 0 to MAX_TOOLBARS - 1 do Begin
  Toolbars[I].ButtonCount := 0;
  Toolbars[I].Visible := False;
  Toolbars[I].Docked := True;
  Toolbars[I].DockPosition := 0;
 End;

 { ========== BARRE D'OUTILS STANDARD ========== }
 Toolbars[TOOLBAR_STANDARD].Title := 'Standard';
 Toolbars[TOOLBAR_STANDARD].Docked := True;
 Toolbars[TOOLBAR_STANDARD].DockPosition := 0;
 Toolbars[TOOLBAR_STANDARD].X := 5;
 Toolbars[TOOLBAR_STANDARD].Y := MENUBAR_HEIGHT + 2;
 Toolbars[TOOLBAR_STANDARD].Visible := True;
 Toolbars[TOOLBAR_STANDARD].ButtonCount := 10;
 
 { New }
 Toolbars[TOOLBAR_STANDARD].Buttons[0].Caption := 'New';
 Toolbars[TOOLBAR_STANDARD].Buttons[0].Symbol := 'N';
 Toolbars[TOOLBAR_STANDARD].Buttons[0].Command := 'NEW';
 Toolbars[TOOLBAR_STANDARD].Buttons[0].Enabled := True;
 
 { Open }
 Toolbars[TOOLBAR_STANDARD].Buttons[1].Caption := 'Open';
 Toolbars[TOOLBAR_STANDARD].Buttons[1].Symbol := 'O';
 Toolbars[TOOLBAR_STANDARD].Buttons[1].Command := 'OPEN';
 Toolbars[TOOLBAR_STANDARD].Buttons[1].Enabled := True;
 
 { Save }
 Toolbars[TOOLBAR_STANDARD].Buttons[2].Caption := 'Save';
 Toolbars[TOOLBAR_STANDARD].Buttons[2].Symbol := 'S';
 Toolbars[TOOLBAR_STANDARD].Buttons[2].Command := 'SAVE';
 Toolbars[TOOLBAR_STANDARD].Buttons[2].Enabled := True;
 
 { Séparateur }
 Toolbars[TOOLBAR_STANDARD].Buttons[3].Separator := True;
 
 { Print }
 Toolbars[TOOLBAR_STANDARD].Buttons[4].Caption := 'Print';
 Toolbars[TOOLBAR_STANDARD].Buttons[4].Symbol := 'P';
 Toolbars[TOOLBAR_STANDARD].Buttons[4].Command := 'PRINT';
 Toolbars[TOOLBAR_STANDARD].Buttons[4].Enabled := True;
 
 { Séparateur }
 Toolbars[TOOLBAR_STANDARD].Buttons[5].Separator := True;
 
 { Undo }
 Toolbars[TOOLBAR_STANDARD].Buttons[6].Caption := 'Undo';
 Toolbars[TOOLBAR_STANDARD].Buttons[6].Symbol := 'U';
 Toolbars[TOOLBAR_STANDARD].Buttons[6].Command := 'UNDO';
 Toolbars[TOOLBAR_STANDARD].Buttons[6].Enabled := True;
 
 { Redo }
 Toolbars[TOOLBAR_STANDARD].Buttons[7].Caption := 'Redo';
 Toolbars[TOOLBAR_STANDARD].Buttons[7].Symbol := 'R';
 Toolbars[TOOLBAR_STANDARD].Buttons[7].Command := 'REDO';
 Toolbars[TOOLBAR_STANDARD].Buttons[7].Enabled := True;
 
 { Séparateur }
 Toolbars[TOOLBAR_STANDARD].Buttons[8].Separator := True;
 
 { Zoom }
 Toolbars[TOOLBAR_STANDARD].Buttons[9].Caption := 'Zoom';
 Toolbars[TOOLBAR_STANDARD].Buttons[9].Symbol := 'Z';
 Toolbars[TOOLBAR_STANDARD].Buttons[9].Command := 'ZOOM';
 Toolbars[TOOLBAR_STANDARD].Buttons[9].Enabled := True;

 { ========== BARRE D'OUTILS DRAW ========== }
 Toolbars[TOOLBAR_DRAW].Title := 'Draw';
 Toolbars[TOOLBAR_DRAW].Docked := True;
 Toolbars[TOOLBAR_DRAW].DockPosition := 0;
 Toolbars[TOOLBAR_DRAW].X := 280;
 Toolbars[TOOLBAR_DRAW].Y := MENUBAR_HEIGHT + 2;
 Toolbars[TOOLBAR_DRAW].Visible := True;
 Toolbars[TOOLBAR_DRAW].ButtonCount := 12;
 
 { Line }
 Toolbars[TOOLBAR_DRAW].Buttons[0].Caption := 'Line';
 Toolbars[TOOLBAR_DRAW].Buttons[0].Symbol := '/';
 Toolbars[TOOLBAR_DRAW].Buttons[0].Command := 'LINE';
 Toolbars[TOOLBAR_DRAW].Buttons[0].Enabled := True;
 
 { Polyline }
 Toolbars[TOOLBAR_DRAW].Buttons[1].Caption := 'Polyline';
 Toolbars[TOOLBAR_DRAW].Buttons[1].Symbol := 'W';
 Toolbars[TOOLBAR_DRAW].Buttons[1].Command := 'PLINE';
 Toolbars[TOOLBAR_DRAW].Buttons[1].Enabled := True;
 
 { Rectangle }
 Toolbars[TOOLBAR_DRAW].Buttons[2].Caption := 'Rectangle';
 Toolbars[TOOLBAR_DRAW].Buttons[2].Symbol := '#';
 Toolbars[TOOLBAR_DRAW].Buttons[2].Command := 'RECTANG';
 Toolbars[TOOLBAR_DRAW].Buttons[2].Enabled := True;
 
 { Polygon }
 Toolbars[TOOLBAR_DRAW].Buttons[3].Caption := 'Polygon';
 Toolbars[TOOLBAR_DRAW].Buttons[3].Symbol := '%';
 Toolbars[TOOLBAR_DRAW].Buttons[3].Command := 'POLYGON';
 Toolbars[TOOLBAR_DRAW].Buttons[3].Enabled := True;
 
 { Séparateur }
 Toolbars[TOOLBAR_DRAW].Buttons[4].Separator := True;
 
 { Circle }
 Toolbars[TOOLBAR_DRAW].Buttons[5].Caption := 'Circle';
 Toolbars[TOOLBAR_DRAW].Buttons[5].Symbol := 'o';
 Toolbars[TOOLBAR_DRAW].Buttons[5].Command := 'CIRCLE';
 Toolbars[TOOLBAR_DRAW].Buttons[5].Enabled := True;
 
 { Arc }
 Toolbars[TOOLBAR_DRAW].Buttons[6].Caption := 'Arc';
 Toolbars[TOOLBAR_DRAW].Buttons[6].Symbol := '(';
 Toolbars[TOOLBAR_DRAW].Buttons[6].Command := 'ARC';
 Toolbars[TOOLBAR_DRAW].Buttons[6].Enabled := True;
 
 { Ellipse }
 Toolbars[TOOLBAR_DRAW].Buttons[7].Caption := 'Ellipse';
 Toolbars[TOOLBAR_DRAW].Buttons[7].Symbol := '0';
 Toolbars[TOOLBAR_DRAW].Buttons[7].Command := 'ELLIPSE';
 Toolbars[TOOLBAR_DRAW].Buttons[7].Enabled := True;
 
 { Séparateur }
 Toolbars[TOOLBAR_DRAW].Buttons[8].Separator := True;
 
 { Text }
 Toolbars[TOOLBAR_DRAW].Buttons[9].Caption := 'Text';
 Toolbars[TOOLBAR_DRAW].Buttons[9].Symbol := 'A';
 Toolbars[TOOLBAR_DRAW].Buttons[9].Command := 'TEXT';
 Toolbars[TOOLBAR_DRAW].Buttons[9].Enabled := True;
 
 { Hatch }
 Toolbars[TOOLBAR_DRAW].Buttons[10].Caption := 'Hatch';
 Toolbars[TOOLBAR_DRAW].Buttons[10].Symbol := 'H';
 Toolbars[TOOLBAR_DRAW].Buttons[10].Command := 'HATCH';
 Toolbars[TOOLBAR_DRAW].Buttons[10].Enabled := True;
 
 { Point }
 Toolbars[TOOLBAR_DRAW].Buttons[11].Caption := 'Point';
 Toolbars[TOOLBAR_DRAW].Buttons[11].Symbol := '.';
 Toolbars[TOOLBAR_DRAW].Buttons[11].Command := 'POINT';
 Toolbars[TOOLBAR_DRAW].Buttons[11].Enabled := True;

 { ========== BARRE D'OUTILS MODIFY ========== }
 Toolbars[TOOLBAR_MODIFY].Title := 'Modify';
 Toolbars[TOOLBAR_MODIFY].Docked := True;
 Toolbars[TOOLBAR_MODIFY].DockPosition := 0;
 Toolbars[TOOLBAR_MODIFY].X := 600;
 Toolbars[TOOLBAR_MODIFY].Y := MENUBAR_HEIGHT + 2;
 Toolbars[TOOLBAR_MODIFY].Visible := True;
 Toolbars[TOOLBAR_MODIFY].ButtonCount := 12;
 
 { Erase }
 Toolbars[TOOLBAR_MODIFY].Buttons[0].Caption := 'Erase';
 Toolbars[TOOLBAR_MODIFY].Buttons[0].Symbol := 'X';
 Toolbars[TOOLBAR_MODIFY].Buttons[0].Command := 'ERASE';
 Toolbars[TOOLBAR_MODIFY].Buttons[0].Enabled := True;
 
 { Copy }
 Toolbars[TOOLBAR_MODIFY].Buttons[1].Caption := 'Copy';
 Toolbars[TOOLBAR_MODIFY].Buttons[1].Symbol := 'C';
 Toolbars[TOOLBAR_MODIFY].Buttons[1].Command := 'COPY';
 Toolbars[TOOLBAR_MODIFY].Buttons[1].Enabled := True;
 
 { Move }
 Toolbars[TOOLBAR_MODIFY].Buttons[2].Caption := 'Move';
 Toolbars[TOOLBAR_MODIFY].Buttons[2].Symbol := 'M';
 Toolbars[TOOLBAR_MODIFY].Buttons[2].Command := 'MOVE';
 Toolbars[TOOLBAR_MODIFY].Buttons[2].Enabled := True;
 
 { Mirror }
 Toolbars[TOOLBAR_MODIFY].Buttons[3].Caption := 'Mirror';
 Toolbars[TOOLBAR_MODIFY].Buttons[3].Symbol := '|';
 Toolbars[TOOLBAR_MODIFY].Buttons[3].Command := 'MIRROR';
 Toolbars[TOOLBAR_MODIFY].Buttons[3].Enabled := True;
 
 { Séparateur }
 Toolbars[TOOLBAR_MODIFY].Buttons[4].Separator := True;
 
 { Rotate }
 Toolbars[TOOLBAR_MODIFY].Buttons[5].Caption := 'Rotate';
 Toolbars[TOOLBAR_MODIFY].Buttons[5].Symbol := '@';
 Toolbars[TOOLBAR_MODIFY].Buttons[5].Command := 'ROTATE';
 Toolbars[TOOLBAR_MODIFY].Buttons[5].Enabled := True;
 
 { Scale }
 Toolbars[TOOLBAR_MODIFY].Buttons[6].Caption := 'Scale';
 Toolbars[TOOLBAR_MODIFY].Buttons[6].Symbol := '*';
 Toolbars[TOOLBAR_MODIFY].Buttons[6].Command := 'SCALE';
 Toolbars[TOOLBAR_MODIFY].Buttons[6].Enabled := True;
 
 { Offset }
 Toolbars[TOOLBAR_MODIFY].Buttons[7].Caption := 'Offset';
 Toolbars[TOOLBAR_MODIFY].Buttons[7].Symbol := '=';
 Toolbars[TOOLBAR_MODIFY].Buttons[7].Command := 'OFFSET';
 Toolbars[TOOLBAR_MODIFY].Buttons[7].Enabled := True;
 
 { Séparateur }
 Toolbars[TOOLBAR_MODIFY].Buttons[8].Separator := True;
 
 { Trim }
 Toolbars[TOOLBAR_MODIFY].Buttons[9].Caption := 'Trim';
 Toolbars[TOOLBAR_MODIFY].Buttons[9].Symbol := 'T';
 Toolbars[TOOLBAR_MODIFY].Buttons[9].Command := 'TRIM';
 Toolbars[TOOLBAR_MODIFY].Buttons[9].Enabled := True;
 
 { Extend }
 Toolbars[TOOLBAR_MODIFY].Buttons[10].Caption := 'Extend';
 Toolbars[TOOLBAR_MODIFY].Buttons[10].Symbol := 'E';
 Toolbars[TOOLBAR_MODIFY].Buttons[10].Command := 'EXTEND';
 Toolbars[TOOLBAR_MODIFY].Buttons[10].Enabled := True;
 
 { Fillet }
 Toolbars[TOOLBAR_MODIFY].Buttons[11].Caption := 'Fillet';
 Toolbars[TOOLBAR_MODIFY].Buttons[11].Symbol := 'F';
 Toolbars[TOOLBAR_MODIFY].Buttons[11].Command := 'FILLET';
 Toolbars[TOOLBAR_MODIFY].Buttons[11].Enabled := True;

 { ========== BARRE D'OUTILS LAYERS (flottante) ========== }
 Toolbars[TOOLBAR_LAYERS].Title := 'Layers';
 Toolbars[TOOLBAR_LAYERS].Docked := False;  { Barre flottante }
 Toolbars[TOOLBAR_LAYERS].X := 50;
 Toolbars[TOOLBAR_LAYERS].Y := 100;
 Toolbars[TOOLBAR_LAYERS].Visible := False;  { Cachée par défaut }
 Toolbars[TOOLBAR_LAYERS].ButtonCount := 4;
 
 Toolbars[TOOLBAR_LAYERS].Buttons[0].Caption := 'Layer Properties';
 Toolbars[TOOLBAR_LAYERS].Buttons[0].Symbol := 'L';
 Toolbars[TOOLBAR_LAYERS].Buttons[0].Command := 'LAYER';
 Toolbars[TOOLBAR_LAYERS].Buttons[0].Enabled := True;
 
 Toolbars[TOOLBAR_LAYERS].Buttons[1].Caption := 'Make Layer Current';
 Toolbars[TOOLBAR_LAYERS].Buttons[1].Symbol := '+';
 Toolbars[TOOLBAR_LAYERS].Buttons[1].Command := 'LAYMCUR';
 Toolbars[TOOLBAR_LAYERS].Buttons[1].Enabled := True;
 
 Toolbars[TOOLBAR_LAYERS].Buttons[2].Caption := 'Layer Off';
 Toolbars[TOOLBAR_LAYERS].Buttons[2].Symbol := '-';
 Toolbars[TOOLBAR_LAYERS].Buttons[2].Command := 'LAYOFF';
 Toolbars[TOOLBAR_LAYERS].Buttons[2].Enabled := True;
 
 Toolbars[TOOLBAR_LAYERS].Buttons[3].Caption := 'Layer Freeze';
 Toolbars[TOOLBAR_LAYERS].Buttons[3].Symbol := '~';
 Toolbars[TOOLBAR_LAYERS].Buttons[3].Command := 'LAYFRZ';
 Toolbars[TOOLBAR_LAYERS].Buttons[3].Enabled := True;

 { ========== BARRE D'OUTILS PROPERTIES (flottante) ========== }
 Toolbars[TOOLBAR_PROPERTIES].Title := 'Properties';
 Toolbars[TOOLBAR_PROPERTIES].Docked := False;  { Barre flottante }
 Toolbars[TOOLBAR_PROPERTIES].X := 50;
 Toolbars[TOOLBAR_PROPERTIES].Y := 200;
 Toolbars[TOOLBAR_PROPERTIES].Visible := False;  { Cachée par défaut }
 Toolbars[TOOLBAR_PROPERTIES].ButtonCount := 3;
 
 Toolbars[TOOLBAR_PROPERTIES].Buttons[0].Caption := 'Properties';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[0].Symbol := 'I';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[0].Command := 'PROPERTIES';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[0].Enabled := True;
 
 Toolbars[TOOLBAR_PROPERTIES].Buttons[1].Caption := 'Match Properties';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[1].Symbol := '&';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[1].Command := 'MATCHPROP';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[1].Enabled := True;
 
 Toolbars[TOOLBAR_PROPERTIES].Buttons[2].Caption := 'List';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[2].Symbol := '?';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[2].Command := 'LIST';
 Toolbars[TOOLBAR_PROPERTIES].Buttons[2].Enabled := True;

 { Initialiser les variables de survol }
 HoveredToolbar := -1;
 HoveredButton := -1;
End;

{ Dessiner la barre de menu }
Procedure DrawMenuBar;
Var
 I: Integer;
 X: Integer;
Begin
 { Fond de la barre de menu - Style AutoCAD gris foncé }
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, 0, ScreenWidth - 1, MENUBAR_HEIGHT - 1);
 SetColor(Black);
 Line(0, MENUBAR_HEIGHT - 1, ScreenWidth - 1, MENUBAR_HEIGHT - 1);

 { Dessiner les titres des menus }
 X := 5;
 For I := 0 to MAX_MENUS - 1 do Begin
  Menus[I].X := X;
  If (MenuActive) and (ActiveMenu = I) Then Begin
   { Menu sélectionné - surbrillance }
   SetFillStyle(SolidFill, Blue);
   Bar(X - 2, 2, X + TextWidth(Menus[I].Title) + 4, MENUBAR_HEIGHT - 3);
   SetColor(White);
  End Else Begin
   SetColor(White);
  End;
  OutTextXY(X, 5, Menus[I].Title);
  X := X + TextWidth(Menus[I].Title) + 15;
 End;
End;

{ Dessiner un menu déroulant }
Procedure DrawDropdownMenu(MenuIndex: Integer);
Var
 I: Integer;
 X, Y: Integer;
 ItemHeight: Integer;
 MenuHeight: Integer;
Begin
 If (MenuIndex < 0) or (MenuIndex >= MAX_MENUS) Then Exit;

 ItemHeight := 18;
 MenuHeight := Menus[MenuIndex].ItemCount * ItemHeight + 4;

 X := Menus[MenuIndex].X;
 Y := MENUBAR_HEIGHT;

 { Fond du menu déroulant }
 SetFillStyle(SolidFill, LightGray);
 Bar(X - 2, Y, X + Menus[MenuIndex].Width, Y + MenuHeight);

 { Bordure du menu }
 SetColor(White);
 Line(X - 2, Y, X + Menus[MenuIndex].Width, Y);
 Line(X - 2, Y, X - 2, Y + MenuHeight);
 SetColor(DarkGray);
 Line(X + Menus[MenuIndex].Width, Y, X + Menus[MenuIndex].Width, Y + MenuHeight);
 Line(X - 2, Y + MenuHeight, X + Menus[MenuIndex].Width, Y + MenuHeight);

 { Dessiner les éléments du menu }
 For I := 0 to Menus[MenuIndex].ItemCount - 1 do Begin
  If Menus[MenuIndex].Items[I].Separator Then Begin
   { Ligne de séparation }
   SetColor(DarkGray);
   Line(X, Y + I * ItemHeight + ItemHeight div 2 + 2,
        X + Menus[MenuIndex].Width - 5, Y + I * ItemHeight + ItemHeight div 2 + 2);
  End Else Begin
   { Élément de menu }
   If ActiveMenuItem = I Then Begin
    { Élément sélectionné }
    SetFillStyle(SolidFill, Blue);
    Bar(X, Y + I * ItemHeight + 2, X + Menus[MenuIndex].Width - 2, Y + (I + 1) * ItemHeight + 2);
    SetColor(White);
   End Else Begin
    If Menus[MenuIndex].Items[I].Enabled Then
     SetColor(Black)
    Else
     SetColor(DarkGray);
   End;

   OutTextXY(X + 5, Y + I * ItemHeight + 5, Menus[MenuIndex].Items[I].Caption);

   { Afficher le raccourci clavier }
   If Length(Menus[MenuIndex].Items[I].Shortcut) > 0 Then Begin
    If ActiveMenuItem = I Then
     SetColor(White)
    Else
     SetColor(DarkGray);
    OutTextXY(X + Menus[MenuIndex].Width - TextWidth(Menus[MenuIndex].Items[I].Shortcut) - 10,
              Y + I * ItemHeight + 5, Menus[MenuIndex].Items[I].Shortcut);
   End;
  End;
 End;
End;

{ ============================================================================ }
{ Procédures de dessin des barres d'outils - TODO 5                            }
{ ============================================================================ }

{ Dessiner un bouton de barre d'outils }
Procedure DrawToolbarButton(X, Y: Integer; Var Button: TToolbarButton;
                           IsHovered: Boolean);
Var
 BtnSize: Integer;
Begin
 BtnSize := TOOLBAR_BUTTON_SIZE;
 
 If Button.Separator Then Begin
  { Dessiner un séparateur }
  SetColor(DarkGray);
  Line(X + BtnSize div 2, Y + 2, X + BtnSize div 2, Y + BtnSize - 2);
  SetColor(White);
  Line(X + BtnSize div 2 + 1, Y + 2, X + BtnSize div 2 + 1, Y + BtnSize - 2);
 End Else Begin
  { Dessiner le fond du bouton }
  If IsHovered Then Begin
   { Bouton survolé - effet 3D enfoncé }
   SetFillStyle(SolidFill, LightGray);
   Bar(X, Y, X + BtnSize - 1, Y + BtnSize - 1);
   SetColor(DarkGray);
   Line(X, Y, X + BtnSize - 1, Y);
   Line(X, Y, X, Y + BtnSize - 1);
   SetColor(White);
   Line(X + BtnSize - 1, Y, X + BtnSize - 1, Y + BtnSize - 1);
   Line(X, Y + BtnSize - 1, X + BtnSize - 1, Y + BtnSize - 1);
  End Else Begin
   { Bouton normal - effet 3D relevé }
   SetFillStyle(SolidFill, LightGray);
   Bar(X, Y, X + BtnSize - 1, Y + BtnSize - 1);
   SetColor(White);
   Line(X, Y, X + BtnSize - 1, Y);
   Line(X, Y, X, Y + BtnSize - 1);
   SetColor(DarkGray);
   Line(X + BtnSize - 1, Y, X + BtnSize - 1, Y + BtnSize - 1);
   Line(X, Y + BtnSize - 1, X + BtnSize - 1, Y + BtnSize - 1);
  End;
  
  { Dessiner le symbole centré }
  If Button.Enabled Then
   SetColor(Black)
  Else
   SetColor(DarkGray);
  OutTextXY(X + (BtnSize - TextWidth(Button.Symbol)) div 2,
            Y + (BtnSize - 10) div 2, Button.Symbol);
 End;
End;

{ Dessiner une barre d'outils complète }
Procedure DrawToolbar(ToolbarIndex: Integer);
Var
 I: Integer;
 X, Y: Integer;
 BtnX: Integer;
 TitleHeight: Integer;
 ToolbarWidth: Integer;
 IsHovered: Boolean;
Begin
 If (ToolbarIndex < 0) or (ToolbarIndex >= MAX_TOOLBARS) Then Exit;
 If Not Toolbars[ToolbarIndex].Visible Then Exit;
 
 X := Toolbars[ToolbarIndex].X;
 Y := Toolbars[ToolbarIndex].Y;
 TitleHeight := 0;
 
 { Calculer la largeur de la barre d'outils }
 ToolbarWidth := Toolbars[ToolbarIndex].ButtonCount * (TOOLBAR_BUTTON_SIZE + TOOLBAR_SPACING) + 4;
 
 If Not Toolbars[ToolbarIndex].Docked Then Begin
  { Barre flottante - dessiner la barre de titre }
  TitleHeight := 16;
  
  { Barre de titre }
  SetFillStyle(SolidFill, Blue);
  Bar(X, Y, X + ToolbarWidth, Y + TitleHeight);
  SetColor(White);
  OutTextXY(X + 3, Y + 3, Toolbars[ToolbarIndex].Title);
  
  { Bordure de la fenêtre flottante }
  SetColor(DarkGray);
  Rectangle(X, Y, X + ToolbarWidth, Y + TitleHeight + TOOLBAR_BUTTON_SIZE + 6);
 End;
 
 { Fond de la barre d'outils }
 SetFillStyle(SolidFill, LightGray);
 Bar(X, Y + TitleHeight, X + ToolbarWidth, Y + TitleHeight + TOOLBAR_BUTTON_SIZE + 4);
 
 { Dessiner les boutons }
 BtnX := X + 2;
 For I := 0 to Toolbars[ToolbarIndex].ButtonCount - 1 do Begin
  IsHovered := (HoveredToolbar = ToolbarIndex) and (HoveredButton = I);
  DrawToolbarButton(BtnX, Y + TitleHeight + 2, Toolbars[ToolbarIndex].Buttons[I], IsHovered);
  BtnX := BtnX + TOOLBAR_BUTTON_SIZE + TOOLBAR_SPACING;
 End;
End;

{ Dessiner toutes les barres d'outils }
Procedure DrawAllToolbars;
Var
 I: Integer;
Begin
 { Zone de fond pour les barres d'outils ancrées en haut }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, MENUBAR_HEIGHT, ScreenWidth - 1, MENUBAR_HEIGHT + TOOLBAR_HEIGHT - 1);
 SetColor(DarkGray);
 Line(0, MENUBAR_HEIGHT + TOOLBAR_HEIGHT - 1, ScreenWidth - 1, MENUBAR_HEIGHT + TOOLBAR_HEIGHT - 1);
 
 { Dessiner chaque barre d'outils visible }
 For I := 0 to MAX_TOOLBARS - 1 do Begin
  DrawToolbar(I);
 End;
End;

{ Vérifier si un clic est dans une barre d'outils }
Function IsInToolbar(X, Y: Integer): Boolean;
Begin
 IsInToolbar := (Y >= MENUBAR_HEIGHT) and (Y < MENUBAR_HEIGHT + TOOLBAR_HEIGHT);
End;

{ Trouver le bouton de barre d'outils sous le curseur }
Procedure GetToolbarButtonAtPosition(X, Y: Integer; Var TbIndex, BtnIndex: Integer);
Var
 I, J: Integer;
 TbX, TbY: Integer;
 BtnX: Integer;
 TitleHeight: Integer;
Begin
 TbIndex := -1;
 BtnIndex := -1;
 
 For I := 0 to MAX_TOOLBARS - 1 do Begin
  If Not Toolbars[I].Visible Then Continue;
  
  TbX := Toolbars[I].X;
  TbY := Toolbars[I].Y;
  TitleHeight := 0;
  
  If Not Toolbars[I].Docked Then
   TitleHeight := 16;
  
  { Vérifier si on est dans la zone de cette barre d'outils }
  BtnX := TbX + 2;
  For J := 0 to Toolbars[I].ButtonCount - 1 do Begin
   If (X >= BtnX) and (X < BtnX + TOOLBAR_BUTTON_SIZE) and
      (Y >= TbY + TitleHeight + 2) and (Y < TbY + TitleHeight + 2 + TOOLBAR_BUTTON_SIZE) Then Begin
    If Not Toolbars[I].Buttons[J].Separator Then Begin
     TbIndex := I;
     BtnIndex := J;
     Exit;
    End;
   End;
   BtnX := BtnX + TOOLBAR_BUTTON_SIZE + TOOLBAR_SPACING;
  End;
 End;
End;

{ Convertir les coordonnées écran en coordonnées monde - TODO 7 }
Function ScreenToWorldX(SX: Integer): Real;
Var
 CanvasLeft, CanvasWidth: Integer;
 CanvasCenterX: Real;
Begin
 CanvasLeft := 0;
 CanvasWidth := ScreenWidth;
 CanvasCenterX := CanvasWidth / 2.0;
 ScreenToWorldX := ((SX - CanvasLeft - CanvasCenterX) / ZoomLevel) - ViewOffsetX;
End;

Function ScreenToWorldY(SY: Integer): Real;
Var
 CanvasTop, CanvasHeight: Integer;
 CanvasCenterY: Real;
Begin
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasHeight := ScreenHeight - CanvasTop - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 CanvasCenterY := CanvasTop + CanvasHeight / 2.0;
 ScreenToWorldY := -((SY - CanvasCenterY) / ZoomLevel) - ViewOffsetY;
End;

{ Convertir les coordonnées monde en coordonnées écran - TODO 7 }
Function WorldToScreenX(WX: Real): Integer;
Var
 CanvasLeft, CanvasWidth: Integer;
 CanvasCenterX: Real;
Begin
 CanvasLeft := 0;
 CanvasWidth := ScreenWidth;
 CanvasCenterX := CanvasWidth / 2.0;
 WorldToScreenX := Round((WX + ViewOffsetX) * ZoomLevel + CanvasCenterX);
End;

Function WorldToScreenY(WY: Real): Integer;
Var
 CanvasTop, CanvasHeight: Integer;
 CanvasCenterY: Real;
Begin
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasHeight := ScreenHeight - CanvasTop - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 CanvasCenterY := CanvasTop + CanvasHeight / 2.0;
 WorldToScreenY := Round(-(WY + ViewOffsetY) * ZoomLevel + CanvasCenterY);
End;

{ Dessiner la grille de fond - TODO 7 }
Procedure DrawGrid;
Var
 CanvasTop, CanvasBottom, CanvasLeft, CanvasRight: Integer;
 GridSpacing: Real;
 X, Y: Real;
 SX, SY: Integer;
 StartX, StartY, EndX, EndY: Real;
Begin
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasBottom := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 CanvasLeft := 0;
 CanvasRight := ScreenWidth - 1;
 
 { Calculer l'espacement de la grille en fonction du zoom }
 GridSpacing := 50.0;  { Espacement de base }
 If ZoomLevel < 0.5 Then GridSpacing := 100.0;
 If ZoomLevel < 0.25 Then GridSpacing := 200.0;
 If ZoomLevel > 2.0 Then GridSpacing := 25.0;
 If ZoomLevel > 4.0 Then GridSpacing := 10.0;
 
 { Calculer les limites visibles en coordonnées monde }
 StartX := ScreenToWorldX(CanvasLeft);
 EndX := ScreenToWorldX(CanvasRight);
 StartY := ScreenToWorldY(CanvasBottom);
 EndY := ScreenToWorldY(CanvasTop);
 
 { Arrondir au multiple de GridSpacing }
 StartX := Int(StartX / GridSpacing) * GridSpacing - GridSpacing;
 StartY := Int(StartY / GridSpacing) * GridSpacing - GridSpacing;
 
 SetColor(DarkGray);
 
 { Dessiner les lignes verticales }
 X := StartX;
 While X <= EndX do Begin
  SX := WorldToScreenX(X);
  If (SX >= CanvasLeft) and (SX <= CanvasRight) Then
   Line(SX, CanvasTop, SX, CanvasBottom);
  X := X + GridSpacing;
 End;
 
 { Dessiner les lignes horizontales }
 Y := StartY;
 While Y <= EndY do Begin
  SY := WorldToScreenY(Y);
  If (SY >= CanvasTop) and (SY <= CanvasBottom) Then
   Line(CanvasLeft, SY, CanvasRight, SY);
  Y := Y + GridSpacing;
 End;
 
 { Dessiner les axes principaux }
 SetColor(Red);
 SX := WorldToScreenX(0);
 If (SX >= CanvasLeft) and (SX <= CanvasRight) Then
  Line(SX, CanvasTop, SX, CanvasBottom);
 
 SetColor(Green);
 SY := WorldToScreenY(0);
 If (SY >= CanvasTop) and (SY <= CanvasBottom) Then
  Line(CanvasLeft, SY, CanvasRight, SY);
End;

{ ============================================================================ }
{ Procédures pour le curseur de précision (crosshair) - TODO 8                  }
{ Créer le curseur de précision avec affichage des coordonnées en temps réel   }
{ ============================================================================ }

{ Initialiser les paramètres du crosshair }
Procedure InitCrosshairSettings;
Begin
 CrosshairSize := CROSSHAIR_SIZE_FULLSCREEN;  { Plein écran par défaut comme AutoCAD }
 CrosshairColor := White;
 CoordDisplayMode := COORD_DISPLAY_BOTH;      { Tooltip + barre d'état }
 ShowPickBox := True;                         { Afficher la boîte de sélection }
 PickBoxSize := 5;                            { Taille de la boîte de sélection }
End;

{ Dessiner le curseur crosshair de précision }
Procedure DrawCrosshairCursor(X, Y: Integer);
Var
 CanvasTop, CanvasBottom, CanvasLeft, CanvasRight: Integer;
 HalfSize: Integer;
 StartX, EndX, StartY, EndY: Integer;
Begin
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasBottom := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 CanvasLeft := 0;
 CanvasRight := ScreenWidth - 1;
 
 { Vérifier que le curseur est dans la zone de dessin }
 If (X < CanvasLeft) or (X > CanvasRight) or
    (Y < CanvasTop) or (Y > CanvasBottom) Then Exit;
 
 { Définir la couleur du crosshair }
 SetColor(CrosshairColor);
 SetWriteMode(XORPut);  { Mode XOR pour effacer/redessiner facilement }
 
 If CrosshairSize = CROSSHAIR_SIZE_FULLSCREEN Then Begin
  { Crosshair plein écran - lignes traversant tout le canvas }
  { Ligne horizontale }
  Line(CanvasLeft, Y, X - 3, Y);      { Gauche du curseur }
  Line(X + 3, Y, CanvasRight, Y);     { Droite du curseur }
  
  { Ligne verticale }
  Line(X, CanvasTop, X, Y - 3);       { Haut du curseur }
  Line(X, Y + 3, X, CanvasBottom);    { Bas du curseur }
 End Else Begin
  { Crosshair de taille limitée }
  HalfSize := CrosshairSize div 2;
  
  { Calculer les limites en respectant les bords du canvas }
  StartX := X - HalfSize;
  If StartX < CanvasLeft Then StartX := CanvasLeft;
  EndX := X + HalfSize;
  If EndX > CanvasRight Then EndX := CanvasRight;
  
  StartY := Y - HalfSize;
  If StartY < CanvasTop Then StartY := CanvasTop;
  EndY := Y + HalfSize;
  If EndY > CanvasBottom Then EndY := CanvasBottom;
  
  { Ligne horizontale avec gap au centre }
  If X - 3 >= StartX Then
   Line(StartX, Y, X - 3, Y);
  If X + 3 <= EndX Then
   Line(X + 3, Y, EndX, Y);
  
  { Ligne verticale avec gap au centre }
  If Y - 3 >= StartY Then
   Line(X, StartY, X, Y - 3);
  If Y + 3 <= EndY Then
   Line(X, Y + 3, X, EndY);
 End;
 
 { Dessiner la boîte de sélection (pickbox) au centre }
 If ShowPickBox Then Begin
  SetColor(CrosshairColor);
  Rectangle(X - PickBoxSize, Y - PickBoxSize, X + PickBoxSize, Y + PickBoxSize);
 End;
 
 SetWriteMode(NormalPut);  { Restaurer le mode normal }
End;

{ Dessiner le tooltip des coordonnées près du curseur }
Procedure DrawCoordinateTooltip(X, Y: Integer);
Var
 WorldX, WorldY: Real;
 CoordStr: String;
 StrX, StrY: String;
 TooltipX, TooltipY: Integer;
 TooltipWidth, TooltipHeight: Integer;
 CanvasTop, CanvasBottom: Integer;
Begin
 { Vérifier le mode d'affichage }
 If (CoordDisplayMode = COORD_DISPLAY_NONE) or 
    (CoordDisplayMode = COORD_DISPLAY_STATUSBAR) Then Exit;
 
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasBottom := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 
 { Vérifier que le curseur est dans la zone de dessin }
 If (Y < CanvasTop) or (Y > CanvasBottom) Then Exit;
 
 { Calculer les coordonnées monde }
 WorldX := ScreenToWorldX(X);
 WorldY := ScreenToWorldY(Y);
 
 { Formater la chaîne de coordonnées }
 Str(WorldX:0:2, StrX);
 Str(WorldY:0:2, StrY);
 CoordStr := StrX + ', ' + StrY;
 
 { Calculer la position du tooltip (en bas à droite du curseur) }
 TooltipX := X + 15;
 TooltipY := Y + 15;
 TooltipWidth := TextWidth(CoordStr) + 6;
 TooltipHeight := 14;
 
 { Ajuster si dépasse l'écran }
 If TooltipX + TooltipWidth > ScreenWidth - 5 Then
  TooltipX := X - TooltipWidth - 5;
 If TooltipY + TooltipHeight > CanvasBottom - 5 Then
  TooltipY := Y - TooltipHeight - 5;
 
 { Dessiner le fond du tooltip }
 SetFillStyle(SolidFill, Black);
 Bar(TooltipX, TooltipY, TooltipX + TooltipWidth, TooltipY + TooltipHeight);
 
 { Dessiner la bordure }
 SetColor(Yellow);
 Rectangle(TooltipX, TooltipY, TooltipX + TooltipWidth, TooltipY + TooltipHeight);
 
 { Dessiner le texte des coordonnées }
 SetColor(Yellow);
 OutTextXY(TooltipX + 3, TooltipY + 2, CoordStr);
End;

{ ============================================================================ }
{ Procédures pour le système de sélection d'objets - TODO 9                    }
{ Implémenter la sélection par clic, fenêtre et fenêtre croisée                }
{ ============================================================================ }

{ Initialiser le système de sélection }
Procedure InitSelectionSystem;
Var
 I: Integer;
Begin
 { Initialiser le compteur d'objets }
 ObjectCount := 0;
 
 { Effacer tous les objets }
 For I := 0 to MAX_OBJECTS - 1 do Begin
  DrawObjects[I].ObjType := OBJ_NONE;
  DrawObjects[I].Selected := False;
  DrawObjects[I].Visible := True;
 End;
 
 { Initialiser le jeu de sélection }
 SelectionSet.Count := 0;
 For I := 0 to MAX_SELECTED - 1 do
  SelectionSet.Objects[I] := -1;
 
 { Initialiser les variables de sélection }
 SelectMode := SELECT_MODE_NONE;
 SelectionActive := False;
 SelectStartX := 0;
 SelectStartY := 0;
 SelectEndX := 0;
 SelectEndY := 0;
 
 { Créer quelques objets de démonstration }
 { Ligne horizontale }
 DrawObjects[0].ObjType := OBJ_LINE;
 DrawObjects[0].X1 := -100;
 DrawObjects[0].Y1 := 50;
 DrawObjects[0].X2 := 100;
 DrawObjects[0].Y2 := 50;
 DrawObjects[0].Color := Yellow;
 DrawObjects[0].Selected := False;
 DrawObjects[0].Visible := True;
 
 { Ligne verticale }
 DrawObjects[1].ObjType := OBJ_LINE;
 DrawObjects[1].X1 := 0;
 DrawObjects[1].Y1 := -80;
 DrawObjects[1].X2 := 0;
 DrawObjects[1].Y2 := 120;
 DrawObjects[1].Color := Cyan;
 DrawObjects[1].Selected := False;
 DrawObjects[1].Visible := True;
 
 { Cercle }
 DrawObjects[2].ObjType := OBJ_CIRCLE;
 DrawObjects[2].X1 := -50;  { Centre X }
 DrawObjects[2].Y1 := -30;  { Centre Y }
 DrawObjects[2].Radius := 40;
 DrawObjects[2].Color := Green;
 DrawObjects[2].Selected := False;
 DrawObjects[2].Visible := True;
 
 { Rectangle (représenté par 4 lignes conceptuellement, mais comme un objet) }
 DrawObjects[3].ObjType := OBJ_RECTANGLE;
 DrawObjects[3].X1 := 60;   { Coin inférieur gauche X }
 DrawObjects[3].Y1 := -60;  { Coin inférieur gauche Y }
 DrawObjects[3].X2 := 140;  { Coin supérieur droit X }
 DrawObjects[3].Y2 := 20;   { Coin supérieur droit Y }
 DrawObjects[3].Color := Magenta;
 DrawObjects[3].Selected := False;
 DrawObjects[3].Visible := True;
 
 { Ligne diagonale }
 DrawObjects[4].ObjType := OBJ_LINE;
 DrawObjects[4].X1 := -120;
 DrawObjects[4].Y1 := -100;
 DrawObjects[4].X2 := -60;
 DrawObjects[4].Y2 := -40;
 DrawObjects[4].Color := LightRed;
 DrawObjects[4].Selected := False;
 DrawObjects[4].Visible := True;
 
 ObjectCount := 5;
End;

{ Effacer la sélection }
Procedure ClearSelection;
Var
 I: Integer;
Begin
 { Désélectionner tous les objets }
 For I := 0 to ObjectCount - 1 do
  DrawObjects[I].Selected := False;
 
 { Effacer le jeu de sélection }
 SelectionSet.Count := 0;
 For I := 0 to MAX_SELECTED - 1 do
  SelectionSet.Objects[I] := -1;
End;

{ Vérifier si un objet est sélectionné }
Function IsSelected(ObjIndex: Integer): Boolean;
Var
 I: Integer;
Begin
 IsSelected := False;
 If (ObjIndex < 0) or (ObjIndex >= ObjectCount) Then Exit;
 
 For I := 0 to SelectionSet.Count - 1 do Begin
  If SelectionSet.Objects[I] = ObjIndex Then Begin
   IsSelected := True;
   Exit;
  End;
 End;
End;

{ Ajouter un objet à la sélection }
Procedure AddToSelection(ObjIndex: Integer);
Begin
 If (ObjIndex < 0) or (ObjIndex >= ObjectCount) Then Exit;
 If SelectionSet.Count >= MAX_SELECTED Then Exit;
 If IsSelected(ObjIndex) Then Exit;  { Déjà sélectionné }
 
 SelectionSet.Objects[SelectionSet.Count] := ObjIndex;
 SelectionSet.Count := SelectionSet.Count + 1;
 DrawObjects[ObjIndex].Selected := True;
End;

{ Retirer un objet de la sélection }
Procedure RemoveFromSelection(ObjIndex: Integer);
Var
 I, J: Integer;
Begin
 If (ObjIndex < 0) or (ObjIndex >= ObjectCount) Then Exit;
 
 For I := 0 to SelectionSet.Count - 1 do Begin
  If SelectionSet.Objects[I] = ObjIndex Then Begin
   { Décaler les éléments suivants }
   For J := I to SelectionSet.Count - 2 do
    SelectionSet.Objects[J] := SelectionSet.Objects[J + 1];
   SelectionSet.Count := SelectionSet.Count - 1;
   SelectionSet.Objects[SelectionSet.Count] := -1;
   DrawObjects[ObjIndex].Selected := False;
   Exit;
  End;
 End;
End;

{ Vérifier si un point est proche d'une ligne }
Function PointNearLine(PX, PY, X1, Y1, X2, Y2: Real; Tolerance: Real): Boolean;
Var
 DX, DY, T: Real;
 NearX, NearY: Real;
 Dist: Real;
Begin
 PointNearLine := False;
 
 DX := X2 - X1;
 DY := Y2 - Y1;
 
 { Calculer le paramètre t pour le point le plus proche sur la ligne }
 If (DX = 0) and (DY = 0) Then Begin
  { Ligne dégénérée (point) }
  Dist := Sqrt(Sqr(PX - X1) + Sqr(PY - Y1));
  PointNearLine := Dist <= Tolerance;
  Exit;
 End;
 
 T := ((PX - X1) * DX + (PY - Y1) * DY) / (Sqr(DX) + Sqr(DY));
 
 { Limiter t entre 0 et 1 pour rester sur le segment }
 If T < 0 Then T := 0;
 If T > 1 Then T := 1;
 
 { Calculer le point le plus proche sur le segment }
 NearX := X1 + T * DX;
 NearY := Y1 + T * DY;
 
 { Calculer la distance }
 Dist := Sqrt(Sqr(PX - NearX) + Sqr(PY - NearY));
 PointNearLine := Dist <= Tolerance;
End;

{ Vérifier si un point est proche d'un cercle }
Function PointNearCircle(PX, PY, CX, CY, Radius: Real; Tolerance: Real): Boolean;
Var
 Dist: Real;
Begin
 Dist := Abs(Sqrt(Sqr(PX - CX) + Sqr(PY - CY)) - Radius);
 PointNearCircle := Dist <= Tolerance;
End;

{ Vérifier si un objet intersecte un rectangle (pour fenêtre croisée) }
Function ObjectIntersectsRect(ObjIndex: Integer; RX1, RY1, RX2, RY2: Real): Boolean;
Var
 MinX, MinY, MaxX, MaxY: Real;
 CX, CY, R: Real;
 OX1, OY1, OX2, OY2: Real;
Begin
 ObjectIntersectsRect := False;
 If (ObjIndex < 0) or (ObjIndex >= ObjectCount) Then Exit;
 
 { Normaliser le rectangle }
 If RX1 < RX2 Then Begin MinX := RX1; MaxX := RX2; End
 Else Begin MinX := RX2; MaxX := RX1; End;
 If RY1 < RY2 Then Begin MinY := RY1; MaxY := RY2; End
 Else Begin MinY := RY2; MaxY := RY1; End;
 
 Case DrawObjects[ObjIndex].ObjType of
  OBJ_LINE: Begin
   OX1 := DrawObjects[ObjIndex].X1;
   OY1 := DrawObjects[ObjIndex].Y1;
   OX2 := DrawObjects[ObjIndex].X2;
   OY2 := DrawObjects[ObjIndex].Y2;
   
   { Vérifier si au moins un point est dans le rectangle }
   If (OX1 >= MinX) and (OX1 <= MaxX) and (OY1 >= MinY) and (OY1 <= MaxY) Then Begin
    ObjectIntersectsRect := True;
    Exit;
   End;
   If (OX2 >= MinX) and (OX2 <= MaxX) and (OY2 >= MinY) and (OY2 <= MaxY) Then Begin
    ObjectIntersectsRect := True;
    Exit;
   End;
   
   { Vérifier l'intersection avec les bords du rectangle }
   { Simplification: vérifier si la ligne croise le rectangle }
   If ((OX1 < MinX) and (OX2 > MaxX)) or ((OX1 > MaxX) and (OX2 < MinX)) Then Begin
    { La ligne traverse horizontalement }
    If (OY1 >= MinY) and (OY1 <= MaxY) or (OY2 >= MinY) and (OY2 <= MaxY) Then Begin
     ObjectIntersectsRect := True;
     Exit;
    End;
   End;
   If ((OY1 < MinY) and (OY2 > MaxY)) or ((OY1 > MaxY) and (OY2 < MinY)) Then Begin
    { La ligne traverse verticalement }
    If (OX1 >= MinX) and (OX1 <= MaxX) or (OX2 >= MinX) and (OX2 <= MaxX) Then Begin
     ObjectIntersectsRect := True;
     Exit;
    End;
   End;
  End;
  
  OBJ_CIRCLE: Begin
   CX := DrawObjects[ObjIndex].X1;
   CY := DrawObjects[ObjIndex].Y1;
   R := DrawObjects[ObjIndex].Radius;
   
   { Vérifier si le cercle intersecte le rectangle }
   { Le cercle intersecte si le centre est assez proche du rectangle }
   If (CX >= MinX - R) and (CX <= MaxX + R) and
      (CY >= MinY - R) and (CY <= MaxY + R) Then Begin
    ObjectIntersectsRect := True;
    Exit;
   End;
  End;
  
  OBJ_RECTANGLE: Begin
   OX1 := DrawObjects[ObjIndex].X1;
   OY1 := DrawObjects[ObjIndex].Y1;
   OX2 := DrawObjects[ObjIndex].X2;
   OY2 := DrawObjects[ObjIndex].Y2;
   
   { Les rectangles s'intersectent si aucun n'est complètement à l'extérieur }
   If Not ((OX2 < MinX) or (OX1 > MaxX) or (OY2 < MinY) or (OY1 > MaxY)) Then Begin
    ObjectIntersectsRect := True;
    Exit;
   End;
  End;
 End;
End;

{ Vérifier si un objet est complètement dans un rectangle (pour fenêtre normale) }
Function ObjectInsideRect(ObjIndex: Integer; RX1, RY1, RX2, RY2: Real): Boolean;
Var
 MinX, MinY, MaxX, MaxY: Real;
 CX, CY, R: Real;
 OX1, OY1, OX2, OY2: Real;
Begin
 ObjectInsideRect := False;
 If (ObjIndex < 0) or (ObjIndex >= ObjectCount) Then Exit;
 
 { Normaliser le rectangle }
 If RX1 < RX2 Then Begin MinX := RX1; MaxX := RX2; End
 Else Begin MinX := RX2; MaxX := RX1; End;
 If RY1 < RY2 Then Begin MinY := RY1; MaxY := RY2; End
 Else Begin MinY := RY2; MaxY := RY1; End;
 
 Case DrawObjects[ObjIndex].ObjType of
  OBJ_LINE: Begin
   OX1 := DrawObjects[ObjIndex].X1;
   OY1 := DrawObjects[ObjIndex].Y1;
   OX2 := DrawObjects[ObjIndex].X2;
   OY2 := DrawObjects[ObjIndex].Y2;
   
   { Les deux points doivent être dans le rectangle }
   ObjectInsideRect := (OX1 >= MinX) and (OX1 <= MaxX) and (OY1 >= MinY) and (OY1 <= MaxY) and
                       (OX2 >= MinX) and (OX2 <= MaxX) and (OY2 >= MinY) and (OY2 <= MaxY);
  End;
  
  OBJ_CIRCLE: Begin
   CX := DrawObjects[ObjIndex].X1;
   CY := DrawObjects[ObjIndex].Y1;
   R := DrawObjects[ObjIndex].Radius;
   
   { Le cercle entier doit être dans le rectangle }
   ObjectInsideRect := (CX - R >= MinX) and (CX + R <= MaxX) and
                       (CY - R >= MinY) and (CY + R <= MaxY);
  End;
  
  OBJ_RECTANGLE: Begin
   OX1 := DrawObjects[ObjIndex].X1;
   OY1 := DrawObjects[ObjIndex].Y1;
   OX2 := DrawObjects[ObjIndex].X2;
   OY2 := DrawObjects[ObjIndex].Y2;
   
   { Le rectangle objet doit être complètement dans le rectangle de sélection }
   ObjectInsideRect := (OX1 >= MinX) and (OX2 <= MaxX) and
                       (OY1 >= MinY) and (OY2 <= MaxY);
  End;
 End;
End;

{ Sélectionner un objet à un point (par clic) }
Function SelectObjectAtPoint(X, Y: Integer): Integer;
Var
 I: Integer;
 WorldX, WorldY: Real;
 Tolerance: Real;
 CX, CY, R: Real;
Begin
 SelectObjectAtPoint := -1;
 
 WorldX := ScreenToWorldX(X);
 WorldY := ScreenToWorldY(Y);
 Tolerance := PICK_TOLERANCE / ZoomLevel;
 
 { Parcourir tous les objets (en ordre inverse pour sélectionner les plus récents d'abord) }
 For I := ObjectCount - 1 downto 0 do Begin
  If Not DrawObjects[I].Visible Then Continue;
  If DrawObjects[I].ObjType = OBJ_NONE Then Continue;
  
  Case DrawObjects[I].ObjType of
   OBJ_LINE: Begin
    If PointNearLine(WorldX, WorldY, 
                     DrawObjects[I].X1, DrawObjects[I].Y1,
                     DrawObjects[I].X2, DrawObjects[I].Y2,
                     Tolerance) Then Begin
     SelectObjectAtPoint := I;
     Exit;
    End;
   End;
   
   OBJ_CIRCLE: Begin
    If PointNearCircle(WorldX, WorldY,
                       DrawObjects[I].X1, DrawObjects[I].Y1,
                       DrawObjects[I].Radius, Tolerance) Then Begin
     SelectObjectAtPoint := I;
     Exit;
    End;
   End;
   
   OBJ_RECTANGLE: Begin
    { Vérifier les 4 côtés du rectangle }
    CX := DrawObjects[I].X1;
    CY := DrawObjects[I].Y1;
    R := DrawObjects[I].X2;  { X2 = coin droit }
    
    { Côté bas }
    If PointNearLine(WorldX, WorldY, CX, CY, R, CY, Tolerance) Then Begin
     SelectObjectAtPoint := I;
     Exit;
    End;
    { Côté haut }
    If PointNearLine(WorldX, WorldY, CX, DrawObjects[I].Y2, R, DrawObjects[I].Y2, Tolerance) Then Begin
     SelectObjectAtPoint := I;
     Exit;
    End;
    { Côté gauche }
    If PointNearLine(WorldX, WorldY, CX, CY, CX, DrawObjects[I].Y2, Tolerance) Then Begin
     SelectObjectAtPoint := I;
     Exit;
    End;
    { Côté droit }
    If PointNearLine(WorldX, WorldY, R, CY, R, DrawObjects[I].Y2, Tolerance) Then Begin
     SelectObjectAtPoint := I;
     Exit;
    End;
   End;
  End;
 End;
End;

{ Sélectionner les objets dans une fenêtre }
Procedure SelectObjectsInWindow(X1, Y1, X2, Y2: Integer; Crossing: Boolean);
Var
 I: Integer;
 WorldX1, WorldY1, WorldX2, WorldY2: Real;
Begin
 WorldX1 := ScreenToWorldX(X1);
 WorldY1 := ScreenToWorldY(Y1);
 WorldX2 := ScreenToWorldX(X2);
 WorldY2 := ScreenToWorldY(Y2);
 
 For I := 0 to ObjectCount - 1 do Begin
  If Not DrawObjects[I].Visible Then Continue;
  If DrawObjects[I].ObjType = OBJ_NONE Then Continue;
  
  If Crossing Then Begin
   { Fenêtre croisée: sélectionner les objets qui touchent le rectangle }
   If ObjectIntersectsRect(I, WorldX1, WorldY1, WorldX2, WorldY2) Then
    AddToSelection(I);
  End Else Begin
   { Fenêtre normale: sélectionner uniquement les objets complètement à l'intérieur }
   If ObjectInsideRect(I, WorldX1, WorldY1, WorldX2, WorldY2) Then
    AddToSelection(I);
  End;
 End;
End;

{ Dessiner le rectangle de sélection }
Procedure DrawSelectionRectangle(X1, Y1, X2, Y2: Integer; IsCrossing: Boolean);
Var
 CanvasTop, CanvasBottom: Integer;
Begin
 If Not SelectionActive Then Exit;
 
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasBottom := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 
 { Limiter aux bornes du canvas }
 If Y1 < CanvasTop Then Y1 := CanvasTop;
 If Y2 < CanvasTop Then Y2 := CanvasTop;
 If Y1 > CanvasBottom Then Y1 := CanvasBottom;
 If Y2 > CanvasBottom Then Y2 := CanvasBottom;
 
 SetWriteMode(XORPut);
 
 If IsCrossing Then Begin
  { Fenêtre croisée: rectangle vert en pointillé }
  SetColor(LightGreen);
  SetLineStyle(DashedLn, 0, NormWidth);
 End Else Begin
  { Fenêtre normale: rectangle bleu en continu }
  SetColor(LightBlue);
  SetLineStyle(SolidLn, 0, NormWidth);
 End;
 
 Rectangle(X1, Y1, X2, Y2);
 
 { Restaurer les paramètres par défaut }
 SetWriteMode(NormalPut);
 SetLineStyle(SolidLn, 0, NormWidth);
End;

{ Démarrer une sélection par fenêtre }
Procedure StartWindowSelection(X, Y: Integer);
Begin
 SelectionActive := True;
 SelectStartX := X;
 SelectStartY := Y;
 SelectEndX := X;
 SelectEndY := Y;
 
 { Déterminer le mode en fonction de la direction }
 { Ce sera mis à jour pendant le drag }
 SelectMode := SELECT_MODE_WINDOW;
End;

{ Mettre à jour la sélection par fenêtre pendant le drag }
Procedure UpdateWindowSelection(X, Y: Integer);
Begin
 If Not SelectionActive Then Exit;
 
 { Effacer l'ancien rectangle }
 DrawSelectionRectangle(SelectStartX, SelectStartY, SelectEndX, SelectEndY, 
                        SelectMode = SELECT_MODE_CROSSING);
 
 SelectEndX := X;
 SelectEndY := Y;
 
 { Déterminer le mode: fenêtre croisée si on va de droite à gauche }
 If SelectEndX < SelectStartX Then
  SelectMode := SELECT_MODE_CROSSING
 Else
  SelectMode := SELECT_MODE_WINDOW;
 
 { Dessiner le nouveau rectangle }
 DrawSelectionRectangle(SelectStartX, SelectStartY, SelectEndX, SelectEndY,
                        SelectMode = SELECT_MODE_CROSSING);
End;

{ Terminer la sélection par fenêtre }
Procedure FinishWindowSelection;
Begin
 If Not SelectionActive Then Exit;
 
 { Effacer le rectangle }
 DrawSelectionRectangle(SelectStartX, SelectStartY, SelectEndX, SelectEndY,
                        SelectMode = SELECT_MODE_CROSSING);
 
 { Sélectionner les objets }
 SelectObjectsInWindow(SelectStartX, SelectStartY, SelectEndX, SelectEndY,
                       SelectMode = SELECT_MODE_CROSSING);
 
 SelectionActive := False;
 SelectMode := SELECT_MODE_NONE;
End;

{ Dessiner tous les objets (avec mise en surbrillance des sélectionnés) }
Procedure DrawSelectedObjects;
Var
 I: Integer;
 SX1, SY1, SX2, SY2: Integer;
 SCX, SCY, SR: Integer;
 ObjColor: Integer;
Begin
 For I := 0 to ObjectCount - 1 do Begin
  If Not DrawObjects[I].Visible Then Continue;
  If DrawObjects[I].ObjType = OBJ_NONE Then Continue;
  
  { Déterminer la couleur }
  If DrawObjects[I].Selected Then
   ObjColor := White  { Couleur de surbrillance }
  Else
   ObjColor := DrawObjects[I].Color;
  
  SetColor(ObjColor);
  
  Case DrawObjects[I].ObjType of
   OBJ_LINE: Begin
    SX1 := WorldToScreenX(DrawObjects[I].X1);
    SY1 := WorldToScreenY(DrawObjects[I].Y1);
    SX2 := WorldToScreenX(DrawObjects[I].X2);
    SY2 := WorldToScreenY(DrawObjects[I].Y2);
    Line(SX1, SY1, SX2, SY2);
    
    { Si sélectionné, dessiner des poignées aux extrémités }
    If DrawObjects[I].Selected Then Begin
     SetFillStyle(SolidFill, Blue);
     Bar(SX1 - 3, SY1 - 3, SX1 + 3, SY1 + 3);
     Bar(SX2 - 3, SY2 - 3, SX2 + 3, SY2 + 3);
    End;
   End;
   
   OBJ_CIRCLE: Begin
    SCX := WorldToScreenX(DrawObjects[I].X1);
    SCY := WorldToScreenY(DrawObjects[I].Y1);
    SR := Round(DrawObjects[I].Radius * ZoomLevel);
    Circle(SCX, SCY, SR);
    
    { Si sélectionné, dessiner des poignées }
    If DrawObjects[I].Selected Then Begin
     SetFillStyle(SolidFill, Blue);
     Bar(SCX - 3, SCY - SR - 3, SCX + 3, SCY - SR + 3);  { Haut }
     Bar(SCX - 3, SCY + SR - 3, SCX + 3, SCY + SR + 3);  { Bas }
     Bar(SCX - SR - 3, SCY - 3, SCX - SR + 3, SCY + 3);  { Gauche }
     Bar(SCX + SR - 3, SCY - 3, SCX + SR + 3, SCY + 3);  { Droite }
     Bar(SCX - 3, SCY - 3, SCX + 3, SCY + 3);  { Centre }
    End;
   End;
   
   OBJ_RECTANGLE: Begin
    SX1 := WorldToScreenX(DrawObjects[I].X1);
    SY1 := WorldToScreenY(DrawObjects[I].Y1);
    SX2 := WorldToScreenX(DrawObjects[I].X2);
    SY2 := WorldToScreenY(DrawObjects[I].Y2);
    Rectangle(SX1, SY1, SX2, SY2);
    
    { Si sélectionné, dessiner des poignées aux coins }
    If DrawObjects[I].Selected Then Begin
     SetFillStyle(SolidFill, Blue);
     Bar(SX1 - 3, SY1 - 3, SX1 + 3, SY1 + 3);  { Coin 1 }
     Bar(SX2 - 3, SY1 - 3, SX2 + 3, SY1 + 3);  { Coin 2 }
     Bar(SX1 - 3, SY2 - 3, SX1 + 3, SY2 + 3);  { Coin 3 }
     Bar(SX2 - 3, SY2 - 3, SX2 + 3, SY2 + 3);  { Coin 4 }
    End;
   End;
  End;
 End;
 
 { Dessiner le rectangle de sélection si actif }
 If SelectionActive Then
  DrawSelectionRectangle(SelectStartX, SelectStartY, SelectEndX, SelectEndY,
                         SelectMode = SELECT_MODE_CROSSING);
End;

{ Dessiner la zone de dessin principale - TODO 7: Support zoom et pan, TODO 8: Crosshair, TODO 9: Sélection }
Procedure DrawCanvas;
Var
 CanvasTop, CanvasBottom: Integer;
 OriginX, OriginY: Integer;
Begin
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasBottom := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 
 { Zone de dessin noire - style AutoCAD }
 SetFillStyle(SolidFill, Black);
 Bar(0, CanvasTop, ScreenWidth - 1, CanvasBottom);

 { Dessiner la grille }
 DrawGrid;
 
 { TODO 9: Dessiner tous les objets du dessin }
 DrawSelectedObjects;
 
 { Dessiner un petit repère à l'origine (0,0) - UCS Icon }
 OriginX := WorldToScreenX(0);
 OriginY := WorldToScreenY(0);
 
 If (OriginX >= 0) and (OriginX < ScreenWidth) and
    (OriginY >= CanvasTop) and (OriginY < CanvasBottom) Then Begin
  { Axe X (rouge) }
  SetColor(Red);
  Line(OriginX, OriginY, OriginX + 20, OriginY);
  OutTextXY(OriginX + 22, OriginY - 4, 'X');
  
  { Axe Y (vert) }
  SetColor(Green);
  Line(OriginX, OriginY, OriginX, OriginY - 20);
  OutTextXY(OriginX - 4, OriginY - 30, 'Y');
  
  { Carré à l'origine }
  SetColor(White);
  Rectangle(OriginX - 2, OriginY - 2, OriginX + 2, OriginY + 2);
 End;
 
 { Dessiner le curseur crosshair qui suit la souris - TODO 8 }
 DrawCrosshairCursor(MouseX, MouseY);
 
 { Dessiner le tooltip des coordonnées - TODO 8 }
 If (CoordDisplayMode = COORD_DISPLAY_TOOLTIP) or (CoordDisplayMode = COORD_DISPLAY_BOTH) Then
  DrawCoordinateTooltip(MouseX, MouseY);
 
 { Indicateur de mode pan si actif - TODO 7 }
 If MouseMode = MOUSE_MODE_PAN Then Begin
  SetColor(Yellow);
  OutTextXY(ScreenWidth div 2 - 20, CanvasTop + 5, '** PAN **');
 End;
 
 { Indicateur de mode zoom si actif }
 If MouseMode = MOUSE_MODE_ZOOM Then Begin
  SetColor(Yellow);
  OutTextXY(ScreenWidth div 2 - 20, CanvasTop + 5, '** ZOOM **');
 End;
 
 { TODO 9: Indicateur de mode sélection si actif }
 If MouseMode = MOUSE_MODE_SELECT Then Begin
  SetColor(Cyan);
  If SelectMode = SELECT_MODE_CROSSING Then
   OutTextXY(ScreenWidth div 2 - 40, CanvasTop + 5, '** CROSSING **')
  Else
   OutTextXY(ScreenWidth div 2 - 35, CanvasTop + 5, '** WINDOW **');
 End;
End;

{ Dessiner la ligne de commande }
Procedure DrawCommandLine;
Begin
 { Fond de la ligne de commande }
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT,
     ScreenWidth - 1, ScreenHeight - STATUSBAR_HEIGHT - 1);

 SetColor(White);
 OutTextXY(5, ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT + 5, 'Command:');
End;

{ Dessiner la barre d'état }
Procedure DrawStatusBar;
Var
 CoordStr, ZoomStr, SelStr: String;
 WorldX, WorldY: Real;
Begin
 { Fond de la barre d'état }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, ScreenHeight - STATUSBAR_HEIGHT, ScreenWidth - 1, ScreenHeight - 1);

 SetColor(Black);
 Line(0, ScreenHeight - STATUSBAR_HEIGHT, ScreenWidth - 1, ScreenHeight - STATUSBAR_HEIGHT);

 { Coordonnées du curseur en coordonnées monde - TODO 7 }
 WorldX := ScreenToWorldX(MouseX);
 WorldY := ScreenToWorldY(MouseY);
 Str(WorldX:8:2, CoordStr);
 CoordStr := CoordStr + ', ';
 Str(WorldY:8:2, ZoomStr);
 CoordStr := CoordStr + ZoomStr + ', 0.00';
 OutTextXY(5, ScreenHeight - STATUSBAR_HEIGHT + 5, CoordStr);

 { Niveau de zoom - TODO 7 }
 Str(ZoomLevel * 100:5:0, ZoomStr);
 ZoomStr := 'Zoom: ' + ZoomStr + '%';
 OutTextXY(200, ScreenHeight - STATUSBAR_HEIGHT + 5, ZoomStr);

 { TODO 9: Nombre d'objets sélectionnés }
 If SelectionSet.Count > 0 Then Begin
  Str(SelectionSet.Count, SelStr);
  SelStr := 'Sel: ' + SelStr + ' obj';
  SetColor(Blue);
  OutTextXY(280, ScreenHeight - STATUSBAR_HEIGHT + 5, SelStr);
  SetColor(Black);
 End;

 { Modes SNAP, GRID, ORTHO, etc. }
 OutTextXY(360, ScreenHeight - STATUSBAR_HEIGHT + 5, 'SNAP GRID ORTHO OSNAP MODEL');
End;

{ Dessiner l'interface complète }
Procedure DrawInterface;
Begin
 { Effacer l'écran }
 ClearDevice;

 { Dessiner les éléments de l'interface }
 DrawMenuBar;
 DrawAllToolbars;  { TODO 5: Barres d'outils }
 DrawCanvas;
 DrawCommandLine;
 DrawStatusBar;

 { Si un menu est actif, le dessiner }
 If MenuActive and (ActiveMenu >= 0) Then
  DrawDropdownMenu(ActiveMenu);
 
 { Si le menu contextuel est actif, le dessiner - TODO 6 }
 If ContextMenuActive Then
  DrawContextMenu;
End;

{ Vérifier si un clic est dans la barre de menu }
Function IsInMenuBar(X, Y: Integer): Boolean;
Begin
 IsInMenuBar := (Y >= 0) and (Y < MENUBAR_HEIGHT);
End;

{ Trouver le menu sous le curseur }
Function GetMenuAtPosition(X: Integer): Integer;
Var
 I: Integer;
 MenuEnd: Integer;
Begin
 GetMenuAtPosition := -1;
 For I := 0 to MAX_MENUS - 1 do Begin
  If I < MAX_MENUS - 1 Then
   MenuEnd := Menus[I + 1].X - 5
  Else
   MenuEnd := Menus[I].X + TextWidth(Menus[I].Title) + 10;

  If (X >= Menus[I].X - 2) and (X < MenuEnd) Then Begin
   GetMenuAtPosition := I;
   Exit;
  End;
 End;
End;

{ Trouver l'élément de menu sous le curseur }
Function GetMenuItemAtPosition(MenuIndex, X, Y: Integer): Integer;
Var
 ItemHeight: Integer;
 ItemIndex: Integer;
 MenuY: Integer;
Begin
 GetMenuItemAtPosition := -1;
 If (MenuIndex < 0) or (MenuIndex >= MAX_MENUS) Then Exit;

 ItemHeight := 18;
 MenuY := MENUBAR_HEIGHT;

 If (X >= Menus[MenuIndex].X - 2) and (X <= Menus[MenuIndex].X + Menus[MenuIndex].Width) and
    (Y >= MenuY) and (Y < MenuY + Menus[MenuIndex].ItemCount * ItemHeight + 4) Then
 Begin
  ItemIndex := (Y - MenuY - 2) div ItemHeight;
  If (ItemIndex >= 0) and (ItemIndex < Menus[MenuIndex].ItemCount) Then Begin
   If Not Menus[MenuIndex].Items[ItemIndex].Separator Then
    GetMenuItemAtPosition := ItemIndex;
  End;
 End;
End;

{ Gérer les clics de souris }
Procedure HandleMouseClick(X, Y, Button: Integer);
Var
 NewMenu: Integer;
 NewItem: Integer;
 ContextItem: Integer;
 SelectedObj: Integer;
 CanvasTop, CanvasBottom: Integer;
Begin
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasBottom := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 
 { Gérer le menu contextuel en premier }
 If ContextMenuActive Then Begin
  If Button = MOUSE_BUTTON_LEFT Then Begin
   ContextItem := GetContextMenuItemAt(X, Y);
   If ContextItem >= 0 Then Begin
    ExecuteContextAction(ContextItem);
   End Else Begin
    { Clic en dehors - fermer le menu contextuel }
    ContextMenuActive := False;
    ActiveContextItem := -1;
    DrawInterface;
   End;
   Exit;
  End Else If Button = MOUSE_BUTTON_RIGHT Then Begin
   { Nouveau clic droit - repositionner le menu }
   ContextMenuX := X;
   ContextMenuY := Y;
   ActiveContextItem := -1;
   DrawInterface;
   DrawContextMenu;
   Exit;
  End;
 End;

 Case Button of
  MOUSE_BUTTON_LEFT: Begin { Clic gauche }
   { Démarrer un drag si nécessaire }
   If MouseMode <> MOUSE_MODE_NORMAL Then Begin
    MouseDragging := True;
    DragStartX := X;
    DragStartY := Y;
   End;
   
   If IsInMenuBar(X, Y) Then Begin
    NewMenu := GetMenuAtPosition(X);
    If NewMenu >= 0 Then Begin
     If MenuActive and (ActiveMenu = NewMenu) Then Begin
      { Fermer le menu si on clique sur le même }
      MenuActive := False;
      ActiveMenu := -1;
     End Else Begin
      { Ouvrir le nouveau menu }
      MenuActive := True;
      ActiveMenu := NewMenu;
      ActiveMenuItem := -1;
     End;
     DrawInterface;
    End;
   End Else If MenuActive Then Begin
    { Vérifier si on clique sur un élément de menu }
    NewItem := GetMenuItemAtPosition(ActiveMenu, X, Y);
    If NewItem >= 0 Then Begin
     { Exécuter l'action du menu }
     If (ActiveMenu = MENU_FILE) and (NewItem = 13) Then Begin
      { Exit }
      Running := False;
     End;
     MenuActive := False;
     ActiveMenu := -1;
     ActiveMenuItem := -1;
     DrawInterface;
    End Else Begin
     { Clic en dehors du menu - fermer }
     MenuActive := False;
     ActiveMenu := -1;
     ActiveMenuItem := -1;
     DrawInterface;
    End;
   End Else If (Y >= CanvasTop) and (Y <= CanvasBottom) Then Begin
    { TODO 9: Clic dans la zone de dessin - sélection d'objet }
    SelectedObj := SelectObjectAtPoint(X, Y);
    If SelectedObj >= 0 Then Begin
     { Un objet a été trouvé sous le curseur }
     If IsSelected(SelectedObj) Then Begin
      { Désélectionner si déjà sélectionné }
      RemoveFromSelection(SelectedObj);
     End Else Begin
      { Effacer la sélection précédente et sélectionner le nouvel objet }
      ClearSelection;
      AddToSelection(SelectedObj);
     End;
     DrawInterface;
    End Else Begin
     { Aucun objet sous le curseur - démarrer une sélection par fenêtre }
     ClearSelection;
     MouseMode := MOUSE_MODE_SELECT;
     MouseDragging := True;
     StartWindowSelection(X, Y);
     DragStartX := X;
     DragStartY := Y;
    End;
   End;
  End;
  
  MOUSE_BUTTON_RIGHT: Begin { Clic droit - TODO 6 }
   HandleRightClick(X, Y);
  End;
  
  MOUSE_BUTTON_MIDDLE: Begin { Clic milieu - TODO 6 }
   HandleMiddleClick(X, Y);
  End;
 End;
End;

{ Gérer le mouvement de la souris }
Procedure HandleMouseMove(X, Y: Integer);
Var
 NewItem: Integer;
 NewMenu: Integer;
Begin
 { Gérer le menu contextuel en premier - TODO 6 }
 If ContextMenuActive Then Begin
  HandleContextMenuHover(X, Y);
  LastMouseX := X;
  LastMouseY := Y;
  Exit;
 End;
 
 { Gérer le drag - TODO 6 }
 If MouseDragging Then Begin
  HandleMouseDrag(X, Y);
  LastMouseX := X;
  LastMouseY := Y;
  Exit;
 End;

 If MenuActive Then Begin
  { Vérifier si on survole un autre menu }
  If IsInMenuBar(X, Y) Then Begin
   NewMenu := GetMenuAtPosition(X);
   If (NewMenu >= 0) and (NewMenu <> ActiveMenu) Then Begin
    ActiveMenu := NewMenu;
    ActiveMenuItem := -1;
    DrawInterface;
   End;
  End Else Begin
   { Vérifier si on survole un élément de menu }
   NewItem := GetMenuItemAtPosition(ActiveMenu, X, Y);
   If NewItem <> ActiveMenuItem Then Begin
    ActiveMenuItem := NewItem;
    DrawInterface;
   End;
  End;
 End;
 
 { Mettre à jour la dernière position }
 LastMouseX := X;
 LastMouseY := Y;
End;

{ ============================================================================ }
{ Procédures de gestion avancée de la souris - TODO 6                          }
{ Implémenter la gestion complète de la souris avec clic gauche, clic droit,   }
{ molette et déplacement                                                        }
{ ============================================================================ }

{ Initialiser le menu contextuel }
Procedure InitContextMenu;
Begin
 ContextMenuItemCount := 10;
 
 ContextMenuItems[CONTEXT_REPEAT].Caption := 'Repeat Last Command';
 ContextMenuItems[CONTEXT_REPEAT].Enabled := True;
 ContextMenuItems[CONTEXT_REPEAT].Separator := False;
 
 ContextMenuItems[CONTEXT_RECENT_INPUT].Caption := 'Recent Input';
 ContextMenuItems[CONTEXT_RECENT_INPUT].Enabled := True;
 ContextMenuItems[CONTEXT_RECENT_INPUT].Separator := True;
 
 ContextMenuItems[CONTEXT_CUT].Caption := 'Cut';
 ContextMenuItems[CONTEXT_CUT].Enabled := True;
 ContextMenuItems[CONTEXT_CUT].Separator := False;
 
 ContextMenuItems[CONTEXT_COPY].Caption := 'Copy';
 ContextMenuItems[CONTEXT_COPY].Enabled := True;
 ContextMenuItems[CONTEXT_COPY].Separator := False;
 
 ContextMenuItems[CONTEXT_PASTE].Caption := 'Paste';
 ContextMenuItems[CONTEXT_PASTE].Enabled := True;
 ContextMenuItems[CONTEXT_PASTE].Separator := True;
 
 ContextMenuItems[CONTEXT_ERASE].Caption := 'Erase';
 ContextMenuItems[CONTEXT_ERASE].Enabled := True;
 ContextMenuItems[CONTEXT_ERASE].Separator := True;
 
 ContextMenuItems[CONTEXT_PAN].Caption := 'Pan';
 ContextMenuItems[CONTEXT_PAN].Enabled := True;
 ContextMenuItems[CONTEXT_PAN].Separator := False;
 
 ContextMenuItems[CONTEXT_ZOOM].Caption := 'Zoom';
 ContextMenuItems[CONTEXT_ZOOM].Enabled := True;
 ContextMenuItems[CONTEXT_ZOOM].Separator := True;
 
 ContextMenuItems[CONTEXT_PROPERTIES].Caption := 'Properties';
 ContextMenuItems[CONTEXT_PROPERTIES].Enabled := True;
 ContextMenuItems[CONTEXT_PROPERTIES].Separator := False;
 
 ContextMenuItems[CONTEXT_OPTIONS].Caption := 'Options...';
 ContextMenuItems[CONTEXT_OPTIONS].Enabled := True;
 ContextMenuItems[CONTEXT_OPTIONS].Separator := False;
 
 ContextMenuActive := False;
 ActiveContextItem := -1;
End;

{ Initialiser les variables de souris }
Procedure InitMouseState;
Begin
 MouseMode := MOUSE_MODE_NORMAL;
 MouseDragging := False;
 DragStartX := 0;
 DragStartY := 0;
 LastMouseX := 0;
 LastMouseY := 0;
 MouseWheelDelta := 0;
 ViewOffsetX := 0.0;
 ViewOffsetY := 0.0;
 ZoomLevel := 1.0;
 InitContextMenu;
 InitCrosshairSettings;  { TODO 8: Initialiser le crosshair }
 InitSelectionSystem;    { TODO 9: Initialiser le système de sélection }
End;

{ Dessiner le menu contextuel }
Procedure DrawContextMenu;
Var
 I: Integer;
 MenuWidth, MenuHeight: Integer;
 ItemHeight: Integer;
 X, Y: Integer;
Begin
 If Not ContextMenuActive Then Exit;
 
 ItemHeight := 18;
 MenuWidth := 160;
 MenuHeight := ContextMenuItemCount * ItemHeight + 4;
 X := ContextMenuX;
 Y := ContextMenuY;
 
 { Ajuster la position si le menu dépasse l'écran }
 If X + MenuWidth > ScreenWidth Then
  X := ScreenWidth - MenuWidth - 2;
 If Y + MenuHeight > ScreenHeight Then
  Y := ScreenHeight - MenuHeight - 2;
 
 { Fond du menu contextuel }
 SetFillStyle(SolidFill, LightGray);
 Bar(X, Y, X + MenuWidth, Y + MenuHeight);
 
 { Bordure 3D }
 SetColor(White);
 Line(X, Y, X + MenuWidth, Y);
 Line(X, Y, X, Y + MenuHeight);
 SetColor(DarkGray);
 Line(X + MenuWidth, Y, X + MenuWidth, Y + MenuHeight);
 Line(X, Y + MenuHeight, X + MenuWidth, Y + MenuHeight);
 
 { Dessiner les éléments }
 For I := 0 to ContextMenuItemCount - 1 do Begin
  If ContextMenuItems[I].Separator and (I > 0) Then Begin
   { Ligne de séparation au-dessus de cet élément }
   SetColor(DarkGray);
   Line(X + 2, Y + I * ItemHeight, X + MenuWidth - 2, Y + I * ItemHeight);
   SetColor(White);
   Line(X + 2, Y + I * ItemHeight + 1, X + MenuWidth - 2, Y + I * ItemHeight + 1);
  End;
  
  { Fond survolé }
  If I = ActiveContextItem Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(X + 2, Y + I * ItemHeight + 2, X + MenuWidth - 2, Y + (I + 1) * ItemHeight + 1);
   SetColor(White);
  End Else Begin
   If ContextMenuItems[I].Enabled Then
    SetColor(Black)
   Else
    SetColor(DarkGray);
  End;
  
  OutTextXY(X + 8, Y + I * ItemHeight + 5, ContextMenuItems[I].Caption);
 End;
End;

{ Obtenir l'élément de menu contextuel à la position }
Function GetContextMenuItemAt(X, Y: Integer): Integer;
Var
 ItemHeight: Integer;
 MenuWidth, MenuHeight: Integer;
 Index: Integer;
 MX, MY: Integer;
Begin
 GetContextMenuItemAt := -1;
 If Not ContextMenuActive Then Exit;
 
 ItemHeight := 18;
 MenuWidth := 160;
 MenuHeight := ContextMenuItemCount * ItemHeight + 4;
 MX := ContextMenuX;
 MY := ContextMenuY;
 
 { Ajuster la position si le menu dépasse l'écran }
 If MX + MenuWidth > ScreenWidth Then
  MX := ScreenWidth - MenuWidth - 2;
 If MY + MenuHeight > ScreenHeight Then
  MY := ScreenHeight - MenuHeight - 2;
 
 If (X >= MX) and (X <= MX + MenuWidth) and
    (Y >= MY) and (Y <= MY + MenuHeight) Then Begin
  Index := (Y - MY - 2) div ItemHeight;
  If (Index >= 0) and (Index < ContextMenuItemCount) Then
   GetContextMenuItemAt := Index;
 End;
End;

{ Gérer le clic droit de la souris }
Procedure HandleRightClick(X, Y: Integer);
Begin
 { Fermer le menu principal s'il est ouvert }
 If MenuActive Then Begin
  MenuActive := False;
  ActiveMenu := -1;
  ActiveMenuItem := -1;
 End;
 
 { Ouvrir le menu contextuel à la position du clic }
 ContextMenuActive := True;
 ContextMenuX := X;
 ContextMenuY := Y;
 ActiveContextItem := -1;
 DrawInterface;
 DrawContextMenu;
End;

{ Gérer le clic milieu de la souris (pan) }
Procedure HandleMiddleClick(X, Y: Integer);
Begin
 { Activer le mode pan }
 If MouseMode = MOUSE_MODE_PAN Then Begin
  { Désactiver le pan }
  MouseMode := MOUSE_MODE_NORMAL;
  MouseDragging := False;
 End Else Begin
  { Activer le pan }
  MouseMode := MOUSE_MODE_PAN;
  DragStartX := X;
  DragStartY := Y;
  MouseDragging := True;
 End;
End;

{ Gérer le drag de la souris (déplacement avec bouton enfoncé) }
Procedure HandleMouseDrag(X, Y: Integer);
Var
 DeltaX, DeltaY: Integer;
Begin
 If Not MouseDragging Then Exit;
 
 DeltaX := X - LastMouseX;
 DeltaY := Y - LastMouseY;
 
 Case MouseMode of
  MOUSE_MODE_PAN: Begin
   { Déplacer la vue }
   ViewOffsetX := ViewOffsetX + DeltaX / ZoomLevel;
   ViewOffsetY := ViewOffsetY + DeltaY / ZoomLevel;
   DrawInterface;
  End;
  MOUSE_MODE_SELECT: Begin
   { TODO 9: Mettre à jour le rectangle de sélection }
   UpdateWindowSelection(X, Y);
  End;
 End;
End;

{ Gérer la molette de la souris }
Procedure HandleMouseWheel(Delta: Integer);
Var
 ZoomFactor: Real;
 OldZoom: Real;
Begin
 OldZoom := ZoomLevel;
 
 If Delta > 0 Then Begin
  { Zoom avant }
  ZoomFactor := 1.1;
 End Else Begin
  { Zoom arrière }
  ZoomFactor := 0.9;
 End;
 
 ZoomLevel := ZoomLevel * ZoomFactor;
 
 { Limiter le zoom }
 If ZoomLevel < 0.1 Then ZoomLevel := 0.1;
 If ZoomLevel > 20.0 Then ZoomLevel := 20.0;
 
 { Redessiner si le zoom a changé }
 If ZoomLevel <> OldZoom Then
  DrawInterface;
End;

{ Exécuter une action du menu contextuel }
Procedure ExecuteContextAction(Action: Integer);
Begin
 Case Action of
  CONTEXT_REPEAT: Begin
   { Répéter la dernière commande }
  End;
  CONTEXT_CUT: Begin
   { Couper }
  End;
  CONTEXT_COPY: Begin
   { Copier }
  End;
  CONTEXT_PASTE: Begin
   { Coller }
  End;
  CONTEXT_ERASE: Begin
   { Effacer }
  End;
  CONTEXT_PAN: Begin
   { Activer le mode pan }
   MouseMode := MOUSE_MODE_PAN;
  End;
  CONTEXT_ZOOM: Begin
   { Activer le mode zoom }
   MouseMode := MOUSE_MODE_ZOOM;
  End;
  CONTEXT_PROPERTIES: Begin
   { Ouvrir les propriétés }
  End;
  CONTEXT_OPTIONS: Begin
   { Ouvrir les options }
  End;
 End;
 
 { Fermer le menu contextuel }
 ContextMenuActive := False;
 ActiveContextItem := -1;
 DrawInterface;
End;

{ Gérer le survol du menu contextuel }
Procedure HandleContextMenuHover(X, Y: Integer);
Var
 NewItem: Integer;
Begin
 If Not ContextMenuActive Then Exit;
 
 NewItem := GetContextMenuItemAt(X, Y);
 If NewItem <> ActiveContextItem Then Begin
  ActiveContextItem := NewItem;
  DrawInterface;
  DrawContextMenu;
 End;
End;

{ Boucle principale }
Procedure MainLoop;
Var
 OldMouseX, OldMouseY, OldButtons: Integer;
 LX, LY, LB: LongInt;
 Key: Char;
 PanStep: Real;
 I: Integer;  { TODO 9: Variable pour la sélection }
Begin
 Running := True;
 OldMouseX := -1;
 OldMouseY := -1;
 OldButtons := 0;

 ShowMouse;

 While Running do Begin
  { Lire l'état de la souris }
  GetMouseState(LX, LY, LB);
  MouseX := LX;
  MouseY := LY;
  MouseButtons := LB;

  { Détecter les clics - TODO 6: gestion complète des boutons }
  If (MouseButtons <> OldButtons) Then Begin
   { Clic gauche enfoncé }
   If ((MouseButtons and MOUSE_BUTTON_LEFT) = MOUSE_BUTTON_LEFT) and
      ((OldButtons and MOUSE_BUTTON_LEFT) = 0) Then
    HandleMouseClick(MouseX, MouseY, MOUSE_BUTTON_LEFT);
   
   { Clic gauche relâché - fin du drag }
   If ((MouseButtons and MOUSE_BUTTON_LEFT) = 0) and
      ((OldButtons and MOUSE_BUTTON_LEFT) = MOUSE_BUTTON_LEFT) Then Begin
    { TODO 9: Terminer la sélection par fenêtre si active }
    If MouseMode = MOUSE_MODE_SELECT Then Begin
     FinishWindowSelection;
     MouseMode := MOUSE_MODE_NORMAL;
     DrawInterface;
    End;
    MouseDragging := False;
   End;
   
   { Clic droit enfoncé }
   If ((MouseButtons and MOUSE_BUTTON_RIGHT) = MOUSE_BUTTON_RIGHT) and
      ((OldButtons and MOUSE_BUTTON_RIGHT) = 0) Then
    HandleMouseClick(MouseX, MouseY, MOUSE_BUTTON_RIGHT);
   
   { Clic milieu enfoncé - TODO 7: Activer le pan }
   If ((MouseButtons and MOUSE_BUTTON_MIDDLE) = MOUSE_BUTTON_MIDDLE) and
      ((OldButtons and MOUSE_BUTTON_MIDDLE) = 0) Then Begin
    HandleMouseClick(MouseX, MouseY, MOUSE_BUTTON_MIDDLE);
    MouseMode := MOUSE_MODE_PAN;
    MouseDragging := True;
    DragStartX := MouseX;
    DragStartY := MouseY;
   End;
   
   { Clic milieu relâché - fin du pan - TODO 7 }
   If ((MouseButtons and MOUSE_BUTTON_MIDDLE) = 0) and
      ((OldButtons and MOUSE_BUTTON_MIDDLE) = MOUSE_BUTTON_MIDDLE) Then Begin
    If MouseMode = MOUSE_MODE_PAN Then Begin
     MouseMode := MOUSE_MODE_NORMAL;
     MouseDragging := False;
     DrawInterface;
    End;
   End;
   
   OldButtons := MouseButtons;
  End;

  { Détecter les mouvements }
  If (MouseX <> OldMouseX) or (MouseY <> OldMouseY) Then Begin
   HandleMouseMove(MouseX, MouseY);
   OldMouseX := MouseX;
   OldMouseY := MouseY;
   { TODO 8: Redessiner le canvas pour mettre à jour le crosshair }
   DrawCanvas;
   { Mettre à jour la barre d'état avec les nouvelles coordonnées }
   DrawStatusBar;
  End;

  { Vérifier les touches clavier }
  If KeyPressed Then Begin
   Key := ReadKey;
   Case Key of
    #27: Begin { Escape pour quitter ou fermer les menus }
     If ContextMenuActive Then Begin
      ContextMenuActive := False;
      ActiveContextItem := -1;
      DrawInterface;
     End Else If MenuActive Then Begin
      MenuActive := False;
      ActiveMenu := -1;
      ActiveMenuItem := -1;
      DrawInterface;
     End Else If MouseMode <> MOUSE_MODE_NORMAL Then Begin
      { TODO 9: Annuler la sélection en cours }
      If SelectionActive Then Begin
       SelectionActive := False;
       SelectMode := SELECT_MODE_NONE;
      End;
      MouseMode := MOUSE_MODE_NORMAL;
      MouseDragging := False;
      DrawInterface;
     End Else If SelectionSet.Count > 0 Then Begin
      { TODO 9: Effacer la sélection existante }
      ClearSelection;
      DrawInterface;
     End Else Begin
      Running := False;
     End;
    End;
    { TODO 7: Raccourcis clavier pour zoom }
    '+', '=': Begin
     HandleMouseWheel(1);  { Zoom avant }
    End;
    '-', '_': Begin
     HandleMouseWheel(-1); { Zoom arrière }
    End;
    { TODO 8: Raccourcis pour la taille du crosshair }
    'c', 'C': Begin
     { Cycle entre les tailles de crosshair }
     If CrosshairSize = CROSSHAIR_SIZE_FULLSCREEN Then
      CrosshairSize := CROSSHAIR_SIZE_SMALL
     Else If CrosshairSize = CROSSHAIR_SIZE_SMALL Then
      CrosshairSize := CROSSHAIR_SIZE_MEDIUM
     Else If CrosshairSize = CROSSHAIR_SIZE_MEDIUM Then
      CrosshairSize := CROSSHAIR_SIZE_LARGE
     Else
      CrosshairSize := CROSSHAIR_SIZE_FULLSCREEN;
     DrawInterface;
    End;
    't', 'T': Begin
     { Toggle tooltip des coordonnées }
     If CoordDisplayMode = COORD_DISPLAY_BOTH Then
      CoordDisplayMode := COORD_DISPLAY_STATUSBAR
     Else If CoordDisplayMode = COORD_DISPLAY_STATUSBAR Then
      CoordDisplayMode := COORD_DISPLAY_TOOLTIP
     Else If CoordDisplayMode = COORD_DISPLAY_TOOLTIP Then
      CoordDisplayMode := COORD_DISPLAY_NONE
     Else
      CoordDisplayMode := COORD_DISPLAY_BOTH;
     DrawInterface;
    End;
    'p', 'P': Begin
     { Toggle pickbox }
     ShowPickBox := Not ShowPickBox;
     DrawInterface;
    End;
    { TODO 9: Raccourci pour sélectionner tous les objets }
    'a', 'A': Begin
     ClearSelection;
     { Sélectionner tous les objets visibles }
     For I := 0 to ObjectCount - 1 do Begin
      If DrawObjects[I].Visible and (DrawObjects[I].ObjType <> OBJ_NONE) Then
       AddToSelection(I);
     End;
     DrawInterface;
    End;
    { TODO 7: Touche spéciale (flèches) pour le pan }
    #0: Begin
     Key := ReadKey; { Lire le code étendu }
     PanStep := 50.0 / ZoomLevel;
     Case Key of
      #72: Begin { Flèche haut - pan vers le haut }
       ViewOffsetY := ViewOffsetY + PanStep;
       DrawInterface;
      End;
      #80: Begin { Flèche bas - pan vers le bas }
       ViewOffsetY := ViewOffsetY - PanStep;
       DrawInterface;
      End;
      #75: Begin { Flèche gauche - pan vers la gauche }
       ViewOffsetX := ViewOffsetX + PanStep;
       DrawInterface;
      End;
      #77: Begin { Flèche droite - pan vers la droite }
       ViewOffsetX := ViewOffsetX - PanStep;
       DrawInterface;
      End;
      #73: Begin { Page Up - zoom avant }
       HandleMouseWheel(1);
      End;
      #81: Begin { Page Down - zoom arrière }
       HandleMouseWheel(-1);
      End;
      #71: Begin { Home - reset zoom et pan }
       ViewOffsetX := 0.0;
       ViewOffsetY := 0.0;
       ZoomLevel := 1.0;
       DrawInterface;
      End;
     End;
    End;
   End;
  End;

  Delay(10);
 End;

 HideMouse;
End;

BEGIN
 { Initialisation }
 InitializeGraphics;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;

 { Initialiser les menus }
 InitMenus;

 { Initialiser les barres d'outils - TODO 5 }
 InitToolbars;

 { Initialiser la gestion de la souris - TODO 6 }
 InitMouseState;

 { Dessiner l'interface initiale }
 DrawInterface;

 { Lancer la boucle principale }
 MainLoop;

 { Fermer le mode graphique }
 CloseGraph;
END.