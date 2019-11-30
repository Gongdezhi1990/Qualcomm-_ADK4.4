// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_hf_assembly_initialise_signal_gain_and_component_loop
//
// DESCRIPTION:
//    - initialise the loop which applies the signal (G) and noise (Q) filters as well
//    - as inserts the sinusoidal components (S) across the high-band in the current
//    - time-sample i
//
// INPUTS:
//    -
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    -
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_hf_assembly_initialise_signal_gain_and_component_loop;
   .CODESEGMENT AACDEC_SBR_HF_ASSEMBLY_INITIALISE_SIGNAL_GAIN_AND_COMPONENT_LOOP_PM;
   .DATASEGMENT DM;



   $aacdec.sbr_hf_assembly_initialise_signal_gain_and_component_loop:


   r6 = M[$aacdec.sbr_info + $aacdec.SBR_kx];

   // I1 -> real(X_sbr[ch][SBR_kx][i+SBR_tHFAdj])
   // I4 -> imag(X_sbr[ch][SBR_kx][i+SBR_tHFAdj])

   r0 = M1 + $aacdec.SBR_tHFAdj;
   r0 = r0 * $aacdec.X_SBR_WIDTH (int);
   r0 = r0 + r6;
   I1 = r0 + (&$aacdec.sbr_x_real+512);
   I4 = r0 + (&$aacdec.sbr_x_imag+1536);

   r0 = M[$aacdec.tmp + $aacdec.SBR_calc_gain_boost_data_per_envelope];
   r0 = r0 * r8 (int);
   // I3 -> SBR_S_M_boost_mantissa[l][0]
   r1 = M[$aacdec.tmp_mem_pool + $aacdec.SBR_S_M_boost_mantissa_ptr];
   I3 = r0 + r1;

   // I7 -> SBR_G_filt_mantissa[0]
   r0 = M[$aacdec.tmp_mem_pool + $aacdec.SBR_G_filt_ptr];
   I7 = r0;
   // I2 -> SBR_Q_filt_mantissa[0]
   r0 = M[$aacdec.tmp_mem_pool + $aacdec.SBR_Q_filt_ptr];
   I2 = r0;

   r10 = M[$aacdec.sbr_info + $aacdec.SBR_M];

   r0 = M[$aacdec.tmp + $aacdec.SBR_hf_assembly_noise_component_flag];
   M2 = r0;

   M[$aacdec.tmp + $aacdec.SBR_hf_assembly_save_ch] = r5;

   r0 = M[$aacdec.tmp + $aacdec.SBR_f_index_sine];
   r6 = M[$aacdec.sbr_phi_re_sin + r0];
   r5 = M[$aacdec.sbr_phi_im_sin + r0];
   // SBR_f_index_sine = bitand(SBR_f_index_sine + 1, 3);
   r0 = r0 + 1;
   r0 = r0 AND 3;
   M[$aacdec.tmp + $aacdec.SBR_f_index_sine] = r0;

   r7 = M[$aacdec.tmp + $aacdec.SBR_f_index_noise] + r10;
   r7 = r7 AND 0x1FF;
   M[$aacdec.tmp + $aacdec.SBR_f_index_noise] = r7;

   #ifdef AACDEC_SBR_V_NOISE_IN_FLASH
      I5 = I0 + 512;
   #else
      //I5 = I0 + ($aacdec.V_noise_imag - $aacdec.V_noise_real);
      I5 = I0 - &$aacdec.V_noise_real;
      I5 = I5 + &$aacdec.V_noise_imag;
   #endif

   L0 = 512;
   L5 = 512;

   // if(bitand(SBR_kx, 1) == 1)
   //    rev = 1;
   // else
   //    rev = -1;
   r0 = M[$aacdec.sbr_info + $aacdec.SBR_kx];
   Null = r0 AND 1;
   //if NZ r5 = -r5;
   if Z r5 = -r5;

   // r7 = no. bits to shift the calculated Sinusoidal component by to make it $aacdec.SBR_ANALYSIS_SHIFT_AMOUNT - bits
   // higher than the correct scale like X_sbr is inorder to keep $aacdec.SBR_ANALYSIS_SHIFT_AMOUNT fractional bits
   r4 = M[($aacdec.sbr_info + $aacdec.SBR_S_M_BOOST_BLOCK_EXPONENT_ARRAY_FIELD) + r8];
   r7 = r4 + ($aacdec.SBR_ANALYSIS_SHIFT_AMOUNT - 23);

   M[$aacdec.tmp + $aacdec.SBR_hf_assembly_save_l] = r8;
   r4 = M[$aacdec.sbr_info + $aacdec.SBR_G_FILT_BLOCK_EXPONENT_FIELD];

   // r8 = no. bits to shift the calculated Noise component by to make it $aacdec.SBR_ANALYSIS_SHIFT_AMOUNT - bits
   // higher than the correct scale like X_sbr is inorder to keep $aacdec.SBR_ANALYSIS_SHIFT_AMOUNT fractional bits
   r8 = M[$aacdec.sbr_info + $aacdec.SBR_Q_FILT_BLOCK_EXPONENT_FIELD];
   #ifdef AACDEC_SBR_V_NOISE_IN_FLASH
      r8 = r8 + ($aacdec.SBR_ANALYSIS_SHIFT_AMOUNT-23 + 8);
   #else
      r8 = r8 + ($aacdec.SBR_ANALYSIS_SHIFT_AMOUNT-23);
   #endif



   rts;




.ENDMODULE;

#endif


