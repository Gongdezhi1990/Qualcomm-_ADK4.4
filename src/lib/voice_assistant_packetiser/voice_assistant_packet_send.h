/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    voice_assistant_packet_send.h

DESCRIPTION
    This header file declares the function prototype for sending the voice data
    packets to the GAIA library.
*/

#include <source.h>

#ifndef __VOICE_ASSISTANT_PACKET_SEND_H__
#define __VOICE_ASSISTANT_PACKET_SEND_H__

/******************************************************************************
DESCRIPTION
    @brief This function reads voice data packets from the source and send to 
              the remote device through GAIA library.

    @param src The DSP encoded voice samples data will be read.
*/
void VapSendPacket(Source src);

#endif  /* __VOICE_ASSISTANT_PACKET_SEND_H__ */

