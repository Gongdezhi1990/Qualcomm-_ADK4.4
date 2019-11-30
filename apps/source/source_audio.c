/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source

FILE NAME
    source_audio.c

DESCRIPTION
    Handles audio routing.

*/


/* header for this file */
#include "source_audio.h"
/* application header files */
#include "source_app_msg_handler.h"
#include "source_debug.h"
#include "source_memory.h"
#include "source_private.h"
#include "source_usb.h"
#include "source_usb.h"
#include "source_volume.h"
#include "source_aghfp.h"
#include "source_connection_mgr.h"
#include <audio_instance.h>
/* profile/library headers */
#include <audio.h>
#include <kalimba_standard_messages.h>
#include <print.h>
#include <stdlib.h>
#include "source_private_data_config_def.h"
#include "Source_configmanager.h" 

/* structure holding the Audio data */
typedef struct
{
    Task audio_plugin;
    A2dpEncoderPluginConnectParams audio_a2dp_connect_params;    
    A2dpEncoderPluginModeParams audio_a2dp_mode_params;
    CsrAgAudioPluginConnectParams audio_aghfp_connect_params;
    CsrAgAudioPluginUsbParams ag_usb_params;
    unsigned audio_routed:2;
    unsigned audio_usb_active:1;
    unsigned audio_a2dp_connection_delay:1;
    unsigned audio_aghfp_connection_delay:1;
    unsigned audio_voip_music_mode:2;
    unsigned audio_remote_bidir_support:1;
    unsigned unused:8;
    audio_instance_t connected_audio_instance;
} AUDIO_DATA_T;

 static AUDIO_DATA_T AUDIO_RUNDATA;

#ifdef DEBUG_AUDIO
    #define AUDIO_DEBUG(x) DEBUG(x)
#else
    #define AUDIO_DEBUG(x)
#endif

#define PIO_SPDIF_INPUT()  audio_get_spdif_input_Values()

#define PIN_WIRED_ALWAYSON  PIN_INVALID     /* Input PIO is disabled, always assumed on */
#define PIN_WIRED_DISABLED  0xFE            /* Entire input type is disabled */


/* Get audio plugin functions */
static Task audio_a2dp_get_plugin(void);
static Task audio_aghfp_get_plugin(bool wbs);
static bool audio_is_bidir_supported(a2dp_codec_settings* settings);
static audio_instance_t audioGetConnectedAudioInstance(void);
static void audioSetConnectedAudioInstance(audio_instance_t instance);


/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME
    audio_plugin_msg_handler -

DESCRIPTION
    Handles messages received from an audio plugin library. 

RETURNS
    void
*/
void audio_plugin_msg_handler(Task task, MessageId id, Message message)
{
    switch (id)
    {
        case AUDIO_DSP_IND:
        {
            /* Warp value sent from the DSP via the audio plugin */
            if (((AUDIO_DSP_IND_T *)message)->id == KALIMBA_MSG_SOURCE_CLOCK_MISMATCH_RATE)
            {
                if (AUDIO_RUNDATA.audio_routed == AUDIO_ROUTED_AGHFP)
                {
                    /* only store the value for AGHFP audio */
                    aghfp_store_warp_values(((AUDIO_DSP_IND_T *)message)->size_value,
                                            ((AUDIO_DSP_IND_T *)message)->value);
                }
            }
        }
        break;

        default:
        {
        }
        break;
	}
}


/****************************************************************************
NAME
    audio_init -

DESCRIPTION
    Initialises the audio section of code. 

RETURNS
    void
*/
void audio_init(void)
{
    /* initialise audio library */
    AudioLibraryInit();

    /* set the input source to either analogue, USB or SPDIF */
    AUDIO_RUNDATA.audio_a2dp_connect_params.input_device_type = audio_get_input_source();

    if(audio_get_input_source() == A2dpEncoderInputDeviceSPDIF)
    {
        if((PIO_SPDIF_INPUT() != PIN_WIRED_ALWAYSON) && (PIO_SPDIF_INPUT() != PIN_WIRED_DISABLED))
        {
            PioSetFunction(PIO_SPDIF_INPUT(), SPDIF_RX);
        }
    }

    AUDIO_RUNDATA.audio_plugin = NULL;
    AUDIO_RUNDATA.audio_routed = AUDIO_ROUTED_NONE;
    AUDIO_RUNDATA.connected_audio_instance = NULL;
}


/****************************************************************************
NAME
    audio_a2dp_connect -

DESCRIPTION
    Attempt to route the A2DP audio. 

RETURNS
    void
*/
void audio_a2dp_connect(Sink sink, uint16 device_id, uint16 stream_id)
{
    uint8 bitpool;
    uint8 bad_link_bitpool;
    bool multiple_streams;
    audio_instance_t taudioinstance = NULL;
 
    /* start audio active timer */
    audio_start_active_timer();

    /* remove any AGHFP audio */
    audio_aghfp_disconnect();

    AUDIO_DEBUG(("AUDIO: audio_a2dp_connect\n"));

    if (AUDIO_RUNDATA.audio_routed == AUDIO_ROUTED_NONE)
    {

        AUDIO_RUNDATA.audio_a2dp_connect_params.input_source = usb_get_speaker_source(); /* Set the USB Source, not used for Analogue */
        AUDIO_RUNDATA.audio_a2dp_connect_params.input_sink = usb_get_mic_sink(); /* Set the USB Sink, not used for Analogue */
        AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[device_id] = sink; /* Set the A2DP media Sink */

        AUDIO_DEBUG(("  audio_routed [%d] input_source [0x%x] input_sink [0x%x] a2dp_sink_0 [0x%x] a2dp_sink_1 [0x%x]\n",
                     AUDIO_RUNDATA.audio_routed,
                     (uint16)AUDIO_RUNDATA.audio_a2dp_connect_params.input_source,
                     (uint16)AUDIO_RUNDATA.audio_a2dp_connect_params.input_sink,
                     (uint16)AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[0],
                     (uint16)AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[1]));

        if (AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[0] || AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[1])
        {
            AudioPluginFeatures features = {0,0,0}; /* no stereo or i2s output */
            a2dp_codec_settings *codec_settings = A2dpCodecGetSettings(device_id, stream_id);

            if (codec_settings)
            {
                AUDIO_DEBUG(("  codec ; voice_rate[0x%lx] packet_size[0x%x] bitpool[0x%x] format[0x%x] CP[0x%x]\n",
                             codec_settings->codecData.voice_rate,
                             codec_settings->codecData.packet_size,
                             codec_settings->codecData.bitpool,
                             codec_settings->codecData.format,
                             codec_settings->codecData.content_protection
                             ));

                AUDIO_RUNDATA.audio_a2dp_connect_params.rate = codec_settings->codecData.voice_rate;
                AUDIO_RUNDATA.audio_a2dp_connect_params.packet_size = codec_settings->codecData.packet_size;
                if (a2dp_get_sbc_bitpool(&bitpool, &bad_link_bitpool, &multiple_streams))
                {
                    AUDIO_RUNDATA.audio_a2dp_connect_params.bitpool = bitpool;
                    AUDIO_RUNDATA.audio_a2dp_connect_params.bad_link_bitpool = bad_link_bitpool;
                }
                else
                {
                    AUDIO_RUNDATA.audio_a2dp_connect_params.bitpool = codec_settings->codecData.bitpool;
                }
                AUDIO_RUNDATA.audio_a2dp_connect_params.format = codec_settings->codecData.format;
                AUDIO_RUNDATA.audio_a2dp_mode_params.eq_mode = volume_get_eq_index();
                AUDIO_RUNDATA.audio_a2dp_connect_params.mode = &AUDIO_RUNDATA.audio_a2dp_mode_params;
                /* turn on content protection if negotiated */
                AUDIO_RUNDATA.audio_a2dp_connect_params.content_protection = codec_settings->codecData.content_protection;

                /* remember if the remote device supports bidirectional audio, i.e. has a MIC back channel */
                AUDIO_RUNDATA.audio_remote_bidir_support = audio_is_bidir_supported(codec_settings) ? 1 : 0;

                AUDIO_RUNDATA.audio_routed = AUDIO_ROUTED_A2DP;

                AUDIO_RUNDATA.audio_a2dp_connect_params.digital_input_bits_per_sample = audio_get_digital_input_bits_per_sample();

                audio_a2dp_get_plugin();

                taudioinstance = AudioConnect(audio_a2dp_get_plugin(),
                        0,
                        AUDIO_SINK_AV,
                        /*a2dp_gain*/10,
                        codec_settings->rate,
                        features, /* stereo supported, no i2s output */
                        volume_get_mute_mode(),
                        AUDIO_ROUTE_INTERNAL,
                        /*power*/0,
                        &AUDIO_RUNDATA.audio_a2dp_connect_params,
                        &theSource->audioTask);

                if(taudioinstance)
                {
                    audioSetConnectedAudioInstance(taudioinstance);
                }

                /* free the codec_settings memory that the A2DP library allocated */
                memory_free(codec_settings);
            }
        }
    }
    else if (AUDIO_RUNDATA.audio_routed == AUDIO_ROUTED_A2DP)
    {
        /* connecting additional A2DP device */
        AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[device_id] = sink;
        AUDIO_RUNDATA.audio_a2dp_mode_params.connect_sink = sink;
        if (a2dp_get_sbc_bitpool(&bitpool, &bad_link_bitpool, &multiple_streams))
        {
            AUDIO_RUNDATA.audio_a2dp_mode_params.bitpool = bitpool;
            AUDIO_RUNDATA.audio_a2dp_mode_params.bad_link_bitpool = bad_link_bitpool;
        }

        AUDIO_DEBUG(("  audio_routed [%d] connect_sink [0x%x] bitpool [%d] bad_link_bitpool [%d]\n",
                      AUDIO_RUNDATA.audio_routed,
                      (uint16)sink,
                      bitpool,
                      bad_link_bitpool));

        audio_update_mode_parameters();
    }
}


/****************************************************************************
NAME    
    audio_a2dp_disconnect

DESCRIPTION
    Attempt to disconnect the A2DP audio. 

RETURNS
    void
*/
void audio_a2dp_disconnect(uint16 device_id, Sink media_sink)
{
    uint16 index = 0;
    bool active_audio = FALSE;

    if (media_sink)
    {
        if (AUDIO_RUNDATA.audio_routed == AUDIO_ROUTED_A2DP)
        {
            /* store that this media is now disconnected */
            AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[device_id] = 0;

            /* see if any other A2DP media is active */
            for (index = 0; index < CSR_A2DP_ENCODER_PLUGIN_MAX_A2DP_SINKS; index++)
            {
                if (AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[index])
                {
                    active_audio = TRUE;
                }
            }

            if (active_audio)
            {
                /* A2DP media still active so just disconnect one of the A2DP audio streams */
                AUDIO_RUNDATA.audio_a2dp_mode_params.disconnect_sink = media_sink;

                AUDIO_DEBUG(("  Disconnect A2DP Audio: sink [0x%x]\n",
                          (uint16)media_sink));

                audio_update_mode_parameters();
            }
            else
            {
                /* no A2DP media still active so disconnect all A2DP audio streams */
                audio_a2dp_disconnect_all();
            }
        }
    }
}


/****************************************************************************
NAME    
    audio_a2dp_disconnect_all

DESCRIPTION
    Attempt to disconnect all active A2DP audio. 

RETURNS
    void
*/
void audio_a2dp_disconnect_all(void)
{
    uint16 index = 0;

    if (AUDIO_RUNDATA.audio_routed == AUDIO_ROUTED_A2DP)
    {
        AUDIO_RUNDATA.audio_routed = AUDIO_ROUTED_NONE;

        for (index = 0; index < CSR_A2DP_ENCODER_PLUGIN_MAX_A2DP_SINKS; index++)
        {
            AUDIO_RUNDATA.audio_a2dp_connect_params.a2dp_sink[index] = 0;
        }

        AudioDisconnect();
        /*delete the connected audio instance*/
        if(audioGetConnectedAudioInstance())
        {
            AudioInstanceDestroy(audioGetConnectedAudioInstance());
            audioSetConnectedAudioInstance(NULL);
        }
    }
}


/****************************************************************************
NAME    
    audio_a2dp_set_plugin

DESCRIPTION
    Set the A2DP audio plugin in use. 

RETURNS
    void
*/
void audio_a2dp_set_plugin(uint8 seid)
{
    AUDIO_DEBUG(("AUDIO: audio_a2dp_set_plugin [%d]\n", seid));

    switch (seid)
    {
        case A2DP_SEID_SBC:
        {
            AUDIO_RUNDATA.audio_plugin = (TaskData *)&csr_a2dp_sbc_encoder_plugin;
        }
        break;

        case A2DP_SEID_FASTSTREAM:
        {
            AUDIO_RUNDATA.audio_plugin = (TaskData *)&csr_a2dp_faststream_encoder_plugin;
        }
        break;

        case A2DP_SEID_APTX:
        {
            AUDIO_RUNDATA.audio_plugin = (TaskData *)&csr_a2dp_aptx_encoder_plugin;
        }
        break;

        case A2DP_SEID_APTX_LOW_LATENCY:
        {
            AUDIO_RUNDATA.audio_plugin = (TaskData *)&csr_a2dp_aptx_lowlatency_encoder_plugin;
        }
        break;

        case A2DP_SEID_APTXHD:
        {
            AUDIO_RUNDATA.audio_plugin = (TaskData *)&csr_a2dp_aptxhd_encoder_plugin;
        }
        break;

        default:
        {
        }
        break;
    }
}


/****************************************************************************
NAME
    audio_set_voip_music_mode

DESCRIPTION
    Set the audio mode in use (VOIP \ MUSIC).

RETURNS
    void
*/
void audio_set_voip_music_mode(AUDIO_VOIP_MUSIC_MODE_T mode)
{
    AUDIO_DEBUG(("AUDIO: Audio Mode [%d]\n", mode));
    AUDIO_RUNDATA.audio_voip_music_mode = mode;
}


/****************************************************************************
NAME    
    audio_switch_voip_music_mode

DESCRIPTION
    Switch the audio mode in use (VOIP \ MUSIC). 

RETURNS
    void
*/
void audio_switch_voip_music_mode(AUDIO_VOIP_MUSIC_MODE_T new_mode)
{
    if (states_get_state() == SOURCE_STATE_CONNECTED)
    {
        AUDIO_DEBUG(("AUDIO: Switch Audio Mode\n"));
        if ((new_mode == AUDIO_VOIP_MODE) &&
            (AUDIO_RUNDATA.audio_voip_music_mode == AUDIO_MUSIC_MODE))
        {
            if (connection_mgr_is_aghfp_profile_enabled() && aghfp_get_number_connections())
            {
                /* only switch if bidirectional support is not enabled, otherwise we're
                 * running with a codec and a remote device which is already feeding us
                 * a MIC back channel */
                if (!AUDIO_RUNDATA.audio_remote_bidir_support)
                {
                    /* switch to VOIP mode from MUSIC mode */
                    audio_set_voip_music_mode(AUDIO_VOIP_MODE);
                    MessageSend(app_get_instance(), APP_AUDIO_START, 0);
                }
            }
        }
        else if ((new_mode == AUDIO_MUSIC_MODE) &&
                 (AUDIO_RUNDATA.audio_voip_music_mode == AUDIO_VOIP_MODE))
        {
            if (connection_mgr_is_a2dp_profile_enabled() && a2dp_get_number_connections())
            {
                /* switch to MUSIC mode from VOIP mode */
                audio_set_voip_music_mode(AUDIO_MUSIC_MODE);
                MessageSend(app_get_instance(), APP_AUDIO_START, 0);
                /* make sure Voice Recognition is disabled as this can cause audio routing issues on the remote device */
                aghfp_send_voice_recognition(FALSE);
            }
        }
    }
}


/****************************************************************************
NAME    
    audio_aghfp_connect

DESCRIPTION
    Attempt to route the AGHFP audio. 

RETURNS
    void
*/
void audio_aghfp_connect(Sink sink, bool esco, bool wbs, uint16 size_warp, uint16 *warp)
{
    uint16 i = 0;
    audio_instance_t taudioinstance = NULL;
    AudioPluginFeatures features = {0,0,0}; /* no stereo or i2s output */

    AUDIO_DEBUG(("AUDIO: audio_aghfp_connect\n"));

    /* start audio active timer */
    audio_start_active_timer();

    /* remove any A2DP audio */
    audio_a2dp_disconnect_all();

    AUDIO_RUNDATA.audio_aghfp_connect_params.mic = NULL;
    AUDIO_RUNDATA.ag_usb_params.usb_source = usb_get_speaker_source(); /* Set the USB Source */
    AUDIO_RUNDATA.ag_usb_params.usb_sink = usb_get_mic_sink(); /* Set the USB Sink */
    AUDIO_RUNDATA.audio_aghfp_connect_params.usb = &AUDIO_RUNDATA.ag_usb_params;

    for (i = 0; i < size_warp; i++)
    {
        AUDIO_RUNDATA.audio_aghfp_connect_params.warp[i] = warp[i];
    }

    if (AUDIO_RUNDATA.audio_routed == AUDIO_ROUTED_NONE)
    {
        AUDIO_RUNDATA.audio_routed = AUDIO_ROUTED_AGHFP;

        taudioinstance  = AudioConnect(audio_aghfp_get_plugin(wbs),
            sink,
            esco ? AUDIO_SINK_ESCO : AUDIO_SINK_SCO,
            /*aghfp_gain*/10,
            8000,
            features ,                        /* no stereo or I2S output required */
            volume_get_mute_mode(),
            AUDIO_ROUTE_INTERNAL,
            /*power*/0,
            &AUDIO_RUNDATA.audio_aghfp_connect_params,
            &theSource->audioTask);

        if(taudioinstance)
        {
            audioSetConnectedAudioInstance(taudioinstance);
        }
    }
}


/****************************************************************************
NAME    
    audio_aghfp_disconnect

DESCRIPTION
    Attempt to disconnect the AGHFP audio. 

RETURNS
    void
*/
void audio_aghfp_disconnect(void)
{
    if (AUDIO_RUNDATA.audio_routed == AUDIO_ROUTED_AGHFP)
    {
        AUDIO_RUNDATA.audio_routed = AUDIO_ROUTED_NONE;

        /* unroute audio */
        AudioDisconnect();
        /*delete the connected audio instance*/
        if(audioGetConnectedAudioInstance())
        {
            AudioInstanceDestroy(AUDIO_RUNDATA.connected_audio_instance);
            audioSetConnectedAudioInstance(NULL);
        }
    }
}


/****************************************************************************
NAME    
    audio_route_all

DESCRIPTION
    Route audio for all active connections. 

RETURNS
    void
*/
void audio_route_all(void)
{
    /* AGHFP audio */
    aghfp_route_all_audio();

    /* A2DP audio */
    a2dp_route_all_audio();
}


/****************************************************************************
NAME    
    audio_suspend_all

DESCRIPTION
    Suspend audio for all active connections. 

RETURNS
    void
*/
void audio_suspend_all(void)
{
    /* AGHFP audio */
    aghfp_suspend_all_audio();

    /* A2DP audio */
    a2dp_suspend_all_audio();
}


/****************************************************************************
NAME    
    audio_start_active_timer

DESCRIPTION
    Starts the audio active timer in USB mode if the USB audio interfaces are inactive. 
    When the timer expires the Bluetooth audio links can be suspended as no USB audio will be active.

RETURNS
    void
*/
void audio_start_active_timer(void)
{
    MessageCancelFirst(app_get_instance(), APP_USB_AUDIO_ACTIVE);
    MessageCancelFirst(app_get_instance(), APP_USB_AUDIO_INACTIVE);

#ifndef ANALOGUE_INPUT_DEVICE
    /* Audio active timer only applies to a USB device as an Analogue input device cannot be notified when audio is present */
    if ((usb_get_audioactive_timer() != TIMER_NO_TIMEOUT) &&
        (!AUDIO_RUNDATA.audio_usb_active))
    {
        /* send the audio inactive message after the PS configured delay */
        MessageSendLater(app_get_instance(), APP_USB_AUDIO_INACTIVE, 0, D_SEC(usb_get_audioactive_timer()));
    }
#endif
}


/****************************************************************************
NAME    
    audio_a2dp_update_bitpool

DESCRIPTION
    Change the bitpool for the A2DP audio. 

RETURNS
    void
*/
void audio_a2dp_update_bitpool(uint8 bitpool, uint8 bad_link_bitpool)
{
    if (AUDIO_RUNDATA.audio_routed == AUDIO_ROUTED_A2DP)
    {
        /* change A2DP SBC bitpools */
        AUDIO_RUNDATA.audio_a2dp_mode_params.bitpool = bitpool;
        AUDIO_RUNDATA.audio_a2dp_mode_params.bad_link_bitpool = bad_link_bitpool;

        AUDIO_DEBUG(("AUDIO: audio_a2dp_update_bitpool - bitpool[%d] bad_link_bitpool[%d]\n", bitpool, bad_link_bitpool));

        audio_update_mode_parameters();
    }
}


/****************************************************************************
NAME    
    audio_update_mode_parameters

DESCRIPTION
    The audio parameters have changed so update the audio mode. 

RETURNS
    void
*/
void audio_update_mode_parameters(void)
{
    AudioSetMode(volume_get_mute_mode(), &AUDIO_RUNDATA.audio_a2dp_mode_params);
}


/****************************************************************************
NAME
    audio_a2dp_get_plugin - 

DESCRIPTION
     Get the active A2DP audio plugin

RETURNS
    Task
*/
static Task audio_a2dp_get_plugin(void)
{
    return AUDIO_RUNDATA.audio_plugin;
}


/****************************************************************************
NAME
    audio_aghfp_get_plugin -

DESCRIPTION
     Get the active AGHFP audio plugin

RETURNS
    Task
*/
static Task audio_aghfp_get_plugin(bool wbs)
{
    uint32 usb_sample_rate = usb_get_speaker_sample_rate();

    if (wbs)
    {
        switch (usb_sample_rate)
        {
            case 48000:
            {
                return (TaskData *)&csr_ag_audio_sbc_48k_1mic_plugin;
            }
            case 16000:
            {
                return (TaskData *)&csr_ag_audio_sbc_16k_1mic_plugin;
            }
            default:
            {
                Panic(); /* no wide-band audio plugin for this USB sample rate */
            }
        }

        return 0;
    }

    switch (usb_sample_rate)
    {
        case 48000:
        {
            return (TaskData *)&csr_ag_audio_cvsd_48k_1mic_plugin;
        }
        case 8000:
        {
            return (TaskData *)&csr_ag_audio_cvsd_8k_1mic_plugin;
        }
        default:
        {
            Panic(); /* no narrow-band audio plugin for this USB sample rate */
        }
    }

    return 0;
}

/****************************************************************************
NAME
    audio_is_bidir_supported - 

DESCRIPTION
    Returns true if remote device supports bidirectional audio.

RETURNS
    TRUE if the bidirectional audio is suported for fast stream or aptx low latency.
    FALSE, if otherwise.
*/
static bool audio_is_bidir_supported(a2dp_codec_settings* settings)
{
    bool supported = FALSE;

    switch (settings->seid)
    {
        case A2DP_SEID_FASTSTREAM:
        {
            if ((settings->size_configured_codec_caps >= A2DP_FASTSTREAM_DIRECTION_INDEX) &&
                 (settings->configured_codec_caps[A2DP_FASTSTREAM_DIRECTION_INDEX] & A2DP_FASTSTREAM_VOICE))
            {
                supported = TRUE;
            }
        }
        break;

        case A2DP_SEID_APTX_LOW_LATENCY:
        {
            if ((settings->size_configured_codec_caps >= A2DP_APTX_DIRECTION_INDEX) &&
                (settings->configured_codec_caps[A2DP_APTX_DIRECTION_INDEX] & A2DP_APTX_LOWLATENCY_VOICE_16000))
            {
                supported = TRUE;
            }
        }
        break;

        default:
        break;
    }

    return supported;
}
/******************************************************************************
NAME
    audio_set_a2dp_conn_delay

DESCRIPTION
    Helper function to set the a2dp commection delay

RETURNS
    void
*/
void audio_set_a2dp_conn_delay(bool a2dpConnDelay)
{
    AUDIO_RUNDATA.audio_a2dp_connection_delay  = a2dpConnDelay;
}
/******************************************************************************
NAME
    audio_get_a2dp_conn_delay

DESCRIPTION
    Helper function to get the a2dp commection delay

RETURNS
    TRUE, if the A2DP connection delay is set,
    FALSE, if otherwise.
*/
bool audio_get_a2dp_conn_delay(void)
{
    return AUDIO_RUNDATA.audio_a2dp_connection_delay;
}
/******************************************************************************
NAME
audio_get_a2dp_input_device_type

DESCRIPTION
    Helper function to get the a2dp input device type.

RETURNS
        The current A2DP input device type  having the possible values: 
        0 = A2dpEncoderInputDeviceUsb,
        1 = A2dpEncoderInputDeviceAnalogue,
        2 = A2dpEncoderInputDeviceSPDIF,
        3 = A2dpEncoderInputDeviceI2S
*/
A2dpEncoderInputDeviceType audio_get_a2dp_input_device_type(void)
{
    return AUDIO_RUNDATA.audio_a2dp_connect_params.input_device_type;
}
/******************************************************************************
NAME
    audio_get_voip_music_mode(void)

DESCRIPTION
    Helper function to get the a2dp voip music mode.

RETURNS
        The current audio mode which is active .
        0 = AUDIO_MUSIC_MODE,
        1 = AUDIO_VOIP_MODE
*/
AUDIO_VOIP_MUSIC_MODE_T audio_get_voip_music_mode(void)
{
    return AUDIO_RUNDATA.audio_voip_music_mode;
}
/******************************************************************************
NAME
audio_get_audio_routed.

DESCRIPTION
    Helper function to get the audio routed types

RETURNS
    If the audio is routed either through A2DP or AGHFP else none.
    0 = AUDIO_ROUTED_NONE,
    1 = AUDIO_ROUTED_A2DP,
    2 = AUDIO_ROUTED_AGHFP
*/
AUDIO_ROUTED_T audio_get_audio_routed(void)
{
    return AUDIO_RUNDATA.audio_routed;
}
/******************************************************************************
NAME
    audio_set_aghfp_conn_delay

DESCRIPTION
    Helper function to set the a2dp connection delay

RETURNS
    void
*/
void audio_set_aghfp_conn_delay(bool aghfpConnDelay)
{
    AUDIO_RUNDATA.audio_aghfp_connection_delay = aghfpConnDelay;
}
/******************************************************************************
NAME
    audio_get_aghfp_conn_delay

DESCRIPTION
    Helper function to get the aghfp commection delay

RETURNS
    void
*/
bool audio_get_aghfp_conn_delay(void)
{
    return AUDIO_RUNDATA.audio_aghfp_connection_delay;
}
/******************************************************************************
NAME
    audio_set_usb_active_flag

DESCRIPTION
    Helper function to set the Audio usb active flag

RETURNS
    void
*/
void audio_set_usb_active_flag(bool usbactive)
{
    AUDIO_RUNDATA.audio_usb_active = usbactive;
}
/******************************************************************************
NAME
    audio_get_eq_mode

DESCRIPTION
    Helper function to get the eq_mode parameter value.

RETURNS
    The current eq mode to use. The potential values are shown below:
    A2dpEncoderEqModeBypass,
    A2dpEncoderEqMode1,
    A2dpEncoderEqMode2,
    A2dpEncoderEqMode3,
    A2dpEncoderEqMode4
*/
A2dpEncoderEqMode audio_get_eq_mode(void)
{
    return AUDIO_RUNDATA.audio_a2dp_mode_params.eq_mode;
}
/******************************************************************************
NAME
    audio_set_eq_mode

DESCRIPTION
    Helper function to sers the eq_mode parameter value.

RETURNS
    void
*/
void audio_set_eq_mode(uint8 eq_mode)
{
    AUDIO_RUNDATA.audio_a2dp_mode_params.eq_mode = eq_mode;
}
/****************************************************************************
NAME
    audioGetConnectedAudioInstance 

DESCRIPTION
    Get the connected audio instance.

RETURNS
    The pointer to the structure audio_instance_tag.
*/
static audio_instance_t audioGetConnectedAudioInstance(void)
{
    return AUDIO_RUNDATA.connected_audio_instance;
}

/****************************************************************************
NAME
    audioSetConnectedAudioInstance - 

DESCRIPTION
    Set the connected audio instance.

RETURNS
    void
*/
static void audioSetConnectedAudioInstance(audio_instance_t instance)
{
    AUDIO_RUNDATA.connected_audio_instance = instance;
}

