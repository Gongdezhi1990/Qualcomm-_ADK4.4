// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"
#include "fft.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_analysis_filterbank
//
// DESCRIPTION:
//    Convert audio samples output from plain AAC decoder into frequency domain
//    information used by the SBR section of the decoder.
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - all including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_analysis_filterbank;
   .CODESEGMENT AACDEC_SBR_ANALYSIS_FILTERBANK_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_analysis_filterbank:

   // push rLink onto stack
   push rLink;

   // set aside some temporary storage for X_sbr_shared_real/imag
   r0 = $aacdec.X_SBR_SHARED_SIZE;
   call $aacdec.tmp_mem_pool_allocate;
   if NEG jump $aacdec.corruption;

   // set I0 and L0 to correct information for WavBlock
   r5 = M[$aacdec.codec_struc];
   r0 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
   r1 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
   r7 = M[&$aacdec.current_channel];
   if NZ r0 = r1;
   M[&$aacdec.tmp + 3] = r7;

   call $cbuffer.get_write_address_and_size;
   M[&$aacdec.tmp] = r0;
   M[&$aacdec.tmp + 1] = r1;


   // set up fft structure for the analysis filterbank
#ifdef AACDEC_ELD_ADDITIONS
   r1= 16;
   M[$aacdec.fft_pointer_struct + $fft.NUM_POINTS_FIELD] = r1;

#else
   r1 = 32;
   M[$aacdec.fft_pointer_struct + $fft.NUM_POINTS_FIELD] = r1;
   r1 = &$aacdec.sbr_temp_1;
   M[$aacdec.fft_pointer_struct + $fft.REAL_ADDR_FIELD] = r1;
   r1 = &$aacdec.sbr_temp_2;
   M[$aacdec.fft_pointer_struct + $fft.IMAG_ADDR_FIELD] = r1;

#endif  // AACDEC_ELD_ADDITIONS


   // store block loop number in tmp[2]
   r1 = $aacdec.SBR_tHFGen;
   M[&$aacdec.tmp + 2] = r1;

   block_loop:


      // store constant referring to channel being worked on in r7
      r7 = M[&$aacdec.tmp + 3];


      // get current write address for x_input_buffer
      r0 = M[&$aacdec.x_input_buffer_write_pointers + r7];
      I4 = r0;
      L4 = $aacdec.X_INPUT_BUFFER_LENGTH;


      /*
      //       WavBlock[1024] (per channel)
      //             _______________________________________________________________________________
      //            |_______________________________________________________________________________
      //             0     31|32    63|64......
      //               \ /
      //               / \
      //       __32|31_____0|__old_____________________________________
      //      |________________________________________________________| x_input_buffer [320] (per channel)  CIRCULAR BUFFER
      //       0           |                                         319
      //               current write pointer
      //
      */
      
      // restore WavBlock position and length
      // WavBlock is the PCM audio output from the AAC core decoder
      r0 = M[&$aacdec.tmp];
      r1 = M[&$aacdec.tmp + 1];
      I0 = r0;
      L0 = r1;

      // copy and scale 32 elements from WavBlock to x_input_buffer
      r10 = 15;
      r1 = (1.0 / (1 << $aacdec.SBR_ANALYSIS_SHIFT_AMOUNT));

      r0 = M[I0, 1];
      r0 = r0 * r1 (frac),
       r2 = M[I0, 1];
      do copy_loop;
         r2 = r2 * r1 (frac),
          M[I4, -1] = r0,
          r0 = M[I0, 1];
         r0 = r0 * r1 (frac),
          M[I4, -1] = r2,
          r2 = M[I0, 1];
      copy_loop:
      r2 = r2 * r1 (frac),
       M[I4, -1] = r0;
      M[I4, 0] = r2;


      // store back WavBlock position
      L0 = 0;
      r0 = I0;
      M[&$aacdec.tmp] = r0;


      // for n=0:63,
      //    u(n) = ( x_input_buffer(ch, n) * QMF_filterbank_window(2*n) ) +  ...
      //           ( x_input_buffer(ch, n+64) * QMF_filterbank_window(2*(n+64))) ) + ...
      //           ( x_input_buffer(ch, n+128) * QMF_filterbank_window(2*(n+128)) ) + ...
      //           ( x_input_buffer(ch, n+192) * QMF_filterbank_window(2*(n+192)) ) + ...
      //           ( x_input_buffer(ch, n+256) * QMF_filterbank_window(2*(n+256)) );
      // end;
      //
      //
      //    sbr_temp_1[32]
      //  -----------------------------------------------------------
      // | u(0) | -u(63) | -u(62) | -u(61) | -u(60) | ......| -u(33) |
      //  -----------------------------------------------------------
      //
      //    sbr_temp_2[32]
      //  -----------------------------------------------------------
      // | u(32) | u(31) | u(30) | u(29) | u(28) | ...........| u(1) |
      //  -----------------------------------------------------------


      // do window function and store in sbr_temp_1 and sbr_temp_2

#ifndef AACDEC_ELD_ADDITIONS
      // ** work out U(0) **
      I1 = &$aacdec.QMF_filterbank_window;
      I2 = &$aacdec.sbr_temp_1;
      M0 = 64;
      M1 = 128;
      M2 = -128;
      M3 = -255;

      r0 = M[I4,M0],
       r1 = M[I1,M1];        // win(0)
      rMAC = r0 * r1,
       r0 = M[I4, M0],
       r2 = M[I1, M1];       // win(128)
      rMAC = rMAC + r0 * r2,
       r0 = M[I4, M0],
       r1 = M[I1, M1];       // win(256)
      rMAC = rMAC + r0 * r1,
       r0 = M[I4, M0];
      rMAC = rMAC - r0 * r1, // win(384) = -win(256) = -r1
       r0 = M[I4, M3];
      rMAC = rMAC - r0 * r2; // win(512) = -win(128) = -r2
      M[I2, 0] = rMAC;



      // ** work out U(1) to U(32) **
      I1 = &$aacdec.QMF_filterbank_window + 2;
      I2 = &$aacdec.QMF_filterbank_window + 254;
      I5 = &$aacdec.sbr_temp_2 + 31;
      M3 = -254;

      r10 = 32;
      r0 = M[I4,M0],
       r1 = M[I1,M1];
      do window_loop1;
         rMAC = r0 * r1,
          r0 = M[I4, M0],
          r1 = M[I1, M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4, M0],
          r1 = M[I1, M3];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4, M0],
          r1 = M[I2, M2];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4, M0],
          r1 = M[I2, M2];
         r2 = M[I4, 1];          //dummy read
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I1,M1];
         I2 = I2 - M3,
          M[I5, -1] = rMAC;
      window_loop1:



      // ** work out -U(33) to -U(63) **
      I2 = &$aacdec.QMF_filterbank_window + 318;
      I5 = &$aacdec.sbr_temp_1 + 31;
      r10 = 31;
      M3 = +254;

      do window_loop2;
         rMAC = r0 * r1,
          r0 = M[I4, M0],
          r1 = M[I1, M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4, M0],
          r1 = M[I2, M2];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4, M0],
          r1 = M[I2, M2];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4, M0],
          r1 = M[I2, M3];
         I1 = I1 - M3,
          r2 = M[I4, 1];         //dummy read
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I1,M1];
         rMAC = -rMAC;
         M[I5, -1] = rMAC;
      window_loop2:




      // write current input buffer location back
      M1 = 191;          //=255-M0
      r1 = M[I4, M1];
      r1 = I4;
      M[&$aacdec.x_input_buffer_write_pointers + r7] = r1;
      L4 = 0;
     

#else
   
   // I4 holds the current write address for x_input_buffer
   I2 = &$aacdec.temp_u;                                     // pointer to temp_u buffer(length:64)
   I1 = &$aacdec.QMF_filterbank_window;                      // pointer to QMF_filterbank_window
   M0 = 64;
   M3 = -255;
   r2 = I4;
   r10 = 64;  
   do window_loop1;
      r0 = M[I4,M0],
      r1 = M[I1,M0];           // win(0)
      rMAC = r0 * r1,
      r0 = M[I4, M0],
      r1 = M[I1, M0];          // win(64)
      rMAC = rMAC + r0 * r1,
      r0 = M[I4, M0],
      r1 = M[I1, M0];          // win(128)
      rMAC = rMAC + r0 * r1,
      r0 = M[I4, M0],
      r1 = M[I1, M0];
      rMAC = rMAC +r0 * r1,    // win(192) 
      r0 = M[I4, M3],
      r1 = M[I1, M3];
      rMAC = rMAC + r0 * r1;   // win(256) 
      M[I2, 1] = rMAC;
   window_loop1:

   // *****************************************************************************
   // write back the current input buffer location(saved in r2)
   // *****************************************************************************
   I4 = r2;
   r2 = M[I4,-1];
   r2 = I4;
   M[&$aacdec.x_input_buffer_write_pointers + r7] = r2;
   L4 = 0;
   
   // *****************************************************************************
   // Rearrange data from temp_u to form sbr_temp_1 & sbr_temp_2
   // ****************************************************************************
   I1 = &$aacdec.sbr_temp_1;
   I4 = &$aacdec.sbr_temp_2;
   I5 = &$aacdec.temp_u  + 48;
   I3 = &$aacdec.temp_u  + 47;
   
   // *****************************************************************************
   // Rearrange the input - set sbr_temp_1(0:15) and sbr_temp_2(0:15)
   // *****************************************************************************
   r10 = 16;
   M3 = 1;
   do rearrange_1;
      r1 = M[I5,1], r2 = M[I3,-1];
      r4 = r1 + r2;
      M[I1,M3] = r4, r4 = r1 - r2;
      M[I4,1] = r4;
   rearrange_1:
   
   // *****************************************************************************
   // Rearrange the input - set sbr_temp_1(16:31) and sbr_temp_2(16:31)
   // *****************************************************************************      
   I1 = &$aacdec.sbr_temp_1 + 16;
   I4 = &$aacdec.sbr_temp_2 + 16;
   I5 = &$aacdec.temp_u  + 31;
   I3 = &$aacdec.temp_u;
   r10 = 16;
   do rearrange_2;
      r1 = M[I5,-1] , r2 = M[I3,1];
      r4 = r1 - r2;
      r1 = -r1 , M[I1,M3] = r4;
      r4 = r1 - r2;
      M[I4,1] = r4;
   rearrange_2:
   
   // *****************************************************************************
   // swap the sign for the alternate elements of sbr_temp_2
   // *****************************************************************************     
   I2 = &$aacdec.sbr_temp_2 + 1 ;
   I6 = I2;
   r10 = 16;
   r1 = M[I2,2];
   do sign_adjust_imag;
      r1 = -r1;
      M[I6,2] = r1 , r1 = M[I2,2] ;
   sign_adjust_imag:
      

#endif  // AACDEC_ELD_ADDITIONS

      

// ** do DCT **
      call $aacdec.sbr_analysis_dct_kernel;
 



      
      
      // ** Reorder, scale and put data into the X_sbr matrix **
      /*
      //    X_sbr_shared_real [32*SBR_numTimeSlotsRate] (32 for each loop, here one 32 element section shown)
      //    --------------------------------------------------------------------------------------------------
      //   | 2R(0) | -2I(31) | 2R(1) | -2I(30) | 2R(2) | -2I(29) | 2R(3) | ... | -2I(x) | 2R(y) | 0 | ... | 0 |
      //    --------------------------------------------------------------------------------------------------
      //    /__________________________________________________________________________________\
      //    \                                  Kx                                              /
      //    --------------------------------------------------------------------------------------------------
      //   | 2I(0) | -2R(31) | 2I(1) | -2R(30) | 2I(2) | -2R(29) | 2I(3) | ... | -2R(x) | 2I(y) | 0 | ... | 0 |
      //    --------------------------------------------------------------------------------------------------
      //    X_sbr_shared_imag [32*SBR_numTimeSlotsRate] (32 for each loop, here one 32 element section shown)
      //
      //    R(x) = sbr_temp_3(x)
      //    I(x) = sbr_temp_4(x)
      */

      // I2 = beginning of real
      // I3 = end of real
      // I5 = beginning of imag
      // I6 = end of imag
      I2 = &$aacdec.sbr_temp_3;
      I5 = &$aacdec.sbr_temp_4 ;
      
#ifndef AACDEC_ELD_ADDITIONS
      I3 = I2 + 31;
      I6 = I5 + 31;
#else 
      I6 = I5 + 15;
      I7 = &$aacdec.sbr_temp_7 + 15;
      I5 = &$aacdec.sbr_temp_8  ;

#endif // AACDEC_ELD_ADDITIONS
      
      // retrieve block loop number from tmp[2]
      r8 = M[$aacdec.tmp + 2];

      // I1 = write position for X_sbr_shared_real for this loop
      // I4 = write position for X_sbr_shared_imag for this loop
      r0 = r8 * $aacdec.X_SBR_WIDTH (int);
      I1 = r0 + (&$aacdec.sbr_x_real+512);
      I4 = r0 + (&$aacdec.sbr_x_imag+1536);


      // set length = (HF_reconstruction==1) ? Kx : 32
      r4 = 32;
      r0 = M[$aacdec.sbr_info + $aacdec.SBR_kx];
      Null = M[$aacdec.sbr_info + $aacdec.SBR_HF_reconstruction];
      if NZ r4 = r0;


      r10 = r4 ASHIFT -1;
      r5 = r10 ASHIFT 1;
#ifndef AACDEC_ELD_ADDITIONS
      r6 = (1 << $aacdec.SBR_ANALYSIS_POST_SHIFT_AMOUNT);
      r7 = -r6;

      r0 = M[I2, 1],
       r1 = M[I5, 1];
      do rearrange_loop;
         r0 = r0 * r6 (int) (sat),
          r2 = M[I3, -1],
          r3 = M[I6, -1];
         r1 = r1 * r6 (int) (sat),
          M[I1, 1] = r0;
         r3 = r3 * r7 (int) (sat),
          M[I4, 1] = r1;
         r2 = r2 * r7 (int) (sat),
          M[I1, 1] = r3,
          r1 = M[I5, 1];
         M[I4, 1] = r2,
          r0 = M[I2, 1];
      rearrange_loop:
#else
   
   M0 = 1;
   r6 = 2;
   r7 = -r6;
   do rearrange_loop_32;
      r0 = M[I2, 1] , r1 = M[I6, -1];
      r0 = r0 * r6 (int) (sat);
      r1 = r1 * r7 (int) (sat), M[I1,M0] = r0;
      M[I1,M0] = r1 , r0 = M[I5, M0];
      r1 = M[I7, -1], r0 = r0 * r7 (int) (sat);
      r1 = r1 * r6 (int) (sat), M[I4,M0] = r0;
      M[I4,M0] = r1;
   rearrange_loop_32:

#endif  // AACDEC_ELD_ADDITIONS
      
      r10 = 64 - r4;

      Null = r4 - r5;
      if Z jump even_kx;
   
#ifdef AACDEC_ELD_ADDITIONS
         // sort out if kx is odd
        r0 = M[I2, 1] ;
        r0 = r0 * r6 (int) (sat);
        M[I1,M0] = r0;
        r0 = M[I5, M0];
        r0 = r0 * r7 (int) (sat);
        M[I4,M0] = r0;
#else     
        r0 = r0 * r6 (int) (sat);
         r1 = r1 * r6 (int) (sat),
          M[I1, 1] = r0;
         M[I4, 1] = r1;
#endif 

      even_kx:
      r0 = 0;
      do zero_pad_loop;
         M[I1, 1] = r0,
          M[I4, 1] = r0;
      zero_pad_loop:



      // loop again if not yet done SBR_numTimeSlotsRate passes
      r8 = r8 + 1;
      M[$aacdec.tmp + 2] = r8;
   #ifndef AACDEC_ELD_ADDITIONS   
      Null = r8 - ($aacdec.SBR_numTimeSlotsRate+$aacdec.SBR_tHFGen);
   #else 
      r1 = M[$aacdec.SBR_numTimeSlotsRate_eld];
      r1 = r1 + $aacdec.SBR_tHFGen;
      Null = r8 -r1;
    #endif 
   if LT jump block_loop;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
