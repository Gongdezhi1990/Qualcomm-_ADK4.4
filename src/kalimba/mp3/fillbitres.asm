// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_FILLBITRES_INCLUDED
#define MP3DEC_FILLBITRES_INCLUDED

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.fillbitres
//
// DESCRIPTION:
//    Fill Bit Reservoir
//
// INPUTS:
//    - r9 = pointer to table of external memory pointers
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    r0-r6, I1, I2
//
// *****************************************************************************
.MODULE $M.mp3dec.fillbitres;
   .CODESEGMENT MP3DEC_FILLBITRES_PM;
   .DATASEGMENT DM;

   $mp3dec.fillbitres:

   // push rLink onto stack
   $push_rLink_macro;


   // read current bit reservoir Out bit position mask
   // and round down to next whole byte read
   // ie. 10000000_00000000_00000000  -> 0
   // ie. 01000000_00000000_00000000  -> -1
   // ie. 00100000_00000000_00000000  -> -1
   // ie. 00000001_00000000_00000000  -> -1
   // ie. 00000000_10000000_00000000  -> -1
   // ie. 00000000_01000000_00000000  -> -2
   // ie. 00000000_00000000_10000000  -> -2
   // ie. 00000000_01000000_01000000  -> -3
   // r0 = 0 (MS byte), -1 (Mid byte), -2 (LS byte), -3 (none)
   r0 = 0;
   r2 = M[$mp3dec.bitres_outbitmask];
   if NEG jump outbitmask_MSbyte;
      r2 = SIGNDET r2;
      r2 = r2 LSHIFT -3;
      r2 = r2 + 1;
      r0 = -r2;
   outbitmask_MSbyte:


   // read current bit reservoir In bit position mask
   // r1 = 0 (MS byte), 1 (Mid byte), 2 (LS byte)
   r1 = 1;
   r2 = M[$mp3dec.bitres_inbitmask];
   if NEG r1 = 0 ;
   Null = r2 - 128;
   if Z r1 = r1 + r1;


   // now calculate the number of bytes in the bit reservoir
   // ((inptr - outptr) mod size)*3  + r1 - r0
#ifdef MP3_USE_EXTERNAL_MEMORY
   r3 = $mp3dec.mem.BITRES_LENGTH;
#else
   r3 = LENGTH($mp3dec.bitres);
#endif
   r2 = M[$mp3dec.bitres_inptr];
   r2 = r2 - M[$mp3dec.bitres_outptr];
   if NEG r2 = r2 + r3;
   r2 = r2 * 3 (int);
   r2 = r2 + r1;
   M[$mp3dec.bitres_numbytes] = r2 - r0;


   // read bitres In and Out pointers
   r0 = M[$mp3dec.bitres_inptr];
   I1 = r0;
   #ifdef BASE_REGISTER_MODE

      #ifdef MP3_USE_EXTERNAL_MEMORY
            r0 = M[r9 + $mp3dec.mem.BITRES_FIELD];
            push r0;
      #else
            push $mp3dec.bitres;
      #endif

      pop B1;
   #endif
#ifdef MP3_USE_EXTERNAL_MEMORY
   L1 = $mp3dec.mem.BITRES_LENGTH;
#else
   L1 = LENGTH($mp3dec.bitres);
#endif


   // if (bitres_numbytes >= main_data_begin)
   // then set the outbitmask/outptr to be
   // main_data_begin bytes before the inbitmask/inptr
   r0 = M[$mp3dec.bitres_numbytes];
   Null = r0 - M[$mp3dec.main_data_begin];
   if POS jump update_inptr;

      // if there isn't enough data in the bit reservoir then we still want
      // to fill up the bit reservoir but not decode this frame.  So we set
      // the frame_corrupt flag so that no more decoding of this frame will
      // occur
      r0 = 1;
      M[$mp3dec.frame_corrupt] = r0;
      .VAR $mp3dec.filling_bitres =0;  
      M[$mp3dec.filling_bitres] = r0;

      // set I2 = out_ptr
      r0 = M[$mp3dec.bitres_outptr];
      I2 = r0;
      jump update_inptr_done;

   update_inptr:

   // translate current In bit position mask to the following:
   // r0 = -2 (MS byte), -1 (Mid byte), 0 (LS byte)
   r0 = r1 - 2;

   // use main_data_begin to update outptr
   r0 = r0 - M[$mp3dec.main_data_begin];
   r3 = r0 + 1;
   // r3 = -floor(r3 / 3)  (0xD55500 ~= -1/3)
   r3 = r3 * 0xD55500 (frac);
   M1 = -r3;
   // dummy read to decrement I1
   r1 = M[I1,M1];
   r1 = I1;
   M[$mp3dec.bitres_outptr] = r1;
   I2 = r1;
   M1 = -M1;
   // dummy read to increment I1
   r1 = M[I1,M1];

   // and also use main_data_begin to update outbitmask
   r3 = r3 * 3 (int);
   // r3 = rem (-r0 / 3)
   r3 = r0 + r3;
   r3 = r3 * -8 (int);
   r3 = r3 + 7;
   r0 = 1 LSHIFT r3;
   M[$mp3dec.bitres_outbitmask] = r0;

   update_inptr_done:


   // copy across framelength bytes to the bitreservoir
   r4 = M[$mp3dec.framelength];
   r3 = M[$mp3dec.framebitsread];
   // convert to bytes read
   r3 = r3 LSHIFT -3;
   r4 = r4 - r3;


   // set to read bytes from mp3 stream
   r0 = 8;
   r1 = M[$mp3dec.bitres_inbitmask];
   if NEG jump first_full_word_to_copy;

      r5 = M[I1,0];
      Null = r1 AND 32768;
      if Z jump no_middle_byte_needed;

         // get byte from mp3 stream and
         // write to middle byte of bit reservoir.
         call $mp3dec.getbits;
         r1 = r1 LSHIFT 8;
         r5 = r5 OR r1;
         r4 = r4 - 1;

      no_middle_byte_needed:

      // get byte from mp3 stream and
      // write to ls byte of bit reservoir.
      call $mp3dec.getbits;
      r5 = r5 OR r1;
      r4 = r4 - 1;
      M[I1,1] = r5;

   first_full_word_to_copy:

   // check there is enough space in bit reservoir, if not then indicate
   // corrupt_file_error but carry on as normal filling the bit reservoir
   r1 = I1 - I2;
   if LT r1 = r1 + L1;  // r1 = amount of data
   r1 = L1 - r1;
   r1 = r1 - 1;
   r1 = r1 * 3 (int);   // r1 = amount of space (bytes)
   Null = r1 - r4;
   if GE jump enough_space;
      r1 = 1;
      M[$mp3dec.frame_corrupt] = r1;
   enough_space:


   // word align input bitstream
   r5 = 16;
   r1 = M[$mp3dec.get_bitpos];
   if Z jump read_next_word;
      Null = r1 - 8;
      if NE jump ready_to_go;
         r2 = M[I0, 1];
         r2 = r2 LSHIFT r5,
          r1 = M[I0, 0];
         r1 = r1 AND 0xFFFF;
         r2 = r2 OR r1;
         M[I1, 1] = r2;
         r4 = r4 - 3;
         r1 = M[$mp3dec.framebitsread];
         r1 = r1 + 24;
         M[$mp3dec.framebitsread] = r1;

   read_next_word:
      r1 = M[I0, 1]; // move to the next word
   ready_to_go:

   // input bitstream is word-aligned
   r1 = 16;
   M[$mp3dec.get_bitpos] = r1;

   // calculate number of 6-byte words
   r10 = r4 * 0.66665649414063 (frac);
   r10 = r10 ASHIFT -2;
   r1 = r10 * 6 (int);
   r4 = r4 - r1; // r4 = remaining bytes

   // update framebitsread assuming reading the remaining data
   // (incl. above word alignment but excl. remaining bytes)
   r3 = M[$mp3dec.framebitsread];
   r1 = r10 * 48 (int);
   M[$mp3dec.framebitsread] = r3 + r1;

   // now loop to copy rest of frame in words: 3 x 16 bit = 2 x 24 bit
   do copy_loop;
        r1 = M[I0, 1];
      r1 = r1 LSHIFT r0,
       r3 = M[I0, 1];
      r3 = r3 AND 0xFFFF;
      r2 = r3 LSHIFT -8;
      r1 = r1 OR r2;

      r3 = r3 LSHIFT r5,
       r2 = M[I0, 1];
      r2 = r2 AND 0xFFFF;
      r2 = r2 OR r3,
       M[I1, 1] = r1;      // write 24-bit word 1
      M[I1, 1] = r2;       // write 24-bit word 2
   copy_loop:

   r10 = r4;
   r4 = 24;
   r5 = 0;
   do remaining_bytes;
      // get byte
      call $mp3dec.getbits;
      r4 = r4 - 8;
      if NZ jump not_last;
         // 24-bit completed: write it and move on!
         r5 = r5 OR r1;
         r5 = 0,
          M[I1, 1] = r5;
         r4 = 24;
      jump next_byte;
      not_last:
      r1 = r1 LSHIFT r4;
      r5 = r5 OR r1;
      next_byte:
      nop;
   remaining_bytes:


   // store new In bit position mask
   r6 = 1;
   r4 = r4 - r6,
    M[I1,0] = r5;

   r6 = r6 LSHIFT r4;
   M[$mp3dec.bitres_inbitmask] = r6;
   r0 = I1;
   // store new In pointer
   M[$mp3dec.bitres_inptr] = r0;
   L1 = 0;
   #ifdef BASE_REGISTER_MODE
      push Null;
      pop B1;
   #endif
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
