// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// DESCRIPTION
//    Decoder for an audio playing device (non USB)
//
// *****************************************************************************

#include "codec_decoder.h"


.MODULE $M.main;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $_main:


   .VAR $app.audio_port_ids[7] =
       $AUDIO_LEFT_OUT_PORT,
       $AUDIO_RIGHT_OUT_PORT,
       $CSB_IN_PORT,
       0,
       0,
       0,
       0;

   // allocate cbuffers and cbuffer structures
   .VAR/DMCIRC $app.codec_cbuffer[4096];
   .VAR $app.codec_cbuffer_struc[$cbuffer.STRUC_SIZE] =
         LENGTH($app.codec_cbuffer),              // size
         &$app.codec_cbuffer,                     // read pointer
         &$app.codec_cbuffer;                     // write pointer

    .VAR/DMCIRC $app.pcm_in_left_cbuffer[4096];
    .VAR $app.pcm_in_left_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($app.pcm_in_left_cbuffer),            // size
        &$app.pcm_in_left_cbuffer,                   // read pointer
        &$app.pcm_in_left_cbuffer;                   // write pointer

    .VAR/DMCIRC $app.pcm_in_right_cbuffer[4096];
    .VAR $app.pcm_in_right_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($app.pcm_in_right_cbuffer),           // size
        &$app.pcm_in_right_cbuffer,                  // read pointer
        &$app.pcm_in_right_cbuffer;                  // write pointer

    .VAR/DMCIRC $app.pcm_out_left_cbuffer[4096];
    .VAR $app.pcm_out_left_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($app.pcm_out_left_cbuffer),            // size
        &$app.pcm_out_left_cbuffer,                   // read pointer
        &$app.pcm_out_left_cbuffer;                   // write pointer

    .VAR/DMCIRC $app.pcm_out_right_cbuffer[4096];
    .VAR $app.pcm_out_right_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($app.pcm_out_right_cbuffer),           // size
        &$app.pcm_out_right_cbuffer,                  // read pointer
        &$app.pcm_out_right_cbuffer;                  // write pointer

    // allocate memory for timer structures
    .VAR $app.timer_struc[$timer.STRUC_SIZE];
    .VAR $app.timer_event_id;

    // allocate memory for message structures
    .VAR $message.handler_struc[$message.STRUC_SIZE];
    .VAR $fw_bdaddr_message.handler_struc[$message.STRUC_SIZE];
    .VAR $fw_audio_message.handler_struc[$message.STRUC_SIZE];

    .VAR $_wall_clock_struc[$wall_clock.STRUC_SIZE] =
        0,                      // next wall_clock
        0, 0, 0, 0,             // bd_addr
        0,                      // adjustment
        &$wall_clock.callback,  // callback
        0 ...;

    .VAR $wall_clock.running = 0;

    // Metadata lists
    .VAR/DM $app.codec_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR/DM $app.pcm_in_left_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR/DM $app.pcm_in_right_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR/DM $app.pcm_out_left_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR/DM $app.pcm_out_right_md_list[MD_LIST_STRUC_SIZE] = 0 ...;

    // Settings / parameters
    .VAR $app.ec_input[EC_INPUT_STRUC_SIZE] =
        $CSB_IN_PORT,                  // ec_input_t.params.input_port
        0,                             // ec_input_t.params.stream_id
        0 ...;                         // ec_input_t.state (internal)

    // For frame info library (initialising to zero indicates to the frame
    // info library that the parameters are uninitialised).
    .BLOCK $celt_decoder_parameters;
    .VAR $_celt_decoder_frame_size_octets_44100 = 0;
    .VAR $_celt_decoder_frame_samples_44100     = 0;
    .VAR $_celt_decoder_frame_size_octets_48000 = 0;
    .VAR $_celt_decoder_frame_samples_48000     = 0;
    .VAR $_celt_decoder_frame_channels          = 0;
    .ENDBLOCK;

    .VAR $app.csb_input[CSB_INPUT_STRUC_SIZE] =
        &$app.scmr_params,             // csb_input_t.params.scmr_params;
        &$app.codec_md_list,           // csb_input_t.params.codec_md_list
        &$app.codec_cbuffer_struc,     // csb_input_t.params.codec_cbuffer
        $_get_frame_info_celt_decoder, // csb_input_t.params.get_frame_info_fn
        0,                             // csb_input_t.params.frame_header_length_octets
        0,                             // csb_input_t.params.frame_header_buffer
        SR_FREQUENCY_BITFIELD_44100 |
        SR_FREQUENCY_BITFIELD_48000,   // csb_input_t.params.supported_sample_rates_bitfield
        0 ...;                         // csb_input_t.state (internal)

    .VAR $app.csb_decoder_params[CSB_DECODER_PARAMS_STRUC_SIZE] =
        &$app.codec_md_list,              // csb_decoder_params.codec_md_list
        &$app.codec_cbuffer_struc,        // csb_decoder_params.codec_cbuffer_struc
        &$app.pcm_in_left_md_list,        // csb_decoder_params.pcm_left_md_list
        &$app.pcm_in_right_md_list,       // csb_decoder_params.pcm_right_md_list
        &$app.pcm_in_left_cbuffer_struc,  // csb_decoder_params.pcm_left_cbuffer_struc
        &$app.pcm_in_right_cbuffer_struc, // csb_decoder_params.pcm_right_cbuffer_struc
        $_celt_decode_frame,              // csb_decoder_params.csb_decode_frame_fn
       $CLOCK_SOURCE_WALL_CLOCK;      // csb_decoder_params.system_time_source

    .VAR $app.scmr_params[SCMR_PARAMS_STRUC_SIZE] =
        $app.scmr_segment_ind,
        $app.scmr_segment_expired,
        0 ...;

    // Use the API to setup the parameters
    .VAR $app.aesccm_params[AESCCM_PARAMS_STRUC_SIZE] = 0 ...;

    // Define the clock sources and the params so each clock time can be read
    .CONST $CLOCK_SOURCE_WALL_CLOCK  0;
    .VAR $app.clock_params_wall_clock[SYSTEM_TIME_CLOCK_PARAMS_STRUC_SIZE] =
        $_wall_clock_get_time, // system_time_clock_params.get_clock_fn
        &$_wall_clock_struc,       // system_time_clock_params.arg
        0,                         // system_time_clock_params.offset
        0;                         // system_time_clock_params.active

    .VAR $app.csb_audio_status;

    // Volume variables
    .VAR $app.local_volume = 0; // The local volume set by the VM
    .VAR $app.current_volume = 0; // The current volume (heading towards the target)
    .VAR $app.target_volume = 0; // The desired volume
    .VAR $app.csb_volume = 0; // The global csb volume
    .VAR $app.volume_timer;
    .VAR $app.sr_change_complete = 0;

    .VAR $app.audio_output_ports_disconnected = 1 << $AUDIO_OUT_LEFT_PORT_NUMBER | 1 << $AUDIO_OUT_RIGHT_PORT_NUMBER;

    .VAR/DMCIRC $csb_metadata_buffer[128];
    .VAR $csb_metadata_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($csb_metadata_buffer),   // size
        &$csb_metadata_buffer,          // read pointer
        &$csb_metadata_buffer;          // write pointer	

    // initialise the interrupt library
    call $interrupt.initialise;

    // initialise the message library
    call $message.initialise;

    // initialise the cbuffer library
    call $cbuffer.initialise;

    // register cbuffer for CSB port metadata
    r0 = $CSB_IN_PORT;
    r1 = &$csb_metadata_cbuffer_struc;
    call $cbuffer.register_metadata_cbuffer;

    r0 = &$app.write_port_disconnect_callback;
    M[$cbuffer.write_port_disconnect_address] = r0;
    r0 = &$app.write_port_connect_callback;
    M[$cbuffer.write_port_connect_address] = r0;

    // initialise the pskey library
    call $pskey.initialise;
    
    // prevent null pointers
    M[$M.prevent_using_addr_0.dummy_var] = Null;

#ifdef INCLUDE_PROFILER
    .VAR/DM1 $profiler.csb_input_process[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
    .VAR/DM1 $profiler.csb_decode_frames[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
    .VAR/DM1 $profiler.audio_processing[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
    // initialise the profiler library
    call $profiler.initialise;
#endif

    // initialise the wall-clock library
    call $wall_clock.initialise;

    // Setup the clock sources
    r0 = $CLOCK_SOURCE_WALL_CLOCK;
    r1 = &$app.clock_params_wall_clock;
    $call_c_with_void_return_macro(system_time_register_source);

    r0 = &$app.audio_port_ids;
    $call_c_with_void_return_macro(audio_output_initialise);
    r0 = &$app.ec_input;
    $call_c_with_void_return_macro(ec_input_initialise);
    r0 = &$app.csb_input;
    $call_c_with_void_return_macro(csb_input_initialise);
    $call_c_with_void_return_macro(md_initialise);

    // initialise audio processing
    call $audio_processing_initialise;
    r0 = &$M.codec_resampler.resamp_out_md_track_state_l;
    $call_c_with_void_return_macro(md_track_cbuffers_initialise);
    r0 = &$M.codec_resampler.resamp_out_md_track_state_r;
    $call_c_with_void_return_macro(md_track_cbuffers_initialise);

    // register message handler for messages in the 0x3000 to 0x30FF range
    r1 = &$message.handler_struc;
    r2 = 0x3000;
    r3 = &$message_handler;
    r4 = 0x00FF;
    call $message.register_handler_with_mask;

    // register message handler for MESSAGE_PORT_BT_ADDRESS
    r1 = &$fw_bdaddr_message.handler_struc;
    r2 = $MESSAGE_PORT_BT_ADDRESS;
    r3 = &$fw_bdaddr_message.handler;
    call $message.register_handler;

    // register message handler for MESSAGE_AUDIO_CONFIGURE_RESPONSE
    r1 = &$fw_audio_message.handler_struc;
    r2 = $MESSAGE_AUDIO_CONFIGURE_RESPONSE;
    r3 = &$fw_audio_message.handler;
    call $message.register_handler;
    

	// TONE_MIXER
   // set up message handler for VM_SET_TONE_RATE_MESSAGE_ID message
   r1 = &$set_tone_rate_from_vm_message_struc;
   r2 = VM_SET_TONE_RATE_MESSAGE_ID;
   r3 = &$set_tone_rate_from_vm;
   call $message.register_handler;
   
   // set up message handler for VM_SET_DAC_RATE_MESSAGE_ID message
   r1 = &$set_dac_rate_from_vm_message_struc;
   r2 = VM_SET_DAC_RATE_MESSAGE_ID;
   r3 = &$set_dac_rate_from_vm;
   call $message.register_handler;

   // set up message handler for VM_SET_CODEC_RATE_MESSAGE_ID message
   r1 = &$set_codec_rate_from_vm_message_struc;
   r2 = VM_SET_CODEC_RATE_MESSAGE_ID;
   r3 = &$set_codec_rate_from_vm;
   call $message.register_handler;

    
#if (uses_SPKR_EQ)
    // Power Up Reset needs to be called once during program execution
    call $music_example.power_up_reset;
    r2 = $music_example.VMMSG.READY;
    r3 = $MUSIC_MANAGER_SYSID;
    // status
    r4 = M[$music_example.Version];
    r4 = r4 LSHIFT -8;
    call $message.send_short;
#endif

    // tell vm we're ready and wait for the go message
    r0 = $message.READY_WITH_META_RX_ENABLE + $message.READY_WITH_META_TX_ENABLE;
    call $message.send_ready_with_meta_wait_for_go;

    // Request BDADDR of CSB_IN_PORT  
    r2 = $MESSAGE_GET_BT_ADDRESS;
    r3 = $CSB_IN_PORT_NUMBER;
    call $message.send;

    start_timer:
        // start timer that copies audio samples
        r1 = &$app.timer_struc;
        r2 = TIMER_PERIOD;
        r3 = &$timer_handler;
        call $timer.schedule_event_in;
        M[$app.timer_event_id] = r3;
		

main_loop:
    // Use r5 to sum the returns from all the processes.
    r5 = 0;

    // ** CSB INPUT **
    PROFILER_START(&$profiler.csb_input_process);
    r0 = &$app.csb_input;
    r1 = &$app.ec_input;
    r2 = &$app.aesccm_params;
    r3 = &$app.csb_audio_status;
    $call_c_with_int_return_macro(csb_input_process);
    r5 = r5 + r0;
    PROFILER_STOP(&$profiler.csb_input_process);

    // check if volume has changed
    r0 = M[$app.csb_audio_status];
    Null = r0 AND CSB_INPUT_VOLUME_CHANGED_FLAG;
    if Z jump main_loop_volume_not_changed;

        r0 = &$app.csb_input;
        $call_c_with_int_return_macro(csb_input_get_volume);

        M[$app.csb_volume] = r0;
        r1 = M[$app.local_volume];
        call $app.set_target_volume;

        // Tell VM the latest system, local and total volume
        r2 = $MESSAGE_VOLUME_IND;
        r3 = M[$app.csb_volume];
        r4 = M[$app.local_volume];
        r5 = M[$app.current_volume];
        r6 = 0;
        call $message.send;

    main_loop_volume_not_changed:

    // check if sample rate has changed
    r0 = M[$app.csb_audio_status];
    Null = r0 AND CSB_INPUT_SAMPLE_RATE_CHANGED_FLAG;
    if Z jump main_loop_sample_rate_not_changed;
        // Cancel timer
        r2 = M[$app.timer_event_id];
        call $timer.cancel_event;
        // Clear flag
        M[$app.sr_change_complete] = 0;
        // send message to VM to request sample rate change
        r0 = &$app.csb_input;
        $call_c_with_int_return_macro(csb_input_get_sample_rate);
        r1 = r0;
        r2 = $MESSAGE_CSB_SAMPLE_RATE_CHANGED;
        r3 = r1 LSHIFT -8;
        r4 = r1 AND 0xFF;
        call $message.send;

        // Wait here until the sample rate changes
        wait_for_sample_rate_change:
            Null = M[$app.sr_change_complete];
            if Z jump wait_for_sample_rate_change;
        jump start_timer;
    main_loop_sample_rate_not_changed:

    // ** CSB DECODE **
    PROFILER_START(&$profiler.csb_decode_frames);
    r0 = &$app.csb_decoder_params;
    $call_c_with_int_return_macro(csb_decode_frames);
    r5 = r5 + r0;
    PROFILER_STOP(&$profiler.csb_decode_frames);

    PROFILER_START(&$profiler.audio_processing);
    push r5;
    call $audio_processing;
    pop r5;
    r5 = r5 + r0;
    PROFILER_STOP(&$profiler.audio_processing);
	push r5;
	call $M.codec_resampler.run_resampler;
	pop  r5;
    r5 = r5 + r0;

    NULL = r5;
    if Z call $SystemSleepAudio;
    jump main_loop;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $message_handler
//
// DESCRIPTION:
//    Function called on receive a message from the VM
//
// TRASHED REGISTERS:
//    All
//
// *****************************************************************************
.MODULE $M.message_handler;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$fw_audio_message.handler:
    rts;

$fw_bdaddr_message.handler:
    // push rLink onto stack
    $push_rLink_macro;

    // update wallclock structure with bdaddr
    r1 = r1 AND 0xFF00;
    r1 = r1 LSHIFT -8;
    M[$_wall_clock_struc + $wall_clock.BT_ADDR_TYPE_FIELD] = r1;
    //r2 = r2 AND 0xFFFF;
    M[$_wall_clock_struc + $wall_clock.BT_ADDR_WORD0_FIELD] = r2;
    //r3 = r3 AND 0xFFFF;
    M[$_wall_clock_struc + $wall_clock.BT_ADDR_WORD1_FIELD] = r3;
    //r4 = r4 AND 0xFFFF;
    M[$_wall_clock_struc + $wall_clock.BT_ADDR_WORD2_FIELD] = r4;

    // enable wall-clock, now that bdaddr is set
    r1 = &$_wall_clock_struc;
    call $wall_clock.enable;

    // pop rLink from stack
    jump $pop_rLink_and_rts;

$message_handler:

    // push rLink onto stack
    $push_rLink_macro;

    /* Standard Messages */

    // jump if LED colour message from VM
    Null = r0 - $MESSAGE_LED_COLOUR;
    if EQ jump message_handler.led_colour;

    // jump if set volume message from VM
    Null = r0 - $MESSAGE_SET_VOLUME;
    if EQ jump message_handler.set_volume;

    // jump if csb input iv set message from VM
    Null = r0 - $MESSAGE_SET_IV;
    if EQ jump message.handler_set_iv;

    // jump if csb input fixed iv set message from VM
    Null = r0 - $MESSAGE_SET_FIXED_IV;
    if EQ jump message.handler_set_fixed_iv;

    // jump if broadcast configuration message from VM
    Null = r0 - $MESSAGE_BROADCAST_CONFIG;
    if EQ jump message.handler_broadcast_config;

    // jump if set stream id message from VM
    Null = r0 - $MESSAGE_SET_STREAM_ID;
    if EQ jump message.handler_set_stream_id;

    // jump if celt config message from VM
    Null = r0 - $MESSAGE_SET_CELT_CONFIG;
    if EQ jump message.handler_set_celt_config;

    // Place all standard message tests before here
    Null = r0 - $message.LONG_MESSAGE_MODE_ID;
    if NE jump $pop_rLink_and_rts;

    /* Long Messages */

    // jump if csb input key set message from VM
    Null = r1 - $MESSAGE_SET_KEY;
    if EQ jump message.handler_set_key;

    // pop rLink from stack
    jump $pop_rLink_and_rts;


message_handler.led_colour:

    // LED RGB gains in r1, r2, r3
    r0 = r1 AND 0xFF;
    r1 = r1 ASHIFT 8;
    r1 = r1 OR r0;
    r0 = r2 AND 0xFF;
    r2 = r2 ASHIFT 8;
    r2 = r2 OR r0;
    r0 = r3 AND 0xFF;
    r3 = r3 ASHIFT 8;
    r3 = r3 OR r0;
    call $led.set_colour;

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message_handler.set_volume:
    r0 = &$app.csb_input;
    $call_c_with_int_return_macro(csb_input_get_volume);
    M[$app.csb_volume] = r0;

    //r1 = local volume from message
    M[$app.local_volume] = r1;
    call $app.set_target_volume;

    // Tell VM the latest system, local and total volume
    r2 = $MESSAGE_VOLUME_IND;
    r3 = M[$app.csb_volume];
    r4 = M[$app.local_volume];
    r5 = M[$app.current_volume];
    r6 = 0;
    call $message.send;

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_set_key:
    // This is a long message - the payload address is in r3
    r1 = r3;
    r0 = &$app.aesccm_params;
    $call_c_with_void_return_macro(aesccm_set_key);

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_set_iv:
    r0 = &$app.aesccm_params;
    // r1 contains the IV from the message
    $call_c_with_void_return_macro(aesccm_set_iv);

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_set_fixed_iv:
    r0 = &$app.aesccm_params;
    // r1, r2, r3 contains the fixed IV from the message
    $call_c_with_void_return_macro(aesccm_set_fixed_iv);

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_broadcast_config:
    r0 = &$app.ec_input;
    // r1 is the CSB interval in slots from the message
    $call_c_with_void_return_macro(ec_input_set_rx_interval);
    jump $pop_rLink_and_rts;

message.handler_set_stream_id:
    // r1 contains the stream id to use
    r0 = &$app.ec_input;
    $call_c_with_void_return_macro(ec_input_set_stream_id);
    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_set_celt_config:
    // r1 is the sample rate this config applies to
    // r2 is the number of octets per frame
    // r3 is the number of samples per frame
    // r4 is the number of channels
    r1 = r1 AND 0xFFFF;
    M[$_celt_decoder_frame_channels] = r4;
    r4 = &$celt_decoder_parameters;
    r5 = r4 + 2;
    r0 = 0;
    Null = r1 - 44100;
    if Z r0 = r4;
    Null = r1 - 48000;
    if Z r0 = r5;
    Null = r0;
    if Z call $error;
    M[r0] = r2;
    M[r0 + 1] = r3;
    // pop rLink from stack
    jump $pop_rLink_and_rts;

$app.scmr_segment_ind:
    $push_rLink_macro;
    $kcc_regs_save_macro;

    r2 = $MESSAGE_SCM_SEGMENT_IND;
    r3 = r0;
    r4 = r1 LSHIFT -16;
    r5 = r1 AND 0xFFFF;
    call $message.send;    

    $kcc_regs_restore_macro;
    jump $pop_rLink_and_rts;

$app.scmr_segment_expired:
    $push_rLink_macro;
    $kcc_regs_save_macro;

    r2 = $MESSAGE_SCM_SEGMENT_EXPIRED;
    r3 = r0;
    r4 = 0;
    r5 = 0;
    call $message.send;    

    $kcc_regs_restore_macro;
    jump $pop_rLink_and_rts;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $app.set_target_volume
//
// DESCRIPTION:
//    Set the target volume based on the CSB and local volume level.
//
// INPUTS:
//    r0 - the CSB volume
//    r1 - the local volume
//
// TRASHED REGISTERS:
//    r0, r1
//
// *****************************************************************************
.MODULE $M.app_set_target_volume;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
$app.set_target_volume:
    // add CSB and local volumes together, clamp within 0 and 31
    r0 = r0 + r1;
    r1 = 31;
    r0 = MIN r1;
    r1 = 0;
    r0 = MAX r1;
    // store target volume
    M[$app.target_volume] = r0;
    rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $timer_handler
//
// DESCRIPTION:
//    Function called on a timer interrupt to perform the DAC copying and RTP
//    copying.
//
// TRASHED REGISTERS:
//    All
//
// *****************************************************************************
.MODULE $M.timer_handler;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

    .VAR $app.audio.output.status = $audio.output.NO_AUDIO;

$timer_handler:

    // push rLink onto stack
    $push_rLink_macro;

    // post another timer event
    r1 = &$app.timer_struc;
    r2 = TIMER_PERIOD;
    r3 = &$timer_handler;
    call $timer.schedule_event_in_period;
    M[$app.timer_event_id] = r3;
    
    M[$frame_sync.sync_flag] = Null;
    
	// TONE_MIXER
    call $M.post_eq.processing;
    
    r0 =  $dacout_left_md_list;
    r1 =  $dacout_right_md_list;
    // pass tone data into audio_output_timestamped_frames so it can be played when main audio has stopped.
    r2 = $tone_mixing_data;
    $call_c_with_int_return_macro(audio_output_timestamped_frames);
    r1 = M[$app.audio.output.status];
    r1 = r1 XOR r0;
    M[$app.audio.output.status] = r0;

#ifdef ENABLE_IMMEDIATE_AUDIO_STATUS_CHANGE_MESSAGES
    // Tell the VM if audio status has changed
    r2 = $MESSAGE_AUDIO_STATUS;
    r3 = r0;
    Null = r1;
    pushm <r0, r1>;
    if NE call $message.send;
    popm <r0, r1>;
#endif

    // Copy CSB packet from port to EC
    r0 = $app.ec_input;
    r1 = TIMER_PERIOD;
    $call_c_with_int_return_macro(ec_input_copy);
    // Tell the VM if AFH channel map has changed
    r2 = $MESSAGE_AFH_CHANNEL_MAP_CHANGE_PENDING;
    Null = r0;
    pushm <r0, r1>;
    if NZ call $message.send;
    popm <r0, r1>;
    

    call $led.update_pwm;



    r0 = $app.scmr_params;
    $call_c_with_void_return_macro(scmr_segment_check);

    call $app.send_status_message;

    // pop rLink from stack
    jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $wall_clock.callback
//
// DESCRIPTION:
//    Function called when wall-clock updated.
//
// INPUTS:
//    r2 the wall clock adjustment field
//
// *****************************************************************************
.MODULE $M.wall_clock_callback;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$wall_clock.callback:
    $push_rLink_macro;

    r0 = M[$wall_clock.running];
    if NZ jump $pop_rLink_and_rts;

    // Set the wall clock as an active source
    r0 = $CLOCK_SOURCE_WALL_CLOCK;
    $call_c_with_void_return_macro(system_time_set_source_active);

    r0 = 1;
    M[$wall_clock.running] = r0;
    jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $app.send_status_message
//
// DESCRIPTION:
//    Periodically send a status message to the VM
//
// TRASHED REGISTERS:
//    All
//
// *****************************************************************************
.MODULE $M.app_send_status_message;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

    // Send message every 500ms (2Hz)
    .CONST $STATUS_MESSAGE_TIMER_TICKS 500000 / TIMER_PERIOD;
    .VAR $app.status_message_timer = $STATUS_MESSAGE_TIMER_TICKS;

$app.send_status_message:

    // exit if it's not time to send the message
    r0 = M[$app.status_message_timer];
    r0 = r0 - 1;
    M[$app.status_message_timer] = r0;
    if POS rts;

    // reset timer
    r0 = $STATUS_MESSAGE_TIMER_TICKS;
    M[$app.status_message_timer] = r0;

    $push_rLink_macro;
    r0 = $MESSAGE_BROADCAST_STATUS;
    r1 = &$app.csb_input;
    r2 = &$app.ec_input;
    $call_c_with_void_return_macro(broadcast_status_send_receiver);
    // pop rLink from stack
    jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $app.write_port_change_callback
// FUNCTIONS:
//    $app.write_port_connect_callback
//    $app.write_port_disconnect_callback
//
// DESCRIPTION:
//    Functions called by cbuffer library when write port is
//    connected / disconnected.
//
// INPUTS:
//    r0 = $cbuffer.CALLBACK_PORT_CONNECT or $cbuffer.CALLBACK_PORT_DISCONNECT
//    r1 = the port number connected / disconnected
//
// *****************************************************************************
.MODULE $M.app.write_port_change_callback;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$app.write_port_connect_callback:
    r1 = r1 - CBUFFER_WRITE_PORT_OFFSET;
    Null = r1 - $AUDIO_OUT_LEFT_PORT_NUMBER;
    if Z jump audio_out_port_connected;
    Null = r1 - $AUDIO_OUT_RIGHT_PORT_NUMBER;
    if Z jump audio_out_port_connected;
    rts;
$app.write_port_disconnect_callback:
    r1 = r1 - CBUFFER_WRITE_PORT_OFFSET;
    Null = r1 - $AUDIO_OUT_LEFT_PORT_NUMBER;
    if Z jump audio_out_port_disconnected;
    Null = r1 - $AUDIO_OUT_RIGHT_PORT_NUMBER;
    if Z jump audio_out_port_disconnected;
    rts;

// Handle AUDIO_OUT_LEFT/RIGHT_PORT connected
audio_out_port_connected:
    // Clear bit on connect
    r0 = 1 LSHIFT r1;
    r0 = r0 XOR ~0;
    r1 = M[$app.audio_output_ports_disconnected];
    r1 = r1 AND r0;
    M[$app.audio_output_ports_disconnected] = r1;
    if NZ rts;
    // Zero the volume, so the volume ramps up as audio playback begins
    M[$app.current_volume] = 0;
    M[$app.volume_timer] = 0;
    $push_rLink_macro;
    r0 = 0;
    jump $pop_rLink_and_rts;

// Handle AUDIO_OUT_LEFT/RIGHT_PORT disconnected
audio_out_port_disconnected:
    // Set bit on disconnect
    r0 = 1 LSHIFT r1;
    r1 = M[$app.audio_output_ports_disconnected];
    r1 = r1 OR r0;
    M[$app.audio_output_ports_disconnected] = r1;
    rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    .MODULE $M.prevent_using_addr_0
// FUNCTIONS:
//    none
//
// DESCRIPTION:
//    All this module does is put something in address zero to avoid having the 
//    linker stick something there that could result in a null pointer.
//
// INPUTS:
//    none
//
// *****************************************************************************
.MODULE $M.prevent_using_addr_0;
   .DATASEGMENT DM1_AVOID_DATA_IN_ADDR_0;
   .VAR dummy_var = 0;
.ENDMODULE;


// TONE_MIXER

.MODULE $M.post_eq;
   .CODESEGMENT PM;
   .DATASEGMENT DM;


   DeclareCBuffer(dacout_left_cbuffer_struc,  dacout_cbuffer_left,  DAC_OUT_CBUFFER_SIZE);
   DeclareCBuffer(dacout_right_cbuffer_struc, dacout_cbuffer_right, DAC_OUT_CBUFFER_SIZE);

    // define cbuffer to track for post_eq cbops operation.
   .VAR post_eq_left_cbuffer_struc[$cbuffer.STRUC_SIZE] = 0 ...;
   .VAR post_eq_right_cbuffer_struc[$cbuffer.STRUC_SIZE] = 0 ...;
   

   .VAR/DM $dacout_left_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
   .VAR/DM $dacout_right_md_list[MD_LIST_STRUC_SIZE] = 0 ...;


    // Cbuffers that present input data to the audio processing, based
    // on the input metadata lists
   .VAR/DM1CIRC tone_mixer_l._hist[$cbops.auto_resample_mix.TONE_FILTER_HIST_LENGTH];                                                               
   .VAR/DM1CIRC tone_mixer_r._hist[$cbops.auto_resample_mix.TONE_FILTER_HIST_LENGTH];                                                               
   
   .VAR en = 1;
   
   .VAR copy_struc[] =
        &switch_op_l,              // first operator block
        // copy_l,
        2,                            // number of inputs
        &post_eq_left_cbuffer_struc,  // CONFIG_FIELD
        &post_eq_right_cbuffer_struc, // CONFIG_FIELD
        2,
        &dacout_left_cbuffer_struc,  // CONFIG_FIELD
        &dacout_right_cbuffer_struc; // CONFIG_FIELD

   .VAR dacout_md_track_state_l[MD_TRACK_STATE_STRUC_SIZE] =
        &post_eq_left_cbuffer_struc,        // md_track_state.input_cbuffer
        &dacout_left_cbuffer_struc,         // md_track_state.output_cbuffer
        &$app.pcm_out_left_md_list,         // md_track_state.input_md_list
        &$dacout_left_md_list,              // md_track_state.output_md_list
        0,                                  // md_track_state.algorithmic_delay_samples
        0 ...;
   .VAR dacout_md_track_state_r[MD_TRACK_STATE_STRUC_SIZE] =
        &post_eq_right_cbuffer_struc,       // md_track_state.input_cbuffer
        &dacout_right_cbuffer_struc,        // md_track_state.output_cbuffer
        &$app.pcm_out_right_md_list,        // md_track_state.input_md_list
        &$dacout_right_md_list,             // md_track_state.output_md_list
        0,                                  // md_track_state.algorithmic_delay_samples
        0 ...;



    // #define TEMPLATE_SWITCH_ALT_OP(name, next_op, alt_next_op, en, mask)                                   
   /* Switch operator chains according to whether switch condition is valid */                           
   .BLOCK switch_op_l;                                                                                     
      .VAR switch_op_l.next = tone_mixer_l;                                                                 
      .VAR switch_op_l.func = $cbops.switch_op;                                                            
      .VAR switch_op_l.param[$cbops.switch_op.STRUC_SIZE] =                                                
         en,                                /* Pointer to switch (1: next, 0: alt_next) */            
         soft_mute_l,                       /* ALT_NEXT_FIELD, pointer to alternate cbops chain */     
         0,                                 /* SWITCH_MASK_FIELD */                                   
         0;                                 /* INVERT_CONTROL_FIELD */                                
   .ENDBLOCK;

    // #define TEMPLATE_MIX_OP(name, next_op, in_idx, in_tone_cbuf)                                                                                   
   .BLOCK tone_mixer_l;                                                                                                                              
      .VAR tone_mixer_l.next = soft_mute_l;  // need to be configured in run time                                                                                                    
      .VAR tone_mixer_l.func = $cbops.auto_upsample_and_mix;                                                                                        
      .VAR tone_mixer_l.param[$cbops.auto_resample_mix.STRUC_SIZE] =                                                                                
         0,                               /* Input index to first channel */                                                                    
         -1,                              /* Input index to second channel, -1 for no second channel */                                         
         $tone_in_left_resample_cbuffer_struc, /* cbuffer structure containing tone samples */                                                       
         $sra_coeffs,                     /* coefs for resampling */                                                                            
         $current_dac_sampling_rate,      /* pointer to variable containing dac rate received from vm (if 0, default 48000hz will be used) */   
         tone_mixer_l._hist,              /* history buffer for resampling */                                                                   
         $current_dac_sampling_rate,      /* pointer to variable containing tone rate received from vm (if 0, default 8000hz will be used) */   
         0.5,                             /* tone volume mixing (set by vm) */                                                                  
         0.5,                             /* audio volume mixing */                                                                             
         0 ...;                           /* Pad out remaining items with zeros */                                                              
   .ENDBLOCK;

   .BLOCK soft_mute_l;
        .VAR soft_mute_l.next = switch_op_r;
        .VAR soft_mute_l.func = &$cbops.soft_mute;
        .VAR soft_mute_l.param[$cbops.soft_mute_op.STRUC_SIZE_MONO] =
            1,      // mute direction (1 = unmute audio)
            0,      // index
            1,      // number of channels
            0,      // input index
            2;      // output index
    .ENDBLOCK;

   .BLOCK switch_op_r;                                                                                      
      .VAR switch_op_r.next = tone_mixer_r;                                                                 
      .VAR switch_op_r.func = $cbops.switch_op;                                                           
      .VAR switch_op_r.param[$cbops.switch_op.STRUC_SIZE] =                                               
         en,                                 /* Pointer to switch (1: next, 0: alt_next) */             
         soft_mute_r,                     /* ALT_NEXT_FIELD, pointer to alternate cbops chain */    
         0,                               /* SWITCH_MASK_FIELD */                                    
         0;                                  /* INVERT_CONTROL_FIELD */                                 
   .ENDBLOCK;

   .BLOCK tone_mixer_r;                                                                                                                              
      .VAR tone_mixer_r.next = soft_mute_r;                                                                                                               
      .VAR tone_mixer_r.func = $cbops.auto_upsample_and_mix;                                                                                        
      .VAR tone_mixer_r.param[$cbops.auto_resample_mix.STRUC_SIZE] =                                                                                
         1,                          /* Input index to first channel */                                                                    
         -1,                              /* Input index to second channel, -1 for no second channel */                                         
         $tone_in_right_resample_cbuffer_struc, /* cbuffer structure containing tone samples */                                                       
         $sra_coeffs,                     /* coefs for resampling */                                                                            
         $current_dac_sampling_rate,      /* pointer to variable containing dac rate received from vm (if 0, default 48000hz will be used) */   
         tone_mixer_r._hist,              /* history buffer for resampling */                                                                   
         $current_dac_sampling_rate,      /* pointer to variable containing tone rate received from vm (if 0, default 8000hz will be used) */   
         0.5,                             /* tone volume mixing (set by vm) */                                                                  
         0.5,                             /* audio volume mixing */                                                                             
         0 ...;                           /* Pad out remaining items with zeros */    
   .ENDBLOCK;
         
   .BLOCK soft_mute_r;
        .VAR soft_mute_r.next = $cbops.NO_MORE_OPERATORS;
        .VAR soft_mute_r.func = &$cbops.soft_mute;
        .VAR soft_mute_r.param[$cbops.soft_mute_op.STRUC_SIZE_MONO] =
            1,      // mute direction (1 = unmute audio)
            0,      // index
            1,      // number of channels
            1,      // input index
            3;      // output index
    .ENDBLOCK;



processing:

    $push_rLink_macro;
    
    // copy tone from port into cbuffer and upsample it to DAC rate
    Null = M[$aux_input_stream_available];
    if NZ  call $tone_copy_handler;





    r0 = &dacout_md_track_state_l;
    $call_c_with_int_return_macro(md_track_cbuffers_pre);
    Null = r0;
    if Z jump cbops_post_eq_exit;
    r0 = &dacout_md_track_state_r;
    $call_c_with_int_return_macro(md_track_cbuffers_pre);
    Null = r0;
    if Z jump cbops_post_eq_exit;

//  Mix tone with primary audio
    r8 = copy_struc;
    call $cbops.copy;


    r0 = &dacout_md_track_state_l;
    $call_c_with_int_return_macro(md_track_cbuffers_post);
    push r0;
    r0 = &dacout_md_track_state_r;
    $call_c_with_int_return_macro(md_track_cbuffers_post);
    pop r1;
    r0 = r0 + r1;
    
cbops_post_eq_exit:


    jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.Sleep
//
// DESCRIPTION:
//    Place Processor in IDLE and compute system MIPS
//    To read total MIPS over SPI do ($M.Sleep.Mips*proc speed)/8000
//    proc speed is 120 for Gordon and 120 for Rick
//
// *****************************************************************************
.MODULE $M.Sleep;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR TotalTime=0;
   .VAR LastUpdateTm=0;
   .VAR Mips=0;
   .VAR sync_flag_esco=0;
   .VAR max_mips = 0;

$SystemSleepAudio:
   r2 = $frame_sync.sync_flag;
   jump SleepSetSync;

$SystemSleepEsco:
   r2 = sync_flag_esco;

SleepSetSync:
   // Set the sync flag to commence sleeping (wait for it being cleared)
   r0 = 1;
   M[r2] = r0;

   // Timer status for MIPs estimate
   r1 = M[$TIMER_TIME];
   r4 = M[$interrupt.total_time];
   // save current clock rate
   r6 = M[$CLOCK_DIVIDE_RATE];
   // go to slower clock and wait for task event
   r0 = $frame_sync.MAX_CLK_DIV_RATE;
   M[$CLOCK_DIVIDE_RATE] = r0;

   // wait in loop (delay) till sync flag is reset
jp_wait:
   Null = M[r2];
   if NZ jump jp_wait;

   // restore clock rate
   M[$CLOCK_DIVIDE_RATE] = r6;

   // r1 is total idle time
   r3 = M[$TIMER_TIME];
   r1 = r3 - r1;  // time spent sleeping
   r4 = r4 - M[$interrupt.total_time]; // time spent in interrupt during this sleep
   r1 = r1 + r4; // r1 = time spent sleeping - time spent in interrupt during this sleep
   r0 = M[&TotalTime];
   r1 = r1 + r0;
   M[&TotalTime]=r1;  // accumulated time spent sleeping (excludes main loop and interrupt processing time)

   // Check for MIPs update
   r0 = M[LastUpdateTm];
   r5 = r3 - r0;
   rMAC = 1000000;
   NULL = r5 - rMAC;
   if NEG rts;  // a second hasn't elapsed yet so return - note that first measurement will be bogus.  That's okay.  We can ignore the first one.
   
// a second or more has elapsed.  Let's calculate MIPS.
// r5 has the amount of time that elapsed over this measurment.
// r1 has the amount of time spent sleeping during this measurement period.  Note: all other time would be spent processing in main loop and interrupts.
// (r5-r1)/r5 * 120MIPS = MIPS spent doing interrupt and main loop processing.
// r1/r5 * 120 MIPS = MIPS spent sleeping.
// -r4/r5 * 120 MIPS = MIPS spent in interrupts.

   // Time Period
   rMAC = rMAC ASHIFT -1;
   Div = rMAC/r5; // 1 second / measurement period, which is a little bigger than one second - not sure why we do this.
   // Total Processing (Time Period - Idle Time) - note that "Idle Time" really means time spent doing processing that's not in the interrupt; i.e. main_loop processing
   rMAC = r5 - r1;
   // Last Trigger Time
   M[LastUpdateTm]=r3;
   // Reset total time count
   M[&TotalTime]=NULL;
   // MIPS
   r3  = DivResult;
   rMAC  = r3 * rMAC (frac); // 1 second / measurement period * time spent doing main loop processing
   // Convert for UFE format
   // UFE uses STAT_FORMAT_MIPS - Displays (m_ulCurrent/8000.0*m_pSL->GetChipMIPS())
   // Multiply by 0.008 = 1,000,000 --> 8000 = 100% of MIPs
   r3 = 0.008;
   rMAC = rMAC * r3 (frac);  // Total MIPs Est
   M[Mips]=rMAC;
   r0 = M[max_mips];
   Null = r0 - rMAC;
   if NEG r0 = rMAC;
   M[max_mips] = r0;
   rts;

.ENDMODULE;
