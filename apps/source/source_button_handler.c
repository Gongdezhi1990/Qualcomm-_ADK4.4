/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_button_handler.c

DESCRIPTION
    Handles button events.
    The functionality is only included if INCLUDE_BUTTONS is defined.
    
*/


#ifdef INCLUDE_BUTTONS

/* header for this file */
#include "source_button_handler.h"
/* application header files */
#include "source_app_msg_handler.h"
#include "source_debug.h" 
#include "source_states.h"
#include "source_connection_mgr.h"
#include "source_private.h"
/* profile/library headers */

/* VM headers */
#include <psu.h>


#ifdef DEBUG_BUTTONS
    #define BUTTONS_DEBUG(x) DEBUG(x)
#else
    #define BUTTONS_DEBUG(x)
#endif

/* structure holding the button data */
typedef struct
{
    TaskData buttonTask;
    PioState pio_state;
    unsigned power_button_released:1;
    unsigned button_long_press:1;
} BUTTON_DATA_T;

 static BUTTON_DATA_T BUTTON_RUNDATA;
/****************************************************************************
NAME    
    button_enter_inquiry - Enters Inquiry mode from button event
*/ 
static void button_enter_inquiry(void)
{
    switch (states_get_state())
    {
        case SOURCE_STATE_IDLE:      
        case SOURCE_STATE_CONNECTABLE:
        case SOURCE_STATE_DISCOVERABLE:
        case SOURCE_STATE_CONNECTING:
        case SOURCE_STATE_CONNECTED:
        {      
            /* cancel connecting timer */
            MessageCancelAll(app_get_instance(), APP_CONNECT_REQ);  
            /* move to inquiry state */    
            states_set_state(SOURCE_STATE_INQUIRING);
            /* indicate this is a forced inquiry, and must remain in this state until a successful connection */
            inquiry_set_forced_inquiry_mode(TRUE);
        }
        break;
        
        default:
        {
                    
        }
        break;
    }
}


/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    button_msg_handler - Message handler for button events
*/  
void button_msg_handler(Task task, MessageId id, Message message)
{
    switch (id)
    {
        case BUTTON_MSG_ENTER_PAIRING_MODE:
        {
            BUTTONS_DEBUG(("BUTTON_MSG_ENTER_PAIRING_MODE\n"));
                        
            /* flag to indicate long press, so short press events aren't sent */
            BUTTON_RUNDATA.button_long_press = TRUE;
            /* start inquiry */
            button_enter_inquiry();
        }
        break;
        
        case BUTTON_MSG_RESET_PAIRED_DEVICE_LIST:
        {
            BUTTONS_DEBUG(("BUTTON_MSG_RESET_PAIRED_DEVICE_LIST\n"));
            
            /* flag to indicate long press, so short press events aren't sent */
            BUTTON_RUNDATA.button_long_press = TRUE;
            /* Delete paired devices and associated attributes */
            ConnectionSmDeleteAllAuthDevices(0);
            /* start inquiry */
            button_enter_inquiry();
        }
        break;
        case BUTTON_MSG_SET_CONN_DISCOV:
        {
        	if (SOURCE_STATE_INQUIRING == states_get_state())
        	{
   			   /* free inquiry memory */
               inquiry_complete();
            }
			MessageSendLater(app_get_instance(), APP_DISCOVERY_STATE_TIMEOUT, 0, D_SEC(connection_mgr_get_discoverable_timer()));
			states_set_state(SOURCE_STATE_DISCOVERABLE);
		        
        }
        break;        
        case BUTTON_MSG_CONNECT:
        {
            if (!BUTTON_RUNDATA.button_long_press)
            {
                BUTTONS_DEBUG(("BUTTON_MSG_CONNECT\n"));
                
                /* a long press of the button hasn't been activated, okay to send short release event */
                switch (states_get_state())
                {
                    case SOURCE_STATE_IDLE:
                    case SOURCE_STATE_CONNECTABLE:
                    case SOURCE_STATE_DISCOVERABLE:
                    case SOURCE_STATE_INQUIRING:
                    {
                        /* no longer in forced inquiry mode */    
                        inquiry_set_forced_inquiry_mode(FALSE);
                        /* reset connection attempts */
                        connection_mgr_reset_connection_retries();
                        /* initialise the connection with the connection manager */
                        connection_mgr_start_connection_attempt(NULL, connection_mgr_is_aghfp_profile_enabled() ? PROFILE_AGHFP : PROFILE_A2DP, 0);
                    }
                    break;
                
                    case SOURCE_STATE_CONNECTED:
                    {
                        /* see if a further device can be connected */
                        if (connection_mgr_connect_further_device(TRUE))
                        {
                            /* connection will be attempted */
                        }
                    }
                    break;
                
                    default:
                    {
                    }
                    break;
                }
            }
            BUTTON_RUNDATA.button_long_press = FALSE;
        }
        break;
        
        case BUTTON_MSG_ON_OFF_HELD:
        {
#if defined ANALOGUE_INPUT_DEVICE || defined ENABLE_AHI_TEST_WRAPPER
            BUTTONS_DEBUG(("BUTTON_MSG_ON_OFF_HELD\n"));
            switch (states_get_state())
            {
                case SOURCE_STATE_IDLE:
                case SOURCE_STATE_CONNECTABLE:
                case SOURCE_STATE_DISCOVERABLE:
                case SOURCE_STATE_INQUIRING:
                case SOURCE_STATE_CONNECTING:
                case SOURCE_STATE_CONNECTED:
                {
                    if (BUTTON_RUNDATA.power_button_released)
                    {
                        states_set_state(SOURCE_STATE_POWERED_OFF);
                    }
                    else
                    {
                        BUTTONS_DEBUG(("  Power off ignored\n"));
                    }
                }
                break;
                
                case SOURCE_STATE_POWERED_OFF:
                {
                    if (connection_mgr_any_connected_profiles())
                    {                        
                        uint16 profile_connected = connection_mgr_get_profile_connected() ;
                        /* if still devices connected wait for them to disconnect - power on anyway after a delay incase a connection gets stuck */
                        MessageSendConditionally(app_get_instance(), APP_POWER_ON_DEVICE, 0, &profile_connected);
                        MessageSendLater(app_get_instance(), APP_POWER_ON_DEVICE, 0, 1000); 
                    }
                    else
                    {
                        /* power on immediately if no devices connected */
                        MessageSend(app_get_instance(), APP_POWER_ON_DEVICE, 0);
                    }
                }
                break;
                
                default:
                {
                }
                break;
            }
#endif /* ANALOGUE_INPUT_DEVICE */            
        }
        break;
        
        case BUTTON_MSG_ON_OFF_RELEASE:
        {
#if defined ANALOGUE_INPUT_DEVICE || defined ENABLE_AHI_TEST_WRAPPER
            BUTTONS_DEBUG(("BUTTON_MSG_ON_OFF_RELEASE\n"));
            /* stop device powering off straight after a power on */
            BUTTON_RUNDATA.power_button_released = TRUE;
#endif /* ANALOGUE_INPUT_DEVICE */            
        }
        break;
        
        case CHARGER_CONNECTED:
        {
            BUTTONS_DEBUG(("CHARGER_CONNECTED\n"));
            
#ifdef INCLUDE_POWER_READINGS            
            PowerChargerMonitor();
#endif            
        }
        break;
        
        case CHARGER_DISCONNECTED:
        {
            BUTTONS_DEBUG(("CHARGER_DISCONNECTED\n"));
            
#ifdef INCLUDE_POWER_READINGS            
            PowerChargerMonitor();
#endif
            
            switch (states_get_state())
            {
                case SOURCE_STATE_POWERED_OFF:
                {
                    MessageSend(app_get_instance(), APP_POWER_OFF_DEVICE, 0);
                }
                break;
                
                default:
                {
                }
                break;
            }
        }
        break;
        
        default:
        {
            
        }
        break;
    }
}


/****************************************************************************
NAME    
    buttons_init - Initialises the button handling
*/ 
void buttons_init(void)
{
    memset(&BUTTON_RUNDATA,0,sizeof(BUTTON_DATA_T));
    BUTTON_RUNDATA.buttonTask.handler = button_msg_handler;
    
    pioInit(&BUTTON_RUNDATA.pio_state, &BUTTON_RUNDATA.buttonTask);
    
    if (!PsuGetVregEn())
    {
        /* if VREG (used as power button) is not high initially then note that the power button is not held down */
        BUTTON_RUNDATA.power_button_released = TRUE;
    }
}


#else
    static const int buttons_disabled;
#endif /* #INCLUDE_BUTTONS */

