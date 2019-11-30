// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
// *****************************************************************************

#include <core_library.h>
#include <cbops_library.h>
#include <md.h>
#include "frame_sync_buffer.h"
#include "music_manager_config.h"
#include "music_example.h"

#include "codec_decoder.h"

.MODULE $M.audio_processing;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

    // Cbuffers that present input data to the audio processing, based
    // on the input metadata lists
    .VAR audio_in_l_cbuffer_struc[$cbuffer.STRUC_SIZE];
    .VAR audio_in_r_cbuffer_struc[$cbuffer.STRUC_SIZE];

    DeclareCBuffer(eq_out_left_cbuffer_struc,  eq_out_left_mem,  $EQ_OUT_CBUFFER_SIZE);
    DeclareCBuffer(eq_out_right_cbuffer_struc, eq_out_right_mem, $EQ_OUT_CBUFFER_SIZE);
   .VAR $eq_out_left_md_list[MD_LIST_STRUC_SIZE]  = 0 ...;
   .VAR $eq_out_right_md_list[MD_LIST_STRUC_SIZE] = 0 ...;

    .VAR md_track_state_l[MD_TRACK_STATE_STRUC_SIZE] =
        &audio_in_l_cbuffer_struc,          // md_track_state.input_cbuffer
        &eq_out_left_cbuffer_struc,        // md_track_state.output_cbuffer
        &$app.pcm_in_left_md_list,          // md_track_state.input_md_list
        &$eq_out_left_md_list,              // md_track_state.output_md_list
        0,                                  // md_track_state.algorithmic_delay_samples
        0 ...;
    .VAR md_track_state_r[MD_TRACK_STATE_STRUC_SIZE] =
        &audio_in_r_cbuffer_struc,           // md_track_state.input_cbuffer
        &eq_out_right_cbuffer_struc,        // md_track_state.output_cbuffer
        &$app.pcm_in_right_md_list,          // md_track_state.input_md_list
        &$eq_out_right_md_list,              // md_track_state.output_md_list
        0,                                   // md_track_state.algorithmic_delay_samples
        0 ...;

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
