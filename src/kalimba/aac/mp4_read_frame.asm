// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"
#include "profiler.h"

// *****************************************************************************
// MODULE:
//    $aacdec.mp4_read_frame
//
// DESCRIPTION:
//    Read an mp4 frame (1 raw_data_block's worth per call)
//
// INPUTS:
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.mp4_read_frame;
   .CODESEGMENT AACDEC_MP4_READ_FRAME_PM;
   .DATASEGMENT DM;

   $aacdec.mp4_read_frame:

   // push rLink onto stack
   push rLink;

   // default is no faults detected
   M[$aacdec.possible_frame_corruption] = Null;
   M[$aacdec.frame_underflow] = Null;

   // if mp4 header has not been fully parsed then continue parsing it
   r0 = M[$aacdec.mp4_header_parsed];
   Null = r0 AND 0x1;
   if Z call $aacdec.mp4_sequence;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump possible_corruption;

   Null = M[$aacdec.frame_underflow];
   if NZ jump frame_underflow;

   // once the mp4 header has been parsed we still need there to be enough data
   // in the buffer to decode a frame
   r0 = M[$aacdec.mp4_header_parsed];
   Null = r0 AND 0x1;
   if Z jump frame_underflow;

      Null = M[$aacdec.mp4_decoding_started];
      if NZ jump read_raw_data_block;

      // check enough data available to decode the first frame
      r0 = M[$aacdec.num_bytes_available];
      Null = r0 - $aacdec.MAX_AAC_FRAME_SIZE_MP4;
      if NEG jump frame_underflow;

      r0 = 1;
      M[$aacdec.mp4_decoding_started] = r0;


   read_raw_data_block:
   // check if all valid data in mdat has been processed
   Null = M[$aacdec.mdat_processed];
   if NZ jump possible_corruption; //Not a proper fix. Need to inform app that decoding is done

   r1 = M[$aacdec.fast_fwd_samples_ls];
   r2 = M[$aacdec.fast_fwd_samples_ms];
   Null = r1 OR r2;
   if Z jump not_fast_fwd_rew;
      call $aacdec.mp4_ff_rew;
      Null = M[$aacdec.frame_underflow];
      if NZ jump frame_underflow;
      jump $pop_rLink_and_rts;

not_fast_fwd_rew:
   r0 = M[$aacdec.read_bit_count];
   M[$aacdec.temp_bit_count] = r0;
   // -- Decode the raw data block --
   PROFILER_START(&$aacdec.profile_raw_data_block)
#ifdef AACDEC_ELD_ADDITIONS
   r2 = $aacdec.raw_data_block;
   r3 = $aacdec.er_raw_data_block_eld;
   r0 = M[$aacdec.audio_object_type];
   Null = r0 - $aacdec.ER_AAC_ELD;
   if EQ r2 = r3;
   // r0 and r1 are not required for $aacdec.raw_data_block but they do no harm
   r1 = $aacdec.BYTE_ALIGN_ON;
   r0 = M[$aacdec.channel_configuration];
   call r2;
#else
   call $aacdec.raw_data_block;
#endif // AACDEC_ELD_ADDITIONS
   PROFILER_STOP(&$aacdec.profile_raw_data_block)

   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump possible_corruption;

   // Update mp4 frame count
   r0 = M[$aacdec.mp4_frame_count];
   r0 = r0 + 1;
   M[$aacdec.mp4_frame_count] = r0;


   call $aacdec.byte_align;

   // Calculate number of bytes read in mp4a atom
   r0 = M[$aacdec.read_bit_count];
   r0 = r0 - M[$aacdec.temp_bit_count];
   r0 = r0 ASHIFT -3;

   r2 = r0 + M[&$aacdec.mp4_file_offset + 1];
   r3 = M[$aacdec.mp4_file_offset] + Carry;

   M[$aacdec.mp4_file_offset + 1] = r2;
   M[$aacdec.mp4_file_offset] = r3;

   r4 = 1;
   r0 = M[$aacdec.mdat_offset + 1];
   r1 = M[$aacdec.mdat_offset];
   r0 = r0 + M[&$aacdec.mdat_size + 2];
   r1 = r1 + M[&$aacdec.mdat_size + 1] + Carry;
   //Compare this with file offset
   r0 = r0 - r2;
   r1 = r1 - r3 - Borrow;
   if POS r4 = 0;
   //Note: $aacdec.mdat_size + 0 can be ignored for practical purposes. To be Removed

   M[$aacdec.mdat_processed] = r4;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

   frame_underflow:
      r0 = 1;
      M[$aacdec.frame_underflow] = r0;

      // pop rLink from stack
      jump $pop_rLink_and_rts;


   possible_corruption:
      // Calculate number of bytes read in mp4a atom
      r0 = M[$aacdec.read_bit_count];
      r0 = r0 - M[$aacdec.temp_bit_count];
      r0 = r0 ASHIFT -3;

      r2 = r0 + M[&$aacdec.mp4_file_offset + 1];
      r3 = M[$aacdec.mp4_file_offset] + Carry;

      M[$aacdec.mp4_file_offset + 1] = r2;
      M[$aacdec.mp4_file_offset] = r3;


      r0 = M[$aacdec.frame_num_bits_avail];
      r0 = r0 - M[$aacdec.read_bit_count];
      if POS jump $aacdec.corruption;
         r0 = 1;
         M[$aacdec.frame_underflow] = r0;
         // pop rLink from stack
         jump $pop_rLink_and_rts;


.ENDMODULE;

