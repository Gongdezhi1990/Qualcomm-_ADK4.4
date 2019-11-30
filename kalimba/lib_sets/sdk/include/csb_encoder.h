/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file csb_encoder.h
    @brief CSB Encoder
    
    Encodes audio frames to go into CSB packets.    
*/

#ifndef CSB_ENCODER_H
#define CSB_ENCODER_H

#ifdef KCC
#include <core_library_c_stubs.h>
#include <md.h>

typedef int (*csb_encode_frame_fn_t)(
    cbuffer_t *codec_cbuffer_struc,        /** Pointer to codec cbuffer structures */
    const cbuffer_t *pcm_cbuffer_strucs[], /** Array of pointers to l/r pcm cbuffer structures */
    unsigned sample_rate                   /** Frame sample rate */
    );

typedef struct csb_encoder_params
{
    /** PCM frames metadata L/R in */
    md_list_t *audio_in_md_list[2];
    /** PCM frames metadata L/R out */
    md_list_t *audio_out_md_list[2];
    /** Codec frames metadata list */
    md_list_t *frame_md_list;
    /** Codec frames data */
    cbuffer_t *frame_cbuffer;
    /** The CSB encoder will call this function to encode a frame*/
    csb_encode_frame_fn_t csb_encode_frame_fn;
    /** Number of samples per channel required by the csb_encode_frame_fn to encode a frame */
    unsigned int samples_in_frame;
    /** The number of samples delay introduced by the csb encoder */
    unsigned int csb_encoder_delay_samples;
    /** The csb encoder will not encode frames whose metadata system_time_source
        does not match the system_time_source defined here. */
    unsigned int system_time_source;
    /** The minimum time before TTP to encode a frame */
    time_t encode_time_min;
    /** Internal State */
    md_list_t audio_encode_md_list[2];
    md_chunk_state_t audio_in_chunk[2];
} csb_encoder_params_t;

/**
 * \brief  Encode frames for broadcast, store in frame_cbuffer/frame_md_list
 *
 * \param params The csb encoder parameters/state
 * \return True if the function encoded a frame, false if a frame
 *         was not encoded (for example because there was no frame, not
 *         enough output space etc).
 */
extern bool csb_encode_frames(csb_encoder_params_t *params);

/**
 * \brief  Set the minimum time before the TTP to encode a frame.
 *
 * \param params The csb encoder parameters/state
 * \param encode_time_min The minimum time before TTP to encode a frame.
 *
 * If the time before the input data's TTP is less than the minimum, the input
 * data will not be encoded for broadcast and will be copied directly to the
 * output md lists.
 */
extern void csb_encoder_set_encode_time_min(csb_encoder_params_t *params,
                                           time_t encode_time_min);

#else /* KCC */
#include <md.h>
#endif /* KCC */

/* Size in words of the celt_encoder_params structure */
#define CSB_ENCODER_PARAMS_STRUC_SIZE  (11 + (MD_LIST_STRUC_SIZE * 2) + (MD_CHUNK_STATE_STRUC_SIZE * 2))
#define CSB_ENCODER_PARAMS_CSB_ENCODER_DELAY_SAMPLES_FIELD 8

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(csb_encoder_params_t, CSB_ENCODER_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* CSB_ENCODER_H */



