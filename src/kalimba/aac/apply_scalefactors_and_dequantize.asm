// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "aac_library.h"
#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.apply_scalefactors_and_dequantize
//
// DESCRIPTION:
//    Apply the scalefactors and dequantise the samples
//
// INPUTS:
//    - r4 = ICS_ptr
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r8, r10, rMAC, I1-I7, M0-M3
//    - first element of $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.apply_scalefactors_and_dequantize;
   .CODESEGMENT AACDEC_APPLY_SCALEFACTORS_AND_DEQUANTIZE_PM;
   .DATASEGMENT DM;

   $aacdec.apply_scalefactors_and_dequantize:

   // push rLink onto stack
   push rLink;

   // set up r4 as an ics pointer
   r4 = M[$aacdec.current_ics_ptr];

   // window = 0;
   // for g = 0:ics(ch).num_window_groups-1,
   //    k = 0;
   //    p = window*128;
   //    for sfb = 0:ics(ch).max_sfb-1,
   //       top = ics(ch).sect_sfb_offset(g+1,sfb+2);
   //       scale = 2^(0.25 * (ics(ch).scale_factors(g+1,sfb+1) - SF_OFFSET));
   //       while k < top,
   //          x_rescale(ch,p+k+1) = x_invquant(ch,p+k+1) * scale;
   //          k = k + 1;
   //       end
   //    end
   //
   //    window = window + ics(ch).window_group_length(g+1);
   // end

   // initialise regs for x^4/3 routine
   I3 = (&$aacdec.x43_lookup2 - 9);
   M3 = 9;
   M2 = 32;
   r7 = 0x200000;

   // I5 = &window_group_length(g)
   r0 = r4 + $aacdec.ics.WINDOW_GROUP_LENGTH_FIELD;
   I5 = r0;

   // I1 = &scalefactors(0,0)
   r0 = M[r4 + $aacdec.ics.SCALEFACTORS_PTR_FIELD];
   I1 = r0;
   // r5 = g = 0
   r5 = 0;
   M[$aacdec.tmp] = r5;
   // M1 = window = 0
   M1 = 0;

   r8 = 100;

   win_groups_loop:

      // M0 = k = 0
      M0 = 0;

      // I7 = &spec_sample(window * 128);
      r0 = M1;
      r1 = r0 * 128 (int);
      r0 = M[$aacdec.current_spec_ptr];
      I7 = r0 + r1;

      // I4 = &sect_sfb_offset(g,1)
      r0 = M[r4 + $aacdec.ics.NUM_SWB_FIELD];
      r0 = r0 * r5 (int);
      r0 = r0 + r5;  // r0 = g*(num_swb+1)
      r1 = M[r4 + $aacdec.ics.SECT_SFB_OFFSET_PTR_FIELD];
      I4 = r0 + r1;
      I4 = I4 + 1;

      r0 = M[r4 + $aacdec.ics.MAX_SFB_FIELD];
      // if max_sfb = 0 then skip this loop
      if Z jump sfb_loop_end;
      I6 = r0;
      sfb_loop:

         // read current scalefactor
         r0 = M[I1,1];
         r0 = r0 - ($aacdec.SF_OFFSET + $aacdec.REQUANTIZE_EXTRA_SHIFT);
         r1 = r0 AND 3;
         // r5 = scalefactor shift amount
         r5 = r0 ASHIFT -2;
         // r6 = scalefactor multiply factor
         r6 = M[$aacdec.two2qtrx_lookup + r1];

         // r0 = top
         r0 = M[I4,1];
         r10 = r0 - M0;
         // k = k + r10;
         M0 = M0 + r10;
         do inner_loop;

            r0 = M[I7,0];
            Null = r0;
            if NEG jump negative_sample;
               call dequantize;
               jump long_write_back;
            negative_sample:
               r0 = -r0;
               call dequantize;
               rMAC = -rMAC;
            long_write_back:
             r8 = BLKSIGNDET rMAC,
              M[I7,1] = rMAC;

         inner_loop:

         I6 = I6 - 1;
      if NZ jump sfb_loop;
      sfb_loop_end:

      // M1 = window = window + ics(ch).window_group_length(g+1);
      r0 = M[I5,1];
      M1 = M1 + r0;

      // move on to the next window group
      r5 = M[$aacdec.tmp];
      r5 = r5 + 1;
      M[$aacdec.tmp] = r5;
      r0 = M[r4 + $aacdec.ics.NUM_WINDOW_GROUPS_FIELD];
      Null = r5 - r0;
   if NZ jump win_groups_loop;

   r1 = M[$aacdec.current_spec_blksigndet_ptr];
   M[r1] = r8;

   // pop rLink from stack
   jump $pop_rLink_and_rts;


   // **************************************************************************
   // SUBROUTINE:  Dequantise a sample and apply scalefactor
   //
   // INPUTS:
   //    r0 = sample to requantise
   //    r5 = scalefactor shift amount
   //    r6 = scalefactor multiply fraction
   //    r7 = 0x200000
   //    I3 = x43_lookup2[-9]
   //    M3 = 9
   //    M2 = 32
   //
   // OUTPUTS:
   //    rMAC = Requantised subband sample
   //           = (r0 ^ (4/3) * scalefactor_faction) << scalefactor_shift
   //
   // TRASHED REGISTERS:
   //    - r0-r3, I2
   //
   // **************************************************************************
   dequantize:

   Null = r0 - 32;
   if NEG jump x43_first32;

      r1 = SIGNDET r0;
      I2 = r1 + (&$aacdec.x43_lookup1 - 9);
      r2 = r0 LSHIFT r1;       // r2 = x'
      Null = r2 AND r7;
      if NZ I2 = I3 + r1;      // I2 = pointer in coef table to use

      r0 = M[I2,M3];           // get exponent coef

      r1 = r2 * r2 (frac),     // r1 = x'^2
       rMAC = M[I2,M3];        // get x'^0 coef

      r3 = r5 + r0,            // r3 = (scalefactor shift amount) + Exponent
       r0 = M[I2,M3];          // get x'^2 coef

      rMAC = rMAC + r1 * r0,
       r0 = M[I2,M3];          // get x'^1 coef
      rMAC = rMAC + r2 * r0;

      rMAC = rMAC * r6;        // now do the * 2^((scalefac+exp)/4)
      rMAC = rMAC ASHIFT r3;
      rts;

   x43_first32:
   I2 = r0 + &$aacdec.x43_lookup32;
   r0 = M[I2,M2];           // get exponent coef

   r3 = r5 + r0,            // r3 = (scalefactor shift amount) + Exponent
    rMAC = M[I2,M2];        // get x'^0 coef

   rMAC = rMAC * r6;        // now do the * 2^((scalefac+exp)/4)
   rMAC = rMAC ASHIFT r3;
   rts;

.ENDMODULE;
