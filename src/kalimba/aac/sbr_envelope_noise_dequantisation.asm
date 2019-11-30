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
//    $aacdec.sbr_envelope_noise_dequantisation
//
// DESCRIPTION:
//    Decode envelope and noise floor scalefactors
//
// INPUTS:
//    - r5 current channel (0/1)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r4, r6-r8, r10, I1-I6, M3
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_envelope_noise_dequantisation;
   .CODESEGMENT AACDEC_SBR_ENVELOPE_NOISE_DEQUANTISATION_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_envelope_noise_dequantisation:


   // push rLink onto stack
   push rLink;

   #ifdef AACDEC_SBR_Q_DIV_TABLE_IN_FLASH
      r0 = &$aacdec.sbr_q_div_table_rows;
      r2 = M[$flash.windowed_data16.address];
      call $flash.map_page_into_dm;
      M3 = r0;
   #endif

   // SBR_E_orig_mantissa over-writes SBR_E_envelope
   r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_E_envelope_base_ptr) + r5];
   M[($aacdec.sbr_np_info + $aacdec.SBR_E_orig_mantissa_base_ptr) + r5] = r1;
   I2 = r1;


   // amp_res is either 0 or 1, we use this to decide how much to divide
   // SBR_E_envelope[][] by.
   // if amp_res = 0.  Divide by 2,  i.e. left shift by -1 = shift_amp
   // if amp_res = 1.  Divide by 1,  i.e. left shift by  0 = shift_amp
   r6 = M[($aacdec.sbr_info + $aacdec.SBR_amp_res) + r5];
   r6 = r6 - 1;

   // for l=0:SBR_bs_num_env[ch]-1,
   r7 = 0;
   e_orig_outer_loop:
      // for k=0:SBR_num_env_bands[SBR_bs_freq_res[ch][l]]-1,
      r0 = r5 * 6 (int);
      r0 = r0 + r7;
      r0 = M[($aacdec.sbr_info + $aacdec.SBR_bs_freq_res) + r0];
      r10 = M[($aacdec.sbr_info + $aacdec.SBR_num_env_bands) + r0];

      // SBR_E_orig_mantissa
      I1 = I2;

      do e_orig_inner_loop;

         // r3 = SBR_E_envelope[ch][k][l]
         r3 = M[I1, 0];
         // exp = SBR_E_envelope[ch][k][l] << shift_amp
         r0 = r3 LSHIFT r6;
         // if((exp < 0)||(exp >= 64))
         Null = r0;
         if NEG jump zero_e_orig_value;
            Null = r0 - 64;
            if GE jump zero_e_orig_value;
               // SBR_E_orig[ch][k][l] = 2 ^ (exp + SBR_E_deg_offset)
               r0 = r0 + ($aacdec.SBR_E_deg_offset - 5);

               // store with mantissa shifted 11 bits left
               r1 = 2048;

               // if((amp==-2)&&(bitand(SBR_E_envelope[ch][k][l],1)==1))
               Null = r6 + 1;
               if NZ jump e_orig_value_assigned;
                  Null = r3 AND 1;
                  if Z jump e_orig_value_assigned;
                     // SBR_E_orig[ch][k][l] *= sqrt(2)
                     //   because mantissa is known to be 2^11 just set the
                     //   mantissa to sqrt(2)*2^11 = 2896
                     r1 = 2896;

                     jump e_orig_value_assigned;
            zero_e_orig_value:
               // SBR_E_orig[ch][k][l] = 0
               // SBR_E_orig over-writes SBR_E_envelope
               r0 = 0;
               r1 = 0;
         e_orig_value_assigned:

         // store E_orig value as [23---Exponent----8][7---Mantissa---0]
         r0 = r0 LSHIFT 12;
         r1 = r1 + r0;

         M[I1, 0] = r1;

         I1 = I1 + 1;

      e_orig_inner_loop:


   r0 = M[$aacdec.sbr_info + ($aacdec.SBR_num_env_bands+1)];
   I2 = I2 + r0;

   r7 = r7 + 1;
   r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
   Null = r0 - r7;
   if GT jump e_orig_outer_loop;


   // SBR_Q_orig over-writes SBR_Q_envelope
   r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_Q_envelope_base_ptr) + r5];
   I5 = r1;

   r0 = r5 * 10 (int);
   I2 = (&$aacdec.sbr_np_info + $aacdec.SBR_Q_orig) + r0;

   I3 = (&$aacdec.sbr_np_info + $aacdec.SBR_Q_orig2) + r0;


   // for l=0:SBR_bs_num_noise[ch]-1,
   r7 = 0;
   #ifdef AACDEC_SBR_Q_DIV_TABLE_IN_FLASH
      r8 = 9;
   #endif
   r4 = 6;
   q_orig_outer_loop:

      // SBR_Q_orig
      I1 = I2;
      // SBR_Q_orig2
      I4 = I3;
      // SBR_Q_envelope
      I6 = I5;

      // for k=0:SBR_Nq-1,
      r10 = M[$aacdec.sbr_info + $aacdec.SBR_Nq];
      r3 = M[I6, 1];

      do q_orig_inner_loop;

         // if(SBR_Q_envelope[ch][k][l] < 0)||(SBR_Q_envelope[ch][k][l] > 30))
         Null = r3;
         if NEG jump zero_q_orig_value;
            Null = r3 - 30;
            if GT jump zero_q_orig_value;
               call $aacdec.sbr_read_qdiv_tables;
               M[I1, 1] = r1,
                M[I4, 1] = r0;
               jump q_orig_value_assigned;
         zero_q_orig_value:
            // SBR_Q_orig[ch][k][l] = 0
            r0 = 0;
            M[I1, 1] = r0,
             M[I4, 1] = r0;
         q_orig_value_assigned:
         r3 = M[I6, 1];

      q_orig_inner_loop:

   I2 = I2 + $aacdec.SBR_Nq_max;
   I3 = I3 + $aacdec.SBR_Nq_max;
   I5 = I5 + $aacdec.SBR_Nq_max;


   r7 = r7 + 1;
   r0 = r5 + $aacdec.SBR_bs_num_noise;
   r0 = M[$aacdec.tmp_mem_pool + r0];
   Null = r0 - r7;
   if GT jump q_orig_outer_loop;


   // pop rLink from stack
   jump $pop_rLink_and_rts;



.ENDMODULE;

#endif
