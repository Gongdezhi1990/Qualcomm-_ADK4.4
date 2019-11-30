/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_a2dp_decoder_peq.h
DESCRIPTION
    Handle user eq related functionality
*/

#ifndef CSR_A2DP_DECODER_PEQ_H_
#define CSR_A2DP_DECODER_PEQ_H_

/****************************************************************************
DESCRIPTION
    Stores a single user eq parameter in the audio_config library.
*/
void CsrA2dpDecoderSetUserEqParameter(const audio_plugin_user_eq_param_t* param);

/****************************************************************************
DESCRIPTION
    Sends a message to kalimba to apply all the user eq parameters that were previously stored in the audio_config library.
*/
void CsrA2dpDecoderApplyUserEqParameters(AUDIO_PLUGIN_APPLY_USER_EQ_PARAMETERS_MSG_T* apply_message);

/****************************************************************************
DESCRIPTION
    Sends message to kalimba to get a single user eq parameter.
*/
void CsrA2dpDecoderGetUserEqParameter(audio_plugin_user_eq_param_id_t* param);

/****************************************************************************
DESCRIPTION
    Sends message to kalimba to get multiple user eq parameters.
*/
void CsrA2dpDecoderGetUserEqGroupParameter(unsigned number_of_params, audio_plugin_user_eq_param_id_t* params);


#endif /* CSR_A2DP_DECODER_PEQ_H_ */
