/*******************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    anc_config_data.c

DESCRIPTION
    Encapsulation of the ANC VM Library data.
*/

#include "anc_config_data.h"
#include "anc_data.h"
#include "anc_debug.h"
#include "anc_config_read.h"

#include <stdlib.h>
#include <string.h>
#include <audio_config.h>


/******************************************************************************/
IIR_COEFFICIENTS* ancDataGetChannelCoefficients(audio_channel channel)
{
    anc_mode_config_t * mode_config = ancDataGetCurrentModeConfig();

    if(channel == AUDIO_CHANNEL_A)
    {
        return &mode_config->coefficients.coefficient_a;
    }
    else if(channel == AUDIO_CHANNEL_B)
    {
        return &mode_config->coefficients.coefficient_b;
    }
    ANC_PANIC();
    return NULL;
}

/******************************************************************************/
uint32 ancDataGetMicSampleRate(void)
{
    anc_mode_config_t * mode_config = ancDataGetCurrentModeConfig();

    uint32 sample_rate = SAMPLE_RATE_48000;
    if(mode_config->tuning_config.adc_sample_rate)
    {
        sample_rate = SAMPLE_RATE_96000;
    }
    return sample_rate;
}

/******************************************************************************/
uint32 ancDataGetOutputSampleRate(void)
{
    anc_mode_config_t * mode_config = ancDataGetCurrentModeConfig();

    uint32 sample_rate = DAC_OUTPUT_RESAMPLE_RATE_96K;
    if(mode_config->tuning_config.dac_sample_rate)
    {
        sample_rate = DAC_OUTPUT_RESAMPLE_RATE_192K;
    }
    return sample_rate;
}

/******************************************************************************/
static void updateDacOutputResamplingRate(void)
{
    uint32 resample_rate = DAC_OUTPUT_RESAMPLE_RATE_NONE;
    if(ancDataGetState() == anc_state_enabled)
    {
        resample_rate = ancDataGetOutputSampleRate();
    }
    AudioConfigSetDacOutputResamplingRate(resample_rate);
}

/******************************************************************************/
static void updateDacOutputRawGainForChannel(audio_channel channel)
{
    if(channel == AUDIO_CHANNEL_A)
    {
        AudioConfigSetRawDacGain(audio_output_primary_left, ancDataGetDacGain(channel));
    }
    else if(channel == AUDIO_CHANNEL_B)
    {
        AudioConfigSetRawDacGain(audio_output_primary_right, ancDataGetDacGain(channel));
    }
}

static void updateDacOutputRawGainSettings(void)
{
    updateDacOutputRawGainForChannel(AUDIO_CHANNEL_A);
    updateDacOutputRawGainForChannel(AUDIO_CHANNEL_B);
}

/******************************************************************************/
bool ancDataGetSidetoneInvert(audio_channel channel)
{
    anc_mode_config_t * mode_config = ancDataGetCurrentModeConfig();

    if(channel == AUDIO_CHANNEL_A)
    {
        return mode_config->tuning_config.st_invert_a;
    }
    else if(channel == AUDIO_CHANNEL_B)
    {
        return mode_config->tuning_config.st_invert_b;
    }
    ANC_PANIC();
    return FALSE;
}

/******************************************************************************/
bool ancDataGetInvertGain(audio_channel channel)
{
    anc_mode_config_t * mode_config = ancDataGetCurrentModeConfig();

    if(channel == AUDIO_CHANNEL_A)
    {
        return mode_config->tuning_config.inv_gain_a;
    }
    else if(channel == AUDIO_CHANNEL_B)
    {
        return mode_config->tuning_config.inv_gain_b;
    }
    ANC_PANIC();
    return FALSE;
}

/******************************************************************************/
uint32 ancDataGetAdcGain(audio_channel channel)
{
    anc_mode_config_t * mode_config = ancDataGetCurrentModeConfig();

    if(channel == AUDIO_CHANNEL_A)
    {
        return mode_config->gains.adc_gain_a;
    }
    else if(channel == AUDIO_CHANNEL_B)
    {
        return mode_config->gains.adc_gain_b;
    }
    ANC_PANIC();
    return 0;
}


/******************************************************************************/
uint32 ancDataGetDacGain(audio_channel channel)
{
    anc_mode_config_t * mode_config = ancDataGetCurrentModeConfig();

    if(channel == AUDIO_CHANNEL_A)
    {
        return mode_config->gains.dac_gain_a;
    }
    else if(channel == AUDIO_CHANNEL_B)
    {
        return mode_config->gains.dac_gain_b;
    }
    ANC_PANIC();
    return 0;
}



/******************************************************************************/
bool ancDataSetSidetoneGain(uint16 gain)
{
    if (gain <= ANC_SIDETONE_GAIN_MAX)
    {
        ancDataGetConfigData()->sidetone_gain = gain;
        return TRUE;
    }
    return FALSE;
}

/******************************************************************************/
uint16 ancDataGetSidetoneGain(void)
{
    return ancDataGetConfigData()->sidetone_gain;
}

/******************************************************************************/
static void ancDataResetFineTuneGainStep(void)
{
    ancDataSetFineTuneGain(anc_fine_tune_gain_step_default);
}

void ancConfigDataUpdateOnStateChange(void)
{
    updateDacOutputResamplingRate();
    ancDataResetFineTuneGainStep();
}

void ancConfigDataUpdateOnModeChange(void)
{
    updateDacOutputRawGainSettings();
    ancDataResetFineTuneGainStep();
}

