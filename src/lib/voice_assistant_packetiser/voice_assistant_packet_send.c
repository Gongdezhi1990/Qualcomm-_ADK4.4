/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    voice_assistant_packet_send.c

DESCRIPTION
    This file contains supporting functions for VA packetiser.
*/

#include <string.h>
#include <vm.h>

#include "gaia.h"

#include"voice_assistant_packetiser_private.h"
#include"voice_assistant_packet_send.h"

#define MIN_VA_PACKET_TO_SEND 2
#define VA_VOICE_PKT_LEN 64
#define MIN_VA_PKT_SIZE_TO_BE_SEND (VA_VOICE_PKT_LEN*MIN_VA_PACKET_TO_SEND)

/* PRIVATE FUNCTION DEFINITIONS **********************************************/

/* PUBLIC FUNCTION DEFINITIONS ***********************************************/

/******************************************************************************
DESCRIPTION
    @brief This function reads voice data packets from the source and send to 
              the remote device through GAIA library.

    @param src The DSP encoded voice samples data to be read.
*/
void VapSendPacket(Source src)
{
    const uint8 *payload = SourceMap(src);
    uint16 sent_packet_size = 0;

    PRINT(("VAP: VapSendPacket() \n"));

    if(payload)
    {
        uint16 packet_len = SourceSize(src);

        PRINT(("VAP: Length[%u] and Source[%p]\n", packet_len, payload));

        /* Check enough packets are there to send */
        if((packet_len) && (packet_len >= MIN_VA_PKT_SIZE_TO_BE_SEND))
        {
            /* Send VA packet to GAIA library. */
            sent_packet_size = GaiaVoiceAssistantSendData(packet_len, payload,(packet_len/VA_VOICE_PKT_LEN));
            /* Drop the processed packet data. */
            SourceDrop(src, sent_packet_size);
            PRINT(("VAP: Packet Sent: Lenth[%u]\n",sent_packet_size));
        }
    }
}

