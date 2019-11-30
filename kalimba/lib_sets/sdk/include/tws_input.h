/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

#ifndef TWS_INPUT_H
#define TWS_INPUT_H

#include <md.h>
#include <bitreader.h>

#define TWS_PACKET_HEADER_SIZE (5)
#define TWS_FRAME_HEADER_SIZE (1)

#ifdef KCC

#include <frame_info.h>
#include <core_library_c_stubs.h>
#include <rtime.h>

typedef struct tws_input_params
{
    unsigned input_port;

    /** The TWS input will write to this metadata list */
    md_list_t *frame_out_md_list;

    /** The TWS input will write codec frames to this cbuffer */
    cbuffer_t *frame_out_cbuffer;

    /** The CSB input will call this function to read the frame info */
    get_frame_info_fn_t get_frame_info_fn;

    /** The CSB input will copy this many octets from its input buffer to the
        frame_header_buffer and call get_frame_info_fn */
    uint24_t frame_header_length_octets;

    /** The CSB input will write the frame header to this buffer packed 8 bits
        per word */
    uint24_t *frame_header_buffer;

    /** Internal state */
    bitreader_t br; 
    volatile unsigned rx_ready;   
    unsigned ttp;

    /** The TWS packet volume */
    uint24_t volume;

    /** The sample rate of the last TWS packet */
    enum srbits sr;

    /** The system's sample rate */
    enum srbits system_sr;
} tws_input_params_t;

void tws_input_initialise(struct tws_input_params *params);
uint24_t tws_input_process(struct tws_input_params *params);
void tws_input_copy(struct tws_input_params *params);

/**
 * \brief  Get the TWS volume defined in the last received packet
 *
 * \param params The TWS input object
 * \return The TWS volume in the range 0 to 31
 */
uint24_t tws_input_get_volume(struct tws_input_params *params);

/**
 * \brief  Set the TWS input system sample rate
 *         Must be called by the application before processing any csb packets
 *
 * \param params The TWS input object
 * \param sr The raw sample rate at which system is configured to operate (e.g.
 *           44100, 48000 etc)
 */
void tws_input_set_sample_rate(struct tws_input_params *params, uint24_t sr);

/**
 * \brief  Get the TWS sample rate defined in the last received packet
 *
 * \param params The TWS input object
 * \return The raw sample rate (e.g. 44100, 48000 etc)
 */
uint24_t tws_input_get_sample_rate(struct tws_input_params *params);


#else /* KCC */

#define TWS_INPUT_PARAMS_INPUT_PORT_FIELD (0)
#define TWS_INPUT_PARAMS_BITREADER_FIELD (6)
#define TWS_INPUT_PARAMS_RX_READY_FIELD (6 + BITREADER_STRUC_SIZE)

#endif /* KCC */

#define TWS_INPUT_PARAMS_STRUC_SIZE (11 + BITREADER_STRUC_SIZE)

#define TWS_INPUT_VOLUME_CHANGED_FLAG      (1 << 0)
#define TWS_INPUT_SAMPLE_RATE_CHANGED_FLAG (1 << 1)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(tws_input_params_t, TWS_INPUT_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* TWS_INPUT_H */
