// *****************************************************************************
// Copyright (c) 2003 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// *****************************************************************************
// DESCRIPTION
//    Resampler used to reconcile the codec output sampling rate to the
//    DAC sampling rate. This is used for multi-channel operation and
//    is performed before channel splitting (before the Music manager) in
//    order to reduce MIPS.
//
// *****************************************************************************

#include "codec_decoder.h"

// CODEC resampler module
.MODULE $M.codec_resampler;
   .DATASEGMENT DM;

    .CONST $RESOLUTION_MODE_16BIT                           16;             // 16bit resolution mode
    .CONST $RESOLUTION_MODE_24BIT                           24;             // 24bit resolution mode

    // define cbuffer to track for resampler  operation.
   .VAR codec_resamp_in_left_cbuffer_struc[$cbuffer.STRUC_SIZE] = 0 ...;
   .VAR codec_resamp_in_right_cbuffer_struc[$cbuffer.STRUC_SIZE] = 0 ...;
   
   
    .VAR resamp_out_md_track_state_l[MD_TRACK_STATE_STRUC_SIZE] =
        &codec_resamp_in_left_cbuffer_struc,      // md_track_state.input_cbuffer
        &$app.pcm_out_left_cbuffer_struc,         // md_track_state.output_cbuffer
        &$eq_out_left_md_list,                    // md_track_state.input_md_list
        &$app.pcm_out_left_md_list,               // md_track_state.output_md_list
        0,                                        // md_track_state.algorithmic_delay_samples
        0 ...;
    .VAR resamp_out_md_track_state_r[MD_TRACK_STATE_STRUC_SIZE] =
        &codec_resamp_in_right_cbuffer_struc,     // md_track_state.input_cbuffer
        &$app.pcm_out_right_cbuffer_struc,        // md_track_state.output_cbuffer
        &$eq_out_right_md_list,                   // md_track_state.input_md_list
        &$app.pcm_out_right_md_list,               // md_track_state.output_md_list
        0,                                        // md_track_state.algorithmic_delay_samples
        0 ...;
		
   
   
   // Lookup table used to determine cbops/resampler structure values given codec rate and DAC rate
   // (Codec rate, DAC rate, filter spec)
   .CONST record_size 3;
   .VAR filter_spec_lookup_table[] =
      // Input rates with no resampling
      96000, 96000, 0,
      88200, 88200, 0,
      48000, 48000, 0,
      44100, 44100, 0,
      32000, 32000, 0,
      22050, 22050, 0,
      16000, 16000, 0,
      8000, 8000, 0,
#ifdef HI_RATE_MUSIC_MANAGER_SUPPORT
      // Hi-res output rates
      44100, 96000, $M.iir_resamplev2.Up_320_Down_147.filter,
      48000, 96000, $M.iir_resamplev2.Up_2_Down_1.filter,
      88200, 96000, $M.iir_resamplev2.Up_160_Down_147.filter,
      44100, 88200, $M.iir_resamplev2.Up_2_Down_1.filter,
      48000, 88200, $M.iir_resamplev2.Up_147_Down_80.filter,
      96000, 88200, $M.iir_resamplev2.Up_147_Down_160.filter,
      
     // Hi-res resampled input rates
      88200, 48000, $M.iir_resamplev2.Up_80_Down_147.filter,
      96000, 48000, $M.iir_resamplev2.Up_1_Down_2.filter,
      88200, 44100, $M.iir_resamplev2.Up_1_Down_2.filter,
      96000, 44100, $M.iir_resamplev2.Up_147_Down_320.filter,
#endif ///HI_RATE_MUSIC_MANAGER_SUPPORT
      // Standard resampled input rates
      16000, 48000, $M.iir_resamplev2.Up_3_Down_1.filter,
      32000, 48000, $M.iir_resamplev2.Up_3_Down_2.filter,
//      44100, 48000, $M.iir_resamplev2.Up_160_Down_147.filter,
      44100, 48000, $M.iir_resamplev2.Up_160_Down_147_low_mips.filter,      
      16000, 44100, $M.iir_resamplev2.Up_441_Down_160.filter,
      32000, 44100, $M.iir_resamplev2.Up_441_Down_320.filter,
      48000, 44100, $M.iir_resamplev2.Up_147_Down_160.filter,
      0;
   
   // Flag showing whether the resampling is active
   .VAR resampler_configured = 0;
   // Flag to indicate a rate error has occurred
   .VAR rate_error = 0;
   // add current coding sampling rate
   // it should be configured through VM message or derived from MD blocks
   // Variables to receive dac and codec sampling rates from the vm
   .VAR $current_dac_sampling_rate = 0;                              // Dac sample rate, set by message from VM
   .VAR $set_dac_rate_from_vm_message_struc[$message.STRUC_SIZE];    // Message structure for VM_SET_DAC_RATE_MESSAGE_ID message
   .VAR $current_codec_sampling_rate = 0;                            // codec data sample rate, set by vm
   .VAR $set_codec_rate_from_vm_message_struc[$message.STRUC_SIZE];  // Message structure for VM_SET_CODEC_RATE_MESSAGE_ID message
   .VAR $procResolutionMode = $RESOLUTION_MODE_16BIT;
   

   .VAR   iir_temp[$TEMP_BUFF_SIZE];                                                           
   
   .VAR left[$iir_resamplev2.OBJECT_SIZE] =
      &codec_resamp_in_left_cbuffer_struc,                              // $iir_resamplev2.INPUT_1_START_INDEX_FIELD              0;
      &$app.pcm_out_left_cbuffer_struc,                            	    // $iir_resamplev2.OUTPUT_1_START_INDEX_FIELD             1;
      // Filter Definition
      0,                                                                // $iir_resamplev2.FILTER_DEFINITION_PTR_FIELD            2;
      -8,                                                               // $iir_resamplev2.INPUT_SCALE_FIELD                      3;
      8,                                                                // $iir_resamplev2.OUTPUT_SCALE_FIELD                     4;
      // Buffer between Stages
      iir_temp,                                                         // $iir_resamplev2.INTERMEDIATE_CBUF_PTR_FIELD            5;
      length(iir_temp),                                                 // $iir_resamplev2.INTERMEDIATE_CBUF_LEN_FIELD            6;
      0,                                                                // $iir_resamplev2.RESET_FLAG_FIELD                       7;
      0,                                                                // $iir_resamplev2.DBL_PRECISSION_FIELD                   8;
      // 1st Stage
      0,                                                                // $iir_resamplev2.PARTIAL1_FIELD                         9;
      0,                                                                // $iir_resamplev2.SAMPLE_COUNT1_FIELD                    10;
      0,                                                                // $iir_resamplev2.FIR_HISTORY_BUF1_PTR_FIELD             11;
      0,                                                                // $iir_resamplev2.IIR_HISTORY_BUF1_PTR_FIELD             12;
      // 2nd Stage
      0,                                                                // $iir_resamplev2.PARTIAL2_FIELD                         13;
      0,                                                                // $iir_resamplev2.SAMPLE_COUNT2_FIELD                    14;
      0,                                                                // $iir_resamplev2.FIR_HISTORY_BUF2_PTR_FIELD             15;
      0,                                                                // $iir_resamplev2.IIR_HISTORY_BUF2_PTR_FIELD             16;
      // Reset Flags (Set to NULL)
      0 ...;                                                            // Zero the history buffers                               17...;

   .VAR right[$iir_resamplev2.OBJECT_SIZE] =
      &codec_resamp_in_right_cbuffer_struc,                             // $iir_resamplev2.INPUT_1_START_INDEX_FIELD              0;
      &$app.pcm_out_right_cbuffer_struc,                          		// $iir_resamplev2.OUTPUT_1_START_INDEX_FIELD             1;
      // Filter Definition
      0,                                                                // $iir_resamplev2.FILTER_DEFINITION_PTR_FIELD            2;
      -8,                                                               // $iir_resamplev2.INPUT_SCALE_FIELD                      3;
      8,                                                                // $iir_resamplev2.OUTPUT_SCALE_FIELD                     4;
      // Buffer between Stages
      iir_temp,                                                         // $iir_resamplev2.INTERMEDIATE_CBUF_PTR_FIELD            5;
      length(iir_temp),                                                 // $iir_resamplev2.INTERMEDIATE_CBUF_LEN_FIELD            6;
      0,                                                                // $iir_resamplev2.RESET_FLAG_FIELD                       7;
      0,                                                                // $iir_resamplev2.DBL_PRECISSION_FIELD                   8;
      // 1st Stage
      0,                                                                // $iir_resamplev2.PARTIAL1_FIELD                         9;
      0,                                                                // $iir_resamplev2.SAMPLE_COUNT1_FIELD                    10;
      0,                                                                // $iir_resamplev2.FIR_HISTORY_BUF1_PTR_FIELD             11;
      0,                                                                // $iir_resamplev2.IIR_HISTORY_BUF1_PTR_FIELD             12;
      // 2nd Stage
      0,                                                                // $iir_resamplev2.PARTIAL2_FIELD                         13;
      0,                                                                // $iir_resamplev2.SAMPLE_COUNT2_FIELD                    14;
      0,                                                                // $iir_resamplev2.FIR_HISTORY_BUF2_PTR_FIELD             15;
      0,                                                                // $iir_resamplev2.IIR_HISTORY_BUF2_PTR_FIELD             16;
      // Reset Flags (Set to NULL)
      0 ...;                                                            // Zero the history buffers                               17...;
   
// *****************************************************************************
// MODULE:
//    $codec_resample.run_resampler
//
// DESCRIPTION:
//    utility function that runs the resampler for main chain
//
// INPUTS:
//    - r5: framesize
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    Assume everything
//
// *****************************************************************************
   .CODESEGMENT PM;

run_resampler:

    // bypass resampler if not active, activated through configuration.
    Null = M[resampler_configured];
    if Z rts;

    // Push rLink onto stack
    $push_rLink_macro;
    
    // update resampler's input cbuffer structure's read and write address from md_list so cbuffer has correct amount of input data. 
    r0 = &resamp_out_md_track_state_l;
    $call_c_with_int_return_macro(md_track_cbuffers_pre);
    Null = r0;
    if Z jump run_resampler_done;
    r0 = &resamp_out_md_track_state_r;
    $call_c_with_int_return_macro(md_track_cbuffers_pre);
    Null = r0;
    if Z jump run_resampler_done;
   
    // process head md 
    // get number of input samples in head md
    r2 = M[&$eq_out_left_md_list]; // head
    r5 = M[r2 + MD_NUM_WORDS_FIELD_INDEX];
    push r5; // number of input samples we need to process

    // Get Data/Space
    r8 = left;
    r0 = M[r8 + $iir_resamplev2.INPUT_1_START_INDEX_FIELD];
    call $cbuffer.calc_amount_data;
    r6 = r0;
    r0 = M[r8 + $iir_resamplev2.OUTPUT_1_START_INDEX_FIELD];
    call $cbuffer.calc_amount_space;
    r7 = r0;
    call $iir_resamplev2.amount_to_use;
    // r5 is the amount of samples resampler can process given number of input samples, space in output buffer, and space in temporary buffer
    pop r4; // number of samples in head md
    r0 = Null;  // in case we exit without processing
    Null = r5 - r4;  // r4 must be smaller than or equal to r5 to continue
    if NEG jump run_resampler_done;  // can't process a frame.

    // get number of input samples in head md
    r5 = r4;
    push r5;  // number of samples to process

    // resample left channel
    // r5 = framesize
    r8 = left;
    call $iir_resamplev2.Limited_Process;
   
    // resample right channel
    // r5 = framesize
    pop  r5;
    r8 = right;
    call $iir_resamplev2.Limited_Process;

    r0 = &resamp_out_md_track_state_l;
    r1 = M[$current_dac_sampling_rate];
    $call_c_with_int_return_macro(md_track_cbuffers_post_resampler);
    push r0;
    r0 = &resamp_out_md_track_state_r;
    r1 = M[$current_dac_sampling_rate];
    $call_c_with_int_return_macro(md_track_cbuffers_post_resampler);
    pop r1;
    r0 = r0 + r1;
		
   run_resampler_done:
   // Pop rLink from stack
   jump $pop_rLink_and_rts;

// *****************************************************************************
// MODULE:
//    $M.codec_resampler
//
// DESCRIPTION:
//    Configure the codec resampler to perform the required sampling rate
//    change. This modifies the resampler structures with values appropriate
//    for the sampling rate change.
//
//    Uses $current_codec_sampling_rate and $current_dac_sampling_rate
//    to determine the configuration required.
//
// INPUTS:
//    r7:  M[procResolutionMode]
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0, r1, r2, r3, r4, r5, r6, r10, DoLoop;
//
// *****************************************************************************
   .CODESEGMENT PM;

   config:
   
   // // only configured once 
   Null = M[resampler_configured];
   if  NZ  rts;     
   
    // config only when codec and dac are all configured
   r1 = M[$current_codec_sampling_rate];
   if  Z  rts;
   r2 = M[$current_dac_sampling_rate];
   if  Z  rts;
   
   // set algorithmic delay if resampling from 44.1 to 48 kHz
   Null = r1 - 44100;
   if NZ jump continue;
   
   Null = r2 - 48000;
   if NZ jump continue;
   
   r0 = 14;
   M[resamp_out_md_track_state_l + 4] = r0;
   M[resamp_out_md_track_state_r + 4] = r0;   

continue:
   // Push rLink onto stack
   $push_rLink_macro;

   // reset error flag before configuration
   M[rate_error] = Null;

   // Point to first record in the resampler lookup table
   r1 = filter_spec_lookup_table;
   r2 = M[$current_codec_sampling_rate];                                         // Codec/input rate
   r3 = M[$current_dac_sampling_rate];                                           // Processing/output rate (before any ANC resampling)
   call $lookup_2_in_1_out;                                                      // r0 = filter spec. pointer, r1 = matching record pointer, r3 = status (0: match, 1: no match)
   null = r3;                                                                    // Match?
   if Z jump match_found;                                                        // Yes - set up the resampler

      // Invalid rates are configured, send error message and perform fatal error

      // Get the requested rates
      r3 = M[$current_codec_sampling_rate];
      r4 = M[$current_dac_sampling_rate];

      // Scale down rates by 10 to fit into 16bit words
      r0 = 10;
      rMAC = r3;
      Div = rMAC/r0;
      r3 = DivResult;
      rMAC = r4;
      Div = rMAC/r0;
      r4 = DivResult;

      // Report the error to the VM
      r2 = UNSUPPORTED_SAMPLING_RATES_MSG;
      call $message.send_short;

      // Don't call fatal $error since S/PDIF input rate is dynamic (and may change to a valid rate)
      // (just store a flag for debug purposes)
      r0 = 1;
      M[rate_error] = r0;

   match_found:
   
   
   call $block_interrupts;

   // Set the resampler precision flag according to the resolution mode
   // r7 = M[$procResolutionMode];
   r0 = 0;                                            // Precision flag for 16bit resolution mode
   r2 = 1;                                            // Precision flag for 24bit resolution mode
   null = r7 - $RESOLUTION_MODE_24BIT;                // 24bit?
   if Z r0 = r2;                                      //

   // Configure the precision for the resampler
   M[left + $iir_resamplev2.DBL_PRECISSION_FIELD] = r0;
   M[right + $iir_resamplev2.DBL_PRECISSION_FIELD] = r0;
   
   
   // Force a reset (set the reset field in the filter parameters to 0)
   M[left  + $iir_resamplev2.RESET_FLAG_FIELD] = 0;
   M[right + $iir_resamplev2.RESET_FLAG_FIELD] = 0;

   // Filter specifications in the resampler structure
   r0 = M[r1+2];
   M[left  + $iir_resamplev2.FILTER_DEFINITION_PTR_FIELD] = r0;
   M[right + $iir_resamplev2.FILTER_DEFINITION_PTR_FIELD] = r0;
   
   // Store a flag indicating whether resampling is being configured
   r2 = $cbops.switch_op.ON;
   Null = M[rate_error];
   if  NZ r2 = Null;
   M[resampler_configured] = r2;

   
   // Calculate the adjustment factor needed to modify the SRA calculation
   // commented out for BA, since resampling happens before SRA module.
   // call $calc_sra_resampling_adjustment;

   call $unblock_interrupts;

   // Pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

// VM messaging, restored to traditional sample rate mes 

// *****************************************************************************
// MODULE:
//    $set_dac_rate_from_vm
//
// DESCRIPTION: message handler for receiving DAC rate from VM
//
// INPUTS:
//  r1 = dac sampling rate/10 (e.g. 44100Hz is given by r1=4410)
//  r2 = maximum clock mismatch to compensate (r2/10)%
//       (Bit7==1 disables the rate control, e.g 0x80)
//  r3 = bit0: if long term mismatch rate saved bits(15:1): saved_rate>>5
//
//  [r4 = bits(1:0): DEPRECATED in multi-channel implementation
//                  audio output interface type:
//                  0 -> None (not expected)
//                  1 -> Analogue output (DAC)
//                  2 -> I2S output
//                  3 -> SPDIF output]
//
//  r4 = bit8: playback mode (0: remote playback, 1: local file play back)
//       bit9: pcm playback, releavant only when b8==1
// *****************************************************************************
.MODULE $M.set_dac_rate_from_vm;
   .CODESEGMENT PM;

$set_dac_rate_from_vm:

   // Mask sign extension
   r1 = r1 AND 0xffff;

   // Scale to get sampling rate in Hz
   r1 = r1 * 10 (int);

   // Store the parameters
   M[$current_dac_sampling_rate] = r1;                // DAC sampling rate (e.g. 44100Hz is given by r1=44100)
   
   push rLink; 
   //configure audio dac output module for new sample rate
   r0 = r1;
   $call_c_with_void_return_macro(audio_output_set_rate);
   

   r7 = M[$procResolutionMode];
   call $M.codec_resampler.config;


/*  M[$max_clock_mismatch] = r2;                       // Maximum clock mismatch to compensate (r2/10)% (Bit7==1 disables the rate control, e.g 0x80)
   M[$long_term_mismatch] = r3;                       // bit0: if long term mismatch rate saved bits(15:1): saved_rate>>5
   // b8 b9    encoded   pcm
   // 0  x       N        N
   // 1  0       Y        N
   // 1  1       N        Y
   r1 = r4 AND $PCM_PLAYBACK_MASK;                    // Mask for pcm/coded bit
   r2 = r1 XOR $PCM_PLAYBACK_MASK;
   r0 = r4 AND $LOCAL_PLAYBACK_MASK;                  // Mask for local file play back info
   r2 = r2 * r0 (int)(sat);
   M[$local_encoded_play_back] = r2;                  // encoded play back
   r3 = 0x1;
   r1 = r1 * r0 (int)(sat);
   if NZ r1 = r3;
   M[$aux_input_stream_available] = r1;               // aux pcm stream play back

   // update inverse of dac sample rate
   push rLink;
   r0 = M[$current_dac_sampling_rate];
   call $latency.calc_inv_fs;
   M[$intermediate_fs_1] = r0;      */

   pop rLink;     
   rts;
   
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $set_codec_rate_from_vm
//
// DESCRIPTION: message handler for receiving codec rate from VM
//
// INPUTS:
//  r1 = codec sampling rate/10 (e.g. 44100Hz is given by r1=4410)
//  r2 =
//  r3 =
//  r4 =
// *****************************************************************************
.MODULE $M.set_codec_rate_from_vm;
   .CODESEGMENT PM;

$set_codec_rate_from_vm:

   // Mask sign extension
   r1 = r1 AND 0xffff;

   // Scale to get sampling rate in Hz
   r1 = r1 * 10 (int);

   // Store the codec sampling rate
   M[$current_codec_sampling_rate] = r1;

/* // removed inv rate calc, not used
   // update inverse of codec sample rate
   push rLink;
   r0 = M[$current_codec_sampling_rate];
   call $latency.calc_inv_fs;
   M[$inv_codec_fs] = r0;
   pop rLink;  */

    // reinitialize the music manager
    M[$music_example.reinit] = r1;

    $push_rLink_macro;
    
    // configure the csb input for new sample rate
    r0 = &$app.csb_input;
    // r1 has codec rate
    $call_c_with_void_return_macro(csb_input_set_sample_rate);
    r0 = 1;
    M[$app.sr_change_complete] = r0;    

    r7 = M[$procResolutionMode];
    call $M.codec_resampler.config;

    // pop rLink from stack
    jump $pop_rLink_and_rts;

.ENDMODULE;


