/****************************************************************************
Copyright (c) 2004 - 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    broadcast_packetiser.c
*/

#include "broadcast_packetiser_private.h"

#include <stdlib.h>
#include <panic.h>
#include <string.h>
#include <stream.h>
#include <message.h>

static Source bpSetSource(broadcast_packetiser_t *bp, Source new)
{
    Source old = bp->config.port.source;

    /* Removing valid source? */
    if (NULL != old) /* TODO: use SourceIsValid() once B-231645 is fixed */
    {
        BP_DEBUG1("BP: Removing old source: %x", old);
        MessageStreamTaskFromSource(old, NULL);
    }

    /* Adding or changing source? */
    if (NULL != new) /* TODO: use SourceIsValid() once B-231645 is fixed */
    {
        BP_DEBUG1("BP: Adding new source: %x", new);
        MessageStreamTaskFromSource(new, &bp->lib_task);
        SourceConfigure(new, VM_SOURCE_MESSAGES, VM_MESSAGES_ALL);
    }
    bp->config.port.source = new;

    return old;
}

static Sink bpSetSink(broadcast_packetiser_t *bp, Sink new)
{
    Sink old = bp->config.port.sink;

    /* Removing valid sink? */
    if (NULL != old) /* TODO: use SinkIsValid() once B-231645 is fixed */
    {
        BP_DEBUG1("BP: Removing old sink: %x", old);
        MessageStreamTaskFromSink(old, NULL);
    }

    /* Adding or changing sink? */
    if (NULL != new) /* TODO: use SinkIsValid() once B-231645 is fixed */
    {
        BP_DEBUG1("BP: Adding new sink: %x", new);
        MessageStreamTaskFromSink(new, &bp->lib_task);
        SinkConfigure(new, VM_SINK_MESSAGES, VM_MESSAGES_ALL);
    }
    bp->config.port.sink = new;

    return old;
}

void BroadcastPacketiserInit(broadcast_packetiser_config_t *config)
{
    broadcast_packetiser_t *bp = NULL;
    MESSAGE_MAKE(msg, BROADCAST_PACKETISER_INIT_CFM_T);

    /* Create a new instance of the library */
    bp = PanicNull(calloc(1, sizeof(*bp)));

    bp->config = *config;
    bp->config.port.sink = NULL;
    bp->config.port.source = NULL;

    switch (bp->config.role)
    {
        case broadcast_packetiser_role_broadcaster:
            bp->lib_task.handler = messageHandlerBroadcaster;
            bpSetSource(bp, config->port.source);

            /* This message will trigger the transmit of a non-audio packet
               after the idle period. */
            MessageSendLater(&bp->lib_task,
                             BROADCAST_PACKETISER_INTERNAL_TX_PACKET_MSG,
                             NULL, IDLE_TRIGGER_MS);
            break;

        case broadcast_packetiser_role_receiver:
            bp->lib_task.handler = messageHandlerReceiver;
            bp->start_of_stream = TRUE;
            bpSetSink(bp, config->port.sink);
            ErasureCodingRxSetPacketClient(bp->config.ec_handle.rx, &bp->lib_task);
            break;

        default:
            /* Invalid role defined */
            Panic();
            break;
    }

    aesccmInit(&bp->config.aesccm);    

    /* set the initial TTP extension */
    bp->ttp.extension = config->ttp_extension;

    if (bp->config.stats_interval)
    {
        MessageSendLater(&bp->lib_task, BROADCAST_PACKETISER_INTERNAL_STATS_MSG,
                         NULL, bp->config.stats_interval / US_PER_MS);
    }

    msg->initialisation_success = TRUE;
    msg->broadcast_packetiser = bp;
    msg->lib_task = &bp->lib_task;
    msg->config = bp->config;
    MessageSend(bp->config.client_task, BROADCAST_PACKETISER_INIT_CFM, msg);
}

void BroadcastPacketiserDestroy(broadcast_packetiser_t *bp)
{
    MessageId msgid;

    bpSetSink(bp, NULL);
    bpSetSource(bp, NULL);

    if (bp->config.role == broadcast_packetiser_role_receiver)
    {
        ErasureCodingRxSetPacketClient(bp->config.ec_handle.rx, NULL);
    }

    /* Flush / cancel all messages */
    MessageFlushTask(&bp->lib_task);
    for (msgid = BROADCAST_PACKETISER_MESSAGE_BASE;
         msgid < BROADCAST_PACKETISER_MESSAGE_TOP;
         msgid++)
    {
        MessageCancelAll(bp->config.client_task, msgid);
    }

    if (bp->aesccm_nonce)
    {
        free(bp->aesccm_nonce);
        bp->aesccm_nonce = NULL;
    }
    if (bp->unencoded)
    {
        free(bp->unencoded);
        bp->unencoded = NULL;
    }

    if (bp->scm_transport)
    {
        /* The SCM transport should not exist when the packetiser is destroyed.
           The SCM transport should first be destroyed by disabling the SCM
           that is using the SCM transport. */
        Panic();
    }

    free(bp);
}

void BroadcastPacketiserSetAesccmDynamicIv(broadcast_packetiser_t *bp,
                                           uint16 iv)
{
    bp->config.aesccm.dynamic_iv = iv;
}

void BroadcastPacketiserSetVolume(broadcast_packetiser_t *bp, uint16 volume)
{
    bp->config.volume = volume;
}

void BroadcastPacketiserSetStatsInterval(broadcast_packetiser_t *bp,
                                         rtime_t interval)
{
    bp->config.stats_interval = interval;
    MessageCancelAll(&bp->lib_task, BROADCAST_PACKETISER_INTERNAL_STATS_MSG);
    if (bp->config.stats_interval)
    {
        MessageSendLater(&bp->lib_task, BROADCAST_PACKETISER_INTERNAL_STATS_MSG,
                         NULL, interval / US_PER_MS);
    }
}

void BroadcastPacketiserSetSampleRate(broadcast_packetiser_t *bp,
                                      rtime_sample_rate_t sample_rate)
{
    if (bp->config.role == broadcast_packetiser_role_broadcaster &&
        (bp->config.port.source == NULL ||
         bp->state == broadcast_packetiser_state_start_of_stream_pending))
    {
        bp->config.sample_rate = sample_rate;
    }
    else
    {
        /* Called in invalid role or state */
        Panic();
    }
}

Source BroadcastPacketiserSetSource(broadcast_packetiser_t *bp, Source new)
{
    if (bp->config.role == broadcast_packetiser_role_broadcaster)
    {
        return bpSetSource(bp, new);
    }

    /* The Source can only be set in the broadcaster role */
    Panic();
    return NULL;
}

Sink BroadcastPacketiserSetSink(broadcast_packetiser_t *bp, Sink new)
{
    if (bp->config.role == broadcast_packetiser_role_receiver)
    {
        return bpSetSink(bp, new);
    }

    /* The Sink can only be set in the receiver role */
    Panic();
    return NULL;
}

/*! @brief Get the current TTP extension value. */
uint8 BroadcastPacketiserGetTtpExtension(broadcast_packetiser_t *bp)
{
    if (bp->config.role == broadcast_packetiser_role_broadcaster)
    {
        return bp->ttp.extension;
    }

    return 0;
}

/*!  @brief Set new frame length and frame samples codec parameters. */
void BroadcastPacketiserSetCodecParameters(broadcast_packetiser_t *bp,
                                           uint16 frame_length,
                                           uint16 frame_samples)
{
    if (bp->config.role == broadcast_packetiser_role_receiver ||
        (bp->config.role == broadcast_packetiser_role_broadcaster && bp->config.port.source == NULL))
    {
        bp->config.frame_length = frame_length;
        bp->config.frame_samples = frame_samples;
    }
    else
    {
        /* Called in invalid role or state */
        Panic();
    }
}
