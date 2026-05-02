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
  25. Valider avec plusieurs decodeurs AVIF et ajouter des tests de non-regression.
}

Program BMP2AVIF;

{$A-}

Uses DOS;

Const
 bi_RGB=0;
 MaxLineBytes=16384;

Type
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
 BMPBytesPerLine,ByteReaded:Word;
 ImageWidth,ImageHeight,NumPal:Word;
 StartPos,BMPBPL:LongInt;
 Y:LongInt;

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
 X:Word;
 Row:LongInt;
 Pixel:RGB;
 Checksum:LongInt;
Begin
 {Le decodage BMP est integre ici. L'etape manquante est l'encodage AV1
  intra + conteneur ISO-BMFF/AVIF, qui est un codec complet.}
 Checksum:=0;
 For Y:=0 to ImageHeight-1 Do Begin
  If BIH.biHeight>0 Then Row:=LongInt(ImageHeight)-1-Y
                    Else Row:=Y;
  ReadBmpRow(Row);
  For X:=0 to ImageWidth-1 Do Begin
   GetRGBPixel(X,Pixel);
   Checksum:=(Checksum+LongInt(Pixel.R)+LongInt(Pixel.G)+LongInt(Pixel.B))and $7FFFFFFF;
  End;
 End;
 If Checksum=0 Then Begin
 End;
 EncodeAVIFBuiltIn:=False;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('BMP2AVIF : Cette commande devrait convertir une image BitMap (.BMP) ',
                    'en format AVIF (AV1 Image File Format).');
  WriteLn;
  WriteLn('Syntaxe : BMP2AVIF source.BMP [destination.AVIF]');
  WriteLn;
  WriteLn(' source.BMP       Ce parametre permet d''indiquer le nom du fichier ".BMP".');
  WriteLn(' destination.AVIF Ce parametre permet d''indiquer le nom du fichier ".AVIF".');
  WriteLn;
  WriteLn('Cette version ne fait aucun appel externe. L''encodage AV1/AVIF integre');
  WriteLn('n''est pas disponible dans cette petite commande Pascal autonome.');
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
  WriteLn('AVIF exige un flux AV1 valide dans un conteneur ISO-BMFF.');
  WriteLn('Un encodeur AV1 complet integre en Turbo Pascal/Free Pascal n''est pas implemente.');
  Close(SourceBMP);
  Halt(4);
 End;
 Close(SourceBMP);
END.
