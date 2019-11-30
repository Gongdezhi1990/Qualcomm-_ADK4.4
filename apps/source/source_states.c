/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_states.c

DESCRIPTION
    Main application state machine.
    
*/


/* application header files */
#include "source_app_msg_handler.h"
#include "source_audio.h"
#include "source_connection_mgr.h"
#include "source_debug.h"
#include "source_init.h"
#include "source_inquiry.h"
#include "source_led_handler.h"
#include "source_memory.h"
#include "source_power.h" 
#include "source_scan.h"
#include "source_states.h"
#include "source_usb.h"
#include "source_avrcp.h"
#include "source_button_handler.h"
#include <source_aghfp_data.h>

/* VM headers */
#include <charger.h>
#include <pio.h>
#include <ahi.h>


#ifdef DEBUG_STATES
    #define STATES_DEBUG(x) DEBUG(x)

    const char *const state_strings[SOURCE_STATES_MAX] = {  "Initialising",
                                                            "Powered Off",
                                                            "Test Mode",
                                                            "Idle",
                                                            "Connectable",
                                                            "Discoverable",
                                                            "Connecting",
                                                            "Inquiring",
                                                            "Connected"};
#else
    #define STATES_DEBUG(x)
#endif

/* structure holding the timer data */
typedef struct
{
    unsigned timers_stopped:1;
} TIMER_DATA_T;

static TIMER_DATA_T TIMER_RUNDATA;

/* check the device is powered on */    
#define states_is_powered_on(state) (state > SOURCE_STATE_TEST_MODE);
    
/* Debug output for unhandled state */
#define states_unhandled_state(inst) STATES_DEBUG(("STATES unhandled state[%d]", states_get_state()));
    
    
/* exit state functions */    
static void states_exit_state(SOURCE_STATE_T new_state);
static void states_exit_state_initialising(void);
static void states_exit_state_powered_off(void);
static void states_exit_state_test_mode(void);
static void states_exit_state_idle(void);
static void states_exit_state_connectable(void);
static void states_exit_state_discoverable(void);
static void states_exit_state_connecting(void);
static void states_exit_state_inquiring(void);
static void states_exit_state_connected(SOURCE_STATE_T new_state);
static void states_exit_state_configure_mode(void);

/* enter state functions */    
static void states_enter_state(SOURCE_STATE_T old_state);
static void states_enter_state_initialising(void);
static void states_enter_state_powered_off(void);
static void states_enter_state_test_mode(void);
static void states_enter_state_idle(SOURCE_STATE_T old_state);
static void states_enter_state_connectable(void);
static void states_enter_state_discoverable(void);
static void states_enter_state_connecting(void);
static void states_enter_state_inquiring(void);
static void states_enter_state_connected(SOURCE_STATE_T old_state);
static void states_enter_state_configure_mode(void);

/*Other Local functions */    
static void states_set_timer_stopped_value(bool timers_stopped);
static bool states_get_timer_stopped_value(void);
/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    states_set_state - Sets the new application state
*/
void states_set_state(SOURCE_STATE_T new_state)
{
    if (new_state < SOURCE_STATES_MAX)
    {
        SOURCE_STATE_T old_state = theSource->app_data.app_state;
        
        /* leaving current state */
        states_exit_state(new_state);
        
        /* store new state */
        theSource->app_data.app_state = new_state;
        STATES_DEBUG(("STATE: new state [%s]\n", state_strings[new_state]));

        AhiTestReportStateMachineState(1, new_state);

        /* entered new state */
        states_enter_state(old_state);

        /* fudge states reported to Host, so that IDLE state is converted to a known state */
        if (new_state == SOURCE_STATE_IDLE)
        {
            theSource->app_data.pre_idle_state = old_state;
            new_state = theSource->app_data.pre_idle_state;
        }
        if (old_state == SOURCE_STATE_IDLE)
        {
            old_state = theSource->app_data.pre_idle_state;
        }
        if (old_state != new_state)
        {
            /* send new state via Vendor USB command */
            usb_send_vendor_state();

#ifdef INCLUDE_LEDS            
            /* update LED state indication */
            leds_show_state(new_state);
#endif /* INCLUDE_LEDS */              
        }
    }
}


/****************************************************************************
NAME    
    states_get_state

DESCRIPTION
    Gets the application state.
    
RETURNS
    The application state.
*/
SOURCE_STATE_T states_get_state(void)
{
    return theSource->app_data.app_state;
}


/****************************************************************************
NAME    
    states_force_inquiry

DESCRIPTION
    Move to Inquiry state regardless of current activity.

RETURNS
    void
*/
void states_force_inquiry(void)
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
            /* set appropriate timers as it is being forced to stay in inquiry state */
            states_no_timers();
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


/****************************************************************************
NAME    
    states_no_timers

DESCRIPTION
    Turns off timers that were set by the PS configuration.

RETURNS
    void
*/
void states_no_timers(void)
{
    /* stop timers */
    connection_mgr_set_inquiry_state_timer(TIMER_NO_TIMEOUT);
    connection_mgr_set_inquiry_idle_timer(0);
    connection_mgr_set_connection_idle_timer(0);
    connection_mgr_set_disconnection_Idle_timer(0);
    /* note that timers have been stopped */
    states_set_timer_stopped_value(TRUE);;
}


/****************************************************************************
NAME    
    states_exit_state - 

DESCRIPTION
    Called when exiting an application state.

RETURNS
    void
*/
static void states_exit_state(SOURCE_STATE_T new_state)
{
    switch (states_get_state())
    {
        case SOURCE_STATE_INITIALISING:
        {
            states_exit_state_initialising();
        }
        break;
        
        case SOURCE_STATE_POWERED_OFF:
        {
            states_exit_state_powered_off();
        }
        break;
        
        case SOURCE_STATE_TEST_MODE:
        {
            states_exit_state_test_mode();
        }
        break;
        
        case SOURCE_STATE_IDLE:
        {
            states_exit_state_idle();
        }
        break;
        
        case SOURCE_STATE_CONNECTABLE:
        {
            states_exit_state_connectable();
        }
        break;
        
        case SOURCE_STATE_DISCOVERABLE:
        {
            states_exit_state_discoverable();
        }
        break;
        
        case SOURCE_STATE_CONNECTING:
        {
            states_exit_state_connecting();
        }
        break;
        
        case SOURCE_STATE_INQUIRING:
        {
            states_exit_state_inquiring();
        }
        break;
        
        case SOURCE_STATE_CONNECTED:
        {
            states_exit_state_connected(new_state);
        }
        break;

        case SOURCE_STATE_CONFIGURE_MODE:
        {
            states_exit_state_configure_mode();
        }
        break;

        default:
        {
            states_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    states_exit_state_initialising - 

DESCRIPTION
    Called when exiting the SOURCE_STATE_INITIALISING state.

RETURNS
    void
*/
static void states_exit_state_initialising(void)
{
    
}


/****************************************************************************
NAME    
    states_exit_state_powered_off - 

DESCRIPTION
    Called when exiting the SOURCE_STATE_POWERED_OFF state.

RETURNS
    void
*/
static void states_exit_state_powered_off(void)
{
    
}


/****************************************************************************
NAME    
    states_exit_state_test_mode - 

DESCRIPTION
    Called when exiting the SOURCE_STATE_TEST_MODE state.

RETURNS
    void
*/
static void states_exit_state_test_mode(void)
{
    
}


/****************************************************************************
NAME    
    states_exit_state_idle -

DESCRIPTION
    Called when exiting the SOURCE_STATE_IDLE state

RETURNS
    void
*/
static void states_exit_state_idle(void)
{
    
}


/****************************************************************************
NAME    
    states_exit_state_connectable - 

DESCRIPTION
    Called when exiting the SOURCE_STATE_CONNECTABLE state

RETURNS
    void
*/
static void states_exit_state_connectable(void)
{
    scan_set_unconnectable();
}


/****************************************************************************
NAME    
    states_exit_state_discoverable - 

DESCRIPTION
    Called when exiting the SOURCE_STATE_DISCOVERABLE state.

RETURNS
    void
*/
static void states_exit_state_discoverable(void)
{
    scan_set_unconnectable();
    MessageCancelAll(app_get_instance(), APP_INQUIRY_IDLE_TIMEOUT);
}


/****************************************************************************
NAME    
    states_exit_state_connecting - 

DESCRIPTION
    Called when exiting the SOURCE_STATE_CONNECTING state.

RETURNS
    void
*/
static void states_exit_state_connecting(void)
{
}


/****************************************************************************
NAME    
    states_exit_state_inquiring - 

DESCRIPTION
    Called when exiting the SOURCE_STATE_INQUIRING state

RETURNS
    void
*/
static void states_exit_state_inquiring(void)
{
    /* cancel any active inquries */
    ConnectionInquireCancel(connection_mgr_get_instance());
}

/****************************************************************************
NAME    
    states_exit_state_configure_mode - Called when exiting the SOURCE_STATE_CONFIGURE_MODE state
*/
static void states_exit_state_configure_mode(void)
{
}


/****************************************************************************
NAME    
    states_exit_state_connected - 

DESCRIPTION
    Called when exiting the SOURCE_STATE_CONNECTED state.

RETURNS
    void

*/
static void states_exit_state_connected(SOURCE_STATE_T new_state)
{
    if (new_state != SOURCE_STATE_CONNECTING) /* if going from connected to connecting, might be connecting further devices so don't disconnect */
    {
        /* Remove all connections as it has left the connected state */
        MessageSend(app_get_instance(), APP_DISCONNECT_REQ, 0);
    }
    /* Clear the manufacturer ID */
    connection_mgr_reset_remote_manufacturer();
}


/****************************************************************************
NAME    
    states_enter_state -

DESCRIPTION
     Called when entering an application state.

RETURNS
    void
*/
static void states_enter_state(SOURCE_STATE_T old_state)
{
    switch (states_get_state())
    {
        case SOURCE_STATE_INITIALISING:
        {
            states_enter_state_initialising();
        }
        break;
        
        case SOURCE_STATE_POWERED_OFF:
        {
            states_enter_state_powered_off();
        }
        break;
        
        case SOURCE_STATE_TEST_MODE:
        {
            states_enter_state_test_mode();
        }
        break;
        
        case SOURCE_STATE_IDLE:
        {
            states_enter_state_idle(old_state);
        }
        break;
        
        case SOURCE_STATE_CONNECTABLE:
        {
            states_enter_state_connectable();
        }
        break;
        
        case SOURCE_STATE_DISCOVERABLE:
        {
            states_enter_state_discoverable();
        }
        break;
        
        case SOURCE_STATE_CONNECTING:
        {
            states_enter_state_connecting();
        }
        break;
        
        case SOURCE_STATE_INQUIRING:
        {
            states_enter_state_inquiring();
        }
        break;
        
        case SOURCE_STATE_CONNECTED:
        {
            states_enter_state_connected(old_state);
        }
        break;

        case SOURCE_STATE_CONFIGURE_MODE:
        {
            states_enter_state_configure_mode();
        }
        break;

        default:
        {
            states_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    states_enter_state_initialising -

DESCRIPTION
      Called when entering the SOURCE_STATE_INITIALISING application state

RETURNS
    void
*/
static void states_enter_state_initialising(void)
{
    /* apply power to device */
    app_power_device(TRUE);
    /* initialise audio block */
    audio_init();
    /* initialise inquiry */
    inquiry_init();

#ifdef INCLUDE_BUTTONS    
    /* initialise buttons */
    buttons_init();
#endif /* INCLUDE_BUTTONS */
    
#ifdef INCLUDE_POWER_READINGS
    /* initialise power readings */
    power_init();
#endif /* INCLUDE_POWER_READINGS */
    
    /* start registration of libraries */
    init_register_profiles(REGISTERED_PROFILE_NONE);  
}


/****************************************************************************
NAME    
    states_enter_state_powered_off - 

DESCRIPTION
      Called when entering the SOURCE_STATE_POWERED_OFF application state.

RETURNS
    void
*/
static void states_enter_state_powered_off(void)
{    
    /* restore any stopped timers on power off */
    states_restore_timers();
    
    /* cancel any queued messages */
    MessageCancelAll(app_get_instance(), APP_CONNECT_REQ);
    MessageCancelAll(app_get_instance(), APP_LINKLOSS_IND);
    MessageCancelAll(app_get_instance(), APP_AUDIO_START);
    MessageCancelAll(app_get_instance(), APP_USB_AUDIO_ACTIVE);
    
    /* Physically power off the device after a delay */
    MessageSendLater(app_get_instance(), APP_POWER_OFF_DEVICE, 0, POWER_OFF_DELAY);
}


/****************************************************************************
NAME    
    states_enter_state_test_mode - 

DESCRIPTION
      Called when entering the SOURCE_STATE_TEST_MODE application state

RETURNS
    void
*/
static void states_enter_state_test_mode(void)
{
    /* enter DUT mode */
    ConnectionEnterDutMode();
}


/****************************************************************************
NAME    
    states_enter_state_idle - 

DESCRIPTION
     Called when entering the SOURCE_STATE_IDLE application state

RETURNS
    void
*/
static void states_enter_state_idle(SOURCE_STATE_T old_state)
{
    uint16 delay = 0; /* default is to have no delay before next connection attempt */
    bdaddr  bt_addr = {0,0,0};

    switch (old_state)
    {
        case SOURCE_STATE_CONNECTING:
        {
            if (connection_mgr_get_combined_max_connection_retries() != INVALID_VALUE)
            {
                /* feature enabled to only try to a remote device a set number of times before giving up */
                if ((connection_mgr_get_connection_retries() < connection_mgr_get_combined_max_connection_retries()) ||
                   states_get_timer_stopped_value())
                {
                    /* if it was connnecting use the connection_idle_timer delay before next connection attempt */
                    delay = connection_mgr_get_idle_timer();
                    STATES_DEBUG(("STATE: was connecting, connection attempts:[%d], can continue after delay:[%d secs]\n", connection_mgr_get_connection_retries(), delay));
                    
                    if (!states_get_timer_stopped_value())
                    {
                        /* increase number of connections attempted if timers haven't been bypassed */
                        connection_mgr_increment_connection_retries();
                    }
                }
                else
                {
                    /* configured number of connection attempts have been tried - give up connecting! */
                    delay = TIMER_NO_TIMEOUT;
                    connection_mgr_reset_connection_retries();
                    STATES_DEBUG(("STATE: was connecting, given up trying to connect\n"));
                }
            }
            else
            {
                /* if it was connnecting use the connection_idle_timer delay before next connection attempt */
                delay = connection_mgr_get_idle_timer();
                STATES_DEBUG(("STATE: was connecting, next connect delay:[%d secs]\n", delay));
            }
        }
        break;
        
        case SOURCE_STATE_CONNECTED:
        {
            /* if it was connnected use the disconnect_idle_timer delay before next connection attempt */
            delay = connection_mgr_get_disconnect_idle_timer();
            STATES_DEBUG(("STATE: was connected, delay:[%d secs]\n", delay));
        }
        break;
        
        case SOURCE_STATE_INITIALISING:
        case SOURCE_STATE_POWERED_OFF:
        {
            connection_mgr_get_remote_device_address(&bt_addr);
            if (BdaddrIsZero(&bt_addr))
            {
                /* if the device was powered off and no previous connection exists:
                    use the power_on_discover_idle_timer before first discovery attempt */
                delay = connection_mgr_get_power_on_discover_idle_timer();
            }
            else
            {
                /* if the device was powered off and a previous connection exists:
                    use the power_on_connect_idle_timer before first connection attempt */
                delay = connection_mgr_get_power_on_connect_idle_timer();
            }
        }
        break;
        
        default:
        {
            
        }
        break;            
    }
    
    if (old_state != SOURCE_STATE_CONNECTING)
    {
        /* reset connection attempts if not currently connecting */
        connection_mgr_reset_connection_retries();;
    }
    
    if (delay != 0)
    {
        memset(&bt_addr,0,sizeof(bdaddr));
        connection_mgr_get_remote_device_address(&bt_addr);
        /* enter connectable or discoverable state if a delay has been configured */
        if (BdaddrIsZero(&bt_addr) || inquiry_get_forced_inquiry_mode())
        {
            /* no device to connect to, go discoverable */
            MessageSend(app_get_instance(),APP_ENTER_PAIRING_STATE_FROM_IDLE, 0);
        }
        else
        {
            /* there is a device to connect to, go connectable */
            MessageSend(app_get_instance(), APP_ENTER_CONNECTABLE_STATE_FROM_IDLE, 0);
        }
    }

    if (delay != TIMER_NO_TIMEOUT)
    {
        STATES_DEBUG(("STATE: IDLE delay before next connection:[%d secs]\n", delay));      
        /* initialise the connection with the connection manager */
        connection_mgr_start_connection_attempt(NULL, connection_mgr_is_aghfp_profile_enabled() ? PROFILE_AGHFP : PROFILE_A2DP, delay);        
    }
    else
    {
        STATES_DEBUG(("STATE: No auto reconnection\n"));
    }
}


/****************************************************************************
NAME    
    states_enter_state_connectable - 

DESCRIPTION
     Called when entering the SOURCE_STATE_CONNECTABLE application state

RETURNS
    void
*/
static void states_enter_state_connectable(void)
{
    scan_set_connectable_only();
}


/****************************************************************************
NAME    
    states_enter_state_discoverable - 

DESCRIPTION
     Called when entering the SOURCE_STATE_DISCOVERABLE application state

RETURNS
    void
*/
static void states_enter_state_discoverable(void)
{
    scan_set_connectable_discoverable();
}


/****************************************************************************
NAME    
    states_enter_state_connecting - 

DESCRIPTION
     Called when entering the SOURCE_STATE_CONNECTING application state

RETURNS
    void
*/
static void states_enter_state_connecting(void)
{
    if (connection_mgr_get_current_profile() == PROFILE_AGHFP)
    {
        aghfp_start_connection();
    }
    else if (connection_mgr_get_current_profile() == PROFILE_A2DP)
    {
        a2dp_start_connection();
    }
    else
    {
        Panic(); /* Panic if A2DP and HFP profiles disabled */
    }
}


/****************************************************************************
NAME    
    states_enter_state_inquiring - 

DESCRIPTION
     Called when entering the SOURCE_STATE_INQUIRING application state

RETURNS
    void
*/
static void states_enter_state_inquiring(void)
{
    if (inquiry_has_results())
    {
        /* continue inquiry from previously found results */
        MessageSend(app_get_instance(), APP_INQUIRY_CONTINUE, 0);
    }
    else
    {
        /* restart inquiry process */
        inquiry_start_discovery();
    }
}


/****************************************************************************
NAME    
    states_enter_state_connected -

DESCRIPTION
      Called when entering the SOURCE_STATE_CONNECTED application state

RETURNS
    void
*/
static void states_enter_state_connected(SOURCE_STATE_T old_state)
{
    /* finish any ongoing inquiry */
    inquiry_complete();
    
    /* restore timers if they have been altered */
    if (usb_get_hid_mode() == USB_HID_MODE_HOST)
    {
        states_restore_timers();
    }
    
    if ((old_state == SOURCE_STATE_CONNECTING) && 
        !audio_get_aghfp_conn_delay() &&
        !audio_get_a2dp_conn_delay())
    {
        /* start any audio immediately as this side initiated connection */
        MessageSend(app_get_instance(), APP_AUDIO_START, 0);
    }
    else
    {
        /* start any audio after the configured delay as this side didn't initiate connection */
        MessageSendLater(app_get_instance(), APP_AUDIO_START, 0,connection_mgr_get_audio_delay_timer());
    }
}
/****************************************************************************
NAME    
    states_restore_timers -

DESCRIPTION
     Stops the timer

RETURNS
    void
*/
void states_restore_timers(void)
{
    if (states_get_timer_stopped_value())
    {
        /* note that timers have been restored */
        states_set_timer_stopped_value(FALSE);
    }
}
/****************************************************************************
NAME    
    states_get_timer_stopped_value - 

DESCRIPTION
    Helper function to Get the timer stopped variable

RETURNS
    bool
*/
static bool states_get_timer_stopped_value(void)
{
    return TIMER_RUNDATA.timers_stopped;
}
/****************************************************************************
NAME    
    states_set_timer_stopped_value 

DESCRIPTION
    Helper function to set the timer stopped variable

RETURNS
    void
*/
static void states_set_timer_stopped_value(bool timers_stopped)
{
    TIMER_RUNDATA.timers_stopped = timers_stopped;
}
/****************************************************************************
NAME    
    states_enter_state_discoverable - Called when entering the SOURCE_STATE_DISCOVERABLE application state
*/
static void states_enter_state_configure_mode(void)
{
}

