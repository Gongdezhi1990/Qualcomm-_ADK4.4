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
//    $aacdec.sbr_analysis_dct_kernel
//
// DESCRIPTION:
//    Carry out the DCT for the analysis filterbank
//
//
// INPUTS:
//    sbr_temp_1 (real)
//    sbr_temp_2 (imag)
//
//
// OUTPUTS:
//    sbr_temp_3 (real)
//    sbr_temp_4 (imag)
//
//
// TRASHED REGISTERS:
//    - all
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_analysis_dct_kernel;
   .CODESEGMENT AACDEC_SBR_ANALYSIS_DCT_KERNEL_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_analysis_dct_kernel:

   // push rLink onto stack
   push rLink;

#ifndef AACDEC_ELD_ADDITIONS
   // ** Perform the following **
   //       sbr_temp_1(i) = [sbr_temp_2(i) * T(i + 64)] + [(sbr_temp_1(i) + sbr_temp_2(i)) * T(i)]
   //       sbr_temp_2(i) = [sbr_temp_1(i) * T(i + 32)] + [(sbr_temp_1(i) + sbr_temp_2(i)) * T(i)]
   // for i = 0-31
   // T = dct4_64_table
   I6 = &$aacdec.dct4_64_table;
   I4 = &$aacdec.sbr_temp_1;
   I5 = &$aacdec.sbr_temp_2;
   I1 = I4;
   I2 = I5;
   M3 = 1;
   call $aacdec.sbr_analysis_dct_kernel_internal_loop;

#else 
   // ******************************************************
   // Rearrange real into real and imag part 
   // ******************************************************
   I5 = &$aacdec.sbr_temp_1;            // real1 
   I4 = &$aacdec.sbr_temp_5 + 15 ;      // imag1
   I2 = I5 + 1;
   I1 = I5;
   r10 = 16;
   do rearrange_before_fft1;
      r1= M[I5,2], r2= M[I2,2];
      M[I4,-1]=r2,  M[I1,1] = r1;
   rearrange_before_fft1:
   
   // ******************************************************
   // Rearrange imag into real and imag part 
   // ******************************************************
   I5 = &$aacdec.sbr_temp_2;            // real2
   I4 = &$aacdec.sbr_temp_6 + 15 ;      // imag2
   I2 = I5 + 1;
   I1 = I5;
   r10 = 16;
   do rearrange_before_fft2;
      r1 = M[I5,2], r2 = M[I2,2];
      M[I4,-1] = r2, M[I1,1] = r1;
   rearrange_before_fft2:
   
   // *****************************************************************************
   // Pre-multiply the inputs
   // *****************************************************************************
   I6 = &$aacdec.dct4_pre_cos;
   I2 = &$aacdec.dct4_pre_sin;
   I3 = &$aacdec.sbr_temp_1;            // real1
   I4 = &$aacdec.sbr_temp_5;            // imag1 
   I1 = &$aacdec.sbr_temp_2;            // real2
   I7 = &$aacdec.sbr_temp_6;            // imag2
   r10 = 16 ;
   do apply_twiddle_before_fft;
      r1 = M[I3,0], r3 = M[I6,1];                              // load real1 , load cos
      rMAC = r1 * r3 , r2 = M[I4,0], r4 = M[I2,1];             // calculate new real1 , load imag1 , load sin
      rMAC = rMAC - r4 * r2;                                   // calculate new real1 = RC + SI
      M[I3,1] = rMAC , rMAC = r2 * r3;                         // write new real1 , calculate new imag1
      rMAC = rMAC + r4 * r1 , r1 = M[I1,0] , r2 = M[I7,0];     // calculate new imag1 = IC - RS , load real2 , load imag2
      
      rMAC = r1 * r3 , M[I4,1] = rMAC;                         // calculate new real2 , write new imag1
      rMAC = rMAC - r4 * r2;                                   // calculate new real2 = RC + SI
      M[I1,1] = rMAC , rMAC = r2 * r3;                         // write new real2 , calculate new imag2
      rMAC = rMAC + r4 * r1;                                   // calculate new imag2 = IC - RS
      M[I7,1] = rMAC;                                          // write new imag2
   apply_twiddle_before_fft:

   r1 = &$aacdec.sbr_temp_1;
   M[$aacdec.fft_pointer_struct + $fft.REAL_ADDR_FIELD] = r1;
   r1 = &$aacdec.sbr_temp_5;
   M[$aacdec.fft_pointer_struct + $fft.IMAG_ADDR_FIELD] = r1;

#endif   // AACDEC_ELD_ADDITIONS

   // ** do fft **
   I7 = &$aacdec.fft_pointer_struct;
   call $math.fft;
   
#ifdef AACDEC_ELD_ADDITIONS 
   r1 = &$aacdec.sbr_temp_2;
   M[$aacdec.fft_pointer_struct + $fft.REAL_ADDR_FIELD] = r1;
   r1 = &$aacdec.sbr_temp_6;
   M[$aacdec.fft_pointer_struct + $fft.IMAG_ADDR_FIELD] = r1;

   // *****************************************************************************
   // Apply FFT 
   // *****************************************************************************
   I7 = &$aacdec.fft_pointer_struct;
   call $math.fft;
#endif 

#ifndef AACDEC_ELD_ADDITIONS

   // ** Perform the following **
   //       out_real(i) = [IM(i) * T(i + 64+96)] + [(RE(i) + IM(i)) * T(i +96)]
   //       out_imag(i) = [RE(i) * T(i + 32+96)] + [(RE(i) + IM(i)) * T(i +96)]
   // for i = 0-15 & 17-31
   //
   //       out_real(16) = (IM(16) - RE(16)) * T(16 +96)
   //       out_imag(16) = (IM(16) + RE(16)) * T(16 +96)
   //
   // RE = real output from fft (need to undo bitreversed order)
   // IM = imag output from fft (need to undo bitreversed order)
   // T  = dct4_64_table
   I1 = BITREVERSE(&$aacdec.sbr_temp_1);
   I2 = BITREVERSE(&$aacdec.sbr_temp_2);
   I4 = &$aacdec.sbr_temp_3;
   I5 = &$aacdec.sbr_temp_4;
   I6 = &$aacdec.dct4_64_table + 96;
#if defined(KAL_ARCH3) || defined(KAL_ARCH5)
   M3 = 1024 * 0x100;
#else
   #error Unsupported architecture
   M3 = 1024;
#endif

   rFLAGS = rFLAGS OR $BR_FLAG;
   call $aacdec.sbr_analysis_dct_kernel_internal_loop;
   rFLAGS = rFLAGS AND $NOT_BR_FLAG;

   // fix for 17th element
   r0 = M[&$aacdec.sbr_temp_1 + 1];
   r1 = M[&$aacdec.sbr_temp_2 + 1];
   r3 = M[$aacdec.dct4_64_table + (96 + 16)];
   r2 = r1 + r0;
   rMAC = r2 * r3;
   M[$aacdec.sbr_temp_3 + 16] = rMAC;
   r2 = r1 - r0;
   rMAC = r2 * r3;
   M[$aacdec.sbr_temp_4 + 16] = rMAC;

#else 
   // *****************************************************************************
   // Do bitreverse on the FFT output
   // *****************************************************************************
   I4 = &$aacdec.sbr_temp_1;
   r1 = I4;
   I0 = &$aacdec.sbr_temp_3;
   r0 = I0;
   call $math.address_bitreverse;
   I0 = r1;
   r10 = 16 ;
   call $math.bitreverse_array;
   
   I4 = &$aacdec.sbr_temp_5;
   r1 = I4;
   I0 = &$aacdec.sbr_temp_4;
   r0 = I0;
   call $math.address_bitreverse;
   r10 = 16 ;
   I0 = r1;
   call $math.bitreverse_array;
   
   I4 = &$aacdec.sbr_temp_2;
   r1 = I4;
   I0 = &$aacdec.sbr_temp_7;
   r0 = I0;
   call $math.address_bitreverse;
   I0 = r1;
   r10 = 16 ;
   call $math.bitreverse_array;
   
   I4 = &$aacdec.sbr_temp_6;
   r1 = I4;
   I0 = &$aacdec.sbr_temp_8;
   r0 = I0;
   call $math.address_bitreverse;
   r10 = 16 ;
   I0 = r1;
   call $math.bitreverse_array;
   
   // *****************************************************************************
   // Post-multiply the outputs
   // *****************************************************************************     
   I6 = &$aacdec.dct4_post_cos;
   I2 = &$aacdec.dct4_post_sin;
   I3 = &$aacdec.sbr_temp_3;
   I4 = &$aacdec.sbr_temp_4;
   I7 = &$aacdec.sbr_temp_7;
   I1 = &$aacdec.sbr_temp_8;
   r10 = 16 ;
   do apply_twiddle_after_fft;
      r1 = M[I3,0] , r3 = M[I6,1] ;                            // load real1 , load cos
      rMAC = r1 * r3 , r2 = M[I4,0] , r4 = M[I2,1];            // calculate new real1 , load imag1 , load sin
      rMAC = rMAC - r4 * r2;                                   // calculate new real1 = RC + SI
      M[I3,1] = rMAC , rMAC = r2 * r3;                         // write new real1 , calculate new imag1
      rMAC = rMAC + r4 * r1 , r1 = M[I7,0], r2 = M[I1,0];      // calculate new imag1 = IC - RS , load real2 , load imag2
               
      rMAC = r1 * r3 , M[I4,1] = rMAC;                         // calculate new real2 , write new imag1
      rMAC = rMAC - r4 * r2;                                   // calculate new real2 = RC + SI
      M[I7,1] = rMAC , rMAC = r2 * r3;                         // write new real2 , calculate new imag2
      rMAC = rMAC + r4 * r1;                                   // calculate new imag2 = IC - RS
      M[I1,1] = rMAC;                                          // write new imag2
   apply_twiddle_after_fft:
          
#endif 

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $aacdec.sbr_analysis_dct_kernel_internal_loop
//
// DESCRIPTION:
//    performs the following windowing calculation:
//
//       real_out(i) = [IM(i) * T(i + 64)] + [(RE(i) + IM(i)) * T(i)]
//       imag_out(i) = [RE(i) * T(i + 32)] + [(RE(i) + IM(i)) * T(i)]
//
//    for i = 0-31
//    where IM = imaginary input
//          RE = real input
//          T = windowing table
//
// INPUTS:
//    I1 - real input
//    I2 - imaginary input
//    I4 - real output
//    I5 - imaginary output
//    I6 - windowing table
//    M3 - modifer for reading input data
//       - 1 for normal use
//       - 1024 if following 32 element fft (bitreversing)
//
// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    - r0-6, rMAC, I1, I2, I4-I7, M0-2.
//
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_analysis_dct_kernel_internal_loop;
   .CODESEGMENT AACDEC_SBR_ANALYSIS_DCT_KERNEL_INTERNAL_LOOP_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_analysis_dct_kernel_internal_loop:

   r10 = 15;
   M0 = 1;
   M1 = -32;
   M2 = 33;
   I7 = I6 + 64;

   r0 = M[I2, M3];                // r0 = IM(i)
   r2 = M[I1, M3],                // r1 = RE(i)
    r3 = M[I6, M0];               // r3 = T(i)

   r6 = r0 + r2,
    r1 = M[I1, M3];               // r1 = RE(i) (for next half loop)
   rMAC = r6 * r3,
    r4 = M[I7, M1];               // r4 = T(i+64)
   rMAC = rMAC + r0 * r4,
    r5 = M[I7, M2];               // r5 = T(i+32)
   rMAC = r6 * r3,
    M[I4, M0] = rMAC,             // real_out(i) = rMAC
    r0 = M[I2, M3];               // r0 = IM(i)
   rMAC = rMAC + r2 * r5,
    r3 = M[I6, M0];               // r3 = T(i)
   M[I5, M0] = rMAC;              // imag_out(i) = rMAC

   do loop;

      r6 = r0 + r1,
       r2 = M[I1, M3];            // r2 = RE(i) (for next half loop)
      rMAC = r6 * r3,
       r4 = M[I7, M1];            // r4 = T(i+64)
      rMAC = rMAC + r0 * r4,
       r5 = M[I7, M2];            // r5 = T(i+32)
      rMAC = r6 * r3,
       M[I4, M0] = rMAC,          // real_out(i) = rMAC
       r0 = M[I2, M3];            // r0 = IM(i)
      rMAC = rMAC + r1 * r5,
       r3 = M[I6, M0];            // r3 = T(i)
      M[I5, M0] = rMAC;           // imag_out(i) = rMAC

      r6 = r0 + r2,
       r1 = M[I1, M3];            // r1 = RE(i) (for next half loop)
      rMAC = r6 * r3,
       r4 = M[I7, M1];            // r4 = T(i+64)
      rMAC = rMAC + r0 * r4,
       r5 = M[I7, M2];            // r5 = T(i+32)
      rMAC = r6 * r3,
       M[I4, M0] = rMAC,          // real_out(i) = rMAC
       r0 = M[I2, M3];            // r0 = IM(i)
      rMAC = rMAC + r2 * r5,
       r3 = M[I6, M0];            // r3 = T(i)
      M[I5, M0] = rMAC;           // imag_out(i) = rMAC

   loop:

   r6 = r0 + r1;
   rMAC = r6 * r3,
    r4 = M[I7, M1];               // r4 = T(i+64)
   rMAC = rMAC + r0 * r4,
    r5 = M[I7, M2];               // r5 = T(i+32)
   rMAC = r6 * r3,
    M[I4, M0] = rMAC;             // real_out(i) = rMAC
   rMAC = rMAC + r1 * r5;
   M[I5, M0] = rMAC;              // imag_out(i) = rMAC

   rts;

.ENDMODULE;

#endif
