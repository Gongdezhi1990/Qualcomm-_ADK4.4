/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_app_msg_handler.c

DESCRIPTION
    Application message handler
    
*/


/* header for this file */
#include "source_app_msg_handler.h"
/* application header files */
#include "source_a2dp.h"
#include "source_avrcp.h"
#include "source_debug.h"
#include "source_init.h"
#include "source_inquiry.h"
#include "source_power.h" 
#include "source_scan.h"
#include "source_states.h"
#include "source_usb.h"
#include "source_aghfp.h"
#include "source_audio.h"
#include "source_connection_mgr.h"
#include "source_ahi.h"
#include "source_button_handler.h"
/* profile/library headers */
#include <audio.h>
#include <connection.h>
#include <ahi.h>
/* VM headers */
#include <psu.h>


#ifdef DEBUG_APP_MSG
    #define APP_MSG_DEBUG(x) DEBUG(x)
#else
    #define APP_MSG_DEBUG(x)
#endif


/* Display unhandled states in Debug Mode */
#define app_msg_unhandled_state() APP_MSG_DEBUG(("APP MSG Ignored; state [%d]\n", states_get_state()));


/* Application message handling functions */
static void app_init_cfm(void);
static void app_connect_success_cfm(void);
static void app_connect_fail_cfm(void);
static void app_disconnect_ind(void);
static void app_connect_req(const APP_CONNECT_REQ_T *message);
static void app_disconnect_req(void);
static void app_disconnect_signalling_req(void);
static void app_linkloss_ind(void);
static void app_inquiry_idle_timeout(void);
static void app_discovery_state_timeout(void);
static void app_inquiry_continue(void);
static void app_enter_pairing_state_from_idle(void);
static void app_enter_connectable_state_from_idle(void);
static void app_usb_audio_active(void);
static void app_usb_audio_inactive(void);
static void app_mic_audio_active(void);
static void app_mic_audio_inactive(void);
        

/***************************************************************************
Functions
****************************************************************************
*/

/*******************************************************************************
    App message handler
*/

static void app_msg_handler(Task task, MessageId id, Message message)
{
    switch (id)
    {
        /* confirmation that the application has been initialised */
        case APP_INIT_CFM:
        {
            APP_MSG_DEBUG(("APP_INIT_CFM\n"));
            app_init_cfm();
        }
        break;
        
        /* confirmation that a connection attempt has successfully completed */
        case APP_CONNECT_SUCCESS_CFM:
        {
            APP_MSG_DEBUG(("APP_CONNECT_SUCCESS_CFM\n"));
            app_connect_success_cfm();
        }
        break;
        
        /* confirmation that a connection attempt has failed */
        case APP_CONNECT_FAIL_CFM:
        {
            APP_MSG_DEBUG(("APP_CONNECT_FAIL_CFM\n"));            
            app_connect_fail_cfm();
        }
        break;
        
        /* indication that a disconnection has occurred */
        case APP_DISCONNECT_IND:
        {
            APP_MSG_DEBUG(("APP_DISCONNECT_IND\n"));            
            app_disconnect_ind();
        }
        break;
        
        /* request to initiate connection to a remote device */
        case APP_CONNECT_REQ:
        {
            APP_MSG_DEBUG(("APP_CONNECT_REQ\n"));            
            app_connect_req((APP_CONNECT_REQ_T *)message);
        }
        break;
        
        /* request to disconnect from a remote device */
        case APP_DISCONNECT_REQ:
        {
            APP_MSG_DEBUG(("APP_DISCONNECT_REQ\n"));            
            app_disconnect_req();
        }
        break;
        
        /* request to disconnect all signalling connections */
        case APP_DISCONNECT_SIGNALLING_REQ:
        {
            APP_MSG_DEBUG(("APP_DISCONNECT_SIGNALLING_REQ\n"));            
            app_disconnect_signalling_req();
        }
        break;
        
        /* indication that link loss occurred with a remote device  */
        case APP_LINKLOSS_IND:
        {
            APP_MSG_DEBUG(("APP_LINKLOSS_IND\n"));   
            app_linkloss_ind();
        }
        break;
        
        /* message that indicates that inquiry has timed out */
        case APP_INQUIRY_STATE_TIMEOUT:
        {
            APP_MSG_DEBUG(("APP_INQUIRY_STATE_TIMEOUT\n"));  
            if (inquiry_get_inquiry_data())
            {
                inquiry_set_inquiry_state_timeout(1);
            }
        }
        break;
        
        /* message that inidicates that the wait between inquiry attempts has elapsed  */
        case APP_INQUIRY_IDLE_TIMEOUT:
        {
            APP_MSG_DEBUG(("APP_INQUIRY_IDLE_TIMEOUT\n"));  
            app_inquiry_idle_timeout();
        }
        break;
        
        /* message that indicates that the discoverable state timer has expired  */
        case APP_DISCOVERY_STATE_TIMEOUT:
        {
            APP_MSG_DEBUG(("APP_DISCOVERY_STATE_TIMEOUT\n"));  
            app_discovery_state_timeout();
        }
        break;        
        /* message to continue inquiry */
        case APP_INQUIRY_CONTINUE:
        {
            APP_MSG_DEBUG(("APP_INQUIRY_CONTINUE\n"));  
            app_inquiry_continue();
        }
        break;
        
        /* message to enter pairing state */
        case APP_ENTER_PAIRING_STATE_FROM_IDLE:
        {
            APP_MSG_DEBUG(("APP_ENTER_PAIRING_STATE_FROM_IDLE\n")); 
            app_enter_pairing_state_from_idle();            
        }
        break;
        
        /* message to enter connectable state */
        case APP_ENTER_CONNECTABLE_STATE_FROM_IDLE:
        {
            APP_MSG_DEBUG(("APP_ENTER_CONNECTABLE_STATE_FROM_IDLE\n")); 
            app_enter_connectable_state_from_idle();            
        }
        break;
        
        /* message to indicate that the rewind released event should be sent */
        case APP_USB_REW_RELEASE:
        {
            APP_MSG_DEBUG(("APP_USB_REW_RELEASE\n")); 
            usb_rewind_release();
        }
        break;
        
        /* message to indicate that the fast forward released event should be sent */
        case APP_USB_FFWD_RELEASE:
        {
            APP_MSG_DEBUG(("APP_USB_FFWD_RELEASE\n")); 
            usb_fast_forward_release();
        }
        break;
        
        /* message to route all audio for the connections that are active */
        case APP_AUDIO_START:
        {
            APP_MSG_DEBUG(("APP_AUDIO_START\n")); 
            audio_route_all();
        }
        break;
        
        /* message to suspend all audio for the connections that are active */
        case APP_AUDIO_SUSPEND:
        {
            APP_MSG_DEBUG(("APP_AUDIO_SUSPEND\n")); 
            audio_suspend_all();
        }
        break;   
        
        /* message to power on the device from the SOURCE_STATE_POWERED_OFF state */
        case APP_POWER_ON_DEVICE:
        {
            APP_MSG_DEBUG(("APP_POWER_ON_DEVICE\n")); 
            /* cancel any further queued messages */
            MessageCancelAll(app_get_instance(), APP_POWER_ON_DEVICE);
            MessageCancelAll(app_get_instance(), APP_POWER_OFF_DEVICE);

            /* move to IDLE state and connections will be handled from here */
            states_set_state(SOURCE_STATE_IDLE);
        }
        break;
        
        /* message to physically power off the device from the SOURCE_STATE_POWERED_OFF state */
        case APP_POWER_OFF_DEVICE:
        {
            APP_MSG_DEBUG(("APP_POWER_OFF_DEVICE\n")); 
            app_power_device(FALSE);
        }
        break;
        
        case APP_USB_AUDIO_ACTIVE:
        {
            APP_MSG_DEBUG(("APP_USB_AUDIO_ACTIVE\n")); 
            app_usb_audio_active();
        }
        break;
        
        case APP_USB_AUDIO_INACTIVE:
        {
            APP_MSG_DEBUG(("APP_USB_AUDIO_INACTIVE\n")); 
            app_usb_audio_inactive();
        }
        break;
        
        case APP_STORE_DEVICE_ATTRIBUTES:
        {
            APP_MSG_DEBUG(("APP_STORE_DEVICE_ATTRIBUTES\n")); 
            connection_mgr_write_device_attributes(&((APP_STORE_DEVICE_ATTRIBUTES_T *)message)->addr,
                                       ((APP_STORE_DEVICE_ATTRIBUTES_T *)message)->attributes);
        }
        break;
        
        case APP_MIC_AUDIO_ACTIVE:
        {
            APP_MSG_DEBUG(("APP_MIC_AUDIO_ACTIVE\n")); 
            app_mic_audio_active();
        }
        break;
        
        case APP_MIC_AUDIO_INACTIVE:
        {
            APP_MSG_DEBUG(("APP_MIC_AUDIO_INACTIVE\n")); 
            app_mic_audio_inactive();
        }
        break;
        
        default:
        {
           APP_MSG_DEBUG(("Unhandled App msg 0x%x\n", id));
        }
        break;
    }
}

/*******************************************************************************
    AHI message handler
*/
static void ahi_handler(Task task, MessageId id, Message message)
{

    switch (id)
    {
        case AHI_APP_MODE_CHANGE_REQ:
        {
            AHI_APP_MODE_CHANGE_REQ_T *msg = (AHI_APP_MODE_CHANGE_REQ_T *)message;

            bool reboot_needed = sourceAhiIsRebootRequired(msg->app_mode);

            if( sourceAhiSetAppMode(msg->app_mode) == source_ahi_status_succeeded )
            {
                if(reboot_needed)
                {
                    /* TODO */
                    /* Add all code that needs to be run before reboot */
                }
                AhiAppModeChangeCfm(msg->app_mode, reboot_needed);
            }
            else
            {
                AhiAppModeChangeCfm(sourceAhiGetAppMode(), FALSE);
            }
        }
        break;
        
        case AHI_APP_TRANSPORT_DISABLE_REQ:
        {
            if (source_ahi_status_succeeded == sourceAhiSetUsbHidDataLinkState(source_ahi_usb_hid_datalink_disabled))
                AhiAppTransportDisableCfm(ahi_status_success);
            else
                AhiAppTransportDisableCfm(ahi_status_bad_parameter);
        }
        break;
        
        default:
        APP_MSG_DEBUG(("Unhandled AHI msg 0x%x\n", id));
    }
}

/****************************************************************************
NAME    
    app_handler - Handles application messages.
*/
void app_handler(Task task, MessageId id, Message message)
{  

    if((id >= APP_INIT_CFM) && (id <APP_INTERNAL_MESSAGE_TOP))
    {
        app_msg_handler(task,id,message);
    }    
    else if((id >= AHI_MESSAGE_BASE) && (id < AHI_LAST_APP_MESSAGE))
    {
        ahi_handler(task,id,message);
    }
    #ifdef INCLUDE_BUTTONS
    else if((id >= BUTTON_MSG_ENTER_PAIRING_MODE) && (id <= PIO_RAW))
    {
        button_msg_handler(task,id,message);
    #ifdef ENABLE_AHI_TEST_WRAPPER
        AhiTestReportEvent(id, 0,0);
    #endif
    }
    #endif
    else
    {
        switch (id)
        {
            case AVRCP_CONNECT_CFM:
            {
                APP_MSG_DEBUG(("AVRCP_CONNECT_CFM\n"));
                /* AVRCP connect confirmation can be sent to this handler if no free  
                    AVRCP instances were found during an incoming connection.
                    The message can just be ignored. */            
            }
            break;
                    
            default:
            {
                APP_MSG_DEBUG(("APP message unrecognised!\n"));
            }
            break;                
        }
    }
}


/****************************************************************************
NAME    
    app_power_device - Latches power on and removes power from the device
*/
void app_power_device(bool enable)
{
#ifdef ANALOGUE_INPUT_DEVICE   
    
#ifdef BC5_MULTIMEDIA
    
    if (enable || (!enable && !power_is_charger_connected()))
    {
        PsuConfigure(PSU_SMPS0, PSU_ENABLE, enable);
    }
    
#else
    
    /* when shutting down ensure all psus are off for BC7 chips */
    if (!enable && !power_is_charger_connected())    
    {
        PsuConfigure(PSU_ALL, PSU_ENABLE, enable);
    } 
    
#endif /* BC5_MULTIMEDIA */
    
#endif /* ANALOGUE_INPUT_DEVICE  */    
}


/****************************************************************************
NAME    
    app_init_cfm - Called when the application has been initialised.
*/
static void app_init_cfm(void)
{
    /* write Class of Device */
    ConnectionWriteClassOfDevice(COD_MAJOR_CAPTURING | COD_MAJOR_AV | COD_MINOR_AV_HIFI_AUDIO);
        
    /* must enter idle state initially on power on */
    states_set_state(SOURCE_STATE_IDLE);   
}


/****************************************************************************
NAME    
    app_connect_success_cfm - Called when on a successful connection event.
*/
static void app_connect_success_cfm(void)
{ 
    connection_mgr_set_Profile(TRUE);
    
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTING:
        {
            if (!connection_mgr_connect_next_profile())
            {
                /* go on to attempt connection to a second device if this side is currently initiating the connection */
                if (!connection_mgr_connect_further_device(FALSE))
                {
                    states_set_state(SOURCE_STATE_CONNECTED);
                }
            }
        }
        break;
            
        case SOURCE_STATE_IDLE:
        case SOURCE_STATE_CONNECTABLE:
        case SOURCE_STATE_DISCOVERABLE:                
        case SOURCE_STATE_INQUIRING:
        {                        
            if (!connection_mgr_connect_next_profile())
            {
                /* move to connected state */
                states_set_state(SOURCE_STATE_CONNECTED);
            }
        }
        break;
        
        case SOURCE_STATE_POWERED_OFF:
        case SOURCE_STATE_TEST_MODE:
        {
            MessageSend(app_get_instance(), APP_DISCONNECT_REQ, 0);
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
    
    /* see if scan has to be updated due to new connection */
    scan_check_connection_state();
}


/****************************************************************************
NAME    
    app_connect_fail_cfm - Called when on a failed connection event.
*/
static void app_connect_fail_cfm(void)
{ 
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTING:
        {            
            if (!connection_mgr_connect_next_profile())
            {            
                /* all supported profiles attempted */
                if (!connection_mgr_any_connected_profiles())
                {         
                    /* no active profile connections */
                    /* attempt connection to device from paired list */
                    if (!connection_mgr_connect_next_paired_device())
                    {
                        if (!connection_mgr_connect_further_device(connection_mgr_get_manual_2nd_connection()))
                        {
                            /* update state */
                            states_set_state(SOURCE_STATE_IDLE);
                        }
                    }
                }  
                else
                {
                    if (!connection_mgr_connect_further_device(connection_mgr_get_manual_2nd_connection()))
                    {
                        /* a profile is still connected so update state */
                        states_set_state(SOURCE_STATE_CONNECTED);
                    }
                }     
            }
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }     
    
    /* see if scan has to be updated after failed connection */
    scan_check_connection_state();
}


/****************************************************************************
NAME    
    app_disconnect_ind - Called when on a disconnection event.
*/
static void app_disconnect_ind(void)
{
    if (!connection_mgr_any_connected_profiles())
    {
        connection_mgr_set_Profile(FALSE);
    }
    else
    {
        connection_mgr_set_Profile(TRUE);
    }
    
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTED:
        {
            /* only change state if all profiles are disconnected */
            if (!connection_mgr_get_profile_connected())
            {                
                /* update state */
                states_set_state(SOURCE_STATE_IDLE);
            }
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }       
    
    /* see if scan has to be updated due to disconnection */
    scan_check_connection_state();
}


/****************************************************************************
NAME    
    app_connect_req - Called to start a connection attempt.
*/
static void app_connect_req(const APP_CONNECT_REQ_T *message)
{
    APP_MSG_DEBUG(("APP_MSG: app_connect_req\n"));

    /* cancel any other connection requests as they may come from user or be automatically generated */
    MessageCancelAll(app_get_instance(), APP_CONNECT_REQ);
    
    switch (states_get_state())
    {
        case SOURCE_STATE_IDLE:
        case SOURCE_STATE_CONNECTABLE:
        case SOURCE_STATE_DISCOVERABLE:
        case SOURCE_STATE_INQUIRING: /* connect after device found through inquiry */
        case SOURCE_STATE_CONNECTING: /* this will occur when trying to connect further profiles - re-enter state to kick connection */
        case SOURCE_STATE_CONNECTED:
        {
            /* suspend any active audio */
            MessageSend(app_get_instance(), APP_AUDIO_SUSPEND, 0);
            /* connect to remote device */
            if (BdaddrIsZero(connection_mgr_get_remote_address()) || message->force_inquiry_mode)
            {                
                states_set_state(SOURCE_STATE_INQUIRING);
            }
            else
            {                
                states_set_state(SOURCE_STATE_CONNECTING);              
            }
        }
        break;
               
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    app_disconnect_req - Called to start a disconnection attempt. If A2DP media is open this will be closed first.
                            Then a APP_DISCONNECT_SIGNALLING_REQ message will be sent.
*/
static void app_disconnect_req(void)
{
    uint16 delay = 0;
    
    APP_MSG_DEBUG(("APP_MSG: app_disconnect_req\n"));
    
    /* close A2DP media first then signalling connections in the White Paper disconnection order */
    if (a2dp_disconnect_media())
    {
        delay = A2DP_MEDIA_CLOSE_TIMEOUT;
        connection_mgr_set_a2dp_media_before_signalling(TRUE);
    }
    
    MessageSendLater(app_get_instance(), APP_DISCONNECT_SIGNALLING_REQ, 0, delay);
}


/****************************************************************************
NAME    
    app_linkloss_ind - Called when linkloss has occurred and the link_loss_reconnect_delay_timer has expired.
*/
static void app_linkloss_ind(void)
{
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTABLE:        
        {
            /* If a connection request is queued in the Connectable state then send the connection request now.
                The application should reconnect after the link_loss_reconnect_delay_timer has expired which has now occurred. */
            if (MessageCancelFirst(app_get_instance(), APP_CONNECT_REQ))
            {
                MAKE_MESSAGE(APP_CONNECT_REQ);
                message->force_inquiry_mode = FALSE;
                MessageSend(app_get_instance(), APP_CONNECT_REQ, message);
                APP_MSG_DEBUG(("APP_MSG: Reconnect now due to link loss\n"));
            }
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    app_disconnect_signalling_req - Called to disconnect all signalling connections.
*/
static void app_disconnect_signalling_req(void)
{
    APP_MSG_DEBUG(("APP_MSG: app_disconnect_signalling_req\n"));
    
    /* disconnecting signalling now so reset the disconnecting media flag */
    connection_mgr_set_a2dp_media_before_signalling(FALSE);
    
    /* disconnect all profiles - the disconnect order complies with multi profile Whitepapers */
    
    /* must try to disconnect AVRCP regardless of state */
    avrcp_disconnect_all();
    /* must try to disconnect A2DP regardless of state */
    a2dp_disconnect_all(); 
    /* must try to disconnect AGHFP regardless of state */
    aghfp_disconnect_all();
}


/****************************************************************************
NAME    
    app_inquiry_idle_timeout - Called after inquiry has been idle for a set amount of time
*/
static void app_inquiry_idle_timeout(void)
{
    APP_MSG_DEBUG(("APP_MSG: app_inquiry_idle_timeout\n"));
    switch (states_get_state())
    {
        case SOURCE_STATE_DISCOVERABLE:        
        case SOURCE_STATE_IDLE:
        {
            /* restart inquiry after idle timeout */
            states_set_state(SOURCE_STATE_INQUIRING);
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}

/****************************************************************************
NAME    
    app_discovery_state_timeout - Called after discovery state timer has expired.

*/
static void app_discovery_state_timeout(void)
{
    switch (states_get_state())
    {
        case SOURCE_STATE_DISCOVERABLE:
        {
            /* restart inquiry after discovery state timeout */
            states_set_state(SOURCE_STATE_INQUIRING);
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}
/****************************************************************************
NAME    
    app_inquiry_continue - Called to continue inquiry
*/
static void app_inquiry_continue(void)
{
    APP_MSG_DEBUG(("APP_MSG: app_inquiry_continue\n"));
    
    switch (states_get_state())
    {
        case SOURCE_STATE_INQUIRING:        
        {
            /* continue inquiry */
            inquiry_process_results();
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    app_enter_pairing_state_from_idle - Called to move from an idle state into DISCOVERABLE state
*/
static void app_enter_pairing_state_from_idle(void)
{
    switch (states_get_state())
    {
        /* only enter pairing mode if not involved in inquiry/connection */
        case SOURCE_STATE_IDLE:
        case SOURCE_STATE_CONNECTABLE:        
        {
            inquiry_complete();
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    app_enter_connectable_state_from_idle - Called to move an idle state into CONNECTABLE state
*/
static void app_enter_connectable_state_from_idle(void)
{
    /* only enter connectable mode if not involved in inquiry/connection */
    switch (states_get_state())
    {
        case SOURCE_STATE_IDLE:
        case SOURCE_STATE_DISCOVERABLE:        
        {
            states_set_state(SOURCE_STATE_CONNECTABLE);
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    app_usb_audio_active - Called when USB audio has been activated
*/
static void app_usb_audio_active(void)
{
    /* route audio if connected to a device */
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTED:
        {
            MessageSend(app_get_instance(), APP_AUDIO_START, 0);
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    app_usb_audio_inactive - Called when USB audio has been de-activated
*/
static void app_usb_audio_inactive(void)
{
    /* route audio if connected to a device */
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTED:
        {
            MessageSend(app_get_instance(), APP_AUDIO_SUSPEND, 0);
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    app_mic_audio_active - Called when USB mic audio has been activated
*/
static void app_mic_audio_active(void)
{
    /* route audio if connected to a device */
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTED:
        {
            if ((audio_get_voip_music_mode() != AUDIO_VOIP_MODE) && connection_mgr_is_aghfp_profile_enabled())
            {
                audio_switch_voip_music_mode(AUDIO_VOIP_MODE);
            }
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


/****************************************************************************
NAME    
    app_mic_audio_inactive - Called when USB mic audio has been de-activated
*/
static void app_mic_audio_inactive(void)
{
    /* route audio if connected to a device */
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTED:
        {
            if ((audio_get_voip_music_mode() == AUDIO_VOIP_MODE) && connection_mgr_is_a2dp_profile_enabled())
            {
                audio_switch_voip_music_mode(AUDIO_MUSIC_MODE);
            }
        }
        break;
        
        default:
        {
            app_msg_unhandled_state();
        }
        break;
    }
}


