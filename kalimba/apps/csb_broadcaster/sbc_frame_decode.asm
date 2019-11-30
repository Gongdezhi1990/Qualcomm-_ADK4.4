// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
// *****************************************************************************

#if defined(SELECTED_DECODER_SBC) || defined(SELECTED_MULTI_DECODER)

#include <codec_library.h>
#include <interrupt.h>
#include <sbc_library.h>
#include <stack.h>

// *****************************************************************************
// MODULE:
//    sbc_frame_decode
//
// DESCRIPTION:
//    Decodes a single SBC frame writing the PCM data to
//    $audio.decode.left_cbuffer_struc and
//    $audio.decode.right_cbuffer_struc
//
// INPUTS:
//    - r0 = Pointer to the codec input cbuffer.
//    - r1 = The size of the encoded audio frame in octets.
//    - r2 = Array of pointers to PCM cbuffers.
//    - r3 = The nominal sample rate (unused)
//
// OUTPUTS:
//    - r0 = the number of samples OR < 0 if an error occurred
//
// TRASHED REGISTERS:
//   r0, r1, r2, r3
//
// *****************************************************************************
.MODULE $M.sbc_frame_decode;
    .CODESEGMENT PM;
    .DATASEGMENT DM;

    // decoder structure
    .VAR/DM1 $audio_decode_sbc_codec_stream_struc[$codec.av_decode.STRUC_SIZE] =
        &$sbcdec.frame_decode_aligned,             // frame_decode function
        &$sbcdec.reset_decoder,                    // reset_decoder function
        &$sbcdec.silence_decoder,                  // silence_decoder function
        0,                                         // in cbuffer
        0,                                         // out left cbuffer
        0,                                         // out right cbuffer
        0,                                         // MODE_FIELD
        0,                                         // STALL_COUNTER_FIELD
        0,                                         // BUFFERING_THRESHOLD_FIELD
        0 ...;

    .VAR $sbc_frame_decode.initialised = 0;

sbc_decode_frame_init:
    pushm <r0,r1,r2,r3>; // Preserve C parameters
    r5 = $audio_decode_sbc_codec_stream_struc + $codec.av_decode.DECODER_STRUC_FIELD;
    call $sbcdec.init_static_decoder;
    r0 = 1;
    M[$sbc_frame_decode.initialised] = r0;
    // Return on corrupt frame, do not reattempt decode
    r5 = $audio_decode_sbc_codec_stream_struc + $codec.av_decode.DECODER_STRUC_FIELD;
    r1 = M[r5 + $codec.DECODER_DATA_OBJECT_FIELD];
    M[r1 + $sbc.mem.RETURN_ON_CORRUPT_FRAME_FIELD] = r0;   
    // disable frame sync search
    M[r1 + $sbc.mem.FRAME_SYNC_SEARCH_DISABLE] = r0;
    popm <r0,r1,r2,r3>;
    jump sbc_decode_frame_initialised;

$_sbc_decode_frame:
    $push_rLink_macro;
    $kcc_regs_save_macro;

    Null = M[$sbc_frame_decode.initialised];
    if Z jump sbc_decode_frame_init; // Initialise on first use
sbc_decode_frame_initialised:

    M[$audio_decode_sbc_codec_stream_struc + $codec.av_decode.IN_BUFFER_FIELD] = r0;
    r6 = M[r2];
    M[$audio_decode_sbc_codec_stream_struc + $codec.av_decode.OUT_LEFT_BUFFER_FIELD] = r6;
    r6 = M[r2 + 1];
    M[$audio_decode_sbc_codec_stream_struc + $codec.av_decode.OUT_RIGHT_BUFFER_FIELD] = r6;

    // attempt to decode the frame
    r5 = &$audio_decode_sbc_codec_stream_struc;
    r0 = $codec.NORMAL_DECODE;
    M[r5 + $codec.av_decode.MODE_FIELD] = r0;
    r0 = M[r5 + $codec.av_decode.ADDR_FIELD];
    r5 = r5 + $codec.av_decode.DECODER_STRUC_FIELD;
    call r0;
    r0 = M[r5 + $codec.DECODER_MODE_FIELD];
    Null = r0 - $codec.SUCCESS;
    if NE jump error;

    r0 = M[r5 + $codec.DECODER_NUM_OUTPUT_SAMPLES_FIELD];
    jump out;
error:
    r0 = -r0;
out:
    $kcc_regs_restore_macro;
    jump $pop_rLink_and_rts;


.ENDMODULE;
#endif /* SELECTED_DECODER_SBC || SELECTED_MULTI_DECODER */
