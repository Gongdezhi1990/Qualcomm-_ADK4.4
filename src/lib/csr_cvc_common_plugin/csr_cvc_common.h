/****************************************************************************
Copyright (c) 2005 - 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_cvc_common.h

DESCRIPTION


NOTES

*/

#ifndef _CSR_CVC_COMMON_H_
#define _CSR_CVC_COMMON_H_

#include "csr_cvc_common_plugin.h"
#include <audio_plugin_common.h>
#include <audio_plugin_voice_variants.h>

/*******************************************************************************
 Microphone IDs
*/
typedef enum
{
    microphone_input_id_voice_a,
    microphone_input_id_voice_b,
    microphone_input_id_max
} microphone_input_id_t;

/*******************************************************************************
 Bandwidth types supported by CVC
*/
typedef enum
{
    bandwidth_narrow,       /* Straight 8KHz */
    bandwidth_wide,         /* Straight 16KHz */
    bandwidth_expanded      /* 8KHz expanded to 16KHz */
} bandwidth_t;

/* Macros for checking the plug-in variant */
#define CVC_PLUGIN_IS_ASR(task) ((task->cvc_plugin_variant == cvc_1_mic_headset_cvsd_asr) || \
                                 (task->cvc_plugin_variant == cvc_2_mic_headset_cvsd_asr) || \
                                 (task->cvc_plugin_variant == cvc_1_mic_handsfree_cvsd_asr) || \
                                 (task->cvc_plugin_variant == cvc_2_mic_handsfree_cvsd_asr))

#define CVC_PLUGIN_IS_ASR_HEADSET(task) ((task->cvc_plugin_variant == cvc_1_mic_headset_cvsd_asr) || \
                                         (task->cvc_plugin_variant == cvc_2_mic_headset_cvsd_asr))

#define CVC_PLUGIN_IS_2MIC_BEX(task) ((task->cvc_plugin_variant == cvc_2_mic_headset_cvsd_bex) || \
                                      (task->cvc_plugin_variant == cvc_2_mic_handsfree_cvsd_bex))

#define CVC_PLUGIN_IS_CVC_DISABLED(task) (task->cvc_plugin_variant == cvc_disabled)

/*******************************************************************************
DESCRIPTION
    This function connects cvc to the stream subsystem
*/
void CsrCvcPluginConnect( CvcPluginTaskdata *task, 
                          AUDIO_PLUGIN_CONNECT_MSG_T* connect_msg);

/*******************************************************************************
DESCRIPTION
    Handle request to disconnect CVC
*/
void CsrCvcPluginHandleDisconnectEvent(Task task);

/*******************************************************************************
DESCRIPTION
    Disconnect CVC and power off the DSP core
*/
void CsrCvcPluginDisconnect(CvcPluginTaskdata *task) ;

/*******************************************************************************
DESCRIPTION
    Tell CVC to update the volume.
*/
void CsrCvcPluginSetVolume(int16 volume ) ;


/*******************************************************************************
DESCRIPTION
    Reset the volume back to stored values
*/
void CsrCvcPluginResetVolume(void);

/*******************************************************************************
DESCRIPTION
    Set the mode when the plug-in is not using the DSP (this really just 
    used to connect/disconnect mic and speakers).
*/
void CsrCvcPluginSetModeNoDsp(AUDIO_MODE_T mode);

/*******************************************************************************
DESCRIPTION
    Set the mute state when the plug-in is not using the DSP (this is done
    by connecting/disconnecting mic and speakers based on mute state)
*/
void CsrCvcPluginSetSoftMuteNoDsp(AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T* message);

/*******************************************************************************
DESCRIPTION
    Set the CVC processing mode
*/
void CsrCvcPluginSetMode(CvcPluginTaskdata *task, AUDIO_MODE_T mode , const void * params);

/*******************************************************************************
DESCRIPTION
    Set the mute states
*/
void CsrCvcPluginSetSoftMute(AUDIO_PLUGIN_SET_SOFT_MUTE_MSG_T* message);

/*******************************************************************************
DESCRIPTION
    Connect the speaker and microphone hardware to the DSP and send the initial
    hardware and transport configuration. Also sets the initial volume and mute
    states.
*/ 
void csrCvcCommonConnectAudio(CvcPluginTaskdata *task);

/*******************************************************************************
DESCRIPTION
    Handles a CVC_CODEC message received from CVC
*/
void csrCvcCodecMessage(CvcPluginTaskdata *task, T_mic_gain input_gain_l, T_mic_gain input_gain_r, int16 output_gain);

/*******************************************************************************
DESCRIPTION
    Get the bandwidth setting (narrow/wide/expanded) for a CVC plugin
*/
bandwidth_t csrCvcGetBandwidth(CvcPluginTaskdata *task);

/*******************************************************************************
DESCRIPTION
    Get the file index for any deferred MultiKap CVC application
*/
FILE_INDEX csrCvcGetAppIndex(void);

/*******************************************************************************
DESCRIPTION
    Set the file index for any deferred MultiKap CVC application
*/
void csrCvcSetAppIndex(FILE_INDEX index);

/*******************************************************************************
DESCRIPTION
    Get the microphone configuration used for a particular microphone
*/
const audio_mic_params * CsrCvcGetMicParamsFromMicId(const microphone_input_id_t mic_id);

/*******************************************************************************
DESCRIPTION
    Cycle through to the next microphone input (for testing microphone hardware)
*/
#ifdef CVC_ALL
void CsrCvcPluginMicSwitch(void);
#else
#define CsrCvcPluginMicSwitch() (NULL)
#endif

/*******************************************************************************
DESCRIPTION
    Cycle through to the next speaker output (for testing speaker hardware)
*/
#ifdef CVC_ALL
void CsrCvcPluginOutputSwitch(void);
#else
#define CsrCvcPluginOutputSwitch() (NULL)
#endif

/*******************************************************************************
DESCRIPTION
    Sets the power mode of the plugin
*/
void CsrCvcPluginSetPower( CvcPluginTaskdata *task,  AUDIO_POWER_T power );

/*******************************************************************************
DESCRIPTION
    Configures CVC for use as ASR (speech recognition)
*/
void CvcConfigureSpeechRecognitionIfSupported(CvcPluginTaskdata *task);

/*******************************************************************************
DESCRIPTION
    Start or restart the ASR engine
*/
void CsrCvcPluginStartSpeechRecognitionIfSupported(CvcPluginTaskdata *task);

#ifdef HOSTED_TEST_ENVIRONMENT
/*******************************************************************************
DESCRIPTION
    Reset the plug-in to it's default state.
*/
void CsrCvcPluginTestReset(void);
#endif

/*******************************************************************************
DESCRIPTION
    Is Hands-free-kit processing enabled for this connection (or is CVC in pass-
    through mode)?
*/
bool CsrCvcIsHandsFreeKitEnabled(void);

/*******************************************************************************
DESCRIPTION
    Get the main volume for this connection
*/
int16 CsrCvcGetVolume(void);

/*******************************************************************************
DESCRIPTION
    Get the tone volume for this connection
*/
int16 CsrCvcGetToneVolume(void);

/*******************************************************************************
DESCRIPTION
    Is the current connection a USB link?
*/
bool CsrCvcIsUsbAudio(void);

/*******************************************************************************
DESCRIPTION
    Send a message to the application task 
*/
void CsrCvcSendApplicationMessage(MessageId id, void* payload);

/*******************************************************************************
DESCRIPTION
    Play a tone, either by connecting the a tone source directly to the DAC
    if the plug-in is not using the DSP OR by connecting the tone source to the
    DSP tone mixing input
*/
void CsrCvcCommonTonePlay(CvcPluginTaskdata* task, AUDIO_PLUGIN_PLAY_TONE_MSG_T * tone_message);

/*******************************************************************************
DESCRIPTION
    Stop a tone from playing
*/
void CsrCvcCommonToneStop(CvcPluginTaskdata* task);

/*******************************************************************************
DESCRIPTION
    Handle a firmware message indicating that a tone source has been
    disconnected
*/
void CsrCvcCommonToneComplete ( CvcPluginTaskdata *task ) ;

/*******************************************************************************
DESCRIPTION
    Handle a MESSAGE_TONE_COMPLETE from the DSP
*/
void csrCvcCommonToneCompleteMessage(CvcPluginTaskdata* task);

/*******************************************************************************
DESCRIPTION
    Reconnects the audio after a tone has completed in no DSP mode
*/
void CsrCvcCommonToneForceCompleteNoDsp(void);

/*******************************************************************************
DESCRIPTION
    Check if the SCO sink is still valid
*/
bool CsrCvcCommonIsScoValid(void);


/* The power level that the plugin will switch to low power mode */
#define LPIBM_THRESHOLD     POWER_BATT_LEVEL0

/* Internal message ids */
#define MESSAGE_FORCE_TONE_COMPLETE     0x0001

#endif

