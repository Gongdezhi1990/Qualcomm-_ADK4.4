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
//    $aacdec.adts_read_frame
//
// DESCRIPTION:
//    Read an adts frame (1 raw_data_block's worth per call)
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
.MODULE $M.aacdec.adts_read_frame;
   .CODESEGMENT AACDEC_ADTS_READ_FRAME_PM;
   .DATASEGMENT DM;

   $aacdec.adts_read_frame:

   // push rLink onto stack
   push rLink;

   .VAR saved_I0;
   .VAR saved_bitpos;

   // save buffer address and bitpos
   r0 = I0;
   M[saved_I0] = r0;
   r0 = M[$aacdec.get_bitpos];
   M[saved_bitpos] = r0;

   // default is no faults detected
   M[$aacdec.frame_underflow] = Null;
   M[$aacdec.frame_corrupt] = Null;
   M[$aacdec.possible_frame_corruption] = Null;

   // check if we still need to read the remains of an id3 tag
   Null = M[$aacdec.id3_skip_num_bytes];
   if NZ jump skip_remaining_id3_tag;

   // get byte aligned - we should be anyway but for robustness we force it
   r0 = M[$aacdec.get_bitpos];
   r0 = r0 AND 7;
   call $aacdec.getbits;

   // find adts or ID3v1 or ID3v2 syncword
   r4 = 0;
   findsyncloop:
      // store value of I0 just before sync word might have been found
      I2 = I0;
      r7 = M[$aacdec.get_bitpos];

      // check if enough data available to read another byte
      r4 = r4 + 1;
      Null = r4 - M[$aacdec.num_bytes_available];
      if GT jump buffer_underflow_occured;

      // read a byte
      call $aacdec.get1byte;

      // see if byte matches any of our tags
      Null = r1 - 0xFF;
      if Z jump found_first_byte_adts;
      Null = r1 - 0x54;  // 'T'
      if Z jump found_first_byte_id3v1;
      Null = r1 - 0x49;  // 'I'
      if Z jump found_first_byte_id3v2;
      jump findsyncloop;


      // ADTS sync tag 'FFF?' or 'FFE?'
      found_first_byte_adts:
      // check if enough data available to read another byte
      r4 = r4 + 1;
      Null = r4 - M[$aacdec.num_bytes_available];
      if GT jump buffer_underflow_occured;
      // read a nibble if 0xF we're synced
      call $aacdec.get4bits;
      Null = r1 - 0xF;
      if Z jump syncfound_adts;
      // if not chuck the next nibble and find sync again
      call $aacdec.get4bits;
      jump findsyncloop;


      // ID3v1 sync tag 'TAG'
      found_first_byte_id3v1:
      // check if enough data available to read another byte
      r4 = r4 + 1;
      Null = r4 - M[$aacdec.num_bytes_available];
      if GT jump buffer_underflow_occured;
      // read next byte - should be 'A'
      call $aacdec.get1byte;
      Null = r1 - 0x41;   // 'A'
      if NZ jump findsyncloop;
      // check if enough data available to read another byte
      r4 = r4 + 1;
      Null = r4 - M[$aacdec.num_bytes_available];
      if GT jump buffer_underflow_occured;
      // read next byte - should be 'G'
      call $aacdec.get1byte;
      Null = r1 - 0x47;   // 'G'
      if NZ jump findsyncloop;
      jump syncfound_id3v1;


      // ID3v2 sync tag 'ID3'
      found_first_byte_id3v2:
      // check if enough data available to read another byte
      r4 = r4 + 1;
      Null = r4 - M[$aacdec.num_bytes_available];
      if GT jump buffer_underflow_occured;
      // read next byte - should be 'D'
      call $aacdec.get1byte;
      Null = r1 - 0x44;   // 'D'
      if NZ jump findsyncloop;
      // check if enough data available to read another byte
      r4 = r4 + 1;
      Null = r4 - M[$aacdec.num_bytes_available];
      if GT jump buffer_underflow_occured;
      // read next byte - should be '3'
      call $aacdec.get1byte;
      Null = r1 - 0x33;   // '3'
      if NZ jump findsyncloop;
      jump syncfound_id3v2;


   syncfound_id3v1:
      //  we skip the remaining 125 bytes of ID3v1 tag data
      r0 = 125;
      M[$aacdec.id3_skip_num_bytes] = r0;
      // store number of bytes now available
      r4 = r4 - M[$aacdec.num_bytes_available];
      M[$aacdec.num_bytes_available] = -r4;
      jump skip_remaining_id3_tag;


   syncfound_id3v2:
      // check we have enough data available to read another 7 bytes
      r4 = r4 + 7;
      Null = r4 - M[$aacdec.num_bytes_available];
      if GT jump buffer_underflow_occured;

      // read and discard 2 bytes of version data
      call $aacdec.get1byte;
      call $aacdec.get1byte;

      // read 1 byte of flags data
      call $aacdec.get1byte;
      // if no footer tag size = size + 10
      r5 = 10;
      // bit 4 if set means there are 10 bytes extra (footer data)
      Null = r1 AND 0x10;
      if NZ r5 = r5 + r5;


      // read 4 bytes of size data
      // only LS 7bits of each are valid data
      call $aacdec.get1byte;
      r1 = r1 AND 3;
      r1 = r1 LSHIFT 21;
      r5 = r5 + r1;
      call $aacdec.get1byte;
      r1 = r1 LSHIFT 14;
      r5 = r5 + r1;
      call $aacdec.get1byte;
      r1 = r1 LSHIFT 7;
      r5 = r5 + r1;
      call $aacdec.get1byte;
      r5 = r5 + r1;

      // we've now read 10bytes in total
      r5 = r5 - 10;
      //  so we need to skip the remaining r5 bytes of ID3v2 tag data
      M[$aacdec.id3_skip_num_bytes] = r5;
      // store number of bytes now available
      r4 = r4 - M[$aacdec.num_bytes_available];
      M[$aacdec.num_bytes_available] = -r4;

   skip_remaining_id3_tag:
      r0 = M[$aacdec.id3_skip_num_bytes];
      r10 = M[$aacdec.num_bytes_available];
      Null = r10 - r0;
      if POS r10 = r0;

      // update skip_num_bytes for next time
      M[$aacdec.id3_skip_num_bytes] = r0 - r10;

      // discard the bytes
      do discard_id3_data_loop;
         call $aacdec.get1byte;
      discard_id3_data_loop:

      // exit with a corrupt file error
      // so that reattempt decoding from the next adts header
      jump corrupt_file_error;


   syncfound_adts:

   #ifdef DEBUG_AACDEC
      // if the syncword wasn't just the next 12bits in the buffer
      // then increment the lostsync count
      Null = r4 - 2;
      if Z jump didnt_loose_sync;
         r0 = M[$aacdec.lostsync_errors];
         r0 = r0 + 1;
         M[$aacdec.lostsync_errors] = r0;
      didnt_loose_sync:
   #endif

   // store number of bytes now available
   r4 = r4 - M[$aacdec.num_bytes_available];
   M[$aacdec.num_bytes_available] = -r4;
   // check we can read 7 more bytes of header minimum
   Null = r4 + 7;
   if GT jump buffer_underflow_occured;


   // now decode the rest of the header

      // read id field (selects between MPEG2 (1) and MPEG4 (0))
   r5 = $aacdec.MPEG2_AAC_STREAM;
   r6 = $aacdec.MPEG4_AAC_STREAM;
   call $aacdec.get1bit;
   if Z r5 = r6;
   M[$aacdec.frame_version] = r5;   // TODO ez01 this does not seem to be used at all



   // read layer field
   call $aacdec.get2bits;
   // error if layer != 0
   if NZ jump corrupt_file_error;


   // read protection field
   call $aacdec.get1bit;
   M[$aacdec.protection_absent] = r1;


   // read profile_objecttype field
   call $aacdec.get2bits;
   // Just throw it away for the moment


   // read sampling_freq field
   call $aacdec.get4bits;
   // check that sampling frequency is the same as the last frame
   Null = M[$aacdec.sf_index];
   if NEG jump sampling_freq_update;
      Null = r1 - M[$aacdec.sf_index];
      if Z jump sampling_freq_correct;
      // sampling frequency has changed must be a corrupt frame
      r0 = -1;
      M[$aacdec.sf_index] = r0;
      jump corrupt_file_error;
   sampling_freq_update:
   // error if reserved or unsupported sampling_freq selected
   #ifdef USE_AAC_TABLES_FROM_FLASH
      r0 = &$aacdec.sampling_freq_lookup;
      r2 = M[$flash.windowed_data16.address];
      push rLink;
      r5 = r1;
      call $flash.map_page_into_dm;
      r1 = r5;
      r0 = M[r0 + r5];
      pop rLink;
   #else
      r0 = M[$aacdec.sampling_freq_lookup + r1];
   #endif

   if NEG jump corrupt_file_error;
   M[$aacdec.sf_index] = r1;
   sampling_freq_correct:


   // read and throw away private field
   call $aacdec.get1bit;


   // read channel_configuration field
   call $aacdec.get3bits;
   M[$aacdec.channel_configuration] = r1;
#ifndef AACDEC_ADTS_MULTICHANNEL_SUPPORT
   // multi channel isn't supported
   Null = r1 - 2;
   if GT jump corrupt_file_error;
#endif

   // read and throw away original/copy + home + (emphasis field if old format)
   #ifdef AACDEC_ADTS_OLD_FORMAT_WITH_EMPHASIS_BITS
      call $aacdec.get4bits;
   #else
      call $aacdec.get2bits;
   #endif


   // read and throw away copyright_id_bit + copyright_id_start field
   call $aacdec.get2bits;


   // read frame_length field
   r0 = 13;
   call $aacdec.getbits;
   M[$aacdec.frame_length] = r1;

   // see if we have enough data to read the rest of the frame
   // subtract off the 2 bytes accounted for in reading the sync word above
   r1 = r1 - 2;
   Null = r1 - M[$aacdec.num_bytes_available];
   if GT jump buffer_underflow_occured;



   // read and throw away adts_buffer_fullness field
   r0 = 11;
   call $aacdec.getbits;


   // read no_raw_data_blocks_in_frame field
   call $aacdec.get2bits;
   r1 = r1 + 1;
   M[$aacdec.no_raw_data_blocks_in_frame] = r1;


   // skip crc field if needed
   Null = M[$aacdec.protection_absent];
   if Z call $aacdec.get2bytes;


   // -- Decode the raw data block --
   PROFILER_START(&$aacdec.profile_raw_data_block)
   push I2;
   push r7;
   call $aacdec.raw_data_block;
   pop r7;
   pop I2;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump possible_corruption;
   PROFILER_STOP(&$aacdec.profile_raw_data_block)

   // byte align
   call $aacdec.byte_align;

   // pop rLink from stack
   jump $pop_rLink_and_rts;


   possible_corruption:
      r0 = M[$aacdec.frame_num_bits_avail];
      r1 = r0 - M[$aacdec.read_bit_count];
      if NEG jump buffer_underflow_occured;
      // corrupt input, but we have read more
      // than available data
      r0 = r0 - M[saved_bitpos];
      r0 = r0 + BITPOS_START;
#ifndef USE_PACKED_ENCODED_DATA
      r0 = r0 LSHIFT -4;
#else
      rMAC = 0;
      rMAC0 = r0;
      r0 = 24;
      Div = rMAC / r0;
      r0 = divResult;
#endif
      M0 = r0;
      r0 = M[saved_I0];
      I0 = r0;
      r0 = M[I0, M0];      
      jump corrupt_file_error;

   buffer_underflow_occured:
      // adjust I0 and bitpos to just before a possible sync word was found,
      // this allows us to sync next time to that sync word when more data
      // is available.
      I0 = I2;
      M[$aacdec.get_bitpos] = r7;
      r0 = 1;
      M[$aacdec.frame_underflow] = r0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;


   corrupt_file_error:
      r0 = 1;
      M[$aacdec.frame_corrupt] = r0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;

.ENDMODULE;
