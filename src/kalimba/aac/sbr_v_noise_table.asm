// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"
#ifdef AACDEC_SBR_ADDITIONS

.VAR/DM1CIRC V_noise_real[512] =
   -0.99948153278296,  0.97113454393991,  0.14130051758487, -0.47005496701697,  0.80705063769351, -0.38981478896926, -0.01053049862020, -0.91266367957293,
    0.54840422910309,  0.40009252867955, -0.99867974711855, -0.95531076805040, -0.45725933317144, -0.72929675029275,  0.75622801399036,  0.07069442601050,
    0.74496252926055, -0.96440182703856,  0.30424629369539,  0.66565033746925,  0.91697008020594, -0.70774918760427, -0.70051415345560, -0.99496513054797,
    0.98164490790123, -0.54671580548181, -0.01689629065389, -0.86110349531986, -0.98892980586032,  0.51756627678691, -0.99635026409640, -0.99969370862163,
    0.55266258627194,  0.34581177741673,  0.62664209577999, -0.77149701404973, -0.91592244254432, -0.76285492357887,  0.79788337195331,  0.54473080610200,
   -0.85639281671058, -0.92882402971423, -0.11708371046774,  0.21356749817493, -0.76191692573909,  0.98111043100884, -0.85913269895572, -0.93307242253692,
    0.30485754879632,  0.85289650925190,  0.91328082618125, -0.05890199924154,  0.28398686150148,  0.95258164539612, -0.78566324168507, -0.95789495447877,
    0.82411158711197, -0.65185446735885, -0.93643603134666,  0.91427159529618, -0.70395684036886,  0.00563771969365,  0.89065051931895, -0.68683707712762,
    0.72165342518718, -0.62928247730667,  0.29938434065514, -0.91781958879280,  0.99298717043688,  0.82368298622748, -0.98512833386833, -0.95915368242257,
   -0.21411126572790, -0.68821476106884,  0.91851997982317, -0.96062769559127,  0.51646184922287,  0.61130721139669,  0.47336129371299,  0.90998308703519,
    0.44844799194357,  0.66614891079092,  0.74922239129237, -0.99571588506485,  0.97401082477563,  0.72683747733879,  0.95432193457128, -0.72962208425191,
   -0.85359479233537, -0.81412430338535, -0.87930772356786, -0.71573331064977,  0.83524300028228, -0.48086065601423,  0.97139128574778,  0.51992825347895,
   -0.00848591195325, -0.70294374303036, -0.95894428168140,  0.97079252950321, -0.92404293670797, -0.69506469500450,  0.26559203620024,  0.28038443336943,
   -0.74138124825523, -0.01752795995444, -0.55126773094930,  0.97960898850996, -0.99196309146936, -0.67684928085260,  0.09140039465500, -0.71658965751996,
    0.81014640078925,  0.40616991671205, -0.67680188682972,  0.86849774348749, -0.99500381284851,  0.84329189340667, -0.09215968531446,  0.99956173327206,
   -0.79732779473535,  0.96349973642406, -0.79942778496547, -0.11566039853896, -0.39922954514662,  0.99089197565987,  0.28631285179909, -0.83302725605608,
    0.95404443402072, -0.06449863579434, -0.99575054486311, -0.65501142790847, -0.81254441908887, -0.99646369485481,  0.00287840603348,  0.70176989408455,
    0.96361882270190, -0.68883758192426, -0.34875585502238,  0.91980081243087, -0.99009048343881,  0.68865791458395, -0.99484402129368,  0.94214511408023,
   -0.67414626793544, -0.47339353684664,  0.14323651387360, -0.29268293575672,  0.43793861458754, -0.36345126374441, -0.08750604656825, -0.96495267812511,
    0.55526940659947,  0.73538215752630, -0.30889773919437,  0.03574995626194,  0.98720684660488, -0.81689296271203,  0.67866860118215, -0.15808569732583,
    0.80723395114371,  0.47788757329038,  0.96367554763201, -0.99143875716818,  0.83081876925833, -0.58753191905341,  0.95538108220960, -0.96490920476211,
   -0.97327101028521,  0.91400366022124, -0.99925837363824, -0.86875903507313, -0.26240034795124, -0.24664412953388,  0.02416275806869,  0.82068619590515,
    0.88547373760759, -0.18173078152226,  0.09355476558534, -0.54668414224090,  0.37050990604091, -0.70373594262891, -0.34600785879594, -0.68774481731008,
   -0.26843291251234,  0.49072334613242,  0.38975993093975, -0.97757125224150, -0.17325552859616,  0.99948035025744, -0.64946246527458, -0.12016920576437,
   -0.58947456517751, -0.41815140454465,  0.99885650204884, -0.56649614128386,  0.94138021032330, -0.75725076534641,  0.20541973692630,  0.99980371023351,
    0.29078277605775, -0.62858772103030,  0.43440904467688, -0.98298583762390,  0.19513029146934, -0.95476662400101,  0.93379635304810, -0.85235410573336,
   -0.86425093011245,  0.38879779059045,  0.92045124735495,  0.89162532251878, -0.36834336949252,  0.93891760988045,  0.99267657565094, -0.94063471614176,
    0.99740224117019, -0.35899413170555,  0.05237237274947,  0.36703583957424,  0.91653180367913,  0.69000803499316, -0.38658751133527, -0.29250814029851,
   -0.60182204677608, -0.97418588163217,  0.88461574003963,  0.05198933055162, -0.53499621979720, -0.49429560226497, -0.98935142339139, -0.98081380091130,
   -0.27338148835532,  0.06310802338302, -0.20461677199539,  0.66223843141647, -0.84764345483665, -0.89039863483811,  0.95903308477986,  0.73504123909879,
   -0.31744434966056, -0.34110827591623,  0.47803883714199,  0.98299195879514, -0.30963073129751,  0.99992588229018, -0.93149731080767,  0.99923472302773,
   -0.26024169633417, -0.35712514743563, -0.99899084509530,  0.86557171579452,  0.33408042438752,  0.99010736374716, -0.66694269691195,  0.64016792079480,
    0.99570534804836, -0.63431466947340, -0.07706847005931,  0.98590090577724,  0.80099335254678,  0.78368131392666,  0.08707806671691, -0.86811883080712,
   -0.39466529740375,  0.97875325649683, -0.95038560288864,  0.17005239424212, -0.76910792026848,  0.99743281016846,  0.95437383549973,  0.99578905365569,
    0.28058259829990,  0.85256524470573, -0.50608540105128, -0.97210735183243,  0.95424048234441, -0.96926570524023,  0.30872163214726, -0.24523839572639,
   -0.33813265086024, -0.05826828420146, -0.22898461455054, -0.18509915019881, -0.10488238045009, -0.71886586182037,  0.99793873738654,  0.57563307626120,
    0.28909646383717,  0.42188998312520,  0.93335049681047, -0.97087374418267,  0.36722871286923, -0.81093025665696, -0.26240603062237,  0.83996497984604,
   -0.99909615720225,  0.74649464155061, -0.74774595569805,  0.95781667469567,  0.95472308713099,  0.48708332746299,  0.46332038247497, -0.76497004940162,
    0.57397389364339,  0.75374316974495, -0.59174397685714,  0.75087906691890, -0.98607857336230, -0.40761056640505,  0.66929266740477, -0.97463695257310,
    0.90145509409859, -0.87259289048043, -0.91529461447692, -0.03305738840705,  0.07223051368337,  0.99498012188353, -0.74904939500519,  0.04585228574211,
   -0.89054954257993, -0.83782144651251,  0.33454804933804, -0.99707579362824, -0.22827527843994,  0.67248046289143, -0.05146538187944,  0.99947295749905,
    0.66951124390363, -0.99602956559179,  0.82104905483590,  0.99186510988782, -0.65284592392918,  0.93885443798188,  0.96735248738388, -0.22225968841114,
   -0.44132783753414, -0.85694974219574,  0.91783042091762,  0.72556974415690, -0.99711581834508,  0.77638976371966,  0.07717324253925, -0.56049829194163,
    0.98398893639988,  0.47546946844938,  0.65675089314631,  0.03273375457980, -0.38684144784738, -0.97346267944545, -0.53282156061942,  0.99817310731176,
   -0.50254500772635,  0.01995873238855,  0.99930381973804,  0.82907767600783, -0.58660709669728, -0.17573736667267,  0.83434292401346,  0.05946491307025,
    0.81505484574602, -0.44976380954860, -0.89746474625671,  0.39677256130792, -0.07588948563079,  0.76343198951445, -0.74490104699626,  0.64880119792759,
    0.62319537462542,  0.42215817594807,  0.02704554141885,  0.80001773566818, -0.79351832348816,  0.63872359151636,  0.52890520960295,  0.74238552914587,
    0.99096131449250, -0.80412329643109, -0.64612616129736,  0.11657770663191, -0.95053182488101, -0.62228872928622,  0.03004475787316, -0.97987214341034,
   -0.99986980746200,  0.89110648599879,  0.10407960510582,  0.95964737821728,  0.50843233159162,  0.17006334670615,  0.25872675063360, -0.01115998681937,
   -0.79598702973261, -0.99264708948101, -0.99829663752818, -0.70801016548184, -0.70467057786826,  0.99846021905254, -0.63364968534650, -0.16258217500792,
   -0.43645594360633, -0.99848471702976, -0.16796458968998, -0.87979225745213,  0.44183099021786,  0.93310180125532, -0.93941931782002, -0.88590003188677,
    0.99971463703691, -0.75376385639978,  0.93887685615875,  0.85126435782309,  0.39701421446381, -0.37024464187437, -0.36024828242896, -0.93388812549209,
   -0.65298804552119,  0.11960319006843,  0.94292565553160,  0.75081145286948,  0.56721979748394,  0.46857766746029,  0.97312313923635, -0.38299976567017,
    0.41025800019463,  0.09638062008048, -0.85283249275397,  0.88866808958124, -0.48202429536989,  0.27572582416567, -0.65889129659168,  0.98838086953732,
   -0.20651349620689, -0.62126416356920,  0.20320105410437, -0.97790548600584,  0.11112534735126, -0.41368337314182,  0.24133038992960, -0.66393410674885,
   -0.53697829178752, -0.97224737889348,  0.87392477144549,  0.19050361015753, -0.46353441212724, -0.07064096339021, -0.92444085484466, -0.83822593578728,
    0.75214681811150, -0.42102998829339, -0.72094786237696,  0.78843311019251,  0.97394027897442,  0.99206463477946,  0.76789609461795, -0.82002421836409,
    0.81924990025724, -0.26719850873357, -0.43311260380975,  0.99194979673836, -0.80692001248487,  0.43080003649976,  0.67709491937357,  0.56151770568316,
    0.10831862810749,  0.91229417540436, -0.48972893932274, -0.89033658689697,  0.65269447475094,  0.67439478141121, -0.47770832416973, -0.99715979260878,
   -0.90889593602546, -0.06618622548177,  0.99430266919728,  0.97686402381843,  0.94813650221268, -0.95434497492853, -0.49104783137150,  0.99881175120751,
    0.50449166760303,  0.47162891065108, -0.62081581361840, -0.43867015250812,  0.98630563232075, -0.61510362277374, -0.03841517601843, -0.30102157304644,
    0.41881284182683, -0.86135454941237,  0.67226861393788, -0.70737398842068,  0.94044946687963, -0.82386352534327, -0.32070666698656,  0.57593163224487,
   -0.36326018419965,  0.99979044674350, -0.92366023326932, -0.44607178518598,  0.44226800932956,  0.03671907158312,  0.52175424682195, -0.94701139690956,
   -0.98759606946049,  0.87434794743625, -0.93412041758744,  0.96063943315511,  0.97534253457837,  0.99642466504163, -0.94705089665984,  0.91599807087376;


.VAR/DM2CIRC V_noise_imag[512] =
   -0.59483417516607, -0.67528515225647, -0.95090983575689, -0.37340549728647,  0.29653668284408,  0.89572605717087, -0.66959058036166, -0.11522938140034,
    0.75221367176302, -0.98929400334421, -0.88147068645358,  0.90908757154593, -0.56716323646760, -0.98008272727324,  0.20950329995549, -0.78247898470706,
   -0.91169004445807, -0.94739918296622, -0.49438267012479,  0.64652935542491,  0.17514097332009,  0.52548653416543, -0.45340028808763, -0.90071908066973,
   -0.77463155528697, -0.02570928536004,  0.00287506445732,  0.42548583726477, -0.87881132267556,  0.66926784710139, -0.58107730574765,  0.98369989360250,
    0.59449057465591,  0.94879421061866, -0.74402970906471, -0.33883658042801,  0.03687901376713, -0.91371867919124, -0.93180971199849, -0.11919206037186,
    0.42429854760451,  0.27871809078609, -0.99800843444966, -0.90716295627033,  0.99768118356265, -0.95854459734407,  0.95766566168880,  0.49431757696466,
   -0.70540034357529,  0.46766131791044, -0.99839597361769,  0.70741827819497,  0.34633555702188, -0.54893416026939, -0.75568541079691, -0.20423194696966,
    0.96654618432562, -0.88734990773289,  0.99870790442385, -0.98290505544444,  0.58796798221039,  0.61768196727244,  0.52783352697585,  0.80806944710339,
   -0.69259857349564,  0.13627037407335, -0.46051329682246, -0.74012716684186,  0.40816610075661, -0.74036047190173, -0.99972330709594, -0.99237800466040,
   -0.93424819052545, -0.26892306315457,  0.09358228901785,  0.36099095133739, -0.71373332873917,  0.46950141175917, -0.27333178296162,  0.96715662938132,
    0.99211574628306,  0.96590176169121, -0.89879858826087,  0.52785521494349, -0.16855870075190, -0.48060774432251,  0.68849603408441, -0.76608443420917,
    0.88738125901579, -0.97480768049637,  0.74748307690436, -0.98570608178923,  0.83702537075163, -0.98848504923531,  0.80093621198236,  0.80247631400510,
   -0.76670128000486,  0.55359910445577, -0.43265504344783,  0.09325857238682,  0.85507704027855,  0.98633412625459,  0.73314307966524,  0.14537913654427,
    0.99310339807762, -0.82616635284178, -0.98898543862153, -0.94021446752851,  0.67019017358456,  0.12631491649378, -0.20537731453108, -0.97788200391224,
    0.53722648362443, -0.26469008598449,  0.94502052337695, -0.18333598647899, -0.02634122068550,  0.10406957462213,  0.69540012101253, -0.12358542001404,
   -0.91582524736159,  0.96640458041000,  0.64323902822857,  0.28587846253726,  0.94129601616966, -0.92062625581587, -0.91035047143603, -0.67330410892084,
    0.49162765398743,  0.03250560813135,  0.42389784469507,  0.82546114655624, -0.51627234660629,  0.84490533520752,  0.64768261158166, -0.20453028573322,
    0.40706967140989,  0.91338958840772,  0.71472290693300,  0.66507455644919,  0.85868021604848,  0.55660316809678, -0.20052559254934, -0.99696425367461,
    0.49548221180078, -0.85904328834047, -0.94145598222488,  0.05759224927952, -0.78904969892724,  0.64874435357162,  0.97686944362527, -0.53960305946511,
    0.78891523734774,  0.96452072373404, -0.80664389776860, -0.97325616900959,  0.48409133691962, -0.90827703628298,  0.81284503870856,  0.85279555024382,
   -0.24717418514605, -0.46333147839295,  0.38486749303242, -0.24945277239809, -0.94780851414763,  0.01290772389163, -0.85557052096538, -0.64020970923102,
    0.12378128133110,  0.57972471346930,  0.71084847864067, -0.20291699203564, -0.68264554369108, -0.87642273115183,  0.27192914288905, -0.85087787994476,
   -0.89636802901469, -0.26152145156800,  0.54845123045604,  0.95980774020221, -0.59910140383171,  0.91227665827081, -0.99441426144200, -0.30238837956299,
    0.83115668004362, -0.45359708737775,  0.95515358099121,  0.05305894580606, -0.92770672250494,  0.58285545563426,  0.68645507104960, -0.57147322153312,
   -0.34847132454388,  0.16276422358861,  0.11136095490444, -0.90494866361587,  0.35281916733018,  0.53650549640587, -0.94435144369918,  0.79835913565599,
    0.35393777921520,  0.38765693387102, -0.98546330463232,  0.21021524625209, -0.94239832251867,  0.98364554179143, -0.70881994583682, -0.08342347966410,
   -0.45795025029466,  0.97274429344593, -0.62433652524220,  0.54950955570563,  0.96458298020975, -0.89968353740388, -0.03757034316958,  0.41332338538963,
   -0.16830494996370, -0.46633226649613, -0.25640361602661, -0.38653265641875, -0.30587628726597,  0.90952171386132,  0.99501571208985,  0.37444994344615,
    0.86779651036123,  0.96468523666475,  0.57508405276414,  0.21269661669964,  0.97241553731237,  0.98183865291903, -0.40249159006933, -0.72856895534041,
    0.99950922447209, -0.54539587529618, -0.14209977628489,  0.72528579940326,  0.02372316801261,  0.88866581484602,  0.76744927173873, -0.03747203173192,
   -0.36834111883652,  0.40211222807691, -0.39423219786288,  0.01989791390047, -0.18076720599336, -0.26281872094289, -0.98313162570490, -0.80142993767554,
   -0.75999759855752,  0.19298963768574,  0.74645156992493,  0.55593866696299,  0.86185953874709,  0.04602397576623, -0.91643611810148,  0.15649530836856,
    0.45844586038111,  0.21079116459234, -0.89581437101329,  0.88241721133981, -0.36851896710853,  0.45506999802597,  0.80938994918745,  0.39347308654705,
   -0.66809432114456, -0.72467840967746,  0.89563219587625,  0.54683053962658, -0.96226617549298,  0.42697157037567,  0.97002324109952, -0.54106826257356,
   -0.85361420634036, -0.64567607735589, -0.65846015480300, -0.23095213067791, -0.99240147091219,  0.73775654896574,  0.41514960556126,  0.63206633394807,
   -0.38661779441897, -0.06940774188029,  0.97054853316316,  0.47565762892084, -0.87769947402394,  0.78030982480538,  0.90041310491497, -0.91034337352097,
    0.96307783970534,  0.48148651230437, -0.43537023883588,  0.86636445711364,  0.65291654172961,  0.08778370229363, -0.92774095379098,  0.55839849139647,
   -0.96024605713970,  0.12144893606462, -0.26898062008959, -0.79047927052628, -0.08588776019550,  0.99999041579432,  0.10964126185063,  0.89210929242238,
    0.35289703373760,  0.96705214651335, -0.89405370422752, -0.29612672982396,  0.25034911730023, -0.90045573444695,  0.98629493401748, -0.00190223301301,
    0.99781390365446,  0.99233587353666, -0.15698707534206, -0.37205262859764, -0.88805001733626,  0.97094358113387,  0.99985483641521,  0.99812337444082,
   -0.31791913188064,  0.97637632547466, -0.86231516800408,  0.93237990079441,  0.18874759397997, -0.03646211390569, -0.92599700120679,  0.93625229707912,
    0.98905825623893, -0.44654715757688,  0.99540741724928,  0.72023001312947,  0.52186723253637, -0.74895312615259,  0.90891816978629,  0.57124029781228,
   -0.92688840659280,  0.88844532719844, -0.46356892383970, -0.99899555770747,  0.58211560180426,  0.94321834873819,  0.58638399856595,  0.82522301569036,
    0.39467440420569,  0.68613044836811,  0.18331637134880, -0.74933109564108,  0.51337349030406, -0.96549364384098, -0.91423265091354,  0.61133572482148,
   -0.88829338134294,  0.85223515096765,  0.94578896296649, -0.06323442598128,  0.96840773806582, -0.48166920859485, -0.13023450646997,  0.20511047074866,
   -0.94685947861369,  0.40894572671545,  0.99846578838537, -0.74854668609359,  0.74096214084170,  0.41746629422634,  0.94725911744610,  0.41336660830571,
   -0.93098313552599, -0.07712787385208, -0.05417518053666,  0.91542195141039, -0.36208897989136,  0.08128252493444,  0.60048872455592,  0.04491915291044,
   -0.19451182854402, -0.88513818199457,  0.72198674804544, -0.83662833815041, -0.96939905138082,  0.82767262846661, -0.99738896333384,  0.36526129686425,
   -0.36021610299715, -0.97894250343044,  0.77357793811619, -0.35435818285502,  0.96107691266205, -0.76854025314829,  0.99893303933816,  0.98496019742444,
    0.97138411318894, -0.99542822402536,  0.01877138824311,  0.33680685948117,  0.93272777501857, -0.98725746254433, -0.16473594423746, -0.95939125400802,
   -0.94805030113284,  0.96245166923809, -0.98987511890470, -0.71725725041680, -0.93568974498761, -0.99913308068246, -0.56409379640356,  0.47624600491382,
   -0.83889954253462,  0.00814643438625, -0.11284528204636,  0.52349251543547,  0.81779634174316, -0.87071656222959,  0.34655735648287, -0.84476541096429,
   -0.18439575450921,  0.99899346780168,  0.83163906518293, -0.35533223142265, -0.24076836414499, -0.30140233457198, -0.99548191630031,  0.98516909715427,
    0.02116736935734,  0.04411984381457,  0.91475563922421, -0.99735267083226, -0.96805608884164,  0.58634753335832,  0.58835634138583,  0.99994349600236,
    0.54593044066355, -0.59893681700392, -0.86879180355289,  0.96290806999242,  0.21484763313301,  0.28216837680365,  0.51294362630238, -0.08249679629081,
   -0.97649903936228,  0.22081333579837, -0.12796173740361,  0.01602615387195, -0.95249041539006, -0.94479803205886, -0.10457590187436, -0.01695043208885,
   -0.99955681042665,  0.99720941999394, -0.35008961934255,  0.52851398958271, -0.26695944086561, -0.57010120849429, -0.76519356730966, -0.73530179553767,
    0.99698425250579,  0.68903369776193,  0.85321815947490,  0.91876249766422, -0.32627540663214, -0.21919095636638, -0.95478075822906, -0.70693811747778,
   -0.08628837174592, -0.65987351408410,  0.56289246362686, -0.71656563987082,  0.65916004833932, -0.81684380846796, -0.16789556203025, -0.93565784007648,
    0.62034397054380, -0.23812217221359,  0.18812555317553, -0.28664534366620, -0.97506640027128, -0.79607978501983,  0.32895214359663,  0.88993983831354,
   -0.85995072408434, -0.18680204049569,  0.75000676218956,  0.99998069244322, -0.53578899600662, -0.89515019899997, -0.69888815681179, -0.07667808922205,
    0.02188098922282,  0.98947480909359, -0.13494389011014, -0.76547349325992,  0.09026201157416,  0.08924768823676,  0.50143421908753, -0.98966422921509,
    0.07440243123228, -0.14130287347405, -0.97979298068180, -0.54233252016394,  0.71326756742752,  0.63606389366675, -0.85396826735705, -0.01826348194255,
    0.82288714303073,  0.89399495655433,  0.41374052024363,  0.93116709541280,  0.86150930812689,  0.70190043427512, -0.29580042814306, -0.98147830385781;

#endif
