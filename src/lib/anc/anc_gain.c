/*******************************************************************************
Copyright (c) 2015 - 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    anc_gain.c

DESCRIPTION
    Functions required to update the ANC Sidetone gain.
*/

#include "anc_gain.h"
#include "anc.h"
#include "anc_data.h"
#include "anc_debug.h"
#include "anc_configure.h"

/******************************************************************************/
static void incrementFineTuneGainStep(void)
{
    anc_fine_tune_gain_step_t gain_step = ancDataGetFineTuneGain();

    gain_step++;
    
    if(gain_step > anc_fine_tune_gain_step_max)
    {
        gain_step = anc_fine_tune_gain_step_min;
    }
    ancDataSetFineTuneGain(gain_step);
}

/******************************************************************************/
static bool analogueMicIsPresent(void)
{
    anc_mic_params_t* mic_params = ancDataGetMicParams();
    return (!mic_params->feed_forward_left.is_digital || !mic_params->feed_forward_right.is_digital);
}



bool ancGainIncrementFineTuneGain(void)
{
    bool success = FALSE;

    if(analogueMicIsPresent())
    {
        incrementFineTuneGainStep();
        ancConfigureFinetuneGains();

        success = TRUE;
    }
    return success;
}

