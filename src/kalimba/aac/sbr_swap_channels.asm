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
//    $aacdec.sbr_swap_channels
//
// DESCRIPTION:
//    Swap the left and right channels in the persistent part of X_sbr
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - I0, I1, I4, I5, r0-r3, r10
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_swap_channels;
   .CODESEGMENT AACDEC_SBR_SWAP_CHANNELS_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_swap_channels:

   // push rLink onto stack
   push rLink;
#ifndef AACDEC_ELD_ADDITIONS
   r10 = $aacdec.X_SBR_WIDTH/2;
   I0 = (&$aacdec.sbr_x_real+512);
   I4 = (&$aacdec.sbr_x_imag+1536);
   I1 = I0 + ($aacdec.X_SBR_WIDTH/2);
   I5 = I4 + ($aacdec.X_SBR_WIDTH/2);
   call swap;

   r10 = $aacdec.X_SBR_WIDTH/2;
   I0 = I0 + ($aacdec.X_SBR_WIDTH/2);
   I1 = I1 + ($aacdec.X_SBR_WIDTH/2);
   I4 = I4 + ($aacdec.X_SBR_WIDTH/2);
   I5 = I5 + ($aacdec.X_SBR_WIDTH/2);
   call swap;

   r10 = $aacdec.X_SBR_LEFTRIGHT_SIZE;
   I0 = I0 + ($aacdec.X_SBR_WIDTH/2);
   I4 = I4 + ($aacdec.X_SBR_WIDTH/2);
   I1 = &$aacdec.X_sbr_other_real;
   I5 = &$aacdec.X_sbr_other_imag;
   call swap;
#else
   r10 = $aacdec.X_SBR_WIDTH*2;
   I0 = (&$aacdec.sbr_x_real+512);
   I4 = (&$aacdec.sbr_x_imag+1536);
   I1 = &$aacdec.X_sbr_other_real;
   I5 = &$aacdec.X_sbr_other_imag;
   call swap;
 #endif 
   // pop rLink from stack
   jump $pop_rLink_and_rts;

   swap:
      do copy_loop;
         r0 = M[I0, 0],
          r2 = M[I4, 0];
         r1 = M[I1, 0],
          r3 = M[I5, 0];
         M[I0, 1] = r1,
          M[I4, 1] = r3;
         M[I1, 1] = r0,
          M[I5, 1] = r2;
      copy_loop:
      rts;

.ENDMODULE;

#endif
