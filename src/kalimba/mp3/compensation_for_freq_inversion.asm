// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_COMPENSATION_FOR_FREQ_INVERSION_INCLUDED
#define MP3DEC_COMPENSATION_FOR_FREQ_INVERSION_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.compensation_for_freq_inversion
//
// DESCRIPTION:
//    Compensation for frequency inversion of filterbank
//
// INPUTS:
//    - r9 = pointer to table of external memory pointers
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r1, r2, r10, DoLoop, I2, I3
//
// NOTES:
//
//  If the time samples are labelled 0 through 17, with 0 being the earliest
//  time sample, and subbands are labeled 0 through 31, with 0 being the
//  lowest subband, then every odd time sample of every odd subband is
//  multiplied by -1 before processing by the polyphase filter bank.
//
// *****************************************************************************
.MODULE $M.mp3dec.compensation_for_freq_inversion;
   .CODESEGMENT MP3DEC_COMPENSATION_FOR_FREQ_INVERSION_PM;
   .DATASEGMENT DM;

   $mp3dec.compensation_for_freq_inversion:

   M0 = 2;
   // set ptr to 1st odd time sample of 1st old subband
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.GENBUF_FIELD];
   I3 = r0 + 19;
#else
   I3 = (&$mp3dec.genbuf + 19);
#endif
   I2 = I3;

   // 16 odd subbands to process
   r2 = 16;
   subband_loop:

      // 9*2=18 Time samples to do
      r10 = 9;
      r0 = M[I2,M0];
      do sample_loop;
         r1 = -r0,
          r0 = M[I2,M0];
         M[I3,M0] = r1;
      sample_loop:
      // move on to next subband
      I2 = I2 + 16;
      I3 = I3 + 18;
   r2 = r2 - 1;
   if NZ jump subband_loop;
   rts;

.ENDMODULE;

#endif
