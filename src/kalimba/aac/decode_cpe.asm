// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.decode_cpe
//
// DESCRIPTION:
//    Get channel pair element information
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume everything
//
// *****************************************************************************
.MODULE $M.aacdec.decode_cpe;
   .CODESEGMENT AACDEC_DECODE_CPE_PM;
   .DATASEGMENT DM;

   $aacdec.decode_cpe:

   // push rLink onto stack
   push rLink;

   // make sure that sample_rate is known
   // (ie. corrupt frames might get us here with out it being set)
   Null = M[$aacdec.sf_index];
   if NEG jump $aacdec.possible_corruption;

   // make sure we haven't had too many CPEs
   r0 = M[$aacdec.num_CPEs];
   r0 = r0 + 1;
   M[$aacdec.num_CPEs] = r0;
   Null = r0 - $aacdec.MAX_NUM_CPES;
   if GT jump $aacdec.possible_corruption;

   // dummy = getbits(4);  //element_instance_tag
   call $aacdec.get4bits;

   // set initial ics and spec pointers to the left channel
   r4 = &$aacdec.ics_left;
   M[$aacdec.current_ics_ptr] = r4;
 #ifndef AAC_USE_EXTERNAL_MEMORY
   r0 = &$aacdec.buf_left;
 #else 
   r0 = M[$aacdec.buf_left_ptr]; 
 #endif // AAC_USE_EXTERNAL_MEMORY
   M[$aacdec.current_spec_ptr] = r0;
   M[$aacdec.current_channel] = Null;

   // set ms_mask_present = 0;
   M[r4 + $aacdec.ics.MS_MASK_PRESENT_FIELD] = Null;

   // common_window = getbits(1);
   call $aacdec.get1bit;
   M[$aacdec.common_window] = r1;

   // if (common_window == 1)
   if Z jump not_common_window;

      // ics_info();
      call $aacdec.ics_info;
      Null = M[$aacdec.possible_frame_corruption];
      if NZ jump $aacdec.possible_corruption;


      // copy across ltp data from right chan to left (if common window)
      r0 = &$aacdec.ics_left;
      r1 = M[r0 + $aacdec.ics.PREDICTOR_DATA_PRESENT_FIELD];
      r4 = &$aacdec.ics_right;
      M[r4 + $aacdec.ics.PREDICTOR_DATA_PRESENT_FIELD] = r1;

      r1 = M[r0 + $aacdec.ics.LTP_INFO_PTR_FIELD];
      M[r4 + $aacdec.ics.LTP_INFO_PTR_FIELD] = r1;

      r1 = M[r0 + $aacdec.ics.LTP_INFO_CH2_PTR_FIELD];
      M[r4 + $aacdec.ics.LTP_INFO_CH2_PTR_FIELD] = r1;


      // ms_mask_present = getbits(2);
      r4 = M[$aacdec.current_ics_ptr];
      call $aacdec.get2bits;
      M[r4 + $aacdec.ics.MS_MASK_PRESENT_FIELD] = r1;

      // if (ms_mask_preset == 1)
      Null = r1 - 1;
      if NZ jump ms_mask_not_one;

         // allocate max_sfb words for the ms_used data
         // use frame memory
         r0 = M[r4 + $aacdec.ics.MAX_SFB_FIELD];
         call $aacdec.frame_mem_pool_allocate;
         if NEG jump $aacdec.possible_corruption;
         M[r4 + $aacdec.ics.MS_USED_PTR_FIELD] = r1;

         // set the initial bitmask = 1
         r7 = 1;

         // for g = 0:num_window_groups-1,
         r5 = M[r4 + $aacdec.ics.NUM_WINDOW_GROUPS_FIELD];
         num_win_groups_loop:

            // set I1 = start of ms_used array
            r1 = M[r4 + $aacdec.ics.MS_USED_PTR_FIELD];
            I1 = r1;

            // for sfb = 0:max_sfb-1,
            r6 = M[r4 + $aacdec.ics.MAX_SFB_FIELD];
            if Z jump max_sfb_loop_end;
            max_sfb_loop:

               // ms_used(g,sfb) = getbits(1);
               call $aacdec.get1bit;

               // read current ms_used word
               r2 = M[I1,0];
               // clear the current bit
               r3 = r2 AND r7;
               r2 = r2 - r3;
               // if getbits was 1 then add the bit to the current word
               Null = r1;
               if NZ r2 = r2 + r7;

               // move on to the next sfb
               r6 = r6 - r0,
                M[I1,1] = r2;          // and store back ms_used word
            if NZ jump max_sfb_loop;
            max_sfb_loop_end:

            // left shift the bit mask
            r7 = r7 LSHIFT 1;

            // move on to the next window group
            r5 = r5 - 1;
         if NZ jump num_win_groups_loop;

      ms_mask_not_one:

      // copy across data from the left ics structure to the right
      // need to copy all data up to ics.NUM_SEC_FIELD
      r10 = $aacdec.ics.NUM_SEC_FIELD;
      I1 = &$aacdec.ics_left;
      I2 = &$aacdec.ics_right;
      do ics_copy;
         r0 = M[I1,1];
         M[I2,1] = r0;
      ics_copy:

   not_common_window:

   #ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
      // -- reset the list of unpacked huffman tables --
      call $aacdec.huffman_reset_unpacked_list;
   #endif

   // individual_channel_stream();
   call $aacdec.individual_channel_stream;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump $aacdec.possible_corruption;

   // set ics and spec pointers to the right channel
   r0 = &$aacdec.ics_right;
   M[$aacdec.current_ics_ptr] = r0;
   #ifndef AAC_USE_EXTERNAL_MEMORY
   r0 = &$aacdec.buf_right;
   #else 
   r0 = M[$aacdec.buf_right_ptr];
   #endif 
   M[$aacdec.current_spec_ptr] = r0;
   r0 = 1;
   M[$aacdec.current_channel] = r0;

   // aacdec_individual_channel_stream();
   call $aacdec.individual_channel_stream;


   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
