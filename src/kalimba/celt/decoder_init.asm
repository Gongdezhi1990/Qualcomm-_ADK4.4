// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_DECODER_INIT_INCLUDED
#define CELT_DECODER_INIT_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.decoder_init
//
// DESCRIPTION:
//    initialises the decoder
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
.MODULE $M.celt.decoder_init;
   .CODESEGMENT CELT_DECODER_INIT_PM;
   .DATASEGMENT DM;
   
   $celt.decoder_init:
   
   // -- disable re-init flag
   M[r5 + $celt.dec.REINIT_DECODER_FIELD] = 0;
      
   // reset byte pos
   r0 = 1;
   M[r5 + $celt.dec.GET_BYTE_POS_FIELD] = r0;
   
   // -- read mode variables
   r10 = $celt.mode.STRUC_SIZE ;
   r8 = M[r5 + $celt.dec.CELT_MODE_OBJECT_FIELD];
   I3 = r8;
   I6 = r5 + $celt.dec.MODE_FIELDS_OFFSET_FIELD;
   do read_single_vars_loop;
      r0 = M[I3, 1];
      M[I6, 1] = r0;
   read_single_vars_loop:
      
   r1 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   r0 = M[r5 + $celt.dec.DECODER_OUT_RIGHT_BUFFER_FIELD];
   r1 = r1 XOR 1;
   r0 = r0 * r1 (int);
   M[$celt.dec.mono_to_stereo] = r0;
   
   r0 = &$celt.ec_dec_tell;
   M[r5 + $celt.dec.TELL_FUNC_FIELD] = r0;
   r0 = &$celt.alg_unquant;
   M[r5 + $celt.dec.ALG_QUANT_FUNC_FIELD] = r0;
   r0 = &$celt.ec_dec_uint;
   M[r5 + $celt.dec.EC_UINT_FUNC_FIELD] = r0;
   rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.alloc_state_mem
//
// DESCRIPTION:
//    utility funtion to allocate state vars from a pool
//    
// INPUTS:
//  r5 = pointer to decoder structure
//  r8 = DM(1) state pool
//  r7 = DM(1) state size 
// OUTPUTS:
//
// TRASHED REGISTERS:
//    assume everything except r5
// NOTE:
//  - Any other method to allocate state mem can be used
//  - This function must be run after init
//  - pool memory should stay persistent between calls
//
// TODO: making it independent from vectors name
// *****************************************************************************
.MODULE $M.celt.alloc_state_mem;
   .CODESEGMENT CELT_ALLOC_STATE_MEM_PM;
   .DATASEGMENT DM;
   $celt.alloc_state_mem:
   r0 = $celt.MAX_BANDS;
   r1 = M[r5 + $celt.dec.MODE_OVERLAP_FIELD];   
   r2 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   r2 = r2 + 1;
   r3 = r0 + r1;
   r3 = r3 * r2 (int);
   Null = r7 - r3;
   if NEG call $error;
   M[r5 + $celt.dec.OLD_EBAND_LEFT_FIELD] = r8;
   r8 = r8 + r0;
   if NZ r8 = r8 + r0;
   M[r5 + $celt.dec.HIST_OLA_LEFT_FIELD] = r8;
   r8 = r8 + r1;   
   M[r5 + $celt.dec.HIST_OLA_RIGHT_FIELD] = r8;   
   rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.alloc_scratch_mem
//
// DESCRIPTION:
//    utility funtion to allocate scratch vars from a pool
//    
// INPUTS:
//  r5 = pointer to decoder structure
//  r1 = DM1 pool addr table
//  r2 = DM1 base

//  r3 = DM2 pool addr table
//  r4 = DM2 base
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//    assume everything except r5
// NOTE:
//  - Any other method to allocate scratch mem can be used
//  - This function must be run after init
//  - pool memory doesnt neeed to stay persistent
// *****************************************************************************
.MODULE $M.celt.alloc_scratch_mem;
   .CODESEGMENT CELT_ALLOC_SCRATCH_MEM_PM;
   .DATASEGMENT DM;
   $celt.alloc_scratch_mem:
  
  
   I0 = r5 + $celt.dec.DM1_SCRATCH_FIELDS_OFFSET ;
   r10 = $celt.dec.DM1_SCRATCH_FIELDS_LENGTH;
   I4 = r1;
   do copy_dm1_loop;
      r0 = M[I4, 1];
      r0 = r0 + r2;
      M[I0, 1] = r0;
   copy_dm1_loop:
   
   I0 = r5 + $celt.dec.DM2_SCRATCH_FIELDS_OFFSET ;
   r10 = $celt.dec.DM2_SCRATCH_FIELDS_LENGTH;
   I4 = r3;
   do copy_dm2_loop;
      r0 = M[I4, 1];
      r0 = r0 + r4;
      M[I0, 1] = r0;
   copy_dm2_loop:
   rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.decoder_frame_init
//
// DESCRIPTION:
//    initialise decoder to start decoding new frame
//
// INPUTS:
//  r5 = pointer to decoder structure
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//    assume everything except r5
// *****************************************************************************
.MODULE $M.celt.decoder_frame_init;
   .CODESEGMENT CELT_DECODER_FRAME_INIT_PM;
   .DATASEGMENT DM;
   
   $celt.decoder_frame_init:
   
   // push rLink onto stack
   $push_rLink_macro;

   // set byte-pos values
   r0 = M[r5 + $celt.dec.GET_BYTE_POS_FIELD];
   M[$celt.dec.get_bytepos] = r0;
   r0 = M[r5 + $celt.dec.DECODER_IN_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_read_address_and_size_and_start_address;
   push r2;
   pop  B0;
#else
   call $cbuffer.get_read_address_and_size;
#endif
   I0 = r0;
   L0 = r1;
   
   // get the frame length in bytes
   r8 = M[r5 + $celt.dec.CELT_MODE_OBJECT_FIELD];
   r0 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   M[$celt.dec.frame_bytes_remained] = r0;
   M[$celt.dec.frame_bytes_remained_reverse] = r0;
   r1 = r0 + M[$celt.dec.get_bytepos];
   r1 = r1 AND 1;
   M[$celt.dec.get_bytepos_reverse] = r1;
   
   //I1/L1 -> must point to end of buffer
   I1 = I0;
   L1 = L0;
#ifdef BASE_REGISTER_MODE
   push B0;
   pop B1;
#endif
   
   r0 = r0 + M[$celt.dec.get_bytepos_reverse];
   r0 = r0 - M[$celt.dec.get_bytepos];
   r0 = r0 LSHIFT -1;
   M0 = r0;
   r0 = M[I1, M0];
   
   // initialise entropy decoder
   call $celt.ec_dec_init;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.end_reading_frame
//
// DESCRIPTION:
//    safely ends reading from input frame
//
// INPUTS:
//  r5 = pointer to decoder structure
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//    assume everything except r5
// *****************************************************************************
.MODULE $M.celt_dec.end_reading_frame;
   .CODESEGMENT CELT_END_READING_FRAME_PM;
   .DATASEGMENT DM;
   
   $celt.end_reading_frame:
   
     // push rLink onto stack
   $push_rLink_macro;
   
   r0 = M[r5 + $celt.dec.GET_BYTE_POS_FIELD];
   r4 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r4 AND 1;
   r2 = r0 XOR r1;
   M[r5 + $celt.dec.GET_BYTE_POS_FIELD] = r2;
   r4 = r4 + r2;
   r4 = r4 LSHIFT -1;
   M0 = r4;
   r0 = M[r5 + $celt.dec.DECODER_IN_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_read_address_and_size_and_start_address;
   push r2;
   pop  B0;
#else
   call $cbuffer.get_read_address_and_size;
#endif
   I0 = r0;
   L0 = r1;
   r0 = M[I0, M0];
   L0 = 0;
   r0 = M[r5 + $celt.dec.DECODER_IN_BUFFER_FIELD];
   r1 = I0;
   call $cbuffer.set_read_address;
   L0 = 0;
   L1 = 0;
#ifdef BASE_REGISTER_MODE
   push Null;
   pop  B0;
   push Null;
   pop  B1; 
#endif
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
#endif
