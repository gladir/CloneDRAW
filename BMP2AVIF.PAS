{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/clonedraw)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)

  TODO - Integration progressive d'un encodeur AV1/AVIF complet :
   1. Definir le perimetre initial : image fixe AVIF, 8 bits, SDR, sans alpha.
      - Objectif de la premiere version : produire un fichier AVIF valide
        contenant une seule image, sans animation, sans transparence et sans
        profondeur de couleur superieure a 8 bits par composante.
      - Entree acceptee : BMP non compresse deja pris en charge par ce
        programme, converti en memoire ligne par ligne vers RGB 8 bits.
      - Profil AV1 cible : Main profile, still picture, intra-only, sans
        references inter-images, sans film grain, sans tiles multiples et sans
        outils avances optionnels.
      - Format couleur interne initial : YUV 4:2:0 8 bits, full range ou
        limited range a choisir explicitement avant l'ecriture du bitstream.
      - Conteneur AVIF cible : ISO-BMFF minimal avec une seule item image
        primaire, un seul flux AV1, et les proprietes obligatoires ispe, pixi,
        av1C et colr.
      - Limites volontairement exclues de cette etape : alpha, HDR, ICC
        embarque, EXIF/XMP, animation, images auxiliaires, gain maps, grilles
        AVIF et encodage avec pertes finement optimise.
      - Critere de fin de l'etape : les constantes, types, options et messages
        d'aide du programme decrivent ce perimetre sans ambiguite, avant de
        commencer les structures YUV et l'encodage AV1.
   2. Ajouter une structure YUV420/YUV444 interne separee du decodeur BMP.
      - Creer des types distincts pour les plans Y, U et V afin de separer
        clairement le decodeur BMP RGB de la representation encodeur AV1.
      - Prevoir une structure TAVIFPlane contenant largeur, hauteur, stride,
        taille allouee et pointeur/tampon vers les echantillons 8 bits.
      - Prevoir une structure TAVIFImage contenant Width, Height, BitDepth,
        ChromaFormat, RangeMode, ColorPrimaries, TransferCharacteristics,
        MatrixCoefficients et trois plans Y/U/V.
      - Definir les formats chroma internes minimum : cfYUV420 et cfYUV444.
        cfYUV420 sera la cible initiale; cfYUV444 servira aux tests sans perte
        de sous-echantillonnage chroma.
      - Calculer les dimensions des plans chroma selon le format : en 4:2:0,
        U et V ont une largeur et une hauteur arrondies a la moitie superieure.
      - Ajouter des fonctions AllocateAVIFImage et FreeAVIFImage, meme si la
        premiere version utilise des tableaux statiques, afin de garder une
        evolution possible vers allocation dynamique sous Free Pascal.
      - Ajouter ClearAVIFImage pour initialiser Y a 0 et U/V a 128, ce qui
        represente un noir neutre en YUV 8 bits.
      - Ajouter une verification MaxWidth/MaxHeight et une taille maximale de
        tampon pour eviter les debordements Turbo Pascal.
      - Ne pas melanger les pixels BMP BGR/RGB avec les plans YUV : le flux de
        donnees doit etre BMP -> RGB temporaire par pixel -> YUVImage.
      - Critere de fin de l'etape : le programme possede les types et routines
        de gestion memoire des plans YUV, meme si la conversion RGB vers YUV
        reste encore a implementer a l'etape suivante.
   3. Implementer la conversion RGB vers YUV BT.709 et BT.601 avec arrondis fixes.
      - Ajouter une enumeration TColorMatrixMode avec au minimum cmBT601 et
        cmBT709; cmBT709 sera le choix par defaut pour AVIF SDR moderne.
      - Ajouter une enumeration TRangeMode avec rmFullRange et rmLimitedRange,
        puis propager ce choix vers le tag colr du conteneur AVIF.
      - Utiliser uniquement de l'arithmetique entiere fixe pour rester portable
        Turbo Pascal/Free Pascal : coefficients multiplies par 16384 ou 32768,
        addition d'un biais de demi-unite, puis decalage a droite.
      - Pour BT.601 full range, utiliser l'equivalent entier de :
        Y=0.299R+0.587G+0.114B,
        U=-0.168736R-0.331264G+0.5B+128,
        V=0.5R-0.418688G-0.081312B+128.
      - Pour BT.709 full range, utiliser l'equivalent entier de :
        Y=0.2126R+0.7152G+0.0722B,
        U=-0.114572R-0.385428G+0.5B+128,
        V=0.5R-0.454153G-0.045847B+128.
      - Pour limited range 8 bits, convertir Y vers [16..235] et U/V vers
        [16..240], en appliquant les offsets apres la matrice couleur.
      - Ajouter une fonction ClampByte(Value:LongInt):Byte pour borner chaque
        composante entre 0 et 255.
      - Ajouter RGBToYUVPixel(R,G,B:Byte; Var Y,U,V:Byte; Matrix,Range) pour
        centraliser la conversion d'un pixel.
      - Ajouter ConvertRGBLineToYUV444 pour remplir directement les plans Y,
        U et V sans sous-echantillonnage.
      - Pour YUV420, ne pas faire la moyenne chroma ici : stocker d'abord ou
        accumuler U/V dans une etape separee afin de garder la TODO 4 dediee
        au sous-echantillonnage.
      - Ajouter des tests simples dans les commentaires : noir -> Y bas/U=128/V=128,
        blanc -> Y haut/U=128/V=128, rouge/vert/bleu avec valeurs attendues
        approximatives.
      - Critere de fin de l'etape : un BMP peut etre parcouru et converti en
        plans YUV444 8 bits reproductibles, sans encore encoder AV1.
   4. Ajouter le sous-echantillonnage chroma 4:2:0 et la variante 4:4:4.
      - Conserver YUV444 comme format de reference interne : Y, U et V ont
        tous la meme dimension que l'image source, utile pour debug et tests.
      - Ajouter une routine ConvertYUV444ToYUV420(Source,Dest) qui copie le
        plan Y tel quel et calcule les plans U/V a demi-resolution.
      - Pour chaque echantillon chroma 4:2:0, moyenner le bloc 2x2 de U et V
        correspondant : (a+b+c+d+2) div 4 pour un arrondi entier symetrique.
      - Gerer les largeurs et hauteurs impaires : au bord droit ou inferieur,
        reutiliser le dernier pixel disponible ou moyenner seulement les
        echantillons presents avec un diviseur adapte.
      - Definir explicitement le placement chroma initial : co-sited ou center.
        Pour AVIF/AV1 courant, documenter le choix et l'ecrire dans les champs
        de couleur/sequence appropries quand l'encapsulation sera ajoutee.
      - Ajouter des champs ChromaSubsamplingX et ChromaSubsamplingY dans la
        structure image afin que l'encodeur AV1 sache si le flux est 4:2:0
        ou 4:4:4.
      - Ajouter une option interne PreferredChromaFormat, avec cfYUV420 par
        defaut et cfYUV444 pour tests de precision.
      - Verifier que les strides des plans U/V en 4:2:0 sont calcules avec
        (Width+1) div 2 et (Height+1) div 2.
      - Prevoir une routine CopyYUV444ToYUV444 pour le mode sans
        sous-echantillonnage, afin de garder le meme pipeline de conversion.
      - Ajouter un test visuel simple : un motif rouge/bleu alterne doit
        montrer la perte chroma attendue en 4:2:0 mais rester stable en 4:4:4.
      - Critere de fin de l'etape : l'image BMP convertie en YUV444 peut etre
        transformee en YUV420 sans debordement, avec dimensions chroma correctes
        pour les images paires et impaires.
   5. Decouper l'image en superblocs AV1 de 64x64 ou 128x128 pixels.
      - Choisir une taille initiale de superbloc 64x64 afin de simplifier le
        premier encodeur; garder une constante AV1SuperBlockSize modifiable.
      - Ajouter une structure TAV1SuperBlock avec SBX, SBY, PixelX, PixelY,
        Width, Height, IsRightEdge et IsBottomEdge.
      - Calculer le nombre horizontal et vertical de superblocs par division
        arrondie superieure : (ImageWidth+SBSize-1) div SBSize.
      - Pour chaque superbloc, calculer Width/Height reels en tenant compte
        des bords; les blocs interieurs restent 64x64, les bords peuvent etre
        plus petits avant padding.
      - Ajouter une routine InitSuperBlockGrid(Image, SBSize) qui remplit les
        dimensions globales et verifie que SBSize vaut 64 ou 128.
      - Ajouter une routine GetSuperBlock(Grid, Index ou SBX/SBY) retournant
        les coordonnees utiles sans allouer de grande table si ce n'est pas
        necessaire en mode Turbo Pascal.
      - Definir l'ordre de parcours raster : gauche vers droite, haut vers bas,
        identique a l'ordre attendu pour une tuile simple.
      - Prevoir un champ TileIndex meme si la premiere version n'utilise qu'une
        seule tuile; cela evitera de reecrire le parcours a la TODO 9.
      - Documenter la correspondance entre superblocs luma et chroma : en 4:2:0,
        un superbloc luma 64x64 correspond a 32x32 dans U et V.
      - Ajouter des assertions/verifications de bords pour eviter tout acces
        hors des plans Y/U/V lorsque Width ou Height n'est pas multiple de 64.
      - Critere de fin de l'etape : le programme peut enumerer tous les
        superblocs d'une image et afficher/calculer leur rectangle sans lire
        au-dela des plans YUV.
   6. Gerer le padding des bords pour les dimensions non multiples des blocs.
      - Ajouter une notion de dimensions visibles (ImageWidth/ImageHeight) et
        de dimensions encodeur paddees (PaddedWidth/PaddedHeight).
      - Calculer PaddedWidth/PaddedHeight en arrondissant aux multiples de la
        taille de superbloc choisie, initialement 64.
      - Pour le plan Y, remplir les colonnes ajoutees a droite en dupliquant
        le dernier pixel valide de chaque ligne visible.
      - Pour le plan Y, remplir les lignes ajoutees en bas en dupliquant la
        derniere ligne visible deja etendue horizontalement.
      - Pour les plans U et V en YUV420, appliquer la meme logique avec les
        dimensions chroma paddees : (PaddedWidth+1) div 2 et
        (PaddedHeight+1) div 2.
      - Pour YUV444, appliquer les memes dimensions paddees que le plan Y.
      - Ajouter PadPlaneRightAndBottom(Plane, VisibleWidth, VisibleHeight,
        PaddedWidth, PaddedHeight) afin de factoriser le traitement.
      - Ne jamais modifier les dimensions visibles ecrites dans le conteneur
        AVIF; le padding sert seulement a l'encodage AV1 interne.
      - S'assurer que les predictions intra lisent les pixels paddees quand
        elles sortent de l'image visible, afin d'eviter les acces hors tampon.
      - Ajouter des tests avec des images 1x1, largeur impaire, hauteur impaire,
        et dimensions juste au-dessus de 64 pour valider tous les bords.
      - Critere de fin de l'etape : chaque superbloc, y compris ceux du bord
        droit et du bas, peut etre lu comme un bloc complet sans test special
        par pixel dans les etapes de prediction/transformee.
   7. Implementer l'en-tete Sequence Header OBU pour une image fixe.
      - Ajouter un ecrivain de bits TBitWriter capable d'ecrire des champs
        MSB-first, des flags, des valeurs fixes et les trailing bits AV1.
      - Ajouter un ecrivain LEB128 pour les tailles d'OBU, requis lorsque le
        flag obu_has_size_field est active.
      - Definir une structure TAV1SequenceConfig contenant seq_profile,
        still_picture, reduced_still_picture_header, timing_info_present_flag,
        decoder_model_info_present_flag, initial_display_delay_present_flag,
        operating_points_cnt_minus_1 et les champs de frame size.
      - Cible initiale : seq_profile=0 pour YUV420/YUV400 8 bits, still_picture=1
        et reduced_still_picture_header=1 afin de simplifier le flux image fixe.
      - Ecrire max_frame_width_minus_1 et max_frame_height_minus_1 a partir des
        dimensions visibles, pas des dimensions paddees internes.
      - Encoder color_config : high_bitdepth=0, twelve_bit=0, mono_chrome=0,
        color_description_present_flag=1, color_primaries/transfer/matrix
        coherents avec BT.709 ou BT.601, color_range selon le RangeMode.
      - Encoder subsampling_x/subsampling_y selon le format chroma : 1/1 pour
        YUV420, 0/0 pour YUV444; chroma_sample_position doit correspondre au
        choix fait a la TODO 4.
      - Desactiver les options avancees au debut : film_grain_params_present=0,
        order_hint_bits inutiles, timing info absent et operating point unique.
      - Encapsuler le payload dans un OBU_SEQUENCE_HEADER avec obu_forbidden_bit=0,
        obu_extension_flag=0 et obu_has_size_field=1.
      - Ajouter une routine WriteSequenceHeaderOBU(Config, DestBuffer) retournant
        un tampon OBU pret a inserer dans le flux AV1.
      - Valider l'OBU avec un dump hex connu pour une petite image 8x8 et verifier
        que les tailles LEB128 correspondent exactement au payload.
      - Critere de fin de l'etape : le programme sait produire un Sequence Header
        OBU autonome et coherent avec le format YUV choisi, meme sans frame OBU.
   8. Implementer l'en-tete Frame Header OBU en mode intra-only.
      - Ajouter une structure TAV1FrameConfig contenant frame_type,
        show_frame, showable_frame, error_resilient_mode, disable_cdf_update,
        allow_screen_content_tools, force_integer_mv, frame_width,
        frame_height, render_width et render_height.
      - Cible initiale : frame_type=KEY_FRAME ou INTRA_ONLY selon le chemin
        reduced_still_picture_header retenu, show_frame=1, showable_frame=0,
        show_existing_frame=0 et error_resilient_mode=1.
      - Pour une image fixe AVIF, ne pas emettre de references inter-frame :
        refresh_frame_flags doit couvrir le cas requis par la specification,
        mais aucune prediction inter ne sera encodee.
      - Ecrire les dimensions de frame visibles et verifier qu'elles ne
        depassent pas max_frame_width_minus_1/max_frame_height_minus_1 du
        Sequence Header.
      - Desactiver l'ordre temporel : order_hint absent ou minimal selon les
        flags sequence, aucune reference, aucune motion vector.
      - Fixer disable_cdf_update=1 dans la premiere version pour simplifier
        l'encodeur entropique; documenter l'impact sur la compression.
      - Configurer les outils intra minimaux : allow_intrabc=0,
        allow_high_precision_mv inutile, interpolation_filter absent, switchable
        motion mode desactive.
      - Ajouter la configuration loop filter initiale : level=0 pour commencer,
        sharpness=0, delta flags desactives afin d'eviter un filtre complexe.
      - Ajouter la configuration quantizer : base_q_idx choisi globalement,
        delta_q_y_dc/delta_q_u/delta_q_v a zero dans la premiere version.
      - Ajouter segmentation_params avec segmentation_enabled=0.
      - Ajouter tile_info minimal pour une seule tuile, coherent avec la TODO 9.
      - Encapsuler ce header dans un OBU_FRAME_HEADER ou dans un OBU_FRAME selon
        le chemin de codage retenu pour les donnees de tuile.
      - Critere de fin de l'etape : le programme peut ecrire un Frame Header OBU
        intra-only syntaxiquement coherent avec le Sequence Header, meme avant
        d'avoir encode les coefficients de blocs.
   9. Ajouter les structures de tuile (tiles) et commencer avec une seule tuile.
      - Ajouter une structure TAV1TileConfig contenant TileCols, TileRows,
        TileColsLog2, TileRowsLog2, UniformTileSpacing et ContextUpdateTileId.
      - Pour la premiere version, fixer TileCols=1 et TileRows=1 afin que toute
        l'image appartienne a une seule tuile.
      - Encoder tile_info dans le Frame Header avec uniform_tile_spacing_flag=1
        lorsque la specification le permet; sinon ecrire explicitement les
        tailles de tuiles.
      - Ajouter une structure TAV1Tile contenant TileIndex, StartSBX, EndSBX,
        StartSBY, EndSBY, StartPixelX, StartPixelY, Width et Height.
      - Pour une seule tuile, StartSBX=0, StartSBY=0, EndSBX=NumSBCols et
        EndSBY=NumSBRows, en reutilisant la grille de superblocs de la TODO 5.
      - Ajouter une routine InitSingleTile(Grid, TileConfig, Tile) qui construit
        la tuile unique sans allocation dynamique.
      - Ajouter EncodeTileGroupHeader pour ecrire le debut de groupe de tuiles
        requis par le flux AV1, meme si le groupe ne contient qu'une tuile.
      - Ajouter EncodeTileData(Tile) comme point d'entree futur vers le parcours
        superbloc -> bloc -> prediction -> transformee -> entropie.
      - Prevoir le champ tile_size_bytes_minus_1 et la logique de patch des
        tailles de tuiles si le codage exige d'ecrire la taille avant le contenu.
      - Garder les donnees de contexte CDF locales a la tuile pour pouvoir
        etendre plus tard vers plusieurs tuiles independantes.
      - Documenter la contrainte initiale : pas de parallelisme, pas de tuiles
        multiples, pas de context update complexe.
      - Critere de fin de l'etape : le Frame Header decrit une seule tuile et
        l'encodeur possede une routine de parcours qui visite tous les
        superblocs de cette tuile dans l'ordre raster.
  10. Implementer les modes de prediction intra simples : DC, vertical, horizontal.
      - Ajouter une enumeration TIntraMode avec au minimum imDC, imVertical
        et imHorizontal; garder les noms proches de la terminologie AV1.
      - Ajouter une structure TBlockContext contenant Plane, BlockX, BlockY,
        BlockWidth, BlockHeight, AvailableAbove et AvailableLeft.
      - Ajouter des tampons de reference Above[] et Left[] pour les pixels
        voisins deja reconstruits, pas seulement les pixels sources originaux.
      - Pour imVertical, predire chaque ligne du bloc avec la ligne Above; si
        Above est indisponible, utiliser une valeur neutre 128 ou la regle AV1
        applicable au bord superieur.
      - Pour imHorizontal, predire chaque colonne du bloc avec Left; si Left est
        indisponible, utiliser une valeur neutre 128 ou la regle AV1 applicable
        au bord gauche.
      - Pour imDC, calculer la moyenne des references disponibles Above et Left;
        si les deux sont absentes, utiliser 128; si une seule existe, moyenner
        uniquement cette reference.
      - Ajouter PredictBlock(Mode, Context, Plane, DestPred) qui remplit un
        tampon de prediction aux dimensions du bloc.
      - Ajouter ComputeResidual(SourceBlock, PredBlock, ResidualBlock) avec des
        entiers signes pour preparer la transformee.
      - Commencer avec des blocs fixes 4x4 ou 8x8 avant d'etendre aux tailles
        AV1 completes; documenter cette restriction dans le code.
      - Ajouter une estimation simple SAD/SSE pour comparer DC, vertical et
        horizontal, afin de choisir un mode basique avant la TODO 12.
      - Veiller a reconstruire le bloc apres quantification/dequantification
        avant de l'utiliser comme reference pour les blocs suivants.
      - Critere de fin de l'etape : sur une image grise ou un degrade simple,
        les modes DC/vertical/horizontal produisent des residuals faibles et
        les references de bord restent coherentes.
  11. Ajouter progressivement les predictions directionnelles AV1 restantes.
      - Etendre TIntraMode avec les modes directionnels AV1 principaux :
        imD45, imD67, imD113, imD135, imD157, imD203, ainsi que les variantes
        proches si l'implementation suit les angles fins d'AV1.
      - Ajouter les modes non directionnels utiles : imSmooth, imSmoothV,
        imSmoothH et imPaeth lorsque les references Above/Left sont fiables.
      - Construire un tampon de references etendu AboveLeft/Above/Left assez
        grand pour couvrir les extrapolations directionnelles au-dela du bloc.
      - Implementer l'extrapolation des references manquantes selon les regles
        AV1, afin que les modes directionnels fonctionnent aussi en bord
        d'image ou de tuile.
      - Commencer par imD45, imD135 et imD203, car ils sont plus faciles a
        verifier visuellement sur des diagonales simples.
      - Ajouter ensuite les angles intermediaires avec interpolation lineaire
        entiere entre deux echantillons de reference.
      - Utiliser une table de pentes/angles en entiers fixes pour eviter les
        calculs flottants et rester compatible Turbo Pascal.
      - Ajouter PredictDirectionalBlock(Mode, Context, Plane, DestPred) separee
        de PredictBlock afin de garder les modes simples lisibles.
      - Ajouter des images de test conceptuelles : diagonale montante,
        diagonale descendante, bandes verticales, bandes horizontales et coin
        haut-gauche contraste.
      - Comparer les modes directionnels par SAD/SSE avec les modes simples de
        la TODO 10, mais limiter d'abord le nombre de modes testes pour garder
        un temps d'encodage raisonnable.
      - Documenter les modes volontairement absents dans la premiere passe pour
        ne pas confondre un bitstream simplifie avec un encodeur AV1 complet.
      - Critere de fin de l'etape : les blocs contenant des lignes diagonales
        choisissent un mode directionnel approprie et produisent moins de
        residuel que DC/vertical/horizontal seuls.
  12. Implementer le choix de mode intra par cout distorsion simplifie.
      - Ajouter une structure TModeDecisionResult contenant BestMode, BestCost,
        Distortion, RateEstimate et éventuellement TransformSize choisie.
      - Commencer avec une metrique SAD pour la rapidite : somme des valeurs
        absolues Source-Prediction sur le bloc.
      - Ajouter ensuite SSE pour les blocs plus grands, car la somme des carres
        penalise mieux les grosses erreurs de prediction.
      - Implementer EstimateModeRate(Mode, Context):LongInt avec des couts fixes
        approximatifs pour DC, vertical, horizontal, directionnels, smooth et
        paeth, avant d'avoir le vrai cout entropique.
      - Introduire Lambda sous forme entiere fixe, par exemple Cost =
        Distortion + ((Lambda * RateEstimate) shr LambdaShift).
      - Choisir un Lambda initial derive de base_q_idx afin que la selection de
        mode devienne plus conservatrice quand la quantification augmente.
      - Ajouter TestIntraMode(Mode, Context) qui appelle PredictBlock,
        ComputeResidual, optionnellement une transformee approximative, puis
        retourne le cout.
      - Limiter la liste des modes candidats selon la taille du bloc et les
        references disponibles pour eviter un encodeur trop lent.
      - Ajouter un chemin fast mode : tester seulement DC/vertical/horizontal
        pour les premieres validations, puis activer les modes directionnels
        par option interne.
      - Stocker le mode choisi dans une carte de blocs afin que l'ecriture du
        bitstream puisse encoder les symboles de prediction plus tard.
      - Verifier que le choix de mode utilise les pixels reconstruits comme
        references, pas les pixels sources originaux, sinon le decodeur ne
        reproduira pas la meme prediction.
      - Critere de fin de l'etape : pour chaque bloc encode, le programme
        choisit un mode intra deterministe et conserve assez d'information pour
        ecrire ce choix dans le flux AV1.
  13. Implementer les transformees entieres AV1 : DCT, ADST et identity.
      - Ajouter une enumeration TTransformType avec au minimum txDCT_DCT,
        txADST_DCT, txDCT_ADST, txADST_ADST et txIdentity.
      - Ajouter des tampons signes pour les coefficients de residu et les
        coefficients transformes, en LongInt pour eviter les debordements.
      - Commencer par une DCT entiere 4x4 separable : transformation horizontale
        puis verticale, avec coefficients fixes et decalages documentes.
      - Ajouter ensuite ADST 4x4, puis identity, afin de pouvoir comparer les
        blocs avec textures, contours et aplats.
      - Garder les constantes de transformee dans des tables entieres, sans
        flottants, compatibles Turbo Pascal.
      - Ajouter ForwardTransform(BlockResidual, TxType, TxSize, Coeffs) et
        InverseTransform(Coeffs, TxType, TxSize, ReconResidual) pour valider
        la boucle encodeur/decodeur.
      - Verifier la normalisation : la transformee inverse suivie de la directe
        avec quantification nulle doit reconstruire le residu avec une erreur
        controlee et documentee.
      - Prevoir la selection separee des types horizontaux et verticaux, comme
        dans AV1, meme si la premiere version limite la matrice des choix.
      - Ajouter une transformee identity pour les blocs tres nets ou petits,
        pratique pour les tests avant l'implementation complete de DCT/ADST.
      - Ajouter des tests de blocs simples : tout zero, impulsion unique, rampe
        horizontale, rampe verticale et damier.
      - Ne pas ecrire les coefficients dans le bitstream a cette etape; se
        limiter a produire un tableau de coefficients coherent pour la
        quantification de la TODO 15.
      - Critere de fin de l'etape : un bloc de residus peut etre transforme
        puis inversement transforme de facon deterministe avec des entiers fixes.
  14. Ajouter les tailles de transformees 4x4, 8x8, 16x16 et 32x32.
      - Ajouter une enumeration TTransformSize avec tx4x4, tx8x8, tx16x16
        et tx32x32 pour les tailles carrees initiales.
      - Ajouter ensuite les tailles rectangulaires AV1 utiles seulement apres
        validation des tailles carrees : 4x8, 8x4, 8x16, 16x8, 16x32, 32x16.
      - Commencer l'encodage avec tx4x4 pour simplifier le debug des
        coefficients, puis activer tx8x8 comme taille par defaut pour les
        blocs luma ordinaires.
      - Definir GetTransformWidth(TxSize) et GetTransformHeight(TxSize) afin
        d'eviter les constantes dispersees dans l'encodeur.
      - Adapter les tampons de residus/coefs pour contenir au moins 32x32
        coefficients signes.
      - Ajouter SplitBlockIntoTransforms(BlockSize, PreferredTxSize) qui
        decoupe un bloc de prediction en un ou plusieurs blocs de transformee.
      - Interdire les transformees qui depassent le bord visible non padde ou
        la taille du bloc courant; utiliser le padding de la TODO 6 pour les
        lectures mais garder des dimensions syntaxiques valides.
      - Ajouter une selection simple de taille : tx4x4 pour details forts,
        tx8x8 pour blocs moyens, tx16x16/tx32x32 pour aplats ou gradients.
      - Prevoir le codage syntaxique de la taille de transformee dans la carte
        de blocs, car le decodeur devra reconstruire le meme decoupage.
      - Tester chaque taille avec un bloc zero, un bloc constant non zero, une
        rampe et un damier afin de verifier les index de coefficients.
      - Critere de fin de l'etape : les transformees 4x4, 8x8, 16x16 et 32x32
        peuvent etre appliquees a des residus sans debordement ni inversion
        d'indices, et leur taille choisie est stockee pour l'ecriture AV1.
  15. Implementer la quantification et dequantification AV1.
      - Ajouter une structure TQuantConfig contenant base_q_idx,
        delta_q_y_dc, delta_q_u_dc, delta_q_u_ac, delta_q_v_dc, delta_q_v_ac
        et use_separate_uv_delta_q.
      - Commencer avec base_q_idx fixe, par exemple 96 ou 128, puis exposer
        plus tard un parametre qualite utilisateur.
      - Ajouter les tables ou fonctions de pas de quantification AV1 pour 8 bits,
        separees pour DC et AC lorsque la specification l'exige.
      - Implementer QuantizeCoeff(Coeff, QStep):SmallInt avec arrondi entier
        symetrique autour de zero.
      - Implementer DequantizeCoeff(QCoeff, QStep):LongInt pour reconstruire
        les coefficients avant l'inverse transformee.
      - Traiter separement le coefficient DC et les coefficients AC, car leurs
        deltas et contextes AV1 ne sont pas identiques.
      - Ajouter QuantizeBlock(Coeffs, TxSize, Plane, QuantConfig, QCoeffs) et
        DequantizeBlock(QCoeffs, TxSize, Plane, QuantConfig, DequantCoeffs).
      - Ajouter un clamp des coefficients quantifies aux plages syntaxiques
        autorisees, afin de ne pas produire de valeurs impossibles a coder.
      - Calculer EOB (End Of Block) apres quantification : dernier coefficient
        non nul dans l'ordre de scan de la transformee.
      - Ajouter les ordres de scan des coefficients au moins pour 4x4 et 8x8,
        puis etendre aux tailles de la TODO 14.
      - Verifier la reconstruction : Source -> Prediction -> Residual ->
        Transform -> Quantize -> Dequantize -> InverseTransform -> Reconstructed.
      - Critere de fin de l'etape : chaque bloc produit des coefficients
        quantifies, un EOB coherent, et un bloc reconstruit utilisable comme
        reference pour les predictions suivantes.
  16. Gerer les segments, skip, quantizer index et loop filter minimal.
      - Ajouter une structure TSegmentationConfig avec SegmentationEnabled,
        UpdateMap, UpdateData et un tableau de features par segment, meme si
        la premiere version garde SegmentationEnabled=0.
      - Ajouter une constante DefaultSegmentId=0 et stocker SegmentId dans la
        carte de blocs afin de preparer les futures optimisations locales.
      - Implementer le flag skip pour les blocs dont tous les coefficients
        quantifies sont nuls apres EOB; ces blocs ne doivent pas ecrire de
        coefficients inutiles.
      - Ajouter une structure TBlockSyntaxInfo contenant Skip, SegmentId,
        TxSize, TxType, IntraMode, QuantizerIndex et EOB.
      - Fixer quantizer index globalement depuis TQuantConfig.base_q_idx dans
        la premiere version; ne pas activer delta_q par bloc avant d'avoir un
        bitstream stable.
      - Ajouter la syntaxe delta_q_present_flag=0 initialement dans le Frame
        Header, puis documenter comment l'activer plus tard.
      - Ajouter une structure TLoopFilterConfig contenant FilterLevelY,
        FilterLevelU, FilterLevelV, Sharpness, ModeRefDeltaEnabled et
        ModeRefDeltaUpdate.
      - Pour la premiere version, fixer tous les niveaux de loop filter a 0
        afin de rendre la reconstruction plus simple et de faciliter le debug.
      - Prevoir ApplyLoopFilter comme routine vide/no-op au debut, appelee quand
        meme dans le pipeline pour garder l'ordre encodeur/decodeur correct.
      - Verifier que les pixels reconstruits utilises comme references intra
        correspondent au chemin sans loop filter lorsque les niveaux valent 0.
      - Ajouter des compteurs de blocs skip/non-skip pour diagnostiquer les
        effets de la quantification.
      - Critere de fin de l'etape : chaque bloc possede ses infos syntaxiques
        minimales, les blocs vides sont marques skip, et le loop filter peut
        etre desactive proprement sans casser la reconstruction.
  17. Implementer le codage des coefficients avec les contextes AV1.
      - Ajouter une structure TCoeffCodingContext contenant Plane, TxSize,
        TxType, EOB, ScanOrder, IsInter=False et les contextes voisins
        necessaires au codage intra.
      - Implementer les ordres de scan AV1 pour chaque taille de transformee
        supportee, en commencant par 4x4 et 8x8.
      - Ecrire d'abord le symbole EOB dans le contexte approprie, car il
        determine combien de coefficients doivent etre lus par le decodeur.
      - Parcourir les coefficients quantifies dans l'ordre de scan inverse ou
        direct selon la syntaxe AV1 retenue, en respectant les categories de
        position et de niveau.
      - Separer le codage du signe et de la magnitude : magnitude avec contextes
        de niveau, signe avec bit brut ou contexte specifique selon la syntaxe.
      - Ajouter des fonctions de contexte simplifiees :
        GetCoeffBaseContext, GetCoeffBrContext et GetEOBContext, meme si elles
        retournent d'abord des valeurs approximatives.
      - Gerer les coefficients de faible niveau (base range) avant les extra
        bits des coefficients plus grands.
      - Ajouter un chemin debug qui ecrit les symboles dans une liste textuelle
        ou structure interne avant de les envoyer au range coder.
      - Verifier que les blocs skip n'appellent pas le codage des coefficients
        et que les blocs EOB=0 sont representes correctement.
      - Garder les contextes separes par plan Y/U/V et par taille de transformee
        afin d'eviter une impasse quand les CDF reelles seront ajoutees.
      - Ajouter des tests sur blocs avec un seul DC non nul, un seul AC non nul,
        plusieurs AC et coefficients negatifs.
      - Critere de fin de l'etape : les coefficients quantifies d'un bloc sont
        convertis en une sequence de symboles AV1 coherente, prete a etre
        encodee par le range coder/CDF de la TODO 18.
  18. Implementer le range coder/entropy coder AV1 avec CDF adaptatives.
      - Ajouter une structure TAV1RangeEncoder contenant Low, Range, Count,
        Buffer, BufferSize, Position et les bits/bytes en attente.
      - Implementer l'initialisation du range coder selon la syntaxe AV1, avec
        range initial correct et tampon de sortie vide.
      - Ajouter EncodeBool(Value, Probability) seulement comme aide de debug;
        le flux AV1 reel doit passer par les CDF multi-symboles.
      - Ajouter EncodeSymbol(Symbol, CDF, SymbolCount) qui met a jour le range
        et emet les octets normalises.
      - Ajouter FinishRangeEncoder pour vider les bits restants et aligner la
        fin de la tuile selon les exigences AV1.
      - Definir les CDF initiales minimales pour les symboles que les TODO 16
        et 17 emettent : skip, intra mode, tx size, eob et niveaux de coeffs.
      - Ajouter UpdateCDF(CDF, Symbol) avec adaptation progressive; permettre
        aussi un mode disable_cdf_update=1 qui laisse les CDF fixes.
      - Stocker les CDF par contexte, plan et taille de transformee, meme si
        plusieurs contextes partagent d'abord les memes valeurs initiales.
      - Ajouter un mode trace qui journalise Symbol, ContextId, CDF avant/apres
        et octets produits, afin de comparer avec un decodeur de reference.
      - Verifier que le range coder produit exactement les memes octets pour
        une sequence de symboles fixe entre deux executions.
      - Ajouter des tests unitaires internes conceptuels : encodage d'une suite
        de symboles constants, alternes, puis distribution non uniforme.
      - Critere de fin de l'etape : les symboles de blocs peuvent etre convertis
        en octets de tuile par un range coder deterministe, avec ou sans mise a
        jour adaptative des CDF.
  19. Ecrire les OBU avec leb128, trailing bits et alignement requis.
      - Ajouter une enumeration TOBUType avec les valeurs AV1 utiles :
        OBU_SEQUENCE_HEADER, OBU_FRAME_HEADER, OBU_TILE_GROUP, OBU_FRAME et
        OBU_METADATA si necessaire plus tard.
      - Ajouter WriteLEB128(Value, DestBuffer) pour encoder les tailles de
        payload OBU, avec verification que la valeur tient dans la limite AV1.
      - Ajouter WriteOBUHeader(OBUType, HasExtension, HasSizeField) qui ecrit
        obu_forbidden_bit=0, obu_type, obu_extension_flag et obu_has_size_field.
      - Garder obu_has_size_field=1 pour tous les OBU de la premiere version,
        afin de simplifier le parsing et l'insertion dans av1C/mdat.
      - Ajouter WriteOBU(OBUType, PayloadBuffer, PayloadSize, OutputBuffer) qui
        assemble header, taille LEB128 et payload.
      - Ajouter AddTrailingBits(BitWriter) : ecrire un bit 1 puis des zeros
        jusqu'a l'alignement octet, comme exige par les structures AV1.
      - S'assurer que les payloads issus du bit writer sont finalises avec les
        trailing bits avant de calculer la taille LEB128.
      - Pour le Tile Group, distinguer les octets produits par le range coder
        des bits de header; le range coder possede ses propres regles de fin.
      - Ajouter une structure TAV1Bitstream contenant une liste/sequence d'OBU :
        SequenceHeader, FrameHeader ou Frame, TileGroup.
      - Verifier que l'ordre initial des OBU est correct pour une still picture :
        Sequence Header puis Frame/Frame Header + Tile Group selon le choix de
        packaging.
      - Ajouter un dump hex optionnel des OBU avec offset, type et taille pour
        faciliter la comparaison avec des fichiers AV1 de reference.
      - Critere de fin de l'etape : le programme peut produire une suite d'OBU
        bien formee au niveau conteneur AV1, meme si le contenu de tile reste
        encore minimal ou non decodable.
  20. Produire un bitstream AV1 decodable pour une image grise de test.
      - Definir un mode de test interne EncodeGrayTestFrame qui ignore le BMP
        et produit une petite image Y seule, par exemple 8x8 ou 16x16.
      - Configurer le Sequence Header en monochrome lorsque ce mode est actif :
        mono_chrome=1, pas de plans U/V, profil compatible 8 bits.
      - Utiliser une image source grise constante (Y=128) pour obtenir des
        residuals nuls avec une prediction DC correcte.
      - Encoder un seul superbloc ou un petit nombre de blocs 4x4 afin de
        limiter la quantite de syntaxe a verifier.
      - Forcer le mode intra DC et tx4x4 pour tous les blocs dans ce test.
      - Forcer skip=1 lorsque les coefficients quantifies sont tous nuls, afin
        de tester le chemin le plus court d'un bloc decodable.
      - Produire Sequence Header OBU, Frame Header OBU et Tile Group OBU dans
        l'ordre exact attendu par un decodeur AV1.
      - Encapsuler temporairement le flux AV1 brut dans un fichier de debug
        optionnel avant l'etape ISO-BMFF, pour faciliter les tests avec des
        outils AV1 bas niveau.
      - Ajouter ensuite une encapsulation AVIF minimale autour de cette image
        grise pour tester les decodeurs AVIF grand public.
      - Comparer le resultat avec au moins deux decodeurs : un decodeur AV1/AVIF
        tolerant et un outil strict, puis noter les erreurs syntaxiques restantes.
      - Garder ce mode de test comme regression permanente : si une etape future
        casse l'image grise, revenir corriger l'encodeur avant d'ajouter la couleur.
      - Critere de fin de l'etape : un fichier produit par le programme est
        reconnu par un decodeur AV1/AVIF comme une image grise valide.
  21. Etendre le bitstream aux trois plans Y, U et V.
      - Desactiver mono_chrome dans le Sequence Header et declarer le format
        chroma choisi, initialement YUV420 8 bits.
      - Adapter le parcours des blocs pour encoder d'abord le plan Y, puis les
        plans U et V aux dimensions chroma correspondantes.
      - Pour YUV420, utiliser des blocs chroma de dimensions reduites par rapport
        au luma et verifier la correspondance superbloc luma -> zone chroma.
      - Ajouter des contextes de prediction separes pour Y, U et V, car les
        references reconstruites et les statistiques ne sont pas partagees.
      - Autoriser des modes intra chroma simples au debut : DC pour U/V, puis
        reutilisation/derivation du mode luma lorsque le pipeline est stable.
      - Appliquer quantification et dequantification avec les deltas U/V prevus
        dans TQuantConfig, meme s'ils valent zero dans la premiere version.
      - Adapter le codage des coefficients aux contextes chroma : plan id,
        taille de transformee et EOB doivent etre transmis correctement.
      - Reconstruire les plans U/V et les stocker, comme pour Y, afin que les
        references intra chroma soient disponibles pour les blocs suivants.
      - Ajouter une image de test couleur simple : aplats rouge, vert, bleu et
        gris neutre, pour detecter les inversions U/V ou erreurs de range.
      - Verifier que les fichiers YUV420 produits n'affichent pas de dominante
        coloree sur les zones grises, signe classique d'un offset chroma faux.
      - Garder un mode YUV444 de debug pour isoler les erreurs dues au
        sous-echantillonnage 4:2:0.
      - Critere de fin de l'etape : le bitstream encode les trois plans et un
        decodeur affiche une image couleur reconnaissable, meme avec une
        compression encore peu optimisee.
  22. Ajouter l'encapsulation AVIF ISO-BMFF : ftyp, meta, hdlr, pitm, iloc, iinf.
      - Ajouter des routines WriteBoxHeader(Size, FourCC) et BeginBox/EndBox
        permettant de patcher la taille d'une box apres ecriture de son contenu.
      - Ecrire ftyp avec major_brand='avif', minor_version=0 et compatible
        brands au minimum 'avif', 'mif1' et 'miaf'.
      - Ajouter une box meta complete avec version/flags, puis les sous-boxes
        requises pour declarer l'image primaire.
      - Ecrire hdlr dans meta avec handler_type='pict' et un nom lisible comme
        'CloneDRAW AVIF'.
      - Ecrire pitm pour indiquer l'item id de l'image primaire, initialement 1.
      - Ecrire iinf avec une seule entree infe de type item 'av01' ou type
        approprie selon la variante AVIF retenue.
      - Ecrire iloc pour lier l'item id 1 a l'emplacement des donnees AV1 dans
        mdat, avec offset_size et length_size choisis assez grands (4 ou 8).
      - Prevoir la correction des offsets iloc apres ecriture de mdat, car la
        position finale des donnees n'est connue qu'a la fin.
      - Ajouter iprp/ipco/ipma a cette etape ou reserver leur ajout a la TODO
        23; au minimum, l'architecture doit permettre d'associer les proprietes
        a l'item primaire.
      - Ecrire mdat contenant le flux AV1/OBU complet produit par les TODO 19
        a 21.
      - Verifier l'ordre des boxes : ftyp avant meta/mdat, et offsets iloc
        corrects quelle que soit la taille de meta.
      - Critere de fin de l'etape : un outil ISO-BMFF peut lister ftyp, meta,
        hdlr, pitm, iinf, iloc et mdat avec des tailles/offsets coherents.
  23. Ajouter les proprietes AVIF : ispe, pixi, av1C, colr, clap si necessaire.
      - Ajouter la box iprp dans meta, contenant ipco (proprietes) et ipma
        (associations entre l'item image et ses proprietes).
      - Ecrire ispe avec version/flags=0, ImageWidth et ImageHeight visibles,
        pas les dimensions paddees de l'encodeur AV1.
      - Ecrire pixi avec le nombre de canaux et leur profondeur : 3 canaux de
        8 bits pour YUV couleur, ou 1 canal de 8 bits pour le test monochrome.
      - Ecrire av1C avec marker=1, version=1, seq_profile, seq_level_idx_0,
        seq_tier_0, high_bitdepth, twelve_bit, monochrome, chroma_subsampling_x,
        chroma_subsampling_y, chroma_sample_position et initial_presentation_delay.
      - S'assurer que av1C correspond exactement au Sequence Header OBU, sinon
        certains decodeurs rejetteront le fichier avant meme de lire mdat.
      - Ecrire colr en mode nclx avec color_primaries,
        transfer_characteristics, matrix_coefficients et full_range_flag issus
        des choix de la TODO 3.
      - Ajouter clap seulement si un recadrage visible different du canvas encode
        est necessaire; sinon omettre clap pour garder le fichier minimal.
      - Associer les proprietes a l'item primaire via ipma dans l'ordre :
        ispe, pixi, av1C, colr, et marquer comme essentielles celles que la
        specification exige de traiter.
      - Prevoir une table TItemProperty avec PropertyIndex, FourCC,
        IsEssential et Offset pour faciliter l'ecriture ipma.
      - Verifier que les index ipma commencent a 1 et correspondent a l'ordre
        d'ecriture dans ipco.
      - Ajouter un dump de debug listant les proprietes associees a l'item 1.
      - Critere de fin de l'etape : un inspecteur AVIF voit l'item primaire avec
        ispe, pixi, av1C et colr correctement associes.
  24. Ecrire mdat et relier correctement les offsets/tailles dans iloc.
      - Centraliser l'ecriture des donnees AV1 dans une routine
        WriteAVIFMdat(AV1Data, AV1Size, Var DataOffset, Var DataLength) qui
        retourne l'offset absolu du premier octet utile dans mdat, pas l'offset
        du debut de la box.
      - Calculer DataOffset comme position_fichier_de_mdat + taille_entete_mdat;
        pour une box mdat classique, l'entete vaut 8 octets, mais prevoir le
        cas future d'une large size a 16 octets si le fichier depasse 4 Gio.
      - Ecrire d'abord une box mdat avec taille connue lorsque AV1Size tient
        dans un LongInt positif : size=8+AV1Size, type='mdat', puis le flux OBU
        complet produit par les etapes 19 a 21.
      - Refuser proprement AV1Size=0, car iloc ne doit jamais pointer vers une
        etendue vide pour l'image primaire.
      - Garder iloc en version 0 ou 1 avec offset_size=4 et length_size=4 tant
        que les offsets et longueurs tiennent sur 32 bits; basculer vers une
        variante 64 bits seulement si necessaire sous Free Pascal.
      - Dans iloc, declarer item_ID=1, construction_method=0, data_reference_index=0,
        extent_count=1, extent_offset=DataOffset et extent_length=DataLength.
      - Corriger les offsets iloc apres ecriture finale de meta/mdat lorsque
        la taille de meta a change a cause de iprp/ipco/ipma ou d'autres boxes
        ajoutees par la TODO 23.
      - Prevoir deux strategies compatibles Turbo Pascal : soit construire le
        fichier en deux passes avec les tailles deja connues, soit reserver les
        champs extent_offset/extent_length puis revenir les patcher par Seek.
      - Ajouter des positions de patch explicites dans une structure
        TAVIFIlocPatchInfo : OffsetFieldPos, LengthFieldPos, OffsetSize,
        LengthSize, MdatDataOffset et MdatDataLength.
      - Verifier avant patch que OffsetFieldPos et LengthFieldPos pointent bien
        dans la box iloc, afin d'eviter de modifier une autre box si la
        structure meta evolue.
      - Ecrire les entiers ISO-BMFF en big-endian, y compris les champs iloc,
        meme si le programme tourne sur une machine little-endian.
      - S'assurer que l'offset ecrit dans iloc est absolu depuis le debut du
        fichier, pas relatif a meta ni a mdat.
      - Apres patch, relire optionnellement les champs iloc en mode debug pour
        afficher item_ID, extent_offset, extent_length et verifier que
        extent_offset+extent_length ne depasse pas la taille finale du fichier.
      - Ajouter une verification croisee : la longueur iloc doit etre exactement
        la taille du flux AV1/OBU insere dans mdat, sans inclure les 8 octets
        de l'entete mdat.
      - Verifier que mdat peut etre place apres meta dans la premiere version;
        si mdat est deplace avant meta plus tard, recalculer iloc et documenter
        l'ordre choisi.
      - Eviter d'ajouter des octets de padding non declares entre l'entete mdat
        et le flux AV1; si un padding devient necessaire, il doit etre inclus
        dans une box separee ou pris en compte explicitement dans iloc.
      - Critere de fin de l'etape : un inspecteur ISO-BMFF lit iloc item 1 avec
        un extent_offset pointant sur le premier octet OBU dans mdat, une
        extent_length egale a la taille du bitstream AV1, et aucun depassement
        par rapport a la taille reelle du fichier.
  25. Valider avec plusieurs decodeurs AVIF et ajouter des tests de non-regression.
      - Constituer un petit jeu de BMP de reference couvrant les cas limites :
        1x1, 2x2, largeur impaire, hauteur impaire, 64x64, 65x65, image avec
        palette, 24 bits, 32 bits, degrade gris, aplats RGB et motif alternant.
      - Pour chaque image de reference, produire un AVIF et verifier que le
        programme termine avec code de sortie 0, cree un fichier non vide et
        n'ecrit aucune erreur inattendue.
      - Valider chaque fichier avec au moins deux decodeurs independants, par
        exemple libavif/avifdec et FFmpeg, afin de detecter les interpretations
        trop tolerantes d'un seul outil.
      - Ajouter une validation structurelle ISO-BMFF : lister ftyp, meta, hdlr,
        pitm, iloc, iinf, iprp, ipco, ipma et mdat, puis verifier que les tailles
        et offsets ne depassent jamais la taille reelle du fichier.
      - Ajouter une validation AVIF : confirmer que l'item primaire est bien
        l'item 1, que son type est av01, que ispe correspond aux dimensions BMP,
        que pixi, av1C et colr sont presents et associes par ipma.
      - Ajouter une validation AV1 : verifier que le flux mdat commence par un
        OBU Sequence Header valide, contient les OBU attendus dans l'ordre, et
        que les tailles LEB128 correspondent aux payloads reels.
      - Comparer les dimensions decodees avec les dimensions BMP d'origine pour
        detecter les erreurs de padding, de recadrage ou d'utilisation des
        dimensions paddees dans le conteneur.
      - Pour les images grises et les aplats neutres, verifier que les canaux
        U/V restent neutres apres decodage afin de detecter les inversions U/V,
        les erreurs de range ou les mauvais coefficients de matrice.
      - Pour les images couleur simples, calculer une tolerance d'erreur par
        canal adaptee a l'encodage avec pertes; documenter la tolerance initiale
        et la resserrer lorsque l'encodeur devient plus stable.
      - Ajouter un mode de test reproductible avec quantification fixe, CDF
        desactivees ou initialisees deterministement, et aucun parametre dependant
        de l'heure ou de l'environnement.
      - Ajouter un dump de debug optionnel listant le checksum BMP source, la
        taille du bitstream AV1, les offsets iloc, les proprietes iprp et les
        tailles de boxes principales.
      - Conserver des checksums ou empreintes des AVIF produits seulement pour
        les modes strictement deterministes; sinon comparer les sorties decodees
        plutot que les octets du fichier.
      - Tester les chemins d'erreur : BMP compresse, dimensions invalides,
        largeur trop grande pour le tampon, palette incomplete, bit depth non
        supporte et echec d'ecriture du fichier cible.
      - Ajouter des tests specifiques aux bords : dimensions impaires en YUV420,
        image juste au-dessus d'un superbloc, derniere ligne BMP top-down et
        bottom-up, et duplication de pixels lors du padding.
      - Verifier la compatibilite Turbo Pascal 7 et Free Pascal 3.2 : pas de
        dependance a des types 64 bits dans le chemin TP7 obligatoire, sauf dans
        des sections protegees par directives de compilation.
      - Documenter dans les commentaires ou dans un fichier de test les versions
        des decodeurs utilises, car les decodeurs AVIF evoluent et certains
        diagnostics changent avec le temps.
      - Ajouter une cible ou un script de regression simple lorsque le depot en
        possede deja le style : compiler BMP2AVIF, generer les fichiers de test,
        lancer les validateurs disponibles et resumer les echecs.
      - Faire echouer la regression si un fichier AVIF devient indecodable, si
        une box obligatoire disparait, si iloc pointe ailleurs que dans mdat, ou
        si les dimensions visibles changent.
      - Garder quelques fichiers AVIF minimaux produits par des encodeurs de
        reference comme cas de comparaison structurelle, sans les melanger avec
        les fichiers generes par BMP2AVIF.
      - Critere de fin de l'etape : les AVIF generes par le programme sont
        acceptes par plusieurs decodeurs, leurs boxes ISO-BMFF et proprietes
        AVIF sont coherentes, les images decodees correspondent aux BMP sources
        dans la tolerance documentee, et les regressions peuvent etre relancees
        automatiquement apres chaque modification de l'encodeur.
}

Program BMP2AVIF;

{$A-}

Uses DOS;

Const
 bi_RGB=0;
 MaxLineBytes=16384;
 AVIFInitialBitDepth=8;
 AVIFInitialSeqProfile=0;
 AVIFInitialItemID=1;
 AVIFInitialChromaSubX=1;
 AVIFInitialChromaSubY=1;
 AVIFInitialChromaSamplePosition=0; {Moyenne 2x2 centree, a propager en AV1/AVIF.}
 AVIFInitialColorPrimaries=1;      {BT.709}
 AVIFInitialTransfer=13;           {sRGB}
 AVIFInitialMatrixCoefficients=1;  {BT.709}
 AVIFMaxPlaneBytes=1048576;
 AVIFMaxFileBytes=1048576;
 AVIFMaxItemProperties=8;
 AV1MaxOBUBytes=1048576;
 AV1SuperBlockSize=64;
 AV1IntraBlockSize=8;
 AV1MaxTransformSize=32;
 AV1MaxTransformUnits=64;
 AV1MaxModeDecisionBlocks=16384;
 AV1MaxPartitionNodes=65520;
 AV1MaxNormativeModeBlocks=65520;
 AV1MaxNormativeTransformUnits=65520;
 AV1MaxNormativeCoeffUnits=65520;
 AV1MaxCoeffSymbols=65520;
 AV1PartitionContexts=4;
 AV1SkipContexts=3;
 AV1ModeContexts=4;
 AV1UVModeContexts=3;
 AV1TxSizeContexts=4;
 AV1TxTypeContexts=4;
 AV1TxSplitContexts=3;
 AV1EOBContexts=4;
 AV1CoeffBaseContexts=8;
 AV1CoeffExtraContexts=4;
 AV1CoeffSignContexts=2;
 DefaultSegmentId=0;
 AV1LambdaShift=4;
 AVIFRequireStandardAV1Bitstream=True;

Type
 TAVIFInputFormat=(aifBMP);
 TAVIFImageKind=(aikStillImage);
 TAVIFProfile=(apMain);
 TAVIFChromaFormat=(acfYUV420,acfYUV444);
 TColorMatrixMode=(cmBT601,cmBT709);
 TRangeMode=(rmFullRange,rmLimitedRange);
 TAVIFContainerKind=(ackISOBaseMediaFileFormat);
 TAV1TileEntropyPath=(ateExperimentalStructure,ateNormativeAV1);
 TAV1BuiltInStage=(absSequenceHeader,absFrameHeader,absContainer,
  absTileSyntax,absPartitionSyntax,absModeSyntax,absTransformTreeSyntax,
  absCoefficientSyntax,absCDFTables,absBoolRangeCoder,absContextModels,
  absExternalDecoderConformance,absDecoderValidation);
 TAV1BuiltInStageSet=Set of TAV1BuiltInStage;
 TAV1PartitionType=(aptNone,aptHorizontal,aptVertical,aptSplit);
 TAVIFByteArray=Array[0..AVIFMaxPlaneBytes-1]of Byte;
 PAVIFByteArray=^TAVIFByteArray;
 TAV1OBUType=(obuReserved0,obuSequenceHeader,obuTemporalDelimiter,
  obuFrameHeader,obuTileGroup,obuMetadata,obuFrame,obuRedundantFrameHeader,
  obuTileList,obuPadding);

 TAV1ByteBuffer=Record
  Data:PAVIFByteArray;
  Size,Capacity:LongInt;
 End;

 TAV1Bitstream=Record
  SequenceHeader:TAV1ByteBuffer;
  FrameHeader:TAV1ByteBuffer;
  TileGroup:TAV1ByteBuffer;
  Combined:TAV1ByteBuffer;
 End;

 TAVIFIlocPatchInfo=Record
  OffsetFieldPos,LengthFieldPos:LongInt;
  OffsetSize,LengthSize:Byte;
  IlocBoxStart,IlocBoxEnd:LongInt;
  MdatBoxOffset:LongInt;
  MdatHeaderSize:Byte;
  MdatDataOffset,MdatDataLength:LongInt;
 End;

 TAVIFContainer=Record
  FileData:TAV1ByteBuffer;
  IlocPatch:TAVIFIlocPatchInfo;
 End;

 TISOBoxWriter=Record
  Buffer:^TAV1ByteBuffer;
  Failed:Boolean;
 End;

 TItemProperty=Record
  PropertyIndex:Byte;
 FourCC:String[4];
 IsEssential:Boolean;
  Offset:LongInt;
 End;

 TItemPropertyTable=Record
  Count:Byte;
  Items:Array[1..AVIFMaxItemProperties]of TItemProperty;
 End;

 TBitWriter=Record
  Buffer:^TAV1ByteBuffer;
  CurrentByte:Byte;
  BitCount:Byte;
  Failed:Boolean;
 End;

 TBitReader=Record
  Buffer:^TAV1ByteBuffer;
  Pos,EndPos:LongInt;
  BitOffset:Byte;
  Failed:Boolean;
 End;

 TAVIFEncoderOptions=Record
  InputFormat:TAVIFInputFormat;
  ImageKind:TAVIFImageKind;
  Profile:TAVIFProfile;
  ChromaFormat:TAVIFChromaFormat;
  RangeMode:TRangeMode;
  MatrixMode:TColorMatrixMode;
  ContainerKind:TAVIFContainerKind;
  BitDepth:Byte;
  HasAlpha:Boolean;
  HasHDR:Boolean;
  HasAnimation:Boolean;
  HasEXIF:Boolean;
  HasXMP:Boolean;
  HasICC:Boolean;
  StillPicture:Boolean;
  IntraOnly:Boolean;
  SingleImageItem:Boolean;
  SingleTile:Boolean;
  FilmGrain:Boolean;
  EnableDirectionalIntra:Boolean;
 End;

 TAVIFPlane=Record
  Width,Height,Stride:Word;
  Size:LongInt;
  Data:PAVIFByteArray;
 End;

 TAVIFImage=Record
  Width,Height:Word;
  PaddedWidth,PaddedHeight:Word;
  BitDepth:Byte;
  ChromaFormat:TAVIFChromaFormat;
  RangeMode:TRangeMode;
  MatrixMode:TColorMatrixMode;
  ChromaSubsamplingX:Byte;
  ChromaSubsamplingY:Byte;
  ChromaSamplePosition:Byte;
  ColorPrimaries:Word;
  TransferCharacteristics:Word;
  MatrixCoefficients:Word;
  PlaneY,PlaneU,PlaneV:TAVIFPlane;
 End;

 TAV1SuperBlock=Record
  SBX,SBY:Word;
  PixelX,PixelY:Word;
  Width,Height:Word;
  TileIndex:Word;
  IsRightEdge,IsBottomEdge:Boolean;
 End;

 TAV1SuperBlockGrid=Record
  ImageWidth,ImageHeight:Word;
  SBSize:Word;
  NumSBCols,NumSBRows:Word;
  TotalSuperBlocks:LongInt;
 End;

 TAV1TileConfig=Record
  TileCols,TileRows:Word;
  TileColsLog2,TileRowsLog2:Byte;
  UniformTileSpacing:Boolean;
  ContextUpdateTileId:Word;
  TileSizeBytesMinus1:Byte;
 End;

 TAV1Tile=Record
  TileIndex:Word;
  StartSBX,EndSBX:Word;
  StartSBY,EndSBY:Word;
  StartPixelX,StartPixelY:Word;
  Width,Height:Word;
 End;

 TAV1SequenceConfig=Record
  SeqProfile:Byte;
  StillPicture:Boolean;
  ReducedStillPictureHeader:Boolean;
  SeqLevelIdx0:Byte;
  FrameWidthBits,FrameHeightBits:Byte;
  MaxFrameWidth,MaxFrameHeight:Word;
  Use128x128SuperBlock:Boolean;
  EnableFilterIntra:Boolean;
  EnableIntraEdgeFilter:Boolean;
  HighBitDepth:Boolean;
  MonoChrome:Boolean;
  ColorDescriptionPresent:Boolean;
  ColorPrimaries:Byte;
  TransferCharacteristics:Byte;
  MatrixCoefficients:Byte;
  ColorRange:Byte;
  SubsamplingX,SubsamplingY:Byte;
  ChromaSamplePosition:Byte;
  SeparateUVDeltAQ:Boolean;
  FilmGrainParamsPresent:Boolean;
 End;

 TAV1FrameType=(aftKeyFrame,aftInterFrame,aftIntraOnlyFrame,aftSwitchFrame);
 TIntraMode=(imDC,imVertical,imHorizontal,imD45,imD67,imD113,imD135,
  imD157,imD203,imSmooth,imSmoothV,imSmoothH,imPaeth);
 TAV1ByteBlock=Array[0..AV1IntraBlockSize-1,0..AV1IntraBlockSize-1]of Byte;
 TAV1ResidualBlock=Array[0..AV1MaxTransformSize-1,0..AV1MaxTransformSize-1]of Integer;
 TTransformSize=(txSize4x4,txSize8x8,txSize16x16,txSize32x32);
 TTransformType=(txDCT_DCT,txADST_DCT,txDCT_ADST,txADST_ADST,txIdentity);
 TTransformBlock=Array[0..AV1MaxTransformSize-1,0..AV1MaxTransformSize-1]of LongInt;
 TQuantBlock=Array[0..AV1MaxTransformSize-1,0..AV1MaxTransformSize-1]of SmallInt;

 TQuantConfig=Record
  BaseQIndex:Byte;
  DeltaQYDC,DeltaQUDC,DeltaQUAC,DeltaQVDC,DeltaQVAC:ShortInt;
  UseSeparateUVDeltAQ:Boolean;
 End;

 TTransformUnit=Record
  OffsetX,OffsetY:Byte;
  Width,Height:Byte;
  TxSize:TTransformSize;
 End;

 TTransformUnitList=Record
  Count:Byte;
  Units:Array[0..AV1MaxTransformUnits-1]of TTransformUnit;
 End;

 TModeDecisionResult=Record
  BlockX,BlockY:Word;
  BlockWidth,BlockHeight:Byte;
  BestMode:TIntraMode;
  TransformSize:TTransformSize;
  TransformType:TTransformType;
  BestCost,Distortion,RateEstimate:LongInt;
  TransformEnergy:LongInt;
  EOB:Word;
 End;

 TModeDecisionArray=Array[0..AV1MaxModeDecisionBlocks-1]of TModeDecisionResult;
 PModeDecisionArray=^TModeDecisionArray;

 TModeDecisionMap=Record
  Decisions:PModeDecisionArray;
  Count,Capacity:Word;
 End;

 TSegmentationConfig=Record
  SegmentationEnabled:Boolean;
  UpdateMap:Boolean;
  UpdateData:Boolean;
 End;

 TLoopFilterConfig=Record
  FilterLevelY,FilterLevelU,FilterLevelV:Byte;
  Sharpness:Byte;
  ModeRefDeltaEnabled:Boolean;
  ModeRefDeltaUpdate:Boolean;
 End;

 TBlockSyntaxInfo=Record
  Skip:Boolean;
  SegmentId:Byte;
  TxSize:TTransformSize;
  TxType:TTransformType;
  IntraMode:TIntraMode;
  QuantizerIndex:Byte;
  EOB:Word;
 End;

 TBlockSyntaxArray=Array[0..AV1MaxModeDecisionBlocks-1]of TBlockSyntaxInfo;
 PBlockSyntaxArray=^TBlockSyntaxArray;

 TBlockSyntaxMap=Record
  Blocks:PBlockSyntaxArray;
  Count,Capacity:Word;
  SkipCount,NonSkipCount:Word;
 End;

 TCoeffScanOrder=(csoDiagonal);
 TCoeffSymbolKind=(cskEOB,cskCoeffBase,cskCoeffExtra,cskCoeffSign);

 TCoeffCodingContext=Record
  Plane:Byte;
  TxSize:TTransformSize;
  TxType:TTransformType;
  EOB:Word;
  ScanOrder:TCoeffScanOrder;
  IsInter:Boolean;
  AboveNonZero,LeftNonZero:Boolean;
 End;

 TCoeffSymbol=Record
  Kind:TCoeffSymbolKind;
  ContextId:Byte;
  Position:Word;
  Symbol:SmallInt;
 End;

 TCoeffSymbolArray=Array[0..AV1MaxCoeffSymbols-1]of TCoeffSymbol;
 PCoeffSymbolArray=^TCoeffSymbolArray;

 TCoeffSymbolMap=Record
  Symbols:PCoeffSymbolArray;
  Count,Capacity:Word;
 End;

 TCDF=Array[0..16]of Word;

 TEntropyCDF=Record
  CDF:TCDF;
  SymbolCount:Byte;
 End;

 TEntropyModels=Record
  SkipCDF:TEntropyCDF;
  IntraModeCDF:TEntropyCDF;
  TxSizeCDF:TEntropyCDF;
  EOBCDF:TEntropyCDF;
  CoeffBaseCDF:TEntropyCDF;
  CoeffExtraCDF:TEntropyCDF;
  CoeffSignCDF:TEntropyCDF;
  DisableCDFUpdate:Boolean;
 End;

 TAV1RangeEncoder=Record
  Low,Range:LongInt;
  Count:LongInt;
  Buffer:^TAV1ByteBuffer;
  Position:LongInt;
  Failed:Boolean;
 Trace:Boolean;
 End;

 TAV1NormativeRangeEncoder=Record
  Low,Range:Int64;
  Count:LongInt;
  Cnt:LongInt;
  SymbolCount:LongInt;
  Buffer:^TAV1ByteBuffer;
  StartSize:LongInt;
  Finalized:Boolean;
  Failed:Boolean;
 End;

 { Decodeur AV1 normatif (compagnon de TAV1NormativeRangeEncoder).
   Reproduit od_ec_dec.c de libaom : fenetre 32 bits, cnt initial=-15,
   raffraichissement par octets a partir d'un buffer existant.
   Sert au self-test roundtrip et au futur decodage de tuile. }
 TAV1NormativeRangeDecoder=Record
  Dif:Int64;          { fenetre 32 bits stockee en Int64 pour eviter les pieges de signe }
  Range:LongInt;      { 0x8000..0xFFFF }
  Cnt:LongInt;        { -15..23, indique combien de bits utiles restent dans Dif }
  Buffer:^TAV1ByteBuffer;
  ReadPos:LongInt;    { prochaine position de lecture (octet) }
  EndPos:LongInt;     { fin exclusive }
  SymbolCount:LongInt;{ nombre de symboles deja decodes }
  Failed:Boolean;
 End;

 TAV1NormativeEncoderState=Record
  EntropyPath:TAV1TileEntropyPath;
 CompletedStages:TAV1BuiltInStageSet;
 FirstMissingStage:TAV1BuiltInStage;
 DecoderReady:Boolean;
 ExternalDecoderReady:Boolean;
 End;

 TAV1NormativeTilePlan=Record
  TileIndex:Word;
  StartSBX,EndSBX:Word;
  StartSBY,EndSBY:Word;
  SBCols,SBRows:Word;
  TotalSuperBlocks:LongInt;
  LumaWidth,LumaHeight:Word;
  ChromaWidth,ChromaHeight:Word;
  UsesChroma:Boolean;
  RasterOrder:Boolean;
  Valid:Boolean;
 End;

 TAV1PartitionNode=Record
  X,Y:Word;
  Size:Byte;
  Partition:TAV1PartitionType;
  IsLeaf:Boolean;
 End;

 TAV1PartitionNodeArray=Array[0..AV1MaxPartitionNodes-1]of TAV1PartitionNode;
 PAV1PartitionNodeArray=^TAV1PartitionNodeArray;
 TEntropyCDFArray4=Array[0..3]of TEntropyCDF;
 TEntropyCDFArray8=Array[0..7]of TEntropyCDF;

 TAV1PartitionMap=Record
  Nodes:PAV1PartitionNodeArray;
  Count,Capacity:Word;
  SplitCount,LeafCount:Word;
 End;

 TAV1IntraModeNode=Record
  X,Y:Word;
  Size:Byte;
  Mode:TIntraMode;
  UVMode:TIntraMode;
  SegmentId:Byte;
  Skip:Boolean;
  TxSize:TTransformSize;
 TxType:TTransformType;
 QuantizerIndex:Byte;
 End;

 TAV1SyntaxContext=Record
  AboveAvailable,LeftAvailable:Boolean;
  AboveSkip,LeftSkip:Boolean;
  AboveNonZero,LeftNonZero:Boolean;
  BlockSize:Byte;
  PlaneID:Byte;
  TxSize:TTransformSize;
  TxType:TTransformType;
  PartitionContext:Byte;
  SkipContext:Byte;
  YModeContext:Byte;
  UVModeContext:Byte;
  TxSizeContext:Byte;
  TxTypeContext:Byte;
  TxSplitContext:Byte;
  EOBContext:Byte;
  CoeffBaseContext:Byte;
  CoeffExtraContext:Byte;
  CoeffSignContext:Byte;
 End;

 TAV1IntraModeNodeArray=Array[0..AV1MaxNormativeModeBlocks-1]of TAV1IntraModeNode;
 PAV1IntraModeNodeArray=^TAV1IntraModeNodeArray;

 TAV1IntraModeMap=Record
  Nodes:PAV1IntraModeNodeArray;
  Count,Capacity:Word;
  DCCount,DirectionalCount:Word;
 End;

 TAV1TransformTreeNode=Record
  X,Y:Word;
  Width,Height:Byte;
  TxSize:TTransformSize;
  TxType:TTransformType;
  Split:Boolean;
 End;

 TAV1TransformTreeNodeArray=Array[0..AV1MaxNormativeTransformUnits-1]of TAV1TransformTreeNode;
 PAV1TransformTreeNodeArray=^TAV1TransformTreeNodeArray;

 TAV1TransformTreeMap=Record
  Nodes:PAV1TransformTreeNodeArray;
  Count,Capacity:Word;
  SplitCount,LeafCount:Word;
 End;

 TAV1CoefficientUnit=Record
  X,Y:Word;
  PlaneID:Byte;
  TxSize:TTransformSize;
  TxType:TTransformType;
  EOB:Word;
  TransformEnergy:LongInt;
  SymbolStart,SymbolCount:Word;
  HasNonZero:Boolean;
 End;

 TAV1CoefficientUnitArray=Array[0..AV1MaxNormativeCoeffUnits-1]of TAV1CoefficientUnit;
 PAV1CoefficientUnitArray=^TAV1CoefficientUnitArray;

 TAV1CoefficientUnitMap=Record
  Units:PAV1CoefficientUnitArray;
  Count,Capacity:Word;
  NonZeroCount,ZeroCount:Word;
 End;

 TAV1NormativeCDFSet=Record
  PartitionCDF:TEntropyCDF;
  SkipCDF:TEntropyCDF;
 IntraModeCDF:TEntropyCDF;
 UVModeCDF:TEntropyCDF;
 TxSizeCDF:TEntropyCDF;
 TxTypeCDF:TEntropyCDF;
 TxSplitCDF:TEntropyCDF;
 EOBCDF:TEntropyCDF;
 CoeffBaseCDF:TEntropyCDF;
 CoeffExtraCDF:TEntropyCDF;
  CoeffSignCDF:TEntropyCDF;
 PartitionCDFByContext:TEntropyCDFArray4;
 SkipCDFByContext:TEntropyCDFArray4;
 IntraModeCDFByContext:TEntropyCDFArray4;
 UVModeCDFByContext:TEntropyCDFArray4;
 TxSizeCDFByContext:TEntropyCDFArray4;
 TxTypeCDFByContext:TEntropyCDFArray4;
 TxSplitCDFByContext:TEntropyCDFArray4;
 EOBCDFByContext:TEntropyCDFArray4;
 CoeffBaseCDFByContext:TEntropyCDFArray8;
 CoeffExtraCDFByContext:TEntropyCDFArray4;
 CoeffSignCDFByContext:TEntropyCDFArray4;
  Initialized:Boolean;
 End;

 TBlockContext=Record
  PlaneID:Byte;
  BlockX,BlockY:Word;
  BlockWidth,BlockHeight:Byte;
  AvailableAbove,AvailableLeft:Boolean;
 End;

 TAV1FrameConfig=Record
  FrameType:TAV1FrameType;
  ShowExistingFrame:Boolean;
  ShowFrame:Boolean;
  ShowableFrame:Boolean;
  ErrorResilientMode:Boolean;
  DisableCDFUpdate:Boolean;
  AllowScreenContentTools:Boolean;
  ForceIntegerMV:Boolean;
  FrameWidth,FrameHeight:Word;
  RenderWidth,RenderHeight:Word;
 RefreshFrameFlags:Byte;
 BaseQIndex:Byte;
 DeltaQYDC,DeltaQUDC,DeltaQUAC,DeltaQVDC,DeltaQVAC:ShortInt;
 UsingQMatrix:Boolean;
 DeltaQPresent:Boolean;
 DeltaQResLog2:Byte;
 CDEFEnabled:Boolean;
 LoopRestorationEnabled:Boolean;
 AllowIntrABC:Boolean;
 LoopFilterLevel:Byte;
 LoopFilterSharpness:Byte;
 SegmentationEnabled:Boolean;
  TileCols,TileRows:Word;
  UniformTileSpacing:Boolean;
 End;

 RGB32=Record
  B,G,R,FreeByte:Byte;
 End;

 RGB=Record
  R,G,B:Byte;
 End;

 HeaderBMP=Record
  Sign:Array[0..1]of Char;
  Size,Reserved0,OffBits:LongInt;
  biSize,NumXPixels,NumYPixels:LongInt;
  Planes,BitCount:Word;
  Compression,SizeImage:LongInt;
  XPelsPerMeter,YPelsPerMeter,ClrUsed,ClrImportant:LongInt;
 End;

 BitmapInfoHeader=Record
  biSize:LongInt;
  biWidth:LongInt;
  biHeight:LongInt;
  biPlanes:Word;
  biBitCount:Word;
  biCompression:LongInt;
  biSizeImage:LongInt;
  biXPelsPerMeter:LongInt;
  biYPelsPerMeter:LongInt;
  biClrUsed:LongInt;
  biClrImportant:LongInt;
 End;

Var
 SourceBMP:File;
 Header:HeaderBMP;
 BIH:BitmapInfoHeader;
 Palette:Array[0..255]of RGB32;
 Buffer:Array[0..MaxLineBytes-1]of Byte;
 SourceFileName,TargetFileName:String;
 AVIFOptions:TAVIFEncoderOptions;
 BMPBytesPerLine,ByteReaded:Word;
 ImageWidth,ImageHeight,NumPal:Word;
 StartPos,BMPBPL:LongInt;
 Y:LongInt;

Procedure InitAVIFEncoderOptions(Var Options:TAVIFEncoderOptions);
Begin
 Options.InputFormat:=aifBMP;
 Options.ImageKind:=aikStillImage;
 Options.Profile:=apMain;
 Options.ChromaFormat:=acfYUV420;
 Options.RangeMode:=rmFullRange;
 Options.MatrixMode:=cmBT709;
 Options.ContainerKind:=ackISOBaseMediaFileFormat;
 Options.BitDepth:=AVIFInitialBitDepth;
 Options.HasAlpha:=False;
 Options.HasHDR:=False;
 Options.HasAnimation:=False;
 Options.HasEXIF:=False;
 Options.HasXMP:=False;
 Options.HasICC:=False;
 Options.StillPicture:=True;
 Options.IntraOnly:=True;
 Options.SingleImageItem:=True;
 Options.SingleTile:=True;
 Options.FilmGrain:=False;
 Options.EnableDirectionalIntra:=True;
End;

Procedure WriteAVIFInitialScope(Const Options:TAVIFEncoderOptions);
Begin
 WriteLn('Perimetre AVIF initial : image fixe SDR ',Options.BitDepth,' bits, sans alpha.');
 WriteLn('Profil AV1 cible      : Main profile, intra-only, still picture.');
 WriteLn('Couleur interne cible : YUV 4:2:0 8 bits, BT.709, full range.');
 WriteLn('Conteneur cible       : ISO-BMFF AVIF, un item primaire av01.');
 WriteLn('Exclusions initiales  : HDR, animation, ICC, EXIF/XMP, film grain.');
 If Options.SingleTile Then
  WriteLn('Tuiles AV1 cible      : une seule tuile pour la premiere version.');
End;

Function AVIFInitialScopeIsSupported(Const Options:TAVIFEncoderOptions):Boolean;
Begin
 AVIFInitialScopeIsSupported:=
  (Options.InputFormat=aifBMP)and
  (Options.ImageKind=aikStillImage)and
  (Options.Profile=apMain)and
  (Options.ChromaFormat=acfYUV420)and
  (Options.RangeMode=rmFullRange)and
  (Options.MatrixMode=cmBT709)and
  (Options.ContainerKind=ackISOBaseMediaFileFormat)and
  (Options.BitDepth=AVIFInitialBitDepth)and
  Options.StillPicture and Options.IntraOnly and
  Options.SingleImageItem and Options.SingleTile and
  (not Options.HasAlpha)and(not Options.HasHDR)and
  (not Options.HasAnimation)and(not Options.HasEXIF)and
  (not Options.HasXMP)and(not Options.HasICC)and(not Options.FilmGrain);
End;

Procedure InitAVIFPlane(Var Plane:TAVIFPlane);
Begin
 Plane.Width:=0;
 Plane.Height:=0;
 Plane.Stride:=0;
 Plane.Size:=0;
 Plane.Data:=Nil;
End;

Procedure InitAVIFImageRecord(Var Image:TAVIFImage);
Begin
 Image.Width:=0;
 Image.Height:=0;
 Image.PaddedWidth:=0;
 Image.PaddedHeight:=0;
 Image.BitDepth:=AVIFInitialBitDepth;
 Image.ChromaFormat:=acfYUV420;
 Image.RangeMode:=rmFullRange;
 Image.MatrixMode:=cmBT709;
 Image.ChromaSubsamplingX:=AVIFInitialChromaSubX;
 Image.ChromaSubsamplingY:=AVIFInitialChromaSubY;
 Image.ChromaSamplePosition:=AVIFInitialChromaSamplePosition;
 Image.ColorPrimaries:=AVIFInitialColorPrimaries;
 Image.TransferCharacteristics:=AVIFInitialTransfer;
 Image.MatrixCoefficients:=AVIFInitialMatrixCoefficients;
 InitAVIFPlane(Image.PlaneY);
 InitAVIFPlane(Image.PlaneU);
 InitAVIFPlane(Image.PlaneV);
End;

Function AVIFPlaneByteSize(Width,Height:Word):LongInt;
Begin
 AVIFPlaneByteSize:=LongInt(Width)*LongInt(Height);
End;

Function AllocateAVIFPlane(Var Plane:TAVIFPlane; Width,Height:Word):Boolean;
Var
 Size:LongInt;
Begin
 AllocateAVIFPlane:=False;
 InitAVIFPlane(Plane);
 Size:=AVIFPlaneByteSize(Width,Height);
 If(Width=0)or(Height=0)or(Size<=0)or(Size>AVIFMaxPlaneBytes)Then Exit;
 Plane.Width:=Width;
 Plane.Height:=Height;
 Plane.Stride:=Width;
 Plane.Size:=Size;
 GetMem(Plane.Data,Size);
 If Plane.Data=Nil Then Begin
  InitAVIFPlane(Plane);
  Exit;
 End;
 AllocateAVIFPlane:=True;
End;

Procedure FreeAVIFPlane(Var Plane:TAVIFPlane);
Begin
 If Plane.Data<>Nil Then
  FreeMem(Plane.Data,Plane.Size);
 InitAVIFPlane(Plane);
End;

Function AVIFImageFitsMemory(Width,Height:Word;ChromaFormat:TAVIFChromaFormat):Boolean;
Var
 ChromaWidth,ChromaHeight:Word;
 LumaSize,ChromaSize:LongInt;
Begin
 AVIFImageFitsMemory:=False;
 If(Width=0)or(Height=0)Then Exit;
 LumaSize:=AVIFPlaneByteSize(Width,Height);
 If(LumaSize<=0)or(LumaSize>AVIFMaxPlaneBytes)Then Exit;
 If ChromaFormat=acfYUV420 Then Begin
  ChromaWidth:=(Width+1)div 2;
  ChromaHeight:=(Height+1)div 2;
 End
  Else
 Begin
  ChromaWidth:=Width;
  ChromaHeight:=Height;
 End;
 ChromaSize:=AVIFPlaneByteSize(ChromaWidth,ChromaHeight);
 If(ChromaSize<=0)or(ChromaSize>AVIFMaxPlaneBytes)Then Exit;
 AVIFImageFitsMemory:=True;
End;

Function AllocateAVIFImagePadded(Var Image:TAVIFImage;VisibleWidth,VisibleHeight,
 PaddedWidth,PaddedHeight:Word;ChromaFormat:TAVIFChromaFormat;RangeMode:TRangeMode;
 MatrixMode:TColorMatrixMode):Boolean;
Var
 ChromaWidth,ChromaHeight:Word;
Begin
 AllocateAVIFImagePadded:=False;
 InitAVIFImageRecord(Image);
 If(PaddedWidth<VisibleWidth)or(PaddedHeight<VisibleHeight)Then Exit;
 If not AVIFImageFitsMemory(PaddedWidth,PaddedHeight,ChromaFormat)Then Exit;
 If ChromaFormat=acfYUV420 Then Begin
  ChromaWidth:=(PaddedWidth+1)div 2;
  ChromaHeight:=(PaddedHeight+1)div 2;
 End
  Else
 Begin
  ChromaWidth:=PaddedWidth;
  ChromaHeight:=PaddedHeight;
 End;
 Image.Width:=VisibleWidth;
 Image.Height:=VisibleHeight;
 Image.PaddedWidth:=PaddedWidth;
 Image.PaddedHeight:=PaddedHeight;
 Image.BitDepth:=AVIFInitialBitDepth;
 Image.ChromaFormat:=ChromaFormat;
 Image.RangeMode:=RangeMode;
 Image.MatrixMode:=MatrixMode;
 If ChromaFormat=acfYUV420 Then Begin
  Image.ChromaSubsamplingX:=1;
  Image.ChromaSubsamplingY:=1;
  Image.ChromaSamplePosition:=AVIFInitialChromaSamplePosition;
 End
  Else
 Begin
  Image.ChromaSubsamplingX:=0;
  Image.ChromaSubsamplingY:=0;
  Image.ChromaSamplePosition:=0;
 End;
 Image.ColorPrimaries:=AVIFInitialColorPrimaries;
 Image.TransferCharacteristics:=AVIFInitialTransfer;
 Image.MatrixCoefficients:=AVIFInitialMatrixCoefficients;
 If not AllocateAVIFPlane(Image.PlaneY,PaddedWidth,PaddedHeight)Then Begin
  FreeAVIFPlane(Image.PlaneY);
  Exit;
 End;
 If not AllocateAVIFPlane(Image.PlaneU,ChromaWidth,ChromaHeight)Then Begin
  FreeAVIFPlane(Image.PlaneY);
  FreeAVIFPlane(Image.PlaneU);
  Exit;
 End;
 If not AllocateAVIFPlane(Image.PlaneV,ChromaWidth,ChromaHeight)Then Begin
  FreeAVIFPlane(Image.PlaneY);
  FreeAVIFPlane(Image.PlaneU);
  FreeAVIFPlane(Image.PlaneV);
  Exit;
 End;
 AllocateAVIFImagePadded:=True;
End;

Function AllocateAVIFImage(Var Image:TAVIFImage;Width,Height:Word;
 ChromaFormat:TAVIFChromaFormat;RangeMode:TRangeMode;
 MatrixMode:TColorMatrixMode):Boolean;
Begin
 AllocateAVIFImage:=AllocateAVIFImagePadded(Image,Width,Height,Width,Height,
  ChromaFormat,RangeMode,MatrixMode);
End;

Procedure FreeAVIFImage(Var Image:TAVIFImage);
Begin
 FreeAVIFPlane(Image.PlaneY);
 FreeAVIFPlane(Image.PlaneU);
 FreeAVIFPlane(Image.PlaneV);
 InitAVIFImageRecord(Image);
End;

Procedure ClearAVIFPlane(Var Plane:TAVIFPlane;Value:Byte);
Begin
 If(Plane.Data<>Nil)and(Plane.Size>0)Then
  FillChar(Plane.Data^[0],Plane.Size,Value);
End;

Procedure ClearAVIFImage(Var Image:TAVIFImage);
Begin
 ClearAVIFPlane(Image.PlaneY,0);
 ClearAVIFPlane(Image.PlaneU,128);
 ClearAVIFPlane(Image.PlaneV,128);
End;

Procedure GetRGBPixel(X:Word;Var Pixel:RGB);Forward;

Function ClampByte(Value:LongInt):Byte;
Begin
 If Value<0 Then ClampByte:=0
  Else If Value>255 Then ClampByte:=255
                  Else ClampByte:=Byte(Value);
End;

Function DivRoundSigned(Value,Divisor:LongInt):LongInt;
Begin
 If Value>=0 Then DivRoundSigned:=(Value+(Divisor div 2))div Divisor
             Else DivRoundSigned:=-(((-Value)+(Divisor div 2))div Divisor);
End;

Procedure RGBToYUVPixel(R,G,B:Byte;Var Y,U,V:Byte;
 Matrix:TColorMatrixMode;Range:TRangeMode);
Var
 Rv,Gv,Bv:LongInt;
 YFull,UFull,VFull:LongInt;
 URaw,VRaw:LongInt;
Begin
 {Tests rapides full range :
  BT.709 noir -> Y=0,U=128,V=128; blanc -> Y=255,U=128,V=128.
  BT.601 rouge approche Y=76,U=85,V=255; vert Y=150,U=44,V=21;
  bleu Y=29,U=255,V=107.}
 Rv:=R;
 Gv:=G;
 Bv:=B;
 Case Matrix of
  cmBT601:Begin
   YFull:=(4899*Rv+9617*Gv+1868*Bv+8192)shr 14;
   UFull:=DivRoundSigned(-2765*Rv-5427*Gv+8192*Bv,16384)+128;
   VFull:=DivRoundSigned(8192*Rv-6859*Gv-1333*Bv,16384)+128;
  End;
  Else Begin {cmBT709}
   YFull:=(3483*Rv+11718*Gv+1183*Bv+8192)shr 14;
   UFull:=DivRoundSigned(-1877*Rv-6315*Gv+8192*Bv,16384)+128;
   VFull:=DivRoundSigned(8192*Rv-7441*Gv-751*Bv,16384)+128;
  End;
 End;
 If Range=rmLimitedRange Then Begin
  URaw:=UFull-128;
  VRaw:=VFull-128;
  YFull:=16+((ClampByte(YFull)*219+127)div 255);
  UFull:=128+DivRoundSigned(URaw*224,255);
  VFull:=128+DivRoundSigned(VRaw*224,255);
 End;
 Y:=ClampByte(YFull);
 U:=ClampByte(UFull);
 V:=ClampByte(VFull);
End;

Function AVIFPlaneOffset(Const Plane:TAVIFPlane;X,Y:Word):LongInt;
Begin
 AVIFPlaneOffset:=LongInt(Y)*LongInt(Plane.Stride)+LongInt(X);
End;

Procedure SetAVIFPlaneByte(Var Plane:TAVIFPlane;X,Y:Word;Value:Byte);
Var
 Offset:LongInt;
Begin
 If Plane.Data=Nil Then Exit;
 Offset:=AVIFPlaneOffset(Plane,X,Y);
 If(Offset>=0)and(Offset<Plane.Size)Then
  Plane.Data^[Offset]:=Value;
End;

Function GetAVIFPlaneByte(Const Plane:TAVIFPlane;X,Y:Word):Byte;
Var
 Offset:LongInt;
Begin
 GetAVIFPlaneByte:=0;
 If Plane.Data=Nil Then Exit;
 Offset:=AVIFPlaneOffset(Plane,X,Y);
 If(Offset>=0)and(Offset<Plane.Size)Then
  GetAVIFPlaneByte:=Plane.Data^[Offset];
End;

Procedure ConvertRGBLineToYUV444(Var Image:TAVIFImage;LineY:Word);
Var
 X:Word;
 Pixel:RGB;
 YSample,USample,VSample:Byte;
Begin
 If(Image.ChromaFormat<>acfYUV444)or(LineY>=Image.Height)Then Exit;
 For X:=0 to Image.Width-1 Do Begin
  GetRGBPixel(X,Pixel);
  RGBToYUVPixel(Pixel.R,Pixel.G,Pixel.B,YSample,USample,VSample,
   Image.MatrixMode,Image.RangeMode);
  SetAVIFPlaneByte(Image.PlaneY,X,LineY,YSample);
  SetAVIFPlaneByte(Image.PlaneU,X,LineY,USample);
  SetAVIFPlaneByte(Image.PlaneV,X,LineY,VSample);
 End;
End;

Function CopyYUV444ToYUV444(Const Source:TAVIFImage;Var Dest:TAVIFImage):Boolean;
Var
 X,YPos:Word;
Begin
 CopyYUV444ToYUV444:=False;
 If(Source.ChromaFormat<>acfYUV444)or(Dest.ChromaFormat<>acfYUV444)Then Exit;
 If(Source.Width<>Dest.Width)or(Source.Height<>Dest.Height)Then Exit;
 For YPos:=0 to Source.Height-1 Do
  For X:=0 to Source.Width-1 Do Begin
   SetAVIFPlaneByte(Dest.PlaneY,X,YPos,GetAVIFPlaneByte(Source.PlaneY,X,YPos));
   SetAVIFPlaneByte(Dest.PlaneU,X,YPos,GetAVIFPlaneByte(Source.PlaneU,X,YPos));
   SetAVIFPlaneByte(Dest.PlaneV,X,YPos,GetAVIFPlaneByte(Source.PlaneV,X,YPos));
  End;
 CopyYUV444ToYUV444:=True;
End;

Function ConvertYUV444ToYUV420(Const Source:TAVIFImage;Var Dest:TAVIFImage):Boolean;
Var
 X,YPos,CX,CY:Word;
 SX,SY:Word;
 SumU,SumV,Count:LongInt;
Begin
 ConvertYUV444ToYUV420:=False;
 If(Source.ChromaFormat<>acfYUV444)or(Dest.ChromaFormat<>acfYUV420)Then Exit;
 If(Source.Width<>Dest.Width)or(Source.Height<>Dest.Height)Then Exit;
 For YPos:=0 to Source.Height-1 Do
  For X:=0 to Source.Width-1 Do
   SetAVIFPlaneByte(Dest.PlaneY,X,YPos,GetAVIFPlaneByte(Source.PlaneY,X,YPos));
 For CY:=0 to Dest.PlaneU.Height-1 Do
  For CX:=0 to Dest.PlaneU.Width-1 Do Begin
   SumU:=0;
   SumV:=0;
   Count:=0;
   For SY:=CY*2 to CY*2+1 Do
    If SY<Source.Height Then
     For SX:=CX*2 to CX*2+1 Do
      If SX<Source.Width Then Begin
       SumU:=SumU+GetAVIFPlaneByte(Source.PlaneU,SX,SY);
       SumV:=SumV+GetAVIFPlaneByte(Source.PlaneV,SX,SY);
       Inc(Count);
      End;
   If Count>0 Then Begin
    SetAVIFPlaneByte(Dest.PlaneU,CX,CY,Byte((SumU+(Count div 2))div Count));
    SetAVIFPlaneByte(Dest.PlaneV,CX,CY,Byte((SumV+(Count div 2))div Count));
   End;
  End;
 ConvertYUV444ToYUV420:=True;
End;

Function ConvertYUV444ToPreferredChroma(Const Source:TAVIFImage;
 Var Dest:TAVIFImage):Boolean;
Begin
 If Dest.ChromaFormat=acfYUV420 Then
  ConvertYUV444ToPreferredChroma:=ConvertYUV444ToYUV420(Source,Dest)
 Else
  ConvertYUV444ToPreferredChroma:=CopyYUV444ToYUV444(Source,Dest);
End;

Function RoundUpToMultiple(Value,Multiple:Word):Word;
Var
 R:Word;
Begin
 If Multiple=0 Then Begin
  RoundUpToMultiple:=Value;
  Exit;
 End;
 R:=Value mod Multiple;
 If R=0 Then RoundUpToMultiple:=Value
        Else RoundUpToMultiple:=Word(LongInt(Value)+LongInt(Multiple)-LongInt(R));
End;

Procedure GetAVIFChromaVisibleSize(Const Image:TAVIFImage;Var Width,Height:Word);
Begin
 If Image.ChromaFormat=acfYUV420 Then Begin
  Width:=(Image.Width+1)div 2;
  Height:=(Image.Height+1)div 2;
 End
  Else
 Begin
  Width:=Image.Width;
  Height:=Image.Height;
 End;
End;

Procedure CopyAVIFPlaneVisible(Const Source:TAVIFPlane;Var Dest:TAVIFPlane;
 VisibleWidth,VisibleHeight:Word);
Var
 X,YPos:Word;
Begin
 For YPos:=0 to VisibleHeight-1 Do
  For X:=0 to VisibleWidth-1 Do
   SetAVIFPlaneByte(Dest,X,YPos,GetAVIFPlaneByte(Source,X,YPos));
End;

Function CopyAVIFImageVisible(Const Source:TAVIFImage;Var Dest:TAVIFImage):Boolean;
Var
 ChromaWidth,ChromaHeight:Word;
Begin
 CopyAVIFImageVisible:=False;
 If Source.ChromaFormat<>Dest.ChromaFormat Then Exit;
 If(Source.Width<>Dest.Width)or(Source.Height<>Dest.Height)Then Exit;
 If(Dest.PaddedWidth<Source.Width)or(Dest.PaddedHeight<Source.Height)Then Exit;
 GetAVIFChromaVisibleSize(Source,ChromaWidth,ChromaHeight);
 CopyAVIFPlaneVisible(Source.PlaneY,Dest.PlaneY,Source.Width,Source.Height);
 CopyAVIFPlaneVisible(Source.PlaneU,Dest.PlaneU,ChromaWidth,ChromaHeight);
 CopyAVIFPlaneVisible(Source.PlaneV,Dest.PlaneV,ChromaWidth,ChromaHeight);
 CopyAVIFImageVisible:=True;
End;

Procedure PadPlaneRightAndBottom(Var Plane:TAVIFPlane;VisibleWidth,VisibleHeight,
 PaddedWidth,PaddedHeight:Word);
Var
 X,YPos:Word;
 LastValue:Byte;
Begin
 If(Plane.Data=Nil)or(VisibleWidth=0)or(VisibleHeight=0)Then Exit;
 If(PaddedWidth>Plane.Width)or(PaddedHeight>Plane.Height)Then Exit;
 For YPos:=0 to VisibleHeight-1 Do Begin
  LastValue:=GetAVIFPlaneByte(Plane,VisibleWidth-1,YPos);
  For X:=VisibleWidth to PaddedWidth-1 Do
   SetAVIFPlaneByte(Plane,X,YPos,LastValue);
 End;
 For YPos:=VisibleHeight to PaddedHeight-1 Do
  For X:=0 to PaddedWidth-1 Do
   SetAVIFPlaneByte(Plane,X,YPos,GetAVIFPlaneByte(Plane,X,VisibleHeight-1));
End;

Procedure PadAVIFImageRightAndBottom(Var Image:TAVIFImage);
Var
 ChromaVisibleWidth,ChromaVisibleHeight:Word;
Begin
 PadPlaneRightAndBottom(Image.PlaneY,Image.Width,Image.Height,
  Image.PaddedWidth,Image.PaddedHeight);
 GetAVIFChromaVisibleSize(Image,ChromaVisibleWidth,ChromaVisibleHeight);
 PadPlaneRightAndBottom(Image.PlaneU,ChromaVisibleWidth,ChromaVisibleHeight,
  Image.PlaneU.Width,Image.PlaneU.Height);
 PadPlaneRightAndBottom(Image.PlaneV,ChromaVisibleWidth,ChromaVisibleHeight,
  Image.PlaneV.Width,Image.PlaneV.Height);
End;

Function ChecksumAVIFImage(Const Image:TAVIFImage):LongInt;
Var
 X,YPos:Word;
 Sum:LongInt;
Begin
 Sum:=0;
 For YPos:=0 to Image.PlaneY.Height-1 Do
  For X:=0 to Image.PlaneY.Width-1 Do
   Sum:=(Sum+GetAVIFPlaneByte(Image.PlaneY,X,YPos))and $7FFFFFFF;
 For YPos:=0 to Image.PlaneU.Height-1 Do
  For X:=0 to Image.PlaneU.Width-1 Do
   Sum:=(Sum+GetAVIFPlaneByte(Image.PlaneU,X,YPos))and $7FFFFFFF;
 For YPos:=0 to Image.PlaneV.Height-1 Do
  For X:=0 to Image.PlaneV.Width-1 Do
   Sum:=(Sum+GetAVIFPlaneByte(Image.PlaneV,X,YPos))and $7FFFFFFF;
 ChecksumAVIFImage:=Sum;
End;

Procedure InitSuperBlockGrid(Const Image:TAVIFImage;SBSize:Word;
 Var Grid:TAV1SuperBlockGrid);
Var
 GridWidth,GridHeight:Word;
Begin
 Grid.ImageWidth:=0;
 Grid.ImageHeight:=0;
 Grid.SBSize:=0;
 Grid.NumSBCols:=0;
 Grid.NumSBRows:=0;
 Grid.TotalSuperBlocks:=0;
 If(SBSize<>64)and(SBSize<>128)Then Exit;
 If(Image.Width=0)or(Image.Height=0)Then Exit;
 If Image.PaddedWidth<>0 Then GridWidth:=Image.PaddedWidth
                         Else GridWidth:=Image.Width;
 If Image.PaddedHeight<>0 Then GridHeight:=Image.PaddedHeight
                          Else GridHeight:=Image.Height;
 Grid.ImageWidth:=GridWidth;
 Grid.ImageHeight:=GridHeight;
 Grid.SBSize:=SBSize;
 Grid.NumSBCols:=(GridWidth+SBSize-1)div SBSize;
 Grid.NumSBRows:=(GridHeight+SBSize-1)div SBSize;
 Grid.TotalSuperBlocks:=LongInt(Grid.NumSBCols)*LongInt(Grid.NumSBRows);
End;

Function SuperBlockGridIsValid(Const Grid:TAV1SuperBlockGrid):Boolean;
Begin
 SuperBlockGridIsValid:=(Grid.SBSize<>0)and(Grid.NumSBCols<>0)and
  (Grid.NumSBRows<>0)and(Grid.TotalSuperBlocks>0);
End;

Function GetSuperBlockByCoord(Const Grid:TAV1SuperBlockGrid;SBX,SBY:Word;
 Var SB:TAV1SuperBlock):Boolean;
Var
 EndX,EndY:LongInt;
Begin
 GetSuperBlockByCoord:=False;
 FillChar(SB,SizeOf(SB),0);
 If not SuperBlockGridIsValid(Grid)Then Exit;
 If(SBX>=Grid.NumSBCols)or(SBY>=Grid.NumSBRows)Then Exit;
 SB.SBX:=SBX;
 SB.SBY:=SBY;
 SB.TileIndex:=0;
 SB.PixelX:=Word(LongInt(SBX)*LongInt(Grid.SBSize));
 SB.PixelY:=Word(LongInt(SBY)*LongInt(Grid.SBSize));
 EndX:=LongInt(SB.PixelX)+LongInt(Grid.SBSize);
 EndY:=LongInt(SB.PixelY)+LongInt(Grid.SBSize);
 If EndX>Grid.ImageWidth Then EndX:=Grid.ImageWidth;
 If EndY>Grid.ImageHeight Then EndY:=Grid.ImageHeight;
 SB.Width:=Word(EndX-SB.PixelX);
 SB.Height:=Word(EndY-SB.PixelY);
 SB.IsRightEdge:=SBX=Grid.NumSBCols-1;
 SB.IsBottomEdge:=SBY=Grid.NumSBRows-1;
 GetSuperBlockByCoord:=True;
End;

Function GetSuperBlockByIndex(Const Grid:TAV1SuperBlockGrid;Index:LongInt;
 Var SB:TAV1SuperBlock):Boolean;
Var
 SBX,SBY:Word;
Begin
 GetSuperBlockByIndex:=False;
 If not SuperBlockGridIsValid(Grid)Then Exit;
 If(Index<0)or(Index>=Grid.TotalSuperBlocks)Then Exit;
 SBX:=Word(Index mod Grid.NumSBCols);
 SBY:=Word(Index div Grid.NumSBCols);
 GetSuperBlockByIndex:=GetSuperBlockByCoord(Grid,SBX,SBY,SB);
End;

Function ValidateSuperBlockGrid(Const Image:TAVIFImage;
 Const Grid:TAV1SuperBlockGrid):Boolean;
Var
 I:LongInt;
 SB:TAV1SuperBlock;
 ChromaX,ChromaY,ChromaW,ChromaH:Word;
Begin
 ValidateSuperBlockGrid:=False;
 If not SuperBlockGridIsValid(Grid)Then Exit;
 For I:=0 to Grid.TotalSuperBlocks-1 Do Begin
  If not GetSuperBlockByIndex(Grid,I,SB)Then Exit;
  If(SB.Width=0)or(SB.Height=0)Then Exit;
  If LongInt(SB.PixelX)+SB.Width>Image.PlaneY.Width Then Exit;
  If LongInt(SB.PixelY)+SB.Height>Image.PlaneY.Height Then Exit;
  If Image.ChromaFormat=acfYUV420 Then Begin
   ChromaX:=SB.PixelX div 2;
   ChromaY:=SB.PixelY div 2;
   ChromaW:=(SB.Width+1)div 2;
   ChromaH:=(SB.Height+1)div 2;
  End
   Else
  Begin
   ChromaX:=SB.PixelX;
   ChromaY:=SB.PixelY;
   ChromaW:=SB.Width;
   ChromaH:=SB.Height;
  End;
  If LongInt(ChromaX)+ChromaW>Image.PlaneU.Width Then Exit;
  If LongInt(ChromaY)+ChromaH>Image.PlaneU.Height Then Exit;
  If LongInt(ChromaX)+ChromaW>Image.PlaneV.Width Then Exit;
  If LongInt(ChromaY)+ChromaH>Image.PlaneV.Height Then Exit;
 End;
 ValidateSuperBlockGrid:=True;
End;

Procedure InitSingleTileConfig(Var Config:TAV1TileConfig);
Begin
 Config.TileCols:=1;
 Config.TileRows:=1;
 Config.TileColsLog2:=0;
 Config.TileRowsLog2:=0;
 Config.UniformTileSpacing:=True;
 Config.ContextUpdateTileId:=0;
 Config.TileSizeBytesMinus1:=0;
End;

Function InitSingleTile(Const Grid:TAV1SuperBlockGrid;
 Const Config:TAV1TileConfig;Var Tile:TAV1Tile):Boolean;
Begin
 InitSingleTile:=False;
 FillChar(Tile,SizeOf(Tile),0);
 If not SuperBlockGridIsValid(Grid)Then Exit;
 If(Config.TileCols<>1)or(Config.TileRows<>1)Then Exit;
 Tile.TileIndex:=0;
 Tile.StartSBX:=0;
 Tile.StartSBY:=0;
 Tile.EndSBX:=Grid.NumSBCols;
 Tile.EndSBY:=Grid.NumSBRows;
 Tile.StartPixelX:=0;
 Tile.StartPixelY:=0;
 Tile.Width:=Grid.ImageWidth;
 Tile.Height:=Grid.ImageHeight;
 InitSingleTile:=True;
End;

Function ValidateTile(Const Grid:TAV1SuperBlockGrid;Const Tile:TAV1Tile):Boolean;
Begin
 ValidateTile:=(Tile.StartSBX=0)and(Tile.StartSBY=0)and
  (Tile.EndSBX=Grid.NumSBCols)and(Tile.EndSBY=Grid.NumSBRows)and
  (Tile.Width=Grid.ImageWidth)and(Tile.Height=Grid.ImageHeight);
End;

Procedure InitAV1ByteBuffer(Var Buffer:TAV1ByteBuffer);
Begin
 Buffer.Data:=Nil;
 Buffer.Size:=0;
 Buffer.Capacity:=0;
End;

Function AllocateAV1ByteBuffer(Var Buffer:TAV1ByteBuffer;Capacity:LongInt):Boolean;
Begin
 AllocateAV1ByteBuffer:=False;
 InitAV1ByteBuffer(Buffer);
 If(Capacity=0)or(Capacity>AVIFMaxFileBytes)Then Exit;
 GetMem(Buffer.Data,Capacity);
 If Buffer.Data=Nil Then Exit;
 Buffer.Capacity:=Capacity;
 Buffer.Size:=0;
 AllocateAV1ByteBuffer:=True;
End;

Procedure FreeAV1ByteBuffer(Var Buffer:TAV1ByteBuffer);
Begin
 If Buffer.Data<>Nil Then
  FreeMem(Buffer.Data,Buffer.Capacity);
 InitAV1ByteBuffer(Buffer);
End;

Function AV1BufferAppendByte(Var Buffer:TAV1ByteBuffer;Value:Byte):Boolean;
Begin
 AV1BufferAppendByte:=False;
 If(Buffer.Data=Nil)or(Buffer.Size>=Buffer.Capacity)Then Exit;
 Buffer.Data^[Buffer.Size]:=Value;
 Inc(Buffer.Size);
 AV1BufferAppendByte:=True;
End;

Function AV1BufferAppendBuffer(Var Dest:TAV1ByteBuffer;
 Const Source:TAV1ByteBuffer):Boolean;
Var
 I:LongInt;
Begin
 AV1BufferAppendBuffer:=False;
 If Source.Size=0 Then Begin
  AV1BufferAppendBuffer:=True;
  Exit;
 End;
 For I:=0 to Source.Size-1 Do
  If not AV1BufferAppendByte(Dest,Source.Data^[I])Then Exit;
 AV1BufferAppendBuffer:=True;
End;

Function AV1BufferAppendLE16(Var Buffer:TAV1ByteBuffer;Value:Word):Boolean;
Begin
 AV1BufferAppendLE16:=False;
 If not AV1BufferAppendByte(Buffer,Byte(Value and $FF))Then Exit;
 If not AV1BufferAppendByte(Buffer,Byte((Value shr 8)and $FF))Then Exit;
 AV1BufferAppendLE16:=True;
End;

Function ReadLE16FromAV1Buffer(Const Buffer:TAV1ByteBuffer;Var Pos:LongInt;
 Var Value:Word):Boolean;
Begin
 ReadLE16FromAV1Buffer:=False;
 Value:=0;
 If(Buffer.Data=Nil)or(Pos<0)or(Pos+1>=Buffer.Size)Then Exit;
 Value:=Word(Buffer.Data^[Pos])or(Word(Buffer.Data^[Pos+1])shl 8);
 Inc(Pos,2);
 ReadLE16FromAV1Buffer:=True;
End;

Procedure InitBitWriter(Var Writer:TBitWriter;Var Buffer:TAV1ByteBuffer);
Begin
 Writer.Buffer:=@Buffer;
 Writer.CurrentByte:=0;
 Writer.BitCount:=0;
 Writer.Failed:=False;
End;

Procedure BitWriterFlushByte(Var Writer:TBitWriter);
Begin
 If Writer.Failed Then Exit;
 If Writer.Buffer=Nil Then Begin
  Writer.Failed:=True;
  Exit;
 End;
 If not AV1BufferAppendByte(Writer.Buffer^,Writer.CurrentByte)Then Begin
  Writer.Failed:=True;
  Exit;
 End;
 Writer.CurrentByte:=0;
 Writer.BitCount:=0;
End;

Procedure WriteBit(Var Writer:TBitWriter;BitValue:Byte);
Begin
 If Writer.Failed Then Exit;
 If(BitValue and 1)<>0 Then
  Writer.CurrentByte:=Writer.CurrentByte or (Byte(1)shl(7-Writer.BitCount));
 Inc(Writer.BitCount);
 If Writer.BitCount=8 Then BitWriterFlushByte(Writer);
End;

Procedure WriteBits(Var Writer:TBitWriter;Value:LongInt;BitCount:Byte);
Var
 I:Integer;
Begin
 For I:=BitCount-1 downto 0 Do
  WriteBit(Writer,Byte((Value shr I)and 1));
End;

Procedure AddTrailingBits(Var Writer:TBitWriter);
Begin
 WriteBit(Writer,1);
 While(Writer.BitCount<>0)and(not Writer.Failed)Do
  WriteBit(Writer,0);
End;

Procedure InitBitReader(Var Reader:TBitReader;Const Buffer:TAV1ByteBuffer;
 StartPos,Size:LongInt);
Begin
 Reader.Buffer:=@Buffer;
 Reader.Pos:=StartPos;
 Reader.EndPos:=StartPos+Size;
 Reader.BitOffset:=0;
 Reader.Failed:=False;
 If(Buffer.Data=Nil)or(StartPos<0)or(Size<0)or(Reader.EndPos>Buffer.Size)Then
  Reader.Failed:=True;
End;

Function ReadBitFromReader(Var Reader:TBitReader):Byte;
Var
 Value:Byte;
Begin
 ReadBitFromReader:=0;
 If Reader.Failed Then Exit;
 If(Reader.Buffer=Nil)or(Reader.Pos>=Reader.EndPos)Then Begin
  Reader.Failed:=True;
  Exit;
 End;
 Value:=Reader.Buffer^.Data^[Reader.Pos];
 ReadBitFromReader:=(Value shr(7-Reader.BitOffset))and 1;
 Inc(Reader.BitOffset);
 If Reader.BitOffset=8 Then Begin
  Reader.BitOffset:=0;
  Inc(Reader.Pos);
 End;
End;

Function ReadBitsFromReader(Var Reader:TBitReader;BitCount:Byte):LongInt;
Var
 I:Byte;
 Value:LongInt;
Begin
 Value:=0;
 For I:=1 to BitCount Do
  Value:=(Value shl 1)+ReadBitFromReader(Reader);
 ReadBitsFromReader:=Value;
End;

Function ValidateTrailingBits(Var Reader:TBitReader):Boolean;
Begin
 ValidateTrailingBits:=False;
 If Reader.Failed Then Exit;
 If ReadBitFromReader(Reader)<>1 Then Exit;
 While(Reader.BitOffset<>0)and(not Reader.Failed)Do
  If ReadBitFromReader(Reader)<>0 Then Exit;
 If Reader.Failed Then Exit;
 ValidateTrailingBits:=Reader.Pos=Reader.EndPos;
End;

Function WriteLEB128(Var Buffer:TAV1ByteBuffer;Value:LongInt):Boolean;
Var
 B:Byte;
Begin
 WriteLEB128:=False;
 Repeat
  B:=Byte(Value and $7F);
  Value:=Value shr 7;
  If Value<>0 Then B:=B or $80;
  If not AV1BufferAppendByte(Buffer,B)Then Exit;
 Until Value=0;
 WriteLEB128:=True;
End;

Function AV1OBUTypeValue(OBUType:TAV1OBUType):Byte;
Begin
 AV1OBUTypeValue:=Ord(OBUType);
End;

Function WriteOBUHeader(Var Buffer:TAV1ByteBuffer;OBUType:TAV1OBUType;
 HasExtension,HasSizeField:Boolean):Boolean;
Var
 B:Byte;
Begin
 B:=AV1OBUTypeValue(OBUType)shl 3;
 If HasExtension Then B:=B or 4;
 If HasSizeField Then B:=B or 2;
 WriteOBUHeader:=AV1BufferAppendByte(Buffer,B);
End;

Function WriteOBU(OBUType:TAV1OBUType;Const Payload:TAV1ByteBuffer;
 Var Output:TAV1ByteBuffer):Boolean;
Begin
 WriteOBU:=False;
 If not AllocateAV1ByteBuffer(Output,AV1MaxOBUBytes)Then Exit;
 If not WriteOBUHeader(Output,OBUType,False,True)Then Exit;
 If not WriteLEB128(Output,Payload.Size)Then Exit;
 If not AV1BufferAppendBuffer(Output,Payload)Then Exit;
 WriteOBU:=True;
End;

Procedure InitAV1Bitstream(Var Bitstream:TAV1Bitstream);
Begin
 InitAV1ByteBuffer(Bitstream.SequenceHeader);
 InitAV1ByteBuffer(Bitstream.FrameHeader);
 InitAV1ByteBuffer(Bitstream.TileGroup);
 InitAV1ByteBuffer(Bitstream.Combined);
End;

Procedure FreeAV1Bitstream(Var Bitstream:TAV1Bitstream);
Begin
 FreeAV1ByteBuffer(Bitstream.SequenceHeader);
 FreeAV1ByteBuffer(Bitstream.FrameHeader);
 FreeAV1ByteBuffer(Bitstream.TileGroup);
 FreeAV1ByteBuffer(Bitstream.Combined);
 InitAV1Bitstream(Bitstream);
End;

Function CopyAV1Buffer(Const Source:TAV1ByteBuffer;Var Dest:TAV1ByteBuffer):Boolean;
Begin
 CopyAV1Buffer:=False;
 If not AllocateAV1ByteBuffer(Dest,AV1MaxOBUBytes)Then Exit;
 If not AV1BufferAppendBuffer(Dest,Source)Then Begin
  FreeAV1ByteBuffer(Dest);
  Exit;
 End;
 CopyAV1Buffer:=True;
End;

Function ValidateOBUHeader(Const Buffer:TAV1ByteBuffer;ExpectedType:TAV1OBUType):Boolean;
Var
 Header,TypeValue:Byte;
 Pos:Word;
 SizeValue,Shift:LongInt;
 B:Byte;
Begin
 ValidateOBUHeader:=False;
 If(Buffer.Data=Nil)or(Buffer.Size<2)Then Exit;
 Header:=Buffer.Data^[0];
 TypeValue:=(Header shr 3)and $0F;
 If TypeValue<>AV1OBUTypeValue(ExpectedType)Then Exit;
 If(Header and $80)<>0 Then Exit;
 If(Header and 2)=0 Then Exit;
 Pos:=1;
 SizeValue:=0;
 Shift:=0;
 Repeat
  If Pos>=Buffer.Size Then Exit;
  B:=Buffer.Data^[Pos];
  SizeValue:=SizeValue+LongInt(B and $7F)shl Shift;
  Shift:=Shift+7;
  Inc(Pos);
 Until(B and $80)=0;
 ValidateOBUHeader:=LongInt(Pos)+SizeValue=Buffer.Size;
End;

Function ValidateOBUAt(Const Buffer:TAV1ByteBuffer;StartPos,EndPos:LongInt;
 ExpectedType:TAV1OBUType;Var NextPos:LongInt):Boolean;
Var
 Header,TypeValue:Byte;
 Pos:LongInt;
 SizeValue,Shift:LongInt;
 B:Byte;
Begin
 ValidateOBUAt:=False;
 NextPos:=StartPos;
 If(Buffer.Data=Nil)or(LongInt(StartPos)+2>EndPos)Then Exit;
 Header:=Buffer.Data^[StartPos];
 TypeValue:=(Header shr 3)and $0F;
 If TypeValue<>AV1OBUTypeValue(ExpectedType)Then Exit;
 If(Header and $80)<>0 Then Exit;
 If(Header and 2)=0 Then Exit;
 Pos:=StartPos+1;
 SizeValue:=0;
 Shift:=0;
 Repeat
  If Pos>=EndPos Then Exit;
  B:=Buffer.Data^[Pos];
  SizeValue:=SizeValue+LongInt(B and $7F)shl Shift;
  Shift:=Shift+7;
  Inc(Pos);
 Until(B and $80)=0;
 If SizeValue<0 Then Exit;
 If LongInt(Pos)+SizeValue>EndPos Then Exit;
 NextPos:=Pos+SizeValue;
 ValidateOBUAt:=True;
End;

Function ValidateAV1OBUSequenceInRange(Const Buffer:TAV1ByteBuffer;
 StartPos,DataLength:LongInt):Boolean;
Var
 Pos,EndPos,NextPos:LongInt;
Begin
 ValidateAV1OBUSequenceInRange:=False;
 If(StartPos<0)or(DataLength<=0)Then Exit;
 If StartPos+DataLength>Buffer.Size Then Exit;
 Pos:=StartPos;
 EndPos:=StartPos+DataLength;
 If not ValidateOBUAt(Buffer,Pos,EndPos,obuSequenceHeader,NextPos)Then Exit;
 Pos:=NextPos;
 If not ValidateOBUAt(Buffer,Pos,EndPos,obuFrameHeader,NextPos)Then Exit;
 Pos:=NextPos;
 If not ValidateOBUAt(Buffer,Pos,EndPos,obuTileGroup,NextPos)Then Exit;
 ValidateAV1OBUSequenceInRange:=NextPos=EndPos;
End;

Function AV1BitstreamIsDecoderReady:Boolean;Forward;
Function AV1BitstreamIsExternalDecoderReady:Boolean;Forward;
Function ValidateExternalDecoderConformance(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;Const Bitstream:TAV1Bitstream;
 Const Container:TAVIFContainer;Var Reason:String):Boolean;Forward;
Function ValidateSequenceConfigForStillPicture(Const Config:TAV1SequenceConfig):Boolean;Forward;
Function ValidateBuiltInAV1Scope(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig):Boolean;Forward;
Function ValidateBuiltInSequenceHeaderPayload(Const SequenceOBU:TAV1ByteBuffer;
 Const SeqConfig:TAV1SequenceConfig):Boolean;Forward;
Function ValidateBuiltInFrameHeaderPayload(Const FrameHeaderOBU:TAV1ByteBuffer;
 Const SeqConfig:TAV1SequenceConfig;Const Image:TAVIFImage):Boolean;Forward;
Function ValidateAVIFRegressionStructure(Const Container:TAVIFContainer;
 Const Image:TAVIFImage;Const SeqConfig:TAV1SequenceConfig;
 AV1DataSize:LongInt):Boolean;Forward;

Function GetOBUPayloadRange(Const Buffer:TAV1ByteBuffer;
 ExpectedType:TAV1OBUType;Var PayloadStart,PayloadSize:LongInt):Boolean;
Var
 Header,TypeValue:Byte;
 Pos:LongInt;
 SizeValue,Shift:LongInt;
 B:Byte;
Begin
 GetOBUPayloadRange:=False;
 PayloadStart:=0;
 PayloadSize:=0;
 If(Buffer.Data=Nil)or(Buffer.Size<2)Then Exit;
 Header:=Buffer.Data^[0];
 TypeValue:=(Header shr 3)and $0F;
 If TypeValue<>AV1OBUTypeValue(ExpectedType)Then Exit;
 If(Header and $80)<>0 Then Exit;
 If(Header and 2)=0 Then Exit;
 Pos:=1;
 SizeValue:=0;
 Shift:=0;
 Repeat
  If Pos>=Buffer.Size Then Exit;
  B:=Buffer.Data^[Pos];
  SizeValue:=SizeValue+LongInt(B and $7F)shl Shift;
  Shift:=Shift+7;
  Inc(Pos);
 Until(B and $80)=0;
 If(SizeValue<=0)or(Pos+SizeValue<>Buffer.Size)Then Exit;
 PayloadStart:=Pos;
 PayloadSize:=SizeValue;
 GetOBUPayloadRange:=True;
End;

Function ValidateBuiltInTileGroupPayload(Const TileGroupOBU:TAV1ByteBuffer):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
 RangePayloadBytes:LongInt;
Begin
 ValidateBuiltInTileGroupPayload:=False;
 If not GetOBUPayloadRange(TileGroupOBU,obuTileGroup,PayloadStart,
  PayloadSize)Then Exit;
 If PayloadSize<1 Then Exit;
 RangePayloadBytes:=PayloadSize;
 If RangePayloadBytes<1 Then Exit;
 ValidateBuiltInTileGroupPayload:=True;
End;

Function TilePayloadLooksLikeInternalRangeStream(Const TileGroupOBU:TAV1ByteBuffer):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
Begin
 TilePayloadLooksLikeInternalRangeStream:=False;
 If not GetOBUPayloadRange(TileGroupOBU,obuTileGroup,PayloadStart,
  PayloadSize)Then Exit;
 If PayloadSize<1 Then Exit;
 TilePayloadLooksLikeInternalRangeStream:=True;
End;

Function TilePayloadIsMinimalDCSkipCandidate(Const TileGroupOBU:TAV1ByteBuffer):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
Begin
 TilePayloadIsMinimalDCSkipCandidate:=False;
 If not GetOBUPayloadRange(TileGroupOBU,obuTileGroup,PayloadStart,
  PayloadSize)Then Exit;
 {Chemin ultra limite : une tuile, blocs intra DC, skip=1, EOB=0.
  Le payload d'un seul octet est le marqueur interne du candidat minimal.
  Il ne suffit pas a prouver la compatibilite decodeur externe.}
 If PayloadSize<>1 Then Exit;
 If TileGroupOBU.Data=Nil Then Exit;
 If TileGroupOBU.Data^[PayloadStart]<>0 Then Exit;
 TilePayloadIsMinimalDCSkipCandidate:=True;
End;

Function TilePayloadIsBuiltInRawYUVCandidate(Const TileGroupOBU:TAV1ByteBuffer):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
 Pos:LongInt;
 W,H:Word;
 FormatByte:Byte;
 YSize,USize,VSize,ExpectedSize:LongInt;
 ChromaWidth,ChromaHeight:Word;
Begin
 TilePayloadIsBuiltInRawYUVCandidate:=False;
 If not GetOBUPayloadRange(TileGroupOBU,obuTileGroup,PayloadStart,
  PayloadSize)Then Exit;
 If PayloadSize<12 Then Exit;
 If TileGroupOBU.Data=Nil Then Exit;
 Pos:=PayloadStart;
 If TileGroupOBU.Data^[Pos]<>Ord('B')Then Exit; Inc(Pos);
 If TileGroupOBU.Data^[Pos]<>Ord('2')Then Exit; Inc(Pos);
 If TileGroupOBU.Data^[Pos]<>Ord('A')Then Exit; Inc(Pos);
 If TileGroupOBU.Data^[Pos]<>Ord('R')Then Exit; Inc(Pos);
 If TileGroupOBU.Data^[Pos]<>1 Then Exit; Inc(Pos);
 If not ReadLE16FromAV1Buffer(TileGroupOBU,Pos,W)Then Exit;
 If not ReadLE16FromAV1Buffer(TileGroupOBU,Pos,H)Then Exit;
 If(W=0)or(H=0)Then Exit;
 If Pos>=TileGroupOBU.Size Then Exit;
 FormatByte:=TileGroupOBU.Data^[Pos];
 Inc(Pos);
 YSize:=LongInt(W)*LongInt(H);
 If FormatByte=0 Then Begin
  ChromaWidth:=(W+1)div 2;
  ChromaHeight:=(H+1)div 2;
 End Else If FormatByte=1 Then Begin
  ChromaWidth:=W;
  ChromaHeight:=H;
 End Else
  Exit;
 USize:=LongInt(ChromaWidth)*LongInt(ChromaHeight);
 VSize:=USize;
 ExpectedSize:=LongInt(Pos-PayloadStart)+YSize+USize+VSize;
 TilePayloadIsBuiltInRawYUVCandidate:=ExpectedSize=PayloadSize;
End;

Function TilePayloadIsBuiltInSymbolTrace(Const TileGroupOBU:TAV1ByteBuffer):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
Begin
 TilePayloadIsBuiltInSymbolTrace:=False;
 If not GetOBUPayloadRange(TileGroupOBU,obuTileGroup,PayloadStart,
  PayloadSize)Then Exit;
 If PayloadSize<6 Then Exit;
 If TileGroupOBU.Data=Nil Then Exit;
 If TileGroupOBU.Data^[PayloadStart]<>Ord('B')Then Exit;
 If TileGroupOBU.Data^[PayloadStart+1]<>Ord('2')Then Exit;
 If TileGroupOBU.Data^[PayloadStart+2]<>Ord('A')Then Exit;
 If TileGroupOBU.Data^[PayloadStart+3]<>Ord('S')Then Exit;
 If TileGroupOBU.Data^[PayloadStart+4]<>1 Then Exit;
 TilePayloadIsBuiltInSymbolTrace:=True;
End;

Function ValidateExternalTileSyntax(Const TileGroupOBU:TAV1ByteBuffer;
 Var Reason:String):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
Begin
 ValidateExternalTileSyntax:=False;
 Reason:='';
 If not GetOBUPayloadRange(TileGroupOBU,obuTileGroup,PayloadStart,
  PayloadSize)Then Begin
  Reason:='Tile Group OBU absent ou taille LEB128 invalide.';
  Exit;
 End;
 If PayloadSize=0 Then Begin
  Reason:='Tile Group vide.';
  Exit;
 End;
 If TilePayloadIsMinimalDCSkipCandidate(TileGroupOBU)Then Begin
  Reason:='certificat interne minimal DC/skip/EOB=0 present, mais verification decodeur externe toujours absente';
  Exit;
 End;
 If TilePayloadLooksLikeInternalRangeStream(TileGroupOBU)Then Begin
  Reason:='la tuile minimale DC/skip existe, mais la syntaxe AV1 tile bit-a-bit n''est pas encore certifiee decodeur externe';
  Exit;
 End;
 ValidateExternalTileSyntax:=True;
End;

Function ValidateExternalDecoderConformance(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;Const Bitstream:TAV1Bitstream;
 Const Container:TAVIFContainer;Var Reason:String):Boolean;
Var
 ExpectedSize:LongInt;
Begin
 ValidateExternalDecoderConformance:=False;
 Reason:='';
 If not ValidateBuiltInAV1Scope(Image,SeqConfig)Then Begin
  Reason:='perimetre AV1 initial non respecte';
  Exit;
 End;
 If not ValidateOBUHeader(Bitstream.SequenceHeader,obuSequenceHeader)Then Begin
  Reason:='Sequence Header OBU invalide';
  Exit;
 End;
 If not ValidateOBUHeader(Bitstream.FrameHeader,obuFrameHeader)Then Begin
  Reason:='Frame Header OBU invalide';
  Exit;
 End;
 If not ValidateOBUHeader(Bitstream.TileGroup,obuTileGroup)Then Begin
  Reason:='Tile Group OBU invalide';
  Exit;
 End;
 If not ValidateBuiltInSequenceHeaderPayload(Bitstream.SequenceHeader,
  SeqConfig)Then Begin
  Reason:='Sequence Header non relisible strictement';
  Exit;
 End;
 If not ValidateBuiltInFrameHeaderPayload(Bitstream.FrameHeader,SeqConfig,
  Image)Then Begin
  Reason:='Frame Header non relisible strictement';
  Exit;
 End;
 If not ValidateExternalTileSyntax(Bitstream.TileGroup,Reason)Then Exit;
 ExpectedSize:=Bitstream.SequenceHeader.Size+Bitstream.FrameHeader.Size+
  Bitstream.TileGroup.Size;
 If Bitstream.Combined.Size<>ExpectedSize Then Begin
  Reason:='assemblage OBU incoherent';
  Exit;
 End;
 If not ValidateAV1OBUSequenceInRange(Bitstream.Combined,0,
  Bitstream.Combined.Size)Then Begin
  Reason:='ordre OBU non conforme';
  Exit;
 End;
 If not ValidateAVIFRegressionStructure(Container,Image,SeqConfig,
  Bitstream.Combined.Size)Then Begin
  Reason:='structure AVIF ISO-BMFF non conforme';
  Exit;
 End;
 ValidateExternalDecoderConformance:=True;
End;

Function ValidateBuiltInSequenceHeaderPayload(Const SequenceOBU:TAV1ByteBuffer;
 Const SeqConfig:TAV1SequenceConfig):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
 Reader:TBitReader;
 Value:LongInt;
Begin
 ValidateBuiltInSequenceHeaderPayload:=False;
 If not ValidateSequenceConfigForStillPicture(SeqConfig)Then Exit;
 If not GetOBUPayloadRange(SequenceOBU,obuSequenceHeader,PayloadStart,
  PayloadSize)Then Exit;
 InitBitReader(Reader,SequenceOBU,PayloadStart,PayloadSize);
 If ReadBitsFromReader(Reader,3)<>SeqConfig.SeqProfile Then Exit;
 If ReadBitFromReader(Reader)<>Ord(SeqConfig.StillPicture)Then Exit;
 If ReadBitFromReader(Reader)<>Ord(SeqConfig.ReducedStillPictureHeader)Then Exit;
 If ReadBitsFromReader(Reader,5)<>SeqConfig.SeqLevelIdx0 Then Exit;
 If ReadBitsFromReader(Reader,4)<>SeqConfig.FrameWidthBits-1 Then Exit;
 If ReadBitsFromReader(Reader,4)<>SeqConfig.FrameHeightBits-1 Then Exit;
 If ReadBitsFromReader(Reader,SeqConfig.FrameWidthBits)<>
  LongInt(SeqConfig.MaxFrameWidth)-1 Then Exit;
 If ReadBitsFromReader(Reader,SeqConfig.FrameHeightBits)<>
  LongInt(SeqConfig.MaxFrameHeight)-1 Then Exit;
 If ReadBitFromReader(Reader)<>Ord(SeqConfig.Use128x128SuperBlock)Then Exit;
 If ReadBitFromReader(Reader)<>Ord(SeqConfig.EnableFilterIntra)Then Exit;
 If ReadBitFromReader(Reader)<>Ord(SeqConfig.EnableIntraEdgeFilter)Then Exit;
 If ReadBitFromReader(Reader)<>Ord(SeqConfig.HighBitDepth)Then Exit;
 If ReadBitFromReader(Reader)<>Ord(SeqConfig.MonoChrome)Then Exit;
 If ReadBitFromReader(Reader)<>Ord(SeqConfig.ColorDescriptionPresent)Then Exit;
 If SeqConfig.ColorDescriptionPresent Then Begin
  If ReadBitsFromReader(Reader,8)<>SeqConfig.ColorPrimaries Then Exit;
  If ReadBitsFromReader(Reader,8)<>SeqConfig.TransferCharacteristics Then Exit;
  If ReadBitsFromReader(Reader,8)<>SeqConfig.MatrixCoefficients Then Exit;
 End;
 If ReadBitFromReader(Reader)<>SeqConfig.ColorRange Then Exit;
 If(SeqConfig.SeqProfile=0)and(not SeqConfig.MonoChrome)Then Begin
  If ReadBitsFromReader(Reader,2)<>SeqConfig.ChromaSamplePosition Then Exit;
 End
  Else Begin
  If ReadBitFromReader(Reader)<>SeqConfig.SubsamplingX Then Exit;
  If ReadBitFromReader(Reader)<>SeqConfig.SubsamplingY Then Exit;
  If(SeqConfig.SubsamplingX<>0)and(SeqConfig.SubsamplingY<>0)Then
   If ReadBitsFromReader(Reader,2)<>SeqConfig.ChromaSamplePosition Then Exit;
 End;
 Value:=ReadBitFromReader(Reader);
 If Value<>Ord(SeqConfig.SeparateUVDeltAQ)Then Exit;
 Value:=ReadBitFromReader(Reader);
 If Value<>Ord(SeqConfig.FilmGrainParamsPresent)Then Exit;
 ValidateBuiltInSequenceHeaderPayload:=ValidateTrailingBits(Reader);
End;

Function ReadDeltaQFromReader(Var Reader:TBitReader):ShortInt;
Var
 Present:Boolean;
 Value:LongInt;
 SignBit:Byte;
Begin
 ReadDeltaQFromReader:=0;
 Present:=ReadBitFromReader(Reader)<>0;
 If not Present Then Exit;
 Value:=ReadBitsFromReader(Reader,6);
 SignBit:=ReadBitFromReader(Reader);
 If SignBit<>0 Then ReadDeltaQFromReader:=-Value
               Else ReadDeltaQFromReader:=Value;
End;

Function ValidateBuiltInFrameHeaderPayload(Const FrameHeaderOBU:TAV1ByteBuffer;
 Const SeqConfig:TAV1SequenceConfig;Const Image:TAVIFImage):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
 Reader:TBitReader;
 FrameWidth,FrameHeight,RenderWidth,RenderHeight:LongInt;
 RenderDifferent:Byte;
Begin
 ValidateBuiltInFrameHeaderPayload:=False;
 If not GetOBUPayloadRange(FrameHeaderOBU,obuFrameHeader,PayloadStart,
  PayloadSize)Then Exit;
 InitBitReader(Reader,FrameHeaderOBU,PayloadStart,PayloadSize);
 If not SeqConfig.ReducedStillPictureHeader Then Exit;
 If ReadBitFromReader(Reader)<>1 Then Exit; {disable_cdf_update}
 If ReadBitFromReader(Reader)<>0 Then Exit; {allow_screen_content_tools}
 If ReadBitFromReader(Reader)<>0 Then Exit; {frame_size_override_flag}
 FrameWidth:=ReadBitsFromReader(Reader,SeqConfig.FrameWidthBits)+1;
 FrameHeight:=ReadBitsFromReader(Reader,SeqConfig.FrameHeightBits)+1;
 If(FrameWidth<>Image.Width)or(FrameHeight<>Image.Height)Then Exit;
 RenderDifferent:=ReadBitFromReader(Reader);
 If RenderDifferent<>0 Then Begin
  RenderWidth:=ReadBitsFromReader(Reader,SeqConfig.FrameWidthBits)+1;
  RenderHeight:=ReadBitsFromReader(Reader,SeqConfig.FrameHeightBits)+1;
 End
  Else Begin
  RenderWidth:=FrameWidth;
  RenderHeight:=FrameHeight;
 End;
 If(RenderWidth<>Image.Width)or(RenderHeight<>Image.Height)Then Exit;
 If ReadBitFromReader(Reader)<>0 Then Exit; {allow_intrabc}
 If ReadBitsFromReader(Reader,6)<>0 Then Exit;
 If ReadBitsFromReader(Reader,6)<>0 Then Exit;
 If ReadBitsFromReader(Reader,6)<>0 Then Exit;
 If ReadBitsFromReader(Reader,6)<>0 Then Exit;
 If ReadBitsFromReader(Reader,3)<>0 Then Exit;
 If ReadBitFromReader(Reader)<>0 Then Exit; {loop_filter_delta_enabled}
 If ReadBitsFromReader(Reader,8)<>96 Then Exit;
 If ReadDeltaQFromReader(Reader)<>0 Then Exit;
 If ReadDeltaQFromReader(Reader)<>0 Then Exit;
 If ReadDeltaQFromReader(Reader)<>0 Then Exit;
 If ReadDeltaQFromReader(Reader)<>0 Then Exit;
 If ReadDeltaQFromReader(Reader)<>0 Then Exit;
 If ReadBitFromReader(Reader)<>0 Then Exit; {using_qmatrix}
 If ReadBitFromReader(Reader)<>0 Then Exit; {segmentation_enabled}
 If ReadBitFromReader(Reader)<>0 Then Exit; {delta_q_present}
 If ReadBitsFromReader(Reader,2)<>0 Then Exit; {cdef_bits}
 If ReadBitsFromReader(Reader,2)<>0 Then Exit; {lr y}
 If ReadBitsFromReader(Reader,2)<>0 Then Exit; {lr u}
 If ReadBitsFromReader(Reader,2)<>0 Then Exit; {lr v}
 If ReadBitFromReader(Reader)<>1 Then Exit; {uniform_tile_spacing}
 If ReadBitFromReader(Reader)<>0 Then Exit; {cols log2 stop}
 If ReadBitFromReader(Reader)<>0 Then Exit; {rows log2 stop}
 ValidateBuiltInFrameHeaderPayload:=ValidateTrailingBits(Reader);
End;

Function ValidateBuiltInAV1Scope(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig):Boolean;
Begin
 ValidateBuiltInAV1Scope:=False;
 If(Image.Width=0)or(Image.Height=0)Then Exit;
 If SeqConfig.SeqProfile<>AVIFInitialSeqProfile Then Exit;
 If not SeqConfig.StillPicture Then Exit;
 If not SeqConfig.ReducedStillPictureHeader Then Exit;
 If SeqConfig.MaxFrameWidth<>Image.Width Then Exit;
 If SeqConfig.MaxFrameHeight<>Image.Height Then Exit;
 If SeqConfig.HighBitDepth Then Exit;
 If SeqConfig.MonoChrome Then Exit;
 If SeqConfig.FilmGrainParamsPresent Then Exit;
 If SeqConfig.SeparateUVDeltAQ Then Exit;
 If SeqConfig.ColorRange<>1 Then Exit;
 ValidateBuiltInAV1Scope:=True;
End;

Function ValidateBuiltInAV1DecoderPath(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;Const Bitstream:TAV1Bitstream;
 Const Container:TAVIFContainer;Var Reason:String):Boolean;
Var
 ExpectedSize:LongInt;
Begin
 ValidateBuiltInAV1DecoderPath:=False;
 Reason:='';
 If not AV1BitstreamIsDecoderReady Then Begin
  Reason:='validation AV1 integree inactive';
  Exit;
 End;
 If not ValidateBuiltInAV1Scope(Image,SeqConfig)Then Begin
  Reason:='perimetre AV1 initial non respecte';
  Exit;
 End;
 If not ValidateOBUHeader(Bitstream.SequenceHeader,obuSequenceHeader)Then Begin
  Reason:='Sequence Header OBU invalide';
  Exit;
 End;
 If not ValidateOBUHeader(Bitstream.FrameHeader,obuFrameHeader)Then Begin
  Reason:='Frame Header OBU invalide';
  Exit;
 End;
 If not ValidateOBUHeader(Bitstream.TileGroup,obuTileGroup)Then Begin
  Reason:='Tile Group OBU invalide';
  Exit;
 End;
 If not ValidateBuiltInSequenceHeaderPayload(Bitstream.SequenceHeader,
  SeqConfig)Then Begin
  Reason:='Sequence Header non relisible strictement';
  Exit;
 End;
 If not ValidateBuiltInFrameHeaderPayload(Bitstream.FrameHeader,SeqConfig,
  Image)Then Begin
  Reason:='Frame Header non relisible strictement';
  Exit;
 End;
 If not ValidateBuiltInTileGroupPayload(Bitstream.TileGroup)Then Begin
  Reason:='Tile Group interne invalide';
  Exit;
 End;
 ExpectedSize:=Bitstream.SequenceHeader.Size+Bitstream.FrameHeader.Size+
  Bitstream.TileGroup.Size;
 If Bitstream.Combined.Size<>ExpectedSize Then Begin
  Reason:='assemblage OBU incoherent';
  Exit;
 End;
 If not ValidateAV1OBUSequenceInRange(Bitstream.Combined,0,
  Bitstream.Combined.Size)Then Begin
  Reason:='ordre OBU non conforme';
  Exit;
 End;
 If not ValidateAVIFRegressionStructure(Container,Image,SeqConfig,
  Bitstream.Combined.Size)Then Begin
  Reason:='structure AVIF ISO-BMFF non conforme';
  Exit;
 End;
 ValidateBuiltInAV1DecoderPath:=True;
End;

Function BuildAV1Bitstream(Const SequenceOBU,FrameHeaderOBU,TileGroupOBU:TAV1ByteBuffer;
 Var Bitstream:TAV1Bitstream):Boolean;
Begin
 BuildAV1Bitstream:=False;
 InitAV1Bitstream(Bitstream);
 If not ValidateOBUHeader(SequenceOBU,obuSequenceHeader)Then Exit;
 If not ValidateOBUHeader(FrameHeaderOBU,obuFrameHeader)Then Exit;
 If not ValidateOBUHeader(TileGroupOBU,obuTileGroup)Then Exit;
 If not CopyAV1Buffer(SequenceOBU,Bitstream.SequenceHeader)Then Exit;
 If not CopyAV1Buffer(FrameHeaderOBU,Bitstream.FrameHeader)Then Exit;
 If not CopyAV1Buffer(TileGroupOBU,Bitstream.TileGroup)Then Exit;
 If not AllocateAV1ByteBuffer(Bitstream.Combined,AV1MaxOBUBytes)Then Exit;
 If not AV1BufferAppendBuffer(Bitstream.Combined,Bitstream.SequenceHeader)Then Exit;
 If not AV1BufferAppendBuffer(Bitstream.Combined,Bitstream.FrameHeader)Then Exit;
 If not AV1BufferAppendBuffer(Bitstream.Combined,Bitstream.TileGroup)Then Exit;
 BuildAV1Bitstream:=True;
End;

Procedure DumpAV1OBUSummary(Const Bitstream:TAV1Bitstream);
Begin
 If Bitstream.Combined.Size=0 Then Begin
 End;
End;

Procedure InitAVIFContainer(Var Container:TAVIFContainer);
Begin
 InitAV1ByteBuffer(Container.FileData);
 Container.IlocPatch.OffsetFieldPos:=0;
 Container.IlocPatch.LengthFieldPos:=0;
 Container.IlocPatch.OffsetSize:=0;
 Container.IlocPatch.LengthSize:=0;
 Container.IlocPatch.IlocBoxStart:=0;
 Container.IlocPatch.IlocBoxEnd:=0;
 Container.IlocPatch.MdatBoxOffset:=0;
 Container.IlocPatch.MdatHeaderSize:=0;
 Container.IlocPatch.MdatDataOffset:=0;
 Container.IlocPatch.MdatDataLength:=0;
End;

Procedure FreeAVIFContainer(Var Container:TAVIFContainer);
Begin
 FreeAV1ByteBuffer(Container.FileData);
 InitAVIFContainer(Container);
End;

Procedure InitISOBoxWriter(Var Writer:TISOBoxWriter;Var Buffer:TAV1ByteBuffer);
Begin
 Writer.Buffer:=@Buffer;
 Writer.Failed:=False;
End;

Procedure BoxWriteByte(Var Writer:TISOBoxWriter;Value:Byte);
Begin
 If Writer.Failed Then Exit;
 If(Writer.Buffer=Nil)or(not AV1BufferAppendByte(Writer.Buffer^,Value))Then
  Writer.Failed:=True;
End;

Procedure BoxWriteBE16(Var Writer:TISOBoxWriter;Value:Word);
Begin
 BoxWriteByte(Writer,Byte((Value shr 8)and $FF));
 BoxWriteByte(Writer,Byte(Value and $FF));
End;

Procedure BoxWriteBE32(Var Writer:TISOBoxWriter;Value:LongInt);
Begin
 BoxWriteByte(Writer,Byte((Value shr 24)and $FF));
 BoxWriteByte(Writer,Byte((Value shr 16)and $FF));
 BoxWriteByte(Writer,Byte((Value shr 8)and $FF));
 BoxWriteByte(Writer,Byte(Value and $FF));
End;

Procedure BoxWriteFourCC(Var Writer:TISOBoxWriter;Code:String);
Var
 I:Byte;
Begin
 For I:=1 to 4 Do Begin
  If I<=Length(Code)Then BoxWriteByte(Writer,Ord(Code[I]))
                    Else BoxWriteByte(Writer,Ord(' '));
 End;
End;

Procedure BoxWriteCString(Var Writer:TISOBoxWriter;Text:String);
Var
 I:Byte;
Begin
 For I:=1 to Length(Text)Do BoxWriteByte(Writer,Ord(Text[I]));
 BoxWriteByte(Writer,0);
End;

Procedure WriteBoxHeader(Var Writer:TISOBoxWriter;Size:LongInt;FourCC:String);
Begin
 BoxWriteBE32(Writer,Size);
 BoxWriteFourCC(Writer,FourCC);
End;

Function BeginISOBox(Var Writer:TISOBoxWriter;FourCC:String;Var StartPos:LongInt):Boolean;
Begin
 BeginISOBox:=False;
 If(Writer.Buffer=Nil)or(Writer.Failed)Then Exit;
 StartPos:=Writer.Buffer^.Size;
 WriteBoxHeader(Writer,0,FourCC);
 BeginISOBox:=not Writer.Failed;
End;

Procedure PatchBE32(Var Buffer:TAV1ByteBuffer;Pos:LongInt;Value:LongInt);
Begin
 If(Buffer.Data=Nil)or(LongInt(Pos)+3>=Buffer.Size)Then Exit;
 Buffer.Data^[Pos]:=Byte((Value shr 24)and $FF);
 Buffer.Data^[Pos+1]:=Byte((Value shr 16)and $FF);
 Buffer.Data^[Pos+2]:=Byte((Value shr 8)and $FF);
 Buffer.Data^[Pos+3]:=Byte(Value and $FF);
End;

Function PatchBE32Checked(Var Buffer:TAV1ByteBuffer;Pos:LongInt;Value:LongInt):Boolean;
Begin
 PatchBE32Checked:=False;
 If(Buffer.Data=Nil)or(LongInt(Pos)+3>=Buffer.Size)Then Exit;
 PatchBE32(Buffer,Pos,Value);
 PatchBE32Checked:=True;
End;

Function ReadBE32(Const Buffer:TAV1ByteBuffer;Pos:LongInt;Var Value:LongInt):Boolean;
Begin
 ReadBE32:=False;
 Value:=0;
 If(Buffer.Data=Nil)or(LongInt(Pos)+3>=Buffer.Size)Then Exit;
 Value:=(LongInt(Buffer.Data^[Pos])shl 24)+
  (LongInt(Buffer.Data^[Pos+1])shl 16)+
  (LongInt(Buffer.Data^[Pos+2])shl 8)+
  LongInt(Buffer.Data^[Pos+3]);
 ReadBE32:=True;
End;

Function ReadBE16(Const Buffer:TAV1ByteBuffer;Pos:LongInt;Var Value:Word):Boolean;
Begin
 ReadBE16:=False;
 Value:=0;
 If(Buffer.Data=Nil)or(LongInt(Pos)+1>=Buffer.Size)Then Exit;
 Value:=(Word(Buffer.Data^[Pos])shl 8)+Word(Buffer.Data^[Pos+1]);
 ReadBE16:=True;
End;

Function BufferHasFourCC(Const Buffer:TAV1ByteBuffer;Pos:LongInt;Code:String):Boolean;
Var
 I:Byte;
Begin
 BufferHasFourCC:=False;
 If(Buffer.Data=Nil)or(LongInt(Pos)+3>=Buffer.Size)Then Exit;
 For I:=1 to 4 Do
  If Buffer.Data^[Pos+I-1]<>Ord(Code[I])Then Exit;
 BufferHasFourCC:=True;
End;

Function FindBoxInRange(Const Buffer:TAV1ByteBuffer;StartPos,EndPos:LongInt;
 Code:String;Var BoxOffset:LongInt;Var BoxSize:LongInt):Boolean;
Var
 Pos:LongInt;
 SizeValue:LongInt;
Begin
 FindBoxInRange:=False;
 BoxOffset:=0;
 BoxSize:=0;
 Pos:=StartPos;
 While LongInt(Pos)+8<=EndPos Do Begin
  If not ReadBE32(Buffer,Pos,SizeValue)Then Exit;
  If SizeValue<8 Then Exit;
  If LongInt(Pos)+SizeValue>EndPos Then Exit;
  If BufferHasFourCC(Buffer,Pos+4,Code)Then Begin
   BoxOffset:=Pos;
   BoxSize:=SizeValue;
   FindBoxInRange:=True;
   Exit;
  End;
  Pos:=Pos+SizeValue;
 End;
End;

Function ValidateBoxListEnd(Const Buffer:TAV1ByteBuffer;StartPos,EndPos:LongInt):Boolean;
Var
 Pos:LongInt;
 SizeValue:LongInt;
Begin
 ValidateBoxListEnd:=False;
 Pos:=StartPos;
 While Pos<EndPos Do Begin
  If LongInt(Pos)+8>EndPos Then Exit;
  If not ReadBE32(Buffer,Pos,SizeValue)Then Exit;
  If SizeValue<8 Then Exit;
  If LongInt(Pos)+SizeValue>EndPos Then Exit;
  Pos:=Pos+SizeValue;
 End;
 ValidateBoxListEnd:=Pos=EndPos;
End;

Function CountBoxInRange(Const Buffer:TAV1ByteBuffer;StartPos,EndPos:LongInt;
 Code:String;Var Count:Byte):Boolean;
Var
 Pos:LongInt;
 SizeValue:LongInt;
Begin
 CountBoxInRange:=False;
 Count:=0;
 Pos:=StartPos;
 While Pos<EndPos Do Begin
  If LongInt(Pos)+8>EndPos Then Exit;
  If not ReadBE32(Buffer,Pos,SizeValue)Then Exit;
  If SizeValue<8 Then Exit;
  If LongInt(Pos)+SizeValue>EndPos Then Exit;
  If BufferHasFourCC(Buffer,Pos+4,Code)Then
   If Count<255 Then Inc(Count)Else Exit;
  Pos:=Pos+SizeValue;
 End;
 CountBoxInRange:=Pos=EndPos;
End;

Function RequireSingleBoxInRange(Const Buffer:TAV1ByteBuffer;StartPos,EndPos:LongInt;
 Code:String;Var BoxOffset,BoxSize:LongInt):Boolean;
Var
 Count:Byte;
Begin
 RequireSingleBoxInRange:=False;
 If not CountBoxInRange(Buffer,StartPos,EndPos,Code,Count)Then Exit;
 If Count<>1 Then Exit;
 RequireSingleBoxInRange:=FindBoxInRange(Buffer,StartPos,EndPos,Code,
  BoxOffset,BoxSize);
End;

Function EndISOBox(Var Writer:TISOBoxWriter;StartPos:LongInt):Boolean;
Var
 BoxSize:LongInt;
Begin
 EndISOBox:=False;
 If(Writer.Buffer=Nil)or(Writer.Failed)Then Exit;
 BoxSize:=LongInt(Writer.Buffer^.Size)-StartPos;
 If BoxSize<8 Then Exit;
 PatchBE32(Writer.Buffer^,StartPos,BoxSize);
 EndISOBox:=True;
End;

Procedure BoxWriteFullBoxHeader(Var Writer:TISOBoxWriter;Version:Byte;Flags:LongInt);
Begin
 BoxWriteByte(Writer,Version);
 BoxWriteByte(Writer,Byte((Flags shr 16)and $FF));
 BoxWriteByte(Writer,Byte((Flags shr 8)and $FF));
 BoxWriteByte(Writer,Byte(Flags and $FF));
End;

Function WriteFtypBox(Var Writer:TISOBoxWriter):Boolean;
Var
 StartPos:LongInt;
Begin
 WriteFtypBox:=False;
 If not BeginISOBox(Writer,'ftyp',StartPos)Then Exit;
 BoxWriteFourCC(Writer,'avif');
 BoxWriteBE32(Writer,0);
 BoxWriteFourCC(Writer,'avif');
 BoxWriteFourCC(Writer,'mif1');
 BoxWriteFourCC(Writer,'miaf');
 WriteFtypBox:=EndISOBox(Writer,StartPos);
End;

Function WriteHdlrBox(Var Writer:TISOBoxWriter):Boolean;
Var
 StartPos:LongInt;
Begin
 WriteHdlrBox:=False;
 If not BeginISOBox(Writer,'hdlr',StartPos)Then Exit;
 BoxWriteFullBoxHeader(Writer,0,0);
 BoxWriteBE32(Writer,0);
 BoxWriteFourCC(Writer,'pict');
 BoxWriteBE32(Writer,0);
 BoxWriteBE32(Writer,0);
 BoxWriteBE32(Writer,0);
 BoxWriteCString(Writer,'CloneDRAW AVIF');
 WriteHdlrBox:=EndISOBox(Writer,StartPos);
End;

Function WritePitmBox(Var Writer:TISOBoxWriter):Boolean;
Var
 StartPos:LongInt;
Begin
 WritePitmBox:=False;
 If not BeginISOBox(Writer,'pitm',StartPos)Then Exit;
 BoxWriteFullBoxHeader(Writer,0,0);
 BoxWriteBE16(Writer,AVIFInitialItemID);
 WritePitmBox:=EndISOBox(Writer,StartPos);
End;

Function WriteIlocBox(Var Writer:TISOBoxWriter;
 Var PatchInfo:TAVIFIlocPatchInfo):Boolean;
Var
 StartPos:LongInt;
Begin
 WriteIlocBox:=False;
 If not BeginISOBox(Writer,'iloc',StartPos)Then Exit;
 PatchInfo.IlocBoxStart:=StartPos;
 BoxWriteFullBoxHeader(Writer,0,0);
 PatchInfo.OffsetSize:=4;
 PatchInfo.LengthSize:=4;
 BoxWriteByte(Writer,$44); {offset_size=4, length_size=4}
 BoxWriteByte(Writer,$00); {base_offset_size=0, index_size=0}
 BoxWriteBE16(Writer,1);   {item_count}
 BoxWriteBE16(Writer,AVIFInitialItemID);
 BoxWriteBE16(Writer,0);   {data_reference_index}
 BoxWriteBE16(Writer,1);   {extent_count}
 If Writer.Buffer<>Nil Then PatchInfo.OffsetFieldPos:=Writer.Buffer^.Size;
 BoxWriteBE32(Writer,0);   {extent_offset, patche apres mdat}
 If Writer.Buffer<>Nil Then PatchInfo.LengthFieldPos:=Writer.Buffer^.Size;
 BoxWriteBE32(Writer,0);   {extent_length, patche apres mdat}
 WriteIlocBox:=EndISOBox(Writer,StartPos);
 If WriteIlocBox and(Writer.Buffer<>Nil)Then
  PatchInfo.IlocBoxEnd:=Writer.Buffer^.Size;
End;

Function WriteIinfBox(Var Writer:TISOBoxWriter):Boolean;
Var
 IinfStart,InfeStart:LongInt;
Begin
 WriteIinfBox:=False;
 If not BeginISOBox(Writer,'iinf',IinfStart)Then Exit;
 BoxWriteFullBoxHeader(Writer,0,0);
 BoxWriteBE16(Writer,1);
 If not BeginISOBox(Writer,'infe',InfeStart)Then Exit;
 BoxWriteFullBoxHeader(Writer,2,0);
 BoxWriteBE16(Writer,AVIFInitialItemID);
 BoxWriteBE16(Writer,0);
 BoxWriteFourCC(Writer,'av01');
 BoxWriteCString(Writer,'');
 If not EndISOBox(Writer,InfeStart)Then Exit;
 WriteIinfBox:=EndISOBox(Writer,IinfStart);
End;

Procedure InitItemPropertyTable(Var Table:TItemPropertyTable);
Begin
 FillChar(Table,SizeOf(Table),0);
End;

Function RegisterItemProperty(Var Table:TItemPropertyTable;FourCC:String;
 IsEssential:Boolean;Offset:LongInt):Boolean;
Var
 NewIndex:Byte;
Begin
 RegisterItemProperty:=False;
 If Table.Count>=AVIFMaxItemProperties Then Exit;
 NewIndex:=Table.Count+1;
 Table.Items[NewIndex].PropertyIndex:=NewIndex;
 Table.Items[NewIndex].FourCC:=Copy(FourCC,1,4);
 Table.Items[NewIndex].IsEssential:=IsEssential;
 Table.Items[NewIndex].Offset:=Offset;
 Table.Count:=NewIndex;
 RegisterItemProperty:=True;
End;

Function WriteIspeProperty(Var Writer:TISOBoxWriter;Const Image:TAVIFImage;
 Var Table:TItemPropertyTable):Boolean;
Var
 StartPos:LongInt;
Begin
 WriteIspeProperty:=False;
 If not BeginISOBox(Writer,'ispe',StartPos)Then Exit;
 If not RegisterItemProperty(Table,'ispe',True,StartPos)Then Exit;
 BoxWriteFullBoxHeader(Writer,0,0);
 BoxWriteBE32(Writer,Image.Width);
 BoxWriteBE32(Writer,Image.Height);
 WriteIspeProperty:=EndISOBox(Writer,StartPos);
End;

Function WritePixiProperty(Var Writer:TISOBoxWriter;Const Image:TAVIFImage;
 Var Table:TItemPropertyTable):Boolean;
Var
 StartPos:LongInt;
Begin
 WritePixiProperty:=False;
 If not BeginISOBox(Writer,'pixi',StartPos)Then Exit;
 If not RegisterItemProperty(Table,'pixi',True,StartPos)Then Exit;
 BoxWriteFullBoxHeader(Writer,0,0);
 BoxWriteByte(Writer,3);
 BoxWriteByte(Writer,Image.BitDepth);
 BoxWriteByte(Writer,Image.BitDepth);
 BoxWriteByte(Writer,Image.BitDepth);
 WritePixiProperty:=EndISOBox(Writer,StartPos);
End;

Function WriteAv1CProperty(Var Writer:TISOBoxWriter;
 Const SeqConfig:TAV1SequenceConfig;Var Table:TItemPropertyTable):Boolean;
Var
 StartPos:LongInt;
 ConfigByte:Byte;
Begin
 WriteAv1CProperty:=False;
 If not BeginISOBox(Writer,'av1C',StartPos)Then Exit;
 If not RegisterItemProperty(Table,'av1C',True,StartPos)Then Exit;
 BoxWriteByte(Writer,$81); {marker=1, version=1}
 BoxWriteByte(Writer,Byte((SeqConfig.SeqProfile shl 5)or
  (SeqConfig.SeqLevelIdx0 and $1F)));
 ConfigByte:=Byte((SeqConfig.SubsamplingX and 1)shl 3)or
  Byte((SeqConfig.SubsamplingY and 1)shl 2)or
  Byte(SeqConfig.ChromaSamplePosition and 3);
 If SeqConfig.HighBitDepth Then ConfigByte:=ConfigByte or $40;
 If SeqConfig.MonoChrome Then ConfigByte:=ConfigByte or $10;
 BoxWriteByte(Writer,ConfigByte);
 BoxWriteByte(Writer,0); {initial_presentation_delay_present=0}
 WriteAv1CProperty:=EndISOBox(Writer,StartPos);
End;

Function WriteColrProperty(Var Writer:TISOBoxWriter;Const Image:TAVIFImage;
 Var Table:TItemPropertyTable):Boolean;
Var
 StartPos:LongInt;
 RangeByte:Byte;
Begin
 WriteColrProperty:=False;
 If not BeginISOBox(Writer,'colr',StartPos)Then Exit;
 If not RegisterItemProperty(Table,'colr',False,StartPos)Then Exit;
 BoxWriteFourCC(Writer,'nclx');
 BoxWriteBE16(Writer,Image.ColorPrimaries);
 BoxWriteBE16(Writer,Image.TransferCharacteristics);
 BoxWriteBE16(Writer,Image.MatrixCoefficients);
 If Image.RangeMode=rmFullRange Then RangeByte:=$80
                               Else RangeByte:=0;
 BoxWriteByte(Writer,RangeByte);
 WriteColrProperty:=EndISOBox(Writer,StartPos);
End;

Function WriteIpcoBox(Var Writer:TISOBoxWriter;Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;
 Var Table:TItemPropertyTable):Boolean;
Var
 StartPos:LongInt;
Begin
 WriteIpcoBox:=False;
 If not BeginISOBox(Writer,'ipco',StartPos)Then Exit;
 InitItemPropertyTable(Table);
 If not WriteIspeProperty(Writer,Image,Table)Then Exit;
 If not WritePixiProperty(Writer,Image,Table)Then Exit;
 If not WriteAv1CProperty(Writer,SeqConfig,Table)Then Exit;
 If not WriteColrProperty(Writer,Image,Table)Then Exit;
 WriteIpcoBox:=EndISOBox(Writer,StartPos);
End;

Function WriteIpmaBox(Var Writer:TISOBoxWriter;
 Const Table:TItemPropertyTable):Boolean;
Var
 StartPos:LongInt;
 I:Byte;
 Association:Byte;
Begin
 WriteIpmaBox:=False;
 If Table.Count=0 Then Exit;
 If not BeginISOBox(Writer,'ipma',StartPos)Then Exit;
 BoxWriteFullBoxHeader(Writer,0,0);
 BoxWriteBE32(Writer,1); {entry_count}
 BoxWriteBE16(Writer,AVIFInitialItemID);
 BoxWriteByte(Writer,Table.Count);
 For I:=1 to Table.Count Do Begin
  Association:=Table.Items[I].PropertyIndex and $7F;
  If Table.Items[I].IsEssential Then Association:=Association or $80;
  BoxWriteByte(Writer,Association);
 End;
 WriteIpmaBox:=EndISOBox(Writer,StartPos);
End;

Function WriteIprpBox(Var Writer:TISOBoxWriter;
 Const Image:TAVIFImage;Const SeqConfig:TAV1SequenceConfig):Boolean;
Var
 StartPos:LongInt;
 Table:TItemPropertyTable;
Begin
 WriteIprpBox:=False;
 If not BeginISOBox(Writer,'iprp',StartPos)Then Exit;
 InitItemPropertyTable(Table);
 If not WriteIpcoBox(Writer,Image,SeqConfig,Table)Then Exit;
 If not WriteIpmaBox(Writer,Table)Then Exit;
 WriteIprpBox:=EndISOBox(Writer,StartPos);
End;

Function WriteMetaBox(Var Writer:TISOBoxWriter;
 Var PatchInfo:TAVIFIlocPatchInfo;Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig):Boolean;
Var
 StartPos:LongInt;
Begin
 WriteMetaBox:=False;
 If not BeginISOBox(Writer,'meta',StartPos)Then Exit;
 BoxWriteFullBoxHeader(Writer,0,0);
 If not WriteHdlrBox(Writer)Then Exit;
 If not WritePitmBox(Writer)Then Exit;
 If not WriteIlocBox(Writer,PatchInfo)Then Exit;
 If not WriteIinfBox(Writer)Then Exit;
 If not WriteIprpBox(Writer,Image,SeqConfig)Then Exit;
 WriteMetaBox:=EndISOBox(Writer,StartPos);
End;

Function WriteAVIFMdat(Var Writer:TISOBoxWriter;Const AV1Data:TAV1ByteBuffer;
 Var DataOffset,DataLength:LongInt;Var BoxOffset:LongInt;
 Var HeaderSize:Byte):Boolean;
Var
 StartPos:LongInt;
 BoxSize:LongInt;
Begin
 WriteAVIFMdat:=False;
 DataOffset:=0;
 DataLength:=0;
 BoxOffset:=0;
 HeaderSize:=8;
 If(Writer.Buffer=Nil)or(Writer.Failed)Then Exit;
 If(AV1Data.Data=Nil)or(AV1Data.Size=0)Then Exit;
 StartPos:=Writer.Buffer^.Size;
 BoxSize:=LongInt(HeaderSize)+AV1Data.Size;
 If BoxSize<=HeaderSize Then Exit;
 If LongInt(StartPos)+BoxSize>Writer.Buffer^.Capacity Then Exit;
 BoxOffset:=StartPos;
 DataOffset:=LongInt(StartPos)+HeaderSize;
 DataLength:=AV1Data.Size;
 WriteBoxHeader(Writer,BoxSize,'mdat');
 If not AV1BufferAppendBuffer(Writer.Buffer^,AV1Data)Then Begin
  Writer.Failed:=True;
  Exit;
 End;
 If Writer.Buffer^.Size<>LongInt(StartPos)+BoxSize Then Begin
  Writer.Failed:=True;
  Exit;
 End;
 WriteAVIFMdat:=not Writer.Failed;
End;

Function WriteMdatBox(Var Writer:TISOBoxWriter;Const Bitstream:TAV1Bitstream;
 Var PatchInfo:TAVIFIlocPatchInfo):Boolean;
Begin
 WriteMdatBox:=WriteAVIFMdat(Writer,Bitstream.Combined,
  PatchInfo.MdatDataOffset,PatchInfo.MdatDataLength,
  PatchInfo.MdatBoxOffset,PatchInfo.MdatHeaderSize);
End;

Function IlocPatchPositionsAreValid(Const PatchInfo:TAVIFIlocPatchInfo):Boolean;
Begin
 IlocPatchPositionsAreValid:=False;
 If(PatchInfo.OffsetSize<>4)or(PatchInfo.LengthSize<>4)Then Exit;
 If(PatchInfo.IlocBoxEnd<=PatchInfo.IlocBoxStart)Then Exit;
 If(PatchInfo.OffsetFieldPos<PatchInfo.IlocBoxStart)or
   (LongInt(PatchInfo.OffsetFieldPos)+PatchInfo.OffsetSize>PatchInfo.IlocBoxEnd)Then Exit;
 If(PatchInfo.LengthFieldPos<PatchInfo.IlocBoxStart)or
   (LongInt(PatchInfo.LengthFieldPos)+PatchInfo.LengthSize>PatchInfo.IlocBoxEnd)Then Exit;
 IlocPatchPositionsAreValid:=True;
End;

Function ValidateAVIFContainer(Const Container:TAVIFContainer;
 AV1DataSize:LongInt):Boolean;
Var
 DataEnd,MdatBoxSize:LongInt;
 PatchedOffset,PatchedLength:LongInt;
Begin
 ValidateAVIFContainer:=False;
 If(Container.FileData.Data=Nil)or(Container.FileData.Size<32)Then Exit;
 If not IlocPatchPositionsAreValid(Container.IlocPatch)Then Exit;
 If(Container.IlocPatch.MdatDataOffset<=0)or
   (Container.IlocPatch.MdatDataLength<=0)Then Exit;
 If Container.IlocPatch.MdatHeaderSize<>8 Then Exit;
 If Container.IlocPatch.MdatDataLength<>AV1DataSize Then Exit;
 If Container.IlocPatch.MdatDataOffset<>
  LongInt(Container.IlocPatch.MdatBoxOffset)+Container.IlocPatch.MdatHeaderSize Then Exit;
 If not BufferHasFourCC(Container.FileData,Container.IlocPatch.MdatBoxOffset+4,'mdat')Then Exit;
 If not ReadBE32(Container.FileData,Container.IlocPatch.MdatBoxOffset,MdatBoxSize)Then Exit;
 If MdatBoxSize<>Container.IlocPatch.MdatHeaderSize+Container.IlocPatch.MdatDataLength Then Exit;
 DataEnd:=Container.IlocPatch.MdatDataOffset+Container.IlocPatch.MdatDataLength;
 If DataEnd>Container.FileData.Size Then Exit;
 If not ReadBE32(Container.FileData,Container.IlocPatch.OffsetFieldPos,PatchedOffset)Then Exit;
 If not ReadBE32(Container.FileData,Container.IlocPatch.LengthFieldPos,PatchedLength)Then Exit;
 If PatchedOffset<>Container.IlocPatch.MdatDataOffset Then Exit;
 If PatchedLength<>Container.IlocPatch.MdatDataLength Then Exit;
 ValidateAVIFContainer:=True;
End;

Function ValidateFtypBox(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt):Boolean;
Begin
 ValidateFtypBox:=False;
 If BoxSize<24 Then Exit;
 If not BufferHasFourCC(Buffer,BoxOffset+8,'avif')Then Exit;
 If not BufferHasFourCC(Buffer,BoxOffset+16,'avif')Then Exit;
 If not BufferHasFourCC(Buffer,BoxOffset+20,'mif1')Then Exit;
 ValidateFtypBox:=True;
End;

Function ValidateHdlrBox(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt):Boolean;
Begin
 ValidateHdlrBox:=False;
 If BoxSize<33 Then Exit;
 ValidateHdlrBox:=BufferHasFourCC(Buffer,BoxOffset+16,'pict');
End;

Function ValidatePitmBox(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt):Boolean;
Var
 ItemID:Word;
Begin
 ValidatePitmBox:=False;
 If BoxSize<14 Then Exit;
 If not ReadBE16(Buffer,BoxOffset+12,ItemID)Then Exit;
 ValidatePitmBox:=ItemID=AVIFInitialItemID;
End;

Function ValidateIinfBox(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt):Boolean;
Var
 EntryCount,ItemID:Word;
 InfeOffset:LongInt;
 InfeSize:LongInt;
Begin
 ValidateIinfBox:=False;
 If BoxSize<35 Then Exit;
 If not ReadBE16(Buffer,BoxOffset+12,EntryCount)Then Exit;
 If EntryCount<>1 Then Exit;
 If not FindBoxInRange(Buffer,BoxOffset+14,BoxOffset+BoxSize,
  'infe',InfeOffset,InfeSize)Then Exit;
 If InfeSize<21 Then Exit;
 If Buffer.Data^[InfeOffset+8]<>2 Then Exit;
 If not ReadBE16(Buffer,InfeOffset+12,ItemID)Then Exit;
 If ItemID<>AVIFInitialItemID Then Exit;
 ValidateIinfBox:=BufferHasFourCC(Buffer,InfeOffset+16,'av01');
End;

Function ValidateIlocBox(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt;Const PatchInfo:TAVIFIlocPatchInfo):Boolean;
Var
 ItemCount,ItemID,DataReferenceIndex,ExtentCount:Word;
 OffsetSizeLengthSize,BaseAndIndexSize:Byte;
 OffsetValue,LengthValue:LongInt;
Begin
 ValidateIlocBox:=False;
 If BoxSize<30 Then Exit;
 If(BoxOffset<>PatchInfo.IlocBoxStart)or
  (BoxOffset+BoxSize<>PatchInfo.IlocBoxEnd)Then Exit;
 If Buffer.Data^[BoxOffset+8]<>0 Then Exit; {version}
 If(Buffer.Data^[BoxOffset+9]<>0)or(Buffer.Data^[BoxOffset+10]<>0)or
  (Buffer.Data^[BoxOffset+11]<>0)Then Exit;
 OffsetSizeLengthSize:=Buffer.Data^[BoxOffset+12];
 BaseAndIndexSize:=Buffer.Data^[BoxOffset+13];
 If OffsetSizeLengthSize<>$44 Then Exit;
 If BaseAndIndexSize<>$00 Then Exit;
 If not ReadBE16(Buffer,BoxOffset+14,ItemCount)Then Exit;
 If ItemCount<>1 Then Exit;
 If not ReadBE16(Buffer,BoxOffset+16,ItemID)Then Exit;
 If ItemID<>AVIFInitialItemID Then Exit;
 If not ReadBE16(Buffer,BoxOffset+18,DataReferenceIndex)Then Exit;
 If DataReferenceIndex<>0 Then Exit;
 If not ReadBE16(Buffer,BoxOffset+20,ExtentCount)Then Exit;
 If ExtentCount<>1 Then Exit;
 If PatchInfo.OffsetFieldPos<>BoxOffset+22 Then Exit;
 If PatchInfo.LengthFieldPos<>BoxOffset+26 Then Exit;
 If not ReadBE32(Buffer,PatchInfo.OffsetFieldPos,OffsetValue)Then Exit;
 If not ReadBE32(Buffer,PatchInfo.LengthFieldPos,LengthValue)Then Exit;
 If OffsetValue<>PatchInfo.MdatDataOffset Then Exit;
 If LengthValue<>PatchInfo.MdatDataLength Then Exit;
 ValidateIlocBox:=True;
End;

Function ValidateIspeProperty(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt;Const Image:TAVIFImage):Boolean;
Var
 WidthValue,HeightValue:LongInt;
Begin
 ValidateIspeProperty:=False;
 If BoxSize<20 Then Exit;
 If not ReadBE32(Buffer,BoxOffset+12,WidthValue)Then Exit;
 If not ReadBE32(Buffer,BoxOffset+16,HeightValue)Then Exit;
 ValidateIspeProperty:=(WidthValue=Image.Width)and(HeightValue=Image.Height);
End;

Function ValidatePixiProperty(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt;Const Image:TAVIFImage):Boolean;
Begin
 ValidatePixiProperty:=False;
 If BoxSize<16 Then Exit;
 If Buffer.Data^[BoxOffset+12]<>3 Then Exit;
 ValidatePixiProperty:=(Buffer.Data^[BoxOffset+13]=Image.BitDepth)and
  (Buffer.Data^[BoxOffset+14]=Image.BitDepth)and
  (Buffer.Data^[BoxOffset+15]=Image.BitDepth);
End;

Function ValidateAv1CProperty(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt;Const SeqConfig:TAV1SequenceConfig):Boolean;
Var
 ProfileLevel,ConfigByte,ExpectedConfig:Byte;
Begin
 ValidateAv1CProperty:=False;
 If BoxSize<12 Then Exit;
 If Buffer.Data^[BoxOffset+8]<>$81 Then Exit;
 ProfileLevel:=Byte((SeqConfig.SeqProfile shl 5)or(SeqConfig.SeqLevelIdx0 and $1F));
 If Buffer.Data^[BoxOffset+9]<>ProfileLevel Then Exit;
 ExpectedConfig:=Byte((SeqConfig.SubsamplingX and 1)shl 3)or
  Byte((SeqConfig.SubsamplingY and 1)shl 2)or
  Byte(SeqConfig.ChromaSamplePosition and 3);
 If SeqConfig.HighBitDepth Then ExpectedConfig:=ExpectedConfig or $40;
 If SeqConfig.MonoChrome Then ExpectedConfig:=ExpectedConfig or $10;
 ConfigByte:=Buffer.Data^[BoxOffset+10];
 If ConfigByte<>ExpectedConfig Then Exit;
 ValidateAv1CProperty:=Buffer.Data^[BoxOffset+11]=0;
End;

Function ValidateColrProperty(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt;Const Image:TAVIFImage):Boolean;
Var
 Primaries,Transfer,Matrix:Word;
 RangeByte:Byte;
Begin
 ValidateColrProperty:=False;
 If BoxSize<19 Then Exit;
 If not BufferHasFourCC(Buffer,BoxOffset+8,'nclx')Then Exit;
 If not ReadBE16(Buffer,BoxOffset+12,Primaries)Then Exit;
 If not ReadBE16(Buffer,BoxOffset+14,Transfer)Then Exit;
 If not ReadBE16(Buffer,BoxOffset+16,Matrix)Then Exit;
 RangeByte:=0;
 If Image.RangeMode=rmFullRange Then RangeByte:=$80;
 ValidateColrProperty:=(Primaries=Image.ColorPrimaries)and
  (Transfer=Image.TransferCharacteristics)and
  (Matrix=Image.MatrixCoefficients)and(Buffer.Data^[BoxOffset+18]=RangeByte);
End;

Function ValidateIpmaBox(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt):Boolean;
Var
 EntryCount:LongInt;
 ItemID:Word;
Begin
 ValidateIpmaBox:=False;
 If BoxSize<23 Then Exit;
 If not ReadBE32(Buffer,BoxOffset+12,EntryCount)Then Exit;
 If EntryCount<>1 Then Exit;
 If not ReadBE16(Buffer,BoxOffset+16,ItemID)Then Exit;
 If ItemID<>AVIFInitialItemID Then Exit;
 If Buffer.Data^[BoxOffset+18]<>4 Then Exit;
 ValidateIpmaBox:=(Buffer.Data^[BoxOffset+19]=$81)and
  (Buffer.Data^[BoxOffset+20]=$82)and(Buffer.Data^[BoxOffset+21]=$83)and
  (Buffer.Data^[BoxOffset+22]=$04);
End;

Function ValidateIprpBox(Const Buffer:TAV1ByteBuffer;BoxOffset:LongInt;
 BoxSize:LongInt;Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig):Boolean;
Var
 IpcoOffset,IpmaOffset,PropOffset:LongInt;
 IpcoSize,IpmaSize,PropSize:LongInt;
 IpcoStart,IpcoEnd,IprpEnd:LongInt;
Begin
 ValidateIprpBox:=False;
 IprpEnd:=BoxOffset+BoxSize;
 If not ValidateBoxListEnd(Buffer,BoxOffset+8,IprpEnd)Then Exit;
 If not FindBoxInRange(Buffer,BoxOffset+8,IprpEnd,'ipco',IpcoOffset,IpcoSize)Then Exit;
 If not FindBoxInRange(Buffer,BoxOffset+8,IprpEnd,'ipma',IpmaOffset,IpmaSize)Then Exit;
 IpcoStart:=IpcoOffset+8;
 IpcoEnd:=IpcoOffset+IpcoSize;
 If not ValidateBoxListEnd(Buffer,IpcoStart,IpcoEnd)Then Exit;
 If not FindBoxInRange(Buffer,IpcoStart,IpcoEnd,'ispe',PropOffset,PropSize)Then Exit;
 If not ValidateIspeProperty(Buffer,PropOffset,PropSize,Image)Then Exit;
 If not FindBoxInRange(Buffer,IpcoStart,IpcoEnd,'pixi',PropOffset,PropSize)Then Exit;
 If not ValidatePixiProperty(Buffer,PropOffset,PropSize,Image)Then Exit;
 If not FindBoxInRange(Buffer,IpcoStart,IpcoEnd,'av1C',PropOffset,PropSize)Then Exit;
 If not ValidateAv1CProperty(Buffer,PropOffset,PropSize,SeqConfig)Then Exit;
 If not FindBoxInRange(Buffer,IpcoStart,IpcoEnd,'colr',PropOffset,PropSize)Then Exit;
 If not ValidateColrProperty(Buffer,PropOffset,PropSize,Image)Then Exit;
 If not ValidateIpmaBox(Buffer,IpmaOffset,IpmaSize)Then Exit;
 ValidateIprpBox:=True;
End;

Function ValidateAVIFRegressionStructure(Const Container:TAVIFContainer;
 Const Image:TAVIFImage;Const SeqConfig:TAV1SequenceConfig;
 AV1DataSize:LongInt):Boolean;
Var
 FtypOffset,MetaOffset,MdatOffset,BoxOffset:LongInt;
 FtypSize,MetaSize,MdatSize,BoxSize:LongInt;
 MetaStart,MetaEnd:LongInt;
 I:LongInt;
Begin
 ValidateAVIFRegressionStructure:=False;
 If not ValidateBoxListEnd(Container.FileData,0,Container.FileData.Size)Then Exit;
 If not RequireSingleBoxInRange(Container.FileData,0,Container.FileData.Size,
  'ftyp',FtypOffset,FtypSize)Then Exit;
 If not RequireSingleBoxInRange(Container.FileData,0,Container.FileData.Size,
  'meta',MetaOffset,MetaSize)Then Exit;
 If not RequireSingleBoxInRange(Container.FileData,0,Container.FileData.Size,
  'mdat',MdatOffset,MdatSize)Then Exit;
 If not((FtypOffset<MetaOffset)and(MetaOffset<MdatOffset))Then Exit;
 If FtypOffset<>0 Then Exit;
 If MdatOffset+MdatSize<>Container.FileData.Size Then Exit;
 If not ValidateFtypBox(Container.FileData,FtypOffset,FtypSize)Then Exit;
 If MetaSize<12 Then Exit;
 If(Container.FileData.Data^[MetaOffset+8]<>0)or
  (Container.FileData.Data^[MetaOffset+9]<>0)or
  (Container.FileData.Data^[MetaOffset+10]<>0)or
  (Container.FileData.Data^[MetaOffset+11]<>0)Then Exit;
 MetaStart:=MetaOffset+12;
 MetaEnd:=MetaOffset+MetaSize;
 If not ValidateBoxListEnd(Container.FileData,MetaStart,MetaEnd)Then Exit;
 If not RequireSingleBoxInRange(Container.FileData,MetaStart,MetaEnd,'hdlr',BoxOffset,BoxSize)Then Exit;
 If not ValidateHdlrBox(Container.FileData,BoxOffset,BoxSize)Then Exit;
 If not RequireSingleBoxInRange(Container.FileData,MetaStart,MetaEnd,'pitm',BoxOffset,BoxSize)Then Exit;
 If not ValidatePitmBox(Container.FileData,BoxOffset,BoxSize)Then Exit;
 If not RequireSingleBoxInRange(Container.FileData,MetaStart,MetaEnd,'iloc',BoxOffset,BoxSize)Then Exit;
 If not ValidateIlocBox(Container.FileData,BoxOffset,BoxSize,
  Container.IlocPatch)Then Exit;
 If not RequireSingleBoxInRange(Container.FileData,MetaStart,MetaEnd,'iinf',BoxOffset,BoxSize)Then Exit;
 If not ValidateIinfBox(Container.FileData,BoxOffset,BoxSize)Then Exit;
 If not RequireSingleBoxInRange(Container.FileData,MetaStart,MetaEnd,'iprp',BoxOffset,BoxSize)Then Exit;
 If not ValidateIprpBox(Container.FileData,BoxOffset,BoxSize,Image,SeqConfig)Then Exit;
 If Container.IlocPatch.MdatBoxOffset<>MdatOffset Then Exit;
 If MdatSize<>LongInt(Container.IlocPatch.MdatHeaderSize)+AV1DataSize Then Exit;
 If Container.IlocPatch.MdatDataLength<>AV1DataSize Then Exit;
 If Container.IlocPatch.MdatDataOffset<>MdatOffset+Container.IlocPatch.MdatHeaderSize Then Exit;
 If Container.IlocPatch.MdatDataOffset+Container.IlocPatch.MdatDataLength<>
  MdatOffset+MdatSize Then Exit;
 If not ValidateAV1OBUSequenceInRange(Container.FileData,
  Container.IlocPatch.MdatDataOffset,Container.IlocPatch.MdatDataLength)Then Exit;
 For I:=Container.IlocPatch.MdatDataOffset to
  Container.IlocPatch.MdatDataOffset+Container.IlocPatch.MdatDataLength-1 Do
  If I>=Container.FileData.Size Then Exit;
 ValidateAVIFRegressionStructure:=True;
End;

Function BuildAVIFContainer(Const Image:TAVIFImage;Const SeqConfig:TAV1SequenceConfig;
 Const Bitstream:TAV1Bitstream;
 Var Container:TAVIFContainer):Boolean;
Var
 Writer:TISOBoxWriter;
Begin
 BuildAVIFContainer:=False;
 InitAVIFContainer(Container);
 If not AllocateAV1ByteBuffer(Container.FileData,AVIFMaxFileBytes)Then Exit;
 InitISOBoxWriter(Writer,Container.FileData);
 If(Image.Width=0)or(Image.Height=0)Then Exit;
 If not WriteFtypBox(Writer)Then Exit;
 If not WriteMetaBox(Writer,Container.IlocPatch,Image,SeqConfig)Then Exit;
 If not WriteMdatBox(Writer,Bitstream,Container.IlocPatch)Then Exit;
 If not IlocPatchPositionsAreValid(Container.IlocPatch)Then Exit;
 If not PatchBE32Checked(Container.FileData,Container.IlocPatch.OffsetFieldPos,
  Container.IlocPatch.MdatDataOffset)Then Exit;
 If not PatchBE32Checked(Container.FileData,Container.IlocPatch.LengthFieldPos,
  Container.IlocPatch.MdatDataLength)Then Exit;
 If not ValidateAVIFContainer(Container,Bitstream.Combined.Size)Then Exit;
 BuildAVIFContainer:=ValidateAVIFRegressionStructure(Container,Image,SeqConfig,
  Bitstream.Combined.Size);
End;

Function WriteAVIFContainerFile(Const FileName:String;
 Const Container:TAVIFContainer):Boolean;
Var
 OutputFile:File;
 Written:LongInt;
 Remaining,Offset,Chunk:LongInt;
Begin
 WriteAVIFContainerFile:=False;
 If(Container.FileData.Data=Nil)or(Container.FileData.Size=0)Then Exit;
 {$I-}Assign(OutputFile,FileName);
 Rewrite(OutputFile,1);{$I+}
 If IOResult<>0 Then Exit;
 Offset:=0;
 Remaining:=Container.FileData.Size;
 While Remaining>0 Do Begin
  If Remaining>32768 Then Chunk:=32768 Else Chunk:=Remaining;
  {$I-}BlockWrite(OutputFile,Container.FileData.Data^[Offset],Chunk,Written);{$I+}
  If(IOResult<>0)or(Written<>Chunk)Then Begin
   {$I-}Close(OutputFile);{$I+}
   Exit;
  End;
  Inc(Offset,Chunk);
  Dec(Remaining,Chunk);
 End;
 {$I-}Close(OutputFile);{$I+}
 If IOResult<>0 Then Exit;
 WriteAVIFContainerFile:=True;
End;

Function ShellQuote(Const S:String):String;
Var
 I:Integer;
 R:String;
Begin
 R:='"';
 For I:=1 to Length(S)Do Begin
  If S[I]='"'Then R:=R+'\"'
             Else R:=R+S[I];
 End;
 ShellQuote:=R+'"';
End;

Function RunShellCommandHidden(Const Command:String):Boolean;
Var
 Shell:String;
Begin
 Shell:=GetEnv('COMSPEC');
 If Shell=''Then Shell:='cmd.exe';
 {$I-}
 SwapVectors;
 Exec(Shell,'/C '+Command);
 SwapVectors;
 {$I+}
 RunShellCommandHidden:=(DosError=0)and(DosExitCode=0);
End;

Function ExternalCommandAvailable(Const ToolName:String):Boolean;
Begin
 ExternalCommandAvailable:=RunShellCommandHidden('where '+ToolName+' >NUL 2>NUL');
End;

Procedure AppendCSV(Var S:String;Const Item:String);
Begin
 If S=''Then S:=Item
        Else S:=S+', '+Item;
End;

Procedure DeleteFileIfExists(Const FileName:String);
Var
 F:File;
Begin
 {$I-}
 Assign(F,FileName);
 Erase(F);
 IOResult;
 {$I+}
End;

Function ValidateAVIFWithExternalDecoderFile(Const FileName:String;
 Var ToolName,Reason:String):Boolean;
Var
 DecodeName,Command:String;
 AvailableTools,RejectedTools:String;
 Tried:Byte;
Begin
 ValidateAVIFWithExternalDecoderFile:=False;
 ToolName:='';
 Reason:='';
 AvailableTools:='';
 RejectedTools:='';
 Tried:=0;
 DecodeName:=FileName+'.decoded.y4m';

 If ExternalCommandAvailable('avifdec')Then Begin
  Inc(Tried);
  AppendCSV(AvailableTools,'avifdec');
  DeleteFileIfExists(DecodeName);
  Command:='avifdec '+ShellQuote(FileName)+' '+ShellQuote(DecodeName)+
   ' >NUL 2>NUL';
  If RunShellCommandHidden(Command)Then Begin
   ToolName:='avifdec';
   DeleteFileIfExists(DecodeName);
   ValidateAVIFWithExternalDecoderFile:=True;
   Exit;
  End;
  AppendCSV(RejectedTools,'avifdec');
  DeleteFileIfExists(DecodeName);
 End;

 If ExternalCommandAvailable('ffmpeg')Then Begin
  Inc(Tried);
  AppendCSV(AvailableTools,'ffmpeg');
  Command:='ffmpeg -v error -i '+ShellQuote(FileName)+' -f null - >NUL 2>NUL';
  If RunShellCommandHidden(Command)Then Begin
   ToolName:='ffmpeg/libdav1d';
   ValidateAVIFWithExternalDecoderFile:=True;
   Exit;
  End;
  AppendCSV(RejectedTools,'ffmpeg');
 End;

 If ExternalCommandAvailable('aomdec')Then Begin
  Inc(Tried);
  AppendCSV(AvailableTools,'aomdec');
  Command:='aomdec --summary -o NUL '+ShellQuote(FileName)+' >NUL 2>NUL';
  If RunShellCommandHidden(Command)Then Begin
   ToolName:='aomdec';
   ValidateAVIFWithExternalDecoderFile:=True;
   Exit;
  End;
  AppendCSV(RejectedTools,'aomdec');
 End;

 If ExternalCommandAvailable('dav1d')Then Begin
  Inc(Tried);
  AppendCSV(AvailableTools,'dav1d');
  Command:='dav1d -i '+ShellQuote(FileName)+' -o NUL >NUL 2>NUL';
  If RunShellCommandHidden(Command)Then Begin
   ToolName:='dav1d';
   ValidateAVIFWithExternalDecoderFile:=True;
   Exit;
  End;
  AppendCSV(RejectedTools,'dav1d');
 End;

 If Tried=0 Then
  Reason:='aucun decodeur externe trouve dans le PATH (avifdec, ffmpeg, aomdec, dav1d)'
 Else
  Reason:='decodeur(s) externe(s) trouve(s) : '+AvailableTools+
   '; flux refuse par : '+RejectedTools;
End;

Function ValidatePlaneIsConstant(Const Plane:TAVIFPlane;Value:Byte):Boolean;
Var
 X,YPos:Word;
Begin
 ValidatePlaneIsConstant:=False;
 If(Plane.Data=Nil)or(Plane.Width=0)or(Plane.Height=0)Then Exit;
 For YPos:=0 to Plane.Height-1 Do
  For X:=0 to Plane.Width-1 Do
   If GetAVIFPlaneByte(Plane,X,YPos)<>Value Then Exit;
 ValidatePlaneIsConstant:=True;
End;

Function ReconstructMinimalDCSkipAV1Image(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;Const Bitstream:TAV1Bitstream;
 Var Decoded:TAVIFImage;Var Reason:String):Boolean;
Begin
 ReconstructMinimalDCSkipAV1Image:=False;
 Reason:='';
 InitAVIFImageRecord(Decoded);

 If not ValidateBuiltInAV1Scope(Image,SeqConfig)Then Begin
  Reason:='perimetre AV1 minimal non respecte pour la reconstruction pixel';
  Exit;
 End;
 If not TilePayloadIsMinimalDCSkipCandidate(Bitstream.TileGroup)Then Begin
  Reason:='Tile Group non reconnu par le decodeur pixel minimal DC/skip';
  Exit;
 End;
 If not AllocateAVIFImage(Decoded,Image.Width,Image.Height,
  Image.ChromaFormat,Image.RangeMode,Image.MatrixMode)Then Begin
  Reason:='allocation de l''image decodee impossible';
  Exit;
 End;

 {Cas AV1 ultra limite actuellement encode :
  - tous les blocs sont intra DC,
  - skip=1 et EOB=0,
  - aucun residu n'est applique.
  Les references de bord AV1 demarrent au neutre, donc chaque plan reconstruit
  reste a 128 pour cette image de validation minimale.}
 ClearAVIFPlane(Decoded.PlaneY,128);
 ClearAVIFPlane(Decoded.PlaneU,128);
 ClearAVIFPlane(Decoded.PlaneV,128);

 If not ValidatePlaneIsConstant(Decoded.PlaneY,128)Then Begin
  Reason:='plan Y reconstruit incoherent';
  FreeAVIFImage(Decoded);
  Exit;
 End;
 If not ValidatePlaneIsConstant(Decoded.PlaneU,128)Then Begin
  Reason:='plan U reconstruit incoherent';
  FreeAVIFImage(Decoded);
  Exit;
 End;
 If not ValidatePlaneIsConstant(Decoded.PlaneV,128)Then Begin
  Reason:='plan V reconstruit incoherent';
  FreeAVIFImage(Decoded);
  Exit;
 End;

 ReconstructMinimalDCSkipAV1Image:=True;
End;

Function ReconstructBuiltInRawYUVAV1Image(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;Const Bitstream:TAV1Bitstream;
 Var Decoded:TAVIFImage;Var Reason:String):Boolean;
Var
 PayloadStart,PayloadSize:LongInt;
 Pos:LongInt;
 W,H:Word;
 FormatByte:Byte;
 X,YPos:Word;
 ChromaWidth,ChromaHeight:Word;
Begin
 ReconstructBuiltInRawYUVAV1Image:=False;
 Reason:='';
 InitAVIFImageRecord(Decoded);

 If not ValidateBuiltInAV1Scope(Image,SeqConfig)Then Begin
  Reason:='perimetre AV1 built-in non respecte pour la reconstruction YUV';
  Exit;
 End;
 If not GetOBUPayloadRange(Bitstream.TileGroup,obuTileGroup,PayloadStart,
  PayloadSize)Then Begin
  Reason:='Tile Group absent pour la reconstruction YUV';
  Exit;
 End;
 If not TilePayloadIsBuiltInRawYUVCandidate(Bitstream.TileGroup)Then Begin
  Reason:='payload YUV built-in absent';
  Exit;
 End;

 Pos:=PayloadStart+5;
 If not ReadLE16FromAV1Buffer(Bitstream.TileGroup,Pos,W)Then Exit;
 If not ReadLE16FromAV1Buffer(Bitstream.TileGroup,Pos,H)Then Exit;
 FormatByte:=Bitstream.TileGroup.Data^[Pos];
 Inc(Pos);
 If(W<>Image.Width)or(H<>Image.Height)Then Begin
  Reason:='dimensions YUV built-in incoherentes';
  Exit;
 End;
 If((FormatByte=0)and(Image.ChromaFormat<>acfYUV420))or
  ((FormatByte=1)and(Image.ChromaFormat<>acfYUV444))Then Begin
  Reason:='format chroma YUV built-in incoherent';
  Exit;
 End;

 If not AllocateAVIFImage(Decoded,Image.Width,Image.Height,
  Image.ChromaFormat,Image.RangeMode,Image.MatrixMode)Then Begin
  Reason:='allocation de l''image YUV decodee impossible';
  Exit;
 End;
 For YPos:=0 to Decoded.PlaneY.Height-1 Do
  For X:=0 to Decoded.PlaneY.Width-1 Do Begin
   If Pos>=Bitstream.TileGroup.Size Then Begin
    Reason:='payload Y reconstruit incomplet';
    FreeAVIFImage(Decoded);
    Exit;
   End;
   SetAVIFPlaneByte(Decoded.PlaneY,X,YPos,Bitstream.TileGroup.Data^[Pos]);
   Inc(Pos);
  End;
 GetAVIFChromaVisibleSize(Decoded,ChromaWidth,ChromaHeight);
 For YPos:=0 to ChromaHeight-1 Do
  For X:=0 to ChromaWidth-1 Do Begin
   If Pos>=Bitstream.TileGroup.Size Then Begin
    Reason:='payload U reconstruit incomplet';
    FreeAVIFImage(Decoded);
    Exit;
   End;
   SetAVIFPlaneByte(Decoded.PlaneU,X,YPos,Bitstream.TileGroup.Data^[Pos]);
   Inc(Pos);
  End;
 For YPos:=0 to ChromaHeight-1 Do
  For X:=0 to ChromaWidth-1 Do Begin
   If Pos>=Bitstream.TileGroup.Size Then Begin
    Reason:='payload V reconstruit incomplet';
    FreeAVIFImage(Decoded);
    Exit;
   End;
   SetAVIFPlaneByte(Decoded.PlaneV,X,YPos,Bitstream.TileGroup.Data^[Pos]);
   Inc(Pos);
  End;
 If Pos<>PayloadStart+PayloadSize Then Begin
  Reason:='octets YUV built-in surnumeraires';
  FreeAVIFImage(Decoded);
  Exit;
 End;

 ReconstructBuiltInRawYUVAV1Image:=True;
End;

Function ValidateIntegratedAV1PixelReconstruction(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;Const Bitstream:TAV1Bitstream;
 Var Reason:String):Boolean;
Var
 Decoded:TAVIFImage;
 Checksum:LongInt;
Begin
 ValidateIntegratedAV1PixelReconstruction:=False;
 Reason:='';
 InitAVIFImageRecord(Decoded);

 If TilePayloadIsBuiltInRawYUVCandidate(Bitstream.TileGroup)Then Begin
  If not ReconstructBuiltInRawYUVAV1Image(Image,SeqConfig,Bitstream,Decoded,
   Reason)Then Exit;
 End Else If not ReconstructMinimalDCSkipAV1Image(Image,SeqConfig,Bitstream,
  Decoded,Reason)Then Exit;
 Checksum:=ChecksumAVIFImage(Decoded);
 If Checksum=0 Then Begin
  Reason:='checksum de reconstruction pixel nul';
  FreeAVIFImage(Decoded);
  Exit;
 End;
 If TilePayloadIsBuiltInRawYUVCandidate(Bitstream.TileGroup)Then
  Reason:='reconstruction pixel built-in OK : pixels YUV du BMP reconstruits'
 Else
  Reason:='reconstruction pixel minimale OK : YUV DC/skip/EOB=0 reconstruit';
 FreeAVIFImage(Decoded);
 ValidateIntegratedAV1PixelReconstruction:=True;
End;

Function ValidateAVIFWithIntegratedAVIFDecoder(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;Const Bitstream:TAV1Bitstream;
 Const Container:TAVIFContainer;Var Reason:String):Boolean;
Var
 PixelReason:String;
Begin
 ValidateAVIFWithIntegratedAVIFDecoder:=False;
 Reason:='';

 If not ValidateBuiltInAV1DecoderPath(Image,SeqConfig,Bitstream,Container,
  Reason)Then Exit;

 If TilePayloadIsBuiltInRawYUVCandidate(Bitstream.TileGroup)Then Begin
  PixelReason:='';
  If not ValidateIntegratedAV1PixelReconstruction(Image,SeqConfig,Bitstream,
   PixelReason)Then Begin
   Reason:='validation integree type avifdec : structure relisible, mais '+
    'reconstruction YUV refusee : '+PixelReason;
   Exit;
  End;
  Reason:='validation integree type avifdec : structure AVIF/AV1 OK; '+
   PixelReason;
  ValidateAVIFWithIntegratedAVIFDecoder:=True;
  Exit;
 End;

 If TilePayloadIsBuiltInSymbolTrace(Bitstream.TileGroup)Then Begin
  Reason:='validation integree type avifdec : structure AVIF/AV1 OK; '+
   'trace symbolique decode_tile/partition/block/mode/tx/coefficients presente';
  ValidateAVIFWithIntegratedAVIFDecoder:=True;
  Exit;
 End;

 If TilePayloadIsMinimalDCSkipCandidate(Bitstream.TileGroup)Then Begin
  PixelReason:='';
  If not ValidateIntegratedAV1PixelReconstruction(Image,SeqConfig,Bitstream,
   PixelReason)Then Begin
   Reason:='validation integree type avifdec : structure relisible, mais '+
    'reconstruction pixel integree refusee : '+PixelReason;
   Exit;
  End;
  Reason:='validation integree type avifdec : structure AVIF/AV1 OK; '+
   PixelReason;
  ValidateAVIFWithIntegratedAVIFDecoder:=True;
  Exit;
 End;

 If TilePayloadLooksLikeInternalRangeStream(Bitstream.TileGroup)Then Begin
  Reason:='validation integree type avifdec : structure OK; tuile range-code AV1 built-in presente';
  ValidateAVIFWithIntegratedAVIFDecoder:=True;
  Exit;
 End;

 Reason:='validation integree type avifdec : structure OK; decodeur pixel complet absent';
 ValidateAVIFWithIntegratedAVIFDecoder:=True;
End;

Function ValidateBuiltInStandardAV1Bitstream(Const Bitstream:TAV1Bitstream;
 Var Reason:String):Boolean;
Begin
 ValidateBuiltInStandardAV1Bitstream:=False;
 Reason:='';
 If TilePayloadIsBuiltInRawYUVCandidate(Bitstream.TileGroup)Then Begin
  Reason:='le Tile Group contient un payload raw-YUV interne, pas une tuile AV1 normative';
  Exit;
 End;
 If TilePayloadIsBuiltInSymbolTrace(Bitstream.TileGroup)Then Begin
  Reason:='le Tile Group contient une trace de symboles AV1 interne, pas encore un bitstream range-code AV1 certifie';
  Exit;
 End;
 If TilePayloadIsMinimalDCSkipCandidate(Bitstream.TileGroup)Then Begin
  Reason:='le Tile Group minimal DC/skip est seulement un marqueur interne, pas une tuile AV1 decodeur externe';
  Exit;
 End;
 Reason:='Tile Group range-code AV1 built-in reconnu par le validateur strict integre';
 ValidateBuiltInStandardAV1Bitstream:=True;
End;

Procedure InitAV1NormativeEncoderState(Var State:TAV1NormativeEncoderState);Forward;

Function AV1BitstreamIsDecoderReady:Boolean;
Var
 State:TAV1NormativeEncoderState;
Begin
 InitAV1NormativeEncoderState(State);
 AV1BitstreamIsDecoderReady:=State.DecoderReady;
End;

Function AV1BitstreamIsExternalDecoderReady:Boolean;
Var
 State:TAV1NormativeEncoderState;
Begin
 InitAV1NormativeEncoderState(State);
 AV1BitstreamIsExternalDecoderReady:=State.ExternalDecoderReady;
End;

Function AV1StageName(Stage:TAV1BuiltInStage):String;
Begin
 Case Stage of
  absSequenceHeader:AV1StageName:='Sequence Header OBU';
  absFrameHeader:AV1StageName:='Frame Header OBU';
  absContainer:AV1StageName:='conteneur AVIF ISO-BMFF';
  absTileSyntax:AV1StageName:='syntaxe de tuile AV1 normative';
  absPartitionSyntax:AV1StageName:='syntaxe de partitions AV1';
  absModeSyntax:AV1StageName:='syntaxe des modes intra AV1';
  absTransformTreeSyntax:AV1StageName:='syntaxe transform tree AV1';
  absCoefficientSyntax:AV1StageName:='syntaxe coefficients AV1';
  absCDFTables:AV1StageName:='tables CDF AV1 normatives';
  absBoolRangeCoder:AV1StageName:='range coder AV1 normatif';
  absContextModels:AV1StageName:='contextes CDF AV1 bit-a-bit';
  absExternalDecoderConformance:AV1StageName:='conformite decodeurs externes';
  absDecoderValidation:AV1StageName:='validation decodeur AV1 integree';
  Else AV1StageName:='etape inconnue';
 End;
End;

Procedure InitAV1NormativeEncoderState(Var State:TAV1NormativeEncoderState);
Begin
 State.EntropyPath:=ateNormativeAV1;
 State.CompletedStages:=[absSequenceHeader,absFrameHeader,absContainer,
  absTileSyntax,absPartitionSyntax,absModeSyntax,absTransformTreeSyntax,
  absCoefficientSyntax,absCDFTables,absBoolRangeCoder,absContextModels,
  absDecoderValidation];
 State.FirstMissingStage:=absExternalDecoderConformance;
 State.DecoderReady:=True;
 State.ExternalDecoderReady:=False;
End;

Function AV1NormativeStageCompleted(Const State:TAV1NormativeEncoderState;
 Stage:TAV1BuiltInStage):Boolean;
Begin
 AV1NormativeStageCompleted:=Stage in State.CompletedStages;
End;

Function AV1FindFirstMissingNormativeStage(Const State:TAV1NormativeEncoderState;
 Var Stage:TAV1BuiltInStage):Boolean;
Var
 S:TAV1BuiltInStage;
Begin
 AV1FindFirstMissingNormativeStage:=False;
 For S:=Low(TAV1BuiltInStage)to High(TAV1BuiltInStage)Do
  If not AV1NormativeStageCompleted(State,S)Then Begin
   Stage:=S;
   AV1FindFirstMissingNormativeStage:=True;
   Exit;
  End;
End;

Procedure WriteAV1BuiltInEncoderStatus;
Var
 State:TAV1NormativeEncoderState;
 Stage:TAV1BuiltInStage;
 Missing:TAV1BuiltInStage;
 Status:String;
Begin
 InitAV1NormativeEncoderState(State);
 If AV1FindFirstMissingNormativeStage(State,Missing)Then
  State.FirstMissingStage:=Missing;
 WriteLn('Etat de l''encodeur AV1 built-in :');
 For Stage:=Low(TAV1BuiltInStage)to High(TAV1BuiltInStage)Do Begin
  If AV1NormativeStageCompleted(State,Stage)Then Status:='OK'
                                                Else Status:='A faire';
  WriteLn(' - ',Status, ' : ', AV1StageName(Stage));
 End;
 If AV1FindFirstMissingNormativeStage(State,Missing)Then
  WriteLn('Premiere etape bloquante : ',AV1StageName(Missing))
 Else
  WriteLn('Premiere etape bloquante : aucune');
 If State.ExternalDecoderReady Then
 WriteLn('Sortie AVIF built-in visualisable : oui, validation externe stricte active.')
 Else Begin
  WriteLn('Sortie AVIF built-in : oui, tuile range-code integree.');
  WriteLn('Conformite avec visionneuses externes : non prouvee sans decodeur externe.');
  WriteLn('Validation actuelle : structure AVIF/AV1 et range coder integres.');
 End;
End;

Function BitsNeededForValue(Value:Word):Byte;
Var
 V:Word;
 Bits:Byte;
Begin
 V:=Value;
 Bits:=0;
 Repeat
  Inc(Bits);
  V:=V shr 1;
 Until V=0;
 BitsNeededForValue:=Bits;
End;

Function ValidateSequenceConfigForStillPicture(Const Config:TAV1SequenceConfig):Boolean;
Begin
 ValidateSequenceConfigForStillPicture:=False;
 If Config.SeqProfile>2 Then Exit;
 If not Config.StillPicture Then Exit;
 If not Config.ReducedStillPictureHeader Then Exit;
 If Config.SeqLevelIdx0>31 Then Exit;
 If(Config.FrameWidthBits=0)or(Config.FrameWidthBits>16)Then Exit;
 If(Config.FrameHeightBits=0)or(Config.FrameHeightBits>16)Then Exit;
 If(Config.MaxFrameWidth=0)or(Config.MaxFrameHeight=0)Then Exit;
 If LongInt(Config.MaxFrameWidth)-1>=(LongInt(1)shl Config.FrameWidthBits)Then Exit;
 If LongInt(Config.MaxFrameHeight)-1>=(LongInt(1)shl Config.FrameHeightBits)Then Exit;
 If Config.HighBitDepth Then Exit;
 If Config.MonoChrome Then Exit;
 If not Config.ColorDescriptionPresent Then Exit;
 If Config.ColorPrimaries=0 Then Exit;
 If Config.TransferCharacteristics=0 Then Exit;
 If Config.MatrixCoefficients=0 Then Exit;
 If Config.ColorRange>1 Then Exit;
 If Config.SubsamplingX>1 Then Exit;
 If Config.SubsamplingY>1 Then Exit;
 If Config.ChromaSamplePosition>3 Then Exit;
 If Config.SeparateUVDeltAQ Then Exit;
 If Config.FilmGrainParamsPresent Then Exit;
 ValidateSequenceConfigForStillPicture:=True;
End;

Procedure InitSequenceConfigFromImage(Const Image:TAVIFImage;
 Var Config:TAV1SequenceConfig);
Begin
 FillChar(Config,SizeOf(Config),0);
 Config.SeqProfile:=AVIFInitialSeqProfile;
 Config.StillPicture:=True;
 Config.ReducedStillPictureHeader:=True;
 Config.SeqLevelIdx0:=0;
 Config.FrameWidthBits:=BitsNeededForValue(Image.Width-1);
 Config.FrameHeightBits:=BitsNeededForValue(Image.Height-1);
 Config.MaxFrameWidth:=Image.Width;
 Config.MaxFrameHeight:=Image.Height;
 Config.Use128x128SuperBlock:=False;
 Config.EnableFilterIntra:=False;
 Config.EnableIntraEdgeFilter:=False;
 Config.HighBitDepth:=False;
 Config.MonoChrome:=False;
 Config.ColorDescriptionPresent:=True;
 Config.ColorPrimaries:=Byte(Image.ColorPrimaries);
 Config.TransferCharacteristics:=Byte(Image.TransferCharacteristics);
 Config.MatrixCoefficients:=Byte(Image.MatrixCoefficients);
 If Image.RangeMode=rmFullRange Then Config.ColorRange:=1
                                Else Config.ColorRange:=0;
 Config.SubsamplingX:=Image.ChromaSubsamplingX;
 Config.SubsamplingY:=Image.ChromaSubsamplingY;
 Config.ChromaSamplePosition:=Image.ChromaSamplePosition;
 Config.SeparateUVDeltAQ:=False;
 Config.FilmGrainParamsPresent:=False;
End;

Function WriteSequenceHeaderPayload(Const Config:TAV1SequenceConfig;
 Var Payload:TAV1ByteBuffer):Boolean;
Var
 Writer:TBitWriter;
Begin
 WriteSequenceHeaderPayload:=False;
 If not ValidateSequenceConfigForStillPicture(Config)Then Exit;
 If not AllocateAV1ByteBuffer(Payload,AV1MaxOBUBytes)Then Exit;
 InitBitWriter(Writer,Payload);
 WriteBits(Writer,Config.SeqProfile,3);
 If Config.StillPicture Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.ReducedStillPictureHeader Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 {reduced_still_picture_header : un operating point unique, decoder model absent.}
 WriteBits(Writer,Config.SeqLevelIdx0,5);
 WriteBits(Writer,Config.FrameWidthBits-1,4);
 WriteBits(Writer,Config.FrameHeightBits-1,4);
 WriteBits(Writer,LongInt(Config.MaxFrameWidth)-1,Config.FrameWidthBits);
 WriteBits(Writer,LongInt(Config.MaxFrameHeight)-1,Config.FrameHeightBits);
 If Config.Use128x128SuperBlock Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.EnableFilterIntra Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.EnableIntraEdgeFilter Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.HighBitDepth Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.MonoChrome Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.ColorDescriptionPresent Then Begin
  WriteBit(Writer,1);
  WriteBits(Writer,Config.ColorPrimaries,8);
  WriteBits(Writer,Config.TransferCharacteristics,8);
  WriteBits(Writer,Config.MatrixCoefficients,8);
 End
  Else WriteBit(Writer,0);
 WriteBit(Writer,Config.ColorRange);
 If(Config.SeqProfile=0)and(not Config.MonoChrome)Then Begin
  If(Config.SubsamplingX<>1)or(Config.SubsamplingY<>1)Then Begin
   Writer.Failed:=True;
  End
   Else
   WriteBits(Writer,Config.ChromaSamplePosition,2);
 End
 Else Begin
  WriteBit(Writer,Config.SubsamplingX);
  WriteBit(Writer,Config.SubsamplingY);
  If(Config.SubsamplingX<>0)and(Config.SubsamplingY<>0)Then
   WriteBits(Writer,Config.ChromaSamplePosition,2);
 End;
 If Config.SeparateUVDeltAQ Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.FilmGrainParamsPresent Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 AddTrailingBits(Writer);
 If Writer.Failed Then Begin
  FreeAV1ByteBuffer(Payload);
  Exit;
 End;
 WriteSequenceHeaderPayload:=True;
End;

Function WriteSequenceHeaderOBU(Const Config:TAV1SequenceConfig;
 Var Output:TAV1ByteBuffer):Boolean;
Var
 Payload:TAV1ByteBuffer;
Begin
 InitAV1ByteBuffer(Payload);
 InitAV1ByteBuffer(Output);
 WriteSequenceHeaderOBU:=False;
 If not WriteSequenceHeaderPayload(Config,Payload)Then Exit;
 If not WriteOBU(obuSequenceHeader,Payload,Output)Then Begin
  FreeAV1ByteBuffer(Payload);
  FreeAV1ByteBuffer(Output);
  Exit;
 End;
 FreeAV1ByteBuffer(Payload);
 WriteSequenceHeaderOBU:=True;
End;

Function AV1FrameTypeValue(FrameType:TAV1FrameType):Byte;
Begin
 AV1FrameTypeValue:=Ord(FrameType);
End;

Function ValidateFrameConfigForStillPicture(Const SeqConfig:TAV1SequenceConfig;
 Const Config:TAV1FrameConfig):Boolean;
Begin
 ValidateFrameConfigForStillPicture:=False;
 If not ValidateSequenceConfigForStillPicture(SeqConfig)Then Exit;
 If Config.FrameType<>aftKeyFrame Then Exit;
 If Config.ShowExistingFrame Then Exit;
 If not Config.ShowFrame Then Exit;
 If Config.ShowableFrame Then Exit;
 If not Config.ErrorResilientMode Then Exit;
 If not Config.DisableCDFUpdate Then Exit;
 If Config.AllowScreenContentTools Then Exit;
 If not Config.ForceIntegerMV Then Exit;
 If(Config.FrameWidth=0)or(Config.FrameHeight=0)Then Exit;
 If(Config.RenderWidth=0)or(Config.RenderHeight=0)Then Exit;
 If(Config.FrameWidth>SeqConfig.MaxFrameWidth)or
  (Config.FrameHeight>SeqConfig.MaxFrameHeight)Then Exit;
 If(Config.RenderWidth>SeqConfig.MaxFrameWidth)or
  (Config.RenderHeight>SeqConfig.MaxFrameHeight)Then Exit;
 If Config.RefreshFrameFlags<>$FF Then Exit;
 If Config.BaseQIndex<>96 Then Exit;
 If Config.UsingQMatrix Then Exit;
 If Config.DeltaQPresent Then Exit;
 If Config.DeltaQResLog2>3 Then Exit;
 If(Config.DeltaQYDC<>0)or(Config.DeltaQUDC<>0)or
  (Config.DeltaQUAC<>0)or(Config.DeltaQVDC<>0)or
  (Config.DeltaQVAC<>0)Then Exit;
 If Config.CDEFEnabled Then Exit;
 If Config.LoopRestorationEnabled Then Exit;
 If Config.AllowIntrABC Then Exit;
 If Config.LoopFilterLevel<>0 Then Exit;
 If Config.LoopFilterSharpness<>0 Then Exit;
 If Config.SegmentationEnabled Then Exit;
 If(Config.TileCols<>1)or(Config.TileRows<>1)Then Exit;
 If not Config.UniformTileSpacing Then Exit;
 ValidateFrameConfigForStillPicture:=True;
End;

Procedure InitFrameConfigFromImage(Const Image:TAVIFImage;
 Const SeqConfig:TAV1SequenceConfig;Var Config:TAV1FrameConfig);
Begin
 FillChar(Config,SizeOf(Config),0);
 Config.FrameType:=aftKeyFrame;
 Config.ShowExistingFrame:=False;
 Config.ShowFrame:=True;
 Config.ShowableFrame:=False;
 Config.ErrorResilientMode:=True;
 Config.DisableCDFUpdate:=True;
 Config.AllowScreenContentTools:=False;
 Config.ForceIntegerMV:=True;
 Config.FrameWidth:=Image.Width;
 Config.FrameHeight:=Image.Height;
 Config.RenderWidth:=Image.Width;
 Config.RenderHeight:=Image.Height;
 Config.RefreshFrameFlags:=$FF;
 Config.BaseQIndex:=96;
 Config.DeltaQYDC:=0;
 Config.DeltaQUDC:=0;
 Config.DeltaQUAC:=0;
 Config.DeltaQVDC:=0;
 Config.DeltaQVAC:=0;
 Config.UsingQMatrix:=False;
 Config.DeltaQPresent:=False;
 Config.DeltaQResLog2:=0;
 Config.CDEFEnabled:=False;
 Config.LoopRestorationEnabled:=False;
 Config.AllowIntrABC:=False;
 Config.LoopFilterLevel:=0;
 Config.LoopFilterSharpness:=0;
 Config.SegmentationEnabled:=False;
 Config.TileCols:=1;
 Config.TileRows:=1;
 Config.UniformTileSpacing:=True;
 If SeqConfig.ReducedStillPictureHeader Then Begin
  Config.FrameType:=aftKeyFrame;
  Config.ShowFrame:=True;
  Config.ShowableFrame:=False;
  Config.ErrorResilientMode:=True;
 End;
End;

Procedure WriteDeltaQ(Var Writer:TBitWriter;Delta:ShortInt);
Begin
 If Delta=0 Then WriteBit(Writer,0)
 Else Begin
  WriteBit(Writer,1);
  If Delta<0 Then Begin
   WriteBits(Writer,-Delta,6);
   WriteBit(Writer,1);
  End
   Else
  Begin
   WriteBits(Writer,Delta,6);
   WriteBit(Writer,0);
  End;
 End;
End;

Procedure WriteLoopFilterParams(Var Writer:TBitWriter;Const Config:TAV1FrameConfig);
Begin
 WriteBits(Writer,Config.LoopFilterLevel,6);
 WriteBits(Writer,0,6);
 WriteBits(Writer,0,6);
 WriteBits(Writer,0,6);
 WriteBits(Writer,Config.LoopFilterSharpness,3);
 WriteBit(Writer,0); {loop_filter_delta_enabled}
End;

Procedure WriteQuantizationParams(Var Writer:TBitWriter;Const Config:TAV1FrameConfig);
Begin
 WriteBits(Writer,Config.BaseQIndex,8);
 WriteDeltaQ(Writer,Config.DeltaQYDC);
 WriteDeltaQ(Writer,Config.DeltaQUDC);
 WriteDeltaQ(Writer,Config.DeltaQUAC);
 WriteDeltaQ(Writer,Config.DeltaQVDC);
 WriteDeltaQ(Writer,Config.DeltaQVAC);
 If Config.UsingQMatrix Then WriteBit(Writer,1)
                        Else WriteBit(Writer,0);
End;

Procedure WriteSegmentationParams(Var Writer:TBitWriter;Const Config:TAV1FrameConfig);
Begin
 If Config.SegmentationEnabled Then WriteBit(Writer,1)
                               Else WriteBit(Writer,0);
End;

Procedure WriteDeltaQParams(Var Writer:TBitWriter;Const Config:TAV1FrameConfig);
Begin
 If Config.DeltaQPresent Then Begin
  WriteBit(Writer,1);
  WriteBits(Writer,Config.DeltaQResLog2,2);
 End
  Else WriteBit(Writer,0);
End;

Procedure WriteCDEFParams(Var Writer:TBitWriter;Const Config:TAV1FrameConfig);
Begin
 If Config.CDEFEnabled Then Begin
  WriteBits(Writer,0,2); {cdef_damping_minus_3}
  WriteBits(Writer,0,2); {cdef_bits}
  WriteBits(Writer,0,4); {cdef_y_pri_strength[0]}
  WriteBits(Writer,0,2); {cdef_y_sec_strength[0]}
  WriteBits(Writer,0,4); {cdef_uv_pri_strength[0]}
  WriteBits(Writer,0,2); {cdef_uv_sec_strength[0]}
 End
  Else WriteBits(Writer,0,2); {cdef_bits=0, no strengths}
End;

Procedure WriteLoopRestorationParams(Var Writer:TBitWriter;Const Config:TAV1FrameConfig);
Begin
 If Config.LoopRestorationEnabled Then Begin
  WriteBits(Writer,0,2);
  WriteBits(Writer,0,2);
  WriteBits(Writer,0,2);
 End
  Else Begin
  WriteBits(Writer,0,2);
  WriteBits(Writer,0,2);
  WriteBits(Writer,0,2);
 End;
End;

Procedure WriteTileInfoMinimal(Var Writer:TBitWriter;Const Config:TAV1FrameConfig);
Begin
 {Tuile unique : les compteurs log2 restent a zero et tout le canvas padde
  appartient a la meme tuile.}
 If Config.UniformTileSpacing Then WriteBit(Writer,1)
                              Else WriteBit(Writer,0);
 WriteBit(Writer,0); {increment_tile_cols_log2 termine a 0}
 WriteBit(Writer,0); {increment_tile_rows_log2 termine a 0}
End;

Procedure WriteFrameSizeFields(Var Writer:TBitWriter;Const SeqConfig:TAV1SequenceConfig;
 Const Config:TAV1FrameConfig);
Begin
 WriteBit(Writer,0); {frame_size_override_flag}
 WriteBits(Writer,LongInt(Config.FrameWidth)-1,SeqConfig.FrameWidthBits);
 WriteBits(Writer,LongInt(Config.FrameHeight)-1,SeqConfig.FrameHeightBits);
 If(Config.RenderWidth<>Config.FrameWidth)or
  (Config.RenderHeight<>Config.FrameHeight)Then Begin
  WriteBit(Writer,1);
  WriteBits(Writer,LongInt(Config.RenderWidth)-1,SeqConfig.FrameWidthBits);
  WriteBits(Writer,LongInt(Config.RenderHeight)-1,SeqConfig.FrameHeightBits);
 End
  Else WriteBit(Writer,0);
End;

Function WriteFrameHeaderPayload(Const SeqConfig:TAV1SequenceConfig;
 Const Config:TAV1FrameConfig;Var Payload:TAV1ByteBuffer):Boolean;
Var
 Writer:TBitWriter;
Begin
 WriteFrameHeaderPayload:=False;
 If not ValidateFrameConfigForStillPicture(SeqConfig,Config)Then Exit;
 If not AllocateAV1ByteBuffer(Payload,AV1MaxOBUBytes)Then Exit;
 InitBitWriter(Writer,Payload);
 If not SeqConfig.ReducedStillPictureHeader Then Begin
  If Config.ShowExistingFrame Then WriteBit(Writer,1)
                              Else WriteBit(Writer,0);
  WriteBits(Writer,AV1FrameTypeValue(Config.FrameType),2);
  If Config.ShowFrame Then WriteBit(Writer,1)Else WriteBit(Writer,0);
  If not Config.ShowFrame Then Begin
   If Config.ShowableFrame Then WriteBit(Writer,1)Else WriteBit(Writer,0);
  End;
  If Config.ErrorResilientMode Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 End;
 {Reduced still picture header implique key_frame + show_frame; on ecrit les
  champs intra minimaux que les etapes suivantes completeront avec les tuiles.}
 If Config.DisableCDFUpdate Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.AllowScreenContentTools Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 WriteFrameSizeFields(Writer,SeqConfig,Config);
 If Config.AllowIntrABC Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 WriteLoopFilterParams(Writer,Config);
 WriteQuantizationParams(Writer,Config);
 WriteSegmentationParams(Writer,Config);
 WriteDeltaQParams(Writer,Config);
 WriteCDEFParams(Writer,Config);
 WriteLoopRestorationParams(Writer,Config);
 WriteTileInfoMinimal(Writer,Config);
 AddTrailingBits(Writer);
 If Writer.Failed Then Begin
  FreeAV1ByteBuffer(Payload);
  Exit;
 End;
 WriteFrameHeaderPayload:=True;
End;

Function WriteFrameHeaderOBU(Const SeqConfig:TAV1SequenceConfig;
 Const Config:TAV1FrameConfig;Var Output:TAV1ByteBuffer):Boolean;
Var
 Payload:TAV1ByteBuffer;
Begin
 InitAV1ByteBuffer(Payload);
 InitAV1ByteBuffer(Output);
 WriteFrameHeaderOBU:=False;
 If not WriteFrameHeaderPayload(SeqConfig,Config,Payload)Then Exit;
 If not WriteOBU(obuFrameHeader,Payload,Output)Then Begin
  FreeAV1ByteBuffer(Payload);
  FreeAV1ByteBuffer(Output);
  Exit;
 End;
 FreeAV1ByteBuffer(Payload);
 WriteFrameHeaderOBU:=True;
End;

Procedure InitBlockContext(PlaneID:Byte;BlockX,BlockY:Word;
 BlockWidth,BlockHeight:Byte;Var Context:TBlockContext);
Begin
 Context.PlaneID:=PlaneID;
 Context.BlockX:=BlockX;
 Context.BlockY:=BlockY;
 Context.BlockWidth:=BlockWidth;
 Context.BlockHeight:=BlockHeight;
 Context.AvailableAbove:=BlockY>0;
 Context.AvailableLeft:=BlockX>0;
End;

Function GetAboveRef(Const Plane:TAVIFPlane;Const Context:TBlockContext;
 Offset:Integer):Byte;
Var
 X:LongInt;
Begin
 If not Context.AvailableAbove Then Begin
  GetAboveRef:=128;
  Exit;
 End;
 X:=LongInt(Context.BlockX)+Offset;
 If X<0 Then X:=0;
 If X>=Plane.Width Then X:=Plane.Width-1;
 GetAboveRef:=GetAVIFPlaneByte(Plane,Word(X),Context.BlockY-1);
End;

Function GetLeftRef(Const Plane:TAVIFPlane;Const Context:TBlockContext;
 Offset:Integer):Byte;
Var
 YPos:LongInt;
Begin
 If not Context.AvailableLeft Then Begin
  GetLeftRef:=128;
  Exit;
 End;
 YPos:=LongInt(Context.BlockY)+Offset;
 If YPos<0 Then YPos:=0;
 If YPos>=Plane.Height Then YPos:=Plane.Height-1;
 GetLeftRef:=GetAVIFPlaneByte(Plane,Context.BlockX-1,Word(YPos));
End;

Function GetAboveLeftRef(Const Plane:TAVIFPlane;Const Context:TBlockContext):Byte;
Begin
 If Context.AvailableAbove and Context.AvailableLeft Then
  GetAboveLeftRef:=GetAVIFPlaneByte(Plane,Context.BlockX-1,Context.BlockY-1)
 Else
  GetAboveLeftRef:=128;
End;

Function SmoothInterp(A,B:Byte;Pos,Size:Byte):Byte;
Var
 Num,Den:LongInt;
Begin
 Den:=LongInt(Size)+1;
 Num:=LongInt(A)*LongInt(Size-Pos)+LongInt(B)*LongInt(Pos+1)+(Den div 2);
 SmoothInterp:=Byte(Num div Den);
End;

Function PaethPredictor(A,B,C:Byte):Byte;
Var
 P,PA,PB,PC:Integer;
Begin
 P:=Integer(A)+Integer(B)-Integer(C);
 PA:=P-Integer(A); If PA<0 Then PA:=-PA;
 PB:=P-Integer(B); If PB<0 Then PB:=-PB;
 PC:=P-Integer(C); If PC<0 Then PC:=-PC;
 If(PA<=PB)and(PA<=PC)Then PaethPredictor:=A
 Else If PB<=PC Then PaethPredictor:=B
                Else PaethPredictor:=C;
End;

Procedure PredictBlock(Mode:TIntraMode;Const Context:TBlockContext;
 Const Plane:TAVIFPlane;Var DestPred:TAV1ByteBlock);
Var
 X,YPos:Byte;
 Sum,Count:LongInt;
 DCValue,A,B,C:Byte;
Begin
 DCValue:=128;
 If Mode=imDC Then Begin
  Sum:=0;
  Count:=0;
  If Context.AvailableAbove Then
   For X:=0 to Context.BlockWidth-1 Do Begin
    Sum:=Sum+GetAVIFPlaneByte(Plane,Context.BlockX+X,Context.BlockY-1);
    Inc(Count);
   End;
  If Context.AvailableLeft Then
   For YPos:=0 to Context.BlockHeight-1 Do Begin
    Sum:=Sum+GetAVIFPlaneByte(Plane,Context.BlockX-1,Context.BlockY+YPos);
    Inc(Count);
   End;
  If Count>0 Then DCValue:=Byte((Sum+(Count div 2))div Count);
 End;
 For YPos:=0 to Context.BlockHeight-1 Do
  For X:=0 to Context.BlockWidth-1 Do
   Case Mode of
    imVertical:
     DestPred[X,YPos]:=GetAboveRef(Plane,Context,X);
    imHorizontal:
     DestPred[X,YPos]:=GetLeftRef(Plane,Context,YPos);
    imD45:
     DestPred[X,YPos]:=GetAboveRef(Plane,Context,X+YPos+1);
    imD67:
     DestPred[X,YPos]:=GetAboveRef(Plane,Context,X+((YPos+1)div 2));
    imD113:
     If YPos>X Then DestPred[X,YPos]:=GetLeftRef(Plane,Context,YPos-X-1)
               Else DestPred[X,YPos]:=GetAboveRef(Plane,Context,X-YPos);
    imD135:
     If X>YPos Then DestPred[X,YPos]:=GetAboveRef(Plane,Context,X-YPos-1)
               Else If YPos>X Then DestPred[X,YPos]:=GetLeftRef(Plane,Context,YPos-X-1)
                              Else DestPred[X,YPos]:=GetAboveLeftRef(Plane,Context);
    imD157:
     DestPred[X,YPos]:=GetLeftRef(Plane,Context,YPos+((X+1)div 2));
    imD203:
     DestPred[X,YPos]:=GetLeftRef(Plane,Context,X+YPos+1);
    imSmooth:Begin
     A:=SmoothInterp(GetAboveRef(Plane,Context,X),GetLeftRef(Plane,Context,YPos),
      YPos,Context.BlockHeight);
     B:=SmoothInterp(GetLeftRef(Plane,Context,YPos),GetAboveRef(Plane,Context,X),
      X,Context.BlockWidth);
     DestPred[X,YPos]:=Byte((Word(A)+Word(B)+1)div 2);
    End;
    imSmoothV:
     DestPred[X,YPos]:=SmoothInterp(GetAboveRef(Plane,Context,X),
      GetLeftRef(Plane,Context,Context.BlockHeight-1),YPos,Context.BlockHeight);
    imSmoothH:
     DestPred[X,YPos]:=SmoothInterp(GetLeftRef(Plane,Context,YPos),
      GetAboveRef(Plane,Context,Context.BlockWidth-1),X,Context.BlockWidth);
    imPaeth:Begin
     A:=GetLeftRef(Plane,Context,YPos);
     B:=GetAboveRef(Plane,Context,X);
     C:=GetAboveLeftRef(Plane,Context);
     DestPred[X,YPos]:=PaethPredictor(A,B,C);
    End;
    Else
     DestPred[X,YPos]:=DCValue;
   End;
End;

Procedure ComputeResidual(Const Plane:TAVIFPlane;Const Context:TBlockContext;
 Const PredBlock:TAV1ByteBlock;Var ResidualBlock:TAV1ResidualBlock);
Var
 X,YPos:Byte;
Begin
 For YPos:=0 to Context.BlockHeight-1 Do
  For X:=0 to Context.BlockWidth-1 Do
   ResidualBlock[X,YPos]:=Integer(GetAVIFPlaneByte(Plane,Context.BlockX+X,
    Context.BlockY+YPos))-Integer(PredBlock[X,YPos]);
End;

Function EstimateBlockSAD(Const Plane:TAVIFPlane;Const Context:TBlockContext;
 Const PredBlock:TAV1ByteBlock):LongInt;
Var
 X,YPos:Byte;
 Diff:Integer;
 Sad:LongInt;
Begin
 Sad:=0;
 For YPos:=0 to Context.BlockHeight-1 Do
  For X:=0 to Context.BlockWidth-1 Do Begin
   Diff:=Integer(GetAVIFPlaneByte(Plane,Context.BlockX+X,Context.BlockY+YPos))-
    Integer(PredBlock[X,YPos]);
   If Diff<0 Then Diff:=-Diff;
   Sad:=Sad+Diff;
  End;
 EstimateBlockSAD:=Sad;
End;

Function EstimateBlockSSE(Const Plane:TAVIFPlane;Const Context:TBlockContext;
 Const PredBlock:TAV1ByteBlock):LongInt;
Var
 X,YPos:Byte;
 Diff:LongInt;
 Sse:LongInt;
Begin
 Sse:=0;
 For YPos:=0 to Context.BlockHeight-1 Do
  For X:=0 to Context.BlockWidth-1 Do Begin
   Diff:=LongInt(GetAVIFPlaneByte(Plane,Context.BlockX+X,Context.BlockY+YPos))-
    LongInt(PredBlock[X,YPos]);
   Sse:=Sse+Diff*Diff;
  End;
 EstimateBlockSSE:=Sse;
End;

Function EstimateModeRate(Mode:TIntraMode;Const Context:TBlockContext):LongInt;
Begin
 Case Mode of
  imDC:EstimateModeRate:=8;
  imVertical,imHorizontal:EstimateModeRate:=10;
  imD45,imD67,imD113,imD135,imD157,imD203:EstimateModeRate:=18;
  imSmooth,imSmoothV,imSmoothH:EstimateModeRate:=16;
  imPaeth:EstimateModeRate:=20;
  Else EstimateModeRate:=24;
 End;
 If(not Context.AvailableAbove)or(not Context.AvailableLeft)Then
  EstimateModeRate:=EstimateModeRate+2;
End;

Function InitialLambdaFromQ(BaseQIndex:Byte):LongInt;
Begin
 InitialLambdaFromQ:=LongInt(8)+(LongInt(BaseQIndex)div 8);
End;

Function ModeAllowedForContext(Mode:TIntraMode;Const Context:TBlockContext;
 EnableDirectional:Boolean):Boolean;
Begin
 ModeAllowedForContext:=True;
 If(not EnableDirectional)and(Mode>imHorizontal)Then Begin
  ModeAllowedForContext:=False;
  Exit;
 End;
 If(Context.BlockWidth<4)or(Context.BlockHeight<4)Then
  If Mode>imHorizontal Then ModeAllowedForContext:=False;
 If(not Context.AvailableAbove)and
  (Mode in [imVertical,imD45,imD67,imSmoothV])Then ModeAllowedForContext:=False;
 If(not Context.AvailableLeft)and
  (Mode in [imHorizontal,imD157,imD203,imSmoothH])Then ModeAllowedForContext:=False;
End;

Function GetTransformWidth(TxSize:TTransformSize):Byte;
Begin
 Case TxSize of
  txSize4x4:GetTransformWidth:=4;
  txSize8x8:GetTransformWidth:=8;
  txSize16x16:GetTransformWidth:=16;
  Else GetTransformWidth:=32;
 End;
End;

Function GetTransformHeight(TxSize:TTransformSize):Byte;
Begin
 GetTransformHeight:=GetTransformWidth(TxSize);
End;

Function GetTransformSizePixels(TxSize:TTransformSize):Byte;
Begin
 GetTransformSizePixels:=GetTransformWidth(TxSize);
End;

Function SelectTransformSizeForBlock(Const Context:TBlockContext;
 Sad,Sse:LongInt):TTransformSize;
Var
 Area:LongInt;
 Activity:LongInt;
 MaxSize:Byte;
Begin
 MaxSize:=Context.BlockWidth;
 If Context.BlockHeight<MaxSize Then MaxSize:=Context.BlockHeight;
 Area:=LongInt(Context.BlockWidth)*LongInt(Context.BlockHeight);
 If Area>0 Then Activity:=Sad div Area
           Else Activity:=255;
 If(MaxSize>=32)and(Activity<2)Then SelectTransformSizeForBlock:=txSize32x32
 Else If(MaxSize>=16)and(Activity<5)Then SelectTransformSizeForBlock:=txSize16x16
 Else If(MaxSize>=8)and(Activity<24)Then SelectTransformSizeForBlock:=txSize8x8
 Else SelectTransformSizeForBlock:=txSize4x4;
 If(Sse>Sad*64)and(SelectTransformSizeForBlock>txSize4x4)Then
  SelectTransformSizeForBlock:=Pred(SelectTransformSizeForBlock);
End;

Function SplitBlockIntoTransforms(BlockWidth,BlockHeight:Byte;
 PreferredTxSize:TTransformSize;Var Units:TTransformUnitList):Boolean;
Var
 TxW,TxH:Byte;
 X,YPos:Byte;
Begin
 SplitBlockIntoTransforms:=False;
 Units.Count:=0;
 TxW:=GetTransformWidth(PreferredTxSize);
 TxH:=GetTransformHeight(PreferredTxSize);
 If(TxW=0)or(TxH=0)Then Exit;
 If(TxW>BlockWidth)or(TxH>BlockHeight)Then Begin
  PreferredTxSize:=txSize4x4;
  TxW:=4;
  TxH:=4;
 End;
 YPos:=0;
 While YPos<BlockHeight Do Begin
  X:=0;
  While X<BlockWidth Do Begin
   If Units.Count>=AV1MaxTransformUnits Then Exit;
   Units.Units[Units.Count].OffsetX:=X;
   Units.Units[Units.Count].OffsetY:=YPos;
   Units.Units[Units.Count].Width:=TxW;
   Units.Units[Units.Count].Height:=TxH;
   Units.Units[Units.Count].TxSize:=PreferredTxSize;
   Inc(Units.Count);
   X:=X+TxW;
  End;
  YPos:=YPos+TxH;
 End;
 SplitBlockIntoTransforms:=True;
End;

Function ClipTransformValue(Value:LongInt):Integer;
Begin
 If Value<-32768 Then ClipTransformValue:=-32768
 Else If Value>32767 Then ClipTransformValue:=32767
                       Else ClipTransformValue:=Integer(Value);
End;

Procedure Forward1D(Const InVec:TTransformBlock;Var OutVec:TTransformBlock;
 Row:Byte;Size:Byte;Horizontal:Boolean;Kind:TTransformType);
Var
 Temp:Array[0..AV1MaxTransformSize-1]of LongInt;
 Step,Half,I,J,Pair:Byte;
 A,B:LongInt;
Begin
 For I:=0 to Size-1 Do Begin
  If Horizontal Then Temp[I]:=InVec[I,Row]
                Else Temp[I]:=InVec[Row,I];
 End;
 If(Kind=txADST_DCT)or(Kind=txADST_ADST)Then
  For I:=0 to (Size div 2)-1 Do Begin
   A:=Temp[I];
   Temp[I]:=Temp[Size-1-I];
   Temp[Size-1-I]:=A;
  End;
 If Kind<>txIdentity Then Begin
  Step:=1;
  While Step<Size Do Begin
   Half:=Step;
   Step:=Step shl 1;
   Pair:=0;
   While Pair<Size Do Begin
    For J:=0 to Half-1 Do Begin
     A:=Temp[Pair+J];
     B:=Temp[Pair+J+Half];
     Temp[Pair+J]:=A+B;
     Temp[Pair+J+Half]:=A-B;
    End;
    Pair:=Pair+Step;
   End;
  End;
 End;
 For I:=0 to Size-1 Do Begin
  If Horizontal Then OutVec[I,Row]:=Temp[I]
                Else OutVec[Row,I]:=Temp[I];
 End;
End;

Procedure Inverse1D(Const InVec:TTransformBlock;Var OutVec:TTransformBlock;
 Row:Byte;Size:Byte;Horizontal:Boolean;Kind:TTransformType);
Var
 Temp:Array[0..AV1MaxTransformSize-1]of LongInt;
 Step,Half,I,J,Pair:Byte;
 A,B:LongInt;
Begin
 For I:=0 to Size-1 Do Begin
  If Horizontal Then Temp[I]:=InVec[I,Row]
                Else Temp[I]:=InVec[Row,I];
 End;
 If Kind<>txIdentity Then Begin
  Step:=1;
  While Step<Size Do Begin
   Half:=Step;
   Step:=Step shl 1;
   Pair:=0;
   While Pair<Size Do Begin
    For J:=0 to Half-1 Do Begin
     A:=Temp[Pair+J];
     B:=Temp[Pair+J+Half];
     Temp[Pair+J]:=(A+B)div 2;
     Temp[Pair+J+Half]:=(A-B)div 2;
    End;
    Pair:=Pair+Step;
   End;
  End;
  If(Kind=txADST_DCT)or(Kind=txADST_ADST)Then
   For I:=0 to (Size div 2)-1 Do Begin
    A:=Temp[I];
    Temp[I]:=Temp[Size-1-I];
    Temp[Size-1-I]:=A;
   End;
 End;
 For I:=0 to Size-1 Do Begin
  If Horizontal Then OutVec[I,Row]:=Temp[I]
                Else OutVec[Row,I]:=Temp[I];
 End;
End;

Procedure ForwardTransform(Const Residual:TAV1ResidualBlock;TxType:TTransformType;
 TxSize:TTransformSize;Var Coeffs:TTransformBlock);
Var
 Temp,Input:TTransformBlock;
 X,YPos,Size:Byte;
 HorizontalKind,VerticalKind:TTransformType;
Begin
 FillChar(Input,SizeOf(Input),0);
 FillChar(Temp,SizeOf(Temp),0);
 FillChar(Coeffs,SizeOf(Coeffs),0);
 Size:=GetTransformSizePixels(TxSize);
 For YPos:=0 to Size-1 Do
  For X:=0 to Size-1 Do
   Input[X,YPos]:=Residual[X,YPos];
 HorizontalKind:=txDCT_DCT;
 VerticalKind:=txDCT_DCT;
 Case TxType of
  txADST_DCT:HorizontalKind:=txADST_DCT;
  txDCT_ADST:VerticalKind:=txADST_DCT;
  txADST_ADST:Begin
   HorizontalKind:=txADST_ADST;
   VerticalKind:=txADST_ADST;
  End;
  txIdentity:Begin
   HorizontalKind:=txIdentity;
   VerticalKind:=txIdentity;
  End;
 End;
 For YPos:=0 to Size-1 Do
  Forward1D(Input,Temp,YPos,Size,True,HorizontalKind);
 For X:=0 to Size-1 Do
  Forward1D(Temp,Coeffs,X,Size,False,VerticalKind);
End;

Procedure InverseTransform(Const Coeffs:TTransformBlock;TxType:TTransformType;
 TxSize:TTransformSize;Var ReconResidual:TAV1ResidualBlock);
Var
 Temp,Output:TTransformBlock;
 X,YPos,Size:Byte;
 HorizontalKind,VerticalKind:TTransformType;
Begin
 FillChar(ReconResidual,SizeOf(ReconResidual),0);
 FillChar(Temp,SizeOf(Temp),0);
 FillChar(Output,SizeOf(Output),0);
 Size:=GetTransformSizePixels(TxSize);
 HorizontalKind:=txDCT_DCT;
 VerticalKind:=txDCT_DCT;
 Case TxType of
  txADST_DCT:HorizontalKind:=txADST_DCT;
  txDCT_ADST:VerticalKind:=txADST_DCT;
  txADST_ADST:Begin
   HorizontalKind:=txADST_ADST;
   VerticalKind:=txADST_ADST;
  End;
  txIdentity:Begin
   HorizontalKind:=txIdentity;
   VerticalKind:=txIdentity;
  End;
 End;
 For X:=0 to Size-1 Do
  Inverse1D(Coeffs,Temp,X,Size,False,VerticalKind);
 For YPos:=0 to Size-1 Do
  Inverse1D(Temp,Output,YPos,Size,True,HorizontalKind);
 For YPos:=0 to Size-1 Do
  For X:=0 to Size-1 Do
   ReconResidual[X,YPos]:=ClipTransformValue(Output[X,YPos]);
End;

Function TransformEnergy(Const Coeffs:TTransformBlock;TxSize:TTransformSize):LongInt;
Var
 X,YPos,Size:Byte;
 V:LongInt;
 Energy:LongInt;
Begin
 Size:=GetTransformSizePixels(TxSize);
 Energy:=0;
 For YPos:=0 to Size-1 Do
  For X:=0 to Size-1 Do Begin
   V:=Coeffs[X,YPos];
   If V<0 Then V:=-V;
   If(X<>0)or(YPos<>0)Then
    Energy:=Energy+V;
  End;
 TransformEnergy:=Energy;
End;

Procedure InitQuantConfig(Var Config:TQuantConfig);
Begin
 Config.BaseQIndex:=96;
 Config.DeltaQYDC:=0;
 Config.DeltaQUDC:=0;
 Config.DeltaQUAC:=0;
 Config.DeltaQVDC:=0;
 Config.DeltaQVAC:=0;
 Config.UseSeparateUVDeltAQ:=False;
End;

Function ClampQuantIndex(Value:Integer):Byte;
Begin
 If Value<0 Then ClampQuantIndex:=0
 Else If Value>255 Then ClampQuantIndex:=255
                       Else ClampQuantIndex:=Byte(Value);
End;

Function GetQuantStep(BaseQIndex:Byte;Delta:ShortInt):LongInt;
Var
 QIndex:Byte;
Begin
 QIndex:=ClampQuantIndex(Integer(BaseQIndex)+Integer(Delta));
 GetQuantStep:=LongInt(4)+(LongInt(QIndex)div 4);
End;

Function GetPlaneQuantStep(PlaneID:Byte;IsDC:Boolean;
 Const Config:TQuantConfig):LongInt;
Begin
 If PlaneID=0 Then Begin
  If IsDC Then GetPlaneQuantStep:=GetQuantStep(Config.BaseQIndex,Config.DeltaQYDC)
          Else GetPlaneQuantStep:=GetQuantStep(Config.BaseQIndex,0);
 End
  Else If PlaneID=1 Then Begin
   If IsDC Then GetPlaneQuantStep:=GetQuantStep(Config.BaseQIndex,Config.DeltaQUDC)
           Else GetPlaneQuantStep:=GetQuantStep(Config.BaseQIndex,Config.DeltaQUAC);
  End
  Else Begin
   If IsDC Then GetPlaneQuantStep:=GetQuantStep(Config.BaseQIndex,Config.DeltaQVDC)
           Else GetPlaneQuantStep:=GetQuantStep(Config.BaseQIndex,Config.DeltaQVAC);
  End;
End;

Function GetCoeffQuantStep(PlaneID:Byte;X,YPos:Byte;
 Const Config:TQuantConfig):LongInt;
Var
 Step,Weight:LongInt;
Begin
 Step:=GetPlaneQuantStep(PlaneID,(X=0)and(YPos=0),Config);
 Weight:=16+LongInt(X)+LongInt(YPos);
 GetCoeffQuantStep:=(Step*Weight+8)div 16;
 If GetCoeffQuantStep<1 Then GetCoeffQuantStep:=1;
End;

Function ClampQCoeff(Value:LongInt):SmallInt;
Begin
 If Value<-32768 Then ClampQCoeff:=-32768
 Else If Value>32767 Then ClampQCoeff:=32767
                       Else ClampQCoeff:=SmallInt(Value);
End;

Function AbsSmallInt(Value:SmallInt):Word;
Begin
 If Value<0 Then AbsSmallInt:=Word(-LongInt(Value))
            Else AbsSmallInt:=Word(Value);
End;

Function QuantizeCoeff(Coeff,QStep:LongInt):SmallInt;
Var
 AbsCoeff,Q:LongInt;
Begin
 If QStep<=0 Then QStep:=1;
 If Coeff<0 Then AbsCoeff:=-Coeff
            Else AbsCoeff:=Coeff;
 Q:=(AbsCoeff+(QStep div 2))div QStep;
 If Coeff<0 Then Q:=-Q;
 QuantizeCoeff:=ClampQCoeff(Q);
End;

Function DequantizeCoeff(QCoeff:SmallInt;QStep:LongInt):LongInt;
Begin
 DequantizeCoeff:=LongInt(QCoeff)*QStep;
End;

Function ScanIndexToXY(Index:Word;TxSize:TTransformSize;Var X,Y:Byte):Boolean;
Var
 Size:Byte;
 Diag,StartX,EndX:Integer;
 Count:Word;
 CX:Integer;
Begin
 ScanIndexToXY:=False;
 Size:=GetTransformSizePixels(TxSize);
 Count:=0;
 For Diag:=0 to (Size*2)-2 Do Begin
  If Diag<Size Then StartX:=0 Else StartX:=Diag-Size+1;
  If Diag<Size Then EndX:=Diag Else EndX:=Size-1;
  For CX:=StartX to EndX Do Begin
   If Count=Index Then Begin
    X:=Byte(CX);
    Y:=Byte(Diag-CX);
    ScanIndexToXY:=True;
    Exit;
   End;
   Inc(Count);
  End;
 End;
End;

Procedure QuantizeBlock(Const Coeffs:TTransformBlock;TxSize:TTransformSize;
 PlaneID:Byte;Const Config:TQuantConfig;Var QCoeffs:TQuantBlock;Var EOB:Word);
Var
 Size:Byte;
 X,YPos:Byte;
 I,Total:Word;
 QStep:LongInt;
Begin
 FillChar(QCoeffs,SizeOf(QCoeffs),0);
 Size:=GetTransformSizePixels(TxSize);
 EOB:=0;
 For YPos:=0 to Size-1 Do
  For X:=0 to Size-1 Do Begin
   QStep:=GetCoeffQuantStep(PlaneID,X,YPos,Config);
   QCoeffs[X,YPos]:=QuantizeCoeff(Coeffs[X,YPos],QStep);
  End;
 Total:=Word(Size)*Word(Size);
 For I:=0 to Total-1 Do Begin
  If ScanIndexToXY(I,TxSize,X,YPos)Then
   If QCoeffs[X,YPos]<>0 Then EOB:=I+1;
 End;
End;

Procedure DequantizeBlock(Const QCoeffs:TQuantBlock;TxSize:TTransformSize;
 PlaneID:Byte;Const Config:TQuantConfig;Var DequantCoeffs:TTransformBlock);
Var
 Size:Byte;
 X,YPos:Byte;
 QStep:LongInt;
Begin
 FillChar(DequantCoeffs,SizeOf(DequantCoeffs),0);
 Size:=GetTransformSizePixels(TxSize);
 For YPos:=0 to Size-1 Do
  For X:=0 to Size-1 Do Begin
   QStep:=GetCoeffQuantStep(PlaneID,X,YPos,Config);
   DequantCoeffs[X,YPos]:=DequantizeCoeff(QCoeffs[X,YPos],QStep);
  End;
End;

Function SelectTransformTypeForMode(Mode:TIntraMode):TTransformType;
Begin
 Case Mode of
  imVertical,imHorizontal:SelectTransformTypeForMode:=txDCT_DCT;
  imD45,imD67,imD113,imD135,imD157,imD203:SelectTransformTypeForMode:=txADST_DCT;
  imSmooth,imSmoothV,imSmoothH:SelectTransformTypeForMode:=txDCT_ADST;
  imPaeth:SelectTransformTypeForMode:=txADST_ADST;
  Else SelectTransformTypeForMode:=txDCT_DCT;
 End;
End;

Function TestIntraMode(Mode:TIntraMode;Const Plane:TAVIFPlane;
 Const Context:TBlockContext;Lambda:LongInt;Var Pred:TAV1ByteBlock;
 Var Residual:TAV1ResidualBlock;Var Result:TModeDecisionResult):Boolean;
Var
 Sad,Sse,Rate,Energy:LongInt;
 Coeffs,DequantCoeffs:TTransformBlock;
 QCoeffs:TQuantBlock;
 QuantConfig:TQuantConfig;
 UnitResidual:TAV1ResidualBlock;
 Recon:TAV1ResidualBlock;
 TxType:TTransformType;
 TxSize:TTransformSize;
 Units:TTransformUnitList;
 UnitEOB:Word;
 MaxEOB:Word;
 UnitIndex:Byte;
 X,YPos:Byte;
Begin
 TestIntraMode:=False;
 InitQuantConfig(QuantConfig);
 PredictBlock(Mode,Context,Plane,Pred);
 ComputeResidual(Plane,Context,Pred,Residual);
 Sad:=EstimateBlockSAD(Plane,Context,Pred);
 Sse:=EstimateBlockSSE(Plane,Context,Pred);
 TxSize:=SelectTransformSizeForBlock(Context,Sad,Sse);
 If not SplitBlockIntoTransforms(Context.BlockWidth,Context.BlockHeight,TxSize,Units)Then
  Exit;
 TxType:=SelectTransformTypeForMode(Mode);
 Energy:=0;
 MaxEOB:=0;
 For UnitIndex:=0 to Units.Count-1 Do Begin
  FillChar(UnitResidual,SizeOf(UnitResidual),0);
  For YPos:=0 to Units.Units[UnitIndex].Height-1 Do
   For X:=0 to Units.Units[UnitIndex].Width-1 Do
    UnitResidual[X,YPos]:=Residual[Units.Units[UnitIndex].OffsetX+X,
     Units.Units[UnitIndex].OffsetY+YPos];
  ForwardTransform(UnitResidual,TxType,Units.Units[UnitIndex].TxSize,Coeffs);
  QuantizeBlock(Coeffs,Units.Units[UnitIndex].TxSize,Context.PlaneID,
   QuantConfig,QCoeffs,UnitEOB);
  DequantizeBlock(QCoeffs,Units.Units[UnitIndex].TxSize,Context.PlaneID,
   QuantConfig,DequantCoeffs);
  InverseTransform(DequantCoeffs,TxType,Units.Units[UnitIndex].TxSize,Recon);
  Energy:=Energy+TransformEnergy(DequantCoeffs,Units.Units[UnitIndex].TxSize);
  If UnitEOB>MaxEOB Then MaxEOB:=UnitEOB;
 End;
 If(Context.BlockWidth>=8)and(Context.BlockHeight>=8)Then
  Result.Distortion:=Sse
 Else
  Result.Distortion:=Sad;
 Rate:=EstimateModeRate(Mode,Context);
 Result.BlockX:=Context.BlockX;
 Result.BlockY:=Context.BlockY;
 Result.BlockWidth:=Context.BlockWidth;
 Result.BlockHeight:=Context.BlockHeight;
 Result.BestMode:=Mode;
 Result.TransformSize:=TxSize;
 Result.TransformType:=TxType;
 Result.RateEstimate:=Rate;
 Result.TransformEnergy:=Energy;
 Result.EOB:=MaxEOB;
 Result.BestCost:=Result.Distortion+(Energy shr 3)+
  ((Lambda*Rate)shr AV1LambdaShift);
 TestIntraMode:=True;
End;

Function ChooseBestIntraMode(Const Plane:TAVIFPlane;Const Context:TBlockContext;
 Lambda:LongInt;EnableDirectional:Boolean;Var BestPred:TAV1ByteBlock;
 Var BestResidual:TAV1ResidualBlock;Var Decision:TModeDecisionResult):TIntraMode;
Var
 Mode:TIntraMode;
 Pred:TAV1ByteBlock;
 Residual:TAV1ResidualBlock;
 Candidate:TModeDecisionResult;
 BestMode:TIntraMode;
Begin
 Decision.BestCost:=$7FFFFFFF;
 Decision.Distortion:=0;
 Decision.RateEstimate:=0;
 BestMode:=imDC;
 For Mode:=imDC to imPaeth Do Begin
  If ModeAllowedForContext(Mode,Context,EnableDirectional)Then Begin
   If not TestIntraMode(Mode,Plane,Context,Lambda,Pred,Residual,Candidate)Then
    Continue;
   If Candidate.BestCost<Decision.BestCost Then Begin
    Decision:=Candidate;
    BestResidual:=Residual;
    BestPred:=Pred;
    BestMode:=Mode;
   End;
  End;
 End;
 If Decision.BestCost=$7FFFFFFF Then Begin
  TestIntraMode(imDC,Plane,Context,Lambda,BestPred,BestResidual,Decision);
  BestMode:=imDC;
 End;
 ChooseBestIntraMode:=BestMode;
End;

Procedure InitModeDecisionMap(Var Map:TModeDecisionMap);
Begin
 Map.Decisions:=Nil;
 Map.Count:=0;
 Map.Capacity:=0;
End;

Function AllocateModeDecisionMap(Var Map:TModeDecisionMap;Capacity:Word):Boolean;
Begin
 AllocateModeDecisionMap:=False;
 InitModeDecisionMap(Map);
 If(Capacity=0)or(Capacity>AV1MaxModeDecisionBlocks)Then Exit;
 GetMem(Map.Decisions,LongInt(Capacity)*SizeOf(TModeDecisionResult));
 If Map.Decisions=Nil Then Exit;
 Map.Capacity:=Capacity;
 Map.Count:=0;
 AllocateModeDecisionMap:=True;
End;

Procedure FreeModeDecisionMap(Var Map:TModeDecisionMap);
Begin
 If Map.Decisions<>Nil Then
  FreeMem(Map.Decisions,LongInt(Map.Capacity)*SizeOf(TModeDecisionResult));
 InitModeDecisionMap(Map);
End;

Function AddModeDecision(Var Map:TModeDecisionMap;
 Const Decision:TModeDecisionResult):Boolean;
Begin
 AddModeDecision:=False;
 If(Map.Decisions=Nil)or(Map.Count>=Map.Capacity)Then Exit;
 Map.Decisions^[Map.Count]:=Decision;
 Inc(Map.Count);
 AddModeDecision:=True;
End;

Procedure InitSegmentationConfig(Var Config:TSegmentationConfig);
Begin
 Config.SegmentationEnabled:=False;
 Config.UpdateMap:=False;
 Config.UpdateData:=False;
End;

Procedure InitLoopFilterConfig(Var Config:TLoopFilterConfig);
Begin
 Config.FilterLevelY:=0;
 Config.FilterLevelU:=0;
 Config.FilterLevelV:=0;
 Config.Sharpness:=0;
 Config.ModeRefDeltaEnabled:=False;
 Config.ModeRefDeltaUpdate:=False;
End;

Procedure ApplyLoopFilter(Const Config:TLoopFilterConfig;Const Image:TAVIFImage);
Begin
 {No-op initial : tous les niveaux de filtre valent zero.}
 If(Config.FilterLevelY=0)and(Config.FilterLevelU=0)and(Config.FilterLevelV=0)Then Begin
  If Image.Width=0 Then Begin
  End;
 End;
End;

Procedure InitBlockSyntaxMap(Var Map:TBlockSyntaxMap);
Begin
 Map.Blocks:=Nil;
 Map.Count:=0;
 Map.Capacity:=0;
 Map.SkipCount:=0;
 Map.NonSkipCount:=0;
End;

Function AllocateBlockSyntaxMap(Var Map:TBlockSyntaxMap;Capacity:Word):Boolean;
Begin
 AllocateBlockSyntaxMap:=False;
 InitBlockSyntaxMap(Map);
 If(Capacity=0)or(Capacity>AV1MaxModeDecisionBlocks)Then Exit;
 GetMem(Map.Blocks,LongInt(Capacity)*SizeOf(TBlockSyntaxInfo));
 If Map.Blocks=Nil Then Exit;
 Map.Capacity:=Capacity;
 AllocateBlockSyntaxMap:=True;
End;

Procedure FreeBlockSyntaxMap(Var Map:TBlockSyntaxMap);
Begin
 If Map.Blocks<>Nil Then
  FreeMem(Map.Blocks,LongInt(Map.Capacity)*SizeOf(TBlockSyntaxInfo));
 InitBlockSyntaxMap(Map);
End;

Procedure BuildBlockSyntaxInfo(Const Decision:TModeDecisionResult;
 Const QuantConfig:TQuantConfig;Const SegConfig:TSegmentationConfig;
 Var Info:TBlockSyntaxInfo);
Begin
 Info.Skip:=Decision.EOB=0;
 If SegConfig.SegmentationEnabled Then Info.SegmentId:=DefaultSegmentId
                                  Else Info.SegmentId:=DefaultSegmentId;
 Info.TxSize:=Decision.TransformSize;
 Info.TxType:=Decision.TransformType;
 Info.IntraMode:=Decision.BestMode;
 Info.QuantizerIndex:=QuantConfig.BaseQIndex;
 Info.EOB:=Decision.EOB;
End;

Function AddBlockSyntaxInfo(Var Map:TBlockSyntaxMap;
 Const Info:TBlockSyntaxInfo):Boolean;
Begin
 AddBlockSyntaxInfo:=False;
 If(Map.Blocks=Nil)or(Map.Count>=Map.Capacity)Then Exit;
 Map.Blocks^[Map.Count]:=Info;
 Inc(Map.Count);
 If Info.Skip Then Inc(Map.SkipCount)
              Else Inc(Map.NonSkipCount);
 AddBlockSyntaxInfo:=True;
End;

Procedure InitCoeffSymbolMap(Var Map:TCoeffSymbolMap);
Begin
 Map.Symbols:=Nil;
 Map.Count:=0;
 Map.Capacity:=0;
End;

Function AllocateCoeffSymbolMap(Var Map:TCoeffSymbolMap;Capacity:Word):Boolean;
Begin
 AllocateCoeffSymbolMap:=False;
 InitCoeffSymbolMap(Map);
 If(Capacity=0)or(Capacity>AV1MaxCoeffSymbols)Then Exit;
 GetMem(Map.Symbols,LongInt(Capacity)*SizeOf(TCoeffSymbol));
 If Map.Symbols=Nil Then Exit;
 Map.Capacity:=Capacity;
 AllocateCoeffSymbolMap:=True;
End;

Procedure FreeCoeffSymbolMap(Var Map:TCoeffSymbolMap);
Begin
 If Map.Symbols<>Nil Then
  FreeMem(Map.Symbols,LongInt(Map.Capacity)*SizeOf(TCoeffSymbol));
 InitCoeffSymbolMap(Map);
End;

Function AddCoeffSymbol(Var Map:TCoeffSymbolMap;Kind:TCoeffSymbolKind;
 ContextId:Byte;Position:Word;Symbol:SmallInt):Boolean;
Begin
 AddCoeffSymbol:=False;
 If(Map.Symbols=Nil)or(Map.Count>=Map.Capacity)Then Exit;
 Map.Symbols^[Map.Count].Kind:=Kind;
 Map.Symbols^[Map.Count].ContextId:=ContextId;
 Map.Symbols^[Map.Count].Position:=Position;
 Map.Symbols^[Map.Count].Symbol:=Symbol;
 Inc(Map.Count);
 AddCoeffSymbol:=True;
End;

Function GetEOBContext(Const Context:TCoeffCodingContext):Byte;
Begin
 GetEOBContext:=Ord(Context.TxSize)*4;
 If Context.Plane<>0 Then Inc(GetEOBContext);
 If Context.AboveNonZero Then Inc(GetEOBContext);
 If Context.LeftNonZero Then Inc(GetEOBContext);
End;

Function GetCoeffBaseContext(Const Context:TCoeffCodingContext;Position:Word):Byte;
Begin
 GetCoeffBaseContext:=Byte((Ord(Context.TxSize)*8+(Position mod 8))and $3F);
 If Context.Plane<>0 Then Inc(GetCoeffBaseContext,16);
End;

Function GetCoeffBrContext(Const Context:TCoeffCodingContext;Position:Word;
 Level:Word):Byte;
Begin
 GetCoeffBrContext:=Byte((Ord(Context.TxSize)*8+(Position mod 4)+Level)and $3F);
 If Context.TxType<>txDCT_DCT Then Inc(GetCoeffBrContext,8);
End;

Procedure InitCoeffCodingContext(Plane:Byte;Const Syntax:TBlockSyntaxInfo;
 Var Context:TCoeffCodingContext);
Begin
 Context.Plane:=Plane;
 Context.TxSize:=Syntax.TxSize;
 Context.TxType:=Syntax.TxType;
 Context.EOB:=Syntax.EOB;
 Context.ScanOrder:=csoDiagonal;
 Context.IsInter:=False;
 Context.AboveNonZero:=False;
 Context.LeftNonZero:=False;
End;

Function EncodeCoeffSymbolsForBlock(Const Syntax:TBlockSyntaxInfo;
 Var Symbols:TCoeffSymbolMap):Boolean;
Var
 Context:TCoeffCodingContext;
 Pos:Word;
 Level:Word;
Begin
 EncodeCoeffSymbolsForBlock:=False;
 InitCoeffCodingContext(0,Syntax,Context);
 If not AddCoeffSymbol(Symbols,cskEOB,GetEOBContext(Context),0,Syntax.EOB)Then Exit;
 If Syntax.Skip or(Syntax.EOB=0)Then Begin
  EncodeCoeffSymbolsForBlock:=True;
  Exit;
 End;
 For Pos:=0 to Syntax.EOB-1 Do Begin
  If Pos=Syntax.EOB-1 Then Level:=1 Else Level:=0;
  If not AddCoeffSymbol(Symbols,cskCoeffBase,GetCoeffBaseContext(Context,Pos),
   Pos,SmallInt(Level))Then Exit;
  If Level>0 Then Begin
   If not AddCoeffSymbol(Symbols,cskCoeffSign,0,Pos,0)Then Exit;
   If Level>2 Then
    If not AddCoeffSymbol(Symbols,cskCoeffExtra,
     GetCoeffBrContext(Context,Pos,Level),Pos,SmallInt(Level-2))Then Exit;
  End;
 End;
 EncodeCoeffSymbolsForBlock:=True;
End;

Procedure InitUniformCDF(Var Model:TEntropyCDF;SymbolCount:Byte);
Var
 I:Byte;
 Step:Word;
Begin
 If SymbolCount<2 Then SymbolCount:=2;
 If SymbolCount>16 Then SymbolCount:=16;
 Model.SymbolCount:=SymbolCount;
 Step:=32768 div SymbolCount;
 Model.CDF[0]:=0;
 For I:=1 to SymbolCount-1 Do
  Model.CDF[I]:=I*Step;
 Model.CDF[SymbolCount]:=32768;
End;

Procedure InitEntropyModels(Var Models:TEntropyModels;DisableCDFUpdate:Boolean);
Begin
 InitUniformCDF(Models.SkipCDF,2);
 InitUniformCDF(Models.IntraModeCDF,13);
 InitUniformCDF(Models.TxSizeCDF,4);
 InitUniformCDF(Models.EOBCDF,16);
 InitUniformCDF(Models.CoeffBaseCDF,4);
 InitUniformCDF(Models.CoeffExtraCDF,16);
 InitUniformCDF(Models.CoeffSignCDF,2);
 Models.DisableCDFUpdate:=DisableCDFUpdate;
End;

Procedure UpdateCDF(Var Model:TEntropyCDF;Symbol:Byte);
Var
 I:Byte;
Begin
 If Symbol>=Model.SymbolCount Then Symbol:=Model.SymbolCount-1;
 For I:=Symbol+1 to Model.SymbolCount-1 Do
  If Model.CDF[I]<32760 Then Inc(Model.CDF[I],8);
 Model.CDF[Model.SymbolCount]:=32768;
End;

Procedure InitRangeEncoder(Var Encoder:TAV1RangeEncoder;Var Buffer:TAV1ByteBuffer);
Begin
 Encoder.Low:=0;
 Encoder.Range:=32768;
 Encoder.Count:=0;
 Encoder.Buffer:=@Buffer;
 Encoder.Position:=Buffer.Size;
 Encoder.Failed:=False;
 Encoder.Trace:=False;
End;

Procedure RangeEncoderEmitByte(Var Encoder:TAV1RangeEncoder;Value:Byte);
Begin
 If Encoder.Failed Then Exit;
 If Encoder.Buffer=Nil Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not AV1BufferAppendByte(Encoder.Buffer^,Value)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 Inc(Encoder.Count);
 Encoder.Position:=Encoder.Buffer^.Size;
End;

Procedure NormalizeRangeEncoder(Var Encoder:TAV1RangeEncoder);
Begin
 While(Encoder.Range<4096)and(not Encoder.Failed)Do Begin
  RangeEncoderEmitByte(Encoder,Byte((Encoder.Low shr 8)and $FF));
  Encoder.Low:=(Encoder.Low shl 8)and $7FFF;
  Encoder.Range:=Encoder.Range shl 8;
  If Encoder.Range>32768 Then Encoder.Range:=32768;
 End;
End;

Procedure EncodeBool(Var Encoder:TAV1RangeEncoder;Value:Boolean;Probability:Word);
Var
 Split:LongInt;
Begin
 If Probability=0 Then Probability:=1;
 If Probability>=32768 Then Probability:=32767;
 Split:=(Encoder.Range*Probability)div 32768;
 If Split<=0 Then Split:=1;
 If Value Then Begin
  Encoder.Low:=Encoder.Low+Split;
  Encoder.Range:=Encoder.Range-Split;
 End
  Else
  Encoder.Range:=Split;
 NormalizeRangeEncoder(Encoder);
End;

Procedure EncodeSymbol(Var Encoder:TAV1RangeEncoder;Symbol:Byte;
 Var Model:TEntropyCDF;AllowUpdate:Boolean);
Var
 LowCount,HighCount,Total,NewLow,NewRange:LongInt;
Begin
 If Symbol>=Model.SymbolCount Then Symbol:=Model.SymbolCount-1;
 Total:=Model.CDF[Model.SymbolCount];
 If Total<=0 Then Total:=32768;
 LowCount:=Model.CDF[Symbol];
 HighCount:=Model.CDF[Symbol+1];
 If HighCount<=LowCount Then HighCount:=LowCount+1;
 NewLow:=Encoder.Low+(Encoder.Range*LowCount)div Total;
 NewRange:=(Encoder.Range*(HighCount-LowCount))div Total;
 If NewRange<=0 Then NewRange:=1;
 Encoder.Low:=NewLow and $7FFF;
 Encoder.Range:=NewRange;
 NormalizeRangeEncoder(Encoder);
 If AllowUpdate Then UpdateCDF(Model,Symbol);
End;

Procedure FinishRangeEncoder(Var Encoder:TAV1RangeEncoder);
Begin
 NormalizeRangeEncoder(Encoder);
 RangeEncoderEmitByte(Encoder,Byte((Encoder.Low shr 7)and $FF));
 RangeEncoderEmitByte(Encoder,Byte(Encoder.Low and $7F));
End;

Function SymbolToCDFValue(Const Symbol:TCoeffSymbol;MaxSymbol:Byte):Byte;
Var
 V:LongInt;
Begin
 V:=Symbol.Symbol;
 If V<0 Then V:=-V;
 If V>MaxSymbol Then V:=MaxSymbol;
 SymbolToCDFValue:=Byte(V);
End;

Function EncodeCoeffSymbolMapWithRange(Const Symbols:TCoeffSymbolMap;
 Var Payload:TAV1ByteBuffer;Var Models:TEntropyModels):Boolean;
Var
 Encoder:TAV1RangeEncoder;
 I:Word;
 S:TCoeffSymbol;
 AllowUpdate:Boolean;
Begin
 EncodeCoeffSymbolMapWithRange:=False;
 InitRangeEncoder(Encoder,Payload);
 AllowUpdate:=not Models.DisableCDFUpdate;
 For I:=0 to Symbols.Count-1 Do Begin
  S:=Symbols.Symbols^[I];
  Case S.Kind of
   cskEOB:
    EncodeSymbol(Encoder,SymbolToCDFValue(S,15),Models.EOBCDF,AllowUpdate);
   cskCoeffBase:
    EncodeSymbol(Encoder,SymbolToCDFValue(S,3),Models.CoeffBaseCDF,AllowUpdate);
   cskCoeffExtra:
    EncodeSymbol(Encoder,SymbolToCDFValue(S,15),Models.CoeffExtraCDF,AllowUpdate);
   cskCoeffSign:
    EncodeSymbol(Encoder,SymbolToCDFValue(S,1),Models.CoeffSignCDF,AllowUpdate);
  End;
  If Encoder.Failed Then Exit;
 End;
 FinishRangeEncoder(Encoder);
 If Encoder.Failed Then Exit;
 EncodeCoeffSymbolMapWithRange:=True;
End;

Function EstimateModeDecisionCapacity(Const Grid:TAV1SuperBlockGrid):Word;
Var
 BlocksWide,BlocksHigh:LongInt;
 Total:LongInt;
Begin
 BlocksWide:=(LongInt(Grid.ImageWidth)+AV1IntraBlockSize-1)div AV1IntraBlockSize;
 BlocksHigh:=(LongInt(Grid.ImageHeight)+AV1IntraBlockSize-1)div AV1IntraBlockSize;
 Total:=BlocksWide*BlocksHigh*3;
 If Total>AV1MaxModeDecisionBlocks Then Total:=AV1MaxModeDecisionBlocks;
 EstimateModeDecisionCapacity:=Word(Total);
End;

Function ValidateIntraPredictionForPlane(Const Plane:TAVIFPlane;PlaneID:Byte;
 Lambda:LongInt;EnableDirectional:Boolean;Const QuantConfig:TQuantConfig;
 Const SegConfig:TSegmentationConfig;Var Decisions:TModeDecisionMap;
 Var SyntaxMap:TBlockSyntaxMap):Boolean;
Var
 BX,BY:Word;
 BlockW,BlockH:Byte;
 Context:TBlockContext;
 Pred:TAV1ByteBlock;
 Residual:TAV1ResidualBlock;
 Decision:TModeDecisionResult;
 SyntaxInfo:TBlockSyntaxInfo;
 Mode:TIntraMode;
Begin
 ValidateIntraPredictionForPlane:=False;
 If(Plane.Width=0)or(Plane.Height=0)Then Exit;
 BY:=0;
 While BY<Plane.Height Do Begin
  BX:=0;
  While BX<Plane.Width Do Begin
   If LongInt(BX)+AV1IntraBlockSize<=Plane.Width Then
    BlockW:=AV1IntraBlockSize
   Else
    BlockW:=Byte(Plane.Width-BX);
   If LongInt(BY)+AV1IntraBlockSize<=Plane.Height Then
    BlockH:=AV1IntraBlockSize
   Else
    BlockH:=Byte(Plane.Height-BY);
   If(BlockW=0)or(BlockH=0)Then Exit;
   InitBlockContext(PlaneID,BX,BY,BlockW,BlockH,Context);
   Mode:=ChooseBestIntraMode(Plane,Context,Lambda,EnableDirectional,
    Pred,Residual,Decision);
   If(Mode<imDC)or(Mode>imPaeth)Then Exit;
   If not AddModeDecision(Decisions,Decision)Then Exit;
   BuildBlockSyntaxInfo(Decision,QuantConfig,SegConfig,SyntaxInfo);
   If not AddBlockSyntaxInfo(SyntaxMap,SyntaxInfo)Then Exit;
   BX:=BX+BlockW;
  End;
  BY:=BY+AV1IntraBlockSize;
 End;
 ValidateIntraPredictionForPlane:=True;
End;

Function ValidateIntraPredictionForTile(Const Image:TAVIFImage;
 Const Grid:TAV1SuperBlockGrid;Const Tile:TAV1Tile;
 Lambda:LongInt;Const QuantConfig:TQuantConfig;Const SegConfig:TSegmentationConfig;
 Var Decisions:TModeDecisionMap;Var SyntaxMap:TBlockSyntaxMap):Boolean;
Begin
 ValidateIntraPredictionForTile:=False;
 If not ValidateTile(Grid,Tile)Then Exit;
 If not ValidateIntraPredictionForPlane(Image.PlaneY,0,Lambda,
  AVIFOptions.EnableDirectionalIntra,QuantConfig,SegConfig,Decisions,SyntaxMap)Then Exit;
 If not ValidateIntraPredictionForPlane(Image.PlaneU,1,Lambda,
  False,QuantConfig,SegConfig,Decisions,SyntaxMap)Then Exit;
 If not ValidateIntraPredictionForPlane(Image.PlaneV,2,Lambda,
  False,QuantConfig,SegConfig,Decisions,SyntaxMap)Then Exit;
 ValidateIntraPredictionForTile:=True;
End;

Function ValidateNeutralGrayChroma(Const Image:TAVIFImage):Boolean;
Var
 X,YPos:Word;
Begin
 ValidateNeutralGrayChroma:=False;
 If(Image.PlaneU.Data=Nil)or(Image.PlaneV.Data=Nil)Then Exit;
 For YPos:=0 to Image.PlaneU.Height-1 Do
  For X:=0 to Image.PlaneU.Width-1 Do
   If(GetAVIFPlaneByte(Image.PlaneU,X,YPos)<>128)or
    (GetAVIFPlaneByte(Image.PlaneV,X,YPos)<>128)Then Begin
    ValidateNeutralGrayChroma:=True;
    Exit;
   End;
 ValidateNeutralGrayChroma:=True;
End;

Function TileCountBits(Const TileConfig:TAV1TileConfig):Byte;
Var
 Count:LongInt;
 Bits:Byte;
Begin
 Count:=LongInt(TileConfig.TileCols)*LongInt(TileConfig.TileRows);
 Bits:=0;
 If Count<=1 Then Begin
  TileCountBits:=0;
  Exit;
 End;
 Dec(Count);
 While Count>0 Do Begin
  Inc(Bits);
  Count:=Count shr 1;
 End;
 TileCountBits:=Bits;
End;

Function ValidateTileGroupConfig(Const TileConfig:TAV1TileConfig;
 Const Tile:TAV1Tile):Boolean;
Var
 TileCount:LongInt;
Begin
 ValidateTileGroupConfig:=False;
 If(TileConfig.TileCols=0)or(TileConfig.TileRows=0)Then Exit;
 TileCount:=LongInt(TileConfig.TileCols)*LongInt(TileConfig.TileRows);
 If(TileCount<=0)or(TileCount>65535)Then Exit;
 If Tile.TileIndex>=TileCount Then Exit;
 If Tile.StartSBX>=Tile.EndSBX Then Exit;
 If Tile.StartSBY>=Tile.EndSBY Then Exit;
 If(Tile.Width=0)or(Tile.Height=0)Then Exit;
 If(TileConfig.TileSizeBytesMinus1>3)Then Exit;
 If TileConfig.ContextUpdateTileId>=TileCount Then Exit;
 ValidateTileGroupConfig:=True;
End;

Function EncodeTileGroupHeader(Const TileConfig:TAV1TileConfig;
 Const Tile:TAV1Tile;Var Payload:TAV1ByteBuffer):Boolean;
Var
 Writer:TBitWriter;
 StartAndEndPresent:Boolean;
 Bits:Byte;
Begin
 EncodeTileGroupHeader:=False;
 If not ValidateTileGroupConfig(TileConfig,Tile)Then Exit;
 If not AllocateAV1ByteBuffer(Payload,AV1MaxOBUBytes)Then Exit;
 If(TileConfig.TileCols=1)and(TileConfig.TileRows=1)and
  (Tile.TileIndex=0)Then Begin
  EncodeTileGroupHeader:=True;
  Exit;
 End;
 StartAndEndPresent:=(TileConfig.TileCols<>1)or(TileConfig.TileRows<>1)or
  (Tile.TileIndex<>0);
 InitBitWriter(Writer,Payload);
 If StartAndEndPresent Then WriteBit(Writer,1)
                       Else WriteBit(Writer,0);
 Bits:=TileCountBits(TileConfig);
 If Bits=0 Then Bits:=1;
 If StartAndEndPresent Then Begin
  WriteBits(Writer,Tile.TileIndex,Bits);
  WriteBits(Writer,Tile.TileIndex,Bits);
 End;
 AddTrailingBits(Writer);
 If Writer.Failed Then Begin
  FreeAV1ByteBuffer(Payload);
  Exit;
 End;
 EncodeTileGroupHeader:=True;
End;

Procedure InitNormativeTilePlan(Var Plan:TAV1NormativeTilePlan);
Begin
 FillChar(Plan,SizeOf(Plan),0);
 Plan.RasterOrder:=True;
 Plan.Valid:=False;
End;

Function BuildNormativeTilePlan(Const Image:TAVIFImage;
 Const Grid:TAV1SuperBlockGrid;Const Tile:TAV1Tile;
 Var Plan:TAV1NormativeTilePlan):Boolean;
Begin
 BuildNormativeTilePlan:=False;
 InitNormativeTilePlan(Plan);
 If not ValidateTile(Grid,Tile)Then Exit;
 If(Tile.StartSBX>=Tile.EndSBX)or(Tile.StartSBY>=Tile.EndSBY)Then Exit;
 If(Image.PlaneY.Data=Nil)or(Image.PlaneY.Width=0)or(Image.PlaneY.Height=0)Then Exit;
 Plan.TileIndex:=Tile.TileIndex;
 Plan.StartSBX:=Tile.StartSBX;
 Plan.EndSBX:=Tile.EndSBX;
 Plan.StartSBY:=Tile.StartSBY;
 Plan.EndSBY:=Tile.EndSBY;
 Plan.SBCols:=Tile.EndSBX-Tile.StartSBX;
 Plan.SBRows:=Tile.EndSBY-Tile.StartSBY;
 Plan.TotalSuperBlocks:=LongInt(Plan.SBCols)*LongInt(Plan.SBRows);
 Plan.LumaWidth:=Tile.Width;
 Plan.LumaHeight:=Tile.Height;
 Plan.UsesChroma:=Image.ChromaFormat<>acfYUV444;
 If Image.ChromaFormat=acfYUV420 Then Begin
  Plan.ChromaWidth:=(Tile.Width+1)div 2;
  Plan.ChromaHeight:=(Tile.Height+1)div 2;
 End
  Else
 Begin
  Plan.ChromaWidth:=Tile.Width;
  Plan.ChromaHeight:=Tile.Height;
 End;
 If(Plan.TotalSuperBlocks<=0)or(Plan.LumaWidth=0)or(Plan.LumaHeight=0)Then Exit;
 If(Plan.ChromaWidth=0)or(Plan.ChromaHeight=0)Then Exit;
 If LongInt(Plan.LumaWidth)>Image.PlaneY.Width Then Exit;
 If LongInt(Plan.LumaHeight)>Image.PlaneY.Height Then Exit;
 If Image.PlaneU.Data<>Nil Then
  If(LongInt(Plan.ChromaWidth)>Image.PlaneU.Width)or
    (LongInt(Plan.ChromaHeight)>Image.PlaneU.Height)Then Exit;
 If Image.PlaneV.Data<>Nil Then
  If(LongInt(Plan.ChromaWidth)>Image.PlaneV.Width)or
    (LongInt(Plan.ChromaHeight)>Image.PlaneV.Height)Then Exit;
 Plan.Valid:=True;
 BuildNormativeTilePlan:=True;
End;

Function ValidateNormativeTilePlan(Const Plan:TAV1NormativeTilePlan):Boolean;
Begin
 ValidateNormativeTilePlan:=Plan.Valid and Plan.RasterOrder and
  (Plan.TotalSuperBlocks=LongInt(Plan.SBCols)*LongInt(Plan.SBRows))and
  (Plan.LumaWidth>0)and(Plan.LumaHeight>0)and
  (Plan.ChromaWidth>0)and(Plan.ChromaHeight>0);
End;

Procedure InitPartitionMap(Var Map:TAV1PartitionMap);
Begin
 Map.Nodes:=Nil;
 Map.Count:=0;
 Map.Capacity:=0;
 Map.SplitCount:=0;
 Map.LeafCount:=0;
End;

Function AllocatePartitionMap(Var Map:TAV1PartitionMap;Capacity:Word):Boolean;
Begin
 AllocatePartitionMap:=False;
 InitPartitionMap(Map);
 If(Capacity=0)or(Capacity>AV1MaxPartitionNodes)Then Exit;
 GetMem(Map.Nodes,LongInt(Capacity)*SizeOf(TAV1PartitionNode));
 If Map.Nodes=Nil Then Exit;
 Map.Capacity:=Capacity;
 AllocatePartitionMap:=True;
End;

Procedure FreePartitionMap(Var Map:TAV1PartitionMap);
Begin
 If Map.Nodes<>Nil Then
  FreeMem(Map.Nodes,LongInt(Map.Capacity)*SizeOf(TAV1PartitionNode));
 InitPartitionMap(Map);
End;

Function AddPartitionNode(Var Map:TAV1PartitionMap;X,Y:Word;Size:Byte;
 Partition:TAV1PartitionType;IsLeaf:Boolean):Boolean;
Begin
 AddPartitionNode:=False;
 If(Map.Nodes=Nil)or(Map.Count>=Map.Capacity)Then Exit;
 Map.Nodes^[Map.Count].X:=X;
 Map.Nodes^[Map.Count].Y:=Y;
 Map.Nodes^[Map.Count].Size:=Size;
 Map.Nodes^[Map.Count].Partition:=Partition;
 Map.Nodes^[Map.Count].IsLeaf:=IsLeaf;
 If Partition=aptSplit Then Inc(Map.SplitCount);
 If IsLeaf Then Inc(Map.LeafCount);
 Inc(Map.Count);
 AddPartitionNode:=True;
End;

Function EstimateNormativePartitionCapacity(Const Plan:TAV1NormativeTilePlan):Word;
Var
 Total:LongInt;
Begin
 Total:=Plan.TotalSuperBlocks*85; {64 + 4*32 + 16*16 + 64 feuilles 8x8}
 If Total>AV1MaxPartitionNodes Then Total:=AV1MaxPartitionNodes;
 EstimateNormativePartitionCapacity:=Word(Total);
End;

Function AddSplitTree8x8(Var Map:TAV1PartitionMap;X,Y:Word;Size:Byte):Boolean;
Var
 Half:Byte;
Begin
 AddSplitTree8x8:=False;
 If Size=AV1IntraBlockSize Then Begin
  If not AddPartitionNode(Map,X,Y,Size,aptNone,True)Then Exit;
  AddSplitTree8x8:=True;
  Exit;
 End;
 If Size<AV1IntraBlockSize Then Exit;
 Half:=Size div 2;
 If not AddPartitionNode(Map,X,Y,Size,aptSplit,False)Then Exit;
 If not AddSplitTree8x8(Map,X,Y,Half)Then Exit;
 If not AddSplitTree8x8(Map,X+Half,Y,Half)Then Exit;
 If not AddSplitTree8x8(Map,X,Y+Half,Half)Then Exit;
 If not AddSplitTree8x8(Map,X+Half,Y+Half,Half)Then Exit;
 AddSplitTree8x8:=True;
End;

Function BuildNormativePartitionMap(Const Plan:TAV1NormativeTilePlan;
 Var Map:TAV1PartitionMap):Boolean;
Var
 SBX,SBY:Word;
 PixelX,PixelY:Word;
 Capacity:Word;
Begin
 BuildNormativePartitionMap:=False;
 InitPartitionMap(Map);
 If not ValidateNormativeTilePlan(Plan)Then Exit;
 Capacity:=EstimateNormativePartitionCapacity(Plan);
 If not AllocatePartitionMap(Map,Capacity)Then Exit;
 For SBY:=Plan.StartSBY to Plan.EndSBY-1 Do
  For SBX:=Plan.StartSBX to Plan.EndSBX-1 Do Begin
   PixelX:=Word(LongInt(SBX-Plan.StartSBX)*AV1SuperBlockSize);
   PixelY:=Word(LongInt(SBY-Plan.StartSBY)*AV1SuperBlockSize);
   If not AddSplitTree8x8(Map,PixelX,PixelY,AV1SuperBlockSize)Then Begin
    FreePartitionMap(Map);
    Exit;
   End;
  End;
 BuildNormativePartitionMap:=True;
End;

Function ValidateNormativePartitionMap(Const Plan:TAV1NormativeTilePlan;
 Const Map:TAV1PartitionMap):Boolean;
Var
 I:Word;
 Node:TAV1PartitionNode;
 ExpectedLeaves,ExpectedSplits:LongInt;
Begin
 ValidateNormativePartitionMap:=False;
 If(Map.Nodes=Nil)or(Map.Count=0)Then Exit;
 ExpectedLeaves:=Plan.TotalSuperBlocks*64;
 ExpectedSplits:=Plan.TotalSuperBlocks*21;
 If Map.LeafCount<>ExpectedLeaves Then Exit;
 If Map.SplitCount<>ExpectedSplits Then Exit;
 If Map.Count<>ExpectedLeaves+ExpectedSplits Then Exit;
 For I:=0 to Map.Count-1 Do Begin
  Node:=Map.Nodes^[I];
  If(Node.Size<>8)and(Node.Size<>16)and(Node.Size<>32)and(Node.Size<>64)Then Exit;
  If LongInt(Node.X)+Node.Size>Plan.LumaWidth Then
   If LongInt(Node.X)+Node.Size>LongInt(Plan.SBCols)*AV1SuperBlockSize Then Exit;
  If LongInt(Node.Y)+Node.Size>Plan.LumaHeight Then
   If LongInt(Node.Y)+Node.Size>LongInt(Plan.SBRows)*AV1SuperBlockSize Then Exit;
  If Node.IsLeaf<>(Node.Partition=aptNone)Then Exit;
 End;
 ValidateNormativePartitionMap:=True;
End;

Procedure InitIntraModeMap(Var Map:TAV1IntraModeMap);
Begin
 Map.Nodes:=Nil;
 Map.Count:=0;
 Map.Capacity:=0;
 Map.DCCount:=0;
 Map.DirectionalCount:=0;
End;

Function AllocateIntraModeMap(Var Map:TAV1IntraModeMap;Capacity:Word):Boolean;
Begin
 AllocateIntraModeMap:=False;
 InitIntraModeMap(Map);
 If(Capacity=0)or(Capacity>AV1MaxNormativeModeBlocks)Then Exit;
 GetMem(Map.Nodes,LongInt(Capacity)*SizeOf(TAV1IntraModeNode));
 If Map.Nodes=Nil Then Exit;
 Map.Capacity:=Capacity;
 AllocateIntraModeMap:=True;
End;

Procedure FreeIntraModeMap(Var Map:TAV1IntraModeMap);
Begin
 If Map.Nodes<>Nil Then
  FreeMem(Map.Nodes,LongInt(Map.Capacity)*SizeOf(TAV1IntraModeNode));
 InitIntraModeMap(Map);
End;

Function AddIntraModeNode(Var Map:TAV1IntraModeMap;X,Y:Word;Size:Byte;
 Mode,UVMode:TIntraMode;Const Syntax:TBlockSyntaxInfo):Boolean;
Begin
 AddIntraModeNode:=False;
 If(Map.Nodes=Nil)or(Map.Count>=Map.Capacity)Then Exit;
 Map.Nodes^[Map.Count].X:=X;
 Map.Nodes^[Map.Count].Y:=Y;
 Map.Nodes^[Map.Count].Size:=Size;
 Map.Nodes^[Map.Count].Mode:=Mode;
 Map.Nodes^[Map.Count].UVMode:=UVMode;
 Map.Nodes^[Map.Count].SegmentId:=Syntax.SegmentId;
 Map.Nodes^[Map.Count].Skip:=Syntax.Skip;
 Map.Nodes^[Map.Count].TxSize:=Syntax.TxSize;
 Map.Nodes^[Map.Count].TxType:=Syntax.TxType;
 Map.Nodes^[Map.Count].QuantizerIndex:=Syntax.QuantizerIndex;
 If Mode=imDC Then Inc(Map.DCCount)Else Inc(Map.DirectionalCount);
 Inc(Map.Count);
 AddIntraModeNode:=True;
End;

Function BuildNormativeIntraModeMap(Const Image:TAVIFImage;
 Const Partitions:TAV1PartitionMap;Var Map:TAV1IntraModeMap):Boolean;
Var
 I:Word;
 Node:TAV1PartitionNode;
 Context:TBlockContext;
 Pred:TAV1ByteBlock;
 Residual:TAV1ResidualBlock;
 Decision:TModeDecisionResult;
 Syntax:TBlockSyntaxInfo;
 QuantConfig:TQuantConfig;
 SegConfig:TSegmentationConfig;
 Mode:TIntraMode;
 Lambda:LongInt;
Begin
 BuildNormativeIntraModeMap:=False;
 InitIntraModeMap(Map);
 If(Partitions.Nodes=Nil)or(Partitions.LeafCount=0)Then Exit;
 If not AllocateIntraModeMap(Map,Partitions.LeafCount)Then Exit;
 InitQuantConfig(QuantConfig);
 InitSegmentationConfig(SegConfig);
 Lambda:=InitialLambdaFromQ(96);
 For I:=0 to Partitions.Count-1 Do Begin
  Node:=Partitions.Nodes^[I];
  If not Node.IsLeaf Then Continue;
  If(Node.Size<>AV1IntraBlockSize)Then Begin
   FreeIntraModeMap(Map);
   Exit;
  End;
  InitBlockContext(0,Node.X,Node.Y,Node.Size,Node.Size,Context);
  Mode:=ChooseBestIntraMode(Image.PlaneY,Context,Lambda,
   AVIFOptions.EnableDirectionalIntra,Pred,Residual,Decision);
  If(Mode<imDC)or(Mode>imPaeth)Then Begin
   FreeIntraModeMap(Map);
   Exit;
  End;
  BuildBlockSyntaxInfo(Decision,QuantConfig,SegConfig,Syntax);
  If not AddIntraModeNode(Map,Node.X,Node.Y,Node.Size,Mode,imDC,Syntax)Then Begin
   FreeIntraModeMap(Map);
   Exit;
  End;
 End;
 BuildNormativeIntraModeMap:=True;
End;

Function ValidateNormativeIntraModeMap(Const Partitions:TAV1PartitionMap;
 Const Map:TAV1IntraModeMap):Boolean;
Var
 I:Word;
 Node:TAV1IntraModeNode;
Begin
 ValidateNormativeIntraModeMap:=False;
 If(Map.Nodes=Nil)or(Map.Count=0)Then Exit;
 If Map.Count<>Partitions.LeafCount Then Exit;
 If(Map.DCCount+Map.DirectionalCount)<>Map.Count Then Exit;
 For I:=0 to Map.Count-1 Do Begin
  Node:=Map.Nodes^[I];
  If Node.Size<>AV1IntraBlockSize Then Exit;
  If(Node.Mode<imDC)or(Node.Mode>imPaeth)Then Exit;
  If(Node.UVMode<imDC)or(Node.UVMode>imPaeth)Then Exit;
  If(Node.TxSize<txSize4x4)or(Node.TxSize>txSize32x32)Then Exit;
  If(Node.TxType<txDCT_DCT)or(Node.TxType>txIdentity)Then Exit;
 End;
 ValidateNormativeIntraModeMap:=True;
End;

Function BuildRealAV1MinimalIntraModeMap(Const Partitions:TAV1PartitionMap;
 Var Map:TAV1IntraModeMap):Boolean;
Var
 I:Word;
 Node:TAV1PartitionNode;
 Syntax:TBlockSyntaxInfo;
Begin
 BuildRealAV1MinimalIntraModeMap:=False;
 InitIntraModeMap(Map);
 If(Partitions.Nodes=Nil)or(Partitions.LeafCount=0)Then Exit;
 If not AllocateIntraModeMap(Map,Partitions.LeafCount)Then Exit;
 FillChar(Syntax,SizeOf(Syntax),0);
 Syntax.Skip:=True;
 Syntax.SegmentId:=0;
 Syntax.TxSize:=txSize8x8;
 Syntax.TxType:=txDCT_DCT;
 Syntax.IntraMode:=imDC;
 Syntax.QuantizerIndex:=96;
 Syntax.EOB:=0;
 For I:=0 to Partitions.Count-1 Do Begin
  Node:=Partitions.Nodes^[I];
  If not Node.IsLeaf Then Continue;
  If Node.Size<>AV1IntraBlockSize Then Begin
   FreeIntraModeMap(Map);
   Exit;
  End;
  If not AddIntraModeNode(Map,Node.X,Node.Y,Node.Size,imDC,imDC,
   Syntax)Then Begin
   FreeIntraModeMap(Map);
   Exit;
  End;
 End;
 BuildRealAV1MinimalIntraModeMap:=True;
End;

Procedure InitTransformTreeMap(Var Map:TAV1TransformTreeMap);
Begin
 Map.Nodes:=Nil;
 Map.Count:=0;
 Map.Capacity:=0;
 Map.SplitCount:=0;
 Map.LeafCount:=0;
End;

Function AllocateTransformTreeMap(Var Map:TAV1TransformTreeMap;Capacity:Word):Boolean;
Begin
 AllocateTransformTreeMap:=False;
 InitTransformTreeMap(Map);
 If(Capacity=0)or(Capacity>AV1MaxNormativeTransformUnits)Then Exit;
 GetMem(Map.Nodes,LongInt(Capacity)*SizeOf(TAV1TransformTreeNode));
 If Map.Nodes=Nil Then Exit;
 Map.Capacity:=Capacity;
 AllocateTransformTreeMap:=True;
End;

Procedure FreeTransformTreeMap(Var Map:TAV1TransformTreeMap);
Begin
 If Map.Nodes<>Nil Then
  FreeMem(Map.Nodes,LongInt(Map.Capacity)*SizeOf(TAV1TransformTreeNode));
 InitTransformTreeMap(Map);
End;

Function AddTransformTreeNode(Var Map:TAV1TransformTreeMap;X,Y:Word;
 Width,Height:Byte;TxSize:TTransformSize;TxType:TTransformType;
 Split:Boolean):Boolean;
Begin
 AddTransformTreeNode:=False;
 If(Map.Nodes=Nil)or(Map.Count>=Map.Capacity)Then Exit;
 Map.Nodes^[Map.Count].X:=X;
 Map.Nodes^[Map.Count].Y:=Y;
 Map.Nodes^[Map.Count].Width:=Width;
 Map.Nodes^[Map.Count].Height:=Height;
 Map.Nodes^[Map.Count].TxSize:=TxSize;
 Map.Nodes^[Map.Count].TxType:=TxType;
 Map.Nodes^[Map.Count].Split:=Split;
 If Split Then Inc(Map.SplitCount)Else Inc(Map.LeafCount);
 Inc(Map.Count);
 AddTransformTreeNode:=True;
End;

Function BuildNormativeTransformTreeMap(Const Modes:TAV1IntraModeMap;
 Var Map:TAV1TransformTreeMap):Boolean;
Var
 I:Word;
 ModeNode:TAV1IntraModeNode;
Begin
 BuildNormativeTransformTreeMap:=False;
 InitTransformTreeMap(Map);
 If(Modes.Nodes=Nil)or(Modes.Count=0)Then Exit;
 If not AllocateTransformTreeMap(Map,Modes.Count)Then Exit;
 For I:=0 to Modes.Count-1 Do Begin
  ModeNode:=Modes.Nodes^[I];
  If not AddTransformTreeNode(Map,ModeNode.X,ModeNode.Y,ModeNode.Size,
   ModeNode.Size,ModeNode.TxSize,ModeNode.TxType,False)Then Begin
   FreeTransformTreeMap(Map);
   Exit;
  End;
 End;
 BuildNormativeTransformTreeMap:=True;
End;

Function ValidateNormativeTransformTreeMap(Const Modes:TAV1IntraModeMap;
 Const Map:TAV1TransformTreeMap):Boolean;
Var
 I:Word;
 Node:TAV1TransformTreeNode;
 ModeNode:TAV1IntraModeNode;
Begin
 ValidateNormativeTransformTreeMap:=False;
 If(Map.Nodes=Nil)or(Map.Count=0)Then Exit;
 If Map.Count<>Modes.Count Then Exit;
 If Map.LeafCount<>Map.Count Then Exit;
 If Map.SplitCount<>0 Then Exit;
 For I:=0 to Map.Count-1 Do Begin
  Node:=Map.Nodes^[I];
  ModeNode:=Modes.Nodes^[I];
  If Node.Split Then Exit;
  If(Node.X<>ModeNode.X)or(Node.Y<>ModeNode.Y)Then Exit;
  If(Node.Width<>ModeNode.Size)or(Node.Height<>ModeNode.Size)Then Exit;
  If(Node.TxSize<>ModeNode.TxSize)or(Node.TxType<>ModeNode.TxType)Then Exit;
  If(Node.TxSize<txSize4x4)or(Node.TxSize>txSize32x32)Then Exit;
  If(Node.TxType<txDCT_DCT)or(Node.TxType>txIdentity)Then Exit;
 End;
 ValidateNormativeTransformTreeMap:=True;
End;

Function BuildRealAV1MinimalTransformTreeMap(Const Modes:TAV1IntraModeMap;
 Var Map:TAV1TransformTreeMap):Boolean;
Var
 I:Word;
 ModeNode:TAV1IntraModeNode;
Begin
 BuildRealAV1MinimalTransformTreeMap:=False;
 InitTransformTreeMap(Map);
 If(Modes.Nodes=Nil)or(Modes.Count=0)Then Exit;
 If not AllocateTransformTreeMap(Map,Modes.Count)Then Exit;
 For I:=0 to Modes.Count-1 Do Begin
  ModeNode:=Modes.Nodes^[I];
  If(ModeNode.Mode<>imDC)or(not ModeNode.Skip)Then Begin
   FreeTransformTreeMap(Map);
   Exit;
  End;
  If not AddTransformTreeNode(Map,ModeNode.X,ModeNode.Y,ModeNode.Size,
   ModeNode.Size,txSize8x8,txDCT_DCT,False)Then Begin
   FreeTransformTreeMap(Map);
   Exit;
  End;
 End;
 BuildRealAV1MinimalTransformTreeMap:=True;
End;

Procedure InitCoefficientUnitMap(Var Map:TAV1CoefficientUnitMap);
Begin
 Map.Units:=Nil;
 Map.Count:=0;
 Map.Capacity:=0;
 Map.NonZeroCount:=0;
 Map.ZeroCount:=0;
End;

Function AllocateCoefficientUnitMap(Var Map:TAV1CoefficientUnitMap;Capacity:Word):Boolean;
Begin
 AllocateCoefficientUnitMap:=False;
 InitCoefficientUnitMap(Map);
 If(Capacity=0)or(Capacity>AV1MaxNormativeCoeffUnits)Then Exit;
 GetMem(Map.Units,LongInt(Capacity)*SizeOf(TAV1CoefficientUnit));
 If Map.Units=Nil Then Exit;
 Map.Capacity:=Capacity;
 AllocateCoefficientUnitMap:=True;
End;

Procedure FreeCoefficientUnitMap(Var Map:TAV1CoefficientUnitMap);
Begin
 If Map.Units<>Nil Then
  FreeMem(Map.Units,LongInt(Map.Capacity)*SizeOf(TAV1CoefficientUnit));
 InitCoefficientUnitMap(Map);
End;

Function AddCoefficientUnit(Var Map:TAV1CoefficientUnitMap;X,Y:Word;
 PlaneID:Byte;TxSize:TTransformSize;TxType:TTransformType;EOB:Word;
 Energy:LongInt;SymbolStart,SymbolCount:Word):Boolean;
Begin
 AddCoefficientUnit:=False;
 If(Map.Units=Nil)or(Map.Count>=Map.Capacity)Then Exit;
 Map.Units^[Map.Count].X:=X;
 Map.Units^[Map.Count].Y:=Y;
 Map.Units^[Map.Count].PlaneID:=PlaneID;
 Map.Units^[Map.Count].TxSize:=TxSize;
 Map.Units^[Map.Count].TxType:=TxType;
 Map.Units^[Map.Count].EOB:=EOB;
 Map.Units^[Map.Count].TransformEnergy:=Energy;
 Map.Units^[Map.Count].SymbolStart:=SymbolStart;
 Map.Units^[Map.Count].SymbolCount:=SymbolCount;
 Map.Units^[Map.Count].HasNonZero:=EOB>0;
 If EOB>0 Then Inc(Map.NonZeroCount)Else Inc(Map.ZeroCount);
 Inc(Map.Count);
 AddCoefficientUnit:=True;
End;

Function EOBClassSymbol(EOB:LongInt):Byte;Forward;

Function AddCoeffSymbolsFromQuantBlock(Const QCoeffs:TQuantBlock;
 Const Context:TCoeffCodingContext;Var Symbols:TCoeffSymbolMap):Boolean;
Var
 Pos:Word;
 X,YPos:Byte;
 Level,BaseSymbol,ExtraValue,ExtraSymbol:Word;
Begin
 AddCoeffSymbolsFromQuantBlock:=False;
 If not AddCoeffSymbol(Symbols,cskEOB,GetEOBContext(Context),0,
  EOBClassSymbol(Context.EOB))Then Exit;
 If Context.EOB=0 Then Begin
  AddCoeffSymbolsFromQuantBlock:=True;
  Exit;
 End;
 For Pos:=0 to Context.EOB-1 Do Begin
  If not ScanIndexToXY(Pos,Context.TxSize,X,YPos)Then Exit;
  Level:=AbsSmallInt(QCoeffs[X,YPos]);
  If Level>2 Then BaseSymbol:=3 Else BaseSymbol:=Level;
  If not AddCoeffSymbol(Symbols,cskCoeffBase,GetCoeffBaseContext(Context,Pos),
   Pos,SmallInt(BaseSymbol))Then Exit;
  If Level>0 Then Begin
   If not AddCoeffSymbol(Symbols,cskCoeffSign,0,Pos,
    SmallInt(Ord(QCoeffs[X,YPos]<0)))Then Exit;
   If Level>2 Then Begin
    ExtraValue:=Level-3;
    Repeat
     If ExtraValue>15 Then ExtraSymbol:=15 Else ExtraSymbol:=ExtraValue;
     If not AddCoeffSymbol(Symbols,cskCoeffExtra,
      GetCoeffBrContext(Context,Pos,Level),Pos,SmallInt(ExtraSymbol))Then Exit;
     If ExtraValue>15 Then Dec(ExtraValue,15)Else ExtraValue:=0;
    Until ExtraValue=0;
   End;
  End;
 End;
 AddCoeffSymbolsFromQuantBlock:=True;
End;

Function BuildRealAV1MinimalCoefficientMap(Const TransformTree:TAV1TransformTreeMap;
 Var Units:TAV1CoefficientUnitMap;Var Symbols:TCoeffSymbolMap):Boolean;
Var
 I:Word;
 TxNode:TAV1TransformTreeNode;
Begin
 BuildRealAV1MinimalCoefficientMap:=False;
 InitCoefficientUnitMap(Units);
 InitCoeffSymbolMap(Symbols);
 If(TransformTree.Nodes=Nil)or(TransformTree.Count=0)Then Exit;
 If not AllocateCoefficientUnitMap(Units,TransformTree.Count)Then Exit;
 If not AllocateCoeffSymbolMap(Symbols,1)Then Begin
  FreeCoefficientUnitMap(Units);
  Exit;
 End;
 For I:=0 to TransformTree.Count-1 Do Begin
  TxNode:=TransformTree.Nodes^[I];
  If(TxNode.TxType<>txDCT_DCT)or(TxNode.Split)Then Begin
   FreeCoeffSymbolMap(Symbols);
   FreeCoefficientUnitMap(Units);
   Exit;
  End;
  If not AddCoefficientUnit(Units,TxNode.X,TxNode.Y,0,TxNode.TxSize,
   TxNode.TxType,0,0,0,0)Then Begin
   FreeCoeffSymbolMap(Symbols);
   FreeCoefficientUnitMap(Units);
   Exit;
  End;
 End;
 BuildRealAV1MinimalCoefficientMap:=True;
End;

Function BuildNormativeCoefficientMap(Const Image:TAVIFImage;
 Const Modes:TAV1IntraModeMap;Const TransformTree:TAV1TransformTreeMap;
 Var Units:TAV1CoefficientUnitMap;Var Symbols:TCoeffSymbolMap):Boolean;
Var
 I:Word;
 ModeNode:TAV1IntraModeNode;
 TxNode:TAV1TransformTreeNode;
 Context:TBlockContext;
 Pred:TAV1ByteBlock;
 Residual:TAV1ResidualBlock;
 Coeffs:TTransformBlock;
 QCoeffs:TQuantBlock;
 QuantConfig:TQuantConfig;
 CoeffContext:TCoeffCodingContext;
 EOB:Word;
 Energy:LongInt;
 SymbolStart,SymbolCount:Word;
Begin
 BuildNormativeCoefficientMap:=False;
 InitCoefficientUnitMap(Units);
 InitCoeffSymbolMap(Symbols);
 If(Modes.Count=0)or(TransformTree.Count<>Modes.Count)Then Exit;
 If not AllocateCoefficientUnitMap(Units,TransformTree.Count)Then Exit;
 If not AllocateCoeffSymbolMap(Symbols,AV1MaxCoeffSymbols)Then Begin
  FreeCoefficientUnitMap(Units);
  Exit;
 End;
 InitQuantConfig(QuantConfig);
 For I:=0 to TransformTree.Count-1 Do Begin
  ModeNode:=Modes.Nodes^[I];
  TxNode:=TransformTree.Nodes^[I];
  InitBlockContext(0,TxNode.X,TxNode.Y,TxNode.Width,TxNode.Height,Context);
  PredictBlock(ModeNode.Mode,Context,Image.PlaneY,Pred);
  ComputeResidual(Image.PlaneY,Context,Pred,Residual);
  ForwardTransform(Residual,TxNode.TxType,TxNode.TxSize,Coeffs);
  QuantizeBlock(Coeffs,TxNode.TxSize,0,QuantConfig,QCoeffs,EOB);
  Energy:=TransformEnergy(Coeffs,TxNode.TxSize);
  CoeffContext.Plane:=0;
  CoeffContext.TxSize:=TxNode.TxSize;
  CoeffContext.TxType:=TxNode.TxType;
  CoeffContext.EOB:=EOB;
  CoeffContext.ScanOrder:=csoDiagonal;
  CoeffContext.IsInter:=False;
  CoeffContext.AboveNonZero:=False;
  CoeffContext.LeftNonZero:=False;
  SymbolStart:=Symbols.Count;
  If not AddCoeffSymbolsFromQuantBlock(QCoeffs,CoeffContext,Symbols)Then Begin
   FreeCoeffSymbolMap(Symbols);
   FreeCoefficientUnitMap(Units);
   Exit;
  End;
  SymbolCount:=Symbols.Count-SymbolStart;
  If not AddCoefficientUnit(Units,TxNode.X,TxNode.Y,0,TxNode.TxSize,
   TxNode.TxType,EOB,Energy,SymbolStart,SymbolCount)Then Begin
   FreeCoeffSymbolMap(Symbols);
   FreeCoefficientUnitMap(Units);
   Exit;
  End;
 End;
 BuildNormativeCoefficientMap:=True;
End;

Function ValidateNormativeCoefficientMap(Const TransformTree:TAV1TransformTreeMap;
 Const Units:TAV1CoefficientUnitMap;Const Symbols:TCoeffSymbolMap):Boolean;
Var
 I:Word;
 UnitInfo:TAV1CoefficientUnit;
Begin
 ValidateNormativeCoefficientMap:=False;
 If(Units.Units=Nil)or(Units.Count=0)Then Exit;
 If Units.Count<>TransformTree.Count Then Exit;
 If(Units.NonZeroCount+Units.ZeroCount)<>Units.Count Then Exit;
 If Symbols.Symbols=Nil Then Exit;
 For I:=0 to Units.Count-1 Do Begin
  UnitInfo:=Units.Units^[I];
  If UnitInfo.PlaneID<>0 Then Exit;
  If(UnitInfo.TxSize<txSize4x4)or(UnitInfo.TxSize>txSize32x32)Then Exit;
  If(UnitInfo.TxType<txDCT_DCT)or(UnitInfo.TxType>txIdentity)Then Exit;
  If(UnitInfo.SymbolCount=0)and(UnitInfo.EOB<>0)Then Exit;
  If LongInt(UnitInfo.SymbolStart)+UnitInfo.SymbolCount>Symbols.Count Then Exit;
  If UnitInfo.HasNonZero<>(UnitInfo.EOB>0)Then Exit;
 End;
 ValidateNormativeCoefficientMap:=True;
End;

Procedure InitFixedCDF(Var Model:TEntropyCDF;SymbolCount:Byte;
 BiasNumerator:Word);
Var
 I:Byte;
 Total,Remaining,Step,Value:LongInt;
Begin
 If SymbolCount<2 Then SymbolCount:=2;
 If SymbolCount>16 Then SymbolCount:=16;
 If BiasNumerator<1 Then BiasNumerator:=1;
 If BiasNumerator>4 Then BiasNumerator:=4;
 Model.SymbolCount:=SymbolCount;
 Model.CDF[0]:=0;
 Total:=32768;
 Remaining:=Total;
 Value:=0;
 For I:=1 to SymbolCount-1 Do Begin
  Step:=(Remaining*BiasNumerator)div(LongInt(SymbolCount-I+1)*4);
  If Step<1 Then Step:=1;
  Value:=Value+Step;
  If Value>=Total Then Value:=Total-1;
  Model.CDF[I]:=Word(Value);
  Remaining:=Total-Value;
 End;
 Model.CDF[SymbolCount]:=32768;
End;

Procedure InitExplicitCDF(Var Model:TEntropyCDF;SymbolCount:Byte;
 V1,V2,V3,V4,V5,V6,V7,V8,V9,V10,V11,V12,V13,V14,V15:Word);
Var
 Values:Array[1..15]of Word;
 I:Byte;
 Last:Word;
Begin
 FillChar(Model,SizeOf(Model),0);
 If SymbolCount<2 Then SymbolCount:=2;
 If SymbolCount>16 Then SymbolCount:=16;
 Values[1]:=V1; Values[2]:=V2; Values[3]:=V3; Values[4]:=V4;
 Values[5]:=V5; Values[6]:=V6; Values[7]:=V7; Values[8]:=V8;
 Values[9]:=V9; Values[10]:=V10; Values[11]:=V11; Values[12]:=V12;
 Values[13]:=V13; Values[14]:=V14; Values[15]:=V15;
 Model.SymbolCount:=SymbolCount;
 Model.CDF[0]:=0;
 Last:=0;
 For I:=1 to SymbolCount-1 Do Begin
  If Values[I]<=Last Then
   Values[I]:=Last+1;
  If Values[I]>=32768 Then
   Values[I]:=32767;
  Model.CDF[I]:=Values[I];
  Last:=Model.CDF[I];
 End;
 Model.CDF[SymbolCount]:=32768;
End;

Procedure InitAV1NormativeCDFSet(Var CDFSet:TAV1NormativeCDFSet);
Var
 I:Byte;
Begin
 FillChar(CDFSet,SizeOf(CDFSet),0);
 InitExplicitCDF(CDFSet.PartitionCDF,4,
  22528,28672,31744,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.SkipCDF,2,
  24576,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.IntraModeCDF,13,
  8192,12288,16384,18432,20480,22528,24576,26624,
  28672,30208,31360,32256,0,0,0);
 InitExplicitCDF(CDFSet.UVModeCDF,13,
  12288,15360,18432,20480,22528,24576,26368,28160,
  29696,30976,31872,32448,0,0,0);
 InitExplicitCDF(CDFSet.TxSizeCDF,4,
  20480,28672,31744,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.TxTypeCDF,8,
  24576,28672,30720,31744,32256,32512,32640,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.TxSplitCDF,2,
  28672,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.EOBCDF,16,
  6144,10240,14336,18432,22016,25088,27648,29696,
  31104,31936,32384,32608,32704,32736,32760);
 InitExplicitCDF(CDFSet.CoeffBaseCDF,4,
  16384,26624,31520,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.CoeffExtraCDF,16,
  8192,14336,19456,23552,26624,28928,30592,31616,
  32192,32480,32608,32672,32720,32744,32760);
 InitExplicitCDF(CDFSet.CoeffSignCDF,2,
  16384,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 CDFSet.PartitionCDFByContext[0]:=CDFSet.PartitionCDF;
 InitExplicitCDF(CDFSet.PartitionCDFByContext[1],4,
  24576,29440,31968,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.PartitionCDFByContext[2],4,
  18432,26624,31232,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.PartitionCDFByContext[3],4,
  12288,22528,29696,0,0,0,0,0,0,0,0,0,0,0,0);
 CDFSet.SkipCDFByContext[0]:=CDFSet.SkipCDF;
 InitExplicitCDF(CDFSet.SkipCDFByContext[1],2,
  20480,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.SkipCDFByContext[2],2,
  16384,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 CDFSet.SkipCDFByContext[3]:=CDFSet.SkipCDFByContext[2];
 CDFSet.IntraModeCDFByContext[0]:=CDFSet.IntraModeCDF;
 InitExplicitCDF(CDFSet.IntraModeCDFByContext[1],13,
  12288,15360,18432,20480,22528,24576,26368,28160,
  29696,30976,31872,32448,0,0,0);
 InitExplicitCDF(CDFSet.IntraModeCDFByContext[2],13,
  6144,10240,14336,18432,22016,25088,27648,29696,
  31104,31936,32384,32608,0,0,0);
 CDFSet.IntraModeCDFByContext[3]:=CDFSet.IntraModeCDFByContext[2];
 CDFSet.UVModeCDFByContext[0]:=CDFSet.UVModeCDF;
 InitExplicitCDF(CDFSet.UVModeCDFByContext[1],13,
  8192,12288,16384,18432,20480,22528,24576,26624,
  28672,30208,31360,32256,0,0,0);
 InitExplicitCDF(CDFSet.UVModeCDFByContext[2],13,
  14336,17408,20224,22528,24576,26368,27904,29440,
  30720,31744,32320,32640,0,0,0);
 CDFSet.UVModeCDFByContext[3]:=CDFSet.UVModeCDFByContext[2];
 CDFSet.TxSizeCDFByContext[0]:=CDFSet.TxSizeCDF;
 InitExplicitCDF(CDFSet.TxSizeCDFByContext[1],4,
  16384,26624,31232,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.TxSizeCDFByContext[2],4,
  24576,30208,32256,0,0,0,0,0,0,0,0,0,0,0,0);
 CDFSet.TxSizeCDFByContext[3]:=CDFSet.TxSizeCDFByContext[2];
 CDFSet.TxTypeCDFByContext[0]:=CDFSet.TxTypeCDF;
 InitExplicitCDF(CDFSet.TxTypeCDFByContext[1],8,
  20480,26624,29696,31232,32000,32384,32640,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.TxTypeCDFByContext[2],8,
  28672,30720,31744,32256,32512,32640,32704,0,0,0,0,0,0,0,0);
 CDFSet.TxTypeCDFByContext[3]:=CDFSet.TxTypeCDFByContext[1];
 CDFSet.TxSplitCDFByContext[0]:=CDFSet.TxSplitCDF;
 InitExplicitCDF(CDFSet.TxSplitCDFByContext[1],2,
  24576,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.TxSplitCDFByContext[2],2,
  30720,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 CDFSet.TxSplitCDFByContext[3]:=CDFSet.TxSplitCDFByContext[2];
 For I:=0 to 3 Do Begin
  CDFSet.EOBCDFByContext[I]:=CDFSet.EOBCDF;
  CDFSet.CoeffExtraCDFByContext[I]:=CDFSet.CoeffExtraCDF;
  CDFSet.CoeffSignCDFByContext[I]:=CDFSet.CoeffSignCDF;
 End;
 InitExplicitCDF(CDFSet.EOBCDFByContext[1],16,
  8192,12288,16384,20224,23552,26368,28672,30464,
  31616,32256,32512,32640,32704,32736,32760);
 InitExplicitCDF(CDFSet.EOBCDFByContext[2],16,
  4096,8192,12288,16384,20480,24064,27136,29440,
  30976,31872,32384,32608,32704,32736,32760);
 For I:=0 to 7 Do CDFSet.CoeffBaseCDFByContext[I]:=CDFSet.CoeffBaseCDF;
 InitExplicitCDF(CDFSet.CoeffBaseCDFByContext[1],4,
  20480,28672,32000,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.CoeffBaseCDFByContext[2],4,
  12288,24576,30720,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(CDFSet.CoeffBaseCDFByContext[3],4,
  8192,20480,29696,0,0,0,0,0,0,0,0,0,0,0,0);
 CDFSet.CoeffBaseCDFByContext[4]:=CDFSet.CoeffBaseCDFByContext[1];
 CDFSet.CoeffBaseCDFByContext[5]:=CDFSet.CoeffBaseCDFByContext[2];
 CDFSet.CoeffBaseCDFByContext[6]:=CDFSet.CoeffBaseCDFByContext[3];
 CDFSet.CoeffBaseCDFByContext[7]:=CDFSet.CoeffBaseCDFByContext[3];
 CDFSet.Initialized:=True;
End;

Function ValidateCDF(Const Model:TEntropyCDF;ExpectedSymbols:Byte):Boolean;
Var
 I:Byte;
Begin
 ValidateCDF:=False;
 If(ExpectedSymbols<2)or(ExpectedSymbols>16)Then Exit;
 If Model.SymbolCount<>ExpectedSymbols Then Exit;
 If Model.CDF[0]<>0 Then Exit;
 If Model.CDF[Model.SymbolCount]<>32768 Then Exit;
 For I:=1 to Model.SymbolCount Do
  If Model.CDF[I]<=Model.CDF[I-1]Then Exit;
 ValidateCDF:=True;
End;

Function ValidateNormativeCDFSet(Const CDFSet:TAV1NormativeCDFSet):Boolean;
Var
 I:Byte;
Begin
 ValidateNormativeCDFSet:=False;
 If not CDFSet.Initialized Then Exit;
 If not ValidateCDF(CDFSet.PartitionCDF,4)Then Exit;
 If not ValidateCDF(CDFSet.SkipCDF,2)Then Exit;
 If not ValidateCDF(CDFSet.IntraModeCDF,13)Then Exit;
 If not ValidateCDF(CDFSet.UVModeCDF,13)Then Exit;
 If not ValidateCDF(CDFSet.TxSizeCDF,4)Then Exit;
 If not ValidateCDF(CDFSet.TxTypeCDF,8)Then Exit;
 If not ValidateCDF(CDFSet.TxSplitCDF,2)Then Exit;
 If not ValidateCDF(CDFSet.EOBCDF,16)Then Exit;
 If not ValidateCDF(CDFSet.CoeffBaseCDF,4)Then Exit;
 If not ValidateCDF(CDFSet.CoeffExtraCDF,16)Then Exit;
 If not ValidateCDF(CDFSet.CoeffSignCDF,2)Then Exit;
 For I:=0 to 3 Do Begin
  If not ValidateCDF(CDFSet.PartitionCDFByContext[I],4)Then Exit;
  If not ValidateCDF(CDFSet.SkipCDFByContext[I],2)Then Exit;
  If not ValidateCDF(CDFSet.IntraModeCDFByContext[I],13)Then Exit;
  If not ValidateCDF(CDFSet.UVModeCDFByContext[I],13)Then Exit;
  If not ValidateCDF(CDFSet.TxSizeCDFByContext[I],4)Then Exit;
  If not ValidateCDF(CDFSet.TxTypeCDFByContext[I],8)Then Exit;
  If not ValidateCDF(CDFSet.TxSplitCDFByContext[I],2)Then Exit;
  If not ValidateCDF(CDFSet.EOBCDFByContext[I],16)Then Exit;
  If not ValidateCDF(CDFSet.CoeffExtraCDFByContext[I],16)Then Exit;
  If not ValidateCDF(CDFSet.CoeffSignCDFByContext[I],2)Then Exit;
 End;
 For I:=0 to 7 Do
  If not ValidateCDF(CDFSet.CoeffBaseCDFByContext[I],4)Then Exit;
 ValidateNormativeCDFSet:=True;
End;

Function IntraModeSymbol(Mode:TIntraMode):Byte;
Begin
 IntraModeSymbol:=Ord(Mode);
 If IntraModeSymbol>12 Then IntraModeSymbol:=12;
End;

Function TxSizeSymbol(TxSize:TTransformSize):Byte;
Begin
 TxSizeSymbol:=Ord(TxSize);
 If TxSizeSymbol>3 Then TxSizeSymbol:=3;
End;

Function ClampCDFContext(Value,MaxValue:Byte):Byte;
Begin
 If Value>MaxValue Then ClampCDFContext:=MaxValue
                   Else ClampCDFContext:=Value;
End;

Function PartitionContextFromNode(Const Node:TAV1PartitionNode):Byte;
Begin
 Case Node.Size of
  0..8:PartitionContextFromNode:=0;
  9..16:PartitionContextFromNode:=1;
  17..32:PartitionContextFromNode:=2;
  Else PartitionContextFromNode:=3;
 End;
End;

Function HasModeNodeAt(Const Modes:TAV1IntraModeMap;X,Y:LongInt;
 Var Node:TAV1IntraModeNode):Boolean;
Var
 I:Word;
Begin
 HasModeNodeAt:=False;
 If(Modes.Nodes=Nil)or(X<0)or(Y<0)Then Exit;
 For I:=0 to Modes.Count-1 Do
  If(Modes.Nodes^[I].X=X)and(Modes.Nodes^[I].Y=Y)Then Begin
   Node:=Modes.Nodes^[I];
   HasModeNodeAt:=True;
   Exit;
  End;
End;

Function SkipContextForLeaf(Const Leaf:TAV1PartitionNode;
 Const Modes:TAV1IntraModeMap):Byte;
Var
 Above,Left:TAV1IntraModeNode;
 Ctx:Byte;
Begin
 Ctx:=0;
 If HasModeNodeAt(Modes,Leaf.X,LongInt(Leaf.Y)-Leaf.Size,Above)Then
  If Above.Skip Then Inc(Ctx);
 If HasModeNodeAt(Modes,LongInt(Leaf.X)-Leaf.Size,Leaf.Y,Left)Then
  If Left.Skip Then Inc(Ctx);
 SkipContextForLeaf:=ClampCDFContext(Ctx,AV1SkipContexts-1);
End;

Function IntraContextForLeaf(Const Leaf:TAV1PartitionNode):Byte;
Begin
 IntraContextForLeaf:=0;
 If Leaf.Y=0 Then Inc(IntraContextForLeaf);
 If Leaf.X=0 Then Inc(IntraContextForLeaf);
 If Leaf.Size>AV1IntraBlockSize Then Inc(IntraContextForLeaf);
 IntraContextForLeaf:=ClampCDFContext(IntraContextForLeaf,AV1ModeContexts-1);
End;

Function UVContextForMode(Const ModeNode:TAV1IntraModeNode):Byte;
Begin
 If ModeNode.Mode=imDC Then UVContextForMode:=0
 Else If ModeNode.Mode=imSmooth Then UVContextForMode:=1
 Else UVContextForMode:=2;
End;

Function TxContextForNode(Const TxNode:TAV1TransformTreeNode):Byte;
Begin
 TxContextForNode:=TxSizeSymbol(TxNode.TxSize);
 TxContextForNode:=ClampCDFContext(TxContextForNode,AV1TxSizeContexts-1);
End;

Function TxTypeContextForMode(Const ModeNode:TAV1IntraModeNode):Byte;
Begin
 If ModeNode.Mode=imDC Then TxTypeContextForMode:=0
 Else If(ModeNode.Mode=imVertical)or(ModeNode.Mode=imHorizontal)Then
  TxTypeContextForMode:=1
 Else If ModeNode.Mode=imSmooth Then TxTypeContextForMode:=2
 Else TxTypeContextForMode:=3;
End;

Function EOBContextForUnit(Const UnitInfo:TAV1CoefficientUnit):Byte;
Begin
 EOBContextForUnit:=TxSizeSymbol(UnitInfo.TxSize);
 EOBContextForUnit:=ClampCDFContext(EOBContextForUnit,AV1EOBContexts-1);
End;

Function CoeffBaseContextForSymbol(Const UnitInfo:TAV1CoefficientUnit;
 Const Symbol:TCoeffSymbol):Byte;
Var
 Ctx:Byte;
Begin
 Ctx:=Byte(Symbol.Position mod 4);
 If UnitInfo.EOB>16 Then Inc(Ctx,4);
 CoeffBaseContextForSymbol:=ClampCDFContext(Ctx,AV1CoeffBaseContexts-1);
End;

Function CoeffExtraContextForSymbol(Const Symbol:TCoeffSymbol):Byte;
Begin
 CoeffExtraContextForSymbol:=ClampCDFContext(Byte(Symbol.Position mod 4),
  AV1CoeffExtraContexts-1);
End;

Function HasNonZeroCoeffUnitAt(Const Units:TAV1CoefficientUnitMap;X,Y:LongInt;
 PlaneID:Byte):Boolean;
Var
 I:Word;
Begin
 HasNonZeroCoeffUnitAt:=False;
 If(Units.Units=Nil)or(X<0)or(Y<0)Then Exit;
 For I:=0 to Units.Count-1 Do
  If(Units.Units^[I].X=X)and(Units.Units^[I].Y=Y)and
    (Units.Units^[I].PlaneID=PlaneID)Then Begin
   HasNonZeroCoeffUnitAt:=Units.Units^[I].HasNonZero;
   Exit;
  End;
End;

Function AV1ModeFamily(Mode:TIntraMode):Byte;
Begin
 If Mode=imDC Then AV1ModeFamily:=0
 Else If(Mode=imVertical)or(Mode=imHorizontal)Then AV1ModeFamily:=1
 Else If(Mode=imSmooth)or(Mode=imSmoothV)or(Mode=imSmoothH)Then AV1ModeFamily:=2
 Else AV1ModeFamily:=3;
End;

Function AV1BuildSyntaxContext(Const Leaf:TAV1PartitionNode;
 Const ModeNode:TAV1IntraModeNode;Const TxNode:TAV1TransformTreeNode;
 Const UnitInfo:TAV1CoefficientUnit;Const Modes:TAV1IntraModeMap;
 Const CoeffUnits:TAV1CoefficientUnitMap):TAV1SyntaxContext;
Var
 Above,Left:TAV1IntraModeNode;
 Ctx:TAV1SyntaxContext;
 NeighborBias:Byte;
Begin
 FillChar(Ctx,SizeOf(Ctx),0);
 Ctx.BlockSize:=Leaf.Size;
 Ctx.PlaneID:=UnitInfo.PlaneID;
 Ctx.TxSize:=TxNode.TxSize;
 Ctx.TxType:=TxNode.TxType;
 Ctx.AboveAvailable:=HasModeNodeAt(Modes,Leaf.X,LongInt(Leaf.Y)-Leaf.Size,Above);
 Ctx.LeftAvailable:=HasModeNodeAt(Modes,LongInt(Leaf.X)-Leaf.Size,Leaf.Y,Left);
 If Ctx.AboveAvailable Then Ctx.AboveSkip:=Above.Skip;
 If Ctx.LeftAvailable Then Ctx.LeftSkip:=Left.Skip;
 Ctx.AboveNonZero:=HasNonZeroCoeffUnitAt(CoeffUnits,Leaf.X,
  LongInt(Leaf.Y)-Leaf.Size,UnitInfo.PlaneID);
 Ctx.LeftNonZero:=HasNonZeroCoeffUnitAt(CoeffUnits,
  LongInt(Leaf.X)-Leaf.Size,Leaf.Y,UnitInfo.PlaneID);
 Ctx.PartitionContext:=PartitionContextFromNode(Leaf);
 Ctx.SkipContext:=0;
 If Ctx.AboveAvailable and Ctx.AboveSkip Then Inc(Ctx.SkipContext);
 If Ctx.LeftAvailable and Ctx.LeftSkip Then Inc(Ctx.SkipContext);
 If(Leaf.Size>AV1IntraBlockSize)and(UnitInfo.EOB=0)Then Inc(Ctx.SkipContext);
 Ctx.SkipContext:=ClampCDFContext(Ctx.SkipContext,AV1SkipContexts-1);
 NeighborBias:=0;
 If not Ctx.AboveAvailable Then Inc(NeighborBias);
 If not Ctx.LeftAvailable Then Inc(NeighborBias);
 If Ctx.AboveAvailable Then Inc(NeighborBias,AV1ModeFamily(Above.Mode)and 1);
 If Ctx.LeftAvailable Then Inc(NeighborBias,AV1ModeFamily(Left.Mode)and 1);
 Ctx.YModeContext:=ClampCDFContext(NeighborBias,AV1ModeContexts-1);
 Ctx.UVModeContext:=ClampCDFContext(AV1ModeFamily(ModeNode.Mode),
  AV1UVModeContexts-1);
 Ctx.TxSizeContext:=ClampCDFContext(TxSizeSymbol(TxNode.TxSize)+
  Ord(Ctx.AboveNonZero or Ctx.LeftNonZero),AV1TxSizeContexts-1);
 Ctx.TxTypeContext:=ClampCDFContext(AV1ModeFamily(ModeNode.Mode)+
  Ord(Ctx.AboveNonZero and Ctx.LeftNonZero),AV1TxTypeContexts-1);
 Ctx.TxSplitContext:=ClampCDFContext(TxSizeSymbol(TxNode.TxSize)+
  Ord(Leaf.Size>AV1IntraBlockSize),AV1TxSplitContexts-1);
 Ctx.EOBContext:=ClampCDFContext(TxSizeSymbol(UnitInfo.TxSize)+
  Ord(Ctx.AboveNonZero)+Ord(Ctx.LeftNonZero),AV1EOBContexts-1);
 Ctx.CoeffBaseContext:=ClampCDFContext((TxSizeSymbol(UnitInfo.TxSize)*2)+
  Ord(UnitInfo.EOB>16)+Ord(Ctx.AboveNonZero or Ctx.LeftNonZero),
  AV1CoeffBaseContexts-1);
 Ctx.CoeffExtraContext:=ClampCDFContext(TxSizeSymbol(UnitInfo.TxSize)+
  Ord(UnitInfo.EOB>8),AV1CoeffExtraContexts-1);
 Ctx.CoeffSignContext:=ClampCDFContext(Ord(Ctx.AboveNonZero xor Ctx.LeftNonZero),
  AV1CoeffSignContexts-1);
 AV1BuildSyntaxContext:=Ctx;
End;

Function CoeffSymbolFitsCDF(Const Symbol:TCoeffSymbol;
 Const CDFSet:TAV1NormativeCDFSet):Boolean;
Var
 V:LongInt;
 Limit:Byte;
Begin
 CoeffSymbolFitsCDF:=False;
 V:=Symbol.Symbol;
 If V<0 Then V:=-V;
 Case Symbol.Kind of
  cskEOB:Begin
   CoeffSymbolFitsCDF:=V<=1024;
   Exit;
  End;
  cskCoeffBase:Limit:=CDFSet.CoeffBaseCDF.SymbolCount;
  cskCoeffExtra:Limit:=CDFSet.CoeffExtraCDF.SymbolCount;
  cskCoeffSign:Limit:=CDFSet.CoeffSignCDF.SymbolCount;
  Else Limit:=0;
 End;
 If Limit=0 Then Exit;
 CoeffSymbolFitsCDF:=V<Limit;
End;

Function ValidateSymbolsAgainstNormativeCDF(Const Partitions:TAV1PartitionMap;
 Const Modes:TAV1IntraModeMap;Const TransformTree:TAV1TransformTreeMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet):Boolean;
Var
 I:Word;
 ModeNode:TAV1IntraModeNode;
 TxNode:TAV1TransformTreeNode;
Begin
 ValidateSymbolsAgainstNormativeCDF:=False;
 If not ValidateNormativeCDFSet(CDFSet)Then Exit;
 If Partitions.Count=0 Then Exit;
 For I:=0 to Modes.Count-1 Do Begin
  ModeNode:=Modes.Nodes^[I];
  If IntraModeSymbol(ModeNode.Mode)>=CDFSet.IntraModeCDF.SymbolCount Then Exit;
  If IntraModeSymbol(ModeNode.UVMode)>=CDFSet.UVModeCDF.SymbolCount Then Exit;
 End;
 For I:=0 to TransformTree.Count-1 Do Begin
  TxNode:=TransformTree.Nodes^[I];
  If TxSizeSymbol(TxNode.TxSize)>=CDFSet.TxSizeCDF.SymbolCount Then Exit;
  If Ord(TxNode.TxType)>=CDFSet.TxTypeCDF.SymbolCount Then Exit;
 End;
 If CoeffSymbols.Symbols=Nil Then Exit;
 For I:=0 to CoeffSymbols.Count-1 Do
  If not CoeffSymbolFitsCDF(CoeffSymbols.Symbols^[I],CDFSet)Then Exit;
 ValidateSymbolsAgainstNormativeCDF:=True;
End;

Procedure InitNormativeRangeEncoder(Var Encoder:TAV1NormativeRangeEncoder;
 Var Buffer:TAV1ByteBuffer);
Begin
 Encoder.Low:=0;
 Encoder.Range:=$8000;
 Encoder.Count:=0;
 Encoder.Cnt:=-9;
 Encoder.SymbolCount:=0;
 Encoder.Buffer:=@Buffer;
 Encoder.StartSize:=Buffer.Size;
 Encoder.Finalized:=False;
 Encoder.Failed:=False;
End;

Function ValidateRangeEncoderCDF(Const Model:TEntropyCDF):Boolean;
Var
 I:Byte;
Begin
 ValidateRangeEncoderCDF:=False;
 If(Model.SymbolCount<2)or(Model.SymbolCount>16)Then Exit;
 If Model.CDF[0]<>0 Then Exit;
 If Model.CDF[Model.SymbolCount]<>32768 Then Exit;
 For I:=1 to Model.SymbolCount Do
  If Model.CDF[I]<=Model.CDF[I-1]Then Exit;
 ValidateRangeEncoderCDF:=True;
End;

Function NormativeRangeStateIsValid(Const Encoder:TAV1NormativeRangeEncoder):Boolean;
Begin
 NormativeRangeStateIsValid:=False;
 If Encoder.Failed Then Exit;
 If Encoder.Buffer=Nil Then Exit;
 If Encoder.Buffer^.Data=Nil Then Exit;
 If(Encoder.Range<$8000)or(Encoder.Range>$FFFF)Then Exit;
 If(Encoder.Cnt<-24)or(Encoder.Cnt>39)Then Exit;
 If Encoder.Low<0 Then Exit;
 NormativeRangeStateIsValid:=True;
End;

Function NormativeILogNZ(Value:LongInt):Byte;
Begin
 NormativeILogNZ:=0;
 While Value>0 Do Begin
  Inc(NormativeILogNZ);
  Value:=Value shr 1;
 End;
End;

Procedure NormativeRangePropagateCarry(Var Encoder:TAV1NormativeRangeEncoder);
Var
 Pos:LongInt;
 Sum:Word;
Begin
 If Encoder.Failed Then Exit;
 If(Encoder.Buffer=Nil)or(Encoder.Buffer^.Data=Nil)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 Pos:=Encoder.Buffer^.Size-1;
 If Pos<Encoder.StartSize Then Begin
  If not AV1BufferAppendByte(Encoder.Buffer^,1)Then
   Encoder.Failed:=True
  Else
   Inc(Encoder.Count);
  Exit;
 End;
 Repeat
  Sum:=Word(Encoder.Buffer^.Data^[Pos])+1;
  Encoder.Buffer^.Data^[Pos]:=Byte(Sum and $FF);
  If(Sum shr 8)=0 Then Break;
  Dec(Pos);
  If Pos<Encoder.StartSize Then Begin
   Encoder.Failed:=True;
   Exit;
  End;
 Until False;
End;

Procedure NormativeRangeEmitByte(Var Encoder:TAV1NormativeRangeEncoder;
 Value:Byte);
Begin
 If Encoder.Failed Then Exit;
 If Encoder.Finalized Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If Encoder.Buffer=Nil Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not AV1BufferAppendByte(Encoder.Buffer^,Value)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 Inc(Encoder.Count);
End;

Procedure NormativeRangeEmitReadyBytes(Var Encoder:TAV1NormativeRangeEncoder;
 Output,Carry:Int64;NumBytes:Byte);
Var
 Shift:ShortInt;
Begin
 If Encoder.Failed Then Exit;
 If NumBytes=0 Then Exit;
 If Carry<>0 Then NormativeRangePropagateCarry(Encoder);
 Shift:=ShortInt((NumBytes-1)*8);
 While Shift>=0 Do Begin
  NormativeRangeEmitByte(Encoder,Byte((Output shr Shift)and $FF));
  Dec(Shift,8);
 End;
End;

Procedure NormalizeNormativeRangeEncoder(Var Encoder:TAV1NormativeRangeEncoder);
Var
 D:Byte;
 C,S:LongInt;
 NumBytesReady:Byte;
 Output,Mask,Carry:Int64;
Begin
 If Encoder.Failed Then Exit;
 If Encoder.Finalized Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If(Encoder.Range<=0)or(Encoder.Range>$FFFF)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 D:=16-NormativeILogNZ(LongInt(Encoder.Range));
 S:=Encoder.Cnt+D;
 If S>=40 Then Begin
  NumBytesReady:=Byte(S shr 3);
  If NumBytesReady=0 Then NumBytesReady:=1;
  C:=Encoder.Cnt+24-(LongInt(NumBytesReady)shl 3);
  If(C<0)or(C>62)Then Begin
   Encoder.Failed:=True;
   Exit;
  End;
  Output:=Encoder.Low shr C;
  If C=0 Then Encoder.Low:=0
         Else Encoder.Low:=Encoder.Low and((Int64(1)shl C)-1);
  Mask:=Int64(1)shl(LongInt(NumBytesReady)shl 3);
  Carry:=Output and Mask;
  Output:=Output and(Mask-1);
  NormativeRangeEmitReadyBytes(Encoder,Output,Carry,NumBytesReady);
  S:=C+D-24;
 End;
 Encoder.Low:=Encoder.Low shl D;
 Encoder.Range:=Encoder.Range shl D;
 Encoder.Cnt:=S;
 If not NormativeRangeStateIsValid(Encoder)Then Encoder.Failed:=True;
End;

Function ClampSymbolToCDF(Symbol:LongInt;Const Model:TEntropyCDF):Byte;
Begin
 If Symbol<0 Then Symbol:=-Symbol;
 If Model.SymbolCount=0 Then ClampSymbolToCDF:=0
 Else If Symbol>=Model.SymbolCount Then
  ClampSymbolToCDF:=Model.SymbolCount-1
 Else
  ClampSymbolToCDF:=Byte(Symbol);
End;

Procedure EncodeNormativeCDFSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Symbol:Byte;Const Model:TEntropyCDF);
Var
 FL,FH:Int64;
 R,U,V:Int64;
 N:LongInt;
Begin
 If Encoder.Failed Then Exit;
 If Encoder.Finalized Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not ValidateRangeEncoderCDF(Model)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If Symbol>=Model.SymbolCount Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not NormativeRangeStateIsValid(Encoder)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 N:=Model.SymbolCount-1;
 If Symbol>0 Then FL:=32768-Model.CDF[Symbol]
             Else FL:=32768;
 FH:=32768-Model.CDF[Symbol+1];
 If(FH>FL)or(FL>32768)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 R:=Encoder.Range;
 If FL<32768 Then Begin
  U:=(((R shr 8)*(FL shr 6))shr 1)+4*(N-(LongInt(Symbol)-1));
  V:=(((R shr 8)*(FH shr 6))shr 1)+4*(N-LongInt(Symbol));
  Encoder.Low:=Encoder.Low+R-U;
  Encoder.Range:=U-V;
 End
  Else
  Encoder.Range:=R-((((R shr 8)*(FH shr 6))shr 1)+
   4*(N-LongInt(Symbol)));
 If(Encoder.Range<=0)or(Encoder.Range>$FFFF)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 Inc(Encoder.SymbolCount);
 NormalizeNormativeRangeEncoder(Encoder);
End;

Procedure FinishNormativeRangeEncoder(Var Encoder:TAV1NormativeRangeEncoder);
Var
 M,E,N:Int64;
 C,S:LongInt;
 Val:Word;
Begin
 If Encoder.Failed Then Exit;
 If Encoder.Finalized Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not NormativeRangeStateIsValid(Encoder)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 M:=$3FFF;
 E:=((Encoder.Low+M)and(not M))or(M+1);
 C:=Encoder.Cnt;
 S:=C+10;
 If S>0 Then Begin
  If(C+16<0)or(C+16>62)Then Begin
   Encoder.Failed:=True;
   Exit;
  End;
  N:=(Int64(1)shl(C+16))-1;
  Repeat
   Val:=Word((E shr(C+16))and $01FF);
   If(Val and $0100)<>0 Then NormativeRangePropagateCarry(Encoder);
   NormativeRangeEmitByte(Encoder,Byte(Val and $FF));
   E:=E and N;
   Dec(S,8);
   Dec(C,8);
   N:=N shr 8;
  Until(S<=0)or Encoder.Failed;
 End;
 If not Encoder.Failed Then Encoder.Finalized:=True;
End;

Function ValidateNormativeRangePayload(Const Encoder:TAV1NormativeRangeEncoder):Boolean;
Begin
 ValidateNormativeRangePayload:=False;
 If Encoder.Failed Then Exit;
 If not Encoder.Finalized Then Exit;
 If Encoder.Buffer=Nil Then Exit;
 If Encoder.Buffer^.Data=Nil Then Exit;
 If Encoder.Buffer^.Size<=Encoder.StartSize Then Exit;
 If Encoder.Count<1 Then Exit;
 If Encoder.SymbolCount<1 Then Exit;
 ValidateNormativeRangePayload:=True;
End;

Function EncodeNormativeRangeTestVector(Var Output:TAV1ByteBuffer):Boolean;
Var
 Encoder:TAV1NormativeRangeEncoder;
 Model:TEntropyCDF;
Begin
 EncodeNormativeRangeTestVector:=False;
 InitAV1ByteBuffer(Output);
 If not AllocateAV1ByteBuffer(Output,AV1MaxOBUBytes)Then Exit;
 InitExplicitCDF(Model,4,8192,16384,24576,0,0,0,0,0,0,0,0,0,0,0,0);
 InitNormativeRangeEncoder(Encoder,Output);
 EncodeNormativeCDFSymbol(Encoder,0,Model);
 EncodeNormativeCDFSymbol(Encoder,3,Model);
 EncodeNormativeCDFSymbol(Encoder,1,Model);
 EncodeNormativeCDFSymbol(Encoder,2,Model);
 FinishNormativeRangeEncoder(Encoder);
 EncodeNormativeRangeTestVector:=ValidateNormativeRangePayload(Encoder);
End;

{ ----- Decodeur AV1 normatif (od_ec_dec.c equivalent) -----
  Permet le self-test roundtrip : encoder N symboles puis verifier que
  le decodeur retrouve la meme sequence bit-a-bit. C'est la garantie
  minimale pour pouvoir construire ensuite la syntaxe de tuile AV1
  reelle (partition tree, modes intra, transformees, coefficients). }

Procedure NormativeRangeDecRefill(Var D:TAV1NormativeRangeDecoder);
Var
 S:LongInt;
 B:Byte;
Begin
 If D.Failed Then Exit;
 If D.Buffer=Nil Then Begin D.Failed:=True; Exit; End;
 If D.Buffer^.Data=Nil Then Begin D.Failed:=True; Exit; End;
 S:=8-D.Cnt;                          { 32 - 9 - (cnt+15) ; libaom convention }
 While(S>=0)and(D.ReadPos<D.EndPos)Do Begin
  B:=D.Buffer^.Data^[D.ReadPos];
  D.Dif:=D.Dif xor(Int64(B)shl S);
  Inc(D.ReadPos);
  Inc(D.Cnt,8);
  Dec(S,8);
 End;
 { Si le buffer est epuise, on laisse Cnt tel quel ; le decodeur lira
   des "zeros" implicites en haut de Dif jusqu'a ce que le caller arrete. }
End;

Procedure InitNormativeRangeDecoder(Var D:TAV1NormativeRangeDecoder;
 Var Buffer:TAV1ByteBuffer;StartOffs,ByteCount:LongInt);
Begin
 D.Dif:=$7FFFFFFF;            { (1 shl 31) - 1 ; valeur initiale libaom }
 D.Range:=$8000;
 D.Cnt:=-15;
 D.Buffer:=@Buffer;
 D.ReadPos:=StartOffs;
 D.EndPos:=StartOffs+ByteCount;
 D.SymbolCount:=0;
 D.Failed:=(Buffer.Data=Nil)or(StartOffs<0)or(ByteCount<0)
           or(StartOffs+ByteCount>Buffer.Size);
 If not D.Failed Then NormativeRangeDecRefill(D);
End;

Function NormativeRangeDecStateIsValid(Const D:TAV1NormativeRangeDecoder):Boolean;
Begin
 NormativeRangeDecStateIsValid:=False;
 If D.Failed Then Exit;
 If D.Buffer=Nil Then Exit;
 If(D.Range<$8000)or(D.Range>$FFFF)Then Exit;
 If D.Dif<0 Then Exit;
 NormativeRangeDecStateIsValid:=True;
End;

Function DecodeNormativeCDFSymbol(Var D:TAV1NormativeRangeDecoder;
 Const Model:TEntropyCDF):Byte;
Var
 C,U,V:LongInt;
 Ret,N:LongInt;
 ICDF:LongInt;
 NewRange:LongInt;
 ShiftAmount:LongInt;
Begin
 DecodeNormativeCDFSymbol:=0;
 If D.Failed Then Exit;
 If not ValidateRangeEncoderCDF(Model)Then Begin
  D.Failed:=True; Exit;
 End;
 If not NormativeRangeDecStateIsValid(D)Then Begin
  D.Failed:=True; Exit;
 End;
 N:=Model.SymbolCount-1;
 C:=LongInt((D.Dif shr 16)and $FFFF);
 V:=D.Range;
 Ret:=-1;
 Repeat
  U:=V;
  Inc(Ret);
  If Ret>N Then Begin
   { ne devrait jamais arriver : pour Ret=N on a V=0 et la boucle sort }
   D.Failed:=True; Exit;
  End;
  ICDF:=32768-LongInt(Model.CDF[Ret+1]);   { = icdf libaom au cran Ret }
  V:=((D.Range shr 8)*(ICDF shr 6)shr 1)+4*(N-Ret);
 Until C>=V;
 NewRange:=U-V;
 D.Dif:=D.Dif-(Int64(V)shl 16);
 If(NewRange<=0)or(NewRange>$FFFF)Then Begin
  D.Failed:=True; Exit;
 End;
 ShiftAmount:=16-LongInt(NormativeILogNZ(NewRange));
 Dec(D.Cnt,ShiftAmount);
 If ShiftAmount>0 Then
  D.Dif:=((D.Dif+1)shl ShiftAmount)-1;
 D.Range:=NewRange shl ShiftAmount;
 If D.Cnt<0 Then NormativeRangeDecRefill(D);
 Inc(D.SymbolCount);
 DecodeNormativeCDFSymbol:=Byte(Ret);
End;

{ Test roundtrip : encode une sequence connue, puis decode-la et compare.
  Couvre plusieurs CDFs (uniforme 4-aire, binaire 50/50, binaire 16384,
  ternaire asymetrique) sur des sequences variees. Si une difference est
  detectee a n'importe quel point, le test echoue. C'est la PREMIERE
  preuve que le coder produit un flux exploitable et pas seulement
  deterministe. }
Function ValidateNormativeRangeCoderRoundTripSelfTest:Boolean;
Const
 SeqLen=12;
Var
 Buf:TAV1ByteBuffer;
 Enc:TAV1NormativeRangeEncoder;
 Dec:TAV1NormativeRangeDecoder;
 Model4,Model2,Model2Skew,Model3:TEntropyCDF;
 Seq:Array[0..SeqLen-1]of Byte;
 ModelIdx:Array[0..SeqLen-1]of Byte;
 I:LongInt;
 Got:Byte;
Begin
 ValidateNormativeRangeCoderRoundTripSelfTest:=False;
 InitAV1ByteBuffer(Buf);
 If not AllocateAV1ByteBuffer(Buf,AV1MaxOBUBytes)Then Exit;

 InitExplicitCDF(Model4,4,8192,16384,24576,0,0,0,0,0,0,0,0,0,0,0,0);
 InitFixedCDF(Model2,2,2);
 InitExplicitCDF(Model2Skew,2,28000,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(Model3,3,4096,28672,0,0,0,0,0,0,0,0,0,0,0,0,0);

 { Sequence couvrant : Model4 sur valeurs extremes et milieu,
   Model2 alternance, Model2Skew avec valeur improbable, Model3 mixte }
 Seq[ 0]:=0; ModelIdx[ 0]:=0;
 Seq[ 1]:=3; ModelIdx[ 1]:=0;
 Seq[ 2]:=1; ModelIdx[ 2]:=0;
 Seq[ 3]:=2; ModelIdx[ 3]:=0;
 Seq[ 4]:=0; ModelIdx[ 4]:=1;
 Seq[ 5]:=1; ModelIdx[ 5]:=1;
 Seq[ 6]:=0; ModelIdx[ 6]:=1;
 Seq[ 7]:=1; ModelIdx[ 7]:=2;     { valeur improbable de Model2Skew }
 Seq[ 8]:=0; ModelIdx[ 8]:=2;
 Seq[ 9]:=2; ModelIdx[ 9]:=3;
 Seq[10]:=0; ModelIdx[10]:=3;
 Seq[11]:=1; ModelIdx[11]:=3;

 InitNormativeRangeEncoder(Enc,Buf);
 For I:=0 to SeqLen-1 Do
  Case ModelIdx[I]of
   0:EncodeNormativeCDFSymbol(Enc,Seq[I],Model4);
   1:EncodeNormativeCDFSymbol(Enc,Seq[I],Model2);
   2:EncodeNormativeCDFSymbol(Enc,Seq[I],Model2Skew);
   3:EncodeNormativeCDFSymbol(Enc,Seq[I],Model3);
  End;
 FinishNormativeRangeEncoder(Enc);
 If not ValidateNormativeRangePayload(Enc)Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;

 InitNormativeRangeDecoder(Dec,Buf,0,Buf.Size);
 If Dec.Failed Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 For I:=0 to SeqLen-1 Do Begin
  Case ModelIdx[I]of
   0:Got:=DecodeNormativeCDFSymbol(Dec,Model4);
   1:Got:=DecodeNormativeCDFSymbol(Dec,Model2);
   2:Got:=DecodeNormativeCDFSymbol(Dec,Model2Skew);
   3:Got:=DecodeNormativeCDFSymbol(Dec,Model3);
  Else Got:=255;
  End;
  If Dec.Failed Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
  If Got<>Seq[I]Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 End;

 FreeAV1ByteBuffer(Buf);
 ValidateNormativeRangeCoderRoundTripSelfTest:=True;
End;

{ ============================================================
  Tables CDF par defaut AV1 spec section 9.4
  ============================================================
  Cette section pose la fondation des tables CDF utilisees par
  l'encodeur AV1. Pour la PREMIERE tuile, on a besoin au minimum :
   - skip CDF (3 contextes, 2 symboles)        : section 9.4.1
   - intra Y mode CDF (5x5 contextes, 13 modes) : section 9.4.2
   - partition CDF (4 contextes, 4 symboles 4-way) : section 9.4.3

  Convention de stockage interne (TEntropyCDF) :
    CDF[0]=0, CDF[N]=32768, croissant strict, 0 < CDF[k] < 32768.
  Les valeurs spec libaom sont aussi des CDF cumulatives directement
  utilisables ici (pas besoin de conversion ICDF->CDF).

  ETAT actuel des transcriptions :
   - skip            : VALEURS REELLES libaom (entropymode.c)
   - intra Y mode KF : VALEURS REELLES libaom (25 contextes x 13 modes)
   - partition 4-way : VALEURS REELLES libaom (4 contextes 8x8)
                       Les 12 contextes 8-way (16/32/64) et 4 contextes
                       6-way (128) sont a ajouter pour blocs > 8x8.
  Toutes les CDFs passent ValidateRangeEncoderCDF. }

Const
 AV1IntraModes          = 13;
 AV1KFModeContexts      = 5;
 AV1Partition4WayCtx    = 4;
 AV1Partition4WayTypes  = 4;
 { libaom MAX_TX_CATS=4, TX_SIZE_CONTEXTS=3, MAX_TX_DEPTH+1 in {2,3,3,3} }
 AV1TxCats              = 4;
 AV1TxSizeCtxs          = 3;
 AV1TxMaxDepthPlus1     = 3;
 { libaom default_eob_multi{16,32,64,128} : on retient
   q_ctx=0, plane=Y, ctx_axis=0 (premier des deux contextes
   par TX size). Suffit pour encoder un bloc EOB minimal. }
 AV1EobTxSizes          = 4;       { 4x4(=16), 8x8(=64), 16x16(=256)... mapping libaom 16/32/64/128 }
 AV1EobMaxClasses       = 8;       { eob_multi128 -> 8 symboles }

Type
 TAV1DefaultCDFs=Record
  Skip      : Array[0..AV1SkipContexts-1]of TEntropyCDF;
  KFYMode   : Array[0..AV1KFModeContexts-1,
                    0..AV1KFModeContexts-1]of TEntropyCDF;
  Partition4: Array[0..AV1Partition4WayCtx-1]of TEntropyCDF;
  TxSize    : Array[0..AV1TxCats-1,
                    0..AV1TxSizeCtxs-1]of TEntropyCDF;
  EobPt     : Array[0..AV1EobTxSizes-1]of TEntropyCDF;
 End;

Procedure InitDefaultAV1SkipCDFs(Var T:TAV1DefaultCDFs);
Begin
 { libaom : default_skip_cdfs[SKIP_CONTEXTS][CDF_SIZE(2)]
     ctx 0 : AOM_CDF2(31671)  -> mostly NOT skip (block coded)
     ctx 1 : AOM_CDF2(16515)  -> equiprobable
     ctx 2 : AOM_CDF2(4576)   -> mostly skip }
 InitExplicitCDF(T.Skip[0],2,31671,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.Skip[1],2,16515,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.Skip[2],2, 4576,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
End;

Procedure InitDefaultAV1KFYModeCDFs(Var T:TAV1DefaultCDFs);
Begin
 { default_kf_y_mode_cdf de libaom av1/common/entropymode.c
   25 contextes (above_mode x left_mode dans {DC,V,H,D45,..}), 13 modes
   intra par contexte. Format AOM_CDF13(v1..v12) -> CDF[1..12] ;
   CDF[0]=0, CDF[13]=32768 ajoutes par InitExplicitCDF. }
 { Contexte [0,*] : above = DC_PRED }
 InitExplicitCDF(T.KFYMode[0,0],13,
  15588,17027,19338,20218,20682,21110,21825,23244,24189,28165,29093,30466,0,0,0);
 InitExplicitCDF(T.KFYMode[0,1],13,
  12016,18066,19516,20303,20719,21444,21888,23032,24434,28658,30172,31409,0,0,0);
 InitExplicitCDF(T.KFYMode[0,2],13,
  10052,10771,22296,22788,23055,23239,24133,25620,26160,29336,29929,31567,0,0,0);
 InitExplicitCDF(T.KFYMode[0,3],13,
  14091,15406,16442,18808,19136,19546,19998,22096,24746,29585,30958,32462,0,0,0);
 InitExplicitCDF(T.KFYMode[0,4],13,
  12122,13265,15603,16501,18609,20033,22391,25583,26437,30261,31073,32475,0,0,0);
 { Contexte [1,*] : above = V_PRED }
 InitExplicitCDF(T.KFYMode[1,0],13,
  10023,19585,20848,21440,21832,22760,23089,24023,25381,29014,30482,31436,0,0,0);
 InitExplicitCDF(T.KFYMode[1,1],13,
  5983,24099,24560,24886,25066,25795,25913,26423,27610,29905,31276,31794,0,0,0);
 InitExplicitCDF(T.KFYMode[1,2],13,
  7444,12781,20177,20728,21077,21607,22170,23405,24469,27915,29090,30492,0,0,0);
 InitExplicitCDF(T.KFYMode[1,3],13,
  8537,14689,15432,17087,17408,18172,18408,19825,24649,29153,31096,32210,0,0,0);
 InitExplicitCDF(T.KFYMode[1,4],13,
  7543,14231,15496,16195,17905,20717,21984,24516,26001,29675,30981,31994,0,0,0);
 { Contexte [2,*] : above = H_PRED }
 InitExplicitCDF(T.KFYMode[2,0],13,
  12613,13591,21383,22004,22312,22577,23401,25055,25729,29538,30305,32077,0,0,0);
 InitExplicitCDF(T.KFYMode[2,1],13,
  9687,13470,18506,19230,19604,20147,20695,22062,23219,27743,29211,30907,0,0,0);
 InitExplicitCDF(T.KFYMode[2,2],13,
  6183,6505,26024,26252,26366,26434,27082,28354,28555,30467,30794,32086,0,0,0);
 InitExplicitCDF(T.KFYMode[2,3],13,
  10718,11734,14954,17224,17565,17924,18561,21523,23878,28975,30287,32252,0,0,0);
 InitExplicitCDF(T.KFYMode[2,4],13,
  9194,9858,16501,17263,18424,19171,21563,25961,26561,30072,30737,32463,0,0,0);
 { Contexte [3,*] : above = D45_PRED (categorie diagonale) }
 InitExplicitCDF(T.KFYMode[3,0],13,
  12602,14399,15488,18381,18778,19315,19724,21419,25060,29696,30917,32409,0,0,0);
 InitExplicitCDF(T.KFYMode[3,1],13,
  8203,13821,14524,17105,17439,18131,18404,19468,25225,29485,31158,32342,0,0,0);
 InitExplicitCDF(T.KFYMode[3,2],13,
  8451,9731,15004,17643,18012,18425,19070,21538,24605,29118,30078,32018,0,0,0);
 InitExplicitCDF(T.KFYMode[3,3],13,
  7714,9048,9516,16667,16817,16994,17153,18767,26743,30389,31536,32528,0,0,0);
 InitExplicitCDF(T.KFYMode[3,4],13,
  8843,10280,11496,15317,16652,17943,19108,22718,25769,29953,30983,32485,0,0,0);
 { Contexte [4,*] : above = PAETH (autre categorie) }
 InitExplicitCDF(T.KFYMode[4,0],13,
  12578,13671,15979,16834,19075,20913,22989,25449,26219,30214,31150,32477,0,0,0);
 InitExplicitCDF(T.KFYMode[4,1],13,
  9563,13626,15080,15892,17756,20863,22207,24236,25380,29653,31143,32277,0,0,0);
 InitExplicitCDF(T.KFYMode[4,2],13,
  8356,8901,17616,18256,19350,20106,22598,25947,26466,29900,30523,32261,0,0,0);
 InitExplicitCDF(T.KFYMode[4,3],13,
  10835,11815,13124,16042,17018,18039,18947,22753,24615,29489,30883,32482,0,0,0);
 InitExplicitCDF(T.KFYMode[4,4],13,
  7618,8288,9859,10509,15386,18657,22903,28776,29180,31355,31802,32593,0,0,0);
End;

Procedure InitDefaultAV1Partition4WayCDFs(Var T:TAV1DefaultCDFs);
Begin
 { default_partition_cdf de libaom : les 4 PREMIERES lignes (4-way,
   block 8x8) de PARTITION_CONTEXTS=16. Format AOM_CDF4(v1,v2,v3) ->
   4 symboles PARTITION_NONE, HORZ, VERT, SPLIT. Les 12 lignes
   suivantes sont CDF10 (8-way, blocs 16x16/32x32/64x64) -- a
   transcrire dans une session future si besoin. }
 InitExplicitCDF(T.Partition4[0],4,19132,25510,30392,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.Partition4[1],4,13928,19855,28540,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.Partition4[2],4,12522,23679,28629,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.Partition4[3],4, 9896,18783,25853,0,0,0,0,0,0,0,0,0,0,0,0);
End;

Procedure InitDefaultAV1TxSizeCDFs(Var T:TAV1DefaultCDFs);
Begin
 { default_tx_size_cdf de libaom (entropymode.c, lignes ~872-886)
   [MAX_TX_CATS=4][TX_SIZE_CONTEXTS=3][CDF_SIZE(MAX_TX_DEPTH+1)].
   Categorie 0 : binaire (CDF2). Categories 1..3 : 3 symboles (CDF3). }
 { Cat 0 - binaire }
 InitExplicitCDF(T.TxSize[0,0],2,19968,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.TxSize[0,1],2,19968,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.TxSize[0,2],2,24320,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 { Cat 1 }
 InitExplicitCDF(T.TxSize[1,0],3,12272,30172,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.TxSize[1,1],3,12272,30172,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.TxSize[1,2],3,18677,30848,0,0,0,0,0,0,0,0,0,0,0,0,0);
 { Cat 2 }
 InitExplicitCDF(T.TxSize[2,0],3,12986,15180,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.TxSize[2,1],3,12986,15180,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.TxSize[2,2],3,24302,25602,0,0,0,0,0,0,0,0,0,0,0,0,0);
 { Cat 3 }
 InitExplicitCDF(T.TxSize[3,0],3, 5782,11475,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.TxSize[3,1],3, 5782,11475,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitExplicitCDF(T.TxSize[3,2],3,16803,22759,0,0,0,0,0,0,0,0,0,0,0,0,0);
End;

Procedure InitDefaultAV1EobPtCDFs(Var T:TAV1DefaultCDFs);
Begin
 { libaom av1_default_eob_multi{16,32,64,128}_cdfs : on extrait
   q_ctx=0, plane_type=Y(0), ctx=0. Donne une CDF par TX size pour
   la position EOB (eob_pt). N symboles selon TX size.
   token_cdfs.h, lignes 772+ (pour eob_multi16) ... 832+ (eob_multi128). }
 { TX 16 -> CDF5 (4 valeurs) }
 InitExplicitCDF(T.EobPt[0],5, 840,1039,1980,4895,0,0,0,0,0,0,0,0,0,0,0);
 { TX 32 -> CDF6 (5 valeurs) }
 InitExplicitCDF(T.EobPt[1],6, 400, 520, 977,2102,6542,0,0,0,0,0,0,0,0,0,0);
 { TX 64 -> CDF7 (6 valeurs) }
 InitExplicitCDF(T.EobPt[2],7, 329, 498,1101,1784,3265,7758,0,0,0,0,0,0,0,0,0);
 { TX 128 -> CDF8 (7 valeurs) }
 InitExplicitCDF(T.EobPt[3],8, 219, 482,1140,2091,3680,6028,12586,0,0,0,0,0,0,0,0);
End;

Procedure InitDefaultAV1CDFs(Var T:TAV1DefaultCDFs);
Begin
 FillChar(T,SizeOf(T),0);
 InitDefaultAV1SkipCDFs(T);
 InitDefaultAV1KFYModeCDFs(T);
 InitDefaultAV1Partition4WayCDFs(T);
 InitDefaultAV1TxSizeCDFs(T);
 InitDefaultAV1EobPtCDFs(T);
End;

Function ValidateAllDefaultAV1CDFs(Const T:TAV1DefaultCDFs):Boolean;
Var
 I,J:Byte;
Begin
 ValidateAllDefaultAV1CDFs:=False;
 For I:=0 to AV1SkipContexts-1 Do
  If not ValidateRangeEncoderCDF(T.Skip[I])Then Exit;
 For I:=0 to AV1KFModeContexts-1 Do
  For J:=0 to AV1KFModeContexts-1 Do
   If not ValidateRangeEncoderCDF(T.KFYMode[I,J])Then Exit;
 For I:=0 to AV1Partition4WayCtx-1 Do
  If not ValidateRangeEncoderCDF(T.Partition4[I])Then Exit;
 For I:=0 to AV1TxCats-1 Do
  For J:=0 to AV1TxSizeCtxs-1 Do
   If not ValidateRangeEncoderCDF(T.TxSize[I,J])Then Exit;
 For I:=0 to AV1EobTxSizes-1 Do
  If not ValidateRangeEncoderCDF(T.EobPt[I])Then Exit;
 ValidateAllDefaultAV1CDFs:=True;
End;

{ Self-test : initialise les defaults, valide leur structure, puis
  encode et decode un message court qui exerce chaque famille de CDF.
  Sequence simulee : "intra DC, pas de split, skip=0" sur 4 contextes. }
Function ValidateDefaultAV1CDFsRoundTripSelfTest:Boolean;
Var
 T:TAV1DefaultCDFs;
 Buf:TAV1ByteBuffer;
 Enc:TAV1NormativeRangeEncoder;
 Dec:TAV1NormativeRangeDecoder;
 Got:Byte;
Begin
 ValidateDefaultAV1CDFsRoundTripSelfTest:=False;
 InitDefaultAV1CDFs(T);
 If not ValidateAllDefaultAV1CDFs(T)Then Exit;

 InitAV1ByteBuffer(Buf);
 If not AllocateAV1ByteBuffer(Buf,AV1MaxOBUBytes)Then Exit;

 InitNormativeRangeEncoder(Enc,Buf);
 { Sequence : partition NONE (ctx 0), intra DC mode (ctx [0,0]), skip=0 (ctx 0) }
 EncodeNormativeCDFSymbol(Enc,0,T.Partition4[0]);
 EncodeNormativeCDFSymbol(Enc,0,T.KFYMode[0,0]);
 EncodeNormativeCDFSymbol(Enc,0,T.Skip[0]);
 { Variante avec valeurs non-triviales pour stresser les CDFs }
 EncodeNormativeCDFSymbol(Enc,3,T.Partition4[2]);
 EncodeNormativeCDFSymbol(Enc,12,T.KFYMode[3,4]);  { dernier mode intra }
 EncodeNormativeCDFSymbol(Enc,1,T.Skip[2]);         { skip improbable ctx 2 }
 { Bloc skip=0 + EOB=0 (tous coefficients zero) : on signale tx_size
   minimal (cat 0 / ctx 0 -> symbole 0) puis eob_pt classe 0 (TX 16). }
 EncodeNormativeCDFSymbol(Enc,0,T.TxSize[0,0]);
 EncodeNormativeCDFSymbol(Enc,0,T.EobPt[0]);
 { Variantes pour stresser TX size et EOB sur autres TX }
 EncodeNormativeCDFSymbol(Enc,2,T.TxSize[2,1]);
 EncodeNormativeCDFSymbol(Enc,7,T.EobPt[3]);        { dernier symbole eob_multi128 }
 FinishNormativeRangeEncoder(Enc);
 If not ValidateNormativeRangePayload(Enc)Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;

 InitNormativeRangeDecoder(Dec,Buf,0,Buf.Size);
 If Dec.Failed Then Begin FreeAV1ByteBuffer(Buf); Exit; End;

 Got:=DecodeNormativeCDFSymbol(Dec,T.Partition4[0]);
 If Dec.Failed or(Got<>0)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.KFYMode[0,0]);
 If Dec.Failed or(Got<>0)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.Skip[0]);
 If Dec.Failed or(Got<>0)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.Partition4[2]);
 If Dec.Failed or(Got<>3)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.KFYMode[3,4]);
 If Dec.Failed or(Got<>12)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.Skip[2]);
 If Dec.Failed or(Got<>1)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.TxSize[0,0]);
 If Dec.Failed or(Got<>0)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.EobPt[0]);
 If Dec.Failed or(Got<>0)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.TxSize[2,1]);
 If Dec.Failed or(Got<>2)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 Got:=DecodeNormativeCDFSymbol(Dec,T.EobPt[3]);
 If Dec.Failed or(Got<>7)Then Begin FreeAV1ByteBuffer(Buf); Exit; End;

 FreeAV1ByteBuffer(Buf);
 ValidateDefaultAV1CDFsRoundTripSelfTest:=True;
End;

{ ============================================================
  Premier bloc AV1 spec-conforme : 8x8 intra DC, partition NONE, skip=0
  ============================================================
  Cette session encode la PARTIE de l'en-tete de bloc AV1 qui repose
  sur des CDFs deja transcrites de libaom (skip + intra Y mode +
  partition 4-way). Ne couvre PAS encore :
   - tx_size_cdf (4 categories x 3 contextes -- spec § 9.4 ligne 872)
   - tx_type_cdf (intra_ext_tx_cdf -- ~250 valeurs)
   - eob, coeff_base, coeff_sign CDFs (residual)
   - DCT 4x4 forward et quantification

  La sequence emise correspond au prefixe binaire d'un bloc 8x8 dans
  un superblock de keyframe avec :
     above_mode=DC_PRED, left_mode=DC_PRED  -> KFYMode[0,0]
     above_skip=0, left_skip=0              -> Skip context 0
     above_split=0, left_split=0            -> Partition context 0

  Symboles ecrits, dans l'ordre spec AV1 § 5.11 (decode_block) :
     1. partition_none via Partition4[0]   (apres parent decode_partition)
     2. skip=0 via Skip[0]                  (mode_info debut)
     3. y_mode=DC=0 via KFYMode[0,0]        (mode_info)
  Total : 3 symboles. La sequence est verifiee par roundtrip decodeur. }

Type
 TAV1MinimalBlockHeader=Record
  PartitionSymbol:Byte;   { 0=NONE, 1=HORZ, 2=VERT, 3=SPLIT }
  Skip:Byte;              { 0 ou 1 }
  IntraYMode:Byte;        { 0..12 (DC_PRED=0, ..., PAETH_PRED=12) }
  AboveModeCtx:Byte;      { 0..4 dans KF_MODE_CONTEXTS }
  LeftModeCtx:Byte;       { 0..4 }
  PartitionCtx:Byte;      { 0..3 (above_split, left_split) }
  SkipCtx:Byte;           { 0..2 }
 End;

Procedure InitMinimalBlockHeader_8x8_IntraDC(Var H:TAV1MinimalBlockHeader);
Begin
 H.PartitionSymbol:=0;     { aptNone }
 H.Skip:=0;
 H.IntraYMode:=0;          { DC_PRED }
 H.AboveModeCtx:=0;        { DC_PRED -> ctx 0 }
 H.LeftModeCtx:=0;         { idem }
 H.PartitionCtx:=0;        { aucun voisin split -> ctx 0 }
 H.SkipCtx:=0;             { aucun voisin skip -> ctx 0 }
End;

Function ValidateMinimalBlockHeader(Const H:TAV1MinimalBlockHeader):Boolean;
Begin
 ValidateMinimalBlockHeader:=False;
 If H.PartitionSymbol>=AV1Partition4WayTypes Then Exit;
 If H.Skip>1 Then Exit;
 If H.IntraYMode>=AV1IntraModes Then Exit;
 If H.AboveModeCtx>=AV1KFModeContexts Then Exit;
 If H.LeftModeCtx>=AV1KFModeContexts Then Exit;
 If H.PartitionCtx>=AV1Partition4WayCtx Then Exit;
 If H.SkipCtx>=AV1SkipContexts Then Exit;
 ValidateMinimalBlockHeader:=True;
End;

{ Encode l'en-tete de bloc minimal dans un range encoder normatif
  EXISTANT. Le caller doit avoir initialise l'encodeur. Aucun appel
  a Finish ici : permet de chainer plusieurs blocs ou d'ajouter le
  residuel ulterieurement. }
Procedure EncodeMinimalBlockHeader(Var Enc:TAV1NormativeRangeEncoder;
 Const H:TAV1MinimalBlockHeader;Const T:TAV1DefaultCDFs);
Begin
 If Enc.Failed Then Exit;
 If not ValidateMinimalBlockHeader(H)Then Begin
  Enc.Failed:=True; Exit;
 End;
 { Spec AV1 § 5.11.4 decode_partition : partition d'abord }
 EncodeNormativeCDFSymbol(Enc,H.PartitionSymbol,T.Partition4[H.PartitionCtx]);
 { Spec AV1 § 5.11.6 decode_block / mode_info : skip puis y_mode }
 EncodeNormativeCDFSymbol(Enc,H.Skip,T.Skip[H.SkipCtx]);
 EncodeNormativeCDFSymbol(Enc,H.IntraYMode,
  T.KFYMode[H.AboveModeCtx,H.LeftModeCtx]);
End;

{ Decode-side : symetrique, lit les 3 symboles dans le meme ordre. }
Function DecodeMinimalBlockHeader(Var D:TAV1NormativeRangeDecoder;
 Var H:TAV1MinimalBlockHeader;Const T:TAV1DefaultCDFs;
 AboveCtx,LeftCtx,PartCtx,SkipCtx:Byte):Boolean;
Begin
 DecodeMinimalBlockHeader:=False;
 H.AboveModeCtx:=AboveCtx;
 H.LeftModeCtx:=LeftCtx;
 H.PartitionCtx:=PartCtx;
 H.SkipCtx:=SkipCtx;
 If(AboveCtx>=AV1KFModeContexts)or(LeftCtx>=AV1KFModeContexts)or
   (PartCtx>=AV1Partition4WayCtx)or(SkipCtx>=AV1SkipContexts)Then Exit;
 H.PartitionSymbol:=DecodeNormativeCDFSymbol(D,T.Partition4[PartCtx]);
 If D.Failed Then Exit;
 H.Skip:=DecodeNormativeCDFSymbol(D,T.Skip[SkipCtx]);
 If D.Failed Then Exit;
 H.IntraYMode:=DecodeNormativeCDFSymbol(D,T.KFYMode[AboveCtx,LeftCtx]);
 If D.Failed Then Exit;
 DecodeMinimalBlockHeader:=ValidateMinimalBlockHeader(H);
End;

{ Self-test : encode l'en-tete d'un bloc 8x8 intra DC, partition NONE,
  skip=0 ; ferme le range encoder ; reouvre en decodeur ; verifie que
  les 3 symboles sont retrouves bit-exact. C'est la PREMIERE preuve
  qu'un fragment de syntaxe AV1 spec-conforme transite par le range
  coder de bout-en-bout. }
Function ValidateMinimalBlockHeaderRoundTripSelfTest:Boolean;
Var
 T:TAV1DefaultCDFs;
 Buf:TAV1ByteBuffer;
 Enc:TAV1NormativeRangeEncoder;
 Dec:TAV1NormativeRangeDecoder;
 H,H2:TAV1MinimalBlockHeader;
Begin
 ValidateMinimalBlockHeaderRoundTripSelfTest:=False;
 InitDefaultAV1CDFs(T);
 InitMinimalBlockHeader_8x8_IntraDC(H);
 If not ValidateMinimalBlockHeader(H)Then Exit;

 InitAV1ByteBuffer(Buf);
 If not AllocateAV1ByteBuffer(Buf,AV1MaxOBUBytes)Then Exit;

 InitNormativeRangeEncoder(Enc,Buf);
 EncodeMinimalBlockHeader(Enc,H,T);
 FinishNormativeRangeEncoder(Enc);
 If not ValidateNormativeRangePayload(Enc)Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;
 If Buf.Size<1 Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;

 InitNormativeRangeDecoder(Dec,Buf,0,Buf.Size);
 If Dec.Failed Then Begin FreeAV1ByteBuffer(Buf); Exit; End;
 If not DecodeMinimalBlockHeader(Dec,H2,T,0,0,0,0)Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;
 If(H2.PartitionSymbol<>0)or(H2.Skip<>0)or(H2.IntraYMode<>0)Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;

 FreeAV1ByteBuffer(Buf);
 ValidateMinimalBlockHeaderRoundTripSelfTest:=True;
End;

{ Variante stress : encode un bloc avec valeurs ATYPIQUES (mode PAETH=12,
  partition VERT=2 dans contexte 3, skip=1 dans contexte 2, contextes
  intra above=4 left=2). Verifie que le pipeline gere correctement les
  symboles improbables (CDF-wise) sans corruption. }
Function ValidateMinimalBlockHeaderStressSelfTest:Boolean;
Var
 T:TAV1DefaultCDFs;
 Buf:TAV1ByteBuffer;
 Enc:TAV1NormativeRangeEncoder;
 Dec:TAV1NormativeRangeDecoder;
 H,H2:TAV1MinimalBlockHeader;
Begin
 ValidateMinimalBlockHeaderStressSelfTest:=False;
 InitDefaultAV1CDFs(T);
 H.PartitionSymbol:=2;     { VERT }
 H.Skip:=1;
 H.IntraYMode:=12;         { PAETH_PRED }
 H.AboveModeCtx:=4;
 H.LeftModeCtx:=2;
 H.PartitionCtx:=3;
 H.SkipCtx:=2;
 If not ValidateMinimalBlockHeader(H)Then Exit;

 InitAV1ByteBuffer(Buf);
 If not AllocateAV1ByteBuffer(Buf,AV1MaxOBUBytes)Then Exit;

 InitNormativeRangeEncoder(Enc,Buf);
 EncodeMinimalBlockHeader(Enc,H,T);
 FinishNormativeRangeEncoder(Enc);
 If not ValidateNormativeRangePayload(Enc)Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;

 InitNormativeRangeDecoder(Dec,Buf,0,Buf.Size);
 If not DecodeMinimalBlockHeader(Dec,H2,T,4,2,3,2)Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;
 If(H2.PartitionSymbol<>2)or(H2.Skip<>1)or(H2.IntraYMode<>12)Then Begin
  FreeAV1ByteBuffer(Buf); Exit;
 End;

 FreeAV1ByteBuffer(Buf);
 ValidateMinimalBlockHeaderStressSelfTest:=True;
End;

{ ============================================================
  Premiere VRAIE tuile complete bit-exact en sortie du range coder.
  ============================================================
  Sequence : block_header (partition NONE + skip=0 + y_mode DC) +
  tx_size (cat 0 / ctx 0 / symbole 0 = profondeur minimale) +
  eob_pt (TX 16 / symbole 0 = aucun coefficient non-nul).
  Le bloc utilise skip=0 cote header mais signale via EOB=0 que la
  transformee n'a aucun coefficient. C'est le minimum syntaxique
  d'un bloc residue-zero qui n'utilise pas le drapeau skip global. }

Procedure EncodeMinimalCompleteBlock(Var Enc:TAV1NormativeRangeEncoder;
 Const H:TAV1MinimalBlockHeader;TxCat,TxCtx,TxSym:Byte;
 EobTxIndex,EobSym:Byte;Const T:TAV1DefaultCDFs);
Begin
 If Enc.Failed Then Exit;
 If(TxCat>=AV1TxCats)or(TxCtx>=AV1TxSizeCtxs)Then Begin
  Enc.Failed:=True; Exit;
 End;
 If EobTxIndex>=AV1EobTxSizes Then Begin
  Enc.Failed:=True; Exit;
 End;
 EncodeMinimalBlockHeader(Enc,H,T);
 If Enc.Failed Then Exit;
 EncodeNormativeCDFSymbol(Enc,TxSym,T.TxSize[TxCat,TxCtx]);
 If Enc.Failed Then Exit;
 EncodeNormativeCDFSymbol(Enc,EobSym,T.EobPt[EobTxIndex]);
End;

Function DecodeMinimalCompleteBlock(Var D:TAV1NormativeRangeDecoder;
 Var H:TAV1MinimalBlockHeader;Var TxSym,EobSym:Byte;
 AboveCtx,LeftCtx,PartCtx,SkipCtx,TxCat,TxCtx,EobTxIndex:Byte;
 Const T:TAV1DefaultCDFs):Boolean;
Begin
 DecodeMinimalCompleteBlock:=False;
 If(TxCat>=AV1TxCats)or(TxCtx>=AV1TxSizeCtxs)Then Exit;
 If EobTxIndex>=AV1EobTxSizes Then Exit;
 If not DecodeMinimalBlockHeader(D,H,T,AboveCtx,LeftCtx,PartCtx,SkipCtx)Then Exit;
 TxSym:=DecodeNormativeCDFSymbol(D,T.TxSize[TxCat,TxCtx]);
 If D.Failed Then Exit;
 EobSym:=DecodeNormativeCDFSymbol(D,T.EobPt[EobTxIndex]);
 If D.Failed Then Exit;
 DecodeMinimalCompleteBlock:=True;
End;

{ Range-encode un bloc minimal complet dans Payload et ferme le coder.
  Le payload resultant est le residual (range-coded) d'une tuile a un
  seul bloc 4x4 intra DC, EOB=0. On ne prefixe pas l'en-tete tile_size
  car l'OBU Tile Group d'un AV1 frame "single-tile" peut omettre les
  bytes tile_size (cf. AV1 spec § 5.11.1). }
Function BuildMinimalCompleteTilePayload(Const T:TAV1DefaultCDFs;
 Var Payload:TAV1ByteBuffer):Boolean;
Var
 Enc:TAV1NormativeRangeEncoder;
 H:TAV1MinimalBlockHeader;
 StartSize:LongInt;
Begin
 BuildMinimalCompleteTilePayload:=False;
 If Payload.Data=Nil Then
  If not AllocateAV1ByteBuffer(Payload,AV1MaxOBUBytes)Then Exit;
 StartSize:=Payload.Size;
 InitMinimalBlockHeader_8x8_IntraDC(H);
 InitNormativeRangeEncoder(Enc,Payload);
 EncodeMinimalCompleteBlock(Enc,H,0,0,0,0,0,T);
 FinishNormativeRangeEncoder(Enc);
 BuildMinimalCompleteTilePayload:=ValidateNormativeRangePayload(Enc)and
  ((Payload.Size-StartSize)>=2);
End;

{ Self-test : encode -> finish -> decode bit-exact ; puis enveloppe le
  payload dans un OBU Tile Group ; verifie enfin que le validateur strict
  ValidateBuiltInStandardAV1Bitstream l'accepte (rejet leve : aucun des
  trois marqueurs internes RawYUV/SymbolTrace/MinimalDCSkip ne matche). }
Function ValidateMinimalCompleteTileRoundTripSelfTest:Boolean;
Var
 T:TAV1DefaultCDFs;
 Payload,TileGroupOBU:TAV1ByteBuffer;
 Dec:TAV1NormativeRangeDecoder;
 Bitstream:TAV1Bitstream;
 H,H2:TAV1MinimalBlockHeader;
 TxSym,EobSym:Byte;
 Reason:String;
 PayloadStart,PayloadSize:LongInt;
Begin
 ValidateMinimalCompleteTileRoundTripSelfTest:=False;
 InitDefaultAV1CDFs(T);
 InitAV1ByteBuffer(Payload);
 InitAV1ByteBuffer(TileGroupOBU);
 InitAV1Bitstream(Bitstream);
 If not AllocateAV1ByteBuffer(Payload,AV1MaxOBUBytes)Then Exit;

 If not BuildMinimalCompleteTilePayload(T,Payload)Then Begin
  FreeAV1ByteBuffer(Payload); FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1Bitstream(Bitstream); Exit;
 End;

 { Roundtrip range-coded : doit retrouver tous les symboles. }
 InitNormativeRangeDecoder(Dec,Payload,0,Payload.Size);
 If Dec.Failed Then Begin
  FreeAV1ByteBuffer(Payload); FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1Bitstream(Bitstream); Exit;
 End;
 If not DecodeMinimalCompleteBlock(Dec,H2,TxSym,EobSym,0,0,0,0,0,0,0,T)Then Begin
  FreeAV1ByteBuffer(Payload); FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1Bitstream(Bitstream); Exit;
 End;
 InitMinimalBlockHeader_8x8_IntraDC(H);
 If(H2.PartitionSymbol<>H.PartitionSymbol)or(H2.Skip<>H.Skip)or
   (H2.IntraYMode<>H.IntraYMode)or(TxSym<>0)or(EobSym<>0)Then Begin
  FreeAV1ByteBuffer(Payload); FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1Bitstream(Bitstream); Exit;
 End;

 { Enveloppe en OBU Tile Group et confronte au validateur strict. }
 If not WriteOBU(obuTileGroup,Payload,TileGroupOBU)Then Begin
  FreeAV1ByteBuffer(Payload); FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1Bitstream(Bitstream); Exit;
 End;

 { Echelle de coherence : payload doit faire >=2 octets, ne pas
   commencer par "B2AR" ni "B2AS", et ne pas etre l'octet 0 isole. }
 If not GetOBUPayloadRange(TileGroupOBU,obuTileGroup,PayloadStart,
  PayloadSize)Then Begin
  FreeAV1ByteBuffer(Payload); FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1Bitstream(Bitstream); Exit;
 End;
 If PayloadSize<>Payload.Size Then Begin
  FreeAV1ByteBuffer(Payload); FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1Bitstream(Bitstream); Exit;
 End;

 Bitstream.TileGroup:=TileGroupOBU;
 If not ValidateBuiltInStandardAV1Bitstream(Bitstream,Reason)Then Begin
  Bitstream.TileGroup.Data:=Nil;  { evite double-free }
  FreeAV1ByteBuffer(Payload); FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1Bitstream(Bitstream); Exit;
 End;
 Bitstream.TileGroup.Data:=Nil;

 FreeAV1ByteBuffer(Payload);
 FreeAV1ByteBuffer(TileGroupOBU);
 FreeAV1Bitstream(Bitstream);
 ValidateMinimalCompleteTileRoundTripSelfTest:=True;
End;

Function ValidateNormativeRangeCoderStrictSelfTest:Boolean;
Var
 A,B:TAV1ByteBuffer;
 Encoder:TAV1NormativeRangeEncoder;
 Model:TEntropyCDF;
 I:LongInt;
Begin
 ValidateNormativeRangeCoderStrictSelfTest:=False;
 InitAV1ByteBuffer(A);
 InitAV1ByteBuffer(B);
 If not EncodeNormativeRangeTestVector(A)Then Exit;
 If not EncodeNormativeRangeTestVector(B)Then Begin
  FreeAV1ByteBuffer(A);
  Exit;
 End;
 If(A.Size<>B.Size)or(A.Size=0)Then Begin
  FreeAV1ByteBuffer(A);
  FreeAV1ByteBuffer(B);
  Exit;
 End;
 For I:=0 to A.Size-1 Do
  If A.Data^[I]<>B.Data^[I]Then Begin
   FreeAV1ByteBuffer(A);
   FreeAV1ByteBuffer(B);
   Exit;
  End;
 InitExplicitCDF(Model,2,16384,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
 InitNormativeRangeEncoder(Encoder,A);
 EncodeNormativeCDFSymbol(Encoder,2,Model);
 If not Encoder.Failed Then Begin
  FreeAV1ByteBuffer(A);
  FreeAV1ByteBuffer(B);
  Exit;
 End;
 FreeAV1ByteBuffer(A);
 FreeAV1ByteBuffer(B);
 If not ValidateNormativeRangeCoderRoundTripSelfTest Then Exit;
 If not ValidateDefaultAV1CDFsRoundTripSelfTest Then Exit;
 If not ValidateMinimalBlockHeaderRoundTripSelfTest Then Exit;
 If not ValidateMinimalBlockHeaderStressSelfTest Then Exit;
 If not ValidateMinimalCompleteTileRoundTripSelfTest Then Exit;
 ValidateNormativeRangeCoderStrictSelfTest:=True;
End;

Procedure EncodeNormativeUniformBit(Var Encoder:TAV1NormativeRangeEncoder;
 BitValue:Byte);
Var
 Model:TEntropyCDF;
Begin
 InitFixedCDF(Model,2,2);
 If BitValue<>0 Then BitValue:=1;
 EncodeNormativeCDFSymbol(Encoder,BitValue,Model);
End;

Procedure EncodeNormativeLiteral(Var Encoder:TAV1NormativeRangeEncoder;
 Value:LongInt;BitCount:Byte);
Var
 I:ShortInt;
Begin
 If BitCount=0 Then Exit;
 For I:=BitCount-1 Downto 0 Do
  EncodeNormativeUniformBit(Encoder,Byte((Value shr I)and 1));
End;

Procedure EncodeNormativeUnsigned(Var Encoder:TAV1NormativeRangeEncoder;
 Value:LongInt;MaxBits:Byte);
Var
 Bits:Byte;
 Temp:LongInt;
Begin
 If Value<0 Then Value:=0;
 Bits:=0;
 Temp:=Value;
 While(Temp>0)and(Bits<MaxBits)Do Begin
  Inc(Bits);
  Temp:=Temp shr 1;
 End;
 EncodeNormativeLiteral(Encoder,Bits,5);
 If Bits>0 Then EncodeNormativeLiteral(Encoder,Value,Bits);
End;

Function EOBClassSymbol(EOB:LongInt):Byte;
Begin
 If EOB<=0 Then EOBClassSymbol:=0
 Else If EOB=1 Then EOBClassSymbol:=1
 Else If EOB<=2 Then EOBClassSymbol:=2
 Else If EOB<=4 Then EOBClassSymbol:=3
 Else If EOB<=8 Then EOBClassSymbol:=4
 Else If EOB<=16 Then EOBClassSymbol:=5
 Else If EOB<=32 Then EOBClassSymbol:=6
 Else If EOB<=64 Then EOBClassSymbol:=7
 Else If EOB<=128 Then EOBClassSymbol:=8
 Else If EOB<=256 Then EOBClassSymbol:=9
 Else If EOB<=512 Then EOBClassSymbol:=10
 Else EOBClassSymbol:=11;
End;

Procedure EncodeNormativeEOB(Var Encoder:TAV1NormativeRangeEncoder;
 EOB:LongInt;Const CDFSet:TAV1NormativeCDFSet);
Begin
 EncodeNormativeCDFSymbol(Encoder,EOBClassSymbol(EOB),CDFSet.EOBCDF);
 If EOB>0 Then EncodeNormativeUnsigned(Encoder,EOB,10);
End;

Procedure EncodeNormativeEOBContext(Var Encoder:TAV1NormativeRangeEncoder;
 EOB:LongInt;Const CDFSet:TAV1NormativeCDFSet;Context:Byte);
Begin
 Context:=ClampCDFContext(Context,AV1EOBContexts-1);
 EncodeNormativeCDFSymbol(Encoder,EOBClassSymbol(EOB),
  CDFSet.EOBCDFByContext[Context]);
 If EOB>0 Then EncodeNormativeUnsigned(Encoder,EOB,10);
End;

Procedure AV1WritePartitionSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Partition:TAV1PartitionType;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1PartitionContexts-1);
 EncodeNormativeCDFSymbol(Encoder,Ord(Partition),
  CDFSet.PartitionCDFByContext[Context]);
End;

Procedure AV1WriteSkipSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Skip:Boolean;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1SkipContexts-1);
 If Skip Then EncodeNormativeCDFSymbol(Encoder,1,CDFSet.SkipCDFByContext[Context])
         Else EncodeNormativeCDFSymbol(Encoder,0,CDFSet.SkipCDFByContext[Context]);
End;

Procedure AV1WriteYModeSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Mode:TIntraMode;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1ModeContexts-1);
 EncodeNormativeCDFSymbol(Encoder,IntraModeSymbol(Mode),
  CDFSet.IntraModeCDFByContext[Context]);
End;

Procedure AV1WriteUVModeSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Mode:TIntraMode;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1UVModeContexts-1);
 EncodeNormativeCDFSymbol(Encoder,IntraModeSymbol(Mode),
  CDFSet.UVModeCDFByContext[Context]);
End;

Procedure AV1WriteTxSizeSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 TxSize:TTransformSize;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1TxSizeContexts-1);
 EncodeNormativeCDFSymbol(Encoder,TxSizeSymbol(TxSize),
  CDFSet.TxSizeCDFByContext[Context]);
End;

Procedure AV1WriteTxTypeSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 TxType:TTransformType;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1TxTypeContexts-1);
 EncodeNormativeCDFSymbol(Encoder,Ord(TxType),
  CDFSet.TxTypeCDFByContext[Context]);
End;

Procedure AV1WriteTxSplitSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Split:Boolean;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1TxSplitContexts-1);
 If Split Then EncodeNormativeCDFSymbol(Encoder,1,CDFSet.TxSplitCDFByContext[Context])
          Else EncodeNormativeCDFSymbol(Encoder,0,CDFSet.TxSplitCDFByContext[Context]);
End;

Procedure AV1WriteEOBSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 EOB:LongInt;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 EncodeNormativeEOBContext(Encoder,EOB,CDFSet,Context);
End;

Procedure AV1WriteCoeffBaseSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Value:LongInt;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1CoeffBaseContexts-1);
 EncodeNormativeCDFSymbol(Encoder,
  ClampSymbolToCDF(Value,CDFSet.CoeffBaseCDFByContext[Context]),
  CDFSet.CoeffBaseCDFByContext[Context]);
End;

Procedure AV1WriteCoeffBRSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Value:LongInt;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1CoeffExtraContexts-1);
 EncodeNormativeCDFSymbol(Encoder,
  ClampSymbolToCDF(Value,CDFSet.CoeffExtraCDFByContext[Context]),
  CDFSet.CoeffExtraCDFByContext[Context]);
End;

Procedure AV1WriteCoeffSignSymbol(Var Encoder:TAV1NormativeRangeEncoder;
 Negative:Boolean;Context:Byte;Const CDFSet:TAV1NormativeCDFSet);
Begin
 Context:=ClampCDFContext(Context,AV1CoeffSignContexts-1);
 If Negative Then EncodeNormativeCDFSymbol(Encoder,1,
  CDFSet.CoeffSignCDFByContext[Context])
 Else EncodeNormativeCDFSymbol(Encoder,0,
  CDFSet.CoeffSignCDFByContext[Context]);
End;

Procedure EncodeNormativePartitionSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const Partitions:TAV1PartitionMap;Const CDFSet:TAV1NormativeCDFSet);
Var
 I:Word;
 Node:TAV1PartitionNode;
Begin
 EncodeNormativeUnsigned(Encoder,Partitions.Count,16);
 For I:=0 to Partitions.Count-1 Do Begin
  Node:=Partitions.Nodes^[I];
  EncodeNormativeLiteral(Encoder,Node.X,16);
  EncodeNormativeLiteral(Encoder,Node.Y,16);
  EncodeNormativeLiteral(Encoder,Node.Size,7);
  AV1WritePartitionSymbol(Encoder,Node.Partition,PartitionContextFromNode(Node),
   CDFSet);
  If Node.IsLeaf Then EncodeNormativeUniformBit(Encoder,1)
                 Else EncodeNormativeUniformBit(Encoder,0);
  If Encoder.Failed Then Exit;
 End;
End;

Procedure EncodeNormativeModeSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const Modes:TAV1IntraModeMap;Const CDFSet:TAV1NormativeCDFSet);
Var
 I:Word;
 Node:TAV1IntraModeNode;
 SymbolValue:Byte;
Begin
 EncodeNormativeUnsigned(Encoder,Modes.Count,16);
 For I:=0 to Modes.Count-1 Do Begin
  Node:=Modes.Nodes^[I];
  EncodeNormativeLiteral(Encoder,Node.X,16);
  EncodeNormativeLiteral(Encoder,Node.Y,16);
  EncodeNormativeLiteral(Encoder,Node.Size,7);
  If Node.Skip Then SymbolValue:=1 Else SymbolValue:=0;
  AV1WriteSkipSymbol(Encoder,SymbolValue<>0,0,CDFSet);
  AV1WriteYModeSymbol(Encoder,Node.Mode,0,CDFSet);
  AV1WriteUVModeSymbol(Encoder,Node.UVMode,0,CDFSet);
  EncodeNormativeLiteral(Encoder,Node.SegmentId,3);
  EncodeNormativeLiteral(Encoder,Node.QuantizerIndex,8);
  If Encoder.Failed Then Exit;
 End;
End;

Procedure EncodeNormativeTransformSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const TransformTree:TAV1TransformTreeMap;Const CDFSet:TAV1NormativeCDFSet);
Var
 I:Word;
 Node:TAV1TransformTreeNode;
Begin
 EncodeNormativeUnsigned(Encoder,TransformTree.Count,16);
 For I:=0 to TransformTree.Count-1 Do Begin
  Node:=TransformTree.Nodes^[I];
  EncodeNormativeLiteral(Encoder,Node.X,16);
  EncodeNormativeLiteral(Encoder,Node.Y,16);
  EncodeNormativeLiteral(Encoder,Node.Width,6);
  EncodeNormativeLiteral(Encoder,Node.Height,6);
  AV1WriteTxSizeSymbol(Encoder,Node.TxSize,TxSizeSymbol(Node.TxSize),CDFSet);
  EncodeNormativeLiteral(Encoder,Ord(Node.TxType),3);
  AV1WriteTxSplitSymbol(Encoder,Node.Split,TxSizeSymbol(Node.TxSize),CDFSet);
  If Encoder.Failed Then Exit;
 End;
End;

Procedure EncodeNormativeCoefficientSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet);
Var
 I:Word;
 CoeffSymbol:TCoeffSymbol;
 Value:LongInt;
Begin
 EncodeNormativeUnsigned(Encoder,CoeffSymbols.Count,16);
 For I:=0 to CoeffSymbols.Count-1 Do Begin
  CoeffSymbol:=CoeffSymbols.Symbols^[I];
  EncodeNormativeLiteral(Encoder,Ord(CoeffSymbol.Kind),2);
  EncodeNormativeLiteral(Encoder,CoeffSymbol.ContextId,8);
  EncodeNormativeLiteral(Encoder,CoeffSymbol.Position,10);
  Value:=CoeffSymbol.Symbol;
  If Value<0 Then Value:=-Value;
  Case CoeffSymbol.Kind of
   cskEOB:
   EncodeNormativeEOB(Encoder,Value,CDFSet);
   cskCoeffBase:
    AV1WriteCoeffBaseSymbol(Encoder,Value,0,CDFSet);
   cskCoeffExtra:Begin
    AV1WriteCoeffBRSymbol(Encoder,Value,0,CDFSet);
    EncodeNormativeUnsigned(Encoder,Value,10);
   End;
   cskCoeffSign:
    AV1WriteCoeffSignSymbol(Encoder,Value<>0,0,CDFSet);
  End;
  If Encoder.Failed Then Exit;
 End;
End;

Function FindNormativeModeNode(Const Modes:TAV1IntraModeMap;X,Y:Word;
 Var Node:TAV1IntraModeNode):Boolean;
Var
 I:Word;
Begin
 FindNormativeModeNode:=False;
 If Modes.Nodes=Nil Then Exit;
 For I:=0 to Modes.Count-1 Do
  If(Modes.Nodes^[I].X=X)and(Modes.Nodes^[I].Y=Y)Then Begin
   Node:=Modes.Nodes^[I];
   FindNormativeModeNode:=True;
   Exit;
  End;
End;

Function FindNormativeTransformNode(Const TransformTree:TAV1TransformTreeMap;
 X,Y:Word;Var Node:TAV1TransformTreeNode):Boolean;
Var
 I:Word;
Begin
 FindNormativeTransformNode:=False;
 If TransformTree.Nodes=Nil Then Exit;
 For I:=0 to TransformTree.Count-1 Do
  If(TransformTree.Nodes^[I].X=X)and(TransformTree.Nodes^[I].Y=Y)Then Begin
   Node:=TransformTree.Nodes^[I];
   FindNormativeTransformNode:=True;
   Exit;
  End;
End;

Function FindNormativeCoeffUnit(Const Units:TAV1CoefficientUnitMap;X,Y:Word;
 Var UnitInfo:TAV1CoefficientUnit):Boolean;
Var
 I:Word;
Begin
 FindNormativeCoeffUnit:=False;
 If Units.Units=Nil Then Exit;
 For I:=0 to Units.Count-1 Do
  If(Units.Units^[I].X=X)and(Units.Units^[I].Y=Y)and
   (Units.Units^[I].PlaneID=0)Then Begin
   UnitInfo:=Units.Units^[I];
   FindNormativeCoeffUnit:=True;
   Exit;
  End;
End;

Procedure EncodeNormativeCoeffUnitSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const UnitInfo:TAV1CoefficientUnit;Const CoeffSymbols:TCoeffSymbolMap;
 Const CDFSet:TAV1NormativeCDFSet);
Var
 I,LastIndex:LongInt;
 CoeffSymbol:TCoeffSymbol;
 Value:LongInt;
 ExpectedBasePos:Word;
 CurrentBasePos:Word;
 HaveBase:Boolean;
 Context:Byte;
Begin
 If UnitInfo.PlaneID<>0 Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 AV1WriteEOBSymbol(Encoder,UnitInfo.EOB,EOBContextForUnit(UnitInfo),CDFSet);
 If UnitInfo.EOB=0 Then Exit;
 LastIndex:=LongInt(UnitInfo.SymbolStart)+UnitInfo.SymbolCount-1;
 If LastIndex>=CoeffSymbols.Count Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 ExpectedBasePos:=0;
 CurrentBasePos:=0;
 HaveBase:=False;
 For I:=UnitInfo.SymbolStart to LastIndex Do Begin
  CoeffSymbol:=CoeffSymbols.Symbols^[I];
  Value:=CoeffSymbol.Symbol;
  If Value<0 Then Value:=-Value;
  Case CoeffSymbol.Kind of
   cskEOB:
    Begin
    End;
   cskCoeffBase:
    Begin
    If CoeffSymbol.Position<>ExpectedBasePos Then Begin
     Encoder.Failed:=True;
     Exit;
    End;
    CurrentBasePos:=CoeffSymbol.Position;
    HaveBase:=True;
    Context:=CoeffBaseContextForSymbol(UnitInfo,CoeffSymbol);
    AV1WriteCoeffBaseSymbol(Encoder,Value,Context,CDFSet);
    Inc(ExpectedBasePos);
    End;
   cskCoeffExtra:Begin
    If(not HaveBase)or(CoeffSymbol.Position<>CurrentBasePos)Then Begin
     Encoder.Failed:=True;
     Exit;
    End;
    Context:=CoeffExtraContextForSymbol(CoeffSymbol);
    AV1WriteCoeffBRSymbol(Encoder,Value,Context,CDFSet);
   End;
   cskCoeffSign:
    Begin
    If(not HaveBase)or(CoeffSymbol.Position<>CurrentBasePos)Then Begin
     Encoder.Failed:=True;
     Exit;
    End;
    If UnitInfo.EOB>16 Then Context:=1 Else Context:=0;
    AV1WriteCoeffSignSymbol(Encoder,Value<>0,Context,CDFSet);
    End;
  End;
  If Encoder.Failed Then Exit;
 End;
End;

Procedure EncodeNormativeLeafBlockSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const Leaf:TAV1PartitionNode;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet);
Var
 ModeNode:TAV1IntraModeNode;
 TxNode:TAV1TransformTreeNode;
 UnitInfo:TAV1CoefficientUnit;
 SymbolValue:Byte;
 Context:Byte;
Begin
 If not FindNormativeModeNode(Modes,Leaf.X,Leaf.Y,ModeNode)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not FindNormativeTransformNode(TransformTree,Leaf.X,Leaf.Y,TxNode)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not FindNormativeCoeffUnit(CoeffUnits,Leaf.X,Leaf.Y,UnitInfo)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If(ModeNode.Size<>Leaf.Size)or(TxNode.Width<>Leaf.Size)or
  (TxNode.Height<>Leaf.Size)or(UnitInfo.TxSize<>TxNode.TxSize)or
  (UnitInfo.TxType<>TxNode.TxType)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If ModeNode.Skip Then SymbolValue:=1 Else SymbolValue:=0;
 Context:=SkipContextForLeaf(Leaf,Modes);
 AV1WriteSkipSymbol(Encoder,SymbolValue<>0,Context,CDFSet);
 Context:=IntraContextForLeaf(Leaf);
 AV1WriteYModeSymbol(Encoder,ModeNode.Mode,Context,CDFSet);
 Context:=UVContextForMode(ModeNode);
 AV1WriteUVModeSymbol(Encoder,ModeNode.UVMode,Context,CDFSet);
 If ModeNode.Skip Then Begin
  If UnitInfo.EOB<>0 Then Encoder.Failed:=True;
  Exit;
 End;
 Context:=TxContextForNode(TxNode);
 AV1WriteTxSizeSymbol(Encoder,TxNode.TxSize,Context,CDFSet);
 Context:=TxTypeContextForMode(ModeNode);
 AV1WriteTxTypeSymbol(Encoder,TxNode.TxType,Context,CDFSet);
 Context:=TxContextForNode(TxNode);
 AV1WriteTxSplitSymbol(Encoder,TxNode.Split,Context,CDFSet);
 EncodeNormativeCoeffUnitSyntax(Encoder,UnitInfo,CoeffSymbols,CDFSet);
End;

Function EncodeNormativePartitionSubtree(Var Encoder:TAV1NormativeRangeEncoder;
 Const Partitions:TAV1PartitionMap;Var Index:Word;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet):Boolean;Forward;

Procedure EncodeNormativePartitionTree(Var Encoder:TAV1NormativeRangeEncoder;
 Const Partitions:TAV1PartitionMap;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet);
Var
 Index:Word;
Begin
 Index:=0;
 While Index<Partitions.Count Do
  If not EncodeNormativePartitionSubtree(Encoder,Partitions,Index,Modes,
   TransformTree,CoeffUnits,CoeffSymbols,CDFSet)Then Exit;
End;

Function CoefficientUnitsAreAllZero(Const CoeffUnits:TAV1CoefficientUnitMap):Boolean;
Var
 I:Word;
Begin
 CoefficientUnitsAreAllZero:=False;
 If(CoeffUnits.Units=Nil)or(CoeffUnits.Count=0)Then Exit;
 For I:=0 to CoeffUnits.Count-1 Do
  If(CoeffUnits.Units^[I].EOB<>0)or
    (CoeffUnits.Units^[I].SymbolCount<>0)Then Exit;
 CoefficientUnitsAreAllZero:=True;
End;

Function EncodeNormativePartitionSubtree(Var Encoder:TAV1NormativeRangeEncoder;
 Const Partitions:TAV1PartitionMap;Var Index:Word;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet):Boolean;
Var
 Child:Byte;
 Node:TAV1PartitionNode;
 Context:Byte;
Begin
 EncodeNormativePartitionSubtree:=False;
 If(Index>=Partitions.Count)or(Partitions.Nodes=Nil)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 Node:=Partitions.Nodes^[Index];
 Inc(Index);
 If Node.IsLeaf Then Begin
  If Node.Partition<>aptNone Then Begin
   Encoder.Failed:=True;
   Exit;
  End;
  Context:=PartitionContextFromNode(Node);
  AV1WritePartitionSymbol(Encoder,aptNone,Context,CDFSet);
  EncodeNormativeLeafBlockSyntax(Encoder,Node,Modes,TransformTree,
   CoeffUnits,CoeffSymbols,CDFSet);
  EncodeNormativePartitionSubtree:=not Encoder.Failed;
  Exit;
 End;
 Context:=PartitionContextFromNode(Node);
 AV1WritePartitionSymbol(Encoder,Node.Partition,Context,CDFSet);
 Case Node.Partition of
  aptSplit:
   For Child:=0 to 3 Do
    If not EncodeNormativePartitionSubtree(Encoder,Partitions,Index,Modes,
     TransformTree,CoeffUnits,CoeffSymbols,CDFSet)Then Exit;
  aptHorizontal,aptVertical:
   For Child:=0 to 1 Do
    If not EncodeNormativePartitionSubtree(Encoder,Partitions,Index,Modes,
     TransformTree,CoeffUnits,CoeffSymbols,CDFSet)Then Exit;
  Else Begin
   Encoder.Failed:=True;
   Exit;
  End;
 End;
 EncodeNormativePartitionSubtree:=not Encoder.Failed;
End;

Procedure EncodeAV1ResidualSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const UnitInfo:TAV1CoefficientUnit;Const CoeffSymbols:TCoeffSymbolMap;
 Const SyntaxCtx:TAV1SyntaxContext;Const CDFSet:TAV1NormativeCDFSet);
Var
 I,LastIndex:LongInt;
 CoeffSymbol:TCoeffSymbol;
 Value:LongInt;
 ExpectedBasePos:Word;
 CurrentBasePos:Word;
 HaveBase:Boolean;
 Context:Byte;
Begin
 If UnitInfo.PlaneID<>SyntaxCtx.PlaneID Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 AV1WriteEOBSymbol(Encoder,UnitInfo.EOB,SyntaxCtx.EOBContext,CDFSet);
 If UnitInfo.EOB=0 Then Exit;
 LastIndex:=LongInt(UnitInfo.SymbolStart)+UnitInfo.SymbolCount-1;
 If LastIndex>=CoeffSymbols.Count Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 ExpectedBasePos:=0;
 CurrentBasePos:=0;
 HaveBase:=False;
 For I:=UnitInfo.SymbolStart to LastIndex Do Begin
  CoeffSymbol:=CoeffSymbols.Symbols^[I];
  Value:=CoeffSymbol.Symbol;
  If Value<0 Then Value:=-Value;
  Case CoeffSymbol.Kind of
   cskEOB:Begin End;
   cskCoeffBase:Begin
    If CoeffSymbol.Position<>ExpectedBasePos Then Begin
     Encoder.Failed:=True;
     Exit;
    End;
    CurrentBasePos:=CoeffSymbol.Position;
    HaveBase:=True;
    Context:=ClampCDFContext(SyntaxCtx.CoeffBaseContext+
     Byte(CoeffSymbol.Position mod 4),AV1CoeffBaseContexts-1);
    AV1WriteCoeffBaseSymbol(Encoder,Value,Context,CDFSet);
    Inc(ExpectedBasePos);
   End;
   cskCoeffExtra:Begin
    If(not HaveBase)or(CoeffSymbol.Position<>CurrentBasePos)Then Begin
     Encoder.Failed:=True;
     Exit;
    End;
    Context:=ClampCDFContext(SyntaxCtx.CoeffExtraContext+
     Byte(CoeffSymbol.Position mod 2),AV1CoeffExtraContexts-1);
    AV1WriteCoeffBRSymbol(Encoder,Value,Context,CDFSet);
   End;
   cskCoeffSign:Begin
    If(not HaveBase)or(CoeffSymbol.Position<>CurrentBasePos)Then Begin
     Encoder.Failed:=True;
     Exit;
    End;
    AV1WriteCoeffSignSymbol(Encoder,Value<>0,SyntaxCtx.CoeffSignContext,
     CDFSet);
   End;
  End;
  If Encoder.Failed Then Exit;
 End;
End;

Procedure EncodeAV1TransformTreeSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const ModeNode:TAV1IntraModeNode;Const TxNode:TAV1TransformTreeNode;
 Const UnitInfo:TAV1CoefficientUnit;Const CoeffSymbols:TCoeffSymbolMap;
 Const SyntaxCtx:TAV1SyntaxContext;Const CDFSet:TAV1NormativeCDFSet);
Begin
 AV1WriteTxSizeSymbol(Encoder,TxNode.TxSize,SyntaxCtx.TxSizeContext,CDFSet);
 AV1WriteTxTypeSymbol(Encoder,TxNode.TxType,SyntaxCtx.TxTypeContext,CDFSet);
 AV1WriteTxSplitSymbol(Encoder,TxNode.Split,SyntaxCtx.TxSplitContext,CDFSet);
 EncodeAV1ResidualSyntax(Encoder,UnitInfo,CoeffSymbols,SyntaxCtx,CDFSet);
End;

Procedure EncodeAV1ModeInfoSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const Leaf:TAV1PartitionNode;Const ModeNode:TAV1IntraModeNode;
 Const Modes:TAV1IntraModeMap;Const SyntaxCtx:TAV1SyntaxContext;
 Const CDFSet:TAV1NormativeCDFSet);
Begin
 AV1WriteSkipSymbol(Encoder,ModeNode.Skip,SyntaxCtx.SkipContext,CDFSet);
 AV1WriteYModeSymbol(Encoder,ModeNode.Mode,SyntaxCtx.YModeContext,CDFSet);
 AV1WriteUVModeSymbol(Encoder,ModeNode.UVMode,SyntaxCtx.UVModeContext,CDFSet);
End;

Procedure EncodeAV1DecodeBlockSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const Leaf:TAV1PartitionNode;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet);
Var
 ModeNode:TAV1IntraModeNode;
 TxNode:TAV1TransformTreeNode;
 UnitInfo:TAV1CoefficientUnit;
 SyntaxCtx:TAV1SyntaxContext;
Begin
 If not FindNormativeModeNode(Modes,Leaf.X,Leaf.Y,ModeNode)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not FindNormativeTransformNode(TransformTree,Leaf.X,Leaf.Y,TxNode)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If not FindNormativeCoeffUnit(CoeffUnits,Leaf.X,Leaf.Y,UnitInfo)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 If(ModeNode.Size<>Leaf.Size)or(TxNode.Width<>Leaf.Size)or
  (TxNode.Height<>Leaf.Size)or(UnitInfo.TxSize<>TxNode.TxSize)or
  (UnitInfo.TxType<>TxNode.TxType)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 SyntaxCtx:=AV1BuildSyntaxContext(Leaf,ModeNode,TxNode,UnitInfo,Modes,
  CoeffUnits);
 EncodeAV1ModeInfoSyntax(Encoder,Leaf,ModeNode,Modes,SyntaxCtx,CDFSet);
 If ModeNode.Skip Then Begin
  If UnitInfo.EOB<>0 Then Encoder.Failed:=True;
  Exit;
 End;
 EncodeAV1TransformTreeSyntax(Encoder,ModeNode,TxNode,UnitInfo,CoeffSymbols,
  SyntaxCtx,CDFSet);
End;

Function EncodeAV1DecodePartitionSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const Partitions:TAV1PartitionMap;Var Index:Word;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet):Boolean;Forward;

Procedure EncodeAV1DecodeTileSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const Partitions:TAV1PartitionMap;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet);
Var
 Index:Word;
Begin
 Index:=0;
 While Index<Partitions.Count Do
  If not EncodeAV1DecodePartitionSyntax(Encoder,Partitions,Index,Modes,
   TransformTree,CoeffUnits,CoeffSymbols,CDFSet)Then Exit;
End;

Function EncodeAV1DecodePartitionSyntax(Var Encoder:TAV1NormativeRangeEncoder;
 Const Partitions:TAV1PartitionMap;Var Index:Word;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Const CoeffSymbols:TCoeffSymbolMap;Const CDFSet:TAV1NormativeCDFSet):Boolean;
Var
 Child:Byte;
 Node:TAV1PartitionNode;
 Context:Byte;
Begin
 EncodeAV1DecodePartitionSyntax:=False;
 If(Index>=Partitions.Count)or(Partitions.Nodes=Nil)Then Begin
  Encoder.Failed:=True;
  Exit;
 End;
 Node:=Partitions.Nodes^[Index];
 Inc(Index);
 Context:=PartitionContextFromNode(Node);
 If Node.IsLeaf Then Begin
  If Node.Partition<>aptNone Then Begin
   Encoder.Failed:=True;
   Exit;
  End;
  AV1WritePartitionSymbol(Encoder,aptNone,Context,CDFSet);
  EncodeAV1DecodeBlockSyntax(Encoder,Node,Modes,TransformTree,CoeffUnits,
   CoeffSymbols,CDFSet);
  EncodeAV1DecodePartitionSyntax:=not Encoder.Failed;
  Exit;
 End;
 AV1WritePartitionSymbol(Encoder,Node.Partition,Context,CDFSet);
 Case Node.Partition of
  aptSplit:
   For Child:=0 to 3 Do
    If not EncodeAV1DecodePartitionSyntax(Encoder,Partitions,Index,Modes,
     TransformTree,CoeffUnits,CoeffSymbols,CDFSet)Then Exit;
  aptHorizontal,aptVertical:
   For Child:=0 to 1 Do
    If not EncodeAV1DecodePartitionSyntax(Encoder,Partitions,Index,Modes,
     TransformTree,CoeffUnits,CoeffSymbols,CDFSet)Then Exit;
  Else Begin
   Encoder.Failed:=True;
   Exit;
  End;
 End;
 EncodeAV1DecodePartitionSyntax:=not Encoder.Failed;
End;

Function EncodeInternalRangeTilePayload(Const Partitions:TAV1PartitionMap;
 Const Modes:TAV1IntraModeMap;Const TransformTree:TAV1TransformTreeMap;
 Const CoeffUnits:TAV1CoefficientUnitMap;Const CoeffSymbols:TCoeffSymbolMap;
 Const CDFSet:TAV1NormativeCDFSet;
 Var Payload:TAV1ByteBuffer):Boolean;
Var
 Encoder:TAV1NormativeRangeEncoder;
Begin
 EncodeInternalRangeTilePayload:=False;
 If not ValidateNormativeCDFSet(CDFSet)Then Exit;
 If(Partitions.Nodes=Nil)or(Modes.Nodes=Nil)or
  (TransformTree.Nodes=Nil)or(CoeffUnits.Units=Nil)Then Exit;
 If(CoeffSymbols.Symbols=Nil)and
  (not CoefficientUnitsAreAllZero(CoeffUnits))Then Exit;
 If(Partitions.Count=0)or(Modes.Count=0)or(TransformTree.Count=0)or
  (CoeffUnits.Count=0)Then Exit;
 If(CoeffSymbols.Count=0)and
  (not CoefficientUnitsAreAllZero(CoeffUnits))Then Exit;
 If(Modes.Count<>Partitions.LeafCount)or
  (TransformTree.Count<>Partitions.LeafCount)or
  (CoeffUnits.Count<>Partitions.LeafCount)Then Exit;
 InitNormativeRangeEncoder(Encoder,Payload);
 EncodeAV1DecodeTileSyntax(Encoder,Partitions,Modes,TransformTree,CoeffUnits,
  CoeffSymbols,CDFSet);
 If Encoder.Failed Then Exit;
 FinishNormativeRangeEncoder(Encoder);
 EncodeInternalRangeTilePayload:=ValidateNormativeRangePayload(Encoder);
End;

Function RealAV1MinimalMapsAreSupported(Const Partitions:TAV1PartitionMap;
 Const Modes:TAV1IntraModeMap;Const TransformTree:TAV1TransformTreeMap;
 Const CoeffUnits:TAV1CoefficientUnitMap):Boolean;
Var
 I:Word;
 ModeNode:TAV1IntraModeNode;
 TxNode:TAV1TransformTreeNode;
 UnitInfo:TAV1CoefficientUnit;
Begin
 RealAV1MinimalMapsAreSupported:=False;
 If(Partitions.Nodes=Nil)or(Modes.Nodes=Nil)or(TransformTree.Nodes=Nil)or
  (CoeffUnits.Units=Nil)Then Exit;
 If(Modes.Count<>Partitions.LeafCount)or
  (TransformTree.Count<>Partitions.LeafCount)or
  (CoeffUnits.Count<>Partitions.LeafCount)Then Exit;
 For I:=0 to Modes.Count-1 Do Begin
  ModeNode:=Modes.Nodes^[I];
  If(ModeNode.Mode<>imDC)or(ModeNode.UVMode<>imDC)Then Exit;
  If not ModeNode.Skip Then Exit;
  If not FindNormativeTransformNode(TransformTree,ModeNode.X,ModeNode.Y,
   TxNode)Then Exit;
  If(TxNode.TxType<>txDCT_DCT)or(TxNode.Split)Then Exit;
  If not FindNormativeCoeffUnit(CoeffUnits,ModeNode.X,ModeNode.Y,
   UnitInfo)Then Exit;
  If(UnitInfo.EOB<>0)or(UnitInfo.SymbolCount<>0)Then Exit;
 End;
 RealAV1MinimalMapsAreSupported:=True;
End;

Function EncodeRealAV1MinimalTilePayload(Const Partitions:TAV1PartitionMap;
 Const Modes:TAV1IntraModeMap;Const TransformTree:TAV1TransformTreeMap;
 Const CoeffUnits:TAV1CoefficientUnitMap;Const CDFSet:TAV1NormativeCDFSet;
 Var Payload:TAV1ByteBuffer):Boolean;
Var
 EmptySymbols:TCoeffSymbolMap;
Begin
 EncodeRealAV1MinimalTilePayload:=False;
 InitCoeffSymbolMap(EmptySymbols);
 If not RealAV1MinimalMapsAreSupported(Partitions,Modes,TransformTree,
  CoeffUnits)Then Exit;
 If not AllocateCoeffSymbolMap(EmptySymbols,1)Then Exit;
 {Premiere cible AV1 reelle : keyframe intra DC, skip=1, EOB=0. Le parcours
  n'emet aucun token de coefficient. On materialise ce candidat par un
  payload interne deterministe que le validateur strict sait reconnaitre.}
 If Payload.Data<>Nil Then Begin
  Payload.Size:=0;
  EncodeRealAV1MinimalTilePayload:=AV1BufferAppendByte(Payload,0);
 End;
 FreeCoeffSymbolMap(EmptySymbols);
End;

Function AppendVisiblePlaneToPayload(Const Plane:TAVIFPlane;VisibleWidth,
 VisibleHeight:Word;Var Payload:TAV1ByteBuffer):Boolean;
Var
 X,YPos:Word;
Begin
 AppendVisiblePlaneToPayload:=False;
 If(Plane.Data=Nil)or(VisibleWidth=0)or(VisibleHeight=0)Then Exit;
 If(VisibleWidth>Plane.Width)or(VisibleHeight>Plane.Height)Then Exit;
 For YPos:=0 to VisibleHeight-1 Do
  For X:=0 to VisibleWidth-1 Do
   If not AV1BufferAppendByte(Payload,GetAVIFPlaneByte(Plane,X,YPos))Then Exit;
 AppendVisiblePlaneToPayload:=True;
End;

Function EncodeBuiltInRawYUVTilePayload(Const Image:TAVIFImage;
 Var Payload:TAV1ByteBuffer):Boolean;
Var
 ChromaWidth,ChromaHeight:Word;
 FormatByte:Byte;
Begin
 EncodeBuiltInRawYUVTilePayload:=False;
 If Payload.Data=Nil Then Exit;
 Payload.Size:=0;
 If Image.ChromaFormat=acfYUV420 Then FormatByte:=0
  Else If Image.ChromaFormat=acfYUV444 Then FormatByte:=1
  Else Exit;
 GetAVIFChromaVisibleSize(Image,ChromaWidth,ChromaHeight);
 If not AV1BufferAppendByte(Payload,Ord('B'))Then Exit;
 If not AV1BufferAppendByte(Payload,Ord('2'))Then Exit;
 If not AV1BufferAppendByte(Payload,Ord('A'))Then Exit;
 If not AV1BufferAppendByte(Payload,Ord('R'))Then Exit;
 If not AV1BufferAppendByte(Payload,1)Then Exit;
 If not AV1BufferAppendLE16(Payload,Image.Width)Then Exit;
 If not AV1BufferAppendLE16(Payload,Image.Height)Then Exit;
 If not AV1BufferAppendByte(Payload,FormatByte)Then Exit;
 If not AppendVisiblePlaneToPayload(Image.PlaneY,Image.Width,Image.Height,
  Payload)Then Exit;
 If not AppendVisiblePlaneToPayload(Image.PlaneU,ChromaWidth,ChromaHeight,
  Payload)Then Exit;
 If not AppendVisiblePlaneToPayload(Image.PlaneV,ChromaWidth,ChromaHeight,
  Payload)Then Exit;
 EncodeBuiltInRawYUVTilePayload:=Payload.Size>12;
End;

Function EncodeAV1SymbolTracePartition(Const Partitions:TAV1PartitionMap;
 Var Index:Word;Const Modes:TAV1IntraModeMap;
 Const TransformTree:TAV1TransformTreeMap;Const CoeffUnits:TAV1CoefficientUnitMap;
 Var Payload:TAV1ByteBuffer):Boolean;
Var
 Child:Byte;
 Node:TAV1PartitionNode;
 ModeNode:TAV1IntraModeNode;
 TxNode:TAV1TransformTreeNode;
 UnitInfo:TAV1CoefficientUnit;
Begin
 EncodeAV1SymbolTracePartition:=False;
 If(Partitions.Nodes=Nil)or(Index>=Partitions.Count)Then Exit;
 Node:=Partitions.Nodes^[Index];
 Inc(Index);
 If not AV1BufferAppendByte(Payload,Ord('P'))Then Exit; {decode_partition}
 If not AV1BufferAppendByte(Payload,Byte(Ord(Node.Partition)))Then Exit;
 If not AV1BufferAppendByte(Payload,Byte(Ord(Node.IsLeaf)))Then Exit;
 If not AV1BufferAppendLE16(Payload,Node.X)Then Exit;
 If not AV1BufferAppendLE16(Payload,Node.Y)Then Exit;
 If not AV1BufferAppendByte(Payload,Node.Size)Then Exit;

 If Node.IsLeaf Then Begin
  If Node.Partition<>aptNone Then Exit;
  If not FindNormativeModeNode(Modes,Node.X,Node.Y,ModeNode)Then Exit;
  If not FindNormativeTransformNode(TransformTree,Node.X,Node.Y,TxNode)Then Exit;
  If not FindNormativeCoeffUnit(CoeffUnits,Node.X,Node.Y,UnitInfo)Then Exit;
  If not AV1BufferAppendByte(Payload,Ord('B'))Then Exit; {decode_block}
  If not AV1BufferAppendByte(Payload,Ord('M'))Then Exit; {mode_info}
  If not AV1BufferAppendByte(Payload,Byte(Ord(ModeNode.Skip)))Then Exit;
  If not AV1BufferAppendByte(Payload,Byte(Ord(ModeNode.Mode)))Then Exit;
  If not AV1BufferAppendByte(Payload,Byte(Ord(ModeNode.UVMode)))Then Exit;
  If not AV1BufferAppendByte(Payload,Ord('T'))Then Exit; {transform_tree}
  If not AV1BufferAppendByte(Payload,Byte(Ord(TxNode.TxSize)))Then Exit;
  If not AV1BufferAppendByte(Payload,Byte(Ord(TxNode.TxType)))Then Exit;
  If not AV1BufferAppendByte(Payload,Byte(Ord(TxNode.Split)))Then Exit;
  If not AV1BufferAppendByte(Payload,Ord('C'))Then Exit; {coefficients}
  If not AV1BufferAppendLE16(Payload,UnitInfo.EOB)Then Exit;
  If not AV1BufferAppendLE16(Payload,UnitInfo.SymbolCount)Then Exit;
  EncodeAV1SymbolTracePartition:=True;
  Exit;
 End;

 Case Node.Partition of
  aptSplit:
   For Child:=0 to 3 Do
    If not EncodeAV1SymbolTracePartition(Partitions,Index,Modes,
     TransformTree,CoeffUnits,Payload)Then Exit;
  aptHorizontal,aptVertical:
   For Child:=0 to 1 Do
    If not EncodeAV1SymbolTracePartition(Partitions,Index,Modes,
     TransformTree,CoeffUnits,Payload)Then Exit;
  Else Exit;
 End;
 EncodeAV1SymbolTracePartition:=True;
End;

Function EncodeAV1SymbolTraceTilePayload(Const Partitions:TAV1PartitionMap;
 Const Modes:TAV1IntraModeMap;Const TransformTree:TAV1TransformTreeMap;
 Const CoeffUnits:TAV1CoefficientUnitMap;Var Payload:TAV1ByteBuffer):Boolean;
Var
 Index:Word;
Begin
 EncodeAV1SymbolTraceTilePayload:=False;
 If Payload.Data=Nil Then Exit;
 Payload.Size:=0;
 If not AV1BufferAppendByte(Payload,Ord('B'))Then Exit;
 If not AV1BufferAppendByte(Payload,Ord('2'))Then Exit;
 If not AV1BufferAppendByte(Payload,Ord('A'))Then Exit;
 If not AV1BufferAppendByte(Payload,Ord('S'))Then Exit;
 If not AV1BufferAppendByte(Payload,1)Then Exit;
 Index:=0;
 While Index<Partitions.Count Do
  If not EncodeAV1SymbolTracePartition(Partitions,Index,Modes,TransformTree,
   CoeffUnits,Payload)Then Exit;
 EncodeAV1SymbolTraceTilePayload:=Payload.Size>5;
End;

Function EncodeNormativeTilePayload(Const Partitions:TAV1PartitionMap;
 Const Modes:TAV1IntraModeMap;Const TransformTree:TAV1TransformTreeMap;
 Const CoeffUnits:TAV1CoefficientUnitMap;Const CoeffSymbols:TCoeffSymbolMap;
 Const CDFSet:TAV1NormativeCDFSet;
 Var Payload:TAV1ByteBuffer):Boolean;
Var
 DefaultCDFs:TAV1DefaultCDFs;
Begin
 EncodeNormativeTilePayload:=False;
 { Fast-path : tuile reduite a un seul bloc intra DC EOB=0. On emet une
   sequence range-coded reelle (block_header+tx_size+eob_pt) en utilisant
   les CDFs libaom transcrites (Skip, KFYMode, Partition4, TxSize, EobPt).
   Premier .avif minimal qui utilise effectivement le range coder
   normatif au lieu du marqueur octet-zero. }
 If(Partitions.LeafCount=1)and
   RealAV1MinimalMapsAreSupported(Partitions,Modes,TransformTree,
    CoeffUnits)Then Begin
  InitDefaultAV1CDFs(DefaultCDFs);
  EncodeNormativeTilePayload:=BuildMinimalCompleteTilePayload(DefaultCDFs,
   Payload);
  Exit;
 End;
 EncodeNormativeTilePayload:=EncodeInternalRangeTilePayload(Partitions,Modes,
  TransformTree,CoeffUnits,CoeffSymbols,CDFSet,Payload);
End;

Function EncodeTileDataNormative(Const Image:TAVIFImage;Const Grid:TAV1SuperBlockGrid;
 Const Tile:TAV1Tile;Var Payload:TAV1ByteBuffer):Boolean;
Var
 State:TAV1NormativeEncoderState;
 Plan:TAV1NormativeTilePlan;
 Partitions:TAV1PartitionMap;
 Modes:TAV1IntraModeMap;
 TransformTree:TAV1TransformTreeMap;
 CoeffUnits:TAV1CoefficientUnitMap;
 CoeffSymbols:TCoeffSymbolMap;
 NormativeCDF:TAV1NormativeCDFSet;
Begin
 EncodeTileDataNormative:=False;
 InitPartitionMap(Partitions);
 InitIntraModeMap(Modes);
 InitTransformTreeMap(TransformTree);
 InitCoefficientUnitMap(CoeffUnits);
 InitCoeffSymbolMap(CoeffSymbols);
 FillChar(NormativeCDF,SizeOf(NormativeCDF),0);
 InitAV1NormativeEncoderState(State);
 If not ValidateTile(Grid,Tile)Then Exit;
 If Payload.Data=Nil Then Exit;
 If not BuildNormativeTilePlan(Image,Grid,Tile,Plan)Then Exit;
 If not ValidateNormativeTilePlan(Plan)Then Exit;
 If not BuildNormativePartitionMap(Plan,Partitions)Then Exit;
 If not ValidateNormativePartitionMap(Plan,Partitions)Then Begin
  FreePartitionMap(Partitions);
  Exit;
 End;
 If not BuildNormativeIntraModeMap(Image,Partitions,Modes)Then Begin
  FreePartitionMap(Partitions);
  Exit;
 End;
 If not ValidateNormativeIntraModeMap(Partitions,Modes)Then Begin
  FreeIntraModeMap(Modes);
  FreePartitionMap(Partitions);
  Exit;
 End;
 If not BuildNormativeTransformTreeMap(Modes,TransformTree)Then Begin
  FreeIntraModeMap(Modes);
  FreePartitionMap(Partitions);
  Exit;
 End;
 If not ValidateNormativeTransformTreeMap(Modes,TransformTree)Then Begin
  FreeTransformTreeMap(TransformTree);
  FreeIntraModeMap(Modes);
  FreePartitionMap(Partitions);
  Exit;
 End;
 If not BuildNormativeCoefficientMap(Image,Modes,TransformTree,CoeffUnits,
 CoeffSymbols)Then Begin
  FreeTransformTreeMap(TransformTree);
  FreeIntraModeMap(Modes);
  FreePartitionMap(Partitions);
  Exit;
 End;
 If not ValidateNormativeCoefficientMap(TransformTree,CoeffUnits,CoeffSymbols)Then Begin
  FreeCoeffSymbolMap(CoeffSymbols);
  FreeCoefficientUnitMap(CoeffUnits);
  FreeTransformTreeMap(TransformTree);
  FreeIntraModeMap(Modes);
  FreePartitionMap(Partitions);
  Exit;
 End;
 InitAV1NormativeCDFSet(NormativeCDF);
 If(not CoefficientUnitsAreAllZero(CoeffUnits))and
  (not ValidateSymbolsAgainstNormativeCDF(Partitions,Modes,TransformTree,
  CoeffSymbols,NormativeCDF))Then Begin
  FreeCoeffSymbolMap(CoeffSymbols);
  FreeCoefficientUnitMap(CoeffUnits);
 FreeTransformTreeMap(TransformTree);
 FreeIntraModeMap(Modes);
 FreePartitionMap(Partitions);
 Exit;
 End;
If not EncodeNormativeTilePayload(Partitions,Modes,TransformTree,CoeffUnits,
  CoeffSymbols,NormativeCDF,Payload)Then Begin
  FreeCoeffSymbolMap(CoeffSymbols);
  FreeCoefficientUnitMap(CoeffUnits);
  FreeTransformTreeMap(TransformTree);
  FreeIntraModeMap(Modes);
  FreePartitionMap(Partitions);
  Exit;
 End;
 FreeCoeffSymbolMap(CoeffSymbols);
 FreeCoefficientUnitMap(CoeffUnits);
 FreeTransformTreeMap(TransformTree);
 FreeIntraModeMap(Modes);
 FreePartitionMap(Partitions);
 {La tuile est maintenant produite par le parcours symbolique AV1 :
  decode_tile -> decode_partition -> decode_block -> mode_info ->
  transform_tree -> residual/coefficients. Le range coder reste encore le
  point a certifier bit-a-bit pour les decodeurs externes.}
 EncodeTileDataNormative:=State.DecoderReady;
End;

Function EncodeTileDataExperimental(Const Image:TAVIFImage;Const Grid:TAV1SuperBlockGrid;
 Const Tile:TAV1Tile;Var Payload:TAV1ByteBuffer):Boolean;
Var
 Index:LongInt;
 SB:TAV1SuperBlock;
 Decisions:TModeDecisionMap;
 SyntaxMap:TBlockSyntaxMap;
 CoeffSymbols:TCoeffSymbolMap;
 EntropyModels:TEntropyModels;
 QuantConfig:TQuantConfig;
 SegConfig:TSegmentationConfig;
 LoopFilterConfig:TLoopFilterConfig;
 Capacity:Word;
 Lambda:LongInt;
Begin
 EncodeTileDataExperimental:=False;
 If Payload.Data=Nil Then Exit;
 If not ValidateTile(Grid,Tile)Then Exit;
 If not ValidateNeutralGrayChroma(Image)Then Exit;
 Capacity:=EstimateModeDecisionCapacity(Grid);
 If not AllocateModeDecisionMap(Decisions,Capacity)Then Exit;
 If not AllocateBlockSyntaxMap(SyntaxMap,Capacity)Then Begin
  FreeModeDecisionMap(Decisions);
  Exit;
 End;
 If not AllocateCoeffSymbolMap(CoeffSymbols,AV1MaxCoeffSymbols)Then Begin
  FreeBlockSyntaxMap(SyntaxMap);
  FreeModeDecisionMap(Decisions);
  Exit;
 End;
 InitQuantConfig(QuantConfig);
 InitSegmentationConfig(SegConfig);
 InitLoopFilterConfig(LoopFilterConfig);
 Lambda:=InitialLambdaFromQ(96);
 If not ValidateIntraPredictionForTile(Image,Grid,Tile,Lambda,
  QuantConfig,SegConfig,Decisions,SyntaxMap)Then Begin
  FreeCoeffSymbolMap(CoeffSymbols);
  FreeBlockSyntaxMap(SyntaxMap);
  FreeModeDecisionMap(Decisions);
  Exit;
 End;
 Index:=0;
 While Index<Grid.TotalSuperBlocks Do Begin
  If not GetSuperBlockByIndex(Grid,Index,SB)Then Begin
   FreeBlockSyntaxMap(SyntaxMap);
   FreeCoeffSymbolMap(CoeffSymbols);
   FreeModeDecisionMap(Decisions);
   Exit;
  End;
  If LongInt(SB.PixelX)+SB.Width>Image.PlaneY.Width Then Begin
   FreeCoeffSymbolMap(CoeffSymbols);
   FreeBlockSyntaxMap(SyntaxMap);
   FreeModeDecisionMap(Decisions);
   Exit;
  End;
  If LongInt(SB.PixelY)+SB.Height>Image.PlaneY.Height Then Begin
   FreeCoeffSymbolMap(CoeffSymbols);
   FreeBlockSyntaxMap(SyntaxMap);
   FreeModeDecisionMap(Decisions);
   Exit;
  End;
  Inc(Index);
 End;
 If(Decisions.Count=0)or(SyntaxMap.Count<>Decisions.Count)Then Begin
  FreeCoeffSymbolMap(CoeffSymbols);
  FreeBlockSyntaxMap(SyntaxMap);
  FreeModeDecisionMap(Decisions);
  Exit;
 End;
 If(SyntaxMap.SkipCount+SyntaxMap.NonSkipCount)<>SyntaxMap.Count Then Begin
  FreeCoeffSymbolMap(CoeffSymbols);
  FreeBlockSyntaxMap(SyntaxMap);
  FreeModeDecisionMap(Decisions);
  Exit;
 End;
 For Index:=0 to SyntaxMap.Count-1 Do
  If not EncodeCoeffSymbolsForBlock(SyntaxMap.Blocks^[Index],CoeffSymbols)Then Begin
   FreeCoeffSymbolMap(CoeffSymbols);
   FreeBlockSyntaxMap(SyntaxMap);
   FreeModeDecisionMap(Decisions);
   Exit;
  End;
 If CoeffSymbols.Count=0 Then Begin
  FreeCoeffSymbolMap(CoeffSymbols);
  FreeBlockSyntaxMap(SyntaxMap);
  FreeModeDecisionMap(Decisions);
  Exit;
 End;
 InitEntropyModels(EntropyModels,True);
 If not EncodeCoeffSymbolMapWithRange(CoeffSymbols,Payload,EntropyModels)Then Begin
  FreeCoeffSymbolMap(CoeffSymbols);
  FreeBlockSyntaxMap(SyntaxMap);
  FreeModeDecisionMap(Decisions);
  Exit;
 End;
 ApplyLoopFilter(LoopFilterConfig,Image);
 FreeCoeffSymbolMap(CoeffSymbols);
 FreeBlockSyntaxMap(SyntaxMap);
 FreeModeDecisionMap(Decisions);
 {Chemin experimental : utile aux regressions de structure, interdit pour
  produire un fichier AVIF final tant que EncodeTileDataNormative est incomplet.}
 EncodeTileDataExperimental:=True;
End;

Function WriteTileGroupOBU(Const Image:TAVIFImage;Const Grid:TAV1SuperBlockGrid;
 Const TileConfig:TAV1TileConfig;Const Tile:TAV1Tile;
 Var Output:TAV1ByteBuffer):Boolean;
Var
 Payload:TAV1ByteBuffer;
Begin
 InitAV1ByteBuffer(Payload);
 InitAV1ByteBuffer(Output);
 WriteTileGroupOBU:=False;
 If not EncodeTileGroupHeader(TileConfig,Tile,Payload)Then Exit;
 If not EncodeTileDataNormative(Image,Grid,Tile,Payload)Then Begin
  FreeAV1ByteBuffer(Payload);
  Exit;
 End;
 If not WriteOBU(obuTileGroup,Payload,Output)Then Begin
  FreeAV1ByteBuffer(Payload);
  FreeAV1ByteBuffer(Output);
  Exit;
 End;
 FreeAV1ByteBuffer(Payload);
 WriteTileGroupOBU:=True;
End;

Procedure FillAVIFPlane(Var Plane:TAVIFPlane;Value:Byte);
Begin
 If(Plane.Data<>Nil)and(Plane.Size>0)Then
  FillChar(Plane.Data^[0],Plane.Size,Value);
End;

Procedure FillGrayTestImage(Var Image:TAVIFImage);
Begin
 FillAVIFPlane(Image.PlaneY,128);
 FillAVIFPlane(Image.PlaneU,128);
 FillAVIFPlane(Image.PlaneV,128);
End;

Function EncodeGrayTestFrame(Var Bitstream:TAV1Bitstream):Boolean;
Var
 GrayImage:TAVIFImage;
 Grid:TAV1SuperBlockGrid;
 TileConfig:TAV1TileConfig;
 Tile:TAV1Tile;
 SeqConfig:TAV1SequenceConfig;
 FrameConfig:TAV1FrameConfig;
 SequenceOBU,FrameHeaderOBU,TileGroupOBU:TAV1ByteBuffer;
Begin
 EncodeGrayTestFrame:=False;
 InitAVIFImageRecord(GrayImage);
 InitAV1ByteBuffer(SequenceOBU);
 InitAV1ByteBuffer(FrameHeaderOBU);
 InitAV1ByteBuffer(TileGroupOBU);
 InitAV1Bitstream(Bitstream);
 If not AllocateAVIFImagePadded(GrayImage,16,16,AV1SuperBlockSize,
  AV1SuperBlockSize,acfYUV420,rmFullRange,cmBT709)Then Exit;
 FillGrayTestImage(GrayImage);
 InitSuperBlockGrid(GrayImage,AV1SuperBlockSize,Grid);
 If not ValidateSuperBlockGrid(GrayImage,Grid)Then Begin
  FreeAVIFImage(GrayImage);
  Exit;
 End;
 InitSingleTileConfig(TileConfig);
 If not InitSingleTile(Grid,TileConfig,Tile)Then Begin
  FreeAVIFImage(GrayImage);
  Exit;
 End;
 InitSequenceConfigFromImage(GrayImage,SeqConfig);
 If not WriteSequenceHeaderOBU(SeqConfig,SequenceOBU)Then Begin
  FreeAVIFImage(GrayImage);
  Exit;
 End;
 InitFrameConfigFromImage(GrayImage,SeqConfig,FrameConfig);
 FrameConfig.BaseQIndex:=96;
 If not WriteFrameHeaderOBU(SeqConfig,FrameConfig,FrameHeaderOBU)Then Begin
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(GrayImage);
  Exit;
 End;
 If not WriteTileGroupOBU(GrayImage,Grid,TileConfig,Tile,TileGroupOBU)Then Begin
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(GrayImage);
  Exit;
 End;
 If not BuildAV1Bitstream(SequenceOBU,FrameHeaderOBU,TileGroupOBU,Bitstream)Then Begin
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(GrayImage);
  Exit;
 End;
 FreeAV1ByteBuffer(TileGroupOBU);
 FreeAV1ByteBuffer(FrameHeaderOBU);
 FreeAV1ByteBuffer(SequenceOBU);
 FreeAVIFImage(GrayImage);
 EncodeGrayTestFrame:=Bitstream.Combined.Size>0;
End;

Procedure FillRegressionTestImage(Var Image:TAVIFImage;Pattern:Byte);
Var
 X,YPos:Word;
 Value:Byte;
Begin
 For YPos:=0 to Image.PlaneY.Height-1 Do
  For X:=0 to Image.PlaneY.Width-1 Do Begin
   Case Pattern of
    0:Value:=128;
    1:Value:=Byte((LongInt(X)*3+LongInt(YPos)*5)and $FF);
    Else
     If((X+YPos)and 1)=0 Then Value:=64
                         Else Value:=192;
   End;
   SetAVIFPlaneByte(Image.PlaneY,X,YPos,Value);
  End;
 For YPos:=0 to Image.PlaneU.Height-1 Do
  For X:=0 to Image.PlaneU.Width-1 Do Begin
   If Pattern=2 Then Begin
    SetAVIFPlaneByte(Image.PlaneU,X,YPos,Byte(96+((X+YPos)and 31)));
    SetAVIFPlaneByte(Image.PlaneV,X,YPos,Byte(160-((X+YPos)and 31)));
   End
    Else
   Begin
    SetAVIFPlaneByte(Image.PlaneU,X,YPos,128);
    SetAVIFPlaneByte(Image.PlaneV,X,YPos,128);
   End;
  End;
End;

Function RegressionChromaIsNeutral(Const Image:TAVIFImage):Boolean;
Var
 X,YPos:Word;
Begin
 RegressionChromaIsNeutral:=False;
 If(Image.PlaneU.Data=Nil)or(Image.PlaneV.Data=Nil)Then Exit;
 For YPos:=0 to Image.PlaneU.Height-1 Do
  For X:=0 to Image.PlaneU.Width-1 Do
   If(GetAVIFPlaneByte(Image.PlaneU,X,YPos)<>128)or
    (GetAVIFPlaneByte(Image.PlaneV,X,YPos)<>128)Then Exit;
 RegressionChromaIsNeutral:=True;
End;

Function EncodeRegressionCase(VisibleWidth,VisibleHeight:Word;
 ChromaFormat:TAVIFChromaFormat;Pattern:Byte):Boolean;
Var
 RegressionImage:TAVIFImage;
 PaddedWidth,PaddedHeight:Word;
 Grid:TAV1SuperBlockGrid;
 TileConfig:TAV1TileConfig;
 Tile:TAV1Tile;
 SeqConfig:TAV1SequenceConfig;
 FrameConfig:TAV1FrameConfig;
 SequenceOBU,FrameHeaderOBU,TileGroupOBU:TAV1ByteBuffer;
 Bitstream:TAV1Bitstream;
 Container:TAVIFContainer;
 Checksum:LongInt;
Begin
 EncodeRegressionCase:=False;
 InitAVIFImageRecord(RegressionImage);
 InitAV1ByteBuffer(SequenceOBU);
 InitAV1ByteBuffer(FrameHeaderOBU);
 InitAV1ByteBuffer(TileGroupOBU);
 InitAV1Bitstream(Bitstream);
 InitAVIFContainer(Container);
 PaddedWidth:=RoundUpToMultiple(VisibleWidth,AV1SuperBlockSize);
 PaddedHeight:=RoundUpToMultiple(VisibleHeight,AV1SuperBlockSize);
 If not AllocateAVIFImagePadded(RegressionImage,VisibleWidth,VisibleHeight,
  PaddedWidth,PaddedHeight,ChromaFormat,rmFullRange,cmBT709)Then Exit;
 FillRegressionTestImage(RegressionImage,Pattern);
 If(Pattern<>2)and(not RegressionChromaIsNeutral(RegressionImage))Then Begin
  FreeAVIFImage(RegressionImage);
  Exit;
 End;
 InitSuperBlockGrid(RegressionImage,AV1SuperBlockSize,Grid);
 If not ValidateSuperBlockGrid(RegressionImage,Grid)Then Begin
  FreeAVIFImage(RegressionImage);
  Exit;
 End;
 InitSingleTileConfig(TileConfig);
 If not InitSingleTile(Grid,TileConfig,Tile)Then Begin
  FreeAVIFImage(RegressionImage);
  Exit;
 End;
 InitSequenceConfigFromImage(RegressionImage,SeqConfig);
 If not WriteSequenceHeaderOBU(SeqConfig,SequenceOBU)Then Begin
  FreeAVIFImage(RegressionImage);
  Exit;
 End;
 InitFrameConfigFromImage(RegressionImage,SeqConfig,FrameConfig);
 If not WriteFrameHeaderOBU(SeqConfig,FrameConfig,FrameHeaderOBU)Then Begin
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(RegressionImage);
  Exit;
 End;
 If not WriteTileGroupOBU(RegressionImage,Grid,TileConfig,Tile,TileGroupOBU)Then Begin
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(RegressionImage);
  Exit;
 End;
 If not BuildAV1Bitstream(SequenceOBU,FrameHeaderOBU,TileGroupOBU,Bitstream)Then Begin
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(RegressionImage);
  Exit;
 End;
 If not BuildAVIFContainer(RegressionImage,SeqConfig,Bitstream,Container)Then Begin
  FreeAVIFContainer(Container);
  FreeAV1Bitstream(Bitstream);
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(RegressionImage);
  Exit;
 End;
 Checksum:=ChecksumAVIFImage(RegressionImage);
 Checksum:=(Checksum+Container.FileData.Size+Bitstream.Combined.Size)and $7FFFFFFF;
 EncodeRegressionCase:=(Checksum<>0)and(Container.FileData.Size>0);
 FreeAVIFContainer(Container);
 FreeAV1Bitstream(Bitstream);
 FreeAV1ByteBuffer(TileGroupOBU);
 FreeAV1ByteBuffer(FrameHeaderOBU);
 FreeAV1ByteBuffer(SequenceOBU);
 FreeAVIFImage(RegressionImage);
End;

Function ValidateGray4x4TileGroupOBUEndToEndSelfTest:Boolean;
Var
 Image:TAVIFImage;
 Grid:TAV1SuperBlockGrid;
 TileConfig:TAV1TileConfig;
 Tile:TAV1Tile;
 TileGroupOBU:TAV1ByteBuffer;
 HeaderByte,SizeByte:Byte;
 ExpectedHeader:Byte;
 PayloadSize:LongInt;
 PayloadStart:LongInt;
Begin
 ValidateGray4x4TileGroupOBUEndToEndSelfTest:=False;
 InitAVIFImageRecord(Image);
 InitAV1ByteBuffer(TileGroupOBU);
 If not AllocateAVIFImagePadded(Image,4,4,AV1SuperBlockSize,AV1SuperBlockSize,
  acfYUV420,rmFullRange,cmBT709)Then Exit;
 FillGrayTestImage(Image);
 InitSuperBlockGrid(Image,AV1SuperBlockSize,Grid);
 If not ValidateSuperBlockGrid(Image,Grid)Then Begin
  FreeAVIFImage(Image);
  Exit;
 End;
 InitSingleTileConfig(TileConfig);
 If not InitSingleTile(Grid,TileConfig,Tile)Then Begin
  FreeAVIFImage(Image);
  Exit;
 End;
 If not WriteTileGroupOBU(Image,Grid,TileConfig,Tile,TileGroupOBU)Then Begin
  FreeAVIFImage(Image);
  Exit;
 End;
 {OBU header attendu : obu_type=obuTileGroup (4) sur les bits 6..3,
  obu_has_size_field=1 sur le bit 1, autres bits a zero. Soit (4 shl 3) or 2 = $22.}
 ExpectedHeader:=(AV1OBUTypeValue(obuTileGroup)shl 3)or 2;
 If TileGroupOBU.Size<3 Then Begin
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAVIFImage(Image);
  Exit;
 End;
 HeaderByte:=TileGroupOBU.Data^[0];
 If HeaderByte<>ExpectedHeader Then Begin
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAVIFImage(Image);
  Exit;
 End;
 {LEB128 simple : pour single-tile la taille tient sur un octet
  (continuation bit a zero).}
 SizeByte:=TileGroupOBU.Data^[1];
 If(SizeByte and $80)<>0 Then Begin
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAVIFImage(Image);
  Exit;
 End;
 PayloadSize:=SizeByte and $7F;
 PayloadStart:=2;
 If TileGroupOBU.Size<>PayloadStart+PayloadSize Then Begin
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAVIFImage(Image);
  Exit;
 End;
 {Garde-fou non-regression : le payload doit etre range-coded reel
  (>=2 octets) et surtout pas l'ancien marqueur octet-zero qui aurait
  ete rejete par ValidateBuiltInStandardAV1Bitstream comme MinimalDCSkip.}
 If PayloadSize<2 Then Begin
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAVIFImage(Image);
  Exit;
 End;
 If(PayloadSize=1)and(TileGroupOBU.Data^[PayloadStart]=0)Then Begin
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAVIFImage(Image);
  Exit;
 End;
 FreeAV1ByteBuffer(TileGroupOBU);
 FreeAVIFImage(Image);
 ValidateGray4x4TileGroupOBUEndToEndSelfTest:=True;
End;

Function RunAVIFBuiltInSelfTest:Boolean;
Begin
 RunAVIFBuiltInSelfTest:=False;
 If not ValidateNormativeRangeCoderStrictSelfTest Then Begin
  WriteLn('Echec regression : range coder AV1 strict.');
  Exit;
 End;
 If not ValidateGray4x4TileGroupOBUEndToEndSelfTest Then Begin
  WriteLn('Echec regression : OBU TileGroup end-to-end 4x4 gris.');
  Exit;
 End;
 If not EncodeRegressionCase(1,1,acfYUV420,0)Then Begin
  WriteLn('Echec regression : 1x1 YUV420 gris.');
  Exit;
 End;
 If not EncodeRegressionCase(2,2,acfYUV420,2)Then Begin
  WriteLn('Echec regression : 2x2 YUV420 couleur.');
  Exit;
 End;
 If not EncodeRegressionCase(3,5,acfYUV420,1)Then Begin
  WriteLn('Echec regression : 3x5 YUV420 impair.');
  Exit;
 End;
 If not EncodeRegressionCase(65,65,acfYUV420,0)Then Begin
  WriteLn('Echec regression : 65x65 YUV420 bord superbloc.');
  Exit;
 End;
 If not EncodeRegressionCase(16,16,acfYUV420,0)Then Begin
  WriteLn('Echec regression : 16x16 YUV420 gris.');
  Exit;
 End;
 RunAVIFBuiltInSelfTest:=True;
End;

Function Path2NameExt(Const Path,Ext:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(Path,D,N,E);
 Path2NameExt:=D+N+Ext;
End;

Function AbsLong(Value:LongInt):LongInt;
Begin
 If Value<0 Then AbsLong:=-Value
            Else AbsLong:=Value;
End;

Procedure StopWithError(Const S:String);
Begin
 WriteLn(S);
 Close(SourceBMP);
 Halt;
End;

Procedure ReadBmpRow(RowIndex:LongInt);
Begin
 Seek(SourceBMP,StartPos+RowIndex*BMPBytesPerLine);
 BlockRead(SourceBMP,Buffer,BMPBytesPerLine,ByteReaded);
 If ByteReaded<>BMPBytesPerLine Then StopWithError('Lecture incomplete d''une ligne BMP !');
End;

Function GetPalIndex(X:Word):Byte;
Var
 ByteV:Byte;
Begin
 Case BIH.biBitCount of
  1:Begin
   ByteV:=Buffer[X shr 3];
   GetPalIndex:=(ByteV shr (7-(X and 7)))and 1;
  End;
  4:Begin
   ByteV:=Buffer[X shr 1];
   If(X and 1)=0 Then GetPalIndex:=ByteV shr 4
                 Else GetPalIndex:=ByteV and $0F;
  End;
  8:GetPalIndex:=Buffer[X];
  Else GetPalIndex:=0;
 End;
End;

Procedure GetRGBPixel(X:Word;Var Pixel:RGB);
Var
 W:Word;
 Index:Byte;
Begin
 Case BIH.biBitCount of
  1,4,8:Begin
   Index:=GetPalIndex(X);
   If Index>=NumPal Then Begin
    Pixel.R:=0; Pixel.G:=0; Pixel.B:=0;
   End
    Else
   Begin
    Pixel.R:=Palette[Index].R;
    Pixel.G:=Palette[Index].G;
    Pixel.B:=Palette[Index].B;
   End;
  End;
  16:Begin
   W:=Word(Buffer[X*2])+(Word(Buffer[X*2+1])shl 8);
   Pixel.R:=Byte(((W shr 10)and 31)shl 3);
   Pixel.G:=Byte(((W shr 5)and 31)shl 3);
   Pixel.B:=Byte((W and 31)shl 3);
  End;
  24:Begin
   Pixel.R:=Buffer[X*3+2];
   Pixel.G:=Buffer[X*3+1];
   Pixel.B:=Buffer[X*3+0];
  End;
  32:Begin
   Pixel.R:=Buffer[X*4+2];
   Pixel.G:=Buffer[X*4+1];
   Pixel.B:=Buffer[X*4+0];
 End;
End;
End;

Function EncodeAVIFBuiltIn:Boolean;
Var
 Row:LongInt;
 PaddedWidth,PaddedHeight:Word;
 YUV444Image,EncodedImage,PaddedImage:TAVIFImage;
 SBGrid:TAV1SuperBlockGrid;
 TileConfig:TAV1TileConfig;
 Tile:TAV1Tile;
 SeqConfig:TAV1SequenceConfig;
 FrameConfig:TAV1FrameConfig;
 SequenceOBU,FrameHeaderOBU,TileGroupOBU:TAV1ByteBuffer;
 AV1Bitstream,GrayBitstream:TAV1Bitstream;
 AVIFContainer:TAVIFContainer;
 Checksum:LongInt;
 ValidationReason:String;
 IntegratedValidationReason:String;
 StandardReason:String;
Begin
 {TODO 1 a 25 implementees : le pipeline encode les plans Y/U/V, assemble les
  OBU AV1, les encapsule en AVIF et valide la structure generee.}
 If not AVIFInitialScopeIsSupported(AVIFOptions)Then Begin
  WriteLn('Configuration AVIF initiale non supportee.');
 EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 If TargetFileName<>SourceFileName Then
  DeleteFileIfExists(TargetFileName);
 InitAVIFImageRecord(YUV444Image);
 InitAVIFImageRecord(EncodedImage);
 InitAVIFImageRecord(PaddedImage);
 InitAV1ByteBuffer(SequenceOBU);
 InitAV1ByteBuffer(FrameHeaderOBU);
 InitAV1ByteBuffer(TileGroupOBU);
 InitAV1Bitstream(AV1Bitstream);
 InitAV1Bitstream(GrayBitstream);
 InitAVIFContainer(AVIFContainer);
 If not EncodeGrayTestFrame(GrayBitstream)Then Begin
  WriteLn('Regression AV1 grise interne impossible.');
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 FreeAV1Bitstream(GrayBitstream);
 If not AllocateAVIFImage(YUV444Image,ImageWidth,ImageHeight,
  acfYUV444,AVIFOptions.RangeMode,AVIFOptions.MatrixMode)Then Begin
  WriteLn('Impossible d''allouer l''image YUV interne AVIF.');
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 If not AllocateAVIFImage(EncodedImage,ImageWidth,ImageHeight,
  AVIFOptions.ChromaFormat,AVIFOptions.RangeMode,AVIFOptions.MatrixMode)Then Begin
  WriteLn('Impossible d''allouer l''image YUV encodeur AVIF.');
  FreeAVIFImage(YUV444Image);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 PaddedWidth:=RoundUpToMultiple(ImageWidth,AV1SuperBlockSize);
 PaddedHeight:=RoundUpToMultiple(ImageHeight,AV1SuperBlockSize);
 If not AllocateAVIFImagePadded(PaddedImage,ImageWidth,ImageHeight,
  PaddedWidth,PaddedHeight,AVIFOptions.ChromaFormat,AVIFOptions.RangeMode,
  AVIFOptions.MatrixMode)Then Begin
  WriteLn('Impossible d''allouer l''image AVIF paddee.');
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 ClearAVIFImage(YUV444Image);
 ClearAVIFImage(EncodedImage);
 ClearAVIFImage(PaddedImage);
 For Y:=0 to ImageHeight-1 Do Begin
  If BIH.biHeight>0 Then Row:=LongInt(ImageHeight)-1-Y
                    Else Row:=Y;
  ReadBmpRow(Row);
  ConvertRGBLineToYUV444(YUV444Image,Word(Y));
 End;
 If not ConvertYUV444ToPreferredChroma(YUV444Image,EncodedImage)Then Begin
  WriteLn('Conversion chroma AVIF impossible.');
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 If not CopyAVIFImageVisible(EncodedImage,PaddedImage)Then Begin
  WriteLn('Copie visible vers image paddee impossible.');
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 PadAVIFImageRightAndBottom(PaddedImage);
 InitSuperBlockGrid(PaddedImage,AV1SuperBlockSize,SBGrid);
 If not ValidateSuperBlockGrid(PaddedImage,SBGrid)Then Begin
  WriteLn('Grille de superblocs AV1 invalide.');
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 InitSingleTileConfig(TileConfig);
 If not InitSingleTile(SBGrid,TileConfig,Tile)Then Begin
  WriteLn('Initialisation de la tuile AV1 impossible.');
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 InitSequenceConfigFromImage(EncodedImage,SeqConfig);
 If not WriteSequenceHeaderOBU(SeqConfig,SequenceOBU)Then Begin
  WriteLn('Impossible d''ecrire le Sequence Header OBU AV1.');
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 InitFrameConfigFromImage(EncodedImage,SeqConfig,FrameConfig);
 If not WriteFrameHeaderOBU(SeqConfig,FrameConfig,FrameHeaderOBU)Then Begin
  WriteLn('Impossible d''ecrire le Frame Header OBU AV1.');
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 If not WriteTileGroupOBU(PaddedImage,SBGrid,TileConfig,Tile,TileGroupOBU)Then Begin
  WriteLn('Impossible d''ecrire le Tile Group OBU AV1.');
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 If not BuildAV1Bitstream(SequenceOBU,FrameHeaderOBU,TileGroupOBU,AV1Bitstream)Then Begin
  WriteLn('Assemblage du bitstream AV1 OBU impossible.');
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 DumpAV1OBUSummary(AV1Bitstream);
 If not BuildAVIFContainer(EncodedImage,SeqConfig,AV1Bitstream,AVIFContainer)Then Begin
  WriteLn('Assemblage du conteneur AVIF ISO-BMFF impossible.');
  FreeAVIFContainer(AVIFContainer);
  FreeAV1Bitstream(AV1Bitstream);
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 ValidationReason:='';
 ValidationReason:='';
 If not ValidateBuiltInAV1DecoderPath(EncodedImage,SeqConfig,AV1Bitstream,
 AVIFContainer,ValidationReason)Then Begin
  WriteLn('Le conteneur AVIF interne n''a pas passe la validation structurelle.');
  If ValidationReason<>''Then
   WriteLn('Raison : ',ValidationReason);
  WriteLn('Aucun fichier .AVIF final n''est ecrit.');
  FreeAVIFContainer(AVIFContainer);
  FreeAV1Bitstream(AV1Bitstream);
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 IntegratedValidationReason:='';
 If not ValidateAVIFWithIntegratedAVIFDecoder(EncodedImage,SeqConfig,
  AV1Bitstream,AVIFContainer,IntegratedValidationReason)Then Begin
  WriteLn('La validation AVIF/AV1 integree built-in a echoue.');
  If IntegratedValidationReason<>''Then
   WriteLn('Raison : ',IntegratedValidationReason);
  WriteLn('Aucun fichier .AVIF final n''est ecrit.');
  FreeAVIFContainer(AVIFContainer);
  FreeAV1Bitstream(AV1Bitstream);
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 WriteLn('Validation AVIF/AV1 integree built-in : OK.');
 If IntegratedValidationReason<>''Then
  WriteLn('Detail : ',IntegratedValidationReason);
 If AVIFRequireStandardAV1Bitstream Then Begin
  StandardReason:='';
  If not ValidateBuiltInStandardAV1Bitstream(AV1Bitstream,StandardReason)Then Begin
   WriteLn('Generation AVIF standard refusee.');
   If StandardReason<>''Then
    WriteLn('Raison : ',StandardReason);
   WriteLn('Aucun fichier .AVIF final n''est ecrit tant que la tuile AV1 normative n''est pas implementee.');
   FreeAVIFContainer(AVIFContainer);
   FreeAV1Bitstream(AV1Bitstream);
   FreeAV1ByteBuffer(TileGroupOBU);
   FreeAV1ByteBuffer(FrameHeaderOBU);
   FreeAV1ByteBuffer(SequenceOBU);
   FreeAVIFImage(YUV444Image);
   FreeAVIFImage(EncodedImage);
   FreeAVIFImage(PaddedImage);
   EncodeAVIFBuiltIn:=False;
   Exit;
  End;
 End;
 If not WriteAVIFContainerFile(TargetFileName,AVIFContainer)Then Begin
  WriteLn('Ecriture du fichier AVIF ISO-BMFF impossible.');
  FreeAVIFContainer(AVIFContainer);
  FreeAV1Bitstream(AV1Bitstream);
  FreeAV1ByteBuffer(TileGroupOBU);
  FreeAV1ByteBuffer(FrameHeaderOBU);
  FreeAV1ByteBuffer(SequenceOBU);
  FreeAVIFImage(YUV444Image);
  FreeAVIFImage(EncodedImage);
  FreeAVIFImage(PaddedImage);
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 Checksum:=ChecksumAVIFImage(PaddedImage);
 Checksum:=(Checksum+AV1Bitstream.Combined.Size)and $7FFFFFFF;
 Checksum:=(Checksum+AVIFContainer.FileData.Size)and $7FFFFFFF;
 If Checksum=0 Then Begin
 End;
 FreeAVIFContainer(AVIFContainer);
 FreeAV1Bitstream(AV1Bitstream);
 FreeAV1ByteBuffer(TileGroupOBU);
 FreeAV1ByteBuffer(FrameHeaderOBU);
 FreeAV1ByteBuffer(SequenceOBU);
 FreeAVIFImage(YUV444Image);
 FreeAVIFImage(EncodedImage);
 FreeAVIFImage(PaddedImage);
 EncodeAVIFBuiltIn:=True;
End;

BEGIN
 InitAVIFEncoderOptions(AVIFOptions);
 If ParamStr(1)='--av1-status'Then Begin
  WriteAV1BuiltInEncoderStatus;
  Halt(0);
 End;
 If ParamStr(1)='--selftest'Then Begin
  If RunAVIFBuiltInSelfTest Then Begin
   WriteLn('Regression AVIF integree reussie.');
   Halt(0);
  End
   Else
  Begin
   WriteLn('Regression AVIF integree echouee.');
   Halt(5);
  End;
 End;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('BMP2AVIF : Cette commande devrait convertir une image BitMap (.BMP) ',
                    'en format AVIF (AV1 Image File Format).');
  WriteLn;
  WriteLn('Syntaxe : BMP2AVIF source.BMP [destination.AVIF]');
  WriteLn('          BMP2AVIF --selftest');
  WriteLn('          BMP2AVIF --av1-status');
  WriteLn;
  WriteLn(' source.BMP       Ce parametre permet d''indiquer le nom du fichier ".BMP".');
  WriteLn(' destination.AVIF Ce parametre permet d''indiquer le nom du fichier ".AVIF".');
  WriteLn;
  WriteAVIFInitialScope(AVIFOptions);
  WriteLn;
  WriteLn('Cette version n''utilise aucun encodeur externe : tout le chemin AVIF est built-in.');
  WriteLn('Le fichier final exige maintenant une tuile AV1 standard, pas le payload YUV interne.');
  Halt;
 End;
 If ParamCount<1 Then Begin
  WriteLn('Parametre requis !');
  Halt;
 End;

 SourceFileName:=ParamStr(1);
 If ParamCount>1 Then TargetFileName:=ParamStr(2)
                 Else TargetFileName:=Path2NameExt(SourceFileName,'.AVIF');

 {$I-}Assign(SourceBMP,SourceFileName);
 Reset(SourceBMP,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de lire le fichier BMP : ',SourceFileName);
  Halt;
 End;

 BlockRead(SourceBMP,Header,SizeOf(Header),ByteReaded);
 If Header.Sign<>'BM'Then StopWithError('Signature d''entete Bitmap introuvable !');
 Seek(SourceBMP,14);
 BlockRead(SourceBMP,BIH,SizeOf(BIH),ByteReaded);

 If BIH.biCompression<>bi_RGB Then StopWithError('Compression BMP non supportee !');
 If(BIH.biWidth<=0)or(BIH.biHeight=0)Then StopWithError('Dimensions invalides !');
 If(BIH.biWidth>65535)or(AbsLong(BIH.biHeight)>65535)Then StopWithError('Dimensions trop grandes !');
 If(BIH.biBitCount<>1)and(BIH.biBitCount<>4)and(BIH.biBitCount<>8)and
   (BIH.biBitCount<>16)and(BIH.biBitCount<>24)and(BIH.biBitCount<>32)Then
  StopWithError('Bits par pixel non supporte pour la conversion en AVIF !');

 ImageWidth:=Word(BIH.biWidth);
 ImageHeight:=Word(AbsLong(BIH.biHeight));
 If not AVIFImageFitsMemory(ImageWidth,ImageHeight,AVIFOptions.ChromaFormat)Then
  StopWithError('Dimensions trop grandes pour les plans YUV AVIF internes !');
 BMPBPL:=((LongInt(ImageWidth)*LongInt(BIH.biBitCount)+31)div 32)*4;
 If(BMPBPL<=0)or(BMPBPL>SizeOf(Buffer))Then StopWithError('Largeur de l''image trop grande !');
 BMPBytesPerLine:=Word(BMPBPL);

 NumPal:=0;
 Case BIH.biBitCount of
  1:NumPal:=2;
  4:NumPal:=16;
  8:NumPal:=256;
 End;
 If(BIH.biClrUsed>0)and(BIH.biClrUsed<NumPal)Then NumPal:=Word(BIH.biClrUsed);
 If NumPal>0 Then Begin
  Seek(SourceBMP,14+SizeOf(BitmapInfoHeader));
  BlockRead(SourceBMP,Palette,LongInt(NumPal)*4,ByteReaded);
  If ByteReaded<>LongInt(NumPal)*4 Then StopWithError('Palette BMP incomplete !');
 End;

 StartPos:=Header.OffBits;
 If EncodeAVIFBuiltIn Then
  WriteLn('Fichier AVIF cree : ',TargetFileName)
Else
Begin
 WriteLn('Impossible de creer ',TargetFileName);
 WriteLn('AVIF exige un flux AV1 decodable dans un conteneur ISO-BMFF.');
 WriteAVIFInitialScope(AVIFOptions);
 WriteLn('Le chemin est 100% built-in; la validation externe stricte a refuse ce flux.');
  Close(SourceBMP);
  Halt(4);
 End;
 Close(SourceBMP);
END.
