// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_DEC_INCLUDED
#define CELT_DEC_INCLUDED
// *****************************************************************************
// MODULE:
//    $celt_dec
//
// DESCRIPTION:
//  This module defines short length SCRATCH variables used in the decoder. 
//  Arrays in CELT are passed via the input structure and must be allocated
//  by the application. This is to minimise the memory usage.
// *****************************************************************************
#include "fft.h"
.MODULE $celt.dec;
   .CODESEGMENT CELT_DEC_PM;
   .DATASEGMENT DM;

   // -- Variables for reading from input buffer
   .VAR/DM_SCRATCH get_bytepos;
   .VAR/DM_SCRATCH frame_bytes_remained;
   .VAR/DM_SCRATCH get_bytepos_reverse;
   .VAR/DM_SCRATCH frame_bytes_remained_reverse;

   // -- Address of input celt_dec structure 
   .VAR codec_struc;
   
   // -- reading flags
   .VAR/DM_SCRATCH frame_corrupt;
   
   // -- fft structure
    .VAR fft_struct[$fft.STRUC_SIZE];
   
   // -- Entropy decoding variables
   .VAR/DM_SCRATCH ec_dec.rem;             // The remainder of a buffered input symbol
   .VAR/DM_SCRATCH ec_dec.rng[2];          // The number of values in the current range
   .VAR/DM_SCRATCH ec_dec.dif[2];          // The difference between the input value and the lowest value in the current range
   .VAR/DM_SCRATCH ec_dec.nrm[2];          // Normalization factor
   .VAR/DM_SCRATCH ec_dec.end_byte;        // Byte read from end of frame
   .VAR/DM_SCRATCH ec_dec.end_bits_left;   // Number of bits not read from end
   .VAR/DM_SCRATCH ec_dec.nb_end_bits;     // Number of valid bits in end_byte
   .VAR/DM_SCRATCH ec_dec.ft[2];           // Cumulative frequency of the symbols
   .VAR/DM_SCRATCH ec_dec.fl[2];
   .VAR/DM_SCRATCH ec_dec.fh[2];
   .VAR/DM_SCRATCH ec_dec.ftb;
   
   // -- Variables related to audio output buffers
   .VAR/DM_SCRATCH mono_to_stereo;                // mono to stereo convert
   .VAR/DM_SCRATCH left_obuf_addr;                
   .VAR/DM_SCRATCH left_obuf_len;
   .VAR/DM_SCRATCH left_obuf_start_addr;
   .VAR/DM_SCRATCH right_obuf_addr;
   .VAR/DM_SCRATCH right_obuf_len;
   .VAR/DM_SCRATCH right_obuf_start_addr;
   
   // -- PLC variables
   #ifdef $celt.INCLUDE_PLC
      .VAR/DM_SCRATCH   max_pitch;
      .VAR/DM_SCRATCH   lag;
   #endif   
   
   // -- 
   .VAR/DM_SCRATCH max_sband[2];
   
.ENDMODULE;
#endif
