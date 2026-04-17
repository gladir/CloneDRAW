{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application Visio de Microsoft
}

{ TODO: Liste de 25 points pour un clone complet de Visio

  === MENUS ET INTERFACE ===
  1. Implementer le menu principal avec File, Edit, View, Insert, Format, Shape, Tools, Window, Help
  2. Ajouter le menu File avec New, Open, Close, Save, Save As, Export, Print, Print Preview, Exit
  3. Ajouter le menu Edit avec Undo, Redo, Cut, Copy, Paste, Delete, Select All, Find, Replace
  4. Ajouter le menu View avec Zoom In, Zoom Out, Fit Page, Grid, Rulers, Guides, Snap to Grid
  5. Ajouter le menu Insert avec Shape, Text Box, Image, Connector, Page, Layer
  6. Ajouter le menu Format avec Fill, Line, Text, Alignment, Arrange, Group, Ungroup
  7. Ajouter le menu Shape avec Rotate, Flip, Align, Distribute, Size, Position, Operations (Union, Intersect, Subtract)
  8. Implementer la barre d'outils avec boutons pour les actions frequentes (Selection, Rectangle, Ellipse, Ligne, Connecteur, Texte)

  === SUPPORT SOURIS ===
  9. Gerer les evenements de clic gauche pour selection et dessin d'objets
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

BEGIN
 InitializeGraphics;
END.