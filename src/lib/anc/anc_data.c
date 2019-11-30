/*******************************************************************************
Copyright (c) 2015-2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    anc_data.c

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

typedef struct
{
    anc_state state;
    anc_mode mode;
    anc_mic_params_t mic_params;
    anc_config_t config_data;
    anc_fine_tune_gain_step_t fine_tune_gain_step;
} anc_lib_data_t;


static anc_lib_data_t* anc_lib_data = NULL;

/******************************************************************************/
bool ancDataInitialise(void)
{
    /* Should only ever be initialised once */
    ANC_ASSERT(anc_lib_data == NULL);

    anc_lib_data = malloc(sizeof(anc_lib_data_t));
    return (anc_lib_data != NULL);
}

/******************************************************************************/
bool ancDataDeinitialise(void)
{
    free((anc_lib_data));
    anc_lib_data = NULL;
    return (anc_lib_data == NULL);
}

/******************************************************************************/
void ancDataSetState(anc_state state)
{
    ANC_ASSERT(anc_lib_data != NULL);
    anc_lib_data->state = state;

    ancConfigDataUpdateOnStateChange();
}

/******************************************************************************/
anc_state ancDataGetState(void)
{
    if (anc_lib_data == NULL)
    {
        /* If we haven't allocated the library data yet then we must be in
           uninitialised state */
        return anc_state_uninitialised;
    }
    return anc_lib_data->state;
}

/******************************************************************************/
void ancDataSetMicParams(anc_mic_params_t *mic_params)
{
    ANC_ASSERT(anc_lib_data != NULL);
    anc_lib_data->mic_params = *mic_params;
}

/******************************************************************************/
anc_mic_params_t* ancDataGetMicParams(void)
{
    ANC_ASSERT(anc_lib_data != NULL);
    return &(anc_lib_data->mic_params);
}

/******************************************************************************/
void ancDataSetMode(anc_mode mode)
{
    ANC_ASSERT(anc_lib_data != NULL);
    anc_lib_data->mode = mode;

    ancConfigDataUpdateOnModeChange();
}

/******************************************************************************/
anc_mode ancDataGetMode(void)
{
    ANC_ASSERT(anc_lib_data != NULL);
    return anc_lib_data->mode;
}

/******************************************************************************/
anc_config_t * ancDataGetConfigData(void)
{
    ANC_ASSERT(anc_lib_data != NULL);
    return &anc_lib_data->config_data;
}

/******************************************************************************/
void ancDataSetFineTuneGain(anc_fine_tune_gain_step_t step)
{
    ANC_ASSERT(anc_lib_data != NULL);
    anc_lib_data->fine_tune_gain_step = step;
}

anc_fine_tune_gain_step_t ancDataGetFineTuneGain(void)
{
    ANC_ASSERT(anc_lib_data != NULL);
    return anc_lib_data->fine_tune_gain_step;
}

/******************************************************************************/
anc_mode_config_t * ancDataGetCurrentModeConfig(void)
{
    if(ancDataGetMode() == anc_mode_active)
    {
        return &ancDataGetConfigData()->active;
    }
    else if(ancDataGetMode() == anc_mode_leakthrough)
    {
        return &ancDataGetConfigData()->leakthrough;
    }
    ANC_PANIC();
    return NULL;
}

void ancDataRetrieveAndPopulateTuningData(void)
{
    ancConfigReadPopulateAncData(ancDataGetConfigData());
}
