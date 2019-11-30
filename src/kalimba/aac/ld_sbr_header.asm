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
//    $aacdec.ld_sbr_header
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
.MODULE $M.aacdec.ld_sbr_header;
   .CODESEGMENT AACDEC_LD_SBR_HEADER_PM;
   .DATASEGMENT DM;

$aacdec.ld_sbr_header:
   
   push rLink; 
   
case_1_or_2:
   call $aacdec.sbr_header;
   
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
