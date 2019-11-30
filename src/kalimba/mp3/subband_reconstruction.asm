// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_SUBBAND_RECONSTRUCTION_INCLUDED
#define MP3DEC_SUBBAND_RECONSTRUCTION_INCLUDED

#include "stack.h"
#include "mp3.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.subband_reconstruction
//
// DESCRIPTION:
//    Subband Reconstruction
//
// INPUTS:
//    - r9 = pointer to table of external memory pointers
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    rMAC, r0-r9, r10, M0-M3, I1-I7
//
// NOTES:
//    Uses r9
//
// *****************************************************************************
.MODULE $M.mp3dec.subband_reconstruction;
   .CODESEGMENT MP3DEC_SUBBAND_RECONSTRUCTION_PM;
   .DATASEGMENT DM;

   $mp3dec.subband_reconstruction:

   .VAR $mp3dec.adjusted_global_gain;

   // push rLink onto stack
   $push_rLink_macro;

   // Save the external memory pointer
   push r9;

   // setup registers for requantisation subroutine
   r5 = 3;
   I3 = (&$mp3dec.x43_lookup2 - 9);
   M3 = 9;
   r4 = 0x200000;
   I0 = &$mp3dec.region_size;

#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.GENBUF_FIELD];
   I1 = r0 + 1;
#else
   I1 = &$mp3dec.genbuf + 1;
#endif

   r9 = 0;


   //   Precalculate the scalefactors for each frequency line
   //   using the requantization formulae
   //
   // For long blocks (and first 2 subbands of mixed blocks):
   //
   //     Scale = global_gain - 210 - 4 *
   //                scale_multipler * (scalefac_l[sfb] + preflag * pretab[sfb])
   //
   //
   // For short blocks:
   //
   //     Scale = global_gain - 210 - 8 * subblockgain[win] - 4 *
   //                scale_multipler * scalefac_s[sfb][win]
   //
   //

   // Setup pointers etc. depending on current channel/granule
   r0 = M[$mp3dec.current_grch];     // bit 0 = channel,  bit 1 = granule

   r1 = r0 AND $mp3dec.CHANNEL_MASK;
   if NZ jump is_right;
      #ifdef BASE_REGISTER_MODE
         r8 = M[$mp3dec.arbuf_start_left];
      #endif
      r2 = M[$mp3dec.arbuf_left_pointer];
      r3 = M[$mp3dec.arbuf_left_size];
      jump ar_Buf_initialised;
   is_right:
      #ifdef BASE_REGISTER_MODE
         r8 = M[$mp3dec.arbuf_start_right];
      #endif
      r2 = M[$mp3dec.arbuf_right_pointer];
      r3 = M[$mp3dec.arbuf_right_size];
   ar_Buf_initialised:
   I4 = r2;                          // I4 = ar_Buf left or right
   L4 = r3;

   #ifdef BASE_REGISTER_MODE
      push r8; // There is a stall in here, so these two stack instructions can be split up
      pop B4;
   #endif

   // calculate the number of (remaining) non-zero samples
   r2 = M[$mp3dec.rzerolength + r1];
   M2 = 576 - r2;

   r1 = r1 * ($mp3dec.NUM_SHORT_SF_BANDS*3) (int);
   I7 = &$mp3dec.scalefac + r1;      // I7 = scale_fac (left or right)
   r1 = M[$mp3dec.preflag + r0];     // set preflag depending on channel & granule
   M1 = r1;                   // ie. if no pre-emphasis M0 = 0
                              // therefore pretab value will = 0 always

   r8 = M[$mp3dec.scale_multiplier_x4 + r0];
   r1 = M[$mp3dec.global_gain + r0];
   r1 = r1 - (210 - 6 * 4);
   M[$mp3dec.adjusted_global_gain] = r1;


   r0 = M[$mp3dec.block_type + r0];
   Null = r0 - $mp3dec.SHORT_MASK;
   if Z jump short_window;    // if mixed_block_flag = 0 and short window

   long_window:

      r7 = 15;
      Null = r0 - ($mp3dec.SHORT_MASK + $mp3dec.MIXED_MASK);
                                 // if mixed_block_flag = 1 and short window
      if NZ r7 = 0;              // then r7 = 15 else r7 = 0

      I5 = &$mp3dec.pretab;

      #if defined(MP3DEC_ZERO_FLASH)
         r0 = M[$mp3dec.sampling_freq];
         r0 = r0 * $mp3dec.NUM_LONG_SF_BANDS (int);
         I6 = r0 + &$mp3dec.sfb_width_long;
      #else
         I6 = &$mp3dec.sfb_width_long;
      #endif

      M0 = $mp3dec.NUM_LONG_SF_BANDS;
      long_loop:

         r0 = M[I7,1];              // get scalefac[sfb]
         r1 = M[I5,M1];             // get pretab[sfb]
         r0 = r0 + r1;
         r0 = r0 * r8 (int),
          r1 = M[I6,1];
         call $mp3dec.requantise_subband;

         Null = M0 - r7;
         if Z jump short_window;
         M0 = M0 - 1;
      if NZ jump long_loop;

      // take care of rzero region
      jump zero_rzero;

   short_window:
      #if defined(MP3DEC_ZERO_FLASH)
         r0 = M[$mp3dec.sampling_freq];
         r0 = r0 * $mp3dec.NUM_SHORT_SF_BANDS (int);
         I6 = r0 + &$mp3dec.sfb_width_short;
      #else
         I6 = &$mp3dec.sfb_width_short;
      #endif

      r1 = M[$mp3dec.current_grch];
      r0 = r1 * 3 (int);
      I5 = r0 + &$mp3dec.subblock_gain;

      M0 = ($mp3dec.NUM_SHORT_SF_BANDS*3);

      r0 = M[$mp3dec.block_type + r1];
      Null = r0 AND $mp3dec.MIXED_MASK;
      if Z jump short_not_mixed;
         I6 = I6 + 3;
         M0 = (($mp3dec.NUM_SHORT_SF_BANDS-3)*3);
      short_not_mixed:

      r7 = 4;
      short_loop:

         r7 = r7 - 1;            // next window
         if NZ jump short_no_win_reset;
            r7 = 3;                 // if all 3 windows done then back to 1st
            I5 = I5 - 3;
            I2 = I2 - r7,
             r1 = M[I6,1];          // and onto next scalefactor subband
         short_no_win_reset:

         r0 = M[I7,1];           // get scalefac[sfb][window]
         r0 = r0 * r8 (int),
          r1 = M[I5,1];          // get subblock_gain[win] (already *8)
         r0 = r0 + r1,
          r1 = M[I6,0];

         call $mp3dec.requantise_subband;


         M0 = M0 - 1;
      if NZ jump short_loop;

      // take care of rzero region
      zero_rzero:
      r0 = M[$mp3dec.current_grch];     // bit 0 = channel,  bit 1 = granule
      r0 = r0 AND $mp3dec.CHANNEL_MASK;
      r10 = M[$mp3dec.rzerolength + r0];
      r0 = 0;
      do rzero_loop;
         M[I4, 1] = r0;
      rzero_loop:

      // pop rLink from stack
      L4 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         pop B4;
      #endif

      // Restore the external memory pointer
      pop r9;

      jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
