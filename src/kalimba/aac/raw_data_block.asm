// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.raw_data_block
//
// DESCRIPTION:
//    Get a raw data block
//
// INPUTS:
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.raw_data_block;
   .CODESEGMENT AACDEC_RAW_DATA_BLOCK_PM;
   .DATASEGMENT DM;

   $aacdec.raw_data_block:

   // push rLink onto stack
   push rLink;

   // zero the SCE and CPE counters
   M[$aacdec.num_SCEs] = Null;
   M[$aacdec.num_CPEs] = Null;

   id_loop:

      call $aacdec.get3bits;
      r1 = M[&$aacdec.syntatic_element_func_table + r1];
      if Z jump $pop_rLink_and_rts;
      if NEG jump $aacdec.possible_corruption;
      call r1;
      Null = M[$aacdec.possible_frame_corruption];
      if NZ jump $aacdec.possible_corruption;

#ifdef AACDEC_ENABLE_LATM_GARBAGE_DETECTION
      // garbage check
      r0 = M[$aacdec.read_bit_count];
      Null = r0 -  ($aacdec.MIN_AAC_FRAME_SIZE_IN_BYTES*8*2);
      if POS jump $aacdec.possible_corruption;
#endif

      jump id_loop;


.ENDMODULE;
