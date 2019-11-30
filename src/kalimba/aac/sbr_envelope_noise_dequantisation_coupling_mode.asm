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
//    $aacdec.sbr_envelope_noise_dequantisation_coupling_mode
//
// DESCRIPTION:
//    Decode envelope and noise floor scalefactors in coupling mode
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - SBR_E_orig and SBR_Q_orig
//
// TRASHED REGISTERS:
//    - all plus (except r5) first 2 elements of $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_envelope_noise_dequantisation_coupling_mode;
   .CODESEGMENT AACDEC_SBR_ENVELOPE_NOISE_DEQUANTISATION_COUPLING_MODE_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_envelope_noise_dequantisation_coupling_mode:

   // push rLink onto stack
   push rLink;

   #ifdef AACDEC_SBR_Q_DIV_TABLE_IN_FLASH
      r0 = &$aacdec.sbr_q_div_table_rows;
      r2 = M[$flash.windowed_data16.address];
      call $flash.map_page_into_dm;
      M3 = r0;
   #endif

   r0 = I0;
   M[$aacdec.getbits_saved_I0] = r0;
   r0 = L0;
   M[$aacdec.getbits_saved_L0] = r0;
   L0 = 0;

   // left
   // SBR_E_orig_mantissa over-writes SBR_E_envelope
   r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_E_envelope_base_ptr)];
   M[($aacdec.sbr_np_info + $aacdec.SBR_E_orig_mantissa_base_ptr)] = r1;
   I2 = r1;

   // amp0 = -1
   r7 = -1;
   r0 = M[($aacdec.sbr_info + $aacdec.SBR_amp_res)];
   if NZ r7 = 0;  // amp0 = 0
   M[&$aacdec.tmp] = r7;


   // right
   // SBR_E_orig_mantissa over-writes SBR_E_envelope
   r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_E_envelope_base_ptr) + 1];
   M[($aacdec.sbr_np_info + $aacdec.SBR_E_orig_mantissa_base_ptr) + 1] = r1;
   I5 = r1;

   // amp1 = -1
   r6 = -1;
   r0 = M[($aacdec.sbr_info + $aacdec.SBR_amp_res) + 1];
   if NZ r6 = 0;  // amp1 = 0
   M[&$aacdec.tmp + 1] = r6;


   // for l=0:SBR_bs_num_env[1]-1,
   // r7 = 0;

   M0 = 0;
   e_orig_outer_loop:
      // for k=0:SBR_num_env_bands[SBR_bs_freq_res[1][l]]-1,
      r0 = (&$aacdec.sbr_info + $aacdec.SBR_bs_freq_res) + M0;
      r0 = M[r0];
      r10 = M[($aacdec.sbr_info + $aacdec.SBR_num_env_bands) + r0];

      // SBR_E_orig_mantissa(1,:,:)
      I1 = I2;
      // SBR_E_orig_mantissa(2,:,:)
      I7 = I5;

      do e_orig_inner_loop;


         r0 = M[I7, 0], // r3 = SBR_E_envelope[2][k][l]
          r3 = M[I1, 0]; // r3 = SBR_E_envelope[1][k][l]
         // exp1 = SBR_E_envelope[2][k][l] << amp1
         r8 = r0 LSHIFT r6;

         // exp0 = (SBR_E_envelope[1][k][l] << amp0) +1
         r0 = r3 LSHIFT r7;
         r0 = r0 + 1;
         // if((exp0 < 0)||(exp0 >= 64)||(exp1 < 0)||(exp1 > 24))
         if NEG jump zero_e_orig_value;
            Null = r0 - 64;
            if GE jump zero_e_orig_value;
               Null = r8;
               if NEG jump zero_e_orig_value;
                  Null = r8 - 24;
                  if GT jump zero_e_orig_value;
                     // SBR_E_orig[ch][k][l] = 2 ^ (exp0 + SBR_E_deg_offset - 16)
                     r0 = r0 + (($aacdec.SBR_E_deg_offset - 16) + 8);
                     r1 = 0x4000;  // r1 = 2^14

                     // if((amp0==-1)&&(bitand(SBR_E_envelope[1][k][l],1)==1))
                     Null = r7 + 1;
                     if NZ jump e_orig_value_nextstep;
                        Null = r3 AND 1;
                        if Z jump e_orig_value_nextstep;
                           r1 = 0x5a82;
                     e_orig_value_nextstep:
                        rMAC = r1;
                        r4 = M[&$aacdec.sbr_E_pan_tab + r8];
                        call $aacdec.sbr_fp_mult_frac;
                        r8 = 24 - r8;
                        rMAC = r1;
                        r4 = M[&$aacdec.sbr_E_pan_tab + r8];
                        M[I1, 1] = r2;
                        call $aacdec.sbr_fp_mult_frac;

                        jump e_orig_value_assigned;

         zero_e_orig_value:
               // SBR_E_orig[ch][k][l] = 0
               // SBR_E_orig over-writes SBR_E_envelope
               r2 = 0;
               M[I1, 1] = r2;

         e_orig_value_assigned:

         M[I7, 1] = r2;
      e_orig_inner_loop:


   r0 = M[$aacdec.sbr_info + ($aacdec.SBR_num_env_bands+1)];
   I2 = I2 + r0;
   I5 = I5 + r0;

   M0 = M0 + 1;
   r0 = M[$aacdec.sbr_np_info + $aacdec.SBR_bs_num_env];
   Null = r0 - M0;
   if GT jump e_orig_outer_loop;




   // left
   // SBR_Q_orig over-writes SBR_Q_envelope
   r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_Q_envelope_base_ptr)];
   I2 = r1;
   M0 = (&$aacdec.sbr_np_info + $aacdec.SBR_Q_orig);


   I3 = (&$aacdec.sbr_np_info + $aacdec.SBR_Q_orig2);

   // right
   // SBR_Q_orig over-writes SBR_Q_envelope
   r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_Q_envelope_base_ptr) + 1];
   I5 = r1;

   M1 = (&$aacdec.sbr_np_info + $aacdec.SBR_Q_orig) + 10;
   I6 = (&$aacdec.sbr_np_info + $aacdec.SBR_Q_orig2) + 10;

   // for l=0:SBR_bs_num_noise[1]-1,
   r6 = M[$aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_noise];
   r7 = 0;
   #ifdef AACDEC_SBR_Q_DIV_TABLE_IN_FLASH
      r8 = 9;
   #endif
   q_orig_outer_loop:

      // for k=0:SBR_Nq-1,
      r10 = M[$aacdec.sbr_info + $aacdec.SBR_Nq];

      // SBR_Q_orig(1,:,:)
      I1 = I2;
      // SBR_Q_orig2(1,:,:)
      I4 = I3;
      // SBR_Q_orig(2,:,:)
      I7 = I5;
      // SBR_Q_orig2(2,:,:)
      I0 = I6;

      M2 = 0;

      do q_orig_inner_loop;

         // if((SBR_Q_envelope[1][k][l] < 0)||(SBR_Q_envelope[1][k][l] > 30)||(SBR_Q_envelope[2][k][l] < 0)||(SBR_Q_envelope[2][k][l] > 24))
         r3 = M[I1, 1],
          r4 = M[I7, 1];
         Null = r3;
         if NEG jump zero_q_orig_value;
            Null = r3 - 30;
            if GT jump zero_q_orig_value;
               Null = r4;
               if NEG jump zero_q_orig_value;
                  Null = r4 - 24;
                  if GT jump zero_q_orig_value;
                     r4 = r4 ASHIFT -1;

                     call $aacdec.sbr_read_qdiv_tables;

                     M[I4, 1] = r0;
                     r0 = M0 + M2;
                     M[r0] = r1;

                     r4 = 12 - r4;

                     call $aacdec.sbr_read_qdiv_tables;

                     M[I0, 1] = r0;
                     r0 = M1 + M2;
                     M[r0] = r1;

                     jump q_orig_value_assigned;
         zero_q_orig_value:
            // SBR_Q_orig[ch][k][l] = 0
            r0 = 0;

            r1 = M0 + M2;
            M[r1] = Null;

            M[I4, 1] = r0;

            r1 = M1 + M2;
            M[r1] = Null;
            M[I0, 1] = r0;
         q_orig_value_assigned:

         M2 = M2 + 1;

      q_orig_inner_loop:

   r4 = &$aacdec.sbr_info;

   I2 = I2 + $aacdec.SBR_Nq_max;
   I3 = I3 + $aacdec.SBR_Nq_max;
   I5 = I5 + $aacdec.SBR_Nq_max;
   I6 = I6 + $aacdec.SBR_Nq_max;

   M0 = M0 + $aacdec.SBR_Nq_max;
   M1 = M1 + $aacdec.SBR_Nq_max;

   r7 = r7 + 1;
   Null = r6 - r7;
   if GT jump q_orig_outer_loop;



   r0 = M[$aacdec.getbits_saved_I0];
   I0 = r0;
   r0 = M[$aacdec.getbits_saved_L0];
   L0 = r0;


   // pop rLink from stack
   jump $pop_rLink_and_rts;



.ENDMODULE;

#endif
