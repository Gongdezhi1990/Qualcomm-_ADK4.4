// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "core_library.h"


// *****************************************************************************
// MODULE:
//    $math.biquad
//
// INPUTS:
//    I0  = pointer to the input data
//    L0  = length of input buffer (it will be circular)
//    I4  = pointer to the output data
//    L4  = length of output buffer (it will be circular)
//    I1  = scaled coefficients b2,b1,b0,b_scale, a2,a1,a_scale,... etc
//    L1  = 7 * num_biquads
//    I5  = delay line
//    L5  = 2 * num_biquads + 2
//    r0  = no of samples to apply the filter to
//    r10 = number of biquad sections
//
// OUTPUTS:
//    I0  = updated over data read
//    I4  = updated over data written
//
// TRASHED REGISTERS:
//    r0-r5, r10, DoLoop
//
// DESCRIPTION:
//    Library subroutine for a bi-quad IIR filter. Equation of each section:
//
//       y(n) =   (b0*x(n) + b1*x(n-1) + b2*x(n-2)) << b_scale
//              - (          a1*y(n-1) - a2*y(n-2)) << a_scale
//
//    The implementation uses Direct Form I as shown in:
//
//       http://en.wikipedia.org/wiki/Digital_biquad_filter
//
//    The "b" coefficients can be independently scaled from the "a" coefficients
// to make optimal use of the available bits for precision.
//
// *****************************************************************************
.MODULE $M.math.biquad;
   .CODESEGMENT MATH_BIQUAD_PM;

   $math.biquad:

   $push_rLink_macro;

   // save the number of biquads
   r5 = r10;

   sample_loop:
      // filter the samples
      r4 = M[I0, 1];
      do biquad_loop;
         //                     b2             x(n-2)
                                r2 = M[I1, 1], r1 = M[I5, 1];
         //                     b1             x(n-1)
         rMAC =        r1 * r2, r2 = M[I1, 1], r1 = M[I5,-1];
         //                     b0             store x(n-2)
         rMAC = rMAC + r1 * r2, r2 = M[I1, 1], M[I5, 1] = r1;
         //                     scalefactor    store x(n-1)
         rMAC = rMAC + r4 * r2, r2 = M[I1, 1], M[I5, 1] = r4;
         // scale coefficients
         r4   = rMAC ASHIFT r2;
         //                     a2             y(n-2)
                                r2 = M[I1, 1], r1 = M[I5, 1];
         //                     a1             y(n-1)
         rMAC =        r1 * r2, r2 = M[I1, 1], r1 = M[I5,-1];
         //                     scalefactor
         rMAC = rMAC + r1 * r2, r2 = M[I1, 1];
         // scale coefficients
         rMAC = rMAC ASHIFT r2;
         r4   = r4 - rMAC;
      biquad_loop:

      M[I5, 1] = r1; // store new y(n-2)
      M[I5, 1] = r4; // store new y(n-1)
      // write the sample back and reload r10
      r10 = r10 + r5, M[I4, 1] = r4;
      // decrement loop counter
      r0 = r0 - 1;
   if GT jump sample_loop;

   jump $pop_rLink_and_rts;

.ENDMODULE;



