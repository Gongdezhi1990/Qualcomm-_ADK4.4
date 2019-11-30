// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_RESET_DECODER_INCLUDED
#define MP3DEC_RESET_DECODER_INCLUDED

#include "stack.h"
#include "profiler.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.reset_decoder
//
// DESCRIPTION:
//    Reset the decoder
//
// INPUTS:
//    - r9 = pointer to table of external memory pointers
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r10, DoLoop, I0, I4
//
// *****************************************************************************
.MODULE $M.mp3dec.reset_decoder;
   .CODESEGMENT MP3DEC_RESET_DECODER_PM;
   .DATASEGMENT DM;

   $mp3dec.reset_decoder:

   // push rLink onto stack
   $push_rLink_macro;

   // clear the filter buffers
   call $mp3dec.silence_decoder;

   // set sampling rate index to -1 to imply start of new mp3 file
   r0 = -1;
   M[$mp3dec.sampling_freq] = r0;

   // reset get_bitpos to initial value of 16
   r0 = 16;
   M[$mp3dec.get_bitpos] = r0;

   // reset granule and channel count to 0
   M[$mp3dec.current_grch] = Null;

   // empty the bit reservoir
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.BITRES_FIELD];
#else
   r0 = &$mp3dec.bitres;
#endif

   M[$mp3dec.bitres_inptr] = r0;
   M[$mp3dec.bitres_outptr] = r0;

   r0 = 1<<23;
   M[$mp3dec.bitres_inbitmask] = r0;
   M[$mp3dec.bitres_outbitmask] = r0;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
