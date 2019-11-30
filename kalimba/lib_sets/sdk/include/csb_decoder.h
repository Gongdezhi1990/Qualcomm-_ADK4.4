/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file csb_decoder.h
    @brief CSB Decoder
    
    Decodes audio frames from received CSB packets.    
*/

#ifndef CSB_DECODER_H
#define CSB_DECODER_H

#ifdef KCC
#include <core_library_c_stubs.h>
#include <md.h>

typedef int (*csb_decode_frame_fn_t)(
    cbuffer_t *codec_cbuffer_struc,        /** Pointer to codec cbuffer structures */
    unsigned num_octets,                   /** Number of octets in the frame */
    const cbuffer_t *pcm_cbuffer_strucs[], /** Array of pointers to l/r pcm cbuffer structures */
    unsigned sample_rate                   /** Frame sample rate */
    );

typedef struct csb_decoder_params
{
    /** Codec frames metadata list */
    md_list_t *codec_md_list;
    /** Codec frames data */
    cbuffer_t *codec_cbuffer_struc;
    /** Decoded PCM frames metadata list L */
    md_list_t *pcm_left_md_list;
    /** Decoded PCM frames metdata list R */
    md_list_t *pcm_right_md_list;
    /** Decoded PCM frames data L */
    cbuffer_t *pcm_left_cbuffer_struc;
    /** Decoded PCM fraemes data R */
    cbuffer_t *pcm_right_cbuffer_struc;
    /** The CSB decoder will call this function to decode a frame*/
    csb_decode_frame_fn_t csb_decode_frame_fn;
    /** The csb encoder will assign this system_time_source to decoded frames */
    unsigned system_time_source;
} csb_decoder_params_t;

/**
 * \brief  Decode one broadcast frame
 *
 * \param params The csb decoder parameters/state
 * \return True if the function decoded a broadcast frame and more frames are
 *         available to decode. False if the decoder is blocked (for example
 *         because there was no frame).
 */
bool csb_decode_frames(csb_decoder_params_t *params);

#endif /* KCC */

#define CSB_DECODER_PARAMS_STRUC_SIZE (8)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(csb_decoder_params_t, CSB_DECODER_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* CSB_DECODER_H */
