// *****************************************************************************
// Copyright (c) 2007 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef SBC_API_INCLUDED
#define SBC_API_INCLUDED


.MODULE $M.mp3.get_sampling_frequency;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
    $mp3.get_sampling_frequency:
     .VAR sampling_freq_hz[10] = 44100, 48000, 32000, 22050, 24000, 16000, 11025, 12000, 8000, 0;
     r1 = 9;
     r0 = M[$mp3dec.sampling_freq];
     if NEG r0 = r1;
     Null = r0 - r1;
     if POS r0 = r1;
     r0 = M[r0 + sampling_freq_hz];
      rts;
.ENDMODULE;
#endif