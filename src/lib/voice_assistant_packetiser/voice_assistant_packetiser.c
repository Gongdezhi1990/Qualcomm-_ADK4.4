/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    voice_assistant_packetiser.c

DESCRIPTION
    @brief Interface to the Voice Assistant Packetiser Library.
    The VA packetiser reads the voice data packet from the source and sends 
    to GAIA libray.
*/

#include <message.h>
#include <panic.h>
#include <vmal.h>

#include"voice_assistant_packetiser_private.h"
#include "voice_assistant_packetiser.h"
#include"voice_assistant_packet_send.h"

/* The one, and only, Voice Assistant packetiser Instance */
static voice_assistant_packetiser_t* voice_assistant_packetiser = 0;

/* PRIVATE FUNCTION DEFINITIONS **********************************************/

/******************************************************************************
DESCRIPTION
    @brief This function handles all messages sent to the voice assistant packetiser task.

    @param task Task to which the message has been sent.
    @param id Message type identifier.
    @param message Message contents.
*/
static void VaPacketiserMessageHandler(Task task, MessageId id, Message message)
{
    UNUSED(task);
    UNUSED(message);
    PRINT(("VAP: vaPacketiserMsgHandler() \n"));

    switch (id)
    {
        /* Assuming more data will come for every 64 bytes of voice data. */
        case MESSAGE_MORE_DATA:
        {
            if(NULL != voice_assistant_packetiser->source)/* Use SourceIsValid() once B-231645 is fixed. TO DO. */
            {
                VapSendPacket(((MessageMoreData *) message)->source);
            }
        }
        break;

        default:
            PRINT(("VAP: Unhandled message %x\n", id));
            break;
    }
}

/* PUBLIC FUNCTION DEFINITIONS ***********************************************/

/******************************************************************************
DESCRIPTION
    @brief API function to the application for Creating the instance and initialise
    the of voice assistant packetiser.

    @param source The DSP encoded voice samples data will be read.

    @return TRUE on success, FALSE otherwise.
*/
bool VaPacketiserStart(Source source)
{
    PRINT(("VAP: VaPacketiserStart() \n"));

    if(voice_assistant_packetiser == NULL)
    {
        if(source)
        {
            /* Create a new instance of the library. */
            voice_assistant_packetiser = (voice_assistant_packetiser_t *)calloc(1, sizeof(*voice_assistant_packetiser));

            PanicNull(voice_assistant_packetiser);

            /* Store DSP encoded voice samples data source. */
            voice_assistant_packetiser->source = source;

            /* Set the handler function */
            voice_assistant_packetiser->lib_task.handler = VaPacketiserMessageHandler;

            /* Associate a task with a source. */
            VmalMessageSourceTask(voice_assistant_packetiser->source, &voice_assistant_packetiser->lib_task);

            /* Configure the Source. */
            PanicFalse(SourceConfigure(source, VM_SOURCE_MESSAGES, VM_MESSAGES_SOME));

            /* Initial read is need for the source, otherwise MESSAGE_MORE_DATA may not be sent.
               Without MESSAGE_MORE_DATA this library won't process any data. */
            VapSendPacket(voice_assistant_packetiser->source);

            return TRUE;
        }
        else
        {
            /* Invalid Source. */
            return FALSE; 
        }
    }
    else
    {
        /* Failed to initialise Voice assistant packetiser library. */
        return FALSE;
    }
}

/******************************************************************************
DESCRIPTION
    @brief API function to the application for destroying the voice assistant 
    packetiser.instance.

    @return TRUE on success, FALSE otherwise.
*/
bool VaPacketiserStop(void)
{
    uint16 unreadDataSize;
    PRINT(("VAP: VaPacketiserStop() \n"));

    if(voice_assistant_packetiser)
    {
        /* Discard unread input data in the source. */
        unreadDataSize = SourceSize(voice_assistant_packetiser->source);
        if (unreadDataSize)
        {
            PRINT(("VAP: Drop Un read data from  the Source\n"));
            SourceDrop(voice_assistant_packetiser->source, unreadDataSize);
        }

        /* Clear pending messages */
        MessageFlushTask(&voice_assistant_packetiser->lib_task);

        free(voice_assistant_packetiser);
        voice_assistant_packetiser = NULL;
        return TRUE;
    }

    return FALSE;
}

