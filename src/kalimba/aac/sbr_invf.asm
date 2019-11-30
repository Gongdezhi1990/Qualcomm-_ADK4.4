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
//    $aacdec.sbr_invf
//
// DESCRIPTION:
//    Get inverse filtering information
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
.MODULE $M.aacdec.sbr_invf;
   .CODESEGMENT AACDEC_SBR_INVF_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_invf:

   // push rLink onto stack
   push rLink;

   r0 = r5 * 5 (int);
   I1 = (&$aacdec.sbr_np_info + $aacdec.SBR_bs_invf_mode) + r0;

   r10 = M[$aacdec.sbr_info + $aacdec.SBR_Nq];

   do invf_mode_loop;
      call $aacdec.get2bits;
      M[I1, 1] = r1;
   invf_mode_loop:

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
