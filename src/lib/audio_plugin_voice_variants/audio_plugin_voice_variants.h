/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    audio_plugin_voice_variants.h

DESCRIPTION
    Definitions of voice plug-in variants.
*/

#ifndef AUDIO_PLUGIN_VOICE_VARIANTS_H_
#define AUDIO_PLUGIN_VOICE_VARIANTS_H_

#include <message.h>
#include <hfp.h>

/*******************************************************************************
* CVC plug-in types - Values for the selecting the plug-in variant in the
* CvcPluginTaskdata structure.
*/

/* hfp_wbs_codec_mask is defined in hfp.h */

typedef enum
{
    /*! 8kHz audio */
    usb_voice_mono_nb         = 0x01,
    /*! 16kHz audio */
    usb_voice_mono_wb         = 0x02
} usb_voice_plugin_type;

/*Bex variants not supported on Crescendo*/
/*Speaker variants not supported on BlueCore*/
typedef enum{
    plugin_no_dsp = 0,
        
    plugin_cvc_hs_1mic = 1,
    plugin_cvc_hs_1mic_bex = 2,
    plugin_cvc_hs_2mic = 3,
    plugin_cvc_hs_2mic_bex = 4,
    plugin_cvc_hs_2mic_binaural = 5,

    plugin_cvc_hf_1mic = 6,
    plugin_cvc_hf_1mic_bex = 7,
    plugin_cvc_hf_2mic = 8,
    plugin_cvc_hf_2mic_bex = 9,
    
    plugin_cvc_spkr_1mic = 10,
    plugin_cvc_spkr_2mic = 11,
    
    max_num_voice_variants,
    plugin_cvc_1mic_example = max_num_voice_variants,
    plugin_cvc_2mic_example = 13,
    max_num_voice_variants_inc_examples
}plugin_index_t;


typedef enum
{
    cvc_1_mic_headset_cvsd       = 0,
    cvc_1_mic_headset_cvsd_bex   = 1,
    cvc_1_mic_headset_msbc       = 2,

    cvc_2_mic_headset_cvsd       = 3,
    cvc_2_mic_headset_cvsd_bex   = 4,
    cvc_2_mic_headset_msbc       = 5,

    cvc_1_mic_handsfree_cvsd     = 6,
    cvc_1_mic_handsfree_cvsd_bex = 7,
    cvc_1_mic_handsfree_msbc     = 8,

    cvc_2_mic_handsfree_cvsd     = 9,
    cvc_2_mic_handsfree_cvsd_bex = 10,
    cvc_2_mic_handsfree_msbc     = 11,

    cvc_disabled                 = 12,

    cvc_1_mic_headset_cvsd_asr   = 13,
    cvc_2_mic_headset_cvsd_asr   = 14,

    cvc_1_mic_handsfree_cvsd_asr = 15,
    cvc_2_mic_handsfree_cvsd_asr = 16,

    cvc_2_mic_headset_binaural_nb = 17,
    cvc_2_mic_headset_binaural_wb = 18,

    cvc_1_mic_speaker_cvsd     = 19,
    cvc_1_mic_speaker_msbc     = 20,

    cvc_2_mic_speaker_cvsd     = 21,
    cvc_2_mic_speaker_msbc     = 22

} cvc_plugin_type_t;

typedef enum
{
    link_encoding_cvsd,
    link_encoding_msbc,
    link_encoding_usb_pcm
} link_encoding_t;

typedef struct
{
    TaskData          data;
    cvc_plugin_type_t cvc_plugin_variant:5;   /* Selects the CVC plug-in variant */
    link_encoding_t   encoder:3 ;             /* Sets if its CVSD, AURI or SBC */
    unsigned          two_mic:1;              /* Set the bit if using 2mic plug-in */
    unsigned          adc_dac_16kHz:1;        /* Set ADC/DAC sample rates to 16kHz */
    unsigned          reserved:6 ;            /* Set the reserved bits to zero */
} CvcPluginTaskdata;


/****************************************************************************
DESCRIPTION
    Returns HFP plugin based on codec and index
*/
Task AudioPluginVoiceVariantsGetHfpPlugin(hfp_wbs_codec_mask codec, plugin_index_t plugin);

extern const TaskData aov_plugin;

/****************************************************************************
DESCRIPTION
    Returns USB plugin based on codec and index
*/
Task AudioPluginVoiceVariantsGetUsbPlugin(usb_voice_plugin_type codec, plugin_index_t plugin);

/****************************************************************************
DESCRIPTION
    Returns HFP ASR plugin based on codec and index
*/
Task AudioPluginVoiceVariantsGetAsrPlugin(hfp_wbs_codec_mask codec, plugin_index_t plugin);


#endif /* AUDIO_PLUGIN_VOICE_VARIANTS_H_ */
