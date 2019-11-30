/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    broadcast_packetiser_tx.c
*/

#include "broadcast_packetiser_private.h"
#include "broadcast_packet.h"

#include <packetiser_helper.h>
#include <scm_transport.h>
#include <panic.h>
#include <string.h>
#include <stdlib.h>
#include <system_clock.h>
#include <crypto.h>


/* Uncomment to ignore start of stream indications in metadata */
#define DISABLE_START_OF_STREAM

/* The broadcast packetiser needs some extra time to process data before
   passing to EC for transmit */
#define BP_EXTRA_PROCESSING_TIME 10000

/* Time to allow for encrypting & encoding a ba packet when using
   MESSAGE_MORE_DATA to kick it off.
   It is similar in intention to BP_EXTRA_PROCESSING_TIME but testing shows it
   needs to be larger. */
#define BP_EXTRA_ENCODING_TIME 20000


/* Increment the TTP extension when the TTP base wraps */
static void handleTTPWrap(ttp_t *ttp, rtime_t new_ttp_base)
{
    if (new_ttp_base < ttp->base)
    {
        ttp->extension++;
    }
    ttp->base = new_ttp_base;
}

static bool writePacketHeader(broadcast_packetiser_t *bp)
{
    audio_frame_metadata_t fmd;

    /* Read frames from the source until the frame's TTP is ok to transmit.
       Break when a start of stream is detected to allow the client to
       reconfigure the library for the new stream. */
    while (PacketiserHelperAudioFrameMetadataGetFromSource(bp->config.port.source, &fmd))
    {
#ifndef DISABLE_START_OF_STREAM
        if (fmd.start_of_stream)
        {
            /* Send start of stream message to client */
            MESSAGE_MAKE(msg, BROADCAST_PACKETISER_START_OF_STREAM_IND_T);
            msg->broadcast_packetiser = bp;
            MessageSend(bp->config.client_task,
                        BROADCAST_PACKETISER_START_OF_STREAM_IND, msg);
            bp->state = broadcast_packetiser_state_start_of_stream_pending;
            BP_DEBUG("BPTX: Start of Stream - waiting on client");
            break;
        }
#endif

        rtime_t time_before_ttp_to_tx = ErasureCodingTxLatency(bp->config.ec_handle.tx, TRUE);
        int32 delay = RtimeTimeBeforeTx(fmd.ttp, time_before_ttp_to_tx);
        delay = rtime_sub(delay, BP_EXTRA_PROCESSING_TIME);
        BP_DEBUG3("BPTX: wPH DLY:%d, TTP:%u TT:%u", delay, fmd.ttp, time_before_ttp_to_tx);

        if (rtime_gt(delay, 0))
        {
            rtime_t new_ttp;
            uint16 ec_mtu = ErasureCodingTxMTU(bp->config.ec_handle.tx);
            bp->unencoded = ErasureCodingTxAllocatePacket(bp->config.ec_handle.tx, ec_mtu);
            PanicNull(bp->unencoded);

            broadcastPacketInit(&bp->bpkt, bp->unencoded->buffer, ec_mtu);

            new_ttp = ErasureCodingTxTimeLocalToTransport(bp->config.ec_handle.tx, fmd.ttp);
            handleTTPWrap(&bp->ttp, new_ttp);
            bp->ttp_lc = fmd.ttp;

            broadcastPacketWriteNonAudio(&bp->bpkt, &bp->ttp);
            broadcastPacketWriteAudioHeader(&bp->bpkt,
                                            bp->config.scmst,
                                            bp->config.volume,
                                            bp->config.sample_rate);

            /* Cancel existing messages (i.e. the message that triggers tx of a
            non-audio packet if idle for a period of time) */
            MessageCancelAll(&bp->lib_task,
                            BROADCAST_PACKETISER_INTERNAL_TX_PACKET_MSG);

            /* The packet will be transmitted when this message is received,
               if it has not already been sent in response to a
               MESSAGE_MORE_DATA. */
            MessageSendLater(&bp->lib_task,
                            BROADCAST_PACKETISER_INTERNAL_TX_PACKET_MSG,
                            NULL, (uint32)delay / US_PER_MS);

            bp->state = broadcast_packetiser_state_written_header;
            bp->frame_count = 0;
            return TRUE;
        }
        else
        {
            BP_DEBUG("BPTX: wPH **LATE**");
            bp->stats.tx.audio_frames_late++;
            SourceDrop(bp->config.port.source, SourceBoundary(bp->config.port.source));
        }
    }
    return FALSE;
}

static void writePacketAudioFrames(broadcast_packetiser_t *bp)
{
    audio_frame_metadata_t fmd;

    /* Write queued audio frames from source */
    while (PacketiserHelperAudioFrameMetadataGetFromSource(bp->config.port.source, &fmd))
    {
        rtime_spadj_mini_t spadjm;
        uint16 len = SourceBoundary(bp->config.port.source);
        const uint8 *src = SourceMap(bp->config.port.source);

        if (!len || !src || (len != bp->config.frame_length))
        {
            BP_DEBUG2("BPTX: wPAF Panic len/src %u %p", len, src);
            Panic();
        }
        spadjm = RtimeSpadjFullToMini(fmd.sample_period_adjustment);

#ifndef DISABLE_START_OF_STREAM
        /* Don't add frame if start of stream and not first frame in packet */
        if (fmd.start_of_stream &&
            (bp->state != broadcast_packetiser_state_written_header))
            break;
#endif

        /* If the frame cannot be written, leave the frame in the source
           and try writing it to a packet later */
        if (!broadcastPacketWriteAudioFrame(&bp->bpkt, src, len, spadjm))
        {
            break;
        }


        BP_DEBUG4("BPTX: wPAF %u, %u 0x%x, 0x%x", bp->frame_count, len, fmd.sample_period_adjustment, fmd.ttp);

        bp->state = broadcast_packetiser_state_written_audio_frame;
        bp->frame_count++;
        bp->stats.tx.audio_frames_transmitted++;
        
        SourceDrop(bp->config.port.source, len);
    }
}

/* Create a broadcast packet, copying audio frames from the source */
static void processAudioFrames(broadcast_packetiser_t *bp)
{
    if ((bp->state == broadcast_packetiser_state_idle && writePacketHeader(bp)) ||
        bp->state == broadcast_packetiser_state_written_header ||
        bp->state == broadcast_packetiser_state_written_audio_frame)
    {
        writePacketAudioFrames(bp);
    }
}

/* Complete broadcast packet processing.*/
static void completeBroadcastPacketProcessing(broadcast_packetiser_t *bp)
{
    if (bp->aesccm_nonce)
    {
        free(bp->aesccm_nonce);
        bp->aesccm_nonce = NULL;
    }

    /* Setting the state to idle, causes processAudioFrames() to restart 
       processing audio frames. The packet currently being processed
       is now complete. */
    bp->state = broadcast_packetiser_state_idle;

    broadcastPacketInit(&bp->bpkt, NULL, 0);
    PanicNull(bp->unencoded);
    free(bp->unencoded);
    bp->unencoded = NULL;

    /* This message will trigger the transmit of a non-audio packet after the idle period. */
    MessageSendLater(&bp->lib_task,
                     BROADCAST_PACKETISER_INTERNAL_TX_PACKET_MSG,
                     NULL, IDLE_TRIGGER_MS);
}

static void calculateMacA(broadcast_packetiser_t *bp, uint16 len)
{
    BP_DEBUG2("BPTX: AuthMacA %d, %x", len, bp->ttp.base);

    aesccmSetupAuthenticationNonce(&bp->config.aesccm, &bp->ttp, len, bp->aesccm_nonce);
    /* First part of the authentication process is the B_0 vector - from aesccmSetupAuthenticationNonce */
    PanicFalse(CryptoAes128Cbc(TRUE, bp->config.aesccm.key, bp->aesccm_nonce->n, 0,
                               zeros_16, sizeof(zeros_16), NULL, 0));
}

static void calculateMacB(broadcast_packetiser_t *bp)
{
    uint16 len;

    uint8 *addr = broadcastPacketGetAuthenticationAddrLen(&bp->bpkt, &len);
    BP_DEBUG1("BPTX: AuthMacB %d", len);

    /* Second part of the authentication process is to authenticate the received data */
    PanicFalse(CryptoAes128Cbc(TRUE, bp->config.aesccm.key, bp->aesccm_nonce->n, 0,
                               addr, len, NULL, 0));
}

static void encryptPacket(broadcast_packetiser_t *bp)
{
    uint16 len;
    uint8 *addr;

    /* Encrypt, then write the mac that has just been calculated to the packet */
    aesccm_mac_t mac_calc = aesccmNonceToMac(bp->aesccm_nonce);

    aesccmSetupEncryptionNonce(&bp->config.aesccm, &bp->ttp, bp->aesccm_nonce);
    PanicFalse(CryptoAes128Ctr(bp->config.aesccm.key, bp->aesccm_nonce->n, 0, 0,
                               (uint8*)&mac_calc, sizeof(mac_calc),
                               (uint8*)&mac_calc, sizeof(mac_calc)));
    broadcastPacketWriteMAC(&bp->bpkt, mac_calc);

    /* Encrypt the packet in place */
    addr = broadcastPacketGetEncryptionAddrLen(&bp->bpkt, &len);
    BP_DEBUG2("BPTX: Enc %d, %x", len, bp->ttp.base);
    aesccmSetupEncryptionNonce(&bp->config.aesccm, &bp->ttp, bp->aesccm_nonce);
    PanicFalse(CryptoAes128Ctr(bp->config.aesccm.key, bp->aesccm_nonce->n, 0, 1,
                               addr, len, addr, len));
}

static void startErasureCoding(broadcast_packetiser_t *bp)
{
    /* The broadcast packet is now ready for coding and transmission */
    bp->unencoded->task = &bp->lib_task;
    bp->unencoded->timestamp = bp->ttp_lc;
    bp->unencoded->size = broadcastPacketGetLength(&bp->bpkt);
    PanicFalse(ErasureCodingTxPacketReq(bp->config.ec_handle.tx, bp->unencoded));
}

static void processBroadcastPacket(broadcast_packetiser_t *bp)
{
    switch (bp->state)
    {
        case broadcast_packetiser_state_encrypt:
            bp->aesccm_nonce = malloc(sizeof(*bp->aesccm_nonce));
            if (bp->aesccm_nonce)
            {
                uint16 len;
                broadcastPacketGetAuthenticationAddrLen(&bp->bpkt, &len);
                if (len)
                {
                    calculateMacA(bp, len);
                    calculateMacB(bp);
                    encryptPacket(bp);
                    bp->state = broadcast_packetiser_state_transmit;
                    startErasureCoding(bp);
                }
                else
                {
                    BP_DEBUG("BPTX: Nothing to authenticate");
                    completeBroadcastPacketProcessing(bp);
                }
            }
            else
            {
                BP_DEBUG("BPTX: Unable to malloc nonce");
                completeBroadcastPacketProcessing(bp);
            }
            break;

        case broadcast_packetiser_state_transmit:
            /* The broadcast packet is now ready for coding and transmission */
            startErasureCoding(bp);
            break;

        default:
            BP_DEBUG1("BPTX: Unexpected state, %u", bp->state);
            Panic();
            break;
    }

    /* Attempt to create another packet from buffered frames */
    processAudioFrames(bp);
}

void BroadcastPacketiserStartOfStreamResponse(broadcast_packetiser_t *bp)
{
    BP_DEBUG1("BPTX: BroadcastPacketiserStartOfStreamResponse cur_state %u", bp->state);
    if (bp->config.role == broadcast_packetiser_role_broadcaster &&
        bp->state == broadcast_packetiser_state_start_of_stream_pending)
    {
        bp->state = broadcast_packetiser_state_idle;
        processAudioFrames(bp);
    }
    else
    {
        /* Function called in invalid role or invalid state */
        Panic();
    }
}

static void erasureCodingCompleted(Task task, uint16 times_transmitted)
{
    broadcast_packetiser_t *bp =(broadcast_packetiser_t *)task;

    if (times_transmitted)
    {
        bp->stats.tx.broadcast_packets_transmitted++;
        if (bp->scm_transport)
        {
            ScmbTransportSegmentUpdateLifetime(bp->scm_transport, (times_transmitted + 1) / 2);
        }
    }
    completeBroadcastPacketProcessing(bp);
    processAudioFrames(bp);
}

static void startPacketEncoding(Task task)
{
    broadcast_packetiser_t *bp =(broadcast_packetiser_t *)task;

    if (bp->state == broadcast_packetiser_state_idle)
    {
        uint16 ec_mtu = ErasureCodingTxMTU(bp->config.ec_handle.tx);
        bp->unencoded = ErasureCodingTxAllocatePacket(bp->config.ec_handle.tx, ec_mtu);
        PanicNull(bp->unencoded);
        broadcastPacketInit(&bp->bpkt, bp->unencoded->buffer, ec_mtu);

        /* If idle, the message is triggering tx of a non-audio packet.
        Increment the ttp and create a non-audio packet */
        rtime_t new_ttp = rtime_add(bp->ttp.base, 1);
        /* Fiddle ttp_lc for non-audio packet so it is sent once  */
        bp->ttp_lc = rtime_add(SystemClockGetTimerTime(),
                                ErasureCodingTxLatency(bp->config.ec_handle.tx, FALSE));
        handleTTPWrap(&bp->ttp, new_ttp);
        broadcastPacketWriteNonAudio(&bp->bpkt, &bp->ttp);
        if (!broadcastPacketWriteSCM(&bp->bpkt, bp->scm_transport))
        {
            /* If no SCM is written there is no point in sending the
            non-audio parts of the packet alone. Initialise
            the packet, which will result in just an erasure
            packet header being sent. */
            broadcastPacketInit(&bp->bpkt, bp->unencoded->buffer, 0);
        }
    }
    else if (bp->state == broadcast_packetiser_state_written_audio_frame)
    {
        /* Final step before processing the broadcast packet is to fill up
           the packet (if possible) with SCM messages */
        broadcastPacketWriteSCM(&bp->bpkt, bp->scm_transport);
    }
    else
    {
        Panic();
    }

    bp->state = bp->config.aesccm_disabled || !broadcastPacketGetLength(&bp->bpkt) ?
        broadcast_packetiser_state_transmit :
        broadcast_packetiser_state_encrypt;

    processBroadcastPacket(bp);
}

void messageHandlerBroadcaster(Task task, MessageId id, Message message)
{
    broadcast_packetiser_t *bp =(broadcast_packetiser_t *)task;
    UNUSED(message);
    BP_DEBUG1("BPTX: messageHandlerBroadcaster id 0x%x", id);
	
    switch (id)
    {
        /* More data available from the source */
        case MESSAGE_MORE_DATA:
            processAudioFrames(bp);

            if (bp->state == broadcast_packetiser_state_written_audio_frame)
            {
                rtime_t time_before_ttp_to_tx = ErasureCodingTxLatency(bp->config.ec_handle.tx, TRUE);
                int32 ttotx = RtimeTimeBeforeTx(bp->ttp_lc, time_before_ttp_to_tx);
                if ((bp->frame_count >= broadcastPacketCalcMaxFrames(&bp->bpkt, bp->config.frame_length))
                    || rtime_lt(ttotx, BP_EXTRA_ENCODING_TIME))
                {
                    /* Cancel existing messages (i.e. the message that triggers tx of a
                    non-audio packet if idle for a period of time) */
                    MessageCancelAll(&bp->lib_task,
                                    BROADCAST_PACKETISER_INTERNAL_TX_PACKET_MSG);

                    startPacketEncoding(task);
                }
            }
            break;

        case MESSAGE_SOURCE_EMPTY:
            break;

        case ERASURE_CODING_TX_PACKET_CFM:
        {
            ERASURE_CODING_TX_PACKET_CFM_T *cfm = (ERASURE_CODING_TX_PACKET_CFM_T*)message;
            erasureCodingCompleted(task, cfm->times_transmitted);
        }
        break;

        /* Time to transmit a packet */
        case BROADCAST_PACKETISER_INTERNAL_TX_PACKET_MSG:
            if (bp->state == broadcast_packetiser_state_idle
                || bp->state == broadcast_packetiser_state_written_audio_frame)
            {
                processAudioFrames(bp);
                startPacketEncoding(task);
            }
            break;

        case BROADCAST_PACKETISER_INTERNAL_AESCCM_COMPLETE:
            processBroadcastPacket(bp);
            break;

        case BROADCAST_PACKETISER_INTERNAL_STATS_MSG:
        {
            MESSAGE_MAKE(msg, BROADCAST_PACKETISER_STATS_BROADCASTER_IND_T);
            msg->broadcast_packetiser = bp;
            msg->stats = bp->stats.tx;
            MessageSend(bp->config.client_task, BROADCAST_PACKETISER_STATS_BROADCASTER_IND, msg);
            MessageSendLater(&bp->lib_task, BROADCAST_PACKETISER_INTERNAL_STATS_MSG,
                             NULL, bp->config.stats_interval / US_PER_MS);
            memset(&bp->stats, 0, sizeof(bp->stats));
            break;
        }

        case SCM_BROADCAST_TRANSPORT_REGISTER_REQ:
        {
            SCM_BROADCAST_TRANSPORT_REGISTER_REQ_T *msg;
            msg = (SCM_BROADCAST_TRANSPORT_REGISTER_REQ_T *)message;
            if (msg->scm)
            {
                bp->scm_transport = ScmbTransportInit(msg->scm);
                ScmBroadcastTransportRegisterCfm(msg->scm, &bp->lib_task);
            }
            break;
        }

        case SCM_BROADCAST_TRANSPORT_UNREGISTER_REQ:
        {
            SCM_BROADCAST_TRANSPORT_UNREGISTER_REQ_T *msg;
            msg = (SCM_BROADCAST_TRANSPORT_UNREGISTER_REQ_T *) message;
            if (msg->scm)
            {
                ScmbTransportShutdown(bp->scm_transport);
                bp->scm_transport = NULL;
                ScmBroadcastTransportUnRegisterCfm(msg->scm);
            }
            break;
        }

        /* Message from SCM library requesting segment transmit */
        case SCM_BROADCAST_SEGMENT_REQ:
        {
            SCM_BROADCAST_SEGMENT_REQ_T *msg = (SCM_BROADCAST_SEGMENT_REQ_T*)message;
            if (bp->scm_transport)
            {
                ScmbTransportSegmentQueue(bp->scm_transport, msg->header,
                                          msg->data, msg->num_transmissions);
            }
            break;
        }

        default:
            BP_DEBUG1("BPTX: Unhandled message, %u", id);
            Panic();
            break;
    }
}
