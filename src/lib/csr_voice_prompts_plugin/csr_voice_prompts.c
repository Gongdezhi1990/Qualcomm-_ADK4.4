/****************************************************************************
Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_voice_prompts.h
DESCRIPTION
    plugin implementation which plays audio prompts
NOTES
*/

#include <stdlib.h>
#include <string.h>

#include <source.h>
#include <panic.h>

#include "audio.h"
#include "audio_plugin_voice_prompts_variants.h"
#include "print.h"
#include "csr_cvc_common_plugin.h"

#include "voice_prompts_dsp_if.h"
#include "voice_prompts_utils.h"
#include "voice_prompt_file.h"
#include "csr_voice_prompts_plugin.h"
#include "csr_voice_prompts.h"

static vp_context_t            *phrase_data = NULL;

static void DisconnectAndCloseSource(Source source);

vp_context_t *VoicePromptsGetContext(void)
{
    return phrase_data;
}

/****************************************************************************
 Business logic
 */

/****************************************************************************
DESCRIPTION
    helper function to determine whether voice prompt to be played is adpcm or pcm which
    can then be mixed by the other dsp applications.
*/
bool CsrVoicePromptsIsMixable(FILE_INDEX prompt_header_index)
{
    voice_prompt_t prompt;

    /* Can't mix if there is no dsp. Check for no_dsp */
   Task no_dsp_plugin = AudioPluginVoiceVariantsGetHfpPlugin(hfp_wbs_codec_mask_cvsd, plugin_no_dsp);
    if(AudioIsControlPlugin(no_dsp_plugin))    
    {
        return FALSE;
    }

    VoicePromptsFileSetProperties(prompt_header_index, &prompt);

    return !VoicePromptsIsCompressed(prompt.codec_type);
}



static Source setupContextBasedOnVPFile(void)
{
    Source lSource;
    voice_prompt_t prompt;

    /* Get the prompt data */
    lSource = VoicePromptsFileGetToneOrPrompt(phrase_data, &prompt, !VoicePromptsDspAreTonesGeneratedOnDsp());
    if(!lSource && !VoicePromptsDspAreTonesGeneratedOnDsp())
    {
        Panic();
    }

    /* Stash the source */
    phrase_data->source = lSource;
    phrase_data->duplicate_source = NULL; /* set only if needed below */
    phrase_data->codec_type = prompt.codec_type;
    phrase_data->stereo = prompt.stereo;
    phrase_data->playback_rate =  (prompt.playback_rate ? prompt.playback_rate : 8000);
    phrase_data->mixing = FALSE;    /* overridden later if this prompt is mixed */

    return lSource;
}


/****************************************************************************
DESCRIPTION
    plays a number phrase using the audio plugin

    CsrVoicePromptsPluginPlayPhrase() is a common interface for playing audio
	with and without DSP. 

    no_dsp_prompt_volume parameter is used for calculating the DB value from DAC gain when
	play the prompt directly without the DSP case.
*/

void CsrVoicePromptsPluginPlayPhrase (FILE_INDEX prompt_index , FILE_INDEX prompt_header_index, int16 ap_volume , AudioPluginFeatures features, Task app_task)
{
    if(phrase_data != NULL)
        Panic();

    PRINT(("VP: Play Phrase:\n"));

    /* Allocate the memory */
    phrase_data = (vp_context_t *) PanicUnlessMalloc(sizeof(vp_context_t));
    memset(phrase_data,0,sizeof(vp_context_t));

    /* Set up params */
    phrase_data->prompt_index = prompt_index;
    phrase_data->prompt_header_index = prompt_header_index;
    phrase_data->features      = features;
    phrase_data->prompt_volume = ap_volume;  /*used for prompts which are not played via tone port */
    phrase_data->tone          = NULL;  /* not a tone */
    phrase_data->app_task      = app_task;

    (void)setupContextBasedOnVPFile();

    SetAudioBusy((TaskData*) &(csr_voice_prompts_plugin));
    AudioSetAudioPromptPlayingTask((Task)&csr_voice_prompts_plugin);

    VoicePromptsDspPlay(phrase_data);
}

/****************************************************************************
DESCRIPTION
    plays a tone using the audio plugin
*/
void CsrVoicePromptsPluginPlayTone (const ringtone_note * tone, AudioPluginFeatures features)
{
    if(tone == NULL)
        Panic();

    PRINT(("VP: Play tone:\n"));

    MessageCancelAll((TaskData*) &csr_voice_prompts_plugin, MESSAGE_STREAM_DISCONNECT );
    MessageCancelAll((TaskData*) &csr_voice_prompts_plugin, MESSAGE_FROM_KALIMBA);

    /* Allocate the memory */
    phrase_data = (vp_context_t *) PanicUnlessMalloc(sizeof(vp_context_t));
    memset(phrase_data,0,sizeof(vp_context_t));

    /* Set up params */
    phrase_data->prompt_index  = 0;
    phrase_data->prompt_header_index = 0; /* not a prompt */
    phrase_data->features      = features;
    phrase_data->tone          = tone;

    (void)setupContextBasedOnVPFile();

    SetAudioBusy((TaskData*) &(csr_voice_prompts_plugin));
    AudioSetAudioPromptPlayingTask((Task)&csr_voice_prompts_plugin);

    VoicePromptsDspPlay(phrase_data);
}

/*
    Act on a MESSAGE_STREAM_DISCONNECT being received by the plugin.

    If phrase_data has already been freed then there is no further work
    required (because we caused the stream disconnect ourselves during
    cleanup).
    If the prompt was being mixed, we must wait for the MUSIC_TONE_COMPLETE
    message to be sure that the prompt has finished playing and so we ignore
    the stream disconnect.  If it wasn't being mixed, the
    MESSAGE_STREAM_DISCONNECT signals that the prompt has finished.
*/
void CsrVoicePromptsPluginHandleStreamDisconnect(void)
{
    PRINT(("VP: Handle stream disconnect\n"));

    if(VoicePromptsDspShallHandleStreamDisconnect(phrase_data))
    {
        /* Prompt has finished so tidy up */
        CsrVoicePromptsPluginStopPhrase();
    }
    /* else
     * do nothing either because we have tidied up already or because
     * CsrVoicePromptsPluginCleanup() will be called when
     * AudioBusy is cleared on receipt of a MUSIC_TONE_COMPLETE
     */
}



/****************************************************************************
DESCRIPTION
    Stop a prompt from currently playing by freeing the AudioBusy lock
    to invoke the cleanup callback

*/
void CsrVoicePromptsPluginStopPhrase ( void )
{
    if (AudioBusyTask() == &csr_voice_prompts_plugin)
    {
        VoicePromptsDspStop();
    }
}

/****************************************************************************
DESCRIPTION
    Callback called when the voice prompt plugin loses its audio busy lock
    either when CsrVoicePromptsPluginStopPhrase() voluntarily frees it or
    when some other ill-mannered task grabs or frees the lock itself.
*/
void CsrVoicePromptsPluginCleanup (void)
{
    if(!phrase_data)
        Panic();

    PRINT(("VP: Terminated\n"));

    VoicePromptsDspPrepareForClose();

    DisconnectAndCloseSource(phrase_data->source);
    DisconnectAndCloseSource(phrase_data->duplicate_source);

    VoicePromptsDspCleanup(phrase_data);

    /* Notify the application that the prompt has completed */
    if(phrase_data->app_task)
    {
        MessageSend(phrase_data->app_task, AUDIO_PROMPT_DONE, NULL);
    }

    /* Tidy up */
    free(phrase_data);
    phrase_data = NULL;

    AudioSetAudioPromptPlayingTask((Task)NULL);

    MessageCancelAll ((TaskData *) &csr_voice_prompts_plugin,
            AUDIO_PLUGIN_STOP_TONE_AND_PROMPT_MSG) ;
}

static void DisconnectAndCloseSource(Source source)
{
    if(SourceIsValid(source))
    {
        StreamDisconnect(source, NULL);
        SourceClose(source);
    }
}

#ifdef HOSTED_TEST_ENVIRONMENT
void CsrVoicePromptsPluginTestReset(void)
{
    free(phrase_data);
    phrase_data = NULL;
}
#endif
