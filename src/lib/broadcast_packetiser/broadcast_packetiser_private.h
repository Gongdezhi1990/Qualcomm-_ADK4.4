/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    broadcast_packetiser_private.h

DESCRIPTION
    Private header file for the Broadcast Packetiser library.

*/

#ifndef BROADCAST_PACKETISER_PRIVATE_H_
#define BROADCAST_PACKETISER_PRIVATE_H_

#include "broadcast_packetiser.h"
#include "broadcast_packet.h"
#include "broadcast_packet_ttp.h"
#include "aesccm.h"

#include <csrtypes.h>
#include <message.h>

#include <erasure_coding.h>
#include <packetiser_helper.h>
#include <rtime.h>
#include <scm_transport.h>

/****************************************************************************
 * Defines
 ****************************************************************************/

/* Control debug generation using hydra log. Using hydra log results in more efficient
   utilisation of the log buffer than printf */
#ifdef BROADCAST_PACKETISER_DEBUG_LIB
#include <hydra_log.h>
#define BP_DEBUG(x)  L2_DBG_MSG(x)
#define BP_DEBUG1(x, A)  L2_DBG_MSG1(x, A)
#define BP_DEBUG2(x, A, B)  L2_DBG_MSG2(x, A, B)
#define BP_DEBUG3(x, A, B, C)  L2_DBG_MSG3(x, A, B, C)
#define BP_DEBUG4(x, A, B, C, D)  L2_DBG_MSG4(x, A, B, C, D)
#define TP_LOG_STRING(label, text) HYDRA_LOG_STRING(label, text)
#else
#define BP_DEBUG(x)
#define BP_DEBUG1(x, A)
#define BP_DEBUG2(x, A, B)
#define BP_DEBUG3(x, A, B, C)
#define BP_DEBUG4(x, A, B, C, D)
#define TP_LOG_STRING(label, text)
#endif

/* The time in ms before a non-audio message will be transmitted */
#define IDLE_TRIGGER_MS (100)

#define BROADCAST_PACKETISER_INTERNAL_MSG_BASE 0
typedef enum __broadcast_packetiser_internal_msg
{
    BROADCAST_PACKETISER_INTERNAL_TX_PACKET_MSG = BROADCAST_PACKETISER_INTERNAL_MSG_BASE,
    BROADCAST_PACKETISER_INTERNAL_STATS_MSG,
    BROADCAST_PACKETISER_INTERNAL_SCM_TRANSPORT_KICK_MSG,
    BROADCAST_PACKETISER_INTERNAL_AESCCM_COMPLETE,
    BROADCAST_PACKETISER_INTERNAL_MSG_TOP
} broadcast_packetiser_internal_msg_t;

/* Enumerate the states used to broadcast / receiver packets */
typedef enum __broadcast_packetiser_state
{
    broadcast_packetiser_state_idle = 0,
    broadcast_packetiser_state_written_header,
    broadcast_packetiser_state_written_audio_frame,
    broadcast_packetiser_state_calculate_mac_a,
    broadcast_packetiser_state_calculate_mac_b,
    broadcast_packetiser_state_encrypt,
    broadcast_packetiser_state_decrypt,
    broadcast_packetiser_state_authenticate,
    broadcast_packetiser_state_transmit,
    broadcast_packetiser_state_read_broadcast_packet,
    broadcast_packetiser_state_sample_rate_change_pending,
    broadcast_packetiser_state_start_of_stream_pending
} broadcast_packetiser_state_t;

struct __broadcast_packetiser
{
    /* Task for this instance of the library */
    TaskData lib_task;

    /* Current state of the packetisation */
    broadcast_packetiser_state_t state;

    /* The wall-clock TTP of the current packet */
    ttp_t ttp;

    /* The local-clock base-TTP of the current packet */
    rtime_t ttp_lc;

    /* Broadcaster role: unused.
       Receiver role: Flags that the current sample rate is unsupported.
       The receiver reads and discards packets */
    bool sample_rate_unsupported;

    /* Broadcaster role: unused.
       Receiver role: flags that the next audio frame written to the sink
       is the start of stream. The flag is asserted on a change of sample
       sample rate. */
    bool start_of_stream;

    /* The number of frames in the packet. */
    uint32 frame_count;

    /* The configuration */
    broadcast_packetiser_config_t config;

    union
    {
        broadcast_packetiser_stats_broadcaster_t tx;
        broadcast_packetiser_stats_receiver_t rx;
    } stats;

    /* Pointer to dynamically allocated instance of the SCM transport used for
       either broadcasting or receiving SCM (not both at the same time). */
    scm_transport_t *scm_transport;

    /* Pointer to dynamically allocated nonce */
    aesccm_nonce_t *aesccm_nonce;

    /* The broadcast packet */
    broadcast_packet_t bpkt;

    ec_unencoded_packet_t *unencoded;
};

/*!
  @brief Handle messages in the broadcaster role.
*/
void messageHandlerBroadcaster(Task task, MessageId id, Message message);

/*!
  @brief Handle messages in the receiver role.
*/
void messageHandlerReceiver(Task task, MessageId id, Message message);

#endif
