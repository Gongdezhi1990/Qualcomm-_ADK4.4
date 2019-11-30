// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_HEADER_INCLUDED
#define CELT_HEADER_INCLUDED

   // -- Defining some constants
   .CONST   $celt.MONO_MODE                                            0;    // mono stream
   .CONST   $celt.STEREO_MODE                                          1;    // stereo stream
   .CONST   $celt.MAX_BANDS                                            25;   // maximum number of critical bands
   .CONST   $celt.MAX_BANDSx2                                          50;   // 2 x maximum number of critical bands
   .CONST   $celt.MAX_PERIOD                                           1024; // max pitch period in samples (twice of)
   .CONST   $celt.NO_RIGHT_CHANNEL                                     0;

   // -- Flag constants
   .CONST   $celt.FLAG_NONE                                            0;
   .CONST   $celt.FLAG_INTRA                                           (1<<13);
   .CONST   $celt.FLAG_PITCH                                           (1<<12);
   .CONST   $celt.FLAG_SHORT                                           (1<<11);
   .CONST   $celt.FLAG_FOLD                                            (1<<10);
   .CONST   $celt.FLAG_MASK                                            ($celt.FLAG_INTRA|$celt.FLAG_PITCH|$celt.FLAG_SHORT|$celt.FLAG_FOLD);

   // -- Constants used by the entropy routines
   .CONST   $celt.EC_SYM_BITS                                          8;
   .CONST   $celt.EC_SYM_BITS_SHIFT                                    3;
   .CONST   $celt.EC_CODE_BITS                                         32;
   .CONST   $celt.EC_SYM_MAX                                           ((1<<$celt.EC_SYM_BITS)-1);
   .CONST   $celt.EC_CODE_BOT                                          0x800000;
   .CONST   $celt.EC_CODE_EXTRA                                        7;
   .CONST   $celt.EC_UNIT_BITS                                         8;
   .CONST   $celt.EC_UNIT_MASK                                         ((1<<$celt.EC_UNIT_BITS)-1);
   .CONST   $celt.BITRES                                               4;
   .CONST   $celt.FINE_OFFSET                                          50;
   .CONST   $celt.QTHETA_OFFSET                                        40;
   .CONST   $celt.MAX_PSEUDOLOG                                        6;
   .CONST   $celt.MAX_PSEUDO                                           40;
   .CONST   $celt.E_MEANS_SIZE                                         5;
   .CONST   $celt.EC_CODE_SHIFT                                        ($celt.EC_CODE_BITS-$celt.EC_SYM_BITS-1);                                  

   
   // -- Constants used in PLC
   .CONST   $celt.PLC_BUFFER_SIZE                                      $celt.MAX_PERIOD;
   .CONST   $celt.PLC_LPC_ORDER                                        12;
   .CONST   $celt.PLC_LPC_SHIFT                                        4;
   .CONST   $celt.PLC_MAX_LOSS_PACKETS                                 3;
   .CONST   $celt.ENABLE_PLC                                           1;
   .CONST   $celt.DISABLE_PLC                                          0;
   
   .CONST   $celt.CELT_DECODER                                         0;
   .CONST   $celt.CELT_ENCODER                                         1;
   .CONST   $celt.MAX_SBAND                                            4;
   // setting
   #define $celt.INCLUDE_PLC
   #define $celt.PLC_EXTRA_DOWNSAMPLE

   //-- Include constants to read mode objects
   #include "celt_modes.h"

   // -- include macros that widely used
   #include "celt_macros.h"


 #endif // CELT_DEC_HEADER_INCLUDED
