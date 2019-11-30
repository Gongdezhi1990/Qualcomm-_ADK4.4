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
//    $aacdec.sbr_bubble_sort
//
// DESCRIPTION:
//    sort array into ascending order
//
// INPUTS:
//    - r0 = length of array
//    - r1 = base pointer to array
//
// OUTPUTS:
//    - r1 = unchanged
//
// TRASHED REGISTERS:
//    - r0, r2, r3, I1, I2, r10, DoLoop
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_bubble_sort;
   .CODESEGMENT AACDEC_SBR_BUBBLE_SORT_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_bubble_sort:

   // return immediately if length of array is zero
   Null = r0;
   if Z rts;

   // for i=length_of_array:-1:1,
   outer_loop:

      I1 = r1;

      r10 = r0 - 1;

      r2 = M[I1, 1];

      // for j=1:i-1,
      do inner_loop;

         r3 = M[I1, 1];

         // if(array[j-1] > array[j]) swap two elements around
         Null = r2 - r3;
         if LE jump dont_swap;

            I2 = I1 - 2;
            M[I2, 1] = r3;
            M[I2, 1] = r2;

            r3 = r2;
         dont_swap:

         r2 = r3;

      inner_loop:

      r0 = r0 - 1;
   if GT jump outer_loop;

   rts;

.ENDMODULE;

#endif
