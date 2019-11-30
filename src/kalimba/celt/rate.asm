// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_RATE_INCLUDED
#define CELT_RATE_INCLUDED
#include "stack.h"
#include "celt.h"
// *****************************************************************************
// MODULE:
//    $celt.decode_pulses32
//
// DESCRIPTION:
//  decode pulse(max 32 bits) vector into normalised bins
// INPUTS:
//  r4 = number of pulses
//  r3 = number of outputs
//  I7 = output buffer (size = r3)
// OUTPUTS:
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.decode_pulses32;
   .CODESEGMENT CELT_DECODE_PULSES32_PM;
   .DATASEGMENT DM;
   $celt.decode_pulses32:
   $push_rLink_macro;
   .VAR temp[4];
   .VAR jump_table[5]  = &n_1, &n_2, &n_3, &n_4, n_5;
   // save nr of pulses and bins
   M[temp + 0] = r4;
   M[temp + 1] = r3;

   // jump to proper function based on number of outputs
   // all can be processed using default (takes more cycles)
   r0 = M[r3 + (jump_table-1)];
   Null = r3 - 6;
   if POS jump default;
   Null = r3 - 1;
   if NEG call $error;
   jump r0;

   // -- process n = 1
   n_1:
      r0 = 1;
      M[$celt.dec.ec_dec.ftb] = r0;
      call $celt.ec_dec_bits;
      r4 = M[temp + 0];
      $celt.cwrsi1(r2, r0, r1)
      M[I7, 0] = r1;      
   jump end;

   // -- process n = 2
   n_2:
      $celt.ncwrs2(r4, r0)
      r1 = 0;
      call $celt.ec_dec_uint;
      r4 = M[temp + 0]; 
      r6 = r0;
      r7 = r1;
      call $celt.cwrsi2;
   jump end;

   // -- process n = 3
   n_3:
      $celt.ncwrs3(r4, r0, r1, decode_pulses32_n_3_lb1)
      call $celt.ec_dec_uint;
      r4 = M[temp + 0];
      r6 = r0;
      r7 = r1;
      call $celt.cwrsi3;
   jump end;

   // -- process n = 4
   n_4:
      $celt.ncwrs4(r4, r0, r1, r2, decode_pulses32_n_4_lb1)
      call $celt.ec_dec_uint;
      r4 = M[temp + 0];
      r6 = r0;
      r7 = r1;
      call $celt.cwrsi4;
   jump end;

   // -- process n = 5
   n_5:
      $celt.ncwrs5(r4, r0, r1, r2, decode_pulses32_n_5_lb1)
      call $celt.ec_dec_uint;
      r4 = M[temp + 0];
      r6 = r0;
      r7 = r1;
      call $celt.cwrsi5;
   jump end;

   // -- process n > 5
   default:
      M[temp + 2] = r5;
      push I7;
      r0 = M[r5 + $celt.dec.UVECTOR_FIELD];
      I7 = r0;//&$celt.dec.uvector;
      M[temp + 3] = r0;
      call $celt.ncwrs_urow;
      call $celt.ec_dec_uint;
      r4 = M[temp + 3];
      I5 = r4;
      #if defined(KAL_ARCH3) || defined(KAL_ARCH5)
         I7 = M[SP - 1];
      #else
         I7 = plook 0;
      #endif
      r4 = M[temp + 0]; 
      r3 = M[temp + 1]; 
      M3 = r3;
      r6 = r0;
      r7 = r1;
      call $celt.cwrsi;
      r5 = M[temp + 2];
      pop I7;
   end:
   r4 = M[temp + 0]; 
   r3 = M[temp + 1];
   jump $pop_rLink_and_rts;
   .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.decode_pulses
//
// DESCRIPTION:
//  decode pulse vector into normalized output bins
// INPUTS:
//  r4 = number of pulses
//  r3 = number of outputs
//  I7 = output buffer (size = r3)
// OUTPUTS:
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************  
.MODULE $M.celt.decode_pulses;
   .CODESEGMENT CELT_DECODE_PULSES_PM;
   .DATASEGMENT DM;
   $celt.decode_pulses:
   
   // zero output for zero pulses
   Null = r4;
   if NZ jump decode;
      r10 = r3;
      r0 = 0;
      I6 = I7;
      do zero_k_lp;
         M[I6, 1] = r0;
      zero_k_lp:
      rts;
   decode:
   $push_rLink_macro;
   // NOTE: no state should be below this point
   // does it fit into a 32-bit unsigned number?
   $celt.fits_in32(r3, r4, r0, decode_pulses_lb1, decode_pulses_lb2)
   if Z jump split_it;
         // yes, it does
         call $celt.decode_pulses32;
         jump $pop_rLink_and_rts;
  
   // No, it doesnt, 
   split_it:
      push I7;
      push r3;
      push r4;
  
      r1 = 0;
      r0 = r4 + 1;
      call $celt.ec_dec_uint;
      // r0 = count
      #if !defined(KAL_ARCH3) && !defined(KAL_ARCH5)
         r3 = plook 1;   
         r3 = r3 + 1;
         r3 = r3 LSHIFT -1;
         r4 = r0;
         call $celt.decode_pulses;
         r0 = plook 0;   
         r1 = plook 1;   
      #else
         r3 = M[SP - 2]; 
         r3 = r3 + 1;
         r3 = r3 LSHIFT -1;
         r4 = r0;
         call $celt.decode_pulses;
         r0 = M[SP - 1];    
         r1 = M[SP - 2];    
      #endif
      I7 = I7 + r3;
      r4 = r0 - r4;
      r3 = r1 - r3;
      call $celt.decode_pulses;
      pop r4;
      pop r3;
      pop I7;      
   jump $pop_rLink_and_rts;

   .ENDMODULE;

   
// *****************************************************************************
// MODULE:
//    $celt.encode_pulses
//
// DESCRIPTION:
//  
// INPUTS:
//  r4 = number of pulses
//  r3 = number of inputs
//  I7 = output buffer (size = r3)
// OUTPUTS:
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************  
.MODULE $M.celt.encode_pulses;
   .CODESEGMENT CELT_ENCODE_PULSES_PM;
   .DATASEGMENT DM;
   $celt.encode_pulses:
   // zero output for zero pulses
   Null = r4;
   if Z rts;
   $push_rLink_macro;
   // NOTE: no state should be below this point
   // does it fit into a 32-bit unsigned number?
   $celt.fits_in32(r3, r4, r0, encode_pulses_lb1, encode_pulses_lb2)
   if Z jump split_it;
   
   // yes, it does
   call $celt.encode_pulses32;
   jump $pop_rLink_and_rts;
  
   // No, it doesnt, 
   split_it:
      
      push I7;
      push r3;
      push r4;
      I6 = I7;
      r3 = r3 + 1;
      r3 = r3 LSHIFT -1;
      r10 = r3;
      r1 = 0, r0 = M[I6, 1];
      do calc_count_loop;
         Null = r0;
         if NEG r0 = -r0;
         r1 = r1 + r0, r0 = M[I6, 1];
      calc_count_loop:
      M[$celt.enc.ec_enc.fl + 1] = Null;
      M[$celt.enc.ec_enc.fl + 0] = r1;
      r4 = r4 + 1;
      M[$celt.enc.ec_enc.ft + 0] = r4;
      M[$celt.enc.ec_enc.ft + 1] = Null;
      push r1;
      push r3;
      call $celt.ec_enc_uint;
      pop r3;
      pop r4;
      call $celt.encode_pulses;
      
    #if !defined(KAL_ARCH3) && !defined(KAL_ARCH5)
      r0 = plook 0;   
      r1 = plook 1;   
    #else
      r0 = M[SP - 1];
      r1 = M[SP - 2];
    #endif
   
      I7 = I7 + r3;
      r4 = r0 - r4;
      r3 = r1 - r3;
      call $celt.encode_pulses;
      pop r4;
      pop r3; 
      pop I7;
   jump $pop_rLink_and_rts;

   .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.cwrsi2
//
// DESCRIPTION:
//   returns a vector of pulses (from a set with size = 2) 
//
// INPUTS:
//    r4 = element number
//    r7:r6: combination index
//    I7 = buffer to write to (size = 2)
// OUTPUTS:
//   None
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.cwrsi2;
   .CODESEGMENT CELT_CWRSI2_PM;
   .DATASEGMENT DM;
   $celt.cwrsi2:
   r0 = r4 + 1;
   $celt.ucwrs2(r0, r3)
   Null = r6 - r3;
   Null = r7 - Borrow;
   if NEG r3 = 0;
   r6 = r6 - r3;
   r2 = r6 + 1;
   r2 = r2 LSHIFT -1; 
   $celt.ucwrs2(r2, r1)
   r0 = r4 - r2;
   Null = r3;
   if NZ r0 = -r0;
   r6 = r6 - r1, M[I7, 1] = r0;
   $celt.cwrsi1(r2, r6, r3)
   M[I7, -1] = r3;  
   rts;
 .ENDMODULE; 

// *****************************************************************************
// MODULE:
//    $celt.cwrsi3
//
// DESCRIPTION:
//   returns a vector of pulses (from a set with size = 3) 
//
// INPUTS:
//    r4 = element number
//    r7:r6: combination index
//    I7 = buffer to write to (size = 3)
// OUTPUTS:
//   None
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.cwrsi3;
   .CODESEGMENT CELT_CWRSI3_PM;
   .DATASEGMENT DM;
  $celt.cwrsi3:
   // push rLink onto stack
   $push_rLink_macro; 
  .VAR tmp[3];
 
   r3 = r4 + 1;
   $celt.ucwrs3(r3, r0, r1,  cwrsi3_lbl1)
   M[tmp + 0]  = r0;
   M[tmp + 1]  = r1;
   M[tmp + 2]  = r4; 
   M0 = 0;
   Null = r6 - r0;
   Null = r7 - r1 - borrow;
   if NEG jump chng1_end;
      M0 = 1;
      r6 = r6 - r0;
      r7 = r7 - r1 - borrow;
   chng1_end:
   r2 = 0;
   Null = r6 - 1;
   Null = r7 - r1 - borrow;
   if NEG jump chng2_end;
      r0 = r6 + r6;
      r1 = r7 + r7 + Carry;
      r0 = r0 - 1;
      r1 = r1 - Borrow;
      M1 = r7;
      $celt.ISQRT32(cwrsi3_lbl2, cwrsi3_lbl3)
      r2 = r2 + 1;
      r2 = r2 LSHIFT -1;
      r7 = M1;
   chng2_end:
   $celt.ucwrs3(r2, r0, r1,  cwrsi3_lbl4)  
   r6 = r6 - r0;
   r7 = r7 - r1 - borrow;
   r0 = r2 - M[tmp + 2];
   Null = M0;
   if Z r0 = -r0;
   M[I7, 1] = r0;
   r4 = r2;
   call $celt.cwrsi2;
   r0 = M[I7, -1];
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.cwrsi4
//
// DESCRIPTION:
//   returns a vector of pulses (from a set with size = 4) 
//
// INPUTS:
//    r4 = element number
//    r7:r6: combination index
//    I7 = buffer to write to (size = 4)
// OUTPUTS:
//   None
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.cwrsi4;
   .CODESEGMENT CELT_CWRSI4_PM;
   .DATASEGMENT DM;
   $celt.cwrsi4:
   // push rLink onto stack
   $push_rLink_macro; 
   .VAR tmp[3];
   r3 = r4 + 1;
   $celt.ucwrs4(r3, r0, r1, r2, cwrsi4_lbl1)
   M[tmp + 0]  = r0;
   M[tmp + 1]  = r1;
   M[tmp + 2]  = r4; 
   M0 = 0;
   Null = r6 - r0;
   Null = r7 - r1 - borrow;
   if NEG jump chng1_end;
      M0 = 1;
      r6 = r6 - r0;
      r7 = r7 - r1 - borrow;
   chng1_end:  
   r10 = 0;
   r8 = r4;
   cwrsi4_loop1:
      r4 = r10 + r8;
      r4 = r4 LSHIFT -1;
      $celt.ucwrs4(r4, r0, r1, r2, cwrsi4_lbl2)
      r2 = r6 - r0;
      r3 = r7 - r1 - Borrow;
      if NEG jump pos_part;
         r2 = r3 OR r2;
         if Z jump cwrsi4_loop1_end;
         Null = r4 - r8;
         if POS jump cwrsi4_loop1_end;
         r10 = r4 + 1;
      jump cwrsi4_loop1; 
      pos_part:
          r8 = r4 - 1;
   jump cwrsi4_loop1;  
   cwrsi4_loop1_end:
  
   r6 = r6 - r0;
   r7 = r7 - r1 - borrow;
   r0 = r4 - M[tmp + 2];
   Null = M0;
   if Z r0 = -r0;
   M[I7, 1] = r0;
   call $celt.cwrsi3;
   r0 = M[I7, -1];
   jump $pop_rLink_and_rts;
.ENDMODULE;

 
// *****************************************************************************
// MODULE:
//    $celt.cwrsi5
//
// DESCRIPTION:
//   returns a vector of pulses (from a set with size = 5) 
//
// INPUTS:
//    r4 = element number
//    r7:r6: combination index
//    I7 = buffer to write to (size = 5)
// OUTPUTS:
//   None
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.cwrsi5;
   .CODESEGMENT CELT_CWRSI5_PM;
   .DATASEGMENT DM;
  $celt.cwrsi5:
     // push rLink onto stack
   $push_rLink_macro; 
   .VAR tmp[3];
   r3 = r4 + 1;
   $celt.ucwrs5(r3, r0, r1, r2, cwrsi5_lbl1)
   M[tmp + 0]  = r0;
   M[tmp + 1]  = r1;
   M[tmp + 2]  = r4; 
   
   M0 = 0;
   Null = r6 - r0;
   Null = r7 - r1 - borrow;
   if NEG jump chng1_end;
      M0 = 1;
      r6 = r6 - r0;
      r7 = r7 - r1 - borrow;
   chng1_end:  
   r10 = 0;
   r8 = r4;
   cwrsi5_loop1:
      r4 = r10 + r8;
      r4 = r4 LSHIFT -1;
      $celt.ucwrs5(r4, r0, r1, r2, cwrsi5_lbl2)
      r2 = r6 - r0;
      r3 = r7 - r1 - Borrow;
      if NEG jump pos_part;
         r2 = r3 OR r2;
         if Z jump cwrsi5_loop1_end;
         Null = r4 - r8;
         if POS jump cwrsi5_loop1_end;
         r10 = r4 + 1;
      jump cwrsi5_loop1; 
      pos_part:
         r8 = r4 - 1;
   jump cwrsi5_loop1;  
   
   cwrsi5_loop1_end:
   r6 = r6 - r0;
   r7 = r7 - r1 - borrow;
   r0 = r4 - M[tmp + 2];
   Null = M0;
   if Z r0 = -r0;
   M[I7, 1] = r0;
   call $celt.cwrsi4;
   r0 = M[I7, -1];
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.uprev
//
// DESCRIPTION:
//  computes previous row
// INPUTS:
//    r10 = row number
//    r3:r2: curren row
//    I3 = u
// OUTPUTS:
//   None
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.uprev;
   .CODESEGMENT CELT_UPREV_PM;
   .DATASEGMENT DM;
  $celt.uprev:
  I2 = I3;
  M0 = 1;
  r10 = r10 - 1;
  r0 = M[I2, M0]; //0 ->1
  r1 = M[I2, M0]; //1 ->0
  r4 = M[I2, M0];  //2->3
  r5 = M[I2, M0];  //3->0
  do uprev_loop;
     r6 = r4 - r0;
     r7 = r5 - r1 - Borrow;
     r2 = r6 - r2, M[I3, M0] = r2;
     r3 = r7 - r3 - Borrow, M[I3, M0] = r3; 
     r0 = r4, r4 = M[I2, M0];
     r1 = r5,  r5 = M[I2, M0];     
  uprev_loop:
  M[I3, M0] = r2;
  M[I3, M0] = r3;  
  rts;
 .ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.unext
//
// DESCRIPTION:
//  computes next row
// INPUTS:
//    r10 = row number
//    r3:r2: curren row
//    I3 = u
// OUTPUTS:
//   None
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.unext;
   .CODESEGMENT CELT_UNEXT_PM;
   .DATASEGMENT DM;
  $celt.unext:
  I2 = I3;
  M0 = 1;
  r10 = r10 - 1;
  r0 = M[I2, M0]; //0 ->1
  r1 = M[I2, M0]; //1 ->0
  r4 = M[I2, M0];  //2->3
  r5 = M[I2, M0];  //3->0
  do unext_loop;
     r6 = r4 + r0;
     r7 = r5 + r1 + Carry;
     r2 = r6 + r2, M[I3, M0] = r2;
     r3 = r7 + r3 + Carry, M[I3, M0] = r3; 
     r0 = r4, r4 = M[I2, M0];
     r1 = r5,  r5 = M[I2, M0];     
  unext_loop:
  M[I3, M0] = r2;
  M[I3, M0] = r3;  
  rts;
 .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.cwrsi
//
// DESCRIPTION:
//   returns a vector of pulses (from a set with size = n) 
//
// INPUTS:
// OUTPUTS:
//   None
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.cwrsi;
   .CODESEGMENT CELT_CWRSI_PM;
   .DATASEGMENT DM;
   $celt.cwrsi:
   //r4 = k
   //I7 = y
   //I5 = u (32 bit
   //M3 = n
   $push_rLink_macro; 
#if !defined(KAL_ARCH3) && !defined(KAL_ARCH5)
   .VAR temp_stk[5];
#endif
   r8 = I5 + r4;
   r8 = r8 + r4;
   M2 = 1;
   M1 = -3;
   cwrsi_loop:
      r0 = M[r8 + 2];
      r1 = M[r8 + 3];
      M0 = 0;
      Null = r6 - r0;
      Null = r7 - r1 - borrow;
      if NEG jump chng1_end;
         M0 = 1;
         r6 = r6 - r0;
         r7 = r7 - r1 - borrow;
      chng1_end:
      r0 = M[r8 + 0];
      r1 = M[r8 + 1];
      I2 = r8 - 2;
      cwrsi_loop2:
        r2 = r6 - r0, r0 = M[I2, M2];
        r3 = r7 - r1 - borrow, r1 = M[I2, M1];
      if NEG jump cwrsi_loop2;
      r8 = I2 + 4;
      r6 = r2;
      r7 = r3;
      r3 = r8 - I5;
      r3 = r3 LSHIFT -1;
      r4 = r4 - r3;
      Null = M0;
      if NZ r4 = -r4;
      M[I7, 1] = r4;
      r4 = r3;
      r10 = r4 + 2;
      r3 = 0;
      r2 = 0;
      I3 = I5;
#if defined(KAL_ARCH3) || defined(KAL_ARCH5)
      pushm <r0, r1, r4, r6, r7>;
      call $celt.uprev;
      popm <r0, r1, r4, r6, r7>;
#else
      M[temp_stk + 0] = r4;
      M[temp_stk + 1] = r1;
      M[temp_stk + 2] = r6;
      M[temp_stk + 3] = r7;
      M[temp_stk + 4] = r0;
      call $celt.uprev;
      r4 = M[temp_stk + 0];
      r1 = M[temp_stk + 1];
      r6 = M[temp_stk + 2];
      r7 = M[temp_stk + 3];
      r0 = M[temp_stk + 4];
#endif  // defined(KAL_ARCH3) || defined(KAL_ARCH5)
     M3 = M3 - 1;  

   if NZ jump cwrsi_loop;


   jump $pop_rLink_and_rts;
 .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ncwrs_urow
//
// DESCRIPTION:
//
// INPUTS:
// OUTPUTS:
//   None
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.ncwrs_urow;
   .CODESEGMENT CELT_NCWRS_UROW_PM;
   .DATASEGMENT DM;
   $celt.ncwrs_urow:
   $push_rLink_macro; 
   //static celt_uint32 ncwrs_urow(unsigned _n,unsigned _k,celt_uint32 *_u){
   //I7 = u(32 bit)
   //r4 = k
   //r3 = n
   //len=_k+2;
   .VAR temp[4];
   I6 = I7 + r4;
   I6 = I6 + r4;
   r8 = I7;
   M3 = r4 + 2;
   M[r8 + 0] = Null;
   M[r8 + 1] = Null;
   r0 = 1;
   M[r8 + 2] = r0;
   M[r8 + 3] = Null;
  
   Null = r3 - 7;
   if NEG jump path1;
   Null = r4 - 256;
   if POS jump path1;
   path2: /*n>6 && k<=255*/
      r0 = r3 + r3;
      r0 = r0 - 1;
      M[r8 + 4] = r0;
      r1 = 0;
      M[r8 + 5] = r1;
      M3 = r4 + -1;
      if LE jump end;
      I3 = r8 + 6;
      r4 = 1;
      r5 = 0;
      r2 = r0;
      r3 = r1;
      M[temp + 0] = r2;  //UM1
      M[temp + 1] = r3;  //uM1
      M[temp + 2] = r4;  //um2
      M[temp + 3] = r5;  //um2
      r10 = 2; //is not a do loop
      I2 = &temp + 2;
      M2 = 1; 
      path2_unext_loop:
         r4 = M[I2, 1];                //um2 2 ->3
         r5 = M[I2, -1];               //um2 3->2
         call $celt.imusdiv32;
         r2 = r2 + r4;          
         r3 = r3 + r5 + Carry, M[I2, 1] = r2; //um2 2 ->3
         M[I2, -1] = r3;                       //um2 3 ->2
         r10 = r10 + M2, M[I3, 1] = r2;
         M3 = M3 - M2, M[I3, 1] = r3;
         if Z jump end;
         r5 = M[I2, -1];               //2->1 dummy
         r5 = M[I2, -1];               //um1 1->0
         r4 = M[I2, 0];                //um1 0->0 
         call $celt.imusdiv32;
         
         r2 = r2 + r4;          
         r3 = r3 + r5 + Carry, M[I2, 1] = r2;  //um2 0 ->1
         M[I2, 1] = r3;                        //um2 1 ->2
         r10 = r10 + M2, M[I3, 1] = r2;
         M3 = M3 - M2, M[I3, 1] = r3;
      if NZ jump path2_unext_loop;
      jump end;
   path1: /*n<=6 || k>255*/
      r10 = r4 - 1; 
      I3 = r8 + 4;
      r0 = 3;
      r1 = 2;
      r2 = 0;
      do set_uk_2_plus_loop;
         r0 = r0 + r1, M[I3, 1] = r0;
         M[I3, 1] = r2;
      set_uk_2_plus_loop:
      M[I3, 1] = r0;
      M[I3, 2] = r2;
      M3 = r3 - 2;
      M2 = r4 + 1;
      path1_unext_loop:
         r10 = M2;
         r3 = 0;
         r2 = 1;
         I3 = I7 + 2;
         call $celt.unext;
         M3 = M3 - 1;
      if NZ jump path1_unext_loop;
   end:
   r0 = M[I6, 1];
   r1 = M[I6, 1];
   r2 = M[I6, 1];
   r3 = M[I6, 1];
   r0 = r0 + r2;
   r1 = r1 + r3 + Carry;
  jump $pop_rLink_and_rts;
.ENDMODULE;  
 

// *****************************************************************************
// MODULE:
//    $celt.alg_unquant
//
// DESCRIPTION:
//    algebric unquntiser
//
// INPUTS:
//  r5 = pointer to decoder structure
//  I5 = output buffer
//  r4 = nrof pulses
//  r3 = nr of outputs
//  M0 = spread flag
// OUTPUTS:
//
// TRASHED REGISTERS:
//    
// *****************************************************************************
.MODULE $M.celt.alg_unquant;
   .CODESEGMENT CELT_ALG_UNQUANT_PM;
   .DATASEGMENT DM;
   $celt.alg_unquant:
   $push_rLink_macro;
 
   r0 = M0;
  .VAR temp[4];
   M[temp + 0] = r0;
   r0 = I5;
   M[temp + 1] = r0;
   M[temp + 2] = r3;
   $celt.get_pulses(r4, r1, get_pulses_lbl1)
   M[temp + 3] = r4;

   r0 = M[r5 + $celt.dec.ALG_UNQUANT_ST_FIELD];
   I7 = r0;
   call  $celt.decode_pulses;
   r3 = M[temp + 2];
   r4 = M[temp + 3];
   
   // calc enrgy of output
   r10 = r3 - 1;
   r0 = M[r5 + $celt.dec.ALG_UNQUANT_ST_FIELD];
   I7 = r0;
   rMAC = 0, r0 = M[I7, 1];
   do calc_en_lp;
      rMAC = rMAC + r0 * r0, r0 = M[I7, 1];
   calc_en_lp:
   rMAC = rMAC + r0 * r0;
   
   // normalise residual
   r0 = M[temp + 1];
   I5 = r0;
   r0 = M[r5 + $celt.dec.ALG_UNQUANT_ST_FIELD];
   I7 = r0;
   call $celt.normalise_residual;
   Null = M[temp + 0];
   if Z jump end;
   
   // rotation if required
   r6 = M[temp];
   r0 = M[temp + 1];
   I5 = r0;
   r3 = M[temp + 2];
   r4 = M[temp + 3];
   r7 = -1;
   call $celt.exp_rotation;
   end:
   jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $celt.icwrs2
//
// DESCRIPTION:
//
// INPUTS:
//    I7 = buffer to write to (size = 2)
// OUTPUTS:
//    r4 = element number
//    r6 = index
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.icwrs2;
   .CODESEGMENT CELT_ICWRS2_PM;
   .DATASEGMENT DM;
   $celt.icwrs2:
   I7 = I7 + 1;
   r0 = M[I7, -1];
   $celt.icwrs1(r0, r4, r6)
   $celt.ucwrs2(r4, r0)
   r6 = r6 + r0, r1 = M[I7, 0];
   Null = r1;
   if POS jump end;
      r4 = r4 - r1;
      r0 = r4 + 1;
      $celt.ucwrs2(r0, r2)
      r6 = r6 + r2;
      rts;
   end:
   r4 = r4 + r1;
   rts;
 .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.icwrs3
//
// DESCRIPTION:
//
// INPUTS:
//    I7 = buffer to write to (size = 3)
// OUTPUTS:
//    r4 = element number
//    r7:r6 = index
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.icwrs3;
   .CODESEGMENT CELT_ICWRS3_PM;
   .DATASEGMENT DM;
   $celt.icwrs3:
   $push_rLink_macro;
   I7 = I7 + 1;
   call $celt.icwrs2;
   I7 = I7 - 1;
   $celt.ucwrs3(r4, r0, r1, icwrs3_lbl1)
   r6 = r6 + r0, r2 = M[I7, 0];
   r7 = r1 + Carry;
   Null = r2;
   if POS jump end;
      r4 = r4 - r2;
      r0 = r4 + 1;
      $celt.ucwrs3(r0, r1, r2, icwrs3_lbl2)
      r6 = r6 + r1;
      r7 = r7 + r2 + Carry;
      jump $pop_rLink_and_rts;
   end:
   r4 = r4 + r2;
   jump $pop_rLink_and_rts;
 .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.icwrs4
//
// DESCRIPTION:
//
// INPUTS:
//    I7 = buffer to write to (size = 4)
// OUTPUTS:
//    r4 = element number
//    r7:r6 = index
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.icwrs4;
   .CODESEGMENT CELT_ICWRS4_PM;
   .DATASEGMENT DM;
   $celt.icwrs4:
   $push_rLink_macro;
   I7 = I7 + 1;
   call $celt.icwrs3;
   I7 = I7 - 1;
   $celt.ucwrs4(r4, r0, r1, r2, icwrs4_lbl1)
   r6 = r6 + r0, r2 = M[I7, 0];
   r7 = r1 + Carry;
   Null = r2;
   if POS jump end;
      r4 = r4 - r2;
      r0 = r4 + 1;
      $celt.ucwrs4(r0, r1, r2, r3, icwrs4_lbl2)
      r6 = r6 + r1;
      r7 = r7 + r2 + Carry;
      jump $pop_rLink_and_rts;
   end:
   r4 = r4 + r2;
   jump $pop_rLink_and_rts;
 .ENDMODULE;
 // *****************************************************************************
// MODULE:
//    $celt.icwrs5
//
// DESCRIPTION:
//
// INPUTS:
//    I7 = buffer to write to (size = 5)
// OUTPUTS:
//    r4 = element number
//    r7:r6 = index
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.icwrs5;
   .CODESEGMENT CELT_ICWRS5_PM;
   .DATASEGMENT DM;
   $celt.icwrs5:
   $push_rLink_macro;
   I7 = I7 + 1;
   call $celt.icwrs4;
   I7 = I7 - 1;
   $celt.ucwrs5(r4, r0, r1, r2, icwrs5_lbl1)
   r6 = r6 + r0, r2 = M[I7, 0];
   r7 = r1 + Carry;
   Null = r2;
   if POS jump end;
      r4 = r4 - r2;
      r0 = r4 + 1;
      $celt.ucwrs5(r0, r1, r2, r3, icwrs5_lbl2)
      r6 = r6 + r1;
      r7 = r7 + r2 + Carry;
      jump $pop_rLink_and_rts;
   end:
   r4 = r4 + r2;
   jump $pop_rLink_and_rts;
 .ENDMODULE;
 
 // *****************************************************************************
// MODULE:
//    $celt.icwrs5
//
// DESCRIPTION:
//Returns the index of the given combination of K elements chosen from a set
//   of size _n with associated sign bits.
// INPUTS:
//    I7 = buffer to read from
//    I5 = uvector (32 bit)
//    r4 = 
//    r3 = n
// OUTPUTS:
//    r7:r6 = index
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.icwrs;
   .CODESEGMENT CELT_ICWRS_PM;
   .DATASEGMENT DM;
   $celt.icwrs:
   $push_rLink_macro;
#if !defined(KAL_ARCH3) && !defined(KAL_ARCH5)
   .VAR temp[2];
#endif
   I2 = I5;
   M0 = 1;
   r2 = 0;
   r10 = r4, M[I2, M0] = r2;
   r0 = M0, M[I2, M0] = r2;
   r1 = r0 + r0, M[I2, M0] = r0;
   do init_u_loop;
      r0 = r0 + r1, M[I2, M0] = r2;      
      M[I2, M0] = r0;
   init_u_loop:
   I7 = I7 - 1;
   I7 = I7 + r3, M[I2, M0] = r2;
   r2 = M[I7, -1];
   $celt.icwrs1(r2, r8, r6)
   r8 = r8 + r8;
   r8 = I5 + r8;
   r0 = M[r8 + 0];
   r6 = r6 + r0;
   r7 = 0, r0 = M[I7, -1];
   r1  = r0 + r0;   
   if POS jump index_up;
      r1 = -r1;
      r2 = r1 + 2;
      r0 = M[r8 + r2];
      r6 = r6 + r0;
   index_up:
   r8 = r8 + r1;
   M3 = r3 - 2;
   M1 = r4 + 2;
   index_up_loop:
       r2 = 0;
       r3 = 0;
       r10 = M1;
       I3 = I5;
#if defined(KAL_ARCH3) || defined(KAL_ARCH5)
       pushm<r6, r7>;
       call $celt.unext;
       popm<r6, r7>;
#else       
       M[temp + 0] = r6;
       M[temp + 1] = r7;
       call $celt.unext;
       r6 = M[temp + 0];
       r7 = M[temp + 1];
#endif
       r0 = M[r8 + 0];
       r1 = M[r8 + 1];
       r6 = r6 + r0;
       r7 = r7 + r1 + Carry, r5 = M[I7, -1];
       r5 = r5 + r5;
       if POS jump end_update;
          r5 = -r5;
          r2 = r5 + 2;
          r0 = M[r8 + r2];
          r2 = r2 + 1;
          r1 = M[r8 + r2];
          r6 = r6 + r0;
          r7 = r7 + r1 + Carry;   
       end_update:
       r8 = r8 + r5;
       M3 = M3 - 1;  //1
  if NZ jump index_up_loop;
  r0 = M[r8 + 0];
  r1 = M[r8 + 1];
  r2 = M[r8 + 2];
  r3 = M[r8 + 3];  
  r0 = r0 + r2;
  r1 = r1 + r3 + Carry;
  jump $pop_rLink_and_rts;
 .ENDMODULE;
 
// *****************************************************************************
// MODULE:
//    $celt.encode_pulses32
//
// DESCRIPTION:
// INPUTS:
//  r4 = number of pulses
//  r3 = number of outputs
//  I7 = input buffer (size = r3)
// OUTPUTS:
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.encode_pulses32;
   .CODESEGMENT CELT_ENCODE_PULSES32_PM;
   .DATASEGMENT DM;
   $celt.encode_pulses32:
   $push_rLink_macro;
   .VAR jump_table[5]  = &n_1, &n_2, &n_3, &n_4, n_5;
   // save nr of pulses and bins
#if defined(KAL_ARCH3) || defined(KAL_ARCH5)
   pushm<r3, r4, r5>;
#else
   .VAR temp[4];
   M[temp + 0] = r4;
   M[temp + 1] = r3;
   M[temp + 2] = r5;
#endif

   push I7;
   // jump to proper function based on number of outputs
   // all can be processed using default (takes more cycles)
   r0 = M[r3 + (jump_table-1)];
   Null = r3 - 6;
   if POS jump default;
   Null = r3 - 1;
   if NEG call $error;
   jump r0;
   
   // -- process n = 1
   n_1:
      r0 = M[I7, 0];
      $celt.icwrs1(r0, r4, r6)
      r0 = 1;
      M[$celt.enc.ec_enc.ftb] = r0;
      M[$celt.enc.ec_enc.fl + 0] = r6;
      M[$celt.enc.ec_enc.fl + 1] = NULL;
      call $celt.ec_enc_bits;      
   jump $pop_rLink_and_rts;
   
   // -- process n = 2
   n_2:
      call $celt.icwrs2;
      $celt.ncwrs2(r4, r0)
      r1 = 0;
      r7 = 0;
   jump end;
   
   // -- process n = 3
   n_3:
      call $celt.icwrs3;
      $celt.ncwrs3(r4, r0, r1, encode_pulses32_n_3_lb1)
   jump end;
   
   // -- process n = 4
   n_4:
      call $celt.icwrs4;
      $celt.ncwrs4(r4, r0, r1, r2, encode_pulses32_n_4_lb1)
   jump end;
   
   // -- process n = 5
   n_5:
      call $celt.icwrs5;
      $celt.ncwrs5(r4, r0, r1, r2, decode_pulses32_n_5_lb1)
   jump end;

   // -- process n > 5
   default:
      r0 = M[r5 + $celt.enc.UVECTOR_FIELD];
      I5 = r0;
      call $celt.icwrs;
   end:
      M[$celt.enc.ec_enc.ft + 0] = r0;
      M[$celt.enc.ec_enc.ft + 1] = r1;
      M[$celt.enc.ec_enc.fl + 0] = r6;
      M[$celt.enc.ec_enc.fl + 1] = r7;
      call $celt.ec_enc_uint;  
      
      pop I7;
#if defined(KAL_ARCH3) || defined(KAL_ARCH5)
      popm<r3, r4, r5>;
#else
      r5 = M[temp + 2];
      r4 = M[temp + 0];
      r3 = M[temp + 1];
#endif

   jump $pop_rLink_and_rts;
   .ENDMODULE;
#endif

