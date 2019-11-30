// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_FRAME_DECODE_INCLUDED
#define MP3DEC_FRAME_DECODE_INCLUDED

#include "mp3_library.h"
#include "stack.h"
#include "codec_library.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.frame_decode
//
// DESCRIPTION:
//    Decode an MP3 frame
//
// INPUTS:
//    - r9 = pointer to table of external memory pointers
//    - r5 = pointer to a $codec.DECODER_STRUC structure
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    assume everything
//
// NOTES:
//    To support mono, stereo, and dual mono decoding the operation of the
//    routine is as follows:
//
//    @verbatim
//    channels | left_buf | right_buf
//     in file |          |
//    ---------|----------|-----------
//        1    | enabled  | disabled    - Mono decoding to left
//        1    | disabled | enabled     - Not supported
//        1    | enabled  | enabled     - Mono decoding to both left and right
//        2    | enabled  | enabled     - Standard stereo decoding
//        2    | enabled  | disabled    - Stereo decoding but with just left
//        2    | disabled | enabled     - Stereo decoding but with just right
//    @endverbatim
//
//
// *****************************************************************************
.MODULE $M.mp3dec.frame_decode;
   .CODESEGMENT MP3DEC_FRAME_DECODE_PM;
   .DATASEGMENT DM;

   $mp3dec.frame_decode:

   // push rLink onto stack
   $push_rLink_macro;

   // -- Start overall profiling if enabled --
   PROFILER_START(&$mp3dec.profile_frame_decode)

   // -- Save $codec.DECODER_STRUC pointer --
   M[$mp3dec.codec_struc] = r5;

   // -- Set initial buffer pointers --
   // If a channel is not available, use its "synth" buffer as scratch
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = $mp3dec.mem.SYNTHV_RIGHT_LENGTH;
#else
   r0 = LENGTH($mp3dec.synthv_right);
#endif
   M[$mp3dec.arbuf_right_size] = r0;
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.SYNTHV_RIGHT_FIELD];
#else
   r0 = &$mp3dec.synthv_right;
#endif
   M[$mp3dec.arbuf_right_pointer] = r0;
   #ifdef BASE_REGISTER_MODE
      M[$mp3dec.arbuf_start_right] = r0;
   #endif

#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = $mp3dec.mem.SYNTHV_LEFT_LENGTH;
#else
   r0 = LENGTH($mp3dec.synthv_left);
#endif
   M[$mp3dec.arbuf_left_size] = r0;
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.SYNTHV_LEFT_FIELD];
#else
   r0 = &$mp3dec.synthv_left;
#endif
   M[$mp3dec.arbuf_left_pointer] = r0;
   #ifdef BASE_REGISTER_MODE
      M[$mp3dec.arbuf_start_left] = r0;
   #endif

   // clear frame corrupt flag
   M[$mp3dec.frame_corrupt] = 0;
   M[$mp3dec.filling_bitres] = 0;

   // -- Check that we have enough output audio space --
   // only if not GOBBLING though
   r0 = M[r5 + $codec.DECODER_MODE_FIELD];
   Null = r0 - $codec.GOBBLE_DECODE;
   if Z jump no_output_check_needed;

      // -- Check that we have enough output audio space --
      // -- Also store buffer  size and  write  pointers --
      // r4 = number of available output buffers
      r4 = 0;
      r0 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
      if Z jump output_check_no_left_channel;
         call $cbuffer.calc_amount_space;
         Null = r0 - $mp3dec.MAX_AUDIO_FRAME_SIZE_IN_WORDS;
         if NEG jump exit_not_enough_output_space;
         r0 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
         #ifdef BASE_REGISTER_MODE
            call $cbuffer.get_write_address_and_size_and_start_address;
            M[$mp3dec.arbuf_left_pointer] = r0;
            M[$mp3dec.arbuf_left_size] = r1;
            M[$mp3dec.arbuf_start_left] = r2;
         #else
         call $cbuffer.get_write_address_and_size;
         M[$mp3dec.arbuf_left_pointer] = r0;
         M[$mp3dec.arbuf_left_size] = r1;
         #endif
         r4 = r4 + 1;
      output_check_no_left_channel:
      r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
      if Z jump output_check_no_right_channel;
         call $cbuffer.calc_amount_space;
         Null = r0 - $mp3dec.MAX_AUDIO_FRAME_SIZE_IN_WORDS;
         if NEG jump exit_not_enough_output_space;
         r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
         #ifdef BASE_REGISTER_MODE
            call $cbuffer.get_write_address_and_size_and_start_address;
            M[$mp3dec.arbuf_right_pointer] = r0;
            M[$mp3dec.arbuf_right_size] = r1;
            M[$mp3dec.arbuf_start_right] = r2;
         #else
         call $cbuffer.get_write_address_and_size;
         M[$mp3dec.arbuf_right_pointer] = r0;
         M[$mp3dec.arbuf_right_size] = r1;
         #endif
         r4 = r4 + 1;
      output_check_no_right_channel:
      // check that at least 1 channel's output buffer is available otherwise
      // exit with not_enough_output_space flagged
      Null = r4;
      if Z jump exit_not_enough_output_space;
   no_output_check_needed:

   reattempt_decode:

   Null = M[$mp3dec.current_grch];
   if NZ jump decode_granule;

   // -- Setup MP3 input stream buffer info --
   // set I0 to point to cbuffer for mp3 input stream
   r5 = M[$mp3dec.codec_struc];
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   #ifdef BASE_REGISTER_MODE
      call $cbuffer.get_read_address_and_size_and_start_address;
      I0 = r0;   L0 = r1;
      push r2;
      pop B0;
   #else
   call $cbuffer.get_read_address_and_size;
   I0 = r0;   L0 = r1;
   #endif

   // Call Bin Header

   null = M[$mp3dec.filling_bitres];
   if Z jump no_bin;
   r0 = M[r5 + $codec.TWS_CALLBACK_FIELD];
   if NZ call r0;
   M[$mp3dec.filling_bitres] = 0;
  no_bin:
   // -- Store number of bytes of data available in the MP3 stream --
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   call $cbuffer.calc_amount_data;
   r0 = r0 + r0;
   // adjust by the number of bits we've currently read
   r1 = M[$mp3dec.get_bitpos];
   r1 = r1 ASHIFT -3;
   r0 = r0 + r1;
   r0 = r0 - 2;
   if NEG r0 = 0;
   M[$mp3dec.num_bytes_available] = r0;
   Null = r0 - $mp3dec.MIN_MP3_FRAME_SIZE_IN_BYTES;
   if POS jump no_buffer_underflow;
      buffer_underflow:
      // indicate that not enough input data
      r5 = M[$mp3dec.codec_struc];
      r0 = $codec.NOT_ENOUGH_INPUT_DATA;
      M[r5 + $codec.DECODER_MODE_FIELD] = r0;
      // store updated cbuffer pointers for mp3 input stream
      r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
      r1 = I0;
      call $cbuffer.set_read_address;
      L0 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         pop B0;
      #endif
      jump exit;
   no_buffer_underflow:

   // -- Read mp3 header --
   PROFILER_START(&$mp3dec.profile_read_frame_header)
   call $mp3dec.read_header;
   PROFILER_STOP(&$mp3dec.profile_read_frame_header)

   // if corruption in file then deal with it cleanly
   Null = M[$mp3dec.frame_corrupt];
   if NZ jump crc_fail_or_corrupt;

   // if buffer underflow will occur then exit here
   Null = M[$mp3dec.frame_underflow];
   if NZ jump buffer_underflow;

   // -- Read side information --
   PROFILER_START(&$mp3dec.profile_read_sideinfo)
   call $mp3dec.read_sideinfo;
   PROFILER_STOP(&$mp3dec.profile_read_sideinfo)

   // crc calculation done, reset the flag
   rFlags = rFlags AND $NOT_UD_FLAG;
   
   // if corruption in file then deal with it cleanly
   Null = M[$mp3dec.frame_corrupt];
   if NZ jump crc_fail_or_corrupt;


   // -- Check CRC --
   r0 = M[$mp3dec.frame_crc];
   r0 = r0 - M[$mp3dec.crc_checksum];
   r0 = r0 AND 0xffff;
   if Z jump crc_correct;

      crc_fail_or_corrupt:
      // check for rfc3119
      Null = M[$mp3dec.rfc3119_enable];
      if NZ jump crc_fail_or_corrupt_dont_empty_bitres;

         // empty the bit reservoir
         r0 = M[$mp3dec.bitres_outbitmask];
         M[$mp3dec.bitres_inbitmask] = r0;

         r0 = M[$mp3dec.bitres_outptr];
         M[$mp3dec.bitres_inptr] = r0;

      crc_fail_or_corrupt_dont_empty_bitres:
      #ifdef DEBUG_MP3DEC
         r0 = M[$mp3dec.frame_corrupt_errors];
         r0 = r0 + 1;
         M[$mp3dec.frame_corrupt_errors] = r0;
      #endif

      // -- Save back MP3 input stream buffer info --
      // store updated cbuffer pointers for sbc input stream
      // this will mean that next time we'll look after the crc_fail/corruption
      // and hopefully find a good frame
      r5 = M[$mp3dec.codec_struc];
      r1 = I0;
      r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
      call $cbuffer.set_read_address;
      L0 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         pop B0;
      #endif

      // set sampling rate index to -1 so that we re-read it in the next mp3 frame
      r0 = -1;
      M[$mp3dec.sampling_freq] = r0;
      call $mp3dec.silence_decoder;
      jump reattempt_decode;
   crc_correct:


   // -- Fill up bit reservoir --
   PROFILER_START(&$mp3dec.profile_fillbitres)
   call $mp3dec.fillbitres;
   PROFILER_STOP(&$mp3dec.profile_fillbitres)

   // if corruption in file then deal with it cleanly
   Null = M[$mp3dec.frame_corrupt];
   if NZ jump crc_fail_or_corrupt_dont_empty_bitres;

   // -- Save back MP3 input stream buffer info --
   // store updated cbuffer pointers for mp3 input stream
   r5 = M[$mp3dec.codec_struc];
   r1 = I0;
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   call $cbuffer.set_read_address;
   L0 = 0;
   #ifdef BASE_REGISTER_MODE
      push Null;
      pop B0;
   #endif


   // -- Decode a granule (1/2 a frame) --
   decode_granule:

   // -- Skip further decoding if just doing a dummy frame read --
   r0 = M[r5 + $codec.DECODER_MODE_FIELD];
   Null = r0 - $codec.NORMAL_DECODE;
   if NZ jump dummy_decode_tidyup;

   mainchannel_loop:

      // -- Read from the bit reservoir the scalefactor information --
      PROFILER_START(&$mp3dec.profile_read_scalefactors)
      call $mp3dec.read_scalefactors;
      PROFILER_STOP(&$mp3dec.profile_read_scalefactors)

      // -- Read from the bit reservoir the huffman data --
      PROFILER_START(&$mp3dec.profile_read_huffman)
      call $mp3dec.read_huffman;
      PROFILER_STOP(&$mp3dec.profile_read_huffman)

      // -- Reconstruct the subband samples --
      PROFILER_START(&$mp3dec.profile_subband_reconstruction)
      call $mp3dec.subband_reconstruction;
      PROFILER_STOP(&$mp3dec.profile_subband_reconstruction)


      // if mono then get out of channel loop
      r0 = M[$mp3dec.mode];
      Null = r0 - $mp3dec.SINGLE_CHANNEL;
      if Z jump mono_decode;

      // see if all channels have been decoded
      r0 = M[$mp3dec.current_grch];
      Null = r0 AND $mp3dec.CHANNEL_MASK;
      if NZ jump stereo_decode;
      r0 = r0 OR $mp3dec.CHANNEL_MASK;
      M[$mp3dec.current_grch] = r0;
   jump mainchannel_loop;

   stereo_decode:
      // -- Perform middle/side and intensity stereo decoding --
      PROFILER_START(&$mp3dec.profile_jointstereo_processing)
      r0 = M[$mp3dec.arbuf_left_size]; L4 = r0;
      r0 = M[$mp3dec.arbuf_right_size]; L0 = r0;
      #ifdef BASE_REGISTER_MODE
         r0 = M[$mp3dec.arbuf_start_left]; push r0; pop B4;
         r0 = M[$mp3dec.arbuf_start_right]; push r0; pop B0;
      #endif
      call $mp3dec.jointstereo_processing;
      L0 = 0;
      L4 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         B0 = M[SP-1];
         pop B4;
      #endif
      PROFILER_STOP(&$mp3dec.profile_jointstereo_processing)

      // update rzerolength
      Null = M[$mp3dec.mode_extension];
      if Z jump start_dspwork;
         // take the minimum of the two
         r0 = M[$mp3dec.rzerolength];
         r1 = M[$mp3dec.rzerolength + 1];
         Null = r0 - r1;
         if GT r0 = r1;
         M[$mp3dec.rzerolength] = r0;
         M[$mp3dec.rzerolength + 1] = r0;
      jump start_dspwork;

   mono_decode:
      // if we have both left and right audio buffers available then
      // copy left channel to right channel - then treat as stereo
      // otherwise we just process mono into the 1 audio buffer which is available
      r5 = M[$mp3dec.codec_struc];
      Null = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
      if Z jump start_dspwork;
      Null = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
      if Z jump start_dspwork;

      r10 = 576;

      r0 = M[$mp3dec.arbuf_left_pointer];
      I0 = r0;
      #ifdef BASE_REGISTER_MODE
         r0 = M[$mp3dec.arbuf_start_left];
         push r0;
         pop B0;
      #endif
      r0 = M[$mp3dec.arbuf_left_size];
      L0 = r0;
      r0 = M[$mp3dec.arbuf_right_pointer];
      I1 = r0;
      #ifdef BASE_REGISTER_MODE
         r0 = M[$mp3dec.arbuf_start_right];
         push r0;
         pop B1;
      #endif
      r0 = M[$mp3dec.arbuf_right_size];
      L1 = r0;

      do mono_copy;
         r0 = M[I0,1];
         M[I1,1] = r0;
      mono_copy:
      // copy across block type information between left and right
      r0 = M[$mp3dec.current_grch];
      r1 = M[$mp3dec.block_type + r0];
      M[($mp3dec.block_type + 1) + r0 ] = r1;
      r1 = M[$mp3dec.rzerolength + 0];
      M[$mp3dec.rzerolength + 1 ] = r1;
      L0 = 0;
      L1 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         B0 = M[SP - 1];
         pop B1;
      #endif


   start_dspwork:

   // -- Reorder spectrum so that short blocks are in order --
   PROFILER_START(&$mp3dec.profile_reorder_spectrum)
   call $mp3dec.reorder_spectrum;
   PROFILER_STOP(&$mp3dec.profile_reorder_spectrum)

   // -- Perform alias reduction --
   PROFILER_START(&$mp3dec.profile_alias_reduction)
   call $mp3dec.alias_reduction;
   PROFILER_STOP(&$mp3dec.profile_alias_reduction)


   // -- Left channel dsp work --
   // IMDCT and frequency compensation
   r5 = M[$mp3dec.codec_struc];
   r0 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
   if Z jump no_left_buffer;
      r0 = M[$mp3dec.arbuf_left_pointer];
      I0 = r0;
      #ifdef BASE_REGISTER_MODE
         r0 = M[$mp3dec.arbuf_start_left];
         push r0;
         pop B0;
      #endif
      r0 = M[$mp3dec.arbuf_left_size];
      L0 = r0;
#ifdef MP3_USE_EXTERNAL_MEMORY
      r0 = M[r9 + $mp3dec.mem.OABUF_LEFT_FIELD];
      I1 = r0;
#else
      I1 = &$mp3dec.oabuf_left;
#endif
      // set to the left channel
      r0 = M[$mp3dec.current_grch];
      r0 = r0 AND $mp3dec.GRANULE_MASK;
      M[$mp3dec.current_grch] = r0;

      // -- Perform IMDCT and windowing + overlap and add --
      PROFILER_START(&$mp3dec.profile_imdct_windowing_overlapadd)
      r1 = 0;     // = left channel
      call $mp3dec.imdct_windowing_overlapadd;
      PROFILER_STOP(&$mp3dec.profile_imdct_windowing_overlapadd)
      L0 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         pop B0;
      #endif

      // -- Perform compensation for freq inversion --
      PROFILER_START(&$mp3dec.profile_compensation_for_freq_inversion)
      call $mp3dec.compensation_for_freq_inversion;
      PROFILER_STOP(&$mp3dec.profile_compensation_for_freq_inversion)

      // set I1 to point to cbuffer for left audio output
      r0 = M[$mp3dec.arbuf_left_pointer];
      I1 = r0;
      #ifdef BASE_REGISTER_MODE
         r0 = M[$mp3dec.arbuf_start_left];
         push r0;
         pop B1;
      #endif
      r0 = M[$mp3dec.arbuf_left_size];
      L1 = r0;

      // do synthesis filter bank
      r0 = M[$mp3dec.synthv_leftptr];
      I4 = r0;
      PROFILER_START(&$mp3dec.profile_synthesis_filterbank)
      call $mp3dec.synthesis_filterbank;
      PROFILER_STOP(&$mp3dec.profile_synthesis_filterbank)
      r0 = I4;
      M[$mp3dec.synthv_leftptr] = r0;

      // store updated cbuffer pointers for left audio output
      r5 = M[$mp3dec.codec_struc];
      r1 = I1;
      r0 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
      call $cbuffer.set_write_address;
      L1 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         pop B1;
      #endif
   no_left_buffer:


   // -- Right channel dsp work --
   // IMDCT and frequency compensation
   r5 = M[$mp3dec.codec_struc];
   r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
   if Z jump no_right_buffer;
      r0 = M[$mp3dec.arbuf_right_pointer];
      I0 = r0;
      #ifdef BASE_REGISTER_MODE
         r0 = M[$mp3dec.arbuf_start_right];
         push r0;
         pop B0;
      #endif
      r0 = M[$mp3dec.arbuf_right_size];
      L0 = r0;
#ifdef MP3_USE_EXTERNAL_MEMORY
      r0 = M[r9 + $mp3dec.mem.OABUF_RIGHT_FIELD];
      I1 = r0;
#else
      I1 = &$mp3dec.oabuf_right;
#endif
      // set the right channel
      r0 = M[$mp3dec.current_grch];
      r0 = r0 OR $mp3dec.CHANNEL_MASK;
      M[$mp3dec.current_grch] = r0;

      // -- Perform IMDCT and windowing + overlap and add --
      PROFILER_START(&$mp3dec.profile_imdct_windowing_overlapadd)
      r1 = 1;     // = right channel
      call $mp3dec.imdct_windowing_overlapadd;
      L0 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         pop B0;
      #endif
      PROFILER_STOP(&$mp3dec.profile_imdct_windowing_overlapadd)

      // -- Perform compensation for freq inversion --
      PROFILER_START(&$mp3dec.profile_compensation_for_freq_inversion)
      call $mp3dec.compensation_for_freq_inversion;
      PROFILER_STOP(&$mp3dec.profile_compensation_for_freq_inversion)

      // set I1 to point to cbuffer for right audio output
      r0 = M[$mp3dec.arbuf_right_pointer];
      I1 = r0;
      #ifdef BASE_REGISTER_MODE
         r0 = M[$mp3dec.arbuf_start_right];
         push r0;
         pop B1;
      #endif
      r0 = M[$mp3dec.arbuf_right_size];
      L1 = r0;

      // do synthesis filter bank
      r0 = M[$mp3dec.synthv_rightptr];
      I4 = r0;
      PROFILER_START(&$mp3dec.profile_synthesis_filterbank)
      call $mp3dec.synthesis_filterbank;
      PROFILER_STOP(&$mp3dec.profile_synthesis_filterbank)
      r0 = I4;
      M[$mp3dec.synthv_rightptr] = r0;

      // store updated cbuffer pointers for right audio output
      r5 = M[$mp3dec.codec_struc];
      r1 = I1;
      r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
      call $cbuffer.set_write_address;
      L1 = 0;
      #ifdef BASE_REGISTER_MODE
         push Null;
         pop B1;
      #endif
   no_right_buffer:

   dummy_decode_tidyup:

   // -- See if both granules have been decoded --
   // mpeg2 and 2.5 only has 1 granule per frame
   Null = M[$mp3dec.frame_version];
   if NZ jump select_1st_granule;
   // mpeg1 has 2 granules per frame
   r0 = M[$mp3dec.current_grch];
   r0 = r0 AND $mp3dec.GRANULE_MASK;
   if Z jump select_2nd_granule;
      select_1st_granule:
      M[$mp3dec.current_grch] = Null;
      jump granule_select_done;

      select_2nd_granule:
      r0 = $mp3dec.GRANULE_MASK;
      M[$mp3dec.current_grch] = r0;

   granule_select_done:


   #ifdef DEBUG_MP3DEC
      // -- Increment granule counter --
      r0 = M[$mp3dec.granule_count];
      r0 = r0 + 1;
      M[$mp3dec.granule_count] = r0;
   #endif

   // -- update $codec.DECODER_STRUC --
   r0 = $codec.SUCCESS;
   M[r5 + $codec.DECODER_MODE_FIELD] = r0;
   r0 = $mp3dec.MAX_AUDIO_FRAME_SIZE_IN_WORDS;
   M[r5 + $codec.DECODER_NUM_OUTPUT_SAMPLES_FIELD] = r0;

   exit:

   // check if any errors occured
   Null = M[$mp3dec.frame_corrupt];
   if Z jump no_corruption;
      r5 = M[$mp3dec.codec_struc];
      r0 = $codec.ERROR;
      M[r5 + $codec.DECODER_MODE_FIELD] = r0;
   no_corruption:

   // -- Stop overall profiling if enabled --
   PROFILER_STOP(&$mp3dec.profile_frame_decode)

   // pop rLink from stack
   jump $pop_rLink_and_rts;

   exit_not_enough_output_space:
   // set NOT_ENOUGH_OUTPUT_SPACE flag and exit
   r0 = $codec.NOT_ENOUGH_OUTPUT_SPACE;
   M[r5 + $codec.DECODER_MODE_FIELD] = r0;
   jump exit;

.ENDMODULE;

#endif
