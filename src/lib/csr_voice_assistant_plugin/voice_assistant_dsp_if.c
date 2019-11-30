/***************************************************************************
Copyright (c) 2015 - 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    voice_assistant_dsp_if.c
 
DESCRIPTION
    Monolithic DSP implementation of voice assistant plug-in.
*/

#include <stdlib.h>
#include <string.h>

#include <kalimba.h>
#include <kalimba_standard_messages.h>
#include <kalimba_if.h>
#include <print.h>
#include <file.h>
#include <audio_config.h>
#include <gain_utils.h>

#include "audio.h"
#include "audio_plugin_if.h"

#include "csr_voice_assistant.h"
#include "voice_assistant_dsp_if.h"
#include "sbc_encoder_params_util.h"
#include "audio_plugin_common.h"
#include <vmal.h>

/* MIC params*/
#define VA_MIC_SAMPLE_RATE 16000 /* fixed at 16k wbs */
#define VA_MIC_PORT           1 /* ports used by the DSP for VA*/
#define VA_MIC_DSP_OUTPUT_PORT   DSP_OUTPUT_PORT_SUB_ESCO
#define VA_MANAGED_STREAM_DATA_LIMIT    3072
#define VA_MANAGED_STREAM_UNUSED_DATA_LIMIT    1
#define TONE_PLAYBACK_RATE   (8000)


/* DSP message structure */
typedef struct
{
    uint16 id;
    uint16 a;
    uint16 b;
    uint16 c;
    uint16 d;
} DSP_REGISTER_T;

/* dsp Sink type for MIC*/
typedef enum
{
    dsp_sink_none,
    dsp_sink_mic_a,
    dsp_sink_mic_b
} dsp_sink_type_t;

typedef enum
{
    dsp_source_none,
    dsp_source_va_mic_channel
} dsp_source_type_t;

/* Decoder type to send to DSP app */
typedef enum
{
    VA_NO_DECODER = 0,
    VA_SBC_DECODER = 1
} VOICE_ASSISTANT_DECODER_T;

extern const TaskData voice_assistant_plugin;


static void voiceAssistantLoadDsp(void);
static void voiceAssistantDspSetEncoderParams(void);
static void  voiceAssistantDspConnectMicPorts(void);
static void  voiceAssistantDspDisconnectMicPorts(void);
static Sink voiceAssistantGetDspSink(dsp_sink_type_t type);
static bool voiceAssistantIsOtherPluginPresent(void);
static void voiceAssistantDspConnectPorts(void);
static void voiceAssistantHandleMusicToneCompleteMessage(void);
static void voiceAssistantSetVolume(int16 prompt_volume, bool using_tone_port);
static void voiceAssistantSendDspSampleRateMessages(unsigned playback_rate, unsigned resample_rate_with_coefficient_applied);
static DAC_OUTPUT_RESAMPLING_MODE_T convertDacResamplingRateToResamplingMode(uint32 resample_rate);
static uint16 voiceAssistantDspConvertEncoderFormat(void);

/******************************************************************************
DESCRIPTION
    Get appropriate decoder kap file for given decoder name.
*/
static const char* voiceAssistantGetKapFileName(VOICE_ASSISTANT_DECODER_T decoder)
{
    const char *kap_file_name = NULL;

    switch(decoder)
    {
    case VA_SBC_DECODER:
        kap_file_name = "sbc_decoder/sbc_decoder.kap";
        break;
    case VA_NO_DECODER:
    default:
        Panic();
    }

    return kap_file_name;
}

/******************************************************************************
DESCRIPTION
    Is other plugin (like a2dp) already loaded.
*/
static bool voiceAssistantIsOtherPluginPresent(void)
{
    DSP_STATUS_INFO_T status = GetCurrentDspStatus();
    if(DSP_NOT_LOADED == status || DSP_ERROR == status)
    {
        return FALSE;
    }
    else
    {
        return TRUE;
    }
}


/****************************************************************************
DESCRIPTION
    Load DSP application for given codec type.
*/
static void voiceAssistantLoadDsp(void)
{
    const char *kap_file = voiceAssistantGetKapFileName(VA_SBC_DECODER);
    FILE_INDEX file_index = FileFind(FILE_ROOT,(const char *) kap_file ,(uint16)strlen(kap_file));

    /* Register the plugin with Kalimba*/
    MessageKalimbaTask((TaskData*)&voice_assistant_plugin);
    /* Load DSP */
    if (!KalimbaLoad(file_index))
        Panic();
}


/*******************************************************************************
DESCRIPTION
    Entry point for DSP specific Voice Assistant activity.
*/
void VoiceAssistantDspStart(void)
{
    va_context_t *context = VoiceAssistantGetContext();
    if(context)
    {
         /* Set the Audio Busy */
         SetAudioBusy((TaskData*) &(voice_assistant_plugin));

        if(voiceAssistantIsOtherPluginPresent()){
            PRINT(("VoiceAssistantDspStart:Parallel Setup\n"));
            context->is_standalone = FALSE;
            voiceAssistantDspConnectPorts();
        }
        else
        {
            PRINT(("VoiceAssistantDspStart: Stand Alone\n"));
            /* Mode of operation*/
            context->is_standalone = TRUE;
            /* Set the DSP status for audio lib*/
            SetCurrentDspStatus( DSP_LOADING );
            /* Load he kalimba with the respective Kap*/
            voiceAssistantLoadDsp();
        }
    }
    else
    {
        /* update current dsp status */
        PRINT(("VoiceAssistantDspStart:Could not find the context, setting the appropriate DSP status \n"));
        SetCurrentDspStatus( DSP_ERROR );
    }

}

/****************************************************************************
DESCRIPTION
    Common place to connect the DSP ports
*/
static void voiceAssistantDspConnectPorts(void)
{
    PRINT(("voiceAssistantDspConnectPorts\n"));
    /* Set the SBC encode params */
    voiceAssistantDspSetEncoderParams();
    /* Connect the MIC ports*/
    voiceAssistantDspConnectMicPorts();
}

/*******************************************************************************
DESCRIPTION
    Stop the DSP with respect to Voice assistant.
*/
void VoiceAssistantDspStop(void)
{
    va_context_t *context = VoiceAssistantGetContext();
    PRINT(("VoiceAssistantDspStop\n"));
    /* Disconnect the MIC Ports */
    if(context)
    {
        voiceAssistantDspDisconnectMicPorts();
        if(context->is_standalone == TRUE)
        {
            context->is_standalone = FALSE;
            /* Disconnect PCM sources/sinks */
            (void)AudioOutputDisconnect();
            /* turn off dsp and de-register the Kalimba Task */
            KalimbaPowerOff() ;
            MessageKalimbaTask(NULL);
            /* Set the DSP status for audio lib*/
            SetCurrentDspStatus( DSP_NOT_LOADED );
        }
        /* Cancel all the messages relating to VP that have been sent */
        MessageCancelAll((TaskData*) &voice_assistant_plugin, MESSAGE_FROM_KALIMBA);
    }

   /* Clean Audio Busy Flag */
    SetAudioBusy(NULL);

}

static uint16 voiceAssistantDspConvertEncoderFormat(void)
{
    sbc_encoder_params_t encoder_params;
    uint16 force_word_for_sbcformat = 0x0100;
    uint16 format;

    encoder_params = AudioConfigGetSbcEncoderParams();
    format =voiceAssistantDspConvertSbcEncParamsToFormat(&(encoder_params));
    force_word_for_sbcformat |= format;
    return force_word_for_sbcformat;
    
}
/****************************************************************************
DESCRIPTION
    Set the encoder parameters
*/
static void voiceAssistantDspSetEncoderParams(void){
    PRINT(("voiceAssistantDspSetEncoderParams\n"));
    /* Configure SBC encoding format */
    (void)PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SBCENC_SET_PARAMS, voiceAssistantDspConvertEncoderFormat(), 0, 0, 0));
    (void)PanicFalse(KalimbaSendMessage(KALIMBA_MSG_SBCENC_SET_BITPOOL, (uint16)(AudioConfigGetSbcEncoderParams().bitpool_size), 0, 0, 0));
}


/****************************************************************************
DESCRIPTION
    Disconnect Mic once the DSP is loaded
*/
static void  voiceAssistantDspDisconnectMicPorts(void){

    audio_mic_params configured_mic_params =  AudioConfigGetVaMicParams();
    va_context_t *context = VoiceAssistantGetContext();
    /* Obtain the source for MIC */
    Source mic_source_a = AudioPluginGetMicSource(configured_mic_params, AUDIO_CHANNEL_A);
    Source dsp_output_src = StreamKalimbaSource(VA_MIC_DSP_OUTPUT_PORT);
    PRINT(("VoiceAssistantDspDisconnectMicPorts\n"));
    /* if microphone is connected then disconnect it */
    if (mic_source_a)
    {
        /* disconnect and close the source */
        StreamDisconnect(mic_source_a, 0);
        SourceClose(mic_source_a);
    }

    /* Closing the managed streams*/
    if(dsp_output_src)
    {
        /* disconnect and close the source */
        StreamDisconnect(dsp_output_src, 0);
        SourceClose(dsp_output_src);
    }

    /* Closing the pipe stream */
    if((context)&&(context->va_snk_dsp != NULL)){
        PRINT(("VoiceAssistantDspDisconnectMicPorts close va_snk_dsp\n"));
        SourceDrop(StreamSourceFromSink(context->va_snk_dsp),SourceSize(StreamSourceFromSink(context->va_snk_dsp)));
        SinkClose(context->va_snk_dsp);
        }
    if((context)&&(context->va_snk_vm != NULL)){
        PRINT(("VoiceAssistantDspDisconnectMicPorts close va_snk_vm\n"));
        SourceDrop(StreamSourceFromSink(context->va_snk_vm),SourceSize(StreamSourceFromSink(context->va_snk_vm)));
        SinkClose(context->va_snk_vm);
    }

    AudioPluginSetMicBiasDrive(configured_mic_params, FALSE);

}

/****************************************************************************
DESCRIPTION
    Retrieve the respective DSP sink
*/
static Sink voiceAssistantGetDspSink(dsp_sink_type_t type)
{
    switch(type)
    {
        case dsp_sink_mic_a:
            return StreamKalimbaSink(VA_MIC_PORT);
        case dsp_sink_none:
        default:
            return (Sink)NULL;
    }
}

/****************************************************************************
DESCRIPTION
    Indicate the VA data source to the respective App task
*/
static void voiceAssistantIndicateDataSource(Task app_task,Source src)
{
     MAKE_AUDIO_MESSAGE( AUDIO_VA_INDICATE_DATA_SOURCE, message ) ;
     message->plugin = (Task)&voice_assistant_plugin ;
     message->data_src = src ;
     MessageSend(app_task, AUDIO_VA_INDICATE_DATA_SOURCE, message);
}

/****************************************************************************
DESCRIPTION
    Connect all the DSP output ports to hardware
*/
static void voiceAssistantConnectKalimbaOutputs(audio_output_params_t* mch_params)
{
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_PRI_LEFT), audio_output_primary_left);
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_PRI_RIGHT), audio_output_primary_right);
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_SEC_LEFT), audio_output_secondary_left);
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_SEC_RIGHT), audio_output_secondary_right);
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_AUX_LEFT), audio_output_aux_left);
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_AUX_RIGHT), audio_output_aux_right);
    AudioOutputAddSourceOrPanic(StreamKalimbaSource(DSP_OUTPUT_PORT_SUB_WIRED), audio_output_wired_sub);
    AudioOutputConnectOrPanic(mch_params);
}

/******************************************************************************
DESCRIPTION
    Set the digital and hardware gain as appropriate. The multi-channel library
    takes care of checking which volume control mode has been configured and
    setting either the hardware or digital gain to a fixed level if applicable.
*/
static void voiceAssistantSetVolume(int16 prompt_volume, bool using_tone_port)
{
    audio_output_gain_t main_vol_msg;
    audio_output_gain_t aux_vol_msg;

    int16 master_volume = MAXIMUM_DIGITAL_VOLUME_0DB;

    if (!using_tone_port)
    {
        /* Have to use master volume to control prompt level */
        master_volume = prompt_volume;
    }

    /* Fill in and then send DSP volume messages */
    AudioOutputGainGetDigital(audio_output_group_main, master_volume, prompt_volume, (audio_output_gain_t*)&main_vol_msg);
    AudioOutputGainGetDigital(audio_output_group_aux, master_volume, prompt_volume, (audio_output_gain_t*)&aux_vol_msg);

    KalimbaSendMessage(MUSIC_VOLUME_MSG_S, 1, (uint16)main_vol_msg.trim.main.primary_left, (uint16)main_vol_msg.trim.main.primary_right, 0);
    KalimbaSendMessage(MUSIC_VOLUME_MSG_S, 2, (uint16)main_vol_msg.trim.main.secondary_left, (uint16)main_vol_msg.trim.main.secondary_right, (uint16)main_vol_msg.trim.main.wired_sub);
    KalimbaSendMessage(MUSIC_VOLUME_MSG_S, 0, (uint16)main_vol_msg.common.system, (uint16)main_vol_msg.common.master, (uint16)main_vol_msg.common.tone);

    KalimbaSendMessage(MUSIC_VOLUME_AUX_MSG_S, 1, (uint16)aux_vol_msg.trim.aux.aux_left, (uint16)aux_vol_msg.trim.aux.aux_left, 0);
    KalimbaSendMessage(MUSIC_VOLUME_AUX_MSG_S, 0, (uint16)aux_vol_msg.common.system, (uint16)aux_vol_msg.common.master, (uint16)aux_vol_msg.common.tone);

    /* Set hardware gains */
    AudioOutputGainSetHardware(audio_output_group_main, master_volume, NULL);
    AudioOutputGainSetHardware(audio_output_group_aux, master_volume, NULL);
}

/****************************************************************************
DESCRIPTION
    Connect Mic once the DSP is loaded
*/
static void  voiceAssistantDspConnectMicPorts(void){

    va_context_t *context = VoiceAssistantGetContext();
    
    if(context)
    {
        /* Configure and connect MIC */
        PanicNull(StreamConnect(AudioPluginMicSetup(AUDIO_CHANNEL_A, AudioConfigGetVaMicParams(), VA_MIC_SAMPLE_RATE), 
                    voiceAssistantGetDspSink(dsp_sink_mic_a)));


        /* connect DSP source to managed streams */
        StreamPipePair(&(context->va_snk_dsp),&(context->va_snk_vm), VA_MANAGED_STREAM_DATA_LIMIT,VA_MANAGED_STREAM_UNUSED_DATA_LIMIT);
        PanicNull(StreamConnect(StreamKalimbaSource(VA_MIC_DSP_OUTPUT_PORT),context->va_snk_dsp));
        voiceAssistantIndicateDataSource((VoiceAssistantGetContext())->app_task,StreamSourceFromSink(context->va_snk_vm));

    }

}



static DAC_OUTPUT_RESAMPLING_MODE_T convertDacResamplingRateToResamplingMode(uint32 resample_rate)
{
    DAC_OUTPUT_RESAMPLING_MODE_T resampling_mode = DAC_OUTPUT_RESAMPLING_MODE_OFF;

    switch(resample_rate)
    {
        case DAC_OUTPUT_RESAMPLE_RATE_96K:
            resampling_mode = DAC_OUTPUT_RESAMPLING_MODE_96K;
            break;
        case DAC_OUTPUT_RESAMPLE_RATE_192K:
            resampling_mode = DAC_OUTPUT_RESAMPLING_MODE_192K;
            break;
        case DAC_OUTPUT_RESAMPLE_RATE_NONE:
        default:
            break;
    }
    return resampling_mode;
}

static DAC_OUTPUT_RESAMPLING_MODE_T getDacOutputResamplingMode(void)
{
    return convertDacResamplingRateToResamplingMode(AudioConfigGetDacOutputResamplingRate());
}



/******************************************************************************
DESCRIPTION

    Sends input ('CODEC'), required output ('DAC'), and tone sample rate
    configuration messages to the DSP, taking into account any re-sampling.
*/
static void voiceAssistantSendDspSampleRateMessages(
        unsigned playback_rate, unsigned resample_rate_with_coefficient_applied)
{
    PRINT(("voiceAssistantSendDspSampleRateMessages-->%d\n",getDacOutputResamplingMode()));
    if(!KalimbaSendMessage(MESSAGE_SET_DAC_OUTPUT_RESAMPLER_MSG, getDacOutputResamplingMode(), 0, 0, 0))
    {
        PRINT(("VP: Message MESSAGE_SET_DAC_OUTPUT_RESAMPLER_MSG failed!\n"));
        Panic();
    }

    {
        /* Set the codec sampling rate (DSP needs to know this for resampling) */
        KalimbaSendMessage(MESSAGE_SET_MUSIC_MANAGER_SAMPLE_RATE, (uint16)resample_rate_with_coefficient_applied, 0, 0, (LOCAL_FILE_PLAYBACK));
        KalimbaSendMessage(MESSAGE_SET_CODEC_SAMPLE_RATE, (uint16)(playback_rate/DSP_RESAMPLING_RATE_COEFFICIENT), 0, 0, 0);
    }
}
/****************************************************************************
DESCRIPTION
    Handler for message sent after DSP application loading process is finished.
*/
static void voiceAssistantHandleMusicReadyMessage(void)
{

    va_context_t *context = VoiceAssistantGetContext();

    /* Set up multi-channel parameters. */
    audio_output_params_t mch_params;
    memset(&mch_params, 0, sizeof(audio_output_params_t));
    PRINT(("VoiceAssistantHandleMusicReadyMessage\n"));

    if(context)
    {

        /* Set the DSP status for audio lib*/
        SetCurrentDspStatus( DSP_LOADED_IDLE );
        /* Set the codec in use */
        KalimbaSendMessage(MUSIC_SET_PLUGIN_MSG, VA_SBC_DECODER, 0, 0, 0);

        mch_params.sample_rate = TONE_PLAYBACK_RATE;
        /* Connect outputs */
        voiceAssistantConnectKalimbaOutputs(&mch_params);
        /* Set the digital volume before playing the prompt */
        voiceAssistantSetVolume(AudioConfigGetToneVolumeToUse(), FALSE);
        /* Set the playback rate */
        KalimbaSendMessage(MESSAGE_SET_SAMPLE_RATE, TONE_PLAYBACK_RATE, 0, 0, 1);

        /* If re-sampling was required, multi-channel library will have overridden supplied rate. */
        voiceAssistantSendDspSampleRateMessages(TONE_PLAYBACK_RATE, mch_params.sample_rate/DSP_RESAMPLING_RATE_COEFFICIENT);

        /* Connect DSP ports and confgure*/
        voiceAssistantDspConnectPorts();

        /* Send Go message to DSP*/
        if (!KalimbaSendMessage(KALIMBA_MSG_GO, 0, 0, 0, 0))
        {
            PRINT(("VA: DSP failed to send go to kalimba\n"));
            Panic();
        }
        SetCurrentDspStatus( DSP_RUNNING );

    }
    else
    {
        /* update current dsp status */
        PRINT(("voiceAssistantHandleMusicReadyMessage:Could not find the context, setting the appropriate DSP status \n"));
        SetCurrentDspStatus( DSP_ERROR );
    }
}

/****************************************************************************
DESCRIPTION
    Handler for message sent after Tone has been completed.
*/
static void voiceAssistantHandleMusicToneCompleteMessage(void)
{
    va_context_t *context = VoiceAssistantGetContext();
    PRINT(("voiceAssistantHandleMusicToneCompleteMessage\n")) ;

    /* ensure plugin hasn't unloaded before dsp message was received */
    if(context)
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
         PRINT(("voiceAssistantHandleMusicToneCompleteMessage--prompt cleanup \n")) ;
        AudioSetAudioPromptPlayingTask((Task)NULL);
        SetAudioBusy(NULL) ;
    }

}

/*******************************************************************************
DESCRIPTION
    Message handler for DSP messages.
*/
void AudioPluginVaDspMessageHandler(Task task, Message message)
{
    const DSP_REGISTER_T *dspMessage = (const DSP_REGISTER_T *) message;
    PRINT(("AudioPluginVaDspMessageHandler: msg id[%x] a[%x] b[%x] c[%x] d[%x]\n", dspMessage->id, dspMessage->a, dspMessage->b, dspMessage->c, dspMessage->d));

    UNUSED(task);
    switch ( dspMessage->id )
    {
        case MUSIC_READY_MSG:
        {
            PRINT(("VA: KalMsg MUSIC_READY_MSG\n"));
            voiceAssistantHandleMusicReadyMessage();
        }
        break;

        case MUSIC_TONE_COMPLETE:
        {
            PRINT(("VA: KalMsg MUSIC_TONE_COMPLETE\n"));
            if (AudioIsAudioPromptPlaying())
            {
                voiceAssistantHandleMusicToneCompleteMessage() ;
            }
        }
        break;

        default:
        {
            PRINT(("handleKalimbaMessage: unhandled %X\n", dspMessage->id));
        }
        break;
    }
}


