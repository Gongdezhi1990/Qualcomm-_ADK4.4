// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#include <core_library.h>
#include <cbops_library.h>
#include <md.h>
#include "frame_sync_buffer.h"
#include "music_manager_config.h"
#include "music_example.h"

#include "codec_encoder.h"


.MODULE $M.audio_processing;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

    // Cbuffers that present input data to the audio processing, based
    // on the input metadata lists
    .VAR audio_in_l_cbuffer_struc[$cbuffer.STRUC_SIZE];
    .VAR audio_in_r_cbuffer_struc[$cbuffer.STRUC_SIZE];

    .VAR audio_eq_l_cbuffer_struc[$cbuffer.STRUC_SIZE] = 
           LENGTH($audio_in_left), &$audio_in_left, &$audio_in_left;

    .VAR audio_eq_r_cbuffer_struc[$cbuffer.STRUC_SIZE] = 
           LENGTH($audio_in_right), &$audio_in_right, &$audio_in_right;
		   
		   
    DeclareCBuffer(eq_out_left_cbuffer_struc,  eq_out_left_mem,  $EQ_OUT_CBUFFER_SIZE);
    DeclareCBuffer(eq_out_right_cbuffer_struc, eq_out_right_mem, $EQ_OUT_CBUFFER_SIZE);
   .VAR $eq_out_left_md_list[MD_LIST_STRUC_SIZE]  = 0 ...;
   .VAR $eq_out_right_md_list[MD_LIST_STRUC_SIZE] = 0 ...;

    .VAR md_track_state_l[MD_TRACK_STATE_STRUC_SIZE] =
        &audio_in_l_cbuffer_struc,        // md_track_state.input_cbuffer
        &eq_out_left_cbuffer_struc,        // md_track_state.output_cbuffer
        &$audio_post_csb_left_md_list,    // md_track_state.input_md_list
        &$eq_out_left_md_list,            // md_track_state.output_md_list
        0,                                // md_track_state.algorithmic_delay_samples
        0 ...;
    .VAR md_track_state_r[MD_TRACK_STATE_STRUC_SIZE] =
        &audio_in_r_cbuffer_struc,        // md_track_state.input_cbuffer
        &eq_out_right_cbuffer_struc,      // md_track_state.output_cbuffer
        &$audio_post_csb_right_md_list,   // md_track_state.input_md_list
        &$eq_out_right_md_list,           // md_track_state.output_md_list
        0,                                // md_track_state.algorithmic_delay_samples
        0 ...;

		
    .VAR num_samples_user_eq;
    
    .VAR mute_audio_buffer_addresses[2] = 
           0, // read and write ptr for channel 1
           0; // read and write ptr for channel 2
    .VAR mute_audio_buffer_lengths[2] = 
           0, // read and write buffer length for channel 1
           0; // write and write buffer length for channel 2

    .VAR soft_mute_pre_encoder.param[$cbops.soft_mute_op.STRUC_SIZE_STEREO] =
        1,      // mute direction (1 = unmute audio)
        0,      // index
        2,      // number of channels
        0,      // input index channel 1
        0,      // output index channel 1
        1,      // input index channel 2
        1;      // output index channel 2

// *****************************************************************************
// DESCRIPTION:
//    Initialise the md tracking state
// INPUTS:
//    None
// OUTPUTS:
//    None
// TRASHED REGISTERS:
//    None
// *****************************************************************************
$audio_processing_initialise:
    $push_rLink_macro;
    r0 = &md_track_state_l;
    $call_c_with_void_return_macro(md_track_cbuffers_initialise);
    r0 = &md_track_state_r;
    $call_c_with_void_return_macro(md_track_cbuffers_initialise);

    // TONE MIXER
    r0 = &$M.post_eq.dacout_md_track_state_l;
    $call_c_with_void_return_macro(md_track_cbuffers_initialise);
    r0 = &$M.post_eq.dacout_md_track_state_r;
    $call_c_with_void_return_macro(md_track_cbuffers_initialise);

    jump $pop_rLink_and_rts;

// *****************************************************************************
// DESCRIPTION:
//    Audio processing with automatic metadata handling
// INPUTS:
//    None
// OUTPUTS:
//    r0 - the sum of the number of left and right samples processed
// TRASHED REGISTERS:
//    Assume all
// *****************************************************************************
$audio_processing_user_eq:
    $push_rLink_macro;
	
	M[num_samples_user_eq] = r1;
    
    // Check for Initialization
    NULL = M[$music_example.reinit];
    if NZ call $music_example_reinitialize;

    r0 = M[num_samples_user_eq];
    if Z  jump eq_audio_processing_exit;

    r7 = $M.system_config.data.stream_map_left_in_user_eq;
    r0 = $audio_in_left_cbuffer_struc;
    M[r7] = r0;
    call $cbuffer.get_write_address_and_size;
    I0 = r0;
    L0 = r1;
    
    r10 = M[num_samples_user_eq];
    M0 = -r10;
    r0 = M[I0, M0];
    r0 = I0;  // address where new data was written
    M[r7 + $frmbuffer.FRAME_PTR_FIELD] = r0;
    M[r7 + $frmbuffer.FRAME_SIZE_FIELD] = r10;    
    M[mute_audio_buffer_lengths + 0] = r1;   // read and write address for mute channel 1
    M[mute_audio_buffer_addresses + 0] = r0; // buffer length
 
    r8 = $M.MUSIC_MANAGER.CONFIG.USER_EQ_BYPASS;
    r7 = $M.system_config.data.user_eq_left_dm2; 
    call $music_example.peq.process;

    r7 = $M.system_config.data.stream_map_right_in_user_eq;
    r0 = $audio_in_right_cbuffer_struc;
    M[r7] = r0;
    call $cbuffer.get_write_address_and_size;
    I0 = r0;
    L0 = r1;
    r10 = M[num_samples_user_eq];
    M0 = -r10;
    r0 = M[I0, M0];
    r0 = I0;  // address where new data was written
    M[r7 + $frmbuffer.FRAME_PTR_FIELD] = r0;
    M[r7 + $frmbuffer.FRAME_SIZE_FIELD] = r10;    
    M[mute_audio_buffer_lengths + 1] = r1;   // read and write address for mute channel 2
    M[mute_audio_buffer_addresses + 1] = r0; // buffer length

    r8 = $M.MUSIC_MANAGER.CONFIG.USER_EQ_BYPASS;
    r7 = $M.system_config.data.user_eq_right_dm2; 
    call $music_example.peq.process;

    r6 = &mute_audio_buffer_addresses;
    r7 = &mute_audio_buffer_lengths;
    r8 = &soft_mute_pre_encoder.param;
    r10 = M[num_samples_user_eq];
    call $cbops.soft_mute.main;

eq_audio_processing_exit:
    jump $pop_rLink_and_rts;

$audio_processing:
    $push_rLink_macro;

    r0 = &md_track_state_l;
    $call_c_with_int_return_macro(md_track_cbuffers_pre);
    Null = r0;
    if Z jump audio_processing_exit;
    r0 = &md_track_state_r;
    $call_c_with_int_return_macro(md_track_cbuffers_pre);
    Null = r0;
    if Z jump audio_processing_exit;

    // Check for Initialization
    NULL = M[$music_example.reinit];
    if NZ call $music_example_reinitialize;
 
    r7 = $spkr_eq_obj_table;
    r8 = $NUM_PASS_THRU_OBJ;
    call    $mm_stream_config_framesize;
    Null = r8;
    if Z  jump   skip_processing;
    
    r7 = $spkr_eq_obj_table + $LEFT_PASS_THRU_OBJ_FIELD;
    r8 = $M.MUSIC_MANAGER.CONFIG.SPKR_EQ_BYPASS;
    call    $mm_stream_process_chan;    
    r7 = $spkr_eq_obj_table + $RIGHT_PASS_THRU_OBJ_FIELD;
    r8 = $M.MUSIC_MANAGER.CONFIG.SPKR_EQ_BYPASS;
    call    $mm_stream_process_chan;    
    r7 = &$M.system_config.data.multichannel_volume_and_limit_obj;
    call $volume_and_limit.apply_volume;
skip_processing:
    r0 = &md_track_state_l;
    $call_c_with_int_return_macro(md_track_cbuffers_post);
    push r0;
    r0 = &md_track_state_r;
    $call_c_with_int_return_macro(md_track_cbuffers_post);
    pop r1;
    r0 = r0 + r1;

audio_processing_exit:
    jump $pop_rLink_and_rts;
.ENDMODULE;
