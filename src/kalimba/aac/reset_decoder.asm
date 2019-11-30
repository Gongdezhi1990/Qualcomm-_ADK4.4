// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"
#include "core_library.h"

// *****************************************************************************
// MODULE:
//    $aacdec.reset_decoder
//
// DESCRIPTION:
//    This library contains functions to decode AAC and AAC+SBR. This function
//    resets the decoder.
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0, r1, r10, I0, I4
//
// *****************************************************************************
.MODULE $M.aacdec.reset_decoder;
   .CODESEGMENT AACDEC_RESET_DECODER_PM;
   .DATASEGMENT DM;

   $aacdec.reset_decoder:
   

 #ifndef AAC_USE_EXTERNAL_MEMORY
   // reset tmp_mem_pool_end
    r0 = &$aacdec.tmp_mem_pool;
    M[$aacdec.tmp_mem_pool_end] = r0;

  
   // clear the overlap-add buffers
   I0 = &$aacdec.overlap_add_left;
   I4 = &$aacdec.overlap_add_right;
   r10 = LENGTH($aacdec.overlap_add_right);
#else
   r0 =  M[$aacdec.tmp_mem_pool_ptr];//&$aacdec.tmp_mem_pool;
   M[$aacdec.tmp_mem_pool_end_ptr] = r0;

   // clear the overlap-add buffers
   r0 = M[$aacdec.overlap_add_left_ptr];
   I0 = r0;//&$aacdec.overlap_add_left;
   r0 = M[$aacdec.overlap_add_right_ptr];
   I4 = r0;// &$aacdec.overlap_add_right;
   r10 = 576;
#endif 

   r0 = 0;
   do zero_overlap_add;
      M[I0,1] = r0,
       M[I4,1] = r0;
   zero_overlap_add:

   //clear the ics structures
   I0 = &$aacdec.ics_left;
   I4 = &$aacdec.ics_right;
   r10 = $aacdec.ics.STRUC_SIZE;
   do zero_ics_struc;
      M[I0,1] = r0,
       M[I4,1] = r0;
   zero_ics_struc:
  #ifndef AAC_USE_EXTERNAL_MEMORY
   // clear internal buffers
   r10 = LENGTH($aacdec.buf_left);
   I0 = &$aacdec.buf_left;
   I4 = &$aacdec.buf_right;
   #else 
      // clear internal buffers
   r10 = 1024;
   r0 = M[$aacdec.buf_left_ptr]; 
   I0 = r0;
   r0 = M[$aacdec.buf_right_ptr]; 
   I4 = r0;
   r0 = 0;
   #endif 
   do zero_buffer;
      M[I0, 1] = r0,
       M[I4, 1] = r0;
   zero_buffer:


   // clear previous window shape
   M[$aacdec.previous_window_shape_left] = Null;
   M[$aacdec.previous_window_shape_right] = Null;


   // set sampling rate index to -1 to imply start of new file
   r0 = -1;
   M[$aacdec.sf_index] = r0;


   // initial bit reading variables for the start of new file
   M[$aacdec.read_bit_count] = Null;
   r0 = BITPOS_START;
   M[$aacdec.get_bitpos] = r0;


   #ifdef AACDEC_SBR_ADDITIONS
      #ifdef AACDEC_SBR_HALF_SYNTHESIS
         // set in_synth to zero to indicate not half way through synthesis filterbank
         M[$aacdec.in_synth] = Null;
      #endif
   #endif

   // reset mp4 variables
   M[$aacdec.mp4_decoding_started] = Null;
   M[$aacdec.mp4_header_parsed] = Null;
   M[$aacdec.mp4_sequence_flags_initialised] = Null;
   M[$aacdec.mp4_moov_atom_size_ms] = Null;
   M[$aacdec.mp4_moov_atom_size_ls] = Null;
   M[$aacdec.mp4_discard_amount_ms] = Null;
   M[$aacdec.mp4_discard_amount_ls] = Null;
   M[$aacdec.mp4_in_moov] = Null;
   M[$aacdec.mp4_in_discard_atom_data] = Null;
   M[&$aacdec.mdat_size + 2] = Null;
   M[&$aacdec.mdat_size + 1] = Null;
   M[$aacdec.mdat_size] = Null;
   M[$aacdec.sample_count] = Null;
   M[&$aacdec.sample_count + 1] = Null;
   M[$aacdec.mdat_processed] = Null;
   M[$aacdec.mdat_offset + 1] = Null;
   M[$aacdec.mdat_offset] = Null;
   M[$aacdec.mp4_file_offset + 1] = Null;
   M[$aacdec.mp4_file_offset] = Null;
   M[&$aacdec.stsz_offset + 1] = Null;
   M[$aacdec.stsz_offset] = Null;
   M[&$aacdec.stss_offset + 1] = Null;
   M[$aacdec.stss_offset] = Null;
   M[$aacdec.mp4_frame_count] = Null;

   M[$aacdec.mp4_ff_rew_status] = Null;
   M[$aacdec.ff_rew_skip_amount] = Null;
   M[$aacdec.ff_rew_skip_amount + 1] = Null;

   // clear spec_blksigndet
   M[$aacdec.left_spec_blksigndet] = Null;
   M[$aacdec.left_spec_blksigndet + 1] = Null;
   M[$aacdec.right_spec_blksigndet] = Null;
   M[$aacdec.right_spec_blksigndet + 1] = Null;


   #ifdef AACDEC_SBR_ADDITIONS
      // clear X_sbr buffers
      r0 = 0;
      r10 = LENGTH(&$aacdec.X_sbr_2env_imag);
      I0 = &$aacdec.X_sbr_2env_imag;
      I4 = &$aacdec.X_sbr_2env_real;
      do zero_X_sbr_2env_loop;
         M[I0, 1] = r0,
          M[I4, 1] = r0;
      zero_X_sbr_2env_loop:

      r10 = LENGTH(&$aacdec.X_sbr_curr_imag);
      I0 = &$aacdec.X_sbr_curr_imag;
      I4 = &$aacdec.X_sbr_curr_real;
      do zero_X_sbr_curr_loop;
         M[I0, 1] = r0,
          M[I4, 1] = r0;
      zero_X_sbr_curr_loop:

      // clear/initialise x_input buffers
      r10 = LENGTH(&$aacdec.x_input_buffer_left);
      I0 = &$aacdec.x_input_buffer_left;
      I4 = &$aacdec.x_input_buffer_right;
      do zero_x_input_buffer_loop;
         M[I0, 1] = r0,
          M[I4, 1] = r0;
      zero_x_input_buffer_loop:
      r1 = &$aacdec.x_input_buffer_left;
      M[$aacdec.x_input_buffer_write_pointers] = r1;
      r1 = &$aacdec.x_input_buffer_right;
      M[$aacdec.x_input_buffer_write_pointers + 1] = r1;


      // clear/initialise v_buffer buffers
      r10 = LENGTH(&$aacdec.v_buffer_left);
      I0 = &$aacdec.v_buffer_left;
      I4 = &$aacdec.v_buffer_right;
      do zero_v_buffer_loop;
         M[I0, 1] = r0,
          M[I4, 1] = r0;
      zero_v_buffer_loop:

      r1 = &$aacdec.v_buffer_left + 127;
      M[$aacdec.v_left_cbuffer_struc + $cbuffer.READ_ADDR_FIELD] = r1;
      M[$aacdec.v_left_cbuffer_struc + $cbuffer.WRITE_ADDR_FIELD] = r1;

      r1 = &$aacdec.v_buffer_right + 127;
      M[$aacdec.v_right_cbuffer_struc + $cbuffer.READ_ADDR_FIELD] = r1;
      M[$aacdec.v_right_cbuffer_struc + $cbuffer.WRITE_ADDR_FIELD] = r1;


      // clear/initialise X_sbr_other buffers
      r10 = LENGTH(&$aacdec.X_sbr_other_real);
      I0 = &$aacdec.X_sbr_other_real;
      I4 = &$aacdec.X_sbr_other_imag;
      do zero_X_sbr_other_loop;
         M[I0, 1] = r0,
          M[I4, 1] = r0;
      zero_X_sbr_other_loop:


      // clear/initialise sbr_info
      r10 = $aacdec.SBR_SIZE;
      I0 = &$aacdec.sbr_info;
      do zero_sbr_info_loop;
         M[I0, 1] = r0;
      zero_sbr_info_loop:

      M[$aacdec.sbr_info + $aacdec.SBR_num_crc_bits] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_header_count] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_stop_freq] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_stop_freq_prev] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_freq_scale_prev] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_alter_scale_prev] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_xover_band] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_xover_band_prev] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_noise_bands_prev] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_k0] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_k2] = Null;
      M[$aacdec.sbr_info + $aacdec.SBR_kx] = Null;

      r0 = -1;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_start_freq_prev] = r0;

      r0 = 1;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_interpol_freq] = r0;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_smoothing_mode] = r0;
      M[$aacdec.sbr_info + $aacdec.SBR_reset] = r0;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_alter_scale] = r0;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_amp_res] = r0;

      r0 = 2;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_noise_bands] = r0;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_limiter_bands] = r0;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_limiter_gains] = r0;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_freq_scale] = r0;

      r0 = 5;
      M[$aacdec.sbr_info + $aacdec.SBR_bs_start_freq] = r0;

      M[$aacdec.sbr_present] = Null;

      #ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS
         r10 = LENGTH($aacdec.ps_info);
         I0 = &$aacdec.ps_info;
         r0 = 0;
         do zero_ps_info;
            M[I0, 1] = r0;
         zero_ps_info:

         M[$aacdec.parametric_stereo_present] = Null;
      #endif

   #endif

   // discard half word awaiting to be written into the buffer
   M[$aacdec.write_bytepos] = Null;
   
   rts;

.ENDMODULE;
