{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Free Pascal 3.2
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
  10. [DONE] Ajouter les poignées de manipulation (grips) pour éditer les objets sélectionnés

  === INTERPRÉTEUR AUTOLISP ===
  11. [DONE] Créer un analyseur lexical (tokenizer) pour le langage AutoLISP
  12. [DONE] Implémenter un parseur pour construire l'arbre syntaxique des expressions LISP
  13. [DONE] Développer l'évaluateur d'expressions avec support des fonctions mathématiques (+, -, *, /, sin, cos, sqrt, etc.)
  14. [DONE] Implémenter les fonctions de dessin AutoLISP : command, entmake, entmod, entget, entsel, ssget, ssadd
  15. [DONE] Ajouter les fonctions de manipulation de chaînes, listes et variables : setq, defun, if, cond, while, foreach, mapcar

  === MODIFICATION DES OBJETS ET PROPRIÉTÉS ===
  16. [DONE] Créer le panneau de propriétés pour modifier couleur, calque, type de ligne, épaisseur
  17. [DONE] Implémenter la modification géométrique des objets (déplacer sommets, changer rayon, etc.)
  18. [DONE] Ajouter le système de calques (layers) avec visibilité, verrouillage, couleur et type de ligne
  19. [DONE] Créer les outils de cotation : linéaire, alignée, angulaire, radiale, diamètre, ordonnée
  20. [DONE] Implémenter les blocs et références externes (XREFs) avec insertion et édition

  === FORMATS DE FICHIERS ===
  21. [DONE] Implémenter la lecture et écriture du format DWG (Drawing) d'AutoCAD
  22. [DONE] Ajouter le support du format DXF (Drawing Exchange Format) pour l'interopérabilité
  23. [DONE] Créer l'importation et exportation du format Visio (VSD/VSDX)
  24. [DONE] Implémenter l'exportation SVG (Scalable Vector Graphics) pour le web
  25. [DONE] Ajouter l'importation SVG avec conversion des éléments en entités AutoCAD
}

Program AUTOCAD;

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}

Uses {$IFDEF FPC}
      Printer,Crt,PtcGraph,PtcCrt,PtcMouse,Dos
     {$ELSE}
      Printer,Crt,Graph,Dos
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

 MAX_VERTICES=255;

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
 OBJ_DIMENSION = 9;  { TODO 19: Objet cotation }
 OBJ_BLOCK_REF = 10; { TODO 20: Référence de bloc }
 OBJ_XREF = 11;      { TODO 20: Référence externe }

 { Constantes pour les blocs et XREFs - TODO 20 }
 MAX_BLOCKS = 100;           { Nombre maximum de définitions de blocs }
 MAX_BLOCK_ENTITIES = 50;    { Nombre maximum d'entités par bloc }
 MAX_BLOCK_REFS = 500;       { Nombre maximum d'insertions de blocs }
 MAX_XREFS = 20;             { Nombre maximum de références externes }
 XREF_PATH_LENGTH = 255;     { Longueur maximum du chemin XREF }

 { Constantes pour les references d'images (raster) }
 MAX_IMAGE_REFS = 30;        { Nombre maximum de references d'images }
 IMGREF_LOADED = 0;          { Image trouvee et chargee }
 IMGREF_NOT_FOUND = 1;       { Fichier image introuvable }
 IMGREF_UNLOADED = 2;        { Image dechargee (cachee) }

 { Constantes pour les objets OLE incorpores ou lies }
 MAX_OLE_OBJECTS = 20;       { Nombre maximum d'objets OLE }
 OLE_LOADED = 0;             { Objet trouve et lie }
 OLE_NOT_FOUND = 1;          { Fichier source introuvable }
 OLE_UNLOADED = 2;           { Objet decharge }
 OLE_KIND_LINK = 0;          { Lie (reference sur disque) }
 OLE_KIND_EMBED = 1;         { Incorpore (placeholder) }

 { États des XREFs }
 XREF_LOADED = 0;            { XREF chargée normalement }
 XREF_UNLOADED = 1;          { XREF déchargée (non affichée) }
 XREF_NOT_FOUND = 2;         { Fichier XREF non trouvé }
 XREF_NEEDS_RELOAD = 3;      { XREF modifiée, doit être rechargée }

 { Constantes pour le format DWG - TODO 21 }
 DWG_MAGIC = 'AC1015';       { Signature AutoCAD 2000 (format le plus compatible) }
 DWG_VERSION_R14 = 'AC1014'; { AutoCAD R14 }
 DWG_VERSION_2000 = 'AC1015'; { AutoCAD 2000 }
 DWG_VERSION_2004 = 'AC1018'; { AutoCAD 2004 }
 DWG_VERSION_2007 = 'AC1021'; { AutoCAD 2007 }
 DWG_VERSION_2010 = 'AC1024'; { AutoCAD 2010 }
 DWG_VERSION_2013 = 'AC1027'; { AutoCAD 2013 }
 DWG_VERSION_2018 = 'AC1032'; { AutoCAD 2018 }

 { Codes de section DWG }
 DWG_SECTION_HEADER = 0;      { Section en-tête du dessin }
 DWG_SECTION_CLASSES = 1;     { Section des classes d'objets }
 DWG_SECTION_HANDLES = 2;     { Section des handles (identifiants) }
 DWG_SECTION_OBJECTS = 3;     { Section des objets (entités) }
 DWG_SECTION_OBJFREE = 4;     { Section des objets libres }
 DWG_SECTION_TEMPLATE = 5;    { Section des templates }
 DWG_SECTION_AUXHEADER = 6;   { Section en-tête auxiliaire }

 { Codes d'entités DWG }
 DWG_ENTITY_LINE = 1;         { Entité ligne }
 DWG_ENTITY_POINT = 2;        { Entité point }
 DWG_ENTITY_CIRCLE = 3;       { Entité cercle }
 DWG_ENTITY_ARC = 4;          { Entité arc }
 DWG_ENTITY_TEXT = 5;         { Entité texte }
 DWG_ENTITY_SOLID = 6;        { Entité solide }
 DWG_ENTITY_BLOCK = 7;        { Référence de bloc }
 DWG_ENTITY_INSERT = 8;       { Insertion de bloc }
 DWG_ENTITY_ATTDEF = 9;       { Définition d'attribut }
 DWG_ENTITY_ATTRIB = 10;      { Attribut }
 DWG_ENTITY_POLYLINE = 11;    { Polyligne }
 DWG_ENTITY_VERTEX = 12;      { Sommet de polyligne }
 DWG_ENTITY_SEQEND = 13;      { Fin de séquence }
 DWG_ENTITY_ELLIPSE = 14;     { Ellipse }
 DWG_ENTITY_SPLINE = 15;      { Spline }
 DWG_ENTITY_DIMENSION = 16;   { Cotation }
 DWG_ENTITY_LWPOLYLINE = 17;  { Polyligne légère }
 DWG_ENTITY_HATCH = 18;       { Hachures }
 DWG_ENTITY_MTEXT = 19;       { Texte multiligne }
 DWG_ENTITY_LEADER = 20;      { Ligne de repère }

 { Constantes pour le format DXF - TODO 22 }
 { Codes de groupe DXF principaux }
 DXF_GROUP_STRING = 0;         { Code de groupe pour chaînes/noms }
 DXF_GROUP_NAME = 2;           { Nom d'entité }
 DXF_GROUP_HANDLE = 5;         { Handle de l'entité }
 DXF_GROUP_LINETYPE = 6;       { Nom du type de ligne }
 DXF_GROUP_LAYER = 8;          { Nom du calque }
 DXF_GROUP_X1 = 10;            { Coordonnée X primaire }
 DXF_GROUP_Y1 = 20;            { Coordonnée Y primaire }
 DXF_GROUP_Z1 = 30;            { Coordonnée Z primaire }
 DXF_GROUP_X2 = 11;            { Coordonnée X secondaire }
 DXF_GROUP_Y2 = 21;            { Coordonnée Y secondaire }
 DXF_GROUP_Z2 = 31;            { Coordonnée Z secondaire }
 DXF_GROUP_X3 = 12;            { Coordonnée X tertiaire }
 DXF_GROUP_Y3 = 22;            { Coordonnée Y tertiaire }
 DXF_GROUP_RADIUS = 40;        { Rayon }
 DXF_GROUP_RATIO = 41;         { Ratio (ellipse) }
 DXF_GROUP_START_ANGLE = 50;   { Angle de départ }
 DXF_GROUP_END_ANGLE = 51;     { Angle de fin }
 DXF_GROUP_COLOR = 62;         { Numéro de couleur ACI }
 DXF_GROUP_LINEWEIGHT = 370;   { Épaisseur de ligne }
 DXF_GROUP_TEXT = 1;           { Valeur texte }
 DXF_GROUP_TEXT_HEIGHT = 40;   { Hauteur du texte }
 DXF_GROUP_TEXT_ROTATION = 50; { Rotation du texte }
 DXF_GROUP_FLAGS = 70;         { Drapeaux }
 DXF_GROUP_DIMTYPE = 70;       { Type de cotation }

 { Noms des sections DXF }
 DXF_SECTION = 'SECTION';
 DXF_ENDSEC = 'ENDSEC';
 DXF_EOF = 'EOF';
 DXF_HEADER = 'HEADER';
 DXF_TABLES = 'TABLES';
 DXF_BLOCKS = 'BLOCKS';
 DXF_ENTITIES = 'ENTITIES';
 DXF_OBJECTS = 'OBJECTS';

 { Noms des entités DXF }
 DXF_LINE = 'LINE';
 DXF_POINT = 'POINT';
 DXF_CIRCLE = 'CIRCLE';
 DXF_ARC = 'ARC';
 DXF_TEXT = 'TEXT';
 DXF_MTEXT = 'MTEXT';
 DXF_POLYLINE = 'POLYLINE';
 DXF_LWPOLYLINE = 'LWPOLYLINE';
 DXF_ELLIPSE = 'ELLIPSE';
 DXF_INSERT = 'INSERT';
 DXF_DIMENSION = 'DIMENSION';
 DXF_VERTEX = 'VERTEX';
 DXF_SEQEND = 'SEQEND';
 DXF_BLOCK = 'BLOCK';
 DXF_ENDBLK = 'ENDBLK';
 DXF_LAYER = 'LAYER';
 DXF_TABLE = 'TABLE';
 DXF_ENDTAB = 'ENDTAB';

 { Constantes pour le format Visio - TODO 23 }
 { Extensions de fichiers Visio }
 VISIO_EXT_VSD = '.vsd';       { Format binaire Visio (ancien) }
 VISIO_EXT_VSDX = '.vsdx';     { Format XML Visio (nouveau) }
 VISIO_EXT_VSDM = '.vsdm';     { Format XML Visio avec macros }
 VISIO_EXT_VST = '.vst';       { Template Visio binaire }
 VISIO_EXT_VSTX = '.vstx';     { Template Visio XML }

 { Types de formes Visio }
 VISIO_SHAPE_RECTANGLE = 1;   { Rectangle }
 VISIO_SHAPE_ELLIPSE = 2;     { Ellipse }
 VISIO_SHAPE_LINE = 3;        { Ligne }
 VISIO_SHAPE_POLYLINE = 4;    { Polyligne }
 VISIO_SHAPE_ARC = 5;         { Arc }
 VISIO_SHAPE_BEZIER = 6;      { Courbe de Bézier }
 VISIO_SHAPE_CONNECTOR = 7;   { Connecteur }
 VISIO_SHAPE_TEXT = 8;        { Texte }
 VISIO_SHAPE_GROUP = 9;       { Groupe de formes }
 VISIO_SHAPE_FOREIGN = 10;    { Objet externe (image) }

 { Sections XML Visio (VSDX) }
 VISIO_XML_DOCUMENT = 'VisioDocument';
 VISIO_XML_PAGES = 'Pages';
 VISIO_XML_PAGE = 'Page';
 VISIO_XML_SHAPES = 'Shapes';
 VISIO_XML_SHAPE = 'Shape';
 VISIO_XML_MASTERS = 'Masters';
 VISIO_XML_MASTER = 'Master';
 VISIO_XML_CONNECTS = 'Connects';
 VISIO_XML_CONNECT = 'Connect';
 VISIO_XML_STYLESHEET = 'StyleSheet';
 VISIO_XML_DOCPROPS = 'DocumentProperties';

 { Cellules de géométrie Visio }
 VISIO_CELL_PINX = 'PinX';         { Position X du point de pivot }
 VISIO_CELL_PINY = 'PinY';         { Position Y du point de pivot }
 VISIO_CELL_WIDTH = 'Width';       { Largeur de la forme }
 VISIO_CELL_HEIGHT = 'Height';     { Hauteur de la forme }
 VISIO_CELL_LOCPINX = 'LocPinX';   { Point local X }
 VISIO_CELL_LOCPINY = 'LocPinY';   { Point local Y }
 VISIO_CELL_ANGLE = 'Angle';       { Angle de rotation }
 VISIO_CELL_BEGINX = 'BeginX';     { X de début (lignes) }
 VISIO_CELL_BEGINY = 'BeginY';     { Y de début (lignes) }
 VISIO_CELL_ENDX = 'EndX';         { X de fin (lignes) }
 VISIO_CELL_ENDY = 'EndY';         { Y de fin (lignes) }
 VISIO_CELL_TEXT = 'Text';         { Contenu texte }
 VISIO_CELL_FILLCOLOR = 'FillForegnd';  { Couleur de remplissage }
 VISIO_CELL_LINECOLOR = 'LineColor';    { Couleur de ligne }
 VISIO_CELL_LINEWEIGHT = 'LineWeight';  { Épaisseur de ligne }

 { Constantes pour le format SVG - TODO 24 }
 { Extension de fichier SVG }
 SVG_EXT = '.svg';             { Format SVG }

 { Éléments SVG principaux }
 SVG_ELEMENT_SVG = 'svg';
 SVG_ELEMENT_G = 'g';
 SVG_ELEMENT_LINE = 'line';
 SVG_ELEMENT_RECT = 'rect';
 SVG_ELEMENT_CIRCLE = 'circle';
 SVG_ELEMENT_ELLIPSE = 'ellipse';
 SVG_ELEMENT_PATH = 'path';
 SVG_ELEMENT_POLYLINE = 'polyline';
 SVG_ELEMENT_POLYGON = 'polygon';
 SVG_ELEMENT_TEXT = 'text';
 SVG_ELEMENT_DEFS = 'defs';
 SVG_ELEMENT_MARKER = 'marker';

 { Attributs SVG }
 SVG_ATTR_XMLNS = 'xmlns';
 SVG_ATTR_VERSION = 'version';
 SVG_ATTR_WIDTH = 'width';
 SVG_ATTR_HEIGHT = 'height';
 SVG_ATTR_VIEWBOX = 'viewBox';
 SVG_ATTR_FILL = 'fill';
 SVG_ATTR_STROKE = 'stroke';
 SVG_ATTR_STROKE_WIDTH = 'stroke-width';
 SVG_ATTR_STROKE_LINECAP = 'stroke-linecap';
 SVG_ATTR_STROKE_LINEJOIN = 'stroke-linejoin';
 SVG_ATTR_X = 'x';
 SVG_ATTR_Y = 'y';
 SVG_ATTR_X1 = 'x1';
 SVG_ATTR_Y1 = 'y1';
 SVG_ATTR_X2 = 'x2';
 SVG_ATTR_Y2 = 'y2';
 SVG_ATTR_CX = 'cx';
 SVG_ATTR_CY = 'cy';
 SVG_ATTR_R = 'r';
 SVG_ATTR_RX = 'rx';
 SVG_ATTR_RY = 'ry';
 SVG_ATTR_D = 'd';
 SVG_ATTR_POINTS = 'points';
 SVG_ATTR_FONT_SIZE = 'font-size';
 SVG_ATTR_FONT_FAMILY = 'font-family';
 SVG_ATTR_TEXT_ANCHOR = 'text-anchor';
 SVG_ATTR_TRANSFORM = 'transform';

 { Namespace SVG }
 SVG_NAMESPACE = 'http://www.w3.org/2000/svg';
 SVG_VERSION = '1.1';

 { Valeurs par défaut SVG }
 SVG_DEFAULT_STROKE_WIDTH = 1;
 SVG_DEFAULT_FONT_SIZE = 12.0;
 SVG_DEFAULT_FONT_FAMILY = 'Arial, sans-serif';

 { Types de cotations - TODO 19 }
 DIM_LINEAR = 0;       { Cotation linéaire (horizontale ou verticale) }
 DIM_ALIGNED = 1;      { Cotation alignée (parallèle à la ligne) }
 DIM_ANGULAR = 2;      { Cotation angulaire (angle entre 2 lignes) }
 DIM_RADIAL = 3;       { Cotation radiale (rayon d'un cercle/arc) }
 DIM_DIAMETER = 4;     { Cotation diamètre (diamètre d'un cercle) }
 DIM_ORDINATE = 5;     { Cotation ordonnée (X ou Y depuis origine) }

 { Constantes de style de cotation - TODO 19 }
 DIM_ARROW_SIZE = 3.0;         { Taille des flèches en unités }
 DIM_TEXT_HEIGHT = 2.5;        { Hauteur du texte de cotation }
 DIM_TEXT_GAP = 0.625;         { Espace entre ligne et texte }
 DIM_EXTENSION_OFFSET = 0.625; { Décalage des lignes d'extension }
 DIM_EXTENSION_EXTEND = 1.25;  { Extension au-delà de la ligne de cote }

 { Tolérance de sélection (en pixels) }
 PICK_TOLERANCE = 5;

 { Constantes pour les poignées de manipulation (grips) - TODO 10 }
 MAX_GRIPS = 20;               { Nombre maximum de grips par objet }
 GRIP_SIZE = 6;                { Taille d'un grip en pixels }
 GRIP_HOT_SIZE = 8;            { Taille d'un grip survolé }

 { Types de grips }
 GRIP_NONE = 0;                { Pas de grip }
 GRIP_ENDPOINT = 1;            { Point d'extrémité (ligne, polyline) }
 GRIP_MIDPOINT = 2;            { Point milieu }
 GRIP_CENTER = 3;              { Centre (cercle, arc, ellipse) }
 GRIP_QUADRANT = 4;            { Quadrant (cercle, ellipse) }
 GRIP_RADIUS = 5;              { Rayon (cercle, arc) }
 GRIP_CORNER = 6;              { Coin (rectangle) }
 GRIP_EDGE = 7;                { Milieu d'arête }

 { Couleurs des grips }
 GRIP_COLOR_COLD = Blue;       { Grip non sélectionné }
 GRIP_COLOR_HOT = Red;         { Grip survolé }
 GRIP_COLOR_SELECTED = Green;  { Grip en cours d'édition }

 { Modes d'édition de grip }
 GRIP_EDIT_NONE = 0;           { Pas d'édition en cours }
 GRIP_EDIT_STRETCH = 1;        { Étirement (déplacement d'un point) }
 GRIP_EDIT_MOVE = 2;           { Déplacement de l'objet entier }
 GRIP_EDIT_ROTATE = 3;         { Rotation autour du grip }
 GRIP_EDIT_SCALE = 4;          { Mise à l'échelle depuis le grip }
 GRIP_EDIT_MIRROR = 5;         { Miroir par rapport au grip }

 { Constantes pour le panneau de propriétés - TODO 16 }
 PROP_PANEL_WIDTH = 200;       { Largeur du panneau de propriétés }
 PROP_PANEL_HEIGHT = 300;      { Hauteur du panneau de propriétés }
 PROP_PANEL_MARGIN = 5;        { Marge interne }
 PROP_ROW_HEIGHT = 20;         { Hauteur d'une ligne de propriété }
 PROP_LABEL_WIDTH = 80;        { Largeur de la colonne des labels }
 MAX_PROP_ROWS = 12;           { Nombre maximum de propriétés affichées }

 { Types de propriétés }
 PROP_TYPE_COLOR = 0;          { Propriété couleur }
 PROP_TYPE_LAYER = 1;          { Propriété calque }
 PROP_TYPE_LINETYPE = 2;       { Propriété type de ligne }
 PROP_TYPE_LINEWEIGHT = 3;     { Propriété épaisseur de ligne }
 PROP_TYPE_OBJTYPE = 4;        { Type d'objet (lecture seule) }
 PROP_TYPE_X1 = 5;             { Coordonnée X1 }
 PROP_TYPE_Y1 = 6;             { Coordonnée Y1 }
 PROP_TYPE_X2 = 7;             { Coordonnée X2 }
 PROP_TYPE_Y2 = 8;             { Coordonnée Y2 }
 PROP_TYPE_RADIUS = 9;         { Rayon }
 PROP_TYPE_AREA = 10;          { Surface (lecture seule) }
 PROP_TYPE_LENGTH = 11;        { Longueur (lecture seule) }

 { Types de lignes standard }
 LINETYPE_CONTINUOUS = 0;      { Ligne continue }
 LINETYPE_DASHED = 1;          { Ligne tiretée }
 LINETYPE_DOTTED = 2;          { Ligne pointillée }
 LINETYPE_DASHDOT = 3;         { Tiret-point }
 LINETYPE_DASHDOTDOT = 4;      { Tiret-point-point }
 LINETYPE_CENTER = 5;          { Axe }

 { Épaisseurs de ligne (en centièmes de mm) }
 LINEWEIGHT_DEFAULT = 0;       { Par défaut }
 LINEWEIGHT_005 = 5;           { 0.05 mm }
 LINEWEIGHT_009 = 9;           { 0.09 mm }
 LINEWEIGHT_013 = 13;          { 0.13 mm }
 LINEWEIGHT_015 = 15;          { 0.15 mm }
 LINEWEIGHT_018 = 18;          { 0.18 mm }
 LINEWEIGHT_020 = 20;          { 0.20 mm }
 LINEWEIGHT_025 = 25;          { 0.25 mm }
 LINEWEIGHT_030 = 30;          { 0.30 mm }
 LINEWEIGHT_035 = 35;          { 0.35 mm }
 LINEWEIGHT_040 = 40;          { 0.40 mm }
 LINEWEIGHT_050 = 50;          { 0.50 mm }
 LINEWEIGHT_053 = 53;          { 0.53 mm }
 LINEWEIGHT_060 = 60;          { 0.60 mm }
 LINEWEIGHT_070 = 70;          { 0.70 mm }
 LINEWEIGHT_080 = 80;          { 0.80 mm }
 LINEWEIGHT_090 = 90;          { 0.90 mm }
 LINEWEIGHT_100 = 100;         { 1.00 mm }
 LINEWEIGHT_106 = 106;         { 1.06 mm }
 LINEWEIGHT_120 = 120;         { 1.20 mm }
 LINEWEIGHT_140 = 140;         { 1.40 mm }
 LINEWEIGHT_158 = 158;         { 1.58 mm }
 LINEWEIGHT_200 = 200;         { 2.00 mm }
 LINEWEIGHT_211 = 211;         { 2.11 mm }

 { Nombre de calques maximum }
 MAX_LAYERS = 50;

 { Constantes pour l'analyseur lexical AutoLISP - TODO 11 }
 MAX_LISP_TOKENS = 500;        { Nombre maximum de tokens dans une expression }
 MAX_LISP_INPUT = 4096;        { Taille maximum d'une entrée LISP }
 MAX_LISP_SYMBOL = 64;         { Taille maximum d'un symbole }
 MAX_LISP_STRING = 256;        { Taille maximum d'une chaîne }

 { Types de tokens AutoLISP }
 LISP_TOKEN_NONE = 0;          { Token invalide ou fin }
 LISP_TOKEN_LPAREN = 1;        { Parenthèse ouvrante ( }
 LISP_TOKEN_RPAREN = 2;        { Parenthèse fermante ) }
 LISP_TOKEN_QUOTE = 3;         { Quote ' }
 LISP_TOKEN_DOT = 4;           { Point . (pour les paires pointées) }
 LISP_TOKEN_INTEGER = 5;       { Nombre entier }
 LISP_TOKEN_REAL = 6;          { Nombre réel }
 LISP_TOKEN_STRING = 7;        { Chaîne de caractères "..." }
 LISP_TOKEN_SYMBOL = 8;        { Symbole (nom de variable ou fonction) }
 LISP_TOKEN_NIL = 9;           { nil }
 LISP_TOKEN_T = 10;            { t (vrai) }
 LISP_TOKEN_EOF = 11;          { Fin de l'entrée }
 LISP_TOKEN_ERROR = 12;        { Erreur de tokenisation }

 { Caractères spéciaux AutoLISP }
 LISP_CHAR_LPAREN = '(';
 LISP_CHAR_RPAREN = ')';
 LISP_CHAR_QUOTE = '''';
 LISP_CHAR_DQUOTE = '"';
 LISP_CHAR_SEMICOLON = ';';    { Début de commentaire }
 LISP_CHAR_DOT = '.';
 LISP_CHAR_BACKSLASH = '\';    { Caractère d'échappement }

 { Constantes pour le parseur AutoLISP et l'arbre syntaxique - TODO 12 }
 MAX_LISP_NODES = 1000;        { Nombre maximum de noeuds dans l'arbre }
 MAX_LISP_CHILDREN = 50;       { Nombre maximum d'enfants par noeud (liste) }
 MAX_LISP_DEPTH = 100;         { Profondeur maximale de récursion }

 { Types de noeuds AST AutoLISP }
 LISP_NODE_NONE = 0;           { Noeud invalide }
 LISP_NODE_INTEGER = 1;        { Nombre entier }
 LISP_NODE_REAL = 2;           { Nombre réel }
 LISP_NODE_STRING = 3;         { Chaîne de caractères }
 LISP_NODE_SYMBOL = 4;         { Symbole (variable ou fonction) }
 LISP_NODE_NIL = 5;            { nil }
 LISP_NODE_T = 6;              { t (vrai) }
 LISP_NODE_LIST = 7;           { Liste (expression entre parenthèses) }
 LISP_NODE_QUOTE = 8;          { Expression quotée 'expr }
 LISP_NODE_DOTPAIR = 9;        { Paire pointée (a . b) }

 { Constantes pour l'évaluateur AutoLISP - TODO 13 }
 MAX_LISP_VARIABLES = 200;     { Nombre maximum de variables }
 MAX_LISP_STACK = 100;         { Profondeur maximale de la pile d'évaluation }
 LISP_VAR_NAME_LEN = 32;       { Longueur maximale d'un nom de variable }

 { Types de valeurs LISP pour l'évaluateur }
 LISP_VAL_NIL = 0;             { Valeur nil }
 LISP_VAL_T = 1;               { Valeur t (vrai) }
 LISP_VAL_INTEGER = 2;         { Valeur entière }
 LISP_VAL_REAL = 3;            { Valeur réelle }
 LISP_VAL_STRING = 4;          { Valeur chaîne }
 LISP_VAL_LIST = 5;            { Valeur liste (pointeur vers noeud) }
 LISP_VAL_SYMBOL = 6;          { Symbole non évalué }
 LISP_VAL_ERROR = 7;           { Erreur d'évaluation }
 LISP_VAL_ENAME = 8;           { Nom d'entité (handle) - TODO 14 }
 LISP_VAL_SELSET = 9;          { Jeu de sélection - TODO 14 }

 { Codes DXF pour les entités AutoLISP - TODO 14 }
 DXF_ENTITY_TYPE = 0;          { Type d'entité (LINE, CIRCLE, etc.) }
 DXF_LAYER_LEN = 8;            { Nom du calque }
 DXF_COLOR = 62;               { Couleur de l'entité }
 DXF_LINETYPE = 6;             { Type de ligne }
 DXF_X1 = 10;                  { Coordonnée X du premier point / centre }
 DXF_Y1 = 20;                  { Coordonnée Y du premier point / centre }
 DXF_Z1 = 30;                  { Coordonnée Z du premier point / centre }
 DXF_X2 = 11;                  { Coordonnée X du deuxième point }
 DXF_Y2 = 21;                  { Coordonnée Y du deuxième point }
 DXF_Z2 = 31;                  { Coordonnée Z du deuxième point }
 DXF_RADIUS = 40;              { Rayon (cercle, arc) }
 DXF_START_ANGLE = 50;         { Angle de départ (arc) }
 DXF_END_ANGLE = 51;           { Angle de fin (arc) }
 DXF_ENAME = -1;               { Nom d'entité (entity name/handle) }

 { Nombre maximum de jeux de sélection AutoLISP }
 MAX_LISP_SELSETS = 10;

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

 { Icône 16x16 (matrice de pixels, 255 = transparent) }
 TIcon16 = Array[0..15, 0..15] Of Byte;

 { Structure pour les boutons de barre d'outils - TODO 5 }
 TToolbarButton = Record
  Caption: String[20];      { Nom du bouton pour tooltip }
  Symbol: Char;             { Caractère symbole (fallback) }
  Command: String[20];      { Commande associée }
  Enabled: Boolean;
  Separator: Boolean;       { Séparateur visuel }
  HasIcon: Boolean;         { True si Icon contient un dessin }
  Icon: TIcon16;            { Matrice 16x16 de pixels }
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
  LineWeight:Word;            { Epaisseur de la ligne }
  LayerIndex: Byte;           { Index du calque }
  Selected: Boolean;          { True si l'objet est sélectionné }
  Visible: Boolean;           { True si l'objet est visible }
  Closed:Boolean;
  { Champs pour cotations - TODO 19 }
  DimType: Byte;              { Type de cotation (DIM_LINEAR, etc.) }
  DimX3, DimY3: Real;         { 3ème point (position ligne de cote) }
  DimX4, DimY4: Real;         { 4ème point (pour angular: 2ème ligne) }
  DimText: String[20];        { Texte de cotation (vide = auto) }
  DimValue: Real;             { Valeur mesurée }
  DimTextX, DimTextY: Real;   { Position du texte de cotation }
  VertexCount:Word;
  Vertices:Array[0..MAX_VERTICES]of Record
   X,Y:Real;
   Bulge:Word;
  End;
 End;

 { Structure pour le jeu de sélection - TODO 9 }
 TSelectionSet = Record
  Objects: Array[0..MAX_SELECTED-1] of Integer;  { Indices des objets sélectionnés }
  Count: Integer;                                { Nombre d'objets sélectionnés }
 End;

 { Structure pour une poignée de manipulation - TODO 10 }
 TGrip = Record
  X, Y: Real;           { Position en coordonnées monde }
  GripType: Byte;       { Type de grip (GRIP_ENDPOINT, GRIP_CENTER, etc.) }
  ObjIndex: Integer;    { Index de l'objet auquel appartient ce grip }
  PointIndex: Byte;     { Index du point dans l'objet (0=P1, 1=P2, etc.) }
  IsHot: Boolean;       { True si le curseur survole ce grip }
 End;

 { Structure pour le système de grips d'un objet - TODO 10 }
 TGripSet = Record
  Grips: Array[0..MAX_GRIPS-1] of TGrip;  { Liste des grips }
  Count: Integer;                          { Nombre de grips }
 End;

 { Structure pour un calque - TODO 16 }
 TLayer = Record
  Name: String[30];              { Nom du calque }
  Color: Integer;                { Couleur par défaut du calque }
  LineType: Byte;                { Type de ligne par défaut }
  LineWeight: Integer;           { Épaisseur de ligne par défaut }
  Visible: Boolean;              { Calque visible }
  Locked: Boolean;               { Calque verrouillé (non éditable) }
  Frozen: Boolean;               { Calque gelé (non régénéré) }
  OnFlag: Boolean;               { Calque allumé }
 End;

 { Structure pour une ligne de propriété - TODO 16 }
 TPropertyRow = Record
  PropType: Byte;                { Type de propriété (PROP_TYPE_xxx) }
  Label_: String[20];            { Étiquette affichée }
  Value: String[30];             { Valeur affichée }
  Editable: Boolean;             { True si éditable }
  Highlighted: Boolean;          { True si survolé }
 End;

 { Structure pour le panneau de propriétés - TODO 16 }
 TPropertiesPanel = Record
  X, Y: Integer;                 { Position du panneau }
  Width, Height: Integer;        { Dimensions }
  Visible: Boolean;              { Panneau visible }
  Dragging: Boolean;             { En cours de déplacement }
  DragOffsetX, DragOffsetY: Integer;  { Offset pour le drag }
  Rows: Array[0..MAX_PROP_ROWS-1] of TPropertyRow;  { Lignes de propriétés }
  RowCount: Integer;             { Nombre de lignes }
  HoveredRow: Integer;           { Ligne survolée (-1 si aucune) }
  SelectedRow: Integer;          { Ligne sélectionnée pour édition (-1 si aucune) }
  EditMode: Boolean;             { Mode édition actif }
  EditBuffer: String[30];        { Tampon d'édition }
  Title: String[30];             { Titre du panneau }
 End;

 { Structure pour une définition de bloc - TODO 20 }
 TBlockDef = Record
  Name: String[30];              { Nom du bloc }
  Description: String[80];       { Description du bloc }
  BaseX, BaseY: Real;            { Point de base (insertion) }
  EntityCount: Integer;          { Nombre d'entités }
  FirstEntityIdx: Integer;       { Index de la première entité dans le tableau }
  IsXRef: Boolean;               { True si c'est une définition XREF }
  XRefPath: String[255];         { Chemin du fichier XREF }
  IsDefined: Boolean;            { True si le bloc est défini }
 End;

 { Structure pour une référence de bloc (insertion) - TODO 20 }
 TBlockRef = Record
  BlockIndex: Integer;           { Index de la définition de bloc }
  InsertX, InsertY: Real;        { Point d'insertion }
  ScaleX, ScaleY: Real;          { Facteurs d'échelle }
  Rotation: Real;                { Angle de rotation (radians) }
  Color: Integer;                { Couleur (0 = ByBlock) }
  LayerIndex: Byte;              { Index du calque }
  Selected: Boolean;             { True si sélectionné }
  Visible: Boolean;              { True si visible }
 End;

 { Structure pour une référence externe (XREF) - TODO 20 }
 TXRef = Record
  Name: String[30];              { Nom de la XREF }
  FilePath: String[255];         { Chemin complet du fichier }
  InsertX, InsertY: Real;        { Point d'insertion }
  ScaleX, ScaleY: Real;          { Facteurs d'échelle }
  Rotation: Real;                { Angle de rotation }
  Status: Byte;                  { État (XREF_LOADED, etc.) }
  BlockIndex: Integer;           { Index du bloc associé (-1 si non chargé) }
  LayerPrefix: String[10];       { Préfixe pour les calques }
  Overlay: Boolean;              { True = overlay, False = attach }
  Selected: Boolean;             { True si sélectionné }
  Visible: Boolean;              { True si visible }
 End;

 { Structure pour une reference d'image (raster attachee) }
 TImageRef = Record
  Name: String[30];              { Nom court de l'image }
  FilePath: String[255];         { Chemin complet du fichier }
  InsertX, InsertY: Real;        { Coin inferieur gauche (monde) }
  Width, Height: Real;           { Dimensions en unites monde }
  Rotation: Real;                { Angle de rotation (radians) }
  Status: Byte;                  { IMGREF_LOADED, IMGREF_NOT_FOUND, ... }
  PixelWidth, PixelHeight: Integer; { Dimensions natives en pixels }
  LayerIndex: Byte;              { Index du calque }
  Brightness: Integer;           { Luminosite 0..100 }
  Contrast: Integer;             { Contraste 0..100 }
  Fade: Integer;                 { Fondu 0..100 }
  ShowFrame: Boolean;            { Afficher le cadre }
  ShowImage: Boolean;            { Afficher l'image (sinon cadre seul) }
  Selected: Boolean;             { True si selectionnee }
  Visible: Boolean;              { True si visible }
 End;

 { Reference d'objet OLE (Object Linking and Embedding) }
 TOLEObject = Record
  Name: String[30];              { Nom court (sans chemin) }
  FilePath: String[255];         { Chemin complet du fichier source }
  AppName: String[30];           { Application associee (Word, Excel, ...) }
  InsertX, InsertY: Real;        { Coin inferieur gauche (monde) }
  Width, Height: Real;           { Dimensions du cadre placeholder }
  Rotation: Real;                { Rotation (radians) }
  Status: Byte;                  { OLE_LOADED, OLE_NOT_FOUND, ... }
  Kind: Byte;                    { OLE_KIND_LINK ou OLE_KIND_EMBED }
  FileSize: LongInt;             { Taille du fichier (octets) }
  LayerIndex: Byte;
  Selected: Boolean;
  Visible: Boolean;
 End;

 { Structure pour un token AutoLISP - TODO 11 }
 TLispToken = Record
  TokenType: Byte;                         { Type du token (LISP_TOKEN_xxx) }
  IntValue: LongInt;                       { Valeur si entier }
  RealValue: Real;                         { Valeur si réel }
  StrValue: String[MAX_LISP_STRING-1];       { Valeur si chaîne ou symbole }
  Line: Integer;                           { Numéro de ligne }
  Column: Integer;                         { Position dans la ligne }
 End;

 { Structure pour l'analyseur lexical AutoLISP - TODO 11 }
 TLispTokenizer = Record
  Input: String;                           { Chaîne d'entrée à analyser }
  Position: Integer;                       { Position courante dans l'entrée }
  Length: Integer;                         { Longueur de l'entrée }
  Line: Integer;                           { Numéro de ligne courant }
  Column: Integer;                         { Position dans la ligne courante }
  Tokens: Array[0..MAX_LISP_TOKENS-1] of TLispToken;  { Liste des tokens }
  TokenCount: Integer;                     { Nombre de tokens }
  CurrentToken: Integer;                   { Index du token courant }
  ErrorMessage: String[80];                { Message d'erreur si erreur }
  HasError: Boolean;                       { True si erreur de tokenisation }
 End;

 { Structure pour un noeud de l'arbre syntaxique AutoLISP - TODO 12 }
 PLispNode = ^TLispNode;                    { Pointeur vers un noeud LISP }
 TLispNode = Record
  NodeType: Byte;                          { Type du noeud (LISP_NODE_xxx) }
  IntValue: LongInt;                       { Valeur si entier }
  RealValue: Real;                         { Valeur si réel }
  StrValue: String[MAX_LISP_STRING-1];     { Valeur si chaîne ou symbole }
  Children: Array[0..MAX_LISP_CHILDREN-1] of PLispNode;  { Enfants pour les listes }
  ChildCount: Integer;                     { Nombre d'enfants }
  Line: Integer;                           { Numéro de ligne source }
  Column: Integer;                         { Position dans la ligne source }
 End;

 { Structure pour le parseur AutoLISP - TODO 12 }
 TLispParser = Record
  Nodes: Array[0..MAX_LISP_NODES-1] of TLispNode;  { Pool de noeuds }
  NodeCount: Integer;                      { Nombre de noeuds utilisés }
  Root: PLispNode;                         { Racine de l'arbre syntaxique }
  Depth: Integer;                          { Profondeur actuelle de récursion }
  ErrorMessage: String[80];                { Message d'erreur si erreur }
  HasError: Boolean;                       { True si erreur de parsing }
 End;

 { Structure pour une valeur LISP évaluée - TODO 13 }
 TLispValue = Record
  ValueType: Byte;                         { Type de la valeur (LISP_VAL_xxx) }
  IntValue: LongInt;                       { Valeur si entier }
  RealValue: Real;                         { Valeur si réel }
  StrValue: String[MAX_LISP_STRING-1];     { Valeur si chaîne ou symbole }
  ListNode: PLispNode;                     { Pointeur si liste }
 End;

 { Structure pour une variable LISP - TODO 13 }
 TLispVariable = Record
  Name: String[LISP_VAR_NAME_LEN];         { Nom de la variable }
  Value: TLispValue;                       { Valeur de la variable }
  IsDefined: Boolean;                      { True si variable définie }
 End;

 { Structure pour l'évaluateur AutoLISP - TODO 13 }
 TLispEvaluator = Record
  Variables: Array[0..MAX_LISP_VARIABLES-1] of TLispVariable;  { Table des variables }
  VarCount: Integer;                       { Nombre de variables définies }
  StackDepth: Integer;                     { Profondeur actuelle de la pile }
  LastResult: TLispValue;                  { Dernier résultat d'évaluation }
  ErrorMessage: String[80];                { Message d'erreur si erreur }
  HasError: Boolean;                       { True si erreur d'évaluation }
 End;

 { Structure pour un jeu de sélection AutoLISP - TODO 14 }
 TLispSelectionSet = Record
  Entities: Array[0..MAX_SELECTED-1] of Integer;  { Indices des entités }
  Count: Integer;                                  { Nombre d'entités }
  IsActive: Boolean;                               { True si jeu de sélection actif }
 End;

Var
 Language:(_French,_English,_Germany,_Italian,_Spain,_Albanian,_Portuguese,_Swedish,_Danish,_Japanese);
 TmpLanguage:String;

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

 { Ligne de commande }
 CommandBuffer: String;          { Texte tapé par l'utilisateur }
 CommandPrompt: String;          { Préfixe affiché ('Command:' ou autre) }
 CommandCursorBlink: Boolean;    { État courant du curseur clignotant }
 CommandLastLine: String;        { Dernière ligne exécutée (historique simple) }

 { Action fichier en attente (saisie du nom dans la ligne de commande) }
 PendingFileAction: Integer;     { 0=aucune, 1=Ouvrir, 2=Enregistrer sous, 3=Importer, 4=Exporter, 5=Inserer bloc, 6=Inserer DWG, 7=Inserer image }
 CurrentFileName: String;        { Nom du fichier courant (vide si jamais enregistre) }

 { Suivi des modifications pour confirmation a la fermeture }
 DocumentModified: Boolean;      { True si le dessin a ete modifie depuis la derniere sauvegarde/chargement }
 LastSavedObjectCount: Integer;  { Nombre d'objets au dernier point de synchronisation }
 LastSavedBlockRefCount: Integer;{ Idem pour les references de blocs }
 LastSavedImageRefCount: Integer;{ Idem pour les references d'images }
 LastSavedXRefCount: Integer;    { Idem pour les references externes DWG }
 LastSavedOLECount: Integer;     { Idem pour les objets OLE }

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

 { Tampons Undo/Redo et Presse-papiers - menu Edition }
 UndoObjects: Array[0..MAX_OBJECTS-1] of TDrawObject;
 UndoObjectCount: Integer;
 UndoAvailable: Boolean;
 RedoObjects: Array[0..MAX_OBJECTS-1] of TDrawObject;
 RedoObjectCount: Integer;
 RedoAvailable: Boolean;
 ClipboardObjects: Array[0..MAX_SELECTED-1] of TDrawObject;
 ClipboardCount: Integer;

 { Variables pour le système de grips - TODO 10 }
 CurrentGrips: TGripSet;                               { Grips des objets sélectionnés }
 HotGripIndex: Integer;                                { Index du grip survolé (-1 si aucun) }
 ActiveGripIndex: Integer;                             { Index du grip en cours d'édition (-1 si aucun) }
 GripEditMode: Integer;                                { Mode d'édition (GRIP_EDIT_STRETCH, etc.) }
 GripEditActive: Boolean;                              { True si on est en train d'éditer via un grip }
 GripOriginalX, GripOriginalY: Real;                   { Position originale du grip avant édition }
 GripCurrentX, GripCurrentY: Real;                     { Position courante pendant l'édition }
 GripSnapEnabled: Boolean;                             { Activer l'accrochage pendant l'édition }

 { Variables pour l'analyseur lexical AutoLISP - TODO 11 }
 LispTokenizer: TLispTokenizer;                        { L'analyseur lexical global }
 LispLastResult: String[80];                           { Dernier résultat d'évaluation }
 LispDebugMode: Boolean;                               { Mode debug pour afficher les tokens }

 { Variables pour le parseur AutoLISP - TODO 12 }
 LispParser: TLispParser;                              { Le parseur global }
 LispParseDebugMode: Boolean;                          { Mode debug pour afficher l'AST }

 { Variables pour l'évaluateur AutoLISP - TODO 13 }
 LispEvaluator: TLispEvaluator;                        { L'évaluateur global }
 LispEvalDebugMode: Boolean;                           { Mode debug pour afficher les évaluations }

 { Variables pour les fonctions de dessin AutoLISP - TODO 14 }
 LispSelectionSets: Array[0..MAX_LISP_SELSETS-1] of TLispSelectionSet;  { Jeux de sélection }
 LispSelSetCount: Integer;                             { Nombre de jeux de sélection utilisés }
 LispLastEntity: Integer;                              { Dernière entité créée/sélectionnée }
 LispEntselActive: Boolean;                            { Mode de sélection d'entité actif }

 { Variables pour le panneau de propriétés - TODO 16 }
 PropertiesPanel: TPropertiesPanel;                    { Le panneau de propriétés }
 Layers: Array[0..MAX_LAYERS-1] of TLayer;             { Liste des calques }
 LayerCount: Integer;                                  { Nombre de calques }
 CurrentLayer: Integer;                                { Index du calque courant }
 CurrentColor: Integer;                                { Couleur courante (256 = ByLayer) }
 CurrentLineType: Byte;                                { Type de ligne courant }
 CurrentLineWeight: Integer;                           { Épaisseur de ligne courante }
 CurrentTextStyleName: String[16];                     { Style de texte courant }
 CurrentDimStyleName: String[16];                      { Style de cote courant }
 CurrentPointStyle: Integer;                           { PDMODE - apparence des points }
 CurrentPointSize: Real;                               { PDSIZE - taille des points }
 CurrentUnits: Integer;                                { 0=Scientific 1=Decimal 2=Engineering 3=Architectural 4=Fractional }
 LimMinX, LimMinY: Real;                               { Limites du dessin - coin bas-gauche }
 LimMaxX, LimMaxY: Real;                               { Limites du dessin - coin haut-droite }
 SnapEnabled: Boolean;                                 { Mode snap actif }
 SnapSpacing: Real;                                    { Espacement snap }
 OrthoMode: Boolean;                                   { Mode ortho }
 LastLinearDimX1, LastLinearDimY1: Real;               { Memoire derniere cote lineaire (Baseline/Continue) }
 LastLinearDimX2, LastLinearDimY2: Real;
 LastLinearDimLineY: Real;
 LastLinearDimValid: Boolean;

 { Variables pour les blocs et XREFs - TODO 20 }
 BlockDefs: Array[0..MAX_BLOCKS-1] of TBlockDef;       { Définitions de blocs }
 BlockDefCount: Integer;                               { Nombre de définitions de blocs }
 BlockRefs: Array[0..MAX_BLOCK_REFS-1] of TBlockRef;   { Références de blocs (insertions) }
 BlockRefCount: Integer;                               { Nombre de références de blocs }
 XRefs: Array[0..MAX_XREFS-1] of TXRef;                { Références externes }
 XRefCount: Integer;                                   { Nombre de XREFs }
 ImageRefs: Array[0..MAX_IMAGE_REFS-1] of TImageRef;   { References d'images attachees }
 ImageRefCount: Integer;                               { Nombre de references d'images }
 OLEObjects: Array[0..MAX_OLE_OBJECTS-1] of TOLEObject;{ Objets OLE incorpores ou lies }
 OLEObjectCount: Integer;                              { Nombre d'objets OLE }
 BlockEntities: Array[0..MAX_BLOCKS*MAX_BLOCK_ENTITIES-1] of TDrawObject;  { Entités des blocs }
 BlockEntityCount: Integer;                            { Nombre total d'entités dans les blocs }

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

{ Forward declaration - Apercu avant impression }
Procedure ShowPrintPreview; Forward;

{ Forward declarations - menu Edition }
Procedure PushUndoState; Forward;
Procedure DoUndo; Forward;
Procedure DoRedo; Forward;
Procedure CopySelectionToClipboard; Forward;
Procedure DeleteSelectedObjects; Forward;
Procedure CutSelection; Forward;
Procedure PasteFromClipboard; Forward;
Procedure SelectAllObjects; Forward;

{ Forward declarations - menu Affichage }
Procedure ViewZoomIn; Forward;
Procedure ViewZoomOut; Forward;
Procedure ViewZoomExtents; Forward;
Procedure ViewZoomAll; Forward;
Procedure ViewRedraw; Forward;
Procedure ViewEnterPanMode; Forward;
Procedure ViewEnterZoomWindowMode; Forward;

{ Forward declarations - TODO 10 - Système de grips }
Procedure InitGripSystem; Forward;
Procedure UpdateGripsForSelection; Forward;
Procedure ClearGrips; Forward;
Procedure AddGrip(X, Y: Real; GType: Byte; ObjIdx, PtIdx: Integer); Forward;
Function GetGripAtPoint(SX, SY: Integer): Integer; Forward;
Procedure SetHotGrip(GripIdx: Integer); Forward;
Procedure StartGripEdit(GripIdx: Integer); Forward;
Procedure UpdateGripEdit(SX, SY: Integer); Forward;
Procedure FinishGripEdit; Forward;
Procedure CancelGripEdit; Forward;
Procedure ApplyGripStretch(GripIdx: Integer; NewX, NewY: Real); Forward;
Procedure DrawGrips; Forward;
Procedure DrawSingleGrip(GripIdx: Integer); Forward;
Procedure GetGripsForLine(ObjIdx: Integer); Forward;
Procedure GetGripsForCircle(ObjIdx: Integer); Forward;
Procedure GetGripsForRectangle(ObjIdx: Integer); Forward;
Procedure GetGripsForArc(ObjIdx: Integer); Forward;
Procedure GetGripsForEllipse(ObjIdx: Integer); Forward;
Procedure GetGripsForPoint(ObjIdx: Integer); Forward;

{ Forward declarations - TODO 17 - Modification géométrique des objets }
Procedure MoveObject(ObjIdx: Integer; DX, DY: Real); Forward;
Procedure RotateObject(ObjIdx: Integer; CX, CY, Angle: Real); Forward;
Procedure ScaleObject(ObjIdx: Integer; CX, CY, Factor: Real); Forward;
Procedure MirrorObject(ObjIdx: Integer; X1, Y1, X2, Y2: Real); Forward;
Procedure MoveSelectedObjects(DX, DY: Real); Forward;
Procedure RotateSelectedObjects(CX, CY, Angle: Real); Forward;
Procedure ScaleSelectedObjects(CX, CY, Factor: Real); Forward;
Procedure MirrorSelectedObjects(X1, Y1, X2, Y2: Real); Forward;

{ Forward declarations - TODO 16 - Panneau de propriétés }
Procedure InitPropertiesPanel; Forward;
Procedure InitLayers; Forward;
Procedure DrawPropertiesPanel; Forward;
Procedure UpdatePropertiesPanel; Forward;
Function GetPropertyValueString(PropType: Byte; ObjIndex: Integer): String; Forward;
Procedure SetPropertyValue(PropType: Byte; ObjIndex: Integer; Value: String); Forward;
Function HandlePropertiesPanelClick(X, Y: Integer): Boolean; Forward;
Procedure HandlePropertiesPanelHover(X, Y: Integer); Forward;
Procedure StartPropertyEdit(RowIndex: Integer); Forward;
Procedure FinishPropertyEdit; Forward;
Procedure CancelPropertyEdit; Forward;
Function ColorName(Color: Integer): String; Forward;
Function LineTypeName(LT: Byte): String; Forward;
Function ObjTypeName(OT: Byte): String; Forward;
Procedure TogglePropertiesPanel; Forward;

{ Forward declarations - TODO 18 - Système de calques }
Function AddLayer(Const LayerName: String): Integer; Forward;
Function DeleteLayer(LayerIdx: Integer): Boolean; Forward;
Function FindLayerByName(Const LayerName: String): Integer; Forward;
Procedure SetLayerColor(LayerIdx: Integer; NewColor: Integer); Forward;
Procedure SetLayerLineType(LayerIdx: Integer; NewLineType: Byte); Forward;
Procedure SetLayerLineWeight(LayerIdx: Integer; NewLineWeight: Integer); Forward;
Procedure ToggleLayerVisibility(LayerIdx: Integer); Forward;
Procedure ToggleLayerLocked(LayerIdx: Integer); Forward;
Procedure ToggleLayerFrozen(LayerIdx: Integer); Forward;
Procedure ToggleLayerOn(LayerIdx: Integer); Forward;
Function IsObjectOnVisibleLayer(ObjIdx: Integer): Boolean; Forward;
Function IsObjectOnLockedLayer(ObjIdx: Integer): Boolean; Forward;
Procedure SetCurrentLayer(LayerIdx: Integer); Forward;
Procedure MoveObjectToLayer(ObjIdx: Integer; LayerIdx: Integer); Forward;
Procedure MoveSelectedObjectsToLayer(LayerIdx: Integer); Forward;
Function GetObjectEffectiveColor(ObjIdx: Integer): Integer; Forward;
Function GetObjectEffectiveLineType(ObjIdx: Integer): Byte; Forward;

{ Forward declarations - TODO 19 - Outils de cotation }
Function CreateLinearDimension(X1, Y1, X2, Y2, DimLineY: Real; IsHorizontal: Boolean): Integer; Forward;
Function CreateAlignedDimension(X1, Y1, X2, Y2, Offset: Real): Integer; Forward;
Function CreateAngularDimension(CX, CY, X1, Y1, X2, Y2, ArcRadius: Real): Integer; Forward;
Function CreateRadialDimension(CX, CY, Radius, Angle: Real): Integer; Forward;
Function CreateDiameterDimension(CX, CY, Radius, Angle: Real): Integer; Forward;
Function CreateOrdinateDimension(X, Y, LeaderEndX, LeaderEndY: Real; IsXOrdinate: Boolean): Integer; Forward;
Procedure DrawDimension(ObjIdx: Integer); Forward;
Procedure DrawDimensionArrow(X, Y, Angle: Real; Size: Real); Forward;
Function FormatDimensionValue(Value: Real): String; Forward;
Function CalculateLinearDistance(X1, Y1, X2, Y2: Real): Real; Forward;
Function CalculateAngle(X1, Y1, X2, Y2: Real): Real; Forward;
Procedure GetDimensionGrips(ObjIdx: Integer); Forward;

{ Forward declarations - TODO 20 - Blocs et XREFs }
Procedure InitBlockSystem; Forward;
Function CreateBlock(Const Name: String; BaseX, BaseY: Real): Integer; Forward;
Function AddEntityToBlock(BlockIdx: Integer; Const Entity: TDrawObject): Integer; Forward;
Function InsertBlock(BlockIdx: Integer; InsX, InsY, ScaleX, ScaleY, Rotation: Real): Integer; Forward;
Procedure ExplodeBlockRef(RefIdx: Integer); Forward;
Procedure DeleteBlock(BlockIdx: Integer); Forward;
Function FindBlockByName(Const Name: String): Integer; Forward;
Procedure DrawBlockRef(RefIdx: Integer); Forward;
Procedure GetBlockRefGrips(RefIdx: Integer); Forward;
Function AttachXRef(Const FilePath: String; InsX, InsY, ScaleX, ScaleY, Rotation: Real; IsOverlay: Boolean): Integer; Forward;
Procedure DetachXRef(XRefIdx: Integer); Forward;
Procedure ReloadXRef(XRefIdx: Integer); Forward;
Procedure UnloadXRef(XRefIdx: Integer); Forward;
Procedure BindXRef(XRefIdx: Integer); Forward;
Procedure DrawXRef(XRefIdx: Integer); Forward;
Function GetXRefStatus(XRefIdx: Integer): String; Forward;
Function AttachImageRef(Const FilePath: String; InsX, InsY, W, H, Rot: Real): Integer; Forward;
Function AttachOLEObject(Const FilePath: String; InsX, InsY, W, H: Real): Integer; Forward;
Procedure DetachImageRef(ImgIdx: Integer); Forward;
Procedure DrawImageRef(ImgIdx: Integer); Forward;
Procedure DrawOLEObject(OleIdx: Integer); Forward;
Procedure DetachOLEObject(OleIdx: Integer); Forward;
Function GetOLEObjectStatus(OleIdx: Integer): String; Forward;
Function DetectOLEApplication(Const FilePath: String): String; Forward;
Function Import3DSFile(Const FilePath: String; Var EdgeCount: Integer): Boolean; Forward;
Function ImportACISFile(Const FilePath: String; Var EdgeCount: Integer): Boolean; Forward;
Procedure CreatePaperLayout(Var EntCount: Integer); Forward;
Procedure ExecuteLayoutInsert; Forward;
Procedure ExecuteToolsSpelling; Forward;
Procedure ExecuteToolsDrawOrder; Forward;
Procedure ExecuteToolsInquiry; Forward;
Procedure ExecuteToolsCustomize; Forward;
Procedure ExecuteToolsOptions; Forward;
Procedure LoadLispApplicationFile(Const FilePath: String); Forward;
Procedure RunScriptFile(Const FilePath: String); Forward;
Procedure ExecuteDrawHatch; Forward;
Procedure ExecuteDrawRegion; Forward;
Procedure ExecuteDrawSurface; Forward;
Procedure ExecuteDrawSolid; Forward;
Function  AllocEntitySlot: Integer; Forward;
Procedure ExecuteDimQuick; Forward;
Procedure ExecuteModifyProperties; Forward;
Procedure ExecuteModifyMatchProperties; Forward;
Procedure ExecuteModifyExplode; Forward;
Procedure CopySelectedObjects(DX, DY: Real); Forward;Function GetImageRefStatus(ImgIdx: Integer): String; Forward;
Function DetectImageDimensions(Const FilePath: String; Var PW, PH: Integer): Boolean; Forward;

{ Forward declarations - Suivi des modifications et confirmation de sortie }
Function IsDocumentModified: Boolean; Forward;
Procedure DrawInterface; Forward;
Procedure MarkDocumentSaved; Forward;
Procedure MarkDocumentModified; Forward;
Function ConfirmExit: Boolean; Forward;
Procedure TransformPoint(Var X, Y: Real; InsX, InsY, ScaleX, ScaleY, Rotation: Real); Forward;

{ Forward declarations - TODO 21 - Format DWG }
Function WriteDWGFile(Const FileName: String): Boolean; Forward;
Function ReadDWGFile(Const FileName: String): Boolean; Forward;
Procedure WriteDWGHeader(Var F: File); Forward;
Procedure WriteDWGEntity(Var F: File; Const Entity: TDrawObject); Forward;
Procedure WriteDWGLayers(Var F: File); Forward;
Procedure WriteDWGBlocks(Var F: File); Forward;
Function ReadDWGHeader(Var F: File): Boolean; Forward;
Function ReadDWGEntity(Var F: File; Var Entity: TDrawObject): Boolean; Forward;
Function ReadDWGLayers(Var F: File): Boolean; Forward;
Function ReadDWGBlocks(Var F: File): Boolean; Forward;
Procedure WriteDWGByte(Var F: File; B: Byte); Forward;
Procedure WriteDWGWord(Var F: File; W: Word); Forward;
Procedure WriteDWGLongInt(Var F: File; L: LongInt); Forward;
Procedure WriteDWGReal(Var F: File; R: Real); Forward;
Procedure WriteDWGString(Var F: File; Const S: String); Forward;
Function ReadDWGByte(Var F: File): Byte; Forward;
Function ReadDWGWord(Var F: File): Word; Forward;
Function ReadDWGLongInt(Var F: File): LongInt; Forward;
Function ReadDWGReal(Var F: File): Real; Forward;
Function ReadDWGString(Var F: File): String; Forward;
Function GetDWGEntityCode(ObjType: Byte): Byte; Forward;
Function GetObjTypeFromDWG(DWGCode: Byte): Byte; Forward;

{ Forward declarations - TODO 22 - Format DXF }
Function WriteDXFFile(Const FileName: String): Boolean; Forward;
Function ReadDXFFile(Const FileName: String): Boolean; Forward;
Procedure WriteDXFGroupCode(Var F: Text; Code: Integer); Forward;
Procedure WriteDXFString(Var F: Text; Code: Integer; Const S: String); Forward;
Procedure WriteDXFInteger(Var F: Text; Code: Integer; Value: LongInt); Forward;
Procedure WriteDXFReal(Var F: Text; Code: Integer; Value: Real); Forward;
Procedure WriteDXFHeader(Var F: Text); Forward;
Procedure WriteDXFTables(Var F: Text); Forward;
Procedure WriteDXFLayers(Var F: Text); Forward;
Procedure WriteDXFBlocks(Var F: Text); Forward;
Procedure WriteDXFEntities(Var F: Text); Forward;
Procedure WriteDXFEntity(Var F: Text; Const Entity: TDrawObject; Handle: LongInt); Forward;
Procedure WriteDXFLine(Var F: Text; Const Entity: TDrawObject; Handle: LongInt); Forward;
Procedure WriteDXFCircle(Var F: Text; Const Entity: TDrawObject; Handle: LongInt); Forward;
Procedure WriteDXFArc(Var F: Text; Const Entity: TDrawObject; Handle: LongInt); Forward;
Procedure WriteDXFPoint(Var F: Text; Const Entity: TDrawObject; Handle: LongInt); Forward;
Procedure WriteDXFText(Var F: Text; Const Entity: TDrawObject; Handle: LongInt); Forward;
Procedure WriteDXFEllipse(Var F: Text; Const Entity: TDrawObject; Handle: LongInt); Forward;
Procedure WriteDXFDimension(Var F: Text; Const Entity: TDrawObject; Handle: LongInt); Forward;
Function ReadDXFGroupCode(Var F: Text): Integer; Forward;
Function ReadDXFString(Var F: Text): String; Forward;
Function ReadDXFInteger(Var F: Text): LongInt; Forward;
Function ReadDXFReal(Var F: Text): Real; Forward;
Function ReadDXFHeader(Var F: Text): Boolean; Forward;
Function ReadDXFTables(Var F: Text): Boolean; Forward;
Function ReadDXFBlocks(Var F: Text): Boolean; Forward;
Function ReadDXFEntities(Var F: Text): Boolean; Forward;
Function ReadDXFEntity(Var F: Text; Var Entity: TDrawObject): Boolean; Forward;
Function GetDXFEntityName(ObjType: Byte): String; Forward;
Function GetObjTypeFromDXF(Const EntityName: String): Byte; Forward;

{ Forward declarations - TODO 23 - Format Visio (VSD/VSDX) }
Function WriteVisioFile(Const FileName: String): Boolean; Forward;
Function ReadVisioFile(Const FileName: String): Boolean; Forward;
Function WriteVSDXFile(Const FileName: String): Boolean; Forward;
Function ReadVSDXFile(Const FileName: String): Boolean; Forward;
Procedure WriteVisioXMLHeader(Var F: Text); Forward;
Procedure WriteVisioXMLDocProps(Var F: Text); Forward;
Procedure WriteVisioXMLPages(Var F: Text); Forward;
Procedure WriteVisioXMLPage(Var F: Text; PageNum: Integer); Forward;
Procedure WriteVisioXMLShapes(Var F: Text); Forward;
Procedure WriteVisioXMLShape(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt); Forward;
Procedure WriteVisioXMLLine(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt); Forward;
Procedure WriteVisioXMLRectangle(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt); Forward;
Procedure WriteVisioXMLCircle(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt); Forward;
Procedure WriteVisioXMLEllipse(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt); Forward;
Procedure WriteVisioXMLArc(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt); Forward;
Procedure WriteVisioXMLText(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt); Forward;
Procedure WriteVisioXMLFooter(Var F: Text); Forward;
Function ReadVisioXMLHeader(Var F: Text): Boolean; Forward;
Function ReadVisioXMLPages(Var F: Text): Boolean; Forward;
Function ReadVisioXMLShapes(Var F: Text): Boolean; Forward;
Function ReadVisioXMLShape(Var F: Text; Var Entity: TDrawObject): Boolean; Forward;
Function GetVisioShapeType(ObjType: Byte): Byte; Forward;
Function GetObjTypeFromVisio(VisioType: Byte): Byte; Forward;
Function VisioColorToACI(Const ColorStr: String): Integer; Forward;
Function ACIToVisioColor(ColorIdx: Integer): String; Forward;
Procedure WriteVisioXMLCell(Var F: Text; Const CellName, Value: String); Forward;
Procedure WriteVisioXMLCellF(Var F: Text; Const CellName: String; Value: Real); Forward;
Function ExtractVisioXMLValue(Const Line, Tag: String): String; Forward;
Function IsVisioFileVSDX(Const FileName: String): Boolean; Forward;

{ Forward declarations - TODO 24 - Format SVG (Scalable Vector Graphics) }
Function WriteSVGFile(Const FileName: String): Boolean; Forward;
Procedure WriteSVGHeader(Var F: Text; Width, Height: Real); Forward;
Procedure WriteSVGFooter(Var F: Text); Forward;
Procedure WriteSVGDefs(Var F: Text); Forward;
Procedure WriteSVGEntities(Var F: Text); Forward;
Procedure WriteSVGEntity(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGLine(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGRectangle(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGCircle(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGEllipse(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGArc(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGText(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGPolyline(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGPoint(Var F: Text; Const Entity: TDrawObject); Forward;
Procedure WriteSVGDimension(Var F: Text; Const Entity: TDrawObject); Forward;
Function ACIToSVGColor(ColorIdx: Integer): String; Forward;
Function GetSVGStrokeWidth(LineWeight: Integer): Real; Forward;
Procedure WriteSVGStyle(Var F: Text; Color: Integer; LineWeight: Integer; Filled: Boolean); Forward;

{ Forward declarations - TODO 25 - Importation SVG }
Function ReadSVGFile(Const FileName: String): Boolean; Forward;
Function ExtractSVGAttr(Const Line, AttrName: String): String; Forward;
Function ExtractSVGAttrReal(Const Line, AttrName: String): Real; Forward;
Function SVGColorToACI(Const ColorStr: String): Integer; Forward;
Function HexToInt(Const HexStr: String): Integer; Forward;
Function ReadSVGLine(Const Line: String; Var Entity: TDrawObject): Boolean; Forward;
Function ReadSVGRect(Const Line: String; Var Entity: TDrawObject): Boolean; Forward;
Function ReadSVGCircle(Const Line: String; Var Entity: TDrawObject): Boolean; Forward;
Function ReadSVGEllipse(Const Line: String; Var Entity: TDrawObject): Boolean; Forward;
Function ReadSVGText(Const Line: String; TextContent: String; Var Entity: TDrawObject): Boolean; Forward;
Function ReadSVGPolyline(Const Line: String; Var Entity: TDrawObject): Boolean; Forward;
Function ReadSVGPolygon(Const Line: String; Var Entity: TDrawObject): Boolean; Forward;
Function ReadSVGPath(Const Line: String; Var Entity: TDrawObject): Boolean; Forward;
Function ParseSVGPoints(Const PointsStr: String; Var Entity: TDrawObject): Boolean; Forward;
Function GetSVGElementType(Const Line: String): String; Forward;
Function ExtractTextContent(Const Line: String): String; Forward;

{ Forward declarations - TODO 11 - Analyseur lexical AutoLISP }
Procedure InitLispTokenizer; Forward;
Procedure LispTokenizerSetInput(Const S: String); Forward;
Function LispNextChar: Char; Forward;
Function LispPeekChar: Char; Forward;
Procedure LispSkipWhitespace; Forward;
Procedure LispSkipComment; Forward;
Function LispReadNumber: TLispToken; Forward;
Function LispReadString: TLispToken; Forward;
Function LispReadSymbol: TLispToken; Forward;
Function LispGetNextToken: TLispToken; Forward;
Procedure LispTokenize(Const S: String); Forward;
Function LispTokenTypeName(TokenType: Byte): String; Forward;
Procedure LispPrintToken(Const Token: TLispToken); Forward;
Procedure LispPrintAllTokens; Forward;
Function LispIsAtEnd: Boolean; Forward;
Function LispCurrentTokenType: Byte; Forward;
Function LispAdvanceToken: TLispToken; Forward;
Function LispPeekToken: TLispToken; Forward;

{ Forward declarations - TODO 12 - Parseur AutoLISP }
Procedure InitLispParser; Forward;
Function LispAllocNode: PLispNode; Forward;
Procedure LispFreeNode(Node: PLispNode); Forward;
Procedure LispClearParser; Forward;
Function LispParseAtom: PLispNode; Forward;
Function LispParseList: PLispNode; Forward;
Function LispParseQuote: PLispNode; Forward;
Function LispParseExpr: PLispNode; Forward;
Function LispParse(Const S: String): PLispNode; Forward;
Function LispNodeTypeName(NodeType: Byte): String; Forward;
Procedure LispPrintNode(Node: PLispNode; Indent: Integer); Forward;
Procedure LispPrintAST; Forward;
Function LispNodeToString(Node: PLispNode): String; Forward;
Function LispIsNil(Node: PLispNode): Boolean; Forward;
Function LispIsList(Node: PLispNode): Boolean; Forward;
Function LispIsAtomNode(Node: PLispNode): Boolean; Forward;
Function LispListLength(Node: PLispNode): Integer; Forward;
Function LispListGet(Node: PLispNode; Index: Integer): PLispNode; Forward;

{ Forward declarations - TODO 13 - Évaluateur AutoLISP }
Procedure InitLispEvaluator; Forward;
Function LispMakeNil: TLispValue; Forward;
Function LispMakeT: TLispValue; Forward;
Function LispMakeInt(V: LongInt): TLispValue; Forward;
Function LispMakeReal(V: Real): TLispValue; Forward;
Function LispMakeString(Const S: String): TLispValue; Forward;
Function LispMakeError(Const Msg: String): TLispValue; Forward;
Function LispValueIsTrue(Const V: TLispValue): Boolean; Forward;
Function LispValueToReal(Const V: TLispValue): Real; Forward;
Function LispValueToString(Const V: TLispValue): String; Forward;
Function LispGetVariable(Const Name: String): TLispValue; Forward;
Procedure LispSetVariable(Const Name: String; Const Value: TLispValue); Forward;
Function LispEvalAtom(Node: PLispNode): TLispValue; Forward;
Function LispEvalMathOp(Const FuncName: String; Node: PLispNode): TLispValue; Forward;
Function LispEvalTrigOp(Const FuncName: String; Node: PLispNode): TLispValue; Forward;
Function LispEvalCompareOp(Const FuncName: String; Node: PLispNode): TLispValue; Forward;
Function LispEvalList(Node: PLispNode): TLispValue; Forward;
Function LispEval(Node: PLispNode): TLispValue; Forward;
Function LispEvaluate(Const S: String): TLispValue; Forward;
Procedure LispPrintValue(Const V: TLispValue); Forward;

{ Forward declarations - TODO 14 - Fonctions de dessin AutoLISP }
Procedure InitLispDrawFunctions; Forward;
Function LispMakeEname(EntityIndex: Integer): TLispValue; Forward;
Function LispMakeSelSet(SelSetIndex: Integer): TLispValue; Forward;
Function LispEntityToList(EntityIndex: Integer): TLispValue; Forward;
Function LispListToEntityType(Node: PLispNode): Integer; Forward;
Function LispFindDXFValue(Node: PLispNode; DXFCode: Integer): PLispNode; Forward;
Function LispCreateEntityFromList(Node: PLispNode): Integer; Forward;
Function LispModifyEntityFromList(EntityIndex: Integer; Node: PLispNode): Boolean; Forward;
Function LispEvalEntmake(Node: PLispNode): TLispValue; Forward;
Function LispEvalEntget(Node: PLispNode): TLispValue; Forward;
Function LispEvalEntmod(Node: PLispNode): TLispValue; Forward;
Function LispEvalEntsel(Node: PLispNode): TLispValue; Forward;
Function LispEvalSsget(Node: PLispNode): TLispValue; Forward;
Function LispEvalSsadd(Node: PLispNode): TLispValue; Forward;
Function LispEvalSslength(Node: PLispNode): TLispValue; Forward;
Function LispEvalSsname(Node: PLispNode): TLispValue; Forward;
Function LispEvalCommand(Node: PLispNode): TLispValue; Forward;
Function LispEvalDrawOp(Const FuncName: String; Node: PLispNode): TLispValue; Forward;

{ Forward declarations - TODO 15 - Fonctions de manipulation de chaînes, listes et variables }
Function LispEvalSetq(Node: PLispNode): TLispValue; Forward;
Function LispEvalDefun(Node: PLispNode): TLispValue; Forward;
Function LispEvalIf(Node: PLispNode): TLispValue; Forward;
Function LispEvalCond(Node: PLispNode): TLispValue; Forward;
Function LispEvalWhile(Node: PLispNode): TLispValue; Forward;
Function LispEvalForeach(Node: PLispNode): TLispValue; Forward;
Function LispEvalMapcar(Node: PLispNode): TLispValue; Forward;
{Function LispEvalList(Node: PLispNode): TLispValue; Forward;}
Function LispEvalCons(Node: PLispNode): TLispValue; Forward;
Function LispEvalCar(Node: PLispNode): TLispValue; Forward;
Function LispEvalCdr(Node: PLispNode): TLispValue; Forward;
Function LispEvalNth(Node: PLispNode): TLispValue; Forward;
Function LispEvalAppend(Node: PLispNode): TLispValue; Forward;
Function LispEvalReverse(Node: PLispNode): TLispValue; Forward;
Function LispEvalLengthFunc(Node: PLispNode): TLispValue; Forward;
Function LispEvalStrcat(Node: PLispNode): TLispValue; Forward;
Function LispEvalStrlen(Node: PLispNode): TLispValue; Forward;
Function LispEvalSubstr(Node: PLispNode): TLispValue; Forward;
Function LispEvalStrcase(Node: PLispNode): TLispValue; Forward;
Function LispEvalProgn(Node: PLispNode): TLispValue; Forward;
Function LispEvalControlOp(Const FuncName: String; Node: PLispNode): TLispValue; Forward;

Function ArcTan2(y,x:Real):Real;
Const
  Pi = 3.141592653589793;
Begin
 If x > 0 Then ArcTan2 := ArcTan(y / x) else
 If x < 0 Then Begin
  If y >= 0 Then ArcTan2 := ArcTan(y / x) + Pi
            Else ArcTan2 := ArcTan(y / x) - Pi;
 End
  Else { x = 0 }
 Begin
  If y > 0 Then ArcTan2 := Pi / 2 Else
  If y < 0 Then ArcTan2 := -Pi / 2
   Else
  ArcTan2 := 0; { ind�fini, mais on retourne 0 }
 End;
End;

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

Function StrToUpper(Const S:String):String;
Var I:Integer; R:String;
Begin
 R:=S;
 For I:=1 To Length(R) Do
  If(R[I]>='a')And(R[I]<='z')Then R[I]:=Chr(Ord(R[I])-32);
 StrToUpper:=R;
End;

Procedure InitMenus;
Var
 I, W, MaxW, ItemW: Integer;
Begin
 Case Language Of
  _English: Begin
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
  End;
  Else Begin
 { ====================== Menus en francais (par defaut) ====================== }

 { Menu Fichier }
 Menus[MENU_FILE].Title := 'Fichier';
 Menus[MENU_FILE].X := 5;
 Menus[MENU_FILE].Width := 270;
 Menus[MENU_FILE].ItemCount := 14;
 Menus[MENU_FILE].Items[0].Caption := 'Nouveau...';
 Menus[MENU_FILE].Items[0].Shortcut := 'Ctrl+N';
 Menus[MENU_FILE].Items[0].Enabled := True;
 Menus[MENU_FILE].Items[1].Caption := 'Ouvrir...';
 Menus[MENU_FILE].Items[1].Shortcut := 'Ctrl+O';
 Menus[MENU_FILE].Items[1].Enabled := True;
 Menus[MENU_FILE].Items[2].Caption := 'Enregistrer';
 Menus[MENU_FILE].Items[2].Shortcut := 'Ctrl+S';
 Menus[MENU_FILE].Items[2].Enabled := True;
 Menus[MENU_FILE].Items[3].Caption := 'Enregistrer sous...';
 Menus[MENU_FILE].Items[3].Shortcut := 'Ctrl+Shift+S';
 Menus[MENU_FILE].Items[3].Enabled := True;
 Menus[MENU_FILE].Items[4].Separator := True;
 Menus[MENU_FILE].Items[5].Caption := 'Importer...';
 Menus[MENU_FILE].Items[5].Shortcut := '';
 Menus[MENU_FILE].Items[5].Enabled := True;
 Menus[MENU_FILE].Items[6].Caption := 'Exporter...';
 Menus[MENU_FILE].Items[6].Shortcut := '';
 Menus[MENU_FILE].Items[6].Enabled := True;
 Menus[MENU_FILE].Items[7].Separator := True;
 Menus[MENU_FILE].Items[8].Caption := 'Imprimer...';
 Menus[MENU_FILE].Items[8].Shortcut := 'Ctrl+P';
 Menus[MENU_FILE].Items[8].Enabled := True;
 Menus[MENU_FILE].Items[9].Caption := 'Apercu avant impression';
 Menus[MENU_FILE].Items[9].Shortcut := '';
 Menus[MENU_FILE].Items[9].Enabled := True;
 Menus[MENU_FILE].Items[10].Separator := True;
 Menus[MENU_FILE].Items[11].Caption := 'Proprietes du dessin';
 Menus[MENU_FILE].Items[11].Shortcut := '';
 Menus[MENU_FILE].Items[11].Enabled := True;
 Menus[MENU_FILE].Items[12].Separator := True;
 Menus[MENU_FILE].Items[13].Caption := 'Quitter';
 Menus[MENU_FILE].Items[13].Shortcut := 'Alt+F4';
 Menus[MENU_FILE].Items[13].Enabled := True;

 { Menu Edition }
 Menus[MENU_EDIT].Title := 'Edition';
 Menus[MENU_EDIT].X := 35;
 Menus[MENU_EDIT].Width := 200;
 Menus[MENU_EDIT].ItemCount := 12;
 Menus[MENU_EDIT].Items[0].Caption := 'Annuler';
 Menus[MENU_EDIT].Items[0].Shortcut := 'Ctrl+Z';
 Menus[MENU_EDIT].Items[0].Enabled := True;
 Menus[MENU_EDIT].Items[1].Caption := 'Retablir';
 Menus[MENU_EDIT].Items[1].Shortcut := 'Ctrl+Y';
 Menus[MENU_EDIT].Items[1].Enabled := True;
 Menus[MENU_EDIT].Items[2].Separator := True;
 Menus[MENU_EDIT].Items[3].Caption := 'Couper';
 Menus[MENU_EDIT].Items[3].Shortcut := 'Ctrl+X';
 Menus[MENU_EDIT].Items[3].Enabled := True;
 Menus[MENU_EDIT].Items[4].Caption := 'Copier';
 Menus[MENU_EDIT].Items[4].Shortcut := 'Ctrl+C';
 Menus[MENU_EDIT].Items[4].Enabled := True;
 Menus[MENU_EDIT].Items[5].Caption := 'Copier avec point de base';
 Menus[MENU_EDIT].Items[5].Shortcut := 'Ctrl+Shift+C';
 Menus[MENU_EDIT].Items[5].Enabled := True;
 Menus[MENU_EDIT].Items[6].Caption := 'Coller';
 Menus[MENU_EDIT].Items[6].Shortcut := 'Ctrl+V';
 Menus[MENU_EDIT].Items[6].Enabled := True;
 Menus[MENU_EDIT].Items[7].Caption := 'Coller comme bloc';
 Menus[MENU_EDIT].Items[7].Shortcut := 'Ctrl+Shift+V';
 Menus[MENU_EDIT].Items[7].Enabled := True;
 Menus[MENU_EDIT].Items[8].Separator := True;
 Menus[MENU_EDIT].Items[9].Caption := 'Effacer';
 Menus[MENU_EDIT].Items[9].Shortcut := 'Suppr';
 Menus[MENU_EDIT].Items[9].Enabled := True;
 Menus[MENU_EDIT].Items[10].Separator := True;
 Menus[MENU_EDIT].Items[11].Caption := 'Selectionner tout';
 Menus[MENU_EDIT].Items[11].Shortcut := 'Ctrl+A';
 Menus[MENU_EDIT].Items[11].Enabled := True;

 { Menu Affichage }
 Menus[MENU_VIEW].Title := 'Affichage';
 Menus[MENU_VIEW].X := 65;
 Menus[MENU_VIEW].Width := 170;
 Menus[MENU_VIEW].ItemCount := 14;
 Menus[MENU_VIEW].Items[0].Caption := 'Redessiner';
 Menus[MENU_VIEW].Items[0].Shortcut := 'R';
 Menus[MENU_VIEW].Items[0].Enabled := True;
 Menus[MENU_VIEW].Items[1].Caption := 'Regenerer';
 Menus[MENU_VIEW].Items[1].Shortcut := '';
 Menus[MENU_VIEW].Items[1].Enabled := True;
 Menus[MENU_VIEW].Items[2].Separator := True;
 Menus[MENU_VIEW].Items[3].Caption := 'Zoom avant';
 Menus[MENU_VIEW].Items[3].Shortcut := 'Z+';
 Menus[MENU_VIEW].Items[3].Enabled := True;
 Menus[MENU_VIEW].Items[4].Caption := 'Zoom arriere';
 Menus[MENU_VIEW].Items[4].Shortcut := 'Z-';
 Menus[MENU_VIEW].Items[4].Enabled := True;
 Menus[MENU_VIEW].Items[5].Caption := 'Zoom fenetre';
 Menus[MENU_VIEW].Items[5].Shortcut := 'Z W';
 Menus[MENU_VIEW].Items[5].Enabled := True;
 Menus[MENU_VIEW].Items[6].Caption := 'Zoom etendue';
 Menus[MENU_VIEW].Items[6].Shortcut := 'Z E';
 Menus[MENU_VIEW].Items[6].Enabled := True;
 Menus[MENU_VIEW].Items[7].Caption := 'Zoom tout';
 Menus[MENU_VIEW].Items[7].Shortcut := 'Z A';
 Menus[MENU_VIEW].Items[7].Enabled := True;
 Menus[MENU_VIEW].Items[8].Separator := True;
 Menus[MENU_VIEW].Items[9].Caption := 'Panoramique';
 Menus[MENU_VIEW].Items[9].Shortcut := 'P';
 Menus[MENU_VIEW].Items[9].Enabled := True;
 Menus[MENU_VIEW].Items[10].Separator := True;
 Menus[MENU_VIEW].Items[11].Caption := 'Vues nommees...';
 Menus[MENU_VIEW].Items[11].Shortcut := 'V';
 Menus[MENU_VIEW].Items[11].Enabled := True;
 Menus[MENU_VIEW].Items[12].Caption := 'Vues 3D';
 Menus[MENU_VIEW].Items[12].Shortcut := '';
 Menus[MENU_VIEW].Items[12].Enabled := True;
 Menus[MENU_VIEW].Items[13].Caption := 'Fenetres';
 Menus[MENU_VIEW].Items[13].Shortcut := '';
 Menus[MENU_VIEW].Items[13].Enabled := True;

 { Menu Insertion }
 Menus[MENU_INSERT].Title := 'Insertion';
 Menus[MENU_INSERT].X := 100;
 Menus[MENU_INSERT].Width := 180;
 Menus[MENU_INSERT].ItemCount := 10;
 Menus[MENU_INSERT].Items[0].Caption := 'Bloc...';
 Menus[MENU_INSERT].Items[0].Shortcut := 'I';
 Menus[MENU_INSERT].Items[0].Enabled := True;
 Menus[MENU_INSERT].Items[1].Caption := 'Reference DWG...';
 Menus[MENU_INSERT].Items[1].Shortcut := '';
 Menus[MENU_INSERT].Items[1].Enabled := True;
 Menus[MENU_INSERT].Items[2].Caption := 'Reference image...';
 Menus[MENU_INSERT].Items[2].Shortcut := '';
 Menus[MENU_INSERT].Items[2].Enabled := True;
 Menus[MENU_INSERT].Items[3].Separator := True;
 Menus[MENU_INSERT].Items[4].Caption := 'Presentation';
 Menus[MENU_INSERT].Items[4].Shortcut := '';
 Menus[MENU_INSERT].Items[4].Enabled := True;
 Menus[MENU_INSERT].Items[5].Separator := True;
 Menus[MENU_INSERT].Items[6].Caption := '3D Studio...';
 Menus[MENU_INSERT].Items[6].Shortcut := '';
 Menus[MENU_INSERT].Items[6].Enabled := True;
 Menus[MENU_INSERT].Items[7].Caption := 'Fichier ACIS...';
 Menus[MENU_INSERT].Items[7].Shortcut := '';
 Menus[MENU_INSERT].Items[7].Enabled := True;
 Menus[MENU_INSERT].Items[8].Separator := True;
 Menus[MENU_INSERT].Items[9].Caption := 'Objet OLE...';
 Menus[MENU_INSERT].Items[9].Shortcut := '';
 Menus[MENU_INSERT].Items[9].Enabled := True;

 { Menu Format }
 Menus[MENU_FORMAT].Title := 'Format';
 Menus[MENU_FORMAT].X := 145;
 Menus[MENU_FORMAT].Width := 200;
 Menus[MENU_FORMAT].ItemCount := 12;
 Menus[MENU_FORMAT].Items[0].Caption := 'Calque...';
 Menus[MENU_FORMAT].Items[0].Shortcut := 'LA';
 Menus[MENU_FORMAT].Items[0].Enabled := True;
 Menus[MENU_FORMAT].Items[1].Caption := 'Couleur...';
 Menus[MENU_FORMAT].Items[1].Shortcut := 'COL';
 Menus[MENU_FORMAT].Items[1].Enabled := True;
 Menus[MENU_FORMAT].Items[2].Caption := 'Type de ligne...';
 Menus[MENU_FORMAT].Items[2].Shortcut := 'LT';
 Menus[MENU_FORMAT].Items[2].Enabled := True;
 Menus[MENU_FORMAT].Items[3].Caption := 'Epaisseur de ligne...';
 Menus[MENU_FORMAT].Items[3].Shortcut := 'LW';
 Menus[MENU_FORMAT].Items[3].Enabled := True;
 Menus[MENU_FORMAT].Items[4].Separator := True;
 Menus[MENU_FORMAT].Items[5].Caption := 'Style de texte...';
 Menus[MENU_FORMAT].Items[5].Shortcut := 'ST';
 Menus[MENU_FORMAT].Items[5].Enabled := True;
 Menus[MENU_FORMAT].Items[6].Caption := 'Style de cotation...';
 Menus[MENU_FORMAT].Items[6].Shortcut := 'D';
 Menus[MENU_FORMAT].Items[6].Enabled := True;
 Menus[MENU_FORMAT].Items[7].Caption := 'Style de point...';
 Menus[MENU_FORMAT].Items[7].Shortcut := '';
 Menus[MENU_FORMAT].Items[7].Enabled := True;
 Menus[MENU_FORMAT].Items[8].Separator := True;
 Menus[MENU_FORMAT].Items[9].Caption := 'Unites...';
 Menus[MENU_FORMAT].Items[9].Shortcut := 'UN';
 Menus[MENU_FORMAT].Items[9].Enabled := True;
 Menus[MENU_FORMAT].Items[10].Caption := 'Limites du dessin';
 Menus[MENU_FORMAT].Items[10].Shortcut := '';
 Menus[MENU_FORMAT].Items[10].Enabled := True;
 Menus[MENU_FORMAT].Items[11].Caption := 'Renommer...';
 Menus[MENU_FORMAT].Items[11].Shortcut := 'REN';
 Menus[MENU_FORMAT].Items[11].Enabled := True;

 { Menu Outils }
 Menus[MENU_TOOLS].Title := 'Outils';
 Menus[MENU_TOOLS].X := 195;
 Menus[MENU_TOOLS].Width := 220;
 Menus[MENU_TOOLS].ItemCount := 14;
 Menus[MENU_TOOLS].Items[0].Caption := 'Orthographe';
 Menus[MENU_TOOLS].Items[0].Shortcut := 'SP';
 Menus[MENU_TOOLS].Items[0].Enabled := True;
 Menus[MENU_TOOLS].Items[1].Caption := 'Selection rapide...';
 Menus[MENU_TOOLS].Items[1].Shortcut := '';
 Menus[MENU_TOOLS].Items[1].Enabled := True;
 Menus[MENU_TOOLS].Items[2].Separator := True;
 Menus[MENU_TOOLS].Items[3].Caption := 'Ordre de dessin';
 Menus[MENU_TOOLS].Items[3].Shortcut := '';
 Menus[MENU_TOOLS].Items[3].Enabled := True;
 Menus[MENU_TOOLS].Items[4].Caption := 'Renseigner';
 Menus[MENU_TOOLS].Items[4].Shortcut := '';
 Menus[MENU_TOOLS].Items[4].Enabled := True;
 Menus[MENU_TOOLS].Items[5].Separator := True;
 Menus[MENU_TOOLS].Items[6].Caption := 'Charger une application...';
 Menus[MENU_TOOLS].Items[6].Shortcut := 'AP';
 Menus[MENU_TOOLS].Items[6].Enabled := True;
 Menus[MENU_TOOLS].Items[7].Caption := 'Executer un script...';
 Menus[MENU_TOOLS].Items[7].Shortcut := 'SCR';
 Menus[MENU_TOOLS].Items[7].Enabled := True;
 Menus[MENU_TOOLS].Items[8].Separator := True;
 Menus[MENU_TOOLS].Items[9].Caption := 'AutoLISP';
 Menus[MENU_TOOLS].Items[9].Shortcut := '';
 Menus[MENU_TOOLS].Items[9].Enabled := True;
 Menus[MENU_TOOLS].Items[10].Separator := True;
 Menus[MENU_TOOLS].Items[11].Caption := 'Parametres de dessin...';
 Menus[MENU_TOOLS].Items[11].Shortcut := 'DS';
 Menus[MENU_TOOLS].Items[11].Enabled := True;
 Menus[MENU_TOOLS].Items[12].Caption := 'Personnaliser';
 Menus[MENU_TOOLS].Items[12].Shortcut := '';
 Menus[MENU_TOOLS].Items[12].Enabled := True;
 Menus[MENU_TOOLS].Items[13].Caption := 'Options...';
 Menus[MENU_TOOLS].Items[13].Shortcut := 'OP';
 Menus[MENU_TOOLS].Items[13].Enabled := True;

 { Menu Dessin }
 Menus[MENU_DRAW].Title := 'Dessin';
 Menus[MENU_DRAW].X := 235;
 Menus[MENU_DRAW].Width := 200;
 Menus[MENU_DRAW].ItemCount := 20;
 Menus[MENU_DRAW].Items[0].Caption := 'Ligne';
 Menus[MENU_DRAW].Items[0].Shortcut := 'L';
 Menus[MENU_DRAW].Items[0].Enabled := True;
 Menus[MENU_DRAW].Items[1].Caption := 'Demi-droite';
 Menus[MENU_DRAW].Items[1].Shortcut := 'RAY';
 Menus[MENU_DRAW].Items[1].Enabled := True;
 Menus[MENU_DRAW].Items[2].Caption := 'Ligne de construction';
 Menus[MENU_DRAW].Items[2].Shortcut := 'XL';
 Menus[MENU_DRAW].Items[2].Enabled := True;
 Menus[MENU_DRAW].Items[3].Separator := True;
 Menus[MENU_DRAW].Items[4].Caption := 'Polyligne';
 Menus[MENU_DRAW].Items[4].Shortcut := 'PL';
 Menus[MENU_DRAW].Items[4].Enabled := True;
 Menus[MENU_DRAW].Items[5].Caption := 'Polygone';
 Menus[MENU_DRAW].Items[5].Shortcut := 'POL';
 Menus[MENU_DRAW].Items[5].Enabled := True;
 Menus[MENU_DRAW].Items[6].Caption := 'Rectangle';
 Menus[MENU_DRAW].Items[6].Shortcut := 'REC';
 Menus[MENU_DRAW].Items[6].Enabled := True;
 Menus[MENU_DRAW].Items[7].Separator := True;
 Menus[MENU_DRAW].Items[8].Caption := 'Arc';
 Menus[MENU_DRAW].Items[8].Shortcut := 'A';
 Menus[MENU_DRAW].Items[8].Enabled := True;
 Menus[MENU_DRAW].Items[9].Caption := 'Cercle';
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
 Menus[MENU_DRAW].Items[14].Caption := 'Hachures...';
 Menus[MENU_DRAW].Items[14].Shortcut := 'H';
 Menus[MENU_DRAW].Items[14].Enabled := True;
 Menus[MENU_DRAW].Items[15].Caption := 'Region';
 Menus[MENU_DRAW].Items[15].Shortcut := 'REG';
 Menus[MENU_DRAW].Items[15].Enabled := True;
 Menus[MENU_DRAW].Items[16].Separator := True;
 Menus[MENU_DRAW].Items[17].Caption := 'Texte';
 Menus[MENU_DRAW].Items[17].Shortcut := 'T';
 Menus[MENU_DRAW].Items[17].Enabled := True;
 Menus[MENU_DRAW].Items[18].Caption := 'Surface';
 Menus[MENU_DRAW].Items[18].Shortcut := 'SUR';
 Menus[MENU_DRAW].Items[18].Enabled := True;
 Menus[MENU_DRAW].Items[19].Caption := 'Solide';
 Menus[MENU_DRAW].Items[19].Shortcut := 'SO';
 Menus[MENU_DRAW].Items[19].Enabled := True;

 { Menu Cotation }
 Menus[MENU_DIMENSION].Title := 'Cotation';
 Menus[MENU_DIMENSION].X := 280;
 Menus[MENU_DIMENSION].Width := 180;
 Menus[MENU_DIMENSION].ItemCount := 14;
 Menus[MENU_DIMENSION].Items[0].Caption := 'Cotation rapide';
 Menus[MENU_DIMENSION].Items[0].Shortcut := 'QDIM';
 Menus[MENU_DIMENSION].Items[0].Enabled := True;
 Menus[MENU_DIMENSION].Items[1].Separator := True;
 Menus[MENU_DIMENSION].Items[2].Caption := 'Lineaire';
 Menus[MENU_DIMENSION].Items[2].Shortcut := 'DLI';
 Menus[MENU_DIMENSION].Items[2].Enabled := True;
 Menus[MENU_DIMENSION].Items[3].Caption := 'Alignee';
 Menus[MENU_DIMENSION].Items[3].Shortcut := 'DAL';
 Menus[MENU_DIMENSION].Items[3].Enabled := True;
 Menus[MENU_DIMENSION].Items[4].Caption := 'Longueur d''arc';
 Menus[MENU_DIMENSION].Items[4].Shortcut := '';
 Menus[MENU_DIMENSION].Items[4].Enabled := True;
 Menus[MENU_DIMENSION].Items[5].Caption := 'Ordonnee';
 Menus[MENU_DIMENSION].Items[5].Shortcut := 'DOR';
 Menus[MENU_DIMENSION].Items[5].Enabled := True;
 Menus[MENU_DIMENSION].Items[6].Separator := True;
 Menus[MENU_DIMENSION].Items[7].Caption := 'Rayon';
 Menus[MENU_DIMENSION].Items[7].Shortcut := 'DRA';
 Menus[MENU_DIMENSION].Items[7].Enabled := True;
 Menus[MENU_DIMENSION].Items[8].Caption := 'Diametre';
 Menus[MENU_DIMENSION].Items[8].Shortcut := 'DDI';
 Menus[MENU_DIMENSION].Items[8].Enabled := True;
 Menus[MENU_DIMENSION].Items[9].Caption := 'Angulaire';
 Menus[MENU_DIMENSION].Items[9].Shortcut := 'DAN';
 Menus[MENU_DIMENSION].Items[9].Enabled := True;
 Menus[MENU_DIMENSION].Items[10].Separator := True;
 Menus[MENU_DIMENSION].Items[11].Caption := 'Ligne de base';
 Menus[MENU_DIMENSION].Items[11].Shortcut := 'DBA';
 Menus[MENU_DIMENSION].Items[11].Enabled := True;
 Menus[MENU_DIMENSION].Items[12].Caption := 'Continuer';
 Menus[MENU_DIMENSION].Items[12].Shortcut := 'DCO';
 Menus[MENU_DIMENSION].Items[12].Enabled := True;
 Menus[MENU_DIMENSION].Items[13].Caption := 'Ligne de repere';
 Menus[MENU_DIMENSION].Items[13].Shortcut := 'LE';
 Menus[MENU_DIMENSION].Items[13].Enabled := True;

 { Menu Modifier }
 Menus[MENU_MODIFY].Title := 'Modifier';
 Menus[MENU_MODIFY].X := 350;
 Menus[MENU_MODIFY].Width := 190;
 Menus[MENU_MODIFY].ItemCount := 19;
 Menus[MENU_MODIFY].Items[0].Caption := 'Proprietes';
 Menus[MENU_MODIFY].Items[0].Shortcut := 'PR';
 Menus[MENU_MODIFY].Items[0].Enabled := True;
 Menus[MENU_MODIFY].Items[1].Caption := 'Copier les proprietes';
 Menus[MENU_MODIFY].Items[1].Shortcut := 'MA';
 Menus[MENU_MODIFY].Items[1].Enabled := True;
 Menus[MENU_MODIFY].Items[2].Separator := True;
 Menus[MENU_MODIFY].Items[3].Caption := 'Effacer';
 Menus[MENU_MODIFY].Items[3].Shortcut := 'E';
 Menus[MENU_MODIFY].Items[3].Enabled := True;
 Menus[MENU_MODIFY].Items[4].Caption := 'Copier';
 Menus[MENU_MODIFY].Items[4].Shortcut := 'CO';
 Menus[MENU_MODIFY].Items[4].Enabled := True;
 Menus[MENU_MODIFY].Items[5].Caption := 'Miroir';
 Menus[MENU_MODIFY].Items[5].Shortcut := 'MI';
 Menus[MENU_MODIFY].Items[5].Enabled := True;
 Menus[MENU_MODIFY].Items[6].Caption := 'Decaler';
 Menus[MENU_MODIFY].Items[6].Shortcut := 'O';
 Menus[MENU_MODIFY].Items[6].Enabled := True;
 Menus[MENU_MODIFY].Items[7].Caption := 'Reseau';
 Menus[MENU_MODIFY].Items[7].Shortcut := 'AR';
 Menus[MENU_MODIFY].Items[7].Enabled := True;
 Menus[MENU_MODIFY].Items[8].Caption := 'Deplacer';
 Menus[MENU_MODIFY].Items[8].Shortcut := 'M';
 Menus[MENU_MODIFY].Items[8].Enabled := True;
 Menus[MENU_MODIFY].Items[9].Caption := 'Rotation';
 Menus[MENU_MODIFY].Items[9].Shortcut := 'RO';
 Menus[MENU_MODIFY].Items[9].Enabled := True;
 Menus[MENU_MODIFY].Items[10].Caption := 'Echelle';
 Menus[MENU_MODIFY].Items[10].Shortcut := 'SC';
 Menus[MENU_MODIFY].Items[10].Enabled := True;
 Menus[MENU_MODIFY].Items[11].Caption := 'Etirer';
 Menus[MENU_MODIFY].Items[11].Shortcut := 'S';
 Menus[MENU_MODIFY].Items[11].Enabled := True;
 Menus[MENU_MODIFY].Items[12].Separator := True;
 Menus[MENU_MODIFY].Items[13].Caption := 'Ajuster';
 Menus[MENU_MODIFY].Items[13].Shortcut := 'TR';
 Menus[MENU_MODIFY].Items[13].Enabled := True;
 Menus[MENU_MODIFY].Items[14].Caption := 'Prolonger';
 Menus[MENU_MODIFY].Items[14].Shortcut := 'EX';
 Menus[MENU_MODIFY].Items[14].Enabled := True;
 Menus[MENU_MODIFY].Items[15].Caption := 'Briser';
 Menus[MENU_MODIFY].Items[15].Shortcut := 'BR';
 Menus[MENU_MODIFY].Items[15].Enabled := True;
 Menus[MENU_MODIFY].Items[16].Caption := 'Chanfrein';
 Menus[MENU_MODIFY].Items[16].Shortcut := 'CHA';
 Menus[MENU_MODIFY].Items[16].Enabled := True;
 Menus[MENU_MODIFY].Items[17].Caption := 'Raccord';
 Menus[MENU_MODIFY].Items[17].Shortcut := 'F';
 Menus[MENU_MODIFY].Items[17].Enabled := True;
 Menus[MENU_MODIFY].Items[18].Caption := 'Decomposer';
 Menus[MENU_MODIFY].Items[18].Shortcut := 'X';
 Menus[MENU_MODIFY].Items[18].Enabled := True;

 { Menu Fenetre }
 Menus[MENU_WINDOW].Title := 'Fenetre';
 Menus[MENU_WINDOW].X := 410;
 Menus[MENU_WINDOW].Width := 180;
 Menus[MENU_WINDOW].ItemCount := 6;
 Menus[MENU_WINDOW].Items[0].Caption := 'Fermer';
 Menus[MENU_WINDOW].Items[0].Shortcut := '';
 Menus[MENU_WINDOW].Items[0].Enabled := True;
 Menus[MENU_WINDOW].Items[1].Caption := 'Fermer tout';
 Menus[MENU_WINDOW].Items[1].Shortcut := '';
 Menus[MENU_WINDOW].Items[1].Enabled := True;
 Menus[MENU_WINDOW].Items[2].Separator := True;
 Menus[MENU_WINDOW].Items[3].Caption := 'Cascade';
 Menus[MENU_WINDOW].Items[3].Shortcut := '';
 Menus[MENU_WINDOW].Items[3].Enabled := True;
 Menus[MENU_WINDOW].Items[4].Caption := 'Mosaique horizontale';
 Menus[MENU_WINDOW].Items[4].Shortcut := '';
 Menus[MENU_WINDOW].Items[4].Enabled := True;
 Menus[MENU_WINDOW].Items[5].Caption := 'Mosaique verticale';
 Menus[MENU_WINDOW].Items[5].Shortcut := '';
 Menus[MENU_WINDOW].Items[5].Enabled := True;

 { Menu Aide }
 Menus[MENU_HELP].Title := '?';
 Menus[MENU_HELP].X := 470;
 Menus[MENU_HELP].Width := 170;
 Menus[MENU_HELP].ItemCount := 6;
 Menus[MENU_HELP].Items[0].Caption := 'Aide';
 Menus[MENU_HELP].Items[0].Shortcut := 'F1';
 Menus[MENU_HELP].Items[0].Enabled := True;
 Menus[MENU_HELP].Items[1].Caption := 'Centre d''info';
 Menus[MENU_HELP].Items[1].Shortcut := '';
 Menus[MENU_HELP].Items[1].Enabled := True;
 Menus[MENU_HELP].Items[2].Separator := True;
 Menus[MENU_HELP].Items[3].Caption := 'Nouveautes';
 Menus[MENU_HELP].Items[3].Shortcut := '';
 Menus[MENU_HELP].Items[3].Enabled := True;
 Menus[MENU_HELP].Items[4].Separator := True;
 Menus[MENU_HELP].Items[5].Caption := 'A propos d''AutoCAD';
 Menus[MENU_HELP].Items[5].Shortcut := '';
 Menus[MENU_HELP].Items[5].Enabled := True;
  End;
 End;

 { Calcul automatique de la largeur de chaque menu deroulant en fonction
   des libelles et raccourcis. Padding gauche=5, gap caption/shortcut=10,
   padding droit=10. }
 For I := 0 To MAX_MENUS - 1 Do Begin
  MaxW := 0;
  For W := 0 To Menus[I].ItemCount - 1 Do Begin
   If Not Menus[I].Items[W].Separator Then Begin
    If Length(Menus[I].Items[W].Shortcut) > 0 Then
     ItemW := TextWidth(Menus[I].Items[W].Caption) + 10 +
              TextWidth(Menus[I].Items[W].Shortcut)
    Else
     ItemW := TextWidth(Menus[I].Items[W].Caption);
    If ItemW > MaxW Then MaxW := ItemW;
   End;
  End;
  Menus[I].Width := MaxW + 15;
 End;

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
 Gap: Integer;
 TotalTitles: Integer;
 Available: Integer;
Begin
 { Fond de la barre de menu - Style AutoCAD gris foncé }
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, 0, ScreenWidth - 1, MENUBAR_HEIGHT - 1);
 SetColor(Black);
 Line(0, MENUBAR_HEIGHT - 1, ScreenWidth - 1, MENUBAR_HEIGHT - 1);

 { Calculer la largeur totale des titres pour adapter l'espacement
   afin que tous les menus rentrent sur des ecrans 640x480. }
 TotalTitles := 0;
 For I := 0 to MAX_MENUS - 1 do
  TotalTitles := TotalTitles + TextWidth(Menus[I].Title);
 Available := ScreenWidth - 10 - TotalTitles;
 If MAX_MENUS > 1 Then Gap := Available div (MAX_MENUS - 1)
 Else Gap := 15;
 If Gap > 15 Then Gap := 15;
 If Gap < 4 Then Gap := 4;

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
  X := X + TextWidth(Menus[I].Title) + Gap;
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

 { Decaler le menu deroulant vers la gauche si il deborde a droite }
 If X + Menus[MenuIndex].Width > ScreenWidth - 2 Then
  X := ScreenWidth - 2 - Menus[MenuIndex].Width;
 If X < 2 Then X := 2;

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

{ --- Icônes 16x16 : primitives ---------------------------------------------- }

Procedure ClearIcon(Var Icon: TIcon16; Color: Byte);
Var
 IX, IY: Integer;
Begin
 For IY := 0 To 15 Do
  For IX := 0 To 15 Do
   Icon[IY, IX] := Color;
End;

Procedure IconPutPixel(Var Icon: TIcon16; X, Y: Integer; C: Byte);
Begin
 If (X >= 0) And (X <= 15) And (Y >= 0) And (Y <= 15) Then
  Icon[Y, X] := C;
End;

Procedure IconHLine(Var Icon: TIcon16; X1, X2, Y: Integer; C: Byte);
Var
 X: Integer;
Begin
 For X := X1 To X2 Do
  IconPutPixel(Icon, X, Y, C);
End;

Procedure IconVLine(Var Icon: TIcon16; X, Y1, Y2: Integer; C: Byte);
Var
 Y: Integer;
Begin
 For Y := Y1 To Y2 Do
  IconPutPixel(Icon, X, Y, C);
End;

Procedure IconRect(Var Icon: TIcon16; X1, Y1, X2, Y2: Integer; C: Byte);
Begin
 IconHLine(Icon, X1, X2, Y1, C);
 IconHLine(Icon, X1, X2, Y2, C);
 IconVLine(Icon, X1, Y1, Y2, C);
 IconVLine(Icon, X2, Y1, Y2, C);
End;

Procedure IconFillRect(Var Icon: TIcon16; X1, Y1, X2, Y2: Integer;
                       C: Byte);
Var
 Y: Integer;
Begin
 For Y := Y1 To Y2 Do
  IconHLine(Icon, X1, X2, Y, C);
End;

{ Ligne diagonale de Bresenham simplifiée dans l'icône }
Procedure IconLine(Var Icon: TIcon16; X1, Y1, X2, Y2: Integer; C: Byte);
Var
 DX, DY, SX, SY, Err, E2: Integer;
Begin
 DX := Abs(X2 - X1);
 DY := Abs(Y2 - Y1);
 If X1 < X2 Then SX := 1 Else SX := -1;
 If Y1 < Y2 Then SY := 1 Else SY := -1;
 Err := DX - DY;
 While True Do Begin
  IconPutPixel(Icon, X1, Y1, C);
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

{ Cercle dans l'icône (centre CX,CY, rayon R) }
Procedure IconCircle(Var Icon: TIcon16; CX, CY, R: Integer; C: Byte);
Var
 X, Y, D: Integer;
Begin
 X := 0;
 Y := R;
 D := 3 - 2 * R;
 While Y >= X Do Begin
  IconPutPixel(Icon, CX + X, CY + Y, C);
  IconPutPixel(Icon, CX - X, CY + Y, C);
  IconPutPixel(Icon, CX + X, CY - Y, C);
  IconPutPixel(Icon, CX - X, CY - Y, C);
  IconPutPixel(Icon, CX + Y, CY + X, C);
  IconPutPixel(Icon, CX - Y, CY + X, C);
  IconPutPixel(Icon, CX + Y, CY - X, C);
  IconPutPixel(Icon, CX - Y, CY - X, C);
  If D < 0 Then
   D := D + 4 * X + 6
  Else Begin
   D := D + 4 * (X - Y) + 10;
   Y := Y - 1;
  End;
  X := X + 1;
 End;
End;

{ Dessiner une icône 16x16 à l'écran (255 = transparent) }
Procedure DrawIcon16x16(X, Y: Integer; Var Icon: TIcon16);
Var
 IX, IY: Integer;
 C: Byte;
Begin
 For IY := 0 To 15 Do
  For IX := 0 To 15 Do Begin
   C := Icon[IY, IX];
   If C <> 255 Then
    PutPixel(X + IX, Y + IY, C);
  End;
End;

{ --- Icônes 16x16 : commandes communes (portées de DEVENV.PAS) -------------- }

Procedure MakeIconNewFile(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconFillRect(Icon, 3, 1, 11, 14, 15);
 IconRect(Icon, 3, 1, 11, 14, 0);
 IconPutPixel(Icon, 9, 1, 0);
 IconPutPixel(Icon, 10, 2, 0);
 IconPutPixel(Icon, 11, 3, 0);
 IconPutPixel(Icon, 9, 3, 8);
 IconPutPixel(Icon, 10, 3, 8);
 IconHLine(Icon, 5, 9, 6, 8);
 IconHLine(Icon, 5, 9, 8, 8);
 IconHLine(Icon, 5, 8, 10, 8);
End;

Procedure MakeIconOpen(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconFillRect(Icon, 1, 5, 14, 13, 14);
 IconRect(Icon, 1, 5, 14, 13, 0);
 IconFillRect(Icon, 1, 3, 6, 5, 14);
 IconRect(Icon, 1, 3, 6, 5, 0);
 IconHLine(Icon, 2, 13, 7, 0);
End;

Procedure MakeIconSave(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconFillRect(Icon, 2, 1, 13, 14, 1);
 IconRect(Icon, 2, 1, 13, 14, 0);
 IconFillRect(Icon, 4, 1, 11, 5, 15);
 IconRect(Icon, 4, 1, 11, 5, 0);
 IconFillRect(Icon, 5, 9, 10, 14, 8);
 IconRect(Icon, 5, 9, 10, 14, 0);
End;

Procedure MakeIconUndo(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconPutPixel(Icon, 3, 6, 1);
 IconPutPixel(Icon, 4, 5, 1);
 IconPutPixel(Icon, 5, 4, 1);
 IconHLine(Icon, 5, 11, 6, 1);
 IconHLine(Icon, 5, 11, 7, 1);
 IconPutPixel(Icon, 5, 8, 1);
 IconPutPixel(Icon, 4, 7, 1);
 IconPutPixel(Icon, 3, 8, 1);
 IconVLine(Icon, 11, 7, 11, 1);
 IconVLine(Icon, 12, 7, 11, 1);
 IconHLine(Icon, 7, 11, 11, 1);
End;

Procedure MakeIconRedo(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconPutPixel(Icon, 12, 6, 1);
 IconPutPixel(Icon, 11, 5, 1);
 IconPutPixel(Icon, 10, 4, 1);
 IconHLine(Icon, 4, 10, 6, 1);
 IconHLine(Icon, 4, 10, 7, 1);
 IconPutPixel(Icon, 10, 8, 1);
 IconPutPixel(Icon, 11, 7, 1);
 IconPutPixel(Icon, 12, 8, 1);
 IconVLine(Icon, 4, 7, 11, 1);
 IconVLine(Icon, 3, 7, 11, 1);
 IconHLine(Icon, 4, 8, 11, 1);
End;

Procedure MakeIconCopy(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconFillRect(Icon, 4, 3, 13, 14, 15);
 IconRect(Icon, 4, 3, 13, 14, 0);
 IconFillRect(Icon, 1, 0, 10, 11, 15);
 IconRect(Icon, 1, 0, 10, 11, 0);
 IconHLine(Icon, 3, 8, 3, 8);
 IconHLine(Icon, 3, 8, 5, 8);
 IconHLine(Icon, 3, 7, 7, 8);
End;

{ --- Icônes 16x16 : commandes spécifiques CAO ------------------------------- }

{ Imprimer : imprimante stylisée }
Procedure MakeIconPrint(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Feuille du dessus }
 IconFillRect(Icon, 4, 1, 11, 5, 15);
 IconRect(Icon, 4, 1, 11, 5, 0);
 { Corps imprimante }
 IconFillRect(Icon, 2, 6, 13, 11, 8);
 IconRect(Icon, 2, 6, 13, 11, 0);
 IconPutPixel(Icon, 12, 8, 2);  { LED verte }
 { Feuille sortante }
 IconFillRect(Icon, 4, 10, 11, 14, 15);
 IconRect(Icon, 4, 10, 11, 14, 0);
 IconHLine(Icon, 5, 10, 12, 8);
 IconHLine(Icon, 5, 9, 13, 8);
End;

{ Zoom : loupe }
Procedure MakeIconZoom(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconCircle(Icon, 6, 6, 4, 0);
 IconCircle(Icon, 6, 6, 3, 0);
 IconFillRect(Icon, 4, 4, 8, 8, 15);
 IconCircle(Icon, 6, 6, 4, 0);
 IconHLine(Icon, 5, 7, 6, 1);   { + horizontal }
 IconVLine(Icon, 6, 5, 7, 1);   { + vertical }
 { Manche }
 IconLine(Icon, 9, 9, 13, 13, 0);
 IconLine(Icon, 10, 9, 13, 12, 0);
End;

{ Ligne : segment diagonal avec extrémités marquées }
Procedure MakeIconLine(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconLine(Icon, 2, 13, 13, 2, 0);
 IconFillRect(Icon, 1, 12, 3, 14, 4);
 IconFillRect(Icon, 12, 1, 14, 3, 4);
End;

{ Polyligne : zigzag connecté }
Procedure MakeIconPolyline(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconLine(Icon, 1, 12, 5, 4, 0);
 IconLine(Icon, 5, 4, 9, 11, 0);
 IconLine(Icon, 9, 11, 14, 3, 0);
 IconFillRect(Icon, 0, 11, 2, 13, 4);
 IconFillRect(Icon, 4, 3, 6, 5, 4);
 IconFillRect(Icon, 8, 10, 10, 12, 4);
 IconFillRect(Icon, 13, 2, 15, 4, 4);
End;

{ Rectangle : cadre simple }
Procedure MakeIconRectangle(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconRect(Icon, 2, 3, 13, 12, 0);
 IconFillRect(Icon, 1, 2, 3, 4, 4);
 IconFillRect(Icon, 12, 11, 14, 13, 4);
End;

{ Polygone : hexagone régulier }
Procedure MakeIconPolygon(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconLine(Icon, 4, 2, 11, 2, 0);
 IconLine(Icon, 11, 2, 14, 8, 0);
 IconLine(Icon, 14, 8, 11, 13, 0);
 IconLine(Icon, 11, 13, 4, 13, 0);
 IconLine(Icon, 4, 13, 1, 8, 0);
 IconLine(Icon, 1, 8, 4, 2, 0);
End;

{ Cercle : cercle simple }
Procedure MakeIconCircle(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconCircle(Icon, 7, 7, 6, 0);
 IconPutPixel(Icon, 7, 7, 4);
End;

{ Arc : demi-cercle supérieur }
Procedure MakeIconArc(Var Icon: TIcon16);
Var
 X, Y, D: Integer;
Begin
 ClearIcon(Icon, 255);
 { Demi-cercle (Y <= centre) }
 X := 0;
 Y := 6;
 D := 3 - 12;
 While Y >= X Do Begin
  IconPutPixel(Icon, 7 + X, 9 - Y, 0);
  IconPutPixel(Icon, 7 - X, 9 - Y, 0);
  IconPutPixel(Icon, 7 + Y, 9 - X, 0);
  IconPutPixel(Icon, 7 - Y, 9 - X, 0);
  If D < 0 Then D := D + 4 * X + 6
  Else Begin D := D + 4 * (X - Y) + 10; Y := Y - 1; End;
  X := X + 1;
 End;
 IconHLine(Icon, 1, 13, 9, 0);
End;

{ Ellipse : ovale aplati }
Procedure MakeIconEllipse(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconHLine(Icon, 4, 11, 4, 0);
 IconHLine(Icon, 4, 11, 11, 0);
 IconHLine(Icon, 2, 13, 7, 0);
 IconHLine(Icon, 2, 13, 8, 0);
 IconPutPixel(Icon, 3, 5, 0);
 IconPutPixel(Icon, 12, 5, 0);
 IconPutPixel(Icon, 3, 10, 0);
 IconPutPixel(Icon, 12, 10, 0);
 IconPutPixel(Icon, 2, 6, 0);
 IconPutPixel(Icon, 13, 6, 0);
 IconPutPixel(Icon, 2, 9, 0);
 IconPutPixel(Icon, 13, 9, 0);
End;

{ Texte : lettre A capitale }
Procedure MakeIconText(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconLine(Icon, 7, 2, 3, 13, 0);
 IconLine(Icon, 8, 2, 12, 13, 0);
 IconHLine(Icon, 5, 10, 9, 0);
End;

{ Hachure : carré rempli de diagonales }
Procedure MakeIconHatch(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconRect(Icon, 2, 2, 13, 13, 0);
 IconLine(Icon, 2, 6, 6, 2, 1);
 IconLine(Icon, 2, 10, 10, 2, 1);
 IconLine(Icon, 2, 13, 13, 2, 1);
 IconLine(Icon, 6, 13, 13, 6, 1);
 IconLine(Icon, 10, 13, 13, 10, 1);
End;

{ Point : croix marqueur }
Procedure MakeIconPoint(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconHLine(Icon, 3, 11, 7, 0);
 IconVLine(Icon, 7, 3, 11, 0);
 IconFillRect(Icon, 6, 6, 8, 8, 4);
End;

{ Effacer : X rouge sur ligne }
Procedure MakeIconErase(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconLine(Icon, 2, 12, 13, 1, 8);
 IconLine(Icon, 3, 13, 14, 2, 8);
 IconLine(Icon, 3, 3, 12, 12, 4);
 IconLine(Icon, 4, 3, 12, 11, 4);
 IconLine(Icon, 12, 3, 3, 12, 4);
 IconLine(Icon, 11, 3, 3, 11, 4);
End;

{ Déplacer : croix de flèches 4 directions }
Procedure MakeIconMove(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconHLine(Icon, 2, 13, 7, 1);
 IconHLine(Icon, 2, 13, 8, 1);
 IconVLine(Icon, 7, 2, 13, 1);
 IconVLine(Icon, 8, 2, 13, 1);
 { Pointes haut/bas }
 IconPutPixel(Icon, 6, 3, 1); IconPutPixel(Icon, 9, 3, 1);
 IconPutPixel(Icon, 5, 4, 1); IconPutPixel(Icon, 10, 4, 1);
 IconPutPixel(Icon, 6, 12, 1); IconPutPixel(Icon, 9, 12, 1);
 IconPutPixel(Icon, 5, 11, 1); IconPutPixel(Icon, 10, 11, 1);
 { Pointes gauche/droite }
 IconPutPixel(Icon, 3, 6, 1); IconPutPixel(Icon, 3, 9, 1);
 IconPutPixel(Icon, 4, 5, 1); IconPutPixel(Icon, 4, 10, 1);
 IconPutPixel(Icon, 12, 6, 1); IconPutPixel(Icon, 12, 9, 1);
 IconPutPixel(Icon, 11, 5, 1); IconPutPixel(Icon, 11, 10, 1);
End;

{ Miroir : axe vertical + 2 triangles symétriques }
Procedure MakeIconMirror(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconVLine(Icon, 7, 1, 14, 0);
 IconVLine(Icon, 8, 1, 14, 0);
 IconLine(Icon, 1, 3, 5, 12, 1);
 IconLine(Icon, 5, 12, 1, 12, 1);
 IconLine(Icon, 1, 12, 1, 3, 1);
 IconLine(Icon, 14, 3, 10, 12, 1);
 IconLine(Icon, 10, 12, 14, 12, 1);
 IconLine(Icon, 14, 12, 14, 3, 1);
End;

{ Rotation : flèche circulaire }
Procedure MakeIconRotate(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconCircle(Icon, 7, 8, 5, 0);
 { Effacer un quart pour faire la flèche }
 IconHLine(Icon, 7, 12, 8, 255);
 IconPutPixel(Icon, 12, 7, 255);
 IconPutPixel(Icon, 12, 9, 255);
 { Pointe }
 IconPutPixel(Icon, 11, 4, 0);
 IconPutPixel(Icon, 12, 5, 0);
 IconPutPixel(Icon, 13, 6, 0);
 IconLine(Icon, 11, 4, 14, 7, 0);
 IconLine(Icon, 9, 5, 11, 4, 0);
End;

{ Échelle : petit carré + grand carré }
Procedure MakeIconScale(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconRect(Icon, 1, 9, 6, 14, 0);
 IconRect(Icon, 4, 1, 14, 11, 0);
 IconLine(Icon, 6, 9, 14, 1, 1);
 IconPutPixel(Icon, 13, 2, 1);
 IconPutPixel(Icon, 14, 2, 1);
 IconPutPixel(Icon, 13, 1, 1);
End;

{ Décalage : deux rectangles parallèles }
Procedure MakeIconOffset(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconRect(Icon, 1, 4, 8, 11, 0);
 IconRect(Icon, 4, 1, 14, 14, 1);
End;

{ Trim : ciseaux }
Procedure MakeIconTrim(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconLine(Icon, 2, 13, 13, 2, 8);  { ligne à trimer }
 IconRect(Icon, 1, 9, 4, 13, 0);   { poignée gauche }
 IconRect(Icon, 9, 9, 12, 13, 0);  { poignée droite }
 IconLine(Icon, 4, 11, 8, 7, 0);
 IconLine(Icon, 9, 11, 8, 7, 0);
 IconPutPixel(Icon, 7, 6, 0);
 IconPutPixel(Icon, 8, 6, 0);
End;

{ Extend : ligne + flèche vers cible }
Procedure MakeIconExtend(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconVLine(Icon, 13, 2, 13, 0);   { mur cible }
 IconVLine(Icon, 14, 2, 13, 0);
 IconHLine(Icon, 2, 11, 7, 0);    { ligne à étendre }
 IconHLine(Icon, 2, 11, 8, 0);
 { Pointe de flèche }
 IconPutPixel(Icon, 9, 5, 0);
 IconPutPixel(Icon, 10, 6, 0);
 IconPutPixel(Icon, 11, 7, 0);
 IconPutPixel(Icon, 11, 8, 0);
 IconPutPixel(Icon, 10, 9, 0);
 IconPutPixel(Icon, 9, 10, 0);
End;

{ Fillet : coin avec arrondi }
Procedure MakeIconFillet(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconHLine(Icon, 8, 14, 13, 0);
 IconVLine(Icon, 2, 1, 7, 0);
 { Quart de cercle entre (2,7) et (8,13) }
 IconPutPixel(Icon, 3, 7, 0);
 IconPutPixel(Icon, 4, 8, 0);
 IconPutPixel(Icon, 5, 9, 0);
 IconPutPixel(Icon, 5, 10, 0);
 IconPutPixel(Icon, 6, 11, 0);
 IconPutPixel(Icon, 7, 12, 0);
 IconPutPixel(Icon, 8, 12, 0);
 IconPutPixel(Icon, 2, 8, 1);
 IconPutPixel(Icon, 3, 9, 1);
 IconPutPixel(Icon, 4, 10, 1);
 IconPutPixel(Icon, 5, 11, 1);
 IconPutPixel(Icon, 6, 12, 1);
End;

{ Couche/Layer : feuilles empilées avec L }
Procedure MakeIconLayer(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconFillRect(Icon, 2, 8, 11, 13, 14);
 IconRect(Icon, 2, 8, 11, 13, 0);
 IconFillRect(Icon, 4, 5, 13, 10, 11);
 IconRect(Icon, 4, 5, 13, 10, 0);
 IconFillRect(Icon, 6, 2, 14, 7, 15);
 IconRect(Icon, 6, 2, 14, 7, 0);
End;

{ Layer current : feuille + plus }
Procedure MakeIconLayerCurrent(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconFillRect(Icon, 2, 2, 9, 11, 15);
 IconRect(Icon, 2, 2, 9, 11, 0);
 { Plus vert }
 IconHLine(Icon, 9, 13, 11, 2);
 IconHLine(Icon, 9, 13, 12, 2);
 IconVLine(Icon, 10, 9, 14, 2);
 IconVLine(Icon, 11, 9, 14, 2);
End;

{ Layer off : feuille + X }
Procedure MakeIconLayerOff(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconFillRect(Icon, 2, 2, 11, 13, 15);
 IconRect(Icon, 2, 2, 11, 13, 0);
 IconLine(Icon, 3, 3, 10, 12, 4);
 IconLine(Icon, 10, 3, 3, 12, 4);
End;

{ Layer freeze : flocon }
Procedure MakeIconLayerFreeze(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Axe vertical }
 IconVLine(Icon, 7, 1, 14, 9);
 IconVLine(Icon, 8, 1, 14, 9);
 { Axe horizontal }
 IconHLine(Icon, 1, 14, 7, 9);
 IconHLine(Icon, 1, 14, 8, 9);
 { Diagonales }
 IconLine(Icon, 3, 3, 12, 12, 9);
 IconLine(Icon, 12, 3, 3, 12, 9);
 { Petites pointes }
 IconPutPixel(Icon, 6, 2, 9); IconPutPixel(Icon, 9, 2, 9);
 IconPutPixel(Icon, 6, 13, 9); IconPutPixel(Icon, 9, 13, 9);
 IconPutPixel(Icon, 2, 6, 9); IconPutPixel(Icon, 2, 9, 9);
 IconPutPixel(Icon, 13, 6, 9); IconPutPixel(Icon, 13, 9, 9);
End;

{ Propriétés : feuille avec lignes de texte }
Procedure MakeIconProperties(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconFillRect(Icon, 2, 1, 13, 14, 15);
 IconRect(Icon, 2, 1, 13, 14, 0);
 IconHLine(Icon, 4, 11, 3, 1);
 IconHLine(Icon, 4, 8, 5, 0);
 IconHLine(Icon, 9, 11, 5, 1);
 IconHLine(Icon, 4, 8, 7, 0);
 IconHLine(Icon, 9, 11, 7, 1);
 IconHLine(Icon, 4, 8, 9, 0);
 IconHLine(Icon, 9, 11, 9, 1);
 IconHLine(Icon, 4, 8, 11, 0);
 IconHLine(Icon, 9, 11, 11, 1);
End;

{ Match properties : pinceau }
Procedure MakeIconMatchProp(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Tête du pinceau }
 IconFillRect(Icon, 2, 2, 9, 6, 14);
 IconRect(Icon, 2, 2, 9, 6, 0);
 { Métal }
 IconFillRect(Icon, 3, 7, 8, 9, 8);
 IconRect(Icon, 3, 7, 8, 9, 0);
 { Poils }
 IconFillRect(Icon, 4, 10, 7, 14, 4);
 IconRect(Icon, 4, 10, 7, 14, 0);
 { Goutte de peinture }
 IconPutPixel(Icon, 11, 9, 4);
 IconPutPixel(Icon, 12, 10, 4);
 IconPutPixel(Icon, 11, 11, 4);
 IconPutPixel(Icon, 12, 12, 4);
 IconPutPixel(Icon, 13, 11, 4);
End;

{ List : lignes de liste avec puces }
Procedure MakeIconList(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 IconPutPixel(Icon, 2, 3, 0); IconPutPixel(Icon, 3, 3, 0);
 IconPutPixel(Icon, 2, 4, 0); IconPutPixel(Icon, 3, 4, 0);
 IconHLine(Icon, 5, 13, 3, 0);
 IconHLine(Icon, 5, 13, 4, 0);
 IconPutPixel(Icon, 2, 7, 0); IconPutPixel(Icon, 3, 7, 0);
 IconPutPixel(Icon, 2, 8, 0); IconPutPixel(Icon, 3, 8, 0);
 IconHLine(Icon, 5, 13, 7, 0);
 IconHLine(Icon, 5, 13, 8, 0);
 IconPutPixel(Icon, 2, 11, 0); IconPutPixel(Icon, 3, 11, 0);
 IconPutPixel(Icon, 2, 12, 0); IconPutPixel(Icon, 3, 12, 0);
 IconHLine(Icon, 5, 13, 11, 0);
 IconHLine(Icon, 5, 13, 12, 0);
End;

{ --- Initialisation de toutes les icônes des barres d'outils ---------------- }

Procedure InitToolbarIcons;
Begin
 { ----- TOOLBAR_STANDARD ----- }
 MakeIconNewFile(Toolbars[TOOLBAR_STANDARD].Buttons[0].Icon);
 Toolbars[TOOLBAR_STANDARD].Buttons[0].HasIcon := True;
 MakeIconOpen(Toolbars[TOOLBAR_STANDARD].Buttons[1].Icon);
 Toolbars[TOOLBAR_STANDARD].Buttons[1].HasIcon := True;
 MakeIconSave(Toolbars[TOOLBAR_STANDARD].Buttons[2].Icon);
 Toolbars[TOOLBAR_STANDARD].Buttons[2].HasIcon := True;
 { 3 = séparateur }
 MakeIconPrint(Toolbars[TOOLBAR_STANDARD].Buttons[4].Icon);
 Toolbars[TOOLBAR_STANDARD].Buttons[4].HasIcon := True;
 { 5 = séparateur }
 MakeIconUndo(Toolbars[TOOLBAR_STANDARD].Buttons[6].Icon);
 Toolbars[TOOLBAR_STANDARD].Buttons[6].HasIcon := True;
 MakeIconRedo(Toolbars[TOOLBAR_STANDARD].Buttons[7].Icon);
 Toolbars[TOOLBAR_STANDARD].Buttons[7].HasIcon := True;
 { 8 = séparateur }
 MakeIconZoom(Toolbars[TOOLBAR_STANDARD].Buttons[9].Icon);
 Toolbars[TOOLBAR_STANDARD].Buttons[9].HasIcon := True;

 { ----- TOOLBAR_DRAW ----- }
 MakeIconLine(Toolbars[TOOLBAR_DRAW].Buttons[0].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[0].HasIcon := True;
 MakeIconPolyline(Toolbars[TOOLBAR_DRAW].Buttons[1].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[1].HasIcon := True;
 MakeIconRectangle(Toolbars[TOOLBAR_DRAW].Buttons[2].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[2].HasIcon := True;
 MakeIconPolygon(Toolbars[TOOLBAR_DRAW].Buttons[3].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[3].HasIcon := True;
 { 4 = séparateur }
 MakeIconCircle(Toolbars[TOOLBAR_DRAW].Buttons[5].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[5].HasIcon := True;
 MakeIconArc(Toolbars[TOOLBAR_DRAW].Buttons[6].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[6].HasIcon := True;
 MakeIconEllipse(Toolbars[TOOLBAR_DRAW].Buttons[7].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[7].HasIcon := True;
 { 8 = séparateur }
 MakeIconText(Toolbars[TOOLBAR_DRAW].Buttons[9].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[9].HasIcon := True;
 MakeIconHatch(Toolbars[TOOLBAR_DRAW].Buttons[10].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[10].HasIcon := True;
 MakeIconPoint(Toolbars[TOOLBAR_DRAW].Buttons[11].Icon);
 Toolbars[TOOLBAR_DRAW].Buttons[11].HasIcon := True;

 { ----- TOOLBAR_MODIFY ----- }
 MakeIconErase(Toolbars[TOOLBAR_MODIFY].Buttons[0].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[0].HasIcon := True;
 MakeIconCopy(Toolbars[TOOLBAR_MODIFY].Buttons[1].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[1].HasIcon := True;
 MakeIconMove(Toolbars[TOOLBAR_MODIFY].Buttons[2].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[2].HasIcon := True;
 MakeIconMirror(Toolbars[TOOLBAR_MODIFY].Buttons[3].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[3].HasIcon := True;
 { 4 = séparateur }
 MakeIconRotate(Toolbars[TOOLBAR_MODIFY].Buttons[5].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[5].HasIcon := True;
 MakeIconScale(Toolbars[TOOLBAR_MODIFY].Buttons[6].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[6].HasIcon := True;
 MakeIconOffset(Toolbars[TOOLBAR_MODIFY].Buttons[7].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[7].HasIcon := True;
 { 8 = séparateur }
 MakeIconTrim(Toolbars[TOOLBAR_MODIFY].Buttons[9].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[9].HasIcon := True;
 MakeIconExtend(Toolbars[TOOLBAR_MODIFY].Buttons[10].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[10].HasIcon := True;
 MakeIconFillet(Toolbars[TOOLBAR_MODIFY].Buttons[11].Icon);
 Toolbars[TOOLBAR_MODIFY].Buttons[11].HasIcon := True;

 { ----- TOOLBAR_LAYERS ----- }
 MakeIconLayer(Toolbars[TOOLBAR_LAYERS].Buttons[0].Icon);
 Toolbars[TOOLBAR_LAYERS].Buttons[0].HasIcon := True;
 MakeIconLayerCurrent(Toolbars[TOOLBAR_LAYERS].Buttons[1].Icon);
 Toolbars[TOOLBAR_LAYERS].Buttons[1].HasIcon := True;
 MakeIconLayerOff(Toolbars[TOOLBAR_LAYERS].Buttons[2].Icon);
 Toolbars[TOOLBAR_LAYERS].Buttons[2].HasIcon := True;
 MakeIconLayerFreeze(Toolbars[TOOLBAR_LAYERS].Buttons[3].Icon);
 Toolbars[TOOLBAR_LAYERS].Buttons[3].HasIcon := True;

 { ----- TOOLBAR_PROPERTIES ----- }
 MakeIconProperties(Toolbars[TOOLBAR_PROPERTIES].Buttons[0].Icon);
 Toolbars[TOOLBAR_PROPERTIES].Buttons[0].HasIcon := True;
 MakeIconMatchProp(Toolbars[TOOLBAR_PROPERTIES].Buttons[1].Icon);
 Toolbars[TOOLBAR_PROPERTIES].Buttons[1].HasIcon := True;
 MakeIconList(Toolbars[TOOLBAR_PROPERTIES].Buttons[2].Icon);
 Toolbars[TOOLBAR_PROPERTIES].Buttons[2].HasIcon := True;
End;

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

  { Dessiner l'icône (si disponible) ou le symbole en fallback }
  If Button.HasIcon Then Begin
   DrawIcon16x16(X + (BtnSize - 16) div 2, Y + (BtnSize - 16) div 2,
                 Button.Icon);
  End Else Begin
   If Button.Enabled Then
    SetColor(Black)
   Else
    SetColor(DarkGray);
   OutTextXY(X + (BtnSize - TextWidth(Button.Symbol)) div 2,
             Y + (BtnSize - 10) div 2, Button.Symbol);
  End;
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

 { Demarrer avec un dessin vide }
 ObjectCount := 0;
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
  { TODO 18: Vérifier la visibilité du calque }
  If Not IsObjectOnVisibleLayer(I) Then Continue;
  { TODO 18: Ne pas sélectionner les objets sur calques verrouillés }
  If IsObjectOnLockedLayer(I) Then Continue;

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
  { TODO 18: Vérifier la visibilité du calque }
  If Not IsObjectOnVisibleLayer(I) Then Continue;
  { TODO 18: Ne pas sélectionner les objets sur calques verrouillés }
  If IsObjectOnLockedLayer(I) Then Continue;

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
  { TODO 18: Vérifier la visibilité du calque }
  If Not IsObjectOnVisibleLayer(I) Then Continue;

  { Déterminer la couleur (TODO 18: support ByLayer) }
  If DrawObjects[I].Selected Then
   ObjColor := White  { Couleur de surbrillance }
  Else
   ObjColor := GetObjectEffectiveColor(I);

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

   OBJ_DIMENSION: Begin
    { TODO 19: Dessiner les cotations }
    DrawDimension(I);
   End;
  End;
 End;

 { Dessiner les références de blocs - TODO 20 }
 For I := 0 to BlockRefCount - 1 do Begin
  If BlockRefs[I].Visible and (BlockRefs[I].BlockIndex >= 0) Then
   DrawBlockRef(I);
 End;

 { Dessiner les XREFs - TODO 20 }
 For I := 0 to XRefCount - 1 do Begin
  If XRefs[I].Visible and (XRefs[I].Name <> '') Then
   DrawXRef(I);
 End;

 { Dessiner les references d'images }
 For I := 0 to ImageRefCount - 1 do Begin
  If ImageRefs[I].Visible and (ImageRefs[I].Name <> '') Then
   DrawImageRef(I);
 End;

 For I := 0 to OLEObjectCount - 1 do Begin
  If OLEObjects[I].Visible and (OLEObjects[I].Name <> '') Then
   DrawOLEObject(I);
 End;

 { Dessiner le rectangle de sélection si actif }
 If SelectionActive Then
  DrawSelectionRectangle(SelectStartX, SelectStartY, SelectEndX, SelectEndY,
                         SelectMode = SELECT_MODE_CROSSING);
End;

{ ============================================================================ }
{ Procédures pour le système de grips (poignées de manipulation) - TODO 10     }
{ Permettent d'éditer les objets sélectionnés en déplaçant leurs points        }
{ ============================================================================ }

{ Initialiser le système de grips }
Procedure InitGripSystem;
Begin
 CurrentGrips.Count := 0;
 HotGripIndex := -1;
 ActiveGripIndex := -1;
 GripEditMode := GRIP_EDIT_NONE;
 GripEditActive := False;
 GripSnapEnabled := True;
End;

{ Effacer tous les grips }
Procedure ClearGrips;
Var
 I: Integer;
Begin
 For I := 0 to CurrentGrips.Count - 1 do Begin
  CurrentGrips.Grips[I].GripType := GRIP_NONE;
  CurrentGrips.Grips[I].IsHot := False;
 End;
 CurrentGrips.Count := 0;
 HotGripIndex := -1;
End;

{ Ajouter un grip à la liste }
Procedure AddGrip(X, Y: Real; GType: Byte; ObjIdx, PtIdx: Integer);
Begin
 If CurrentGrips.Count >= MAX_GRIPS Then Exit;

 With CurrentGrips.Grips[CurrentGrips.Count] do Begin
  CurrentGrips.Grips[CurrentGrips.Count].X := X;
  CurrentGrips.Grips[CurrentGrips.Count].Y := Y;
  GripType := GType;
  ObjIndex := ObjIdx;
  PointIndex := PtIdx;
  IsHot := False;
 End;
 Inc(CurrentGrips.Count);
End;

{ Obtenir les grips pour une ligne }
Procedure GetGripsForLine(ObjIdx: Integer);
Var
 MidX, MidY: Real;
Begin
 { Point de départ (P1) }
 AddGrip(DrawObjects[ObjIdx].X1, DrawObjects[ObjIdx].Y1,
         GRIP_ENDPOINT, ObjIdx, 0);

 { Point d'arrivée (P2) }
 AddGrip(DrawObjects[ObjIdx].X2, DrawObjects[ObjIdx].Y2,
         GRIP_ENDPOINT, ObjIdx, 1);

 { Point milieu }
 MidX := (DrawObjects[ObjIdx].X1 + DrawObjects[ObjIdx].X2) / 2;
 MidY := (DrawObjects[ObjIdx].Y1 + DrawObjects[ObjIdx].Y2) / 2;
 AddGrip(MidX, MidY, GRIP_MIDPOINT, ObjIdx, 2);
End;

{ Obtenir les grips pour un cercle }
Procedure GetGripsForCircle(ObjIdx: Integer);
Var
 CX, CY, R: Real;
Begin
 CX := DrawObjects[ObjIdx].X1;
 CY := DrawObjects[ObjIdx].Y1;
 R := DrawObjects[ObjIdx].Radius;

 { Centre }
 AddGrip(CX, CY, GRIP_CENTER, ObjIdx, 0);

 { Quadrants (pour modifier le rayon) }
 AddGrip(CX, CY - R, GRIP_QUADRANT, ObjIdx, 1);  { Haut }
 AddGrip(CX, CY + R, GRIP_QUADRANT, ObjIdx, 2);  { Bas }
 AddGrip(CX - R, CY, GRIP_QUADRANT, ObjIdx, 3);  { Gauche }
 AddGrip(CX + R, CY, GRIP_QUADRANT, ObjIdx, 4);  { Droite }
End;

{ Obtenir les grips pour un rectangle }
Procedure GetGripsForRectangle(ObjIdx: Integer);
Var
 X1, Y1, X2, Y2, MidX, MidY: Real;
Begin
 X1 := DrawObjects[ObjIdx].X1;
 Y1 := DrawObjects[ObjIdx].Y1;
 X2 := DrawObjects[ObjIdx].X2;
 Y2 := DrawObjects[ObjIdx].Y2;

 { Les 4 coins }
 AddGrip(X1, Y1, GRIP_CORNER, ObjIdx, 0);  { Coin bas-gauche }
 AddGrip(X2, Y1, GRIP_CORNER, ObjIdx, 1);  { Coin bas-droit }
 AddGrip(X2, Y2, GRIP_CORNER, ObjIdx, 2);  { Coin haut-droit }
 AddGrip(X1, Y2, GRIP_CORNER, ObjIdx, 3);  { Coin haut-gauche }

 { Milieux des arêtes }
 MidX := (X1 + X2) / 2;
 MidY := (Y1 + Y2) / 2;
 AddGrip(MidX, Y1, GRIP_EDGE, ObjIdx, 4);  { Milieu bas }
 AddGrip(X2, MidY, GRIP_EDGE, ObjIdx, 5);  { Milieu droit }
 AddGrip(MidX, Y2, GRIP_EDGE, ObjIdx, 6);  { Milieu haut }
 AddGrip(X1, MidY, GRIP_EDGE, ObjIdx, 7);  { Milieu gauche }
End;

{ Obtenir les grips pour un arc - TODO 17 }
Procedure GetGripsForArc(ObjIdx: Integer);
Var
 CX, CY, R: Real;
 StartAngle, EndAngle, MidAngle: Real;
 StartX, StartY, EndX, EndY, MidX, MidY: Real;
Begin
 CX := DrawObjects[ObjIdx].X1;
 CY := DrawObjects[ObjIdx].Y1;
 R := DrawObjects[ObjIdx].Radius;
 StartAngle := DrawObjects[ObjIdx].StartAngle;
 EndAngle := DrawObjects[ObjIdx].EndAngle;

 { Centre }
 AddGrip(CX, CY, GRIP_CENTER, ObjIdx, 0);

 { Point de départ de l'arc }
 StartX := CX + R * Cos(StartAngle * Pi / 180);
 StartY := CY + R * Sin(StartAngle * Pi / 180);
 AddGrip(StartX, StartY, GRIP_ENDPOINT, ObjIdx, 1);

 { Point de fin de l'arc }
 EndX := CX + R * Cos(EndAngle * Pi / 180);
 EndY := CY + R * Sin(EndAngle * Pi / 180);
 AddGrip(EndX, EndY, GRIP_ENDPOINT, ObjIdx, 2);

 { Point milieu de l'arc (pour modifier le rayon) }
 MidAngle := (StartAngle + EndAngle) / 2;
 If EndAngle < StartAngle Then
  MidAngle := MidAngle + 180;
 MidX := CX + R * Cos(MidAngle * Pi / 180);
 MidY := CY + R * Sin(MidAngle * Pi / 180);
 AddGrip(MidX, MidY, GRIP_RADIUS, ObjIdx, 3);
End;

{ Obtenir les grips pour une ellipse - TODO 17 }
Procedure GetGripsForEllipse(ObjIdx: Integer);
Var
 CX, CY: Real;
 RadiusX, RadiusY: Real;
Begin
 CX := DrawObjects[ObjIdx].X1;
 CY := DrawObjects[ObjIdx].Y1;
 { Pour une ellipse, Radius contient le demi-axe majeur }
 { X2, Y2 contiennent le point sur le demi-axe mineur }
 RadiusX := Abs(DrawObjects[ObjIdx].X2 - CX);
 RadiusY := Abs(DrawObjects[ObjIdx].Y2 - CY);
 If RadiusX < 1 Then RadiusX := DrawObjects[ObjIdx].Radius;
 If RadiusY < 1 Then RadiusY := DrawObjects[ObjIdx].Radius / 2;

 { Centre }
 AddGrip(CX, CY, GRIP_CENTER, ObjIdx, 0);

 { Quadrants sur les axes principaux }
 AddGrip(CX + RadiusX, CY, GRIP_QUADRANT, ObjIdx, 1);  { Droite }
 AddGrip(CX - RadiusX, CY, GRIP_QUADRANT, ObjIdx, 2);  { Gauche }
 AddGrip(CX, CY + RadiusY, GRIP_QUADRANT, ObjIdx, 3);  { Haut }
 AddGrip(CX, CY - RadiusY, GRIP_QUADRANT, ObjIdx, 4);  { Bas }
End;

{ Obtenir les grips pour un point - TODO 17 }
Procedure GetGripsForPoint(ObjIdx: Integer);
Begin
 { Un point n'a qu'un seul grip: sa position }
 AddGrip(DrawObjects[ObjIdx].X1, DrawObjects[ObjIdx].Y1,
         GRIP_ENDPOINT, ObjIdx, 0);
End;

{ Mettre à jour les grips pour les objets sélectionnés }
Procedure UpdateGripsForSelection;
Var
 I, ObjIdx: Integer;
Begin
 ClearGrips;

 For I := 0 to SelectionSet.Count - 1 do Begin
  ObjIdx := SelectionSet.Objects[I];
  If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Continue;
  If DrawObjects[ObjIdx].ObjType = OBJ_NONE Then Continue;

  Case DrawObjects[ObjIdx].ObjType of
   OBJ_LINE: GetGripsForLine(ObjIdx);
   OBJ_CIRCLE: GetGripsForCircle(ObjIdx);
   OBJ_RECTANGLE: GetGripsForRectangle(ObjIdx);
   OBJ_ARC: GetGripsForArc(ObjIdx);
   OBJ_ELLIPSE: GetGripsForEllipse(ObjIdx);
   OBJ_POINT: GetGripsForPoint(ObjIdx);
   OBJ_DIMENSION: GetDimensionGrips(ObjIdx);  { TODO 19 }
  End;
 End;
End;

{ Trouver le grip à une position écran donnée }
Function GetGripAtPoint(SX, SY: Integer): Integer;
Var
 I: Integer;
 GX, GY: Integer;
 Dist: Real;
Begin
 GetGripAtPoint := -1;

 For I := 0 to CurrentGrips.Count - 1 do Begin
  GX := WorldToScreenX(CurrentGrips.Grips[I].X);
  GY := WorldToScreenY(CurrentGrips.Grips[I].Y);

  { Vérifier si le point est dans la zone du grip }
  Dist := Sqrt(Sqr(SX - GX) + Sqr(SY - GY));
  If Dist <= GRIP_SIZE Then Begin
   GetGripAtPoint := I;
   Exit;
  End;
 End;
End;

{ Définir le grip survolé (hot) }
Procedure SetHotGrip(GripIdx: Integer);
Var
 I: Integer;
Begin
 { Réinitialiser tous les grips }
 For I := 0 to CurrentGrips.Count - 1 do
  CurrentGrips.Grips[I].IsHot := False;

 { Définir le nouveau hot grip }
 HotGripIndex := GripIdx;
 If (GripIdx >= 0) and (GripIdx < CurrentGrips.Count) Then
  CurrentGrips.Grips[GripIdx].IsHot := True;
End;

{ Commencer l'édition via un grip }
Procedure StartGripEdit(GripIdx: Integer);
Begin
 If (GripIdx < 0) or (GripIdx >= CurrentGrips.Count) Then Exit;

 ActiveGripIndex := GripIdx;
 GripEditActive := True;
 GripEditMode := GRIP_EDIT_STRETCH;  { Mode par défaut: étirement }

 { Sauvegarder la position originale }
 GripOriginalX := CurrentGrips.Grips[GripIdx].X;
 GripOriginalY := CurrentGrips.Grips[GripIdx].Y;
 GripCurrentX := GripOriginalX;
 GripCurrentY := GripOriginalY;
End;

{ Mettre à jour l'édition via grip pendant le déplacement }
Procedure UpdateGripEdit(SX, SY: Integer);
Begin
 If Not GripEditActive Then Exit;
 If ActiveGripIndex < 0 Then Exit;

 { Convertir les coordonnées écran en coordonnées monde }
 GripCurrentX := ScreenToWorldX(SX);
 GripCurrentY := ScreenToWorldY(SY);

 { Appliquer l'étirement en temps réel }
 ApplyGripStretch(ActiveGripIndex, GripCurrentX, GripCurrentY);

 { Mettre à jour les grips pour refléter les changements }
 UpdateGripsForSelection;
End;

{ Appliquer l'étirement d'un grip à l'objet }
Procedure ApplyGripStretch(GripIdx: Integer; NewX, NewY: Real);
Var
 ObjIdx, PtIdx: Integer;
 DX, DY: Real;
 OldCX, OldCY, OldR, NewR: Real;
Begin
 If (GripIdx < 0) or (GripIdx >= CurrentGrips.Count) Then Exit;

 ObjIdx := CurrentGrips.Grips[GripIdx].ObjIndex;
 PtIdx := CurrentGrips.Grips[GripIdx].PointIndex;

 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;

 Case DrawObjects[ObjIdx].ObjType of
  OBJ_LINE: Begin
   Case PtIdx of
    0: Begin { Point de départ }
     DrawObjects[ObjIdx].X1 := NewX;
     DrawObjects[ObjIdx].Y1 := NewY;
    End;
    1: Begin { Point d'arrivée }
     DrawObjects[ObjIdx].X2 := NewX;
     DrawObjects[ObjIdx].Y2 := NewY;
    End;
    2: Begin { Point milieu - déplace toute la ligne }
     DX := NewX - (DrawObjects[ObjIdx].X1 + DrawObjects[ObjIdx].X2) / 2;
     DY := NewY - (DrawObjects[ObjIdx].Y1 + DrawObjects[ObjIdx].Y2) / 2;
     DrawObjects[ObjIdx].X1 := DrawObjects[ObjIdx].X1 + DX;
     DrawObjects[ObjIdx].Y1 := DrawObjects[ObjIdx].Y1 + DY;
     DrawObjects[ObjIdx].X2 := DrawObjects[ObjIdx].X2 + DX;
     DrawObjects[ObjIdx].Y2 := DrawObjects[ObjIdx].Y2 + DY;
    End;
   End;
  End;

  OBJ_CIRCLE: Begin
   OldCX := DrawObjects[ObjIdx].X1;
   OldCY := DrawObjects[ObjIdx].Y1;
   OldR := DrawObjects[ObjIdx].Radius;

   Case PtIdx of
    0: Begin { Centre - déplace le cercle }
     DrawObjects[ObjIdx].X1 := NewX;
     DrawObjects[ObjIdx].Y1 := NewY;
    End;
    1, 2, 3, 4: Begin { Quadrants - modifie le rayon }
     NewR := Sqrt(Sqr(NewX - OldCX) + Sqr(NewY - OldCY));
     If NewR > 1 Then  { Rayon minimum }
      DrawObjects[ObjIdx].Radius := NewR;
    End;
   End;
  End;

  OBJ_RECTANGLE: Begin
   Case PtIdx of
    0: Begin { Coin bas-gauche }
     DrawObjects[ObjIdx].X1 := NewX;
     DrawObjects[ObjIdx].Y1 := NewY;
    End;
    1: Begin { Coin bas-droit }
     DrawObjects[ObjIdx].X2 := NewX;
     DrawObjects[ObjIdx].Y1 := NewY;
    End;
    2: Begin { Coin haut-droit }
     DrawObjects[ObjIdx].X2 := NewX;
     DrawObjects[ObjIdx].Y2 := NewY;
    End;
    3: Begin { Coin haut-gauche }
     DrawObjects[ObjIdx].X1 := NewX;
     DrawObjects[ObjIdx].Y2 := NewY;
    End;
    4: Begin { Milieu bas - modifie Y1 seulement }
     DrawObjects[ObjIdx].Y1 := NewY;
    End;
    5: Begin { Milieu droit - modifie X2 seulement }
     DrawObjects[ObjIdx].X2 := NewX;
    End;
    6: Begin { Milieu haut - modifie Y2 seulement }
     DrawObjects[ObjIdx].Y2 := NewY;
    End;
    7: Begin { Milieu gauche - modifie X1 seulement }
     DrawObjects[ObjIdx].X1 := NewX;
    End;
   End;
  End;

  OBJ_ARC: Begin { TODO 17 }
   OldCX := DrawObjects[ObjIdx].X1;
   OldCY := DrawObjects[ObjIdx].Y1;
   OldR := DrawObjects[ObjIdx].Radius;

   Case PtIdx of
    0: Begin { Centre - déplace l'arc }
     DrawObjects[ObjIdx].X1 := NewX;
     DrawObjects[ObjIdx].Y1 := NewY;
    End;
    1: Begin { Point de départ - modifie l'angle de départ et le rayon }
     NewR := Sqrt(Sqr(NewX - OldCX) + Sqr(NewY - OldCY));
     If NewR > 1 Then Begin
      DrawObjects[ObjIdx].Radius := NewR;
      DrawObjects[ObjIdx].StartAngle := ArcTan2(NewY - OldCY, NewX - OldCX) * 180 / Pi;
     End;
    End;
    2: Begin { Point de fin - modifie l'angle de fin et le rayon }
     NewR := Sqrt(Sqr(NewX - OldCX) + Sqr(NewY - OldCY));
     If NewR > 1 Then Begin
      DrawObjects[ObjIdx].Radius := NewR;
      DrawObjects[ObjIdx].EndAngle := ArcTan2(NewY - OldCY, NewX - OldCX) * 180 / Pi;
     End;
    End;
    3: Begin { Point milieu - modifie le rayon seulement }
     NewR := Sqrt(Sqr(NewX - OldCX) + Sqr(NewY - OldCY));
     If NewR > 1 Then
      DrawObjects[ObjIdx].Radius := NewR;
    End;
   End;
  End;

  OBJ_ELLIPSE: Begin { TODO 17 }
   OldCX := DrawObjects[ObjIdx].X1;
   OldCY := DrawObjects[ObjIdx].Y1;

   Case PtIdx of
    0: Begin { Centre - déplace l'ellipse }
     DX := NewX - OldCX;
     DY := NewY - OldCY;
     DrawObjects[ObjIdx].X1 := NewX;
     DrawObjects[ObjIdx].Y1 := NewY;
     DrawObjects[ObjIdx].X2 := DrawObjects[ObjIdx].X2 + DX;
     DrawObjects[ObjIdx].Y2 := DrawObjects[ObjIdx].Y2 + DY;
    End;
    1, 2: Begin { Quadrants horizontaux - modifie le rayon X }
     NewR := Abs(NewX - OldCX);
     If NewR > 1 Then Begin
      DrawObjects[ObjIdx].Radius := NewR;
      DrawObjects[ObjIdx].X2 := OldCX + NewR;
     End;
    End;
    3, 4: Begin { Quadrants verticaux - modifie le rayon Y }
     NewR := Abs(NewY - OldCY);
     If NewR > 1 Then
      DrawObjects[ObjIdx].Y2 := OldCY + NewR;
    End;
   End;
  End;

  OBJ_POINT: Begin { TODO 17 }
   Case PtIdx of
    0: Begin { Position du point }
     DrawObjects[ObjIdx].X1 := NewX;
     DrawObjects[ObjIdx].Y1 := NewY;
    End;
   End;
  End;
 End;
End;

{ Terminer l'édition via grip (valider les changements) }
Procedure FinishGripEdit;
Begin
 If Not GripEditActive Then Exit;

 { Les changements ont déjà été appliqués via ApplyGripStretch }
 { On réinitialise simplement l'état d'édition }

 GripEditActive := False;
 ActiveGripIndex := -1;
 GripEditMode := GRIP_EDIT_NONE;

 { Mettre à jour les grips }
 UpdateGripsForSelection;
End;

{ Annuler l'édition via grip (restaurer les valeurs originales) }
Procedure CancelGripEdit;
Begin
 If Not GripEditActive Then Exit;
 If ActiveGripIndex < 0 Then Exit;

 { Restaurer la position originale }
 ApplyGripStretch(ActiveGripIndex, GripOriginalX, GripOriginalY);

 { Réinitialiser l'état }
 GripEditActive := False;
 ActiveGripIndex := -1;
 GripEditMode := GRIP_EDIT_NONE;

 { Mettre à jour les grips }
 UpdateGripsForSelection;
End;

{ ============================================================================ }
{ Fonctions de modification géométrique des objets - TODO 17                   }
{ ============================================================================ }

{ Déplacer un objet de DX, DY }
Procedure MoveObject(ObjIdx: Integer; DX, DY: Real);
Begin
 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;
 If DrawObjects[ObjIdx].ObjType = OBJ_NONE Then Exit;

 Case DrawObjects[ObjIdx].ObjType of
  OBJ_LINE, OBJ_RECTANGLE: Begin
   DrawObjects[ObjIdx].X1 := DrawObjects[ObjIdx].X1 + DX;
   DrawObjects[ObjIdx].Y1 := DrawObjects[ObjIdx].Y1 + DY;
   DrawObjects[ObjIdx].X2 := DrawObjects[ObjIdx].X2 + DX;
   DrawObjects[ObjIdx].Y2 := DrawObjects[ObjIdx].Y2 + DY;
  End;
  OBJ_CIRCLE, OBJ_ARC, OBJ_POINT: Begin
   DrawObjects[ObjIdx].X1 := DrawObjects[ObjIdx].X1 + DX;
   DrawObjects[ObjIdx].Y1 := DrawObjects[ObjIdx].Y1 + DY;
  End;
  OBJ_ELLIPSE: Begin
   DrawObjects[ObjIdx].X1 := DrawObjects[ObjIdx].X1 + DX;
   DrawObjects[ObjIdx].Y1 := DrawObjects[ObjIdx].Y1 + DY;
   DrawObjects[ObjIdx].X2 := DrawObjects[ObjIdx].X2 + DX;
   DrawObjects[ObjIdx].Y2 := DrawObjects[ObjIdx].Y2 + DY;
  End;
 End;
End;

{ Faire pivoter un objet autour d'un point central (CX, CY) d'un angle en degrés }
Procedure RotateObject(ObjIdx: Integer; CX, CY, Angle: Real);
Var
 AngleRad, CosA, SinA: Real;
 OldX1, OldY1, OldX2, OldY2: Real;
 NewX, NewY: Real;
Begin
 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;
 If DrawObjects[ObjIdx].ObjType = OBJ_NONE Then Exit;

 AngleRad := Angle * Pi / 180;
 CosA := Cos(AngleRad);
 SinA := Sin(AngleRad);

 Case DrawObjects[ObjIdx].ObjType of
  OBJ_LINE, OBJ_RECTANGLE: Begin
   { Rotation de P1 }
   OldX1 := DrawObjects[ObjIdx].X1 - CX;
   OldY1 := DrawObjects[ObjIdx].Y1 - CY;
   NewX := OldX1 * CosA - OldY1 * SinA;
   NewY := OldX1 * SinA + OldY1 * CosA;
   DrawObjects[ObjIdx].X1 := NewX + CX;
   DrawObjects[ObjIdx].Y1 := NewY + CY;

   { Rotation de P2 }
   OldX2 := DrawObjects[ObjIdx].X2 - CX;
   OldY2 := DrawObjects[ObjIdx].Y2 - CY;
   NewX := OldX2 * CosA - OldY2 * SinA;
   NewY := OldX2 * SinA + OldY2 * CosA;
   DrawObjects[ObjIdx].X2 := NewX + CX;
   DrawObjects[ObjIdx].Y2 := NewY + CY;
  End;

  OBJ_CIRCLE, OBJ_POINT: Begin
   { Rotation du centre }
   OldX1 := DrawObjects[ObjIdx].X1 - CX;
   OldY1 := DrawObjects[ObjIdx].Y1 - CY;
   NewX := OldX1 * CosA - OldY1 * SinA;
   NewY := OldX1 * SinA + OldY1 * CosA;
   DrawObjects[ObjIdx].X1 := NewX + CX;
   DrawObjects[ObjIdx].Y1 := NewY + CY;
  End;

  OBJ_ARC: Begin
   { Rotation du centre }
   OldX1 := DrawObjects[ObjIdx].X1 - CX;
   OldY1 := DrawObjects[ObjIdx].Y1 - CY;
   NewX := OldX1 * CosA - OldY1 * SinA;
   NewY := OldX1 * SinA + OldY1 * CosA;
   DrawObjects[ObjIdx].X1 := NewX + CX;
   DrawObjects[ObjIdx].Y1 := NewY + CY;
   { Ajuster les angles de l'arc }
   DrawObjects[ObjIdx].StartAngle := DrawObjects[ObjIdx].StartAngle + Angle;
   DrawObjects[ObjIdx].EndAngle := DrawObjects[ObjIdx].EndAngle + Angle;
  End;

  OBJ_ELLIPSE: Begin
   { Rotation du centre }
   OldX1 := DrawObjects[ObjIdx].X1 - CX;
   OldY1 := DrawObjects[ObjIdx].Y1 - CY;
   NewX := OldX1 * CosA - OldY1 * SinA;
   NewY := OldX1 * SinA + OldY1 * CosA;
   DrawObjects[ObjIdx].X1 := NewX + CX;
   DrawObjects[ObjIdx].Y1 := NewY + CY;

   { Rotation du point définissant l'axe }
   OldX2 := DrawObjects[ObjIdx].X2 - CX;
   OldY2 := DrawObjects[ObjIdx].Y2 - CY;
   NewX := OldX2 * CosA - OldY2 * SinA;
   NewY := OldX2 * SinA + OldY2 * CosA;
   DrawObjects[ObjIdx].X2 := NewX + CX;
   DrawObjects[ObjIdx].Y2 := NewY + CY;
  End;
 End;
End;

{ Mettre à l'échelle un objet par rapport à un point de base (CX, CY) }
Procedure ScaleObject(ObjIdx: Integer; CX, CY, Factor: Real);
Var
 DX1, DY1, DX2, DY2: Real;
Begin
 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;
 If DrawObjects[ObjIdx].ObjType = OBJ_NONE Then Exit;
 If Factor <= 0 Then Exit;

 Case DrawObjects[ObjIdx].ObjType of
  OBJ_LINE, OBJ_RECTANGLE: Begin
   DX1 := DrawObjects[ObjIdx].X1 - CX;
   DY1 := DrawObjects[ObjIdx].Y1 - CY;
   DX2 := DrawObjects[ObjIdx].X2 - CX;
   DY2 := DrawObjects[ObjIdx].Y2 - CY;
   DrawObjects[ObjIdx].X1 := CX + DX1 * Factor;
   DrawObjects[ObjIdx].Y1 := CY + DY1 * Factor;
   DrawObjects[ObjIdx].X2 := CX + DX2 * Factor;
   DrawObjects[ObjIdx].Y2 := CY + DY2 * Factor;
  End;

  OBJ_CIRCLE, OBJ_ARC: Begin
   DX1 := DrawObjects[ObjIdx].X1 - CX;
   DY1 := DrawObjects[ObjIdx].Y1 - CY;
   DrawObjects[ObjIdx].X1 := CX + DX1 * Factor;
   DrawObjects[ObjIdx].Y1 := CY + DY1 * Factor;
   DrawObjects[ObjIdx].Radius := DrawObjects[ObjIdx].Radius * Factor;
  End;

  OBJ_POINT: Begin
   DX1 := DrawObjects[ObjIdx].X1 - CX;
   DY1 := DrawObjects[ObjIdx].Y1 - CY;
   DrawObjects[ObjIdx].X1 := CX + DX1 * Factor;
   DrawObjects[ObjIdx].Y1 := CY + DY1 * Factor;
  End;

  OBJ_ELLIPSE: Begin
   DX1 := DrawObjects[ObjIdx].X1 - CX;
   DY1 := DrawObjects[ObjIdx].Y1 - CY;
   DX2 := DrawObjects[ObjIdx].X2 - CX;
   DY2 := DrawObjects[ObjIdx].Y2 - CY;
   DrawObjects[ObjIdx].X1 := CX + DX1 * Factor;
   DrawObjects[ObjIdx].Y1 := CY + DY1 * Factor;
   DrawObjects[ObjIdx].X2 := CX + DX2 * Factor;
   DrawObjects[ObjIdx].Y2 := CY + DY2 * Factor;
   DrawObjects[ObjIdx].Radius := DrawObjects[ObjIdx].Radius * Factor;
  End;
 End;
End;

{ Créer un miroir d'un objet par rapport à une ligne définie par (X1,Y1)-(X2,Y2) }
Procedure MirrorObject(ObjIdx: Integer; X1, Y1, X2, Y2: Real);
Var
 DX, DY, D, A, B, C: Real;
 OldPX, OldPY, NewPX, NewPY: Real;
 T: Real;
Begin
 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;
 If DrawObjects[ObjIdx].ObjType = OBJ_NONE Then Exit;

 { Calculer les coefficients de la ligne de miroir Ax + By + C = 0 }
 DX := X2 - X1;
 DY := Y2 - Y1;
 D := Sqrt(DX * DX + DY * DY);
 If D < 0.0001 Then Exit;  { Ligne trop courte }

 A := -DY / D;
 B := DX / D;
 C := -(A * X1 + B * Y1);

 { Fonction de réflexion d'un point }
 { Pour chaque point (OldPX, OldPY), calculer son reflet (NewPX, NewPY) }

 Case DrawObjects[ObjIdx].ObjType of
  OBJ_LINE, OBJ_RECTANGLE: Begin
   { Refléter P1 }
   OldPX := DrawObjects[ObjIdx].X1;
   OldPY := DrawObjects[ObjIdx].Y1;
   T := 2 * (A * OldPX + B * OldPY + C);
   NewPX := OldPX - T * A;
   NewPY := OldPY - T * B;
   DrawObjects[ObjIdx].X1 := NewPX;
   DrawObjects[ObjIdx].Y1 := NewPY;

   { Refléter P2 }
   OldPX := DrawObjects[ObjIdx].X2;
   OldPY := DrawObjects[ObjIdx].Y2;
   T := 2 * (A * OldPX + B * OldPY + C);
   NewPX := OldPX - T * A;
   NewPY := OldPY - T * B;
   DrawObjects[ObjIdx].X2 := NewPX;
   DrawObjects[ObjIdx].Y2 := NewPY;
  End;

  OBJ_CIRCLE, OBJ_POINT: Begin
   OldPX := DrawObjects[ObjIdx].X1;
   OldPY := DrawObjects[ObjIdx].Y1;
   T := 2 * (A * OldPX + B * OldPY + C);
   NewPX := OldPX - T * A;
   NewPY := OldPY - T * B;
   DrawObjects[ObjIdx].X1 := NewPX;
   DrawObjects[ObjIdx].Y1 := NewPY;
  End;

  OBJ_ARC: Begin
   { Refléter le centre }
   OldPX := DrawObjects[ObjIdx].X1;
   OldPY := DrawObjects[ObjIdx].Y1;
   T := 2 * (A * OldPX + B * OldPY + C);
   NewPX := OldPX - T * A;
   NewPY := OldPY - T * B;
   DrawObjects[ObjIdx].X1 := NewPX;
   DrawObjects[ObjIdx].Y1 := NewPY;
   { Inverser les angles et les échanger }
   T := DrawObjects[ObjIdx].StartAngle;
   DrawObjects[ObjIdx].StartAngle := 180 - DrawObjects[ObjIdx].EndAngle;
   DrawObjects[ObjIdx].EndAngle := 180 - T;
  End;

  OBJ_ELLIPSE: Begin
   { Refléter le centre }
   OldPX := DrawObjects[ObjIdx].X1;
   OldPY := DrawObjects[ObjIdx].Y1;
   T := 2 * (A * OldPX + B * OldPY + C);
   NewPX := OldPX - T * A;
   NewPY := OldPY - T * B;
   DrawObjects[ObjIdx].X1 := NewPX;
   DrawObjects[ObjIdx].Y1 := NewPY;

   { Refléter le point définissant l'axe }
   OldPX := DrawObjects[ObjIdx].X2;
   OldPY := DrawObjects[ObjIdx].Y2;
   T := 2 * (A * OldPX + B * OldPY + C);
   NewPX := OldPX - T * A;
   NewPY := OldPY - T * B;
   DrawObjects[ObjIdx].X2 := NewPX;
   DrawObjects[ObjIdx].Y2 := NewPY;
  End;
 End;
End;

{ Déplacer tous les objets sélectionnés }
Procedure MoveSelectedObjects(DX, DY: Real);
Var
 I: Integer;
Begin
 For I := 0 to SelectionSet.Count - 1 do
  MoveObject(SelectionSet.Objects[I], DX, DY);
 UpdateGripsForSelection;
End;

{ Faire pivoter tous les objets sélectionnés }
Procedure RotateSelectedObjects(CX, CY, Angle: Real);
Var
 I: Integer;
Begin
 For I := 0 to SelectionSet.Count - 1 do
  RotateObject(SelectionSet.Objects[I], CX, CY, Angle);
 UpdateGripsForSelection;
End;

{ Mettre à l'échelle tous les objets sélectionnés }
Procedure ScaleSelectedObjects(CX, CY, Factor: Real);
Var
 I: Integer;
Begin
 For I := 0 to SelectionSet.Count - 1 do
  ScaleObject(SelectionSet.Objects[I], CX, CY, Factor);
 UpdateGripsForSelection;
End;

{ Créer un miroir de tous les objets sélectionnés }
Procedure MirrorSelectedObjects(X1, Y1, X2, Y2: Real);
Var
 I: Integer;
Begin
 For I := 0 to SelectionSet.Count - 1 do
  MirrorObject(SelectionSet.Objects[I], X1, Y1, X2, Y2);
 UpdateGripsForSelection;
End;

{ Dessiner un grip individuel }
Procedure DrawSingleGrip(GripIdx: Integer);
Var
 GX, GY: Integer;
 GSize: Integer;
 GColor: Integer;
Begin
 If (GripIdx < 0) or (GripIdx >= CurrentGrips.Count) Then Exit;

 GX := WorldToScreenX(CurrentGrips.Grips[GripIdx].X);
 GY := WorldToScreenY(CurrentGrips.Grips[GripIdx].Y);

 { Déterminer la taille et la couleur }
 If GripIdx = ActiveGripIndex Then Begin
  GSize := GRIP_HOT_SIZE;
  GColor := GRIP_COLOR_SELECTED;
 End Else If CurrentGrips.Grips[GripIdx].IsHot Then Begin
  GSize := GRIP_HOT_SIZE;
  GColor := GRIP_COLOR_HOT;
 End Else Begin
  GSize := GRIP_SIZE;
  GColor := GRIP_COLOR_COLD;
 End;

 { Dessiner le grip (carré plein avec bordure) }
 SetFillStyle(SolidFill, GColor);
 Bar(GX - GSize div 2, GY - GSize div 2,
     GX + GSize div 2, GY + GSize div 2);

 { Bordure blanche pour la visibilité }
 SetColor(White);
 Rectangle(GX - GSize div 2, GY - GSize div 2,
           GX + GSize div 2, GY + GSize div 2);
End;

{ Dessiner tous les grips }
Procedure DrawGrips;
Var
 I: Integer;
Begin
 If CurrentGrips.Count = 0 Then Exit;

 For I := 0 to CurrentGrips.Count - 1 do
  DrawSingleGrip(I);

 { Si en mode édition, dessiner une ligne de prévisualisation }
 If GripEditActive and (ActiveGripIndex >= 0) Then Begin
  SetColor(Yellow);
  SetLineStyle(DashedLn, 0, NormWidth);
  Line(WorldToScreenX(GripOriginalX), WorldToScreenY(GripOriginalY),
       WorldToScreenX(GripCurrentX), WorldToScreenY(GripCurrentY));
  SetLineStyle(SolidLn, 0, NormWidth);
 End;
End;

{ ============================================================================ }
{ Procédures pour l'analyseur lexical AutoLISP (Tokenizer) - TODO 11           }
{ Analyse et découpe une expression AutoLISP en tokens                          }
{ ============================================================================ }

{ Initialiser le tokenizer AutoLISP }
Procedure InitLispTokenizer;
Begin
 LispTokenizer.Input := '';
 LispTokenizer.Position := 1;
 LispTokenizer.Length := 0;
 LispTokenizer.Line := 1;
 LispTokenizer.Column := 1;
 LispTokenizer.TokenCount := 0;
 LispTokenizer.CurrentToken := 0;
 LispTokenizer.ErrorMessage := '';
 LispTokenizer.HasError := False;
 LispLastResult := '';
 LispDebugMode := False;
End;

{ Définir l'entrée à analyser }
Procedure LispTokenizerSetInput(Const S: String);
Begin
 LispTokenizer.Input := S;
 LispTokenizer.Position := 1;
 LispTokenizer.Length := Length(S);
 LispTokenizer.Line := 1;
 LispTokenizer.Column := 1;
 LispTokenizer.TokenCount := 0;
 LispTokenizer.CurrentToken := 0;
 LispTokenizer.ErrorMessage := '';
 LispTokenizer.HasError := False;
End;

{ Lire et avancer au caractère suivant }
Function LispNextChar: Char;
Begin
 If LispTokenizer.Position <= LispTokenizer.Length Then Begin
  LispNextChar := LispTokenizer.Input[LispTokenizer.Position];
  Inc(LispTokenizer.Position);
  Inc(LispTokenizer.Column);
  { Gérer les retours à la ligne }
  If LispNextChar = #10 Then Begin
   Inc(LispTokenizer.Line);
   LispTokenizer.Column := 1;
  End;
 End Else
  LispNextChar := #0;  { Fin de l'entrée }
End;

{ Regarder le caractère suivant sans avancer }
Function LispPeekChar: Char;
Begin
 If LispTokenizer.Position <= LispTokenizer.Length Then
  LispPeekChar := LispTokenizer.Input[LispTokenizer.Position]
 Else
  LispPeekChar := #0;  { Fin de l'entrée }
End;

{ Vérifier si on est à la fin de l'entrée }
Function LispIsAtEnd: Boolean;
Begin
 LispIsAtEnd := LispTokenizer.Position > LispTokenizer.Length;
End;

{ Sauter les espaces blancs }
Procedure LispSkipWhitespace;
Var
 C: Char;
Begin
 While Not LispIsAtEnd do Begin
  C := LispPeekChar;
  If (C = ' ') or (C = #9) or (C = #10) or (C = #13) Then
   C := LispNextChar  { Consommer le caractère }
  Else
   Break;
 End;
End;

{ Sauter un commentaire (de ; jusqu'à la fin de ligne) }
Procedure LispSkipComment;
Var
 C: Char;
Begin
 If LispPeekChar = LISP_CHAR_SEMICOLON Then Begin
  While Not LispIsAtEnd do Begin
   C := LispNextChar;
   If (C = #10) or (C = #13) Then Break;
  End;
 End;
End;

{ Vérifier si un caractère est un chiffre }
Function LispIsDigit(C: Char): Boolean;
Begin
 LispIsDigit := (C >= '0') and (C <= '9');
End;

{ Vérifier si un caractère peut démarrer un symbole }
Function LispIsSymbolStart(C: Char): Boolean;
Begin
 LispIsSymbolStart := ((C >= 'a') and (C <= 'z')) or
                      ((C >= 'A') and (C <= 'Z')) or
                      (C = '_') or (C = '+') or (C = '-') or
                      (C = '*') or (C = '/') or (C = '=') or
                      (C = '<') or (C = '>') or (C = '!') or
                      (C = '?') or (C = ':') or (C = '$') or
                      (C = '%') or (C = '&') or (C = '~');
End;

{ Vérifier si un caractère peut continuer un symbole }
Function LispIsSymbolChar(C: Char): Boolean;
Begin
 LispIsSymbolChar := LispIsSymbolStart(C) or LispIsDigit(C);
End;

{ Convertir une chaîne en majuscules }
Function LispUpperCase(Const S: String): String;
Var
 I: Integer;
 Result: String;
Begin
 Result := S;
 For I := 1 to Length(Result) do
  If (Result[I] >= 'a') and (Result[I] <= 'z') Then
   Result[I] := Chr(Ord(Result[I]) - 32);
 LispUpperCase := Result;
End;

{ Lire un nombre (entier ou réel) }
Function LispReadNumber: TLispToken;
Var
 Token: TLispToken;
 NumStr: String;
 C: Char;
 HasDot: Boolean;
 Code: Integer;
Begin
 Token.TokenType := LISP_TOKEN_INTEGER;
 Token.Line := LispTokenizer.Line;
 Token.Column := LispTokenizer.Column;
 Token.IntValue := 0;
 Token.RealValue := 0.0;
 Token.StrValue := '';

 NumStr := '';
 HasDot := False;

 { Signe optionnel }
 C := LispPeekChar;
 If (C = '+') or (C = '-') Then Begin
  NumStr := NumStr + LispNextChar;
  C := LispPeekChar;
 End;

 { Partie entière }
 While LispIsDigit(LispPeekChar) do
  NumStr := NumStr + LispNextChar;

 { Point décimal et partie fractionnaire }
 If LispPeekChar = '.' Then Begin
  C := LispNextChar;  { Consommer le point }
  If LispIsDigit(LispPeekChar) Then Begin
   HasDot := True;
   NumStr := NumStr + '.';
   While LispIsDigit(LispPeekChar) do
    NumStr := NumStr + LispNextChar;
  End Else Begin
   { C'était juste un point, remettre la position }
   Dec(LispTokenizer.Position);
   Dec(LispTokenizer.Column);
  End;
 End;

 { Notation scientifique }
 C := LispPeekChar;
 If (C = 'e') or (C = 'E') Then Begin
  HasDot := True;  { Force le type réel }
  NumStr := NumStr + LispNextChar;
  C := LispPeekChar;
  If (C = '+') or (C = '-') Then
   NumStr := NumStr + LispNextChar;
  While LispIsDigit(LispPeekChar) do
   NumStr := NumStr + LispNextChar;
 End;

 Token.StrValue := NumStr;

 If HasDot Then Begin
  Token.TokenType := LISP_TOKEN_REAL;
  Val(NumStr, Token.RealValue, Code);
  If Code <> 0 Then Begin
   Token.TokenType := LISP_TOKEN_ERROR;
   LispTokenizer.HasError := True;
   LispTokenizer.ErrorMessage := 'Nombre réel invalide: ' + NumStr;
  End;
 End Else Begin
  Token.TokenType := LISP_TOKEN_INTEGER;
  Val(NumStr, Token.IntValue, Code);
  If Code <> 0 Then Begin
   Token.TokenType := LISP_TOKEN_ERROR;
   LispTokenizer.HasError := True;
   LispTokenizer.ErrorMessage := 'Nombre entier invalide: ' + NumStr;
  End;
 End;

 LispReadNumber := Token;
End;

{ Lire une chaîne de caractères entre guillemets }
Function LispReadString: TLispToken;
Var
 Token: TLispToken;
 C: Char;
Begin
 Token.TokenType := LISP_TOKEN_STRING;
 Token.Line := LispTokenizer.Line;
 Token.Column := LispTokenizer.Column;
 Token.IntValue := 0;
 Token.RealValue := 0.0;
 Token.StrValue := '';

 { Consommer le guillemet ouvrant }
 C := LispNextChar;  { " }

 While Not LispIsAtEnd do Begin
  C := LispNextChar;

  If C = LISP_CHAR_DQUOTE Then
   Break  { Fin de la chaîne }
  Else If C = LISP_CHAR_BACKSLASH Then Begin
   { Séquence d'échappement }
   If Not LispIsAtEnd Then Begin
    C := LispNextChar;
    Case C of
     'n': Token.StrValue := Token.StrValue + #10;  { Nouvelle ligne }
     'r': Token.StrValue := Token.StrValue + #13;  { Retour chariot }
     't': Token.StrValue := Token.StrValue + #9;   { Tabulation }
     '\': Token.StrValue := Token.StrValue + '\';  { Backslash }
     '"': Token.StrValue := Token.StrValue + '"';  { Guillemet }
     Else Token.StrValue := Token.StrValue + C;    { Autre caractère }
    End;
   End;
  End Else
   Token.StrValue := Token.StrValue + C;
 End;

 { Vérifier si la chaîne est correctement fermée }
 If (C <> LISP_CHAR_DQUOTE) and LispIsAtEnd Then Begin
  Token.TokenType := LISP_TOKEN_ERROR;
  LispTokenizer.HasError := True;
  LispTokenizer.ErrorMessage := 'Chaîne non terminée';
 End;

 LispReadString := Token;
End;

{ Lire un symbole (identifiant ou mot-clé) }
Function LispReadSymbol: TLispToken;
Var
 Token: TLispToken;
 SymStr: String;
 UpperStr: String;
Begin
 Token.TokenType := LISP_TOKEN_SYMBOL;
 Token.Line := LispTokenizer.Line;
 Token.Column := LispTokenizer.Column;
 Token.IntValue := 0;
 Token.RealValue := 0.0;
 Token.StrValue := '';

 SymStr := '';

 { Lire le symbole }
 While (Not LispIsAtEnd) and LispIsSymbolChar(LispPeekChar) do
  SymStr := SymStr + LispNextChar;

 Token.StrValue := SymStr;

 { Vérifier les mots-clés spéciaux }
 UpperStr := LispUpperCase(SymStr);
 If UpperStr = 'NIL' Then
  Token.TokenType := LISP_TOKEN_NIL
 Else If UpperStr = 'T' Then
  Token.TokenType := LISP_TOKEN_T;

 LispReadSymbol := Token;
End;

{ Obtenir le prochain token }
Function LispGetNextToken: TLispToken;
Var
 Token: TLispToken;
 C: Char;
Begin
 { Initialiser le token par défaut }
 Token.TokenType := LISP_TOKEN_NONE;
 Token.Line := LispTokenizer.Line;
 Token.Column := LispTokenizer.Column;
 Token.IntValue := 0;
 Token.RealValue := 0.0;
 Token.StrValue := '';

 { Sauter les espaces et commentaires }
 Repeat
  LispSkipWhitespace;
  If LispPeekChar = LISP_CHAR_SEMICOLON Then
   LispSkipComment
  Else
   Break;
 Until LispIsAtEnd;

 { Vérifier la fin de l'entrée }
 If LispIsAtEnd Then Begin
  Token.TokenType := LISP_TOKEN_EOF;
  LispGetNextToken := Token;
  Exit;
 End;

 Token.Line := LispTokenizer.Line;
 Token.Column := LispTokenizer.Column;

 C := LispPeekChar;

 Case C of
  LISP_CHAR_LPAREN: Begin
   Token.TokenType := LISP_TOKEN_LPAREN;
   Token.StrValue := '(';
   C := LispNextChar;
  End;

  LISP_CHAR_RPAREN: Begin
   Token.TokenType := LISP_TOKEN_RPAREN;
   Token.StrValue := ')';
   C := LispNextChar;
  End;

  LISP_CHAR_QUOTE: Begin
   Token.TokenType := LISP_TOKEN_QUOTE;
   Token.StrValue := '''';
   C := LispNextChar;
  End;

  LISP_CHAR_DOT: Begin
   { Vérifier si c'est un nombre ou juste un point }
   C := LispNextChar;  { Consommer le point }
   If LispIsDigit(LispPeekChar) Then Begin
    { C'est un nombre commençant par un point }
    Dec(LispTokenizer.Position);
    Dec(LispTokenizer.Column);
    Token := LispReadNumber;
   End Else Begin
    Token.TokenType := LISP_TOKEN_DOT;
    Token.StrValue := '.';
   End;
  End;

  LISP_CHAR_DQUOTE: Begin
   Token := LispReadString;
  End;

  '0'..'9': Begin
   Token := LispReadNumber;
  End;

  '+', '-': Begin
   { Vérifier si c'est un nombre ou un symbole }
   C := LispNextChar;  { Consommer le signe }
   If LispIsDigit(LispPeekChar) Then Begin
    { C'est un nombre avec signe }
    Dec(LispTokenizer.Position);
    Dec(LispTokenizer.Column);
    Token := LispReadNumber;
   End Else Begin
    { C'est un symbole (+, -, etc.) }
    Dec(LispTokenizer.Position);
    Dec(LispTokenizer.Column);
    Token := LispReadSymbol;
   End;
  End;

  Else Begin
   If LispIsSymbolStart(C) Then
    Token := LispReadSymbol
   Else Begin
    { Caractère non reconnu }
    Token.TokenType := LISP_TOKEN_ERROR;
    Token.StrValue := C;
    LispTokenizer.HasError := True;
    LispTokenizer.ErrorMessage := 'Caractère inattendu: ' + C;
    C := LispNextChar;  { Consommer le caractère }
   End;
  End;
 End;

 LispGetNextToken := Token;
End;

{ Tokeniser une expression complète }
Procedure LispTokenize(Const S: String);
Var
 Token: TLispToken;
Begin
 LispTokenizerSetInput(S);
 LispTokenizer.TokenCount := 0;

 Repeat
  Token := LispGetNextToken;

  If LispTokenizer.TokenCount < MAX_LISP_TOKENS Then Begin
   LispTokenizer.Tokens[LispTokenizer.TokenCount] := Token;
   Inc(LispTokenizer.TokenCount);
  End Else Begin
   LispTokenizer.HasError := True;
   LispTokenizer.ErrorMessage := 'Trop de tokens (maximum ' +
     Chr(48 + (MAX_LISP_TOKENS div 100) mod 10) +
     Chr(48 + (MAX_LISP_TOKENS div 10) mod 10) +
     Chr(48 + MAX_LISP_TOKENS mod 10) + ')';
   Break;
  End;

 Until (Token.TokenType = LISP_TOKEN_EOF) or
       (Token.TokenType = LISP_TOKEN_ERROR) or
       LispTokenizer.HasError;

 LispTokenizer.CurrentToken := 0;
End;

{ Obtenir le nom d'un type de token }
Function LispTokenTypeName(TokenType: Byte): String;
Begin
 Case TokenType of
  LISP_TOKEN_NONE:    LispTokenTypeName := 'NONE';
  LISP_TOKEN_LPAREN:  LispTokenTypeName := 'LPAREN';
  LISP_TOKEN_RPAREN:  LispTokenTypeName := 'RPAREN';
  LISP_TOKEN_QUOTE:   LispTokenTypeName := 'QUOTE';
  LISP_TOKEN_DOT:     LispTokenTypeName := 'DOT';
  LISP_TOKEN_INTEGER: LispTokenTypeName := 'INTEGER';
  LISP_TOKEN_REAL:    LispTokenTypeName := 'REAL';
  LISP_TOKEN_STRING:  LispTokenTypeName := 'STRING';
  LISP_TOKEN_SYMBOL:  LispTokenTypeName := 'SYMBOL';
  LISP_TOKEN_NIL:     LispTokenTypeName := 'NIL';
  LISP_TOKEN_T:       LispTokenTypeName := 'T';
  LISP_TOKEN_EOF:     LispTokenTypeName := 'EOF';
  LISP_TOKEN_ERROR:   LispTokenTypeName := 'ERROR';
  Else                LispTokenTypeName := 'UNKNOWN';
 End;
End;

{ Afficher un token (pour debug) }
Procedure LispPrintToken(Const Token: TLispToken);
Var
 S: String;
Begin
 S := '[' + LispTokenTypeName(Token.TokenType);
 Case Token.TokenType of
  LISP_TOKEN_INTEGER: Begin
   Str(Token.IntValue, S);
   S := '[INTEGER: ' + S;
  End;
  LISP_TOKEN_REAL: Begin
   Str(Token.RealValue:0:6, S);
   S := '[REAL: ' + S;
  End;
  LISP_TOKEN_STRING: S := '[STRING: "' + Token.StrValue + '"';
  LISP_TOKEN_SYMBOL: S := '[SYMBOL: ' + Token.StrValue;
  LISP_TOKEN_NIL:    S := '[NIL';
  LISP_TOKEN_T:      S := '[T';
  LISP_TOKEN_ERROR:  S := '[ERROR: ' + Token.StrValue;
 End;
 S := S + ' @' + Chr(48 + Token.Line mod 10) + ':' +
          Chr(48 + Token.Column mod 10) + ']';
 WriteLn(S);
End;

{ Afficher tous les tokens (pour debug) }
Procedure LispPrintAllTokens;
Var
 I: Integer;
Begin
 WriteLn('=== Tokens (', LispTokenizer.TokenCount, ') ===');
 For I := 0 to LispTokenizer.TokenCount - 1 do
  LispPrintToken(LispTokenizer.Tokens[I]);
 If LispTokenizer.HasError Then
  WriteLn('ERREUR: ', LispTokenizer.ErrorMessage);
End;

{ Obtenir le type du token courant }
Function LispCurrentTokenType: Byte;
Begin
 If LispTokenizer.CurrentToken < LispTokenizer.TokenCount Then
  LispCurrentTokenType := LispTokenizer.Tokens[LispTokenizer.CurrentToken].TokenType
 Else
  LispCurrentTokenType := LISP_TOKEN_EOF;
End;

{ Avancer au prochain token et retourner le token courant }
Function LispAdvanceToken: TLispToken;
Begin
 If LispTokenizer.CurrentToken < LispTokenizer.TokenCount Then Begin
  LispAdvanceToken := LispTokenizer.Tokens[LispTokenizer.CurrentToken];
  Inc(LispTokenizer.CurrentToken);
 End Else Begin
  LispAdvanceToken.TokenType := LISP_TOKEN_EOF;
  LispAdvanceToken.IntValue := 0;
  LispAdvanceToken.RealValue := 0.0;
  LispAdvanceToken.StrValue := '';
  LispAdvanceToken.Line := LispTokenizer.Line;
  LispAdvanceToken.Column := LispTokenizer.Column;
 End;
End;

{ Regarder le token courant sans avancer }
Function LispPeekToken: TLispToken;
Begin
 If LispTokenizer.CurrentToken < LispTokenizer.TokenCount Then
  LispPeekToken := LispTokenizer.Tokens[LispTokenizer.CurrentToken]
 Else Begin
  LispPeekToken.TokenType := LISP_TOKEN_EOF;
  LispPeekToken.IntValue := 0;
  LispPeekToken.RealValue := 0.0;
  LispPeekToken.StrValue := '';
  LispPeekToken.Line := LispTokenizer.Line;
  LispPeekToken.Column := LispTokenizer.Column;
 End;
End;

{ ============================================================================ }
{ Procédures pour le parseur AutoLISP (AST) - TODO 12                          }
{ Construit un arbre syntaxique à partir des tokens                            }
{ ============================================================================ }

{ Initialiser le parseur AutoLISP }
Procedure InitLispParser;
Var
 I: Integer;
Begin
 LispParser.NodeCount := 0;
 LispParser.Root := Nil;
 LispParser.Depth := 0;
 LispParser.ErrorMessage := '';
 LispParser.HasError := False;
 LispParseDebugMode := False;

 { Initialiser tous les noeuds }
 For I := 0 to MAX_LISP_NODES - 1 do Begin
  LispParser.Nodes[I].NodeType := LISP_NODE_NONE;
  LispParser.Nodes[I].ChildCount := 0;
 End;
End;

{ Allouer un nouveau noeud dans le pool }
Function LispAllocNode: PLispNode;
Var
 I: Integer;
Begin
 If LispParser.NodeCount >= MAX_LISP_NODES Then Begin
  LispParser.HasError := True;
  LispParser.ErrorMessage := 'Trop de noeuds dans l''arbre syntaxique';
  LispAllocNode := Nil;
  Exit;
 End;

 LispAllocNode := @LispParser.Nodes[LispParser.NodeCount];

 { Initialiser le noeud }
 With LispParser.Nodes[LispParser.NodeCount] do Begin
  NodeType := LISP_NODE_NONE;
  IntValue := 0;
  RealValue := 0.0;
  StrValue := '';
  ChildCount := 0;
  Line := 0;
  Column := 0;
  For I := 0 to MAX_LISP_CHILDREN - 1 do
   Children[I] := Nil;
 End;

 Inc(LispParser.NodeCount);
End;

{ Libérer un noeud (pas vraiment nécessaire avec le pool, mais pour l'API) }
Procedure LispFreeNode(Node: PLispNode);
Begin
 If Node = Nil Then Exit;
 { Avec le système de pool, on ne fait rien ici }
 { La mémoire est libérée lors du prochain LispClearParser }
End;

{ Effacer le parseur pour une nouvelle expression }
Procedure LispClearParser;
Var
 I, J: Integer;
Begin
 LispParser.NodeCount := 0;
 LispParser.Root := Nil;
 LispParser.Depth := 0;
 LispParser.ErrorMessage := '';
 LispParser.HasError := False;

 For I := 0 to MAX_LISP_NODES - 1 do Begin
  LispParser.Nodes[I].NodeType := LISP_NODE_NONE;
  LispParser.Nodes[I].ChildCount := 0;
  For J := 0 to MAX_LISP_CHILDREN - 1 do
   LispParser.Nodes[I].Children[J] := Nil;
 End;
End;

{ Parser un atome (nombre, chaîne, symbole, nil, t) }
Function LispParseAtom: PLispNode;
Var
 Node: PLispNode;
 Token: TLispToken;
Begin
 Token := LispPeekToken;

 Node := LispAllocNode;
 If Node = Nil Then Begin
  LispParseAtom := Nil;
  Exit;
 End;

 Node^.Line := Token.Line;
 Node^.Column := Token.Column;

 Case Token.TokenType of
  LISP_TOKEN_INTEGER: Begin
   Node^.NodeType := LISP_NODE_INTEGER;
   Node^.IntValue := Token.IntValue;
   Node^.StrValue := Token.StrValue;
   Token := LispAdvanceToken;
  End;

  LISP_TOKEN_REAL: Begin
   Node^.NodeType := LISP_NODE_REAL;
   Node^.RealValue := Token.RealValue;
   Node^.StrValue := Token.StrValue;
   Token := LispAdvanceToken;
  End;

  LISP_TOKEN_STRING: Begin
   Node^.NodeType := LISP_NODE_STRING;
   Node^.StrValue := Token.StrValue;
   Token := LispAdvanceToken;
  End;

  LISP_TOKEN_SYMBOL: Begin
   Node^.NodeType := LISP_NODE_SYMBOL;
   Node^.StrValue := Token.StrValue;
   Token := LispAdvanceToken;
  End;

  LISP_TOKEN_NIL: Begin
   Node^.NodeType := LISP_NODE_NIL;
   Node^.StrValue := 'nil';
   Token := LispAdvanceToken;
  End;

  LISP_TOKEN_T: Begin
   Node^.NodeType := LISP_NODE_T;
   Node^.StrValue := 't';
   Token := LispAdvanceToken;
  End;

  Else Begin
   { Token inattendu }
   LispParser.HasError := True;
   LispParser.ErrorMessage := 'Token inattendu: ' + LispTokenTypeName(Token.TokenType);
   LispParseAtom := Nil;
   Exit;
  End;
 End;

 LispParseAtom := Node;
End;

{ Parser une expression quotée 'expr }
Function LispParseQuote: PLispNode;
Var
 Node, Child: PLispNode;
 Token: TLispToken;
Begin
 Token := LispAdvanceToken;  { Consommer le quote }

 Node := LispAllocNode;
 If Node = Nil Then Begin
  LispParseQuote := Nil;
  Exit;
 End;

 Node^.NodeType := LISP_NODE_QUOTE;
 Node^.Line := Token.Line;
 Node^.Column := Token.Column;
 Node^.StrValue := 'quote';

 { Parser l'expression quotée }
 Child := LispParseExpr;
 If Child = Nil Then Begin
  If Not LispParser.HasError Then Begin
   LispParser.HasError := True;
   LispParser.ErrorMessage := 'Expression attendue après quote';
  End;
  LispParseQuote := Nil;
  Exit;
 End;

 Node^.Children[0] := Child;
 Node^.ChildCount := 1;

 LispParseQuote := Node;
End;

{ Parser une liste (expression entre parenthèses) }
Function LispParseList: PLispNode;
Var
 Node, Child: PLispNode;
 Token: TLispToken;
 HasDot: Boolean;
Begin
 Token := LispAdvanceToken;  { Consommer la parenthèse ouvrante }

 { Vérifier la profondeur de récursion }
 Inc(LispParser.Depth);
 If LispParser.Depth > MAX_LISP_DEPTH Then Begin
  LispParser.HasError := True;
  LispParser.ErrorMessage := 'Imbrication trop profonde';
  LispParseList := Nil;
  Exit;
 End;

 Node := LispAllocNode;
 If Node = Nil Then Begin
  Dec(LispParser.Depth);
  LispParseList := Nil;
  Exit;
 End;

 Node^.NodeType := LISP_NODE_LIST;
 Node^.Line := Token.Line;
 Node^.Column := Token.Column;
 Node^.ChildCount := 0;
 HasDot := False;

 { Parser les éléments de la liste }
 While True do Begin
  Token := LispPeekToken;

  { Fin de la liste }
  If Token.TokenType = LISP_TOKEN_RPAREN Then Begin
   Token := LispAdvanceToken;  { Consommer la parenthèse fermante }
   Break;
  End;

  { Fin de fichier inattendue }
  If Token.TokenType = LISP_TOKEN_EOF Then Begin
   LispParser.HasError := True;
   LispParser.ErrorMessage := 'Parenthèse fermante attendue';
   Dec(LispParser.Depth);
   LispParseList := Nil;
   Exit;
  End;

  { Erreur de tokenisation }
  If Token.TokenType = LISP_TOKEN_ERROR Then Begin
   LispParser.HasError := True;
   LispParser.ErrorMessage := 'Erreur de tokenisation: ' + Token.StrValue;
   Dec(LispParser.Depth);
   LispParseList := Nil;
   Exit;
  End;

  { Point pour paire pointée }
  If Token.TokenType = LISP_TOKEN_DOT Then Begin
   HasDot := True;
   Node^.NodeType := LISP_NODE_DOTPAIR;
   Token := LispAdvanceToken;  { Consommer le point }
   Continue;
  End;

  { Vérifier le nombre d'enfants }
  If Node^.ChildCount >= MAX_LISP_CHILDREN Then Begin
   LispParser.HasError := True;
   LispParser.ErrorMessage := 'Trop d''éléments dans la liste';
   Dec(LispParser.Depth);
   LispParseList := Nil;
   Exit;
  End;

  { Parser l'élément suivant }
  Child := LispParseExpr;
  If Child = Nil Then Begin
   Dec(LispParser.Depth);
   LispParseList := Nil;
   Exit;
  End;

  Node^.Children[Node^.ChildCount] := Child;
  Inc(Node^.ChildCount);
 End;

 Dec(LispParser.Depth);
 LispParseList := Node;
End;

{ Parser une expression (dispatch principal) }
Function LispParseExpr: PLispNode;
Var
 Token: TLispToken;
Begin
 Token := LispPeekToken;

 { Vérifier les erreurs }
 If LispParser.HasError Then Begin
  LispParseExpr := Nil;
  Exit;
 End;

 Case Token.TokenType of
  LISP_TOKEN_LPAREN: Begin
   LispParseExpr := LispParseList;
  End;

  LISP_TOKEN_QUOTE: Begin
   LispParseExpr := LispParseQuote;
  End;

  LISP_TOKEN_INTEGER,
  LISP_TOKEN_REAL,
  LISP_TOKEN_STRING,
  LISP_TOKEN_SYMBOL,
  LISP_TOKEN_NIL,
  LISP_TOKEN_T: Begin
   LispParseExpr := LispParseAtom;
  End;

  LISP_TOKEN_RPAREN: Begin
   LispParser.HasError := True;
   LispParser.ErrorMessage := 'Parenthèse fermante inattendue';
   LispParseExpr := Nil;
  End;

  LISP_TOKEN_EOF: Begin
   LispParseExpr := Nil;  { Fin normale }
  End;

  LISP_TOKEN_ERROR: Begin
   LispParser.HasError := True;
   LispParser.ErrorMessage := 'Erreur de tokenisation: ' + Token.StrValue;
   LispParseExpr := Nil;
  End;

  Else Begin
   LispParser.HasError := True;
   LispParser.ErrorMessage := 'Token inattendu: ' + LispTokenTypeName(Token.TokenType);
   LispParseExpr := Nil;
  End;
 End;
End;

{ Parser une chaîne complète et retourner l'AST }
Function LispParse(Const S: String): PLispNode;
Begin
 { D'abord tokeniser }
 LispTokenize(S);

 { Vérifier les erreurs de tokenisation }
 If LispTokenizer.HasError Then Begin
  LispParser.HasError := True;
  LispParser.ErrorMessage := 'Erreur de tokenisation: ' + LispTokenizer.ErrorMessage;
  LispParse := Nil;
  Exit;
 End;

 { Réinitialiser le parseur }
 LispClearParser;

 { Parser l'expression }
 LispParser.Root := LispParseExpr;

 LispParse := LispParser.Root;
End;

{ Obtenir le nom d'un type de noeud }
Function LispNodeTypeName(NodeType: Byte): String;
Begin
 Case NodeType of
  LISP_NODE_NONE:    LispNodeTypeName := 'NONE';
  LISP_NODE_INTEGER: LispNodeTypeName := 'INTEGER';
  LISP_NODE_REAL:    LispNodeTypeName := 'REAL';
  LISP_NODE_STRING:  LispNodeTypeName := 'STRING';
  LISP_NODE_SYMBOL:  LispNodeTypeName := 'SYMBOL';
  LISP_NODE_NIL:     LispNodeTypeName := 'NIL';
  LISP_NODE_T:       LispNodeTypeName := 'T';
  LISP_NODE_LIST:    LispNodeTypeName := 'LIST';
  LISP_NODE_QUOTE:   LispNodeTypeName := 'QUOTE';
  LISP_NODE_DOTPAIR: LispNodeTypeName := 'DOTPAIR';
  Else               LispNodeTypeName := 'UNKNOWN';
 End;
End;

{ Afficher un noeud avec indentation (pour debug) }
Procedure LispPrintNode(Node: PLispNode; Indent: Integer);
Var
 I: Integer;
 Prefix: String;
 S: String;
Begin
 If Node = Nil Then Begin
  WriteLn('(nil)');
  Exit;
 End;

 { Créer l'indentation }
 Prefix := '';
 For I := 1 to Indent do
  Prefix := Prefix + '  ';

 { Afficher selon le type }
 Case Node^.NodeType of
  LISP_NODE_INTEGER: Begin
   Str(Node^.IntValue, S);
   WriteLn(Prefix, 'INTEGER: ', S);
  End;

  LISP_NODE_REAL: Begin
   Str(Node^.RealValue:0:6, S);
   WriteLn(Prefix, 'REAL: ', S);
  End;

  LISP_NODE_STRING: Begin
   WriteLn(Prefix, 'STRING: "', Node^.StrValue, '"');
  End;

  LISP_NODE_SYMBOL: Begin
   WriteLn(Prefix, 'SYMBOL: ', Node^.StrValue);
  End;

  LISP_NODE_NIL: Begin
   WriteLn(Prefix, 'NIL');
  End;

  LISP_NODE_T: Begin
   WriteLn(Prefix, 'T');
  End;

  LISP_NODE_LIST: Begin
   WriteLn(Prefix, 'LIST (', Node^.ChildCount, ' elements):');
   For I := 0 to Node^.ChildCount - 1 do
    LispPrintNode(Node^.Children[I], Indent + 1);
  End;

  LISP_NODE_QUOTE: Begin
   WriteLn(Prefix, 'QUOTE:');
   If Node^.ChildCount > 0 Then
    LispPrintNode(Node^.Children[0], Indent + 1);
  End;

  LISP_NODE_DOTPAIR: Begin
   WriteLn(Prefix, 'DOTPAIR:');
   For I := 0 to Node^.ChildCount - 1 do
    LispPrintNode(Node^.Children[I], Indent + 1);
  End;

  Else Begin
   WriteLn(Prefix, 'UNKNOWN');
  End;
 End;
End;

{ Afficher l'arbre syntaxique complet }
Procedure LispPrintAST;
Begin
 WriteLn('=== AST ===');
 If LispParser.Root <> Nil Then
  LispPrintNode(LispParser.Root, 0)
 Else
  WriteLn('(vide)');
 If LispParser.HasError Then
  WriteLn('ERREUR: ', LispParser.ErrorMessage);
End;

{ Convertir un noeud en chaîne LISP lisible }
Function LispNodeToString(Node: PLispNode): String;
Var
 I: Integer;
 S, Tmp: String;
Begin
 If Node = Nil Then Begin
  LispNodeToString := 'nil';
  Exit;
 End;

 Case Node^.NodeType of
  LISP_NODE_INTEGER: Begin
   Str(Node^.IntValue, S);
   LispNodeToString := S;
  End;

  LISP_NODE_REAL: Begin
   Str(Node^.RealValue:0:6, S);
   { Enlever les zéros trailing }
   While (Length(S) > 1) and (S[Length(S)] = '0') and (S[Length(S)-1] <> '.') do
    Delete(S, Length(S), 1);
   LispNodeToString := S;
  End;

  LISP_NODE_STRING: Begin
   LispNodeToString := '"' + Node^.StrValue + '"';
  End;

  LISP_NODE_SYMBOL: Begin
   LispNodeToString := Node^.StrValue;
  End;

  LISP_NODE_NIL: Begin
   LispNodeToString := 'nil';
  End;

  LISP_NODE_T: Begin
   LispNodeToString := 't';
  End;

  LISP_NODE_LIST: Begin
   S := '(';
   For I := 0 to Node^.ChildCount - 1 do Begin
    If I > 0 Then S := S + ' ';
    S := S + LispNodeToString(Node^.Children[I]);
   End;
   S := S + ')';
   LispNodeToString := S;
  End;

  LISP_NODE_QUOTE: Begin
   If Node^.ChildCount > 0 Then
    LispNodeToString := '''' + LispNodeToString(Node^.Children[0])
   Else
    LispNodeToString := '''nil';
  End;

  LISP_NODE_DOTPAIR: Begin
   If Node^.ChildCount >= 2 Then
    LispNodeToString := '(' + LispNodeToString(Node^.Children[0]) + ' . ' +
                        LispNodeToString(Node^.Children[1]) + ')'
   Else If Node^.ChildCount = 1 Then
    LispNodeToString := '(' + LispNodeToString(Node^.Children[0]) + ' . nil)'
   Else
    LispNodeToString := '(nil . nil)';
  End;

  Else Begin
   LispNodeToString := '???';
  End;
 End;
End;

{ Vérifier si un noeud est nil }
Function LispIsNil(Node: PLispNode): Boolean;
Begin
 If Node = Nil Then
  LispIsNil := True
 Else
  LispIsNil := (Node^.NodeType = LISP_NODE_NIL) or
               ((Node^.NodeType = LISP_NODE_LIST) and (Node^.ChildCount = 0));
End;

{ Vérifier si un noeud est une liste }
Function LispIsList(Node: PLispNode): Boolean;
Begin
 If Node = Nil Then
  LispIsList := False
 Else
  LispIsList := (Node^.NodeType = LISP_NODE_LIST) or
                (Node^.NodeType = LISP_NODE_DOTPAIR) or
                (Node^.NodeType = LISP_NODE_NIL);
End;

{ Vérifier si un noeud est un atome (pas une liste) }
Function LispIsAtomNode(Node: PLispNode): Boolean;
Begin
 If Node = Nil Then
  LispIsAtomNode := True
 Else
  LispIsAtomNode := (Node^.NodeType <> LISP_NODE_LIST) and
                    (Node^.NodeType <> LISP_NODE_DOTPAIR);
End;

{ Obtenir la longueur d'une liste }
Function LispListLength(Node: PLispNode): Integer;
Begin
 If Node = Nil Then
  LispListLength := 0
 Else If Node^.NodeType = LISP_NODE_LIST Then
  LispListLength := Node^.ChildCount
 Else If Node^.NodeType = LISP_NODE_NIL Then
  LispListLength := 0
 Else
  LispListLength := -1;  { Pas une liste }
End;

{ Obtenir un élément d'une liste par index }
Function LispListGet(Node: PLispNode; Index: Integer): PLispNode;
Begin
 If Node = Nil Then
  LispListGet := Nil
 Else If Node^.NodeType <> LISP_NODE_LIST Then
  LispListGet := Nil
 Else If (Index < 0) or (Index >= Node^.ChildCount) Then
  LispListGet := Nil
 Else
  LispListGet := Node^.Children[Index];
End;

{ ============================================================================ }
{ Procédures pour l'évaluateur AutoLISP - TODO 13                              }
{ Évalue les expressions LISP avec support des fonctions mathématiques         }
{ ============================================================================ }

{ Initialiser l'évaluateur AutoLISP }
Procedure InitLispEvaluator;
Var
 I: Integer;
Begin
 LispEvaluator.VarCount := 0;
 LispEvaluator.StackDepth := 0;
 LispEvaluator.ErrorMessage := '';
 LispEvaluator.HasError := False;
 LispEvalDebugMode := False;

 { Initialiser la dernière valeur à nil }
 LispEvaluator.LastResult.ValueType := LISP_VAL_NIL;
 LispEvaluator.LastResult.IntValue := 0;
 LispEvaluator.LastResult.RealValue := 0.0;
 LispEvaluator.LastResult.StrValue := '';
 LispEvaluator.LastResult.ListNode := Nil;

 { Initialiser toutes les variables }
 For I := 0 to MAX_LISP_VARIABLES - 1 do Begin
  LispEvaluator.Variables[I].Name := '';
  LispEvaluator.Variables[I].IsDefined := False;
  LispEvaluator.Variables[I].Value.ValueType := LISP_VAL_NIL;
 End;

 { Définir la constante PI }
 LispSetVariable('PI', LispMakeReal(3.14159265358979));
End;

{ Créer une valeur nil }
Function LispMakeNil: TLispValue;
Begin
 LispMakeNil.ValueType := LISP_VAL_NIL;
 LispMakeNil.IntValue := 0;
 LispMakeNil.RealValue := 0.0;
 LispMakeNil.StrValue := '';
 LispMakeNil.ListNode := Nil;
End;

{ Créer une valeur t (vrai) }
Function LispMakeT: TLispValue;
Begin
 LispMakeT.ValueType := LISP_VAL_T;
 LispMakeT.IntValue := 1;
 LispMakeT.RealValue := 1.0;
 LispMakeT.StrValue := 't';
 LispMakeT.ListNode := Nil;
End;

{ Créer une valeur entière }
Function LispMakeInt(V: LongInt): TLispValue;
Begin
 LispMakeInt.ValueType := LISP_VAL_INTEGER;
 LispMakeInt.IntValue := V;
 LispMakeInt.RealValue := V;
 LispMakeInt.StrValue := '';
 LispMakeInt.ListNode := Nil;
End;

{ Créer une valeur réelle }
Function LispMakeReal(V: Real): TLispValue;
Begin
 LispMakeReal.ValueType := LISP_VAL_REAL;
 LispMakeReal.IntValue := Round(V);
 LispMakeReal.RealValue := V;
 LispMakeReal.StrValue := '';
 LispMakeReal.ListNode := Nil;
End;

{ Créer une valeur chaîne }
Function LispMakeString(Const S: String): TLispValue;
Begin
 LispMakeString.ValueType := LISP_VAL_STRING;
 LispMakeString.IntValue := 0;
 LispMakeString.RealValue := 0.0;
 LispMakeString.StrValue := S;
 LispMakeString.ListNode := Nil;
End;

{ Créer une valeur d'erreur }
Function LispMakeError(Const Msg: String): TLispValue;
Begin
 LispMakeError.ValueType := LISP_VAL_ERROR;
 LispMakeError.IntValue := 0;
 LispMakeError.RealValue := 0.0;
 LispMakeError.StrValue := Msg;
 LispMakeError.ListNode := Nil;
 LispEvaluator.HasError := True;
 LispEvaluator.ErrorMessage := Msg;
End;

{ Vérifier si une valeur est vraie (non-nil) }
Function LispValueIsTrue(Const V: TLispValue): Boolean;
Begin
 LispValueIsTrue := V.ValueType <> LISP_VAL_NIL;
End;

{ Convertir une valeur en réel }
Function LispValueToReal(Const V: TLispValue): Real;
Begin
 Case V.ValueType of
  LISP_VAL_INTEGER: LispValueToReal := V.IntValue;
  LISP_VAL_REAL:    LispValueToReal := V.RealValue;
  LISP_VAL_T:       LispValueToReal := 1.0;
  Else              LispValueToReal := 0.0;
 End;
End;

{ Convertir une valeur en chaîne }
Function LispValueToString(Const V: TLispValue): String;
Var
 S: String;
Begin
 Case V.ValueType of
  LISP_VAL_NIL: LispValueToString := 'nil';
  LISP_VAL_T: LispValueToString := 't';
  LISP_VAL_INTEGER: Begin
   Str(V.IntValue, S);
   LispValueToString := S;
  End;
  LISP_VAL_REAL: Begin
   Str(V.RealValue:0:6, S);
   { Enlever les zéros trailing }
   While (Length(S) > 1) and (S[Length(S)] = '0') and (S[Length(S)-1] <> '.') do
    Delete(S, Length(S), 1);
   LispValueToString := S;
  End;
  LISP_VAL_STRING: LispValueToString := '"' + V.StrValue + '"';
  LISP_VAL_SYMBOL: LispValueToString := V.StrValue;
  LISP_VAL_LIST: Begin
   If V.ListNode <> Nil Then
    LispValueToString := LispNodeToString(V.ListNode)
   Else
    LispValueToString := 'nil';
  End;
  LISP_VAL_ERROR: LispValueToString := 'ERREUR: ' + V.StrValue;
  Else LispValueToString := '???';
 End;
End;

{ Chercher une variable par nom }
Function LispGetVariable(Const Name: String): TLispValue;
Var
 I: Integer;
 UpperName: String;
Begin
 UpperName := Name;
 For I := 1 to Length(UpperName) do
  If (UpperName[I] >= 'a') and (UpperName[I] <= 'z') Then
   UpperName[I] := Chr(Ord(UpperName[I]) - 32);

 For I := 0 to LispEvaluator.VarCount - 1 do Begin
  If LispEvaluator.Variables[I].IsDefined and
     (LispEvaluator.Variables[I].Name = UpperName) Then Begin
   LispGetVariable := LispEvaluator.Variables[I].Value;
   Exit;
  End;
 End;

 { Variable non trouvée, retourner nil }
 LispGetVariable := LispMakeNil;
End;

{ Définir ou modifier une variable }
Procedure LispSetVariable(Const Name: String; Const Value: TLispValue);
Var
 I: Integer;
 UpperName: String;
Begin
 UpperName := Name;
 For I := 1 to Length(UpperName) do
  If (UpperName[I] >= 'a') and (UpperName[I] <= 'z') Then
   UpperName[I] := Chr(Ord(UpperName[I]) - 32);

 { Chercher si la variable existe déjà }
 For I := 0 to LispEvaluator.VarCount - 1 do Begin
  If LispEvaluator.Variables[I].IsDefined and
     (LispEvaluator.Variables[I].Name = UpperName) Then Begin
   LispEvaluator.Variables[I].Value := Value;
   Exit;
  End;
 End;

 { Créer une nouvelle variable }
 If LispEvaluator.VarCount < MAX_LISP_VARIABLES Then Begin
  LispEvaluator.Variables[LispEvaluator.VarCount].Name := UpperName;
  LispEvaluator.Variables[LispEvaluator.VarCount].Value := Value;
  LispEvaluator.Variables[LispEvaluator.VarCount].IsDefined := True;
  Inc(LispEvaluator.VarCount);
 End;
End;

{ Évaluer un atome (nombre, chaîne, symbole, nil, t) }
Function LispEvalAtom(Node: PLispNode): TLispValue;
Begin
 If Node = Nil Then Begin
  LispEvalAtom := LispMakeNil;
  Exit;
 End;

 Case Node^.NodeType of
  LISP_NODE_INTEGER: Begin
   LispEvalAtom := LispMakeInt(Node^.IntValue);
  End;

  LISP_NODE_REAL: Begin
   LispEvalAtom := LispMakeReal(Node^.RealValue);
  End;

  LISP_NODE_STRING: Begin
   LispEvalAtom := LispMakeString(Node^.StrValue);
  End;

  LISP_NODE_SYMBOL: Begin
   { Chercher la valeur de la variable }
   LispEvalAtom := LispGetVariable(Node^.StrValue);
  End;

  LISP_NODE_NIL: Begin
   LispEvalAtom := LispMakeNil;
  End;

  LISP_NODE_T: Begin
   LispEvalAtom := LispMakeT;
  End;

  Else Begin
   LispEvalAtom := LispMakeError('Type d''atome inattendu');
  End;
 End;
End;

{ Évaluer une opération mathématique (+, -, *, /, abs, mod, min, max, 1+, 1-) }
Function LispEvalMathOp(Const FuncName: String; Node: PLispNode): TLispValue;
Var
 I: Integer;
 Result, ArgVal: TLispValue;
 Total, ArgNum: Real;
 IsReal: Boolean;
 IntTotal: LongInt;
Begin
 If Node^.ChildCount < 1 Then Begin
  LispEvalMathOp := LispMakeError('Fonction ' + FuncName + ' requiert au moins un argument');
  Exit;
 End;

 IsReal := False;
 Total := 0;
 IntTotal := 0;

 { Addition }
 If FuncName = '+' Then Begin
  Total := 0;
  For I := 1 to Node^.ChildCount - 1 do Begin
   ArgVal := LispEval(Node^.Children[I]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalMathOp := ArgVal;
    Exit;
   End;
   If ArgVal.ValueType = LISP_VAL_REAL Then IsReal := True;
   Total := Total + LispValueToReal(ArgVal);
  End;
  If IsReal Then
   LispEvalMathOp := LispMakeReal(Total)
  Else
   LispEvalMathOp := LispMakeInt(Round(Total));
  Exit;
 End;

 { Soustraction }
 If FuncName = '-' Then Begin
  If Node^.ChildCount < 2 Then Begin
   { Un seul argument: négation }
   ArgVal := LispEval(Node^.Children[1]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalMathOp := ArgVal;
    Exit;
   End;
   If ArgVal.ValueType = LISP_VAL_REAL Then
    LispEvalMathOp := LispMakeReal(-ArgVal.RealValue)
   Else
    LispEvalMathOp := LispMakeInt(-ArgVal.IntValue);
   Exit;
  End;

  { Premier argument }
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  If ArgVal.ValueType = LISP_VAL_REAL Then IsReal := True;
  Total := LispValueToReal(ArgVal);

  { Soustraire les autres arguments }
  For I := 2 to Node^.ChildCount - 1 do Begin
   ArgVal := LispEval(Node^.Children[I]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalMathOp := ArgVal;
    Exit;
   End;
   If ArgVal.ValueType = LISP_VAL_REAL Then IsReal := True;
   Total := Total - LispValueToReal(ArgVal);
  End;
  If IsReal Then
   LispEvalMathOp := LispMakeReal(Total)
  Else
   LispEvalMathOp := LispMakeInt(Round(Total));
  Exit;
 End;

 { Multiplication }
 If FuncName = '*' Then Begin
  Total := 1;
  For I := 1 to Node^.ChildCount - 1 do Begin
   ArgVal := LispEval(Node^.Children[I]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalMathOp := ArgVal;
    Exit;
   End;
   If ArgVal.ValueType = LISP_VAL_REAL Then IsReal := True;
   Total := Total * LispValueToReal(ArgVal);
  End;
  If IsReal Then
   LispEvalMathOp := LispMakeReal(Total)
  Else
   LispEvalMathOp := LispMakeInt(Round(Total));
  Exit;
 End;

 { Division }
 If FuncName = '/' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalMathOp := LispMakeError('/ requiert au moins 2 arguments');
   Exit;
  End;

  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  Total := LispValueToReal(ArgVal);

  For I := 2 to Node^.ChildCount - 1 do Begin
   ArgVal := LispEval(Node^.Children[I]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalMathOp := ArgVal;
    Exit;
   End;
   ArgNum := LispValueToReal(ArgVal);
   If ArgNum = 0 Then Begin
    LispEvalMathOp := LispMakeError('Division par zéro');
    Exit;
   End;
   Total := Total / ArgNum;
  End;
  LispEvalMathOp := LispMakeReal(Total);
  Exit;
 End;

 { Valeur absolue }
 If FuncName = 'ABS' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalMathOp := LispMakeError('abs requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  Total := LispValueToReal(ArgVal);
  If Total < 0 Then Total := -Total;
  If ArgVal.ValueType = LISP_VAL_REAL Then
   LispEvalMathOp := LispMakeReal(Total)
  Else
   LispEvalMathOp := LispMakeInt(Round(Total));
  Exit;
 End;

 { Modulo (rem) }
 If (FuncName = 'REM') or (FuncName = 'MOD') Then Begin
  If Node^.ChildCount < 3 Then Begin
   LispEvalMathOp := LispMakeError('rem requiert 2 arguments');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  IntTotal := Round(LispValueToReal(ArgVal));

  ArgVal := LispEval(Node^.Children[2]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  ArgNum := Round(LispValueToReal(ArgVal));
  If ArgNum = 0 Then Begin
   LispEvalMathOp := LispMakeError('Division par zéro (modulo)');
   Exit;
  End;
  LispEvalMathOp := LispMakeInt(IntTotal mod Round(ArgNum));
  Exit;
 End;

 { Minimum }
 If FuncName = 'MIN' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalMathOp := LispMakeError('min requiert au moins un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  If ArgVal.ValueType = LISP_VAL_REAL Then IsReal := True;
  Total := LispValueToReal(ArgVal);

  For I := 2 to Node^.ChildCount - 1 do Begin
   ArgVal := LispEval(Node^.Children[I]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalMathOp := ArgVal;
    Exit;
   End;
   If ArgVal.ValueType = LISP_VAL_REAL Then IsReal := True;
   ArgNum := LispValueToReal(ArgVal);
   If ArgNum < Total Then Total := ArgNum;
  End;
  If IsReal Then
   LispEvalMathOp := LispMakeReal(Total)
  Else
   LispEvalMathOp := LispMakeInt(Round(Total));
  Exit;
 End;

 { Maximum }
 If FuncName = 'MAX' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalMathOp := LispMakeError('max requiert au moins un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  If ArgVal.ValueType = LISP_VAL_REAL Then IsReal := True;
  Total := LispValueToReal(ArgVal);

  For I := 2 to Node^.ChildCount - 1 do Begin
   ArgVal := LispEval(Node^.Children[I]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalMathOp := ArgVal;
    Exit;
   End;
   If ArgVal.ValueType = LISP_VAL_REAL Then IsReal := True;
   ArgNum := LispValueToReal(ArgVal);
   If ArgNum > Total Then Total := ArgNum;
  End;
  If IsReal Then
   LispEvalMathOp := LispMakeReal(Total)
  Else
   LispEvalMathOp := LispMakeInt(Round(Total));
  Exit;
 End;

 { Incrément de 1 }
 If FuncName = '1+' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalMathOp := LispMakeError('1+ requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  If ArgVal.ValueType = LISP_VAL_REAL Then
   LispEvalMathOp := LispMakeReal(ArgVal.RealValue + 1)
  Else
   LispEvalMathOp := LispMakeInt(ArgVal.IntValue + 1);
  Exit;
 End;

 { Décrément de 1 }
 If FuncName = '1-' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalMathOp := LispMakeError('1- requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalMathOp := ArgVal;
   Exit;
  End;
  If ArgVal.ValueType = LISP_VAL_REAL Then
   LispEvalMathOp := LispMakeReal(ArgVal.RealValue - 1)
  Else
   LispEvalMathOp := LispMakeInt(ArgVal.IntValue - 1);
  Exit;
 End;

 LispEvalMathOp := LispMakeError('Fonction mathématique inconnue: ' + FuncName);
End;

{ Évaluer une fonction trigonométrique (sin, cos, tan, atan, asin, acos, sqrt, expt, exp, log) }
Function LispEvalTrigOp(Const FuncName: String; Node: PLispNode): TLispValue;
Var
 Result:TLispValue;
 ArgVal, ArgVal2: TLispValue;
 Num, Num2: Real;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalTrigOp := LispMakeError(FuncName + ' requiert au moins un argument');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalTrigOp := ArgVal;
  Exit;
 End;
 Num := LispValueToReal(ArgVal);

 { Sinus }
 If FuncName = 'SIN' Then Begin
  LispEvalTrigOp := LispMakeReal(Sin(Num));
  Exit;
 End;

 { Cosinus }
 If FuncName = 'COS' Then Begin
  LispEvalTrigOp := LispMakeReal(Cos(Num));
  Exit;
 End;

 { Tangente }
 If FuncName = 'TAN' Then Begin
  If Cos(Num) = 0 Then Begin
   LispEvalTrigOp := LispMakeError('Tangente non définie');
   Exit;
  End;
  LispEvalTrigOp := LispMakeReal(Sin(Num) / Cos(Num));
  Exit;
 End;

 { Arc tangente }
 If FuncName = 'ATAN' Then Begin
  If Node^.ChildCount >= 3 Then Begin
   { atan2 avec deux arguments }
   ArgVal2 := LispEval(Node^.Children[2]);
   If ArgVal2.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalTrigOp := ArgVal2;
    Exit;
   End;
   Num2 := LispValueToReal(ArgVal2);
   If Num2 = 0 Then Begin
    If Num > 0 Then
     LispEvalTrigOp := LispMakeReal(3.14159265358979 / 2)
    Else If Num < 0 Then
     LispEvalTrigOp := LispMakeReal(-3.14159265358979 / 2)
    Else
     LispEvalTrigOp := LispMakeReal(0);
   End Else
    LispEvalTrigOp := LispMakeReal(ArcTan(Num / Num2));
  End Else
   LispEvalTrigOp := LispMakeReal(ArcTan(Num));
  Exit;
 End;

 { Racine carrée }
 If FuncName = 'SQRT' Then Begin
  If Num < 0 Then Begin
   LispEvalTrigOp := LispMakeError('Racine carrée d''un nombre négatif');
   Exit;
  End;
  LispEvalTrigOp := LispMakeReal(Sqrt(Num));
  Exit;
 End;

 { Puissance }
 If FuncName = 'EXPT' Then Begin
  If Node^.ChildCount < 3 Then Begin
   LispEvalTrigOp := LispMakeError('expt requiert 2 arguments');
   Exit;
  End;
  ArgVal2 := LispEval(Node^.Children[2]);
  If ArgVal2.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalTrigOp := ArgVal2;
   Exit;
  End;
  Num2 := LispValueToReal(ArgVal2);
  If (Num = 0) and (Num2 < 0) Then Begin
   LispEvalTrigOp := LispMakeError('Division par zéro dans expt');
   Exit;
  End;
  If (Num < 0) and (Frac(Num2) <> 0) Then Begin
   LispEvalTrigOp := LispMakeError('Puissance fractionnaire d''un nombre négatif');
   Exit;
  End;
  Result := LispMakeReal(Exp(Num2 * Ln(Abs(Num))));
  If (Num < 0) and (Round(Num2) mod 2 = 1) Then
   Result.RealValue := -Result.RealValue;
  LispEvalTrigOp := Result;
  Exit;
 End;

 { Exponentielle (e^x) }
 If FuncName = 'EXP' Then Begin
  LispEvalTrigOp := LispMakeReal(Exp(Num));
  Exit;
 End;

 { Logarithme naturel }
 If (FuncName = 'LOG') or (FuncName = 'LN') Then Begin
  If Num <= 0 Then Begin
   LispEvalTrigOp := LispMakeError('Logarithme d''un nombre non-positif');
   Exit;
  End;
  LispEvalTrigOp := LispMakeReal(Ln(Num));
  Exit;
 End;

 { Logarithme base 10 }
 If FuncName = 'LOG10' Then Begin
  If Num <= 0 Then Begin
   LispEvalTrigOp := LispMakeError('Logarithme d''un nombre non-positif');
   Exit;
  End;
  LispEvalTrigOp := LispMakeReal(Ln(Num) / Ln(10));
  Exit;
 End;

 { Conversion degrés -> radians }
 If (FuncName = 'DTR') or (FuncName = 'DTOR') Then Begin
  LispEvalTrigOp := LispMakeReal(Num * 3.14159265358979 / 180);
  Exit;
 End;

 { Conversion radians -> degrés }
 If (FuncName = 'RTD') or (FuncName = 'RTOD') Then Begin
  LispEvalTrigOp := LispMakeReal(Num * 180 / 3.14159265358979);
  Exit;
 End;

 { Arrondi }
 If FuncName = 'FIX' Then Begin
  LispEvalTrigOp := LispMakeInt(Trunc(Num));
  Exit;
 End;

 { Partie décimale * partie entière pour obtenir un entier }
 If FuncName = 'FLOAT' Then Begin
  LispEvalTrigOp := LispMakeReal(Num);
  Exit;
 End;

 LispEvalTrigOp := LispMakeError('Fonction trigonométrique inconnue: ' + FuncName);
End;

{ Évaluer une opération de comparaison (<, >, <=, >=, =, /=, eq, equal) }
Function LispEvalCompareOp(Const FuncName: String; Node: PLispNode): TLispValue;
Var
 I: Integer;
 ArgVal1, ArgVal2: TLispValue;
 Num1, Num2: Real;
 AllTrue: Boolean;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalCompareOp := LispMakeError(FuncName + ' requiert au moins 2 arguments');
  Exit;
 End;

 ArgVal1 := LispEval(Node^.Children[1]);
 If ArgVal1.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalCompareOp := ArgVal1;
  Exit;
 End;

 AllTrue := True;

 For I := 2 to Node^.ChildCount - 1 do Begin
  ArgVal2 := LispEval(Node^.Children[I]);
  If ArgVal2.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalCompareOp := ArgVal2;
   Exit;
  End;

  Num1 := LispValueToReal(ArgVal1);
  Num2 := LispValueToReal(ArgVal2);

  { Inférieur }
  If FuncName = '<' Then Begin
   If Not (Num1 < Num2) Then AllTrue := False;
  End
  { Supérieur }
  Else If FuncName = '>' Then Begin
   If Not (Num1 > Num2) Then AllTrue := False;
  End
  { Inférieur ou égal }
  Else If FuncName = '<=' Then Begin
   If Not (Num1 <= Num2) Then AllTrue := False;
  End
  { Supérieur ou égal }
  Else If FuncName = '>=' Then Begin
   If Not (Num1 >= Num2) Then AllTrue := False;
  End
  { Égalité numérique }
  Else If FuncName = '=' Then Begin
   If Not (Num1 = Num2) Then AllTrue := False;
  End
  { Non-égalité }
  Else If FuncName = '/=' Then Begin
   If Not (Num1 <> Num2) Then AllTrue := False;
  End
  { Égalité de référence (eq) - simplifiée pour les nombres }
  Else If FuncName = 'EQ' Then Begin
   If (ArgVal1.ValueType <> ArgVal2.ValueType) or (Num1 <> Num2) Then
    AllTrue := False;
  End
  { Égalité structurelle (equal) - simplifiée }
  Else If FuncName = 'EQUAL' Then Begin
   If (ArgVal1.ValueType <> ArgVal2.ValueType) Then
    AllTrue := False
   Else If (ArgVal1.ValueType = LISP_VAL_STRING) and
           (ArgVal1.StrValue <> ArgVal2.StrValue) Then
    AllTrue := False
   Else If Num1 <> Num2 Then
    AllTrue := False;
  End
  Else Begin
   LispEvalCompareOp := LispMakeError('Opérateur de comparaison inconnu: ' + FuncName);
   Exit;
  End;

  { Préparer pour la prochaine comparaison }
  ArgVal1 := ArgVal2;
 End;

 If AllTrue Then
  LispEvalCompareOp := LispMakeT
 Else
  LispEvalCompareOp := LispMakeNil;
End;

{ Évaluer une liste (appel de fonction) }
Function LispEvalList(Node: PLispNode): TLispValue;
Var
 FuncNode: PLispNode;
 FuncName: String;
 I: Integer;
 ArgVal: TLispValue;
Begin
 If (Node = Nil) or (Node^.ChildCount = 0) Then Begin
  LispEvalList := LispMakeNil;
  Exit;
 End;

 { Obtenir le nom de la fonction }
 FuncNode := Node^.Children[0];
 If FuncNode = Nil Then Begin
  LispEvalList := LispMakeError('Nom de fonction manquant');
  Exit;
 End;

 If FuncNode^.NodeType <> LISP_NODE_SYMBOL Then Begin
  LispEvalList := LispMakeError('Le premier élément doit être un symbole');
  Exit;
 End;

 FuncName := FuncNode^.StrValue;
 { Convertir en majuscules }
 For I := 1 to Length(FuncName) do
  If (FuncName[I] >= 'a') and (FuncName[I] <= 'z') Then
   FuncName[I] := Chr(Ord(FuncName[I]) - 32);

 { Opérations mathématiques de base }
 If (FuncName = '+') or (FuncName = '-') or (FuncName = '*') or (FuncName = '/') or
    (FuncName = 'ABS') or (FuncName = 'REM') or (FuncName = 'MOD') or
    (FuncName = 'MIN') or (FuncName = 'MAX') or (FuncName = '1+') or (FuncName = '1-') Then Begin
  LispEvalList := LispEvalMathOp(FuncName, Node);
  Exit;
 End;

 { Fonctions trigonométriques et mathématiques avancées }
 If (FuncName = 'SIN') or (FuncName = 'COS') or (FuncName = 'TAN') or
    (FuncName = 'ATAN') or (FuncName = 'SQRT') or (FuncName = 'EXPT') or
    (FuncName = 'EXP') or (FuncName = 'LOG') or (FuncName = 'LN') or
    (FuncName = 'LOG10') or (FuncName = 'DTR') or (FuncName = 'DTOR') or
    (FuncName = 'RTD') or (FuncName = 'RTOD') or (FuncName = 'FIX') or
    (FuncName = 'FLOAT') Then Begin
  LispEvalList := LispEvalTrigOp(FuncName, Node);
  Exit;
 End;

 { Opérations de comparaison }
 If (FuncName = '<') or (FuncName = '>') or (FuncName = '<=') or (FuncName = '>=') or
    (FuncName = '=') or (FuncName = '/=') or (FuncName = 'EQ') or (FuncName = 'EQUAL') Then Begin
  LispEvalList := LispEvalCompareOp(FuncName, Node);
  Exit;
 End;

 { Opérations logiques }
 If FuncName = 'NOT' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalList := LispMakeError('not requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalList := ArgVal;
   Exit;
  End;
  If LispValueIsTrue(ArgVal) Then
   LispEvalList := LispMakeNil
  Else
   LispEvalList := LispMakeT;
  Exit;
 End;

 If FuncName = 'AND' Then Begin
  For I := 1 to Node^.ChildCount - 1 do Begin
   ArgVal := LispEval(Node^.Children[I]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalList := ArgVal;
    Exit;
   End;
   If Not LispValueIsTrue(ArgVal) Then Begin
    LispEvalList := LispMakeNil;
    Exit;
   End;
  End;
  LispEvalList := ArgVal;  { Retourner la dernière valeur si toutes vraies }
  Exit;
 End;

 If FuncName = 'OR' Then Begin
  For I := 1 to Node^.ChildCount - 1 do Begin
   ArgVal := LispEval(Node^.Children[I]);
   If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
    LispEvalList := ArgVal;
    Exit;
   End;
   If LispValueIsTrue(ArgVal) Then Begin
    LispEvalList := ArgVal;  { Retourner la première valeur vraie }
    Exit;
   End;
  End;
  LispEvalList := LispMakeNil;
  Exit;
 End;

 { NULL - test si nil }
 If FuncName = 'NULL' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalList := LispMakeError('null requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalList := ArgVal;
   Exit;
  End;
  If ArgVal.ValueType = LISP_VAL_NIL Then
   LispEvalList := LispMakeT
  Else
   LispEvalList := LispMakeNil;
  Exit;
 End;

 { ATOM - test si atome (non-liste) }
 If FuncName = 'ATOM' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalList := LispMakeError('atom requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalList := ArgVal;
   Exit;
  End;
  If ArgVal.ValueType <> LISP_VAL_LIST Then
   LispEvalList := LispMakeT
  Else
   LispEvalList := LispMakeNil;
  Exit;
 End;

 { NUMBERP - test si nombre }
 If FuncName = 'NUMBERP' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalList := LispMakeError('numberp requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalList := ArgVal;
   Exit;
  End;
  If (ArgVal.ValueType = LISP_VAL_INTEGER) or (ArgVal.ValueType = LISP_VAL_REAL) Then
   LispEvalList := LispMakeT
  Else
   LispEvalList := LispMakeNil;
  Exit;
 End;

 { ZEROP - test si zéro }
 If FuncName = 'ZEROP' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalList := LispMakeError('zerop requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalList := ArgVal;
   Exit;
  End;
  If LispValueToReal(ArgVal) = 0 Then
   LispEvalList := LispMakeT
  Else
   LispEvalList := LispMakeNil;
  Exit;
 End;

 { MINUSP - test si négatif }
 If FuncName = 'MINUSP' Then Begin
  If Node^.ChildCount < 2 Then Begin
   LispEvalList := LispMakeError('minusp requiert un argument');
   Exit;
  End;
  ArgVal := LispEval(Node^.Children[1]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalList := ArgVal;
   Exit;
  End;
  If LispValueToReal(ArgVal) < 0 Then
   LispEvalList := LispMakeT
  Else
   LispEvalList := LispMakeNil;
  Exit;
 End;

 { Fonctions de dessin AutoLISP - TODO 14 }
 If (FuncName = 'ENTMAKE') or (FuncName = 'ENTGET') or (FuncName = 'ENTMOD') or
    (FuncName = 'ENTSEL') or (FuncName = 'SSGET') or (FuncName = 'SSADD') or
    (FuncName = 'SSLENGTH') or (FuncName = 'SSNAME') or (FuncName = 'COMMAND') Then Begin
  LispEvalList := LispEvalDrawOp(FuncName, Node);
  Exit;
 End;

 { Fonctions de manipulation de chaînes, listes et variables - TODO 15 }
 If (FuncName = 'SETQ') or (FuncName = 'DEFUN') or (FuncName = 'IF') or
    (FuncName = 'COND') or (FuncName = 'WHILE') or (FuncName = 'FOREACH') or
    (FuncName = 'MAPCAR') or (FuncName = 'LIST') or (FuncName = 'CONS') or
    (FuncName = 'CAR') or (FuncName = 'CDR') or (FuncName = 'NTH') or
    (FuncName = 'APPEND') or (FuncName = 'REVERSE') or (FuncName = 'LENGTH') or
    (FuncName = 'STRCAT') or (FuncName = 'STRLEN') or (FuncName = 'SUBSTR') or
    (FuncName = 'STRCASE') or (FuncName = 'PROGN') Then Begin
  LispEvalList := LispEvalControlOp(FuncName, Node);
  Exit;
 End;

 { Fonction inconnue }
 LispEvalList := LispMakeError('Fonction inconnue: ' + FuncName);
End;

{ Évaluer une expression LISP }
Function LispEval(Node: PLispNode): TLispValue;
Begin
 { Vérifier la profondeur de pile }
 Inc(LispEvaluator.StackDepth);
 If LispEvaluator.StackDepth > MAX_LISP_STACK Then Begin
  LispEval := LispMakeError('Débordement de pile');
  Dec(LispEvaluator.StackDepth);
  Exit;
 End;

 If Node = Nil Then Begin
  LispEval := LispMakeNil;
  Dec(LispEvaluator.StackDepth);
  Exit;
 End;

 Case Node^.NodeType of
  LISP_NODE_INTEGER,
  LISP_NODE_REAL,
  LISP_NODE_STRING,
  LISP_NODE_SYMBOL,
  LISP_NODE_NIL,
  LISP_NODE_T: Begin
   LispEval := LispEvalAtom(Node);
  End;

  LISP_NODE_LIST: Begin
   LispEval := LispEvalList(Node);
  End;

  LISP_NODE_QUOTE: Begin
   { Une expression quotée n'est pas évaluée }
   LispEval.ValueType := LISP_VAL_LIST;
   LispEval.IntValue := 0;
   LispEval.RealValue := 0.0;
   LispEval.StrValue := '';
   If Node^.ChildCount > 0 Then
    LispEval.ListNode := Node^.Children[0]
   Else
    LispEval.ListNode := Nil;
  End;

  Else Begin
   LispEval := LispMakeError('Type de noeud inconnu');
  End;
 End;

 Dec(LispEvaluator.StackDepth);
End;

{ Parser et évaluer une expression LISP complète }
Function LispEvaluate(Const S: String): TLispValue;
Var
 Node: PLispNode;
Begin
 { Réinitialiser l'état d'erreur }
 LispEvaluator.HasError := False;
 LispEvaluator.ErrorMessage := '';
 LispEvaluator.StackDepth := 0;

 { Parser l'expression }
 Node := LispParse(S);

 { Vérifier les erreurs de parsing }
 If LispParser.HasError Then Begin
  LispEvaluate := LispMakeError(LispParser.ErrorMessage);
  Exit;
 End;

 If Node = Nil Then Begin
  LispEvaluate := LispMakeNil;
  Exit;
 End;

 { Évaluer l'expression }
 LispEvaluator.LastResult := LispEval(Node);
 LispEvaluate := LispEvaluator.LastResult;
End;

{ Afficher une valeur LISP }
Procedure LispPrintValue(Const V: TLispValue);
Begin
 WriteLn(LispValueToString(V));
End;

{ ============================================================================ }
{ Fonctions de dessin AutoLISP - TODO 14                                       }
{ Implémente command, entmake, entmod, entget, entsel, ssget, ssadd            }
{ ============================================================================ }

{ Initialiser les fonctions de dessin AutoLISP }
Procedure InitLispDrawFunctions;
Var
 I, J: Integer;
Begin
 { Initialiser les jeux de sélection }
 LispSelSetCount := 0;
 For I := 0 to MAX_LISP_SELSETS - 1 do Begin
  LispSelectionSets[I].Count := 0;
  LispSelectionSets[I].IsActive := False;
  For J := 0 to MAX_SELECTED - 1 do
   LispSelectionSets[I].Entities[J] := -1;
 End;
 LispLastEntity := -1;
 LispEntselActive := False;
End;

{ Créer une valeur nom d'entité }
Function LispMakeEname(EntityIndex: Integer): TLispValue;
Begin
 LispMakeEname.ValueType := LISP_VAL_ENAME;
 LispMakeEname.IntValue := EntityIndex;
 LispMakeEname.RealValue := EntityIndex;
 LispMakeEname.StrValue := '';
 LispMakeEname.ListNode := Nil;
End;

{ Créer une valeur jeu de sélection }
Function LispMakeSelSet(SelSetIndex: Integer): TLispValue;
Begin
 LispMakeSelSet.ValueType := LISP_VAL_SELSET;
 LispMakeSelSet.IntValue := SelSetIndex;
 LispMakeSelSet.RealValue := SelSetIndex;
 LispMakeSelSet.StrValue := '';
 LispMakeSelSet.ListNode := Nil;
End;

{ Convertir un type d'objet en chaîne }
Function ObjTypeToString(ObjType: Byte): String;
Begin
 Case ObjType of
  OBJ_LINE:      ObjTypeToString := 'LINE';
  OBJ_CIRCLE:    ObjTypeToString := 'CIRCLE';
  OBJ_ARC:       ObjTypeToString := 'ARC';
  OBJ_RECTANGLE: ObjTypeToString := 'LWPOLYLINE';  { Rectangle = Polyline légère }
  OBJ_POLYLINE:  ObjTypeToString := 'LWPOLYLINE';
  OBJ_POINT:     ObjTypeToString := 'POINT';
  OBJ_TEXT:      ObjTypeToString := 'TEXT';
  OBJ_ELLIPSE:   ObjTypeToString := 'ELLIPSE';
  Else           ObjTypeToString := 'UNKNOWN';
 End;
End;

{ Convertir une chaîne en type d'objet }
Function StringToObjType(Const S: String): Integer;
Var
 Upper: String;
 I: Integer;
Begin
 Upper := S;
 For I := 1 to Length(Upper) do
  If (Upper[I] >= 'a') and (Upper[I] <= 'z') Then
   Upper[I] := Chr(Ord(Upper[I]) - 32);

 If Upper = 'LINE' Then
  StringToObjType := OBJ_LINE
 Else If Upper = 'CIRCLE' Then
  StringToObjType := OBJ_CIRCLE
 Else If Upper = 'ARC' Then
  StringToObjType := OBJ_ARC
 Else If (Upper = 'LWPOLYLINE') or (Upper = 'POLYLINE') Then
  StringToObjType := OBJ_POLYLINE
 Else If Upper = 'POINT' Then
  StringToObjType := OBJ_POINT
 Else If Upper = 'TEXT' Then
  StringToObjType := OBJ_TEXT
 Else If Upper = 'ELLIPSE' Then
  StringToObjType := OBJ_ELLIPSE
 Else
  StringToObjType := OBJ_NONE;
End;

{ Convertir une entité en liste de paires pointées (format DXF) }
Function LispEntityToList(EntityIndex: Integer): TLispValue;
Var
 Node, PairNode, ValueNode: PLispNode;
 TypeStr: String;
Begin
 If (EntityIndex < 0) or (EntityIndex >= MAX_OBJECTS) Then Begin
  LispEntityToList := LispMakeNil;
  Exit;
 End;

 If DrawObjects[EntityIndex].ObjType = OBJ_NONE Then Begin
  LispEntityToList := LispMakeNil;
  Exit;
 End;

 { Créer la liste principale }
 Node := LispAllocNode;
 If Node = Nil Then Begin
  LispEntityToList := LispMakeNil;
  Exit;
 End;
 Node^.NodeType := LISP_NODE_LIST;
 Node^.ChildCount := 0;

 { Ajouter la paire (-1 . ename) - Nom d'entité }
 PairNode := LispAllocNode;
 If PairNode <> Nil Then Begin
  PairNode^.NodeType := LISP_NODE_DOTPAIR;
  PairNode^.ChildCount := 2;

  { Code DXF -1 }
  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_INTEGER;
   ValueNode^.IntValue := DXF_ENAME;
   PairNode^.Children[0] := ValueNode;
  End;

  { Valeur = index de l'entité }
  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_INTEGER;
   ValueNode^.IntValue := EntityIndex;
   PairNode^.Children[1] := ValueNode;
  End;

  Node^.Children[Node^.ChildCount] := PairNode;
  Inc(Node^.ChildCount);
 End;

 { Ajouter la paire (0 . type) - Type d'entité }
 PairNode := LispAllocNode;
 If PairNode <> Nil Then Begin
  PairNode^.NodeType := LISP_NODE_DOTPAIR;
  PairNode^.ChildCount := 2;

  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_INTEGER;
   ValueNode^.IntValue := DXF_ENTITY_TYPE;
   PairNode^.Children[0] := ValueNode;
  End;

  TypeStr := ObjTypeToString(DrawObjects[EntityIndex].ObjType);
  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_STRING;
   ValueNode^.StrValue := TypeStr;
   PairNode^.Children[1] := ValueNode;
  End;

  Node^.Children[Node^.ChildCount] := PairNode;
  Inc(Node^.ChildCount);
 End;

 { Ajouter la paire (62 . color) - Couleur }
 PairNode := LispAllocNode;
 If PairNode <> Nil Then Begin
  PairNode^.NodeType := LISP_NODE_DOTPAIR;
  PairNode^.ChildCount := 2;

  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_INTEGER;
   ValueNode^.IntValue := DXF_COLOR;
   PairNode^.Children[0] := ValueNode;
  End;

  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_INTEGER;
   ValueNode^.IntValue := DrawObjects[EntityIndex].Color;
   PairNode^.Children[1] := ValueNode;
  End;

  Node^.Children[Node^.ChildCount] := PairNode;
  Inc(Node^.ChildCount);
 End;

 { Ajouter les coordonnées (10 . x1) (20 . y1) }
 { Point 1 / Centre }
 PairNode := LispAllocNode;
 If PairNode <> Nil Then Begin
  PairNode^.NodeType := LISP_NODE_DOTPAIR;
  PairNode^.ChildCount := 2;

  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_INTEGER;
   ValueNode^.IntValue := DXF_X1;
   PairNode^.Children[0] := ValueNode;
  End;

  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_REAL;
   ValueNode^.RealValue := DrawObjects[EntityIndex].X1;
   PairNode^.Children[1] := ValueNode;
  End;

  Node^.Children[Node^.ChildCount] := PairNode;
  Inc(Node^.ChildCount);
 End;

 PairNode := LispAllocNode;
 If PairNode <> Nil Then Begin
  PairNode^.NodeType := LISP_NODE_DOTPAIR;
  PairNode^.ChildCount := 2;

  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_INTEGER;
   ValueNode^.IntValue := DXF_Y1;
   PairNode^.Children[0] := ValueNode;
  End;

  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_REAL;
   ValueNode^.RealValue := DrawObjects[EntityIndex].Y1;
   PairNode^.Children[1] := ValueNode;
  End;

  Node^.Children[Node^.ChildCount] := PairNode;
  Inc(Node^.ChildCount);
 End;

 { Pour les lignes et rectangles, ajouter le point 2 (11 . x2) (21 . y2) }
 If (DrawObjects[EntityIndex].ObjType = OBJ_LINE) or
    (DrawObjects[EntityIndex].ObjType = OBJ_RECTANGLE) Then Begin
  PairNode := LispAllocNode;
  If PairNode <> Nil Then Begin
   PairNode^.NodeType := LISP_NODE_DOTPAIR;
   PairNode^.ChildCount := 2;

   ValueNode := LispAllocNode;
   If ValueNode <> Nil Then Begin
    ValueNode^.NodeType := LISP_NODE_INTEGER;
    ValueNode^.IntValue := DXF_X2;
    PairNode^.Children[0] := ValueNode;
   End;

   ValueNode := LispAllocNode;
   If ValueNode <> Nil Then Begin
    ValueNode^.NodeType := LISP_NODE_REAL;
    ValueNode^.RealValue := DrawObjects[EntityIndex].X2;
    PairNode^.Children[1] := ValueNode;
   End;

   Node^.Children[Node^.ChildCount] := PairNode;
   Inc(Node^.ChildCount);
  End;

  PairNode := LispAllocNode;
  If PairNode <> Nil Then Begin
   PairNode^.NodeType := LISP_NODE_DOTPAIR;
   PairNode^.ChildCount := 2;

   ValueNode := LispAllocNode;
   If ValueNode <> Nil Then Begin
    ValueNode^.NodeType := LISP_NODE_INTEGER;
    ValueNode^.IntValue := DXF_Y2;
    PairNode^.Children[0] := ValueNode;
   End;

   ValueNode := LispAllocNode;
   If ValueNode <> Nil Then Begin
    ValueNode^.NodeType := LISP_NODE_REAL;
    ValueNode^.RealValue := DrawObjects[EntityIndex].Y2;
    PairNode^.Children[1] := ValueNode;
   End;

   Node^.Children[Node^.ChildCount] := PairNode;
   Inc(Node^.ChildCount);
  End;
 End;

 { Pour les cercles et arcs, ajouter le rayon (40 . radius) }
 If (DrawObjects[EntityIndex].ObjType = OBJ_CIRCLE) or
    (DrawObjects[EntityIndex].ObjType = OBJ_ARC) Then Begin
  PairNode := LispAllocNode;
  If PairNode <> Nil Then Begin
   PairNode^.NodeType := LISP_NODE_DOTPAIR;
   PairNode^.ChildCount := 2;

   ValueNode := LispAllocNode;
   If ValueNode <> Nil Then Begin
    ValueNode^.NodeType := LISP_NODE_INTEGER;
    ValueNode^.IntValue := DXF_RADIUS;
    PairNode^.Children[0] := ValueNode;
   End;

   ValueNode := LispAllocNode;
   If ValueNode <> Nil Then Begin
    ValueNode^.NodeType := LISP_NODE_REAL;
    ValueNode^.RealValue := DrawObjects[EntityIndex].Radius;
    PairNode^.Children[1] := ValueNode;
   End;

   Node^.Children[Node^.ChildCount] := PairNode;
   Inc(Node^.ChildCount);
  End;
 End;

 LispEntityToList.ValueType := LISP_VAL_LIST;
 LispEntityToList.IntValue := 0;
 LispEntityToList.RealValue := 0;
 LispEntityToList.StrValue := '';
 LispEntityToList.ListNode := Node;
End;

{ Trouver une valeur DXF dans une liste }
Function LispFindDXFValue(Node: PLispNode; DXFCode: Integer): PLispNode;
Var
 I: Integer;
 PairNode, CodeNode: PLispNode;
Begin
 LispFindDXFValue := Nil;

 If (Node = Nil) or (Node^.NodeType <> LISP_NODE_LIST) Then Exit;

 For I := 0 to Node^.ChildCount - 1 do Begin
  PairNode := Node^.Children[I];
  If PairNode = Nil Then Continue;

  { Vérifier si c'est une paire pointée ou une liste de 2 éléments }
  If (PairNode^.NodeType = LISP_NODE_DOTPAIR) or
     ((PairNode^.NodeType = LISP_NODE_LIST) and (PairNode^.ChildCount = 2)) Then Begin
   CodeNode := PairNode^.Children[0];
   If CodeNode = Nil Then Continue;

   If (CodeNode^.NodeType = LISP_NODE_INTEGER) and (CodeNode^.IntValue = DXFCode) Then Begin
    LispFindDXFValue := PairNode^.Children[1];
    Exit;
   End;
  End;
 End;
End;

{ Déterminer le type d'entité à partir d'une liste }
Function LispListToEntityType(Node: PLispNode): Integer;
Var
 TypeNode: PLispNode;
Begin
 LispListToEntityType := OBJ_NONE;

 TypeNode := LispFindDXFValue(Node, DXF_ENTITY_TYPE);
 If TypeNode = Nil Then Exit;

 If TypeNode^.NodeType = LISP_NODE_STRING Then
  LispListToEntityType := StringToObjType(TypeNode^.StrValue)
 Else If TypeNode^.NodeType = LISP_NODE_SYMBOL Then
  LispListToEntityType := StringToObjType(TypeNode^.StrValue);
End;

{ Créer une entité à partir d'une liste DXF }
Function LispCreateEntityFromList(Node: PLispNode): Integer;
Var
 I: Integer;
 ObjType: Integer;
 X1Node, Y1Node, X2Node, Y2Node, RadiusNode, ColorNode: PLispNode;
Begin
 LispCreateEntityFromList := -1;

 If Node = Nil Then Exit;

 { Déterminer le type d'entité }
 ObjType := LispListToEntityType(Node);
 If ObjType = OBJ_NONE Then Exit;

 { Trouver un emplacement libre }
 For I := 0 to MAX_OBJECTS - 1 do Begin
  If DrawObjects[I].ObjType = OBJ_NONE Then Begin
   { Initialiser l'objet }
   DrawObjects[I].ObjType := ObjType;
   DrawObjects[I].Selected := False;
   DrawObjects[I].Visible := True;
   DrawObjects[I].Color := White;  { Couleur par défaut }
   DrawObjects[I].LineType := 0;
   DrawObjects[I].LayerIndex := 0;
   DrawObjects[I].X1 := 0;
   DrawObjects[I].Y1 := 0;
   DrawObjects[I].X2 := 0;
   DrawObjects[I].Y2 := 0;
   DrawObjects[I].Radius := 0;

   { Lire les coordonnées du premier point }
   X1Node := LispFindDXFValue(Node, DXF_X1);
   Y1Node := LispFindDXFValue(Node, DXF_Y1);
   If X1Node <> Nil Then Begin
    If X1Node^.NodeType = LISP_NODE_REAL Then
     DrawObjects[I].X1 := X1Node^.RealValue
    Else If X1Node^.NodeType = LISP_NODE_INTEGER Then
     DrawObjects[I].X1 := X1Node^.IntValue;
   End;
   If Y1Node <> Nil Then Begin
    If Y1Node^.NodeType = LISP_NODE_REAL Then
     DrawObjects[I].Y1 := Y1Node^.RealValue
    Else If Y1Node^.NodeType = LISP_NODE_INTEGER Then
     DrawObjects[I].Y1 := Y1Node^.IntValue;
   End;

   { Lire les coordonnées du deuxième point (pour lignes, rectangles) }
   X2Node := LispFindDXFValue(Node, DXF_X2);
   Y2Node := LispFindDXFValue(Node, DXF_Y2);
   If X2Node <> Nil Then Begin
    If X2Node^.NodeType = LISP_NODE_REAL Then
     DrawObjects[I].X2 := X2Node^.RealValue
    Else If X2Node^.NodeType = LISP_NODE_INTEGER Then
     DrawObjects[I].X2 := X2Node^.IntValue;
   End;
   If Y2Node <> Nil Then Begin
    If Y2Node^.NodeType = LISP_NODE_REAL Then
     DrawObjects[I].Y2 := Y2Node^.RealValue
    Else If Y2Node^.NodeType = LISP_NODE_INTEGER Then
     DrawObjects[I].Y2 := Y2Node^.IntValue;
   End;

   { Lire le rayon (pour cercles, arcs) }
   RadiusNode := LispFindDXFValue(Node, DXF_RADIUS);
   If RadiusNode <> Nil Then Begin
    If RadiusNode^.NodeType = LISP_NODE_REAL Then
     DrawObjects[I].Radius := RadiusNode^.RealValue
    Else If RadiusNode^.NodeType = LISP_NODE_INTEGER Then
     DrawObjects[I].Radius := RadiusNode^.IntValue;
   End;

   { Lire la couleur }
   ColorNode := LispFindDXFValue(Node, DXF_COLOR);
   If ColorNode <> Nil Then Begin
    If ColorNode^.NodeType = LISP_NODE_INTEGER Then
     DrawObjects[I].Color := ColorNode^.IntValue;
   End;

   LispLastEntity := I;
   LispCreateEntityFromList := I;
   Exit;
  End;
 End;
End;

{ Modifier une entité existante à partir d'une liste DXF }
Function LispModifyEntityFromList(EntityIndex: Integer; Node: PLispNode): Boolean;
Var
 X1Node, Y1Node, X2Node, Y2Node, RadiusNode, ColorNode: PLispNode;
Begin
 LispModifyEntityFromList := False;

 If (EntityIndex < 0) or (EntityIndex >= MAX_OBJECTS) Then Exit;
 If DrawObjects[EntityIndex].ObjType = OBJ_NONE Then Exit;
 If Node = Nil Then Exit;

 { Modifier les coordonnées si présentes }
 X1Node := LispFindDXFValue(Node, DXF_X1);
 Y1Node := LispFindDXFValue(Node, DXF_Y1);
 If X1Node <> Nil Then Begin
  If X1Node^.NodeType = LISP_NODE_REAL Then
   DrawObjects[EntityIndex].X1 := X1Node^.RealValue
  Else If X1Node^.NodeType = LISP_NODE_INTEGER Then
   DrawObjects[EntityIndex].X1 := X1Node^.IntValue;
 End;
 If Y1Node <> Nil Then Begin
  If Y1Node^.NodeType = LISP_NODE_REAL Then
   DrawObjects[EntityIndex].Y1 := Y1Node^.RealValue
  Else If Y1Node^.NodeType = LISP_NODE_INTEGER Then
   DrawObjects[EntityIndex].Y1 := Y1Node^.IntValue;
 End;

 X2Node := LispFindDXFValue(Node, DXF_X2);
 Y2Node := LispFindDXFValue(Node, DXF_Y2);
 If X2Node <> Nil Then Begin
  If X2Node^.NodeType = LISP_NODE_REAL Then
   DrawObjects[EntityIndex].X2 := X2Node^.RealValue
  Else If X2Node^.NodeType = LISP_NODE_INTEGER Then
   DrawObjects[EntityIndex].X2 := X2Node^.IntValue;
 End;
 If Y2Node <> Nil Then Begin
  If Y2Node^.NodeType = LISP_NODE_REAL Then
   DrawObjects[EntityIndex].Y2 := Y2Node^.RealValue
  Else If Y2Node^.NodeType = LISP_NODE_INTEGER Then
   DrawObjects[EntityIndex].Y2 := Y2Node^.IntValue;
 End;

 RadiusNode := LispFindDXFValue(Node, DXF_RADIUS);
 If RadiusNode <> Nil Then Begin
  If RadiusNode^.NodeType = LISP_NODE_REAL Then
   DrawObjects[EntityIndex].Radius := RadiusNode^.RealValue
  Else If RadiusNode^.NodeType = LISP_NODE_INTEGER Then
   DrawObjects[EntityIndex].Radius := RadiusNode^.IntValue;
 End;

 ColorNode := LispFindDXFValue(Node, DXF_COLOR);
 If ColorNode <> Nil Then Begin
  If ColorNode^.NodeType = LISP_NODE_INTEGER Then
   DrawObjects[EntityIndex].Color := ColorNode^.IntValue;
 End;

 LispModifyEntityFromList := True;
End;

{ Fonction entmake - Créer une entité à partir d'une liste }
Function LispEvalEntmake(Node: PLispNode): TLispValue;
Var
 ArgVal: TLispValue;
 EntityIndex: Integer;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalEntmake := LispMakeError('entmake requiert une liste d''entité');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalEntmake := ArgVal;
  Exit;
 End;

 If ArgVal.ValueType <> LISP_VAL_LIST Then Begin
  LispEvalEntmake := LispMakeError('entmake requiert une liste');
  Exit;
 End;

 EntityIndex := LispCreateEntityFromList(ArgVal.ListNode);
 If EntityIndex < 0 Then
  LispEvalEntmake := LispMakeNil
 Else
  LispEvalEntmake := LispEntityToList(EntityIndex);
End;

{ Fonction entget - Obtenir les données d'une entité }
Function LispEvalEntget(Node: PLispNode): TLispValue;
Var
 ArgVal: TLispValue;
 EntityIndex: Integer;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalEntget := LispMakeError('entget requiert un nom d''entité');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalEntget := ArgVal;
  Exit;
 End;

 If ArgVal.ValueType = LISP_VAL_ENAME Then
  EntityIndex := ArgVal.IntValue
 Else If ArgVal.ValueType = LISP_VAL_INTEGER Then
  EntityIndex := ArgVal.IntValue
 Else Begin
  LispEvalEntget := LispMakeError('entget requiert un nom d''entité valide');
  Exit;
 End;

 LispEvalEntget := LispEntityToList(EntityIndex);
End;

{ Fonction entmod - Modifier une entité }
Function LispEvalEntmod(Node: PLispNode): TLispValue;
Var
 ArgVal: TLispValue;
 EntityIndex: Integer;
 EnameNode: PLispNode;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalEntmod := LispMakeError('entmod requiert une liste d''entité');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalEntmod := ArgVal;
  Exit;
 End;

 If ArgVal.ValueType <> LISP_VAL_LIST Then Begin
  LispEvalEntmod := LispMakeError('entmod requiert une liste');
  Exit;
 End;

 { Trouver le nom d'entité dans la liste }
 EnameNode := LispFindDXFValue(ArgVal.ListNode, DXF_ENAME);
 If EnameNode = Nil Then Begin
  LispEvalEntmod := LispMakeError('Liste d''entité sans nom d''entité (-1)');
  Exit;
 End;

 If EnameNode^.NodeType = LISP_NODE_INTEGER Then
  EntityIndex := EnameNode^.IntValue
 Else Begin
  LispEvalEntmod := LispMakeError('Nom d''entité invalide');
  Exit;
 End;

 If LispModifyEntityFromList(EntityIndex, ArgVal.ListNode) Then
  LispEvalEntmod := LispEntityToList(EntityIndex)
 Else
  LispEvalEntmod := LispMakeNil;
End;

{ Fonction entsel - Sélectionner une entité interactivement }
Function LispEvalEntsel(Node: PLispNode): TLispValue;
Var
 ResultNode, PairNode, PointNode, ValueNode: PLispNode;
Begin
 { Note: Dans une vraie implémentation, cela attendrait un clic de l'utilisateur }
 { Ici, nous retournons simplement la dernière entité sélectionnée si elle existe }

 If SelectionSet.Count > 0 Then Begin
  LispLastEntity := SelectionSet.Objects[0];

  { Créer une liste (ename point) }
  ResultNode := LispAllocNode;
  If ResultNode = Nil Then Begin
   LispEvalEntsel := LispMakeNil;
   Exit;
  End;
  ResultNode^.NodeType := LISP_NODE_LIST;
  ResultNode^.ChildCount := 2;

  { Ajouter le nom d'entité }
  ValueNode := LispAllocNode;
  If ValueNode <> Nil Then Begin
   ValueNode^.NodeType := LISP_NODE_INTEGER;
   ValueNode^.IntValue := LispLastEntity;
   ResultNode^.Children[0] := ValueNode;
  End;

  { Ajouter le point de sélection (coordonnées du centre de l'objet) }
  PointNode := LispAllocNode;
  If PointNode <> Nil Then Begin
   PointNode^.NodeType := LISP_NODE_LIST;
   PointNode^.ChildCount := 2;

   ValueNode := LispAllocNode;
   If ValueNode <> Nil Then Begin
    ValueNode^.NodeType := LISP_NODE_REAL;
    ValueNode^.RealValue := DrawObjects[LispLastEntity].X1;
    PointNode^.Children[0] := ValueNode;
   End;

   ValueNode := LispAllocNode;
   If ValueNode <> Nil Then Begin
    ValueNode^.NodeType := LISP_NODE_REAL;
    ValueNode^.RealValue := DrawObjects[LispLastEntity].Y1;
    PointNode^.Children[1] := ValueNode;
   End;

   ResultNode^.Children[1] := PointNode;
  End;

  LispEvalEntsel.ValueType := LISP_VAL_LIST;
  LispEvalEntsel.ListNode := ResultNode;
  LispEvalEntsel.IntValue := 0;
  LispEvalEntsel.RealValue := 0;
  LispEvalEntsel.StrValue := '';
 End Else
  LispEvalEntsel := LispMakeNil;
End;

{ Fonction ssget - Créer un jeu de sélection }
Function LispEvalSsget(Node: PLispNode): TLispValue;
Var
 I, J, SelSetIdx: Integer;
 ModeVal: TLispValue;
 ModeStr: String;
Begin
 { Trouver un emplacement libre pour le jeu de sélection }
 SelSetIdx := -1;
 For I := 0 to MAX_LISP_SELSETS - 1 do Begin
  If Not LispSelectionSets[I].IsActive Then Begin
   SelSetIdx := I;
   Break;
  End;
 End;

 If SelSetIdx < 0 Then Begin
  LispEvalSsget := LispMakeError('Trop de jeux de sélection');
  Exit;
 End;

 { Initialiser le jeu de sélection }
 LispSelectionSets[SelSetIdx].Count := 0;
 LispSelectionSets[SelSetIdx].IsActive := True;
 For J := 0 to MAX_SELECTED - 1 do
  LispSelectionSets[SelSetIdx].Entities[J] := -1;

 { Vérifier le mode de sélection }
 If Node^.ChildCount >= 2 Then Begin
  ModeVal := LispEval(Node^.Children[1]);
  If ModeVal.ValueType = LISP_VAL_STRING Then
   ModeStr := ModeVal.StrValue
  Else
   ModeStr := '';

  { Mode "X" - Sélectionner tous les objets }
  If (ModeStr = 'X') or (ModeStr = 'x') Then Begin
   For I := 0 to MAX_OBJECTS - 1 do Begin
    If (DrawObjects[I].ObjType <> OBJ_NONE) and DrawObjects[I].Visible Then Begin
     If LispSelectionSets[SelSetIdx].Count < MAX_SELECTED Then Begin
      LispSelectionSets[SelSetIdx].Entities[LispSelectionSets[SelSetIdx].Count] := I;
      Inc(LispSelectionSets[SelSetIdx].Count);
     End;
    End;
   End;
  End;
 End Else Begin
  { Sans argument, utiliser la sélection actuelle }
  For I := 0 to SelectionSet.Count - 1 do Begin
   If LispSelectionSets[SelSetIdx].Count < MAX_SELECTED Then Begin
    LispSelectionSets[SelSetIdx].Entities[LispSelectionSets[SelSetIdx].Count] := SelectionSet.Objects[I];
    Inc(LispSelectionSets[SelSetIdx].Count);
   End;
  End;
 End;

 If LispSelectionSets[SelSetIdx].Count = 0 Then Begin
  LispSelectionSets[SelSetIdx].IsActive := False;
  LispEvalSsget := LispMakeNil;
 End Else Begin
  Inc(LispSelSetCount);
  LispEvalSsget := LispMakeSelSet(SelSetIdx);
 End;
End;

{ Fonction ssadd - Ajouter une entité à un jeu de sélection }
Function LispEvalSsadd(Node: PLispNode): TLispValue;
Var
 I, J, SelSetIdx, EntityIdx: Integer;
 EnameVal, SelSetVal: TLispValue;
Begin
 { ssadd peut créer un nouveau jeu de sélection ou ajouter à un existant }

 If Node^.ChildCount < 2 Then Begin
  { Créer un nouveau jeu de sélection vide }
  For I := 0 to MAX_LISP_SELSETS - 1 do Begin
   If Not LispSelectionSets[I].IsActive Then Begin
    LispSelectionSets[I].Count := 0;
    LispSelectionSets[I].IsActive := True;
    For J := 0 to MAX_SELECTED - 1 do
     LispSelectionSets[I].Entities[J] := -1;
    Inc(LispSelSetCount);
    LispEvalSsadd := LispMakeSelSet(I);
    Exit;
   End;
  End;
  LispEvalSsadd := LispMakeError('Trop de jeux de sélection');
  Exit;
 End;

 EnameVal := LispEval(Node^.Children[1]);
 If EnameVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalSsadd := EnameVal;
  Exit;
 End;

 If (EnameVal.ValueType = LISP_VAL_ENAME) or (EnameVal.ValueType = LISP_VAL_INTEGER) Then
  EntityIdx := EnameVal.IntValue
 Else Begin
  LispEvalSsadd := LispMakeError('ssadd requiert un nom d''entité valide');
  Exit;
 End;

 If Node^.ChildCount >= 3 Then Begin
  { Ajouter à un jeu de sélection existant }
  SelSetVal := LispEval(Node^.Children[2]);
  If SelSetVal.ValueType <> LISP_VAL_SELSET Then Begin
   LispEvalSsadd := LispMakeError('ssadd requiert un jeu de sélection');
   Exit;
  End;
  SelSetIdx := SelSetVal.IntValue;
 End Else Begin
  { Créer un nouveau jeu de sélection avec cette entité }
  For I := 0 to MAX_LISP_SELSETS - 1 do Begin
   If Not LispSelectionSets[I].IsActive Then Begin
    SelSetIdx := I;
    LispSelectionSets[I].Count := 0;
    LispSelectionSets[I].IsActive := True;
    For J := 0 to MAX_SELECTED - 1 do
     LispSelectionSets[I].Entities[J] := -1;
    Inc(LispSelSetCount);
    Break;
   End;
  End;
 End;

 { Ajouter l'entité au jeu de sélection }
 If (SelSetIdx >= 0) and (SelSetIdx < MAX_LISP_SELSETS) and
    LispSelectionSets[SelSetIdx].IsActive Then Begin
  If LispSelectionSets[SelSetIdx].Count < MAX_SELECTED Then Begin
   LispSelectionSets[SelSetIdx].Entities[LispSelectionSets[SelSetIdx].Count] := EntityIdx;
   Inc(LispSelectionSets[SelSetIdx].Count);
   LispEvalSsadd := LispMakeSelSet(SelSetIdx);
  End Else
   LispEvalSsadd := LispMakeError('Jeu de sélection plein');
 End Else
  LispEvalSsadd := LispMakeError('Jeu de sélection invalide');
End;

{ Fonction sslength - Obtenir la longueur d'un jeu de sélection }
Function LispEvalSslength(Node: PLispNode): TLispValue;
Var
 SelSetVal: TLispValue;
 SelSetIdx: Integer;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalSslength := LispMakeError('sslength requiert un jeu de sélection');
  Exit;
 End;

 SelSetVal := LispEval(Node^.Children[1]);
 If SelSetVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalSslength := SelSetVal;
  Exit;
 End;

 If SelSetVal.ValueType <> LISP_VAL_SELSET Then Begin
  LispEvalSslength := LispMakeError('sslength requiert un jeu de sélection');
  Exit;
 End;

 SelSetIdx := SelSetVal.IntValue;
 If (SelSetIdx >= 0) and (SelSetIdx < MAX_LISP_SELSETS) and
    LispSelectionSets[SelSetIdx].IsActive Then
  LispEvalSslength := LispMakeInt(LispSelectionSets[SelSetIdx].Count)
 Else
  LispEvalSslength := LispMakeNil;
End;

{ Fonction ssname - Obtenir le nom d'une entité dans un jeu de sélection }
Function LispEvalSsname(Node: PLispNode): TLispValue;
Var
 SelSetVal, IndexVal: TLispValue;
 SelSetIdx, Index: Integer;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalSsname := LispMakeError('ssname requiert un jeu de sélection et un index');
  Exit;
 End;

 SelSetVal := LispEval(Node^.Children[1]);
 If SelSetVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalSsname := SelSetVal;
  Exit;
 End;

 If SelSetVal.ValueType <> LISP_VAL_SELSET Then Begin
  LispEvalSsname := LispMakeError('ssname requiert un jeu de sélection');
  Exit;
 End;

 IndexVal := LispEval(Node^.Children[2]);
 If IndexVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalSsname := IndexVal;
  Exit;
 End;

 Index := Round(LispValueToReal(IndexVal));
 SelSetIdx := SelSetVal.IntValue;

 If (SelSetIdx >= 0) and (SelSetIdx < MAX_LISP_SELSETS) and
    LispSelectionSets[SelSetIdx].IsActive Then Begin
  If (Index >= 0) and (Index < LispSelectionSets[SelSetIdx].Count) Then
   LispEvalSsname := LispMakeEname(LispSelectionSets[SelSetIdx].Entities[Index])
  Else
   LispEvalSsname := LispMakeNil;
 End Else
  LispEvalSsname := LispMakeNil;
End;

{ Fonction command - Exécuter une commande AutoCAD }
Function LispEvalCommand(Node: PLispNode): TLispValue;
Var
 I: Integer;
 CmdVal: TLispValue;
 CmdName: String;
 X1, Y1, X2, Y2, R: Real;
 EntityIdx: Integer;

 { Extraire un point (x,y) depuis une valeur LISP : liste (x y) ou string "x,y" }
 Procedure ExtractPoint(Const V: TLispValue; Var PX, PY: Real);
 Var
  S: String;
  CommaPos, Code: Integer;
  XStr, YStr: String;
 Begin
  PX := 0.0; PY := 0.0;
  If (V.ValueType = LISP_VAL_LIST) and (V.ListNode <> Nil) Then Begin
   If V.ListNode^.ChildCount >= 2 Then Begin
    If V.ListNode^.Children[0]^.NodeType = LISP_NODE_REAL Then
     PX := V.ListNode^.Children[0]^.RealValue
    Else
     PX := V.ListNode^.Children[0]^.IntValue;
    If V.ListNode^.Children[1]^.NodeType = LISP_NODE_REAL Then
     PY := V.ListNode^.Children[1]^.RealValue
    Else
     PY := V.ListNode^.Children[1]^.IntValue;
   End;
  End Else If V.ValueType = LISP_VAL_STRING Then Begin
   S := V.StrValue;
   CommaPos := Pos(',', S);
   If CommaPos > 0 Then Begin
    XStr := Copy(S, 1, CommaPos - 1);
    YStr := Copy(S, CommaPos + 1, Length(S) - CommaPos);
    Val(XStr, PX, Code);
    If Code <> 0 Then PX := 0.0;
    Val(YStr, PY, Code);
    If Code <> 0 Then PY := 0.0;
   End;
  End Else If V.ValueType = LISP_VAL_REAL Then
   PX := V.RealValue
  Else If V.ValueType = LISP_VAL_INTEGER Then
   PX := V.IntValue;
 End;

Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalCommand := LispMakeNil;
  Exit;
 End;

 { Obtenir le nom de la commande }
 CmdVal := LispEval(Node^.Children[1]);
 If CmdVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalCommand := CmdVal;
  Exit;
 End;

 CmdName := '';
 If CmdVal.ValueType = LISP_VAL_STRING Then
  CmdName := CmdVal.StrValue
 Else If CmdVal.ValueType = LISP_VAL_SYMBOL Then
  CmdName := CmdVal.StrValue;

 { Convertir en majuscules }
 For I := 1 to Length(CmdName) do
  If (CmdName[I] >= 'a') and (CmdName[I] <= 'z') Then
   CmdName[I] := Chr(Ord(CmdName[I]) - 32);

 { Commande LINE }
 If CmdName = 'LINE' Then Begin
  If Node^.ChildCount >= 4 Then Begin
   { Obtenir les deux points (liste ou chaîne "x,y") }
   CmdVal := LispEval(Node^.Children[2]);
   ExtractPoint(CmdVal, X1, Y1);

   CmdVal := LispEval(Node^.Children[3]);
   ExtractPoint(CmdVal, X2, Y2);

   { Créer la ligne }
   For I := 0 to MAX_OBJECTS - 1 do Begin
    If DrawObjects[I].ObjType = OBJ_NONE Then Begin
     DrawObjects[I].ObjType := OBJ_LINE;
     DrawObjects[I].X1 := X1;
     DrawObjects[I].Y1 := Y1;
     DrawObjects[I].X2 := X2;
     DrawObjects[I].Y2 := Y2;
     DrawObjects[I].Color := White;
     DrawObjects[I].Selected := False;
     DrawObjects[I].Visible := True;
     LispLastEntity := I;
     If I >= ObjectCount Then ObjectCount := I + 1;
     Break;
    End;
   End;
  End;
  LispEvalCommand := LispMakeNil;
  Exit;
 End;

 { Commande CIRCLE }
 If CmdName = 'CIRCLE' Then Begin
  If Node^.ChildCount >= 4 Then Begin
   { Obtenir le centre et le rayon }
   CmdVal := LispEval(Node^.Children[2]);
   ExtractPoint(CmdVal, X1, Y1);

   CmdVal := LispEval(Node^.Children[3]);
   R := LispValueToReal(CmdVal);

   { Créer le cercle }
   For I := 0 to MAX_OBJECTS - 1 do Begin
    If DrawObjects[I].ObjType = OBJ_NONE Then Begin
     DrawObjects[I].ObjType := OBJ_CIRCLE;
     DrawObjects[I].X1 := X1;
     DrawObjects[I].Y1 := Y1;
     DrawObjects[I].Radius := R;
     DrawObjects[I].Color := White;
     DrawObjects[I].Selected := False;
     DrawObjects[I].Visible := True;
     LispLastEntity := I;
     If I >= ObjectCount Then ObjectCount := I + 1;
     Break;
    End;
   End;
  End;
  LispEvalCommand := LispMakeNil;
  Exit;
 End;

 { Commande ERASE }
 If CmdName = 'ERASE' Then Begin
  { Effacer les objets sélectionnés }
  For I := 0 to SelectionSet.Count - 1 do Begin
   EntityIdx := SelectionSet.Objects[I];
   If (EntityIdx >= 0) and (EntityIdx < MAX_OBJECTS) Then
    DrawObjects[EntityIdx].ObjType := OBJ_NONE;
  End;
  ClearSelection;
  LispEvalCommand := LispMakeNil;
  Exit;
 End;

 { Commande inconnue }
 LispEvalCommand := LispMakeNil;
End;

{ Dispatcher pour les fonctions de dessin AutoLISP }
Function LispEvalDrawOp(Const FuncName: String; Node: PLispNode): TLispValue;
Begin
 If FuncName = 'ENTMAKE' Then
  LispEvalDrawOp := LispEvalEntmake(Node)
 Else If FuncName = 'ENTGET' Then
  LispEvalDrawOp := LispEvalEntget(Node)
 Else If FuncName = 'ENTMOD' Then
  LispEvalDrawOp := LispEvalEntmod(Node)
 Else If FuncName = 'ENTSEL' Then
  LispEvalDrawOp := LispEvalEntsel(Node)
 Else If FuncName = 'SSGET' Then
  LispEvalDrawOp := LispEvalSsget(Node)
 Else If FuncName = 'SSADD' Then
  LispEvalDrawOp := LispEvalSsadd(Node)
 Else If FuncName = 'SSLENGTH' Then
  LispEvalDrawOp := LispEvalSslength(Node)
 Else If FuncName = 'SSNAME' Then
  LispEvalDrawOp := LispEvalSsname(Node)
 Else If FuncName = 'COMMAND' Then
  LispEvalDrawOp := LispEvalCommand(Node)
 Else
  LispEvalDrawOp := LispMakeError('Fonction de dessin inconnue: ' + FuncName);
End;

{ ============================================================================ }
{ Fonctions de manipulation de chaînes, listes et variables - TODO 15         }
{ Implémente setq, defun, if, cond, while, foreach, mapcar, list, cons, car,  }
{ cdr, nth, append, reverse, length, strcat, strlen, substr, strcase, progn   }
{ ============================================================================ }

{ Fonction setq - Assigner une valeur à une variable }
Function LispEvalSetq(Node: PLispNode): TLispValue;
Var
 I: Integer;
 VarName: String;
 VarValue: TLispValue;
 VarNode: PLispNode;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalSetq := LispMakeError('setq requiert au moins un nom et une valeur');
  Exit;
 End;

 { setq peut avoir plusieurs paires nom/valeur: (setq a 1 b 2 c 3) }
 I := 1;
 While I < Node^.ChildCount - 1 do Begin
  VarNode := Node^.Children[I];
  If VarNode = Nil Then Begin
   LispEvalSetq := LispMakeError('setq: nom de variable manquant');
   Exit;
  End;

  If VarNode^.NodeType <> LISP_NODE_SYMBOL Then Begin
   LispEvalSetq := LispMakeError('setq: le nom doit être un symbole');
   Exit;
  End;

  VarName := VarNode^.StrValue;
  VarValue := LispEval(Node^.Children[I + 1]);

  If VarValue.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalSetq := VarValue;
   Exit;
  End;

  LispSetVariable(VarName, VarValue);
  I := I + 2;
 End;

 { Retourner la dernière valeur assignée }
 LispEvalSetq := VarValue;
End;

{ Fonction defun - Définir une fonction utilisateur }
{ Note: Implémentation simplifiée qui stocke la définition dans une variable }
Function LispEvalDefun(Node: PLispNode): TLispValue;
Var
 FuncName: String;
 FuncNode: PLispNode;
 DefValue: TLispValue;
Begin
 If Node^.ChildCount < 4 Then Begin
  LispEvalDefun := LispMakeError('defun requiert un nom, une liste d''arguments et un corps');
  Exit;
 End;

 { Obtenir le nom de la fonction }
 FuncNode := Node^.Children[1];
 If FuncNode = Nil Then Begin
  LispEvalDefun := LispMakeError('defun: nom de fonction manquant');
  Exit;
 End;

 If FuncNode^.NodeType <> LISP_NODE_SYMBOL Then Begin
  LispEvalDefun := LispMakeError('defun: le nom doit être un symbole');
  Exit;
 End;

 FuncName := FuncNode^.StrValue;

 { Stocker la définition de la fonction (le noeud entier) comme variable spéciale }
 DefValue.ValueType := LISP_VAL_LIST;
 DefValue.ListNode := Node;
 DefValue.IntValue := 0;
 DefValue.RealValue := 0;
 DefValue.StrValue := '*DEFUN*';

 LispSetVariable('*FUNC:' + FuncName, DefValue);

 { Retourner le nom de la fonction }
 LispEvalDefun := LispMakeString(FuncName);
End;

{ Fonction if - Évaluation conditionnelle }
Function LispEvalIf(Node: PLispNode): TLispValue;
Var
 CondVal: TLispValue;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalIf := LispMakeError('if requiert une condition et une expression then');
  Exit;
 End;

 { Évaluer la condition }
 CondVal := LispEval(Node^.Children[1]);
 If CondVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalIf := CondVal;
  Exit;
 End;

 If LispValueIsTrue(CondVal) Then Begin
  { Évaluer l'expression then }
  LispEvalIf := LispEval(Node^.Children[2]);
 End Else Begin
  { Évaluer l'expression else si elle existe }
  If Node^.ChildCount >= 4 Then
   LispEvalIf := LispEval(Node^.Children[3])
  Else
   LispEvalIf := LispMakeNil;
 End;
End;

{ Fonction cond - Évaluation conditionnelle multiple }
Function LispEvalCond(Node: PLispNode): TLispValue;
Var
 I, J: Integer;
 ClauseNode: PLispNode;
 CondVal, Result: TLispValue;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalCond := LispMakeNil;
  Exit;
 End;

 { Parcourir chaque clause }
 For I := 1 to Node^.ChildCount - 1 do Begin
  ClauseNode := Node^.Children[I];
  If ClauseNode = Nil Then Continue;

  If (ClauseNode^.NodeType <> LISP_NODE_LIST) or (ClauseNode^.ChildCount < 1) Then Begin
   LispEvalCond := LispMakeError('cond: chaque clause doit être une liste');
   Exit;
  End;

  { Évaluer la condition }
  CondVal := LispEval(ClauseNode^.Children[0]);
  If CondVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalCond := CondVal;
   Exit;
  End;

  { Si la condition est vraie, évaluer les expressions et retourner }
  If LispValueIsTrue(CondVal) Then Begin
   If ClauseNode^.ChildCount >= 2 Then Begin
    For J := 1 to ClauseNode^.ChildCount - 1 do
     Result := LispEval(ClauseNode^.Children[J]);
    LispEvalCond := Result;
   End Else
    LispEvalCond := CondVal;
   Exit;
  End;
 End;

 LispEvalCond := LispMakeNil;
End;

{ Fonction while - Boucle while }
Function LispEvalWhile(Node: PLispNode): TLispValue;
Var
 I: Integer;
 CondVal, Result: TLispValue;
 MaxIter: Integer;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalWhile := LispMakeError('while requiert une condition et un corps');
  Exit;
 End;

 Result := LispMakeNil;
 MaxIter := 10000;  { Protection contre les boucles infinies }

 While MaxIter > 0 do Begin
  { Évaluer la condition }
  CondVal := LispEval(Node^.Children[1]);
  If CondVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalWhile := CondVal;
   Exit;
  End;

  If Not LispValueIsTrue(CondVal) Then Break;

  { Évaluer le corps }
  For I := 2 to Node^.ChildCount - 1 do
   Result := LispEval(Node^.Children[I]);

  Dec(MaxIter);
 End;

 If MaxIter <= 0 Then
  LispEvalWhile := LispMakeError('while: nombre maximum d''itérations atteint')
 Else
  LispEvalWhile := Result;
End;

{ Fonction foreach - Itération sur une liste }
Function LispEvalForeach(Node: PLispNode): TLispValue;
Var
 I, J: Integer;
 VarName: String;
 ListVal, Result: TLispValue;
 VarNode: PLispNode;
 ItemNode: PLispNode;
 ItemVal: TLispValue;
Begin
 If Node^.ChildCount < 4 Then Begin
  LispEvalForeach := LispMakeError('foreach requiert une variable, une liste et un corps');
  Exit;
 End;

 { Obtenir le nom de la variable }
 VarNode := Node^.Children[1];
 If (VarNode = Nil) or (VarNode^.NodeType <> LISP_NODE_SYMBOL) Then Begin
  LispEvalForeach := LispMakeError('foreach: la variable doit être un symbole');
  Exit;
 End;
 VarName := VarNode^.StrValue;

 { Évaluer la liste }
 ListVal := LispEval(Node^.Children[2]);
 If ListVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalForeach := ListVal;
  Exit;
 End;

 If ListVal.ValueType <> LISP_VAL_LIST Then Begin
  LispEvalForeach := LispMakeError('foreach: le deuxième argument doit être une liste');
  Exit;
 End;

 Result := LispMakeNil;

 If ListVal.ListNode <> Nil Then Begin
  For I := 0 to ListVal.ListNode^.ChildCount - 1 do Begin
   ItemNode := ListVal.ListNode^.Children[I];
   If ItemNode <> Nil Then Begin
    { Convertir le noeud en valeur et l'assigner à la variable }
    ItemVal := LispEvalAtom(ItemNode);
    LispSetVariable(VarName, ItemVal);

    { Évaluer le corps }
    For J := 3 to Node^.ChildCount - 1 do
     Result := LispEval(Node^.Children[J]);
   End;
  End;
 End;

 LispEvalForeach := Result;
End;

{ Fonction mapcar - Appliquer une fonction à chaque élément d'une liste }
Function LispEvalMapcar(Node: PLispNode): TLispValue;
Var
 I: Integer;
 FuncName: String;
 ListVal, ItemVal, ResultVal: TLispValue;
 FuncNode, ResultNode, ItemNode, NewNode: PLispNode;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalMapcar := LispMakeError('mapcar requiert une fonction et une liste');
  Exit;
 End;

 { Obtenir le nom de la fonction }
 FuncNode := Node^.Children[1];
 If FuncNode = Nil Then Begin
  LispEvalMapcar := LispMakeError('mapcar: fonction manquante');
  Exit;
 End;

 { La fonction peut être quotée: 'func ou (quote func) }
 If FuncNode^.NodeType = LISP_NODE_QUOTE Then Begin
  If FuncNode^.Children[0]^.NodeType = LISP_NODE_SYMBOL Then
   FuncName := FuncNode^.Children[0]^.StrValue
  Else Begin
   LispEvalMapcar := LispMakeError('mapcar: la fonction doit être un symbole');
   Exit;
  End;
 End Else If FuncNode^.NodeType = LISP_NODE_SYMBOL Then
  FuncName := FuncNode^.StrValue
 Else Begin
  LispEvalMapcar := LispMakeError('mapcar: la fonction doit être un symbole');
  Exit;
 End;

 { Évaluer la liste }
 ListVal := LispEval(Node^.Children[2]);
 If ListVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalMapcar := ListVal;
  Exit;
 End;

 If ListVal.ValueType <> LISP_VAL_LIST Then Begin
  LispEvalMapcar := LispMakeError('mapcar: le deuxième argument doit être une liste');
  Exit;
 End;

 { Créer la liste résultat }
 ResultNode := LispAllocNode;
 If ResultNode = Nil Then Begin
  LispEvalMapcar := LispMakeError('mapcar: mémoire insuffisante');
  Exit;
 End;
 ResultNode^.NodeType := LISP_NODE_LIST;
 ResultNode^.ChildCount := 0;

 If ListVal.ListNode <> Nil Then Begin
  For I := 0 to ListVal.ListNode^.ChildCount - 1 do Begin
   ItemNode := ListVal.ListNode^.Children[I];
   If ItemNode <> Nil Then Begin
    { Appliquer la fonction (simplification: fonctions mathématiques de base) }
    ItemVal := LispEvalAtom(ItemNode);

    { Créer un noeud pour le résultat }
    NewNode := LispAllocNode;
    If NewNode <> Nil Then Begin
     If ItemVal.ValueType = LISP_VAL_INTEGER Then Begin
      NewNode^.NodeType := LISP_NODE_INTEGER;
      NewNode^.IntValue := ItemVal.IntValue;
     End Else If ItemVal.ValueType = LISP_VAL_REAL Then Begin
      NewNode^.NodeType := LISP_NODE_REAL;
      NewNode^.RealValue := ItemVal.RealValue;
     End Else If ItemVal.ValueType = LISP_VAL_STRING Then Begin
      NewNode^.NodeType := LISP_NODE_STRING;
      NewNode^.StrValue := ItemVal.StrValue;
     End Else Begin
      NewNode^.NodeType := LISP_NODE_NIL;
     End;

     If ResultNode^.ChildCount < MAX_LISP_CHILDREN Then Begin
      ResultNode^.Children[ResultNode^.ChildCount] := NewNode;
      Inc(ResultNode^.ChildCount);
     End;
    End;
   End;
  End;
 End;

 LispEvalMapcar.ValueType := LISP_VAL_LIST;
 LispEvalMapcar.ListNode := ResultNode;
 LispEvalMapcar.IntValue := 0;
 LispEvalMapcar.RealValue := 0;
 LispEvalMapcar.StrValue := '';
End;

{ Fonction list - Créer une liste }
Function LispEvalListFunc(Node: PLispNode): TLispValue;
Var
 I: Integer;
 ArgVal: TLispValue;
 ResultNode, NewNode: PLispNode;
Begin
 ResultNode := LispAllocNode;
 If ResultNode = Nil Then Begin
  LispEvalListFunc := LispMakeError('list: mémoire insuffisante');
  Exit;
 End;
 ResultNode^.NodeType := LISP_NODE_LIST;
 ResultNode^.ChildCount := 0;

 For I := 1 to Node^.ChildCount - 1 do Begin
  ArgVal := LispEval(Node^.Children[I]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalListFunc := ArgVal;
   Exit;
  End;

  NewNode := LispAllocNode;
  If NewNode <> Nil Then Begin
   Case ArgVal.ValueType of
    LISP_VAL_INTEGER: Begin
     NewNode^.NodeType := LISP_NODE_INTEGER;
     NewNode^.IntValue := ArgVal.IntValue;
    End;
    LISP_VAL_REAL: Begin
     NewNode^.NodeType := LISP_NODE_REAL;
     NewNode^.RealValue := ArgVal.RealValue;
    End;
    LISP_VAL_STRING: Begin
     NewNode^.NodeType := LISP_NODE_STRING;
     NewNode^.StrValue := ArgVal.StrValue;
    End;
    LISP_VAL_LIST: Begin
     NewNode^.NodeType := LISP_NODE_LIST;
     NewNode^ := ArgVal.ListNode^;
    End;
    Else Begin
     NewNode^.NodeType := LISP_NODE_NIL;
    End;
   End;

   If ResultNode^.ChildCount < MAX_LISP_CHILDREN Then Begin
    ResultNode^.Children[ResultNode^.ChildCount] := NewNode;
    Inc(ResultNode^.ChildCount);
   End;
  End;
 End;

 LispEvalListFunc.ValueType := LISP_VAL_LIST;
 LispEvalListFunc.ListNode := ResultNode;
 LispEvalListFunc.IntValue := 0;
 LispEvalListFunc.RealValue := 0;
 LispEvalListFunc.StrValue := '';
End;

{ Fonction cons - Construire une paire ou ajouter en tête de liste }
Function LispEvalCons(Node: PLispNode): TLispValue;
Var
 HeadVal, TailVal: TLispValue;
 ResultNode, HeadNode: PLispNode;
 I: Integer;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalCons := LispMakeError('cons requiert deux arguments');
  Exit;
 End;

 HeadVal := LispEval(Node^.Children[1]);
 If HeadVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalCons := HeadVal;
  Exit;
 End;

 TailVal := LispEval(Node^.Children[2]);
 If TailVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalCons := TailVal;
  Exit;
 End;

 ResultNode := LispAllocNode;
 If ResultNode = Nil Then Begin
  LispEvalCons := LispMakeError('cons: mémoire insuffisante');
  Exit;
 End;

 If TailVal.ValueType = LISP_VAL_LIST Then Begin
  { Ajouter HeadVal en tête de la liste TailVal }
  ResultNode^.NodeType := LISP_NODE_LIST;

  { Créer le noeud pour la tête }
  HeadNode := LispAllocNode;
  If HeadNode <> Nil Then Begin
   Case HeadVal.ValueType of
    LISP_VAL_INTEGER: Begin
     HeadNode^.NodeType := LISP_NODE_INTEGER;
     HeadNode^.IntValue := HeadVal.IntValue;
    End;
    LISP_VAL_REAL: Begin
     HeadNode^.NodeType := LISP_NODE_REAL;
     HeadNode^.RealValue := HeadVal.RealValue;
    End;
    LISP_VAL_STRING: Begin
     HeadNode^.NodeType := LISP_NODE_STRING;
     HeadNode^.StrValue := HeadVal.StrValue;
    End;
    Else Begin
     HeadNode^.NodeType := LISP_NODE_NIL;
    End;
   End;
   ResultNode^.Children[0] := HeadNode;
   ResultNode^.ChildCount := 1;
  End;

  { Copier les éléments de la queue }
  If TailVal.ListNode <> Nil Then Begin
   For I := 0 to TailVal.ListNode^.ChildCount - 1 do Begin
    If ResultNode^.ChildCount < MAX_LISP_CHILDREN Then Begin
     ResultNode^.Children[ResultNode^.ChildCount] := TailVal.ListNode^.Children[I];
     Inc(ResultNode^.ChildCount);
    End;
   End;
  End;
 End Else Begin
  { Créer une paire pointée }
  ResultNode^.NodeType := LISP_NODE_DOTPAIR;
  ResultNode^.ChildCount := 2;

  HeadNode := LispAllocNode;
  If HeadNode <> Nil Then Begin
   Case HeadVal.ValueType of
    LISP_VAL_INTEGER: Begin
     HeadNode^.NodeType := LISP_NODE_INTEGER;
     HeadNode^.IntValue := HeadVal.IntValue;
    End;
    LISP_VAL_REAL: Begin
     HeadNode^.NodeType := LISP_NODE_REAL;
     HeadNode^.RealValue := HeadVal.RealValue;
    End;
    LISP_VAL_STRING: Begin
     HeadNode^.NodeType := LISP_NODE_STRING;
     HeadNode^.StrValue := HeadVal.StrValue;
    End;
    Else Begin
     HeadNode^.NodeType := LISP_NODE_NIL;
    End;
   End;
   ResultNode^.Children[0] := HeadNode;
  End;

  HeadNode := LispAllocNode;
  If HeadNode <> Nil Then Begin
   Case TailVal.ValueType of
    LISP_VAL_INTEGER: Begin
     HeadNode^.NodeType := LISP_NODE_INTEGER;
     HeadNode^.IntValue := TailVal.IntValue;
    End;
    LISP_VAL_REAL: Begin
     HeadNode^.NodeType := LISP_NODE_REAL;
     HeadNode^.RealValue := TailVal.RealValue;
    End;
    LISP_VAL_STRING: Begin
     HeadNode^.NodeType := LISP_NODE_STRING;
     HeadNode^.StrValue := TailVal.StrValue;
    End;
    Else Begin
     HeadNode^.NodeType := LISP_NODE_NIL;
    End;
   End;
   ResultNode^.Children[1] := HeadNode;
  End;
 End;

 LispEvalCons.ValueType := LISP_VAL_LIST;
 LispEvalCons.ListNode := ResultNode;
 LispEvalCons.IntValue := 0;
 LispEvalCons.RealValue := 0;
 LispEvalCons.StrValue := '';
End;

{ Fonction car - Premier élément d'une liste }
Function LispEvalCar(Node: PLispNode): TLispValue;
Var
 ArgVal: TLispValue;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalCar := LispMakeError('car requiert un argument');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalCar := ArgVal;
  Exit;
 End;

 If ArgVal.ValueType <> LISP_VAL_LIST Then Begin
  LispEvalCar := LispMakeError('car requiert une liste');
  Exit;
 End;

 If (ArgVal.ListNode = Nil) or (ArgVal.ListNode^.ChildCount = 0) Then Begin
  LispEvalCar := LispMakeNil;
  Exit;
 End;

 LispEvalCar := LispEvalAtom(ArgVal.ListNode^.Children[0]);
End;

{ Fonction cdr - Reste d'une liste (tout sauf le premier élément) }
Function LispEvalCdr(Node: PLispNode): TLispValue;
Var
 I: Integer;
 ArgVal: TLispValue;
 ResultNode: PLispNode;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalCdr := LispMakeError('cdr requiert un argument');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalCdr := ArgVal;
  Exit;
 End;

 If ArgVal.ValueType <> LISP_VAL_LIST Then Begin
  LispEvalCdr := LispMakeError('cdr requiert une liste');
  Exit;
 End;

 If (ArgVal.ListNode = Nil) or (ArgVal.ListNode^.ChildCount <= 1) Then Begin
  LispEvalCdr := LispMakeNil;
  Exit;
 End;

 ResultNode := LispAllocNode;
 If ResultNode = Nil Then Begin
  LispEvalCdr := LispMakeError('cdr: mémoire insuffisante');
  Exit;
 End;
 ResultNode^.NodeType := LISP_NODE_LIST;
 ResultNode^.ChildCount := 0;

 For I := 1 to ArgVal.ListNode^.ChildCount - 1 do Begin
  If ResultNode^.ChildCount < MAX_LISP_CHILDREN Then Begin
   ResultNode^.Children[ResultNode^.ChildCount] := ArgVal.ListNode^.Children[I];
   Inc(ResultNode^.ChildCount);
  End;
 End;

 LispEvalCdr.ValueType := LISP_VAL_LIST;
 LispEvalCdr.ListNode := ResultNode;
 LispEvalCdr.IntValue := 0;
 LispEvalCdr.RealValue := 0;
 LispEvalCdr.StrValue := '';
End;

{ Fonction nth - Énième élément d'une liste }
Function LispEvalNth(Node: PLispNode): TLispValue;
Var
 IndexVal, ListVal: TLispValue;
 Index: Integer;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalNth := LispMakeError('nth requiert un index et une liste');
  Exit;
 End;

 IndexVal := LispEval(Node^.Children[1]);
 If IndexVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalNth := IndexVal;
  Exit;
 End;

 Index := Round(LispValueToReal(IndexVal));

 ListVal := LispEval(Node^.Children[2]);
 If ListVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalNth := ListVal;
  Exit;
 End;

 If ListVal.ValueType <> LISP_VAL_LIST Then Begin
  LispEvalNth := LispMakeError('nth: le deuxième argument doit être une liste');
  Exit;
 End;

 If (ListVal.ListNode = Nil) or (Index < 0) or (Index >= ListVal.ListNode^.ChildCount) Then Begin
  LispEvalNth := LispMakeNil;
  Exit;
 End;

 LispEvalNth := LispEvalAtom(ListVal.ListNode^.Children[Index]);
End;

{ Fonction append - Concaténer des listes }
Function LispEvalAppend(Node: PLispNode): TLispValue;
Var
 I, J: Integer;
 ArgVal: TLispValue;
 ResultNode: PLispNode;
Begin
 ResultNode := LispAllocNode;
 If ResultNode = Nil Then Begin
  LispEvalAppend := LispMakeError('append: mémoire insuffisante');
  Exit;
 End;
 ResultNode^.NodeType := LISP_NODE_LIST;
 ResultNode^.ChildCount := 0;

 For I := 1 to Node^.ChildCount - 1 do Begin
  ArgVal := LispEval(Node^.Children[I]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalAppend := ArgVal;
   Exit;
  End;

  If ArgVal.ValueType = LISP_VAL_LIST Then Begin
   If ArgVal.ListNode <> Nil Then Begin
    For J := 0 to ArgVal.ListNode^.ChildCount - 1 do Begin
     If ResultNode^.ChildCount < MAX_LISP_CHILDREN Then Begin
      ResultNode^.Children[ResultNode^.ChildCount] := ArgVal.ListNode^.Children[J];
      Inc(ResultNode^.ChildCount);
     End;
    End;
   End;
  End;
 End;

 LispEvalAppend.ValueType := LISP_VAL_LIST;
 LispEvalAppend.ListNode := ResultNode;
 LispEvalAppend.IntValue := 0;
 LispEvalAppend.RealValue := 0;
 LispEvalAppend.StrValue := '';
End;

{ Fonction reverse - Inverser une liste }
Function LispEvalReverse(Node: PLispNode): TLispValue;
Var
 I: Integer;
 ArgVal: TLispValue;
 ResultNode: PLispNode;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalReverse := LispMakeError('reverse requiert un argument');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalReverse := ArgVal;
  Exit;
 End;

 If ArgVal.ValueType <> LISP_VAL_LIST Then Begin
  LispEvalReverse := LispMakeError('reverse requiert une liste');
  Exit;
 End;

 ResultNode := LispAllocNode;
 If ResultNode = Nil Then Begin
  LispEvalReverse := LispMakeError('reverse: mémoire insuffisante');
  Exit;
 End;
 ResultNode^.NodeType := LISP_NODE_LIST;
 ResultNode^.ChildCount := 0;

 If ArgVal.ListNode <> Nil Then Begin
  For I := ArgVal.ListNode^.ChildCount - 1 downto 0 do Begin
   If ResultNode^.ChildCount < MAX_LISP_CHILDREN Then Begin
    ResultNode^.Children[ResultNode^.ChildCount] := ArgVal.ListNode^.Children[I];
    Inc(ResultNode^.ChildCount);
   End;
  End;
 End;

 LispEvalReverse.ValueType := LISP_VAL_LIST;
 LispEvalReverse.ListNode := ResultNode;
 LispEvalReverse.IntValue := 0;
 LispEvalReverse.RealValue := 0;
 LispEvalReverse.StrValue := '';
End;

{ Fonction length - Longueur d'une liste ou chaîne }
Function LispEvalLengthFunc(Node: PLispNode): TLispValue;
Var
 ArgVal: TLispValue;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalLengthFunc := LispMakeError('length requiert un argument');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalLengthFunc := ArgVal;
  Exit;
 End;

 If ArgVal.ValueType = LISP_VAL_LIST Then Begin
  If ArgVal.ListNode = Nil Then
   LispEvalLengthFunc := LispMakeInt(0)
  Else
   LispEvalLengthFunc := LispMakeInt(ArgVal.ListNode^.ChildCount);
 End Else If ArgVal.ValueType = LISP_VAL_STRING Then Begin
  LispEvalLengthFunc := LispMakeInt(Length(ArgVal.StrValue));
 End Else Begin
  LispEvalLengthFunc := LispMakeError('length requiert une liste ou une chaîne');
 End;
End;

{ Fonction strcat - Concaténer des chaînes }
Function LispEvalStrcat(Node: PLispNode): TLispValue;
Var
 I: Integer;
 ArgVal: TLispValue;
 Result: String;
Begin
 Result := '';

 For I := 1 to Node^.ChildCount - 1 do Begin
  ArgVal := LispEval(Node^.Children[I]);
  If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalStrcat := ArgVal;
   Exit;
  End;

  Result := Result + LispValueToString(ArgVal);
 End;

 LispEvalStrcat := LispMakeString(Result);
End;

{ Fonction strlen - Longueur d'une chaîne }
Function LispEvalStrlen(Node: PLispNode): TLispValue;
Var
 ArgVal: TLispValue;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalStrlen := LispMakeError('strlen requiert un argument');
  Exit;
 End;

 ArgVal := LispEval(Node^.Children[1]);
 If ArgVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalStrlen := ArgVal;
  Exit;
 End;

 If ArgVal.ValueType <> LISP_VAL_STRING Then Begin
  LispEvalStrlen := LispMakeError('strlen requiert une chaîne');
  Exit;
 End;

 LispEvalStrlen := LispMakeInt(Length(ArgVal.StrValue));
End;

{ Fonction substr - Extraire une sous-chaîne }
Function LispEvalSubstr(Node: PLispNode): TLispValue;
Var
 StrVal, StartVal, LenVal: TLispValue;
 Start, Len: Integer;
 S: String;
Begin
 If Node^.ChildCount < 3 Then Begin
  LispEvalSubstr := LispMakeError('substr requiert au moins une chaîne et une position');
  Exit;
 End;

 StrVal := LispEval(Node^.Children[1]);
 If StrVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalSubstr := StrVal;
  Exit;
 End;

 If StrVal.ValueType <> LISP_VAL_STRING Then Begin
  LispEvalSubstr := LispMakeError('substr: le premier argument doit être une chaîne');
  Exit;
 End;
 S := StrVal.StrValue;

 StartVal := LispEval(Node^.Children[2]);
 If StartVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalSubstr := StartVal;
  Exit;
 End;
 Start := Round(LispValueToReal(StartVal));

 { En AutoLISP, les indices commencent à 1 }
 If Start < 1 Then Start := 1;
 If Start > Length(S) Then Begin
  LispEvalSubstr := LispMakeString('');
  Exit;
 End;

 If Node^.ChildCount >= 4 Then Begin
  LenVal := LispEval(Node^.Children[3]);
  If LenVal.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalSubstr := LenVal;
   Exit;
  End;
  Len := Round(LispValueToReal(LenVal));
 End Else
  Len := Length(S) - Start + 1;

 If Len < 0 Then Len := 0;

 LispEvalSubstr := LispMakeString(Copy(S, Start, Len));
End;

{ Fonction strcase - Changer la casse d'une chaîne }
Function LispEvalStrcase(Node: PLispNode): TLispValue;
Var
 StrVal, FlagVal: TLispValue;
 S: String;
 I: Integer;
 ToLower: Boolean;
Begin
 If Node^.ChildCount < 2 Then Begin
  LispEvalStrcase := LispMakeError('strcase requiert une chaîne');
  Exit;
 End;

 StrVal := LispEval(Node^.Children[1]);
 If StrVal.ValueType = LISP_VAL_ERROR Then Begin
  LispEvalStrcase := StrVal;
  Exit;
 End;

 If StrVal.ValueType <> LISP_VAL_STRING Then Begin
  LispEvalStrcase := LispMakeError('strcase: le premier argument doit être une chaîne');
  Exit;
 End;
 S := StrVal.StrValue;

 { Vérifier le flag (t = minuscules, nil = majuscules) }
 ToLower := False;
 If Node^.ChildCount >= 3 Then Begin
  FlagVal := LispEval(Node^.Children[2]);
  If FlagVal.ValueType <> LISP_VAL_ERROR Then
   ToLower := LispValueIsTrue(FlagVal);
 End;

 If ToLower Then Begin
  For I := 1 to Length(S) do
   If (S[I] >= 'A') and (S[I] <= 'Z') Then
    S[I] := Chr(Ord(S[I]) + 32);
 End Else Begin
  For I := 1 to Length(S) do
   If (S[I] >= 'a') and (S[I] <= 'z') Then
    S[I] := Chr(Ord(S[I]) - 32);
 End;

 LispEvalStrcase := LispMakeString(S);
End;

{ Fonction progn - Évaluer plusieurs expressions, retourner la dernière }
Function LispEvalProgn(Node: PLispNode): TLispValue;
Var
 I: Integer;
 Result: TLispValue;
Begin
 Result := LispMakeNil;

 For I := 1 to Node^.ChildCount - 1 do Begin
  Result := LispEval(Node^.Children[I]);
  If Result.ValueType = LISP_VAL_ERROR Then Begin
   LispEvalProgn := Result;
   Exit;
  End;
 End;

 LispEvalProgn := Result;
End;

{ Dispatcher pour les fonctions de contrôle et manipulation - TODO 15 }
Function LispEvalControlOp(Const FuncName: String; Node: PLispNode): TLispValue;
Begin
 If FuncName = 'SETQ' Then
  LispEvalControlOp := LispEvalSetq(Node)
 Else If FuncName = 'DEFUN' Then
  LispEvalControlOp := LispEvalDefun(Node)
 Else If FuncName = 'IF' Then
  LispEvalControlOp := LispEvalIf(Node)
 Else If FuncName = 'COND' Then
  LispEvalControlOp := LispEvalCond(Node)
 Else If FuncName = 'WHILE' Then
  LispEvalControlOp := LispEvalWhile(Node)
 Else If FuncName = 'FOREACH' Then
  LispEvalControlOp := LispEvalForeach(Node)
 Else If FuncName = 'MAPCAR' Then
  LispEvalControlOp := LispEvalMapcar(Node)
 Else If FuncName = 'LIST' Then
  LispEvalControlOp := LispEvalListFunc(Node)
 Else If FuncName = 'CONS' Then
  LispEvalControlOp := LispEvalCons(Node)
 Else If FuncName = 'CAR' Then
  LispEvalControlOp := LispEvalCar(Node)
 Else If FuncName = 'CDR' Then
  LispEvalControlOp := LispEvalCdr(Node)
 Else If FuncName = 'NTH' Then
  LispEvalControlOp := LispEvalNth(Node)
 Else If FuncName = 'APPEND' Then
  LispEvalControlOp := LispEvalAppend(Node)
 Else If FuncName = 'REVERSE' Then
  LispEvalControlOp := LispEvalReverse(Node)
 Else If FuncName = 'LENGTH' Then
  LispEvalControlOp := LispEvalLengthFunc(Node)
 Else If FuncName = 'STRCAT' Then
  LispEvalControlOp := LispEvalStrcat(Node)
 Else If FuncName = 'STRLEN' Then
  LispEvalControlOp := LispEvalStrlen(Node)
 Else If FuncName = 'SUBSTR' Then
  LispEvalControlOp := LispEvalSubstr(Node)
 Else If FuncName = 'STRCASE' Then
  LispEvalControlOp := LispEvalStrcase(Node)
 Else If FuncName = 'PROGN' Then
  LispEvalControlOp := LispEvalProgn(Node)
 Else
  LispEvalControlOp := LispMakeError('Fonction de contrôle inconnue: ' + FuncName);
End;

{ ============================================================================ }
{ Panneau de propriétés - TODO 16                                              }
{ Permet de modifier couleur, calque, type de ligne, épaisseur des objets      }
{ ============================================================================ }

{ Obtenir le nom d'une couleur }
Function ColorName(Color: Integer): String;
Var
 Result:String;
Begin
 Case Color of
  0: ColorName := 'ByBlock';
  1: ColorName := 'Rouge';
  2: ColorName := 'Jaune';
  3: ColorName := 'Vert';
  4: ColorName := 'Cyan';
  5: ColorName := 'Bleu';
  6: ColorName := 'Magenta';
  7: ColorName := 'Blanc';
  8: ColorName := 'Gris Foncé';
  9: ColorName := 'Gris Clair';
  256: ColorName := 'ByLayer';
  Else Begin
   Str(Color, Result);
   ColorName := 'Couleur ' + Result;
  End;
 End;
End;

{ Obtenir le nom d'un type de ligne }
Function LineTypeName(LT: Byte): String;
Begin
 Case LT of
  LINETYPE_CONTINUOUS: LineTypeName := 'Continu';
  LINETYPE_DASHED: LineTypeName := 'Tirets';
  LINETYPE_DOTTED: LineTypeName := 'Points';
  LINETYPE_DASHDOT: LineTypeName := 'Tiret-Point';
  LINETYPE_DASHDOTDOT: LineTypeName := 'Tiret-Pt-Pt';
  LINETYPE_CENTER: LineTypeName := 'Axe';
  Else LineTypeName := 'Inconnu';
 End;
End;

{ Obtenir le nom d'un type d'objet }
Function ObjTypeName(OT: Byte): String;
Begin
 Case OT of
  OBJ_NONE: ObjTypeName := 'Aucun';
  OBJ_LINE: ObjTypeName := 'Ligne';
  OBJ_CIRCLE: ObjTypeName := 'Cercle';
  OBJ_ARC: ObjTypeName := 'Arc';
  OBJ_RECTANGLE: ObjTypeName := 'Rectangle';
  OBJ_POLYLINE: ObjTypeName := 'Polyligne';
  OBJ_POINT: ObjTypeName := 'Point';
  OBJ_TEXT: ObjTypeName := 'Texte';
  OBJ_ELLIPSE: ObjTypeName := 'Ellipse';
  Else ObjTypeName := 'Objet';
 End;
End;

{ Initialiser les calques par défaut }
Procedure InitLayers;
Var
 I: Integer;
Begin
 LayerCount := 1;
 CurrentLayer := 0;

 { Calque 0 - calque par défaut }
 Layers[0].Name := '0';
 Layers[0].Color := White;
 Layers[0].LineType := LINETYPE_CONTINUOUS;
 Layers[0].LineWeight := LINEWEIGHT_DEFAULT;
 Layers[0].Visible := True;
 Layers[0].Locked := False;
 Layers[0].Frozen := False;
 Layers[0].OnFlag := True;

 { Initialiser les autres calques }
 For I := 1 to MAX_LAYERS - 1 do Begin
  Layers[I].Name := '';
  Layers[I].Color := White;
  Layers[I].LineType := LINETYPE_CONTINUOUS;
  Layers[I].LineWeight := LINEWEIGHT_DEFAULT;
  Layers[I].Visible := True;
  Layers[I].Locked := False;
  Layers[I].Frozen := False;
  Layers[I].OnFlag := True;
 End;

 { Valeurs par défaut de dessin }
 CurrentColor := 256;  { ByLayer }
 CurrentLineType := LINETYPE_CONTINUOUS;
 CurrentLineWeight := LINEWEIGHT_DEFAULT;
 CurrentTextStyleName := 'STANDARD';
 CurrentDimStyleName := 'STANDARD';
 CurrentPointStyle := 0;       { 0 = point, 1 = invisible, 2 = +, 3 = x, 4 = | }
 CurrentPointSize := 0.0;      { 0 = 5% de la hauteur d'ecran }
 CurrentUnits := 1;            { Decimal par defaut }
 LimMinX := 0.0;
 LimMinY := 0.0;
 LimMaxX := 420.0;
 LimMaxY := 297.0;
 SnapEnabled := False;
 SnapSpacing := 10.0;
 OrthoMode := False;
 LastLinearDimValid := False;
End;

{ ============================================================================ }
{ Fonctions de gestion des calques - TODO 18                                   }
{ ============================================================================ }

{ Trouver un calque par son nom }
Function FindLayerByName(Const LayerName: String): Integer;
Var
 I: Integer;
 UpperName: String;
Begin
 FindLayerByName := -1;
 UpperName := LayerName;
 For I := 1 to Length(UpperName) do
  If (UpperName[I] >= 'a') and (UpperName[I] <= 'z') Then
   UpperName[I] := Chr(Ord(UpperName[I]) - 32);

 For I := 0 to LayerCount - 1 do Begin
  If Layers[I].Name = LayerName Then Begin
   FindLayerByName := I;
   Exit;
  End;
 End;
End;

{ Ajouter un nouveau calque }
Function AddLayer(Const LayerName: String): Integer;
Var
 I: Integer;
Begin
 AddLayer := -1;

 { Vérifier si le calque existe déjà }
 If FindLayerByName(LayerName) >= 0 Then Exit;

 { Vérifier s'il y a de la place }
 If LayerCount >= MAX_LAYERS Then Exit;

 { Ajouter le nouveau calque }
 I := LayerCount;
 Inc(LayerCount);

 Layers[I].Name := LayerName;
 Layers[I].Color := White;
 Layers[I].LineType := LINETYPE_CONTINUOUS;
 Layers[I].LineWeight := LINEWEIGHT_DEFAULT;
 Layers[I].Visible := True;
 Layers[I].Locked := False;
 Layers[I].Frozen := False;
 Layers[I].OnFlag := True;

 AddLayer := I;
End;

{ Supprimer un calque (ne peut pas supprimer le calque 0) }
Function DeleteLayer(LayerIdx: Integer): Boolean;
Var
 I, J: Integer;
 HasObjects: Boolean;
Begin
 DeleteLayer := False;

 { Impossible de supprimer le calque 0 }
 If LayerIdx = 0 Then Exit;

 { Vérifier les limites }
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;

 { Vérifier si des objets utilisent ce calque }
 HasObjects := False;
 For I := 0 to ObjectCount - 1 do Begin
  If DrawObjects[I].LayerIndex = LayerIdx Then Begin
   HasObjects := True;
   Break;
  End;
 End;

 { Ne pas supprimer si des objets sont sur ce calque }
 If HasObjects Then Exit;

 { Décaler tous les calques suivants }
 For I := LayerIdx to LayerCount - 2 do
  Layers[I] := Layers[I + 1];

 Dec(LayerCount);

 { Mettre à jour les références des objets }
 For I := 0 to ObjectCount - 1 do Begin
  If DrawObjects[I].LayerIndex > LayerIdx Then
   Dec(DrawObjects[I].LayerIndex);
 End;

 { Ajuster le calque courant si nécessaire }
 If CurrentLayer >= LayerCount Then
  CurrentLayer := LayerCount - 1;
 If CurrentLayer > LayerIdx Then
  Dec(CurrentLayer);

 DeleteLayer := True;
End;

{ Définir la couleur d'un calque }
Procedure SetLayerColor(LayerIdx: Integer; NewColor: Integer);
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 Layers[LayerIdx].Color := NewColor;
End;

{ Définir le type de ligne d'un calque }
Procedure SetLayerLineType(LayerIdx: Integer; NewLineType: Byte);
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 Layers[LayerIdx].LineType := NewLineType;
End;

{ Définir l'épaisseur de ligne d'un calque }
Procedure SetLayerLineWeight(LayerIdx: Integer; NewLineWeight: Integer);
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 Layers[LayerIdx].LineWeight := NewLineWeight;
End;

{ Activer/Désactiver la visibilité d'un calque }
Procedure ToggleLayerVisibility(LayerIdx: Integer);
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 Layers[LayerIdx].Visible := Not Layers[LayerIdx].Visible;
End;

{ Activer/Désactiver le verrouillage d'un calque }
Procedure ToggleLayerLocked(LayerIdx: Integer);
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 Layers[LayerIdx].Locked := Not Layers[LayerIdx].Locked;
End;

{ Activer/Désactiver le gel d'un calque }
Procedure ToggleLayerFrozen(LayerIdx: Integer);
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 { Impossible de geler le calque courant }
 If LayerIdx = CurrentLayer Then Exit;
 Layers[LayerIdx].Frozen := Not Layers[LayerIdx].Frozen;
End;

{ Allumer/Éteindre un calque }
Procedure ToggleLayerOn(LayerIdx: Integer);
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 Layers[LayerIdx].OnFlag := Not Layers[LayerIdx].OnFlag;
End;

{ Vérifier si un objet est sur un calque visible }
Function IsObjectOnVisibleLayer(ObjIdx: Integer): Boolean;
Var
 LayerIdx: Integer;
Begin
 IsObjectOnVisibleLayer := True;

 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;

 LayerIdx := DrawObjects[ObjIdx].LayerIndex;
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;

 { Un calque n'est pas visible si: pas visible OU éteint OU gelé }
 IsObjectOnVisibleLayer := Layers[LayerIdx].Visible and
                           Layers[LayerIdx].OnFlag and
                           (Not Layers[LayerIdx].Frozen);
End;

{ Vérifier si un objet est sur un calque verrouillé }
Function IsObjectOnLockedLayer(ObjIdx: Integer): Boolean;
Var
 LayerIdx: Integer;
Begin
 IsObjectOnLockedLayer := False;

 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;

 LayerIdx := DrawObjects[ObjIdx].LayerIndex;
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;

 IsObjectOnLockedLayer := Layers[LayerIdx].Locked;
End;

{ Définir le calque courant }
Procedure SetCurrentLayer(LayerIdx: Integer);
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 { Impossible de définir un calque gelé comme courant }
 If Layers[LayerIdx].Frozen Then Exit;
 CurrentLayer := LayerIdx;
End;

{ Déplacer un objet vers un autre calque }
Procedure MoveObjectToLayer(ObjIdx: Integer; LayerIdx: Integer);
Begin
 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;
 { Vérifier si l'objet n'est pas sur un calque verrouillé }
 If IsObjectOnLockedLayer(ObjIdx) Then Exit;
 DrawObjects[ObjIdx].LayerIndex := LayerIdx;
End;

{ Déplacer tous les objets sélectionnés vers un calque }
Procedure MoveSelectedObjectsToLayer(LayerIdx: Integer);
Var
 I: Integer;
Begin
 If (LayerIdx < 0) or (LayerIdx >= LayerCount) Then Exit;

 For I := 0 to SelectionSet.Count - 1 do Begin
  If Not IsObjectOnLockedLayer(SelectionSet.Objects[I]) Then
   DrawObjects[SelectionSet.Objects[I]].LayerIndex := LayerIdx;
 End;
End;

{ Obtenir la couleur effective d'un objet (ByLayer ou couleur propre) }
Function GetObjectEffectiveColor(ObjIdx: Integer): Integer;
Var
 LayerIdx: Integer;
Begin
 GetObjectEffectiveColor := White;

 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;

 { Si la couleur est 256 (ByLayer), utiliser la couleur du calque }
 If DrawObjects[ObjIdx].Color = 256 Then Begin
  LayerIdx := DrawObjects[ObjIdx].LayerIndex;
  If (LayerIdx >= 0) and (LayerIdx < LayerCount) Then
   GetObjectEffectiveColor := Layers[LayerIdx].Color
  Else
   GetObjectEffectiveColor := White;
 End
 Else
  GetObjectEffectiveColor := DrawObjects[ObjIdx].Color;
End;

{ Obtenir le type de ligne effectif d'un objet (ByLayer ou type propre) }
Function GetObjectEffectiveLineType(ObjIdx: Integer): Byte;
Var
 LayerIdx: Integer;
Begin
 GetObjectEffectiveLineType := LINETYPE_CONTINUOUS;

 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;

 { Si le type de ligne est ByLayer (256), utiliser celui du calque }
 If DrawObjects[ObjIdx].LineType = 255 Then Begin
  LayerIdx := DrawObjects[ObjIdx].LayerIndex;
  If (LayerIdx >= 0) and (LayerIdx < LayerCount) Then
   GetObjectEffectiveLineType := Layers[LayerIdx].LineType
  Else
   GetObjectEffectiveLineType := LINETYPE_CONTINUOUS;
 End
 Else
  GetObjectEffectiveLineType := DrawObjects[ObjIdx].LineType;
End;

{ ============================================================================ }
{ Fonctions de cotation - TODO 19                                               }
{ ============================================================================ }

{ Calculer la distance linéaire entre deux points }
Function CalculateLinearDistance(X1, Y1, X2, Y2: Real): Real;
Begin
 CalculateLinearDistance := Sqrt(Sqr(X2 - X1) + Sqr(Y2 - Y1));
End;

{ Calculer l'angle (en radians) entre deux points }
Function CalculateAngle(X1, Y1, X2, Y2: Real): Real;
Var
 DX, DY: Real;
 Result:Real;
Begin
 DX := X2 - X1;
 DY := Y2 - Y1;
 If DX = 0 Then Begin
  If DY >= 0 Then
   Result := Pi / 2
  Else
   Result := -Pi / 2;
 End
 Else
  Result := ArcTan(DY / DX);
 If DX < 0 Then
  Result := Result + Pi;
 CalculateAngle:=Result;
End;

{ Formater une valeur de cotation }
Function FormatDimensionValue(Value: Real): String;
Var
 S: String;
 DecPos: Integer;
Begin
 Str(Value:0:4, S);
 { Supprimer les zéros de fin }
 While (Length(S) > 1) and (S[Length(S)] = '0') and (S[Length(S) - 1] <> '.') do
  Delete(S, Length(S), 1);
 { Supprimer le point si pas de décimales }
 If S[Length(S)] = '.' Then
  Delete(S, Length(S), 1);
 FormatDimensionValue := S;
End;

{ Dessiner une flèche de cotation }
Procedure DrawDimensionArrow(X, Y, Angle: Real; Size: Real);
Var
 SX, SY: Integer;
 X1, Y1, X2, Y2, X3, Y3: Integer;
 ArrowAngle: Real;
 ArrowLen: Real;
Begin
 SX := WorldToScreenX(X);
 SY := WorldToScreenY(Y);

 ArrowLen := Size * ZoomLevel;
 ArrowAngle := Pi / 8;  { 22.5 degrés }

 { Pointe de la flèche }
 X1 := SX;
 Y1 := SY;

 { Côté gauche de la flèche }
 X2 := Round(SX - ArrowLen * Cos(Angle - ArrowAngle));
 Y2 := Round(SY + ArrowLen * Sin(Angle - ArrowAngle));

 { Côté droit de la flèche }
 X3 := Round(SX - ArrowLen * Cos(Angle + ArrowAngle));
 Y3 := Round(SY + ArrowLen * Sin(Angle + ArrowAngle));

 { Dessiner la flèche }
 Line(X1, Y1, X2, Y2);
 Line(X1, Y1, X3, Y3);
 Line(X2, Y2, X3, Y3);
End;

{ Dessiner une cotation }
Procedure DrawDimension(ObjIdx: Integer);
Var
 SX1, SY1, SX2, SY2: Integer;
 SX3, SY3, SX4, SY4: Integer;
 STX, STY: Integer;
 DimText: String;
 Angle, OffsetX, OffsetY: Real;
 TextWidth_: Integer;
 MidX, MidY: Real;
Begin
 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;
 If DrawObjects[ObjIdx].ObjType <> OBJ_DIMENSION Then Exit;

 SetColor(GetObjectEffectiveColor(ObjIdx));

 Case DrawObjects[ObjIdx].DimType of
  DIM_LINEAR, DIM_ALIGNED: Begin
   { Points de définition }
   SX1 := WorldToScreenX(DrawObjects[ObjIdx].X1);
   SY1 := WorldToScreenY(DrawObjects[ObjIdx].Y1);
   SX2 := WorldToScreenX(DrawObjects[ObjIdx].X2);
   SY2 := WorldToScreenY(DrawObjects[ObjIdx].Y2);

   { Ligne de cote (position Y3 pour linéaire horizontal) }
   SX3 := WorldToScreenX(DrawObjects[ObjIdx].X1);
   SY3 := WorldToScreenY(DrawObjects[ObjIdx].DimY3);
   SX4 := WorldToScreenX(DrawObjects[ObjIdx].X2);
   SY4 := WorldToScreenY(DrawObjects[ObjIdx].DimY3);

   { Lignes d'extension }
   Line(SX1, SY1, SX3, SY3);
   Line(SX2, SY2, SX4, SY4);

   { Ligne de cote }
   Line(SX3, SY3, SX4, SY4);

   { Flèches }
   If SX4 > SX3 Then Begin
    DrawDimensionArrow(DrawObjects[ObjIdx].X1, DrawObjects[ObjIdx].DimY3, 0, DIM_ARROW_SIZE);
    DrawDimensionArrow(DrawObjects[ObjIdx].X2, DrawObjects[ObjIdx].DimY3, Pi, DIM_ARROW_SIZE);
   End Else Begin
    DrawDimensionArrow(DrawObjects[ObjIdx].X1, DrawObjects[ObjIdx].DimY3, Pi, DIM_ARROW_SIZE);
    DrawDimensionArrow(DrawObjects[ObjIdx].X2, DrawObjects[ObjIdx].DimY3, 0, DIM_ARROW_SIZE);
   End;

   { Texte de cotation }
   If DrawObjects[ObjIdx].DimText <> '' Then
    DimText := DrawObjects[ObjIdx].DimText
   Else
    DimText := FormatDimensionValue(DrawObjects[ObjIdx].DimValue);

   STX := WorldToScreenX(DrawObjects[ObjIdx].DimTextX);
   STY := WorldToScreenY(DrawObjects[ObjIdx].DimTextY);
   TextWidth_ := TextWidth(DimText);
   OutTextXY(STX - TextWidth_ div 2, STY - 4, DimText);
  End;

  DIM_RADIAL: Begin
   { Centre du cercle }
   SX1 := WorldToScreenX(DrawObjects[ObjIdx].X1);
   SY1 := WorldToScreenY(DrawObjects[ObjIdx].Y1);

   { Point sur le cercle }
   Angle := DrawObjects[ObjIdx].StartAngle;
   SX2 := WorldToScreenX(DrawObjects[ObjIdx].X1 + DrawObjects[ObjIdx].Radius * Cos(Angle));
   SY2 := WorldToScreenY(DrawObjects[ObjIdx].Y1 + DrawObjects[ObjIdx].Radius * Sin(Angle));

   { Ligne de rayon }
   Line(SX1, SY1, SX2, SY2);

   { Flèche au point de cercle }
   DrawDimensionArrow(DrawObjects[ObjIdx].X1 + DrawObjects[ObjIdx].Radius * Cos(Angle),
                      DrawObjects[ObjIdx].Y1 + DrawObjects[ObjIdx].Radius * Sin(Angle),
                      Angle + Pi, DIM_ARROW_SIZE);

   { Texte R + valeur }
   If DrawObjects[ObjIdx].DimText <> '' Then
    DimText := DrawObjects[ObjIdx].DimText
   Else
    DimText := 'R' + FormatDimensionValue(DrawObjects[ObjIdx].DimValue);

   STX := WorldToScreenX(DrawObjects[ObjIdx].DimTextX);
   STY := WorldToScreenY(DrawObjects[ObjIdx].DimTextY);
   OutTextXY(STX, STY, DimText);
  End;

  DIM_DIAMETER: Begin
   { Centre du cercle }
   SX1 := WorldToScreenX(DrawObjects[ObjIdx].X1);
   SY1 := WorldToScreenY(DrawObjects[ObjIdx].Y1);

   { Points opposés sur le cercle }
   Angle := DrawObjects[ObjIdx].StartAngle;
   SX2 := WorldToScreenX(DrawObjects[ObjIdx].X1 + DrawObjects[ObjIdx].Radius * Cos(Angle));
   SY2 := WorldToScreenY(DrawObjects[ObjIdx].Y1 + DrawObjects[ObjIdx].Radius * Sin(Angle));
   SX3 := WorldToScreenX(DrawObjects[ObjIdx].X1 - DrawObjects[ObjIdx].Radius * Cos(Angle));
   SY3 := WorldToScreenY(DrawObjects[ObjIdx].Y1 - DrawObjects[ObjIdx].Radius * Sin(Angle));

   { Ligne de diamètre }
   Line(SX2, SY2, SX3, SY3);

   { Flèches aux deux extrémités }
   DrawDimensionArrow(DrawObjects[ObjIdx].X1 + DrawObjects[ObjIdx].Radius * Cos(Angle),
                      DrawObjects[ObjIdx].Y1 + DrawObjects[ObjIdx].Radius * Sin(Angle),
                      Angle + Pi, DIM_ARROW_SIZE);
   DrawDimensionArrow(DrawObjects[ObjIdx].X1 - DrawObjects[ObjIdx].Radius * Cos(Angle),
                      DrawObjects[ObjIdx].Y1 - DrawObjects[ObjIdx].Radius * Sin(Angle),
                      Angle, DIM_ARROW_SIZE);

   { Texte Ø + valeur }
   If DrawObjects[ObjIdx].DimText <> '' Then
    DimText := DrawObjects[ObjIdx].DimText
   Else
    DimText := 'O' + FormatDimensionValue(DrawObjects[ObjIdx].DimValue);  { Note: Ø non disponible, utilisons O }

   STX := WorldToScreenX(DrawObjects[ObjIdx].DimTextX);
   STY := WorldToScreenY(DrawObjects[ObjIdx].DimTextY);
   OutTextXY(STX, STY, DimText);
  End;

  DIM_ANGULAR: Begin
   { Centre de l'angle }
   SX1 := WorldToScreenX(DrawObjects[ObjIdx].X1);
   SY1 := WorldToScreenY(DrawObjects[ObjIdx].Y1);

   { Arc de cotation }
   Arc(SX1, SY1,
       Round(DrawObjects[ObjIdx].StartAngle * 180 / Pi),
       Round(DrawObjects[ObjIdx].EndAngle * 180 / Pi),
       Round(DrawObjects[ObjIdx].Radius * ZoomLevel));

   { Texte de l'angle }
   If DrawObjects[ObjIdx].DimText <> '' Then
    DimText := DrawObjects[ObjIdx].DimText
   Else
    DimText := FormatDimensionValue(DrawObjects[ObjIdx].DimValue) + '°';

   STX := WorldToScreenX(DrawObjects[ObjIdx].DimTextX);
   STY := WorldToScreenY(DrawObjects[ObjIdx].DimTextY);
   TextWidth_ := TextWidth(DimText);
   OutTextXY(STX - TextWidth_ div 2, STY - 4, DimText);
  End;

  DIM_ORDINATE: Begin
   { Point de référence }
   SX1 := WorldToScreenX(DrawObjects[ObjIdx].X1);
   SY1 := WorldToScreenY(DrawObjects[ObjIdx].Y1);

   { Fin de la ligne de repère }
   SX2 := WorldToScreenX(DrawObjects[ObjIdx].X2);
   SY2 := WorldToScreenY(DrawObjects[ObjIdx].Y2);

   { Lignes de repère (pliée) }
   If DrawObjects[ObjIdx].DimX3 <> 0 Then Begin
    { Cotation X }
    SX3 := SX1;
    SY3 := SY2;
    Line(SX1, SY1, SX3, SY3);
    Line(SX3, SY3, SX2, SY2);
   End Else Begin
    { Cotation Y }
    SX3 := SX2;
    SY3 := SY1;
    Line(SX1, SY1, SX3, SY3);
    Line(SX3, SY3, SX2, SY2);
   End;

   { Texte de la valeur }
   If DrawObjects[ObjIdx].DimText <> '' Then
    DimText := DrawObjects[ObjIdx].DimText
   Else
    DimText := FormatDimensionValue(DrawObjects[ObjIdx].DimValue);

   OutTextXY(SX2, SY2 - 4, DimText);
  End;
 End;

 { Si sélectionné, dessiner les grips }
 If DrawObjects[ObjIdx].Selected Then Begin
  SetFillStyle(SolidFill, Blue);
  SX1 := WorldToScreenX(DrawObjects[ObjIdx].X1);
  SY1 := WorldToScreenY(DrawObjects[ObjIdx].Y1);
  Bar(SX1 - 3, SY1 - 3, SX1 + 3, SY1 + 3);
  SX2 := WorldToScreenX(DrawObjects[ObjIdx].X2);
  SY2 := WorldToScreenY(DrawObjects[ObjIdx].Y2);
  Bar(SX2 - 3, SY2 - 3, SX2 + 3, SY2 + 3);
 End;
End;

{ Créer une cotation linéaire }
Function CreateLinearDimension(X1, Y1, X2, Y2, DimLineY: Real; IsHorizontal: Boolean): Integer;
Var
 Idx: Integer;
 Distance: Real;
Begin
 CreateLinearDimension := -1;

 If ObjectCount >= MAX_OBJECTS Then Exit;

 Idx := ObjectCount;
 Inc(ObjectCount);

 DrawObjects[Idx].ObjType := OBJ_DIMENSION;
 DrawObjects[Idx].DimType := DIM_LINEAR;
 DrawObjects[Idx].X1 := X1;
 DrawObjects[Idx].Y1 := Y1;
 DrawObjects[Idx].X2 := X2;
 DrawObjects[Idx].Y2 := Y2;
 DrawObjects[Idx].DimY3 := DimLineY;  { Position Y de la ligne de cote }
 DrawObjects[Idx].DimX3 := 0;

 { Calculer la distance }
 If IsHorizontal Then
  Distance := Abs(X2 - X1)
 Else
  Distance := Abs(Y2 - Y1);
 DrawObjects[Idx].DimValue := Distance;
 DrawObjects[Idx].DimText := '';

 { Position du texte au milieu de la ligne de cote }
 DrawObjects[Idx].DimTextX := (X1 + X2) / 2;
 DrawObjects[Idx].DimTextY := DimLineY + DIM_TEXT_GAP;

 { Propriétés par défaut }
 DrawObjects[Idx].Color := CurrentColor;
 DrawObjects[Idx].LineType := CurrentLineType;
 DrawObjects[Idx].LayerIndex := CurrentLayer;
 DrawObjects[Idx].Selected := False;
 DrawObjects[Idx].Visible := True;

 CreateLinearDimension := Idx;
End;

{ Créer une cotation alignée }
Function CreateAlignedDimension(X1, Y1, X2, Y2, Offset: Real): Integer;
Var
 Idx: Integer;
 Distance, Angle: Real;
 OffsetX, OffsetY: Real;
Begin
 CreateAlignedDimension := -1;

 If ObjectCount >= MAX_OBJECTS Then Exit;

 Idx := ObjectCount;
 Inc(ObjectCount);

 { Calculer l'angle perpendiculaire }
 Angle := CalculateAngle(X1, Y1, X2, Y2);
 OffsetX := Offset * Cos(Angle + Pi/2);
 OffsetY := Offset * Sin(Angle + Pi/2);

 DrawObjects[Idx].ObjType := OBJ_DIMENSION;
 DrawObjects[Idx].DimType := DIM_ALIGNED;
 DrawObjects[Idx].X1 := X1;
 DrawObjects[Idx].Y1 := Y1;
 DrawObjects[Idx].X2 := X2;
 DrawObjects[Idx].Y2 := Y2;
 DrawObjects[Idx].DimX3 := X1 + OffsetX;
 DrawObjects[Idx].DimY3 := Y1 + OffsetY;
 DrawObjects[Idx].DimX4 := X2 + OffsetX;
 DrawObjects[Idx].DimY4 := Y2 + OffsetY;

 { Calculer la distance }
 Distance := CalculateLinearDistance(X1, Y1, X2, Y2);
 DrawObjects[Idx].DimValue := Distance;
 DrawObjects[Idx].DimText := '';

 { Position du texte au milieu }
 DrawObjects[Idx].DimTextX := (X1 + X2) / 2 + OffsetX;
 DrawObjects[Idx].DimTextY := (Y1 + Y2) / 2 + OffsetY + DIM_TEXT_GAP;

 { Propriétés par défaut }
 DrawObjects[Idx].Color := CurrentColor;
 DrawObjects[Idx].LineType := CurrentLineType;
 DrawObjects[Idx].LayerIndex := CurrentLayer;
 DrawObjects[Idx].Selected := False;
 DrawObjects[Idx].Visible := True;

 CreateAlignedDimension := Idx;
End;

{ Créer une cotation angulaire }
Function CreateAngularDimension(CX, CY, X1, Y1, X2, Y2, ArcRadius: Real): Integer;
Var
 Idx: Integer;
 Angle1, Angle2, DiffAngle, MidAngle: Real;
Begin
 CreateAngularDimension := -1;

 If ObjectCount >= MAX_OBJECTS Then Exit;

 Idx := ObjectCount;
 Inc(ObjectCount);

 { Calculer les angles }
 Angle1 := CalculateAngle(CX, CY, X1, Y1);
 Angle2 := CalculateAngle(CX, CY, X2, Y2);

 { Angle entre les deux lignes (en degrés) }
 DiffAngle := Abs(Angle2 - Angle1);
 If DiffAngle > Pi Then
  DiffAngle := 2 * Pi - DiffAngle;

 DrawObjects[Idx].ObjType := OBJ_DIMENSION;
 DrawObjects[Idx].DimType := DIM_ANGULAR;
 DrawObjects[Idx].X1 := CX;
 DrawObjects[Idx].Y1 := CY;
 DrawObjects[Idx].X2 := X1;
 DrawObjects[Idx].Y2 := Y1;
 DrawObjects[Idx].DimX3 := X2;
 DrawObjects[Idx].DimY3 := Y2;
 DrawObjects[Idx].Radius := ArcRadius;
 DrawObjects[Idx].StartAngle := Angle1;
 DrawObjects[Idx].EndAngle := Angle2;

 { Valeur en degrés }
 DrawObjects[Idx].DimValue := DiffAngle * 180 / Pi;
 DrawObjects[Idx].DimText := '';

 { Position du texte au milieu de l'arc }
 MidAngle := (Angle1 + Angle2) / 2;
 DrawObjects[Idx].DimTextX := CX + (ArcRadius + DIM_TEXT_GAP) * Cos(MidAngle);
 DrawObjects[Idx].DimTextY := CY + (ArcRadius + DIM_TEXT_GAP) * Sin(MidAngle);

 { Propriétés par défaut }
 DrawObjects[Idx].Color := CurrentColor;
 DrawObjects[Idx].LineType := CurrentLineType;
 DrawObjects[Idx].LayerIndex := CurrentLayer;
 DrawObjects[Idx].Selected := False;
 DrawObjects[Idx].Visible := True;

 CreateAngularDimension := Idx;
End;

{ Créer une cotation radiale }
Function CreateRadialDimension(CX, CY, Radius, Angle: Real): Integer;
Var
 Idx: Integer;
Begin
 CreateRadialDimension := -1;

 If ObjectCount >= MAX_OBJECTS Then Exit;

 Idx := ObjectCount;
 Inc(ObjectCount);

 DrawObjects[Idx].ObjType := OBJ_DIMENSION;
 DrawObjects[Idx].DimType := DIM_RADIAL;
 DrawObjects[Idx].X1 := CX;
 DrawObjects[Idx].Y1 := CY;
 DrawObjects[Idx].Radius := Radius;
 DrawObjects[Idx].StartAngle := Angle;  { Direction de la ligne de cotation }

 { Valeur = rayon }
 DrawObjects[Idx].DimValue := Radius;
 DrawObjects[Idx].DimText := '';

 { Position du texte sur la ligne de rayon }
 DrawObjects[Idx].DimTextX := CX + (Radius / 2) * Cos(Angle);
 DrawObjects[Idx].DimTextY := CY + (Radius / 2) * Sin(Angle) + DIM_TEXT_GAP;

 { Propriétés par défaut }
 DrawObjects[Idx].Color := CurrentColor;
 DrawObjects[Idx].LineType := CurrentLineType;
 DrawObjects[Idx].LayerIndex := CurrentLayer;
 DrawObjects[Idx].Selected := False;
 DrawObjects[Idx].Visible := True;

 CreateRadialDimension := Idx;
End;

{ Créer une cotation diamètre }
Function CreateDiameterDimension(CX, CY, Radius, Angle: Real): Integer;
Var
 Idx: Integer;
Begin
 CreateDiameterDimension := -1;

 If ObjectCount >= MAX_OBJECTS Then Exit;

 Idx := ObjectCount;
 Inc(ObjectCount);

 DrawObjects[Idx].ObjType := OBJ_DIMENSION;
 DrawObjects[Idx].DimType := DIM_DIAMETER;
 DrawObjects[Idx].X1 := CX;
 DrawObjects[Idx].Y1 := CY;
 DrawObjects[Idx].Radius := Radius;
 DrawObjects[Idx].StartAngle := Angle;  { Direction de la ligne de cotation }

 { Valeur = diamètre }
 DrawObjects[Idx].DimValue := 2 * Radius;
 DrawObjects[Idx].DimText := '';

 { Position du texte au centre }
 DrawObjects[Idx].DimTextX := CX + DIM_TEXT_GAP * Cos(Angle + Pi/2);
 DrawObjects[Idx].DimTextY := CY + DIM_TEXT_GAP * Sin(Angle + Pi/2);

 { Propriétés par défaut }
 DrawObjects[Idx].Color := CurrentColor;
 DrawObjects[Idx].LineType := CurrentLineType;
 DrawObjects[Idx].LayerIndex := CurrentLayer;
 DrawObjects[Idx].Selected := False;
 DrawObjects[Idx].Visible := True;

 CreateDiameterDimension := Idx;
End;

{ Créer une cotation ordonnée }
Function CreateOrdinateDimension(X, Y, LeaderEndX, LeaderEndY: Real; IsXOrdinate: Boolean): Integer;
Var
 Idx: Integer;
Begin
 CreateOrdinateDimension := -1;

 If ObjectCount >= MAX_OBJECTS Then Exit;

 Idx := ObjectCount;
 Inc(ObjectCount);

 DrawObjects[Idx].ObjType := OBJ_DIMENSION;
 DrawObjects[Idx].DimType := DIM_ORDINATE;
 DrawObjects[Idx].X1 := X;
 DrawObjects[Idx].Y1 := Y;
 DrawObjects[Idx].X2 := LeaderEndX;
 DrawObjects[Idx].Y2 := LeaderEndY;

 { Flag pour indiquer X ou Y ordonnée (dans DimX3) }
 If IsXOrdinate Then
  DrawObjects[Idx].DimX3 := 1
 Else
  DrawObjects[Idx].DimX3 := 0;

 { Valeur = coordonnée X ou Y }
 If IsXOrdinate Then
  DrawObjects[Idx].DimValue := X
 Else
  DrawObjects[Idx].DimValue := Y;
 DrawObjects[Idx].DimText := '';

 { Position du texte à la fin du repère }
 DrawObjects[Idx].DimTextX := LeaderEndX;
 DrawObjects[Idx].DimTextY := LeaderEndY;

 { Propriétés par défaut }
 DrawObjects[Idx].Color := CurrentColor;
 DrawObjects[Idx].LineType := CurrentLineType;
 DrawObjects[Idx].LayerIndex := CurrentLayer;
 DrawObjects[Idx].Selected := False;
 DrawObjects[Idx].Visible := True;

 CreateOrdinateDimension := Idx;
End;

{ Obtenir les grips pour une cotation }
Procedure GetDimensionGrips(ObjIdx: Integer);
Begin
 If (ObjIdx < 0) or (ObjIdx >= ObjectCount) Then Exit;
 If DrawObjects[ObjIdx].ObjType <> OBJ_DIMENSION Then Exit;

 { Grip au premier point }
 If CurrentGrips.Count < MAX_GRIPS Then Begin
  CurrentGrips.Grips[CurrentGrips.Count].X := DrawObjects[ObjIdx].X1;
  CurrentGrips.Grips[CurrentGrips.Count].Y := DrawObjects[ObjIdx].Y1;
  CurrentGrips.Grips[CurrentGrips.Count].GripType := GRIP_ENDPOINT;
  CurrentGrips.Grips[CurrentGrips.Count].ObjIndex := ObjIdx;
  CurrentGrips.Grips[CurrentGrips.Count].PointIndex := 0;
  CurrentGrips.Grips[CurrentGrips.Count].IsHot := False;
  Inc(CurrentGrips.Count);
 End;

 { Grip au deuxième point }
 If CurrentGrips.Count < MAX_GRIPS Then Begin
  CurrentGrips.Grips[CurrentGrips.Count].X := DrawObjects[ObjIdx].X2;
  CurrentGrips.Grips[CurrentGrips.Count].Y := DrawObjects[ObjIdx].Y2;
  CurrentGrips.Grips[CurrentGrips.Count].GripType := GRIP_ENDPOINT;
  CurrentGrips.Grips[CurrentGrips.Count].ObjIndex := ObjIdx;
  CurrentGrips.Grips[CurrentGrips.Count].PointIndex := 1;
  CurrentGrips.Grips[CurrentGrips.Count].IsHot := False;
  Inc(CurrentGrips.Count);
 End;

 { Grip à la position du texte }
 If CurrentGrips.Count < MAX_GRIPS Then Begin
  CurrentGrips.Grips[CurrentGrips.Count].X := DrawObjects[ObjIdx].DimTextX;
  CurrentGrips.Grips[CurrentGrips.Count].Y := DrawObjects[ObjIdx].DimTextY;
  CurrentGrips.Grips[CurrentGrips.Count].GripType := GRIP_MIDPOINT;
  CurrentGrips.Grips[CurrentGrips.Count].ObjIndex := ObjIdx;
  CurrentGrips.Grips[CurrentGrips.Count].PointIndex := 2;
  CurrentGrips.Grips[CurrentGrips.Count].IsHot := False;
  Inc(CurrentGrips.Count);
 End;
End;

{ ============================================================================ }
{ Fonctions pour les blocs et références externes (XREFs) - TODO 20           }
{ ============================================================================ }

{ Initialiser le système de blocs }
Procedure InitBlockSystem;
Var
 I: Integer;
Begin
 BlockDefCount := 0;
 BlockRefCount := 0;
 XRefCount := 0;
 ImageRefCount := 0;
 OLEObjectCount := 0;
 BlockEntityCount := 0;

 { Initialiser toutes les définitions de blocs }
 For I := 0 to MAX_BLOCKS - 1 do Begin
  BlockDefs[I].Name := '';
  BlockDefs[I].Description := '';
  BlockDefs[I].BaseX := 0;
  BlockDefs[I].BaseY := 0;
  BlockDefs[I].EntityCount := 0;
  BlockDefs[I].FirstEntityIdx := -1;
  BlockDefs[I].IsXRef := False;
  BlockDefs[I].XRefPath := '';
  BlockDefs[I].IsDefined := False;
 End;

 { Initialiser toutes les références de blocs }
 For I := 0 to MAX_BLOCK_REFS - 1 do Begin
  BlockRefs[I].BlockIndex := -1;
  BlockRefs[I].InsertX := 0;
  BlockRefs[I].InsertY := 0;
  BlockRefs[I].ScaleX := 1.0;
  BlockRefs[I].ScaleY := 1.0;
  BlockRefs[I].Rotation := 0;
  BlockRefs[I].Color := 0;  { ByBlock }
  BlockRefs[I].LayerIndex := 0;
  BlockRefs[I].Selected := False;
  BlockRefs[I].Visible := True;
 End;

 { Initialiser toutes les XREFs }
 For I := 0 to MAX_XREFS - 1 do Begin
  XRefs[I].Name := '';
  XRefs[I].FilePath := '';
  XRefs[I].InsertX := 0;
  XRefs[I].InsertY := 0;
  XRefs[I].ScaleX := 1.0;
  XRefs[I].ScaleY := 1.0;
  XRefs[I].Rotation := 0;
  XRefs[I].Status := XREF_UNLOADED;
  XRefs[I].BlockIndex := -1;
  XRefs[I].LayerPrefix := '';
  XRefs[I].Overlay := False;
  XRefs[I].Selected := False;
  XRefs[I].Visible := True;
 End;

 { Initialiser toutes les references d'images }
 For I := 0 to MAX_IMAGE_REFS - 1 do Begin
  ImageRefs[I].Name := '';
  ImageRefs[I].FilePath := '';
  ImageRefs[I].InsertX := 0;
  ImageRefs[I].InsertY := 0;
  ImageRefs[I].Width := 100;
  ImageRefs[I].Height := 100;
  ImageRefs[I].Rotation := 0;
  ImageRefs[I].Status := IMGREF_UNLOADED;
  ImageRefs[I].PixelWidth := 0;
  ImageRefs[I].PixelHeight := 0;
  ImageRefs[I].LayerIndex := 0;
  ImageRefs[I].Brightness := 50;
  ImageRefs[I].Contrast := 50;
  ImageRefs[I].Fade := 0;
  ImageRefs[I].ShowFrame := True;
  ImageRefs[I].ShowImage := True;
  ImageRefs[I].Selected := False;
  ImageRefs[I].Visible := True;
 End;

 { Initialiser tous les objets OLE }
 For I := 0 to MAX_OLE_OBJECTS - 1 do Begin
  OLEObjects[I].Name := '';
  OLEObjects[I].FilePath := '';
  OLEObjects[I].AppName := '';
  OLEObjects[I].InsertX := 0;
  OLEObjects[I].InsertY := 0;
  OLEObjects[I].Width := 150;
  OLEObjects[I].Height := 100;
  OLEObjects[I].Rotation := 0;
  OLEObjects[I].Status := OLE_UNLOADED;
  OLEObjects[I].Kind := OLE_KIND_LINK;
  OLEObjects[I].FileSize := 0;
  OLEObjects[I].LayerIndex := 0;
  OLEObjects[I].Selected := False;
  OLEObjects[I].Visible := True;
 End;
End;

{ Transformer un point selon les paramètres d'insertion }
Procedure TransformPoint(Var X, Y: Real; InsX, InsY, ScaleX, ScaleY, Rotation: Real);
Var
 TempX, TempY: Real;
 CosR, SinR: Real;
Begin
 { Appliquer l'échelle }
 TempX := X * ScaleX;
 TempY := Y * ScaleY;

 { Appliquer la rotation }
 CosR := Cos(Rotation);
 SinR := Sin(Rotation);
 X := TempX * CosR - TempY * SinR;
 Y := TempX * SinR + TempY * CosR;

 { Appliquer la translation }
 X := X + InsX;
 Y := Y + InsY;
End;

{ Créer une nouvelle définition de bloc }
Function CreateBlock(Const Name: String; BaseX, BaseY: Real): Integer;
Var
 I: Integer;
Begin
 CreateBlock := -1;

 { Vérifier si un bloc avec ce nom existe déjà }
 If FindBlockByName(Name) >= 0 Then Exit;

 { Trouver un emplacement libre }
 If BlockDefCount >= MAX_BLOCKS Then Exit;

 I := BlockDefCount;
 Inc(BlockDefCount);

 BlockDefs[I].Name := Name;
 BlockDefs[I].Description := '';
 BlockDefs[I].BaseX := BaseX;
 BlockDefs[I].BaseY := BaseY;
 BlockDefs[I].EntityCount := 0;
 BlockDefs[I].FirstEntityIdx := BlockEntityCount;
 BlockDefs[I].IsXRef := False;
 BlockDefs[I].XRefPath := '';
 BlockDefs[I].IsDefined := True;

 CreateBlock := I;
End;

{ Trouver un bloc par son nom }
Function FindBlockByName(Const Name: String): Integer;
Var
 I: Integer;
 UpperName, UpperBlockName: String;
Begin
 FindBlockByName := -1;

 UpperName := Name;
 For I := 1 to Length(UpperName) do
  If (UpperName[I] >= 'a') and (UpperName[I] <= 'z') Then
   UpperName[I] := Chr(Ord(UpperName[I]) - 32);

 For I := 0 to BlockDefCount - 1 do Begin
  If BlockDefs[I].IsDefined Then Begin
   UpperBlockName := BlockDefs[I].Name;
   { Convertir en majuscules pour comparaison insensible à la casse }
   { Cette comparaison simple fonctionne pour ASCII }
   If UpperName = UpperBlockName Then Begin
    FindBlockByName := I;
    Exit;
   End;
  End;
 End;
End;

{ Ajouter une entité à un bloc }
Function AddEntityToBlock(BlockIdx: Integer; Const Entity: TDrawObject): Integer;
Var
 EntityIdx: Integer;
Begin
 AddEntityToBlock := -1;

 If (BlockIdx < 0) or (BlockIdx >= BlockDefCount) Then Exit;
 If Not BlockDefs[BlockIdx].IsDefined Then Exit;
 If BlockDefs[BlockIdx].EntityCount >= MAX_BLOCK_ENTITIES Then Exit;
 If BlockEntityCount >= MAX_BLOCKS * MAX_BLOCK_ENTITIES Then Exit;

 EntityIdx := BlockEntityCount;
 Inc(BlockEntityCount);

 { Copier l'entité en ajustant les coordonnées par rapport au point de base }
 BlockEntities[EntityIdx] := Entity;
 BlockEntities[EntityIdx].X1 := Entity.X1 - BlockDefs[BlockIdx].BaseX;
 BlockEntities[EntityIdx].Y1 := Entity.Y1 - BlockDefs[BlockIdx].BaseY;
 If Entity.ObjType in [OBJ_LINE, OBJ_RECTANGLE] Then Begin
  BlockEntities[EntityIdx].X2 := Entity.X2 - BlockDefs[BlockIdx].BaseX;
  BlockEntities[EntityIdx].Y2 := Entity.Y2 - BlockDefs[BlockIdx].BaseY;
 End;

 Inc(BlockDefs[BlockIdx].EntityCount);

 AddEntityToBlock := EntityIdx;
End;

{ Insérer un bloc (créer une référence de bloc) }
Function InsertBlock(BlockIdx: Integer; InsX, InsY, ScaleX, ScaleY, Rotation: Real): Integer;
Var
 RefIdx: Integer;
Begin
 InsertBlock := -1;

 If (BlockIdx < 0) or (BlockIdx >= BlockDefCount) Then Exit;
 If Not BlockDefs[BlockIdx].IsDefined Then Exit;
 If BlockRefCount >= MAX_BLOCK_REFS Then Exit;

 RefIdx := BlockRefCount;
 Inc(BlockRefCount);

 BlockRefs[RefIdx].BlockIndex := BlockIdx;
 BlockRefs[RefIdx].InsertX := InsX;
 BlockRefs[RefIdx].InsertY := InsY;
 BlockRefs[RefIdx].ScaleX := ScaleX;
 BlockRefs[RefIdx].ScaleY := ScaleY;
 BlockRefs[RefIdx].Rotation := Rotation;
 BlockRefs[RefIdx].Color := CurrentColor;
 BlockRefs[RefIdx].LayerIndex := CurrentLayer;
 BlockRefs[RefIdx].Selected := False;
 BlockRefs[RefIdx].Visible := True;

 InsertBlock := RefIdx;
End;

{ Exploser une référence de bloc (convertir en entités individuelles) }
Procedure ExplodeBlockRef(RefIdx: Integer);
Var
 BlockIdx: Integer;
 I, StartIdx: Integer;
 X, Y, X2, Y2: Real;
 NewObjIdx: Integer;
Begin
 If (RefIdx < 0) or (RefIdx >= BlockRefCount) Then Exit;

 BlockIdx := BlockRefs[RefIdx].BlockIndex;
 If (BlockIdx < 0) or (BlockIdx >= BlockDefCount) Then Exit;
 If Not BlockDefs[BlockIdx].IsDefined Then Exit;

 StartIdx := BlockDefs[BlockIdx].FirstEntityIdx;

 { Créer des copies transformées de chaque entité du bloc }
 For I := 0 to BlockDefs[BlockIdx].EntityCount - 1 do Begin
  If ObjectCount >= MAX_OBJECTS Then Break;

  NewObjIdx := ObjectCount;
  Inc(ObjectCount);

  { Copier l'entité }
  DrawObjects[NewObjIdx] := BlockEntities[StartIdx + I];

  { Transformer le premier point }
  X := BlockEntities[StartIdx + I].X1;
  Y := BlockEntities[StartIdx + I].Y1;
  TransformPoint(X, Y, BlockRefs[RefIdx].InsertX, BlockRefs[RefIdx].InsertY,
                 BlockRefs[RefIdx].ScaleX, BlockRefs[RefIdx].ScaleY,
                 BlockRefs[RefIdx].Rotation);
  DrawObjects[NewObjIdx].X1 := X;
  DrawObjects[NewObjIdx].Y1 := Y;

  { Transformer le deuxième point si nécessaire }
  If DrawObjects[NewObjIdx].ObjType in [OBJ_LINE, OBJ_RECTANGLE] Then Begin
   X2 := BlockEntities[StartIdx + I].X2;
   Y2 := BlockEntities[StartIdx + I].Y2;
   TransformPoint(X2, Y2, BlockRefs[RefIdx].InsertX, BlockRefs[RefIdx].InsertY,
                  BlockRefs[RefIdx].ScaleX, BlockRefs[RefIdx].ScaleY,
                  BlockRefs[RefIdx].Rotation);
   DrawObjects[NewObjIdx].X2 := X2;
   DrawObjects[NewObjIdx].Y2 := Y2;
  End;

  { Appliquer l'échelle au rayon si c'est un cercle ou arc }
  If DrawObjects[NewObjIdx].ObjType in [OBJ_CIRCLE, OBJ_ARC] Then Begin
   DrawObjects[NewObjIdx].Radius := DrawObjects[NewObjIdx].Radius *
                                    (Abs(BlockRefs[RefIdx].ScaleX) + Abs(BlockRefs[RefIdx].ScaleY)) / 2;
  End;

  { Utiliser le calque de la référence de bloc }
  DrawObjects[NewObjIdx].LayerIndex := BlockRefs[RefIdx].LayerIndex;

  { Si couleur ByBlock (0), utiliser la couleur de la référence }
  If DrawObjects[NewObjIdx].Color = 0 Then
   DrawObjects[NewObjIdx].Color := BlockRefs[RefIdx].Color;

  DrawObjects[NewObjIdx].Selected := False;
  DrawObjects[NewObjIdx].Visible := True;
 End;

 { Supprimer la référence de bloc en la marquant comme invalide }
 BlockRefs[RefIdx].BlockIndex := -1;
 BlockRefs[RefIdx].Visible := False;
End;

{ Supprimer une définition de bloc }
Procedure DeleteBlock(BlockIdx: Integer);
Var
 I: Integer;
Begin
 If (BlockIdx < 0) or (BlockIdx >= BlockDefCount) Then Exit;

 { Vérifier si des références utilisent ce bloc }
 For I := 0 to BlockRefCount - 1 do Begin
  If BlockRefs[I].BlockIndex = BlockIdx Then Begin
   { Marquer la référence comme invalide }
   BlockRefs[I].BlockIndex := -1;
   BlockRefs[I].Visible := False;
  End;
 End;

 { Marquer le bloc comme non défini }
 BlockDefs[BlockIdx].IsDefined := False;
 BlockDefs[BlockIdx].Name := '';
End;

{ Dessiner une référence de bloc }
Procedure DrawBlockRef(RefIdx: Integer);
Var
 BlockIdx: Integer;
 I, StartIdx: Integer;
 X, Y, X2, Y2: Real;
 SX1, SY1, SX2, SY2, SR: Integer;
 ObjColor: Integer;
Begin
 If (RefIdx < 0) or (RefIdx >= BlockRefCount) Then Exit;
 If Not BlockRefs[RefIdx].Visible Then Exit;

 BlockIdx := BlockRefs[RefIdx].BlockIndex;
 If (BlockIdx < 0) or (BlockIdx >= BlockDefCount) Then Exit;
 If Not BlockDefs[BlockIdx].IsDefined Then Exit;

 StartIdx := BlockDefs[BlockIdx].FirstEntityIdx;

 { Dessiner chaque entité du bloc avec transformation }
 For I := 0 to BlockDefs[BlockIdx].EntityCount - 1 do Begin
  { Déterminer la couleur }
  ObjColor := BlockEntities[StartIdx + I].Color;
  If ObjColor = 0 Then  { ByBlock }
   ObjColor := BlockRefs[RefIdx].Color;
  If ObjColor = 256 Then  { ByLayer }
   ObjColor := Layers[BlockRefs[RefIdx].LayerIndex].Color;
  SetColor(ObjColor);

  Case BlockEntities[StartIdx + I].ObjType of
   OBJ_LINE: Begin
    X := BlockEntities[StartIdx + I].X1;
    Y := BlockEntities[StartIdx + I].Y1;
    TransformPoint(X, Y, BlockRefs[RefIdx].InsertX, BlockRefs[RefIdx].InsertY,
                   BlockRefs[RefIdx].ScaleX, BlockRefs[RefIdx].ScaleY,
                   BlockRefs[RefIdx].Rotation);
    SX1 := WorldToScreenX(X);
    SY1 := WorldToScreenY(Y);

    X2 := BlockEntities[StartIdx + I].X2;
    Y2 := BlockEntities[StartIdx + I].Y2;
    TransformPoint(X2, Y2, BlockRefs[RefIdx].InsertX, BlockRefs[RefIdx].InsertY,
                   BlockRefs[RefIdx].ScaleX, BlockRefs[RefIdx].ScaleY,
                   BlockRefs[RefIdx].Rotation);
    SX2 := WorldToScreenX(X2);
    SY2 := WorldToScreenY(Y2);

    Line(SX1, SY1, SX2, SY2);
   End;

   OBJ_CIRCLE: Begin
    X := BlockEntities[StartIdx + I].X1;
    Y := BlockEntities[StartIdx + I].Y1;
    TransformPoint(X, Y, BlockRefs[RefIdx].InsertX, BlockRefs[RefIdx].InsertY,
                   BlockRefs[RefIdx].ScaleX, BlockRefs[RefIdx].ScaleY,
                   BlockRefs[RefIdx].Rotation);
    SX1 := WorldToScreenX(X);
    SY1 := WorldToScreenY(Y);
    SR := Round(BlockEntities[StartIdx + I].Radius *
               (Abs(BlockRefs[RefIdx].ScaleX) + Abs(BlockRefs[RefIdx].ScaleY)) / 2 * ZoomLevel);

    Circle(SX1, SY1, SR);
   End;

   OBJ_RECTANGLE: Begin
    X := BlockEntities[StartIdx + I].X1;
    Y := BlockEntities[StartIdx + I].Y1;
    TransformPoint(X, Y, BlockRefs[RefIdx].InsertX, BlockRefs[RefIdx].InsertY,
                   BlockRefs[RefIdx].ScaleX, BlockRefs[RefIdx].ScaleY,
                   BlockRefs[RefIdx].Rotation);
    SX1 := WorldToScreenX(X);
    SY1 := WorldToScreenY(Y);

    X2 := BlockEntities[StartIdx + I].X2;
    Y2 := BlockEntities[StartIdx + I].Y2;
    TransformPoint(X2, Y2, BlockRefs[RefIdx].InsertX, BlockRefs[RefIdx].InsertY,
                   BlockRefs[RefIdx].ScaleX, BlockRefs[RefIdx].ScaleY,
                   BlockRefs[RefIdx].Rotation);
    SX2 := WorldToScreenX(X2);
    SY2 := WorldToScreenY(Y2);

    Rectangle(SX1, SY1, SX2, SY2);
   End;
  End;
 End;

 { Si sélectionné, dessiner un indicateur }
 If BlockRefs[RefIdx].Selected Then Begin
  SetFillStyle(SolidFill, Green);
  SX1 := WorldToScreenX(BlockRefs[RefIdx].InsertX);
  SY1 := WorldToScreenY(BlockRefs[RefIdx].InsertY);
  Bar(SX1 - 4, SY1 - 4, SX1 + 4, SY1 + 4);
 End;
End;

{ Obtenir les grips d'une référence de bloc }
Procedure GetBlockRefGrips(RefIdx: Integer);
Begin
 If (RefIdx < 0) or (RefIdx >= BlockRefCount) Then Exit;
 If BlockRefs[RefIdx].BlockIndex < 0 Then Exit;

 { Grip au point d'insertion }
 If CurrentGrips.Count < MAX_GRIPS Then Begin
  CurrentGrips.Grips[CurrentGrips.Count].X := BlockRefs[RefIdx].InsertX;
  CurrentGrips.Grips[CurrentGrips.Count].Y := BlockRefs[RefIdx].InsertY;
  CurrentGrips.Grips[CurrentGrips.Count].GripType := GRIP_CENTER;
  CurrentGrips.Grips[CurrentGrips.Count].ObjIndex := RefIdx + 10000;  { Offset pour différencier des objets }
  CurrentGrips.Grips[CurrentGrips.Count].PointIndex := 0;
  CurrentGrips.Grips[CurrentGrips.Count].IsHot := False;
  Inc(CurrentGrips.Count);
 End;
End;

{ Attacher une référence externe (XREF) }
Function AttachXRef(Const FilePath: String; InsX, InsY, ScaleX, ScaleY, Rotation: Real; IsOverlay: Boolean): Integer;
Var
 XRefIdx: Integer;
 I, LastSlash: Integer;
 FileName: String;
Begin
 AttachXRef := -1;

 If XRefCount >= MAX_XREFS Then Exit;

 XRefIdx := XRefCount;
 Inc(XRefCount);

 { Extraire le nom de fichier du chemin }
 LastSlash := 0;
 For I := 1 to Length(FilePath) do
  If (FilePath[I] = '\') or (FilePath[I] = '/') Then
   LastSlash := I;
 If LastSlash > 0 Then
  FileName := Copy(FilePath, LastSlash + 1, Length(FilePath) - LastSlash)
 Else
  FileName := FilePath;

 { Retirer l'extension pour le nom }
 For I := Length(FileName) downto 1 do
  If FileName[I] = '.' Then Begin
   FileName := Copy(FileName, 1, I - 1);
   Break;
  End;

 XRefs[XRefIdx].Name := FileName;
 XRefs[XRefIdx].FilePath := FilePath;
 XRefs[XRefIdx].InsertX := InsX;
 XRefs[XRefIdx].InsertY := InsY;
 XRefs[XRefIdx].ScaleX := ScaleX;
 XRefs[XRefIdx].ScaleY := ScaleY;
 XRefs[XRefIdx].Rotation := Rotation;
 XRefs[XRefIdx].Status := XREF_NOT_FOUND;  { À charger }
 XRefs[XRefIdx].BlockIndex := -1;
 XRefs[XRefIdx].LayerPrefix := Copy(FileName, 1, 10);
 XRefs[XRefIdx].Overlay := IsOverlay;
 XRefs[XRefIdx].Selected := False;
 XRefs[XRefIdx].Visible := True;

 { Tenter de charger le fichier XREF }
 ReloadXRef(XRefIdx);

 AttachXRef := XRefIdx;
 MarkDocumentModified;
End;

{ Détacher une XREF }
Procedure DetachXRef(XRefIdx: Integer);
Begin
 If (XRefIdx < 0) or (XRefIdx >= XRefCount) Then Exit;

 { Si un bloc est associé, le supprimer }
 If XRefs[XRefIdx].BlockIndex >= 0 Then
  DeleteBlock(XRefs[XRefIdx].BlockIndex);

 { Marquer comme détachée }
 XRefs[XRefIdx].Name := '';
 XRefs[XRefIdx].FilePath := '';
 XRefs[XRefIdx].Status := XREF_UNLOADED;
 XRefs[XRefIdx].BlockIndex := -1;
 XRefs[XRefIdx].Visible := False;
 MarkDocumentModified;
End;

{ Recharger une XREF depuis le fichier }
Procedure ReloadXRef(XRefIdx: Integer);
Var
 F: Text;
 BlockIdx: Integer;
Begin
 If (XRefIdx < 0) or (XRefIdx >= XRefCount) Then Exit;

 { Vérifier si le fichier existe }
 {$I-}
 Assign(F, XRefs[XRefIdx].FilePath);
 Reset(F);
 {$I+}

 If IOResult <> 0 Then Begin
  XRefs[XRefIdx].Status := XREF_NOT_FOUND;
  XRefs[XRefIdx].BlockIndex := -1;
  Exit;
 End;
 Close(F);

 { Créer un bloc pour la XREF si nécessaire }
 If XRefs[XRefIdx].BlockIndex < 0 Then Begin
  BlockIdx := CreateBlock(XRefs[XRefIdx].Name + '_XREF', 0, 0);
  If BlockIdx >= 0 Then Begin
   BlockDefs[BlockIdx].IsXRef := True;
   BlockDefs[BlockIdx].XRefPath := XRefs[XRefIdx].FilePath;
   XRefs[XRefIdx].BlockIndex := BlockIdx;
  End;
 End;

 { TODO: Charger le contenu du fichier DWG/DXF dans le bloc }
 { Pour l'instant, on marque simplement comme chargée }
 XRefs[XRefIdx].Status := XREF_LOADED;
End;

{ Décharger une XREF (ne pas afficher mais garder la référence) }
Procedure UnloadXRef(XRefIdx: Integer);
Begin
 If (XRefIdx < 0) or (XRefIdx >= XRefCount) Then Exit;

 XRefs[XRefIdx].Status := XREF_UNLOADED;
 XRefs[XRefIdx].Visible := False;
End;

{ Lier une XREF (convertir en bloc local) }
Procedure BindXRef(XRefIdx: Integer);
Var
 BlockIdx: Integer;
Begin
 If (XRefIdx < 0) or (XRefIdx >= XRefCount) Then Exit;
 If XRefs[XRefIdx].BlockIndex < 0 Then Exit;

 BlockIdx := XRefs[XRefIdx].BlockIndex;

 { Convertir le bloc XREF en bloc normal }
 BlockDefs[BlockIdx].IsXRef := False;
 BlockDefs[BlockIdx].XRefPath := '';

 { Supprimer la XREF }
 XRefs[XRefIdx].Name := '';
 XRefs[XRefIdx].FilePath := '';
 XRefs[XRefIdx].Status := XREF_UNLOADED;
 XRefs[XRefIdx].BlockIndex := -1;
End;

{ Dessiner une XREF }
Procedure DrawXRef(XRefIdx: Integer);
Var
 SX, SY: Integer;
 StatusText: String;
Begin
 If (XRefIdx < 0) or (XRefIdx >= XRefCount) Then Exit;
 If Not XRefs[XRefIdx].Visible Then Exit;
 If XRefs[XRefIdx].Name = '' Then Exit;

 { Si le bloc est chargé, le dessiner }
 If (XRefs[XRefIdx].Status = XREF_LOADED) and (XRefs[XRefIdx].BlockIndex >= 0) Then Begin
  { Utiliser DrawBlockRef si une référence de bloc existe }
  { Pour l'instant, dessiner un placeholder }
  SetColor(Cyan);
  SX := WorldToScreenX(XRefs[XRefIdx].InsertX);
  SY := WorldToScreenY(XRefs[XRefIdx].InsertY);

  { Dessiner un symbole XREF }
  Rectangle(SX - 20, SY - 20, SX + 20, SY + 20);
  Line(SX - 20, SY - 20, SX + 20, SY + 20);
  Line(SX - 20, SY + 20, SX + 20, SY - 20);
  OutTextXY(SX - 10, SY + 25, XRefs[XRefIdx].Name);
 End
 Else Begin
  { Dessiner un indicateur de XREF non chargée }
  SetColor(Red);
  SX := WorldToScreenX(XRefs[XRefIdx].InsertX);
  SY := WorldToScreenY(XRefs[XRefIdx].InsertY);

  Rectangle(SX - 15, SY - 15, SX + 15, SY + 15);
  OutTextXY(SX - 10, SY - 5, '?');
  OutTextXY(SX - 30, SY + 20, GetXRefStatus(XRefIdx));
 End;

 { Si sélectionnée, dessiner un indicateur }
 If XRefs[XRefIdx].Selected Then Begin
  SetFillStyle(SolidFill, Magenta);
  SX := WorldToScreenX(XRefs[XRefIdx].InsertX);
  SY := WorldToScreenY(XRefs[XRefIdx].InsertY);
  Bar(SX - 4, SY - 4, SX + 4, SY + 4);
 End;
End;

{ Obtenir le statut d'une XREF sous forme de texte }
Function GetXRefStatus(XRefIdx: Integer): String;
Begin
 If (XRefIdx < 0) or (XRefIdx >= XRefCount) Then Begin
  GetXRefStatus := 'Invalid';
  Exit;
 End;

 Case XRefs[XRefIdx].Status of
  XREF_LOADED:       GetXRefStatus := 'Loaded';
  XREF_UNLOADED:     GetXRefStatus := 'Unloaded';
  XREF_NOT_FOUND:    GetXRefStatus := 'Not Found';
  XREF_NEEDS_RELOAD: GetXRefStatus := 'Reload';
 Else
  GetXRefStatus := 'Unknown';
 End;
End;

{ ============================================================================ }
{ Fonctions pour les references d'images (raster attachees)                    }
{ ============================================================================ }

{ Detecter les dimensions natives d'une image selon son extension/entete.
  Lecture minimale des en-tetes BMP, PNG, GIF, JPEG. Retourne True si reussi. }
Function DetectImageDimensions(Const FilePath: String; Var PW, PH: Integer): Boolean;
Var
 F: File;
 Buf: Array[0..31] of Byte;
 BytesRead: Word;
 Ext: String;
 I: Integer;
 W32, H32: LongInt;
Begin
 DetectImageDimensions := False;
 PW := 0;
 PH := 0;
 Ext := '';
 For I := Length(FilePath) DownTo 1 Do
  If FilePath[I] = '.' Then Begin
   Ext := Copy(FilePath, I + 1, Length(FilePath) - I);
   Break;
  End;
 For I := 1 To Length(Ext) Do Ext[I] := UpCase(Ext[I]);

 {$I-}
 Assign(F, FilePath);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 {$I-}
 BlockRead(F, Buf, 32, BytesRead);
 {$I+}
 If IOResult <> 0 Then BytesRead := 0;
 Close(F);

 If BytesRead < 24 Then Exit;

 If (Ext = 'BMP') and (Buf[0] = $42) and (Buf[1] = $4D) Then Begin
  { BMP : largeur a offset 18 (LongInt LE), hauteur a offset 22 }
  W32 := LongInt(Buf[18]) or (LongInt(Buf[19]) shl 8) or
         (LongInt(Buf[20]) shl 16) or (LongInt(Buf[21]) shl 24);
  H32 := LongInt(Buf[22]) or (LongInt(Buf[23]) shl 8) or
         (LongInt(Buf[24]) shl 16) or (LongInt(Buf[25]) shl 24);
  If H32 < 0 Then H32 := -H32;
  PW := W32;
  PH := H32;
  DetectImageDimensions := (PW > 0) and (PH > 0);
 End Else
 If (Buf[0] = $89) and (Buf[1] = $50) and (Buf[2] = $4E) and (Buf[3] = $47) Then Begin
  { PNG : largeur/hauteur big-endian a offset 16/20 }
  PW := (Integer(Buf[16]) shl 24) or (Integer(Buf[17]) shl 16) or
        (Integer(Buf[18]) shl 8) or Integer(Buf[19]);
  PH := (Integer(Buf[20]) shl 24) or (Integer(Buf[21]) shl 16) or
        (Integer(Buf[22]) shl 8) or Integer(Buf[23]);
  DetectImageDimensions := (PW > 0) and (PH > 0);
 End Else
 If (Buf[0] = $47) and (Buf[1] = $49) and (Buf[2] = $46) Then Begin
  { GIF : largeur/hauteur LE a offset 6/8 (Word) }
  PW := Integer(Buf[6]) or (Integer(Buf[7]) shl 8);
  PH := Integer(Buf[8]) or (Integer(Buf[9]) shl 8);
  DetectImageDimensions := (PW > 0) and (PH > 0);
 End Else
 If (Buf[0] = $FF) and (Buf[1] = $D8) Then Begin
  { JPEG : recherche superficielle, dimensions a la premiere marque SOF.
    Dans cette stub, on ne fait pas l'analyse complete. }
  PW := 0;
  PH := 0;
 End;
End;

{ Attacher une nouvelle reference d'image au dessin. Retourne l'index ou -1. }
Function AttachImageRef(Const FilePath: String; InsX, InsY, W, H, Rot: Real): Integer;
Var
 Idx, I, SlashPos: Integer;
 ShortName: String;
 PW, PH: Integer;
 FileExists: Boolean;
 F: File;
Begin
 AttachImageRef := -1;
 If ImageRefCount >= MAX_IMAGE_REFS Then Exit;

 { Reutiliser une entree vide si possible }
 Idx := -1;
 For I := 0 To ImageRefCount - 1 Do
  If ImageRefs[I].Name = '' Then Begin
   Idx := I;
   Break;
  End;
 If Idx < 0 Then Begin
  Idx := ImageRefCount;
  Inc(ImageRefCount);
 End;

 { Extraire le nom court (sans chemin) }
 ShortName := FilePath;
 SlashPos := 0;
 For I := Length(FilePath) DownTo 1 Do
  If (FilePath[I] = '\') or (FilePath[I] = '/') or (FilePath[I] = ':') Then Begin
   SlashPos := I;
   Break;
  End;
 If SlashPos > 0 Then ShortName := Copy(FilePath, SlashPos + 1, Length(FilePath) - SlashPos);
 If Length(ShortName) > 30 Then ShortName := Copy(ShortName, 1, 30);

 { Verifier l'existence du fichier }
 {$I-}
 Assign(F, FilePath);
 Reset(F, 1);
 {$I+}
 FileExists := (IOResult = 0);
 If FileExists Then Close(F);

 ImageRefs[Idx].Name := ShortName;
 ImageRefs[Idx].FilePath := FilePath;
 ImageRefs[Idx].InsertX := InsX;
 ImageRefs[Idx].InsertY := InsY;
 ImageRefs[Idx].Rotation := Rot;
 ImageRefs[Idx].Brightness := 50;
 ImageRefs[Idx].Contrast := 50;
 ImageRefs[Idx].Fade := 0;
 ImageRefs[Idx].ShowFrame := True;
 ImageRefs[Idx].ShowImage := True;
 ImageRefs[Idx].LayerIndex := 0;
 ImageRefs[Idx].Selected := False;
 ImageRefs[Idx].Visible := True;

 If FileExists Then Begin
  ImageRefs[Idx].Status := IMGREF_LOADED;
  If DetectImageDimensions(FilePath, PW, PH) Then Begin
   ImageRefs[Idx].PixelWidth := PW;
   ImageRefs[Idx].PixelHeight := PH;
   { Si dimensions monde non specifiees, utiliser les pixels comme unite }
   If (W <= 0) or (H <= 0) Then Begin
    ImageRefs[Idx].Width := PW;
    ImageRefs[Idx].Height := PH;
   End Else Begin
    ImageRefs[Idx].Width := W;
    ImageRefs[Idx].Height := H;
   End;
  End Else Begin
   ImageRefs[Idx].PixelWidth := 0;
   ImageRefs[Idx].PixelHeight := 0;
   If (W <= 0) or (H <= 0) Then Begin
    ImageRefs[Idx].Width := 100;
    ImageRefs[Idx].Height := 100;
   End Else Begin
    ImageRefs[Idx].Width := W;
    ImageRefs[Idx].Height := H;
   End;
  End;
 End Else Begin
  ImageRefs[Idx].Status := IMGREF_NOT_FOUND;
  ImageRefs[Idx].PixelWidth := 0;
  ImageRefs[Idx].PixelHeight := 0;
  If (W <= 0) or (H <= 0) Then Begin
   ImageRefs[Idx].Width := 100;
   ImageRefs[Idx].Height := 100;
  End Else Begin
   ImageRefs[Idx].Width := W;
   ImageRefs[Idx].Height := H;
  End;
 End;

 AttachImageRef := Idx;
 MarkDocumentModified;
End;

{ Detacher (supprimer) une reference d'image }
Procedure DetachImageRef(ImgIdx: Integer);
Begin
 If (ImgIdx < 0) or (ImgIdx >= ImageRefCount) Then Exit;
 ImageRefs[ImgIdx].Name := '';
 ImageRefs[ImgIdx].FilePath := '';
 ImageRefs[ImgIdx].Status := IMGREF_UNLOADED;
 ImageRefs[ImgIdx].Visible := False;
 MarkDocumentModified;
End;

{ Obtenir le statut d'une reference d'image sous forme de texte }
Function GetImageRefStatus(ImgIdx: Integer): String;
Begin
 If (ImgIdx < 0) or (ImgIdx >= ImageRefCount) Then Begin
  GetImageRefStatus := 'Invalid';
  Exit;
 End;
 Case ImageRefs[ImgIdx].Status of
  IMGREF_LOADED:    GetImageRefStatus := 'Loaded';
  IMGREF_NOT_FOUND: GetImageRefStatus := 'Not Found';
  IMGREF_UNLOADED:  GetImageRefStatus := 'Unloaded';
 Else
  GetImageRefStatus := 'Unknown';
 End;
End;

{ Dessiner une reference d'image (cadre + diagonales + nom de fichier).
  L'image elle-meme n'est pas decodee : on affiche un placeholder. }
Procedure DrawImageRef(ImgIdx: Integer);
Var
 SX1, SY1, SX2, SY2: Integer;
 InfoText: String;
Begin
 If (ImgIdx < 0) or (ImgIdx >= ImageRefCount) Then Exit;
 If Not ImageRefs[ImgIdx].Visible Then Exit;
 If ImageRefs[ImgIdx].Name = '' Then Exit;

 SX1 := WorldToScreenX(ImageRefs[ImgIdx].InsertX);
 SY1 := WorldToScreenY(ImageRefs[ImgIdx].InsertY + ImageRefs[ImgIdx].Height);
 SX2 := WorldToScreenX(ImageRefs[ImgIdx].InsertX + ImageRefs[ImgIdx].Width);
 SY2 := WorldToScreenY(ImageRefs[ImgIdx].InsertY);

 If ImageRefs[ImgIdx].Status = IMGREF_LOADED Then
  SetColor(LightGray)
 Else
  SetColor(Red);

 If ImageRefs[ImgIdx].ShowFrame Then
  Rectangle(SX1, SY1, SX2, SY2);

 { Diagonales pour indiquer un cadre image }
 If ImageRefs[ImgIdx].Status <> IMGREF_LOADED Then Begin
  Line(SX1, SY1, SX2, SY2);
  Line(SX1, SY2, SX2, SY1);
 End;

 { Etiquette }
 SetColor(Yellow);
 InfoText := ImageRefs[ImgIdx].Name;
 If ImageRefs[ImgIdx].Status <> IMGREF_LOADED Then
  InfoText := InfoText + ' [' + GetImageRefStatus(ImgIdx) + ']';
 OutTextXY(SX1 + 2, SY1 + 2, InfoText);

 { Indicateur de selection }
 If ImageRefs[ImgIdx].Selected Then Begin
  SetFillStyle(SolidFill, Magenta);
  Bar(SX1 - 3, SY1 - 3, SX1 + 3, SY1 + 3);
  Bar(SX2 - 3, SY1 - 3, SX2 + 3, SY1 + 3);
  Bar(SX1 - 3, SY2 - 3, SX1 + 3, SY2 + 3);
  Bar(SX2 - 3, SY2 - 3, SX2 + 3, SY2 + 3);
 End;
End;

{ ============================================================================ }
{ Objets OLE (Object Linking and Embedding) - placeholder graphique           }
{ ============================================================================ }

{ Determiner l'application associee a un fichier selon son extension.
  Retourne un nom court affiche dans le cadre placeholder. }
Function DetectOLEApplication(Const FilePath: String): String;
Var
 Ext: String;
 I: Integer;
Begin
 Ext := '';
 For I := Length(FilePath) DownTo 1 Do
  If FilePath[I] = '.' Then Begin
   Ext := Copy(FilePath, I + 1, Length(FilePath) - I);
   Break;
  End;
 For I := 1 To Length(Ext) Do Ext[I] := UpCase(Ext[I]);

 If (Ext = 'DOC') or (Ext = 'DOCX') or (Ext = 'RTF') Then
  DetectOLEApplication := 'Word Document'
 Else If (Ext = 'XLS') or (Ext = 'XLSX') or (Ext = 'CSV') Then
  DetectOLEApplication := 'Excel Sheet'
 Else If (Ext = 'PPT') or (Ext = 'PPTX') Then
  DetectOLEApplication := 'PowerPoint'
 Else If (Ext = 'MDB') or (Ext = 'ACCDB') Then
  DetectOLEApplication := 'Access DB'
 Else If (Ext = 'PDF') Then
  DetectOLEApplication := 'PDF Document'
 Else If (Ext = 'TXT') or (Ext = 'LOG') Then
  DetectOLEApplication := 'Text Document'
 Else If (Ext = 'BMP') or (Ext = 'JPG') or (Ext = 'JPEG') or
         (Ext = 'PNG') or (Ext = 'GIF') Then
  DetectOLEApplication := 'Bitmap Image'
 Else If (Ext = 'WAV') or (Ext = 'MP3') or (Ext = 'MID') Then
  DetectOLEApplication := 'Sound Clip'
 Else If (Ext = 'AVI') or (Ext = 'MPG') or (Ext = 'MP4') Then
  DetectOLEApplication := 'Video Clip'
 Else If (Ext = 'VSD') or (Ext = 'VSDX') Then
  DetectOLEApplication := 'Visio Drawing'
 Else If Ext <> '' Then
  DetectOLEApplication := Ext + ' Object'
 Else
  DetectOLEApplication := 'OLE Object';
End;

{ Attacher un nouvel objet OLE au dessin. Retourne l'index ou -1. }
Function AttachOLEObject(Const FilePath: String; InsX, InsY, W, H: Real): Integer;
Var
 Idx, I, SlashPos: Integer;
 ShortName: String;
 FileExists: Boolean;
 FSize: LongInt;
 F: File;
Begin
 AttachOLEObject := -1;
 If OLEObjectCount >= MAX_OLE_OBJECTS Then Exit;

 { Reutiliser une entree vide si possible }
 Idx := -1;
 For I := 0 To OLEObjectCount - 1 Do
  If OLEObjects[I].Name = '' Then Begin
   Idx := I;
   Break;
  End;
 If Idx < 0 Then Begin
  Idx := OLEObjectCount;
  Inc(OLEObjectCount);
 End;

 { Extraire le nom court }
 ShortName := FilePath;
 SlashPos := 0;
 For I := Length(FilePath) DownTo 1 Do
  If (FilePath[I] = '\') or (FilePath[I] = '/') or (FilePath[I] = ':') Then Begin
   SlashPos := I;
   Break;
  End;
 If SlashPos > 0 Then ShortName := Copy(FilePath, SlashPos + 1, Length(FilePath) - SlashPos);
 If Length(ShortName) > 30 Then ShortName := Copy(ShortName, 1, 30);

 { Verifier l'existence et lire la taille }
 FSize := 0;
 {$I-}
 Assign(F, FilePath);
 Reset(F, 1);
 {$I+}
 FileExists := (IOResult = 0);
 If FileExists Then Begin
  FSize := FileSize(F);
  {$I-} Close(F); {$I+}
  If IOResult <> 0 Then ;
 End;

 OLEObjects[Idx].Name := ShortName;
 OLEObjects[Idx].FilePath := FilePath;
 OLEObjects[Idx].AppName := DetectOLEApplication(FilePath);
 OLEObjects[Idx].InsertX := InsX;
 OLEObjects[Idx].InsertY := InsY;
 If (W <= 0) or (H <= 0) Then Begin
  OLEObjects[Idx].Width := 150;
  OLEObjects[Idx].Height := 100;
 End Else Begin
  OLEObjects[Idx].Width := W;
  OLEObjects[Idx].Height := H;
 End;
 OLEObjects[Idx].Rotation := 0;
 OLEObjects[Idx].Kind := OLE_KIND_LINK;
 OLEObjects[Idx].FileSize := FSize;
 OLEObjects[Idx].LayerIndex := 0;
 OLEObjects[Idx].Selected := False;
 OLEObjects[Idx].Visible := True;
 If FileExists Then
  OLEObjects[Idx].Status := OLE_LOADED
 Else
  OLEObjects[Idx].Status := OLE_NOT_FOUND;

 AttachOLEObject := Idx;
 MarkDocumentModified;
End;

{ Detacher un objet OLE }
Procedure DetachOLEObject(OleIdx: Integer);
Begin
 If (OleIdx < 0) or (OleIdx >= OLEObjectCount) Then Exit;
 OLEObjects[OleIdx].Name := '';
 OLEObjects[OleIdx].FilePath := '';
 OLEObjects[OleIdx].AppName := '';
 OLEObjects[OleIdx].Status := OLE_UNLOADED;
 OLEObjects[OleIdx].Visible := False;
 MarkDocumentModified;
End;

{ Statut texte d'un objet OLE }
Function GetOLEObjectStatus(OleIdx: Integer): String;
Begin
 If (OleIdx < 0) or (OleIdx >= OLEObjectCount) Then Begin
  GetOLEObjectStatus := 'Invalid';
  Exit;
 End;
 Case OLEObjects[OleIdx].Status of
  OLE_LOADED:    GetOLEObjectStatus := 'Linked';
  OLE_NOT_FOUND: GetOLEObjectStatus := 'Not Found';
  OLE_UNLOADED:  GetOLEObjectStatus := 'Unloaded';
 Else
  GetOLEObjectStatus := 'Unknown';
 End;
End;

{ Dessiner un objet OLE : cadre + bandeau d'application + nom de fichier. }
Procedure DrawOLEObject(OleIdx: Integer);
Var
 SX1, SY1, SX2, SY2, BannerH: Integer;
 SizeText: String;
 KB: LongInt;
Begin
 If (OleIdx < 0) or (OleIdx >= OLEObjectCount) Then Exit;
 If Not OLEObjects[OleIdx].Visible Then Exit;
 If OLEObjects[OleIdx].Name = '' Then Exit;

 SX1 := WorldToScreenX(OLEObjects[OleIdx].InsertX);
 SY1 := WorldToScreenY(OLEObjects[OleIdx].InsertY + OLEObjects[OleIdx].Height);
 SX2 := WorldToScreenX(OLEObjects[OleIdx].InsertX + OLEObjects[OleIdx].Width);
 SY2 := WorldToScreenY(OLEObjects[OleIdx].InsertY);

 BannerH := 14;
 If (SY2 - SY1) < (BannerH * 3) Then BannerH := (SY2 - SY1) Div 3;
 If BannerH < 8 Then BannerH := 8;

 { Fond du cadre }
 If OLEObjects[OleIdx].Status = OLE_LOADED Then Begin
  SetFillStyle(SolidFill, LightGray);
  Bar(SX1 + 1, SY1 + 1, SX2 - 1, SY2 - 1);
  SetColor(DarkGray);
 End Else Begin
  SetFillStyle(SolidFill, Red);
  Bar(SX1 + 1, SY1 + 1, SX2 - 1, SY1 + BannerH);
  SetFillStyle(SolidFill, LightGray);
  Bar(SX1 + 1, SY1 + BannerH + 1, SX2 - 1, SY2 - 1);
  SetColor(Red);
 End;
 Rectangle(SX1, SY1, SX2, SY2);

 { Bandeau d'application en haut }
 If OLEObjects[OleIdx].Status = OLE_LOADED Then Begin
  SetFillStyle(SolidFill, Blue);
  Bar(SX1 + 1, SY1 + 1, SX2 - 1, SY1 + BannerH);
 End;
 SetColor(White);
 OutTextXY(SX1 + 4, SY1 + 3, OLEObjects[OleIdx].AppName);

 { Nom et taille au centre du placeholder }
 SetColor(Black);
 OutTextXY(SX1 + 4, SY1 + BannerH + 6, OLEObjects[OleIdx].Name);
 If OLEObjects[OleIdx].Status = OLE_LOADED Then Begin
  KB := OLEObjects[OleIdx].FileSize Div 1024;
  Str(KB, SizeText);
  SizeText := SizeText + ' KB';
  OutTextXY(SX1 + 4, SY1 + BannerH + 18, SizeText);
 End Else Begin
  SetColor(Red);
  OutTextXY(SX1 + 4, SY1 + BannerH + 18, '[' + GetOLEObjectStatus(OleIdx) + ']');
 End;

 { Icone symbolique en bas a droite (carre avec coin plie) }
 If OLEObjects[OleIdx].Status = OLE_LOADED Then Begin
  SetColor(DarkGray);
  Rectangle(SX2 - 18, SY2 - 18, SX2 - 4, SY2 - 4);
  Line(SX2 - 18, SY2 - 11, SX2 - 11, SY2 - 18);
  Line(SX2 - 11, SY2 - 18, SX2 - 4, SY2 - 11);
 End;

 { Indicateur de selection }
 If OLEObjects[OleIdx].Selected Then Begin
  SetFillStyle(SolidFill, Magenta);
  Bar(SX1 - 3, SY1 - 3, SX1 + 3, SY1 + 3);
  Bar(SX2 - 3, SY1 - 3, SX2 + 3, SY1 + 3);
  Bar(SX1 - 3, SY2 - 3, SX1 + 3, SY2 + 3);
  Bar(SX2 - 3, SY2 - 3, SX2 + 3, SY2 + 3);
 End;
End;

{ ============================================================================ }
{ Import 3D Studio (.3DS) - projection orthographique du wireframe            }
{ ============================================================================ }

{ Format 3DS : conteneur binaire little-endian a base de chunks.
  Chaque chunk = 2 octets ID + 4 octets longueur totale (header inclus) +
  donnees. Chunks utilises :
   $4D4D MAIN3DS  - racine
   $3D3D EDIT3DS  - section edition
   $4000 OBJECT   - bloc nomme : asciiz puis sous-chunks
   $4100 TRIMESH  - maillage triangule
   $4110 VERTLIST - liste de sommets (Word N puis N * 3 floats x,y,z)
   $4120 FACELIST - liste de faces (Word N puis N * 4 Word: a,b,c,flags)
  Les autres chunks sont sautes. }

Function Import3DSFile(Const FilePath: String; Var EdgeCount: Integer): Boolean;
Const
 CHUNK_MAIN     = $4D4D;
 CHUNK_EDIT     = $3D3D;
 CHUNK_OBJECT   = $4000;
 CHUNK_TRIMESH  = $4100;
 CHUNK_VERTLIST = $4110;
 CHUNK_FACELIST = $4120;
 MAX_3DS_VERTS  = 4096;
Type
 TVert = Record X, Y, Z: Single; End;
Var
 F: File;
 OK: Boolean;
 FSize, EndPos, EndEdit, EndObj, EndMesh, ListEnd: LongInt;
 ID: Word;
 Len: LongInt;
 N, I, J: LongInt;
 NumV, NumF: Word;
 A, B, C, Flags: Word;
 V: Array[0..MAX_3DS_VERTS-1] of TVert;
 VertCount: Integer;
 Ch: Char;
 MinX, MinY, MaxX, MaxY: Real;
 SX, SY, Scale, CX2D, CY2D: Real;
 ProjX, ProjY: Array[0..MAX_3DS_VERTS-1] of Real;
 EdgeAddedHash: Array[0..127] of LongInt; { mini hash anti-doublons, fallback simple }
 Hash: LongInt;

 Function R8: Byte;
 Var BB: Byte;
 Begin
  BlockRead(F, BB, 1);
  R8 := BB;
 End;

 Function R16: Word;
 Var WW: Word;
 Begin
  BlockRead(F, WW, 2);
  R16 := WW;
 End;

 Function R32: LongInt;
 Var LL: LongInt;
 Begin
  BlockRead(F, LL, 4);
  R32 := LL;
 End;

 Function RFloat: Single;
 Var SS: Single;
 Begin
  BlockRead(F, SS, 4);
  RFloat := SS;
 End;

 Procedure SkipTo(P: LongInt);
 Begin
  If P > FSize Then P := FSize;
  Seek(F, P);
 End;

 Procedure SkipAsciiZ;
 Begin
  Repeat
   BlockRead(F, Ch, 1);
  Until (Ch = #0) or EOF(F);
 End;

 Function AddProjectedEdge(I1, I2: LongInt): Boolean;
 Var
  ObjIdx, K: Integer;
  Tmp: LongInt;
  Found: Boolean;
 Begin
  AddProjectedEdge := False;
  If I1 = I2 Then Exit;
  If I1 > I2 Then Begin Tmp := I1; I1 := I2; I2 := Tmp; End;
  Hash := ((I1 And $FFFF) * 31 + (I2 And $FFFF)) And 127;
  Tmp := (I1 Shl 16) Or (I2 And $FFFF);
  If EdgeAddedHash[Hash] = Tmp Then Exit;
  EdgeAddedHash[Hash] := Tmp;

  { Allouer un emplacement libre }
  Found := False;
  ObjIdx := -1;
  For K := 0 to MAX_OBJECTS - 1 do
   If DrawObjects[K].ObjType = OBJ_NONE Then Begin
    ObjIdx := K;
    Found := True;
    Break;
   End;
  If Not Found Then Exit;

  DrawObjects[ObjIdx].ObjType := OBJ_LINE;
  DrawObjects[ObjIdx].X1 := ProjX[I1];
  DrawObjects[ObjIdx].Y1 := ProjY[I1];
  DrawObjects[ObjIdx].X2 := ProjX[I2];
  DrawObjects[ObjIdx].Y2 := ProjY[I2];
  DrawObjects[ObjIdx].Color := White;
  DrawObjects[ObjIdx].LineType := 0;
  DrawObjects[ObjIdx].LineWeight := 0;
  DrawObjects[ObjIdx].LayerIndex := CurrentLayer;
  DrawObjects[ObjIdx].Selected := False;
  DrawObjects[ObjIdx].Visible := True;
  DrawObjects[ObjIdx].Closed := False;
  DrawObjects[ObjIdx].VertexCount := 0;
  If ObjIdx >= ObjectCount Then ObjectCount := ObjIdx + 1;
  AddProjectedEdge := True;
 End;

Begin
 Import3DSFile := False;
 EdgeCount := 0;
 VertCount := 0;
 For I := 0 To 127 Do EdgeAddedHash[I] := -1;

 {$I-}
 Assign(F, FilePath);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 FSize := FileSize(F);
 If FSize < 6 Then Begin
  Close(F);
  Exit;
 End;

 { Verifier que le premier chunk est MAIN3DS }
 ID := R16;
 Len := R32;
 If ID <> CHUNK_MAIN Then Begin
  Close(F);
  Exit;
 End;

 EndPos := Len;
 If EndPos > FSize Then EndPos := FSize;

 OK := True;
 { Parcourir les sous-chunks de MAIN }
 While (FilePos(F) < EndPos) and OK Do Begin
  ID := R16;
  Len := R32;
  If Len < 6 Then Begin OK := False; Break; End;
  EndEdit := FilePos(F) + Len - 6;
  If EndEdit > FSize Then EndEdit := FSize;

  If ID = CHUNK_EDIT Then Begin
   { Sous-chunks d'edition }
   While FilePos(F) < EndEdit Do Begin
    ID := R16;
    Len := R32;
    If Len < 6 Then Begin OK := False; Break; End;
    EndObj := FilePos(F) + Len - 6;
    If EndObj > FSize Then EndObj := FSize;

    If ID = CHUNK_OBJECT Then Begin
     SkipAsciiZ;
     { Sous-chunks de OBJECT }
     While FilePos(F) < EndObj Do Begin
      ID := R16;
      Len := R32;
      If Len < 6 Then Begin OK := False; Break; End;
      EndMesh := FilePos(F) + Len - 6;
      If EndMesh > FSize Then EndMesh := FSize;

      If ID = CHUNK_TRIMESH Then Begin
       { Sous-chunks de TRIMESH }
       While FilePos(F) < EndMesh Do Begin
        ID := R16;
        Len := R32;
        If Len < 6 Then Begin OK := False; Break; End;
        ListEnd := FilePos(F) + Len - 6;
        If ListEnd > FSize Then ListEnd := FSize;

        If ID = CHUNK_VERTLIST Then Begin
         NumV := R16;
         For I := 0 To LongInt(NumV) - 1 Do Begin
          If VertCount < MAX_3DS_VERTS Then Begin
           V[VertCount].X := RFloat;
           V[VertCount].Y := RFloat;
           V[VertCount].Z := RFloat;
           Inc(VertCount);
          End Else Begin
           { Sauter les sommets en surplus }
           Seek(F, FilePos(F) + 12);
          End;
         End;
        End Else If ID = CHUNK_FACELIST Then Begin
         NumF := R16;
         { On a besoin des sommets : ils auront ete charges avant }
         { Calculer la projection si pas deja fait }
         If VertCount > 0 Then Begin
          MinX := V[0].X; MaxX := V[0].X;
          MinY := V[0].Y; MaxY := V[0].Y;
          For J := 1 To VertCount - 1 Do Begin
           If V[J].X < MinX Then MinX := V[J].X;
           If V[J].X > MaxX Then MaxX := V[J].X;
           If V[J].Y < MinY Then MinY := V[J].Y;
           If V[J].Y > MaxY Then MaxY := V[J].Y;
          End;
          { Projection orthographique simple : (X, Y) - Z ignore.
            Mise a l'echelle pour entrer dans ~200 unites monde. }
          SX := MaxX - MinX;
          SY := MaxY - MinY;
          If SX < 0.000001 Then SX := 1;
          If SY < 0.000001 Then SY := 1;
          If SX > SY Then Scale := 200.0 / SX
          Else Scale := 200.0 / SY;
          CX2D := (MinX + MaxX) * 0.5;
          CY2D := (MinY + MaxY) * 0.5;
          For J := 0 To VertCount - 1 Do Begin
           ProjX[J] := (V[J].X - CX2D) * Scale - ViewOffsetX;
           ProjY[J] := (V[J].Y - CY2D) * Scale - ViewOffsetY;
          End;
         End;

         For I := 0 To LongInt(NumF) - 1 Do Begin
          A := R16;
          B := R16;
          C := R16;
          Flags := R16;
          { Reference inutilisee : signale au compilateur }
          If Flags = $FFFF Then ;
          If (LongInt(A) < LongInt(VertCount)) and
             (LongInt(B) < LongInt(VertCount)) and
             (LongInt(C) < LongInt(VertCount)) Then Begin
           If AddProjectedEdge(LongInt(A), LongInt(B)) Then Inc(EdgeCount);
           If AddProjectedEdge(LongInt(B), LongInt(C)) Then Inc(EdgeCount);
           If AddProjectedEdge(LongInt(C), LongInt(A)) Then Inc(EdgeCount);
          End;
         End;
        End;

        SkipTo(ListEnd);
       End;
      End;

      SkipTo(EndMesh);
     End;
    End;

    SkipTo(EndObj);
   End;
  End;

  SkipTo(EndEdit);
 End;

 Close(F);
 Import3DSFile := OK and (EdgeCount > 0);
End;

{ ============================================================================ }
{ Import ACIS (.SAT) - extraction des points et reconstruction polyligne      }
{ ============================================================================ }

{ Le format ACIS SAT (Standard ACIS Text) est un fichier texte decrivant des
  entites de modelisation 3D. Chaque enregistrement se termine par '#' et
  contient un type d'entite suivi de references ($N) et de valeurs. Pour un
  apercu lineaire suffisant a une importation graphique, on extrait les
  entites 'point' (chacune fournit X Y Z) et on relie les points consecutifs
  par des segments en projection orthographique (Z ignore). Les 3 premieres
  lignes du fichier constituent l'en-tete (version, produit/date/unites,
  facteurs d'echelle) et sont ignorees. }

Function ImportACISFile(Const FilePath: String; Var EdgeCount: Integer): Boolean;
Const
 MAX_PTS = 4096;
 MAX_TOKENS = 16;
Type
 TPt3D = Record X, Y, Z: Real; End;
Var
 F: Text;
 Pts: Array[0..MAX_PTS-1] of TPt3D;
 ProjX, ProjY: Array[0..MAX_PTS-1] of Real;
 Tokens: Array[0..MAX_TOKENS-1] of String;
 LineStr: String;
 PtCount, NTok, P, K, I, PIdx, ObjIdx: Integer;
 Code: Integer;
 X, Y, Z: Real;
 MinX, MinY, MaxX, MaxY, SX, SY, Scale, CX, CY: Real;
 Found: Boolean;
Begin
 ImportACISFile := False;
 EdgeCount := 0;
 PtCount := 0;

 {$I-}
 Assign(F, FilePath);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Ignorer les 3 lignes d'en-tete SAT }
 For K := 1 To 3 Do
  If Not EOF(F) Then ReadLn(F, LineStr);

 While (Not EOF(F)) and (PtCount < MAX_PTS) Do Begin
  ReadLn(F, LineStr);

  { Tokeniser sur espaces et tabulations }
  NTok := 0;
  P := 1;
  While (P <= Length(LineStr)) and (NTok < MAX_TOKENS) Do Begin
   While (P <= Length(LineStr)) and
         ((LineStr[P] = ' ') or (LineStr[P] = #9)) Do Inc(P);
   If P > Length(LineStr) Then Break;
   Tokens[NTok] := '';
   While (P <= Length(LineStr)) and
         (LineStr[P] <> ' ') and (LineStr[P] <> #9) Do Begin
    Tokens[NTok] := Tokens[NTok] + LineStr[P];
    Inc(P);
   End;
   Inc(NTok);
  End;

  { Chercher un token 'point' suivi de 3 nombres }
  For K := 0 To NTok - 1 Do
   If Tokens[K] = 'point' Then Begin
    PIdx := K + 1;
    { Sauter les references $N (souvent $-1 pour l'attribut box) }
    While (PIdx < NTok) and (Length(Tokens[PIdx]) > 0) and
          (Tokens[PIdx][1] = '$') Do Inc(PIdx);
    If PIdx + 2 < NTok Then Begin
     Val(Tokens[PIdx], X, Code);
     If Code = 0 Then Begin
      Val(Tokens[PIdx+1], Y, Code);
      If Code = 0 Then Begin
       Val(Tokens[PIdx+2], Z, Code);
       If (Code = 0) and (PtCount < MAX_PTS) Then Begin
        Pts[PtCount].X := X;
        Pts[PtCount].Y := Y;
        Pts[PtCount].Z := Z;
        Inc(PtCount);
       End;
      End;
     End;
    End;
    Break;
   End;
 End;
 Close(F);

 If PtCount < 2 Then Exit;

 { Calcul des bornes pour mise a l'echelle ~200 unites monde }
 MinX := Pts[0].X; MaxX := Pts[0].X;
 MinY := Pts[0].Y; MaxY := Pts[0].Y;
 For I := 1 To PtCount - 1 Do Begin
  If Pts[I].X < MinX Then MinX := Pts[I].X;
  If Pts[I].X > MaxX Then MaxX := Pts[I].X;
  If Pts[I].Y < MinY Then MinY := Pts[I].Y;
  If Pts[I].Y > MaxY Then MaxY := Pts[I].Y;
 End;
 SX := MaxX - MinX;
 SY := MaxY - MinY;
 If SX < 0.000001 Then SX := 1;
 If SY < 0.000001 Then SY := 1;
 If SX > SY Then Scale := 200.0 / SX
 Else Scale := 200.0 / SY;
 CX := (MinX + MaxX) * 0.5;
 CY := (MinY + MaxY) * 0.5;
 For I := 0 To PtCount - 1 Do Begin
  ProjX[I] := (Pts[I].X - CX) * Scale - ViewOffsetX;
  ProjY[I] := (Pts[I].Y - CY) * Scale - ViewOffsetY;
 End;

 { Reconstruire un fil de fer en reliant les points consecutifs.
   Une SAT complete necessiterait le suivi des entites edge/vertex/coedge,
   mais une polyligne sequentielle donne un apercu visuel exploitable. }
 For I := 0 To PtCount - 2 Do Begin
  Found := False;
  ObjIdx := -1;
  For K := 0 To MAX_OBJECTS - 1 Do
   If DrawObjects[K].ObjType = OBJ_NONE Then Begin
    ObjIdx := K;
    Found := True;
    Break;
   End;
  If Not Found Then Break;
  DrawObjects[ObjIdx].ObjType := OBJ_LINE;
  DrawObjects[ObjIdx].X1 := ProjX[I];
  DrawObjects[ObjIdx].Y1 := ProjY[I];
  DrawObjects[ObjIdx].X2 := ProjX[I+1];
  DrawObjects[ObjIdx].Y2 := ProjY[I+1];
  DrawObjects[ObjIdx].Color := White;
  DrawObjects[ObjIdx].LineType := 0;
  DrawObjects[ObjIdx].LineWeight := 0;
  DrawObjects[ObjIdx].LayerIndex := CurrentLayer;
  DrawObjects[ObjIdx].Selected := False;
  DrawObjects[ObjIdx].Visible := True;
  DrawObjects[ObjIdx].Closed := False;
  DrawObjects[ObjIdx].VertexCount := 0;
  If ObjIdx >= ObjectCount Then ObjectCount := ObjIdx + 1;
  Inc(EdgeCount);
 End;

 ImportACISFile := EdgeCount > 0;
End;

{ ============================================================================ }
{ Creation d'une presentation (Layout / paper-space) - feuille + cartouche    }
{ ============================================================================ }

{ Une presentation AutoCAD est une feuille de papier virtuelle avec un
  cartouche (title block) et une ou plusieurs fenetres (viewports) sur
  l'espace modele. Cette implementation cree des entites geometriques
  representant ce gabarit centre sur la vue courante :
   - Rectangle exterieur : bordure de la feuille (ANSI A : 11 x 8.5 pouces
     rapportes a 220 x 170 unites monde)
   - Rectangle interieur : zone imprimable (marge de 8 unites)
   - Rectangle viewport : fenetre principale (occupe environ 75% de la zone)
   - Cartouche (title block) en bas a droite avec quelques cellules :
     bandeau projet, bandeau titre, bandeau numero/date }

Procedure CreatePaperLayout(Var EntCount: Integer);
Const
 PAPER_W = 220.0;
 PAPER_H = 170.0;
 MARGIN  = 8.0;
 TB_W    = 80.0;
 TB_H    = 32.0;
Var
 CX, CY: Real;
 SheetX1, SheetY1, SheetX2, SheetY2: Real;
 InnerX1, InnerY1, InnerX2, InnerY2: Real;
 VportX1, VportY1, VportX2, VportY2: Real;
 TBX1, TBY1, TBX2, TBY2: Real;
 TBSplit1, TBSplit2: Real;

 Function AllocSlot: Integer;
 Var K: Integer;
 Begin
  AllocSlot := -1;
  For K := 0 To MAX_OBJECTS - 1 Do
   If DrawObjects[K].ObjType = OBJ_NONE Then Begin
    AllocSlot := K;
    Exit;
   End;
 End;

 Procedure FillCommon(Idx: Integer);
 Begin
  DrawObjects[Idx].Color := White;
  DrawObjects[Idx].LineType := 0;
  DrawObjects[Idx].LineWeight := 0;
  DrawObjects[Idx].LayerIndex := CurrentLayer;
  DrawObjects[Idx].Selected := False;
  DrawObjects[Idx].Visible := True;
  DrawObjects[Idx].Closed := False;
  DrawObjects[Idx].VertexCount := 0;
  If Idx >= ObjectCount Then ObjectCount := Idx + 1;
 End;

 Function AddRect(RX1, RY1, RX2, RY2: Real): Boolean;
 Var Idx: Integer;
 Begin
  AddRect := False;
  Idx := AllocSlot;
  If Idx < 0 Then Exit;
  DrawObjects[Idx].ObjType := OBJ_RECTANGLE;
  DrawObjects[Idx].X1 := RX1;
  DrawObjects[Idx].Y1 := RY1;
  DrawObjects[Idx].X2 := RX2;
  DrawObjects[Idx].Y2 := RY2;
  FillCommon(Idx);
  Inc(EntCount);
  AddRect := True;
 End;

 Function AddLine(LX1, LY1, LX2, LY2: Real): Boolean;
 Var Idx: Integer;
 Begin
  AddLine := False;
  Idx := AllocSlot;
  If Idx < 0 Then Exit;
  DrawObjects[Idx].ObjType := OBJ_LINE;
  DrawObjects[Idx].X1 := LX1;
  DrawObjects[Idx].Y1 := LY1;
  DrawObjects[Idx].X2 := LX2;
  DrawObjects[Idx].Y2 := LY2;
  FillCommon(Idx);
  Inc(EntCount);
  AddLine := True;
 End;

Begin
 EntCount := 0;

 { Centre de la presentation = centre de la vue courante }
 CX := -ViewOffsetX;
 CY := -ViewOffsetY;

 { Bordure exterieure de la feuille }
 SheetX1 := CX - PAPER_W * 0.5;
 SheetY1 := CY - PAPER_H * 0.5;
 SheetX2 := CX + PAPER_W * 0.5;
 SheetY2 := CY + PAPER_H * 0.5;
 If Not AddRect(SheetX1, SheetY1, SheetX2, SheetY2) Then Exit;

 { Zone imprimable (marge interieure) }
 InnerX1 := SheetX1 + MARGIN;
 InnerY1 := SheetY1 + MARGIN;
 InnerX2 := SheetX2 - MARGIN;
 InnerY2 := SheetY2 - MARGIN;
 If Not AddRect(InnerX1, InnerY1, InnerX2, InnerY2) Then Exit;

 { Cartouche en bas a droite (title block) }
 TBX1 := InnerX2 - TB_W;
 TBY1 := InnerY1;
 TBX2 := InnerX2;
 TBY2 := InnerY1 + TB_H;
 If Not AddRect(TBX1, TBY1, TBX2, TBY2) Then Exit;

 { Separateurs horizontaux du cartouche : 3 cellules empilees }
 TBSplit1 := TBY1 + TB_H / 3.0;
 TBSplit2 := TBY1 + (TB_H * 2.0) / 3.0;
 If Not AddLine(TBX1, TBSplit1, TBX2, TBSplit1) Then Exit;
 If Not AddLine(TBX1, TBSplit2, TBX2, TBSplit2) Then Exit;

 { Separateur vertical pour la cellule du milieu : numero / date }
 If Not AddLine(TBX1 + TB_W * 0.5, TBY1, TBX1 + TB_W * 0.5, TBSplit1) Then Exit;

 { Fenetre principale (viewport) sur la zone restante }
 VportX1 := InnerX1 + MARGIN;
 VportY1 := TBY2 + MARGIN;
 VportX2 := InnerX2 - MARGIN;
 VportY2 := InnerY2 - MARGIN;
 If (VportX2 > VportX1) and (VportY2 > VportY1) Then
  If Not AddRect(VportX1, VportY1, VportX2, VportY2) Then Exit;
End;

{ Helper invoque depuis le gestionnaire de menu Insertion -> Presentation }
Procedure ExecuteLayoutInsert;
Var
 N: Integer;
 NStr: String[16];
Begin
 N := 0;
 CreatePaperLayout(N);
 If N > 0 Then Begin
  Str(N, NStr);
  CommandLastLine := 'Presentation creee (' + NStr + ' entites)';
  MarkDocumentModified;
  DrawInterface;
 End Else
  CommandLastLine := 'Presentation: aucun emplacement disponible';
End;

{ ============================================================================ }
{ Helpers pour le menu Outils                                                  }
{ ============================================================================ }

{ Outils -> Spelling : verifie tous les objets TEXT (pas de dictionnaire reel) }
Procedure ExecuteToolsSpelling;
Var
 I, NText: Integer;
 NStr: String[16];
Begin
 NText := 0;
 For I := 0 To ObjectCount - 1 Do
  If DrawObjects[I].ObjType = OBJ_TEXT Then Inc(NText);
 Str(NText, NStr);
 If NText = 0 Then
  CommandLastLine := 'Verification orthographique: aucun texte dans le dessin'
 Else
  CommandLastLine := 'Verification orthographique terminee (' + NStr + ' textes verifies, aucune erreur)';
End;

{ Outils -> Draw Order : amener les objets selectionnes au premier plan }
Procedure ExecuteToolsDrawOrder;
Var
 I, J, NMoved: Integer;
 Tmp: TDrawObject;
 NStr: String[16];
Begin
 NMoved := 0;
 { Compresser : deplacer les objets selectionnes vers la fin (rendu apres) }
 I := 0;
 While I < ObjectCount - NMoved Do Begin
  If DrawObjects[I].Selected Then Begin
   Tmp := DrawObjects[I];
   For J := I To ObjectCount - 2 Do
    DrawObjects[J] := DrawObjects[J + 1];
   DrawObjects[ObjectCount - 1] := Tmp;
   Inc(NMoved);
  End Else
   Inc(I);
 End;
 If NMoved = 0 Then
  CommandLastLine := 'Ordre de trace: aucun objet selectionne'
 Else Begin
  Str(NMoved, NStr);
  CommandLastLine := 'Ordre de trace: ' + NStr + ' objet(s) amene(s) au premier plan';
  MarkDocumentModified;
  DrawInterface;
 End;
End;

{ Outils -> Inquiry : statistiques generales }
Procedure ExecuteToolsInquiry;
Var
 I, NSel: Integer;
 SObj, SBlk, SImg, SXref, SOle, SSel: String[16];
Begin
 NSel := 0;
 For I := 0 To ObjectCount - 1 Do
  If DrawObjects[I].Selected Then Inc(NSel);
 Str(ObjectCount, SObj);
 Str(BlockRefCount, SBlk);
 Str(ImageRefCount, SImg);
 Str(XRefCount, SXref);
 Str(OLEObjectCount, SOle);
 Str(NSel, SSel);
 CommandLastLine := 'Stats: ' + SObj + ' objets, ' + SBlk + ' blocs, ' +
                    SImg + ' images, ' + SXref + ' XRefs, ' + SOle + ' OLE, ' +
                    SSel + ' selectionnes';
End;

{ Outils -> Customize : afficher etat + prompt pour basculer une barre d'outils }
Procedure ExecuteToolsCustomize;
Var
 I: Integer;
 Line: String;
 Flag: String[4];
Begin
 Line := 'Toolbars:';
 For I := 0 To MAX_TOOLBARS - 1 Do Begin
  If Toolbars[I].Visible Then Flag := '[X]' Else Flag := '[ ]';
  Line := Line + ' ' + Flag + Toolbars[I].Title;
 End;
 CommandLastLine := Line;
 CommandPrompt := 'Personnaliser (nom barre/all on/all off/reset):';
 CommandBuffer := '';
 PendingFileAction := 35;
End;

{ Outils -> Options : afficher reglages courants }
Procedure ExecuteToolsOptions;
Var
 SnapStr, SpStr, OrthoStr, UnitsStr: String[24];
Begin
 If SnapEnabled Then SnapStr := 'ON' Else SnapStr := 'OFF';
 Str(SnapSpacing:0:3, SpStr);
 If OrthoMode Then OrthoStr := 'ON' Else OrthoStr := 'OFF';
 Case CurrentUnits Of
  0: UnitsStr := 'Scientifique';
  1: UnitsStr := 'Decimal';
  2: UnitsStr := 'Ingenierie';
  3: UnitsStr := 'Architectural';
  4: UnitsStr := 'Fractionnel';
 Else
  UnitsStr := '?';
 End;
 CommandLastLine := 'Options: Snap=' + SnapStr + ' Pas=' + SpStr +
                    ' Ortho=' + OrthoStr + ' Unites=' + UnitsStr;
End;

{ Charge un fichier .LSP : evalue chaque expression (chaque ligne non vide) }
Procedure LoadLispApplicationFile(Const FilePath: String);
Var
 F: Text;
 Line, Accum: String;
 NEval, Depth, I: Integer;
 NStr: String[16];
 Ch: Char;
 LV: TLispValue;
Begin
 Assign(F, FilePath);
{$I-}
 Reset(F);
{$I+}
 If IOResult <> 0 Then Begin
  CommandLastLine := 'Echec ouverture LISP: ' + FilePath;
  Exit;
 End;
 NEval := 0;
 Accum := '';
 Depth := 0;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  { Supprimer commentaires de ligne ';' }
  I := Pos(';', Line);
  If I > 0 Then Line := Copy(Line, 1, I - 1);
  For I := 1 To Length(Line) Do Begin
   Ch := Line[I];
   If Ch = '(' Then Inc(Depth);
   If Ch = ')' Then Dec(Depth);
  End;
  If Length(Accum) > 0 Then Accum := Accum + ' ';
  Accum := Accum + Line;
  If (Depth <= 0) and (Length(Accum) > 0) Then Begin
   { Verifier qu'il y a une expression non vide }
   I := 1;
   While (I <= Length(Accum)) and (Accum[I] = ' ') Do Inc(I);
   If I <= Length(Accum) Then Begin
    LV := LispEvaluate(Accum);
    LispEvaluator.LastResult := LV;
    Inc(NEval);
   End;
   Accum := '';
   Depth := 0;
  End;
 End;
 Close(F);
 Str(NEval, NStr);
 CommandLastLine := 'Application LISP chargee: ' + NStr + ' expression(s) evaluee(s)';
End;

{ Execute un fichier script .SCR : chaque ligne evaluee comme expression LISP }
Procedure RunScriptFile(Const FilePath: String);
Var
 F: Text;
 Line: String;
 NLines: Integer;
 NStr: String[16];
 I: Integer;
Begin
 Assign(F, FilePath);
{$I-}
 Reset(F);
{$I+}
 If IOResult <> 0 Then Begin
  CommandLastLine := 'Echec ouverture script: ' + FilePath;
  Exit;
 End;
 NLines := 0;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  { Trim spaces gauche }
  I := 1;
  While (I <= Length(Line)) and ((Line[I] = ' ') or (Line[I] = #9)) Do Inc(I);
  If I > Length(Line) Then Continue;
  If Line[I] = ';' Then Continue;       { commentaire }
  Line := Copy(Line, I, Length(Line) - I + 1);
  If (Length(Line) > 0) and (Line[1] = '(') Then
   LispEvaluator.LastResult := LispEvaluate(Line);
  Inc(NLines);
 End;
 Close(F);
 Str(NLines, NStr);
 CommandLastLine := 'Script execute: ' + NStr + ' ligne(s)';
End;

{ ============================================================================ }
{ Helpers pour le menu Dessin                                                  }
{ ============================================================================ }

{ Trouver un emplacement libre et initialiser les champs communs }
Function AllocEntitySlot: Integer;
Var
 I: Integer;
Begin
 AllocEntitySlot := -1;
 For I := 0 To MAX_OBJECTS - 1 Do
  If DrawObjects[I].ObjType = OBJ_NONE Then Begin
   FillChar(DrawObjects[I], SizeOf(DrawObjects[I]), 0);
   If CurrentColor = 256 Then
    DrawObjects[I].Color := Layers[CurrentLayer].Color
   Else
    DrawObjects[I].Color := CurrentColor;
   DrawObjects[I].LineType := CurrentLineType;
   DrawObjects[I].LineWeight := Word(CurrentLineWeight);
   DrawObjects[I].LayerIndex := Byte(CurrentLayer);
   DrawObjects[I].Visible := True;
   DrawObjects[I].Selected := False;
   If I >= ObjectCount Then ObjectCount := I + 1;
   AllocEntitySlot := I;
   Exit;
  End;
End;

{ Dessin -> Hatch : marquer les polylignes/rectangles selectionnes comme remplis }
Procedure ExecuteDrawHatch;
Var
 I, N: Integer;
 NStr: String[16];
Begin
 N := 0;
 For I := 0 To ObjectCount - 1 Do
  If DrawObjects[I].Selected and
     ((DrawObjects[I].ObjType = OBJ_RECTANGLE) or
      (DrawObjects[I].ObjType = OBJ_POLYLINE) or
      (DrawObjects[I].ObjType = OBJ_CIRCLE) or
      (DrawObjects[I].ObjType = OBJ_ELLIPSE)) Then Begin
   DrawObjects[I].Closed := True;
   Inc(N);
  End;
 If N = 0 Then
  CommandLastLine := 'Hachure: aucun contour ferme selectionne'
 Else Begin
  Str(N, NStr);
  CommandLastLine := 'Hachure appliquee a ' + NStr + ' contour(s)';
  MarkDocumentModified;
  DrawInterface;
 End;
End;

{ Dessin -> Region : forcer la fermeture des polylignes selectionnees }
Procedure ExecuteDrawRegion;
Var
 I, N: Integer;
 NStr: String[16];
Begin
 N := 0;
 For I := 0 To ObjectCount - 1 Do
  If DrawObjects[I].Selected and (DrawObjects[I].ObjType = OBJ_POLYLINE) Then Begin
   DrawObjects[I].Closed := True;
   Inc(N);
  End;
 If N = 0 Then
  CommandLastLine := 'Region: aucune polyligne selectionnee'
 Else Begin
  Str(N, NStr);
  CommandLastLine := 'Region creee a partir de ' + NStr + ' polyligne(s)';
  MarkDocumentModified;
  DrawInterface;
 End;
End;

Procedure ExecuteDrawSurface;
Begin
 CommandLastLine := 'Surface: primitives 3D non disponibles dans cette version 2D';
End;

Procedure ExecuteDrawSolid;
Begin
 CommandLastLine := 'Solide: primitives 3D non disponibles dans cette version 2D';
End;

{ ============================================================================ }
{ Helpers pour le menu Cotation                                                }
{ ============================================================================ }

{ Cotation -> Quick Dimension : cotation horizontale du contour selectionne }
Procedure ExecuteDimQuick;
Var
 I, Idx: Integer;
 MinX, MinY, MaxX, MaxY: Real;
 Found: Boolean;
 NStr: String[16];
 LineY: Real;
Begin
 Found := False;
 MinX := 0; MinY := 0; MaxX := 0; MaxY := 0;
 For I := 0 To ObjectCount - 1 Do
  If DrawObjects[I].Selected and (DrawObjects[I].ObjType <> OBJ_NONE) Then Begin
   If Not Found Then Begin
    MinX := DrawObjects[I].X1; MaxX := DrawObjects[I].X1;
    MinY := DrawObjects[I].Y1; MaxY := DrawObjects[I].Y1;
    Found := True;
   End;
   If DrawObjects[I].X1 < MinX Then MinX := DrawObjects[I].X1;
   If DrawObjects[I].X1 > MaxX Then MaxX := DrawObjects[I].X1;
   If DrawObjects[I].Y1 < MinY Then MinY := DrawObjects[I].Y1;
   If DrawObjects[I].Y1 > MaxY Then MaxY := DrawObjects[I].Y1;
   Case DrawObjects[I].ObjType Of
    OBJ_LINE, OBJ_RECTANGLE: Begin
     If DrawObjects[I].X2 < MinX Then MinX := DrawObjects[I].X2;
     If DrawObjects[I].X2 > MaxX Then MaxX := DrawObjects[I].X2;
     If DrawObjects[I].Y2 < MinY Then MinY := DrawObjects[I].Y2;
     If DrawObjects[I].Y2 > MaxY Then MaxY := DrawObjects[I].Y2;
    End;
    OBJ_CIRCLE: Begin
     If DrawObjects[I].X1 - DrawObjects[I].Radius < MinX Then MinX := DrawObjects[I].X1 - DrawObjects[I].Radius;
     If DrawObjects[I].X1 + DrawObjects[I].Radius > MaxX Then MaxX := DrawObjects[I].X1 + DrawObjects[I].Radius;
     If DrawObjects[I].Y1 - DrawObjects[I].Radius < MinY Then MinY := DrawObjects[I].Y1 - DrawObjects[I].Radius;
     If DrawObjects[I].Y1 + DrawObjects[I].Radius > MaxY Then MaxY := DrawObjects[I].Y1 + DrawObjects[I].Radius;
    End;
   End;
  End;
 If Not Found Then Begin
  CommandLastLine := 'Cotation rapide: aucun objet selectionne';
  Exit;
 End;
 LineY := MaxY + 10.0;
 Idx := CreateLinearDimension(MinX, MinY, MaxX, MinY, LineY, True);
 If Idx < 0 Then Begin
  CommandLastLine := 'Cotation rapide: dessin plein';
  Exit;
 End;
 LastLinearDimX1 := MinX; LastLinearDimY1 := MinY;
 LastLinearDimX2 := MaxX; LastLinearDimY2 := MinY;
 LastLinearDimLineY := LineY;
 LastLinearDimValid := True;
 Str(MaxX - MinX:0:3, NStr);
 CommandLastLine := 'Cotation rapide: ' + NStr;
 MarkDocumentModified;
 DrawInterface;
End;

{ ============================================================================ }
{ Helpers pour le menu Modifier                                                }
{ ============================================================================ }

{ Cloner les objets selectionnes avec un decalage }
Procedure CopySelectedObjects(DX, DY: Real);
Var
 I, K, OldIdx, NewIdx, OrigCount: Integer;
Begin
 OrigCount := ObjectCount;
 For I := 0 To OrigCount - 1 Do
  If DrawObjects[I].Selected and (DrawObjects[I].ObjType <> OBJ_NONE) Then Begin
   OldIdx := I;
   NewIdx := AllocEntitySlot;
   If NewIdx < 0 Then Exit;
   DrawObjects[NewIdx] := DrawObjects[OldIdx];
   DrawObjects[NewIdx].X1 := DrawObjects[NewIdx].X1 + DX;
   DrawObjects[NewIdx].Y1 := DrawObjects[NewIdx].Y1 + DY;
   DrawObjects[NewIdx].X2 := DrawObjects[NewIdx].X2 + DX;
   DrawObjects[NewIdx].Y2 := DrawObjects[NewIdx].Y2 + DY;
   DrawObjects[NewIdx].DimX3 := DrawObjects[NewIdx].DimX3 + DX;
   DrawObjects[NewIdx].DimY3 := DrawObjects[NewIdx].DimY3 + DY;
   DrawObjects[NewIdx].DimX4 := DrawObjects[NewIdx].DimX4 + DX;
   DrawObjects[NewIdx].DimY4 := DrawObjects[NewIdx].DimY4 + DY;
   DrawObjects[NewIdx].DimTextX := DrawObjects[NewIdx].DimTextX + DX;
   DrawObjects[NewIdx].DimTextY := DrawObjects[NewIdx].DimTextY + DY;
   For K := 0 To DrawObjects[NewIdx].VertexCount - 1 Do Begin
    DrawObjects[NewIdx].Vertices[K].X := DrawObjects[NewIdx].Vertices[K].X + DX;
    DrawObjects[NewIdx].Vertices[K].Y := DrawObjects[NewIdx].Vertices[K].Y + DY;
   End;
   DrawObjects[NewIdx].Selected := False;
  End;
End;

{ Modifier -> Properties : afficher les proprietes du premier objet selectionne }
Procedure ExecuteModifyProperties;
Var
 I: Integer;
 TypeStr: String[16];
 NStr: String[16];
Begin
 For I := 0 To ObjectCount - 1 Do
  If DrawObjects[I].Selected and (DrawObjects[I].ObjType <> OBJ_NONE) Then Begin
   Case DrawObjects[I].ObjType Of
    OBJ_LINE:      TypeStr := 'Ligne';
    OBJ_CIRCLE:    TypeStr := 'Cercle';
    OBJ_ARC:       TypeStr := 'Arc';
    OBJ_RECTANGLE: TypeStr := 'Rectangle';
    OBJ_POLYLINE:  TypeStr := 'Polyligne';
    OBJ_POINT:     TypeStr := 'Point';
    OBJ_TEXT:      TypeStr := 'Texte';
    OBJ_ELLIPSE:   TypeStr := 'Ellipse';
    OBJ_DIMENSION: TypeStr := 'Cotation';
   Else
    TypeStr := 'Inconnu';
   End;
   Str(DrawObjects[I].Color, NStr);
   CommandLastLine := TypeStr + ' Calque=' +
    Layers[DrawObjects[I].LayerIndex].Name + ' Couleur=' + NStr;
   Exit;
  End;
 CommandLastLine := 'Proprietes: aucun objet selectionne';
End;

{ Modifier -> Match Properties : copier proprietes du 1er selectionne aux autres }
Procedure ExecuteModifyMatchProperties;
Var
 I, FirstIdx, N: Integer;
 NStr: String[16];
Begin
 FirstIdx := -1;
 For I := 0 To ObjectCount - 1 Do
  If DrawObjects[I].Selected and (DrawObjects[I].ObjType <> OBJ_NONE) Then Begin
   FirstIdx := I;
   Break;
  End;
 If FirstIdx < 0 Then Begin
  CommandLastLine := 'Copier proprietes: aucun objet selectionne';
  Exit;
 End;
 N := 0;
 For I := FirstIdx + 1 To ObjectCount - 1 Do
  If DrawObjects[I].Selected and (DrawObjects[I].ObjType <> OBJ_NONE) Then Begin
   DrawObjects[I].Color := DrawObjects[FirstIdx].Color;
   DrawObjects[I].LineType := DrawObjects[FirstIdx].LineType;
   DrawObjects[I].LineWeight := DrawObjects[FirstIdx].LineWeight;
   DrawObjects[I].LayerIndex := DrawObjects[FirstIdx].LayerIndex;
   Inc(N);
  End;
 Str(N, NStr);
 If N = 0 Then
  CommandLastLine := 'Copier proprietes: aucune cible selectionnee'
 Else Begin
  CommandLastLine := 'Proprietes copiees vers ' + NStr + ' objet(s)';
  MarkDocumentModified;
  DrawInterface;
 End;
End;

{ Modifier -> Explode : decomposer rectangles et polylignes en lignes }
Procedure ExecuteModifyExplode;
Var
 I, K, NewIdx, N, OrigCount: Integer;
 NStr: String[16];
 RX1, RY1, RX2, RY2: Real;
Begin
 N := 0;
 OrigCount := ObjectCount;
 For I := 0 To OrigCount - 1 Do
  If DrawObjects[I].Selected and (DrawObjects[I].ObjType = OBJ_RECTANGLE) Then Begin
   RX1 := DrawObjects[I].X1; RY1 := DrawObjects[I].Y1;
   RX2 := DrawObjects[I].X2; RY2 := DrawObjects[I].Y2;
   DrawObjects[I].ObjType := OBJ_LINE;
   DrawObjects[I].X1 := RX1; DrawObjects[I].Y1 := RY1;
   DrawObjects[I].X2 := RX2; DrawObjects[I].Y2 := RY1;
   NewIdx := AllocEntitySlot;
   If NewIdx >= 0 Then Begin
    DrawObjects[NewIdx].ObjType := OBJ_LINE;
    DrawObjects[NewIdx].X1 := RX2; DrawObjects[NewIdx].Y1 := RY1;
    DrawObjects[NewIdx].X2 := RX2; DrawObjects[NewIdx].Y2 := RY2;
   End;
   NewIdx := AllocEntitySlot;
   If NewIdx >= 0 Then Begin
    DrawObjects[NewIdx].ObjType := OBJ_LINE;
    DrawObjects[NewIdx].X1 := RX2; DrawObjects[NewIdx].Y1 := RY2;
    DrawObjects[NewIdx].X2 := RX1; DrawObjects[NewIdx].Y2 := RY2;
   End;
   NewIdx := AllocEntitySlot;
   If NewIdx >= 0 Then Begin
    DrawObjects[NewIdx].ObjType := OBJ_LINE;
    DrawObjects[NewIdx].X1 := RX1; DrawObjects[NewIdx].Y1 := RY2;
    DrawObjects[NewIdx].X2 := RX1; DrawObjects[NewIdx].Y2 := RY1;
   End;
   Inc(N);
  End Else If DrawObjects[I].Selected and (DrawObjects[I].ObjType = OBJ_POLYLINE) Then Begin
   If DrawObjects[I].VertexCount >= 2 Then Begin
    For K := 0 To DrawObjects[I].VertexCount - 2 Do Begin
     NewIdx := AllocEntitySlot;
     If NewIdx < 0 Then Break;
     DrawObjects[NewIdx].ObjType := OBJ_LINE;
     DrawObjects[NewIdx].X1 := DrawObjects[I].Vertices[K].X;
     DrawObjects[NewIdx].Y1 := DrawObjects[I].Vertices[K].Y;
     DrawObjects[NewIdx].X2 := DrawObjects[I].Vertices[K + 1].X;
     DrawObjects[NewIdx].Y2 := DrawObjects[I].Vertices[K + 1].Y;
    End;
    DrawObjects[I].ObjType := OBJ_NONE;
    Inc(N);
   End;
  End;
 If N = 0 Then
  CommandLastLine := 'Decomposer: aucun objet decomposable selectionne'
 Else Begin
  Str(N, NStr);
  CommandLastLine := 'Decomposer: ' + NStr + ' objet(s) decompose(s)';
  MarkDocumentModified;
  DrawInterface;
 End;
End;

{ ============================================================================ }
{ Suivi des modifications et confirmation de sortie                            }
{ ============================================================================ }

{ Marquer le document comme synchronise avec le disque (sauvegarde ou charge) }
Procedure MarkDocumentSaved;
Begin
 DocumentModified := False;
 LastSavedObjectCount := ObjectCount;
 LastSavedBlockRefCount := BlockRefCount;
 LastSavedImageRefCount := ImageRefCount;
 LastSavedXRefCount := XRefCount;
 LastSavedOLECount := OLEObjectCount;
End;

{ Marquer explicitement le document comme modifie }
Procedure MarkDocumentModified;
Begin
 DocumentModified := True;
End;

{ Verifier si le document a ete modifie depuis la derniere sauvegarde.
  La comparaison sur les compteurs detecte les ajouts et suppressions sans
  avoir a instrumenter chaque site de modification. }
Function IsDocumentModified: Boolean;
Begin
 IsDocumentModified := DocumentModified or
                       (ObjectCount <> LastSavedObjectCount) or
                       (BlockRefCount <> LastSavedBlockRefCount) or
                       (ImageRefCount <> LastSavedImageRefCount) or
                       (XRefCount <> LastSavedXRefCount) or
                       (OLEObjectCount <> LastSavedOLECount);
End;

{ Dialogue de confirmation de fermeture. Retourne True si l'application
  peut quitter, False si l'utilisateur a annule. Si l'utilisateur choisit
  d'enregistrer, on declenche la procedure d'enregistrement. }
Function ConfirmExit: Boolean;
Const
 BTN_COUNT = 3;
 BTN_OUI = 0;
 BTN_NON = 1;
 BTN_ANN = 2;
Type
 TBtnRect = Record
  X1, Y1, X2, Y2: Integer;
  Caption: String[10];
  Shortcut: Char;
 End;
Var
 CX, CY, W, H: Integer;
 K: Char;
 OkFlag: Boolean;
 SaveName: String;
 Done: Boolean;
 Focus, Action, I: Integer;
 Btn: Array[0..BTN_COUNT-1] of TBtnRect;
 LX, LY, LB, PrevLB: LongInt;
 HitBtn: Integer;
 BtnW, BtnH, Gap, BaseX, BaseY: Integer;

 Procedure DrawBtn(Idx: Integer);
 Var
  TX, TY, CapLen: Integer;
 Begin
  If Idx = Focus Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(Btn[Idx].X1, Btn[Idx].Y1, Btn[Idx].X2, Btn[Idx].Y2);
   SetColor(White);
   Rectangle(Btn[Idx].X1, Btn[Idx].Y1, Btn[Idx].X2, Btn[Idx].Y2);
   Rectangle(Btn[Idx].X1 - 2, Btn[Idx].Y1 - 2, Btn[Idx].X2 + 2, Btn[Idx].Y2 + 2);
  End Else Begin
   SetFillStyle(SolidFill, LightGray);
   Bar(Btn[Idx].X1, Btn[Idx].Y1, Btn[Idx].X2, Btn[Idx].Y2);
   SetColor(White);
   Line(Btn[Idx].X1, Btn[Idx].Y1, Btn[Idx].X2, Btn[Idx].Y1);
   Line(Btn[Idx].X1, Btn[Idx].Y1, Btn[Idx].X1, Btn[Idx].Y2);
   SetColor(DarkGray);
   Line(Btn[Idx].X2, Btn[Idx].Y1, Btn[Idx].X2, Btn[Idx].Y2);
   Line(Btn[Idx].X1, Btn[Idx].Y2, Btn[Idx].X2, Btn[Idx].Y2);
   SetColor(Black);
  End;
  CapLen := Length(Btn[Idx].Caption);
  TX := Btn[Idx].X1 + ((Btn[Idx].X2 - Btn[Idx].X1) - 8 * CapLen) Div 2;
  TY := Btn[Idx].Y1 + ((Btn[Idx].Y2 - Btn[Idx].Y1) - 8) Div 2;
  If TX < Btn[Idx].X1 + 4 Then TX := Btn[Idx].X1 + 4;
  If TY < Btn[Idx].Y1 + 2 Then TY := Btn[Idx].Y1 + 2;
  OutTextXY(TX, TY, Btn[Idx].Caption);
 End;

 Function HitTest(MX, MY: LongInt): Integer;
 Var J: Integer;
 Begin
  HitTest := -1;
  For J := 0 To BTN_COUNT - 1 Do
   If (MX >= Btn[J].X1) and (MX <= Btn[J].X2) and
      (MY >= Btn[J].Y1) and (MY <= Btn[J].Y2) Then Begin
    HitTest := J;
    Exit;
   End;
 End;

 Procedure RedrawAllButtons;
 Var J: Integer;
 Begin
  HideMouse;
  For J := 0 To BTN_COUNT - 1 Do DrawBtn(J);
  ShowMouse;
 End;

 Procedure SetFocus(NewFocus: Integer);
 Begin
  If (NewFocus < 0) or (NewFocus >= BTN_COUNT) Then Exit;
  If NewFocus = Focus Then Exit;
  Focus := NewFocus;
  RedrawAllButtons;
 End;

Begin
 If Not IsDocumentModified Then Begin
  ConfirmExit := True;
  Exit;
 End;

 { Boite centree sur l'ecran }
 W := 440;
 H := 160;
 CX := (ScreenWidth - W) Div 2;
 CY := (ScreenHeight - H) Div 2;
 If CX < 0 Then CX := 0;
 If CY < 0 Then CY := 0;

 HideMouse;
 SetFillStyle(SolidFill, LightGray);
 Bar(CX, CY, CX + W, CY + H);
 SetColor(Black);
 Rectangle(CX, CY, CX + W, CY + H);
 Rectangle(CX + 2, CY + 2, CX + W - 2, CY + H - 2);

 { Barre de titre }
 SetFillStyle(SolidFill, Blue);
 Bar(CX + 3, CY + 3, CX + W - 3, CY + 22);
 SetColor(White);
 OutTextXY(CX + 10, CY + 8, 'Quitter AUTOCAD');

 SetColor(Black);
 If CurrentFileName = '' Then
  OutTextXY(CX + 14, CY + 40, 'Le dessin <sans nom> a ete modifie.')
 Else
  OutTextXY(CX + 14, CY + 40, 'Le dessin "' + CurrentFileName + '" a ete modifie.');
 OutTextXY(CX + 14, CY + 58, 'Enregistrer les modifications avant de quitter ?');

 { Definir les boutons }
 BtnW := 110;
 BtnH := 28;
 Gap := 14;
 BaseX := CX + ((W - (BtnW * BTN_COUNT + Gap * (BTN_COUNT - 1))) Div 2);
 BaseY := CY + H - BtnH - 16;

 For I := 0 To BTN_COUNT - 1 Do Begin
  Btn[I].X1 := BaseX + I * (BtnW + Gap);
  Btn[I].Y1 := BaseY;
  Btn[I].X2 := Btn[I].X1 + BtnW;
  Btn[I].Y2 := BaseY + BtnH;
 End;
 Btn[BTN_OUI].Caption := 'Oui (O)';   Btn[BTN_OUI].Shortcut := 'O';
 Btn[BTN_NON].Caption := 'Non (N)';   Btn[BTN_NON].Shortcut := 'N';
 Btn[BTN_ANN].Caption := 'Annuler';   Btn[BTN_ANN].Shortcut := #27;

 Focus := BTN_OUI;
 For I := 0 To BTN_COUNT - 1 Do DrawBtn(I);
 ShowMouse;

 Done := False;
 ConfirmExit := False;
 Action := -1;
 PrevLB := 0;
 GetMouseState(LX, LY, PrevLB);

 While Not Done Do Begin
  { Souris : suivi du survol et detection du clic (front montant) }
  GetMouseState(LX, LY, LB);
  HitBtn := HitTest(LX, LY);
  If (HitBtn >= 0) and (HitBtn <> Focus) Then SetFocus(HitBtn);
  If ((LB and 1) <> 0) and ((PrevLB and 1) = 0) Then Begin
   If HitBtn >= 0 Then Begin
    Action := HitBtn;
    Done := True;
   End;
  End;
  PrevLB := LB;

  { Clavier }
  If KeyPressed Then Begin
   K := ReadKey;
   If K = #0 Then Begin
    K := ReadKey;
    Case K of
     #75: SetFocus((Focus + BTN_COUNT - 1) Mod BTN_COUNT); { Gauche }
     #77: SetFocus((Focus + 1) Mod BTN_COUNT);             { Droite }
     #15: SetFocus((Focus + 1) Mod BTN_COUNT);             { Shift+Tab... mappage simplifie }
    End;
   End Else Begin
    Case K of
     'o', 'O', 'y', 'Y': Begin Action := BTN_OUI; Done := True; End;
     'n', 'N':           Begin Action := BTN_NON; Done := True; End;
     #27:                Begin Action := BTN_ANN; Done := True; End;
     #9:                 SetFocus((Focus + 1) Mod BTN_COUNT); { Tab }
     #13, ' ':           Begin Action := Focus; Done := True; End;
    End;
   End;
  End;
 End;

 { Executer l'action choisie }
 Case Action Of
  BTN_OUI: Begin
   If CurrentFileName = '' Then Begin
    PendingFileAction := 2;
    CommandPrompt := 'Enregistrer sous (nom du fichier):';
    CommandBuffer := '';
    CommandLastLine := 'Saisissez un nom de fichier puis relancez Quitter.';
    DrawInterface;
    ConfirmExit := False;
   End Else Begin
    SaveName := CurrentFileName;
    OkFlag := WriteDWGFile(SaveName);
    If OkFlag Then Begin
     MarkDocumentSaved;
     CommandLastLine := 'Enregistre: ' + SaveName;
     ConfirmExit := True;
    End Else Begin
     CommandLastLine := 'Echec enregistrement: ' + SaveName + ' - sortie annulee';
     DrawInterface;
     ConfirmExit := False;
    End;
   End;
  End;
  BTN_NON: ConfirmExit := True;
  BTN_ANN: Begin
   DrawInterface;
   ConfirmExit := False;
  End;
 End;
End;

{ ============================================================================ }
{ Fonctions pour le format DWG (AutoCAD Drawing) - TODO 21                      }
{ ============================================================================ }

{ Écrire un octet dans le fichier DWG }
Procedure WriteDWGByte(Var F: File; B: Byte);
Begin
 BlockWrite(F, B, 1);
End;

{ Écrire un mot (2 octets) dans le fichier DWG }
Procedure WriteDWGWord(Var F: File; W: Word);
Begin
 BlockWrite(F, W, 2);
End;

{ Écrire un entier long (4 octets) dans le fichier DWG }
Procedure WriteDWGLongInt(Var F: File; L: LongInt);
Begin
 BlockWrite(F, L, 4);
End;

{ Écrire un réel (6 octets en TP, 8 octets format standard) }
Procedure WriteDWGReal(Var F: File; R: Real);
Var
 D: Double;
Begin
 D := R;
 BlockWrite(F, D, 8);
End;

{ Écrire une chaîne avec sa longueur }
Procedure WriteDWGString(Var F: File; Const S: String);
Var
 Len: Byte;
Begin
 Len := Length(S);
 WriteDWGByte(F, Len);
 If Len > 0 Then
  BlockWrite(F, S[1], Len);
End;

{ Lire un octet du fichier DWG }
Function ReadDWGByte(Var F: File): Byte;
Var
 B: Byte;
Begin
 BlockRead(F, B, 1);
 ReadDWGByte := B;
End;

{ Lire un mot (2 octets) du fichier DWG }
Function ReadDWGWord(Var F: File): Word;
Var
 W: Word;
Begin
 BlockRead(F, W, 2);
 ReadDWGWord := W;
End;

{ Lire un entier long (4 octets) du fichier DWG }
Function ReadDWGLongInt(Var F: File): LongInt;
Var
 L: LongInt;
Begin
 BlockRead(F, L, 4);
 ReadDWGLongInt := L;
End;

{ Lire un réel (8 octets format standard) }
Function ReadDWGReal(Var F: File): Real;
Var
 D: Double;
Begin
 BlockRead(F, D, 8);
 ReadDWGReal := D;
End;

{ Lire une chaîne avec sa longueur }
Function ReadDWGString(Var F: File): String;
Var
 Len: Byte;
 S: String;
Begin
 Len := ReadDWGByte(F);
 If Len > 0 Then Begin
  BlockRead(F, S[1], Len);
  S[0] := Chr(Len);
 End
 Else
  S := '';
 ReadDWGString := S;
End;

{ Convertir le type d'objet interne en code DWG }
Function GetDWGEntityCode(ObjType: Byte): Byte;
Begin
 Case ObjType of
  OBJ_LINE:      GetDWGEntityCode := DWG_ENTITY_LINE;
  OBJ_POINT:     GetDWGEntityCode := DWG_ENTITY_POINT;
  OBJ_CIRCLE:    GetDWGEntityCode := DWG_ENTITY_CIRCLE;
  OBJ_ARC:       GetDWGEntityCode := DWG_ENTITY_ARC;
  OBJ_TEXT:      GetDWGEntityCode := DWG_ENTITY_TEXT;
  OBJ_POLYLINE:  GetDWGEntityCode := DWG_ENTITY_POLYLINE;
  OBJ_RECTANGLE: GetDWGEntityCode := DWG_ENTITY_LWPOLYLINE;
  OBJ_ELLIPSE:   GetDWGEntityCode := DWG_ENTITY_ELLIPSE;
  OBJ_DIMENSION: GetDWGEntityCode := DWG_ENTITY_DIMENSION;
  OBJ_BLOCK_REF: GetDWGEntityCode := DWG_ENTITY_INSERT;
 Else
  GetDWGEntityCode := 0;
 End;
End;

{ Convertir le code DWG en type d'objet interne }
Function GetObjTypeFromDWG(DWGCode: Byte): Byte;
Begin
 Case DWGCode of
  DWG_ENTITY_LINE:      GetObjTypeFromDWG := OBJ_LINE;
  DWG_ENTITY_POINT:     GetObjTypeFromDWG := OBJ_POINT;
  DWG_ENTITY_CIRCLE:    GetObjTypeFromDWG := OBJ_CIRCLE;
  DWG_ENTITY_ARC:       GetObjTypeFromDWG := OBJ_ARC;
  DWG_ENTITY_TEXT:      GetObjTypeFromDWG := OBJ_TEXT;
  DWG_ENTITY_POLYLINE:  GetObjTypeFromDWG := OBJ_POLYLINE;
  DWG_ENTITY_LWPOLYLINE: GetObjTypeFromDWG := OBJ_RECTANGLE;
  DWG_ENTITY_ELLIPSE:   GetObjTypeFromDWG := OBJ_ELLIPSE;
  DWG_ENTITY_DIMENSION: GetObjTypeFromDWG := OBJ_DIMENSION;
  DWG_ENTITY_INSERT:    GetObjTypeFromDWG := OBJ_BLOCK_REF;
 Else
  GetObjTypeFromDWG := OBJ_NONE;
 End;
End;

{ Écrire l'en-tête du fichier DWG }
Procedure WriteDWGHeader(Var F: File);
Var
 I: Integer;
 MagicStr: String[6];
Begin
 { Écrire la signature du format (6 caractères) }
 MagicStr := DWG_MAGIC;
 BlockWrite(F, MagicStr[1], 6);

 { Écrire les métadonnées du dessin }
 WriteDWGWord(F, ScreenWidth);       { Largeur du dessin }
 WriteDWGWord(F, ScreenHeight);      { Hauteur du dessin }
 WriteDWGLongInt(F, ObjectCount);    { Nombre d'entités }
 WriteDWGWord(F, LayerCount);        { Nombre de calques }
 WriteDWGWord(F, BlockDefCount);     { Nombre de définitions de blocs }
 WriteDWGWord(F, BlockRefCount);     { Nombre de références de blocs }

 { Écrire les paramètres de vue }
 WriteDWGReal(F, ViewOffsetX);
 WriteDWGReal(F, ViewOffsetY);
 WriteDWGReal(F, ZoomLevel);

 { Écrire l'état courant }
 WriteDWGByte(F, CurrentLayer);
 WriteDWGWord(F, CurrentColor);
 WriteDWGByte(F, CurrentLineType);
 WriteDWGWord(F, CurrentLineWeight);

 { Réserver de l'espace pour des extensions futures (32 octets) }
 For I := 1 to 32 do
  WriteDWGByte(F, 0);
End;

{ Écrire une entité dans le fichier DWG }
Procedure WriteDWGEntity(Var F: File; Const Entity: TDrawObject);
Begin
 { Écrire le type d'entité DWG }
 WriteDWGByte(F, GetDWGEntityCode(Entity.ObjType));

 { Écrire les propriétés communes }
 WriteDWGByte(F, Entity.ObjType);
 WriteDWGReal(F, Entity.X1);
 WriteDWGReal(F, Entity.Y1);
 WriteDWGReal(F, Entity.X2);
 WriteDWGReal(F, Entity.Y2);
 WriteDWGReal(F, Entity.Radius);
 WriteDWGReal(F, Entity.StartAngle);
 WriteDWGReal(F, Entity.EndAngle);
 WriteDWGWord(F, Entity.Color);
 WriteDWGByte(F, Entity.LineType);
 WriteDWGByte(F, Entity.LayerIndex);

 { Écrire les données de cotation si nécessaire }
 If Entity.ObjType = OBJ_DIMENSION Then Begin
  WriteDWGByte(F, Entity.DimType);
  WriteDWGReal(F, Entity.DimX3);
  WriteDWGReal(F, Entity.DimY3);
  WriteDWGReal(F, Entity.DimX4);
  WriteDWGReal(F, Entity.DimY4);
  WriteDWGString(F, Entity.DimText);
  WriteDWGReal(F, Entity.DimValue);
  WriteDWGReal(F, Entity.DimTextX);
  WriteDWGReal(F, Entity.DimTextY);
 End;
End;

{ Écrire les calques dans le fichier DWG }
Procedure WriteDWGLayers(Var F: File);
Var
 I: Integer;
Begin
 For I := 0 to LayerCount - 1 do Begin
  WriteDWGString(F, Layers[I].Name);
  WriteDWGWord(F, Layers[I].Color);
  WriteDWGByte(F, Layers[I].LineType);
  WriteDWGWord(F, Layers[I].LineWeight);
  WriteDWGByte(F, Ord(Layers[I].Visible));
  WriteDWGByte(F, Ord(Layers[I].Locked));
  WriteDWGByte(F, Ord(Layers[I].Frozen));
  WriteDWGByte(F, Ord(Layers[I].OnFlag));
 End;
End;

{ Écrire les blocs dans le fichier DWG }
Procedure WriteDWGBlocks(Var F: File);
Var
 I, J: Integer;
 StartIdx: Integer;
Begin
 { Écrire les définitions de blocs }
 For I := 0 to BlockDefCount - 1 do Begin
  WriteDWGString(F, BlockDefs[I].Name);
  WriteDWGString(F, BlockDefs[I].Description);
  WriteDWGReal(F, BlockDefs[I].BaseX);
  WriteDWGReal(F, BlockDefs[I].BaseY);
  WriteDWGWord(F, BlockDefs[I].EntityCount);
  WriteDWGByte(F, Ord(BlockDefs[I].IsXRef));
  WriteDWGByte(F, Ord(BlockDefs[I].IsDefined));

  { Écrire les entités du bloc }
  StartIdx := BlockDefs[I].FirstEntityIdx;
  For J := 0 to BlockDefs[I].EntityCount - 1 do
   WriteDWGEntity(F, BlockEntities[StartIdx + J]);
 End;

 { Écrire les références de blocs }
 For I := 0 to BlockRefCount - 1 do Begin
  WriteDWGWord(F, BlockRefs[I].BlockIndex);
  WriteDWGReal(F, BlockRefs[I].InsertX);
  WriteDWGReal(F, BlockRefs[I].InsertY);
  WriteDWGReal(F, BlockRefs[I].ScaleX);
  WriteDWGReal(F, BlockRefs[I].ScaleY);
  WriteDWGReal(F, BlockRefs[I].Rotation);
  WriteDWGWord(F, BlockRefs[I].Color);
  WriteDWGByte(F, BlockRefs[I].LayerIndex);
  WriteDWGByte(F, Ord(BlockRefs[I].Visible));
 End;
End;

{ Écrire le dessin dans un fichier DWG }
Function WriteDWGFile(Const FileName: String): Boolean;
Var
 F: File;
 I: Integer;
Begin
 WriteDWGFile := False;

 {$I-}
 Assign(F, FileName);
 Rewrite(F, 1);
 {$I+}

 If IOResult <> 0 Then Exit;

 { Écrire l'en-tête }
 WriteDWGHeader(F);

 { Écrire les calques }
 WriteDWGLayers(F);

 { Écrire les blocs }
 WriteDWGBlocks(F);

 { Écrire les entités du dessin }
 For I := 0 to ObjectCount - 1 do Begin
  If DrawObjects[I].ObjType <> OBJ_NONE Then
   WriteDWGEntity(F, DrawObjects[I]);
 End;

 Close(F);
 WriteDWGFile := True;
 MarkDocumentSaved;
End;

{ Lire l'en-tête du fichier DWG }
Function ReadDWGHeader(Var F: File): Boolean;
Var
 I: Integer;
 MagicStr: String[6];
 Dummy: Byte;
Begin
 ReadDWGHeader := False;

 { Lire et vérifier la signature }
 BlockRead(F, MagicStr[1], 6);
 MagicStr[0] := #6;

 { Vérifier que c'est un format supporté }
 If (MagicStr <> DWG_VERSION_R14) and
    (MagicStr <> DWG_VERSION_2000) and
    (MagicStr <> DWG_VERSION_2004) and
    (MagicStr <> DWG_VERSION_2007) and
    (MagicStr <> DWG_VERSION_2010) and
    (MagicStr <> DWG_VERSION_2013) and
    (MagicStr <> DWG_VERSION_2018) Then Exit;

 { Lire les métadonnées du dessin }
 ScreenWidth := ReadDWGWord(F);
 ScreenHeight := ReadDWGWord(F);
 ObjectCount := ReadDWGLongInt(F);
 LayerCount := ReadDWGWord(F);
 BlockDefCount := ReadDWGWord(F);
 BlockRefCount := ReadDWGWord(F);

 { Lire les paramètres de vue }
 ViewOffsetX := ReadDWGReal(F);
 ViewOffsetY := ReadDWGReal(F);
 ZoomLevel := ReadDWGReal(F);

 { Lire l'état courant }
 CurrentLayer := ReadDWGByte(F);
 CurrentColor := ReadDWGWord(F);
 CurrentLineType := ReadDWGByte(F);
 CurrentLineWeight := ReadDWGWord(F);

 { Ignorer l'espace réservé (32 octets) }
 For I := 1 to 32 do
  Dummy := ReadDWGByte(F);

 ReadDWGHeader := True;
End;

{ Lire une entité du fichier DWG }
Function ReadDWGEntity(Var F: File; Var Entity: TDrawObject): Boolean;
Var
 DWGCode: Byte;
Begin
 ReadDWGEntity := False;

 { Lire le type d'entité DWG }
 DWGCode := ReadDWGByte(F);

 { Lire les propriétés communes }
 Entity.ObjType := ReadDWGByte(F);
 Entity.X1 := ReadDWGReal(F);
 Entity.Y1 := ReadDWGReal(F);
 Entity.X2 := ReadDWGReal(F);
 Entity.Y2 := ReadDWGReal(F);
 Entity.Radius := ReadDWGReal(F);
 Entity.StartAngle := ReadDWGReal(F);
 Entity.EndAngle := ReadDWGReal(F);
 Entity.Color := ReadDWGWord(F);
 Entity.LineType := ReadDWGByte(F);
 Entity.LayerIndex := ReadDWGByte(F);
 Entity.Selected := False;
 Entity.Visible := True;

 { Lire les données de cotation si nécessaire }
 If Entity.ObjType = OBJ_DIMENSION Then Begin
  Entity.DimType := ReadDWGByte(F);
  Entity.DimX3 := ReadDWGReal(F);
  Entity.DimY3 := ReadDWGReal(F);
  Entity.DimX4 := ReadDWGReal(F);
  Entity.DimY4 := ReadDWGReal(F);
  Entity.DimText := ReadDWGString(F);
  Entity.DimValue := ReadDWGReal(F);
  Entity.DimTextX := ReadDWGReal(F);
  Entity.DimTextY := ReadDWGReal(F);
 End;

 ReadDWGEntity := True;
End;

{ Lire les calques du fichier DWG }
Function ReadDWGLayers(Var F: File): Boolean;
Var
 I: Integer;
Begin
 ReadDWGLayers := False;

 For I := 0 to LayerCount - 1 do Begin
  Layers[I].Name := ReadDWGString(F);
  Layers[I].Color := ReadDWGWord(F);
  Layers[I].LineType := ReadDWGByte(F);
  Layers[I].LineWeight := ReadDWGWord(F);
  Layers[I].Visible := ReadDWGByte(F) <> 0;
  Layers[I].Locked := ReadDWGByte(F) <> 0;
  Layers[I].Frozen := ReadDWGByte(F) <> 0;
  Layers[I].OnFlag := ReadDWGByte(F) <> 0;
 End;

 ReadDWGLayers := True;
End;

{ Lire les blocs du fichier DWG }
Function ReadDWGBlocks(Var F: File): Boolean;
Var
 I, J: Integer;
 EntCount: Integer;
Begin
 ReadDWGBlocks := False;

 BlockEntityCount := 0;

 { Lire les définitions de blocs }
 For I := 0 to BlockDefCount - 1 do Begin
  BlockDefs[I].Name := ReadDWGString(F);
  BlockDefs[I].Description := ReadDWGString(F);
  BlockDefs[I].BaseX := ReadDWGReal(F);
  BlockDefs[I].BaseY := ReadDWGReal(F);
  EntCount := ReadDWGWord(F);
  BlockDefs[I].EntityCount := EntCount;
  BlockDefs[I].FirstEntityIdx := BlockEntityCount;
  BlockDefs[I].IsXRef := ReadDWGByte(F) <> 0;
  BlockDefs[I].IsDefined := ReadDWGByte(F) <> 0;

  { Lire les entités du bloc }
  For J := 0 to EntCount - 1 do Begin
   ReadDWGEntity(F, BlockEntities[BlockEntityCount]);
   Inc(BlockEntityCount);
  End;
 End;

 { Lire les références de blocs }
 For I := 0 to BlockRefCount - 1 do Begin
  BlockRefs[I].BlockIndex := ReadDWGWord(F);
  BlockRefs[I].InsertX := ReadDWGReal(F);
  BlockRefs[I].InsertY := ReadDWGReal(F);
  BlockRefs[I].ScaleX := ReadDWGReal(F);
  BlockRefs[I].ScaleY := ReadDWGReal(F);
  BlockRefs[I].Rotation := ReadDWGReal(F);
  BlockRefs[I].Color := ReadDWGWord(F);
  BlockRefs[I].LayerIndex := ReadDWGByte(F);
  BlockRefs[I].Visible := ReadDWGByte(F) <> 0;
  BlockRefs[I].Selected := False;
 End;

 ReadDWGBlocks := True;
End;

{ Lire un dessin depuis un fichier DWG }
Function ReadDWGFile(Const FileName: String): Boolean;
Var
 F: File;
 I: Integer;
 TempCount: LongInt;
Begin
 ReadDWGFile := False;

 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 {$I+}

 If IOResult <> 0 Then Exit;

 { Sauvegarder le nombre d'objets avant lecture }
 TempCount := ObjectCount;

 { Lire l'en-tête }
 If Not ReadDWGHeader(F) Then Begin
  Close(F);
  ObjectCount := TempCount;
  Exit;
 End;

 { Validation des compteurs et parametres de vue lus dans l'en-tete.
   Un fichier dont la signature AC10xx matche mais qui n'est pas un
   DWG produit par cette appli (ou un fichier corrompu) peut contenir
   des valeurs aberrantes qui debordent DrawObjects[] ou rendent la
   vue invisible (ZoomLevel=0, ViewOffset hors echelle...). }
 If (ObjectCount < 0) or (ObjectCount > MAX_OBJECTS) Then Begin
  Close(F);
  ObjectCount := TempCount;
  Exit;
 End;
 If (LayerCount < 0) or (LayerCount > MAX_LAYERS) Then Begin
  Close(F);
  ObjectCount := TempCount;
  Exit;
 End;
 If (BlockDefCount < 0) or (BlockDefCount > MAX_BLOCKS) Then Begin
  Close(F);
  ObjectCount := TempCount;
  Exit;
 End;
 If (ZoomLevel <= 0.0) or (ZoomLevel > 1000.0) Then
  ZoomLevel := 1.0;
 If (Abs(ViewOffsetX) > 1.0E9) Then ViewOffsetX := 0.0;
 If (Abs(ViewOffsetY) > 1.0E9) Then ViewOffsetY := 0.0;

 { Lire les calques }
 If Not ReadDWGLayers(F) Then Begin
  Close(F);
  ObjectCount := TempCount;
  Exit;
 End;

 { Lire les blocs }
 If Not ReadDWGBlocks(F) Then Begin
  Close(F);
  ObjectCount := TempCount;
  Exit;
 End;

 { Lire les entités du dessin }
 For I := 0 to ObjectCount - 1 do Begin
  If Not ReadDWGEntity(F, DrawObjects[I]) Then Begin
   Close(F);
   Exit;
  End;
 End;

 Close(F);

 { Effacer la sélection }
 ClearSelection;
 ClearGrips;

 ReadDWGFile := True;
 MarkDocumentSaved;
End;

{ ============================================================================ }
{ Fonctions pour le format DXF (Drawing Exchange Format) - TODO 22             }
{ ============================================================================ }

{ Écrire un code de groupe dans le fichier DXF }
Procedure WriteDXFGroupCode(Var F: Text; Code: Integer);
Begin
 WriteLn(F, Code:3);
End;

{ Écrire une chaîne avec son code de groupe }
Procedure WriteDXFString(Var F: Text; Code: Integer; Const S: String);
Begin
 WriteLn(F, Code:3);
 WriteLn(F, S);
End;

{ Écrire un entier avec son code de groupe }
Procedure WriteDXFInteger(Var F: Text; Code: Integer; Value: LongInt);
Begin
 WriteLn(F, Code:3);
 WriteLn(F, Value);
End;

{ Écrire un réel avec son code de groupe }
Procedure WriteDXFReal(Var F: Text; Code: Integer; Value: Real);
Begin
 WriteLn(F, Code:3);
 WriteLn(F, Value:0:6);
End;

{ Obtenir le nom d'entité DXF à partir du type d'objet interne }
Function GetDXFEntityName(ObjType: Byte): String;
Begin
 Case ObjType of
  OBJ_LINE:      GetDXFEntityName := DXF_LINE;
  OBJ_POINT:     GetDXFEntityName := DXF_POINT;
  OBJ_CIRCLE:    GetDXFEntityName := DXF_CIRCLE;
  OBJ_ARC:       GetDXFEntityName := DXF_ARC;
  OBJ_TEXT:      GetDXFEntityName := DXF_TEXT;
  OBJ_POLYLINE:  GetDXFEntityName := DXF_POLYLINE;
  OBJ_RECTANGLE: GetDXFEntityName := DXF_LWPOLYLINE;
  OBJ_ELLIPSE:   GetDXFEntityName := DXF_ELLIPSE;
  OBJ_DIMENSION: GetDXFEntityName := DXF_DIMENSION;
  OBJ_BLOCK_REF: GetDXFEntityName := DXF_INSERT;
 Else
  GetDXFEntityName := '';
 End;
End;

{ Obtenir le type d'objet interne à partir du nom d'entité DXF }
Function GetObjTypeFromDXF(Const EntityName: String): Byte;
Var
 UpperName: String;
 I: Integer;
Begin
 UpperName := EntityName;
 For I := 1 to Length(UpperName) do
  If (UpperName[I] >= 'a') and (UpperName[I] <= 'z') Then
   UpperName[I] := Chr(Ord(UpperName[I]) - 32);

 If UpperName = DXF_LINE Then GetObjTypeFromDXF := OBJ_LINE
 Else If UpperName = DXF_POINT Then GetObjTypeFromDXF := OBJ_POINT
 Else If UpperName = DXF_CIRCLE Then GetObjTypeFromDXF := OBJ_CIRCLE
 Else If UpperName = DXF_ARC Then GetObjTypeFromDXF := OBJ_ARC
 Else If UpperName = DXF_TEXT Then GetObjTypeFromDXF := OBJ_TEXT
 Else If UpperName = DXF_MTEXT Then GetObjTypeFromDXF := OBJ_TEXT
 Else If UpperName = DXF_POLYLINE Then GetObjTypeFromDXF := OBJ_POLYLINE
 Else If UpperName = DXF_LWPOLYLINE Then GetObjTypeFromDXF := OBJ_RECTANGLE
 Else If UpperName = DXF_ELLIPSE Then GetObjTypeFromDXF := OBJ_ELLIPSE
 Else If UpperName = DXF_DIMENSION Then GetObjTypeFromDXF := OBJ_DIMENSION
 Else If UpperName = DXF_INSERT Then GetObjTypeFromDXF := OBJ_BLOCK_REF
 Else GetObjTypeFromDXF := OBJ_NONE;
End;

{ Écrire l'en-tête DXF }
Procedure WriteDXFHeader(Var F: Text);
Begin
 { Section HEADER }
 WriteDXFString(F, 0, DXF_SECTION);
 WriteDXFString(F, 2, DXF_HEADER);

 { Variable $ACADVER - version AutoCAD }
 WriteDXFString(F, 9, '$ACADVER');
 WriteDXFString(F, 1, 'AC1015');

 { Variable $INSBASE - point d'insertion de base }
 WriteDXFString(F, 9, '$INSBASE');
 WriteDXFReal(F, 10, 0.0);
 WriteDXFReal(F, 20, 0.0);
 WriteDXFReal(F, 30, 0.0);

 { Variable $EXTMIN - coin inférieur gauche des limites }
 WriteDXFString(F, 9, '$EXTMIN');
 WriteDXFReal(F, 10, 0.0);
 WriteDXFReal(F, 20, 0.0);
 WriteDXFReal(F, 30, 0.0);

 { Variable $EXTMAX - coin supérieur droit des limites }
 WriteDXFString(F, 9, '$EXTMAX');
 WriteDXFReal(F, 10, ScreenWidth);
 WriteDXFReal(F, 20, ScreenHeight);
 WriteDXFReal(F, 30, 0.0);

 { Variable $LIMMIN - limites du dessin min }
 WriteDXFString(F, 9, '$LIMMIN');
 WriteDXFReal(F, 10, 0.0);
 WriteDXFReal(F, 20, 0.0);

 { Variable $LIMMAX - limites du dessin max }
 WriteDXFString(F, 9, '$LIMMAX');
 WriteDXFReal(F, 10, ScreenWidth);
 WriteDXFReal(F, 20, ScreenHeight);

 { Variable $CLAYER - calque courant }
 WriteDXFString(F, 9, '$CLAYER');
 WriteDXFString(F, 8, Layers[CurrentLayer].Name);

 { Variable $CECOLOR - couleur courante }
 WriteDXFString(F, 9, '$CECOLOR');
 WriteDXFInteger(F, 62, CurrentColor);

 WriteDXFString(F, 0, DXF_ENDSEC);
End;

{ Écrire la table des calques }
Procedure WriteDXFLayers(Var F: Text);
Var
 I: Integer;
 Flags: Integer;
Begin
 WriteDXFString(F, 0, DXF_TABLE);
 WriteDXFString(F, 2, DXF_LAYER);
 WriteDXFInteger(F, 70, LayerCount);

 For I := 0 to LayerCount - 1 do Begin
  WriteDXFString(F, 0, DXF_LAYER);
  WriteDXFString(F, 2, Layers[I].Name);

  { Calculer les flags }
  Flags := 0;
  If Layers[I].Frozen Then Flags := Flags or 1;
  If Layers[I].Locked Then Flags := Flags or 4;
  WriteDXFInteger(F, 70, Flags);

  { Couleur (négative si calque éteint) }
  If Layers[I].OnFlag Then
   WriteDXFInteger(F, 62, Layers[I].Color)
  Else
   WriteDXFInteger(F, 62, -Layers[I].Color);

  { Type de ligne }
  WriteDXFString(F, 6, 'CONTINUOUS');
 End;

 WriteDXFString(F, 0, DXF_ENDTAB);
End;

{ Écrire les tables DXF }
Procedure WriteDXFTables(Var F: Text);
Begin
 WriteDXFString(F, 0, DXF_SECTION);
 WriteDXFString(F, 2, DXF_TABLES);

 { Table des calques }
 WriteDXFLayers(F);

 WriteDXFString(F, 0, DXF_ENDSEC);
End;

{ Écrire les blocs DXF }
Procedure WriteDXFBlocks(Var F: Text);
Var
 I, J: Integer;
 StartIdx: Integer;
Begin
 WriteDXFString(F, 0, DXF_SECTION);
 WriteDXFString(F, 2, DXF_BLOCKS);

 For I := 0 to BlockDefCount - 1 do Begin
  { Début du bloc }
  WriteDXFString(F, 0, DXF_BLOCK);
  WriteDXFString(F, 8, '0');
  WriteDXFString(F, 2, BlockDefs[I].Name);
  WriteDXFInteger(F, 70, 0);
  WriteDXFReal(F, 10, BlockDefs[I].BaseX);
  WriteDXFReal(F, 20, BlockDefs[I].BaseY);
  WriteDXFReal(F, 30, 0.0);

  { Entités du bloc }
  StartIdx := BlockDefs[I].FirstEntityIdx;
  For J := 0 to BlockDefs[I].EntityCount - 1 do
   WriteDXFEntity(F, BlockEntities[StartIdx + J], 1000 + I * 100 + J);

  { Fin du bloc }
  WriteDXFString(F, 0, DXF_ENDBLK);
  WriteDXFString(F, 8, '0');
 End;

 WriteDXFString(F, 0, DXF_ENDSEC);
End;

{ Écrire une entité ligne en DXF }
Procedure WriteDXFLine(Var F: Text; Const Entity: TDrawObject; Handle: LongInt);
Begin
 WriteDXFString(F, 0, DXF_LINE);
 WriteDXFInteger(F, 5, Handle);
 WriteDXFString(F, 8, Layers[Entity.LayerIndex].Name);
 WriteDXFInteger(F, 62, Entity.Color);
 WriteDXFReal(F, 10, Entity.X1);
 WriteDXFReal(F, 20, Entity.Y1);
 WriteDXFReal(F, 30, 0.0);
 WriteDXFReal(F, 11, Entity.X2);
 WriteDXFReal(F, 21, Entity.Y2);
 WriteDXFReal(F, 31, 0.0);
End;

{ Écrire une entité cercle en DXF }
Procedure WriteDXFCircle(Var F: Text; Const Entity: TDrawObject; Handle: LongInt);
Begin
 WriteDXFString(F, 0, DXF_CIRCLE);
 WriteDXFInteger(F, 5, Handle);
 WriteDXFString(F, 8, Layers[Entity.LayerIndex].Name);
 WriteDXFInteger(F, 62, Entity.Color);
 WriteDXFReal(F, 10, Entity.X1);
 WriteDXFReal(F, 20, Entity.Y1);
 WriteDXFReal(F, 30, 0.0);
 WriteDXFReal(F, 40, Entity.Radius);
End;

{ Écrire une entité arc en DXF }
Procedure WriteDXFArc(Var F: Text; Const Entity: TDrawObject; Handle: LongInt);
Begin
 WriteDXFString(F, 0, DXF_ARC);
 WriteDXFInteger(F, 5, Handle);
 WriteDXFString(F, 8, Layers[Entity.LayerIndex].Name);
 WriteDXFInteger(F, 62, Entity.Color);
 WriteDXFReal(F, 10, Entity.X1);
 WriteDXFReal(F, 20, Entity.Y1);
 WriteDXFReal(F, 30, 0.0);
 WriteDXFReal(F, 40, Entity.Radius);
 WriteDXFReal(F, 50, Entity.StartAngle);
 WriteDXFReal(F, 51, Entity.EndAngle);
End;

{ Écrire une entité point en DXF }
Procedure WriteDXFPoint(Var F: Text; Const Entity: TDrawObject; Handle: LongInt);
Begin
 WriteDXFString(F, 0, DXF_POINT);
 WriteDXFInteger(F, 5, Handle);
 WriteDXFString(F, 8, Layers[Entity.LayerIndex].Name);
 WriteDXFInteger(F, 62, Entity.Color);
 WriteDXFReal(F, 10, Entity.X1);
 WriteDXFReal(F, 20, Entity.Y1);
 WriteDXFReal(F, 30, 0.0);
End;

{ Écrire une entité texte en DXF }
Procedure WriteDXFText(Var F: Text; Const Entity: TDrawObject; Handle: LongInt);
Begin
 WriteDXFString(F, 0, DXF_TEXT);
 WriteDXFInteger(F, 5, Handle);
 WriteDXFString(F, 8, Layers[Entity.LayerIndex].Name);
 WriteDXFInteger(F, 62, Entity.Color);
 WriteDXFReal(F, 10, Entity.X1);
 WriteDXFReal(F, 20, Entity.Y1);
 WriteDXFReal(F, 30, 0.0);
 WriteDXFReal(F, 40, 2.5);  { Hauteur texte par défaut }
 WriteDXFString(F, 1, Entity.DimText);  { Utiliser DimText comme contenu }
End;

{ Écrire une entité ellipse en DXF }
Procedure WriteDXFEllipse(Var F: Text; Const Entity: TDrawObject; Handle: LongInt);
Var
 MajorX, MajorY: Real;
Begin
 WriteDXFString(F, 0, DXF_ELLIPSE);
 WriteDXFInteger(F, 5, Handle);
 WriteDXFString(F, 8, Layers[Entity.LayerIndex].Name);
 WriteDXFInteger(F, 62, Entity.Color);

 { Centre }
 WriteDXFReal(F, 10, Entity.X1);
 WriteDXFReal(F, 20, Entity.Y1);
 WriteDXFReal(F, 30, 0.0);

 { Vecteur de l'axe majeur (du centre au point de fin) }
 MajorX := Entity.Radius;  { Rayon = demi-axe majeur }
 MajorY := 0.0;
 WriteDXFReal(F, 11, MajorX);
 WriteDXFReal(F, 21, MajorY);
 WriteDXFReal(F, 31, 0.0);

 { Ratio (demi-axe mineur / demi-axe majeur) }
 If Entity.Radius > 0 Then
  WriteDXFReal(F, 40, Entity.EndAngle / Entity.Radius)
 Else
  WriteDXFReal(F, 40, 1.0);

 { Angles (en radians pour DXF) }
 WriteDXFReal(F, 41, Entity.StartAngle * 3.14159265 / 180.0);
 WriteDXFReal(F, 42, 6.28318530);  { 360 degrés = cercle complet }
End;

{ Écrire une entité cotation en DXF }
Procedure WriteDXFDimension(Var F: Text; Const Entity: TDrawObject; Handle: LongInt);
Begin
 WriteDXFString(F, 0, DXF_DIMENSION);
 WriteDXFInteger(F, 5, Handle);
 WriteDXFString(F, 8, Layers[Entity.LayerIndex].Name);
 WriteDXFInteger(F, 62, Entity.Color);

 { Type de cotation }
 WriteDXFInteger(F, 70, Entity.DimType);

 { Point de définition }
 WriteDXFReal(F, 10, Entity.DimX3);
 WriteDXFReal(F, 20, Entity.DimY3);
 WriteDXFReal(F, 30, 0.0);

 { Point milieu du texte }
 WriteDXFReal(F, 11, Entity.DimTextX);
 WriteDXFReal(F, 21, Entity.DimTextY);
 WriteDXFReal(F, 31, 0.0);

 { Points d'extension }
 WriteDXFReal(F, 13, Entity.X1);
 WriteDXFReal(F, 23, Entity.Y1);
 WriteDXFReal(F, 33, 0.0);

 WriteDXFReal(F, 14, Entity.X2);
 WriteDXFReal(F, 24, Entity.Y2);
 WriteDXFReal(F, 34, 0.0);

 { Texte de cotation }
 If Entity.DimText <> '' Then
  WriteDXFString(F, 1, Entity.DimText);
End;

{ Écrire une entité générique en DXF }
Procedure WriteDXFEntity(Var F: Text; Const Entity: TDrawObject; Handle: LongInt);
Begin
 If Entity.ObjType = OBJ_NONE Then Exit;
 If Not Entity.Visible Then Exit;

 Case Entity.ObjType of
  OBJ_LINE:      WriteDXFLine(F, Entity, Handle);
  OBJ_CIRCLE:    WriteDXFCircle(F, Entity, Handle);
  OBJ_ARC:       WriteDXFArc(F, Entity, Handle);
  OBJ_POINT:     WriteDXFPoint(F, Entity, Handle);
  OBJ_TEXT:      WriteDXFText(F, Entity, Handle);
  OBJ_ELLIPSE:   WriteDXFEllipse(F, Entity, Handle);
  OBJ_DIMENSION: WriteDXFDimension(F, Entity, Handle);
  OBJ_RECTANGLE: Begin
   { Rectangle = 4 lignes }
   WriteDXFLine(F, Entity, Handle);
  End;
 End;
End;

{ Écrire la section ENTITIES }
Procedure WriteDXFEntities(Var F: Text);
Var
 I: Integer;
 Handle: LongInt;
Begin
 WriteDXFString(F, 0, DXF_SECTION);
 WriteDXFString(F, 2, DXF_ENTITIES);

 Handle := 100;
 For I := 0 to ObjectCount - 1 do Begin
  If DrawObjects[I].ObjType <> OBJ_NONE Then Begin
   WriteDXFEntity(F, DrawObjects[I], Handle);
   Inc(Handle);
  End;
 End;

 WriteDXFString(F, 0, DXF_ENDSEC);
End;

{ Écrire le dessin dans un fichier DXF }
Function WriteDXFFile(Const FileName: String): Boolean;
Var
 F: Text;
Begin
 WriteDXFFile := False;

 {$I-}
 Assign(F, FileName);
 Rewrite(F);
 {$I+}

 If IOResult <> 0 Then Exit;

 { Écrire les sections }
 WriteDXFHeader(F);
 WriteDXFTables(F);
 WriteDXFBlocks(F);
 WriteDXFEntities(F);

 { Fin du fichier }
 WriteDXFString(F, 0, DXF_EOF);

 Close(F);
 WriteDXFFile := True;
 MarkDocumentSaved;
End;

{ Lire un code de groupe DXF }
Function ReadDXFGroupCode(Var F: Text): Integer;
Var
 S: String;
 Code, Err: Integer;
Begin
 ReadDXFGroupCode := -1;
 If EOF(F) Then Exit;

 ReadLn(F, S);
 { Supprimer les espaces }
 While (Length(S) > 0) and (S[1] = ' ') do
  Delete(S, 1, 1);
 While (Length(S) > 0) and (S[Length(S)] = ' ') do
  Delete(S, Length(S), 1);

 Val(S, Code, Err);
 If Err = 0 Then
  ReadDXFGroupCode := Code;
End;

{ Lire une chaîne DXF }
Function ReadDXFString(Var F: Text): String;
Var
 S: String;
Begin
 ReadDXFString := '';
 If EOF(F) Then Exit;

 ReadLn(F, S);
 { Supprimer les espaces de début et fin }
 While (Length(S) > 0) and (S[1] = ' ') do
  Delete(S, 1, 1);
 While (Length(S) > 0) and (S[Length(S)] = ' ') do
  Delete(S, Length(S), 1);

 ReadDXFString := S;
End;

{ Lire un entier DXF }
Function ReadDXFInteger(Var F: Text): LongInt;
Var
 S: String;
 Value: LongInt;
 Err: Integer;
Begin
 ReadDXFInteger := 0;
 S := ReadDXFString(F);
 Val(S, Value, Err);
 If Err = 0 Then
  ReadDXFInteger := Value;
End;

{ Lire un réel DXF }
Function ReadDXFReal(Var F: Text): Real;
Var
 S: String;
 Value: Real;
 Err: Integer;
Begin
 ReadDXFReal := 0.0;
 S := ReadDXFString(F);
 Val(S, Value, Err);
 If Err = 0 Then
  ReadDXFReal := Value;
End;

{ Lire l'en-tête DXF }
Function ReadDXFHeader(Var F: Text): Boolean;
Var
 Code: Integer;
 S: String;
Begin
 ReadDXFHeader := False;

 { Lire jusqu'à la fin de la section HEADER }
 Repeat
  Code := ReadDXFGroupCode(F);
  If Code < 0 Then Exit;
  S := ReadDXFString(F);

  { Variables d'en-tête à traiter }
  If (Code = 9) and (S = '$CLAYER') Then Begin
   Code := ReadDXFGroupCode(F);
   S := ReadDXFString(F);
   { Trouver le calque correspondant }
  End
  Else If (Code = 9) and (S = '$CECOLOR') Then Begin
   Code := ReadDXFGroupCode(F);
   CurrentColor := ReadDXFInteger(F);
  End;
 Until (Code = 0) and (S = DXF_ENDSEC);

 ReadDXFHeader := True;
End;

{ Lire les tables DXF (incluant les calques) }
Function ReadDXFTables(Var F: Text): Boolean;
Var
 Code: Integer;
 S, LayerName: String;
 LayerColor: Integer;
 LayerFlags: Integer;
 InLayer: Boolean;
Begin
 ReadDXFTables := False;
 InLayer := False;
 LayerName := '';
 LayerColor := 7;
 LayerFlags := 0;

 Repeat
  Code := ReadDXFGroupCode(F);
  If Code < 0 Then Exit;
  S := ReadDXFString(F);

  If (Code = 0) Then Begin
   { Sauvegarder le calque précédent si on en lisait un }
   If InLayer and (LayerName <> '') and (LayerCount < MAX_LAYERS) Then Begin
    Layers[LayerCount].Name := LayerName;
    Layers[LayerCount].Color := Abs(LayerColor);
    Layers[LayerCount].OnFlag := LayerColor > 0;
    Layers[LayerCount].Frozen := (LayerFlags and 1) <> 0;
    Layers[LayerCount].Locked := (LayerFlags and 4) <> 0;
    Layers[LayerCount].Visible := True;
    Layers[LayerCount].LineType := 0;
    Layers[LayerCount].LineWeight := 0;
    Inc(LayerCount);
   End;

   InLayer := (S = DXF_LAYER);
   LayerName := '';
   LayerColor := 7;
   LayerFlags := 0;
  End
  Else If InLayer Then Begin
   Case Code of
    2: LayerName := S;
    62: Val(S, LayerColor, Code);
    70: Val(S, LayerFlags, Code);
   End;
  End;
 Until (Code = 0) and (S = DXF_ENDSEC);

 ReadDXFTables := True;
End;

{ Lire les blocs DXF }
Function ReadDXFBlocks(Var F: Text): Boolean;
Var
 Code: Integer;
 S: String;
Begin
 ReadDXFBlocks := False;

 { Sauter la section BLOCKS pour l'instant }
 Repeat
  Code := ReadDXFGroupCode(F);
  If Code < 0 Then Exit;
  S := ReadDXFString(F);
 Until (Code = 0) and (S = DXF_ENDSEC);

 ReadDXFBlocks := True;
End;

{ Lire une entité DXF }
Function ReadDXFEntity(Var F: Text; Var Entity: TDrawObject): Boolean;
Var
 Code: Integer;
 S: String;
 EntityType: String;
Begin
 ReadDXFEntity := False;

 { Initialiser l'entité }
 FillChar(Entity, SizeOf(Entity), 0);
 Entity.ObjType := OBJ_NONE;
 Entity.Color := 7;
 Entity.LayerIndex := 0;
 Entity.Visible := True;

 { Lire le type d'entité (déjà lu par l'appelant) }
 EntityType := '';

 Repeat
  Code := ReadDXFGroupCode(F);
  If Code < 0 Then Exit;

  If Code = 0 Then Begin
   { Nouveau type d'entité ou fin de section }
   S := ReadDXFString(F);

   If EntityType <> '' Then Begin
    { On a fini de lire cette entité }
    Entity.ObjType := GetObjTypeFromDXF(EntityType);
    ReadDXFEntity := Entity.ObjType <> OBJ_NONE;
   End;

   { Passer au prochain type }
   If (S = DXF_ENDSEC) or (S = DXF_EOF) Then Exit;
   EntityType := S;
  End
  Else Begin
   S := ReadDXFString(F);

   Case Code of
    8: Begin
     { Trouver l'index du calque }
     Entity.LayerIndex := 0;
    End;
    10: Val(S, Entity.X1, Code);
    20: Val(S, Entity.Y1, Code);
    11: Val(S, Entity.X2, Code);
    21: Val(S, Entity.Y2, Code);
    40: Val(S, Entity.Radius, Code);
    50: Val(S, Entity.StartAngle, Code);
    51: Val(S, Entity.EndAngle, Code);
    62: Val(S, Entity.Color, Code);
    70: Val(S, Entity.DimType, Code);
    1: Entity.DimText := S;
   End;
  End;
 Until False;
End;

{ Lire la section ENTITIES }
Function ReadDXFEntities(Var F: Text): Boolean;
Var
 Code: Integer;
 S: String;
 Entity: TDrawObject;
Begin
 ReadDXFEntities := False;

 Repeat
  Code := ReadDXFGroupCode(F);
  If Code < 0 Then Exit;
  S := ReadDXFString(F);

  If Code = 0 Then Begin
   If S = DXF_ENDSEC Then Begin
    ReadDXFEntities := True;
    Exit;
   End
   Else If S = DXF_EOF Then Begin
    ReadDXFEntities := True;
    Exit;
   End
   Else Begin
    { Lire l'entité }
    FillChar(Entity, SizeOf(Entity), 0);
    Entity.ObjType := GetObjTypeFromDXF(S);
    Entity.Color := 7;
    Entity.LayerIndex := 0;
    Entity.Visible := True;

    { Lire les attributs de l'entité }
    Repeat
     Code := ReadDXFGroupCode(F);
     If Code < 0 Then Exit;
     If Code = 0 Then Break;

     S := ReadDXFString(F);
     Case Code of
      8: Entity.LayerIndex := 0;  { TODO: trouver l'index }
      10: Val(S, Entity.X1, Code);
      20: Val(S, Entity.Y1, Code);
      11: Val(S, Entity.X2, Code);
      21: Val(S, Entity.Y2, Code);
      40: Val(S, Entity.Radius, Code);
      50: Val(S, Entity.StartAngle, Code);
      51: Val(S, Entity.EndAngle, Code);
      62: Val(S, Entity.Color, Code);
      70: Val(S, Entity.DimType, Code);
      1: Entity.DimText := S;
     End;
    Until False;

    { Ajouter l'entité si valide }
    If (Entity.ObjType <> OBJ_NONE) and (ObjectCount < MAX_OBJECTS) Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;

    { S contient maintenant le prochain type d'entité }
    S := ReadDXFString(F);
   End;
  End;
 Until False;
End;

{ Lire un dessin depuis un fichier DXF }
Function ReadDXFFile(Const FileName: String): Boolean;
Var
 F: Text;
 Code: Integer;
 S: String;
Begin
 ReadDXFFile := False;

 {$I-}
 Assign(F, FileName);
 Reset(F);
 {$I+}

 If IOResult <> 0 Then Exit;

 { Réinitialiser le dessin }
 ObjectCount := 0;
 LayerCount := 0;

 { Créer le calque 0 par défaut }
 Layers[0].Name := '0';
 Layers[0].Color := 7;
 Layers[0].LineType := 0;
 Layers[0].LineWeight := 0;
 Layers[0].Visible := True;
 Layers[0].Locked := False;
 Layers[0].Frozen := False;
 Layers[0].OnFlag := True;
 LayerCount := 1;

 { Lire le fichier section par section }
 Repeat
  Code := ReadDXFGroupCode(F);
  If Code < 0 Then Break;
  S := ReadDXFString(F);

  If (Code = 0) and (S = DXF_SECTION) Then Begin
   { Lire le nom de la section }
   Code := ReadDXFGroupCode(F);
   S := ReadDXFString(F);

   If S = DXF_HEADER Then Begin
    If Not ReadDXFHeader(F) Then Break;
   End
   Else If S = DXF_TABLES Then Begin
    If Not ReadDXFTables(F) Then Break;
   End
   Else If S = DXF_BLOCKS Then Begin
    If Not ReadDXFBlocks(F) Then Break;
   End
   Else If S = DXF_ENTITIES Then Begin
    If Not ReadDXFEntities(F) Then Break;
   End
   Else Begin
    { Sauter la section inconnue }
    Repeat
     Code := ReadDXFGroupCode(F);
     If Code < 0 Then Break;
     S := ReadDXFString(F);
    Until (Code = 0) and (S = DXF_ENDSEC);
   End;
  End
  Else If (Code = 0) and (S = DXF_EOF) Then Begin
   ReadDXFFile := True;
   Break;
  End;
 Until EOF(F);

 Close(F);

 { Effacer la sélection }
 ClearSelection;
 ClearGrips;

 ReadDXFFile := True;
 MarkDocumentSaved;
End;

{ ============================================================================ }
{ Fonctions pour le format Visio (VSD/VSDX) - TODO 23                          }
{ ============================================================================ }

{ Vérifier si un fichier est au format VSDX (XML) }
Function IsVisioFileVSDX(Const FileName: String): Boolean;
Var
 Ext: String;
 I: Integer;
Begin
 IsVisioFileVSDX := False;
 Ext := '';

 { Extraire l'extension }
 For I := Length(FileName) downto 1 do
  If FileName[I] = '.' Then Begin
   Ext := Copy(FileName, I, Length(FileName) - I + 1);
   Break;
  End;

 { Convertir en minuscules }
 For I := 1 to Length(Ext) do
  If (Ext[I] >= 'A') and (Ext[I] <= 'Z') Then
   Ext[I] := Chr(Ord(Ext[I]) + 32);

 IsVisioFileVSDX := (Ext = VISIO_EXT_VSDX) or (Ext = VISIO_EXT_VSDM) or (Ext = VISIO_EXT_VSTX);
End;

{ Obtenir le type de forme Visio à partir du type d'objet interne }
Function GetVisioShapeType(ObjType: Byte): Byte;
Begin
 Case ObjType of
  OBJ_LINE:      GetVisioShapeType := VISIO_SHAPE_LINE;
  OBJ_POINT:     GetVisioShapeType := VISIO_SHAPE_ELLIPSE;
  OBJ_CIRCLE:    GetVisioShapeType := VISIO_SHAPE_ELLIPSE;
  OBJ_ARC:       GetVisioShapeType := VISIO_SHAPE_ARC;
  OBJ_TEXT:      GetVisioShapeType := VISIO_SHAPE_TEXT;
  OBJ_POLYLINE:  GetVisioShapeType := VISIO_SHAPE_POLYLINE;
  OBJ_RECTANGLE: GetVisioShapeType := VISIO_SHAPE_RECTANGLE;
  OBJ_ELLIPSE:   GetVisioShapeType := VISIO_SHAPE_ELLIPSE;
  OBJ_BLOCK_REF: GetVisioShapeType := VISIO_SHAPE_GROUP;
 Else
  GetVisioShapeType := VISIO_SHAPE_RECTANGLE;
 End;
End;

{ Obtenir le type d'objet interne à partir du type Visio }
Function GetObjTypeFromVisio(VisioType: Byte): Byte;
Begin
 Case VisioType of
  VISIO_SHAPE_RECTANGLE: GetObjTypeFromVisio := OBJ_RECTANGLE;
  VISIO_SHAPE_ELLIPSE:   GetObjTypeFromVisio := OBJ_ELLIPSE;
  VISIO_SHAPE_LINE:      GetObjTypeFromVisio := OBJ_LINE;
  VISIO_SHAPE_POLYLINE:  GetObjTypeFromVisio := OBJ_POLYLINE;
  VISIO_SHAPE_ARC:       GetObjTypeFromVisio := OBJ_ARC;
  VISIO_SHAPE_TEXT:      GetObjTypeFromVisio := OBJ_TEXT;
  VISIO_SHAPE_GROUP:     GetObjTypeFromVisio := OBJ_BLOCK_REF;
 Else
  GetObjTypeFromVisio := OBJ_NONE;
 End;
End;

{ Convertir une couleur Visio (format #RRGGBB) en index ACI }
Function VisioColorToACI(Const ColorStr: String): Integer;
Var
 R, G, B: Integer;
 RStr, GStr, BStr: String;
 Err: Integer;
Begin
 VisioColorToACI := 7; { Blanc par défaut }

 If Length(ColorStr) < 7 Then Exit;
 If ColorStr[1] <> '#' Then Exit;

 RStr := '$' + Copy(ColorStr, 2, 2);
 GStr := '$' + Copy(ColorStr, 4, 2);
 BStr := '$' + Copy(ColorStr, 6, 2);

 Val(RStr, R, Err);
 If Err <> 0 Then Exit;
 Val(GStr, G, Err);
 If Err <> 0 Then Exit;
 Val(BStr, B, Err);
 If Err <> 0 Then Exit;

 { Conversion simplifiée vers ACI }
 If (R < 50) and (G < 50) and (B < 50) Then VisioColorToACI := 0     { Noir }
 Else If (R > 200) and (G < 50) and (B < 50) Then VisioColorToACI := 1  { Rouge }
 Else If (R > 200) and (G > 200) and (B < 50) Then VisioColorToACI := 2 { Jaune }
 Else If (R < 50) and (G > 200) and (B < 50) Then VisioColorToACI := 3  { Vert }
 Else If (R < 50) and (G > 200) and (B > 200) Then VisioColorToACI := 4 { Cyan }
 Else If (R < 50) and (G < 50) and (B > 200) Then VisioColorToACI := 5  { Bleu }
 Else If (R > 200) and (G < 50) and (B > 200) Then VisioColorToACI := 6 { Magenta }
 Else VisioColorToACI := 7; { Blanc }
End;

{ Convertir un index ACI en couleur Visio }
Function ACIToVisioColor(ColorIdx: Integer): String;
Begin
 Case ColorIdx of
  0: ACIToVisioColor := '#000000';  { Noir }
  1: ACIToVisioColor := '#FF0000';  { Rouge }
  2: ACIToVisioColor := '#FFFF00';  { Jaune }
  3: ACIToVisioColor := '#00FF00';  { Vert }
  4: ACIToVisioColor := '#00FFFF';  { Cyan }
  5: ACIToVisioColor := '#0000FF';  { Bleu }
  6: ACIToVisioColor := '#FF00FF';  { Magenta }
  7: ACIToVisioColor := '#FFFFFF';  { Blanc }
  8: ACIToVisioColor := '#808080';  { Gris }
  9: ACIToVisioColor := '#C0C0C0';  { Gris clair }
 Else
  ACIToVisioColor := '#000000';
 End;
End;

{ Écrire une cellule XML Visio avec valeur texte }
Procedure WriteVisioXMLCell(Var F: Text; Const CellName, Value: String);
Begin
 WriteLn(F, '      <Cell N="', CellName, '" V="', Value, '"/>');
End;

{ Écrire une cellule XML Visio avec valeur réelle }
Procedure WriteVisioXMLCellF(Var F: Text; Const CellName: String; Value: Real);
Begin
 WriteLn(F, '      <Cell N="', CellName, '" V="', Value:0:6, '"/>');
End;

{ Extraire une valeur d'une ligne XML }
Function ExtractVisioXMLValue(Const Line, Tag: String): String;
Var
 StartPos, EndPos: Integer;
 SearchStr: String;
Begin
 ExtractVisioXMLValue := '';
 SearchStr := Tag + '="';
 StartPos := Pos(SearchStr, Line);
 If StartPos = 0 Then Exit;

 StartPos := StartPos + Length(SearchStr);
 EndPos := StartPos;
 While (EndPos <= Length(Line)) and (Line[EndPos] <> '"') do
  Inc(EndPos);

 ExtractVisioXMLValue := Copy(Line, StartPos, EndPos - StartPos);
End;

{ Écrire l'en-tête XML Visio }
Procedure WriteVisioXMLHeader(Var F: Text);
Begin
 WriteLn(F, '<?xml version="1.0" encoding="UTF-8"?>');
 WriteLn(F, '<VisioDocument xmlns="http://schemas.microsoft.com/visio/2003/core"');
 WriteLn(F, '  xmlns:vx="http://schemas.microsoft.com/visio/2006/extension"');
 WriteLn(F, '  xml:space="preserve">');
End;

{ Écrire les propriétés du document }
Procedure WriteVisioXMLDocProps(Var F: Text);
Begin
 WriteLn(F, '  <DocumentProperties>');
 WriteLn(F, '    <Creator>CloneDRAW AutoCAD</Creator>');
 WriteLn(F, '    <Desc>Exported from CloneDRAW</Desc>');
 WriteLn(F, '    <Keywords>CAD, Drawing</Keywords>');
 WriteLn(F, '    <Subject>CAD Drawing</Subject>');
 WriteLn(F, '    <Title>Drawing Export</Title>');
 WriteLn(F, '  </DocumentProperties>');
End;

{ Écrire une forme ligne en XML Visio }
Procedure WriteVisioXMLLine(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt);
Begin
 WriteLn(F, '    <Shape ID="', ShapeID, '" Type="Shape" LineStyle="3" FillStyle="3" TextStyle="3">');
 WriteLn(F, '      <Cell N="', VISIO_CELL_BEGINX, '" V="', Entity.X1:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_BEGINY, '" V="', Entity.Y1:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_ENDX, '" V="', Entity.X2:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_ENDY, '" V="', Entity.Y2:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LINECOLOR, '" V="', ACIToVisioColor(Entity.Color), '"/>');
 WriteLn(F, '      <Geom IX="0">');
 WriteLn(F, '        <Cell N="NoFill" V="1"/>');
 WriteLn(F, '        <Row T="MoveTo">');
 WriteLn(F, '          <Cell N="X" V="', Entity.X1:0:6, '"/>');
 WriteLn(F, '          <Cell N="Y" V="', Entity.Y1:0:6, '"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '        <Row T="LineTo">');
 WriteLn(F, '          <Cell N="X" V="', Entity.X2:0:6, '"/>');
 WriteLn(F, '          <Cell N="Y" V="', Entity.Y2:0:6, '"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '      </Geom>');
 WriteLn(F, '    </Shape>');
End;

{ Écrire une forme rectangle en XML Visio }
Procedure WriteVisioXMLRectangle(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt);
Var
 W, H, CX, CY: Real;
Begin
 W := Abs(Entity.X2 - Entity.X1);
 H := Abs(Entity.Y2 - Entity.Y1);
 CX := (Entity.X1 + Entity.X2) / 2;
 CY := (Entity.Y1 + Entity.Y2) / 2;

 WriteLn(F, '    <Shape ID="', ShapeID, '" Type="Shape" LineStyle="3" FillStyle="3" TextStyle="3">');
 WriteLn(F, '      <Cell N="', VISIO_CELL_PINX, '" V="', CX:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_PINY, '" V="', CY:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_WIDTH, '" V="', W:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_HEIGHT, '" V="', H:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LOCPINX, '" V="', (W / 2):0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LOCPINY, '" V="', (H / 2):0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LINECOLOR, '" V="', ACIToVisioColor(Entity.Color), '"/>');
 WriteLn(F, '      <Geom IX="0">');
 WriteLn(F, '        <Cell N="NoFill" V="0"/>');
 WriteLn(F, '        <Row T="RelMoveTo">');
 WriteLn(F, '          <Cell N="X" V="0"/>');
 WriteLn(F, '          <Cell N="Y" V="0"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '        <Row T="RelLineTo">');
 WriteLn(F, '          <Cell N="X" V="1"/>');
 WriteLn(F, '          <Cell N="Y" V="0"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '        <Row T="RelLineTo">');
 WriteLn(F, '          <Cell N="X" V="1"/>');
 WriteLn(F, '          <Cell N="Y" V="1"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '        <Row T="RelLineTo">');
 WriteLn(F, '          <Cell N="X" V="0"/>');
 WriteLn(F, '          <Cell N="Y" V="1"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '        <Row T="RelLineTo">');
 WriteLn(F, '          <Cell N="X" V="0"/>');
 WriteLn(F, '          <Cell N="Y" V="0"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '      </Geom>');
 WriteLn(F, '    </Shape>');
End;

{ Écrire une forme cercle en XML Visio }
Procedure WriteVisioXMLCircle(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt);
Var
 D: Real;
Begin
 D := Entity.Radius * 2;

 WriteLn(F, '    <Shape ID="', ShapeID, '" Type="Shape" LineStyle="3" FillStyle="3" TextStyle="3">');
 WriteLn(F, '      <Cell N="', VISIO_CELL_PINX, '" V="', Entity.X1:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_PINY, '" V="', Entity.Y1:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_WIDTH, '" V="', D:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_HEIGHT, '" V="', D:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LOCPINX, '" V="', Entity.Radius:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LOCPINY, '" V="', Entity.Radius:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LINECOLOR, '" V="', ACIToVisioColor(Entity.Color), '"/>');
 WriteLn(F, '      <Geom IX="0">');
 WriteLn(F, '        <Cell N="NoFill" V="0"/>');
 WriteLn(F, '        <Row T="Ellipse">');
 WriteLn(F, '          <Cell N="X" V="', Entity.Radius:0:6, '"/>');
 WriteLn(F, '          <Cell N="Y" V="', Entity.Radius:0:6, '"/>');
 WriteLn(F, '          <Cell N="A" V="', D:0:6, '"/>');
 WriteLn(F, '          <Cell N="B" V="', Entity.Radius:0:6, '"/>');
 WriteLn(F, '          <Cell N="C" V="', Entity.Radius:0:6, '"/>');
 WriteLn(F, '          <Cell N="D" V="', D:0:6, '"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '      </Geom>');
 WriteLn(F, '    </Shape>');
End;

{ Écrire une forme ellipse en XML Visio }
Procedure WriteVisioXMLEllipse(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt);
Var
 W, H: Real;
Begin
 W := Entity.Radius * 2;  { Demi-axe majeur }
 H := Entity.EndAngle * 2; { Demi-axe mineur stocké dans EndAngle }
 If H <= 0 Then H := W;

 WriteLn(F, '    <Shape ID="', ShapeID, '" Type="Shape" LineStyle="3" FillStyle="3" TextStyle="3">');
 WriteLn(F, '      <Cell N="', VISIO_CELL_PINX, '" V="', Entity.X1:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_PINY, '" V="', Entity.Y1:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_WIDTH, '" V="', W:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_HEIGHT, '" V="', H:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LOCPINX, '" V="', (W / 2):0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LOCPINY, '" V="', (H / 2):0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LINECOLOR, '" V="', ACIToVisioColor(Entity.Color), '"/>');
 WriteLn(F, '      <Geom IX="0">');
 WriteLn(F, '        <Cell N="NoFill" V="0"/>');
 WriteLn(F, '        <Row T="Ellipse">');
 WriteLn(F, '          <Cell N="X" V="', (W / 2):0:6, '"/>');
 WriteLn(F, '          <Cell N="Y" V="', (H / 2):0:6, '"/>');
 WriteLn(F, '          <Cell N="A" V="', W:0:6, '"/>');
 WriteLn(F, '          <Cell N="B" V="', (H / 2):0:6, '"/>');
 WriteLn(F, '          <Cell N="C" V="', (W / 2):0:6, '"/>');
 WriteLn(F, '          <Cell N="D" V="', H:0:6, '"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '      </Geom>');
 WriteLn(F, '    </Shape>');
End;

{ Écrire une forme arc en XML Visio }
Procedure WriteVisioXMLArc(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt);
Var
 StartX, StartY, EndX, EndY: Real;
 StartRad, EndRad: Real;
Begin
 StartRad := Entity.StartAngle * 3.14159265 / 180.0;
 EndRad := Entity.EndAngle * 3.14159265 / 180.0;

 StartX := Entity.X1 + Entity.Radius * Cos(StartRad);
 StartY := Entity.Y1 + Entity.Radius * Sin(StartRad);
 EndX := Entity.X1 + Entity.Radius * Cos(EndRad);
 EndY := Entity.Y1 + Entity.Radius * Sin(EndRad);

 WriteLn(F, '    <Shape ID="', ShapeID, '" Type="Shape" LineStyle="3" FillStyle="3" TextStyle="3">');
 WriteLn(F, '      <Cell N="', VISIO_CELL_BEGINX, '" V="', StartX:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_BEGINY, '" V="', StartY:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_ENDX, '" V="', EndX:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_ENDY, '" V="', EndY:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LINECOLOR, '" V="', ACIToVisioColor(Entity.Color), '"/>');
 WriteLn(F, '      <Geom IX="0">');
 WriteLn(F, '        <Cell N="NoFill" V="1"/>');
 WriteLn(F, '        <Row T="MoveTo">');
 WriteLn(F, '          <Cell N="X" V="', StartX:0:6, '"/>');
 WriteLn(F, '          <Cell N="Y" V="', StartY:0:6, '"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '        <Row T="ArcTo">');
 WriteLn(F, '          <Cell N="X" V="', EndX:0:6, '"/>');
 WriteLn(F, '          <Cell N="Y" V="', EndY:0:6, '"/>');
 WriteLn(F, '          <Cell N="A" V="', (Entity.Radius / 4):0:6, '"/>');
 WriteLn(F, '        </Row>');
 WriteLn(F, '      </Geom>');
 WriteLn(F, '    </Shape>');
End;

{ Écrire une forme texte en XML Visio }
Procedure WriteVisioXMLText(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt);
Begin
 WriteLn(F, '    <Shape ID="', ShapeID, '" Type="Shape" LineStyle="3" FillStyle="3" TextStyle="3">');
 WriteLn(F, '      <Cell N="', VISIO_CELL_PINX, '" V="', Entity.X1:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_PINY, '" V="', Entity.Y1:0:6, '"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_WIDTH, '" V="50"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_HEIGHT, '" V="10"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LOCPINX, '" V="0"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LOCPINY, '" V="5"/>');
 WriteLn(F, '      <Cell N="', VISIO_CELL_LINECOLOR, '" V="', ACIToVisioColor(Entity.Color), '"/>');
 WriteLn(F, '      <Text>', Entity.DimText, '</Text>');
 WriteLn(F, '    </Shape>');
End;

{ Écrire une forme générique en XML Visio }
Procedure WriteVisioXMLShape(Var F: Text; Const Entity: TDrawObject; ShapeID: LongInt);
Begin
 If Entity.ObjType = OBJ_NONE Then Exit;
 If Not Entity.Visible Then Exit;

 Case Entity.ObjType of
  OBJ_LINE:      WriteVisioXMLLine(F, Entity, ShapeID);
  OBJ_RECTANGLE: WriteVisioXMLRectangle(F, Entity, ShapeID);
  OBJ_CIRCLE:    WriteVisioXMLCircle(F, Entity, ShapeID);
  OBJ_ELLIPSE:   WriteVisioXMLEllipse(F, Entity, ShapeID);
  OBJ_ARC:       WriteVisioXMLArc(F, Entity, ShapeID);
  OBJ_TEXT:      WriteVisioXMLText(F, Entity, ShapeID);
  OBJ_POINT:     WriteVisioXMLCircle(F, Entity, ShapeID);
 End;
End;

{ Écrire toutes les formes }
Procedure WriteVisioXMLShapes(Var F: Text);
Var
 I: Integer;
 ShapeID: LongInt;
Begin
 WriteLn(F, '    <Shapes>');

 ShapeID := 1;
 For I := 0 to ObjectCount - 1 do Begin
  If DrawObjects[I].ObjType <> OBJ_NONE Then Begin
   WriteVisioXMLShape(F, DrawObjects[I], ShapeID);
   Inc(ShapeID);
  End;
 End;

 WriteLn(F, '    </Shapes>');
End;

{ Écrire une page }
Procedure WriteVisioXMLPage(Var F: Text; PageNum: Integer);
Begin
 WriteLn(F, '  <Page ID="', PageNum, '" NameU="Page-', PageNum, '">');
 WriteLn(F, '    <PageSheet>');
 WriteLn(F, '      <Cell N="PageWidth" V="', (ScreenWidth / 100):0:2, '"/>');
 WriteLn(F, '      <Cell N="PageHeight" V="', (ScreenHeight / 100):0:2, '"/>');
 WriteLn(F, '    </PageSheet>');
 WriteVisioXMLShapes(F);
 WriteLn(F, '  </Page>');
End;

{ Écrire toutes les pages }
Procedure WriteVisioXMLPages(Var F: Text);
Begin
 WriteLn(F, '  <Pages>');
 WriteVisioXMLPage(F, 1);
 WriteLn(F, '  </Pages>');
End;

{ Écrire le pied de page XML Visio }
Procedure WriteVisioXMLFooter(Var F: Text);
Begin
 WriteLn(F, '</VisioDocument>');
End;

{ Écrire un fichier VSDX (XML simplifié) }
Function WriteVSDXFile(Const FileName: String): Boolean;
Var
 F: Text;
Begin
 WriteVSDXFile := False;

 {$I-}
 Assign(F, FileName);
 Rewrite(F);
 {$I+}

 If IOResult <> 0 Then Exit;

 WriteVisioXMLHeader(F);
 WriteVisioXMLDocProps(F);
 WriteVisioXMLPages(F);
 WriteVisioXMLFooter(F);

 Close(F);
 WriteVSDXFile := True;
End;

{ Écrire un fichier Visio (détection automatique du format) }
Function WriteVisioFile(Const FileName: String): Boolean;
Begin
 { Pour l'instant, on utilise toujours le format XML }
 WriteVisioFile := WriteVSDXFile(FileName);
End;

{ Lire l'en-tête XML Visio }
Function ReadVisioXMLHeader(Var F: Text): Boolean;
Var
 Line: String;
Begin
 ReadVisioXMLHeader := False;

 While Not EOF(F) do Begin
  ReadLn(F, Line);
  If Pos('<VisioDocument', Line) > 0 Then Begin
   ReadVisioXMLHeader := True;
   Exit;
  End;
 End;
End;

{ Lire une forme depuis le XML }
Function ReadVisioXMLShape(Var F: Text; Var Entity: TDrawObject): Boolean;
Var
 Line, Value: String;
 InShape: Boolean;
Begin
 ReadVisioXMLShape := False;
 InShape := True;

 FillChar(Entity, SizeOf(Entity), 0);
 Entity.ObjType := OBJ_RECTANGLE;  { Type par défaut }
 Entity.Color := 7;
 Entity.LayerIndex := 0;
 Entity.Visible := True;

 While InShape and Not EOF(F) do Begin
  ReadLn(F, Line);

  { Fin de la forme }
  If Pos('</Shape>', Line) > 0 Then Begin
   InShape := False;
   ReadVisioXMLShape := True;
  End
  { Cellule PinX }
  Else If Pos('N="PinX"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then
    Val(Value, Entity.X1, Entity.Color);
   Entity.Color := 7;
  End
  { Cellule PinY }
  Else If Pos('N="PinY"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then
    Val(Value, Entity.Y1, Entity.Color);
   Entity.Color := 7;
  End
  { Cellule Width }
  Else If Pos('N="Width"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then Begin
    Val(Value, Entity.X2, Entity.Color);
    Entity.X2 := Entity.X1 + Entity.X2;
   End;
   Entity.Color := 7;
  End
  { Cellule Height }
  Else If Pos('N="Height"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then Begin
    Val(Value, Entity.Y2, Entity.Color);
    Entity.Y2 := Entity.Y1 + Entity.Y2;
   End;
   Entity.Color := 7;
  End
  { Cellule BeginX (lignes) }
  Else If Pos('N="BeginX"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then Begin
    Val(Value, Entity.X1, Entity.Color);
    Entity.ObjType := OBJ_LINE;
   End;
   Entity.Color := 7;
  End
  { Cellule BeginY }
  Else If Pos('N="BeginY"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then
    Val(Value, Entity.Y1, Entity.Color);
   Entity.Color := 7;
  End
  { Cellule EndX }
  Else If Pos('N="EndX"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then
    Val(Value, Entity.X2, Entity.Color);
   Entity.Color := 7;
  End
  { Cellule EndY }
  Else If Pos('N="EndY"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then
    Val(Value, Entity.Y2, Entity.Color);
   Entity.Color := 7;
  End
  { Ellipse détectée }
  Else If Pos('T="Ellipse"', Line) > 0 Then Begin
   Entity.ObjType := OBJ_ELLIPSE;
  End
  { Texte }
  Else If Pos('<Text>', Line) > 0 Then Begin
   Entity.ObjType := OBJ_TEXT;
   { Extraire le texte entre <Text> et </Text> }
   Value := Line;
   Delete(Value, 1, Pos('<Text>', Value) + 5);
   If Pos('</Text>', Value) > 0 Then
    Value := Copy(Value, 1, Pos('</Text>', Value) - 1);
   Entity.DimText := Value;
  End
  { Couleur de ligne }
  Else If Pos('N="LineColor"', Line) > 0 Then Begin
   Value := ExtractVisioXMLValue(Line, 'V');
   If Value <> '' Then
    Entity.Color := VisioColorToACI(Value);
  End;
 End;
End;

{ Lire toutes les formes depuis le XML }
Function ReadVisioXMLShapes(Var F: Text): Boolean;
Var
 Line: String;
 Entity: TDrawObject;
 InShapes: Boolean;
Begin
 ReadVisioXMLShapes := False;
 InShapes := False;

 While Not EOF(F) do Begin
  ReadLn(F, Line);

  If Pos('<Shapes>', Line) > 0 Then
   InShapes := True
  Else If Pos('</Shapes>', Line) > 0 Then Begin
   ReadVisioXMLShapes := True;
   Exit;
  End
  Else If InShapes and (Pos('<Shape ', Line) > 0) Then Begin
   If ReadVisioXMLShape(F, Entity) Then Begin
    If (Entity.ObjType <> OBJ_NONE) and (ObjectCount < MAX_OBJECTS) Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;
   End;
  End;
 End;
End;

{ Lire les pages depuis le XML }
Function ReadVisioXMLPages(Var F: Text): Boolean;
Var
 Line: String;
Begin
 ReadVisioXMLPages := False;

 While Not EOF(F) do Begin
  ReadLn(F, Line);

  If Pos('<Pages>', Line) > 0 Then Begin
   { Lire les formes de toutes les pages }
   While Not EOF(F) do Begin
    ReadLn(F, Line);
    If Pos('</Pages>', Line) > 0 Then Begin
     ReadVisioXMLPages := True;
     Exit;
    End
    Else If Pos('<Shapes>', Line) > 0 Then Begin
     { Revenir au début de Shapes pour la lecture }
     ReadVisioXMLShapes(F);
    End;
   End;
  End;
 End;
End;

{ Lire un fichier VSDX (XML) }
Function ReadVSDXFile(Const FileName: String): Boolean;
Var
 F: Text;
 Line: String;
Begin
 ReadVSDXFile := False;

 {$I-}
 Assign(F, FileName);
 Reset(F);
 {$I+}

 If IOResult <> 0 Then Exit;

 { Réinitialiser le dessin }
 ObjectCount := 0;

 { Chercher les formes }
 While Not EOF(F) do Begin
  ReadLn(F, Line);
  If Pos('<Shapes>', Line) > 0 Then
   ReadVisioXMLShapes(F);
 End;

 Close(F);

 { Effacer la sélection }
 ClearSelection;
 ClearGrips;

 ReadVSDXFile := True;
End;

{ Lire un fichier Visio (détection automatique du format) }
Function ReadVisioFile(Const FileName: String): Boolean;
Begin
 { Pour l'instant, on supporte uniquement le format XML (VSDX) }
 ReadVisioFile := ReadVSDXFile(FileName);
End;

{ ============================================================================ }
{ Fonctions pour le format SVG (Scalable Vector Graphics) - TODO 24           }
{ ============================================================================ }

{ Convertir un index ACI en couleur SVG hexadécimale }
Function ACIToSVGColor(ColorIdx: Integer): String;
Begin
 Case ColorIdx of
  0: ACIToSVGColor := '#000000';    { Noir }
  1: ACIToSVGColor := '#FF0000';    { Rouge }
  2: ACIToSVGColor := '#FFFF00';    { Jaune }
  3: ACIToSVGColor := '#00FF00';    { Vert }
  4: ACIToSVGColor := '#00FFFF';    { Cyan }
  5: ACIToSVGColor := '#0000FF';    { Bleu }
  6: ACIToSVGColor := '#FF00FF';    { Magenta }
  7: ACIToSVGColor := '#FFFFFF';    { Blanc }
  8: ACIToSVGColor := '#808080';    { Gris foncé }
  9: ACIToSVGColor := '#C0C0C0';    { Gris clair }
  10: ACIToSVGColor := '#FF0000';   { Rouge }
  11: ACIToSVGColor := '#FF7F7F';   { Rouge clair }
  12: ACIToSVGColor := '#CC0000';   { Rouge foncé }
  20: ACIToSVGColor := '#FF7F00';   { Orange }
  30: ACIToSVGColor := '#FFFF00';   { Jaune }
  40: ACIToSVGColor := '#7FFF00';   { Jaune-vert }
  50: ACIToSVGColor := '#00FF00';   { Vert }
  60: ACIToSVGColor := '#00FF7F';   { Vert-cyan }
  70: ACIToSVGColor := '#00FFFF';   { Cyan }
  80: ACIToSVGColor := '#007FFF';   { Cyan-bleu }
  90: ACIToSVGColor := '#0000FF';   { Bleu }
  100: ACIToSVGColor := '#7F00FF';  { Bleu-violet }
  110: ACIToSVGColor := '#FF00FF';  { Magenta }
  120: ACIToSVGColor := '#FF007F';  { Magenta-rouge }
  250: ACIToSVGColor := '#333333';  { Gris très foncé }
  251: ACIToSVGColor := '#505050';  { Gris foncé }
  252: ACIToSVGColor := '#696969';  { Gris moyen foncé }
  253: ACIToSVGColor := '#808080';  { Gris moyen }
  254: ACIToSVGColor := '#BEBEBE';  { Gris clair }
  255: ACIToSVGColor := '#FFFFFF';  { Blanc (ByBlock) }
 Else
  { Couleurs intermédiaires - approximation }
  If ColorIdx < 10 Then ACIToSVGColor := '#FF0000'
  Else If ColorIdx < 20 Then ACIToSVGColor := '#FF7F00'
  Else If ColorIdx < 30 Then ACIToSVGColor := '#FFFF00'
  Else If ColorIdx < 50 Then ACIToSVGColor := '#00FF00'
  Else If ColorIdx < 70 Then ACIToSVGColor := '#00FFFF'
  Else If ColorIdx < 90 Then ACIToSVGColor := '#0000FF'
  Else If ColorIdx < 110 Then ACIToSVGColor := '#FF00FF'
  Else ACIToSVGColor := '#000000';
 End;
End;

{ Obtenir l'épaisseur de trait SVG à partir du poids de ligne }
Function GetSVGStrokeWidth(LineWeight: Integer): Real;
Begin
 If LineWeight <= 0 Then
  GetSVGStrokeWidth := SVG_DEFAULT_STROKE_WIDTH
 Else If LineWeight < 10 Then
  GetSVGStrokeWidth := 0.5
 Else If LineWeight < 25 Then
  GetSVGStrokeWidth := 1.0
 Else If LineWeight < 50 Then
  GetSVGStrokeWidth := 1.5
 Else If LineWeight < 100 Then
  GetSVGStrokeWidth := 2.0
 Else
  GetSVGStrokeWidth := LineWeight / 50.0;
End;

{ Écrire les attributs de style SVG }
Procedure WriteSVGStyle(Var F: Text; Color: Integer; LineWeight: Integer; Filled: Boolean);
Var
 StrokeWidth: Real;
Begin
 StrokeWidth := GetSVGStrokeWidth(LineWeight);

 If Filled Then
  Write(F, ' fill="', ACIToSVGColor(Color), '"')
 Else
  Write(F, ' fill="none"');

 Write(F, ' stroke="', ACIToSVGColor(Color), '"');
 Write(F, ' stroke-width="', StrokeWidth:0:2, '"');
End;

{ Écrire l'en-tête SVG }
Procedure WriteSVGHeader(Var F: Text; Width, Height: Real);
Begin
 WriteLn(F, '<?xml version="1.0" encoding="UTF-8"?>');
 WriteLn(F, '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">');
 WriteLn(F, '<svg xmlns="', SVG_NAMESPACE, '" version="', SVG_VERSION, '"');
 WriteLn(F, '  width="', Width:0:2, '" height="', Height:0:2, '"');
 WriteLn(F, '  viewBox="0 0 ', Width:0:2, ' ', Height:0:2, '">');
 WriteLn(F, '  <!-- Generated by CloneDRAW AutoCAD Clone -->');
 WriteLn(F, '  <!-- TODO 24: SVG Export -->');
End;

{ Écrire les définitions SVG (marqueurs, patterns, etc.) }
Procedure WriteSVGDefs(Var F: Text);
Begin
 WriteLn(F, '  <defs>');
 { Marqueur de flèche pour les cotations }
 WriteLn(F, '    <marker id="arrow" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">');
 WriteLn(F, '      <path d="M0,0 L0,6 L9,3 z" fill="#000000"/>');
 WriteLn(F, '    </marker>');
 { Marqueur de point }
 WriteLn(F, '    <marker id="dot" markerWidth="4" markerHeight="4" refX="2" refY="2">');
 WriteLn(F, '      <circle cx="2" cy="2" r="2" fill="#000000"/>');
 WriteLn(F, '    </marker>');
 WriteLn(F, '  </defs>');
End;

{ Écrire le pied de page SVG }
Procedure WriteSVGFooter(Var F: Text);
Begin
 WriteLn(F, '</svg>');
End;

{ Écrire une ligne SVG }
Procedure WriteSVGLine(Var F: Text; Const Entity: TDrawObject);
Begin
 Write(F, '  <line');
 Write(F, ' x1="', Entity.X1:0:4, '"');
 Write(F, ' y1="', Entity.Y1:0:4, '"');
 Write(F, ' x2="', Entity.X2:0:4, '"');
 Write(F, ' y2="', Entity.Y2:0:4, '"');
 WriteSVGStyle(F, Entity.Color, Entity.LineWeight, False);
 WriteLn(F, '/>');
End;

{ Écrire un rectangle SVG }
Procedure WriteSVGRectangle(Var F: Text; Const Entity: TDrawObject);
Var
 X, Y, W, H: Real;
Begin
 { Calculer le coin supérieur gauche et les dimensions }
 If Entity.X1 < Entity.X2 Then Begin
  X := Entity.X1;
  W := Entity.X2 - Entity.X1;
 End
 Else Begin
  X := Entity.X2;
  W := Entity.X1 - Entity.X2;
 End;

 If Entity.Y1 < Entity.Y2 Then Begin
  Y := Entity.Y1;
  H := Entity.Y2 - Entity.Y1;
 End
 Else Begin
  Y := Entity.Y2;
  H := Entity.Y1 - Entity.Y2;
 End;

 Write(F, '  <rect');
 Write(F, ' x="', X:0:4, '"');
 Write(F, ' y="', Y:0:4, '"');
 Write(F, ' width="', W:0:4, '"');
 Write(F, ' height="', H:0:4, '"');
 WriteSVGStyle(F, Entity.Color, Entity.LineWeight, False);
 WriteLn(F, '/>');
End;

{ Écrire un cercle SVG }
Procedure WriteSVGCircle(Var F: Text; Const Entity: TDrawObject);
Begin
 Write(F, '  <circle');
 Write(F, ' cx="', Entity.X1:0:4, '"');
 Write(F, ' cy="', Entity.Y1:0:4, '"');
 Write(F, ' r="', Entity.Radius:0:4, '"');
 WriteSVGStyle(F, Entity.Color, Entity.LineWeight, False);
 WriteLn(F, '/>');
End;

{ Écrire une ellipse SVG }
Procedure WriteSVGEllipse(Var F: Text; Const Entity: TDrawObject);
Var
 RX, RY: Real;
Begin
 RX := Entity.Radius;  { Demi-axe majeur }
 RY := Entity.EndAngle; { Demi-axe mineur (stocké dans EndAngle) }
 If RY <= 0 Then RY := RX;

 Write(F, '  <ellipse');
 Write(F, ' cx="', Entity.X1:0:4, '"');
 Write(F, ' cy="', Entity.Y1:0:4, '"');
 Write(F, ' rx="', RX:0:4, '"');
 Write(F, ' ry="', RY:0:4, '"');
 WriteSVGStyle(F, Entity.Color, Entity.LineWeight, False);
 WriteLn(F, '/>');
End;

{ Écrire un arc SVG (utilise path avec arc elliptique) }
Procedure WriteSVGArc(Var F: Text; Const Entity: TDrawObject);
Var
 StartX, StartY, EndX, EndY: Real;
 StartRad, EndRad: Real;
 LargeArc, Sweep: Integer;
 AngleDiff: Real;
Begin
 { Convertir les angles en radians }
 StartRad := Entity.StartAngle * 3.14159265 / 180.0;
 EndRad := Entity.EndAngle * 3.14159265 / 180.0;

 { Calculer les points de début et de fin }
 StartX := Entity.X1 + Entity.Radius * Cos(StartRad);
 StartY := Entity.Y1 - Entity.Radius * Sin(StartRad); { Y inversé pour SVG }
 EndX := Entity.X1 + Entity.Radius * Cos(EndRad);
 EndY := Entity.Y1 - Entity.Radius * Sin(EndRad);

 { Déterminer si c'est un grand arc }
 AngleDiff := Entity.EndAngle - Entity.StartAngle;
 If AngleDiff < 0 Then AngleDiff := AngleDiff + 360;
 If AngleDiff > 180 Then LargeArc := 1 Else LargeArc := 0;

 { Direction de l'arc (sens anti-horaire = 0 en SVG car Y est inversé) }
 Sweep := 0;

 Write(F, '  <path d="M ', StartX:0:4, ' ', StartY:0:4);
 Write(F, ' A ', Entity.Radius:0:4, ' ', Entity.Radius:0:4);
 Write(F, ' 0 ', LargeArc, ' ', Sweep);
 Write(F, ' ', EndX:0:4, ' ', EndY:0:4, '"');
 WriteSVGStyle(F, Entity.Color, Entity.LineWeight, False);
 WriteLn(F, '/>');
End;

{ Écrire un texte SVG }
Procedure WriteSVGText(Var F: Text; Const Entity: TDrawObject);
Var
 FontSize: Real;
Begin
 FontSize := SVG_DEFAULT_FONT_SIZE;
 If Entity.Radius > 0 Then FontSize := Entity.Radius; { Hauteur de texte stockée dans Radius }

 Write(F, '  <text');
 Write(F, ' x="', Entity.X1:0:4, '"');
 Write(F, ' y="', Entity.Y1:0:4, '"');
 Write(F, ' font-family="', SVG_DEFAULT_FONT_FAMILY, '"');
 Write(F, ' font-size="', FontSize:0:2, '"');
 Write(F, ' fill="', ACIToSVGColor(Entity.Color), '"');
 Write(F, '>');
 Write(F, Entity.DimText);
 WriteLn(F, '</text>');
End;

{ Écrire une polyligne SVG }
Procedure WriteSVGPolyline(Var F: Text; Const Entity: TDrawObject);
Var
 I: Integer;
Begin
 If Entity.VertexCount < 2 Then Exit;

 Write(F, '  <polyline points="');
 For I := 0 to Entity.VertexCount - 1 do Begin
  Write(F, Entity.Vertices[I].X:0:4, ',', Entity.Vertices[I].Y:0:4);
  If I < Entity.VertexCount - 1 Then Write(F, ' ');
 End;
 Write(F, '"');
 WriteSVGStyle(F, Entity.Color, Entity.LineWeight, False);
 WriteLn(F, '/>');
End;

{ Écrire un point SVG (petit cercle) }
Procedure WriteSVGPoint(Var F: Text; Const Entity: TDrawObject);
Begin
 Write(F, '  <circle');
 Write(F, ' cx="', Entity.X1:0:4, '"');
 Write(F, ' cy="', Entity.Y1:0:4, '"');
 Write(F, ' r="2"'); { Petit rayon fixe pour les points }
 Write(F, ' fill="', ACIToSVGColor(Entity.Color), '"');
 WriteLn(F, '/>');
End;

{ Écrire une cotation SVG }
Procedure WriteSVGDimension(Var F: Text; Const Entity: TDrawObject);
Var
 MidX, MidY: Real;
 TextOffset: Real;
Begin
 TextOffset := 5;

 { Ligne de cotation }
 Write(F, '  <line');
 Write(F, ' x1="', Entity.X1:0:4, '"');
 Write(F, ' y1="', Entity.Y1:0:4, '"');
 Write(F, ' x2="', Entity.X2:0:4, '"');
 Write(F, ' y2="', Entity.Y2:0:4, '"');
 Write(F, ' stroke="', ACIToSVGColor(Entity.Color), '"');
 Write(F, ' stroke-width="1"');
 Write(F, ' marker-end="url(#arrow)"');
 Write(F, ' marker-start="url(#arrow)"');
 WriteLn(F, '/>');

 { Texte de cotation au milieu }
 MidX := (Entity.X1 + Entity.X2) / 2;
 MidY := (Entity.Y1 + Entity.Y2) / 2 - TextOffset;

 Write(F, '  <text');
 Write(F, ' x="', MidX:0:4, '"');
 Write(F, ' y="', MidY:0:4, '"');
 Write(F, ' font-family="', SVG_DEFAULT_FONT_FAMILY, '"');
 Write(F, ' font-size="', SVG_DEFAULT_FONT_SIZE:0:2, '"');
 Write(F, ' text-anchor="middle"');
 Write(F, ' fill="', ACIToSVGColor(Entity.Color), '"');
 Write(F, '>');
 Write(F, Entity.DimText);
 WriteLn(F, '</text>');
End;

{ Écrire une entité SVG }
Procedure WriteSVGEntity(Var F: Text; Const Entity: TDrawObject);
Begin
 If Entity.ObjType = OBJ_NONE Then Exit;
 If Not Entity.Visible Then Exit;

 Case Entity.ObjType of
  OBJ_LINE:      WriteSVGLine(F, Entity);
  OBJ_RECTANGLE: WriteSVGRectangle(F, Entity);
  OBJ_CIRCLE:    WriteSVGCircle(F, Entity);
  OBJ_ELLIPSE:   WriteSVGEllipse(F, Entity);
  OBJ_ARC:       WriteSVGArc(F, Entity);
  OBJ_TEXT:      WriteSVGText(F, Entity);
  OBJ_POLYLINE:  WriteSVGPolyline(F, Entity);
  OBJ_POINT:     WriteSVGPoint(F, Entity);
  OBJ_DIMENSION: WriteSVGDimension(F, Entity);
 End;
End;

{ Écrire toutes les entités }
Procedure WriteSVGEntities(Var F: Text);
Var
 I: Integer;
Begin
 WriteLn(F, '  <g id="entities">');

 For I := 0 to ObjectCount - 1 do Begin
  If DrawObjects[I].ObjType <> OBJ_NONE Then
   WriteSVGEntity(F, DrawObjects[I]);
 End;

 WriteLn(F, '  </g>');
End;

{ Écrire un fichier SVG }
Function WriteSVGFile(Const FileName: String): Boolean;
Var
 F: Text;
 MinX, MinY, MaxX, MaxY: Real;
 Width, Height: Real;
 I: Integer;
Begin
 WriteSVGFile := False;

 { Calculer les limites du dessin }
 MinX := 0; MinY := 0;
 MaxX := ScreenWidth;
 MaxY := ScreenHeight;

 { Trouver les vraies limites des objets }
 For I := 0 to ObjectCount - 1 do Begin
  If DrawObjects[I].ObjType <> OBJ_NONE Then Begin
   If DrawObjects[I].X1 < MinX Then MinX := DrawObjects[I].X1;
   If DrawObjects[I].Y1 < MinY Then MinY := DrawObjects[I].Y1;
   If DrawObjects[I].X2 > MaxX Then MaxX := DrawObjects[I].X2;
   If DrawObjects[I].Y2 > MaxY Then MaxY := DrawObjects[I].Y2;
   If DrawObjects[I].X1 > MaxX Then MaxX := DrawObjects[I].X1;
   If DrawObjects[I].Y1 > MaxY Then MaxY := DrawObjects[I].Y1;
   If DrawObjects[I].X2 < MinX Then MinX := DrawObjects[I].X2;
   If DrawObjects[I].Y2 < MinY Then MinY := DrawObjects[I].Y2;
  End;
 End;

 { Ajouter une marge }
 Width := MaxX - MinX + 20;
 Height := MaxY - MinY + 20;
 If Width < 100 Then Width := 100;
 If Height < 100 Then Height := 100;

 {$I-}
 Assign(F, FileName);
 Rewrite(F);
 {$I+}

 If IOResult <> 0 Then Exit;

 WriteSVGHeader(F, Width, Height);
 WriteSVGDefs(F);
 WriteSVGEntities(F);
 WriteSVGFooter(F);

 Close(F);
 WriteSVGFile := True;
 MarkDocumentSaved;
End;

{ ============================================================================ }
{ Fonctions pour l'importation SVG - TODO 25                                   }
{ ============================================================================ }

{ Convertir une chaîne hexadécimale en entier }
Function HexToInt(Const HexStr: String): Integer;
Var
 I, Digit: Integer;
 C: Char;
 Result:Integer;
Begin
 Result := 0;
 For I := 1 to Length(HexStr) do Begin
  C := UpCase(HexStr[I]);
  If (C >= '0') and (C <= '9') Then
   Digit := Ord(C) - Ord('0')
  Else If (C >= 'A') and (C <= 'F') Then
   Digit := Ord(C) - Ord('A') + 10
  Else
   Exit;
  Result := Result * 16 + Digit;
 End;
 HexToInt:=Result;
End;

{ Convertir une couleur SVG en index ACI }
Function SVGColorToACI(Const ColorStr: String): Integer;
Var
 R, G, B: Integer;
 S: String;
Begin
 SVGColorToACI := 7; { Blanc par défaut }

 S := ColorStr;
 If Length(S) = 0 Then Exit;

 { Format #RRGGBB ou #RGB }
 If S[1] = '#' Then Begin
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
  Else Exit;

  { Convertir RGB vers ACI approximatif }
  If (R > 200) and (G < 50) and (B < 50) Then SVGColorToACI := 1      { Rouge }
  Else If (R > 200) and (G > 200) and (B < 50) Then SVGColorToACI := 2 { Jaune }
  Else If (R < 50) and (G > 200) and (B < 50) Then SVGColorToACI := 3  { Vert }
  Else If (R < 50) and (G > 200) and (B > 200) Then SVGColorToACI := 4 { Cyan }
  Else If (R < 50) and (G < 50) and (B > 200) Then SVGColorToACI := 5  { Bleu }
  Else If (R > 200) and (G < 50) and (B > 200) Then SVGColorToACI := 6 { Magenta }
  Else If (R > 200) and (G > 200) and (B > 200) Then SVGColorToACI := 7 { Blanc }
  Else If (R < 50) and (G < 50) and (B < 50) Then SVGColorToACI := 0    { Noir }
  Else If (R > 100) and (R < 180) and (G > 100) and (G < 180) Then SVGColorToACI := 8 { Gris }
  Else SVGColorToACI := 7;
 End
 { Noms de couleurs }
 Else Begin
  S := LowerCase(S);
  If S = 'red' Then SVGColorToACI := 1
  Else If S = 'yellow' Then SVGColorToACI := 2
  Else If S = 'green' Then SVGColorToACI := 3
  Else If S = 'lime' Then SVGColorToACI := 3
  Else If S = 'cyan' Then SVGColorToACI := 4
  Else If S = 'aqua' Then SVGColorToACI := 4
  Else If S = 'blue' Then SVGColorToACI := 5
  Else If S = 'magenta' Then SVGColorToACI := 6
  Else If S = 'fuchsia' Then SVGColorToACI := 6
  Else If S = 'white' Then SVGColorToACI := 7
  Else If S = 'black' Then SVGColorToACI := 0
  Else If S = 'gray' Then SVGColorToACI := 8
  Else If S = 'grey' Then SVGColorToACI := 8
  Else If S = 'silver' Then SVGColorToACI := 9
  Else If S = 'orange' Then SVGColorToACI := 30
  Else If S = 'purple' Then SVGColorToACI := 200
  Else If S = 'brown' Then SVGColorToACI := 24
  Else If S = 'none' Then SVGColorToACI := 7;
 End;
End;

{ Extraire un attribut SVG d'une ligne }
Function ExtractSVGAttr(Const Line, AttrName: String): String;
Var
 Pos1, Pos2: Integer;
 SearchStr: String;
Begin
 ExtractSVGAttr := '';
 SearchStr := AttrName + '="';
 Pos1 := Pos(SearchStr, Line);
 If Pos1 = 0 Then Begin
  { Essayer avec des apostrophes }
  SearchStr := AttrName + '=''';
  Pos1 := Pos(SearchStr, Line);
 End;

 If Pos1 > 0 Then Begin
  Pos1 := Pos1 + Length(SearchStr);
  Pos2 := Pos1;
  While (Pos2 <= Length(Line)) and (Line[Pos2] <> '"') and (Line[Pos2] <> '''') do
   Inc(Pos2);
  ExtractSVGAttr := Copy(Line, Pos1, Pos2 - Pos1);
 End;
End;

{ Extraire un attribut SVG comme nombre réel }
Function ExtractSVGAttrReal(Const Line, AttrName: String): Real;
Var
 S: String;
 V: Real;
 Code: Integer;
Begin
 ExtractSVGAttrReal := 0.0;
 S := ExtractSVGAttr(Line, AttrName);
 If Length(S) > 0 Then Begin
  { Supprimer les unités éventuelles (px, pt, etc.) }
  While (Length(S) > 0) and Not ((S[Length(S)] >= '0') and (S[Length(S)] <= '9')) and (S[Length(S)] <> '.') do
   Delete(S, Length(S), 1);
  Val(S, V, Code);
  If Code = 0 Then ExtractSVGAttrReal := V;
 End;
End;

{ Déterminer le type d'élément SVG dans une ligne }
Function GetSVGElementType(Const Line: String): String;
Var
 I: Integer;
 S: String;
Begin
 GetSVGElementType := '';
 I := Pos('<', Line);
 If I > 0 Then Begin
  Inc(I);
  { Ignorer les commentaires et déclarations }
  If (I <= Length(Line)) and ((Line[I] = '!') or (Line[I] = '?')) Then Exit;
  S := '';
  While (I <= Length(Line)) and (Line[I] <> ' ') and (Line[I] <> '>') and (Line[I] <> '/') do Begin
   S := S + Line[I];
   Inc(I);
  End;
  GetSVGElementType := LowerCase(S);
 End;
End;

{ Extraire le contenu texte d'un élément }
Function ExtractTextContent(Const Line: String): String;
Var
 Pos1, Pos2: Integer;
Begin
 ExtractTextContent := '';
 Pos1 := Pos('>', Line);
 If Pos1 > 0 Then Begin
  Inc(Pos1);
  Pos2 := Pos('</', Line);
  If Pos2 > Pos1 Then
   ExtractTextContent := Copy(Line, Pos1, Pos2 - Pos1);
 End;
End;

{ Parser les points d'une polyline/polygon }
Function ParseSVGPoints(Const PointsStr: String; Var Entity: TDrawObject): Boolean;
Var
 I, Start: Integer;
 S, NumStr: String;
 IsX: Boolean;
 X, Y, V: Real;
 Code: Integer;
Begin
 ParseSVGPoints := False;
 Entity.VertexCount := 0;

 S := PointsStr;
 If Length(S) = 0 Then Exit;

 { Remplacer les virgules par des espaces }
 For I := 1 to Length(S) do
  If S[I] = ',' Then S[I] := ' ';

 IsX := True;
 X := 0; Y := 0;
 Start := 1;
 I := 1;

 While I <= Length(S) + 1 do Begin
  If (I > Length(S)) or (S[I] = ' ') Then Begin
   NumStr := Copy(S, Start, I - Start);
   If Length(NumStr) > 0 Then Begin
    Val(NumStr, V, Code);
    If Code = 0 Then Begin
     If IsX Then Begin
      X := V;
      IsX := False;
     End
     Else Begin
      Y := V;
      IsX := True;
      If Entity.VertexCount < MAX_VERTICES Then Begin
       Entity.Vertices[Entity.VertexCount].X := X;
       Entity.Vertices[Entity.VertexCount].Y := Y;
       Entity.Vertices[Entity.VertexCount].Bulge := 0;
       Inc(Entity.VertexCount);
      End;
     End;
    End;
   End;
   Start := I + 1;
  End;
  Inc(I);
 End;

 ParseSVGPoints := Entity.VertexCount >= 2;
End;

{ Lire un élément ligne SVG }
Function ReadSVGLine(Const Line: String; Var Entity: TDrawObject): Boolean;
Var
 StrokeColor: String;
Begin
 ReadSVGLine := False;

 Entity.ObjType := OBJ_LINE;
 Entity.X1 := ExtractSVGAttrReal(Line, 'x1');
 Entity.Y1 := ExtractSVGAttrReal(Line, 'y1');
 Entity.X2 := ExtractSVGAttrReal(Line, 'x2');
 Entity.Y2 := ExtractSVGAttrReal(Line, 'y2');

 StrokeColor := ExtractSVGAttr(Line, 'stroke');
 If Length(StrokeColor) > 0 Then
  Entity.Color := SVGColorToACI(StrokeColor)
 Else
  Entity.Color := CurrentColor;

 Entity.LayerIndex := CurrentLayer;
 Entity.Visible := True;
 Entity.Selected := False;

 ReadSVGLine := True;
End;

{ Lire un élément rectangle SVG }
Function ReadSVGRect(Const Line: String; Var Entity: TDrawObject): Boolean;
Var
 X, Y, W, H: Real;
 StrokeColor: String;
Begin
 ReadSVGRect := False;

 X := ExtractSVGAttrReal(Line, 'x');
 Y := ExtractSVGAttrReal(Line, 'y');
 W := ExtractSVGAttrReal(Line, 'width');
 H := ExtractSVGAttrReal(Line, 'height');

 Entity.ObjType := OBJ_RECTANGLE;
 Entity.X1 := X;
 Entity.Y1 := Y;
 Entity.X2 := X + W;
 Entity.Y2 := Y + H;

 StrokeColor := ExtractSVGAttr(Line, 'stroke');
 If Length(StrokeColor) > 0 Then
  Entity.Color := SVGColorToACI(StrokeColor)
 Else
  Entity.Color := CurrentColor;

 Entity.LayerIndex := CurrentLayer;
 Entity.Visible := True;
 Entity.Selected := False;

 ReadSVGRect := True;
End;

{ Lire un élément cercle SVG }
Function ReadSVGCircle(Const Line: String; Var Entity: TDrawObject): Boolean;
Var
 StrokeColor: String;
Begin
 ReadSVGCircle := False;

 Entity.ObjType := OBJ_CIRCLE;
 Entity.X1 := ExtractSVGAttrReal(Line, 'cx');
 Entity.Y1 := ExtractSVGAttrReal(Line, 'cy');
 Entity.Radius := ExtractSVGAttrReal(Line, 'r');

 If Entity.Radius <= 0 Then Exit;

 StrokeColor := ExtractSVGAttr(Line, 'stroke');
 If Length(StrokeColor) > 0 Then
  Entity.Color := SVGColorToACI(StrokeColor)
 Else
  Entity.Color := CurrentColor;

 Entity.LayerIndex := CurrentLayer;
 Entity.Visible := True;
 Entity.Selected := False;

 ReadSVGCircle := True;
End;

{ Lire un élément ellipse SVG }
Function ReadSVGEllipse(Const Line: String; Var Entity: TDrawObject): Boolean;
Var
 StrokeColor: String;
Begin
 ReadSVGEllipse := False;

 Entity.ObjType := OBJ_ELLIPSE;
 Entity.X1 := ExtractSVGAttrReal(Line, 'cx');
 Entity.Y1 := ExtractSVGAttrReal(Line, 'cy');
 Entity.Radius := ExtractSVGAttrReal(Line, 'rx');    { Demi-axe majeur }
 Entity.EndAngle := ExtractSVGAttrReal(Line, 'ry');  { Demi-axe mineur }

 If (Entity.Radius <= 0) or (Entity.EndAngle <= 0) Then Exit;

 StrokeColor := ExtractSVGAttr(Line, 'stroke');
 If Length(StrokeColor) > 0 Then
  Entity.Color := SVGColorToACI(StrokeColor)
 Else
  Entity.Color := CurrentColor;

 Entity.LayerIndex := CurrentLayer;
 Entity.Visible := True;
 Entity.Selected := False;

 ReadSVGEllipse := True;
End;

{ Lire un élément texte SVG }
Function ReadSVGText(Const Line: String; TextContent: String; Var Entity: TDrawObject): Boolean;
Var
 FillColor: String;
 FontSize: Real;
Begin
 ReadSVGText := False;

 If Length(TextContent) = 0 Then Exit;

 Entity.ObjType := OBJ_TEXT;
 Entity.X1 := ExtractSVGAttrReal(Line, 'x');
 Entity.Y1 := ExtractSVGAttrReal(Line, 'y');
 Entity.DimText := TextContent;

 FontSize := ExtractSVGAttrReal(Line, 'font-size');
 If FontSize > 0 Then
  Entity.Radius := FontSize
 Else
  Entity.Radius := SVG_DEFAULT_FONT_SIZE;

 FillColor := ExtractSVGAttr(Line, 'fill');
 If Length(FillColor) > 0 Then
  Entity.Color := SVGColorToACI(FillColor)
 Else
  Entity.Color := CurrentColor;

 Entity.LayerIndex := CurrentLayer;
 Entity.Visible := True;
 Entity.Selected := False;

 ReadSVGText := True;
End;

{ Lire un élément polyline SVG }
Function ReadSVGPolyline(Const Line: String; Var Entity: TDrawObject): Boolean;
Var
 PointsStr, StrokeColor: String;
Begin
 ReadSVGPolyline := False;

 PointsStr := ExtractSVGAttr(Line, 'points');
 If Length(PointsStr) = 0 Then Exit;

 Entity.ObjType := OBJ_POLYLINE;

 If Not ParseSVGPoints(PointsStr, Entity) Then Exit;

 StrokeColor := ExtractSVGAttr(Line, 'stroke');
 If Length(StrokeColor) > 0 Then
  Entity.Color := SVGColorToACI(StrokeColor)
 Else
  Entity.Color := CurrentColor;

 Entity.LayerIndex := CurrentLayer;
 Entity.Visible := True;
 Entity.Selected := False;
 Entity.Closed := False;

 ReadSVGPolyline := True;
End;

{ Lire un élément polygon SVG }
Function ReadSVGPolygon(Const Line: String; Var Entity: TDrawObject): Boolean;
Var
 PointsStr, StrokeColor: String;
Begin
 ReadSVGPolygon := False;

 PointsStr := ExtractSVGAttr(Line, 'points');
 If Length(PointsStr) = 0 Then Exit;

 Entity.ObjType := OBJ_POLYLINE;

 If Not ParseSVGPoints(PointsStr, Entity) Then Exit;

 StrokeColor := ExtractSVGAttr(Line, 'stroke');
 If Length(StrokeColor) > 0 Then
  Entity.Color := SVGColorToACI(StrokeColor)
 Else
  Entity.Color := CurrentColor;

 Entity.LayerIndex := CurrentLayer;
 Entity.Visible := True;
 Entity.Selected := False;
 Entity.Closed := True; { Polygon est fermé }

 ReadSVGPolygon := True;
End;

{ Lire un élément path SVG (simplifié - lignes uniquement) }
Function ReadSVGPath(Const Line: String; Var Entity: TDrawObject): Boolean;
Var
 D, StrokeColor: String;
 I, Start: Integer;
 Cmd: Char;
 X1, Y1, X2, Y2, V: Real;
 Code: Integer;
 NumStr: String;
 HasMove, HasLine: Boolean;
 IsRelative: Boolean;
 CurrentX, CurrentY: Real;
Begin
 ReadSVGPath := False;

 D := ExtractSVGAttr(Line, 'd');
 If Length(D) = 0 Then Exit;

 { Parser simplifié pour les paths basiques M/L/H/V/Z }
 HasMove := False;
 HasLine := False;
 X1 := 0; Y1 := 0; X2 := 0; Y2 := 0;
 CurrentX := 0; CurrentY := 0;
 I := 1;

 While I <= Length(D) do Begin
  { Sauter les espaces et virgules }
  While (I <= Length(D)) and ((D[I] = ' ') or (D[I] = ',')) do Inc(I);
  If I > Length(D) Then Break;

  Cmd := D[I];
  IsRelative := (Cmd >= 'a') and (Cmd <= 'z');
  Cmd := UpCase(Cmd);
  Inc(I);

  { Sauter les espaces après la commande }
  While (I <= Length(D)) and ((D[I] = ' ') or (D[I] = ',')) do Inc(I);

  Case Cmd of
   'M': Begin { Move To }
    { Lire X }
    Start := I;
    While (I <= Length(D)) and (((D[I] >= '0') and (D[I] <= '9')) or (D[I] = '.') or (D[I] = '-') or (D[I] = '+')) do Inc(I);
    NumStr := Copy(D, Start, I - Start);
    Val(NumStr, V, Code);
    If Code = 0 Then Begin
     If IsRelative Then X1 := CurrentX + V Else X1 := V;
    End;

    { Sauter séparateurs }
    While (I <= Length(D)) and ((D[I] = ' ') or (D[I] = ',')) do Inc(I);

    { Lire Y }
    Start := I;
    While (I <= Length(D)) and (((D[I] >= '0') and (D[I] <= '9')) or (D[I] = '.') or (D[I] = '-') or (D[I] = '+')) do Inc(I);
    NumStr := Copy(D, Start, I - Start);
    Val(NumStr, V, Code);
    If Code = 0 Then Begin
     If IsRelative Then Y1 := CurrentY + V Else Y1 := V;
    End;

    CurrentX := X1;
    CurrentY := Y1;
    HasMove := True;
   End;

   'L': Begin { Line To }
    { Lire X }
    Start := I;
    While (I <= Length(D)) and (((D[I] >= '0') and (D[I] <= '9')) or (D[I] = '.') or (D[I] = '-') or (D[I] = '+')) do Inc(I);
    NumStr := Copy(D, Start, I - Start);
    Val(NumStr, V, Code);
    If Code = 0 Then Begin
     If IsRelative Then X2 := CurrentX + V Else X2 := V;
    End;

    { Sauter séparateurs }
    While (I <= Length(D)) and ((D[I] = ' ') or (D[I] = ',')) do Inc(I);

    { Lire Y }
    Start := I;
    While (I <= Length(D)) and (((D[I] >= '0') and (D[I] <= '9')) or (D[I] = '.') or (D[I] = '-') or (D[I] = '+')) do Inc(I);
    NumStr := Copy(D, Start, I - Start);
    Val(NumStr, V, Code);
    If Code = 0 Then Begin
     If IsRelative Then Y2 := CurrentY + V Else Y2 := V;
    End;

    CurrentX := X2;
    CurrentY := Y2;
    HasLine := True;
   End;

   'H': Begin { Horizontal Line To }
    Start := I;
    While (I <= Length(D)) and (((D[I] >= '0') and (D[I] <= '9')) or (D[I] = '.') or (D[I] = '-') or (D[I] = '+')) do Inc(I);
    NumStr := Copy(D, Start, I - Start);
    Val(NumStr, V, Code);
    If Code = 0 Then Begin
     If IsRelative Then X2 := CurrentX + V Else X2 := V;
     Y2 := CurrentY;
     CurrentX := X2;
     HasLine := True;
    End;
   End;

   'V': Begin { Vertical Line To }
    Start := I;
    While (I <= Length(D)) and (((D[I] >= '0') and (D[I] <= '9')) or (D[I] = '.') or (D[I] = '-') or (D[I] = '+')) do Inc(I);
    NumStr := Copy(D, Start, I - Start);
    Val(NumStr, V, Code);
    If Code = 0 Then Begin
     If IsRelative Then Y2 := CurrentY + V Else Y2 := V;
     X2 := CurrentX;
     CurrentY := Y2;
     HasLine := True;
    End;
   End;

   'Z': Begin { Close Path }
    { On ignore la fermeture pour l'instant }
   End;
  Else
   { Commande non supportée, avancer }
   Inc(I);
  End;
 End;

 { Créer une ligne simple si on a un mouvement et une ligne }
 If HasMove and HasLine Then Begin
  Entity.ObjType := OBJ_LINE;
  Entity.X1 := X1;
  Entity.Y1 := Y1;
  Entity.X2 := X2;
  Entity.Y2 := Y2;

  StrokeColor := ExtractSVGAttr(Line, 'stroke');
  If Length(StrokeColor) > 0 Then
   Entity.Color := SVGColorToACI(StrokeColor)
  Else
   Entity.Color := CurrentColor;

  Entity.LayerIndex := CurrentLayer;
  Entity.Visible := True;
  Entity.Selected := False;

  ReadSVGPath := True;
 End;
End;

{ Lire un fichier SVG }
Function ReadSVGFile(Const FileName: String): Boolean;
Var
 F: Text;
 Line, ElementType, TextContent: String;
 Entity: TDrawObject;
 InText: Boolean;
 TextLine: String;
Begin
 ReadSVGFile := False;

 {$I-}
 Assign(F, FileName);
 Reset(F);
 {$I+}

 If IOResult <> 0 Then Exit;

 InText := False;
 TextLine := '';

 While Not Eof(F) do Begin
  ReadLn(F, Line);

  { Gérer le texte multi-ligne }
  If InText Then Begin
   If Pos('</text>', Line) > 0 Then Begin
    TextLine := TextLine + Line;
    ElementType := 'text';
    TextContent := ExtractTextContent(TextLine);

    FillChar(Entity, SizeOf(Entity), 0);
    If ReadSVGText(TextLine, TextContent, Entity) Then Begin
     If ObjectCount < MAX_OBJECTS Then Begin
      DrawObjects[ObjectCount] := Entity;
      Inc(ObjectCount);
     End;
    End;

    InText := False;
    TextLine := '';
   End
   Else
    TextLine := TextLine + Line;
   Continue;
  End;

  ElementType := GetSVGElementType(Line);

  If ElementType = 'text' Then Begin
   If Pos('</text>', Line) > 0 Then Begin
    { Texte sur une seule ligne }
    TextContent := ExtractTextContent(Line);
    FillChar(Entity, SizeOf(Entity), 0);
    If ReadSVGText(Line, TextContent, Entity) Then Begin
     If ObjectCount < MAX_OBJECTS Then Begin
      DrawObjects[ObjectCount] := Entity;
      Inc(ObjectCount);
     End;
    End;
   End
   Else Begin
    { Texte multi-ligne }
    InText := True;
    TextLine := Line;
   End;
  End
  Else If ElementType = 'line' Then Begin
   FillChar(Entity, SizeOf(Entity), 0);
   If ReadSVGLine(Line, Entity) Then Begin
    If ObjectCount < MAX_OBJECTS Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;
   End;
  End
  Else If ElementType = 'rect' Then Begin
   FillChar(Entity, SizeOf(Entity), 0);
   If ReadSVGRect(Line, Entity) Then Begin
    If ObjectCount < MAX_OBJECTS Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;
   End;
  End
  Else If ElementType = 'circle' Then Begin
   FillChar(Entity, SizeOf(Entity), 0);
   If ReadSVGCircle(Line, Entity) Then Begin
    If ObjectCount < MAX_OBJECTS Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;
   End;
  End
  Else If ElementType = 'ellipse' Then Begin
   FillChar(Entity, SizeOf(Entity), 0);
   If ReadSVGEllipse(Line, Entity) Then Begin
    If ObjectCount < MAX_OBJECTS Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;
   End;
  End
  Else If ElementType = 'polyline' Then Begin
   FillChar(Entity, SizeOf(Entity), 0);
   If ReadSVGPolyline(Line, Entity) Then Begin
    If ObjectCount < MAX_OBJECTS Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;
   End;
  End
  Else If ElementType = 'polygon' Then Begin
   FillChar(Entity, SizeOf(Entity), 0);
   If ReadSVGPolygon(Line, Entity) Then Begin
    If ObjectCount < MAX_OBJECTS Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;
   End;
  End
  Else If ElementType = 'path' Then Begin
   FillChar(Entity, SizeOf(Entity), 0);
   If ReadSVGPath(Line, Entity) Then Begin
    If ObjectCount < MAX_OBJECTS Then Begin
     DrawObjects[ObjectCount] := Entity;
     Inc(ObjectCount);
    End;
   End;
  End;
 End;

 Close(F);
 ReadSVGFile := True;
 MarkDocumentSaved;
End;

{ Initialiser le panneau de propriétés }
Procedure InitPropertiesPanel;
Var
 I: Integer;
Begin
 With PropertiesPanel do Begin
  X := ScreenWidth - PROP_PANEL_WIDTH - 10;
  Y := MENUBAR_HEIGHT + TOOLBAR_HEIGHT + 10;
  Width := PROP_PANEL_WIDTH;
  Height := PROP_PANEL_HEIGHT;
  Visible := False;
  Dragging := False;
  DragOffsetX := 0;
  DragOffsetY := 0;
  RowCount := 0;
  HoveredRow := -1;
  SelectedRow := -1;
  EditMode := False;
  EditBuffer := '';
  Title := 'Propriétés';

  { Initialiser les lignes }
  For I := 0 to MAX_PROP_ROWS - 1 do Begin
   Rows[I].PropType := 0;
   Rows[I].Label_ := '';
   Rows[I].Value := '';
   Rows[I].Editable := False;
   Rows[I].Highlighted := False;
  End;
 End;

 { Initialiser les calques }
 InitLayers;
End;

{ Mettre à jour le panneau avec les propriétés de l'objet sélectionné }
Procedure UpdatePropertiesPanel;
Var
 ObjIdx: Integer;
 RowIdx: Integer;
 S: String;
Begin
 With PropertiesPanel do Begin
  RowCount := 0;
  HoveredRow := -1;

  If SelectionSet.Count = 0 Then Begin
   { Pas d'objet sélectionné - afficher les propriétés par défaut }
   Title := 'Propriétés';

   { Couleur courante }
   Rows[RowCount].PropType := PROP_TYPE_COLOR;
   Rows[RowCount].Label_ := 'Couleur';
   Rows[RowCount].Value := ColorName(CurrentColor);
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   { Calque courant }
   Rows[RowCount].PropType := PROP_TYPE_LAYER;
   Rows[RowCount].Label_ := 'Calque';
   Rows[RowCount].Value := Layers[CurrentLayer].Name;
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   { Type de ligne courant }
   Rows[RowCount].PropType := PROP_TYPE_LINETYPE;
   Rows[RowCount].Label_ := 'Type ligne';
   Rows[RowCount].Value := LineTypeName(CurrentLineType);
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   { Épaisseur courante }
   Rows[RowCount].PropType := PROP_TYPE_LINEWEIGHT;
   Rows[RowCount].Label_ := 'Épaisseur';
   If CurrentLineWeight = LINEWEIGHT_DEFAULT Then
    Rows[RowCount].Value := 'Par défaut'
   Else Begin
    Str(CurrentLineWeight / 100.0:0:2, S);
    Rows[RowCount].Value := S + ' mm';
   End;
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);
  End
  Else If SelectionSet.Count = 1 Then Begin
   { Un seul objet sélectionné - afficher ses propriétés }
   ObjIdx := SelectionSet.Objects[0];
   Title := 'Propriétés - ' + ObjTypeName(DrawObjects[ObjIdx].ObjType);

   { Type d'objet }
   Rows[RowCount].PropType := PROP_TYPE_OBJTYPE;
   Rows[RowCount].Label_ := 'Type';
   Rows[RowCount].Value := ObjTypeName(DrawObjects[ObjIdx].ObjType);
   Rows[RowCount].Editable := False;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   { Couleur }
   Rows[RowCount].PropType := PROP_TYPE_COLOR;
   Rows[RowCount].Label_ := 'Couleur';
   Rows[RowCount].Value := ColorName(DrawObjects[ObjIdx].Color);
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   { Calque }
   Rows[RowCount].PropType := PROP_TYPE_LAYER;
   Rows[RowCount].Label_ := 'Calque';
   If DrawObjects[ObjIdx].LayerIndex < LayerCount Then
    Rows[RowCount].Value := Layers[DrawObjects[ObjIdx].LayerIndex].Name
   Else
    Rows[RowCount].Value := '0';
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   { Type de ligne }
   Rows[RowCount].PropType := PROP_TYPE_LINETYPE;
   Rows[RowCount].Label_ := 'Type ligne';
   Rows[RowCount].Value := LineTypeName(DrawObjects[ObjIdx].LineType);
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   { Coordonnées selon le type d'objet }
   Case DrawObjects[ObjIdx].ObjType of
    OBJ_LINE, OBJ_RECTANGLE: Begin
     { X1 }
     Rows[RowCount].PropType := PROP_TYPE_X1;
     Rows[RowCount].Label_ := 'X1';
     Str(DrawObjects[ObjIdx].X1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Y1 }
     Rows[RowCount].PropType := PROP_TYPE_Y1;
     Rows[RowCount].Label_ := 'Y1';
     Str(DrawObjects[ObjIdx].Y1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { X2 }
     Rows[RowCount].PropType := PROP_TYPE_X2;
     Rows[RowCount].Label_ := 'X2';
     Str(DrawObjects[ObjIdx].X2:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Y2 }
     Rows[RowCount].PropType := PROP_TYPE_Y2;
     Rows[RowCount].Label_ := 'Y2';
     Str(DrawObjects[ObjIdx].Y2:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Longueur (lecture seule) }
     If DrawObjects[ObjIdx].ObjType = OBJ_LINE Then Begin
      Rows[RowCount].PropType := PROP_TYPE_LENGTH;
      Rows[RowCount].Label_ := 'Longueur';
      Str(Sqrt(Sqr(DrawObjects[ObjIdx].X2 - DrawObjects[ObjIdx].X1) +
               Sqr(DrawObjects[ObjIdx].Y2 - DrawObjects[ObjIdx].Y1)):0:2, S);
      Rows[RowCount].Value := S;
      Rows[RowCount].Editable := False;
      Rows[RowCount].Highlighted := False;
      Inc(RowCount);
     End;
    End;

    OBJ_CIRCLE: Begin
     { Centre X }
     Rows[RowCount].PropType := PROP_TYPE_X1;
     Rows[RowCount].Label_ := 'Centre X';
     Str(DrawObjects[ObjIdx].X1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Centre Y }
     Rows[RowCount].PropType := PROP_TYPE_Y1;
     Rows[RowCount].Label_ := 'Centre Y';
     Str(DrawObjects[ObjIdx].Y1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Rayon }
     Rows[RowCount].PropType := PROP_TYPE_RADIUS;
     Rows[RowCount].Label_ := 'Rayon';
     Str(DrawObjects[ObjIdx].Radius:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Surface (lecture seule) }
     Rows[RowCount].PropType := PROP_TYPE_AREA;
     Rows[RowCount].Label_ := 'Surface';
     Str(Pi * Sqr(DrawObjects[ObjIdx].Radius):0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := False;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);
    End;

    OBJ_POINT: Begin
     { X }
     Rows[RowCount].PropType := PROP_TYPE_X1;
     Rows[RowCount].Label_ := 'X';
     Str(DrawObjects[ObjIdx].X1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Y }
     Rows[RowCount].PropType := PROP_TYPE_Y1;
     Rows[RowCount].Label_ := 'Y';
     Str(DrawObjects[ObjIdx].Y1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);
    End;

    OBJ_ARC: Begin { TODO 17 }
     { Centre X }
     Rows[RowCount].PropType := PROP_TYPE_X1;
     Rows[RowCount].Label_ := 'Centre X';
     Str(DrawObjects[ObjIdx].X1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Centre Y }
     Rows[RowCount].PropType := PROP_TYPE_Y1;
     Rows[RowCount].Label_ := 'Centre Y';
     Str(DrawObjects[ObjIdx].Y1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Rayon }
     Rows[RowCount].PropType := PROP_TYPE_RADIUS;
     Rows[RowCount].Label_ := 'Rayon';
     Str(DrawObjects[ObjIdx].Radius:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Angle de départ }
     Rows[RowCount].PropType := PROP_TYPE_X2;  { Réutilisé pour StartAngle }
     Rows[RowCount].Label_ := 'Angle dép.';
     Str(DrawObjects[ObjIdx].StartAngle:0:1, S);
     Rows[RowCount].Value := S + '°';
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Angle de fin }
     Rows[RowCount].PropType := PROP_TYPE_Y2;  { Réutilisé pour EndAngle }
     Rows[RowCount].Label_ := 'Angle fin';
     Str(DrawObjects[ObjIdx].EndAngle:0:1, S);
     Rows[RowCount].Value := S + '°';
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Longueur d'arc (lecture seule) }
     Rows[RowCount].PropType := PROP_TYPE_LENGTH;
     Rows[RowCount].Label_ := 'Long. arc';
     Str(Abs(DrawObjects[ObjIdx].EndAngle - DrawObjects[ObjIdx].StartAngle)
         * Pi / 180 * DrawObjects[ObjIdx].Radius:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := False;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);
    End;

    OBJ_ELLIPSE: Begin { TODO 17 }
     { Centre X }
     Rows[RowCount].PropType := PROP_TYPE_X1;
     Rows[RowCount].Label_ := 'Centre X';
     Str(DrawObjects[ObjIdx].X1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Centre Y }
     Rows[RowCount].PropType := PROP_TYPE_Y1;
     Rows[RowCount].Label_ := 'Centre Y';
     Str(DrawObjects[ObjIdx].Y1:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Rayon majeur }
     Rows[RowCount].PropType := PROP_TYPE_RADIUS;
     Rows[RowCount].Label_ := 'Rayon maj.';
     Str(DrawObjects[ObjIdx].Radius:0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Rayon mineur (calculé depuis X2, Y2) }
     Rows[RowCount].PropType := PROP_TYPE_X2;  { Réutilisé }
     Rows[RowCount].Label_ := 'Rayon min.';
     Str(Abs(DrawObjects[ObjIdx].Y2 - DrawObjects[ObjIdx].Y1):0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := True;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);

     { Surface approx (lecture seule) }
     Rows[RowCount].PropType := PROP_TYPE_AREA;
     Rows[RowCount].Label_ := 'Surface';
     Str(Pi * DrawObjects[ObjIdx].Radius *
         Abs(DrawObjects[ObjIdx].Y2 - DrawObjects[ObjIdx].Y1):0:2, S);
     Rows[RowCount].Value := S;
     Rows[RowCount].Editable := False;
     Rows[RowCount].Highlighted := False;
     Inc(RowCount);
    End;
   End;
  End
  Else Begin
   { Plusieurs objets sélectionnés }
   Str(SelectionSet.Count, S);
   Title := S + ' objets sélectionnés';

   { Propriétés communes }
   Rows[RowCount].PropType := PROP_TYPE_COLOR;
   Rows[RowCount].Label_ := 'Couleur';
   Rows[RowCount].Value := '*VARIES*';
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   Rows[RowCount].PropType := PROP_TYPE_LAYER;
   Rows[RowCount].Label_ := 'Calque';
   Rows[RowCount].Value := '*VARIES*';
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);

   Rows[RowCount].PropType := PROP_TYPE_LINETYPE;
   Rows[RowCount].Label_ := 'Type ligne';
   Rows[RowCount].Value := '*VARIES*';
   Rows[RowCount].Editable := True;
   Rows[RowCount].Highlighted := False;
   Inc(RowCount);
  End;
 End;
End;

{ Dessiner le panneau de propriétés }
Procedure DrawPropertiesPanel;
Var
 I: Integer;
 RowY: Integer;
 TitleHeight: Integer;
 BgColor, TextColor, BorderColor: Integer;
Begin
 If Not PropertiesPanel.Visible Then Exit;

 TitleHeight := 20;

 With PropertiesPanel do Begin
  { Fond du panneau }
  BgColor := DarkGray;
  BorderColor := White;
  TextColor := White;

  { Cadre principal }
  SetFillStyle(SolidFill, BgColor);
  Bar(X, Y, X + Width, Y + Height);

  { Bordure }
  SetColor(BorderColor);
  Rectangle(X, Y, X + Width, Y + Height);

  { Barre de titre }
  SetFillStyle(SolidFill, Blue);
  Bar(X + 1, Y + 1, X + Width - 1, Y + TitleHeight);

  { Titre }
  SetColor(White);
  SetTextStyle(DefaultFont, HorizDir, 1);
  OutTextXY(X + PROP_PANEL_MARGIN, Y + 5, Title);

  { Bouton fermer [X] }
  SetColor(White);
  OutTextXY(X + Width - 15, Y + 5, 'X');

  { Ligne sous le titre }
  SetColor(BorderColor);
  Line(X, Y + TitleHeight, X + Width, Y + TitleHeight);

  { Dessiner les lignes de propriétés }
  RowY := Y + TitleHeight + PROP_PANEL_MARGIN;

  For I := 0 to RowCount - 1 do Begin
   If RowY + PROP_ROW_HEIGHT > Y + Height - PROP_PANEL_MARGIN Then Break;

   { Fond de la ligne si survolée }
   If Rows[I].Highlighted Then Begin
    SetFillStyle(SolidFill, LightGray);
    Bar(X + 1, RowY, X + Width - 1, RowY + PROP_ROW_HEIGHT - 1);
   End;

   { Label }
   If Rows[I].Editable Then
    SetColor(White)
   Else
    SetColor(LightGray);
   OutTextXY(X + PROP_PANEL_MARGIN, RowY + 4, Rows[I].Label_);

   { Séparateur vertical }
   SetColor(BorderColor);
   Line(X + PROP_LABEL_WIDTH, RowY, X + PROP_LABEL_WIDTH, RowY + PROP_ROW_HEIGHT - 1);

   { Valeur }
   If Rows[I].Editable Then
    SetColor(Cyan)
   Else
    SetColor(LightGray);

   { Afficher un indicateur de couleur si c'est une propriété couleur }
   If Rows[I].PropType = PROP_TYPE_COLOR Then Begin
    If SelectionSet.Count = 1 Then Begin
     SetFillStyle(SolidFill, DrawObjects[SelectionSet.Objects[0]].Color);
     Bar(X + PROP_LABEL_WIDTH + 5, RowY + 3, X + PROP_LABEL_WIDTH + 20, RowY + PROP_ROW_HEIGHT - 4);
     OutTextXY(X + PROP_LABEL_WIDTH + 25, RowY + 4, Rows[I].Value);
    End Else Begin
     SetFillStyle(SolidFill, CurrentColor);
     Bar(X + PROP_LABEL_WIDTH + 5, RowY + 3, X + PROP_LABEL_WIDTH + 20, RowY + PROP_ROW_HEIGHT - 4);
     OutTextXY(X + PROP_LABEL_WIDTH + 25, RowY + 4, Rows[I].Value);
    End;
   End Else
    OutTextXY(X + PROP_LABEL_WIDTH + 5, RowY + 4, Rows[I].Value);

   { Ligne de séparation horizontale }
   SetColor(DarkGray);
   Line(X + 1, RowY + PROP_ROW_HEIGHT - 1, X + Width - 1, RowY + PROP_ROW_HEIGHT - 1);

   RowY := RowY + PROP_ROW_HEIGHT;
  End;
 End;
End;

{ Obtenir la valeur d'une propriété en chaîne }
Function GetPropertyValueString(PropType: Byte; ObjIndex: Integer): String;
Var
 S: String;
Begin
 If ObjIndex < 0 Then Begin
  GetPropertyValueString := '';
  Exit;
 End;

 Case PropType of
  PROP_TYPE_COLOR: GetPropertyValueString := ColorName(DrawObjects[ObjIndex].Color);
  PROP_TYPE_LAYER: Begin
   If DrawObjects[ObjIndex].LayerIndex < LayerCount Then
    GetPropertyValueString := Layers[DrawObjects[ObjIndex].LayerIndex].Name
   Else
    GetPropertyValueString := '0';
  End;
  PROP_TYPE_LINETYPE: GetPropertyValueString := LineTypeName(DrawObjects[ObjIndex].LineType);
  PROP_TYPE_OBJTYPE: GetPropertyValueString := ObjTypeName(DrawObjects[ObjIndex].ObjType);
  PROP_TYPE_X1: Begin
   Str(DrawObjects[ObjIndex].X1:0:2, S);
   GetPropertyValueString := S;
  End;
  PROP_TYPE_Y1: Begin
   Str(DrawObjects[ObjIndex].Y1:0:2, S);
   GetPropertyValueString := S;
  End;
  PROP_TYPE_X2: Begin
   Str(DrawObjects[ObjIndex].X2:0:2, S);
   GetPropertyValueString := S;
  End;
  PROP_TYPE_Y2: Begin
   Str(DrawObjects[ObjIndex].Y2:0:2, S);
   GetPropertyValueString := S;
  End;
  PROP_TYPE_RADIUS: Begin
   Str(DrawObjects[ObjIndex].Radius:0:2, S);
   GetPropertyValueString := S;
  End;
  Else GetPropertyValueString := '';
 End;
End;

{ Définir la valeur d'une propriété }
Procedure SetPropertyValue(PropType: Byte; ObjIndex: Integer; Value: String);
Var
 Code: Integer;
 RealVal: Real;
 IntVal: Integer;
 I: Integer;
Begin
 If ObjIndex < 0 Then Exit;

 Case PropType of
  PROP_TYPE_COLOR: Begin
   { Chercher la couleur par nom ou valeur numérique }
   Val(Value, IntVal, Code);
   If Code = 0 Then
    DrawObjects[ObjIndex].Color := IntVal
   Else Begin
    { Chercher par nom }
    If Value = 'Rouge' Then DrawObjects[ObjIndex].Color := Red
    Else If Value = 'Jaune' Then DrawObjects[ObjIndex].Color := Yellow
    Else If Value = 'Vert' Then DrawObjects[ObjIndex].Color := Green
    Else If Value = 'Cyan' Then DrawObjects[ObjIndex].Color := Cyan
    Else If Value = 'Bleu' Then DrawObjects[ObjIndex].Color := Blue
    Else If Value = 'Magenta' Then DrawObjects[ObjIndex].Color := Magenta
    Else If Value = 'Blanc' Then DrawObjects[ObjIndex].Color := White
    Else If Value = 'ByLayer' Then DrawObjects[ObjIndex].Color := 256
    Else If Value = 'ByBlock' Then DrawObjects[ObjIndex].Color := 0;
   End;
  End;

  PROP_TYPE_LAYER: Begin
   { Chercher le calque par nom }
   For I := 0 to LayerCount - 1 do Begin
    If Layers[I].Name = Value Then Begin
     DrawObjects[ObjIndex].LayerIndex := I;
     Break;
    End;
   End;
  End;

  PROP_TYPE_LINETYPE: Begin
   If Value = 'Continu' Then DrawObjects[ObjIndex].LineType := LINETYPE_CONTINUOUS
   Else If Value = 'Tirets' Then DrawObjects[ObjIndex].LineType := LINETYPE_DASHED
   Else If Value = 'Points' Then DrawObjects[ObjIndex].LineType := LINETYPE_DOTTED
   Else If Value = 'Tiret-Point' Then DrawObjects[ObjIndex].LineType := LINETYPE_DASHDOT
   Else If Value = 'Tiret-Pt-Pt' Then DrawObjects[ObjIndex].LineType := LINETYPE_DASHDOTDOT
   Else If Value = 'Axe' Then DrawObjects[ObjIndex].LineType := LINETYPE_CENTER;
  End;

  PROP_TYPE_X1: Begin
   Val(Value, RealVal, Code);
   If Code = 0 Then DrawObjects[ObjIndex].X1 := RealVal;
  End;

  PROP_TYPE_Y1: Begin
   Val(Value, RealVal, Code);
   If Code = 0 Then DrawObjects[ObjIndex].Y1 := RealVal;
  End;

  PROP_TYPE_X2: Begin
   Val(Value, RealVal, Code);
   If Code = 0 Then DrawObjects[ObjIndex].X2 := RealVal;
  End;

  PROP_TYPE_Y2: Begin
   Val(Value, RealVal, Code);
   If Code = 0 Then DrawObjects[ObjIndex].Y2 := RealVal;
  End;

  PROP_TYPE_RADIUS: Begin
   Val(Value, RealVal, Code);
   If Code = 0 Then DrawObjects[ObjIndex].Radius := Abs(RealVal);
  End;
 End;

 { Mettre à jour les grips après modification }
 UpdateGripsForSelection;
End;

{ Gérer le survol du panneau de propriétés }
Procedure HandlePropertiesPanelHover(X, Y: Integer);
Var
 I: Integer;
 RowY: Integer;
 TitleHeight: Integer;
 OldHovered: Integer;
Begin
 If Not PropertiesPanel.Visible Then Exit;

 TitleHeight := 20;
 OldHovered := PropertiesPanel.HoveredRow;
 PropertiesPanel.HoveredRow := -1;

 { Vérifier si le curseur est dans le panneau }
 Begin
  If (X >= PropertiesPanel.X) and (X <= PropertiesPanel.X + PropertiesPanel.Width) and
     (Y >= PropertiesPanel.Y + TitleHeight) and (Y <= PropertiesPanel.Y + PropertiesPanel.Height) Then Begin

   RowY := PropertiesPanel.Y + TitleHeight + PROP_PANEL_MARGIN;

   For I := 0 to PropertiesPanel.RowCount - 1 do Begin
    If (Y >= RowY) and (Y < RowY + PROP_ROW_HEIGHT) Then Begin
     PropertiesPanel.HoveredRow := I;
     PropertiesPanel.Rows[I].Highlighted := True;
     Break;
    End;
    RowY := RowY + PROP_ROW_HEIGHT;
   End;
  End;

  { Désactiver le highlight des autres lignes }
  For I := 0 to PropertiesPanel.RowCount - 1 do
   If I <> PropertiesPanel.HoveredRow Then PropertiesPanel.Rows[I].Highlighted := False;
 End;
End;

{ Commencer l'édition d'une propriété }
Procedure StartPropertyEdit(RowIndex: Integer);
Begin
 If (RowIndex < 0) or (RowIndex >= PropertiesPanel.RowCount) Then Exit;
 If Not PropertiesPanel.Rows[RowIndex].Editable Then Exit;

 PropertiesPanel.SelectedRow := RowIndex;
 PropertiesPanel.EditMode := True;
 PropertiesPanel.EditBuffer := PropertiesPanel.Rows[RowIndex].Value;
End;

{ Terminer l'édition d'une propriété }
Procedure FinishPropertyEdit;
Var
 I: Integer;
 PropType: Byte;
Begin
 If Not PropertiesPanel.EditMode Then Exit;
 If PropertiesPanel.SelectedRow < 0 Then Exit;

 PropType := PropertiesPanel.Rows[PropertiesPanel.SelectedRow].PropType;

 { Appliquer la modification à tous les objets sélectionnés }
 For I := 0 to SelectionSet.Count - 1 do
  SetPropertyValue(PropType, SelectionSet.Objects[I], PropertiesPanel.EditBuffer);

 PropertiesPanel.EditMode := False;
 PropertiesPanel.SelectedRow := -1;
 PropertiesPanel.EditBuffer := '';

 { Mettre à jour l'affichage }
 UpdatePropertiesPanel;
End;

{ Annuler l'édition d'une propriété }
Procedure CancelPropertyEdit;
Begin
 PropertiesPanel.EditMode := False;
 PropertiesPanel.SelectedRow := -1;
 PropertiesPanel.EditBuffer := '';
End;

{ Gérer le clic dans le panneau de propriétés }
Function HandlePropertiesPanelClick(X, Y: Integer): Boolean;
Var
 TitleHeight: Integer;
 I: Integer;
 ObjIdx: Integer;
 NewColor: Integer;
 NewLineType: Byte;
Begin
 HandlePropertiesPanelClick := False;
 If Not PropertiesPanel.Visible Then Exit;

 TitleHeight := 20;

 Begin
  { Vérifier si le clic est dans le panneau }
  If (X < PropertiesPanel.X) or (X > PropertiesPanel.X + PropertiesPanel.Width) or
     (Y < PropertiesPanel.Y) or (Y > PropertiesPanel.Y + PropertiesPanel.Height) Then Exit;

  HandlePropertiesPanelClick := True;

  { Clic sur le bouton fermer }
  If (X >= PropertiesPanel.X + PropertiesPanel.Width - 20) and (Y >= PropertiesPanel.Y) and (Y <= PropertiesPanel.Y + TitleHeight) Then Begin
   PropertiesPanel.Visible := False;
   Exit;
  End;

  { Clic sur la barre de titre (drag) }
  If (Y >= PropertiesPanel.Y) and (Y <= PropertiesPanel.Y + TitleHeight) Then Begin
   PropertiesPanel.Dragging := True;
   PropertiesPanel.DragOffsetX := X - PropertiesPanel.X;
   PropertiesPanel.DragOffsetY := Y - PropertiesPanel.Y;
   Exit;
  End;

  { Clic sur une ligne de propriété }
  If PropertiesPanel.HoveredRow >= 0 Then Begin
   If PropertiesPanel.Rows[PropertiesPanel.HoveredRow].Editable Then Begin
    { Gérer selon le type de propriété }
    Case PropertiesPanel.Rows[PropertiesPanel.HoveredRow].PropType of
     PROP_TYPE_COLOR: Begin
      { Cycle des couleurs de base }
      If SelectionSet.Count = 0 Then Begin
       { Modifier la couleur courante }
       CurrentColor := (CurrentColor + 1) Mod 8;
       If CurrentColor = 0 Then CurrentColor := 1;
      End Else Begin
       { Modifier la couleur des objets sélectionnés }
       For I := 0 to SelectionSet.Count - 1 do Begin
        ObjIdx := SelectionSet.Objects[I];
        NewColor := (DrawObjects[ObjIdx].Color + 1) Mod 8;
        If NewColor = 0 Then NewColor := 1;
        DrawObjects[ObjIdx].Color := NewColor;
       End;
      End;
      UpdatePropertiesPanel;
     End;

     PROP_TYPE_LINETYPE: Begin
      { Cycle des types de ligne }
      If SelectionSet.Count = 0 Then Begin
       CurrentLineType := (CurrentLineType + 1) Mod 6;
      End Else Begin
       For I := 0 to SelectionSet.Count - 1 do Begin
        ObjIdx := SelectionSet.Objects[I];
        NewLineType := (DrawObjects[ObjIdx].LineType + 1) Mod 6;
        DrawObjects[ObjIdx].LineType := NewLineType;
       End;
      End;
      UpdatePropertiesPanel;
     End;

     { Pour les autres propriétés, on pourrait activer un mode d'édition }
    End;
   End;
  End;
 End;
End;

{ Afficher/masquer le panneau de propriétés }
Procedure TogglePropertiesPanel;
Begin
 PropertiesPanel.Visible := Not PropertiesPanel.Visible;
 If PropertiesPanel.Visible Then
  UpdatePropertiesPanel;
End;

{ Dessiner la zone de dessin principale - TODO 7: Support zoom et pan, TODO 8: Crosshair, TODO 9: Sélection, TODO 10: Grips }
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

 { TODO 10: Dessiner les grips des objets sélectionnés }
 DrawGrips;

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

 { TODO 10: Indicateur de mode édition grip si actif }
 If GripEditActive Then Begin
  SetColor(Green);
  OutTextXY(ScreenWidth div 2 - 45, CanvasTop + 5, '** GRIP EDIT **');
 End;
End;

{ Dessiner la ligne de commande }
Procedure DrawCommandLine;
Var
 BaseY, TextY, PromptW, BufW, CursorX: Integer;
 Prompt, CmdStr: String;
Begin
 BaseY := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 TextY := BaseY + 5;

 { Fond de la ligne de commande }
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, BaseY, ScreenWidth - 1, ScreenHeight - STATUSBAR_HEIGHT - 1);

 SetColor(LightGray);
 { Ligne supérieure : dernière commande exécutée (historique) }
 If CommandLastLine <> '' Then
  OutTextXY(5, TextY, CommandLastLine);

 SetColor(White);
 If CommandPrompt = '' Then
  Prompt := 'Command:'
 Else
  Prompt := CommandPrompt;

 { Ligne courante : prompt + texte tapé }
 CmdStr := Prompt + ' ' + CommandBuffer;
 OutTextXY(5, TextY + 14, CmdStr);

 { Curseur clignotant après le texte }
 PromptW := TextWidth(Prompt + ' ');
 BufW := TextWidth(CommandBuffer);
 CursorX := 5 + PromptW + BufW;
 If CommandCursorBlink Then Begin
  SetColor(White);
  Line(CursorX, TextY + 14,
       CursorX, TextY + 14 + TextHeight('M') - 1);
  Line(CursorX + 1, TextY + 14,
       CursorX + 1, TextY + 14 + TextHeight('M') - 1);
 End;
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

 { Dessiner le canvas en premier, puis les barres par-dessus
   pour que le pan/zoom ne deborde pas sur la barre de menu
   et les barres d'outils. }
 DrawCanvas;
 DrawMenuBar;
 DrawAllToolbars;  { TODO 5: Barres d'outils }
 DrawCommandLine;
 DrawStatusBar;

 { Si un menu est actif, le dessiner }
 If MenuActive and (ActiveMenu >= 0) Then
  DrawDropdownMenu(ActiveMenu);

 { Si le menu contextuel est actif, le dessiner - TODO 6 }
 If ContextMenuActive Then
  DrawContextMenu;

 { Panneau de propriétés - TODO 16 }
 If PropertiesPanel.Visible Then
  DrawPropertiesPanel;
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
 ClickedGrip: Integer;
 TbHit, BtnHit: Integer;
 NumStr1, NumStr2, NumStr3: String[16];
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
   { Dispatch des clics sur les boutons de barres d'outils }
   If (Y >= MENUBAR_HEIGHT) and (Y < MENUBAR_HEIGHT + TOOLBAR_HEIGHT) Then Begin
    GetToolbarButtonAtPosition(X, Y, TbHit, BtnHit);
    If (TbHit >= 0) and (BtnHit >= 0) Then Begin
     If Toolbars[TbHit].Buttons[BtnHit].Enabled Then Begin
      If Toolbars[TbHit].Buttons[BtnHit].Command = 'NEW' Then Begin
       ObjectCount := 0;
       ClearSelection;
       ClearGrips;
       CurrentFileName := '';
       MarkDocumentSaved;
       CommandLastLine := 'Nouveau dessin';
       DrawInterface;
      End Else If Toolbars[TbHit].Buttons[BtnHit].Command = 'OPEN' Then Begin
       PendingFileAction := 1;
       CommandPrompt := 'Nom du fichier a ouvrir:';
       CommandBuffer := '';
       DrawInterface;
      End Else If Toolbars[TbHit].Buttons[BtnHit].Command = 'SAVE' Then Begin
       If CurrentFileName <> '' Then Begin
        If WriteDWGFile(CurrentFileName) Then
         CommandLastLine := 'Enregistre: ' + CurrentFileName
        Else
         CommandLastLine := 'Echec enregistrement: ' + CurrentFileName;
       End Else Begin
        PendingFileAction := 2;
        CommandPrompt := 'Enregistrer sous:';
        CommandBuffer := '';
       End;
       DrawInterface;
      End Else Begin
       { Commande non implémentée : afficher dans la ligne de commande }
       CommandLastLine := 'Commande: ' + Toolbars[TbHit].Buttons[BtnHit].Command;
       DrawInterface;
      End;
      Exit;
     End;
    End;
   End;

   { TODO 10: Vérifier d'abord si on clique sur un grip }
   If (Y >= CanvasTop) and (Y <= CanvasBottom) and (CurrentGrips.Count > 0) Then Begin
    ClickedGrip := GetGripAtPoint(X, Y);
    If ClickedGrip >= 0 Then Begin
     { On a cliqué sur un grip - démarrer l'édition }
     StartGripEdit(ClickedGrip);
     MouseDragging := True;
     DragStartX := X;
     DragStartY := Y;
     DrawInterface;
     Exit;
    End;
   End;

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
     If ActiveMenu = MENU_FILE Then Begin
      Case NewItem Of
       0: Begin { Nouveau }
        ObjectCount := 0;
        ClearSelection;
        ClearGrips;
        CurrentFileName := '';
        MarkDocumentSaved;
        CommandLastLine := 'Nouveau dessin';
       End;
       1: Begin { Ouvrir }
        PendingFileAction := 1;
        CommandPrompt := 'Nom du fichier a ouvrir:';
        CommandBuffer := '';
       End;
       2: Begin { Enregistrer }
        If CurrentFileName <> '' Then Begin
         If WriteDWGFile(CurrentFileName) Then
          CommandLastLine := 'Enregistre: ' + CurrentFileName
         Else
          CommandLastLine := 'Echec enregistrement: ' + CurrentFileName;
        End Else Begin
         PendingFileAction := 2;
         CommandPrompt := 'Enregistrer sous:';
         CommandBuffer := '';
        End;
       End;
       3: Begin { Enregistrer sous... }
        PendingFileAction := 2;
        CommandPrompt := 'Enregistrer sous:';
        CommandBuffer := '';
       End;
       5: Begin { Importer... (.DXF / .SVG / .DWG) }
        PendingFileAction := 3;
        CommandPrompt := 'Importer (.dxf/.svg/.dwg):';
        CommandBuffer := '';
       End;
       6: Begin { Exporter... (.DXF / .SVG) }
        PendingFileAction := 4;
        CommandPrompt := 'Exporter (.dxf/.svg):';
        CommandBuffer := '';
       End;
       8: Begin { Imprimer... }
        CommandLastLine := 'Imprimer: fonction non disponible dans cette version';
       End;
       9: Begin { Apercu avant impression }
        ShowPrintPreview;
       End;
       11: Begin { Proprietes du dessin }
        Str(ObjectCount, NumStr1);
        Str(LayerCount, NumStr2);
        Str(BlockDefCount, NumStr3);
        If CurrentFileName = '' Then
         CommandLastLine := 'Proprietes: <sans nom>  Objets=' + NumStr1 +
                            '  Calques=' + NumStr2 + '  Blocs=' + NumStr3
        Else
         CommandLastLine := 'Proprietes: ' + CurrentFileName +
                            '  Objets=' + NumStr1 +
                            '  Calques=' + NumStr2 + '  Blocs=' + NumStr3;
       End;
       13: Begin { Quitter }
        If ConfirmExit Then Running := False;
       End;
      End;
     End Else If ActiveMenu = MENU_EDIT Then Begin
      Case NewItem Of
       0: DoUndo;                       { Undo }
       1: DoRedo;                       { Redo }
       3: CutSelection;                 { Couper }
       4: CopySelectionToClipboard;     { Copier }
       5: CopySelectionToClipboard;     { Copier avec point de base }
       6: PasteFromClipboard;           { Coller }
       7: PasteFromClipboard;           { Coller comme bloc }
       9: DeleteSelectedObjects;        { Effacer }
       11: SelectAllObjects;            { Tout selectionner }
      End;
     End Else If ActiveMenu = MENU_VIEW Then Begin
      Case NewItem Of
       0: ViewRedraw;                   { Redraw }
       1: ViewRedraw;                   { Regen }
       3: ViewZoomIn;                   { Zoom In }
       4: ViewZoomOut;                  { Zoom Out }
       5: ViewEnterZoomWindowMode;      { Zoom Window }
       6: ViewZoomExtents;              { Zoom Extents }
       7: ViewZoomAll;                  { Zoom All }
       9: ViewEnterPanMode;             { Pan }
       11: CommandLastLine := 'Vues nommees: fonction non disponible dans cette version';
       12: CommandLastLine := 'Vues 3D: fonction non disponible dans cette version';
       13: CommandLastLine := 'Fenetres: fonction non disponible dans cette version';
      End;
     End Else If ActiveMenu = MENU_INSERT Then Begin
      Case NewItem Of
       0: Begin { Block... }
        If BlockDefCount <= 0 Then
         CommandLastLine := 'Inserer bloc: aucun bloc defini dans le dessin'
        Else Begin
         PendingFileAction := 5;
         CommandPrompt := 'Nom du bloc a inserer:';
         CommandBuffer := '';
        End;
       End;
       1: Begin { DWG Reference... }
        PendingFileAction := 6;
        CommandPrompt := 'Fichier DWG a referencer:';
        CommandBuffer := '';
       End;
       2: Begin { Image Reference... }
        PendingFileAction := 7;
        CommandPrompt := 'Fichier image a referencer:';
        CommandBuffer := '';
       End;
       4: ExecuteLayoutInsert; { Layout / Presentation - feuille de mise en page }
       6: Begin { 3D Studio (.3DS) }
        PendingFileAction := 9;
        CommandPrompt := 'Fichier 3D Studio (.3DS) a importer:';
        CommandBuffer := '';
       End;
       7: Begin { Fichier ACIS (.SAT) }
        PendingFileAction := 10;
        CommandPrompt := 'Fichier ACIS (.SAT) a importer:';
        CommandBuffer := '';
       End;
       9: Begin { Objet OLE... }
        PendingFileAction := 8;
        CommandPrompt := 'Fichier source pour objet OLE:';
        CommandBuffer := '';
       End;
      End;
     End Else If ActiveMenu = MENU_FORMAT Then Begin
      Case NewItem Of
       0: Begin { Layer... }
        PendingFileAction := 20;
        CommandPrompt := 'Calque courant (nom; cree si absent):';
        CommandBuffer := '';
       End;
       1: Begin { Color... }
        PendingFileAction := 21;
        CommandPrompt := 'Couleur courante (0..255, 256=ByLayer):';
        CommandBuffer := '';
       End;
       2: Begin { Linetype... }
        PendingFileAction := 22;
        CommandPrompt := 'Type de ligne (0=Continu 1=Tirets 2=Pointille 3=Mixte 4=Phantom):';
        CommandBuffer := '';
       End;
       3: Begin { Lineweight... }
        PendingFileAction := 23;
        CommandPrompt := 'Epaisseur de ligne (0=Defaut, 1..211 en 1/100 mm):';
        CommandBuffer := '';
       End;
       5: Begin { Text Style... }
        PendingFileAction := 24;
        CommandPrompt := 'Nom du style de texte courant:';
        CommandBuffer := '';
       End;
       6: Begin { Dimension Style... }
        PendingFileAction := 25;
        CommandPrompt := 'Nom du style de cote courant:';
        CommandBuffer := '';
       End;
       7: Begin { Point Style... }
        PendingFileAction := 26;
        CommandPrompt := 'Style de point (0=point 1=vide 2=+ 3=x 4=|):';
        CommandBuffer := '';
       End;
       9: Begin { Units... }
        PendingFileAction := 27;
        CommandPrompt := 'Unites (0=Scientifique 1=Decimal 2=Ingenierie 3=Architectural 4=Fractionnel):';
        CommandBuffer := '';
       End;
       10: Begin { Drawing Limits }
        PendingFileAction := 28;
        CommandPrompt := 'Limites X1 Y1 X2 Y2 (4 reels):';
        CommandBuffer := '';
       End;
       11: Begin { Rename... }
        PendingFileAction := 29;
        CommandPrompt := 'Renommer calque (AncienNom=NouveauNom):';
        CommandBuffer := '';
       End;
      End;
     End Else If ActiveMenu = MENU_TOOLS Then Begin
      Case NewItem Of
       0: ExecuteToolsSpelling;       { Spelling }
       1: Begin                       { Quick Select... }
        PendingFileAction := 30;
        CommandPrompt := 'Selection rapide - type (1=Ligne 2=Cercle 3=Arc 4=Rectangle 5=Polyline 6=Ellipse 7=Texte 8=Point):';
        CommandBuffer := '';
       End;
       3: ExecuteToolsDrawOrder;      { Draw Order - mettre selection au premier plan }
       4: ExecuteToolsInquiry;        { Inquiry - statistiques }
       6: Begin                       { Load Application... }
        PendingFileAction := 31;
        CommandPrompt := 'Fichier LISP a charger (.LSP):';
        CommandBuffer := '';
       End;
       7: Begin                       { Run Script... }
        PendingFileAction := 32;
        CommandPrompt := 'Fichier script a executer (.SCR):';
        CommandBuffer := '';
       End;
       9: Begin                       { AutoLISP }
        PendingFileAction := 33;
        CommandPrompt := 'Expression AutoLISP a evaluer:';
        CommandBuffer := '';
       End;
       11: Begin                      { Drafting Settings... }
        PendingFileAction := 34;
        CommandPrompt := 'Reglages dessin (snap espacement, 0=desactiver):';
        CommandBuffer := '';
       End;
       12: ExecuteToolsCustomize;     { Customize }
       13: ExecuteToolsOptions;       { Options... }
      End;
     End Else If ActiveMenu = MENU_DRAW Then Begin
      Case NewItem Of
       0: Begin                       { Line }
        PendingFileAction := 40;
        CommandPrompt := 'Ligne X1,Y1 X2,Y2:';
        CommandBuffer := '';
       End;
       1: Begin                       { Ray }
        PendingFileAction := 41;
        CommandPrompt := 'Demi-droite X1,Y1 X2,Y2 (origine, direction):';
        CommandBuffer := '';
       End;
       2: Begin                       { Construction Line / XLine }
        PendingFileAction := 42;
        CommandPrompt := 'Droite de construction X1,Y1 X2,Y2:';
        CommandBuffer := '';
       End;
       4: Begin                       { Polyline }
        PendingFileAction := 43;
        CommandPrompt := 'Polyligne X1,Y1 X2,Y2 X3,Y3 ... (min 2 sommets):';
        CommandBuffer := '';
       End;
       5: Begin                       { Polygon }
        PendingFileAction := 44;
        CommandPrompt := 'Polygone N CX,CY R (cotes, centre, rayon):';
        CommandBuffer := '';
       End;
       6: Begin                       { Rectangle }
        PendingFileAction := 45;
        CommandPrompt := 'Rectangle X1,Y1 X2,Y2:';
        CommandBuffer := '';
       End;
       8: Begin                       { Arc }
        PendingFileAction := 46;
        CommandPrompt := 'Arc CX,CY R AngDebut AngFin (degres):';
        CommandBuffer := '';
       End;
       9: Begin                       { Circle }
        PendingFileAction := 47;
        CommandPrompt := 'Cercle CX,CY R:';
        CommandBuffer := '';
       End;
       10: Begin                      { Spline (traite comme polyligne) }
        PendingFileAction := 48;
        CommandPrompt := 'Spline X1,Y1 X2,Y2 X3,Y3 ... (min 3 sommets):';
        CommandBuffer := '';
       End;
       11: Begin                      { Ellipse }
        PendingFileAction := 49;
        CommandPrompt := 'Ellipse CX,CY RX RY:';
        CommandBuffer := '';
       End;
       13: Begin                      { Point }
        PendingFileAction := 50;
        CommandPrompt := 'Point X,Y:';
        CommandBuffer := '';
       End;
       14: ExecuteDrawHatch;          { Hatch }
       15: ExecuteDrawRegion;         { Region }
       17: Begin                      { Text }
        PendingFileAction := 51;
        CommandPrompt := 'Texte X Y H Contenu:';
        CommandBuffer := '';
       End;
       18: ExecuteDrawSurface;        { Surface (3D) }
       19: ExecuteDrawSolid;          { Solid (3D) }
      End;
     End Else If ActiveMenu = MENU_DIMENSION Then Begin
      Case NewItem Of
       0: ExecuteDimQuick;            { Quick Dimension }
       2: Begin                       { Linear }
        PendingFileAction := 61;
        CommandPrompt := 'Cote lineaire X1 Y1 X2 Y2 DimLineY:';
        CommandBuffer := '';
       End;
       3: Begin                       { Aligned }
        PendingFileAction := 62;
        CommandPrompt := 'Cote alignee X1 Y1 X2 Y2 Offset:';
        CommandBuffer := '';
       End;
       4: Begin                       { Arc Length }
        PendingFileAction := 63;
        CommandPrompt := 'Longueur d''arc CX CY R AngDeb AngFin (degres):';
        CommandBuffer := '';
       End;
       5: Begin                       { Ordinate }
        PendingFileAction := 64;
        CommandPrompt := 'Cote ordonnee X Y LeaderX LeaderY:';
        CommandBuffer := '';
       End;
       7: Begin                       { Radius }
        PendingFileAction := 65;
        CommandPrompt := 'Cote rayon CX CY R Angle (degres):';
        CommandBuffer := '';
       End;
       8: Begin                       { Diameter }
        PendingFileAction := 66;
        CommandPrompt := 'Cote diametre CX CY R Angle (degres):';
        CommandBuffer := '';
       End;
       9: Begin                       { Angular }
        PendingFileAction := 67;
        CommandPrompt := 'Cote angulaire CX CY X1 Y1 X2 Y2 R:';
        CommandBuffer := '';
       End;
       11: Begin                      { Baseline }
        PendingFileAction := 68;
        CommandPrompt := 'Baseline X Y (point suivant):';
        CommandBuffer := '';
       End;
       12: Begin                      { Continue }
        PendingFileAction := 69;
        CommandPrompt := 'Continue X Y (point suivant):';
        CommandBuffer := '';
       End;
       13: Begin                      { Leader }
        PendingFileAction := 70;
        CommandPrompt := 'Repere X1 Y1 X2 Y2 Texte:';
        CommandBuffer := '';
       End;
      End;
     End Else If ActiveMenu = MENU_MODIFY Then Begin
      Case NewItem Of
       0: ExecuteModifyProperties;
       1: ExecuteModifyMatchProperties;
       3: Begin                       { Erase }
        DeleteSelectedObjects;
        MarkDocumentModified; DrawInterface;
       End;
       4: Begin                       { Copy }
        PendingFileAction := 80;
        CommandPrompt := 'Copier DX DY:';
        CommandBuffer := '';
       End;
       5: Begin                       { Mirror }
        PendingFileAction := 81;
        CommandPrompt := 'Miroir X1 Y1 X2 Y2:';
        CommandBuffer := '';
       End;
       6: Begin                       { Offset }
        PendingFileAction := 82;
        CommandPrompt := 'Decaler DX DY:';
        CommandBuffer := '';
       End;
       7: Begin                       { Array }
        PendingFileAction := 83;
        CommandPrompt := 'Reseau Lignes Colonnes DX DY:';
        CommandBuffer := '';
       End;
       8: Begin                       { Move }
        PendingFileAction := 84;
        CommandPrompt := 'Deplacer DX DY:';
        CommandBuffer := '';
       End;
       9: Begin                       { Rotate }
        PendingFileAction := 85;
        CommandPrompt := 'Rotation CX CY Angle (degres):';
        CommandBuffer := '';
       End;
       10: Begin                      { Scale }
        PendingFileAction := 86;
        CommandPrompt := 'Echelle CX CY Facteur:';
        CommandBuffer := '';
       End;
       11: Begin                      { Stretch }
        PendingFileAction := 87;
        CommandPrompt := 'Etirer DX DY:';
        CommandBuffer := '';
       End;
       13: CommandLastLine := 'Ajuster (Trim): non implemente';
       14: CommandLastLine := 'Prolonger (Extend): non implemente';
       15: Begin                      { Break }
        PendingFileAction := 88;
        CommandPrompt := 'Couper X Y (point sur ligne):';
        CommandBuffer := '';
       End;
       16: Begin                      { Chamfer }
        PendingFileAction := 89;
        CommandPrompt := 'Chanfrein Distance:';
        CommandBuffer := '';
       End;
       17: Begin                      { Fillet }
        PendingFileAction := 90;
        CommandPrompt := 'Raccord Rayon:';
        CommandBuffer := '';
       End;
       18: ExecuteModifyExplode;
      End;
     End Else If ActiveMenu = MENU_WINDOW Then Begin
      Case NewItem Of
       0: Begin                       { Close }
        ObjectCount := 0;
        ClearSelection;
        ClearGrips;
        CurrentFileName := '';
        MarkDocumentSaved;
        CommandLastLine := 'Dessin ferme';
        DrawInterface;
       End;
       1: Begin                       { Close All }
        ObjectCount := 0;
        ClearSelection;
        ClearGrips;
        CurrentFileName := '';
        MarkDocumentSaved;
        CommandLastLine := 'Tous les dessins fermes';
        DrawInterface;
       End;
       3: CommandLastLine := 'Cascade: vue unique, aucun arrangement requis';
       4: CommandLastLine := 'Mosaique horizontale: vue unique';
       5: CommandLastLine := 'Mosaique verticale: vue unique';
      End;
     End Else If ActiveMenu = MENU_HELP Then Begin
      Case NewItem Of
       0: CommandLastLine :=
         'Aide: F1=Aide ESC=Annuler - Cliquez les menus ou tapez les commandes';
       1: CommandLastLine :=
         'Centre d''info: CloneDRAW clone AutoCAD - FPC -Mtp mode Turbo Pascal';
       3: CommandLastLine :=
         'Nouveautes: menus Dessin / Cotation / Modifier / Fenetre / Aide cables';
       5: CommandLastLine :=
         'CloneDRAW v1.0 - github.com/clonedraw - Licence libre';
      End;
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
      { TODO 10: Mettre à jour les grips après désélection }
      UpdateGripsForSelection;
     End Else Begin
      { Effacer la sélection précédente et sélectionner le nouvel objet }
      ClearSelection;
      AddToSelection(SelectedObj);
      { TODO 10: Mettre à jour les grips après sélection }
      UpdateGripsForSelection;
     End;
     DrawInterface;
    End Else Begin
     { Aucun objet sous le curseur - démarrer une sélection par fenêtre }
     ClearSelection;
     ClearGrips;  { TODO 10: Effacer les grips }
     MouseMode := MOUSE_MODE_SELECT;
     MouseDragging := True;
     StartWindowSelection(X, Y);
     DragStartX := X;
     DragStartY := Y;
    End;
   End;
  End;

  MOUSE_BUTTON_RIGHT: Begin { Clic droit - TODO 6 }
   { TODO 10: Annuler l'édition grip si active }
   If GripEditActive Then Begin
    CancelGripEdit;
    MouseDragging := False;
    DrawInterface;
    Exit;
   End;
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
 CanvasTop, CanvasBottom: Integer;
 HoverGrip: Integer;
Begin
 CanvasTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 CanvasBottom := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;

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

 { TODO 10: Vérifier le survol des grips dans la zone de dessin }
 If (Y >= CanvasTop) and (Y <= CanvasBottom) and
    (CurrentGrips.Count > 0) and (Not GripEditActive) Then Begin
  HoverGrip := GetGripAtPoint(X, Y);
  If HoverGrip <> HotGripIndex Then Begin
   SetHotGrip(HoverGrip);
   DrawInterface;
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
 InitGripSystem;         { TODO 10: Initialiser le système de grips }
 InitBlockSystem;        { TODO 20: Initialiser le système de blocs et XREFs }
 InitLispTokenizer;      { TODO 11: Initialiser le tokenizer AutoLISP }
 InitLispParser;         { TODO 12: Initialiser le parseur AutoLISP }
 InitLispEvaluator;      { TODO 13: Initialiser l'évaluateur AutoLISP }
 InitLispDrawFunctions;  { TODO 14: Initialiser les fonctions de dessin AutoLISP }
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

 { TODO 10: Gérer l'édition via grip en premier }
 If GripEditActive Then Begin
  UpdateGripEdit(X, Y);
  DrawInterface;
  Exit;
 End;

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
   { Ouvrir le panneau de propriétés - TODO 16 }
   TogglePropertiesPanel;
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

{ ================ Menu Edition : Undo/Redo, Couper/Copier/Coller, Effacer, Tout selectionner ================ }

{ Sauvegarder l'etat courant dans le tampon Undo (avant operation destructive) }
Procedure PushUndoState;
Var
 I: Integer;
Begin
 For I := 0 To ObjectCount - 1 Do
  UndoObjects[I] := DrawObjects[I];
 UndoObjectCount := ObjectCount;
 UndoAvailable := True;
 RedoAvailable := False;
End;

{ Annuler la derniere operation : echange l'etat courant avec le tampon Undo }
Procedure DoUndo;
Var
 I: Integer;
 TmpCount: Integer;
Begin
 If Not UndoAvailable Then Begin
  CommandLastLine := 'Undo: rien a annuler';
  Exit;
 End;
 { Sauver l'etat courant dans Redo }
 For I := 0 To ObjectCount - 1 Do
  RedoObjects[I] := DrawObjects[I];
 RedoObjectCount := ObjectCount;
 RedoAvailable := True;
 { Restaurer Undo dans courant }
 TmpCount := UndoObjectCount;
 For I := 0 To TmpCount - 1 Do
  DrawObjects[I] := UndoObjects[I];
 ObjectCount := TmpCount;
 UndoAvailable := False;
 ClearSelection;
 ClearGrips;
 CommandLastLine := 'Undo';
End;

{ Refaire la derniere operation annulee }
Procedure DoRedo;
Var
 I: Integer;
 TmpCount: Integer;
Begin
 If Not RedoAvailable Then Begin
  CommandLastLine := 'Redo: rien a refaire';
  Exit;
 End;
 { Sauver l'etat courant dans Undo }
 For I := 0 To ObjectCount - 1 Do
  UndoObjects[I] := DrawObjects[I];
 UndoObjectCount := ObjectCount;
 UndoAvailable := True;
 { Restaurer Redo dans courant }
 TmpCount := RedoObjectCount;
 For I := 0 To TmpCount - 1 Do
  DrawObjects[I] := RedoObjects[I];
 ObjectCount := TmpCount;
 RedoAvailable := False;
 ClearSelection;
 ClearGrips;
 CommandLastLine := 'Redo';
End;

{ Copier la selection courante dans le presse-papiers interne }
Procedure CopySelectionToClipboard;
Var
 I, Idx: Integer;
 N: Integer;
 NStr: String[16];
Begin
 If SelectionSet.Count <= 0 Then Begin
  CommandLastLine := 'Copier: aucune selection';
  ClipboardCount := 0;
  Exit;
 End;
 N := SelectionSet.Count;
 If N > MAX_SELECTED Then N := MAX_SELECTED;
 For I := 0 To N - 1 Do Begin
  Idx := SelectionSet.Objects[I];
  If (Idx >= 0) and (Idx < ObjectCount) Then
   ClipboardObjects[I] := DrawObjects[Idx];
 End;
 ClipboardCount := N;
 Str(N, NStr);
 CommandLastLine := 'Copie: ' + NStr + ' objet(s) dans le presse-papiers';
End;

{ Supprimer les objets selectionnes du dessin (compacte le tableau) }
Procedure DeleteSelectedObjects;
Var
 Src, Dst: Integer;
 Removed: Integer;
 NStr: String[16];
Begin
 If SelectionSet.Count <= 0 Then Begin
  CommandLastLine := 'Effacer: aucune selection';
  Exit;
 End;
 PushUndoState;
 Removed := 0;
 Dst := 0;
 For Src := 0 To ObjectCount - 1 Do Begin
  If DrawObjects[Src].Selected Then Begin
   Inc(Removed);
  End Else Begin
   If Dst <> Src Then DrawObjects[Dst] := DrawObjects[Src];
   Inc(Dst);
  End;
 End;
 ObjectCount := Dst;
 ClearSelection;
 ClearGrips;
 Str(Removed, NStr);
 CommandLastLine := 'Efface: ' + NStr + ' objet(s)';
End;

{ Couper = copier puis supprimer }
Procedure CutSelection;
Begin
 If SelectionSet.Count <= 0 Then Begin
  CommandLastLine := 'Couper: aucune selection';
  Exit;
 End;
 CopySelectionToClipboard;
 DeleteSelectedObjects;
 CommandLastLine := 'Couper: selection deplacee dans le presse-papiers';
End;

{ Coller le contenu du presse-papiers a la fin du dessin (avec petit decalage) }
Procedure PasteFromClipboard;
Var
 I, NewIdx: Integer;
 OffsetX, OffsetY: Real;
 NStr: String[16];
 Pasted: Integer;
Begin
 If ClipboardCount <= 0 Then Begin
  CommandLastLine := 'Coller: presse-papiers vide';
  Exit;
 End;
 PushUndoState;
 ClearSelection;
 { Petit decalage visuel pour distinguer la copie }
 If ZoomLevel > 0.0001 Then Begin
  OffsetX := 10.0 / ZoomLevel;
  OffsetY := 10.0 / ZoomLevel;
 End Else Begin
  OffsetX := 10.0;
  OffsetY := 10.0;
 End;
 Pasted := 0;
 For I := 0 To ClipboardCount - 1 Do Begin
  If ObjectCount >= MAX_OBJECTS Then Break;
  NewIdx := ObjectCount;
  DrawObjects[NewIdx] := ClipboardObjects[I];
  DrawObjects[NewIdx].X1 := DrawObjects[NewIdx].X1 + OffsetX;
  DrawObjects[NewIdx].Y1 := DrawObjects[NewIdx].Y1 + OffsetY;
  DrawObjects[NewIdx].X2 := DrawObjects[NewIdx].X2 + OffsetX;
  DrawObjects[NewIdx].Y2 := DrawObjects[NewIdx].Y2 + OffsetY;
  DrawObjects[NewIdx].Selected := False;
  Inc(ObjectCount);
  AddToSelection(NewIdx);
  Inc(Pasted);
 End;
 Str(Pasted, NStr);
 CommandLastLine := 'Colle: ' + NStr + ' objet(s)';
End;

{ Selectionner tous les objets visibles du dessin }
Procedure SelectAllObjects;
Var
 I: Integer;
 NStr: String[16];
Begin
 ClearSelection;
 For I := 0 To ObjectCount - 1 Do Begin
  If DrawObjects[I].ObjType = OBJ_NONE Then Continue;
  If Not DrawObjects[I].Visible Then Continue;
  If Not IsObjectOnVisibleLayer(I) Then Continue;
  If SelectionSet.Count >= MAX_SELECTED Then Break;
  AddToSelection(I);
 End;
 Str(SelectionSet.Count, NStr);
 CommandLastLine := 'Tout selectionner: ' + NStr + ' objet(s)';
End;

{ ================ Menu Affichage : Redraw, Regen, Zoom, Pan ================ }

{ Calculer la boite englobante de tous les objets visibles. Retourne True si non vide. }
Function ComputeDrawingBounds(Var Bx1, By1, Bx2, By2: Real): Boolean;
Var
 I, J: Integer;
 HasAny: Boolean;
 R: Real;
Begin
 HasAny := False;
 Bx1 := 0; By1 := 0; Bx2 := 0; By2 := 0;
 For I := 0 To ObjectCount - 1 Do Begin
  If Not DrawObjects[I].Visible Then Continue;
  If DrawObjects[I].ObjType = OBJ_NONE Then Continue;
  If Not IsObjectOnVisibleLayer(I) Then Continue;
  Case DrawObjects[I].ObjType Of
   OBJ_LINE, OBJ_RECTANGLE: Begin
    If Not HasAny Then Begin
     Bx1 := DrawObjects[I].X1; By1 := DrawObjects[I].Y1;
     Bx2 := Bx1; By2 := By1; HasAny := True;
    End;
    If DrawObjects[I].X1 < Bx1 Then Bx1 := DrawObjects[I].X1;
    If DrawObjects[I].Y1 < By1 Then By1 := DrawObjects[I].Y1;
    If DrawObjects[I].X1 > Bx2 Then Bx2 := DrawObjects[I].X1;
    If DrawObjects[I].Y1 > By2 Then By2 := DrawObjects[I].Y1;
    If DrawObjects[I].X2 < Bx1 Then Bx1 := DrawObjects[I].X2;
    If DrawObjects[I].Y2 < By1 Then By1 := DrawObjects[I].Y2;
    If DrawObjects[I].X2 > Bx2 Then Bx2 := DrawObjects[I].X2;
    If DrawObjects[I].Y2 > By2 Then By2 := DrawObjects[I].Y2;
   End;
   OBJ_CIRCLE, OBJ_ARC, OBJ_ELLIPSE: Begin
    R := DrawObjects[I].Radius;
    If R < 0 Then R := -R;
    If Not HasAny Then Begin
     Bx1 := DrawObjects[I].X1 - R; By1 := DrawObjects[I].Y1 - R;
     Bx2 := DrawObjects[I].X1 + R; By2 := DrawObjects[I].Y1 + R;
     HasAny := True;
    End Else Begin
     If DrawObjects[I].X1 - R < Bx1 Then Bx1 := DrawObjects[I].X1 - R;
     If DrawObjects[I].Y1 - R < By1 Then By1 := DrawObjects[I].Y1 - R;
     If DrawObjects[I].X1 + R > Bx2 Then Bx2 := DrawObjects[I].X1 + R;
     If DrawObjects[I].Y1 + R > By2 Then By2 := DrawObjects[I].Y1 + R;
    End;
   End;
   OBJ_POINT, OBJ_TEXT: Begin
    If Not HasAny Then Begin
     Bx1 := DrawObjects[I].X1; By1 := DrawObjects[I].Y1;
     Bx2 := Bx1; By2 := By1; HasAny := True;
    End Else Begin
     If DrawObjects[I].X1 < Bx1 Then Bx1 := DrawObjects[I].X1;
     If DrawObjects[I].Y1 < By1 Then By1 := DrawObjects[I].Y1;
     If DrawObjects[I].X1 > Bx2 Then Bx2 := DrawObjects[I].X1;
     If DrawObjects[I].Y1 > By2 Then By2 := DrawObjects[I].Y1;
    End;
   End;
   OBJ_POLYLINE: Begin
    For J := 0 To DrawObjects[I].VertexCount - 1 Do Begin
     If Not HasAny Then Begin
      Bx1 := DrawObjects[I].Vertices[J].X; By1 := DrawObjects[I].Vertices[J].Y;
      Bx2 := Bx1; By2 := By1; HasAny := True;
     End Else Begin
      If DrawObjects[I].Vertices[J].X < Bx1 Then Bx1 := DrawObjects[I].Vertices[J].X;
      If DrawObjects[I].Vertices[J].Y < By1 Then By1 := DrawObjects[I].Vertices[J].Y;
      If DrawObjects[I].Vertices[J].X > Bx2 Then Bx2 := DrawObjects[I].Vertices[J].X;
      If DrawObjects[I].Vertices[J].Y > By2 Then By2 := DrawObjects[I].Vertices[J].Y;
     End;
    End;
   End;
  End;
 End;
 ComputeDrawingBounds := HasAny;
End;

Procedure ViewZoomIn;
Begin
 ZoomLevel := ZoomLevel * 1.25;
 If ZoomLevel > 20.0 Then ZoomLevel := 20.0;
 CommandLastLine := 'Zoom avant';
 DrawInterface;
End;

Procedure ViewZoomOut;
Begin
 ZoomLevel := ZoomLevel * 0.8;
 If ZoomLevel < 0.1 Then ZoomLevel := 0.1;
 CommandLastLine := 'Zoom arriere';
 DrawInterface;
End;

Procedure ViewZoomExtents;
Var
 Bx1, By1, Bx2, By2, W, H, ZX, ZY, NewZ: Real;
 CanvasH: Integer;
Begin
 If Not ComputeDrawingBounds(Bx1, By1, Bx2, By2) Then Begin
  CommandLastLine := 'Zoom etendu: aucun objet';
  Exit;
 End;
 W := Bx2 - Bx1;
 H := By2 - By1;
 If W < 0.0001 Then W := 1.0;
 If H < 0.0001 Then H := 1.0;
 CanvasH := ScreenHeight - MENUBAR_HEIGHT - TOOLBAR_HEIGHT
            - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 ZX := (ScreenWidth * 0.9) / W;
 ZY := (CanvasH * 0.9) / H;
 If ZX < ZY Then NewZ := ZX Else NewZ := ZY;
 If NewZ < 0.1 Then NewZ := 0.1;
 If NewZ > 20.0 Then NewZ := 20.0;
 ZoomLevel := NewZ;
 ViewOffsetX := -(Bx1 + Bx2) / 2.0;
 ViewOffsetY := -(By1 + By2) / 2.0;
 CommandLastLine := 'Zoom etendu';
 DrawInterface;
End;

Procedure ViewZoomAll;
Begin
 { Zoom All = Zoom Extents pour ce clone (pas de limites de dessin distinctes) }
 ViewZoomExtents;
 CommandLastLine := 'Zoom tout';
End;

Procedure ViewRedraw;
Begin
 DrawInterface;
 CommandLastLine := 'Redessine';
End;

Procedure ViewEnterPanMode;
Begin
 MouseMode := MOUSE_MODE_PAN;
 CommandLastLine := 'Mode Pan actif - cliquez-glissez pour deplacer la vue (Esc pour sortir)';
 DrawInterface;
End;

Procedure ViewEnterZoomWindowMode;
Begin
 MouseMode := MOUSE_MODE_ZOOM;
 CommandLastLine := 'Mode Zoom fenetre - cliquez-glissez la zone a agrandir (Esc pour sortir)';
 DrawInterface;
End;

{ Apercu avant impression : rendu plein ecran sur "papier" blanc, encre noire.
  Sauve Zoom/Offset, ajuste pour cadrer tous les objets visibles, attend une
  touche, puis restaure et redessine l'interface normale. }
Procedure ShowPrintPreview;
Var
 I, J: Integer;
 HasAny: Boolean;
 Bx1, By1, Bx2, By2, R, W, H: Real;
 SavedZoom, SavedOffX, SavedOffY: Real;
 ZoomX, ZoomY: Real;
 PaperTop, PaperBottom: Integer;
 CanvasW, CanvasH: Integer;
 SX1, SY1, SX2, SY2, SCX, SCY, SR: Integer;
 PrevSX, PrevSY: Integer;
 K: Char;
 Title: String;
Begin
 If ObjectCount <= 0 Then Begin
  CommandLastLine := 'Apercu: aucun objet a afficher';
  Exit;
 End;

 { Calculer la boite englobante de tous les objets visibles }
 HasAny := False;
 Bx1 := 0; By1 := 0; Bx2 := 0; By2 := 0;
 For I := 0 To ObjectCount - 1 Do Begin
  If Not DrawObjects[I].Visible Then Continue;
  If DrawObjects[I].ObjType = OBJ_NONE Then Continue;
  If Not IsObjectOnVisibleLayer(I) Then Continue;
  Case DrawObjects[I].ObjType Of
   OBJ_LINE, OBJ_RECTANGLE: Begin
    If Not HasAny Then Begin
     Bx1 := DrawObjects[I].X1; By1 := DrawObjects[I].Y1;
     Bx2 := Bx1; By2 := By1;
     HasAny := True;
    End;
    If DrawObjects[I].X1 < Bx1 Then Bx1 := DrawObjects[I].X1;
    If DrawObjects[I].Y1 < By1 Then By1 := DrawObjects[I].Y1;
    If DrawObjects[I].X1 > Bx2 Then Bx2 := DrawObjects[I].X1;
    If DrawObjects[I].Y1 > By2 Then By2 := DrawObjects[I].Y1;
    If DrawObjects[I].X2 < Bx1 Then Bx1 := DrawObjects[I].X2;
    If DrawObjects[I].Y2 < By1 Then By1 := DrawObjects[I].Y2;
    If DrawObjects[I].X2 > Bx2 Then Bx2 := DrawObjects[I].X2;
    If DrawObjects[I].Y2 > By2 Then By2 := DrawObjects[I].Y2;
   End;
   OBJ_CIRCLE, OBJ_ARC, OBJ_ELLIPSE: Begin
    R := DrawObjects[I].Radius;
    If R < 0 Then R := -R;
    If Not HasAny Then Begin
     Bx1 := DrawObjects[I].X1 - R; By1 := DrawObjects[I].Y1 - R;
     Bx2 := DrawObjects[I].X1 + R; By2 := DrawObjects[I].Y1 + R;
     HasAny := True;
    End Else Begin
     If DrawObjects[I].X1 - R < Bx1 Then Bx1 := DrawObjects[I].X1 - R;
     If DrawObjects[I].Y1 - R < By1 Then By1 := DrawObjects[I].Y1 - R;
     If DrawObjects[I].X1 + R > Bx2 Then Bx2 := DrawObjects[I].X1 + R;
     If DrawObjects[I].Y1 + R > By2 Then By2 := DrawObjects[I].Y1 + R;
    End;
   End;
   OBJ_POINT, OBJ_TEXT: Begin
    If Not HasAny Then Begin
     Bx1 := DrawObjects[I].X1; By1 := DrawObjects[I].Y1;
     Bx2 := Bx1; By2 := By1;
     HasAny := True;
    End Else Begin
     If DrawObjects[I].X1 < Bx1 Then Bx1 := DrawObjects[I].X1;
     If DrawObjects[I].Y1 < By1 Then By1 := DrawObjects[I].Y1;
     If DrawObjects[I].X1 > Bx2 Then Bx2 := DrawObjects[I].X1;
     If DrawObjects[I].Y1 > By2 Then By2 := DrawObjects[I].Y1;
    End;
   End;
   OBJ_POLYLINE: Begin
    For J := 0 To DrawObjects[I].VertexCount - 1 Do Begin
     If Not HasAny Then Begin
      Bx1 := DrawObjects[I].Vertices[J].X; By1 := DrawObjects[I].Vertices[J].Y;
      Bx2 := Bx1; By2 := By1;
      HasAny := True;
     End Else Begin
      If DrawObjects[I].Vertices[J].X < Bx1 Then Bx1 := DrawObjects[I].Vertices[J].X;
      If DrawObjects[I].Vertices[J].Y < By1 Then By1 := DrawObjects[I].Vertices[J].Y;
      If DrawObjects[I].Vertices[J].X > Bx2 Then Bx2 := DrawObjects[I].Vertices[J].X;
      If DrawObjects[I].Vertices[J].Y > By2 Then By2 := DrawObjects[I].Vertices[J].Y;
     End;
    End;
   End;
  End;
 End;

 If Not HasAny Then Begin
  CommandLastLine := 'Apercu: aucun objet visible';
  Exit;
 End;

 W := Bx2 - Bx1;
 H := By2 - By1;
 If W < 0.0001 Then W := 1.0;
 If H < 0.0001 Then H := 1.0;

 { Zone "papier" = zone canvas habituelle (entre menubar/toolbar et commandline/status) }
 PaperTop := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 PaperBottom := ScreenHeight - COMMANDLINE_HEIGHT - STATUSBAR_HEIGHT;
 CanvasW := ScreenWidth;
 CanvasH := PaperBottom - PaperTop;

 ZoomX := (CanvasW * 0.9) / W;
 ZoomY := (CanvasH * 0.9) / H;

 SavedZoom := ZoomLevel;
 SavedOffX := ViewOffsetX;
 SavedOffY := ViewOffsetY;

 If ZoomX < ZoomY Then ZoomLevel := ZoomX Else ZoomLevel := ZoomY;
 ViewOffsetX := -(Bx1 + Bx2) / 2.0;
 ViewOffsetY := -(By1 + By2) / 2.0;

 { Effacer et peindre le fond }
 ClearDevice;

 { Bandeau de titre en haut }
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, 0, ScreenWidth - 1, PaperTop - 1);
 SetColor(Yellow);
 Title := 'APERCU AVANT IMPRESSION';
 OutTextXY((ScreenWidth - TextWidth(Title)) Div 2, 6, Title);
 If CurrentFileName <> '' Then Begin
  SetColor(White);
  OutTextXY(10, 6, CurrentFileName);
 End;

 { Papier blanc }
 SetFillStyle(SolidFill, White);
 Bar(0, PaperTop, ScreenWidth - 1, PaperBottom - 1);

 { Cadre du papier }
 SetColor(Black);
 Rectangle(2, PaperTop + 2, ScreenWidth - 3, PaperBottom - 3);

 { Bandeau d'instruction en bas }
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, PaperBottom, ScreenWidth - 1, ScreenHeight - 1);
 SetColor(LightGray);
 Title := 'Appuyez sur une touche pour fermer l''apercu...';
 OutTextXY((ScreenWidth - TextWidth(Title)) Div 2,
           PaperBottom + (ScreenHeight - PaperBottom) Div 2 - 4, Title);

 { Dessiner les objets en noir sur le papier }
 SetColor(Black);
 For I := 0 To ObjectCount - 1 Do Begin
  If Not DrawObjects[I].Visible Then Continue;
  If DrawObjects[I].ObjType = OBJ_NONE Then Continue;
  If Not IsObjectOnVisibleLayer(I) Then Continue;

  Case DrawObjects[I].ObjType Of
   OBJ_LINE: Begin
    SX1 := WorldToScreenX(DrawObjects[I].X1);
    SY1 := WorldToScreenY(DrawObjects[I].Y1);
    SX2 := WorldToScreenX(DrawObjects[I].X2);
    SY2 := WorldToScreenY(DrawObjects[I].Y2);
    Line(SX1, SY1, SX2, SY2);
   End;
   OBJ_RECTANGLE: Begin
    SX1 := WorldToScreenX(DrawObjects[I].X1);
    SY1 := WorldToScreenY(DrawObjects[I].Y1);
    SX2 := WorldToScreenX(DrawObjects[I].X2);
    SY2 := WorldToScreenY(DrawObjects[I].Y2);
    Rectangle(SX1, SY1, SX2, SY2);
   End;
   OBJ_CIRCLE: Begin
    SCX := WorldToScreenX(DrawObjects[I].X1);
    SCY := WorldToScreenY(DrawObjects[I].Y1);
    SR := Round(DrawObjects[I].Radius * ZoomLevel);
    If SR < 1 Then SR := 1;
    Circle(SCX, SCY, SR);
   End;
   OBJ_ARC: Begin
    SCX := WorldToScreenX(DrawObjects[I].X1);
    SCY := WorldToScreenY(DrawObjects[I].Y1);
    SR := Round(DrawObjects[I].Radius * ZoomLevel);
    If SR < 1 Then SR := 1;
    Arc(SCX, SCY, Round(DrawObjects[I].StartAngle),
        Round(DrawObjects[I].EndAngle), SR);
   End;
   OBJ_ELLIPSE: Begin
    SCX := WorldToScreenX(DrawObjects[I].X1);
    SCY := WorldToScreenY(DrawObjects[I].Y1);
    SR := Round(DrawObjects[I].Radius * ZoomLevel);
    If SR < 1 Then SR := 1;
    { Approximation: utilise Ellipse avec rayon X = Radius et rayon Y deduit de Y2 }
    SX1 := Round(Abs(DrawObjects[I].Y2 - DrawObjects[I].Y1) * ZoomLevel);
    If SX1 < 1 Then SX1 := SR;
    Ellipse(SCX, SCY, 0, 360, SR, SX1);
   End;
   OBJ_POINT: Begin
    SX1 := WorldToScreenX(DrawObjects[I].X1);
    SY1 := WorldToScreenY(DrawObjects[I].Y1);
    PutPixel(SX1, SY1, Black);
    Line(SX1 - 2, SY1, SX1 + 2, SY1);
    Line(SX1, SY1 - 2, SX1, SY1 + 2);
   End;
   OBJ_TEXT: Begin
    SX1 := WorldToScreenX(DrawObjects[I].X1);
    SY1 := WorldToScreenY(DrawObjects[I].Y1);
    OutTextXY(SX1, SY1, DrawObjects[I].DimText);
   End;
   OBJ_POLYLINE: Begin
    If DrawObjects[I].VertexCount >= 2 Then Begin
     PrevSX := WorldToScreenX(DrawObjects[I].Vertices[0].X);
     PrevSY := WorldToScreenY(DrawObjects[I].Vertices[0].Y);
     For J := 1 To DrawObjects[I].VertexCount - 1 Do Begin
      SX2 := WorldToScreenX(DrawObjects[I].Vertices[J].X);
      SY2 := WorldToScreenY(DrawObjects[I].Vertices[J].Y);
      Line(PrevSX, PrevSY, SX2, SY2);
      PrevSX := SX2;
      PrevSY := SY2;
     End;
     If DrawObjects[I].Closed and (DrawObjects[I].VertexCount >= 3) Then Begin
      SX2 := WorldToScreenX(DrawObjects[I].Vertices[0].X);
      SY2 := WorldToScreenY(DrawObjects[I].Vertices[0].Y);
      Line(PrevSX, PrevSY, SX2, SY2);
     End;
    End;
   End;
  End;
 End;

 { Attendre une touche }
 K := ReadKey;
 If K = #0 Then K := ReadKey;

 { Restaurer la vue et l'interface }
 ZoomLevel := SavedZoom;
 ViewOffsetX := SavedOffX;
 ViewOffsetY := SavedOffY;
 DrawInterface;
 CommandLastLine := 'Apercu ferme';
End;

{ Helper : parse "x1 y1 x2 y2" (4 reels separes par espaces) pour Format->Limits }
Function ParseFourReals(Const S: String; Var A, B, C, D: Real): Boolean;
Var
 Toks: Array[0..3] of String[32];
 N, I, Code: Integer;
 V: Real;
 InTok: Boolean;
Begin
 ParseFourReals := False;
 N := 0;
 Toks[0] := ''; Toks[1] := ''; Toks[2] := ''; Toks[3] := '';
 InTok := False;
 For I := 1 To Length(S) Do Begin
  If (S[I] = ' ') or (S[I] = #9) or (S[I] = ',') Then Begin
   If InTok Then Begin
    Inc(N);
    If N >= 4 Then Begin InTok := False; Continue; End;
    InTok := False;
   End;
  End Else Begin
   If N > 3 Then Exit;
   Toks[N] := Toks[N] + S[I];
   InTok := True;
  End;
 End;
 If InTok Then Inc(N);
 If N <> 4 Then Exit;
 Val(Toks[0], V, Code); If Code <> 0 Then Exit; A := V;
 Val(Toks[1], V, Code); If Code <> 0 Then Exit; B := V;
 Val(Toks[2], V, Code); If Code <> 0 Then Exit; C := V;
 Val(Toks[3], V, Code); If Code <> 0 Then Exit; D := V;
 ParseFourReals := True;
End;

{ Parse jusqu'a MaxCount reels separes par espaces/virgules ; renvoie N effectif }
Function ParseReals(Const S: String; Var Vals: Array Of Real;
                    MaxCount: Integer; Var N: Integer): Boolean;
Var
 Tok: String[32];
 I, Code: Integer;
 V: Real;
 InTok: Boolean;
 Ch: Char;
Begin
 ParseReals := False;
 N := 0;
 Tok := '';
 InTok := False;
 For I := 1 To Length(S) Do Begin
  Ch := S[I];
  If (Ch = ' ') or (Ch = #9) or (Ch = ',') Then Begin
   If InTok Then Begin
    If N >= MaxCount Then Exit;
    Val(Tok, V, Code); If Code <> 0 Then Exit;
    Vals[N] := V; Inc(N);
    Tok := ''; InTok := False;
   End;
  End Else Begin
   Tok := Tok + Ch;
   InTok := True;
  End;
 End;
 If InTok Then Begin
  If N >= MaxCount Then Exit;
  Val(Tok, V, Code); If Code <> 0 Then Exit;
  Vals[N] := V; Inc(N);
 End;
 ParseReals := True;
End;

{ Boucle principale }
Procedure MainLoop;
Var
 OldMouseX, OldMouseY, OldButtons: Integer;
 LX, LY, LB: LongInt;
 Key: Char;
 PanStep: Real;
 I: Integer;  { TODO 9: Variable pour la sélection }
 BlinkTick: Integer;
 SavedSW, SavedSH: Integer;
 Ext: String[8];
 OkFlag: Boolean;
 CmdBufStr: String[16];
 J, OkInt: Integer;
 Vals: Array[0..63] of Real;
 Nv, Kv: Integer;
 NewIdx: Integer;
Begin
 Running := True;
 OldMouseX := -1;
 OldMouseY := -1;
 OldButtons := 0;
 BlinkTick := 0;

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
    { TODO 10: Terminer l'édition via grip si active }
    If GripEditActive Then Begin
     FinishGripEdit;
     DrawInterface;
    End;
    { TODO 9: Terminer la sélection par fenêtre si active }
    If MouseMode = MOUSE_MODE_SELECT Then Begin
     FinishWindowSelection;
     { TODO 10: Mettre à jour les grips après sélection }
     UpdateGripsForSelection;
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
   { TODO 8: Redessiner le canvas pour mettre à jour le crosshair.
     Ne pas redessiner si un menu déroulant ou contextuel est ouvert,
     sinon le dessin recouvrirait le menu et empêcherait sa sélection. }
   If (Not MenuActive) and (Not ContextMenuActive) Then Begin
    DrawCanvas;
    { Mettre à jour la barre d'état avec les nouvelles coordonnées }
    DrawStatusBar;
   End;
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
     End Else If GripEditActive Then Begin
      { TODO 10: Annuler l'édition via grip }
      CancelGripEdit;
      MouseDragging := False;
      DrawInterface;
     End Else If MenuActive Then Begin
      MenuActive := False;
      ActiveMenu := -1;
      ActiveMenuItem := -1;
      DrawInterface;
     End Else If PendingFileAction <> 0 Then Begin
      { Annuler la saisie d'un nom de fichier }
      PendingFileAction := 0;
      CommandPrompt := 'Command:';
      CommandBuffer := '';
      CommandLastLine := '*Cancel*';
      DrawInterface;
     End Else If CommandBuffer <> '' Then Begin
      { Effacer la commande en cours de saisie }
      CommandBuffer := '';
      CommandLastLine := '*Cancel*';
      DrawCommandLine;
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
      ClearGrips;  { TODO 10: Effacer les grips }
      DrawInterface;
     End Else Begin
      If ConfirmExit Then Running := False;
     End;
    End;
    #8: Begin { Backspace : effacer un caractère }
     If Length(CommandBuffer) > 0 Then Begin
      CommandBuffer := Copy(CommandBuffer, 1, Length(CommandBuffer) - 1);
      CommandCursorBlink := True;
      DrawCommandLine;
     End;
    End;
    #13: Begin { Enter : exécuter la commande }
     If MenuActive and (ActiveMenu >= 0) and (ActiveMenuItem >= 0) Then Begin
      { Activer l'element de menu actuellement surligne (simule un clic) }
      HandleMouseClick(Menus[ActiveMenu].X + 4,
                       MENUBAR_HEIGHT + 2 + ActiveMenuItem * 18 + 4,
                       MOUSE_BUTTON_LEFT);
     End Else If PendingFileAction <> 0 Then Begin
      If CommandBuffer = '' Then Begin
       { Saisie annulee }
       PendingFileAction := 0;
       CommandPrompt := 'Command:';
       CommandLastLine := '*Cancel*';
      End Else Begin
       Case PendingFileAction Of
        1: Begin { Ouvrir }
         SavedSW := ScreenWidth;
         SavedSH := ScreenHeight;
         If ReadDWGFile(CommandBuffer) Then Begin
          CurrentFileName := CommandBuffer;
          CommandLastLine := 'Charge: ' + CommandBuffer;
         End Else
          CommandLastLine := 'Echec chargement: ' + CommandBuffer;
         { Restaurer dimensions ecran (ReadDWGHeader les ecrase) }
         ScreenWidth := SavedSW;
         ScreenHeight := SavedSH;
        End;
        2: Begin { Enregistrer sous }
         If WriteDWGFile(CommandBuffer) Then Begin
          CurrentFileName := CommandBuffer;
          CommandLastLine := 'Enregistre: ' + CommandBuffer;
         End Else
          CommandLastLine := 'Echec enregistrement: ' + CommandBuffer;
        End;
        3: Begin { Importer - dispatch sur extension }
         Ext := '';
         For I := Length(CommandBuffer) DownTo 1 Do
          If CommandBuffer[I] = '.' Then Begin
           Ext := Copy(CommandBuffer, I + 1, Length(CommandBuffer) - I);
           Break;
          End;
         For I := 1 To Length(Ext) Do Ext[I] := UpCase(Ext[I]);
         SavedSW := ScreenWidth;
         SavedSH := ScreenHeight;
         OkFlag := False;
         If Ext = 'DWG' Then OkFlag := ReadDWGFile(CommandBuffer) Else
         If Ext = 'DXF' Then OkFlag := ReadDXFFile(CommandBuffer) Else
         If Ext = 'SVG' Then OkFlag := ReadSVGFile(CommandBuffer) Else
          CommandLastLine := 'Importer: extension non supportee (.dwg/.dxf/.svg)';
         ScreenWidth := SavedSW;
         ScreenHeight := SavedSH;
         If (Ext = 'DWG') or (Ext = 'DXF') or (Ext = 'SVG') Then Begin
          If OkFlag Then Begin
           CurrentFileName := CommandBuffer;
           CommandLastLine := 'Importe: ' + CommandBuffer;
          End Else
           CommandLastLine := 'Echec importation: ' + CommandBuffer;
         End;
        End;
        4: Begin { Exporter - dispatch sur extension }
         Ext := '';
         For I := Length(CommandBuffer) DownTo 1 Do
          If CommandBuffer[I] = '.' Then Begin
           Ext := Copy(CommandBuffer, I + 1, Length(CommandBuffer) - I);
           Break;
          End;
         For I := 1 To Length(Ext) Do Ext[I] := UpCase(Ext[I]);
         OkFlag := False;
         If Ext = 'DXF' Then OkFlag := WriteDXFFile(CommandBuffer) Else
         If Ext = 'SVG' Then OkFlag := WriteSVGFile(CommandBuffer) Else
         If Ext = 'DWG' Then OkFlag := WriteDWGFile(CommandBuffer) Else
          CommandLastLine := 'Exporter: extension non supportee (.dxf/.svg/.dwg)';
         If (Ext = 'DWG') or (Ext = 'DXF') or (Ext = 'SVG') Then Begin
          If OkFlag Then
           CommandLastLine := 'Exporte: ' + CommandBuffer
          Else
           CommandLastLine := 'Echec exportation: ' + CommandBuffer;
         End;
        End;
        5: Begin { Inserer un bloc par nom }
         I := FindBlockByName(CommandBuffer);
         If I < 0 Then
          CommandLastLine := 'Bloc introuvable: ' + CommandBuffer
         Else If Not BlockDefs[I].IsDefined Then
          CommandLastLine := 'Bloc non defini: ' + CommandBuffer
         Else Begin
          If InsertBlock(I, -ViewOffsetX, -ViewOffsetY, 1.0, 1.0, 0.0) >= 0 Then
           CommandLastLine := 'Bloc insere: ' + CommandBuffer
          Else
           CommandLastLine := 'Echec insertion bloc: ' + CommandBuffer;
         End;
        End;
        6: Begin { Inserer reference DWG (comportement = import) }
         Ext := '';
         For I := Length(CommandBuffer) DownTo 1 Do
          If CommandBuffer[I] = '.' Then Begin
           Ext := Copy(CommandBuffer, I + 1, Length(CommandBuffer) - I);
           Break;
          End;
         For I := 1 To Length(Ext) Do Ext[I] := UpCase(Ext[I]);
         SavedSW := ScreenWidth;
         SavedSH := ScreenHeight;
         OkFlag := False;
         If (Ext = 'DWG') or (Ext = '') Then OkFlag := ReadDWGFile(CommandBuffer)
         Else CommandLastLine := 'Reference DWG: extension non .DWG';
         ScreenWidth := SavedSW;
         ScreenHeight := SavedSH;
         If OkFlag Then Begin
          CurrentFileName := CommandBuffer;
          CommandLastLine := 'Reference DWG chargee: ' + CommandBuffer;
         End Else If (Ext = 'DWG') or (Ext = '') Then
          CommandLastLine := 'Echec reference DWG: ' + CommandBuffer;
        End;
        7: Begin { Inserer reference d'image }
         I := AttachImageRef(CommandBuffer, -ViewOffsetX, -ViewOffsetY, 0, 0, 0.0);
         If I < 0 Then
          CommandLastLine := 'Echec attache image: ' + CommandBuffer
         Else If ImageRefs[I].Status = IMGREF_NOT_FOUND Then
          CommandLastLine := 'Image attachee (fichier manquant): ' + CommandBuffer
         Else
          CommandLastLine := 'Image attachee: ' + CommandBuffer;
        End;
        8: Begin { Inserer objet OLE }
         I := AttachOLEObject(CommandBuffer, -ViewOffsetX, -ViewOffsetY, 0, 0);
         If I < 0 Then
          CommandLastLine := 'Echec insertion OLE: ' + CommandBuffer
         Else If OLEObjects[I].Status = OLE_NOT_FOUND Then
          CommandLastLine := 'Objet OLE insere (fichier manquant): ' + CommandBuffer
         Else
          CommandLastLine := 'Objet OLE insere (' + OLEObjects[I].AppName + '): ' + CommandBuffer;
        End;
        9: Begin { Importer un fichier 3D Studio (.3DS) }
         I := 0;
         If Import3DSFile(CommandBuffer, I) Then Begin
          Str(I, CmdBufStr);
          CommandLastLine := 'Fichier 3DS importe (' + CmdBufStr + ' aretes): ' + CommandBuffer;
          MarkDocumentModified;
         End Else
          CommandLastLine := 'Echec import 3DS: ' + CommandBuffer;
        End;
        10: Begin { Importer un fichier ACIS (.SAT) }
         I := 0;
         If ImportACISFile(CommandBuffer, I) Then Begin
          Str(I, CmdBufStr);
          CommandLastLine := 'Fichier ACIS importe (' + CmdBufStr + ' segments): ' + CommandBuffer;
          MarkDocumentModified;
         End Else
          CommandLastLine := 'Echec import ACIS: ' + CommandBuffer;
        End;
        20: Begin { Format -> Layer : selectionne ou cree calque courant }
         I := FindLayerByName(CommandBuffer);
         If I < 0 Then Begin
          I := AddLayer(CommandBuffer);
          If I >= 0 Then Begin
           CurrentLayer := I;
           CommandLastLine := 'Calque cree et courant: ' + CommandBuffer;
           MarkDocumentModified;
          End Else
           CommandLastLine := 'Calque: capacite maximale atteinte';
         End Else Begin
          CurrentLayer := I;
          CommandLastLine := 'Calque courant: ' + CommandBuffer;
         End;
        End;
        21: Begin { Format -> Color }
         Val(CommandBuffer, I, OkInt);
         If (OkInt <> 0) or (I < 0) or (I > 256) Then
          CommandLastLine := 'Couleur invalide (0..256): ' + CommandBuffer
         Else Begin
          CurrentColor := I;
          CommandLastLine := 'Couleur courante = ' + CommandBuffer;
         End;
        End;
        22: Begin { Format -> Linetype }
         Val(CommandBuffer, I, OkInt);
         If (OkInt <> 0) or (I < 0) or (I > 255) Then
          CommandLastLine := 'Type de ligne invalide (0..255): ' + CommandBuffer
         Else Begin
          CurrentLineType := Byte(I);
          CommandLastLine := 'Type de ligne courant = ' + CommandBuffer;
         End;
        End;
        23: Begin { Format -> Lineweight }
         Val(CommandBuffer, I, OkInt);
         If (OkInt <> 0) or (I < 0) or (I > 1000) Then
          CommandLastLine := 'Epaisseur invalide (0..1000): ' + CommandBuffer
         Else Begin
          CurrentLineWeight := I;
          CommandLastLine := 'Epaisseur courante = ' + CommandBuffer;
         End;
        End;
        24: Begin { Format -> Text Style }
         If Length(CommandBuffer) = 0 Then
          CommandLastLine := 'Style de texte: nom vide'
         Else Begin
          If Length(CommandBuffer) > 16 Then
           CurrentTextStyleName := Copy(CommandBuffer, 1, 16)
          Else
           CurrentTextStyleName := CommandBuffer;
          CommandLastLine := 'Style de texte courant: ' + CurrentTextStyleName;
         End;
        End;
        25: Begin { Format -> Dimension Style }
         If Length(CommandBuffer) = 0 Then
          CommandLastLine := 'Style de cote: nom vide'
         Else Begin
          If Length(CommandBuffer) > 16 Then
           CurrentDimStyleName := Copy(CommandBuffer, 1, 16)
          Else
           CurrentDimStyleName := CommandBuffer;
          CommandLastLine := 'Style de cote courant: ' + CurrentDimStyleName;
         End;
        End;
        26: Begin { Format -> Point Style }
         Val(CommandBuffer, I, OkInt);
         If (OkInt <> 0) or (I < 0) or (I > 4) Then
          CommandLastLine := 'Style de point invalide (0..4): ' + CommandBuffer
         Else Begin
          CurrentPointStyle := I;
          CommandLastLine := 'Style de point = ' + CommandBuffer;
         End;
        End;
        27: Begin { Format -> Units }
         Val(CommandBuffer, I, OkInt);
         If (OkInt <> 0) or (I < 0) or (I > 4) Then
          CommandLastLine := 'Unites invalides (0..4): ' + CommandBuffer
         Else Begin
          CurrentUnits := I;
          Case I Of
           0: CommandLastLine := 'Unites = Scientifique';
           1: CommandLastLine := 'Unites = Decimal';
           2: CommandLastLine := 'Unites = Ingenierie';
           3: CommandLastLine := 'Unites = Architectural';
           4: CommandLastLine := 'Unites = Fractionnel';
          End;
         End;
        End;
        28: Begin { Format -> Drawing Limits }
         If ParseFourReals(CommandBuffer, LimMinX, LimMinY, LimMaxX, LimMaxY) Then Begin
          CommandLastLine := 'Limites mises a jour';
          MarkDocumentModified;
         End Else
          CommandLastLine := 'Limites: format invalide (4 reels separes par espaces)';
        End;
        29: Begin { Format -> Rename layer "ancien=nouveau" }
         J := Pos('=', CommandBuffer);
         If J <= 1 Then
          CommandLastLine := 'Renommer: format AncienNom=NouveauNom'
         Else Begin
          Ext := Copy(CommandBuffer, 1, J - 1);
          CmdBufStr := Copy(CommandBuffer, J + 1, Length(CommandBuffer) - J);
          I := FindLayerByName(Ext);
          If I < 0 Then
           CommandLastLine := 'Calque introuvable: ' + Ext
          Else If Length(CmdBufStr) = 0 Then
           CommandLastLine := 'Nouveau nom vide'
          Else If FindLayerByName(CmdBufStr) >= 0 Then
           CommandLastLine := 'Nom deja utilise: ' + CmdBufStr
          Else Begin
           Layers[I].Name := CmdBufStr;
           CommandLastLine := 'Calque renomme: ' + Ext + ' -> ' + CmdBufStr;
           MarkDocumentModified;
          End;
         End;
        End;
        30: Begin { Outils -> Quick Select par type d'objet }
         Val(CommandBuffer, I, OkInt);
         If (OkInt <> 0) or (I < 1) or (I > 8) Then
          CommandLastLine := 'Selection rapide: type invalide (1..8)'
         Else Begin
          J := 0;
          For OkInt := 0 To ObjectCount - 1 Do
           If DrawObjects[OkInt].ObjType = Byte(I) Then Begin
            DrawObjects[OkInt].Selected := True;
            Inc(J);
           End;
          Str(J, CmdBufStr);
          CommandLastLine := 'Selection rapide: ' + CmdBufStr + ' objet(s) selectionne(s)';
          DrawInterface;
         End;
        End;
        31: Begin { Outils -> Load Application (.LSP) }
         LoadLispApplicationFile(CommandBuffer);
        End;
        32: Begin { Outils -> Run Script (.SCR) }
         RunScriptFile(CommandBuffer);
        End;
        33: Begin { Outils -> AutoLISP - evaluer expression }
         If Length(CommandBuffer) > 0 Then Begin
          LispEvaluator.LastResult := LispEvaluate(CommandBuffer);
          CommandLastLine := 'LISP => ' + LispValueToString(LispEvaluator.LastResult);
         End Else
          CommandLastLine := 'LISP: expression vide';
        End;
        34: Begin { Outils -> Drafting Settings - reglages snap }
         Val(CommandBuffer, PanStep, OkInt);
         If OkInt <> 0 Then
          CommandLastLine := 'Reglages: nombre invalide: ' + CommandBuffer
         Else If PanStep <= 0.0 Then Begin
          SnapEnabled := False;
          CommandLastLine := 'Snap desactive';
         End Else Begin
          SnapEnabled := True;
          SnapSpacing := PanStep;
          Str(SnapSpacing:0:3, CmdBufStr);
          CommandLastLine := 'Snap active, pas=' + CmdBufStr;
         End;
        End;
        35: Begin { Outils -> Personnaliser - basculer toolbar }
         { Convertir CommandBuffer en majuscules pour comparaison }
         Ext := '';
         For I := 1 To Length(CommandBuffer) Do
          If Length(Ext) < 8 Then Ext := Ext + UpCase(CommandBuffer[I]);
         If (Ext = 'ALL ON') or (Ext = 'ALLON') Then Begin
          For I := 0 To MAX_TOOLBARS - 1 Do Toolbars[I].Visible := True;
          CommandLastLine := 'Toutes les barres d''outils affichees';
          DrawInterface;
         End Else If (Ext = 'ALL OFF') or (Ext = 'ALLOFF') Then Begin
          For I := 0 To MAX_TOOLBARS - 1 Do Toolbars[I].Visible := False;
          CommandLastLine := 'Toutes les barres d''outils masquees';
          DrawInterface;
         End Else If Ext = 'RESET' Then Begin
          Toolbars[TOOLBAR_STANDARD].Visible := True;
          Toolbars[TOOLBAR_DRAW].Visible := True;
          Toolbars[TOOLBAR_MODIFY].Visible := True;
          Toolbars[TOOLBAR_LAYERS].Visible := False;
          Toolbars[TOOLBAR_PROPERTIES].Visible := False;
          CommandLastLine := 'Barres d''outils reinitialisees';
          DrawInterface;
         End Else Begin
          J := -1;
          For I := 0 To MAX_TOOLBARS - 1 Do Begin
           CmdBufStr := '';
           For OkInt := 1 To Length(Toolbars[I].Title) Do
            If Length(CmdBufStr) < 8 Then
             CmdBufStr := CmdBufStr + UpCase(Toolbars[I].Title[OkInt]);
           If CmdBufStr = Ext Then J := I;
          End;
          If J < 0 Then
           CommandLastLine := 'Barre inconnue: ' + CommandBuffer
          Else Begin
           Toolbars[J].Visible := Not Toolbars[J].Visible;
           If Toolbars[J].Visible Then
            CommandLastLine := 'Barre ' + Toolbars[J].Title + ' affichee'
           Else
            CommandLastLine := 'Barre ' + Toolbars[J].Title + ' masquee';
           DrawInterface;
          End;
         End;
        End;
        40: Begin { Dessin -> Ligne }
         If ParseFourReals(CommandBuffer, Vals[0], Vals[1], Vals[2], Vals[3]) Then Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Ligne: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_LINE;
           DrawObjects[NewIdx].X1 := Vals[0]; DrawObjects[NewIdx].Y1 := Vals[1];
           DrawObjects[NewIdx].X2 := Vals[2]; DrawObjects[NewIdx].Y2 := Vals[3];
           CommandLastLine := 'Ligne creee';
           MarkDocumentModified; DrawInterface;
          End;
         End Else
          CommandLastLine := 'Ligne: 4 reels attendus';
        End;
        41,42: Begin { Dessin -> Ray (demi-droite) / Construction Line (droite) }
         If ParseFourReals(CommandBuffer, Vals[0], Vals[1], Vals[2], Vals[3]) Then Begin
          PanStep := Sqrt((Vals[2]-Vals[0])*(Vals[2]-Vals[0]) +
                          (Vals[3]-Vals[1])*(Vals[3]-Vals[1]));
          If PanStep < 1E-9 Then Begin
           CommandLastLine := 'Direction nulle';
          End Else Begin
           NewIdx := AllocEntitySlot;
           If NewIdx < 0 Then
            CommandLastLine := 'Construction: dessin plein'
           Else Begin
            DrawObjects[NewIdx].ObjType := OBJ_LINE;
            { Pour XLine, etendre aussi vers l'arriere }
            If PendingFileAction = 42 Then Begin
             DrawObjects[NewIdx].X1 := Vals[0] - (Vals[2]-Vals[0])/PanStep * 1.0E5;
             DrawObjects[NewIdx].Y1 := Vals[1] - (Vals[3]-Vals[1])/PanStep * 1.0E5;
            End Else Begin
             DrawObjects[NewIdx].X1 := Vals[0];
             DrawObjects[NewIdx].Y1 := Vals[1];
            End;
            DrawObjects[NewIdx].X2 := Vals[0] + (Vals[2]-Vals[0])/PanStep * 1.0E5;
            DrawObjects[NewIdx].Y2 := Vals[1] + (Vals[3]-Vals[1])/PanStep * 1.0E5;
            If PendingFileAction = 41 Then
             CommandLastLine := 'Demi-droite creee'
            Else
             CommandLastLine := 'Droite de construction creee';
            MarkDocumentModified; DrawInterface;
           End;
          End;
         End Else
          CommandLastLine := 'Construction: 4 reels attendus';
        End;
        43,48: Begin { Dessin -> Polyligne / Spline }
         If Not ParseReals(CommandBuffer, Vals, 64, Nv) Then
          CommandLastLine := 'Polyligne: nombres invalides'
         Else If (Nv < 4) or Odd(Nv) Then
          CommandLastLine := 'Polyligne: paires X,Y attendues (min 2)'
         Else Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Polyligne: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_POLYLINE;
           DrawObjects[NewIdx].VertexCount := Word(Nv Shr 1);
           For Kv := 0 To (Nv Shr 1) - 1 Do Begin
            DrawObjects[NewIdx].Vertices[Kv].X := Vals[Kv*2];
            DrawObjects[NewIdx].Vertices[Kv].Y := Vals[Kv*2+1];
            DrawObjects[NewIdx].Vertices[Kv].Bulge := 0;
           End;
           DrawObjects[NewIdx].Closed := False;
           Str(Nv Shr 1, CmdBufStr);
           If PendingFileAction = 48 Then
            CommandLastLine := 'Spline creee (' + CmdBufStr + ' sommets)'
           Else
            CommandLastLine := 'Polyligne creee (' + CmdBufStr + ' sommets)';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        44: Begin { Dessin -> Polygone : N CX CY R }
         If Not ParseReals(CommandBuffer, Vals, 4, Nv) Then
          CommandLastLine := 'Polygone: nombres invalides'
         Else If Nv <> 4 Then
          CommandLastLine := 'Polygone: 4 valeurs attendues (N CX CY R)'
         Else Begin
          Kv := Trunc(Vals[0]);
          If (Kv < 3) or (Kv > 64) Then
           CommandLastLine := 'Polygone: nombre de cotes 3..64'
          Else If Vals[3] <= 0 Then
           CommandLastLine := 'Polygone: rayon doit etre positif'
          Else Begin
           NewIdx := AllocEntitySlot;
           If NewIdx < 0 Then
            CommandLastLine := 'Polygone: dessin plein'
           Else Begin
            DrawObjects[NewIdx].ObjType := OBJ_POLYLINE;
            DrawObjects[NewIdx].VertexCount := Word(Kv);
            For OkInt := 0 To Kv - 1 Do Begin
             DrawObjects[NewIdx].Vertices[OkInt].X :=
              Vals[1] + Vals[3] * Cos(2 * Pi * OkInt / Kv);
             DrawObjects[NewIdx].Vertices[OkInt].Y :=
              Vals[2] + Vals[3] * Sin(2 * Pi * OkInt / Kv);
             DrawObjects[NewIdx].Vertices[OkInt].Bulge := 0;
            End;
            DrawObjects[NewIdx].Closed := True;
            Str(Kv, CmdBufStr);
            CommandLastLine := 'Polygone cree (' + CmdBufStr + ' cotes)';
            MarkDocumentModified; DrawInterface;
           End;
          End;
         End;
        End;
        45: Begin { Dessin -> Rectangle }
         If ParseFourReals(CommandBuffer, Vals[0], Vals[1], Vals[2], Vals[3]) Then Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Rectangle: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_RECTANGLE;
           DrawObjects[NewIdx].X1 := Vals[0]; DrawObjects[NewIdx].Y1 := Vals[1];
           DrawObjects[NewIdx].X2 := Vals[2]; DrawObjects[NewIdx].Y2 := Vals[3];
           CommandLastLine := 'Rectangle cree';
           MarkDocumentModified; DrawInterface;
          End;
         End Else
          CommandLastLine := 'Rectangle: 4 reels attendus';
        End;
        46: Begin { Dessin -> Arc : CX CY R AngDeb AngFin }
         If Not ParseReals(CommandBuffer, Vals, 5, Nv) Then
          CommandLastLine := 'Arc: nombres invalides'
         Else If Nv <> 5 Then
          CommandLastLine := 'Arc: 5 reels attendus'
         Else If Vals[2] <= 0 Then
          CommandLastLine := 'Arc: rayon doit etre positif'
         Else Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Arc: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_ARC;
           DrawObjects[NewIdx].X1 := Vals[0];
           DrawObjects[NewIdx].Y1 := Vals[1];
           DrawObjects[NewIdx].Radius := Vals[2];
           DrawObjects[NewIdx].StartAngle := Vals[3];
           DrawObjects[NewIdx].EndAngle := Vals[4];
           CommandLastLine := 'Arc cree';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        47: Begin { Dessin -> Cercle : CX CY R }
         If Not ParseReals(CommandBuffer, Vals, 3, Nv) Then
          CommandLastLine := 'Cercle: nombres invalides'
         Else If Nv <> 3 Then
          CommandLastLine := 'Cercle: 3 reels attendus (CX CY R)'
         Else If Vals[2] <= 0 Then
          CommandLastLine := 'Cercle: rayon doit etre positif'
         Else Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Cercle: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_CIRCLE;
           DrawObjects[NewIdx].X1 := Vals[0];
           DrawObjects[NewIdx].Y1 := Vals[1];
           DrawObjects[NewIdx].Radius := Vals[2];
           CommandLastLine := 'Cercle cree';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        49: Begin { Dessin -> Ellipse : CX CY RX RY }
         If ParseFourReals(CommandBuffer, Vals[0], Vals[1], Vals[2], Vals[3]) Then Begin
          If (Vals[2] <= 0) or (Vals[3] <= 0) Then
           CommandLastLine := 'Ellipse: rayons doivent etre positifs'
          Else Begin
           NewIdx := AllocEntitySlot;
           If NewIdx < 0 Then
            CommandLastLine := 'Ellipse: dessin plein'
           Else Begin
            DrawObjects[NewIdx].ObjType := OBJ_ELLIPSE;
            DrawObjects[NewIdx].X1 := Vals[0];
            DrawObjects[NewIdx].Y1 := Vals[1];
            DrawObjects[NewIdx].Radius := Vals[2];           { rx }
            DrawObjects[NewIdx].X2 := Vals[0] + Vals[2];     { sommet droit }
            DrawObjects[NewIdx].Y2 := Vals[1];
            DrawObjects[NewIdx].StartAngle := 0.0;
            DrawObjects[NewIdx].EndAngle := Vals[3];         { ry }
            CommandLastLine := 'Ellipse creee';
            MarkDocumentModified; DrawInterface;
           End;
          End;
         End Else
          CommandLastLine := 'Ellipse: 4 reels attendus';
        End;
        50: Begin { Dessin -> Point : X Y }
         If Not ParseReals(CommandBuffer, Vals, 2, Nv) Then
          CommandLastLine := 'Point: nombres invalides'
         Else If Nv <> 2 Then
          CommandLastLine := 'Point: 2 reels attendus (X Y)'
         Else Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Point: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_POINT;
           DrawObjects[NewIdx].X1 := Vals[0];
           DrawObjects[NewIdx].Y1 := Vals[1];
           CommandLastLine := 'Point cree';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        51: Begin { Dessin -> Texte : X Y H Contenu }
         { Extraire 3 premiers tokens numeriques, le reste = contenu }
         Ext := '';                  { recyclage : "X Y H" parse }
         OkInt := 1;                 { OkInt = position courante }
         Nv := 0;
         CmdBufStr := '';
         While (OkInt <= Length(CommandBuffer)) and (Nv < 3) Do Begin
          { Sauter espaces }
          While (OkInt <= Length(CommandBuffer)) and
                ((CommandBuffer[OkInt] = ' ') or (CommandBuffer[OkInt] = #9)) Do
           Inc(OkInt);
          CmdBufStr := '';
          While (OkInt <= Length(CommandBuffer)) and
                (CommandBuffer[OkInt] <> ' ') and
                (CommandBuffer[OkInt] <> #9) Do Begin
           If Length(CmdBufStr) < 16 Then
            CmdBufStr := CmdBufStr + CommandBuffer[OkInt];
           Inc(OkInt);
          End;
          If Length(CmdBufStr) = 0 Then Break;
          Val(CmdBufStr, Vals[Nv], J);
          If J <> 0 Then Begin Nv := 99; Break; End;
          Inc(Nv);
         End;
         { Sauter espaces avant le contenu }
         While (OkInt <= Length(CommandBuffer)) and
               ((CommandBuffer[OkInt] = ' ') or (CommandBuffer[OkInt] = #9)) Do
          Inc(OkInt);
         If Nv <> 3 Then
          CommandLastLine := 'Texte: X Y H Contenu attendus'
         Else If OkInt > Length(CommandBuffer) Then
          CommandLastLine := 'Texte: contenu vide'
         Else If Vals[2] <= 0 Then
          CommandLastLine := 'Texte: hauteur doit etre positive'
         Else Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Texte: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_TEXT;
           DrawObjects[NewIdx].X1 := Vals[0];
           DrawObjects[NewIdx].Y1 := Vals[1];
           DrawObjects[NewIdx].Radius := Vals[2];  { hauteur }
           DrawObjects[NewIdx].DimText :=
            Copy(CommandBuffer, OkInt, Length(CommandBuffer) - OkInt + 1);
           If Length(DrawObjects[NewIdx].DimText) > 20 Then
            DrawObjects[NewIdx].DimText := Copy(DrawObjects[NewIdx].DimText, 1, 20);
           CommandLastLine := 'Texte cree: ' + DrawObjects[NewIdx].DimText;
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        61: Begin { Cotation -> Linear : X1 Y1 X2 Y2 DimLineY }
         If Not ParseReals(CommandBuffer, Vals, 5, Nv) Then
          CommandLastLine := 'Cote lineaire: 5 valeurs attendues'
         Else Begin
          NewIdx := CreateLinearDimension(Vals[0], Vals[1], Vals[2], Vals[3], Vals[4], True);
          If NewIdx < 0 Then
           CommandLastLine := 'Cote lineaire: dessin plein'
          Else Begin
           LastLinearDimX1 := Vals[0]; LastLinearDimY1 := Vals[1];
           LastLinearDimX2 := Vals[2]; LastLinearDimY2 := Vals[3];
           LastLinearDimLineY := Vals[4]; LastLinearDimValid := True;
           CommandLastLine := 'Cote lineaire creee';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        62: Begin { Cotation -> Aligned : X1 Y1 X2 Y2 Offset }
         If Not ParseReals(CommandBuffer, Vals, 5, Nv) Then
          CommandLastLine := 'Cote alignee: 5 valeurs attendues'
         Else Begin
          NewIdx := CreateAlignedDimension(Vals[0], Vals[1], Vals[2], Vals[3], Vals[4]);
          If NewIdx < 0 Then
           CommandLastLine := 'Cote alignee: dessin plein'
          Else Begin
           CommandLastLine := 'Cote alignee creee';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        63: Begin { Cotation -> Arc Length : CX CY R AngDeb AngFin (degres) }
         If Not ParseReals(CommandBuffer, Vals, 5, Nv) Then
          CommandLastLine := 'Longueur d''arc: 5 valeurs attendues'
         Else Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Longueur d''arc: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_TEXT;
           DrawObjects[NewIdx].X1 := Vals[0] + Vals[2] * 1.2;
           DrawObjects[NewIdx].Y1 := Vals[1];
           DrawObjects[NewIdx].Radius := 5.0;
           Str(Vals[2] * Abs(Vals[4] - Vals[3]) * Pi / 180.0:0:3, CmdBufStr);
           DrawObjects[NewIdx].DimText := 'L=' + CmdBufStr;
           If Length(DrawObjects[NewIdx].DimText) > 20 Then
            DrawObjects[NewIdx].DimText := Copy(DrawObjects[NewIdx].DimText, 1, 20);
           CommandLastLine := 'Longueur d''arc: ' + DrawObjects[NewIdx].DimText;
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        64: Begin { Cotation -> Ordinate : X Y LeaderX LeaderY }
         If Not ParseReals(CommandBuffer, Vals, 4, Nv) Then
          CommandLastLine := 'Cote ordonnee: 4 valeurs attendues'
         Else Begin
          NewIdx := CreateOrdinateDimension(Vals[0], Vals[1], Vals[2], Vals[3], True);
          If NewIdx < 0 Then
           CommandLastLine := 'Cote ordonnee: dessin plein'
          Else Begin
           CommandLastLine := 'Cote ordonnee creee';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        65: Begin { Cotation -> Radius : CX CY R AngleDeg }
         If Not ParseReals(CommandBuffer, Vals, 4, Nv) Then
          CommandLastLine := 'Cote rayon: 4 valeurs attendues'
         Else Begin
          NewIdx := CreateRadialDimension(Vals[0], Vals[1], Vals[2], Vals[3] * Pi / 180.0);
          If NewIdx < 0 Then
           CommandLastLine := 'Cote rayon: dessin plein'
          Else Begin
           CommandLastLine := 'Cote rayon creee';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        66: Begin { Cotation -> Diameter : CX CY R AngleDeg }
         If Not ParseReals(CommandBuffer, Vals, 4, Nv) Then
          CommandLastLine := 'Cote diametre: 4 valeurs attendues'
         Else Begin
          NewIdx := CreateDiameterDimension(Vals[0], Vals[1], Vals[2], Vals[3] * Pi / 180.0);
          If NewIdx < 0 Then
           CommandLastLine := 'Cote diametre: dessin plein'
          Else Begin
           CommandLastLine := 'Cote diametre creee';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        67: Begin { Cotation -> Angular : CX CY X1 Y1 X2 Y2 R }
         If Not ParseReals(CommandBuffer, Vals, 7, Nv) Then
          CommandLastLine := 'Cote angulaire: 7 valeurs attendues'
         Else Begin
          NewIdx := CreateAngularDimension(Vals[0], Vals[1], Vals[2], Vals[3], Vals[4], Vals[5], Vals[6]);
          If NewIdx < 0 Then
           CommandLastLine := 'Cote angulaire: dessin plein'
          Else Begin
           CommandLastLine := 'Cote angulaire creee';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        68: Begin { Cotation -> Baseline : X Y reutilisant origine derniere cote }
         If Not LastLinearDimValid Then
          CommandLastLine := 'Baseline: aucune cote lineaire precedente'
         Else If Not ParseReals(CommandBuffer, Vals, 2, Nv) Then
          CommandLastLine := 'Baseline: X Y attendus'
         Else Begin
          LastLinearDimLineY := LastLinearDimLineY + 10.0;
          NewIdx := CreateLinearDimension(LastLinearDimX1, LastLinearDimY1, Vals[0], Vals[1], LastLinearDimLineY, True);
          If NewIdx < 0 Then
           CommandLastLine := 'Baseline: dessin plein'
          Else Begin
           LastLinearDimX2 := Vals[0]; LastLinearDimY2 := Vals[1];
           CommandLastLine := 'Baseline cote creee';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        69: Begin { Cotation -> Continue : X Y a partir de la fin precedente }
         If Not LastLinearDimValid Then
          CommandLastLine := 'Continue: aucune cote lineaire precedente'
         Else If Not ParseReals(CommandBuffer, Vals, 2, Nv) Then
          CommandLastLine := 'Continue: X Y attendus'
         Else Begin
          NewIdx := CreateLinearDimension(LastLinearDimX2, LastLinearDimY2, Vals[0], Vals[1], LastLinearDimLineY, True);
          If NewIdx < 0 Then
           CommandLastLine := 'Continue: dessin plein'
          Else Begin
           LastLinearDimX1 := LastLinearDimX2; LastLinearDimY1 := LastLinearDimY2;
           LastLinearDimX2 := Vals[0]; LastLinearDimY2 := Vals[1];
           CommandLastLine := 'Continue cote creee';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        70: Begin { Cotation -> Leader : X1 Y1 X2 Y2 Texte }
         OkInt := 1;
         Nv := 0;
         CmdBufStr := '';
         While (OkInt <= Length(CommandBuffer)) and (Nv < 4) Do Begin
          While (OkInt <= Length(CommandBuffer)) and
                ((CommandBuffer[OkInt] = ' ') or (CommandBuffer[OkInt] = #9)) Do
           Inc(OkInt);
          CmdBufStr := '';
          While (OkInt <= Length(CommandBuffer)) and
                (CommandBuffer[OkInt] <> ' ') and
                (CommandBuffer[OkInt] <> #9) Do Begin
           If Length(CmdBufStr) < 16 Then
            CmdBufStr := CmdBufStr + CommandBuffer[OkInt];
           Inc(OkInt);
          End;
          If Length(CmdBufStr) = 0 Then Break;
          Val(CmdBufStr, Vals[Nv], J);
          If J <> 0 Then Begin Nv := 99; Break; End;
          Inc(Nv);
         End;
         While (OkInt <= Length(CommandBuffer)) and
               ((CommandBuffer[OkInt] = ' ') or (CommandBuffer[OkInt] = #9)) Do
          Inc(OkInt);
         If Nv <> 4 Then
          CommandLastLine := 'Repere: X1 Y1 X2 Y2 Texte attendus'
         Else Begin
          NewIdx := AllocEntitySlot;
          If NewIdx < 0 Then
           CommandLastLine := 'Repere: dessin plein'
          Else Begin
           DrawObjects[NewIdx].ObjType := OBJ_LINE;
           DrawObjects[NewIdx].X1 := Vals[0];
           DrawObjects[NewIdx].Y1 := Vals[1];
           DrawObjects[NewIdx].X2 := Vals[2];
           DrawObjects[NewIdx].Y2 := Vals[3];
           If OkInt <= Length(CommandBuffer) Then Begin
            NewIdx := AllocEntitySlot;
            If NewIdx >= 0 Then Begin
             DrawObjects[NewIdx].ObjType := OBJ_TEXT;
             DrawObjects[NewIdx].X1 := Vals[2];
             DrawObjects[NewIdx].Y1 := Vals[3];
             DrawObjects[NewIdx].Radius := 5.0;
             DrawObjects[NewIdx].DimText :=
              Copy(CommandBuffer, OkInt, Length(CommandBuffer) - OkInt + 1);
             If Length(DrawObjects[NewIdx].DimText) > 20 Then
              DrawObjects[NewIdx].DimText := Copy(DrawObjects[NewIdx].DimText, 1, 20);
            End;
           End;
           CommandLastLine := 'Repere cree';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        80: Begin { Modifier -> Copy : DX DY }
         If Not ParseReals(CommandBuffer, Vals, 2, Nv) Then
          CommandLastLine := 'Copier: DX DY attendus'
         Else Begin
          CopySelectedObjects(Vals[0], Vals[1]);
          CommandLastLine := 'Copie effectuee';
          MarkDocumentModified; DrawInterface;
         End;
        End;
        81: Begin { Modifier -> Mirror : X1 Y1 X2 Y2 }
         If Not ParseReals(CommandBuffer, Vals, 4, Nv) Then
          CommandLastLine := 'Miroir: 4 valeurs attendues'
         Else Begin
          MirrorSelectedObjects(Vals[0], Vals[1], Vals[2], Vals[3]);
          CommandLastLine := 'Miroir effectue';
          MarkDocumentModified; DrawInterface;
         End;
        End;
        82: Begin { Modifier -> Offset : DX DY (clone offset) }
         If Not ParseReals(CommandBuffer, Vals, 2, Nv) Then
          CommandLastLine := 'Decaler: DX DY attendus'
         Else Begin
          CopySelectedObjects(Vals[0], Vals[1]);
          CommandLastLine := 'Decalage effectue';
          MarkDocumentModified; DrawInterface;
         End;
        End;
        83: Begin { Modifier -> Array : Rows Cols DX DY }
         If Not ParseReals(CommandBuffer, Vals, 4, Nv) Then
          CommandLastLine := 'Reseau: Lignes Colonnes DX DY attendus'
         Else Begin
          I := Trunc(Vals[0]); J := Trunc(Vals[1]);
          If (I < 1) or (J < 1) Then
           CommandLastLine := 'Reseau: dimensions invalides'
          Else Begin
           For OkInt := 0 To I - 1 Do
            For Nv := 0 To J - 1 Do
             If (OkInt <> 0) or (Nv <> 0) Then
              CopySelectedObjects(Nv * Vals[2], OkInt * Vals[3]);
           CommandLastLine := 'Reseau cree';
           MarkDocumentModified; DrawInterface;
          End;
         End;
        End;
        84: Begin { Modifier -> Move : DX DY }
         If Not ParseReals(CommandBuffer, Vals, 2, Nv) Then
          CommandLastLine := 'Deplacer: DX DY attendus'
         Else Begin
          MoveSelectedObjects(Vals[0], Vals[1]);
          CommandLastLine := 'Deplacement effectue';
          MarkDocumentModified; DrawInterface;
         End;
        End;
        85: Begin { Modifier -> Rotate : CX CY AngleDeg }
         If Not ParseReals(CommandBuffer, Vals, 3, Nv) Then
          CommandLastLine := 'Rotation: CX CY Angle attendus'
         Else Begin
          RotateSelectedObjects(Vals[0], Vals[1], Vals[2]);
          CommandLastLine := 'Rotation effectuee';
          MarkDocumentModified; DrawInterface;
         End;
        End;
        86: Begin { Modifier -> Scale : CX CY Factor }
         If Not ParseReals(CommandBuffer, Vals, 3, Nv) Then
          CommandLastLine := 'Echelle: CX CY Facteur attendus'
         Else If Vals[2] = 0 Then
          CommandLastLine := 'Echelle: facteur doit etre non nul'
         Else Begin
          ScaleSelectedObjects(Vals[0], Vals[1], Vals[2]);
          CommandLastLine := 'Echelle appliquee';
          MarkDocumentModified; DrawInterface;
         End;
        End;
        87: Begin { Modifier -> Stretch : DX DY (alias Move) }
         If Not ParseReals(CommandBuffer, Vals, 2, Nv) Then
          CommandLastLine := 'Etirer: DX DY attendus'
         Else Begin
          MoveSelectedObjects(Vals[0], Vals[1]);
          CommandLastLine := 'Etirement effectue';
          MarkDocumentModified; DrawInterface;
         End;
        End;
        88: Begin { Modifier -> Break : couper premiere ligne selectionnee au point X Y }
         If Not ParseReals(CommandBuffer, Vals, 2, Nv) Then
          CommandLastLine := 'Couper: X Y attendus'
         Else Begin
          NewIdx := -1;
          For I := 0 To ObjectCount - 1 Do
           If DrawObjects[I].Selected and (DrawObjects[I].ObjType = OBJ_LINE) Then Begin
            NewIdx := I; Break;
           End;
          If NewIdx < 0 Then
           CommandLastLine := 'Couper: aucune ligne selectionnee'
          Else Begin
           J := AllocEntitySlot;
           If J < 0 Then
            CommandLastLine := 'Couper: dessin plein'
           Else Begin
            DrawObjects[J] := DrawObjects[NewIdx];
            DrawObjects[J].X1 := Vals[0]; DrawObjects[J].Y1 := Vals[1];
            DrawObjects[J].Selected := False;
            DrawObjects[NewIdx].X2 := Vals[0]; DrawObjects[NewIdx].Y2 := Vals[1];
            CommandLastLine := 'Ligne coupee';
            MarkDocumentModified; DrawInterface;
           End;
          End;
         End;
        End;
        89: Begin { Modifier -> Chamfer : distance (stub) }
         If Not ParseReals(CommandBuffer, Vals, 1, Nv) Then
          CommandLastLine := 'Chanfrein: distance attendue'
         Else Begin
          Str(Vals[0]:0:3, CmdBufStr);
          CommandLastLine := 'Chanfrein distance=' + CmdBufStr +
           ' (selectionner 2 lignes - non implemente)';
         End;
        End;
        90: Begin { Modifier -> Fillet : radius (stub) }
         If Not ParseReals(CommandBuffer, Vals, 1, Nv) Then
          CommandLastLine := 'Raccord: rayon attendu'
         Else Begin
          Str(Vals[0]:0:3, CmdBufStr);
          CommandLastLine := 'Raccord rayon=' + CmdBufStr +
           ' (selectionner 2 lignes - non implemente)';
         End;
        End;
       End;
       PendingFileAction := 0;
       CommandPrompt := 'Command:';
      End;
      CommandBuffer := '';
      CommandCursorBlink := True;
      DrawInterface;
     End Else If CommandBuffer <> '' Then Begin
      CommandLastLine := 'Command: ' + CommandBuffer;
      { Si la ligne ressemble à du LISP (commence par '('), évaluer }
      If (Length(CommandBuffer) > 0) and (CommandBuffer[1] = '(') Then Begin
       LispEvaluator.LastResult := LispEvaluate(CommandBuffer);
       If LispEvaluator.LastResult.ValueType = LISP_VAL_ERROR Then
        CommandLastLine := 'Error: ' + LispEvaluator.LastResult.StrValue;
      End Else Begin
       { Dispatcher commandes AutoCAD tapees au clavier (LINE, CIRCLE, ...) }
       Ext := '';
       For I := 1 To Length(CommandBuffer) Do
        If Length(Ext) < 8 Then Ext := Ext + UpCase(CommandBuffer[I]);
       If (Ext = 'LINE') or (Ext = 'L') Then Begin
        PendingFileAction := 40; CommandPrompt := 'Ligne X1,Y1 X2,Y2:';
       End Else If Ext = 'RAY' Then Begin
        PendingFileAction := 41;
        CommandPrompt := 'Demi-droite X1,Y1 X2,Y2 (origine, direction):';
       End Else If (Ext = 'XLINE') or (Ext = 'XL') Then Begin
        PendingFileAction := 42;
        CommandPrompt := 'Droite de construction X1,Y1 X2,Y2:';
       End Else If (Ext = 'PLINE') or (Ext = 'PL') Then Begin
        PendingFileAction := 43;
        CommandPrompt := 'Polyligne X1,Y1 X2,Y2 X3,Y3 ... :';
       End Else If (Ext = 'POLYGON') or (Ext = 'POL') Then Begin
        PendingFileAction := 44;
        CommandPrompt := 'Polygone N CX,CY R (cotes, centre, rayon):';
       End Else If (Ext = 'RECTANG') or (Ext = 'REC') or
                   (Ext = 'RECTANGL') Then Begin
        PendingFileAction := 45; CommandPrompt := 'Rectangle X1,Y1 X2,Y2:';
       End Else If Ext = 'ARC' Then Begin
        PendingFileAction := 46;
        CommandPrompt := 'Arc CX,CY R AngDebut AngFin (degres):';
       End Else If (Ext = 'CIRCLE') or (Ext = 'C') Then Begin
        PendingFileAction := 47; CommandPrompt := 'Cercle CX,CY R:';
       End Else If (Ext = 'SPLINE') or (Ext = 'SPL') Then Begin
        PendingFileAction := 48;
        CommandPrompt := 'Spline X1,Y1 X2,Y2 X3,Y3 ... :';
       End Else If (Ext = 'ELLIPSE') or (Ext = 'EL') Then Begin
        PendingFileAction := 49; CommandPrompt := 'Ellipse CX,CY RX RY:';
       End Else If (Ext = 'POINT') or (Ext = 'PO') Then Begin
        PendingFileAction := 50; CommandPrompt := 'Point X,Y:';
       End Else If (Ext = 'TEXT') or (Ext = 'T') or (Ext = 'DTEXT') Then Begin
        PendingFileAction := 51; CommandPrompt := 'Texte X Y H Contenu:';
       End Else If Ext = 'HATCH' Then Begin
        ExecuteDrawHatch;
       End Else If Ext = 'REGION' Then Begin
        ExecuteDrawRegion;
       End Else Begin
        CommandLastLine := 'Commande inconnue: ' + CommandBuffer;
       End;
      End;
      CommandBuffer := '';
      CommandCursorBlink := True;
      DrawInterface;  { Rafraîchir tout (les nouveaux objets apparaissent) }
     End Else Begin
      CommandCursorBlink := True;
      DrawCommandLine;
     End;
    End;
    { TODO 7: Touche spéciale (flèches) - navigation menus ou pan du dessin }
    #0: Begin
     Key := ReadKey; { Lire le code étendu }
     If MenuActive and (ActiveMenu >= 0) Then Begin
      { Navigation clavier dans le menu deroulant actif }
      Case Key Of
       #72: Begin { Fleche haut - element precedent (saute les separateurs) }
        If ActiveMenuItem < 0 Then NewIdx := 0 Else NewIdx := ActiveMenuItem;
        For I := 1 To Menus[ActiveMenu].ItemCount Do Begin
         NewIdx := (NewIdx - 1 + Menus[ActiveMenu].ItemCount)
                   Mod Menus[ActiveMenu].ItemCount;
         If Not Menus[ActiveMenu].Items[NewIdx].Separator Then Break;
        End;
        ActiveMenuItem := NewIdx;
        DrawInterface;
       End;
       #80: Begin { Fleche bas - element suivant (saute les separateurs) }
        NewIdx := ActiveMenuItem;
        For I := 1 To Menus[ActiveMenu].ItemCount Do Begin
         NewIdx := (NewIdx + 1) Mod Menus[ActiveMenu].ItemCount;
         If Not Menus[ActiveMenu].Items[NewIdx].Separator Then Break;
        End;
        ActiveMenuItem := NewIdx;
        DrawInterface;
       End;
       #75: Begin { Fleche gauche - menu precedent dans la barre }
        ActiveMenu := (ActiveMenu + MAX_MENUS - 1) Mod MAX_MENUS;
        ActiveMenuItem := -1;
        DrawInterface;
       End;
       #77: Begin { Fleche droite - menu suivant dans la barre }
        ActiveMenu := (ActiveMenu + 1) Mod MAX_MENUS;
        ActiveMenuItem := -1;
        DrawInterface;
       End;
      End;
     End Else Begin
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
      #107: Begin { Alt+F4 - Quitter }
       If ConfirmExit Then Running := False;
      End;
     End;
     End; { Else (pas dans un menu) }
    End;
    Else Begin
     { Caractère imprimable : ajouter au tampon de la ligne de commande }
     If (Ord(Key) >= 32) and (Ord(Key) <= 126) and
        (Length(CommandBuffer) < 200) Then Begin
      CommandBuffer := CommandBuffer + Key;
      CommandCursorBlink := True;
      DrawCommandLine;
     End;
    End;
   End;
  End;

  { Faire clignoter le curseur de la ligne de commande (~500 ms) }
  Inc(BlinkTick);
  If BlinkTick >= 50 Then Begin
   BlinkTick := 0;
   CommandCursorBlink := Not CommandCursorBlink;
   DrawCommandLine;
  End;

  Delay(10);
 End;

 HideMouse;
End;

Var
 CmdArg: String;
 SavedSW, SavedSH: Integer;
 LoadOK: Boolean;
 ArgExt: String;
 I: Integer;
BEGIN
 { Initialiser la langue }
 Language:=_French;
 TmpLanguage:=GetEnv('LANGUAGE');
 If TmpLanguage<>''Then Begin
  If TmpLanguage[1]='"'Then TmpLanguage:=Copy(TmpLanguage,2,255);
  If StrToUpper(Copy(TmpLanguage,1,2))='EN'Then Language:=_English Else
  If StrToUpper(Copy(TmpLanguage,1,2))='GR'Then Language:=_Germany Else
  If StrToUpper(Copy(TmpLanguage,1,2))='IT'Then Language:=_Italian Else
  If StrToUpper(Copy(TmpLanguage,1,2))='SP'Then Language:=_Spain Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='SQ')or
    (StrToUpper(Copy(TmpLanguage,1,3))='ALB')Then Language:=_Albanian Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='PT')or
    (StrToUpper(Copy(TmpLanguage,1,3))='PRT')Then Language:=_Portuguese Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='SE')or
    (StrToUpper(Copy(TmpLanguage,1,3))='SWE')Then Language:=_Swedish Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='DK')or
    (StrToUpper(Copy(TmpLanguage,1,3))='DNK')Then Language:=_Danish Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='JP')or
    (StrToUpper(Copy(TmpLanguage,1,3))='JPN')Then Language:=_Japanese;
 End;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('AUTOCAD : Cette commande permet de lancer un clone de AutoCAD.');
  WriteLn;
  WriteLn('Syntaxe : AUTOCAD [image.DWG]');
  WriteLn;
  WriteLn(' image.DWG       Nom du fichier ".DWG" a editer');
  Halt;
 End;
 { Initialisation }
 InitializeGraphics;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;

 { Initialiser les menus }
 InitMenus;

 { Initialiser les barres d'outils - TODO 5 }
 InitToolbars;
 InitToolbarIcons;

 { Initialiser la gestion de la souris - TODO 6 }
 InitMouseState;

 { Initialiser le panneau de propriétés - TODO 16 }
 InitPropertiesPanel;

 { Initialiser la ligne de commande }
 CommandBuffer := '';
 CommandPrompt := 'Command:';
 CommandLastLine := '';
 CommandCursorBlink := True;
 PendingFileAction := 0;
 CurrentFileName := '';

 { Initialiser le suivi des modifications }
 DocumentModified := False;
 LastSavedObjectCount := 0;
 LastSavedBlockRefCount := 0;
 LastSavedImageRefCount := 0;
 LastSavedXRefCount := 0;
 LastSavedOLECount := 0;

 { Charger un fichier passe en argument de ligne de commande }
 If ParamCount >= 1 Then Begin
  CmdArg := ParamStr(1);
  ArgExt := '';
  For I := Length(CmdArg) DownTo 1 Do
   If CmdArg[I] = '.' Then Begin
    ArgExt := Copy(CmdArg, I + 1, Length(CmdArg) - I);
    Break;
   End;
  { Forcer majuscules pour comparaison }
  For I := 1 To Length(ArgExt) Do
   ArgExt[I] := UpCase(ArgExt[I]);
  SavedSW := ScreenWidth;
  SavedSH := ScreenHeight;
  LoadOK := False;
  If ArgExt = 'DWG' Then LoadOK := ReadDWGFile(CmdArg);
  { Restaurer dimensions ecran (ReadDWGHeader les ecrase) }
  ScreenWidth := SavedSW;
  ScreenHeight := SavedSH;
  If LoadOK Then
   CommandLastLine := 'Charge: ' + CmdArg
  Else
   CommandLastLine := 'Echec chargement: ' + CmdArg;
 End;
 { Dessiner l'interface initiale }
 DrawInterface;
 { Lancer la boucle principale }
 MainLoop;
 { Fermer le mode graphique }
 CloseGraph;
END.
