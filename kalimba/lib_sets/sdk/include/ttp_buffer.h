/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file ttp_buffer.h
    @brief  Time-to-play buffer

    Provides initial buffering of an audio stream to compensate for high
    levels of jitter when the stream is started. Once the initial countdown
    has been reached the TTP in the buffered metadata is recalculated and the
    metadata is passed to the next list in the chain. Afterwards, metadata is
    passed immediately to the next block in the chain with no buffering.
*/

#ifndef TTP_BUFFER_H
#define TTP_BUFFER_H


#ifdef KCC
/****************************************************************************
  Include Files
*/
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <md.h>
#include "ttp.h"

/****************************************************************************
  Public Type Declarations
*/
typedef struct ttp_buffer
{
    /* The TTP generator containing the initial countdown */
    struct ttp_state* ttp_state;

    /* Buffer's metadata until initial countdown is reached */
    md_list_t internal;

    /* The next audio block in the chain */
    md_list_t *next;
} ttp_buffer_t;
#else

#include <md.h>

#endif

#define TTP_BUFFER_STRUC_SIZE   (1 + MD_LIST_STRUC_SIZE + 1)

#ifdef KCC
/****************************************************************************
  Public Function Definitions
*/

/**
 * \brief   Initialises the TTP buffer state.
 *
 * \param   buf       Pointer to the TTP buffer to destroy.
 * \param   ttp_state The TTP state to track.
 * \param   next      The next metadata queue in the audio chain.
 */
void ttp_buffer_init(struct ttp_buffer *buf, struct ttp_state *ttp_state,
        md_list_t *next);
/**
 * \brief   Enqueues a new metadata item.
 *
 * \param   buffer The buffer to add the meta-data to.
 * \param   md  The metadata to buffer.
 */
void ttp_buffer_enque(struct ttp_buffer *buffer, md_t *md);

/**
 * \brief   Tests if the TTP initial countdown timer has just expired. If
 *          so the TTP of all of the buffered metadata is adjusted and passed
 *          to the next block the chain.
 *
 * \param   buffer Pointer to the TTP buffer.
 */
void ttp_buffer_recalculate(struct ttp_buffer *buffer);

/**
 * \brief   Releases any resources owned by the TTP buffer.
 *          Any buffered metadata is freed.
 *          TODO: Do we need a flush function as well to flush
 *          enqueued meta-data before the initial countdown has
 *          expired ?
 *
 * \param   buf Pointer to the TTP buffer to destroy.
 */
void ttp_buffer_destroy(struct ttp_buffer *buf);

#endif /* KCC */
#endif /* TTP_BUFFER_H */
