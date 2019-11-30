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
//    $aacdec.sbr_synthesis_construct_v
//
// DESCRIPTION:
//    constructs the v buffer for the sbr synthesis filterbank
//    (if not in downsampled mode)
//
// INPUTS:
//    - I0 = beginning of part of X_sbr_real to be used
//    - I4 = beginning of part of X_sbr_imag to be used
//    - $aacdec.tmp - 2nd element, write pointer for v_buffer
//                  - 3rd element, length of v_buffer
//
// OUTPUTS:
//    - v_buffer updated
//    - I4 = new write address for v_buffer
//
// TRASHED REGISTERS:
//    - all including the rest of $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_synthesis_construct_v;
   .CODESEGMENT AACDEC_SBR_SYNTHESIS_CONSTRUCT_V_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_synthesis_construct_v:

   // push rLink onto stack
   push rLink;

   // I0 = X_sbr_real
   // I4 = X_sbr_imag
   // need I4 to equal next write address at end



   // ** Entire function does the following **
   //
   // if (header_count == 0) {
   //    num = 32;
   // } else {
   //    num = min(kx_band + m_band, 64);
   // }
   //
   // for (j = 0; j < num; j++)
   // {
   //    X(j) = X_sbr(j);
   // }
   // for (j = num; j < 64; j++)
   // {
   //    X(j) = 0;
   // }
   //
   // for (k = 0; k < 32; k++)
   // {
   //    in_real1(     k) = real(X(2*k    ));
   //    in_imag1(31 - k) = real(X(2*k + 1));
   //    in_real2(     k) = imag(X(63 - (2*k    )));
   //    in_imag2(31 - k) = imag(X(63 - (2*k + 1)));
   // }
   //
   // dct4_kernel(in_real1, in_imag1, out_real1, out_imag1);
   // dct4_kernel(in_real2, in_imag2, out_real2, out_imag2);
   //
   // for (n = 0; n < 32; n++)
   // {
   //    v_buffer(2*n  )       = out_real2(n)    - out_real1(n);
   //    v_buffer(2*n+1)       = out_imag2(31-n) + out_imag1(31-n);
   //    v_buffer(127-(2*n  )) = out_real2(n)    + out_real1(n);
   //    v_buffer(127-(2*n+1)) = out_imag2(31-n) - out_imag1(31-n);
   // }







   r0 = I0;
   M[$aacdec.tmp + 8] = r0;

   I0 = &$aacdec.sbr_temp_2;
   I1 = &$aacdec.sbr_temp_1+31;

   r0 = -1;
   M[$aacdec.tmp + 7] = r0;


   // ** set amount of X_sbr to use **
   // if (header_count == 0) {
   //    num = 32;
   // } else {
   //    num = min(kx_band + m_band, 64);
   // }

   r2 = 32;
   Null = M[&$aacdec.sbr_info + $aacdec.SBR_header_count];     //check header_count
   if Z jump got_r8;
      r2 = M[$aacdec.tmp_mem_pool + $aacdec.SBR_kx_band];
      r1 = M[$aacdec.tmp_mem_pool + $aacdec.SBR_M_band];
      r2 = r2 + r1;
      r1 = r2 - $aacdec.SBR_K;
      if GT r2 = r2 - r1;
   got_r8:

   r1 = r2 ASHIFT -1;
   M[$aacdec.tmp + 9] = r1;
   r1 = r1 ASHIFT 1;
   r2 = r2 - r1;
   M[$aacdec.tmp + 10] = r2;

#ifndef AACDEC_ELD_ADDITIONS

   outer_repeat_loop:

      // ** Copy and scale data from X_sbr **
      //
      // for (j = 0; j < num; j++)
      // {
      //    X(j) = X_sbr(j);
      // }
      // for (j = num; j < 64; j++)
      // {
      //    X(j) = 0;
      // }
      // for (k = 0; k < 32; k++)
      // {
      //     in_real1(     k) = real(X_sbr(2*k    ))/64;
      //     in_imag1(31 - k) = real(X_sbr(2*k + 1))/64;
      //     in_real2(     k) = imag(X_sbr(63 - (2*k    )))/64;
      //     in_imag2(31 - k) = imag(X_sbr(63 - (2*k + 1)))/64;
      // }
      //
      // in_real2 and in_imag2 on first time around loop
      // in_real1 and in_imag1 on second time around loop


      r2 = 0.0625;         // = (1/64)*4   multiply by 4 since dct_kernel returns 1/4 of correct value

      r10 = M[$aacdec.tmp + 9];
      r8 = r10 - 32;
      r10 = r10 - 1;

      r1 = M[I4, 1];
      r1 = r1 * r2 (frac),
       r0 = M[I4, 1];
      do copy_loop;

         r0 = r0 * r2 (frac),
          M[I0, 1] = r1,
          r1 = M[I4, 1];

         r1 = r1 * r2 (frac),
          M[I1,-1] = r0,
          r0 = M[I4, 1];

      copy_loop:
      r0 = r0 * r2 (frac),
       M[I0, 1] = r1,
       r1 = M[I4, 1];
      r1 = r1 * r2 (frac),
       M[I1,-1] = r0;

      r10 = -r8;
      r0 = 0;
      I4 = I1;
      Null = M[$aacdec.tmp +10];
      if Z jump even_loops;
         r10 = r10 - 1;
         M[I0, 1] = r1,
          M[I4,-1] = r0;
      even_loops:
      do zeros_loop;
         M[I0, 1] = r0,
          M[I4,-1] = r0;
      zeros_loop:


      // ** Do DCT_kernel **
      call $aacdec.sbr_analysis_dct_kernel;


      // ** Copy back section **
      // for (n = 0; n < 32; n++)
      // {
      //    v_buffer(2*n  )       = out_real2(n)    - out_real1(n);
      //    v_buffer(127-(2*n  )) = out_real2(n)    + out_real1(n);
      //    v_buffer(2*n+1)       = out_imag2(31-n) + out_imag1(31-n);
      //    v_buffer(127-(2*n+1)) = out_imag2(31-n) - out_imag1(31-n);
      // }

      r0 = M[$aacdec.tmp + 7];
      r0 = r0 + 1;
      M[$aacdec.tmp + 7] = r0;
      if NZ jump second_writeback;

      r0 = M[$aacdec.tmp +1];
      I4 = r0 - 127;
      I5 = r0;
      r0 = M[$aacdec.tmp +2];
      L4 = r0;
      L5 = r0;
      I1 = &$aacdec.sbr_temp_3;
      r4 = -1;

      // for (n = 0; n < 32; n++)
      // {
      //    v_buffer(2*n  )       = out_real2(n);       //first loop
      //    v_buffer(2*n+1)       = out_imag2(31-n);    //second loop
      // }
      repeat_copy_back:

         r10 = 16;
         M1 = -2;

         r0 = M[I1, 1];
         do copy_back_loop;
            r1 = M[I1, 1],
             M[I4, 2] = r0;
            r0 = M[I1, 1],
             M[I4, 2] = r1;
         copy_back_loop:
         r4 = r4 + 1;
         if NZ jump done_copy_back;
            r0 = M[$aacdec.tmp +1];
            I4 = r0 - 63;
            I5 = r0 - 64;
            I1 = &$aacdec.sbr_temp_4;
            jump repeat_copy_back;

      done_copy_back:
      L4 = 0;
      L5 = 0;

      I0 = &$aacdec.sbr_temp_1;
      I1 = &$aacdec.sbr_temp_2+31;
      r0 = M[$aacdec.tmp + 8];
      I4 = r0;

   jump outer_repeat_loop;


   second_writeback:

      // for (n = 0; n < 32; n++)
      // {
      //    v_buffer(2*n  )       = v_buffer(2*n  ) - out_real1(n);     //first loop
      //    v_buffer(127-(2*n  )) = v_buffer(2*n  ) + out_real1(n);     //first loop
      //    v_buffer(2*n+1)       = v_buffer(2*n+1) + out_imag1(31-n);  //second loop
      //    v_buffer(127-(2*n+1)) = v_buffer(2*n+1) - out_imag1(31-n);  //second loop
      // }

      r6 = -127;
      r7 = 0;
      I4 = &$aacdec.sbr_temp_3;
      r8 = -1;

      repeat_second_copy_back:
         r0 = M[$aacdec.tmp +1];
         I0 = r0 + r6;
         I1 = r0 + r7;
         r0 = M[$aacdec.tmp +2];
         L0 = r0;
         L1 = r0;

         r10 = 16;
         M0 = 0;
         M1 = -2;

         r1 = M[I0, 2],
          r0 = M[I4, 1];
         do second_copy_back_loop;
            r2 = r1 - r0,
             r3 = M[I0, M1];
            r1 = r1 + r0,
             M[I0, 2] = r2,
             r4 = M[I4, 1];
            r5 = r3 - r4,
             M[I1, M1] = r1;
            r3 = r3 + r4,
             M[I0, 2] = r5,
             r0 = M[I4, 1];
            M[I1, M1] = r3;
            r1 = M[I0, 2];
         second_copy_back_loop:

         r8 = r8 + 1;
         if NZ jump done_second_copy_back;
         r6 = -63;
         r7 = -64;
         I4 = &$aacdec.sbr_temp_4;
         jump repeat_second_copy_back;

      done_second_copy_back:

      I4 = I1;
      r0 = L0;
      L4 = r0;
      L0 = 0;
      L1 = 0;
      
#else 

   // *****************************************************************************
   // I0 = beginning of part of x_sbr_real to be used
   // I4 = beginning of part of x_sbr_imag to be used
   // $aacdec.tmp - 2nd element, write pointer for v_buffer
   //             - 3rd element, length of v_buffer
   // *****************************************************************************
   
   // *****************************************************************************
   // Calculate DCT and rearrange the outputs for the real part
   // *****************************************************************************
   push I4;
   r0 = M[$aacdec.tmp + 8];
   I0 = r0;
   r8 = 0;
   call $aacdec.sbr.synthesis.dct;
   pop I4;
   
   // *****************************************************************************
   // Calculate DCT and rearrange the outputs for the imaginary part
   // *****************************************************************************
   r8 = 1;
   call $aacdec.sbr.synthesis.dct;
   
   // *****************************************************************************
   // Calculate the difference(real-imag) and write to the v_buffer
   // *****************************************************************************
   r0 = M[$aacdec.tmp + 1];
   I0 = r0;
   M2 = -127;
   r0 = M[I0, M2];
   r1 =  M[$aacdec.tmp +2];
   L0 = r1;
   I1 = $aacdec.synthesis.temp2;
   I5 = $aacdec.synthesis.temp3;
   r10 = 128;
   M1 = 1;
   r1 = M[I1,M1] , r2 = M[I5,M1];             // preload real , preload imag
   do calc_output_loop;
      r0 = r1 - r2 , r1 = M[I1,M1];          // calculate output , read real
      M[I0,M1] = r0 , r2 = M[I5,M1];         // write output , read imag
   calc_output_loop:
   
   r0 = M[$aacdec.tmp + 1];
   I4 = r0;
   r0 = M[I4, M2];           
   r0 = L0;
   L4 = r0;
   L0 = 0;
   L1 = 0;

#endif
   
      

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;


//******************************************************************************
// MODULE:
//    $M.aacdec.sbr.synthesis.dct
//
// DESCRIPTION:
//  Calculates the DCT of the input
//
// INPUTS:
//    - r8 - flag to indicate real/imag calculation (0-real , 1-imag)
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//    - Assume everything
//
// CPU USAGE:
//
// Notes
//******************************************************************************
.MODULE $M.aacdec.sbr.synthesis.dct;

   .CODESEGMENT AACDEC_SBR_SYNTHESIS_CONSTRUCT_V_PM;

$aacdec.sbr.synthesis.dct:

   push rLink;
   push r8;
   
   Null = r8;
   if NZ I0 = I4;
   
   // *****************************************************************************
   // copy the 64 values from x_sbr_real/imag to temp_buffer1
   // *****************************************************************************
   r10 = 64;
   r2 = 0.03125;
   I4 = $aacdec.synthesis.temp1;       // point to start of the temp_buffer1 (length:64)
   r1 = M[I0,1]; 
   r1 = r1 * r2 (frac);                // preload x_sbr_real/imag
   do copy_sbr_input_values;
      M[I4,1] = r1 , r1 = M[I0,1];
      r1 = r1 * r2 (frac);  
   copy_sbr_input_values:
   
   Null = r8;
   if Z jump input_copy_done;
   // *****************************************************************************************
   // Change the sign for the alternate values(starting from second) for imaginary input
   // *****************************************************************************************
   r10 = 32;
   I0 = $aacdec.synthesis.temp1 + 1;       // point to element 2 of the temp_buffer1 (length:64)
   I4 = I0;
   r1 = M[I0,2];                           // preload element 2
   do imag_sign_change_loop;
      r2 = -r1;                            // change the sign
      M[I4,2] = r2 , r1 = M[I0,2];         // write output , read next value
   imag_sign_change_loop:
      
input_copy_done:   
   // *****************************************************************************
   // Generate the DCT inputs sbr_temp_1 and sbr_temp_2
   // *****************************************************************************
   I1 = $aacdec.synthesis.temp1;       // point to start of the temp_buffer1 (length:64)
   I5 = $aacdec.synthesis.temp1 + 63;  // point to end of the temp_buffer1
   I2 = &$aacdec.sbr_temp_1;           // real(length:32)
   I6 = &$aacdec.sbr_temp_2;           // imag(length:32)
   r10 = 32;
   M1 = 2; 
   M2 = -2;
   do dct_input_gen_loop;
      r1 = M[I1,M1] , r2 = M[I5,M2];
      M[I2,1] = r1 , M[I6,1] = r2;
   dct_input_gen_loop: 
   
   // *****************************************************************************
   // Pre-multiply the inputs
   // *****************************************************************************
   I1 = &$aacdec.sbr_temp_1;           // real(length:32)
   I5 = &$aacdec.sbr_temp_2;           // imag(length:32)
   I2 = &$aacdec.dct4_pre_cos_synthesis;
   I6 = &$aacdec.dct4_pre_sin_synthesis;
   r10 = 32;
   r1 = M[I1,0];                          // preload input_real
   do pre_mult_input;
      r3 = M[I2,1] , r4 = M[I6,1];        // load cos , load sin
      rMAC = r1 * r3 , r2 = M[I5,0];      // real = RC , load input_imag
      rMAC = rMAC - r2 * r4;              // real = RC - IS
      rMAC = r2 * r3 , M[I1,1] = rMAC;    // imag = IC , write output_real 
      rMAC = rMAC + r1 * r4;              // imag = IC + RS
      r1 = M[I1,0] , M[I5,1] = rMAC;      // write output_imag , load input_real
   pre_mult_input: 
   
   // *****************************************************************************
   // Apply FFT 
   // *****************************************************************************
   r1 = 32;
   M[$aacdec.fft_pointer_struct + $fft.NUM_POINTS_FIELD] = r1;
   r1 = &$aacdec.sbr_temp_1;
   M[$aacdec.fft_pointer_struct + $fft.REAL_ADDR_FIELD] = r1;
   r1 = &$aacdec.sbr_temp_2;
   M[$aacdec.fft_pointer_struct + $fft.IMAG_ADDR_FIELD] = r1;
   I7 = &$aacdec.fft_pointer_struct;
   call $math.fft;
   
   // *****************************************************************************
   // Do bitreverse on the FFT output
   // *****************************************************************************
   I4 = &$aacdec.sbr_temp_1;
   r1 = I4;
   I0 = &$aacdec.sbr_temp_3;
   r0 = I0;
   call $math.address_bitreverse;
   I0 = r1;
   r10 = 32;
   call $math.bitreverse_array;
   
   I4 = &$aacdec.sbr_temp_2;
   r1= I4;
   I0 = &$aacdec.sbr_temp_4;
   r0= I0;
   call $math.address_bitreverse;
   r10 = 32;
   I0 = r1;
   call $math.bitreverse_array;
   
   // *****************************************************************************
   // Post-multiply the outputs
   // *****************************************************************************
   I1 = &$aacdec.sbr_temp_3;
   I5 = &$aacdec.sbr_temp_4;
   I2 = &$aacdec.dct4_post_cos_synthesis;
   I6 = &$aacdec.dct4_post_sin_synthesis;
   r10 = 32;
   r1 = M[I1,0];                          // preload real
   do post_mult_input;
      r3 = M[I2,1] , r4 = M[I6,1];        // load cos , load sin
      rMAC = r1 * r3 , r2 = M[I5,0];      // real = RC , load imag
      rMAC = rMAC - r2 * r4;              // real = RC - IS
      rMAC = r2 * r3 , M[I1,1] = rMAC;    // imag = IC , write output_real 
      rMAC = rMAC + r1 * r4;              // imag = IC + RS
      r1 = M[I1,0] , M[I5,1] = rMAC;      // write output_imag , load real
   post_mult_input: 
   
   
   pop r8;
   // *****************************************************************************
   // Rearrange the output 
   // *****************************************************************************
   r10 = 32;
   r3 = -1.0;
   I1 = $aacdec.synthesis.temp1;       // point to start of the temp_buffer1 (length:64)
   I5 = $aacdec.synthesis.temp1 + 1;   // point to element 2 of the temp_buffer1 (length:64)
   Null = r8;
   if NZ jump imag_rearrange;
   
real_rearrange:   
   I2 = &$aacdec.sbr_temp_3;           // point to real
   I6 = &$aacdec.sbr_temp_4 + 31;      // point to end of sbr_temp_4
   do output_sort_real;
     r1 = M[I2,1] , r2 = M[I6,-1];
     r2 = r2 * r3;
     M[I1,2] = r1 , M[I5,2] = r2;
   output_sort_real:
   
   jump rearrange_done;
   
imag_rearrange:    
   I2 = &$aacdec.sbr_temp_3 + 31;      // point to end of sbr_temp_3
   I6 = &$aacdec.sbr_temp_4;           // point to sbr_temp_4
   do output_sort_imag;
     r1 = M[I2,-1] , r2 = M[I6,1];
     r2 = r2 * r3;
     M[I1,2] = r2 , M[I5,2] = r1;
   output_sort_imag:

rearrange_done:
   // *****************************************************************************
   // Reconstruct the remaining 64 output samples (first 32 and last 32)
   // *****************************************************************************
reconstruct_real_init:   
   r3 = -1.0;
   r4 = 1.0;
   I1 = $aacdec.synthesis.temp2;           // point to start of temp_buffer2 (length:128)
   Null = r8;
   if Z jump reconstruct_output;
   
reconstruct_imag_init:   
   r3 = 1.0;
   r4 = -1.0;
   I1 = $aacdec.synthesis.temp3;           // point to start of temp_buffer3 (length:128)

reconstruct_output:   
   I2 = $aacdec.synthesis.temp1 + 31;      // point to the middle of temp_buffer1
   I6 = $aacdec.synthesis.temp1 + 63;      // point to the end of temp_buffer1
   I5 = I1 + 96;                           // point to element 96 of temp_buffer2/3
   r10 = 32;
   do reconstruct_output_samples;
      r1 = M[I2,-1] , r2 = M[I6,-1];
      r1 = r1 * r4;
      r2 = r2 * r3;
      M[I1,1] = r1 , M[I5,1] = r2;
   reconstruct_output_samples:
   
   // *****************************************************************************
   // Copy the original 64 output samples (middle 64)
   // *****************************************************************************
   I5 = $aacdec.synthesis.temp2;
   r1 = $aacdec.synthesis.temp3;
   Null = r8;
   if NZ I5 = r1;                     // point to start of temp_buffer2/3 (length:128)
   I1 = $aacdec.synthesis.temp1;
   I5 = I5 + 32; 
   r10 = 64;
   r1 = M[I1,1];                    // preload input
   do copy_original_samples;
      M[I5,1] = r1 , r1 = M[I1,1];  // write output , load input
   copy_original_samples:      
   
   
   jump $pop_rLink_and_rts;


.ENDMODULE;

#endif // AACDEC_SBR_ADDITIONS     