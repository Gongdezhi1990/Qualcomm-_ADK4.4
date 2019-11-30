// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_DEC_LAPLACE_INCLUDED
#define CELT_DEC_LAPLACE_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.ec_laplace_decode_start
//
// DESCRIPTION:
//   laplace distribution decode
// INPUTS:
//   r3 = start freq
//   r2 = decay
// OUTPUTS:
//   r1 = decoded value
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.ec_laplace_decode_start;
   .CODESEGMENT CELT_EC_LAPLACE_DECODE_START_PM;
   .DATASEGMENT DM;
   
   $celt.ec_laplace_decode_start:
   // push rLink onto stack
   $push_rLink_macro;
   
   push r3;
   push r2;
   call $celt.ec_decode_bin;
   pop r2;
   pop r3;
   r4 = 0;     //fl
   r6 = 32768; //ft
   r7 = r3;    //fh
   M0 = 0;     //val
   M2 = 1;
   loop_start_laplace:
      Null = r0 -  r7;
      if NEG jump laplace_loop_end;
      Null = r3;
      r4 = r7;
      rMAC = r3*r2;
      rMAC = rMAC LSHIFT (24-15);
      r3 = rMAC;
      NULL = r7 - (32768-1);
      if POS rMAC = 0;
      rMAC = rMAC OR r3;
      if Z r3 = M2;
      rMAC = r3 + r3;
      r7 = r7 + rMAC;
      M0 = M0 + 1;
   jump loop_start_laplace;
            
   laplace_loop_end:    
   Null = r4 - 0;
   if LE jump end_flh_fix;
      rMAC = r0 - r4;
      rMAC = rMAC - r3;
      if NEG r7 = r7 - r3;
      Null = rMAC;
      if NEG jump end_flh_fix;
      M0 = -M0;
      r4 = r4 + r3;
   end_flh_fix:
   Null = r4 - r7;
   if Z r4 = r4 - M2;
   M[$celt.dec.ec_dec.fl + 0] = r4;
   M[$celt.dec.ec_dec.fl + 1] = 0;
   M[$celt.dec.ec_dec.fh + 0] = r7;
   M[$celt.dec.ec_dec.fl + 1] = 0; 
   M[$celt.dec.ec_dec.ft + 0] = r6;
   M[$celt.dec.ec_dec.fl + 1] = 0; 
   push M0;
   call $celt.ec_dec_update;
   pop r1;
   // pop rLink from stack
   jump $pop_rLink_and_rts;
  .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_laplace_encode_start
//
// DESCRIPTION:
//   laplace distribution decode
// INPUTS:
//   r3 = start freq
//   r2 = decay
//   r1 = val
//   r8 = s
//   r7 = ft
//   r6 = fl
//   r1 = value
// OUTPUTS:
//   r1 = decoded value
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************  
 .MODULE $M.celt.ec_laplace_encode_start;
   .CODESEGMENT CELT_EC_LAPLACE_ENCODE_START_PM;
   .DATASEGMENT DM;
   
   $celt.ec_laplace_encode_start:
   // push rLink onto stack
   $push_rLink_macro;
   .VAR temp;
   M[temp] = r1;
   r10 = r1;
   if NEG 
   r10 = -r10;
   r7 = 32768;
   r6 = -r3;
   M1 = 1;
   M2 = 0;
   do calc_fl_loop;
      r4 = r3 + r3;
      r6 = r6 + r4;
      r0 = r3;
      rMAC = r3*r2;
      r3 = rMAC LSHIFT (24-15);
      if NZ jump end_update;
         r8 = r6 + 2;
         Null = r7 - r8;
         if POS jump set_fs;
            r3 = r0;
            r6 = r6 - r4;
            r1 = M2;
            Null = M[temp];
            if NEG r1 = -r1;
            jump end_calc_loop;
      set_fs:
      r3 = 1;
      end_update:
      M2 = M2 + 1;
   calc_fl_loop:
   end_calc_loop:
   Null = r6;
   if NEG r6 = 0;
   Null = M[temp];
   if NEG r6 = r6 + r3;
   M[$celt.enc.ec_enc.fl + 0] = r6;
   M[$celt.enc.ec_enc.fl + 1] = NULL;
   M[$celt.enc.ec_enc.fh + 0] = r6 + r3;
   M[$celt.enc.ec_enc.fh + 1] = NULL;
   M[temp] = r1;
   call $celt.ec_encode_bin;   
   r1 = M[temp]; 
   // pop rLink from stack
   jump $pop_rLink_and_rts;
  .ENDMODULE;

#endif
