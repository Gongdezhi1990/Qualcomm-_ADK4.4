// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "stack.h"
#include "cbops.h"

// *****************************************************************************
// MODULE:
//   $M.cbops.fill_limit
//
// DESCRIPTION:
//   cbops structure for fill_limit operator
//
// *****************************************************************************
.MODULE $M.cbops.fill_limit;
   .DATASEGMENT DM;

   // ** Function vector **
   .VAR $cbops.fill_limit[$cbops.function_vector.STRUC_SIZE] =
      $cbops.function_vector.NO_FUNCTION,    // Reset function
      &$cbops.fill_limit.amount_to_use,      // Amount to use function
      $cbops.function_vector.NO_FUNCTION;    // Main function

.ENDMODULE;

// *****************************************************************************
// MODULE:
//   $M.cbops.fill_limit.amount_to_use
//
// DESCRIPTION:
//    Operator to limit the amount of data copied in each call so that
//    the output buffer/port will not contain more than a given
//    amount of data (value in the FILL_LIMIT_FIELD field in words).
//    Note: it does not actually copy any data, it simply limits the amount
//    of data other operators will copy.
//
// INPUTS:
//    - r5 = the minimum of the number of input samples available and the
//      amount of output space available
//    - r6 = the number of input samples available
//    - r7 = the amount of output space available
//    - r8 = pointer to operator structure
//
// OUTPUTS:
//    - r5 = the number of samples to process
//
// TRASHED REGISTERS:
//    r0, r1, r2, r3, r4
//
// *****************************************************************************
.MODULE $M.cbops.fill_limit.amount_to_use;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   // ** Amount to use function **
   $cbops.fill_limit.amount_to_use:

   // Push rLink onto stack
   $push_rLink_macro;

   // If no limit then exit
   r3 = M[r8 + $cbops.fill_limit.FILL_LIMIT_FIELD];
   Null = r3 - $cbops.fill_limit.NO_LIMIT;
   if Z jump $pop_rLink_and_rts;

   // Calculate the amount of data currently in the output cbuffer/port
   r0 = M[r8 + $cbops.fill_limit.OUT_BUFFER_FIELD];
   call $cbuffer.calc_amount_space;

   // Operator must work for cbuffers and ports
   r1 = M[r8 + $cbops.fill_limit.OUT_BUFFER_FIELD];
   null = SIGNDET r1;      // Is it a cbuffer?
   if NZ jump skip_port;   // Yes - skip the port octet conversion

      push r3;
      r3 = M[r8 + $cbops.fill_limit.OUT_BUFFER_FIELD];;
      // Convert to samples (in: r2 = octets, r3 = port config; out r2 = samples)
      call $cbuffer.mmu_octets_to_samples;
      pop r3;

   skip_port:

   // Amount of data currently in the output cbuffer/port (in words)
   r0 = r2 - r0;

   // Potential amount (in words) in the output cbuffer/port if a full copy was performed
   r0 = r0 + r5;

   // Compare the amount with the chosen limit
   r2 = r0 - r3;
   if POS r5 = r5 - r2;

   // Pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
