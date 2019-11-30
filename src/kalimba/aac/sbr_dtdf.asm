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
//    $aacdec.sbr_dtdf
//
// DESCRIPTION:
//    Get envelope and noise data delta coding information
//
// INPUTS:
//    - r5 channel
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r3, r10, I1
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_dtdf;
   .CODESEGMENT AACDEC_SBR_DTDF_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_dtdf:

   // push rLink onto stack
   push rLink;

   r10 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
   r0 = r5 * 5 (int);
   I1 = (&$aacdec.tmp_mem_pool + $aacdec.SBR_bs_df_env) + r0;

   do df_env_loop;
      call $aacdec.get1bit;
      M[I1, 1] = r1;
   df_env_loop:

   r10 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_noise) + r5];

   r1 = r5 * 2 (int);
   I1 = (&$aacdec.tmp_mem_pool + $aacdec.SBR_bs_df_noise) + r1;


   do df_noise_loop;
      call $aacdec.get1bit;
      M[I1, 1] = r1;
   df_noise_loop:

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
