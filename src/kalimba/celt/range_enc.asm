// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_RANGE_ENC_INCLUDED
#define CELT_RANGE_ENC_INCLUDED
#include "stack.h"
#include "celt.h"
// *****************************************************************************
// MODULE:
//    $celt.ec_enc_init
//
// DESCRIPTION:
//    initialise entropy encoder
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_enc_init;
   .CODESEGMENT CELT_EC_ENC_INIT_PM;
   .DATASEGMENT DM;
   $celt.ec_enc_init:
   // push rLink onto stack
   $push_rLink_macro;

   r0 = -1;
   M[$celt.enc.ec_enc.rem] = r0;
   // rng = EC_CODE_TOP
   M[$celt.enc.ec_enc.rng + 0] = Null;
   r0 = 0x80;
   M[$celt.enc.ec_enc.rng + 1] = r0;
   r0 = 8;
   M[$celt.enc.ec_enc.end_bits_left] = r0;
   M[$celt.enc.ec_enc.nb_end_bits] = Null;
   M[$celt.enc.ec_enc.low + 0] = Null;
   M[$celt.enc.ec_enc.low + 1] = Null;
   M[$celt.enc.ec_enc.ext + 0] = Null;
   M[$celt.enc.ec_enc.end_byte] = Null;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_enc_carry_out
//
// DESCRIPTION:
//
// INPUTS:
//    r3 = carry
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - r0-r2
// *****************************************************************************
.MODULE $M.celt.ec_enc_carry_out;
   .CODESEGMENT CELT_EC_ENC_CARRY_OUT_PM;
   .DATASEGMENT DM;
   $celt.ec_enc_carry_out:
   // push rLink onto stack
   $push_rLink_macro;
   // r3 = carry
   Null = r3 - $celt.EC_SYM_MAX;
   if NZ jump write_sym;
      r2 = M[$celt.enc.ec_enc.ext];
      r2 = r2 + 1;
      jump end;
   write_sym:
   r2 = r3 LSHIFT (-$celt.EC_SYM_BITS);
   r1 = M[$celt.enc.ec_enc.rem];
   if NEG jump end_writing_carry;
      r1 = r1 + r2; 
      call $celt.put1byte;
   end_writing_carry:
   r2 = r2 + $celt.EC_SYM_MAX;
   r1 = r2 AND $celt.EC_SYM_MAX;
   r2 = M[$celt.enc.ec_enc.ext];
   loop_write_sym:
      if LE jump end_write_loop;
      call $celt.put1byte;
      r2 = r2 - 1;
   jump loop_write_sym;
   end_write_loop:
   r3 = r3 AND $celt.EC_SYM_MAX; 
   M[$celt.enc.ec_enc.rem] = r3;
   end:
   M[$celt.enc.ec_enc.ext] = r2;
    // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.ec_enc_normalise
//
// DESCRIPTION:
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_enc_normalise;
   .CODESEGMENT CELT_EC_ENC_NORMALISE_PM;
   .DATASEGMENT DM;
   $celt.ec_enc_normalise:
   // push rLink onto stack
   $push_rLink_macro;
    r7 = M[$celt.enc.ec_enc.low + 0];
    r8 = M[$celt.enc.ec_enc.low + 1];
    r4 = M[$celt.enc.ec_enc.rng + 0];
    r6 = M[$celt.enc.ec_enc.rng + 1];
    retry:
       Null = $celt.EC_CODE_BOT - r4;
       Null = Null - r6 - Borrow;
       if NEG jump end;
          r0 = r7 LSHIFT (-$celt.EC_CODE_SHIFT);
          r1 = r8 LSHIFT (24-$celt.EC_CODE_SHIFT);
          r3 = r1 + r0;
          call $celt.ec_enc_carry_out;
          r8 = r7 LSHIFT -16;
          r7 = r7 LSHIFT 8;
          r8 = r8 AND 0x7F;          
          r6 = r4 LSHIFT -16;
          r4 = r4 LSHIFT 8;
    jump retry;
    end:
    M[$celt.enc.ec_enc.low + 0] = r7;
    M[$celt.enc.ec_enc.low + 1] = r8;
    M[$celt.enc.ec_enc.rng + 0] = r4;
    M[$celt.enc.ec_enc.rng + 1] = r6;
    // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.ec_encode
//
// DESCRIPTION:
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_encode;
   .CODESEGMENT CELT_EC_ENCODE_PM;
   .DATASEGMENT DM;
   $celt.ec_encode:
   // push rLink onto stack
   $push_rLink_macro;
   
    r0 = M[$celt.enc.ec_enc.rng + 0];
    r1 = M[$celt.enc.ec_enc.rng + 1];
    r2 = M[$celt.enc.ec_enc.ft + 0];
    r3 = 0; //M[$celt.enc.ec_enc.ft + 1]; 
    call $celt.idiv32;
    r0 = M[$celt.enc.ec_enc.rng + 0];
    $celt.ec_encode_bin_jump_point:
    r4 = -M[$celt.enc.ec_enc.fl + 0];
    if POS jump update_range_only;
       // r = r7:r6
       r2 = r4 + r2;
       //r8:r3=(r7:r6)*r2
       rMAC = r2*r6(UU);
       r3 = rMAC LSHIFT 23;
       rMAC0 = rMAC1;
       rMAC12 = rMAC2(ZP);
       rMAC = rMAC + r2*r7(SU);
       r8 = rMAC LSHIFT 23;
       r0 = r0 - r3;
       r1 = r1 - r8 - Borrow;
       r0 = r0 + M[$celt.enc.ec_enc.low + 0];
       r1 = r1 + M[$celt.enc.ec_enc.low + 1] + Carry;
       M[$celt.enc.ec_enc.low + 0] = r0;
       M[$celt.enc.ec_enc.low + 1] = r1;
       r2 = r4 + M[$celt.enc.ec_enc.fh + 0];
       //r1:r0=(r7:r6)*r2
       rMAC = r2*r6(UU);
       r0 = rMAC LSHIFT 23;
       rMAC0 = rMAC1;
       rMAC12 = rMAC2(ZP);
       rMAC = rMAC + r2*r7(SU);
       r1 = rMAC LSHIFT 23;
       M[$celt.enc.ec_enc.rng + 0] = r0;
       M[$celt.enc.ec_enc.rng + 1] = r1; 
       jump end;
    update_range_only:
       r8 = r2 - M[$celt.enc.ec_enc.fh + 0];
       //(r7:r6)*r8
       rMAC = r8*r6(UU);
       r6 = rMAC LSHIFT 23;
       rMAC0 = rMAC1;
       rMAC12 = rMAC2(ZP);
       rMAC = rMAC + r7*r8(SU);
       r7 = rMAC LSHIFT 23; 
       M[$celt.enc.ec_enc.rng + 0] = r0 - r6;
       M[$celt.enc.ec_enc.rng + 1] = r1 - r7 - Borrow; 
    end:
    call $celt.ec_enc_normalise;
    // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.ec_encode_bin
//
// DESCRIPTION:
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_encode_bin;
   .CODESEGMENT CELT_EC_ENCODE_BIN_PM;
   .DATASEGMENT DM;
   $celt.ec_encode_bin:
   // push rLink onto stack
   $push_rLink_macro;
   
   r0 = M[$celt.enc.ec_enc.rng + 0];
   r1 = M[$celt.enc.ec_enc.rng + 1];
   r2 = r0 LSHIFT -15;
   r6 = r1 LSHIFT (24-15);
   r6 = r6 + r2;
   r2 = 32768;
   M[$celt.enc.ec_enc.ft + 0] = r2;
   M[$celt.enc.ec_enc.ft + 1] = Null;
   r7 = 0;
   jump $celt.ec_encode_bin_jump_point;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.ec_encode_raw
//
// DESCRIPTION:
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_encode_raw;
   .CODESEGMENT CELT_EC_ENCODE_RAW_PM;
   .DATASEGMENT DM;
   $celt.ec_encode_raw:
   // push rLink onto stack
   $push_rLink_macro;
   //r8 = bits
   r0 = r8 + M[$celt.enc.ec_enc.nb_end_bits];
   M[$celt.enc.ec_enc.nb_end_bits] = r0;
   r7 = M[$celt.enc.ec_enc.end_byte];
   r4 = M[$celt.enc.ec_enc.end_bits_left];
   r6 = M[$celt.enc.ec_enc.fl + 0];
   loop_until_bits_left:
      Null = r8 - r4;
      if NEG jump end_bits_loop;
         r1 = 8 - r4;
         r1 = r6 LSHIFT r1;
         r1 = r1 AND 0xFF;
         r1 = r1 OR r7;
         call $celt.put1byte_to_end;
         r4 = -r4;
         r6 = r6 LSHIFT r4;
         r8 = r8 + r4;
         r4 = 8;
         r7 = 0;
   jump loop_until_bits_left;
   end_bits_loop: 
   r1 = 8 - r4;
   r1 = r6 LSHIFT r1;
   r1 = r1 AND 0xFF;
   r1 = r1 OR r7;
   M[$celt.enc.ec_enc.end_byte] = r1;
   r4 = r4 - r8;
   M[$celt.enc.ec_enc.end_bits_left] = r4; 
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_enc_tell
//
// DESCRIPTION:
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_enc_tell;
   .CODESEGMENT CELT_EC_ENC_TELL_PM;
   .DATASEGMENT DM;
   $celt.ec_enc_tell:
   // push rLink onto stack
   $push_rLink_macro;
   // work out number of bits
   r3 = M[r5 + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD];
   r3 = r3 - M[$celt.enc.frame_bytes_remained];
   r3 = r3 + M[$celt.enc.ec_enc.ext];
   r0 = 1;
   Null = M[$celt.enc.ec_enc.rem];
   if POS r3 = r3 + r0;
   r3 = r3 * $celt.EC_SYM_BITS (int);
   r3 = r3 + M[$celt.enc.ec_enc.nb_end_bits];
   r3 = r3 + ($celt.EC_CODE_BITS+1);
   r3 = r3 LSHIFT r4;
   r0 = M[$celt.enc.ec_enc.rng + 0];
   r1 = M[$celt.enc.ec_enc.rng + 1];   
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
// *****************************************************************************
// MODULE:
//    $celt.ec_enc_bits
//
// DESCRIPTION:
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_enc_bits;
   .CODESEGMENT CELT_EC_ENC_BITS_PM;
   .DATASEGMENT DM;
   $celt.ec_enc_bits:
   // push rLink onto stack
   .VAR temp_t[2];
   $push_rLink_macro;
   r0 =  M[$celt.enc.ec_enc.fl + 0];
   r1 =  M[$celt.enc.ec_enc.fl + 1];
   M[temp_t + 0] = r0;
   M[temp_t + 1] = r1;
   M[$celt.enc.ec_enc.fl + 1] = 0;
   M[$celt.enc.ec_enc.fh + 1] = 0;
   r2 = M[$celt.enc.ec_enc.ftb];
   loop_check_ftb:
      r3 = $celt.EC_UNIT_BITS - r2;    
      if POS jump end_check_ftb;
      M[$celt.enc.ec_enc.ftb] = -r3;      
      r2 = r3 + 24;
      r0 = r0 LSHIFT r3;
      r1 = r1 LSHIFT r2;
      r0 = r0 + r1;
      r0 = r0 AND $celt.EC_UNIT_MASK;
      M[$celt.enc.ec_enc.fl + 0] = r0;
      r0 = r0 + 1;
      M[$celt.enc.ec_enc.fh + 0] = r0;
      r8 = $celt.EC_UNIT_BITS;
      call $celt.ec_encode_raw;
      r0 = M[temp_t + 0];
      r1 = M[temp_t + 1];
      r2 = M[$celt.enc.ec_enc.ftb];
   jump loop_check_ftb;
   end_check_ftb:
   r8 = r2;
   r2 = 1 LSHIFT r2;
   r2 = r2 - 1;
   r0 = r0 AND r2;
   M[$celt.enc.ec_enc.fl + 0] = r0;
   r0 = r0 + 1;
   M[$celt.enc.ec_enc.fh + 0] = r0;
   call $celt.ec_encode_raw;
    // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.ec_enc_uint
//
// DESCRIPTION:
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.ec_enc_uint;
   .CODESEGMENT CELT_EC_ENC_UINT_PM;
   .DATASEGMENT DM;
   $celt.ec_enc_uint:
   // push rLink onto stack
   $push_rLink_macro;
   .VAR temp[2];
   r0 = M[$celt.enc.ec_enc.ft + 0];
   r1 = M[$celt.enc.ec_enc.ft + 1];
   r0 = r0 - 1;
   r1 = r1 - Borrow;
   $celt.EC_ILOG32(r0, r1, r2)
   M[$celt.enc.ec_enc.ftb] = r2;
   //r1:r0 = _ft, r2 = ftb
   r3 = $celt.EC_UNIT_BITS -r2;
   if GT jump inc_ft;
     M[$celt.enc.ec_enc.ftb] = -r3;
     r2 = r3 + 24;
     r0 = r0 LSHIFT r3;
     r1 = r1 LSHIFT r2;
     r0 = r0 + r1;
     r0 = r0 + 1;
     M[$celt.enc.ec_enc.ft + 0] = r0;
     M[$celt.enc.ec_enc.ft + 1] = Null;
     r0 = M[$celt.enc.ec_enc.fl + 0];
     r1 = M[$celt.enc.ec_enc.fl + 1];
     M[temp + 0] = r0;
     M[temp + 1] = r1;
     r0 = r0 LSHIFT r3;
     r1 = r1 LSHIFT r2;
     r0 = r0 + r1;
     M[$celt.enc.ec_enc.fl + 0] = r0;
     M[$celt.enc.ec_enc.fl + 1] = Null;
     r0 = r0 + 1;
     M[$celt.enc.ec_enc.fh + 0] = r0;
     M[$celt.enc.ec_enc.fh + 1] = Null;
     call $celt.ec_encode;
     r0 = M[temp + 0];
     r1 = M[temp + 1];     
     M[$celt.enc.ec_enc.fl + 0] = r0;
     M[$celt.enc.ec_enc.fl + 1] = r1;
     call $celt.ec_enc_bits;
     jump $pop_rLink_and_rts;
   inc_ft:
   r0 = M[$celt.enc.ec_enc.fl + 0];
   r1 = M[$celt.enc.ec_enc.fl + 1];
   r0 = r0 + 1;
   M[$celt.enc.ec_enc.fh + 1] = r1 + Carry; 
   M[$celt.enc.ec_enc.fh + 0] = r0;
   call $celt.ec_encode;
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.end_writing_frame
//
// DESCRIPTION:
//
// INPUTS:
//    -none
// OUTPUTS:
//    -none
// TRASHED REGISTERS:
//   - assume everything except r5
// *****************************************************************************
.MODULE $M.celt.end_writing_frame;
   .CODESEGMENT CELT_END_WRITING_FRAME_PM;
   .DATASEGMENT DM;
   $celt.end_writing_frame:

   // push rLink onto stack
 $push_rLink_macro;
   r0 = M[$celt.enc.ec_enc.rng + 0];
   r1 = M[$celt.enc.ec_enc.rng + 1];   
   $celt.EC_ILOG32(r0, r1, r6)
   r6 = r6 - $celt.EC_CODE_BITS;
   r3 = 0x7F;
   r2 = 0xFFFFFF;
   r4 = r6 + 24;   
   r2 = r2 LSHIFT r6;
   r8 = r3 LSHIFT r4;
   r3 = r3 LSHIFT r6;
   r2 = r2 + r8;
   //r3:r2 = msk
   r7 = M[$celt.enc.ec_enc.low + 0];
   r8 = M[$celt.enc.ec_enc.low + 1];  
   r0 = r0 + r7;
   r1 = r1 + r8 + Carry;
   r7 = r7 + r2;
   r8 = r8 + r3 + Carry;
   //a = r8:r7
   //b = r3:r2
   //r10:r4= a&~b=(a xo rb) & a   
   r10 = r8 XOR r3;
   r4 = r7 XOR r2;
   r8 = r10 and r8;
   r7 = r4 and r7;
   r4 = r7 OR r2;
   r10 = r8 OR r3;
   Null = r4 - r0;
   Null = r10 - r1 - Borrow;
   if NEG jump no_msk_up;
      r6 = r6 - 1;
      r2 = r2 LSHIFT -1;
      r4 = r3 LSHIFT 23;
      r3 = r3 LSHIFT -1;
      r2 = r2 + r4;
      r7 = r2 + M[$celt.enc.ec_enc.low + 0];
      r8 = r3 + M[$celt.enc.ec_enc.low + 1] + Carry;
      r10 = r8 XOR r3;
      r4 = r7 XOR r2;
      r8 = r10 and r8;
      r7 = r4 and r7;  
   no_msk_up:
   
   Null = r6;
   retry:
   if POS jump end_carry_out;
      r0 = r7 LSHIFT (-$celt.EC_CODE_SHIFT);
      r1 = r8 LSHIFT (24-$celt.EC_CODE_SHIFT);
      r3 = r1 + r0;
      call $celt.ec_enc_carry_out;
      r8 = r7 LSHIFT -16;
      r7 = r7 LSHIFT 8;
      r8 = r8 AND 0x7F;         
      r6 = r6 + $celt.EC_SYM_BITS;
      jump retry;
   end_carry_out:
   r0 = M[$celt.enc.ec_enc.rem];
   if NEG r0 = 0;
   r1 = M[$celt.enc.ec_enc.ext];
   r1 = r1 OR r0;
   if Z jump end_last_sym;
      r3 = 0;
      call $celt.ec_enc_carry_out;
      r0 = -1;
      M[$celt.enc.ec_enc.rem] = r0;
   end_last_sym:
   
   r10 = M[$celt.enc.frame_bytes_remained];
   r10 = r10 + M[$celt.enc.frame_bytes_remained_reverse];
   r0 = M[r5 + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD];
   r10 = r10 - r0;
   if NEG r10 = 0;

   do lp_pad;
      r1 = 0;
      call $celt.put1byte;
   lp_pad:
   r0 = M[$celt.enc.ec_enc.end_bits_left];
   Null = r0 - 8;
   if Z jump update_buffer_addr;
      r0 = M[$celt.enc.ec_enc.end_byte];
      r0 = r0 LSHIFT 8;
      Null = M[$celt.enc.put_bytepos_reverse];
      if Z jump this_word;
         r0 = r0 LSHIFT -8;
         r1  = M[I1, -1];
      this_word:
      r1 = M[I1, 0];
      r0 = r0 OR r1;
      M[I1, 0] = r0;      
   update_buffer_addr:
   r0 = M[r5 + $celt.enc.PUT_BYTE_POS_FIELD];
   r4 = M[r5 + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD];
   r2 = r4 -r0;
   r0 = r2 AND 1;
   M[r5 + $celt.enc.PUT_BYTE_POS_FIELD] = r0;
   r2 = r2 + 1;
   r2 = r2 LSHIFT -1;
   M0 = r2;
   r0 = M[r5 + $celt.enc.ENCODER_OUT_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   push r2;
   pop  B0;
#else
   call $cbuffer.get_write_address_and_size;
#endif
   I0 = r0;
   L0 = r1;
   r0 = M[I0, M0];
   L0 = 0;
   r0 = M[r5 + $celt.enc.ENCODER_OUT_BUFFER_FIELD];
   r1 = I0;
   call $cbuffer.set_write_address;
   L0 = 0;
   L1 = 0;   
#ifdef BASE_REGISTER_MODE
   push Null;
   pop  B0;
   push Null;
   pop B1;
#endif

   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
#endif
