// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_FF_REW_INCLUDED
#define MP3DEC_FF_REW_INCLUDED

#include "stack.h"
#include "codec_library.h"
#include "mp3.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.mp3_ff_rew
//
// DESCRIPTION:
//    Fast Forward/Rewind an mp3 using seek function
//
// INPUTS:
//    - r1 = fast_forward_remaining_samples_ls
//    - r2 = fast_forward_remaining_samples_ms
//
// OUTPUTS:
//    - r4 - Status of fast fwd/rwd (0 --> FAIL, 1 --> SUCCESS)
//    - r5 - LS value of output samples produced(valid in FF/FREW case)
//    - r6 - MS value of output samples produced(valid in FF/FREW case)
//
// TRASHED REGISTERS:
//    assume everything
//
// NOTES:
//
//
// *****************************************************************************
.MODULE $M.mp3dec.mp3_ff_rew;
   .CODESEGMENT MP3DEC_FF_REW_PM;
   .DATASEGMENT DM;

   .VAR          mp3_fast_forward_remaining_samples_ms;
   .VAR          mp3_fast_forward_remaining_samples_ls;


   $mp3dec.mp3_ff_rew:

   // push rLink onto stack
   $push_rLink_macro;

   r4 = 0;
   r6 = M[$mp3dec.skip_function];
   if Z jump $pop_rLink_and_rts;

   M[mp3_fast_forward_remaining_samples_ls] = r1;
   M[mp3_fast_forward_remaining_samples_ms] = r2;

   // Check if FF/REW is required
   M[$mp3dec.current_grch] = Null;

   // check if it is rewind
   Null = r2;
   if POS jump ff_not_negative;
      // absolute value of num output samples to ff/rew
      r1 = Null - r1;
      r2 = Null - r2 - Borrow;

   ff_not_negative:
      // Calculate number of frames to skip
      // Num frames to skip = Num samples / Samples per frame

      // rMAC = {r2,r1)
      rMAC = r1 LSHIFT 0 (LO);
      r3 = 0x800000;
      rMAC = rMAC + r2 * r3 (UU);

      // samples per frame
      r0 = $mp3dec.MAX_AUDIO_FRAME_SIZE_IN_WORDS*2;
      // Calculate number of frames to skip
      Div = rMAC/r0;

      // Caclulate average frame length
      rMAC = M[$mp3dec.avg_bitrate];
      r0 = M[$mp3dec.sampling_freq];
      r1 = M[$mp3dec.framelen_freqcoef + r0];
      rMAC = rMAC * r1;
      rMAC = rMAC LSHIFT 4;

      r0 = M[$mp3dec.framelength];
      Null = rMAC;
      if NZ r0 = rMAC; // use this when avg bit rate is available

      // Number of frames to be skipped
      r1 = DivResult;

      // Get number of bytes to skip
      rMAC = r1 * r0;

      r3 = rMAC LSHIFT 23;
      r4 = rMAC LSHIFT -1;

      // Seek must be negative in case of rewind
      r2 = M[mp3_fast_forward_remaining_samples_ms];
      if POS jump ff_pos_seek;
         r3 = Null - r3;
         r4 = Null - r4 - Borrow;

   ff_pos_seek:
      // set I0 to point to cbuffer for mp3 input stream
      r5 = M[$mp3dec.codec_struc];
      r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
      call $cbuffer.get_read_address_and_size;
      I0 = r0;
      call $mp3dec.skip_through_file;
   exit:

   L0 = 0; // L0 changed by skip function. reset it
   r4 = 1;
   r5 = M[mp3_fast_forward_remaining_samples_ls];
   r6 = M[mp3_fast_forward_remaining_samples_ms];
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
