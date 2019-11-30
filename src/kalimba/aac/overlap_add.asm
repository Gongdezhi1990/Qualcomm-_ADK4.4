// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.overlap_add
//
// DESCRIPTION:
//    Copy data to the overlap_add buffer for next frame
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0, r1, r3, r4, r10, I1, I4
//
// *****************************************************************************
.MODULE $M.aacdec.overlap_add;
   .CODESEGMENT AACDEC_OVERLAP_ADD_PM;
   .DATASEGMENT DM;

   $aacdec.overlap_add:

   // push rLink onto stack
   push rLink;

   // select overlap_add_left or overlap_add_right
#ifndef AAC_USE_EXTERNAL_MEMORY   
   I1 = &$aacdec.overlap_add_left;
   r0 = &$aacdec.overlap_add_right;
#else
   r0 = M[$aacdec.overlap_add_left_ptr];
   I1 = r0;;
   r0 = M[$aacdec.overlap_add_right_ptr];
#endif ///AAC_USE_EXTERNAL_MEMORY
   Null = M[$aacdec.current_channel];
   if NZ I1 = r0;
#ifndef AAC_USE_EXTERNAL_MEMORY
   I4 = &$aacdec.tmp_mem_pool + 1023;
#else 
   r0 = M[$aacdec.tmp_mem_pool_ptr];
   I4 = r0 + 1023;///&$aacdec.tmp_mem_pool + 1023;
#endif 

   // scale data up if not already done in tns
   r4 = M[$aacdec.current_spec_blksigndet_ptr];
   r0 = 1;
   r3 = 2;
   Null = M[r4 + 1];
   if NZ r3 = r0;
   M[r4 + 1] = Null;

   // set number of elements to copy based on the window sequence type
   r10 = 255;
   r1 = 287;
   r4 = M[$aacdec.current_ics_ptr];
   r0 = M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD];
   Null = r0 - $aacdec.EIGHT_SHORT_SEQUENCE;
   if Z r10 = r1;
   I1 = I1 + 1;
   I1 = I1 + r10;
   I1 = I1 + r10,
     r4 = M[I4,-1];

   // do the copy
   r4 = r4 * r3 (int),
    r0 = M[I4,-1];
   do overlap_add_loop2;
      r0 = r0 * r3 (int),
       r4 = M[I4,-1],
       M[I1,-1] = r4;
      r4 = r4 * r3 (int),
       r0 = M[I4,-1],
       M[I1,-1] = r0;
   overlap_add_loop2:
   r0 = r0 * r3 (int),
    M[I1,-1] = r4;
   M[I1,-1] = r0;


   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
