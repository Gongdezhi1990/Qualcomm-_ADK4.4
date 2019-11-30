/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_broadcast_audio_plugin.c
DESCRIPTION
    Interface file for broadcast audio_plugin
NOTES
*/

#include <audio.h>
#include <stdlib.h>
#include <print.h>
#include <stream.h> /*for the ringtone_note*/
#include <string.h>

#include "audio_plugin_if.h" /*the messaging interface*/
#include "audio_plugin_music_variants.h"
#include "csr_broadcast_audio_plugin.h"
#include "csr_broadcast_audio.h"
#include "csr_broadcast_audio_if.h"
#include "scm.h"

const A2dpPluginTaskdata csr_ba_sbc_decoder_plugin = {{BaPluginMusicMessageHandler}, SBC_DECODER, BITFIELD_CAST(8, 0)};
const A2dpPluginTaskdata csr_ba_aac_decoder_plugin = {{BaPluginMusicMessageHandler}, AAC_DECODER, BITFIELD_CAST(8, 0)};
const A2dpPluginTaskdata csr_ba_analogue_decoder_plugin = {{BaPluginMusicMessageHandler}, SBC_DECODER, BITFIELD_CAST(8, 0)};
const A2dpPluginTaskdata csr_ba_usb_decoder_plugin = {{BaPluginMusicMessageHandler}, SBC_DECODER, BITFIELD_CAST(8, 0)};

    /*the local message handling functions*/
static void handleAudioMessage ( Task task , MessageId id, Message message );
static void handleInternalMessage ( Task task , MessageId id, Message message );
static void handleScmTransportMessage( Task task , MessageId id, Message message );

/****************************************************************************
DESCRIPTION
    The main task message handler
*/
void BaPluginMusicMessageHandler ( Task task, MessageId id, Message message )
{
    if ( (id >= AUDIO_DOWNSTREAM_MESSAGE_BASE ) && (id < AUDIO_DOWNSTREAM_MESSAGE_TOP) )
    {
        handleAudioMessage (task , id, message ) ;
    }
    else if( (id >= SCM_MESSAGE_BASE ) && (id < SCM_MESSAGE_TOP) )
    {
        handleScmTransportMessage(task, id, message);
    }
    else
    {
        handleInternalMessage (task , id , message ) ;
    }
}

/****************************************************************************
DESCRIPTION

    messages from the SCM library are received here.
*/
static void handleScmTransportMessage ( Task task , MessageId id, Message message )
{
    switch (id)
    {
        case SCM_BROADCAST_TRANSPORT_REGISTER_REQ:
        {
            PRINT(("Plugin: SCM_BROADCAST_TRANSPORT_REGISTER_REQ\n"));
            CsrBroadcastAudioScmTransportRegisterReq(task);
        }
        break;

        case SCM_BROADCAST_TRANSPORT_UNREGISTER_REQ:
        {
            PRINT(("Plugin: SCM_BROADCAST_TRANSPORT_UNREGISTER_REQ\n"));
            CsrBroadcastAudioScmTransportUnRegisterReq();
        }
        break;

        case SCM_BROADCAST_SEGMENT_REQ:
        {
            PRINT(("Plugin: SCM_BROADCAST_SEGMENT_REQ\n"));
            CsrBroadcastAudioScmSeqmentReq((SCM_BROADCAST_SEGMENT_REQ_T*)message);
        }
        break;

        default:
            break;
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
            CsrBroadcastAudioPluginConnect(  (A2dpPluginTaskdata*)task, connect_message);
        }
        break ;

        case (AUDIO_PLUGIN_DISCONNECT_MSG ):
        {
            CsrBroadcastAudioPluginPluginStartDisconnect(task);
        }
        break;

        case (AUDIO_PLUGIN_DISCONNECT_DELAYED_MSG):
        {
            CsrBroadcastAudioPluginDisconnect() ;
        }
        break ;

        case (AUDIO_PLUGIN_SET_MODE_MSG ):
        {
            AUDIO_PLUGIN_SET_MODE_MSG_T * mode_message = (AUDIO_PLUGIN_SET_MODE_MSG_T *)message ;
            CsrBroadcastAudioPluginSetMode(mode_message->mode , mode_message->params);

        }
        break ;

        case (AUDIO_PLUGIN_SET_VOLUME_MSG ):
        {
            PRINT(("BA_DECODER: Set volume not used in this plugin\n"));
        }
        break ;

        case (AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG ):
        {
            AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T * volume_message = (AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T *)message ;
            CsrBroadcastAudioPluginSetVolume (volume_message) ;
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
            CsrBroadcastAudioPluginSetSoftMute(mute_message);
            PRINT(("BA_DECODER: AUDIO_PLUGIN_SET_SOFT_MUTE_MSG mute state: %d\n", mute_message->mute_states));
        }
        break ;

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

        case (AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG):
        {
            AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG_T * volume_message = (AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG_T *)message ;
            CsrBroadcastAudioPluginSetHardwareLevels(volume_message);
        }
        break;

#ifdef HOSTED_TEST_ENVIRONMENT
        case AUDIO_PLUGIN_TEST_RESET_MSG :
        {
            CsrBroadcastAudioPluginTestReset();
        }
        break;
#endif

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
            PRINT(("BA_DECODER: Tone End\n"));
            break ;

        default:
        {
            /*route the BA messages to the relavent handler*/
            CsrBroadcastAudioPluginInternalMessage((A2dpPluginTaskdata*)task , id , message ) ;
        }
        break ;
    }
}

