// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_INIT_DECODER_INCLUDED
#define MP3DEC_INIT_DECODER_INCLUDED

#include "stack.h"
#include "profiler.h"
#include "mp3_library.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.init_decoder
//
// DESCRIPTION:
//    Initialise the MP3 decoder
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
.MODULE $M.mp3dec.init_decoder;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $mp3dec.init_decoder:

   // push rLink onto stack
   $push_rLink_macro;

#ifdef MP3_USE_EXTERNAL_MEMORY
   // Set up the initial pointer positions to the start of buffer
   r0 = M[r9 + $mp3dec.mem.SYNTHV_LEFT_FIELD];
   M[$mp3dec.synthv_leftptr] = r0;
   r0 = M[r9 + $mp3dec.mem.SYNTHV_RIGHT_FIELD];
   M[$mp3dec.synthv_rightptr] = r0;

   r0 = M[r9 + $mp3dec.mem.BITRES_FIELD];
   M[$mp3dec.bitres_inptr] = r0;
   r0 = M[r9 + $mp3dec.mem.BITRES_FIELD];
   M[$mp3dec.bitres_outptr] = r0;
#endif

   // -- reset decoder variables --
   call $mp3dec.reset_decoder;

   // reset get_bitpos to point to the begging of a word
   r0 = 16;
   M[$mp3dec.get_bitpos] = r0;

   // set BOF flag with a non-zero value
   M[$mp3dec.beginning_of_file] = r0;

   // reset mp3 detection variables
   M[$mp3dec.frame_detect_counter] = Null;
   M[$mp3dec.consecutive_frames] = Null;
   M[$mp3dec.valid_mp3_file_detected] = Null;
   M[$mp3dec.frame_type] = Null;

   // initialise profiling and macros if enabled
   #ifdef ENABLE_PROFILER_MACROS

      #define PROFILER_START_MP3DEC(addr)  \
         r0 = addr;                        \
         call $profiler.start;
      #define PROFILER_STOP_MP3DEC(addr)   \
         r0 = addr;                        \
         call $profiler.stop;

      .VAR/DM1 $mp3dec.profile_frame_decode[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_read_frame_header[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_read_sideinfo[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_fillbitres[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_read_scalefactors[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_read_huffman[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_subband_reconstruction[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_jointstereo_processing[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_reorder_spectrum[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_alias_reduction[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_imdct_windowing_overlapadd[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_compensation_for_freq_inversion[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;
      .VAR/DM1 $mp3dec.profile_synthesis_filterbank[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED,
      0 ...;

   #else
      #define PROFILER_START_MP3DEC(addr)
      #define PROFILER_STOP_MP3DEC(addr)
   #endif

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif