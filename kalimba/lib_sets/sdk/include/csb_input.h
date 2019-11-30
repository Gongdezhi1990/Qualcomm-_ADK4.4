/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file csb_input.h
    @brief CSB Input
    
    Processes received CSB packets.    
*/

#ifndef CSB_INPUT_H
#define CSB_INPUT_H

#ifdef KCC
#include <frame_info.h>
#include <md.h>
#include <rtime.h>
#include <core_library_c_stubs.h>
#include <erasure_code_input.h>
#include <csb_aesccm.h>
#include <scm.h>

typedef struct csb_input_params
{
    scmr_params_t *scmr_params;

    /** The CSB input will write to this metadata list */
    md_list_t *codec_md_list;
    /** The CSB input will write codec frames to this cbuffer */
    cbuffer_t *codec_cbuffer;
    /** The CSB input will call this function to read the frame info */
    get_frame_info_fn_t get_frame_info_fn;
    /** The CSB input will copy this many octets from its input buffer to the
        frame_header_buffer and call get_frame_info_fn */
    uint24_t frame_header_length_octets;
    /** The CSB input will write the frame header to this buffer packed 8 bits
        per word */
    uint24_t *frame_header_buffer;
    /** Bitfield of sample rates supported by the application. The bitfield
        should be populated from the SR_FREQUENCY_BITFIELD_X defines in sr.h */
    uint24_t supported_sample_rates_bitfield;
} csb_input_params_t;

/** Internal state */
typedef struct csb_input_state
{
    /** The CSB packet volume */
    uint24_t volume;
    /** The sample rate of the last CSB packet */
    enum srbits sr;
    /** The system's sample rate */
    enum srbits system_sr;
    /** Count the number of packets read */
    uint24_t packets_read;
    /** Count the number packets failing the AESCCM MAC */
    uint24_t mac_failures;
    /** The CSB packet base TTP (24 bits) */
    uint24_t ttp;
    /** The CSB packet extended TTP (16 bits) */
    uint24_t ttp_extension;
    /** Count the number of invalid packets received */
    uint24_t invalid_packets;
} csb_input_state_t;

typedef struct csb_input
{
    /** Parameters (owned by the application) */
    csb_input_params_t params;
    /** State (owned by the CSB input) */
    csb_input_state_t state;
} csb_input_t;

/**
 * \brief  Initialise the CSB input
 *
 * \param c The CSB input object
 */
void csb_input_initialise(csb_input_t *c);

/**
 * \brief  Process a CSB packet
 *
 * \param c [IN] The CSB input object
 * \param e [IN] The EC input object
 * \param a [IN] The aesccm parameters
 * \param audio_status [OUT] Volume and sample rate changed flags
 * \return True if the function processed a csb input frame, false if a frame
 *         was not processed (for example because there was no frame).
 */
bool csb_input_process(csb_input_t *c, ec_input_t *e, aesccm_params_t *a, unsigned int *audio_status);

/**
 * \brief  Get the CSB volume defined in the last received packet
 *
 * \return The CSB volume in the range 0 to 31
 */
uint24_t csb_input_get_volume(csb_input_t *c);

/**
 * \brief  Set the CSB input system sample rate
 *         Must be called by the application before processing any csb packets
 *
 * \param c The CSB input object
 * \param sr The raw sample rate at which system is configured to operate (e.g.
 *           44100, 48000 etc)
 */
void csb_input_set_sample_rate(csb_input_t *c, uint24_t sr);

/**
 * \brief  Get the CSB sample rate defined in the last received packet
 *
 * \return The raw sample rate (e.g. 44100, 48000), or 0 if the last received
 *         sample rate was invalid.
 */
uint24_t csb_input_get_sample_rate(csb_input_t *c);

/**
 * \brief  Get the number of CSB packets received
 *
 * \return The number of CSB packets received
 */
uint24_t csb_input_get_packets_received(csb_input_t *c);

/**
 * \brief  Get the number of CSB packets failing the MAC
 *
 * \return The number of CSB packets failing the MAC
 */
uint24_t csb_input_get_mac_failures(csb_input_t *c);

/**
 * \brief  Get the number of invalid CSB packets received.
 *
 * \return The number of invalid CSB packets received.
 * A invalid packet is a packet that:
 *    Does not have a ttp
 *    Does not have a MAC and at least one octet of data following the MAC.
 *    Has framing errors when reading the data from the payload.
 */
uint24_t csb_input_get_invalid_packets(csb_input_t *c);

/**
 * \brief  Reset the count of number of CSB packets received
 */
void csb_input_reset_packets_received(csb_input_t *c);

/**
 * \brief  Reset the count of number of CSB packets failing the MAC
 */
void csb_input_reset_mac_failures(csb_input_t *c);

/**
 * \brief  Reset the count of number of invalid CSB packets received.
 */
void csb_input_reset_invalid_packets(csb_input_t *c);

#else /* KCC */

#endif /* KCC */

#define CSB_INPUT_STRUC_SIZE (7+8)

#define CSB_INPUT_VOLUME_CHANGED_FLAG      (1 << 0)
#define CSB_INPUT_SAMPLE_RATE_CHANGED_FLAG (1 << 1)
#define CSB_INPUT_SAMPLE_RATE_INVALID_FLAG (1 << 2)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(csb_input_t, CSB_INPUT_STRUC_SIZE);
#endif /* KCC */

#endif /* CSB_INPUT_H */
