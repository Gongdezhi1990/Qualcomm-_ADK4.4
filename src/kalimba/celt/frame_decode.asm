// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_FRAME_DECODE_INCLUDED
#define CELT_FRAME_DECODE_INCLUDED
#include "stack.h"
#include "codec_library.h"
// *****************************************************************************
// MODULE:
//    $celt.frame_decode
//
// DESCRIPTION:
//    Decode a CELT frame
//
// INPUTS:
//    - r5 = pointer to a $celt.dec structure, 
//           see header file for definition of structure fields
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    assume everything
//
// NOTES:
//    - left output channel must always be valid(it is not checked)
//    - stereo decode not implemented yet
//    - for mono stream, mono to stereo conversion is performed if right output channel is available
// *****************************************************************************
.MODULE $M.celt.frame_decode;
   .CODESEGMENT CELT_FRAME_DECODE_PM;
   .DATASEGMENT DM;
 
   $celt.frame_decode:

   // push rLink onto stack
   $push_rLink_macro;

   // -- Save codec struct pointer --
   M[$celt.dec.codec_struc] = r5;
   
   // -- No output samples yet
   M[r5 + $celt.dec.DECODER_NUM_OUTPUT_SAMPLES_FIELD] = 0;
   
   //-- Is re-init required?
   Null = M[r5 + $celt.dec.REINIT_DECODER_FIELD];
   if NZ call $celt.decoder_init;
   
   // -- See if there is enough output space
   r4 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
   r0 = M[r5 + $celt.dec.DECODER_OUT_LEFT_BUFFER_FIELD];
   call $cbuffer.calc_amount_space;
   Null = r0 - r4;
   if NEG jump exit_not_enough_output_space;
   r0 = M[r5 + $celt.dec.DECODER_OUT_RIGHT_BUFFER_FIELD];
   if Z jump end_space_check;
      call $cbuffer.calc_amount_space;
      Null = r0 - r4;
      if NEG jump exit_not_enough_output_space;
   end_space_check:
   
   // save output buffer addresses
   r0 = M[r5 + $celt.dec.DECODER_OUT_LEFT_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   M[$celt.dec.left_obuf_start_addr] = r2;
#else   
   call $cbuffer.get_write_address_and_size;
#endif
   M[$celt.dec.left_obuf_addr] = r0;
   M[$celt.dec.left_obuf_len] = r1;
   r0 = M[r5 + $celt.dec.DECODER_OUT_RIGHT_BUFFER_FIELD];
   if Z jump end_ch_addr_save;
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   M[$celt.dec.right_obuf_start_addr] = r2;
#else  
   call $cbuffer.get_write_address_and_size;
#endif
      M[$celt.dec.right_obuf_addr] = r0;
      M[$celt.dec.right_obuf_len] = r1;
   end_ch_addr_save:
   
   // see if PLC is required to run
   #ifdef $celt.INCLUDE_PLC
      r0 = M[r5 + $celt.dec.RUN_PLC_FIELD];
      r1 = M[r5 + $celt.dec.PLC_ENABLED_FIELD];
      r0 = r0 AND r1;
      if Z jump no_plc_run;
         call $celt.run_plc;
      jump post_proc;   
      no_plc_run:
      M[r5 + $celt.dec.PLC_COUNTER_FIELD] = Null;
   #endif
   //-- See if there is at least one frame 
   r0 = M[r5 + $celt.dec.DECODER_IN_BUFFER_FIELD];
   call $cbuffer.calc_amount_data;
   r0 = r0 + r0;
   r1 = M[r5 + $celt.dec.GET_BYTE_POS_FIELD];
   r2 = r0 + r1;
   r2 = r2 - 1;
   r1 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r0 = $codec.NOT_ENOUGH_INPUT_DATA;
   Null = r2 - r1;
   if NEG jump exit;
 
   // -- Initialise frame decoder
   call $celt.decoder_frame_init;
   
   // -- Extract flags
   call $celt.decode_flags;
   M[$celt.dec.frame_corrupt] = r0;
   if NZ jump frame_corrupt;
   
   // -- Unquantise Coarse Energies
   call $celt.unquant_coarse_energy;
   
   // -- Compute bit allocations
   call $celt.compute_allocation;
   
   // -- Decode fine energy bits
   call $celt.unquant_fine_energy;
   
   // -- Dequantise residual bits 
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   if Z call $celt.unquant_bands;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   if NZ call $celt.unquant_bands_stereo;
   
   // -- Decode remaining bits
   call $celt.unquant_energy_finalise;
   
   // -- MDCT shape for some short encoded frames
   r8 = $celt.CELT_DECODER;
   Null = M[r5 + $celt.dec.MDCT_WEIGHT_SHIFT_FIELD];
   if NZ call  $celt.mdct_shape;
 
   // -- Denormalising bands
   call $celt.denormalise_bands;
 
   // -- Input frame processed, terminate reading
   call $celt.end_reading_frame;
   
   //-- TODO: Do optional stereo to mono processing here
   
   // -- Apply windowing and overlap add
   call $celt.imdct_window_overlap_add;
   
   post_proc:   
   // -- fill plc history buffers
   #ifdef $celt.INCLUDE_PLC
      r1 = M[r5 + $celt.dec.PLC_ENABLED_FIELD];
      if NZ call $celt.fill_plc_buffers; 
   #endif
   
   // -- Apply final de-emphasis filter  
   call $celt.deemphasis;
   
   //-- Mono to stereo convert
   Null = M[$celt.dec.mono_to_stereo];
   if Z jump end_mono_to_stereo_convert;
   r10 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
   r0 = M[$celt.dec.left_obuf_addr];
   r1 = M[$celt.dec.left_obuf_len];
   I5 = r0;
   L5 = r1;
   r0 = M[$celt.dec.right_obuf_addr];
   r1 = M[$celt.dec.right_obuf_len];
   I4 = r0;
   L4 = r1;
#ifdef BASE_REGISTER_MODE
   r0 = M[$celt.dec.left_obuf_start_addr];
   push r0;
   pop B5;
   r0 = M[$celt.dec.right_obuf_start_addr];
   push r0;
   pop B4;
#endif 
   do copy_left_to_right_loop;
      r0 = M[I5, 1];
      M[I4, 1] = r0;
   copy_left_to_right_loop:
   L4 = 0;
   L5 = 0;   
#ifdef BASE_REGISTER_MODE
   push Null;
   pop B4;
   push Null; 
   pop B5; 
#endif 

   end_mono_to_stereo_convert:
   
   // -- Stereo to mono convert
   // Celt library doesnt do this at the moment   
   //-- Set write address for left channel
   r0 = M[r5 + $celt.dec.DECODER_OUT_LEFT_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   push r2;
   pop  B5;
#else  
   call $cbuffer.get_write_address_and_size;
#endif
   I5 = r0;
   L5 = r1;
   r0 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
   M0 = r0;
   r0 = M[I5, M0];
   r0 = M[r5 + $celt.dec.DECODER_OUT_LEFT_BUFFER_FIELD];
   r1 = I5;
   call $cbuffer.set_write_address;
   
   //-- Set write address for right channel
   r0 = M[r5 + $celt.dec.DECODER_OUT_RIGHT_BUFFER_FIELD];
   if Z jump end_buffer_set_write_address;
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   push r2;
   pop  B5;
#else     
   call $cbuffer.get_write_address_and_size;
#endif
   I5 = r0;
   L5 = r1;
   r0 = M[I5, M0];
   r0 = M[r5 + $celt.dec.DECODER_OUT_RIGHT_BUFFER_FIELD];
   r1 = I5;
   call $cbuffer.set_write_address;
   end_buffer_set_write_address:
   L5 = 0;
#ifdef BASE_REGISTER_MODE
   push Null;
   pop  B5;
#endif
   
   // -- Decoding Successful
   r0 = M0;
   M[r5 + $celt.dec.DECODER_NUM_OUTPUT_SAMPLES_FIELD] = r0;
   r0 = $codec.SUCCESS;
   jump exit;
   
   // check if any errors occured
   frame_corrupt:
      call $celt.end_reading_frame;
      r0 = $codec.FRAME_CORRUPT;
      jump exit;
 
   exit_not_enough_output_space:
   // set NOT_ENOUGH_OUTPUT_SPACE flag and exit
   r0 = $codec.NOT_ENOUGH_OUTPUT_SPACE;
   
   exit:
   M[r5 + $codec.DECODER_MODE_FIELD] = r0;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
