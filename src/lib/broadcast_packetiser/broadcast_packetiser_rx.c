/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    broadcast_packetiser_rx.c
*/

#include "broadcast_packetiser_private.h"
#include "broadcast_packet.h"

#include <packetiser_helper.h>
#include <panic.h>
#include <string.h>
#include <stdlib.h>
#include <source.h>
#include <stream.h>
#include <vmtypes.h>
#include <system_clock.h>
#include <crypto.h>

static uint8 *getDest(broadcast_packetiser_t *bp)
{
    uint8 *dest = SinkMap(bp->config.port.sink);
    if (dest)
    {
        uint16 offset = SinkClaim(bp->config.port.sink, bp->config.frame_length);
        if (offset != 0xFFFF)
            return dest + offset;
    }
    return NULL;
}

/* Read all the audio frames in the packet */
static void readBroadcastPacketFrames(broadcast_packetiser_t *bp)
{
    uint32 frame_count;
    audio_frame_metadata_t fmd;
    fmd.ttp = ErasureCodingRxTimeTransortToLocal(bp->config.ec_handle.rx, bp->ttp.base);
    bp->ttp_lc = fmd.ttp;
    fmd.start_of_stream = bp->start_of_stream;
    bp->start_of_stream = FALSE;

    for (frame_count = 0; frame_count < bp->frame_count; frame_count++)
    {
        rtime_spadj_mini_t spadjm;
        rtime_t frame_time;

        /* Read, calculate and set the frame metadata spadj */
        spadjm = broadcastPacketReadAudioFrameHeader(&bp->bpkt, frame_count,
                                                     bp->config.frame_length);
        fmd.sample_period_adjustment = RtimeSpadjMiniToFull(spadjm);

        int32 time_before_ttp = RtimeTimeBeforeTTP(fmd.ttp);
        BP_DEBUG2("BPRX: Audio frame %d, time before TTP: %d", frame_count, time_before_ttp);
        if (rtime_gt(time_before_ttp, 0))
        {
            uint8 fmdbin[AUDIO_FRAME_METADATA_LENGTH];
            uint8 *dest = getDest(bp);
            if (!dest)
            {
                /* Log any dropped frames as no space in sink or sink invalid */
                bp->stats.rx.audio_frames_no_space += (bp->frame_count - frame_count);
                break;
            }

            broadcastPacketReadAudioFrame(&bp->bpkt, dest,
                                          frame_count, bp->config.frame_length);

            /* Convert fmd structure to bytes */
            PacketiserHelperAudioFrameMetadataSet(&fmd, fmdbin);

            /* Write header and frame to the sink */
            PanicFalse(SinkFlushHeader(bp->config.port.sink, bp->config.frame_length,
                                       fmdbin, sizeof(fmdbin)));
            bp->stats.rx.audio_frames_received++;
        }
        else
        {
            /* Drop frame - too late, but keep iterating through the frames,
               later frames may not be late. */
            bp->stats.rx.audio_frames_late++;
            BP_DEBUG2("BPRX: LATE drop TTP:%u TT:%u", fmd.ttp, SystemClockGetTimerTime());
        }

        /* Update the TTP */
        frame_time = RtimeSamplesToTime(bp->config.frame_samples,
                                        bp->config.sample_rate,
                                        fmd.sample_period_adjustment);
        fmd.ttp = rtime_add(fmd.ttp, frame_time);
    }
}

static bool handleVolumeChange(broadcast_packetiser_t *bp, uint32 volume)
{
    if (volume != bp->config.volume)
    {
        /* Send volume change message to client */
        MESSAGE_MAKE(msg, BROADCAST_PACKETISER_VOLUME_CHANGE_IND_T);
        msg->broadcast_packetiser = bp;
        msg->volume = volume;
        MessageSend(bp->config.client_task, BROADCAST_PACKETISER_VOLUME_CHANGE_IND, msg);
        bp->config.volume = volume;
        return TRUE;
    }
    return FALSE;
}

static bool handleScmstChange(broadcast_packetiser_t *bp, packetiser_helper_scmst_t scmst)
{
    if (scmst != bp->config.scmst)
    {
        /* Send scmst change message to client */
        MESSAGE_MAKE(msg, BROADCAST_PACKETISER_SCMST_CHANGE_IND_T);
        msg->broadcast_packetiser = bp;
        msg->scmst = scmst;
        MessageSend(bp->config.client_task, BROADCAST_PACKETISER_SCMST_CHANGE_IND, msg);
        bp->config.scmst = scmst;
        return TRUE;
    }
    return FALSE;
}

static bool handleSampleRateChange(broadcast_packetiser_t *bp, rtime_sample_rate_t sample_rate)
{
    if (sample_rate != bp->config.sample_rate)
    {
        /* Send sample_rate change message to client */
        MESSAGE_MAKE(msg, BROADCAST_PACKETISER_SAMPLE_RATE_CHANGE_IND_T);
        msg->broadcast_packetiser = bp;
        msg->sample_rate = sample_rate;
        MessageSend(bp->config.client_task, BROADCAST_PACKETISER_SAMPLE_RATE_CHANGE_IND, msg);
        BP_DEBUG2("BPRX: SR Changed %d, %d", sample_rate, bp->config.sample_rate);
        bp->config.sample_rate = sample_rate;
        return TRUE;
    }
    return FALSE;
}

static bool ttpIsDuplicate(broadcast_packetiser_t *bp, ttp_t *ttp)
{
    return ((bp->ttp.base == ttp->base) && (bp->ttp.extension == ttp->extension));
}

static broadcast_packetiser_state_t readBroadcastPacket(broadcast_packetiser_t *bp)
{
    ttp_t ttp;
    uint32 volume = bp->config.volume;
    packetiser_helper_scmst_t scmst = bp->config.scmst;
    rtime_sample_rate_t sample_rate = bp->config.sample_rate;

    if (!broadcastPacketReadNonAudio(&bp->bpkt, bp->scm_transport, &ttp))
    {
        /* Drop packet - framing error */
        bp->stats.rx.broadcast_packet_invalid++;
    }
    else if (ttpIsDuplicate(bp, &ttp))
    {
        /* Drop packet - duplicate */
        bp->stats.rx.broadcast_packet_duplicate_ttp++;
    }
    else if (!broadcastPacketReadAudioHeader(&bp->bpkt, bp->config.frame_length,
                                             &bp->frame_count, &scmst,
                                             &volume, &sample_rate))
    {
        if (bp->frame_count == FRAME_COUNT_FRAMING_ERROR)
        {
            bp->stats.rx.broadcast_packet_invalid++;
        }

        /* check in case the framing error is due to the sample rate changing
         * and causing packet sizes to change */
        if (handleSampleRateChange(bp, sample_rate))
        {
            /* The sample rate has changed, a indication has been sent to the
               client task. The client task is expected to send a message in
               response */
            return broadcast_packetiser_state_sample_rate_change_pending;
        }
    }
    else
    {
        /* Good packet, handle parameter changes then read audio frames. */
        handleScmstChange(bp, scmst);
        handleVolumeChange(bp, volume);
        bp->ttp = ttp;
        if (handleSampleRateChange(bp, sample_rate))
        {
            /* The sample rate has changed, a indication has been sent to the
               client task. The client task is expected to send a message in
               response */
            return broadcast_packetiser_state_sample_rate_change_pending;
        }
        if (bp->sample_rate_unsupported)
        {
            bp->stats.rx.broadcast_packet_unsupported_sample_rate++;
        }
        else
        {
            readBroadcastPacketFrames(bp);
            bp->stats.rx.broadcast_packets_received++;
        }
    }
    return broadcast_packetiser_state_idle;
}

/* Complete broadcast packet processing.*/
static void completeBroadcastPacketProcessing(broadcast_packetiser_t *bp)
{
    if (bp->aesccm_nonce)
    {
        free(bp->aesccm_nonce);
        bp->aesccm_nonce = NULL;
    }
    broadcastPacketInit(&bp->bpkt, NULL, 0);
    bp->unencoded = NULL;
    ErasureCodingRxPacketResponse(bp->config.ec_handle.rx);
}

static void processBroadcastPacket(broadcast_packetiser_t *bp)
{
    switch (bp->state)
    {
        case broadcast_packetiser_state_decrypt:
        {
            bp->aesccm_nonce = malloc(sizeof(*bp->aesccm_nonce));
            if (bp->aesccm_nonce)
            {
                uint16 len;
                uint8 *addr = broadcastPacketGetEncryptionAddrLen(&bp->bpkt, &len);
                if (len)
                {
                    ttp_t rx_ttp;
                    broadcastPacketGetTTP(&bp->bpkt, &rx_ttp);
                    BP_DEBUG2("BPRX: Dec %d, %x", len, rx_ttp.base);
                    /* Decrypt the packet in place */
                    aesccmSetupEncryptionNonce(&bp->config.aesccm, &rx_ttp, bp->aesccm_nonce);
                    PanicFalse(CryptoAes128Ctr(bp->config.aesccm.key, bp->aesccm_nonce->n, 0, 1,
                                               addr, len, addr, len));
                    bp->state = broadcast_packetiser_state_calculate_mac_a;
                    MessageSend(&bp->lib_task, BROADCAST_PACKETISER_INTERNAL_AESCCM_COMPLETE, NULL);
                }
                else
                {
                    /* Nothing useful to decrypt. */
                    completeBroadcastPacketProcessing(bp);
                }
            }
            else
            {
                BP_DEBUG("BPRX: Unable to malloc nonce");
                completeBroadcastPacketProcessing(bp);
            }
            break;
        }

        case broadcast_packetiser_state_calculate_mac_a:
        {
            ttp_t rx_ttp;
            uint16 len;
            broadcastPacketGetAuthenticationAddrLen(&bp->bpkt, &len);
            broadcastPacketGetTTP(&bp->bpkt, &rx_ttp);
            BP_DEBUG2("BPRX: AuthMacA %d, %x", len, rx_ttp.base);
            aesccmSetupAuthenticationNonce(&bp->config.aesccm, &rx_ttp, len, bp->aesccm_nonce);
            /* First part of the authentication process is the B_0 vector - from aesccmSetupAuthenticationNonce */
            PanicFalse(CryptoAes128Cbc(TRUE, bp->config.aesccm.key, bp->aesccm_nonce->n, 0,
                                       zeros_16, sizeof(zeros_16), bp->aesccm_nonce->n, sizeof(zeros_16)));
            bp->state = broadcast_packetiser_state_calculate_mac_b;
            MessageSend(&bp->lib_task, BROADCAST_PACKETISER_INTERNAL_AESCCM_COMPLETE, NULL);
            break;
        }

        case broadcast_packetiser_state_calculate_mac_b:
        {
            uint16 len;
            uint8 *addr = broadcastPacketGetAuthenticationAddrLen(&bp->bpkt, &len);
            BP_DEBUG1("BPRX: AuthMacB %d", len);
            /* Second part of the authentication process is to authenticate the received data */
            PanicFalse(CryptoAes128Cbc(TRUE, bp->config.aesccm.key, bp->aesccm_nonce->n, 0,
                                       addr, len, NULL, 0));
            bp->state = broadcast_packetiser_state_authenticate;
            MessageSend(&bp->lib_task, BROADCAST_PACKETISER_INTERNAL_AESCCM_COMPLETE, NULL);
            break;
        }

        case broadcast_packetiser_state_authenticate:
        {
            aesccm_mac_t mac_rx = broadcastPacketReadMAC(&bp->bpkt);
            aesccm_mac_t mac_calc = aesccmNonceToMac(bp->aesccm_nonce);           

            /* Decrypt the MAC in place */
            ttp_t rx_ttp;
            broadcastPacketGetTTP(&bp->bpkt, &rx_ttp);
            aesccmSetupEncryptionNonce(&bp->config.aesccm, &rx_ttp, bp->aesccm_nonce);
            PanicFalse(CryptoAes128Ctr(bp->config.aesccm.key, bp->aesccm_nonce->n, 0, 0,
                                       (uint8*)&mac_rx, sizeof(aesccm_mac_t), 
                                       (uint8*)&mac_rx, sizeof(aesccm_mac_t)));

            if (mac_rx != mac_calc)
            {
                /* Drop the packet if it is not authentic */
                BP_DEBUG2("BPRX: !Authentic: %x, %x", mac_rx, mac_calc);
                bp->stats.rx.authentication_errors++;
                completeBroadcastPacketProcessing(bp);
                break;
            }
            BP_DEBUG("BPRX: Authentic");
            /* Fall-through to read the packet */
        }

        case broadcast_packetiser_state_read_broadcast_packet:
            bp->state = readBroadcastPacket(bp);
            if (bp->state == broadcast_packetiser_state_idle)
            {
                completeBroadcastPacketProcessing(bp);
            }
            break;

        default:
            /* Invalid state */
            Panic();
            break;
    }
}

void BroadcastPacketiserSampleRateChangeResponse(broadcast_packetiser_t *bp,
                                                  bool response)
{
    if (bp->config.role == broadcast_packetiser_role_receiver &&
        bp->state == broadcast_packetiser_state_sample_rate_change_pending)
    {
        BP_DEBUG1("BPRX: SR Changed Resp %d", response);
        bp->start_of_stream = TRUE;
        bp->sample_rate_unsupported = !response;
        bp->state = broadcast_packetiser_state_read_broadcast_packet;
        processBroadcastPacket(bp);
    }
    else
    {
        /* Function called in invalid role or invalid state */
        Panic();
    }
}

void messageHandlerReceiver(Task task, MessageId id, Message message)
{
    broadcast_packetiser_t *bp =(broadcast_packetiser_t *)task;
    switch (id)
    {
        case ERASURE_CODING_RX_PACKET_IND:
        {
            ERASURE_CODING_RX_PACKET_IND_T *ind = (ERASURE_CODING_RX_PACKET_IND_T*)message;
            /* Should not get this message whilst there is another message being processed */
            PanicFalse(NULL == bp->unencoded);
            bp->unencoded = ind->unencoded;
            broadcastPacketInit(&bp->bpkt, bp->unencoded->buffer, bp->unencoded->size);
            bp->state = bp->config.aesccm_disabled ? broadcast_packetiser_state_read_broadcast_packet :
                                                     broadcast_packetiser_state_decrypt;

            processBroadcastPacket(bp);
            break;
        }

        /* More space available in sink */
        case MESSAGE_MORE_SPACE:
            break;

        case BROADCAST_PACKETISER_INTERNAL_AESCCM_COMPLETE:
            processBroadcastPacket(bp);
            break;

        case BROADCAST_PACKETISER_INTERNAL_STATS_MSG:
        {
            MESSAGE_MAKE(msg, BROADCAST_PACKETISER_STATS_RECEIVER_IND_T);
            msg->broadcast_packetiser = bp;
            msg->stats = bp->stats.rx;
            MessageSend(bp->config.client_task, BROADCAST_PACKETISER_STATS_RECEIVER_IND, msg);
            MessageSendLater(&bp->lib_task, BROADCAST_PACKETISER_INTERNAL_STATS_MSG,
                             NULL, bp->config.stats_interval / US_PER_MS);
            memset(&bp->stats, 0, sizeof(bp->stats));
            break;
        }

        case SCM_RECEIVER_TRANSPORT_REGISTER_REQ:
        {
            SCM_RECEIVER_TRANSPORT_REGISTER_REQ_T *msg;
            msg = (SCM_RECEIVER_TRANSPORT_REGISTER_REQ_T *)message;
            if (msg->scm)
            {
                bp->scm_transport = ScmrTransportInit(msg->scm);
                ScmReceiverTransportRegisterCfm(msg->scm, &bp->lib_task);
                MessageSendLater(&bp->lib_task,
                                 BROADCAST_PACKETISER_INTERNAL_SCM_TRANSPORT_KICK_MSG,
                                 NULL, SCMR_TRANSPORT_KICK_PERIOD_MS);
            }
            break;
        }

        case SCM_RECEIVER_TRANSPORT_UNREGISTER_REQ:
        {
            SCM_RECEIVER_TRANSPORT_UNREGISTER_REQ_T *msg;
            msg = (SCM_RECEIVER_TRANSPORT_UNREGISTER_REQ_T *)message;
            if (msg->scm)
            {
                ScmrTransportShutdown(bp->scm_transport);
                bp->scm_transport = NULL;
                MessageCancelAll(&bp->lib_task,
                                 BROADCAST_PACKETISER_INTERNAL_SCM_TRANSPORT_KICK_MSG);
                ScmReceiverTransportUnRegisterCfm(msg->scm);
            }
            break;
        }

        /* Flush stale received SCM segments from the transport */
        case BROADCAST_PACKETISER_INTERNAL_SCM_TRANSPORT_KICK_MSG:
            ScmrTransportSegmentCheck(bp->scm_transport);
            MessageSendLater(&bp->lib_task,
                             BROADCAST_PACKETISER_INTERNAL_SCM_TRANSPORT_KICK_MSG,
                             NULL, SCMR_TRANSPORT_KICK_PERIOD_MS);
            break;

        default:
            BP_DEBUG1("BP: Unhandled message, %u", id);
            Panic();
            break;
    }
}
