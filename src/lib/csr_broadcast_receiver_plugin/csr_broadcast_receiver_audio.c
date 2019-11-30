/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
   csr_broadcast_receiver_audio.c
    
DESCRIPTION
NOTES
*/
#include <stdlib.h>
#include <string.h>
#include <file.h>

#include <kalimba.h>
#include <kalimba_standard_messages.h>

#include <audio_plugin_music_variants.h>
#include <audio_plugin_music_params.h>
#include <audio_plugin_if.h>
#include <audio.h>
#include <audio_output.h>

#include <broadcast.h>
#include <broadcast_status_msg_structures.h>
#include <broadcast_msg_interface.h>
#include <broadcast_status_msg_structures.h>
#include <broadcast_stream_service_record.h>
#include <broadcast_context.h>
#include <broadcast_cmd.h>

#include <csr_i2s_audio_plugin.h>
#include <gain_utils.h>

#include <print.h>
#include <panic.h>
#include <vmal.h>

#include "csr_broadcast_receiver_audio.h"

#define STATUS_DEBUGx

/* DSP output port to left DAC */
#define DSP_OUTPUT_PORT_DAC0 0
/* DSP output port to right DAC */
#define DSP_OUTPUT_PORT_DAC1 1

/* Register 0x0C sets the headphone channel volume */
#define I2S_HEADPHONE_CHANNEL_VOLUME (0x0C)

/* Register 0x08 and 0x09 set the main channel volumes */
#define I2S_SPEAKER_CHANNEL_1_VOLUME (0x08)
#define I2S_SPEAKER_CHANNEL_2_VOLUME (0x09)

#define MUTE_NONE   ((uint16)(0))
#define MUTE_PRIMARY_LEFT   ((uint16)(1<<0))
#define MUTE_PRIMARY_RIGHT  ((uint16)(1<<1))
#define MUTE_BA_ALL_DEVICES      ((uint16)(1<<5))

/* In order to switch stream ids, at least this number of stream ids must be
   received on the new stream id */
#define STREAM_ID_SWITCH_COUNT_MIN 20

#define DSP_CSB_INPUT_PORT (0)

#define MIXED_MODE_INCREASING_DELAY 42 /* 42 ms optimum delay for increasing volume */
#define MIXED_MODE_DECREASING_DELAY 25 /* 25 ms optimum delay for decreasing volume */

/*! Maximum volume step in BA mode */
#define BA_MAX_STEPS 31

/*! DSP kap filename for receiver */
static const char kap_file_receiver[] = "csb_receiver/csb_receiver.kap";

/* The task instance pointer*/
static CSB_DECODER_t * CSB_DECODER = NULL;

/* dsp message structure*/
typedef struct
{
    uint16 id;
    uint16 a;
    uint16 b;
    uint16 c;
    uint16 d;
} DSP_REGISTER_T;

/***************************************************************************
NAME
    baCsbDecoderSendDspCeltConfig
 
DESCRIPTION
    Utility function to send CLET config to DSP
    
PARAMS
    sample_rate sample rates to which this config applies
    frame_size frame size in octets of each CELT frame
    frame_samples The number of audio samples represented by each CELT frame
    
RETURNS
    void
*/
static void baCsbDecoderSendDspCeltConfig(uint16 sample_rate, uint16 frame_size, uint16 frame_samples)
{
    KalimbaSendMessage(KALIMBA_MSG_SET_CELT_CONFIG, sample_rate,
                               frame_size, frame_samples, CELT_FRAME_CHANNELS);
}

/***************************************************************************
NAME
    baCsbDecoderConfigureCeltCodec
 
DESCRIPTION
    Utility function to Read the celt configuration from the bssr and tell the DSP
    
PARAMS
    bssr Broadcaster Stream Service Records
    bssr_len Broadcaster Stream Service Records Length
    stream_id Stream Id
    
RETURNS
    void
*/
static void baCsbDecoderConfigureCeltCodec(const uint8 *bssr, uint16 bssr_len, uint16 stream_id)
{
    uint16 instance;
    codec_config_celt config;
    for (instance = 0;
         bssrGetNthCodecConfigCelt(bssr, bssr_len, (uint8)stream_id, (uint8)instance, &config);
         instance++)
    {
        if (config.frequencies & BSSR_CODEC_FREQ_44100HZ)
        {
            baCsbDecoderSendDspCeltConfig(44100,config.frame_size, config.frame_samples);
        }
        if (config.frequencies & BSSR_CODEC_FREQ_48KHZ)
        {
            baCsbDecoderSendDspCeltConfig(48000,config.frame_size, config.frame_samples);
        }
    }
}

/****************************************************************************
DESCRIPTION
*/
static void baCsbDecoderInitVolume(int16 volume)
{
    CSB_DECODER->volume.group = audio_output_group_all; /* Always update all groups */
    CSB_DECODER->volume.main.tone = volume; /* set the initial tones volume level */
    CSB_DECODER->volume.main.master = DIGITAL_VOLUME_MUTE; /* -120dB , literally mute */
}

/*******************************************************************************/
static void populateCsbPluginFromAudioConnectData(A2dpPluginTaskdata * task, const AUDIO_PLUGIN_CONNECT_MSG_T * const connect_message)
{
    CSB_DECODER = (CSB_DECODER_t*)PanicUnlessMalloc(sizeof (CSB_DECODER_t));
    memset(CSB_DECODER,0, sizeof(CSB_DECODER_t));

    CSB_DECODER->task = task;
    CSB_DECODER->a2dp_plugin_variant = task->a2dp_plugin_variant;
    CSB_DECODER->params     = connect_message->params;
    CSB_DECODER->mode  = connect_message->mode;
    CSB_DECODER->mode_params = 0;
    CSB_DECODER->rate       = connect_message->rate;
    CSB_DECODER->app_task = connect_message->app_task;
    CSB_DECODER->ba_volume = connect_message->volume;
    baCsbDecoderInitVolume(connect_message->volume);
    CSB_DECODER->mute_state[audio_mute_group_main] = AUDIO_MUTE_DISABLE;
    CSB_DECODER->mute_state[audio_mute_group_aux] = AUDIO_MUTE_DISABLE;
    CSB_DECODER->mute_state[audio_mute_group_mic] = AUDIO_MUTE_DISABLE;
    PRINT(("CSB_DECODER: connect CELT Decoder \n"));
}

/****************************************************************************
DESCRIPTION
    Disconnected local speaker output
*/
static void baCsbDecoderDisconnectLocalAudioOutput(void)
{
    PRINT(("CSB_DECODER: baCsbDecoderDisconnectLocalAudioOutput\n"));
    PanicFalse(AudioOutputDisconnect());
}

/****************************************************************************
DESCRIPTION
    
*/
static void baCsbDecoderHandleStreamIdCounts(ec_input_stats_t *stats)
{
    /* First determine if the stream id has changed. We will only switch stream
       ids when we are sure the new stream id is stable. */
    unsigned int i;
    unsigned int non_zero_counts = 0;
    stream_id_count_t counts;
    for (i = 0; i < EC_STREAM_ID_COUNT_TABLE_SIZE; i++)
    {
        if (stats->stream_id_counts[i].count)
        {
            non_zero_counts++;
            /* Copy the structure to get counts.stream_id and counts.count. */
            counts = stats->stream_id_counts[i];
        }
    }
    /* There must be exactly one non-zero count:
         Zero non-zero counts indicates nothing is being received, so there is
         no information on which to base a switch of stream id.
         Multiple non-zero counts indicates multiple stream IDs are being received.
         This is a sign of transition between stream ids (in which case we'll
         just wait for the next stats message at which point the transision should
         be complete) or some other unusual condition. Either way take no action
         until the stream id is stable. */
    if (non_zero_counts == 1 &&
        (counts.stream_id != BroadcastContextGetStreamId()) &&
        counts.count > STREAM_ID_SWITCH_COUNT_MIN)
    {
        /* Read the BSSR from PS */
        uint16 bssr_len_words = BroadcastContextGetBssrConfigLength();
        if (!bssr_len_words)
        {
            /* This should not happen. But if for some reason it has happened,
               we need to reassociate to read the BSSR. This could be performed
               automatically, however, this application will just delete the
               association from ps and panic. The user will have to manually
               reassociate. */
            PRINT(("CSB_DECODER: Unable to read BSSR from PS\n"));
            MessageSend(CSB_DECODER->app_task, AUDIO_BA_RECEIVER_RESET_BD_ADDRESS, NULL);
            Panic();
        }
        else
        {
           const uint8 *bssr =  NULL;
           /* Whatever happens below, update the stream id. This means that
               future stream id changes (e.g. back to a supported stream id)
               will be detected. */
            BroadcastContextSetStreamId((uint16)counts.stream_id);
            if(!BroadcastContextGetBssrConfig(&bssr, &bssr_len_words))
            {
                PRINT(("CSB_DECODER: BSSR is not set by application\n"));
            }
            if (BroadcastContextStreamCanBeReceived(bssr, bssr_len_words, (uint8)counts.stream_id))
            {
                PRINT(("CSB_DECODER: Switching to stream id %u\n", counts.stream_id));
                baCsbDecoderConfigureCeltCodec(bssr, bssr_len_words, (uint16)counts.stream_id);
                KalimbaSendMessage(KALIMBA_MSG_SET_STREAM_ID, (uint16)counts.stream_id, 0, 0 ,0);
            }
            else
            {
                PRINT(("CSB_DECODER: Unable to receive new stream id %u\n", counts.stream_id));
            }
        }
    }
}

/****************************************************************************
DESCRIPTION
    Cancel all dsp related messages
*/
static void baCsbDecoderCancelDspMessages(A2dpPluginTaskdata * task)
{
    MessageCancelAll( (TaskData*) task, MESSAGE_FROM_KALIMBA);
    MessageKalimbaTask( (TaskData*)task );
}

/****************************************************************************
DESCRIPTION
    Load the requested dsp resources
*/
static void baCsbDecoderLoadDSP(void)
{
    /* Load DSP code */
    PanicFalse(KalimbaLoad(FileFind(FILE_ROOT, kap_file_receiver, sizeof(kap_file_receiver) - 1)));
}

/****************************************************************************
DESCRIPTION
    Handles the Broadcast Status message from DSP
*/
static void baCsbDecoderHandleCsbStatusMessage(MessageFromKalimbaLong *kal_msg)
{
    if(!CSB_DECODER)
    {
        PRINT(("CSB_DECODER: CSB_DECODER is NULL ignore the CSB status\n"));
        return;
    }

    if (kal_msg->len == sizeof(broadcast_status_receiver_t))
    {
        broadcast_status_receiver_t *msg;
        broadcast_encr_config_t *encr = NULL;
        msg = (broadcast_status_receiver_t*)kal_msg->data;
        if (!(msg->audio_output_status & 0x01))
        {
#ifdef STATUS_DEBUG
            PRINT(("CSB_DECODER: Indicate Streaming State\n"));
#endif
            MessageSend(CSB_DECODER->app_task, AUDIO_BA_RECEIVER_INDICATE_STREAMING_STATE, NULL);
        }
#ifdef STATUS_DEBUG
        {
            unsigned int i;
            PRINT(("aos=%u,cipr=%u,cimf=%u,cisr=%u,civ=%u,ciip=%u",
                       msg->audio_output_status,
                       msg->csb_input_packets_received,
                       msg->csb_input_mac_failures,
                       msg->csb_input_sample_rate,
                       msg->csb_input_volume,
                       msg->csb_input_invalid_packets));
            for (i = 0; i < EC_STREAM_ID_COUNT_TABLE_SIZE; i++)
            {
                PRINT((",%u:sid=%u,cnt=%u", i,
                           msg->ec_input_stats.stream_id_counts[i].stream_id,
                           msg->ec_input_stats.stream_id_counts[i].count));
            }
            PRINT((",ecidp="));
            for (i = 0; i < EC_2_5_PAIR_COMBINATIONS; i++)
            {
                PRINT(("%u,", msg->ec_input_stats.decoded_pairs[i]));
            }
            PRINT(("ecidf=%u", msg->ec_input_stats.decode_failures));
            PRINT(("\n"));
        }
#endif

        baCsbDecoderHandleStreamIdCounts(&msg->ec_input_stats);

        encr = BroadcastContextGetEncryptionConfig();
        /* if we're getting mac failures, but we think we have a variant IV,
         * then look again, it probably changed */
        if (encr && (msg->csb_input_mac_failures != 0) &&
            (encr->variant_iv != 0))
        {
            PRINT(("CSB_DECODER:KAL: MAC FAILURES - Search for new Variant IV\n"));
            BroadcastStopReceiver(BroadcastContextGetBroadcastHandle());
            /* Post a Upstream DSP message to App to handle this */
            MessageSend(CSB_DECODER->app_task, AUDIO_BA_RECEIVER_START_SCAN_VARIANT_IV, NULL);
        }
    }
    else
    {
        PRINT(("CSB_DECODER :KALIMBA_MSG_BROADCAST_STATUS message length mismatch\n"));
    }
}

/****************************************************************************
DESCRIPTION
    Handles the SCM message from DSP
*/
static void baCsbDecoderHandleScmMessage(const uint16 id, MessageFromKalimba * message)
{
    switch(id)
    {
        case KALIMBA_MSG_SCM_SEGMENT_IND:
        {
            uint8 data[3];
            PRINT(("scm_segment header:%02x, payload:%02x%04x\n",
                       message->data[0],
                       message->data[1] & 0xFF,
                       message->data[2] & 0xFFFF));
            data[0] = (uint8)((message->data[1] >> 0) & 0xFF);
            data[1] = (uint8)((message->data[2] >> 8) & 0xFF);
            data[2] = (uint8)((message->data[2] >> 0) & 0xFF);
            BroadcastCmdScmSeqmentInd(message->data[0], data);
        }
        break;

        case KALIMBA_MSG_SCM_SEGMENT_EXPIRED:
        {
            PRINT(("scm_segment_expired header:%02x\n", message->data[0]));
            BroadcastCmdScmSeqmentExpiredInd(message->data[0]);
        }
        break;

        default:
        break;
    }
}

/***************************************************************************
NAME
    baCsbDecoderSendDspEncConfig
 
DESCRIPTION
    Utility function to send Encryption Config to DSP

PARAMS
    void
 
RETURNS
    void
*/
static void baCsbDecoderSendDspEncConfig(void)
{
    broadcast_encr_config_t* encr = NULL;

    encr = BroadcastContextGetEncryptionConfig();

    if(encr)
    {
        PRINT(("CSB_DECODER: setupReceiverAudio SecKey: %x-%x-%x\n",encr->seckey[0],
                                                             encr->seckey[1],
                                                             encr->seckey[2]));
        PanicFalse(KalimbaSendLongMessage(KALIMBA_MSG_SET_KEY, (sizeof(encr->seckey) - 1),
                                          &encr->seckey[1]));
        PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SET_FIXED_IV, encr->fixed_iv[0],
                                      encr->fixed_iv[1], encr->fixed_iv[2], 0));
        PRINT(("CSB_DECODER: setupReceiverAudio Variant IV: %x\n", encr->variant_iv));
        PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SET_IV, encr->variant_iv, 0, 0, 0));
    }
}

/***************************************************************************
NAME
    baCsbDecoderSendDspSampleRate
 
DESCRIPTION
    Utility function to send Sample rate information to DSP

PARAMS
    uint16 Sample Rate
 
RETURNS
    void
*/
static void baCsbDecoderSendDspSampleRate(uint16 rate)
{
    /* Inform the DSP of the sample rate */
    PanicFalse(KalimbaSendMessage(KALIMBA_MSG_AUDIO_SAMPLE_RATE, rate >> 8, rate & 0xFF, 0, 0));

    KALIMBA_SEND_MESSAGE(MESSAGE_SET_MUSIC_MANAGER_SAMPLE_RATE,
                                CSB_DECODER->dsp_resample_rate,
                                0, 0, OUTPUT_INTERFACE_TYPE_NONE);

    /* Set input codec rate to DSP */
    KALIMBA_SEND_MESSAGE(MESSAGE_SET_CODEC_SAMPLE_RATE,
                                (uint16)(rate/DSP_RESAMPLING_RATE_COEFFICIENT),
                                 0, 0, 0);
}

/***************************************************************************
NAME
    baCsbDecoderSendDspBroadcastConfig
 
DESCRIPTION
    Utility function to send Broadcast Configuration to DSP

PARAMS
    void
 
RETURNS
    void
*/
static void baCsbDecoderSendDspBroadcastConfig(void)
{
    uint16 interval;
    PanicNotZero(BroadcastReceiverGetCSBInterval(BroadcastContextGetBroadcastHandle(), &interval));
    PRINT(("CSB_DECODER: setupReceiverAudio CSB Interval: %u\n", interval));
    PanicFalse(KalimbaSendMessage(KALIMBA_MSG_BROADCAST_CONFIG, interval, 0, 0, 0));
}

/***************************************************************************
NAME
    baCsbDecoderSendDspStreamId
 
DESCRIPTION
    Utility function to set Stream ID in DSP

PARAMS
    void
 
RETURNS
    void
*/
static void baCsbDecoderSendDspStreamId(void)
{
    PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SET_STREAM_ID, BroadcastContextGetStreamId(), 0, 0, 0));
}

/****************************************************************************
DESCRIPTION
    Connect dsp to speaker ouptuts
*/
static void baCsbDecoderConnectDspOutputs(audio_output_params_t* params)
{
    PRINT(("CSB_DECODER: baCsbDecoderConnectDspOutputs\n"));
    /* BA only supports primary outputs, connect only those ports */
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_DAC0), audio_output_primary_left);
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_DAC1), audio_output_primary_right);
    AudioOutputConnectOrPanic(params);
}

/****************************************************************************
DESCRIPTION
   Connect the local audio stream through DSP
*/
static void baCsbDecoderConnectLocalAudioOutput(uint32 rate)
{
    audio_output_params_t params;
    memset(&params, 0, sizeof(audio_output_params_t));
    /* Now set the DAC rate */
    params.sample_rate = rate;
    params.disable_resample = FALSE;

    /* Store adjusted sample rate returned from multi-channel plugin */
    CSB_DECODER->dsp_resample_rate = (uint16)(AudioOutputGetSampleRate(&params, 0)/DSP_RESAMPLING_RATE_COEFFICIENT);
    baCsbDecoderConnectDspOutputs(&params);
}

/***************************************************************************
NAME
    baCsbDecoderSetupAudio
 
DESCRIPTION
    Utility function to Connect DSP to DACs
 
PARAMS
    rate Sampling Frequency
 
RETURNS
    void
*/
static void baCsbDecoderSetupAudio(uint32 rate)
{
    /* update the current audio state */
    SetAudioInUse(TRUE);
    /* Connect DSP to DACs */
    baCsbDecoderConnectLocalAudioOutput(rate);
    baCsbDecoderSendDspSampleRate((uint16)rate);
    baCsbDecoderSendDspEncConfig();

    baCsbDecoderSendDspBroadcastConfig();
    BroadcastContextSetStreamId(0);
    baCsbDecoderSendDspStreamId();
}

/****************************************************************************
DESCRIPTION
    utility function to set the current EQ operating mode

    @return void
*/
static void baCsbDecoderPluginSetEqMode(uint16 operating_mode, A2DP_MUSIC_PROCESSING_T music_processing, A2dpPluginModeParams *mode_params)
{
    /* determine the music processing mode requirements, set dsp music mode appropriately */
    switch (music_processing)
    {
        case A2DP_MUSIC_PROCESSING_PASSTHROUGH:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , MUSIC_SYSMODE_PASSTHRU , MUSIC_DO_NOT_CHANGE_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)) );
                PRINT(("CSB_DECODER: Set Music Mode SYSMODE_PASSTHRU\n"));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_DO_NOT_CHANGE_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode SYSMODE_FULLPROC\n"));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_NEXT_EQ_BANK:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_NEXT_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode %d and advance to next EQ bank\n", operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK0:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode %d and set EQ bank 0\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK1:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 1, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode %d and set EQ bank 1\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK2:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 2, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode %d and set EQ bank 2\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK3:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 3, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode %d and set EQ bank 3\n",operating_mode));
            }
            break;
        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK4:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 4, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode %d and set EQ bank 4\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK5:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 5, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode %d and set EQ bank 5\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK6:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 6, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("CSB_DECODER: Set Music Mode %d and set EQ bank 6\n",operating_mode));
            }
            break;

        default:
            {
                PRINT(("CSB_DECODER: Set Music Mode Invalid [%x]\n" , music_processing ));
            }
            break;
    }
}

/*******************************************************************************/
static void setupUserEq(void)
{
    A2dpPluginModeParams *mode_params = NULL;
    A2dpPluginConnectParams* codec_data = (A2dpPluginConnectParams *) CSB_DECODER->params;;

    if((codec_data != NULL) && (codec_data->mode_params != NULL))
    {
        mode_params = codec_data->mode_params;
    }
    CsrBaReceiverAudioPluginSetMode(CSB_DECODER->mode, mode_params);
}

/****************************************************************************
DESCRIPTION
    Reconnects the audio after a tone has completed
*/
static void baCsbDecoderDspToneComplete ( void )
{
    PRINT(("CSB_DECODER: Tone Complete\n")) ;

    /* ensure plugin hasn't unloaded before dsp message was received */
    if(CSB_DECODER)
    {
        /*we no longer want to receive stream indications*/
        VmalMessageSinkTask(StreamKalimbaSink(TONE_VP_MIXING_DSP_PORT), NULL);
    }
    if(AudioIsAudioPromptPlaying())
    {
        /*
         * unblock messages waiting for tone to complete and trigger a voice
         * prompt cleanup if required
         */
        AudioSetAudioPromptPlayingTask((Task)NULL);
        SetAudioBusy(NULL) ;
    }
}


/****************************************************************************
DESCRIPTION
    Standby mode
*/
static void baCsbDecoderDspStandby(A2dpPluginModeParams *mode_params)
{
    /* ensure mode_params has been set before use */
    if (mode_params)
    {
        KALIMBA_SEND_MESSAGE(MUSIC_SETMODE_MSG, MUSIC_SYSMODE_STANDBY, MUSIC_DO_NOT_CHANGE_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
    }
}

/*******************************************************************************/
static void baCsbDecoderModeConnected(A2DP_MUSIC_PROCESSING_T music_processing, A2dpPluginModeParams* mode_params)
{
    PRINT(("CSB_DECODER: baCsbDecoderModeConnected()\n"));
    /* ensure mode_params has been set before use */
    if (mode_params)
    {
        /* Update DSP mode if necessary */
        baCsbDecoderPluginSetEqMode(MUSIC_SYSMODE_FULLPROC, music_processing,
                mode_params);
    }
}

/****************************************************************************
DESCRIPTION
    Function to set the hardware volume (used to set hardware volume after
    a delay when using hybrid volume control).
*/
static void baCsbDecoderSetHardwareGainDelayed(audio_output_group_t group, int16 master_gain, uint16 delay_ms)
{
    if(CSB_DECODER->task)
    {
        MAKE_AUDIO_MESSAGE(AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG, message);
        message->group  = group;
        message->master = master_gain;
        MessageSendLater((Task)CSB_DECODER->task, AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG, message, delay_ms);
    }
    else
    {
        AudioOutputGainSetHardware(group, master_gain, NULL);
    }
}

/****************************************************************************
DESCRIPTION
    Obtains the mute mask value for the Main output group.
    Return Mute mask value.
*/
static uint16 baCsbGetMainMuteMask(AUDIO_MUTE_STATE_T state)
{
    uint16 mute_mask = MUTE_NONE;
    PRINT(("CSB_DECODER: baCsbGetMainMuteMask \n"));

    if ( state == AUDIO_MUTE_ENABLE)
    {
        mute_mask |= (MUTE_PRIMARY_LEFT | MUTE_PRIMARY_RIGHT | MUTE_BA_ALL_DEVICES);
    }
    return mute_mask;
}

/******************************************************************************
DESCRIPTION
    Send volume message to Kalimba
*/
static void baCsbDecoderSendDspVolume(audio_output_group_t group, audio_output_gain_t* gain_info)
{
    /* Send the correct volume message for this output group */
    if(group == audio_output_group_main)
    {
        KALIMBA_SEND_MESSAGE(MUSIC_VOLUME_MSG_S, 1, (uint16)gain_info->trim.main.primary_left, (uint16)gain_info->trim.main.primary_right, 0);
        KALIMBA_SEND_MESSAGE(MUSIC_VOLUME_MSG_S, 2, (uint16)gain_info->trim.main.secondary_left, (uint16)gain_info->trim.main.secondary_right, (uint16)gain_info->trim.main.wired_sub);
        KALIMBA_SEND_MESSAGE(MUSIC_VOLUME_MSG_S, 0, (uint16)gain_info->common.system, (uint16)gain_info->common.master, (uint16)gain_info->common.tone);
    }
    else
    {
        KALIMBA_SEND_MESSAGE(MUSIC_VOLUME_AUX_MSG_S, 1, (uint16)gain_info->trim.aux.aux_left, (uint16)gain_info->trim.aux.aux_left, 0);
        KALIMBA_SEND_MESSAGE(MUSIC_VOLUME_AUX_MSG_S, 0, (uint16)gain_info->common.system, (uint16)gain_info->common.master, (uint16)gain_info->common.tone);
    }
}

/****************************************************************************
DESCRIPTION
    Set the volume levels for a group (either main or aux, not all)
*/
static void baCsbDecoderPluginSetGroupLevels(audio_output_group_t group, int16 master, int16 tone)
{
    audio_output_gain_t gain_info;

    /* Get the previous gain for this group */
    int16 prev_gain = (group == audio_output_group_main) ? CSB_DECODER->volume.main.master :
                                                            CSB_DECODER->volume.aux.master;

/* TODO: Need to access how to achive this as BA does not have input audio only mute functionality 
    if(BA_DECODER->input_audio_port_mute_active)
    {
        PRINT(("Input Mute Active, overriding volume"));
        master = DIGITAL_VOLUME_MUTE;
    }*/

    PRINT(("%s vol %d dB/60\n", (group == audio_output_group_main) ? "Main" : "Aux", master));

    /* Get the digital gain settings to apply */
    AudioOutputGainGetDigital(group, master, tone, &gain_info);

    switch(AudioOutputGainGetType(group))
    {
        case audio_output_gain_hardware:
        {
            /* Apply hardware gain */
            AudioOutputGainSetHardware(group, master, NULL);
        }
        break;

        case audio_output_gain_hybrid:
        {
            uint16 hw_delay_ms = (master >= prev_gain) ? MIXED_MODE_INCREASING_DELAY :
                                                         MIXED_MODE_DECREASING_DELAY;
            /* Set hardware gain after a delay (delay is tuned to ensure digital and hardware gains happen simultaneously) */
            baCsbDecoderSetHardwareGainDelayed(group, master, hw_delay_ms);
        }
        break;

        case audio_output_gain_digital:
        case audio_output_gain_invalid:
        default:
            /* Set hardware gain to fixed level */
            AudioOutputGainSetHardware(group, master, NULL);
        break;
    }

    baCsbDecoderSendDspVolume(group, &gain_info);
}

/****************************************************************************
DESCRIPTION
    Update the volume levels for a group (either main or aux, not all)
*/
static void baCsbDecoderPluginUpdateVolume(int16 master)
{
    PRINT(("total applied gain %d\n", master));
    baCsbDecoderPluginSetGroupLevels(audio_output_group_main, master, CSB_DECODER->volume.main.tone);
}

/****************************************************************************
DESCRIPTION
    Update the volume info stored in DECODER->volume
*/
static void baCsbDecoderUpdateStoredVolume(AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T* volume_msg)
{
    if(volume_msg->group == audio_output_group_main || volume_msg->group == audio_output_group_all)
        CSB_DECODER->volume.main = volume_msg->main;
    if(volume_msg->group == audio_output_group_aux || volume_msg->group == audio_output_group_all)
        CSB_DECODER->volume.aux = volume_msg->aux;
}

/****************************************************************************
DESCRIPTION
    Function to update the volume levels
*/
static void baCsbDecoderPluginSetLevels(AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T * volume_msg)
{
    /* Update stored volume once level has been set to ensure correct
       detection of increase/decrease when setting hybrid volume level */
    baCsbDecoderUpdateStoredVolume(volume_msg);
}

/****************************************************************************
DESCRIPTION
    Apply mute state to an audio group
*/
static void baCsbMuteOutput(audio_output_group_t group, AUDIO_MUTE_STATE_T state)
{
    PRINT(("CSB_DECODER: %smute ", (state == AUDIO_MUTE_DISABLE) ? "un-" : ""));

    if ((group == audio_output_group_main || group == audio_output_group_all))
    {
        PRINT(("main\n"));
        if(CSB_DECODER->mute_state[audio_mute_group_main] != state)
        {
            KALIMBA_SEND_MESSAGE(MESSAGE_MULTI_CHANNEL_MUTE_MAIN_S, baCsbGetMainMuteMask(state), 0, 0, 0);
            CSB_DECODER->mute_state[audio_mute_group_main] = state;
        }
    }
}

/******************************************************************************
DESCRIPTION
    Get the AUDIO_MUTE_STATE_T from a mute mask for a group. NB. group must not
    be audio_mute_group_all
*/
static AUDIO_MUTE_STATE_T baCsbGetMuteState(audio_output_group_t group, uint16 mute_mask)
{
    AUDIO_MUTE_STATE_T state = AUDIO_MUTE_DISABLE;

    PanicFalse(group != audio_output_group_all);

    if(mute_mask & AUDIO_MUTE_MASK(group))
        state = AUDIO_MUTE_ENABLE;

    return state;
}

/******************************************************************************
DESCRIPTION
    Take a mute mask and apply the setting for the main or aux group.
*/
static void baCsbApplyMuteMask(audio_output_group_t group, uint16 mute_mask)
{
    /* Can only apply main or aux here */
    PanicFalse(group == audio_output_group_main || group == audio_output_group_aux);

    /* Convert mask to AUDIO_MUTE_STATE_T and apply */
    baCsbMuteOutput(group, baCsbGetMuteState(group, mute_mask));
}

/******************************************************************************
DESCRIPTION
    Disconnects the local audio output & powers off the Kalimba
*/
static void disconnectLocalOutputAndPowerOffKalimba(A2dpPluginTaskdata * task)
{
    /* ensure nothing interrupts this sequence of events */
    SetAudioBusy((TaskData*) task);

    baCsbDecoderDisconnectLocalAudioOutput();

    /* Disconnect DSP from CSB source */
    StreamDisconnect(0, StreamKalimbaSink(DSP_CSB_INPUT_PORT));

    /* Power off DSP */
    KalimbaPowerOff();

    MessageKalimbaTask(NULL);

    (void)MessageCancelAll((TaskData*)task, MESSAGE_FROM_KALIMBA);
    (void)MessageCancelAll((TaskData*)task, MESSAGE_FROM_KALIMBA_LONG);

    /* update current dsp status */
    SetCurrentDspStatus( DSP_NOT_LOADED );

    SetAudioInUse(FALSE);

    /* Send an upstream mesage to receiver application to clean any pending scm messages in the list */
    MessageSend(CSB_DECODER->app_task, AUDIO_BA_RECEIVER_RESET_SCM_RECEIVER, NULL);
}

/******************************************************************************
DESCRIPTION
    Loads the Kalimba
*/
static void loadKalimba(A2dpPluginTaskdata * task)
{
    /* update current dsp status */
    SetCurrentDspStatus(DSP_LOADING);

    baCsbDecoderCancelDspMessages(task);

    baCsbDecoderLoadDSP();

    /* update current dsp status */
    SetCurrentDspStatus( DSP_LOADED_IDLE );
}

/******************************************************************************
DESCRIPTION
    On CSB sample rate changed indication, reload the DSP
*/
static void baReloadDspOnCsbSampleRateChange(A2dpPluginTaskdata * task, uint32 new_sample_rate)
{

    PRINT(("CSB_DECODER: CSB sample rate has changed\n"));
    PRINT(("CSB_DECODER: First disconnect local audio & power off Kalimba\n"));

    /* ensure nothing interrupts this sequence of events */
    SetAudioBusy((TaskData*) task);

    disconnectLocalOutputAndPowerOffKalimba(task);

    PRINT(("CSB_DECODER: Now reload the receiver kap file & connect audio with new CSB sample rate\n"));

    CSB_DECODER->rate = new_sample_rate;
    loadKalimba(task);
}

/*******************************************************************************/
void CsrBaReceiverAudioPluginSetMode( AUDIO_MODE_T mode , const void * params )
{
    /* set the dsp into the correct operating mode with regards to mute and enhancements */
    A2dpPluginModeParams *mode_params = NULL;
    A2DP_MUSIC_PROCESSING_T music_processing = A2DP_MUSIC_PROCESSING_PASSTHROUGH;

    if (!CSB_DECODER)
        Panic() ;

    /* mode not already set so set it */
    CSB_DECODER->mode = mode;

    /* check whether any operating mode parameters were passed in via the audio connect */
    if (params)
    {
        /* if mode parameters supplied then use these */
        mode_params = (A2dpPluginModeParams *)params;
        music_processing = mode_params->music_mode_processing;
        CSB_DECODER->mode_params = mode_params;
    }
    /* no operating mode params were passed in, use previous ones if available */
    else if (CSB_DECODER->mode_params)
    {
        /* if previous mode params exist then revert to back to use these */
        mode_params = (A2dpPluginModeParams *)CSB_DECODER->mode_params;
        music_processing = mode_params->music_mode_processing;
    }

    /* determine current operating mode */
    switch(mode)
    {
        case AUDIO_MODE_STANDBY:
        {
            baCsbDecoderDspStandby(mode_params);
        }
        break;

        case AUDIO_MODE_CONNECTED:
        {
            baCsbDecoderModeConnected(music_processing, mode_params);
        }
        break;
        case AUDIO_MODE_MUTE_MIC:
        case AUDIO_MODE_MUTE_SPEAKER:
        case AUDIO_MODE_MUTE_BOTH:
        case AUDIO_MODE_UNMUTE_SPEAKER:
        {
            PRINT(("CSB_DECODER: *** Muting via SET_MODE_MSG is deprecated ***\n"));
            PRINT(("CSB_DECODER: Use SET_SOFT_MUTE_MSG instead\n"));
            Panic();
        }
        break;

        case AUDIO_MODE_LEFT_PASSTHRU:
        case AUDIO_MODE_RIGHT_PASSTHRU:
        case AUDIO_MODE_LOW_VOLUME:
        default:
        {
            PRINT(("CSB_DECODER: Set Audio Mode Invalid [%x]\n", mode));
        }
        break;
    }
}

/****************************************************************************
DESCRIPTION
*/
void CsrBaReceiverAudioPluginSetVolume(AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T *volumeDsp)
{
    if(CSB_DECODER && volumeDsp)
    {
        /* set the volume levels according to volume control type */
        baCsbDecoderPluginSetLevels(volumeDsp );
    }
}

/****************************************************************************
DESCRIPTION
    function to set the volume levels of the dsp after a preset delay
*/
void CsrBaReceiverAudioPluginSetHardwareLevels(AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG_T * message)
{
    PRINT(("CSB_DECODER: DSP Hybrid Delayed Gains: Group = %d Master Gain = %d\n", message->group, message->master));
    AudioOutputGainSetHardware(message->group, message->master, NULL);
}

/*******************************************************************************/
void CsrBaReceiverAudioPluginSetSoftMute(AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T *message)
{
    if(CSB_DECODER)
    {

        uint16 mute_mask = message->mute_states;
        /* Apply mute mask for main group. */
        baCsbApplyMuteMask(audio_output_group_main, mute_mask);
    }
}

/****************************************************************************
DESCRIPTION
*/
void CsrBaReceiverAudioPluginConnect(A2dpPluginTaskdata * task, const AUDIO_PLUGIN_CONNECT_MSG_T * const connect_msg)
{
    if(CSB_DECODER)
    {
        /* Disconnect plugin? */
        PRINT(("CSB_DECODER: CsrBaReceiverAudioPluginConnect Already connected, Disconnect?? \n"));
    }

    populateCsbPluginFromAudioConnectData(task, connect_msg);

    /*signal that the audio is busy until the kalimba / parameters are fully loaded so that no tone messages etc will arrive*/
    SetAudioBusy((TaskData*) task);

    loadKalimba(task);

    PRINT(("CSB_DECODER: CsrBaReceiverAudioPluginConnect completed\n"));
}

/****************************************************************************
DESCRIPTION
*/
void CsrBaReceiverAudioPluginDisconnect(const A2dpPluginTaskdata * const task)
{
    if (!CSB_DECODER)
    {
        PRINT(("CSB_DECODER: CsrBaReceiverAudioPluginDisconnect, nothing to disconnect\n"));
        return; /* nothing to disconnect */
    }

    PRINT(("CSB_DECODER: Disconnect output speakers and connected audio source\n"));

    /* ensure nothing interrupts this sequence of events */
    SetAudioBusy((TaskData*) task);

    disconnectLocalOutputAndPowerOffKalimba((A2dpPluginTaskdata *)task);

    SetAudioBusy(NULL);
    free (CSB_DECODER);
    CSB_DECODER = NULL;

    PRINT(("CSB_DECODER: Disconnect\n"));

}

/****************************************************************************
DESCRIPTION
   handles the internal BA plugin messages /  messages from the dsp
*/
void CsrBaReceiverAudioPluginInternalMessage(A2dpPluginTaskdata * task,
                                            const uint16 id, const Message message)
{
    UNUSED(task);
    switch(id)
    {
        case MESSAGE_FROM_KALIMBA_LONG:
        {
            MessageFromKalimbaLong *kal_msg = (MessageFromKalimbaLong *)message;
            switch (kal_msg->id)
            {
                case KALIMBA_MSG_BROADCAST_STATUS:
                    {
                        baCsbDecoderHandleCsbStatusMessage(kal_msg);
                    }
                    break;
                default:
                    PRINT(("CSB_DECODER: Unhandled long Kalimba message, ID %04x\n", kal_msg->id));
                    break;
            }
        }
        break;
        case MESSAGE_FROM_KALIMBA:
        {
            MessageFromKalimba *kal_msg = (MessageFromKalimba *)message;
            switch (kal_msg->id)
            {
                case MUSIC_READY_MSG:
                {
                    PRINT(("CSB_DECODER: MUSIC READY received\n"));
                    PanicFalse(KalimbaSendMessage(MUSIC_LOADPARAMS_MSG, MUSIC_PS_BASE, 0, 0 ,0));
                }
                break;

                case MUSIC_PARAMS_LOADED_MSG:
                {
                    PRINT(("CSB_DECODER: MUSIC_PARAMS_LOADED_MSG received\n"));
                    /* Disconnect the source in case it was being ConnectDispose'd */
                    StreamDisconnect(BroadcastContextGetReceiverSource(), 0);

                    /* Connect receiver source stream to DSP sink */
                    PanicFalse(StreamConnect(BroadcastContextGetReceiverSource(), StreamKalimbaSink(DSP_CSB_INPUT_PORT)));

                    baCsbDecoderSetupAudio(CSB_DECODER->rate);
                    setupUserEq();

                    /* Start DSP main loop running */
                    PanicFalse(KalimbaSendMessage(KALIMBA_MSG_GO, 0, 0, 0, 0)); 
                    /* update current dsp status */
                    SetCurrentDspStatus( DSP_RUNNING);
                    SetAudioBusy( NULL );
                }
                break;

                /* message from DSP when tone or voice prompt has completed playing */
                case MUSIC_TONE_COMPLETE:
                {
                    /* stop tone and clear up status flags */
                    baCsbDecoderDspToneComplete() ;
                }
                break;

                case KALIMBA_MSG_CSB_SAMPLE_RATE_CHANGED:
                    PRINT(("CSB_DECODER: New sample rate %u\n", (kal_msg->data[0] << 8) + kal_msg->data[1]));
                    baReloadDspOnCsbSampleRateChange(task,(uint32)((kal_msg->data[0] << 8) + kal_msg->data[1]));
                    break;

                case KALIMBA_MSG_AUDIO_STATUS:
                    PRINT(("CSB_DECODER: New audio status %u\n", kal_msg->data[0]));
                    break;

                case KALIMBA_MSG_VOLUME_IND:
                    PRINT(("volume ind global:%u, actual:%u\n", kal_msg->data[0], kal_msg->data[2]));
                    baCsbDecoderPluginUpdateVolume(ConvertBroadcastVolumeTodB(kal_msg->data[0], BroadcastContextGetVolumeTable()));
                    break;

                case MUSIC_CUR_EQ_BANK:
                {
                    if (CSB_DECODER)
                    {
                        const DSP_REGISTER_T *kal_eq_msg = (const DSP_REGISTER_T *) message;
                        MAKE_AUDIO_MESSAGE_WITH_LEN(AUDIO_DSP_IND, 1, dsp_ind_message);
                        PRINT(("CSB_DECODER: Current EQ setting: [%x][%x]\n", kal_eq_msg->a, kal_eq_msg->b));
                        dsp_ind_message->id = A2DP_MUSIC_MSG_CUR_EQ_BANK;
                        dsp_ind_message->size_value = 1;
                        dsp_ind_message->value[0] = kal_eq_msg->a;
                        MessageSend(CSB_DECODER->app_task, AUDIO_DSP_IND, dsp_ind_message);
                    }
                }
                break;

                case KALIMBA_MSG_SCM_SEGMENT_IND:
                case KALIMBA_MSG_SCM_SEGMENT_EXPIRED:
                    baCsbDecoderHandleScmMessage(kal_msg->id, kal_msg);
                break;

                case KALIMBA_MSG_AFH_CHANNEL_MAP_CHANGE_PENDING:
                {
                    PRINT(("CSB_DECODER: afh_channel_map_change_pending\n"));
                    MessageSend(CSB_DECODER->app_task, AUDIO_BA_RECEIVER_AFH_CHANNEL_MAP_CHANGE_PENDING, NULL);
                }
                break;

                default:
                    PRINT(("CSB_DECODER: Unhandled Kalimba message, ID %04x\n", kal_msg->id));
                    break; 
            }
        }
        break;

        default :
        break;
    }
}

#ifdef HOSTED_TEST_ENVIRONMENT
/****************************************************************************
DESCRIPTION
    Reset any static variables
    This is only intended for unit test and will panic if called in a release build.
*/
void CsrBaReceiverAudioPluginTestReset(void)
{
    if (CSB_DECODER)
    {
        memset(CSB_DECODER, 0, sizeof(CSB_DECODER_t));
        free(CSB_DECODER);
        CSB_DECODER = NULL;
    }
}
#endif
