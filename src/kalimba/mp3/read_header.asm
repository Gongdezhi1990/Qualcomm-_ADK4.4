// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_READ_HEADER_INCLUDED
#define MP3DEC_READ_HEADER_INCLUDED

#include "stack.h"
#include "mp3.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.read_header
//
// DESCRIPTION:
//    Read MP3 Header
//
// INPUTS:
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    rMAC, r0-r7, r10, DoLoop, I2
//
// *****************************************************************************
.MODULE $M.mp3dec.read_header;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR frame_version_lut[4]=$mp3dec.MPEG2p5, $mp3dec.MPEG_reserved, $mp3dec.MPEG2, $mp3dec.MPEG1;
   .VAR $mp3_temp1;
   $mp3dec.read_header:

   // push rLink onto stack
   $push_rLink_macro;

   //no crc check until we find that protection bit is set
   rFlags = rFlags AND $NOT_UD_FLAG;
   // default is no faults detected
   M[$mp3dec.frame_underflow] = 0;
   M[$mp3dec.frame_corrupt] = 0;

   // check if we still need to read the remains of an id3 tag
   Null = M[$mp3dec.id3_skip_num_bytes];
   if NZ jump skip_remaining_id3_tag;

   // get byte aligned - we should be anyway but for robustness we force it
   r0 = M[$mp3dec.get_bitpos];
   r0 = r0 AND 7;
   if NZ call $mp3dec.getbits;

   // check for rfc3119
   Null = M[$mp3dec.rfc3119_enable];
   if Z jump not_rfc3119;
      // read ADU frame length
      r0 = 2;
      call $mp3dec.getbits;

      r0 = 14;
      call $mp3dec.getbits;
      M[$mp3dec.framelength] = r1;
   not_rfc3119:



   r4 = M[$mp3dec.num_bytes_available];

   //in findsync loop r6 is used as holderof last 3 bytes read from the codec input buffer
   r6 = 0;

   // find mp3 or ID3v1 or ID3v2 syncword
   findsyncloop:
      // store value of I0 just before sync word might have been found
      I2 = I0;
      r7 = M[$mp3dec.get_bitpos];

     //check to see if we can get another byte from the codec input buffer
     r4 = r4 -1;
     if NEG jump buffer_underflow_occured;

      // read a byte
      r0 = 8;
      call $mp3dec.getbits;

     r6 = r6 LSHIFT 8;
     r6 = r6 + r1;


      // tag         FirstByte   Secod Byte     Third Byte
     //---------------------------------------------------
     // mp3            0xFF        0xF? or 0xE?   ?? (? = not par of sync)
     // id3_v1         'T'=0x54    'A'=0x41       'G' = 0x47
     // id3_v2         'I'=0x49    'D'=0x49       '3' = 0x33
     // ape_v2         'A'=0x41    'P'=0x50       'E' = 0x45
     //

     // check to see if it is a mp3 sync
     // only the first 12 bits is checked, the second 12 bits contains other info
     r2 = r6 AND 0xFFE000;
     Null = r2 - 0xFFE000;
     if  Z jump syncfound_mp3;

      //check to see if it is an id3_v1 sync
     Null = r6 - 0x544147;
     if  Z jump syncfound_id3v1;

     //check to see if it is an id3_v2 sync
     Null = r6 - 0x494433;
     if Z jump syncfound_id3v2;

     //check to see if it is an ape_v2 sync
     Null = r6 - 0x415045;
     if Z jump syncfound_apev2;

     jump findsyncloop;


   syncfound_id3v1:

   #ifdef DEBUG_MP3DEC
      r0 = M[$mp3dec.frame_type];
      r0 = r0 OR $mp3dec.FRAME_ID3V1;
      M[$mp3dec.frame_type] = r0;
   #endif

      call detect_mp3_by_tag;

      //  we skip the remaining 125 bytes of ID3v1 tag data
      r5 = 125;
      jump set_id3_skip_num_bytes;

   syncfound_id3v2:

   #ifdef DEBUG_MP3DEC
      r0 = M[$mp3dec.frame_type];
      r0 = r0 OR $mp3dec.FRAME_ID3V2;
      M[$mp3dec.frame_type] = r0;
   #endif

      call detect_mp3_by_tag;

      // check we have enough data available to read another 7 bytes
      r4 = r4 -7;
      if NEG jump buffer_underflow_occured;

      // read and discard 2 bytes of version data
      r0 = 16;
      call $mp3dec.getbits;


      // read 1 byte of flags data
      r0 = 8;
      call $mp3dec.getbits;
      // if no footer tag size = size + 10
      r5 = 10;
      // bit 4 if set means there are 10 bytes extra (footer data)
      Null = r1 AND 0x10;
      if NZ r5 = r5 + r5;


      // read 4 bytes of size data
      // only LS 7bits of each are valid data
      r0 = 8;
      call $mp3dec.getbits;
      r1 = r1 AND 3;
      r1 = r1 LSHIFT 21;
      r5 = r5 + r1;
      call $mp3dec.getbits;
      r1 = r1 LSHIFT 14;
      r5 = r5 + r1;
      call $mp3dec.getbits;
      r1 = r1 LSHIFT 7;
      r5 = r5 + r1;
      call $mp3dec.getbits;
      r5 = r5 + r1;

      // we've now read 10bytes in total
      r5 = r5 - 10;

      r6 = M[$mp3dec.skip_function];
      if Z jump set_id3_skip_num_bytes;
         r3 = r5;
         // r4 = r4 - Borrow; // TODO it is assumed that ID3 is smaller than 8MB
         r4 = 0;              //
         call $mp3dec.skip_through_file;
         jump tag_data_skipped;

   set_id3_skip_num_bytes:
      //  so we need to skip the remaining r5 bytes of ID3v2 tag data
      M[$mp3dec.id3_skip_num_bytes] = r5;
      // store number of bytes now available
      M[$mp3dec.num_bytes_available] = r4;
   skip_remaining_id3_tag:
      r0 = M[$mp3dec.id3_skip_num_bytes];
      r10 = M[$mp3dec.num_bytes_available];
      Null = r10 - r0;
      if POS r10 = r0;

      // update skip_num_bytes for next time
      M[$mp3dec.id3_skip_num_bytes] = r0 - r10;

      // discard the bytes
      r0 = 8;
      do discard_id3_data_loop;
         call $mp3dec.getbits;
         nop;
      discard_id3_data_loop:

   tag_data_skipped:
      // exit with a corrupt file error
      // so that reattempt decoding from the next mp3 header
      jump corrupt_file_error;

   syncfound_apev2:

   #ifdef DEBUG_MP3DEC
      r0 = M[$mp3dec.frame_type];
      r0 = r0 OR $mp3dec.FRAME_APEV2;
      M[$mp3dec.frame_type] = r0;
   #endif

      call detect_mp3_by_tag;

      // TODO: the succeding bytes after { 'A', 'P', 'E'} should be { 'T', 'A', 'G', 'E', 'X' }

      //  we skip the remaining 29 bytes of APEv2 tag data
      r5 = 29;
      jump set_id3_skip_num_bytes;


   // MP3 detection
   detect_mp3_by_tag:
      // reset frame detection counter, since it is processing a TAG
      M[$mp3dec.frame_detect_counter] = Null;

      // beginning of a file?
      r0 = M[$mp3dec.beginning_of_file];
      if Z rts;

      // beginning of a block?
      r0 = M[$mp3dec.num_bytes_available];
      r0 = r0 - 3;
      Null = r4 - r0;
      if NZ rts;

      // now a tag had been detected at the very beginning of the file
      // let's decide it must be a true MP3 file,
      r0 = 1;
      M[$mp3dec.valid_mp3_file_detected] = r0;
      rts;


   syncfound_mp3:
   // if sync word was 0xFFE then it's a version 2.5 stream


   // if the syncword wasn't just the next 12bits in the buffer
   // then set lost sync flag
   r1 = 1;
   r0 = M[$mp3dec.num_bytes_available];
   r0 = r0 - 3;
   Null = r4 - r0;
   if Z r1 = 0;
   M[$mp3dec.lostsync] = r1;

   #ifdef DEBUG_MP3DEC
      // increment the lostsync count if lost sync happend
      Null = M[$mp3dec.lostsync];
      if Z jump didnt_loose_sync;
         r0 = M[$mp3dec.lostsync_errors];
         r0 = r0 + 1;
         M[$mp3dec.lostsync_errors] = r0;
      didnt_loose_sync:
   #endif

   // store number of bytes now available
   M[$mp3dec.num_bytes_available] = r4;

   // 3 bytes has been read so far
   r0 =  24;
   M[$mp3dec.framebitsread] = r0;

   // clac frame version based on id field and sync word
   // sync  id  frame_version
   // FFE    0     MPEG2p5
   //
   // FFE    1     MPEG_reserved
   //----------------------------
   // FFF    0     MPEG2
   //
   // FFF    1     MPEG1
   // remember r6 contains first 24-bit of the header
   // extrac the second byte
   r1 = r6 LSHIFT -8;
   r0 = r1 LSHIFT -3;
   r0 = r0 AND 3;
   r3 = M[r0+&frame_version_lut];
   M[$mp3dec.frame_version] = r3;

   //error if frame_version == MPEG_reserved
   Null = r3 - $mp3dec.MPEG_reserved;
   if Z jump corrupt_file_error;

   // extract layer field
   r0 = r1 LSHIFT -1;
   r0 = r0 AND 3;
   M[$mp3dec.frame_layer] = r0;

   // error if layer != III
   Null = r0 - $mp3dec.LAYER_III;
   if NZ jump corrupt_file_error;


   // read protection field
   // UD Flag is set, it must be reset when crc checking is no longer required
   r0 = $UD_FLAG;
   r1 = r1 AND 1;
   if Z rFlags = rFlags OR r0;

   //--- Extracting info from the 3rd byte of header

   // initialise $crc_calc
   r0 = $mp3dec.CRC_INITVAL;
   M[$mp3dec.crc_checksum] = r0;



   // extract bitrate_index field
   r1 = r6 LSHIFT -4;
   r1 = r1 AND 0xF;

   // convert to bitrate
   r0 = M[$mp3dec.frame_version];
   if NZ jump mpeg2_or_2p5_bitrate;
   mpeg1_bitrate:
      rMAC = M[$mp3dec.bit_rates + r1];
      jump bitrate_read_done;
   mpeg2_or_2p5_bitrate:
      rMAC = M[$mp3dec.bit_rates_v2_and_v2p5 + r1];
   bitrate_read_done:
   // error if forbidden bitrate_index
   if NEG jump corrupt_file_error;

   M[$mp3dec.bitrate] = rMAC;
   // extract sampling_freq field
   r1 = r6 LSHIFT -2;
   r1 = r1 AND 0x3;

   //extract sampling frequency
   r0 = M[$mp3dec.frame_version];
   r0 = r0 * 3 (int);
   r0 = r0 + r1;

   // check that sampling frequency is the same as the last frame
   Null = M[$mp3dec.sampling_freq];
   if NEG jump sampling_freq_update;
      Null = r0 - M[$mp3dec.sampling_freq];
      if Z jump sampling_freq_correct;
      // sampling frequency has changed must be a corrupt frame
      r0 = -1;
      M[$mp3dec.sampling_freq] = r0;
      jump corrupt_file_error;
   sampling_freq_update:
   // error if reserved sampling_freq selected
   Null = r1 - $mp3dec.SAMPFREQ_RESERVED;
   if Z jump corrupt_file_error;
        M[$mp3dec.sampling_freq] = r0;

   #if (!defined(MP3DEC_ZERO_FLASH))
      // save a few registers
      I3 = I0; M3 = L0; L0 = 0;
      #ifdef BASE_REGISTER_MODE
         push B0;
         push Null;
         pop B0;
      #endif

      // update width tables from flash
      r0 = r0 * $mp3dec.NUM_LONG_SF_BANDS (int);
      r0 = r0 + &$mp3dec.sfb_width_long_flash;
      r1 = $mp3dec.NUM_LONG_SF_BANDS;
      I0 = &$mp3dec.sfb_width_long;
      r2 = M[$flash.windowed_data16.address];
      call $flash.copy_to_dm;

      r0 = M[$mp3dec.sampling_freq];
      r0 = r0 * $mp3dec.NUM_SHORT_SF_BANDS (int);
      r0 = r0 + &$mp3dec.sfb_width_short_flash;
      r1 = $mp3dec.NUM_SHORT_SF_BANDS;
      I0 = &$mp3dec.sfb_width_short;
      r2 = M[$flash.windowed_data16.address];
      call $flash.copy_to_dm;

      r0 = M[$mp3dec.sampling_freq];
      #ifdef BASE_REGISTER_MODE
         pop B0;
      #endif
      I0 = I3; L0 = M3;
   #endif

   sampling_freq_correct:


   // calc frame length
   r1 = M[$mp3dec.framelen_freqcoef + r0];
   rMAC = rMAC * r1;
   rMAC = rMAC LSHIFT 4;


   //3rd word of header has already been read but yet no crc has been calculated
   r0 = 8;
   r1= r6 AND 0xFF;
   if USERDEF call $mp3dec.crc_check;

   // read padding_bit field
   r1 = r6 LSHIFT -1;
   r1 = r1 AND 0x1;

   // store calculated frame length
   r6 = r1 + rMAC;
   Null = M[$mp3dec.rfc3119_enable];
   if NZ jump dont_update_framelength;
      M[$mp3dec.framelength] = r6;
   dont_update_framelength:

   // see if we have enough data to read the rest of the frame
   // subtract off the 2 bytes accounted for in reading the sync word above
   r6 = r6 - 2;
   Null = r6 - M[$mp3dec.num_bytes_available];
   if GT jump buffer_underflow_occured;


   //read a byte
   r0 = 8;
   call $mp3dec.getbits_and_calc_crc;

   // extract mode field
   r0 = r1 LSHIFT -6;
   r0 = r0 AND 3;
   M[$mp3dec.mode] = r0;


   // extract mode extension field(2 bits)
   r0 = r1 LSHIFT -4;
   r0 = r0 AND 3;
   M[$mp3dec.mode_extension] = r0;


   // extract copyright field (1 bit)
   r0 = r1 LSHIFT -3;
   r0 = r0 AND 1;
   M[$mp3dec.copyright] = r0;


   // extract original/copy field (1 bits)
   r0 = r1 LSHIFT -2;
   r0 = r0 AND 1;
   M[$mp3dec.orig_copy] = r0;

   // extract emphasis field (1 bits)
   r0 = r1 AND 3;
   M[$mp3dec.emphasis] = r0;


   if USERDEF jump read_crc_field;
   jump dont_read_crc_field;

   read_crc_field:
      //disable crc checking when reading crc info
     rFlags = rFlags AND $NOT_UD_FLAG;
      r0 = 16;
     // read crc_check field
      call $mp3dec.getbits;
      M[$mp3dec.frame_crc] = r1;
     //re-enable crc checking
     rFlags = rFlags OR $UD_FLAG;

   dont_read_crc_field:
   // pop rLink from stack
   jump $pop_rLink_and_rts;


   buffer_underflow_occured:
      // adjust I0 and bitpos to just before a possible sync word was found,
      // this allows us to sync next time to that sync word when more data
      // is available.
      I0 = I2;
     //start of the sync is 2 bytes before I2, so we decrement I0 by one word
     r0 = M[I0, -1];
      M[$mp3dec.get_bitpos] = r7;
     //setting overflow flag
      r0 = 1;
      M[$mp3dec.frame_underflow] = r0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;


   corrupt_file_error:
      r0 = 1;
      M[$mp3dec.frame_corrupt] = r0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;


.ENDMODULE;


#endif
