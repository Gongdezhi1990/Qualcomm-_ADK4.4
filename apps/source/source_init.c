/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_init.c

DESCRIPTION
    Initialisation of application.
    
*/


/* header for this file */
#include "source_init.h"
/* application header files */
#include "source_a2dp.h"
#include "source_app_msg_handler.h"
#include "source_avrcp.h"
#include "source_debug.h"
#include "source_inquiry.h"
#include "source_memory.h"
#include "source_private.h"
#include "source_states.h"
#include "source_sc.h"
#include "source_aghfp_data.h"
#include "source_audio.h"
#include "source_connection_mgr.h"
/* profile/library headers */
#include <a2dp.h>
#include <connection.h>
/* VM headers */
#include <panic.h>

#ifdef DEBUG_INIT
    #define INIT_DEBUG(x) DEBUG(x)
#else
    #define INIT_DEBUG(x)
#endif

/* connection library messages to receive */
const msg_filter connection_msg_filter = {msg_group_acl};


/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    init_register_profiles

DESCRIPTION
    Called when a profile has been initialised, to kick off the next initialisation step.

RETURNS:
    void
    
*/
void init_register_profiles(REGISTERED_PROFILE_T registered_profile)
{
    switch (registered_profile)
    {
        case REGISTERED_PROFILE_NONE:
        {
            /* initialise profile memory */
            init_profile_memory();

            /* store locally supported profiles */
            if (aghfp_get_profile_Value() != HFP_PROFILE_DISABLED)
            {
                connection_mgr_set_supported_profiles(PROFILE_AGHFP);
            }
            if (a2dp_get_profile_value() != A2DP_PROFILE_DISABLED)
            {
                connection_mgr_set_supported_profiles(PROFILE_A2DP);
            }
            if (avrcp_get_profile_value() != AVRCP_PROFILE_DISABLED)
            {
                connection_mgr_set_supported_profiles(PROFILE_AVRCP);
            }
            
            /* set initial audio mode based on registered Profiles */
            if (connection_mgr_is_a2dp_profile_enabled())
            {    
                audio_set_voip_music_mode(AUDIO_MUSIC_MODE);
            }
            else
            {
                audio_set_voip_music_mode(AUDIO_VOIP_MODE);
            }

            /* Read Pin code configuration*/
            connection_mgr_read_pin_code_config_values();
            /* initialise Connection library */
            INIT_DEBUG(("INIT: Initialising Connection Library...\n"));
            ConnectionInitEx3(connection_mgr_get_instance(),&connection_msg_filter,
                              connection_mgr_get_number_of_paired_devices(),
                              SC_CONNECTION_LIB_OPTIONS);
        }
        break;
              
        case REGISTERED_PROFILE_CL:
        {            
            if (connection_mgr_is_a2dp_profile_enabled())
            {
                /* initialise A2DP library */
                INIT_DEBUG(("INIT: Initialising A2DP Library...\n"));
                a2dp_init();
                break;
            }
        }
        /* fall through to REGISTERED_PROFILE_A2DP if A2DP disabled */        
        
        case REGISTERED_PROFILE_A2DP:
        {        
            if (connection_mgr_is_avrcp_profile_enabled())
            {
                /* initialise AVRCP library */
                INIT_DEBUG(("INIT: Initialising AVRCP Library...\n"));
                avrcp_init();
                break;
            }
        }
        /* fall through to REGISTERED_PROFILE_AVRCP if AVRCP disabled */ 
        
        case REGISTERED_PROFILE_AVRCP:
        {           
            if (connection_mgr_is_aghfp_profile_enabled())
            {
                /* initialise AGHFP library */
                INIT_DEBUG(("INIT: Initialising AGHFP Library...\n"));
                aghfp_init();  
                break;
            }
        }
        /* fall through to REGISTERED_PROFILE_AGHFP if AGHFP disabled */
        
        case REGISTERED_PROFILE_AGHFP:
        {
            /* libraries initialised - send message to indicate the app is initialised */            
            MessageSend(app_get_instance(), APP_INIT_CFM, 0);
        }
        break;
        
        default:
        {
            INIT_DEBUG(("INIT: Unrecognised Profile Registered\n"));
            Panic();
        }
        break;
    }
}


/****************************************************************************
NAME    
    init_profile_memory

DESCRIPTION
    Initialise memory to hold profile data.
    
RETURNS
    TRUE - memory could be initialised
    FALSE - memory could not be initialised
*/
bool init_profile_memory(void)
{
    return memory_create_block(MEMORY_CREATE_BLOCK_PROFILES);
}

