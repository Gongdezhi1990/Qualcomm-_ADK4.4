// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_RANGE_DEC
#define CELT_RANGE_DEC
#include "stack.h"
#include "celt.h"
// *****************************************************************************
// MODULE:
//    $celt.ec_dec_init
//
// DESCRIPTION:
//    initialise entropy decoder
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_dec_init;
   .CODESEGMENT CELT_EC_DEC_INIT_PM;
   .DATASEGMENT DM;

   $celt.ec_dec_init:
   
   // push rLink onto stack
   $push_rLink_macro;
   
   // get rem
   call $celt.get1byte;
   M[$celt.dec.ec_dec.rem] = r1;
   
   // init rng
   r2 = 1<<$celt.EC_CODE_EXTRA;
   M[$celt.dec.ec_dec.rng] = r2;
   M[$celt.dec.ec_dec.rng + 1] = 0;
   
   // init diff
   r1 = r1 LSHIFT (-$celt.EC_SYM_BITS+$celt.EC_CODE_EXTRA);
   r1 = r2 - r1;
   r2 = Null - Null -borrow;
   M[$celt.dec.ec_dec.dif] = r1;
   M[$celt.dec.ec_dec.dif + 1] = r2;   
  
   // Normalise the interval
   call $celt.ec_dec_normalise;
 
   // reset bits reading from end of buffer
   M[$celt.dec.ec_dec.end_bits_left] = Null;
   M[$celt.dec.ec_dec.nb_end_bits] = Null;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_dec_normalise
//
// DESCRIPTION:
//    entropy decoder normalise, rescale the range if its too small
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5/I0/I1
// *****************************************************************************
.MODULE $M.celt.ec_dec_normalise;
   .CODESEGMENT CELT_EC_DEC_NORMALISE_PM;
   .DATASEGMENT DM;

   $celt.ec_dec_normalise:
   // push rLink onto stack
   $push_rLink_macro;
   
   // rng=r6:r4
   r4 = M[$celt.dec.ec_dec.rng + 0];
   r6 = M[$celt.dec.ec_dec.rng + 1];
   
   // rem = rMAC
   rMAC = M[$celt.dec.ec_dec.rem];
   
   // dif = r8:r7
   r7 = M[$celt.dec.ec_dec.dif + 0];
   r8 = M[$celt.dec.ec_dec.dif+1];
   retry:
      // see if range is still small
      r0 = r4 - ($celt.EC_CODE_BOT+1);
      r0 = r6 - Null - borrow;
      if POS jump end;
         // update range
         r0 = r4 LSHIFT -16;
         r4 = r4 LSHIFT 8;
         r6 = r6 LSHIFT 8;
         r6 = r6 + r0;
         
         // read next byte from input buffer
         call $celt.get1byte;
         
         // use the ramining bits
         rMAC = rMAC LSHIFT $celt.EC_CODE_EXTRA;
         rMAC = rMAC AND $celt.EC_SYM_MAX;
         r0 = r1 LSHIFT ($celt.EC_CODE_EXTRA-$celt.EC_SYM_BITS);
         rMAC = rMAC OR r0;
         r8 = r7 LSHIFT -16;
         r7 = r7 LSHIFT 8;      
         r7 = r7 - rMAC;
         r8 = r8 - Null - borrow;
         r8 = r8 AND 0xFF;
         r0 = r8 - 0x80;
         if POS r8 = r0;
         rMAC = r1;      
   jump retry;   
   end:
   
   // rng = r6:r4
   M[$celt.dec.ec_dec.rng + 0] = r4;
   M[$celt.dec.ec_dec.rng + 1] = r6;
   
   // rem = rMAC
   M[$celt.dec.ec_dec.rem] = rMAC;
   
   // dif = r8:r7
   M[$celt.dec.ec_dec.dif + 0] = r7;
   M[$celt.dec.ec_dec.dif+1] = r8;
   
    // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_decode
//
// DESCRIPTION:
//   entropy decode funtion
//
// INPUTS:
//  r1:r0 32-bit unsigned, total freq next symbol has been encoded with
// OUTPUTS:
//  -r1:r0 32-bit unsigned, cumulative rate of the next symbol
//
// TRASHED REGISTERS:
//   TODO
// *****************************************************************************
.MODULE $M.celt.ec_decode;
   .CODESEGMENT CELT_EC_DECODE_PM;
   .DATASEGMENT DM;
   $celt.ec_decode:
   // push rLink onto stack
   $push_rLink_macro;  
   //ft = r0:r0
   M[$celt.dec.ec_dec.ft + 0] = r0;
   M[$celt.dec.ec_dec.ft + 1] = r1;
   r2 = r0;
   r3 = r1;
   r0 = M[$celt.dec.ec_dec.rng + 0];
   r1 = M[$celt.dec.ec_dec.rng + 1];
   call $celt.idiv32;
   // label for jumping from $celt.ec_decode_bin
   $celt.ec_decode.bin_jump:
   // save norm = rng/inp
   M[$celt.dec.ec_dec.nrm + 0] = r6;
   M[$celt.dec.ec_dec.nrm + 1] = r7;
   r2 = r6;
   r3 = r7;
   r0 = M[$celt.dec.ec_dec.dif + 0];
   r1 = M[$celt.dec.ec_dec.dif + 1];
   r0 = r0 - 1;
   r1 = r1 - borrow;
   call $celt.idiv32;
   r2 = r6 + 1;
   r3 = r7 + carry;
   r0 = M[$celt.dec.ec_dec.ft + 0];
   r1 = M[$celt.dec.ec_dec.ft + 1];
   r0 = r0 - r2;
   r1 = r1 - r3 - borrow;
   if POS jump end;
     r0 = 0;
     r1 = 0;
   end:
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_decode_bin
//
// DESCRIPTION:
//   same as ec_decode for ft = power of two cases
//
// INPUTS:
//  -none(see Notes)
// OUTPUTS:
//  -r1:r0 32-bit unsigned, cumulative rate of the next symbol
//
// TRASHED REGISTERS:
//   TODO
// NOTES:
//  at the moment hardcoded for 2^15, as only this case is used in the decoder
// *****************************************************************************
.MODULE $M.celt.ec_decode_bin;
   .CODESEGMENT CELT_EC_DECODE_BIN_PM;
   .DATASEGMENT DM;
   $celt.ec_decode_bin:
   $push_rLink_macro;
   r0 = M[$celt.dec.ec_dec.rng + 0];
   r1 = M[$celt.dec.ec_dec.rng + 1];
   r0 = r0 LSHIFT -15;
   r1 = r1 LSHIFT (24-15);
   r6 = r0 + r1;
   r0 = 32768;
   M[$celt.dec.ec_dec.ft + 0] = r0;
   M[$celt.dec.ec_dec.ft + 1] = Null;
   r7 = 0;
   jump $celt.ec_decode.bin_jump;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.ec_dec_update
//
// DESCRIPTION:
//   post decoding update
//
// INPUTS:
//  none
// OUTPUTS:
//  none
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.ec_dec_update;
   .CODESEGMENT CELT_EC_DEC_UPDATE_PM;
   .DATASEGMENT DM;
$celt.ec_dec_update:
  
   // push rLink onto stack
   $push_rLink_macro;
   
   r0 = M[$celt.dec.ec_dec.ft + 0];
   r1 = M[$celt.dec.ec_dec.ft + 1];
   r0 = r0 -  M[$celt.dec.ec_dec.fh + 0];
   r1 = r1 -  M[$celt.dec.ec_dec.fh + 1] -borrow;
   r2 = M[$celt.dec.ec_dec.nrm + 0];
   r3 = M[$celt.dec.ec_dec.nrm + 1];
   
   //IMUL32 , TODO:BC7OPT
   rMAC = r0*r2(UU);
   r6 = rMAC LSHIFT 23;
   rMAC0 = rMAC1;
   rMAC12 = rMAC2(ZP);
   rMAC = rMAC + r1*r2(SU);
   rMAC = rMAC + r3*r0(SU);
   r7 = rMAC LSHIFT 23;

   //update dif
   r0 = M[$celt.dec.ec_dec.dif + 0];
   r1 = M[$celt.dec.ec_dec.dif + 1];
   M[$celt.dec.ec_dec.dif + 0] = r0 - r6;
   M[$celt.dec.ec_dec.dif + 1] = r1 - r7 -borrow;  
   
   // update rng
   r0 = M[$celt.dec.ec_dec.fl + 0];
   r1 = M[$celt.dec.ec_dec.fl + 1];
   NULL = r1 OR r0;
   if NZ jump calc_rng_norm;
      r0 = M[$celt.dec.ec_dec.rng + 0];
      r1 = M[$celt.dec.ec_dec.rng + 1];
      M[$celt.dec.ec_dec.rng + 0] = r0 - r6;
      M[$celt.dec.ec_dec.rng + 1] = r1 - r7 - borrow;
      jump norm_dec;
   calc_rng_norm:
   r0 = M[$celt.dec.ec_dec.fh + 0];
   r1 = M[$celt.dec.ec_dec.fh + 1];
   r0 = r0 -  M[$celt.dec.ec_dec.fl + 0];
   r1 = r1 -  M[$celt.dec.ec_dec.fl + 1] -borrow;
   
   //IMUL32 , TODO:BC7OPT
   rMAC = r0*r2(UU);
   r6 = rMAC LSHIFT 23;
   rMAC0 = rMAC1;
   rMAC12 = rMAC2(ZP);
   rMAC = rMAC + r1*r2(SU);
   rMAC = rMAC + r3*r0(SU);
   r7 = rMAC LSHIFT 23;
   
   //IMUL32
   M[$celt.dec.ec_dec.rng + 0] = r6;
   M[$celt.dec.ec_dec.rng + 1] = r7;   
   norm_dec:
   // normalise
   call $celt.ec_dec_normalise;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.ec_dec_bits
//
// DESCRIPTION:
//   decoding a number of bits
//
// INPUTS:
//  M[$celt.dec.ec_dec.ftb] -> number of bits
// OUTPUTS:
//  r1:r0 -> 32 bits
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.ec_dec_bits;
   .CODESEGMENT CELT_EC_DEC_BITS_PM;
   .DATASEGMENT DM;
   $celt.ec_dec_bits:
   // push rLink onto stack
   $push_rLink_macro;  
   // r2=ftb
   .var temp_t[2];
   M[temp_t + 0] = 0;
   M[temp_t + 1] =  0;
   r2 = M[$celt.dec.ec_dec.ftb];
   loop_check_ftp:
      Null = r2 - $celt.EC_UNIT_BITS;
      if NEG jump end_check_ftp;
      r8 = $celt.EC_UNIT_BITS;
      call $celt.ec_decode_raw;
      r2 = M[temp_t + 0];
      r3 = M[temp_t + 1];
      r3 = r3 LSHIFT  $celt.EC_UNIT_BITS;
      r4 = r2  LSHIFT ($celt.EC_UNIT_BITS-24);
      r3 = r3 + r4;
      r2 = r2 LSHIFT  $celt.EC_UNIT_BITS;
      r2 = r2 OR r0;
      r3 = r3 OR r1;
      M[temp_t + 0] = r2;
      M[temp_t + 1] = r3;
      r2 = M[$celt.dec.ec_dec.ftb];
      r2 = r2 - $celt.EC_UNIT_BITS;
      M[$celt.dec.ec_dec.ftb] = r2;     
  jump  loop_check_ftp;
  end_check_ftp:
  r8 = r2;
  call $celt.ec_decode_raw;
  r2 = M[temp_t + 0];
  r3 = M[temp_t + 1];
  r4 =  M[$celt.dec.ec_dec.ftb];
  r3 = r3 LSHIFT  r4;
  r6 = r4 - 24;
  r6 = r2  LSHIFT r6;
  r3 = r3 + r6;
  r2 = r2 LSHIFT  r4;
  r0 = r2 OR r0;
  r1 = r3 OR r1;
  // pop rLink from stack
  jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_decode_raw
//
// DESCRIPTION:
//   decoding a number of bits
//
// INPUTS:
//    r8 = number of bits
// OUTPUTS:
//     r0 
//     r1 = 0
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.ec_decode_raw;
   .CODESEGMENT CELT_EC_DECODE_RAW_PM;
   .DATASEGMENT DM;
   $celt.ec_decode_raw:
   // push rLink onto stack
   $push_rLink_macro;  
   //rMAC: value
   //r7: count
   //r2: bits(input)
   //r4:end_bits_left
   //r6:end_byte
   rMAC = 0; 
   r7 = 0; 
   r4 = M[$celt.dec.ec_dec.end_bits_left];
   r6 = M[$celt.dec.ec_dec.end_byte];
   r0 = r8 + M[$celt.dec.ec_dec.nb_end_bits];
   M[$celt.dec.ec_dec.nb_end_bits] = r0;
   loop_until_bits_left:
      Null = r8 - r4;
      if NEG jump end_bits_loop;
         r0 = r4 - 8;
         r0 = r6 LSHIFT r0;
         r0 = r0 LSHIFT r7;
         rMAC = rMAC OR r0;
         r7 = r7 + r4;
         r8 = r8 - r4;
         call $celt.get1byte_from_end;
         r6 = r1;
         r4 = 8;
   jump loop_until_bits_left;
   end_bits_loop: 
   r2 = 1 LSHIFT r8;   
   r2 = r2 - 1;        
   r0 = r4 - 8;        
   r0 = r6 LSHIFT r0;  
   r0 = r0 AND r2;    
   r0 = r0 LSHIFT r7; 
   r0 = rMAC OR r0; 
   r4 = r4 - r8;
   M[$celt.dec.ec_dec.end_bits_left] = r4;
   M[$celt.dec.ec_dec.end_byte] = r6;
   r1 = 0;
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_dec_uint
//
// DESCRIPTION:
//   decoding a 32 bit number
//
// INPUTS:
//    r1:r0 
// OUTPUTS:
//    r1:r0
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.ec_dec_uint;
   .CODESEGMENT CELT_EC_DEC_UINT_PM;
   .DATASEGMENT DM;
   $celt.ec_dec_uint:
   .VAR temp_ftb;
   .VAR tmp_ft[2];
   
   // push rLink onto stack
   $push_rLink_macro;
   
   r2 = r0 - 2;
   r2 = r1 - borrow;
   if NEG call $error;
   r0 = r0 - 1;
   r1 = r1 - borrow;
   M[tmp_ft + 0] = r0;
   M[tmp_ft + 1] = r1;
   // this is a macro
   $celt.EC_ILOG32(r0, r1, r2)
   M[$celt.dec.ec_dec.ftb] = r2;
   Null = r2 - $celt.EC_UNIT_BITS;
   if LE jump inc_ft;
      r2 = $celt.EC_UNIT_BITS - r2;
      M[$celt.dec.ec_dec.ftb] = -r2;
      M[temp_ftb] = -r2;
      M[$celt.dec.ec_dec.ft + 0] = r0;
      M[$celt.dec.ec_dec.ft + 1] = r1;
      // TODO:BC7OPT
      r3 = r2 + 24;
      r3 = r1 LSHIFT r3;
      r0 = r0 LSHIFT r2;
      r0 = r0 OR r3;
      r1 = r1 LSHIFT r2;
      r0 = r0 + 1;
      r1 = r1 + carry;
      
      call $celt.ec_decode;
      M[$celt.dec.ec_dec.fl + 0] = r0;
      M[$celt.dec.ec_dec.fl + 1] = r1;
      r0 = r0 + 1;
      M[$celt.dec.ec_dec.fh + 1] = r1 + carry;
      M[$celt.dec.ec_dec.fh + 0] = r0;
      call $celt.ec_dec_update;  
      
      call $celt.ec_dec_bits;
      r2 = M[$celt.dec.ec_dec.fl + 0];
      r3 = M[$celt.dec.ec_dec.fl + 1];
      r4 = M[temp_ftb];
      
      // TODO:BC7OPT
      r3 = r3 LSHIFT r4;
      r7 = r4 - 24;
      r7 = r2 LSHIFT r7;
      r3 = r3 OR r7;
      r2 = r2 LSHIFT r4;
      r0 = r0 OR r2;
      r1 = r1 OR r3;
      
      r2 = M[$celt.dec.ec_dec.ft + 0];
      r3 = M[$celt.dec.ec_dec.ft + 1];
      NULL = r0 - M[tmp_ft + 0];
      NULL = r1 - M[tmp_ft + 1] - borrow;
      if LE jump end;
         r0 = r2;
         r1 = r3;
      jump end;
   inc_ft:
   r0 = r0 + 1;
   r1 = r1 + carry;
   call $celt.ec_decode;
   M[$celt.dec.ec_dec.fl + 0] = r0;
   M[$celt.dec.ec_dec.fl + 1] = r1;
   r0 = r0 + 1;
   M[$celt.dec.ec_dec.fh + 1] = r1 + carry;
   M[$celt.dec.ec_dec.fh + 0] = r0;
   call $celt.ec_dec_update;
   r0 = M[$celt.dec.ec_dec.fl + 0];
   r1 = M[$celt.dec.ec_dec.fl + 1];
   
   end:
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_dec_tell
//
// DESCRIPTION:
//  returns number of bits used so far
// INPUTS:
//  r4: bit precision
// OUTPUTS:
//  r0 = number of bits
// TRASHED REGISTERS:
// 
// *****************************************************************************
.MODULE $M.celt.ec_dec_tell;
   .CODESEGMENT CELT_EC_DEC_TELL_PM;
   .DATASEGMENT DM;
   $celt.ec_dec_tell:

   // push rLink onto stack
   $push_rLink_macro;
   
   // work out number of bits
   r3 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r3 = r3 - M[$celt.dec.frame_bytes_remained];
   r3 = r3 - (($celt.EC_CODE_BITS+$celt.EC_SYM_BITS-1)/$celt.EC_SYM_BITS); 
   r3 = r3 * $celt.EC_SYM_BITS (int);
   r3 = r3 + M[$celt.dec.ec_dec.nb_end_bits];
   r3 = r3 +($celt.EC_CODE_BITS+1);
   r3 = r3 LSHIFT r4;
   r0 = M[$celt.dec.ec_dec.rng + 0];
   r1 = M[$celt.dec.ec_dec.rng + 1];   
   $celt.EC_ILOG32(r0, r1, r2)
   r6 = 16 - r2;
   r0 = r0 LSHIFT r6;
   r6 = r6 + 24;
   r1 = r1 LSHIFT r6;
   r6 = r0 OR r1;
   r1 = -1;
   tel_loop:
      r4 = r4 - 1;
      if NEG jump end_tel_loop;
         rMAC = r6 * r6;
         r6 = rMAC LSHIFT (24-15-1);
         r0 = r6 LSHIFT -16;
         if NZ r6 = r6 LSHIFT r1;
         r2 = r2 + r2;
         r2 = r2 OR r0; 
      jump tel_loop;
   end_tel_loop:
   r0 = r3 - r2;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;
   

.ENDMODULE;
#endif
