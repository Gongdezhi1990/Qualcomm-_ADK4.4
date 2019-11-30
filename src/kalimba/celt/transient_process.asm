// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_TRANSIENT_PROCESS_INCLUDED
#define CELT_TRANSIENT_PROCESS_INCLUDED
#include "stack.h"

// *****************************************************************************
// MODULE:
//    $celt.transient_analysis
//
// DESCRIPTION:
//    analyses if the frame needs to be encoded as short blocks
//
// INPUTS:
//  r5 = pointer to encoder structure
// OUTPUTS:
//
// TRASHED REGISTERS:
//   everything except r5   
// *****************************************************************************
.MODULE $M.celt.transient_analysis;
   .CODESEGMENT CELT_TRANSIENT_ANALYSIS_PM;
   .DATASEGMENT DM;
   $celt.transient_analysis:
   
   r0 = M[r5 + $celt.enc.PREEMPH_LEFT_AUDIO_FIELD];
   I0 = r0;
   r4 = M[r5 + $celt.enc.MODE_OVERLAP_FIELD];
   r0 =  M[r5 + $celt.enc.MODE_AUDIO_FRAME_SIZE_FIELD];
   r4 = r4 + r0;
   M0 = 1;
   r10 = r4 - M0, r0 = M[I0, M0];
   r1 = M[r5 + $celt.enc.TRANSIENT_PROC_FIELD];
   I1 = r1;
   r1 = r0;
   r7 = 0;
   do abs1_loop;
      if NEG r1 = -r1, r0 = M[I0, M0];
      Null = r7 - r1;
      if NEG r7 = r1;
      r1 = r0, M[I1, M0] = r1;
   abs1_loop:
   if NEG r1 = -r1;
   M[I1, M0] = r1;
   r0 = signdet r7;
   r0 = r0 - (23-18);
   Null = r7;
   if Z r0 = 0;
   M[$celt.enc.max_sband + 0] = r0;
   
   Null = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   if Z jump end_rch_proc;
      r0 = M[r5 + $celt.enc.PREEMPH_RIGHT_AUDIO_FIELD];
      I0 = r0;      
      r10 = r4, r0 = M[I0, M0];   
      r1 = M[r5 + $celt.enc.TRANSIENT_PROC_FIELD];
      I1 = r1;
      r7 = 0;
      do abs2_loop;
         r0 = r0 + Null, r1 = M[I1, 0];
         if NEG r0 = -r0;
         Null = r7 - r0;
         if NEG r7 = r0;
         Null = r1 - r0;
         if NEG r1 = r0, r0 = M[I0, M0];         
         M[I1, 1] = r1;         
      abs2_loop:
      r0 = signdet r7;
      r0 = r0 - (23-18);
      Null = r7;
      if Z r0 = 0;
      M[$celt.enc.max_sband + 1] = r0;
   end_rch_proc:
   r1 = M[r5 + $celt.enc.TRANSIENT_PROC_FIELD];//&$celt.enc.begin;
   I1 = r1;
   I0 = r1;
   r10 = r4 - 1;
   r1 = 0;
   Null = r1 - r0, r0 = M[I0, M0];
   do max_loop;
      if NEG r1 = r0, r0 = M[I0, M0];
      Null = r1 - r0, M[I1, M0] = r1;
   max_loop:
   if NEG r1 = r0;
   M[I1, M0] = r1;

   M[r5 + $celt.enc.SHORT_BLOCKS_FIELD] = Null;
   r0 = M[r5 + $celt.enc.MODE_NB_SHORT_MDCTS_FIELD];
   Null = r0 - 2;
   if NEG rts;

   r2 = r1*0.2(frac);
   r6 = M[r5 + $celt.enc.TRANSIENT_PROC_FIELD];//&$celt.enc.begin;
   I0 = r6 + 8;
   I1 = r6;
   r10 = r4 - 16;
   r0 = M[I0, M0];
   do search_loop;
      Null = r0 - r2, r0 = M[I0, M0];
      if NEG I1 = I0;
   search_loop:
   r2 = I1 - r6;
   r2 = r2 - 2;
   r0 = 0;
   r3 = r2 - 32;
   if NEG rts;
   rMAC = 0;
   rMAC0 = r1;
   r3 = r2 + r6;
   r0 = M[r3+(-1)];
   r0 = r0 LSHIFT -1;
   r0 = r0 + 64;
   Div = rMAC/r0;
   r0 = DivResult;
   Null = r0 - 10;
   if NEG rts;
   M[r5 + $celt.enc.TRANSIENT_TIME_FIELD] = r2;
   r1 = 3;
   Null = r0 - 90;
   if NEG r1 = 0;
   M[r5 + $celt.enc.TRANSIENT_SHIFT_FIELD] = r1;
   if Z jump end;
   
   r7 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   r6 = M[r5 + $celt.enc.PREEMPH_LEFT_AUDIO_FIELD];
   chan_win_loop:
      I4 = &$celt.inv_transientWindow;
      I0 = r6 + r2;
      I0 = I0 - 16;
      I1 = I0;
      r10 = 15;
      r0 = M[I0, 1], r1 = M[I4, 1];
      r3 = r0 * r1 (frac);
      do tran_win_loop;
         r0 = M[I0, 1], r1 = M[I4, 1];
         r3 = r0 * r1 (frac), M[I1, M0] = r3;
      tran_win_loop:
      M[I1, M0] = r3;
      r1 = 0.125;
      r10 = r4 - r2, r0 = M[I0, M0];
      r10 = r10 - M0;
      do tran_wing_loop;
         r3 = r1 * r0 (frac), r0 = M[I0, M0];
         M[I1, M0] = r3;
      tran_wing_loop:
      r3 = r1 * r0 (frac);
      M[I1, M0] = r3;
      r6 = M[r5 + $celt.enc.PREEMPH_RIGHT_AUDIO_FIELD];
      r7 = r7 - 1;
   if POS jump chan_win_loop;
   end:
   r0 = $celt.FLAG_SHORT;
   M[r5 + $celt.enc.SHORT_BLOCKS_FIELD] = r0;
   r0 = $celt.FLAG_FOLD;
   M[r5 + $celt.enc.HAS_FOLD_FIELD] = r0;   
   rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.transient_synthesis
//
// DESCRIPTION:
//    applies transient processing for enabled short block
//
// INPUTS:
//  r5 = pointer to decoder structure
//  I5 = output buffer (circular)
//  I0 = hist buffer
//  r0 = transient shift
// OUTPUTS:
//
// TRASHED REGISTERS:
//   everything except r5   
// *****************************************************************************
.MODULE $M.celt.transient_synthesis;
   .CODESEGMENT CELT_TRANSIENT_SYNTHESIS_PM;
   .DATASEGMENT DM;
   $celt.transient_synthesis:
   r4 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
   r3 = M[r5 + $celt.dec.MODE_OVERLAP_FIELD];
   
   // copy output to scratch
   r2 = M[r5 + $celt.dec.TRANSIENT_PROC_FIELD];
   M3 = r2;
   I1 = r2; //scratch memory
   r10 = r4;                  //r10 = N
   I4 = I5;                   //I4 = save(I5)
   I3 = I0;                   //I3 = save(I0)
   do read_buf_loop;
      r2 = M[I5, 1];
      M[I1, 1] = r2;   
   read_buf_loop:
   
   // copy hist to scratch
   r10 = r3;
   do read_hist_loop;
      r2 = M[I0, 1];
      M[I1, 1] = r2;   
   read_hist_loop:
   
   //apply transient window and shift to first 16 samples
   r2 = M[r5 + $celt.dec.TRANSIENT_TIME_FIELD];
   I1 = M3 - 16;
   I1 = I1 + r2;     //16 samples before t time
   r10 = 16;                               //wlen
   I6 = &$celt.transientWindow;         //w
   r6 = 1.0;                               
   do transient_win_loop;
      r2 = M[I1, 0], r1 = M[I6, 1];        //r2 = x , r1 = w
      rMAC = r1*r2;                        //rMAC = x*w
      rMAC = rMAC ASHIFT r0 (56bit);               //rMAC = x*w<<n
      rMAC = rMAC - r1*r2;                 //rMAC = x*w((1<<n) - 1)
      rMAC = rMAC + r6*r2;                 //rMAC = x*(1+w*((1<<n) - 1)
      M[I1, 1] = rMAC;                     //save
   transient_win_loop:
   // apply transient shift to the rest of buffer
   r10 = r3 + r4;                           //r10 = N + O
   r1 = M[r5 + $celt.dec.TRANSIENT_TIME_FIELD];
   r10 = r10 - r1; //r10 = N + O -t
   r10 = r10 - 1;
   r1 = M[I1, 0];                           //x
   I6 = I1 + 1;                              
   M0 = 1;
   do shift_transient_loop;
      r1 = r1 ASHIFT r0, r2 = M[I6, 1];    //r1=x<<n, r2 = next x
      r1 = r2, M[I1, M0] = r1;             //save previous, x=next x
   shift_transient_loop:
   r1 = r1 ASHIFT r0;
   M[I1, M0] = r1;
   
   //write back from processed buffer to output
   I1 = M3; //scratch memory
   I5 = I4;
   I0 = I3;
   r10 = r4;
   do write_buf_loop;
      r2 = M[I1, 1];
      M[I5, 1] = r2;   
   write_buf_loop:
   //write back from processed buffer to hist buf
   r10 = r3;
   do write_hist_loop;
      r2 = M[I1, 1];
      M[I0, 1] = r2;   
   write_hist_loop:
   rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.mdct_shape
//
// DESCRIPTION:
//    shape mdct bins for short blocks if necessary
//
// INPUTS:
//  r5 = pointer to decoder structure
// OUTPUTS:
//
// TRASHED REGISTERS:
//   everything except r5    
// *****************************************************************************
.MODULE $M.celt.mdct_shape;
   .CODESEGMENT CELT_MDCT_SHAPE_PM;
   .DATASEGMENT DM;
   $celt.mdct_shape: 
   // push rLink onto stack
   $push_rLink_macro;
   
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   I6 = r0 + 1;
   r0 = M[r5 + $celt.dec.MODE_NB_SHORT_MDCTS_FIELD];
   M0 = r0;
   r0 = M[r5 + $celt.dec.MODE_SHORT_MDCT_SIZE_FIELD];
   I7 = r0;
   r4 = M[r5 + $celt.dec.MDCT_WEIGHT_SHIFT_FIELD];
   r4 = -r4;
   r0 = M[r5 + $celt.dec.MDCT_WEIGHT_POS_FIELD];
   M1 = r0 + 1; //end point
   r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
   I3 = r0 + M1; //X
   NULL = r8;
   if Z jump setup_done;   
      I3 = r0 + M0;
      M1 = M0 - M1;
   setup_done:   
   chan_shape_loop:
      M2 = M1;
      block_loop: 
         r10 = I7 - 1;
         I4 = I3 - M2;
         I2 = I4;
         r0 = M[I2, M0];
         do shift_loop;
            r1 = r0 ASHIFT r4, r0 = M[I2, M0];
            M[I4, M0] = r1; 
         shift_loop:
         r1 = r0 ASHIFT r4; 
         M[I4, M0] = r1;
         M2 = M2 - 1;
      if NZ jump block_loop;
      r0 = M[r5 + $celt.dec.MODE_MDCT_SIZE_FIELD];
      I3 = I3 + r0;
      I6 = I6 - 1;
   if NZ jump chan_shape_loop;
   call $celt.renormalise_bands;
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.transient_block_process
//
// DESCRIPTION:
//
// INPUTS:
// OUTPUTS:
//
// TRASHED REGISTERS:
//   everything except r5   
// *****************************************************************************
.MODULE $M.celt.transient_block_process;
   .CODESEGMENT CELT_TRANSIENT_BLOCK_PROCESS_PM;
   .DATASEGMENT DM;
   $celt.transient_block_process:
   // push rLink onto stack
   $push_rLink_macro;
    r2 = 0;  // 
    r3 = 1;  //
    Null = M[r5 + $celt.enc.TRANSIENT_SHIFT_FIELD];
    if NZ jump  set_weight_pos;
    r4 = M[r5 + $celt.enc.NORM_FREQ_FIELD];
    I2 = r4;
    r6 = M[r5 + $celt.enc.MODE_NB_SHORT_MDCTS_FIELD];
    M0 = r6;
    M2 = 1;
    r7 = 1.0; //sum(m)
    r1 = 1.0/64;    
    block_loop:
       r10 = M[r5 + $celt.enc.MODE_SHORT_MDCT_SIZE_FIELD];
       r10 = r10 - M2, r0 = M[I2, M0];
       rMAC = 0;
       do calc_abssum_loop;
          Null = r0;
          if NEG r0 = -r0;
          rMAC = rMAC + r0*r1, r0 = M[I2, M0];
       calc_abssum_loop:
       Null = r0;
       if NEG r0 = -r0;
       rMAC = rMAC + r0*r1, r0 = M[I2, M0];
       r4 = r4 + 1;
       I2 = r4;
       r8 = r7 ASHIFT 3;
       Null = rMAC - r8;
       if LE jump check_lower_w;
          r2 = 2;
          r3 = M0 - r6;
          jump end;
       check_lower_w:
       Null = r2 - 2;
       if POS jump end;
       r8 = r7 ASHIFT 1;
       Null = rMAC - r8;
       if LE jump end;
          r2 = 1;
          r3 = M0 - r6;        
    end:
    r7 = rMAC;
    r6 = r6 - 1;
    if NZ jump block_loop;
    set_weight_pos:
    r8 = $celt.CELT_ENCODER;
    r3 = r3 - 1;
    M[r5 + $celt.enc.MDCT_WEIGHT_POS_FIELD] = r3;
    M[r5 + $celt.enc.MDCT_WEIGHT_SHIFT_FIELD] = r2;
    if NZ call  $celt.mdct_shape;
    

   // pop rLink from stack
   jump $pop_rLink_and_rts;
 .ENDMODULE;
#endif

