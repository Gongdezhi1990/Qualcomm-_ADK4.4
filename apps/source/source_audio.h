/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_audio.h

DESCRIPTION
    Handles audio routing.
    
*/


#ifndef _SOURCE_AUDIO_H_
#define _SOURCE_AUDIO_H_


/* profile/library headers */
#include <stream.h>
#include <audio_plugin_if.h>
#include <csr_a2dp_encoder_common_plugin.h>
#include <csr_ag_audio_plugin.h>
#include <pio.h>
#include <pio_common.h>


/* Indicates which audio is routed */
typedef enum
{
    AUDIO_ROUTED_NONE,
    AUDIO_ROUTED_A2DP,
    AUDIO_ROUTED_AGHFP
} AUDIO_ROUTED_T;

/* Indicates which audio mode is active (VOIP \ Music) */
typedef enum
{
    AUDIO_MUSIC_MODE,
    AUDIO_VOIP_MODE
} AUDIO_VOIP_MUSIC_MODE_T;

/***************************************************************************
Function definitions
****************************************************************************
*/


/****************************************************************************
NAME    
    audio_plugin_msg_handler

DESCRIPTION
    Handles messages received from an audio plugin library. 

RETURNS
    void
*/
void audio_plugin_msg_handler(Task task, MessageId id, Message message);


/****************************************************************************
NAME    
    audio_init

DESCRIPTION
    Initialises the audio section of code. 

RETURNS
    void
*/
void audio_init(void);


/****************************************************************************
NAME    
    audio_a2dp_connect

DESCRIPTION
    Attempt to route the A2DP audio. 

RETURNS
    void
*/
void audio_a2dp_connect(Sink sink, uint16 device_id, uint16 stream_id);


/****************************************************************************
NAME    
    audio_a2dp_disconnect

DESCRIPTION
    Attempt to disconnect the A2DP audio. 

RETURNS
    void
*/
void audio_a2dp_disconnect(uint16 device_id, Sink media_sink);


/****************************************************************************
NAME    
    audio_a2dp_disconnect_all

DESCRIPTION
    Attempt to disconnect all active A2DP audio. 

RETURNS
    void
*/
void audio_a2dp_disconnect_all(void);


/****************************************************************************
NAME    
    audio_a2dp_set_plugin

DESCRIPTION
    Set the A2DP audio plugin in use. 

RETURNS
    void
*/
void audio_a2dp_set_plugin(uint8 seid);


/****************************************************************************
NAME    
    audio_set_voip_music_mode

DESCRIPTION
    Set the audio mode in use (VOIP \ MUSIC). 

RETURNS
    void
*/
void audio_set_voip_music_mode(AUDIO_VOIP_MUSIC_MODE_T mode);


/****************************************************************************
NAME    
    audio_switch_voip_music_mode

DESCRIPTION
    Switch the audio mode in use (VOIP \ MUSIC). 

RETURNS
    void
*/
void audio_switch_voip_music_mode(AUDIO_VOIP_MUSIC_MODE_T new_mode);


/****************************************************************************
NAME    
    audio_aghfp_connect

DESCRIPTION
    Attempt to route the AGHFP audio. 

RETURNS
    void
*/
void audio_aghfp_connect(Sink sink, bool esco, bool wbs, uint16 size_warp, uint16 *warp);


/****************************************************************************
NAME    
    audio_aghfp_disconnect

DESCRIPTION
    Attempt to disconnect the AGHFP audio. 

RETURNS
    void
*/
void audio_aghfp_disconnect(void);


/****************************************************************************
NAME    
    audio_route_all

DESCRIPTION
    Route audio for all active connections. 

RETURNS
    void
*/
void audio_route_all(void);


/****************************************************************************
NAME    
    audio_suspend_all

DESCRIPTION
    Suspend audio for all active connections. 

RETURNS
    void
*/
void audio_suspend_all(void);


/****************************************************************************
NAME    
    audio_start_active_timer

DESCRIPTION
    Starts the audio active timer in USB mode if the USB audio interfaces are inactive. 
    When the timer expires the Bluetooth audio links can be suspended as no USB audio will be active.

RETURNS
    void
*/
void audio_start_active_timer(void);


/****************************************************************************
NAME    
    audio_a2dp_update_bitpool

DESCRIPTION
    Change the bitpool for the A2DP audio. 

RETURNS
    void
*/
void audio_a2dp_update_bitpool(uint8 bitpool, uint8 bad_link_bitpool);


/****************************************************************************
NAME    
    audio_update_mode_parameters

DESCRIPTION
    The audio parameters have changed so update the audio mode. 

RETURNS
    void
*/
void audio_update_mode_parameters(void);
/******************************************************************************
NAME
    audio_set_a2dp_conn_delay

DESCRIPTION
    Helper function to set the a2dp commection delay

RETURNS
    uint16
*/
void audio_set_a2dp_conn_delay(bool a2dpConnDelay);
/******************************************************************************
NAME
    audio_get_a2dp_input_device_type

DESCRIPTION
    Helper function to get the a2dp input device type.

RETURNS
        The current A2DP input device type configured which could have any of the possible values shown below: 
        0 = A2dpEncoderInputDeviceUsb,
        1 = A2dpEncoderInputDeviceAnalogue,
        2 = A2dpEncoderInputDeviceSPDIF,
        3 = A2dpEncoderInputDeviceI2S
*/
A2dpEncoderInputDeviceType audio_get_a2dp_input_device_type(void);
/******************************************************************************
NAME
    audio_get_audio_routed

DESCRIPTION
    Helper function to get the audio routed types

RETURNS
    The current audio mode which is routed.
    0 = AUDIO_ROUTED_NONE,
    1 = AUDIO_ROUTED_A2DP,
    2 = AUDIO_ROUTED_AGHFP
*/
AUDIO_ROUTED_T audio_get_audio_routed(void);
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
AUDIO_VOIP_MUSIC_MODE_T audio_get_voip_music_mode(void);
/******************************************************************************
NAME
    audio_set_aghfp_conn_delay

DESCRIPTION
    Helper function to set the a2dp commection delay

RETURNS
    void
*/
void audio_set_aghfp_conn_delay(bool aghfpConnDelay);
/******************************************************************************
NAME
    audio_get_aghfp_conn_delay

DESCRIPTION
    Helper function to get the aghfp commection delay

RETURNS
    void
*/
bool audio_get_aghfp_conn_delay(void);
/******************************************************************************
NAME
    audio_set_usb_active_flag

DESCRIPTION
    Helper function to set the Audio usb active flag

RETURNS
    void
*/
void audio_set_usb_active_flag(bool usbactive);
/******************************************************************************
NAME
    audio_get_a2dp_conn_delay

DESCRIPTION
    Helper function to get the a2dp commection delay

RETURNS
    TRUE, if the A2DP connection delay is set,
    FALSE, if otherwise.
*/
bool audio_get_a2dp_conn_delay(void);
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
A2dpEncoderEqMode audio_get_eq_mode(void);
/******************************************************************************
NAME
    audio_set_eq_mode

DESCRIPTION
    Helper function to sers the eq_mode parameter value.

RETURNS
    void
*/
void audio_set_eq_mode(uint8 eq_mode);
#endif /* _SOURCE_AUDIO_H_ */
