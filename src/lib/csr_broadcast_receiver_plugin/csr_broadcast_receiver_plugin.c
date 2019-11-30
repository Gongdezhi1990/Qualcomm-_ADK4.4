/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
   csr_broadcast_receiver_plugin.c

DESCRIPTION
NOTES
*/

#include <audio.h>
#include <stdlib.h>
#include <string.h>

#include <print.h>
#include <audio_plugin_music_variants.h>
#include <audio_plugin_if.h>

#include "csr_broadcast_receiver_audio.h"
#include "csr_broadcast_receiver_plugin.h"

/* The externally available plugin object. */
const A2dpPluginTaskdata csr_ba_receiver_decoder_plugin = {{CsrReceiverMusicMessageHandler}, BA_CELT_DECODER, BITFIELD_CAST(8, 0)};

/****************************************************************************
DESCRIPTION
    Internal messages to the task are handled here
*/
static void handleInternalMessage ( Task task , MessageId id, Message message )
{
    CsrBaReceiverAudioPluginInternalMessage((A2dpPluginTaskdata*)task, id, message);
}

/****************************************************************************
DESCRIPTION
    Messages from the audio library are received here.
    and converted into function calls to be implemented in the
    plug-in module.
*/
static void handleAudioMessage(Task task, MessageId id, Message message)
{
    switch(id)
    {
        case AUDIO_PLUGIN_CONNECT_MSG:
        {
            AUDIO_PLUGIN_CONNECT_MSG_T * connect_message = (AUDIO_PLUGIN_CONNECT_MSG_T *)message;
            CsrBaReceiverAudioPluginConnect((A2dpPluginTaskdata*)task, connect_message);
            break;
        }

        case AUDIO_PLUGIN_DISCONNECT_MSG:
        {
            CsrBaReceiverAudioPluginDisconnect((A2dpPluginTaskdata*)task);
        }
        break;

        case AUDIO_PLUGIN_SET_MODE_MSG:
        {
            AUDIO_PLUGIN_SET_MODE_MSG_T * mode_message = (AUDIO_PLUGIN_SET_MODE_MSG_T *)message ;
            CsrBaReceiverAudioPluginSetMode(mode_message->mode , mode_message->params);
        }
        break;

        case AUDIO_PLUGIN_SET_VOLUME_MSG:
        {
            PRINT(("CSB_DECODER: Set volume not used in this plugin\n"));
        }
        break;

        case AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG:
        {
            AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T * volume_message = (AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T *)message ;
            CsrBaReceiverAudioPluginSetVolume(volume_message);
        }
        break;

        case (AUDIO_PLUGIN_PLAY_TONE_MSG ):
        {
            /* Let tone plugin do the job */
            AUDIO_PLUGIN_PLAY_TONE_MSG_T * tone_message = (AUDIO_PLUGIN_PLAY_TONE_MSG_T *)message;
            MAKE_AUDIO_MESSAGE(AUDIO_PLUGIN_PLAY_TONE_MSG, new_message);

            memcpy(new_message, tone_message, sizeof(AUDIO_PLUGIN_PLAY_TONE_MSG_T));

            MessageSend(AudioGetTonePlugin(), AUDIO_PLUGIN_PLAY_TONE_MSG, new_message);

            /* Set audio busy here otherwise other pending tone messages will be sent */
            SetAudioBusy(AudioGetTonePlugin());
        }
        break ;

        case (AUDIO_PLUGIN_STOP_TONE_AND_PROMPT_MSG ):
        {
            MessageSend(AudioGetTonePlugin(), AUDIO_PLUGIN_STOP_TONE_AND_PROMPT_MSG, NULL);
        }
        break ;

        /* Message from VM application via audio lib to configure the mute state of the sink, this could be to either:
            mute the sink output but not subwoofer
            mute the subwoofer output but not sink
            mute both sink and subwoofer
            unmute both sink and subwoofer */
        case (AUDIO_PLUGIN_SET_SOFT_MUTE_MSG ):
        {
            AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T* mute_message = (AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T*)message;
            CsrBaReceiverAudioPluginSetSoftMute(mute_message);
        }
        break ;

        case (AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG):
        {
            AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG_T * volume_message = (AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG_T *)message ;
            CsrBaReceiverAudioPluginSetHardwareLevels(volume_message);
        }
        break;

#ifdef HOSTED_TEST_ENVIRONMENT
        case AUDIO_PLUGIN_TEST_RESET_MSG:
        {
            CsrBaReceiverAudioPluginTestReset();
        }
        break;
#endif

        default:
            break;
    }
}

/******************************************************************************/
void CsrReceiverMusicMessageHandler(Task task, MessageId id, Message message)
{
    if ( (id >= AUDIO_DOWNSTREAM_MESSAGE_BASE ) && (id < AUDIO_DOWNSTREAM_MESSAGE_TOP) )
    {
        handleAudioMessage (task , id, message );
    }
    else
    {
        handleInternalMessage (task , id , message ) ;
    }
}

