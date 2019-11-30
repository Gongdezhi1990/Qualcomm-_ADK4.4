/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_broadcast_audio.h

DESCRIPTION
    
    
NOTES
   
*/

#ifndef _CSR_BROADCAST_AUDIO_H_
#define _CSR_BROADCAST_AUDIO_H_

#include <audio_plugin_music_params.h>
#include <audio_plugin_music_variants.h>
#include <scm.h>

#ifdef DEBUG_PRINT_ENABLED
#define KALIMBA_SEND_MESSAGE(id, a, b, c, d) \
if(!KalimbaSendMessage(id, a, b, c, d)) \
{\
    PRINT(("KalimbaSendMessageFailed %d\n", id)); \
    Panic(); \
}
#else
#define KALIMBA_SEND_MESSAGE(id, a, b, c, d) \
PanicFalse(KalimbaSendMessage(id, a, b, c, d));
#endif

typedef struct audio_Tag
{
    A2dpPluginTaskdata *task;
    Sink media_sink ;
    AudioPluginFeatures features;
    /* Selects the A2DP plugin variant */
    A2DP_DECODER_PLUGIN_TYPE_T  a2dp_plugin_variant:8 ;
    /* type of audio source, used to determine what port to connect to dsp */
    AUDIO_SINK_T sink_type:8;
   /*! The current mode */
    unsigned mode:8 ;
    uint32 rate;                /* Codec sample rate (input rate to DSP) */
    uint16 dsp_resample_rate;   /* Output sample rate (required output rate from DSP, divided by DSP_RESAMPLING_RATE_COEFFICIENT ready to send in Kalimba message) */
    /* Additional mode parameters */
    void * mode_params;
    void * params;
    Task app_task;
   /*! The current volume level*/
   uint16 ba_volume;
    /* digital volume structure including trim gains */
    AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T volume;
    AUDIO_MUTE_STATE_T mute_state[audio_mute_group_max];
}BA_DECODER_t ;

/*plugin functions*/
void CsrBroadcastAudioPluginConnect(A2dpPluginTaskdata * task, const AUDIO_PLUGIN_CONNECT_MSG_T * const connect_msg);
void CsrBroadcastAudioPluginPluginStartDisconnect(TaskData * task);
void CsrBroadcastAudioPluginDisconnect(void);
void CsrBroadcastAudioPluginSetVolume(AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T *volumeDsp);
void CsrBroadcastAudioPluginSetSoftMute(AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T *mute);
void CsrBroadcastAudioPluginSetMode( AUDIO_MODE_T mode , const void * params );

BA_DECODER_t * CsrBaDecoderGetDecoderData(void);

/*internal plugin message functions*/
void CsrBroadcastAudioPluginInternalMessage(A2dpPluginTaskdata * task, const uint16 id, const Message message);
void CsrBroadcastAudioPluginSetHardwareLevels(AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG_T * message);

/* SCM Transport related functions */
void CsrBroadcastAudioScmTransportRegisterReq(Task transport_task);
void CsrBroadcastAudioScmTransportUnRegisterReq(void);
void CsrBroadcastAudioScmSeqmentReq(SCM_BROADCAST_SEGMENT_REQ_T* req);

#ifdef HOSTED_TEST_ENVIRONMENT
void CsrBroadcastAudioPluginTestReset(void);
#endif

#endif

