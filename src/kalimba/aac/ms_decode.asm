// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.ms_decode
//
// DESCRIPTION:
//    Decode the MS (Middle and Side Stereo) data
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r8, r10, rMAC, I0-I6, M0, M1
//    - first 2 elements of $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.ms_decode;
   .CODESEGMENT AACDEC_MS_DECODE_PM;
   .DATASEGMENT DM;

   $aacdec.ms_decode:

   // for (g=0; g<num_window_groups; g++) {
   //    for (b=0; b<window_group_length[g]; b++) {
   //       for(sfb=0; sfb<max_sfb; sfb++) {
   //          if ((ms_used[g][sfb] || mask_present == 2) &&
   //             !is_intensity_right(g,sfb) &&
   //             !is_noise_right(g,sfb) && !is_noise_left(g,sfb)) {
   //             for (i=0; i< swb_offset[sfb+1]-swb_offset[sfb]; i++) {
   //                tmp = l_spec[g][b][sfb][i] - r_spec[g][b][sfb][i];
   //                l_spec[g][b][sfb][i] = l_spec[g][b][sfb][i] + r_spec[g][b][sfb][i];
   //                r_spec[g][b][sfb][i] = tmp;
   //             }
   //          }
   //       }
   //    }
   // }

   r8 = M[$aacdec.left_spec_blksigndet];
   r5 = M[$aacdec.right_spec_blksigndet];

   // I1 = &window_group_length[0]
   I1 = (&$aacdec.ics_left + &$aacdec.ics.WINDOW_GROUP_LENGTH_FIELD);

   // M0 = window_offset = 0
   M0 = 0;

   // for (g=0; g<num_window_groups; g++) {
   // r1 = g = 0
   r7 = 1; // r7 = num_group_mask for ms_used
   r1 = 0;
   M[$aacdec.tmp] = r1;
   win_groups_loop:

      // for (b=0; b<window_group_length[g]; b++) {
      // r5 = window_group_length(g);
      r2 = M[I1,1];
      M[$aacdec.tmp + 1] = r2;
      window_loop:

         // I2 = &swb_offset[0]
         r0 = M[$aacdec.ics_left + $aacdec.ics.SWB_OFFSET_PTR_FIELD];
         I2 = r0;

         // r6 = g*max_sfb + sfb
         r0 = M[$aacdec.ics_left + $aacdec.ics.MAX_SFB_FIELD];
         // skip the sfb_loop if max_sfb = 0
         if Z jump sfb_loop_end;
         M1 = r0; // M1 = max_sfb
         r6 = r0 * r1 (int);

         // r4 = swb_offset[0]
         r4 = M[I2,1];

         // I5 = &sfb_cb_left[g][0]
         r0 = M[$aacdec.ics_left + $aacdec.ics.SFB_CB_PTR_FIELD];
         I5 = r0 + r6;

         // I3 = &sfb_cb_right[g][0]
         r0 = M[$aacdec.ics_right + $aacdec.ics.SFB_CB_PTR_FIELD];
         I3 = r0 + r6;

         // I6 = &ms_used[0]
         r0 = M[$aacdec.ics_left + $aacdec.ics.MS_USED_PTR_FIELD];
         I6 = r0;

         // for (sfb=0; sfb<max_sfb; sfb++) {
         sfb_loop:

            // r4 = swb_offset[sfb]
            // r3 = swb_offset[sfb+1]
            r3 = M[I2,1],
             r0 = M[I5,1]; // r0 = sfb_cb_left[g][sfb]

            r1 = M[I3,1],  // r1 = sfb_cb_right[g][sfb]
             r2 = M[I6,1]; // r2 = ms_used[g][sfb]


            // if ((ms_used[g][sfb] || mask_present == 2) &&
            //     !is_intensity_right(g,sfb) &&
            //     !is_noise_right(g,sfb) && !is_noise_left(g,sfb)) {

            // check (mask_present == 2)
            rMAC = M[$aacdec.ics_left + $aacdec.ics.MS_MASK_PRESENT_FIELD];
            Null = rMAC - 2;
            if Z jump mask_present_equals_two;

               // check (ms_used(g,sfb) == 1)
               Null = r2 AND r7;
               if Z jump dont_ms_process;
            mask_present_equals_two:

            // check (is_noise_left(g,sfb) == 0)
            Null = r0 - $aacdec.NOISE_HCB;
            if Z jump dont_ms_process;

            // check (is_noise_right(g,sfb) == 0)
            Null = r1 - $aacdec.NOISE_HCB;
            if Z jump dont_ms_process;

            // check (is_intensity_right(g,sfb) == 0)
            Null = r1 - $aacdec.INTENSITY_HCB;
            if Z jump dont_ms_process;
            Null = r1 - $aacdec.INTENSITY_HCB2;
            if Z jump dont_ms_process;

               // for (i=0; i< swb_offset[sfb+1]-swb_offset[sfb]; i++) {
               //    tmp = l_spec[g][b][sfb][i] - r_spec[g][b][sfb][i];
               //    l_spec[g][b][sfb][i] = l_spec[g][b][sfb][i] + r_spec[g][b][sfb][i];
               //    r_spec[g][b][sfb][i] = tmp;
               // }
               r10 = r3 - r4;
               // I0 = &spec_left[window*128 + swb_offset[sfb]];
               r0 = M0 + r4;
               #ifndef AAC_USE_EXTERNAL_MEMORY
               I0 = r0 + &$aacdec.buf_left;
               #else
               r1 = M[$aacdec.buf_left_ptr]; 
               I0 = r0 + r1;
               #endif
               // I4 = &spec_right[window*128 + swb_offset[sfb]];
               #ifndef AAC_USE_EXTERNAL_MEMORY
               I4 = r0 + &$aacdec.buf_right;
               #else
               r1 = M[$aacdec.buf_right_ptr]; 
               I4 = r0 + r1;
               #endif
               r0 = $ADDSUB_SATURATE_ON_OVERFLOW_MASK;
               M[$ARITHMETIC_MODE] = r0;
               r0 = 0;
               do ms_loop;
                  r5 = BLKSIGNDET r0,
                   r0 = M[I0,0],
                   r1 = M[I4,0];
                  r2 = r0 + r1;
                  r0 = r0 - r1,
                   M[I0,1] = r2;
                  r8 = BLKSIGNDET r2,
                     M[I4,1] = r0;
               ms_loop:
               r5 = BLKSIGNDET r0;
               M[$ARITHMETIC_MODE] = Null;

            dont_ms_process:

            r4 = r3;

            // move on to next sfb
            r6 = r6 + 1;
            M1 = M1 - 1;
         if NZ jump sfb_loop;
         sfb_loop_end:

         // move on to the next window
         M0 = M0 + 128;
         r1 = M[$aacdec.tmp];
         r2 = M[$aacdec.tmp + 1];
         r2 = r2 - 1;
         M[$aacdec.tmp + 1] = r2;
      if NZ jump window_loop;

      // move on to the next window group
      r7 = r7 ASHIFT 1;
      r1 = r1 + 1;
      M[$aacdec.tmp] = r1;
      Null = r1 - M[$aacdec.ics_left + $aacdec.ics.NUM_WINDOW_GROUPS_FIELD];
   if NZ jump win_groups_loop;

   M[$aacdec.left_spec_blksigndet] = r8;
   M[$aacdec.right_spec_blksigndet] = r5;

   rts;

.ENDMODULE;
