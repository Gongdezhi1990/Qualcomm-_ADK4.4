// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.pns_decode
//
// DESCRIPTION:
//    Decode the PNS (Perceptual Noise Substitution) data
//
// INPUTS:
//    - M3 = 0 (if individual channel),   1 (if channel pair)
//    - r4 = ICS structure pointer
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r3, r5-r8, r10, rMAC, I0-I7, M0-M2, Div
//    - first 3 elements of $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.pns_decode;
//   .CODESEGMENT AACDEC_PM_FAST;
   .CODESEGMENT AACDEC_PNS_DECODE_PM;
   .DATASEGMENT DM;

   $aacdec.pns_decode:

   //   nrg = global_gain - NOISE_OFFSET - 256;
   //   for (g=0; g<num_window_groups; g++) {
   //
   //      /* Decode noise energies for this group */
   //      for (sfb=0; sfb<max_sfb; sfb++)
   //         if (is_noise(g,sfb))
   //            noise_nrg[g][sfb] = nrg += dpcm_noise_nrg[g][sfb];
   //
   //      /* Do perceptual noise substitution decoding */
   //      for (b=0; b<window_group_length[g]; b++) {
   //         for (sfb=0; sfb<max_sfb; sfb++) {
   //
   //            if (is_noise(g,sfb)) {
   //               offs = swb_offset[sfb];
   //               size = swb_offset[sfb+1] - offs;
   //
   //               /* Generate random vector */
   //               gen_rand_vector( &spec[g][b][sfb][0], size );
   //               scale = 1/(size * sqrt(MEAN_NRG));
   //               scale *= 2.0^(0.25*noise_nrg [g][sfb]);
   //
   //               /* Scale random vector to desired target energy */
   //               for (i=0; i<size; i++)
   //                  spec[g][b][sfb][i] *= scale;
   //            }
   //
   //            if chan_pair && is_noise_right(g,sfb) {
   //               if is_noise_left(g,sfb) && ((ms_mask_present == 2) ||
   //                  (ms_mask_present == 1) && ms_used[g][sfb]) {
   //
   //                  /* copy across data from left channel to right channel */
   //                  for (i=0; i<size; i++)
   //                     spec_chan_pair[g][b][sfb][i] = spec[g][b][sfb][i]
   //
   //               } else {
   //
   //                  /* generate new pns data for right channel */
   //                  offs = swb_offset[sfb];
   //                  size = swb_offset[sfb+1] - offs;
   //
   //                  /* Generate random vector */
   //                  gen_rand_vector( &spec[g][b][sfb][0], size );
   //                  scale = 1/(size * sqrt(MEAN_NRG));
   //                  scale *= 2.0^(0.25*noise_nrg [g][sfb]);
   //
   //                  /* Scale random vector to desired target energy */
   //                  for (i=0; i<size; i++)
   //                     spec[g][b][sfb][i] *= scale;
   //               }
   //            }
   //         }
   //      }
   //   }

   // push rLink onto stack
   push rLink;

   // set r6 as random number generator constant
   r6 = $aacdec.PNS_RAND_M;

   // r7 = window_offset = 0
   r7 = 0;

   // for (g=0; g<num_window_groups; g++) {
   // r8 = g = 0
   r8 = 0;
   win_groups_loop:

      // for (b=0; b<window_group_length[g]; b++) {
      // M1 = window_group_length(g);
      r0 = r4 + $aacdec.ics.WINDOW_GROUP_LENGTH_FIELD;
      r0 = M[r0 + r8];
      M1 = r0;
      window_loop:

         r0 = M[r4 + $aacdec.ics.SWB_OFFSET_PTR_FIELD];
         I4 = r0;
         r0 = M[I4,1];
         I2 = r0;

         // for (sfb=0; sfb<max_sfb; sfb++) {
         r0 = M[r4 + $aacdec.ics.MAX_SFB_FIELD];
         // if max_sfb = 0 then skip the sfb_loop
         if Z jump sfb_loop_end;
         M2 = r0;
         // r1 = g*max_sfb + sfb
         r1 = r0 * r8 (int);

         // I6 = sfb_cb[g][0]
         r0 = M[r4 + $aacdec.ics.SFB_CB_PTR_FIELD];
         I6 = r0 + r1;

         // I5 = scalefactors[g][0]
         r0 = M[r4 + $aacdec.ics.SCALEFACTORS_PTR_FIELD];
         I5 = r0 + r1;

         // I3 = sfb_cb_right[g][0]
         r0 = M[$aacdec.ics_right + $aacdec.ics.SFB_CB_PTR_FIELD];
         I3 = r0 + r1;

         // I7 = scalefactors_right[g][0]
         r0 = M[$aacdec.ics_right + $aacdec.ics.SCALEFACTORS_PTR_FIELD];
         I7 = r0 + r1;

         sfb_loop:

            // I2 = swb_offset[sfb]
            // r2 = swb_offset[sfb+1]
            r2 = M[I4,1];

            r3 = M[I6,1]; // r3 = sfb_cb[g][sfb]
            r5 = M[I5,1]; // r5 = scalefactors[g][sfb]

            // if (is_noise(g,sfb))
            Null = r3 - $aacdec.NOISE_HCB;
            if NZ jump not_noise;

               // size = swb_offset[sfb+1] - swb_offset[sfb]
               r10 = r2 - I2;

               // load last random number
               r0 = M[$aacdec.pns_rand_num];

               // calculate what the actual energy will be
               // for these random values
               rMAC = 0;
               do energy_loop;
                  r0 = r0 * r6 (int);
                  r0 = r0 + $aacdec.PNS_RAND_C;
                  rMAC = rMAC + r0 * r0;
               energy_loop:
               r0 = rMAC ASHIFT -6;


               // -- calc sqrt(energy) --
               // save r2, r3, r4
               M[$aacdec.tmp + 0] = r2;
               M[$aacdec.tmp + 1] = r3;
               M[$aacdec.tmp + 2] = r4;
               call $math.sqrt;
               // restore r2, r3, r4
               r2 = M[$aacdec.tmp + 0];
               r3 = M[$aacdec.tmp + 1];
               r4 = M[$aacdec.tmp + 2];

               // -- calc 1/sqrt(energy) --
               // make sure we don't divide by too small a number (avoid overflow)
               r0 = r1 - (1<<11);
               if NEG r1 = r1 - r0;
               rMAC = (1<<9);
               Div = rMAC / r1;

               // size = swb_offset[sfb+1] - swb_offset[sfb]
               r10 = r2 - I2;

               // I0 = spec[window*128 + swb_offset[sfb]];
               r0 = r7 + M[$aacdec.current_spec_ptr];
               I0 = r0 + I2;

               // form scaling factor
               r5 = r5 - ($aacdec.REQUANTIZE_EXTRA_SHIFT - 40);
               r1 = r5 AND 3;
               r1 = M[$aacdec.two2qtrx_lookup + r1];
               rMAC = DivResult;
               rMAC = rMAC * r1;
               r1 = r5 ASHIFT -2;
               rMAC = rMAC ASHIFT r1;

               // reload last random number;
               r0 = M[$aacdec.pns_rand_num];

               // -- generate the scaled random data --
               do random_vector_loop;
                  // generate a new scaled random number
                  r0 = r0 * r6 (int);
                  r0 = r0 + $aacdec.PNS_RAND_C;
                  r1 = r0 * rMAC (frac);
                  M[I0,1] = r1;
               random_vector_loop:
               // store last random number for next time;
               M[$aacdec.pns_rand_num] = r0;


            not_noise:

            // if chan_pair && is_noise_right(g,sfb)
            Null = M3,
             r0 = M[I3,1];
            if Z jump not_chan_pair;
            r5 = M[I7,1]; // r5 = scalefactors_right[g][sfb]
            Null = r0 - $aacdec.NOISE_HCB;
            if NZ jump not_noise_right;

               // if is_noise_left(g,sfb) && ((ms_mask_present == 2) ||
               //    ((ms_mask_present == 1) && ms_used[g][sfb])) {
               Null = r3 - $aacdec.NOISE_HCB;
               if NZ jump chan_pair_not_correlated;
               r0 = M[r4 + $aacdec.ics.MS_MASK_PRESENT_FIELD];
               Null = r0 - 2;
               if Z jump chan_pair_correlated;
               Null = r0 - 1;
               if NZ jump chan_pair_not_correlated;
               r1 = I5;
               r1 = r1 - M[$aacdec.ics_left + $aacdec.ics.SCALEFACTORS_PTR_FIELD];
               r0 = M[r4 + $aacdec.ics.MS_USED_PTR_FIELD];
               Null = M[r1 + r0];
               if Z jump chan_pair_not_correlated;

               chan_pair_correlated:
                  r10 = r2 - I2;

                  // I0 = spec[window*128 + swb_offset[sfb] + size - 1];
                  I0 = I0 - 1;
                  // I1 = spec_right[window*128 + swb_offset[sfb] + size - 1];
                  #ifndef AAC_USE_EXTERNAL_MEMORY
                  I1 = I0 + $aacdec.buf_right;
                  I1 = I1 - $aacdec.buf_left;
                  #else 
                  r0 = M[$aacdec.buf_right_ptr];
                  I1 = I0 + r0;
                  r0 = M[$aacdec.buf_left_ptr];
                  I1 = I1 - r0;
                  #endif 


                  do channel_pair_copy_loop;
                     r0 = M[I0,-1];
                     M[I1,-1] = r0;
                  channel_pair_copy_loop:
                  jump chan_pair_done;


               chan_pair_not_correlated:

                  // Here we don't use the sqrt routine to calculate the short term sqrt(MEAN_ENERGY),
                  // we just use a constant for the long term average - there are no PNS stereo
                  // compliance test files to verify this assumption.

                  // size = swb_offset[sfb+1] - swb_offset[sfb]
                  r10 = r2 - I2;
                  r0 = M[$aacdec.sqrt_three_over_two];
                  rMAC = r0 ASHIFT 0 (LO);
                  Div = rMAC / r10;

                  // I0 = spec_right[window*128 + swb_offset[sfb]];
                  #ifndef AAC_USE_EXTERNAL_MEMORY
                  r0 = r7 + &$aacdec.buf_right;
                  #else 
                  r0 = M[$aacdec.buf_right_ptr];
                  r0 = r7 + r0; 
                  #endif 
                  I0 = r0 + I2;

                  // load last random number;
                  r0 = M[$aacdec.pns_rand_num];

                  // form scaling factor
                  r5 = r5 - ($aacdec.REQUANTIZE_EXTRA_SHIFT - 8);
                  r1 = r5 AND 3;
                  r1 = M[$aacdec.two2qtrx_lookup + r1];
                  rMAC = DivResult;
                  rMAC = rMAC * r1;
                  r1 = r5 ASHIFT -2;
                  rMAC = rMAC ASHIFT r1;

                  do chan_pair_random_vector_loop;
                     // generate a new scaled random number
                     r0 = r0 * r6 (int);
                     r0 = r0 + $aacdec.PNS_RAND_C;
                     r1 = r0 * rMAC (frac);
                     M[I0,1] = r1;
                  chan_pair_random_vector_loop:
                  // store last random number for next time;
                  M[$aacdec.pns_rand_num] = r0;

               chan_pair_done:
            not_noise_right:
            not_chan_pair:
            I2 = r2;

            // move on to next sfb
            M2 = M2 - 1;
         if NZ jump sfb_loop;
         sfb_loop_end:

         // move on to the next window
         r7 = r7 + 128;
         M1 = M1 - 1;
      if NZ jump window_loop;

      // move on to the next window group
      r8 = r8 + 1;
      r0 = M[r4 + $aacdec.ics.NUM_WINDOW_GROUPS_FIELD];
      Null = r8 - r0;
   if NZ jump win_groups_loop;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
