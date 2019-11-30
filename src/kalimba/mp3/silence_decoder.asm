// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_SILENCE_DECODER_INCLUDED
#define MP3DEC_SILENCE_DECODER_INCLUDED

#include "stack.h"
#include "profiler.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.silence_decoder
//
// DESCRIPTION:
//    Silence the decoder - clears any buffers so that no pops and squeeks upon
//    re-enabling output audio
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
.MODULE $M.mp3dec.silence_decoder;
   .CODESEGMENT MP3DEC_SILENCE_DECODER_PM;
   .DATASEGMENT DM;

   $mp3dec.silence_decoder:

   // clear OA buffers
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.OABUF_LEFT_FIELD];
   I0 = r0;
   r0 = M[r9 + $mp3dec.mem.OABUF_RIGHT_FIELD];
   I4 = r0;
#else
   I0 = &$mp3dec.oabuf_left;
   I4 = &$mp3dec.oabuf_right;
#endif
   r10 = 576;
   r0 = 0;
   do oa_clear_loop;
      M[I0,1] = r0,
       M[I4,1] = r0;
   oa_clear_loop:

   // clear synthv arrays
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.SYNTHV_LEFT_FIELD];
   I0 = r0;
   r0 = M[r9 + $mp3dec.mem.SYNTHV_RIGHT_FIELD];
   I4 = r0;
#else
   I0 = &$mp3dec.synthv_left;
   I4 = &$mp3dec.synthv_right;
#endif
   r10 = 1024;
   r0 = 0;
   do SynthV_clear_loop;
      M[I0,1] = r0,
       M[I4,1] = r0;
   SynthV_clear_loop:

   rts;

.ENDMODULE;

#endif
