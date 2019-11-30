// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_MAIN_INCLUDED
#define MP3DEC_MAIN_INCLUDED

#include "stack.h"
#include "codec_library.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.main
//
// DESCRIPTION:
//    invoke codec functions
//
// INPUTS:
//    - r0 = requested function
//    - Other input arguments depends on requested function
//
// OUTPUTS:
//    - Depends on function called
//
// TRASHED REGISTERS:
//    Depends on function called
//
// *****************************************************************************
.MODULE $M.mp3dec.main;
   .CODESEGMENT MP3DEC_MAIN_PM;
   .DATASEGMENT DM;

   $mp3dec.main:

   // check functions
   Null = r0 - $codec.FRAME_DECODE;
   if Z jump $mp3dec.frame_decode;              // in: r5, out: none, trashed: all
   Null = r0 - $codec.INIT_DECODER;
   if Z jump $mp3dec.init_decoder;              // in: none, out: none, trashed: r0, r10, DoLoop, I0, I4
   Null = r0 - $codec.RESET_DECODER;
   if Z jump $mp3dec.reset_decoder;             // in: none, out: none, trashed: r0, r10, DoLoop, I0, I4
   Null = r0 - $codec.SILENCE_DECODER;
   if Z jump $mp3dec.silence_decoder;           // in: none, out: none, trashed: r0, r10, DoLoop, I0, I4
   Null = r0 - $codec.SUSPEND_DECODER;
   if Z jump $mp3dec.suspend_decoder;           // in: I0, out: r0, I0 trashed: none
   Null = r0 - $codec.RESUME_DECODER;
   if Z jump $mp3dec.resume_decoder;            // in: I0, out: I0, trashed: r0
   Null = r0 - $codec.STORE_BOUNDARY_SNAPSHOT;
   if Z jump $mp3dec.store_boundary_snapshot;   // in: I0, out: r0, I0 trashed: none
   Null = r0 - $codec.RESTORE_BOUNDARY_SNAPSHOT;
   if Z jump $mp3dec.restore_boundary_snapshot; // in: I0, out: I0 trashed: r0
   Null = r0 - $codec.FAST_SKIP;
   if Z jump $mp3dec.mp3_ff_rew;                // in: r1, r2, out: r4-6, trashed: all

   // accecc interfaces
   Null = r0 - $codec.SET_SKIP_FUNCTION;
   if NZ jump not_set_skip_function;
      // INPUTS:
      //    - r1 = skip function pointer
      // OUTPUTS:
      //    - none
      M[$mp3dec.skip_function] = r1;
      rts;
   not_set_skip_function:

   Null = r0 - $codec.SET_AVERAGE_BITRATE;
   if NZ jump not_set_average_bitrate;
      // INPUTS:
      //    - r1 = average bitrate
      // OUTPUTS:
      //    - none
      M[$mp3dec.avg_bitrate] = r1;
      rts;
   not_set_average_bitrate:

   // unknown command
   rts;


.ENDMODULE;

#endif