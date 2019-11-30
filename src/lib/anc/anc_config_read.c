/*******************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    anc_config_read.c

DESCRIPTION

*/

#include <stdlib.h>
#include <ps.h>
#include "anc.h"
#include "anc_data.h"
#include "anc_debug.h"
#include "anc_config_read.h"

#define CONFIG_DSP_BASE  (50)
#define CONFIG_DSP(x)    (CONFIG_DSP_BASE + x)

#define ANC_TUNING_TOOL_ACTIVE_MODE_KEY (CONFIG_DSP(1))
#define ANC_TUNING_TOOL_LEAKTHROUGH_MODE_KEY (CONFIG_DSP(2))
/*  ANC Configuration defines */
#define ANC_TUNING_TOOL_CONFIG_SIZE 31 /* Sizeof PS Key */
#define ANC_CONFIG_TOOL_CONFIG_SIZE 3 /* Sizeof PS Key */
#define ANC_CONFIG_TOOL_SESSION_DATA_SIZE 3 /* Sizeof PS Key */
/* Tuning Tool configuration field offsets in the PS Keys */
#define ANC_TUNING_TOOL_COEFFICIENTS 0

#define ANC_TUNING_TOOL_ADC_A_GAIN_ANALOGUE 22
#define ANC_TUNING_TOOL_ADC_B_GAIN_ANALOGUE 23
#define ANC_TUNING_TOOL_DAC_A_GAIN_ANALOGUE 24
#define ANC_TUNING_TOOL_DAC_B_GAIN_ANALOGUE 25

#define ANC_TUNING_TOOL_ADC_A_GAIN_DIGITAL 26
#define ANC_TUNING_TOOL_ADC_B_GAIN_DIGITAL 27
#define ANC_TUNING_TOOL_DAC_A_GAIN_DIGITAL 28
#define ANC_TUNING_TOOL_DAC_B_GAIN_DIGITAL 29

#define ANC_TUNING_TOOL_CONFIG 30

#define ANC_CONFIG_TOOL_SESSION_DATA_SIZE 3 /* Sizeof PS Key */

/* The ANC Tuning Config word is a set of flags, these are the Masks */
#define ANC_TUNING_TOOL_CONFIG_ST_INV_A 0x0008
#define ANC_TUNING_TOOL_CONFIG_ST_INV_B 0x0004

#define ANC_TUNING_TOOL_CONFIG_ADC_SAMPLE_RATE 0x0020
#define ANC_TUNING_TOOL_CONFIG_DAC_SAMPLE_RATE 0x0010

#define ANC_TUNING_TOOL_CONFIG_INV_GAIN_A 0x0002
#define ANC_TUNING_TOOL_CONFIG_INV_GAIN_B 0x0001

/* Size of coefficients, i.e. number of words in IIR_COEFFICIENTS */
#define ANC_COEFFICIENTS_SIZE 11


static void populateCoefficientsFromPsKey(anc_mode_config_t * mode_config, uint16 * pskey_val)
{
    uint16 loop_count;
    for(loop_count = ANC_TUNING_TOOL_COEFFICIENTS; loop_count < ANC_COEFFICIENTS_SIZE; loop_count++)
    {
        mode_config->coefficients.coefficient_a.coefficients[loop_count] = pskey_val[loop_count];
        mode_config->coefficients.coefficient_b.coefficients[loop_count] = pskey_val[loop_count + ANC_COEFFICIENTS_SIZE];
    }
}

static void populateGainsFromPsKey(anc_mode_config_t * mode_config, uint16 * pskey_val)
{
    mode_config->gains.adc_gain_a = ((uint32) pskey_val[ANC_TUNING_TOOL_ADC_A_GAIN_ANALOGUE] << 16);
    mode_config->gains.adc_gain_a += pskey_val[ANC_TUNING_TOOL_ADC_A_GAIN_DIGITAL];

    mode_config->gains.adc_gain_b = ((uint32) pskey_val[ANC_TUNING_TOOL_ADC_B_GAIN_ANALOGUE] << 16);
    mode_config->gains.adc_gain_b += pskey_val[ANC_TUNING_TOOL_ADC_B_GAIN_DIGITAL];

    mode_config->gains.dac_gain_a = ((uint32) pskey_val[ANC_TUNING_TOOL_DAC_A_GAIN_ANALOGUE] << 16);
    mode_config->gains.dac_gain_a += pskey_val[ANC_TUNING_TOOL_DAC_A_GAIN_DIGITAL];

    mode_config->gains.dac_gain_b = ((uint32) pskey_val[ANC_TUNING_TOOL_DAC_B_GAIN_ANALOGUE] << 16);
    mode_config->gains.dac_gain_b += pskey_val[ANC_TUNING_TOOL_DAC_B_GAIN_DIGITAL];
}

static void populateTuningConfigFromPsKey(anc_mode_config_t * mode_config, uint16 * pskey_val)
{
    mode_config->tuning_config.adc_sample_rate = ((pskey_val[ANC_TUNING_TOOL_CONFIG] & ANC_TUNING_TOOL_CONFIG_ADC_SAMPLE_RATE) != 0);
    mode_config->tuning_config.dac_sample_rate = ((pskey_val[ANC_TUNING_TOOL_CONFIG] & ANC_TUNING_TOOL_CONFIG_DAC_SAMPLE_RATE) != 0);

    mode_config->tuning_config.st_invert_a = ((pskey_val[ANC_TUNING_TOOL_CONFIG] & ANC_TUNING_TOOL_CONFIG_ST_INV_A) != 0);
    mode_config->tuning_config.st_invert_b = ((pskey_val[ANC_TUNING_TOOL_CONFIG] & ANC_TUNING_TOOL_CONFIG_ST_INV_B) != 0);

    mode_config->tuning_config.inv_gain_a = ((pskey_val[ANC_TUNING_TOOL_CONFIG] & ANC_TUNING_TOOL_CONFIG_INV_GAIN_A) != 0);
    mode_config->tuning_config.inv_gain_b = ((pskey_val[ANC_TUNING_TOOL_CONFIG] & ANC_TUNING_TOOL_CONFIG_INV_GAIN_B) != 0);
}

/******************************************************************************
NAME
    readAncTuningToolModeConfig

DESCRIPTION
    Read the configuration from the ANC tuning tool for a specific ANC mode.
*/
static void readAncTuningToolModeConfig(uint16 ps_key_num, anc_mode_config_t * mode_config)
{
    uint16 pskey_val[ANC_TUNING_TOOL_CONFIG_SIZE];


    /* Read PS Key, size must be checked previously */
    PsRetrieve(ps_key_num, pskey_val, ANC_TUNING_TOOL_CONFIG_SIZE);

    populateCoefficientsFromPsKey(mode_config, pskey_val);
    populateGainsFromPsKey(mode_config, pskey_val);
    populateTuningConfigFromPsKey(mode_config, pskey_val);
}

static bool areAncConfigKeysValid(void)
{
    return ((PsRetrieve(ANC_TUNING_TOOL_ACTIVE_MODE_KEY, NULL, 0) == ANC_TUNING_TOOL_CONFIG_SIZE) &&
            (PsRetrieve(ANC_TUNING_TOOL_LEAKTHROUGH_MODE_KEY, NULL, 0) == ANC_TUNING_TOOL_CONFIG_SIZE));
}

void ancConfigReadPopulateAncData(anc_config_t * config_data)
{
    if(areAncConfigKeysValid() == FALSE)
    {
        ANC_PANIC();
    }

    readAncTuningToolModeConfig(ANC_TUNING_TOOL_ACTIVE_MODE_KEY, &config_data->active);
    readAncTuningToolModeConfig(ANC_TUNING_TOOL_LEAKTHROUGH_MODE_KEY, &config_data->leakthrough);
}
