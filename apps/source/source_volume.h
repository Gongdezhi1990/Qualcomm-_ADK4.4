/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_volume.h

DESCRIPTION
    Volume handling.
    
*/


#ifndef _SOURCE_VOLUME_H_
#define _SOURCE_VOLUME_H_


/* profile/library headers */
#include <audio.h>
/* VM headers */
#include <message.h>


/* Volume default levels */
#define VOLUME_MIC_DEFAULT      10
#define VOLUME_SPEAKER_DEFAULT  11
#define VOLUME_SIDETONE_DEFAULT 0
#define VOLUME_EQ_DEFAULT       0
/* USB to local volume conversion */
#define VOLUME_MAX_INDEX 16
#define VOLUME_MIN_INDEX 0
#define VOLUME_MAX_SPEAKER_VALUE 0
#define VOLUME_MIN_SPEAKER_VALUE -16
#define VOLUME_MAX_MIC_VALUE 31
#define VOLUME_MIN_MIC_VALUE 0
/* Value for MUTE */
#define VOLUME_MUTE 0xff

/***************************************************************************
Function definitions
****************************************************************************
*/


/****************************************************************************
NAME    
    volume_initialise

DESCRIPTION
    Initialise the volume levels.

RETURNS
    void
*/
void volume_initialise(void);


/****************************************************************************
NAME    
    volume_set_dongle_levels

DESCRIPTION
    Updates the local volume levels.

RETURNS
    Return TRUE if one of the passed in volumes has caused a change in volume.
    Otherwise FALSE.
*/
bool volume_set_dongle_levels(uint8 mic_vol, uint8 speaker_vol, uint8 sidetone_vol, uint8 eq_index);


/****************************************************************************
NAME    
    volume_mute_mic

DESCRIPTION
    Updates the mic mute state.

RETURNS
    void
*/
void volume_mute_mic(bool mute);


/****************************************************************************
NAME    
    volume_get_mute_mode

DESCRIPTION
    Gets the audio mode state which is used with an audio plugin.
    
RETURNS
    The current audio mode that can be passed to an audio plugin.
    
*/
AUDIO_MODE_T volume_get_mute_mode(void);


/****************************************************************************
NAME    
    volume_usb_levels_changed_ind

DESCRIPTION
    Updates the volume based on USB audio changes.
    
*/
void volume_usb_levels_changed_ind(uint8 mic_vol_level, uint8 playback_vol_level, bool mic_mute, bool speaker_mute);

/****************************************************************************
NAME    
    volume_get_speaker_volume - 

DESCRIPTION
       Gets the speaker volume 

RETURNS
    The current speaker volume 
*/
uint8 volume_get_speaker_volume(void);

/****************************************************************************
NAME    
    volume_set_speaker_volume -

DESCRIPTION
       Sets the speaker volume  

RETURNS
    void
*/
void volume_set_speaker_volume(uint8 speaker_vol );

/****************************************************************************
NAME    
    volume_get_mic_volume -

DESCRIPTION
      Gets the mic volume 

RETURNS
    The current mic volume 
*/
uint8 volume_get_mic_volume(void);

/****************************************************************************
NAME    
    volume_set_mic_volume -

DESCRIPTION
     Sets the mic volume 

RETURNS
    void
*/
void volume_set_mic_volume(uint8 mic_vol );

/****************************************************************************
NAME    
    volume_get_side_tone_volume - 

DESCRIPTION
    Gets the speaker volume 

RETURNS
    The current side tone volume 
*/
uint8 volume_get_side_tone_volume(void);

/****************************************************************************
NAME    
    volume_set_side_tone_volume -

DESCRIPTION
      -  Sets the speaker volume 

RETURNS
    void

*/
void volume_set_side_tone_volume(uint8 sidetone_vol );

/****************************************************************************
NAME    
    volume_get_eq_index 

DESCRIPTION
      - Gets the eq index 

RETURNS
     The current eq index variable 
*/
uint8 volume_get_eq_index(void);

/****************************************************************************
NAME    
    volume_get_micmute -

DESCRIPTION
      Gets the Mic Mute variable.

RETURNS
    TRUE, if the mic mute is enabled.
    FALSE, if otherwise
*/
bool volume_get_micmute(void);
/****************************************************************************
NAME    
    volume_get_speaker_mute - 

DESCRIPTION
     Gets the Speaker Mute variable

RETURNS
    TRUE, if the speaker mute is enabled.
    FALSE, if otherwise
*/
bool volume_get_speaker_mute(void);
#endif /* _SOURCE_VOLUME_H_ */
