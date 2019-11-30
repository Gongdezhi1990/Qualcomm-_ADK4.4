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
//    $aacdec.sbr_wrap_last_thfgen_envelopes
//
// DESCRIPTION:
//    Wraps the last tHFGen envelopes in X_sbr to the front of X_sbr for the
//    next frame. The first tHFAdj of these envelopes have only the lower half
//    of the frequencies wrapped.
//
// INPUTS:
//    - r5 channel
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0, r1, r10, I1, I2, I4, I5
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_wrap_last_thfgen_envelopes;
   .CODESEGMENT AACDEC_SBR_WRAP_LAST_THFGEN_ENVELOPES_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_wrap_last_thfgen_envelopes:

   // push rLink onto stack
   push rLink;
#ifdef AACDEC_ELD_ADDITIONS
   r1 = M[$aacdec.SBR_numTimeSlotsRate_eld];
   r0 = $aacdec.X_SBR_WIDTH;
   r0 = r0 * r1 (int);
#else 
   r0 = $aacdec.X_SBR_WIDTH * $aacdec.SBR_numTimeSlotsRate;
#endif 
   // I2 <- real(X_sbr[ch][0][SBR_numTimeSlotsRate])
   I2 = r0 + (&$aacdec.sbr_x_real+512);

   // I5 <- imag(X_sbr[ch][0][SBR_numTimeSlotsRate])
   I5 = r0 + (&$aacdec.sbr_x_imag+1536);


   //
   // X_sbr[ch][0:31][0] = X_sbr[ch][0:31][SBR_numTimeSlotsRate]
   //
#ifndef AACDEC_ELD_ADDITIONS
     r10 = $aacdec.X_SBR_LEFTRIGHT_2ENV_SIZE/2;
#else
      r10 = $aacdec.X_SBR_LEFTRIGHT_2ENV_SIZE;
      r10 = r10 * 2 (int);
#endif 
   I1 = (&$aacdec.sbr_x_real+512);
   I4 = (&$aacdec.sbr_x_imag+1536);

   do x_sbr_wrap_last_thf_gen_env_loop2a;
      r0 = M[I2, 1],
       r1 = M[I5, 1];
      M[I1, 1] = r0,
       M[I4, 1] = r1;
   x_sbr_wrap_last_thf_gen_env_loop2a:

   //
   // X_sbr[ch][0:31][1] = X_sbr[ch][0:31][SBR_numTimeSlotsRate+1]
   //
#ifndef AACDEC_ELD_ADDITIONS
   r10 = $aacdec.X_SBR_LEFTRIGHT_2ENV_SIZE/2;
   I1 = I1 + ($aacdec.X_SBR_WIDTH/2);
   I2 = I2 + ($aacdec.X_SBR_WIDTH/2);
   I4 = I4 + ($aacdec.X_SBR_WIDTH/2);
   I5 = I5 + ($aacdec.X_SBR_WIDTH/2);


   do x_sbr_wrap_last_thf_gen_env_loop2b;
      r0 = M[I2, 1],
       r1 = M[I5, 1];
      M[I1, 1] = r0,
       M[I4, 1] = r1;
   x_sbr_wrap_last_thf_gen_env_loop2b:


   //
   // X_sbr[ch][0:63][SBR_tHFAdj:SBR_tHFGen-1] = X_sbr[ch][0:63][SBR_numTimeSlotsRate+SBR_tHFAdj:39]
   //

   r10 = $aacdec.X_SBR_LEFTRIGHT_SIZE;
   I1 = I1 + ($aacdec.X_SBR_WIDTH/2);
   I2 = I2 + ($aacdec.X_SBR_WIDTH/2);
   I4 = I4 + ($aacdec.X_SBR_WIDTH/2);
   I5 = I5 + ($aacdec.X_SBR_WIDTH/2);
   do x_sbr_wrap_last_thf_gen_env_loop;
      r0 = M[I2, 1],
       r1 = M[I5, 1];
      M[I1, 1] = r0,
       M[I4, 1] = r1;
   x_sbr_wrap_last_thf_gen_env_loop:

#endif ///AACDEC_ELD_ADDITIONS
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
