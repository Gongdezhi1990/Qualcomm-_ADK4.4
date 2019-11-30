/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_connection_mgr.c

DESCRIPTION
    Connection manager for handling connection to remote devices.

*/


/* header for this file */
#include "source_connection_mgr.h"
/* application header files */
#include "source_app_msg_handler.h"
#include "source_debug.h"
#include "source_led_handler.h"
#include "source_private.h"
#include "source_states.h"
#include "source_memory.h"
#include "source_led_error.h"
#include "source_private_data_config_def.h"
#include "Source_configmanager.h" 
#include "source_aghfp.h"

#ifdef DEBUG_CONNECTION_MGR
    #define CONNECTION_MGR_DEBUG(x) DEBUG(x)
#else
    #define CONNECTION_MGR_DEBUG(x)
#endif    

/* structure holding the connection variables */
typedef struct
{
    bdaddr remote_connection_addr;      
    unsigned remote_profiles_attempted:8;
    unsigned paired_device_index:8;
    unsigned paired_device_start:8;
    unsigned supported_profiles:8;      
    uint16 remote_manufacturer;
    uint16 profile_connected;
    CONNECTION_DEVICE_T device_number:2;  
    unsigned connected_device_ps_slot:2;
    unsigned manual_2nd_connection:1;
    unsigned disconnecting_a2dp_media_before_signalling:1;
    CONNECTION_PIN_CODE_STORE_T *connection_pin;
    uint16 connection_retries;
} CONNECTION_DATA_T;

static CONNECTION_DATA_T CONN_RUN_DATA;

/* local conection functions */
static void connection_mgr_set_remote_device(const bdaddr *addr);
static void connection_mgr_clear_remote_device(void);
static void connection_mgr_set_profile_attempt(PROFILES_T profile);
static void connection_mgr_restart_paired_device(void);
static bool connection_mgr_next_paired_device(typed_bdaddr *addr);

/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    connection_mgr_can_pair - Determines if a pairing attempt should be accepted or rejected
*/    
bool connection_mgr_can_pair(const bdaddr *bd_addr)
{
    switch (states_get_state())
    {        
        case SOURCE_STATE_INQUIRING:
        case SOURCE_STATE_CONNECTING:        
        {
            /* the remote connection address should be set in these states */
            if (!BdaddrIsZero(connection_mgr_get_remote_address()))
            {
                /* only accept pairing if this is the device currently in negotiation with */
                if (BdaddrIsSame(connection_mgr_get_remote_address(), bd_addr))
                    return TRUE;
                else
                    return FALSE;
            }
        }
        break;
        
        case SOURCE_STATE_DISCOVERABLE:        
        {
            return TRUE;
        }
        break;
        
        default:
        {
            /* fall through to end of function */
        }
        break;
    }
    
    return FALSE;
}


/****************************************************************************
NAME    
    connection_mgr_can_connect - Determines if an incoming connection should be accepted or rejected
*/ 
bool connection_mgr_can_connect(const bdaddr *bd_addr, PROFILES_T profile_connecting)
{
    switch (states_get_state())
    {
        case SOURCE_STATE_CONNECTABLE:
        case SOURCE_STATE_DISCOVERABLE:
        case SOURCE_STATE_CONNECTED:
        {
            /* only allow incoming connection in these states */
            return TRUE;
        }
        break;
        
        case SOURCE_STATE_CONNECTING:
        {
            /* only allow incoming connection when connecting if the profiles are not connecting */
            if (!aghfp_is_connecting() && !a2dp_is_connecting())
                return TRUE;
        }
        break;
        
        default:
        {
            /* fall through to end of function */
        }
        break;
    }
    
    return FALSE;
}


/****************************************************************************
NAME    
    connection_mgr_start_connection_attempt - Begins connecting to a remote device by sending the APP_CONNECT_REQ message
*/
void connection_mgr_start_connection_attempt(const bdaddr *addr, PROFILES_T profile, uint16 delay)
{
    bdaddr  bt_addr = {0,0,0};

    MAKE_MESSAGE(APP_CONNECT_REQ); 
    message->force_inquiry_mode = FALSE;

    CONNECTION_MGR_DEBUG(("CM: Start remote connection attempt\n"));
    
    /* clear previous connection attempts and set profile to connect with */
    connection_mgr_clear_remote_device();
    connection_mgr_clear_attempted_profiles();
    connection_mgr_set_profile_attempt(profile);    
    
    if (addr != NULL)
    {
        CONNECTION_MGR_DEBUG(("    address supplied\n"));
        /* use address if supplied */
        connection_mgr_set_remote_device(addr);
    }
    else
    {
        /* not connecting to a specific address so force inquiry if the flag has been set */
        message->force_inquiry_mode = inquiry_get_forced_inquiry_mode();
        /* find address to use */
        if (connection_mgr_get_connect_policy() == CONNECT_LAST_DEVICE)
        {
            CONNECTION_MGR_DEBUG(("connect to last\n"));
            connection_mgr_get_remote_device_address(&bt_addr);
            /* address of last used remote device stored in PS */
            connection_mgr_set_remote_device(&bt_addr);
        }
        else
        {
            /* get address from the paired device list */
            typed_bdaddr paired_addr;
            bool paired_found = FALSE;
            
            connection_mgr_restart_paired_device();
            paired_found = connection_mgr_next_paired_device(&paired_addr);
            
            if (paired_found)
            {                
                CONNECTION_MGR_DEBUG(("    connect to paired\n"));
                DEBUG_BDADDR(paired_addr.addr);
                connection_mgr_set_remote_device(&paired_addr.addr);
            }
            else
            {
                CONNECTION_MGR_DEBUG(("    no device found\n"));
                /* don't wait for delay as there are no paired devices */
                delay = 0;
            }
        }
    }
    
    MessageSendLater(app_get_instance(), APP_CONNECT_REQ, message, D_SEC(delay));
}


/****************************************************************************
NAME    
    connection_mgr_connect_next_profile - Continues the connection attempt using the next profile that is enabled
*/
bool connection_mgr_connect_next_profile(void)
{       
    uint16 supported_profiles = CONN_RUN_DATA.supported_profiles;
    uint16 current_profile = connection_mgr_get_current_profile();   
    
    CONNECTION_MGR_DEBUG(("CM: Connect Next Profile - supported_profiles [%d] current_profile [%d]\n", supported_profiles, current_profile));
    
    while (current_profile != PROFILE_NONE)
    {
        /* move to next profile to try */
        current_profile = current_profile >> 1;  
        CONNECTION_MGR_DEBUG(("    current_profile [%d]\n", current_profile));
        
        /* break if this next profile is supported */
        if (current_profile & supported_profiles)
        {
            CONNECTION_MGR_DEBUG(("    profile found\n"));
            break; 
        }                
    }
            
    CONNECTION_MGR_DEBUG(("        next profile [%d]\n", current_profile));
    
    if (current_profile != PROFILE_NONE)
    {
        uint16 delay;
        MAKE_MESSAGE(APP_CONNECT_REQ);
        /* wait for the delay specified in the PS Key, to give chance for the remote device to connect the next profile */
        delay = connection_mgr_get_profile_connection_delay_timer();
        /* set profile to connect with */
        connection_mgr_set_profile_attempt(current_profile);
        /* send connect message */
        message->force_inquiry_mode = FALSE;
        MessageSendLater(app_get_instance(), APP_CONNECT_REQ, message, delay);
        
        return TRUE;
    }

    return FALSE;
}


/****************************************************************************
NAME    
    connection_mgr_connect_next_paired_device - Continues the connection attempt to the next device in the paired device list
*/
bool connection_mgr_connect_next_paired_device(void)
{
    typed_bdaddr paired_device;
    
    if (connection_mgr_next_paired_device(&paired_device))
    {
        MAKE_MESSAGE(APP_CONNECT_REQ); 
        /* connect to next device from the paired device list, setting the profile to try first */
        connection_mgr_clear_attempted_profiles();
        connection_mgr_set_profile_attempt(connection_mgr_is_aghfp_profile_enabled() ? PROFILE_AGHFP : PROFILE_A2DP);
        connection_mgr_set_remote_device(&paired_device.addr);
        message->force_inquiry_mode = FALSE;
        MessageSend(app_get_instance(), APP_CONNECT_REQ, message);
        
        return TRUE;
    }
    
    return FALSE;
}


/****************************************************************************
NAME    
    connection_mgr_set_incoming_connection - Stores the remote device as the device to connect with
*/
void connection_mgr_set_incoming_connection(PROFILES_T profile, const bdaddr *addr)
{
    /* store the incoming connection as the device to connect with */
    connection_mgr_clear_attempted_profiles();
    connection_mgr_set_profile_attempt(profile);
    connection_mgr_set_remote_device(addr);    
    
    /* Cancel any outgoing connecting requests as the remote device is trying to connect.
        Further profiles will be connected by the dongle on confirmation of connection. */
    MessageCancelAll(app_get_instance(), APP_CONNECT_REQ);
}


/****************************************************************************
NAME    
    connection_mgr_clear_attempted_profiles - Resets which profiles have been attempted
*/
void connection_mgr_clear_attempted_profiles(void)
{
    CONN_RUN_DATA.remote_profiles_attempted = 0;
    
    CONNECTION_MGR_DEBUG(("CM: Clear attempted profiles\n"));
}


/****************************************************************************
NAME    
    connection_mgr_get_current_profile - Returns which profile is currently being used in a connection attempt
*/
PROFILES_T connection_mgr_get_current_profile(void)
{
    CONNECTION_MGR_DEBUG(("CM: Get current profile [%d]\n", CONN_RUN_DATA.remote_profiles_attempted));
    
    /* get current active profile based on what has been attempted - AGHFP always tried before A2DP */
    if (CONN_RUN_DATA.remote_profiles_attempted & PROFILE_A2DP)
        return PROFILE_A2DP;
    if (CONN_RUN_DATA.remote_profiles_attempted & PROFILE_AGHFP)
        return PROFILE_AGHFP; 
    
    return PROFILE_NONE;
}


/****************************************************************************
NAME    
    connection_mgr_any_connected_profiles - Returns if any profiles are currently connected
*/
bool connection_mgr_any_connected_profiles(void)
{
    if (a2dp_get_number_connections() || aghfp_get_number_connections())
    {
        /* profiles connected */
        return TRUE;
    }
    
    /* no connections */
    return FALSE;
}


/****************************************************************************
NAME    
    connection_mgr_connect_further_device - Attempts to connect to a further remote device
*/
bool connection_mgr_connect_further_device(bool manual_connect)
{
    bool initial_manual_connect = connection_mgr_get_manual_2nd_connection();
    bdaddr  addr = {0,0,0};
    bdaddr  dual_stream_addr = {0,0,0};
    
    /* store the manual connect flag passed in */
    connection_mgr_set_manual_2nd_connection(manual_connect);
    
    if (A2DP_DUALSTREAM_ENABLED)
    {        
        if (manual_connect || (!manual_connect && A2DP_DUALSTREAM_CONNECT_NEXT))
        {
            CONNECTION_MGR_DEBUG(("CM: connection_mgr_connect_further_device\n"));
        
            if (connection_mgr_get_connect_policy() == CONNECT_LAST_DEVICE)
            {
                /* get address from the last used PS Key */
                
                bdaddr connect_addr, addr_a, addr_b;
                
                BdaddrSetZero(&connect_addr);
                BdaddrSetZero(&addr_a);
                BdaddrSetZero(&addr_b);
                
                a2dp_get_connected_addr(&addr_a, &addr_b);
                connection_mgr_get_dualstream_second_device_bt_address(&dual_stream_addr);
                if (BdaddrIsSame(&addr_a, &dual_stream_addr) &&
                    !BdaddrIsZero(&addr_a))
                {
                    connection_mgr_get_remote_device_address(&addr);
                    /* the device stored in the second PS Key is connected, so connect the first PS Key device */
                    memcpy(&connect_addr,&addr,sizeof(bdaddr));
                    CONNECTION_MGR_DEBUG(("    connect first PS Key device\n"));
                }
                else if (!BdaddrIsZero(&dual_stream_addr))
                {
                    /* the device stored in the first PS Key is connected, so connect the second PS Key device */
                    memcpy(&connect_addr,&dual_stream_addr,sizeof(bdaddr));
                    CONNECTION_MGR_DEBUG(("    connect second PS Key device\n"));
                }
                    
                /* Connect to second device if it has been found. Don't connect to it if connection has already been attempted. */
                if (connection_mgr_is_a2dp_profile_enabled() && 
                    !BdaddrIsZero(&connect_addr) && 
                    BdaddrIsZero(&addr_b) &&
                    (CONN_RUN_DATA.device_number != CONNECTION_DEVICE_SECONDARY))
                {
                    connection_mgr_start_connection_attempt(&connect_addr, PROFILE_A2DP, 0);
                    CONN_RUN_DATA.device_number = CONNECTION_DEVICE_SECONDARY;
                    return TRUE;
                }
            }
            else
            {
                /* get address from the paired device list */
                
                typed_bdaddr paired_addr;
                bool paired_found = FALSE;
                
                if (manual_connect && !initial_manual_connect)
                {
                    /* for user initiated connection attempts start at the beginning of the paired device list */
                    connection_mgr_restart_paired_device();
                }
            
                paired_found = connection_mgr_next_paired_device(&paired_addr);
            
                if (paired_found && a2dp_allow_more_connections())
                {                
                    CONNECTION_MGR_DEBUG(("    connect to paired\n"));
                    DEBUG_BDADDR(paired_addr.addr);
                    /* connect to secondary device from the paired device list */
                    connection_mgr_start_connection_attempt(&paired_addr.addr, PROFILE_A2DP, 0);
                    CONN_RUN_DATA.device_number = CONNECTION_DEVICE_SECONDARY;
                    return TRUE;
                }
            }        
        }
    }

    /* reset manual connect flag as no longer connecting to a second device */
    connection_mgr_set_manual_2nd_connection(FALSE);
    
    /* reset to connect with primary device */
    CONN_RUN_DATA.device_number = CONNECTION_DEVICE_PRIMARY;
    
    return FALSE;
}
        

/****************************************************************************
NAME    
    connection_mgr_set_remote_device - Store the device to connect with
*/
static void connection_mgr_set_remote_device(const bdaddr *addr)
{
    /* store the address of the device the source is connecting to */
    CONN_RUN_DATA.remote_connection_addr = *addr;

    CONNECTION_MGR_DEBUG(("CM: Set remote connection addr: \n"));
    DEBUG_BDADDR(CONN_RUN_DATA.remote_connection_addr);
}


/****************************************************************************
NAME    
    connection_mgr_clear_remote_device - Clears the device to connect with
*/
static void connection_mgr_clear_remote_device(void)
{
    /* clear the address of the device the source is connecting to */
    BdaddrSetZero(connection_mgr_get_remote_address());    
    
    CONNECTION_MGR_DEBUG(("CM: Clear remote connection addr\n"));
}


/****************************************************************************
NAME    
    connection_mgr_set_profile_attempt - Keeps a record that the profile passed in has been attempted
*/
static void connection_mgr_set_profile_attempt(PROFILES_T profile)
{
    /* store that this active profile is being attempted */
    CONN_RUN_DATA.remote_profiles_attempted |= profile;
    
    CONNECTION_MGR_DEBUG(("CM: Attempting profile [%d], profiles attempted [%d] \n", profile, CONN_RUN_DATA.remote_profiles_attempted));
}


/****************************************************************************
NAME    
    connection_mgr_restart_paired_device - Resets the indexes back to the beginning of the paired device list
*/
static void connection_mgr_restart_paired_device(void)
{
    CONNECTION_MGR_DEBUG(("CM: Restart Paired Device List\n"));
    
    /* start at the most recently used device from the paired device list */
    CONN_RUN_DATA.paired_device_start = 0;
    CONN_RUN_DATA.paired_device_index = 0;
}


/****************************************************************************
NAME    
    connection_mgr_next_paired_device - Returns the address of the next device from the paired device list.
                                        Will return TRUE if an address is returned in addr.
                                        Will return FALSE if no address is returned.
*/
static bool connection_mgr_next_paired_device(typed_bdaddr *addr)
{
    typed_bdaddr paired_addr;
    uint8 psdata[1];
    const uint16 size_psdata = 0;
    
    CONNECTION_MGR_DEBUG(("CM: Next Paired Device\n"));
    
    if (connection_mgr_get_connect_policy() == CONNECT_LAST_DEVICE)
    {
        /* if the Source is only connect to the last device then not concerned about the paired list */
        
        CONNECTION_MGR_DEBUG(("   no next paired - connect to last device only\n"));
        
        return FALSE;
    }
    
    if (CONN_RUN_DATA.paired_device_index >= connection_mgr_get_number_of_paired_devices())
    {
        /* reached the end of the paired device list, loop back to the beginning */
        CONN_RUN_DATA.paired_device_index = 0;
        if (CONN_RUN_DATA.paired_device_index == CONN_RUN_DATA.paired_device_start)
        {
            /* reached the start again so return that no more paired devices to try */
            
            CONNECTION_MGR_DEBUG(("   no next paired - reached end of list\n"));
            
            return FALSE;
        }
    }
    
    if (ConnectionSmGetIndexedAttributeNowReq(0, CONN_RUN_DATA.paired_device_index, size_psdata, psdata, &paired_addr))
    {
        CONNECTION_MGR_DEBUG(("   next paired - index %d\n", CONN_RUN_DATA.paired_device_index));
        DEBUG_BDADDR(paired_addr.addr);
        
        /* return the address of the device found */
        *addr = paired_addr;
        
        /* increment the index to the paired devices */
        CONN_RUN_DATA.paired_device_index++;
        
        return TRUE;
    }
    
    CONNECTION_MGR_DEBUG(("   no next paired - attribute not found\n"));
    
    return FALSE;
}


/****************************************************************************
NAME    
    connection_mgr_set_profile_connected - Registers a profile connection with the connection manager
*/
void connection_mgr_set_profile_connected(PROFILES_T profile, const bdaddr *addr)
{
    switch (profile)
    {
        case PROFILE_A2DP:
        {
            /* see if the AGHFP profile is connected */
            aghfpInstance *aghfp_inst = aghfp_get_instance_from_bdaddr(addr);
            
            if (aghfp_inst != NULL)
            {
                if (aghfp_is_connected(aghfp_inst->aghfp_state))
                {
                    break;
                }
            }
            
#ifdef INCLUDE_LEDS            
            /* this is the first profile connected for this device, show connected LED indication */
            leds_show_event(LED_EVENT_DEVICE_CONNECTED);
#endif            
        }
        break;
        
        case PROFILE_AGHFP:
        {
            /* see if the A2DP profile is connected */
            a2dpInstance *a2dp_inst = a2dp_get_instance_from_bdaddr(addr);
            
            if (a2dp_inst != NULL)
            {
                if (a2dp_is_connected(a2dp_inst->a2dp_state))
                {
                    break;
                }
            }
#ifdef INCLUDE_LEDS            
            /* this is the first profile connected for this device, show connected LED indication */
            leds_show_event(LED_EVENT_DEVICE_CONNECTED);
#endif            
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
    connection_mgr_set_profile_disconnected - Registers a profile disconnection with the connection manager
*/
void connection_mgr_set_profile_disconnected(PROFILES_T profile, const bdaddr *addr)
{
    switch (profile)
    {
        case PROFILE_A2DP:
        {
            /* see if the AGHFP profile is connected */
            aghfpInstance *aghfp_inst = aghfp_get_instance_from_bdaddr(addr);
            
            if (aghfp_inst != NULL)
            {
                if (aghfp_is_connected(aghfp_inst->aghfp_state))
                {
                    break;
                }
            }
#ifdef INCLUDE_LEDS            
            /* this is the final profile disconnected for this device, show disconnected LED indication */
            leds_show_event(LED_EVENT_DEVICE_DISCONNECTED);
#endif            
        }
        break;
        
        case PROFILE_AGHFP:
        {
            /* see if the A2DP profile is connected */
            a2dpInstance *a2dp_inst = a2dp_get_instance_from_bdaddr(addr);
            
            if (a2dp_inst != NULL)
            {
                if (a2dp_is_connected(a2dp_inst->a2dp_state))
                {
                    break;
                }
            }
#ifdef INCLUDE_LEDS            
            /* this is the final profile disconnected for this device, show disconnected LED indication */
            leds_show_event(LED_EVENT_DEVICE_DISCONNECTED);
#endif            
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
    connection_mgr_reset_pin_codes - Resets the stored PIN codes to their default states.
*/
void connection_mgr_reset_pin_codes(void)
{
    uint16 index = 0;
    
    if (CONN_RUN_DATA.connection_pin)
    {
        CONN_RUN_DATA.connection_pin->device.number_device_pins = 0;
        for (index = 0; index < CONNECTION_MAX_DEVICE_PIN_CODES; index ++)
        {
            BdaddrSetZero(&CONN_RUN_DATA.connection_pin->device.addr[index]);
            CONN_RUN_DATA.connection_pin->device.index[index] = 0;
        }
    }
}



/****************************************************************************
NAME    
    connection_mgr_find_pin_index_by_addr - Find PIN index by the Bluetooth address supplied
*/
uint16 connection_mgr_find_pin_index_by_addr(const bdaddr *addr)
{
    uint16 index = 0;
    uint16 pins_stored = CONN_RUN_DATA.connection_pin->device.number_device_pins;
    
    for (index = 0; index < pins_stored; index++)
    {
        if (BdaddrIsSame(&CONN_RUN_DATA.connection_pin->device.addr[index], addr))
        {
            CONNECTION_MGR_DEBUG(("  found PIN index %d\n", index));
            return index;
        }
    }
    
    CONNECTION_MGR_DEBUG(("  no PIN index\n"));
    
    return INVALID_VALUE;
}


/****************************************************************************
NAME    
    connection_mgr_get_next_pin_code - Return if next PIN code was found for the device with the Bluetooth address supplied     
*/
bool connection_mgr_get_next_pin_code(const bdaddr *addr)
{
    /* may need to try next PIN code */
    uint16 index = connection_mgr_find_pin_index_by_addr(addr);
        
    if (index != INVALID_VALUE)
    {
        CONN_RUN_DATA.connection_pin->device.index[index]++;
        if (CONN_RUN_DATA.connection_pin->device.index[index] >= CONNECTION_MAX_DEVICE_PIN_CODES)
        {
            CONN_RUN_DATA.connection_pin->device.index[index] = 0;                        
        }
        else
        {
            CONNECTION_MGR_DEBUG(("   next PIN code index %d\n", CONN_RUN_DATA.connection_pin->device.index[index]));
            return TRUE;
        }
    }
    
    CONNECTION_MGR_DEBUG(("   no next PIN code\n"));
    
    return FALSE;
}
/****************************************************************************
NAME    
    connection_mgr_write_device_link_mode
    
DESCRIPTION
    Called when receiving the CL_SM_AUTHORISE_CFM message after authorisation has completed
    Write the default device attributes with negotiated link mode to config store.

RETURNS
    void
*/
void connection_mgr_write_device_link_mode(const CL_SM_AUTHENTICATE_CFM_T *cfm)
{
    ATTRIBUTES_T attributes;

    /* Attributes value shall be filled later by respective modules, construct default values here */
    memset(&attributes, 0, sizeof(ATTRIBUTES_T));

    /* Check if the pairing type is secure if secure_connection_mode is secure */
    if(connection_mgr_get_secure_connection_mode()> source_no_secure_connection)
    {
        if((cfm->key_type == cl_sm_link_key_unauthenticated_p256 || 
                   cfm->key_type == cl_sm_link_key_authenticated_p256))
        {
            CONNECTION_MGR_DEBUG((" Secure connection mode = %x\n", connection_mgr_get_secure_connection_mode()));       
            attributes.mode = connection_mgr_get_secure_connection_mode() ? source_secure_connection_mode: source_no_secure_connection;        
        }
    }

    /* store the attributes of the device with this address for the link mode*/
    ConnectionSmPutAttribute(0, &cfm->bd_addr, sizeof(attributes), (uint8*)&attributes);
}
/****************************************************************************
NAME    
    connection_mgr_write_new_remote_device - Write the device to config block ID
*/
void connection_mgr_write_new_remote_device(const bdaddr *addr, PROFILES_T profile)
{
    bdaddr  btaddr = {0,0,0};
    bdaddr  dual_stream_btaddr = {0,0,0};
    bool bdaddr_zero_main_device = FALSE;
    bool bdaddr_zero_stream2_device =  FALSE;

    /* check if the remote device needs to be stored as the one to always connect with */   
    if (!BdaddrIsZero(addr))
    {
        connection_mgr_get_remote_device_address(&btaddr);
        connection_mgr_get_dualstream_second_device_bt_address(&dual_stream_btaddr);
        bdaddr_zero_main_device = BdaddrIsZero(&btaddr);
        bdaddr_zero_stream2_device = BdaddrIsZero(&dual_stream_btaddr);
        
        /* set to be the most recently used device */
        ConnectionSmUpdateMruDevice(addr);
        
        if (!bdaddr_zero_main_device)
        {
            if (BdaddrIsSame(&btaddr, addr))
            {
                /* this device already exists in PS so don't need to store the remote device address */
                CONNECTION_MGR_DEBUG(("CONNECTION_MGR: Write new device - addr already exists as main device\n"));
                return;
            }
        }
        if (A2DP_DUALSTREAM_ENABLED && !bdaddr_zero_stream2_device)
        {
            if (BdaddrIsSame(&dual_stream_btaddr, addr))
            {
                /* this device already exists in PS so don't need to store the remote device address */
                CONNECTION_MGR_DEBUG(("CONNECTION_MGR: Write new device - addr already exists as 2nd device\n"));
                return;
            }
        }
        
        if ((profile == PROFILE_AGHFP) || !A2DP_DUALSTREAM_ENABLED)
        {
            /* write as main device */
            connection_mgr_set_remote_device_address(addr);
            CONNECTION_MGR_DEBUG(("CONNECTION_MGR: Write new device - written as main device\n"));
        }
        else
        {
            /* DualStream enabled - have to check which address to update */
            if (a2dp_get_number_connections() > 1)
            {
                /* write 2nd A2DP device to PS and store locally */
                #ifdef INCLUDE_DUALSTREAM
                connection_mgr_set_dualstream_second_device_bt_address(addr);
                #endif
                CONNECTION_MGR_DEBUG(("CONNECTION_MGR: Write new device - written as 2nd device\n"));
            }
            else
            {
                /* this is the first connection but have to choose which device this is */
                if (bdaddr_zero_main_device)
                {
                    /* no PS Key written for the main device, so store this as the main device */
                    connection_mgr_reset_connected_device_ps_slot();
                }
                else if (bdaddr_zero_stream2_device)
                {
                    /* no PS Key written for the 2nd stream device, so store this as the 2nd stream device */
                    connection_mgr_set_connected_device_ps_slot(1);
                }
            
                if (connection_mgr_get_connected_device_ps_slot() == 0)                    
                {
                    /* write as first device */
                    connection_mgr_set_remote_device_address(addr);
                    /* update to write as 2nd device next time */
                    connection_mgr_set_connected_device_ps_slot(1);
                    CONNECTION_MGR_DEBUG(("CONNECTION_MGR: Write new device - slot 0 written as main device\n"));
                }
                else
                {
                    /* write as 2nd stream device */
                    #ifdef INCLUDE_DUALSTREAM
                    connection_mgr_set_dualstream_second_device_bt_address(addr);
                    #endif
                    /* update to write as 1st device next time */
                    connection_mgr_reset_connected_device_ps_slot();
                    CONNECTION_MGR_DEBUG(("CONNECTION_MGR: Write new device - slot 1 written as 2nd device\n"));
                }             
            }
        }
    }
}
/****************************************************************************
NAME    
    connection_mgr_write_device_name - Write the device name to Config store     
*/
void connection_mgr_write_device_name(const bdaddr *addr, uint16 size_name, const uint8 *name)
{
    ATTRIBUTES_T attributes;

    /* Get the attributes for addr and then update the remote name for the addr */
    ConnectionSmGetAttributeNow(0,addr, sizeof(ATTRIBUTES_T), (uint8*)&attributes);

    if(size_name > MAX_REMOTE_DEVICE_NAME_LEN)
    {
        size_name = MAX_REMOTE_DEVICE_NAME_LEN;
    }

    attributes.remote_name_size = size_name;

    memset(attributes.remote_name, 0, MAX_REMOTE_DEVICE_NAME_LEN);
    memmove(attributes.remote_name, name, size_name);

    /* store the local friendly name of the device with this address */
    ConnectionSmPutAttribute(0, addr, sizeof(attributes), (uint8*)&attributes);
}

/****************************************************************************
NAME    
    ps_write_device_attributes - Write the device attributes to config store     
*/
void connection_mgr_write_device_attributes(const bdaddr *addr, ATTRIBUTES_T attributes)
{
    /* store the attributes of the device with this address */
    ConnectionSmPutAttribute(0, addr, sizeof(attributes), (uint8*)&attributes);
}
/****************************************************************************
NAME    
    connection_mgr_read_pin_code_config_values 

DESCRIPTION
    reads the pin code configuration from the xml file.

RETURNS
    void
**************************************************************************/
void connection_mgr_read_pin_code_config_values(void)
{
   /* Read PIN code config */
   connection_mgr_create_memory_for_connection_pin();
   /* reset stored PIN codes */
   connection_mgr_reset_pin_codes();
   /*Read the values to the CONN_RUN_DATA global data structure*/
   connection_mgr_ps_read_user_for_pincodes();
}
/****************************************************************************
NAME    
    connection_mgr_set_link_supervision_timeout - Sets the link supervision timeout for the link associated with the supplied Sink
*/
void connection_mgr_set_link_supervision_timeout(Sink sink)
{
    ConnectionSetLinkSupervisionTimeout(sink, CONNECTION_LINK_SUPERVISION_TIMEOUT);
}
/****************************************************************************
NAME    
    connection_mgr_get_remote_address - To get the remote address .
*/
bdaddr *connection_mgr_get_remote_address(void)
{
    return &CONN_RUN_DATA.remote_connection_addr;
}
/****************************************************************************
NAME    
    connection_mgr_get_a2dp_media_before_signalling - To get the a2dp_media_before_signalling val .
*/
bool connection_mgr_get_a2dp_media_before_signalling(void)
{
    return CONN_RUN_DATA.disconnecting_a2dp_media_before_signalling;
}
/****************************************************************************
NAME    
    connection_mgr_set_a2dp_media_before_signalling - To get the a2dp_media_before_signalling val .
*/
void connection_mgr_set_a2dp_media_before_signalling(bool a2dp_media_before_signalling)
{
    CONN_RUN_DATA.disconnecting_a2dp_media_before_signalling = a2dp_media_before_signalling;
}
/****************************************************************************
NAME    
    connection_mgr_set_Profile - To set the profile connected value .
*/
void connection_mgr_set_Profile(bool profile_connected)
{
    CONN_RUN_DATA.profile_connected = profile_connected;
}
/****************************************************************************
NAME    
    connection_mgr_get_profile_connected - To gethe profile connected value .
*/
uint16  connection_mgr_get_profile_connected(void)
{
    return CONN_RUN_DATA.profile_connected;
}
/****************************************************************************
NAME    
    connection_mgr_get_manual_2nd_connection - To gethe Manual 2nd Connection .
*/
bool connection_mgr_get_manual_2nd_connection(void)
{
    return CONN_RUN_DATA.manual_2nd_connection;
}
/****************************************************************************
NAME    
    connection_mgr_set_manual_2nd_connection - To set the Manual 2nd Connection .
*/
void connection_mgr_set_manual_2nd_connection(bool manual_2nd_connection)
{
    CONN_RUN_DATA.manual_2nd_connection = manual_2nd_connection;
}
/****************************************************************************
NAME    
    connection_mgr_get_connection_retries - To get the number of connection retries.
*/
uint16  connection_mgr_get_connection_retries(void)
{
    return CONN_RUN_DATA.connection_retries;
}
/****************************************************************************
NAME    
    connection_mgr_reset_connection_retries - To get the number of connection retries.
*/
void  connection_mgr_reset_connection_retries(void)
{
    CONN_RUN_DATA.connection_retries = 0;;
}
/****************************************************************************
NAME    
    connection_mgr_increment_connection_retries - Increments the connection retries
*/
void  connection_mgr_increment_connection_retries(void)
{
    CONN_RUN_DATA.connection_retries++;
}
/****************************************************************************
NAME    
    connection_mgr_reset_remote_manufacturer - To reset the Remote manufacturer
*/
void  connection_mgr_reset_remote_manufacturer(void)
{
    CONN_RUN_DATA.remote_manufacturer = 0;;
}
/****************************************************************************
NAME    
    connection_mgr_set_remote_manufacturer - To reset the Remote manufacturer
*/
void  connection_mgr_set_remote_manufacturer(uint16 remote_manufacturer)
{
    CONN_RUN_DATA.remote_manufacturer = remote_manufacturer;;
}
/****************************************************************************
NAME    
    connection_mgr_get_number_of_device_pins - To get the number of device pins
*/
uint16  connection_mgr_get_number_of_device_pins(void)
{
    return CONN_RUN_DATA.connection_pin->device.number_device_pins;
}
/****************************************************************************
NAME    
    connection_mgr_set_pin_address - To Set the pin address based on index.
*/
void  connection_mgr_set_pin_address(uint16 index, bdaddr  addr)
{
    CONN_RUN_DATA.connection_pin->device.addr[index] = addr;
}
/****************************************************************************
NAME    
    connection_mgr_get_index_value - To Get the index value.
*/
uint16  connection_mgr_get_index_value(uint16 index)
{
    return CONN_RUN_DATA.connection_pin->device.index[index];
}
/****************************************************************************
NAME    
    connection_mgr_Set_Index_value - To Set the pin address based on index.
*/
void  connection_mgr_set_index_value(uint16 index, uint16  value)
{
    CONN_RUN_DATA.connection_pin->device.index[index] = value;
}
/****************************************************************************
NAME    
    connection_mgr_increment_number_of_devicePins - To Increment the number of device pins
*/
void  connection_mgr_increment_number_of_devicePins(void)
{
    CONN_RUN_DATA.connection_pin->device.number_device_pins++;
}
/****************************************************************************
NAME    
    connection_mgr_get_pin_length - To Get the index value.
*/
uint16  connection_mgr_get_pin_length(uint16 code_index)
{
    return sizeof(CONN_RUN_DATA.connection_pin->pin.pin_codes[code_index].code);
}
/****************************************************************************
NAME    
    connection_mgr_get_pin_value - To Get the code value
*/
uint16  connection_mgr_get_pin_value(uint16 code_index,uint16 count)
{
    return CONN_RUN_DATA.connection_pin->pin.pin_codes[code_index].code[count];
}
/****************************************************************************
NAME    
    connection_mgr_set_supported_profiles - To Get the code value
*/
void connection_mgr_set_supported_profiles(PROFILES_T profiles)
{
    switch(profiles)
    {
        case PROFILE_A2DP:
            CONN_RUN_DATA.supported_profiles |= PROFILE_A2DP;
            break;
        case PROFILE_AGHFP:
            CONN_RUN_DATA.supported_profiles |= PROFILE_AGHFP;
            break;
        case PROFILE_AVRCP:
            CONN_RUN_DATA.supported_profiles |= PROFILE_AVRCP;
            break;
         default:
            break;
    }
}
/****************************************************************************
NAME    
    connection_mgr_create_memory_for_connection_pin - Creates memory for Connection PIN
*/
void connection_mgr_create_memory_for_connection_pin(void)
{
    CONN_RUN_DATA.connection_pin = memory_create(sizeof(CONNECTION_PIN_CODE_STORE_T));
}
/****************************************************************************
NAME    
    connection_mgr_ps_read_user_for_pincodes - Creates memory for Connection PIN
*/
void  connection_mgr_ps_read_user_for_pincodes(void)
{
    connection_mgr_get_connection_pin_values(&CONN_RUN_DATA.connection_pin->pin);
}
/****************************************************************************
NAME    
    connection_mgr_set_connected_device_ps_slot - Sets the connected device ps slots
*/
void  connection_mgr_set_connected_device_ps_slot(uint8 connected_device_ps_slot)
{
    CONN_RUN_DATA.connected_device_ps_slot = connected_device_ps_slot ;
}
/****************************************************************************
NAME    
    connection_mgr_reset_connected_device_ps_slot - Resets the connected device ps slots
*/
void  connection_mgr_reset_connected_device_ps_slot(void)
{
    CONN_RUN_DATA.connected_device_ps_slot = 0 ;
}
/****************************************************************************
NAME    
    connection_mgr_get_connected_device_ps_slot - Sets the connected device ps slots
*/
uint8  connection_mgr_get_connected_device_ps_slot(void)
{
    return CONN_RUN_DATA.connected_device_ps_slot ;
}
/****************************************************************************
NAME    
    connection_mgr_is_a2dp_profile_enabled -Checks if A2DP profile is enabled or not 
*/
uint8 connection_mgr_is_a2dp_profile_enabled (void)
{
    return CONN_RUN_DATA.supported_profiles & PROFILE_A2DP;
}
/****************************************************************************
NAME    
    connection_mgr_is_aghfp_profile_enabled -Checks if AGHFP profile is enabled or not 
*/
uint8 connection_mgr_is_aghfp_profile_enabled (void)
{
    return CONN_RUN_DATA.supported_profiles & PROFILE_AGHFP;
}
/****************************************************************************
NAME    
    Source_AGHFP_PROFILE_ENABLED -Checks if AVRCP profile is enabled or not 
*/
uint8 connection_mgr_is_avrcp_profile_enabled (void)
{
    return CONN_RUN_DATA.supported_profiles & PROFILE_AVRCP;
}
/*************************************************************************
NAME
    connection_mgr_get_audio_delay_timer

DESCRIPTION
    Helper function to Get the audio delay timer.

RETURNS
    The  audio delay timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_audio_delay_timer(void)
{
    uint16 audio_delay_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        audio_delay_timer = timer_data->private_data_timers.AudioDelay_ms;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return audio_delay_timer;
}
/*************************************************************************
NAME
    source_timers_connection_idle_timer

DESCRIPTION
    Helper function to Get the Connection Idle timer.

RETURNS
    The  idle timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_idle_timer(void)
{
    uint16 Connection_Idle_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        Connection_Idle_timer = timer_data->private_data_timers.ConnectionIdle_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return Connection_Idle_timer;
}
/*************************************************************************
NAME
    connection_mgr_get_discoverable_timer

DESCRIPTION
    Helper function to Get the Discovery state timer.

RETURNS
    The Discovery state timer read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_discoverable_timer(void)
{
    uint16 Discovery_State_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        Discovery_State_timer = timer_data->private_data_timers.DiscoveryState_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return Discovery_State_timer;
}
/*************************************************************************
NAME
    connection_mgr_get_disconnect_idle_timer

DESCRIPTION
    Helper function to Get the DisconnectIdle timer.

RETURNS
    The disconnect idle timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_disconnect_idle_timer(void)
{
    uint16 Disconnect_Idle_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        Disconnect_Idle_timer = timer_data->private_data_timers.DisconnectIdle_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return Disconnect_Idle_timer;
}
/*************************************************************************
NAME
    connection_mgr_get_combined_max_connection_retries

DESCRIPTION
    Helper function to Get the Combined max connection retries.

RETURNS
    The combined max connection retries  value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_combined_max_connection_retries(void)
{
    uint16 Combined_max_connection_retries = 0;
    sourcedata_readonly_config_def_t *profile_connection_retries;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&profile_connection_retries))
    {
        Combined_max_connection_retries = profile_connection_retries->CombMaxContRetries;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return Combined_max_connection_retries;
}
/*************************************************************************
NAME
    connection_mgr_get_profile_connection_delay_timer

DESCRIPTION
    Helper function to Get the Profile Connection delay timer.

RETURNS
    The profile connection delay  timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_profile_connection_delay_timer(void)
{
    uint16 AVRCP_ProfileDelay_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        AVRCP_ProfileDelay_timer = timer_data->private_data_timers.ProfileConnectionDelay_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return AVRCP_ProfileDelay_timer;
}
/*************************************************************************
NAME
    connection_mgr_get_linkloss_reconnect_delay_timer

DESCRIPTION
    Helper function to Get the Link Loss Reconnect delay timer.

RETURNS
    The link loss reconnect delay  timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_linkloss_reconnect_delay_timer(void)
{
    uint16 LinkLoss_Reconnect_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        LinkLoss_Reconnect_timer = timer_data->private_data_timers.LinkLossReconnectDelay_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return LinkLoss_Reconnect_timer;
}
/*************************************************************************
NAME
    connection_mgr_get_connect_policy

DESCRIPTION
    Helper function to Get the Connect Policy while pairing.

RETURNS
    The current reconnection policy as set in the config block section after power ON.The possible values are:
    0 = Connect to last device
    1 = Iterate through PDL.
    2 = Unassigned.

**************************************************************************/
uint16 connection_mgr_get_connect_policy(void)
{
    uint8 connect_policy = 0;
    sourcedata_readonly_config_def_t *profile_connection_retries;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&profile_connection_retries))
    {
        connect_policy = profile_connection_retries->ReconnectOnPanic;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return connect_policy;
}
/*************************************************************************
NAME
    connection_mgr_get_remote_device_address

DESCRIPTION
    Helper function to Get the Remote device address

RETURNS
   void 

**************************************************************************/
void connection_mgr_get_remote_device_address(bdaddr *addr)
{       

    remote_device_address_config_def_t *bdaddr_remote_device = NULL;

    if (configManagerGetReadOnlyConfig(REMOTE_DEVICE_ADDRESS_CONFIG_BLK_ID, (const void **)&bdaddr_remote_device))
    {
        addr->lap = (((uint32)bdaddr_remote_device->Device_Address.LAP_hi << 16) | ((uint32) (bdaddr_remote_device->Device_Address.LAP_lo) & 0x0000FFFFUL));
        addr->uap = bdaddr_remote_device->Device_Address.UAP;
        addr ->nap = bdaddr_remote_device->Device_Address.NAP;
    }
    configManagerReleaseConfig(REMOTE_DEVICE_ADDRESS_CONFIG_BLK_ID);
}
/*************************************************************************
NAME
    connection_mgr_set_remote_device_address

DESCRIPTION
    Helper function to Set the Remote device address

RETURNS
    void

**************************************************************************/
void connection_mgr_set_remote_device_address(const bdaddr *addr)
{

    remote_device_address_config_def_t *bdaddr_remote_device = NULL;
    
    if (configManagerGetWriteableConfig(REMOTE_DEVICE_ADDRESS_CONFIG_BLK_ID, (void**)&bdaddr_remote_device, 0))
    {
        /* Populate the Bluetooth address to be written */
        if (addr == NULL)
        {
            /* No address passed in, so zero pad the addr part of the key */
            memset(&bdaddr_remote_device->Device_Address, 0, sizeof(bdaddr_remote_device->Device_Address));
        }
        else
        {
            bdaddr_remote_device->Device_Address.LAP_hi = (addr->lap>>16);
            bdaddr_remote_device->Device_Address.LAP_lo = (uint16)addr->lap;
            bdaddr_remote_device->Device_Address.NAP = addr->nap;
            bdaddr_remote_device->Device_Address.UAP = addr->uap;
        }
   }
   configManagerUpdateWriteableConfig(REMOTE_DEVICE_ADDRESS_CONFIG_BLK_ID);
}
#ifdef INCLUDE_DUALSTREAM
/*************************************************************************
NAME
    connection_mgr_get_dualstream_second_device_bt_address

DESCRIPTION
    Helper function to Get the Dual Stream 2nd Device Bluetooth Address

RETURNS
    void

**************************************************************************/
void connection_mgr_get_dualstream_second_device_bt_address(bdaddr *addr)
{       

    source_dual_stream_config_def_t *DualStreamConfig = NULL;

    if (configManagerGetReadOnlyConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID, (const void **)&DualStreamConfig))
    {
        addr->lap = (((uint32)DualStreamConfig->Bluetooth_Address.LAP_hi << 16) | ((uint32) (DualStreamConfig->Bluetooth_Address.LAP_lo) & 0x0000FFFFUL));
        addr->uap = DualStreamConfig->Bluetooth_Address.UAP;
        addr->nap = DualStreamConfig->Bluetooth_Address.NAP;
    }
    configManagerReleaseConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID);
}
/*************************************************************************
NAME
    connection_mgr_set_dualstream_second_device_bt_address

DESCRIPTION
    Helper function to Set the Dual Stream 2nd Device Bluetooth Address

RETURNS
    void

**************************************************************************/
void connection_mgr_set_dualstream_second_device_bt_address(const bdaddr *addr)
{
    source_dual_stream_config_def_t *DualStreamConfig = NULL;
    
    if (configManagerGetWriteableConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID, (void**)&DualStreamConfig, 0))
    {
        /* Populate the Bluetooth address to be written */
        if (addr == NULL)
        {
            /* No address passed in, so zero pad the addr part of the key */
            memset(&DualStreamConfig->Bluetooth_Address, 0, sizeof(DualStreamConfig->Bluetooth_Address));
        }
        else
        {
            DualStreamConfig->Bluetooth_Address.LAP_hi = (addr->lap>>16);
            DualStreamConfig->Bluetooth_Address.LAP_lo = (uint16) addr->lap;
            DualStreamConfig->Bluetooth_Address.NAP = addr->nap;
            DualStreamConfig->Bluetooth_Address.UAP = addr->uap;
        }
        configManagerUpdateWriteableConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID);
   }
}
/*************************************************************************
NAME
    connection_mgr_get_enable_dual_stream_feature

DESCRIPTION
    Helper function to get the Dual Stream enable feature.

RETURNS
    TRUE, if the variable 'Dual Stream' is set in the config block,
    FALSE, if other wise

**************************************************************************/
bool connection_mgr_get_enable_dual_stream_feature(void)
{
    source_dual_stream_config_def_t *DualStreamConfig = NULL;
    bool enable_dual_stream = FALSE;
    if (configManagerGetWriteableConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID, (void**)&DualStreamConfig, 0))
    {
            enable_dual_stream = DualStreamConfig->Enable_Dual_Stream;
    }
    configManagerUpdateWriteableConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID);
    return enable_dual_stream;
}
/*************************************************************************
NAME
    connection_mgr_get_connect_both_devices_enable_feature

DESCRIPTION
    Helper function to get the connect both the devices feature.

RETURNS
    TRUE, if the variable 'Connect both devices ' is set in the config block,
    FALSE, if other wise

**************************************************************************/
bool connection_mgr_get_connect_both_devices_enable_feature(void)
{
    source_dual_stream_config_def_t *DualStreamConfig = NULL;
    bool connect_both_devices = FALSE;
    if (configManagerGetWriteableConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID, (void**)&DualStreamConfig, 0))
    {
            connect_both_devices = DualStreamConfig->Connect_both_Devices;
    }
    configManagerUpdateWriteableConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID);
    return connect_both_devices;
}
#endif
/*************************************************************************
NAME
    connection_mgr_get_secure_connection_mode

DESCRIPTION
    Helper function to get the secure connection mode value.

RETURNS
    The value of 'source_secure_connection_mode', if secure connection is enabled
    source_no_secure_connection if not enabled.

**************************************************************************/
source_link_mode connection_mgr_get_secure_connection_mode(void)
{
    secure_connection_modes_config_def_t *SecureConnectionMode = NULL;
    source_link_mode secure_connection_mode = source_no_secure_connection;
    if (configManagerGetWriteableConfig(SECURE_CONNECTION_MODES_CONFIG_BLK_ID, (void**)&SecureConnectionMode, 0))
    {
            secure_connection_mode = SecureConnectionMode->secure_connection_mode;
    }
    configManagerUpdateWriteableConfig(SECURE_CONNECTION_MODES_CONFIG_BLK_ID);
    return secure_connection_mode;
}
/*************************************************************************
NAME
    connection_mgr_get_man_in_the_mid_value

DESCRIPTION
    Helper function to get the man in the mid variable value..

RETURNS
    TRUE, if the variable 'man_in_the_middle' is set in the config block,
    FALSE, if other wise

**************************************************************************/
bool connection_mgr_get_man_in_the_mid_value(void)
{
    secure_connection_modes_config_def_t *SecureConnectionMode = NULL;
    bool man_in_the_middle = FALSE;
    if (configManagerGetWriteableConfig(SECURE_CONNECTION_MODES_CONFIG_BLK_ID, (void**)&SecureConnectionMode, 0))
    {
            man_in_the_middle = SecureConnectionMode->man_in_the_middle;
    }
    configManagerUpdateWriteableConfig(SECURE_CONNECTION_MODES_CONFIG_BLK_ID);
    return man_in_the_middle;
}
/*************************************************************************
NAME
    connection_mgr_get_number_of_paired_devices

DESCRIPTION
    Helper function to get the number of paired devices possible.

RETURNS
    The number of paired devices as configured in the module xml files.  

**************************************************************************/
uint8 connection_mgr_get_number_of_paired_devices(void)
{
    number_of_paired_devices_config_def_t *Number_Of_Paired_Devices = NULL;
    uint8 NumberOfPairedDevices = 0;
    if (configManagerGetWriteableConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID, (void**)&Number_Of_Paired_Devices, 0))
    {
            NumberOfPairedDevices = Number_Of_Paired_Devices->number_of_paired_devices;
    }
    configManagerUpdateWriteableConfig(SOURCE_DUAL_STREAM_CONFIG_BLK_ID);
    return NumberOfPairedDevices;
}
/*************************************************************************
NAME
    connection_mgr_get_connection_pin_values

DESCRIPTION
    Helper function to get the pin code values.

RETURNS
    void

**************************************************************************/
void connection_mgr_get_connection_pin_values(PIN_CONFIG_T *connection_pin_code)
{
    source_pairing_writable_config_def_t *connection_pin_code_tmp = NULL;

    if (configManagerGetWriteableConfig(SOURCE_PAIRING_WRITABLE_CONFIG_BLK_ID, (void**)&connection_pin_code_tmp, 0))
    {
        connection_pin_code->number_pin_codes  = connection_pin_code_tmp->NumOfPinCodes ;
        memcpy(&connection_pin_code->pin_codes[0].code,&connection_pin_code_tmp->PIN_Code1,sizeof(connection_pin_code_tmp->PIN_Code1));
        memcpy(&connection_pin_code->pin_codes[1].code,&connection_pin_code_tmp->PIN_Code2,sizeof(connection_pin_code_tmp->PIN_Code2));
        memcpy(&connection_pin_code->pin_codes[2].code,&connection_pin_code_tmp->PIN_Code3,sizeof(connection_pin_code_tmp->PIN_Code3));
        memcpy(&connection_pin_code->pin_codes[3].code,&connection_pin_code_tmp->PIN_Code4,sizeof(connection_pin_code_tmp->PIN_Code4));
    }
    configManagerUpdateWriteableConfig(SOURCE_PAIRING_WRITABLE_CONFIG_BLK_ID);
}
/*************************************************************************
NAME
    connection_mgr_get_power_on_connect_idle_timer

DESCRIPTION
    Helper function to Get the Power On Connect Idle timer.

RETURNS
    The power ON  connect idle timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_power_on_connect_idle_timer(void)
{
    uint16 PowerOn_ConnectIdle_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        PowerOn_ConnectIdle_timer = timer_data->private_data_timers.PowerOnConnectIdle_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return PowerOn_ConnectIdle_timer;
}
/*************************************************************************
NAME
    connection_mgr_get_power_on_discover_idle_timer

DESCRIPTION
    Helper function to Get the Power On DisCover Idle timer.

RETURNS
    The authenticated payload timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_power_on_discover_idle_timer(void)
{
    uint16 PowerOn_DisConnectIdle_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        PowerOn_DisConnectIdle_timer = timer_data->private_data_timers.PowerOnDiscoverIdle_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return PowerOn_DisConnectIdle_timer;
}
/*************************************************************************
NAME
    connection_mgr_get_authenticated_payload_timer

DESCRIPTION
    Helper function to Get the Authenticated Payload Timer value..

RETURNS
    The authenticated payload timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_authenticated_payload_timer(void)
{
    uint16 authenticated_payload_timeout_s = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        authenticated_payload_timeout_s = timer_data->private_data_timers.AuthenticatedPayloadTO_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return authenticated_payload_timeout_s;
}
/*************************************************************************
NAME
    source_timers_set_inquiry_state_timer

DESCRIPTION
    Helper function to set the inquiry state timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_inquiry_state_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;
    
    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.InquiryState_s = timeout ;
         ret =  TRUE;
    }
    else
        ret  = FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return ret;
}
/*************************************************************************
NAME
    source_timers_set_inquiry_idle_timer

DESCRIPTION
    Helper function to set the inquiry Idle timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_inquiry_idle_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;
    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.InquiryIdle_s = timeout ;
        ret =  TRUE;
    }
    else
        ret  = FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return ret;
}
/*************************************************************************
NAME
    connection_mgr_set_connection_idle_timer

DESCRIPTION
    Helper function to set the Connection Idle timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_connection_idle_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;

    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.ConnectionIdle_s = timeout ;
        ret =  TRUE;
    }
    else
        ret =  FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return ret;
}
/*************************************************************************
NAME
    source_timers_set_disconnection_Idle_timer

DESCRIPTION
    Helper function to set the DisConnection Idle timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_disconnection_Idle_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;

    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.DisconnectIdle_s = timeout ;
        ret =  TRUE;
    }
    else
        ret = FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return FALSE;
}
/*************************************************************************
NAME
    connection_mgr_set_profile_connection_delay_timer

DESCRIPTION
    Helper function to set the AVRCP Profile Connection Delay timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_profile_connection_delay_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;
    
    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.ProfileConnectionDelay_s = timeout ;
        ret =  TRUE;
    }
    else
        ret = FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return ret;
}
/*************************************************************************
NAME
    source_timers_set_linkloss_reconnect_delay_timer

DESCRIPTION
    Helper function to set the LinkLoss ReConnection Delay timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_linkloss_reconnect_delay_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;
    
    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.LinkLossReconnectDelay_s = timeout ;
        ret =  TRUE;
    }
    else
        ret = FALSE;

   configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return ret ;
}
/*************************************************************************
NAME
    connection_mgr_set_audio_delay_timer

DESCRIPTION
    Helper function to set the Audio Delay timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_audio_delay_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;

    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.AudioDelay_ms = timeout ;
        ret =  TRUE;
    }
    else
        ret = FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return ret;
}
/*************************************************************************
NAME
    connection_mgr_set_power_on_connect_idle_timer

DESCRIPTION
    Helper function to set the Power On Connect Idle  timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_power_on_connect_idle_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;

    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.PowerOnConnectIdle_s = timeout ;
        ret =  TRUE;
    }
    else
        ret = FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return FALSE;
}
/*************************************************************************
NAME
    connection_mgr_set_powerOn_discover_Idle_timer

DESCRIPTION
    Helper function to set the Power On Discover Idle  timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_power_on_discover_Idle_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;
    
    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.PowerOnDiscoverIdle_s = timeout ;
        ret =  TRUE;
    }
    else
        ret = FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return FALSE;
}
/*************************************************************************
NAME
    connection_mgr_set_authenticated_payload_timer

DESCRIPTION
    Helper function to set the Authenticated Payload Time value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_authenticated_payload_timer(uint16 timeout)
{
    sourcedata_readonly_config_def_t *read_configdata = NULL;
    bool ret = FALSE;

    if (configManagerGetWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->private_data_timers.AuthenticatedPayloadTO_s = timeout ;
        ret =  TRUE;
    }
    else
        ret = FALSE;

    configManagerUpdateWriteableConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return FALSE;
}
/****************************************************************************
NAME    
    connection_mgr_get_instance -

DESCRIPTION
     Gets the instance of the Connection Task.

RETURNS
    Connection Task Instance.
*/
Task connection_mgr_get_instance(void)
{
    return &theSource->connectionTask;
}

