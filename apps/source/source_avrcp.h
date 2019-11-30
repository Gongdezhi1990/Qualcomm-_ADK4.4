/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_avrcp.h

DESCRIPTION
    AVRCP profile functionality.
    
*/


#ifndef _SOURCE_AVRCP_H_
#define _SOURCE_AVRCP_H_


/* application header files */
#include "source_avrcp_msg_handler.h"
/* profile/library headers */
#include <avrcp.h>
#include <connection.h>
/* VM headers */
#include <message.h>


/* AVRCP fixed values */
#ifdef INCLUDE_DUALSTREAM
#define AVRCP_MAX_INSTANCES         2
#else
#define AVRCP_MAX_INSTANCES         1
#endif /* INCLUDE_DUALSTREAM */

#define AVRCP_ENABLED_INSTANCES()    (connection_mgr_get_enable_dual_stream_feature() ? 2 : 1)

/* Max SDP records to receive */
#define AVRCP_MAX_SDP_RECS                      50

/* AVRCP Vendor Dependent Defines */
#define AVRCP_CTYPE_NOTIFICATION                0x3
#define AVRCP_VENDOR_NOTIFICATION_DATA_LENGTH   3
#define AVRCP_VENDOR_PRODUCT_ID_UPPER_BYTE      0xff
#define AVRCP_VENDOR_PRODUCT_ID_LOWER_BYTE      0x00
#define AVRCP_REGISTER_NOTIFICATION_PDU_ID      0x31 /* the AVRCP 1.4 defined commands for volume sync */
#define AVRCP_SET_ABSOLUTE_VOLUME_PDU_ID        0x50 /* the AVRCP 1.4 defined commands for volume sync */
#define AVRCP_EVENT_VOLUME_CHANGED              0x0D /* the AVRCP 1.4 defined commands for volume sync */
#define AVRCP_BLUETOOTH_SIG_COMPANY_ID          ((uint32)6488) /* the AVRCP 1.4 defined BT SIG company ID */
#define AVRCP_ABS_VOL_STEP_CHANGE               8 /* absolute volume steps */

/* loop through all AVRCP connection instances */
#define for_all_avrcp_instance(index) for (index = 0; index < AVRCP_ENABLED_INSTANCES(); index++)

/* AVRCP State Machine */
typedef enum
{  
    AVRCP_STATE_DISCONNECTED,       /* No AVRCP connection */
    AVRCP_STATE_CONNECTING_LOCAL,   /* Locally initiated connection in progress */
    AVRCP_STATE_CONNECTING_REMOTE,  /* Remotely initiated connection is progress */
    AVRCP_STATE_CONNECTED,          /* Control channel connected */
    AVRCP_STATE_DISCONNECTING       /* Disconnecting control channel */
} AVRCP_STATE_T;

#define AVRCP_STATES_MAX  (AVRCP_STATE_DISCONNECTING + 1)


/* Check of AVRCP connection state */
#define avrcp_is_connected(state) ((state >= AVRCP_STATE_CONNECTED) && (state < AVRCP_STATES_MAX))


/* AVRCP supported values */
typedef enum
{
    AVRCP_SUPPORT_UNKNOWN,
    AVRCP_SUPPORT_YES,
    AVRCP_SUPPORT_NO
} AVRCP_SUPPORT_T;

/* AVRCP profiles supported */
typedef enum
{
    AVRCP_PROFILE_DISABLED,
    AVRCP_PROFILE_1_0
} AVRCP_PROFILE_T;

/* structure holding the AVRCP data */
typedef struct
{
    TaskData avrcpTask;
    AVRCP_STATE_T avrcp_state;
    AVRCP *avrcp;
    bdaddr addr;
    uint8 *vendor_data;
    uint16 pending_vendor_command;
    AVRCP_SUPPORT_T remote_vendor_support;
    AVRCP_SUPPORT_T avrcp_support;
    uint16 avrcp_connection_retries;
} avrcpInstance;


/***************************************************************************
Function definitions
****************************************************************************
*/

/****************************************************************************
NAME    
    avrcp_init

DESCRIPTION
    Initialises the AVRCP profile libary and prepares the application so it can handle AVRCP connections.
    The application will allocate a memory block to hold connection related information.
    Each AVRCP connection with a remote device will be stored within the memory block as an AVRCP instance. 

RETURNS
    void
*/
void avrcp_init(void);


/****************************************************************************
NAME    
    avrcp_set_state

DESCRIPTION
    Sets the new state of an AVRCP connection.

RETURNS
    void
*/
void avrcp_set_state(avrcpInstance *inst, AVRCP_STATE_T new_state);


/****************************************************************************
NAME    
    avrcp_get_state

DESCRIPTION
    Gets the current state of an AVRCP connection.

RETURNS
    The current value of the AVRCP state machine.
*/
AVRCP_STATE_T avrcp_get_state(avrcpInstance *inst);


/****************************************************************************
NAME    
    avrcp_get_instance_from_pointer

DESCRIPTION
    Finds and returns the AVRCP instance with AVRCP pointer set to the avrcp address passed to the function.
    
RETURNS
    If an AVRCP instance has the AVRCP pointer set as avrcp then that avrcpInstance will be returned.
    Otherwise NULL.

*/
avrcpInstance *avrcp_get_instance_from_pointer(AVRCP *avrcp);


/****************************************************************************
NAME    
    avrcp_get_instance_from_bdaddr

DESCRIPTION
    Finds and returns the AVRCP instance with address set to the addr passed to the function.
    
RETURNS
    If an AVRCP instance has address set as addr then that avrcpInstance will be returned.
    Otherwise NULL.

*/
avrcpInstance *avrcp_get_instance_from_bdaddr(const bdaddr addr);


/****************************************************************************
NAME    
    avrcp_get_free_instance

DESCRIPTION
    Finds and returns the a free AVRCP instance which has no current ongoing connection.
    
RETURNS
    If an AVRCP instance has no ongoing connection then that avrcpInstance will be returned.
    Otherwise NULL.

*/
avrcpInstance *avrcp_get_free_instance(void);


/****************************************************************************
NAME    
    avrcp_start_connection

DESCRIPTION
    Initiates an AVRCP connection to the remote device with address stored in theSource->connection_data.remote_connection_addr. 

RETURNS
    void
*/
void avrcp_start_connection(const bdaddr addr);


/****************************************************************************
NAME    
    avrcp_init_instance

DESCRIPTION
    Sets an AVRCP instance to a default state of having no ongoing connection.

RETURNS
    void
*/
void avrcp_init_instance(avrcpInstance *inst);


/****************************************************************************
NAME    
    avrcp_disconnect_all

DESCRIPTION
    Disconnects all active AVRCP connections.

RETURNS
    void
*/
void avrcp_disconnect_all(void);


/****************************************************************************
NAME    
    avrcp_send_internal_vendor_command

DESCRIPTION
    Creates the internal application message AVRCP_INTERNAL_VENDOR_COMMAND_REQ which will send an AVRCP VENDORDEPENDENT message to the remote device.
    The command will contain the data that is passed into this function.

RETURNS
    void
*/
void avrcp_send_internal_vendor_command(avrcpInstance *inst, avc_subunit_type subunit_type, avc_subunit_id subunit_id, uint8 ctype, uint32 company_id, uint16 cmd_id, uint16 size_data, Source data);


/****************************************************************************
NAME    
    avrcp_send_vendor_command

DESCRIPTION
    Called when the AVRCP_INTERNAL_VENDOR_COMMAND_REQ message is received.
    Sends an AVRCP VENDORDEPENDENT message by calling the AVRCP library API function.

RETURNS
    void
*/
void avrcp_send_vendor_command(Task task, const AVRCP_INTERNAL_VENDOR_COMMAND_REQ_T *req);


/****************************************************************************
NAME    
    avrcp_free_vendor_data

DESCRIPTION
    Frees the memory that was allocated when sending an AVRCP VENDORDEPENDENT message.

RETURNS
    void
*/
void avrcp_free_vendor_data(avrcpInstance *inst);




/****************************************************************************
NAME    
    avrcp_sdp_search_cfm

DESCRIPTION
    Called when an AVRCP Service Search has completed. This will determine if AVRCP is supported by the remote device.

RETURNS
    void
*/
void avrcp_sdp_search_cfm(avrcpInstance *inst, const CL_SDP_SERVICE_SEARCH_CFM_T *message);

/****************************************************************************
NAME    
    avrcp_handle_vendor_ind

DESCRIPTION
    Handle AVRCP Vendor command sent from remote device.

RETURNS
    void
*/
void avrcp_handle_vendor_ind(uint8 mic_mute_eq);


/****************************************************************************
NAME    
    avrcp_send_source_volume

DESCRIPTION
    Send locally stored volumes over AVRCP.

RETURNS
    void
*/
void avrcp_send_source_volume(avrcpInstance *inst);


/****************************************************************************
NAME    
    avrcp_register_volume_changes

DESCRIPTION
    Register to receive volume changes from the remote end.

RETURNS
    void
*/
void avrcp_register_volume_changes(avrcpInstance *inst);


/****************************************************************************
NAME    
    avrcp_source_vendor_command

DESCRIPTION
    Build AVRCP Vendor command to send to remote device.

RETURNS
    void
*/
void avrcp_source_vendor_command(avrcpInstance *inst, uint32 company_id, uint16 cmd_id, uint16 size_data, const uint8 *data);

/******************************************************************************
NAME
    avrcp_get_profile_value

DESCRIPTION
    Helper function to get the AVRCP Profile value.


RETURNS
    The current AVRCP profile which is configured having possible values:
    AVRCP_PROFILE_DISABLED,
    AVRCP_PROFILE_1_0
*/
AVRCP_PROFILE_T avrcp_get_profile_value(void);
/******************************************************************************
NAME
    avrcp_get_company_id

DESCRIPTION
    Helper function to get the Company ID value.

RETURNS
    The company ID as defined in the module configuration file for AVRCP.
*/
uint16 avrcp_get_company_id(void);
/******************************************************************************
NAME
    avrcp_get_vendor_enabled

DESCRIPTION
    Helper function to get the AVRCP Vendor Enabled value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool avrcp_get_vendor_enabled(void);
/*************************************************************************
NAME
    avrcp_get_max_connection_retries

DESCRIPTION
    Helper function to get the a2dp max connection retries.

RETURNS
    The max connection retries value read from the corresponding config block section 

**************************************************************************/
uint16 avrcp_get_max_connection_retries(void);

/*************************************************************************
NAME
    avrcp_get_connection_failed_timer

DESCRIPTION
    Helper function to Get the AVRCP Connection Failed timer.

RETURNS
    The avrcp  connection failed timer  value read from the corresponding config block section 

**************************************************************************/
uint16 avrcp_get_connection_failed_timer(void);
/*************************************************************************
NAME
    avrcp_get_connection_delay_timer

DESCRIPTION
    Helper function to Get the AVRCP Connection delay timer.

RETURNS
    The avrcp  connection delaytimer value read from the corresponding config block section 

**************************************************************************/
uint16 avrcp_get_connection_delay_timer(void);
/*************************************************************************
NAME
    source_timers_set_avrcp_connection_failed_timer

DESCRIPTION
    Helper function to set the AVRCP Connection Failed timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool avrcp_connection_failed_timer(uint16 timeout);
/*************************************************************************
NAME
    source_timers_set_avrcp_connection_delay_timer

DESCRIPTION
    Helper function to set the AVRCP Connection Delay timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool avrcp_set_connection_delay_timer(uint16 timeout);
/****************************************************************************
NAME    
    avrcp_check_to_send_logitech_command

DESCRIPTION
    Called to send the logictech avrcp vendor command whenever AVRCP profile is connected.

RETURNS
    void
*/
void avrcp_check_to_send_logitech_command(void);
#endif /* _SOURCE_AVRCP_H_ */
