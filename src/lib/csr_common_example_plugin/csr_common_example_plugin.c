/****************************************************************************
Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_common_example_plugin.c
DESCRIPTION
    Interface file for an audio_plugin
NOTES
*/

#include <audio.h>
#include <stdlib.h>
#include <print.h>
#include <stream.h> /*for the ringtone_note*/

#include "audio_plugin_if.h" /*the messaging interface*/
#include "csr_common_example_plugin.h"
#include "csr_common_example.h"
#include "csr_common_example_if.h"
static void message_handler (Task task, MessageId id, Message message) ;

    /*the local message handling functions*/
static void handleAudioMessage ( Task task , MessageId id, Message message );
static void handleInternalMessage ( Task task , MessageId id, Message message );

    /*the plugin task*/

const ExamplePluginTaskdata csr_cvsd_8k_1mic_plugin = {{message_handler}, CVSD_8K_1_MIC, 0, 0};

const ExamplePluginTaskdata csr_cvsd_8k_2mic_plugin = {{message_handler}, CVSD_8K_2_MIC, 1, 0};

const ExamplePluginTaskdata csr_sbc_1mic_plugin = {{message_handler}, SBC_1_MIC, 0, 0};

const ExamplePluginTaskdata csr_sbc_2mic_plugin = {{message_handler}, SBC_2_MIC, 1, 0};


/****************************************************************************
DESCRIPTION
    The main task message handler
*/
static void message_handler ( Task task, MessageId id, Message message )
{
    if ( (id >= AUDIO_DOWNSTREAM_MESSAGE_BASE ) && (id < AUDIO_DOWNSTREAM_MESSAGE_TOP) )
    {
        handleAudioMessage (task , id, message ) ;
    }
    else
    {
        handleInternalMessage (task , id , message ) ;
    }
}

/****************************************************************************
DESCRIPTION

    messages from the audio library are received here.
    and converted into function calls to be implemented in the
    plugin module
*/
static void handleAudioMessage ( Task task , MessageId id, Message message )
{
    switch (id)
    {
        case (AUDIO_PLUGIN_CONNECT_MSG ):
        {
            AUDIO_PLUGIN_CONNECT_MSG_T * connect_message = (AUDIO_PLUGIN_CONNECT_MSG_T *)message ;

            if (IsAudioBusy())
            {
                /*Queue the connect message until the audio task is available*/
                MAKE_AUDIO_MESSAGE( AUDIO_PLUGIN_CONNECT_MSG, message ) ;

                message->audio_sink = connect_message->audio_sink ;
                message->sink_type  = connect_message->sink_type ;
                message->volume     = connect_message->volume ;
                message->rate       = connect_message->rate ;
                message->mode       = connect_message->mode ;
                message->features   = connect_message->features ;
                message->params     = connect_message->params ;

                MessageSendConditionallyOnTask ( task, AUDIO_PLUGIN_CONNECT_MSG , message , AudioBusyPtr() ) ;
            }
            else
            {
                /*connect the audio*/
                CsrExamplePluginConnect(  (ExamplePluginTaskdata*)task, connect_message) ;
            }
            break ;
        }
        case (AUDIO_PLUGIN_DISCONNECT_MSG ):
            if (IsAudioBusy())
            {
                MessageSendConditionallyOnTask ( task, AUDIO_PLUGIN_DISCONNECT_MSG , 0 , AudioBusyPtr() ) ;
            }
            else
            {
                CsrExamplePluginDisconnect((ExamplePluginTaskdata*)task) ;
            }
            break ;
        case (AUDIO_PLUGIN_SET_MODE_MSG ):
        {
            AUDIO_PLUGIN_SET_MODE_MSG_T * mode_message = (AUDIO_PLUGIN_SET_MODE_MSG_T *)message ;

            if (IsAudioBusy())
            {
                MAKE_AUDIO_MESSAGE ( AUDIO_PLUGIN_SET_MODE_MSG, message) ;
                message->mode   = mode_message->mode ;
                message->params = mode_message->params ;

                MessageSendConditionallyOnTask ( task, AUDIO_PLUGIN_SET_MODE_MSG , message , AudioBusyPtr() ) ;
            }
            else
            {
                CsrExamplePluginSetMode(mode_message->mode);
            }
            break ;
        }
        case (AUDIO_PLUGIN_SET_VOLUME_MSG ):
        {
            AUDIO_PLUGIN_SET_VOLUME_MSG_T * volume_message = (AUDIO_PLUGIN_SET_VOLUME_MSG_T *)message ;

            if (IsAudioBusy())
            {
                 MAKE_AUDIO_MESSAGE (AUDIO_PLUGIN_SET_VOLUME_MSG, message ) ;
                 message->volume = volume_message->volume ;

                 MessageSendConditionallyOnTask ( task, AUDIO_PLUGIN_SET_VOLUME_MSG , message , AudioBusyPtr() ) ;
            }
            else
            {
                CsrExamplePluginSetVolume(volume_message->volume);
            }
            break ;
        }

        case (AUDIO_PLUGIN_SET_SOFT_MUTE_MSG):
        {
            AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T* mute_message = (AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T*)message;

            if(IsAudioBusy())
            {
                MAKE_AUDIO_MESSAGE( AUDIO_PLUGIN_SET_SOFT_MUTE_MSG, message );
                message->mute_states = mute_message->mute_states;

                MessageSendConditionallyOnTask(task, AUDIO_PLUGIN_SET_SOFT_MUTE_MSG, message, AudioBusyPtr());
            }
            else
            {
                CsrExamplePluginSetSoftMute(mute_message);
            }
        }
        break;

        case (AUDIO_PLUGIN_PLAY_TONE_MSG ):
        {
            AUDIO_PLUGIN_PLAY_TONE_MSG_T * tone_message = (AUDIO_PLUGIN_PLAY_TONE_MSG_T *)message ;

            if (IsAudioBusy())
            {
                if ( tone_message->can_queue) /*then re-queue the tone*/
                {
                    MAKE_AUDIO_MESSAGE( AUDIO_PLUGIN_PLAY_TONE_MSG, message ) ;

                    message->tone        = tone_message->tone       ;
                    message->can_queue   = tone_message->can_queue  ;
                    message->tone_volume = tone_message->tone_volume;
                    message->features    = tone_message->features   ;

                    PRINT(("TONE:Q\n"));

                    MessageSendConditionallyOnTask ( task , AUDIO_PLUGIN_PLAY_TONE_MSG, message , AudioBusyPtr() ) ;
                }
            }
            else
            {
                PRINT(("TONE:start\n"));
                SetAudioBusy((TaskData*) task);
                CsrExamplePluginPlayTone ((ExamplePluginTaskdata*)task, tone_message) ;
            }
            break ;
        }
        case (AUDIO_PLUGIN_STOP_TONE_AND_PROMPT_MSG ):
            if (IsAudioBusy())
            {
                    CsrExamplePluginStopTone() ;
            }
            break ;
        default:
            break ;
    }
}

/****************************************************************************
DESCRIPTION
    Internal messages to the task are handled here
*/
static void handleInternalMessage ( Task task , MessageId id, Message message )
{
    switch (id)
    {
        case MESSAGE_STREAM_DISCONNECT: /*a tone has completed*/
            PRINT(("CSR_COMMON_EXAMPLE: Tone End\n"));
            SetAudioBusy(NULL) ;

            CsrExamplePluginToneComplete((ExamplePluginTaskdata*)task) ;
            break ;
        default:
            /*route the cvc messages to the relavent handler*/
            CsrExamplePluginInternalMessage((ExamplePluginTaskdata*)task , id , message ) ;
            break ;
    }
}
