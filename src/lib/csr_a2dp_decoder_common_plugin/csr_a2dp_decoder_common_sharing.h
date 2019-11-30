/****************************************************************************
Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_a2dp_decoder_common_sharing.h

DESCRIPTION
    Functionality to share audio with a second device.

*/
 
#ifndef _CSR_A2DP_DECODER_COMMON_SHARING_H_
#define _CSR_A2DP_DECODER_COMMON_SHARING_H_

/* 
    Use a fixed packet size when using the RTP transform to encode the ShareMe data.
    It would be better if this packet size was passed into the CsrA2dpDecoderPluginForwardUndecoded() function,
    but the A2DP MTU is set to be this value for the Master to Slave ShareMe link.
*/
#define SHAREME_ENCODE_FIXED_PACKET_SIZE (672)

/* Space for Real-time Transport Protocol header */
#define SHAREME_APTX_RTP_OVERHEAD (12)

/* Relay packet size (in 16-bit words) */
#define SHAREME_APTX_PACKET_SIZE ((SHAREME_ENCODE_FIXED_PACKET_SIZE - SHAREME_APTX_RTP_OVERHEAD) / 2)
/* For SBC the RTP overhead is 13 bytes; we can't communicate an odd size to
 * the DSP so we choose a size of 446 (223 words).  The DSP is able to copy
 * 2 packets of that size into its 1K buffer, and the FW takes 659 bytes for
 * every RTP packet, leaving space for the DSP to copy another packet.
 */
#define SHAREME_SBC_PACKET_SIZE (223)

/* Relay packet time interval */
#define SHAREME_APTX_FLUSH_THRESHOLD (12)
#define SHAREME_SBC_FLUSH_THRESHOLD (12)

extern void CsrA2dpDecoderPluginForwardUndecoded(A2dpPluginTaskdata *task , bool enable, Sink sink, bool content_protection, peer_buffer_level buffer_level_required);
extern void CsrA2dpDecoderPluginDisconnectForwardingSink(void);
extern void A2DPConnectAndConfigureTWSAudio(peer_buffer_level buffer_level_required);

#endif


