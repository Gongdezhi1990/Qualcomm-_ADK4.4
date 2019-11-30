/****************************************************************************
Copyright (c)  2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    broadcast_packet.h

DESCRIPTION
    Private header file for the Broadcast Packet.

*/

#ifndef BROADCAST_PACKET_H_
#define BROADCAST_PACKET_H_

#include <packetiser_helper.h>
#include <rtime.h>
#include <erasure_coding.h>
#include <scm_transport.h>

#include "broadcast_packet_ttp.h"
#include "aesccm.h"

/* Code to indicate broadcastPacketReadAudioHeader() detected a framing error */
#define FRAME_COUNT_FRAMING_ERROR 0xFFFFFFFFU

typedef struct __broadcast_packet
{
    /*! Broadcaster role: store the buffer write index whilst creating the packet
        Receiver role: store the buffer read index whilst parsing the packet */
    uint8 *pkt_ptr;

    /*! The length of the current packet in the buffer. */
    uint16 packet_length;

    /*! Buffer containing the broadcast packet data */
    uint8 *packet;

} broadcast_packet_t;

/*!
  @brief Initialise the packet structure.
  @param bp The packet instance.
  @param packet The memory allocated for the packet.
  @param packet_length The packet length.
*/
void broadcastPacketInit(broadcast_packet_t *bp, uint8 *packet, uint16 packet_length);

/*!
  @brief Calculate the data written to the packet buffer (the packet length).
  @param bp The packet instance.
  @return The packet length.
*/
uint16 broadcastPacketGetLength(broadcast_packet_t *bp);

/*!
  @brief Calculate the maximum number of audio frames that will fit into a packet.
  @param bp The packet instance.
  @param frame_length The length of an audio frame.
  @return The maximum number of audio frames that will fit in the packet.
*/
uint16 broadcastPacketCalcMaxFrames(broadcast_packet_t *bp, uint16 frame_length);

/*!
  @brief Write the packet header to the broadcast packet. The packet header is
  the TTP, and space for the MAC (as the MAC is not calculated until the packet
  is complete).
  @param bp The packet instance.
  @param The TTP to write in the header.
*/
void broadcastPacketWriteNonAudio(broadcast_packet_t *bp, const ttp_t *ttp);

/*!
  @brief Read the non-audio elements of the broadcast packet.
  @param bp The packet instance.
  @param scm_transport The SCM transport.
  @param [OUT] ttp The frame's time-to-play.
  @return TRUE if the data was read correct, otherwise FALSE.
*/
bool broadcastPacketReadNonAudio(broadcast_packet_t *bp,
                                 scm_transport_t *scm_transport,
                                 ttp_t *ttp);

/*!
  @brief Write the audio header to the broadcast packet.
  @param bp The packet instance.
  @param scmst The scmst to write.
  @param volume The volume to write.
  @param sample_rate The sample rate to write.
*/
void broadcastPacketWriteAudioHeader(broadcast_packet_t *bp,
                                     const packetiser_helper_scmst_t scmst,
                                     const uint32 volume,
                                     const rtime_sample_rate_t sample_rate);

/*!
  @brief Read the broadcast packet audio header.
  @param bp The packet instance.
  @param frame_length The length of each audio frame in the packet.
  @param frame_count [OUT] The number of frames in the packet.
  @param scmst [OUT] The read scmst.
  @param volume [OUT] The read volume.
  @param sample_rate [OUT] The read sample rate.
  @return TRUE if the audio header was read correctly, otherwise FALSE.
  The functions fails if: the packet is not large enough to contain a header;
  the audio tag is not found; the extended audio header is present; there is
  an audio frame error (the packet contains a non-integer number of audio 
  frames, calculated based on the current value of frame_length).
  If the function returns FALSE due to a framing error, the sample_rate will
  still be updated. This can be used to detect if a sample rate change is
  causing the framing error. If a framing error is detected, frame_count
  will be set to FRAME_COUNT_FRAMING_ERROR.
*/
bool broadcastPacketReadAudioHeader(broadcast_packet_t *bp,
                                    uint16 frame_length,
                                    uint32 *frame_count,
                                    packetiser_helper_scmst_t *scmst,
                                    uint32 *volume,
                                    rtime_sample_rate_t *sample_rate);

/*!
  @brief Write an audio frame to the broadcast packet.
  @param bp The packet instance.
  @param src The source data.
  @param frame_length The length of the frame.
  @param spadjm The frame's mini sample period adjustment.
  @return TRUE if frame was written, FALSE otherwise.
*/
bool broadcastPacketWriteAudioFrame(broadcast_packet_t *bp,
                                    const uint8 *src, uint16 frame_length,
                                    rtime_spadj_mini_t spadjm);

/*!
  @brief Read the indexed broadcast packet audio frame.
  @param bp The packet instance.
  @param dest The destination to read the frame to.
  @param frame_index The indexed frame to read.
  @param frame_length The frame length.
*/
void broadcastPacketReadAudioFrame(broadcast_packet_t *bp,
                                   uint8 *dest,
                                   uint32 frame_index, uint16 frame_length);

/*!
  @brief Read the indexed broadcast packet audio frame header.
  @param bp The packet instance.
  @param frame_index The indexed frame to read.
  @param frame_length The frame length.
  @return The frame header (the mini spadj).
*/
rtime_spadj_mini_t broadcastPacketReadAudioFrameHeader(broadcast_packet_t *bp,
                                                       uint32 frame_index,
                                                       uint16 frame_length);

/*!
  @brief Write the AESCCM MAC to the broadcast packet.
  @param bp The packet instance.
  @param mac The MAC.
*/
void broadcastPacketWriteMAC(broadcast_packet_t *bp, aesccm_mac_t mac);

/*!
  @brief Read the AESCCM MAC from the broadcast packet.
  @param bp The packet instance.
  @return the MAC.
*/
aesccm_mac_t broadcastPacketReadMAC(broadcast_packet_t *bp);

/*!
  @brief Write SCM segment(s) to the broadcast packet.
  @param bp The packet instance.
  @param scm_transport The SCM transport.
  @return TRUE is at least one SCM segment was written, otherwise FALSE.
 */
bool broadcastPacketWriteSCM(broadcast_packet_t *bp,
                             scm_transport_t *scm_transport);

/*!
  @brief Get the address and length of the data to be authenticated.
  @param bp The packet instance.
  @param authentication_len [OUT] The number of octets to be authenticated.
  @return The start address of the data to be authenticated.
 */
uint8* broadcastPacketGetAuthenticationAddrLen(broadcast_packet_t *bp, uint16 *authentication_len);

/*!
  @brief Get the address and length of the data to be encrypted/decrypted.
  @param bp The packet instance.
  @param encryption_len [OUT] The number of octets to be encrypted/decrypted.
  @return The start address of the data to be encrypted/decrypted.
 */
uint8* broadcastPacketGetEncryptionAddrLen(broadcast_packet_t *bp, uint16 *encryption_len);

/*!
  @brief Read the TTP from a broadcast packet.
  @param bp The packet instance.
  @param ttp [OUT] The packet's TTP .
*/
void broadcastPacketGetTTP(broadcast_packet_t *bp, ttp_t *ttp);

#endif
