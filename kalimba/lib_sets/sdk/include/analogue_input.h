/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/
/*!
   @file analogue_input.h
   @brief Analogue Input.
*/

#ifndef ANALOGUE_INPUT_H
#define ANALOGUE_INPUT_H

#ifdef KCC
#include <core_library_c_stubs.h>
#include <md.h>
#include <stdbool.h>
#include <ttp.h>

/** Analogue input parameters. */
typedef struct analogue_input_params
{
    /** The size (in samples) for a meta-data packet for a single channel */
    int pcm_md_size;
    /** The left port/cbuffer to read from. */
    tCbuffer *left_input;
    /** The right port/cbuffer to read from. */
    tCbuffer *right_input;
    /** The left cbuffer to write to. */
    tCbuffer *left_output;
    /** The right cbuffer to write to. */
    tCbuffer *right_output;
    /** The meta-data list for left_output */
    md_list_t *left_pcm_md_list;
    /** The meta-data list for right_output */
    md_list_t *right_pcm_md_list;
    /** The TTP state structure used to timestamp the meta-data packets */
    struct ttp_state *ttp_state;
    /** The TTP settings used to timestamp the meta-data packets */
    struct ttp_settings *ttp_settings;
    /** Address of variable defining the system time source */
    unsigned *system_time_source;
    /* Internal state initialised by analogue input */
    bool initialised;
    int samples_copied;
    uint24_t *left_read_ptr;   /* Boundary of last meta-data block */
    uint24_t *right_read_ptr;  /* Boundary of last meta-data block */
} analogue_input_params_t;

/**
 * \brief   Reads from the analogue input ports.
 *
 * \param params The analogue input parameters.
 *
 * Reads from the analogue input port. If enough data is available then a PCM
 * meta-data entry is generated.
 */
void analogue_input_copy_and_timestamp_frames(struct analogue_input_params *params);

#endif /* KCC */

/*! Size in words of the analogue_input_params structure */
#define ANALOGUE_INPUT_PARAMS_STRUC_SIZE    14

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(analogue_input_params_t, ANALOGUE_INPUT_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* ANALOGUE_INPUT */
