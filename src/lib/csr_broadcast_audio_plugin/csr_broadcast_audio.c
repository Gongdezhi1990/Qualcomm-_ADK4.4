/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
   csr_broadcast_audio.c
    
DESCRIPTION
NOTES
*/


#include <audio.h>
#include <gain_utils.h>
#include <stdlib.h>
#include <panic.h>
#include <stream.h>
#include <sink.h>
#include <print.h>
#include <kalimba.h>
#include <file.h>
#include <stream.h>     /*for the ringtone_note*/
#include <connection.h> /*for the link_type */
#include <string.h>
#include <kalimba_standard_messages.h>
#include <kalimba_if.h>
#include <source.h>
#include <app/vm/vm_if.h>
#include <vmal.h>
#include <audio_plugin_if.h>       /*for the audio_mode*/
#include <audio_plugin_common.h>
#include <csr_broadcast_audio_if.h>  /*for things common to all CSR_COMMON_EXAMPLE systems*/
#include <csr_broadcast_audio_plugin.h>
#include <csr_broadcast_audio.h>
#include <csr_i2s_audio_plugin.h>
#include <audio_output.h>
#include <ttp_latency.h>

#include <broadcast_context.h>
#include <broadcast_msg_interface.h>
#include <broadcast_status_msg_structures.h>
#include <broadcast_cmd.h>

/* Limit the debug status */
#define LIMIT_STATUS_DEBUG

#define MIXED_MODE_INCREASING_DELAY 42 /* 42 ms optimum delay for increasing volume */
#define MIXED_MODE_DECREASING_DELAY 25 /* 25 ms optimum delay for decreasing volume */

#define LATENCY_USB_MS      (LATENCY_CSB_MS + 80)
#define LATENCY_ANALOGUE_MS (LATENCY_CSB_MS + 80)

/*! Identifier of a Broadcast stream using the CELT codec. */
#define CELT_STREAM_ID              0x01

/* DSP input port for USB audio */
#define DSP_INPUT_PORT_USB   4
/* DSP input port for A2DP source */
#define DSP_INPUT_PORT_A2DP 0
/* DSP input port for left ADC */
#define DSP_INPUT_PORT_ADC_LEFT  1
/* DSP input port for right ADC */
#define DSP_INPUT_PORT_ADC_RIGHT 2
/* DSP output port to left DAC */
#define DSP_OUTPUT_PORT_DAC0 0
/* DSP output port to right DAC */
#define DSP_OUTPUT_PORT_DAC1 1
/* DSP output port to CSB */
#define DSP_OUTPUT_PORT_CSB  2

#define DEFAULT_WIRED_RATE       (48000)

#define WIRED_RATE_44100        (44100)

#define WIRED_RATE_48000        (48000)

#define MUTE_NONE   ((uint16)(0))
#define MUTE_PRIMARY_LEFT   ((uint16)(1<<0))
#define MUTE_PRIMARY_RIGHT  ((uint16)(1<<1))
#define MUTE_BA_ALL_DEVICES      ((uint16)(1<<5))

/* allow 250mS for outputs to mute before disconnecting dsp to prevent thuds/clicks */
#define MUTE_DISCONNECT_DELAY_WITH_SUB 250

/*! Maximum volume step in BA mode */
#define BA_MAX_STEPS 31

/* The task instance pointer*/
static BA_DECODER_t * BA_DECODER = NULL;

/*******************************************************************************/
static uint32 calculateSampleRate (const uint32 rate)
{
    uint32 supported_rate = DEFAULT_WIRED_RATE;

    switch(BA_DECODER->sink_type)
    {
        case AUDIO_SINK_AV :
            supported_rate = rate;
            break;

        case AUDIO_SINK_ANALOG:
            if((rate == WIRED_RATE_44100) || (rate == WIRED_RATE_48000))
                supported_rate = rate;
            break;

        case AUDIO_SINK_USB :
            break;
        case AUDIO_SINK_I2S:
        case AUDIO_SINK_SPDIF:
        case AUDIO_SINK_FM:
        default :
            PRINT(("BA_DECODER: unsupported sampling rate\n"));
            break;
    }
    return supported_rate;
}

/*******************************************************************************/
static A2dpPluginConnectParams * baGetCodecData(void)
{
    A2dpPluginConnectParams *codecData = NULL;
    codecData = (A2dpPluginConnectParams *) BA_DECODER->params;

    if (!codecData)
    {
        PRINT(("BA_DECODER: baGetCodecData(), BA_DECODER-> Params NULL \n"));
        Panic();
    }
    return codecData;
}

/*******************************************************************************/
static bool baContentProtection(void)
{
    A2dpPluginConnectParams *codecData = baGetCodecData();

    PRINT(("BA_DECODER: baContentProtection, %x \n", codecData->content_protection));
    return codecData->content_protection;
}

/*******************************************************************************/
static uint16 baGetLatency(void)
{
    uint16 latency =0;
    
    switch(BA_DECODER->sink_type)
    {

        case AUDIO_SINK_ANALOG:
            latency = LATENCY_ANALOGUE_MS;
            break;

        case AUDIO_SINK_AV:
            latency = BA_A2DP_LATENCY_MS;
            break;

        case AUDIO_SINK_USB:
            latency = LATENCY_USB_MS;
            break;

        default:
            break;
    }
    return latency;
}

/****************************************************************************
DESCRIPTION
*/
static void baInitVolume(int16 volume)
{
/*  We use default values to mute volume on A2DP audio connection
    VM application is expected to send volume control right
    after attempting to establish A2DP media connection with the correct
    system and trim volume information along with master and tone volume
*/
    BA_DECODER->volume.group = audio_output_group_all; /* Always update all groups */
    BA_DECODER->volume.main.tone = volume; /* set the initial tones volume level */
    BA_DECODER->volume.main.master = DIGITAL_VOLUME_MUTE; /* -120dB , literally mute */
    BA_DECODER->volume.main.device_trim_master = 0;
    BA_DECODER->volume.main.device_trim_slave = 0;
    BA_DECODER->volume.aux.tone = volume; /* set the initial tones volume level */
    BA_DECODER->volume.aux.master = DIGITAL_VOLUME_MUTE; /* -120dB , literally mute */
    BA_DECODER->mute_state[audio_mute_group_main] = AUDIO_MUTE_DISABLE;
    BA_DECODER->mute_state[audio_mute_group_aux] = AUDIO_MUTE_DISABLE;
    BA_DECODER->mute_state[audio_mute_group_mic] = AUDIO_MUTE_DISABLE;
}

/*******************************************************************************/
static void baPopulatePluginFromAudioConnectData(A2dpPluginTaskdata * task, const AUDIO_PLUGIN_CONNECT_MSG_T * const connect_message)
{
    BA_DECODER = (BA_DECODER_t*)PanicUnlessMalloc(sizeof (BA_DECODER_t));

    BA_DECODER->task = task;
    BA_DECODER->media_sink = connect_message->audio_sink ;
    BA_DECODER->a2dp_plugin_variant = task->a2dp_plugin_variant;
    BA_DECODER->mode  = connect_message->mode;
    BA_DECODER->mode_params = 0;
    BA_DECODER->features   = connect_message->features;
    BA_DECODER->params     = connect_message->params;
    BA_DECODER->sink_type  = connect_message->sink_type;
    BA_DECODER->rate       = calculateSampleRate(connect_message->rate);
    BA_DECODER->app_task   = connect_message->app_task;
    BA_DECODER->ba_volume = (uint16)connect_message->volume;
    baInitVolume(connect_message->volume);
    PRINT(("BA_DECODER: connect [%p] \n", (void*) BA_DECODER->media_sink));
}

/*******************************************************************************/
static void baConnectAnalogSource(uint32 sample_rate)
{
    Source adc_a, adc_b;
    Sink dsp_a, dsp_b;
    A2dpPluginConnectParams* codecData = (A2dpPluginConnectParams *) BA_DECODER->params;
    PRINT(("BA_DECODER: +ADCS\n"));
    
    adc_a = AudioPluginAnalogueInputSetup(AUDIO_CHANNEL_A, *codecData->analogue_in_params, sample_rate);
    /* Configure analogue input B */
    adc_b = AudioPluginAnalogueInputSetup(AUDIO_CHANNEL_B, *codecData->analogue_in_params, sample_rate);

    /* Synchronise both sources for channels A & B */
    PanicFalse(SourceSynchronise(adc_a, adc_b));

    /* Plug Kalimba port 2 into ADC channel A */
    dsp_a = StreamKalimbaSink(DSP_INPUT_PORT_ADC_LEFT);
    PanicFalse(StreamConnect(adc_a, dsp_a));

    /* Plug Kalimba port 3 into ADC channel B*/
    dsp_b = StreamKalimbaSink(DSP_INPUT_PORT_ADC_RIGHT);
    PanicFalse(StreamConnect(adc_b, dsp_b));
}

/*******************************************************************************/
static void baConnectA2dpSource(void)
{
    PRINT(("BA_DECODER: +A2DP\n"));

    /* For sinks disconnect the source in case its currently being disposed */
    StreamDisconnect(StreamSourceFromSink(BA_DECODER->media_sink), DSP_INPUT_PORT_A2DP);

    /* Connect A2DP media channel directly to DSP */
    PanicFalse(StreamConnect(StreamSourceFromSink(BA_DECODER->media_sink), StreamKalimbaSink(DSP_INPUT_PORT_A2DP)));
}

/*******************************************************************************/
static void baConnectUsbAudioSource(void)
{
    PRINT(("BA_DECODER: +USB\n"));
    
    PanicFalse(StreamConnect(PanicNull(StreamUsbEndPointSource(end_point_iso_in)), StreamKalimbaSink(DSP_INPUT_PORT_USB)));
}

/*******************************************************************************/
static void baConnectAudioInputSource(uint32 sample_rate)
{
    switch(BA_DECODER->sink_type)
    {
        case AUDIO_SINK_ANALOG:
            baConnectAnalogSource(sample_rate);
            break;

        case AUDIO_SINK_AV:
            baConnectA2dpSource();
            break;

        case AUDIO_SINK_USB:
            baConnectUsbAudioSource();
            break;

        default:
            PRINT(("BA_DECODER: Unsupported audio input source: %x\n" , BA_DECODER->sink_type));
            break;
    }
}
/******************************************************************************
DESCRIPTION

    Sends input ('CODEC') sample rate configuration message
    to the DSP.
*/
static void baSendDspSampleRateMessage(uint16 sample_rate)
{
    /* Inform the DSP of the sample rate */
    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_AUDIO_SAMPLE_RATE, sample_rate >> 8,
                                  sample_rate & 0xFF, 0, 0);

    KALIMBA_SEND_MESSAGE(MESSAGE_SET_MUSIC_MANAGER_SAMPLE_RATE,
                                BA_DECODER->dsp_resample_rate,
                                0, 0, OUTPUT_INTERFACE_TYPE_NONE);

    /* Set input codec rate to DSP */
    KALIMBA_SEND_MESSAGE(MESSAGE_SET_CODEC_SAMPLE_RATE,
                                (uint16)(BA_DECODER->rate/DSP_RESAMPLING_RATE_COEFFICIENT),
                                0, 0, 0);
}

/******************************************************************************
DESCRIPTION

    Sends Latency based on the sink type  in use to the DSP.
*/
static void baSendDspLatencyMessage(void)
{
    /* Configure latency */
    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_SET_LATENCY, baGetLatency(), 0 ,0, 0);
}

/******************************************************************************
DESCRIPTION

    Informs the DSP about the supported CELT sample rates.
*/
static void baSendDspCeltMessages(void)
{
    /* Configure the CELT codec at the supported sample rates */
    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_SET_CELT_CONFIG,
                                  44100,
                                  CELT_CODEC_FRAME_SIZE_44100HZ,
                                  CELT_CODEC_FRAME_SAMPLES_44100HZ,
                                  2);
    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_SET_CELT_CONFIG,
                                  48000,
                                  CELT_CODEC_FRAME_SIZE_48KHZ,
                                  CELT_CODEC_FRAME_SAMPLES_48KHZ,
                                  2);
}

/******************************************************************************
DESCRIPTION

    Sends the CELT Stream ID to use for the DSP.
*/
static void baSendDspCeltStreamIdMessage(void)
{
    /* Set the stream id */
    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_SET_STREAM_ID, CELT_STREAM_ID, 0, 0 ,0);
}

/******************************************************************************
DESCRIPTION

    Sends the Content Protection Message to the DSP.
*/
static void baSendDspContentProtectionMessage(void)
{
    /* Configure content protection */
    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_SET_CONTENT_PROTECTION, (uint16)baContentProtection(), 0, 0 ,0);
}

/******************************************************************************
DESCRIPTION

    Sends the volume Message to the DSP.
*/
static void baSendDspVolumeMessage(uint16 ba_volume_step)
{

    /* TODO: set initial volume levels to mute, ensure this happens 
    DECODER->volume.main.master = DIGITAL_VOLUME_MUTE;
    DECODER->volume.aux.master  = DIGITAL_VOLUME_MUTE;
    CsrA2dpDecoderPluginSetLevels(&DECODER->volume, TRUE);*/

    /* Configure volume setting */
    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_SET_VOLUME, ba_volume_step, 0, 0, 0); 
}

/****************************************************************************
DESCRIPTION
    Connect dsp to speaker ouptuts
*/
static void baConnectDspOutputs(audio_output_params_t* params)
{
    PRINT(("BA_DECODER: baConnectDspOutputs\n"));
    /* BA only supports primary outputs, connect only those ports */
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_DAC0), audio_output_primary_left);
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_DAC1), audio_output_primary_right);
    AudioOutputConnectOrPanic(params);
}

/****************************************************************************
DESCRIPTION
    Set the output sample rate
*/
static void baSetOutputSampleRate(audio_output_params_t* params)
{
    A2dpPluginConnectParams *codecData = (A2dpPluginConnectParams *) BA_DECODER->params;

    /* Consider output sampling rate set in case of wired audio routing (analog, I2S and SPDIF) except USB */
    if((BA_DECODER->sink_type == AUDIO_SINK_ANALOG) ||(BA_DECODER->sink_type == AUDIO_SINK_I2S) ||(BA_DECODER->sink_type == AUDIO_SINK_SPDIF))
    {
        /* Set the output sampling rate to that of the configured output rate ?? need to take care of USB and SPDIF here??*/
        params->sample_rate = codecData->wired_audio_output_rate;
    }
    else
    {
        /* Set the output sampling rate to that of the codec rate, no resampling */
        params->sample_rate = BA_DECODER->rate;
    }
}

/****************************************************************************
DESCRIPTION
   Connect the local audio stream through DSP
*/
static void baConnectLocalAudioOutput(void)
{
    audio_output_params_t params;
    memset(&params, 0, sizeof(audio_output_params_t));
    /* Now set the DAC rate */
    params.sample_rate = BA_DECODER->rate;
    params.disable_resample = FALSE;

    baSetOutputSampleRate(&params);
    /* Store adjusted sample rate returned from multi-channel plugin */
    BA_DECODER->dsp_resample_rate = (uint16)(AudioOutputGetSampleRate(&params, 0)/DSP_RESAMPLING_RATE_COEFFICIENT);
    PRINT(("BA_DECODER: BA_DECODER->dsp_resample_rate = %d\n", BA_DECODER->dsp_resample_rate));
    baConnectDspOutputs(&params);
}

/****************************************************************************
DESCRIPTION
   Connect the audio stream (Speaker and Microphone)
*/
static void baConnectAudio(void)
{
    if(BA_DECODER->media_sink)
    {
        uint32 sample_rate = BA_DECODER->rate;

        /* update the current audio state */
        SetAudioInUse(TRUE);

        /* connect audio source input */
        baConnectAudioInputSource(sample_rate);

        /* Connect local output */
        baConnectLocalAudioOutput();
        baSendDspSampleRateMessage((uint16)sample_rate);
        baSendDspLatencyMessage();
        baSendDspCeltMessages();
        baSendDspCeltStreamIdMessage();
        baSendDspContentProtectionMessage();
        baSendDspVolumeMessage(BA_DECODER->ba_volume);

    }
    else
    {
        /*Disconnect plugin ?*/
    }

    SetCurrentDspStatus(DSP_RUNNING);
}

/****************************************************************************
DESCRIPTION
    Disconnect connected Analog audio source
*/
static void baDisconnectAnalogSource(void)
{
    Source adc_a = NULL;
    Source adc_b = NULL;
    
    PRINT(("BA_DECODER: -ADCS\n"));

    adc_a = StreamAudioSource(AUDIO_HARDWARE_CODEC, AUDIO_INSTANCE_0, AUDIO_CHANNEL_A);
    adc_b = StreamAudioSource(AUDIO_HARDWARE_CODEC, AUDIO_INSTANCE_0, AUDIO_CHANNEL_B);

    /* Disconnect and close mic a */
    StreamDisconnect(adc_a, 0);
    StreamConnectDispose(adc_a);
    SourceClose(adc_a);

    /* Disconnect and close mic b */
    StreamDisconnect(adc_b, 0);
    StreamConnectDispose(adc_b);
    SourceClose(adc_b);

    StreamDisconnect(0, StreamKalimbaSink(DSP_INPUT_PORT_ADC_LEFT));
    StreamDisconnect(0, StreamKalimbaSink(DSP_INPUT_PORT_ADC_RIGHT));
}

/****************************************************************************
DESCRIPTION
    Disconnect connected A2DP audio source
*/
static void baDisconnectA2dpSource(void)
{
    Source disconnectSource = StreamSourceFromSink(BA_DECODER->media_sink);
    
    PRINT(("BA_DECODER: -A2DP\n"));

    StreamDisconnect(disconnectSource, 0);

    /* flush buffer */
    StreamConnectDispose(disconnectSource);

    /* disconnect and close */
    SourceClose(disconnectSource);
}

/****************************************************************************
DESCRIPTION
    Disconnect connected USB audio source
*/
static void baDisconnectUsbAudioSource(void)
{
    PRINT(("BA_DECODER: -USB\n"));

    StreamDisconnect(PanicNull(StreamUsbEndPointSource(end_point_iso_in)), 0);
}

/****************************************************************************
DESCRIPTION
    Disconnect connected BA audio source
*/
static void baDisconnectAudioInputSource(void)
{
    switch(BA_DECODER->sink_type)
    {
        case AUDIO_SINK_ANALOG:
            /* Disconnect ADCs from DSP */
            baDisconnectAnalogSource();
            break;

        case AUDIO_SINK_AV:
            /* Disconnect A2DP media channel from DSP */
            baDisconnectA2dpSource();
            break;

        case AUDIO_SINK_USB:
            /* Disconnect USB*/
            baDisconnectUsbAudioSource();
            break;

        default:
            Panic();
    }
}

/****************************************************************************
DESCRIPTION
    Disconnected local speaker output
*/
static void baDisconnectLocalAudioOutput(void)
{
    PRINT(("BA_DECODER: baDisconnectLocalAudioOutput\n"));
    PanicFalse(AudioOutputDisconnect());
}

/****************************************************************************
DESCRIPTION
    Cancel all dsp related messages
*/
static void baCancelDspMessages(A2dpPluginTaskdata * task)
{
    MessageCancelAll( (TaskData*) task, MESSAGE_FROM_KALIMBA);
    MessageKalimbaTask( (TaskData*)task );
}

/****************************************************************************
DESCRIPTION
    This function returns the filename and path for the variant chosen
*/
static const char* baGetKapFile(A2DP_DECODER_PLUGIN_TYPE_T variant)
{
    PRINT(("BA_DECODER: baGetKapFile() Variant: %x \n",variant));
    /* determine required dsp app based on variant required */
    switch (variant)
    {
        case SBC_DECODER:
        case AAC_DECODER:
            return "csb_broadcaster_multi_decoder/csb_broadcaster_multi_decoder.kap";

        default:
            Panic();
            return NULL;
    }
}

/****************************************************************************
DESCRIPTION
    Load the requested dsp resources
*/
static void baLoadDSP(void)
{
    const char* kap_file;
    FILE_INDEX file_index;
    BA_DECODER_t* decoder = CsrBaDecoderGetDecoderData();
    /* get the filename of the kap file to load */
    kap_file = baGetKapFile(decoder->a2dp_plugin_variant);

    /* attempt to obtain file handle and load kap file, panic if not achieveable */
    file_index = FileFind(FILE_ROOT, kap_file, (uint16)strlen(kap_file));
    PanicFalse(file_index != FILE_NONE);
    PanicFalse(KalimbaLoad(file_index));
}

/****************************************************************************
DESCRIPTION
*/
static void baSetTTPExtn(void)
{
    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_SET_TTP_EXTENSION, (uint16)(BroadcastContextGetTtpExtension() + 2),
                              0, 0, 0);
}

/****************************************************************************
DESCRIPTION
    Handles the Broadcast Status message from DSP
*/
static void baHandleBroadcastStatusMessage(Message message)
{
    MessageFromKalimbaLong *kal_msg = (MessageFromKalimbaLong *)message;

    if (kal_msg->len == sizeof(broadcast_status_broadcaster_t))
    {
        broadcast_status_broadcaster_t *msg;
        msg = (broadcast_status_broadcaster_t*)kal_msg->data;
        /* remember the TTP extension */
        BroadcastContextSetTtpExtension((uint16)msg->ttp_extension);
#ifdef LIMIT_STATUS_DEBUG
        {
            static unsigned int prev_aos = 0;
            if (msg->audio_output_status != prev_aos)
            {
                PRINT(("aos=%u,ttple=%dms\n", msg->audio_output_status, msg->latency_error_ms));
                prev_aos = msg->audio_output_status;
            }
        }
#else
        PRINT(("aos=%u,ttple=%dms,ttp_ext=%x\n", msg->audio_output_status, msg->latency_error_ms, msg->ttp_extension));
#endif
    }
    else
    {
        PRINT(("KALIMBA_MSG_BROADCAST_STATUS message length mismatch\n"));
    }
}

/****************************************************************************
DESCRIPTION
    Handles the Broadcast SCM shutdown message from DSP
*/
static void baHandleBaScmShutdownCfm(A2dpPluginTaskdata * task )
{
    PRINT(("BA_DECODER:KALIMBA_MSG_SCM_SHUTDOWN_CFM\n"));

    (void)MessageCancelAll((TaskData*)task, MESSAGE_FROM_KALIMBA);
    (void)MessageCancelAll((TaskData*)task, MESSAGE_FROM_KALIMBA_LONG);

    /* Turn off DSP */
    KalimbaPowerOff();
    MessageKalimbaTask(NULL);
    
    /* update current dsp status */
    SetCurrentDspStatus( DSP_NOT_LOADED );
    /* update the current audio state */
    SetAudioInUse(FALSE);
    SetAudioBusy(NULL);
    free(BA_DECODER);
    BA_DECODER = NULL;
    
    PRINT(("BA_DECODER: BA Plugin Diconnect completed\n"));
}

/***************************************************************************
NAME
    baConnectCsbStream
 
DESCRIPTION
    Connect the CSB sink to the DSP. Also enables SCM, now that CSB is connected
 
PARAMS
    csb_sink CSB sink to connect to DSP
 
RETURNS
    void
*/
static void baConnectCsbStream(Task task, Sink csb_sink)
{
    if(csb_sink)
    {
        PRINT(("BA_DECODER: +CSB 0x%p\n", (void*)csb_sink));

        /* connect DSP to CSB sink */
        PanicFalse(StreamConnect(StreamKalimbaSource(DSP_OUTPUT_PORT_CSB), csb_sink));

        /* TODO: Enable SCM, provide plugin task as the SCM transport task */
        /*BroadcastCmdScmEnable(task);*/
        UNUSED(task);
    }
}

/***************************************************************************
NAME
    baDisconnectCsbStream
 
DESCRIPTION
    Disconnect CSB from the DSP.
    Also disables SCM, as there is no longer a CSB channel to send
    SCM messages on.
 
PARAMS
    void
 
RETURNS
    void
*/
static void baDisconnectCsbStream(void)
{
    PRINT(("BA_DECODER: -CSB\n"));

    /* TODO: disconnecting CSB, so SCM will not be available 
    ScmBroadcastDisable(sinkBroadcasterGetScmInstance());*/

    /* actually disconnect the CSB stream from the DSP */
    StreamDisconnect(StreamKalimbaSource(DSP_OUTPUT_PORT_CSB), 0);
}

/***************************************************************************
NAME
    baSetupCsbConnection
 
DESCRIPTION
    configure encryption on the csb link
 
PARAMS
    void
 
RETURNS
    void
*/
static void baSetupCsbConnection(A2dpPluginTaskdata *task)
{
    broadcast_encr_config_t* encr = BroadcastContextGetEncryptionConfig();
    
    PRINT(("BA_DECODER: Connecting CSB\n"));

    /* configure encryption on the csb link, if config provided */
    if (encr)
    {
        PRINT(("BA_DECODER: SecKey: %x-%x-%x IV:%x\n", encr->seckey[0], encr->seckey[1],
                                                 encr->seckey[2], encr->variant_iv));

        PanicFalse(KalimbaSendLongMessage(KALIMBA_MSG_SET_KEY, sizeof(encr->seckey) - 1,
                                          &encr->seckey[1]));
        PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SET_FIXED_IV,
                                      encr->fixed_iv[0], encr->fixed_iv[1], 
                                      encr->fixed_iv[2], 0));
        PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SET_IV, encr->variant_iv, 0, 0, 0));
    }

    /* Configure CSB min time, window and interval */
    PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SET_CSB_TIMING, CSB_TX_TIME_MIN_MS,
                                  CSB_TX_WINDOW_MS, CSB_INTERVAL_SLOTS, 0));

    /* Set the stream id */
    PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SET_STREAM_ID, CELT_STREAM_ID, 0, 0 ,0));

    /* connect CSB to the DSP */
    baConnectCsbStream((Task)task, BroadcastContextGetSink());
}

/****************************************************************************
DESCRIPTION
    Reconnects the audio after a tone has completed
*/
static void baPluginToneComplete ( void )
{
    PRINT(("BA_DECODER: Tone Complete\n")) ;

    /* ensure plugin hasn't unloaded before dsp message was received */
    if(BA_DECODER)
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
static void baDspStandby(A2dpPluginModeParams *mode_params)
{
    KALIMBA_SEND_MESSAGE(MUSIC_SETMODE_MSG, MUSIC_SYSMODE_STANDBY, MUSIC_DO_NOT_CHANGE_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
}

/****************************************************************************
DESCRIPTION
    utility function to set the current EQ operating mode

    @return void
*/
static void baPluginSetEqMode(uint16 operating_mode, A2DP_MUSIC_PROCESSING_T music_processing, A2dpPluginModeParams *mode_params)
{
    /* determine the music processing mode requirements, set dsp music mode appropriately */
    switch (music_processing)
    {
        case A2DP_MUSIC_PROCESSING_PASSTHROUGH:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , MUSIC_SYSMODE_PASSTHRU , MUSIC_DO_NOT_CHANGE_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)) );
                PRINT(("BA_DECODER: Set Music Mode SYSMODE_PASSTHRU\n"));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_DO_NOT_CHANGE_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode SYSMODE_FULLPROC\n"));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_NEXT_EQ_BANK:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_NEXT_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode %d and advance to next EQ bank\n", operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK0:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 0, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode %d and set EQ bank 0\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK1:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 1, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode %d and set EQ bank 1\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK2:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 2, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode %d and set EQ bank 2\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK3:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 3, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode %d and set EQ bank 3\n",operating_mode));
            }
            break;
        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK4:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 4, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode %d and set EQ bank 4\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK5:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 5, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode %d and set EQ bank 5\n",operating_mode));
            }
            break;

        case A2DP_MUSIC_PROCESSING_FULL_SET_EQ_BANK6:
            {
                KALIMBA_SEND_MESSAGE (MUSIC_SETMODE_MSG , operating_mode , MUSIC_SET_EQ_BANK, 6, (uint16)((mode_params->external_mic_settings << 1)+(mode_params->mic_mute)));
                PRINT(("BA_DECODER: Set Music Mode %d and set EQ bank 6\n",operating_mode));
            }
            break;

        default:
            {
                PRINT(("BA_DECODER: Set Music Mode Invalid [%x]\n" , music_processing ));
            }
            break;
    }
}

/*******************************************************************************/
static void baModeConnected(A2DP_MUSIC_PROCESSING_T music_processing, A2dpPluginModeParams* mode_params)
{
    PRINT(("BA_DECODER: baModeConnected()\n"));
    /* ensure mode_params has been set before use */
    if (mode_params)
    {
        /* Update DSP mode if necessary */
        baPluginSetEqMode(MUSIC_SYSMODE_FULLPROC, music_processing,
                mode_params);
    }
}

/*******************************************************************************/
static void baSetupUserEq(void)
{
    A2dpPluginModeParams *mode_params = NULL;
    A2dpPluginConnectParams* codec_data = (A2dpPluginConnectParams *) BA_DECODER->params;;

    if((codec_data != NULL) && (codec_data->mode_params != NULL))
    {
        mode_params = codec_data->mode_params;
    }
    CsrBroadcastAudioPluginSetMode(BA_DECODER->mode, mode_params);
}

/******************************************************************************
DESCRIPTION
    Send volume message to Kalimba
*/
static void baDecodeSendDspVolume(audio_output_group_t group, audio_output_gain_t* gain_info)
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
    Function to set the hardware volume (used to set hardware volume after
    a delay when using hybrid volume control).
*/
static void baSetHardwareGainDelayed(audio_output_group_t group, int16 master_gain, uint16 delay_ms)
{
    if(BA_DECODER->task)
    {
        MAKE_AUDIO_MESSAGE(AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG, message);
        message->group  = group;
        message->master = master_gain;
        MessageSendLater((Task)BA_DECODER->task, AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG, message, delay_ms);
    }
    else
    {
        AudioOutputGainSetHardware(group, master_gain, NULL);
    }
}

/****************************************************************************
DESCRIPTION
    Set the volume levels for a group (either main or aux, not all)
*/
static void baPluginSetGroupLevels(audio_output_group_t group, int16 master, int16 tone)
{
    audio_output_gain_t gain_info;

    /* Get the previous gain for this group */
    int16 prev_gain = (group == audio_output_group_main) ? BA_DECODER->volume.main.master :
                                                            BA_DECODER->volume.aux.master;

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
            baSetHardwareGainDelayed(group, master, hw_delay_ms);
        }
        break;

        case audio_output_gain_digital:
        case audio_output_gain_invalid:
        default:
            /* Set hardware gain to fixed level */
            AudioOutputGainSetHardware(group, master, NULL);
        break;
    }
    /* Set digital gain in DSP */
    baDecodeSendDspVolume(group, &gain_info);
}


/****************************************************************************
DESCRIPTION
    Update the volume info stored in DECODER->volume
*/
static void baUpdateStoredVolume(AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T* volume_msg)
{
    if(volume_msg->group == audio_output_group_main || volume_msg->group == audio_output_group_all)
        BA_DECODER->volume.main = volume_msg->main;

    if(volume_msg->group == audio_output_group_aux || volume_msg->group == audio_output_group_all)
        BA_DECODER->volume.aux = volume_msg->aux;
}

/****************************************************************************
DESCRIPTION
    Function to set the volume levels using the appropriate volume control
    mechanism
*/
static void baPluginSetLevels(AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T * volume_msg)
{
    /* Set the volume parameters for the main group and also update BA step to receivers */
    if(volume_msg->group == audio_output_group_main || volume_msg->group == audio_output_group_all)
    {
        baPluginSetGroupLevels(audio_output_group_main, volume_msg->main.master, volume_msg->main.tone);
        baSendDspVolumeMessage(ConvertdBToBroadcastVolume(volume_msg->main.master, BroadcastContextGetVolumeTable()));
    }
    /* Set the volume parameters for the aux group */
    if(volume_msg->group == audio_output_group_aux || volume_msg->group == audio_output_group_all)
    {
        baPluginSetGroupLevels(audio_output_group_aux, volume_msg->aux.master, volume_msg->aux.tone);
    }
    /* Update stored volume once level has been set to ensure correct
       detection of increase/decrease when setting hybrid volume level */
    baUpdateStoredVolume(volume_msg);
}

/****************************************************************************
DESCRIPTION

    Obtains the mute mask value for the Main output group.
    Return Mute mask value.
*/
static uint16 baGetMainMuteMask(AUDIO_MUTE_STATE_T state)
{
    uint16 mute_mask = MUTE_NONE;
    PRINT(("BA_DECODER: audioGetMainMuteMask \n"));

    if ( state == AUDIO_MUTE_ENABLE)
    {
        mute_mask |= (MUTE_PRIMARY_LEFT | MUTE_PRIMARY_RIGHT | MUTE_BA_ALL_DEVICES);
    }
    return mute_mask;
}

/****************************************************************************
DESCRIPTION
    Apply mute state to an audio group
*/
static void baMuteOutput(audio_output_group_t group, AUDIO_MUTE_STATE_T state)
{
    BA_DECODER_t* ba_decoder = CsrBaDecoderGetDecoderData();

    PRINT(("BA_DECODER: %smute ", (state == AUDIO_MUTE_DISABLE) ? "un-" : ""));

    if ((group == audio_output_group_main || group == audio_output_group_all))
    {
        PRINT(("main\n"));
        if(ba_decoder->mute_state[audio_mute_group_main] != state)
        {
            KALIMBA_SEND_MESSAGE(MESSAGE_MULTI_CHANNEL_MUTE_MAIN_S, baGetMainMuteMask(state), 0, 0, 0);
            ba_decoder->mute_state[audio_mute_group_main] = state;
        }
    }
}

/******************************************************************************
DESCRIPTION
    Get the AUDIO_MUTE_STATE_T from a mute mask for a group. NB. group must not
    be audio_mute_group_all
*/
static AUDIO_MUTE_STATE_T baGetMuteState(audio_output_group_t group, uint16 mute_mask)
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
static void baApplyMuteMask(audio_output_group_t group, uint16 mute_mask)
{
    /* Can only apply main or aux here */
    PanicFalse(group == audio_output_group_main || group == audio_output_group_aux);

    /* Convert mask to AUDIO_MUTE_STATE_T and apply */
    baMuteOutput(group, baGetMuteState(group, mute_mask));
}

/****************************************************************************
DESCRIPTION
*/
BA_DECODER_t * CsrBaDecoderGetDecoderData(void)
{
    return BA_DECODER;
}

/****************************************************************************
DESCRIPTION
*/
void CsrBroadcastAudioPluginConnect(A2dpPluginTaskdata * task, const AUDIO_PLUGIN_CONNECT_MSG_T * const connect_msg)
{
    if(BA_DECODER)
    {
        /* Disconnect plugin? */
        PRINT(("BA_DECODER: CsrBroadcastAudioPluginConnect Already connected, Disconnect?? \n"));
    }

    baPopulatePluginFromAudioConnectData(task, connect_msg);

     /* For sinks disconnect the source in case its currently being disposed. */
    StreamDisconnect(StreamSourceFromSink(connect_msg->audio_sink), 0);

    /*signal that the audio is busy until the kalimba / parameters are fully loaded so that no tone messages etc will arrive*/
    SetAudioBusy((TaskData*) task);

    /* update current dsp status */
    SetCurrentDspStatus(DSP_LOADING);

    baCancelDspMessages(task);

    baLoadDSP();

    /* set the TTP extension, needs to be as soon as we load the DSP, or it
     * will default to 0, and tell us 0 in a BROADCAST_STATUS message */
    baSetTTPExtn();

    /* update current dsp status */
    SetCurrentDspStatus( DSP_LOADED_IDLE );

    PRINT(("BA_DECODER: CsrBroadcastAudioPluginConnect completed\n"));
}

/****************************************************************************
DESCRIPTION
    Disconnect Sync audio
*/
void CsrBroadcastAudioPluginPluginStartDisconnect(TaskData * task)
{

    PRINT(("BA_DECODER: CsrBroadcastAudioPluginPluginStartDisconnect \n"));

    /* ensure nothing interrupts this sequence of events */
    SetAudioBusy((TaskData*) task);

    MessageSendLater( task, AUDIO_PLUGIN_DISCONNECT_DELAYED_MSG, 0, MUTE_DISCONNECT_DELAY_WITH_SUB);
}

/****************************************************************************
DESCRIPTION
*/
void CsrBroadcastAudioPluginDisconnect(void)
{
    if (!BA_DECODER)
    {
        PRINT(("BA_DECODER: CsrBroadcasterAudioPluginDisconnect, nothing to disconnect\n"));
        return; /* nothing to disconnect */
    }

    PRINT(("BA_DECODER: Disconnect output speakers and connected audio source\n"));

    baDisconnectLocalAudioOutput();
    baDisconnectAudioInputSource();
    baDisconnectCsbStream();
    
    PRINT(("BA_DECODER: Disconnect\n"));

    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_SCM_SHUTDOWN_REQ, 0, 0, 0, 0);
}

/*******************************************************************************/
void CsrBroadcastAudioPluginSetVolume(AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T *volumeDsp)
{
    if(BA_DECODER && volumeDsp)
    {
        /* set the volume levels according to volume control type */
        baPluginSetLevels(volumeDsp );
    }
}

/*******************************************************************************/
void CsrBroadcastAudioPluginSetSoftMute(AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T *message)
{
    if(BA_DECODER)
    {

        uint16 mute_mask = message->mute_states;
        /* Apply mute mask for main group. */
        baApplyMuteMask(audio_output_group_main, mute_mask);
    }
}

/*******************************************************************************/
void CsrBroadcastAudioPluginSetMode( AUDIO_MODE_T mode , const void * params )
{
    /* set the dsp into the correct operating mode with regards to mute and enhancements */
    A2dpPluginModeParams *mode_params = NULL;
    A2DP_MUSIC_PROCESSING_T music_processing = A2DP_MUSIC_PROCESSING_PASSTHROUGH;

    if (!BA_DECODER)
        Panic() ;

    /* mode not already set so set it */
    BA_DECODER->mode = mode;

    /* check whether any operating mode parameters were passed in via the audio connect */
    if (params)
    {
        /* if mode parameters supplied then use these */
        mode_params = (A2dpPluginModeParams *)params;
        music_processing = mode_params->music_mode_processing;
        BA_DECODER->mode_params = mode_params;
    }
    /* no operating mode params were passed in, use previous ones if available */
    else if (BA_DECODER->mode_params)
    {
        /* if previous mode params exist then revert to back to use these */
        mode_params = (A2dpPluginModeParams *)BA_DECODER->mode_params;
        music_processing = mode_params->music_mode_processing;
    }

    /* determine current operating mode */
    switch(mode)
    {
        case AUDIO_MODE_STANDBY:
        {
            baDspStandby(mode_params);
        }
        break;

        case AUDIO_MODE_CONNECTED:
        {
            baModeConnected(music_processing, mode_params);
        }
        break;
        case AUDIO_MODE_MUTE_MIC:
        case AUDIO_MODE_MUTE_SPEAKER:
        case AUDIO_MODE_MUTE_BOTH:
        case AUDIO_MODE_UNMUTE_SPEAKER:
        {
            PRINT(("BA_DECODER: *** Muting via SET_MODE_MSG is deprecated ***\n"));
            PRINT(("BA_DECODER: Use SET_SOFT_MUTE_MSG instead\n"));
            Panic();
        }
        break;

        case AUDIO_MODE_LEFT_PASSTHRU:
        case AUDIO_MODE_RIGHT_PASSTHRU:
        case AUDIO_MODE_LOW_VOLUME:
        default:
        {
            PRINT(("BA_DECODER: Set Audio Mode Invalid [%x]\n", mode));
        }
        break;
    }
}

/****************************************************************************
DESCRIPTION
   handles the internal BA plugin messages /  messages from the dsp
*/
void CsrBroadcastAudioPluginInternalMessage(A2dpPluginTaskdata * task,
                                            const uint16 id, const Message message)
{
    BA_DECODER_t* ba_decoder = CsrBaDecoderGetDecoderData();
    
    switch(id)
    {
        case MESSAGE_FROM_KALIMBA_LONG:
        {
            MessageFromKalimbaLong *kal_msg = (MessageFromKalimbaLong *)message;
            switch (kal_msg->id)
            {
                case KALIMBA_MSG_BROADCAST_STATUS:
                {
                    baHandleBroadcastStatusMessage(message);
                }
                break;
                default:
                    PRINT(("Unhandled long kalimba msg id %04x\n", kal_msg->id));
                    break;
            }
        }
        break;

        case MESSAGE_FROM_KALIMBA:
        {
            MessageFromKalimba *m = (MessageFromKalimba *)message;
            switch( m->id )
            {
                case MUSIC_READY_MSG:
                    {
                        PRINT(("BA_DECODER: MUSIC READY received\n"));
                        /* Tell the DSP what plugin type (decoder) is being used */
                        KALIMBA_SEND_MESSAGE(MUSIC_SET_PLUGIN_MSG, task->a2dp_plugin_variant, 0, 0, 0);
                        SetCurrentDspStatus(DSP_LOADED_IDLE);
                        baConnectAudio();
                        KALIMBA_SEND_MESSAGE(MUSIC_LOADPARAMS_MSG, MUSIC_PS_BASE, 0, 0 ,0);
                    }
                    break;

                case MUSIC_PARAMS_LOADED_MSG:
                    PRINT(("BA_DECODER: MUSIC_PARAMS_LOADED_MSG received\n"));
                    /* Connect BA output to CSB stream */
                    baSetupCsbConnection(task);
                    baSetupUserEq();
                    KALIMBA_SEND_MESSAGE(KALIMBA_MSG_GO, 0, 0, 0, 0);
                    SetCurrentDspStatus(DSP_RUNNING);
                    SetAudioBusy( NULL );
                    break;

                case MUSIC_CUR_EQ_BANK:
                {
                    PRINT(("BA_DECODER: MUSIC_CUR_EQ_BANK received\n"));
                    if (ba_decoder)
                    {
                        const DSP_REGISTER_T *kal_eq_msg = (const DSP_REGISTER_T *) message;
                        MAKE_AUDIO_MESSAGE_WITH_LEN(AUDIO_DSP_IND, 1, dsp_ind_message);
                        PRINT(("BA_DECODER: Current EQ setting: [%x][%x]\n", kal_eq_msg->a, kal_eq_msg->b));
                        dsp_ind_message->id = A2DP_MUSIC_MSG_CUR_EQ_BANK;
                        dsp_ind_message->size_value = 1;
                        dsp_ind_message->value[0] = kal_eq_msg->a;
                        MessageSend(ba_decoder->app_task, AUDIO_DSP_IND, dsp_ind_message);
                    }
                }
                break;

                case KALIMBA_MSG_AUDIO_STATUS:
                {
                    PRINT(("New audio status %u\n", m->data[0]));
                }
                break;

                case KALIMBA_MSG_SCM_SHUTDOWN_CFM:
                {
                    baHandleBaScmShutdownCfm(task);
                }
                break;

                case KALIMBA_MSG_SET_SCM_SEGMENT_CFM:
                {
                    PRINT(("BA_DECODER: KALIMBA_MSG_SET_SCM_SEGMENT_CFM, header %04x, tx_remaining %u\n", m->data[0], m->data[1]));
                    /* Confirm segment transmission to app/SCM library */
                    BroadcastCmdScmSeqmentSendCfm(m->data[0], m->data[1]);
                }
                break;

                /* message from DSP when tone or voice prompt has completed playing */
                case MUSIC_TONE_COMPLETE:
                {
                    /* stop tone and clear up status flags */
                    baPluginToneComplete() ;
                }
                break;

                default:
                    PRINT(("BA_DECODER: Unhandled Kalimba msg ID %04x\n", m->id));
                    break;
            }
        }
        break;

        /* Message is not from DSP.*/

        default:
            break;
    }
}
/****************************************************************************
DESCRIPTION
    function to set the volume levels of the dsp after a preset delay
*/
void CsrBroadcastAudioPluginSetHardwareLevels(AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG_T * message)
{
    PRINT(("DSP Hybrid Delayed Gains: Group = %d Master Gain = %d\n", message->group, message->master));
    AudioOutputGainSetHardware(message->group, message->master, NULL);
}

#ifdef HOSTED_TEST_ENVIRONMENT
/****************************************************************************
DESCRIPTION
    Reset any static variables
    This is only intended for unit test and will panic if called in a release build.
*/
void CsrBroadcastAudioPluginTestReset(void)
{
    if (BA_DECODER)
    {
        memset(BA_DECODER, 0, sizeof(BA_DECODER_t));
        free(BA_DECODER);
        BA_DECODER = NULL;
    }
}
#endif

/* SCM Transport related functions */
/****************************************************************************
DESCRIPTION
    Register Plugin task as the SCM transport task
*/
void CsrBroadcastAudioScmTransportRegisterReq(Task transport_task)
{
    BroadcastCmdScmTransportRegisterReq(transport_task);
}

/****************************************************************************
DESCRIPTION
    Un-Register Plugin task as the SCM transport task
*/
void CsrBroadcastAudioScmTransportUnRegisterReq(void)
{
    BroadcastCmdScmTransportUnRegisterReq();
}

/****************************************************************************
DESCRIPTION
    Send the SCM seqment request to Kalimba
*/
void CsrBroadcastAudioScmSeqmentReq(SCM_BROADCAST_SEGMENT_REQ_T* req)
{
    KalimbaSendMessage(KALIMBA_MSG_SET_SCM_SEGMENT_REQ, req->header,
                           req->data[0], (uint16)((req->data[1] << 8) | (req->data[2])),
                           req->num_transmissions);
}

