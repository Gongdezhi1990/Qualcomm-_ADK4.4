// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.mp4_discard_atom_data
//
// DESCRIPTION:
//    Discard data from an atom
//
// INPUTS:
//    - r5 = LS word amount to discard (3 bytes)
//    - r4 = MS word amount to discard (1 byte)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-5, r8
//
// *****************************************************************************
.MODULE $M.aacdec.mp4_discard_atom_data;
//   .CODESEGMENT AACDEC_PM_FAST;
   .CODESEGMENT AACDEC_MP4_DISCARD_ATOM_DATA_PM;
   .DATASEGMENT DM;


   $aacdec.mp4_discard_atom_data:

   // push rLink onto stack
   push rLink;

   // see if half way through discarding
   Null = M[$aacdec.mp4_in_discard_atom_data];
   if Z jump new_sub_atom_to_discard;

      // restore amount left to discard
      r4 = M[$aacdec.mp4_discard_amount_ms];
      r5 = M[$aacdec.mp4_discard_amount_ls];

   new_sub_atom_to_discard:

   Null = r4 AND 0xFFFF00;
   if NZ jump $aacdec.possible_corruption;
   Null = r5;
   if NZ jump non_zero_input;
      Null = r4;
      if Z jump escape;
   non_zero_input:


   r8 = M[$aacdec.num_bytes_available];

   // loop around discarding {r4:r5} bytes
   discard_loop:

      r8 = r8 - 1;
      if NEG jump out_of_data;

      // discard a byte
      call $aacdec.get1byte;

      // decrement count (r4:r5) by 1
      r5 = r5 - 1;
      r4 = r4 - Borrow;
   if NZ jump discard_loop;
   Null = r5;
   if NZ jump discard_loop;

   // update num_bytes_available store
   M[$aacdec.num_bytes_available] = r8;

   // successfully discarded all bytes required
   M[$aacdec.mp4_in_discard_atom_data] = Null;

   escape:
   // pop rLink from stack
   jump $pop_rLink_and_rts;


   out_of_data:
      // update num_bytes_available store
      M[$aacdec.num_bytes_available] = Null;
      r0 = 1;
      M[$aacdec.frame_underflow] = r0;

      // flag that we still need to discard the remainder next time
      M[$aacdec.mp4_in_discard_atom_data] = r0;
      M[$aacdec.mp4_discard_amount_ms] = r4;
      M[$aacdec.mp4_discard_amount_ls] = r5;

      // pop rLink from stack
      jump $pop_rLink_and_rts;

.ENDMODULE;
