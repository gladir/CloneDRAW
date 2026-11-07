{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/office-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application SolderRun (SOLDERRUN-BPM) : editeur
                de diagrammes de flux de donnees (DFD) hierarchiques.
}

{ Liste de points implementes :
  ---------------------------------------------------------------------------
   1. Interface graphique style Windows : barre de titre, menus deroulants
      avec sous-menus (File, Edit, Display, Model, Project, Tools, Window,
      Help), barre d'outils, palette flottante d'outils, fenetre de diagramme
      (MDI) avec cadre "Context", barres de defilement et barre d'etat
   2. Souris et clavier : Alt+lettre, F10, fleches, Entree, Echap
   3. Objets DFD : processus (numero, nom, ressource), magasins (S-n),
      entites externes, flux (nom, qualifiant, point de pliage), textes
   4. Decomposition hierarchique : ouvrir/creer le diagramme enfant d'un
      processus, remonter au parent, numerotation 1, 1.1, 1.1.1 ...
   5. Edition : annuler/refaire, couper/copier/coller/dupliquer/effacer,
      tout selectionner, selectionner par nom, aller au diagramme
   6. Affichage : zoom, ajuster, taille du dessin, alignement, premier plan,
      arriere-plan, masquer/afficher, surlignage, redresser les flux,
      inverser le sens d'un flux, libelles et qualifiants
   7. Modele : listes des processus, flux, magasins, entites, ressources,
      qualifiants, diagrammes, description du modele, champs utilisateur
   8. Projet : dictionnaires (domaines, types, elements communs, structures,
      systemes cibles, concepts etendus) et description du projet
   9. Outils : verification d'integrite, nettoyage, generation de rapports,
      fusion, scission, arbre des processus, parent du processus racine,
      mise a jour de l'environnement, renumerotation, options
  10. Interface MDI : plusieurs modeles ouverts en meme temps (4 au maximum),
      chacun avec ses fenetres de diagrammes, son fichier, son historique
      d'annulation ; cascade, mosaique, fermer tout, icones
  11. Fichiers : lecture des fichiers .DFD de SolderRun (versions 3.1 et
      2.2.4 : processus, hierarchie, entites, magasins, flux, positions
      des processus), enregistrement/lecture au format natif .SRD, export
      SVG / CSV, import de processus (texte), rapport, impression texte
  12. Langues : francais par defaut, LANGUAGE=EN (anglais), LANGUAGE=GR
      (allemand), LANGUAGE=SP (espagnol), LANGUAGE=IT (italien)
}

{$IFDEF FPC}
 {$MODE TP}
 {$PACKRECORDS 1}
 {$Q-}
 {$R-}
 {$V-}
{$ELSE}
 {$M 32768,0,655360}
 {$R-,S-,I-,Q-,V-}
{$ENDIF}

Program SR;

Uses {$IFDEF FPC}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

{ ====================================================================== }
{                              CONSTANTES                                }
{ ====================================================================== }

Const
 SCR_W        = 640;
 SCR_H        = 480;
 TITLE_H      = 18;
 MENU_Y       = 18;
 MENU_H       = 18;
 TOOL_Y       = 36;
 TOOL_H       = 28;
 STAT_H       = 16;
 NMENU        = 8;            { menus principaux }
 NMTOT        = 15;           { menus principaux + sous-menus }
 MAXITEM      = 20;

 { Couleurs VGA }
 cBlk=0; cNavy=1; cGrn=2; cCyn=3; cRed=4; cMag=5; cBrn=6; cLGr=7;
 cDGr=8; cLBl=9; cLGn=10; cLCy=11; cLRd=12; cLMg=13; cYel=14; cWht=15;

 { Codes de touches : caractere = ord ; etendue = 256 + code }
 K_ESC    = 27;
 K_ENTER  = 13;
 K_BKSP   = 8;
 K_TAB    = 9;
 K_UP     = 328;
 K_DOWN   = 336;
 K_LEFT   = 331;
 K_RIGHT  = 333;
 K_HOME   = 327;
 K_END    = 335;
 K_PGUP   = 329;
 K_PGDN   = 337;
 K_INS    = 338;
 K_DEL    = 339;
 K_F1     = 315;
 K_F2     = 316;
 K_F10    = 324;
 K_STAB   = 271;
 K_CF4    = 353;

 { Limites des donnees }
 MAXEL    = 130;
 MAXFL    = 180;
 MAXDG    = 50;
 MAXWIN   = 12;
 MAXDOC   = 4;
 MAXDE    = 40;
 NCAT     = 12;
 UNDOMAX  = 6;
 CBMAX    = 40;
 CBFMAX   = 60;
 MAXTL    = 400;

 { Genres d'objets }
 ekProc=1; ekStore=2; ekEnt=3; ekText=4; ekInfo=5; ekRect=6; ekRRect=7;
 ekEll=8; ekLine=9;

 { Outils de la palette }
 tlSelect=1; tlProc=2; tlEnt=3; tlStore=4; tlFlow=5; tlText=6;
 tlQual=7; tlRes=8; tlRect=9; tlRRect=10; tlEll=11; tlLineA=12; tlLineB=13;
 tlLineC=14; tlFuse=15; tlMove=16; tlNote=17;

 { Categories des dictionnaires }
 dcRes=1; dcQual=2; dcDom=3; dcType=4; dcComm=5; dcStruct=6; dcTarget=7;
 dcRule=8; dcEvent=9; dcLoc=10; dcCarac=11; dcCorr=12;

 { Commandes }
 cmNew=101; cmOpen=102; cmClose=103; cmSave=104; cmSaveAs=105; cmPass=106;
 cmImpExp=107; cmReport=108; cmPageSetup=109; cmPrint=110; cmExit=111;
 cmUndo=120; cmRedo=121; cmCut=122; cmCopy=123; cmPaste=124; cmClear=125;
 cmDup=126; cmSelAll=127; cmSelect=128; cmGoto=129;
 cmToolbars=140; cmStraight=141; cmChgDir=142; cmFit=143; cmRestore=144;
 cmResize=145; cmHide=146; cmHilite=147; cmUnHilite=148; cmFont=149;
 cmDrawSize=150;
 cmLabName=151; cmLabQual=152; cmLabNum=153; cmLabRes=154;
 cmShowAll=155; cmFront=157; cmBack=158;
 cmZoom25=160; cmZoom50=161; cmZoom75=162; cmZoom100=163; cmZoom150=164;
 cmZoom200=165; cmZoomIn=166; cmZoomOut=167;
 cmAlL=170; cmAlR=171; cmAlT=172; cmAlB=173; cmAlH=174; cmAlV=175;
 cmMProc=180; cmMFlow=181; cmMStore=182; cmMEnt=183; cmMRes=184;
 cmMQual=185; cmMDiag=186; cmMDesc=187; cmMUdf=188;
 cmPDom=190; cmPType=191; cmPComm=192; cmPStruct=193; cmPTarget=194;
 cmPRule=195; cmPEvent=196; cmPLoc=197; cmPDesc=198;
 cmVerify=200; cmCleanup=201; cmGenList=203; cmGenTree=204; cmGenDict=205;
 cmMerge=206; cmSplit=207; cmTree=208; cmTreeUpd=209; cmParent=210;
 cmEnv=211; cmEnvFlow=212; cmRenum=213; cmWRM=214; cmOptions=216;
 cmAddIns=217;
 cmCascade=230; cmTileH=231; cmTileV=232; cmCloseAll=233; cmArrange=234;
 cmWin1=280;
 cmHelp=250; cmGuide=251; cmRelNotes=252; cmLicenses=253; cmAbout=254;
 cmProps=260; cmDecomp=261; cmParentUp=262; cmEnvUp=263; cmRename=264;
 cmCenter=265; cmNextObj=266; cmNote=267; cmFuse=268; cmMove=269;
 cmFitObj=300; cmLabShow=301; cmLabPlace=302; cmZoomNorm=303; cmZoomPan=304;
 cmGenCode=305; cmGenItems=306; cmGenHtml=307; cmGenTpl=308; cmPalettes=309;
 cmCtx=310; cmFlowSty0=311; cmFlowSty1=312; cmFlowSty2=313; cmFlowDash=314;
 cmRecent1=320; cmGuide2=330; cmGuide3=331; cmSelComp=332; cmShowSel=333;
 cmRenumAuto=334; cmRenumSel=335; cmEpurer=336; cmCompl=337;

{ ====================================================================== }
{                                TYPES                                   }
{ ====================================================================== }

Type
 TElem = Record
  Used: Boolean;
  Kind: Byte;
  Id: Integer;
  Diag: Integer;
  X,Y,W,H: Integer;
  Z: Integer;
  Num: String[12];
  Name: String[40];
  Desc: String[40];
  Res: Integer;
  Child: Integer;
  Hid,Hi,Sel: Boolean;
  FS: Byte;
  U1,U2,U3: String[10];
  Qual,Str: Integer;
  Col,Fil: Byte;
  Code: String[20];
  Note: String[60];
 End;

 TFlow = Record
  Used: Boolean;
  Diag: Integer;
  A,B: Integer;                 { identifiants d'elements }
  Name: String[30];
  Desc: String[40];
  Qual: Integer;
  Bend: Boolean;
  BX,BY: Integer;
  Sel,Hid,Hi: Boolean;
  Num: String[8];
  Str: Integer;
  Col,Dir,Sty,Dsh: Byte;
  LOX,LOY: Integer;
 End;

 TDiag = Record
  Used: Boolean;
  Parent: Integer;              { identifiant du processus parent, 0 = racine }
  Title: String[40];
  W,H: Integer;
  NP: Integer;                  { prochain numero de processus }
 End;

 TModel = Record
  El: Array[1..MAXEL] Of TElem;
  Fl: Array[1..MAXFL] Of TFlow;
  Dg: Array[1..MAXDG] Of TDiag;
  NextId,NextZ: Integer;
  NS,NE,NF,NT: Integer;
 End;
 PModel = ^TModel;

 TDEntry = Record
  Name: String[20];
  Desc: String[44];
 End;
 TDict = Array[1..NCAT,1..MAXDE] Of TDEntry;
 PDict = ^TDict;

 TCfg = Record
  ProjName,Author: String[40];
  Desc1,Desc2: String[60];
  Ver: String[10];
  MName: String[40];
  MDesc: String[60];
  UdfN: Array[1..3] Of String[16];
  Pass: String[12];
  Grid: Integer;
  Snap,ShowGrid: Boolean;
  ShName,ShQual,ShNum,ShRes: Boolean;
  Landscape: Boolean;
  Margin: Integer;
  WRM,AutoOpen,AutoFit: Boolean;
  DefSty: Byte;
  Created,Modified: String[10];
  PW,PH: Integer;
  Notation: Byte;
  ZDesc: Array[1..3] Of Byte;
  ZJus: Array[1..3] Of Byte;
 End;

 TWin = Record
  Used: Boolean;
  Doc: Integer;
  Diag,Zoom: Integer;
  SX,SY: LongInt;
  X,Y,W,H: Integer;
  Iconic: Boolean;
 End;

 TDoc = Record
  Used: Boolean;
  M: PModel;
  D: PDict;
  Cfg: TCfg;
  US,RS: Array[1..UNDOMAX] Of PModel;
  UN,RN: Integer;
  FileN: String[79];
  Named,Modified,FromDFD,TreeOpen: Boolean;
 End;

 TEvent = Record
  { 0 rien, 1 touche, 2 bouton gauche bas, 3 bouton gauche haut,
    4 mouvement, 5 bouton droit bas }
  Kind : Byte;
  Key  : Word;
  X,Y,B: LongInt;
 End;

 TCBEl = Array[1..CBMAX] Of TElem;
 PCBEl = ^TCBEl;
 TCBFl = Array[1..CBFMAX] Of TFlow;
 PCBFl = ^TCBFl;

 TTL = Array[1..MAXTL] Of String[78];
 PTL = ^TTL;

 TForm = Record
  Title: String[44];
  N: Integer;
  Lbl: Array[1..10] Of String[28];
  Kind: Array[1..10] Of Byte;     { 0 texte, 1 nombre, 2 case, 3 dico, 4 choix }
  Val: Array[1..10] Of String[70];
  Opt: Array[1..10] Of String[70];
  Len: Array[1..10] Of Byte;
  Info: String[70];
 End;

{ ====================================================================== }
{                              VARIABLES                                 }
{ ====================================================================== }

Var
 Lang      : Integer;                 { 1 fr, 2 en, 3 de, 4 es, 5 it }
 Mdl       : PModel;
 Dict      : PDict;
 Cfg       : TCfg;
 UStk,RStk : Array[1..UNDOMAX] Of PModel;
 UN,RN     : Integer;
 CBEl      : PCBEl;
 CBFl      : PCBFl;
 CBN,CBFN  : Integer;
 TL        : PTL;
 TLN       : Integer;
 FileN     : String[79];
 Named,Modified,FromDFD : Boolean;
 Quit      : Boolean;
 Docs      : Array[1..MAXDOC] Of TDoc;
 CurDoc    : Integer;
 Wn        : Array[1..MAXWIN] Of TWin;
 WZo      : Array[1..MAXWIN] Of Integer;   { ordre : dernier = actif }
 WCnt      : Integer;
 WMax      : Boolean;
 ToolBarOn,ToolBoxOn,StatusOn : Boolean;
 TbX,TbY   : Integer;
 CurTool   : Integer;
 StatMsg   : String[78];
 TreeOpen  : Boolean;

 MX,MY,MB,LastB : LongInt;
 PrevMX,PrevMY  : LongInt;
 LastClickT,LastClickX,LastClickY : LongInt;
 MenuOpen,MenuHi,SubOpen,SubHi : Integer;
 Dirty     : Boolean;

{ ====================================================================== }
{                  GRAPHIQUE / SOURIS (squelette)                        }
{ ====================================================================== }

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
  { Pas d'implementation pour Free Pascal }
 End;

 Procedure HideMouse;
 Begin
  { Pas d'implementation pour Free Pascal }
 End;
{$ENDIF}

{ ====================================================================== }
{                  LANGUE (FR defaut, EN, GR, SP, IT)                    }
{ ====================================================================== }

{ Codes d'accents dans les chaines sources : @e=e aigu @g=e grave @c=e circ.
  @a=a grave @q=a circ. @i=i circ. @y=i trema @o=o circ. @u=u grave
  @w=u circ. @k=c cedille @t=e trema @E=E aigu @1=ae @2=oe @3=ue @4=Ae
  @5=Oe @6=Ue @7=sz @r=a aigu @j=i aigu @p=o aigu @v=u aigu @n=n tilde
  @?=point d'interrogation inverse @!=exclamation inverse @l=i grave
  @m=o grave @@=arobase }
Function Dc(Const S: String): String;
Var I: Integer; R: String; C: Char;
Begin
 R:='';I:=1;
 While I<=Length(S) Do Begin
  If (S[I]='@') And (I<Length(S)) Then Begin
   C:=S[I+1];
   Case C Of
    'e': R:=R+#130;
    'E': R:=R+#144;
    'g': R:=R+#138;
    'c': R:=R+#136;
    'a': R:=R+#133;
    'q': R:=R+#131;
    'i': R:=R+#140;
    'y': R:=R+#139;
    'o': R:=R+#147;
    'u': R:=R+#151;
    'w': R:=R+#150;
    'k': R:=R+#135;
    't': R:=R+#137;
    '1': R:=R+#132;
    '2': R:=R+#148;
    '3': R:=R+#129;
    '4': R:=R+#142;
    '5': R:=R+#153;
    '6': R:=R+#154;
    '7': R:=R+#225;
    'r': If Lang=5 Then R:=R+#133 Else R:=R+#160;
    'j': If Lang=5 Then R:=R+#141 Else R:=R+#161;
    'p': R:=R+#162;
    'v': R:=R+#163;
    'n': R:=R+#164;
    '?': R:=R+#168;
    '!': R:=R+#173;
    'l': R:=R+#141;
    'm': R:=R+#149;
    '@': R:=R+'@';
    Else R:=R+'@'+C;
   End;
   Inc(I,2);
  End Else Begin
   R:=R+S[I];Inc(I);
  End;
 End;
 Dc:=R;
End;

Function T5(Const F,E,G,S,I: String): String;
Begin
 Case Lang Of
  2: T5:=Dc(E);
  3: T5:=Dc(G);
  4: T5:=Dc(S);
  5: T5:=Dc(I);
  Else T5:=Dc(F);
 End;
End;

Function Upper(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 Upper:=S;
End;

Procedure DetectLanguage;
Var S: String;
Begin
 S:=Upper(GetEnv('LANGUAGE'));
 Lang:=1;
 If Copy(S,1,2)='EN' Then Lang:=2;
 If (Copy(S,1,2)='GR') Or (Copy(S,1,2)='DE') Then Lang:=3;
 If (Copy(S,1,2)='SP') Or (Copy(S,1,2)='ES') Then Lang:=4;
 If Copy(S,1,2)='IT' Then Lang:=5;
End;

{ ====================================================================== }
{                       UTILITAIRES GENERAUX                             }
{ ====================================================================== }

Function IntStr(N: LongInt): String;
Var S: String;
Begin
 Str(N,S);
 IntStr:=S;
End;

Function TrimStr(S: String): String;
Begin
 While (Length(S)>0) And (S[1]=' ') Do Delete(S,1,1);
 While (Length(S)>0) And (S[Length(S)]=' ') Do Delete(S,Length(S),1);
 TrimStr:=S;
End;

Function Min2(A,B: LongInt): LongInt;
Begin
 If A<B Then Min2:=A Else Min2:=B;
End;

Function Max2(A,B: LongInt): LongInt;
Begin
 If A>B Then Max2:=A Else Max2:=B;
End;

Function ValInt(Const S: String; Def: LongInt): LongInt;
Var V: LongInt; Code: Integer; T: String;
Begin
 T:=TrimStr(S);
 Val(T,V,Code);
 If (Code<>0) Or (T='') Then ValInt:=Def Else ValInt:=V;
End;

Function Tick: LongInt;
Var H,M,S,S100: Word;
Begin
 GetTime(H,M,S,S100);
 Tick:=((H*60+M)*60+S)*100+S100;
End;

Function FileExists(Const N: String): Boolean;
Var F: File;
Begin
 {$I-}
 Assign(F,N);
 Reset(F,1);
 {$I+}
 If IOResult=0 Then Begin
  Close(F);
  FileExists:=True;
 End Else FileExists:=False;
End;

Function ShortName(Const N: String): String;
Var I: Integer; S: String;
Begin
 S:=N;
 For I:=Length(S) DownTo 1 Do
  If (S[I]='\') Or (S[I]='/') Or (S[I]=':') Then Begin
   ShortName:=Copy(S,I+1,80);Exit;
  End;
 ShortName:=S;
End;

Function HasExt(Const N: String): Boolean;
Var I: Integer;
Begin
 HasExt:=False;
 For I:=Length(N) DownTo 1 Do Begin
  If (N[I]='\') Or (N[I]='/') Then Exit;
  If N[I]='.' Then Begin HasExt:=True;Exit;End;
 End;
End;

Function AddExt(Const N,Ext: String): String;
Begin
 If HasExt(N) Then AddExt:=N Else AddExt:=N+'.'+Ext;
End;

Function ChangeExt(Const N,Ext: String): String;
Var I: Integer;
Begin
 For I:=Length(N) DownTo 1 Do Begin
  If (N[I]='\') Or (N[I]='/') Then Begin ChangeExt:=N+'.'+Ext;Exit;End;
  If N[I]='.' Then Begin ChangeExt:=Copy(N,1,I-1)+'.'+Ext;Exit;End;
 End;
 ChangeExt:=N+'.'+Ext;
End;

Function Pad(Const S: String; N: Integer): String;
Var R: String;
Begin
 R:=S;
 While Length(R)<N Do R:=R+' ';
 Pad:=Copy(R,1,N);
End;

Function ExtOf(Const N: String): String;
Var I: Integer;
Begin
 ExtOf:='';
 For I:=Length(N) DownTo 1 Do Begin
  If (N[I]='\') Or (N[I]='/') Then Exit;
  If N[I]='.' Then Begin ExtOf:=Upper(Copy(N,I+1,5));Exit;End;
 End;
End;

{ ====================================================================== }
{                  MODELE : OBJETS, SELECTION, ANNULATION                }
{ ====================================================================== }

Procedure FixWindows; Forward;
Procedure DrawAll; Forward;

Procedure AllocData;
Var I: Integer;
Begin
 New(CBEl);New(CBFl);New(TL);
 Mdl:=Nil;Dict:=Nil;CurDoc:=0;
 For I:=1 To MAXDOC Do Docs[I].Used:=False;
 For I:=1 To UNDOMAX Do Begin UStk[I]:=Nil;RStk[I]:=Nil;End;
 UN:=0;RN:=0;CBN:=0;CBFN:=0;TLN:=0;
End;

Function FindEl(Id: Integer): Integer;
Var I: Integer;
Begin
 FindEl:=0;
 If Id<=0 Then Exit;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Id=Id) Then Begin FindEl:=I;Exit;End;
End;

Function ElName(I: Integer): String;
Begin
 If Mdl^.El[I].Name<>'' Then ElName:=Mdl^.El[I].Name Else
   ElName:=Mdl^.El[I].Num;
End;

Function DictName(Cat,I: Integer): String;
Begin
 If (I>=1) And (I<=MAXDE) Then DictName:=Dict^[Cat,I].Name Else DictName:='';
End;

Function DictLabel(Cat,I: Integer): String;
Begin
 If (I>=1) And (I<=MAXDE) Then Begin
  If Dict^[Cat,I].Desc<>'' Then DictLabel:=Dict^[Cat,I].Desc
  Else DictLabel:=Dict^[Cat,I].Name;
 End Else DictLabel:='';
End;

Function DiagCount: Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To MAXDG Do If Mdl^.Dg[I].Used Then Inc(N);
 DiagCount:=N;
End;

Function RootDiag: Integer;
Var I: Integer;
Begin
 RootDiag:=0;
 For I:=1 To MAXDG Do
  If Mdl^.Dg[I].Used And (Mdl^.Dg[I].Parent=0) Then Begin RootDiag:=I;Exit;End;
End;

Function NewDiag(Parent: Integer; Const Title: String): Integer;
Var I: Integer;
Begin
 NewDiag:=0;
 For I:=1 To MAXDG Do
  If Not Mdl^.Dg[I].Used Then Begin
   FillChar(Mdl^.Dg[I],SizeOf(TDiag),0);
   Mdl^.Dg[I].Used:=True;
   Mdl^.Dg[I].Parent:=Parent;
   Mdl^.Dg[I].Title:=Title;
   Mdl^.Dg[I].W:=720;
   Mdl^.Dg[I].H:=480;
   Mdl^.Dg[I].NP:=1;
   NewDiag:=I;
   Exit;
  End;
End;

Function ProcNum(D: Integer): String;
Var P: Integer; S: String;
Begin
 P:=FindEl(Mdl^.Dg[D].Parent);
 S:=IntStr(Mdl^.Dg[D].NP);
 If P>0 Then S:=Mdl^.El[P].Num+'.'+S;
 Inc(Mdl^.Dg[D].NP);
 ProcNum:=S;
End;

Function NewEl(Kind,Diag,X,Y: Integer): Integer;
Var I: Integer;
Begin
 NewEl:=0;
 For I:=1 To MAXEL Do
  If Not Mdl^.El[I].Used Then Begin
   FillChar(Mdl^.El[I],SizeOf(TElem),0);
   With Mdl^.El[I] Do Begin
    Used:=True;Kind:=Kind;Id:=Mdl^.NextId;Diag:=Diag;
    Z:=Mdl^.NextZ;FS:=1;
   End;
   Inc(Mdl^.NextId);Inc(Mdl^.NextZ);
   With Mdl^.El[I] Do Begin
    Kind:=Kind;
   End;
   Mdl^.El[I].Kind:=Kind;
   Mdl^.El[I].Diag:=Diag;
   Case Kind Of
    ekProc: Begin
      Mdl^.El[I].W:=Cfg.PW;Mdl^.El[I].H:=Cfg.PH;
      Mdl^.El[I].Num:=ProcNum(Diag);
     End;
    ekStore: Begin
      Mdl^.El[I].W:=150;Mdl^.El[I].H:=34;
      Inc(Mdl^.NS);
      Mdl^.El[I].Num:='S-'+IntStr(Mdl^.NS);
      Mdl^.El[I].Name:=Mdl^.El[I].Num;
     End;
    ekEnt: Begin
      Mdl^.El[I].W:=100;Mdl^.El[I].H:=44;
      Inc(Mdl^.NE);
      Mdl^.El[I].Num:='E-'+IntStr(Mdl^.NE);
      Mdl^.El[I].Name:=Mdl^.El[I].Num;
     End;
    ekText: Begin
      Mdl^.El[I].W:=90;Mdl^.El[I].H:=18;
      Mdl^.El[I].Name:=T5('Texte','Text','Text','Texto','Testo');
     End;
    ekInfo: Begin
      Mdl^.El[I].W:=260;Mdl^.El[I].H:=112;
     End;
    ekRect,ekRRect: Begin Mdl^.El[I].W:=120;Mdl^.El[I].H:=64;End;
    ekEll: Begin Mdl^.El[I].W:=110;Mdl^.El[I].H:=64;End;
    ekLine: Begin Mdl^.El[I].W:=120;Mdl^.El[I].H:=40;Mdl^.El[I].FS:=1;End;
   End;
   Mdl^.El[I].X:=X-Mdl^.El[I].W Div 2;
   Mdl^.El[I].Y:=Y-Mdl^.El[I].H Div 2;
   NewEl:=I;
   Exit;
  End;
End;

Function NewFl(Diag,A,B: Integer): Integer;
Var I: Integer;
Begin
 NewFl:=0;
 For I:=1 To MAXFL Do
  If Not Mdl^.Fl[I].Used Then Begin
   FillChar(Mdl^.Fl[I],SizeOf(TFlow),0);
   Mdl^.Fl[I].Used:=True;
   Mdl^.Fl[I].Diag:=Diag;
   Mdl^.Fl[I].A:=A;Mdl^.Fl[I].B:=B;
   Inc(Mdl^.NF);
   Mdl^.Fl[I].Num:='F-'+IntStr(Mdl^.NF);
   Mdl^.Fl[I].Sty:=Cfg.DefSty;
   NewFl:=I;
   Exit;
  End;
End;

Procedure DelDiag(D: Integer); Forward;

Procedure DelEl(I: Integer);
Var K,C: Integer; Id: Integer;
Begin
 If Not Mdl^.El[I].Used Then Exit;
 Id:=Mdl^.El[I].Id;
 For K:=1 To MAXFL Do
  If Mdl^.Fl[K].Used And ((Mdl^.Fl[K].A=Id) Or (Mdl^.Fl[K].B=Id)) Then
    Mdl^.Fl[K].Used:=False;
 C:=Mdl^.El[I].Child;
 Mdl^.El[I].Used:=False;
 If (C>0) And Mdl^.Dg[C].Used Then DelDiag(C);
End;

Procedure DelDiag(D: Integer);
Var K: Integer;
Begin
 If (D<1) Or Not Mdl^.Dg[D].Used Then Exit;
 Mdl^.Dg[D].Used:=False;
 For K:=1 To MAXEL Do
  If Mdl^.El[K].Used And (Mdl^.El[K].Diag=D) Then DelEl(K);
 For K:=1 To MAXFL Do
  If Mdl^.Fl[K].Used And (Mdl^.Fl[K].Diag=D) Then Mdl^.Fl[K].Used:=False;
 FixWindows;
End;

Function SelCount(D: Integer): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then Inc(N);
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And Mdl^.Fl[I].Sel And (Mdl^.Fl[I].Diag=D) Then Inc(N);
 SelCount:=N;
End;

Function SelElCount(D: Integer): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then Inc(N);
 SelElCount:=N;
End;

Function SelFlCount(D: Integer): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And Mdl^.Fl[I].Sel And (Mdl^.Fl[I].Diag=D) Then Inc(N);
 SelFlCount:=N;
End;

Procedure ClearSel;
Var I: Integer;
Begin
 For I:=1 To MAXEL Do Mdl^.El[I].Sel:=False;
 For I:=1 To MAXFL Do Mdl^.Fl[I].Sel:=False;
End;

Function HiddenCount(D: Integer): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Hid And (Mdl^.El[I].Diag=D) Then Inc(N);
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And Mdl^.Fl[I].Hid And (Mdl^.Fl[I].Diag=D) Then Inc(N);
 HiddenCount:=N;
End;

Function FlowOK(KA,KB: Integer): Boolean;
Begin
 FlowOK:=((KA=ekProc) And (KB<=ekEnt)) Or ((KB=ekProc) And (KA<=ekEnt));
End;

Function SnapV(V: LongInt): Integer;
Var G: Integer;
Begin
 G:=Cfg.Grid;
 If Cfg.Snap And (G>1) Then Begin
  If V>=0 Then SnapV:=((V+G Div 2) Div G)*G Else SnapV:=-(((-V+G Div 2) Div
    G)*G);
 End Else SnapV:=V;
End;

{ ---- annulation / retablissement ---- }

Function AllocSnap: PModel;
Var P: PModel;
Begin
 AllocSnap:=Nil;
 {$IFNDEF FPC}
 If MaxAvail<LongInt(SizeOf(TModel))+30000 Then Exit;
 {$ENDIF}
 New(P);
 AllocSnap:=P;
End;

Procedure ClearRedo;
Var I: Integer;
Begin
 For I:=1 To RN Do Begin
  If RStk[I]<>Nil Then Dispose(RStk[I]);
  RStk[I]:=Nil;
 End;
 RN:=0;
End;

Procedure PushUndo;
Var I: Integer; P: PModel;
Begin
 ClearRedo;
 P:=AllocSnap;
 If (P=Nil) And (UN>0) Then Begin
  Dispose(UStk[1]);
  For I:=1 To UN-1 Do UStk[I]:=UStk[I+1];
  UStk[UN]:=Nil;Dec(UN);
  P:=AllocSnap;
 End;
 If P=Nil Then Begin Modified:=True;Exit;End;
 If UN=UNDOMAX Then Begin
  Dispose(UStk[1]);
  For I:=1 To UN-1 Do UStk[I]:=UStk[I+1];
  Dec(UN);
 End;
 P^:=Mdl^;
 Inc(UN);UStk[UN]:=P;
 Modified:=True;
End;

Procedure DoUndo;
Var P: PModel;
Begin
 If UN=0 Then Exit;
 P:=AllocSnap;
 If P<>Nil Then Begin
  P^:=Mdl^;
  If RN<UNDOMAX Then Begin Inc(RN);RStk[RN]:=P;End Else Dispose(P);
 End;
 Mdl^:=UStk[UN]^;
 Dispose(UStk[UN]);UStk[UN]:=Nil;Dec(UN);
 Modified:=True;
 FixWindows;
End;

Procedure DoRedo;
Var P: PModel;
Begin
 If RN=0 Then Exit;
 P:=AllocSnap;
 If P<>Nil Then Begin
  P^:=Mdl^;
  If UN<UNDOMAX Then Begin Inc(UN);UStk[UN]:=P;End Else Dispose(P);
 End;
 Mdl^:=RStk[RN]^;
 Dispose(RStk[RN]);RStk[RN]:=Nil;Dec(RN);
 Modified:=True;
 FixWindows;
End;

Procedure FlushUndo;
Var I: Integer;
Begin
 For I:=1 To UN Do Begin
  If UStk[I]<>Nil Then Dispose(UStk[I]);
  UStk[I]:=Nil;
 End;
 UN:=0;
 ClearRedo;
End;

{ ---- numerotation ---- }

Procedure RenumDiag(D: Integer; Const Prefix: String);
Var Idx: Array[1..MAXEL] Of Integer; N,I,J,T,P: Integer; S: String;
Begin
 N:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].Kind=ekProc) Then
    Begin
   Inc(N);Idx[N]:=I;
  End;
 For I:=1 To N-1 Do
  For J:=I+1 To N Do
   If (Mdl^.El[Idx[J]].Y<Mdl^.El[Idx[I]].Y) Or
      ((Mdl^.El[Idx[J]].Y=Mdl^.El[Idx[I]].Y) And
       (Mdl^.El[Idx[J]].X<Mdl^.El[Idx[I]].X)) Then Begin
    T:=Idx[I];Idx[I]:=Idx[J];Idx[J]:=T;
   End;
 For I:=1 To N Do Begin
  S:=IntStr(I);
  If Prefix<>'' Then S:=Prefix+'.'+S;
  Mdl^.El[Idx[I]].Num:=S;
 End;
 Mdl^.Dg[D].NP:=N+1;
 For I:=1 To N Do Begin
  P:=Mdl^.El[Idx[I]].Child;
  If (P>0) And Mdl^.Dg[P].Used Then RenumDiag(P,Mdl^.El[Idx[I]].Num);
 End;
End;

Procedure RenumAll;
Var I: Integer;
Begin
 For I:=1 To MAXDG Do
  If Mdl^.Dg[I].Used And (Mdl^.Dg[I].Parent=0) Then RenumDiag(I,'');
End;

Function DiagTitle(D: Integer): String;
Begin
 If (D>=1) And (D<=MAXDG) And Mdl^.Dg[D].Used Then DiagTitle:=Mdl^.Dg[D].Title
 Else DiagTitle:='';
End;

{ ---- presse-papiers ---- }

Procedure CopySel(D: Integer);
Var I,J,K: Integer;
Begin
 CBN:=0;CBFN:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) And (CBN<CBMAX)
    Then Begin
   Inc(CBN);CBEl^[CBN]:=Mdl^.El[I];
   CBEl^[CBN].Child:=0;
  End;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) And (CBFN<CBFMAX) Then Begin
   J:=0;K:=0;
   For J:=1 To CBN Do Begin
    If CBEl^[J].Id=Mdl^.Fl[I].A Then K:=K+1;
    If CBEl^[J].Id=Mdl^.Fl[I].B Then K:=K+10;
   End;
   If K=11 Then Begin Inc(CBFN);CBFl^[CBFN]:=Mdl^.Fl[I];End;
  End;
End;

Procedure PasteCB(D,Off: Integer);
Var Map: Array[1..CBMAX] Of Integer; I,J,K,E,F: Integer;
Begin
 ClearSel;
 For I:=1 To CBN Do Begin
  E:=NewEl(CBEl^[I].Kind,D,0,0);
  Map[I]:=0;
  If E>0 Then Begin
   Map[I]:=Mdl^.El[E].Id;
   K:=Mdl^.El[E].Id;J:=Mdl^.El[E].Z;
   Mdl^.El[E]:=CBEl^[I];
   Mdl^.El[E].Id:=K;Mdl^.El[E].Z:=J;
   Mdl^.El[E].Diag:=D;Mdl^.El[E].Child:=0;
   Mdl^.El[E].X:=Mdl^.El[E].X+Off;Mdl^.El[E].Y:=Mdl^.El[E].Y+Off;
   Mdl^.El[E].Sel:=True;Mdl^.El[E].Hid:=False;
   If Mdl^.El[E].Kind=ekProc Then Mdl^.El[E].Num:=ProcNum(D);
  End;
 End;
 For I:=1 To CBFN Do Begin
  K:=0;J:=0;
  For E:=1 To CBN Do Begin
   If CBEl^[E].Id=CBFl^[I].A Then K:=Map[E];
   If CBEl^[E].Id=CBFl^[I].B Then J:=Map[E];
  End;
  If (K>0) And (J>0) Then Begin
   F:=NewFl(D,K,J);
   If F>0 Then Begin
    Mdl^.Fl[F].Name:=CBFl^[I].Name;Mdl^.Fl[F].Desc:=CBFl^[I].Desc;
    Mdl^.Fl[F].Qual:=CBFl^[I].Qual;
    Mdl^.Fl[F].Bend:=CBFl^[I].Bend;
    Mdl^.Fl[F].BX:=CBFl^[I].BX+Off;Mdl^.Fl[F].BY:=CBFl^[I].BY+Off;
    Mdl^.Fl[F].Sel:=True;
   End;
  End;
 End;
End;

{ ---- dictionnaires ---- }

Procedure AddQual(Const Code,Fr,En: String);
Var I: Integer;
Begin
 For I:=1 To MAXDE Do
  If Dict^[dcQual,I].Name='' Then Begin
   Dict^[dcQual,I].Name:=Code;
   Dict^[dcQual,I].Desc:=T5(Fr,En,En,En,En);
   Exit;
  End;
End;

Procedure DefaultDict;
Begin
 FillChar(Dict^,SizeOf(TDict),0);
 AddQual('ctrl','Contr@ole','Control');
 AddQual('info','Information','Information');
 AddQual('en','Energie','Energy');
 AddQual('mat','Mati@gre','Matter');
 AddQual('a verif','A v@erifier','To verify');
 AddQual('verif','V@erifi@e','Verified');
 AddQual('ref','Refus@e','Refused');
 AddQual('con','Controvers@e','Disputed');
 AddQual('air','Air','Air');
 AddQual('mer','Mer','Sea');
 AddQual('ter','Terre','Land');
 AddQual('t@el','T@el@ephone','Telephone');
 AddQual('cou','Courrier','Mail');
 AddQual('ora','Orale','Oral');
 AddQual('ecr','Ecrite','Written');
 AddQual('fax','Fax','Fax');
 AddQual('aud','Audit','Audit');
 AddQual('ver','V@erification','Verification');
 AddQual('test','Test','Test');
 AddQual('dec','D@ecision','Decision');
 AddQual('hom','Homme','Human');
 AddQual('homm','Homme-machine','Human-machine');
 AddQual('auto','Automatis@e','Automated');
 AddQual('on','Direct (on-line)','Direct (on-line)');
 AddQual('off','Diff@er@e','Deferred');
 AddQual('main','Mainframe','Mainframe');
 AddQual('stat','Station de travail','Workstation');
 AddQual('dis','Disque','Disk');
 AddQual('disk','Disquette','Diskette');
 AddQual('bnd','Bande','Tape');
 AddQual('arc','Archive','Archive');
 AddQual('cop','Copie de travail','Working copy');
End;

Function TodayStr: String;
Var Y,M,D,W: Word; A,B: String;
Begin
 GetDate(Y,M,D,W);
 A:=IntStr(M);If Length(A)<2 Then A:='0'+A;
 B:=IntStr(D);If Length(B)<2 Then B:='0'+B;
 If Lang=2 Then TodayStr:=A+'/'+B+'/'+IntStr(Y) Else
   TodayStr:=B+'/'+A+'/'+IntStr(Y);
End;

Procedure DefaultCfg;
Begin
 FillChar(Cfg,SizeOf(Cfg),0);
 Cfg.ProjName:='Projet1';
 Cfg.MName:='Model_1';
 Cfg.Created:=TodayStr;Cfg.Modified:=Cfg.Created;
 Cfg.PW:=120;Cfg.PH:=110;Cfg.Notation:=1;
 Cfg.ZDesc[1]:=2;Cfg.ZDesc[2]:=3;Cfg.ZDesc[3]:=5;
 Cfg.ZJus[1]:=2;Cfg.ZJus[2]:=2;Cfg.ZJus[3]:=2;
 Cfg.Grid:=10;Cfg.Snap:=True;Cfg.ShowGrid:=False;
 Cfg.ShName:=True;Cfg.ShQual:=True;Cfg.ShNum:=True;Cfg.ShRes:=True;
 Cfg.Landscape:=True;Cfg.Margin:=10;Cfg.AutoOpen:=True;
 Cfg.Ver:='1.0';
End;


{ ---- documents (modeles) multiples : MDI ---- }

Procedure SaveDoc;
Var I: Integer;
Begin
 If CurDoc<1 Then Exit;
 With Docs[CurDoc] Do Begin
  M:=Mdl;D:=Dict;
 End;
 Docs[CurDoc].Cfg:=Cfg;
 For I:=1 To UNDOMAX Do Begin
  Docs[CurDoc].US[I]:=UStk[I];Docs[CurDoc].RS[I]:=RStk[I];
 End;
 Docs[CurDoc].UN:=UN;Docs[CurDoc].RN:=RN;
 Docs[CurDoc].FileN:=FileN;Docs[CurDoc].Named:=Named;
 Docs[CurDoc].Modified:=Modified;Docs[CurDoc].FromDFD:=FromDFD;
 Docs[CurDoc].TreeOpen:=TreeOpen;
End;

Procedure LoadDocState(N: Integer);
Var I: Integer;
Begin
 CurDoc:=N;
 Mdl:=Docs[N].M;Dict:=Docs[N].D;Cfg:=Docs[N].Cfg;
 For I:=1 To UNDOMAX Do Begin UStk[I]:=Docs[N].US[I];RStk[I]:=Docs[N].RS[I];End;
 UN:=Docs[N].UN;RN:=Docs[N].RN;
 FileN:=Docs[N].FileN;Named:=Docs[N].Named;Modified:=Docs[N].Modified;
 FromDFD:=Docs[N].FromDFD;TreeOpen:=Docs[N].TreeOpen;
End;

Procedure SelectDoc(N: Integer);
Begin
 If (N<1) Or (N>MAXDOC) Or (N=CurDoc) Then Exit;
 If Not Docs[N].Used Then Exit;
 SaveDoc;
 LoadDocState(N);
End;

{ cree un document vide et le rend courant ; 0 si impossible }
Function NewDocSlot: Integer;
Var I,F: Integer;
Begin
 NewDocSlot:=0;
 F:=0;
 For I:=1 To MAXDOC Do If (F=0) And Not Docs[I].Used Then F:=I;
 If F=0 Then Exit;
 {$IFNDEF FPC}
 If MaxAvail<LongInt(SizeOf(TModel))+LongInt(SizeOf(TDict))+20000 Then Exit;
 {$ENDIF}
 SaveDoc;
 FillChar(Docs[F],SizeOf(TDoc),0);
 New(Docs[F].M);New(Docs[F].D);
 Docs[F].Used:=True;
 LoadDocState(F);
 NewDocSlot:=F;
End;

{ libere le document courant (ses fenetres doivent etre deja fermees) }
Procedure FreeCurDoc;
Begin
 If CurDoc<1 Then Exit;
 FlushUndo;
 Dispose(Mdl);Dispose(Dict);
 Docs[CurDoc].Used:=False;
 Mdl:=Nil;Dict:=Nil;CurDoc:=0;
End;

{ ---- fenetres ---- }

Procedure WinToFront(W: Integer);
Var I,P: Integer;
Begin
 P:=0;
 For I:=1 To WCnt Do If WZo[I]=W Then P:=I;
 If P=0 Then Exit;
 For I:=P To WCnt-1 Do WZo[I]:=WZo[I+1];
 WZo[WCnt]:=W;
 SelectDoc(Wn[W].Doc);
End;

Function ActiveWin: Integer;
Begin
 If WCnt>0 Then ActiveWin:=WZo[WCnt] Else ActiveWin:=0;
End;

Function CurDiag: Integer;
Var W: Integer;
Begin
 W:=ActiveWin;
 If W>0 Then CurDiag:=Wn[W].Diag Else CurDiag:=0;
End;

Function OpenWin(D: Integer): Integer;
Var I,F: Integer;
Begin
 OpenWin:=0;
 For I:=1 To MAXWIN Do
  If Wn[I].Used And (Wn[I].Diag=D) And (Wn[I].Doc=CurDoc) Then Begin
   Wn[I].Iconic:=False;
   WinToFront(I);OpenWin:=I;Exit;
  End;
 F:=0;
 For I:=1 To MAXWIN Do If (F=0) And Not Wn[I].Used Then F:=I;
 If F=0 Then Begin
  F:=ActiveWin;
  If F=0 Then Exit;
  Wn[F].Diag:=D;Wn[F].Doc:=CurDoc;
 End Else Begin
  FillChar(Wn[F],SizeOf(TWin),0);
  Wn[F].Used:=True;Wn[F].Diag:=D;Wn[F].Doc:=CurDoc;Wn[F].Zoom:=100;
  Wn[F].X:=20+(WCnt Mod 8)*20;Wn[F].Y:=10+(WCnt Mod 8)*20;Wn[F].W:=480;
    Wn[F].H:=300;
  Inc(WCnt);WZo[WCnt]:=F;
 End;
 Wn[F].SX:=0;Wn[F].SY:=0;Wn[F].Iconic:=False;
 WinToFront(F);
 OpenWin:=F;
End;

Procedure CloseWin(W: Integer);
Var I,P: Integer;
Begin
 If Not Wn[W].Used Then Exit;
 Wn[W].Used:=False;
 P:=0;
 For I:=1 To WCnt Do If WZo[I]=W Then P:=I;
 If P>0 Then Begin
  For I:=P To WCnt-1 Do WZo[I]:=WZo[I+1];
  Dec(WCnt);
 End;
End;

Procedure FixWindows;
Var I,K,Top: Integer;
Begin
 For I:=1 To MAXWIN Do
  If Wn[I].Used And (Wn[I].Doc=CurDoc) Then
   If (Wn[I].Diag<1) Or (Wn[I].Diag>MAXDG) Or
      Not Mdl^.Dg[Wn[I].Diag].Used Then CloseWin(I);
 K:=0;
 For I:=1 To MAXWIN Do If Wn[I].Used And (Wn[I].Doc=CurDoc) Then Inc(K);
 If (K=0) And (RootDiag>0) Then OpenWin(RootDiag);
 Top:=0;
 For I:=1 To WCnt Do If Wn[WZo[I]].Doc=CurDoc Then Top:=WZo[I];
 If Top>0 Then WinToFront(Top);
End;

{ ====================================================================== }
{                  PRIMITIVES DE DESSIN (style Windows)                  }
{ ====================================================================== }

Procedure Bx(X1,Y1,X2,Y2,C: Integer);
Begin
 If (X2<X1) Or (Y2<Y1) Then Exit;
 SetFillStyle(SolidFill,C);
 Bar(X1,Y1,X2,Y2);
End;

Procedure Ln(X1,Y1,X2,Y2,C: Integer);
Begin
 SetColor(C);
 SetLineStyle(SolidLn,0,1);
 Line(X1,Y1,X2,Y2);
End;

Procedure Frame(X1,Y1,X2,Y2,C: Integer);
Begin
 SetColor(C);
 SetLineStyle(SolidLn,0,1);
 Rectangle(X1,Y1,X2,Y2);
End;

Procedure Raised(X1,Y1,X2,Y2: Integer);
Begin
 Bx(X1,Y1,X2,Y2,cLGr);
 Ln(X1,Y1,X2-1,Y1,cWht);Ln(X1,Y1,X1,Y2-1,cWht);
 Ln(X1,Y2,X2,Y2,cBlk);Ln(X2,Y1,X2,Y2,cBlk);
 Ln(X1+1,Y2-1,X2-1,Y2-1,cDGr);Ln(X2-1,Y1+1,X2-1,Y2-1,cDGr);
End;

Procedure Sunken(X1,Y1,X2,Y2,C: Integer);
Begin
 Bx(X1,Y1,X2,Y2,C);
 Ln(X1,Y1,X2-1,Y1,cDGr);Ln(X1,Y1,X1,Y2-1,cDGr);
 Ln(X1+1,Y1+1,X2-2,Y1+1,cBlk);Ln(X1+1,Y1+1,X1+1,Y2-2,cBlk);
 Ln(X1,Y2,X2,Y2,cWht);Ln(X2,Y1,X2,Y2,cWht);
 Ln(X1+1,Y2-1,X2-1,Y2-1,cLGr);Ln(X2-1,Y1+1,X2-1,Y2-1,cLGr);
End;

Procedure Etched(X1,Y1,X2,Y2: Integer);
Begin
 SetLineStyle(SolidLn,0,1);
 SetColor(cDGr);Rectangle(X1,Y1,X2-1,Y2-1);
 SetColor(cWht);Rectangle(X1+1,Y1+1,X2,Y2);
End;

Procedure FocusRect(X1,Y1,X2,Y2: Integer);
Begin
 SetColor(cBlk);
 SetLineStyle(UserBitLn,$AAAA,1);
 Rectangle(X1,Y1,X2,Y2);
 SetLineStyle(SolidLn,0,1);
End;

Procedure Arw(CX,CY,Dir,C: Integer);
Var I: Integer;
Begin
 SetColor(C);
 SetLineStyle(SolidLn,0,1);
 Case Dir Of
  1: For I:=0 To 3 Do Line(CX-I,CY-2+I,CX+I,CY-2+I);
  2: For I:=0 To 3 Do Line(CX-I,CY+2-I,CX+I,CY+2-I);
  3: For I:=0 To 3 Do Line(CX-2+I,CY-I,CX-2+I,CY+I);
  4: For I:=0 To 3 Do Line(CX+2-I,CY-I,CX+2-I,CY+I);
 End;
End;

Procedure Tx(X,Y: Integer; Const S: String; C: Integer);
Begin
 SetColor(C);
 OutTextXY(X,Y,S);
End;

Procedure TxB(X,Y: Integer; Const S: String; C: Integer);
Begin
 SetColor(C);
 OutTextXY(X,Y,S);
 OutTextXY(X+1,Y,S);
End;

Procedure TxGray(X,Y: Integer; Const S: String);
Begin
 Tx(X+1,Y+1,S,cWht);
 Tx(X,Y,S,cDGr);
End;

Function TextW(Const S: String): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To Length(S) Do If S[I]<>'&' Then Inc(N);
 TextW:=N*8;
End;

{ Texte avec lettre soulignee : '&' precede la lettre }
Procedure UTx(X,Y: Integer; Const S: String; C: Integer);
Var I,P: Integer; Mark: Boolean;
Begin
 SetColor(C);
 P:=0;Mark:=False;
 For I:=1 To Length(S) Do Begin
  If (S[I]='&') And Not Mark Then Mark:=True
  Else Begin
   OutTextXY(X+P*8,Y,S[I]);
   If Mark Then Begin
    SetLineStyle(SolidLn,0,1);
    Line(X+P*8,Y+9,X+P*8+7,Y+9);
    Mark:=False;
   End;
   Inc(P);
  End;
 End;
End;

Function StripAmp(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:='';
 For I:=1 To Length(S) Do If S[I]<>'&' Then R:=R+S[I];
 StripAmp:=R;
End;

Function InBox(X,Y,X1,Y1,X2,Y2: LongInt): Boolean;
Begin
 InBox:=(X>=X1) And (X<=X2) And (Y>=Y1) And (Y<=Y2);
End;

Procedure CenterTx(X1,X2,Y: Integer; Const S: String; C: Integer);
Begin
 Tx(X1+((X2-X1+1)-Length(S)*8) Div 2,Y,S,C);
End;

Procedure Button(X1,Y1,X2,Y2: Integer; Const S: String; Foc,Ena: Boolean);
Var L: Integer;
Begin
 Raised(X1,Y1,X2,Y2);
 If Foc Then FocusRect(X1+3,Y1+3,X2-3,Y2-3);
 L:=TextW(S);
 If Ena Then UTx(X1+((X2-X1+1)-L) Div 2,Y1+((Y2-Y1)-7) Div 2,S,cBlk)
 Else Begin
  Tx(X1+((X2-X1+1)-L) Div 2+1,Y1+((Y2-Y1)-7) Div 2+1,StripAmp(S),cWht);
  Tx(X1+((X2-X1+1)-L) Div 2,Y1+((Y2-Y1)-7) Div 2,StripAmp(S),cDGr);
 End;
End;

{ ====================================================================== }
{                  EVENEMENTS (clavier / souris)                         }
{ ====================================================================== }

Procedure PollEvent(Var E: TEvent);
Var Ch: Char; K: Word;
Begin
 E.Kind:=0;E.Key:=0;E.X:=MX;E.Y:=MY;E.B:=MB;
 If KeyPressed Then Begin
  Ch:=ReadKey;
  If Ch=#0 Then K:=256+Ord(ReadKey) Else K:=Ord(Ch);
  E.Kind:=1;E.Key:=K;
  Exit;
 End;
 PrevMX:=MX;PrevMY:=MY;LastB:=MB;
 GetMouseState(MX,MY,MB);
 E.X:=MX;E.Y:=MY;E.B:=MB;
 If ((MB And 1)<>0) And ((LastB And 1)=0) Then E.Kind:=2
 Else If ((MB And 1)=0) And ((LastB And 1)<>0) Then E.Kind:=3
 Else If ((MB And 2)<>0) And ((LastB And 2)=0) Then E.Kind:=5
 Else If (MX<>PrevMX) Or (MY<>PrevMY) Then E.Kind:=4
 Else Delay(4);
End;

Function IsDouble(X,Y: LongInt): Boolean;
Var T: LongInt;
Begin
 T:=Tick;
 IsDouble:=(Abs(T-LastClickT)<45) And (Abs(X-LastClickX)<5)
     And (Abs(Y-LastClickY)<5);
 LastClickT:=T;LastClickX:=X;LastClickY:=Y;
End;

{ ====================================================================== }
{                        BOITES DE DIALOGUE                              }
{ ====================================================================== }

Procedure DlgFrame(X1,Y1,X2,Y2: Integer; Const Title: String);
Begin
 Raised(X1,Y1,X2,Y2);
 Bx(X1+3,Y1+3,X2-3,Y1+19,cLBl);
 TxB(X1+8,Y1+7,Title,cWht);
End;

Procedure FillMsgLines(Const Msg: String; Wd: Integer);
Var I,P: Integer; Cur,Wd2: String;
Begin
 TLN:=0;Cur:='';
 I:=1;
 While I<=Length(Msg) Do Begin
  If Msg[I]='~' Then Begin
   Inc(TLN);TL^[TLN]:=Cur;Cur:='';
  End Else Begin
   If (Length(Cur)>=Wd) And (Msg[I]=' ') Then Begin
    Inc(TLN);TL^[TLN]:=Cur;Cur:='';
   End Else Cur:=Cur+Msg[I];
  End;
  Inc(I);
 End;
 If (Cur<>'') Or (TLN=0) Then Begin Inc(TLN);TL^[TLN]:=Cur;End;
 If TLN>12 Then TLN:=12;
 P:=0;Wd2:='';
End;

{ Kind: 1 OK ; 2 OK/Annuler ; 3 Oui/Non/Annuler ; 4 Oui/Non
  Retour : 1 premier bouton (OK/Oui), 2 Non, 3 Annuler }
Function MsgBox(Const Msg: String; Kind: Integer): Integer;
Var X1,Y1,X2,Y2,W,H,NB,I,Foc,BX1,BW,BY: Integer;
    Lb: Array[1..3] Of String[16]; Ret: Array[1..3] Of Integer;
    E: TEvent; Done: Boolean; Res: Integer; Lines: Array[1..12] Of String[50];
    NL: Integer;
Begin
 FillMsgLines(Msg,32);
 NL:=TLN;
 For I:=1 To NL Do Lines[I]:=Copy(TL^[I],1,50);
 Case Kind Of
  1: Begin NB:=1;Lb[1]:='OK';Ret[1]:=1;End;
  2: Begin NB:=2;Lb[1]:='OK';Ret[1]:=1;
      Lb[2]:=T5('Annuler','Cancel','Abbrechen','Cancelar','Annulla');Ret[2]:=3;
        End;
  3: Begin NB:=3;Lb[1]:=T5('Oui','Yes','Ja','S@j','S@j');Ret[1]:=1;
      Lb[2]:='Non';Ret[2]:=2;
      Lb[3]:=T5('Annuler','Cancel','Abbrechen','Cancelar','Annulla');Ret[3]:=3;
      If Lang=3 Then Lb[2]:='Nein';If Lang=2 Then Lb[2]:='No';
 End;
  Else Begin NB:=2;Lb[1]:=T5('Oui','Yes','Ja','S@j','S@j');Ret[1]:=1;
      Lb[2]:='Non';Ret[2]:=2;
      If Lang=3 Then Lb[2]:='Nein';If Lang=2 Then Lb[2]:='No';End;
 End;
 W:=380;H:=60+NL*12+34;
 X1:=(SCR_W-W) Div 2;Y1:=(SCR_H-H) Div 2;X2:=X1+W-1;Y2:=Y1+H-1;
 BW:=84;BY:=Y2-30;
 BX1:=X1+(W-(NB*BW+(NB-1)*10)) Div 2;
 Foc:=1;Done:=False;Res:=Ret[NB];
 HideMouse;
 DlgFrame(X1,Y1,X2,Y2,'SOLDERRUN-BPM');
 For I:=1 To NL Do Tx(X1+20,Y1+34+(I-1)*12,Lines[I],cBlk);
 ShowMouse;
 Repeat
  HideMouse;
  For I:=1 To NB Do Button(BX1+(I-1)*(BW+10),BY,BX1+(I-1)*(BW+10)+BW-1,BY+22,
    Lb[I],I=Foc,True);
  ShowMouse;
  Repeat PollEvent(E) Until E.Kind In [1,2];
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ENTER: Begin Res:=Ret[Foc];Done:=True;End;
    K_ESC: Begin If Kind=4 Then Res:=2 Else If Kind=1 Then Res:=1 Else Res:=3;
      Done:=True;End;
    K_TAB,K_RIGHT: Begin Inc(Foc);If Foc>NB Then Foc:=1;End;
    K_STAB,K_LEFT: Begin Dec(Foc);If Foc<1 Then Foc:=NB;End;
    Else Begin
     For I:=1 To NB Do
      If UpCase(Chr(E.Key And $FF))=UpCase(Lb[I][1]) Then Begin
       Res:=Ret[I];Done:=True;End;
    End;
   End;
  End Else Begin
   For I:=1 To NB Do
    If InBox(E.X,E.Y,BX1+(I-1)*(BW+10),BY,BX1+(I-1)*(BW+10)+BW-1,BY+22) Then
      Begin
     Res:=Ret[I];Done:=True;
    End;
  End;
 Until Done;
 MsgBox:=Res;
 DrawAll;
End;

Procedure Msg(Const S: String);
Var R: Integer;
Begin
 R:=MsgBox(S,1);
End;

{ ---- formulaire generique ---- }

Var
 Frm: TForm;

Procedure FormBegin(Const Title: String);
Begin
 FillChar(Frm,SizeOf(Frm),0);
 Frm.Title:=Title;
End;

Procedure FormAdd(Kind: Integer; Const Lbl,Val: String; MaxL: Integer; Const
  Opt: String);
Begin
 If Frm.N>=10 Then Exit;
 Inc(Frm.N);
 Frm.Lbl[Frm.N]:=Lbl;Frm.Kind[Frm.N]:=Kind;Frm.Val[Frm.N]:=Val;
 Frm.Len[Frm.N]:=MaxL;Frm.Opt[Frm.N]:=Opt;
End;

Function OptCount(Const O: String): Integer;
Var I,N: Integer;
Begin
 N:=1;
 For I:=1 To Length(O) Do If O[I]='|' Then Inc(N);
 OptCount:=N;
End;

Function OptItem(Const O: String; N: Integer): String;
Var I,K: Integer; S: String;
Begin
 S:='';K:=1;
 For I:=1 To Length(O) Do Begin
  If O[I]='|' Then Inc(K)
  Else If K=N Then S:=S+O[I];
 End;
 OptItem:=S;
End;

Function DictNext(Cat,Cur,Dir: Integer): Integer;
Var I,N: Integer;
Begin
 N:=Cur;
 For I:=1 To MAXDE+1 Do Begin
  N:=N+Dir;
  If N>MAXDE Then N:=0;
  If N<0 Then N:=MAXDE;
  If (N=0) Or (Dict^[Cat,N].Name<>'') Then Begin DictNext:=N;Exit;End;
 End;
 DictNext:=Cur;
End;

Function FormText(I: Integer): String;
Var K: Integer;
Begin
 Case Frm.Kind[I] Of
  2: If Frm.Val[I]='1' Then FormText:='[x]' Else FormText:='[ ]';
  3: Begin
      K:=ValInt(Frm.Val[I],0);
      If K=0 Then FormText:=T5('<aucun>','<none>','<keine>','<ninguno>',
        '<nessuno>')
      Else FormText:=Copy(DictLabel(ValInt(Frm.Opt[I],1),K),1,28);
     End;
  4: FormText:=OptItem(Frm.Opt[I],ValInt(Frm.Val[I],1));
  Else FormText:=Frm.Val[I];
 End;
End;

Function RunForm: Boolean;
Var X1,Y1,X2,Y2,W,H,I,Foc,Cur,RY,FX,K,Rd: Integer;
    E: TEvent; Done,OK,Fresh,Redraw: Boolean; S: String; Ch: Char;
    CurT: LongInt;
Begin
 Rd:=0;
 For I:=1 To Frm.N Do If Length(Frm.Lbl[I])>Rd Then Rd:=Length(Frm.Lbl[I]);
 W:=14+Rd*8+14+236;
 If W<420 Then W:=420;
 If W>SCR_W-20 Then W:=SCR_W-20;
 H:=64+Frm.N*24+44;
 If Frm.Info<>'' Then H:=H+16;
 X1:=(SCR_W-W) Div 2;Y1:=(SCR_H-H) Div 2;X2:=X1+W-1;Y2:=Y1+H-1;
 FX:=X2-14-232;
 Foc:=1;Cur:=Length(Frm.Val[1]);Fresh:=True;Done:=False;OK:=False;
 For I:=1 To Frm.N Do If Frm.Kind[I]=1 Then Frm.Val[I]:=TrimStr(Frm.Val[I]);
 Redraw:=True;
 Repeat
  If Redraw Then Begin
   HideMouse;
   DlgFrame(X1,Y1,X2,Y2,Frm.Title);
   RY:=Y1+30;
   If Frm.Info<>'' Then Begin Tx(X1+14,RY,Frm.Info,cBlk);Inc(RY,16);End;
   For I:=1 To Frm.N Do Begin
    Tx(X1+14,RY+I*24-14,Frm.Lbl[I],cBlk);
    If Frm.Kind[I] In [0,1] Then Begin
     Sunken(FX,RY+I*24-18,X2-14,RY+I*24+2,cWht);
     S:=Frm.Val[I];
     If I=Foc Then Begin
      If Fresh And (S<>'') Then Begin
       Bx(FX+3,RY+I*24-15,FX+3+Length(S)*8,RY+I*24-1,cNavy);
       Tx(FX+3,RY+I*24-12,S,cWht);
      End Else Begin
       Tx(FX+3,RY+I*24-12,S,cBlk);
       Ln(FX+3+Cur*8,RY+I*24-15,FX+3+Cur*8,RY+I*24-3,cBlk);
      End;
     End Else Tx(FX+3,RY+I*24-12,S,cBlk);
    End Else Begin
     Raised(FX,RY+I*24-18,X2-14,RY+I*24+2);
     If Frm.Kind[I]=2 Then Begin
      Sunken(FX+4,RY+I*24-14,FX+16,RY+I*24-2,cWht);
      If Frm.Val[I]='1' Then Begin
       Ln(FX+6,RY+I*24-9,FX+9,RY+I*24-5,cBlk);Ln(FX+9,RY+I*24-5,FX+14,
         RY+I*24-12,cBlk);
      End;
     End Else Begin
      Tx(FX+8,RY+I*24-12,FormText(I),cBlk);
      Arw(X2-24,RY+I*24-8,4,cBlk);
     End;
     If I=Foc Then FocusRect(FX+1,RY+I*24-17,X2-15,RY+I*24+1);
    End;
   End;
   Button(X2-190,Y2-34,X2-110,Y2-10,'OK',False,True);
   Button(X2-98,Y2-34,X2-18,Y2-10,T5('Annuler','Cancel','Abbrechen','Cancelar',
     'Annulla'),False,True);
   ShowMouse;
   Redraw:=False;
  End;
  Repeat PollEvent(E) Until E.Kind In [1,2];
  If E.Kind=1 Then Begin
   K:=E.Key;
   Case K Of
    K_ESC: Done:=True;
    K_ENTER: Begin OK:=True;Done:=True;End;
    K_TAB,K_DOWN: Begin Inc(Foc);If Foc>Frm.N Then Foc:=1;
      Cur:=Length(Frm.Val[Foc]);Fresh:=True;Redraw:=True;End;
    K_STAB,K_UP: Begin Dec(Foc);If Foc<1 Then Foc:=Frm.N;
      Cur:=Length(Frm.Val[Foc]);Fresh:=True;Redraw:=True;End;
    Else Begin
     Case Frm.Kind[Foc] Of
      0,1: Begin
        S:=Frm.Val[Foc];
        If K=K_LEFT Then Begin If Cur>0 Then Dec(Cur);Fresh:=False;End
        Else If K=K_RIGHT Then Begin If Cur<Length(S) Then Inc(Cur);
          Fresh:=False;End
        Else If K=K_HOME Then Begin Cur:=0;Fresh:=False;End
        Else If K=K_END Then Begin Cur:=Length(S);Fresh:=False;End
        Else If K=K_DEL Then Begin
          If Fresh Then Begin S:='';Cur:=0;End Else If Cur<Length(S) Then
            Delete(S,Cur+1,1);
          Fresh:=False;
        End
        Else If K=K_BKSP Then Begin
          If Fresh Then Begin S:='';Cur:=0;End Else If Cur>0 Then Begin
            Delete(S,Cur,1);Dec(Cur);End;
          Fresh:=False;
        End
        Else If (K>=32) And (K<256) Then Begin
          Ch:=Chr(K);
          If (Frm.Kind[Foc]=0) Or (Ch In ['0'..'9','-']) Then Begin
           If Fresh Then Begin S:='';Cur:=0;End;
           If Length(S)<Frm.Len[Foc] Then Begin Insert(Ch,S,Cur+1);Inc(Cur);End;
           Fresh:=False;
          End;
        End;
        Frm.Val[Foc]:=S;
        Redraw:=True;
       End;
      2: If (K=32) Or (K=K_LEFT) Or (K=K_RIGHT) Then Begin
          If Frm.Val[Foc]='1' Then Frm.Val[Foc]:='0' Else Frm.Val[Foc]:='1';
            Redraw:=True;End;
      3: Begin
          If (K=32) Or (K=K_RIGHT) Then Begin
           Frm.Val[Foc]:=IntStr(DictNext(ValInt(Frm.Opt[Foc],1),
             ValInt(Frm.Val[Foc],0),1));Redraw:=True;End;
          If K=K_LEFT Then Begin
           Frm.Val[Foc]:=IntStr(DictNext(ValInt(Frm.Opt[Foc],1),
             ValInt(Frm.Val[Foc],0),-1));Redraw:=True;End;
         End;
      4: Begin
          Rd:=ValInt(Frm.Val[Foc],1);
          If (K=32) Or (K=K_RIGHT) Then Begin Inc(Rd);If
            Rd>OptCount(Frm.Opt[Foc]) Then Rd:=1;Redraw:=True;End;
          If K=K_LEFT Then Begin Dec(Rd);If Rd<1 Then
            Rd:=OptCount(Frm.Opt[Foc]);Redraw:=True;End;
          Frm.Val[Foc]:=IntStr(Rd);
         End;
     End;
    End;
   End;
  End Else Begin
   If InBox(E.X,E.Y,X2-190,Y2-34,X2-110,Y2-10) Then Begin OK:=True;Done:=True;
     End
   Else If InBox(E.X,E.Y,X2-98,Y2-34,X2-18,Y2-10) Then Done:=True
   Else Begin
    RY:=Y1+30;If Frm.Info<>'' Then Inc(RY,16);
    For I:=1 To Frm.N Do
     If InBox(E.X,E.Y,FX,RY+I*24-18,X2-14,RY+I*24+2) Then Begin
      If Foc<>I Then Begin Foc:=I;Cur:=Length(Frm.Val[I]);Fresh:=False;End;
      Case Frm.Kind[I] Of
       0,1: Begin
         Cur:=(E.X-FX-3+4) Div 8;
         If Cur>Length(Frm.Val[I]) Then Cur:=Length(Frm.Val[I]);If Cur<0 Then
           Cur:=0;
         Fresh:=False;
        End;
       2: If Frm.Val[I]='1' Then Frm.Val[I]:='0' Else Frm.Val[I]:='1';
       3: Frm.Val[I]:=IntStr(DictNext(ValInt(Frm.Opt[I],1),ValInt(Frm.Val[I],0),
         1));
       4: Begin
           Rd:=ValInt(Frm.Val[I],1)+1;If Rd>OptCount(Frm.Opt[I]) Then Rd:=1;
           Frm.Val[I]:=IntStr(Rd);
          End;
      End;
     End;
    Redraw:=True;
   End;
  End;
 Until Done;
 For I:=1 To Frm.N Do If Frm.Kind[I]=1 Then Frm.Val[I]:=TrimStr(Frm.Val[I]);
 RunForm:=OK;
 DrawAll;
End;

Function InputBox(Const Title,Prompt: String; Var S: String; MaxL: Integer):
  Boolean;
Begin
 FormBegin(Title);
 FormAdd(0,Prompt,S,MaxL,'');
 If RunForm Then Begin S:=Frm.Val[1];InputBox:=True;End Else InputBox:=False;
End;

{ ---- liste a choisir / visionneuse de texte ---- }

Var
 LRef  : Array[1..MAXTL] Of Integer;
 LNoSel: Boolean;
 LWide : Integer;

{ Items dans TL^[1..TLN] ; retour : numero du bouton (0 = Echap) }
Function ListBox(Const Title,Btns: String; Var Sel: Integer): Integer;
Var X1,Y1,X2,Y2,W,H,Rows,Top,I,NB,BW,R,K,Res,LY,LH,Foc: Integer;
    E: TEvent; Done,Redraw: Boolean; Lb: String; DblT: LongInt;
Begin
 Rows:=15;LH:=12;
 If LWide=0 Then W:=440 Else W:=LWide;
 H:=34+Rows*LH+12+34;
 NB:=OptCount(Btns);
 X1:=(SCR_W-W) Div 2;Y1:=(SCR_H-H) Div 2-4;X2:=X1+W-1;Y2:=Y1+H-1;
 If Sel<1 Then Sel:=1;If Sel>TLN Then Sel:=TLN;
 Top:=1;Done:=False;Res:=0;Redraw:=True;DblT:=0;Foc:=1;
 BW:=(W-20-(NB-1)*6) Div NB;If BW>100 Then BW:=100;
 Repeat
  If (Sel<Top) Then Top:=Sel;
  If Sel>=Top+Rows Then Top:=Sel-Rows+1;
  If Top<1 Then Top:=1;
  If Redraw Then Begin
   HideMouse;
   DlgFrame(X1,Y1,X2,Y2,Title);
   Sunken(X1+10,Y1+28,X2-26,Y1+28+Rows*LH+3,cWht);
   LY:=Y1+30;
   For I:=0 To Rows-1 Do Begin
    R:=Top+I;
    If R<=TLN Then Begin
     If (R=Sel) And Not LNoSel Then Begin
      Bx(X1+12,LY+I*LH-1,X2-28,LY+I*LH+LH-2,cNavy);
      Tx(X1+14,LY+I*LH+1,Copy(TL^[R],1,(W-46) Div 8),cWht);
     End Else Tx(X1+14,LY+I*LH+1,Copy(TL^[R],1,(W-46) Div 8),cBlk);
    End;
   End;
   Raised(X2-24,Y1+28,X2-9,Y1+43);Arw(X2-17,Y1+36,1,cBlk);
   Raised(X2-24,Y1+28+Rows*LH-12,X2-9,Y1+28+Rows*LH+3);Arw(X2-17,
     Y1+28+Rows*LH-5,2,cBlk);
   Bx(X2-24,Y1+44,X2-9,Y1+28+Rows*LH-13,cLGr);
   If TLN>Rows Then Begin
    K:=Y1+44+((Top-1)*(Rows*LH-58-12)) Div (TLN-Rows+1);
    Raised(X2-24,K,X2-9,K+12);
   End;
   For I:=1 To NB Do Begin
    Lb:=OptItem(Btns,I);
    Button(X1+10+(I-1)*(BW+6),Y2-32,X1+10+(I-1)*(BW+6)+BW-1,Y2-8,Lb,I=Foc,True);
   End;
   ShowMouse;
   Redraw:=False;
  End;
  Repeat PollEvent(E) Until E.Kind In [1,2];
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ESC: Begin Res:=0;Done:=True;End;
    K_ENTER: Begin Res:=Foc;Done:=True;End;
    K_UP: Begin If Sel>1 Then Dec(Sel);Redraw:=True;End;
    K_DOWN: Begin If Sel<TLN Then Inc(Sel);Redraw:=True;End;
    K_PGUP: Begin Dec(Sel,Rows);If Sel<1 Then Sel:=1;Redraw:=True;End;
    K_PGDN: Begin Inc(Sel,Rows);If Sel>TLN Then Sel:=TLN;Redraw:=True;End;
    K_HOME: Begin Sel:=1;Redraw:=True;End;
    K_END: Begin Sel:=TLN;Redraw:=True;End;
    K_TAB: Begin Inc(Foc);If Foc>NB Then Foc:=1;Redraw:=True;End;
    K_STAB: Begin Dec(Foc);If Foc<1 Then Foc:=NB;Redraw:=True;End;
    K_LEFT: Begin Dec(Foc);If Foc<1 Then Foc:=NB;Redraw:=True;End;
    K_RIGHT: Begin Inc(Foc);If Foc>NB Then Foc:=1;Redraw:=True;End;
   End;
  End Else Begin
   For I:=1 To NB Do
    If InBox(E.X,E.Y,X1+10+(I-1)*(BW+6),Y2-32,X1+10+(I-1)*(BW+6)+BW-1,Y2-8) Then
      Begin
     Res:=I;Done:=True;
    End;
   If InBox(E.X,E.Y,X1+12,Y1+30,X2-28,Y1+30+Rows*LH) Then Begin
    R:=Top+(E.Y-(Y1+30)) Div LH;
    If (R>=1) And (R<=TLN) Then Begin
     If (R=Sel) And (Abs(Tick-DblT)<45) And Not LNoSel Then Begin Res:=1;
       Done:=True;End;
     Sel:=R;DblT:=Tick;Redraw:=True;
    End;
   End;
   If InBox(E.X,E.Y,X2-24,Y1+28,X2-9,Y1+43) Then Begin If Sel>1 Then Dec(Sel);
     Redraw:=True;End;
   If InBox(E.X,E.Y,X2-24,Y1+28+Rows*LH-12,X2-9,Y1+28+Rows*LH+3) Then Begin
    If Sel<TLN Then Inc(Sel);Redraw:=True;End;
   If InBox(E.X,E.Y,X2-24,Y1+44,X2-9,Y1+28+Rows*LH-13) Then Begin
    If E.Y<Y1+44+Rows*LH Div 2 Then Dec(Sel,Rows) Else Inc(Sel,Rows);
    If Sel<1 Then Sel:=1;If Sel>TLN Then Sel:=TLN;Redraw:=True;
   End;
  End;
 Until Done;
 ListBox:=Res;
 DrawAll;
End;

Procedure TLClear;
Begin
 TLN:=0;
End;

Procedure TLAdd(Const S: String);
Begin
 If TLN<MAXTL Then Begin Inc(TLN);TL^[TLN]:=Copy(S,1,78);LRef[TLN]:=0;End;
End;

Procedure SaveTextLines(Const FN: String);
Var F: Text; I: Integer;
Begin
 {$I-}
 Assign(F,FN);Rewrite(F);
 {$I+}
 If IOResult<>0 Then Begin
  Msg(T5('Impossible d''@ecrire le fichier.','Cannot write the file.',
     'Datei kann nicht geschrieben werden.','No se puede escribir el archivo.',
     'Impossibile scrivere il file.'));
  Exit;
 End;
 For I:=1 To TLN Do WriteLn(F,TL^[I]);
 Close(F);
End;

Procedure ShowText(Const Title: String);
Var Sel,R: Integer; FN: String;
Begin
 Sel:=1;LNoSel:=True;LWide:=600;
 Repeat
  R:=ListBox(Title,T5('Enregistrer...|Fermer','Save...|Close',
    'Speichern...|Schlie@7en',
     'Guardar...|Cerrar','Salva...|Chiudi'),Sel);
  If R=1 Then Begin
   FN:='RAPPORT.TXT';
   If InputBox(T5('Enregistrer le texte','Save text','Text speichern',
     'Guardar texto','Salva testo'),
      T5('Fichier :','File:','Datei:','Archivo:','File:'),FN,60) Then Begin
    SaveTextLines(FN);
    R:=2;
   End;
  End;
 Until R<>1;
 LNoSel:=False;LWide:=0;
End;

{ ====================================================================== }
{                      MENUS DEROULANTS (SIMPLY.PAS)                     }
{ ====================================================================== }

Procedure DoCmd(Cm: Integer); Forward;

Var
 MT    : Array[1..NMTOT] Of String[28];
 MLb   : Array[1..NMTOT,1..MAXITEM] Of String[60];
 MCm   : Array[1..NMTOT,1..MAXITEM] Of Integer;
 MCnt  : Array[1..NMTOT] Of Integer;
 MRX1,MRY1,MRX2,MRY2 : Array[1..NMTOT] Of Integer;

Procedure MAdd(M: Integer; Const Lb: String; Cm: Integer);
Begin
 Inc(MCnt[M]);
 MLb[M,MCnt[M]]:=Lb;
 MCm[M,MCnt[M]]:=Cm;
End;

Function FileTitle: String;
Begin
 If FileN='' Then FileTitle:=T5('SansTitre','Untitled','Unbenannt','SinTitulo',
   'SenzaTitolo')+IntStr(CurDoc)
 Else FileTitle:=ShortName(FileN);
End;

Function WinTitle(W: Integer): String;
Var P,Old: Integer; T: String;
Begin
 Old:=CurDoc;
 SelectDoc(Wn[W].Doc);
 T:=DiagTitle(Wn[W].Diag);
 P:=FindEl(Mdl^.Dg[Wn[W].Diag].Parent);
 If P>0 Then T:=Mdl^.El[P].Num;
 WinTitle:='('+IntStr(Wn[W].Doc)+') '+FileTitle+' - '+T;
 SelectDoc(Old);
End;

Procedure BuildWindowMenu;
Var I,K: Integer;
Begin
 MCnt[7]:=0;
 MAdd(7,T5('Cascade','Cascade','@6berlappend','Cascada','Sovrapponi'),
   cmCascade);
 MAdd(7,T5('Mosa@yque horizontale','Tile Horizontally','Horizontal anordnen',
   'Mosaico horizontal','Affianca orizzontalmente'),cmTileH);
 MAdd(7,T5('Mosa@yque verticale','Tile Vertically','Vertikal anordnen',
   'Mosaico vertical','Affianca verticalmente'),cmTileV);
 MAdd(7,T5('Fermer tout','Close All','Alle schlie@7en','Cerrar todo',
   'Chiudi tutto'),cmCloseAll);
 MAdd(7,T5('R@eorganiser ic@ones','Arrange Icons','Symbole anordnen',
   'Organizar iconos','Disponi icone'),cmArrange);
 If WCnt>0 Then MAdd(7,'-',0);
 K:=0;
 For I:=1 To WCnt Do Begin
  Inc(K);
  MAdd(7,IntStr(K)+' '+WinTitle(WZo[I]),cmWin1+WZo[I]);
 End;
End;

Procedure BuildMenus;
Begin
 FillChar(MCnt,SizeOf(MCnt),0);
 MT[1]:=T5('&Fichier','&File','&Datei','&Archivo','&File');
 MT[2]:=T5('&Edition','&Edit','&Bearbeiten','&Edici@pn','&Modifica');
 MT[3]:=T5('&Affichage','&Display','&Anzeige','&Ver','&Visualizza');
 MT[4]:=T5('&Mod@gle','&Model','&Modell','&Modelo','Mo&dello');
 MT[5]:=T5('&Projet','&Project','&Projekt','&Proyecto','&Progetto');
 MT[6]:=T5('&Outils','&Tools','&Werkzeuge','&Herramientas','S&trumenti');
 MT[7]:=T5('Fe&n@etre','&Window','&Fenster','Ven&tana','Fi&nestra');
 MT[8]:=T5('Ai&de','&Help','&Hilfe','A&yuda','&Aiuto');
 { Fichier }
 MAdd(1,T5('Nouveau|Ctrl+N','New|Ctrl+N','Neu|Strg+N','Nuevo|Ctrl+N',
   'Nuovo|Ctrl+N'),cmNew);
 MAdd(1,T5('Ouvrir...|Ctrl+O','Open...|Ctrl+O','@5ffnen...|Strg+O',
   'Abrir...|Ctrl+O','Apri...|Ctrl+O'),cmOpen);
 MAdd(1,T5('Fermer|Ctrl+F4','Close|Ctrl+F4','Schlie@7en|Strg+F4',
   'Cerrar|Ctrl+F4','Chiudi|Ctrl+F4'),cmClose);
 MAdd(1,'-',0);
 MAdd(1,T5('Enregistrer|Ctrl+S','Save|Ctrl+S','Speichern|Strg+S',
   'Guardar|Ctrl+S','Salva|Ctrl+S'),cmSave);
 MAdd(1,T5('Enregistrer sous...','Save As...','Speichern unter...',
   'Guardar como...','Salva con nome...'),cmSaveAs);
 MAdd(1,T5('Mots de passe...','Passwords...','Passw@2rter...','Contrase@nas...',
   'Password...'),cmPass);
 MAdd(1,'-',0);
 MAdd(1,T5('Importer-Exporter...','Import-Export...','Import-Export...',
   'Importar-Exportar...','Importa-Esporta...'),cmImpExp);
 MAdd(1,T5('Rapport...','Report...','Bericht...','Informe...','Rapporto...'),
   cmReport);
 MAdd(1,'-',0);
 MAdd(1,T5('Mise en page...','Page Setup...','Seite einrichten...',
   'Configurar p@rgina...','Imposta pagina...'),cmPageSetup);
 MAdd(1,T5('Imprimer...|Ctrl+P','Print...|Ctrl+P','Drucken...|Strg+P',
   'Imprimir...|Ctrl+P','Stampa...|Ctrl+P'),cmPrint);
 MAdd(1,'-',0);
 MAdd(1,T5('Quitter','Exit','Beenden','Salir','Esci'),cmExit);
 { Edition }
 MAdd(2,T5('Annuler|Ctrl+Z','Undo|Ctrl+Z','R@3ckg@1ngig|Strg+Z',
   'Deshacer|Ctrl+Z','Annulla|Ctrl+Z'),cmUndo);
 MAdd(2,T5('R@etablir|Ctrl+Y','Redo|Ctrl+Y','Wiederholen|Strg+Y',
   'Rehacer|Ctrl+Y','Ripeti|Ctrl+Y'),cmRedo);
 MAdd(2,'-',0);
 MAdd(2,T5('Couper|Ctrl+X','Cut|Ctrl+X','Ausschneiden|Strg+X','Cortar|Ctrl+X',
   'Taglia|Ctrl+X'),cmCut);
 MAdd(2,T5('Copier|Ctrl+C','Copy|Ctrl+C','Kopieren|Strg+C','Copiar|Ctrl+C',
   'Copia|Ctrl+C'),cmCopy);
 MAdd(2,T5('Coller|Ctrl+V','Paste|Ctrl+V','Einf@3gen|Strg+V','Pegar|Ctrl+V',
   'Incolla|Ctrl+V'),cmPaste);
 MAdd(2,T5('Effacer|Suppr','Clear|Del','L@2schen|Entf','Borrar|Supr',
   'Cancella|Canc'),cmClear);
 MAdd(2,T5('Dupliquer|Ctrl+D','Duplicate|Ctrl+D','Duplizieren|Strg+D',
   'Duplicar|Ctrl+D','Duplica|Ctrl+D'),cmDup);
 MAdd(2,'-',0);
 MAdd(2,T5('S@electionner tout|Ctrl+A','Select All|Ctrl+A',
   'Alles ausw@1hlen|Strg+A','Seleccionar todo|Ctrl+A',
   'Seleziona tutto|Ctrl+A'),cmSelAll);
 MAdd(2,T5('S@electionner...|Ctrl+L','Select...|Ctrl+L','Ausw@1hlen...|Strg+L',
   'Seleccionar...|Ctrl+L','Seleziona...|Ctrl+L'),cmSelect);
 MAdd(2,T5('Atteindre la page...|Ctrl+G','Go to Page...|Ctrl+G',
   'Gehe zu Seite...|Strg+G','Ir a p@rgina...|Ctrl+G','Vai a pagina...|Ctrl+G'),
   cmGoto);
 { Affichage }
 MAdd(3,T5('Palettes...','Toolbars...','Symbolleisten...',
   'Barras de herramientas...','Barre degli strumenti...'),cmToolbars);
 MAdd(3,'-',0);
 MAdd(3,T5('Tendre les flux|Ctrl+T','Straighten Flows|Ctrl+T',
   'Fl@3sse begradigen|Strg+T','Enderezar flujos|Ctrl+T',
   'Raddrizza flussi|Ctrl+T'),cmStraight);
 MAdd(3,T5('Changer la direction des flux|Ctrl+U',
   'Change Flow Direction|Ctrl+U','Flussrichtung @1ndern|Strg+U',
   'Cambiar sentido|Ctrl+U','Cambia direzione|Ctrl+U'),cmChgDir);
 MAdd(3,T5('Libell@es et qualificatifs','Labels and Qualifiers',
   'Beschriftungen','Etiquetas y calificadores','Etichette e qualificatori'),
   1009);
 MAdd(3,'-',0);
 MAdd(3,T5('Cadrer|Ctrl+F','Fit|Ctrl+F','Anpassen|Strg+F','Ajustar|Ctrl+F',
   'Adatta|Ctrl+F'),cmFit);
 MAdd(3,T5('Remettre @a la taille par d@efaut','Restore to Default Size',
   'Standardgr@2@7e','Tama@no predeterminado','Dimensione predefinita'),
   cmRestore);
 MAdd(3,T5('Dimensionner...','Resize...','Gr@2@7e @1ndern...',
   'Cambiar tama@no...','Ridimensiona...'),cmResize);
 MAdd(3,T5('Cacher|Ctrl+H','Hide|Ctrl+H','Ausblenden|Strg+H','Ocultar|Ctrl+H',
   'Nascondi|Ctrl+H'),cmHide);
 MAdd(3,T5('Montrer','Show','Einblenden','Mostrar','Mostra'),1010);
 MAdd(3,T5('Mettre en @evidence','Highlight','Hervorheben','Resaltar',
   'Evidenzia'),cmHilite);
 MAdd(3,T5('Enlever la mise en @evidence','Remove Highlight',
   'Hervorhebung entfernen','Quitar resaltado','Rimuovi evidenziazione'),
   cmUnHilite);
 MAdd(3,T5('Police du texte libre...','Free Text Font...',
   'Schrift f@3r freien Text...','Fuente del texto libre...',
   'Carattere del testo libero...'),cmFont);
 MAdd(3,T5('Disposition','Arrange','Anordnen','Organizar','Disponi'),1011);
 MAdd(3,'-',0);
 MAdd(3,T5('Surface de travail...','Drawing Size...','Zeichnungsgr@2@7e...',
   'Tama@no del dibujo...','Dimensione disegno...'),cmDrawSize);
 MAdd(3,'Zoom',1012);
 MAdd(3,T5('Aligner','Align','Ausrichten','Alinear','Allinea'),1013);
 { Modele }
 MAdd(4,T5('Processus|Ctrl+1','Processes|Ctrl+1','Prozesse|Strg+1',
   'Procesos|Ctrl+1','Processi|Ctrl+1'),cmMProc);
 MAdd(4,T5('Flux|Ctrl+2','Flows|Ctrl+2','Fl@3sse|Strg+2','Flujos|Ctrl+2',
   'Flussi|Ctrl+2'),cmMFlow);
 MAdd(4,T5('D@ep@ots|Ctrl+3','Stores|Ctrl+3','Speicher|Strg+3',
   'Almacenes|Ctrl+3','Archivi|Ctrl+3'),cmMStore);
 MAdd(4,T5('Entit@es externes|Ctrl+4','External Entities|Ctrl+4',
   'Externe Entit@1ten|Strg+4','Entidades externas|Ctrl+4',
   'Entit@r esterne|Ctrl+4'),cmMEnt);
 MAdd(4,T5('Ressources|Ctrl+5','Resources|Ctrl+5','Ressourcen|Strg+5',
   'Recursos|Ctrl+5','Risorse|Ctrl+5'),cmMRes);
 MAdd(4,T5('Qualificatifs|Ctrl+6','Qualifiers|Ctrl+6','Qualifizierer|Strg+6',
   'Calificadores|Ctrl+6','Qualificatori|Ctrl+6'),cmMQual);
 MAdd(4,T5('Diagrammes|Ctrl+7','Diagrams|Ctrl+7','Diagramme|Strg+7',
   'Diagramas|Ctrl+7','Diagrammi|Ctrl+7'),cmMDiag);
 MAdd(4,'-',0);
 MAdd(4,T5('Description du mod@gle','Model Description','Modellbeschreibung',
   'Descripci@pn del modelo','Descrizione del modello'),cmMDesc);
 MAdd(4,'-',0);
 MAdd(4,T5('Champs utilisateur','User Defined Fields',
   'Benutzerdefinierte Felder','Campos definidos por el usuario',
   'Campi definiti dall''utente'),cmMUdf);
 { Projet }
 MAdd(5,T5('Domaines','Domains','Dom@1nen','Dominios','Domini'),cmPDom);
 MAdd(5,T5('Types de donn@ees','Data Types','Datentypen','Tipos de datos',
   'Tipi di dati'),cmPType);
 MAdd(5,T5('Items communs','Common Items','Gemeinsame Elemente',
   'Elementos comunes','Elementi comuni'),cmPComm);
 MAdd(5,T5('Structures de donn@ees','Data Structures','Datenstrukturen',
   'Estructuras de datos','Strutture dati'),cmPStruct);
 MAdd(5,T5('Syst@gmes cibles','Target Systems','Zielsysteme',
   'Sistemas de destino','Sistemi di destinazione'),cmPTarget);
 MAdd(5,'-',0);
 MAdd(5,T5('Concepts avanc@es','Extended Concepts','Erweiterte Konzepte',
   'Conceptos extendidos','Concetti estesi'),1014);
 MAdd(5,'-',0);
 MAdd(5,T5('Description du projet','Project Description','Projektbeschreibung',
   'Descripci@pn del proyecto','Descrizione del progetto'),cmPDesc);
 { Outils }
 MAdd(6,T5('V@erifier l''int@egrit@e...','Verify Integrity...',
   'Integrit@1t pr@3fen...','Verificar integridad...','Verifica integrit@r...'),
   cmVerify);
 MAdd(6,T5('Nettoyage...','Cleanup...','Bereinigen...','Limpieza...',
   'Pulizia...'),cmCleanup);
 MAdd(6,T5('G@en@erer','Generate','Generieren','Generar','Genera'),1015);
 MAdd(6,'-',0);
 MAdd(6,T5('Compl@ements','Add-Ins','Add-Ins','Complementos',
   'Componenti aggiuntivi'),cmAddIns);
 MAdd(6,'-',0);
 MAdd(6,T5('Fusionner...','Merge...','Zusammenf@3hren...','Combinar...',
   'Unisci...'),cmMerge);
 MAdd(6,T5('Scinder...','Split...','Aufteilen...','Dividir...','Dividi...'),
   cmSplit);
 MAdd(6,'-',0);
 MAdd(6,T5('Cr@eer/ouvrir l''arbre des processus...',
   'Create/Open Process Tree...','Prozessbaum erstellen/@2ffnen...',
   'Crear/abrir @rrbol de procesos...','Crea/apri albero dei processi...'),
   cmTree);
 MAdd(6,T5('Mettre @a jour l''arbre des processus...','Update Process Tree...',
   'Prozessbaum aktualisieren...','Actualizar @rrbol de procesos...',
   'Aggiorna albero dei processi...'),cmTreeUpd);
 MAdd(6,T5('Cr@eer un parent du processus racine...',
   'Create Parent for Root Process...','Eltern f@3r Wurzelprozess erstellen...',
   'Crear padre del proceso ra@jz...','Crea genitore del processo radice...'),
   cmParent);
 MAdd(6,T5('Mettre @a jour l''environnement','Update Environment',
   'Umgebung aktualisieren','Actualizar entorno','Aggiorna ambiente'),cmEnv);
 MAdd(6,T5('Mettre @a jour l''environnement (avec propri@et@es des flux)',
   'Update Environment (with Flow Properties)',
   'Umgebung aktualisieren (mit Flusseigenschaften)',
   'Actualizar entorno (con propiedades de flujo)',
   'Aggiorna ambiente (con propriet@r dei flussi)'),cmEnvFlow);
 MAdd(6,'-',0);
 MAdd(6,T5('Renum@eroter...','Renumber...','Neu nummerieren...','Renumerar...',
   'Rinumera...'),cmRenum);
 MAdd(6,T5('Utiliser le dictionnaire WRM','Use WRM Dictionary',
   'WRM-W@2rterbuch verwenden','Usar diccionario WRM','Usa dizionario WRM'),
   cmWRM);
 MAdd(6,'-',0);
 MAdd(6,T5('Options...','Options...','Optionen...','Opciones...','Opzioni...'),
   cmOptions);
 { Fenetre : dynamique }
 BuildWindowMenu;
 { Aide }
 MAdd(8,T5('Aide Solderrun-BPM|F1','Solderrun-BPM Help|F1',
   'Solderrun-BPM-Hilfe|F1','Ayuda de Solderrun-BPM|F1',
   'Guida di Solderrun-BPM|F1'),cmHelp);
 MAdd(8,'-',0);
 MAdd(8,T5('Guide de l''utilisateur BPM','BPM User''s Guide',
   'BPM-Benutzerhandbuch','Gu@ja del usuario BPM','Guida utente BPM'),cmGuide);
 MAdd(8,T5('Nouveaut@es','Release Notes','Versionshinweise',
   'Notas de la versi@pn','Note di rilascio'),cmRelNotes);
 MAdd(8,'-',0);
 MAdd(8,T5('Licences','Licenses','Lizenzen','Licencias','Licenze'),cmLicenses);
 MAdd(8,'-',0);
 MAdd(8,T5('A propos de SOLDERRUN-BPM...','About SOLDERRUN-BPM...',
   '@6ber SOLDERRUN-BPM...','Acerca de SOLDERRUN-BPM...',
   'Informazioni su SOLDERRUN-BPM...'),cmAbout);
 { Sous-menus }
 MAdd(9,T5('Noms des flux','Flow Names','Flussnamen','Nombres de flujos',
   'Nomi dei flussi'),cmLabName);
 MAdd(9,T5('Qualificatifs','Qualifiers','Qualifizierer','Calificadores',
   'Qualificatori'),cmLabQual);
 MAdd(9,T5('Num@eros','Numbers','Nummern','N@vmeros','Numeri'),cmLabNum);
 MAdd(9,T5('Ressources','Resources','Ressourcen','Recursos','Risorse'),
   cmLabRes);
 MAdd(10,T5('Tous les objets masqu@es','All hidden objects',
   'Alle ausgeblendeten Objekte','Todos los objetos ocultos',
   'Tutti gli oggetti nascosti'),cmShowAll);
 MAdd(11,T5('Premier plan','Bring to Front','In den Vordergrund',
   'Traer al frente','Porta in primo piano'),cmFront);
 MAdd(11,T5('Arri@gre-plan','Send to Back','In den Hintergrund',
   'Enviar al fondo','Porta in secondo piano'),cmBack);
 MAdd(12,'25 %',cmZoom25);MAdd(12,'50 %',cmZoom50);MAdd(12,'75 %',cmZoom75);
 MAdd(12,'100 %',cmZoom100);MAdd(12,'150 %',cmZoom150);MAdd(12,'200 %',
   cmZoom200);
 MAdd(12,'-',0);
 MAdd(12,T5('Zoom avant','Zoom In','Vergr@2@7ern','Acercar','Ingrandisci'),
   cmZoomIn);
 MAdd(12,T5('Zoom arri@gre','Zoom Out','Verkleinern','Alejar','Riduci'),
   cmZoomOut);
 MAdd(13,T5('Gauche','Left','Links','Izquierda','Sinistra'),cmAlL);
 MAdd(13,T5('Droite','Right','Rechts','Derecha','Destra'),cmAlR);
 MAdd(13,T5('Haut','Top','Oben','Arriba','Alto'),cmAlT);
 MAdd(13,T5('Bas','Bottom','Unten','Abajo','Basso'),cmAlB);
 MAdd(13,T5('Centrer horizontalement','Center Horizontally',
   'Horizontal zentrieren','Centrar horizontalmente','Centra orizzontalmente'),
   cmAlH);
 MAdd(13,T5('Centrer verticalement','Center Vertically','Vertikal zentrieren',
   'Centrar verticalmente','Centra verticalmente'),cmAlV);
 MAdd(14,T5('R@gles d''affaires','Business Rules','Gesch@1ftsregeln',
   'Reglas de negocio','Regole di business'),cmPRule);
 MAdd(14,T5('Ev@enements','Events','Ereignisse','Eventos','Eventi'),cmPEvent);
 MAdd(14,T5('Sites','Locations','Standorte','Ubicaciones','Sedi'),cmPLoc);
 MAdd(15,T5('Liste des processus','Process List','Prozessliste',
   'Lista de procesos','Elenco dei processi'),cmGenList);
 MAdd(15,T5('Arbre des processus (texte)','Process Tree (text)',
   'Prozessbaum (Text)','@rrbol de procesos (texto)',
   'Albero dei processi (testo)'),cmGenTree);
 MAdd(15,T5('Dictionnaire de donn@ees','Data Dictionary','Datenw@2rterbuch',
   'Diccionario de datos','Dizionario dati'),cmGenDict);
End;

Function ItemH(M,I: Integer): Integer;
Begin
 If MLb[M,I]='-' Then ItemH:=7 Else ItemH:=17;
End;

Function MenuX(M: Integer): Integer;
Var I,X: Integer;
Begin
 X:=8;
 For I:=1 To M-1 Do X:=X+TextW(MT[I])+14;
 MenuX:=X;
End;

Function MenuMnem(M: Integer): Char;
Var P: Integer;
Begin
 P:=Pos('&',MT[M]);
 If (P>0) And (P<Length(MT[M])) Then MenuMnem:=UpCase(MT[M][P+1]) Else
   MenuMnem:=#0;
End;

Function ItemY(M,I: Integer): Integer;
Var K,Y: Integer;
Begin
 Y:=MRY1[M]+3;
 For K:=1 To I-1 Do Y:=Y+ItemH(M,K);
 ItemY:=Y;
End;

Procedure LayoutMenu(M,AX,AY: Integer);
Var I,W,L,P,H: Integer; S: String;
Begin
 W:=0;H:=6;
 For I:=1 To MCnt[M] Do Begin
  S:=MLb[M,I];
  P:=Pos('|',S);
  If P>0 Then L:=(P-1)*8+28+(Length(S)-P)*8 Else L:=Length(S)*8;
  If L>W Then W:=L;
  H:=H+ItemH(M,I);
 End;
 MRX1[M]:=AX;MRY1[M]:=AY;
 MRX2[M]:=AX+W+48;MRY2[M]:=AY+H-1;
 If MRX2[M]>SCR_W-3 Then Begin
  MRX1[M]:=MRX1[M]-(MRX2[M]-(SCR_W-3));MRX2[M]:=SCR_W-3;
 End;
 If MRY2[M]>SCR_H-3 Then Begin
  MRY1[M]:=MRY1[M]-(MRY2[M]-(SCR_H-3));MRY2[M]:=SCR_H-3;
 End;
End;

Procedure LayoutMain(M: Integer);
Begin
 LayoutMenu(M,MenuX(M)-5,MENU_Y+MENU_H-1);
End;

Procedure LayoutSub(P,I,S: Integer);
Begin
 LayoutMenu(S,MRX2[P]-3,ItemY(P,I)-3);
End;

Function DropHit(M: Integer; X,Y: LongInt): Integer;
Var I: Integer;
Begin
 DropHit:=0;
 If M<1 Then Exit;
 If Not InBox(X,Y,MRX1[M],MRY1[M],MRX2[M],MRY2[M]) Then Exit;
 For I:=1 To MCnt[M] Do
  If (Y>=ItemY(M,I)) And (Y<ItemY(M,I)+ItemH(M,I)) Then DropHit:=I;
End;

Function TitleHit(X,Y: LongInt): Integer;
Var M: Integer;
Begin
 TitleHit:=0;
 If (Y<MENU_Y) Or (Y>=MENU_Y+MENU_H) Then Exit;
 For M:=1 To NMENU Do
  If (X>=MenuX(M)-5) And (X<=MenuX(M)+TextW(MT[M])+5) Then TitleHit:=M;
End;

{ ---- etat des commandes ---- }

Function CmdEnabled(Cm: Integer): Boolean;
Var D: Integer;
Begin
 CmdEnabled:=True;
 D:=CurDiag;
 Case Cm Of
  cmUndo: CmdEnabled:=UN>0;
  cmRedo: CmdEnabled:=RN>0;
  cmCut,cmCopy,cmClear,cmDup,cmHide,cmHilite,cmUnHilite,cmFront,cmBack:
    CmdEnabled:=(D>0) And (SelCount(D)>0);
  cmPaste: CmdEnabled:=(CBN>0) And (D>0);
  cmStraight,cmChgDir: CmdEnabled:=(D>0) And (SelFlCount(D)>0);
  cmResize,cmRestore: CmdEnabled:=(D>0) And (SelElCount(D)>0);
  cmShowAll: CmdEnabled:=(D>0) And (HiddenCount(D)>0);
  cmAlL,cmAlR,cmAlT,cmAlB,cmAlH,cmAlV: CmdEnabled:=(D>0) And (SelElCount(D)>=2);
  cmFont: CmdEnabled:=(D>0) And (SelElCount(D)>0);
  cmTreeUpd: CmdEnabled:=TreeOpen;
  cmAddIns: CmdEnabled:=False;
  cmEnv,cmEnvFlow,cmParentUp: CmdEnabled:=(D>0) And (Mdl^.Dg[D].Parent<>0);
  cmCloseAll,cmCascade,cmTileH,cmTileV,cmArrange: CmdEnabled:=WCnt>0;
  cmZoomIn,cmZoomOut,cmFit,cmDrawSize,cmSelAll,cmSelect: CmdEnabled:=D>0;
 End;
End;

Function CmdChecked(Cm: Integer): Boolean;
Begin
 CmdChecked:=False;
 Case Cm Of
  cmLabName: CmdChecked:=Cfg.ShName;
  cmLabQual: CmdChecked:=Cfg.ShQual;
  cmLabNum: CmdChecked:=Cfg.ShNum;
  cmLabRes: CmdChecked:=Cfg.ShRes;
  cmWRM: CmdChecked:=Cfg.WRM;
  cmWin1+1..cmWin1+MAXWIN: CmdChecked:=(Cm-cmWin1=ActiveWin);
 End;
End;

Procedure DrawMenuBar;
Var M: Integer;
Begin
 Bx(0,MENU_Y,SCR_W-1,MENU_Y+MENU_H-1,cLGr);
 Ln(0,MENU_Y+MENU_H-1,SCR_W-1,MENU_Y+MENU_H-1,cDGr);
 For M:=1 To NMENU Do Begin
  If M=MenuOpen Then Begin
   Bx(MenuX(M)-5,MENU_Y+1,MenuX(M)+TextW(MT[M])+4,MENU_Y+MENU_H-2,cNavy);
   UTx(MenuX(M),MENU_Y+5,MT[M],cWht);
  End Else UTx(MenuX(M),MENU_Y+5,MT[M],cBlk);
 End;
End;

Procedure DrawPanel(M,Hi: Integer);
Var I,Y,P,X1,X2: Integer; S,Lb,Sc: String; H,En: Boolean;
Begin
 X1:=MRX1[M];X2:=MRX2[M];
 Bx(X1+3,MRY1[M]+3,X2+3,MRY2[M]+3,cDGr);
 Bx(X1,MRY1[M],X2,MRY2[M],cWht);
 Frame(X1,MRY1[M],X2,MRY2[M],cDGr);
 For I:=1 To MCnt[M] Do Begin
  S:=MLb[M,I];
  Y:=ItemY(M,I);
  If S='-' Then Ln(X1+22,Y+3,X2-4,Y+3,cDGr)
  Else Begin
   P:=Pos('|',S);
   If P>0 Then Begin Lb:=Copy(S,1,P-1);Sc:=Copy(S,P+1,20);End
   Else Begin Lb:=S;Sc:='';End;
   H:=(I=Hi);
   En:=(MCm[M,I]>=1000) Or CmdEnabled(MCm[M,I]);
   If H And En Then Bx(X1+2,Y,X2-2,Y+16,cNavy);
   If CmdChecked(MCm[M,I]) Then Begin
    If H And En Then Tx(X1+7,Y+4,#251,cWht) Else Tx(X1+7,Y+4,#251,cBlk);
   End;
   If Not En Then Begin
    TxGray(X1+22,Y+4,Lb);
    If Sc<>'' Then TxGray(X2-8-Length(Sc)*8,Y+4,Sc);
   End Else If H Then Begin
    Tx(X1+22,Y+4,Lb,cWht);
    If Sc<>'' Then Tx(X2-8-Length(Sc)*8,Y+4,Sc,cWht);
   End Else Begin
    Tx(X1+22,Y+4,Lb,cBlk);
    If Sc<>'' Then Tx(X2-8-Length(Sc)*8,Y+4,Sc,cBlk);
   End;
   If MCm[M,I]>=1000 Then Begin
    If H Then Arw(X2-8,Y+8,4,cWht) Else Arw(X2-8,Y+8,4,cBlk);
   End;
  End;
 End;
End;

Procedure DrawMenuOverlay;
Begin
 DrawMenuBar;
 If MenuOpen>0 Then DrawPanel(MenuOpen,MenuHi);
 If SubOpen>0 Then DrawPanel(SubOpen,SubHi);
End;

Function NextItem(M,From,Dir: Integer): Integer;
Var I,N,Tries: Integer;
Begin
 N:=MCnt[M];
 I:=From;Tries:=0;
 Repeat
  I:=I+Dir;Inc(Tries);
  If I<1 Then I:=N;
  If I>N Then I:=1;
  If (MLb[M,I]<>'-') Then Begin
   If (MCm[M,I]>=1000) Or CmdEnabled(MCm[M,I]) Then Begin NextItem:=I;Exit;End;
  End;
 Until Tries>N;
 NextItem:=From;
End;

Function ItemOK(M,I: Integer): Boolean;
Begin
 ItemOK:=(I>0) And (MLb[M,I]<>'-') And ((MCm[M,I]>=1000) Or CmdEnabled(MCm[M,
   I]));
End;

Procedure RunMenu(StartM: Integer; ByMouse: Boolean);
Var M,Hi,S,SHi,H,T,Cm: Integer; E: TEvent; Done,Pick,Full,Over,InSub: Boolean;
Begin
 BuildWindowMenu;
 M:=StartM;S:=0;SHi:=0;InSub:=False;
 LayoutMain(M);
 Hi:=0;
 If Not ByMouse Then Hi:=NextItem(M,0,1);
 MenuOpen:=M;MenuHi:=Hi;SubOpen:=0;SubHi:=0;
 DrawAll;
 Done:=False;Pick:=False;Cm:=0;
 Repeat
  PollEvent(E);
  Full:=False;Over:=False;
  Case E.Kind Of
   4,2,3: Begin
     T:=TitleHit(E.X,E.Y);
     If (E.Kind<>3) And (T>0) And (T<>M) Then Begin
      M:=T;Hi:=0;S:=0;SHi:=0;InSub:=False;LayoutMain(M);Full:=True;
     End Else Begin
      H:=0;
      If S>0 Then H:=DropHit(S,E.X,E.Y);
      If H<>0 Then Begin
       InSub:=True;
       If ItemOK(S,H) Then Begin If H<>SHi Then Begin SHi:=H;Over:=True;End;End
       Else If SHi<>0 Then Begin SHi:=0;Over:=True;End;
       If (E.Kind<>4) And ItemOK(S,H) And ((E.Kind=2) Or (SHi=H)) Then Begin
        Cm:=MCm[S,H];Pick:=True;Done:=True;
       End;
      End Else Begin
       H:=DropHit(M,E.X,E.Y);
       If H<>0 Then Begin
        InSub:=False;
        If ItemOK(M,H) Then Begin
         If H<>Hi Then Begin
          Hi:=H;Over:=True;
          If S>0 Then Begin S:=0;SHi:=0;Full:=True;End;
          If MCm[M,H]>=1000 Then Begin
           S:=MCm[M,H]-1000;SHi:=0;LayoutSub(M,H,S);Full:=True;
          End;
         End;
         If (E.Kind=2) And (MCm[M,H]<1000) Then Begin Cm:=MCm[M,H];Pick:=True;
           Done:=True;End;
         If (E.Kind=3) And (MCm[M,H]<1000) And (Hi=H) Then Begin Cm:=MCm[M,H];
           Pick:=True;Done:=True;End;
        End Else If Hi<>0 Then Begin Hi:=0;Over:=True;End;
       End Else Begin
        If (E.Kind=2) And (T=0) And (DropHit(M,E.X,E.Y)=0) Then Done:=True;
        If (E.Kind=4) And (S=0) And (Hi<>0) Then Begin Hi:=0;Over:=True;End;
       End;
      End;
     End;
    End;
   1: Case E.Key Of
       K_ESC: Begin
         If S>0 Then Begin S:=0;SHi:=0;InSub:=False;Full:=True;End Else
           Done:=True;
        End;
       K_LEFT: Begin
         If S>0 Then Begin S:=0;SHi:=0;InSub:=False;Full:=True;End
         Else Begin Dec(M);If M<1 Then M:=NMENU;Hi:=NextItem(M,0,1);
           LayoutMain(M);Full:=True;End;
        End;
       K_RIGHT: Begin
         If (Hi>0) And (MCm[M,Hi]>=1000) And (S=0) Then Begin
          S:=MCm[M,Hi]-1000;LayoutSub(M,Hi,S);SHi:=NextItem(S,0,1);InSub:=True;
            Full:=True;
         End Else Begin
          Inc(M);If M>NMENU Then M:=1;Hi:=NextItem(M,0,1);S:=0;SHi:=0;
            InSub:=False;
          LayoutMain(M);Full:=True;
         End;
        End;
       K_UP: Begin
         If InSub And (S>0) Then SHi:=NextItem(S,SHi,-1) Else Hi:=NextItem(M,Hi,
           -1);
         Over:=True;
        End;
       K_DOWN: Begin
         If InSub And (S>0) Then SHi:=NextItem(S,SHi,1) Else Hi:=NextItem(M,Hi,
           1);
         Over:=True;
        End;
       K_ENTER: Begin
         If InSub And (S>0) And (SHi>0) Then Begin Cm:=MCm[S,SHi];Pick:=True;
           Done:=True;End
         Else If Hi>0 Then Begin
          If MCm[M,Hi]>=1000 Then Begin
           S:=MCm[M,Hi]-1000;LayoutSub(M,Hi,S);SHi:=NextItem(S,0,1);InSub:=True;
             Full:=True;
          End Else Begin Cm:=MCm[M,Hi];Pick:=True;Done:=True;End;
         End;
        End;
      End;
  End;
  If Full Then Begin MenuOpen:=M;MenuHi:=Hi;SubOpen:=S;SubHi:=SHi;DrawAll;End
  Else If Over Then Begin
   MenuOpen:=M;MenuHi:=Hi;SubOpen:=S;SubHi:=SHi;
   HideMouse;DrawMenuOverlay;ShowMouse;
  End;
 Until Done;
 MenuOpen:=0;MenuHi:=0;SubOpen:=0;SubHi:=0;
 DrawAll;
 If Pick And (Cm>0) Then DoCmd(Cm);
End;

Function AltLetter(K: Word): Integer;
Const
 RowQ : String[10] = 'QWERTYUIOP';
 RowA : String[9] = 'ASDFGHJKL';
 RowZ : String[7] = 'ZXCVBNM';
Var Sc: Integer;
Begin
 AltLetter:=-1;
 If K<256 Then Exit;
 Sc:=K-256;
 Case Sc Of
  16..25: AltLetter:=Ord(RowQ[Sc-15])-65;
  30..38: AltLetter:=Ord(RowA[Sc-29])-65;
  44..50: AltLetter:=Ord(RowZ[Sc-43])-65;
 End;
End;

Procedure MenuByLetter(L: Integer);
Var M: Integer;
Begin
 For M:=1 To NMENU Do
  If MenuMnem(M)=Chr(L+65) Then Begin RunMenu(M,False);Exit;End;
End;

{ ====================================================================== }
{                  FENETRES DE DIAGRAMME, BARRES, PALETTE                }
{ ====================================================================== }

Var
 VZ,VOX,VOY : LongInt;       { zoom (%), origine d'affichage }
 VSX,VSY    : LongInt;       { decalage de defilement (pixels zoomes) }
 VW,VH      : Integer;       { taille de la zone visible }
 CVX,CVY    : Integer;       { origine ecran de la zone de dessin }
 TbCmd      : Array[1..12] Of Integer;
 TbX1       : Array[1..12] Of Integer;
 BoxCmd     : Array[1..16] Of Integer;

Function WsY0: Integer;
Begin
 If ToolBarOn Then WsY0:=TOOL_Y+TOOL_H Else WsY0:=TOOL_Y;
End;

Function WsY1: Integer;
Begin
 If StatusOn Then WsY1:=SCR_H-STAT_H-1 Else WsY1:=SCR_H-1;
End;

Function IconIndex(W: Integer): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To WCnt Do Begin
  If Wn[WZo[I]].Iconic Then Inc(N);
  If WZo[I]=W Then Begin IconIndex:=N-1;Exit;End;
 End;
 IconIndex:=0;
End;

Procedure WinRect(W: Integer; Var X1,Y1,X2,Y2: Integer);
Begin
 If Wn[W].Iconic Then Begin
  X1:=4+IconIndex(W)*164;Y2:=WsY1-1;Y1:=Y2-19;X2:=X1+160;
 End Else If WMax Then Begin
  X1:=0;Y1:=WsY0;X2:=SCR_W-1;Y2:=WsY1;
 End Else Begin
  X1:=Wn[W].X;Y1:=WsY0+Wn[W].Y;X2:=X1+Wn[W].W-1;Y2:=Y1+Wn[W].H-1;
 End;
End;

Procedure CanvasRect(W: Integer; Var X1,Y1,X2,Y2: Integer);
Var A,B,C,D: Integer;
Begin
 WinRect(W,A,B,C,D);
 X1:=A+3;Y1:=B+TITLE_H+2;X2:=C-3-16;Y2:=D-3-16;
End;

Function ContentW(W: Integer): LongInt;
Begin
 ContentW:=LongInt(Mdl^.Dg[Wn[W].Diag].W)*Wn[W].Zoom Div 100+16;
End;

Function ContentH(W: Integer): LongInt;
Begin
 ContentH:=LongInt(Mdl^.Dg[Wn[W].Diag].H)*Wn[W].Zoom Div 100+16;
End;

Procedure ClampScroll(W: Integer);
Var X1,Y1,X2,Y2: Integer; M: LongInt;
Begin
 CanvasRect(W,X1,Y1,X2,Y2);
 M:=ContentW(W)-(X2-X1+1);If M<0 Then M:=0;
 If Wn[W].SX>M Then Wn[W].SX:=M;
 If Wn[W].SX<0 Then Wn[W].SX:=0;
 M:=ContentH(W)-(Y2-Y1+1);If M<0 Then M:=0;
 If Wn[W].SY>M Then Wn[W].SY:=M;
 If Wn[W].SY<0 Then Wn[W].SY:=0;
End;

Procedure SetZoom(W,Z: Integer);
Begin
 If Z<10 Then Z:=10;
 If Z>400 Then Z:=400;
 Wn[W].SX:=Wn[W].SX*Z Div Wn[W].Zoom;
 Wn[W].SY:=Wn[W].SY*Z Div Wn[W].Zoom;
 Wn[W].Zoom:=Z;
 ClampScroll(W);
End;

Procedure FitWin(W: Integer);
Var X1,Y1,X2,Y2,Z1,Z2,Z: Integer; D: Integer;
Begin
 CanvasRect(W,X1,Y1,X2,Y2);
 D:=Wn[W].Diag;
 Z1:=(X2-X1-14)*100 Div Mdl^.Dg[D].W;
 Z2:=(Y2-Y1-14)*100 Div Mdl^.Dg[D].H;
 Z:=Z1;If Z2<Z Then Z:=Z2;
 If Z<10 Then Z:=10;
 If Z>400 Then Z:=400;
 Wn[W].Zoom:=Z;Wn[W].SX:=0;Wn[W].SY:=0;
End;

Function OpenFit(D: Integer): Integer;
Var I,W: Integer; Found: Boolean;
Begin
 Found:=False;
 For I:=1 To MAXWIN Do If Wn[I].Used And (Wn[I].Diag=D) Then Found:=True;
 W:=OpenWin(D);
 If (W>0) And Not Found Then FitWin(W);
 OpenFit:=W;
End;

{ ---- conversions modele <-> ecran (zone de dessin de la fenetre) ---- }

Function SXc(X: LongInt): Integer;
Begin
 SXc:=VOX+X*VZ Div 100-VSX;
End;

Function SYc(Y: LongInt): Integer;
Begin
 SYc:=VOY+Y*VZ Div 100-VSY;
End;

Function MXc(PX: LongInt): LongInt;
Begin
 MXc:=(PX-VOX+VSX)*100 Div VZ;
End;

Function MYc(PY: LongInt): LongInt;
Begin
 MYc:=(PY-VOY+VSY)*100 Div VZ;
End;

Procedure SetView(W: Integer);
Var X1,Y1,X2,Y2: Integer;
Begin
 CanvasRect(W,X1,Y1,X2,Y2);
 VZ:=Wn[W].Zoom;VSX:=Wn[W].SX;VSY:=Wn[W].SY;
 VOX:=0;VOY:=0;CVX:=X1;CVY:=Y1;VW:=X2-X1+1;VH:=Y2-Y1+1;
End;

{ ---- rendu des objets ---- }

Procedure DrawWrap(X1,Y1,X2,Y2: Integer; Const S: String; C,J: Integer);
Var Per,Rows,N,I,P,Last,Start: Integer; L: Array[1..6] Of String[40]; Cur,Wd:
  String;
Begin
 Per:=(X2-X1+1) Div 8;Rows:=(Y2-Y1+1) Div 10;
 If (Per<2) Or (Rows<1) Or (S='') Then Exit;
 If Rows>6 Then Rows:=6;
 If Per>40 Then Per:=40;
 N:=0;Cur:='';Wd:='';
 I:=1;
 While (I<=Length(S)+1) And (N<Rows) Do Begin
  If (I>Length(S)) Or (S[I]=' ') Then Begin
   If Wd<>'' Then Begin
    If Cur='' Then Cur:=Wd
    Else If Length(Cur)+1+Length(Wd)<=Per Then Cur:=Cur+' '+Wd
    Else Begin Inc(N);L[N]:=Cur;Cur:=Wd;End;
    While (Length(Cur)>Per) And (N<Rows) Do Begin
     Inc(N);L[N]:=Copy(Cur,1,Per);Delete(Cur,1,Per);
    End;
    Wd:='';
   End;
  End Else Wd:=Wd+S[I];
  Inc(I);
 End;
 If (Cur<>'') And (N<Rows) Then Begin Inc(N);L[N]:=Cur;End;
 Start:=Y1+((Y2-Y1+1)-N*10) Div 2;
 For I:=1 To N Do
  Case J Of
   1: Tx(X1,Start+(I-1)*10,L[I],C);
   3: Tx(X2-Length(L[I])*8+1,Start+(I-1)*10,L[I],C);
   Else CenterTx(X1,X2,Start+(I-1)*10,L[I],C);
  End;
 P:=0;Last:=0;
End;

Procedure RoundBox(X1,Y1,X2,Y2,R,C: Integer);
Begin
 SetColor(C);SetLineStyle(SolidLn,0,1);
 Line(X1+R,Y1,X2-R,Y1);Line(X1+R,Y2,X2-R,Y2);
 Line(X1,Y1+R,X1,Y2-R);Line(X2,Y1+R,X2,Y2-R);
 Arc(X1+R,Y1+R,90,180,R);Arc(X2-R,Y1+R,0,90,R);
 Arc(X1+R,Y2-R,180,270,R);Arc(X2-R,Y2-R,270,360,R);
End;

Procedure DrawInfoBox(X1,Y1,X2,Y2,C: Integer);
Var R1,R2,MX1,MX2: Integer;
Begin
 R1:=Y1+(Y2-Y1)*34 Div 100;R2:=Y1+(Y2-Y1)*67 Div 100;
 MX1:=X1+(X2-X1)*70 Div 100;MX2:=X1+(X2-X1)*52 Div 100;
 Bx(X1,Y1,X2,Y2,cWht);
 SetColor(C);SetLineStyle(SolidLn,0,1);
 Line(X1+8,Y1,X2-8,Y1);Line(X1,Y1+8,X1,Y2);Line(X2,Y1+8,X2,Y2);
 Line(X1,Y2,X2,Y2);
 Arc(X1+8,Y1+8,90,180,8);Arc(X2-8,Y1+8,0,90,8);
 Line(X1,R1,X2,R1);Line(X1,R2,X2,R2);
 Line(MX1,R1,MX1,R2);Line(MX2,R2,MX2,Y2);
 If VZ<50 Then Exit;
 Tx(X1+4,Y1+3,T5('Nom du mod@gle','Model Name','Modellname',
    'Nombre del modelo','Nome del modello'),cDGr);
 Tx(X1+4,Y1+13,Copy(Cfg.MName,1,(X2-X1) Div 8-1),C);
 Tx(X1+4,R1+3,T5('Cr@eateur','Creator','Ersteller','Creador','Creatore'),
    cDGr);
 Tx(X1+4,R1+13,Copy(Cfg.Author,1,(MX1-X1) Div 8-1),C);
 Tx(MX1+4,R1+3,'Version',cDGr);
 Tx(MX1+4,R1+13,Cfg.Ver,C);
 Tx(X1+4,R2+3,T5('Cr@e@e le','Created','Erstellt','Creado','Creato'),cDGr);
 Tx(X1+4,R2+13,Cfg.Created,C);
 Tx(MX2+4,R2+3,T5('Modifi@e le','Modified','Ge@1ndert','Modificado',
    'Modificato'),cDGr);
 Tx(MX2+4,R2+13,Cfg.Modified,C);
End;

Function ElColor(I: Integer): Integer;
Begin
 If Mdl^.El[I].Hi Then ElColor:=cLRd
 Else If Mdl^.El[I].Col>0 Then ElColor:=Mdl^.El[I].Col-1
 Else ElColor:=cBlk;
End;

Function FillC(I: Integer): Integer;
Begin
 If Mdl^.El[I].Fil>0 Then FillC:=Mdl^.El[I].Fil-1 Else FillC:=cWht;
End;

Function ZoneText(I,Z: Integer): String;
Var K: Integer; C: Integer;
Begin
 ZoneText:='';
 K:=Cfg.ZDesc[Z];
 Case K Of
  2: ZoneText:=Mdl^.El[I].Num;
  3: ZoneText:=Mdl^.El[I].Name;
  4: ZoneText:=Mdl^.El[I].Desc;
  5: If Mdl^.El[I].Res>0 Then ZoneText:=DictLabel(dcRes,Mdl^.El[I].Res);
  6: Begin
      C:=Mdl^.El[I].Child;
      If (C>0) And Mdl^.Dg[C].Used Then ZoneText:=Mdl^.Dg[C].Title;
     End;
 End;
End;

Procedure ZoneLine(X1,X2,Y: Integer; Const S: String; J,C: Integer);
Var T: String;
Begin
 T:=Copy(S,1,(X2-X1-4) Div 8);
 Case J Of
  1: Tx(X1+3,Y,T,C);
  3: Tx(X2-3-Length(T)*8,Y,T,C);
  Else CenterTx(X1,X2,Y,T,C);
 End;
End;

Procedure CurveSeg(X1,Y1,CX,CY,X2,Y2: Integer);
Var T: Integer; PX,PY,QX,QY,U: LongInt;
Begin
 PX:=X1;PY:=Y1;
 For T:=1 To 10 Do Begin
  U:=T*100 Div 10;
  QX:=((100-U)*(100-U)*X1+2*U*(100-U)*CX+U*U*X2) Div 10000;
  QY:=((100-U)*(100-U)*Y1+2*U*(100-U)*CY+U*U*Y2) Div 10000;
  Line(PX,PY,QX,QY);PX:=QX;PY:=QY;
 End;
End;

Procedure DrawElem(I: Integer);
Var X1,Y1,X2,Y2,B,R,C,DX,TY1,TY2,Z,TC,F,Nt: Integer;
Begin
 If Mdl^.El[I].Hid Then Exit;
 X1:=SXc(Mdl^.El[I].X);Y1:=SYc(Mdl^.El[I].Y);
 X2:=SXc(Mdl^.El[I].X+Mdl^.El[I].W);Y2:=SYc(Mdl^.El[I].Y+Mdl^.El[I].H);
 If (X2<0) Or (Y2<0) Or (X1>VW) Or (Y1>VH) Then Exit;
 C:=ElColor(I);F:=FillC(I);Nt:=Cfg.Notation;
 R:=8*VZ Div 100;If R<3 Then R:=3;
 B:=16*VZ Div 100;If B<4 Then B:=4;
 SetLineStyle(SolidLn,0,1);
 Case Mdl^.El[I].Kind Of
  ekProc: Begin
    Bx(X1,Y1,X2,Y2,F);
    TY1:=Y1+2;TY2:=Y2-2;
    If (Nt=2) Or (Nt=4) Then Begin
     SetColor(C);SetFillStyle(SolidFill,F);
     FillEllipse((X1+X2) Div 2,(Y1+Y2) Div 2,(X2-X1) Div 2,(Y2-Y1) Div 2);
     If VZ>=50 Then Begin
      If Cfg.ZDesc[1]>1 Then
       CenterTx(X1,X2,Y1+(Y2-Y1) Div 5,ZoneText(I,1),cMag);
      If Cfg.ZDesc[2]>1 Then
       DrawWrap(X1+8,Y1+(Y2-Y1) Div 3,X2-8,Y2-(Y2-Y1) Div 4,
          ZoneText(I,2),C,2);
      If Cfg.ZDesc[3]>1 Then
       CenterTx(X1,X2,Y2-(Y2-Y1) Div 5-6,ZoneText(I,3),C);
     End;
    End Else Begin
     RoundBox(X1,Y1,X2,Y2,R,C);
     If Cfg.ZDesc[1]>1 Then Begin Ln(X1,Y1+B,X2,Y1+B,C);TY1:=Y1+B+2;End;
     If Cfg.ZDesc[3]>1 Then Begin Ln(X1,Y2-B,X2,Y2-B,C);TY2:=Y2-B-2;End;
     If VZ>=50 Then Begin
      For Z:=1 To 3 Do
       If Cfg.ZDesc[Z]>1 Then Begin
        If Cfg.ZDesc[Z]=2 Then TC:=cMag Else TC:=C;
        Case Z Of
         1: ZoneLine(X1,X2,Y1+(B-7) Div 2+1,ZoneText(I,1),Cfg.ZJus[1],TC);
         2: DrawWrap(X1+3,TY1+1,X2-3,TY2-1,ZoneText(I,2),TC,Cfg.ZJus[2]);
         3: ZoneLine(X1,X2,Y2-B+(B-7) Div 2+1,ZoneText(I,3),Cfg.ZJus[3],TC);
        End;
       End;
     End;
    End;
   End;
  ekStore: Begin
    DX:=(X2-X1)*3 Div 10;If DX<6 Then DX:=6;
    Bx(X1,Y1,X2,Y2,F);
    If (Nt=2) Or (Nt=4) Then Begin
     Ln(X1,Y1,X2,Y1,C);Ln(X1,Y2,X2,Y2,C);
     If VZ>=50 Then DrawWrap(X1+4,Y1+2,X2-4,Y2-2,Mdl^.El[I].Name,C,2);
    End Else If Nt=3 Then Begin
     Ln(X1,Y1,X2,Y1,C);Ln(X1,Y2,X2,Y2,C);Ln(X1,Y1,X1,Y2,C);
     Ln(X1,(Y1+Y2) Div 2,X2,(Y1+Y2) Div 2,C);
     If VZ>=50 Then
      DrawWrap(X1+3,Y1+2,X2-3,(Y1+Y2) Div 2-2,Mdl^.El[I].Name,C,2);
    End Else Begin
     Ln(X1,Y1,X2,Y1,C);Ln(X1,Y2,X2,Y2,C);Ln(X1,Y1,X1,Y2,C);
     Ln(X1+DX,Y1,X1+DX,Y2,C);
     If VZ>=50 Then Begin
      DrawWrap(X1+1,Y1+2,X1+DX-1,Y2-2,Mdl^.El[I].Num,C,1);
      DrawWrap(X1+DX+3,Y1+2,X2-3,Y2-2,Mdl^.El[I].Name,C,1);
     End;
    End;
   End;
  ekEnt: Begin
    Bx(X1,Y1,X2,Y2,F);
    If Nt=3 Then RoundBox(X1,Y1,X2,Y2,R,C)
    Else Begin Frame(X1,Y1,X2,Y2,C);Frame(X1+2,Y1+2,X2-2,Y2-2,C);End;
    If VZ>=50 Then DrawWrap(X1+5,Y1+5,X2-5,Y2-5,ElName(I),C,2);
   End;
  ekInfo: DrawInfoBox(X1,Y1,X2,Y2,C);
  ekText: Begin
    If VZ>=50 Then Begin
     Tx(X1+2,Y1+(Y2-Y1-7) Div 2,
        Copy(Mdl^.El[I].Name,1,(X2-X1) Div 8+4),C);
     If Mdl^.El[I].FS=2 Then
      Tx(X1+3,Y1+(Y2-Y1-7) Div 2,
         Copy(Mdl^.El[I].Name,1,(X2-X1) Div 8+4),C);
    End;
    If Mdl^.El[I].Sel Then Frame(X1,Y1,X2,Y2,cDGr);
   End;
  ekRect: Begin
    If Mdl^.El[I].Fil>0 Then Bx(X1,Y1,X2,Y2,F);
    Frame(X1,Y1,X2,Y2,C);
   End;
  ekRRect: Begin
    If Mdl^.El[I].Fil>0 Then Bx(X1+2,Y1+2,X2-2,Y2-2,F);
    RoundBox(X1,Y1,X2,Y2,R,C);
   End;
  ekEll: Begin
    SetColor(C);SetLineStyle(SolidLn,0,1);
    If Mdl^.El[I].Fil>0 Then Begin
     SetFillStyle(SolidFill,F);
     FillEllipse((X1+X2) Div 2,(Y1+Y2) Div 2,(X2-X1) Div 2,(Y2-Y1) Div 2);
    End Else
     Ellipse((X1+X2) Div 2,(Y1+Y2) Div 2,0,360,(X2-X1) Div 2,(Y2-Y1) Div 2);
   End;
  ekLine: Begin
    SetColor(C);SetLineStyle(SolidLn,0,1);
    Case Mdl^.El[I].FS Of
     2: Begin Line(X1,Y1,X1,Y2);Line(X1,Y2,X2,Y2);End;
     3: CurveSeg(X1,Y2,X2,Y1,X2,Y2);
     Else Line(X1,Y1,X2,Y2);
    End;
   End;
 End;
End;

Procedure ClipRect(I: Integer; TX,TY: LongInt; Var OX,OY: LongInt);
Var CX,CY,DX,DY,HW,HH,T1,T2,T: LongInt;
Begin
 CX:=Mdl^.El[I].X+Mdl^.El[I].W Div 2;CY:=Mdl^.El[I].Y+Mdl^.El[I].H Div 2;
 HW:=Mdl^.El[I].W Div 2;HH:=Mdl^.El[I].H Div 2;
 DX:=TX-CX;DY:=TY-CY;
 OX:=CX;OY:=CY;
 If (DX=0) And (DY=0) Then Exit;
 If DX=0 Then T1:=100000 Else T1:=HW*1000 Div Abs(DX);
 If DY=0 Then T2:=100000 Else T2:=HH*1000 Div Abs(DY);
 If T1<T2 Then T:=T1 Else T:=T2;
 If T>=1000 Then Exit;
 OX:=CX+DX*T Div 1000;OY:=CY+DY*T Div 1000;
End;

Const MAXPT = 12;

Var
 FPX,FPY : Array[1..MAXPT] Of LongInt;
 FPN     : Integer;

{ chemin du flux en coordonnees modele (apres decoupe sur les objets) }
Function FlowPath(F: Integer): Boolean;
Var A,B,K: Integer; CAx,CAy,CBx,CBy,MX,MY,SX,SY,EX,EY,CPX,CPY,U: LongInt;
Begin
 FlowPath:=False;
 A:=FindEl(Mdl^.Fl[F].A);B:=FindEl(Mdl^.Fl[F].B);
 If (A=0) Or (B=0) Then Exit;
 CAx:=Mdl^.El[A].X+Mdl^.El[A].W Div 2;CAy:=Mdl^.El[A].Y+Mdl^.El[A].H Div 2;
 CBx:=Mdl^.El[B].X+Mdl^.El[B].W Div 2;CBy:=Mdl^.El[B].Y+Mdl^.El[B].H Div 2;
 Case Mdl^.Fl[F].Sty Of
  1: Begin
    If Mdl^.Fl[F].Bend Then Begin MX:=Mdl^.Fl[F].BX;MY:=Mdl^.Fl[F].BY;End
    Else Begin MX:=(CAx+CBx) Div 2;MY:=(CAy+CBy) Div 2;End;
    If Abs(CBx-CAx)>=Abs(CBy-CAy) Then Begin
     ClipRect(A,MX,CAy,SX,SY);ClipRect(B,MX,CBy,EX,EY);
     FPN:=4;
     FPX[1]:=SX;FPY[1]:=CAy;FPX[2]:=MX;FPY[2]:=CAy;
     FPX[3]:=MX;FPY[3]:=CBy;FPX[4]:=EX;FPY[4]:=CBy;
    End Else Begin
     ClipRect(A,CAx,MY,SX,SY);ClipRect(B,CBx,MY,EX,EY);
     FPN:=4;
     FPX[1]:=CAx;FPY[1]:=SY;FPX[2]:=CAx;FPY[2]:=MY;
     FPX[3]:=CBx;FPY[3]:=MY;FPX[4]:=CBx;FPY[4]:=EY;
    End;
   End;
  2: Begin
    If Mdl^.Fl[F].Bend Then Begin CPX:=Mdl^.Fl[F].BX;CPY:=Mdl^.Fl[F].BY;End
    Else Begin
     CPX:=(CAx+CBx) Div 2+(CBy-CAy) Div 4;CPY:=(CAy+CBy) Div 2-(CBx-CAx) Div 4;
    End;
    ClipRect(A,CPX,CPY,SX,SY);ClipRect(B,CPX,CPY,EX,EY);
    FPN:=9;
    For K:=0 To 8 Do Begin
     U:=K*100 Div 8;
     FPX[K+1]:=((100-U)*(100-U)*SX+2*U*(100-U)*CPX+U*U*EX) Div 10000;
     FPY[K+1]:=((100-U)*(100-U)*SY+2*U*(100-U)*CPY+U*U*EY) Div 10000;
    End;
   End;
  Else Begin
    If Mdl^.Fl[F].Bend Then Begin
     ClipRect(A,Mdl^.Fl[F].BX,Mdl^.Fl[F].BY,SX,SY);
     ClipRect(B,Mdl^.Fl[F].BX,Mdl^.Fl[F].BY,EX,EY);
     FPN:=3;FPX[2]:=Mdl^.Fl[F].BX;FPY[2]:=Mdl^.Fl[F].BY;
     FPX[1]:=SX;FPY[1]:=SY;FPX[3]:=EX;FPY[3]:=EY;
    End Else Begin
     ClipRect(A,CBx,CBy,SX,SY);ClipRect(B,CAx,CAy,EX,EY);
     FPN:=2;FPX[1]:=SX;FPY[1]:=SY;FPX[2]:=EX;FPY[2]:=EY;
    End;
   End;
 End;
 FlowPath:=True;
End;

{ extremites du flux (premier et dernier point du chemin) }
Function FlowGeom(F: Integer; Var X1,Y1,X2,Y2: LongInt): Boolean;
Begin
 FlowGeom:=False;
 If Not FlowPath(F) Then Exit;
 X1:=FPX[1];Y1:=FPY[1];X2:=FPX[FPN];Y2:=FPY[FPN];
 FlowGeom:=True;
End;

Procedure ArrowHead(X1,Y1,X2,Y2,C: Integer);
Var DX,DY,L,Sz: LongInt; Pt: Array[1..3] Of PointType; PX,PY: LongInt;
Begin
 DX:=X2-X1;DY:=Y2-Y1;
 L:=Trunc(Sqrt(Sqr(DX*1.0)+Sqr(DY*1.0)));
 If L<1 Then Exit;
 Sz:=8*VZ Div 100;If Sz<5 Then Sz:=5;
 PX:=X2-DX*Sz Div L;PY:=Y2-DY*Sz Div L;
 Pt[1].X:=X2;Pt[1].Y:=Y2;
 Pt[2].X:=PX-DY*(Sz Div 2) Div L;Pt[2].Y:=PY+DX*(Sz Div 2) Div L;
 Pt[3].X:=PX+DY*(Sz Div 2) Div L;Pt[3].Y:=PY-DX*(Sz Div 2) Div L;
 SetColor(C);SetFillStyle(SolidFill,C);SetLineStyle(SolidLn,0,1);
 FillPoly(3,Pt);
End;

Function FlowLabel(F: Integer): String;
Var S: String;
Begin
 S:='';
 If Cfg.ShName Then S:=Mdl^.Fl[F].Name;
 If Cfg.ShQual And (Mdl^.Fl[F].Qual>0) Then Begin
  If S<>'' Then S:=S+' ';
  S:=S+'['+DictName(dcQual,Mdl^.Fl[F].Qual)+']';
 End;
 FlowLabel:=S;
End;

Procedure FlowLabelPos(F: Integer; Var LX,LY: Integer);
Var M1,M2: Integer;
Begin
 M1:=(FPN+1) Div 2;M2:=FPN Div 2+1;
 LX:=SXc((FPX[M1]+FPX[M2]) Div 2+Mdl^.Fl[F].LOX);
 LY:=SYc((FPY[M1]+FPY[M2]) Div 2+Mdl^.Fl[F].LOY);
End;

Procedure DrawFlow(F: Integer);
Var K,C,LX,LY: Integer; S: String;
Begin
 If Mdl^.Fl[F].Hid Then Exit;
 If Not FlowPath(F) Then Exit;
 If Mdl^.Fl[F].Sel Then C:=cLBl Else If Mdl^.Fl[F].Hi Then C:=cLRd
 Else If Mdl^.Fl[F].Col>0 Then C:=Mdl^.Fl[F].Col-1 Else C:=cBlk;
 SetColor(C);
 If Mdl^.Fl[F].Dsh=1 Then SetLineStyle(DashedLn,0,1)
 Else SetLineStyle(SolidLn,0,1);
 For K:=1 To FPN-1 Do
  Line(SXc(FPX[K]),SYc(FPY[K]),SXc(FPX[K+1]),SYc(FPY[K+1]));
 SetLineStyle(SolidLn,0,1);
 If Mdl^.Fl[F].Dir In [0,2] Then
  ArrowHead(SXc(FPX[FPN-1]),SYc(FPY[FPN-1]),SXc(FPX[FPN]),SYc(FPY[FPN]),C);
 If Mdl^.Fl[F].Dir In [1,2] Then
  ArrowHead(SXc(FPX[2]),SYc(FPY[2]),SXc(FPX[1]),SYc(FPY[1]),C);
 FlowLabelPos(F,LX,LY);
 If Mdl^.Fl[F].Sel Then Begin
  Bx(SXc(FPX[1])-2,SYc(FPY[1])-2,SXc(FPX[1])+2,SYc(FPY[1])+2,cBlk);
  Bx(SXc(FPX[FPN])-2,SYc(FPY[FPN])-2,SXc(FPX[FPN])+2,SYc(FPY[FPN])+2,cBlk);
  Bx(LX-2,LY-2,LX+2,LY+2,cBlk);
 End;
 If VZ>=50 Then Begin
  S:=FlowLabel(F);
  If S<>'' Then Begin
   S:=Copy(S,1,24);
   Bx(LX-Length(S)*4-1,LY-14,LX+Length(S)*4,LY-5,cWht);
   CenterTx(LX-Length(S)*4,LX+Length(S)*4,LY-13,S,C);
  End;
 End;
End;

Procedure Handles(I: Integer);
Var X1,Y1,X2,Y2,MXx,MYy: Integer;
Begin
 X1:=SXc(Mdl^.El[I].X);Y1:=SYc(Mdl^.El[I].Y);
 X2:=SXc(Mdl^.El[I].X+Mdl^.El[I].W);Y2:=SYc(Mdl^.El[I].Y+Mdl^.El[I].H);
 MXx:=(X1+X2) Div 2;MYy:=(Y1+Y2) Div 2;
 Bx(X1-2,Y1-2,X1+2,Y1+2,cBlk);Bx(X2-2,Y1-2,X2+2,Y1+2,cBlk);
 Bx(X1-2,Y2-2,X1+2,Y2+2,cBlk);Bx(X2-2,Y2-2,X2+2,Y2+2,cBlk);
 Bx(MXx-2,Y1-2,MXx+2,Y1+2,cBlk);Bx(MXx-2,Y2-2,MXx+2,Y2+2,cBlk);
 Bx(X1-2,MYy-2,X1+2,MYy+2,cBlk);Bx(X2-2,MYy-2,X2+2,MYy+2,cBlk);
End;

{ poignee touchee : 1 NO 2 N 3 NE 4 E 5 SE 6 S 7 SO 8 O ; 0 aucune }
Function HandleHit(I: Integer; PX,PY: LongInt): Integer;
Var X1,Y1,X2,Y2,MXx,MYy: Integer;
Function Near(HX,HY: Integer): Boolean;
Begin
 Near:=(Abs(PX-HX)<=4) And (Abs(PY-HY)<=4);
End;
Begin
 HandleHit:=0;
 X1:=SXc(Mdl^.El[I].X);Y1:=SYc(Mdl^.El[I].Y);
 X2:=SXc(Mdl^.El[I].X+Mdl^.El[I].W);Y2:=SYc(Mdl^.El[I].Y+Mdl^.El[I].H);
 MXx:=(X1+X2) Div 2;MYy:=(Y1+Y2) Div 2;
 If Near(X1,Y1) Then HandleHit:=1
 Else If Near(MXx,Y1) Then HandleHit:=2
 Else If Near(X2,Y1) Then HandleHit:=3
 Else If Near(X2,MYy) Then HandleHit:=4
 Else If Near(X2,Y2) Then HandleHit:=5
 Else If Near(MXx,Y2) Then HandleHit:=6
 Else If Near(X1,Y2) Then HandleHit:=7
 Else If Near(X1,MYy) Then HandleHit:=8;
End;

Procedure DrawDiagram(W: Integer);
Var D,I,J,K,R,X1,Y1,X2,Y2,HB,N,GX,GY,G: Integer;
    Ord: Array[1..MAXEL] Of Integer; T: Integer;
Begin
 D:=Wn[W].Diag;
 Bx(0,0,VW-1,VH-1,cWht);
 X1:=SXc(0);Y1:=SYc(0);X2:=SXc(Mdl^.Dg[D].W);Y2:=SYc(Mdl^.Dg[D].H);
 { grille }
 If Cfg.ShowGrid And (VZ>=50) And (Cfg.Grid>=4) Then Begin
  G:=Cfg.Grid;
  GX:=G;
  While GX<Mdl^.Dg[D].W Do Begin
   GY:=G;
   While GY<Mdl^.Dg[D].H Do Begin
    If (SXc(GX)>=0) And (SXc(GX)<VW) And (SYc(GY)>=0) And (SYc(GY)<VH) Then
      PutPixel(SXc(GX),SYc(GY),cDGr);
    Inc(GY,G);
   End;
   Inc(GX,G);
  End;
 End;
 { cadre }
 HB:=24*VZ Div 100;If HB<12 Then HB:=12;
 R:=8*VZ Div 100;If R<3 Then R:=3;
 SetColor(cBlk);SetLineStyle(SolidLn,0,ThickWidth);
 Line(X1+R,Y1,X2-R,Y1);Line(X1,Y1+R,X1,Y2);Line(X2,Y1+R,X2,Y2);Line(X1,Y2,X2,
   Y2);
 Arc(X1+R,Y1+R,90,180,R);Arc(X2-R,Y1+R,0,90,R);
 Line(X1,Y1+HB,X2,Y1+HB);
 SetLineStyle(SolidLn,0,1);
 If VZ>=40 Then CenterTx(X1,X2,Y1+(HB-7) Div 2+2,Mdl^.Dg[D].Title,cBlk);
 { flux puis objets (par Z) }
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) Then DrawFlow(I);
 N:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And Not Mdl^.El[I].Hid Then Begin
   Inc(N);Ord[N]:=I;
  End;
 For I:=1 To N-1 Do
  For J:=I+1 To N Do
   If Mdl^.El[Ord[J]].Z<Mdl^.El[Ord[I]].Z Then Begin
    T:=Ord[I];Ord[I]:=Ord[J];Ord[J]:=T;
   End;
 For I:=1 To N Do DrawElem(Ord[I]);
 K:=0;J:=0;
 For I:=1 To N Do
  If Mdl^.El[Ord[I]].Sel Then Begin Inc(K);J:=Ord[I];End;
 If K=1 Then Handles(J)
 Else If K>1 Then
  For I:=1 To N Do
   If Mdl^.El[Ord[I]].Sel Then Begin
    X1:=SXc(Mdl^.El[Ord[I]].X);Y1:=SYc(Mdl^.El[Ord[I]].Y);
    X2:=SXc(Mdl^.El[Ord[I]].X+Mdl^.El[Ord[I]].W);
      Y2:=SYc(Mdl^.El[Ord[I]].Y+Mdl^.El[Ord[I]].H);
    Bx(X1-2,Y1-2,X1+2,Y1+2,cBlk);Bx(X2-2,Y1-2,X2+2,Y1+2,cBlk);
    Bx(X1-2,Y2-2,X1+2,Y2+2,cBlk);Bx(X2-2,Y2-2,X2+2,Y2+2,cBlk);
   End;
End;

{ ---- icones 16x16 ---- }

Procedure DrawIcon(Id,X,Y: Integer);
Var Pt: Array[1..5] Of PointType;
Begin
 SetLineStyle(SolidLn,0,1);
 Case Id Of
  1: Begin Bx(X+3,Y+1,X+12,Y+14,cWht);Frame(X+3,Y+1,X+12,Y+14,cBlk);Ln(X+9,Y+1,
    X+12,Y+4,cBlk);End;
  2: Begin Bx(X+1,Y+4,X+14,Y+13,cYel);Frame(X+1,Y+4,X+14,Y+13,cBlk);Bx(X+1,Y+2,
    X+6,Y+4,cYel);Frame(X+1,Y+2,X+6,Y+4,cBlk);End;
  3: Begin Bx(X+1,Y+1,X+14,Y+14,cNavy);Bx(X+4,Y+1,X+11,Y+6,cWht);Bx(X+4,Y+9,
    X+11,Y+14,cLGr);End;
  4: Begin Bx(X+1,Y+6,X+14,Y+12,cLGr);Frame(X+1,Y+6,X+14,Y+12,cBlk);Bx(X+4,Y+1,
    X+11,Y+6,cWht);Frame(X+4,Y+1,X+11,Y+6,cBlk);Bx(X+4,Y+10,X+11,Y+14,cWht);
    Frame(X+4,Y+10,X+11,Y+14,cBlk);End;
  5: Begin Ln(X+4,Y+2,X+11,Y+10,cBlk);Ln(X+11,Y+2,X+4,Y+10,cBlk);Circle(X+4,
    Y+12,2);Circle(X+11,Y+12,2);End;
  6: Begin Bx(X+2,Y+1,X+9,Y+10,cWht);Frame(X+2,Y+1,X+9,Y+10,cBlk);Bx(X+6,Y+5,
    X+13,Y+14,cWht);Frame(X+6,Y+5,X+13,Y+14,cBlk);End;
  7: Begin Bx(X+2,Y+2,X+13,Y+14,cBrn);Bx(X+5,Y+1,X+10,Y+3,cLGr);Bx(X+4,Y+5,X+11,
    Y+13,cWht);End;
  8: Begin Arc(X+8,Y+9,0,180,5);Ln(X+3,Y+9,X+3,Y+5,cNavy);Ln(X+3,Y+5,X+1,Y+8,
    cNavy);Ln(X+3,Y+5,X+6,Y+8,cNavy);End;
  9: Begin Arc(X+8,Y+9,0,180,5);Ln(X+13,Y+9,X+13,Y+5,cNavy);Ln(X+13,Y+5,X+10,
    Y+8,cNavy);Ln(X+13,Y+5,X+15,Y+8,cNavy);End;
  10,11,27,37: Begin
    SetColor(cBlk);Circle(X+6,Y+6,5);Ln(X+10,Y+10,X+14,Y+14,cBlk);Ln(X+4,Y+6,
      X+8,Y+6,cBlk);
    If (Id=11) Or (Id=37) Then Ln(X+6,Y+4,X+6,Y+8,cBlk);
   End;
  12: Begin Bx(X+2,Y+1,X+13,Y+14,cMag);Bx(X+3,Y+2,X+12,Y+13,cWht);Ln(X+4,Y+5,
    X+11,Y+5,cMag);Ln(X+4,Y+8,X+11,Y+8,cMag);End;
  20: Begin Frame(X+2,Y+1,X+13,Y+10,cBlk);Ln(X+2,Y+4,X+13,Y+4,cBlk);Ln(X+8,Y+11,
    X+8,Y+14,cBlk);Ln(X+6,Y+12,X+8,Y+14,cBlk);Ln(X+10,Y+12,X+8,Y+14,cBlk);End;
  21: Begin Tx(X+4,Y+4,'A',cBlk);Tx(X+5,Y+4,'A',cBlk);End;
  22: Begin Bx(X+3,Y+1,X+12,Y+14,cWht);Frame(X+3,Y+1,X+12,Y+14,cBlk);Ln(X+5,Y+5,
    X+10,Y+5,cBlk);Ln(X+5,Y+8,X+10,Y+8,cBlk);Ln(X+5,Y+11,X+10,Y+11,cBlk);End;
  23: Begin Frame(X+1,Y+1,X+6,Y+6,cBlk);Frame(X+9,Y+9,X+14,Y+14,cBlk);Ln(X+7,
    Y+7,X+8,Y+8,cBlk);Ln(X+8,Y+8,X+6,Y+8,cBlk);Ln(X+8,Y+8,X+8,Y+6,cBlk);End;
  24: Begin Tx(X+4,Y+4,'#',cBlk);Frame(X+1,Y+2,X+14,Y+13,cBlk);End;
  25: Begin Circle(X+8,Y+4,3);Frame(X+4,Y+8,X+12,Y+14,cBlk);Ln(X+4,Y+8,X+12,Y+8,
    cBlk);End;
  26: Begin Bx(X+2,Y+2,X+13,Y+13,cYel);Frame(X+2,Y+2,X+13,Y+13,cBlk);Ln(X+4,
    Y+10,X+11,Y+4,cBlk);End;
  30: Begin
    Pt[1].X:=X+4;Pt[1].Y:=Y+1;Pt[2].X:=X+4;Pt[2].Y:=Y+13;Pt[3].X:=X+7;
      Pt[3].Y:=Y+10;
    Pt[4].X:=X+11;Pt[4].Y:=Y+10;Pt[5].X:=X+4;Pt[5].Y:=Y+1;
    SetColor(cBlk);SetFillStyle(SolidFill,cBlk);FillPoly(5,Pt);
   End;
  31: Begin RoundBox(X+1,Y+1,X+14,Y+14,3,cBlk);Ln(X+1,Y+5,X+14,Y+5,cBlk);Ln(X+1,
    Y+11,X+14,Y+11,cBlk);End;
  32: Begin Frame(X+1,Y+2,X+14,Y+13,cBlk);Frame(X+3,Y+4,X+12,Y+11,cBlk);End;
  33: Begin Frame(X+1,Y+4,X+14,Y+11,cBlk);Ln(X+5,Y+4,X+5,Y+11,cBlk);End;
  34: Begin Ln(X+1,Y+13,X+12,Y+3,cBlk);Ln(X+12,Y+3,X+8,Y+3,cBlk);Ln(X+12,Y+3,
    X+12,Y+7,cBlk);End;
  35: Begin Ln(X+8,Y+14,X+8,Y+3,cBlk);Ln(X+3,Y+8,X+8,Y+3,cBlk);Ln(X+13,Y+8,X+8,
    Y+3,cBlk);Ln(X+7,Y+14,X+7,Y+4,cBlk);Ln(X+9,Y+14,X+9,Y+4,cBlk);End;
  36: Begin Circle(X+8,Y+8,5);Ln(X+8,Y+1,X+8,Y+14,cBlk);Ln(X+1,Y+8,X+14,Y+8,
    cBlk);End;
 End;
End;

Procedure InitToolbar;
Const Cmds: Array[1..12] Of Integer = (cmNew,cmOpen,cmSave,cmPrint,cmCut,cmCopy,
  cmPaste,cmUndo,cmRedo,cmZoomOut,cmZoomIn,cmHelp);
Var I,X: Integer;
Begin
 X:=4;
 For I:=1 To 12 Do Begin
  If (I=5) Or (I=8) Or (I=10) Or (I=12) Then Inc(X,8);
  TbCmd[I]:=Cmds[I];TbX1[I]:=X;Inc(X,26);
 End;
End;

Function IconOfCmd(Cm: Integer): Integer;
Begin
 Case Cm Of
  cmNew: IconOfCmd:=1; cmOpen: IconOfCmd:=2; cmSave: IconOfCmd:=3;
  cmPrint: IconOfCmd:=4; cmCut: IconOfCmd:=5; cmCopy: IconOfCmd:=6;
  cmPaste: IconOfCmd:=7; cmUndo: IconOfCmd:=8; cmRedo: IconOfCmd:=9;
  cmZoomOut: IconOfCmd:=10; cmZoomIn: IconOfCmd:=11; cmHelp: IconOfCmd:=12;
  Else IconOfCmd:=0;
 End;
End;

Procedure Fade(X1,Y1,X2,Y2: Integer);
Var Y: Integer;
Begin
 SetColor(cLGr);
 For Y:=Y1 To Y2 Do Begin
  If Odd(Y) Then SetLineStyle(UserBitLn,$AAAA,1) Else SetLineStyle(UserBitLn,
    $5555,1);
  Line(X1,Y,X2,Y);
 End;
 SetLineStyle(SolidLn,0,1);
End;

Procedure DrawToolbar;
Var I: Integer; En: Boolean;
Begin
 Bx(0,TOOL_Y,SCR_W-1,TOOL_Y+TOOL_H-1,cLGr);
 Ln(0,TOOL_Y+TOOL_H-1,SCR_W-1,TOOL_Y+TOOL_H-1,cDGr);
 For I:=1 To 12 Do Begin
  En:=CmdEnabled(TbCmd[I]);
  Raised(TbX1[I],TOOL_Y+2,TbX1[I]+23,TOOL_Y+25);
  If En Then DrawIcon(IconOfCmd(TbCmd[I]),TbX1[I]+4,TOOL_Y+6)
  Else Begin
   DrawIcon(IconOfCmd(TbCmd[I]),TbX1[I]+4,TOOL_Y+6);
   Fade(TbX1[I]+3,TOOL_Y+5,TbX1[I]+20,TOOL_Y+22);
  End;
 End;
End;

Function ToolHit(X,Y: LongInt): Integer;
Var I: Integer;
Begin
 ToolHit:=0;
 If Not ToolBarOn Then Exit;
 For I:=1 To 12 Do
  If InBox(X,Y,TbX1[I],TOOL_Y+2,TbX1[I]+23,TOOL_Y+25) Then ToolHit:=TbCmd[I];
End;

{ ---- palette flottante : 2 colonnes x 8 lignes ---- }

Procedure InitBox;
Begin
 { colonne gauche (actions) puis colonne droite (outils) : index = ligne*2-1 /
   ligne*2 }
 BoxCmd[1]:=cmDecomp;  BoxCmd[2]:=1000+tlSelect;
 BoxCmd[3]:=cmProps;   BoxCmd[4]:=1000+tlProc;
 BoxCmd[5]:=cmEnvUp;   BoxCmd[6]:=1000+tlEnt;
 BoxCmd[7]:=cmVerify;  BoxCmd[8]:=1000+tlStore;
 BoxCmd[9]:=1000+tlQual;BoxCmd[10]:=1000+tlFlow;
 BoxCmd[11]:=1000+tlRes;BoxCmd[12]:=cmParentUp;
 BoxCmd[13]:=1000+tlText;BoxCmd[14]:=cmFit;
 BoxCmd[15]:=cmZoomOut;BoxCmd[16]:=cmZoomIn;
End;

Function BoxIcon(K: Integer): Integer;
Begin
 Case K Of
  1: BoxIcon:=20;  2: BoxIcon:=30;
  3: BoxIcon:=22;  4: BoxIcon:=31;
  5: BoxIcon:=23;  6: BoxIcon:=32;
  7: BoxIcon:=26;  8: BoxIcon:=33;
  9: BoxIcon:=24;  10: BoxIcon:=34;
  11: BoxIcon:=25; 12: BoxIcon:=35;
  13: BoxIcon:=21; 14: BoxIcon:=36;
  15: BoxIcon:=10; 16: BoxIcon:=11;
 End;
End;

Procedure BoxRect(Var X1,Y1,X2,Y2: Integer);
Begin
 X1:=TbX;Y1:=TbY;X2:=TbX+59;Y2:=TbY+14+8*26+4;
End;

Procedure DrawToolBox;
Var X1,Y1,X2,Y2,K,BXX,BYY,T: Integer;
Begin
 If Not ToolBoxOn Then Exit;
 BoxRect(X1,Y1,X2,Y2);
 Bx(X1,Y1,X2,Y2,cNavy);
 Bx(X1+2,Y1+2,X2-2,Y1+12,cNavy);
 Raised(X2-14,Y1+1,X2-3,Y1+12);
 Ln(X2-12,Y1+3,X2-5,Y1+10,cLRd);Ln(X2-12,Y1+10,X2-5,Y1+3,cLRd);
 Bx(X1+2,Y1+14,X2-2,Y2-2,cLGr);
 For K:=1 To 16 Do Begin
  BXX:=X1+4+((K-1) Mod 2)*26;BYY:=Y1+16+((K-1) Div 2)*26;
  T:=0;
  If BoxCmd[K]>=1000 Then T:=BoxCmd[K]-1000;
  If (T>0) And (T=CurTool) Then Sunken(BXX,BYY,BXX+24,BYY+24,cLGr)
  Else Raised(BXX,BYY,BXX+24,BYY+24);
  DrawIcon(BoxIcon(K),BXX+5,BYY+5);
  If (BoxCmd[K]<1000) And Not CmdEnabled(BoxCmd[K]) Then Begin
   Fade(BXX+4,BYY+4,BXX+20,BYY+20);
  End;
 End;
End;

Function BoxHit(X,Y: LongInt): Integer;
Var X1,Y1,X2,Y2,K,BXX,BYY: Integer;
Begin
 BoxHit:=0;
 If Not ToolBoxOn Then Exit;
 BoxRect(X1,Y1,X2,Y2);
 If Not InBox(X,Y,X1,Y1,X2,Y2) Then Exit;
 If InBox(X,Y,X2-14,Y1+1,X2-3,Y1+12) Then Begin BoxHit:=-2;Exit;End;
 If Y<Y1+14 Then Begin BoxHit:=-1;Exit;End;
 BoxHit:=-3;
 For K:=1 To 16 Do Begin
  BXX:=X1+4+((K-1) Mod 2)*26;BYY:=Y1+16+((K-1) Div 2)*26;
  If InBox(X,Y,BXX,BYY,BXX+24,BYY+24) Then BoxHit:=K;
 End;
End;

{ ---- barres de defilement ---- }

Procedure DrawScrollBars(W: Integer);
Var A,B,C,D,CX1,CY1,CX2,CY2,TL,TH,Tsz,Tp: Integer; M,V: LongInt;
Begin
 WinRect(W,A,B,C,D);
 CanvasRect(W,CX1,CY1,CX2,CY2);
 { verticale }
 Bx(CX2+2,CY1,C-3,CY2,cLGr);
 Raised(CX2+2,CY1,C-3,CY1+15);Arw((CX2+2+C-3) Div 2,CY1+8,1,cBlk);
 Raised(CX2+2,CY2-15,C-3,CY2);Arw((CX2+2+C-3) Div 2,CY2-7,2,cBlk);
 TL:=CY1+16;TH:=CY2-16-TL;
 M:=ContentH(W);V:=CY2-CY1+1;
 If (TH>10) And (M>V) Then Begin
  Tsz:=TH*V Div M;If Tsz<10 Then Tsz:=10;
  Tp:=TL+(TH-Tsz)*Wn[W].SY Div (M-V);
  Raised(CX2+2,Tp,C-3,Tp+Tsz);
 End Else Raised(CX2+2,TL,C-3,TL+TH-1);
 { horizontale }
 Bx(CX1,CY2+2,CX2,D-3,cLGr);
 Raised(CX1,CY2+2,CX1+15,D-3);Arw(CX1+8,(CY2+2+D-3) Div 2,3,cBlk);
 Raised(CX2-15,CY2+2,CX2,D-3);Arw(CX2-7,(CY2+2+D-3) Div 2,4,cBlk);
 TL:=CX1+16;TH:=CX2-16-TL;
 M:=ContentW(W);V:=CX2-CX1+1;
 If (TH>10) And (M>V) Then Begin
  Tsz:=TH*V Div M;If Tsz<10 Then Tsz:=10;
  Tp:=TL+(TH-Tsz)*Wn[W].SX Div (M-V);
  Raised(Tp,CY2+2,Tp+Tsz,D-3);
 End Else Raised(TL,CY2+2,TL+TH-1,D-3);
 Raised(CX2+2,CY2+2,C-3,D-3);
End;

Procedure DrawWindow(W: Integer; Act: Boolean);
Var A,B,C,D,TC,CX1,CY1,CX2,CY2: Integer; S: String;
Begin
 WinRect(W,A,B,C,D);
 If Act Then TC:=cLBl Else TC:=cDGr;
 If Wn[W].Iconic Then Begin
  Raised(A,B,C,D);
  Bx(A+3,B+3,C-3,D-3,TC);
  Tx(A+8,B+6,Copy(WinTitle(W),1,17),cWht);
  Exit;
 End;
 Raised(A,B,C,D);
 Bx(A+2,B+2,C-2,B+TITLE_H,TC);
 Bx(A+5,B+5,A+11,B+14,cWht);Bx(A+6,B+6,A+10,B+9,cLRd);
 TxB(A+17,B+6,Copy(WinTitle(W),1,(C-A-90) Div 8),cWht);
 Raised(C-52,B+3,C-38,B+16);Bx(C-49,B+13,C-42,B+14,cBlk);
 Raised(C-36,B+3,C-22,B+16);Frame(C-33,B+6,C-26,B+13,cBlk);
 Raised(C-20,B+3,C-5,B+16);Bx(C-20,B+3,C-5,B+16,cLRd);
 Ln(C-17,B+6,C-9,B+13,cWht);Ln(C-17,B+13,C-9,B+6,cWht);
 CanvasRect(W,CX1,CY1,CX2,CY2);
 Sunken(CX1-1,CY1-1,CX2+1,CY2+1,cWht);
 SetView(W);
 SetViewPort(CX1,CY1,CX2,CY2,True);
 DrawDiagram(W);
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 DrawScrollBars(W);
End;

Function WinAt(X,Y: LongInt): Integer;
Var I,W,A,B,C,D: Integer;
Begin
 WinAt:=0;
 For I:=WCnt DownTo 1 Do Begin
  W:=WZo[I];
  WinRect(W,A,B,C,D);
  If InBox(X,Y,A,B,C,D) Then Begin WinAt:=W;Exit;End;
 End;
End;

{ ---- ecran principal ---- }

Procedure DrawStatus;
Var D,W: Integer; S: String;
Begin
 If Not StatusOn Then Exit;
 Bx(0,SCR_H-STAT_H,SCR_W-1,SCR_H-1,cLGr);
 Sunken(2,SCR_H-STAT_H+1,SCR_W-170,SCR_H-2,cLGr);
 Sunken(SCR_W-168,SCR_H-STAT_H+1,SCR_W-3,SCR_H-2,cLGr);
 D:=CurDiag;W:=ActiveWin;
 If StatMsg<>'' Then S:=StatMsg Else S:=T5('Pr@et','Ready','Bereit','Listo',
   'Pronto');
 Tx(8,SCR_H-STAT_H+4,Copy(S,1,(SCR_W-190) Div 8),cBlk);
 If W>0 Then
  Tx(SCR_W-160,SCR_H-STAT_H+4,
    'Zoom '+IntStr(Wn[W].Zoom)+'%'+'  '+IntStr(SelCount(D))+' sel',cBlk);
End;

Procedure DrawMain;
Var I,W: Integer; S: String;
Begin
 { fond de l'espace de travail }
 Bx(0,WsY0,SCR_W-1,WsY1,cDGr);
 { barre de titre de l'application }
 Bx(0,0,SCR_W-1,TITLE_H-1,cLBl);
 Bx(4,3,14,14,cNavy);Bx(5,4,13,8,cLRd);Bx(5,10,13,13,cWht);
 TxB(22,5,'SOLDERRUN-BPM',cWht);
 Raised(SCR_W-52,2,SCR_W-38,15);Raised(SCR_W-37,2,SCR_W-23,15);
 Bx(SCR_W-20,2,SCR_W-4,15,cLRd);Frame(SCR_W-20,2,SCR_W-4,15,cWht);
 Bx(SCR_W-49,12,SCR_W-42,13,cBlk);Frame(SCR_W-34,5,SCR_W-27,12,cBlk);
 Ln(SCR_W-16,5,SCR_W-8,12,cWht);Ln(SCR_W-16,12,SCR_W-8,5,cWht);
 DrawMenuBar;
 If ToolBarOn Then DrawToolbar;
 For I:=1 To WCnt Do
  If Not Wn[WZo[I]].Iconic Then Begin
   SelectDoc(Wn[WZo[I]].Doc);
   DrawWindow(WZo[I],I=WCnt);
  End;
 For I:=1 To WCnt Do
  If Wn[WZo[I]].Iconic Then DrawWindow(WZo[I],False);
 If WCnt>0 Then SelectDoc(Wn[WZo[WCnt]].Doc);
 DrawToolBox;
 DrawStatus;
 If MenuOpen>0 Then Begin
  DrawPanel(MenuOpen,MenuHi);
  If SubOpen>0 Then DrawPanel(SubOpen,SubHi);
 End;
 W:=0;S:='';
End;

Procedure DrawAll;
Begin
 HideMouse;
 DrawMain;
 ShowMouse;
 Dirty:=False;
End;

{ ====================================================================== }
{                  FICHIERS : FORMAT NATIF .SRD                          }
{ ====================================================================== }

Const
 SRMAGIC = 'SRCLONE3';

Function ImportDFD(Const FN: String; P: PModel; D: PDict; Var C: TCfg): Integer;
  Forward;

Procedure XorPass(Var S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=Chr(Ord(S[I]) Xor $5A);
End;

Function WriteSRD(Const FN: String; M: PModel): Boolean;
Var F: File; C: TCfg; Mg: String[8]; OK: Boolean;
Begin
 WriteSRD:=False;
 {$I-}
 Assign(F,FN);Rewrite(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 Cfg.Modified:=TodayStr;
 Mg:=SRMAGIC;C:=Cfg;
 XorPass(C.Pass);
 {$I-}
 BlockWrite(F,Mg[1],8);
 BlockWrite(F,C,SizeOf(C));
 BlockWrite(F,Dict^,SizeOf(TDict));
 BlockWrite(F,M^,SizeOf(TModel));
 Close(F);
 {$I+}
 OK:=(IOResult=0);
 WriteSRD:=OK;
End;

{ 0 ok, 1 erreur d'E/S, 2 format invalide }
Function ReadSRD(Const FN: String; P: PModel; D: PDict; Var C: TCfg): Integer;
Var F: File; Mg: String[8]; Rd: Word; Res: Integer;
Begin
 ReadSRD:=1;
 {$I-}
 Assign(F,FN);Reset(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 Mg[0]:=#8;
 {$I-}
 BlockRead(F,Mg[1],8,Rd);
 {$I+}
 If (Rd<>8) Or (Mg<>SRMAGIC) Then Begin Close(F);ReadSRD:=2;Exit;End;
 Res:=0;
 {$I-}
 BlockRead(F,C,SizeOf(C),Rd);If Rd<>SizeOf(C) Then Res:=2;
 If Res=0 Then Begin BlockRead(F,D^,SizeOf(TDict),Rd);If Rd<>SizeOf(TDict) Then
   Res:=2;End;
 If Res=0 Then Begin BlockRead(F,P^,SizeOf(TModel),Rd);If Rd<>SizeOf(TModel)
   Then Res:=2;End;
 Close(F);
 {$I+}
 If IOResult<>0 Then Res:=1;
 XorPass(C.Pass);
 ReadSRD:=Res;
End;

Function IsDFDFile(Const FN: String): Boolean;
Var F: File; B: Array[1..8] Of Char; Rd: Word;
Begin
 IsDFDFile:=False;
 {$I-}
 Assign(F,FN);Reset(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 {$I-}
 BlockRead(F,B,8,Rd);
 Close(F);
 {$I+}
 If IOResult<>0 Then Exit;
 IsDFDFile:=(Rd=8) And (B[1]=#7) And (Copy(B[2]+B[3]+B[4]+B[5]+B[6]+B[7]+B[8],1,
   7)='VERSION');
End;

Function ReadAnyFile(Const FN: String; P: PModel; D: PDict; Var C: TCfg):
  Integer;
Begin
 If IsDFDFile(FN) Then ReadAnyFile:=ImportDFD(FN,P,D,C)
 Else ReadAnyFile:=ReadSRD(FN,P,D,C);
End;

{ ====================================================================== }
{                  GOTO, PROPRIETES, LISTES                              }
{ ====================================================================== }

Procedure CenterOn(W: Integer; X,Y: LongInt);
Var CX1,CY1,CX2,CY2: Integer;
Begin
 CanvasRect(W,CX1,CY1,CX2,CY2);
 Wn[W].SX:=X*Wn[W].Zoom Div 100-(CX2-CX1+1) Div 2;
 Wn[W].SY:=Y*Wn[W].Zoom Div 100-(CY2-CY1+1) Div 2;
 ClampScroll(W);
End;

Procedure GotoElem(I: Integer);
Var W: Integer;
Begin
 W:=OpenFit(Mdl^.El[I].Diag);
 If W=0 Then Exit;
 ClearSel;
 Mdl^.El[I].Sel:=True;Mdl^.El[I].Hid:=False;
 CenterOn(W,Mdl^.El[I].X+Mdl^.El[I].W Div 2,Mdl^.El[I].Y+Mdl^.El[I].H Div 2);
 DrawAll;
End;

Procedure ElemProps(I: Integer);
Var K,N,Cn: Integer; Ch: Integer; S: String;
Begin
 If Mdl^.El[I].Kind=ekInfo Then Begin
  FormBegin(T5('Nom du mod@gle','Model Name','Modellname',
     'Nombre del modelo','Nome del modello'));
  FormAdd(0,T5('Nom du mod@gle','Model name','Modellname',
     'Nombre del modelo','Nome del modello'),Cfg.MName,40,'');
  FormAdd(0,T5('Cr@eateur','Creator','Ersteller','Creador','Creatore'),
     Cfg.Author,40,'');
  FormAdd(0,'Version',Cfg.Ver,10,'');
  If RunForm Then Begin
   PushUndo;
   Cfg.MName:=Frm.Val[1];Cfg.Author:=Frm.Val[2];Cfg.Ver:=Frm.Val[3];
  End;
  Exit;
 End;
 FormBegin(T5('Propri@et@es','Properties','Eigenschaften','Propiedades',
   'Propriet@r'));
 FormAdd(0,T5('Num@ero','Number','Nummer','N@vmero','Numero'),Mdl^.El[I].Num,12,
   '');
 FormAdd(0,T5('Nom','Name','Name','Nombre','Nome'),Mdl^.El[I].Name,40,'');
 If Mdl^.El[I].Kind<>ekText Then
  FormAdd(0,'Description',Mdl^.El[I].Desc,40,'');
 If Mdl^.El[I].Kind=ekProc Then
  FormAdd(3,T5('Ressource','Resource','Ressource','Recurso','Risorsa'),
    IntStr(Mdl^.El[I].Res),0,IntStr(dcRes));
 If Mdl^.El[I].Kind<>ekText Then Begin
  If Cfg.UdfN[1]<>'' Then FormAdd(0,Cfg.UdfN[1],Mdl^.El[I].U1,10,'');
  If Cfg.UdfN[2]<>'' Then FormAdd(0,Cfg.UdfN[2],Mdl^.El[I].U2,10,'');
  If Cfg.UdfN[3]<>'' Then FormAdd(0,Cfg.UdfN[3],Mdl^.El[I].U3,10,'');
 End;
 If Not RunForm Then Exit;
 PushUndo;
 N:=1;
 Mdl^.El[I].Num:=Frm.Val[N];Inc(N);
 Mdl^.El[I].Name:=Frm.Val[N];Inc(N);
 If Mdl^.El[I].Kind<>ekText Then Begin Mdl^.El[I].Desc:=Frm.Val[N];Inc(N);End;
 If Mdl^.El[I].Kind=ekProc Then Begin Mdl^.El[I].Res:=ValInt(Frm.Val[N],0);
   Inc(N);End;
 If Mdl^.El[I].Kind<>ekText Then Begin
  If Cfg.UdfN[1]<>'' Then Begin Mdl^.El[I].U1:=Frm.Val[N];Inc(N);End;
  If Cfg.UdfN[2]<>'' Then Begin Mdl^.El[I].U2:=Frm.Val[N];Inc(N);End;
  If Cfg.UdfN[3]<>'' Then Begin Mdl^.El[I].U3:=Frm.Val[N];Inc(N);End;
 End;
 Cn:=Mdl^.El[I].Child;
 If (Cn>0) And Mdl^.Dg[Cn].Used Then Begin
  If Mdl^.El[I].Name<>'' Then Mdl^.Dg[Cn].Title:=Mdl^.El[I].Name Else
    Mdl^.Dg[Cn].Title:=Mdl^.El[I].Num;
 End;
 K:=0;Ch:=0;S:='';
End;

Procedure FlowProps(F: Integer);
Begin
 FormBegin(T5('Propri@et@es du flux','Flow Properties','Flusseigenschaften',
   'Propiedades del flujo','Propriet@r del flusso'));
 FormAdd(0,T5('Num@ero','Number','Nummer','N@vmero','Numero'),Mdl^.Fl[F].Num,8,
   '');
 FormAdd(0,T5('Nom','Name','Name','Nombre','Nome'),Mdl^.Fl[F].Name,30,'');
 FormAdd(0,'Description',Mdl^.Fl[F].Desc,40,'');
 FormAdd(3,T5('Qualifiant','Qualifier','Qualifizierer','Calificador',
   'Qualificatore'),IntStr(Mdl^.Fl[F].Qual),0,IntStr(dcQual));
 If Not RunForm Then Exit;
 PushUndo;
 Mdl^.Fl[F].Num:=Frm.Val[1];Mdl^.Fl[F].Name:=Frm.Val[2];
 Mdl^.Fl[F].Desc:=Frm.Val[3];Mdl^.Fl[F].Qual:=ValInt(Frm.Val[4],0);
End;

Function FlowDesc(F: Integer): String;
Var A,B: Integer; S: String;
Begin
 A:=FindEl(Mdl^.Fl[F].A);B:=FindEl(Mdl^.Fl[F].B);
 S:='';
 If (A>0) And (B>0) Then S:=' ('+Copy(ElName(A),1,14)+' > '+Copy(ElName(B),1,
   14)+')';
 FlowDesc:=Pad(Mdl^.Fl[F].Num,6)+Copy(Mdl^.Fl[F].Name,1,26)+S;
End;

Function FirstSel(D: Integer; Var IsFlow: Boolean): Integer;
Var I: Integer;
Begin
 FirstSel:=0;IsFlow:=False;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then Begin
    FirstSel:=I;Exit;End;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And Mdl^.Fl[I].Sel And (Mdl^.Fl[I].Diag=D) Then Begin
    FirstSel:=I;IsFlow:=True;Exit;End;
End;

Procedure PropsOfSel;
Var I: Integer; IsF: Boolean;
Begin
 I:=FirstSel(CurDiag,IsF);
 If I=0 Then Begin
  Msg(T5('S@electionnez d''abord un objet.','Select an object first.',
    'Zuerst ein Objekt ausw@1hlen.','Seleccione primero un objeto.',
    'Selezionare prima un oggetto.'));
  Exit;
 End;
 If IsF Then FlowProps(I) Else ElemProps(I);
 DrawAll;
End;

{ ---- listes du modele ---- }

Function ListTitle(Kind,Cat: Integer): String;
Begin
 Case Kind Of
  1: ListTitle:=T5('Processus','Processes','Prozesse','Procesos','Processi');
  2: ListTitle:=T5('Flux','Flows','Fl@3sse','Flujos','Flussi');
  3: ListTitle:=T5('D@ep@ots','Stores','Speicher','Almacenes','Archivi');
  4: ListTitle:=T5('Entit@es externes','External Entities','Externe Entit@1ten',
    'Entidades externas','Entit@r esterne');
  5: ListTitle:=T5('Diagrammes','Diagrams','Diagramme','Diagramas','Diagrammi');
  Else Case Cat Of
   dcRes: ListTitle:=T5('Ressources','Resources','Ressourcen','Recursos',
     'Risorse');
   dcQual: ListTitle:=T5('Qualificatifs','Qualifiers','Qualifizierer',
     'Calificadores','Qualificatori');
   dcDom: ListTitle:=T5('Domaines','Domains','Dom@1nen','Dominios','Domini');
   dcType: ListTitle:=T5('Types de donn@ees','Data Types','Datentypen',
     'Tipos de datos','Tipi di dati');
   dcComm: ListTitle:=T5('Items communs','Common Items','Gemeinsame Elemente',
     'Elementos comunes','Elementi comuni');
   dcStruct: ListTitle:=T5('Structures de donn@ees','Data Structures',
     'Datenstrukturen','Estructuras de datos','Strutture dati');
   dcTarget: ListTitle:=T5('Syst@gmes cibles','Target Systems','Zielsysteme',
     'Sistemas de destino','Sistemi di destinazione');
   dcRule: ListTitle:=T5('R@gles d''affaires','Business Rules',
     'Gesch@1ftsregeln','Reglas de negocio','Regole di business');
   dcEvent: ListTitle:=T5('Ev@enements','Events','Ereignisse','Eventos',
     'Eventi');
   Else ListTitle:=T5('Sites','Locations','Standorte','Ubicaciones','Sedi');
  End;
 End;
End;

Procedure BuildList(Kind,Cat: Integer);
Var I,N: Integer; Ek: Integer;
Begin
 TLClear;
 Case Kind Of
  1,3,4: Begin
    Ek:=ekProc;If Kind=3 Then Ek:=ekStore;If Kind=4 Then Ek:=ekEnt;
    For I:=1 To MAXEL Do
     If Mdl^.El[I].Used And (Mdl^.El[I].Kind=Ek) Then Begin
      TLAdd(Pad(Mdl^.El[I].Num,9)+Pad(Mdl^.El[I].Name,
        26)+' ['+Copy(DiagTitle(Mdl^.El[I].Diag),1,12)+']');
      LRef[TLN]:=I;
     End;
   End;
  2: For I:=1 To MAXFL Do
      If Mdl^.Fl[I].Used Then Begin TLAdd(FlowDesc(I));LRef[TLN]:=I;End;
  5: Begin
    N:=0;
    For I:=1 To MAXDG Do
     If Mdl^.Dg[I].Used Then Begin
      Inc(N);TLAdd(Pad(IntStr(N),4)+Pad(Mdl^.Dg[I].Title,40));LRef[TLN]:=I;
     End;
   End;
  Else For I:=1 To MAXDE Do
        If Dict^[Cat,I].Name<>'' Then Begin
         TLAdd(Pad(Dict^[Cat,I].Name,22)+Dict^[Cat,I].Desc);LRef[TLN]:=I;
        End;
 End;
End;

Procedure DictEdit(Cat,Slot: Integer);
Var NewS: Boolean;
Begin
 NewS:=(Slot=0);
 If NewS Then Begin
  For Slot:=1 To MAXDE Do If Dict^[Cat,Slot].Name='' Then Begin
   FormBegin(ListTitle(6,Cat));
   FormAdd(0,T5('Nom','Name','Name','Nombre','Nome'),'',20,'');
   FormAdd(0,'Description','',44,'');
   If RunForm Then Begin
    If TrimStr(Frm.Val[1])<>'' Then Begin
     Dict^[Cat,Slot].Name:=TrimStr(Frm.Val[1]);Dict^[Cat,Slot].Desc:=Frm.Val[2];
       Modified:=True;
    End;
   End;
   Exit;
  End;
  Msg(T5('Liste pleine.','List is full.','Liste ist voll.','Lista llena.',
    'Elenco pieno.'));
  Exit;
 End;
 FormBegin(ListTitle(6,Cat));
 FormAdd(0,T5('Nom','Name','Name','Nombre','Nome'),Dict^[Cat,Slot].Name,20,'');
 FormAdd(0,'Description',Dict^[Cat,Slot].Desc,44,'');
 If RunForm Then Begin
  If TrimStr(Frm.Val[1])<>'' Then Begin
   Dict^[Cat,Slot].Name:=TrimStr(Frm.Val[1]);Dict^[Cat,Slot].Desc:=Frm.Val[2];
     Modified:=True;
  End;
 End;
End;

Procedure ModelList(Kind,Cat: Integer);
Var Sel,R,I,Ref: Integer; Btns: String; Done: Boolean;
Begin
 Sel:=1;Done:=False;
 Repeat
  BuildList(Kind,Cat);
  If TLN=0 Then Begin TLAdd(T5('(aucun)','(none)','(keine)','(ninguno)',
    '(nessuno)'));LRef[1]:=0;End;
  Case Kind Of
   1,2,3,4: Btns:=T5('Aller @a|Propri@et@es...|Supprimer|Fermer',
     'Go to|Properties...|Delete|Close',
     'Gehe zu|Eigenschaften...|L@2schen|Schlie@7en',
     'Ir a|Propiedades...|Borrar|Cerrar','Vai a|Propriet@r...|Elimina|Chiudi');
   5: Btns:=T5('Ouvrir|Supprimer|Fermer','Open|Delete|Close',
     '@2ffnen|L@2schen|Schlie@7en','Abrir|Borrar|Cerrar','Apri|Elimina|Chiudi');
   Else Btns:=T5('Ajouter...|Modifier...|Supprimer|Fermer',
     'Add...|Edit...|Delete|Close',
     'Hinzuf@3gen...|@4ndern...|L@2schen|Schlie@7en',
     'A@nadir...|Modificar...|Borrar|Cerrar',
     'Aggiungi...|Modifica...|Elimina|Chiudi');
  End;
  R:=ListBox(ListTitle(Kind,Cat),Btns,Sel);
  Ref:=0;
  If (Sel>=1) And (Sel<=TLN) Then Ref:=LRef[Sel];
  Case Kind Of
   1,2,3,4: Case R Of
     1: If Ref>0 Then Begin
         If Kind=2 Then Begin
          I:=OpenFit(Mdl^.Fl[Ref].Diag);
          ClearSel;Mdl^.Fl[Ref].Sel:=True;
         End Else GotoElem(Ref);
         Done:=True;
        End;
     2: If Ref>0 Then Begin If Kind=2 Then FlowProps(Ref) Else ElemProps(Ref);
       End;
     3: If Ref>0 Then Begin
         If MsgBox(T5('Supprimer cet objet ?','Delete this object?',
           'Dieses Objekt l@2schen?','@?Borrar este objeto?',
           'Eliminare questo oggetto?'),4)=1 Then Begin
          PushUndo;
          If Kind=2 Then Mdl^.Fl[Ref].Used:=False Else DelEl(Ref);
          FixWindows;
         End;
        End;
     Else Done:=True;
    End;
   5: Case R Of
     1: If Ref>0 Then Begin OpenFit(Ref);Done:=True;End;
     2: If Ref>0 Then Begin
         If Mdl^.Dg[Ref].Parent=0 Then
          Msg(T5('Le diagramme racine ne peut pas @etre supprim@e.',
            'The root diagram cannot be deleted.',
            'Das Wurzeldiagramm kann nicht gel@2scht werden.',
            'El diagrama ra@jz no se puede borrar.',
            'Il diagramma radice non pu@m essere eliminato.'))
         Else If MsgBox(T5('Supprimer ce diagramme et ses sous-diagrammes ?',
           'Delete this diagram and its sub-diagrams?',
           'Dieses Diagramm und seine Unterdiagramme l@2schen?',
           '@?Borrar este diagrama y sus subdiagramas?',
           'Eliminare questo diagramma e i sottodiagrammi?'),4)=1 Then Begin
          PushUndo;
          I:=FindEl(Mdl^.Dg[Ref].Parent);
          If I>0 Then Mdl^.El[I].Child:=0;
          DelDiag(Ref);
         End;
        End;
     Else Done:=True;
    End;
   Else Case R Of
     1: DictEdit(Cat,0);
     2: If Ref>0 Then DictEdit(Cat,Ref);
     3: If Ref>0 Then Begin
         If MsgBox(T5('Supprimer cet @el@ement ?','Delete this entry?',
           'Diesen Eintrag l@2schen?','@?Borrar esta entrada?',
           'Eliminare questa voce?'),4)=1 Then Begin
          Dict^[Cat,Ref].Name:='';Dict^[Cat,Ref].Desc:='';
          If Cat=dcRes Then
           For I:=1 To MAXEL Do If Mdl^.El[I].Res=Ref Then Mdl^.El[I].Res:=0;
          If Cat=dcQual Then
           For I:=1 To MAXFL Do If Mdl^.Fl[I].Qual=Ref Then Mdl^.Fl[I].Qual:=0;
          Modified:=True;
         End;
        End;
     Else Done:=True;
    End;
  End;
  If R=0 Then Done:=True;
 Until Done;
 DrawAll;
End;

{ ---- descriptions ---- }

Procedure CmdModelDesc;
Var R,I: Integer; Found: Boolean;
Begin
 FormBegin(T5('Description du mod@gle','Model Description','Modellbeschreibung',
   'Descripci@pn del modelo','Descrizione del modello'));
 FormAdd(0,T5('Nom du mod@gle','Model name','Modellname','Nombre del modelo',
   'Nome del modello'),Cfg.MName,40,'');
 FormAdd(0,'Description',Cfg.MDesc,60,'');
If RunForm Then Begin
  Cfg.MName:=Frm.Val[1];Cfg.MDesc:=Frm.Val[2];Modified:=True;
  R:=RootDiag;Found:=False;
  For I:=1 To MAXEL Do
   If Mdl^.El[I].Used And (Mdl^.El[I].Kind=ekInfo) Then Found:=True;
  If (R>0) And Not Found Then Begin
   PushUndo;
   I:=NewEl(ekInfo,R,Mdl^.Dg[R].W Div 2,Mdl^.Dg[R].H-70);
  End;
 End;
End;

Procedure CmdProjDesc;
Begin
 FormBegin(T5('Description du projet','Project Description',
   'Projektbeschreibung','Descripci@pn del proyecto',
   'Descrizione del progetto'));
 FormAdd(0,T5('Nom du projet','Project name','Projektname',
   'Nombre del proyecto','Nome del progetto'),Cfg.ProjName,40,'');
 FormAdd(0,T5('Auteur','Author','Autor','Autor','Autore'),Cfg.Author,40,'');
 FormAdd(0,'Version',Cfg.Ver,10,'');
 FormAdd(0,'Description',Cfg.Desc1,60,'');
 FormAdd(0,'Description',Cfg.Desc2,60,'');
 If RunForm Then Begin
  Cfg.ProjName:=Frm.Val[1];Cfg.Author:=Frm.Val[2];Cfg.Ver:=Frm.Val[3];
  Cfg.Desc1:=Frm.Val[4];Cfg.Desc2:=Frm.Val[5];Modified:=True;
 End;
End;

Procedure CmdUdf;
Var I: Integer;
Begin
 FormBegin(T5('Champs utilisateur','User Defined Fields',
   'Benutzerdefinierte Felder','Campos definidos por el usuario',
   'Campi definiti dall''utente'));
 For I:=1 To 3 Do
  FormAdd(0,T5('Champ ','Field ','Feld ','Campo ','Campo ')+IntStr(I),
    Cfg.UdfN[I],16,'');
 If RunForm Then Begin
  For I:=1 To 3 Do Cfg.UdfN[I]:=Frm.Val[I];
  Modified:=True;
 End;
End;

{ ---- rapports ---- }

Procedure TreeLines(D,Lev: Integer);
Var I: Integer; S: String;
Begin
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].Kind=ekProc) Then
    Begin
   S:='';
   If Lev>0 Then S:=Copy('                                        ',1,Lev*3);
   TLAdd(S+Mdl^.El[I].Num+' '+Mdl^.El[I].Name);
   LRef[TLN]:=I;
   If (Mdl^.El[I].Child>0) And Mdl^.Dg[Mdl^.El[I].Child].Used Then
     TreeLines(Mdl^.El[I].Child,Lev+1);
  End;
End;

Function Dbl(Const S: String): String;
Var R: String; I: Integer;
Begin
 R:='';
 For I:=1 To Length(S) Do R:=R+'=';
 Dbl:=R;
End;

Procedure GenReport(K: Integer);
Var I,J,R: Integer; T: String;
Begin
 TLClear;
 Case K Of
  1: Begin
    T:=T5('Liste des processus','Process list','Prozessliste',
      'Lista de procesos','Elenco dei processi');
    TLAdd(T);TLAdd(Dbl(T));
    For I:=1 To MAXEL Do
     If Mdl^.El[I].Used And (Mdl^.El[I].Kind=ekProc) Then
      TLAdd(Pad(Mdl^.El[I].Num,10)+Pad(Mdl^.El[I].Name,34)+Pad(DictLabel(dcRes,
        Mdl^.El[I].Res),16)+DiagTitle(Mdl^.El[I].Diag));
   End;
  2: Begin
    T:=T5('Liste des flux','Flow list','Flussliste','Lista de flujos',
      'Elenco dei flussi');
    TLAdd(T);TLAdd(Dbl(T));
    For I:=1 To MAXFL Do If Mdl^.Fl[I].Used Then
      TLAdd(FlowDesc(I)+' ['+DictName(dcQual,Mdl^.Fl[I].Qual)+']');
   End;
  3: Begin
    T:=T5('Entrep@ots et entit@es externes','Stores and external entities',
      'Speicher und externe Entit@1ten','Almacenes y entidades externas',
      'Archivi ed entit@r esterne');
    TLAdd(Dc(T));TLAdd(Dbl(Dc(T)));
    For I:=1 To MAXEL Do
     If Mdl^.El[I].Used And (Mdl^.El[I].Kind In [ekStore,ekEnt]) Then
      TLAdd(Pad(Mdl^.El[I].Num,10)+Pad(Mdl^.El[I].Name,34)+Mdl^.El[I].Desc);
   End;
  4: Begin
    T:=T5('Dictionnaire de donn@ees','Data dictionary','Datenw@2rterbuch',
      'Diccionario de datos','Dizionario dati');
    TLAdd(T);TLAdd(Dbl(T));
    For J:=1 To NCAT Do Begin
     R:=0;
     For I:=1 To MAXDE Do If Dict^[J,I].Name<>'' Then Inc(R);
     If R>0 Then Begin
      TLAdd('');TLAdd('['+ListTitle(6,J)+']');
      For I:=1 To MAXDE Do
       If Dict^[J,I].Name<>'' Then TLAdd('  '+Pad(Dict^[J,I].Name,22)+Dict^[J,
         I].Desc);
     End;
    End;
   End;
  Else Begin
    T:=T5('Arbre des processus','Process tree','Prozessbaum',
      '@rrbol de procesos','Albero dei processi');
    TLAdd(T);TLAdd(Dbl(T));
    R:=RootDiag;
    If R>0 Then TreeLines(R,0);
   End;
 End;
 If TLN=0 Then TLAdd('-');
End;

Procedure ShowReport(K: Integer);
Begin
 GenReport(K);
 ShowText(T5('Rapport','Report','Bericht','Informe','Rapporto'));
End;

Procedure CmdReport;
Begin
 FormBegin(T5('Rapport','Report','Bericht','Informe','Rapporto'));
 FormAdd(4,T5('Type de rapport','Report type','Berichtstyp','Tipo de informe',
   'Tipo di rapporto'),'1',0,
   T5('Processus|Flux|Entrep@ots et entit@es|Dictionnaire|Arbre',
     'Processes|Flows|Stores and entities|Dictionary|Tree',
     'Prozesse|Fl@3sse|Speicher und Entit@1ten|W@2rterbuch|Baum',
     'Procesos|Flujos|Almacenes y entidades|Diccionario|@rrbol',
     'Processi|Flussi|Archivi ed entit@r|Dizionario|Albero'));
 If RunForm Then ShowReport(ValInt(Frm.Val[1],1));
End;

{ ---- verification d'integrite ---- }

Function FlowCount(Id: Integer; Var NIn,NOut: Integer): Integer;
Var I: Integer;
Begin
 NIn:=0;NOut:=0;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used Then Begin
   If Mdl^.Fl[I].A=Id Then Inc(NOut);
   If Mdl^.Fl[I].B=Id Then Inc(NIn);
  End;
 FlowCount:=NIn+NOut;
End;

Procedure CmdVerify;
Var I,J,NI,NO,Bad: Integer; S: String;
Begin
 TLClear;Bad:=0;
 TLAdd(T5('V@erification de l''int@egrit@e','Integrity check',
   'Integrit@1tspr@3fung','Verificaci@pn de integridad',
   'Verifica di integrit@r'));
 TLAdd('');
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used Then Begin
   S:=Mdl^.El[I].Num+' '+Mdl^.El[I].Name;
   FlowCount(Mdl^.El[I].Id,NI,NO);
   If Mdl^.El[I].Kind=ekProc Then Begin
    If Mdl^.El[I].Name='' Then Begin Inc(Bad);
      TLAdd(Mdl^.El[I].Num+' : '+T5('processus sans nom','process without name',
      'Prozess ohne Namen','proceso sin nombre','processo senza nome'));End;
    If (NI=0) And (NO>0) Then Begin Inc(Bad);
      TLAdd(S+' : '+T5('aucune entr@ee (miracle)','no input (miracle)',
      'keine Eingabe','sin entradas','nessun ingresso'));End;
    If (NO=0) And (NI>0) Then Begin Inc(Bad);
      TLAdd(S+' : '+T5('aucune sortie (trou noir)','no output (black hole)',
      'keine Ausgabe','sin salidas','nessuna uscita'));End;
    If (NI=0) And (NO=0) Then Begin Inc(Bad);TLAdd(S+' : '+T5('aucun flux',
      'no flows','keine Fl@3sse','sin flujos','nessun flusso'));End;
    If (Mdl^.El[I].Child>0) And Mdl^.Dg[Mdl^.El[I].Child].Used Then Begin
     J:=0;
     For NI:=1 To MAXEL Do
      If Mdl^.El[NI].Used And (Mdl^.El[NI].Diag=Mdl^.El[I].Child) Then Inc(J);
     If J=0 Then Begin Inc(Bad);TLAdd(S+' : '+T5('diagramme enfant vide',
       'empty child diagram','leeres Unterdiagramm','diagrama hijo vac@jo',
       'diagramma figlio vuoto'));End;
    End;
   End Else If (Mdl^.El[I].Kind<>ekText) And (Mdl^.El[I].Kind<>ekInfo)
      And (NI+NO=0) Then Begin
    Inc(Bad);TLAdd(S+' : '+T5('objet non connect@e','unconnected object',
      'nicht verbundenes Objekt','objeto no conectado',
      'oggetto non collegato'));
   End;
   For J:=I+1 To MAXEL Do
    If Mdl^.El[J].Used And (Mdl^.El[J].Kind=Mdl^.El[I].Kind) And
      (Mdl^.El[J].Num=Mdl^.El[I].Num)
       And (Mdl^.El[I].Kind=ekProc) Then Begin
     Inc(Bad);TLAdd(Mdl^.El[I].Num+' : '+T5('num@ero en double',
       'duplicate number','doppelte Nummer','n@vmero duplicado',
       'numero duplicato'));
    End;
  End;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used Then Begin
   If (FindEl(Mdl^.Fl[I].A)=0) Or (FindEl(Mdl^.Fl[I].B)=0) Then Begin
    Inc(Bad);TLAdd(Mdl^.Fl[I].Num+' : '+T5('flux avec extr@emit@e manquante',
      'flow with missing end','Fluss mit fehlendem Ende',
      'flujo con extremo faltante','flusso con estremit@r mancante'));
   End Else If Mdl^.Fl[I].Name='' Then Begin
    Inc(Bad);TLAdd(Mdl^.Fl[I].Num+' : '+T5('flux sans nom','flow without name',
      'Fluss ohne Namen','flujo sin nombre','flusso senza nome'));
   End;
  End;
 TLAdd('');
 If Bad=0 Then TLAdd(T5('Aucun probl@gme d@etect@e.','No problem found.',
   'Keine Probleme gefunden.','No se encontraron problemas.',
   'Nessun problema rilevato.'))
 Else TLAdd(IntStr(Bad)+' '+T5('probl@gme(s) d@etect@e(s).','problem(s) found.',
   'Problem(e) gefunden.','problema(s) encontrado(s).',
   'problema/i rilevato/i.'));
 ShowText(T5('V@erifier l''int@egrit@e','Verify Integrity',
   'Integrit@1t pr@3fen','Verificar integridad','Verifica integrit@r'));
End;

Procedure CmdCleanup;
Var I,N,NI,NO: Integer;
Begin
 If MsgBox(T5('Supprimer les flux orphelins et les objets inutiles ?',
   'Remove orphan flows and unused objects?',
   'Verwaiste Fl@3sse und unn@2tige Objekte entfernen?',
   '@?Eliminar flujos hu@erfanos y objetos innecesarios?',
   'Rimuovere flussi orfani e oggetti inutili?'),4)<>1 Then Exit;
 PushUndo;N:=0;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And ((FindEl(Mdl^.Fl[I].A)=0) Or (FindEl(Mdl^.Fl[I].B)=0))
    Then Begin
   Mdl^.Fl[I].Used:=False;Inc(N);
  End;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Kind In [ekStore,ekEnt]) Then Begin
   FlowCount(Mdl^.El[I].Id,NI,NO);
   If (NI+NO=0) And (Mdl^.El[I].Name=Mdl^.El[I].Num) Then Begin
     Mdl^.El[I].Used:=False;Inc(N);End;
  End;
 Msg(IntStr(N)+' '+T5('objet(s) supprim@e(s).','object(s) removed.',
   'Objekt(e) entfernt.','objeto(s) eliminado(s).','oggetto/i rimosso/i.'));
End;

{ ====================================================================== }
{                  COMMANDES DE L'APPLICATION                            }
{ ====================================================================== }

{ ---- nouveau modele ---- }

Procedure InitDocContent;
Var D,E,W: Integer;
Begin
 FlushUndo;
 FillChar(Mdl^,SizeOf(TModel),0);
 Mdl^.NextId:=1;Mdl^.NextZ:=1;
 DefaultDict;
 DefaultCfg;
 D:=NewDiag(0,T5('Contexte','Context','Kontext','Contexto','Contesto'));
 E:=NewEl(ekInfo,D,360,414);
 FileN:='';Named:=False;Modified:=False;FromDFD:=False;
 TreeOpen:=False;
 WMax:=True;
 W:=OpenWin(D);
 If W>0 Then FitWin(W);
End;

Procedure TooManyDocs;
Begin
 Msg(T5('Nombre maximal de mod@gles ouverts atteint.',
  'Maximum number of open models reached.',
  'Maximale Anzahl offener Modelle erreicht.',
  'N@vmero m@rximo de modelos abiertos alcanzado.',
  'Numero massimo di modelli aperti raggiunto.'));
End;

Function NewDocument: Boolean;
Begin
 NewDocument:=False;
 If NewDocSlot=0 Then Begin
  If CurDoc>0 Then TooManyDocs;
  Exit;
 End;
 InitDocContent;
 NewDocument:=True;
End;

Var ImpStats: String[120];

Function ConfirmSave: Integer;     { 1 oui, 2 non, 3 annuler }
Begin
 If Not Modified Then Begin ConfirmSave:=2;Exit;End;
 ConfirmSave:=MsgBox(T5('Enregistrer les modifications ?','Save changes?',
   '@4nderungen speichern?','@?Guardar los cambios?','Salvare le modifiche?'),
   3);
End;

Function DoSaveAs: Boolean;
Var S: String;
Begin
 DoSaveAs:=False;
 If FileN<>'' Then S:=ChangeExt(FileN,'SRD') Else S:=FileTitle+'.SRD';
 If Not InputBox(T5('Enregistrer sous','Save As','Speichern unter',
   'Guardar como','Salva con nome'),
    T5('Fichier :','File:','Datei:','Archivo:','File:'),S,60) Then Exit;
 S:=AddExt(TrimStr(S),'SRD');
 If FileExists(S) And (S<>FileN) Then
  If MsgBox(T5('Le fichier existe d@ej@a. Le remplacer ?',
    'The file already exists. Replace it?',
    'Die Datei existiert bereits. Ersetzen?',
    'El archivo ya existe. @?Reemplazarlo?',
    'Il file esiste gi@a. Sostituirlo?'),4)<>1 Then Exit;
 If WriteSRD(S,Mdl) Then Begin
  FileN:=S;Named:=True;Modified:=False;FromDFD:=False;DoSaveAs:=True;
 End Else Msg(T5('Erreur d''@ecriture du fichier.','File write error.',
   'Fehler beim Schreiben der Datei.','Error al escribir el archivo.',
   'Errore di scrittura del file.'));
End;

Function DoSave: Boolean;
Begin
 If (FileN='') Or FromDFD Then Begin DoSave:=DoSaveAs;Exit;End;
 If WriteSRD(FileN,Mdl) Then Begin Modified:=False;DoSave:=True;End
 Else Begin
  Msg(T5('Erreur d''@ecriture du fichier.','File write error.',
    'Fehler beim Schreiben der Datei.','Error al escribir el archivo.',
    'Errore di scrittura del file.'));
  DoSave:=False;
 End;
End;

Procedure CloseDocWindows(N: Integer);
Var I: Integer;
Begin
 For I:=1 To MAXWIN Do
  If Wn[I].Used And (Wn[I].Doc=N) Then CloseWin(I);
End;

Procedure ResetWindows;
Var W,R: Integer;
Begin
 CloseDocWindows(CurDoc);
 WMax:=True;
 R:=RootDiag;
 If R>0 Then Begin
  W:=OpenFit(R);
  If W>0 Then FitWin(W);
  If (W>0) And (Wn[W].Zoom>100) Then Begin
   Wn[W].Zoom:=100;ClampScroll(W);
  End;
  If (W>0) And (Wn[W].Zoom<50) Then SetZoom(W,50);
 End;
End;

Function PickFile(Var FN: String): Boolean;
Var SR: SearchRec; Sel,R,I,J: Integer; Names: Array[1..60] Of String[40]; N:
  Integer; Pat: Integer; S: String;
    Dup: Boolean;
Begin
 PickFile:=False;N:=0;
 For Pat:=1 To 4 Do Begin
  Case Pat Of
   1: S:='*.SRD'; 2: S:='*.DFD'; 3: S:='*.srd'; Else S:='*.dfd';
  End;
  FindFirst(S,AnyFile,SR);
  While (DosError=0) And (N<60) Do Begin
   Dup:=False;
   For I:=1 To N Do If Upper(Names[I])=Upper(SR.Name) Then Dup:=True;
   If Not Dup Then Begin Inc(N);Names[N]:=SR.Name;End;
   FindNext(SR);
  End;
 End;
 For I:=1 To N-1 Do For J:=I+1 To N Do
  If Upper(Names[J])<Upper(Names[I]) Then Begin S:=Names[I];Names[I]:=Names[J];
    Names[J]:=S;End;
 TLClear;
 For I:=1 To N Do TLAdd(Names[I]);
 If TLN=0 Then TLAdd(T5('(aucun fichier .SRD / .DFD)','(no .SRD / .DFD file)',
   '(keine .SRD / .DFD Datei)','(ning@vn archivo .SRD / .DFD)',
   '(nessun file .SRD / .DFD)'));
 Sel:=1;
 R:=ListBox(T5('Ouvrir','Open','@5ffnen','Abrir','Apri'),
   T5('Ouvrir|Autre...|Annuler','Open|Other...|Cancel',
   '@5ffnen|Andere...|Abbrechen','Abrir|Otro...|Cancelar',
   'Apri|Altro...|Annulla'),Sel);
 If (R=1) And (N>0) Then Begin FN:=Names[Sel];PickFile:=True;End
 Else If R=2 Then Begin
  FN:='';
  If InputBox(T5('Ouvrir','Open','@5ffnen','Abrir','Apri'),T5('Fichier :',
    'File:','Datei:','Archivo:','File:'),FN,60) Then
   If TrimStr(FN)<>'' Then PickFile:=True;
 End;
End;

Procedure LoadFile(FN: String);
Var T: PModel; TD: PDict; TC: TCfg; Res: Integer; PW: String;
Begin
 If Not FileExists(FN) Then Begin
  If FileExists(FN+'.SRD') Then FN:=FN+'.SRD'
  Else If FileExists(FN+'.DFD') Then FN:=FN+'.DFD'
  Else Begin Msg(T5('Fichier introuvable.','File not found.',
    'Datei nicht gefunden.','Archivo no encontrado.','File non trovato.'));Exit;
    End;
 End;
 New(T);New(TD);
 Res:=ReadAnyFile(FN,T,TD,TC);
 If Res=0 Then Begin
  If TC.Pass<>'' Then Begin
   PW:='';
   FormBegin(T5('Mot de passe','Password','Passwort','Contrase@na','Password'));
   FormAdd(0,T5('Mot de passe','Password','Passwort','Contrase@na','Password'),
     '',12,'');
   If Not RunForm Then Res:=3
   Else If Frm.Val[1]<>TC.Pass Then Begin
    Msg(T5('Mot de passe incorrect.','Wrong password.','Falsches Passwort.',
      'Contrase@na incorrecta.','Password errata.'));Res:=3;
   End;
  End;
 End;
 If Res=0 Then Begin
  If (CurDoc>0) And (FileN='') And Not Modified Then Begin
   CloseDocWindows(CurDoc);
   FlushUndo;
  End Else If NewDocSlot=0 Then Begin
   TooManyDocs;Res:=3;
  End;
 End;
 If Res=0 Then Begin
  Mdl^:=T^;Dict^:=TD^;Cfg:=TC;
  FileN:=FN;Named:=True;Modified:=False;FromDFD:=IsDFDFile(FN);
  TreeOpen:=False;
  ResetWindows;
  If FromDFD Then Msg(T5('Fichier SolderRun (.DFD) import@e : ',
    'SolderRun (.DFD) file imported: ','SolderRun-Datei (.DFD) importiert: ',
    'Archivo SolderRun (.DFD) importado: ',
    'File SolderRun (.DFD) importato: ')+ImpStats+'~'+T5('Positions des '+
    'processus lues ; autres objets plac@es automatiquement. Utilisez '+
    'Enregistrer sous (.SRD).',
    'Process positions read; other objects placed automatically. Use Save As '+
    '(.SRD).','Prozesspositionen gelesen; andere Objekte automatisch '+
    'platziert. Zum Speichern Speichern unter (.SRD) verwenden.',
    'Posiciones de procesos le@jdas; otros objetos colocados '+
    'autom@rticamente. Use Guardar como (.SRD).',
    'Posizioni dei processi lette; altri oggetti posizionati automaticamente.'+
    ' Usare Salva con nome (.SRD).'));
 End Else If Res=1 Then
  Msg(T5('Erreur de lecture du fichier.','File read error.',
    'Fehler beim Lesen der Datei.','Error al leer el archivo.',
    'Errore di lettura del file.'))
 Else If Res=2 Then
  Msg(T5('Format de fichier invalide.','Invalid file format.',
    'Ung@3ltiges Dateiformat.','Formato de archivo no v@rlido.',
    'Formato di file non valido.'))
 Else If Res=4 Then
  Msg(T5('Fichier .DFD reconnu, mais aucun diagramme exploitable n''a @et@e '+
    'trouv@e.','DFD file recognised, but no usable diagram was found.',
    'DFD-Datei erkannt, aber kein verwendbares Diagramm gefunden.',
    'Archivo DFD reconocido, pero no se encontr@p ning@vn diagrama utilizable.',
    'File DFD riconosciuto, ma nessun diagramma utilizzabile trovato.'))
 Else If Res=5 Then
  Msg(T5('Fichier .DFD trop volumineux pour cette version (maximum 64 Ko).',
    'DFD file too large for this version (64 KB maximum).',
    'DFD-Datei zu gro@7 f@3r diese Version (maximal 64 KB).',
    'Archivo DFD demasiado grande para esta versi@pn (m@rximo 64 KB).',
    'File DFD troppo grande per questa versione (massimo 64 KB).'));
 Dispose(TD);Dispose(T);
 DrawAll;
End;

Procedure CmdNew;
Begin
 If NewDocument Then DrawAll;
End;

Procedure CmdOpen;
Var FN: String;
Begin
 If PickFile(FN) Then LoadFile(FN);
 DrawAll;
End;

{ ferme le modele N (demande l'enregistrement) ; False si annule }
Function CloseDoc(N: Integer): Boolean;
Var I,Top: Integer; R: Integer;
Begin
 CloseDoc:=False;
 Top:=0;
 For I:=1 To WCnt Do If Wn[WZo[I]].Doc=N Then Top:=WZo[I];
 If Top>0 Then WinToFront(Top) Else SelectDoc(N);
 R:=ConfirmSave;
 If R=1 Then Begin If Not DoSave Then Exit;End
 Else If R=3 Then Exit;
 CloseDocWindows(N);
 FreeCurDoc;
 If WCnt>0 Then WinToFront(WZo[WCnt])
 Else If Not NewDocument Then Begin End;
 CloseDoc:=True;
End;

Procedure CmdQuit;
Var I: Integer; Ok: Boolean;
Begin
 Ok:=True;
 For I:=1 To MAXDOC Do
  If Ok And Docs[I].Used Then Ok:=CloseDoc(I);
 If Ok Then Quit:=True Else DrawAll;
End;

Function DocWinCount(N: Integer): Integer;
Var I,K: Integer;
Begin
 K:=0;
 For I:=1 To MAXWIN Do If Wn[I].Used And (Wn[I].Doc=N) Then Inc(K);
 DocWinCount:=K;
End;

Procedure CmdCloseWin;
Var W: Integer;
Begin
 W:=ActiveWin;
 If W=0 Then Exit;
 If DocWinCount(Wn[W].Doc)>1 Then Begin
  CloseWin(W);
  If WCnt>0 Then WinToFront(WZo[WCnt]);
 End Else Begin
  If Not CloseDoc(Wn[W].Doc) Then Exit;
 End;
 DrawAll;
End;

Procedure CmdCloseAll;
Var I: Integer; Ok: Boolean;
Begin
 Ok:=True;
 For I:=1 To MAXDOC Do
  If Ok And Docs[I].Used Then Ok:=CloseDoc(I);
 DrawAll;
End;

{ ---- edition ---- }

Procedure DelSel;
Var I,D: Integer;
Begin
 D:=CurDiag;
 If (D=0) Or (SelCount(D)=0) Then Exit;
 PushUndo;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And Mdl^.Fl[I].Sel And (Mdl^.Fl[I].Diag=D) Then
    Mdl^.Fl[I].Used:=False;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then DelEl(I);
 FixWindows;
End;

Procedure SelectByName;
Var S: String; D,I,N: Integer;
Begin
 D:=CurDiag;If D=0 Then Exit;
 S:='';
 If Not InputBox(T5('S@electionner','Select','Ausw@1hlen','Seleccionar',
   'Seleziona'),
    T5('Nom contenant :','Name containing:','Name enth@1lt:',
      'Nombre que contiene:','Nome contenente:'),S,30) Then Exit;
 S:=Upper(TrimStr(S));
 ClearSel;N:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And Not Mdl^.El[I].Hid And (Pos(S,
    Upper(Mdl^.El[I].Name))>0) Then Begin
   Mdl^.El[I].Sel:=True;Inc(N);
  End;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) And Not Mdl^.Fl[I].Hid And (Pos(S,
    Upper(Mdl^.Fl[I].Name))>0) Then Begin
   Mdl^.Fl[I].Sel:=True;Inc(N);
  End;
 StatMsg:=IntStr(N)+' '+T5('objet(s) s@electionn@e(s)','object(s) selected',
   'Objekt(e) ausgew@1hlt','objeto(s) seleccionado(s)',
   'oggetto/i selezionato/i');
End;

Procedure GotoPage;
Var I,K,N: Integer;
Begin
 FormBegin(T5('Aller @a la page','Go to Page','Gehe zu Seite','Ir a p@rgina',
   'Vai a pagina'));
 FormAdd(1,T5('Page (1-','Page (1-','Seite (1-','P@rgina (1-',
   'Pagina (1-')+IntStr(DiagCount)+')','1',4,'');
 If Not RunForm Then Exit;
 N:=ValInt(Frm.Val[1],1);K:=0;
 For I:=1 To MAXDG Do
  If Mdl^.Dg[I].Used Then Begin
   Inc(K);
   If K=N Then Begin OpenFit(I);Exit;End;
  End;
End;

Procedure AlignSel(Cm: Integer);
Var D,I,N: Integer; MinX,MaxR,MinY,MaxB: LongInt;
Begin
 D:=CurDiag;
 If SelElCount(D)<2 Then Exit;
 PushUndo;
 MinX:=32000;MaxR:=-32000;MinY:=32000;MaxB:=-32000;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then Begin
   If Mdl^.El[I].X<MinX Then MinX:=Mdl^.El[I].X;
   If Mdl^.El[I].X+Mdl^.El[I].W>MaxR Then MaxR:=Mdl^.El[I].X+Mdl^.El[I].W;
   If Mdl^.El[I].Y<MinY Then MinY:=Mdl^.El[I].Y;
   If Mdl^.El[I].Y+Mdl^.El[I].H>MaxB Then MaxB:=Mdl^.El[I].Y+Mdl^.El[I].H;
  End;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then
   Case Cm Of
    cmAlL: Mdl^.El[I].X:=MinX;
    cmAlR: Mdl^.El[I].X:=MaxR-Mdl^.El[I].W;
    cmAlT: Mdl^.El[I].Y:=MinY;
    cmAlB: Mdl^.El[I].Y:=MaxB-Mdl^.El[I].H;
    cmAlH: Mdl^.El[I].X:=(MinX+MaxR) Div 2-Mdl^.El[I].W Div 2;
    cmAlV: Mdl^.El[I].Y:=(MinY+MaxB) Div 2-Mdl^.El[I].H Div 2;
   End;
 N:=0;
End;

Procedure ResizeSel;
Var D,I,F: Integer;
Begin
 D:=CurDiag;
 F:=0;
 For I:=1 To MAXEL Do If (F=0) And Mdl^.El[I].Used And Mdl^.El[I].Sel And
   (Mdl^.El[I].Diag=D) Then F:=I;
 If F=0 Then Exit;
 FormBegin(T5('Redimensionner','Resize','Gr@2@7e @1ndern','Cambiar tama@no',
   'Ridimensiona'));
 FormAdd(1,T5('Largeur','Width','Breite','Ancho','Larghezza'),
   IntStr(Mdl^.El[F].W),4,'');
 FormAdd(1,T5('Hauteur','Height','H@2he','Alto','Altezza'),IntStr(Mdl^.El[F].H),
   4,'');
 If Not RunForm Then Exit;
 PushUndo;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then Begin
   Mdl^.El[I].W:=Integer(Max2(20,Min2(600,ValInt(Frm.Val[1],Mdl^.El[I].W))));
   Mdl^.El[I].H:=Integer(Max2(12,Min2(400,ValInt(Frm.Val[2],Mdl^.El[I].H))));
  End;
End;

Procedure RestoreSize;
Var D,I: Integer;
Begin
 D:=CurDiag;PushUndo;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then
   Case Mdl^.El[I].Kind Of
    ekProc: Begin Mdl^.El[I].W:=Cfg.PW;Mdl^.El[I].H:=Cfg.PH;End;
    ekStore: Begin Mdl^.El[I].W:=150;Mdl^.El[I].H:=34;End;
    ekEnt: Begin Mdl^.El[I].W:=100;Mdl^.El[I].H:=44;End;
    ekInfo: Begin Mdl^.El[I].W:=260;Mdl^.El[I].H:=112;End;
    Else Begin Mdl^.El[I].W:=90;Mdl^.El[I].H:=18;End;
   End;
End;

Procedure ChangeFont;
Var D,I: Integer;
Begin
 D:=CurDiag;
 FormBegin(T5('Police du texte libre','Free Text Font',
   'Schrift f@3r freien Text','Fuente del texto libre',
   'Carattere del testo libero'));
 FormAdd(4,T5('Style','Style','Stil','Estilo','Stile'),'1',0,T5('Normal|Gras',
   'Normal|Bold','Normal|Fett','Normal|Negrita','Normale|Grassetto'));
 If Not RunForm Then Exit;
 PushUndo;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) And
    (Mdl^.El[I].Kind=ekText) Then
   Mdl^.El[I].FS:=ValInt(Frm.Val[1],1);
End;

Procedure DrawSize;
Var D: Integer;
Begin
 D:=CurDiag;If D=0 Then Exit;
 FormBegin(T5('Taille du dessin','Drawing Size','Zeichnungsgr@2@7e',
   'Tama@no del dibujo','Dimensione disegno'));
 FormAdd(1,T5('Largeur','Width','Breite','Ancho','Larghezza'),
   IntStr(Mdl^.Dg[D].W),4,'');
 FormAdd(1,T5('Hauteur','Height','H@2he','Alto','Altezza'),IntStr(Mdl^.Dg[D].H),
   4,'');
 If Not RunForm Then Exit;
 PushUndo;
 Mdl^.Dg[D].W:=Integer(Max2(300,Min2(3000,ValInt(Frm.Val[1],720))));
 Mdl^.Dg[D].H:=Integer(Max2(200,Min2(3000,ValInt(Frm.Val[2],480))));
 ClampScroll(ActiveWin);
End;

Procedure CmdToolbars;
Begin
 FormBegin(T5('Barres d''outils','Toolbars','Symbolleisten',
   'Barras de herramientas','Barre degli strumenti'));
 FormAdd(2,T5('Barre d''outils','Toolbar','Symbolleiste',
   'Barra de herramientas','Barra degli strumenti'),Chr(48+Ord(ToolBarOn)),0,
   '');
 FormAdd(2,T5('Palette d''outils','Tool box','Werkzeugpalette',
   'Paleta de herramientas','Tavolozza strumenti'),Chr(48+Ord(ToolBoxOn)),0,'');
 FormAdd(2,T5('Barre d''@etat','Status bar','Statusleiste','Barra de estado',
   'Barra di stato'),Chr(48+Ord(StatusOn)),0,'');
 If RunForm Then Begin
  ToolBarOn:=Frm.Val[1]='1';ToolBoxOn:=Frm.Val[2]='1';StatusOn:=Frm.Val[3]='1';
  FixWindows;
 End;
End;

Procedure ProcPrefs;
Var Dd,Jj,I: Integer; Opt1,Opt2: String;
Begin
 Opt1:=T5('(aucun)|ID num@erique|Nom|Description|Ressources|Diagramme enfant',
   '(none)|Numerical ID|Name|Description|Resources|Child diagram',
   '(keine)|Numerische ID|Name|Beschreibung|Ressourcen|Unterdiagramm',
   '(ninguno)|ID num@erico|Nombre|Descripci@pn|Recursos|Diagrama hijo',
   '(nessuno)|ID numerico|Nome|Descrizione|Risorse|Diagramma figlio');
 Opt2:=T5('Gauche|Centr@e|Droite','Left|Center|Right','Links|Zentriert|Rechts',
   'Izquierda|Centrado|Derecha','Sinistra|Centrato|Destra');
 FormBegin(T5('Pr@ef@erences des processus','Process Preferences',
   'Prozessvorgaben','Preferencias de procesos','Preferenze dei processi'));
 FormAdd(4,T5('Notation','Notation','Notation','Notaci@pn','Notazione'),
   IntStr(Cfg.Notation),0,'Gane-Sarson|Yourdon');
 For I:=1 To 3 Do Begin
  FormAdd(4,T5('Zone ','Zone ','Zone ','Zona ','Zona ')+IntStr(I),
    IntStr(Cfg.ZDesc[I]),0,Opt1);
  FormAdd(4,T5('  Justification','  Justification','  Ausrichtung',
    '  Justificaci@pn','  Giustificazione'),IntStr(Cfg.ZJus[I]),0,Opt2);
 End;
 FormAdd(1,T5('Largeur par d@efaut (mm)','Default width (mm)',
   'Standardbreite (mm)','Ancho predeterminado (mm)',
   'Larghezza predefinita (mm)'),IntStr(Cfg.PW Div 4),3,'');
 FormAdd(1,T5('Hauteur par d@efaut (mm)','Default height (mm)',
   'Standardh@2he (mm)','Alto predeterminado (mm)','Altezza predefinita (mm)'),
   IntStr(Cfg.PH Div 4),3,'');
 If Not RunForm Then Exit;
 Cfg.Notation:=ValInt(Frm.Val[1],1);
 For I:=1 To 3 Do Begin
  Dd:=ValInt(Frm.Val[2*I],1);Jj:=ValInt(Frm.Val[2*I+1],2);
  Cfg.ZDesc[I]:=Dd;Cfg.ZJus[I]:=Jj;
 End;
 Cfg.PW:=Integer(Max2(60,Min2(600,ValInt(Frm.Val[8],30)*4)));
 Cfg.PH:=Integer(Max2(40,Min2(400,ValInt(Frm.Val[9],22)*4)));
 Modified:=True;
End;

Procedure CmdOptions;

Begin
 FormBegin(T5('Options','Options','Optionen','Opciones','Opzioni'));
 FormAdd(2,T5('Aimanter @a la grille','Snap to grid','Am Raster ausrichten',
   'Ajustar a la cuadr@jcula','Allinea alla griglia'),Chr(48+Ord(Cfg.Snap)),0,
   '');
 FormAdd(1,T5('Pas de la grille','Grid size','Rastergr@2@7e',
   'Tama@no de cuadr@jcula','Passo della griglia'),IntStr(Cfg.Grid),3,'');
 FormAdd(2,T5('Afficher la grille','Show grid','Raster anzeigen',
   'Mostrar cuadr@jcula','Mostra griglia'),Chr(48+Ord(Cfg.ShowGrid)),0,'');
 FormAdd(2,T5('Pr@ef@erences des processus...','Process preferences...',
   'Prozessvorgaben...','Preferencias de procesos...',
   'Preferenze dei processi...'),'0',0,'');
 FormAdd(2,T5('Double-clic ouvre l''enfant','Double-click opens child',
   'Doppelklick @2ffnet Unterdiagramm','Doble clic abre el hijo',
   'Doppio clic apre il figlio'),Chr(48+Ord(Cfg.AutoOpen)),0,'');
 If RunForm Then Begin
  Cfg.Snap:=Frm.Val[1]='1';
  Cfg.Grid:=Integer(Max2(2,Min2(100,ValInt(Frm.Val[2],10))));
  Cfg.ShowGrid:=Frm.Val[3]='1';Cfg.AutoOpen:=Frm.Val[5]='1';
  If Frm.Val[4]='1' Then ProcPrefs;
 End;
End;

Procedure CmdPass;
Begin
 FormBegin(T5('Mots de passe','Passwords','Passw@2rter','Contrase@nas',
   'Password'));
 FormAdd(0,T5('Nouveau mot de passe','New password','Neues Passwort',
   'Nueva contrase@na','Nuova password'),Cfg.Pass,12,'');
 FormAdd(0,T5('Confirmation','Confirm','Best@1tigen','Confirmar','Conferma'),
   Cfg.Pass,12,'');
 If RunForm Then Begin
  If Frm.Val[1]=Frm.Val[2] Then Begin Cfg.Pass:=Frm.Val[1];Modified:=True;End
  Else Msg(T5('Les mots de passe ne correspondent pas.',
    'Passwords do not match.','Passw@2rter stimmen nicht @3berein.',
    'Las contrase@nas no coinciden.','Le password non corrispondono.'));
 End;
End;

Procedure CmdPageSetup;
Begin
 FormBegin(T5('Mise en page','Page Setup','Seite einrichten',
   'Configurar p@rgina','Imposta pagina'));
 FormAdd(4,T5('Orientation','Orientation','Ausrichtung','Orientaci@pn',
   'Orientamento'),Chr(49+Ord(Cfg.Landscape)),0,T5('Portrait|Paysage',
   'Portrait|Landscape','Hochformat|Querformat','Vertical|Horizontal',
   'Verticale|Orizzontale'));
 FormAdd(1,T5('Marge (mm)','Margin (mm)','Rand (mm)','Margen (mm)',
   'Margine (mm)'),IntStr(Cfg.Margin),3,'');
 If RunForm Then Begin
  Cfg.Landscape:=Frm.Val[1]='2';
  Cfg.Margin:=Integer(Max2(0,Min2(50,ValInt(Frm.Val[2],10))));
 End;
End;

Procedure CmdPrint;
Var FN: String; K: Integer; F: Text; I: Integer;
Begin
 {$IFDEF FPC}
 FN:='SRPRINT.TXT';
 {$ELSE}
 FN:='PRN';
 {$ENDIF}
 If Not InputBox(T5('Imprimer','Print','Drucken','Imprimir','Stampa'),
   T5('Destination :','Destination:','Ziel:','Destino:','Destinazione:'),FN,40)
   Then Exit;
 {$I-}
 Assign(F,FN);Rewrite(F);
 {$I+}
 If IOResult<>0 Then Begin Msg(T5('Impression impossible.','Cannot print.',
   'Drucken nicht m@2glich.','No se puede imprimir.','Impossibile stampare.'));
   Exit;End;
 WriteLn(F,'SOLDERRUN-BPM - ',FileTitle);
 WriteLn(F);
 For K:=1 To 5 Do Begin
  GenReport(K);
  For I:=1 To TLN Do WriteLn(F,TL^[I]);
  WriteLn(F);
 End;
 Close(F);
 Msg(T5('Rapport envoy@e vers ','Report sent to ','Bericht gesendet an ',
   'Informe enviado a ','Rapporto inviato a ')+FN);
End;

{ ---- import / export ---- }

Function Esc(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:='';
 For I:=1 To Length(S) Do
  Case S[I] Of
   '&': R:=R+'&amp;';
   '<': R:=R+'&lt;';
   '>': R:=R+'&gt;';
   '"': R:=R+'&quot;';
   Else R:=R+S[I];
  End;
 Esc:=R;
End;

Procedure ExportSVG(Const FN: String);
Var F: Text; D,I: Integer; X1,Y1,X2,Y2: LongInt; A,B: Integer;
Begin
 D:=CurDiag;If D=0 Then Exit;
 {$I-}
 Assign(F,FN);Rewrite(F);
 {$I+}
 If IOResult<>0 Then Begin Msg(T5('Erreur d''@ecriture du fichier.',
   'File write error.','Fehler beim Schreiben der Datei.',
   'Error al escribir el archivo.','Errore di scrittura del file.'));Exit;End;
 WriteLn(F,'<?xml version="1.0" encoding="ISO-8859-1"?>');
 WriteLn(F,'<svg xmlns="http://www.w3.org/2000/svg" width="',Mdl^.Dg[D].W,
   '" height="',Mdl^.Dg[D].H,'" font-family="Arial" font-size="12">');
 WriteLn(F,'<defs><marker id="a" markerWidth="10" markerHeight="8" refX="9" '+
   'refY="4" orient="auto"><path d="M0,0 L10,4 L0,8 z"/></marker></defs>');
 WriteLn(F,'<rect x="1" y="1" width="',Mdl^.Dg[D].W-2,'" height="',
   Mdl^.Dg[D].H-2,'" rx="10" fill="white" stroke="black" stroke-width="3"/>');
 WriteLn(F,'<line x1="1" y1="18" x2="',Mdl^.Dg[D].W-1,
   '" y2="18" stroke="black" stroke-width="3"/>');
 WriteLn(F,'<text x="',Mdl^.Dg[D].W Div 2,'" y="14" text-anchor="middle">',
   Esc(Mdl^.Dg[D].Title),'</text>');
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) And FlowGeom(I,X1,Y1,X2,Y2) Then
    Begin
   If Mdl^.Fl[I].Bend Then
    WriteLn(F,'<polyline points="',X1,',',Y1,' ',Mdl^.Fl[I].BX,',',
      Mdl^.Fl[I].BY,' ',X2,',',Y2,
      '" fill="none" stroke="black" marker-end="url(#a)"/>')
   Else WriteLn(F,'<line x1="',X1,'" y1="',Y1,'" x2="',X2,'" y2="',Y2,
     '" stroke="black" marker-end="url(#a)"/>');
   WriteLn(F,'<text x="',(X1+X2) Div 2,'" y="',(Y1+Y2) Div 2-4,
     '" text-anchor="middle">',Esc(Mdl^.Fl[I].Name),'</text>');
  End;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) Then Begin
   X1:=Mdl^.El[I].X;Y1:=Mdl^.El[I].Y;X2:=Mdl^.El[I].W;Y2:=Mdl^.El[I].H;
   Case Mdl^.El[I].Kind Of
    ekProc: Begin
      WriteLn(F,'<rect x="',X1,'" y="',Y1,'" width="',X2,'" height="',Y2,
        '" rx="8" fill="white" stroke="black"/>');
      WriteLn(F,'<line x1="',X1,'" y1="',Y1+16,'" x2="',X1+X2,'" y2="',Y1+16,
        '" stroke="black"/>');
      WriteLn(F,'<line x1="',X1,'" y1="',Y1+Y2-16,'" x2="',X1+X2,'" y2="',
        Y1+Y2-16,'" stroke="black"/>');
      WriteLn(F,'<text x="',X1+X2 Div 2,'" y="',Y1+12,
        '" text-anchor="middle" fill="purple">',Esc(Mdl^.El[I].Num),'</text>');
      WriteLn(F,'<text x="',X1+X2 Div 2,'" y="',Y1+Y2 Div 2+4,
        '" text-anchor="middle">',Esc(Mdl^.El[I].Name),'</text>');
      WriteLn(F,'<text x="',X1+X2 Div 2,'" y="',Y1+Y2-4,
        '" text-anchor="middle">',Esc(DictLabel(dcRes,Mdl^.El[I].Res)),
        '</text>');
     End;
    ekStore: Begin
      WriteLn(F,'<rect x="',X1,'" y="',Y1,'" width="',X2,'" height="',Y2,
        '" fill="white" stroke="black"/>');
      WriteLn(F,'<line x1="',X1+X2*3 Div 10,'" y1="',Y1,'" x2="',X1+X2*3 Div 10,
        '" y2="',Y1+Y2,'" stroke="black"/>');
      WriteLn(F,'<text x="',X1+4,'" y="',Y1+Y2 Div 2+4,'">',Esc(Mdl^.El[I].Num),
        '</text>');
      WriteLn(F,'<text x="',X1+X2*3 Div 10+4,'" y="',Y1+Y2 Div 2+4,'">',
        Esc(Mdl^.El[I].Name),'</text>');
     End;
    ekEnt: Begin
      WriteLn(F,'<rect x="',X1,'" y="',Y1,'" width="',X2,'" height="',Y2,
        '" fill="white" stroke="black"/>');
      WriteLn(F,'<text x="',X1+X2 Div 2,'" y="',Y1+Y2 Div 2+4,
        '" text-anchor="middle">',Esc(ElName(I)),'</text>');
     End;
    Else WriteLn(F,'<text x="',X1,'" y="',Y1+12,'">',Esc(Mdl^.El[I].Name),
      '</text>');
   End;
  End;
 A:=0;B:=0;
 WriteLn(F,'</svg>');
 Close(F);
End;

Procedure ExportCSV(Const FN: String);
Var F: Text; I: Integer;
Begin
 {$I-}
 Assign(F,FN);Rewrite(F);
 {$I+}
 If IOResult<>0 Then Begin Msg(T5('Erreur d''@ecriture du fichier.',
   'File write error.','Fehler beim Schreiben der Datei.',
   'Error al escribir el archivo.','Errore di scrittura del file.'));Exit;End;
 WriteLn(F,'Type;Num;Name;Diagram;Description;Resource');
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used Then
   WriteLn(F,Mdl^.El[I].Kind,';',Mdl^.El[I].Num,';',Mdl^.El[I].Name,';',
     DiagTitle(Mdl^.El[I].Diag),';',Mdl^.El[I].Desc,';',DictLabel(dcRes,
     Mdl^.El[I].Res));
 WriteLn(F,'Flow;Num;Name;From;To;Qualifier');
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And (FindEl(Mdl^.Fl[I].A)>0) And (FindEl(Mdl^.Fl[I].B)>0)
    Then
   WriteLn(F,'F;',Mdl^.Fl[I].Num,';',Mdl^.Fl[I].Name,';',
     ElName(FindEl(Mdl^.Fl[I].A)),';',ElName(FindEl(Mdl^.Fl[I].B)),';',
     DictName(dcQual,Mdl^.Fl[I].Qual));
 Close(F);
End;

Procedure ImportNames(Const FN: String);
Var F: Text; S: String; D,E,N: Integer;
Begin
 D:=CurDiag;If D=0 Then Exit;
 {$I-}
 Assign(F,FN);Reset(F);
 {$I+}
 If IOResult<>0 Then Begin Msg(T5('Fichier introuvable.','File not found.',
   'Datei nicht gefunden.','Archivo no encontrado.','File non trovato.'));Exit;
   End;
 PushUndo;N:=0;
 While Not Eof(F) Do Begin
  ReadLn(F,S);S:=TrimStr(S);
  If S<>'' Then Begin
   E:=NewEl(ekProc,D,90+(N Mod 5)*130,70+(N Div 5)*105);
   If E>0 Then Begin Mdl^.El[E].Name:=Copy(S,1,40);Inc(N);End;
  End;
 End;
 Close(F);
 Msg(IntStr(N)+' '+T5('processus import@es.','processes imported.',
   'Prozesse importiert.','procesos importados.','processi importati.'));
End;

Procedure CmdImpExp;
Var FN: String; K: Integer;
Begin
 FormBegin(T5('Importer-Exporter','Import-Export','Import-Export',
   'Importar-Exportar','Importa-Esporta'));
 FormAdd(4,T5('Op@eration','Operation','Vorgang','Operaci@pn','Operazione'),'1',
   0,
  T5('Exporter en SVG|Exporter en CSV|Importer des processus (texte)',
    'Export to SVG|Export to CSV|Import processes (text)',
    'Als SVG exportieren|Als CSV exportieren|Prozesse importieren (Text)',
    'Exportar a SVG|Exportar a CSV|Importar procesos (texto)',
    'Esporta in SVG|Esporta in CSV|Importa processi (testo)'));
 FormAdd(0,T5('Fichier','File','Datei','Archivo','File'),ChangeExt(FileTitle,
   'SVG'),60,'');
 If Not RunForm Then Exit;
 K:=ValInt(Frm.Val[1],1);FN:=TrimStr(Frm.Val[2]);
 If FN='' Then Exit;
 Case K Of
  1: ExportSVG(AddExt(FN,'SVG'));
  2: ExportCSV(AddExt(FN,'CSV'));
  3: ImportNames(FN);
 End;
End;

{ ---- fusion / scission ---- }

Procedure CmdMerge;
Var FN: String; T: PModel; TD: PDict; TC: TCfg; Res,I,J,E,F,D: Integer;
    DMap: Array[1..MAXDG] Of Integer; NewId: Array[1..MAXEL] Of Integer; Sid,Sz,
      K: Integer;
Function MapId(Old: Integer): Integer;
Var Q: Integer;
Begin
 MapId:=0;
 For Q:=1 To MAXEL Do If T^.El[Q].Used And (T^.El[Q].Id=Old) Then
   MapId:=NewId[Q];
End;
Begin
 FN:='';
 If Not PickFile(FN) Then Exit;
 New(T);New(TD);
 Res:=ReadAnyFile(FN,T,TD,TC);
 If Res<>0 Then Begin
  Msg(T5('Impossible de lire ce fichier.','Cannot read this file.',
    'Datei kann nicht gelesen werden.','No se puede leer este archivo.',
    'Impossibile leggere questo file.'));
  Dispose(TD);Dispose(T);Exit;
 End;
 PushUndo;
 For I:=1 To MAXDG Do Begin
  DMap[I]:=0;
  If T^.Dg[I].Used Then Begin
   D:=NewDiag(0,T^.Dg[I].Title);DMap[I]:=D;
   If D>0 Then Begin Mdl^.Dg[D].W:=T^.Dg[I].W;Mdl^.Dg[D].H:=T^.Dg[I].H;
     Mdl^.Dg[D].NP:=T^.Dg[I].NP;End;
  End;
 End;
 For I:=1 To MAXEL Do Begin
  NewId[I]:=0;
  If T^.El[I].Used And (DMap[T^.El[I].Diag]>0) Then Begin
   E:=NewEl(T^.El[I].Kind,DMap[T^.El[I].Diag],0,0);
   If E>0 Then Begin
    Sid:=Mdl^.El[E].Id;Sz:=Mdl^.El[E].Z;
    Mdl^.El[E]:=T^.El[I];
    Mdl^.El[E].Id:=Sid;Mdl^.El[E].Z:=Sz;Mdl^.El[E].Diag:=DMap[T^.El[I].Diag];
    Mdl^.El[E].Sel:=False;Mdl^.El[E].Res:=0;
    If T^.El[I].Child>0 Then Mdl^.El[E].Child:=DMap[T^.El[I].Child] Else
      Mdl^.El[E].Child:=0;
    NewId[I]:=Sid;
   End;
  End;
 End;
 For I:=1 To MAXDG Do
  If T^.Dg[I].Used And (DMap[I]>0) And (T^.Dg[I].Parent>0) Then
    Mdl^.Dg[DMap[I]].Parent:=MapId(T^.Dg[I].Parent);
 For I:=1 To MAXFL Do
  If T^.Fl[I].Used And (DMap[T^.Fl[I].Diag]>0) Then Begin
   J:=MapId(T^.Fl[I].A);K:=MapId(T^.Fl[I].B);
   If (J>0) And (K>0) Then Begin
    F:=NewFl(DMap[T^.Fl[I].Diag],J,K);
    If F>0 Then Begin
     Mdl^.Fl[F].Name:=T^.Fl[I].Name;Mdl^.Fl[F].Desc:=T^.Fl[I].Desc;
     Mdl^.Fl[F].Bend:=T^.Fl[I].Bend;Mdl^.Fl[F].BX:=T^.Fl[I].BX;
       Mdl^.Fl[F].BY:=T^.Fl[I].BY;
    End;
   End;
  End;
 Dispose(TD);Dispose(T);
 Msg(T5('Fusion termin@ee : les diagrammes ont @et@e ajout@es.',
   'Merge complete: diagrams were added.',
   'Zusammenf@3hren abgeschlossen: Diagramme hinzugef@3gt.',
   'Combinaci@pn terminada: diagramas a@nadidos.',
   'Unione completata: diagrammi aggiunti.'));
End;

Function InSubtree(D,Root: Integer): Boolean;
Var C,Guard,P: Integer;
Begin
 C:=D;Guard:=0;
 While (C>0) And (Guard<MAXDG+2) Do Begin
  If C=Root Then Begin InSubtree:=True;Exit;End;
  P:=FindEl(Mdl^.Dg[C].Parent);
  If P=0 Then C:=0 Else C:=Mdl^.El[P].Diag;
  Inc(Guard);
 End;
 InSubtree:=False;
End;

Procedure CmdSplit;
Var D,I: Integer; FN: String; T: PModel; Sv: PModel;
Begin
 D:=CurDiag;If D=0 Then Exit;
 FN:=ChangeExt(FileTitle+'_'+IntStr(D),'SRD');
 If Not InputBox(T5('Scinder','Split','Aufteilen','Dividir','Dividi'),
   T5('Fichier :','File:','Datei:','Archivo:','File:'),FN,60) Then Exit;
 New(T);
 T^:=Mdl^;
 For I:=1 To MAXDG Do If T^.Dg[I].Used And Not InSubtree(I,D) Then
   T^.Dg[I].Used:=False;
 For I:=1 To MAXEL Do If T^.El[I].Used And Not T^.Dg[T^.El[I].Diag].Used Then
   T^.El[I].Used:=False;
 For I:=1 To MAXFL Do If T^.Fl[I].Used And Not T^.Dg[T^.Fl[I].Diag].Used Then
   T^.Fl[I].Used:=False;
 T^.Dg[D].Parent:=0;
 If WriteSRD(AddExt(FN,'SRD'),T) Then
  Msg(T5('Sous-mod@gle enregistr@e : ','Sub-model saved: ',
    'Teilmodell gespeichert: ','Submodelo guardado: ',
    'Sottomodello salvato: ')+AddExt(FN,'SRD'))
 Else Msg(T5('Erreur d''@ecriture du fichier.','File write error.',
   'Fehler beim Schreiben der Datei.','Error al escribir el archivo.',
   'Errore di scrittura del file.'));
 Dispose(T);
 Sv:=Nil;
End;

{ ---- hierarchie ---- }

Procedure DoDecompose;
Var D,I,C: Integer; IsF: Boolean; S: String;
Begin
 D:=CurDiag;If D=0 Then Exit;
 I:=FirstSel(D,IsF);
 If (I=0) Or IsF Or (Mdl^.El[I].Kind<>ekProc) Then Begin
  Msg(T5('S@electionnez un processus.','Select a process.',
    'Einen Prozess ausw@1hlen.','Seleccione un proceso.',
    'Selezionare un processo.'));Exit;
 End;
 C:=Mdl^.El[I].Child;
 If (C=0) Or Not Mdl^.Dg[C].Used Then Begin
  PushUndo;
  S:=Mdl^.El[I].Name;If S='' Then S:=Mdl^.El[I].Num;
  C:=NewDiag(Mdl^.El[I].Id,S);
  If C=0 Then Begin Msg(T5('Trop de diagrammes.','Too many diagrams.',
    'Zu viele Diagramme.','Demasiados diagramas.','Troppi diagrammi.'));Exit;
    End;
  Mdl^.El[I].Child:=C;
 End;
 ClearSel;
 OpenFit(C);
End;

Procedure DoParentUp;
Var D,P: Integer;
Begin
 D:=CurDiag;If D=0 Then Exit;
 P:=FindEl(Mdl^.Dg[D].Parent);
 If P=0 Then Begin Msg(T5('Ce diagramme est la racine.',
   'This diagram is the root.','Dieses Diagramm ist die Wurzel.',
   'Este diagrama es la ra@jz.','Questo diagramma @a la radice.'));Exit;End;
 GotoElem(P);
End;

Procedure CmdTree;
Var Sel,R,Ref,Rt: Integer;
Begin
 TreeOpen:=True;Sel:=1;
 Repeat
  TLClear;
  Rt:=RootDiag;
  If Rt>0 Then TreeLines(Rt,0);
  If TLN=0 Then Begin TLAdd('-');LRef[1]:=0;End;
  R:=ListBox(T5('Arbre des processus','Process Tree','Prozessbaum',
    '@rrbol de procesos','Albero dei processi'),
     T5('Aller @a|Fermer','Go to|Close','Gehe zu|Schlie@7en','Ir a|Cerrar',
       'Vai a|Chiudi'),Sel);
  Ref:=0;If (Sel>=1) And (Sel<=TLN) Then Ref:=LRef[Sel];
  If (R=1) And (Ref>0) Then Begin GotoElem(Ref);R:=2;End;
 Until R<>1;
End;

Procedure CmdParent;
Var R,ND,E: Integer;
Begin
 R:=RootDiag;If R=0 Then Exit;
 PushUndo;
 ND:=NewDiag(0,T5('Contexte','Context','Kontext','Contexto','Contesto'));
 If ND=0 Then Exit;
 E:=NewEl(ekProc,ND,360,240);
 If E=0 Then Exit;
 Mdl^.El[E].Child:=R;
 Mdl^.El[E].Name:=Cfg.ProjName;
 Mdl^.Dg[R].Parent:=Mdl^.El[E].Id;
 Mdl^.Dg[R].Title:=Cfg.ProjName;
 RenumAll;
 OpenFit(ND);
End;

Procedure CmdEnv(WithFlow: Boolean);
Var D,P,DP,I,J,O,E,K,N,Y: Integer;
Begin
 D:=CurDiag;If D=0 Then Exit;
 P:=FindEl(Mdl^.Dg[D].Parent);
 If P=0 Then Exit;
 DP:=Mdl^.El[P].Diag;
 PushUndo;N:=0;Y:=60;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=DP) And ((Mdl^.Fl[I].A=Mdl^.El[P].Id)
    Or (Mdl^.Fl[I].B=Mdl^.El[P].Id)) Then Begin
   If Mdl^.Fl[I].A=Mdl^.El[P].Id Then O:=FindEl(Mdl^.Fl[I].B) Else
     O:=FindEl(Mdl^.Fl[I].A);
   If (O>0) And (Mdl^.El[O].Kind<>ekProc) Then Begin
    E:=0;
    For J:=1 To MAXEL Do
     If Mdl^.El[J].Used And (Mdl^.El[J].Diag=D) And
       (Mdl^.El[J].Kind=Mdl^.El[O].Kind) And (Mdl^.El[J].Name=Mdl^.El[O].Name)
       Then E:=J;
    If E=0 Then Begin
     E:=NewEl(Mdl^.El[O].Kind,D,0,0);
     If E>0 Then Begin
      Mdl^.El[E].Name:=Mdl^.El[O].Name;Mdl^.El[E].Num:=Mdl^.El[O].Num;
        Mdl^.El[E].Desc:=Mdl^.El[O].Desc;
      Mdl^.El[E].X:=20;Mdl^.El[E].Y:=Y;Inc(Y,Mdl^.El[E].H+16);
      Inc(N);
     End;
    End;
   End;
  End;
 If WithFlow Then
  For I:=1 To MAXFL Do
   If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) Then
    For J:=1 To MAXFL Do
     If Mdl^.Fl[J].Used And (Mdl^.Fl[J].Diag=DP) And
       (Mdl^.Fl[J].Name=Mdl^.Fl[I].Name) And (Mdl^.Fl[I].Name<>'') Then Begin
      Mdl^.Fl[I].Qual:=Mdl^.Fl[J].Qual;Mdl^.Fl[I].Desc:=Mdl^.Fl[J].Desc;
     End;
 K:=0;
 Msg(IntStr(N)+' '+T5('objet(s) d''environnement ajout@e(s).',
   'environment object(s) added.','Umgebungsobjekt(e) hinzugef@3gt.',
   'objeto(s) de entorno a@nadido(s).','oggetto/i di ambiente aggiunto/i.'));
End;

Procedure CmdRenum;
Var D,P: Integer; Pre: String;
Begin
 FormBegin(T5('Renum@eroter','Renumber','Neu nummerieren','Renumerar',
   'Rinumera'));
 FormAdd(4,T5('Port@ee','Scope','Bereich','Alcance','Ambito'),'1',0,
   T5('Tout le mod@gle|Diagramme courant','Whole model|Current diagram',
   'Gesamtes Modell|Aktuelles Diagramm','Todo el modelo|Diagrama actual',
   'Intero modello|Diagramma corrente'));
 If Not RunForm Then Exit;
 PushUndo;
 If Frm.Val[1]='1' Then RenumAll
 Else Begin
  D:=CurDiag;If D=0 Then Exit;
  P:=FindEl(Mdl^.Dg[D].Parent);
  If P>0 Then Pre:=Mdl^.El[P].Num Else Pre:='';
  RenumDiag(D,Pre);
 End;
End;

{ ---- fenetres ---- }

Procedure ArrangeWins(Mode: Integer);
Var I,K,N,X,Y,W0,H0,W: Integer;
Begin
 N:=0;
 For I:=1 To WCnt Do If Not Wn[WZo[I]].Iconic Then Inc(N);
 If N=0 Then Exit;
 WMax:=False;
 W0:=SCR_W;H0:=WsY1-WsY0+1-22;
 K:=0;
 For I:=1 To WCnt Do Begin
  W:=WZo[I];
  If Not Wn[W].Iconic Then Begin
   Case Mode Of
    1: Begin
      Wn[W].X:=8+K*24;Wn[W].Y:=4+K*22;
      Wn[W].W:=Integer(Min2(W0-Wn[W].X-8,520));
        Wn[W].H:=Integer(Min2(H0-Wn[W].Y-4,320));
     End;
    2: Begin Wn[W].X:=0;Wn[W].W:=W0;Wn[W].H:=H0 Div N;Wn[W].Y:=K*Wn[W].H;End;
    Else Begin Wn[W].Y:=0;Wn[W].H:=H0;Wn[W].W:=W0 Div N;Wn[W].X:=K*Wn[W].W;End;
   End;
   SelectDoc(Wn[W].Doc);
   FitWin(W);
   Inc(K);
  End;
 End;
 X:=0;Y:=0;
 If WCnt>0 Then SelectDoc(Wn[WZo[WCnt]].Doc);
End;

Procedure ZoomCmd(Z: Integer);
Var W: Integer;
Begin
 W:=ActiveWin;If W=0 Then Exit;
 SetZoom(W,Z);
End;

Procedure ZStep(Dir: Integer);
Const Steps: Array[1..9] Of Integer = (10,25,50,75,100,150,200,300,400);
Var W,I,N: Integer;
Begin
 W:=ActiveWin;If W=0 Then Exit;
 N:=0;
 If Dir>0 Then Begin
  For I:=9 DownTo 1 Do If Steps[I]>Wn[W].Zoom Then N:=Steps[I];
 End Else Begin
  For I:=1 To 9 Do If Steps[I]<Wn[W].Zoom Then N:=Steps[I];
 End;
 If N>0 Then SetZoom(W,N);
End;

Procedure HelpText(K: Integer);
Begin
 TLClear;
 Case K Of
  1: Begin
    TLAdd(T5('AIDE DE SOLDERRUN-BPM (clone)','SOLDERRUN-BPM HELP (clone)',
      'SOLDERRUN-BPM-HILFE (Klon)','AYUDA DE SOLDERRUN-BPM (clon)',
      'GUIDA DI SOLDERRUN-BPM (clone)'));
    TLAdd('');
    TLAdd(T5('Palette d''outils (colonne de droite) :',
      'Tool box (right column):','Werkzeugpalette (rechte Spalte):',
      'Paleta (columna derecha):','Tavolozza (colonna destra):'));
    TLAdd(T5('  S@election, Processus, Entit@e, Entrep@ot, Flux,',
      '  Select, Process, Entity, Store, Flow,',
      '  Auswahl, Prozess, Entit@1t, Speicher, Fluss,',
      '  Selecci@pn, Proceso, Entidad, Almac@gn, Flujo,',
      '  Selezione, Processo, Entit@r, Archivio, Flusso,'));
    TLAdd(T5('  Parent, Ajuster, Zoom avant.','  Parent, Fit, Zoom in.',
      '  Eltern, Anpassen, Vergr@2@7ern.','  Padre, Ajustar, Acercar.',
      '  Genitore, Adatta, Ingrandisci.'));
    TLAdd(T5('Colonne de gauche : d@ecomposer, propri@et@es,',
      'Left column: decompose, properties,',
      'Linke Spalte: Zerlegen, Eigenschaften,',
      'Columna izquierda: descomponer, propiedades,',
      'Colonna sinistra: scomponi, propriet@r,'));
    TLAdd(T5('environnement, surlignage, qualifiant, ressource, texte, zoom '+
      'arri@gre.',
      'environment, highlight, qualifier, resource, text, zoom out.',
      'Umgebung, Hervorheben, Qualifizierer, Ressource, Text, Verkleinern.',
      'entorno, resaltar, calificador, recurso, texto, alejar.',
      'ambiente, evidenzia, qualificatore, risorsa, testo, riduci.'));
    TLAdd('');
    TLAdd(T5('Flux : outil Flux, cliquer l''origine puis la destination.',
      'Flows: Flow tool, click the source then the target.',
      'Fl@3sse: Flusswerkzeug, Quelle dann Ziel anklicken.',
      'Flujos: herramienta Flujo, clic en origen y luego destino.',
      'Flussi: strumento Flusso, clic su origine poi destinazione.'));
    TLAdd(T5('Double-clic : propri@et@es. Glisser un flux : point de pliage.',
      'Double-click: properties. Drag a flow: bend point.',
      'Doppelklick: Eigenschaften. Fluss ziehen: Knickpunkt.',
      'Doble clic: propiedades. Arrastrar un flujo: punto de pliegue.',
      'Doppio clic: propriet@r. Trascinare un flusso: punto di piegatura.'));
    TLAdd(T5('Clic droit sur un objet : ajoute @a la s@election.',
      'Right-click an object: add to selection.',
      'Rechtsklick auf Objekt: zur Auswahl hinzuf@3gen.',
      'Clic derecho en un objeto: a@nadir a la selecci@pn.',
      'Clic destro su un oggetto: aggiunge alla selezione.'));
   End;
  2: Begin
    TLAdd(T5('GUIDE DE L''UTILISATEUR BPM','BPM USER''S GUIDE',
      'BPM-BENUTZERHANDBUCH','GU@jA DEL USUARIO BPM','GUIDA UTENTE BPM'));
    TLAdd('');
    TLAdd('F1 ........ '+T5('Aide','Help','Hilfe','Ayuda','Guida'));
    TLAdd('F2 ........ '+T5('Renommer','Rename','Umbenennen','Renombrar',
      'Rinomina'));
    TLAdd('F10 ....... '+T5('Menus','Menus','Men@3s','Men@3s','Menu'));
    TLAdd('Alt+lettre  '+T5('Ouvre un menu','Opens a menu','@2ffnet ein Men@3',
      'Abre un men@3','Apre un menu'));
    TLAdd('Alt+1..7 .. '+T5('Listes du mod@gle (Ctrl+1..7)',
      'Model lists (Ctrl+1..7)','Modelllisten (Strg+1..7)',
      'Listas del modelo (Ctrl+1..7)','Elenchi del modello (Ctrl+1..7)'));
    TLAdd('Ctrl+N/O/S '+T5('Nouveau / Ouvrir / Enregistrer','New / Open / Save',
      'Neu / @2ffnen / Speichern','Nuevo / Abrir / Guardar',
      'Nuovo / Apri / Salva'));
    TLAdd('Ctrl+Z/Y .. '+T5('Annuler / R@etablir','Undo / Redo',
      'R@3ckg@1ngig / Wiederholen','Deshacer / Rehacer','Annulla / Ripeti'));
    TLAdd('Ctrl+X/C/V '+T5('Couper / Copier / Coller','Cut / Copy / Paste',
      'Ausschneiden / Kopieren / Einf@3gen','Cortar / Copiar / Pegar',
      'Taglia / Copia / Incolla'));
    TLAdd('Ctrl+D .... '+T5('Dupliquer','Duplicate','Duplizieren','Duplicar',
      'Duplica'));
    TLAdd('Ctrl+A/L/G '+T5('Tout / S@electionner / Aller @a la page',
      'All / Select / Go to page','Alle / Ausw@1hlen / Gehe zu Seite',
      'Todo / Seleccionar / Ir a p@rgina','Tutto / Seleziona / Vai a pagina'));
    TLAdd('Ctrl+T/U .. '+T5('Redresser / Inverser un flux',
      'Straighten / Reverse a flow','Fluss begradigen / umkehren',
      'Enderezar / invertir flujo','Raddrizza / inverti flusso'));
    TLAdd('Ctrl+F .... '+T5('Ajuster','Fit','Anpassen','Ajustar','Adatta'));
    TLAdd('Ctrl+H .... '+T5('Masquer','Hide','Ausblenden','Ocultar',
      'Nascondi'));
    TLAdd('Suppr/Del .. '+T5('Effacer','Clear','L@2schen','Borrar','Cancella'));
    TLAdd('Tab ....... '+T5('Objet suivant','Next object','N@1chstes Objekt',
      'Objeto siguiente','Oggetto successivo'));
    TLAdd('+ / - ..... Zoom');
   End;
  3: Begin
    TLAdd(T5('NOTES DE VERSION','RELEASE NOTES','VERSIONSHINWEISE',
      'NOTAS DE LA VERSI@pN','NOTE DI RILASCIO'));
    TLAdd('');
    TLAdd('1.00');
    TLAdd(T5('- Premi@gre version du clone SOLDERRUN-BPM.',
      '- First version of the SOLDERRUN-BPM clone.',
      '- Erste Version des SOLDERRUN-BPM-Klons.',
      '- Primera versi@pn del clon de SOLDERRUN-BPM.',
      '- Prima versione del clone SOLDERRUN-BPM.'));
    TLAdd(T5('- Lecture des fichiers .DFD de SolderRun (3.1 et 2.2.4), '+
      'positions des processus lues.',
      '- Reading SolderRun .DFD files (3.1 and 2.2.4), process positions read.',
      '- Lesen von SolderRun-.DFD-Dateien (3.1 und 2.2.4), Prozesspositionen '+
      'gelesen.','- Lectura de archivos .DFD de SolderRun (3.1 y 2.2.4), '+
      'posiciones de procesos le@jdas.',
      '- Lettura di file .DFD di SolderRun (3.1 e 2.2.4), posizioni dei '+
      'processi lette.'));
    TLAdd(T5('- Enregistrement au format natif .SRD.',
      '- Saving in the native .SRD format.',
      '- Speichern im nativen .SRD-Format.',
      '- Guardado en el formato nativo .SRD.',
      '- Salvataggio nel formato nativo .SRD.'));
    TLAdd(T5('- Interface MDI : plusieurs mod@gles ouverts simultan@ement.',
      '- MDI interface: several models open at the same time.',
      '- MDI-Oberfl@1che: mehrere Modelle gleichzeitig ge@2ffnet.',
      '- Interfaz MDI: varios modelos abiertos a la vez.',
      '- Interfaccia MDI: pi@m modelli aperti contemporaneamente.'));
   End;
  Else Begin
    TLAdd(T5('LICENCES','LICENSES','LIZENZEN','LICENCIAS','LICENZE'));
    TLAdd('');
    TLAdd(T5('Clone ind@ependant d''une application de diagrammes de flux.',
      'Independent clone of a data flow diagram application.',
      'Unabh@1ngiger Klon einer Datenflussdiagramm-Anwendung.',
      'Clon independiente de una aplicaci@pn de diagramas de flujo.',
      'Clone indipendente di un''applicazione di diagrammi di flusso.'));
    TLAdd(T5('SolderRun est une marque de ses propri@etaires.',
      'SolderRun is a trademark of its owners.',
      'SolderRun ist eine Marke seiner Eigent@3mer.',
      'SolderRun es una marca de sus propietarios.',
      'SolderRun @a un marchio dei suoi proprietari.'));
    TLAdd('Sylvain Maltais - support@@gladir.com - '+
      'https://www.gladir.com/office-0');
   End;
 End;
End;

Procedure ShowHelp(K: Integer);
Begin
 HelpText(K);
 ShowText(T5('Aide','Help','Hilfe','Ayuda','Guida'));
End;

{ ====================================================================== }
{                  EDITION A LA SOURIS DANS LE DIAGRAMME                 }
{ ====================================================================== }

Procedure XorRect(X1,Y1,X2,Y2: Integer);
Begin
 SetWriteMode(XORPut);
 SetColor(cWht);
 SetLineStyle(SolidLn,0,1);
 Rectangle(X1,Y1,X2,Y2);
 SetWriteMode(CopyPut);
End;

Procedure XorLine(X1,Y1,X2,Y2: Integer);
Begin
 SetWriteMode(XORPut);
 SetColor(cWht);
 SetLineStyle(SolidLn,0,1);
 Line(X1,Y1,X2,Y2);
 SetWriteMode(CopyPut);
End;

Function HitElem(D: Integer; PX,PY: LongInt): Integer;
Var I,Best: Integer;
Begin
 Best:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And Not Mdl^.El[I].Hid Then
   If InBox(PX,PY,SXc(Mdl^.El[I].X),SYc(Mdl^.El[I].Y),
     SXc(Mdl^.El[I].X+Mdl^.El[I].W),SYc(Mdl^.El[I].Y+Mdl^.El[I].H)) Then Begin
    If (Best=0) Or (Mdl^.El[I].Z>Mdl^.El[Best].Z) Then Best:=I;
   End;
 HitElem:=Best;
End;

Function DistSeg2(PX,PY,AX,AY,BX,BY: LongInt): LongInt;
Var DX,DY,T,L2,QX,QY: LongInt;
Begin
 DX:=BX-AX;DY:=BY-AY;L2:=DX*DX+DY*DY;
 If L2=0 Then T:=0 Else T:=((PX-AX)*DX+(PY-AY)*DY)*1000 Div L2;
 If T<0 Then T:=0;If T>1000 Then T:=1000;
 QX:=AX+DX*T Div 1000;QY:=AY+DY*T Div 1000;
 DistSeg2:=(PX-QX)*(PX-QX)+(PY-QY)*(PY-QY);
End;

Function HitFlow(D: Integer; PX,PY: LongInt): Integer;
Var I: Integer; X1,Y1,X2,Y2: LongInt; HBX,HBY: LongInt;
Begin
 HitFlow:=0;
 For I:=1 To MAXFL Do
  If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) And Not Mdl^.Fl[I].Hid And
    FlowGeom(I,X1,Y1,X2,Y2) Then Begin
   If Mdl^.Fl[I].Bend Then Begin
    HBX:=SXc(Mdl^.Fl[I].BX);HBY:=SYc(Mdl^.Fl[I].BY);
    If (DistSeg2(PX,PY,SXc(X1),SYc(Y1),HBX,HBY)<=25) Or (DistSeg2(PX,PY,HBX,HBY,
      SXc(X2),SYc(Y2))<=25) Then HitFlow:=I;
   End Else
    If DistSeg2(PX,PY,SXc(X1),SYc(Y1),SXc(X2),SYc(Y2))<=25 Then HitFlow:=I;
  End;
End;

Procedure ClipView(W: Integer);
Var X1,Y1,X2,Y2: Integer;
Begin
 CanvasRect(W,X1,Y1,X2,Y2);
 SetViewPort(X1,Y1,X2,Y2,True);
End;

Procedure NoClip;
Begin
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
End;

{ deplacement de la selection avec contours XOR }
Procedure MoveDrag(W: Integer; SX0,SY0: LongInt);
Var D,I,F,First: Integer; E: TEvent; DX,DY,NDX,NDY: LongInt; Moved,Cancel:
  Boolean;
Procedure Outlines;
Var K: Integer;
Begin
 For K:=1 To MAXEL Do
  If Mdl^.El[K].Used And Mdl^.El[K].Sel And (Mdl^.El[K].Diag=D) Then
   XorRect(SXc(Mdl^.El[K].X+DX),SYc(Mdl^.El[K].Y+DY),
     SXc(Mdl^.El[K].X+Mdl^.El[K].W+DX),SYc(Mdl^.El[K].Y+Mdl^.El[K].H+DY));
End;
Begin
 D:=Wn[W].Diag;
 First:=0;
 For I:=1 To MAXEL Do If (First=0) And Mdl^.El[I].Used And Mdl^.El[I].Sel And
   (Mdl^.El[I].Diag=D) Then First:=I;
 If First=0 Then Exit;
 DX:=0;DY:=0;Moved:=False;Cancel:=False;
 HideMouse;ClipView(W);ShowMouse;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then If E.Key=K_ESC Then Cancel:=True;
  If E.Kind=4 Then Begin
   NDX:=SnapV(Mdl^.El[First].X+(E.X-CVX-SX0)*100 Div VZ)-Mdl^.El[First].X;
   NDY:=SnapV(Mdl^.El[First].Y+(E.Y-CVY-SY0)*100 Div VZ)-Mdl^.El[First].Y;
   If (NDX<>DX) Or (NDY<>DY) Then Begin
    HideMouse;
    If Moved Then Outlines;
    DX:=NDX;DY:=NDY;Moved:=True;
    Outlines;
    ShowMouse;
   End;
  End;
 Until (E.Kind=3) Or Cancel;
 HideMouse;
 If Moved Then Outlines;
 NoClip;ShowMouse;
 If Moved And Not Cancel And ((DX<>0) Or (DY<>0)) Then Begin
  PushUndo;
  For I:=1 To MAXEL Do
   If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then Begin
    Mdl^.El[I].X:=Mdl^.El[I].X+Integer(DX);
      Mdl^.El[I].Y:=Mdl^.El[I].Y+Integer(DY);
   End;
  For F:=1 To MAXFL Do
   If Mdl^.Fl[F].Used And (Mdl^.Fl[F].Diag=D) And Mdl^.Fl[F].Bend Then Begin
    If Mdl^.El[FindEl(Mdl^.Fl[F].A)].Sel And Mdl^.El[FindEl(Mdl^.Fl[F].B)].Sel
      Then Begin
     Mdl^.Fl[F].BX:=Mdl^.Fl[F].BX+Integer(DX);
       Mdl^.Fl[F].BY:=Mdl^.Fl[F].BY+Integer(DY);
    End;
   End;
 End;
End;

Procedure ResizeDrag(W,I,H: Integer);
Var D: Integer; E: TEvent; X1,Y1,X2,Y2,NX1,NY1,NX2,NY2: LongInt; Moved,Cancel:
  Boolean;
Begin
 D:=Wn[W].Diag;
 X1:=Mdl^.El[I].X;Y1:=Mdl^.El[I].Y;X2:=X1+Mdl^.El[I].W;Y2:=Y1+Mdl^.El[I].H;
 NX1:=X1;NY1:=Y1;NX2:=X2;NY2:=Y2;Moved:=False;Cancel:=False;
 HideMouse;ClipView(W);ShowMouse;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then If E.Key=K_ESC Then Cancel:=True;
  If E.Kind=4 Then Begin
   HideMouse;
   If Moved Then XorRect(SXc(NX1),SYc(NY1),SXc(NX2),SYc(NY2));
   NX1:=X1;NY1:=Y1;NX2:=X2;NY2:=Y2;
   If H In [1,7,8] Then NX1:=SnapV(MXc(E.X-CVX));
   If H In [3,4,5] Then NX2:=SnapV(MXc(E.X-CVX));
   If H In [1,2,3] Then NY1:=SnapV(MYc(E.Y-CVY));
   If H In [5,6,7] Then NY2:=SnapV(MYc(E.Y-CVY));
   If NX2-NX1<24 Then Begin If H In [1,7,8] Then NX1:=NX2-24 Else NX2:=NX1+24;
     End;
   If NY2-NY1<14 Then Begin If H In [1,2,3] Then NY1:=NY2-14 Else NY2:=NY1+14;
     End;
   XorRect(SXc(NX1),SYc(NY1),SXc(NX2),SYc(NY2));Moved:=True;
   ShowMouse;
  End;
 Until (E.Kind=3) Or Cancel;
 HideMouse;
 If Moved Then XorRect(SXc(NX1),SYc(NY1),SXc(NX2),SYc(NY2));
 NoClip;ShowMouse;
 If Moved And Not Cancel Then Begin
  PushUndo;
  Mdl^.El[I].X:=Integer(NX1);Mdl^.El[I].Y:=Integer(NY1);
  Mdl^.El[I].W:=Integer(NX2-NX1);Mdl^.El[I].H:=Integer(NY2-NY1);
 End;
End;

Procedure Marquee(W: Integer; SX0,SY0: LongInt; Extend: Boolean);
Var D,I: Integer; E: TEvent; X1,Y1,X2,Y2,CX,CY: LongInt; Moved,Cancel: Boolean;
  A,B: Integer;
    FX1,FY1,FX2,FY2: LongInt; LX1,LY1,LX2,LY2: Integer;
Begin
 D:=Wn[W].Diag;
 LX1:=SX0;LY1:=SY0;LX2:=SX0;LY2:=SY0;Moved:=False;Cancel:=False;
 HideMouse;ClipView(W);ShowMouse;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then If E.Key=K_ESC Then Cancel:=True;
  If E.Kind=4 Then Begin
   HideMouse;
   If Moved Then XorRect(LX1,LY1,LX2,LY2);
   LX2:=E.X-CVX;LY2:=E.Y-CVY;Moved:=True;
   XorRect(LX1,LY1,LX2,LY2);
   ShowMouse;
  End;
 Until (E.Kind=3) Or Cancel;
 HideMouse;
 If Moved Then XorRect(LX1,LY1,LX2,LY2);
 NoClip;ShowMouse;
 If Not Extend Then ClearSel;
 If Moved And Not Cancel Then Begin
  X1:=Min2(MXc(LX1),MXc(LX2));X2:=Max2(MXc(LX1),MXc(LX2));
  Y1:=Min2(MYc(LY1),MYc(LY2));Y2:=Max2(MYc(LY1),MYc(LY2));
  For I:=1 To MAXEL Do
   If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And Not Mdl^.El[I].Hid Then
    If (Mdl^.El[I].X<=X2) And (Mdl^.El[I].X+Mdl^.El[I].W>=X1) And
       (Mdl^.El[I].Y<=Y2) And (Mdl^.El[I].Y+Mdl^.El[I].H>=Y1) Then
         Mdl^.El[I].Sel:=True;
  For I:=1 To MAXFL Do
   If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) And Not Mdl^.Fl[I].Hid And
     FlowGeom(I,FX1,FY1,FX2,FY2) Then Begin
    CX:=(FX1+FX2) Div 2;CY:=(FY1+FY2) Div 2;
    If (CX>=X1) And (CX<=X2) And (CY>=Y1) And (CY<=Y2) Then
      Mdl^.Fl[I].Sel:=True;
   End;
 End;
 A:=0;B:=0;
End;

Procedure NameNewFlow(F: Integer);
Var S: String;
Begin
 S:='';
 If InputBox(T5('Nom du flux','Flow name','Flussname','Nombre del flujo',
   'Nome del flusso'),
    T5('Nom :','Name:','Name:','Nombre:','Nome:'),S,30) Then Begin
  Mdl^.Fl[F].Name:=S;
 End;
End;

Procedure FlowTool(W: Integer; PX,PY: LongInt);
Var D,A,B,F: Integer; E: TEvent; CX,CY,LX,LY: Integer; Done,Drag,Moved: Boolean;
Begin
 D:=Wn[W].Diag;
 A:=HitElem(D,PX,PY);
 If (A=0) Or (Mdl^.El[A].Kind=ekText) Or (Mdl^.El[A].Kind=ekInfo) Then Exit;
 CX:=SXc(Mdl^.El[A].X+Mdl^.El[A].W Div 2);CY:=SYc(Mdl^.El[A].Y+Mdl^.El[A].H Div
   2);
 LX:=CX;LY:=CY;Done:=False;Drag:=True;Moved:=False;
 HideMouse;ClipView(W);ShowMouse;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin If E.Key=K_ESC Then Done:=True;End;
  If E.Kind=4 Then Begin
   HideMouse;
   If Moved Then XorLine(CX,CY,LX,LY);
   LX:=E.X-CVX;LY:=E.Y-CVY;Moved:=True;
   XorLine(CX,CY,LX,LY);
   ShowMouse;
  End;
  If ((E.Kind=3) And Drag) Or ((E.Kind=2) And Not Drag) Then Begin
   B:=HitElem(D,E.X-CVX,E.Y-CVY);
   If (B>0) And (B<>A) Then Begin
    HideMouse;If Moved Then XorLine(CX,CY,LX,LY);Moved:=False;NoClip;ShowMouse;
    If (Mdl^.El[B].Kind=ekText) Or Not FlowOK(Mdl^.El[A].Kind,Mdl^.El[B].Kind)
      Then
     Msg(T5('Un flux doit relier un processus @a un autre objet.',
       'A flow must connect a process to another object.',
       'Ein Fluss muss einen Prozess mit einem anderen Objekt verbinden.',
       'Un flujo debe conectar un proceso con otro objeto.',
       'Un flusso deve collegare un processo a un altro oggetto.'))
    Else Begin
     PushUndo;
     F:=NewFl(D,Mdl^.El[A].Id,Mdl^.El[B].Id);
     If F>0 Then Begin ClearSel;Mdl^.Fl[F].Sel:=True;NameNewFlow(F);End;
    End;
    Done:=True;
    HideMouse;ClipView(W);ShowMouse;
   End Else Begin
    If E.Kind=3 Then Drag:=False Else Done:=True;
   End;
  End;
 Until Done;
 HideMouse;
 If Moved Then XorLine(CX,CY,LX,LY);
 NoClip;ShowMouse;
End;

Procedure BendDrag(W,F: Integer);
Var E: TEvent; X1,Y1,X2,Y2: LongInt; LX,LY: Integer; Moved,Cancel: Boolean; SA,
  SB,EA,EB: Integer;
Begin
 If Not FlowGeom(F,X1,Y1,X2,Y2) Then Exit;
 SA:=SXc(X1);SB:=SYc(Y1);EA:=SXc(X2);EB:=SYc(Y2);
 LX:=0;LY:=0;Moved:=False;Cancel:=False;
 HideMouse;ClipView(W);ShowMouse;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then If E.Key=K_ESC Then Cancel:=True;
  If E.Kind=4 Then Begin
   HideMouse;
   If Moved Then Begin XorLine(SA,SB,LX,LY);XorLine(LX,LY,EA,EB);End;
   LX:=E.X-CVX;LY:=E.Y-CVY;Moved:=True;
   XorLine(SA,SB,LX,LY);XorLine(LX,LY,EA,EB);
   ShowMouse;
  End;
 Until (E.Kind=3) Or Cancel;
 HideMouse;
 If Moved Then Begin XorLine(SA,SB,LX,LY);XorLine(LX,LY,EA,EB);End;
 NoClip;ShowMouse;
 If Moved And Not Cancel Then Begin
  PushUndo;
  Mdl^.Fl[F].Bend:=True;
  Mdl^.Fl[F].BX:=SnapV(MXc(LX));Mdl^.Fl[F].BY:=SnapV(MYc(LY));
 End;
End;

Procedure PlaceElem(W,Kind: Integer; PX,PY: LongInt);
Var D,I: Integer; S: String;
Begin
 D:=Wn[W].Diag;
 PushUndo;
 I:=NewEl(Kind,D,Integer(MXc(PX)),Integer(MYc(PY)));
 If I=0 Then Begin Msg(T5('Trop d''objets.','Too many objects.',
   'Zu viele Objekte.','Demasiados objetos.','Troppi oggetti.'));Exit;End;
 Mdl^.El[I].X:=SnapV(Mdl^.El[I].X);Mdl^.El[I].Y:=SnapV(Mdl^.El[I].Y);
 If Mdl^.El[I].X<6 Then Mdl^.El[I].X:=6;
 If Mdl^.El[I].Y<30 Then Mdl^.El[I].Y:=30;
 ClearSel;Mdl^.El[I].Sel:=True;
 CurTool:=tlSelect;
 If Kind=ekText Then Begin
  S:=Mdl^.El[I].Name;
  If InputBox(T5('Texte','Text','Text','Texto','Testo'),T5('Texte :','Text:',
    'Text:','Texto:','Testo:'),S,40) Then Mdl^.El[I].Name:=S;
 End;
End;

Procedure PickDict(Cat: Integer; Var Cur: Integer; Const Title: String);
Begin
 FormBegin(Title);
 FormAdd(3,ListTitle(6,Cat),IntStr(Cur),0,IntStr(Cat));
 If RunForm Then Cur:=ValInt(Frm.Val[1],0);
End;

Procedure CanvasDown(W: Integer; X,Y: LongInt; Right,Dbl: Boolean);
Var D,CX1,CY1,CX2,CY2,I,F,H,K: Integer; PX,PY: LongInt; Q: Integer;
Begin
 SetView(W);
 CanvasRect(W,CX1,CY1,CX2,CY2);
 PX:=X;PY:=Y;
 D:=Wn[W].Diag;
 Case CurTool Of
  tlProc: PlaceElem(W,ekProc,PX,PY);
  tlEnt: PlaceElem(W,ekEnt,PX,PY);
  tlStore: PlaceElem(W,ekStore,PX,PY);
  tlText: PlaceElem(W,ekText,PX,PY);
  tlFlow: FlowTool(W,PX,PY);
  tlQual: Begin
    F:=HitFlow(D,PX,PY);
    If F>0 Then Begin
     Q:=Mdl^.Fl[F].Qual;
     PickDict(dcQual,Q,T5('Qualifiant','Qualifier','Qualifizierer',
       'Calificador','Qualificatore'));
     If Q<>Mdl^.Fl[F].Qual Then Begin PushUndo;Mdl^.Fl[F].Qual:=Q;End;
    End;
   End;
  tlRes: Begin
    I:=HitElem(D,PX,PY);
    If (I>0) And (Mdl^.El[I].Kind=ekProc) Then Begin
     Q:=Mdl^.El[I].Res;
     PickDict(dcRes,Q,T5('Ressource','Resource','Ressource','Recurso',
       'Risorsa'));
     If Q<>Mdl^.El[I].Res Then Begin PushUndo;Mdl^.El[I].Res:=Q;End;
    End;
   End;
  Else Begin
   { outil de selection }
   K:=0;
   For I:=1 To MAXEL Do If Mdl^.El[I].Used And Mdl^.El[I].Sel And
     (Mdl^.El[I].Diag=D) Then Begin Inc(K);F:=I;End;
   If (K=1) And (SelFlCount(D)=0) Then Begin
    H:=HandleHit(F,PX,PY);
    If H>0 Then Begin ResizeDrag(W,F,H);Exit;End;
   End;
   I:=HitElem(D,PX,PY);
   If I>0 Then Begin
    If Dbl Then Begin
     If (Mdl^.El[I].Kind=ekProc) And (Mdl^.El[I].Child>0) And Cfg.AutoOpen And
       Mdl^.Dg[Mdl^.El[I].Child].Used Then Begin
      OpenFit(Mdl^.El[I].Child);
     End Else ElemProps(I);
     Exit;
    End;
    If Right Then Mdl^.El[I].Sel:=Not Mdl^.El[I].Sel
    Else If Not Mdl^.El[I].Sel Then Begin ClearSel;Mdl^.El[I].Sel:=True;End;
    DrawAll;
    If Not Right Then MoveDrag(W,X,Y);
   End Else Begin
    F:=HitFlow(D,PX,PY);
    If F>0 Then Begin
     If Dbl Then Begin FlowProps(F);Exit;End;
     If Right Then Mdl^.Fl[F].Sel:=Not Mdl^.Fl[F].Sel
     Else Begin ClearSel;Mdl^.Fl[F].Sel:=True;End;
     DrawAll;
     If Not Right Then BendDrag(W,F);
    End Else Marquee(W,X,Y,Right);
   End;
  End;
 End;
End;

{ ---- defilement ---- }

Function ScrollMouse(W: Integer; X,Y: LongInt): Boolean;
Var A,B,C,D,CX1,CY1,CX2,CY2,TL,TH,Th2,Tp: Integer; M,V: LongInt; E: TEvent; Off:
  LongInt;
Begin
 ScrollMouse:=False;
 WinRect(W,A,B,C,D);
 CanvasRect(W,CX1,CY1,CX2,CY2);
 { verticale }
 If InBox(X,Y,CX2+2,CY1,C-3,CY2) Then Begin
  ScrollMouse:=True;
  M:=ContentH(W);V:=CY2-CY1+1;
  TL:=CY1+16;TH:=CY2-16-TL;
  If Y<CY1+16 Then Dec(Wn[W].SY,24)
  Else If Y>CY2-16 Then Inc(Wn[W].SY,24)
  Else If (M>V) And (TH>10) Then Begin
   Th2:=TH*V Div M;If Th2<10 Then Th2:=10;
   Tp:=TL+(TH-Th2)*Wn[W].SY Div (M-V);
   If Y<Tp Then Dec(Wn[W].SY,V)
   Else If Y>Tp+Th2 Then Inc(Wn[W].SY,V)
   Else Begin
    Off:=Y-Tp;
    Repeat
     PollEvent(E);
     If E.Kind=4 Then Begin
      Wn[W].SY:=(E.Y-Off-TL)*(M-V) Div (TH-Th2);
      ClampScroll(W);DrawAll;
     End;
    Until E.Kind=3;
   End;
  End;
  ClampScroll(W);Exit;
 End;
 { horizontale }
 If InBox(X,Y,CX1,CY2+2,CX2,D-3) Then Begin
  ScrollMouse:=True;
  M:=ContentW(W);V:=CX2-CX1+1;
  TL:=CX1+16;TH:=CX2-16-TL;
  If X<CX1+16 Then Dec(Wn[W].SX,24)
  Else If X>CX2-16 Then Inc(Wn[W].SX,24)
  Else If (M>V) And (TH>10) Then Begin
   Th2:=TH*V Div M;If Th2<10 Then Th2:=10;
   Tp:=TL+(TH-Th2)*Wn[W].SX Div (M-V);
   If X<Tp Then Dec(Wn[W].SX,V)
   Else If X>Tp+Th2 Then Inc(Wn[W].SX,V)
   Else Begin
    Off:=X-Tp;
    Repeat
     PollEvent(E);
     If E.Kind=4 Then Begin
      Wn[W].SX:=(E.X-Off-TL)*(M-V) Div (TH-Th2);
      ClampScroll(W);DrawAll;
     End;
    Until E.Kind=3;
   End;
  End;
  ClampScroll(W);
 End;
End;

Procedure MoveWinDrag(W: Integer; SX0,SY0: LongInt);
Var E: TEvent; A,B,C,D,DX,DY: Integer; Moved: Boolean;
Begin
 WinRect(W,A,B,C,D);
 DX:=0;DY:=0;Moved:=False;
 Repeat
  PollEvent(E);
  If E.Kind=4 Then Begin
   HideMouse;
   If Moved Then XorRect(A+DX,B+DY,C+DX,D+DY);
   DX:=E.X-SX0;DY:=E.Y-SY0;Moved:=True;
   XorRect(A+DX,B+DY,C+DX,D+DY);
   ShowMouse;
  End;
 Until E.Kind=3;
 HideMouse;
 If Moved Then XorRect(A+DX,B+DY,C+DX,D+DY);
 ShowMouse;
 Wn[W].X:=Wn[W].X+DX;Wn[W].Y:=Wn[W].Y+DY;
 If Wn[W].X<0 Then Wn[W].X:=0;
 If Wn[W].Y<0 Then Wn[W].Y:=0;
End;

Procedure MoveBoxDrag(SX0,SY0: LongInt);
Var E: TEvent; X1,Y1,X2,Y2,DX,DY: Integer; Moved: Boolean;
Begin
 BoxRect(X1,Y1,X2,Y2);
 DX:=0;DY:=0;Moved:=False;
 Repeat
  PollEvent(E);
  If E.Kind=4 Then Begin
   HideMouse;
   If Moved Then XorRect(X1+DX,Y1+DY,X2+DX,Y2+DY);
   DX:=E.X-SX0;DY:=E.Y-SY0;Moved:=True;
   XorRect(X1+DX,Y1+DY,X2+DX,Y2+DY);
   ShowMouse;
  End;
 Until E.Kind=3;
 HideMouse;
 If Moved Then XorRect(X1+DX,Y1+DY,X2+DX,Y2+DY);
 ShowMouse;
 TbX:=TbX+DX;TbY:=TbY+DY;
 If TbX<0 Then TbX:=0;
 If TbY<WsY0 Then TbY:=WsY0;
 If TbX>SCR_W-60 Then TbX:=SCR_W-60;
 If TbY>WsY1-60 Then TbY:=WsY1-60;
End;

Procedure MouseDown(X,Y: LongInt; Right: Boolean);
Var T,Cm,K,W,A,B,C,D,CX1,CY1,CX2,CY2: Integer; Dbl: Boolean;
Begin
 Dbl:=IsDouble(X,Y);
 StatMsg:='';
 T:=TitleHit(X,Y);
 If T>0 Then Begin RunMenu(T,True);Exit;End;
 If (Y<TITLE_H) Then Begin If X>=SCR_W-20 Then CmdQuit;Exit;End;
 Cm:=ToolHit(X,Y);
 If Cm>0 Then Begin If CmdEnabled(Cm) Then DoCmd(Cm);Exit;End;
 K:=BoxHit(X,Y);
 If K<>0 Then Begin
  If K=-2 Then ToolBoxOn:=False
  Else If K=-1 Then MoveBoxDrag(X,Y)
  Else If K>0 Then Begin
   If BoxCmd[K]>=1000 Then CurTool:=BoxCmd[K]-1000
   Else If CmdEnabled(BoxCmd[K]) Then DoCmd(BoxCmd[K]);
  End;
  DrawAll;Exit;
 End;
 W:=WinAt(X,Y);
 If W=0 Then Exit;
 If Wn[W].Iconic Then Begin Wn[W].Iconic:=False;WinToFront(W);DrawAll;Exit;End;
 If W<>ActiveWin Then Begin WinToFront(W);DrawAll;End;
 WinRect(W,A,B,C,D);
 CanvasRect(W,CX1,CY1,CX2,CY2);
 If InBox(X,Y,A,B,C,B+TITLE_H) Then Begin
  If InBox(X,Y,C-20,B+3,C-5,B+16) Then Begin CmdCloseWin;Exit;End;
  If InBox(X,Y,C-36,B+3,C-22,B+16) Then Begin WMax:=Not WMax;ClampScroll(W);
    DrawAll;Exit;End;
  If InBox(X,Y,C-52,B+3,C-38,B+16) Then Begin Wn[W].Iconic:=True;DrawAll;Exit;
    End;
  If Dbl Then Begin WMax:=Not WMax;ClampScroll(W);DrawAll;Exit;End;
  If Not WMax Then Begin MoveWinDrag(W,X,Y);DrawAll;End;
  Exit;
 End;
 If ScrollMouse(W,X,Y) Then Begin DrawAll;Exit;End;
 If InBox(X,Y,CX1,CY1,CX2,CY2) Then Begin
  CanvasDown(W,X-CX1,Y-CY1,Right,Dbl);
  DrawAll;
 End;
End;

{ ====================================================================== }
{                  DISPATCH DES COMMANDES                                }
{ ====================================================================== }

Procedure SetFlag(Var B: Boolean);
Begin
 B:=Not B;
End;

Procedure DoCmd(Cm: Integer);
Var D,W,I,K: Integer; MinZ: Integer;
Begin
 D:=CurDiag;W:=ActiveWin;
 Case Cm Of
  cmNew: CmdNew;
  cmOpen: CmdOpen;
  cmClose: CmdCloseWin;
  cmSave: K:=Ord(DoSave);
  cmSaveAs: K:=Ord(DoSaveAs);
  cmPass: CmdPass;
  cmImpExp: CmdImpExp;
  cmReport: CmdReport;
  cmPageSetup: CmdPageSetup;
  cmPrint: CmdPrint;
  cmExit: CmdQuit;
  cmUndo: DoUndo;
  cmRedo: DoRedo;
  cmCut: If D>0 Then Begin CopySel(D);DelSel;End;
  cmCopy: If D>0 Then CopySel(D);
  cmPaste: If D>0 Then Begin PushUndo;PasteCB(D,20);End;
  cmClear: DelSel;
  cmDup: If D>0 Then Begin CopySel(D);PushUndo;PasteCB(D,20);End;
  cmSelAll: If D>0 Then Begin
      ClearSel;
      For I:=1 To MAXEL Do If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And Not
        Mdl^.El[I].Hid Then Mdl^.El[I].Sel:=True;
      For I:=1 To MAXFL Do If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) And Not
        Mdl^.Fl[I].Hid Then Mdl^.Fl[I].Sel:=True;
     End;
  cmSelect: SelectByName;
  cmGoto: GotoPage;
  cmToolbars: CmdToolbars;
  cmStraight: If D>0 Then Begin
      PushUndo;
      For I:=1 To MAXFL Do If Mdl^.Fl[I].Used And Mdl^.Fl[I].Sel And
        (Mdl^.Fl[I].Diag=D) Then Mdl^.Fl[I].Bend:=False;
     End;
  cmChgDir: If D>0 Then Begin
      PushUndo;
      For I:=1 To MAXFL Do
       If Mdl^.Fl[I].Used And Mdl^.Fl[I].Sel And (Mdl^.Fl[I].Diag=D) Then Begin
        K:=Mdl^.Fl[I].A;Mdl^.Fl[I].A:=Mdl^.Fl[I].B;Mdl^.Fl[I].B:=K;
       End;
     End;
  cmLabName: SetFlag(Cfg.ShName);
  cmLabQual: SetFlag(Cfg.ShQual);
  cmLabNum: SetFlag(Cfg.ShNum);
  cmLabRes: SetFlag(Cfg.ShRes);
  cmFit,cmCenter: If W>0 Then FitWin(W);
  cmRestore: If D>0 Then RestoreSize;
  cmResize: If D>0 Then ResizeSel;
  cmHide: If D>0 Then Begin
      PushUndo;
      For I:=1 To MAXEL Do If Mdl^.El[I].Used And Mdl^.El[I].Sel And
        (Mdl^.El[I].Diag=D) Then Begin Mdl^.El[I].Hid:=True;
        Mdl^.El[I].Sel:=False;End;
      For I:=1 To MAXFL Do If Mdl^.Fl[I].Used And Mdl^.Fl[I].Sel And
        (Mdl^.Fl[I].Diag=D) Then Begin Mdl^.Fl[I].Hid:=True;
        Mdl^.Fl[I].Sel:=False;End;
     End;
  cmShowAll: If D>0 Then Begin
      PushUndo;
      For I:=1 To MAXEL Do If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) Then
        Mdl^.El[I].Hid:=False;
      For I:=1 To MAXFL Do If Mdl^.Fl[I].Used And (Mdl^.Fl[I].Diag=D) Then
        Mdl^.Fl[I].Hid:=False;
     End;
  cmHilite,cmUnHilite: If D>0 Then Begin
      PushUndo;
      For I:=1 To MAXEL Do If Mdl^.El[I].Used And Mdl^.El[I].Sel And
        (Mdl^.El[I].Diag=D) Then Mdl^.El[I].Hi:=(Cm=cmHilite);
      For I:=1 To MAXFL Do If Mdl^.Fl[I].Used And Mdl^.Fl[I].Sel And
        (Mdl^.Fl[I].Diag=D) Then Mdl^.Fl[I].Hi:=(Cm=cmHilite);
     End;
  cmFont: ChangeFont;
  cmFront,cmBack: If D>0 Then Begin
      PushUndo;
      MinZ:=32000;
      For I:=1 To MAXEL Do If Mdl^.El[I].Used And (Mdl^.El[I].Z<MinZ) Then
        MinZ:=Mdl^.El[I].Z;
      For I:=1 To MAXEL Do
       If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then Begin
        If Cm=cmFront Then Begin Mdl^.El[I].Z:=Mdl^.NextZ;Inc(Mdl^.NextZ);End
        Else Begin Dec(MinZ);Mdl^.El[I].Z:=MinZ;End;
       End;
     End;
  cmDrawSize: DrawSize;
  cmZoom25: ZoomCmd(25);
  cmZoom50: ZoomCmd(50);
  cmZoom75: ZoomCmd(75);
  cmZoom100: ZoomCmd(100);
  cmZoom150: ZoomCmd(150);
  cmZoom200: ZoomCmd(200);
  cmZoomIn: ZStep(1);
  cmZoomOut: ZStep(-1);
  cmAlL..cmAlV: AlignSel(Cm);
  cmMProc: ModelList(1,0);
  cmMFlow: ModelList(2,0);
  cmMStore: ModelList(3,0);
  cmMEnt: ModelList(4,0);
  cmMRes: ModelList(6,dcRes);
  cmMQual: ModelList(6,dcQual);
  cmMDiag: ModelList(5,0);
  cmMDesc: CmdModelDesc;
  cmMUdf: CmdUdf;
  cmPDom: ModelList(6,dcDom);
  cmPType: ModelList(6,dcType);
  cmPComm: ModelList(6,dcComm);
  cmPStruct: ModelList(6,dcStruct);
  cmPTarget: ModelList(6,dcTarget);
  cmPRule: ModelList(6,dcRule);
  cmPEvent: ModelList(6,dcEvent);
  cmPLoc: ModelList(6,dcLoc);
  cmPDesc: CmdProjDesc;
  cmVerify: CmdVerify;
  cmCleanup: CmdCleanup;
  cmGenList: ShowReport(1);
  cmGenTree: ShowReport(5);
  cmGenDict: ShowReport(4);
  cmMerge: CmdMerge;
  cmSplit: CmdSplit;
  cmTree: CmdTree;
  cmTreeUpd: Begin PushUndo;RenumAll;Msg(T5('Arbre des processus mis @a jour.',
    'Process tree updated.','Prozessbaum aktualisiert.',
    '@rrbol de procesos actualizado.','Albero dei processi aggiornato.'));End;
  cmParent: CmdParent;
  cmEnv,cmEnvUp: CmdEnv(False);
  cmEnvFlow: CmdEnv(True);
  cmRenum: CmdRenum;
  cmWRM: SetFlag(Cfg.WRM);
  cmOptions: CmdOptions;
  cmCascade: ArrangeWins(1);
  cmTileH: ArrangeWins(2);
  cmTileV: ArrangeWins(3);
  cmCloseAll: CmdCloseAll;
  cmArrange: Begin
      For I:=1 To MAXWIN Do If Wn[I].Used And Wn[I].Iconic Then
        Wn[I].Iconic:=True;
     End;
  cmWin1+1..cmWin1+MAXWIN: Begin
      I:=Cm-cmWin1;
      If Wn[I].Used Then Begin Wn[I].Iconic:=False;WinToFront(I);End;
     End;
  cmHelp: ShowHelp(1);
  cmGuide: ShowHelp(2);
  cmRelNotes: ShowHelp(3);
  cmLicenses: ShowHelp(4);
  cmAbout: Msg('SOLDERRUN-BPM (clone)~'+T5('Version 1.00 - Clone Turbo Pascal'+
    ' / Free Pascal','Version 1.00 - Turbo Pascal / Free Pascal clone',
    'Version 1.00 - Turbo-Pascal-/Free-Pascal-Klon',
    'Versi@pn 1.00 - Clon en Turbo Pascal / Free Pascal',
    'Versione 1.00 - Clone Turbo Pascal / Free Pascal')+'~Sylvain Maltais - '+
    'www.gladir.com/office-0');
  cmProps: PropsOfSel;
  cmRename: PropsOfSel;
  cmDecomp: DoDecompose;
  cmParentUp: DoParentUp;
  cmNextObj: If D>0 Then Begin
      K:=0;
      For I:=1 To MAXEL Do If Mdl^.El[I].Used And Mdl^.El[I].Sel And
        (Mdl^.El[I].Diag=D) Then K:=I;
      ClearSel;
      For I:=K+1 To MAXEL Do
       If (K<MAXEL) And Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And Not
         Mdl^.El[I].Hid Then Begin
        Mdl^.El[I].Sel:=True;K:=MAXEL;
       End;
     End;
  1001..1099: CurTool:=Cm-1000;
 End;
 If Not Quit Then DrawAll;
End;

{ ====================================================================== }
{                          CLAVIER ET BOUCLE                             }
{ ====================================================================== }

Procedure MoveSelBy(DX,DY: Integer);
Var D,I: Integer; Any: Boolean;
Begin
 D:=CurDiag;If D=0 Then Exit;
 Any:=False;
 For I:=1 To MAXEL Do If Mdl^.El[I].Used And Mdl^.El[I].Sel And
   (Mdl^.El[I].Diag=D) Then Any:=True;
 If Not Any Then Exit;
 PushUndo;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And Mdl^.El[I].Sel And (Mdl^.El[I].Diag=D) Then Begin
   Mdl^.El[I].X:=Mdl^.El[I].X+DX;Mdl^.El[I].Y:=Mdl^.El[I].Y+DY;
  End;
End;

Procedure HandleKey(K: Word);
Var L,W,G: Integer;
Begin
 W:=ActiveWin;
 If K>=256 Then Begin
  L:=AltLetter(K);
  If L>=0 Then Begin MenuByLetter(L);Exit;End;
 End;
 G:=Cfg.Grid;If G<2 Then G:=2;
 Case K Of
  K_F10: RunMenu(1,False);
  K_F1: DoCmd(cmHelp);
  K_F2: DoCmd(cmRename);
  14: DoCmd(cmNew);
  15: DoCmd(cmOpen);
  19: DoCmd(cmSave);
  16: DoCmd(cmPrint);
  26: DoCmd(cmUndo);
  25: DoCmd(cmRedo);
  24: If CmdEnabled(cmCut) Then DoCmd(cmCut);
  3: If CmdEnabled(cmCopy) Then DoCmd(cmCopy);
  22: If CmdEnabled(cmPaste) Then DoCmd(cmPaste);
  4: If CmdEnabled(cmDup) Then DoCmd(cmDup);
  1: DoCmd(cmSelAll);
  12: DoCmd(cmSelect);
  7: DoCmd(cmGoto);
  20: If CmdEnabled(cmStraight) Then DoCmd(cmStraight);
  21: If CmdEnabled(cmChgDir) Then DoCmd(cmChgDir);
  6: DoCmd(cmFit);
  K_BKSP: If CmdEnabled(cmHide) Then DoCmd(cmHide);
  K_CF4: DoCmd(cmClose);
  K_DEL: DoCmd(cmClear);
  K_ENTER: DoCmd(cmProps);
  K_TAB: DoCmd(cmNextObj);
  K_ESC: Begin CurTool:=tlSelect;Dirty:=True;End;
  43,61: ZStep(1);
  45: ZStep(-1);
  K_LEFT: If (CurDiag>0) And (SelElCount(CurDiag)>0) Then MoveSelBy(-G,0) Else
    If W>0 Then Begin Dec(Wn[W].SX,20);ClampScroll(W);End;
  K_RIGHT: If (CurDiag>0) And (SelElCount(CurDiag)>0) Then MoveSelBy(G,0) Else
    If W>0 Then Begin Inc(Wn[W].SX,20);ClampScroll(W);End;
  K_UP: If (CurDiag>0) And (SelElCount(CurDiag)>0) Then MoveSelBy(0,-G) Else If
    W>0 Then Begin Dec(Wn[W].SY,20);ClampScroll(W);End;
  K_DOWN: If (CurDiag>0) And (SelElCount(CurDiag)>0) Then MoveSelBy(0,G) Else If
    W>0 Then Begin Inc(Wn[W].SY,20);ClampScroll(W);End;
  K_PGUP: If W>0 Then Begin Dec(Wn[W].SY,200);ClampScroll(W);End;
  K_PGDN: If W>0 Then Begin Inc(Wn[W].SY,200);ClampScroll(W);End;
  K_HOME: If W>0 Then Begin Wn[W].SX:=0;Wn[W].SY:=0;End;
  376..382: If CmdEnabled(cmMProc) Then DoCmd(cmMProc+(K-376-0));
 End;
 { Alt+1..7 : codes etendus 120..126 }
 If (K>=376) And (K<=382) Then Begin End;
 Dirty:=True;
End;

Procedure MainLoop;
Var E: TEvent;
Begin
 Repeat
  If Dirty Then DrawAll;
  PollEvent(E);
  Case E.Kind Of
   1: HandleKey(E.Key);
   2: MouseDown(E.X,E.Y,False);
   5: MouseDown(E.X,E.Y,True);
  End;
 Until Quit;
End;

Procedure ShowHelpLine;
Begin
 WriteLn('SR - Clone de SolderRun (SOLDERRUN-BPM), diagrammes de flux de '+
   'donnees.');
 WriteLn;
 WriteLn('Utilisation : SR [fichier.SRD|fichier.DFD] [/?]');
 WriteLn;
 WriteLn('  fichier   Fichier de diagramme a ouvrir.');
 WriteLn('  /?        Affiche cette aide.');
 WriteLn;
 WriteLn('Langue : LANGUAGE=EN (anglais), LANGUAGE=GR (allemand),');
 WriteLn('         LANGUAGE=SP (espagnol), LANGUAGE=IT (italien), francais '+
   'par defaut.');
End;

{ ====================================================================== }
{          IMPORTATION DES FICHIERS .DFD DE SOLDERRUN (3.1 / 2.2.4)      }
{ ====================================================================== }

{ Le fichier .DFD est une base d'objets binaire : enregistrements d'entites,
  de magasins, de processus (numerotes .1, .1.2 ...) et de flux. Les noms,
  les numeros, la hierarchie et les liens des flux sont reconstitues ; les
  positions sont recalculees automatiquement (disposition en grille). }

Const
 IMAXE = 80;
 IMAXP = 120;
 IMAXF = 220;
 IMAXK = 300;
 IMAXG = 260;

Type
 TFBuf = Array[0..65000] Of Byte;
 PFBuf = ^TFBuf;
 TIObj = Record
  Kind: Byte;                 { 1 entite, 2 magasin, 3 table unique }
  Idx: Integer;
  Name: String[40];
  Id: Word;
  Has: Boolean;
  PX,PY,PW,PH: Integer;
 End;
 TIGfx = Record
  Hid: Word;
  X,Y,W,H: Integer;
 End;
 TIProc = Record
  Num: String[14];
  Diag: Word;
  Name: String[40];
  Depth: Integer;
  El,Child: Integer;
  Id: Word;
  Has: Boolean;
  PX,PY,PW,PH: Integer;
 End;
 TIFlow = Record
  Num: String[8];
  Name: String[30];
  NR: Integer;
  R: Array[1..6] Of Word;
 End;
 TIKey = Record
  Diag,Key,El: Integer;
 End;
 TImp = Record
  O: Array[1..IMAXE] Of TIObj;
  P: Array[1..IMAXP] Of TIProc;
  F: Array[1..IMAXF] Of TIFlow;
  K: Array[1..IMAXK] Of TIKey;
  G: Array[1..IMAXG] Of TIGfx;
  NO,NP,NF,NK,NG: Integer;
 End;
 PImp = ^TImp;

Var
 IB   : PFBuf;
 IBN  : LongInt;
 ITag : Word;
 ImPtrM   : PModel;
 ImPtrD   : PDict;
 ImCfgOut : TCfg;

Function U16(O: LongInt): Word;
Begin
 If (O<0) Or (O+1>=IBN) Then U16:=0 Else U16:=IB^[O]+IB^[O+1]*256;
End;

Function SInt(O: LongInt): LongInt;
Begin
 If (O<0) Or (O+3>=IBN) Then SInt:=0
 Else SInt:=LongInt(IB^[O])+LongInt(IB^[O+1])*256+LongInt(IB^[O+2])*65536
      +LongInt(Shortint(IB^[O+3]))*16777216;
End;

Function U32(O: LongInt): LongInt;
Begin
 If (O<0) Or (O+3>=IBN) Then U32:=0
 Else U32:=LongInt(IB^[O])+LongInt(IB^[O+1])*256+LongInt(IB^[O+2])*65536
      +LongInt(IB^[O+3] And $7F)*16777216;
End;

{ Latin-1 / Windows-1252 vers page de codes 437 }
Function L2D(C: Byte): Char;
Begin
 Case C Of
  $E9: L2D:=#130; $E8: L2D:=#138; $EA: L2D:=#136; $EB: L2D:=#137;
  $E0: L2D:=#133; $E2: L2D:=#131; $E4: L2D:=#132; $EE: L2D:=#140;
  $EF: L2D:=#139; $F4: L2D:=#147; $F6: L2D:=#148; $F9: L2D:=#151;
  $FB: L2D:=#150; $FC: L2D:=#129; $E7: L2D:=#135; $C9: L2D:=#144;
  $C4: L2D:=#142; $D6: L2D:=#153; $DC: L2D:=#154; $F1: L2D:=#164;
  $E1: L2D:=#160; $ED: L2D:=#161; $F3: L2D:=#162; $FA: L2D:=#163;
  $DF: L2D:=#225; $C0,$C1,$C2,$C3,$C5: L2D:='A'; $C8,$CA,$CB: L2D:='E';
  $CE,$CF: L2D:='I'; $D4: L2D:='O'; $D9,$DB: L2D:='U'; $C7: L2D:=#128;
  $92,$91: L2D:=#39;
  Else If C<128 Then L2D:=Chr(C) Else If C>=160 Then L2D:=Chr(C) Else L2D:=' ';
 End;
End;

{ lit une chaine a longueur 16 ou 32 bits terminee par 0 }
Function ReadStr(O: LongInt; Var S: String; Var Nx: LongInt): Boolean;
Var N: LongInt; F,I: Integer; C: Byte;
Begin
 ReadStr:=False;S:='';
 If (O<0) Or (O+6>=IBN) Then Exit;
 N:=U16(O);
 If (N>0) And (U16(O+2)=0) Then F:=4 Else F:=2;
 If (N<1) Or (N>80) Or (O+F+N>IBN) Then Exit;
 If IB^[O+F+N-1]<>0 Then Exit;
 For I:=0 To N-2 Do Begin
  C:=IB^[O+F+I];
  If C<32 Then Exit;
  S:=S+L2D(C);
 End;
 Nx:=O+F+N;
 ReadStr:=True;
End;

Function ReadNum(O: LongInt; Var S: String; Var Nx: LongInt): Boolean;
Var N: LongInt; F,I: Integer; C: Byte;
Begin
 ReadNum:=False;S:='';
 If (O<0) Or (O+8>=IBN) Then Exit;
 N:=U16(O);
 If (N>0) And (U16(O+2)=0) Then F:=4 Else F:=2;
 If (N<3) Or (N>14) Or (O+F+N>IBN) Then Exit;
 If (IB^[O+F]<>46) Or (IB^[O+F+N-1]<>0) Then Exit;
 For I:=0 To N-2 Do Begin
  C:=IB^[O+F+I];
  If Not (C In [46,48..57]) Then Exit;
  S:=S+Chr(C);
 End;
 Nx:=O+F+N;
 ReadNum:=True;
End;

Function PlausibleName(Const S: String): Boolean;
Var I,L: Integer;
Begin
 PlausibleName:=False;
 If (Length(S)<1) Then Exit;
 L:=0;
 For I:=1 To Length(S) Do If UpCase(S[I]) In ['A'..'Z'] Then Inc(L);
 PlausibleName:=L>0;
End;

Procedure ScanObjects(M: PImp);
Var I,J: LongInt; Sg,K: Byte; Idx: Word; Tg: Word; S: String; Nx: LongInt;
Begin
 I:=0;
 While I<IBN-40 Do Begin
  K:=0;
  If (IB^[I]=$A1) And (IB^[I+1]=$80) Then K:=1
  Else If (IB^[I]=$81) And (IB^[I+1]=$60) Then K:=2
  Else If (IB^[I]=$90) And (IB^[I+1]=$58) Then K:=3;
  If K>0 Then Begin
   J:=I+6;
   While J<I+34 Do Begin
    If (IB^[J]=0) And (IB^[J+1]=0) Then Begin
     Idx:=U16(J+2);Tg:=U16(J+4);
     If (Idx>=1) And (Idx<=300) And ((ITag=0) Or (Tg=ITag)) Then
      If ReadStr(J+6,S,Nx) And PlausibleName(S) Then Begin
       If ITag=0 Then ITag:=Tg;
       If M^.NO<IMAXE Then Begin
        Inc(M^.NO);
        M^.O[M^.NO].Kind:=K;M^.O[M^.NO].Idx:=Idx;M^.O[M^.NO].Name:=Copy(S,1,40);
        M^.O[M^.NO].Id:=U16(I+6);M^.O[M^.NO].Has:=False;
       End;
       I:=Nx-1;J:=I+100;
      End;
    End;
    Inc(J);
   End;
  End;
  Inc(I);
 End;
End;

{ identifiant logique de l'enregistrement dont la chaine numerotee est en O }
Function HdrId(O: LongInt): Word;
Var K,J: LongInt;
Begin
 HdrId:=0;
 K:=O-1;
 While (K>O-130) And Not ((IB^[K]=$80) And (IB^[K+1]=$21)) Do Dec(K);
 If (K>O-130) And (K>0) Then Begin HdrId:=U16(K+7);Exit;End;
 J:=O-1;
 While (J>O-130) And (IB^[J]=0) Do Dec(J);
 If (IB^[J]=$18) And (IB^[J-1]>=$C0) Then Begin
  K:=J-1;
  While (IB^[K+1]=$18) And (IB^[K]>=$C0) And (IB^[K]<=$C8) Do Dec(K,6);
  HdrId:=U16(K);
 End;
End;

{ enregistrements graphiques (rectangles des objets) }
Procedure ScanGfx(M: PImp);
Var I,K: LongInt; T: Byte; Hid: Word; Xmin,Xmax,Ymin,Ymax: LongInt;
Begin
 I:=60;
 While I<IBN-30 Do Begin
  If (IB^[I]=0) And (IB^[I+2]=0) And (U16(I+3)=ITag) And (IB^[I+7]=0) Then Begin
   T:=IB^[I+8];
   If (T=$18) And (M^.NG<IMAXG) Then Begin
    K:=I-27;
    If (IB^[K]=$FF) And (IB^[K+1]=$FF) And (IB^[K+5]=$FF) Then Hid:=U16(K-6)
    Else Begin
     K:=I-4;
     While (K>I-48) And Not ((IB^[K+1]=$18) And (IB^[K]>=$C1) And (IB^[K]<=$C8))
       Do Dec(K);
     Hid:=U16(K-6);
    End;
    Inc(M^.NG);
    M^.G[M^.NG].Hid:=Hid;
    Ymin:=SInt(I+9);Xmax:=SInt(I+13);Xmin:=SInt(I+17);Ymax:=SInt(I+21);
    M^.G[M^.NG].X:=Integer(((Xmin-2000)*100) Div 2646);
    M^.G[M^.NG].Y:=Integer(((-Ymax-2000)*100) Div 2646);
    M^.G[M^.NG].W:=Integer(((Xmax-Xmin)*100) Div 2646);
    M^.G[M^.NG].H:=Integer(((Ymax-Ymin)*100) Div 2646);
   End;
  End;
  Inc(I);
 End;
End;

Procedure AssignPos(M: PImp);
Var I,G: Integer;
Begin
 For I:=1 To M^.NO Do
  For G:=1 To M^.NG Do
   If M^.G[G].Hid=M^.O[I].Id+1 Then Begin
    M^.O[I].Has:=True;M^.O[I].PX:=M^.G[G].X;M^.O[I].PY:=M^.G[G].Y;
    M^.O[I].PW:=M^.G[G].W;M^.O[I].PH:=M^.G[G].H;
   End;
 For I:=1 To M^.NP Do
  For G:=1 To M^.NG Do
   If M^.G[G].Hid=M^.P[I].Id+1 Then Begin
    M^.P[I].Has:=True;M^.P[I].PX:=M^.G[G].X;M^.P[I].PY:=M^.G[G].Y;
    M^.P[I].PW:=M^.G[G].W;M^.P[I].PH:=M^.G[G].H;
   End;
End;

Procedure ScanProcesses(M: PImp);
Var O,P: LongInt; Num,Num2,Nm: String; Nx,Nx2: LongInt; Dg,Skip: Integer; Sk:
  Array[1..5] Of Integer;
    Ok: Boolean; K,Dp,I: Integer;
Begin
 Sk[1]:=2;Sk[2]:=4;Sk[3]:=0;Sk[4]:=6;Sk[5]:=8;
 O:=0;
 While O<IBN-30 Do Begin
  If ReadNum(O,Num,Nx) Then Begin
   P:=Nx+2;
   If ReadNum(P,Num2,Nx2) And (Num2=Num) Then Begin
    Dg:=U16(Nx2);
    If U16(Nx2+2)=ITag Then Begin
     P:=Nx2+4;
     Ok:=False;Nm:='';
     For K:=1 To 5 Do
      If Not Ok Then
       If ReadStr(P+Sk[K],Nm,Nx) And (Length(Nm)>0) Then Ok:=True;
     If Ok And (M^.NP<IMAXP) Then Begin
      Inc(M^.NP);
      M^.P[M^.NP].Num:=Num;M^.P[M^.NP].Diag:=Dg;M^.P[M^.NP].Name:=Copy(Nm,1,40);
      Dp:=0;
      For I:=1 To Length(Num) Do If Num[I]='.' Then Inc(Dp);
      M^.P[M^.NP].Depth:=Dp;M^.P[M^.NP].El:=0;M^.P[M^.NP].Child:=0;
      M^.P[M^.NP].Id:=HdrId(O);M^.P[M^.NP].Has:=False;
      O:=Nx-1;
     End;
    End;
   End;
  End;
  Inc(O);
 End;
End;

Procedure ScanFlows(M: PImp);
Const Pat: Array[0..11] Of Byte = (1,0,0,0,0,0,1,0,0,0,0,0);
Var I: LongInt; J: Integer; Hit: Boolean; Num,Nm: String; Nx,P: LongInt; NR:
  Integer; R: Array[1..6] Of Word;
    Ok: Boolean;
Begin
 I:=0;
 While I<IBN-60 Do Begin
  Hit:=True;
  For J:=0 To 11 Do If IB^[I+J]<>Pat[J] Then Hit:=False;
  If Hit Then Begin
   If ReadStr(I+12,Num,Nx) And (Length(Num)>0) And (Length(Num)<=8) And
     (Num[1]<>'.') Then Begin
    P:=Nx;NR:=0;
    While (U16(P)<>ITag) And (NR<6) Do Begin Inc(NR);R[NR]:=U16(P);Inc(P,2);End;
    If (U16(P)=ITag) And (NR>=1) And (M^.NF<IMAXF) Then Begin
     Inc(P,2);
     Nm:='';
     If U16(P)=$FFFF Then Inc(P,4)
     Else If (IB^[P+3] And $80)<>0 Then Inc(P,4);
     Ok:=ReadStr(P,Nm,Nx);
     If Not Ok Then Nm:='';
     Inc(M^.NF);
     M^.F[M^.NF].Num:=Num;M^.F[M^.NF].Name:=Copy(Nm,1,30);M^.F[M^.NF].NR:=NR;
     For J:=1 To NR Do M^.F[M^.NF].R[J]:=R[J];
     I:=Nx-1;
    End;
   End;
  End;
  Inc(I);
 End;
End;

Function ObjName(M: PImp; Kind,Idx: Integer; Var Real_: Integer): String;
Var I: Integer;
Begin
 ObjName:='';Real_:=0;
 For I:=1 To M^.NO Do
  If (M^.O[I].Kind=Kind) And (M^.O[I].Idx=Idx) Then Begin ObjName:=M^.O[I].Name;
    Real_:=I;Exit;End;
End;

Function IsStoreName(Const S: String): Boolean;
Var U: String; I: Integer;
Const W: Array[1..12] Of String[10] = ('JOURNAL','FICHIER','DOSSIER','CLASSEUR',
  'ARCHIVE','REGISTRE','LISTE','INVENTAIRE','RETENUE','EMPLOYE','STOCK',
  'COMPTE');
Begin
 U:=Upper(S);IsStoreName:=False;
 For I:=1 To 12 Do If Pos(W[I],U)>0 Then IsStoreName:=True;
End;

{ ---- construction du modele ---- }

Var
 ImM    : PImp;
 ImD0   : Integer;       { identifiant du diagramme de contexte }
 ImRoot : Integer;
 ImSB,ImEB : Integer;    { bases des identifiants magasins / entites }
 ImSingle  : Boolean;

Function ProcByNum(Const Num: String): Integer;
Var I: Integer;
Begin
 ProcByNum:=0;
 For I:=1 To ImM^.NP Do If ImM^.P[I].Num=Num Then Begin ProcByNum:=I;Exit;End;
End;

Function ChildDiagOf(K: Integer): Integer;
Var E,D: Integer;
Begin
 ChildDiagOf:=0;
 If (K<1) Or (K>ImM^.NP) Then Exit;
 If ImM^.P[K].Child>0 Then Begin ChildDiagOf:=ImM^.P[K].Child;Exit;End;
 E:=ImM^.P[K].El;
 If E=0 Then Exit;
 D:=NewDiag(Mdl^.El[E].Id,Mdl^.El[E].Name);
 If D=0 Then Exit;
 If Mdl^.El[E].Name='' Then Mdl^.Dg[D].Title:=Mdl^.El[E].Num;
 Mdl^.El[E].Child:=D;
 ImM^.P[K].Child:=D;
 ChildDiagOf:=D;
End;

Function DiagOfId(Id: Integer): Integer;
Begin
 If Id=ImD0 Then DiagOfId:=ImRoot
 Else If (Id>ImD0) And (Id<=ImD0+ImM^.NP) Then DiagOfId:=ChildDiagOf(Id-ImD0)
 Else DiagOfId:=0;
End;

Function KeyEl(D,Key: Integer): Integer;
Var I: Integer;
Begin
 KeyEl:=0;
 For I:=1 To ImM^.NK Do If (ImM^.K[I].Diag=D) And (ImM^.K[I].Key=Key) Then Begin
   KeyEl:=ImM^.K[I].El;Exit;End;
End;

Procedure AddKey(D,Key,E: Integer);
Begin
 If ImM^.NK<IMAXK Then Begin
  Inc(ImM^.NK);ImM^.K[ImM^.NK].Diag:=D;ImM^.K[ImM^.NK].Key:=Key;
    ImM^.K[ImM^.NK].El:=E;
 End;
End;

{ renvoie l'element (dans le diagramme D) qui represente l'identifiant logique
  Id ; 0 si inconnu }
Function ResolveEl(D,Id: Integer): Integer;
Var K,I,E,RI,Kd,Ix: Integer; Nm: String; Own: Integer;
Begin
 ResolveEl:=0;
 If Id>ImD0 Then Begin
  K:=Id-ImD0;
  If K>ImM^.NP Then Exit;
  E:=ImM^.P[K].El;
  If E=0 Then Exit;
  If Mdl^.El[E].Diag=D Then Begin ResolveEl:=E;Exit;End;
  I:=KeyEl(D,5000+K);
  If I=0 Then Begin
   I:=NewEl(ekEnt,D,0,0);
   If I=0 Then Exit;
   Mdl^.El[I].Name:=Copy(Mdl^.El[E].Num+' '+Mdl^.El[E].Name,1,40);
   Mdl^.El[I].Num:='';
   AddKey(D,5000+K,I);
  End;
  ResolveEl:=I;Exit;
 End;
 If Id=ImD0 Then Exit;
 { entite / magasin }
 Kd:=0;Ix:=0;
 If ImSingle Then Begin
  Ix:=Id-ImSB;
  Nm:=ObjName(ImM,3,Ix,RI);
  If RI>0 Then Begin If IsStoreName(Nm) Then Kd:=ekStore Else Kd:=ekEnt;End;
 End Else Begin
  Ix:=Id-ImSB;Nm:=ObjName(ImM,2,Ix,RI);
  If RI>0 Then Kd:=ekStore Else Begin
   Ix:=Id-ImEB;Nm:=ObjName(ImM,1,Ix,RI);
   If RI>0 Then Kd:=ekEnt;
  End;
 End;
 If Kd=0 Then Exit;
 I:=KeyEl(D,Kd*1000+Ix);
 If I=0 Then Begin
  I:=NewEl(Kd,D,0,0);
  If I=0 Then Exit;
  Mdl^.El[I].Name:=Nm;
  If Kd=ekStore Then Mdl^.El[I].Num:='S-'+IntStr(Ix) Else
    Mdl^.El[I].Num:='E-'+IntStr(Ix);
  If (D=ImRoot) And ImM^.O[RI].Has Then Begin
   Mdl^.El[I].X:=ImM^.O[RI].PX;Mdl^.El[I].Y:=ImM^.O[RI].PY;
   If ImM^.O[RI].PW>=40 Then Mdl^.El[I].W:=ImM^.O[RI].PW;
   If ImM^.O[RI].PH>=20 Then Mdl^.El[I].H:=ImM^.O[RI].PH;
   Mdl^.El[I].FS:=9;
  End;
  AddKey(D,Kd*1000+Ix,I);
 End;
 ResolveEl:=I;
 Own:=0;
End;

Procedure SolveBases;
Var Ends: Array[1..120] Of Word; Cn: Array[1..120] Of Integer; NE,I,J,F,SB,EB,
  Smax,X,RI: Integer;
    Sc,Best: LongInt; Dup: Boolean; S: String;
Begin
 NE:=0;
 For F:=1 To ImM^.NF Do
  If ImM^.F[F].NR>=3 Then
   For J:=1 To 2 Do Begin
    X:=ImM^.F[F].R[J];
    If (X<ImD0) And (X>0) Then Begin
     Dup:=False;
     For I:=1 To NE Do If Ends[I]=X Then Begin Dup:=True;Inc(Cn[I]);End;
     If Not Dup And (NE<120) Then Begin Inc(NE);Ends[NE]:=X;Cn[NE]:=1;End;
    End;
   End;
 Smax:=0;
 For I:=1 To ImM^.NO Do If (ImM^.O[I].Kind=2) And (ImM^.O[I].Idx>Smax) Then
   Smax:=ImM^.O[I].Idx;
 Best:=-1;ImSB:=0;ImEB:=0;
 If ImSingle Then Begin
  For SB:=0 To 400 Do Begin
   Sc:=0;
   For I:=1 To NE Do Begin S:=ObjName(ImM,3,Ends[I]-SB,RI);If RI>0 Then Inc(Sc,
     Cn[I]);End;
   If Sc*100>Best Then Begin Best:=Sc*100;ImSB:=SB;End;
  End;
 End Else Begin
  For SB:=0 To 400 Do
   For EB:=SB+Smax+13 To SB+Smax+26 Do Begin
    Sc:=0;
    For I:=1 To NE Do Begin
     S:=ObjName(ImM,2,Ends[I]-SB,RI);
     If RI>0 Then Inc(Sc,Cn[I]) Else Begin S:=ObjName(ImM,1,Ends[I]-EB,RI);If
       RI>0 Then Inc(Sc,Cn[I]);End;
    End;
    Sc:=Sc*100-Abs(EB-SB-Smax-13)*10;
    If Sc>Best Then Begin Best:=Sc;ImSB:=SB;ImEB:=EB;End;
   End;
 End;
End;

Function NumPart(Const S: String; K: Integer): LongInt;
Var I,C: Integer; V: LongInt;
Begin
 C:=0;V:=0;
 For I:=1 To Length(S) Do Begin
  If S[I]='.' Then Begin Inc(C);If C=K Then Begin NumPart:=V;Exit;End;V:=0;End
  Else If S[I] In ['0'..'9'] Then V:=V*10+Ord(S[I])-48;
 End;
 If C+1=K Then NumPart:=V Else NumPart:=-1;
End;

Function NumLess(Const A,B: String): Boolean;
Var K: Integer; X,Y: LongInt;
Begin
 For K:=1 To 8 Do Begin
  X:=NumPart(A,K);Y:=NumPart(B,K);
  If X<>Y Then Begin NumLess:=X<Y;Exit;End;
 End;
 NumLess:=False;
End;

Function Overlaps(D,Skip,X,Y,W,H: Integer): Boolean;
Var I: Integer;
Begin
 Overlaps:=False;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (I<>Skip) And
     (Mdl^.El[I].FS In [8,9]) And (Mdl^.El[I].Kind<>ekInfo) Then
   If (X<Mdl^.El[I].X+Mdl^.El[I].W+8) And (X+W+8>Mdl^.El[I].X) And
      (Y<Mdl^.El[I].Y+Mdl^.El[I].H+8) And (Y+H+8>Mdl^.El[I].Y) Then
        Overlaps:=True;
End;

Procedure PlaceFree(D,I,SX,SY,Step: Integer);
Var X,Y: Integer; Done: Boolean;
Begin
 Done:=False;
 Y:=SY;
 While (Y<2600) And Not Done Do Begin
  X:=SX;
  While (X<1400) And Not Done Do Begin
   If Not Overlaps(D,I,X,Y,Mdl^.El[I].W,Mdl^.El[I].H) Then Begin
    Mdl^.El[I].X:=X;Mdl^.El[I].Y:=Y;Mdl^.El[I].FS:=8;Done:=True;
   End;
   Inc(X,Step);
  End;
  Inc(Y,18);
 End;
 If Not Done Then Begin Mdl^.El[I].X:=SX;Mdl^.El[I].Y:=SY;Mdl^.El[I].FS:=8;End;
End;

Procedure LayoutImported(D: Integer);
Var I,J,K,NPr,Cols,MaxR,MaxB,Wd,Ht: Integer;
Begin
 { rang des processus non positionnes, par numero }
 NPr:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].Kind=ekProc)
     And (Mdl^.El[I].FS<>9) Then Inc(NPr);
 Cols:=3;If NPr>6 Then Cols:=4;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].Kind=ekProc)
     And (Mdl^.El[I].FS<>9) Then Begin
   K:=0;
   For J:=1 To MAXEL Do
    If Mdl^.El[J].Used And (Mdl^.El[J].Diag=D) And (Mdl^.El[J].Kind=ekProc)
       And (Mdl^.El[J].FS<>9) And (J<>I) Then
     If NumLess(Mdl^.El[J].Num,Mdl^.El[I].Num) Then Inc(K);
   Mdl^.El[I].Z:=K;
  End;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].Kind=ekProc)
     And (Mdl^.El[I].FS<>9) Then Begin
   K:=Mdl^.El[I].Z;
   Mdl^.El[I].X:=280+(K Mod Cols)*160;Mdl^.El[I].Y:=40+(K Div Cols)*150;
   Mdl^.El[I].FS:=8;
  End;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].FS=9) Then Begin
   If Mdl^.El[I].X<6 Then Mdl^.El[I].X:=6;
   If Mdl^.El[I].Y<30 Then Mdl^.El[I].Y:=30;
  End;
 { entites, objets externes et magasins non positionnes }
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].FS<>9)
     And (Mdl^.El[I].FS<>8) And (Mdl^.El[I].Kind In [ekEnt,ekText]) Then
   PlaceFree(D,I,14,40,24);
 MaxR:=0;MaxB:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].Kind<>ekInfo) Then
    Begin
   If Mdl^.El[I].X+Mdl^.El[I].W>MaxR Then MaxR:=Mdl^.El[I].X+Mdl^.El[I].W;
   If Mdl^.El[I].Y+Mdl^.El[I].H>MaxB Then MaxB:=Mdl^.El[I].Y+Mdl^.El[I].H;
  End;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].FS<>9)
     And (Mdl^.El[I].FS<>8) And (Mdl^.El[I].Kind=ekStore) Then
   PlaceFree(D,I,30,MaxB+20,24);
 MaxR:=0;MaxB:=0;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And (Mdl^.El[I].Kind<>ekInfo) Then
    Begin
   If Mdl^.El[I].X+Mdl^.El[I].W>MaxR Then MaxR:=Mdl^.El[I].X+Mdl^.El[I].W;
   If Mdl^.El[I].Y+Mdl^.El[I].H>MaxB Then MaxB:=Mdl^.El[I].Y+Mdl^.El[I].H;
  End;
 Wd:=MaxR+40;If Wd<720 Then Wd:=720;
 Ht:=MaxB+40;
 If Mdl^.Dg[D].Parent=0 Then Ht:=Ht+130;
 If Ht<480 Then Ht:=480;
 Mdl^.Dg[D].W:=Wd;Mdl^.Dg[D].H:=Ht;
 For I:=1 To MAXEL Do
  If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) Then Begin
   If Mdl^.El[I].Kind=ekInfo Then Begin
    Mdl^.El[I].X:=(Wd-Mdl^.El[I].W) Div 2;Mdl^.El[I].Y:=Ht-Mdl^.El[I].H-14;
   End;
   Mdl^.El[I].FS:=1;
  End;
End;

Function BuildFromImp(M: PImp; Const FN: String): Integer;
Var I,J,K,D,E,A,B,F,Dp,Par,Dgm,NSk,NOk: Integer; Num: String; PN: String; Pos2:
  Integer;
    SaveCfg: TCfg; SaveM: PModel; SaveD: PDict; NProcBad: Integer;
Begin
 BuildFromImp:=4;
 If M^.NP=0 Then Exit;
 ImM:=M;
 ImD0:=0;
 For I:=1 To M^.NP Do
  If M^.P[I].Depth=1 Then Begin
   If (ImD0=0) Or (M^.P[I].Diag<ImD0) Then ImD0:=M^.P[I].Diag;
  End;
 If ImD0=0 Then Exit;
 ImSingle:=False;
 For I:=1 To M^.NO Do If M^.O[I].Kind=3 Then ImSingle:=True;
 SolveBases;
 { remplace le modele global le temps de la construction }
 SaveM:=Mdl;SaveD:=Dict;SaveCfg:=Cfg;
 Mdl:=ImPtrM;Dict:=ImPtrD;
 FillChar(Mdl^,SizeOf(TModel),0);
 Mdl^.NextId:=1;Mdl^.NextZ:=1;
 DefaultDict;DefaultCfg;
 Cfg.MName:=ShortName(FN);
 If Pos('.',Cfg.MName)>0 Then Cfg.MName:=Copy(Cfg.MName,1,Pos('.',Cfg.MName)-1);
 Cfg.MName:=Copy(Cfg.MName,1,30);
 Cfg.ProjName:=Cfg.MName;
 M^.NK:=0;
 ImRoot:=NewDiag(0,T5('Contexte','Context','Kontext','Contexto','Contesto'));
 E:=NewEl(ekInfo,ImRoot,0,0);
 NOk:=0;NSk:=0;NProcBad:=0;
 { processus, du niveau le plus haut au plus bas }
 For Dp:=1 To 8 Do
  For I:=1 To M^.NP Do
   If M^.P[I].Depth=Dp Then Begin
    PN:=M^.P[I].Num;
    If Dp=1 Then Dgm:=ImRoot
    Else Begin
     Pos2:=Length(PN);
     While (Pos2>1) And (PN[Pos2]<>'.') Do Dec(Pos2);
     Par:=ProcByNum(Copy(PN,1,Pos2-1));
     If Par>0 Then Dgm:=ChildDiagOf(Par) Else Dgm:=0;
    End;
    If Dgm>0 Then Begin
     E:=NewEl(ekProc,Dgm,0,0);
     If E>0 Then Begin
      Mdl^.El[E].Num:=Copy(PN,2,20);
      Mdl^.El[E].Name:=M^.P[I].Name;
      M^.P[I].El:=E;
      If M^.P[I].Has Then Begin
       Mdl^.El[E].X:=M^.P[I].PX;Mdl^.El[E].Y:=M^.P[I].PY;
       If M^.P[I].PW>=40 Then Mdl^.El[E].W:=M^.P[I].PW;
       If M^.P[I].PH>=30 Then Mdl^.El[E].H:=M^.P[I].PH;
       Mdl^.El[E].FS:=9;
      End;
      Inc(NOk);
     End Else Inc(NProcBad);
    End;
   End;
 { flux }
 For F:=1 To M^.NF Do Begin
  J:=M^.F[F].NR;
  If J>=3 Then Begin
   D:=DiagOfId(M^.F[F].R[J]);
   If D>0 Then Begin
    A:=ResolveEl(D,M^.F[F].R[1]);
    B:=ResolveEl(D,M^.F[F].R[2]);
    If (A>0) And (B>0) And (A<>B) And FlowOK(Mdl^.El[A].Kind,Mdl^.El[B].Kind)
      Then Begin
     K:=NewFl(D,Mdl^.El[A].Id,Mdl^.El[B].Id);
     If K>0 Then Begin
      Mdl^.Fl[K].Name:=M^.F[F].Name;Mdl^.Fl[K].Num:=Copy(M^.F[F].Num,1,8);
      Inc(NOk);
     End Else Inc(NSk);
    End Else Inc(NSk);
   End Else Inc(NSk);
  End Else Inc(NSk);
 End;
 For D:=1 To MAXDG Do
  If Mdl^.Dg[D].Used Then Begin
   LayoutImported(D);
   K:=0;
   For I:=1 To MAXEL Do If Mdl^.El[I].Used And (Mdl^.El[I].Diag=D) And
     (Mdl^.El[I].Kind=ekProc) Then Inc(K);
   Mdl^.Dg[D].NP:=K+1;
  End;
 ImpStats:=IntStr(M^.NP)+' '+T5('processus','processes','Prozesse','procesos',
   'processi')+', '+
   IntStr(M^.NF)+' '+T5('flux','flows','Fl@3sse','flujos',
     'flussi')+' ('+IntStr(NSk)+' '+
   T5('non reli@es ignor@es','unlinked skipped','nicht verbunden',
     'sin enlace omitidos','non collegati ignorati')+')';
 ImpStats:=Dc(ImpStats);
 Cfg.Created:=TodayStr;Cfg.Modified:=Cfg.Created;
 ImCfgOut:=Cfg;
 Mdl:=SaveM;Dict:=SaveD;Cfg:=SaveCfg;
 BuildFromImp:=0;
End;

Function ImportDFD(Const FN: String; P: PModel; D: PDict; Var C: TCfg): Integer;
Var F: File; Rd: Word; Sz: LongInt; M: PImp; Res: Integer;
Begin
 ImportDFD:=4;
 {$I-}
 Assign(F,FN);Reset(F,1);
 {$I+}
 If IOResult<>0 Then Begin ImportDFD:=1;Exit;End;
 Sz:=FileSize(F);
 If Sz>64000 Then Begin Close(F);ImportDFD:=5;Exit;End;
 GetMem(IB,Sz+64);
 FillChar(IB^,Sz+64,0);
 {$I-}
 BlockRead(F,IB^,Sz,Rd);
 Close(F);
 {$I+}
 IBN:=Sz;
 If IOResult<>0 Then Begin FreeMem(IB,Sz+64);ImportDFD:=1;Exit;End;
 New(M);
 FillChar(M^,SizeOf(TImp),0);
 ITag:=0;
 ScanObjects(M);
 If ITag=0 Then Begin
  { pas d'entite ni de magasin : etiquette a partir d'un processus }
  ITag:=0;
 End;
 If ITag<>0 Then Begin
  ScanProcesses(M);
  ScanFlows(M);
  ScanGfx(M);
  AssignPos(M);
 End;
 ImPtrM:=P;ImPtrD:=D;
 If ITag=0 Then Res:=4 Else Res:=BuildFromImp(M,FN);
 If Res=0 Then C:=ImCfgOut;
 Dispose(M);
 FreeMem(IB,Sz+64);
 ImportDFD:=Res;
End;

{ ====================================================================== }
{                          PROGRAMME PRINCIPAL                           }
{ ====================================================================== }

BEGIN
 If (ParamCount>=1) And ((ParamStr(1)='/?') Or (ParamStr(1)='-h') Or
    (ParamStr(1)='--help')) Then Begin
  ShowHelpLine;
  Halt(0);
 End;
 CheckBreak:=False;
 DetectLanguage;
 AllocData;
 Quit:=False;Dirty:=True;
 ToolBarOn:=True;ToolBoxOn:=True;StatusOn:=True;
 TbX:=10;TbY:=100;CurTool:=tlSelect;StatMsg:='';
 MX:=0;MY:=0;MB:=0;LastB:=0;LastClickT:=0;LastClickX:=0;LastClickY:=0;
 MenuOpen:=0;MenuHi:=0;SubOpen:=0;SubHi:=0;
 NewDocument;
 BuildMenus;
 InitToolbar;
 InitBox;
 InitializeGraphics;
 If MouseDriverFound Then ShowMouse;
 If ParamCount>=1 Then LoadFile(ParamStr(1));
 MainLoop;
 CloseGraph;
END.
