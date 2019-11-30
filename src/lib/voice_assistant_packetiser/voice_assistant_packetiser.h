/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    voice_assistant_packetiser.h

DESCRIPTION
    @brief The library exposes a functional API to the application/libraries.


         CLIENT APPLICATION
               |             |
               |    VOICE ASSISTANT PACKETISER Library
               |             |
               GAIA  Library
               |             |
         BLUESTACK/HYDRACORE

*/

#ifndef _VOICE_ASSISTANT_PACKETISER_H_
#define _VOICE_ASSISTANT_PACKETISER_H_

#include <source_.h>

/******************************************************************************
DESCRIPTION
    @brief API function to the application for Creating the instance and initialise
    the of voice assistant packetiser.

    @param source The DSP encoded voice samples data will be read.

    @return TRUE on success, FALSE otherwise.
*/
bool VaPacketiserStart(Source source);

/******************************************************************************
DESCRIPTION
    @brief API function to the application for destroying the voice assistant 
    packetiser.instance.

    @return TRUE on success, FALSE otherwise.
*/
bool VaPacketiserStop(void);

#endif /* ifdef _VOICE_ASSISTANT_PACKETISER_H_ */

