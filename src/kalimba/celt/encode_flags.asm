// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_ENCODE_FLAGS_INCLUDED
#define CELT_ENCODE_FLAGS_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.encode_flags
//
// DESCRIPTION:
//   encode flags for current frame, 
//   these flags indicate featurs available in the frame 
//
// INPUTS:
//  r5: pointer to decoder structure
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//   assume everything except r5
//
// *****************************************************************************
.MODULE $M.celt.encode_flags;
   .CODESEGMENT CELT_ENCODE_FLAGS_PM;
   .DATASEGMENT DM;
   $celt.encode_flags:

   // push rLink onto stack
   $push_rLink_macro;
  
   r0 = M[r5 + $celt.enc.INTRA_ENER_FIELD];
   r1 = M[r5 + $celt.enc.HAS_PITCH_FIELD];
   r0 = r0 OR r1;
   r1 = M[r5 + $celt.enc.SHORT_BLOCKS_FIELD];
   r0 = r0 OR r1;
   r1 = M[r5 + $celt.enc.HAS_FOLD_FIELD];
   r0 = r0 OR r1;
   // verify it is a valid flag
   r10 = 8;
   I2 = &$celt.flaglist;
   r1 = M[I2, 1];
   r2 = r1 AND $celt.FLAG_MASK;
   do ver_on_list_loop;
      r2 = r2 - r0, r1 = M[I2, 1];
      if Z jump break_ver_lp;
      r2 = r1 AND $celt.FLAG_MASK;
   ver_on_list_loop:
      // flag not found in the list
      // return error
      r0 = 1;
      jump $pop_rLink_and_rts;
   break_ver_lp:   
   r0 = I2-(&$celt.flaglist);
   M[$celt.enc.ec_enc.fl + 1] = Null;
   M[$celt.enc.ec_enc.ft + 1] = Null;
   r1 = M[(&$celt.flaglist-2) + r0];   
   r1 = r1 AND 0xF;
   M[$celt.enc.ec_enc.fl + 0] = r1;
   r1 = 3;
   r0 = r0 LSHIFT -2;
   if NZ r0 = r0 XOR r1;
   r0 = 4 LSHIFT r0;
   M[$celt.enc.ec_enc.ft + 0] = r0;
   call $celt.ec_enc_uint;   
   

   Null = M[r5 + $celt.enc.SHORT_BLOCKS_FIELD];
   if Z jump end;
   M[$celt.enc.ec_enc.ft + 1] = Null;
   M[$celt.enc.ec_enc.fl + 1] = Null;
   r0 = M[r5 + $celt.enc.TRANSIENT_SHIFT_FIELD];
   if Z jump no_transient_shift;
      M[$celt.enc.ec_enc.fl + 0] = r0;
      r0 = 4;
      M[$celt.enc.ec_enc.ft + 0] = r0;
      call $celt.ec_enc_uint;
      r0 = M[r5 + $celt.enc.TRANSIENT_TIME_FIELD];
      M[$celt.enc.ec_enc.fl + 0] = r0;
      r0 = M[r5 + $celt.enc.MODE_OVERLAP_FIELD];
      r1 = M[r5 + $celt.enc.MODE_MDCT_SIZE_FIELD];
      M[$celt.enc.ec_enc.ft + 0] = r0 + r1;
      call $celt.ec_enc_uint;
      jump end;      
   no_transient_shift:
      r0 = M[r5 + $celt.enc.MDCT_WEIGHT_SHIFT_FIELD];
      M[$celt.enc.ec_enc.fl + 0] = r0;
      r0 = 4;
      M[$celt.enc.ec_enc.ft + 0] = r0;
      call $celt.ec_enc_uint;
      r0 = M[r5 + $celt.enc.MDCT_WEIGHT_SHIFT_FIELD];
      if Z jump end;
      r0 = M[r5 + $celt.enc.MODE_NB_SHORT_MDCTS_FIELD];
      Null = r0 - 3;
      if NEG jump end;
      r0 = r0 - 1;
      r1 = M[r5 + $celt.enc.MDCT_WEIGHT_POS_FIELD];
      M[$celt.enc.ec_enc.fl + 0] = r1;
      M[$celt.enc.ec_enc.ft + 0] = r0;
      call $celt.ec_enc_uint;
   end:
   // output
   r0 = 0;
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
#endif
