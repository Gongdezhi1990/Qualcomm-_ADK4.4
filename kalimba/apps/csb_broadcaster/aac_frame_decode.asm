// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
// *****************************************************************************

#if defined(SELECTED_DECODER_AAC) || defined(SELECTED_MULTI_DECODER)

#include <codec_library.h>
#include <interrupt.h>
#include <aac_library.h>
#include <stack.h>



// *****************************************************************************
// MODULE:
//    aac_frame_decode
//
// DESCRIPTION:
//    Decodes a single AAC frame writing the PCM data to
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
.MODULE $M.aac_frame_decode;
    .CODESEGMENT PM;
    .DATASEGMENT DM;

    // decoder structure
    .VAR/DM1 $audio_decode_aac_codec_stream_struc[$codec.av_decode.STRUC_SIZE] =
        &$aacdec.frame_decode,                     // frame_decode function
        &$aacdec.reset_decoder,                    // reset_decoder function
        &$aacdec.silence_decoder,                  // silence_decoder function
        0,                                         // in cbuffer
        0,                                         // out left cbuffer
        0,                                         // out right cbuffer
        0,                                         // MODE_FIELD
        0,                                         // STALL_COUNTER_FIELD
        0,                                         // BUFFERING_THRESHOLD_FIELD
        0 ...;

    .VAR $aac_frame_decode.initialised = 0;

aac_decode_frame_init:
    pushm <r0,r1,r2,r3>; // Preserve C parameters
    r5 = $audio_decode_aac_codec_stream_struc + $codec.av_decode.DECODER_STRUC_FIELD;
    call $aacdec.init_decoder;
    r0 = 1;
    M[$aac_frame_decode.initialised] = r0;
    r0 = &$aacdec.latm_read_frame;
    M[$aacdec.read_frame_function] = r0;
    popm <r0,r1,r2,r3>;
    jump aac_decode_frame_initialised;


$_aac_decode_frame:
    $push_rLink_macro;
    $kcc_regs_save_macro;

    Null = M[$aac_frame_decode.initialised];
    if Z jump aac_decode_frame_init; // Initialise on first use
aac_decode_frame_initialised:

    // encoded frame from RTP packet is copied to codec_buffer for decode
    M[$audio_decode_aac_codec_stream_struc + $codec.av_decode.IN_BUFFER_FIELD] = r0;
    r3 = M[r2];
    M[$audio_decode_aac_codec_stream_struc + $codec.av_decode.OUT_LEFT_BUFFER_FIELD] = r3;
    r3 = M[r2 + 1];
    M[$audio_decode_aac_codec_stream_struc + $codec.av_decode.OUT_RIGHT_BUFFER_FIELD] = r3;

    // If there are an odd number of octets in the frame then
    // only the one byte of the last word is valid.
    r6 = r1 AND 1;
    M[$aacdec.write_bytepos] = r6;
    r6 = 16;
    M[$aacdec.get_bitpos] = r6;

    // attempt to decode the frame
    r5 = &$audio_decode_aac_codec_stream_struc;
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

#endif /* SELECTED_DECODER_AAC || SELECTED_MULTI_DECODER  */
