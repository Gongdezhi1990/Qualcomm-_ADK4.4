/****************************************************************************
Copyright (c) 2005 - 2017 Qualcomm Technologies International, Ltd.


FILE NAME
    csr_voice_assistant.c
DESCRIPTION
    plugin implementation for voice assistant
NOTES
*/

#include <stdlib.h>
#include <string.h>

#include <source.h>
#include <panic.h>

#include "audio.h"
#include "audio_config.h"
#include "csr_voice_assistant.h"
#include "audio_plugin_voice_assistant_variants.h"
#include "voice_assistant_dsp_if.h"
#include "print.h"


static va_context_t *voice_assistant_data = NULL;

static void voiceAssistantCreateContext(void);
static void voiceAssistantCleanUpContext(void);

/****************************************************************************
DESCRIPTION
   retrieve the context from Voice Assistant
*/
va_context_t *VoiceAssistantGetContext(void)
{
    return voice_assistant_data;
}

/****************************************************************************
DESCRIPTION
    Create the context for voice assistant
*/
static void voiceAssistantCreateContext(void){

    PRINT(("VoiceAssistantCreatContext\n"));
    
    /* Not expected to have allocated before*/
    PanicNotNull(voice_assistant_data);

    /* Allocate the memory */
    voice_assistant_data =(va_context_t *)PanicNull(calloc(1, sizeof(va_context_t)));

}


/****************************************************************************
DESCRIPTION
    Create the context for voice assistant
*/
static void voiceAssistantCleanUpContext(void){

    PRINT(("VoiceAssistantCleanUpContext\n"));

    if(voice_assistant_data)
    {
        /* Cleanup the memory */
        free(voice_assistant_data);
        voice_assistant_data = NULL;
    }
}


/****************************************************************************
DESCRIPTION
    Starts the voice capture used for Voice Assistance.
    This is the common place to configure the voice capture for VA
    with/without DSP loaded.
*/

void VoiceAssistantPluginStartCapture(AUDIO_PLUGIN_START_VOICE_CAPTURE_MSG_T *msg)
{

    PRINT(("VoiceAssistantPluginStartCapture\n"));

    /* Create the VA context*/
     voiceAssistantCreateContext();

    /*Load the App task*/
    voice_assistant_data->app_task = msg->app_task;
    
    /* Should we inform the audio lib about the plugin in use ??*/
    /* Call the DSP interface now */
    VoiceAssistantDspStart();
}

/****************************************************************************
DESCRIPTION
    Stops the voice capture used for Voice Assistance.
*/

void VoiceAssistantPluginStopCapture(void)
{
    PRINT(("VoiceAssistantPluginStopCapture\n"));

    if(VoiceAssistantGetContext())
    {
        /* Call the DSP interface now */
        VoiceAssistantDspStop();

        /* Cleanup the context */
        voiceAssistantCleanUpContext();
    }
}


