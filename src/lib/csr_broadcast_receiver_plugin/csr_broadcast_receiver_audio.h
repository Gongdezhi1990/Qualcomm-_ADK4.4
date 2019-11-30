/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_broadcast_receiver_audio.h

DESCRIPTION
    
    
NOTES
   
*/

#include <audio_plugin_if.h>

#ifndef _CSR_BROADCAST_RECEIVER_AUDIO_H_
#define _CSR_BROADCAST_RECEIVER_AUDIO_H_

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
    Task app_task;
    /* Selects the A2DP plugin variant */
    A2DP_DECODER_PLUGIN_TYPE_T  a2dp_plugin_variant;
    void * params;
    /* Additional mode parameters */
    void * mode_params;
    uint32 rate;                /* Codec sample rate (input rate to DSP) */
    uint16 dsp_resample_rate;   /* Output sample rate (required output rate from DSP, divided by DSP_RESAMPLING_RATE_COEFFICIENT ready to send in Kalimba message) */
    /*! The current volume level*/
    int16 ba_volume;
    /* digital volume structure including trim gains */
    AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T volume;
    AUDIO_MUTE_STATE_T mute_state[audio_mute_group_max];
    /*! The current mode */
    unsigned mode:8;
}CSB_DECODER_t ;

/*plugin functions*/
void CsrBaReceiverAudioPluginConnect(A2dpPluginTaskdata * task, const AUDIO_PLUGIN_CONNECT_MSG_T * const connect_msg);
void CsrBaReceiverAudioPluginDisconnect(const A2dpPluginTaskdata * const task);
void CsrBaReceiverAudioPluginSetVolume(AUDIO_PLUGIN_SET_GROUP_VOLUME_MSG_T *volumeDsp);
void CsrBaReceiverAudioPluginSetMode( AUDIO_MODE_T mode , const void * params );
void CsrBaReceiverAudioPluginSetSoftMute(AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T *message);

/*internal plugin message functions*/
void CsrBaReceiverAudioPluginInternalMessage(A2dpPluginTaskdata * task, const uint16 id, const Message message);
void CsrBaReceiverAudioPluginSetHardwareLevels(AUDIO_PLUGIN_DELAY_VOLUME_SET_MSG_T * message);

#ifdef HOSTED_TEST_ENVIRONMENT
void CsrBaReceiverAudioPluginTestReset(void);
#endif

#endif

