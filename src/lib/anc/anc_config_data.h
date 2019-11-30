/*******************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    anc_config_data.h

DESCRIPTION
    Architecture specific config data.
*/

#ifndef ANC_CONFIG_DATA_H_
#define ANC_CONFIG_DATA_H_

#include <vmtypes.h>
#include <csrtypes.h>
#include <app/audio/audio_if.h>

/*! @brief The ANC mode specific IIR filter coefficients.

    These are the IIR coefficients that are required by ANC on a per ANC mode basis.
 */
typedef struct
{
    IIR_COEFFICIENTS coefficient_a;
    IIR_COEFFICIENTS coefficient_b;
} anc_mode_coefficients_t;

/*! @brief The ANC mode specific gains.

    These are the gain values that are required by ANC on a per ANC mode basis.
 */
typedef struct
{
    uint32 dac_gain_a;
    uint32 dac_gain_b;
    uint32 adc_gain_a;
    uint32 adc_gain_b;
} anc_mode_gains_t;

/*! @brief ANC mode specific Tuning configuration.

    These are the configuration values that are required by ANC on a per ANC mode basis.
 */
typedef struct
{
    BITFIELD unused:10;
    BITFIELD adc_sample_rate:1;
    BITFIELD dac_sample_rate:1;
    BITFIELD st_invert_a:1;
    BITFIELD st_invert_b:1;
    BITFIELD inv_gain_a:1;
    BITFIELD inv_gain_b:1;
} anc_mode_tuning_config_t;

typedef struct
{
    anc_mode_gains_t gains;
    anc_mode_coefficients_t coefficients;
    anc_mode_tuning_config_t tuning_config;
} anc_mode_config_t;

typedef struct
{
    anc_mode_config_t active;
    anc_mode_config_t leakthrough;
    uint16 sidetone_gain;
} anc_config_t;

/******************************************************************************
NAME
    ancDataGetChannelCoefficients

DESCRIPTION
    Simple getter functions for the ANC coefficients.
*/
IIR_COEFFICIENTS* ancDataGetChannelCoefficients(audio_channel channel);
    

/******************************************************************************
NAME
    ancDataGetXXXSampleRate

DESCRIPTION
    Simple getters for ADC and DAC sample rates.
*/
uint32 ancDataGetMicSampleRate(void);
uint32 ancDataGetOutputSampleRate(void);

/******************************************************************************
NAME
    ancDataGetSidetoneInvert
    ancDataGetInvertGain

DESCRIPTION
    Simple getters for sidetone and gain invert.
*/
bool ancDataGetSidetoneInvert(audio_channel channel);
bool ancDataGetInvertGain(audio_channel channel);


/******************************************************************************
NAME
    ancDataGetXXXGain

DESCRIPTION
    Simple getter functions for the ADC and DAC Gains.
*/
uint32 ancDataGetAdcGain(audio_channel channel);
uint32 ancDataGetDacGain(audio_channel channel);


/******************************************************************************
NAME
    ancDataSetSidetoneGain/ancDataGetSidetoneGain

DESCRIPTION
    Simple setter and getter functions for the ANC Sidetone Gain.
*/
bool ancDataSetSidetoneGain(uint16 sidetone_gain);
uint16 ancDataGetSidetoneGain(void);

/******************************************************************************/
void ancConfigDataUpdateOnStateChange(void);
void ancConfigDataUpdateOnModeChange(void);

#endif
