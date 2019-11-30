/****************************************************************************
Copyright (c) 2018 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    sbc_encoder_params_util.h
 
DESCRIPTION
    Converts sink application's format of SBC encoder settings
    to operators library SBC encoder parameters.
*/

#ifndef SBC_ENCODER_PARAMS_UTIL_H_
#define SBC_ENCODER_PARAMS_UTIL_H_

#include <audio_sbc_encoder_params.h>


uint16 voiceAssistantDspConvertSbcEncParamsToFormat(sbc_encoder_params_t *params);


#endif /* SBC_ENCODER_PARAMS_UTIL_H_ */

