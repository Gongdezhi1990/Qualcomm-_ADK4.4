// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.raw_data_stream
//
// DESCRIPTION:
//    Get a raw data block /// TODO: This function is never used
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.raw_data_stream;
   .CODESEGMENT AACDEC_RAW_DATA_STREAM_PM;
   .DATASEGMENT DM;

   $aacdec.raw_data_stream:

   // push rLink onto stack
   push rLink;

   forever_at_the_moment:

      // raw data block
      call $aacdec.raw_data_block;

   jump forever_at_the_moment;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
