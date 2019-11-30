// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
// *****************************************************************************

#include <codec_library.h>
#include <interrupt.h>
#include <celt_library.h>
#include <stack.h>
#include <csb_encoder.h>

// *****************************************************************************
// MODULE:
//    celt_frame_encode
//
// DESCRIPTION:
//    Encodes a single CELT frame, reading the PCM data from r1 pointers
//
// INPUTS:
//    - r0 = Pointer to the codec output cbuffer.
//    - r1 = Array of pointers to PCM cbuffers.
//    - r2 = Sample rate
//
// OUTPUTS:
//    - r0 = the number of octets OR < 0 if an error occurred
//
// TRASHED REGISTERS:
//   r0, r1, r2, r3
//
// *****************************************************************************
.MODULE $M.celt_frame_encode;
    .CODESEGMENT PM;
    .DATASEGMENT DM;

    .VAR $celt_parameters_44100[2] = &$celt.mode.celt_512_44100_mode, // mode
                                     222; // frame size octets
    .VAR $celt_parameters_48000[2] = &$celt.mode.celt_512_48000_mode, // mode
                                     190; // frame size octets

    .VAR $audio_encode_codec_stream_struc[$celt.enc.STRUC_SIZE + 20] =
        0,                  // $celt.enc.ENCODER_OUT_BUFFER_FIELD
        0,                  // $celt.enc.ENCODER_IN_LEFT_BUFFER_FIELD
        0,                  // $celt.enc.ENCODER_IN_RIGHT_BUFFER_FIELD
        0,                  // $celt.enc.ENCODER_MODE_FIELD
        0,                  // unused
        0,                  // $celt.enc.CELT_MODE_OBJECT_FIELD
        0,                  // $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD
        $celt.STEREO_MODE,  // $celt.enc.CELT_CHANNELS_FIELD
        &$celt.mdct_radix2, // $celt.enc.MDCT_FUNCTION_FIELD
        &$celt.mdct_radix2, // $celt.enc.MDCT_SHORT_FUNCTION_FIELD
        0 ...;

    .VAR $celt_frame_encode.initialised = 0;
    .VAR $celt_frame_encode.write_address;

celt_encode_frame_init:
    pushm <r0,r1,r2,r3>; // Preserve C parameters

    // configure CELT encoder for new sample rate / frame size
    Null = r2 - 44100;
    if Z jump sample_rate_44100;
    Null = r2 - 48000;
    if Z jump sample_rate_48000;
    // unknown sample rate
    call $error;
sample_rate_44100:
    r3 = M[$celt_parameters_44100 + 0];
    M[$audio_encode_codec_stream_struc + $celt.enc.CELT_MODE_OBJECT_FIELD] = r3;
    r3 = M[$celt_parameters_44100 + 1];
    M[$audio_encode_codec_stream_struc + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD] = r3;
    jump sample_rate_config_complete;
sample_rate_48000:
    r3 = M[$celt_parameters_48000 + 0];
    M[$audio_encode_codec_stream_struc + $celt.enc.CELT_MODE_OBJECT_FIELD] = r3;
    r3 = M[$celt_parameters_48000 + 1];
    M[$audio_encode_codec_stream_struc + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD] = r3;
    jump sample_rate_config_complete;
sample_rate_config_complete:
    r0 = r2;
    r5 = &$audio_encode_codec_stream_struc;
    call $celt.encoder.init;

    // Initialise csb_encoder_params.csb_encoder_delay_samples
    r0 = M[$audio_encode_codec_stream_struc + $celt.enc.CELT_MODE_OBJECT_FIELD];
    r0 = M[r0 + $celt.mode.OVERLAP_FIELD];
    r1 = &$app.csb_encoder_params;
    M[r1 + CSB_ENCODER_PARAMS_CSB_ENCODER_DELAY_SAMPLES_FIELD] = r0;

    popm <r0,r1,r2,r3>;
    M[$celt_frame_encode.initialised] = r2;
    jump celt_encode_frame_initialised;

$celt_encode_frame:
    $push_rLink_macro;
    $kcc_regs_save_macro;

    Null = r2 - M[$celt_frame_encode.initialised];
    if NE jump celt_encode_frame_init; // Initialise on first use or change of sample rate

celt_encode_frame_initialised:

    M[$audio_encode_codec_stream_struc + $celt.enc.ENCODER_OUT_BUFFER_FIELD] = r0;
    r6 = M[r1];
    M[$audio_encode_codec_stream_struc + $celt.enc.ENCODER_IN_LEFT_BUFFER_FIELD] = r6;
    r6 = M[r1 + 1];
    M[$audio_encode_codec_stream_struc + $celt.enc.ENCODER_IN_RIGHT_BUFFER_FIELD] = r6;

    // get current write address to calculate number of words that have
    // been written after encoder has run
    // r0 contains address of output cbuffer struc function argument
    call $cbuffer.get_write_address_and_size;
    M[$celt_frame_encode.write_address] = r0;

    // attempt to encode a frame
    r5 = &$audio_encode_codec_stream_struc;
    call $celt.frame_encode;

    // Exit if encode was unsuccessful
    r0 = M[$audio_encode_codec_stream_struc + $celt.enc.ENCODER_MODE_FIELD];
    r0 = $codec.SUCCESS - r0;
    if NE jump celt_encode_frame_error;

    // calculate number of octets that have been written
    r0 = M[$audio_encode_codec_stream_struc + $celt.enc.ENCODER_OUT_BUFFER_FIELD];
    call $cbuffer.get_write_address_and_size;
    r0 = r0 - M[$celt_frame_encode.write_address];
    if NEG r0 = r0 + r1;
    r0 = r0 ASHIFT 1;

celt_encode_frame_exit:
    $kcc_regs_restore_macro;
    jump $pop_rLink_and_rts;

celt_encode_frame_error:
    r0 = 0;
    jump celt_encode_frame_exit;

.ENDMODULE;
