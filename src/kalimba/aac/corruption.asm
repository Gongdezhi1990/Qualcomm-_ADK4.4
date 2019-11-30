// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifndef AACDEC_CORRUPTION
#define AACDEC_CORRUPTION

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.possible_corruption
//
// DESCRIPTION:
//    Set possible_frame_corruption flag and escape from module
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0
//
// *****************************************************************************
.MODULE $M.aacdec.possible_corruption;
   .CODESEGMENT AACDEC_POSSIBLE_CORRUPTION_PM;
   .DATASEGMENT DM;

   $aacdec.possible_corruption:

      // set the possible_corruption flag and hope to get back in sync next time
      #ifdef AACDEC_CALL_ERROR_ON_POSSIBLE_CORRUPTION
         call $error;
      #else
         r0 = 1;
         M[$aacdec.possible_frame_corruption] = r0;
         // pop rLink from stack
         jump $pop_rLink_and_rts;
      #endif

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $aacdec.corruption
//
// DESCRIPTION:
//    Set frame_corrupt flag and escape from module
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0
//
// *****************************************************************************
.MODULE $M.aacdec.corruption;
   .CODESEGMENT AACDEC_CORRUPTION_PM;
   .DATASEGMENT DM;

   $aacdec.corruption:

      // set the frame_corrupt flag and hope to get back in sync next time
      #ifdef AACDEC_CALL_ERROR_ON_POSSIBLE_CORRUPTION
         call $error;
      #else
         r0 = 1;
         M[$aacdec.frame_corrupt] = r0;
         // pop rLink from stack
         jump $pop_rLink_and_rts;
      #endif

.ENDMODULE;


#endif
