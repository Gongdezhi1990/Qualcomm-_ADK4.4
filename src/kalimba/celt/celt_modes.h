// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_MODES_HEADER
#define CELT_MODES_HEADER

    // -- Defining mode object structure
   .CONST   $celt.mode.FS_FIELD                         0;    // sampling rate of the stream
   .CONST   $celt.mode.OVERLAP_FIELD                    1;    // overlap size
   .CONST   $celt.mode.MDCT_SIZE_FIELD                  2;    // audio frame size
   .CONST   $celt.mode.AUDIO_FRAME_SIZE_FIELD           2;
   .CONST   $celt.mode.NB_EBANDS_FIELD                  3;    // number of energy bands
   .CONST   $celt.mode.PITCH_END_FIELD                  4;    // pitch end (not use currently)
   .CONST   $celt.mode.E_PRED_COEF_FIELD                5;    // pre/de emphasis coefficient
   .CONST   $celt.mode.NB_ALLOC_VECTORS_FIELD           6;    // number of alloc tables
   .CONST   $celt.mode.NB_SHORT_MDCTS_FIELD             7;    // number of short blocks per frame
   .CONST   $celt.mode.SHORT_MDCT_SIZE_FIELD            8;    // size of short blocks = audio frame size / number of short blocks per frame
   .CONST   $celt.mode.EBANDS_ADDR_FIELD                9;    // address to read enegy bands boundaries
   .CONST   $celt.mode.ALLOC_VECTORS_ADDR_FIELD         10;   // address to read allocation vectors
   .CONST   $celt.mode.WINDOW_ADDR_FIELD                11;   // address to read windowing data
   .CONST   $celt.mode.PROB_ADDR_FIELD                  12;   // address to read prob data
   .CONST   $celt.mode.BITS_VECTORS_ADDR_FIELD          13;   // address to read bit vectors
   .CONST   $celt.mode.EBNADS_DIF_SQRT_ADDRESS_FIELD    14;   // sqrt(diff(bands)), stored for accuracy purposes
   .CONST   $celt.mode.TRIG_ADDRESS_FIELD               15;   // used in pre/post rotation of MDCT data
   .CONST   $celt.mode.STRUC_SIZE                       20;   // four extra fields for non-regular modes

   .CONST   $celt.mode.TRIG_VECTOR_SIZE                 12;

#endif