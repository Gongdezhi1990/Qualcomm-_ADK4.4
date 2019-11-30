// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// *****************************************************************************
// DESCRIPTION
//    Broadcast Audio Master Application
//
// *****************************************************************************

#include "codec_encoder.h"

// By default request FFT_TWIDDLE_SIZE 256, AAC may override this with a 
// larger value.
#define FFT_TWIDDLE_NEED_256_POINT
#include <fft_twiddle.h>


.MODULE $M.main;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   // These scratch "registers" are used by various libraries (e.g. SBC)
   .VAR $scratch.s0;
   .VAR $scratch.s1;
   .VAR $scratch.s2;

   // To reduce RAM utilisation, these scratch buffers are shared by the AAC
   // decoder, CELT encoder and other libraries (via malloc/free) whose
   // processing runs in the main loop.
   // To avoid modifying the AAC library to support dynamic allocation
   // of pool buffers, an AAC library variant has been created called
   // "aac_external_pools" that allows the two AAC pools to be defined
   // externally. The pools are defined here using blocks so the naming
   // used in the AAC library can be preserved.
   .CONST $celt.SCRATCH_LENGTH 2500;
#if defined(SELECTED_DECODER_AAC) || defined(SELECTED_MULTI_DECODER)
   .CONST $SCRATCH_1_LENGTH max($aacdec.TMP_MEM_POOL_LENGTH, $celt.SCRATCH_LENGTH);
   .CONST $SCRATCH_2_LENGTH max($aacdec.FRAME_MEM_POOL_LENGTH, $celt.SCRATCH_LENGTH);
#else
   .CONST $SCRATCH_1_LENGTH $celt.SCRATCH_LENGTH;
   .CONST $SCRATCH_2_LENGTH $celt.SCRATCH_LENGTH;
#endif
   .BLOCK/DM1CIRC $_scratch_dm1;
       .VAR $aacdec.tmp_mem_pool[$SCRATCH_1_LENGTH];
   .ENDBLOCK;
   .BLOCK/DM2CIRC $_scratch_dm2;
       .VAR $aacdec.frame_mem_pool[$SCRATCH_2_LENGTH];
   .ENDBLOCK;

   .VAR $malloc.pool[] =
        &$_scratch_dm1,
        LENGTH($_scratch_dm1) | $malloc.FLAG_CIRCULAR,
        &$_scratch_dm2,
        LENGTH($_scratch_dm2) | $malloc.FLAG_CIRCULAR | $malloc.FLAG_DM2;

   $_main:


   .VAR $AUDIO_PORT_IDS[7] =
       $AUDIO_LEFT_OUT_PORT,
       $AUDIO_RIGHT_OUT_PORT,
       $RTP_IN_PORT,
       $USB_IN_PORT,
       $AUDIO_LEFT_IN_PORT,
       $AUDIO_RIGHT_IN_PORT,
       $CSB_OUT_PORT;

    // allocate memory for timer structures
    .VAR $timer.struc[$timer.STRUC_SIZE];

    // allocate memory for message structures
    .VAR $message.handler_struc[$message.STRUC_SIZE];
    .VAR $scm_message.handler_struc[$message.STRUC_SIZE];
    .VAR $fw_audio_message.handler_struc[$message.STRUC_SIZE];
    .VAR $fw_bdaddr_message.handler_struc[$message.STRUC_SIZE];

#ifdef  SELECTED_MULTI_DECODER
    .VAR $set_plugin_message_struc[$message.STRUC_SIZE];
#endif 

    .VAR $_wall_clock_struc[$wall_clock.STRUC_SIZE] =
        0,                      // next wall_clock
        0, 0, 0, 0,             // bd_addr
        0,                      // adjustment
        &$wall_clock.callback,  // callback
        0 ...;

    .VAR $wall_clock.running = 0;

    .VAR $fwrandom_struc[$fwrandom.STRUC_SIZE] = 0 ...;
    .VAR $fwrandom_buffer[$fwrandom.MAX_RAND_BITS / 16] = 0 ...;

    .VAR $app.rtp_input_decoder_params[RTP_INPUT_DECODER_PARAMS_STRUC_SIZE] =
        $rtp_frame_md_list,              // rtp_input_decoder_params.codec_md_list
        $audio_in_left_cbuffer_struc,    // rtp_input_decoder_params.audio_in_left_cbuffer
        $audio_in_right_cbuffer_struc,   // rtp_input_decoder_params.audio_in_right_cbuffer
        $audio_in_left_md_list,          // rtp_input_decoder_params.audio_in_left_md_list
        $audio_in_right_md_list,         // rtp_input_decoder_params.audio_in_right_md_list
#if defined(SELECTED_MULTI_DECODER)
	    0;
#elif defined(SELECTED_DECODER_AAC)
        $_aac_decode_frame;              // rtp_input_decoder_params.rtp_input_decode_frame_fn
#elif defined(SELECTED_DECODER_SBC)
        $_sbc_decode_frame;              // rtp_input_decoder_params.rtp_input_decode_frame_fn
#endif

    .VAR $app.analogue_input_params[ANALOGUE_INPUT_PARAMS_STRUC_SIZE] =
        128,                                // analogue_input_params.pcm_md_size
        $AUDIO_LEFT_IN_PORT,                // analogue_input_params.left_input
        $AUDIO_RIGHT_IN_PORT,               // analogue_input_params.right_input
        &$audio_in_left_cbuffer_struc,      // analogue_input_params.left_output
        &$audio_in_right_cbuffer_struc,     // analogue_input_params.right_output
        &$audio_in_left_md_list,            // analogue_input_params.left_pcm_md_list
        &$audio_in_right_md_list,           // analogue_input_params.right_pcm_md_list
        &$app.ttp_state,                    // analogue_input_params.ttp_state
        &$app.analogue.ttp_settings_struc,  // analogue_input_params.ttp_settings
        &$app.system_time_source,           // analogue_input_params.system_time_source
        0 ...;                              // internal state
       
    .VAR $app.rtp_input_params[RTP_INPUT_PARAMS_STRUC_SIZE] =
        $RTP_IN_PORT,                       // rtp_input_params.input
        &$rtp_frame_cbuffer_struc,          // rtp_input_params.frame_cbuffer
        &$rtp_frame_md_list,                // rtp_input_params.frame_md_list
        &$app.ttp_state,                    // rtp_input_params.ttp_state
        &$app.rtp.ttp_settings_struc,       // rtp_input_params.ttp_settings
        &$app.system_time_source,           // rtp_input_params.system_time_source
#if defined(SELECTED_DECODER_AAC)
        $_rtp_input_process_aac_frames,     // rtp_input_params.rtp_process_fn
#elif defined(SELECTED_DECODER_SBC)
        $_rtp_input_process_sbc_frames,     // rtp_input_params.rtp_process_fn
#endif
        0 ...;

    .VAR $app.usb_input_params[USB_INPUT_PARAMS_STRUC_SIZE] = 
        128,                                // usb_input_params.pcm_md_size
        $USB_IN_PORT,                       // usb_input_params.source
        &$audio_in_left_cbuffer_struc,      // usb_input_params.left_output
        &$audio_in_right_cbuffer_struc,     // usb_input_params.right_output
        &$audio_in_left_md_list,            // usb_input_params.left_pcm_md_list
        &$audio_in_right_md_list,           // usb_input_params.right_pcm_md_list
        USB_PACKET_LEN,                     // Packet length (Number of audio data bytes in a USB packet for all channels)
        8,                                  // shift ammount
        &$app.ttp_state,                    // usb_input_params.ttp_state
        &$app.usb.ttp_settings_struc,       // usb_input_params.ttp_settings
        &$app.system_time_source,           // usb_input_params.system_time_source
        0 ...;                              // internal state

    .VAR $app.csb_output_params[CSB_OUTPUT_PARAMS_STRUC_SIZE] =
        &$app.scmb_params,                  // csb_output_params.scmb_params
        0,                                  // csb_output_params.tx_time_min - set via VM message
        0,                                  // csb_output_params.tx_window - set via VM message
        &$csb_frame_md_list,                // csb_output_params.frame_md_list
        0 ...;                              // internal state

    .VAR $app.csb_encoder_params[CSB_ENCODER_PARAMS_STRUC_SIZE] = 
        &$audio_in_left_md_list,            // csb_encoder_params.audio_in_md_list[0]
        &$audio_in_right_md_list,           // csb_encoder_params.audio_in_md_list[1]
        &$audio_post_csb_left_md_list,      // csb_encoder_params.audio_out_md_list[0]
        &$audio_post_csb_right_md_list,     // csb_encoder_params.audio_out_md_list[1]
        &$csb_frame_md_list,                // csb_encoder_params.frame_md_list
        &$csb_frame_cbuffer_struc,          // csb_encoder_params.frame_cbuffer
        &$celt_encode_frame,                // csb_encoder_params.csb_decode_frame_fn
        512,                                // csb_encoder_params.samples_in_frame
        0,                                  // csb_encoder_params.csb_encoder_delay_samples
                                            // /initialised in celt_frame_encode.asm
        $CLOCK_SOURCE_CSB_WALL_CLOCK,       // csb_encoder_params.system_time_source
        0 ...;                              // internal state

    .VAR $app.ec_output_params[EC_OUTPUT_PARAMS_STRUC_SIZE] =
        $CSB_OUT_PORT,                      // ec_output_params.output_port 
        0 ...;                              // ec_output_params.stream_id

    .VAR $app.scmb_params[SCMB_PARAMS_STRUC_SIZE] =
        $app.scmb_segment_cfm,
        0 ...;
    
    .VAR $app.analogue.ttp_settings_struc[TTP_SETTINGS_STRUC_SIZE] =
        0.999,  // LATENCY_HOLD_LEAKAGE
        -2000,  // LATENCY_DIFFERENCE_LIMIT
        0.997,  // LATENCY_ERROR_FILTER_GAIN
        -1,     // LATENCY_ERROR_FILTER_SHIFT
        -1,     // LATENCY_INITIAL_COUNTDOWN_VALUE_US
        100000, // TTP_SETTINGS_LATENCY
        4;      // TTP_SETTINGS_SAMPLE_RATE_BITS

    .VAR $app.rtp.ttp_settings_struc[TTP_SETTINGS_STRUC_SIZE] =
        0.999,             // LATENCY_HOLD_LEAKAGE
        -2000,             // LATENCY_DIFFERENCE_LIMIT
        0.997,             // LATENCY_ERROR_FILTER_GAIN
        -1,                // LATENCY_ERROR_FILTER_SHIFT
        200*$TIMER_PERIOD, // LATENCY_INITIAL_COUNTDOWN_VALUE_US
        350000,            // TTP_SETTINGS_LATENCY
        3;                 // TTP_SETTINGS_SAMPLE_RATE_BITS

    .VAR $app.usb.ttp_settings_struc[TTP_SETTINGS_STRUC_SIZE] =
        0.999,  // LATENCY_HOLD_LEAKAGE
        -2000,  // LATENCY_DIFFERENCE_LIMIT
        0.997,  // LATENCY_ERROR_FILTER_GAIN
        -1,     // LATENCY_ERROR_FILTER_SHIFT
        -1,     // LATENCY_INITIAL_COUNTDOWN_VALUE_US
        100000, // TTP_SETTINGS_LATENCY,
        4;      // TTP_SETTINGS_SAMPLE_RATE_BITS

    // Use the API to setup the parameters
    .VAR $app.aesccm_params[AESCCM_PARAMS_STRUC_SIZE] = 0 ...;

    .VAR $app.ttp_state[TTP_STATE_STRUC_SIZE];

    // Define the clock sources and the params so each clock time can be read
    .CONST $CLOCK_SOURCE_LOCAL_TIME      0;
    .CONST $CLOCK_SOURCE_CSB_WALL_CLOCK  1;
    .VAR $app.clock_params_local_time[SYSTEM_TIME_CLOCK_PARAMS_STRUC_SIZE] =
        $_timer_time_get,          // system_time_clock_params.get_clock_fn
        0,                         // system_time_clock_params.arg
        0,                         // system_time_clock_params.offset
        1;                         // system_time_clock_params.active
    .VAR $app.clock_params_csb_wall_clock[SYSTEM_TIME_CLOCK_PARAMS_STRUC_SIZE] =
        $_wall_clock_get_time,     // system_time_clock_params.get_clock_fn
        &$_wall_clock_struc,       // system_time_clock_params.arg
        0,                         // system_time_clock_params.offset
        0;                         // system_time_clock_params.active

    // The address of this variable is passed to inputs in their
    // parameter structure. Inputs request a system time from the source
    // defined by the value of this variable.
    .VAR $app.system_time_source = $CLOCK_SOURCE_LOCAL_TIME;

    .VAR $app.audio_output_ports_disconnected = 1 << $AUDIO_OUT_LEFT_PORT_NUMBER | 1 << $AUDIO_OUT_RIGHT_PORT_NUMBER;

    .VAR/DM $audio_in_left_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR/DM $audio_in_right_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    
    .VAR/DM $audio_post_csb_left_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR/DM $audio_post_csb_right_md_list[MD_LIST_STRUC_SIZE] = 0 ...;

    .VAR/DM $audio_out_left_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR/DM $audio_out_right_md_list[MD_LIST_STRUC_SIZE] = 0 ...;

    // For RTP input, these buffers are used as the variables are named.
    // For USB/Analogue inputs (uncompressed PCM inputs), the rtp_frame_cbuffer
    // is not required for storing compressed data, so this buffer is re-used
    // for storing input PCM data. In this case the block names are used.
    // The changes to $audio_in_left/right_cbuffer_struc are made when either
    // the USB or analogue input ports are connected at startup.
    // The two blocks may be mismatched in size - in which case the minimum of
    // the two block's size is used in the USB/analogue input case.
    .BLOCK/DMCIRC $pcm_in_left;
        .VAR $rtp_frame_cbuffer[10240];
    .ENDBLOCK;
    .BLOCK/DMCIRC $pcm_in_right;
        .VAR $audio_in_left[4096];
        .VAR $audio_in_right[4096];
    .ENDBLOCK;

    .VAR $audio_in_left_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($audio_in_left), &$audio_in_left, &$audio_in_left;

    .VAR $audio_in_right_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($audio_in_right), &$audio_in_right, &$audio_in_right;

    .VAR/DMCIRC $audio_out_left[6114];
    .VAR $audio_out_left_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($audio_out_left), &$audio_out_left, &$audio_out_left;

    .VAR/DMCIRC $audio_out_right[6114];
    .VAR $audio_out_right_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($audio_out_right), &$audio_out_right, &$audio_out_right;

    .VAR/DM $csb_frame_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR/DMCIRC $csb_frame_cbuffer[1024];
    .VAR $csb_frame_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($csb_frame_cbuffer), &$csb_frame_cbuffer, &$csb_frame_cbuffer;

    .VAR/DM $rtp_frame_md_list[MD_LIST_STRUC_SIZE] = 0 ...;
    .VAR $rtp_frame_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($rtp_frame_cbuffer), &$rtp_frame_cbuffer, &$rtp_frame_cbuffer;

    .VAR/DMCIRC $rtp_metadata_buffer[128];
    .VAR $rtp_metadata_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($rtp_metadata_buffer),   // size
        &$rtp_metadata_buffer,          // read pointer
        &$rtp_metadata_buffer;          // write pointer	

    .VAR/DMCIRC $csb_metadata_buffer[128];
    .VAR $csb_metadata_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($csb_metadata_buffer),   // size
        &$csb_metadata_buffer,          // read pointer
        &$csb_metadata_buffer;          // write pointer	

    // Atomic protection for CSB port connect/disconnect
    .CONST $CSB_PORT_DISCONNECTED       1;
    .CONST $CSB_PORT_CONNECTED          2;
    .CONST $CSB_PORT_CHANGE_NOT_IN_PROGRESS    0;
    .CONST $CSB_PORT_CHANGE_IN_PROGRESS        1;
    .VAR $app.csb_port_dest_state = $CSB_PORT_DISCONNECTED;
    .VAR $app.csb_port_change_state = $CSB_PORT_CHANGE_NOT_IN_PROGRESS;

    // initialise the interrupt library
    call $interrupt.initialise;

    // initialise the message library
    call $message.initialise;

    // initialise the cbuffer library
    call $cbuffer.initialise;
    
    // initialise the pskey library
    call $pskey.initialise;

    // prevent null pointers
    M[$M.prevent_using_addr_0.dummy_var] = Null;

    // register cbuffers for RTP & CSB port metadata
    //  TBD: only register when connected    
    r0 = $RTP_IN_PORT;
    r1 = &$rtp_metadata_cbuffer_struc;
    call $cbuffer.register_metadata_cbuffer;
    r0 = $CSB_OUT_PORT;
    r1 = &$csb_metadata_cbuffer_struc;
    call $cbuffer.register_metadata_cbuffer;

    // setup write port connect and disconnect callback functions
    r0 = &$app.write_port_disconnect_callback;
    M[$cbuffer.write_port_disconnect_address] = r0;
    r0 = &$app.write_port_connect_callback;
    M[$cbuffer.write_port_connect_address] = r0;
    r0 = &$app.read_port_connect_callback;
    M[$cbuffer.read_port_connect_address] = r0;
    r0 = &$app.read_port_disconnect_callback;
    M[$cbuffer.read_port_disconnect_address] = r0;


#ifdef INCLUDE_PROFILER
    .VAR/DM1 $profiler.rtp_input_process[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
    .VAR/DM1 $profiler.rtp_input_decode_frames[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
    .VAR/DM1 $profiler.csb_encode_frames[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
    .VAR/DM1 $profiler.csb_output_process[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
    .VAR/DM1 $profiler.audio_processing[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
    // initialise the profiler library
    call $profiler.initialise;
#endif

    // initialise meta-data block
    $call_c_with_void_return_macro(md_initialise);

    // initialise the wall-clock library
    call $wall_clock.initialise;

    // Setup the clock sources
    r0 = $CLOCK_SOURCE_LOCAL_TIME;
    r1 = &$app.clock_params_local_time;
    $call_c_with_void_return_macro(system_time_register_source);
    r0 = $CLOCK_SOURCE_CSB_WALL_CLOCK;
    r1 = &$app.clock_params_csb_wall_clock;
    $call_c_with_void_return_macro(system_time_register_source);

    // initialise time-to-play block
    r0 = &$app.ttp_state;
    $call_c_with_void_return_macro(ttp_initialise);

    r0 = $app.scmb_params;
    $call_c_with_void_return_macro(scmb_initialise);

    // initialise C version of audio output
    r0 = &$AUDIO_PORT_IDS;
    $call_c_with_void_return_macro(audio_output_initialise);

    // initialise audio processing
    call $audio_processing_initialise;
    r0 = &$M.codec_resampler.resamp_out_md_track_state_l;
    $call_c_with_void_return_macro(md_track_cbuffers_initialise);
    r0 = &$M.codec_resampler.resamp_out_md_track_state_r;
    $call_c_with_void_return_macro(md_track_cbuffers_initialise);

    // initialise CSB
    r0 = $app.csb_output_params;
    $call_c_with_void_return_macro(csb_output_initialise);

    // initialise EC
    r0 = $app.ec_output_params;
    $call_c_with_void_return_macro(ec_output_initialise);
    
    // initialise RTP input
    r0 = &$app.rtp_input_params;
    $call_c_with_void_return_macro(rtp_input_initialise);

    // initialise random number generator
    call $fwrandom.initialise;

    // register message handler for messages in the 0x3000 to 0x30FF range
    r1 = &$message.handler_struc;
    r2 = 0x3000;
    r3 = &$message.handler;
    r4 = 0x00FF;
    call $message.register_handler_with_mask;

    r1 = &$scm_message.handler_struc;
    r2 = 0x3100;
    r3 = &$scm_message.handler;
    r4 = 0x00FF;
    call $message.register_handler_with_mask;

    r1 = &$fw_bdaddr_message.handler_struc;
    r2 = $MESSAGE_PORT_BT_ADDRESS;
    r3 = &$fw_bdaddr_message.handler;
    call $message.register_handler;
    

   //   TONE_MIXER
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

#ifdef  SELECTED_MULTI_DECODER
   // handler for SETPLUGIN_MESSAGE_ID 
   r1 = &$set_plugin_message_struc;
   r2 = SETPLUGIN_MESSAGE_ID;
   r3 = &$M.set_plugin.func;
   call $message.register_handler;
#endif // SELECTED_MULTI_DECODER

   
   

    r1 = &$fw_audio_message.handler_struc;
    r2 = $MESSAGE_AUDIO_CONFIGURE_RESPONSE;
    r3 = &$fw_audio_message.handler;
    call $message.register_handler;
    
#if (uses_SPKR_EQ || uses_USER_EQ)
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

    // start timer that copies RTP data and audio samples
    r1 = &$timer.struc;
    r2 = $TIMER_PERIOD;
    r3 = &$timer.handler;
    call $timer.schedule_event_in;


main_loop:

    // Use r5 to sum the returns from all the processes.
    r5 = 0;

    PROFILER_START(&$profiler.rtp_input_process);
    r0 = &$app.rtp_input_params;
    $call_c_with_int_return_macro(rtp_input_process);
    r5 = r5 + r0;
    PROFILER_STOP(&$profiler.rtp_input_process);

    r0 = $RTP_IN_PORT;
    call $cbuffer.is_it_enabled;
    if Z jump skip_user_eq_and_rtp_decoder;

    r0 = $audio_in_left_cbuffer_struc;
    call $cbuffer.calc_amount_data;
    push r0; // amount data
    r0 = $audio_in_right_cbuffer_struc;
    call $cbuffer.calc_amount_data;
    pop r1;  // amount data
    r0 = min r1;
    push r1; // num samples predecode
    
    PROFILER_START(&$profiler.rtp_input_decode_frames);
    r0 = &$app.rtp_input_decoder_params;
    $call_c_with_int_return_macro(rtp_input_decode_frames);
    r5 = r5 + r0;
    PROFILER_STOP(&$profiler.rtp_input_decode_frames);

    r0 = $audio_in_left_cbuffer_struc;
    call $cbuffer.calc_amount_data;
    push r0; // amount data
    r0 = $audio_in_right_cbuffer_struc;
    call $cbuffer.calc_amount_data;
    pop r1; // amount data
    r0 = min r1;
    pop r1; // num sample post decode
    r1 = r0 - r1;
    push r5;
    call $audio_processing_user_eq;
    pop r5;

skip_user_eq_and_rtp_decoder:

    PROFILER_START(&$profiler.csb_encode_frames);
    r0 = &$app.csb_encoder_params;
    $call_c_with_int_return_macro(csb_encode_frames);
    r5 = r5 + r0;
    PROFILER_STOP(&$profiler.csb_encode_frames);

    PROFILER_START(&$profiler.csb_output_process);
    r0 = &$app.csb_output_params;
    r1 = &$app.ec_output_params;
    r2 = &$app.aesccm_params;
    $call_c_with_int_return_macro(csb_output_process);
    r5 = r5 + r0;
    PROFILER_STOP(&$profiler.csb_output_process);

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

    $call_c_with_void_return_macro(md_validate);

    Null = r5;
#ifndef RICK
    if Z call $SystemSleepAudio;
#endif
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
.MODULE $M.message.handler;
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

$message.handler:

    // push rLink onto stack
    $push_rLink_macro;

    /* Standard Messages */

    // jump if set sample rate message from VM
    Null = r0 - $MESSAGE_CONFIGURE_SCMS_T;
    if EQ jump message.handler_scms_t_config;

    // jump if LED colour message from VM
    Null = r0 - $MESSAGE_LED_COLOUR;
    if EQ jump message.handler_led_colour;

    // jump if set latency message from VM
    Null = r0 - $MESSAGE_SET_LATENCY;
    if EQ jump message.handler_set_latency;

    // jump if set volume message from VM
    Null = r0 - $MESSAGE_SET_VOLUME;
    if EQ jump message.handler_set_volume;

    // jump if random bits request from VM
    Null = r0 - $MESSAGE_RANDOM_BITS_REQ;
    if EQ jump message.handler_random_bits_req;

    // jump if csb output iv set message from VM
    Null = r0 - $MESSAGE_SET_IV;
    if EQ jump message.handler_set_iv;

    // jump if csb output fixed iv set message from VM
    Null = r0 - $MESSAGE_SET_FIXED_IV;
    if EQ jump message.handler_set_fixed_iv;

    // jump if set ttp_extension message from VM
    Null = r0 - $MESSAGE_SET_TTP_EXTENSION;
    if EQ jump message.handler_set_ttp_extension;

    // jump if set CSB timing message from VM
    Null = r0 - $MESSAGE_SET_CSB_TIMING;
    if EQ jump message.handler_set_csb_timing;

    // jump if set stream id message from VM
    Null = r0 - $MESSAGE_SET_STREAM_ID;
    if EQ jump message.handler_set_stream_id;

    // jump if celt config message from VM
    Null = r0 - $MESSAGE_SET_CELT_CONFIG;
    if EQ jump message.handler_set_celt_config;

    // jump if afh change pending message from VM
    Null = r0 - $MESSAGE_AFH_CHANNEL_MAP_CHANGE_PENDING;
    if EQ jump message.handler_afh_channel_map_change_pending;

    // Place all standard message tests before here
    Null = r0 - $message.LONG_MESSAGE_MODE_ID;
    if NE jump $pop_rLink_and_rts;

    /* Long Messages */

    // jump if csb output key set message from VM
    Null = r1 - $MESSAGE_SET_KEY;
    if EQ jump message.handler_set_key;

    // pop rLink from stack
    jump $pop_rLink_and_rts;
    

message.handler_scms_t_config:
    // r1 = 1 to enable SCMS_T.  0 to disable SCMS_T 
    // initialise RTP input
    Null = r1;
    if Z jump disable_scms_t;
	
    // enable scms_t
    r0 = &$app.rtp_input_params;
    $call_c_with_void_return_macro(rtp_enable_scms);
	
    jump rtp_scms_t_config_complete;

disable_scms_t:
    r0 = &$app.rtp_input_params;
    $call_c_with_void_return_macro(rtp_disable_scms);
	
rtp_scms_t_config_complete:
    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_led_colour:

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

message.handler_set_latency:

    // total latency (ms) r1
    r0 = r1;
    r1 = r0 * 1000 (int); // convert to us

    // TODO consider allowing each input to have different latency
    M[$app.analogue.ttp_settings_struc + TTP_SETTINGS_LATENCY_FIELD] = r1;
    M[$app.usb.ttp_settings_struc + TTP_SETTINGS_LATENCY_FIELD] = r1;
    M[$app.rtp.ttp_settings_struc + TTP_SETTINGS_LATENCY_FIELD] = r1;

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_set_csb_timing:

    // Set CSB transmit and encode windows
    r0 = &$app.csb_output_params;
    r1 = r1 * 1000 (int); // convert to us
    r2 = r2 * 1000 (int); // convert to us
    $call_c_with_void_return_macro(csb_output_set_tx_window);
    r0 = &$app.csb_encoder_params;
    $call_c_with_void_return_macro(csb_encoder_set_encode_time_min);
    r0 = &$app.ec_output_params;

    // The CSB interval in BT slots
    r1 = r3;
    $call_c_with_void_return_macro(ec_output_set_tx_interval);

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_set_volume:

    r0 = &$app.csb_output_params;
    $call_c_with_void_return_macro(csb_output_set_volume);


    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_random_bits_req:
    // r1 is the number of requested random bits
    r2 = r1;
    r1 = &$fwrandom_struc;
    r3 = &$fwrandom.callback;
    r4 = &$fwrandom_buffer;
    call $fwrandom.get_rand_bits;

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

message.handler_set_ttp_extension:
    // r1 contains the ttp extension to set
    r0 = &$app.csb_output_params;
    $call_c_with_void_return_macro(csb_output_set_ttp_extension);

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_set_stream_id:
    // r1 contains the stream id to use
    r0 = &$app.ec_output_params;
    $call_c_with_void_return_macro(ec_output_set_stream_id);
    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_set_celt_config:
    // r1 is the sample rate this config applies to
    // r2 is the number of octets per frame
    // r3 is the number of samples per frame
    // r4 is the number of channels
    // Only two channels and 512 samples per frame supported
    Null = r3 - 512;
    if NZ call $error;
    Null = r4 - 2;
    if NZ call $error;
    r1 = r1 AND 0xFFFF;

    r3 = &$celt_parameters_44100;
    r4 = &$celt_parameters_48000;
    r0 = 0;
    Null = r1 - 44100;
    if Z r0 = r3;
    Null = r1 - 48000;
    if Z r0 = r4;
    Null = r0;
    if Z call $error;
    M[r0 + 1] = r2;

    // pop rLink from stack
    jump $pop_rLink_and_rts;

message.handler_afh_channel_map_change_pending:
    r0 = &$app.ec_output_params;
    $call_c_with_void_return_macro(ec_output_afh_channel_map_change_is_pending);
    // pop rLink from stack
    jump $pop_rLink_and_rts;


$scm_message.handler:

    // r0 = message ID
    // r1 = message Data 0
    // r2 = message Data 1
    // r3 = message Data 2
    // r4 = message Data 3

    // push rLink onto stack
    $push_rLink_macro;

    // jump if set sample rate message from VM
    Null = r0 - $MESSAGE_SET_SCM_SEGMENT_REQ;
    if EQ jump scm_message.handler_set_scm_segment_req;

    Null = r0 - $MESSAGE_SCM_SHUTDOWN_REQ;
    if EQ jump scm_message.handler_scm_shutdown_req;

    // pop rLink from stack
    jump $pop_rLink_and_rts;

scm_message.handler_scm_shutdown_req:

    r0 = $app.scmb_params;
    $call_c_with_void_return_macro(scmb_shutdown);

    r2 = $MESSAGE_SCM_SHUTDOWN_CFM;
    call $message.send;

    // pop rLink from stack
    jump $pop_rLink_and_rts;


scm_message.handler_set_scm_segment_req:
        
    r0 = $app.scmb_params;
    //r1 = r1; // header
    r2 = r2 LSHIFT 16;  // data, 1st octet
    r3 = r3 AND 0xFFFF; // data, 2nd and 3rd octet
    r2 = r2 OR r3;      // combine into 1 word
    r3 = r4;
    $call_c_with_void_return_macro(scmb_segment_queue);

    // pop rLink from stack
    jump $pop_rLink_and_rts;

$app.scmb_segment_cfm:
    $push_rLink_macro;
    $kcc_regs_save_macro;

    r2 = $MESSAGE_SET_SCM_SEGMENT_CFM;
    r3 = r0;
    r4 = r1;
    call $message.send;    

    $kcc_regs_restore_macro;
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
    .CONST $STATUS_MESSAGE_TIMER_TICKS 500000 / $TIMER_PERIOD;
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
    r1 = &$app.ttp_state;
    r2 = &$app.csb_output_params;
    $call_c_with_void_return_macro(broadcast_status_send_broadcaster);
    // pop rLink from stack
    jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $timer.handler
//
// DESCRIPTION:
//    Function called on a timer interrupt to perform the DAC copying and RTP
//    copying.
//
// TRASHED REGISTERS:
//    All
//
// *****************************************************************************
.MODULE $M.timer.handler;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

    .VAR $app.audio.output.status = $audio.output.NO_AUDIO;
    .VAR $app.audio.active_port;

$timer.handler:

    // push rLink onto stack
    $push_rLink_macro;

    // post another timer event
    r1 = &$timer.struc;
    r2 = $TIMER_PERIOD;
    r3 = &$timer.handler;
    call $timer.schedule_event_in_period;

    M[$frame_sync.sync_flag] = Null;

    // Copy tone from port into cbuffer, resample it to DAC rate, and mix with primary audio
    call $M.post_eq.processing;

    r0 = $dacout_left_md_list;
    r1 = $dacout_right_md_list;
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
    r1 = r1 AND r0;
    Null = r1 AND $audio.output.NO_AUDIO;
    if Z jump timer_handler_noresync;
    r0 = &$app.ttp_state;
    $call_c_with_void_return_macro(ttp_resync);

timer_handler_noresync:

    // Copy EC packet
    r0 = &$app.ec_output_params;
    r1 = $TIMER_PERIOD;
    $call_c_with_void_return_macro(ec_output_copy);

    r0 = &$app.ttp_state;
    r1 = $TIMER_PERIOD;
    $call_c_with_int_return_macro(ttp_tick);

    // check if packet from RTP input port
timer_handler_test_rtp_port:
    r0 = $RTP_IN_PORT;
    call $cbuffer.is_it_enabled;
    if Z jump timer_handler_test_usb_port;
    r0 = $RTP_IN_PORT;
    r5 = &$_rtp_input_copy_packet;
    r6 = &$app.rtp_input_params;
    jump timer_handler_read_source;

    // check if packet from USB input port
timer_handler_test_usb_port:
    r0 = $USB_IN_PORT;
    call $cbuffer.is_it_enabled;
    if Z jump timer_handler_test_analogue_ports;
    r0 = $USB_IN_PORT;
    r5 = &timer_handler_read_usb_ports;
    r6 = &$app.usb_input_params;
    jump timer_handler_read_source;

timer_handler_read_usb_ports:
    $push_rLink_macro;
    $call_c_with_void_return_macro(usb_input_copy_and_timestamp_frames);
    jump $pop_rLink_and_rts;

timer_handler_test_analogue_ports:
    r0 = $AUDIO_LEFT_IN_PORT;
    call $cbuffer.is_it_enabled;
    if Z jump timer_handler_update_led_pwm;
    r0 = $AUDIO_RIGHT_IN_PORT;
    call $cbuffer.is_it_enabled;
    if Z jump timer_handler_update_led_pwm;
    r0 = $AUDIO_LEFT_IN_PORT;
    r5 = &timer_handler_read_analogue_ports;
    r6 = &$app.analogue_input_params;
    jump timer_handler_read_source;

timer_handler_read_analogue_ports:
    $push_rLink_macro;
    $call_c_with_void_return_macro(analogue_input_copy_and_timestamp_frames);
    jump $pop_rLink_and_rts;

timer_handler_read_source:
    NULL = r0 - M[$app.audio.active_port];
    if NZ jump timer_handler_source_changed;


    r0 = M[$app.audio.active_port];
    Null = r0 - $RTP_IN_PORT;
    if  Z  jump skip_preprocess;
    r0 = $audio_in_left_cbuffer_struc;
    call $cbuffer.calc_amount_data;
    push r0; // amount data
    r0 = $audio_in_right_cbuffer_struc;
    call $cbuffer.calc_amount_data;
    pop r1;  // amount data
    r0 = min r1;
    push r1; // num samples predecode
skip_preprocess:    

    // The source is unchanged
    r0 = r6; // Parameters
    call r5; // Read from the input port
    
    r0 = M[$app.audio.active_port];
    Null = r0 - $RTP_IN_PORT;
    if  Z  jump skip_postprocess;
    r0 = $audio_in_left_cbuffer_struc;
    call $cbuffer.calc_amount_data;
    push r0; // amount data
    r0 = $audio_in_right_cbuffer_struc;
    call $cbuffer.calc_amount_data;
    pop r1; // amount data
    r0 = min r1;
    pop r1; // num sample post decode
    r1 = r0 - r1;
    call $audio_processing_user_eq;
skip_postprocess:    


    jump timer_handler_update_led_pwm;

timer_handler_source_changed:
    // The source has changed
    M[$app.audio.active_port] = r0;

    // TODO - reinitialise TTP, with correct sample rate
    r0 = r6; // Params to input reader
    call r5; // Read from the input port

timer_handler_update_led_pwm:
    call $led.update_pwm;

    // update volume
    call $app.send_status_message;

    // validate meta-data lists
    $call_c_with_void_return_macro(md_validate);

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
    r0 = $CLOCK_SOURCE_CSB_WALL_CLOCK;
    r1 = r2;
    $call_c_with_void_return_macro(system_time_set_source_offset);

    r0 = M[$wall_clock.running];
    if NZ jump $pop_rLink_and_rts;

    // Set the csb wall clock as an active source
    r0 = $CLOCK_SOURCE_CSB_WALL_CLOCK;
    $call_c_with_void_return_macro(system_time_set_source_active);

    // Change system time from local time to csb time
    r1 = $CLOCK_SOURCE_CSB_WALL_CLOCK;
    M[$app.system_time_source] = r1;

    r0 = 1;
    M[$wall_clock.running] = r0;

    // all done, clear the busy flag
    r0 = $CSB_PORT_CHANGE_NOT_IN_PROGRESS;
    M[$app.csb_port_change_state] = r0;

    // check if we're in the destination state we need to be
    r0 = M[$app.csb_port_dest_state];
    NULL = r0 - $CSB_PORT_CONNECTED;
    if NZ call $app.disconnect_csb_port;

    jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $app.port_change_callbacks
// FUNCTIONS:
//    $app.write_port_connect_callback
//    $app.write_port_disconnect_callback
//    $app.read_port_connect_callback
//    $app.read_port_disconect_callback
//
// DESCRIPTION:
//    Functions called by cbuffer library when write/read port is
//    connected / disconnected.
//
// INPUTS:
//    r0 = $cbuffer.CALLBACK_PORT_CONNECT or $cbuffer.CALLBACK_PORT_DISCONNECT
//    r1 = the port number connected / disconnected
//
// *****************************************************************************
.MODULE $M.app.port_change_callbacks;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$app.write_port_connect_callback:
    r1 = r1 - CBUFFER_WRITE_PORT_OFFSET;
    Null = r1 - $AUDIO_OUT_LEFT_PORT_NUMBER;
    if Z jump audio_out_port_connected;
    Null = r1 - $AUDIO_OUT_RIGHT_PORT_NUMBER;
    if Z jump audio_out_port_connected;
    Null = r1 - $CSB_OUT_PORT_NUMBER;
    if Z jump csb_out_port_connected;
    rts;
$app.write_port_disconnect_callback:
    r1 = r1 - CBUFFER_WRITE_PORT_OFFSET;
    Null = r1 - $AUDIO_OUT_LEFT_PORT_NUMBER;
    if Z jump audio_out_port_disconnected;
    Null = r1 - $AUDIO_OUT_RIGHT_PORT_NUMBER;
    if Z jump audio_out_port_disconnected;
    Null = r1 - $CSB_OUT_PORT_NUMBER;
    if Z jump csb_out_port_disconnected;
    rts;

$app.read_port_connect_callback:
    Null = r1 - $AUDIO_IN_LEFT_PORT_NUMBER;
    if Z jump pcm_in_port_connected;
    Null = r1 - $AUDIO_IN_RIGHT_PORT_NUMBER;
    if Z jump pcm_in_port_connected;
    Null = r1 - $USB_IN_PORT_NUMBER;
    if Z jump pcm_in_port_connected;
    rts;
$app.read_port_disconnect_callback:
    rts;

// For USB or analogue inputs, change $audio_in_l/r_cbuffer_struc to use
// block buffer names.
pcm_in_port_connected:
    r0 = min(LENGTH($pcm_in_left), LENGTH($pcm_in_right));
    M[$audio_in_left_cbuffer_struc + $cbuffer.SIZE_FIELD] = r0;
    M[$audio_in_right_cbuffer_struc + $cbuffer.SIZE_FIELD] = r0;
    r0 = &$pcm_in_left;
    M[$audio_in_left_cbuffer_struc + $cbuffer.READ_ADDR_FIELD] = r0;
    M[$audio_in_left_cbuffer_struc + $cbuffer.WRITE_ADDR_FIELD] = r0;
    r0 = &$pcm_in_right;
    M[$audio_in_right_cbuffer_struc + $cbuffer.READ_ADDR_FIELD] = r0;
    M[$audio_in_right_cbuffer_struc + $cbuffer.WRITE_ADDR_FIELD] = r0;
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

// Handle AUDIO_OUT_LEFT/RIGHT_PORT disconnected
audio_out_port_disconnected:
    // Set bit on disconnect
    r0 = 1 LSHIFT r1;
    r1 = M[$app.audio_output_ports_disconnected];
    r1 = r1 OR r0;
    M[$app.audio_output_ports_disconnected] = r1;
    rts;

// Handle CSB_OUT_PORT connected
csb_out_port_connected:
    // set the destination state to be CONNECTED
    r0 = $CSB_PORT_CONNECTED;
    M[$app.csb_port_dest_state] = r0;
    // connect now if CSB port is not currently in progress
    r0 = M[$app.csb_port_change_state];
    NULL = r0 - $CSB_PORT_CHANGE_NOT_IN_PROGRESS;
    if Z jump csb_out_port_connect_now;
    rts;
csb_out_port_connect_now:
    $push_rLink_macro;
    call $app.connect_csb_port;
    jump $pop_rLink_and_rts;
    
// Handle CSB_OUT_PORT disconnect
csb_out_port_disconnected:
    // set the destination state to be DISCONNECTED
    r0 = $CSB_PORT_DISCONNECTED;
    M[$app.csb_port_dest_state] = r0;
    // disconnect now if CSB port change not currently in progress
    r0 = M[$app.csb_port_change_state];
    NULL = r0 - $CSB_PORT_CHANGE_NOT_IN_PROGRESS;
    if Z jump csb_out_port_disconnect_now;
    rts;
csb_out_port_disconnect_now:
    $push_rLink_macro;
    call $app.disconnect_csb_port;
    jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $app_csb_port_actions
// FUNCTIONS:
//    $app.connect_csb_port
//    $app.disconnect_csb_port
//
// DESCRIPTION:
//    Functions called to perform connection (including associated messaging
//    with firmware) and disconnection of CSB port.
//
// TRASHED REGISTERS:
//    r0, r1, r2, r3
//
// *****************************************************************************
.MODULE $M.app_csb_port_actions;
    .CODESEGMENT PM;

$app.connect_csb_port:
    // indicate we're busy changing the port state
    r2 = $CSB_PORT_CHANGE_IN_PROGRESS;
    M[$app.csb_port_change_state] = r2;

    $push_rLink_macro;
    // Request BDADDR of CSB_OUT_PORT  
    r2 = $MESSAGE_GET_BT_ADDRESS;
    r3 = $CSB_OUT_PORT_NUMBER + CBUFFER_WRITE_PORT_OFFSET;
    call $message.send;
    jump $pop_rLink_and_rts;

$app.disconnect_csb_port:
    // indicate we're busy changing the port state
    r0 = $CSB_PORT_CHANGE_IN_PROGRESS;
    M[$app.csb_port_change_state] = r0;

    $push_rLink_macro;
    // Clear the csb clock as an inactive source
    r0 = $CLOCK_SOURCE_CSB_WALL_CLOCK;
    $call_c_with_void_return_macro(system_time_set_source_inactive);

    // Disable wall-clock
    r1 = &$_wall_clock_struc;
    call $wall_clock.disable;
    M[$wall_clock.running] = Null;

    // Change system time from csb time to local time
    r1 = $CLOCK_SOURCE_LOCAL_TIME;
    M[$app.system_time_source] = r1;

    // all done, clear the busy flag
    r1 = $CSB_PORT_CHANGE_NOT_IN_PROGRESS;
    M[$app.csb_port_change_state] = r1;

    // check if we're in the destination state we need to be
    r1 = M[$app.csb_port_dest_state];
    NULL = r1 - $CSB_PORT_DISCONNECTED;
    if NZ call $app.connect_csb_port;

    jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $fwrandom.callback
//
// DESCRIPTION:
//    Function called by the fwrandom library when the request completes.
//    Retries if the request fails
//
// INPUTS:
//    r2 - the number of words returned
//    r3 - the address of the buffer containing the random bits
//
// TRASHED REGISTERS:
//    All
//
// *****************************************************************************
.MODULE $M.fwrandom_callback;
    .CODESEGMENT PM;
    .DATASEGMENT DM;

$fwrandom.callback:
    $push_rLink_macro;

    // Request again if request failed
    NULL = r2 - $fwrandom.READ_FAILED;
    if Z jump $M.message.handler.message.handler_random_bits_req;
    // Request succeeded

    // convert bits to XAP words
    r1 = M[&$fwrandom_struc + $fwrandom.NUM_RESP_FIELD];
    r1 = r1 + 15;
    r1 = r1 ASHIFT -4;

    // Send the result to the VM
    r5 = r3;
    r4 = r1;
    r2 = $message.LONG_MESSAGE_MODE_ID;
    r3 = $MESSAGE_RANDOM_BITS_RESP;
    call $message.send;

    jump $pop_rLink_and_rts;

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
        2,                            // number of inputs
        &post_eq_left_cbuffer_struc,  // CONFIG_FIELD
        &post_eq_right_cbuffer_struc, // CONFIG_FIELD
        2,
        &dacout_left_cbuffer_struc,  // CONFIG_FIELD
        &dacout_right_cbuffer_struc; // CONFIG_FIELD


   .VAR dacout_md_track_state_l[MD_TRACK_STATE_STRUC_SIZE] =
        &post_eq_left_cbuffer_struc,        // md_track_state.input_cbuffer
        &dacout_left_cbuffer_struc,         // md_track_state.output_cbuffer
        &$audio_out_left_md_list,           // md_track_state.input_md_list
        &$dacout_left_md_list,              // md_track_state.output_md_list
        0,                                  // md_track_state.algorithmic_delay_samples
        0 ...;
   .VAR dacout_md_track_state_r[MD_TRACK_STATE_STRUC_SIZE] =
        &post_eq_right_cbuffer_struc,       // md_track_state.input_cbuffer
        &dacout_right_cbuffer_struc,        // md_track_state.output_cbuffer
        &$audio_out_right_md_list,          // md_track_state.input_md_list
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
   r4 = r4 - M[$interrupt.total_time]; // - time spent in interrupt during this sleep
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
