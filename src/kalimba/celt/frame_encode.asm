// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_FRAME_ENCODE_INCLUDED
#define CELT_FRAME_ENCODE_INCLUDED
#include "stack.h"
#include "codec_library.h"
// *****************************************************************************
// MODULE:
//    $celt.frame_encode
//
// DESCRIPTION:
//    Encode an audio frame to CELT format
//
// INPUTS:
//    - r5 = pointer to a $celt.enc structure, 
//           see header file for definition of structure fields
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    assume everything
//
// NOTES:
//    - left input channel must always be valid(it is not checked)
// *****************************************************************************
.MODULE $M.celt.frame_encode;
   .CODESEGMENT CELT_FRAME_ENCODE_PM;
   .DATASEGMENT DM;
 
   $celt.frame_encode:

   // push rLink onto stack
   $push_rLink_macro;

   // -- Save codec struct pointer --
   M[$celt.enc.codec_struc] = r5;
   
   //-- Is re-init required?
   Null = M[r5 + $celt.enc.REINIT_ENCODER_FIELD];
   if NZ call $celt.encoder_init;
   
   // -- See if there is enough input data
   r4 = M[r5 + $celt.enc.MODE_AUDIO_FRAME_SIZE_FIELD];
   r0 = M[r5 + $celt.enc.ENCODER_IN_LEFT_BUFFER_FIELD];
   call $cbuffer.calc_amount_data;
   Null = r0 - r4;
   if NEG jump exit_not_enough_input_data;
   r0 = M[r5 + $celt.enc.ENCODER_IN_RIGHT_BUFFER_FIELD];
   if Z jump end_data_check;
      call $cbuffer.calc_amount_data;
      Null = r0 - r4;
      if NEG jump exit_not_enough_input_data;
   end_data_check:
   
   // save output buffer addresses
   r0 = M[r5 + $celt.enc.ENCODER_IN_LEFT_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_read_address_and_size_and_start_address;
   M[$celt.enc.left_ibuf_start_addr] = r2;
#else
   call $cbuffer.get_read_address_and_size;
#endif
   M[$celt.enc.left_ibuf_addr] = r0;
   M[$celt.enc.left_ibuf_len] = r1;
   r0 =  M[r5 + $celt.enc.ENCODER_IN_RIGHT_BUFFER_FIELD];
   if Z jump end_ch_addr_save;
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_read_address_and_size_and_start_address;
   M[$celt.enc.right_ibuf_start_addr] = r2;
#else
   call $cbuffer.get_read_address_and_size;
#endif
   M[$celt.enc.right_ibuf_addr] = r0;
   M[$celt.enc.right_ibuf_len] = r1;

   end_ch_addr_save:

   //-- See if there is at least one frame output space 
   r0 = M[r5 + $celt.enc.ENCODER_OUT_BUFFER_FIELD];
   call $cbuffer.calc_amount_space;
   r0 = r0 + r0;
   r1 = M[r5 + $celt.enc.PUT_BYTE_POS_FIELD];
   r2 = r0 + r1;
   r2 = r2 - 1;
   r1 = M[r5 + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD];
   r0 = $codec.NOT_ENOUGH_OUTPUT_SPACE;
   Null = r2 - r1;
   if NEG jump exit;

   // -- stereo to mono --
   // Please note right channel signal is mixed into left channel signal. 
   // The mono output signal will be a mixed signal of left and right channels. 
   r0 = 1;
   Null = M[r5 + $celt.enc.ENCODER_IN_RIGHT_BUFFER_FIELD];
   if Z r0 = 0;
   r1 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   r2 = r1 XOR r0; 
   r0 = r0 AND r2;
   M[$celt.enc.stereo_to_mono] = r0;  
   if Z jump end_stereo_to_mono_convert;
      r10 = M[r5 + $celt.enc.MODE_AUDIO_FRAME_SIZE_FIELD];
      r0 = M[$celt.enc.left_ibuf_addr];
      I4 = r0;
      r0 = M[$celt.enc.left_ibuf_len];
      L4 = r0;
      r0 = M[$celt.enc.right_ibuf_addr];
      I5 = r0;
      r0 = M[$celt.enc.right_ibuf_len];
      L5 = r0;
#ifdef BASE_REGISTER_MODE  
      r0 = M[$celt.enc.left_ibuf_start_addr];
      push r0; 
      pop B4;
      r0 = M[$celt.enc.right_ibuf_start_addr];
      push r0;
      pop B5; 
#endif       
      r2 = 0.5;
      r10 = r10 - 1;
      r0 = M[I5, 1];
      rMAC = r0 * r2;
      do stereo_to_mono_loop;
         r0 = M[I4, 0];
         rMAC = rMAC + r0 * r2, r0 = M[I5, 1];
         rMAC = r0 * r2, M[I4, 1] = rMAC;
      stereo_to_mono_loop:
      r0 = M[I4, 0];
      rMAC = rMAC + r0 * r2;
      M[I4, 1] = rMAC;    
      L5 = 0;
      L4 = 0;
      
#ifdef BASE_REGISTER_MODE 
      push Null; 
      pop B4;
      push Null; 
      pop B5; 
#endif
      
   end_stereo_to_mono_convert:
   
   // -- Preemphasis
   call $celt.preemphasis;
   
  // --
  call  $celt.transient_analysis;
  
   // -- Windowing and MDCT
   call $celt.mdct_analysis;
  
   // -- Bands processing
   call $celt.bands_process;
   
   // -- Initialise frame encoder
   call $celt.encoder_frame_init;

   // -- update output buffer addresses
   r0 =  M[r5 + $celt.enc.ENCODER_IN_LEFT_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_read_address_and_size_and_start_address;
   push r2;
   pop  B4;
#else
   call $cbuffer.get_read_address_and_size;
#endif
   r4 = M[r5 + $celt.enc.MODE_AUDIO_FRAME_SIZE_FIELD];
   I4 = r0;
   L4 = r1;
   M0 = r4;
   r0 = M[I4, M0];
   r1 = I4;
   r0 = M[r5 + $celt.enc.ENCODER_IN_LEFT_BUFFER_FIELD];
   call $cbuffer.set_read_address;
   
   // -- see if right buffer is enabled
   r0 =  M[r5 + $celt.enc.ENCODER_IN_RIGHT_BUFFER_FIELD];
   if Z jump end_ch_addr_update;
#ifdef BASE_REGISTER_MODE
    call $cbuffer.get_read_address_and_size_and_start_address;
    push r2;
    pop  B4;
#else  
    call $cbuffer.get_read_address_and_size;
#endif
    I4 = r0;
    L4 = r1;
    r0 = M[I4, M0];
    r1 = I4;
    r0 = M[r5 + $celt.enc.ENCODER_IN_RIGHT_BUFFER_FIELD];
    call $cbuffer.set_read_address;
 end_ch_addr_update:
    L4 = 0;
 #ifdef BASE_REGISTER_MODE
    push Null;
    pop  B4;
#endif

   // -- encode flags
   r0 = $celt.FLAG_INTRA;
   M[r5 + $celt.enc.INTRA_ENER_FIELD] = r0;
   M[r5 + $celt.enc.HAS_PITCH_FIELD] = Null;
   //M[r5 + $celt.enc.SHORT_BLOCKS_FIELD] = Null;
   r0 = $celt.FLAG_FOLD;
   M[r5 + $celt.enc.HAS_FOLD_FIELD] = r0;
   
   // -- more transient processing for short blocks
   Null = M[r5 + $celt.enc.SHORT_BLOCKS_FIELD];
   if NZ call $celt.transient_block_process;
   
   
   call $celt.encode_flags;
   
   // -- quant coarse energy
   call $celt.quant_coarse_energy;
  
   // -- Compute bit allocations
   call $celt.compute_allocation;
   
   // -- Encode fine energy bits
   call $celt.quant_fine_energy;

   // -- Quantise residual bits 
   r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   if Z call $celt.quant_bands;
   r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   if NZ call $celt.quant_bands_stereo;
   
   // -- Finalize energy quantization
   call $celt.quant_energy_finalise;
   
   // -- Complete final steps in encoding frame
   //    this also updates output buffer pointers
   call $celt.end_writing_frame;
   
   // -- Encoding Successful!
   r0 = $codec.SUCCESS;
   jump exit;
   
   exit_not_enough_input_data:
   // set NOT_ENOUGH_OUTPUT_SPACE flag and exit
   r0 = $codec.NOT_ENOUGH_INPUT_DATA;
   
   exit:
   M[r5 + $celt.enc.ENCODER_MODE_FIELD] = r0;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
