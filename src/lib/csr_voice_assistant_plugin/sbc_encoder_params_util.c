/***************************************************************************
Copyright (c) 2015 - 2018 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    sbc_encoder_params_util.c
 
DESCRIPTION
    Converts sink application's format of SBC encoder settings
    to operators library SBC encoder parameters.
*/


#include "audio_plugin_common.h"
#include "sbc_encoder_params_util.h"


/* SBC Encoder Params masks */
#define VA_SBC_16KHZ_MASK                    6
#define VA_SBC_16_BCK_MASK                  4
#define VA_SBC_MONO_MASK                    2
#define VA_SBC_SNR_MASK                       1
#define VA_SBC_8_SUB_BANDS_MASK        0



/* SBC Encoder Params defaults */
#define VA_DEFAULT_SBCENC_NO_OF_SUBBANDS        8
#define VA_DEFAULT_SBCENC_NO_OF_BLOCKS          16
#define VA_DEFAULT_SBCENC_SAMPLE_RATE           16000
#define DEFAULT_VA_SBC_BITPOOL                  0x001c


uint16 voiceAssistantDspConvertSbcEncParamsToFormat(sbc_encoder_params_t *sbcEncParams)
{
    uint16 format = 0;
    /* Validate all the sbc encoder params including bitpool size*/
    if((VA_DEFAULT_SBCENC_SAMPLE_RATE != sbcEncParams->sample_rate) ||
        (VA_DEFAULT_SBCENC_NO_OF_BLOCKS != sbcEncParams->number_of_blocks) ||
        (sbc_encoder_channel_mode_mono != sbcEncParams->channel_mode) ||
        (sbc_encoder_allocation_method_snr != sbcEncParams->allocation_method) ||
        (VA_DEFAULT_SBCENC_NO_OF_SUBBANDS != sbcEncParams->number_of_subbands) ||
        (DEFAULT_VA_SBC_BITPOOL != sbcEncParams->bitpool_size))
    {
        /*Expect only Default values to be set to avoid undesired behavior */
        Panic();
    }
 
    /* set the sampling frequency */
    format |= 0x00 << VA_SBC_16KHZ_MASK;
    /* number of blocks */
    format |= 0x03 << VA_SBC_16_BCK_MASK;
    /* channel mode */
    format |= 0x00 << VA_SBC_MONO_MASK;
    /* allocation type */
    format |= 0x01 << VA_SBC_SNR_MASK;
    /* sub-band */
    format |=0x01 << VA_SBC_8_SUB_BANDS_MASK;


    return format;
    
}
