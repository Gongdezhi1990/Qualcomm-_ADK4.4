/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file csb_output.h
    @brief CSB Output
    
    Generates CSB packets containing SCM and audio frames, these packets
    are then passed to the erasure encoder.    
*/

#ifndef CSB_OUTPUT_H
#define CSB_OUTPUT_H

#ifdef KCC
#include <core_library_c_stubs.h>
#include <md.h>
#include <rtime.h>
#include <erasure_code_output.h>
#include <sr.h>
#include <csb_aesccm.h>
#include <scm.h>

/**
 * @brief CSB output parameters structure.
 */
typedef struct csb_output_params
{
    scmb_params_t *scmb_params;

    /** The minimum time before time-to-play to Tx frame */
    time_t tx_time_min;

    /** Packets arriving before (ttp - tx_time_min - tx_window) will be
        buffered. Packets arriving between (ttp - tx_time_min - tx_window)
        and (ttp - tx_time_min) will be transmitted. Packet arriving after
        (ttp - tx_time_min) will be discarded */
    time_t tx_window;

    /** The meta-data list for input frames */
    md_list_t *frame_md_list;

    /** Internal state */
    md_list_t frame_tx_md_list;

    /** The CSB packet base TTP (24 bits) */
    uint24_t ttp;

    /** The CSB packet extended TTP (16 bits) */
    uint24_t ttp_extension;
    
    /** Current volume */
    unsigned volume;
    
    /** Current sample rate encoded as enum */
    enum srbits srbits;
    
    /** Size (in bits) of audio portion of packet */
    unsigned int csb_packet_audio_size;
    
    /** Time before TTP for current packet */
    int tx_time_before_ttp;
} csb_output_params_t;

/**
 * @brief Initialise CSB output
 */
void csb_output_initialise(csb_output_params_t *params);

/**
 * @brief CSB output background process
 */
bool csb_output_process(csb_output_params_t *c, ec_output_params_t *e, aesccm_params_t *a);

/**
 * @brief Set TX window for CSB transmission
 */
void csb_output_set_tx_window(csb_output_params_t *params, time_t tx_time_min, time_t tx_window);

/**
 * @brief Set the volume field in the CSB packet
 */
void csb_output_set_volume(csb_output_params_t *params, unsigned int volume);

/**
 * @brief Set the TTP extension value in the CSB packet
 */
void csb_output_set_ttp_extension(csb_output_params_t *params, uint24_t ttp_extension);

#else /* KCC */

#include <md.h>

#endif /* KCC */

#define CSB_OUTPUT_PARAMS_STRUC_SIZE (4 + MD_LIST_STRUC_SIZE + 6)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(csb_output_params_t, CSB_OUTPUT_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* CSB_OUTPUT */
