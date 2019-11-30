/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file scm.h
    @brief Sub-channel Messaging (SCM).

    Handles transmitting and receiving SCM segements.  Fragmentation and
    re-assembly is handled by VM SCM library.
*/

#ifndef SCM_H
#define SCM_H

#include <bitwriter.h>

/* Number of concurrent segments allowed */
#define SCM_NUM_SEGMENTS   (8)  

#ifdef KCC

#include <stdint.h>
#include <stdbool.h>
#include <core_library_c_stubs.h>
#include <rtime.h>
#include <bitreader.h>

#define SCM_SEGMENT_VALID (0x10000)

/** Size of SCM segment in octets */ 
#define SCM_SEGMENT_SIZE_OCTETS (1 + 1 + 3)

/** Size of SCM segment in bits */ 
#define SCM_SEGMENT_SIZE_BITS (SCM_SEGMENT_SIZE_OCTETS * BITS_PER_OCTET)

/** @defgroup SCM broadcast segment states
 *
 * @{
 */
/** Segment is waiting for transmission */
#define SCMB_STATE_WAITING (0)
/** Segment is being transmitted */
#define SCMB_STATE_IN_PROGRESS (1)
/** @} */

typedef struct scm_segment
{
    uint24_t header;            /*! Segment header, only botton 8 bits copied */
    uint24_t payload;           /*! 24 bits of segment payload */
    unsigned tx_remaining:14;   /*! Number of transmission remaining for this segment  (Broadcaster only) */
    unsigned tx_state:2;        /*! Transmission state (Broadcaster only) */
    time_t time_received;       /*! Last time this segment was received (Receiver only) */
} scm_segment_t;

/** 
* \brief SCM broadcaster parameters structure
* 
* Application must set callback fields, remaining fields should be set to 0.
*/
typedef struct scmb_params
{
    /** Application callback that's called when a segment has been transmitted.
        tx_remaining will be non-zero if the DSP is shutting down. */
    void (*segment_cfm)(unsigned header, unsigned tx_remaining);
    
    scm_segment_t segment[SCM_NUM_SEGMENTS];
    unsigned segment_index;
} scmb_params_t;

/**
 * \brief  Initialise SCM broadcaster
 *
 * \param params Pointer to SCM broadcaster parameters structure.
 */
extern void scmb_initialise(scmb_params_t *params);

/**
 * \brief  Shutdown SCM broadcaster
 *
 * \param params Pointer to SCM broadcaster parameters structure.
 *
 * Releases any resources owned by SCM broadcaster.
 */
extern void scmb_shutdown(scmb_params_t *params);

/**
 * \brief  Write SCM segment(s) to bitwriter
 *
 * \param params    Pointer to SCM broadcaster parameters structure.
 * \param bwr       Pointer to bitwriter objects to store SCM segment(s).
 * \param size_bits Number of bits available for SCM segments.
 *
 * Writes any segments waiting to be broadcast up to size_bits number of bits. 
 */
extern void scmb_segment_write(scmb_params_t *params, bitwriter_t *bwr, unsigned size_bits);

/**
 * \brief  Update broadcast lifetime of segments
 *
 * \param params    Pointer to SCM broadcaster parameters structure.
 * \param num_tx    Number of transmissions that the segments(s) have been transmitted for.
 *
 * Updates the broadcast lifetime of the segments previously written to the bitwriters using
 * scmb_segment_write.  Once the lifetime reaches 0 the segment will be freed and the application
 * informed via a callback.
 */
extern void scmb_segment_update_lifetime(scmb_params_t *params, unsigned num_tx);

/**
 * \brief  Queue segment for broadcast
 *
 * \param params    Pointer to SCM broadcaster parameters structure.
 * \param header    SCM segment header (LS 8 bits only).
 * \param payload   SCM segment payload (all 24 bits).
 * \param tx_count  Number of transmissions required for this segment.
 */
extern unsigned scmb_segment_queue(scmb_params_t *params, unsigned header, uint24_t payload, unsigned tx_count);

/** 
* \brief SCM receiver parameters structure
* 
* Application must set callback fields, remaining fields should be set to 0.
*/
typedef struct scmr_params
{
    /** Application callback that's called when a new segment is recevied */
    void (*segment_ind)(unsigned header, unsigned payload);

    /** Application callback that's called when an old segment has expired */
    void (*segment_expired)(unsigned header);
        
    scm_segment_t segment[SCM_NUM_SEGMENTS];
    unsigned segment_index;
} scmr_params_t;

/**
 * \brief  Initialise SCM receiver
 *
 * \param params Pointer to SCM receiver parameters structure.
 */
extern void scmr_initialise(scmr_params_t *params);

/**
 * \brief  Shutdown SCM receiver
 *
 * \param params Pointer to SCM receiver parameters structure.
 *
 * Releases any resources owned by SCM receiver.
 */
extern void scmr_shutdown(scmr_params_t *params);

/**
 * \brief  Check for any stale segments
 *
 * \param params Pointer to SCM receiver parameters structure.
 *
 * Scans through list of recevied segments and free any that are considered stale
 * (not recevied with last second).  Application callback is called to inform
 * application the segment has expired.
 */
extern void scmr_segment_check(scmr_params_t *params);

/**
 * \brief  Read SCM segment from bitreader
 *
 * \param params Pointer to SCM receiver parameters structure.
 * \param brd Pointer to bitreader object containing SCM segment
 *
 * Reads SCM segment from bitreader and stores it in list of received segments if
 * it hasn't been received before. Once list hits it's maximum size the oldest
 * segment is removed and the application informed that the segment has expired.
 * Application is also informed of the new segment.
 */
extern void scmr_segment_read(scmr_params_t *params, bitreader_t *brd);

#endif /* KCC */

#define SCM_SEGMENT_STRUCT_SIZE (4)
#define SCMB_PARAMS_STRUC_SIZE (SCM_SEGMENT_STRUCT_SIZE * SCM_NUM_SEGMENTS + 2)
#define SCMR_PARAMS_STRUC_SIZE (SCM_SEGMENT_STRUCT_SIZE * SCM_NUM_SEGMENTS + 3)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(scmb_params_t, SCMB_PARAMS_STRUC_SIZE);
STRUC_SIZE_CHECK(scmr_params_t, SCMR_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif // SCM_H
