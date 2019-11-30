// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_DECODE_FLAGS
#define CELT_DECODE_FLAGS
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.decode_flags
//
// DESCRIPTION:
//   decode flags for current frame, 
//   these flags indicate featurs available the frame 
//
// INPUTS:
//  r5: pointer to decoder structure
//
// OUTPUTS:
//   r0: NZ means error in the frame
//
// TRASHED REGISTERS:
//   assume everything except r5
//
// *****************************************************************************
.MODULE $M.celt.decode_flags;
   .CODESEGMENT CELT_DECODE_FLAGS_PM;
   .DATASEGMENT DM;
   $celt.decode_flags:

   // push rLink onto stack
   $push_rLink_macro;
   .VAR flag_bits;
   // read flags
   r0 = 4;
   r1 = 0;
   call $celt.ec_dec_uint;
   M[flag_bits] = r0;   
   Null = r0 - 2;
   if NZ jump test_for_fb3;
      // flag bits = 2
      r0 = 4;
      r1 = 0;
      call $celt.ec_dec_uint;
      r4 = M[flag_bits];
      r4 = r4 LSHIFT 2;
      r0 = r0 OR r4;
   test_for_fb3:
   Null = r0 - 3;
   if NZ jump flag_list_ver;
      // flag bits = 3
      r0 = 2;
      call $celt.ec_dec_uint;
      r4 = M[flag_bits];
      r4 = r4 LSHIFT 1;
      r0 = r0 OR r4;
   flag_list_ver:    
   // verify it is a valid flag
   r10 = 8;
   I2 = &$celt.flaglist;
   r1 = M[I2, 1];
   r2 = r1 AND 0xF;
   do ver_on_list_loop;
      r2 = r2 - r0, r1 = M[I2, 1];
      if Z jump break_ver_lp;
      r2 = r1 AND 0xF;
   ver_on_list_loop:
      // flag not found in the list
      // return error
      r0 = 1;
      jump $pop_rLink_and_rts;
   break_ver_lp:
   
   // flags found in the list, set available features
   I2 = I2 - 2;
   r1 = M[I2, 0];
   r0 = r1 AND $celt.FLAG_INTRA;
   M[r5 + $celt.dec.INTRA_ENER_FIELD] = r0;
   r0 = r1 AND $celt.FLAG_PITCH;
   M[r5 + $celt.dec.HAS_PITCH_FIELD] = r0;
   r0 = r1 AND $celt.FLAG_SHORT;
   M[r5 + $celt.dec.SHORT_BLOCKS_FIELD] = r0;
   r0 = r1 AND $celt.FLAG_FOLD;
   M[r5 + $celt.dec.HAS_FOLD_FIELD] = r0;
   
   // Extract more info for short blocks
   r0 = -1; //no transient time
   M[r5 + $celt.dec.TRANSIENT_SHIFT_FIELD] = 0;
   M[r5 + $celt.dec.MDCT_WEIGHT_SHIFT_FIELD] = 0;
   M[r5 + $celt.dec.MDCT_WEIGHT_POS_FIELD] = 0;
   Null = M[r5 + $celt.dec.SHORT_BLOCKS_FIELD];
   if Z jump set_transient_time;
      r0 = 4;
      r1 = 0;
      call $celt.ec_dec_uint;
      Null = r0 - 3;
      if NZ jump check_mdct_weight;
         M[r5 + $celt.dec.TRANSIENT_SHIFT_FIELD] = r0;
         r1 = 0;
         r0 = M[r5 + $celt.dec.MODE_OVERLAP_FIELD];
         r2 = M[r5 + $celt.dec.MODE_MDCT_SIZE_FIELD];
         r0 = r0 + r2;
         call $celt.ec_dec_uint;
         jump set_transient_time;
         check_mdct_weight:
            M[r5 + $celt.dec.TRANSIENT_SHIFT_FIELD] = 0;
            M[r5 + $celt.dec.MDCT_WEIGHT_SHIFT_FIELD] = r0;
            if Z jump pos_calc_end;
            r0 = M[r5 + $celt.dec.MODE_NB_SHORT_MDCTS_FIELD];
            Null = r0 - 3;
            if NEG jump pos_calc_end;
            r0 = r0 - 1;
            r1 = 0;
            call $celt.ec_dec_uint;
            M[r5 + $celt.dec.MDCT_WEIGHT_POS_FIELD] = r0;
         pos_calc_end:
         r0 = 0;
   set_transient_time:
   M[r5 + $celt.dec.TRANSIENT_TIME_FIELD] = r0;

   // output
   r0 = 0;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
#endif
