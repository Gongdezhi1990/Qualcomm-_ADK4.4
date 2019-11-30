// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CBUFFER_LOG_H
#define CBUFFER_LOG_H

#include <stdint.h>
#include <stddef.h>

/* 8-bit message id */
enum cbuffer_log_msg_id {
    CBUFFER_LOG_MSG_ID_RESERVED = 0,
    CBUFFER_LOG_MSG_ID_TTP_SET_TTP = 1,
    CBUFFER_LOG_MSG_ID_TTP_SET_INITIAL_COUNTDOWN = 2,
    CBUFFER_LOG_MSG_ID_TTP_RUN = 3,
    CBUFFER_LOG_MSG_ID_TTP_CALCULATE = 4,
    CBUFFER_LOG_MSG_ID_TTP_RESYNC = 5,
    CBUFFER_LOG_MSG_ID_AUDIO_OUTPUT_TIMESTAMPED_FRAMES = 6,
    CBUFFER_LOG_MSG_ID_RTP_INPUT_HEADER = 7,

    CBUFFER_LOG_MSG_ID_END_OF_LIBRARY_MSG_IDS = 128,
    // The application may declare msg id following this number
};

/**
 * \brief  Add a message to the log buffer
 *
 * \param msg_id    The message id (8 bits)
 * \param msg       A pointer to the message structure.
 * \param size      The size of the message structure
 *
 * Writes a new message to the $debug.log_cbuffer_struc. If the buffer is full
 * then the message is dropped on the assumption that the external debugger
 * is not active.
 */
extern void cbuffer_log(enum cbuffer_log_msg_id msg_id, const void *msg, size_t size);

#endif /* CBUFFER_LOG_H */
