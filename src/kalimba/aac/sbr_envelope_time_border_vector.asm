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
//    $aacdec.sbr_envelope_time_border_vector
//
// DESCRIPTION:
//    Calculate time borders for each segment
//
// INPUTS:
//    - r5 current channel (0/1)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r3, r6, r7, r10
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_envelope_time_border_vector;
   .CODESEGMENT AACDEC_SBR_ENVELOPE_TIME_BORDER_VECTOR_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_envelope_time_border_vector:

   // SBR_t_E[ch][0] = SBR_RATE * SBR_abs_bord_lead[ch]
   // r6 = SBR_abs_bord_lead[ch]
   r6 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_lead) + r5];
   r1 = r6 * $aacdec.SBR_RATE (int);
   r0 = r5 * 6 (int);
   M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r0] = r1;

   // SBR_t_E[ch][SBR_bs_num_env[ch]] = SBR_RATE * SBR_abs_bord_trail[ch]
   // r3 = SBR_bs_num_env[ch]
   r3 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
   // r7 = SBR_abs_bord_trail[ch]
   r7 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_trail) + r5];
   r1 = r7 * $aacdec.SBR_RATE (int);
   r0 = r0 + r3;
   M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r0] = r1;


   // switch(SBR_bs_frame_class[ch])
   r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_frame_class) + r5];

   // case SBR_FIXFIX
   Null = r0 - $aacdec.SBR_FIXFIX;
   if NZ jump not_case_fixfix;
      // switch(SBR_bs_num_env[ch]
      // case 4
 #ifdef AACDEC_ELD_ADDITIONS
      r6 = M[$aacdec.SBR_numTimeSlots_eld];
      r1 = r6 * 0.25;///to be rounded up in a similar way as the ISO reference code for odd value of SBR_numTimeSlots
      r1 = $aacdec.SBR_RATE  * r1(int);
 #endif 
      r0 = r5 * 6 (int);
      Null = r3 - 4;
      if NZ jump fixfix_not_case_4;
#ifndef AACDEC_ELD_ADDITIONS
         r1 = $aacdec.SBR_RATE * ($aacdec.SBR_numTimeSlots / 4);
#endif//AACDEC_ELD_ADDITIONS
         M[($aacdec.sbr_np_info + $aacdec.SBR_t_E + 1) + r0] = r1;
         r0 = r0 + 1;
         r2 = r1 *2 (int) ;
         M[($aacdec.sbr_np_info + $aacdec.SBR_t_E + 1) + r0] = r2;
         r0 = r0 + 1;
         r2 = r1 *3(int);
         M[($aacdec.sbr_np_info + $aacdec.SBR_t_E + 1) + r0] = r2;
         jump exit;

      fixfix_not_case_4:
      // case 2
      Null = r3 - 2;
      if NZ jump exit;
#ifdef AACDEC_ELD_ADDITIONS
         r1 = r6 *0.5;
         r1 = $aacdec.SBR_RATE  * r1 (int);
#else
        r1 = $aacdec.SBR_RATE * ($aacdec.SBR_numTimeSlots / 2);
#endif //AACDEC_ELD_ADDITIONS
         M[($aacdec.sbr_np_info + $aacdec.SBR_t_E + 1) + r0] = r1;
         jump exit;

   // case SBR_FIXVAR
   not_case_fixfix:
   
#ifdef AACDEC_ELD_ADDITIONS

   r0 = r5 *6 (int);
   // tE(0) = 0;
   r6 = 0;
   M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r0] = r6;
   
   // load L_E(bs_num_env)
   r3 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
   // tE(L_E) = numberTimeSlots;
   r0 = r5 *6 (int);
   r0 = r0 + r3;
   r6 = M[$aacdec.SBR_numTimeSlots_eld];
   M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r0] = r6;
   
   // load bs_transient_position
   r1 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_transient_position) + r5];
   r1 = r1 * 4(int);    // calculate the row
   
   // load the envelope table and set the pointer to the correct row
   r2 = &$aacdec.ld_envelopetable480;
   r0 = &$aacdec.ld_envelopetable512;
   Null = M[$aacdec.frame_length_flag];
   if NZ r0 = r2;
   I2 = r0 + r1;                               // indexing into the correct [row]
   I2 = I2 + 1;                                // indexing into the correct [row][column]
   
   // tE(l) = LD EnvelopeTable[bs_transient_position][l+1] for 0 < l < L_E
   r10 = r3 - 1;
   I1 = $aacdec.sbr_np_info + $aacdec.SBR_t_E;
   r0 = r5 *6 (int);
   r0 = r0 + 1;
   I1 = I1 + r0;
   do set_te_loop;
      r3 = M[I2,1];   // LD EnvelopeTable[bs_transient_position][l+1]
      M[I1,1] = r3;   // tE(l) = LD EnvelopeTable[bs_transient_position][l+1]
   set_te_loop:
   
   jump exit;
   
#else   

   Null = r0 - $aacdec.SBR_FIXVAR;
   if NZ jump not_case_fixvar;
      // if(SBR_bs_num_env[ch] > 1)
      r10 = r3 - 1;
      if LE jump exit;
         // for l=0:SBR_bs_num_env[ch]-2,

         r0 = r5 * 5 (int);
         r2 = r5 * 6 (int);
         r2 = r2 + r10;

         do fixvar_bs_rel_border_loop;
            // r1 = SBR_bs_rel_bord[ch][l]
            r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord) + r0];
            // SBR_bs_rel_bord[ch][l] - SBR_abs_bord_trail[ch]
            Null = r1 - r7;
            if GT jump exit;

            // border -= SBR_bs_rel_bord[ch][l]
            r7 = r7 - r1;
            // SBR_t_E[ch][i] = SBR_RATE * border
            r1 = r7 * $aacdec.SBR_RATE (int);
            M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r2] = r1;
            // i -= 1
            r2 = r2 - 1;
            r0 = r0 + 1;
         fixvar_bs_rel_border_loop:
         jump exit;

   // case SBR_VARFIX
   not_case_fixvar:
   Null = r0 - $aacdec.SBR_VARFIX;
   if NZ jump not_case_varfix;
      // if(SBR_bs_num_env[ch] > 1)
      r10 = r3 - 1;
      if LE jump exit;
         // for l=0:SBR_bs_num_env[ch]-2,

         r0 = r5 * 5 (int);
         r2 = r5 * 6 (int);

         do varfix_bs_rel_border_loop;
            // r1 = SBR_bs_rel_bord[ch][l]
            r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord) + r0];
            // border += SBR_bs_rel_bord[ch][l]
            r6 = r6 + r1;
            r1 = r6 * $aacdec.SBR_RATE (int);
            Null = r1 - ($aacdec.SBR_numTimeSlotsRate + $aacdec.SBR_tHFGen - $aacdec.SBR_tHFAdj);
            if GT jump exit;

            // SBR_t_E[ch][l+1] = SBR_RATE * border;
            M[($aacdec.sbr_np_info + $aacdec.SBR_t_E + 1) + r2] = r1;
            r2 = r2 + 1;
            r0 = r0 + 1;
         varfix_bs_rel_border_loop:
         jump exit;

   // case SBR_VARVAR
   not_case_varfix:
   Null = r0 - $aacdec.SBR_VARVAR;
   if NZ jump exit;

      // if(SBR_bs_num_rel_0[ch]==1)
      r10 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_rel_0) + r5];

      r0 = r5 * 5 (int);
      r2 = r5 * 6 (int);

      // for l=0:SBR_bs_num_rel_0[ch]-1,
      do varvar_bs_num_rel_0_loop;
         r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord_0) + r0];
         // border += SBR_bs_rel_bord_0[ch][l]
         r6 = r6 + r1;

         // if((SBR_RATE*border+SBR_tHFAdj) > (SBR_numTimeSlotsRate+SBR_tHFGen))
         r1 = r6 * $aacdec.SBR_RATE (int);
         Null = r1 - ($aacdec.SBR_numTimeSlotsRate + $aacdec.SBR_tHFGen - $aacdec.SBR_tHFAdj);
         if GT jump do_rel_1;

         // SBR_t_E[ch][l+1] = SBR_RATE * border
         M[($aacdec.sbr_np_info + $aacdec.SBR_t_E + 1) + r2] = r1;
         r2 = r2 + 1;
         r0 = r0 + 1;
      varvar_bs_num_rel_0_loop:


      do_rel_1:
      // if(SBR_bs_num_rel_1[ch]==1)
      r10 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_rel_1) + r5];

      r0 = r5 * 5 (int);
      r2 = r5 * 6 (int);
      // r3 = SBR_bs_num_env[ch]
      r2 = r2 + r3;

      // for l=0:SBR_bs_num_rel_1[ch]
      do varvar_bs_num_rel_1_loop;
         // if(border < SBR_bs_rel_bord_1[ch][l]
         r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord_1) + r0];
         Null = r7 - r1;
         if LT jump exit;

         // border -= SBR_bs_rel_bord_1[ch][l]
         r7 = r7 - r1;
         // SBR_t_E[ch][i] = SBR_RATE * border
         r1 = r7 * $aacdec.SBR_RATE (int);
         M[($aacdec.sbr_np_info + $aacdec.SBR_t_E - 1) + r2] = r1;
         // i -= 1
         r2 = r2 - 1;
         r0 = r0 + 1;
      varvar_bs_num_rel_1_loop:
      
#endif  //AACDEC_ELD_ADDITIONS   

   exit:
   rts;

.ENDMODULE;


#endif  //AACDEC_SBR_ADDITIONS
