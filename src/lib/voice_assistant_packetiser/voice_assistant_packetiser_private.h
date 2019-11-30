/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    voice_assistant_packetiser_private.h

DESCRIPTION
    @brief This file contains data private to the voice assistant packetiser library.
*/

#ifndef _VOICE_ASSISTANT_PACKETISER_PRIVATE_H_
#define _VOICE_ASSISTANT_PACKETISER_PRIVATE_H_

/*------------------------------ include headers ----------------------------*/
#include <stdlib.h>
#include <stdio.h>
#include <print.h>
#include <vmtypes.h>

#include <message_.h>
#include <source_.h>

#include "app/message/system_message.h"

/*****************************************************************************/

/*-------------------  Defines -------------------*/

/******************************************************************************
DESCRIPTION
    @brief voice assistant packetiser library main task and its data members.
*/

typedef struct __voice_assistant_packetiser
{
    /*! Task for this instance of the library */
    TaskData lib_task;

    /*! The Source of voice data captured from DSP. */
    Source source;

}voice_assistant_packetiser_t;

#endif /* ifdef _VOICE_ASSISTANT_PACKETISER_PRIVATE_H_ */

