// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_REORDER_SPECTRUM_INCLUDED
#define MP3DEC_REORDER_SPECTRUM_INCLUDED

#include "mp3.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.reorder_spectrum
//
// DESCRIPTION:
//    Reorder Spectrum
//
//  For long blocks:  Just copies values
//  For short blocks: Reorders from [sfb][win][freq] to [subband][win][freq]
//
// INPUTS:
//    - r9 = pointer to table of external memory pointers
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0-r5, r10, DoLoop, I0, I1, I4, M0-M3
//
// *****************************************************************************

.MODULE $M.mp3dec.reorder_spectrum;
   .CODESEGMENT MP3DEC_REORDER_SPECTRUM_PM;
   .DATASEGMENT DM;

   $mp3dec.reorder_spectrum:

   r5 = M[$mp3dec.current_grch];
   r5 = r5 AND $mp3dec.GRANULE_MASK;
   M2 = 6;

   chan_loop:

      Null = r5 AND 1;
      if NZ jump is_right;
         r0 = M[$mp3dec.arbuf_left_pointer];
         r1 = M[$mp3dec.arbuf_left_size];
         jump ar_Buf_initialised;
      is_right:
         r0 = M[$mp3dec.arbuf_right_pointer];
         r1 = M[$mp3dec.arbuf_right_size];
      ar_Buf_initialised:
      I1 = r0; L1 = r1;             // I1 = I4 = ^arbuf_left/Right
      I4 = r0; L4 = r1;

#ifdef MP3_USE_EXTERNAL_MEMORY
      r0 = M[r9 + $mp3dec.mem.GENBUF_FIELD];
      I0 = r0;
#else
      I0 = &$mp3dec.genbuf;         // I0 = ^genbuf
#endif


      #if defined(MP3DEC_ZERO_FLASH)
         r0 = M[$mp3dec.sampling_freq];
         r0 = r0 * $mp3dec.NUM_SHORT_SF_BANDS (int);
         r1 = r0 + &$mp3dec.sfb_width_short;
      #else
         r1 = &$mp3dec.sfb_width_short;
      #endif
      r4 = 7;


      r0 = M[$mp3dec.block_type + r5];
      Null = r0  - $mp3dec.SHORT_MASK;
      if Z jump short_not_mixed;
      Null = r0  - ($mp3dec.MIXED_MASK + $mp3dec.SHORT_MASK);
      if NZ jump reorder_done; // Long blocks do nothing

      short_mixed:           // Short blocks, mixed_flag = 1

         r10 = 36;
         r3 = 10;               // set up for short blocks below
         r1 = r1 + 3;
         do short_mixed_loop;   // copy across first 36 values
            r0 = M[I4,1];
            M[I0,1] = r0;
         short_mixed_loop:
         jump short_loop;

      short_not_mixed:       // Short blocks, mixed_flag = 0

         r3 = $mp3dec.NUM_SHORT_SF_BANDS;
         short_loop:            // copy across with rearranging

            M3 = -11;

            r10 = M[r1];
            M0 = r10;

            r2 = r10 * -2 (int);
            M1 = r2 + 1;

            do short_inner_loop;

               r4 = r4 - 1;            // see if new subband change
               if NZ jump short_no_newsb;
                  r4 = 6;
                  I0 = I0 + 12;
               short_no_newsb:
               r0 = M[I4,M0];
               M[I0,M2] = r0,
                r0 = M[I4,M0];
               M[I0,M2] = r0,
                r0 = M[I4,M1];
               M[I0,M3] = r0;

            short_inner_loop:

            M3 = -r2;
            r0 = M[I4, M3];            // dummy read
            r1 = r1 + 1;
            r3 = r3 - 1;
         if NZ jump short_loop;

      // Now copy back from genbuf to the ar_Buf
      r10 = 576;
#ifdef MP3_USE_EXTERNAL_MEMORY
      r0 = M[r9 + $mp3dec.mem.GENBUF_FIELD];
      I0 = r0;
#else
      I0 = &$mp3dec.genbuf;
#endif
      do copy_back;
         r0 = M[I0,1];
         M[I1,1] = r0;
      copy_back:

      reorder_done:
      r5 = r5 + 1;
      Null = r5 AND 1;
   if NZ jump chan_loop;

   L1 = 0;
   L4 = 0;
   rts;

.ENDMODULE;

#endif
