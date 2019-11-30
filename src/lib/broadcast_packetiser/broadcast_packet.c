/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    broadcast_packet.c
*/

#include <broadcast_packet.h>
#include <packetiser_helper.h>

#include <stddef.h>
#include <string.h>
#include <panic.h>
#include <scm_transport.h>

/* Reserve space in the buffer for one SCM segment */
#define RESERVED_FOR_SCM (SCM_SEGMENT_SIZE)

/* The audio header is the tag plus the volume and sample rate */
#define AUDIO_HEADER_LEN 2

/* The non-audio data at the start of the packet */
#define NON_AUDIO_LEN (sizeof(ttp_bytes_t) + sizeof(aesccm_mac_t))


static size_t writeTTP(uint8 *dest, const ttp_t *ttp)
{
    ttp_bytes_t t;
    t.ttp[0] = ttp->extension;
    t.ttp[1] = (uint8)(ttp->base >> 24) & 0xff;
    t.ttp[2] = (uint8)(ttp->base >> 16) & 0xff;
    t.ttp[3] = (uint8)(ttp->base >> 8) & 0xff;
    t.ttp[4] = (uint8)ttp->base & 0xff;
    memcpy(dest, &t, sizeof(ttp_bytes_t));
    return sizeof(ttp_bytes_t);
}

static size_t readTTP(const uint8 *src, ttp_t *ttp)
{
    ttp->extension = src[0];
    ttp->base = (rtime_t)src[1] << 24;
    ttp->base |= (rtime_t)src[2] << 16;
    ttp->base |= (rtime_t)src[3] << 8;
    ttp->base |= src[4];
    return sizeof(ttp_bytes_t);
}

static uint16 broadcastPacketCalcUnread(broadcast_packet_t *bp)
{
    ptrdiff_t unread = bp->packet + bp->packet_length - bp->pkt_ptr;
    if (unread < 0)
        Panic();
    return (uint16)unread;
}

static uint16 broadcastPacketCalcSpace(broadcast_packet_t *bp)
{
    ptrdiff_t space = bp->packet + bp->packet_length - bp->pkt_ptr - RESERVED_FOR_SCM;
    if (space < 0)
        Panic();
    return (uint16)space;
}

uint16 broadcastPacketGetLength(broadcast_packet_t *bp)
{
    ptrdiff_t packet_length = bp->pkt_ptr - bp->packet;
    if (packet_length < 0)
        Panic();
    bp->packet_length = (uint16)packet_length;
    return bp->packet_length;
}

uint16 broadcastPacketCalcMaxFrames(broadcast_packet_t *bp, uint16 frame_length)
{
    /* SCM data is not inculded here because it is written into
       any space left after the audio frames have been written. */
    return ((bp->packet_length - NON_AUDIO_LEN - AUDIO_HEADER_LEN) / frame_length);
}

void broadcastPacketInit(broadcast_packet_t *bp, uint8 *packet, uint16 packet_length)
{
    bp->packet_length = packet_length;
    bp->pkt_ptr = bp->packet = packet;
}

/* On exit from the function, the pkt_ptr points to the address
   where the audio header may be written */
void broadcastPacketWriteNonAudio(broadcast_packet_t *bp, const ttp_t *ttp)
{
    /* Start from the start of the packet */
    uint8 *dest = bp->packet;
    /* Reset pkt_ptr for broadcastPacketCalcSpace() */
    bp->pkt_ptr = dest;

    /* Assert there is enough space for the header. */
    if (broadcastPacketCalcSpace(bp) < (sizeof(ttp_bytes_t) + sizeof(aesccm_mac_t)))
    {
        Panic();
    }

    /* Write TTP and extension */
    dest += writeTTP(dest, ttp);

    /* Zero MAC. It is written once the frame is complete if encryption is enabled. */
    memset(dest, 0, sizeof(aesccm_mac_t));
    dest += sizeof(aesccm_mac_t);

    /* Save current position */
    bp->pkt_ptr = dest;
}

/* On exit from the function, the pkt_ptr will address:
   1. The audio data tag (if it was found)
   2. One byte beyond the end of the packet buffer if no audio tag was found
      and there were no framing errors.
   3. The final tag processed if a framing error was found. A framing error
      means the length of data defined in the tag would cause a buffer overrun.
*/
bool broadcastPacketReadNonAudio(broadcast_packet_t *bp,
                                 scm_transport_t *scm_transport,
                                 ttp_t *ttp)
{
    uint32 unread;

    /* Read from the start of the packet */
    bp->pkt_ptr = bp->packet;

    /* Read the TTP and extension */
    bp->pkt_ptr += readTTP(bp->pkt_ptr, ttp);

    /* Skip over MAC */
    bp->pkt_ptr += sizeof(aesccm_mac_t);

    unread = broadcastPacketCalcUnread(bp);

    /* Read remaining tagged data until the audio tag is found or the end of the
       packet is reached. */
    while(unread)
    {
        uint8 tag = *bp->pkt_ptr;
        if(TAG_IS_NON_AUDIO(tag))
        {
            /* Get length of tag and tag data */
            uint32 len = TAG_GET_NON_AUDIO_LENGTH(tag) + 1U;
            uint32 type = TAG_GET_NON_AUDIO_TYPE(tag);
            if (len > unread)
            {
                /* Framing error with tag/data in packet */
                return FALSE;
            }
            if (type == packetiser_helper_non_audio_type_scm &&
                len == SCM_SEGMENT_SIZE)
            {
                /* Pass this SCM segment to the transport */
                if (scm_transport)
                {
                    ScmrTransportReadSegment(scm_transport, bp->pkt_ptr + 1);
                }
            }
            /* Step over the tag data to the next tag */
            bp->pkt_ptr += len;
            unread -= len;
        }
        else
        {
            /* Audio tag has been found */
            break;
        }
    }
    return TRUE;
}

/* On exit from the function, the pkt_ptr points to the address where the first
   audio frame will be written. */
void broadcastPacketWriteAudioHeader(broadcast_packet_t *bp,
                                     const packetiser_helper_scmst_t scmst,
                                     const uint32 volume,
                                     const rtime_sample_rate_t sample_rate)
{
    /* Continue writing from last write */
    uint8 *dest = bp->pkt_ptr;

    /* Assert there is enough space for the header. */
    if (broadcastPacketCalcSpace(bp) < AUDIO_HEADER_LEN)
    {
        Panic();
    }

    /* Write audio data tag (extended audio header absent) */
    *dest++ = (uint8)(TAG_AUDIO_TYPE_MASK | TAG_SET_AUDIO_SCMST_TYPE(scmst));

    /* Write volume and sample rate */
    *dest++ = (uint8)(((volume & 0x1F) << 3) | (sample_rate & 0x7));

    /* Save current position */
    bp->pkt_ptr = dest;
}

/* On exit from the function, if there are audio frames, the pkt_ptr will
   address the first audio frame in the packet. Otherwise pkt_ptr will be
   unchanged. */
bool broadcastPacketReadAudioHeader(broadcast_packet_t *bp,
                                    uint16 frame_length,
                                    uint32 *frame_count,
                                    packetiser_helper_scmst_t *scmst,
                                    uint32 *volume,
                                    rtime_sample_rate_t *sample_rate)
{
    uint32 unread = broadcastPacketCalcUnread(bp);
    *frame_count = 0;
    if (unread >= AUDIO_HEADER_LEN)
    {
        uint8 tag = bp->pkt_ptr[0];
        if (TAG_IS_AUDIO(tag))
        {
            /* Broadcast does not use/know how to parse the extended header */
            if (!TAG_AUDIO_EXTENDED_HEADER_IS_PRESENT(tag))
            {
                /* Test that the frame contains an whole number of frames. */
                uint32 remainder = ((unread - AUDIO_HEADER_LEN) %
                                    (frame_length + sizeof(rtime_spadj_mini_t)));
                    
                /* always try and read the sample rate in the first audio frame
                 * we may have a framing error, but only due to changing sample
                 * rate causing packet sizes to change. */
                *sample_rate = bp->pkt_ptr[1] & 0x7;

                if (!remainder)
                {
                    *frame_count = ((unread - AUDIO_HEADER_LEN) /
                                    (frame_length + sizeof(rtime_spadj_mini_t)));

                    /* Read the volume and SCMS-T fields */
                    *volume = (bp->pkt_ptr[1] >> 3) & 0x1f;
                    *scmst = TAG_GET_AUDIO_SCMST_TYPE(tag);

                    bp->pkt_ptr += AUDIO_HEADER_LEN;

                    return TRUE;
                }
                else
                {
                    /* Framing error */
                    *frame_count = FRAME_COUNT_FRAMING_ERROR;
                    return FALSE;
                }
            }
        }
    }
    return FALSE;
}

bool broadcastPacketWriteAudioFrame(broadcast_packet_t *bp,
                                    const uint8 *src, uint16 frame_length,
                                    rtime_spadj_mini_t spadjm)
{
    /* Enough space? */
    if (broadcastPacketCalcSpace(bp) >= (sizeof(rtime_spadj_mini_t) + frame_length))
    {
        /* Start from the last write */
        uint8 *dest = bp->pkt_ptr;

        /* Each frame has a mini-sample period adjustment */
        *dest++ = (uint8)spadjm;

        /* Copy frame from the source */
        memcpy(dest, src, frame_length);
        dest += frame_length;

        /* Store current value of write pointer, so we can continue writing to
           the buffer later */
        bp->pkt_ptr = dest;

        return TRUE;
    }
    return FALSE;
}

static uint8 *nthAudioFrame(broadcast_packet_t *bp, uint32 n, uint16 frame_length)
{
    return bp->pkt_ptr + (n * (frame_length + sizeof(rtime_spadj_mini_t)));
}

/* Assumes pkt_ptr points to sample period adjustment of the first audio frame
   in the packet. */
rtime_spadj_mini_t broadcastPacketReadAudioFrameHeader(broadcast_packet_t *bp,
                                                       uint32 frame_index,
                                                       uint16 frame_length)
{
    uint8 *src = nthAudioFrame(bp, frame_index, frame_length);
    return (rtime_spadj_mini_t)*src;
}

/* Assumes pkt_ptr points to sample period adjustment of the first audio frame
   in the packet. */
void broadcastPacketReadAudioFrame(broadcast_packet_t *bp,
                                   uint8 *dest,
                                   uint32 frame_index,
                                   uint16 frame_length)
{
    uint8 *src = nthAudioFrame(bp, frame_index, frame_length);
    src += sizeof(rtime_spadj_mini_t);
    memcpy(dest, src, frame_length);
}

/* Get the address and length of the data to be authenticated */
uint8* broadcastPacketGetAuthenticationAddrLen(broadcast_packet_t *bp, uint16 *authentication_len)
{
    uint16 extra = sizeof(ttp_bytes_t) + sizeof(aesccm_mac_t);
    uint16 len = bp->packet_length;
    if (len >= extra)
    {
        *authentication_len = (uint16)(len - extra);
        return bp->packet + extra;
    }
    *authentication_len = 0;
    return NULL;
}

/* Get the address and length of the data to be encrypted/decrypted */
uint8* broadcastPacketGetEncryptionAddrLen(broadcast_packet_t *bp, uint16 *encryption_len)
{
    return broadcastPacketGetAuthenticationAddrLen(bp, encryption_len);
}

void broadcastPacketWriteMAC(broadcast_packet_t *bp, aesccm_mac_t mac)
{
    /* The MAC is after the TTP */
    uint8 *dest = bp->packet + sizeof(ttp_bytes_t);
    memcpy(dest, &mac, sizeof(aesccm_mac_t));
}

aesccm_mac_t broadcastPacketReadMAC(broadcast_packet_t *bp)
{
    aesccm_mac_t mac;
    /* The MAC is after the TTP */
    uint8 *src = bp->packet + sizeof(ttp_bytes_t);
    memcpy(&mac, src, sizeof(aesccm_mac_t));
    return mac;
}

void broadcastPacketGetTTP(broadcast_packet_t *bp, ttp_t *ttp)
{
    /* Read the TTP and extension from the start of the packet */
    readTTP(bp->packet, ttp);
}

bool broadcastPacketWriteSCM(broadcast_packet_t *bp, scm_transport_t *scm_transport)
{
    /* Get the remaining space in the buffer */
    uint32 space = broadcastPacketCalcSpace(bp);

    /* Offer this space to the SCM transport. The scm's requirement includes the tag */
    uint32 scms_requirement = (scm_transport ?
                               ScmbTransportOfferSpace(scm_transport, space) :
                               0);

    if ((space + RESERVED_FOR_SCM) < scms_requirement)
        Panic();

    /* The audio data in the buffer needs to be moved if SCM segments require
       space */
    if (scms_requirement)
    {
        /* Calculate the address of the audio data tag */
        uint8 *audio_ptr = bp->packet + sizeof(ttp_bytes_t) + sizeof(aesccm_mac_t);
        uint8 *dest = audio_ptr + scms_requirement;
        ptrdiff_t count = bp->pkt_ptr - audio_ptr;

        if ((count < 0) ||
            ((dest + count) >= (bp->packet + bp->packet_length)))
        {
            Panic();
        }

        memmove(dest, audio_ptr, (size_t)count);

        /* Write SCM segments into the space required */
        space = ScmbTransportWriteSegments(scm_transport, audio_ptr, scms_requirement);
        /* The SCM transport should honour the requirement it made */
        if (space != 0)
        {
            Panic();
        }

        /* increase packet size to account for SCM message space */
        bp->pkt_ptr += scms_requirement;

        return TRUE;
    }
    return FALSE;
}
