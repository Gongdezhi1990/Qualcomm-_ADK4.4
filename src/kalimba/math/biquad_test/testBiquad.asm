// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "core_library.h"

// *****************************************************************************
// MODULE:
//    $main
//
// DESCRIPTION:
//    Biquad test framework
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    all
//
// NOTES:
//    Test framework for the biquad routines. It currently loads a simple single
// stage biquad filter. However, it is expected to be driven from a test script:
// the python script of the same name. This can load update the filter with any
// filter up to 20 stages.
//
// *****************************************************************************
.MODULE $M.main;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR/DMCIRC $inputBuffer[8192];
   .VAR/DMCIRC $outputBuffer[8192];
   .VAR        $newRun = 0;

   .CONST      $MAX_NUM_STAGES                   20;
   .CONST      $NUM_COEFS_PER_STAGE              7;
   .VAR        $numStages = 1;

   .VAR/DMCIRC $coefs[$MAX_NUM_STAGES * 7] =
                        0.00460399444634034 * 64,
                        0.00920798889268068 * 64,
                        0.00460399444634034 * 64,
                        -6,
                         0.8175108129889816 * 0.5,
                        -1.7990948352036205 * 0.5,
                        1,
                        0 ...;
   .VAR/DMCIRC $delayLine[$MAX_NUM_STAGES * 2 + 2];


   $main:

   // setup the libraries we'll use
   call $stack.initialise;

   loop:
      // wait for new data
      Null = M[$newRun];
      if Z jump loop;

      // there's data to process, say we're doing it
      r0 = -1;
      M[$newRun] = r0;

      // process the data
      r10 = M[$numStages];
      I0 = &$inputBuffer;
      L0 = LENGTH($inputBuffer);
      I5 = &$delayLine;
      r1 = r10 * 2 (int);
      r1 = r1 + 2;
      L5 = r1;
      I4 = &$outputBuffer;
      L4 = LENGTH($outputBuffer);
      I1 = &$coefs;
      r1 = r10 * 7 (int);
      L1 = r1;
      r0 = LENGTH($inputBuffer);
      call $math.biquad;

      // say we're done
      M[$newRun] = 0;

   jump loop;

.ENDMODULE;


