/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_a2dp_decoder_peq.c
DESCRIPTION
    Handle user eq related functionality
*/

#include <kalimba.h>
#include <stdlib.h>
#include <string.h>
#include <print.h>

#include <audio_plugin_if.h>
#include <audio_config.h>
#include <panic.h>

#include "csr_a2dp_decoder_peq.h"
#include "csr_a2dp_decoder_common.h"

#define NUM_WORDS_PER_PARAM (2)
#define SET_GET_PARAMS_HEADER_SIZE (1)

typedef enum
{
    USER_EQ_NUM_PARAMS_HI_OFFSET,
    USER_EQ_NUM_PARAMS_LO_OFFSET
} gaia_cmd_user_eq_num_params_offset;

typedef enum
{
    USER_EQ_PARAM_HI_OFFSET,
    USER_EQ_PARAM_LO_OFFSET,
    USER_EQ_VALUE_HI_OFFSET,
    USER_EQ_VALUE_LO_OFFSET
} gaia_cmd_user_eq_param_payload_offset;

/****************************************************************************
NAME
    csrA2dpDecoderMakeParamId
DESCRIPTION
    construct a user eq parameter from the supplied parameters */
static uint16 csrA2dpDecoderMakeParamId(const uint16 bank, const uint16 band, const eq_param_type_t param_type)
{
    return (uint16)(((uint16)(bank & 0x000f) << 8) | (uint16)((band & 0x000f) << 4) | (uint16)(param_type & 0x000f) );
}


void CsrA2dpDecoderSetUserEqParameter(const audio_plugin_user_eq_param_t* param)
{
    AudioConfigSetUserEqParameter(param);
}


void CsrA2dpDecoderApplyUserEqParameters(AUDIO_PLUGIN_APPLY_USER_EQ_PARAMETERS_MSG_T* apply_message)
{
    /* DSP long message format follows gaia message format (in words)
     * Offset  Comment
         0     Number of parameters
         1     Parameter 1 ID
         2     Value for Param 1
         [Repeat offset 1-2]
     */
    unsigned number_of_params = AudioConfigGetNumberOfEqParams();

    bool recalcalculate_coefficients = apply_message->recalculate_coefficients;

    /* Must send all params as individual parameters if the recalc flag is set due to the
     * way the dsp handles long and short messages*/
    bool send_params_individually = ((number_of_params == 1) || (recalcalculate_coefficients == TRUE));
    unsigned i;
    const unsigned last_param = number_of_params - 1;
    audio_plugin_user_eq_param_t* param;
    uint16 param_id;
    uint16 param_value;

    if (send_params_individually)
    {
        bool send_recalculate;
        for (i = 0; i < number_of_params; i++)
        {
            send_recalculate = recalcalculate_coefficients && (i == last_param);
            param = AudioConfigGetUserEqParameter(i);
            param_id = csrA2dpDecoderMakeParamId(param->id.bank, param->id.band, param->id.param_type);
            param_value = (uint16)param->value;
            KALIMBA_SEND_MESSAGE(KALIMBA_SET_USER_EQ_PARAM, param_id, param_value, (uint16)send_recalculate, 0);
        }
    }
    else
    {
        unsigned offset;
        size_t message_size = (sizeof(uint16) * ((number_of_params * NUM_WORDS_PER_PARAM) + SET_GET_PARAMS_HEADER_SIZE));
        uint16* message = PanicUnlessMalloc(message_size);
        message[0] = (uint16)number_of_params;

        for (i = 0; i < number_of_params; i++)
        {
            param = AudioConfigGetUserEqParameter(i);
            param_id = csrA2dpDecoderMakeParamId(param->id.bank, param->id.band, param->id.param_type);
            param_value = (uint16)param->value;
            offset = SET_GET_PARAMS_HEADER_SIZE + (i * NUM_WORDS_PER_PARAM);

            message[offset] = param_id;
            message[offset + 1] = param_value;
        }
        KalimbaSendLongMessage(KALIMBA_SET_USER_EQ_PARAMS, (uint16)message_size, message);
        free(message);
    }
    AudioConfigClearUserEqParams();
}


void CsrA2dpDecoderGetUserEqParameter(audio_plugin_user_eq_param_id_t* param_id)
{
    uint16 param = csrA2dpDecoderMakeParamId(param_id->bank, param_id->band, param_id->param_type);
    KalimbaSendMessage(KALIMBA_GET_USER_EQ_PARAM, param, 0, 0, 0);
}


void CsrA2dpDecoderGetUserEqGroupParameter(unsigned number_of_params, audio_plugin_user_eq_param_id_t* param_ids)
{
    /* DSP message format follows gaia message format (in words)
     * Offset  Comment
         0     Number of parameters
         1     Parameter 1 ID
         2     Must be zero
      [Repeat offset 1-2]
     */
    unsigned i;
    size_t message_size = (sizeof(uint16) * ((number_of_params * NUM_WORDS_PER_PARAM)  + SET_GET_PARAMS_HEADER_SIZE));
    uint16* message = PanicUnlessMalloc(message_size);
    memset(message, 0, message_size);

    message[0] = (uint16)number_of_params;

    for (i = 0; i < number_of_params; i++)
    {
        unsigned offset = SET_GET_PARAMS_HEADER_SIZE + (i * NUM_WORDS_PER_PARAM);
        uint16 param = csrA2dpDecoderMakeParamId(param_ids[i].bank, param_ids[i].band, param_ids[i].param_type);
        message[offset] = param;
    }

    KalimbaSendLongMessage(KALIMBA_GET_USER_EQ_PARAMS, (uint16)message_size, message);

    free(message);
}

