// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
// *****************************************************************************

#include <codec_library.h>
#include <interrupt.h>
#include <stack.h>
#include "celt_library.h"

#define FFT_TWIDDLE_NEED_256_POINT
#include "fft_twiddle.h"

// *****************************************************************************
// MODULE:
//    celt_decode_frame
//
// DESCRIPTION:
//    Decodes a single CELT frame.
//
// INPUTS:
//    - r0 = Pointer to the codec input cbuffer.
//    - r1 = The size of the encoded audio frame in octets.
//    - r2 = Array of pointers to PCM cbuffers.
//    - r3 = The nominal sample rate
//
// OUTPUTS:
//    - r0 = the number of samples OR < 0 if an error occurred
//
// TRASHED REGISTERS:
//   r0, r1, r2, r3
//
// *****************************************************************************
.MODULE $M.$_celt_decode_frame;
    .CODESEGMENT PM;
    .DATASEGMENT DM;

    .VAR $celt_frame_decode.codec_stream_struc[$celt.dec.STRUC_SIZE] =
       0,                                        // in cbuffer
       0,                                        // out left cbuffer
       0,                                        // out right cbuffer
       0,                                        // mode field
       0,                                        // number of output samples field
       &$celt.mode.celt_512_44100_mode,
       0,                                        // codec frame size from r1
       $celt.STEREO_MODE,
       &$celt.imdct_radix2,                      // imdct function field
       &$celt.imdct_radix2,                      // imdct short function field
       0 ...;

    .VAR $celt_frame_decode.sample_rate;         // sample rate of current frame being decoded

$_celt_decode_frame:

    // push rLink onto stack
    $push_rLink_macro;
    $kcc_regs_save_macro;

    r5 = &$celt_frame_decode.codec_stream_struc;
    M[r5 + $celt.dec.DECODER_IN_BUFFER_FIELD] = r0;
    r4 = M[r2];
    M[r5 + $celt.dec.DECODER_OUT_LEFT_BUFFER_FIELD] = r4;
    r4 = M[r2 + 1];
    M[r5 + $celt.dec.DECODER_OUT_RIGHT_BUFFER_FIELD] = r4;
    M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD] = r1;

    // read sample rate of frame, check if it has changed from previous frame
    Null = r3 - M[$celt_frame_decode.sample_rate];
    if EQ jump celt_frame_decode.sample_rate_no_change;
    M[$celt_frame_decode.sample_rate] = r3;

    // re-configure CELT decoder for new sample rate
    r5 = &$celt_frame_decode.codec_stream_struc;
    r0 = r3;
    call $celt.init_decoder;

celt_frame_decode.sample_rate_no_change:

    // decode the frame
    r5 = &$celt_frame_decode.codec_stream_struc;
    r0 = $codec.NORMAL_DECODE;
    M[r5 + $celt.dec.DECODER_MODE_FIELD] = r0;
    call $celt.frame_decode;
    r5 = &$celt_frame_decode.codec_stream_struc;
    r0 = M[r5 + $celt.dec.DECODER_MODE_FIELD];
    Null = r0 - $codec.SUCCESS;
    if NE jump error;
    r0 = M[r5 + $codec.DECODER_NUM_OUTPUT_SAMPLES_FIELD];  // number of audio samples
    jump out;

error:
    r0 = -r0;

out:
    $kcc_regs_restore_macro;
    jump $pop_rLink_and_rts;

.ENDMODULE;
