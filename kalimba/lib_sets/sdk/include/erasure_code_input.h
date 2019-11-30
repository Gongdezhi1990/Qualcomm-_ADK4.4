/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file erasure_code_input.h
    @brief Erasure code input.

    Handles erasure decoding of received CSB packets.
*/

#ifndef EC_INPUT_H
#define EC_INPUT_H

#include <bluetooth.h>
#include <erasure_code_common.h>

#ifdef KCC
#include <kalimba_c_util.h>
#include <core_library_c_stubs.h>
#include <bitreader.h>
#include <stdint.h>
#include <rtime.h>
#include <erasure_code_input_stats.h>

typedef struct ec_input_params
{
    /** The input port number */
    unsigned int input_port;

    /** The stream ID */
    unsigned int stream_id;

    /** Age limit after which received ec buffers will be freed */
    time_t age_limit_us;
} ec_input_params_t;

typedef struct ec_input_buffer
{
    /** Buffer has valid rx data */
    bool valid;

    /** Buffer can be locked during decode */
    bool locked;

    /** Payload length */
    unsigned int payload_length_octets;

    /** EC header */
    unsigned int stream_id;
    unsigned int coding_info;
    unsigned int overflow;

    /** Age of the packet - it is born when the packet is read from the port */
    time_t age_us;

    /** Buffer for storing the EC payload 16 bits per word */
    unsigned int payload[BT_PACKET_2DH5_MAX_DATA_16BIT_WORDS];

} ec_input_buffer_t;

/* Enumerate the states for determining/settting AFH channel map update pending state */
typedef enum __afh_channel_map_update_pending_state
{
    afh_channel_map_change_pending_state_0 = 0,
    afh_channel_map_change_pending_state_1 = 1,
    afh_channel_map_change_pending_state_unknown,
} afh_channel_map_change_pending_state_t;

typedef struct ec_input_state
{
    ec_input_stats_t stats;
    ec_input_buffer_t rx_buffers[EC_K];
    bitreader_t bitreader;
    /** Buffer, data stored 16 bits per word, decoded packets are stored here */
    unsigned int buffer[OCTETS_TO_16BIT_WORDS(2*BT_PACKET_2DH5_MAX_DATA_OCTETS)];
    /** Used to detect changes to afh channel map change pending bit in EC header */
    afh_channel_map_change_pending_state_t afh_channel_map_change_pending_state;
    
} ec_input_state_t;

typedef struct ec_input
{
    /** Parameters (owned by the application) */
    ec_input_params_t params;
    /** State (owned by the EC input) */
    ec_input_state_t state;
} ec_input_t;

/****************************************************************************
  Public Function Definitions
*/

/**
 * \brief  Initialises the Erasure Code input.
 *
 * \param e The ec input object
 */
extern void ec_input_initialise(ec_input_t *e);

/**
 * \brief Decode and return a erasure decoded broadcast packet bitreader.
 *        It is assumed that the caller will complete processing of
 *        the bitreader returned by the first call to this function
 *        prior to calling this function for a second time.
 *
 * \param e The ec input object
 * \return A bitreader or NULL if there is no buffer available.
 */
extern bitreader_t* ec_buffer_rx(ec_input_t *e);

/**
 * \brief Copy packet from MMU port to Erasure Code Buffer
 *        Call from timer interrupt
 *
 * \param e The ec input object
 * \param delta_us The time since the last call
 * \return true if the copy detected an AFH channel map change is pending,
           otherwise false.
 */
extern bool ec_input_copy(ec_input_t *e, time_t delta_us);

/**
 * \brief Reset the ec input stats.
 *
 * \param e The ec input object
 */
extern void ec_input_reset_stats(ec_input_t *e);

/**
 * \brief Set the EC receive interval.
 *
 * \param e The ec input object
 * \param interval_slots The interval in BT slots
 */
extern void ec_input_set_rx_interval(ec_input_t *e, unsigned int interval_slots);

/**
 * \brief Set the stream id to receive.
 *
 * \param e The ec input object
 * \param stream_id The stream id.
 *
 * Packets received that do not match the configured stream id will be discarded.
 */
extern void ec_input_set_stream_id(ec_input_t *e, unsigned int stream_id);

#else /* KCC */

#include <bitreader.h>
#define EC_INPUT_BUFFER_VALID_FIELD 0
#define EC_INPUT_BUFFER_LOCKED_FIELD 1
#define EC_INPUT_BUFFER_PAYLOAD_LENGTH_OCTETS_FIELD 2
#define EC_INPUT_BUFFER_STREAM_ID_FIELD 3
#define EC_INPUT_BUFFER_CODING_INFO_FIELD 4
#define EC_INPUT_BUFFER_OVERFLOW_FIELD 5
#define EC_INPUT_BUFFER_AGE_US_FIELD 6
#define EC_INPUT_BUFFER_PAYLOAD_FIELD 7

#endif /* KCC */

/* Size in words of the ec_input structure */
#define EC_INPUT_STRUC_SIZE (3+EC_2_5_PAIR_COMBINATIONS+1+(2*EC_STREAM_ID_COUNT_TABLE_SIZE)+(2*(BT_PACKET_2DH5_MAX_DATA_16BIT_WORDS+7))+BITREADER_STRUC_SIZE+OCTETS_TO_16BIT_WORDS(2*BT_PACKET_2DH5_MAX_DATA_OCTETS)+1)

#ifdef KCC
STRUC_SIZE_CHECK(ec_input_t, EC_INPUT_STRUC_SIZE);
#endif /* KCC */

#endif /* EC_INPUT_H */
