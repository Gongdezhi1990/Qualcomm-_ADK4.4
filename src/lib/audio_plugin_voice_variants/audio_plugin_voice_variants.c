/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.

FILE NAME
    audio_plugin_voice_variants.c

DESCRIPTION
    Definitions of voice plug-in variants.
*/

#include <stdlib.h>
#include <print.h>

#include "audio_plugin_voice_variants.h"


extern CvcPluginTaskdata csr_cvsd_no_dsp_plugin;
extern CvcPluginTaskdata usb_nb_no_dsp_plugin;

#define NODSPCVSD       (TaskData *)&csr_cvsd_no_dsp_plugin
#define USB_NODSP_NB    (TaskData *)&usb_nb_no_dsp_plugin

#ifdef NO_DSP
    #define MAX_NUM_HFP_PLUGINS_PER_CODEC (1)

    /* the column to use is selected by user PSKEY
       the row depends upon the audio link (codec) negotiated */
    Task const hfp_cvc_plugins [] [ MAX_NUM_HFP_PLUGINS_PER_CODEC ] =
    {   /*  0   */
    /*CVSD*/    {NODSPCVSD},
    /*SBC*/     {NULL},
    };

#else

    /* HFP extern declarations */
    extern CvcPluginTaskdata csr_cvsd_cvc_1mic_handsfree_plugin;
    extern CvcPluginTaskdata csr_wbs_cvc_1mic_handsfree_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_1mic_handsfree_bex_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_2mic_handsfree_plugin;
    extern CvcPluginTaskdata csr_wbs_cvc_2mic_handsfree_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_2mic_handsfree_bex_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_1mic_headset_plugin;
    extern CvcPluginTaskdata csr_wbs_cvc_1mic_headset_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_1mic_headset_bex_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_2mic_headset_plugin;
    extern CvcPluginTaskdata csr_wbs_cvc_2mic_headset_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_2mic_headset_bex_plugin;

    /* HFP ASR extern declarations */
    extern CvcPluginTaskdata csr_cvsd_cvc_1mic_asr_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_2mic_asr_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_1mic_hf_asr_plugin;
    extern CvcPluginTaskdata csr_cvsd_cvc_2mic_hf_asr_plugin;

    /* HFP Headset plugins */
    #define CVCHS1MIC       (TaskData *)&csr_cvsd_cvc_1mic_headset_plugin
    #define CVCHS1MICBEX    (TaskData *)&csr_cvsd_cvc_1mic_headset_bex_plugin
    #define CVCHS1MICWBS    (TaskData *)&csr_wbs_cvc_1mic_headset_plugin
    #define CVCHS2MIC       (TaskData *)&csr_cvsd_cvc_2mic_headset_plugin
    #define CVCHS2MICBEX    (TaskData *)&csr_cvsd_cvc_2mic_headset_bex_plugin
    #define CVCHS2MICWBS    (TaskData *)&csr_wbs_cvc_2mic_headset_plugin
    /* HFP Handsfree plugins */
    #define CVCHF1MIC       (TaskData *)&csr_cvsd_cvc_1mic_handsfree_plugin
    #define CVCHF1MICBEX    (TaskData *)&csr_cvsd_cvc_1mic_handsfree_bex_plugin
    #define CVCHF1MICWBS    (TaskData *)&csr_wbs_cvc_1mic_handsfree_plugin
    #define CVCHF2MIC       (TaskData *)&csr_cvsd_cvc_2mic_handsfree_plugin
    #define CVCHF2MICBEX    (TaskData *)&csr_cvsd_cvc_2mic_handsfree_bex_plugin
    #define CVCHF2MICWBS    (TaskData *)&csr_wbs_cvc_2mic_handsfree_plugin

#ifdef INCLUDE_DSP_EXAMPLES
    #include <csr_common_example_plugin.h>

    extern ExamplePluginTaskdata csr_cvsd_8k_1mic_plugin;
    extern ExamplePluginTaskdata csr_sbc_1mic_plugin;
    extern ExamplePluginTaskdata csr_cvsd_8k_2mic_plugin;
    extern ExamplePluginTaskdata csr_sbc_2mic_plugin;

    /* Example Plugins */
    #define CVSD1MIC_EXAMPLE    (TaskData *)&csr_cvsd_8k_1mic_plugin
    #define SBC1MIC_EXAMPLE     (TaskData *)&csr_sbc_1mic_plugin
    #define CVSD2MIC_EXAMPLE    (TaskData *)&csr_cvsd_8k_2mic_plugin
    #define SBC2MIC_EXAMPLE     (TaskData *)&csr_sbc_2mic_plugin
#else
    #define CVSD1MIC_EXAMPLE    NULL
    #define SBC1MIC_EXAMPLE     NULL
    #define CVSD2MIC_EXAMPLE    NULL
    #define SBC2MIC_EXAMPLE     NULL
#endif

    #define MAX_NUM_HFP_PLUGINS_PER_CODEC (max_num_voice_variants_inc_examples)

    /* the column to use is selected by user PSKEY
    the row depends upon the audio link (codec) negotiated */
    Task const hfp_cvc_plugins[][MAX_NUM_HFP_PLUGINS_PER_CODEC] =
    {
        /*CVSD*/
        {
          NODSPCVSD,  
          /*Headset plugins*/
          CVCHS1MIC,
          CVCHS1MICBEX,
          CVCHS2MIC,
          CVCHS2MICBEX, 
          NULL,
          /*Handsfree plugins*/
          CVCHF1MIC,   
          CVCHF1MICBEX,
          CVCHF2MIC,
          CVCHF2MICBEX,
          /*Speaker plugins - Not supported for Bluecore*/
          NULL,   
          NULL,
          /*DSP Example plugins*/
          CVSD1MIC_EXAMPLE,
          CVSD2MIC_EXAMPLE
        },           
        /*MSBC*/
        {
          NULL,  
          /*Headset plugins*/
          CVCHS1MICWBS, 
          CVCHS1MICWBS, 
          CVCHS2MICWBS,   
          CVCHS2MICWBS,  
          NULL,
          /*Handsfree plugins*/
          CVCHF1MICWBS, 
          CVCHF1MICWBS,   
          CVCHF2MICWBS,   
          CVCHF2MICWBS, 
          /*Speaker plugins - Not supported for Bluecore*/
          NULL, 
          NULL,   
          /*DSP Example plugins*/
          SBC1MIC_EXAMPLE,    
          SBC2MIC_EXAMPLE
         }
    };

#endif

static hfp_wbs_codec_mask translateUsbCodecToHfpCodec(usb_voice_plugin_type usb_codec)
{
    switch (usb_codec)
    {
        case usb_voice_mono_nb:
            return hfp_wbs_codec_mask_cvsd;

        case usb_voice_mono_wb:
            return hfp_wbs_codec_mask_msbc;

        default:
            return hfp_wbs_codec_mask_none;
    }
}

Task AudioPluginVoiceVariantsGetHfpPlugin(hfp_wbs_codec_mask codec, plugin_index_t index)
{
    if((codec == hfp_wbs_codec_mask_cvsd) || (codec == hfp_wbs_codec_mask_msbc))
    {
        if(index < MAX_NUM_HFP_PLUGINS_PER_CODEC)
        {
            PRINT(("Voice: plugin [%p] \n" , (void*)plugin));
            return hfp_cvc_plugins[codec - hfp_wbs_codec_mask_cvsd][index];
        }
    }

    return NULL;
}


Task AudioPluginVoiceVariantsGetUsbPlugin(usb_voice_plugin_type usb_codec, plugin_index_t index)
{
    hfp_wbs_codec_mask hfp_codec = translateUsbCodecToHfpCodec(usb_codec);

    return AudioPluginVoiceVariantsGetHfpPlugin(hfp_codec, index);
}


Task AudioPluginVoiceVariantsGetAsrPlugin(hfp_wbs_codec_mask codec, plugin_index_t index)
{
#ifdef NO_DSP
    UNUSED(codec);
    UNUSED(index);
#else
    Task plugin = AudioPluginVoiceVariantsGetHfpPlugin(codec, index);

    /* 1 mic headset? */
    if((plugin == (TaskData *) &csr_cvsd_cvc_1mic_headset_plugin) ||
       (plugin == (TaskData *) &csr_cvsd_cvc_1mic_headset_bex_plugin))
    {
        /* use the asr 1-mic task instead */
        return (TaskData *) &csr_cvsd_cvc_1mic_asr_plugin;
    }

    /* 2 mic headset? */
    if((plugin == (TaskData *) &csr_cvsd_cvc_2mic_headset_plugin) ||
       (plugin == (TaskData *) &csr_cvsd_cvc_2mic_headset_bex_plugin))
    {
        /* use the asr 2-mic task instead */
        return (TaskData *) &csr_cvsd_cvc_2mic_asr_plugin;
    }

    /* 1 mic handsfree? */
    if((plugin == (TaskData *) &csr_cvsd_cvc_1mic_handsfree_plugin) ||
       (plugin == (TaskData *) &csr_cvsd_cvc_1mic_handsfree_bex_plugin))
    {
        /* use the asr 1-mic hf task instead */
        return (TaskData *) &csr_cvsd_cvc_1mic_hf_asr_plugin;
    }

    /* 2mic handsfree? */
    if((plugin == (TaskData *) &csr_cvsd_cvc_2mic_handsfree_plugin) ||
       (plugin == (TaskData *) &csr_cvsd_cvc_2mic_handsfree_bex_plugin))
    {
        /* use the asr 2-mic hf task instead */
        return (TaskData *) &csr_cvsd_cvc_2mic_hf_asr_plugin;
    }
#endif
    return NULL;
}

