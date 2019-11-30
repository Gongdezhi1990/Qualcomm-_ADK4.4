// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_ENCODER_INIT_INCLUDED
#define CELT_ENCODER_INIT_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.encoder_init
//
// DESCRIPTION:
//    initialises the encoder
//
// INPUTS:
//  r5 = pointer to decoder structure
//
// OUTPUTS:
//  - none
//
// TRASHED REGISTERS:
//    assume everything except r5
// *****************************************************************************
.MODULE $M.celt.encoder_init;
   .CODESEGMENT CELT_ENCODER_INIT_PM;
   .DATASEGMENT DM;
   
   $celt.encoder_init:
   
   // -- disable re-init flag
   M[r5 + $celt.enc.REINIT_ENCODER_FIELD] = 0;
      
   r0 = 1;
   M[r5 + $celt.enc.PUT_BYTE_POS_FIELD] = r0;
   
   // -- read mode variables
   r10 = $celt.mode.STRUC_SIZE ;
   r8 = M[r5 + $celt.enc.CELT_MODE_OBJECT_FIELD];
   I3 = r8;
   I6 = r5 + $celt.enc.MODE_FIELDS_OFFSET_FIELD;
   do read_single_vars_loop;
      r0 = M[I3, 1];
      M[I6, 1] = r0;
   read_single_vars_loop:
      
   r0 = &$celt.ec_enc_tell;
   M[r5 + $celt.enc.TELL_FUNC_FIELD] = r0;
   r0 = &$celt.alg_quant;
   M[r5 + $celt.enc.ALG_QUANT_FUNC_FIELD] = r0;
   r0 = &$celt.ec_enc_uint;
   M[r5 + $celt.dec.EC_UINT_FUNC_FIELD] = r0;

   rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.encoder_frame_init
//
// DESCRIPTION:
//    initialise encoder to start encoding new frame
//
// INPUTS:
//  r5 = pointer to decoder structure
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//    assume everything except r5
// *****************************************************************************
.MODULE $M.celt.encoder_frame_init;
   .CODESEGMENT CELT_ENCODER_FRAME_INIT_PM;
   .DATASEGMENT DM;
   
   $celt.encoder_frame_init:
   
   // push rLink onto stack
   $push_rLink_macro;

   // set byte-pos values
   r0 = M[r5 + $celt.enc.PUT_BYTE_POS_FIELD];
   M[$celt.enc.put_bytepos] = r0;
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
   
   // get the frame length in bytes
   r8 = M[r5 + $celt.enc.CELT_MODE_OBJECT_FIELD];
   r0 = M[r5 + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD];
   M[$celt.enc.frame_bytes_remained] = r0;
   M[$celt.enc.frame_bytes_remained_reverse] = r0;
   r1 = r0 + M[$celt.enc.put_bytepos];
   r1 = r1 AND 1;
   M[$celt.enc.put_bytepos_reverse] = r1;
   
   //I1/L1 -> must point to end of buffer
   I1 = I0;
   L1 = L0;
#ifdef BASE_REGISTER_MODE   
   push B0;
   pop B1;
#endif 

   r0 = r0 + M[$celt.enc.put_bytepos_reverse];
   r0 = r0 - M[$celt.enc.put_bytepos];
   r0 = r0 LSHIFT -1;
   M0 = r0;
   r0 = M[I1, M0];
   
   // initialise entropy decoder
   call $celt.ec_enc_init;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
