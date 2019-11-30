// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_MDCT_ANALYSIS_INCLUDED
#define CELT_MDCT_ANALYSIS_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.mdct_analysis
//
// DESCRIPTION:
//    applies the follwing processes into the input audio frame
//    - windowing
//    - overlap
//    - mdct transform
// INPUTS:
//   r5 = pointer to the input celt encoder structure
// OUTPUTS:
//   None
// TRASHED REGISTERS:
//    everything except r5    
// *****************************************************************************
.MODULE $M.celt.mdct_analysis;
   .CODESEGMENT CELT_MDCT_ANALYSIS_PM;
   .DATASEGMENT DM;
   $celt.mdct_analysis:
   // push rLink onto stack
   $push_rLink_macro;
 
   // -- some local variables
   .VAR ch_inp_buf;
   .VAR ch_out_buf;
   .VAR ch_counter;
   .VAR block_counter;
   
   M[ch_counter] = Null;
   r0 = M[r5 + $celt.enc.PREEMPH_LEFT_AUDIO_FIELD];
   M[ch_inp_buf] = r0;
   r0 = M[r5 + $celt.enc.FREQ_FIELD];
   M[ch_out_buf] = r0;
   chan_process:
   
      // -- scale the input if needed
      call scale_in;

      // -- different procedure for short blocks
      Null = M[r5 + $celt.enc.SHORT_BLOCKS_FIELD];
      if NZ jump short_proc;   
   
      // -- Window and reshuffle for MDCT 
      r0 = M[r5 + $celt.enc.MDCT_INPUT_REAL_FIELD];
      I6 = r0;
      r0 = M[r5 + $celt.enc.MDCT_INPUT_IMAG_FIELD];
      I7 = r0;
      r8 = M[r5 + $celt.enc.MODE_MDCT_SIZE_FIELD];
      r0 = M[ch_inp_buf];
      I0 = r0;
      call $celt.window_reshuffle;
  
      // -- MDCT spectrum analysis
      r0 = M[r5 + $celt.enc.MDCT_INPUT_REAL_FIELD];
      I6 = r0;
      r0 = M[r5 + $celt.enc.MDCT_INPUT_IMAG_FIELD];
      I7 = r0;
      r8 = M[r5 + $celt.enc.MODE_MDCT_SIZE_FIELD]; //N2
      r0 = M[ch_out_buf];
      I0 = r0;    
      r0 = M[ch_counter];
      r4 = M[$celt.enc.max_sband + r0];
      r0 = M[r5 + $celt.enc.MDCT_FUNCTION_FIELD];
      call r0;
      jump ch_end;
   
      short_proc:
      // -- short block mdct analysis
      r0 = M[r5 + $celt.enc.MODE_NB_SHORT_MDCTS_FIELD];
      r0 = r0 - 1;
      M[block_counter] = r0;
      block_loop:
         // -- Window and reshuffle for MDCT 
         r1 = M[r5 + $celt.enc.MDCT_INPUT_REAL_FIELD];
         I6 = r1;
         r1 = M[r5 + $celt.enc.MDCT_INPUT_IMAG_FIELD];
         I7 = r1;
         r8 = M[r5 + $celt.enc.MODE_SHORT_MDCT_SIZE_FIELD];
         r1 = M[ch_inp_buf];
         r0 = r0 * r8 (int);
         I0 = r1 + r0; 
         call $celt.window_reshuffle;      
      
         // -- MDCT spectrum analysis
         r0 = M[r5 + $celt.enc.MDCT_INPUT_REAL_FIELD];
         I6 = r0;
         r0 = M[r5 + $celt.enc.MDCT_INPUT_IMAG_FIELD];
         I7 = r0;
         r8 = M[r5 + $celt.enc.MODE_SHORT_MDCT_SIZE_FIELD];
         r0 = M[r5 + $celt.enc.SHORT_FREQ_FIELD];
         r1 = M[block_counter];
         r1 = r1 * r8 (int);
         I0 = r0 + r1;     
         r0 = M[ch_counter];
         r4 = M[$celt.enc.max_sband + r0];
         r0 = M[r5 + $celt.enc.MDCT_SHORT_FUNCTION_FIELD];
         call r0;
         r0 = M[block_counter];
         r0 = r0 - 1;
         M[block_counter] = r0;
      if POS jump block_loop;
   
      // -- interleaving
      // r4 = freq
      r4 = M[ch_out_buf];
      I0 = r4;   
      r0 = M[r5 + $celt.enc.SHORT_FREQ_FIELD];
      I4 = r0;
      r6 = M[r5 + $celt.enc.MODE_NB_SHORT_MDCTS_FIELD];
      M1 = r6;
      M2 = 1;
      shortf_outer_loop:
         r10 = M[r5 + $celt.enc.MODE_SHORT_MDCT_SIZE_FIELD];
         r10 = r10 - M2, r0 = M[I4, M2];
         r4 = r4 + 1;
         do shortf_inner_loop;
            r0 = M[I4, M2], M[I0, M1] = r0; 
         shortf_inner_loop:
         M[I0, M1] = r0;
         I0 = r4;
         r6 = r6 - 1;
      if NZ jump shortf_outer_loop;
      ch_end:
      r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
      r1 = M[ch_counter];
      r1 = r1 + 1;
      M[ch_counter] = r1;
      Null = r0 - r1;
      if NEG jump $pop_rLink_and_rts;
      r0 = M[r5 + $celt.enc.PREEMPH_RIGHT_AUDIO_FIELD];
      M[ch_inp_buf] = r0;
      r0 = M[r5 + $celt.enc.FREQ2_FIELD];
      M[ch_out_buf] = r0;
   jump chan_process;

   scale_in:
   // -- scale in the input in order to get the best result from fft module
   // Negative scale factors will be compensated in mdct analysis
   r0 = M[ch_counter];
   r2 = M[$celt.enc.max_sband + r0];      
   if LE rts;
   
   r3 = M[ch_inp_buf];
   I0 = r3;
   r4 = M[r5 + $celt.enc.MODE_OVERLAP_FIELD];
   r0 =  M[r5 + $celt.enc.MODE_AUDIO_FRAME_SIZE_FIELD];
   r10 = r4 + r0;
   M0 = 1;
   r10 = r10 - M0, r0 = M[I0, M0];
   I1 = r3;
   do scale_in_loop;
      r1 = r0 ASHIFT r2, r0 = M[I0, M0];
      M[I1, M0] = r1;
   scale_in_loop:
   r1 = r0 ASHIFT r2;
   M[I1, M0] = r1;
   rts;
.ENDMODULE;
#endif
