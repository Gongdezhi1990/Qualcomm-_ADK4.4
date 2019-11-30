/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    voice_prompt_file.c
 
DESCRIPTION
     Voice prompt file related functions.
*/
#include <stdio.h>
#include <string.h>

#include <source.h>
#include <file.h>

#include "print.h"

#include "voice_prompts_utils.h"
#include "voice_prompt_file.h"

#define SIZE_PROMPT_DATA   (12)

static void setPropertiesForTone(bool is_stereo, voice_prompt_t* prompt);
static Source getToneSource(const ringtone_note * tone);
static Source getVoicePromptSource(FILE_INDEX file_index);

/****************************************************************************
DESCRIPTION
    Set up prompt structure content using voice prompt header file pointed by
    file_index.
*/
void VoicePromptsFileSetProperties(FILE_INDEX file_index, voice_prompt_t* prompt)
{
    Source lSource = NULL;
    const uint8* rx_array;

    lSource = StreamFileSource(file_index);

    /* Check source created successfully */
    if(SourceSize(lSource) < SIZE_PROMPT_DATA)
    {
        /* Finished with header source, close it */
        SourceClose(lSource);
        Panic();
    }

    rx_array = SourceMap(lSource);

    prompt->stereo        = rx_array[4];
    prompt->codec_type = rx_array[9];
    prompt->playback_rate = (uint16)(((uint16)rx_array[10] << 8) | (rx_array[11]));

    if(!VoicePromptsIsCodecTypeValid(prompt->codec_type))
    {
        Panic();
    }

    /* Finished with header source, close it */
    if(!SourceClose(lSource))
    {
        Panic();
    }
}

/****************************************************************************
DESCRIPTION
    Get tone or voice prompt source and set up prompt structure.
*/
Source VoicePromptsFileGetToneOrPrompt(const vp_context_t * pData, voice_prompt_t* prompt,
        bool tones_require_source)
{
    Source audio_source;

    if(!pData || !prompt )
        return NULL;

    /* determine if this is a tone */
    if(pData->tone)
    {
        setPropertiesForTone(pData->features.stereo, prompt);
        if(tones_require_source)
        {
            audio_source = getToneSource(pData->tone);
        }
        else
        {
            audio_source = NULL;
        }
    }
    else
    {
        VoicePromptsFileSetProperties(pData->prompt_header_index, prompt);
        audio_source = getVoicePromptSource(pData->prompt_index);
    }

    PRINT(("Prompt: %X rate 0x%x stereo %lu\n", prompt->codec_type, prompt->playback_rate, (unsigned long) prompt->stereo));

    return audio_source;
}

/****************************************************************************
DESCRIPTION
    Set up prompt structure for tone.
*/
static void setPropertiesForTone(bool is_stereo, voice_prompt_t* prompt)
{
    prompt->codec_type = voice_prompts_codec_tone;
    prompt->playback_rate = 8000;
    prompt->stereo = is_stereo;
}

/****************************************************************************
DESCRIPTION
    Get tone source.
*/
static Source getToneSource(const ringtone_note * tone)
{
    PRINT(("VP: Prompt is a tone 0x%p\n", (void*)tone));

    return StreamRingtoneSource(tone);
}

/****************************************************************************
DESCRIPTION
    Get voice prompt source.
*/
static Source getVoicePromptSource(FILE_INDEX file_index)
{
    return StreamFileSource(file_index);
}
