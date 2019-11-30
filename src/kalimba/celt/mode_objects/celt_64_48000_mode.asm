// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_MODE_64_48000_INCLUDED
#define CELT_MODE_64_48000_INCLUDED

#include "../celt_library.h"
// *****************************************************************************
// MODULE:
//    $celt.celt_64_48000_mode 
//
// DESCRIPTION:
//    Mode object for N=240 and fs = 48000Hz
//
// *****************************************************************************
.MODULE $M.celt.mode.celt_64_48000_mode;
.DATASEGMENT DM;
   // -- Definition of mode object
   .VAR $celt.mode.celt_64_48000_mode[$celt.mode.STRUC_SIZE] = 
      48000,             // Fs
      32,                // overlap
      64,                // mdctSize
      11,                // nbEBands
      5,                 // pitchEnd
      0.8,               // ePredCoef
      12,                // nbAllocVectors
      1,                 // nbShortMdcts
      64,                // shortMdctSize
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
   .VAR eBands[13] =  0,  3,  6,  9,  12,  15,  18,  21,  26,  32,  41,  53,  64;
   
   // -- Allocation vectors
   .VAR allocVectors[132] =       
          1,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0, 
          3,     1,     0,     0,     0,     0,     0,     0,     0,     0,     0, 
          4,     3,     4,     2,     1,     0,     0,     0,     0,     0,     0, 
          6,     4,     5,     3,     1,     1,     0,     0,     0,     0,     0, 
          7,     6,     6,     3,     2,     1,     1,     1,     0,     0,     0, 
         10,     8,     7,     4,     2,     1,     1,     1,     1,     0,     0, 
         12,    10,     7,     4,     3,     2,     2,     3,     2,     0,     0, 
         15,    11,     8,     6,     4,     4,     3,     5,     4,     2,     0, 
         18,    14,    13,    11,     9,     9,     8,    10,     9,     9,     0, 
         20,    20,    20,    15,    11,    10,     9,    13,    13,    13,     8, 
         22,    28,    26,    21,    17,    15,    13,    16,    16,    20,    16, 
         31,    41,    38,    30,    26,    22,    19,    23,    21,    25,    24;
      
   // -- Window
   .VAR/DM2 window[32] =			
      0.000946046318859, 0.008500646799803, 0.023535225540400, 0.045895054936409, 0.075335189700127, 0.111507304012775, 0.153945803642273, 0.202055752277374, 
      0.255105674266815, 0.312227666378021, 0.372427016496658, 0.434602767229080, 0.497579008340836, 0.560145974159241, 0.621108531951904, 0.679338276386261, 
      0.733825266361237, 0.783724606037140, 0.828393936157227, 0.867418646812439, 0.900622248649597, 0.928061485290527, 0.950007319450378, 0.966913163661957, 
      0.979374051094055, 0.988079309463501, 0.993763625621796, 0.997158288955688, 0.998946249485016, 0.999723017215729, 0.999963879585266, 0.999999523162842;
 
   // -- Prob vector     
   .VAR prob[44] =			
          6000,    15200,     5800,    15632, 
          5600,    16072,     5400,    16522, 
          5200,    16978,     5000,    17444, 
          4800,    17918,     4600,    18400, 
          4400,    18892,     4200,    19394, 
          4000,    19906,     9000,     9530, 
          8760,     9934,     8520,    10346, 
          8280,    10766,     8040,    11194, 
          7800,    11630,     7560,    12074, 
          7320,    12528,     7080,    12992, 
          6840,    13466,     6600,    13948;
      
   // -- bits verctors      
   .BLOCK/DM bits;
      .VAR bits_vector_offset[11] =   11,  11, 11, 11, 11, 11, 11, 51,  91, 131, 171;
      .VAR bits_vector_0[40]  =   0,  42,  67,  84,  97, 107, 116, 123, 129, 134, 139, 143, 147, 151, 154, 158, 161, 166, 171, 175, 179, 183, 186, 190, 193, 198, 203, 207, 211, 215, 218, 222, 225, 230, 235, 239, 243, 247, 250, 254;
      .VAR bits_vector_7[40]  =   0,  54,  91, 119, 142, 160, 176, 189, 201, 211, 221, 229, 237, 245, 251, 258, 264, 274, 284, 293, 301, 308, 315, 321, 327, 338, 348, 357, 365, 372, 379, 385, 391, 402, 412, 421, 429, 436, 443, 449;
      .VAR bits_vector_8[40]  =   0,  58,  99, 132, 158, 180, 199, 215, 229, 242, 254, 265, 274, 283, 292, 300, 307, 320, 332, 343, 353, 362, 371, 379, 386, 400, 412, 423, 433, 442, 451, 459, 466, 480, 492, 503, 528, 538, 547, 555;
      .VAR bits_vector_9[40]  =   0,  67, 118, 159, 195, 225, 252, 275, 297, 316, 334, 350, 365, 379, 392, 404, 415, 436, 455, 472, 488, 503, 538, 550, 561, 584, 602, 620, 636, 650, 664, 677, 689, 711, 730, 748, 764, 779, 793, 805;
      .VAR bits_vector_10[40] =   0,  74, 131, 179, 221, 258, 290, 320, 347, 371, 394, 415, 435, 453, 470, 486, 502, 552, 579, 603, 623, 643, 662, 680, 695, 724, 750, 774, 796, 817, 836, 853, 870, 900, 926, 950, 972, 992,1012,1029;
   .ENDBLOCK;

   // -- square root of band widths (just for accuracy)
   .VAR ebands_dif_sqrt[11+2] = 
      -2,
      0.216506350946110,
      0.216506350946110,
      0.216506350946110,
      0.216506350946110,
      0.216506350946110,
      0.216506350946110,
      0.216506350946110,
      0.279508497187474,
      0.306186217847897,
      0.375000000000000,
      0.433012701892219,
      0.414578098794425;
      
   // -- trig data (used in MDCT/IMDCT pre-post rotation)
   .VAR/DM2 trig[12*2] = 
        0.757858283255199,//long block data
        0.757858283255199,
        0.998795456205172,
        0.049067674327418,
        0.999981175282601,
        0.006135884649154,
        0.921514039342042,
        0.388345046698826,
        0.702754744457225,
        0.711432195745216,
        0.377007410216418,
        0.926210242138311,
        
        0.757858283255199,//short block data
        0.757858283255199,
        0.998795456205172,
        0.049067674327418,
        0.999981175282601,
        0.006135884649154,
        0.921514039342042,
        0.388345046698826,
        0.702754744457225,
        0.711432195745216,
        0.377007410216418,
        0.926210242138311;
        
   // -- decoder scratch memory allocation (DM1)
   .VAR $celt.dec.celt_64_48000_mode.dm1scratch_alloc[$celt.dec.DM1_SCRATCH_FIELDS_LENGTH] =
      0,    //BITS1
      19,   //BITS2
      512,  //ALG_UNQUANT_ST
      640,  //UVECTOR
      0,    //NORM_FREQ
      512,  //BAND_E
      512,  //IMDCT_OUTPUT
      768,  //SHORT_HIST
      896,  //TEMP_FFT
      0,    //PLC_EXC
      0,    //PLC_PITCH_BUF
      512,  //PLC_XLP4 
      1024, //PLC_AC
      0;    //TRANSIENT_PROC
      
   // -- decoder scratch memory allocation (DM2)
   .VAR $celt.dec.celt_64_48000_mode.dm2scratch_alloc[$celt.dec.DM2_SCRATCH_FIELDS_LENGTH] =
      0,    //PULSES
      19,   //FINE_QUANT
      38,   //FINE_PRIORITY
      640,  //NORM
      0,    //FREQ
      256,  //FREQ2
      512,  //SHORT_FREQ
      0,    //PLC_EXC_COPY
      0,    //PLC_E
      0,    //PLC_YLP4
      512,  //PLC_MEM_LPC
      576,  //PLC_XCORR
      896;  //TEMP_VECT
      
   // -- encoder scratch memory allocation (DM1)
   .VAR $celt.enc.celt_64_48000_mode.dm1scratch_alloc[$celt.dec.DM1_SCRATCH_FIELDS_LENGTH] =               
      768,  //BITS1
      787,  //BITS2
      512,  //ALG_QUANT_ST
      640,  //UVECTOR_FIELD
      0,    //NORM_FREQ
      806,  //BANDE
      384,  //MDCT_INPUT_IMAG
      0,    //PREEMPH_LEFT_AUDIO
      896,  //LOG_BANDE_
      960,  //BAND_ERROR
      384,  //TRANSIENT
      0 ...;
      
   // -- encoder scratch memory allocation (DM2)
   .VAR $celt.enc.celt_64_48000_mode.dm2scratch_alloc[$celt.dec.DM2_SCRATCH_FIELDS_LENGTH] =
      768,  //PULSES
      787,  //FINE_QUANT
      806,  //FINE_PRIORITY
      256,  //NORM
      256,  //FREQ
      512,  //FREQ2
      0,    //SHORT_FREQ
      768,  //MDCT_INPUT_REAL
      0,    //PREEMPH_RIGHT_AUDIO
      512,  //ABS_NORM
      0 ...;
.ENDMODULE;
#endif
