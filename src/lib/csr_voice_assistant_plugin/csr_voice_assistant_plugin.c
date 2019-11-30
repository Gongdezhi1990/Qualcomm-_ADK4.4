/****************************************************************************
Copyright (c) 2005 - 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_voice_assistant_plugin.c
DESCRIPTION
    an Voice assistant audio plugin
NOTES
*/

#include <stdlib.h>

#include "print.h"

#include "audio.h"
#include "audio_plugin_if.h" /*the messaging interface*/
#include "csr_voice_assistant_plugin.h"
#include "csr_voice_assistant.h"
#include "voice_assistant_dsp_if.h"


/*the task message handler*/
static void AudioPluginVaMessagehandler (Task task, MessageId id, Message message);

/*the local message handling functions*/
static void AudioPluginVaAudioMessageHandler (Task task , MessageId id, Message message);
    
/*the plugin task*/
const TaskData voice_assistant_plugin = { AudioPluginVaMessagehandler };

/****************************************************************************
DESCRIPTION
    The main task message handler
*/
static void AudioPluginVaMessagehandler ( Task task, MessageId id, Message message ) 
{
    PRINT(("AudioPluginVaMessagehandler\n"));
    if ( (id >= AUDIO_DOWNSTREAM_MESSAGE_BASE ) && (id < AUDIO_DOWNSTREAM_MESSAGE_TOP) )
    {
        AudioPluginVaAudioMessageHandler (task , id, message ) ;
    }
    else if (id == MESSAGE_FROM_KALIMBA)
    {
        AudioPluginVaDspMessageHandler( task , message) ;
    }

}    

/****************************************************************************
DESCRIPTION

    messages from the audio library are received here. 
    and converted into function calls to be implemented in the 
    plugin module
*/ 
static void AudioPluginVaAudioMessageHandler ( Task task , MessageId id, Message message )     
{
    UNUSED(task);
    PRINT(("AudioPluginVaAudioMessageHandler\n"));
    
    switch (id)
    {        
        case AUDIO_PLUGIN_START_VOICE_CAPTURE_MSG:
             VoiceAssistantPluginStartCapture ((AUDIO_PLUGIN_START_VOICE_CAPTURE_MSG_T*)message);
             break;
             
        case AUDIO_PLUGIN_STOP_VOICE_CAPTURE_MSG:
            /* VA plugin is still loading, Wait till it completely loads */
            if((AudioBusyTask()== &voice_assistant_plugin) && (GetCurrentDspStatus() == DSP_LOADING))
            {
               MessageSendConditionallyOnTask(task, AUDIO_PLUGIN_STOP_VOICE_CAPTURE_MSG, NULL, AudioBusyPtr());
            }
            else
            {
               VoiceAssistantPluginStopCapture ();
            }
            break;
            
        default:
            PRINT(("VA_Plugin: Unknown message in plugin\n"));
            Panic();
            break;
    }
}



