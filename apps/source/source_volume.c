/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_volume.c

DESCRIPTION
    Volume handling.
    
*/
/* VM headers */
#include <bdaddr.h>

 
/* header for this file */
#include "source_volume.h"
/* application header files */
#include "source_debug.h" 
#include "source_aghfp.h"
#include "source_audio.h"
#include "source_avrcp.h"
/* profile/library headers */

#ifdef DEBUG_VOLUME
    #define VOLUME_DEBUG(x) DEBUG(x)
#else
    #define VOLUME_DEBUG(x)
#endif

/* structure holding the volume levels */
typedef struct
{
    unsigned mic_vol:8;
    unsigned speaker_vol:8;
    unsigned sidetone_vol:8;
    unsigned eq_index:8;
    unsigned mic_mute:1;
    unsigned speaker_mute:1;
    unsigned unused:14;
} VOLUME_DATA_T;

static VOLUME_DATA_T VOLUME_RUNDATA;

typedef struct
{
    uint16 speaker_value;   /* speaker index value */
    bool speaker_mute;      /* specifies if this index should be counted as a speaker mute */
} VOLUME_SPEAKER_INDEX_T;


/* This array is used to convert a local speaker volume index in the range 0 - 16 (calculated from the volume sent by the USB host)
    to a remote speaker volume index in the range 0 - 15. 
   The volume of the USB host needs to be synced with the volume on the remote device and this array makes sure that the maximum volume seen
    on the USB Host (ie. PC Volume slider) matches with the maximum volume on the remote device. It also makes sure that the minimum 
    volume seen on the USB Host (ie. PC Volume slider) matches with the minimum volume on the remote device.
*/
static const VOLUME_SPEAKER_INDEX_T volumeSpeakerToRemoteIndexTable[VOLUME_MAX_INDEX + 1] =
{
    {0, TRUE},    /* 0 */
    {1, FALSE},    /* 1 */
    {2, FALSE},   /* 2 */
    {2, FALSE},   /* 3 */
    {3, FALSE},   /* 4 */
    {4, FALSE},   /* 5 */
    {5, FALSE},   /* 6 */
    {6, FALSE},   /* 7 */
    {7, FALSE},   /* 8 */
    {8, FALSE},   /* 9 */
    {9, FALSE},   /* 10 */
    {10, FALSE},  /* 11 */
    {11, FALSE},  /* 12 */
    {12, FALSE},  /* 13 */
    {13, FALSE},  /* 14 */
    {14, FALSE},  /* 15 */
    {15, FALSE}   /* 16 */
};

    
/***************************************************************************
Functions
****************************************************************************
*/
static void volume_set_speaker_mute(bool speaker_mute );
static void volume_set_eq_index(uint8 eq_index );
/****************************************************************************
NAME    
    volume_initialise

DESCRIPTION
    Initialise the volume levels.
*/
void volume_initialise(void)
{
    volume_set_dongle_levels(VOLUME_MIC_DEFAULT, VOLUME_SPEAKER_DEFAULT, VOLUME_SIDETONE_DEFAULT, VOLUME_EQ_DEFAULT);
}


/****************************************************************************
NAME    
    volume_set_dongle_levels

DESCRIPTION
    Updates the local volume levels.

RETURNS
    Return TRUE if one of the passed in volumes has caused a change in volume.
    Otherwise FALSE.
*/
bool volume_set_dongle_levels(uint8 mic_vol, uint8 speaker_vol, uint8 sidetone_vol, uint8 eq_index)
{
    bool value_changed = FALSE;
    
    if (volume_get_mic_volume() != mic_vol)
    {
        volume_set_mic_volume(mic_vol);
        value_changed = TRUE;
    }
    if (volume_get_speaker_volume() != speaker_vol)
    {
        volume_set_speaker_volume(speaker_vol);
        value_changed = TRUE;
    }
    if (volume_get_side_tone_volume() != sidetone_vol)
    {
        volume_set_side_tone_volume(sidetone_vol);
        value_changed = TRUE;
    }
    if (volume_get_eq_index() != eq_index)
    {
        volume_set_eq_index(eq_index);
        value_changed = TRUE;
    }
    
    VOLUME_DEBUG(("VOL: changed [%d] mic [%d] speaker [%d] sidetone[%d] eq [%d]\n", 
                  value_changed,
                  volume_get_mic_volume(),
                  volume_get_speaker_volume(),
                  volume_get_side_tone_volume(),
                  volume_get_eq_index()
                  ));
 
    return value_changed;
}


/****************************************************************************
NAME    
    volume_mute_mic

DESCRIPTION
    Updates the mic mute state.
*/
void volume_mute_mic(bool mute)
{
    VOLUME_RUNDATA.mic_mute = mute;
    VOLUME_DEBUG(("VOL: MIC Mute status[%d]\n", mute)); 
}
       

/****************************************************************************
NAME    
    volume_get_mute_mode

DESCRIPTION
    Gets the audio mode state which is used with an audio plugin.
    
RETURNS
    The current audio mode that can be passed to an audio plugin.
    
*/
AUDIO_MODE_T volume_get_mute_mode(void)
{
    AUDIO_MODE_T mode = AUDIO_MODE_CONNECTED;
    
    if (volume_get_micmute())
    {
        mode = AUDIO_MODE_MUTE_MIC;
    }
    if (volume_get_speaker_mute())
    {
        if (mode == AUDIO_MODE_MUTE_MIC)
        {
            mode = AUDIO_MODE_MUTE_BOTH;
        }
        else
        {
            mode = AUDIO_MODE_MUTE_SPEAKER;
        }
    }    
    
    VOLUME_DEBUG(("VOL: Mute mode[%d]\n", mode)); 
    
    return mode;
}

        
/****************************************************************************
NAME    
    volume_usb_levels_changed_ind

DESCRIPTION
    Updates the volume based on USB audio changes.

RETURNS
    void
*/
void volume_usb_levels_changed_ind(uint8 mic_vol_level, uint8 playback_vol_level, bool mic_mute, bool speaker_mute)
{
    bool volumes_changed = FALSE;
    bool old_speaker_mute_mode = volume_get_speaker_mute();
    
    if (speaker_mute)
    {
        /* store the speaker volume as as the Mute value */
        playback_vol_level = VOLUME_MUTE;
    }
    else
    {
        /* Convert the playback level to a value that can be sent to the remote device in the range 0 - 15.
            The value sent needs to sync the volume bar on the PC with the maximum and minimum levels on the remote device. */
        VOLUME_SPEAKER_INDEX_T index = volumeSpeakerToRemoteIndexTable[playback_vol_level];
        playback_vol_level = index.speaker_value;
        speaker_mute = index.speaker_mute;
    }
        
    if (mic_mute)
    {
        mic_vol_level = VOLUME_MUTE;
    }

    /* update speaker mute */
    volume_set_speaker_mute(speaker_mute);
    
    /* update dongle local volumes */
    volumes_changed = volume_set_dongle_levels(mic_vol_level, playback_vol_level, VOLUME_SIDETONE_DEFAULT, volume_get_eq_index());
  
    /* now always send new volume to headset, even if it is not changed in order to keep volume in sync */
    
    /* send volumes over AVRCP */
    avrcp_send_source_volume(NULL);
    /* send volumes over HFP */
    aghfp_send_source_volume(NULL);
    
    /* Update Audio mode */
    if (audio_get_audio_routed() != AUDIO_ROUTED_NONE)
    {
        if (old_speaker_mute_mode != volume_get_speaker_mute())
        {
            VOLUME_DEBUG(("VOL: Speaker Mute [%d]\n", volume_get_speaker_mute()));
            audio_update_mode_parameters();   
        }
    }       
}
/****************************************************************************
NAME    
    volume_get_speaker_volume - 

DESCRIPTION
       Gets the speaker volume 

RETURNS
    The current speaker volume 
*/
uint8 volume_get_speaker_volume(void)
{
    return VOLUME_RUNDATA.speaker_vol;
}
/****************************************************************************
NAME    
    volume_set_speaker_volume -

DESCRIPTION
       Sets the speaker volume  

RETURNS
    void
*/
void volume_set_speaker_volume(uint8 speaker_vol )
{
    VOLUME_RUNDATA.speaker_vol = speaker_vol;
}
/****************************************************************************
NAME    
    volume_get_mic_volume -

DESCRIPTION
      Gets the mic volume 

RETURNS
    The current mic volume 
*/
uint8 volume_get_mic_volume(void)
{
    return VOLUME_RUNDATA.mic_vol;
}
/****************************************************************************
NAME    
    volume_set_mic_volume -

DESCRIPTION
     Sets the mic volume 

RETURNS
    void
*/
void volume_set_mic_volume(uint8 mic_vol )
{
    VOLUME_RUNDATA.mic_vol = mic_vol;
}
/****************************************************************************
NAME    
    volume_get_side_tone_volume - 

DESCRIPTION
    Gets the sidetone volume 

RETURNS
    The current side tone volume 
*/
uint8 volume_get_side_tone_volume(void)
{
    return VOLUME_RUNDATA.sidetone_vol;
}
/****************************************************************************
NAME    
    volume_set_side_tone_volume -

DESCRIPTION
      -  Sets the speaker volume 

RETURNS
    void

*/
void volume_set_side_tone_volume(uint8 sidetone_vol )
{
    VOLUME_RUNDATA.sidetone_vol = sidetone_vol;
}
/****************************************************************************
NAME    
    volume_get_eq_index 

DESCRIPTION
      - Gets the eq index 

RETURNS
     The current eq index variable 
*/
uint8 volume_get_eq_index(void)
{
    return VOLUME_RUNDATA.eq_index;
}
/****************************************************************************
NAME    
    volume_set_eq_index - 

DESCRIPTION
      Sets the eq index variable.

RETURNS
    void
*/
static void volume_set_eq_index(uint8 eq_index )
{
    VOLUME_RUNDATA.eq_index = eq_index;
}
/****************************************************************************
NAME    
    volume_get_micmute -

DESCRIPTION
      Gets the Mic Mute variable.

RETURNS
    TRUE, if the mic mute is enabled.
    FALSE, if otherwise
*/
bool volume_get_micmute(void)
{
    return VOLUME_RUNDATA.mic_mute;
}
/****************************************************************************
NAME    
    volume_get_speaker_mute - 

DESCRIPTION
     Gets the Speaker Mute variable

RETURNS
    TRUE, if the speaker mute is enabled.
    FALSE, if otherwise
*/
bool volume_get_speaker_mute(void)
{
    return VOLUME_RUNDATA.speaker_mute;
}
/****************************************************************************
NAME    
    volume_set_speaker_mute -

DESCRIPTION
     Sets the Mic Mute variable

RETURNS
    void
*/
static void volume_set_speaker_mute(bool speaker_mute )
{
    VOLUME_RUNDATA.speaker_mute = speaker_mute;
}
