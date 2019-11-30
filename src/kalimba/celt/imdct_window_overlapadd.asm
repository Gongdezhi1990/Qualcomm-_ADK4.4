// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_IMDCT_OLA_INCLUDED
#define CELT_IMDCT_OLA_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.imdct_window_overlap_add
//
// DESCRIPTION:
//  applies IMDCT transform to frequency spectrum and builds output
//  by windowing and overlap adding
//
// INPUTS:
//  r5: pointer to decoder structure
//
// OUTPUTS:
// TRASHED REGISTERS:
//   everything except r5
// *****************************************************************************
.MODULE $M.celt.imdct_window_overlap_add;
   .CODESEGMENT CELT_IMDCT_WINDOW_OVERLAP_ADD_PM;
   .DATASEGMENT DM;
   $celt.imdct_window_overlap_add:
   $push_rLink_macro;
   
   // different processing for short blocks
   Null = M[r5 + $celt.dec.SHORT_BLOCKS_FIELD];
   if NZ jump short_block_proc;
   long_block_proc:
   
      // IMDCT transform
      r0 = M[r5 + $celt.dec.FREQ_FIELD];
      I0 = r0;                                       // frequency spectrum
      r0 = M[r5 + $celt.dec.IMDCT_OUTPUT_FIELD];
      I5 = r0;                                       // imdct output
      r8 = M[r5 + $celt.dec.MODE_MDCT_SIZE_FIELD];       
      r6 = 0;                                        // left channel
      r0 = M[r5 + $celt.dec.IMDCT_FUNCTION_FIELD];   // obtain imdct function
      r4 = M[$celt.dec.max_sband + 0];
      call r0;
  
      // -- Apply window+overlap-add
      r0 = M[r5 + $celt.dec.IMDCT_OUTPUT_FIELD];
      I0 = r0;                                // input
      r0 = M[r5 + $celt.dec.HIST_OLA_LEFT_FIELD];
      M3 = r0;              // history
#ifdef BASE_REGISTER_MODE
      r0 = M[$celt.dec.left_obuf_start_addr];
      push r0; 
      pop B5; 
#endif
      r0 = M[$celt.dec.left_obuf_addr];
      r1 = M[$celt.dec.left_obuf_len];
      I5 = r0;                                                    // output buffer
      L5 = r1;

      r8 = M[r5 + $celt.dec.CELT_MODE_OBJECT_FIELD];
      r3 = M[r5 + $celt.dec.MODE_MDCT_SIZE_FIELD];                // audio frame size
      call $celt.windowing_overlapadd;

      // right channel is available?
      Null = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
      if Z jump end_long_proc;
         // IMDCT transform
         r0 = M[r5 + $celt.dec.FREQ2_FIELD];
         I0 = r0;
         // frequency spectrum
         r0 = M[r5 + $celt.dec.IMDCT_OUTPUT_FIELD];
         I5 = r0;                          // imdct output
         r8 = M[r5 + $celt.dec.MODE_MDCT_SIZE_FIELD];          // audio frame size
         r6 = 1;                                               // right channel
         r0 = M[r5 + $celt.dec.IMDCT_FUNCTION_FIELD];          // obtain imdct function
         r4 = M[$celt.dec.max_sband + 1];
         call r0;
         
         // -- Apply window+overlap-add
         r0 = M[r5 + $celt.dec.IMDCT_OUTPUT_FIELD];
         I0 = r0;                               // input
         r0 = M[r5 + $celt.dec.HIST_OLA_RIGHT_FIELD];
         M3 = r0;                // history
#ifdef BASE_REGISTER_MODE
         r0 = M[$celt.dec.left_obuf_start_addr];
         push r0; 
         pop B5; 
#endif
         r0 = M[$celt.dec.right_obuf_addr];
         r1 = M[$celt.dec.right_obuf_len];
         I5 = r0;                                                  // output buffer
         L5 = r1;
         r3 = M[r5 + $celt.dec.MODE_MDCT_SIZE_FIELD];              // audio frame size
         call $celt.windowing_overlapadd;
      end_long_proc:
      jump end;
   short_block_proc:
      // -- Short Blocks processing
      // memory to count block number
      .VAR temp_lp;
      .VAR  ch_no;
      .VAR obuf_addr;
      .VAR obuf_len;  
      .VAR obuf_start;
      .VAR ola_addr;
      M[ch_no] = 0;
      
#ifdef BASE_REGISTER_MODE
      r0 = M[$celt.dec.left_obuf_start_addr];
      M[obuf_start] = r0; 
#endif
      r0 = M[$celt.dec.left_obuf_addr];
      r1 = M[$celt.dec.left_obuf_len];
      M[obuf_addr] = r0;
      M[obuf_len] = r1;
      r0 = M[r5 + $celt.dec.HIST_OLA_LEFT_FIELD];
      M[ola_addr] = r0;
      chan_loop:
         // silence hist, first block overlap add is performed after windowing
         r0 =  0;
         r1 = M[r5 + $celt.dec.SHORT_HIST_FIELD];
         I0 = r1;//&$celt.dec.short_hist;
         r8 = M[r5 + $celt.dec.CELT_MODE_OBJECT_FIELD];
         r10 = M[r5 +$celt.dec.MODE_OVERLAP_FIELD];
         do silent_hist_loop;
            M[I0, 1] = r0;
         silent_hist_loop:
         M[temp_lp] = r0; //block counter
         short_mdct_loop:
            //get short freq inputs
            r1 = M[r5 + $celt.dec.SHORT_FREQ_FIELD];
            I0 = r1;
            r4 = M[r5 +$celt.dec.MODE_NB_SHORT_MDCTS_FIELD];
            M0 = r4;
            M1 = 1;
            r1 = M[r5 + $celt.dec.FREQ_FIELD];
            r8 = M[r5 + $celt.dec.FREQ2_FIELD];
            Null = M[ch_no];
            if NZ r1 = r8;
            I4 = r1 + r0;
            r4 = M[r5 + $celt.dec.MODE_SHORT_MDCT_SIZE_FIELD];
            r10 = r4 - 1;
            r1 = M[I4, M0];
            do copy_short_freq;
               M[I0, M1] = r1, r1 = M[I4, M0];
            copy_short_freq:
            M[I0, 1] = r1;
            
            // -- IMDCT transform
            r1 = M[r5 + $celt.dec.SHORT_FREQ_FIELD];
            I0 = r1;                                           //input
            r1 = M[r5 + $celt.dec.IMDCT_OUTPUT_FIELD];
            I5 = r1;                                           //output
            r8 = r4;                                           //short block size
            r6 = 0;                                            //left channel
            r1 = M[ch_no];
            r0 = M[r5 + $celt.dec.IMDCT_SHORT_FUNCTION_FIELD]; //IMDCT function
            r4 = M[$celt.dec.max_sband + r1];
            call r0;
           
            // window + overlap-add
#ifdef BASE_REGISTER_MODE
            r0 = M[obuf_start]; 
            push r0;
            pop B5;
#endif
            r0 = M[obuf_addr];
            r1 = M[obuf_len];
            I5 = r0;
            L5 = r1;

            r3 = M[r5 + $celt.dec.MODE_SHORT_MDCT_SIZE_FIELD];
            r0 =  M[temp_lp];
            r0 = r0 * r3(int);
            M0 = r0;
            r0 = M[I5, M0];
            r0 = M[r5 + $celt.dec.IMDCT_OUTPUT_FIELD];
            I0 = r0;
            r0 = M[r5 + $celt.dec.SHORT_HIST_FIELD];
            M3 = r0;
            call $celt.windowing_overlapadd;

            // prepare for next block
            r0 = M[temp_lp];
            r0 = r0 + 1;
            M[temp_lp] = r0;
            r1 = M[r5 + $celt.dec.MODE_NB_SHORT_MDCTS_FIELD];
            Null = r1 - r0;
         if NZ jump short_mdct_loop;

         // transient processing if enabled
         r0 = M[obuf_addr];
         I5 = r0;
         r0 = M[r5 + $celt.dec.SHORT_HIST_FIELD];
         I0 = r0;
         r0 = M[r5 + $celt.dec.TRANSIENT_SHIFT_FIELD];
         if NZ call $celt.transient_synthesis;

         // overlap add for first block
         r10 = M[r5 +$celt.dec.MODE_OVERLAP_FIELD];
         r0 = M[obuf_addr];
         I5 = r0;
         r0 = M[r5 + $celt.dec.SHORT_HIST_FIELD];
         I0 = r0;
         r0 = M[ola_addr];
         I1 = r0;
         r7 = 1.0;
         do short_wola_loop;
            rMAC = M[I1, 0], r0 = M[I5, 0]; 
            rMAC = rMAC + r0*r7, r1 = M[I0, 1];
            M[I5, 1] = rMAC, M[I1, 1] = r1;
         short_wola_loop:
         L5 = 0;

#ifdef BASE_REGISTER_MODE
         push Null; 
         pop B5; 

         r0 = M[$celt.dec.right_obuf_start_addr];
         M[obuf_start] = r0; 
#endif       
         r0 = M[$celt.dec.right_obuf_addr];
         r1 = M[$celt.dec.right_obuf_len];
         M[obuf_addr] = r0;
         M[obuf_len] = r1;
         r0 = M[r5 + $celt.dec.HIST_OLA_RIGHT_FIELD];
         M[ola_addr] = r0;      
         r0 = M[ch_no];
         r0 = r0 + 1;
         M[ch_no] = r0;
         r1 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
         Null = r1 - r0;
         if POS jump chan_loop;
   end:
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.dec.windowing_overlapadd
//
// DESCRIPTION:
//    applies windowing and overlap-add to imdct output
//
// INPUTS:
//  r5 = pointer to decoder structure
//  I0 = input
//  I5/L5 = output /circular
//  M3 = hist addr
//  r3 = frame size
// OUTPUTS:
//
// TRASHED REGISTERS:
//   everything except r5    
// *****************************************************************************
.MODULE $M.celt.windowing_overlapadd;
   .CODESEGMENT CELT_WINDOWING_OVERLAPADD_PM;
   .DATASEGMENT DM;
   $celt.windowing_overlapadd:

   // obtain window data
   r0 = M[r5 + $celt.dec.MODE_WINDOW_ADDR_FIELD];
   I3 = r0;
   
   // r8 = overlap_size
   // r6 = overlap size)
   // r4 = frame_size/2
   r8 = M[r5 + $celt.dec.MODE_OVERLAP_FIELD];
   r6 = r8 LSHIFT -1;
   r4 = r3 LSHIFT -1;
    
   // set a few Modify registers
   M0 = 1;
   M1 = -1;
    
   // copy from middle of the window (reverse)
   I1 = I0 + r4;
   I1 = I1 - M0;
   r10 = r4 - r6;
   L4 = L5;
   I4 = I5;
#ifdef BASE_REGISTER_MODE
   push B5;
   pop B4;
#endif 
   M2 = r6 + r4;
   M2 = M2 - M0;
   r0 = M[I4, M2];
   r10 = r10 - M0;
   if LE jump end_copy_q1_loop;
   r0 = M[I1, M1];
   do copy_q1_loop;        
      M[I4, M1] = r0, r0 = M[I1, M1]; 
   copy_q1_loop:
   M[I4, M1] = r0;
   end_copy_q1_loop:
   
   // window and add hist one overlap size
   //I2 = hist(0)
   //I0 = hist(ov - 1)
   //I3 = w1(0)
   //I7 = w2(ov-1)
   I2 = M3;
   I0 = M3 + r8;
   I0 = I0 - M0;
   r7 = 1.0;
   r10 = r6 - M0, r0 = M[I1, M1];                // r0 = x1
   I7 = I3 + r8, rMAC = M[I2, M0];               // rMAC = h1
   I7 = I7 - M0, r2 = M[I3, M0];                 // r2 = w1
   do left_wola_loop;
      rMAC = rMAC - r0*r2, r2 = M[I7, M1], r1 = M[I0, M1];      //rMAC = h1 -x1*w1, r2 = w2, r1 = h2
      rMAC = r0*r2, M[I5, M0] = rMAC, r0 = M[I1, M1];           //yp1 = h1 -x1*w1, rMAC = w2*x1, r0 = x1
      rMAC = rMAC + r7*r1, r2 = M[I3, M0];                      //rMAC = h2 + w2*x1, r2 = w1
      M[I4, M1] = rMAC, rMAC = M[I2, M0];                       //out1 = h2 + w2*x2, rMAC = h2                  
   left_wola_loop:
   rMAC = rMAC - r0*r2, r2 = M[I7, M1], r1 = M[I0, M1];           //rMAC = h1 -x1*w1, r2 = w2, r1 = h2
   rMAC = r0*r2, M[I5, M0] = rMAC;                                //yp1 = h1 -x1*w1, rMAC = w2*x1
   rMAC = rMAC + r7*r1;                                           //rMAC = h2 + w2*x1
   M[I4, M1] = rMAC;                                              //out2 = h2 + w2*x2
   L4 = 0;
#ifdef BASE_REGISTER_MODE
   push Null; 
   pop B4;
#endif   

   // copy from middle of window (forward)
   // I1 = wp(0)
   // I7 = wp(ov - 1)
   I1 = I1 + r4;
   M2 = r4, r0 = M[I1, M0];
   r0 = M[I5, M2];
   r10 = r4 - r6;
   r10 = r10 - M0;
   if LE jump end_copy_bloop; 
   r0 = M[I1, M0];
   do copy_bloop;
      M[I5, M0] = r0, r0 = M[I1, M0];      
   copy_bloop:
   M[I5, M0] = r0;
   end_copy_bloop:

   // window the last ov size and store to hist only
   // I1 = wp(0)
   // I7 = wp(ov-1)
   // I2 = hist(0)
   // I3 = hist(ov-1)
   I4 = I3 - r6;
   I7 = I7 + r6;
   I2 = M3;
   I3 = M3 + r8, r0 = M[I1, M0];
   r10 = r6 - M0; 
   I3 = I3 - M0, r2 = M[I4, M0];                         
   rMAC = r2*r0, r2 = M[I7, M1];
   do left_whist_loop;
      rMAC = r0*r2, M[I3, M1] = rMAC, r2 = M[I4, M0];
      r0 = M[I1, M0];  
      rMAC = r0*r2, r2 = M[I7, M1], M[I2, M0] = rMAC;
   left_whist_loop:
   rMAC = r0*r2, M[I3, M1] = rMAC;
   M[I2, M0] = rMAC;
   rts;
.ENDMODULE;
#endif
