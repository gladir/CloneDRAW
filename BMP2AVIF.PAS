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
 AVIFMaxPlaneBytes=65000;
 AV1MaxOBUBytes=4096;
 AV1SuperBlockSize=64;
 AV1IntraBlockSize=8;
 AV1MaxTransformSize=32;
 AV1MaxTransformUnits=64;
 AV1MaxModeDecisionBlocks=2048;
 AV1MaxCoeffSymbols=8192;
 DefaultSegmentId=0;
 AV1LambdaShift=4;

Type
 TAVIFInputFormat=(aifBMP);
 TAVIFImageKind=(aikStillImage);
 TAVIFProfile=(apMain);
 TAVIFChromaFormat=(acfYUV420,acfYUV444);
 TColorMatrixMode=(cmBT601,cmBT709);
 TRangeMode=(rmFullRange,rmLimitedRange);
 TAVIFContainerKind=(ackISOBaseMediaFileFormat);
 TAVIFByteArray=Array[0..AVIFMaxPlaneBytes-1]of Byte;
 PAVIFByteArray=^TAVIFByteArray;
 TAV1OBUType=(obuReserved0,obuSequenceHeader,obuTemporalDelimiter,
  obuFrameHeader,obuTileGroup,obuMetadata,obuFrame,obuRedundantFrameHeader,
  obuTileList,obuPadding);

 TAV1ByteBuffer=Record
  Data:PAVIFByteArray;
  Size,Capacity:Word;
 End;

 TAV1Bitstream=Record
  SequenceHeader:TAV1ByteBuffer;
  FrameHeader:TAV1ByteBuffer;
  TileGroup:TAV1ByteBuffer;
  Combined:TAV1ByteBuffer;
 End;

 TBitWriter=Record
  Buffer:^TAV1ByteBuffer;
  CurrentByte:Byte;
  BitCount:Byte;
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
  Count:Word;
  Buffer:^TAV1ByteBuffer;
  Position:Word;
  Failed:Boolean;
  Trace:Boolean;
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
 GetMem(Plane.Data,Word(Size));
 If Plane.Data=Nil Then Begin
  InitAVIFPlane(Plane);
  Exit;
 End;
 AllocateAVIFPlane:=True;
End;

Procedure FreeAVIFPlane(Var Plane:TAVIFPlane);
Begin
 If Plane.Data<>Nil Then
  FreeMem(Plane.Data,Word(Plane.Size));
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
  FillChar(Plane.Data^[0],Word(Plane.Size),Value);
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
  Plane.Data^[Word(Offset)]:=Value;
End;

Function GetAVIFPlaneByte(Const Plane:TAVIFPlane;X,Y:Word):Byte;
Var
 Offset:LongInt;
Begin
 GetAVIFPlaneByte:=0;
 If Plane.Data=Nil Then Exit;
 Offset:=AVIFPlaneOffset(Plane,X,Y);
 If(Offset>=0)and(Offset<Plane.Size)Then
  GetAVIFPlaneByte:=Plane.Data^[Word(Offset)];
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

Function AllocateAV1ByteBuffer(Var Buffer:TAV1ByteBuffer;Capacity:Word):Boolean;
Begin
 AllocateAV1ByteBuffer:=False;
 InitAV1ByteBuffer(Buffer);
 If(Capacity=0)or(Capacity>AV1MaxOBUBytes)Then Exit;
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
 I:Word;
Begin
 AV1BufferAppendBuffer:=False;
 For I:=0 to Source.Size-1 Do
  If not AV1BufferAppendByte(Dest,Source.Data^[I])Then Exit;
 AV1BufferAppendBuffer:=True;
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
 If not AllocateAV1ByteBuffer(Payload,AV1MaxOBUBytes)Then Exit;
 InitBitWriter(Writer,Payload);
 WriteBits(Writer,Config.SeqProfile,3);
 If Config.StillPicture Then WriteBit(Writer,1)Else WriteBit(Writer,0);
 If Config.ReducedStillPictureHeader Then WriteBit(Writer,1)Else WriteBit(Writer,0);
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
 {En profil Main 8 bits, le YUV420 est implique par seq_profile=0; les champs
  restent dans Config pour av1C, mais le bitstream n'ecrit que la position.}
 If(Config.SeqProfile=0)and(not Config.MonoChrome)Then
  WriteBits(Writer,Config.ChromaSamplePosition,2)
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
 WriteDeltaQ(Writer,0); {delta_q_y_dc}
 WriteDeltaQ(Writer,0); {delta_q_u_dc}
 WriteDeltaQ(Writer,0); {delta_q_u_ac}
 WriteDeltaQ(Writer,0); {delta_q_v_dc}
 WriteDeltaQ(Writer,0); {delta_q_v_ac}
 WriteBit(Writer,0);    {using_qmatrix}
End;

Procedure WriteSegmentationParams(Var Writer:TBitWriter;Const Config:TAV1FrameConfig);
Begin
 If Config.SegmentationEnabled Then WriteBit(Writer,1)
                               Else WriteBit(Writer,0);
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

Function WriteFrameHeaderPayload(Const SeqConfig:TAV1SequenceConfig;
 Const Config:TAV1FrameConfig;Var Payload:TAV1ByteBuffer):Boolean;
Var
 Writer:TBitWriter;
Begin
 WriteFrameHeaderPayload:=False;
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
 WriteBit(Writer,0); {allow_screen_content_tools}
 WriteBit(Writer,0); {frame_size_override_flag}
 WriteBits(Writer,LongInt(Config.FrameWidth)-1,SeqConfig.FrameWidthBits);
 WriteBits(Writer,LongInt(Config.FrameHeight)-1,SeqConfig.FrameHeightBits);
 WriteBit(Writer,0); {render_and_frame_size_different}
 WriteBit(Writer,0); {allow_intrabc}
 WriteLoopFilterParams(Writer,Config);
 WriteQuantizationParams(Writer,Config);
 WriteSegmentationParams(Writer,Config);
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
 I,J:Byte;
 Sample:LongInt;
Begin
 For I:=0 to Size-1 Do Begin
  If Horizontal Then OutVec[I,Row]:=0
                Else OutVec[Row,I]:=0;
  For J:=0 to Size-1 Do Begin
   If Horizontal Then Sample:=InVec[J,Row]
                 Else Sample:=InVec[Row,J];
   Case Kind of
    txIdentity:
     If I=J Then
      If Horizontal Then OutVec[I,Row]:=OutVec[I,Row]+Sample
                    Else OutVec[Row,I]:=OutVec[Row,I]+Sample;
    txADST_DCT,txADST_ADST:
     If Horizontal Then OutVec[I,Row]:=OutVec[I,Row]+Sample*LongInt((I+1)*(J+1))
                   Else OutVec[Row,I]:=OutVec[Row,I]+Sample*LongInt((I+1)*(J+1));
    Else
     If I=0 Then
      If Horizontal Then OutVec[I,Row]:=OutVec[I,Row]+Sample
                    Else OutVec[Row,I]:=OutVec[Row,I]+Sample
     Else
      If Horizontal Then OutVec[I,Row]:=OutVec[I,Row]+Sample*LongInt((I+1)*(Size-J))
                    Else OutVec[Row,I]:=OutVec[Row,I]+Sample*LongInt((I+1)*(Size-J));
   End;
  End;
  If Kind<>txIdentity Then
   If Horizontal Then OutVec[I,Row]:=OutVec[I,Row] div Size
                 Else OutVec[Row,I]:=OutVec[Row,I] div Size;
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
 X,YPos,Size:Byte;
 Value:LongInt;
Begin
 FillChar(ReconResidual,SizeOf(ReconResidual),0);
 Size:=GetTransformSizePixels(TxSize);
 For YPos:=0 to Size-1 Do
  For X:=0 to Size-1 Do Begin
   If TxType=txIdentity Then Value:=Coeffs[X,YPos]
   Else If(X=0)and(YPos=0)Then Value:=Coeffs[0,0] div Size
   Else Value:=Coeffs[X,YPos] div (Size*Size);
   ReconResidual[X,YPos]:=ClipTransformValue(Value);
  End;
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

Function ClampQCoeff(Value:LongInt):SmallInt;
Begin
 If Value<-32768 Then ClampQCoeff:=-32768
 Else If Value>32767 Then ClampQCoeff:=32767
                       Else ClampQCoeff:=SmallInt(Value);
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
   QStep:=GetPlaneQuantStep(PlaneID,(X=0)and(YPos=0),Config);
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
   QStep:=GetPlaneQuantStep(PlaneID,(X=0)and(YPos=0),Config);
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

Function EncodeTileGroupHeader(Const TileConfig:TAV1TileConfig;
 Const Tile:TAV1Tile;Var Payload:TAV1ByteBuffer):Boolean;
Var
 Writer:TBitWriter;
Begin
 EncodeTileGroupHeader:=False;
 If not AllocateAV1ByteBuffer(Payload,AV1MaxOBUBytes)Then Exit;
 InitBitWriter(Writer,Payload);
 {Pour une seule tuile, tile_start_and_end_present_flag reste a 0 : le groupe
  couvre implicitement la tuile 0 et aucune taille de tuile n'est patchee.}
 If(TileConfig.TileCols=1)and(TileConfig.TileRows=1)and(Tile.TileIndex=0)Then
  WriteBit(Writer,0)
 Else Begin
  WriteBit(Writer,1);
  WriteBits(Writer,Tile.TileIndex,16);
  WriteBits(Writer,Tile.TileIndex,16);
 End;
 AddTrailingBits(Writer);
 If Writer.Failed Then Begin
  FreeAV1ByteBuffer(Payload);
  Exit;
 End;
 EncodeTileGroupHeader:=True;
End;

Function EncodeTileData(Const Image:TAVIFImage;Const Grid:TAV1SuperBlockGrid;
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
 EncodeTileData:=False;
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
 {Les octets produits restent un range coder simplifie; les CDF AV1 completes
  seront raffinees avant le premier bitstream decodable.}
 EncodeTileData:=True;
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
 If not EncodeTileData(Image,Grid,Tile,Payload)Then Begin
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
  FillChar(Plane.Data^[0],Word(Plane.Size),Value);
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
  AV1SuperBlockSize,acfYUV444,rmFullRange,cmBT709)Then Exit;
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
 SeqConfig.MonoChrome:=True;
 SeqConfig.SubsamplingX:=0;
 SeqConfig.SubsamplingY:=0;
 SeqConfig.ChromaSamplePosition:=0;
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
 Checksum:LongInt;
Begin
 {TODO 1 a 21 implementees : le pipeline encode maintenant les plans Y, U et V
  avec contextes separes et modes chroma simples.}
 If not AVIFInitialScopeIsSupported(AVIFOptions)Then Begin
  WriteLn('Configuration AVIF initiale non supportee.');
  EncodeAVIFBuiltIn:=False;
  Exit;
 End;
 InitAVIFImageRecord(YUV444Image);
 InitAVIFImageRecord(EncodedImage);
 InitAVIFImageRecord(PaddedImage);
 InitAV1ByteBuffer(SequenceOBU);
 InitAV1ByteBuffer(FrameHeaderOBU);
 InitAV1ByteBuffer(TileGroupOBU);
 InitAV1Bitstream(AV1Bitstream);
 InitAV1Bitstream(GrayBitstream);
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
 Checksum:=ChecksumAVIFImage(PaddedImage);
 Checksum:=(Checksum+AV1Bitstream.Combined.Size)and $7FFFFFFF;
 If Checksum=0 Then Begin
 End;
 FreeAV1Bitstream(AV1Bitstream);
 FreeAV1ByteBuffer(TileGroupOBU);
 FreeAV1ByteBuffer(FrameHeaderOBU);
 FreeAV1ByteBuffer(SequenceOBU);
 FreeAVIFImage(YUV444Image);
 FreeAVIFImage(EncodedImage);
 FreeAVIFImage(PaddedImage);
 EncodeAVIFBuiltIn:=False;
End;

BEGIN
 InitAVIFEncoderOptions(AVIFOptions);
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('BMP2AVIF : Cette commande devrait convertir une image BitMap (.BMP) ',
                    'en format AVIF (AV1 Image File Format).');
  WriteLn;
  WriteLn('Syntaxe : BMP2AVIF source.BMP [destination.AVIF]');
  WriteLn;
  WriteLn(' source.BMP       Ce parametre permet d''indiquer le nom du fichier ".BMP".');
  WriteLn(' destination.AVIF Ce parametre permet d''indiquer le nom du fichier ".AVIF".');
  WriteLn;
  WriteAVIFInitialScope(AVIFOptions);
  WriteLn;
  WriteLn('Cette version ne fait aucun appel externe. L''encodage AV1/AVIF integre');
  WriteLn('est cadre, les trois plans YUV existent, et le conteneur AVIF reste a implementer.');
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
 WriteLn('AVIF exige un flux AV1 valide dans un conteneur ISO-BMFF.');
 WriteAVIFInitialScope(AVIFOptions);
 WriteLn('Les trois plans YUV existent; le conteneur AVIF sera ajoute aux etapes suivantes.');
  Close(SourceBMP);
  Halt(4);
 End;
 Close(SourceBMP);
END.
