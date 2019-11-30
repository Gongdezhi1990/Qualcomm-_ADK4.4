/****************************************************************************
Copyright (c) 2016 - 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    csr_cvc_common_io_if.c
 
DESCRIPTION
    Microphone and outputs (e.g. DAC) related functions.
*/
#include <string.h>

#include <audio_plugin_common.h>
#include <vmal.h>
#include <print.h>

#include "csr_cvc_common_ctx.h"
#include "csr_cvc_common_dsp_if.h"
#include "csr_cvc_common_io_if.h"

/* Macro to get disabled outpus (all but left and right primary for standard CVC) */
#define CVC_DISABLED_OUTPUTS ((unsigned)~(AudioOutputGetMask(audio_output_primary_left) | AudioOutputGetMask(audio_output_primary_right)))

/*******************************************************************************
DESCRIPTION
    Set up multi-channel parameters as required by CVC. This will configure
    parameters to connect only the primary left output and disable re-sampling
    if the DSP is not being used, otherwise it will connect the primary left and
    primary right outputs.
*/
void CsrCvcIoSetupMicParams(audio_output_params_t* params, bool no_dsp)
{
    CVC_t *CVC = CsrCvcGetCtx();
    memset(params, 0, sizeof(audio_output_params_t));

    if(no_dsp)
    {
        /* Set sample rate. Can't re-sample if DSP is not being used */
        params->sample_rate  = CVC->incoming_rate;
        params->disable_resample = TRUE;
    }
    else
    {
        params->sample_rate  = CVC->incoming_rate;
    }
}

/*******************************************************************************
DESCRIPTION
    Set mic gain
*/
void CsrCvcIoSetMicGain(audio_mic_params audio_mic, audio_channel channel, T_mic_gain gain)
{
    bool digital = audio_mic.is_digital;
    Source mic_source = AudioPluginGetMicSource(audio_mic, channel);
    uint8 mic_gain = (digital ? gain.digital_gain : gain.analogue_gain);
    AudioPluginSetMicGain(mic_source, digital, mic_gain, gain.preamp_enable);
}

void CsrCvcIoMuteMic(bool is_mic_two_present)
{
    CVC_t *CVC = CsrCvcGetCtx();
    /* set gain to 0 */
    T_mic_gain input_gain;
    memset(&input_gain,0,sizeof(T_mic_gain));

    /* Set input gain(s) */
    CsrCvcIoSetMicGain(CVC->voice_mic_params->mic_a, AUDIO_CHANNEL_A, input_gain);
    if(is_mic_two_present)
        CsrCvcIoSetMicGain(CVC->voice_mic_params->mic_b, AUDIO_CHANNEL_B, input_gain);
}

/*******************************************************************************
DESCRIPTION
    Connect an ADC or digital microphone input to the DSP
*/
void CsrCvcIoConnectMic(const audio_channel channel, const audio_mic_params * const params)
{
    CVC_t *CVC = CsrCvcGetCtx();
    audio_output_params_t mch_params;

    CsrCvcIoSetupMicParams(&mch_params, CVC->no_dsp);

    if(CVC->no_dsp)
    {
        Source mic_source = AudioPluginMicSetup(channel, *params, mch_params.sample_rate);
        PanicNull(StreamConnect(mic_source, CVC->audio_sink));
    }
    else
    {
        Source mic_source = AudioPluginMicSetup(channel, *params, AudioOutputGetSampleRate(&mch_params, CVC_DISABLED_OUTPUTS));
        csrCvcCommonDspConnectMicrophones(mic_source, NULL);
    }
}

/*******************************************************************************
DESCRIPTION
    Disonnect an ADC or digital microphone input from the DSP
*/
void CsrCvcIoDisconnectMic(const audio_channel channel, const audio_mic_params * const params)
{
    Source mic_source = AudioPluginGetMicSource(*params, channel);
    PRINT(("CVC: NODSP: Disconnect Mic\n")) ;

    StreamDisconnect(mic_source, NULL);

    SourceClose(mic_source);
}

/*******************************************************************************
DESCRIPTION
    Get the audio channel (A or B) used for a particular microphone
*/
audio_channel CsrCvcIoGetAudioChannelFromMicId(const microphone_input_id_t mic_id)
{
    return ((mic_id == microphone_input_id_voice_b) ? AUDIO_CHANNEL_B : AUDIO_CHANNEL_A);
}

/*******************************************************************************
DESCRIPTION
    Connect (e)SCO with CVC processing disabled. This may be either no DSP mode
    when the (e)SCO is connected directly to the primary left speaker OR it may
    be passthrough mode where CVC is loaded and processing disabled.
*/
void CsrCvcIoConnectOutputNoCvc(void)
{
    CVC_t *CVC = CsrCvcGetCtx();
    audio_output_params_t params;

    /* Don't try to reconnect if sink has closed (e.g. audio transferred to
    the phone while tone playing). */
    if(!SinkIsValid(CVC->audio_sink))
    {
        return;
    }

    PRINT(("CVC: NODSP: Connect Output\n")) ;

    CsrCvcIoSetupMicParams(&params, CVC->no_dsp);

    if(CVC->no_dsp)
    {
        AudioOutputAddSourceOrPanic(CVC->audio_source, CVC->output_for_no_cvc);
        AudioOutputConnectOrPanic(&params);
    }
    else
    {
        csrCvcCommonDspConnectMonoSpeaker(CVC->output_for_no_cvc);

        AudioOutputConnectOrPanic(&params);
        /* AudioOutputConnect will pass back params.sample_rate adjusted if necessary */

        csrCvcCommonDspConfigureHardware(params.sample_rate, params.sample_rate,
                                         rate_matching_software,
                                         AudioOutputI2sActive() ?  hardware_type_i2s : hardware_type_dac);
    }
    CsrCvcPluginSetVolume(CsrCvcGetVolume());
}

/*******************************************************************************
DESCRIPTION
    Disconnect speakers with CVC processing disabled.
*/
void CsrCvcIoDisconnectOutputNoCvc ( void )
{
    PRINT(("CVC: NODSP: Disconnect Speaker\n")) ;

    /* Possible to have a race between remote close of the link and app disconnecting
       audio. Audio may already be disconnected so ignore return value */
    (void)AudioOutputDisconnect();

    /* Clear message task for the audio sink */
    VmalMessageSinkTask( AudioOutputGetAudioSink(), NULL );
}
