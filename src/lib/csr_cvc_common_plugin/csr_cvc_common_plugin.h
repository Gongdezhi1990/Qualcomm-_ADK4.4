/****************************************************************************
Copyright (c) 2005 - 2016 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_cvc_common_plugin.h

DESCRIPTION
    
    
NOTES
   
*/
#ifndef _CSR_CVC_COMMON_PLUGIN_H_
#define _CSR_CVC_COMMON_PLUGIN_H_

#include <message.h> 
#include <audio_plugin_if.h>
#include <audio_plugin_voice_variants.h>

/*!  CSR_CVC_COMMON plugin

    This is an cVc plugin that can be used with the cVc DSP library.
*/

typedef struct
{
    unsigned external_mic_settings:2;
} CVCPluginModeParams;


#endif /* _CSR_CVC_COMMON_PLUGIN_H_ */
