// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


#ifndef MATH_INV_QDRT_INCLUDED
#define MATH_INV_QDRT_INCLUDED

// *****************************************************************************
// MODULE:
//    $math.inv_qdrt
//
// DESCRIPTION:
//    Library subroutine to evaluate the inverse quad root of a number
//    out = in^-0.25
//
// INPUTS:
//    - r0 = input value between 2^22 and 2^23-1 (ie. 0.5 and 1.0 fractional)
//    - r4 = exponent of input
//
// OUTPUTS:
//    - r1 = result
//
// TRASHED REGISTERS:
//    TBD
//
// CPU USAGE:
//    TBD
//
// *****************************************************************************
.MODULE $M.math.inv_qdrt;
   .CODESEGMENT MATH_INV_QDRT_PM;
   .DATASEGMENT DM;

   $math.inv_qdrt:

   .BLOCK inv_qdrtcoefs;
   .VAR coefs[6] =         0.462924229764, -0.6477509759436,  0.99604704846307,
                          -0.944016565707,  0.4889126379157, -0.10611817265187;
   .VAR inv_qdrt_lkup[3] = 0.59460355750136, 0.70710678118655, 0.84089641525371;
   .ENDBLOCK;

   M0 = 1;
   M1 = -7;
   I1 = &coefs;
   Null = r0;

   if Z r4 = r4 + r4,         // if input = 0 make sure output is 0
    rMAC = M[I1,M0];          // x^0 * coefs(1)

   r1 = r4 ASHIFT -2;
   r4 = r4 AND 3;
   if NZ r1 = r1 + M0;
   r1 = r1 + M1;
   M1 = r4;

   r2 = r0 * r0 (frac),       // calc x^2
    r3 = M[I1,M0];            // get coefs(2)

   rMAC = rMAC + r0 * r3,     // x^1 * coefs(2)
    r3 = M[I1,1];             // get coefs(3)

   rMAC = rMAC + r2 * r3,     // x^2 * coefs(3)
    r3 = M[I1,1];             // get coefs(4)

   r2 = r2 * r0 (frac);       // calc x^3

   rMAC = rMAC + r2 * r3,     // x^3 * coefs(4)
    r3 = M[I1,1];             // get coefs(5)

   r2 = r2 * r0 (frac);       // calc x^4

   rMAC = rMAC + r2 * r3,     // x^4 * coefs(5)
    r3 = M[I1,M1];            // get coefs(5)

   r2 = r2 * r0 (frac);       // calc x^5

   rMAC = rMAC + r2 * r3,     // x^5 * coefs(6)
    r3 = M[I1,1];

   r1 = rMAC ASHIFT r1;       // rescale and shift
   Null = r4;                 // shiftamount != 0
   if NZ r1 = r1 * r3 (frac); // if shiftamount was not a multiple of 4 * qdrt(1/4)

   rts;

.ENDMODULE;

#endif
