// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_JOINTSTEREO_PROCESSING_INCLUDED
#define MP3DEC_JOINTSTEREO_PROCESSING_INCLUDED

#include "stack.h"
#include "mp3.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.jointstereo_processing
//
// DESCRIPTION:
//    Joint Stereo Processing
//
// INPUTS:
//    - L0: length of arbuf_right cbuffer
//    - L4: length of arbuf_left cbuffer
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    rMAC, r0-r8, r10, DoLoop, I0-7, M0
//
// NOTES:
//          Joint stereo processing (Intensity and / or MS Stereo)
//
//  For MS Stero:
//
//      Left[i]  = (Middle[i] + Side[i]) / sqrt(2)
//
//      Right[i] = (Middle[i] - Side[i]) / sqrt(2)
//
//   The Middle values are transmitted in the left channel and Side values
//    in the right channel
//
//
//  For Intensity Stereo:
//
//    Scalefactor bands:
//  |  |   |    |     |  ...  |        |       |             |             |
//  |<-- nonzero part of spectrm (R chan) -->|<--- zero part of spectrm -->|
//  |<------ m/s or l/r stereo coded part ---->|<- intensity stereo part ->|
//
//   1) the intensity stereo position is_pos[sfb] is read from the
//      scalefactor of the right channel
//
//   2) if (is_pos[sfb] == 7) do not perform the following steps
//      (illegal is_pos)
//
//   3) is_ratio = tan(ispos[sfb] * pi / 12)
//
//   4) Left[i]  = Left[i] * is_ratio / (1 + is_ratio)
//
//   5) Right[i] = Left[i] * 1 / (1 + is_ratio)
//
//  See page 35 & 36 of ISO 11172-3 for more details
//
//
//  Note for MPEG2 LSE steps 4) and 5) above are changed to:
//   4) Left[i]  = Left[i] * Kr
//   5) Right[i] = Left[i] * Kl
//
//   The values Kl and Kr are calculated from the transmitted scalefactor / is_pos
//   value as follows:
//
//     if (is_pos == 0)            Kl = 1.0                  Kr = 1.0
//     elseif (is_pos % 2 == 1)    Kl = i0^((is_pos+1)/2)    Kr = 1.0
//     else                        Kl = 1.0                  Kr = i0^(is_pos/2)
//
//   Where i0 = 1/sqrt(2) if intensity_scale == 1
//     and i0 = 1/sqrt(sqrt(2)) if intensity_scale == 0
//
//   Also MPEG2 LSE confirms that when processing short windows that each window
//   should be processed separately
//
// *****************************************************************************
.MODULE $M.mp3dec.jointstereo_processing;
   .CODESEGMENT MP3DEC_JOINTSTEREO_PROCESSING_PM;
   .DATASEGMENT DM;

   $mp3dec.jointstereo_processing:

   // push rLink onto stack
   $push_rLink_macro;

   // set default intensity sfb (ie. last+1) at start
   #if defined(MP3DEC_ZERO_FLASH)
      r2 = M[$mp3dec.sampling_freq];
      r0 = r2 * $mp3dec.NUM_LONG_SF_BANDS (int);
      r0 = r0 + (&$mp3dec.sfb_width_long + $mp3dec.NUM_LONG_SF_BANDS);
      M[$mp3dec.intensity_sfb_l] = r0;
      r0 = r2 * $mp3dec.NUM_SHORT_SF_BANDS (int);
      r0 = r0 + (&$mp3dec.sfb_width_short + $mp3dec.NUM_SHORT_SF_BANDS);
   #else
      r0 = (&$mp3dec.sfb_width_long + $mp3dec.NUM_LONG_SF_BANDS);
      M[$mp3dec.intensity_sfb_l] = r0;
      r0 = (&$mp3dec.sfb_width_short + $mp3dec.NUM_SHORT_SF_BANDS);
   #endif
   M[$mp3dec.intensity_sfb_s + 0] = r0;
   M[$mp3dec.intensity_sfb_s + 1] = r0;
   M[$mp3dec.intensity_sfb_s + 2] = r0;


   // see if intensity stereo selected
   r0 = M[$mp3dec.mode_extension];
   Null = r0 AND $mp3dec.IS_MASK;
   if Z jump not_intensity;
      // -- INTENSITY STEREO MODE --

      // r1 = right chan block type
      r1 = M[$mp3dec.current_grch];
      r1 = M[$mp3dec.block_type + r1];
      Null = r1 AND $mp3dec.SHORT_MASK;
      if Z jump not_short_windows_calc;
         // -- SHORT WINDOW sfb calc --

         // for each window find scalefactor band that intensity stereo will start at

         // I2 = &$mp3dec.sfb_width_short[-1]
         #if defined(MP3DEC_ZERO_FLASH)
            r0 = r2 * $mp3dec.NUM_SHORT_SF_BANDS (int);
            I2 = r0 + (&$mp3dec.sfb_width_short - 1);
         #else
            I2 = (&$mp3dec.sfb_width_short - 1);
         #endif

         // r3 = current window number
         r3 = 0;
         r4 = M[$mp3dec.arbuf_right_pointer];
         I0 = r4;
         #ifdef BASE_REGISTER_MODE
            r4 = M[$mp3dec.arbuf_start_left];
            push r4;
            B1 = M[SP - 1];
            pop B0;
         #endif
         M0 = 575;
         r0 = M[I0, M0];
         r4 = I0;
         L1 = L0;

         short_find_non_zero_window_loop:

            // I3 = &$mp3dec.sfb_width_short[12]
            I3 = I2 + $mp3dec.NUM_SHORT_SF_BANDS;

            // I1 = last sample buffer
            I1 = r4;             // (&$mp3dec.arbuf_right + 575);


            short_find_non_zero_scalefactor_loop:
               // read scalefactor width
               r0 = M[I3,-1];
               r10 = r0;

               // set I0 to point to appropriate window's sfb
               r0 = r3 - 2;
               r0 = r0 * r10 (int);
               M0 = r0;
               I0 = I1;
               r0 = M[I0, M0];   // dummy read I0 = I1 + r0;


               // decrement I1 by sfb_width*3
               r0 = r10 * 3 (int);
               M0 = -r0;
               r0 = M[I1, M0];   // dummy read I1 = I1 - r0;

               // see if any non_zero samples in this scalefactor
               do short_find_non_zero_sample_loop;
                  r0 = M[I0,-1];
                  Null = r0;
                  if NZ jump short_non_zero_found;
               short_find_non_zero_sample_loop:

               Null = I3 - I2;
            if NZ jump short_find_non_zero_scalefactor_loop;

            // if 1st sfb is all zero then need to adjust I3
            I3 = I3 - 1;

            short_non_zero_found:

            Null = r1 AND $mp3dec.MIXED_MASK;
            if Z jump not_mixed;
               // if mixed blocks and sfb < 3 then set it to 3;
               r0 = I2 + 2;
               Null = I3 - r0;
               if NEG I3 = r0;
            not_mixed:
            // store sfb for later
            r0 = I3 + 2;
            M[$mp3dec.intensity_sfb_s + r3] = r0;

            r3 = r3 + 1;
            Null = r3 - 3;
         if NZ jump short_find_non_zero_window_loop;
         L1 = 0;
         #ifdef BASE_REGISTER_MODE
            push Null;
            pop B1;
         #endif
      not_short_windows_calc:



      Null = r1 AND ($mp3dec.MIXED_MASK + $mp3dec.START_MASK + $mp3dec.LONG_MASK + $mp3dec.END_MASK);
      if Z jump not_long_windows_calc;
         // -- LONG WINDOW sfb calc --

         // I3 = $mp3dec.sfb_width_long[21]
         #if defined(MP3DEC_ZERO_FLASH)
            r0 = r2 * $mp3dec.NUM_LONG_SF_BANDS (int);
            I3 = r0 + (&$mp3dec.sfb_width_long + $mp3dec.NUM_LONG_SF_BANDS - 1);
         #else
            I3 = (&$mp3dec.sfb_width_long + $mp3dec.NUM_LONG_SF_BANDS - 1);
         #endif

         r10 = $mp3dec.NUM_LONG_SF_BANDS;
         // r3 = rzero length (of the second channel)
         r3 = M[$mp3dec.rzerolength + 1];
         do long_find_non_zero_scalefactor_loop;
            r0 = M[I3,-1];
            r3 = r3 - r0;
            if NEG jump long_non_zero_found;
         long_find_non_zero_scalefactor_loop:

         // if 1st sfb is all zero then need to adjust I3
         I3 = I3 - 1;

         long_non_zero_found:
         // store sfb for later
         r0 = I3 + 2;
         M[$mp3dec.intensity_sfb_l] = r0;
      not_long_windows_calc:



      // set I6 to correct is_coefs depending on if MPEG1/2
      I6 = &$mp3dec.is_coef;
      r0 = M[$mp3dec.frame_version];
      Null = r0 - $mp3dec.MPEG1;
      if Z jump mpeg1_no_lse;
         I6 = &$mp3dec.is_coef_lse_scale0;
         Null = M[$mp3dec.intensity_scale];
         if Z jump mpeg1_no_lse;
         I6 = &$mp3dec.is_coef_lse_scale1;
      mpeg1_no_lse:



      Null = r1 AND $mp3dec.SHORT_MASK;
      if Z jump long_window;
         // -- SHORT WINDOW intensity processing --

         // M1 = &scalefac_s(gr,2,0);
         M1 = &$mp3dec.scalefac + 39;

         // I2 = &$mp3dec.sfb_width_short[0]
         #if defined(MP3DEC_ZERO_FLASH)
            r0 = r2 * $mp3dec.NUM_SHORT_SF_BANDS (int);
            I2 = r0 + &$mp3dec.sfb_width_short;
         #else
            I2 = &$mp3dec.sfb_width_short;
         #endif

         // r8 = flag to know whether to process long windows of a mixed block
         r8 = 0;
         Null = r1 AND $mp3dec.MIXED_MASK;
         if Z jump short_not_mixed;
            r8 = 1;
            // if mixed blocks then short scalefactors start 1 memory location earlier
            // due to 0-7 long sfbs  and (0-2)*3 short sfbs
            M1 = M1 - 1;
         short_not_mixed:


         // r7 = current window to process
         r7 = 0;
         short_window_loop:

            // if intensity scalefactor band > 3 then no need to process long
            // windows of a mixed block
            r6 = M[$mp3dec.intensity_sfb_s + r7];
            r6 = r6 - I2;
            Null = r6 - 3;
            if GT r8 = 0;

            // find starting sample by summing the scalefactor widths up to r6
            r10 = r6;
            I3 = I2;
            r3 = 0;
            do short_sum_sfbs;
               r0 = M[I3,1];
               r3 = r3 + r0;
            short_sum_sfbs:
            // r3 = start_of_sfb
            r3 = r3 * 3 (int);

            short_sfb_loop:
               Null = r6 - 13;
               if Z jump done_short_sfb_loop;

               // read width of next scalefactor
               r0 = M[I3,1];
               r10 = r0;

               // starting sample = start_of_sfb + win*sfb_width
               r0 = r7 * r10 (int);
               M0 = r0 + r3;
               #ifdef BASE_REGISTER_MODE
                  r0 = M[$mp3dec.arbuf_start_left];
                  push r0;
                  pop B4;
               #endif
               #ifdef BASE_REGISTER_MODE
                  r0 = M[$mp3dec.arbuf_start_right];
                  push r0;
                  pop B0;
               #endif
               r0 = M[$mp3dec.arbuf_right_pointer];
               I0 = r0;
               r0 = M[$mp3dec.arbuf_left_pointer];
               I4 = r0,
                r0 = M[I0, M0];
               r0 = M[I4, M0];

               // increment start_of_sfb for next time
               r0 = r10 * 3 (int);
               r3 = r3 + r0;

               // read the scalefactor i.e. is_pos = SI.scalefac_s(gr,2,sfb,win)
               // if sfb==12 then use the scalefactor from band 11
               r0 = r6 - 11;
               if POS r0 = 0;
               r0 = r0 + 11;
               r0 = r0 * 3 (int);
               r0 = r0 + M1;
               r0 = M[r7 + r0];

               // process subband
               call $mp3dec.intensity_processor;

            jump short_sfb_loop;
            done_short_sfb_loop:

            r7 = r7 + 1;
            Null = r7 - 3;
         if NZ jump short_window_loop;

         Null = r8;
         if Z jump no_long_mixed_block_todo;

            // -- LONG WINDOW OF MIXED BLOCK intensity processing --

            // I2 = &$mp3dec.sfb_width_long[0]
            #if defined(MP3DEC_ZERO_FLASH)
               r0 = r2 * $mp3dec.NUM_LONG_SF_BANDS (int);
               I2 = r0 + &$mp3dec.sfb_width_long;
            #else
               I2 = &$mp3dec.sfb_width_long;
            #endif

            r6 = M[$mp3dec.intensity_sfb_l];
            r6 = r6 - I2;

            // find starting sample by summing the scalefactor widths up to r6
            r10 = r6;
            I3 = I2;
            r3 = 0;
            do long_mixed_sum_sfbs;
               r0 = M[I3,1];
               r3 = r3 + r0;
            long_mixed_sum_sfbs:
            // r3 = start_of_sfb

            long_mixed_sfb_loop:
               Null = r6 - 8;
               if Z jump done_long_mixed_sfb_loop;

               // read width of next scalefactor
               r0 = M[I3,1];
               r10 = r0;

               // starting sample = start_of_sfb
               M0 = r3;
               r0 = M[$mp3dec.arbuf_right_pointer];
               I0 = r0;
               r0 = M[$mp3dec.arbuf_left_pointer];
               I4 = r0;
               r0 = M[I0, M0],              // dummy read: I0 = &$mp3dec.arbuf_right + r3;
                r0 = M[I4, M0];             // dummy read:I4 = &$mp3dec.arbuf_left + r3;

               // increment start_of_sfb for next time
               r3 = r3 + r10;

               // read the scalefactor i.e. is_pos = SI.scalefac_l(gr,2,sfb)
               r0 = M[($mp3dec.scalefac + 39) + r6];

               // process subband
               call $mp3dec.intensity_processor;

            jump long_mixed_sfb_loop;
            done_long_mixed_sfb_loop:

         no_long_mixed_block_todo:
         jump intensity_block_type_done;


      long_window:
         // -- LONG WINDOW intensity processing --

         // I2 = &$mp3dec.sfb_width_long[0]
         #if defined(MP3DEC_ZERO_FLASH)
            r0 = r2 * $mp3dec.NUM_LONG_SF_BANDS (int);
            I2 = r0 + &$mp3dec.sfb_width_long;
         #else
            I2 = &$mp3dec.sfb_width_long;
         #endif

         r6 = M[$mp3dec.intensity_sfb_l];
         r6 = r6 - I2;

         // find starting sample by summing the scalefactor widths up to r6
         r10 = r6;
         I3 = I2;
         r3 = 0;
         do long_sum_sfbs;
            r0 = M[I3,1];
            r3 = r3 + r0;
         long_sum_sfbs:
         // r3 = start_of_sfb

         long_sfb_loop:
            Null = r6 - 22;
            if Z jump done_long_sfb_loop;

            // read width of next scalefactor
            r0 = M[I3,1];
            r10 = r0;

            // starting sample = start_of_sfb
            M0 = r3;
            r0 = M[$mp3dec.arbuf_right_pointer];
            I0 = r0;
            r0 = M[$mp3dec.arbuf_left_pointer];
            I4 = r0;
            r0 = M[I0, M0],              // dummy read: I0 = &$mp3dec.arbuf_right + r3;
             r0 = M[I4, M0];             // dummy read:I4 = &$mp3dec.arbuf_left + r3;

            // increment start_of_sfb for next time
            r3 = r3 + r10;

            // read the scalefactor i.e. is_pos = SI.scalefac_l(gr,2,sfb)
            // if sfb==21 then use the scalefactor from band 20
            r0 = r6 - 20;
            if POS r0 = 0;
            r0 = r0 + 20;
            r0 = M[($mp3dec.scalefac + 39) + r0];

            // process subband
            call $mp3dec.intensity_processor;

         jump long_sfb_loop;
         done_long_sfb_loop:

      intensity_block_type_done:
   not_intensity:


   // see if MS stereo selected
   r0 = M[$mp3dec.mode_extension];
   Null = r0 AND $mp3dec.MS_MASK;
   if Z jump $pop_rLink_and_rts;
      // -- MIDDLE-SIDE STEREO MODE --

      // r1 = right chan block type
      r1 = M[$mp3dec.current_grch];

      r5 = 0.70710678118655;

      r1 = M[$mp3dec.block_type + r1];
      Null = r1 AND $mp3dec.SHORT_MASK;
      if Z jump ms_long_window;
         // -- SHORT WINDOW --

         // for each window need to do ms processing

         // r7 = current window to process
         r7 = 0;
         ms_short_window_loop:

            // I2 = &$mp3dec.sfb_width_short[0]
            #if defined(MP3DEC_ZERO_FLASH)
               r0 = r2 * $mp3dec.NUM_SHORT_SF_BANDS (int);
               I2 = r0 + (&$mp3dec.sfb_width_short);
            #else
               I2 = &$mp3dec.sfb_width_short;
            #endif

            r6 = M[$mp3dec.intensity_sfb_s + r7];
            r6 = r6 - I2;
            if Z jump done_ms_short_sfb_loop;

            r3 = 0;
            // loop through all the non-intensity sfbs
            ms_short_sfb_loop:

               r0 = M[I2,1];
               r10 = r0;

               // set pointers to left and right samples for this window
               r0 = r7 * r10 (int);
               M0 = r0 + r3;
               r0 = M[$mp3dec.arbuf_right_pointer];
               I0 = r0;
               r0 = M[$mp3dec.arbuf_left_pointer];
               I4 = r0;
               r0 = M[I0, M0],              // dummy read: I0 = &$mp3dec.arbuf_right + r3;
                r0 = M[I4, M0];             // dummy read:I4 = &$mp3dec.arbuf_left + r3;

               // increment start_sfb
               r0 = r10 * 3 (int);
               r3 = r3 + r0;

               // middle and side processing
               r0 = r10;
               call $mp3dec.fast_ms_decode;

               r6 = r6 - 1;
            if NZ jump ms_short_sfb_loop;
            done_ms_short_sfb_loop:

            r7 = r7 + 1;
            Null = r7 - 3;
         if NZ jump ms_short_window_loop;
         jump $pop_rLink_and_rts;

      ms_long_window:
         // -- LONG WINDOW --
         // for the long window need to do ms processing


         // set pointers to left and right samples for this window
         r0 = M[$mp3dec.arbuf_right_pointer];
         I0 = r0;
         r0 = M[$mp3dec.arbuf_left_pointer];
         I4 = r0;
         #ifdef BASE_REGISTER_MODE
            r10 = M[$mp3dec.arbuf_start_left];
            r0 = M[$mp3dec.arbuf_start_right];
            pushm <r0,r10>;
            popm  <B0,B4>;
         #endif

         // I2 = &$mp3dec.sfb_width_long[0]
         #if defined(MP3DEC_ZERO_FLASH)
            r0 = r2 * $mp3dec.NUM_LONG_SF_BANDS (int);
            I2 = r0 + (&$mp3dec.sfb_width_long);
         #else
            I2 = &$mp3dec.sfb_width_long;
         #endif

         r10 = M[$mp3dec.intensity_sfb_l];
         r10 = r10 - I2;
         if Z jump $pop_rLink_and_rts;

         // set-up m/s loop
         r0 = 0,
          r1 = M[I2, 1];
         do ms_length_loop;
            r0 = r0 + r1,
             r1 = M[I2, 1];
         ms_length_loop:

         // middle and side processing
         call $mp3dec.fast_ms_decode;

         jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $mp3dec.fast_ms_decode
//
// DESCRIPTION:
//    decodes a given number middle-side joint stereo samples
//
// INPUTS:
//    - I0 = buffer pointer to right ring buffer
//    - I4 = buffer pointer to left ring buffer
//    - L0 = right buffer size
//    - L4 = left buffer size
//    - r0 = number samples to be processed
//    - r5 = 0.70710678118655
//
// OUTPUTS:
//    - I0  = buffer pointer to right ring buffer (updated)
//    - I4  = buffer pointer to left ring buffer (updated)

//
// TRASHED REGISTERS:
//    rMAC, r0, r4, L1 = 0, L5 = 0, I1, I5, DoLoop
//
// *****************************************************************************
.MODULE $M.mp3dec.fast_ms_decode;
   .CODESEGMENT MP3DEC_FAST_MS_DECODE_PM;
   .DATASEGMENT DM;

   $mp3dec.fast_ms_decode:

   r10 = r0 - 1;
   I1 = I4; L1 = L4;    // I1 = write pointer left
   I5 = I0; L5 = L0;    // I5 = write pointer right
   #ifdef BASE_REGISTER_MODE
      pushm <B0,B4>;
      pop B1;
      pop B5;
   #endif

   // pre-loop processing
   r4 = M[I4, 1];
   rMAC = r4 * r5,
    r0 = M[I0, 1];
   rMAC = rMAC + r0 * r5;

   rMAC = r4 * r5,
    M[I1, 1] = rMAC,
    r4 = M[I4, 1];
   rMAC = rMAC - r0 * r5;

   // loop through all the non-intensity sfbs
   do ms_long_loop;
      rMAC = r4 * r5,
       r0 = M[I0, 1],
       M[I5, 1] = rMAC;
      rMAC = rMAC + r0 * r5;
      rMAC = r4 * r5,
       M[I1, 1] = rMAC,
       r4 = M[I4, 1];
      rMAC = rMAC - r0 * r5;
   ms_long_loop:
   L1 = 0,
    M[I5, 1] = rMAC;
   L5 = 0;
   #ifdef BASE_REGISTER_MODE
      // Set base registers back to zero (shortcut: use zeroed L registers)
      pushm <L1,L5>;
      popm <B1,B5>;
   #endif
   rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $mp3dec.intensity_processor
//
// DESCRIPTION:
//    decodes a given number intensity stereo samples
//
// INPUTS:
//    - I0  = buffer pointer to right ring buffer
//    - I4  = buffer pointer to left ring buffer
//    - L0  = right buffer size
//    - L4  = left buffer size
//    - r10 = number samples to be processed
//    - r6  = scalefactor sub-band counter
//    - r0  = scalefactor (is_pos) for the current sub-band
//    - I6  = pointer to is coefficient table
//
// OUTPUTS:
//    - I0  = buffer pointer to right ring buffer (updated)
//    - I4  = buffer pointer to left ring buffer (updated)
//    - r6  = r6 + 1
//
// TRASHED REGISTERS:
//    rMAC, r0, r4, r5 L1 = 0, L5 = 0, I1, I5, DoLoop
//
// *****************************************************************************
.MODULE $M.mp3dec.intensity_processor;
   .CODESEGMENT MP3DEC_INTENSITY_PROCESSOR_PM;
   .DATASEGMENT DM;

   $mp3dec.intensity_processor:

   // push rLink onto stack
   $push_rLink_macro;

   // check if is_pos is set to the illegal value of 7
   Null = r0 - 7;
   if Z jump illegal_is_pos;

      // r4 = is_coefs_left[is_pos];
      // r5 = is_coefs_right[is_pos];
      r4 = I6 + r0;
      r5 = M[r4 + 32]; //($mp3dec.isright_coef - $mp3dec.isleft_coef)];
      r4 = M[r4];

      do is_loop;
         // tmp = left sample
         r0 = M[I4,0];
         // right = tmp * is_coefs_right[is_pos];
         rMAC = r0 * r5 (frac);
         // left  = tmp * is_coefs_left[is_pos];
         r0 = r0 * r4 (frac),
          M[I0,1] = rMAC;
         M[I4,1] = r0;
      is_loop:

      jump done_this_sfb;

   illegal_is_pos:
      // if ms stereo selected carry it out on this band
      r0 = M[$mp3dec.mode_extension];
      Null = r0 AND $mp3dec.MS_MASK;
      if Z jump done_this_sfb;

      // middle and side processing
      r5 = 0.70710678118655;
      r0 = r10;
      call $mp3dec.fast_ms_decode;

   done_this_sfb:
   r6 = r6 + 1;

   jump $pop_rLink_and_rts;


.ENDMODULE;

#endif
