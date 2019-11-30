/*******************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    anc_configure.c

DESCRIPTION
    Functions required to configure ANC Sinks/Sources.
*/

#include "anc_configure.h"
#include "anc.h"
#include "anc_data.h"
#include "anc_debug.h"
#include "anc_gain.h"

#include <source.h>
#include <sink.h>
#include <stream.h>
#include <codec_.h>

/* The MSB of the digital gain word is set to 1, fine mode is enabled. */
#define FINE_MODE_DIGITAL_GAIN 0x8000

/* Raw Input Gain value which does not alter the set analog and digital gain
    Higher 16 bits corresponds to Analog, Lower 16 Bits corresponds to Digital Gains
*/
#define ANALOGUE_COMPONENT_MASK		(0xFFFF0000UL)
#define DIGITAL_COMPONENT_MASK		(0x0000FFFFUL)

/* Minimum fine mode digital gain which corresponds to -30.103dB */
#define DIGITAL_GAIN_MIN 0x8001

/* Maximum fine mode digital gain which corresponds to 24.0654dB */
#define DIGITAL_GAIN_MAX 0x81FF

/* Fix the audio sample size to 16bits */
#define BIT_DEPTH 16

/* Defines for the bits that refer to a specific audio channel */
#define ANC_CHANNEL_MASK_A 0x01
#define ANC_CHANNEL_MASK_B 0x02

/* Bit shift values for the different audio instances */
#define ANC_CHANNEL_MASK_INSTANCE_0_SHIFT 0
#define ANC_CHANNEL_MASK_INSTANCE_1_SHIFT 2
#define ANC_CHANNEL_MASK_INSTANCE_2_SHIFT 4

/******************************************************************************
NAME
    ancGetChannelMask

DESCRIPTION
    Helper function to return a specific channel mask based on the requested
    audio channel and the configured ANC microphone audio instance.

RETURNS
    Channel mask bitmask that is defined by the audio channel and the audio
    instance as follows:

    instance:     |   0   |   1   |   2   |
    channel:      | A | B | A | B | A | B |

    bitmask:      | 0 | 1 | 2 | 3 | 4 | 5 |
*/
static uint16 getChannelMask(audio_channel channel, audio_mic_params mic)
{
    uint16 mask = (channel == AUDIO_CHANNEL_A) ? ANC_CHANNEL_MASK_A : ANC_CHANNEL_MASK_B;

    /* The channel mask depends on the audio instance of the mic being used */
    if (mic.instance == AUDIO_INSTANCE_0)
        mask <<= ANC_CHANNEL_MASK_INSTANCE_0_SHIFT;
    else if (mic.instance == AUDIO_INSTANCE_1)
        mask <<= ANC_CHANNEL_MASK_INSTANCE_1_SHIFT;
    else if (mic.instance == AUDIO_INSTANCE_2)
        mask <<= ANC_CHANNEL_MASK_INSTANCE_2_SHIFT;

    return mask;
}

/******************************************************************************
NAME
    ancGainGetCodecRawInputGain

DESCRIPTION
    Helper function to get the Codec Raw input gain to set which is combination of analog and digital gain (fine mode)
*/
static uint32 calculateCodecRawInputGain(audio_channel channel)
{
    anc_mic_params_t* mic_params = ancDataGetMicParams();
    uint32 raw_input_gain = ancDataGetAdcGain(channel);
    uint16 digital_gain = ((uint16)ancDataGetAdcGain(channel) | FINE_MODE_DIGITAL_GAIN);

    switch(ancDataGetFineTuneGain())
    {
        case anc_fine_tune_gain_step_positive:
        	digital_gain += mic_params->mic_gain_step_size;
        	raw_input_gain = ((raw_input_gain & ANALOGUE_COMPONENT_MASK) | digital_gain);
            break;

        case anc_fine_tune_gain_step_negative:
        	digital_gain -= mic_params->mic_gain_step_size;
        	raw_input_gain = ((raw_input_gain & ANALOGUE_COMPONENT_MASK) | digital_gain);
            break;

        case anc_fine_tune_gain_step_default:
        default:
        	break;
    }

    return raw_input_gain;
}


/******************************************************************************/
static void updateMicGain(const audio_mic_params mic_params, audio_channel channel)
{
    Source anc_mic = AudioPluginGetMicSource(mic_params, channel);

    if(mic_params.is_digital)
    {
        ANC_ASSERT(SourceConfigure(anc_mic, STREAM_DIGITAL_MIC_INPUT_GAIN, ancDataGetAdcGain(channel)));
    }
    else
    {
        ANC_ASSERT(SourceConfigure(anc_mic, STREAM_CODEC_RAW_INPUT_GAIN, calculateCodecRawInputGain(channel)));
    }
}

/******************************************************************************
NAME
    updateSidetoneGain

DESCRIPTION
    Helper function to update the sidetone gain for an individual ANC
    microphone channel.
*/
static void updateSidetoneGain(const audio_mic_params mic_params, audio_channel channel)
{
    Source anc_mic = AudioPluginGetMicSource(mic_params, channel);

    if(mic_params.is_digital)
    {
        ANC_ASSERT(SourceConfigure(anc_mic, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, ancDataGetSidetoneGain()));
        ANC_ASSERT(SourceConfigure(anc_mic, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, TRUE));
    }
    else
    {
        ANC_ASSERT(SourceConfigure(anc_mic, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, ancDataGetSidetoneGain()));
        ANC_ASSERT(SourceConfigure(anc_mic, STREAM_CODEC_SIDETONE_SOURCE_POINT, TRUE));
    }
}

/******************************************************************************/
static void configureMicChannel(audio_mic_params path, audio_channel channel)
{
	Source mic_src = AudioPluginMicSetup(channel, path, ancDataGetMicSampleRate());
	updateMicGain(path, channel);
	ANC_ASSERT(SourceConfigure(mic_src, STREAM_AUDIO_SAMPLE_SIZE, BIT_DEPTH));
}

/******************************************************************************/
static void configureMics(void)
{
    anc_mic_params_t* mic_params = ancDataGetMicParams();

    if (mic_params->enabled_mics & feed_forward_left)
    {
    	configureMicChannel(mic_params->feed_forward_left, AUDIO_CHANNEL_A);
    }

    if (mic_params->enabled_mics & feed_forward_right)
   	{
    	configureMicChannel(mic_params->feed_forward_right, AUDIO_CHANNEL_B);
   	}

    ancConfigureSidetoneGains();
}

/******************************************************************************/
static void closeMics(void)
{
	anc_mic_params_t* mic_params = ancDataGetMicParams();

    if (mic_params->enabled_mics & feed_forward_left)
    {
        AudioPluginMicShutdown(AUDIO_CHANNEL_A, &mic_params->feed_forward_left, TRUE);
    }
    if (mic_params->enabled_mics & feed_forward_right)
    {
        AudioPluginMicShutdown(AUDIO_CHANNEL_B, &mic_params->feed_forward_right, TRUE);
    }
}

/******************************************************************************/
static void configureDacChannel(audio_mic_params path, audio_channel channel)
{
	Sink dac_snk = StreamAudioSink(AUDIO_HARDWARE_CODEC, AUDIO_INSTANCE_0, channel);
	uint32 sample_rate = ancDataGetOutputSampleRate();

	ANC_ASSERT(SinkConfigure(dac_snk, STREAM_AUDIO_SAMPLE_SIZE, BIT_DEPTH));
    ANC_ASSERT(SinkConfigure(dac_snk, STREAM_CODEC_SIDETONE_SOURCE_MASK,
  	    					getChannelMask(channel, path)));

    ANC_ASSERT(SinkConfigure(dac_snk, STREAM_CODEC_INDIVIDUAL_SIDETONE_ENABLE, TRUE));
    ANC_ASSERT(SinkConfigure(dac_snk, STREAM_CODEC_SIDETONE_INJECTION_POINT, TRUE));
    ANC_ASSERT(SinkConfigure(dac_snk, STREAM_CODEC_SIDETONE_INVERT, ancDataGetSidetoneInvert(channel)));
    ANC_ASSERT(SinkConfigure(dac_snk, STREAM_CODEC_OUTPUT_RATE, sample_rate));
}

/******************************************************************************/
static void configureDacs(void)
{
    anc_mic_params_t* mic_params = ancDataGetMicParams();

    if (mic_params->enabled_mics & feed_forward_left)
    {
    	configureDacChannel(mic_params->feed_forward_left, AUDIO_CHANNEL_A);
    }

    if (mic_params->enabled_mics & feed_forward_right)
    {
    	configureDacChannel(mic_params->feed_forward_right, AUDIO_CHANNEL_B);
    }

}

/******************************************************************************/
static bool enableFilter(bool enable)
{
    anc_mic_params_t* mic_params = ancDataGetMicParams();
    bool success = FALSE;

    if (mic_params->enabled_mics & feed_forward_left)
    {
   	    success = CodecSetIirFilter16Bit(getChannelMask(AUDIO_CHANNEL_A, mic_params->feed_forward_left),
    	                                      enable, ancDataGetChannelCoefficients(AUDIO_CHANNEL_A));
    }

    if (mic_params->enabled_mics & feed_forward_right)
    {
        success = CodecSetIirFilter16Bit(getChannelMask(AUDIO_CHANNEL_B, mic_params->feed_forward_right),
                                      enable, ancDataGetChannelCoefficients(AUDIO_CHANNEL_B));
    }

    return success;
}

/******************************************************************************/
static bool enableAnc(void)
{
	bool enabled = FALSE;
	if(enableFilter(TRUE))
	{
	    configureMics();
	    configureDacs();
	    StreamEnableSidetone(TRUE);
	    enabled = TRUE;
	}
	return enabled;
}

/******************************************************************************/
static bool disableAnc(void)
{
	bool disabled = FALSE;

	StreamEnableSidetone(FALSE);
	closeMics();
	if(enableFilter(FALSE))
	{
	    disabled = TRUE;
	}
	return disabled;
}



/******************************************************************************/
void ancConfigureFinetuneGains(void)
{
	anc_mic_params_t* mic_params = ancDataGetMicParams();

    if (mic_params->enabled_mics & feed_forward_left)
    {
        if(!mic_params->feed_forward_left.is_digital)
        {
            updateMicGain(mic_params->feed_forward_left, AUDIO_CHANNEL_A);
	    }
    }

    if (mic_params->enabled_mics & feed_forward_right)
    {
        if(!mic_params->feed_forward_right.is_digital)
        {
	        updateMicGain(mic_params->feed_forward_right, AUDIO_CHANNEL_B);
        }
    }
}

/******************************************************************************/
void ancConfigureSidetoneGains(void)
{
	anc_mic_params_t* mic_params = ancDataGetMicParams();

    if (mic_params->enabled_mics & feed_forward_left)
    {
        updateSidetoneGain(mic_params->feed_forward_left, AUDIO_CHANNEL_A);
    }

    if (mic_params->enabled_mics & feed_forward_right)
    {
        updateSidetoneGain(mic_params->feed_forward_right, AUDIO_CHANNEL_B);
    }
}

/******************************************************************************/
bool ancConfigure(bool enable)
{
	return (enable ? enableAnc() : disableAnc());
}

/******************************************************************************/
bool ancConfigureAfterModeChange(void)
{
	configureMics();
	configureDacs();
	return enableFilter(TRUE);
}
