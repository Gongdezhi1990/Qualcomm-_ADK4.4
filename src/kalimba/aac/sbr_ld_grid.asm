// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifdef AACDEC_ELD_ADDITIONS

#include "aac_library.h"
#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_ld_grid
//
// DESCRIPTION:
//    Get information about how the current SBR frame is subdivided
//
// INPUTS:
//    - r5 ch
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r4, r6-r8, r10, I1, I4
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_ld_grid;
   .CODESEGMENT AACDEC_LD_SBR_GRID_PM;
   .DATASEGMENT DM;

$aacdec.sbr_ld_grid:

   push rLink;
   // *****************************************************************************
   // extract bs_frame_class
   // *****************************************************************************
   call $aacdec.get1bit;
   M[($aacdec.sbr_np_info + $aacdec.SBR_bs_frame_class) + r5] = r1;
   // *****************************************************************************
   // switch(bs_frame_class)
   // *****************************************************************************
   Null = r1 - $aacdec.SBR_FIXFIX;
   if NZ jump not_fixfix;
   
case_fixfix:
   // *****************************************************************************
   // extract tmp
   // *****************************************************************************
   call $aacdec.get2bits;           // output is in r1
   r10 = 1 LSHIFT r1;
    r1 = r10 - 4;
    if GT r10 = r10 - r1;
    M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5] = r10;
    r8 = r10;
   
   // *****************************************************************************
   // if (bs_num_env[ch] == 1) 
   // *****************************************************************************
   Null = r10 - 1;
   if NZ jump bsampres_cal_not_reqd;
   
   // *****************************************************************************
   // extract bs_amp_res
   // *****************************************************************************
   call $aacdec.get1bit;
   M[($aacdec.sbr_info  + $aacdec.SBR_amp_res) + r5] = r1;
    
bsampres_cal_not_reqd:  
   // *****************************************************************************
   // extract bs_freq_res
   // *****************************************************************************
   call $aacdec.get1bit;
 //  M[($aacdec.sbr_np_info + $aacdec.SBR_bs_freq_res) + r5] = r1;
   
   // *****************************************************************************
   // for (env = 1; env < bs_num_env[ch]; env++)
   // *****************************************************************************
   r0 = r5 * 6 (int);
   I1 = r0 + (&$aacdec.sbr_info + $aacdec.SBR_bs_freq_res);
   do fixfix_bs_freq_res_loop;
      M[I1, 1] = r1;
   fixfix_bs_freq_res_loop:
   
   // *****************************************************************************
   // SBR_abs_bord_lead[ch] = 0
   // *****************************************************************************
   M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_lead) + r5] = Null;
   
   // *****************************************************************************
   // SBR_abs_bord_trail[ch] = SBR_numTimeSlots
   // *****************************************************************************
   r1 = M[$aacdec.SBR_numTimeSlots_eld];
   M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_trail) + r5] = r1;
   jump end_switch_bs_frame_class;

not_fixfix:
   // *****************************************************************************
   // extract bs_transient_position
   // *****************************************************************************
   Null = r1 - $aacdec.SBR_LDTRAN;
   if Z call $aacdec.get4bits;
   M[($aacdec.sbr_np_info + $aacdec.SBR_bs_transient_position) + r5] = r1;
  
   
   r1 = r1 * 4(int);                                 // [bs_transient_position][num_envelopes]
   r2 = &$aacdec.ld_envelopetable512 ;
   r3 = &$aacdec.ld_envelopetable480 ;
   Null = M[$aacdec.frame_length_flag];
   if NZ r2 = r3  ;
   
   r1 = M[r2 + r1];
   r10 = r1;
   M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5] = r10;
   r8 = r10;
   // *****************************************************************************
   // for (env = 0; env < bs_num_env[ch]; env++)
   // *****************************************************************************
   r0 = r5 * 6 (int);
   I1 = (&$aacdec.sbr_info + $aacdec.SBR_bs_freq_res) + r0;
   do ldtrans_bs_freq_res_loop;
      call $aacdec.get1bit;
      M[I1, 1] = r1;
    ldtrans_bs_freq_res_loop:

end_switch_bs_frame_class:
   r0 = 1;
   Null = r8 - 1;
   if GT r0 = r0 + r0;
   M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_noise) + r5] = r0;
   
   call $aacdec.sbr_envelope_time_border_vector;
   call $aacdec.sbr_envelope_noise_border_vector;

   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif


