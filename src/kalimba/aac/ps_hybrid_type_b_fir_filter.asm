// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS

#include "stack.h"
#include "fft.h"

// *****************************************************************************
// MODULE:
//    $aacdec.ps_hybrid_type_b_fir_filter
//
// DESCRIPTION:
//    - g[n]*cos(2pi/8*q*(n-6))
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - toupdate
//
// *****************************************************************************
.MODULE $M.aacdec.ps_hybrid_type_b_fir_filter;
   .CODESEGMENT AACDEC_PS_HYBRID_TYPE_B_FIR_FILTER_PM;
   .DATASEGMENT DM;



   $aacdec.ps_hybrid_type_b_fir_filter:



   // Initialisation for filtering of the real input samples

   r0 = M[$aacdec.tmp + $aacdec.PS_HYBRID_SUB_SUBBAND_INDEX_OFFSET];
   r0 = r0 * $aacdec.PS_NUM_SAMPLES_PER_FRAME (int);
   // I0 -> real(ps_X_hybrid[ch=0][k=ps_hybrid_sub_subband_index_offset][n=0])
   I0 = &$aacdec.synth_temp + r0;
   // I1 -> real(ps_X_hybrid[ch=0][k=ps_hybrid_sub_subband_index_offset+1][n=0])
   I1 = I0 + $aacdec.PS_NUM_SAMPLES_PER_FRAME;

   r8 = M[$aacdec.tmp + $aacdec.PS_HYBRID_QMF_SUBBAND];
   // I2 -> real(X_SBR[ch=0][k=p][l=SBR_tHFAdj+6])
   I2 = ((&$aacdec.sbr_x_real+640) + (($aacdec.SBR_tHFGen-$aacdec.SBR_tHFAdj)*$aacdec.X_SBR_WIDTH)) + r8;

   M0 = $aacdec.X_SBR_WIDTH;

   // r10 -> real(fir_input[0-(PS_HYBRID_ANALYSIS_FIR_FILTER_LENGTH-1)])
   r10 = M[$aacdec.tmp + $aacdec.PS_HYBRID_QMF_SUBBAND];
   r10 = r10 * ($aacdec.PS_HYBRID_ANALYSIS_FIR_FILTER_LENGTH - 1) (int);
   r10 = r10 + &$aacdec.ps_time_history_real;

   M2 = 1;

   // first outer-loop iteration processed real(fir_input[]) and second iteration processes imag(fir_input[])

   ps_hybrid_type_b_fir_filter_outer_loop:

      I4 = &$aacdec.ps_hybrid_type_b_fir_filter_coefficients;

      // calculate {real | imaginary} filter output for n=0

      r7 = M[r10 + (1 + 0)];   // r7 = fir_input[n-11]
      r6 = M[r10 + (3 + 0)];   // r6 = fir_input[n-9]
      r4 = M[r10 + (5 + 0)];   // r4 = fir_input[n-7]

      M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_FOUR] = r6;
      M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_THREE] = r4;

      r0 = M[r10 + (11 + 0)];  // r0 = fir_input[n-1]
      r1 = M[r10 + (9 + 0)];   // r1 = fir_input[n-3]
      r3 = M[r10 + (6 + 0)];   // r3 = fir_input[n-6]
      r2 = M[r10 + (7 + 0)];   // r2 = fir_input[n-5]
      r5 = M[I4,1];

      M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_TWO] = r1;
      M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_ONE] = r0;

      rMAC = r7 * r5,
       r5 = M[I4,1];
      rMAC = rMAC + r6 * r5,
       r5 = M[I4,0];
      rMAC = rMAC + r4 * r5,
       r5 = M[I4,-1];
      rMAC = rMAC + r2 * r5,
       r5 = M[I4,-1];
      rMAC = rMAC + r1 * r5,
       r5 = M[I4,0];
      rMAC = rMAC + r0 * r5;
      r8 = r3 * 0.5 (frac);
      r5 = r8 + rMAC;
      rMAC = r8 - rMAC;
      M[I0,1] = r5;
      M[I1,1] = rMAC,
       r5 = M[I4,1];

      // calculate {real | imaginary} filter output for n=1

      r7 = M[r10 + (1 + 1)];   // r7 = fir_input[n-11]
      rMAC = r7 * r5,
       r5 = M[I4,1];
      r7 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_FOUR];  // r7 = fir_input[n+1-11]

      r6 = M[r10 + (3 + 1)];   // r6 = fir_input[n-9]
      rMAC = rMAC + r6 * r5,
       r5 = M[I4,0];
      M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_FOUR] = r6;
      r6 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_THREE];   // r6 = fir_input[n+1-9]

      r4 = r3;    // r4 = fir_input[n-7]
      rMAC = rMAC + r4 * r5,
       r5 = M[I4,-1];
      M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_THREE] = r4;

      r3 = r2; // r3 = fir_input[n-6]
      r8 = r3 * 0.5 (frac);
      r4 = r3;  // r4 = fir_input[n+1-7]

      r2 = M[r10 + (7 + 1)];   // r2 = fir_input[n-5]
      rMAC = rMAC + r2 * r5,
       r5 = M[I4,-1];
      r3 = r2; // r3 = fir_input[n+1-6]
      r2 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_TWO];    // r2 = fir_input[n+1-5]

      r1 = M[r10 + (9 + 1)];   // r1 = fir_input[n-3]
      rMAC = rMAC + r1 * r5,
       r5 = M[I4,0];
      M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_TWO] = r1;
      r1 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_ONE];    // r1 = fir_input[n+1-3]

      r0 = M[I2,M0];    // r0 = fir_input[n-1]
      rMAC = rMAC + r0 * r5;
      M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_ONE] = r0;

      r5 = r8 + rMAC;
      rMAC = r8 - rMAC;
      M[I0,1] = r5;
      M[I1,1] = rMAC,
       r5 = M[I4,1];

      // for n=2:PS_NUM_SAMPLES_PER_FRAME-1

      r10 = $aacdec.PS_NUM_SAMPLES_PER_FRAME - 2;

      do ps_hybrid_type_b_fir_time_samples_loop;

         rMAC = r7 * r5,
          r5 = M[I4,1];
         r7 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_FOUR];    // r7 = fir_input[n+1-11]

         rMAC = rMAC + r6 * r5,
          r5 = M[I4,0];
         M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_FOUR] = r6;
         r6 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_THREE];   // r6 = fir_input[n+1-9]

         rMAC = rMAC + r4 * r5,
          r5 = M[I4,-1];
         M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_THREE] = r4;
         r4 = r3;    // r4 = fir_input[n+1-7]

         r8 = r3 * 0.5 (frac);
         r3 = r2;    // r3 = fir_input[n+1-6]

         rMAC = rMAC + r2 * r5,
          r5 = M[I4,-1];
         r2 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_TWO];    // r2 = fir_input[n+1-5]

         rMAC = rMAC + r1 * r5,
          r5 = M[I4,0];

         r0 = M[I2,M0];    // r0 = fir_input[n-1]
         M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_TWO] = r1;
         r1 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_ONE];    // r1 = fir_input[n+1-3]

         rMAC = rMAC + r0 * r5;
         M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_REGISTER_ONE] = r0;

         r5 = r8 + rMAC;
         rMAC = r8 - rMAC;
         M[I0,1] = r5;
         M[I1,1] = rMAC,
          r5 = M[I4,1];

      ps_hybrid_type_b_fir_time_samples_loop:


      Null = M2;
      if Z jump exit_ps_hybrid_type_b_fir_filter;

         // Initialisation for filtering the imaginary input samples

         r0 = M[$aacdec.tmp + $aacdec.PS_HYBRID_SUB_SUBBAND_INDEX_OFFSET];
         r0 = r0 * $aacdec.PS_NUM_SAMPLES_PER_FRAME (int);
         // I0 -> imag(ps_X_hybrid[ch=0][k=ps_hybrid_sub_subband_index_offset][n=0])
         I0 = (&$aacdec.synth_temp + (($aacdec.PS_NUM_HYBRID_SUB_SUBBANDS - 2) * $aacdec.PS_NUM_SAMPLES_PER_FRAME)) + r0;
         // I1 -> imag(ps_X_hybrid[ch=0][k=ps_hybrid_sub_subband_index_offset+1][n=0])
         I1 = I0 + $aacdec.PS_NUM_SAMPLES_PER_FRAME;

         r8 = M[$aacdec.tmp + $aacdec.PS_HYBRID_QMF_SUBBAND];
         // I2 -> imag(X_SBR[ch=0][k=p][l=SBR_tHFAdj+0])
         I2 = ((&$aacdec.sbr_x_imag+1664) + (($aacdec.SBR_tHFGen-$aacdec.SBR_tHFAdj)*$aacdec.X_SBR_WIDTH)) + r8;
         M0 = $aacdec.X_SBR_WIDTH;

         r10 = M[$aacdec.tmp + $aacdec.PS_HYBRID_QMF_SUBBAND];
         r10 = r10 * ($aacdec.PS_HYBRID_ANALYSIS_FIR_FILTER_LENGTH - 1) (int);

         r10 = r10 + &$aacdec.ps_time_history_imag;

         M2 = M2 - 1;
   jump ps_hybrid_type_b_fir_filter_outer_loop;



   exit_ps_hybrid_type_b_fir_filter:


   rts;



.ENDMODULE;

#endif
