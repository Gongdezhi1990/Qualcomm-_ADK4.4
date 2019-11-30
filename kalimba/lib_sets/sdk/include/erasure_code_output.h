/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file erasure_code_output.h
    @brief Erasure code output.

    Handles erasure coding of CSB packets to be transmitted.
*/

#ifndef EC_OUTPUT_H
#define EC_OUTPUT_H

#include <bluetooth.h>
#include <erasure_code_common.h>

#ifdef KCC
#include <system_time.h>
#include <kalimba_c_util.h>
#include <rtime.h>
#include <bitwriter.h>

typedef struct ec_output_buffer
{
    /** Lifetime of the buffer in tx intervals */
    unsigned int lifetime_intervals;

    /** State of buffer (free, allocated, erasure code step) */
    volatile unsigned int state;

    /** bitwriter */
    bitwriter_t bitwriter;

    /** The number of octets padding that were added in order to perform EC */
    unsigned int padding_octets;

    /** Buffer for storing the EC payload 16 bits per word */
    union 
    {
        unsigned int payload[BITS_TO_16BIT_WORDS(EC_BUFFER_PAYLOAD_SIZE_BITS)];
        unsigned int payload_short[BITS_TO_16BIT_WORDS(EC_BUFFER_PAYLOAD_SHORT_SIZE_BITS)];
    } u;
} ec_output_buffer_t;

typedef struct ec_output_params
{
    /** The output port number */
    unsigned int output_port;

    /** The stream ID */
    unsigned int stream_id;

    /** The interval (in us) the ec output should write packets to the port */
    time_t interval_us;

    // Internal state
    /** Used to count time between copies to the port */
    time_t interval_counter_us;

    unsigned int sequence_number;
    bool afh_channel_map_change_pending_state;

    bitwriter_t bwr_a;
    bitwriter_t bwr_b;
    ec_output_buffer_t ec_buffer;

} ec_output_params_t;

#define EC_BUFFER_SHORT  (0)
#define EC_BUFFER_NORMAL (1)

/****************************************************************************
  Public Function Definitions
*/

/**
 * \brief  Initialises the Erasure Code output.
 *
 * \param params The parameter block to use for this Erasure Code output.
 */
extern void ec_output_initialise(ec_output_params_t *params);

/**
 * \brief  Allocate an Erasure Code Buffer.
 *
 * \param params The parameter block to use for this Erasure Code output.
 * \param type The type of buffer to allocate - EC_BUFFER_SHORT or
               EC_BUFFER_NORMAL.
 * \return Pointer to an Erasure Code Buffer.
 */
extern bitwriter_t *ec_buffer_alloc(ec_output_params_t *params, unsigned type);

/**
 * \brief  Free an Erasure Code Buffer.
 *
 * \param params The parameter block to use for this Erasure Code output.
 * \param bwr Pointer to the bitwriter from the buffer to free.
 *
 * Normally, one allocates a buffer and transmits the buffer. This function
 * may be used to free an allocated buffer, if one allocates a buffer, but
 * chooses not to transmit the buffer for some reason, for example,
 * because of insufficient resources.
 */
extern void ec_buffer_free(ec_output_params_t *params, bitwriter_t *bwr);

/**
 * \brief Prepare buffer for transmission
 *
 * \param params The parameter block to use for this Erasure Code output.
 * \param bwr Pointer to bitwriter containing the CSB packet to transmit.
 * \param buffer_lifetime_us The buffer will be transmitted for this time
 *                           or until EC_N EC packets have been transmitted.
 *                           A value of 0 means the buffer will only be
 *                           transmitted once with no erasure coding.
 * \return Number of transmission of this buffer
 */
extern unsigned ec_buffer_tx(ec_output_params_t *params, bitwriter_t *bwr,
                             time_t buffer_lifetime_us);

/**
 * \brief  Copy ec packet to port.
 *         Called by the application in the timer interrupt.
 *
 * \param params The parameter block to use for this Erasure Code output.
 * \param delta_us The time since the last call
 */
extern void ec_output_copy(ec_output_params_t *params, time_t delta_us);

/**
 * \brief  Set the EC transmit interval.
 *
 * \param e The ec parameters.
 * \param interval_slots The interval in BT slots.
 */
extern void ec_output_set_tx_interval(ec_output_params_t *e, unsigned int interval_slots);

/**
 * \brief  Set the EC stream id.
 *
 * \param e The ec parameters.
 * \param stream_id The stream id (least significant 8 bits are transmitted
 *                  in the EC packet). Note that the stream_id should not be
 *                  set to EC_STREAM_ID_INVALID.
 */
extern void ec_output_set_stream_id(ec_output_params_t *e, unsigned int stream_id);

/**
 * \brief  Inform the EC output that a afh channel map change is pending
 *
 * \param e The ec parameters.
 */
extern void ec_output_afh_channel_map_change_is_pending(ec_output_params_t *e);

#else /* KCC */

#endif /* KCC */

/* Size in words of the ec_output_params structure */
#define EC_OUTPUT_PARAMS_STRUC_SIZE (6 + BITWRITER_STRUC_SIZE + BITWRITER_STRUC_SIZE + 2 + BITWRITER_STRUC_SIZE + 1 + BITS_TO_16BIT_WORDS(EC_BUFFER_PAYLOAD_SIZE_BITS))

#ifdef KCC
STRUC_SIZE_CHECK(ec_output_params_t, EC_OUTPUT_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* EC_OUTPUT */
