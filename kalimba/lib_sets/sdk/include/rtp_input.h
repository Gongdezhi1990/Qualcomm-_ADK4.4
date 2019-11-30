/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file rtp_input.h
    @brief  RTP input handling.

    Handles RTP packets from an A2DP audio stream.
*/

#ifndef _RTP_INPUT_H
#define _RTP_INPUT_H

#ifdef KCC
#include <core_library_c_stubs.h>
#include <stdbool.h>
#include <md.h>
#include <ttp.h>
#include <ttp_buffer.h>

struct rtp_input_params;
typedef bool (*rtp_process_fn_t)(struct rtp_input_params *params, md_t *md_ptr);

typedef struct rtp_input_params
{
    /** The RTP input port/cbuffer to read from. */
    cbuffer_t *input;

    /** The CODEC frame cbuffer to write to. */
    cbuffer_t *frame_cbuffer;

    /** The meta-data list for CODEC frames */
    md_list_t *frame_md_list;

    /** The TTP state structure used to timestamp the meta-data packets */
    struct ttp_state *ttp_state;

    /** The TTP settings used to timestamp the meta-data packets */
    struct ttp_settings *ttp_settings;

    /** Address of variable defining the system time source */
    unsigned *system_time_source;

    /** The function to call to process the frames within the rtp payload */
    rtp_process_fn_t rtp_process_fn;

    // Internal state
    time_t time_of_arrival;
    unsigned scms_bits;
    unsigned scms_enabled:1;
    unsigned stream_start:1;
    uint24_t sbc_frames;
    int codec_octets;

    struct ttp_buffer ttp_buffer;
} rtp_input_params_t;

#else

#include "ttp_buffer.h"

#define RTP_INPUT_PARAMS_INPUT_FIELD 0
#define RTP_INPUT_PARAMS_SYSTEM_TIME_SOURCE_PTR_FIELD 5
#define RTP_INPUT_PARAMS_TIME_OF_ARRIVAL_FIELD 7

#endif

#define RTP_INPUT_PARAMS_STRUC_SIZE   (12 + TTP_BUFFER_STRUC_SIZE)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(rtp_input_params_t, RTP_INPUT_PARAMS_STRUC_SIZE);

/****************************************************************************
  Public Function Definitions
*/

/**
 * \brief  Enables the RTP SCMS_T field.
 *
 * \param params The RTP input parameters/state
 */
extern void rtp_enable_scms(struct rtp_input_params *params);

/**
 * \brief  Disables the RTP SCMS_T field.
 *
 * \param params The RTP input parameters/state
 */
extern void rtp_disable_scms(struct rtp_input_params *params);

/**
 * \brief  Initialises the RTP input.
 *
 * \param params The RTP input parameters/state
 */
extern void rtp_input_initialise(struct rtp_input_params *params);


/**
 * \brief  Process RTP packet.
 *
 * \param params The RTP input parameters/state
 * \return True if the function processed a rtp input frame, false if a frame
 *         was not processed (for example because there was no frame, not
 *         enough output space etc).
 */
extern bool rtp_input_process(struct rtp_input_params *params);

/**
 * \brief  Copy RTP packet from port to input buffer
 *         implemented in assembly
 *
 * \param params The RTP input parameters/state
 */
extern void rtp_input_packet(struct rtp_input_params *params);


/****************************************************************************
  Private Function Definitions
*/

/**
 * \brief  Process SBC frames.
 *
 * \param params    Pointer to RTP packet header information.
 * \param md        The metadata block for the RTP packet.
 *
 * Processes all SBC frames in the current RTP packet.  SBC frames are
 * timestamped with the desired time-to-play, packed and then copied into the
 * CODEC cbuffer.
 */
extern bool rtp_input_process_sbc_frames(struct rtp_input_params *params, md_t *md);

/**
 * \brief  Processes an AAC frame in an RTP packet.
 *
 * \param params    Pointer to RTP packet header information.
 * \param md        The metadata block for the RTP packet.
 *
 * Processes the AAC frame in the current RTP packet. The AAC frame is
 * timestamped with the desired time-to-play, packed and then copied into the
 * CODEC cbuffer.
 */
extern bool rtp_input_process_aac_frames(struct rtp_input_params *params, md_t *md);

#endif /* KCC */

#endif
