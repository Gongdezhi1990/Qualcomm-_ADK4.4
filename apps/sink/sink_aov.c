/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    sink_aov.c

DESCRIPTION
    Sink module to support Always-on-Voice (AoV) functionality.

*/
/*!
@file   sink_aov.c
@brief  Sink module to support Always-on-Voice (AoV) functionality.
*/
#include <csrtypes.h>
#include <stdio.h>
#include <string.h>
#include <file.h>
#include <audio.h>
#include <power.h>
#include <audio_plugin_voice_prompts_variants.h>
#include <audio_plugin_voice_variants.h>

#include "sink_aov.h"
#include "sink_configmanager.h"
#include "sink_debug.h"
#include "sink_malloc_debug.h"
#include "sink_audio_routing.h"
#include "sink_tones.h"
#include "sink_main_task.h"

#ifdef ENABLE_AOV
#include "sink_aov_config_def.h"


#ifdef DEBUG_AOV
    #define AOV_DEBUG(x) DEBUG(x)
#else
    #define AOV_DEBUG(x) 
#endif

typedef struct
{
    uint16 enable_count;
    int16 number_of_trigger_phrases;
    audio_instance_t instance;
    bool response_pending;
} aov_info_t;

typedef struct __sink_aov_data_t
{
    bool enabled;
    int16 phrase_index;
    uint16 graph_timeout_ms;
}sink_aov_data_t;


static sink_aov_data_t gAovData;

#define AOV gAovData

#define AOV_FIRST_FILE_INDEX     0

#define MS_PER_SECOND            1000

static void sinkAovMessageHandler(Task task, MessageId id, Message message);
static void handleAoVMessageEnabled(AOV_PLUGIN_AOV_ENABLED_MSG_T* message);

static aov_info_t aov_info = {0, 0, NULL, FALSE};
const TaskData sink_aov_task = {sinkAovMessageHandler};

/*******************************************************************************
NAME
    sinkAovGetSessionData

DESCRIPTION
    Get the AoV writeable in the application config.

RETURNS
    Nothing.
*/
static void sinkAovGetSessionData(void)
{
    sink_aov_writeable_config_def_t *write_data = NULL;

    configManagerGetReadOnlyConfig(SINK_AOV_WRITEABLE_CONFIG_BLK_ID, (const void **)&write_data);

    /* Extract session data */
    AOV.enabled = write_data->aov_enabled;
    AOV.phrase_index = write_data->aov_phrase_index;
    AOV.graph_timeout_ms = write_data->graph_timeout * MS_PER_SECOND;

    configManagerReleaseConfig(SINK_AOV_WRITEABLE_CONFIG_BLK_ID);
}

/*******************************************************************************
NAME
    sinkAovSetSessionData

DESCRIPTION
    Set the AoV writeable data in the application config.

RETURNS
    Nothing.
*/
static void sinkAovSetSessionData(int16 phrase_index)
{
    sink_aov_writeable_config_def_t *write_data = NULL;

    if(configManagerGetWriteableConfig(SINK_AOV_WRITEABLE_CONFIG_BLK_ID, (void **)&write_data, 0))
    {
        AOV_DEBUG(("Persisting AOV phrase file index %d\n", phrase_index));
        write_data->aov_phrase_index =  phrase_index;
    }

    configManagerUpdateWriteableConfig(SINK_AOV_WRITEABLE_CONFIG_BLK_ID);
}

/*******************************************************************************
NAME
    getAovIsEnabled

DESCRIPTION
    Check if AoV is enabled in the application config.

RETURNS
    bool TRUE if AoV is enabled, FALSE otherwise.
*/
static bool getAovIsEnabled(void)
{
    return AOV.enabled;
}

/*******************************************************************************
NAME
    sinkAovGetPromptFileIndexes

DESCRIPTION
    Get the prompt and header file indexes for the AoV prompts.

RETURNS
    FILE_INDEX for the prompt file and header file.
*/
static void sinkAovGetPromptFileIndexes(int16 prompt_index, FILE_INDEX *prompt_file_index, FILE_INDEX *prompt_header_file_index)
{
    char filename[31];

    sprintf(filename, "aov/prompts/%d.prm", prompt_index);
    *prompt_file_index = FileFind(FILE_ROOT, filename, (uint16)strlen(filename));

    sprintf(filename, "aov/headers/%d.idx", prompt_index);
    *prompt_header_file_index = FileFind(FILE_ROOT, filename, (uint16)strlen(filename));
}

/*******************************************************************************
NAME
    sinkAovGetPhraseFileIndex

DESCRIPTION
    Get the phrase file index.

RETURNS
    FILE_INDEX for the phrase file.
*/
static FILE_INDEX sinkAovGetPhraseFileIndex(int16 phrase_index)
{
    char filename[31];

    if (phrase_index == AOV_OFF)
    {
        return FILE_NONE;
    }
    else
    {
        sprintf(filename, "aov/phrase_files/tfd_%d.bin", phrase_index);
        return FileFind(FILE_ROOT, filename, (uint16)strlen(filename));
    }
}

/*******************************************************************************
NAME
    sinkAovPlayPhrasePrompt

DESCRIPTION
    Play the prompt associated with the phrase file.

RETURNS
    Nothing
*/
static void sinkAovPlayPhrasePrompt(int16 prompt_index)
{
    FILE_INDEX prompt_file_index = FILE_NONE;
    FILE_INDEX prompt_file_header_file_index = FILE_NONE;
    TaskData * task = NULL;

    if (prompt_index == AOV_OFF)
    {
        MessageSend(sinkGetMainTask(), EventSysVoiceRecognitionDisabled, NULL);
    }
    else
    {

        task = (TaskData *) &csr_voice_prompts_plugin;

        sinkAovGetPromptFileIndexes(prompt_index, &prompt_file_index, &prompt_file_header_file_index);

        /* turn on audio amp */
        enableAudioActivePio();

        AudioPlayAudioPrompt(task, prompt_file_index, prompt_file_header_file_index, TRUE,
                            (int16)TonesGetToneVolume(),  sinkAudioGetPluginFeatures(), FALSE, sinkGetMainTask());

        /* turn amp off if audio is inactive */
        disableAudioActivePioWhenAudioNotBusy();

    }

}

/*******************************************************************************
NAME
    sinkAovLoadPhrase

DESCRIPTION
    Load the phrase file to be used by the AoV library

RETURNS
    Nothing
*/
static void sinkAovLoadPhrase(int16 phrase_index)
{
    MAKE_AUDIO_MESSAGE(AUDIO_PLUGIN_CHANGE_TRIGGER_PHRASE_MSG, message);

    message->trigger_phrase_data_file = sinkAovGetPhraseFileIndex(phrase_index);

    MessageSend((Task)&aov_plugin, AUDIO_PLUGIN_CHANGE_TRIGGER_PHRASE_MSG, message);
}

/*******************************************************************************
NAME
    sinkAovMessageHandler

DESCRIPTION
    Message handler for the AoV module

RETURNS
    Nothing
*/
static void sinkAovMessageHandler(Task task, MessageId id, Message message)
{
    UNUSED(task);
    UNUSED(message);

    switch(id)
    {
        case AOV_MESSAGE_TRIGGERED:
            AOV_DEBUG(("AOV: SVA Triggered\n"));
            MessageSend(sinkGetMainTask(), EventUsrInitateVoiceRecognition, NULL);
            aov_info.response_pending = TRUE;
            break;

        case AOV_MESSAGE_RESET_TIMEOUT:
            AOV_DEBUG(("AOV: Reset Timeout Triggered\n"));
            MessageSend(sinkGetMainTask(), EventSysVoiceRecognitionRequestTimeout, NULL);
            aov_info.response_pending = FALSE;
            break;

        case AOV_MESSAGE_AOV_ENABLED:
            handleAoVMessageEnabled((AOV_PLUGIN_AOV_ENABLED_MSG_T*)message);
            break;

        default:
            AOV_DEBUG(("AOV: Unknown message from plugin\n"));
            break;
    }
}

/*******************************************************************************
NAME
    handleAoVMessageEnabled

DESCRIPTION
    Message handler for the AoV enabled message

RETURNS
    Nothing
*/
static void handleAoVMessageEnabled(AOV_PLUGIN_AOV_ENABLED_MSG_T* message)
{
    PanicNull(message);

    if(aov_info.response_pending)
    {
        if(message->enabled == FALSE)
        {
            MessageSend(sinkGetMainTask(), EventSysVoiceRecognitionActive, NULL);
        }
        aov_info.response_pending = FALSE;
    }
}

/*******************************************************************************
NAME
    sinkAovgetNumberOfTriggerPhrases

DESCRIPTION
    Get the number of trigger phrases in the file system

RETURNS
    uint16 Number of trigger phrase files
*/
static int16 sinkAovgetNumberOfTriggerPhrases(void)
{
    char filename[31];
    int16 fileIndex = 0;

    sprintf(filename, "aov/phrase_files/tfd_%d.bin", fileIndex);

    while (FileFind(FILE_ROOT, filename, (uint16)strlen(filename)) != FILE_NONE)
    {
        fileIndex++;
        sprintf(filename, "aov/phrase_files/tfd_%d.bin", fileIndex);
    }

    AOV_DEBUG(("Number of Files is %d", fileIndex))

    return fileIndex;
}

/*****************************************************************************/
void sinkAovActivate(bool activate)
{
    AOV_DEBUG(("AOV: sinkAovActivate %d\n", (unsigned)activate));

    /* Ignore any enable/disable commands if the module is not enabled in the
       app config. */
    if (!getAovIsEnabled())
        return;

    if (activate)
    {
        aov_info.enable_count++;
        if (aov_info.enable_count == 1)
        {
            AudioPluginFeatures features;

            AOV_DEBUG(("AOV: Connect AoV plugin\n"));

            memset(&features, 0, sizeof(features));

            aov_connect_params_t* aov_params = PanicUnlessMalloc(sizeof(aov_connect_params_t));

            sinkAudioGetCommonMicParams(&aov_params->mic_params);

            aov_params->trigger_phrase_data_file = sinkAovGetPhraseFileIndex(AOV.phrase_index);

            aov_params->graph_timeout_ms = AOV.graph_timeout_ms;

            aov_info.instance = AudioConnect((Task)&aov_plugin,
                                        NULL/*audio_sink*/,
                                        AUDIO_SINK_SIDE_GRAPH/*sink_type*/,
                                        0/*volume*/,
                                        0/*rate*/,
                                        features/*features*/,
                                        AUDIO_MODE_STANDBY/*mode*/,
                                        AUDIO_ROUTE_INTERNAL/*route*/,
                                        POWER_BATT_CRITICAL/*power*/,
                                        aov_params,
                                        (Task)&sink_aov_task/*app_task*/);
        }
    }
    else
    {
        if (aov_info.enable_count > 0)
        {
            aov_info.enable_count--;
            if (aov_info.enable_count == 0)
            {
                AOV_DEBUG(("AOV: Disconnect AoV plugin\n"));

                PanicNull(aov_info.instance);

                AudioDisconnectInstance(aov_info.instance);
                aov_info.instance = NULL;
            }
        }
    }
}

/*****************************************************************************/
void sinkAovInit(void)
{
    aov_info.number_of_trigger_phrases = sinkAovgetNumberOfTriggerPhrases();
    sinkAovGetSessionData();

    if (AOV.phrase_index >= aov_info.number_of_trigger_phrases)
    {
        if (aov_info.number_of_trigger_phrases > 0)
        {
            sinkAovSetSessionData(AOV_FIRST_FILE_INDEX);
        }
        else
        {
            sinkAovSetSessionData(AOV_OFF);
        }
    }

    sinkAovGetSessionData();

}

/*****************************************************************************/

void sinkAovCyclePhrase(void)
{
    int16 cycle_index;

    if(sinkAovGetPhraseIndex(&cycle_index))
    {
        cycle_index++;

        if (cycle_index >= aov_info.number_of_trigger_phrases)
            cycle_index = AOV_OFF;

        sinkAovSetPhraseIndex(cycle_index);
    }
}

/*******************************************************************************
NAME
    sinkAovSetPhraseIndex

DESCRIPTION
    Update the trigger phrase index we're using

RETURNS
    aov_set_trigger_response
*/
aov_set_phrase_response sinkAovSetPhraseIndex(int16 phrase_index)
{
    if (getAovIsEnabled())
    {
        if((phrase_index < aov_info.number_of_trigger_phrases) 
            && (phrase_index >= AOV_OFF))
        {
            AOV.phrase_index = phrase_index;
            sinkAovLoadPhrase(phrase_index);
            sinkAovPlayPhrasePrompt(phrase_index);
            sinkAovSetSessionData(phrase_index);
            return aov_set_phrase_response_success;
        }
        return aov_set_phrase_response_invalid;
    }
    return aov_set_phrase_response_not_avail;
}

/*******************************************************************************
NAME
    sinkAovGetPhraseIndex

DESCRIPTION
    Get the trigger phrase index we're using

RETURNS
    Nothing.
*/
bool sinkAovGetPhraseIndex(int16 *index)
{
    if(getAovIsEnabled())
    {
        *index = AOV.phrase_index;
        return TRUE;
    }
    return FALSE;
}

#endif /* ENABLE_AOV */
