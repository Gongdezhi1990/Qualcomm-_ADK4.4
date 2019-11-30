// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_GETBITS_INCLUDED
#define MP3DEC_GETBITS_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.getbits
//
// DESCRIPTION:
//    Get bits from MP3 Stream, jumps to crc check if USERDEF enabled
//    Make sure that USERDEF flag is off if you just want to get the bits
//
// INPUTS:
//    - r0 = number of bits to get from buffer
//    - I0 = buffer pointer to read words from
//    - $get_bitpos = previous val (should be initialised to 16)
//    - framebitsread = number of bits read for this frame
//
// OUTPUTS:
//    - r0 = unaffected
//    - r1 = the data read from the buffer
//    - I0 = buffer pointer to read words from (updated)
//    - $get_bitpos   = updated
//    - framebitsread = updated
//
// TRASHED REGISTERS:
//    r2, r3
//
// *****************************************************************************
.MODULE $M.mp3dec.getbits;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $mp3dec.getbits:
   $mp3dec.getbits_and_calc_crc:

   r3 = M[$mp3dec.framebitsread];
   M[$mp3dec.framebitsread] = r3 + r0;  // update number of frame bits read
   r3 = M[$mp3dec.bitmask_lookup + r0]; // form a bit mask (r3)
   r2 = r0 - M[$mp3dec.get_bitpos];     // r2 = shift amount
   r1 = M[I0, 0];                       // r1 = the current word
   r1 = r1 LSHIFT r2;                   // shift current word
   r1 = r1 AND r3;                      // extract only the desired bits
   Null = r2 - 0;
   if   LE jump one_word_only;          //check if we need to read the next word
   r3 = M[I0,1];                        // increment I0 to point to the next word
   r3 = M[I0,0];                        // get another word from buffer (r3)
   r2 = r2 - 16;                        // calc new shift amount
   r3 = r3 LSHIFT r2;                   // and shift
   r1 = r1 + r3;                        // combine the 2 parts
one_word_only:
   M[$mp3dec.get_bitpos] = Null - r2;   // update get_bitpos
   if USERDEF jump $mp3dec.crc_check;   // if USERDEF is enabled, do a crc check as well
   rts;


.ENDMODULE;

#endif