// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.mp4_ff_rew
//
// DESCRIPTION:
//    - r1 = fast_forward_remaining_samples_ls
//    - r2 = fast_forward_remaining_samples_ms
//
// OUTPUTS:
//    - r4 - Status of fast fwd/rwd (0 --> FAIL/PENDING, 1 --> SUCCESS)
//    - r5 - LS value of output samples produced
//    - r6 - MS value of output samples produced
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.aac_ff_rew;
   .CODESEGMENT AACDEC_AAC_FF_REW_PM;
   .DATASEGMENT DM;

   $aacdec.aac_ff_rew:

   push rLink;

   r4 = 0;

   Null = M[$aacdec.skip_function];
   if Z jump $pop_rLink_and_rts;

   //find out which FF/REW function to call (ADTS or MP4)

   #ifdef AACDEC_MP4_FILE_TYPE_SUPPORTED
      r3 = M[$aacdec.read_frame_function];
      Null = r3 - M[$aacdec.read_frame_func_table + 0];
      if NZ jump not_mp4_file;
         // check whether mp4 FF/REW is done
         call $aacdec.mp4_ff_rew_get_status;
         jump $pop_rLink_and_rts;

   #endif

   not_mp4_file:
      call $aacdec.adts_ff_rew;

   jump $pop_rLink_and_rts;

.ENDMODULE;

#ifdef AACDEC_MP4_FILE_TYPE_SUPPORTED

// *****************************************************************************
// MODULE:
//    $aacdec.mp4_ff_rew_get_status
//
// DESCRIPTION:
//    - r1 = fast_forward_remaining_samples_ls
//    - r2 = fast_forward_remaining_samples_ms
//
// OUTPUTS:
//    - r4 - Status of fast fwd/rwd (0 --> FAIL/PENDING, 1 --> SUCCESS)
//    - r5 - LS value of output samples produced
//    - r6 - MS value of output samples produced
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.mp4_ff_rew_get_status;
   .CODESEGMENT AACDEC_AAC_FF_REW_PM;
   .DATASEGMENT DM;

   $aacdec.mp4_ff_rew_get_status:

   push rLink;

   r4 = 0;

   // Check mp4 FF/REW status
   r0 = M[$aacdec.mp4_ff_rew_status];

   Null = r0 - $aacdec.MP4_FF_REW_SEEK_NOT_POSSIBLE;
   // Unable to jump. Just return and allow decoder to gobble
   // This might happen if STZ2 is present instead of STSZ. To be fixed
   if Z jump $pop_rLink_and_rts;

   Null = r0 - $aacdec.MP4_FF_REW_NULL;
   if NZ jump mp4_ff_rew_status_not_null;
      // initial state. Change to IN_PROGRESS
      M[$aacdec.fast_fwd_samples_ls] = r1;
      M[$aacdec.fast_fwd_samples_ms] = r2;
      r1 = $aacdec.MP4_FF_REW_IN_PROGRESS;
      M[$aacdec.mp4_ff_rew_status] = r1;
      jump $pop_rLink_and_rts;

   mp4_ff_rew_status_not_null:
   Null = r0 - $aacdec.MP4_FF_REW_IN_PROGRESS;
   if Z jump $pop_rLink_and_rts; // Ongoing. Just return

   r4 = 1;
   r5 = M[$aacdec.fast_fwd_samples_ls];
   r6 = M[$aacdec.fast_fwd_samples_ms];
   r1 = $aacdec.MP4_FF_REW_NULL;
   M[$aacdec.mp4_ff_rew_status] = r1;
   M[$aacdec.fast_fwd_samples_ls] = Null;
   M[$aacdec.fast_fwd_samples_ms] = Null;

   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif

// *****************************************************************************
// MODULE:
//    $aacdec.adts_ff_rew
//
// DESCRIPTION:
//    - r1 = fast_forward_remaining_samples_ls
//    - r2 = fast_forward_remaining_samples_ms
//
// OUTPUTS:
//    - r4 - Status of fast fwd/rwd (0 --> FAIL, 1 --> SUCCESS)
//    - r5 - LS value of output samples produced
//    - r6 - MS value of output samples produced
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.adts_ff_rew;
   .CODESEGMENT AACDEC_AAC_FF_REW_PM;
   .DATASEGMENT DM;

   $aacdec.adts_ff_rew:

   push rLink;

   M[$aacdec.fast_fwd_samples_ls] = r1;
   M[$aacdec.fast_fwd_samples_ms] = r2;

   // check if it is rewind
   Null = r2;
   if POS jump not_rewind;
      r1 = Null - r1;
      r2 = Null - r2 - Borrow;

   not_rewind:
      // rMAC = {r2,r1)
      rMAC = r1 LSHIFT 0 (LO);
      r3 = 0x800000;
      rMAC = rMAC + r2 * r3 (UU);

      r0 = 2;
      r3 = $aacdec.MAX_AUDIO_FRAME_SIZE_IN_WORDS;
      Null = M[$aacdec.sbr_present];
      if NZ r3 = r0 * r3 (int);

      Div = rMAC/r3;
      rMAC = M[$aacdec.frame_length];
      r6 = DivResult;

      Null = M[$aacdec.avg_bit_rate];
      if Z jump avg_bit_rate_unknown;

         r2 = M[$aacdec.avg_bit_rate];
         r2 = r2 * 1000 (int); // convert to bits per second
         rMAC = r2 LSHIFT -3; // Divide by 8 (bits to bytes)
         rMAC = r3 * rMAC;

         r1 = M[$aacdec.sf_index];

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

         r1 = &$aacdec.sample_rate_tags + $aacdec.OFFSET_TO_SAMPLE_RATE_TAG;
         r1 = r1 + r0;
         r0 = M[r1]; // read sampling frequency
         r0 = r0 * 2 (int); // rMAC has double the actual value
         Div = rMAC/r0;
         rMAC= DivResult;

   avg_bit_rate_unknown:

      rMAC = rMAC * r6;

      r3 = rMAC LSHIFT 23;
      r4 = rMAC LSHIFT -1;

      // Seek must be negative in case of rewind
      Null = M[$aacdec.fast_fwd_samples_ms];
      if POS jump pos_seek;
         r3 = Null - r3;
         r4 = Null - r4 - Borrow;

   pos_seek:
      r6 = M[$aacdec.skip_function];
      // set I0 to point to cbuffer for mp3 input stream
      r5 = M[$aacdec.codec_struc];
      r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
      call $cbuffer.get_read_address_and_size;
      I0 = r0;

      call $aacdec.skip_through_file;

      r4 = 1;
      r5 = M[$aacdec.fast_fwd_samples_ls];
      r6 = M[$aacdec.fast_fwd_samples_ms];
      M[$aacdec.fast_fwd_samples_ls] = Null;
      M[$aacdec.fast_fwd_samples_ms] = Null;
      L0 = 0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;


.ENDMODULE;
