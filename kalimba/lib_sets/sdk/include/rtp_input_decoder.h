/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file rtp_input_decoder.h
    @brief  Decode RTP packets.

    Decodes RTP packets from an A2DP audio stream.
*/

#ifndef RTP_INPUT_DECODER_H
#define RTP_INPUT_DECODER_H

#ifdef KCC

#include <core_library_c_stubs.h>
#include <md.h>

typedef int (*rtp_input_decode_frame_fn_t)(
        cbuffer_t *codec_cbuffer, int num_octets, cbuffer_t *pcm_buffers[]);

typedef struct rtp_input_decoder_params
{
    md_list_t *codec_md_list;

    cbuffer_t *audio_in_left_cbuffer;
    cbuffer_t *audio_in_right_cbuffer;

    md_list_t *audio_in_left_md_list;
    md_list_t *audio_in_right_md_list;

    rtp_input_decode_frame_fn_t rtp_input_decode_frame_fn;
} rtp_input_decoder_params_t;

/**
 * \brief  Decode all available RTP frames.
 *
 * \param params The RTP input decoder parameters/state
 * \return False, because this function always runs until it is blocked
 */
bool rtp_input_decode_frames(struct rtp_input_decoder_params *params);

#endif /* KCC */

/* Size in words of the analogue_input_params structure */
#define RTP_INPUT_DECODER_PARAMS_STRUC_SIZE    6

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(rtp_input_decoder_params_t, RTP_INPUT_DECODER_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* RTP_INPUT_DECODER_H */

