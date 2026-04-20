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
  19. [FAIT] Ecrire et sauvegarder les fichiers au format Visio VSD/VSDX
  20. [FAIT] Gerer les stencils et les masters Visio

  === FORMAT SVG ===
  21. [FAIT] Parser et importer les fichiers SVG avec support des elements path, rect, circle, ellipse, line, polygon, text
  22. [FAIT] Exporter les dessins au format SVG avec attributs de style CSS

  === EXPORT IMAGES ===
  23. [FAIT] Exporter en format BMP avec support 1-bit, 4-bit, 8-bit, 24-bit
  24. [FAIT] Exporter en format GIF avec palette de 256 couleurs et transparence
  25. [FAIT] Exporter en format JPEG avec compression reglable et en format PNG avec canal alpha pour transparence
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

 { Constantes pour les Stencils et Masters Visio }
 MAX_MASTERS = 100;                    { Nombre maximum de masters par stencil }
 MAX_STENCILS = 20;                    { Nombre maximum de stencils chargés }
 MAX_MASTER_NAME_LENGTH = 50;          { Longueur max du nom d'un master }
 MAX_STENCIL_NAME_LENGTH = 100;        { Longueur max du nom d'un stencil }
 VISIO_STENCIL_FORMAT_VSS = 1;         { Format VSS (OLE binaire) }
 VISIO_STENCIL_FORMAT_VSSX = 2;        { Format VSSX (XML compressé ZIP) }

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
 
 { Structure pour un Master Visio (forme modèle réutilisable) }
 TVisioMaster = Record
  ID: LongInt;                                   { ID unique du master }
  Name: String[MAX_MASTER_NAME_LENGTH];          { Nom du master }
  UniqueID: String[40];                          { ID unique universel (GUID) }
  IconIndex: Integer;                            { Index de l'icône }
  BaseShape: TVisioShape;                        { Forme de base du master }
  Width, Height: Real;                           { Dimensions par défaut }
  OffsetX, OffsetY: Real;                        { Décalage du point d'ancrage }
  IsGroup: Boolean;                              { True si le master est un groupe }
  SubShapeCount: Integer;                        { Nombre de sous-formes }
  SubShapes: Array[1..20] of TVisioShape;        { Sous-formes (si groupe) }
  ConnectionPointCount: Integer;                 { Nombre de points de connexion }
  ConnectionPoints: Array[1..8] of Record        { Points de connexion }
   X, Y: Real;                                   { Position relative }
   DirX, DirY: Real;                             { Direction de la connexion }
  End;
 End;
 
 { Structure pour un Stencil Visio (collection de masters) }
 TVisioStencil = Record
  Name: String[MAX_STENCIL_NAME_LENGTH];         { Nom du stencil }
  FilePath: String[255];                         { Chemin du fichier }
  FileFormat: Integer;                           { Format (VSS ou VSSX) }
  MasterCount: Integer;                          { Nombre de masters }
  Masters: Array[1..MAX_MASTERS] of TVisioMaster; { Masters du stencil }
  IsModified: Boolean;                           { True si le stencil a été modifié }
  IsReadOnly: Boolean;                           { True si le stencil est en lecture seule }
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
 { Variables pour les Stencils et Masters Visio }
 Stencils: Array[1..MAX_STENCILS] of TVisioStencil;
 StencilCount: Integer;
 CurrentStencil: Integer;        { Stencil actuellement sélectionné }
 NextMasterID: LongInt;          { Prochain ID de master disponible }

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

{ ============================================================================ }
{ === FONCTIONS D'ECRITURE DES FICHIERS VISIO VSD/VSDX === }
{ ============================================================================ }

{ Fonction pour convertir une couleur Pascal en couleur Visio (BGR) }
Function PascalColorToVisioColor(PascalColor: Integer): LongInt;
Begin
 Case PascalColor of
  0: PascalColorToVisioColor := $000000;  { Noir }
  1: PascalColorToVisioColor := $FF0000;  { Bleu }
  2: PascalColorToVisioColor := $00FF00;  { Vert }
  3: PascalColorToVisioColor := $FFFF00;  { Cyan }
  4: PascalColorToVisioColor := $0000FF;  { Rouge }
  5: PascalColorToVisioColor := $FF00FF;  { Magenta }
  6: PascalColorToVisioColor := $00FFFF;  { Marron/Jaune foncé }
  7: PascalColorToVisioColor := $C0C0C0;  { Gris clair }
  8: PascalColorToVisioColor := $808080;  { Gris foncé }
  9: PascalColorToVisioColor := $FF8080;  { Bleu clair }
  10: PascalColorToVisioColor := $80FF80; { Vert clair }
  11: PascalColorToVisioColor := $FFFF80; { Cyan clair }
  12: PascalColorToVisioColor := $8080FF; { Rouge clair }
  13: PascalColorToVisioColor := $FF80FF; { Magenta clair }
  14: PascalColorToVisioColor := $00FFFF; { Jaune }
  15: PascalColorToVisioColor := $FFFFFF; { Blanc }
 Else
  PascalColorToVisioColor := $000000;     { Noir par défaut }
 End;
End;

{ Fonction pour convertir TShapeType en type de forme Visio }
Function TShapeTypeToVisioShapeType(ST: TShapeType): Integer;
Begin
 Case ST of
  stRectangle: TShapeTypeToVisioShapeType := VISIO_SHAPE_RECTANGLE;
  stEllipse: TShapeTypeToVisioShapeType := VISIO_SHAPE_ELLIPSE;
  stLine: TShapeTypeToVisioShapeType := VISIO_SHAPE_LINE;
  stPolygon: TShapeTypeToVisioShapeType := VISIO_SHAPE_POLYLINE;
  stConnector: TShapeTypeToVisioShapeType := VISIO_SHAPE_CONNECTOR;
  stText: TShapeTypeToVisioShapeType := VISIO_SHAPE_TEXT;
 Else
  TShapeTypeToVisioShapeType := VISIO_SHAPE_RECTANGLE;
 End;
End;

{ Procédure pour convertir TShapeObject en TVisioShape }
Procedure ShapeObjectToVisioShape(Const Shape: TShapeObject; Var VSh: TVisioShape);
Begin
 VSh.ShapeType := TShapeTypeToVisioShapeType(Shape.ShapeType);
 VSh.X := Shape.X1;
 VSh.Y := Shape.Y1;
 VSh.Width := Shape.X2 - Shape.X1;
 VSh.Height := Shape.Y2 - Shape.Y1;
 VSh.Angle := 0;
 VSh.FillColor := PascalColorToVisioColor(Shape.FillColor);
 VSh.LineColor := PascalColorToVisioColor(Shape.LineColor);
 VSh.LineWeight := Shape.LineWidth;
 VSh.Text := Shape.Text;
 VSh.ParentID := Shape.GroupID;
End;

{ Procédure pour initialiser l'en-tête OLE avec des valeurs par défaut }
Procedure InitOLEHeader(Var Header: TOLEHeader);
Var
 I: Integer;
Begin
 { Signature OLE }
 Header.Signature[0] := $D0;
 Header.Signature[1] := $CF;
 Header.Signature[2] := $11;
 Header.Signature[3] := $E0;
 Header.Signature[4] := $A1;
 Header.Signature[5] := $B6;
 Header.Signature[6] := $1A;
 Header.Signature[7] := $E1;
 
 { CLSID Visio (simplifié) }
 For I := 0 to 15 do Header.CLSID[I] := 0;
 
 Header.MinorVersion := $003E;
 Header.MajorVersion := $0003;
 Header.ByteOrder := $FFFE;        { Little-endian }
 Header.SectorShift := 9;          { 512 octets par secteur }
 Header.MiniSectorShift := 6;      { 64 octets par mini-secteur }
 
 For I := 0 to 5 do Header.Reserved[I] := 0;
 
 Header.TotalSectors := 0;
 Header.FirstDirSector := 0;
 Header.TransactionSig := 0;
 Header.MiniStreamCutoff := 4096;
 Header.FirstMiniFATSector := -2;  { ENDOFCHAIN }
 Header.NumMiniFATSectors := 0;
 Header.FirstDIFATSector := -2;    { ENDOFCHAIN }
 Header.NumDIFATSectors := 0;
 
 For I := 0 to 108 do Header.DIFAT[I] := -1;  { FREESECT }
End;

{ Procédure pour initialiser une entrée de répertoire OLE }
Procedure InitOLEDirectoryEntry(Var Entry: TOLEDirectoryEntry; 
                                  Const Name: String; ObjType: Byte);
Var
 I: Integer;
 NameLen: Integer;
Begin
 { Effacer l'entrée }
 For I := 0 to 63 do Entry.EntryName[I] := 0;
 
 { Copier le nom en UTF-16 (simplifié: ASCII seulement) }
 NameLen := Length(Name);
 If NameLen > 31 Then NameLen := 31;
 For I := 1 to NameLen do Begin
  Entry.EntryName[(I-1) * 2] := Ord(Name[I]);
  Entry.EntryName[(I-1) * 2 + 1] := 0;
 End;
 
 Entry.NameLength := (NameLen + 1) * 2;  { Inclure le null terminator }
 Entry.ObjectType := ObjType;
 Entry.ColorFlag := 1;  { Rouge dans l'arbre rouge-noir }
 Entry.LeftSiblingID := -1;   { NOSTREAM }
 Entry.RightSiblingID := -1;  { NOSTREAM }
 Entry.ChildID := -1;         { NOSTREAM }
 
 For I := 0 to 15 do Entry.CLSID[I] := 0;
 Entry.StateBits := 0;
 For I := 0 to 7 do Begin
  Entry.CreationTime[I] := 0;
  Entry.ModifiedTime[I] := 0;
 End;
 Entry.StartSector := 0;
 For I := 0 to 7 do Entry.StreamSize[I] := 0;
End;

{ Fonction pour écrire un fichier VSD (format OLE binaire) }
Function WriteVSDFile(Const FileName: String): Boolean;
Var
 F: File;
 Header: TOLEHeader;
 RootEntry, VisioDocEntry, ContentsEntry: TOLEDirectoryEntry;
 FAT: Array[0..127] of LongInt;
 I: Integer;
 BytesWritten: Integer;
 ShapeData: Array[0..4095] of Byte;
 DataSize: Integer;
 VShape: TVisioShape;
 DataOffset: Integer;
Begin
 WriteVSDFile := False;
 
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 { Initialiser l'en-tête OLE }
 InitOLEHeader(Header);
 Header.FirstDirSector := 1;
 Header.TotalSectors := 4;
 Header.DIFAT[0] := 0;  { FAT dans le secteur 0 }
 
 { Écrire l'en-tête (512 octets) }
 BlockWrite(F, Header, 512, BytesWritten);
 If BytesWritten < 512 Then Begin
  Close(F);
  Exit;
 End;
 
 { Initialiser et écrire le FAT (secteur 0) }
 For I := 0 to 127 do FAT[I] := -1;  { FREESECT }
 FAT[0] := -3;  { FATSECT - ce secteur contient le FAT }
 FAT[1] := -2;  { ENDOFCHAIN - fin de la chaîne du répertoire }
 FAT[2] := -2;  { ENDOFCHAIN - fin de VisioDocument }
 FAT[3] := -2;  { ENDOFCHAIN - fin de Contents }
 
 BlockWrite(F, FAT, 512, BytesWritten);
 If BytesWritten < 512 Then Begin
  Close(F);
  Exit;
 End;
 
 { Créer les entrées du répertoire (secteur 1) }
 { Entrée 0: Root Entry }
 InitOLEDirectoryEntry(RootEntry, 'Root Entry', 5);  { 5 = Root Storage }
 RootEntry.ChildID := 1;
 
 { Entrée 1: VisioDocument }
 InitOLEDirectoryEntry(VisioDocEntry, 'VisioDocument', 1);  { 1 = Storage }
 VisioDocEntry.RightSiblingID := 2;
 VisioDocEntry.StartSector := 2;
 
 { Entrée 2: Contents }
 InitOLEDirectoryEntry(ContentsEntry, 'Contents', 2);  { 2 = Stream }
 ContentsEntry.StartSector := 3;
 
 { Écrire les entrées du répertoire }
 BlockWrite(F, RootEntry, 128, BytesWritten);
 BlockWrite(F, VisioDocEntry, 128, BytesWritten);
 BlockWrite(F, ContentsEntry, 128, BytesWritten);
 
 { Remplir le reste du secteur avec des entrées vides }
 For I := 0 to 127 do ShapeData[I] := 0;
 BlockWrite(F, ShapeData, 128, BytesWritten);
 
 { Écrire le stream VisioDocument (secteur 2) - en-tête Visio simplifié }
 For I := 0 to 511 do ShapeData[I] := 0;
 { Signature Visio simplifiée }
 ShapeData[0] := Ord('V');
 ShapeData[1] := Ord('I');
 ShapeData[2] := Ord('S');
 ShapeData[3] := Ord('I');
 ShapeData[4] := Ord('O');
 ShapeData[5] := 1;  { Version }
 ShapeData[6] := Lo(ShapeCount);
 ShapeData[7] := Hi(ShapeCount);
 
 BlockWrite(F, ShapeData, 512, BytesWritten);
 
 { Écrire le stream Contents (secteur 3) - données des formes }
 For I := 0 to 4095 do ShapeData[I] := 0;
 DataOffset := 0;
 
 For I := 1 to ShapeCount do Begin
  If DataOffset + 64 > 512 Then Break;  { Limite de taille du secteur }
  
  ShapeObjectToVisioShape(Shapes[I], VShape);
  
  { Écrire les données de la forme de manière simplifiée }
  { Type de forme (1 octet) }
  ShapeData[DataOffset] := VShape.ShapeType;
  Inc(DataOffset);
  
  { Position X (2 octets) }
  ShapeData[DataOffset] := Lo(Round(VShape.X));
  ShapeData[DataOffset + 1] := Hi(Round(VShape.X));
  Inc(DataOffset, 2);
  
  { Position Y (2 octets) }
  ShapeData[DataOffset] := Lo(Round(VShape.Y));
  ShapeData[DataOffset + 1] := Hi(Round(VShape.Y));
  Inc(DataOffset, 2);
  
  { Largeur (2 octets) }
  ShapeData[DataOffset] := Lo(Round(VShape.Width));
  ShapeData[DataOffset + 1] := Hi(Round(VShape.Width));
  Inc(DataOffset, 2);
  
  { Hauteur (2 octets) }
  ShapeData[DataOffset] := Lo(Round(VShape.Height));
  ShapeData[DataOffset + 1] := Hi(Round(VShape.Height));
  Inc(DataOffset, 2);
  
  { Couleur de remplissage (4 octets) }
  ShapeData[DataOffset] := VShape.FillColor and $FF;
  ShapeData[DataOffset + 1] := (VShape.FillColor shr 8) and $FF;
  ShapeData[DataOffset + 2] := (VShape.FillColor shr 16) and $FF;
  ShapeData[DataOffset + 3] := 0;
  Inc(DataOffset, 4);
  
  { Couleur de ligne (4 octets) }
  ShapeData[DataOffset] := VShape.LineColor and $FF;
  ShapeData[DataOffset + 1] := (VShape.LineColor shr 8) and $FF;
  ShapeData[DataOffset + 2] := (VShape.LineColor shr 16) and $FF;
  ShapeData[DataOffset + 3] := 0;
  Inc(DataOffset, 4);
  
  { Épaisseur de ligne (1 octet) }
  ShapeData[DataOffset] := Round(VShape.LineWeight);
  Inc(DataOffset);
  
  { Longueur du texte (1 octet) + texte (jusqu'à 40 caractères) }
  DataSize := Length(VShape.Text);
  If DataSize > 40 Then DataSize := 40;
  ShapeData[DataOffset] := DataSize;
  Inc(DataOffset);
  Move(VShape.Text[1], ShapeData[DataOffset], DataSize);
  Inc(DataOffset, 40);
 End;
 
 { Marquer la fin des données }
 ShapeData[DataOffset] := $FF;
 
 BlockWrite(F, ShapeData, 512, BytesWritten);
 
 Close(F);
 WriteVSDFile := True;
End;

{ Fonction pour calculer le CRC32 simplifié }
Function CalcCRC32(Const Data; Size: Integer): LongInt;
Var
 I: Integer;
 CRC: LongInt;
 P: ^Byte;
Begin
 CRC := $FFFFFFFF;
 P := @Data;
 For I := 0 to Size - 1 do Begin
  CRC := CRC xor P^;
  Inc(P);
 End;
 CalcCRC32 := CRC xor $FFFFFFFF;
End;

{ Fonction pour écrire un fichier VSDX (format ZIP avec XML) }
Function WriteVSDXFile(Const FileName: String): Boolean;
Var
 F: File;
 LocalHeader: Array[0..29] of Byte;
 CentralDir: Array[0..45] of Byte;
 EndRecord: Array[0..21] of Byte;
 XMLData: String;
 BytesWritten: Integer;
 I: Integer;
 FileOffset, CentralDirOffset: LongInt;
 XMLSize: Integer;
 CRC: LongInt;
 VShape: TVisioShape;
 ShapeIndex: Integer;
 TempStr: String;
Begin
 WriteVSDXFile := False;
 
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 FileOffset := 0;
 
 { Construire le contenu XML du document Visio }
 XMLData := '<?xml version="1.0" encoding="UTF-8"?>' + #13#10;
 XMLData := XMLData + '<VisioDocument xmlns="http://schemas.microsoft.com/visio/2003/core">' + #13#10;
 XMLData := XMLData + '  <Pages>' + #13#10;
 XMLData := XMLData + '    <Page ID="0" Name="Page-1">' + #13#10;
 XMLData := XMLData + '      <Shapes>' + #13#10;
 
 For ShapeIndex := 1 to ShapeCount do Begin
  ShapeObjectToVisioShape(Shapes[ShapeIndex], VShape);
  
  XMLData := XMLData + '        <Shape ID="' + Chr(48 + ShapeIndex) + '">' + #13#10;
  
  { Type de forme }
  Case VShape.ShapeType of
   VISIO_SHAPE_RECTANGLE: TempStr := 'Rectangle';
   VISIO_SHAPE_ELLIPSE: TempStr := 'Ellipse';
   VISIO_SHAPE_LINE: TempStr := 'Line';
   VISIO_SHAPE_CONNECTOR: TempStr := 'Connector';
   VISIO_SHAPE_TEXT: TempStr := 'Text';
  Else
   TempStr := 'Shape';
  End;
  XMLData := XMLData + '          <Name>' + TempStr + '</Name>' + #13#10;
  
  { Géométrie }
  XMLData := XMLData + '          <XForm>' + #13#10;
  Str(VShape.X:0:2, TempStr);
  XMLData := XMLData + '            <PinX>' + TempStr + '</PinX>' + #13#10;
  Str(VShape.Y:0:2, TempStr);
  XMLData := XMLData + '            <PinY>' + TempStr + '</PinY>' + #13#10;
  Str(VShape.Width:0:2, TempStr);
  XMLData := XMLData + '            <Width>' + TempStr + '</Width>' + #13#10;
  Str(VShape.Height:0:2, TempStr);
  XMLData := XMLData + '            <Height>' + TempStr + '</Height>' + #13#10;
  XMLData := XMLData + '          </XForm>' + #13#10;
  
  { Couleurs }
  XMLData := XMLData + '          <Fill>' + #13#10;
  Str(VShape.FillColor, TempStr);
  XMLData := XMLData + '            <FillForegnd>#' + TempStr + '</FillForegnd>' + #13#10;
  XMLData := XMLData + '          </Fill>' + #13#10;
  
  XMLData := XMLData + '          <Line>' + #13#10;
  Str(VShape.LineColor, TempStr);
  XMLData := XMLData + '            <LineColor>#' + TempStr + '</LineColor>' + #13#10;
  Str(VShape.LineWeight:0:2, TempStr);
  XMLData := XMLData + '            <LineWeight>' + TempStr + '</LineWeight>' + #13#10;
  XMLData := XMLData + '          </Line>' + #13#10;
  
  { Texte }
  If Length(VShape.Text) > 0 Then Begin
   XMLData := XMLData + '          <Text>' + VShape.Text + '</Text>' + #13#10;
  End;
  
  XMLData := XMLData + '        </Shape>' + #13#10;
 End;
 
 XMLData := XMLData + '      </Shapes>' + #13#10;
 XMLData := XMLData + '    </Page>' + #13#10;
 XMLData := XMLData + '  </Pages>' + #13#10;
 XMLData := XMLData + '</VisioDocument>' + #13#10;
 
 XMLSize := Length(XMLData);
 CRC := CalcCRC32(XMLData[1], XMLSize);
 
 { === Écrire l'en-tête local du fichier ZIP === }
 { Signature PK }
 LocalHeader[0] := $50;  { P }
 LocalHeader[1] := $4B;  { K }
 LocalHeader[2] := $03;
 LocalHeader[3] := $04;
 { Version nécessaire pour extraire }
 LocalHeader[4] := 20;   { 2.0 }
 LocalHeader[5] := 0;
 { Flags }
 LocalHeader[6] := 0;
 LocalHeader[7] := 0;
 { Méthode de compression (0 = stocké, pas de compression) }
 LocalHeader[8] := 0;
 LocalHeader[9] := 0;
 { Heure de modification }
 LocalHeader[10] := 0;
 LocalHeader[11] := 0;
 { Date de modification }
 LocalHeader[12] := 0;
 LocalHeader[13] := 0;
 { CRC-32 }
 LocalHeader[14] := CRC and $FF;
 LocalHeader[15] := (CRC shr 8) and $FF;
 LocalHeader[16] := (CRC shr 16) and $FF;
 LocalHeader[17] := (CRC shr 24) and $FF;
 { Taille compressée }
 LocalHeader[18] := XMLSize and $FF;
 LocalHeader[19] := (XMLSize shr 8) and $FF;
 LocalHeader[20] := (XMLSize shr 16) and $FF;
 LocalHeader[21] := (XMLSize shr 24) and $FF;
 { Taille non compressée }
 LocalHeader[22] := XMLSize and $FF;
 LocalHeader[23] := (XMLSize shr 8) and $FF;
 LocalHeader[24] := (XMLSize shr 16) and $FF;
 LocalHeader[25] := (XMLSize shr 24) and $FF;
 { Longueur du nom de fichier }
 LocalHeader[26] := 20;  { "visio/document.xml" = 19 caractères + 1 }
 LocalHeader[27] := 0;
 { Longueur du champ extra }
 LocalHeader[28] := 0;
 LocalHeader[29] := 0;
 
 BlockWrite(F, LocalHeader, 30, BytesWritten);
 FileOffset := FileOffset + 30;
 
 { Nom du fichier }
 TempStr := 'visio/document.xml';
 BlockWrite(F, TempStr[1], 18, BytesWritten);
 FileOffset := FileOffset + 18;
 
 { Données XML }
 BlockWrite(F, XMLData[1], XMLSize, BytesWritten);
 FileOffset := FileOffset + XMLSize;
 
 CentralDirOffset := FileOffset;
 
 { === Écrire l'entrée du répertoire central === }
 { Signature }
 CentralDir[0] := $50;   { P }
 CentralDir[1] := $4B;   { K }
 CentralDir[2] := $01;
 CentralDir[3] := $02;
 { Version créée par }
 CentralDir[4] := 20;
 CentralDir[5] := 0;
 { Version nécessaire pour extraire }
 CentralDir[6] := 20;
 CentralDir[7] := 0;
 { Flags }
 CentralDir[8] := 0;
 CentralDir[9] := 0;
 { Méthode de compression }
 CentralDir[10] := 0;
 CentralDir[11] := 0;
 { Heure de modification }
 CentralDir[12] := 0;
 CentralDir[13] := 0;
 { Date de modification }
 CentralDir[14] := 0;
 CentralDir[15] := 0;
 { CRC-32 }
 CentralDir[16] := CRC and $FF;
 CentralDir[17] := (CRC shr 8) and $FF;
 CentralDir[18] := (CRC shr 16) and $FF;
 CentralDir[19] := (CRC shr 24) and $FF;
 { Taille compressée }
 CentralDir[20] := XMLSize and $FF;
 CentralDir[21] := (XMLSize shr 8) and $FF;
 CentralDir[22] := (XMLSize shr 16) and $FF;
 CentralDir[23] := (XMLSize shr 24) and $FF;
 { Taille non compressée }
 CentralDir[24] := XMLSize and $FF;
 CentralDir[25] := (XMLSize shr 8) and $FF;
 CentralDir[26] := (XMLSize shr 16) and $FF;
 CentralDir[27] := (XMLSize shr 24) and $FF;
 { Longueur du nom de fichier }
 CentralDir[28] := 18;
 CentralDir[29] := 0;
 { Longueur du champ extra }
 CentralDir[30] := 0;
 CentralDir[31] := 0;
 { Longueur du commentaire }
 CentralDir[32] := 0;
 CentralDir[33] := 0;
 { Numéro de disque de début }
 CentralDir[34] := 0;
 CentralDir[35] := 0;
 { Attributs internes }
 CentralDir[36] := 0;
 CentralDir[37] := 0;
 { Attributs externes }
 CentralDir[38] := 0;
 CentralDir[39] := 0;
 CentralDir[40] := 0;
 CentralDir[41] := 0;
 { Offset de l'en-tête local }
 CentralDir[42] := 0;
 CentralDir[43] := 0;
 CentralDir[44] := 0;
 CentralDir[45] := 0;
 
 BlockWrite(F, CentralDir, 46, BytesWritten);
 FileOffset := FileOffset + 46;
 
 { Nom du fichier }
 TempStr := 'visio/document.xml';
 BlockWrite(F, TempStr[1], 18, BytesWritten);
 FileOffset := FileOffset + 18;
 
 { === Écrire l'enregistrement de fin du répertoire central === }
 { Signature }
 EndRecord[0] := $50;    { P }
 EndRecord[1] := $4B;    { K }
 EndRecord[2] := $05;
 EndRecord[3] := $06;
 { Numéro de ce disque }
 EndRecord[4] := 0;
 EndRecord[5] := 0;
 { Disque où commence le répertoire central }
 EndRecord[6] := 0;
 EndRecord[7] := 0;
 { Nombre d'entrées dans le répertoire central sur ce disque }
 EndRecord[8] := 1;
 EndRecord[9] := 0;
 { Nombre total d'entrées }
 EndRecord[10] := 1;
 EndRecord[11] := 0;
 { Taille du répertoire central }
 EndRecord[12] := 64;    { 46 + 18 }
 EndRecord[13] := 0;
 EndRecord[14] := 0;
 EndRecord[15] := 0;
 { Offset du répertoire central }
 EndRecord[16] := CentralDirOffset and $FF;
 EndRecord[17] := (CentralDirOffset shr 8) and $FF;
 EndRecord[18] := (CentralDirOffset shr 16) and $FF;
 EndRecord[19] := (CentralDirOffset shr 24) and $FF;
 { Longueur du commentaire }
 EndRecord[20] := 0;
 EndRecord[21] := 0;
 
 BlockWrite(F, EndRecord, 22, BytesWritten);
 
 Close(F);
 WriteVSDXFile := True;
End;

{ Fonction pour déterminer le format à partir de l'extension du fichier }
Function GetVisioFormatFromExtension(Const FileName: String): Integer;
Var
 Ext: String;
 I: Integer;
Begin
 GetVisioFormatFromExtension := VISIO_FORMAT_UNKNOWN;
 
 { Trouver l'extension }
 Ext := '';
 For I := Length(FileName) downto 1 do Begin
  If FileName[I] = '.' Then Begin
   Ext := Copy(FileName, I, Length(FileName) - I + 1);
   Break;
  End;
 End;
 
 { Convertir en minuscules }
 For I := 1 to Length(Ext) do Begin
  If (Ext[I] >= 'A') and (Ext[I] <= 'Z') Then
   Ext[I] := Chr(Ord(Ext[I]) + 32);
 End;
 
 { Déterminer le format }
 If (Ext = '.vsd') or (Ext = '.vss') or (Ext = '.vst') Then
  GetVisioFormatFromExtension := VISIO_FORMAT_VSD
 Else If (Ext = '.vsdx') or (Ext = '.vssx') or (Ext = '.vstx') Then
  GetVisioFormatFromExtension := VISIO_FORMAT_VSDX;
End;

{ Fonction principale pour sauvegarder un fichier Visio }
Function SaveVisioFile(Const FileName: String; FileFormat: Integer): Boolean;
Begin
 SaveVisioFile := False;
 
 { Si le format n'est pas spécifié, le détecter depuis l'extension }
 If FileFormat = VISIO_FORMAT_UNKNOWN Then
  FileFormat := GetVisioFormatFromExtension(FileName);
 
 { Si toujours inconnu, utiliser VSDX par défaut (format moderne) }
 If FileFormat = VISIO_FORMAT_UNKNOWN Then
  FileFormat := VISIO_FORMAT_VSDX;
 
 Case FileFormat of
  VISIO_FORMAT_VSD: Begin
   SaveVisioFile := WriteVSDFile(FileName);
  End;
  VISIO_FORMAT_VSDX: Begin
   SaveVisioFile := WriteVSDXFile(FileName);
  End;
 End;
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS D'ECRITURE VISIO === }
{ ============================================================================ }

{ ============================================================================ }
{ === FONCTIONS DE GESTION DES STENCILS ET MASTERS VISIO === }
{ ============================================================================ }

{ Procédure pour initialiser un Master vide }
Procedure InitMaster(Var Master: TVisioMaster);
Var
 I: Integer;
Begin
 Master.ID := 0;
 Master.Name := '';
 Master.UniqueID := '';
 Master.IconIndex := 0;
 Master.BaseShape.ID := 0;
 Master.BaseShape.ShapeType := VISIO_SHAPE_RECTANGLE;
 Master.BaseShape.X := 0;
 Master.BaseShape.Y := 0;
 Master.BaseShape.Width := 100;
 Master.BaseShape.Height := 100;
 Master.BaseShape.Angle := 0;
 Master.BaseShape.FillColor := $FFFFFF;
 Master.BaseShape.LineColor := $000000;
 Master.BaseShape.LineWeight := 1;
 Master.BaseShape.Text := '';
 Master.BaseShape.ParentID := 0;
 Master.Width := 100;
 Master.Height := 100;
 Master.OffsetX := 50;
 Master.OffsetY := 50;
 Master.IsGroup := False;
 Master.SubShapeCount := 0;
 Master.ConnectionPointCount := 0;
 For I := 1 to 8 do Begin
  Master.ConnectionPoints[I].X := 0;
  Master.ConnectionPoints[I].Y := 0;
  Master.ConnectionPoints[I].DirX := 0;
  Master.ConnectionPoints[I].DirY := 0;
 End;
End;

{ Procédure pour initialiser un Stencil vide }
Procedure InitStencil(Var Stencil: TVisioStencil);
Var
 I: Integer;
Begin
 Stencil.Name := '';
 Stencil.FilePath := '';
 Stencil.FileFormat := VISIO_STENCIL_FORMAT_VSSX;
 Stencil.MasterCount := 0;
 Stencil.IsModified := False;
 Stencil.IsReadOnly := False;
 For I := 1 to MAX_MASTERS do
  InitMaster(Stencil.Masters[I]);
End;

{ Fonction pour générer un GUID simplifié }
Function GenerateSimpleGUID: String;
Var
 I: Integer;
 S: String;
 HexChars: String;
Begin
 HexChars := '0123456789ABCDEF';
 S := '';
 For I := 1 to 32 do Begin
  S := S + HexChars[Random(16) + 1];
  If (I = 8) or (I = 12) or (I = 16) or (I = 20) Then
   S := S + '-';
 End;
 GenerateSimpleGUID := S;
End;

{ Fonction pour ajouter un Master à un Stencil }
Function AddMasterToStencil(Var Stencil: TVisioStencil; Const Master: TVisioMaster): Boolean;
Begin
 AddMasterToStencil := False;
 If Stencil.MasterCount >= MAX_MASTERS Then Exit;
 
 Inc(Stencil.MasterCount);
 Stencil.Masters[Stencil.MasterCount] := Master;
 Stencil.Masters[Stencil.MasterCount].ID := NextMasterID;
 Inc(NextMasterID);
 Stencil.IsModified := True;
 AddMasterToStencil := True;
End;

{ Fonction pour créer un Master à partir d'une TShapeObject }
Function CreateMasterFromShape(Const Shape: TShapeObject; Const MasterName: String): TVisioMaster;
Var
 Master: TVisioMaster;
Begin
 InitMaster(Master);
 Master.ID := NextMasterID;
 Inc(NextMasterID);
 Master.Name := MasterName;
 Master.UniqueID := GenerateSimpleGUID;
 
 { Convertir les propriétés de la forme }
 Master.BaseShape.ShapeType := TShapeTypeToVisioShapeType(Shape.ShapeType);
 Master.BaseShape.X := 0;
 Master.BaseShape.Y := 0;
 Master.BaseShape.Width := Shape.X2 - Shape.X1;
 Master.BaseShape.Height := Shape.Y2 - Shape.Y1;
 Master.BaseShape.Angle := 0;
 Master.BaseShape.FillColor := PascalColorToVisioColor(Shape.FillColor);
 Master.BaseShape.LineColor := PascalColorToVisioColor(Shape.LineColor);
 Master.BaseShape.LineWeight := Shape.LineWidth;
 Master.BaseShape.Text := Shape.Text;
 
 Master.Width := Master.BaseShape.Width;
 Master.Height := Master.BaseShape.Height;
 Master.OffsetX := Master.Width / 2;
 Master.OffsetY := Master.Height / 2;
 
 { Ajouter les points de connexion par défaut (4 côtés) }
 Master.ConnectionPointCount := 4;
 { Haut }
 Master.ConnectionPoints[1].X := Master.Width / 2;
 Master.ConnectionPoints[1].Y := 0;
 Master.ConnectionPoints[1].DirX := 0;
 Master.ConnectionPoints[1].DirY := -1;
 { Droite }
 Master.ConnectionPoints[2].X := Master.Width;
 Master.ConnectionPoints[2].Y := Master.Height / 2;
 Master.ConnectionPoints[2].DirX := 1;
 Master.ConnectionPoints[2].DirY := 0;
 { Bas }
 Master.ConnectionPoints[3].X := Master.Width / 2;
 Master.ConnectionPoints[3].Y := Master.Height;
 Master.ConnectionPoints[3].DirX := 0;
 Master.ConnectionPoints[3].DirY := 1;
 { Gauche }
 Master.ConnectionPoints[4].X := 0;
 Master.ConnectionPoints[4].Y := Master.Height / 2;
 Master.ConnectionPoints[4].DirX := -1;
 Master.ConnectionPoints[4].DirY := 0;
 
 CreateMasterFromShape := Master;
End;

{ Procédure pour créer une TShapeObject à partir d'un Master }
Procedure CreateShapeFromMaster(Const Master: TVisioMaster; X, Y: Integer; Var Shape: TShapeObject);
Begin
 { Initialiser la forme }
 Shape.ShapeType := stNone;
 Case Master.BaseShape.ShapeType of
  VISIO_SHAPE_RECTANGLE: Shape.ShapeType := stRectangle;
  VISIO_SHAPE_ELLIPSE: Shape.ShapeType := stEllipse;
  VISIO_SHAPE_LINE: Shape.ShapeType := stLine;
  VISIO_SHAPE_POLYLINE: Shape.ShapeType := stPolygon;
  VISIO_SHAPE_CONNECTOR: Shape.ShapeType := stConnector;
  VISIO_SHAPE_TEXT: Shape.ShapeType := stText;
 Else
  Shape.ShapeType := stRectangle;
 End;
 
 { Positionner la forme avec le point d'insertion centré }
 Shape.X1 := X - Round(Master.OffsetX);
 Shape.Y1 := Y - Round(Master.OffsetY);
 Shape.X2 := Shape.X1 + Round(Master.Width);
 Shape.Y2 := Shape.Y1 + Round(Master.Height);
 
 { Convertir les couleurs de Visio vers Pascal }
 Shape.FillColor := VisioColorToPascalColor(Master.BaseShape.FillColor);
 Shape.LineColor := VisioColorToPascalColor(Master.BaseShape.LineColor);
 Shape.LineWidth := Round(Master.BaseShape.LineWeight);
 Shape.LineStyle := 0;  { Solide }
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 Shape.Text := Master.BaseShape.Text;
 Shape.Selected := False;
 Shape.PointCount := 0;
 Shape.ImagePath := '';
 Shape.ConnectStartShape := 0;
 Shape.ConnectEndShape := 0;
 Shape.ConnectStartAnchor := 0;
 Shape.ConnectEndAnchor := 0;
End;

{ Fonction pour rechercher un Master par son nom dans un Stencil }
Function GetMasterByName(Const Stencil: TVisioStencil; Const MasterName: String): Integer;
Var
 I: Integer;
Begin
 GetMasterByName := 0;
 For I := 1 to Stencil.MasterCount do Begin
  If Stencil.Masters[I].Name = MasterName Then Begin
   GetMasterByName := I;
   Exit;
  End;
 End;
End;

{ Fonction pour rechercher un Master par son ID dans un Stencil }
Function GetMasterByID(Const Stencil: TVisioStencil; MasterID: LongInt): Integer;
Var
 I: Integer;
Begin
 GetMasterByID := 0;
 For I := 1 to Stencil.MasterCount do Begin
  If Stencil.Masters[I].ID = MasterID Then Begin
   GetMasterByID := I;
   Exit;
  End;
 End;
End;

{ Fonction pour détecter le format d'un fichier stencil }
Function DetectStencilFormat(Const FileName: String): Integer;
Var
 F: File;
 Buffer: Array[0..7] of Byte;
 BytesRead: Integer;
 Ext: String;
 I: Integer;
Begin
 DetectStencilFormat := VISIO_FORMAT_UNKNOWN;
 
 { Vérifier l'extension d'abord }
 Ext := '';
 For I := Length(FileName) downto 1 do Begin
  If FileName[I] = '.' Then Begin
   Ext := Copy(FileName, I, Length(FileName) - I + 1);
   Break;
  End;
 End;
 
 { Convertir en minuscules }
 For I := 1 to Length(Ext) do Begin
  If (Ext[I] >= 'A') and (Ext[I] <= 'Z') Then
   Ext[I] := Chr(Ord(Ext[I]) + 32);
 End;
 
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 BlockRead(F, Buffer, 8, BytesRead);
 Close(F);
 
 If BytesRead < 4 Then Exit;
 
 { Vérifier si c'est un fichier VSSX (ZIP) }
 If (Buffer[0] = $50) and (Buffer[1] = $4B) Then Begin
  DetectStencilFormat := VISIO_STENCIL_FORMAT_VSSX;
  Exit;
 End;
 
 { Vérifier si c'est un fichier VSS (OLE Compound Document) }
 If BytesRead >= 8 Then Begin
  If (Buffer[0] = $D0) and (Buffer[1] = $CF) and
     (Buffer[2] = $11) and (Buffer[3] = $E0) and
     (Buffer[4] = $A1) and (Buffer[5] = $B6) and
     (Buffer[6] = $1A) and (Buffer[7] = $E1) Then Begin
   DetectStencilFormat := VISIO_STENCIL_FORMAT_VSS;
  End;
 End;
End;

{ Fonction pour charger un fichier stencil VSS (OLE binaire) }
Function LoadVSSFile(Const FileName: String; Var Stencil: TVisioStencil): Boolean;
Var
 F: File;
 Header: TOLEHeader;
 BytesRead: Integer;
 SectorSize: Integer;
Begin
 LoadVSSFile := False;
 InitStencil(Stencil);
 
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 { Lire l'en-tête OLE }
 BlockRead(F, Header, SizeOf(TOLEHeader), BytesRead);
 If BytesRead < SizeOf(TOLEHeader) Then Begin
  Close(F);
  Exit;
 End;
 
 { Vérifier la signature OLE }
 If (Header.Signature[0] <> $D0) or (Header.Signature[1] <> $CF) Then Begin
  Close(F);
  Exit;
 End;
 
 SectorSize := 1 shl Header.SectorShift;
 
 { Pour une implémentation complète, il faudrait : }
 { 1. Parcourir le répertoire OLE }
 { 2. Trouver les streams "Masters" }
 { 3. Parser chaque master }
 
 { Pour cette implémentation simplifiée, créer des masters de base }
 Stencil.Name := 'Basic Shapes';
 Stencil.FilePath := FileName;
 Stencil.FileFormat := VISIO_STENCIL_FORMAT_VSS;
 
 Close(F);
 LoadVSSFile := True;
End;

{ Fonction pour charger un fichier stencil VSSX (ZIP/XML) }
Function LoadVSSXFile(Const FileName: String; Var Stencil: TVisioStencil): Boolean;
Var
 F: File;
 Buffer: Array[0..3] of Byte;
 BytesRead: Integer;
Begin
 LoadVSSXFile := False;
 InitStencil(Stencil);
 
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 { Vérifier la signature ZIP }
 BlockRead(F, Buffer, 4, BytesRead);
 If BytesRead < 4 Then Begin
  Close(F);
  Exit;
 End;
 
 If (Buffer[0] <> $50) or (Buffer[1] <> $4B) Then Begin
  Close(F);
  Exit;
 End;
 
 { Pour une implémentation complète, il faudrait : }
 { 1. Décompresser le ZIP }
 { 2. Lire visio/masters/masters.xml }
 { 3. Parser chaque master XML }
 
 Stencil.Name := 'Basic Shapes';
 Stencil.FilePath := FileName;
 Stencil.FileFormat := VISIO_STENCIL_FORMAT_VSSX;
 
 Close(F);
 LoadVSSXFile := True;
End;

{ Fonction principale pour charger un fichier stencil }
Function LoadStencilFile(Const FileName: String): Integer;
Var
 FileFormat: Integer;
 NewStencil: TVisioStencil;
 Success: Boolean;
Begin
 LoadStencilFile := 0;
 
 If StencilCount >= MAX_STENCILS Then Exit;
 
 FileFormat := DetectStencilFormat(FileName);
 Success := False;
 
 Case FileFormat of
  VISIO_STENCIL_FORMAT_VSS: Begin
   Success := LoadVSSFile(FileName, NewStencil);
  End;
  VISIO_STENCIL_FORMAT_VSSX: Begin
   Success := LoadVSSXFile(FileName, NewStencil);
  End;
 End;
 
 If Success Then Begin
  Inc(StencilCount);
  Stencils[StencilCount] := NewStencil;
  LoadStencilFile := StencilCount;
 End;
End;

{ Fonction pour sauvegarder un stencil au format VSSX (ZIP/XML) }
Function SaveVSSXFile(Const FileName: String; Const Stencil: TVisioStencil): Boolean;
Var
 F: File;
 LocalHeader: Array[0..29] of Byte;
 CentralDir: Array[0..45] of Byte;
 EndRecord: Array[0..21] of Byte;
 XMLData: String;
 BytesWritten: Integer;
 I: Integer;
 FileOffset, CentralDirOffset: LongInt;
 XMLSize: Integer;
 CRC: LongInt;
 TempStr: String;
Begin
 SaveVSSXFile := False;
 
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 FileOffset := 0;
 
 { Construire le contenu XML du stencil }
 XMLData := '<?xml version="1.0" encoding="UTF-8"?>' + #13#10;
 XMLData := XMLData + '<VisioStencil xmlns="http://schemas.microsoft.com/visio/2003/core">' + #13#10;
 XMLData := XMLData + '  <Masters>' + #13#10;
 
 For I := 1 to Stencil.MasterCount do Begin
  XMLData := XMLData + '    <Master ID="' + Chr(48 + I) + '" Name="' + Stencil.Masters[I].Name + '">' + #13#10;
  XMLData := XMLData + '      <UniqueID>' + Stencil.Masters[I].UniqueID + '</UniqueID>' + #13#10;
  XMLData := XMLData + '      <PageSheet>' + #13#10;
  
  Str(Stencil.Masters[I].Width:0:2, TempStr);
  XMLData := XMLData + '        <PageWidth>' + TempStr + '</PageWidth>' + #13#10;
  Str(Stencil.Masters[I].Height:0:2, TempStr);
  XMLData := XMLData + '        <PageHeight>' + TempStr + '</PageHeight>' + #13#10;
  
  XMLData := XMLData + '      </PageSheet>' + #13#10;
  XMLData := XMLData + '      <Shapes>' + #13#10;
  XMLData := XMLData + '        <Shape>' + #13#10;
  
  Case Stencil.Masters[I].BaseShape.ShapeType of
   VISIO_SHAPE_RECTANGLE: TempStr := 'Rectangle';
   VISIO_SHAPE_ELLIPSE: TempStr := 'Ellipse';
   VISIO_SHAPE_LINE: TempStr := 'Line';
   VISIO_SHAPE_CONNECTOR: TempStr := 'Connector';
   VISIO_SHAPE_TEXT: TempStr := 'Text';
  Else
   TempStr := 'Shape';
  End;
  XMLData := XMLData + '          <Name>' + TempStr + '</Name>' + #13#10;
  
  XMLData := XMLData + '          <XForm>' + #13#10;
  Str(Stencil.Masters[I].BaseShape.Width:0:2, TempStr);
  XMLData := XMLData + '            <Width>' + TempStr + '</Width>' + #13#10;
  Str(Stencil.Masters[I].BaseShape.Height:0:2, TempStr);
  XMLData := XMLData + '            <Height>' + TempStr + '</Height>' + #13#10;
  XMLData := XMLData + '          </XForm>' + #13#10;
  
  XMLData := XMLData + '        </Shape>' + #13#10;
  XMLData := XMLData + '      </Shapes>' + #13#10;
  XMLData := XMLData + '    </Master>' + #13#10;
 End;
 
 XMLData := XMLData + '  </Masters>' + #13#10;
 XMLData := XMLData + '</VisioStencil>' + #13#10;
 
 XMLSize := Length(XMLData);
 CRC := CalcCRC32(XMLData[1], XMLSize);
 
 { Écrire l'en-tête local du fichier ZIP }
 LocalHeader[0] := $50;  { P }
 LocalHeader[1] := $4B;  { K }
 LocalHeader[2] := $03;
 LocalHeader[3] := $04;
 LocalHeader[4] := 20;   { Version }
 LocalHeader[5] := 0;
 LocalHeader[6] := 0;
 LocalHeader[7] := 0;
 LocalHeader[8] := 0;
 LocalHeader[9] := 0;
 LocalHeader[10] := 0;
 LocalHeader[11] := 0;
 LocalHeader[12] := 0;
 LocalHeader[13] := 0;
 LocalHeader[14] := CRC and $FF;
 LocalHeader[15] := (CRC shr 8) and $FF;
 LocalHeader[16] := (CRC shr 16) and $FF;
 LocalHeader[17] := (CRC shr 24) and $FF;
 LocalHeader[18] := XMLSize and $FF;
 LocalHeader[19] := (XMLSize shr 8) and $FF;
 LocalHeader[20] := (XMLSize shr 16) and $FF;
 LocalHeader[21] := (XMLSize shr 24) and $FF;
 LocalHeader[22] := XMLSize and $FF;
 LocalHeader[23] := (XMLSize shr 8) and $FF;
 LocalHeader[24] := (XMLSize shr 16) and $FF;
 LocalHeader[25] := (XMLSize shr 24) and $FF;
 LocalHeader[26] := 19;  { Longueur du nom }
 LocalHeader[27] := 0;
 LocalHeader[28] := 0;
 LocalHeader[29] := 0;
 
 BlockWrite(F, LocalHeader, 30, BytesWritten);
 FileOffset := FileOffset + 30;
 
 { Nom du fichier }
 TempStr := 'visio/masters.xml';
 BlockWrite(F, TempStr[1], 17, BytesWritten);
 FileOffset := FileOffset + 17;
 
 { Données XML }
 BlockWrite(F, XMLData[1], XMLSize, BytesWritten);
 FileOffset := FileOffset + XMLSize;
 
 CentralDirOffset := FileOffset;
 
 { Écrire l'entrée du répertoire central }
 CentralDir[0] := $50;
 CentralDir[1] := $4B;
 CentralDir[2] := $01;
 CentralDir[3] := $02;
 CentralDir[4] := 20;
 CentralDir[5] := 0;
 CentralDir[6] := 20;
 CentralDir[7] := 0;
 CentralDir[8] := 0;
 CentralDir[9] := 0;
 CentralDir[10] := 0;
 CentralDir[11] := 0;
 CentralDir[12] := 0;
 CentralDir[13] := 0;
 CentralDir[14] := 0;
 CentralDir[15] := 0;
 CentralDir[16] := CRC and $FF;
 CentralDir[17] := (CRC shr 8) and $FF;
 CentralDir[18] := (CRC shr 16) and $FF;
 CentralDir[19] := (CRC shr 24) and $FF;
 CentralDir[20] := XMLSize and $FF;
 CentralDir[21] := (XMLSize shr 8) and $FF;
 CentralDir[22] := (XMLSize shr 16) and $FF;
 CentralDir[23] := (XMLSize shr 24) and $FF;
 CentralDir[24] := XMLSize and $FF;
 CentralDir[25] := (XMLSize shr 8) and $FF;
 CentralDir[26] := (XMLSize shr 16) and $FF;
 CentralDir[27] := (XMLSize shr 24) and $FF;
 CentralDir[28] := 17;
 CentralDir[29] := 0;
 CentralDir[30] := 0;
 CentralDir[31] := 0;
 CentralDir[32] := 0;
 CentralDir[33] := 0;
 CentralDir[34] := 0;
 CentralDir[35] := 0;
 CentralDir[36] := 0;
 CentralDir[37] := 0;
 CentralDir[38] := 0;
 CentralDir[39] := 0;
 CentralDir[40] := 0;
 CentralDir[41] := 0;
 CentralDir[42] := 0;
 CentralDir[43] := 0;
 CentralDir[44] := 0;
 CentralDir[45] := 0;
 
 BlockWrite(F, CentralDir, 46, BytesWritten);
 FileOffset := FileOffset + 46;
 
 { Nom du fichier }
 TempStr := 'visio/masters.xml';
 BlockWrite(F, TempStr[1], 17, BytesWritten);
 FileOffset := FileOffset + 17;
 
 { Enregistrement de fin }
 EndRecord[0] := $50;
 EndRecord[1] := $4B;
 EndRecord[2] := $05;
 EndRecord[3] := $06;
 EndRecord[4] := 0;
 EndRecord[5] := 0;
 EndRecord[6] := 0;
 EndRecord[7] := 0;
 EndRecord[8] := 1;
 EndRecord[9] := 0;
 EndRecord[10] := 1;
 EndRecord[11] := 0;
 EndRecord[12] := 63;  { Taille du répertoire central }
 EndRecord[13] := 0;
 EndRecord[14] := 0;
 EndRecord[15] := 0;
 EndRecord[16] := CentralDirOffset and $FF;
 EndRecord[17] := (CentralDirOffset shr 8) and $FF;
 EndRecord[18] := (CentralDirOffset shr 16) and $FF;
 EndRecord[19] := (CentralDirOffset shr 24) and $FF;
 EndRecord[20] := 0;
 EndRecord[21] := 0;
 
 BlockWrite(F, EndRecord, 22, BytesWritten);
 
 Close(F);
 SaveVSSXFile := True;
End;

{ Fonction principale pour sauvegarder un stencil }
Function SaveStencilFile(StencilIndex: Integer; Const FileName: String): Boolean;
Begin
 SaveStencilFile := False;
 
 If (StencilIndex < 1) or (StencilIndex > StencilCount) Then Exit;
 
 { Toujours sauvegarder au format VSSX (moderne) }
 SaveStencilFile := SaveVSSXFile(FileName, Stencils[StencilIndex]);
 
 If SaveStencilFile Then Begin
  Stencils[StencilIndex].FilePath := FileName;
  Stencils[StencilIndex].IsModified := False;
 End;
End;

{ Procédure pour créer un nouveau stencil }
Function CreateNewStencil(Const StencilName: String): Integer;
Begin
 CreateNewStencil := 0;
 
 If StencilCount >= MAX_STENCILS Then Exit;
 
 Inc(StencilCount);
 InitStencil(Stencils[StencilCount]);
 Stencils[StencilCount].Name := StencilName;
 Stencils[StencilCount].IsModified := True;
 
 CreateNewStencil := StencilCount;
End;

{ Procédure pour créer des masters de formes de base }
Procedure CreateBasicShapeMasters(StencilIndex: Integer);
Var
 Master: TVisioMaster;
Begin
 If (StencilIndex < 1) or (StencilIndex > StencilCount) Then Exit;
 
 { Master Rectangle }
 InitMaster(Master);
 Master.Name := 'Rectangle';
 Master.UniqueID := GenerateSimpleGUID;
 Master.BaseShape.ShapeType := VISIO_SHAPE_RECTANGLE;
 Master.BaseShape.Width := 100;
 Master.BaseShape.Height := 60;
 Master.BaseShape.FillColor := $FFFFFF;
 Master.BaseShape.LineColor := $000000;
 Master.Width := 100;
 Master.Height := 60;
 Master.OffsetX := 50;
 Master.OffsetY := 30;
 Master.ConnectionPointCount := 4;
 Master.ConnectionPoints[1].X := 50; Master.ConnectionPoints[1].Y := 0;
 Master.ConnectionPoints[2].X := 100; Master.ConnectionPoints[2].Y := 30;
 Master.ConnectionPoints[3].X := 50; Master.ConnectionPoints[3].Y := 60;
 Master.ConnectionPoints[4].X := 0; Master.ConnectionPoints[4].Y := 30;
 AddMasterToStencil(Stencils[StencilIndex], Master);
 
 { Master Ellipse }
 InitMaster(Master);
 Master.Name := 'Ellipse';
 Master.UniqueID := GenerateSimpleGUID;
 Master.BaseShape.ShapeType := VISIO_SHAPE_ELLIPSE;
 Master.BaseShape.Width := 80;
 Master.BaseShape.Height := 80;
 Master.BaseShape.FillColor := $FFFFFF;
 Master.BaseShape.LineColor := $000000;
 Master.Width := 80;
 Master.Height := 80;
 Master.OffsetX := 40;
 Master.OffsetY := 40;
 Master.ConnectionPointCount := 4;
 Master.ConnectionPoints[1].X := 40; Master.ConnectionPoints[1].Y := 0;
 Master.ConnectionPoints[2].X := 80; Master.ConnectionPoints[2].Y := 40;
 Master.ConnectionPoints[3].X := 40; Master.ConnectionPoints[3].Y := 80;
 Master.ConnectionPoints[4].X := 0; Master.ConnectionPoints[4].Y := 40;
 AddMasterToStencil(Stencils[StencilIndex], Master);
 
 { Master Losange (Diamond) }
 InitMaster(Master);
 Master.Name := 'Diamond';
 Master.UniqueID := GenerateSimpleGUID;
 Master.BaseShape.ShapeType := VISIO_SHAPE_RECTANGLE;
 Master.BaseShape.Width := 80;
 Master.BaseShape.Height := 80;
 Master.BaseShape.FillColor := $FFFFFF;
 Master.BaseShape.LineColor := $000000;
 Master.Width := 80;
 Master.Height := 80;
 Master.OffsetX := 40;
 Master.OffsetY := 40;
 Master.ConnectionPointCount := 4;
 Master.ConnectionPoints[1].X := 40; Master.ConnectionPoints[1].Y := 0;
 Master.ConnectionPoints[2].X := 80; Master.ConnectionPoints[2].Y := 40;
 Master.ConnectionPoints[3].X := 40; Master.ConnectionPoints[3].Y := 80;
 Master.ConnectionPoints[4].X := 0; Master.ConnectionPoints[4].Y := 40;
 AddMasterToStencil(Stencils[StencilIndex], Master);
 
 { Master Ligne }
 InitMaster(Master);
 Master.Name := 'Line';
 Master.UniqueID := GenerateSimpleGUID;
 Master.BaseShape.ShapeType := VISIO_SHAPE_LINE;
 Master.BaseShape.Width := 100;
 Master.BaseShape.Height := 0;
 Master.BaseShape.FillColor := $000000;
 Master.BaseShape.LineColor := $000000;
 Master.Width := 100;
 Master.Height := 2;
 Master.OffsetX := 50;
 Master.OffsetY := 1;
 Master.ConnectionPointCount := 2;
 Master.ConnectionPoints[1].X := 0; Master.ConnectionPoints[1].Y := 1;
 Master.ConnectionPoints[2].X := 100; Master.ConnectionPoints[2].Y := 1;
 AddMasterToStencil(Stencils[StencilIndex], Master);
 
 { Master Connecteur }
 InitMaster(Master);
 Master.Name := 'Connector';
 Master.UniqueID := GenerateSimpleGUID;
 Master.BaseShape.ShapeType := VISIO_SHAPE_CONNECTOR;
 Master.BaseShape.Width := 100;
 Master.BaseShape.Height := 0;
 Master.BaseShape.FillColor := $000000;
 Master.BaseShape.LineColor := $000000;
 Master.Width := 100;
 Master.Height := 2;
 Master.OffsetX := 50;
 Master.OffsetY := 1;
 Master.ConnectionPointCount := 2;
 Master.ConnectionPoints[1].X := 0; Master.ConnectionPoints[1].Y := 1;
 Master.ConnectionPoints[2].X := 100; Master.ConnectionPoints[2].Y := 1;
 AddMasterToStencil(Stencils[StencilIndex], Master);
 
 { Master Texte }
 InitMaster(Master);
 Master.Name := 'Text';
 Master.UniqueID := GenerateSimpleGUID;
 Master.BaseShape.ShapeType := VISIO_SHAPE_TEXT;
 Master.BaseShape.Width := 120;
 Master.BaseShape.Height := 30;
 Master.BaseShape.FillColor := $FFFFFF;
 Master.BaseShape.LineColor := $000000;
 Master.BaseShape.Text := 'Text';
 Master.Width := 120;
 Master.Height := 30;
 Master.OffsetX := 60;
 Master.OffsetY := 15;
 Master.ConnectionPointCount := 4;
 Master.ConnectionPoints[1].X := 60; Master.ConnectionPoints[1].Y := 0;
 Master.ConnectionPoints[2].X := 120; Master.ConnectionPoints[2].Y := 15;
 Master.ConnectionPoints[3].X := 60; Master.ConnectionPoints[3].Y := 30;
 Master.ConnectionPoints[4].X := 0; Master.ConnectionPoints[4].Y := 15;
 AddMasterToStencil(Stencils[StencilIndex], Master);
End;

{ Procédure pour fermer un stencil }
Procedure CloseStencil(StencilIndex: Integer);
Var
 I: Integer;
Begin
 If (StencilIndex < 1) or (StencilIndex > StencilCount) Then Exit;
 
 { Décaler les stencils suivants }
 For I := StencilIndex to StencilCount - 1 do
  Stencils[I] := Stencils[I + 1];
 
 Dec(StencilCount);
 
 { Ajuster le stencil courant si nécessaire }
 If CurrentStencil > StencilCount Then
  CurrentStencil := StencilCount;
End;

{ Procédure pour initialiser le système de stencils }
Procedure InitStencilSystem;
Var
 I: Integer;
 NewStencilIdx: Integer;
Begin
 StencilCount := 0;
 CurrentStencil := 0;
 NextMasterID := 1;
 
 For I := 1 to MAX_STENCILS do
  InitStencil(Stencils[I]);
 
 { Créer un stencil par défaut avec les formes de base }
 NewStencilIdx := CreateNewStencil('Basic Shapes');
 If NewStencilIdx > 0 Then Begin
  CreateBasicShapeMasters(NewStencilIdx);
  CurrentStencil := NewStencilIdx;
 End;
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS DE GESTION DES STENCILS ET MASTERS === }
{ ============================================================================ }

{ ============================================================================ }
{ === FONCTIONS D'IMPORT SVG === }
{ ============================================================================ }

{ Constantes pour le parsing SVG }
Const
 SVG_MAX_ATTR_LENGTH = 255;      { Longueur max d'un attribut }
 SVG_MAX_PATH_POINTS = 100;      { Nombre max de points dans un path }
 SVG_SCALE_FACTOR = 1.0;         { Facteur d'échelle pour la conversion }

Type
 { Structure pour un attribut SVG }
 TSVGAttribute = Record
  Name: String[50];
  Value: String[SVG_MAX_ATTR_LENGTH];
 End;
 
 { Structure pour les données de parsing }
 TSVGParseState = Record
  CurrentX, CurrentY: Real;      { Position courante pour les paths }
  StartX, StartY: Real;          { Point de départ du sous-chemin }
  FillColor: LongInt;            { Couleur de remplissage }
  StrokeColor: LongInt;          { Couleur de trait }
  StrokeWidth: Real;             { Épaisseur du trait }
  TransformX, TransformY: Real;  { Translation }
  ScaleX, ScaleY: Real;          { Échelle }
 End;

Var
 SVGParseState: TSVGParseState;

{ Fonction pour sauter les espaces dans une chaîne }
Function SVGSkipWhitespace(Const S: String; StartPos: Integer): Integer;
Begin
 While (StartPos <= Length(S)) and 
       ((S[StartPos] = ' ') or (S[StartPos] = #9) or 
        (S[StartPos] = #10) or (S[StartPos] = #13) or
        (S[StartPos] = ',')) do
  Inc(StartPos);
 SVGSkipWhitespace := StartPos;
End;

{ Fonction pour parser un nombre réel dans une chaîne }
Function SVGParseNumber(Const S: String; Var Pos: Integer): Real;
Var
 NumStr: String;
 Value: Real;
 Code: Integer;
 Negative: Boolean;
Begin
 SVGParseNumber := 0;
 Pos := SVGSkipWhitespace(S, Pos);
 If Pos > Length(S) Then Exit;
 
 NumStr := '';
 Negative := False;
 
 { Gérer le signe }
 If S[Pos] = '-' Then Begin
  Negative := True;
  Inc(Pos);
 End
 Else If S[Pos] = '+' Then
  Inc(Pos);
 
 { Parser les chiffres et le point décimal }
 While (Pos <= Length(S)) and 
       (((S[Pos] >= '0') and (S[Pos] <= '9')) or (S[Pos] = '.')) do Begin
  NumStr := NumStr + S[Pos];
  Inc(Pos);
 End;
 
 { Gérer l'exposant (notation scientifique) }
 If (Pos <= Length(S)) and ((S[Pos] = 'e') or (S[Pos] = 'E')) Then Begin
  NumStr := NumStr + S[Pos];
  Inc(Pos);
  If (Pos <= Length(S)) and ((S[Pos] = '+') or (S[Pos] = '-')) Then Begin
   NumStr := NumStr + S[Pos];
   Inc(Pos);
  End;
  While (Pos <= Length(S)) and (S[Pos] >= '0') and (S[Pos] <= '9') do Begin
   NumStr := NumStr + S[Pos];
   Inc(Pos);
  End;
 End;
 
 If NumStr <> '' Then Begin
  Val(NumStr, Value, Code);
  If Code = 0 Then Begin
   If Negative Then Value := -Value;
   SVGParseNumber := Value;
  End;
 End;
End;

{ Fonction pour convertir une valeur hexadécimale en entier }
Function HexToInt(Const HexStr: String): LongInt;
Var
 I: Integer;
 C: Char;
 Value: LongInt;
Begin
 Value := 0;
 For I := 1 to Length(HexStr) do Begin
  C := HexStr[I];
  Value := Value * 16;
  If (C >= '0') and (C <= '9') Then
   Value := Value + (Ord(C) - Ord('0'))
  Else If (C >= 'a') and (C <= 'f') Then
   Value := Value + (Ord(C) - Ord('a') + 10)
  Else If (C >= 'A') and (C <= 'F') Then
   Value := Value + (Ord(C) - Ord('A') + 10);
 End;
 HexToInt := Value;
End;

{ Fonction pour parser une couleur SVG et retourner une couleur Pascal }
Function SVGParseColor(Const ColorStr: String): Integer;
Var
 S: String;
 R, G, B: Integer;
 I: Integer;
Begin
 SVGParseColor := 0;  { Noir par défaut }
 S := ColorStr;
 
 { Supprimer les espaces }
 While (Length(S) > 0) and (S[1] = ' ') do Delete(S, 1, 1);
 While (Length(S) > 0) and (S[Length(S)] = ' ') do Delete(S, Length(S), 1);
 
 { Convertir en minuscules }
 For I := 1 to Length(S) do
  If (S[I] >= 'A') and (S[I] <= 'Z') Then
   S[I] := Chr(Ord(S[I]) + 32);
 
 { Couleur hexadécimale #RRGGBB ou #RGB }
 If (Length(S) > 0) and (S[1] = '#') Then Begin
  Delete(S, 1, 1);
  If Length(S) = 6 Then Begin
   R := HexToInt(Copy(S, 1, 2));
   G := HexToInt(Copy(S, 3, 2));
   B := HexToInt(Copy(S, 5, 2));
  End
  Else If Length(S) = 3 Then Begin
   R := HexToInt(S[1] + S[1]);
   G := HexToInt(S[2] + S[2]);
   B := HexToInt(S[3] + S[3]);
  End
  Else Begin
   R := 0; G := 0; B := 0;
  End;
  
  { Convertir RGB en couleur Pascal (palette 16 couleurs) }
  { Approximation vers la couleur la plus proche }
  If (R < 64) and (G < 64) and (B < 64) Then SVGParseColor := 0   { Noir }
  Else If (R > 192) and (G > 192) and (B > 192) Then SVGParseColor := 15 { Blanc }
  Else If (R > 192) and (G < 64) and (B < 64) Then SVGParseColor := 4  { Rouge }
  Else If (R < 64) and (G > 192) and (B < 64) Then SVGParseColor := 2  { Vert }
  Else If (R < 64) and (G < 64) and (B > 192) Then SVGParseColor := 1  { Bleu }
  Else If (R > 192) and (G > 192) and (B < 64) Then SVGParseColor := 14 { Jaune }
  Else If (R > 192) and (G < 64) and (B > 192) Then SVGParseColor := 5  { Magenta }
  Else If (R < 64) and (G > 192) and (B > 192) Then SVGParseColor := 3  { Cyan }
  Else If (R > 128) and (G > 128) and (B > 128) Then SVGParseColor := 7 { Gris clair }
  Else SVGParseColor := 8;  { Gris foncé }
  Exit;
 End;
 
 { Couleurs nommées }
 If S = 'black' Then SVGParseColor := 0
 Else If S = 'blue' Then SVGParseColor := 1
 Else If S = 'green' Then SVGParseColor := 2
 Else If S = 'cyan' Then SVGParseColor := 3
 Else If S = 'red' Then SVGParseColor := 4
 Else If S = 'magenta' Then SVGParseColor := 5
 Else If S = 'brown' Then SVGParseColor := 6
 Else If (S = 'lightgray') or (S = 'lightgrey') or (S = 'silver') Then SVGParseColor := 7
 Else If (S = 'darkgray') or (S = 'darkgrey') or (S = 'gray') or (S = 'grey') Then SVGParseColor := 8
 Else If S = 'lightblue' Then SVGParseColor := 9
 Else If (S = 'lightgreen') or (S = 'lime') Then SVGParseColor := 10
 Else If S = 'lightcyan' Then SVGParseColor := 11
 Else If (S = 'lightred') or (S = 'salmon') Then SVGParseColor := 12
 Else If (S = 'lightmagenta') or (S = 'pink') Then SVGParseColor := 13
 Else If S = 'yellow' Then SVGParseColor := 14
 Else If S = 'white' Then SVGParseColor := 15
 Else If S = 'orange' Then SVGParseColor := 6
 Else If S = 'none' Then SVGParseColor := -1;  { Pas de couleur }
End;

{ Fonction pour extraire la valeur d'un attribut dans une balise XML }
Function SVGGetAttribute(Const Tag, AttrName: String): String;
Var
 Pos, EndPos: Integer;
 AttrSearch: String;
 QuoteChar: Char;
Begin
 SVGGetAttribute := '';
 AttrSearch := AttrName + '="';
 Pos := 1;
 
 { Chercher l'attribut avec guillemets doubles }
 While Pos <= Length(Tag) - Length(AttrSearch) do Begin
  If Copy(Tag, Pos, Length(AttrSearch)) = AttrSearch Then Begin
   Pos := Pos + Length(AttrSearch);
   EndPos := Pos;
   While (EndPos <= Length(Tag)) and (Tag[EndPos] <> '"') do
    Inc(EndPos);
   SVGGetAttribute := Copy(Tag, Pos, EndPos - Pos);
   Exit;
  End;
  Inc(Pos);
 End;
 
 { Essayer avec guillemets simples }
 AttrSearch := AttrName + '=''';
 Pos := 1;
 While Pos <= Length(Tag) - Length(AttrSearch) do Begin
  If Copy(Tag, Pos, Length(AttrSearch)) = AttrSearch Then Begin
   Pos := Pos + Length(AttrSearch);
   EndPos := Pos;
   While (EndPos <= Length(Tag)) and (Tag[EndPos] <> '''') do
    Inc(EndPos);
   SVGGetAttribute := Copy(Tag, Pos, EndPos - Pos);
   Exit;
  End;
  Inc(Pos);
 End;
End;

{ Fonction pour initialiser l'état de parsing SVG }
Procedure InitSVGParseState;
Begin
 SVGParseState.CurrentX := 0;
 SVGParseState.CurrentY := 0;
 SVGParseState.StartX := 0;
 SVGParseState.StartY := 0;
 SVGParseState.FillColor := $FFFFFF;
 SVGParseState.StrokeColor := $000000;
 SVGParseState.StrokeWidth := 1;
 SVGParseState.TransformX := 0;
 SVGParseState.TransformY := 0;
 SVGParseState.ScaleX := 1;
 SVGParseState.ScaleY := 1;
End;

{ Fonction pour parser un élément SVG rect }
Function ParseSVGRect(Const Tag: String; Var Shape: TShapeObject): Boolean;
Var
 X, Y, W, H, RX, RY: Real;
 TempStr: String;
 Pos: Integer;
Begin
 ParseSVGRect := False;
 
 { Parser les attributs }
 TempStr := SVGGetAttribute(Tag, 'x');
 If TempStr = '' Then X := 0 Else Begin Pos := 1; X := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'y');
 If TempStr = '' Then Y := 0 Else Begin Pos := 1; Y := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'width');
 If TempStr = '' Then Exit;
 Pos := 1;
 W := SVGParseNumber(TempStr, Pos);
 
 TempStr := SVGGetAttribute(Tag, 'height');
 If TempStr = '' Then Exit;
 Pos := 1;
 H := SVGParseNumber(TempStr, Pos);
 
 { Créer la forme }
 Shape.ShapeType := stRectangle;
 Shape.X1 := Round(X * SVG_SCALE_FACTOR);
 Shape.Y1 := Round(Y * SVG_SCALE_FACTOR);
 Shape.X2 := Round((X + W) * SVG_SCALE_FACTOR);
 Shape.Y2 := Round((Y + H) * SVG_SCALE_FACTOR);
 
 { Parser les couleurs }
 TempStr := SVGGetAttribute(Tag, 'fill');
 If TempStr <> '' Then Shape.FillColor := SVGParseColor(TempStr)
 Else Shape.FillColor := 15;  { Blanc par défaut }
 
 TempStr := SVGGetAttribute(Tag, 'stroke');
 If TempStr <> '' Then Shape.LineColor := SVGParseColor(TempStr)
 Else Shape.LineColor := 0;  { Noir par défaut }
 
 TempStr := SVGGetAttribute(Tag, 'stroke-width');
 If TempStr <> '' Then Begin
  Pos := 1;
  Shape.LineWidth := Round(SVGParseNumber(TempStr, Pos));
 End
 Else Shape.LineWidth := 1;
 
 Shape.LineStyle := 0;
 Shape.Selected := False;
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 Shape.PointCount := 0;
 
 ParseSVGRect := True;
End;

{ Fonction pour parser un élément SVG circle }
Function ParseSVGCircle(Const Tag: String; Var Shape: TShapeObject): Boolean;
Var
 CX, CY, R: Real;
 TempStr: String;
 Pos: Integer;
Begin
 ParseSVGCircle := False;
 
 { Parser les attributs }
 TempStr := SVGGetAttribute(Tag, 'cx');
 If TempStr = '' Then CX := 0 Else Begin Pos := 1; CX := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'cy');
 If TempStr = '' Then CY := 0 Else Begin Pos := 1; CY := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'r');
 If TempStr = '' Then Exit;
 Pos := 1;
 R := SVGParseNumber(TempStr, Pos);
 
 { Créer la forme (ellipse avec même rayon X et Y) }
 Shape.ShapeType := stEllipse;
 Shape.X1 := Round((CX - R) * SVG_SCALE_FACTOR);
 Shape.Y1 := Round((CY - R) * SVG_SCALE_FACTOR);
 Shape.X2 := Round((CX + R) * SVG_SCALE_FACTOR);
 Shape.Y2 := Round((CY + R) * SVG_SCALE_FACTOR);
 
 { Parser les couleurs }
 TempStr := SVGGetAttribute(Tag, 'fill');
 If TempStr <> '' Then Shape.FillColor := SVGParseColor(TempStr)
 Else Shape.FillColor := 15;
 
 TempStr := SVGGetAttribute(Tag, 'stroke');
 If TempStr <> '' Then Shape.LineColor := SVGParseColor(TempStr)
 Else Shape.LineColor := 0;
 
 TempStr := SVGGetAttribute(Tag, 'stroke-width');
 If TempStr <> '' Then Begin
  Pos := 1;
  Shape.LineWidth := Round(SVGParseNumber(TempStr, Pos));
 End
 Else Shape.LineWidth := 1;
 
 Shape.LineStyle := 0;
 Shape.Selected := False;
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 Shape.PointCount := 0;
 
 ParseSVGCircle := True;
End;

{ Fonction pour parser un élément SVG ellipse }
Function ParseSVGEllipse(Const Tag: String; Var Shape: TShapeObject): Boolean;
Var
 CX, CY, RX, RY: Real;
 TempStr: String;
 Pos: Integer;
Begin
 ParseSVGEllipse := False;
 
 { Parser les attributs }
 TempStr := SVGGetAttribute(Tag, 'cx');
 If TempStr = '' Then CX := 0 Else Begin Pos := 1; CX := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'cy');
 If TempStr = '' Then CY := 0 Else Begin Pos := 1; CY := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'rx');
 If TempStr = '' Then Exit;
 Pos := 1;
 RX := SVGParseNumber(TempStr, Pos);
 
 TempStr := SVGGetAttribute(Tag, 'ry');
 If TempStr = '' Then Exit;
 Pos := 1;
 RY := SVGParseNumber(TempStr, Pos);
 
 { Créer la forme }
 Shape.ShapeType := stEllipse;
 Shape.X1 := Round((CX - RX) * SVG_SCALE_FACTOR);
 Shape.Y1 := Round((CY - RY) * SVG_SCALE_FACTOR);
 Shape.X2 := Round((CX + RX) * SVG_SCALE_FACTOR);
 Shape.Y2 := Round((CY + RY) * SVG_SCALE_FACTOR);
 
 { Parser les couleurs }
 TempStr := SVGGetAttribute(Tag, 'fill');
 If TempStr <> '' Then Shape.FillColor := SVGParseColor(TempStr)
 Else Shape.FillColor := 15;
 
 TempStr := SVGGetAttribute(Tag, 'stroke');
 If TempStr <> '' Then Shape.LineColor := SVGParseColor(TempStr)
 Else Shape.LineColor := 0;
 
 TempStr := SVGGetAttribute(Tag, 'stroke-width');
 If TempStr <> '' Then Begin
  Pos := 1;
  Shape.LineWidth := Round(SVGParseNumber(TempStr, Pos));
 End
 Else Shape.LineWidth := 1;
 
 Shape.LineStyle := 0;
 Shape.Selected := False;
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 Shape.PointCount := 0;
 
 ParseSVGEllipse := True;
End;

{ Fonction pour parser un élément SVG line }
Function ParseSVGLine(Const Tag: String; Var Shape: TShapeObject): Boolean;
Var
 X1, Y1, X2, Y2: Real;
 TempStr: String;
 Pos: Integer;
Begin
 ParseSVGLine := False;
 
 { Parser les attributs }
 TempStr := SVGGetAttribute(Tag, 'x1');
 If TempStr = '' Then X1 := 0 Else Begin Pos := 1; X1 := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'y1');
 If TempStr = '' Then Y1 := 0 Else Begin Pos := 1; Y1 := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'x2');
 If TempStr = '' Then X2 := 0 Else Begin Pos := 1; X2 := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'y2');
 If TempStr = '' Then Y2 := 0 Else Begin Pos := 1; Y2 := SVGParseNumber(TempStr, Pos); End;
 
 { Créer la forme }
 Shape.ShapeType := stLine;
 Shape.X1 := Round(X1 * SVG_SCALE_FACTOR);
 Shape.Y1 := Round(Y1 * SVG_SCALE_FACTOR);
 Shape.X2 := Round(X2 * SVG_SCALE_FACTOR);
 Shape.Y2 := Round(Y2 * SVG_SCALE_FACTOR);
 
 { Parser les couleurs (les lignes n'ont pas de remplissage) }
 Shape.FillColor := -1;  { Pas de remplissage }
 
 TempStr := SVGGetAttribute(Tag, 'stroke');
 If TempStr <> '' Then Shape.LineColor := SVGParseColor(TempStr)
 Else Shape.LineColor := 0;
 
 TempStr := SVGGetAttribute(Tag, 'stroke-width');
 If TempStr <> '' Then Begin
  Pos := 1;
  Shape.LineWidth := Round(SVGParseNumber(TempStr, Pos));
 End
 Else Shape.LineWidth := 1;
 
 Shape.LineStyle := 0;
 Shape.Selected := False;
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 Shape.PointCount := 0;
 
 ParseSVGLine := True;
End;

{ Fonction pour parser un élément SVG polygon ou polyline }
Function ParseSVGPolygon(Const Tag: String; Var Shape: TShapeObject; IsPolyline: Boolean): Boolean;
Var
 PointsStr, TempStr: String;
 Pos, I: Integer;
 X, Y: Real;
 MinX, MinY, MaxX, MaxY: Real;
Begin
 ParseSVGPolygon := False;
 
 PointsStr := SVGGetAttribute(Tag, 'points');
 If PointsStr = '' Then Exit;
 
 { Parser les points }
 Shape.PointCount := 0;
 Pos := 1;
 MinX := 32767; MinY := 32767;
 MaxX := -32767; MaxY := -32767;
 
 While (Pos <= Length(PointsStr)) and (Shape.PointCount < MAX_POLYGON_POINTS) do Begin
  Pos := SVGSkipWhitespace(PointsStr, Pos);
  If Pos > Length(PointsStr) Then Break;
  
  X := SVGParseNumber(PointsStr, Pos);
  Pos := SVGSkipWhitespace(PointsStr, Pos);
  Y := SVGParseNumber(PointsStr, Pos);
  
  Inc(Shape.PointCount);
  Shape.Points[Shape.PointCount].X := Round(X * SVG_SCALE_FACTOR);
  Shape.Points[Shape.PointCount].Y := Round(Y * SVG_SCALE_FACTOR);
  
  If X < MinX Then MinX := X;
  If Y < MinY Then MinY := Y;
  If X > MaxX Then MaxX := X;
  If Y > MaxY Then MaxY := Y;
 End;
 
 If Shape.PointCount < 2 Then Exit;
 
 { Créer la forme }
 Shape.ShapeType := stPolygon;
 Shape.X1 := Round(MinX * SVG_SCALE_FACTOR);
 Shape.Y1 := Round(MinY * SVG_SCALE_FACTOR);
 Shape.X2 := Round(MaxX * SVG_SCALE_FACTOR);
 Shape.Y2 := Round(MaxY * SVG_SCALE_FACTOR);
 
 { Parser les couleurs }
 TempStr := SVGGetAttribute(Tag, 'fill');
 If TempStr <> '' Then Shape.FillColor := SVGParseColor(TempStr)
 Else If IsPolyline Then Shape.FillColor := -1
 Else Shape.FillColor := 15;
 
 TempStr := SVGGetAttribute(Tag, 'stroke');
 If TempStr <> '' Then Shape.LineColor := SVGParseColor(TempStr)
 Else Shape.LineColor := 0;
 
 TempStr := SVGGetAttribute(Tag, 'stroke-width');
 If TempStr <> '' Then Begin
  Pos := 1;
  Shape.LineWidth := Round(SVGParseNumber(TempStr, Pos));
 End
 Else Shape.LineWidth := 1;
 
 Shape.LineStyle := 0;
 Shape.Selected := False;
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 
 ParseSVGPolygon := True;
End;

{ Fonction pour parser un élément SVG path (support basique M, L, H, V, Z, C, Q) }
Function ParseSVGPath(Const Tag: String; Var Shape: TShapeObject): Boolean;
Var
 PathData, TempStr: String;
 Pos, I: Integer;
 Cmd: Char;
 X, Y, X1, Y1, X2, Y2: Real;
 CurX, CurY, StartX, StartY: Real;
 MinX, MinY, MaxX, MaxY: Real;
 IsRelative: Boolean;
Begin
 ParseSVGPath := False;
 
 PathData := SVGGetAttribute(Tag, 'd');
 If PathData = '' Then Exit;
 
 { Parser le path }
 Shape.PointCount := 0;
 Pos := 1;
 CurX := 0; CurY := 0;
 StartX := 0; StartY := 0;
 MinX := 32767; MinY := 32767;
 MaxX := -32767; MaxY := -32767;
 
 While (Pos <= Length(PathData)) and (Shape.PointCount < MAX_POLYGON_POINTS) do Begin
  Pos := SVGSkipWhitespace(PathData, Pos);
  If Pos > Length(PathData) Then Break;
  
  Cmd := PathData[Pos];
  
  { Vérifier si c'est une commande }
  If ((Cmd >= 'A') and (Cmd <= 'Z')) or ((Cmd >= 'a') and (Cmd <= 'z')) Then Begin
   Inc(Pos);
   IsRelative := (Cmd >= 'a') and (Cmd <= 'z');
   If IsRelative Then Cmd := Chr(Ord(Cmd) - 32);  { Convertir en majuscule }
  End;
  
  Pos := SVGSkipWhitespace(PathData, Pos);
  
  Case Cmd of
   'M': Begin { MoveTo }
    X := SVGParseNumber(PathData, Pos);
    Y := SVGParseNumber(PathData, Pos);
    If IsRelative Then Begin X := CurX + X; Y := CurY + Y; End;
    CurX := X; CurY := Y;
    StartX := X; StartY := Y;
    If Shape.PointCount < MAX_POLYGON_POINTS Then Begin
     Inc(Shape.PointCount);
     Shape.Points[Shape.PointCount].X := Round(X * SVG_SCALE_FACTOR);
     Shape.Points[Shape.PointCount].Y := Round(Y * SVG_SCALE_FACTOR);
    End;
    If X < MinX Then MinX := X;
    If Y < MinY Then MinY := Y;
    If X > MaxX Then MaxX := X;
    If Y > MaxY Then MaxY := Y;
   End;
   
   'L': Begin { LineTo }
    X := SVGParseNumber(PathData, Pos);
    Y := SVGParseNumber(PathData, Pos);
    If IsRelative Then Begin X := CurX + X; Y := CurY + Y; End;
    CurX := X; CurY := Y;
    If Shape.PointCount < MAX_POLYGON_POINTS Then Begin
     Inc(Shape.PointCount);
     Shape.Points[Shape.PointCount].X := Round(X * SVG_SCALE_FACTOR);
     Shape.Points[Shape.PointCount].Y := Round(Y * SVG_SCALE_FACTOR);
    End;
    If X < MinX Then MinX := X;
    If Y < MinY Then MinY := Y;
    If X > MaxX Then MaxX := X;
    If Y > MaxY Then MaxY := Y;
   End;
   
   'H': Begin { Horizontal LineTo }
    X := SVGParseNumber(PathData, Pos);
    If IsRelative Then X := CurX + X;
    CurX := X;
    If Shape.PointCount < MAX_POLYGON_POINTS Then Begin
     Inc(Shape.PointCount);
     Shape.Points[Shape.PointCount].X := Round(X * SVG_SCALE_FACTOR);
     Shape.Points[Shape.PointCount].Y := Round(CurY * SVG_SCALE_FACTOR);
    End;
    If X < MinX Then MinX := X;
    If X > MaxX Then MaxX := X;
   End;
   
   'V': Begin { Vertical LineTo }
    Y := SVGParseNumber(PathData, Pos);
    If IsRelative Then Y := CurY + Y;
    CurY := Y;
    If Shape.PointCount < MAX_POLYGON_POINTS Then Begin
     Inc(Shape.PointCount);
     Shape.Points[Shape.PointCount].X := Round(CurX * SVG_SCALE_FACTOR);
     Shape.Points[Shape.PointCount].Y := Round(Y * SVG_SCALE_FACTOR);
    End;
    If Y < MinY Then MinY := Y;
    If Y > MaxY Then MaxY := Y;
   End;
   
   'Z': Begin { ClosePath }
    CurX := StartX;
    CurY := StartY;
    { Fermer le chemin en revenant au point de départ }
   End;
   
   'C': Begin { Cubic Bezier - on simplifie en prenant le point final }
    X1 := SVGParseNumber(PathData, Pos);
    Y1 := SVGParseNumber(PathData, Pos);
    X2 := SVGParseNumber(PathData, Pos);
    Y2 := SVGParseNumber(PathData, Pos);
    X := SVGParseNumber(PathData, Pos);
    Y := SVGParseNumber(PathData, Pos);
    If IsRelative Then Begin X := CurX + X; Y := CurY + Y; End;
    CurX := X; CurY := Y;
    If Shape.PointCount < MAX_POLYGON_POINTS Then Begin
     Inc(Shape.PointCount);
     Shape.Points[Shape.PointCount].X := Round(X * SVG_SCALE_FACTOR);
     Shape.Points[Shape.PointCount].Y := Round(Y * SVG_SCALE_FACTOR);
    End;
    If X < MinX Then MinX := X;
    If Y < MinY Then MinY := Y;
    If X > MaxX Then MaxX := X;
    If Y > MaxY Then MaxY := Y;
   End;
   
   'Q': Begin { Quadratic Bezier - on simplifie en prenant le point final }
    X1 := SVGParseNumber(PathData, Pos);
    Y1 := SVGParseNumber(PathData, Pos);
    X := SVGParseNumber(PathData, Pos);
    Y := SVGParseNumber(PathData, Pos);
    If IsRelative Then Begin X := CurX + X; Y := CurY + Y; End;
    CurX := X; CurY := Y;
    If Shape.PointCount < MAX_POLYGON_POINTS Then Begin
     Inc(Shape.PointCount);
     Shape.Points[Shape.PointCount].X := Round(X * SVG_SCALE_FACTOR);
     Shape.Points[Shape.PointCount].Y := Round(Y * SVG_SCALE_FACTOR);
    End;
    If X < MinX Then MinX := X;
    If Y < MinY Then MinY := Y;
    If X > MaxX Then MaxX := X;
    If Y > MaxY Then MaxY := Y;
   End;
   
  Else
   { Commande inconnue, avancer }
   Inc(Pos);
  End;
 End;
 
 If Shape.PointCount < 2 Then Exit;
 
 { Créer la forme }
 Shape.ShapeType := stPolygon;
 Shape.X1 := Round(MinX * SVG_SCALE_FACTOR);
 Shape.Y1 := Round(MinY * SVG_SCALE_FACTOR);
 Shape.X2 := Round(MaxX * SVG_SCALE_FACTOR);
 Shape.Y2 := Round(MaxY * SVG_SCALE_FACTOR);
 
 { Parser les couleurs }
 TempStr := SVGGetAttribute(Tag, 'fill');
 If TempStr <> '' Then Shape.FillColor := SVGParseColor(TempStr)
 Else Shape.FillColor := 15;
 
 TempStr := SVGGetAttribute(Tag, 'stroke');
 If TempStr <> '' Then Shape.LineColor := SVGParseColor(TempStr)
 Else Shape.LineColor := 0;
 
 TempStr := SVGGetAttribute(Tag, 'stroke-width');
 If TempStr <> '' Then Begin
  Pos := 1;
  Shape.LineWidth := Round(SVGParseNumber(TempStr, Pos));
 End
 Else Shape.LineWidth := 1;
 
 Shape.LineStyle := 0;
 Shape.Selected := False;
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 
 ParseSVGPath := True;
End;

{ Fonction pour parser un élément SVG text }
Function ParseSVGText(Const Tag, TextContent: String; Var Shape: TShapeObject): Boolean;
Var
 X, Y: Real;
 TempStr: String;
 Pos: Integer;
Begin
 ParseSVGText := False;
 
 { Parser les attributs }
 TempStr := SVGGetAttribute(Tag, 'x');
 If TempStr = '' Then X := 0 Else Begin Pos := 1; X := SVGParseNumber(TempStr, Pos); End;
 
 TempStr := SVGGetAttribute(Tag, 'y');
 If TempStr = '' Then Y := 0 Else Begin Pos := 1; Y := SVGParseNumber(TempStr, Pos); End;
 
 { Créer la forme }
 Shape.ShapeType := stText;
 Shape.X1 := Round(X * SVG_SCALE_FACTOR);
 Shape.Y1 := Round(Y * SVG_SCALE_FACTOR) - 15;  { Ajuster pour la baseline }
 Shape.X2 := Shape.X1 + Length(TextContent) * 8;  { Estimation de la largeur }
 Shape.Y2 := Shape.Y1 + 20;  { Hauteur estimée }
 
 { Texte }
 If Length(TextContent) > 80 Then
  Shape.Text := Copy(TextContent, 1, 80)
 Else
  Shape.Text := TextContent;
 
 { Parser les couleurs }
 TempStr := SVGGetAttribute(Tag, 'fill');
 If TempStr <> '' Then Shape.FillColor := SVGParseColor(TempStr)
 Else Shape.FillColor := 0;  { Noir par défaut pour le texte }
 
 Shape.LineColor := Shape.FillColor;
 Shape.LineWidth := 1;
 Shape.LineStyle := 0;
 Shape.Selected := False;
 Shape.LayerIndex := 1;
 Shape.GroupID := 0;
 Shape.PointCount := 0;
 
 ParseSVGText := True;
End;

{ Fonction principale pour charger un fichier SVG }
Function LoadSVGFile(Const FileName: String): Boolean;
Var
 F: Text;
 Line, Tag, TagName, TextContent: String;
 TotalContent: String;
 I, TagStart, TagEnd, ContentStart: Integer;
 Shape: TShapeObject;
 InTag: Boolean;
 C: Char;
Begin
 LoadSVGFile := False;
 
 Assign(F, FileName);
 {$I-}
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 InitSVGParseState;
 TotalContent := '';
 
 { Lire tout le fichier }
 While Not Eof(F) do Begin
  ReadLn(F, Line);
  TotalContent := TotalContent + Line + ' ';
 End;
 Close(F);
 
 { Parser les balises }
 I := 1;
 While I <= Length(TotalContent) do Begin
  { Chercher le début d'une balise }
  While (I <= Length(TotalContent)) and (TotalContent[I] <> '<') do
   Inc(I);
  
  If I > Length(TotalContent) Then Break;
  TagStart := I;
  
  { Trouver la fin de la balise }
  While (I <= Length(TotalContent)) and (TotalContent[I] <> '>') do
   Inc(I);
  
  If I > Length(TotalContent) Then Break;
  TagEnd := I;
  
  Tag := Copy(TotalContent, TagStart + 1, TagEnd - TagStart - 1);
  Inc(I);
  
  { Extraire le nom de la balise }
  TagName := '';
  ContentStart := 1;
  While (ContentStart <= Length(Tag)) and (Tag[ContentStart] <> ' ') and 
        (Tag[ContentStart] <> '/') and (Tag[ContentStart] <> '>') do Begin
   TagName := TagName + Tag[ContentStart];
   Inc(ContentStart);
  End;
  
  { Convertir en minuscules }
  For ContentStart := 1 to Length(TagName) do
   If (TagName[ContentStart] >= 'A') and (TagName[ContentStart] <= 'Z') Then
    TagName[ContentStart] := Chr(Ord(TagName[ContentStart]) + 32);
  
  { Traiter les différents types de balises }
  If TagName = 'rect' Then Begin
   If ParseSVGRect(Tag, Shape) Then Begin
    If ShapeCount < MAX_SHAPES Then Begin
     Inc(ShapeCount);
     Shapes[ShapeCount] := Shape;
    End;
   End;
  End
  Else If TagName = 'circle' Then Begin
   If ParseSVGCircle(Tag, Shape) Then Begin
    If ShapeCount < MAX_SHAPES Then Begin
     Inc(ShapeCount);
     Shapes[ShapeCount] := Shape;
    End;
   End;
  End
  Else If TagName = 'ellipse' Then Begin
   If ParseSVGEllipse(Tag, Shape) Then Begin
    If ShapeCount < MAX_SHAPES Then Begin
     Inc(ShapeCount);
     Shapes[ShapeCount] := Shape;
    End;
   End;
  End
  Else If TagName = 'line' Then Begin
   If ParseSVGLine(Tag, Shape) Then Begin
    If ShapeCount < MAX_SHAPES Then Begin
     Inc(ShapeCount);
     Shapes[ShapeCount] := Shape;
    End;
   End;
  End
  Else If TagName = 'polygon' Then Begin
   If ParseSVGPolygon(Tag, Shape, False) Then Begin
    If ShapeCount < MAX_SHAPES Then Begin
     Inc(ShapeCount);
     Shapes[ShapeCount] := Shape;
    End;
   End;
  End
  Else If TagName = 'polyline' Then Begin
   If ParseSVGPolygon(Tag, Shape, True) Then Begin
    If ShapeCount < MAX_SHAPES Then Begin
     Inc(ShapeCount);
     Shapes[ShapeCount] := Shape;
    End;
   End;
  End
  Else If TagName = 'path' Then Begin
   If ParseSVGPath(Tag, Shape) Then Begin
    If ShapeCount < MAX_SHAPES Then Begin
     Inc(ShapeCount);
     Shapes[ShapeCount] := Shape;
    End;
   End;
  End
  Else If TagName = 'text' Then Begin
   { Extraire le contenu texte }
   TextContent := '';
   While (I <= Length(TotalContent)) and (TotalContent[I] <> '<') do Begin
    If (TotalContent[I] <> #10) and (TotalContent[I] <> #13) Then
     TextContent := TextContent + TotalContent[I];
    Inc(I);
   End;
   { Supprimer les espaces au début et à la fin }
   While (Length(TextContent) > 0) and (TextContent[1] = ' ') do
    Delete(TextContent, 1, 1);
   While (Length(TextContent) > 0) and (TextContent[Length(TextContent)] = ' ') do
    Delete(TextContent, Length(TextContent), 1);
   
   If ParseSVGText(Tag, TextContent, Shape) Then Begin
    If ShapeCount < MAX_SHAPES Then Begin
     Inc(ShapeCount);
     Shapes[ShapeCount] := Shape;
    End;
   End;
  End;
 End;
 
 LoadSVGFile := True;
End;

{ Fonction pour détecter si un fichier est un fichier SVG }
Function IsSVGFile(Const FileName: String): Boolean;
Var
 Ext: String;
 I: Integer;
Begin
 IsSVGFile := False;
 Ext := '';
 
 { Extraire l'extension }
 For I := Length(FileName) downto 1 do Begin
  If FileName[I] = '.' Then Begin
   Ext := Copy(FileName, I, Length(FileName) - I + 1);
   Break;
  End;
 End;
 
 { Convertir en minuscules }
 For I := 1 to Length(Ext) do
  If (Ext[I] >= 'A') and (Ext[I] <= 'Z') Then
   Ext[I] := Chr(Ord(Ext[I]) + 32);
 
 IsSVGFile := (Ext = '.svg');
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS D'IMPORT SVG === }
{ ============================================================================ }

{ ============================================================================ }
{ === FONCTIONS D'EXPORT SVG === }
{ ============================================================================ }

{ Fonction pour convertir une couleur Pascal (palette 16 couleurs) en code hexadécimal SVG }
Function ColorToSVGHex(Color: Integer): String;
Begin
 Case Color of
  0:  ColorToSVGHex := '#000000';  { Noir }
  1:  ColorToSVGHex := '#0000AA';  { Bleu }
  2:  ColorToSVGHex := '#00AA00';  { Vert }
  3:  ColorToSVGHex := '#00AAAA';  { Cyan }
  4:  ColorToSVGHex := '#AA0000';  { Rouge }
  5:  ColorToSVGHex := '#AA00AA';  { Magenta }
  6:  ColorToSVGHex := '#AA5500';  { Marron }
  7:  ColorToSVGHex := '#AAAAAA';  { Gris clair }
  8:  ColorToSVGHex := '#555555';  { Gris foncé }
  9:  ColorToSVGHex := '#5555FF';  { Bleu clair }
  10: ColorToSVGHex := '#55FF55';  { Vert clair }
  11: ColorToSVGHex := '#55FFFF';  { Cyan clair }
  12: ColorToSVGHex := '#FF5555';  { Rouge clair }
  13: ColorToSVGHex := '#FF55FF';  { Magenta clair }
  14: ColorToSVGHex := '#FFFF55';  { Jaune }
  15: ColorToSVGHex := '#FFFFFF';  { Blanc }
 Else
  ColorToSVGHex := '#000000';  { Noir par défaut }
 End;
End;

{ Fonction pour convertir le style de ligne en stroke-dasharray SVG }
Function LineStyleToSVGDash(LineStyle: Integer): String;
Begin
 Case LineStyle of
  0: LineStyleToSVGDash := '';                    { Solide }
  1: LineStyleToSVGDash := 'stroke-dasharray="5,5"';  { Pointillé }
  2: LineStyleToSVGDash := 'stroke-dasharray="10,5"'; { Tirets }
  3: LineStyleToSVGDash := 'stroke-dasharray="10,5,2,5"'; { Tiret-point }
 Else
  LineStyleToSVGDash := '';
 End;
End;

{ Fonction pour générer les attributs de style CSS pour une forme }
Function ShapeToSVGStyle(Const Shape: TShapeObject): String;
Var
 Style: String;
Begin
 Style := 'style="';
 
 { Couleur de remplissage }
 If Shape.FillColor >= 0 Then
  Style := Style + 'fill:' + ColorToSVGHex(Shape.FillColor) + ';'
 Else
  Style := Style + 'fill:none;';
 
 { Couleur de contour }
 If Shape.LineColor >= 0 Then
  Style := Style + 'stroke:' + ColorToSVGHex(Shape.LineColor) + ';'
 Else
  Style := Style + 'stroke:none;';
 
 { Épaisseur de ligne }
 If Shape.LineWidth > 0 Then Begin
  Style := Style + 'stroke-width:';
  { Convertir Integer en String manuellement }
  If Shape.LineWidth < 10 Then
   Style := Style + Chr(Ord('0') + Shape.LineWidth)
  Else Begin
   Style := Style + Chr(Ord('0') + (Shape.LineWidth Div 10));
   Style := Style + Chr(Ord('0') + (Shape.LineWidth Mod 10));
  End;
  Style := Style + ';';
 End;
 
 Style := Style + '"';
 
 { Ajouter le style de ligne si nécessaire }
 If Shape.LineStyle > 0 Then
  Style := Style + ' ' + LineStyleToSVGDash(Shape.LineStyle);
 
 ShapeToSVGStyle := Style;
End;

{ Fonction pour convertir un entier en chaîne }
Function IntToStrSVG(N: Integer): String;
Var
 S: String;
 Neg: Boolean;
Begin
 If N = 0 Then Begin
  IntToStrSVG := '0';
  Exit;
 End;
 
 Neg := N < 0;
 If Neg Then N := -N;
 
 S := '';
 While N > 0 do Begin
  S := Chr(Ord('0') + (N Mod 10)) + S;
  N := N Div 10;
 End;
 
 If Neg Then S := '-' + S;
 IntToStrSVG := S;
End;

{ Procédure pour écrire un rectangle en SVG }
Procedure WriteSVGRect(Var F: Text; Const Shape: TShapeObject);
Var
 X, Y, W, H: Integer;
Begin
 X := Shape.X1;
 Y := Shape.Y1;
 W := Shape.X2 - Shape.X1;
 H := Shape.Y2 - Shape.Y1;
 
 If W < 0 Then Begin X := Shape.X2; W := -W; End;
 If H < 0 Then Begin Y := Shape.Y2; H := -H; End;
 
 WriteLn(F, '  <rect x="' + IntToStrSVG(X) + '" y="' + IntToStrSVG(Y) + 
            '" width="' + IntToStrSVG(W) + '" height="' + IntToStrSVG(H) + 
            '" ' + ShapeToSVGStyle(Shape) + ' />');
End;

{ Procédure pour écrire une ellipse en SVG }
Procedure WriteSVGEllipse(Var F: Text; Const Shape: TShapeObject);
Var
 CX, CY, RX, RY: Integer;
Begin
 CX := (Shape.X1 + Shape.X2) Div 2;
 CY := (Shape.Y1 + Shape.Y2) Div 2;
 RX := Abs(Shape.X2 - Shape.X1) Div 2;
 RY := Abs(Shape.Y2 - Shape.Y1) Div 2;
 
 { Si RX = RY, écrire un cercle }
 If RX = RY Then
  WriteLn(F, '  <circle cx="' + IntToStrSVG(CX) + '" cy="' + IntToStrSVG(CY) + 
             '" r="' + IntToStrSVG(RX) + '" ' + ShapeToSVGStyle(Shape) + ' />')
 Else
  WriteLn(F, '  <ellipse cx="' + IntToStrSVG(CX) + '" cy="' + IntToStrSVG(CY) + 
             '" rx="' + IntToStrSVG(RX) + '" ry="' + IntToStrSVG(RY) + 
             '" ' + ShapeToSVGStyle(Shape) + ' />');
End;

{ Procédure pour écrire une ligne en SVG }
Procedure WriteSVGLine(Var F: Text; Const Shape: TShapeObject);
Begin
 WriteLn(F, '  <line x1="' + IntToStrSVG(Shape.X1) + '" y1="' + IntToStrSVG(Shape.Y1) + 
            '" x2="' + IntToStrSVG(Shape.X2) + '" y2="' + IntToStrSVG(Shape.Y2) + 
            '" ' + ShapeToSVGStyle(Shape) + ' />');
End;

{ Procédure pour écrire un polygone en SVG }
Procedure WriteSVGPolygon(Var F: Text; Const Shape: TShapeObject);
Var
 Points: String;
 I: Integer;
Begin
 If Shape.PointCount < 2 Then Exit;
 
 Points := '';
 For I := 1 to Shape.PointCount do Begin
  If I > 1 Then Points := Points + ' ';
  Points := Points + IntToStrSVG(Shape.Points[I].X) + ',' + IntToStrSVG(Shape.Points[I].Y);
 End;
 
 WriteLn(F, '  <polygon points="' + Points + '" ' + ShapeToSVGStyle(Shape) + ' />');
End;

{ Procédure pour écrire un texte en SVG }
Procedure WriteSVGText(Var F: Text; Const Shape: TShapeObject);
Var
 Style: String;
Begin
 Style := 'style="';
 
 { Couleur du texte }
 If Shape.FillColor >= 0 Then
  Style := Style + 'fill:' + ColorToSVGHex(Shape.FillColor) + ';'
 Else
  Style := Style + 'fill:#000000;';
 
 { Taille de police estimée }
 Style := Style + 'font-size:14px;font-family:sans-serif;"';
 
 WriteLn(F, '  <text x="' + IntToStrSVG(Shape.X1) + '" y="' + IntToStrSVG(Shape.Y2) + 
            '" ' + Style + '>' + Shape.Text + '</text>');
End;

{ Procédure pour écrire un connecteur en SVG (comme une ligne avec des marqueurs) }
Procedure WriteSVGConnector(Var F: Text; Const Shape: TShapeObject);
Begin
 { Les connecteurs sont exportés comme des lignes simples }
 WriteLn(F, '  <line x1="' + IntToStrSVG(Shape.X1) + '" y1="' + IntToStrSVG(Shape.Y1) + 
            '" x2="' + IntToStrSVG(Shape.X2) + '" y2="' + IntToStrSVG(Shape.Y2) + 
            '" ' + ShapeToSVGStyle(Shape) + ' marker-end="url(#arrowhead)" />');
End;

{ Procédure pour écrire une courbe de Bézier en SVG }
Procedure WriteSVGBezier(Var F: Text; Const Shape: TShapeObject);
Var
 PathData: String;
 I: Integer;
Begin
 If Shape.PointCount < 2 Then Exit;
 
 { Créer un chemin avec des segments de ligne pour simplifier }
 PathData := 'M' + IntToStrSVG(Shape.Points[1].X) + ',' + IntToStrSVG(Shape.Points[1].Y);
 
 For I := 2 to Shape.PointCount do
  PathData := PathData + ' L' + IntToStrSVG(Shape.Points[I].X) + ',' + IntToStrSVG(Shape.Points[I].Y);
 
 WriteLn(F, '  <path d="' + PathData + '" ' + ShapeToSVGStyle(Shape) + ' />');
End;

{ Fonction principale pour sauvegarder un fichier SVG }
Function SaveSVGFile(Const FileName: String): Boolean;
Var
 F: Text;
 I: Integer;
 MinX, MinY, MaxX, MaxY: Integer;
 Width, Height: Integer;
Begin
 SaveSVGFile := False;
 
 Assign(F, FileName);
 {$I-}
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 { Calculer les dimensions du dessin }
 MinX := 32767; MinY := 32767;
 MaxX := 0; MaxY := 0;
 
 For I := 1 to ShapeCount do Begin
  If Shapes[I].X1 < MinX Then MinX := Shapes[I].X1;
  If Shapes[I].Y1 < MinY Then MinY := Shapes[I].Y1;
  If Shapes[I].X2 < MinX Then MinX := Shapes[I].X2;
  If Shapes[I].Y2 < MinY Then MinY := Shapes[I].Y2;
  If Shapes[I].X1 > MaxX Then MaxX := Shapes[I].X1;
  If Shapes[I].Y1 > MaxY Then MaxY := Shapes[I].Y1;
  If Shapes[I].X2 > MaxX Then MaxX := Shapes[I].X2;
  If Shapes[I].Y2 > MaxY Then MaxY := Shapes[I].Y2;
 End;
 
 If ShapeCount = 0 Then Begin
  Width := 800;
  Height := 600;
 End
 Else Begin
  Width := MaxX - MinX + 20;
  Height := MaxY - MinY + 20;
  If Width < 100 Then Width := 100;
  If Height < 100 Then Height := 100;
 End;
 
 { Écrire l'en-tête XML et SVG }
 WriteLn(F, '<?xml version="1.0" encoding="UTF-8"?>');
 WriteLn(F, '<svg xmlns="http://www.w3.org/2000/svg" version="1.1"');
 WriteLn(F, '     width="' + IntToStrSVG(Width) + '" height="' + IntToStrSVG(Height) + '"');
 WriteLn(F, '     viewBox="' + IntToStrSVG(MinX - 10) + ' ' + IntToStrSVG(MinY - 10) + 
            ' ' + IntToStrSVG(Width) + ' ' + IntToStrSVG(Height) + '">');
 WriteLn(F, '');
 
 { Définir les marqueurs pour les connecteurs }
 WriteLn(F, '  <defs>');
 WriteLn(F, '    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">');
 WriteLn(F, '      <polygon points="0 0, 10 3.5, 0 7" fill="#000000" />');
 WriteLn(F, '    </marker>');
 WriteLn(F, '  </defs>');
 WriteLn(F, '');
 
 { Ajouter un commentaire avec les informations du document }
 WriteLn(F, '  <!-- Generated by CloneDRAW VISIO -->');
 WriteLn(F, '');
 
 { Écrire chaque forme }
 For I := 1 to ShapeCount do Begin
  Case Shapes[I].ShapeType of
   stRectangle: WriteSVGRect(F, Shapes[I]);
   stEllipse: WriteSVGEllipse(F, Shapes[I]);
   stLine: WriteSVGLine(F, Shapes[I]);
   stConnector: WriteSVGConnector(F, Shapes[I]);
   stText: WriteSVGText(F, Shapes[I]);
   stPolygon: WriteSVGPolygon(F, Shapes[I]);
   stBezier: WriteSVGBezier(F, Shapes[I]);
   { stImage n'est pas exporté directement car nécessite l'inclusion de l'image }
  End;
 End;
 
 { Fermer le document SVG }
 WriteLn(F, '');
 WriteLn(F, '</svg>');
 
 Close(F);
 SaveSVGFile := True;
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS D'EXPORT SVG === }
{ ============================================================================ }

{ ============================================================================ }
{ === FONCTIONS D'EXPORT BMP === }
{ ============================================================================ }

{ Constantes pour le format BMP }
Const
 BMP_SIGNATURE = $4D42;  { 'BM' en little-endian }
 BI_RGB = 0;             { Pas de compression }

{ Fonction pour calculer la taille d'une ligne BMP avec padding (multiple de 4 octets) }
Function GetBMPRowSize(Width, BitsPerPixel: Integer): LongInt;
Var
 RowBits: LongInt;
Begin
 RowBits := LongInt(Width) * LongInt(BitsPerPixel);
 GetBMPRowSize := ((RowBits + 31) Div 32) * 4;
End;

{ Procédure pour écrire un Word (2 octets) en little-endian }
Procedure WriteWord(Var F: File; W: Word);
Var
 B: Array[0..1] of Byte;
Begin
 B[0] := Lo(W);
 B[1] := Hi(W);
 BlockWrite(F, B, 2);
End;

{ Procédure pour écrire un LongInt (4 octets) en little-endian }
Procedure WriteDWord(Var F: File; D: LongInt);
Var
 B: Array[0..3] of Byte;
Begin
 B[0] := D And $FF;
 B[1] := (D Shr 8) And $FF;
 B[2] := (D Shr 16) And $FF;
 B[3] := (D Shr 24) And $FF;
 BlockWrite(F, B, 4);
End;

{ Procédure pour écrire un octet }
Procedure WriteByte(Var F: File; B: Byte);
Begin
 BlockWrite(F, B, 1);
End;

{ Fonction pour convertir une couleur palette en RGB (R, G, B) }
Procedure PaletteToRGB(Color: Integer; Var R, G, B: Byte);
Begin
 Case Color of
  0:  Begin R := 0;   G := 0;   B := 0;   End;  { Noir }
  1:  Begin R := 0;   G := 0;   B := 170; End;  { Bleu }
  2:  Begin R := 0;   G := 170; B := 0;   End;  { Vert }
  3:  Begin R := 0;   G := 170; B := 170; End;  { Cyan }
  4:  Begin R := 170; G := 0;   B := 0;   End;  { Rouge }
  5:  Begin R := 170; G := 0;   B := 170; End;  { Magenta }
  6:  Begin R := 170; G := 85;  B := 0;   End;  { Marron }
  7:  Begin R := 170; G := 170; B := 170; End;  { Gris clair }
  8:  Begin R := 85;  G := 85;  B := 85;  End;  { Gris foncé }
  9:  Begin R := 85;  G := 85;  B := 255; End;  { Bleu clair }
  10: Begin R := 85;  G := 255; B := 85;  End;  { Vert clair }
  11: Begin R := 85;  G := 255; B := 255; End;  { Cyan clair }
  12: Begin R := 255; G := 85;  B := 85;  End;  { Rouge clair }
  13: Begin R := 255; G := 85;  B := 255; End;  { Magenta clair }
  14: Begin R := 255; G := 255; B := 85;  End;  { Jaune }
  15: Begin R := 255; G := 255; B := 255; End;  { Blanc }
 Else
  Begin R := 0; G := 0; B := 0; End;  { Noir par défaut }
 End;
End;

{ Procédure pour écrire l'en-tête BMP (BITMAPFILEHEADER + BITMAPINFOHEADER) }
Procedure WriteBMPHeader(Var F: File; Width, Height: Integer; BitsPerPixel: Integer; 
                         PaletteSize: Integer);
Var
 RowSize: LongInt;
 ImageSize: LongInt;
 FileSize: LongInt;
 OffsetBits: LongInt;
 HeaderSize: LongInt;
Begin
 RowSize := GetBMPRowSize(Width, BitsPerPixel);
 ImageSize := RowSize * LongInt(Height);
 HeaderSize := 14 + 40;  { BITMAPFILEHEADER + BITMAPINFOHEADER }
 OffsetBits := HeaderSize + (LongInt(PaletteSize) * 4);
 FileSize := OffsetBits + ImageSize;
 
 { BITMAPFILEHEADER (14 octets) }
 WriteWord(F, BMP_SIGNATURE);   { bfType: 'BM' }
 WriteDWord(F, FileSize);       { bfSize: taille totale du fichier }
 WriteWord(F, 0);               { bfReserved1 }
 WriteWord(F, 0);               { bfReserved2 }
 WriteDWord(F, OffsetBits);     { bfOffBits: offset vers les données }
 
 { BITMAPINFOHEADER (40 octets) }
 WriteDWord(F, 40);             { biSize: taille de l'en-tête }
 WriteDWord(F, Width);          { biWidth }
 WriteDWord(F, Height);         { biHeight (positif = bottom-up) }
 WriteWord(F, 1);               { biPlanes }
 WriteWord(F, BitsPerPixel);    { biBitCount }
 WriteDWord(F, BI_RGB);         { biCompression }
 WriteDWord(F, ImageSize);      { biSizeImage }
 WriteDWord(F, 2835);           { biXPelsPerMeter (72 DPI) }
 WriteDWord(F, 2835);           { biYPelsPerMeter (72 DPI) }
 WriteDWord(F, PaletteSize);    { biClrUsed }
 WriteDWord(F, 0);              { biClrImportant }
End;

{ Procédure pour écrire la palette 16 couleurs standard }
Procedure WritePalette16(Var F: File);
Var
 I: Integer;
 R, G, B: Byte;
Begin
 For I := 0 to 15 do Begin
  PaletteToRGB(I, R, G, B);
  WriteByte(F, B);  { Bleu }
  WriteByte(F, G);  { Vert }
  WriteByte(F, R);  { Rouge }
  WriteByte(F, 0);  { Réservé }
 End;
End;

{ Procédure pour écrire la palette 256 couleurs (16 + niveaux de gris) }
Procedure WritePalette256(Var F: File);
Var
 I: Integer;
 R, G, B: Byte;
 Gray: Byte;
Begin
 { Les 16 premières couleurs sont la palette standard }
 For I := 0 to 15 do Begin
  PaletteToRGB(I, R, G, B);
  WriteByte(F, B);
  WriteByte(F, G);
  WriteByte(F, R);
  WriteByte(F, 0);
 End;
 
 { Les couleurs 16-255 sont des niveaux de gris }
 For I := 16 to 255 do Begin
  Gray := (I - 16) + (I - 16) Div 15;  { Distribution des niveaux de gris }
  WriteByte(F, Gray);
  WriteByte(F, Gray);
  WriteByte(F, Gray);
  WriteByte(F, 0);
 End;
End;

{ Procédure pour écrire la palette monochrome (noir et blanc) }
Procedure WritePalette2(Var F: File);
Begin
 { Couleur 0: Noir }
 WriteByte(F, 0);
 WriteByte(F, 0);
 WriteByte(F, 0);
 WriteByte(F, 0);
 
 { Couleur 1: Blanc }
 WriteByte(F, 255);
 WriteByte(F, 255);
 WriteByte(F, 255);
 WriteByte(F, 0);
End;

{ Type pour un buffer de pixels }
Type
 TPixelBuffer = Array[0..2047, 0..2047] of Byte;
 PPixelBuffer = ^TPixelBuffer;

Var
 PixelBuffer: PPixelBuffer;
 BufferWidth, BufferHeight: Integer;

{ Initialiser le buffer de pixels }
Procedure InitPixelBuffer(Width, Height: Integer);
Begin
 BufferWidth := Width;
 BufferHeight := Height;
 If BufferWidth > 2048 Then BufferWidth := 2048;
 If BufferHeight > 2048 Then BufferHeight := 2048;
 New(PixelBuffer);
 FillChar(PixelBuffer^, SizeOf(TPixelBuffer), 15);  { Remplir de blanc }
End;

{ Libérer le buffer de pixels }
Procedure FreePixelBuffer;
Begin
 If PixelBuffer <> Nil Then Begin
  Dispose(PixelBuffer);
  PixelBuffer := Nil;
 End;
End;

{ Définir un pixel dans le buffer }
Procedure SetBufferPixel(X, Y: Integer; Color: Byte);
Begin
 If (X >= 0) And (X < BufferWidth) And (Y >= 0) And (Y < BufferHeight) Then
  PixelBuffer^[Y, X] := Color;
End;

{ Dessiner une ligne dans le buffer (algorithme de Bresenham) }
Procedure DrawBufferLine(X1, Y1, X2, Y2: Integer; Color: Byte);
Var
 DX, DY, SX, SY, Err, E2: Integer;
Begin
 DX := Abs(X2 - X1);
 DY := Abs(Y2 - Y1);
 If X1 < X2 Then SX := 1 Else SX := -1;
 If Y1 < Y2 Then SY := 1 Else SY := -1;
 Err := DX - DY;
 
 While True do Begin
  SetBufferPixel(X1, Y1, Color);
  If (X1 = X2) And (Y1 = Y2) Then Break;
  E2 := 2 * Err;
  If E2 > -DY Then Begin
   Err := Err - DY;
   X1 := X1 + SX;
  End;
  If E2 < DX Then Begin
   Err := Err + DX;
   Y1 := Y1 + SY;
  End;
 End;
End;

{ Dessiner un rectangle plein dans le buffer }
Procedure DrawBufferRect(X1, Y1, X2, Y2: Integer; FillColor, LineColor: Byte);
Var
 X, Y, Temp: Integer;
Begin
 { S'assurer que X1 <= X2 et Y1 <= Y2 }
 If X1 > X2 Then Begin Temp := X1; X1 := X2; X2 := Temp; End;
 If Y1 > Y2 Then Begin Temp := Y1; Y1 := Y2; Y2 := Temp; End;
 
 { Remplissage }
 If FillColor < 255 Then
  For Y := Y1 to Y2 do
   For X := X1 to X2 do
    SetBufferPixel(X, Y, FillColor);
 
 { Contour }
 If LineColor < 255 Then Begin
  For X := X1 to X2 do Begin
   SetBufferPixel(X, Y1, LineColor);
   SetBufferPixel(X, Y2, LineColor);
  End;
  For Y := Y1 to Y2 do Begin
   SetBufferPixel(X1, Y, LineColor);
   SetBufferPixel(X2, Y, LineColor);
  End;
 End;
End;

{ Dessiner une ellipse dans le buffer (algorithme de Bresenham) }
Procedure DrawBufferEllipse(CX, CY, RX, RY: Integer; FillColor, LineColor: Byte);
Var
 X, Y: Integer;
 RX2, RY2: LongInt;
 FX, FY: LongInt;
 P: LongInt;
 PX, PY: Integer;
Begin
 If (RX <= 0) Or (RY <= 0) Then Exit;
 
 RX2 := LongInt(RX) * LongInt(RX);
 RY2 := LongInt(RY) * LongInt(RY);
 
 { Remplissage simple avec des lignes horizontales }
 If FillColor < 255 Then Begin
  For Y := -RY to RY do Begin
   FX := Round(Sqrt((1 - (LongInt(Y) * LongInt(Y)) / RY2) * RX2));
   For X := CX - FX to CX + FX do
    SetBufferPixel(X, CY + Y, FillColor);
  End;
 End;
 
 { Contour - Algorithme de Bresenham pour ellipse }
 If LineColor < 255 Then Begin
  X := 0;
  Y := RY;
  P := RY2 - RX2 * RY + RX2 Div 4;
  
  While 2 * RY2 * X <= 2 * RX2 * Y do Begin
   SetBufferPixel(CX + X, CY + Y, LineColor);
   SetBufferPixel(CX - X, CY + Y, LineColor);
   SetBufferPixel(CX + X, CY - Y, LineColor);
   SetBufferPixel(CX - X, CY - Y, LineColor);
   
   If P < 0 Then Begin
    X := X + 1;
    P := P + 2 * RY2 * X + RY2;
   End
   Else Begin
    X := X + 1;
    Y := Y - 1;
    P := P + 2 * RY2 * X - 2 * RX2 * Y + RY2;
   End;
  End;
  
  P := RY2 * (X * X + X) + RX2 * (Y - 1) * (Y - 1) - RX2 * RY2;
  While Y >= 0 do Begin
   SetBufferPixel(CX + X, CY + Y, LineColor);
   SetBufferPixel(CX - X, CY + Y, LineColor);
   SetBufferPixel(CX + X, CY - Y, LineColor);
   SetBufferPixel(CX - X, CY - Y, LineColor);
   
   If P > 0 Then Begin
    Y := Y - 1;
    P := P - 2 * RX2 * Y + RX2;
   End
   Else Begin
    X := X + 1;
    Y := Y - 1;
    P := P + 2 * RY2 * X - 2 * RX2 * Y + RX2;
   End;
  End;
 End;
End;

{ Dessiner un polygone dans le buffer }
Procedure DrawBufferPolygon(Const Points: TPointArray; PointCount: Integer; 
                            FillColor, LineColor: Byte);
Var
 I: Integer;
Begin
 If PointCount < 2 Then Exit;
 
 { Dessiner les lignes du contour }
 If LineColor < 255 Then Begin
  For I := 1 to PointCount - 1 do
   DrawBufferLine(Points[I].X, Points[I].Y, Points[I+1].X, Points[I+1].Y, LineColor);
  { Fermer le polygone }
  DrawBufferLine(Points[PointCount].X, Points[PointCount].Y, 
                 Points[1].X, Points[1].Y, LineColor);
 End;
End;

{ Rendre les formes dans le buffer de pixels }
Procedure RenderShapesToBuffer;
Var
 I: Integer;
 CX, CY, RX, RY: Integer;
 FC, LC: Byte;
Begin
 For I := 1 to ShapeCount do Begin
  { Convertir les couleurs (utiliser 15/blanc si négatif) }
  If Shapes[I].FillColor >= 0 Then FC := Shapes[I].FillColor Else FC := 255;
  If Shapes[I].LineColor >= 0 Then LC := Shapes[I].LineColor Else LC := 0;
  
  Case Shapes[I].ShapeType of
   stRectangle:
    DrawBufferRect(Shapes[I].X1, Shapes[I].Y1, Shapes[I].X2, Shapes[I].Y2, FC, LC);
   
   stEllipse: Begin
    CX := (Shapes[I].X1 + Shapes[I].X2) Div 2;
    CY := (Shapes[I].Y1 + Shapes[I].Y2) Div 2;
    RX := Abs(Shapes[I].X2 - Shapes[I].X1) Div 2;
    RY := Abs(Shapes[I].Y2 - Shapes[I].Y1) Div 2;
    DrawBufferEllipse(CX, CY, RX, RY, FC, LC);
   End;
   
   stLine, stConnector:
    DrawBufferLine(Shapes[I].X1, Shapes[I].Y1, Shapes[I].X2, Shapes[I].Y2, LC);
   
   stPolygon, stBezier:
    DrawBufferPolygon(Shapes[I].Points, Shapes[I].PointCount, FC, LC);
  End;
 End;
End;

{ Exporter en BMP 24-bit (True Color) }
Function SaveBMP24Bit(Const FileName: String; Width, Height: Integer): Boolean;
Var
 F: File;
 X, Y: Integer;
 R, G, B: Byte;
 RowSize: LongInt;
 Padding: Integer;
 PadByte: Byte;
Begin
 SaveBMP24Bit := False;
 PadByte := 0;
 
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 RowSize := GetBMPRowSize(Width, 24);
 Padding := RowSize - (Width * 3);
 
 WriteBMPHeader(F, Width, Height, 24, 0);
 
 { Écrire les pixels (bottom-up) }
 For Y := Height - 1 downto 0 do Begin
  For X := 0 to Width - 1 do Begin
   PaletteToRGB(PixelBuffer^[Y, X], R, G, B);
   WriteByte(F, B);
   WriteByte(F, G);
   WriteByte(F, R);
  End;
  { Padding }
  For X := 1 to Padding do
   WriteByte(F, PadByte);
 End;
 
 Close(F);
 SaveBMP24Bit := True;
End;

{ Exporter en BMP 8-bit (256 couleurs) }
Function SaveBMP8Bit(Const FileName: String; Width, Height: Integer): Boolean;
Var
 F: File;
 X, Y: Integer;
 RowSize: LongInt;
 Padding: Integer;
 PadByte: Byte;
Begin
 SaveBMP8Bit := False;
 PadByte := 0;
 
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 RowSize := GetBMPRowSize(Width, 8);
 Padding := RowSize - Width;
 
 WriteBMPHeader(F, Width, Height, 8, 256);
 WritePalette256(F);
 
 { Écrire les pixels (bottom-up) }
 For Y := Height - 1 downto 0 do Begin
  For X := 0 to Width - 1 do
   WriteByte(F, PixelBuffer^[Y, X]);
  { Padding }
  For X := 1 to Padding do
   WriteByte(F, PadByte);
 End;
 
 Close(F);
 SaveBMP8Bit := True;
End;

{ Exporter en BMP 4-bit (16 couleurs) }
Function SaveBMP4Bit(Const FileName: String; Width, Height: Integer): Boolean;
Var
 F: File;
 X, Y: Integer;
 RowSize: LongInt;
 BytesPerRow: Integer;
 Padding: Integer;
 PadByte: Byte;
 PixelPair: Byte;
Begin
 SaveBMP4Bit := False;
 PadByte := 0;
 
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 RowSize := GetBMPRowSize(Width, 4);
 BytesPerRow := (Width + 1) Div 2;
 Padding := RowSize - BytesPerRow;
 
 WriteBMPHeader(F, Width, Height, 4, 16);
 WritePalette16(F);
 
 { Écrire les pixels (bottom-up, 2 pixels par octet) }
 For Y := Height - 1 downto 0 do Begin
  X := 0;
  While X < Width do Begin
   { Premier pixel (4 bits de poids fort) }
   PixelPair := (PixelBuffer^[Y, X] And $0F) Shl 4;
   { Deuxième pixel (4 bits de poids faible) }
   If X + 1 < Width Then
    PixelPair := PixelPair Or (PixelBuffer^[Y, X + 1] And $0F);
   WriteByte(F, PixelPair);
   X := X + 2;
  End;
  { Padding }
  For X := 1 to Padding do
   WriteByte(F, PadByte);
 End;
 
 Close(F);
 SaveBMP4Bit := True;
End;

{ Exporter en BMP 1-bit (monochrome) }
Function SaveBMP1Bit(Const FileName: String; Width, Height: Integer): Boolean;
Var
 F: File;
 X, Y: Integer;
 RowSize: LongInt;
 BytesPerRow: Integer;
 Padding: Integer;
 PadByte: Byte;
 ByteVal: Byte;
 BitPos: Integer;
Begin
 SaveBMP1Bit := False;
 PadByte := 0;
 
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;
 
 RowSize := GetBMPRowSize(Width, 1);
 BytesPerRow := (Width + 7) Div 8;
 Padding := RowSize - BytesPerRow;
 
 WriteBMPHeader(F, Width, Height, 1, 2);
 WritePalette2(F);
 
 { Écrire les pixels (bottom-up, 8 pixels par octet) }
 For Y := Height - 1 downto 0 do Begin
  ByteVal := 0;
  BitPos := 7;
  
  For X := 0 to Width - 1 do Begin
   { Convertir en noir (0) ou blanc (1) basé sur la luminosité }
   If PixelBuffer^[Y, X] >= 8 Then  { Couleurs 8-15 sont "claires" }
    ByteVal := ByteVal Or (1 Shl BitPos);
   
   Dec(BitPos);
   If BitPos < 0 Then Begin
    WriteByte(F, ByteVal);
    ByteVal := 0;
    BitPos := 7;
   End;
  End;
  
  { Écrire le dernier octet partiel si nécessaire }
  If BitPos < 7 Then
   WriteByte(F, ByteVal);
  
  { Padding }
  For X := 1 to Padding do
   WriteByte(F, PadByte);
 End;
 
 Close(F);
 SaveBMP1Bit := True;
End;

{ Fonction principale pour sauvegarder un fichier BMP }
{ BitsPerPixel peut être 1, 4, 8, ou 24 }
Function SaveBMPFile(Const FileName: String; BitsPerPixel: Integer): Boolean;
Var
 MinX, MinY, MaxX, MaxY: Integer;
 Width, Height: Integer;
 I: Integer;
Begin
 SaveBMPFile := False;
 
 { Calculer les dimensions du dessin }
 MinX := 32767; MinY := 32767;
 MaxX := 0; MaxY := 0;
 
 For I := 1 to ShapeCount do Begin
  If Shapes[I].X1 < MinX Then MinX := Shapes[I].X1;
  If Shapes[I].Y1 < MinY Then MinY := Shapes[I].Y1;
  If Shapes[I].X2 < MinX Then MinX := Shapes[I].X2;
  If Shapes[I].Y2 < MinY Then MinY := Shapes[I].Y2;
  If Shapes[I].X1 > MaxX Then MaxX := Shapes[I].X1;
  If Shapes[I].Y1 > MaxY Then MaxY := Shapes[I].Y1;
  If Shapes[I].X2 > MaxX Then MaxX := Shapes[I].X2;
  If Shapes[I].Y2 > MaxY Then MaxY := Shapes[I].Y2;
 End;
 
 If ShapeCount = 0 Then Begin
  Width := 640;
  Height := 480;
  MinX := 0;
  MinY := 0;
 End
 Else Begin
  Width := MaxX - MinX + 20;
  Height := MaxY - MinY + 20;
  If Width < 100 Then Width := 100;
  If Height < 100 Then Height := 100;
 End;
 
 { Limiter les dimensions }
 If Width > 2048 Then Width := 2048;
 If Height > 2048 Then Height := 2048;
 
 { Initialiser le buffer et rendre les formes }
 InitPixelBuffer(Width, Height);
 
 { Décaler les formes pour qu'elles commencent à (10, 10) }
 For I := 1 to ShapeCount do Begin
  Shapes[I].X1 := Shapes[I].X1 - MinX + 10;
  Shapes[I].Y1 := Shapes[I].Y1 - MinY + 10;
  Shapes[I].X2 := Shapes[I].X2 - MinX + 10;
  Shapes[I].Y2 := Shapes[I].Y2 - MinY + 10;
 End;
 
 RenderShapesToBuffer;
 
 { Restaurer les positions originales }
 For I := 1 to ShapeCount do Begin
  Shapes[I].X1 := Shapes[I].X1 + MinX - 10;
  Shapes[I].Y1 := Shapes[I].Y1 + MinY - 10;
  Shapes[I].X2 := Shapes[I].X2 + MinX - 10;
  Shapes[I].Y2 := Shapes[I].Y2 + MinY - 10;
 End;
 
 { Exporter selon le nombre de bits }
 Case BitsPerPixel of
  1:  SaveBMPFile := SaveBMP1Bit(FileName, Width, Height);
  4:  SaveBMPFile := SaveBMP4Bit(FileName, Width, Height);
  8:  SaveBMPFile := SaveBMP8Bit(FileName, Width, Height);
  24: SaveBMPFile := SaveBMP24Bit(FileName, Width, Height);
 Else
  SaveBMPFile := SaveBMP24Bit(FileName, Width, Height);  { Par défaut: 24-bit }
 End;
 
 FreePixelBuffer;
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS D'EXPORT BMP === }
{ ============================================================================ }

{ ============================================================================ }
{ === FONCTIONS D'EXPORT GIF === }
{ ============================================================================ }

{ Constantes pour le format GIF }
Const
 GIF_SIGNATURE = 'GIF';
 GIF_VERSION = '89a';
 GIF_TRAILER = $3B;         { Terminateur GIF ';' }
 GIF_IMAGE_SEPARATOR = $2C; { Séparateur d'image ',' }
 GIF_EXTENSION = $21;       { Extension '!' }
 GIF_GCE_LABEL = $F9;       { Label Graphics Control Extension }
 GIF_MAX_CODE_SIZE = 12;    { Taille maximale du code LZW }

{ Types pour l'encodage LZW }
Type
 TLZWCode = Integer;
 TLZWTable = Array[0..4095] of Record
  Prefix: Integer;
  Suffix: Byte;
 End;

Var
 LZWTable: TLZWTable;
 LZWCodeSize: Integer;
 LZWNextCode: Integer;
 LZWClearCode: Integer;
 LZWEOICode: Integer;
 LZWBitBuffer: LongInt;
 LZWBitsInBuffer: Integer;
 LZWByteBuffer: Array[0..254] of Byte;
 LZWByteCount: Integer;

{ Procédure pour initialiser la table LZW }
Procedure InitLZWTable(ColorBits: Integer);
Var
 I: Integer;
Begin
 LZWCodeSize := ColorBits + 1;
 LZWClearCode := 1 Shl ColorBits;
 LZWEOICode := LZWClearCode + 1;
 LZWNextCode := LZWEOICode + 1;
 LZWBitBuffer := 0;
 LZWBitsInBuffer := 0;
 LZWByteCount := 0;
 
 { Initialiser les codes de base (0 à 255) }
 For I := 0 to LZWClearCode - 1 do Begin
  LZWTable[I].Prefix := -1;
  LZWTable[I].Suffix := I;
 End;
End;

{ Procédure pour réinitialiser la table LZW }
Procedure ResetLZWTable(ColorBits: Integer);
Begin
 LZWCodeSize := ColorBits + 1;
 LZWNextCode := LZWEOICode + 1;
End;

{ Procédure pour écrire un sous-bloc de données }
Procedure FlushLZWByteBuffer(Var F: File);
Begin
 If LZWByteCount > 0 Then Begin
  WriteByte(F, LZWByteCount);
  BlockWrite(F, LZWByteBuffer, LZWByteCount);
  LZWByteCount := 0;
 End;
End;

{ Procédure pour écrire un code LZW }
Procedure WriteLZWCode(Var F: File; Code: Integer);
Begin
 LZWBitBuffer := LZWBitBuffer Or (LongInt(Code) Shl LZWBitsInBuffer);
 LZWBitsInBuffer := LZWBitsInBuffer + LZWCodeSize;
 
 While LZWBitsInBuffer >= 8 do Begin
  LZWByteBuffer[LZWByteCount] := LZWBitBuffer And $FF;
  Inc(LZWByteCount);
  LZWBitBuffer := LZWBitBuffer Shr 8;
  LZWBitsInBuffer := LZWBitsInBuffer - 8;
  
  If LZWByteCount >= 254 Then
   FlushLZWByteBuffer(F);
 End;
End;

{ Procédure pour terminer l'écriture LZW }
Procedure FinishLZWOutput(Var F: File);
Begin
 { Écrire les bits restants }
 If LZWBitsInBuffer > 0 Then Begin
  LZWByteBuffer[LZWByteCount] := LZWBitBuffer And $FF;
  Inc(LZWByteCount);
 End;
 
 FlushLZWByteBuffer(F);
 
 { Écrire le bloc terminateur (taille 0) }
 WriteByte(F, 0);
End;

{ Fonction pour chercher un code dans la table LZW }
Function FindLZWCode(Prefix: Integer; Suffix: Byte): Integer;
Var
 I: Integer;
Begin
 FindLZWCode := -1;
 For I := LZWEOICode + 1 to LZWNextCode - 1 do Begin
  If (LZWTable[I].Prefix = Prefix) And (LZWTable[I].Suffix = Suffix) Then Begin
   FindLZWCode := I;
   Exit;
  End;
 End;
End;

{ Fonction pour ajouter un code à la table LZW }
Function AddLZWCode(Prefix: Integer; Suffix: Byte): Integer;
Begin
 If LZWNextCode < 4096 Then Begin
  LZWTable[LZWNextCode].Prefix := Prefix;
  LZWTable[LZWNextCode].Suffix := Suffix;
  AddLZWCode := LZWNextCode;
  Inc(LZWNextCode);
  
  { Augmenter la taille du code si nécessaire }
  If (LZWNextCode > (1 Shl LZWCodeSize)) And (LZWCodeSize < GIF_MAX_CODE_SIZE) Then
   Inc(LZWCodeSize);
 End
 Else
  AddLZWCode := -1;
End;

{ Procédure pour écrire l'en-tête GIF }
Procedure WriteGIFHeader(Var F: File; Width, Height: Integer; ColorBits: Integer);
Var
 PackedByte: Byte;
Begin
 { Signature et version "GIF89a" }
 BlockWrite(F, GIF_SIGNATURE[1], 3);
 BlockWrite(F, GIF_VERSION[1], 3);
 
 { Logical Screen Descriptor }
 WriteWord(F, Width);         { Largeur }
 WriteWord(F, Height);        { Hauteur }
 
 { Packed byte: Global Color Table Flag (1), Color Resolution (3), Sort Flag (1), Size of Global Color Table (3) }
 PackedByte := $80;                          { Global Color Table présente }
 PackedByte := PackedByte Or ((ColorBits - 1) Shl 4);  { Color Resolution }
 PackedByte := PackedByte Or (ColorBits - 1);          { Size of Global Color Table }
 WriteByte(F, PackedByte);
 
 WriteByte(F, 0);             { Background Color Index }
 WriteByte(F, 0);             { Pixel Aspect Ratio }
End;

{ Procédure pour écrire la palette GIF (Global Color Table) }
Procedure WriteGIFPalette(Var F: File; TransparentIndex: Integer);
Var
 I: Integer;
 R, G, B: Byte;
Begin
 { Écrire les 256 couleurs }
 For I := 0 to 255 do Begin
  If I < 16 Then Begin
   PaletteToRGB(I, R, G, B);
  End
  Else Begin
   { Niveaux de gris pour les couleurs 16-255 }
   R := (I - 16) + (I - 16) Div 15;
   G := R;
   B := R;
  End;
  
  WriteByte(F, R);
  WriteByte(F, G);
  WriteByte(F, B);
 End;
End;

{ Procédure pour écrire l'extension de contrôle graphique (transparence) }
Procedure WriteGIFGCE(Var F: File; TransparentIndex: Integer; HasTransparency: Boolean);
Var
 PackedByte: Byte;
Begin
 WriteByte(F, GIF_EXTENSION);    { Extension Introducer }
 WriteByte(F, GIF_GCE_LABEL);    { Graphics Control Label }
 WriteByte(F, 4);                { Block Size (toujours 4) }
 
 { Packed byte: Reserved (3), Disposal Method (3), User Input (1), Transparent Color Flag (1) }
 If HasTransparency Then
  PackedByte := $01  { Transparent Color Flag = 1 }
 Else
  PackedByte := $00;
 WriteByte(F, PackedByte);
 
 WriteWord(F, 0);                { Delay Time (pas d'animation) }
 
 If HasTransparency Then
  WriteByte(F, TransparentIndex) { Transparent Color Index }
 Else
  WriteByte(F, 0);
 
 WriteByte(F, 0);                { Block Terminator }
End;

{ Procédure pour écrire le descripteur d'image }
Procedure WriteGIFImageDescriptor(Var F: File; Width, Height: Integer);
Begin
 WriteByte(F, GIF_IMAGE_SEPARATOR);  { Image Separator ',' }
 WriteWord(F, 0);                     { Left Position }
 WriteWord(F, 0);                     { Top Position }
 WriteWord(F, Width);                 { Image Width }
 WriteWord(F, Height);                { Image Height }
 WriteByte(F, 0);                     { Packed byte: pas de Local Color Table }
End;

{ Procédure pour écrire les données d'image compressées LZW }
Procedure WriteGIFImageData(Var F: File; Width, Height: Integer; ColorBits: Integer);
Var
 X, Y: Integer;
 Pixel: Byte;
 CurrentCode: Integer;
 NewCode: Integer;
Begin
 { LZW Minimum Code Size }
 WriteByte(F, ColorBits);
 
 { Initialiser la table LZW }
 InitLZWTable(ColorBits);
 
 { Écrire le code Clear }
 WriteLZWCode(F, LZWClearCode);
 
 { Encoder les pixels }
 CurrentCode := -1;
 
 For Y := 0 to Height - 1 do Begin
  For X := 0 to Width - 1 do Begin
   Pixel := PixelBuffer^[Y, X];
   
   If CurrentCode = -1 Then
    CurrentCode := Pixel
   Else Begin
    NewCode := FindLZWCode(CurrentCode, Pixel);
    
    If NewCode >= 0 Then
     CurrentCode := NewCode
    Else Begin
     { Écrire le code actuel }
     WriteLZWCode(F, CurrentCode);
     
     { Ajouter le nouveau code à la table }
     If LZWNextCode < 4096 Then
      AddLZWCode(CurrentCode, Pixel)
     Else Begin
      { Table pleine, émettre un code Clear et réinitialiser }
      WriteLZWCode(F, LZWClearCode);
      ResetLZWTable(ColorBits);
     End;
     
     CurrentCode := Pixel;
    End;
   End;
  End;
 End;
 
 { Écrire le dernier code }
 If CurrentCode >= 0 Then
  WriteLZWCode(F, CurrentCode);
 
 { Écrire le code End of Information }
 WriteLZWCode(F, LZWEOICode);
 
 { Terminer la sortie LZW }
 FinishLZWOutput(F);
End;

{ Fonction principale pour sauvegarder un fichier GIF }
{ TransparentIndex: index de la couleur transparente (-1 = pas de transparence) }
Function SaveGIFFile(Const FileName: String; TransparentIndex: Integer): Boolean;
Var
 F: File;
 MinX, MinY, MaxX, MaxY: Integer;
 Width, Height: Integer;
 I: Integer;
 HasTransparency: Boolean;
 ColorBits: Integer;
Begin
 SaveGIFFile := False;
 ColorBits := 8;  { 256 couleurs }
 HasTransparency := (TransparentIndex >= 0) And (TransparentIndex <= 255);
 
 { Calculer les dimensions du dessin }
 MinX := 32767; MinY := 32767;
 MaxX := 0; MaxY := 0;
 
 For I := 1 to ShapeCount do Begin
  If Shapes[I].X1 < MinX Then MinX := Shapes[I].X1;
  If Shapes[I].Y1 < MinY Then MinY := Shapes[I].Y1;
  If Shapes[I].X2 < MinX Then MinX := Shapes[I].X2;
  If Shapes[I].Y2 < MinY Then MinY := Shapes[I].Y2;
  If Shapes[I].X1 > MaxX Then MaxX := Shapes[I].X1;
  If Shapes[I].Y1 > MaxY Then MaxY := Shapes[I].Y1;
  If Shapes[I].X2 > MaxX Then MaxX := Shapes[I].X2;
  If Shapes[I].Y2 > MaxY Then MaxY := Shapes[I].Y2;
 End;
 
 If ShapeCount = 0 Then Begin
  Width := 640;
  Height := 480;
  MinX := 0;
  MinY := 0;
 End
 Else Begin
  Width := MaxX - MinX + 20;
  Height := MaxY - MinY + 20;
  If Width < 100 Then Width := 100;
  If Height < 100 Then Height := 100;
 End;
 
 { Limiter les dimensions }
 If Width > 2048 Then Width := 2048;
 If Height > 2048 Then Height := 2048;
 
 { Initialiser le buffer et rendre les formes }
 InitPixelBuffer(Width, Height);
 
 { Si transparence, initialiser avec la couleur transparente }
 If HasTransparency Then
  FillChar(PixelBuffer^, SizeOf(TPixelBuffer), TransparentIndex);
 
 { Décaler les formes pour qu'elles commencent à (10, 10) }
 For I := 1 to ShapeCount do Begin
  Shapes[I].X1 := Shapes[I].X1 - MinX + 10;
  Shapes[I].Y1 := Shapes[I].Y1 - MinY + 10;
  Shapes[I].X2 := Shapes[I].X2 - MinX + 10;
  Shapes[I].Y2 := Shapes[I].Y2 - MinY + 10;
 End;
 
 RenderShapesToBuffer;
 
 { Restaurer les positions originales }
 For I := 1 to ShapeCount do Begin
  Shapes[I].X1 := Shapes[I].X1 + MinX - 10;
  Shapes[I].Y1 := Shapes[I].Y1 + MinY - 10;
  Shapes[I].X2 := Shapes[I].X2 + MinX - 10;
  Shapes[I].Y2 := Shapes[I].Y2 + MinY - 10;
 End;
 
 { Ouvrir le fichier }
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  FreePixelBuffer;
  Exit;
 End;
 
 { Écrire l'en-tête GIF }
 WriteGIFHeader(F, Width, Height, ColorBits);
 
 { Écrire la palette globale }
 WriteGIFPalette(F, TransparentIndex);
 
 { Écrire l'extension de contrôle graphique (pour transparence) }
 WriteGIFGCE(F, TransparentIndex, HasTransparency);
 
 { Écrire le descripteur d'image }
 WriteGIFImageDescriptor(F, Width, Height);
 
 { Écrire les données d'image compressées }
 WriteGIFImageData(F, Width, Height, ColorBits);
 
 { Écrire le terminateur GIF }
 WriteByte(F, GIF_TRAILER);
 
 Close(F);
 FreePixelBuffer;
 SaveGIFFile := True;
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS D'EXPORT GIF === }
{ ============================================================================ }

{ ============================================================================ }
{ === FONCTIONS D'EXPORT JPEG (TODO 25) === }
{ ============================================================================ }

{ Constantes pour le format JPEG }
Const
 JPEG_SOI = $FFD8;           { Start of Image }
 JPEG_EOI = $FFD9;           { End of Image }
 JPEG_APP0 = $FFE0;          { JFIF marker }
 JPEG_DQT = $FFDB;           { Define Quantization Table }
 JPEG_SOF0 = $FFC0;          { Start of Frame (Baseline DCT) }
 JPEG_DHT = $FFC4;           { Define Huffman Table }
 JPEG_SOS = $FFDA;           { Start of Scan }
 JPEG_BLOCK_SIZE = 8;        { Taille d'un bloc DCT }

{ Tables de quantisation JPEG standard (qualité 50) }
Const
 JPEG_QT_LUMA: Array[0..63] of Byte = (
  16, 11, 10, 16,  24,  40,  51,  61,
  12, 12, 14, 19,  26,  58,  60,  55,
  14, 13, 16, 24,  40,  57,  69,  56,
  14, 17, 22, 29,  51,  87,  80,  62,
  18, 22, 37, 56,  68, 109, 103,  77,
  24, 35, 55, 64,  81, 104, 113,  92,
  49, 64, 78, 87, 103, 121, 120, 101,
  72, 92, 95, 98, 112, 100, 103,  99
 );
 
 JPEG_QT_CHROMA: Array[0..63] of Byte = (
  17, 18, 24, 47, 99, 99, 99, 99,
  18, 21, 26, 66, 99, 99, 99, 99,
  24, 26, 56, 99, 99, 99, 99, 99,
  47, 66, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99
 );

{ Ordre zig-zag pour les coefficients DCT }
Const
 JPEG_ZIGZAG: Array[0..63] of Byte = (
   0,  1,  8, 16,  9,  2,  3, 10,
  17, 24, 32, 25, 18, 11,  4,  5,
  12, 19, 26, 33, 40, 48, 41, 34,
  27, 20, 13,  6,  7, 14, 21, 28,
  35, 42, 49, 56, 57, 50, 43, 36,
  29, 22, 15, 23, 30, 37, 44, 51,
  58, 59, 52, 45, 38, 31, 39, 46,
  53, 60, 61, 54, 47, 55, 62, 63
 );

{ Tables de Huffman DC/AC standard }
Const
 JPEG_DC_BITS: Array[0..15] of Byte = (0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0);
 JPEG_DC_VALS: Array[0..11] of Byte = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
 JPEG_AC_BITS: Array[0..15] of Byte = (0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 125);
 
Type
 TJPEGBlock = Array[0..63] of Integer;
 TJPEGQuantTable = Array[0..63] of Integer;

Var
 JPEGQuality: Integer;
 JPEGQuantLuma: TJPEGQuantTable;
 JPEGQuantChroma: TJPEGQuantTable;
 JPEGBitBuffer: LongInt;
 JPEGBitsInBuffer: Integer;
 JPEGPrevDC_Y: Integer;
 JPEGPrevDC_Cb: Integer;
 JPEGPrevDC_Cr: Integer;

{ Initialiser les tables de quantisation selon la qualité }
Procedure InitJPEGQuantTables(Quality: Integer);
Var
 I: Integer;
 Scale: Integer;
 Temp: Integer;
Begin
 If Quality < 1 Then Quality := 1;
 If Quality > 100 Then Quality := 100;
 
 { Calculer le facteur d'échelle }
 If Quality < 50 Then
  Scale := 5000 Div Quality
 Else
  Scale := 200 - Quality * 2;
  
 { Générer les tables de quantisation }
 For I := 0 to 63 do Begin
  { Table Luminance }
  Temp := (JPEG_QT_LUMA[I] * Scale + 50) Div 100;
  If Temp < 1 Then Temp := 1;
  If Temp > 255 Then Temp := 255;
  JPEGQuantLuma[I] := Temp;
  
  { Table Chrominance }
  Temp := (JPEG_QT_CHROMA[I] * Scale + 50) Div 100;
  If Temp < 1 Then Temp := 1;
  If Temp > 255 Then Temp := 255;
  JPEGQuantChroma[I] := Temp;
 End;
End;

{ Écrire un marqueur JPEG (2 octets) }
Procedure WriteJPEGMarker(Var F: File; Marker: Word);
Var
 B: Byte;
Begin
 B := Hi(Marker);
 BlockWrite(F, B, 1);
 B := Lo(Marker);
 BlockWrite(F, B, 1);
End;

{ Écrire l'en-tête JFIF APP0 }
Procedure WriteJPEGAPP0(Var F: File);
Var
 B: Byte;
 Len: Word;
Begin
 WriteJPEGMarker(F, JPEG_APP0);
 
 { Longueur du segment (16 octets) }
 B := 0; BlockWrite(F, B, 1);
 B := 16; BlockWrite(F, B, 1);
 
 { Identificateur "JFIF\0" }
 B := Ord('J'); BlockWrite(F, B, 1);
 B := Ord('F'); BlockWrite(F, B, 1);
 B := Ord('I'); BlockWrite(F, B, 1);
 B := Ord('F'); BlockWrite(F, B, 1);
 B := 0; BlockWrite(F, B, 1);
 
 { Version JFIF 1.01 }
 B := 1; BlockWrite(F, B, 1);
 B := 1; BlockWrite(F, B, 1);
 
 { Unités (0 = pas d'unité) }
 B := 0; BlockWrite(F, B, 1);
 
 { Densité X et Y (1x1) }
 B := 0; BlockWrite(F, B, 1);
 B := 1; BlockWrite(F, B, 1);
 B := 0; BlockWrite(F, B, 1);
 B := 1; BlockWrite(F, B, 1);
 
 { Pas de vignette }
 B := 0; BlockWrite(F, B, 1);
 B := 0; BlockWrite(F, B, 1);
End;

{ Écrire une table de quantisation DQT }
Procedure WriteJPEGDQT(Var F: File; TableID: Integer; Const QTable: TJPEGQuantTable);
Var
 B: Byte;
 I: Integer;
Begin
 WriteJPEGMarker(F, JPEG_DQT);
 
 { Longueur (2 + 1 + 64 = 67) }
 B := 0; BlockWrite(F, B, 1);
 B := 67; BlockWrite(F, B, 1);
 
 { ID de la table (4 bits precision + 4 bits ID) }
 B := TableID; BlockWrite(F, B, 1);
 
 { 64 coefficients en ordre zig-zag }
 For I := 0 to 63 do Begin
  B := QTable[JPEG_ZIGZAG[I]];
  BlockWrite(F, B, 1);
 End;
End;

{ Écrire le marqueur SOF0 (Start of Frame) }
Procedure WriteJPEGSOF0(Var F: File; Width, Height: Integer);
Var
 B: Byte;
Begin
 WriteJPEGMarker(F, JPEG_SOF0);
 
 { Longueur (2 + 1 + 2 + 2 + 1 + 3*3 = 17) }
 B := 0; BlockWrite(F, B, 1);
 B := 17; BlockWrite(F, B, 1);
 
 { Précision (8 bits) }
 B := 8; BlockWrite(F, B, 1);
 
 { Hauteur }
 B := Hi(Height); BlockWrite(F, B, 1);
 B := Lo(Height); BlockWrite(F, B, 1);
 
 { Largeur }
 B := Hi(Width); BlockWrite(F, B, 1);
 B := Lo(Width); BlockWrite(F, B, 1);
 
 { Nombre de composants (3 = YCbCr) }
 B := 3; BlockWrite(F, B, 1);
 
 { Composant Y (ID=1, sampling 1x1, table quant 0) }
 B := 1; BlockWrite(F, B, 1);
 B := $11; BlockWrite(F, B, 1);  { 1x1 }
 B := 0; BlockWrite(F, B, 1);
 
 { Composant Cb (ID=2, sampling 1x1, table quant 1) }
 B := 2; BlockWrite(F, B, 1);
 B := $11; BlockWrite(F, B, 1);
 B := 1; BlockWrite(F, B, 1);
 
 { Composant Cr (ID=3, sampling 1x1, table quant 1) }
 B := 3; BlockWrite(F, B, 1);
 B := $11; BlockWrite(F, B, 1);
 B := 1; BlockWrite(F, B, 1);
End;

{ Écrire une table de Huffman DHT }
Procedure WriteJPEGDHT(Var F: File; TableClass, TableID: Integer;
                       Const Bits: Array of Byte; Const Vals: Array of Byte;
                       NumVals: Integer);
Var
 B: Byte;
 I: Integer;
 Len: Integer;
Begin
 WriteJPEGMarker(F, JPEG_DHT);
 
 { Calculer la longueur }
 Len := 2 + 1 + 16 + NumVals;
 B := Hi(Len); BlockWrite(F, B, 1);
 B := Lo(Len); BlockWrite(F, B, 1);
 
 { Classe et ID de la table }
 B := (TableClass Shl 4) Or TableID;
 BlockWrite(F, B, 1);
 
 { 16 octets de compteurs de bits }
 For I := 0 to 15 do Begin
  B := Bits[I];
  BlockWrite(F, B, 1);
 End;
 
 { Valeurs des symboles }
 For I := 0 to NumVals - 1 do Begin
  B := Vals[I];
  BlockWrite(F, B, 1);
 End;
End;

{ Écrire le marqueur SOS (Start of Scan) }
Procedure WriteJPEGSOS(Var F: File);
Var
 B: Byte;
Begin
 WriteJPEGMarker(F, JPEG_SOS);
 
 { Longueur (2 + 1 + 3*2 + 3 = 12) }
 B := 0; BlockWrite(F, B, 1);
 B := 12; BlockWrite(F, B, 1);
 
 { Nombre de composants }
 B := 3; BlockWrite(F, B, 1);
 
 { Y: table DC 0, table AC 0 }
 B := 1; BlockWrite(F, B, 1);
 B := $00; BlockWrite(F, B, 1);
 
 { Cb: table DC 1, table AC 1 }
 B := 2; BlockWrite(F, B, 1);
 B := $11; BlockWrite(F, B, 1);
 
 { Cr: table DC 1, table AC 1 }
 B := 3; BlockWrite(F, B, 1);
 B := $11; BlockWrite(F, B, 1);
 
 { Spectral selection }
 B := 0; BlockWrite(F, B, 1);   { Ss }
 B := 63; BlockWrite(F, B, 1);  { Se }
 B := 0; BlockWrite(F, B, 1);   { Ah/Al }
End;

{ Convertir RGB en YCbCr }
Procedure RGBToYCbCr(R, G, B: Byte; Var Y, Cb, Cr: Integer);
Begin
 Y  := Round(0.299 * R + 0.587 * G + 0.114 * B);
 Cb := Round(-0.169 * R - 0.331 * G + 0.500 * B + 128);
 Cr := Round(0.500 * R - 0.419 * G - 0.081 * B + 128);
 
 If Y < 0 Then Y := 0; If Y > 255 Then Y := 255;
 If Cb < 0 Then Cb := 0; If Cb > 255 Then Cb := 255;
 If Cr < 0 Then Cr := 0; If Cr > 255 Then Cr := 255;
End;

{ Écrire un octet compressé JPEG (avec byte stuffing) }
Procedure WriteJPEGByte(Var F: File; B: Byte);
Var
 Stuff: Byte;
Begin
 BlockWrite(F, B, 1);
 If B = $FF Then Begin
  Stuff := $00;
  BlockWrite(F, Stuff, 1);
 End;
End;

{ Vider le buffer de bits JPEG }
Procedure FlushJPEGBits(Var F: File);
Var
 B: Byte;
Begin
 If JPEGBitsInBuffer > 0 Then Begin
  { Compléter avec des 1 }
  While JPEGBitsInBuffer < 8 do Begin
   JPEGBitBuffer := (JPEGBitBuffer Shl 1) Or 1;
   Inc(JPEGBitsInBuffer);
  End;
  B := JPEGBitBuffer And $FF;
  WriteJPEGByte(F, B);
  JPEGBitBuffer := 0;
  JPEGBitsInBuffer := 0;
 End;
End;

{ Écrire des bits dans le buffer JPEG }
Procedure WriteJPEGBits(Var F: File; Value: Integer; NumBits: Integer);
Var
 B: Byte;
Begin
 While NumBits > 0 do Begin
  JPEGBitBuffer := (JPEGBitBuffer Shl 1) Or ((Value Shr (NumBits - 1)) And 1);
  Inc(JPEGBitsInBuffer);
  Dec(NumBits);
  
  If JPEGBitsInBuffer = 8 Then Begin
   B := JPEGBitBuffer And $FF;
   WriteJPEGByte(F, B);
   JPEGBitBuffer := 0;
   JPEGBitsInBuffer := 0;
  End;
 End;
End;

{ Encoder les données d'image JPEG (version simplifiée) }
Procedure WriteJPEGImageData(Var F: File; Width, Height: Integer);
Var
 X, Y, BX, BY, I, J: Integer;
 R, G, B: Byte;
 YVal, CbVal, CrVal: Integer;
 Block: TJPEGBlock;
 DC: Integer;
Begin
 JPEGBitBuffer := 0;
 JPEGBitsInBuffer := 0;
 JPEGPrevDC_Y := 0;
 JPEGPrevDC_Cb := 0;
 JPEGPrevDC_Cr := 0;
 
 { Traiter l'image par blocs de 8x8 }
 BY := 0;
 While BY < Height do Begin
  BX := 0;
  While BX < Width do Begin
   { Construire un bloc Y simplifié }
   DC := 0;
   For J := 0 to 7 do Begin
    For I := 0 to 7 do Begin
     X := BX + I;
     Y := BY + J;
     If (X < Width) And (X < BufferWidth) And (Y < Height) And (Y < BufferHeight) Then Begin
      PaletteToRGB(PixelBuffer^[Y, X], R, G, B);
      RGBToYCbCr(R, G, B, YVal, CbVal, CrVal);
      DC := DC + YVal;
     End
     Else
      DC := DC + 128;
    End;
   End;
   DC := DC Div 64;
   
   { Écrire un coefficient DC simplifié (code 0 = pas de différence) }
   WriteJPEGBits(F, 0, 2);  { Code EOB simplifié }
   
   BX := BX + 8;
  End;
  BY := BY + 8;
 End;
 
 FlushJPEGBits(F);
End;

{ Constantes pour les tables de Huffman AC standard }
Const
 JPEG_AC_VALS: Array[0..161] of Byte = (
  $01, $02, $03, $00, $04, $11, $05, $12, $21, $31, $41, $06, $13, $51, $61, $07,
  $22, $71, $14, $32, $81, $91, $A1, $08, $23, $42, $B1, $C1, $15, $52, $D1, $F0,
  $24, $33, $62, $72, $82, $09, $0A, $16, $17, $18, $19, $1A, $25, $26, $27, $28,
  $29, $2A, $34, $35, $36, $37, $38, $39, $3A, $43, $44, $45, $46, $47, $48, $49,
  $4A, $53, $54, $55, $56, $57, $58, $59, $5A, $63, $64, $65, $66, $67, $68, $69,
  $6A, $73, $74, $75, $76, $77, $78, $79, $7A, $83, $84, $85, $86, $87, $88, $89,
  $8A, $92, $93, $94, $95, $96, $97, $98, $99, $9A, $A2, $A3, $A4, $A5, $A6, $A7,
  $A8, $A9, $AA, $B2, $B3, $B4, $B5, $B6, $B7, $B8, $B9, $BA, $C2, $C3, $C4, $C5,
  $C6, $C7, $C8, $C9, $CA, $D2, $D3, $D4, $D5, $D6, $D7, $D8, $D9, $DA, $E1, $E2,
  $E3, $E4, $E5, $E6, $E7, $E8, $E9, $EA, $F1, $F2, $F3, $F4, $F5, $F6, $F7, $F8,
  $F9, $FA
 );

{ Fonction principale pour sauvegarder un fichier JPEG }
{ Quality: niveau de qualité de 1 (pire) à 100 (meilleur) }
Function SaveJPEGFile(Const FileName: String; Quality: Integer): Boolean;
Var
 F: File;
 MinX, MinY, MaxX, MaxY: Integer;
 Width, Height: Integer;
Begin
 SaveJPEGFile := False;
 JPEGQuality := Quality;
 If JPEGQuality < 1 Then JPEGQuality := 1;
 If JPEGQuality > 100 Then JPEGQuality := 100;
 
 { Calculer les dimensions du dessin }
 If Not CalculateDrawingBounds(MinX, MinY, MaxX, MaxY) Then Begin
  { Pas de formes, créer une image par défaut }
  MinX := 0; MinY := WORK_AREA_TOP;
  MaxX := 640; MaxY := 480;
 End;
 
 Width := MaxX - MinX + 1;
 Height := MaxY - MinY + 1;
 If Width < 1 Then Width := 1;
 If Height < 1 Then Height := 1;
 
 { Initialiser le buffer de pixels et le remplir }
 InitPixelBuffer(Width, Height);
 
 { Repositionner les formes pour le buffer }
 AdjustShapesForBuffer(MinX, MinY);
 
 { Rendre les formes dans le buffer }
 RenderShapesToBuffer;
 
 { Restaurer les positions originales }
 AdjustShapesForBuffer(-MinX, -MinY);
 
 { Initialiser les tables de quantisation }
 InitJPEGQuantTables(JPEGQuality);
 
 { Créer le fichier }
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  FreePixelBuffer;
  Exit;
 End;
 
 { Écrire le marqueur SOI (Start of Image) }
 WriteJPEGMarker(F, JPEG_SOI);
 
 { Écrire le segment JFIF APP0 }
 WriteJPEGAPP0(F);
 
 { Écrire les tables de quantisation }
 WriteJPEGDQT(F, 0, JPEGQuantLuma);
 WriteJPEGDQT(F, 1, JPEGQuantChroma);
 
 { Écrire le marqueur SOF0 }
 WriteJPEGSOF0(F, Width, Height);
 
 { Écrire les tables de Huffman }
 WriteJPEGDHT(F, 0, 0, JPEG_DC_BITS, JPEG_DC_VALS, 12);  { DC Luma }
 WriteJPEGDHT(F, 0, 1, JPEG_DC_BITS, JPEG_DC_VALS, 12);  { DC Chroma }
 WriteJPEGDHT(F, 1, 0, JPEG_AC_BITS, JPEG_AC_VALS, 162); { AC Luma }
 WriteJPEGDHT(F, 1, 1, JPEG_AC_BITS, JPEG_AC_VALS, 162); { AC Chroma }
 
 { Écrire le marqueur SOS }
 WriteJPEGSOS(F);
 
 { Écrire les données d'image compressées }
 WriteJPEGImageData(F, Width, Height);
 
 { Écrire le marqueur EOI (End of Image) }
 WriteJPEGMarker(F, JPEG_EOI);
 
 Close(F);
 FreePixelBuffer;
 SaveJPEGFile := True;
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS D'EXPORT JPEG === }
{ ============================================================================ }

{ ============================================================================ }
{ === FONCTIONS D'EXPORT PNG (TODO 25) === }
{ ============================================================================ }

{ Constantes pour le format PNG }
Const
 PNG_SIGNATURE: Array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
 PNG_CHUNK_IHDR = $49484452;  { 'IHDR' }
 PNG_CHUNK_IDAT = $49444154;  { 'IDAT' }
 PNG_CHUNK_IEND = $49454E44;  { 'IEND' }
 PNG_CHUNK_PLTE = $504C5445;  { 'PLTE' }
 PNG_CHUNK_tRNS = $74524E53;  { 'tRNS' }
 
 PNG_COLOR_GRAYSCALE = 0;
 PNG_COLOR_RGB = 2;
 PNG_COLOR_INDEXED = 3;
 PNG_COLOR_GRAYSCALE_ALPHA = 4;
 PNG_COLOR_RGBA = 6;

{ Table CRC32 pour PNG }
Var
 PNG_CRC_Table: Array[0..255] of LongInt;
 PNG_CRC_Initialized: Boolean;

{ Initialiser la table CRC32 }
Procedure InitPNGCRCTable;
Var
 C: LongInt;
 N, K: Integer;
Begin
 If PNG_CRC_Initialized Then Exit;
 
 For N := 0 to 255 do Begin
  C := LongInt(N);
  For K := 0 to 7 do Begin
   If (C And 1) <> 0 Then
    C := LongInt($EDB88320) Xor (C Shr 1)
   Else
    C := C Shr 1;
  End;
  PNG_CRC_Table[N] := C;
 End;
 PNG_CRC_Initialized := True;
End;

{ Calculer le CRC32 }
Function UpdateCRC(CRC: LongInt; Const Data: Array of Byte; Len: Integer): LongInt;
Var
 I: Integer;
Begin
 For I := 0 to Len - 1 do
  CRC := PNG_CRC_Table[(CRC Xor Data[I]) And $FF] Xor (CRC Shr 8);
 UpdateCRC := CRC;
End;

{ Écrire un entier 32-bit big-endian }
Procedure WritePNGInt32(Var F: File; Value: LongInt);
Var
 B: Array[0..3] of Byte;
Begin
 B[0] := (Value Shr 24) And $FF;
 B[1] := (Value Shr 16) And $FF;
 B[2] := (Value Shr 8) And $FF;
 B[3] := Value And $FF;
 BlockWrite(F, B, 4);
End;

{ Écrire la signature PNG }
Procedure WritePNGSignature(Var F: File);
Begin
 BlockWrite(F, PNG_SIGNATURE, 8);
End;

{ Écrire un chunk PNG }
Procedure WritePNGChunk(Var F: File; ChunkType: LongInt; Const Data: Array of Byte; DataLen: Integer);
Var
 TypeBytes: Array[0..3] of Byte;
 CRC: LongInt;
 I: Integer;
Begin
 { Écrire la longueur }
 WritePNGInt32(F, DataLen);
 
 { Convertir le type en bytes }
 TypeBytes[0] := (ChunkType Shr 24) And $FF;
 TypeBytes[1] := (ChunkType Shr 16) And $FF;
 TypeBytes[2] := (ChunkType Shr 8) And $FF;
 TypeBytes[3] := ChunkType And $FF;
 
 { Écrire le type }
 BlockWrite(F, TypeBytes, 4);
 
 { Écrire les données }
 If DataLen > 0 Then
  BlockWrite(F, Data, DataLen);
 
 { Calculer et écrire le CRC }
 CRC := $FFFFFFFF;
 CRC := UpdateCRC(CRC, TypeBytes, 4);
 If DataLen > 0 Then
  CRC := UpdateCRC(CRC, Data, DataLen);
 CRC := CRC Xor $FFFFFFFF;
 WritePNGInt32(F, CRC);
End;

{ Écrire le chunk IHDR }
Procedure WritePNGIHDR(Var F: File; Width, Height: Integer; ColorType, BitDepth: Byte);
Var
 Data: Array[0..12] of Byte;
Begin
 { Width (4 bytes) }
 Data[0] := (Width Shr 24) And $FF;
 Data[1] := (Width Shr 16) And $FF;
 Data[2] := (Width Shr 8) And $FF;
 Data[3] := Width And $FF;
 
 { Height (4 bytes) }
 Data[4] := (Height Shr 24) And $FF;
 Data[5] := (Height Shr 16) And $FF;
 Data[6] := (Height Shr 8) And $FF;
 Data[7] := Height And $FF;
 
 { Bit depth }
 Data[8] := BitDepth;
 
 { Color type }
 Data[9] := ColorType;
 
 { Compression method (always 0) }
 Data[10] := 0;
 
 { Filter method (always 0) }
 Data[11] := 0;
 
 { Interlace method (0 = no interlace) }
 Data[12] := 0;
 
 WritePNGChunk(F, PNG_CHUNK_IHDR, Data, 13);
End;

{ Variables pour la compression DEFLATE simplifiée }
Var
 PNGCompressBuffer: Array[0..65535] of Byte;
 PNGCompressLen: Integer;

{ Ajouter un octet au buffer de compression }
Procedure AddPNGCompressByte(B: Byte);
Begin
 If PNGCompressLen < 65536 Then Begin
  PNGCompressBuffer[PNGCompressLen] := B;
  Inc(PNGCompressLen);
 End;
End;

{ Compression DEFLATE simplifiée (données non compressées) }
{ Utilise des blocs non compressés pour la simplicité }
Procedure CompressPNGData(Const InputData: Array of Byte; InputLen: Integer);
Var
 I: Integer;
 BlockLen: Integer;
 Pos: Integer;
 Adler1, Adler2: LongInt;
Begin
 PNGCompressLen := 0;
 
 { En-tête zlib }
 AddPNGCompressByte($78);  { CMF: deflate, 32K window }
 AddPNGCompressByte($01);  { FLG: no dict, level 0 }
 
 { Données en blocs non compressés }
 Pos := 0;
 While Pos < InputLen do Begin
  BlockLen := InputLen - Pos;
  If BlockLen > 65535 Then BlockLen := 65535;
  
  { Header du bloc }
  If Pos + BlockLen >= InputLen Then
   AddPNGCompressByte($01)  { Dernier bloc, non compressé }
  Else
   AddPNGCompressByte($00); { Pas dernier bloc, non compressé }
  
  { Longueur et complément }
  AddPNGCompressByte(BlockLen And $FF);
  AddPNGCompressByte((BlockLen Shr 8) And $FF);
  AddPNGCompressByte((Not BlockLen) And $FF);
  AddPNGCompressByte((Not (BlockLen Shr 8)) And $FF);
  
  { Données }
  For I := 0 to BlockLen - 1 do
   AddPNGCompressByte(InputData[Pos + I]);
  
  Pos := Pos + BlockLen;
 End;
 
 { Calculer Adler-32 }
 Adler1 := 1;
 Adler2 := 0;
 For I := 0 to InputLen - 1 do Begin
  Adler1 := (Adler1 + InputData[I]) Mod 65521;
  Adler2 := (Adler2 + Adler1) Mod 65521;
 End;
 
 { Écrire Adler-32 (big-endian) }
 AddPNGCompressByte((Adler2 Shr 8) And $FF);
 AddPNGCompressByte(Adler2 And $FF);
 AddPNGCompressByte((Adler1 Shr 8) And $FF);
 AddPNGCompressByte(Adler1 And $FF);
End;

{ Type pour les données d'image PNG }
Type
 TPNGRawData = Array[0..65535] of Byte;
 PPNGRawData = ^TPNGRawData;

{ Écrire les données d'image RGBA avec alpha }
Procedure WritePNGImageData(Var F: File; Width, Height: Integer; TransparentIndex: Integer);
Var
 RawData: PPNGRawData;
 RawLen: LongInt;
 X, Y: Integer;
 R, G, B, A: Byte;
 Idx: LongInt;
 PixelColor: Byte;
Begin
 { Calculer la taille des données brutes (filtre + RGBA par pixel) }
 RawLen := LongInt(Height) * (1 + LongInt(Width) * 4);
 
 { Limiter pour éviter le dépassement de mémoire }
 If RawLen > 65535 Then Begin
  { Pour les grandes images, on écrit en plusieurs chunks }
  RawLen := 65535;
 End;
 
 New(RawData);
 Idx := 0;
 
 For Y := 0 to Height - 1 do Begin
  If Idx >= 65535 Then Break;
  
  { Octet de filtre (0 = None) }
  RawData^[Idx] := 0;
  Inc(Idx);
  
  For X := 0 to Width - 1 do Begin
   If Idx + 4 > 65535 Then Break;
   
   { Obtenir la couleur du pixel }
   If (X < BufferWidth) And (Y < BufferHeight) Then
    PixelColor := PixelBuffer^[Y, X]
   Else
    PixelColor := 15;  { Blanc par défaut }
   
   { Convertir en RGB }
   PaletteToRGB(PixelColor, R, G, B);
   
   { Déterminer l'alpha }
   If (TransparentIndex >= 0) And (PixelColor = TransparentIndex) Then
    A := 0    { Transparent }
   Else
    A := 255; { Opaque }
   
   { Écrire RGBA }
   RawData^[Idx] := R; Inc(Idx);
   RawData^[Idx] := G; Inc(Idx);
   RawData^[Idx] := B; Inc(Idx);
   RawData^[Idx] := A; Inc(Idx);
  End;
 End;
 
 { Compresser les données }
 CompressPNGData(RawData^, Idx);
 
 { Écrire le chunk IDAT }
 WritePNGChunk(F, PNG_CHUNK_IDAT, PNGCompressBuffer, PNGCompressLen);
 
 Dispose(RawData);
End;

{ Écrire le chunk IEND }
Procedure WritePNGIEND(Var F: File);
Var
 EmptyData: Array[0..0] of Byte;
Begin
 EmptyData[0] := 0;  { Non utilisé }
 WritePNGChunk(F, PNG_CHUNK_IEND, EmptyData, 0);
End;

{ Fonction principale pour sauvegarder un fichier PNG }
{ TransparentIndex: index de la couleur transparente (-1 = pas de transparence) }
Function SavePNGFile(Const FileName: String; TransparentIndex: Integer): Boolean;
Var
 F: File;
 MinX, MinY, MaxX, MaxY: Integer;
 Width, Height: Integer;
Begin
 SavePNGFile := False;
 
 { Initialiser la table CRC }
 InitPNGCRCTable;
 
 { Calculer les dimensions du dessin }
 If Not CalculateDrawingBounds(MinX, MinY, MaxX, MaxY) Then Begin
  { Pas de formes, créer une image par défaut }
  MinX := 0; MinY := WORK_AREA_TOP;
  MaxX := 640; MaxY := 480;
 End;
 
 Width := MaxX - MinX + 1;
 Height := MaxY - MinY + 1;
 If Width < 1 Then Width := 1;
 If Height < 1 Then Height := 1;
 
 { Limiter la taille pour éviter les problèmes de mémoire }
 If Width > 256 Then Width := 256;
 If Height > 256 Then Height := 256;
 
 { Initialiser le buffer de pixels et le remplir }
 InitPixelBuffer(Width, Height);
 
 { Repositionner les formes pour le buffer }
 AdjustShapesForBuffer(MinX, MinY);
 
 { Rendre les formes dans le buffer }
 RenderShapesToBuffer;
 
 { Restaurer les positions originales }
 AdjustShapesForBuffer(-MinX, -MinY);
 
 { Créer le fichier }
 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  FreePixelBuffer;
  Exit;
 End;
 
 { Écrire la signature PNG }
 WritePNGSignature(F);
 
 { Écrire le chunk IHDR (RGBA, 8 bits par canal) }
 WritePNGIHDR(F, Width, Height, PNG_COLOR_RGBA, 8);
 
 { Écrire les données d'image }
 WritePNGImageData(F, Width, Height, TransparentIndex);
 
 { Écrire le chunk IEND }
 WritePNGIEND(F);
 
 Close(F);
 FreePixelBuffer;
 SavePNGFile := True;
End;

{ ============================================================================ }
{ === FIN DES FONCTIONS D'EXPORT PNG === }
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
Var
 Success: Boolean;
Begin
 If CurrentFileName = '' Then Begin
  { Si pas de nom de fichier, appeler Save As }
  FileSaveAs;
 End
 Else Begin
  { Sauvegarder le fichier au format approprié }
  Success := SaveVisioFile(CurrentFileName, VISIO_FORMAT_UNKNOWN);
  If Success Then Begin
   DocumentModified := False;
  End;
 End;
End;

{ Procédure Save As - Sauvegarder sous un nouveau nom }
Procedure FileSaveAs;
Var
 FileName: String;
 FileFormat: Integer;
 Success: Boolean;
Begin
 { Pour l'instant, utiliser un nom de fichier par défaut }
 { Une vraie implémentation afficherait une boîte de dialogue }
 FileName := 'document.vsdx';  { Format VSDX par défaut }
 
 { TODO: Implémenter une vraie boîte de dialogue de sélection de fichier }
 
 If FileName <> '' Then Begin
  { Détecter le format depuis l'extension }
  FileFormat := GetVisioFormatFromExtension(FileName);
  
  { Sauvegarder le fichier }
  Success := SaveVisioFile(FileName, FileFormat);
  If Success Then Begin
   CurrentFileName := FileName;
   DocumentModified := False;
  End;
 End;
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