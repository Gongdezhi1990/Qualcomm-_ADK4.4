// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_READ_HUFFMAN_INCLUDED
#define MP3DEC_READ_HUFFMAN_INCLUDED

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.read_huffman
//
// DESCRIPTION:
//    Read huffman data
//
// INPUTS:
//    - r9 = pointer to table of external memory pointers
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    rMAC, r0-r8, r10, DoLoop, I0-I3, M0, M1, M2, M3
//
// *****************************************************************************
.MODULE $M.mp3dec.read_huffman;
   .CODESEGMENT MP3DEC_READ_HUFFMAN_PM;
   .DATASEGMENT DM;

   $mp3dec.read_huffman:

   // region_size = [size, flag, size, flag, size, flag, size, flag]
   // size is the size of the region 0, 1, 2 or count1 and flag is zero if
   // abs(values) in that region are less than 32 and 1 otherwise. This is
   // later used in requantise
   .VAR $mp3dec.region_size[8];     // inter-module variable (non-persistent)


   // push rLink onto stack
   $push_rLink_macro;

   // read bitres out pointer and mask
   r0 = M[$mp3dec.bitres_outptr];
   I0 = r0;

#ifdef MP3_USE_EXTERNAL_MEMORY
   L0 = $mp3dec.mem.BITRES_LENGTH;
#else
   L0 = LENGTH($mp3dec.bitres);
#endif

   #ifdef BASE_REGISTER_MODE

      #ifdef MP3_USE_EXTERNAL_MEMORY
            r1 = M[r9 + $mp3dec.mem.BITRES_FIELD];
            push r1;
      #else
            push &$mp3dec.bitres;
      #endif

      pop B0;
   #endif
   r2 = M[$mp3dec.bitres_outbitmask];

   // read current word from bitres
   r1 = M[I0,1];

   // I1 = output buffer to use
#ifdef MP3_USE_EXTERNAL_MEMORY
   r4 = M[r9 + $mp3dec.mem.GENBUF_FIELD];
   I1 = r4;
#else
   I1 = &$mp3dec.genbuf;
#endif

   // set up some required constants
   M0 = 0;
   M1 = 1;
   r4 = M[$mp3dec.current_grch];
   rMAC = -12;
   I4 = &$mp3dec.region_size;

   // read the region size fields
   r5 = M[$mp3dec.big_valuesx2 + r4];
   M2 = r5;
   r6 = M[$mp3dec.region1_start + r4];
   r7 = M[$mp3dec.region2_start + r4];

   // I3 = pointer to huffman tables to use for region 0,1,2
   r4 = r4 * 3 (int);
   I3 = r4 + &$mp3dec.table_select;


   // -- Region 0 --
   // if big_valuesx2 < region1_start then
   //    region0_size = big_valuesx2
   // else
   //    region0_size = region1_start
   r8 = r6;
   Null = M2 - r6;
   if NEG r8 = M2;
   // loop through decoding region 0 values
   call $mp3dec.huff_getvalregion;



   // -- Region 1 --
   // if big_valuesx2 < region2_start then
   //    region1_size = big_valuesx2 - region1_start
   // else
   //    region1_size = region2_start - region1_start
   r8 = r7;
   Null = M2 - r7;
   if NEG r8 = M2;
   r8 = r8 - r6;
   // loop through decoding region 1 values
   call $mp3dec.huff_getvalregion;



   // -- Region 2 --
   // region2_size = big_valuesx2 - region2_start
   r8 = M2 - r7;
   // loop through decoding region 2 values
   call $mp3dec.huff_getvalregion;



   // -- Count 1 Region --
   // r8 = length of count1 + rzero
   r8 = 576 - M2;
   r0 = r8;
   M[I4, 0] = r0;

   // catch zero length count1 partition
   Null = r8 - 2;
   if LE jump count1region_end;

   // get huffman table to use
   r4 = M[$mp3dec.current_grch];

   // r7 = ending bitres_outptr value
   r7 = M[$mp3dec.bitres_outptr_p23end];

   r4 = M[$mp3dec.count1table_select + r4];

   r5 = 0;
   count1region_loop:
      r0 = I0 - r7;
      if NZ jump rzero_notyet;
         r5 = -1;
         Null = r2 - M[$mp3dec.bitres_outbitmask_p23end];
         if Z jump count1region_end;
         if NC jump bladeenc_fix;
      rzero_notyet:

      // check that we won't get to the end of the frame after decoding 1 more quadvalue
      Null = r8 - 4;
      if NEG jump count1region_end;

      // catch condition where quadval goes over to a new word
      Null = r0 AND r5;
      if NZ jump bladeenc_fix;
      call $mp3dec.huff_getvalquad;
      r8 = r8 - 4;
   jump count1region_loop;
   bladeenc_fix:
      // if we did over read past the part23 end then set the last quadruple to 0
      // this is required for bladeenc encoded files which effectively has a bug in
      // the setting of part23 end
      I1 = I1 - 4;
      r0 = 0;
      M[I1,1] = r0;
      M[I1,1] = r0;
      M[I1,1] = r0;
      M[I1,1] = r0;
      jump count1region_end;
   count1region_end:
   // store the rzero/count1 length
   r2 = M[$mp3dec.current_grch];
   r2 = r2 AND $mp3dec.CHANNEL_MASK;
   r0 = M[$mp3dec.rzerolength + r2];
   M[$mp3dec.rzerolength_previous + r2] = r0;
   M[$mp3dec.rzerolength + r2] = r8;
   r0 = 0,
    r2 = M[I4, 1];
   r2 = r2 - r8,  // = count1
    M[I4, -1] = r0;
   M[I4, 1] = r2;

   // set pointer and mask to part2_3 end
   r2 = M[$mp3dec.bitres_outptr_p23end];
   // ie. deals with remove/rewind of stuffing bits
   I0 = r2;
   r2 = M[$mp3dec.bitres_outbitmask_p23end];


   // -- rzero Region --
   // set rzero values to zero
   r10 = r8 ASHIFT -1;
   if LE jump all_done;
   r10 = r10 * 2 (int);
   do rzero_partition_loop;
      M[I1,1] = r0;
   rzero_partition_loop:


   all_done:
   // subtract 1 from I0 with ring buffer wrap around
   r0 = M[I0,-1];
   r0 = I0;
   // store bitres pointer and mask
   M[$mp3dec.bitres_outptr] = r0;
   M[$mp3dec.bitres_outbitmask] = r2;
   L0 = 0;
   #ifdef BASE_REGISTER_MODE
      push Null;
      pop B0;
   #endif

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $mp3dec.huff_getvalregion
//
// DESCRIPTION:
//    huffman - get pairs of encoded values and store them in the buffer pointed
//    to by I1. Works its way through an entire region.
//
// INPUTS:
//    - I0 = ^bitres        - current position
//    - I1 = ^genbuf        - current position
//    - r1 = current word read from bitres
//    - r2 = current mask to read a bit from bitres
//            (should be init to 32768)
//    - r4 = huffman table to use (0-31)
//    - r8 = region size (in samples)
//    - rMAC = -12;
//    - M0 = 0
//    - M1 = 1
//    - I4 = pointer to region_size
//
// OUTPUTS:
//    - I0 = ^bitres        - updated position
//    - I1 = ^genbuf        - updated position
//    - r1 = current word   - updated
//    - r2 = current mask   - updated
//    - r4 = huffman table  - unaffected
//
// TRASHED REGISTERS:
//    r0, r3, r10, M3, (NOT M2)
//
// *****************************************************************************
.MODULE $M.mp3dec.huff_getvalregion;
   .CODESEGMENT MP3DEC_HUFF_GETVALREGION_PM;
   .DATASEGMENT DM;

   $mp3dec.huff_getvalregion:

   // get huffman table to use and write to region_size vaector
   r0 = r8;
   r4 = M[I3,1],        // r4 = table index
    M[I4, 1] = r0;      // write region size

   // if r4 == 24 or r4 <= 19 next I4 element is 0, otherwise it's 1.
   r0 = 1;
   Null = r4 - 24;
   if EQ r0 = 0;
   Null = r4 - 19;
   if LE r0 = 0;
   M[I4, 1] = r0;

   // get number of pairs
   r8 = r8 ASHIFT -1;
   if LE rts;

   // I2 points to the hufftable to use
   r0 = M[$mp3dec.hufftable_lookup + r4];
   if Z jump table0_or_invalid;
   M3 = r0;
   I2 = M3;

   // if the current region doesn't use linbits, a faster
   // loop is implemented which doesn't check for ESC values
   // and makes use of zero-overhead-loops (r10)
   r5 = &code_ended_with_linbits;
   Null = M[$mp3dec.nolinbits + r4];
   if NZ jump region_loop;

   // set up fast loop
   r10 = r8;
   r5 = &code_ended_no_linbits;
   do fast_region_loop;

   region_loop:
      huff_loop:

         // mask out current bit from bitstream
         Null = r1 AND r2,
          r0 = M[I2,M0];       // read huffman node data

         // if bit=1 then take high 12bits of huffman node
         if NZ r0 = r0 LSHIFT rMAC;

         // form next bitmask
         r2 = r2 LSHIFT -1;
         if NZ jump no_new_word_needed;
            r2 = M1,
             r1 = M[I0,M1];    // get new word from bitres

            // set bitmask to 0x800000
            r2 = r2 LSHIFT 23;
         no_new_word_needed:

         // AND off the lower 12bits of huffman node
         r0 = r0 AND 0xFFF;

         // if bit 11 set then huffman code has ended
         r3 = r0 - 0x800;
         if POS jump r5;

         // move huffman pointer onto the next node in the binary tree
         I2 = I2 + r0;

      jump huff_loop;

      code_ended_with_linbits:

      // separate the 'x' value: r0 = x
      r0 = r3 AND 0xF;

      // if zero skip linbits and sign bit
      if Z jump x_no_signbit;

         // if 'x' = ESC then linbits present
         Null = r0 - $mp3dec.HUFF_ESC;
         if NZ jump no_linbits_forx;
            // find number of linbits to read
            r10 = M[$mp3dec.nolinbits + r4];
            r0 = 0;

            // read linbits from bitres
            do linbitsx_loop;
               // get one bit from bitres
               Null = r1 AND r2;
               if NZ r0 = r0 + M1;
               r2 = r2 LSHIFT -1;
               // see if new word from bitres needed
               if NZ jump linbitsx_no_new_word_needed;
                  r2 = M1,
                   r1 = M[I0,M1];     // get new word from bitres
                  r2 = r2 LSHIFT 23;
               linbitsx_no_new_word_needed:
               r0 = r0 LSHIFT 1;
            linbitsx_loop:

            // remove the last shift
            r0 = r0 LSHIFT -1;
            // add on 15 (the ESC code)
            r0 = r0 + 15;
         no_linbits_forx:


         // read sign bit
         // get one bit from bitres
         Null = r1 AND r2;
         // if '1' negate r0 = 'x'
         if NZ r0 = -r0;
         r2 = r2 LSHIFT -1;

         // see if new word from bitres needed
         if NZ jump xsignbit_no_new_word_needed;
            r2 = M1,
             r1 = M[I0,M1];      // get new word from bitres
            r2 = r2 LSHIFT 23;
         xsignbit_no_new_word_needed:

      x_no_signbit:

      I2 = M3,          // reload huffman table
       M[I1,M1] = r0;   // store x

      // separate the 'y' value: r0 = y
      r0 = r3 LSHIFT -4;

      // if zero skip linbits and sign bit
      if Z jump y_no_signbit;

         // if 'y' = ESC then linbits present
         Null = r0 - $mp3dec.HUFF_ESC;
         if NZ jump no_linbits_fory;
            // find number of linbits to read
            r10 = M[$mp3dec.nolinbits + r4];
            r0 = 0;

            // read linbits from bitres
            do linbitsy_loop;
               // get one bit from bitres
               Null = r1 AND r2;
               if NZ r0 = r0 + M1;
               r2 = r2 LSHIFT -1;
               // see if new word from bitres needed
               if NZ jump linbitsy_no_new_word_needed;
                  r2 = M1,
                   r1 = M[I0,M1];   // get new word from bitres
                  r2 = r2 LSHIFT 23;
               linbitsy_no_new_word_needed:
               r0 = r0 LSHIFT 1;
            linbitsy_loop:

            // remove the last shift
            r0 = r0 LSHIFT -1;
            // add on 15 (the ESC code)
            r0 = r0 + 15;
         no_linbits_fory:

         // read sign bit
         // get one bit from bitres
         Null = r1 AND r2;
         // if '1' negate r0 = 'y'
         if NZ r0 = -r0;
         r2 = r2 LSHIFT -1;

         // see if new word from bitres needed
         if NZ jump ysignbit_no_new_word_needed;
            r2 = M1,
             r1 = M[I0,M1];          // get new word from bitres
            r2 = r2 LSHIFT 23;
         ysignbit_no_new_word_needed:

      y_no_signbit:

      r8 = r8 - M1,
       M[I1,1] = r0; // store y
   if NZ jump region_loop;
   rts;

      code_ended_no_linbits:
      // separate the 'x' value: r0 = x
      r0 = r3 AND 0xF;

      // if zero skip sign bit
      if Z jump x_no_signbit_nlb;

         // read sign bit
         // get one bit from bitres
         Null = r1 AND r2;
         // if '1' negate r0 = 'x'
         if NZ r0 = -r0;
         r2 = r2 LSHIFT -1;

         // see if new word from bitres needed
         if NZ jump xsignbit_no_new_word_needed_nlb;
            r2 = M1,
             r1 = M[I0,M1];      // get new word from bitres
            r2 = r2 LSHIFT 23;
         xsignbit_no_new_word_needed_nlb:

      x_no_signbit_nlb:

      // store x
      M[I1,1] = r0;

      // separate the 'y' value: r0 = y
      r0 = r3 LSHIFT -4;

      // if zero skip sign bit
      if Z jump y_no_signbit_nlb;

         // read sign bit
         // get one bit from bitres
         Null = r1 AND r2;
         // if '1' negate r0 = 'y'
         if NZ r0 = -r0;
         r2 = r2 LSHIFT -1;

         // see if new word from bitres needed
         if NZ jump ysignbit_no_new_word_needed_nlb;
            r2 = M1,
             r1 = M[I0,M1];          // get new word from bitres
            r2 = r2 LSHIFT 23;
         ysignbit_no_new_word_needed_nlb:

      y_no_signbit_nlb:

      I2 = M3,       // reload huffman table
       M[I1, M1] = r0; // store y

   fast_region_loop: // end of fast do loop
   rts;

   // if table 0 or an invalid table then x=y=0
   table0_or_invalid:
      r10 = r8 * 2 (int);
      do zero_loop;
         M[I1,1] = r0;
      zero_loop:
   rts;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $mp3dec.huff_getvalquad
//
// DESCRIPTION:
//    huffman - get quadruples of encoded values and store them in the buffer
//    pointed to by I1
//
// INPUTS:
//    - I0 = ^bitres        - current position
//    - I1 = ^genbuf        - current position
//    - r1 = current word read from bitres
//    - r2 = current mask to read a bit from bitres
//            (should be init to 32768)
//    - r4 = huffman table to use (0=tableA, 1=tableB)
//    - rMAC = -12;
//    - M0 = 0
//    - M1 = 1
//
// OUTPUTS:
//    - I0 = ^bitres        - updated position
//    - I1 = ^genbuf        - updated position
//    - r1 = current word   - updated
//    - r2 = current mask   - updated
//
// TRASHED REGISTERS:
//    r0, r3, r10, DoLoop
//
// *****************************************************************************
.MODULE $M.mp3dec.huff_getvalquad;
   .CODESEGMENT MP3DEC_HUFF_GETVALQUAD_PM;
   .DATASEGMENT DM;

   $mp3dec.huff_getvalquad:

   // I2 points to the hufftable to use
   r0 = M[r4 + ($mp3dec.hufftable_lookup + 32)];
   I2 = r0;

   huff_loop:

      // mask out current bit from bitstream
      Null = r1 AND r2,
       r0 = M[I2,M0];       // read huffman node data

      // if bit=1 then take high 12bits of huffman node
      if NZ r0 = r0 LSHIFT rMAC;

      // form next bitmask
      r2 = r2 LSHIFT -1;
      if NZ jump no_new_word_needed;
         r2 = M1,
          r1 = M[I0,M1];          // get new word from bitres

         // set bitmask to 0x800000
         r2 = r2 LSHIFT 23;
      no_new_word_needed:

      // AND off the lower 12bits of huffman node
      r0 = r0 AND 0xFFF;

      // if bit 11 set then huffman code has ended
      r3 = r0 - 0x800;
      if POS jump code_ended;

      // move huffman pointer onto the next node in the binary tree
      I2 = I2 + r0;

   jump huff_loop;

   code_ended:

   // separate the 4 bits (p, q, r, s)
   r10 = 4;
   do sign_bit_loop;
      r0 = r3 AND 1;

      // see if a sign bit is required
      if Z jump no_sign_bit;
         // get one bit from bitres
         Null = r1 AND r2;
         // if '1' negate
         if NZ r0 = -r0;
         r2 = r2 LSHIFT -1;
         // see if new word from bitres needed
         if NZ jump sign_bit_dont_get_new_word;
            r2 = M1,
             r1 = M[I0,M1];             // get new word from bitres
            r2 = r2 LSHIFT 23;
         sign_bit_dont_get_new_word:

      no_sign_bit:
      // store the current bit
      M[I1,1] = r0;
      // shift into next bit
      r3 = r3 LSHIFT -1;

   sign_bit_loop:
   rts;

.ENDMODULE;

#endif
