// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_ENC_INCLUDED
#define CELT_ENC_INCLUDED
// *****************************************************************************
// MODULE:
//    $celt_enc
//
// DESCRIPTION:
//  This module defines short length SCRATCH variables used in the encoder. 
//  Arrays in CELT are passed via the input structure and must be allocated
//  by the application. This is to minimise the memory usage.
// *****************************************************************************
#include "fft.h"
.MODULE $celt.enc;
   .CODESEGMENT CELT_ENC_PM;
   .DATASEGMENT DM;

   .VAR codec_struc;
   
   // -- Variables related to audio output buffers
   .VAR/DM_SCRATCH stereo_to_mono;                // stereo to mono convert 
   .VAR/DM_SCRATCH left_ibuf_addr;                
   .VAR/DM_SCRATCH left_ibuf_len;
   .VAR/DM_SCRATCH left_ibuf_start_addr;                
   .VAR/DM_SCRATCH right_ibuf_addr;
   .VAR/DM_SCRATCH right_ibuf_len;
   .VAR/DM_SCRATCH right_ibuf_start_addr;
  
   .VAR fft_struct[$fft.STRUC_SIZE];
   
   // -- Entropy decoding variables
   .VAR/DM_SCRATCH ec_enc.rem;             // The remainder of a buffered input symbol
   .VAR/DM_SCRATCH ec_enc.rng[2];          // The number of values in the current range
   .VAR/DM_SCRATCH ec_enc.low[2];
   .VAR/DM_SCRATCH ec_enc.ext;
   .VAR/DM_SCRATCH ec_enc.end_byte;        // Byte read from end of frame
   .VAR/DM_SCRATCH ec_enc.end_bits_left;   // Number of bits not read from end
   .VAR/DM_SCRATCH ec_enc.nb_end_bits;     // Number of valid bits in end_byte
   .VAR/DM_SCRATCH ec_enc.ft[2];           // Cumulative frequency of the symbols
   .VAR/DM_SCRATCH ec_enc.fl[2];
   .VAR/DM_SCRATCH ec_enc.fh[2];
   .VAR/DM_SCRATCH ec_enc.ftb;

   // -- Variables for reading from input buffer
   .VAR/DM_SCRATCH put_bytepos;
   .VAR/DM_SCRATCH frame_bytes_remained;
   .VAR/DM_SCRATCH put_bytepos_reverse;
   .VAR/DM_SCRATCH frame_bytes_remained_reverse;
   
   // --
   .VAR/DM_SCRATCH max_sband[2];
  
.ENDMODULE;
#endif
