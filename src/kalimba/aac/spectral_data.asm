// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.spectral_data
//
// DESCRIPTION:
//    Get spectral data
//
// INPUTS:
//    - I0 = buffer to read words from
//    - r4 = current ics pointer
//
// OUTPUTS:
//    - I0 = buffer to read words from (updated)
//
// TRASHED REGISTERS:
//    - r0-r8, r10, rMAC, I1-I7, M2, M3
//    - first 2 elements of $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.spectral_data;
   .CODESEGMENT AACDEC_SPECTRAL_DATA_PM;
   .DATASEGMENT DM;

   $aacdec.spectral_data:

   // push rLink onto stack
   push rLink;


   // spectral_data = zeros(1,1024);
   // ELD: spectral_data = zeros(1,512|480); 
   r0 = M[$aacdec.current_spec_ptr];
   I1 = r0;

   r10 = 1024;

#ifdef AACDEC_ELD_ADDITIONS
   r0 = M[$aacdec.audio_object_type];
   Null = r0 - $aacdec.ER_AAC_ELD;
   if NE jump frame_size_selected;
      r1 = $aacdec.FRAME_SIZE_480;
      r10 = $aacdec.FRAME_SIZE_512;
      Null = M[$aacdec.frame_length_flag];
      if NZ r10 = r1;
   frame_size_selected:
#endif // AACDEC_ELD_ADDITIONS
   r0 = 0;
   do spectrum_clear_loop;
      M[I1,1] = r0;
   spectrum_clear_loop:



   #ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
      // -- unpack the huffman tables that are required for this frame --

      r8 = M[r4 + $aacdec.ics.NUM_WINDOW_GROUPS_FIELD];

      // set I5 to start of sect_cb
      r0 = M[r4 + $aacdec.ics.SECT_CB_PTR_FIELD];
      I5 = r0;

      // set I6 to start of num_sec
      I6 = r4 + $aacdec.ics.NUM_SEC_FIELD;

      unpack_num_window_groups_loop:

         // rMAC = num_sec(g)
         rMAC = M[I6,1];

         unpack_num_sec_loop:
            rMAC = rMAC - 1;
            if NEG jump unpack_end_num_sec_loop;
#ifndef AAC_USE_EXTERNAL_MEMORY
            r6 = M[$aacdec.frame_mem_pool_end];
#else 
            r6 = M[$aacdec.frame_mem_pool_end_ptr];
#endif 
            // get sect_cb(g,i);
            r5 = M[I5,1];
            Null = r5 - $aacdec.NOISE_HCB;
            if NEG call $aacdec.huffman_unpack_individual_flash_table;
#ifndef AAC_USE_EXTERNAL_MEMORY
            r1 = M[$aacdec.frame_mem_pool_end];
#else 
            r1 = M[$aacdec.frame_mem_pool_end_ptr];
#endif
            r1 = r1 - r6;
            r0 = M[$aacdec.amount_unpacked];
            r0 = r0 + r1;
            M[$aacdec.amount_unpacked] = r0;
         jump unpack_num_sec_loop;

         unpack_end_num_sec_loop:
         r8 = r8 - 1;
      if NZ jump unpack_num_window_groups_loop;
   #endif




   // window = 0;
   //
   // for g = 0:num_window_groups-1
   // {
   //    freq_line = window * 128;
   //
   //    for i = 0:num_sec(g)-1
   //    {
   //       switch (sect_cb(g,i))
   //       {
   //          case ZERO_HCB:
   //          case NOISE_HCB:
   //          case INTENSITY_HCB:
   //          case INTENSITY_HCB2:
   //          {
   //             freqline = freqline + sect_sfb_offset(g,sect_end(g,i))
   //                                 - sect_sfb_offset(g,sect_start(g,i));
   //             break;
   //          }
   //
   //          default:
   //          {
   //             if sect_cb(g,i) >= FIRST_PAIR_HCB
   //             {
   //                for j = sect_sfb_offset(g,sect_start(g,i)) : 2 :
   //                        sect_sfb_offset(g,sect_end(g,i)),
   //                {
   //                   [y.z] = huffman_get_pair(sect_cb(g,i));
   //                   spectral_data(freqline+1) = y;
   //                   spectral_data(freqline+2) = z;
   //                   freq_line += 2;
   //                }
   //             }
   //             else
   //             {
   //                for j = sect_sfb_offset(g,sect_start(g,i)) : 4 :
   //                        sect_sfb_offset(g,sect_end(g,i)),
   //                {
   //                   [w,x,y.z] = huffman_get_quad(sect_cb(g,i));
   //                   spectral_data(freqline+1) = w;
   //                   spectral_data(freqline+2) = x;
   //                   spectral_data(freqline+3) = y;
   //                   spectral_data(freqline+4) = z;
   //                   freq_line += 4;
   //                }
   //             }
   //             break;
   //          }
   //       }
   //    }
   //    window += window_group_length(g);
   // }


   // set things up for huffman decoding to work
   call $aacdec.huffman_start;

   // set I3 to start of sect_start
   r0 = M[r4 + $aacdec.ics.SECT_START_PTR_FIELD];
   I3 = r0;

   // set I4 to start of sect_end
   r0 = M[r4 + $aacdec.ics.SECT_END_PTR_FIELD];
   I4 = r0;

   // set I5 to start of sect_cb
   r0 = M[r4 + $aacdec.ics.SECT_CB_PTR_FIELD];
   I5 = r0;

   // set I6 to start of num_sec
   I6 = r4 + $aacdec.ics.NUM_SEC_FIELD;

   // set I7 to start of window_group_length
   I7 = r4 + $aacdec.ics.WINDOW_GROUP_LENGTH_FIELD;

   // set r8 to start of sect_sfb_offset
   r8 = M[r4 + $aacdec.ics.SECT_SFB_OFFSET_PTR_FIELD];

   // set M3 to num_window_groups
   r0 = M[r4 + $aacdec.ics.NUM_WINDOW_GROUPS_FIELD];
   M3 = r0;

   // set tmp[0] = num_swb + 1;
   r0 = M[r4 + $aacdec.ics.NUM_SWB_FIELD];
   r0 = r0 + 1;
   M[$aacdec.tmp] = r0;


   // set r1 and tmp[1] to start of spectral_data
   r1 = M[$aacdec.current_spec_ptr];
   M[$aacdec.tmp + 1] = r1;

   // set r7 = -12 for huffman decoding
   r7 = -12;

   num_window_groups_loop:

      // freq_line = groups * 128;
      I1 = r1;

      // rMAC = num_sec(g)
      rMAC = M[I6,1];

      // if num_sec = 0 then skip this loop
      Null = rMAC;
      if Z jump end_num_sec_loop;

      num_sec_loop:

         // get sect_start(g,i);
         r0 = M[I3,1],
          r1 = M[I4,1];       // get sect_end(g,i);

         // get sect_cb(g,i);
         r4 = M[I5,1];

         // get sect_sfb_offset(g,sect_end(g,i))
         r1 = M[r8 + r1];
         // get sect_sfb_offset(g,sect_start(g,i))
         r0 = M[r8 + r0];
         r10 = r1 - r0;

         // handle the special case of (sect_end-sect_start = 0)
         if Z jump zero_sect_width;

         // set I2 = ptr to the huffman table to use
         r0 = M[$aacdec.huffman_cb_table + r4];
         I2 = r0;

         Null = r4 - $aacdec.FIRST_PAIR_HCB;
         if NEG jump zero_or_quad_book;

         Null = r4 - $aacdec.NOISE_HCB;
         if NEG jump pair_book;

         zero_sect_width:
         zero_hcb:
         noise_hcb:
         intensity_hcb:
         intensity_hcb2:
            I1 = I1 + r10;
            rMAC = rMAC - 1;
            if NZ jump num_sec_loop;
            jump end_num_sec_loop;

         pair_book:
            // set M2 = start of huffman table
            M2 = I2;
            r9 = r10 LSHIFT -1;
            pair_loop:
               call $aacdec.huffman_getpair;
               // set I2 back to the start of the huffman table
               I2 = M2;
               r9 = r9 - 1;
            if NZ jump pair_loop;
            rMAC = rMAC - 1;
            if NZ jump num_sec_loop;
            jump end_num_sec_loop;

         zero_or_quad_book:
            Null = r4;
            if Z jump zero_hcb;
            r10 = r10 LSHIFT -2;
            // set M2 = start of huffman table
            M2 = I2;
            do quad_loop;
               call $aacdec.huffman_getquad;
               // set I2 back to the start of the huffman table
               I2 = M2;
            quad_loop:
            rMAC = rMAC - 1;
            if NZ jump num_sec_loop;

      end_num_sec_loop:

      // r8 = sect_sfb_offset(g,0)
      r8 = r8 + M[$aacdec.tmp];

      // get window_group_length(g);
      r0 = M[I7,1];

      // freq_line = freq_line + 128*window_group_length(g);
      r0 = r0 * 128 (int);
      r1 = r0 + M[$aacdec.tmp + 1];
      M[$aacdec.tmp + 1] = r1;

      M3 = M3 - 1;
   if NZ jump num_window_groups_loop;

   // put things back for getbits to work
   call $aacdec.huffman_finish;

   // set r4 back to being a pointer to the ICS structure
   r4 = M[$aacdec.current_ics_ptr];

   #ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
      Null = M[$aacdec.current_channel];
      if NZ jump deallocate_tables;
         Null = M[$aacdec.num_SCEs];
         if NZ jump deallocate_tables;
            jump $pop_rLink_and_rts;

      deallocate_tables:
         r0 = M[$aacdec.amount_unpacked];
         call $aacdec.frame_mem_pool_free;
         M[$aacdec.amount_unpacked] = Null;
   #endif


   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
