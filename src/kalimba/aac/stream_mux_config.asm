// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.stream_mux_config
//
// DESCRIPTION:
//    Read the stream_mux_config
//
// INPUTS:
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    - r0-r5, r10, I1
//
// *****************************************************************************
.MODULE $M.aacdec.stream_mux_config;
   .CODESEGMENT AACDEC_STREAM_MUX_CONFIG_PM;
   .DATASEGMENT DM;

   $aacdec.stream_mux_config:

   // push rLink onto stack
   push rLink;


   // latm.audioMuxVersion = getbits(1);
   // if (latm.audioMuxVersion==1)
   //    latm.audioMuxVersionA = getbits(1);
   // else
   //    latm.audioMuxVersionA = 0;
   // end
   call $aacdec.get1bit;
   M[$aacdec.latm.audio_mux_version] = r1;
   if NZ call $aacdec.get1bit;
   M[$aacdec.latm.audio_mux_version_a] = r1;



   // if (latm.audioMuxVersionA ~= 0)
   //    error('audioMuxVersionA non-zero not supported');
   // end
   if NZ jump $aacdec.possible_corruption;



   // if (latm.audioMuxVersion==1)
   //    taraBufferFullnesss = latm_get_value;
   // end
   r4 = 0;
   Null = M[$aacdec.latm.audio_mux_version];
   if NZ call $aacdec.latm_get_value;
   M[$aacdec.latm.taraBufferFullnesss] = r4;



   // latm.allStreamsSameTimeFraming = getbits(1);
   // this bit must be set to be compliant with the A2DP spec
   call $aacdec.get1bit;
   if Z jump $aacdec.possible_corruption;



   // latm.numSubFrames = getbits(6);
   call $aacdec.get6bits;
   M[$aacdec.latm.num_subframes] = r1;



   // numProgram = getbits(4);
   // numLayer = getbits(3);
   // if (numProgram~=0) || (numLayer~=0)
   //    error('Only support single layer and single program streams');
   // end
   call $aacdec.get4bits;
   if NZ jump $aacdec.possible_corruption;
   call $aacdec.get3bits;
   if NZ jump $aacdec.possible_corruption;



   // if (latm.audioMuxVersion == 0)
   //    audio_specific_config;
   // else
   //    ascLen = latm_get_value;
   //    prevbitpos = filebitpos();
   //    audio_specific_config;
   //    ascLen = ascLen - (filebitpos() - prevbitpos);
   //    for i = 1:ascLen,
   //       getbits(1);
   //    end
   // end
   Null = M[$aacdec.latm.audio_mux_version];
   if NZ jump asc_data;
      call $aacdec.audio_specific_config;
      Null = M[$aacdec.possible_frame_corruption];
      if NZ jump $aacdec.possible_corruption;

      jump audio_config_read;
   asc_data:
      call $aacdec.latm_get_value;

      M[$aacdec.latm.asc_len] = r4;
      r0 = M[$aacdec.read_bit_count];
      M[$aacdec.latm.prevbitpos] = r0;

      call $aacdec.audio_specific_config;
      Null = M[$aacdec.possible_frame_corruption];
      if NZ jump $aacdec.possible_corruption;

      r10 = M[$aacdec.latm.asc_len];
      r10 = r10 - M[$aacdec.read_bit_count];
      r10 = r10 + M[$aacdec.latm.prevbitpos];
      if NEG jump $aacdec.possible_corruption;
      do loop;
         call $aacdec.get1bit;
      loop:
   audio_config_read:



   // latm.FrameLengthType = getbits(3);
   // if (latm.FrameLengthType==0)
   //    latm.latmBufferFullness = getbits(8);
   // else
   //    error('FrameLengthType not equal to 0 isn''t suppported');
   // end
   call $aacdec.get3bits;
   if NZ jump $aacdec.possible_corruption;
   call $aacdec.get1byte;
   M[$aacdec.latm.latm_buffer_fullness] = r1;



   // latm.otherDataPresent = getbits(1);
   // if (latm.otherDataPresent)
   //    if (latm.audioMuxVersion==1)
   //       latm.otherDataLenBits = latm_get_value;
   //    else
   //       latm.otherDataLenBits = 0;
   //       esc = 1;
   //       while (esc),
   //          latm.otherDataLenBits = latm.otherDataLenBits * 256;
   //          esc = getbits(1);
   //          latm.otherDataLenBits = latm.otherDataLenBits + getbits(8);
   //       end
   //    end
   // end
   call $aacdec.get1bit;
   r4 = r1;
   if Z jump store_other_data_len_bits;

      Null = M[$aacdec.latm.audio_mux_version];
      if Z jump audio_mux_version_zero;
         call $aacdec.latm_get_value;
         jump store_other_data_len_bits;

      audio_mux_version_zero:
         r4 = 0;
         another_word_loop:
            r4 = r4 LSHIFT 8;
            call $aacdec.get1bit;
            r5 = r1;
            call $aacdec.get1byte;
            r4 = r4 + r1;
            Null = r5;
         if NZ jump another_word_loop;

   store_other_data_len_bits:
   M[$aacdec.latm.other_data_len_bits] = r4;


   // crc_check_present = getbits(1);
   // if (crc_check_present)
   //    latm.crcCheckSum = getbits(8);
   // end
   call $aacdec.get1bit;
   // discard the CRC checkword
   if NZ call $aacdec.get1byte;

   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;

