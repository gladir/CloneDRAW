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
  10. Gerer le clic droit pour afficher un menu contextuel avec options (Cut, Copy, Paste, Delete, Properties)
  11. Implementer le glisser-deposer (drag and drop) pour deplacer et redimensionner les objets
  12. Ajouter les poignees de redimensionnement sur les objets selectionnes avec detection de survol

  === OBJETS ET FORMES ===
  13. Creer les types d'objets de base: Rectangle, Ellipse, Ligne, Polygone, Courbe de Bezier, Texte, Image
  14. Implementer les connecteurs entre objets avec points d'ancrage automatiques
  15. Permettre la modification des proprietes des objets: couleur de remplissage, couleur de trait, epaisseur de ligne, style de ligne
  16. Ajouter le support des calques (layers) avec visibilite et verrouillage
  17. Implementer la gestion des groupes d'objets (grouper, degrouper, entrer dans le groupe)

  === FORMAT DE FICHIER VISIO ===
  18. Parser et lire les fichiers Visio VSD/VSDX (format binaire OLE et format XML compresse)
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
 TOOLBAR_COUNT = 6;
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
 
 { Noms des outils de la barre d'outils }
 ToolNames: Array[1..TOOLBAR_COUNT] of String[12] = (
   'Selection', 'Rectangle', 'Ellipse', 'Line', 'Connector', 'Text'
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
 TToolType = (ttSelection, ttRectangle, ttEllipse, ttLine, ttConnector, ttText);
 TShapeType = (stNone, stRectangle, stEllipse, stLine, stConnector, stText);
 
 { Structure pour un objet graphique }
 TShapeObject = Record
  ShapeType: TShapeType;
  X1, Y1, X2, Y2: Integer;  { Coordonnées du rectangle englobant }
  FillColor: Integer;        { Couleur de remplissage }
  LineColor: Integer;        { Couleur de contour }
  LineWidth: Integer;        { Épaisseur de ligne }
  Text: String[80];          { Texte (pour objets texte) }
  Selected: Boolean;         { Objet sélectionné }
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
 { Variables pour le dessin à la souris }
 IsDrawing: Boolean;
 DrawStartX, DrawStartY: Integer;
 LastMouseX, LastMouseY: Integer;
 LastMouseButton: LongInt;

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

{ Procédure New - Créer un nouveau document }
Procedure FileNew;
Begin
 CurrentFileName := '';
 DocumentModified := False;
 { TODO: Réinitialiser le canevas et les objets }
End;

{ Procédure Open - Ouvrir un fichier }
Procedure FileOpen;
Begin
 { TODO: Afficher une boîte de dialogue pour sélectionner un fichier }
 { TODO: Charger le fichier Visio }
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
Begin
 If LayerCount < MAX_LAYERS Then Begin
  LayerCount := LayerCount + 1;
  CurrentLayer := LayerCount;
  { TODO: Créer un nouveau calque dans la page courante }
  { TODO: Actualiser l'affichage pour montrer le nouveau calque }
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
 DEFAULT_TEXT_SIZE = 10;

Type
 TAlignmentType = (atLeft, atCenter, atRight, atTop, atMiddle, atBottom);
 TArrangeType = (arBringToFront, arSendToBack, arBringForward, arSendBackward);

Var
 CurrentFillColor: Integer;
 CurrentLineColor: Integer;
 CurrentLineWidth: Integer;
 CurrentTextSize: Integer;
 CurrentAlignment: TAlignmentType;
 ObjectsGrouped: Boolean;

{ Procédure FormatFill - Modifier la couleur de remplissage }
Procedure FormatFill;
Begin
 { TODO: Afficher une boîte de dialogue pour choisir la couleur de remplissage }
 { TODO: Appliquer la couleur de remplissage aux objets sélectionnés }
 If HasSelection Then Begin
  DocumentModified := True;
 End;
End;

{ Procédure FormatLine - Modifier les propriétés de ligne }
Procedure FormatLine;
Begin
 { TODO: Afficher une boîte de dialogue pour choisir la couleur, épaisseur et style de ligne }
 { TODO: Appliquer les propriétés de ligne aux objets sélectionnés }
 If HasSelection Then Begin
  DocumentModified := True;
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

{ Procédure FormatGroup - Grouper les objets sélectionnés }
Procedure FormatGroup;
Begin
 If HasSelection Then Begin
  { TODO: Créer un groupe avec les objets sélectionnés }
  { TODO: Le groupe devient un seul objet sélectionnable }
  ObjectsGrouped := True;
  DocumentModified := True;
 End;
End;

{ Procédure FormatUngroup - Dégrouper les objets }
Procedure FormatUngroup;
Begin
 If HasSelection And ObjectsGrouped Then Begin
  { TODO: Séparer le groupe en objets individuels }
  { TODO: Tous les objets du groupe deviennent sélectionnés }
  ObjectsGrouped := False;
  DocumentModified := True;
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
Begin
 Shape.ShapeType := stNone;
 Shape.X1 := 0;
 Shape.Y1 := 0;
 Shape.X2 := 0;
 Shape.Y2 := 0;
 Shape.FillColor := White;
 Shape.LineColor := Black;
 Shape.LineWidth := 1;
 Shape.Text := '';
 Shape.Selected := False;
End;

{ Procédure pour dessiner un objet unique }
Procedure DrawShape(Var Shape: TShapeObject);
Var
 CenterX, CenterY, RadiusX, RadiusY: Integer;
Begin
 If Shape.ShapeType = stNone Then Exit;
 
 { Définir la couleur de contour }
 SetColor(Shape.LineColor);
 SetLineStyle(SolidLn, 0, Shape.LineWidth);
 
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
    SetFillStyle(SolidFill, Shape.FillColor);
    FillEllipse(Shape.X1, Shape.Y1, 4, 4);
    FillEllipse(Shape.X2, Shape.Y2, 4, 4);
    SetColor(Shape.LineColor);
    Circle(Shape.X1, Shape.Y1, 4);
    Circle(Shape.X2, Shape.Y2, 4);
   End;
  stText: Begin
    SetColor(Shape.LineColor);
    OutTextXY(Shape.X1, Shape.Y1, Shape.Text);
   End;
 End;
 
 { Dessiner les poignées de sélection si l'objet est sélectionné }
 If Shape.Selected Then Begin
  SetFillStyle(SolidFill, Blue);
  SetColor(White);
  { Coin supérieur gauche }
  Bar(Shape.X1 - SELECTION_HANDLE_SIZE div 2, Shape.Y1 - SELECTION_HANDLE_SIZE div 2,
      Shape.X1 + SELECTION_HANDLE_SIZE div 2, Shape.Y1 + SELECTION_HANDLE_SIZE div 2);
  Rectangle(Shape.X1 - SELECTION_HANDLE_SIZE div 2, Shape.Y1 - SELECTION_HANDLE_SIZE div 2,
            Shape.X1 + SELECTION_HANDLE_SIZE div 2, Shape.Y1 + SELECTION_HANDLE_SIZE div 2);
  { Coin supérieur droit }
  Bar(Shape.X2 - SELECTION_HANDLE_SIZE div 2, Shape.Y1 - SELECTION_HANDLE_SIZE div 2,
      Shape.X2 + SELECTION_HANDLE_SIZE div 2, Shape.Y1 + SELECTION_HANDLE_SIZE div 2);
  Rectangle(Shape.X2 - SELECTION_HANDLE_SIZE div 2, Shape.Y1 - SELECTION_HANDLE_SIZE div 2,
            Shape.X2 + SELECTION_HANDLE_SIZE div 2, Shape.Y1 + SELECTION_HANDLE_SIZE div 2);
  { Coin inférieur gauche }
  Bar(Shape.X1 - SELECTION_HANDLE_SIZE div 2, Shape.Y2 - SELECTION_HANDLE_SIZE div 2,
      Shape.X1 + SELECTION_HANDLE_SIZE div 2, Shape.Y2 + SELECTION_HANDLE_SIZE div 2);
  Rectangle(Shape.X1 - SELECTION_HANDLE_SIZE div 2, Shape.Y2 - SELECTION_HANDLE_SIZE div 2,
            Shape.X1 + SELECTION_HANDLE_SIZE div 2, Shape.Y2 + SELECTION_HANDLE_SIZE div 2);
  { Coin inférieur droit }
  Bar(Shape.X2 - SELECTION_HANDLE_SIZE div 2, Shape.Y2 - SELECTION_HANDLE_SIZE div 2,
      Shape.X2 + SELECTION_HANDLE_SIZE div 2, Shape.Y2 + SELECTION_HANDLE_SIZE div 2);
  Rectangle(Shape.X2 - SELECTION_HANDLE_SIZE div 2, Shape.Y2 - SELECTION_HANDLE_SIZE div 2,
            Shape.X2 + SELECTION_HANDLE_SIZE div 2, Shape.Y2 + SELECTION_HANDLE_SIZE div 2);
 End;
End;

{ Procédure pour dessiner tous les objets }
Procedure DrawAllShapes;
Var
 I: Integer;
Begin
 For I := 1 to ShapeCount do Begin
  DrawShape(Shapes[I]);
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
  If PointInShape(X, Y, Shapes[I]) Then Begin
   GetShapeAtPosition := I;
   Exit;
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
  Shapes[Index].Selected := True;
  SelectedShape := Index;
 End;
End;

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
 
 DocumentModified := True;
End;

{ Procédure pour gérer le clic gauche de la souris }
Procedure HandleLeftClick(X, Y: Integer);
Var
 ShapeIndex: Integer;
 ToolIndex: Integer;
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
     { Mode sélection: chercher un objet sous le curseur }
     ShapeIndex := GetShapeAtPosition(X, Y);
     If ShapeIndex > 0 Then Begin
      SelectShape(ShapeIndex);
     End
     Else Begin
      DeselectAllShapes;
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
  End;
 End;
End;

{ Procédure pour gérer le relâchement du bouton gauche }
Procedure HandleLeftRelease(X, Y: Integer);
Var
 ShapeType: TShapeType;
Begin
 If Not IsDrawing Then Exit;
 
 IsDrawing := False;
 
 { Créer la forme selon l'outil actuel }
 Case CurrentTool of
  ttRectangle: ShapeType := stRectangle;
  ttEllipse: ShapeType := stEllipse;
  ttLine: ShapeType := stLine;
  ttConnector: ShapeType := stConnector;
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
 For I := 1 to MAX_SHAPES do Begin
  InitShape(Shapes[I]);
 End;
End;

{ ============================================================================ }
{ === FIN DES PROCEDURES DE GESTION DES OBJETS === }
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
 CurrentTextSize := DEFAULT_TEXT_SIZE;
 CurrentAlignment := atLeft;
 ObjectsGrouped := False;
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
  6: InsertLayer;      { Layer }
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
End;

BEGIN
 InitializeGraphics;
 InitMenuSystem;
 InitShapes;
 
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
   
   { Détecter un clic gauche (bouton 1) }
   If (LastMouseButton and 1) = 1 Then Begin
    HideMouse;
    HandleLeftClick(LastMouseX, LastMouseY);
    RefreshScreen;
    ShowMouse;
    { Attendre que le bouton soit relâché }
    Repeat
     {$IFDEF FPC}
      GetMouseState(LastMouseX, LastMouseY, LastMouseButton);
     {$ELSE}
      GetMouseState(LastMouseX, LastMouseY, LastMouseButton);
     {$ENDIF}
    Until (LastMouseButton and 1) = 0;
    { Gérer le relâchement du bouton }
    HideMouse;
    HandleLeftRelease(LastMouseX, LastMouseY);
    RefreshScreen;
    ShowMouse;
   End;
  End;
 
  { Attendre une entrée clavier }
  If KeyPressed Then Begin
   Case ReadKey of
    #27: Break; { Escape pour quitter }
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