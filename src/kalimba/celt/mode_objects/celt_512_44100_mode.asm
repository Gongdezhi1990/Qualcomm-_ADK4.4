// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_MODE_512_44100_INCLUDED
#define CELT_MODE_512_44100_INCLUDED

#include "../celt_library.h"
// *****************************************************************************
// MODULE:
//    $celt.celt_512_44100_mode 
//
// DESCRIPTION:
//    Mode object for N=512 and fs = 44100Hz
//
// *****************************************************************************
.MODULE $M.celt.mode.celt_512_44100_mode;
.DATASEGMENT DM;
   // -- Definition of mode object
   .VAR $celt.mode.celt_512_44100_mode[$celt.mode.STRUC_SIZE] = 
      44100,             // Fs
      128,               // overlap
      512,               // mdctSize
      24,                // nbEBands
      46,                // pitchEnd
      0.8,               // ePredCoef
      12,                // nbAllocVectors
      4,                 // nbShortMdcts
      128,               // shortMdctSize
      &eBands,           // eBands_addr
      &allocVectors,     // allocVectors_addr
      &window,           // window_addr
      &prob,             // prob_addr
      &bits,             // bits_addr
      &ebands_dif_sqrt,  // ebands_dif_sqrt_addr
      &trig,             // trig_addr;
      0,
      0,
      0,
      0;            

   // -- start frequency bin of eBANDs 
   .VAR eBands[26] =     0,     3,     6,     9,    12,    15,    18,    21,    25,    29,    34,    40,    47,    54,    63,    73,    86,   102,   123,   149,   179,   221,   279,   360,   465,   512;
   
   // -- Allocation vectors
   .VAR allocVectors[288] = 			
          8,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0, 
          5,     4,     3,     4,     4,     2,     2,     2,     2,     2,     2,     2,     2,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0, 
          5,     5,     3,     4,     4,     4,     3,     4,     4,     4,     4,     9,     9,    14,    13,    14,    10,     8,     0,     0,     0,     0,     0,     0, 
          5,     5,     5,     7,     6,     6,     5,     6,     6,     6,     6,    11,    11,    16,    15,    16,    12,    10,     8,     0,     0,     0,     0,     0, 
          7,     5,     5,     7,     8,     7,     7,     9,     7,     8,     9,    13,    13,    18,    17,    18,    14,    12,    10,    10,    10,     0,     0,     0, 
          8,     8,     9,    10,    11,    11,    10,    13,    11,    12,    15,    15,    17,    20,    19,    20,    18,    12,    10,    10,    10,    10,     2,     0, 
         10,     8,     9,    14,    15,    13,    12,    15,    13,    16,    19,    19,    17,    22,    19,    20,    18,    18,    16,    22,    20,    20,     2,     0, 
         13,    13,    15,    16,    15,    13,    12,    17,    14,    18,    21,    22,    23,    24,    21,    22,    34,    24,    30,    30,    40,    36,    20,     2, 
         16,    18,    18,    19,    17,    15,    14,    19,    18,    23,    26,    30,    32,    37,    40,    45,    53,    58,    79,    73,    76,    80,    70,     2, 
         18,    18,    20,    19,    17,    18,    17,    21,    24,    28,    39,    43,    45,    57,    61,    65,    69,    76,    77,    83,   100,   118,   108,    62, 
         21,    21,    21,    19,    19,    18,    20,    30,    36,    45,    54,    60,    56,    71,    80,    94,    99,   111,   122,   123,   124,   144,   164,   125, 
         23,    23,    25,    28,    28,    28,    30,    47,    55,    66,    75,    86,    85,   112,   119,   134,   138,   171,   183,   183,   185,   184,   203,   185;
      
   // -- Window
   .VAR/DM2 window[128] =			
      0.000059139038058, 0.000532197882421, 0.001478030113503, 0.002896063495427, 0.004785436205566, 0.007144992705435, 0.009973277337849, 0.013268529437482, 
      0.017028674483299, 0.021251311525702, 0.025933710858226, 0.031072795391083, 0.036665130406618, 0.042706914246082, 0.049193959683180, 0.056121692061424, 
      0.063485108315945, 0.071278803050518, 0.079496912658215, 0.088133141398430, 0.097180701792240, 0.106632351875305, 0.116480343043804, 0.126716434955597, 
      0.137331858277321, 0.148317337036133, 0.159663051366806, 0.171358674764633, 0.183393299579620, 0.195755511522293, 0.208433344960213, 0.221414253115654, 
      0.234685227274895, 0.248232662677765, 0.262042462825775, 0.276100039482117, 0.290390282869339, 0.304897606372833, 0.319605946540833, 0.334498882293701, 
      0.349559515714645, 0.364770591259003, 0.380114465951920, 0.395573228597641, 0.411128699779511, 0.426762402057648, 0.442455708980560, 0.458189755678177, 
      0.473945677280426, 0.489704459905624, 0.505447089672089, 0.521154582500458, 0.536808073520660, 0.552388727664948, 0.567878007888794, 0.583257555961609, 
      0.598509252071381, 0.613615453243256, 0.628558754920959, 0.643322288990021, 0.657889604568481, 0.672244906425476, 0.686372935771942, 0.700258910655975, 
      0.713888943195343, 0.727249741554260, 0.740328788757324, 0.753114342689514, 0.765595495700836, 0.777762115001678, 0.789605021476746, 0.801115870475769, 
      0.812287271022797, 0.823112726211548, 0.833586633205414, 0.843704402446747, 0.853462278842926, 0.862857580184937, 0.871888458728790, 0.880554080009460, 
      0.888854384422302, 0.896790385246277, 0.904363751411438, 0.911577284336090, 0.918434441089630, 0.924939453601837, 0.931097447872162, 0.936914145946503, 
      0.942396163940430, 0.947550535202026, 0.952385127544403, 0.956908285617828, 0.961128890514374, 0.965056359767914, 0.968700468540192, 0.972071409225464, 
      0.975179851055145, 0.978036582469940, 0.980652749538422, 0.983039617538452, 0.985208690166473, 0.987171590328217, 0.988939821720123, 0.990525066852570, 
      0.991939008235931, 0.993192970752716, 0.994298517704010, 0.995266735553741, 0.996108710765839, 0.996835112571716, 0.997456431388855, 0.997982800006866, 
      0.998423933982849, 0.998789250850677, 0.999087631702423, 0.999327600002289, 0.999517142772675, 0.999663650989532, 0.999774158000946, 0.999854981899261, 
      0.999911963939667, 0.999950289726257, 0.999974489212036, 0.999988555908203, 0.999995827674866, 0.999998927116394, 0.999999880790710, 1.000000000000000;
      
   // -- Prob vector     
   .VAR prob[96] =			
          6000,    15200,     5800,    15632, 
          5600,    16072,     5400,    16522, 
          5200,    16978,     5000,    17444, 
          4800,    17918,     4600,    18400, 
          4400,    18892,     4200,    19394, 
          4000,    19906,     3800,    20428, 
          3600,    20962,     3400,    21504, 
          3200,    22058,     3000,    22624, 
          2800,    23202,     2600,    23792, 
          2400,    24394,     2200,    25008, 
          2000,    25638,     1800,    26280, 
          1600,    26936,     1400,    27608, 
          9000,     9530,     8760,     9934, 
          8520,    10346,     8280,    10766, 
          8040,    11194,     7800,    11630, 
          7560,    12074,     7320,    12528, 
          7080,    12992,     6840,    13466, 
          6600,    13948,     6360,    14440, 
          6120,    14944,     5880,    15458, 
          5640,    15984,     5400,    16522, 
          5160,    17070,     4920,    17632, 
          4680,    18206,     4440,    18794, 
          4200,    19394,     3960,    20010, 
          3720,    20640,     3480,    21286;
      
   // -- bits verctors      
   .BLOCK/DM bits;
   .VAR bits_offset[24] =        24,       24,       24,       24,       24,       24,       24,       64,       64,      104,      144,      184,      224,      264,      304,      344,      384,      424,      464,      504,      544,      584,      624,      664;
   .VAR bits_0[40] =     0,    42,    67,    84,    97,   107,   116,   123,   129,   134,   139,   143,   147,   151,   154,   158,   161,   166,   171,   175,   179,   183,   186,   190,   193,   198,   203,   207,   211,   215,   218,   222,   225,   230,   235,   239,   243,   247,   250,   254;
   .VAR bits_7[40] =     0,    48,    80,   104,   122,   136,   148,   159,   168,   176,   183,   190,   196,   201,   206,   211,   215,   223,   231,   237,   243,   249,   254,   259,   263,   271,   279,   285,   291,   297,   302,   307,   311,   319,   327,   333,   339,   345,   350,   355;
   .VAR bits_9[40] =     0,    54,    91,   119,   142,   160,   176,   189,   201,   211,   221,   229,   237,   245,   251,   258,   264,   274,   284,   293,   301,   308,   315,   321,   327,   338,   348,   357,   365,   372,   379,   385,   391,   402,   412,   421,   429,   436,   443,   449;
   .VAR bits_10[40] =     0,    58,    99,   132,   158,   180,   199,   215,   229,   242,   254,   265,   274,   283,   292,   300,   307,   320,   332,   343,   353,   362,   371,   379,   386,   400,   412,   423,   433,   442,   451,   459,   466,   480,   492,   503,   528,   538,   547,   555;
   .VAR bits_11[40] =     0,    61,   106,   142,   172,   197,   219,   238,   254,   270,   283,   296,   307,   318,   328,   337,   346,   362,   377,   390,   401,   412,   423,   432,   441,   457,   472,   485,   497,   508,   536,   545,   555,   572,   586,   599,   611,   622,   632,   641;
   .VAR bits_12[40] =     0,    61,   106,   142,   172,   197,   219,   238,   254,   270,   283,   296,   307,   318,   328,   337,   346,   362,   377,   390,   401,   412,   423,   432,   441,   457,   472,   485,   497,   508,   536,   545,   555,   572,   586,   599,   611,   622,   632,   641;
   .VAR bits_13[40] =     0,    67,   118,   159,   195,   225,   252,   275,   297,   316,   334,   350,   365,   379,   392,   404,   415,   436,   455,   472,   488,   503,   538,   550,   561,   584,   602,   620,   636,   650,   664,   677,   689,   711,   730,   748,   764,   779,   793,   805;
   .VAR bits_14[40] =     0,    70,   123,   167,   204,   237,   266,   292,   315,   336,   356,   373,   390,   405,   420,   433,   446,   470,   491,   510,   549,   567,   581,   596,   609,   632,   654,   674,   692,   709,   724,   737,   751,   777,   798,   818,   836,   852,   868,   882;
   .VAR bits_15[40] =     0,    76,   135,   185,   228,   267,   301,   332,   361,   387,   411,   434,   455,   475,   493,   510,   551,   580,   609,   634,   658,   679,   698,   718,   735,   768,   796,   822,   846,   868,   889,   907,   925,   958,   995,  1028,  1055,  1077,  1098,  1117;
   .VAR bits_16[40] =     0,    80,   144,   199,   247,   290,   330,   365,   398,   429,   457,   483,   508,   555,   579,   599,   620,   656,   691,   721,   749,   777,   800,   824,   845,   886,   920,   953,   983,  1010,  1037,  1069,  1096,  1141,  1198,  1229,  1259,  1288,  1314,  1337;
   .VAR bits_17[40] =     0,    87,   157,   218,   272,   322,   367,   409,   447,   484,   541,   574,   605,   633,   661,   688,   713,   759,   803,   842,   878,   913,   950,   989,  1022,  1078,  1124,  1186,  1227,  1265,  1300,  1330,  1360,  1413,  1460,  1505,  1545,  1582,  1617,  1647;
   .VAR bits_18[40] =     0,    92,   167,   233,   292,   346,   396,   443,   486,   549,   590,   626,   662,   694,   727,   757,   788,   842,   893,   941,   987,  1039,  1084,  1124,  1183,  1245,  1304,  1356,  1406,  1450,  1491,  1531,  1568,  1636,  1695,  1748,  1798,  1845,  1888,  1926;
   .VAR bits_19[40] =     0,    95,   174,   243,   305,   363,   416,   466,   533,   578,   622,   662,   702,   737,   773,   806,   840,   900,   964,  1027,  1081,  1153,  1196,  1238,  1277,  1349,  1416,  1474,  1532,  1582,  1630,  1675,  1717,  1794,  1864,  1928,  1985,  2046,  2106,  2161;
   .VAR bits_20[40] =     0,   103,   189,   266,   336,   401,   462,   538,   595,   648,   700,   747,   794,   837,   881,   927,   974,  1056,  1153,  1221,  1285,  1343,  1400,  1456,  1507,  1603,  1692,  1772,  1846,  1923,  1996,  2073,  2141,  2256,  2367,  2476,  2561,  2638,  2710,  2771;
   .VAR bits_21[40] =     0,   110,   204,   288,   366,   439,   507,   590,   655,   715,   774,   828,   882,   935,   994,  1047,  1098,  1212,  1299,  1381,  1459,  1531,  1602,  1670,  1735,  1864,  1992,  2114,  2228,  2334,  2446,  2529,  2603,  2750,  2879,  2997,  3107,  3208,  3304,  3390;
   .VAR bits_22[40] =     0,   118,   219,   311,   397,   477,   572,   645,   717,   785,   854,   925,   991,  1052,  1110,  1186,  1244,  1350,  1453,  1548,  1642,  1732,  1825,  1912,  1994,  2163,  2330,  2491,  2621,  2738,  2852,  2958,  3060,  3248,  3426,  3580,  3733,  3879,  4012,  4136;
   .VAR bits_23[40] =     0,   124,   231,   329,   421,   507,   608,   687,   765,   838,   914,   991,  1063,  1130,  1213,  1276,  1340,  1457,  1572,  1678,  1789,  1895,  2002,  2106,  2213,  2424,  2596,  2748,  2898,  3036,  3170,  3298,  3424,  3659,  3878,  4081,  4282,  4482,  4678,  4877;
   .ENDBLOCK;

   // -- square root of band widths (just for accuracy)
   .VAR ebands_dif_sqrt[24+2] = 
      -3, 
      0.108253175473055,
      0.108253175473055,
      0.108253175473055,
      0.108253175473055,
      0.108253175473055,
      0.108253175473055,
      0.108253175473055,
      0.125000000000000,
      0.125000000000000,
      0.139754248593737,
      0.153093108923949,
      0.165359456941537,
      0.165359456941537,
      0.187500000000000,
      0.197642353760524,
      0.225346954716499,
      0.250000000000000,
      0.286410980934740,
      0.318688719599549,
      0.342326598440729,
      0.405046293650491,
      0.475985819116494,
      0.562500000000000,
      0.640434422872475,
      0.428478412525065;

   // -- trig data (used in MDCT/IMDCT pre-post rotation)
   .VAR/DM2 trig[12*2] = 
        0.840896415253715,//long block data
        0.648419777325505,
        0.999981175282601,
        0.006135884649154,
        0.999999705862882,
        0.000766990318743,
        0.923585746276257,
        0.383391926460809,
        0.706564229144710,
        0.707648917255684,
        0.381974713146567,
        0.924172775251791, 
               
        0.793700525984100,//short block data
        0.707106781186547, 
        0.999698818696204, 
        0.024541228522912, 
        0.999995293809576, 
        0.003067956762966, 
        0.922701128333879, 
        0.385516053843919, 
        0.704934080375905, 
        0.709272826438866, 
        0.379847208924051, 
        0.925049240782678;
        
   // -- decoder scratch memory allocation (DM1)
   .VAR $celt.dec.celt_512_44100_mode.dm1scratch_alloc[$celt.dec.DM1_SCRATCH_FIELDS_LENGTH] =
      0,    //BITS1
      25,   //BITS2
      1024, //ALG_UNQUANT_ST
      1152, //UVECTOR
      0,    //NORM_FREQ
      1024, //BAND_E
      0,    //IMDCT_OUTPUT
      640,  //SHORT_HIST
      768,  //TEMP_FFT
      0,    //PLC_EXC
      0,    //PLC_PITCH_BUF
      512,  //PLC_XLP4 
      1024, //PLC_AC
      0;    //TRANSIENT_PROC
      
   // -- decoder scratch memory allocation (DM2)
   .VAR $celt.dec.celt_512_44100_mode.dm2scratch_alloc[$celt.dec.DM2_SCRATCH_FIELDS_LENGTH] =
      0,    //PULSES
      25,   //FINE_QUANT
      50,   //FINE_PRIORITY
      640,  //NORM
      0,    //FREQ
      512,  //FREQ2
      1024, //SHORT_FREQ
      0,    //PLC_EXC_COPY
      0,    //PLC_E
      0,    //PLC_YLP4
      512,  //PLC_MEM_LPC
      576,  //PLC_XCORR
      896;  //TEMP_VECT
      
   // -- encoder scratch memory allocation (DM1)
   .VAR $celt.enc.celt_512_44100_mode.dm1scratch_alloc[$celt.dec.DM1_SCRATCH_FIELDS_LENGTH] =               
      1280,  //BITS1
      1305,  //BITS2
      1024,  //ALG_QUANT_ST
      1152,  //UVECTOR_FIELD
      0,     //NORM_FREQ
      1024,  //BANDE
      0,     //MDCT_INPUT_IMAG
      640,   //PREEMPH_LEFT_AUDIO
      1152,  //LOG_BANDE_
      1216,  //BAND_ERROR
      0 ...; //TRANSIENT
      
   // -- encoder scratch memory allocation (DM2)
   .VAR $celt.enc.celt_512_44100_mode.dm2scratch_alloc[$celt.dec.DM2_SCRATCH_FIELDS_LENGTH] =
      1024,  //PULSES
      1050,  //FINE_QUANT
      1088,  //FINE_PRIORITY
      0,     //NORM
      0,     //FREQ
      512,   //FREQ2
      1024,  //SHORT_FREQ
      1536,  //MDCT_INPUT_REAL
      1792,  //PREEMPH_RIGHT_AUDIO
      512,   //ABS_NORM
      0 ...;
.ENDMODULE;
#endif