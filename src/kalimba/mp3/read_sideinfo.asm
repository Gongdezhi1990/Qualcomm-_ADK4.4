// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_READ_SIDEINFO_INCLUDED
#define MP3DEC_READ_SIDEINFO_INCLUDED

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.read_sideinfo
//
// DESCRIPTION:
//    Read SideInfo
//
// INPUTS:
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    r0-r3, r5-r8, r10, I1, I2
//
// *****************************************************************************

.MODULE $M.mp3dec.read_sideinfo;
   .CODESEGMENT MP3DEC_READ_SIDEINFO_PM;
   .DATASEGMENT DM;

   $mp3dec.read_sideinfo:
   // push rLink onto stack
   $push_rLink_macro;


   Null = M[$mp3dec.frame_version];
   if Z jump mpeg1_sideinfo;

   mpeg2_and_2p5_sideinfo:
      // read main_data_begin field
      r0 = 8;
      call $mp3dec.getbits_and_calc_crc;
      Null = M[$mp3dec.rfc3119_enable];
      if NZ r1 = 0;
      M[$mp3dec.main_data_begin] = r1;


      // if stereo nch = 2, private_bits = 2
      // if mono nch = 1, private_bits = 1
      r0 = 1;
      r6 = M[$mp3dec.mode];
      Null = r6 - $mp3dec.SINGLE_CHANNEL;
      if NZ r0 = r0 + r0;
      r7 = r0;
      // read private bits and throw them away
      call $mp3dec.getbits_and_calc_crc;
      jump initial_sideinfo_read;

   mpeg1_sideinfo:
      // read main_data_begin field
      r0 = 9;
      call $mp3dec.getbits_and_calc_crc;
      Null = M[$mp3dec.rfc3119_enable];
      if NZ r1 = 0;
      M[$mp3dec.main_data_begin] = r1;


      // if stereo nch = 2, private_bits = 3
      r0 = 3;
      r7 = 2;
      r6 = M[$mp3dec.mode];
      Null = r6 - $mp3dec.SINGLE_CHANNEL;
      if NZ jump two_chan;
         // if mono nch = 1, private_bits = 5
         r0 = 5;
         r7 = 1;
      two_chan:


      // read private bits and throw them away
      call $mp3dec.getbits_and_calc_crc;


      // read scfsi bits
      r6 = r7 * 4 (int);
      r0 = 1;
      I1 = &$mp3dec.scfsi;

      scfi_loop:
         call $mp3dec.getbits_and_calc_crc;
         M[I1,1] = r1;
         r6 = r6 - 1;
      if NZ jump scfi_loop;

   initial_sideinfo_read:
   // r7 = 2 (if mono)
   // r7 = 1 (if 2 channel)
   r7 = 3 - r7;
   r6 = 0;
   grch_loop:

      // read part2_3_length
      r0 = 12;
      call $mp3dec.getbits_and_calc_crc;
      M[$mp3dec.part2_3_length + r6] = r1;


      // read big_values
      r0 = 9;
      call $mp3dec.getbits_and_calc_crc;
      r1 = r1 * 2 (int);
      // saturate big_valuesx2 to 576;
      r0 = 576;
      Null = r1 - r0;
      if POS r1 = r0;
      M[$mp3dec.big_valuesx2 + r6] = r1;


      // read global_gain
      r0 = 8;
      call $mp3dec.getbits_and_calc_crc;
      M[$mp3dec.global_gain + r6] = r1;


      // read scalefac_compress (4 bits for mpeg1, 9 bits for mpeg2 & 2.5)
      r0 = 4;
      r1 = 9;
      Null = M[$mp3dec.frame_version];
      if NZ r0 = r1;
      call $mp3dec.getbits_and_calc_crc;
      M[$mp3dec.scalefac_compress + r6] = r1;


      // read window_switching_flag
      r0 = 1;
      call $mp3dec.getbits_and_calc_crc;
      Null = r1;
      if Z jump normalblock;

         // read block_type
         r0 = 2;
         call $mp3dec.getbits_and_calc_crc;
         r8 = r1;
         // block_type = 0 is reserved
         if Z jump corrupt_file_error;

          // read mixed_block_flag
         r0 = 1;
         // form block_type mask
         r8 = r0 LSHIFT r8;
         call $mp3dec.getbits_and_calc_crc;
         r1 = r1 * 16 (int);
         r8 = r8 + r1;
         // store block_type and mixed_flag as a mask
         // combined (mixed_flag = bit 4)
         M[$mp3dec.block_type + r6] = r8;


         // if (short not mixed)
         //    set region_1_start = 36 (if not 8KHz)   or 72 (if 8KHz)
         // else
         //    set region_1_start = sum(first 8 scalefactor band widths)
         //    = 36 always for MPEG1
         // end
         r1 = 36;
         r0 = M[$mp3dec.sampling_freq];
         Null = r0 - $mp3dec.SAMPFREQ_8K;
         if Z r1 = r1 + r1;
         Null = r8 - $mp3dec.SHORT_MASK;
         if Z jump region1_start_set;
            #if !defined(MP3DEC_ZERO_FLASH)
               I1 = &$mp3dec.sfb_width_long;
            #else
               r0 = r0 * $mp3dec.NUM_LONG_SF_BANDS (int);
               I1 = &$mp3dec.sfb_width_long + r0;
            #endif
            r10 = 8;
            r1 = 0;
            do region1_start_loop;
               r0 = M[I1,1];
               r1 = r1 + r0;
            region1_start_loop:
         region1_start_set:
         M[$mp3dec.region1_start + r6] = r1;


         // set region_1_count = 576
         r1 = 576;
         M[$mp3dec.region2_start + r6] = r1;


         // read table_select region0
         r8 = r6 * 3 (int);
         r0 = 5;
         call $mp3dec.getbits_and_calc_crc;
         M[$mp3dec.table_select + r8] = r1;


         // read table_select region1
         r8 = r8 + 1;
         call $mp3dec.getbits_and_calc_crc;
         M[$mp3dec.table_select + r8] = r1;


         // read subblock_gain win = 0
         r8 = r6 * 3 (int);
         r0 = 3;
         call $mp3dec.getbits_and_calc_crc;
         r1 = r1 * 8 (int);
         // store it *8
         M[$mp3dec.subblock_gain + r8] = r1;


         // read subblock_gain win = 1
         r8 = r8 + 1;
         call $mp3dec.getbits_and_calc_crc;
         r1 = r1 * 8 (int);
         // store it *8
         M[$mp3dec.subblock_gain + r8] = r1;


         // read subblock_gain win = 2
         r8 = r8 + 1;
         call $mp3dec.getbits_and_calc_crc;
         r1 = r1 * 8 (int);
         // store it *8
         M[$mp3dec.subblock_gain + r8] = r1;

         jump block_select_endif;


      normalblock:

         // set block_type = Normal Window
         r0 = $mp3dec.LONG_MASK;
         M[$mp3dec.block_type + r6] = r0;


         // read table_select region0
         r8 = r6 * 3 (int);
         r0 = 5;
         call $mp3dec.getbits_and_calc_crc;
         M[$mp3dec.table_select + r8] = r1;


         // read table_select region1
         r8 = r8 + 1;
         call $mp3dec.getbits_and_calc_crc;
         M[$mp3dec.table_select + r8] = r1;


         // read table_select region2
         r8 = r8 + 1;
         call $mp3dec.getbits_and_calc_crc;
         M[$mp3dec.table_select + r8] = r1;


         #if defined(MP3DEC_ZERO_FLASH)
            r2 = M[$mp3dec.sampling_freq];
            r2 = r2 * $mp3dec.NUM_LONG_SF_BANDS (int);
            I1 = &$mp3dec.sfb_width_long + r2;
         #else
            I1 = &$mp3dec.sfb_width_long;
         #endif


         // read region0_count
         r0 = 4;
         call $mp3dec.getbits_and_calc_crc;
         r10 = r1 + 1;
         r2 = 0;
         do region0_loop;
            r1 = M[I1,1];
            r2 = r2 + r1;
         region0_loop:
         // saturate region1_start to 576;
         r0 = r2 - 576;
         if POS r2 = r2 - r0;
         M[$mp3dec.region1_start + r6] = r2;
         I2 = r2;


         // read region1_count
         r0 = 3;
         call $mp3dec.getbits_and_calc_crc;
         r10 = r1 + 1;
         r2 = I2;
         do region1_loop;
            r1 = M[I1,1];
            r2 = r2 + r1;
         region1_loop:
         // saturate region2_start to 576;
         r0 = r2 - 576;
         if POS r2 = r2 - r0;
         M[$mp3dec.region2_start + r6] = r2;

      block_select_endif:

      // read preflag
      Null = M[$mp3dec.frame_version];
      if NZ jump no_preflag;
         r0 = 1;
         call $mp3dec.getbits_and_calc_crc;
         M[$mp3dec.preflag + r6] = r1;
      no_preflag:

      // read scalefac_scale
      r0 = 1;
      call $mp3dec.getbits_and_calc_crc;
      r1 = r1 + 1;
      // store scale_multiplier * 4;
      r1 = r1 * 2 (int);
      M[$mp3dec.scale_multiplier_x4 + r6] = r1;


      // read count1table_select
      call $mp3dec.getbits_and_calc_crc;
      M[$mp3dec.count1table_select + r6] = r1;

      r6 = r6 + r7;
      Null = M[$mp3dec.frame_version];
      if Z jump mpeg1_loop_check;
         Null = r6 - 2;
         if Z jump grch_loop_finished;
      mpeg1_loop_check:
      Null = r6 - 4;
   if NZ jump grch_loop;
   grch_loop_finished:

   // if no crc checking then clear the fields
   if USERDEF jump crc_enabled;
      M[$mp3dec.crc_checksum] = Null;
      M[$mp3dec.frame_crc] = Null;
      // pop rLink from stack
      jump $pop_rLink_and_rts;


   crc_enabled:
      // finish off crc checksum (a byte shift)
      r0 = M[$mp3dec.crc_checksum];
      r0 = r0 LSHIFT -8;
      M[$mp3dec.crc_checksum] = r0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;


   corrupt_file_error:
      r0 = 1;
      M[$mp3dec.frame_corrupt] = r0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;


.ENDMODULE;

#endif
