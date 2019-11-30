// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.byte_align
//
// DESCRIPTION:
//    Byte align the input stream
//
// INPUTS:
//    - I0 = buffer to read words from
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r3
//
// *****************************************************************************
.MODULE $M.aacdec.byte_align;
   .CODESEGMENT AACDEC_BYTE_ALIGN_PM;
   .DATASEGMENT DM;

   $aacdec.byte_align:

   // push rLink onto stack
   push rLink;

   // for byte alignment bitpos needs to be 0,8,16 etc
   r0 = M[$aacdec.get_bitpos];
   r0 = r0 AND 0x7;
   call $aacdec.getbits;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
