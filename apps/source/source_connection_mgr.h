/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_connection_mgr.h

DESCRIPTION
    Connection manager for handling connection to remote devices.

*/


#ifndef _SOURCE_CONNECTION_MGR_H_
#define _SOURCE_CONNECTION_MGR_H_

/* VM headers */
#include <bdaddr.h>
#include <stdlib.h>
/* application header files */
#include "source_inquiry.h"
#include "source_app_msg_handler.h"
#include "source_private_data_config_def.h"

/* The maximum PIN codes stored. These are used when trying to connect to a Bluetooth v2.0 or earlier device */
#define CONNECTION_MAX_PIN_CODES 4

/* number of different devices for which PIN codes are stored */
#define CONNECTION_MAX_DEVICE_PIN_CODES 4

/* the link supervision timeout to use for a connection
    the timeout is in 0.625ms units so here 8064 (0x1f80) * 0.625ms = 5 secs approx */
#define CONNECTION_LINK_SUPERVISION_TIMEOUT 0x1f80


typedef enum
{
    CONNECTION_DEVICE_PRIMARY = 0,
    CONNECTION_DEVICE_SECONDARY
} CONNECTION_DEVICE_T;

/* PSKey configurable connection policy */
typedef enum
{
    CONNECT_LAST_DEVICE,
    CONNECT_PAIRED_LIST
} CONNECT_POLICY_T;

/* PSKey configurable PIN Codes */
typedef struct
{
    uint8 code[4];     
} PIN_CODE_T;

typedef struct
{
    uint16 number_pin_codes;
    PIN_CODE_T pin_codes[CONNECTION_MAX_PIN_CODES];
} PIN_CONFIG_T;

typedef struct
{
    uint16 number_device_pins;
    bdaddr addr[CONNECTION_MAX_DEVICE_PIN_CODES];
    uint16 index[CONNECTION_MAX_DEVICE_PIN_CODES];
} CONNECTION_DEVICE_PIN_CODES_T;

typedef struct
{
    PIN_CONFIG_T pin;
    CONNECTION_DEVICE_PIN_CODES_T device;
} CONNECTION_PIN_CODE_STORE_T;


/***************************************************************************
Function definitions
****************************************************************************
*/


/****************************************************************************
NAME    
    connection_mgr_can_pair

DESCRIPTION
    Determines if a pairing attempt should be accepted or rejected.
    
RETURNS
    TRUE - Allow pairing attempt
    FALSE - Reject pairing attempt

*/
bool connection_mgr_can_pair(const bdaddr *bd_addr);


/****************************************************************************
NAME    
    connection_mgr_can_connect

DESCRIPTION
    Determines if a incoming connection should be accepted or rejected.
    
RETURNS
    TRUE - Allow incoming connection
    FALSE - Reject incoming connection

*/
bool connection_mgr_can_connect(const bdaddr *bd_addr, PROFILES_T profile_connecting);


/****************************************************************************
NAME    
    connection_mgr_start_connection_attempt

DESCRIPTION
    Begins connecting to a remote device by sending the APP_CONNECT_REQ message. 
    The parameters passed in will determine the connection attempt:
        addr - A Bluetooth address can be supplied to connect to this device. 
                If this is NULL then the address will be filled in by the function based on the reconnection policy.
        profile - Can specify which profile to attempt first.
        delay - Can specify a delay before the APP_CONNECT_REQ message is sent.
    
*/
void connection_mgr_start_connection_attempt(const bdaddr *addr, PROFILES_T profile, uint16 delay);


/****************************************************************************
NAME    
    connection_mgr_connect_next_profile

DESCRIPTION
    Continues the connection attempt using the next profile that is enabled.
    
RETURNS
    TRUE - Connection attempt to the remote device was initiated using the next profile available
    FALSE - Connection was not attempted (for example, if there were no more profiles to try)

*/
bool connection_mgr_connect_next_profile(void);


/****************************************************************************
NAME    
    connection_mgr_connect_next_paired_device

DESCRIPTION
    Continues the connection attempt to the next device in the paired device list.
    
RETURNS
    TRUE - Connection attempt to the next remote device from the paired device list was initiated
    FALSE - Connection was not attempted (for example, if there were no more paired devices to try)

*/
bool connection_mgr_connect_next_paired_device(void);


/****************************************************************************
NAME    
    connection_mgr_set_incoming_connection

DESCRIPTION
    Stores the remote device as the device to connect with, as it has sent a connection request.

*/
void connection_mgr_set_incoming_connection(PROFILES_T profile, const bdaddr *addr);


/****************************************************************************
NAME    
    connection_mgr_clear_attempted_profiles

DESCRIPTION
    Resets which profiles have been attempted.

*/
void connection_mgr_clear_attempted_profiles(void);


/****************************************************************************
NAME    
    connection_mgr_get_current_profile

DESCRIPTION
    Returns which profile is currently being used in a connection attempt.

RETURNS
    The profile currently being used in a connection attempt.  

*/
PROFILES_T connection_mgr_get_current_profile(void);


/****************************************************************************
NAME    
    connection_mgr_any_connected_profiles

DESCRIPTION
    Returns if any profiles are currently connected.
    
RETURNS
    TRUE - There are profiles connected.
    FALSE - There are no profiles connected.

*/
bool connection_mgr_any_connected_profiles(void);


/****************************************************************************
NAME    
    connection_mgr_connect_further_device

DESCRIPTION
    Attempts to connect to a further remote device. 
    manual_connect - TRUE if the connection is user initiated, FALSE otherwise
    
RETURNS
    TRUE - Connection attempt to the next remote device was initiated
    FALSE - Connection to a remote device was not attempted

*/
bool connection_mgr_connect_further_device(bool manual_connect);


/****************************************************************************
NAME    
    connection_mgr_set_profile_connected

DESCRIPTION
    Registers a profile connection with the connection manager.

*/
void connection_mgr_set_profile_connected(PROFILES_T profile, const bdaddr *addr);


/****************************************************************************
NAME    
    connection_mgr_set_profile_disconnected

DESCRIPTION
    Registers a profile disconnection with the connection manager.

*/
void connection_mgr_set_profile_disconnected(PROFILES_T profile, const bdaddr *addr);


/****************************************************************************
NAME    
    connection_mgr_reset_pin_codes

DESCRIPTION
    Resets the stored PIN codes to their default states.

*/
void connection_mgr_reset_pin_codes(void);


/****************************************************************************
NAME    
    connection_mgr_find_pin_index_by_addr

DESCRIPTION
    Find PIN index by the Bluetooth address supplied
    
*/
uint16 connection_mgr_find_pin_index_by_addr(const bdaddr *addr);


/****************************************************************************
NAME    
    connection_mgr_get_next_pin_code

DESCRIPTION
    Return if next PIN code was found for the device with the Bluetooth address supplied 
    
*/
bool connection_mgr_get_next_pin_code(const bdaddr *addr);


/****************************************************************************
NAME    
    connection_mgr_set_link_supervision_timeout

DESCRIPTION
    Sets the link supervision timeout for the link associated with the supplied Sink
    
*/
void connection_mgr_set_link_supervision_timeout(Sink sink);
/****************************************************************************
NAME    
    connection_mgr_read_pin_code_config_values 

DESCRIPTION
    reads the pin code configuration from the xml file.

RETURNS
    void
**************************************************************************/
void connection_mgr_read_pin_code_config_values(void);
/****************************************************************************
NAME    
    connection_mgr_get_remote_address - To get the remote address .
*/
bdaddr *connection_mgr_get_remote_address(void);
/****************************************************************************
NAME    
    connection_mgr_get_a2dp_media_before_signalling - To get the a2dp_media_before_signalling val .
*/
bool connection_mgr_get_a2dp_media_before_signalling(void);
/****************************************************************************
NAME    
    connection_mgr_set_a2dp_media_before_signalling - To get the a2dp_media_before_signalling val .
*/
void connection_mgr_set_a2dp_media_before_signalling(bool a2dp_media_before_signalling);
/****************************************************************************
NAME    
    connection_mgr_set_Profile - To set the profile connected value .
*/
void connection_mgr_set_Profile(bool profile_connected);
/****************************************************************************
NAME    
    connection_mgr_get_profile_connected - To gethe profile connected value .
*/
uint16  connection_mgr_get_profile_connected(void);
/****************************************************************************
NAME    
    connection_mgr_get_manual_2nd_connection - To gethe Manual 2nd Connection .
*/
bool connection_mgr_get_manual_2nd_connection(void);
/****************************************************************************
NAME    
    connection_mgr_set_manual_2nd_connection - To set the Manual 2nd Connection .
*/
void connection_mgr_set_manual_2nd_connection(bool manual_2nd_connection);
/****************************************************************************
NAME    
    connection_mgr_get_connection_retries - To get the number of connection retries.
*/
uint16  connection_mgr_get_connection_retries(void);
/****************************************************************************
NAME    
    connection_mgr_reset_connection_retries - To get the number of connection retries.
*/
void  connection_mgr_reset_connection_retries(void);
/****************************************************************************
NAME    
    connection_mgr_increment_connection_retries - Increments the connection retries
*/
void  connection_mgr_increment_connection_retries(void);
/****************************************************************************
NAME    
    connection_mgr_reset_remote_manufacturer - To reset the Remote manufacturer
*/
void  connection_mgr_reset_remote_manufacturer(void);
/****************************************************************************
NAME    
    connection_mgr_set_remote_manufacturer - To reset the Remote manufacturer
*/
void  connection_mgr_set_remote_manufacturer(uint16 remote_manufacturer);
/****************************************************************************
NAME    
    connection_mgr_get_number_of_device_pins - To get the number of device pins
*/
uint16  connection_mgr_get_number_of_device_pins(void);
/****************************************************************************
NAME    
    connection_mgr_set_pin_address - To Set the pin address based on index.
*/
void  connection_mgr_set_pin_address(uint16 index, bdaddr  addr);
/****************************************************************************
NAME    
    connection_mgr_set_index_value - To Set the pin address based on index.
*/
void  connection_mgr_set_index_value(uint16 index, uint16  value);
/****************************************************************************
NAME    
    connection_mgr_increment_number_of_devicePins - To Increment the number of device pins
*/
void  connection_mgr_increment_number_of_devicePins(void);
/****************************************************************************
NAME    
    connection_mgr_get_index_value - To Get the index value.
*/
uint16  connection_mgr_get_index_value(uint16 index);
/****************************************************************************
NAME    
    connection_mgr_get_pin_length - To Get the index value.
*/
uint16  connection_mgr_get_pin_length(uint16 code_index);
/****************************************************************************
NAME    
    connection_mgr_get_pin_value - To Get the code value
*/
uint16  connection_mgr_get_pin_value(uint16 code_index,uint16 count);
/****************************************************************************
NAME    
    connection_mgr_set_supported_profiles - To Get the code value
*/
void connection_mgr_set_supported_profiles(PROFILES_T profiles);
/****************************************************************************
NAME    
    connection_mgr_create_memory_for_connection_pin - Creates memory for Connection PIN
*/
void  connection_mgr_create_memory_for_connection_pin(void);
/****************************************************************************
NAME    
    connection_mgr_ps_read_user_for_pincodes - Creates memory for Connection PIN
*/
void  connection_mgr_ps_read_user_for_pincodes(void);
/****************************************************************************
NAME    
    connection_mgr_set_connected_device_ps_slot - Sets the connected device ps slots
*/
void  connection_mgr_set_connected_device_ps_slot(uint8 connected_device_ps_slot);
/****************************************************************************
NAME    
    connection_mgr_reset_connected_device_ps_slot - Resets the connected device ps slots
*/
void  connection_mgr_reset_connected_device_ps_slot(void);
/****************************************************************************
NAME    
    connection_mgr_get_connected_device_ps_slot - Sets the connected device ps slots
*/
uint8  connection_mgr_get_connected_device_ps_slot(void);
/****************************************************************************
NAME    
    connection_mgr_is_a2dp_profile_enabled -Checks if A2DP profile is enabled or not 
*/
uint8 connection_mgr_is_a2dp_profile_enabled (void);

/****************************************************************************
NAME    
    connection_mgr_is_aghfp_profile_enabled -Checks if AGHFP profile is enabled or not 
*/
uint8 connection_mgr_is_aghfp_profile_enabled (void);

/****************************************************************************
NAME    
    connection_mgr_is_avrcp_profile_enabled -Checks if AVRCP profile is enabled or not 
*/
uint8 connection_mgr_is_avrcp_profile_enabled (void);
/*************************************************************************
NAME
    connection_mgr_get_combined_max_connection_retries

DESCRIPTION
    Helper function to Get the Combined max connection retries.

RETURNS
    uint16

**************************************************************************/
uint16 connection_mgr_get_combined_max_connection_retries(void);
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
uint16 connection_mgr_get_connect_policy(void);
/*************************************************************************
NAME
    connection_mgr_get_remote_device_address

DESCRIPTION
    Helper function to Get the Remote device address

RETURNS
    uint8

**************************************************************************/
void connection_mgr_get_remote_device_address(bdaddr *addr);
/*************************************************************************
NAME
    connection_mgr_set_remote_device_address

DESCRIPTION
    Helper function to Set the Remote device address

RETURNS
    uint8

**************************************************************************/
void connection_mgr_set_remote_device_address(const bdaddr *addr);
/*************************************************************************
NAME
    connection_mgr_get_secure_connection_mode

DESCRIPTION
    Helper function to get the secure connection mode value.

RETURNS
    The value is source_secure_connection_mode, if secure connection is enabled.
    source_no_secure_connection if not enabled.

**************************************************************************/
source_link_mode connection_mgr_get_secure_connection_mode(void);
/*************************************************************************
NAME
    connection_mgr_get_man_in_the_mid_value

DESCRIPTION
    Helper function to get the man in the mid variable value..

RETURNS
    TRUE, if the variable 'man_in_the_middle' is set in the config block,
    FALSE, if other wise

**************************************************************************/
bool connection_mgr_get_man_in_the_mid_value(void);
/*************************************************************************
NAME
    connection_mgr_get_number_of_paired_devices

DESCRIPTION
    Helper function to get the number of paired devices possible.

RETURNS
    The number of paired devices as configured in the module xml files.  

**************************************************************************/
uint8 connection_mgr_get_number_of_paired_devices(void);
/*************************************************************************
NAME
    connection_mgr_get_connection_pin_values

DESCRIPTION
    Helper function to get the pin code values.

RETURNS
    void

**************************************************************************/
void connection_mgr_get_connection_pin_values(PIN_CONFIG_T *connection_pin_code);
/*************************************************************************
NAME
    connection_mgr_get_dualstream_second_device_bt_address

DESCRIPTION
    Helper function to Get the Dual Stream 2nd Device Bluetooth Address

RETURNS
    bdaddr*

**************************************************************************/
#ifdef INCLUDE_DUALSTREAM
void connection_mgr_get_dualstream_second_device_bt_address(bdaddr *addr);
#else
#define connection_mgr_get_dualstream_second_device_bt_address(addr) ((void)(0))
#endif
/*************************************************************************
NAME
    connection_mgr_set_dualstream_second_device_bt_address

DESCRIPTION
    Helper function to Set the Dual Stream 2nd Device Bluetooth Address

RETURNS
    void

**************************************************************************/
#ifdef INCLUDE_DUALSTREAM
void connection_mgr_set_dualstream_second_device_bt_address(const bdaddr *addr);
#else
#define connection_mgr_set_dualstream_second_device_bt_address(addr) ((void)(0))
#endif
/*************************************************************************
NAME
    connection_mgr_get_enable_dual_stream_feature

DESCRIPTION
    Helper function to get the Dual Stream enable feature.

RETURNS
    TRUE, if the variable 'Dual Stream' is set in the config block,
    FALSE, if other wise

**************************************************************************/
#ifdef INCLUDE_DUALSTREAM
bool connection_mgr_get_enable_dual_stream_feature(void);
#else
#define connection_mgr_get_enable_dual_stream_feature() (FALSE)
#endif
/*************************************************************************
NAME
    source_get_connect_both_device_enable_feature

DESCRIPTION
    Helper function to get the connect both the devices feature.

RETURNS
    TRUE, if the variable 'Connect both devices ' is set in the config block,
    FALSE, if other wise

**************************************************************************/
#ifdef INCLUDE_DUALSTREAM
bool connection_mgr_get_connect_both_devices_enable_feature(void);
#else
#define connection_mgr_get_connect_both_devices_enable_feature() (FALSE)
#endif
/****************************************************************************
NAME    
    connection_mgr_write_device_link_mode
    
DESCRIPTION
    Called when receiving the CL_SM_AUTHORISE_CFM message after authorisation has completed
    Write the default device attributes with negotiated link mode to config store.

RETURNS
    void
**************************************************************************/
void connection_mgr_write_device_link_mode(const CL_SM_AUTHENTICATE_CFM_T *cfm);
/****************************************************************************
NAME    
    connection_mgr_write_new_remote_device - 

DESCRIPTION
    Write the device to config block ID
    
RETURNS
    void
**************************************************************************/
void connection_mgr_write_new_remote_device(const bdaddr *addr, PROFILES_T profile);
/****************************************************************************
NAME    
    connection_mgr_write_device_name - 
    
DESCRIPTION
    Write the device name to Config store     

RETURNS
    void
**************************************************************************/
void connection_mgr_write_device_name(const bdaddr *addr, uint16 size_name, const uint8 *name);
/****************************************************************************
NAME    
    ps_write_device_attributes - 
    
DESCRIPTION
    Write the device attributes to config store.
*/
void connection_mgr_write_device_attributes(const bdaddr *addr, ATTRIBUTES_T attributes);
/*************************************************************************
NAME
    connection_mgr_get_audio_delay_timer

DESCRIPTION
    Helper function to Get the audio delay timer.

RETURNS
    The  audio delay timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_audio_delay_timer(void);
/*************************************************************************
NAME
    connection_mgr_get_idle_timer

DESCRIPTION
    Helper function to Get the Connection Idle timer.

RETURNS
    The  idle timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_idle_timer(void);
/*************************************************************************
NAME
    connection_mgr_get_discoverable_timer

DESCRIPTION
    Helper function to Get the Discovery state timer.

RETURNS
    The Discovery state timer read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_discoverable_timer(void);
/*************************************************************************
NAME
    connection_mgr_get_disconnect_idle_timer

DESCRIPTION
    Helper function to Get the DisconnectIdle timer.

RETURNS
    The disconnect idle timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_disconnect_idle_timer(void);
/*************************************************************************
NAME
    connection_mgr_get_profile_connection_delay_timer

DESCRIPTION
    Helper function to Get the Profile Connection delay timer.

RETURNS
    The profile connection delay  timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_profile_connection_delay_timer(void);
/*************************************************************************
NAME
    connection_mgr_get_linkloss_reconnect_delay_timer

DESCRIPTION
    Helper function to Get the Link Loss Reconnect delay timer.

RETURNS
    The link loss reconnect delay  timer value read from the corresponding config block section .

**************************************************************************/
uint16 connection_mgr_get_linkloss_reconnect_delay_timer(void);
/*************************************************************************
NAME
    connection_mgr_get_power_on_connect_idle_timer

DESCRIPTION
    Helper function to Get the Power On Connect Idle timer.

RETURNS
    uint16

**************************************************************************/
uint16 connection_mgr_get_power_on_connect_idle_timer(void);
/*************************************************************************
NAME
    connection_mgr_get_powerOn_discover_idle_timer

DESCRIPTION
    Helper function to Get the Power On DisCover Idle timer.

RETURNS
    uint16

**************************************************************************/
uint16 connection_mgr_get_power_on_discover_idle_timer(void);
/*************************************************************************
NAME
    connection_mgr_get_authenticated_payload_timer

DESCRIPTION
    Helper function to Get the Authenticated Payload Timer value..

RETURNS
    uint16

**************************************************************************/
uint16 connection_mgr_get_authenticated_payload_timer(void);
/*************************************************************************
NAME
    connection_mgr_set_inquiry_state_timer

DESCRIPTION
    Helper function to set the inquiry state timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_inquiry_state_timer(uint16 timeout);
/*************************************************************************
NAME
    connection_mgr_set_connection_idle_timer

DESCRIPTION
    Helper function to set the inquiry Idle timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_connection_idle_timer(uint16 timeout);
/*************************************************************************
NAME
    connection_mgr_set_profile_connection_delay_timer

DESCRIPTION
    Helper function to set the AVRCP Profile Connection Delay timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_profile_connection_delay_timer(uint16 timeout);
/*************************************************************************
NAME
    connection_mgr_set_disconnection_Idle_timer

DESCRIPTION
    Helper function to set the DisConnection Idle timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_disconnection_Idle_timer(uint16 timeout);
/*************************************************************************
NAME
    connection_mgr_set_audio_delay_timer

DESCRIPTION
    Helper function to set the Audio Delay timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_audio_delay_timer(uint16 timeout);
/*************************************************************************
NAME
    connection_mgr_set_powe_on_connect_idle_timer

DESCRIPTION
    Helper function to set the Power On Connect Idle  timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_power_on_connect_idle_timer(uint16 timeout);
/*************************************************************************
NAME
    connection_mgr_set_power_on_discover_Idle_timer

DESCRIPTION
    Helper function to set the Power On Discover Idle  timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_power_on_discover_Idle_timer(uint16 timeout);
/*************************************************************************
NAME
    connection_mgr_set_authenticated_payload_timer

DESCRIPTION
    Helper function to set the Authenticated Payload Time value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_authenticated_payload_timer(uint16 timeout);
/*************************************************************************
NAME
    source_timers_set_inquiry_idle_timer

DESCRIPTION
    Helper function to set the inquiry Idle timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_inquiry_idle_timer(uint16 timeout);
/*************************************************************************
NAME
    source_timers_set_linkloss_reconnect_delay_timer

DESCRIPTION
    Helper function to set the LinkLoss ReConnection Delay timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool connection_mgr_set_linkloss_reconnect_delay_timer(uint16 timeout);
/****************************************************************************
NAME    
    connection_mgr_get_instance -

DESCRIPTION
     Gets the instance of the Connection Task instance.

RETURNS
    Connection Task Instance.
*/
Task connection_mgr_get_instance(void);
#endif /* _SOURCE_CONNECTION_MGR_H_ */
