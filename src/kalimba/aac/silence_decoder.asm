// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.silence_decoder
//
// DESCRIPTION:
//    Silence the decoder - clears any buffers so that no pops and squeeks upon
//    re-enabling output audio
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r10, DoLoop, I0, I4
//
// *****************************************************************************
.MODULE $M.aacdec.silence_decoder;
   .CODESEGMENT AACDEC_SILENCE_DECODER_PM;
   .DATASEGMENT DM;

   $aacdec.silence_decoder:

   // clear overlap add buffers
   
#ifndef AAC_USE_EXTERNAL_MEMORY   
   I0 = &$aacdec.overlap_add_left;
   I4 = &$aacdec.overlap_add_right;
   
   r10 = LENGTH($aacdec.overlap_add_right);
#else
   r0 = M[$aacdec.overlap_add_left_ptr];
   I0 = r0;;
   r0 = M[$aacdec.overlap_add_right_ptr];
   I4 = r0;
   r10 = 576;
#endif ///AAC_USE_EXTERNAL_MEMORY


   r0 = 0;
   do oa_clear_loop;
      M[I0,1] = r0,
       M[I4,1] = r0;
   oa_clear_loop:

   rts;

.ENDMODULE;
