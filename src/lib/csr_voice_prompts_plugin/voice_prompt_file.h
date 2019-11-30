/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    voice_prompt_file.h
 
DESCRIPTION
    Voice prompt file related functions.
*/

#ifndef LIBS_CSR_VOICE_PROMPTS_PLUGIN_VOICE_PROMPT_FILE_H_
#define LIBS_CSR_VOICE_PROMPTS_PLUGIN_VOICE_PROMPT_FILE_H_

#include <csrtypes.h>
#include "audio_plugin_if.h"
#include "voice_prompts_defs.h"

typedef struct
{
    voice_prompts_codec_t codec_type;
    uint16              playback_rate;
    bool                stereo;
} voice_prompt_t;

/****************************************************************************
DESCRIPTION
    Set up prompt structure content using voice prompt header file pointed by
    file_index.
*/
void VoicePromptsFileSetProperties(FILE_INDEX file_index, voice_prompt_t* prompt);

/****************************************************************************
DESCRIPTION
    Get tone or voice prompt source and set up prompt structure.
*/
Source VoicePromptsFileGetToneOrPrompt(const vp_context_t *context, voice_prompt_t* prompt,
        bool tones_require_source);

#endif /* LIBS_CSR_VOICE_PROMPTS_PLUGIN_VOICE_PROMPT_FILE_H_ */
