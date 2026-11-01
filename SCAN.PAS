{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Free Pascal 3.2 - Windows (WIA) et Linux (SANE))
}

Program SCAN;

{ Utilitaire de numérisation en ligne de commande.

  - Sous Windows (directive conditionnelle WINDOWS), il utilise les API
    COM de WIA (Windows Image Acquisition) : IWiaDevMgr, IWiaItem,
    IWiaPropertyStorage et IWiaDataTransfer.
  - Sous Linux (directive conditionnelle LINUX), il appelle directement les
    API de SANE (sane_init, sane_open, sane_start, sane_read, ...) en
    chargeant libsane.so.1 avec dlopen : aucun fichier d'en-tête SANE
    n'est nécessaire pour compiler. Les images sont encodées par le
    programme lui-même (BMP, PNG, JPEG, TIFF et PNM).

  Seule l'unité DOS est utilisée et aucun fichier d'inclusion n'est requis. }

{$IFDEF WINDOWS}
 {$DEFINE SCAN_WIA}
{$ELSE}
 {$IFDEF LINUX}
  {$DEFINE SCAN_SANE}
 {$ENDIF}
{$ENDIF}

Uses DOS;

Const
  { Codes de retour }
 ExitUsage=1;
 ExitDevice=2;
 ExitScan=3;
 ExitFile=4;

  { Formats de fichier }
 fmtNone=0;
 fmtBMP=1;
 fmtPNG=2;
 fmtJPEG=3;
 fmtTIFF=4;
 fmtPNM=5;
 fmtGIF=6;

  { Modes de couleur }
 clrColor=1;
 clrGray=2;
 clrBW=3;

  { Sources de papier }
 srcAuto=0;
 srcFlatbed=1;
 srcFeeder=2;

 DefaultDPI=200;
 PreviewDPI=75;
 MaxDevices=32;
 MaxPages=999;

Type
 TDevInfo=Record
  Name:String;      { Nom affiché }
  Vendor:String;    { Fabricant }
  Descr:String;     { Description ou modèle }
  DevID:String;     { Identifiant utilisé pour ouvrir le périphérique }
 End;

 TByteArray=Array[0..$7FFFFFF]of Byte;
 PByteArray=^TByteArray;

Var
 OptList,OptPreview,OptUI,OptHelp:Boolean;
 OptDevice,OptOutput:String;
 OptDPI:LongInt;
 OptColor,OptSource,OptFormat,OutFormat:Byte;
 Devs:Array[0..MaxDevices-1]of TDevInfo;
 DevCount:LongInt;
 SelID,SelName:String;
 OutDir,OutBase,OutExt:String;
 OnFail:Procedure;    { Nettoyage à exécuter avant l'arrêt sur erreur }

{ ═══════════════════════════ Fonctions communes ═══════════════════════════ }

Function StrUpper(Const S:String):String;
Var
 I:LongInt;
 R:String;
Begin
 R:=S;
 For I:=1 to Length(R)Do If R[I]in['a'..'z']Then R[I]:=Chr(Ord(R[I])-32);
 StrUpper:=R;
End;

Function IntStr(N:LongInt):String;
Var
 S:String;
Begin
 Str(N,S);
 IntStr:=S;
End;

Function Pad3(N:LongInt):String;
Var
 S:String;
Begin
 S:=IntStr(N);
 While Length(S)<3 do S:='0'+S;
 Pad3:=S;
End;

Function HexLong(V:LongWord):String;
Const
 Digits:String[16]='0123456789ABCDEF';
Var
 I:LongInt;
 S:String;
Begin
 S:='';
 For I:=7 downto 0 do S:=S+Digits[((V shr (I*4))and $F)+1];
 HexLong:='0x'+S;
End;

Function Contains(Const S,Sub:String):Boolean;
Begin
 Contains:=Pos(StrUpper(Sub),StrUpper(S))>0;
End;

Function PCharToStr(P:PChar):String;
Var
 I:LongInt;
 S:String;
Begin
 S:='';
 I:=0;
 If P<>NIL Then While(P[I]<>#0)and(I<255)do Begin
  S:=S+P[I];
  Inc(I);
 End;
 PCharToStr:=S;
End;

Procedure Fail(Const Msg:String;Code:Byte);
Begin
 If OnFail<>NIL Then OnFail;
 WriteLn('Erreur : ',Msg);
 Halt(Code);
End;

Procedure Warn(Const Msg:String);
Begin
 WriteLn('Attention : ',Msg);
End;

Function FormatFromName(Const S:String):Byte;
Var
 U:String;
Begin
 U:=StrUpper(S);
 If(Length(U)>0)and(U[1]='.')Then Delete(U,1,1);
 FormatFromName:=fmtNone;
 If U='PNG' Then FormatFromName:=fmtPNG Else
 If U='BMP' Then FormatFromName:=fmtBMP Else
 If(U='JPG')or(U='JPEG')Then FormatFromName:=fmtJPEG Else
 If(U='TIF')or(U='TIFF')Then FormatFromName:=fmtTIFF Else
 If(U='PNM')or(U='PBM')or(U='PGM')or(U='PPM')Then FormatFromName:=fmtPNM Else
 If U='GIF' Then FormatFromName:=fmtGIF;
End;

Function FormatExt(F:Byte):String;
Begin
 Case F of
  fmtBMP:FormatExt:='.bmp';
  fmtJPEG:FormatExt:='.jpg';
  fmtTIFF:FormatExt:='.tif';
  fmtPNM:FormatExt:='.pnm';
  fmtGIF:FormatExt:='.gif';
  Else FormatExt:='.png';
 End;
End;

Procedure ShowHelp;
Begin
 WriteLn('SCAN : Cette commande permet de numeriser un document avec un scanner ',
         '(Windows : WIA, Linux : SANE).');
 WriteLn;
 WriteLn('Syntaxe : SCAN [options]');
 WriteLn;
 WriteLn(' /LIST             Afficher les scanners disponibles');
 WriteLn(' /DEVICE:n         Selectionner un scanner (numero affiche par /LIST)');
 WriteLn(' /PREVIEW          Previsualiser : numerisation rapide a basse resolution (',
                             PreviewDPI,' DPI)');
 WriteLn(' /DPI:n            Demander une resolution de n DPI (defaut : ',DefaultDPI,')');
 WriteLn(' /COLOR:mode       COLOR (couleur, defaut), GRAY (niveaux de gris) ou BW (noir et blanc)');
 WriteLn(' /SOURCE:source    FLATBED (vitre), FEEDER (chargeur automatique) ou AUTO (defaut)');
 WriteLn(' /FORMAT:format    PNG (defaut), BMP, JPG, TIFF, PNM (Linux) ou GIF (Windows)');
 WriteLn(' /OUTPUT:fichier   Nom du fichier de sortie (defaut : scan.png, ou preview.png)');
 WriteLn(' /UI               Afficher l''interface du pilote, si prise en charge');
 WriteLn;
 WriteLn('Sans /FORMAT, le format est deduit de l''extension du fichier de sortie. Avec le');
 WriteLn('chargeur automatique, chaque page est enregistree dans un fichier distinct :');
 WriteLn('document_001.png, document_002.png, ...');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn(' SCAN /LIST');
 WriteLn(' SCAN /DEVICE:0 /DPI:300 /COLOR:GRAY /FORMAT:PNG /OUTPUT:document.png');
 WriteLn(' SCAN /SOURCE:FEEDER /OUTPUT:livre.tif');
End;

  { Analyse la ligne de commande. Une option commence par / ou - (ou --) et sa
    valeur suit les caractères : ou = }
Procedure ParseCmdLine;
Var
 I,P,Code:LongInt;
 S,Key,Arg:String;
Begin
 OptList:=False;OptPreview:=False;OptUI:=False;OptHelp:=False;
 OptDevice:='0';OptOutput:='';OptDPI:=0;
 OptColor:=clrColor;OptSource:=srcAuto;OptFormat:=fmtNone;
 For I:=1 to ParamCount do Begin
  S:=ParamStr(I);
  If(Length(S)=0)or not(S[1]in['/','-'])Then Fail('parametre inattendu "'+S+'" (voir SCAN /?)',ExitUsage);
  While(Length(S)>0)and(S[1]in['/','-'])do Delete(S,1,1);
  P:=Pos(':',S);
  If(Pos('=',S)>0)and((P=0)or(Pos('=',S)<P))Then P:=Pos('=',S);
  If P>0 Then Begin
   Key:=StrUpper(Copy(S,1,P-1));
   Arg:=Copy(S,P+1,255);
  End
   Else
  Begin
   Key:=StrUpper(S);
   Arg:='';
  End;
  If(Key='?')or(Key='H')or(Key='HELP')Then OptHelp:=True Else
  If Key='LIST' Then OptList:=True Else
  If Key='PREVIEW' Then OptPreview:=True Else
  If Key='UI' Then OptUI:=True Else
  If Key='DEVICE' Then Begin
   If Arg='' Then Fail('/DEVICE demande une valeur (ex. /DEVICE:0)',ExitUsage);
   OptDevice:=Arg;
  End
   Else
  If Key='DPI' Then Begin
   Val(Arg,OptDPI,Code);
   If(Code<>0)or(OptDPI<10)or(OptDPI>9600)Then Fail('resolution invalide "'+Arg+'" (10 a 9600 DPI)',ExitUsage);
  End
   Else
  If Key='COLOR' Then Begin
   Arg:=StrUpper(Arg);
   If(Arg='COLOR')or(Arg='COLOUR')or(Arg='RGB')or(Arg='COULEUR')Then OptColor:=clrColor Else
   If(Arg='GRAY')or(Arg='GREY')or(Arg='GRIS')or(Arg='GRAYSCALE')Then OptColor:=clrGray Else
   If(Arg='BW')or(Arg='LINEART')or(Arg='MONO')or(Arg='BINARY')or(Arg='NB')Then OptColor:=clrBW
    Else Fail('mode de couleur inconnu "'+Arg+'" (COLOR, GRAY ou BW)',ExitUsage);
  End
   Else
  If Key='SOURCE' Then Begin
   Arg:=StrUpper(Arg);
   If(Arg='FEEDER')or(Arg='ADF')or(Arg='CHARGEUR')Then OptSource:=srcFeeder Else
   If(Arg='FLATBED')or(Arg='PLATEN')or(Arg='VITRE')Then OptSource:=srcFlatbed Else
   If(Arg='AUTO')or(Arg='')Then OptSource:=srcAuto
    Else Fail('source inconnue "'+Arg+'" (FLATBED, FEEDER ou AUTO)',ExitUsage);
  End
   Else
  If Key='FORMAT' Then Begin
   OptFormat:=FormatFromName(Arg);
   If OptFormat=fmtNone Then Fail('format inconnu "'+Arg+'" (PNG, BMP, JPG, TIFF, PNM ou GIF)',ExitUsage);
  End
   Else
  If Key='OUTPUT' Then Begin
   If Arg='' Then Fail('/OUTPUT demande un nom de fichier',ExitUsage);
   OptOutput:=Arg;
  End
   Else Fail('option inconnue "'+ParamStr(I)+'" (voir SCAN /?)',ExitUsage);
 End;
End;

  { Détermine le format et les noms de fichiers de sortie. }
Procedure ResolveOutput;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 If OptOutput='' Then Begin
  If OptPreview Then OptOutput:='preview' Else OptOutput:='scan';
 End;
 FSplit(OptOutput,D,N,E);
 If OptFormat<>fmtNone Then OutFormat:=OptFormat Else
 If E<>'' Then Begin
  OutFormat:=FormatFromName(E);
  If OutFormat=fmtNone Then Fail('extension "'+E+'" inconnue : precisez /FORMAT',ExitUsage);
 End
  Else
 OutFormat:=fmtPNG;
 If E='' Then Begin
  OptOutput:=OptOutput+FormatExt(OutFormat);
  FSplit(OptOutput,D,N,E);
 End;
 OutDir:=D;
 OutBase:=N;
 OutExt:=E;
End;

  { Nom du fichier pour la page numéro Page (chargeur : nom_001.ext). }
Function OutputName(Page:LongInt;Multi:Boolean):String;
Begin
 If Multi Then OutputName:=OutDir+OutBase+'_'+Pad3(Page)+OutExt
          Else OutputName:=OptOutput;
End;

Function WantedDPI:LongInt;
Begin
 If OptDPI>0 Then WantedDPI:=OptDPI Else
 If OptPreview Then WantedDPI:=PreviewDPI
               Else WantedDPI:=DefaultDPI;
End;

Function ColorLabel:String;
Begin
 Case OptColor of
  clrGray:ColorLabel:='niveaux de gris';
  clrBW:ColorLabel:='noir et blanc';
  Else ColorLabel:='couleur';
 End;
End;

Procedure ListDevices;
Var
 I:LongInt;
Begin
 If DevCount=0 Then Begin
  WriteLn('Aucun scanner disponible.');
  Exit;
 End;
 WriteLn('Scanners disponibles :');
 For I:=0 to DevCount-1 do Begin
  Write(' ',I:2,'  ',Devs[I].Name);
  If Devs[I].Descr<>'' Then Write(' - ',Devs[I].Descr);
  WriteLn;
  WriteLn('     ID : ',Devs[I].DevID);
 End;
End;

  { Choisit le périphérique d'après /DEVICE (numéro, ou partie du nom/ID). }
Function SelectDevice:Boolean;
Var
 I,N,Code:LongInt;
Begin
 SelectDevice:=False;
 Val(OptDevice,N,Code);
 If Code=0 Then Begin
  If(N<0)or(N>=DevCount)Then Begin
   If DevCount=0 Then Fail('aucun scanner detecte',ExitDevice)
    Else Fail('scanner numero '+OptDevice+' introuvable (voir SCAN /LIST)',ExitDevice);
  End;
  SelID:=Devs[N].DevID;
  SelName:=Devs[N].Name;
  SelectDevice:=True;
 End
  Else
 Begin
  For I:=0 to DevCount-1 do
   If Contains(Devs[I].DevID,OptDevice)or Contains(Devs[I].Name,OptDevice)Then Begin
    SelID:=Devs[I].DevID;
    SelName:=Devs[I].Name;
    SelectDevice:=True;
    Exit;
   End;
 End;
End;

{ ═══════════════════════════════ WINDOWS (WIA) ═════════════════════════════ }

{$IFDEF SCAN_WIA}

Const
 CLSCTX_LOCAL_SERVER=4;
 CP_ACP=0;
 CP_OEMCP=1;
 VT_I4=3;
 VT_BSTR=8;
 VT_UI4=19;
 VT_LPWSTR=31;
 VT_CLSID=72;
 PRSPEC_PROPID=1;
 TYMED_FILE=2;
 WIA_DEVINFO_ENUM_LOCAL=$10;
 WiaItemTypeImage=1;
 StiDeviceTypeScanner=1;

  { Propriétés WIA (WIA_xxx_FIRST + n, voir wiadef.h) }
 WIA_IPA_FIRST=4098;
 WIA_DIP_DEV_ID=2;
 WIA_DIP_VEND_DESC=3;
 WIA_DIP_DEV_DESC=4;
 WIA_DIP_DEV_TYPE=5;
 WIA_DIP_DEV_NAME=7;
 WIA_DPS_HORIZONTAL_BED_SIZE=3074;
 WIA_DPS_VERTICAL_BED_SIZE=3075;
 WIA_DPS_HORIZONTAL_SHEET_FEED_SIZE=3076;
 WIA_DPS_VERTICAL_SHEET_FEED_SIZE=3077;
 WIA_DPS_DOCUMENT_HANDLING_CAPABILITIES=3086;
 WIA_DPS_DOCUMENT_HANDLING_STATUS=3087;
 WIA_DPS_DOCUMENT_HANDLING_SELECT=3088;
 WIA_DPS_PAGES=3096;
 WIA_DPS_PREVIEW=3100;
 WIA_IPA_ITEM_NAME=4098;
 WIA_IPA_DATATYPE=4103;
 WIA_IPA_DEPTH=4104;
 WIA_IPA_FORMAT=4106;
 WIA_IPA_TYMED=4108;
 WIA_IPS_XRES=6147;
 WIA_IPS_YRES=6148;
 WIA_IPS_XPOS=6149;
 WIA_IPS_YPOS=6150;
 WIA_IPS_XEXTENT=6151;
 WIA_IPS_YEXTENT=6152;

  { Valeurs de propriétés }
 WIA_DATA_THRESHOLD=0;
 WIA_DATA_GRAYSCALE=2;
 WIA_DATA_COLOR=3;
 WIA_INTENT_IMAGE_TYPE_COLOR=1;
 WIA_INTENT_IMAGE_TYPE_GRAYSCALE=2;
 WIA_INTENT_IMAGE_TYPE_TEXT=4;
 DOC_FEEDER=$01;            { FEED : capacité / FEEDER : sélection }
 DOC_FLATBED=$02;
 FEED_READY=$01;
 WIA_FINAL_SCAN=0;
 WIA_PREVIEW_SCAN=1;
 WIA_ERROR_PAPER_EMPTY=LongInt($80210003);

Type
 TGuidRec=Record
  D1:LongWord;
  D2,D3:Word;
  D4:Array[0..7]of Byte;
 End;
 PGuidRec=^TGuidRec;

 TVTable=Array[0..63]of Pointer;
 PVTable=^TVTable;
 PObjHdr=^TObjHdr;
 TObjHdr=Record
  Vtbl:PVTable;
 End;

 TPropSpec=Record
  ulKind:LongWord;
  Case Byte of
   0:(propid:LongWord);
   1:(lpwstr:PWideChar);
 End;

 TPropVariant=Record
  vt:Word;
  wReserved1,wReserved2,wReserved3:Word;
  Case Byte of
   0:(lVal:LongInt);
   1:(pVal:Pointer;pVal2:Pointer);
 End;

 TStgMedium=Record
  tymed:LongWord;
  lpszFileName:PWideChar;
  pUnkForRelease:Pointer;
 End;

 TWBuf=Array[0..511]of WideChar;

Const
 CLSID_WiaDevMgr:TGuidRec=(D1:$A1F4E726;D2:$8CF1;D3:$11D1;
                           D4:($BF,$92,$00,$60,$08,$1E,$D8,$11));
 IID_IWiaDevMgr:TGuidRec=(D1:$5EB2502A;D2:$8CF1;D3:$11D1;
                          D4:($BF,$92,$00,$60,$08,$1E,$D8,$11));
 IID_IWiaPropertyStorage:TGuidRec=(D1:$98B5E8A0;D2:$29CC;D3:$491A;
                                   D4:($AA,$C0,$E6,$DB,$4F,$DC,$CE,$B6));
 IID_IWiaDataTransfer:TGuidRec=(D1:$A6CEF998;D2:$A5B0;D3:$11D2;
                                D4:($A0,$8F,$00,$C0,$4F,$72,$DC,$3C));
 WiaImgFmt_BMP:TGuidRec=(D1:$B96B3CAB;D2:$0728;D3:$11D3;
                         D4:($9D,$7B,$00,$00,$F8,$1E,$F3,$2E));
 WiaImgFmt_JPEG:TGuidRec=(D1:$B96B3CAE;D2:$0728;D3:$11D3;
                          D4:($9D,$7B,$00,$00,$F8,$1E,$F3,$2E));
 WiaImgFmt_PNG:TGuidRec=(D1:$B96B3CAF;D2:$0728;D3:$11D3;
                         D4:($9D,$7B,$00,$00,$F8,$1E,$F3,$2E));
 WiaImgFmt_GIF:TGuidRec=(D1:$B96B3CB0;D2:$0728;D3:$11D3;
                         D4:($9D,$7B,$00,$00,$F8,$1E,$F3,$2E));
 WiaImgFmt_TIFF:TGuidRec=(D1:$B96B3CB1;D2:$0728;D3:$11D3;
                          D4:($9D,$7B,$00,$00,$F8,$1E,$F3,$2E));

Function CoInitialize(Reserved:Pointer):LongInt;
 StdCall;External 'ole32.dll' name 'CoInitialize';
Procedure CoUninitialize;
 StdCall;External 'ole32.dll' name 'CoUninitialize';
Function CoCreateInstance(ClsID:PGuidRec;Outer:Pointer;ClsCtx:LongWord;IID:PGuidRec;
                          Var Obj:Pointer):LongInt;
 StdCall;External 'ole32.dll' name 'CoCreateInstance';
Function CoTaskMemAlloc(Size:PtrUInt):Pointer;
 StdCall;External 'ole32.dll' name 'CoTaskMemAlloc';
Procedure CoTaskMemFree(P:Pointer);
 StdCall;External 'ole32.dll' name 'CoTaskMemFree';
Function PropVariantClear(Var PV:TPropVariant):LongInt;
 StdCall;External 'ole32.dll' name 'PropVariantClear';
Function SysAllocString(S:PWideChar):Pointer;
 StdCall;External 'oleaut32.dll' name 'SysAllocString';
Procedure SysFreeString(S:Pointer);
 StdCall;External 'oleaut32.dll' name 'SysFreeString';
Function MultiByteToWideChar(CodePage,Flags:LongWord;MBStr:PChar;CBMultiByte:LongInt;
                             WideStr:PWideChar;CCHWide:LongInt):LongInt;
 StdCall;External 'kernel32.dll' name 'MultiByteToWideChar';
Function WideCharToMultiByte(CodePage,Flags:LongWord;WideStr:PWideChar;CCHWide:LongInt;
                             MBStr:PChar;CBMultiByte:LongInt;DefChar:PChar;
                             UsedDef:Pointer):LongInt;
 StdCall;External 'kernel32.dll' name 'WideCharToMultiByte';

Var
 Mgr:Pointer;          { IWiaDevMgr }
 ComReady:Boolean;

  { ── Appel des méthodes COM par la table de méthodes virtuelles ── }

Function VTEntry(Obj:Pointer;Index:LongInt):Pointer;
Begin
 VTEntry:=PObjHdr(Obj)^.Vtbl^[Index];
End;

Procedure ComRelease(Var Obj:Pointer);
Type
 TRelease=Function(This:Pointer):LongWord;StdCall;
Begin
 If Obj<>NIL Then Begin
  TRelease(VTEntry(Obj,2))(Obj);
  Obj:=NIL;
 End;
End;

Function ComQI(Obj:Pointer;IID:PGuidRec;Var Res:Pointer):LongInt;
Type
 TQI=Function(This:Pointer;RIID:PGuidRec;Var R:Pointer):LongInt;StdCall;
Begin
 Res:=NIL;
 ComQI:=TQI(VTEntry(Obj,0))(Obj,IID,Res);
End;

  { ── Conversion de chaînes ── }

Function WideToStr(W:PWideChar;CodePage:LongWord):String;
Var
 Buf:Array[0..511]of Char;
 N:LongInt;
Begin
 WideToStr:='';
 If W=NIL Then Exit;
 N:=WideCharToMultiByte(CodePage,0,W,-1,@Buf,SizeOf(Buf)-1,NIL,NIL);
 If N<=0 Then Exit;
 Buf[SizeOf(Buf)-1]:=#0;
 WideToStr:=PCharToStr(@Buf);
End;

Procedure StrToWide(Const S:String;Var W:TWBuf);
Var
 Z:Array[0..256]of Char;
 I:LongInt;
Begin
 For I:=1 to Length(S)do Z[I-1]:=S[I];
 Z[Length(S)]:=#0;
 If MultiByteToWideChar(CP_ACP,0,@Z,-1,@W,511)<=0 Then W[0]:=#0;
End;

Function StrToBStr(Const S:String):Pointer;
Var
 W:TWBuf;
Begin
 StrToWide(S,W);
 StrToBStr:=SysAllocString(@W);
End;

  { ── Propriétés WIA (IWiaPropertyStorage : ReadMultiple=3, WriteMultiple=4) ── }

Function PropReadVar(Stg:Pointer;PropID:LongWord;Var PV:TPropVariant):Boolean;
Type
 TReadMultiple=Function(This:Pointer;CPSpec:LongWord;Spec,Vars:Pointer):LongInt;StdCall;
Var
 Spec:TPropSpec;
Begin
 FillChar(PV,SizeOf(PV),0);
 Spec.ulKind:=PRSPEC_PROPID;
 Spec.propid:=PropID;
 PropReadVar:=(TReadMultiple(VTEntry(Stg,3))(Stg,1,@Spec,@PV)=0)and(PV.vt<>0);
End;

Function PropReadLong(Stg:Pointer;PropID:LongWord;Var Value:LongInt):Boolean;
Var
 PV:TPropVariant;
Begin
 PropReadLong:=False;
 If PropReadVar(Stg,PropID,PV)Then Begin
  If(PV.vt=VT_I4)or(PV.vt=VT_UI4)Then Begin
   Value:=PV.lVal;
   PropReadLong:=True;
  End;
  PropVariantClear(PV);
 End;
End;

Function PropReadStr(Stg:Pointer;PropID:LongWord):String;
Var
 PV:TPropVariant;
Begin
 PropReadStr:='';
 If PropReadVar(Stg,PropID,PV)Then Begin
  If(PV.vt=VT_BSTR)or(PV.vt=VT_LPWSTR)Then PropReadStr:=WideToStr(PV.pVal,CP_OEMCP);
  PropVariantClear(PV);
 End;
End;

Function PropWriteVar(Stg:Pointer;PropID:LongWord;Var PV:TPropVariant):Boolean;
Type
 TWriteMultiple=Function(This:Pointer;CPSpec:LongWord;Spec,Vars:Pointer;
                         NameFirst:LongWord):LongInt;StdCall;
Var
 Spec:TPropSpec;
Begin
 Spec.ulKind:=PRSPEC_PROPID;
 Spec.propid:=PropID;
 PropWriteVar:=TWriteMultiple(VTEntry(Stg,4))(Stg,1,@Spec,@PV,WIA_IPA_FIRST)=0;
End;

Function PropWriteLong(Stg:Pointer;PropID:LongWord;Value:LongInt):Boolean;
Var
 PV:TPropVariant;
Begin
 FillChar(PV,SizeOf(PV),0);
 PV.vt:=VT_I4;
 PV.lVal:=Value;
 PropWriteLong:=PropWriteVar(Stg,PropID,PV);
End;

Function PropWriteGuid(Stg:Pointer;PropID:LongWord;G:PGuidRec):Boolean;
Var
 PV:TPropVariant;
Begin
 FillChar(PV,SizeOf(PV),0);
 PV.vt:=VT_CLSID;
 PV.pVal:=G;
 PropWriteGuid:=PropWriteVar(Stg,PropID,PV);
End;

  { ── Initialisation de WIA ── }

Procedure WiaShutdown;
Begin
 ComRelease(Mgr);
 If ComReady Then Begin
  CoUninitialize;
  ComReady:=False;
 End;
End;

Procedure WiaInit;
Begin
 ComReady:=CoInitialize(NIL)>=0;
 Mgr:=NIL;
 If(not ComReady)or(CoCreateInstance(@CLSID_WiaDevMgr,NIL,CLSCTX_LOCAL_SERVER,
                                     @IID_IWiaDevMgr,Mgr)<0)or(Mgr=NIL)Then
  Fail('WIA est indisponible (service "Acquisition d''images Windows" arrete ?)',ExitDevice);
End;

  { Remplit Devs avec les scanners WIA (IWiaDevMgr.EnumDeviceInfo=3). }
Procedure EnumDevices;
Type
 TEnumDeviceInfo=Function(This:Pointer;Flag:LongInt;Var Enum:Pointer):LongInt;StdCall;
 TNext=Function(This:Pointer;Celt:LongWord;Var Stg:Pointer;Var Fetched:LongWord):LongInt;
        StdCall;
Var
 Enum,Stg:Pointer;
 Fetched:LongWord;
 DevType:LongInt;
Begin
 DevCount:=0;
 Enum:=NIL;
 If TEnumDeviceInfo(VTEntry(Mgr,3))(Mgr,WIA_DEVINFO_ENUM_LOCAL,Enum)<0 Then Exit;
 While DevCount<MaxDevices do Begin
  Stg:=NIL;
  Fetched:=0;
  If(TNext(VTEntry(Enum,3))(Enum,1,Stg,Fetched)<>0)or(Fetched=0)or(Stg=NIL)Then Break;
  If PropReadLong(Stg,WIA_DIP_DEV_TYPE,DevType)and((DevType and $FFFF)=StiDeviceTypeScanner)Then Begin
   Devs[DevCount].Name:=PropReadStr(Stg,WIA_DIP_DEV_NAME);
   Devs[DevCount].Vendor:=PropReadStr(Stg,WIA_DIP_VEND_DESC);
   Devs[DevCount].Descr:=PropReadStr(Stg,WIA_DIP_DEV_DESC);
   Devs[DevCount].DevID:=PropReadStr(Stg,WIA_DIP_DEV_ID);
   If Devs[DevCount].Name='' Then Devs[DevCount].Name:=Devs[DevCount].Descr;
   If(Devs[DevCount].Vendor<>'')and(Devs[DevCount].Descr=Devs[DevCount].Name)Then
    Devs[DevCount].Descr:=Devs[DevCount].Vendor
   Else
    If Devs[DevCount].Descr=Devs[DevCount].Name Then Devs[DevCount].Descr:='';
   Inc(DevCount);
  End;
  ComRelease(Stg);
 End;
 ComRelease(Enum);
End;

  { Ouvre le périphérique sélectionné (IWiaDevMgr.CreateDevice=4). }
Function OpenDevice:Pointer;
Type
 TCreateDevice=Function(This:Pointer;DevID:Pointer;Var Root:Pointer):LongInt;StdCall;
Var
 B,Root:Pointer;
 hr:LongInt;
Begin
 Root:=NIL;
 B:=StrToBStr(SelID);
 hr:=TCreateDevice(VTEntry(Mgr,4))(Mgr,B,Root);
 SysFreeString(B);
 If(hr<0)or(Root=NIL)Then
  Fail('impossible d''ouvrir le scanner "'+SelName+'" ('+HexLong(LongWord(hr))+')',ExitDevice);
 OpenDevice:=Root;
End;

Function FormatGuid(F:Byte):PGuidRec;
Begin
 Case F of
  fmtBMP:FormatGuid:=@WiaImgFmt_BMP;
  fmtJPEG:FormatGuid:=@WiaImgFmt_JPEG;
  fmtTIFF:FormatGuid:=@WiaImgFmt_TIFF;
  fmtGIF:FormatGuid:=@WiaImgFmt_GIF;
  Else FormatGuid:=@WiaImgFmt_PNG;
 End;
End;

  { Cherche l'élément image du scanner (vitre ou chargeur) parmi les enfants
    de l'élément racine (IWiaItem.EnumChildItems=5, GetItemType=3). }
Function FindScanItem(Root:Pointer;Feeder:Boolean):Pointer;
Type
 TEnumChildItems=Function(This:Pointer;Var Enum:Pointer):LongInt;StdCall;
 TNextItem=Function(This:Pointer;Celt:LongWord;Var Item:Pointer;Var Fetched:LongWord):LongInt;
            StdCall;
 TGetItemType=Function(This:Pointer;Var T:LongInt):LongInt;StdCall;
Var
 Enum,Item,Stg,First:Pointer;
 Fetched:LongWord;
 ItemType:LongInt;
 Name,Wanted:String;
 Count:LongInt;
Begin
 FindScanItem:=NIL;
 First:=NIL;
 Enum:=NIL;
 If Feeder Then Wanted:='FEEDER' Else Wanted:='FLATBED';
 If TEnumChildItems(VTEntry(Root,5))(Root,Enum)<0 Then Exit;
 Count:=0;
 While Count<32 do Begin
  Item:=NIL;
  Fetched:=0;
  If(TNextItem(VTEntry(Enum,3))(Enum,1,Item,Fetched)<>0)or(Fetched=0)or(Item=NIL)Then Break;
  Inc(Count);
  ItemType:=0;
  TGetItemType(VTEntry(Item,3))(Item,ItemType);
  If(ItemType and WiaItemTypeImage)=0 Then ComRelease(Item)
   Else
  Begin
   Name:='';
   If ComQI(Item,@IID_IWiaPropertyStorage,Stg)>=0 Then Begin
    Name:=PropReadStr(Stg,WIA_IPA_ITEM_NAME);
    ComRelease(Stg);
   End;
   If Contains(Name,Wanted)Then Begin
    ComRelease(First);
    FindScanItem:=Item;
    ComRelease(Enum);
    Exit;
   End;
   If First=NIL Then First:=Item Else ComRelease(Item);
  End;
 End;
 ComRelease(Enum);
 FindScanItem:=First;
End;

  { Transfère une image dans un fichier (IWiaDataTransfer.idtGetData=3). }
Function TransferToFile(Xfer:Pointer;Const FileName:String):LongInt;
Type
 TGetData=Function(This:Pointer;Var Med:TStgMedium;Callback:Pointer):LongInt;StdCall;
Var
 Med:TStgMedium;
 W:TWBuf;
 Full,Got:String;
 F:File;
 hr:LongInt;
Begin
 Full:=FExpand(FileName);
 StrToWide(Full,W);
 FillChar(Med,SizeOf(Med),0);
 Med.tymed:=TYMED_FILE;
 Med.lpszFileName:=CoTaskMemAlloc((Length(Full)+2)*SizeOf(WideChar));
 Move(W,Med.lpszFileName^,(Length(Full)+1)*SizeOf(WideChar));
 hr:=TGetData(VTEntry(Xfer,3))(Xfer,Med,NIL);
 If(hr>=0)and(Med.lpszFileName<>NIL)Then Begin
   { Certains pilotes choisissent eux-mêmes le nom du fichier }
  Got:=WideToStr(Med.lpszFileName,CP_ACP);
  If(Got<>'')and(StrUpper(Got)<>StrUpper(Full))Then Begin
   {$IOCHECKS OFF}
   Assign(F,Full);
   Erase(F);
   If IOResult<>0 Then;
   Assign(F,Got);
   Rename(F,Full);
   If IOResult<>0 Then Warn('le fichier a ete enregistre sous "'+Got+'"');
   {$IOCHECKS ON}
  End;
 End;
 If Med.lpszFileName<>NIL Then CoTaskMemFree(Med.lpszFileName);
 TransferToFile:=hr;
End;

  { /UI : boîte de dialogue du pilote (IWiaDevMgr.GetImageDlg=7). }
Procedure RunDriverUI;
Type
 TGetImageDlg=Function(This:Pointer;Parent:PtrUInt;DevType,Flags,Intent:LongInt;Root:Pointer;
                       FileName:Pointer;Fmt:PGuidRec):LongInt;StdCall;
Var
 Root,B:Pointer;
 Fmt:TGuidRec;
 Intent,hr:LongInt;
Begin
 Root:=OpenDevice;
 Case OptColor of
  clrGray:Intent:=WIA_INTENT_IMAGE_TYPE_GRAYSCALE;
  clrBW:Intent:=WIA_INTENT_IMAGE_TYPE_TEXT;
  Else Intent:=WIA_INTENT_IMAGE_TYPE_COLOR;
 End;
 Fmt:=FormatGuid(OutFormat)^;
 B:=StrToBStr(FExpand(OptOutput));
 WriteLn('Interface du pilote : ',SelName);
 hr:=TGetImageDlg(VTEntry(Mgr,7))(Mgr,0,StiDeviceTypeScanner,0,Intent,Root,B,@Fmt);
 SysFreeString(B);
 ComRelease(Root);
 If hr<0 Then Fail('l''interface du pilote a echoue ('+HexLong(LongWord(hr))+')',ExitScan);
 If hr=1 Then WriteLn('Numerisation annulee.')
         Else WriteLn('Image enregistree : ',OptOutput);
End;

Procedure RunScan;
Var
 Root,RootStg,Item,ItemStg,Xfer:Pointer;
 Caps,Status,BedW,BedH,DPI,Depth,DataType,Actual,Page,hr:LongInt;
 Feeder,Multi,Stop:Boolean;
 FileName:String;
Begin
 Root:=OpenDevice;
 If ComQI(Root,@IID_IWiaPropertyStorage,RootStg)<0 Then
  Fail('proprietes du scanner inaccessibles',ExitDevice);
 Feeder:=OptSource=srcFeeder;
 Multi:=Feeder;
 DPI:=WantedDPI;

  { Source de papier }
 If Feeder Then Begin
  If(not PropReadLong(RootStg,WIA_DPS_DOCUMENT_HANDLING_CAPABILITIES,Caps))or
    ((Caps and DOC_FEEDER)=0)Then
   Fail('le chargeur automatique n''est pas disponible sur ce scanner',ExitScan);
  PropWriteLong(RootStg,WIA_DPS_DOCUMENT_HANDLING_SELECT,DOC_FEEDER);
  PropWriteLong(RootStg,WIA_DPS_PAGES,0);
 End
  Else
 If OptSource=srcFlatbed Then PropWriteLong(RootStg,WIA_DPS_DOCUMENT_HANDLING_SELECT,DOC_FLATBED);
 If OptPreview Then PropWriteLong(RootStg,WIA_DPS_PREVIEW,WIA_PREVIEW_SCAN)
               Else PropWriteLong(RootStg,WIA_DPS_PREVIEW,WIA_FINAL_SCAN);

 Item:=FindScanItem(Root,Feeder);
 If Item=NIL Then Fail('aucun element de numerisation trouve sur ce scanner',ExitScan);
 If(ComQI(Item,@IID_IWiaPropertyStorage,ItemStg)<0)or
   (ComQI(Item,@IID_IWiaDataTransfer,Xfer)<0)Then
  Fail('le scanner ne permet pas le transfert de donnees',ExitScan);

  { Format, mode de couleur et résolution }
 If not PropWriteLong(ItemStg,WIA_IPA_TYMED,TYMED_FILE)Then
  Warn('le type de transfert fichier n''a pas ete accepte');
 If not PropWriteGuid(ItemStg,WIA_IPA_FORMAT,FormatGuid(OutFormat))Then
  Fail('le pilote n''accepte pas ce format de fichier (essayez /FORMAT:BMP)',ExitScan);
 Case OptColor of
  clrGray:Begin DataType:=WIA_DATA_GRAYSCALE;Depth:=8;End;
  clrBW:Begin DataType:=WIA_DATA_THRESHOLD;Depth:=1;End;
  Else Begin DataType:=WIA_DATA_COLOR;Depth:=24;End;
 End;
 If not PropWriteLong(ItemStg,WIA_IPA_DATATYPE,DataType)Then
  Warn('le mode "'+ColorLabel+'" n''est pas accepte par le scanner');
 PropWriteLong(ItemStg,WIA_IPA_DEPTH,Depth);
 If not(PropWriteLong(ItemStg,WIA_IPS_XRES,DPI)and PropWriteLong(ItemStg,WIA_IPS_YRES,DPI))Then
  Warn('la resolution de '+IntStr(DPI)+' DPI n''est pas acceptee par le scanner');
 If PropReadLong(ItemStg,WIA_IPS_XRES,Actual)Then DPI:=Actual;

  { Zone de numérisation : toute la surface utile }
 BedW:=0;
 BedH:=0;
 If Feeder Then Begin
  If not(PropReadLong(RootStg,WIA_DPS_HORIZONTAL_SHEET_FEED_SIZE,BedW)and
         PropReadLong(RootStg,WIA_DPS_VERTICAL_SHEET_FEED_SIZE,BedH))Then Begin
   BedW:=0;
   BedH:=0;
  End;
 End;
 If(BedW<=0)or(BedH<=0)Then
  If not(PropReadLong(RootStg,WIA_DPS_HORIZONTAL_BED_SIZE,BedW)and
         PropReadLong(RootStg,WIA_DPS_VERTICAL_BED_SIZE,BedH))Then Begin
   BedW:=0;
   BedH:=0;
  End;
 If(BedW>0)and(BedH>0)Then Begin
  PropWriteLong(ItemStg,WIA_IPS_XPOS,0);
  PropWriteLong(ItemStg,WIA_IPS_YPOS,0);
  PropWriteLong(ItemStg,WIA_IPS_XEXTENT,(BedW*DPI)div 1000);
  PropWriteLong(ItemStg,WIA_IPS_YEXTENT,(BedH*DPI)div 1000);
 End;

 WriteLn('Scanner    : ',SelName);
 WriteLn('Resolution : ',DPI,' DPI, ',ColorLabel);
 If OptPreview Then WriteLn('Apercu     : numerisation rapide a basse resolution');

  { Certains pilotes réinitialisent le format lorsque le mode ou la résolution
    change : on le redemande juste avant le transfert. }
 PropWriteLong(ItemStg,WIA_IPA_TYMED,TYMED_FILE);
 PropWriteGuid(ItemStg,WIA_IPA_FORMAT,FormatGuid(OutFormat));

  { Numérisation (une page, ou toutes les pages du chargeur) }
 Page:=0;
 Repeat
  If Feeder Then Begin
   If PropReadLong(RootStg,WIA_DPS_DOCUMENT_HANDLING_STATUS,Status)and((Status and FEED_READY)=0)Then Begin
    If Page=0 Then Fail('le chargeur automatique est vide',ExitScan);
    Break;
   End;
  End;
  FileName:=OutputName(Page+1,Multi);
  hr:=TransferToFile(Xfer,FileName);
  Stop:=not Feeder;
  If hr<0 Then Begin
   If(Page>0)and(hr=WIA_ERROR_PAPER_EMPTY)Then Break;
   If hr=WIA_ERROR_PAPER_EMPTY Then Fail('le chargeur automatique est vide',ExitScan);
   Fail('la numerisation a echoue ('+HexLong(LongWord(hr))+')',ExitScan);
  End;
  Inc(Page);
  WriteLn('Image enregistree : ',FileName);
  If hr>0 Then Stop:=True;       { WIA_STATUS_END_OF_MEDIA : dernière page }
 Until Stop or(Page>=MaxPages);
 If Multi Then WriteLn(Page,' page(s) numerisee(s).');

 ComRelease(Xfer);
 ComRelease(ItemStg);
 ComRelease(Item);
 ComRelease(RootStg);
 ComRelease(Root);
End;

Procedure BackendInit;
Begin
 OnFail:=@WiaShutdown;
 WiaInit;
End;

Procedure BackendDone;
Begin
 WiaShutdown;
End;

Procedure BackendRun;
Begin
 If OptUI Then RunDriverUI Else RunScan;
End;

Function DeviceByName:Boolean;
Begin
 DeviceByName:=False;
End;

{$ENDIF}

{ ═══════════════════════════════ LINUX (SANE) ══════════════════════════════ }

{$IFDEF SCAN_SANE}

Const
 RTLD_NOW=2;

 SANE_STATUS_GOOD=0;
 SANE_STATUS_CANCELLED=2;
 SANE_STATUS_EOF=5;
 SANE_STATUS_NO_DOCS=7;

 SANE_TYPE_BOOL=0;
 SANE_TYPE_INT=1;
 SANE_TYPE_FIXED=2;
 SANE_TYPE_STRING=3;
 SANE_TYPE_BUTTON=4;
 SANE_TYPE_GROUP=5;

 SANE_CONSTRAINT_NONE=0;
 SANE_CONSTRAINT_RANGE=1;
 SANE_CONSTRAINT_WORD_LIST=2;
 SANE_CONSTRAINT_STRING_LIST=3;

 SANE_ACTION_GET_VALUE=0;
 SANE_ACTION_SET_VALUE=1;

 SANE_FRAME_GRAY=0;
 SANE_FRAME_RGB=1;

 SANE_CAP_INACTIVE=32;

  { Format des lignes d'image mémorisées dans le fichier temporaire }
 rkBit=1;       { 1 bit par pixel, 1 = noir }
 rkGray=8;      { 8 bits par pixel }
 rkRGB=24;      { 8 bits par composante, ordre R,V,B }

 JpegQuality=90;

Type
 PSaneDevice=^TSaneDevice;
 TSaneDevice=Record
  Name,Vendor,Model,DevType:PChar;
 End;
 PSaneDeviceList=^TSaneDeviceList;
 TSaneDeviceList=Array[0..255]of PSaneDevice;

 TSaneRange=Record
  Min,Max,Quant:LongInt;
 End;
 PSaneRange=^TSaneRange;

 PSaneOptDesc=^TSaneOptDesc;
 TSaneOptDesc=Record
  Name,Title,Desc:PChar;
  ValueType,UnitType,Size,Cap,ConstraintType:LongInt;
  Constraint:Pointer;
 End;

 TSaneParams=Record
  Format,LastFrame,BytesPerLine,PixelsPerLine,Lines,Depth:LongInt;
 End;

 PLongInt=^LongInt;
 PPChar=^PChar;
 TPCharList=Array[0..255]of PChar;
 PPCharList=^TPCharList;
 TLongList=Array[0..65535]of LongInt;
 PLongList=^TLongList;

  { Fonctions de libsane (convention d'appel C) }
 TSaneInit=Function(Var Version:LongInt;Auth:Pointer):LongInt;CDecl;
 TSaneExit=Procedure;CDecl;
 TSaneGetDevices=Function(Var List:Pointer;LocalOnly:LongInt):LongInt;CDecl;
 TSaneOpen=Function(DevName:PChar;Var Handle:Pointer):LongInt;CDecl;
 TSaneClose=Procedure(Handle:Pointer);CDecl;
 TSaneGetOptDesc=Function(Handle:Pointer;Option:LongInt):PSaneOptDesc;CDecl;
 TSaneControl=Function(Handle:Pointer;Option,Action:LongInt;Value:Pointer;
                       Info:PLongInt):LongInt;CDecl;
 TSaneGetParams=Function(Handle:Pointer;Var Params:TSaneParams):LongInt;CDecl;
 TSaneStart=Function(Handle:Pointer):LongInt;CDecl;
 TSaneRead=Function(Handle:Pointer;Buf:Pointer;MaxLen:LongInt;Var Len:LongInt):LongInt;CDecl;
 TSaneCancel=Procedure(Handle:Pointer);CDecl;
 TSaneStrStatus=Function(Status:LongInt):PChar;CDecl;

  { libdl est requise avec les glibc antérieures à 2.34 }
{$LINKLIB dl}
Function dlopen(FileName:PChar;Flags:LongInt):Pointer;CDecl;External 'c' name 'dlopen';
Function dlsym(Handle:Pointer;Symbol:PChar):Pointer;CDecl;External 'c' name 'dlsym';
Function dlclose(Handle:Pointer):LongInt;CDecl;External 'c' name 'dlclose';

Var
 SaneLib:Pointer;
 Sane_Init:TSaneInit;
 Sane_Exit:TSaneExit;
 Sane_GetDevices:TSaneGetDevices;
 Sane_Open:TSaneOpen;
 Sane_Close:TSaneClose;
 Sane_GetOptDesc:TSaneGetOptDesc;
 Sane_Control:TSaneControl;
 Sane_GetParams:TSaneGetParams;
 Sane_Start:TSaneStart;
 Sane_Read:TSaneRead;
 Sane_Cancel:TSaneCancel;
 Sane_StrStatus:TSaneStrStatus;

 SaneReady:Boolean;
 Handle:Pointer;           { Périphérique SANE ouvert }
 OptCount:LongInt;
 ScanActive:Boolean;

  { Image numérisée (fichier temporaire de lignes normalisées) }
 Tmp,Dest:File;
 TmpName:String;
 TmpOpen,DestOpen:Boolean;
 ImgW,ImgH,ImgDPI,RowBytes:LongInt;
 ImgKind:Byte;

 Hdr:Array[0..2047]of Byte;
 HdrLen:LongInt;
 CRCTable:Array[0..255]of LongWord;

{ ── Chargement et utilitaires SANE ── }

Function LoadSane:Boolean;
  Function Sym(Const N:String):Pointer;
  Var
   Z:Array[0..63]of Char;
   I:LongInt;
  Begin
   For I:=1 to Length(N)do Z[I-1]:=N[I];
   Z[Length(N)]:=#0;
   Sym:=dlsym(SaneLib,@Z);
  End;
Begin
 LoadSane:=False;
 SaneLib:=dlopen('libsane.so.1',RTLD_NOW);
 If SaneLib=NIL Then SaneLib:=dlopen('libsane.so',RTLD_NOW);
 If SaneLib=NIL Then Exit;
 Sane_Init:=TSaneInit(Sym('sane_init'));
 Sane_Exit:=TSaneExit(Sym('sane_exit'));
 Sane_GetDevices:=TSaneGetDevices(Sym('sane_get_devices'));
 Sane_Open:=TSaneOpen(Sym('sane_open'));
 Sane_Close:=TSaneClose(Sym('sane_close'));
 Sane_GetOptDesc:=TSaneGetOptDesc(Sym('sane_get_option_descriptor'));
 Sane_Control:=TSaneControl(Sym('sane_control_option'));
 Sane_GetParams:=TSaneGetParams(Sym('sane_get_parameters'));
 Sane_Start:=TSaneStart(Sym('sane_start'));
 Sane_Read:=TSaneRead(Sym('sane_read'));
 Sane_Cancel:=TSaneCancel(Sym('sane_cancel'));
 Sane_StrStatus:=TSaneStrStatus(Sym('sane_strstatus'));
 LoadSane:=(@Sane_Init<>NIL)and(@Sane_Exit<>NIL)and(@Sane_GetDevices<>NIL)and
           (@Sane_Open<>NIL)and(@Sane_Close<>NIL)and(@Sane_GetOptDesc<>NIL)and
           (@Sane_Control<>NIL)and(@Sane_GetParams<>NIL)and(@Sane_Start<>NIL)and
           (@Sane_Read<>NIL)and(@Sane_Cancel<>NIL)and(@Sane_StrStatus<>NIL);
End;

Function SaneMsg(Status:LongInt):String;
Begin
 If @Sane_StrStatus<>NIL Then SaneMsg:=PCharToStr(Sane_StrStatus(Status))
                         Else SaneMsg:='code '+IntStr(Status);
End;

Procedure CloseTemp;
Begin
 If TmpOpen Then Begin
  {$IOCHECKS OFF}
  Close(Tmp);
  Erase(Tmp);
  If IOResult<>0 Then;
  {$IOCHECKS ON}
  TmpOpen:=False;
 End;
End;

Procedure CloseDest(Remove:Boolean);
Begin
 If DestOpen Then Begin
  {$IOCHECKS OFF}
  Close(Dest);
  If Remove Then Erase(Dest);
  If IOResult<>0 Then;
  {$IOCHECKS ON}
  DestOpen:=False;
 End;
End;

Procedure SaneShutdown;
Begin
 CloseTemp;
 CloseDest(True);
 If ScanActive Then Begin
  Sane_Cancel(Handle);
  ScanActive:=False;
 End;
 If Handle<>NIL Then Begin
  Sane_Close(Handle);
  Handle:=NIL;
 End;
 If SaneReady Then Begin
  Sane_Exit;
  SaneReady:=False;
 End;
End;

{ ── Options des pilotes ── }

Function SaneFindOption(Const Name:String):LongInt;
Var
 I:LongInt;
 D:PSaneOptDesc;
Begin
 SaneFindOption:=-1;
 For I:=1 to OptCount-1 do Begin
  D:=Sane_GetOptDesc(Handle,I);
  If(D<>NIL)and(D^.Name<>NIL)and(PCharToStr(D^.Name)=Name)Then Begin
   If(D^.Cap and SANE_CAP_INACTIVE)=0 Then SaneFindOption:=I;
   Exit;
  End;
 End;
End;

  { Fixe une option numérique (valeur brute : entier, ou point fixe 16.16). }
Function SaneSetRaw(Idx,Raw:LongInt):Boolean;
Var
 V,Info:LongInt;
Begin
 V:=Raw;
 Info:=0;
 SaneSetRaw:=Sane_Control(Handle,Idx,SANE_ACTION_SET_VALUE,@V,@Info)=SANE_STATUS_GOOD;
End;

Function SaneGetRaw(Idx:LongInt;Var Raw:LongInt):Boolean;
Begin
 Raw:=0;
 SaneGetRaw:=Sane_Control(Handle,Idx,SANE_ACTION_GET_VALUE,@Raw,NIL)=SANE_STATUS_GOOD;
End;

  { Convertit une valeur utilisateur (DPI ou mm) en valeur brute de l'option
    en la ramenant dans les valeurs permises par le pilote. }
Function SaneFitRaw(Idx,Value:LongInt):LongInt;
Var
 D:PSaneOptDesc;
 Raw,Best,I,N:LongInt;
 Scale:LongInt;
 R:PSaneRange;
 L:PLongList;
Begin
 D:=Sane_GetOptDesc(Handle,Idx);
 If D^.ValueType=SANE_TYPE_FIXED Then Scale:=65536 Else Scale:=1;
 Raw:=Value*Scale;
 If D^.ConstraintType=SANE_CONSTRAINT_RANGE Then Begin
  R:=PSaneRange(D^.Constraint);
  If Raw<R^.Min Then Raw:=R^.Min;
  If Raw>R^.Max Then Raw:=R^.Max;
  If R^.Quant>0 Then Raw:=R^.Min+((Raw-R^.Min+R^.Quant div 2)div R^.Quant)*R^.Quant;
  If Raw>R^.Max Then Raw:=R^.Max;
 End
  Else
 If D^.ConstraintType=SANE_CONSTRAINT_WORD_LIST Then Begin
  L:=PLongList(D^.Constraint);
  N:=L^[0];
  Best:=L^[1];
  For I:=1 to N do
   If Abs(L^[I]-Raw)<Abs(Best-Raw)Then Best:=L^[I];
  Raw:=Best;
 End;
 SaneFitRaw:=Raw;
End;

Function SaneRangeLimit(Idx:LongInt;WantMax:Boolean;Var Raw:LongInt):Boolean;
Var
 D:PSaneOptDesc;
 R:PSaneRange;
Begin
 SaneRangeLimit:=False;
 D:=Sane_GetOptDesc(Handle,Idx);
 If(D<>NIL)and(D^.ConstraintType=SANE_CONSTRAINT_RANGE)Then Begin
  R:=PSaneRange(D^.Constraint);
  If WantMax Then Raw:=R^.Max Else Raw:=R^.Min;
  SaneRangeLimit:=True;
 End;
End;

Function RawToUnits(Idx,Raw:LongInt):LongInt;
Var
 D:PSaneOptDesc;
Begin
 D:=Sane_GetOptDesc(Handle,Idx);
 If(D<>NIL)and(D^.ValueType=SANE_TYPE_FIXED)Then RawToUnits:=(Raw+32768)div 65536
                                           Else RawToUnits:=Raw;
End;

  { Fixe une option de type chaîne. }
Function SaneSetString(Idx:LongInt;Const S:String):Boolean;
Var
 D:PSaneOptDesc;
 P:PChar;
 Info,I,Sz:LongInt;
Begin
 D:=Sane_GetOptDesc(Handle,Idx);
 Sz:=D^.Size;
 If Sz<Length(S)+1 Then Sz:=Length(S)+1;
 GetMem(P,Sz);
 FillChar(P^,Sz,0);
 For I:=1 to Length(S)do P[I-1]:=S[I];
 Info:=0;
 SaneSetString:=Sane_Control(Handle,Idx,SANE_ACTION_SET_VALUE,P,@Info)=SANE_STATUS_GOOD;
 FreeMem(P,Sz);
End;

  { Choix de la valeur d'une option de type liste de chaînes selon le mode
    de couleur ou la source demandés. Tour 1 : critères stricts, tour 2 :
    critères souples. }
Function Matches(Const Cand:String;Kind:Byte;Strict:Boolean):Boolean;
Begin
 Matches:=False;
 Case Kind of
  100+clrColor:Begin
   If Contains(Cand,'COLOR')or Contains(Cand,'COLOUR')or Contains(Cand,'RGB')Then
    Matches:=(not Strict)or not(Contains(Cand,'LINEART')or Contains(Cand,'HALFTONE')or
                                Contains(Cand,'BINARY')or Contains(Cand,'GRAY')or
                                Contains(Cand,'GREY'));
  End;
  100+clrGray:Begin
   If Contains(Cand,'GRAY')or Contains(Cand,'GREY')Then
    Matches:=(not Strict)or not Contains(Cand,'COLOR');
  End;
  100+clrBW:Begin
   If Contains(Cand,'LINEART')or Contains(Cand,'LINE ART')or Contains(Cand,'BINARY')or
      Contains(Cand,'MONO')or Contains(Cand,'BLACK')or Contains(Cand,'B&W')Then Matches:=True
   Else
    If(not Strict)and Contains(Cand,'HALFTONE')Then Matches:=True;
  End;
  200+srcFeeder:Begin
   If Contains(Cand,'ADF')or Contains(Cand,'FEEDER')or Contains(Cand,'DOCUMENT')Then
    Matches:=(not Strict)or not(Contains(Cand,'DUPLEX')or Contains(Cand,'BACK'));
  End;
  200+srcFlatbed:Begin
   Matches:=Contains(Cand,'FLATBED')or Contains(Cand,'PLATEN')or Contains(Cand,'GLASS')or
            Contains(Cand,'NORMAL')or Contains(Cand,'FLAT');
  End;
 End;
End;

Function SaneChooseString(Idx:LongInt;Kind:Byte;Var Chosen:String):Boolean;
Var
 D:PSaneOptDesc;
 L:PPCharList;
 I,Pass:LongInt;
Begin
 SaneChooseString:=False;
 D:=Sane_GetOptDesc(Handle,Idx);
 If(D=NIL)or(D^.ValueType<>SANE_TYPE_STRING)or(D^.ConstraintType<>SANE_CONSTRAINT_STRING_LIST)Then Exit;
 L:=PPCharList(D^.Constraint);
 For Pass:=1 to 2 do Begin
  I:=0;
  While(I<255)and(L^[I]<>NIL)do Begin
   If Matches(PCharToStr(L^[I]),Kind,Pass=1)Then Begin
    Chosen:=PCharToStr(L^[I]);
    If SaneSetString(Idx,Chosen)Then Begin
     SaneChooseString:=True;
     Exit;
    End;
   End;
   Inc(I);
  End;
 End;
End;

{ ── Ouverture et énumération ── }

Procedure SaneInitLib;
Var
 Version,St:LongInt;
Begin
 If not LoadSane Then
  Fail('la bibliotheque SANE (libsane.so.1) est introuvable : installez le paquet libsane',ExitDevice);
 St:=Sane_Init(Version,NIL);
 If St<>SANE_STATUS_GOOD Then Fail('sane_init a echoue : '+SaneMsg(St),ExitDevice);
 SaneReady:=True;
End;

Procedure EnumDevices;
Var
 List:Pointer;
 L:PSaneDeviceList;
 St,I:LongInt;
Begin
 DevCount:=0;
 List:=NIL;
 St:=Sane_GetDevices(List,0);
 If St<>SANE_STATUS_GOOD Then Fail('sane_get_devices a echoue : '+SaneMsg(St),ExitDevice);
 L:=PSaneDeviceList(List);
 If L=NIL Then Exit;
 I:=0;
 While(I<255)and(L^[I]<>NIL)and(DevCount<MaxDevices)do Begin
  Devs[DevCount].DevID:=PCharToStr(L^[I]^.Name);
  Devs[DevCount].Vendor:=PCharToStr(L^[I]^.Vendor);
  Devs[DevCount].Name:=Devs[DevCount].Vendor+' '+PCharToStr(L^[I]^.Model);
  Devs[DevCount].Descr:=PCharToStr(L^[I]^.DevType);
  Inc(DevCount);
  Inc(I);
 End;
End;

Procedure SaneOpenDevice;
Var
 St:LongInt;
 Z:Array[0..255]of Char;
 I:LongInt;
Begin
 For I:=1 to Length(SelID)do Z[I-1]:=SelID[I];
 Z[Length(SelID)]:=#0;
 Handle:=NIL;
 St:=Sane_Open(@Z,Handle);
 If St<>SANE_STATUS_GOOD Then Begin
  Handle:=NIL;
  Fail('impossible d''ouvrir "'+SelID+'" : '+SaneMsg(St),ExitDevice);
 End;
 OptCount:=0;
 Sane_Control(Handle,0,SANE_ACTION_GET_VALUE,@OptCount,NIL);
End;

{ /UI : SANE n'offre pas de boîte de dialogue ; on affiche les options du pilote. }
Procedure ShowDriverOptions;
Var
 I,J,Raw:LongInt;
 D:PSaneOptDesc;
 L:PPCharList;
 Buf:PChar;
 S:String;
Begin
 WriteLn('Options du pilote : ',SelName,' (',SelID,')');
 For I:=1 to OptCount-1 do Begin
  D:=Sane_GetOptDesc(Handle,I);
  If D=NIL Then Continue;
  If D^.ValueType=SANE_TYPE_GROUP Then Begin
   WriteLn;
   WriteLn(' [',PCharToStr(D^.Title),']');
   Continue;
  End;
  If D^.Name=NIL Then Continue;
  Write('   ',PCharToStr(D^.Name));
  If(D^.Cap and SANE_CAP_INACTIVE)<>0 Then Write(' (inactif)')
   Else
  Case D^.ValueType of
   SANE_TYPE_BOOL:If SaneGetRaw(I,Raw)Then Write(' = ',Raw<>0);
   SANE_TYPE_INT:If SaneGetRaw(I,Raw)Then Write(' = ',Raw);
   SANE_TYPE_FIXED:If SaneGetRaw(I,Raw)Then Write(' = ',RawToUnits(I,Raw));
   SANE_TYPE_STRING:Begin
    GetMem(Buf,D^.Size+1);
    FillChar(Buf^,D^.Size+1,0);
    If Sane_Control(Handle,I,SANE_ACTION_GET_VALUE,Buf,NIL)=SANE_STATUS_GOOD Then
     Write(' = ',PCharToStr(Buf));
    FreeMem(Buf,D^.Size+1);
   End;
  End;
  If(D^.Cap and SANE_CAP_INACTIVE)=0 Then Begin
   If D^.ConstraintType=SANE_CONSTRAINT_RANGE Then
    Write('  [',RawToUnits(I,PSaneRange(D^.Constraint)^.Min),'..',
                RawToUnits(I,PSaneRange(D^.Constraint)^.Max),']')
   Else
   If D^.ConstraintType=SANE_CONSTRAINT_STRING_LIST Then Begin
    L:=PPCharList(D^.Constraint);
    S:='';
    J:=0;
    While(J<255)and(L^[J]<>NIL)do Begin
     If S<>'' Then S:=S+'|';
     S:=S+PCharToStr(L^[J]);
     Inc(J);
    End;
    Write('  [',S,']');
   End;
  End;
  WriteLn;
  If(D^.Desc<>NIL)and(D^.Desc^<>#0)Then WriteLn('       ',PCharToStr(D^.Desc));
 End;
 WriteLn;
 WriteLn('SANE n''offre pas de boite de dialogue : utilisez /DPI, /COLOR, /SOURCE et /PREVIEW.');
End;

{ ── Encodage des images (lues dans le fichier temporaire) ── }

Procedure DestWrite(Const Buf;Len:LongInt);
Var
 Written:LongInt;
Begin
 If Len<=0 Then Exit;
 BlockWrite(Dest,Buf,Len,Written);
 If Written<>Len Then Fail('erreur d''ecriture du fichier '+OptOutput,ExitFile);
End;

Procedure HB(V:LongWord);
Begin
 Hdr[HdrLen]:=Byte(V and $FF);
 Inc(HdrLen);
End;

Procedure HW(V:LongWord);
Begin
 HB(V);
 HB(V shr 8);
End;

Procedure HD(V:LongWord);
Begin
 HW(V and $FFFF);
 HW(V shr 16);
End;

Procedure HBE(V:LongWord);
Begin
 HB(V shr 24);
 HB(V shr 16);
 HB(V shr 8);
 HB(V);
End;

Procedure HBW(V:LongWord);
Begin
 HB(V shr 8);
 HB(V);
End;

Procedure HStr(Const S:String);
Var
 I:LongInt;
Begin
 For I:=1 to Length(S)do HB(Ord(S[I]));
End;

Procedure HFlush;
Begin
 DestWrite(Hdr,HdrLen);
 HdrLen:=0;
End;

  { Lit la ligne Y du fichier temporaire. }
Procedure ReadRow(Y:LongInt;Row:PByteArray);
Var
 Got:LongInt;
Begin
 Seek(Tmp,Int64(Y)*RowBytes);
 BlockRead(Tmp,Row^,RowBytes,Got);
 If Got<>RowBytes Then Fail('lecture du fichier temporaire impossible',ExitFile);
End;

Function PixelsPerMeter(DPI:LongInt):LongInt;
Begin
 PixelsPerMeter:=(DPI*10000+127)div 254;
End;

Procedure WriteBMP;
Var
 Bits,Stride,PalSize,OffBits,X,Y:LongInt;
 Row,Line:PByteArray;
Begin
 Case ImgKind of
  rkBit:Bits:=1;
  rkGray:Bits:=8;
  Else Bits:=24;
 End;
 Stride:=((ImgW*Bits+31)div 32)*4;
 If Bits=1 Then PalSize:=8 Else If Bits=8 Then PalSize:=1024 Else PalSize:=0;
 OffBits:=14+40+PalSize;
 HdrLen:=0;
 HStr('BM');
 HD(OffBits+Stride*ImgH);
 HD(0);
 HD(OffBits);
 HD(40);
 HD(ImgW);
 HD(ImgH);
 HW(1);
 HW(Bits);
 HD(0);
 HD(Stride*ImgH);
 HD(PixelsPerMeter(ImgDPI));
 HD(PixelsPerMeter(ImgDPI));
 If Bits=24 Then Begin
  HD(0);
  HD(0);
 End
  Else
 Begin
  HD(1 shl Bits);
  HD(0);
  If Bits=1 Then Begin
   HD($00FFFFFF);       { 0 = blanc }
   HD($00000000);       { 1 = noir }
  End
   Else
  For X:=0 to 255 do HD(X*$010101);
 End;
 HFlush;
 GetMem(Row,RowBytes+8);
 GetMem(Line,Stride+8);
 For Y:=ImgH-1 downto 0 do Begin
  ReadRow(Y,Row);
  FillChar(Line^,Stride,0);
  If ImgKind=rkRGB Then Begin
   For X:=0 to ImgW-1 do Begin
    Line^[X*3]:=Row^[X*3+2];
    Line^[X*3+1]:=Row^[X*3+1];
    Line^[X*3+2]:=Row^[X*3];
   End;
  End
   Else
  Move(Row^,Line^,RowBytes);
  DestWrite(Line^,Stride);
 End;
 FreeMem(Row,RowBytes+8);
 FreeMem(Line,Stride+8);
End;

Procedure WritePNM;
Var
 Y:LongInt;
 Row:PByteArray;
Begin
 HdrLen:=0;
 Case ImgKind of
  rkBit:HStr('P4');
  rkGray:HStr('P5');
  Else HStr('P6');
 End;
 HStr(#10'# SCAN '+IntStr(ImgDPI)+' DPI'#10+IntStr(ImgW)+' '+IntStr(ImgH)+#10);
 If ImgKind<>rkBit Then HStr('255'#10);
 HFlush;
 GetMem(Row,RowBytes+8);
 For Y:=0 to ImgH-1 do Begin
  ReadRow(Y,Row);
  DestWrite(Row^,RowBytes);
 End;
 FreeMem(Row,RowBytes+8);
End;

Procedure TiffEntry(Tag,TType,Count,Value:LongWord);
Begin
 HW(Tag);
 HW(TType);
 HD(Count);
 HD(Value);
End;

Procedure WriteTIFF;
Var
 Y,Samples,BitsPer,Photo,DataOff:LongInt;
 Row:PByteArray;
Begin
 Case ImgKind of
  rkBit:Begin Samples:=1;BitsPer:=1;Photo:=0;End;     { 0 = WhiteIsZero (1 = noir) }
  rkGray:Begin Samples:=1;BitsPer:=8;Photo:=1;End;
  Else Begin Samples:=3;BitsPer:=8;Photo:=2;End;
 End;
 DataOff:=8+2+12*12+4+6+8+8;         { en-tête + IFD + données associées }
 HdrLen:=0;
 HStr('II');
 HW(42);
 HD(8);
 HW(12);                             { Nombre d'entrées de l'IFD }
 TiffEntry(256,4,1,ImgW);                    { ImageWidth }
 TiffEntry(257,4,1,ImgH);                    { ImageLength }
 If Samples=3 Then TiffEntry(258,3,3,8+2+12*12+4)  { BitsPerSample }
              Else TiffEntry(258,3,1,BitsPer);
 TiffEntry(259,3,1,1);                       { Compression : aucune }
 TiffEntry(262,3,1,Photo);                   { PhotometricInterpretation }
 TiffEntry(273,4,1,DataOff);                 { StripOffsets }
 TiffEntry(277,3,1,Samples);                 { SamplesPerPixel }
 TiffEntry(278,4,1,ImgH);                    { RowsPerStrip }
 TiffEntry(279,4,1,RowBytes*ImgH);           { StripByteCounts }
 TiffEntry(282,5,1,8+2+12*12+4+6);           { XResolution }
 TiffEntry(283,5,1,8+2+12*12+4+6+8);         { YResolution }
 TiffEntry(296,3,1,2);                       { ResolutionUnit : pouce }
 HD(0);                                      { Fin des IFD }
 HW(8);HW(8);HW(8);                          { BitsPerSample des 3 composantes }
 HD(ImgDPI);HD(1);
 HD(ImgDPI);HD(1);
 HFlush;
 GetMem(Row,RowBytes+8);
 For Y:=0 to ImgH-1 do Begin
  ReadRow(Y,Row);
  DestWrite(Row^,RowBytes);
 End;
 FreeMem(Row,RowBytes+8);
End;

{ ── PNG : filtres + compression Deflate (LZ77 et codes de Huffman fixes) ── }

Const
 WinSize=32768;
 HashSize=32768;
 ZBufSize=32768;

Var
 LenIdx:Array[3..258]of Byte;
 LitCode:Array[0..287]of Word;     { Codes déjà inversés (écriture LSB d'abord) }
 LitLen:Array[0..287]of Byte;
 DBuf:PByteArray;
 DCap,DLen,DDone:LongInt;
 Head:Array[0..HashSize-1]of LongInt;
 BitAcc:LongWord;
 BitCnt:LongInt;
 ZBuf:Array[0..ZBufSize-1]of Byte;
 ZLen:LongInt;
 AdlerA,AdlerB:LongWord;

Const
 LenBase:Array[0..28]of Word=(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,
                              115,131,163,195,227,258);
 LenExtra:Array[0..28]of Byte=(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DistBase:Array[0..29]of Word=(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,
                               1025,1537,2049,3073,4097,6145,8193,12289,16385,24577);
 DistExtra:Array[0..29]of Byte=(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,
                                13,13);

Procedure InitCRCTable;
Var
 N,K:LongInt;
 C:LongWord;
Begin
 For N:=0 to 255 do Begin
  C:=N;
  For K:=0 to 7 do
   If(C and 1)<>0 Then C:=$EDB88320 xor(C shr 1)
                  Else C:=C shr 1;
  CRCTable[N]:=C;
 End;
End;

Function UpdateCRC(CRC:LongWord;Const Buf;Len:LongInt):LongWord;
Var
 P:PByteArray;
 I:LongInt;
Begin
 P:=@Buf;
 For I:=0 to Len-1 do CRC:=CRCTable[(CRC xor P^[I])and $FF]xor(CRC shr 8);
 UpdateCRC:=CRC;
End;

Function ReverseBits(V:LongWord;N:LongInt):Word;
Var
 I:LongInt;
 R:LongWord;
Begin
 R:=0;
 For I:=1 to N do Begin
  R:=(R shl 1)or(V and 1);
  V:=V shr 1;
 End;
 ReverseBits:=R;
End;

Procedure PutBE32(V:LongWord;Var A:Array of Byte);
Begin
 A[0]:=Byte(V shr 24);
 A[1]:=Byte(V shr 16);
 A[2]:=Byte(V shr 8);
 A[3]:=Byte(V);
End;

  { Écrit un bloc PNG : longueur, type, données et CRC-32. Les tampons
    utilisés sont locaux car Data peut être le tampon Hdr. }
Procedure WritePNGChunk(Const CType:String;Const Data;Len:LongInt);
Var
 CRC:LongWord;
 T:Array[0..3]of Byte;
 L,C:Array[0..3]of Byte;
 I:LongInt;
Begin
 For I:=0 to 3 do T[I]:=Ord(CType[I+1]);
 PutBE32(Len,L);
 DestWrite(L,4);
 DestWrite(T,4);
 If Len>0 Then DestWrite(Data,Len);
 CRC:=UpdateCRC($FFFFFFFF,T,4);
 If Len>0 Then CRC:=UpdateCRC(CRC,Data,Len);
 PutBE32(CRC xor $FFFFFFFF,C);
 DestWrite(C,4);
End;

Procedure ZFlush;
Begin
 If ZLen>0 Then WritePNGChunk('IDAT',ZBuf,ZLen);
 ZLen:=0;
End;

Procedure ZByte(B:Byte);
Begin
 ZBuf[ZLen]:=B;
 Inc(ZLen);
 If ZLen>=ZBufSize Then ZFlush;
End;

Procedure PutBits(V:LongWord;N:LongInt);
Begin
 BitAcc:=BitAcc or(V shl BitCnt);
 Inc(BitCnt,N);
 While BitCnt>=8 do Begin
  ZByte(BitAcc and $FF);
  BitAcc:=BitAcc shr 8;
  Dec(BitCnt,8);
 End;
End;

Procedure DeflateInit;
Var
 I,L:LongInt;
Begin
 For I:=0 to 28 do
  For L:=LenBase[I]to LenBase[I]+(1 shl LenExtra[I])-1 do
   If(L>=3)and(L<=257)Then LenIdx[L]:=I;
 LenIdx[258]:=28;
 For I:=0 to 287 do Begin
  If I<=143 Then Begin LitLen[I]:=8;LitCode[I]:=ReverseBits($30+I,8);End Else
  If I<=255 Then Begin LitLen[I]:=9;LitCode[I]:=ReverseBits($190+I-144,9);End Else
  If I<=279 Then Begin LitLen[I]:=7;LitCode[I]:=ReverseBits(I-256,7);End
            Else Begin LitLen[I]:=8;LitCode[I]:=ReverseBits($C0+I-280,8);End;
 End;
 DCap:=WinSize+RowBytes+1+65536;
 GetMem(DBuf,DCap);
 DLen:=0;
 DDone:=0;
 FillChar(Head,SizeOf(Head),$FF);
 BitAcc:=0;
 BitCnt:=0;
 ZLen:=0;
 AdlerA:=1;
 AdlerB:=0;
 ZByte($78);          { En-tête zlib }
 ZByte($01);
End;

Procedure PutSymbol(Sym:LongInt);
Begin
 PutBits(LitCode[Sym],LitLen[Sym]);
End;

Procedure PutMatch(Len,Dist:LongInt);
Var
 LI,DI:LongInt;
Begin
 LI:=LenIdx[Len];
 PutSymbol(257+LI);
 If LenExtra[LI]>0 Then PutBits(Len-LenBase[LI],LenExtra[LI]);
 DI:=29;
 While DistBase[DI]>Dist do Dec(DI);
 PutBits(ReverseBits(DI,5),5);
 If DistExtra[DI]>0 Then PutBits(Dist-DistBase[DI],DistExtra[DI]);
End;

Function HashAt(P:LongInt):LongInt;
Begin
 HashAt:=((DBuf^[P]shl 10)xor(DBuf^[P+1]shl 5)xor DBuf^[P+2])and(HashSize-1);
End;

  { Compresse les octets non traités de DBuf dans un bloc Deflate. }
Procedure DeflateBlock(Final:Boolean);
Var
 Pos,Cand,H,L,MaxL,K,Keep,Shift,I:LongInt;
Begin
 If Final Then PutBits(1,1) Else PutBits(0,1);
 PutBits(1,2);                      { Codes de Huffman fixes }
 Pos:=DDone;
 While Pos<DLen do Begin
  L:=0;
  Cand:=-1;
  If Pos+2<DLen Then Begin
   H:=HashAt(Pos);
   Cand:=Head[H];
   Head[H]:=Pos;
   If(Cand>=0)and(Pos-Cand<=WinSize)Then Begin
    MaxL:=DLen-Pos;
    If MaxL>258 Then MaxL:=258;
    While(L<MaxL)and(DBuf^[Cand+L]=DBuf^[Pos+L])do Inc(L);
   End;
  End;
  If L>=3 Then Begin
   PutMatch(L,Pos-Cand);
   For K:=Pos+1 to Pos+L-1 do
    If K+2<DLen Then Head[HashAt(K)]:=K;
   Inc(Pos,L);
  End
   Else
  Begin
   PutSymbol(DBuf^[Pos]);
   Inc(Pos);
  End;
 End;
 PutSymbol(256);
 DDone:=DLen;
 If not Final Then Begin
    { On ne garde que la fenêtre de 32 Ko comme historique }
  If DLen>WinSize Then Keep:=WinSize Else Keep:=DLen;
  Shift:=DLen-Keep;
  If Shift>0 Then Begin
   Move(DBuf^[Shift],DBuf^[0],Keep);
   DLen:=Keep;
   DDone:=Keep;
   For I:=0 to HashSize-1 do Begin
    If Head[I]>=Shift Then Dec(Head[I],Shift) Else Head[I]:=-1;
   End;
  End;
 End;
End;

Procedure DeflateFeed(Data:PByteArray;Len:LongInt);
Var
 N,I:LongInt;
Begin
 For I:=0 to Len-1 do Begin
  AdlerA:=(AdlerA+Data^[I])mod 65521;
  AdlerB:=(AdlerB+AdlerA)mod 65521;
 End;
 I:=0;
 While Len>0 do Begin
  N:=DCap-DLen;
  If N>Len Then N:=Len;
  Move(Data^[I],DBuf^[DLen],N);
  Inc(DLen,N);
  Inc(I,N);
  Dec(Len,N);
  If DLen>=DCap Then DeflateBlock(False);
 End;
End;

Procedure DeflateFinish;
Var
 Adler:LongWord;
Begin
 DeflateBlock(True);
 If BitCnt>0 Then PutBits(0,8-BitCnt);
 Adler:=(AdlerB shl 16)or AdlerA;
 ZByte(Adler shr 24);
 ZByte(Adler shr 16);
 ZByte(Adler shr 8);
 ZByte(Adler);
 ZFlush;
 FreeMem(DBuf,DCap);
End;

Function Paeth(A,B,C:LongInt):LongInt;
Var
 P,PA,PB,PC:LongInt;
Begin
 P:=A+B-C;
 PA:=Abs(P-A);
 PB:=Abs(P-B);
 PC:=Abs(P-C);
 If(PA<=PB)and(PA<=PC)Then Paeth:=A Else
 If PB<=PC Then Paeth:=B
           Else Paeth:=C;
End;

Procedure WritePNG;
Var
 Y,I,F,Bpp,Score,BestScore,V,BestF:LongInt;
 Cur,Prev,Cand,Best:PByteArray;
 FilterByte:Array[0..0]of Byte;
 Sig:Array[0..7]of Byte;
 ColorType,BitDepth:Byte;
Begin
 Case ImgKind of
  rkBit:Begin ColorType:=0;BitDepth:=1;Bpp:=1;End;
  rkGray:Begin ColorType:=0;BitDepth:=8;Bpp:=1;End;
  Else Begin ColorType:=2;BitDepth:=8;Bpp:=3;End;
 End;
 InitCRCTable;
 Sig[0]:=137;Sig[1]:=80;Sig[2]:=78;Sig[3]:=71;Sig[4]:=13;Sig[5]:=10;Sig[6]:=26;Sig[7]:=10;
 DestWrite(Sig,8);
 HdrLen:=0;
 HBE(ImgW);
 HBE(ImgH);
 HB(BitDepth);
 HB(ColorType);
 HB(0);HB(0);HB(0);
 WritePNGChunk('IHDR',Hdr,HdrLen);
 HdrLen:=0;
 HBE(PixelsPerMeter(ImgDPI));
 HBE(PixelsPerMeter(ImgDPI));
 HB(1);
 WritePNGChunk('pHYs',Hdr,HdrLen);
 HdrLen:=0;

 GetMem(Cur,RowBytes+8);
 GetMem(Prev,RowBytes+8);
 GetMem(Cand,RowBytes+8);
 GetMem(Best,RowBytes+8);
 FillChar(Prev^,RowBytes,0);
 DeflateInit;
 For Y:=0 to ImgH-1 do Begin
  ReadRow(Y,Cur);
  If ImgKind=rkBit Then For I:=0 to RowBytes-1 do Cur^[I]:=Cur^[I]xor $FF;   { PNG : 0 = noir }
  BestScore:=High(LongInt);
  For F:=0 to 4 do Begin
   Score:=0;
   For I:=0 to RowBytes-1 do Begin
    Case F of
     0:V:=Cur^[I];
     1:If I>=Bpp Then V:=Cur^[I]-Cur^[I-Bpp] Else V:=Cur^[I];
     2:V:=Cur^[I]-Prev^[I];
     3:If I>=Bpp Then V:=Cur^[I]-((Cur^[I-Bpp]+Prev^[I])shr 1)
                 Else V:=Cur^[I]-(Prev^[I]shr 1);
     Else If I>=Bpp Then V:=Cur^[I]-Paeth(Cur^[I-Bpp],Prev^[I],Prev^[I-Bpp])
                    Else V:=Cur^[I]-Paeth(0,Prev^[I],0);
    End;
    Cand^[I]:=Byte(V and $FF);
    If Cand^[I]<128 Then Inc(Score,Cand^[I]) Else Inc(Score,256-Cand^[I]);
    If Score>BestScore Then Break;
   End;
   If Score<BestScore Then Begin
    BestScore:=Score;
    Move(Cand^,Best^,RowBytes);
    BestF:=F;                { Mémorise le type de filtre retenu }
   End;
  End;
  FilterByte[0]:=BestF;
  DeflateFeed(@FilterByte,1);
  DeflateFeed(Best,RowBytes);
  Move(Cur^,Prev^,RowBytes);
 End;
 DeflateFinish;
 HdrLen:=0;
 WritePNGChunk('IEND',Hdr,0);
 FreeMem(Cur,RowBytes+8);
 FreeMem(Prev,RowBytes+8);
 FreeMem(Cand,RowBytes+8);
 FreeMem(Best,RowBytes+8);
End;

{ ── JPEG de base (DCT, Huffman standard, 8 bits, sans sous-échantillonnage) ── }

Const
 QLum:Array[0..63]of Byte=(16,11,10,16,24,40,51,61,12,12,14,19,26,58,60,55,14,13,16,24,40,57,69,56,
                           14,17,22,29,51,87,80,62,18,22,37,56,68,109,103,77,24,35,55,64,81,104,
                           113,92,49,64,78,87,103,121,120,101,72,92,95,98,112,100,103,99);
 QChr:Array[0..63]of Byte=(17,18,24,47,99,99,99,99,18,21,26,66,99,99,99,99,24,26,56,99,99,99,99,99,
                           47,66,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,
                           99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99);
 ZigZag:Array[0..63]of Byte=(0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,26,33,40,48,41,34,27,20,
                             13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,
                             52,45,38,31,39,46,53,60,61,54,47,55,62,63);

  { Tables de Huffman standard (annexe K de la norme JPEG) }
 DCLumBits:Array[1..16]of Byte=(0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0);
 DCChrBits:Array[1..16]of Byte=(0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0);
 DCVals:Array[0..11]of Byte=(0,1,2,3,4,5,6,7,8,9,10,11);
 ACLumBits:Array[1..16]of Byte=(0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,$7D);
 ACLumVals:Array[0..161]of Byte=(
  $01,$02,$03,$00,$04,$11,$05,$12,$21,$31,$41,$06,$13,$51,$61,$07,
  $22,$71,$14,$32,$81,$91,$A1,$08,$23,$42,$B1,$C1,$15,$52,$D1,$F0,
  $24,$33,$62,$72,$82,$09,$0A,$16,$17,$18,$19,$1A,$25,$26,$27,$28,
  $29,$2A,$34,$35,$36,$37,$38,$39,$3A,$43,$44,$45,$46,$47,$48,$49,
  $4A,$53,$54,$55,$56,$57,$58,$59,$5A,$63,$64,$65,$66,$67,$68,$69,
  $6A,$73,$74,$75,$76,$77,$78,$79,$7A,$83,$84,$85,$86,$87,$88,$89,
  $8A,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$A2,$A3,$A4,$A5,$A6,$A7,
  $A8,$A9,$AA,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$C2,$C3,$C4,$C5,
  $C6,$C7,$C8,$C9,$CA,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$E1,$E2,
  $E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,
  $F9,$FA);
 ACChrBits:Array[1..16]of Byte=(0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,$77);
 ACChrVals:Array[0..161]of Byte=(
  $00,$01,$02,$03,$11,$04,$05,$21,$31,$06,$12,$41,$51,$07,$61,$71,
  $13,$22,$32,$81,$08,$14,$42,$91,$A1,$B1,$C1,$09,$23,$33,$52,$F0,
  $15,$62,$72,$D1,$0A,$16,$24,$34,$E1,$25,$F1,$17,$18,$19,$1A,$26,
  $27,$28,$29,$2A,$35,$36,$37,$38,$39,$3A,$43,$44,$45,$46,$47,$48,
  $49,$4A,$53,$54,$55,$56,$57,$58,$59,$5A,$63,$64,$65,$66,$67,$68,
  $69,$6A,$73,$74,$75,$76,$77,$78,$79,$7A,$82,$83,$84,$85,$86,$87,
  $88,$89,$8A,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$A2,$A3,$A4,$A5,
  $A6,$A7,$A8,$A9,$AA,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$C2,$C3,
  $C4,$C5,$C6,$C7,$C8,$C9,$CA,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,
  $E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$F2,$F3,$F4,$F5,$F6,$F7,$F8,
  $F9,$FA);

Type
 THuff=Record
  Code:Array[0..255]of Word;
  Size:Array[0..255]of Byte;
 End;

Var
 JQ:Array[0..1,0..63]of Byte;
 JH:Array[0..3]of THuff;      { 0=DC lum, 1=DC chr, 2=AC lum, 3=AC chr }
 DctM:Array[0..7,0..7]of Double;
 JAcc:LongWord;
 JCnt:LongInt;

Procedure JByte(B:Byte);
Begin
 DestWrite(B,1);
 If B=$FF Then Begin
  B:=0;
  DestWrite(B,1);
 End;
End;

Procedure JBits(V:LongWord;N:LongInt);
Begin
 If N=0 Then Exit;
 JAcc:=(JAcc shl N)or(V and((LongWord(1)shl N)-1));
 Inc(JCnt,N);
 While JCnt>=8 do Begin
  JByte(Byte((JAcc shr(JCnt-8))and $FF));
  Dec(JCnt,8);
 End;
 JAcc:=JAcc and((LongWord(1)shl JCnt)-1);
End;

Procedure BuildHuff(T:Integer;Const Bits:Array of Byte;Const Vals:Array of Byte);
Var
 L,I,K:LongInt;
 Code:LongWord;
Begin
 FillChar(JH[T],SizeOf(THuff),0);
 Code:=0;
 K:=0;
 For L:=1 to 16 do Begin
  For I:=1 to Bits[L-1]do Begin
   JH[T].Code[Vals[K]]:=Code;
   JH[T].Size[Vals[K]]:=L;
   Inc(Code);
   Inc(K);
  End;
  Code:=Code shl 1;
 End;
End;

Procedure JMarker(M:Byte);
Begin
 HB($FF);
 HB(M);
End;

Procedure JpegInit;
Var
 S,I,J:LongInt;
 Q:LongInt;
Begin
 Q:=JpegQuality;
 If Q<50 Then S:=5000 div Q Else S:=200-2*Q;
 For I:=0 to 63 do Begin
  Q:=(QLum[I]*S+50)div 100;
  If Q<1 Then Q:=1;
  If Q>255 Then Q:=255;
  JQ[0,I]:=Q;
  Q:=(QChr[I]*S+50)div 100;
  If Q<1 Then Q:=1;
  If Q>255 Then Q:=255;
  JQ[1,I]:=Q;
 End;
 BuildHuff(0,DCLumBits,DCVals);
 BuildHuff(1,DCChrBits,DCVals);
 BuildHuff(2,ACLumBits,ACLumVals);
 BuildHuff(3,ACChrBits,ACChrVals);
 For I:=0 to 7 do
  For J:=0 to 7 do Begin
   DctM[I,J]:=Cos((2*J+1)*I*Pi/16)/2;
   If I=0 Then DctM[I,J]:=DctM[I,J]/Sqrt(2);
  End;
 JAcc:=0;
 JCnt:=0;
End;

Procedure PutHuffTable(TableClass:Byte;Const Bits:Array of Byte;Const Vals:Array of Byte;N:LongInt);
Var
 I:LongInt;
Begin
 JMarker($C4);
 HBW(19+N);
 HB(TableClass);
 For I:=0 to 15 do HB(Bits[I]);
 For I:=0 to N-1 do HB(Vals[I]);
End;

Function BitLength(V:LongInt):LongInt;
Var
 N:LongInt;
Begin
 N:=0;
 V:=Abs(V);
 While V>0 do Begin
  Inc(N);
  V:=V shr 1;
 End;
 BitLength:=N;
End;

  { Transforme, quantifie et encode un bloc 8x8 d'échantillons (0..255). }
Procedure JpegBlock(Const Blk:Array of Byte;QT,DCT,ACT:Integer;Var Pred:LongInt);
Var
 F,T:Array[0..7,0..7]of Double;
 Coef:Array[0..63]of LongInt;
 U,V,K,X,Y,Run,Diff,N,Nat:LongInt;
 Sum:Double;
Begin
 For Y:=0 to 7 do
  For X:=0 to 7 do F[Y,X]:=Blk[Y*8+X]-128;
 For U:=0 to 7 do
  For X:=0 to 7 do Begin
   Sum:=0;
   For Y:=0 to 7 do Sum:=Sum+DctM[U,Y]*F[Y,X];
   T[U,X]:=Sum;
  End;
 For U:=0 to 7 do
  For V:=0 to 7 do Begin
   Sum:=0;
   For X:=0 to 7 do Sum:=Sum+T[U,X]*DctM[V,X];
   Nat:=U*8+V;
   Coef[Nat]:=Round(Sum/JQ[QT,Nat]);
  End;
 Diff:=Coef[0]-Pred;
 Pred:=Coef[0];
 N:=BitLength(Diff);
 JBits(JH[DCT].Code[N],JH[DCT].Size[N]);
 If Diff<0 Then Diff:=Diff+(1 shl N)-1;
 JBits(Diff,N);
 Run:=0;
 For K:=1 to 63 do Begin
  V:=Coef[ZigZag[K]];
  If V=0 Then Inc(Run)
   Else
  Begin
   While Run>15 do Begin
    JBits(JH[ACT].Code[$F0],JH[ACT].Size[$F0]);
    Dec(Run,16);
   End;
   N:=BitLength(V);
   JBits(JH[ACT].Code[Run*16+N],JH[ACT].Size[Run*16+N]);
   If V<0 Then V:=V+(1 shl N)-1;
   JBits(V,N);
   Run:=0;
  End;
 End;
 If Run>0 Then JBits(JH[ACT].Code[0],JH[ACT].Size[0]);
End;

Procedure WriteJPEG;
Var
 NC,PW,BX,BY,X,Y,I,C,YY,Src:LongInt;
 Row:PByteArray;
 Plane:Array[0..2]of PByteArray;
 Blk:Array[0..63]of Byte;
 Pred:Array[0..2]of LongInt;
 R,G,B:LongInt;
 V:Double;
Begin
 If(ImgW>65535)or(ImgH>65535)Then Fail('image trop grande pour le format JPEG',ExitFile);
 If ImgKind=rkRGB Then NC:=3 Else NC:=1;
 JpegInit;
 HdrLen:=0;
 JMarker($D8);
 JMarker($E0);                      { JFIF }
 HBW(16);
 HStr('JFIF');HB(0);HB(1);HB(1);
 HB(1);                             { Densité en points par pouce }
 HBW(ImgDPI);
 HBW(ImgDPI);
 HB(0);HB(0);
 JMarker($DB);                      { Table de quantification de la luminance }
 HBW(67);
 HB(0);
 For Y:=0 to 63 do HB(JQ[0,ZigZag[Y]]);
 If NC=3 Then Begin
  JMarker($DB);                     { Table de quantification de la chrominance }
  HBW(67);
  HB(1);
  For Y:=0 to 63 do HB(JQ[1,ZigZag[Y]]);
 End;
 JMarker($C0);                      { SOF0 : DCT de base }
 HBW(8+3*NC);
 HB(8);
 HBW(ImgH);
 HBW(ImgW);
 HB(NC);
 For I:=0 to NC-1 do Begin
  HB(I+1);
  HB($11);
  If I=0 Then HB(0) Else HB(1);
 End;
 PutHuffTable($00,DCLumBits,DCVals,12);
 PutHuffTable($10,ACLumBits,ACLumVals,162);
 If NC=3 Then Begin
  PutHuffTable($01,DCChrBits,DCVals,12);
  PutHuffTable($11,ACChrBits,ACChrVals,162);
 End;
 JMarker($DA);                      { Début des données }
 HBW(6+2*NC);
 HB(NC);
 For I:=0 to NC-1 do Begin
  HB(I+1);
  If I=0 Then HB($00) Else HB($11);
 End;
 HB(0);HB(63);HB(0);
 HFlush;

 PW:=((ImgW+7)div 8)*8;
 GetMem(Row,RowBytes+8);
 For C:=0 to NC-1 do Begin
  GetMem(Plane[C],PW*8);
 End;
 Pred[0]:=0;Pred[1]:=0;Pred[2]:=0;
 For BY:=0 to((ImgH+7)div 8)-1 do Begin
  For YY:=0 to 7 do Begin
   Y:=BY*8+YY;
   If Y>=ImgH Then Y:=ImgH-1;
   ReadRow(Y,Row);
   For X:=0 to PW-1 do Begin
    Src:=X;
    If Src>=ImgW Then Src:=ImgW-1;
    Case ImgKind of
     rkBit:Begin
      If(Row^[Src shr 3]and($80 shr(Src and 7)))<>0 Then Plane[0]^[YY*PW+X]:=0
                                                    Else Plane[0]^[YY*PW+X]:=255;
     End;
     rkGray:Plane[0]^[YY*PW+X]:=Row^[Src];
     Else Begin
      R:=Row^[Src*3];G:=Row^[Src*3+1];B:=Row^[Src*3+2];
      V:=0.299*R+0.587*G+0.114*B;
      Plane[0]^[YY*PW+X]:=Round(V);
      V:=128-0.168736*R-0.331264*G+0.5*B;
      If V<0 Then V:=0;
      If V>255 Then V:=255;
      Plane[1]^[YY*PW+X]:=Round(V);
      V:=128+0.5*R-0.418688*G-0.081312*B;
      If V<0 Then V:=0;
      If V>255 Then V:=255;
      Plane[2]^[YY*PW+X]:=Round(V);
     End;
    End;
   End;
  End;
  For BX:=0 to(PW div 8)-1 do
   For C:=0 to NC-1 do Begin
    For YY:=0 to 7 do
     For X:=0 to 7 do Blk[YY*8+X]:=Plane[C]^[YY*PW+BX*8+X];
    If C=0 Then JpegBlock(Blk,0,0,2,Pred[0])
           Else JpegBlock(Blk,1,1,3,Pred[C]);
   End;
 End;
 If JCnt>0 Then JBits($7F,8-JCnt);    { Complète le dernier octet avec des 1 }
 HdrLen:=0;
 JMarker($D9);
 HFlush;
 FreeMem(Row,RowBytes+8);
 For C:=0 to NC-1 do FreeMem(Plane[C],PW*8);
End;

{ ── Numérisation d'une page SANE ── }

  { Lit une page complète depuis le périphérique SANE et la mémorise dans le
    fichier temporaire en lignes normalisées (1 bit / 8 bits gris / RVB 8). }
Procedure AcquirePage;
Var
 P:TSaneParams;
 St,Len,Fill,BPL,I,X,Sample,Step:LongInt;
 Buf:Array[0..65535]of Byte;
 Line,OutRow:PByteArray;
 Wrote:LongInt;
Begin
 St:=Sane_GetParams(Handle,P);
 If St<>SANE_STATUS_GOOD Then Fail('sane_get_parameters a echoue : '+SaneMsg(St),ExitScan);
 If(P.Format<>SANE_FRAME_GRAY)and(P.Format<>SANE_FRAME_RGB)Then
  Fail('les scanners a trois passes (images R, V, B separees) ne sont pas supportes',ExitScan);
 If(P.Format=SANE_FRAME_RGB)and(P.Depth<>8)and(P.Depth<>16)Then
  Fail('profondeur de couleur non supportee ('+IntStr(P.Depth)+' bits)',ExitScan);
 If(P.PixelsPerLine<=0)or(P.BytesPerLine<=0)Then Fail('parametres d''image invalides',ExitScan);
 ImgW:=P.PixelsPerLine;
 BPL:=P.BytesPerLine;
 If P.Format=SANE_FRAME_RGB Then Begin
  ImgKind:=rkRGB;
  RowBytes:=ImgW*3;
 End
  Else
 If P.Depth=1 Then Begin
  ImgKind:=rkBit;
  RowBytes:=(ImgW+7)div 8;
 End
  Else
 Begin
  ImgKind:=rkGray;
  RowBytes:=ImgW;
 End;
 If P.Depth>8 Then Step:=2 Else Step:=1;        { Octets par échantillon }

 TmpName:=OptOutput+'.tmp';
 Assign(Tmp,TmpName);
 {$IOCHECKS OFF}Rewrite(Tmp,1);{$IOCHECKS ON}
 If IOResult<>0 Then Fail('impossible de creer le fichier temporaire '+TmpName,ExitFile);
 TmpOpen:=True;
 GetMem(Line,BPL+8);
 GetMem(OutRow,RowBytes+8);
 ImgH:=0;
 Fill:=0;
 Repeat
  Len:=0;
  St:=Sane_Read(Handle,@Buf,SizeOf(Buf),Len);
  If(St<>SANE_STATUS_GOOD)and(St<>SANE_STATUS_EOF)Then Begin
   FreeMem(Line,BPL+8);
   FreeMem(OutRow,RowBytes+8);
   Fail('sane_read a echoue : '+SaneMsg(St),ExitScan);
  End;
  I:=0;
  While I<Len do Begin
   X:=BPL-Fill;
   If X>Len-I Then X:=Len-I;
   Move(Buf[I],Line^[Fill],X);
   Inc(Fill,X);
   Inc(I,X);
   If Fill=BPL Then Begin
      { Ligne complète : conversion en ligne normalisée }
    Case ImgKind of
     rkBit:Move(Line^,OutRow^,RowBytes);
     rkGray:
      If Step=1 Then Move(Line^,OutRow^,RowBytes)
       Else
      For X:=0 to ImgW-1 do Begin
       {$IFDEF ENDIAN_BIG}Sample:=Line^[X*2];{$ELSE}Sample:=Line^[X*2+1];{$ENDIF}
       OutRow^[X]:=Sample;
      End;
     Else
      If Step=1 Then Move(Line^,OutRow^,RowBytes)
       Else
      For X:=0 to ImgW*3-1 do Begin
       {$IFDEF ENDIAN_BIG}Sample:=Line^[X*2];{$ELSE}Sample:=Line^[X*2+1];{$ENDIF}
       OutRow^[X]:=Sample;
      End;
    End;
    BlockWrite(Tmp,OutRow^,RowBytes,Wrote);
    If Wrote<>RowBytes Then Begin
     FreeMem(Line,BPL+8);
     FreeMem(OutRow,RowBytes+8);
     Fail('erreur d''ecriture du fichier temporaire (disque plein ?)',ExitFile);
    End;
    Inc(ImgH);
    Fill:=0;
   End;
  End;
 Until St=SANE_STATUS_EOF;
 FreeMem(Line,BPL+8);
 FreeMem(OutRow,RowBytes+8);
 If ImgH=0 Then Fail('le scanner n''a retourne aucune donnee',ExitScan);
 Close(Tmp);
 Reset(Tmp,1);
End;

Procedure SaveImage(Const FileName:String);
Begin
 Assign(Dest,FileName);
 {$IOCHECKS OFF}Rewrite(Dest,1);{$IOCHECKS ON}
 If IOResult<>0 Then Fail('impossible de creer le fichier '+FileName,ExitFile);
 DestOpen:=True;
 OptOutput:=FileName;
 Case OutFormat of
  fmtBMP:WriteBMP;
  fmtJPEG:WriteJPEG;
  fmtTIFF:WriteTIFF;
  fmtPNM:WritePNM;
  Else WritePNG;
 End;
 CloseDest(False);
End;

Procedure RunScan;
Var
 Idx,Raw,Page,St,DPI,Actual:LongInt;
 Chosen,FileName,BaseOutput:String;
 Feeder,Multi:Boolean;
Begin
 SaneOpenDevice;
 Feeder:=OptSource=srcFeeder;
 Multi:=Feeder;
 DPI:=WantedDPI;
 BaseOutput:=OptOutput;

  { Source de papier }
 Idx:=SaneFindOption('source');
 If Idx>=0 Then Begin
  Case OptSource of
   srcFeeder:Begin
    If not SaneChooseString(Idx,200+srcFeeder,Chosen)Then
     Fail('le chargeur automatique n''est pas disponible sur ce scanner',ExitScan);
    WriteLn('Source     : ',Chosen);
   End;
   srcFlatbed:Begin
    If SaneChooseString(Idx,200+srcFlatbed,Chosen)Then WriteLn('Source     : ',Chosen);
   End;
  End;
 End
  Else
 If Feeder Then Fail('le chargeur automatique n''est pas disponible sur ce scanner',ExitScan);

  { Mode de couleur }
 Idx:=SaneFindOption('mode');
 If Idx>=0 Then Begin
  If not SaneChooseString(Idx,100+OptColor,Chosen)Then
   Warn('le mode "'+ColorLabel+'" n''est pas accepte par le scanner')
  Else
   WriteLn('Mode       : ',Chosen);
 End;

  { 8 bits par composante (sauf en noir et blanc) }
 Idx:=SaneFindOption('depth');
 If(Idx>=0)and(OptColor<>clrBW)Then SaneSetRaw(Idx,SaneFitRaw(Idx,8));

  { Résolution }
 Idx:=SaneFindOption('resolution');
 If Idx>=0 Then Begin
  Raw:=SaneFitRaw(Idx,DPI);
  If not SaneSetRaw(Idx,Raw)Then Warn('la resolution de '+IntStr(DPI)+' DPI n''est pas acceptee');
  If SaneGetRaw(Idx,Raw)Then Begin
   Actual:=RawToUnits(Idx,Raw);
   If(Actual<>DPI)and(OptDPI>0)Then
    Warn('resolution de '+IntStr(DPI)+' DPI non disponible, utilisation de '+IntStr(Actual)+' DPI');
   DPI:=Actual;
  End;
 End;
 ImgDPI:=DPI;

  { Aperçu rapide }
 Idx:=SaneFindOption('preview');
 If Idx>=0 Then SaneSetRaw(Idx,Ord(OptPreview));

  { Zone de numérisation : toute la surface utile }
 Idx:=SaneFindOption('tl-x');
 If(Idx>=0)and SaneRangeLimit(Idx,False,Raw)Then SaneSetRaw(Idx,Raw);
 Idx:=SaneFindOption('tl-y');
 If(Idx>=0)and SaneRangeLimit(Idx,False,Raw)Then SaneSetRaw(Idx,Raw);
 Idx:=SaneFindOption('br-x');
 If(Idx>=0)and SaneRangeLimit(Idx,True,Raw)Then SaneSetRaw(Idx,Raw);
 Idx:=SaneFindOption('br-y');
 If(Idx>=0)and SaneRangeLimit(Idx,True,Raw)Then SaneSetRaw(Idx,Raw);

 WriteLn('Scanner    : ',SelName);
 WriteLn('Resolution : ',DPI,' DPI, ',ColorLabel);
 If OptPreview Then WriteLn('Apercu     : numerisation rapide a basse resolution');

  { Numérisation (une page, ou toutes les pages du chargeur) }
 Page:=0;
 Repeat
  St:=Sane_Start(Handle);
  If St=SANE_STATUS_NO_DOCS Then Begin
   If Page=0 Then Fail('le chargeur automatique est vide',ExitScan);
   Break;
  End;
  If St<>SANE_STATUS_GOOD Then Fail('sane_start a echoue : '+SaneMsg(St),ExitScan);
  ScanActive:=True;
  OptOutput:=OutputName(Page+1,Multi);
  FileName:=OptOutput;
  AcquirePage;
  ScanActive:=False;
  SaveImage(FileName);
  CloseTemp;
  Inc(Page);
  WriteLn('Image enregistree : ',FileName,' (',ImgW,'x',ImgH,' pixels)');
 Until(not Multi)or(Page>=MaxPages);
 Sane_Cancel(Handle);
 OptOutput:=BaseOutput;
 If Multi Then WriteLn(Page,' page(s) numerisee(s).');
End;

Procedure BackendInit;
Begin
 OnFail:=@SaneShutdown;
 SaneInitLib;
End;

Procedure BackendDone;
Begin
 SaneShutdown;
End;

Procedure BackendRun;
Begin
 If OptUI Then Begin
  SaneOpenDevice;
  ShowDriverOptions;
 End
  Else
 RunScan;
End;

  { Un nom de périphérique SANE inconnu de la liste (ex. "net:hote:pilote")
    est accepté tel quel. }
Function DeviceByName:Boolean;
Begin
 SelID:=OptDevice;
 SelName:=OptDevice;
 DeviceByName:=True;
End;

{$ENDIF}

{ ═══════════════════════ Plateformes sans pilote de scanner ═══════════════════ }

{$IFNDEF SCAN_WIA}
{$IFNDEF SCAN_SANE}

Procedure EnumDevices;
Begin
 DevCount:=0;
End;

Procedure BackendInit;
Begin
 Fail('plateforme non supportee : SCAN utilise WIA (Windows) ou SANE (Linux)',ExitDevice);
End;

Procedure BackendDone;
Begin
End;

Procedure BackendRun;
Begin
End;

Function DeviceByName:Boolean;
Begin
 DeviceByName:=False;
End;

{$ENDIF}
{$ENDIF}

BEGIN
 OnFail:=NIL;
 ParseCmdLine;
 If OptHelp or(ParamCount=0)Then Begin
  ShowHelp;
  Halt;
 End;
 BackendInit;
 EnumDevices;
 If OptList Then Begin
  ListDevices;
  BackendDone;
  Halt;
 End;
 If not SelectDevice Then Begin
  If not DeviceByName Then Fail('scanner "'+OptDevice+'" introuvable (voir SCAN /LIST)',ExitDevice);
 End;
 ResolveOutput;
 BackendRun;
 BackendDone;
END.
