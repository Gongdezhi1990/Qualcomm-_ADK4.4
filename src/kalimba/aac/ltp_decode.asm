// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.ltp_decode
//
// DESCRIPTION:
//    Decode LTP (Long Term Prediction) data
//
// INPUTS:
//    - r4 = pointer to ICS info
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume all including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.ltp_decode;
   .CODESEGMENT AACDEC_LTP_DECODE_PM;
   .DATASEGMENT DM;

   $aacdec.ltp_decode:

   // push rLink onto stack
   push rLink;

   M0 = 1;
 #ifndef AAC_USE_EXTERNAL_MEMORY
   I5 = &$aacdec.tmp_mem_pool;
 #else 
   r1 = M[$aacdec.tmp_mem_pool_ptr];
   I5 = r1 ; // &$aacdec.tmp_mem_pool;
 #endif 
   call $aacdec.windowing;


   r4 = M[$aacdec.current_ics_ptr];

   // select which channel we're using
   r5 = M[$aacdec.codec_struc];
   Null = r4 - &$aacdec.ics_left;
   if NZ jump right_channel;
      // set register for the left channel
      r8 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
      r6 = M[r4 + $aacdec.ics.LTP_INFO_PTR_FIELD];
      if Z jump $pop_rLink_and_rts;
      jump channel_selected;
   right_channel:
      // set register for the right channel
      r8 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
      r6 = M[r4 + $aacdec.ics.LTP_INFO_CH2_PTR_FIELD];
      if Z jump $pop_rLink_and_rts;
   channel_selected:



   // |   last_2048_audio_samples    |  overlap_add   |  zero padding  |
   //  ------------------------------ ---------------- ----------------
   // |<------------2048------------>|<-----1024----->|<-----1024----->|
   //  ------------------------------ ---------------- ----------------
   // |..............................|.................................|
   //                 |<---ltp_lag-->|                  |<---ltp_lag-->|
   //            first_sample                       last_sample
   //                 |<--------------2048------------->|

   // r6 = &ltp_info
   r5 = M[r6 + $aacdec.ltp.COEF_FIELD];
   r0 = M[r6 + $aacdec.ltp.LAG_FIELD];
   r5 = M[$aacdec.ltp_coefs + r5];

   // ** Do possible copying of the 'zero padding' **
   r10 = 1024 - r0;   // 1024 - ltp_lag
   if NEG r10 = 0;
#ifndef AAC_USE_EXTERNAL_MEMORY
   I4 = &$aacdec.tmp_mem_pool + 2047;
#else 
   r2 = M[$aacdec.tmp_mem_pool_ptr];
   I4 = r2 + 2047 ; // &$aacdec.tmp_mem_pool + 2047;
#endif 

   // pad end of input to mdct with zeros to make 2048 samples altogether
   r2 = 0;
   do zero_padding_loop;
      M[I4,-1] = r2;
   zero_padding_loop:


   r1 = 1024 - r0;
   if NEG r1 = 0;
   r1 = r1 + r0;
   r1 = r1 - (1024 - 1);
   I1 = I5 - r1;

   r10 = (1024 + 1) - r1;

   // copy data from the overlap_add buffer applying ltp_coef gain
   r2 = M[I1,-1];
   do overlap_copy_loop;
      // multiply by ltp_coef
      r2 = r2 * r5 (frac);
      r2 = M[I1,-1],
       M[I4,-1] = r2;
   overlap_copy_loop:


   // ** Do possible copying of the 'last_2048_audio_samples' **

   r10 = r0;

   // get pointer to audio buffer
   r0 = r8;
   call $cbuffer.get_write_address_and_size;
   I1 = r0;
   L1 = r1;

   // dummy read to go back ltp_lag samples
   r3 = M[I1,-1];

   // copy data from the audio buffer applying ltp_coef gain
   r2 = M[I1,-1];
   do audio_copy_loop;
      r2 = r2 * r5 (frac);   // multiply by ltp_coef
      r2 = M[I1,-1],
       M[I4,-1] = r2;
   audio_copy_loop:
   L1 = 0;


   // perform windowing of both 1024-sample blocks
   call $aacdec.filterbank_analysis_ltp;

   // if(ics(ch).tns_data_present) call tns_encdec;
   r4 = M[$aacdec.current_ics_ptr];
   M2 = 1;  // flag for encode mode
   Null = M[r4 + $aacdec.ics.TNS_DATA_PTR_FIELD];
   if NZ call $aacdec.tns_encdec;
   Null = M[$aacdec.frame_corrupt];
   if NZ jump frame_corrupt;

   // add scale factor bands of X_est to spec
   // (as defined by ics(ch).ltp_long_used)
#ifndef AAC_USE_EXTERNAL_MEMORY
   I4 = &$aacdec.tmp_mem_pool;
#else 
   r0 = M[$aacdec.tmp_mem_pool_ptr];// ; &$aacdec.tmp_mem_pool;
   I4 = r0;
#endif 
   call $aacdec.ltp_reconstruction;


   frame_corrupt:
   r4 = M[$aacdec.current_ics_ptr];
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
