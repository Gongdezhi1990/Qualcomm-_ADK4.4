// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_CRC_CHECK_INCLUDED
#define MP3DEC_CRC_CHECK_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.crc_check
//
// DESCRIPTION:
//    CRC-Check
//
// INPUTS:
//    - r1 = data to do the CRC on
//    - r0 = number of bits of r1 to do the CRC on (max of 24)
//    - crc_checkword   - previous val (initialised to 0x00)
//
// OUTPUTS:
//    - r1 = unaffected
//    - r0 = unaffected
//    - crc_checkword = updated
//
// TRASHED REGISTERS:
//    r2, r3, r4 ,r5, r10, DoLoop
//
// *****************************************************************************
.MODULE $M.mp3dec.crc_check;
   .CODESEGMENT MP3DEC_CRC_CHECK_PM;
   .DATASEGMENT DM;

   $mp3dec.crc_check:

   r10 = r0;
   // get current crc_checkword
   r2 = M[$mp3dec.crc_checksum];

   // preset the generator polynomial
   r5 = $mp3dec.CRC_GENPOLY;

   r4 = 24 - r0;
   // r4 = shifted data so that 1st bit in MSB
   r4 = r1 LSHIFT r4;

   // crc calc 1 bit at a time
   do loop;
      r3 = r2 LSHIFT 1;
      r2 = r2 XOR r4;
      if NEG r3 = r3 XOR r5;
      r2 = r3;
      r4 = r4 LSHIFT 1;
   loop:

   // save updated crc_checkword
   M[$mp3dec.crc_checksum] = r2;
   rts;

.ENDMODULE;

#endif
