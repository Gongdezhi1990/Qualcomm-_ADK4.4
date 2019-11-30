// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.is_decode
//
// DESCRIPTION:
//    Decode the IS (Intensity Stereo) data
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume all
//
// *****************************************************************************
.MODULE $M.aacdec.is_decode;
   .CODESEGMENT AACDEC_IS_DECODE_PM;
   .DATASEGMENT DM;

   $aacdec.is_decode:

   // function is_intensity(group,sfb) {
   //    +1 for window groups / scalefactor bands with right channel
   //          codebook sfb_cb[group][sfb] == INTENSITY_HCB
   //    -1 for window groups / scalefactor bands with right channel
   //          codebook sfb_cb[group][sfb] == INTENSITY_HCB2
   //    0  otherwise
   // }
   //
   // function invert_intensity(group,sfb) {
   //    1-2*ms_used[group][sfb]     if (ms_mask_present == 1)
   //    +1                          otherwise
   // }
   //
   // The intensity stereo decoding for one channel pair is defined by the following
   // pseudo code:
   //
   // p = 0;
   // for (g=0; g<num_window_groups; g++) {
   //
   //    /* Decode intensity positions for this group */
   //    for (sfb=0; sfb<max_sfb; sfb++)
   //       if (is_intensity(g,sfb))
   //          is_position[g][sfb] = p += dpcm_is_position[g][sfb];
   //
   //    /* Do intensity stereo decoding */
   //    for (b=0; b<window_group_length[g]; b++) {
   //       for (sfb=0; sfb<max_sfb; sfb++) {
   //          if (is_intensity(g,sfb)) {
   //             scale = is_intensity(g,sfb) * invert_intensity(g,sfb) *
   //                   0.5^(0.25*is_position[g][sfb]);
   //             /* Scale from left to right channel,
   //                do not touch left channel */
   //             for (i=0; i<swb_offset[sfb+1]-swb_offset[sfb]; i++)
   //                r_spec[g][b][sfb][i] = scale * l_spec[g][b][sfb][i];
   //          }
   //       }
   //    }
   // }

   // I1 = &window_group_length[0]
   I1 = (&$aacdec.ics_left + &$aacdec.ics.WINDOW_GROUP_LENGTH_FIELD);

   // M0 = window_offset = 0
   M0 = 0;

   // for (g=0; g<num_window_groups; g++) {
   // r0 = g = 0
   r7 = 1; // r7 = num_group_mask for ms_used
   r8 = 0;
   win_groups_loop:

      // for (b=0; b<window_group_length[g]; b++) {
      // r5 = window_group_length(g);
      r5 = M[I1,1];
      window_loop:

         // I2 = &swb_offset[0]
         r0 = M[$aacdec.ics_left + $aacdec.ics.SWB_OFFSET_PTR_FIELD];
         I2 = r0;

         // r6 = g*max_sfb + sfb
         r0 = M[$aacdec.ics_left + $aacdec.ics.MAX_SFB_FIELD];
         if Z jump sfb_loop_end;
         M1 = r0; // M1 = max_sfb
         r6 = r0 * r8 (int);

         // r4 = swb_offset[0]
         r4 = M[I2,1];

         // I3 = &sfb_cb_right[g][0]
         r0 = M[$aacdec.ics_right + $aacdec.ics.SFB_CB_PTR_FIELD];
         I3 = r0 + r6;

         // I5 = &scalefactors[g][0]
         r0 = M[$aacdec.ics_right + $aacdec.ics.SCALEFACTORS_PTR_FIELD];
         I5 = r0 + r6;

         // I6 = &ms_used[0]
         r0 = M[$aacdec.ics_left + $aacdec.ics.MS_USED_PTR_FIELD];
         I6 = r0;

         // for (sfb=0; sfb<max_sfb; sfb++) {
         sfb_loop:

            // r4 = swb_offset[sfb]
            // r3 = swb_offset[sfb+1]
            r3 = M[I2,1],
             r0 = M[I5,1]; // r0 = scalefactors[g][sfb] (is_position)

            r1 = M[I3,1],  // r1 = sfb_cb_right[g][sfb]
             r2 = M[I6,1]; // r2 = ms_used[g][sfb]

            rMAC = 1;

            // if (is_intensity(g,sfb)) {

            // check (is_intensity_right(g,sfb) != 0)
            Null = r1 - $aacdec.INTENSITY_HCB;
            if Z jump is_process_in_phase;
            Null = r1 - $aacdec.INTENSITY_HCB2;
            if NZ jump dont_is_process;

               is_process_out_phase:
               // rMAC = is_intensity_right(g,sfb)
               rMAC = -rMAC;
               is_process_in_phase:

               // scale = is_intensity(g,sfb) * invert_intensity(g,sfb) *
               //         0.5^(0.25*is_position[g][sfb]);

               r1 = M[$aacdec.ics_left + $aacdec.ics.MS_MASK_PRESENT_FIELD];
               Null = r1 - 1;
               if NZ jump no_ms_used;
                  // flip phase if ms_used
                  Null = r2 AND r7;
                  if NZ rMAC = -rMAC;
               no_ms_used:

               r0 = -r0;
               r1 = r0 AND 3;

               // r2 = scale's exponent
               r2 = r0 ASHIFT -2;
               r2 = r2 + 1;

               // r1 = scale's mantissa
               r1 = M[$aacdec.two2qtrx_lookup + r1];
               r1 = r1 * rMAC (int);

               // for (i=0; i<swb_offset[sfb+1]-swb_offset[sfb]; i++)
               //    r_spec[g][b][sfb][i] = scale * l_spec[g][b][sfb][i];

               r10 = r3 - r4;
               #ifndef AAC_USE_EXTERNAL_MEMORY
               // I0 = &spec_left[window*128 + swb_offset[sfb]];
               r0 = M0 + r4;
               I0 = r0 + &$aacdec.buf_left;
               // I4 = &spec_right[window*128 + swb_offset[sfb]];
               I4 = r0 + &$aacdec.buf_right;
               #else 
               r0 = M[$aacdec.buf_left_ptr]; 
               r0 = r0 + M0;
               I0  = r0 + r4;
               r0 = M[$aacdec.buf_right_ptr];
               r0 = r0 + M0;
               I4  = r0 + r4;
               #endif 
               do is_loop;
                  r0 = M[I0,1];
                  rMAC = r0 * r1;
                  r0 = rMAC ASHIFT r2;
                  M[I4,1] = r0;
               is_loop:

            dont_is_process:

            r4 = r3;

            // move on to next sfb
            r6 = r6 + 1;
            M1 = M1 - 1;
         if NZ jump sfb_loop;
         sfb_loop_end:

         // move on to the next window
         M0 = M0 + 128;
         r5 = r5 - 1;
      if NZ jump window_loop;

      // move on to the next window group
      r7 = r7 ASHIFT 1;
      r8 = r8 + 1;
      Null = r8 - M[$aacdec.ics_left + $aacdec.ics.NUM_WINDOW_GROUPS_FIELD];
   if NZ jump win_groups_loop;

   rts;

.ENDMODULE;
