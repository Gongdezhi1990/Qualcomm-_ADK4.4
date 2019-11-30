// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_GETBITRESBITS_INCLUDED
#define MP3DEC_GETBITRESBITS_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.getbitresbits
//
// DESCRIPTION:
//    Get bits from bitres
//
// INPUTS:
//    - I0 = bitres pointer    - current position (of new data)
//    - r1 = current word read from bitres
//    - r2 = current mask to read a bit from bitres
//    - r10 = number of bits to read
//    - r5 = 1 << 23;
//
// OUTPUTS:
//    - I0 = bitres pointer    - updated
//    - r0 = data read
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************
.MODULE $M.mp3dec.getbitresbits;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $mp3dec.getbitresbits:

   r0 = 0;
   do loop;
      Null = r1 AND r2;               // get one bit from bitres
      if NZ r0 = r0 + M0;
      r2 = r2 LSHIFT -1;              // see if new word from bitres needed
      if NZ jump no_new_word_needed;
        r2 = r5,
          r1 = M[I0,M0];              // get new word from bitres
     no_new_word_needed:
      r0 = r0 LSHIFT 1;
   loop:
   r0 = r0 LSHIFT -1;
   rts;

.ENDMODULE;

#endif