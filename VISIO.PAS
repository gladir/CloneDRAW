{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application Visio de Microsoft
}

{ TODO: Liste de 25 points pour un clone complet de Visio

  === MENUS ET INTERFACE ===
  1. [FAIT] Implementer le menu principal avec File, Edit, View, Insert, Format, Shape, Tools, Window, Help
  2. [FAIT] Ajouter le menu File avec New, Open, Close, Save, Save As, Export, Print, Print Preview, Exit
  3. [FAIT] Ajouter le menu Edit avec Undo, Redo, Cut, Copy, Paste, Delete, Select All, Find, Replace
  4. [FAIT] Ajouter le menu View avec Zoom In, Zoom Out, Fit Page, Grid, Rulers, Guides, Snap to Grid
  5. [FAIT] Ajouter le menu Insert avec Shape, Text Box, Image, Connector, Page, Layer
  6. [FAIT] Ajouter le menu Format avec Fill, Line, Text, Alignment, Arrange, Group, Ungroup
  7. [FAIT] Ajouter le menu Shape avec Rotate, Flip, Align, Distribute, Size, Position, Operations (Union, Intersect, Subtract)
  8. [FAIT] Implementer la barre d'outils avec boutons pour les actions frequentes (Selection, Rectangle, Ellipse, Ligne, Connecteur, Texte)

  === SUPPORT SOURIS ===
  9. [FAIT] Gerer les evenements de clic gauche pour selection et dessin d'objets
  10. [FAIT] Gerer le clic droit pour afficher un menu contextuel avec options (Cut, Copy, Paste, Delete, Properties)
  11. [FAIT] Implementer le glisser-deposer (drag and drop) pour deplacer et redimensionner les objets
  12. [FAIT] Ajouter les poignees de redimensionnement sur les objets selectionnes avec detection de survol

  === OBJETS ET FORMES ===
  13. [FAIT] Creer les types d'objets de base: Rectangle, Ellipse, Ligne, Polygone, Courbe de Bezier, Texte, Image
  14. [FAIT] Implementer les connecteurs entre objets avec points d'ancrage automatiques
  15. [FAIT] Permettre la modification des proprietes des objets: couleur de remplissage, couleur de trait, epaisseur de ligne, style de ligne
  16. [FAIT] Ajouter le support des calques (layers) avec visibilite et verrouillage
  17. [FAIT] Implementer la gestion des groupes d'objets (grouper, degrouper, entrer dans le groupe)

  === FORMAT DE FICHIER VISIO ===
  18. [FAIT] Parser et lire les fichiers Visio VSD/VSDX (format binaire OLE et format XML compresse)
  19. Ecrire et sauvegarder les fichiers au format Visio VSD/VSDX
  20. Gerer les stencils et les masters Visio

  === FORMAT SVG ===
  21. Parser et importer les fichiers SVG avec support des elements path, rect, circle, ellipse, line, polygon, text
  22. Exporter les dessins au format SVG avec attributs de style CSS

  === EXPORT IMAGES ===
  23. Exporter en format BMP avec support 1-bit, 4-bit, 8-bit, 24-bit
  24. Exporter en format GIF avec palette de 256 couleurs et transparence
  25. Exporter en format JPEG avec compression reglable et en format PNG avec canal alpha pour transparence
}

Program VISIO;

Uses {$IFDEF FPC}
      Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      Crt,Graph
     {$ENDIF};

Const
 { Constantes pour le menu principal }
 MENU_COUNT = 9;
 MENU_HEIGHT = 18;
 MENU_BAR_COLOR = 7;      { Gris clair }
 MENU_TEXT_COLOR = 0;     { Noir }
 MENU_HIGHLIGHT_BG = 1;   { Bleu }
 MENU_HIGHLIGHT_FG = 15;  { Blanc }
 
 { Constantes pour la barre d'outils }
 TOOLBAR_COUNT = 9;
 TOOLBAR_TOP = 19;        { Juste en dessous de la barre de menu }
 TOOLBAR_HEIGHT = 26;     { Hauteur de la barre d'outils }
 TOOLBAR_BUTTON_SIZE = 24; { Taille d'un bouton }
 TOOLBAR_PADDING = 2;     { Espacement entre les boutons }
 TOOLBAR_COLOR = 7;       { Gris clair - même couleur que la barre de menu }
 TOOLBAR_BTN_COLOR = 15;  { Blanc - fond des boutons }
 TOOLBAR_BTN_BORDER = 8;  { Gris foncé - bordure des boutons }
 TOOLBAR_BTN_SELECTED = 1; { Bleu - bouton sélectionné }
 
 { Constantes pour la zone de travail et les objets }
 WORK_AREA_TOP = 46;      { Début de la zone de travail (sous barre d'outils) }
 MAX_SHAPES = 100;        { Nombre maximum d'objets }
 DEFAULT_SHAPE_WIDTH = 80;  { Largeur par défaut d'une forme }
 DEFAULT_SHAPE_HEIGHT = 60; { Hauteur par défaut d'une forme }
 SELECTION_HANDLE_SIZE = 6; { Taille des poignées de sélection }
 
 { Constantes pour les polygones et courbes de Bézier }
 MAX_POLYGON_POINTS = 20;  { Nombre maximum de points pour un polygone }
 MAX_BEZIER_POINTS = 4;    { Nombre de points de contrôle pour une courbe de Bézier cubique }
 
 { Couleurs pour les poignées de redimensionnement }
 HANDLE_NORMAL_COLOR = 1;   { Bleu - couleur normale des poignées }
 HANDLE_HOVER_COLOR = 4;    { Rouge - couleur des poignées survolées }
 HANDLE_BORDER_COLOR = 15;  { Blanc - bordure des poignées }
 
 { Constantes pour le menu contextuel (clic droit) }
 CONTEXT_MENU_ITEM_COUNT = 5;     { Nombre d'éléments : Cut, Copy, Paste, Delete, Properties }
 CONTEXT_MENU_WIDTH = 100;        { Largeur du menu contextuel }
 CONTEXT_MENU_ITEM_HEIGHT = 18;   { Hauteur d'un élément }
 CONTEXT_MENU_BG_COLOR = 15;      { Blanc - fond du menu }
 CONTEXT_MENU_BORDER_COLOR = 8;   { Gris foncé - bordure }
 CONTEXT_MENU_TEXT_COLOR = 0;     { Noir - texte }
 CONTEXT_MENU_HIGHLIGHT_BG = 1;   { Bleu - surbrillance }
 CONTEXT_MENU_HIGHLIGHT_FG = 15;  { Blanc - texte surbrillance }
 CONTEXT_MENU_DISABLED_COLOR = 8; { Gris - texte désactivé }
 
 { Constantes pour le glisser-déposer (drag and drop) }
 DRAG_MODE_NONE = 0;      { Pas de glissement en cours }
 DRAG_MODE_MOVE = 1;      { Déplacement d'un objet }
 DRAG_MODE_RESIZE = 2;    { Redimensionnement d'un objet }
 
 { Constantes pour les poignées de redimensionnement }
 RESIZE_HANDLE_SIZE = 6;   { Taille des poignées en pixels }
 
 { Constantes pour les points d'ancrage des connecteurs }
 ANCHOR_NONE = 0;         { Pas d'ancrage }
 ANCHOR_TOP = 1;          { Point d'ancrage en haut (centre) }
 ANCHOR_BOTTOM = 2;       { Point d'ancrage en bas (centre) }
 ANCHOR_LEFT = 3;         { Point d'ancrage à gauche (centre) }
 ANCHOR_RIGHT = 4;        { Point d'ancrage à droite (centre) }
 ANCHOR_CENTER = 5;       { Point d'ancrage au centre }
 ANCHOR_COUNT = 4;        { Nombre de points d'ancrage par forme (haut, bas, gauche, droite) }
 ANCHOR_POINT_SIZE = 5;   { Taille des points d'ancrage en pixels }
 ANCHOR_SNAP_DISTANCE = 15; { Distance max pour accrocher à un point d'ancrage }
 RESIZE_HANDLE_NONE = 0;   { Aucune poignée }
 RESIZE_HANDLE_NW = 1;     { Coin nord-ouest (haut-gauche) }
 RESIZE_HANDLE_N = 2;      { Milieu nord (haut) }
 RESIZE_HANDLE_NE = 3;     { Coin nord-est (haut-droite) }
 RESIZE_HANDLE_E = 4;      { Milieu est (droite) }
 RESIZE_HANDLE_SE = 5;     { Coin sud-est (bas-droite) }
 RESIZE_HANDLE_S = 6;      { Milieu sud (bas) }
 RESIZE_HANDLE_SW = 7;     { Coin sud-ouest (bas-gauche) }
 RESIZE_HANDLE_W = 8;      { Milieu ouest (gauche) }
 
 { Constantes pour les styles de ligne }
 LINESTYLE_SOLID = 0;      { Ligne continue }
 LINESTYLE_DASHED = 1;     { Ligne tiretée }
 LINESTYLE_DOTTED = 2;     { Ligne pointillée }
 LINESTYLE_DASHDOT = 3;    { Ligne tiret-point }
 LINESTYLE_COUNT = 4;      { Nombre de styles de ligne }
 
 { Constantes pour la boîte de dialogue des propriétés }
 PROP_DIALOG_WIDTH = 250;   { Largeur de la boîte de dialogue }
 PROP_DIALOG_HEIGHT = 200;  { Hauteur de la boîte de dialogue }
 PROP_DIALOG_BG = 7;        { Gris clair - fond }
 PROP_DIALOG_BORDER = 8;    { Gris foncé - bordure }
 PROP_DIALOG_TEXT = 0;      { Noir - texte }
 PROP_DIALOG_BTN_BG = 15;   { Blanc - fond des boutons }
 PROP_DIALOG_BTN_HL = 1;    { Bleu - bouton surligné }
 PROP_COLOR_BOX_SIZE = 16;  { Taille des cases de couleur }
 PROP_MAX_COLORS = 16;      { Nombre de couleurs dans la palette }
 
 { Constantes pour la boîte de dialogue des calques }
 LAYER_DIALOG_WIDTH = 280;    { Largeur de la boîte de dialogue des calques }
 LAYER_DIALOG_HEIGHT = 250;   { Hauteur de la boîte de dialogue des calques }
 LAYER_ITEM_HEIGHT = 20;      { Hauteur d'un élément de calque }
 LAYER_NAME_LENGTH = 30;      { Longueur max du nom de calque }
 
 { Constantes pour le parsing des fichiers Visio VSD/VSDX }
 VISIO_FORMAT_UNKNOWN = 0;    { Format inconnu }
 VISIO_FORMAT_VSD = 1;        { Format VSD (OLE binaire) }
 VISIO_FORMAT_VSDX = 2;       { Format VSDX (XML compressé ZIP) }
 
 { Taille des signatures de fichier }
 VSD_SIG_SIZE = 8;
 VSDX_SIG_SIZE = 4;
 
 { Constantes pour les structures OLE }
 OLE_SECTOR_SIZE = 512;       { Taille d'un secteur OLE }
 OLE_MINI_SECTOR_SIZE = 64;   { Taille d'un mini-secteur }
 OLE_ENDOFCHAIN = $FFFFFFFE;  { Marqueur de fin de chaîne }
 OLE_FREESECT = $FFFFFFFF;    { Secteur libre }
 
 { Types de formes Visio }
 VISIO_SHAPE_RECTANGLE = 1;
 VISIO_SHAPE_ELLIPSE = 2;
 VISIO_SHAPE_LINE = 3;
 VISIO_SHAPE_POLYLINE = 4;
 VISIO_SHAPE_CONNECTOR = 5;
 VISIO_SHAPE_TEXT = 6;
 VISIO_SHAPE_GROUP = 7;

 { Noms des éléments du menu contextuel }
 ContextMenuNames: Array[1..CONTEXT_MENU_ITEM_COUNT] of String[12] = (
   'Cut', 'Copy', 'Paste', 'Delete', 'Properties'
 )
 
 { Noms des outils de la barre d'outils }
 ToolNames: Array[1..TOOLBAR_COUNT] of String[12] = (
   'Selection', 'Rectangle', 'Ellipse', 'Line', 'Connector', 'Text', 'Polygon', 'Bezier', 'Image'
 );
 
 { Noms des menus principaux }
 MenuNames: Array[1..MENU_COUNT] of String[10] = (
   'File', 'Edit', 'View', 'Insert', 'Format', 'Shape', 'Tools', 'Window', 'Help'
 );
 
 { Positions X des menus }
 MenuPositions: Array[1..MENU_COUNT] of Integer = (
   5, 50, 95, 140, 195, 260, 320, 375, 440
 );

Type
 TMenuState = (msNone, msMenuBar, msDropDown);
 TToolType = (ttSelection, ttRectangle, ttEllipse, ttLine, ttConnector, ttText, ttPolygon, ttBezier, ttImage);
 TShapeType = (stNone, stRectangle, stEllipse, stLine, stConnector, stText, stPolygon, stBezier, stImage);
 
 { Structure pour l'en-tête OLE Compound Document (format VSD) }
 TOLEHeader = Record
  Signature: Array[0..7] of Byte;      { Signature du fichier OLE }
  CLSID: Array[0..15] of Byte;         { CLSID }
  MinorVersion: Word;                   { Version mineure }
  MajorVersion: Word;                   { Version majeure }
  ByteOrder: Word;                      { Ordre des octets (0xFFFE = little-endian) }
  SectorShift: Word;                    { Puissance de 2 pour la taille du secteur }
  MiniSectorShift: Word;                { Puissance de 2 pour la taille du mini-secteur }
  Reserved: Array[0..5] of Byte;        { Réservé }
  TotalSectors: LongInt;                { Nombre total de secteurs }
  FirstDirSector: LongInt;              { Premier secteur du répertoire }
  TransactionSig: LongInt;              { Signature de transaction }
  MiniStreamCutoff: LongInt;            { Taille limite pour mini-stream (4096) }
  FirstMiniFATSector: LongInt;          { Premier secteur du mini-FAT }
  NumMiniFATSectors: LongInt;           { Nombre de secteurs mini-FAT }
  FirstDIFATSector: LongInt;            { Premier secteur DIFAT }
  NumDIFATSectors: LongInt;             { Nombre de secteurs DIFAT }
  DIFAT: Array[0..108] of LongInt;      { Table DIFAT initiale }
 End;
 
 { Structure pour une entrée du répertoire OLE }
 TOLEDirectoryEntry = Record
  EntryName: Array[0..63] of Byte;     { Nom de l'entrée (UTF-16) }
  NameLength: Word;                     { Longueur du nom en octets }
  ObjectType: Byte;                     { Type: 0=inconnu, 1=storage, 2=stream, 5=root }
  ColorFlag: Byte;                      { Couleur dans l'arbre rouge-noir }
  LeftSiblingID: LongInt;               { ID du frère gauche }
  RightSiblingID: LongInt;              { ID du frère droit }
  ChildID: LongInt;                     { ID de l'enfant }
  CLSID: Array[0..15] of Byte;          { CLSID }
  StateBits: LongInt;                   { Bits d'état }
  CreationTime: Array[0..7] of Byte;    { Date de création }
  ModifiedTime: Array[0..7] of Byte;    { Date de modification }
  StartSector: LongInt;                 { Premier secteur du stream }
  StreamSize: Array[0..7] of Byte;      { Taille du stream }
 End;
 
 { Structure pour une forme Visio importée }
 TVisioShape = Record
  ID: LongInt;                          { ID unique de la forme }
  ShapeType: Integer;                   { Type de forme Visio }
  X, Y: Real;                           { Position }
  Width, Height: Real;                  { Dimensions }
  Angle: Real;                          { Angle de rotation }
  FillColor: LongInt;                   { Couleur de remplissage }
  LineColor: LongInt;                   { Couleur de ligne }
  LineWeight: Real;                     { Épaisseur de ligne }
  Text: String[255];                    { Texte de la forme }
  ParentID: LongInt;                    { ID du parent (pour les groupes) }
 End;
 
 { Structure pour un calque }
 TLayer = Record
  Name: String[LAYER_NAME_LENGTH]; { Nom du calque }
  Visible: Boolean;                { Calque visible }
  Locked: Boolean;                 { Calque verrouillé (pas modifiable) }
  Color: Integer;                  { Couleur d'identification du calque }
 End;
 
 { Structure pour stocker les points d'un polygone ou d'une courbe de Bézier }
 TPointArray = Array[1..MAX_POLYGON_POINTS] of Record
  X, Y: Integer;
 End;
 
 { Structure pour un objet graphique }
 TShapeObject = Record
  ShapeType: TShapeType;
  X1, Y1, X2, Y2: Integer;  { Coordonnées du rectangle englobant }
  FillColor: Integer;        { Couleur de remplissage }
  LineColor: Integer;        { Couleur de contour }
  LineWidth: Integer;        { Épaisseur de ligne }
  LineStyle: Integer;        { Style de ligne (LINESTYLE_*) }
  LayerIndex: Integer;       { Index du calque auquel appartient l'objet }
  GroupID: Integer;          { ID du groupe (0 = pas dans un groupe) }
  Text: String[80];          { Texte (pour objets texte) }
  Selected: Boolean;         { Objet sélectionné }
  { Champs pour les polygones et courbes de Bézier }
  Points: TPointArray;       { Points du polygone ou de la courbe de Bézier }
  PointCount: Integer;       { Nombre de points utilisés }
  { Champ pour les images }
  ImagePath: String[255];    { Chemin vers le fichier image }
  { Champs pour les connecteurs avec points d'ancrage automatiques }
  ConnectStartShape: Integer;  { Index de la forme source (0 = pas connecté) }
  ConnectEndShape: Integer;    { Index de la forme cible (0 = pas connecté) }
  ConnectStartAnchor: Integer; { Point d'ancrage source (ANCHOR_*) }
  ConnectEndAnchor: Integer;   { Point d'ancrage cible (ANCHOR_*) }
 End;

Var
 CurrentMenu: Integer;
 MenuState: TMenuState;
 ScreenWidth, ScreenHeight: Integer;
 CurrentTool: TToolType;
 { Variables pour les objets graphiques }
 Shapes: Array[1..MAX_SHAPES] of TShapeObject;
 ShapeCount: Integer;
 SelectedShape: Integer;
 { Variables pour les calques }
 Layers: Array[1..MAX_LAYERS] of TLayer;
 { Variables pour le dessin à la souris }
 IsDrawing: Boolean;
 DrawStartX, DrawStartY: Integer;
 LastMouseX, LastMouseY: Integer;
 LastMouseButton: LongInt;
 { Variables pour le menu contextuel (clic droit) }
 ContextMenuVisible: Boolean;
 ContextMenuX, ContextMenuY: Integer;
 ContextMenuHighlight: Integer;
 { Variables pour le glisser-déposer (drag and drop) }
 DragMode: Integer;           { Mode de glissement actuel (DRAG_MODE_*) }
 DragStartX, DragStartY: Integer;  { Position de départ du glissement }
 DragOffsetX, DragOffsetY: Integer; { Décalage entre clic et coin de l'objet }
 DragResizeHandle: Integer;   { Poignée de redimensionnement en cours }
 DragOrigX1, DragOrigY1: Integer;  { Coordonnées originales de l'objet }
 DragOrigX2, DragOrigY2: Integer;
 { Variable pour le survol des poignées }
 HoveredHandle: Integer;      { Poignée actuellement survolée (RESIZE_HANDLE_*) }
 OldHoveredHandle: Integer;   { Ancienne poignée survolée (pour détection de changement) }
 { Variables pour les connecteurs et points d'ancrage }
 HoveredShapeForAnchor: Integer;  { Forme survolée pour afficher les points d'ancrage }
 NearestAnchorPoint: Integer;     { Point d'ancrage le plus proche de la souris }
 { Variables pour la boîte de dialogue des calques }
 LayerDialogVisible: Boolean;
 LayerDialogX, LayerDialogY: Integer;
 LayerDialogSelectedLayer: Integer;
 LayerDialogHighlightedButton: Integer;

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
{$ENDIF}

{ ============================================================================ }
{ === PROCEDURES DU MENU FILE === }
{ ============================================================================ }

Var
 CurrentFileName: String;
 DocumentModified: Boolean;

{ ============================================================================ }
{ === FONCTIONS DE PARSING DES FICHIERS VISIO VSD/VSDX === }
{ ============================================================================ }

{ Fonction pour détecter le format d'un fichier Visio }
Function DetectVisioFormat(Const FileName: String): Integer;
Var
 F: File;
 Buffer: Array[0..7] of Byte;
 BytesRead: Integer;
Begin
 DetectVisioFormat := VISIO_FORMAT_UNKNOWN;
 
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 { Lire les premiers octets pour identifier le format }
 BlockRead(F, Buffer, 8, BytesRead);
 Close(F);
 
 If BytesRead < 4 Then Exit;
 
 { Vérifier si c'est un fichier VSDX (ZIP) }
 If (Buffer[0] = $50) and (Buffer[1] = $4B) and 
    (Buffer[2] = $03) and (Buffer[3] = $04) Then Begin
  DetectVisioFormat := VISIO_FORMAT_VSDX;
  Exit;
 End;
 
 { Vérifier si c'est un fichier VSD (OLE Compound Document) }
 If BytesRead >= 8 Then Begin
  If (Buffer[0] = $D0) and (Buffer[1] = $CF) and
     (Buffer[2] = $11) and (Buffer[3] = $E0) and
     (Buffer[4] = $A1) and (Buffer[5] = $B6) and
     (Buffer[6] = $1A) and (Buffer[7] = $E1) Then Begin
   DetectVisioFormat := VISIO_FORMAT_VSD;
   Exit;
  End;
 End;
End;

{ Fonction pour lire l'en-tête OLE d'un fichier VSD }
Function ReadOLEHeader(Var F: File; Var Header: TOLEHeader): Boolean;
Var
 BytesRead: Integer;
Begin
 ReadOLEHeader := False;
 
 { Positionner au début du fichier }
 Seek(F, 0);
 
 { Lire l'en-tête complet (512 octets) }
 BlockRead(F, Header, SizeOf(TOLEHeader), BytesRead);
 
 If BytesRead < SizeOf(TOLEHeader) Then Exit;
 
 { Vérifier la signature OLE }
 If (Header.Signature[0] <> $D0) or (Header.Signature[1] <> $CF) or
    (Header.Signature[2] <> $11) or (Header.Signature[3] <> $E0) Then Exit;
    
 ReadOLEHeader := True;
End;

{ Fonction pour lire une entrée du répertoire OLE }
Function ReadOLEDirectoryEntry(Var F: File; SectorNum: LongInt; EntryIndex: Integer;
                                SectorSize: Integer; Var Entry: TOLEDirectoryEntry): Boolean;
Var
 Offset: LongInt;
 BytesRead: Integer;
Begin
 ReadOLEDirectoryEntry := False;
 
 { Calculer l'offset dans le fichier }
 { Les secteurs commencent après l'en-tête (512 octets) }
 Offset := (SectorNum + 1) * SectorSize + (EntryIndex * 128);
 
 { Positionner et lire l'entrée }
 {$I-}
 Seek(F, Offset);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 BlockRead(F, Entry, SizeOf(TOLEDirectoryEntry), BytesRead);
 
 If BytesRead >= 128 Then
  ReadOLEDirectoryEntry := True;
End;

{ Fonction pour extraire le nom d'une entrée OLE (UTF-16 vers ASCII) }
Function GetOLEEntryName(Const Entry: TOLEDirectoryEntry): String;
Var
 I: Integer;
 S: String;
 NameLen: Integer;
Begin
 S := '';
 NameLen := Entry.NameLength div 2 - 1; { UTF-16, moins le null terminator }
 If NameLen > 31 Then NameLen := 31;
 If NameLen < 0 Then NameLen := 0;
 
 For I := 0 to NameLen - 1 do Begin
  { Prendre le premier octet de chaque caractère UTF-16 (ASCII seulement) }
  If Entry.EntryName[I * 2] > 0 Then
   S := S + Chr(Entry.EntryName[I * 2]);
 End;
 
 GetOLEEntryName := S;
End;

{ Fonction pour convertir une couleur Visio en couleur Pascal }
Function VisioColorToPascalColor(VisioColor: LongInt): Integer;
Var
 R, G, B: Byte;
Begin
 { Les couleurs Visio sont en format BGR }
 B := (VisioColor shr 16) and $FF;
 G := (VisioColor shr 8) and $FF;
 R := VisioColor and $FF;
 
 { Mapper vers les 16 couleurs de base }
 If (R < 64) and (G < 64) and (B < 64) Then
  VisioColorToPascalColor := 0  { Noir }
 Else If (R > 192) and (G > 192) and (B > 192) Then
  VisioColorToPascalColor := 15 { Blanc }
 Else If (R > 192) and (G < 64) and (B < 64) Then
  VisioColorToPascalColor := 4  { Rouge }
 Else If (R < 64) and (G > 192) and (B < 64) Then
  VisioColorToPascalColor := 2  { Vert }
 Else If (R < 64) and (G < 64) and (B > 192) Then
  VisioColorToPascalColor := 1  { Bleu }
 Else If (R > 192) and (G > 192) and (B < 64) Then
  VisioColorToPascalColor := 14 { Jaune }
 Else If (R > 192) and (G < 64) and (B > 192) Then
  VisioColorToPascalColor := 5  { Magenta }
 Else If (R < 64) and (G > 192) and (B > 192) Then
  VisioColorToPascalColor := 3  { Cyan }
 Else
  VisioColorToPascalColor := 7; { Gris }
End;

{ Fonction pour convertir un type de forme Visio en TShapeType }
Function VisioShapeTypeToTShapeType(VisioType: Integer): TShapeType;
Begin
 Case VisioType of
  VISIO_SHAPE_RECTANGLE: VisioShapeTypeToTShapeType := stRectangle;
  VISIO_SHAPE_ELLIPSE: VisioShapeTypeToTShapeType := stEllipse;
  VISIO_SHAPE_LINE: VisioShapeTypeToTShapeType := stLine;
  VISIO_SHAPE_POLYLINE: VisioShapeTypeToTShapeType := stPolygon;
  VISIO_SHAPE_CONNECTOR: VisioShapeTypeToTShapeType := stConnector;
  VISIO_SHAPE_TEXT: VisioShapeTypeToTShapeType := stText;
 Else
  VisioShapeTypeToTShapeType := stRectangle; { Par défaut }
 End;
End;

{ Fonction pour convertir une TVisioShape en TShapeObject }
Procedure VisioShapeToShapeObject(Const VSh: TVisioShape; Var Shape: TShapeObject);
Begin
 Shape.ShapeType := VisioShapeTypeToTShapeType(VSh.ShapeType);
 Shape.X1 := Round(VSh.X);
 Shape.Y1 := Round(VSh.Y);
 Shape.X2 := Round(VSh.X + VSh.Width);
 Shape.Y2 := Round(VSh.Y + VSh.Height);
 Shape.FillColor := VisioColorToPascalColor(VSh.FillColor);
 Shape.LineColor := VisioColorToPascalColor(VSh.LineColor);
 Shape.LineWidth := Round(VSh.LineWeight);
 If Shape.LineWidth < 1 Then Shape.LineWidth := 1;
 Shape.LineStyle := LINESTYLE_SOLID;
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 If VSh.ParentID > 0 Then
  Shape.GroupID := VSh.ParentID;
 Shape.Text := VSh.Text;
 Shape.Selected := False;
 Shape.PointCount := 0;
 Shape.ImagePath := '';
 Shape.ConnectStartShape := 0;
 Shape.ConnectEndShape := 0;
 Shape.ConnectStartAnchor := ANCHOR_NONE;
 Shape.ConnectEndAnchor := ANCHOR_NONE;
End;

{ Procédure pour parser un fichier VSD (format OLE binaire) }
Function ParseVSDFile(Const FileName: String): Boolean;
Var
 F: File;
 Header: TOLEHeader;
 Entry: TOLEDirectoryEntry;
 I, EntryIndex: Integer;
 SectorSize: Integer;
 EntryName: String;
 FoundVisioContent: Boolean;
Begin
 ParseVSDFile := False;
 FoundVisioContent := False;
 
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 { Lire l'en-tête OLE }
 If Not ReadOLEHeader(F, Header) Then Begin
  Close(F);
  Exit;
 End;
 
 { Calculer la taille des secteurs }
 SectorSize := 1 shl Header.SectorShift;
 
 { Parcourir le répertoire pour trouver les streams Visio }
 EntryIndex := 0;
 While EntryIndex < 32 do Begin { Limiter à 32 entrées pour la sécurité }
  If ReadOLEDirectoryEntry(F, Header.FirstDirSector, EntryIndex, SectorSize, Entry) Then Begin
   EntryName := GetOLEEntryName(Entry);
   
   { Chercher les streams Visio connus }
   If (Pos('VisioDocument', EntryName) > 0) or
      (Pos('Contents', EntryName) > 0) or
      (Pos('Page', EntryName) > 0) Then Begin
    FoundVisioContent := True;
    { Note: L'implémentation complète du parsing des données Visio }
    { nécessiterait de lire et interpréter le format binaire Visio }
    { qui est très complexe. Cette implémentation détecte le fichier. }
   End;
  End;
  Inc(EntryIndex);
 End;
 
 Close(F);
 
 { Pour l'instant, on retourne True si on a trouvé du contenu Visio }
 { L'implémentation complète nécessiterait le parsing du format binaire Visio }
 ParseVSDFile := FoundVisioContent;
End;

{ Procédure pour parser un fichier VSDX (format XML compressé ZIP) }
Function ParseVSDXFile(Const FileName: String): Boolean;
Var
 F: File;
 Buffer: Array[0..29] of Byte;
 BytesRead: Integer;
 LocalHeaderSig: LongInt;
Begin
 ParseVSDXFile := False;
 
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 { Lire l'en-tête local du ZIP }
 BlockRead(F, Buffer, 30, BytesRead);
 Close(F);
 
 If BytesRead < 30 Then Exit;
 
 { Vérifier la signature ZIP (0x04034B50) }
 LocalHeaderSig := Buffer[0] + (Buffer[1] shl 8) + (Buffer[2] shl 16) + (Buffer[3] shl 24);
 If LocalHeaderSig <> $04034B50 Then Exit;
 
 { Le fichier VSDX est un ZIP valide contenant des fichiers XML }
 { Les fichiers importants sont: }
 { - [Content_Types].xml : Types de contenu }
 { - visio/document.xml : Document principal }
 { - visio/pages/page1.xml, page2.xml... : Pages individuelles }
 { - visio/masters/master1.xml... : Formes maîtres }
 
 { Note: L'implémentation complète nécessiterait: }
 { 1. Décompresser le ZIP }
 { 2. Parser les fichiers XML avec namespace Office }
 { 3. Extraire les formes et propriétés }
 
 { Pour cette implémentation, on valide que c'est un fichier VSDX valide }
 ParseVSDXFile := True;
End;

{ Fonction principale pour ouvrir un fichier Visio }
Function LoadVisioFile(Const FileName: String): Boolean;
Var
 FileFormat: Integer;
Begin
 LoadVisioFile := False;
 
 { Détecter le format du fichier }
 FileFormat := DetectVisioFormat(FileName);
 
 Case FileFormat of
  VISIO_FORMAT_VSD: Begin
   LoadVisioFile := ParseVSDFile(FileName);
  End;
  VISIO_FORMAT_VSDX: Begin
   LoadVisioFile := ParseVSDXFile(FileName);
  End;
 End;
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS DE PARSING VISIO === }
{ ============================================================================ }

{ Procédure New - Créer un nouveau document }
Procedure FileNew;
Begin
 CurrentFileName := '';
 DocumentModified := False;
 { TODO: Réinitialiser le canevas et les objets }
End;

{ Procédure Open - Ouvrir un fichier }
Procedure FileOpen;
Var
 FileName: String;
 FileFormat: Integer;
 Success: Boolean;
Begin
 { Pour l'instant, utiliser un nom de fichier hardcodé pour les tests }
 { Une vraie implémentation afficherait une boîte de dialogue }
 FileName := '';
 
 { Demander le nom du fichier (simplifié) }
 { TODO: Implémenter une vraie boîte de dialogue de sélection de fichier }
 
 If FileName = '' Then Begin
  { Aucun fichier sélectionné, utiliser un fichier de test }
  { En production, on afficherait une boîte de dialogue }
  Exit;
 End;
 
 { Détecter et charger le fichier }
 FileFormat := DetectVisioFormat(FileName);
 
 Case FileFormat of
  VISIO_FORMAT_VSD: Begin
   Success := ParseVSDFile(FileName);
   If Success Then Begin
    CurrentFileName := FileName;
    DocumentModified := False;
   End;
  End;
  VISIO_FORMAT_VSDX: Begin
   Success := ParseVSDXFile(FileName);
   If Success Then Begin
    CurrentFileName := FileName;
    DocumentModified := False;
   End;
  End;
 Else
  { Format inconnu }
  { TODO: Afficher un message d'erreur }
 End;
End;

{ Procédure Close - Fermer le document actuel }
Procedure FileClose;
Begin
 { TODO: Vérifier si le document a été modifié et proposer de sauvegarder }
 CurrentFileName := '';
 DocumentModified := False;
End;

{ Procédure Save - Sauvegarder le document }
Procedure FileSave;
Begin
 If CurrentFileName = '' Then Begin
  { Si pas de nom de fichier, appeler Save As }
  { FileSaveAs; }
 End
 Else Begin
  { TODO: Sauvegarder le fichier }
  DocumentModified := False;
 End;
End;

{ Procédure Save As - Sauvegarder sous un nouveau nom }
Procedure FileSaveAs;
Begin
 { TODO: Afficher une boîte de dialogue pour choisir le nom du fichier }
 { TODO: Sauvegarder le fichier }
 DocumentModified := False;
End;

{ Procédure Export - Exporter dans un autre format }
Procedure FileExport;
Begin
 { TODO: Afficher une boîte de dialogue pour choisir le format d'export }
 { TODO: Exporter le document (BMP, SVG, etc.) }
End;

{ Procédure Print - Imprimer le document }
Procedure FilePrint;
Begin
 { TODO: Afficher la boîte de dialogue d'impression }
 { TODO: Envoyer le document à l'imprimante }
End;

{ Procédure Print Preview - Aperçu avant impression }
Procedure FilePrintPreview;
Begin
 { TODO: Afficher un aperçu du document tel qu'il sera imprimé }
End;

{ Procédure Exit - Quitter l'application }
Function FileExit: Boolean;
Begin
 FileExit := True;
 { TODO: Vérifier si le document a été modifié et proposer de sauvegarder }
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DU MENU FILE === }
{ ============================================================================ }

{ ============================================================================ }
{ === PROCEDURES DU MENU EDIT === }
{ ============================================================================ }

Const
 MAX_UNDO_LEVELS = 50;

Var
 UndoStackIndex: Integer;
 CanUndo, CanRedo: Boolean;
 ClipboardEmpty: Boolean;
 HasSelection: Boolean;

{ Procédure Undo - Annuler la dernière action }
Procedure EditUndo;
Begin
 If CanUndo Then Begin
  { TODO: Restaurer l'état précédent depuis la pile d'annulation }
  { UndoStackIndex := UndoStackIndex - 1; }
  CanRedo := True;
 End;
End;

{ Procédure Redo - Rétablir l'action annulée }
Procedure EditRedo;
Begin
 If CanRedo Then Begin
  { TODO: Restaurer l'état suivant depuis la pile de rétablissement }
  { UndoStackIndex := UndoStackIndex + 1; }
 End;
End;

{ Procédure Cut - Couper la sélection }
Procedure EditCut;
Begin
 If HasSelection Then Begin
  { TODO: Copier la sélection dans le presse-papiers }
  { TODO: Supprimer la sélection du document }
  ClipboardEmpty := False;
  DocumentModified := True;
 End;
End;

{ Procédure Copy - Copier la sélection }
Procedure EditCopy;
Begin
 If HasSelection Then Begin
  { TODO: Copier la sélection dans le presse-papiers }
  ClipboardEmpty := False;
 End;
End;

{ Procédure Paste - Coller depuis le presse-papiers }
Procedure EditPaste;
Begin
 If Not ClipboardEmpty Then Begin
  { TODO: Coller le contenu du presse-papiers dans le document }
  DocumentModified := True;
 End;
End;

{ Procédure Delete - Supprimer la sélection }
Procedure EditDelete;
Begin
 If HasSelection Then Begin
  { TODO: Supprimer la sélection du document }
  DocumentModified := True;
 End;
End;

{ Procédure Select All - Sélectionner tous les objets }
Procedure EditSelectAll;
Begin
 { TODO: Sélectionner tous les objets du calque actif }
 HasSelection := True;
End;

{ Procédure Find - Rechercher du texte }
Procedure EditFind;
Begin
 { TODO: Afficher une boîte de dialogue de recherche }
 { TODO: Rechercher le texte dans les objets texte du document }
End;

{ Procédure Replace - Rechercher et remplacer du texte }
Procedure EditReplace;
Begin
 { TODO: Afficher une boîte de dialogue de recherche et remplacement }
 { TODO: Rechercher et remplacer le texte dans les objets texte }
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DU MENU EDIT === }
{ ============================================================================ }

{ ============================================================================ }
{ === PROCEDURES DU MENU VIEW === }
{ ============================================================================ }

Const
 MIN_ZOOM_LEVEL = 10;   { 10% }
 MAX_ZOOM_LEVEL = 400;  { 400% }
 DEFAULT_ZOOM = 100;    { 100% }
 ZOOM_STEP = 25;        { Pas de zoom de 25% }

Var
 ZoomLevel: Integer;
 ShowGrid: Boolean;
 ShowRulers: Boolean;
 ShowGuides: Boolean;
 SnapToGridEnabled: Boolean;

{ Procédure Zoom In - Augmenter le zoom }
Procedure ViewZoomIn;
Begin
 If ZoomLevel < MAX_ZOOM_LEVEL Then Begin
  ZoomLevel := ZoomLevel + ZOOM_STEP;
  If ZoomLevel > MAX_ZOOM_LEVEL Then
   ZoomLevel := MAX_ZOOM_LEVEL;
  { TODO: Redessiner le canevas avec le nouveau niveau de zoom }
 End;
End;

{ Procédure Zoom Out - Diminuer le zoom }
Procedure ViewZoomOut;
Begin
 If ZoomLevel > MIN_ZOOM_LEVEL Then Begin
  ZoomLevel := ZoomLevel - ZOOM_STEP;
  If ZoomLevel < MIN_ZOOM_LEVEL Then
   ZoomLevel := MIN_ZOOM_LEVEL;
  { TODO: Redessiner le canevas avec le nouveau niveau de zoom }
 End;
End;

{ Procédure Fit Page - Ajuster le zoom pour afficher la page entière }
Procedure ViewFitPage;
Begin
 { TODO: Calculer le zoom optimal pour afficher la page entière dans la vue }
 { TODO: Appliquer ce zoom et centrer la vue sur la page }
 ZoomLevel := DEFAULT_ZOOM;
End;

{ Procédure Grid - Activer/désactiver l'affichage de la grille }
Procedure ViewGrid;
Begin
 ShowGrid := Not ShowGrid;
 { TODO: Redessiner le canevas avec ou sans grille }
End;

{ Procédure Rulers - Activer/désactiver l'affichage des règles }
Procedure ViewRulers;
Begin
 ShowRulers := Not ShowRulers;
 { TODO: Redessiner l'interface avec ou sans règles }
End;

{ Procédure Guides - Activer/désactiver l'affichage des guides }
Procedure ViewGuides;
Begin
 ShowGuides := Not ShowGuides;
 { TODO: Redessiner le canevas avec ou sans guides }
End;

{ Procédure Snap to Grid - Activer/désactiver l'accrochage à la grille }
Procedure ViewSnapToGrid;
Begin
 SnapToGridEnabled := Not SnapToGridEnabled;
 { L'accrochage sera appliqué lors du déplacement des objets }
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DU MENU VIEW === }
{ ============================================================================ }

{ ============================================================================ }
{ === PROCEDURES DU MENU INSERT === }
{ ============================================================================ }

Const
 MAX_PAGES = 100;
 MAX_LAYERS = 50;
 DEFAULT_PAGE_COUNT = 1;
 DEFAULT_LAYER_COUNT = 1;

Var
 CurrentPage: Integer;
 PageCount: Integer;
 CurrentLayer: Integer;
 LayerCount: Integer;
 InsertMode: Integer;  { 0=None, 1=Shape, 2=TextBox, 3=Image, 4=Connector }

{ Procédure InsertShape - Insérer une forme }
Procedure InsertShape;
Begin
 { TODO: Afficher un dialogue pour choisir le type de forme }
 { TODO: Passer en mode dessin de forme }
 InsertMode := 1;
End;

{ Procédure InsertTextBox - Insérer une zone de texte }
Procedure InsertTextBox;
Begin
 { TODO: Passer en mode dessin de zone de texte }
 { TODO: Permettre de dessiner un rectangle pour la zone de texte }
 InsertMode := 2;
End;

{ Procédure InsertImage - Insérer une image }
Procedure InsertImage;
Begin
 { TODO: Afficher une boîte de dialogue pour sélectionner un fichier image }
 { TODO: Charger l'image et l'insérer dans le document }
 InsertMode := 3;
End;

{ Procédure InsertConnector - Insérer un connecteur }
Procedure InsertConnector;
Begin
 { TODO: Passer en mode dessin de connecteur }
 { TODO: Permettre de connecter deux formes avec des points d'ancrage }
 InsertMode := 4;
End;

{ Procédure InsertPage - Insérer une nouvelle page }
Procedure InsertPage;
Begin
 If PageCount < MAX_PAGES Then Begin
  PageCount := PageCount + 1;
  CurrentPage := PageCount;
  { TODO: Créer une nouvelle page vide dans le document }
  { TODO: Actualiser l'affichage pour montrer la nouvelle page }
  DocumentModified := True;
 End;
End;

{ Procédure InsertLayer - Insérer un nouveau calque }
Procedure InsertLayer;
Var
 LayerNum: String[5];
Begin
 If LayerCount < MAX_LAYERS Then Begin
  LayerCount := LayerCount + 1;
  CurrentLayer := LayerCount;
  { Initialiser le nouveau calque }
  Str(LayerCount, LayerNum);
  Layers[LayerCount].Name := 'Layer ' + LayerNum;
  Layers[LayerCount].Visible := True;
  Layers[LayerCount].Locked := False;
  Layers[LayerCount].Color := (LayerCount mod 15) + 1; { Couleur différente par calque }
  DocumentModified := True;
 End;
End;

{ Procédure InitLayer - Initialiser un calque }
Procedure InitLayer(LayerIdx: Integer; LayerName: String);
Begin
 If (LayerIdx >= 1) and (LayerIdx <= MAX_LAYERS) Then Begin
  Layers[LayerIdx].Name := LayerName;
  Layers[LayerIdx].Visible := True;
  Layers[LayerIdx].Locked := False;
  Layers[LayerIdx].Color := (LayerIdx mod 15) + 1;
 End;
End;

{ Procédure InitAllLayers - Initialiser tous les calques }
Procedure InitAllLayers;
Var
 I: Integer;
Begin
 For I := 1 to MAX_LAYERS do Begin
  Layers[I].Name := '';
  Layers[I].Visible := True;
  Layers[I].Locked := False;
  Layers[I].Color := 1;
 End;
 { Créer le calque par défaut }
 InitLayer(1, 'Layer 1');
 LayerCount := 1;
 CurrentLayer := 1;
End;

{ Fonction pour vérifier si un calque est visible }
Function IsLayerVisible(LayerIdx: Integer): Boolean;
Begin
 If (LayerIdx >= 1) and (LayerIdx <= LayerCount) Then
  IsLayerVisible := Layers[LayerIdx].Visible
 Else
  IsLayerVisible := False;
End;

{ Fonction pour vérifier si un calque est verrouillé }
Function IsLayerLocked(LayerIdx: Integer): Boolean;
Begin
 If (LayerIdx >= 1) and (LayerIdx <= LayerCount) Then
  IsLayerLocked := Layers[LayerIdx].Locked
 Else
  IsLayerLocked := True; { Par défaut, calque inexistant = verrouillé }
End;

{ Procédure pour changer la visibilité d'un calque }
Procedure SetLayerVisible(LayerIdx: Integer; Visible: Boolean);
Begin
 If (LayerIdx >= 1) and (LayerIdx <= LayerCount) Then Begin
  Layers[LayerIdx].Visible := Visible;
  DocumentModified := True;
 End;
End;

{ Procédure pour changer le verrouillage d'un calque }
Procedure SetLayerLocked(LayerIdx: Integer; Locked: Boolean);
Begin
 If (LayerIdx >= 1) and (LayerIdx <= LayerCount) Then Begin
  Layers[LayerIdx].Locked := Locked;
  DocumentModified := True;
 End;
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DU MENU INSERT === }
{ ============================================================================ }

{ ============================================================================ }
{ === PROCEDURES DU MENU FORMAT === }
{ ============================================================================ }

Const
 DEFAULT_FILL_COLOR = White;
 DEFAULT_LINE_COLOR = Black;
 DEFAULT_LINE_WIDTH = 1;
 DEFAULT_LINE_STYLE = LINESTYLE_SOLID;
 DEFAULT_TEXT_SIZE = 10;

Type
 TAlignmentType = (atLeft, atCenter, atRight, atTop, atMiddle, atBottom);
 TArrangeType = (arBringToFront, arSendToBack, arBringForward, arSendBackward);

Var
 CurrentFillColor: Integer;
 CurrentLineColor: Integer;
 CurrentLineWidth: Integer;
 CurrentLineStyle: Integer;
 CurrentTextSize: Integer;
 CurrentAlignment: TAlignmentType;
 ObjectsGrouped: Boolean;
 { Variables pour la gestion des groupes }
 NextGroupID: Integer;        { Prochain ID de groupe à attribuer }
 EditingGroupID: Integer;     { ID du groupe en cours d'édition (0 = aucun) }
 { Variables pour la boîte de dialogue des propriétés }
 PropertiesDialogVisible: Boolean;
 PropDialogX, PropDialogY: Integer;
 PropSelectedColor: Integer;
 PropSelectedLineWidth: Integer;
 PropSelectedLineStyle: Integer;
 PropHighlightedButton: Integer;

{ *** BOÎTE DE DIALOGUE DES PROPRIÉTÉS *** }

{ Procédure pour dessiner la palette de couleurs }
Procedure DrawColorPalette(X, Y: Integer; SelectedColor: Integer);
Var
 I, Row, Col: Integer;
 BoxX, BoxY: Integer;
Begin
 For I := 0 to PROP_MAX_COLORS - 1 do Begin
  Row := I div 8;
  Col := I mod 8;
  BoxX := X + Col * (PROP_COLOR_BOX_SIZE + 2);
  BoxY := Y + Row * (PROP_COLOR_BOX_SIZE + 2);
  
  { Dessiner la case de couleur }
  SetFillStyle(SolidFill, I);
  Bar(BoxX, BoxY, BoxX + PROP_COLOR_BOX_SIZE, BoxY + PROP_COLOR_BOX_SIZE);
  
  { Dessiner la bordure (plus épaisse si sélectionné) }
  If I = SelectedColor Then Begin
   SetColor(Black);
   Rectangle(BoxX - 1, BoxY - 1, BoxX + PROP_COLOR_BOX_SIZE + 1, BoxY + PROP_COLOR_BOX_SIZE + 1);
   Rectangle(BoxX - 2, BoxY - 2, BoxX + PROP_COLOR_BOX_SIZE + 2, BoxY + PROP_COLOR_BOX_SIZE + 2);
  End
  Else Begin
   SetColor(PROP_DIALOG_BORDER);
   Rectangle(BoxX, BoxY, BoxX + PROP_COLOR_BOX_SIZE, BoxY + PROP_COLOR_BOX_SIZE);
  End;
 End;
End;

{ Procédure pour dessiner les options de style de ligne }
Procedure DrawLineStyleOptions(X, Y: Integer; SelectedStyle: Integer);
Var
 I: Integer;
 LineY: Integer;
 StyleNames: Array[0..3] of String[12];
Begin
 StyleNames[0] := 'Solid';
 StyleNames[1] := 'Dashed';
 StyleNames[2] := 'Dotted';
 StyleNames[3] := 'Dash-Dot';
 
 For I := 0 to LINESTYLE_COUNT - 1 do Begin
  LineY := Y + I * 20;
  
  { Fond si sélectionné }
  If I = SelectedStyle Then Begin
   SetFillStyle(SolidFill, PROP_DIALOG_BTN_HL);
   Bar(X - 2, LineY - 2, X + 120, LineY + 14);
   SetColor(White);
  End
  Else Begin
   SetColor(PROP_DIALOG_TEXT);
  End;
  
  { Dessiner le nom du style }
  OutTextXY(X, LineY, StyleNames[I]);
  
  { Dessiner un échantillon de la ligne }
  Case I of
   LINESTYLE_SOLID: SetLineStyle(SolidLn, 0, 1);
   LINESTYLE_DASHED: SetLineStyle(DashedLn, 0, 1);
   LINESTYLE_DOTTED: SetLineStyle(DottedLn, 0, 1);
   LINESTYLE_DASHDOT: SetLineStyle(CenterLn, 0, 1);
  End;
  If I = SelectedStyle Then
   SetColor(White)
  Else
   SetColor(PROP_DIALOG_TEXT);
  Line(X + 80, LineY + 6, X + 115, LineY + 6);
  SetLineStyle(SolidLn, 0, 1);
 End;
End;

{ Procédure pour dessiner les options d'épaisseur de ligne }
Procedure DrawLineWidthOptions(X, Y: Integer; SelectedWidth: Integer);
Var
 I: Integer;
 LineY: Integer;
 WidthStr: String[5];
Begin
 For I := 1 to 5 do Begin
  LineY := Y + (I - 1) * 18;
  
  { Fond si sélectionné }
  If I = SelectedWidth Then Begin
   SetFillStyle(SolidFill, PROP_DIALOG_BTN_HL);
   Bar(X - 2, LineY - 2, X + 100, LineY + 14);
   SetColor(White);
  End
  Else Begin
   SetColor(PROP_DIALOG_TEXT);
  End;
  
  { Afficher l'épaisseur }
  Str(I, WidthStr);
  OutTextXY(X, LineY, WidthStr + ' px');
  
  { Dessiner un échantillon de la ligne }
  SetLineStyle(SolidLn, 0, I);
  If I = SelectedWidth Then
   SetColor(White)
  Else
   SetColor(PROP_DIALOG_TEXT);
  Line(X + 40, LineY + 6, X + 95, LineY + 6);
  SetLineStyle(SolidLn, 0, 1);
 End;
End;

{ Procédure pour dessiner la boîte de dialogue des propriétés }
Procedure DrawPropertiesDialog;
Var
 DialogX, DialogY: Integer;
 SectionY: Integer;
Begin
 { Calculer la position centrée }
 DialogX := (ScreenWidth - PROP_DIALOG_WIDTH) div 2;
 DialogY := (ScreenHeight - PROP_DIALOG_HEIGHT) div 2;
 PropDialogX := DialogX;
 PropDialogY := DialogY;
 
 { Dessiner le fond de la boîte de dialogue }
 SetFillStyle(SolidFill, PROP_DIALOG_BG);
 Bar(DialogX, DialogY, DialogX + PROP_DIALOG_WIDTH, DialogY + PROP_DIALOG_HEIGHT);
 
 { Dessiner la bordure }
 SetColor(PROP_DIALOG_BORDER);
 Rectangle(DialogX, DialogY, DialogX + PROP_DIALOG_WIDTH, DialogY + PROP_DIALOG_HEIGHT);
 Rectangle(DialogX + 1, DialogY + 1, DialogX + PROP_DIALOG_WIDTH - 1, DialogY + PROP_DIALOG_HEIGHT - 1);
 
 { Dessiner la barre de titre }
 SetFillStyle(SolidFill, Blue);
 Bar(DialogX + 2, DialogY + 2, DialogX + PROP_DIALOG_WIDTH - 2, DialogY + 20);
 SetColor(White);
 OutTextXY(DialogX + 10, DialogY + 6, 'Properties');
 
 { Section: Couleur de remplissage }
 SectionY := DialogY + 28;
 SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + 10, SectionY, 'Fill Color:');
 DrawColorPalette(DialogX + 10, SectionY + 14, PropSelectedColor);
 
 { Section: Couleur de trait }
 SectionY := SectionY + 52;
 SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + 10, SectionY, 'Line Color:');
 { Utiliser même palette pour couleur de trait }
 
 { Section: Style de ligne (à droite) }
 SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + 130, DialogY + 28, 'Line Style:');
 DrawLineStyleOptions(DialogX + 130, DialogY + 42, PropSelectedLineStyle);
 
 { Section: Épaisseur de ligne }
 OutTextXY(DialogX + 130, DialogY + 130, 'Width:');
 DrawLineWidthOptions(DialogX + 130, DialogY + 144, PropSelectedLineWidth);
 
 { Boutons OK et Cancel }
 { Bouton OK }
 If PropHighlightedButton = 1 Then
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_HL)
 Else
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_BG);
 Bar(DialogX + PROP_DIALOG_WIDTH - 120, DialogY + PROP_DIALOG_HEIGHT - 28, 
     DialogX + PROP_DIALOG_WIDTH - 65, DialogY + PROP_DIALOG_HEIGHT - 8);
 SetColor(PROP_DIALOG_BORDER);
 Rectangle(DialogX + PROP_DIALOG_WIDTH - 120, DialogY + PROP_DIALOG_HEIGHT - 28, 
           DialogX + PROP_DIALOG_WIDTH - 65, DialogY + PROP_DIALOG_HEIGHT - 8);
 If PropHighlightedButton = 1 Then
  SetColor(White)
 Else
  SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + PROP_DIALOG_WIDTH - 105, DialogY + PROP_DIALOG_HEIGHT - 24, 'OK');
 
 { Bouton Cancel }
 If PropHighlightedButton = 2 Then
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_HL)
 Else
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_BG);
 Bar(DialogX + PROP_DIALOG_WIDTH - 60, DialogY + PROP_DIALOG_HEIGHT - 28, 
     DialogX + PROP_DIALOG_WIDTH - 5, DialogY + PROP_DIALOG_HEIGHT - 8);
 SetColor(PROP_DIALOG_BORDER);
 Rectangle(DialogX + PROP_DIALOG_WIDTH - 60, DialogY + PROP_DIALOG_HEIGHT - 28, 
           DialogX + PROP_DIALOG_WIDTH - 5, DialogY + PROP_DIALOG_HEIGHT - 8);
 If PropHighlightedButton = 2 Then
  SetColor(White)
 Else
  SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + PROP_DIALOG_WIDTH - 50, DialogY + PROP_DIALOG_HEIGHT - 24, 'Cancel');
End;

{ Procédure pour afficher la boîte de dialogue des propriétés }
Procedure ShowPropertiesDialog;
Begin
 If SelectedShape < 1 Then Exit;
 
 { Initialiser avec les propriétés de l'objet sélectionné }
 PropSelectedColor := Shapes[SelectedShape].FillColor;
 PropSelectedLineWidth := Shapes[SelectedShape].LineWidth;
 PropSelectedLineStyle := Shapes[SelectedShape].LineStyle;
 PropHighlightedButton := 0;
 
 PropertiesDialogVisible := True;
End;

{ Procédure pour masquer la boîte de dialogue des propriétés }
Procedure HidePropertiesDialog;
Begin
 PropertiesDialogVisible := False;
End;

{ Fonction pour vérifier si un clic est sur la palette de couleurs et retourner l'index }
Function GetColorAtPosition(X, Y, PaletteX, PaletteY: Integer): Integer;
Var
 Col, Row, ColorIndex: Integer;
Begin
 GetColorAtPosition := -1;
 
 { Vérifier si dans la zone de la palette }
 If (X >= PaletteX) and (X < PaletteX + 8 * (PROP_COLOR_BOX_SIZE + 2)) and
    (Y >= PaletteY) and (Y < PaletteY + 2 * (PROP_COLOR_BOX_SIZE + 2)) Then Begin
  Col := (X - PaletteX) div (PROP_COLOR_BOX_SIZE + 2);
  Row := (Y - PaletteY) div (PROP_COLOR_BOX_SIZE + 2);
  ColorIndex := Row * 8 + Col;
  If (ColorIndex >= 0) and (ColorIndex < PROP_MAX_COLORS) Then
   GetColorAtPosition := ColorIndex;
 End;
End;

{ Fonction pour vérifier si un clic est sur les styles de ligne et retourner l'index }
Function GetLineStyleAtPosition(X, Y, OptionsX, OptionsY: Integer): Integer;
Var
 StyleIndex: Integer;
Begin
 GetLineStyleAtPosition := -1;
 
 { Vérifier si dans la zone des options de style }
 If (X >= OptionsX - 2) and (X < OptionsX + 120) and
    (Y >= OptionsY - 2) and (Y < OptionsY + LINESTYLE_COUNT * 20) Then Begin
  StyleIndex := (Y - OptionsY + 2) div 20;
  If (StyleIndex >= 0) and (StyleIndex < LINESTYLE_COUNT) Then
   GetLineStyleAtPosition := StyleIndex;
 End;
End;

{ Fonction pour vérifier si un clic est sur les épaisseurs de ligne et retourner la valeur }
Function GetLineWidthAtPosition(X, Y, OptionsX, OptionsY: Integer): Integer;
Var
 WidthIndex: Integer;
Begin
 GetLineWidthAtPosition := -1;
 
 { Vérifier si dans la zone des options d'épaisseur }
 If (X >= OptionsX - 2) and (X < OptionsX + 100) and
    (Y >= OptionsY - 2) and (Y < OptionsY + 5 * 18) Then Begin
  WidthIndex := (Y - OptionsY + 2) div 18;
  If (WidthIndex >= 0) and (WidthIndex < 5) Then
   GetLineWidthAtPosition := WidthIndex + 1;
 End;
End;

{ Procédure pour gérer un clic dans la boîte de dialogue des propriétés }
Procedure HandlePropertiesDialogClick(X, Y: Integer);
Var
 ColorIndex, StyleIndex, WidthIndex: Integer;
 DialogX, DialogY: Integer;
Begin
 If Not PropertiesDialogVisible Then Exit;
 
 DialogX := PropDialogX;
 DialogY := PropDialogY;
 
 { Vérifier clic sur la palette de couleurs de remplissage }
 ColorIndex := GetColorAtPosition(X, Y, DialogX + 10, DialogY + 42);
 If ColorIndex >= 0 Then Begin
  PropSelectedColor := ColorIndex;
  Exit;
 End;
 
 { Vérifier clic sur les styles de ligne }
 StyleIndex := GetLineStyleAtPosition(X, Y, DialogX + 130, DialogY + 42);
 If StyleIndex >= 0 Then Begin
  PropSelectedLineStyle := StyleIndex;
  Exit;
 End;
 
 { Vérifier clic sur les épaisseurs de ligne }
 WidthIndex := GetLineWidthAtPosition(X, Y, DialogX + 130, DialogY + 144);
 If WidthIndex >= 0 Then Begin
  PropSelectedLineWidth := WidthIndex;
  Exit;
 End;
 
 { Vérifier clic sur le bouton OK }
 If (X >= DialogX + PROP_DIALOG_WIDTH - 120) and 
    (X <= DialogX + PROP_DIALOG_WIDTH - 65) and
    (Y >= DialogY + PROP_DIALOG_HEIGHT - 28) and 
    (Y <= DialogY + PROP_DIALOG_HEIGHT - 8) Then Begin
  { Appliquer les propriétés à l'objet sélectionné }
  If SelectedShape > 0 Then Begin
   Shapes[SelectedShape].FillColor := PropSelectedColor;
   Shapes[SelectedShape].LineWidth := PropSelectedLineWidth;
   Shapes[SelectedShape].LineStyle := PropSelectedLineStyle;
   DocumentModified := True;
  End;
  HidePropertiesDialog;
  Exit;
 End;
 
 { Vérifier clic sur le bouton Cancel }
 If (X >= DialogX + PROP_DIALOG_WIDTH - 60) and 
    (X <= DialogX + PROP_DIALOG_WIDTH - 5) and
    (Y >= DialogY + PROP_DIALOG_HEIGHT - 28) and 
    (Y <= DialogY + PROP_DIALOG_HEIGHT - 8) Then Begin
  HidePropertiesDialog;
  Exit;
 End;
End;

{ Procédure pour gérer le survol dans la boîte de dialogue }
Procedure HandlePropertiesDialogHover(X, Y: Integer);
Var
 DialogX, DialogY: Integer;
 OldHighlight: Integer;
Begin
 If Not PropertiesDialogVisible Then Exit;
 
 DialogX := PropDialogX;
 DialogY := PropDialogY;
 OldHighlight := PropHighlightedButton;
 PropHighlightedButton := 0;
 
 { Vérifier survol du bouton OK }
 If (X >= DialogX + PROP_DIALOG_WIDTH - 120) and 
    (X <= DialogX + PROP_DIALOG_WIDTH - 65) and
    (Y >= DialogY + PROP_DIALOG_HEIGHT - 28) and 
    (Y <= DialogY + PROP_DIALOG_HEIGHT - 8) Then Begin
  PropHighlightedButton := 1;
 End
 { Vérifier survol du bouton Cancel }
 Else If (X >= DialogX + PROP_DIALOG_WIDTH - 60) and 
         (X <= DialogX + PROP_DIALOG_WIDTH - 5) and
         (Y >= DialogY + PROP_DIALOG_HEIGHT - 28) and 
         (Y <= DialogY + PROP_DIALOG_HEIGHT - 8) Then Begin
  PropHighlightedButton := 2;
 End;
End;

{ *** FIN BOÎTE DE DIALOGUE DES PROPRIÉTÉS *** }

{ *** BOÎTE DE DIALOGUE DES CALQUES *** }

{ Procédure pour dessiner la boîte de dialogue des calques }
Procedure DrawLayerDialog;
Var
 DialogX, DialogY: Integer;
 I, ItemY: Integer;
 VisibleStr, LockedStr: String[3];
 NameStr: String[LAYER_NAME_LENGTH];
Begin
 { Calculer la position centrée }
 DialogX := (ScreenWidth - LAYER_DIALOG_WIDTH) div 2;
 DialogY := (ScreenHeight - LAYER_DIALOG_HEIGHT) div 2;
 LayerDialogX := DialogX;
 LayerDialogY := DialogY;
 
 { Dessiner le fond de la boîte de dialogue }
 SetFillStyle(SolidFill, PROP_DIALOG_BG);
 Bar(DialogX, DialogY, DialogX + LAYER_DIALOG_WIDTH, DialogY + LAYER_DIALOG_HEIGHT);
 
 { Dessiner la bordure }
 SetColor(PROP_DIALOG_BORDER);
 Rectangle(DialogX, DialogY, DialogX + LAYER_DIALOG_WIDTH, DialogY + LAYER_DIALOG_HEIGHT);
 Rectangle(DialogX + 1, DialogY + 1, DialogX + LAYER_DIALOG_WIDTH - 1, DialogY + LAYER_DIALOG_HEIGHT - 1);
 
 { Dessiner la barre de titre }
 SetFillStyle(SolidFill, Blue);
 Bar(DialogX + 2, DialogY + 2, DialogX + LAYER_DIALOG_WIDTH - 2, DialogY + 20);
 SetColor(White);
 OutTextXY(DialogX + 10, DialogY + 6, 'Layers');
 
 { En-têtes des colonnes }
 SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + 10, DialogY + 28, 'V');   { Visible }
 OutTextXY(DialogX + 30, DialogY + 28, 'L');   { Locked }
 OutTextXY(DialogX + 50, DialogY + 28, 'Name');
 
 { Ligne de séparation }
 SetColor(PROP_DIALOG_BORDER);
 Line(DialogX + 5, DialogY + 40, DialogX + LAYER_DIALOG_WIDTH - 5, DialogY + 40);
 
 { Afficher les calques }
 For I := 1 to LayerCount do Begin
  ItemY := DialogY + 45 + (I - 1) * LAYER_ITEM_HEIGHT;
  
  { Surligner le calque sélectionné ou le calque actif }
  If I = LayerDialogSelectedLayer Then Begin
   SetFillStyle(SolidFill, PROP_DIALOG_BTN_HL);
   Bar(DialogX + 5, ItemY - 2, DialogX + LAYER_DIALOG_WIDTH - 5, ItemY + LAYER_ITEM_HEIGHT - 4);
   SetColor(White);
  End
  Else If I = CurrentLayer Then Begin
   SetFillStyle(SolidFill, LightGray);
   Bar(DialogX + 5, ItemY - 2, DialogX + LAYER_DIALOG_WIDTH - 5, ItemY + LAYER_ITEM_HEIGHT - 4);
   SetColor(PROP_DIALOG_TEXT);
  End
  Else Begin
   SetColor(PROP_DIALOG_TEXT);
  End;
  
  { Checkbox Visible }
  If Layers[I].Visible Then
   VisibleStr := '[X]'
  Else
   VisibleStr := '[ ]';
  OutTextXY(DialogX + 5, ItemY, VisibleStr);
  
  { Checkbox Locked }
  If Layers[I].Locked Then
   LockedStr := '[X]'
  Else
   LockedStr := '[ ]';
  OutTextXY(DialogX + 25, ItemY, LockedStr);
  
  { Nom du calque }
  NameStr := Layers[I].Name;
  OutTextXY(DialogX + 50, ItemY, NameStr);
  
  { Indicateur de couleur du calque }
  SetFillStyle(SolidFill, Layers[I].Color);
  Bar(DialogX + LAYER_DIALOG_WIDTH - 30, ItemY, DialogX + LAYER_DIALOG_WIDTH - 10, ItemY + 12);
  SetColor(PROP_DIALOG_BORDER);
  Rectangle(DialogX + LAYER_DIALOG_WIDTH - 30, ItemY, DialogX + LAYER_DIALOG_WIDTH - 10, ItemY + 12);
 End;
 
 { Boutons en bas }
 { Bouton New Layer }
 If LayerDialogHighlightedButton = 1 Then
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_HL)
 Else
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_BG);
 Bar(DialogX + 10, DialogY + LAYER_DIALOG_HEIGHT - 35, 
     DialogX + 70, DialogY + LAYER_DIALOG_HEIGHT - 15);
 SetColor(PROP_DIALOG_BORDER);
 Rectangle(DialogX + 10, DialogY + LAYER_DIALOG_HEIGHT - 35, 
           DialogX + 70, DialogY + LAYER_DIALOG_HEIGHT - 15);
 If LayerDialogHighlightedButton = 1 Then
  SetColor(White)
 Else
  SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + 20, DialogY + LAYER_DIALOG_HEIGHT - 31, 'New');
 
 { Bouton Set Active }
 If LayerDialogHighlightedButton = 2 Then
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_HL)
 Else
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_BG);
 Bar(DialogX + 80, DialogY + LAYER_DIALOG_HEIGHT - 35, 
     DialogX + 140, DialogY + LAYER_DIALOG_HEIGHT - 15);
 SetColor(PROP_DIALOG_BORDER);
 Rectangle(DialogX + 80, DialogY + LAYER_DIALOG_HEIGHT - 35, 
           DialogX + 140, DialogY + LAYER_DIALOG_HEIGHT - 15);
 If LayerDialogHighlightedButton = 2 Then
  SetColor(White)
 Else
  SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + 90, DialogY + LAYER_DIALOG_HEIGHT - 31, 'Active');
 
 { Bouton Close }
 If LayerDialogHighlightedButton = 3 Then
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_HL)
 Else
  SetFillStyle(SolidFill, PROP_DIALOG_BTN_BG);
 Bar(DialogX + LAYER_DIALOG_WIDTH - 70, DialogY + LAYER_DIALOG_HEIGHT - 35, 
     DialogX + LAYER_DIALOG_WIDTH - 10, DialogY + LAYER_DIALOG_HEIGHT - 15);
 SetColor(PROP_DIALOG_BORDER);
 Rectangle(DialogX + LAYER_DIALOG_WIDTH - 70, DialogY + LAYER_DIALOG_HEIGHT - 35, 
           DialogX + LAYER_DIALOG_WIDTH - 10, DialogY + LAYER_DIALOG_HEIGHT - 15);
 If LayerDialogHighlightedButton = 3 Then
  SetColor(White)
 Else
  SetColor(PROP_DIALOG_TEXT);
 OutTextXY(DialogX + LAYER_DIALOG_WIDTH - 60, DialogY + LAYER_DIALOG_HEIGHT - 31, 'Close');
End;

{ Procédure pour afficher la boîte de dialogue des calques }
Procedure ShowLayerDialog;
Begin
 LayerDialogVisible := True;
 LayerDialogSelectedLayer := CurrentLayer;
 LayerDialogHighlightedButton := 0;
End;

{ Procédure pour masquer la boîte de dialogue des calques }
Procedure HideLayerDialog;
Begin
 LayerDialogVisible := False;
End;

{ Procédure pour gérer un clic dans la boîte de dialogue des calques }
Procedure HandleLayerDialogClick(X, Y: Integer);
Var
 I, ItemY: Integer;
 DialogX, DialogY: Integer;
Begin
 If Not LayerDialogVisible Then Exit;
 
 DialogX := LayerDialogX;
 DialogY := LayerDialogY;
 
 { Vérifier clic sur les calques }
 For I := 1 to LayerCount do Begin
  ItemY := DialogY + 45 + (I - 1) * LAYER_ITEM_HEIGHT;
  
  If (Y >= ItemY - 2) and (Y < ItemY + LAYER_ITEM_HEIGHT - 4) Then Begin
   { Clic sur Visible (checkbox) }
   If (X >= DialogX + 5) and (X <= DialogX + 22) Then Begin
    Layers[I].Visible := Not Layers[I].Visible;
    DocumentModified := True;
    Exit;
   End;
   
   { Clic sur Locked (checkbox) }
   If (X >= DialogX + 25) and (X <= DialogX + 42) Then Begin
    Layers[I].Locked := Not Layers[I].Locked;
    DocumentModified := True;
    Exit;
   End;
   
   { Clic sur le nom pour sélectionner le calque }
   If (X >= DialogX + 50) and (X <= DialogX + LAYER_DIALOG_WIDTH - 10) Then Begin
    LayerDialogSelectedLayer := I;
    Exit;
   End;
  End;
 End;
 
 { Vérifier clic sur le bouton New }
 If (X >= DialogX + 10) and (X <= DialogX + 70) and
    (Y >= DialogY + LAYER_DIALOG_HEIGHT - 35) and 
    (Y <= DialogY + LAYER_DIALOG_HEIGHT - 15) Then Begin
  InsertLayer;
  LayerDialogSelectedLayer := LayerCount;
  Exit;
 End;
 
 { Vérifier clic sur le bouton Set Active }
 If (X >= DialogX + 80) and (X <= DialogX + 140) and
    (Y >= DialogY + LAYER_DIALOG_HEIGHT - 35) and 
    (Y <= DialogY + LAYER_DIALOG_HEIGHT - 15) Then Begin
  If (LayerDialogSelectedLayer >= 1) and (LayerDialogSelectedLayer <= LayerCount) Then Begin
   CurrentLayer := LayerDialogSelectedLayer;
  End;
  Exit;
 End;
 
 { Vérifier clic sur le bouton Close }
 If (X >= DialogX + LAYER_DIALOG_WIDTH - 70) and 
    (X <= DialogX + LAYER_DIALOG_WIDTH - 10) and
    (Y >= DialogY + LAYER_DIALOG_HEIGHT - 35) and 
    (Y <= DialogY + LAYER_DIALOG_HEIGHT - 15) Then Begin
  HideLayerDialog;
  Exit;
 End;
End;

{ Procédure pour gérer le survol dans la boîte de dialogue des calques }
Procedure HandleLayerDialogHover(X, Y: Integer);
Var
 DialogX, DialogY: Integer;
 OldHighlight: Integer;
Begin
 If Not LayerDialogVisible Then Exit;
 
 DialogX := LayerDialogX;
 DialogY := LayerDialogY;
 OldHighlight := LayerDialogHighlightedButton;
 LayerDialogHighlightedButton := 0;
 
 { Vérifier survol du bouton New }
 If (X >= DialogX + 10) and (X <= DialogX + 70) and
    (Y >= DialogY + LAYER_DIALOG_HEIGHT - 35) and 
    (Y <= DialogY + LAYER_DIALOG_HEIGHT - 15) Then Begin
  LayerDialogHighlightedButton := 1;
 End
 { Vérifier survol du bouton Set Active }
 Else If (X >= DialogX + 80) and (X <= DialogX + 140) and
         (Y >= DialogY + LAYER_DIALOG_HEIGHT - 35) and 
         (Y <= DialogY + LAYER_DIALOG_HEIGHT - 15) Then Begin
  LayerDialogHighlightedButton := 2;
 End
 { Vérifier survol du bouton Close }
 Else If (X >= DialogX + LAYER_DIALOG_WIDTH - 70) and 
         (X <= DialogX + LAYER_DIALOG_WIDTH - 10) and
         (Y >= DialogY + LAYER_DIALOG_HEIGHT - 35) and 
         (Y <= DialogY + LAYER_DIALOG_HEIGHT - 15) Then Begin
  LayerDialogHighlightedButton := 3;
 End;
End;

{ *** FIN BOÎTE DE DIALOGUE DES CALQUES *** }

{ Procédure FormatFill - Modifier la couleur de remplissage }
Procedure FormatFill;
Begin
 { Afficher la boîte de dialogue des propriétés pour modifier la couleur de remplissage }
 If HasSelection Then Begin
  ShowPropertiesDialog;
 End;
End;

{ Procédure FormatLine - Modifier les propriétés de ligne }
Procedure FormatLine;
Begin
 { Afficher la boîte de dialogue des propriétés pour modifier les propriétés de ligne }
 If HasSelection Then Begin
  ShowPropertiesDialog;
 End;
End;

{ Procédure FormatText - Modifier les propriétés de texte }
Procedure FormatText;
Begin
 { TODO: Afficher une boîte de dialogue pour choisir la police, taille et style de texte }
 { TODO: Appliquer les propriétés de texte aux objets texte sélectionnés }
 If HasSelection Then Begin
  DocumentModified := True;
 End;
End;

{ Procédure FormatAlignment - Modifier l'alignement des objets }
Procedure FormatAlignment;
Begin
 { TODO: Afficher un sous-menu ou dialogue pour choisir le type d'alignement }
 { TODO: Aligner les objets sélectionnés selon le type choisi }
 If HasSelection Then Begin
  DocumentModified := True;
 End;
End;

{ Procédure FormatArrange - Modifier l'ordre des objets }
Procedure FormatArrange;
Begin
 { TODO: Afficher un sous-menu pour choisir Bring to Front, Send to Back, etc. }
 { TODO: Modifier l'ordre Z des objets sélectionnés }
 If HasSelection Then Begin
  DocumentModified := True;
 End;
End;

{ Fonction pour compter le nombre d'objets sélectionnés }
Function CountSelectedShapes: Integer;
Var
 I, Count: Integer;
Begin
 Count := 0;
 For I := 1 to ShapeCount do Begin
  If Shapes[I].Selected Then
   Count := Count + 1;
 End;
 CountSelectedShapes := Count;
End;

{ Procédure FormatGroup - Grouper les objets sélectionnés }
Procedure FormatGroup;
Var
 I: Integer;
 SelectedCount: Integer;
Begin
 SelectedCount := CountSelectedShapes;
 { On a besoin d'au moins 2 objets pour créer un groupe }
 If SelectedCount >= 2 Then Begin
  { Incrémenter le compteur de groupe pour obtenir un nouvel ID }
  NextGroupID := NextGroupID + 1;
  { Assigner le même GroupID à tous les objets sélectionnés }
  For I := 1 to ShapeCount do Begin
   If Shapes[I].Selected Then Begin
    Shapes[I].GroupID := NextGroupID;
   End;
  End;
  ObjectsGrouped := True;
  DocumentModified := True;
 End;
End;

{ Procédure FormatUngroup - Dégrouper les objets }
Procedure FormatUngroup;
Var
 I: Integer;
 GroupToUngroup: Integer;
Begin
 If HasSelection Then Begin
  { Trouver le GroupID du premier objet sélectionné }
  GroupToUngroup := 0;
  For I := 1 to ShapeCount do Begin
   If Shapes[I].Selected And (Shapes[I].GroupID > 0) Then Begin
    GroupToUngroup := Shapes[I].GroupID;
    Break;
   End;
  End;
  { Si on a trouvé un groupe, dégrouper tous les objets de ce groupe }
  If GroupToUngroup > 0 Then Begin
   For I := 1 to ShapeCount do Begin
    If Shapes[I].GroupID = GroupToUngroup Then Begin
     Shapes[I].GroupID := 0;
     Shapes[I].Selected := True;  { Sélectionner tous les objets du groupe }
    End;
   End;
   ObjectsGrouped := False;
   DocumentModified := True;
  End;
 End;
End;

{ Procédure EnterGroup - Entrer dans un groupe pour éditer ses objets }
Procedure EnterGroup;
Var
 I: Integer;
Begin
 If HasSelection Then Begin
  { Trouver le GroupID du premier objet sélectionné }
  For I := 1 to ShapeCount do Begin
   If Shapes[I].Selected And (Shapes[I].GroupID > 0) Then Begin
    EditingGroupID := Shapes[I].GroupID;
    { Désélectionner tout }
    For I := 1 to ShapeCount do
     Shapes[I].Selected := False;
    Exit;
   End;
  End;
 End;
End;

{ Procédure ExitGroup - Sortir du mode édition de groupe }
Procedure ExitGroup;
Var
 I: Integer;
Begin
 If EditingGroupID > 0 Then Begin
  { Sélectionner le groupe comme un tout }
  For I := 1 to ShapeCount do Begin
   If Shapes[I].GroupID = EditingGroupID Then Begin
    Shapes[I].Selected := True;
   End;
  End;
  EditingGroupID := 0;
 End;
End;

{ Fonction pour vérifier si une forme fait partie du groupe en cours d'édition }
Function IsShapeInEditingGroup(ShapeIndex: Integer): Boolean;
Begin
 If EditingGroupID = 0 Then
  IsShapeInEditingGroup := True  { Pas en mode édition de groupe, tout est accessible }
 Else
  IsShapeInEditingGroup := Shapes[ShapeIndex].GroupID = EditingGroupID;
End;

{ Fonction pour sélectionner tout le groupe quand on clique sur un membre }
Procedure SelectGroup(GroupID: Integer);
Var
 I: Integer;
Begin
 For I := 1 to ShapeCount do Begin
  If Shapes[I].GroupID = GroupID Then Begin
   Shapes[I].Selected := True;
  End;
 End;
End;

{ Fonction pour calculer le rectangle englobant d'un groupe }
Procedure GetGroupBounds(GroupID: Integer; Var MinX, MinY, MaxX, MaxY: Integer);
Var
 I: Integer;
 First: Boolean;
Begin
 First := True;
 MinX := 0; MinY := 0; MaxX := 0; MaxY := 0;
 For I := 1 to ShapeCount do Begin
  If Shapes[I].GroupID = GroupID Then Begin
   If First Then Begin
    MinX := Shapes[I].X1;
    MinY := Shapes[I].Y1;
    MaxX := Shapes[I].X2;
    MaxY := Shapes[I].Y2;
    First := False;
   End
   Else Begin
    If Shapes[I].X1 < MinX Then MinX := Shapes[I].X1;
    If Shapes[I].Y1 < MinY Then MinY := Shapes[I].Y1;
    If Shapes[I].X2 > MaxX Then MaxX := Shapes[I].X2;
    If Shapes[I].Y2 > MaxY Then MaxY := Shapes[I].Y2;
   End;
  End;
 End;
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DU MENU FORMAT === }
{ ============================================================================ }

{ ============================================================================ }
{ === PROCEDURES DU MENU SHAPE === }
{ ============================================================================ }

Type
 TRotationType = (rtRotate90CW, rtRotate90CCW, rtRotate180, rtFreeRotate);
 TFlipType = (ftHorizontal, ftVertical);
 TAlignShapeType = (asLeft, asCenter, asRight, asTop, asMiddle, asBottom);
 TDistributeType = (dtHorizontal, dtVertical);
 TOperationType = (otUnion, otIntersect, otSubtract);

Var
 CurrentRotation: Integer;  { Angle de rotation actuel en degrés }
 ShapeWidth: Integer;       { Largeur de la forme sélectionnée }
 ShapeHeight: Integer;      { Hauteur de la forme sélectionnée }
 ShapeX: Integer;           { Position X de la forme sélectionnée }
 ShapeY: Integer;           { Position Y de la forme sélectionnée }

{ Procédure ShapeRotate - Rotation de la forme sélectionnée }
Procedure ShapeRotate;
Begin
 If HasSelection Then Begin
  { TODO: Afficher un sous-menu pour choisir l'angle de rotation }
  { TODO: Options: 90° horaire, 90° anti-horaire, 180°, rotation libre }
  CurrentRotation := (CurrentRotation + 90) Mod 360;
  DocumentModified := True;
 End;
End;

{ Procédure ShapeFlip - Retourner la forme horizontalement ou verticalement }
Procedure ShapeFlip;
Begin
 If HasSelection Then Begin
  { TODO: Afficher un sous-menu pour choisir le type de retournement }
  { TODO: Options: Horizontal, Vertical }
  DocumentModified := True;
 End;
End;

{ Procédure ShapeAlign - Aligner les formes sélectionnées }
Procedure ShapeAlign;
Begin
 If HasSelection Then Begin
  { TODO: Afficher un sous-menu pour choisir le type d'alignement }
  { TODO: Options: Left, Center, Right, Top, Middle, Bottom }
  DocumentModified := True;
 End;
End;

{ Procédure ShapeDistribute - Distribuer les formes uniformément }
Procedure ShapeDistribute;
Begin
 If HasSelection Then Begin
  { TODO: Afficher un sous-menu pour choisir la distribution }
  { TODO: Options: Horizontal, Vertical }
  { TODO: Espacer les formes uniformément entre la première et la dernière }
  DocumentModified := True;
 End;
End;

{ Procédure ShapeSize - Modifier la taille de la forme }
Procedure ShapeSize;
Begin
 If HasSelection Then Begin
  { TODO: Afficher une boîte de dialogue pour entrer la nouvelle taille }
  { TODO: Permettre de spécifier largeur et hauteur en pixels ou pourcentage }
  DocumentModified := True;
 End;
End;

{ Procédure ShapePosition - Modifier la position de la forme }
Procedure ShapePosition;
Begin
 If HasSelection Then Begin
  { TODO: Afficher une boîte de dialogue pour entrer la nouvelle position }
  { TODO: Permettre de spécifier les coordonnées X et Y }
  DocumentModified := True;
 End;
End;

{ Procédure ShapeOperations - Opérations booléennes sur les formes }
Procedure ShapeOperations;
Begin
 If HasSelection Then Begin
  { TODO: Afficher un sous-menu pour choisir l'opération }
  { TODO: Options: Union, Intersect, Subtract }
  { TODO: Union: Combiner plusieurs formes en une seule }
  { TODO: Intersect: Garder seulement la partie commune des formes }
  { TODO: Subtract: Soustraire une forme d'une autre }
  DocumentModified := True;
 End;
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DU MENU SHAPE === }
{ ============================================================================ }

{ ============================================================================ }
{ === PROCEDURES DE LA BARRE D'OUTILS === }
{ ============================================================================ }

{ Procédure pour dessiner l'icône d'un outil }
Procedure DrawToolIcon(X, Y: Integer; ToolIndex: Integer);
Var
 CenterX, CenterY: Integer;
Begin
 CenterX := X + TOOLBAR_BUTTON_SIZE div 2;
 CenterY := Y + TOOLBAR_BUTTON_SIZE div 2;
 
 SetColor(Black);
 Case ToolIndex of
  1: Begin { Selection - flèche }
      Line(CenterX - 6, CenterY - 6, CenterX - 6, CenterY + 6);
      Line(CenterX - 6, CenterY - 6, CenterX + 4, CenterY);
      Line(CenterX - 6, CenterY + 6, CenterX + 4, CenterY);
      Line(CenterX - 6, CenterY + 6, CenterX - 6, CenterY - 6);
     End;
  2: Begin { Rectangle }
      Rectangle(CenterX - 7, CenterY - 5, CenterX + 7, CenterY + 5);
     End;
  3: Begin { Ellipse }
      Ellipse(CenterX, CenterY, 0, 360, 7, 5);
     End;
  4: Begin { Line - ligne diagonale }
      Line(CenterX - 6, CenterY + 6, CenterX + 6, CenterY - 6);
     End;
  5: Begin { Connector - deux points avec ligne }
      Circle(CenterX - 6, CenterY, 2);
      Circle(CenterX + 6, CenterY, 2);
      Line(CenterX - 4, CenterY, CenterX + 4, CenterY);
     End;
  6: Begin { Text - lettre A }
      OutTextXY(CenterX - 4, CenterY - 4, 'A');
     End;
 End;
End;

{ Procédure pour dessiner un bouton de la barre d'outils }
Procedure DrawToolButton(Index: Integer; IsSelected: Boolean);
Var
 X, Y: Integer;
Begin
 { Calculer la position du bouton }
 X := TOOLBAR_PADDING + (Index - 1) * (TOOLBAR_BUTTON_SIZE + TOOLBAR_PADDING);
 Y := TOOLBAR_TOP + 1;
 
 { Dessiner le fond du bouton }
 If IsSelected Then Begin
  SetFillStyle(SolidFill, TOOLBAR_BTN_SELECTED);
 End
 Else Begin
  SetFillStyle(SolidFill, TOOLBAR_BTN_COLOR);
 End;
 Bar(X, Y, X + TOOLBAR_BUTTON_SIZE, Y + TOOLBAR_BUTTON_SIZE);
 
 { Dessiner la bordure du bouton }
 If IsSelected Then Begin
  SetColor(White);
 End
 Else Begin
  SetColor(TOOLBAR_BTN_BORDER);
 End;
 Rectangle(X, Y, X + TOOLBAR_BUTTON_SIZE, Y + TOOLBAR_BUTTON_SIZE);
 
 { Dessiner l'icône de l'outil }
 DrawToolIcon(X, Y, Index);
End;

{ Procédure pour dessiner la barre d'outils complète }
Procedure DrawToolbar;
Var
 I: Integer;
 ToolIndex: Integer;
Begin
 { Dessiner le fond de la barre d'outils }
 SetFillStyle(SolidFill, TOOLBAR_COLOR);
 Bar(0, TOOLBAR_TOP, ScreenWidth, TOOLBAR_TOP + TOOLBAR_HEIGHT);
 
 { Dessiner une ligne de séparation en bas }
 SetColor(DarkGray);
 Line(0, TOOLBAR_TOP + TOOLBAR_HEIGHT, ScreenWidth, TOOLBAR_TOP + TOOLBAR_HEIGHT);
 
 { Dessiner chaque bouton d'outil }
 For I := 1 to TOOLBAR_COUNT do Begin
  ToolIndex := Ord(CurrentTool) + 1;
  DrawToolButton(I, I = ToolIndex);
 End;
End;

{ Fonction pour obtenir l'outil à une position donnée }
Function GetToolAtPosition(MouseX, MouseY: Integer): Integer;
Var
 I, X, Y: Integer;
Begin
 GetToolAtPosition := 0;
 
 { Vérifier si la souris est dans la zone de la barre d'outils }
 If (MouseY < TOOLBAR_TOP) or (MouseY > TOOLBAR_TOP + TOOLBAR_HEIGHT) Then Exit;
 
 { Parcourir chaque bouton pour voir si la souris est dessus }
 For I := 1 to TOOLBAR_COUNT do Begin
  X := TOOLBAR_PADDING + (I - 1) * (TOOLBAR_BUTTON_SIZE + TOOLBAR_PADDING);
  Y := TOOLBAR_TOP + 1;
  
  If (MouseX >= X) and (MouseX <= X + TOOLBAR_BUTTON_SIZE) and
     (MouseY >= Y) and (MouseY <= Y + TOOLBAR_BUTTON_SIZE) Then Begin
   GetToolAtPosition := I;
   Exit;
  End;
 End;
End;

{ Procédure pour sélectionner un outil }
Procedure SelectTool(ToolIndex: Integer);
Begin
 If (ToolIndex >= 1) and (ToolIndex <= TOOLBAR_COUNT) Then Begin
  CurrentTool := TToolType(ToolIndex - 1);
 End;
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DE LA BARRE D'OUTILS === }
{ ============================================================================ }

{ ============================================================================ }
{ === PROCEDURES DE GESTION DES OBJETS ET CLIC SOURIS === }
{ ============================================================================ }

{ Procédure pour initialiser un objet vide }
Procedure InitShape(Var Shape: TShapeObject);
Var
 I: Integer;
Begin
 Shape.ShapeType := stNone;
 Shape.X1 := 0;
 Shape.Y1 := 0;
 Shape.X2 := 0;
 Shape.Y2 := 0;
 Shape.FillColor := White;
 Shape.LineColor := Black;
 Shape.LineWidth := 1;
 Shape.LineStyle := LINESTYLE_SOLID;
 Shape.LayerIndex := CurrentLayer;  { Assigner au calque actif }
 Shape.GroupID := 0;                { Pas dans un groupe par défaut }
 Shape.Text := '';
 Shape.Selected := False;
 { Initialiser les champs pour polygones et courbes de Bézier }
 Shape.PointCount := 0;
 For I := 1 to MAX_POLYGON_POINTS do Begin
  Shape.Points[I].X := 0;
  Shape.Points[I].Y := 0;
 End;
 { Initialiser le chemin d'image }
 Shape.ImagePath := '';
 { Initialiser les champs de connexion pour les connecteurs }
 Shape.ConnectStartShape := 0;
 Shape.ConnectEndShape := 0;
 Shape.ConnectStartAnchor := ANCHOR_NONE;
 Shape.ConnectEndAnchor := ANCHOR_NONE;
End;

{ *** FONCTIONS POUR LES CONNECTEURS ET POINTS D'ANCRAGE *** }

{ Fonction pour calculer les coordonnées d'un point d'ancrage sur une forme }
Procedure GetAnchorPoint(ShapeIndex: Integer; AnchorType: Integer; Var AX, AY: Integer);
Var
 CenterX, CenterY: Integer;
Begin
 If (ShapeIndex < 1) or (ShapeIndex > ShapeCount) Then Begin
  AX := 0;
  AY := 0;
  Exit;
 End;
 
 With Shapes[ShapeIndex] do Begin
  CenterX := (X1 + X2) div 2;
  CenterY := (Y1 + Y2) div 2;
  
  Case AnchorType of
   ANCHOR_TOP: Begin
    AX := CenterX;
    AY := Y1;
   End;
   ANCHOR_BOTTOM: Begin
    AX := CenterX;
    AY := Y2;
   End;
   ANCHOR_LEFT: Begin
    AX := X1;
    AY := CenterY;
   End;
   ANCHOR_RIGHT: Begin
    AX := X2;
    AY := CenterY;
   End;
   ANCHOR_CENTER: Begin
    AX := CenterX;
    AY := CenterY;
   End;
   Else Begin
    AX := CenterX;
    AY := CenterY;
   End;
  End;
 End;
End;

{ Fonction pour trouver la forme et le point d'ancrage le plus proche d'une position }
Function FindNearestAnchor(X, Y: Integer; Var FoundShape: Integer; Var FoundAnchor: Integer): Boolean;
Var
 I, AnchorType: Integer;
 AX, AY: Integer;
 Dist, MinDist: Real;
 IsConnectable: Boolean;
Begin
 FindNearestAnchor := False;
 FoundShape := 0;
 FoundAnchor := ANCHOR_NONE;
 MinDist := ANCHOR_SNAP_DISTANCE + 1;
 
 For I := 1 to ShapeCount do Begin
  { Ne pas se connecter à soi-même ou à d'autres connecteurs }
  IsConnectable := (Shapes[I].ShapeType <> stConnector) and
                   (Shapes[I].ShapeType <> stLine) and
                   (Shapes[I].ShapeType <> stText) and
                   (Shapes[I].ShapeType <> stNone);
  
  If IsConnectable Then Begin
   For AnchorType := ANCHOR_TOP to ANCHOR_RIGHT do Begin
    GetAnchorPoint(I, AnchorType, AX, AY);
    Dist := Sqrt(Sqr(X - AX) + Sqr(Y - AY));
    If Dist < MinDist Then Begin
     MinDist := Dist;
     FoundShape := I;
     FoundAnchor := AnchorType;
     FindNearestAnchor := True;
    End;
   End;
  End;
 End;
End;

{ Procédure pour mettre à jour les extrémités d'un connecteur selon ses connexions }
Procedure UpdateConnectorEndpoints(ConnectorIndex: Integer);
Var
 AX, AY: Integer;
Begin
 If (ConnectorIndex < 1) or (ConnectorIndex > ShapeCount) Then Exit;
 If Shapes[ConnectorIndex].ShapeType <> stConnector Then Exit;
 
 With Shapes[ConnectorIndex] do Begin
  { Mettre à jour le point de départ si connecté }
  If ConnectStartShape > 0 Then Begin
   GetAnchorPoint(ConnectStartShape, ConnectStartAnchor, AX, AY);
   X1 := AX;
   Y1 := AY;
  End;
  
  { Mettre à jour le point d'arrivée si connecté }
  If ConnectEndShape > 0 Then Begin
   GetAnchorPoint(ConnectEndShape, ConnectEndAnchor, AX, AY);
   X2 := AX;
   Y2 := AY;
  End;
 End;
End;

{ Procédure pour mettre à jour tous les connecteurs (après déplacement d'une forme) }
Procedure UpdateAllConnectors;
Var
 I: Integer;
Begin
 For I := 1 to ShapeCount do Begin
  If Shapes[I].ShapeType = stConnector Then Begin
   UpdateConnectorEndpoints(I);
  End;
 End;
End;

{ Procédure pour dessiner les points d'ancrage sur une forme }
Procedure DrawAnchorPoints(ShapeIndex: Integer; HighlightAnchor: Integer);
Var
 AnchorType: Integer;
 AX, AY: Integer;
 HalfSize: Integer;
 AnchorColor: Integer;
Begin
 If (ShapeIndex < 1) or (ShapeIndex > ShapeCount) Then Exit;
 
 { Ne pas dessiner les ancres sur les connecteurs, lignes ou textes }
 If Shapes[ShapeIndex].ShapeType in [stConnector, stLine, stText, stNone] Then Exit;
 
 HalfSize := ANCHOR_POINT_SIZE div 2;
 
 For AnchorType := ANCHOR_TOP to ANCHOR_RIGHT do Begin
  GetAnchorPoint(ShapeIndex, AnchorType, AX, AY);
  
  { Choisir la couleur selon si le point est survolé }
  If AnchorType = HighlightAnchor Then
   AnchorColor := Green  { Vert pour le point survolé }
  Else
   AnchorColor := Cyan;  { Cyan pour les autres points }
  
  { Dessiner un petit carré pour le point d'ancrage }
  SetFillStyle(SolidFill, AnchorColor);
  SetColor(Black);
  Bar(AX - HalfSize, AY - HalfSize, AX + HalfSize, AY + HalfSize);
  Rectangle(AX - HalfSize, AY - HalfSize, AX + HalfSize, AY + HalfSize);
 End;
End;

{ Procédure pour dessiner une poignée de redimensionnement unique }
Procedure DrawSingleHandle(X, Y: Integer; HandleNum: Integer);
Var
 HalfSize: Integer;
 HandleColor: Integer;
Begin
 HalfSize := SELECTION_HANDLE_SIZE div 2;
 
 { Choisir la couleur selon si la poignée est survolée }
 If HandleNum = HoveredHandle Then
  HandleColor := HANDLE_HOVER_COLOR
 Else
  HandleColor := HANDLE_NORMAL_COLOR;
 
 { Dessiner la poignée }
 SetFillStyle(SolidFill, HandleColor);
 SetColor(HANDLE_BORDER_COLOR);
 Bar(X - HalfSize, Y - HalfSize, X + HalfSize, Y + HalfSize);
 Rectangle(X - HalfSize, Y - HalfSize, X + HalfSize, Y + HalfSize);
End;

{ Procédure pour dessiner les 8 poignées de redimensionnement sur un objet sélectionné }
Procedure DrawResizeHandles(Var Shape: TShapeObject);
Var
 CenterX, CenterY: Integer;
Begin
 If Not Shape.Selected Then Exit;
 
 CenterX := (Shape.X1 + Shape.X2) div 2;
 CenterY := (Shape.Y1 + Shape.Y2) div 2;
 
 { Dessiner les 8 poignées de redimensionnement }
 { Coin nord-ouest (haut-gauche) }
 DrawSingleHandle(Shape.X1, Shape.Y1, RESIZE_HANDLE_NW);
 
 { Milieu nord (haut) }
 DrawSingleHandle(CenterX, Shape.Y1, RESIZE_HANDLE_N);
 
 { Coin nord-est (haut-droite) }
 DrawSingleHandle(Shape.X2, Shape.Y1, RESIZE_HANDLE_NE);
 
 { Milieu est (droite) }
 DrawSingleHandle(Shape.X2, CenterY, RESIZE_HANDLE_E);
 
 { Coin sud-est (bas-droite) }
 DrawSingleHandle(Shape.X2, Shape.Y2, RESIZE_HANDLE_SE);
 
 { Milieu sud (bas) }
 DrawSingleHandle(CenterX, Shape.Y2, RESIZE_HANDLE_S);
 
 { Coin sud-ouest (bas-gauche) }
 DrawSingleHandle(Shape.X1, Shape.Y2, RESIZE_HANDLE_SW);
 
 { Milieu ouest (gauche) }
 DrawSingleHandle(Shape.X1, CenterY, RESIZE_HANDLE_W);
End;

{ Procédure pour dessiner un objet unique }
Procedure DrawShape(Var Shape: TShapeObject);
Var
 CenterX, CenterY, RadiusX, RadiusY: Integer;
 I: Integer;
 T, OneMinusT: Real;
 BezierX, BezierY, PrevX, PrevY: Integer;
 GraphLineStyle: Integer;
Begin
 If Shape.ShapeType = stNone Then Exit;
 
 { Convertir le style de ligne en constante Graph }
 Case Shape.LineStyle of
  LINESTYLE_SOLID: GraphLineStyle := SolidLn;
  LINESTYLE_DASHED: GraphLineStyle := DashedLn;
  LINESTYLE_DOTTED: GraphLineStyle := DottedLn;
  LINESTYLE_DASHDOT: GraphLineStyle := CenterLn;
  Else GraphLineStyle := SolidLn;
 End;
 
 { Définir la couleur de contour et le style de ligne }
 SetColor(Shape.LineColor);
 SetLineStyle(GraphLineStyle, 0, Shape.LineWidth);
 
 Case Shape.ShapeType of
  stRectangle: Begin
    { Remplir le rectangle }
    SetFillStyle(SolidFill, Shape.FillColor);
    Bar(Shape.X1, Shape.Y1, Shape.X2, Shape.Y2);
    { Dessiner le contour }
    SetColor(Shape.LineColor);
    Rectangle(Shape.X1, Shape.Y1, Shape.X2, Shape.Y2);
   End;
  stEllipse: Begin
    CenterX := (Shape.X1 + Shape.X2) div 2;
    CenterY := (Shape.Y1 + Shape.Y2) div 2;
    RadiusX := Abs(Shape.X2 - Shape.X1) div 2;
    RadiusY := Abs(Shape.Y2 - Shape.Y1) div 2;
    { Remplir l'ellipse }
    SetFillStyle(SolidFill, Shape.FillColor);
    FillEllipse(CenterX, CenterY, RadiusX, RadiusY);
    { Dessiner le contour }
    SetColor(Shape.LineColor);
    Ellipse(CenterX, CenterY, 0, 360, RadiusX, RadiusY);
   End;
  stLine: Begin
    SetColor(Shape.LineColor);
    Line(Shape.X1, Shape.Y1, Shape.X2, Shape.Y2);
   End;
  stConnector: Begin
    { Dessiner une ligne avec des cercles aux extrémités }
    SetColor(Shape.LineColor);
    Line(Shape.X1, Shape.Y1, Shape.X2, Shape.Y2);
    
    { Dessiner le point de départ }
    If Shape.ConnectStartShape > 0 Then Begin
     { Connecté - dessiner un carré plein }
     SetFillStyle(SolidFill, Green);
     Bar(Shape.X1 - 4, Shape.Y1 - 4, Shape.X1 + 4, Shape.Y1 + 4);
     SetColor(Shape.LineColor);
     Rectangle(Shape.X1 - 4, Shape.Y1 - 4, Shape.X1 + 4, Shape.Y1 + 4);
    End
    Else Begin
     { Non connecté - dessiner un cercle }
     SetFillStyle(SolidFill, Shape.FillColor);
     FillEllipse(Shape.X1, Shape.Y1, 4, 4);
     SetColor(Shape.LineColor);
     Circle(Shape.X1, Shape.Y1, 4);
    End;
    
    { Dessiner le point d'arrivée }
    If Shape.ConnectEndShape > 0 Then Begin
     { Connecté - dessiner un carré plein }
     SetFillStyle(SolidFill, Green);
     Bar(Shape.X2 - 4, Shape.Y2 - 4, Shape.X2 + 4, Shape.Y2 + 4);
     SetColor(Shape.LineColor);
     Rectangle(Shape.X2 - 4, Shape.Y2 - 4, Shape.X2 + 4, Shape.Y2 + 4);
    End
    Else Begin
     { Non connecté - dessiner un cercle }
     SetFillStyle(SolidFill, Shape.FillColor);
     FillEllipse(Shape.X2, Shape.Y2, 4, 4);
     SetColor(Shape.LineColor);
     Circle(Shape.X2, Shape.Y2, 4);
    End;
   End;
  stText: Begin
    SetColor(Shape.LineColor);
    OutTextXY(Shape.X1, Shape.Y1, Shape.Text);
   End;
  stPolygon: Begin
    { Dessiner un polygone si au moins 3 points sont définis }
    If Shape.PointCount >= 3 Then Begin
     { Remplir le polygone en dessinant des lignes de remplissage }
     SetFillStyle(SolidFill, Shape.FillColor);
     { Dessiner le contour du polygone }
     SetColor(Shape.LineColor);
     For I := 1 to Shape.PointCount - 1 do Begin
      Line(Shape.Points[I].X, Shape.Points[I].Y, 
           Shape.Points[I + 1].X, Shape.Points[I + 1].Y);
     End;
     { Fermer le polygone }
     Line(Shape.Points[Shape.PointCount].X, Shape.Points[Shape.PointCount].Y,
          Shape.Points[1].X, Shape.Points[1].Y);
    End;
   End;
  stBezier: Begin
    { Dessiner une courbe de Bézier cubique (4 points de contrôle) }
    If Shape.PointCount = 4 Then Begin
     SetColor(Shape.LineColor);
     { Dessiner la courbe de Bézier par approximation avec des segments de ligne }
     { P0 = Points[1], P1 = Points[2], P2 = Points[3], P3 = Points[4] }
     { Formule: B(t) = (1-t)^3*P0 + 3*(1-t)^2*t*P1 + 3*(1-t)*t^2*P2 + t^3*P3 }
     PrevX := Shape.Points[1].X;
     PrevY := Shape.Points[1].Y;
     For I := 1 to 20 do Begin
      T := I / 20;
      OneMinusT := 1 - T;
      { Calcul de la position sur la courbe }
      BezierX := Round(
       OneMinusT * OneMinusT * OneMinusT * Shape.Points[1].X +
       3 * OneMinusT * OneMinusT * T * Shape.Points[2].X +
       3 * OneMinusT * T * T * Shape.Points[3].X +
       T * T * T * Shape.Points[4].X
      );
      BezierY := Round(
       OneMinusT * OneMinusT * OneMinusT * Shape.Points[1].Y +
       3 * OneMinusT * OneMinusT * T * Shape.Points[2].Y +
       3 * OneMinusT * T * T * Shape.Points[3].Y +
       T * T * T * Shape.Points[4].Y
      );
      Line(PrevX, PrevY, BezierX, BezierY);
      PrevX := BezierX;
      PrevY := BezierY;
     End;
     { Dessiner les points de contrôle si sélectionné }
     If Shape.Selected Then Begin
      SetColor(LightGray);
      Line(Shape.Points[1].X, Shape.Points[1].Y, Shape.Points[2].X, Shape.Points[2].Y);
      Line(Shape.Points[3].X, Shape.Points[3].Y, Shape.Points[4].X, Shape.Points[4].Y);
      SetFillStyle(SolidFill, Yellow);
      For I := 1 to 4 do Begin
       FillEllipse(Shape.Points[I].X, Shape.Points[I].Y, 3, 3);
      End;
     End;
    End;
   End;
  stImage: Begin
    { Dessiner un placeholder pour l'image (rectangle avec X) }
    SetFillStyle(SolidFill, Shape.FillColor);
    Bar(Shape.X1, Shape.Y1, Shape.X2, Shape.Y2);
    SetColor(Shape.LineColor);
    Rectangle(Shape.X1, Shape.Y1, Shape.X2, Shape.Y2);
    { Dessiner un X pour indiquer que c'est un placeholder d'image }
    Line(Shape.X1, Shape.Y1, Shape.X2, Shape.Y2);
    Line(Shape.X2, Shape.Y1, Shape.X1, Shape.Y2);
    { Afficher "Image" au centre }
    CenterX := (Shape.X1 + Shape.X2) div 2 - 20;
    CenterY := (Shape.Y1 + Shape.Y2) div 2 - 4;
    OutTextXY(CenterX, CenterY, 'Image');
   End;
 End;
 
 { Dessiner les 8 poignées de redimensionnement si l'objet est sélectionné }
 DrawResizeHandles(Shape);
End;

{ Procédure pour dessiner tous les objets }
Procedure DrawAllShapes;
Var
 I: Integer;
Begin
 For I := 1 to ShapeCount do Begin
  { Ne dessiner que les formes des calques visibles }
  If IsLayerVisible(Shapes[I].LayerIndex) Then Begin
   DrawShape(Shapes[I]);
  End;
 End;
 
 { Dessiner les points d'ancrage sur la forme survolée si on utilise l'outil connecteur }
 If (CurrentTool = ttConnector) and (HoveredShapeForAnchor > 0) Then Begin
  DrawAnchorPoints(HoveredShapeForAnchor, NearestAnchorPoint);
 End;
End;

{ Fonction pour vérifier si un point est dans un objet }
Function PointInShape(X, Y: Integer; Var Shape: TShapeObject): Boolean;
Var
 MinX, MinY, MaxX, MaxY: Integer;
Begin
 PointInShape := False;
 If Shape.ShapeType = stNone Then Exit;
 
 { Normaliser les coordonnées }
 If Shape.X1 < Shape.X2 Then Begin
  MinX := Shape.X1;
  MaxX := Shape.X2;
 End
 Else Begin
  MinX := Shape.X2;
  MaxX := Shape.X1;
 End;
 
 If Shape.Y1 < Shape.Y2 Then Begin
  MinY := Shape.Y1;
  MaxY := Shape.Y2;
 End
 Else Begin
  MinY := Shape.Y2;
  MaxY := Shape.Y1;
 End;
 
 { Vérifier si le point est dans le rectangle englobant }
 PointInShape := (X >= MinX) and (X <= MaxX) and (Y >= MinY) and (Y <= MaxY);
End;

{ Fonction pour trouver l'objet à une position donnée }
Function GetShapeAtPosition(X, Y: Integer): Integer;
Var
 I: Integer;
Begin
 GetShapeAtPosition := 0;
 { Parcourir les objets du dernier au premier (priorité aux objets dessus) }
 For I := ShapeCount downto 1 do Begin
  { Ne sélectionner que les formes des calques visibles et non verrouillés }
  If IsLayerVisible(Shapes[I].LayerIndex) and 
     (Not IsLayerLocked(Shapes[I].LayerIndex)) Then Begin
   { Si on est en mode édition de groupe, ne sélectionner que les objets du groupe }
   If IsShapeInEditingGroup(I) Then Begin
    If PointInShape(X, Y, Shapes[I]) Then Begin
     GetShapeAtPosition := I;
     Exit;
    End;
   End;
  End;
 End;
End;

{ Procédure pour désélectionner tous les objets }
Procedure DeselectAllShapes;
Var
 I: Integer;
Begin
 For I := 1 to ShapeCount do Begin
  Shapes[I].Selected := False;
 End;
 SelectedShape := 0;
End;

{ Procédure pour sélectionner un objet }
Procedure SelectShape(Index: Integer);
Begin
 DeselectAllShapes;
 If (Index >= 1) and (Index <= ShapeCount) Then Begin
  { Si pas en mode édition de groupe et que l'objet fait partie d'un groupe, sélectionner tout le groupe }
  If (EditingGroupID = 0) and (Shapes[Index].GroupID > 0) Then Begin
   SelectGroup(Shapes[Index].GroupID);
   SelectedShape := Index;
  End
  Else Begin
   Shapes[Index].Selected := True;
   SelectedShape := Index;
  End;
 End;
End;

{ ============================================================================ }
{ === PROCEDURES POUR LE GLISSER-DEPOSER (DRAG AND DROP) === }
{ ============================================================================ }

{ Fonction pour détecter quelle poignée de redimensionnement est sous le curseur }
Function GetResizeHandle(X, Y: Integer; ShapeIndex: Integer): Integer;
Var
 X1, Y1, X2, Y2: Integer;
 CenterX, CenterY: Integer;
 HalfSize: Integer;
Begin
 GetResizeHandle := RESIZE_HANDLE_NONE;
 
 If (ShapeIndex < 1) or (ShapeIndex > ShapeCount) Then Exit;
 If Not Shapes[ShapeIndex].Selected Then Exit;
 
 X1 := Shapes[ShapeIndex].X1;
 Y1 := Shapes[ShapeIndex].Y1;
 X2 := Shapes[ShapeIndex].X2;
 Y2 := Shapes[ShapeIndex].Y2;
 CenterX := (X1 + X2) div 2;
 CenterY := (Y1 + Y2) div 2;
 HalfSize := RESIZE_HANDLE_SIZE div 2;
 
 { Vérifier chaque poignée }
 { Coin nord-ouest (haut-gauche) }
 If (Abs(X - X1) <= HalfSize) and (Abs(Y - Y1) <= HalfSize) Then Begin
  GetResizeHandle := RESIZE_HANDLE_NW;
  Exit;
 End;
 
 { Milieu nord (haut) }
 If (Abs(X - CenterX) <= HalfSize) and (Abs(Y - Y1) <= HalfSize) Then Begin
  GetResizeHandle := RESIZE_HANDLE_N;
  Exit;
 End;
 
 { Coin nord-est (haut-droite) }
 If (Abs(X - X2) <= HalfSize) and (Abs(Y - Y1) <= HalfSize) Then Begin
  GetResizeHandle := RESIZE_HANDLE_NE;
  Exit;
 End;
 
 { Milieu est (droite) }
 If (Abs(X - X2) <= HalfSize) and (Abs(Y - CenterY) <= HalfSize) Then Begin
  GetResizeHandle := RESIZE_HANDLE_E;
  Exit;
 End;
 
 { Coin sud-est (bas-droite) }
 If (Abs(X - X2) <= HalfSize) and (Abs(Y - Y2) <= HalfSize) Then Begin
  GetResizeHandle := RESIZE_HANDLE_SE;
  Exit;
 End;
 
 { Milieu sud (bas) }
 If (Abs(X - CenterX) <= HalfSize) and (Abs(Y - Y2) <= HalfSize) Then Begin
  GetResizeHandle := RESIZE_HANDLE_S;
  Exit;
 End;
 
 { Coin sud-ouest (bas-gauche) }
 If (Abs(X - X1) <= HalfSize) and (Abs(Y - Y2) <= HalfSize) Then Begin
  GetResizeHandle := RESIZE_HANDLE_SW;
  Exit;
 End;
 
 { Milieu ouest (gauche) }
 If (Abs(X - X1) <= HalfSize) and (Abs(Y - CenterY) <= HalfSize) Then Begin
  GetResizeHandle := RESIZE_HANDLE_W;
  Exit;
 End;
End;

{ Procédure pour déplacer un objet }
Procedure MoveShape(ShapeIndex: Integer; DeltaX, DeltaY: Integer);
Begin
 If (ShapeIndex < 1) or (ShapeIndex > ShapeCount) Then Exit;
 
 Shapes[ShapeIndex].X1 := Shapes[ShapeIndex].X1 + DeltaX;
 Shapes[ShapeIndex].Y1 := Shapes[ShapeIndex].Y1 + DeltaY;
 Shapes[ShapeIndex].X2 := Shapes[ShapeIndex].X2 + DeltaX;
 Shapes[ShapeIndex].Y2 := Shapes[ShapeIndex].Y2 + DeltaY;
 
 DocumentModified := True;
End;

{ Procédure pour redimensionner un objet selon la poignée }
Procedure ResizeShape(ShapeIndex: Integer; Handle: Integer; NewX, NewY: Integer);
Begin
 If (ShapeIndex < 1) or (ShapeIndex > ShapeCount) Then Exit;
 
 Case Handle of
  RESIZE_HANDLE_NW: Begin
   Shapes[ShapeIndex].X1 := NewX;
   Shapes[ShapeIndex].Y1 := NewY;
  End;
  RESIZE_HANDLE_N: Begin
   Shapes[ShapeIndex].Y1 := NewY;
  End;
  RESIZE_HANDLE_NE: Begin
   Shapes[ShapeIndex].X2 := NewX;
   Shapes[ShapeIndex].Y1 := NewY;
  End;
  RESIZE_HANDLE_E: Begin
   Shapes[ShapeIndex].X2 := NewX;
  End;
  RESIZE_HANDLE_SE: Begin
   Shapes[ShapeIndex].X2 := NewX;
   Shapes[ShapeIndex].Y2 := NewY;
  End;
  RESIZE_HANDLE_S: Begin
   Shapes[ShapeIndex].Y2 := NewY;
  End;
  RESIZE_HANDLE_SW: Begin
   Shapes[ShapeIndex].X1 := NewX;
   Shapes[ShapeIndex].Y2 := NewY;
  End;
  RESIZE_HANDLE_W: Begin
   Shapes[ShapeIndex].X1 := NewX;
  End;
 End;
 
 DocumentModified := True;
End;

{ Procédure pour démarrer le glissement }
Procedure StartDrag(ShapeIndex: Integer; X, Y: Integer; Handle: Integer);
Begin
 If (ShapeIndex < 1) or (ShapeIndex > ShapeCount) Then Exit;
 
 DragStartX := X;
 DragStartY := Y;
 DragOrigX1 := Shapes[ShapeIndex].X1;
 DragOrigY1 := Shapes[ShapeIndex].Y1;
 DragOrigX2 := Shapes[ShapeIndex].X2;
 DragOrigY2 := Shapes[ShapeIndex].Y2;
 
 If Handle <> RESIZE_HANDLE_NONE Then Begin
  { Démarrer le redimensionnement }
  DragMode := DRAG_MODE_RESIZE;
  DragResizeHandle := Handle;
 End
 Else Begin
  { Démarrer le déplacement }
  DragMode := DRAG_MODE_MOVE;
  DragOffsetX := X - Shapes[ShapeIndex].X1;
  DragOffsetY := Y - Shapes[ShapeIndex].Y1;
  DragResizeHandle := RESIZE_HANDLE_NONE;
 End;
End;

{ Procédure pour traiter le mouvement de la souris pendant le drag }
Procedure HandleMouseMove(X, Y: Integer);
Var
 DeltaX, DeltaY: Integer;
Begin
 If DragMode = DRAG_MODE_NONE Then Exit;
 If SelectedShape < 1 Then Exit;
 
 If DragMode = DRAG_MODE_MOVE Then Begin
  { Déplacer l'objet }
  DeltaX := X - DragStartX;
  DeltaY := Y - DragStartY;
  
  { Restaurer position originale puis appliquer le déplacement }
  Shapes[SelectedShape].X1 := DragOrigX1 + DeltaX;
  Shapes[SelectedShape].Y1 := DragOrigY1 + DeltaY;
  Shapes[SelectedShape].X2 := DragOrigX2 + DeltaX;
  Shapes[SelectedShape].Y2 := DragOrigY2 + DeltaY;
 End
 Else If DragMode = DRAG_MODE_RESIZE Then Begin
  { Redimensionner l'objet }
  ResizeShape(SelectedShape, DragResizeHandle, X, Y);
 End;
End;

{ Procédure pour terminer le glissement }
Procedure EndDrag;
Begin
 If DragMode <> DRAG_MODE_NONE Then Begin
  DocumentModified := True;
 End;
 DragMode := DRAG_MODE_NONE;
 DragResizeHandle := RESIZE_HANDLE_NONE;
End;

{ Procédure pour initialiser le glisser-déposer }
Procedure InitDragDrop;
Begin
 DragMode := DRAG_MODE_NONE;
 DragStartX := 0;
 DragStartY := 0;
 DragOffsetX := 0;
 DragOffsetY := 0;
 DragResizeHandle := RESIZE_HANDLE_NONE;
 DragOrigX1 := 0;
 DragOrigY1 := 0;
 DragOrigX2 := 0;
 DragOrigY2 := 0;
 HoveredHandle := RESIZE_HANDLE_NONE;
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DE GLISSER-DEPOSER === }
{ ============================================================================ }

{ Procédure pour ajouter un nouvel objet }
Procedure AddShape(ShapeType: TShapeType; X1, Y1, X2, Y2: Integer);
Var
 Temp: Integer;
Begin
 If ShapeCount >= MAX_SHAPES Then Exit;
 
 Inc(ShapeCount);
 InitShape(Shapes[ShapeCount]);
 Shapes[ShapeCount].ShapeType := ShapeType;
 
 { Normaliser les coordonnées (X1,Y1 = coin supérieur gauche) }
 If X1 > X2 Then Begin
  Temp := X1;
  X1 := X2;
  X2 := Temp;
 End;
 If Y1 > Y2 Then Begin
  Temp := Y1;
  Y1 := Y2;
  Y2 := Temp;
 End;
 
 Shapes[ShapeCount].X1 := X1;
 Shapes[ShapeCount].Y1 := Y1;
 Shapes[ShapeCount].X2 := X2;
 Shapes[ShapeCount].Y2 := Y2;
 Shapes[ShapeCount].FillColor := CurrentFillColor;
 Shapes[ShapeCount].LineColor := CurrentLineColor;
 Shapes[ShapeCount].LineWidth := CurrentLineWidth;
 Shapes[ShapeCount].LineStyle := CurrentLineStyle;
 
 DocumentModified := True;
End;

{ Procédure pour gérer le clic gauche de la souris }
Procedure HandleLeftClick(X, Y: Integer);
Var
 ShapeIndex: Integer;
 ToolIndex: Integer;
 ResizeHandle: Integer;
Begin
 { Vérifier si le clic est dans la barre de menu }
 If Y <= MENU_HEIGHT Then Begin
  { Gérer le clic sur le menu }
  Exit;
 End;
 
 { Vérifier si le clic est dans la barre d'outils }
 If (Y > MENU_HEIGHT) and (Y <= TOOLBAR_TOP + TOOLBAR_HEIGHT) Then Begin
  ToolIndex := GetToolAtPosition(X, Y);
  If ToolIndex > 0 Then Begin
   SelectTool(ToolIndex);
   DrawToolbar;
  End;
  Exit;
 End;
 
 { Le clic est dans la zone de travail }
 If Y > WORK_AREA_TOP Then Begin
  Case CurrentTool of
   ttSelection: Begin
     { Mode sélection: vérifier d'abord si on clique sur une poignée de redimensionnement }
     If SelectedShape > 0 Then Begin
      ResizeHandle := GetResizeHandle(X, Y, SelectedShape);
      If ResizeHandle <> RESIZE_HANDLE_NONE Then Begin
       { Démarrer le redimensionnement }
       StartDrag(SelectedShape, X, Y, ResizeHandle);
       Exit;
      End;
     End;
     
     { Chercher un objet sous le curseur }
     ShapeIndex := GetShapeAtPosition(X, Y);
     If ShapeIndex > 0 Then Begin
      SelectShape(ShapeIndex);
      { Démarrer le glissement pour déplacer l'objet }
      StartDrag(ShapeIndex, X, Y, RESIZE_HANDLE_NONE);
     End
     Else Begin
      DeselectAllShapes;
      EndDrag;
     End;
    End;
   ttRectangle, ttEllipse, ttLine, ttConnector: Begin
     { Démarrer le dessin d'une forme }
     IsDrawing := True;
     DrawStartX := X;
     DrawStartY := Y;
    End;
   ttText: Begin
     { Ajouter un objet texte à la position du clic }
     If ShapeCount < MAX_SHAPES Then Begin
      Inc(ShapeCount);
      InitShape(Shapes[ShapeCount]);
      Shapes[ShapeCount].ShapeType := stText;
      Shapes[ShapeCount].X1 := X;
      Shapes[ShapeCount].Y1 := Y;
      Shapes[ShapeCount].X2 := X + 50;
      Shapes[ShapeCount].Y2 := Y + 12;
      Shapes[ShapeCount].Text := 'Text';
      Shapes[ShapeCount].LineColor := CurrentLineColor;
      DocumentModified := True;
     End;
    End;
   ttPolygon: Begin
     { Pour les polygones, on ajoute un point au polygone en cours }
     { Pour simplifier, créer un polygone régulier (hexagone) }
     If ShapeCount < MAX_SHAPES Then Begin
      Inc(ShapeCount);
      InitShape(Shapes[ShapeCount]);
      Shapes[ShapeCount].ShapeType := stPolygon;
      { Créer un hexagone centré sur le clic }
      Shapes[ShapeCount].PointCount := 6;
      Shapes[ShapeCount].Points[1].X := X;
      Shapes[ShapeCount].Points[1].Y := Y - 30;
      Shapes[ShapeCount].Points[2].X := X + 26;
      Shapes[ShapeCount].Points[2].Y := Y - 15;
      Shapes[ShapeCount].Points[3].X := X + 26;
      Shapes[ShapeCount].Points[3].Y := Y + 15;
      Shapes[ShapeCount].Points[4].X := X;
      Shapes[ShapeCount].Points[4].Y := Y + 30;
      Shapes[ShapeCount].Points[5].X := X - 26;
      Shapes[ShapeCount].Points[5].Y := Y + 15;
      Shapes[ShapeCount].Points[6].X := X - 26;
      Shapes[ShapeCount].Points[6].Y := Y - 15;
      { Calculer le rectangle englobant }
      Shapes[ShapeCount].X1 := X - 26;
      Shapes[ShapeCount].Y1 := Y - 30;
      Shapes[ShapeCount].X2 := X + 26;
      Shapes[ShapeCount].Y2 := Y + 30;
      Shapes[ShapeCount].FillColor := CurrentFillColor;
      Shapes[ShapeCount].LineColor := CurrentLineColor;
      DocumentModified := True;
     End;
    End;
   ttBezier: Begin
     { Créer une courbe de Bézier par défaut }
     If ShapeCount < MAX_SHAPES Then Begin
      Inc(ShapeCount);
      InitShape(Shapes[ShapeCount]);
      Shapes[ShapeCount].ShapeType := stBezier;
      { Définir 4 points de contrôle pour une courbe de Bézier cubique }
      Shapes[ShapeCount].PointCount := 4;
      Shapes[ShapeCount].Points[1].X := X;
      Shapes[ShapeCount].Points[1].Y := Y;
      Shapes[ShapeCount].Points[2].X := X + 30;
      Shapes[ShapeCount].Points[2].Y := Y - 40;
      Shapes[ShapeCount].Points[3].X := X + 70;
      Shapes[ShapeCount].Points[3].Y := Y - 40;
      Shapes[ShapeCount].Points[4].X := X + 100;
      Shapes[ShapeCount].Points[4].Y := Y;
      { Calculer le rectangle englobant }
      Shapes[ShapeCount].X1 := X;
      Shapes[ShapeCount].Y1 := Y - 40;
      Shapes[ShapeCount].X2 := X + 100;
      Shapes[ShapeCount].Y2 := Y;
      Shapes[ShapeCount].LineColor := CurrentLineColor;
      DocumentModified := True;
     End;
    End;
   ttImage: Begin
     { Ajouter un placeholder d'image }
     If ShapeCount < MAX_SHAPES Then Begin
      Inc(ShapeCount);
      InitShape(Shapes[ShapeCount]);
      Shapes[ShapeCount].ShapeType := stImage;
      Shapes[ShapeCount].X1 := X;
      Shapes[ShapeCount].Y1 := Y;
      Shapes[ShapeCount].X2 := X + 80;
      Shapes[ShapeCount].Y2 := Y + 60;
      Shapes[ShapeCount].FillColor := LightGray;
      Shapes[ShapeCount].LineColor := CurrentLineColor;
      Shapes[ShapeCount].ImagePath := '';
      DocumentModified := True;
     End;
    End;
  End;
 End;
End;

{ Procédure pour gérer le relâchement du bouton gauche }
Procedure HandleLeftRelease(X, Y: Integer);
Var
 ShapeType: TShapeType;
 StartShape, StartAnchor: Integer;
 EndShape, EndAnchor: Integer;
Begin
 { Terminer le glissement s'il y en a un en cours }
 If DragMode <> DRAG_MODE_NONE Then Begin
  EndDrag;
  { Mettre à jour tous les connecteurs après déplacement }
  UpdateAllConnectors;
  Exit;
 End;
 
 If Not IsDrawing Then Exit;
 
 IsDrawing := False;
 
 { Traitement spécial pour les connecteurs }
 If CurrentTool = ttConnector Then Begin
  { Vérifier si on doit créer un connecteur }
  If (Abs(X - DrawStartX) > 5) or (Abs(Y - DrawStartY) > 5) Then Begin
   { Chercher les points d'ancrage proches pour le début et la fin }
   FindNearestAnchor(DrawStartX, DrawStartY, StartShape, StartAnchor);
   FindNearestAnchor(X, Y, EndShape, EndAnchor);
   
   { Créer le connecteur }
   If ShapeCount < MAX_SHAPES Then Begin
    Inc(ShapeCount);
    InitShape(Shapes[ShapeCount]);
    Shapes[ShapeCount].ShapeType := stConnector;
    
    { Définir les connexions }
    Shapes[ShapeCount].ConnectStartShape := StartShape;
    Shapes[ShapeCount].ConnectStartAnchor := StartAnchor;
    Shapes[ShapeCount].ConnectEndShape := EndShape;
    Shapes[ShapeCount].ConnectEndAnchor := EndAnchor;
    
    { Définir les coordonnées initiales }
    Shapes[ShapeCount].X1 := DrawStartX;
    Shapes[ShapeCount].Y1 := DrawStartY;
    Shapes[ShapeCount].X2 := X;
    Shapes[ShapeCount].Y2 := Y;
    
    { Mettre à jour les extrémités si connecté à des formes }
    UpdateConnectorEndpoints(ShapeCount);
    
    Shapes[ShapeCount].FillColor := CurrentFillColor;
    Shapes[ShapeCount].LineColor := CurrentLineColor;
    Shapes[ShapeCount].LineWidth := CurrentLineWidth;
    DocumentModified := True;
   End;
  End;
  Exit;
 End;
 
 { Créer la forme selon l'outil actuel }
 Case CurrentTool of
  ttRectangle: ShapeType := stRectangle;
  ttEllipse: ShapeType := stEllipse;
  ttLine: ShapeType := stLine;
  ttImage: ShapeType := stImage;
  Else Exit;
 End;
 
 { Ajouter la forme si elle a une taille minimale }
 If (Abs(X - DrawStartX) > 5) or (Abs(Y - DrawStartY) > 5) Then Begin
  AddShape(ShapeType, DrawStartX, DrawStartY, X, Y);
 End;
End;

{ Procédure pour initialiser les objets }
Procedure InitShapes;
Var
 I: Integer;
Begin
 ShapeCount := 0;
 SelectedShape := 0;
 IsDrawing := False;
 DrawStartX := 0;
 DrawStartY := 0;
 LastMouseX := 0;
 LastMouseY := 0;
 LastMouseButton := 0;
 { Initialiser le glisser-déposer }
 InitDragDrop;
 { Initialiser les variables pour les points d'ancrage }
 HoveredShapeForAnchor := 0;
 NearestAnchorPoint := ANCHOR_NONE;
 { Initialiser les calques }
 InitAllLayers;
 { Initialiser les variables de la boîte de dialogue des calques }
 LayerDialogVisible := False;
 LayerDialogX := 0;
 LayerDialogY := 0;
 LayerDialogSelectedLayer := 1;
 LayerDialogHighlightedButton := 0;
 For I := 1 to MAX_SHAPES do Begin
  InitShape(Shapes[I]);
 End;
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DE GESTION DES OBJETS === }
{ ============================================================================ }

{ ============================================================================ }
{ === PROCEDURES DU MENU CONTEXTUEL (CLIC DROIT) === }
{ ============================================================================ }

{ Procédure pour masquer le menu contextuel }
Procedure HideContextMenu;
Begin
 ContextMenuVisible := False;
 ContextMenuHighlight := 0;
End;

{ Procédure pour dessiner le menu contextuel }
Procedure DrawContextMenu;
Var
 I: Integer;
 MenuHeight: Integer;
 ItemY: Integer;
 ItemEnabled: Boolean;
Begin
 If Not ContextMenuVisible Then Exit;
 
 MenuHeight := CONTEXT_MENU_ITEM_COUNT * CONTEXT_MENU_ITEM_HEIGHT + 4;
 
 { Dessiner le fond du menu }
 SetFillStyle(SolidFill, CONTEXT_MENU_BG_COLOR);
 Bar(ContextMenuX, ContextMenuY, ContextMenuX + CONTEXT_MENU_WIDTH, ContextMenuY + MenuHeight);
 
 { Dessiner la bordure du menu }
 SetColor(CONTEXT_MENU_BORDER_COLOR);
 Rectangle(ContextMenuX, ContextMenuY, ContextMenuX + CONTEXT_MENU_WIDTH, ContextMenuY + MenuHeight);
 
 { Dessiner chaque élément du menu }
 For I := 1 to CONTEXT_MENU_ITEM_COUNT do Begin
  ItemY := ContextMenuY + 2 + (I - 1) * CONTEXT_MENU_ITEM_HEIGHT;
  
  { Déterminer si l'élément est activé }
  { Cut, Copy, Delete nécessitent une sélection }
  { Paste nécessite que le presse-papiers ne soit pas vide }
  { Properties nécessite une sélection }
  Case I of
   1: ItemEnabled := (SelectedShape > 0); { Cut }
   2: ItemEnabled := (SelectedShape > 0); { Copy }
   3: ItemEnabled := Not ClipboardEmpty;  { Paste }
   4: ItemEnabled := (SelectedShape > 0); { Delete }
   5: ItemEnabled := (SelectedShape > 0); { Properties }
   Else ItemEnabled := True;
  End;
  
  { Dessiner le fond de l'élément si surbrillance }
  If (I = ContextMenuHighlight) and ItemEnabled Then Begin
   SetFillStyle(SolidFill, CONTEXT_MENU_HIGHLIGHT_BG);
   Bar(ContextMenuX + 1, ItemY, ContextMenuX + CONTEXT_MENU_WIDTH - 1, ItemY + CONTEXT_MENU_ITEM_HEIGHT);
   SetColor(CONTEXT_MENU_HIGHLIGHT_FG);
  End
  Else If ItemEnabled Then Begin
   SetColor(CONTEXT_MENU_TEXT_COLOR);
  End
  Else Begin
   SetColor(CONTEXT_MENU_DISABLED_COLOR);
  End;
  
  { Afficher le texte de l'élément }
  OutTextXY(ContextMenuX + 8, ItemY + 4, ContextMenuNames[I]);
 End;
End;

{ Fonction pour obtenir l'élément du menu contextuel à une position }
Function GetContextMenuItemAtPosition(X, Y: Integer): Integer;
Var
 MenuHeight: Integer;
 RelY: Integer;
 Item: Integer;
Begin
 GetContextMenuItemAtPosition := 0;
 
 If Not ContextMenuVisible Then Exit;
 
 MenuHeight := CONTEXT_MENU_ITEM_COUNT * CONTEXT_MENU_ITEM_HEIGHT + 4;
 
 { Vérifier si le point est dans le menu }
 If (X >= ContextMenuX) and (X <= ContextMenuX + CONTEXT_MENU_WIDTH) and
    (Y >= ContextMenuY) and (Y <= ContextMenuY + MenuHeight) Then Begin
  RelY := Y - ContextMenuY - 2;
  Item := (RelY div CONTEXT_MENU_ITEM_HEIGHT) + 1;
  If (Item >= 1) and (Item <= CONTEXT_MENU_ITEM_COUNT) Then Begin
   GetContextMenuItemAtPosition := Item;
  End;
 End;
End;

{ Procédure pour exécuter une action du menu contextuel }
Procedure ExecuteContextMenuAction(ItemIndex: Integer);
Var
 ItemEnabled: Boolean;
Begin
 { Vérifier si l'élément est activé }
 Case ItemIndex of
  1: ItemEnabled := (SelectedShape > 0); { Cut }
  2: ItemEnabled := (SelectedShape > 0); { Copy }
  3: ItemEnabled := Not ClipboardEmpty;  { Paste }
  4: ItemEnabled := (SelectedShape > 0); { Delete }
  5: ItemEnabled := (SelectedShape > 0); { Properties }
  Else ItemEnabled := False;
 End;
 
 If Not ItemEnabled Then Exit;
 
 Case ItemIndex of
  1: EditCut;        { Cut }
  2: EditCopy;       { Copy }
  3: EditPaste;      { Paste }
  4: EditDelete;     { Delete }
  5: ShowPropertiesDialog; { Properties - Afficher la boîte de dialogue des propriétés }
 End;
 
 HideContextMenu;
End;

{ Procédure pour afficher le menu contextuel }
Procedure ShowContextMenu(X, Y: Integer);
Begin
 { Ajuster la position pour que le menu reste visible }
 ContextMenuX := X;
 ContextMenuY := Y;
 
 { S'assurer que le menu ne dépasse pas de l'écran }
 If ContextMenuX + CONTEXT_MENU_WIDTH > ScreenWidth Then Begin
  ContextMenuX := ScreenWidth - CONTEXT_MENU_WIDTH - 2;
 End;
 If ContextMenuY + (CONTEXT_MENU_ITEM_COUNT * CONTEXT_MENU_ITEM_HEIGHT + 4) > ScreenHeight Then Begin
  ContextMenuY := ScreenHeight - (CONTEXT_MENU_ITEM_COUNT * CONTEXT_MENU_ITEM_HEIGHT + 4) - 2;
 End;
 
 ContextMenuVisible := True;
 ContextMenuHighlight := 0;
End;

{ Procédure pour gérer le clic droit de la souris }
Procedure HandleRightClick(X, Y: Integer);
Var
 ShapeIndex: Integer;
Begin
 { Masquer le menu contextuel s'il est déjà visible }
 If ContextMenuVisible Then Begin
  HideContextMenu;
  Exit;
 End;
 
 { Vérifier si le clic est dans la zone de travail }
 If Y > WORK_AREA_TOP Then Begin
  { Chercher s'il y a un objet sous le curseur }
  ShapeIndex := GetShapeAtPosition(X, Y);
  
  { Si un objet est trouvé, le sélectionner }
  If ShapeIndex > 0 Then Begin
   SelectShape(ShapeIndex);
  End;
  
  { Afficher le menu contextuel }
  ShowContextMenu(X, Y);
 End;
End;

{ Procédure pour initialiser le menu contextuel }
Procedure InitContextMenu;
Begin
 ContextMenuVisible := False;
 ContextMenuX := 0;
 ContextMenuY := 0;
 ContextMenuHighlight := 0;
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DU MENU CONTEXTUEL === }
{ ============================================================================ }

{ Procédure pour dessiner la barre de menu principale }
Procedure DrawMenuBar;
Var
 I: Integer;
 TextX: Integer;
Begin
 { Dessiner le fond de la barre de menu }
 SetFillStyle(SolidFill, MENU_BAR_COLOR);
 Bar(0, 0, ScreenWidth, MENU_HEIGHT);
 
 { Dessiner une ligne de séparation }
 SetColor(DarkGray);
 Line(0, MENU_HEIGHT, ScreenWidth, MENU_HEIGHT);
 
 { Dessiner chaque élément du menu }
 For I := 1 to MENU_COUNT do Begin
  TextX := MenuPositions[I];
  
  { Si ce menu est sélectionné, dessiner le fond en surbrillance }
  If (I = CurrentMenu) and (MenuState <> msNone) Then Begin
   SetFillStyle(SolidFill, MENU_HIGHLIGHT_BG);
   Bar(TextX - 4, 1, TextX + Length(MenuNames[I]) * 8 + 4, MENU_HEIGHT - 1);
   SetColor(MENU_HIGHLIGHT_FG);
  End
  Else Begin
   SetColor(MENU_TEXT_COLOR);
  End;
  
  { Dessiner le texte du menu }
  OutTextXY(TextX, 4, MenuNames[I]);
 End;
End;

{ Procédure pour dessiner un sous-menu déroulant }
Procedure DrawDropDownMenu(MenuIndex: Integer);
Const
 MaxItems = 12;
 ItemHeight = 16;
 MenuWidth = 150;
Var
 X, Y, I, ItemCount: Integer;
 Items: Array[1..MaxItems] of String[20];
Begin
 { Définir les éléments selon le menu sélectionné }
 Case MenuIndex of
  1: Begin { File }
      ItemCount := 11;
      Items[1] := 'New';
      Items[2] := 'Open...';
      Items[3] := 'Close';
      Items[4] := 'Save';
      Items[5] := 'Save As...';
      Items[6] := '-';
      Items[7] := 'Export...';
      Items[8] := '-';
      Items[9] := 'Print...';
      Items[10] := 'Print Preview';
      Items[11] := 'Exit';
     End;
  2: Begin { Edit }
      ItemCount := 12;
      Items[1] := 'Undo';
      Items[2] := 'Redo';
      Items[3] := '-';
      Items[4] := 'Cut';
      Items[5] := 'Copy';
      Items[6] := 'Paste';
      Items[7] := 'Delete';
      Items[8] := '-';
      Items[9] := 'Select All';
      Items[10] := '-';
      Items[11] := 'Find...';
      Items[12] := 'Replace...';
     End;
  3: Begin { View }
      ItemCount := 9;
      Items[1] := 'Zoom In';
      Items[2] := 'Zoom Out';
      Items[3] := 'Fit Page';
      Items[4] := '-';
      Items[5] := 'Grid';
      Items[6] := 'Rulers';
      Items[7] := 'Guides';
      Items[8] := '-';
      Items[9] := 'Snap to Grid';
     End;
  4: Begin { Insert }
      ItemCount := 6;
      Items[1] := 'Shape';
      Items[2] := 'Text Box';
      Items[3] := 'Image...';
      Items[4] := 'Connector';
      Items[5] := 'Page';
      Items[6] := 'Layer';
     End;
  5: Begin { Format }
      ItemCount := 7;
      Items[1] := 'Fill...';
      Items[2] := 'Line...';
      Items[3] := 'Text...';
      Items[4] := '-';
      Items[5] := 'Alignment';
      Items[6] := 'Group';
      Items[7] := 'Ungroup';
     End;
  6: Begin { Shape }
      ItemCount := 10;
      Items[1] := 'Rotate';
      Items[2] := 'Flip';
      Items[3] := '-';
      Items[4] := 'Align';
      Items[5] := 'Distribute';
      Items[6] := '-';
      Items[7] := 'Size';
      Items[8] := 'Position';
      Items[9] := '-';
      Items[10] := 'Operations';
     End;
  7: Begin { Tools }
      ItemCount := 4;
      Items[1] := 'Snap to Grid';
      Items[2] := 'Snap to Guides';
      Items[3] := '-';
      Items[4] := 'Options...';
     End;
  8: Begin { Window }
      ItemCount := 4;
      Items[1] := 'New Window';
      Items[2] := 'Cascade';
      Items[3] := 'Tile';
      Items[4] := 'Close All';
     End;
  9: Begin { Help }
      ItemCount := 3;
      Items[1] := 'Help Topics';
      Items[2] := '-';
      Items[3] := 'About Visio';
     End;
  Else
   ItemCount := 0;
 End;
 
 If ItemCount = 0 Then Exit;
 
 { Calculer la position du menu déroulant }
 X := MenuPositions[MenuIndex] - 4;
 Y := MENU_HEIGHT + 1;
 
 { Dessiner le fond du menu déroulant }
 SetFillStyle(SolidFill, MENU_BAR_COLOR);
 Bar(X, Y, X + MenuWidth, Y + ItemCount * ItemHeight + 4);
 
 { Dessiner la bordure }
 SetColor(DarkGray);
 Rectangle(X, Y, X + MenuWidth, Y + ItemCount * ItemHeight + 4);
 
 { Dessiner les éléments du menu }
 SetColor(MENU_TEXT_COLOR);
 For I := 1 to ItemCount do Begin
  If Items[I] = '-' Then Begin
   { Dessiner un séparateur }
   SetColor(DarkGray);
   Line(X + 5, Y + I * ItemHeight - 6, X + MenuWidth - 5, Y + I * ItemHeight - 6);
   SetColor(MENU_TEXT_COLOR);
  End
  Else Begin
   OutTextXY(X + 10, Y + (I - 1) * ItemHeight + 4, Items[I]);
  End;
 End;
End;

{ Fonction pour déterminer quel menu est sous la souris }
Function GetMenuAtPosition(MouseX, MouseY: Integer): Integer;
Var
 I: Integer;
Begin
 GetMenuAtPosition := 0;
 
 { Vérifier si on est dans la barre de menu }
 If (MouseY >= 0) and (MouseY <= MENU_HEIGHT) Then Begin
  For I := 1 to MENU_COUNT do Begin
   If (MouseX >= MenuPositions[I] - 4) and 
      (MouseX <= MenuPositions[I] + Length(MenuNames[I]) * 8 + 4) Then Begin
    GetMenuAtPosition := I;
    Exit;
   End;
  End;
 End;
End;

{ Procédure pour initialiser le système de menus }
Procedure InitMenuSystem;
Begin
 CurrentMenu := 0;
 MenuState := msNone;
 ScreenWidth := GetMaxX;
 ScreenHeight := GetMaxY;
 CurrentFileName := '';
 DocumentModified := False;
 { Initialisation des variables du menu Edit }
 UndoStackIndex := 0;
 CanUndo := False;
 CanRedo := False;
 ClipboardEmpty := True;
 HasSelection := False;
 { Initialisation des variables du menu View }
 ZoomLevel := DEFAULT_ZOOM;
 ShowGrid := False;
 ShowRulers := True;
 ShowGuides := True;
 SnapToGridEnabled := True;
 { Initialisation des variables du menu Insert }
 CurrentPage := 1;
 PageCount := DEFAULT_PAGE_COUNT;
 CurrentLayer := 1;
 LayerCount := DEFAULT_LAYER_COUNT;
 InsertMode := 0;
 { Initialisation des variables du menu Format }
 CurrentFillColor := DEFAULT_FILL_COLOR;
 CurrentLineColor := DEFAULT_LINE_COLOR;
 CurrentLineWidth := DEFAULT_LINE_WIDTH;
 CurrentLineStyle := DEFAULT_LINE_STYLE;
 CurrentTextSize := DEFAULT_TEXT_SIZE;
 CurrentAlignment := atLeft;
 ObjectsGrouped := False;
 { Initialisation des variables de gestion des groupes }
 NextGroupID := 0;
 EditingGroupID := 0;
 { Initialisation des variables de la boîte de dialogue des propriétés }
 PropertiesDialogVisible := False;
 PropDialogX := 0;
 PropDialogY := 0;
 PropSelectedColor := 0;
 PropSelectedLineWidth := 1;
 PropSelectedLineStyle := LINESTYLE_SOLID;
 PropHighlightedButton := 0;
 { Initialisation des variables du menu Shape }
 CurrentRotation := 0;
 ShapeWidth := 100;
 ShapeHeight := 100;
 ShapeX := 0;
 ShapeY := 0;
 { Initialisation de la barre d'outils }
 CurrentTool := ttSelection;
End;

{ Fonction pour exécuter une action du menu File }
{ Retourne True si l'application doit quitter }
Function ExecuteFileMenuAction(ItemIndex: Integer): Boolean;
Begin
 ExecuteFileMenuAction := False;
 Case ItemIndex of
  1: FileNew;           { New }
  2: FileOpen;          { Open... }
  3: FileClose;         { Close }
  4: FileSave;          { Save }
  5: FileSaveAs;        { Save As... }
  { 6 est un séparateur }
  7: FileExport;        { Export... }
  { 8 est un séparateur }
  9: FilePrint;         { Print... }
  10: FilePrintPreview; { Print Preview }
  11: ExecuteFileMenuAction := FileExit; { Exit }
 End;
End;

{ Procédure pour exécuter une action du menu Edit }
Procedure ExecuteEditMenuAction(ItemIndex: Integer);
Begin
 Case ItemIndex of
  1: EditUndo;         { Undo }
  2: EditRedo;         { Redo }
  { 3 est un séparateur }
  4: EditCut;          { Cut }
  5: EditCopy;         { Copy }
  6: EditPaste;        { Paste }
  7: EditDelete;       { Delete }
  { 8 est un séparateur }
  9: EditSelectAll;    { Select All }
  { 10 est un séparateur }
  11: EditFind;        { Find... }
  12: EditReplace;     { Replace... }
 End;
End;

{ Procédure pour exécuter une action du menu View }
Procedure ExecuteViewMenuAction(ItemIndex: Integer);
Begin
 Case ItemIndex of
  1: ViewZoomIn;       { Zoom In }
  2: ViewZoomOut;      { Zoom Out }
  3: ViewFitPage;      { Fit Page }
  { 4 est un séparateur }
  5: ViewGrid;         { Grid }
  6: ViewRulers;       { Rulers }
  7: ViewGuides;       { Guides }
  { 8 est un séparateur }
  9: ViewSnapToGrid;   { Snap to Grid }
 End;
End;

{ Procédure pour exécuter une action du menu Insert }
Procedure ExecuteInsertMenuAction(ItemIndex: Integer);
Begin
 Case ItemIndex of
  1: InsertShape;      { Shape }
  2: InsertTextBox;    { Text Box }
  3: InsertImage;      { Image... }
  4: InsertConnector;  { Connector }
  5: InsertPage;       { Page }
  6: ShowLayerDialog;  { Layer - Ouvrir la boîte de dialogue des calques }
 End;
End;

{ Procédure pour exécuter une action du menu Format }
Procedure ExecuteFormatMenuAction(ItemIndex: Integer);
Begin
 Case ItemIndex of
  1: FormatFill;       { Fill... }
  2: FormatLine;       { Line... }
  3: FormatText;       { Text... }
  { 4 est un séparateur }
  5: FormatAlignment;  { Alignment }
  6: FormatGroup;      { Group }
  7: FormatUngroup;    { Ungroup }
 End;
End;

{ Procédure pour exécuter une action du menu Shape }
Procedure ExecuteShapeMenuAction(ItemIndex: Integer);
Begin
 Case ItemIndex of
  1: ShapeRotate;      { Rotate }
  2: ShapeFlip;        { Flip }
  { 3 est un séparateur }
  4: ShapeAlign;       { Align }
  5: ShapeDistribute;  { Distribute }
  { 6 est un séparateur }
  7: ShapeSize;        { Size }
  8: ShapePosition;    { Position }
  { 9 est un séparateur }
  10: ShapeOperations; { Operations }
 End;
End;

{ Fonction pour déterminer quel élément de menu est sous la souris }
Function GetDropDownItemAtPosition(MenuIndex, MouseX, MouseY: Integer): Integer;
Const
 ItemHeight = 16;
 MenuWidth = 150;
Var
 X, Y, ItemCount, I: Integer;
Begin
 GetDropDownItemAtPosition := 0;
 
 { Déterminer le nombre d'éléments selon le menu }
 Case MenuIndex of
  1: ItemCount := 11; { File }
  2: ItemCount := 12; { Edit }
  3: ItemCount := 9;  { View }
  4: ItemCount := 6;  { Insert }
  5: ItemCount := 7;  { Format }
  6: ItemCount := 10; { Shape }
  7: ItemCount := 4;  { Tools }
  8: ItemCount := 4;  { Window }
  9: ItemCount := 3;  { Help }
  Else ItemCount := 0;
 End;
 
 If ItemCount = 0 Then Exit;
 
 { Calculer la position du menu déroulant }
 X := MenuPositions[MenuIndex] - 4;
 Y := MENU_HEIGHT + 1;
 
 { Vérifier si la souris est dans la zone du menu déroulant }
 If (MouseX >= X) and (MouseX <= X + MenuWidth) and
    (MouseY >= Y) and (MouseY <= Y + ItemCount * ItemHeight + 4) Then Begin
  { Calculer l'élément sous la souris }
  I := (MouseY - Y) div ItemHeight + 1;
  If (I >= 1) and (I <= ItemCount) Then Begin
   GetDropDownItemAtPosition := I;
  End;
 End;
End;

{ Procédure pour rafraîchir l'affichage complet }
Procedure RefreshScreen;
Begin
 { Effacer l'écran avec fond blanc (zone de travail sous la barre d'outils) }
 SetFillStyle(SolidFill, White);
 Bar(0, TOOLBAR_TOP + TOOLBAR_HEIGHT + 1, ScreenWidth, ScreenHeight);
 
 { Dessiner tous les objets graphiques }
 DrawAllShapes;
 
 { Dessiner la barre de menu }
 DrawMenuBar;
 
 { Dessiner la barre d'outils }
 DrawToolbar;
 
 { Si un menu est ouvert, le dessiner }
 If (MenuState = msDropDown) and (CurrentMenu > 0) Then Begin
  DrawDropDownMenu(CurrentMenu);
 End;
 
 { Dessiner le menu contextuel s'il est visible }
 If ContextMenuVisible Then Begin
  DrawContextMenu;
 End;
 
 { Dessiner la boîte de dialogue des propriétés si elle est visible }
 If PropertiesDialogVisible Then Begin
  DrawPropertiesDialog;
 End;
 
 { Dessiner la boîte de dialogue des calques si elle est visible }
 If LayerDialogVisible Then Begin
  DrawLayerDialog;
 End;
End;

BEGIN
 InitializeGraphics;
 InitMenuSystem;
 InitShapes;
 InitContextMenu;
 
 { Afficher l'écran initial avec le menu }
 RefreshScreen;
 
 { Boucle principale - en attente d'une touche pour quitter }
 If MouseDriverFound Then Begin
  ShowMouse;
 End;
 
 { Boucle principale du programme }
 Repeat
  { Gérer les événements de la souris }
  If MouseDriverFound Then Begin
   {$IFDEF FPC}
    GetMouseState(LastMouseX, LastMouseY, LastMouseButton);
   {$ELSE}
    GetMouseState(LastMouseX, LastMouseY, LastMouseButton);
   {$ENDIF}
   
   { Détecter le survol des poignées de redimensionnement }
   If (SelectedShape > 0) and (DragMode = DRAG_MODE_NONE) Then Begin
    OldHoveredHandle := HoveredHandle;
    HoveredHandle := GetResizeHandle(LastMouseX, LastMouseY, SelectedShape);
    { Si le survol a changé, rafraîchir l'écran }
    If HoveredHandle <> OldHoveredHandle Then Begin
     HideMouse;
     RefreshScreen;
     ShowMouse;
    End;
   End
   Else Begin
    HoveredHandle := RESIZE_HANDLE_NONE;
   End;
   
   { Détecter le survol des formes pour afficher les points d'ancrage (outil connecteur) }
   If (CurrentTool = ttConnector) and (DragMode = DRAG_MODE_NONE) Then Begin
    { Trouver la forme sous la souris }
    HoveredShapeForAnchor := GetShapeAtPosition(LastMouseX, LastMouseY);
    { Trouver le point d'ancrage le plus proche si on survole une forme }
    If HoveredShapeForAnchor > 0 Then Begin
     If Not FindNearestAnchor(LastMouseX, LastMouseY, HoveredShapeForAnchor, NearestAnchorPoint) Then
      NearestAnchorPoint := ANCHOR_NONE;
    End
    Else Begin
     NearestAnchorPoint := ANCHOR_NONE;
    End;
   End
   Else Begin
    HoveredShapeForAnchor := 0;
    NearestAnchorPoint := ANCHOR_NONE;
   End;
   
   { Détecter un clic gauche (bouton 1) }
   If (LastMouseButton and 1) = 1 Then Begin
    HideMouse;
    { Si la boîte de dialogue des calques est visible, gérer le clic }
    If LayerDialogVisible Then Begin
     HandleLayerDialogClick(LastMouseX, LastMouseY);
    End
    { Si la boîte de dialogue des propriétés est visible, gérer le clic }
    Else If PropertiesDialogVisible Then Begin
     HandlePropertiesDialogClick(LastMouseX, LastMouseY);
    End
    { Si le menu contextuel est visible, vérifier si on clique dedans }
    Else If ContextMenuVisible Then Begin
     ContextMenuHighlight := GetContextMenuItemAtPosition(LastMouseX, LastMouseY);
     If ContextMenuHighlight > 0 Then Begin
      ExecuteContextMenuAction(ContextMenuHighlight);
     End
     Else Begin
      { Clic en dehors du menu contextuel, le fermer }
      HideContextMenu;
     End;
    End
    Else Begin
     HandleLeftClick(LastMouseX, LastMouseY);
    End;
    RefreshScreen;
    ShowMouse;
    { Suivre le mouvement de la souris pendant que le bouton est enfoncé (drag) }
    Repeat
     {$IFDEF FPC}
      GetMouseState(LastMouseX, LastMouseY, LastMouseButton);
     {$ELSE}
      GetMouseState(LastMouseX, LastMouseY, LastMouseButton);
     {$ENDIF}
     { Si on est en mode glissement, mettre à jour la position }
     If DragMode <> DRAG_MODE_NONE Then Begin
      HideMouse;
      HandleMouseMove(LastMouseX, LastMouseY);
      RefreshScreen;
      ShowMouse;
     End;
    Until (LastMouseButton and 1) = 0;
    { Gérer le relâchement du bouton }
    HideMouse;
    HandleLeftRelease(LastMouseX, LastMouseY);
    RefreshScreen;
    ShowMouse;
   End;
   
   { Détecter un clic droit (bouton 2) }
   If (LastMouseButton and 2) = 2 Then Begin
    HideMouse;
    HandleRightClick(LastMouseX, LastMouseY);
    RefreshScreen;
    ShowMouse;
    { Attendre que le bouton soit relâché }
    Repeat
     {$IFDEF FPC}
      GetMouseState(LastMouseX, LastMouseY, LastMouseButton);
     {$ELSE}
      GetMouseState(LastMouseX, LastMouseY, LastMouseButton);
     {$ENDIF}
    Until (LastMouseButton and 2) = 0;
   End;
  End;
 
  { Attendre une entrée clavier }
  If KeyPressed Then Begin
   Case ReadKey of
    #27: Begin
          { Si le menu contextuel est visible, le fermer }
          If ContextMenuVisible Then Begin
           HideContextMenu;
           RefreshScreen;
          End
          Else Begin
           Break; { Escape pour quitter }
          End;
         End;
    #0: Begin { Touches de fonction }
         Case ReadKey of
          #59: Begin { F1 - Aide }
                CurrentMenu := 9;
                MenuState := msDropDown;
                RefreshScreen;
               End;
         End;
        End;
   End;
  End;
 Until False;
 
 If MouseDriverFound Then Begin
  HideMouse;
 End;
 
 CloseGraph;
END.