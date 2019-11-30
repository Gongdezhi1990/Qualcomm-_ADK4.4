// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"
#include "profiler.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_hf_adjustment
//
// DESCRIPTION:
//    Adjusts the new high frequencies that have been added by hf_generation
//
// INPUTS:
//    - r5 current channel (0/1)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r8, r10, rMAC, I0-I7, L0, L4, L5, M0-M3, Div
//    - $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_hf_adjustment;
   .CODESEGMENT AACDEC_SBR_HF_ADJUSTMENT_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_hf_adjustment:

   // push rLink onto stack
   push rLink;

   r1 = -1;
   // if(SBR_bs_frame_class[ch] == SBR_FIXFIX)
   //    SBR_l_A[ch] = -1
   r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_frame_class) + r5];
   Null = r0 - $aacdec.SBR_FIXFIX;
   if Z jump sine_gen_starting_env_assign;
   
#ifdef AACDEC_ELD_ADDITIONS
    // if(SBR_bs_frame_class[ch] == SBR_LDTRAN)
  
   r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_transient_position)+r5];
   r1 = r0 * 4(int) ;
   r1 = r1 + 3;                                 // [bs_transient_position][transientldx]  //transientldx position =  4 *bs_transient_position + 3 from table ld_envelopetable512
    
  r2 = M[$aacdec.ld_envelopetable480 + r1];
  r1 = M[$aacdec.ld_envelopetable512 + r1];
  Null = M[$aacdec.frame_length_flag];
      if NZ r1 = r2;   

   
   jump sine_gen_starting_env_assign;
  
#else
   // elsif(SBR_bs_frame_class[ch] == SBR_VARFIX)
   Null = r0 - $aacdec.SBR_VARFIX;
   if NZ jump not_frame_class_varfix;
      // if(SBR_bs_pointer[ch] > 1)
      //    SBR_l_A[ch] = -1
      // else
      //    SBR_l_A[ch] = SBR_bs_pointer[ch] - 1
      r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_pointer) + r5];
      Null = r0 - 1;
      if GT jump sine_gen_starting_env_assign; 
         r1 = r0 - 1;
         jump sine_gen_starting_env_assign;

   // else
   not_frame_class_varfix:
      // if(SBR_bs_pointer[ch] == 0)
      //    SBR_l_A[ch] = -1
      // else
      //    SBR_l_A[ch] = SBR_bs_num_env[ch] + 1 - SBR_bs_pointer[ch]
      Null = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_pointer) + r5];
      if Z jump sine_gen_starting_env_assign;
         r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
         r1 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_pointer) + r5];
         r0 = r0 + 1;
         r1 = r0 - r1;
#endif 
   sine_gen_starting_env_assign:
   // SBR_l_A[ch] = 'value set above in r1'
   M[($aacdec.tmp_mem_pool + $aacdec.SBR_l_A) + r5] = r1;


  PROFILER_START(&$aacdec.profile_sbr_estimate_current_envelope)
      call $aacdec.sbr_estimate_current_envelope;
  PROFILER_STOP(&$aacdec.profile_sbr_estimate_current_envelope)
   Null = M[$aacdec.frame_corrupt];
   if NZ jump frame_corrupt;

  PROFILER_START(&$aacdec.profile_sbr_calculate_gain)
      call $aacdec.sbr_calculate_gain;
  PROFILER_STOP(&$aacdec.profile_sbr_calculate_gain)
   Null = M[$aacdec.frame_corrupt];
   if NZ jump frame_corrupt;

  PROFILER_START(&$aacdec.profile_sbr_hf_assembly)
      call $aacdec.sbr_hf_assembly;
  PROFILER_STOP(&$aacdec.profile_sbr_hf_assembly)

   frame_corrupt:

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
