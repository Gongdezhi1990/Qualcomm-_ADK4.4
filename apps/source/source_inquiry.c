/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_inquiry.c

DESCRIPTION
    Inquiry sub-system used to locate discoverable remote devices.
    
*/


/* header for this file */
#include "source_inquiry.h"
/* application header files */
#include "source_app_msg_handler.h"
#include "source_debug.h"
#include "source_memory.h"
#include "source_private.h"
#include "Source_configmanager.h" 
#include "source_connection_mgr.h"
/* VM headers */
#include <panic.h>
#include <stdlib.h>
#include <string.h>


#ifdef DEBUG_INQUIRY
    #define INQUIRY_DEBUG(x) DEBUG(x)
#else
    #define INQUIRY_DEBUG(x)
#endif

typedef struct
{
    unsigned inquiry_tx:8;
    unsigned force_inquiry_mode:1;
} INQUIRY_MODE_DATA_T;

 static INQUIRY_SCAN_DATA_T *INQUIRY_RUN_DATA;
 static INQUIRY_MODE_DATA_T INQUIRY_MODE_DATA;
/****************************************************************************
    Definitions used in EIR data setup
*/

/* EIR tags */
#define EIR_TYPE_LOCAL_NAME_COMPLETE            (0x09)
#define EIR_TYPE_UUID16_PARTIAL                 (0x02)
#define EIR_TYPE_INQUIRY_TX                     (0x0A)
#define EIR_TYPE_UUID16_COMPLETE                (0x03)
#define EIR_TYPE_UUID16_SHORTENED               (0x02)

/* Device UUIDs */
#define BT_UUID_SERVICE_CLASS_A2DP              (0x110D)
#define BT_UUID_SERVICE_CLASS_AUDIO_SOURCE      (0x110A)
#define BT_UUID_SERVICE_CLASS_AUDIO_SINK        (0x110B)
#define BT_UUID_SERVICE_CLASS_AVRCP             (0x110E)
#define BT_UUID_SERVICE_CLASS_AVRCP_CT          (0x110F)
#define BT_UUID_SERVICE_CLASS_AVRCP_TG          (0x110C)
#define BT_UUID_SERVICE_CLASS_HFP_AG            (0x111F)
#define BT_UUID_SERVICE_CLASS_HFP_HF            (0x111E)

/* Macro to acquire byte n from a multi-byte word w */
#define GET_BYTE(w, n)                          (((w) >> ((n) * 8)) & 0xFF)
#define EIR_UUID16(x)                           GET_BYTE((x), 0),GET_BYTE((x), 1)

/* Size of fields */
#define EIR_TYPE_FIELD_SIZE                     (0x01)
#define EIR_SIZE_FIELD_SIZE                     (0x01)
#define EIR_NULL_SIZE                           (0x01)
/* Size of data and data type */
#define EIR_DATA_SIZE(size)                     (EIR_TYPE_FIELD_SIZE + (size))
/* Size of data, type and length field */
#define EIR_DATA_SIZE_FULL(size)                (EIR_SIZE_FIELD_SIZE + EIR_DATA_SIZE(size))
/* Size of all EIR data */
#define EIR_BLOCK_SIZE(size)                    (EIR_NULL_SIZE + (size))

/* UUIDs to list */
static const uint8 eir_uuids[] = {  
    EIR_UUID16(BT_UUID_SERVICE_CLASS_A2DP),
    EIR_UUID16(BT_UUID_SERVICE_CLASS_AUDIO_SOURCE)
};

static const uint8 eir_a2dp_uuids[] =  {EIR_UUID16(BT_UUID_SERVICE_CLASS_A2DP),
                                        EIR_UUID16(BT_UUID_SERVICE_CLASS_AUDIO_SOURCE)
                                       };

static const uint8 eir_avrcp_uuids[] = {EIR_UUID16(BT_UUID_SERVICE_CLASS_AVRCP),
                                        EIR_UUID16(BT_UUID_SERVICE_CLASS_AVRCP_CT),
                                        EIR_UUID16(BT_UUID_SERVICE_CLASS_AVRCP_TG)
                                       };

static const uint8 eir_hfp_uuids[] =   {EIR_UUID16(BT_UUID_SERVICE_CLASS_HFP_AG)
                                       };


/* DataEl(0x35), Length(0x03), UUID(0x19), Advanced Audio Distribution(0x111E) */
static const uint8 inquiry_hfp_service_search_pattern[] = {0x35, 0x03, 0x19, 0x11, 0x1E};
/* DataEl(0x35), Length(0x03), UUID(0x19), Advanced Audio Distribution(0x110D) */
static const uint8 inquiry_a2dp_service_search_pattern[] = {0x35, 0x03, 0x19, 0x11, 0x0D};


/* local inquiry functions */
static void inquiry_store_result(const CL_DM_INQUIRE_RESULT_T *result);
static PROFILES_T inquiry_parse_eir_uuids(const uint8 size_uuids, const uint8 *uuids);
static INQUIRY_EIR_DATA_T inquiry_parse_eir_data(const uint8 size_eir_data, const uint8* eir_data);


/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    inquiry_init

DESCRIPTION
    Initial setup of inquiry states.

RETURNS
    void
*/    
void inquiry_init(void)
{
    INQUIRY_RUN_DATA = NULL;    
}


/****************************************************************************
NAME    
    inquiry_write_eir_data

DESCRIPTION
    Write EIR data after reading the local name of the device.

RETURNS
    void
*/ 
void inquiry_write_eir_data(const CL_DM_LOCAL_NAME_COMPLETE_T *data)
{
    /* Determine length of EIR data */
    uint16 total_eir_size = 0;
    uint16 size_uuids = 0;
    uint8 *eir = NULL;

    if (connection_mgr_is_aghfp_profile_enabled())
    {
        size_uuids += sizeof(eir_hfp_uuids);
    }
    if (connection_mgr_is_a2dp_profile_enabled())
    {
        size_uuids += sizeof(eir_a2dp_uuids);
    }
    if (connection_mgr_is_avrcp_profile_enabled())
    {
        size_uuids += sizeof(eir_avrcp_uuids);
    }
    
    total_eir_size = EIR_BLOCK_SIZE(EIR_DATA_SIZE_FULL(data->size_local_name) + 
                    EIR_DATA_SIZE_FULL(sizeof(uint8)) + EIR_DATA_SIZE_FULL(size_uuids));
    
    /* Allocate space for EIR data */
    eir = (uint8 *)memory_create(total_eir_size);
    
    if (eir)
    {
        uint8 *p = eir;
            
        /* Device Name Field */
        *p++ = EIR_DATA_SIZE(data->size_local_name);  
        *p++ = EIR_TYPE_LOCAL_NAME_COMPLETE;
        memmove(p, data->local_name, data->size_local_name);
        p += data->size_local_name;
            
        /* Inquiry Tx Field */
        *p++ = EIR_DATA_SIZE(sizeof(int8));
        *p++ = EIR_TYPE_INQUIRY_TX;
        *p++ = INQUIRY_MODE_DATA.inquiry_tx;
            
        /* UUID16 field */
        *p++ = EIR_DATA_SIZE(sizeof(eir_uuids));
        *p++ = EIR_TYPE_UUID16_COMPLETE;
        
        if (connection_mgr_is_aghfp_profile_enabled())
        {
            memmove(p, eir_hfp_uuids, sizeof(eir_hfp_uuids));
            p += sizeof(eir_hfp_uuids);
        }
        if (connection_mgr_is_a2dp_profile_enabled())
        {
            memmove(p, eir_a2dp_uuids, sizeof(eir_a2dp_uuids));
            p += sizeof(eir_a2dp_uuids);
        }
        if (connection_mgr_is_avrcp_profile_enabled())
        {
            memmove(p, eir_avrcp_uuids, sizeof(eir_avrcp_uuids));
            p += sizeof(eir_avrcp_uuids);
        }
            
        /* NULL Termination */
        *p++ = 0x00; 
            
        /* Register and free EIR data */
        ConnectionWriteEirData(FALSE, total_eir_size, eir);
        memory_free(eir);
        
        INQUIRY_DEBUG(("INQUIRY: inquiry_write_eir_data\n"));
    }
}


/****************************************************************************
NAME    
    inquiry_start_discovery

DESCRIPTION
    Begin the inquiry procedure.

RETURNS
    void
*/
void inquiry_start_discovery(void)
{
    INQUIRY_DEBUG(("INQUIRY: inquiry_start_discovery\n"));
        
    if (INQUIRY_RUN_DATA == NULL)
    {
        INQUIRY_RUN_DATA = (INQUIRY_SCAN_DATA_T *) memory_create(sizeof(INQUIRY_SCAN_DATA_T));
        if (INQUIRY_RUN_DATA)
        {
            /* set read and write indexes */
            INQUIRY_RUN_DATA->read_idx = 0;
            INQUIRY_RUN_DATA->write_idx = 0;
            INQUIRY_RUN_DATA->search_idx = 0;             
            INQUIRY_RUN_DATA->inquiry_state_timeout = 0;
            if (inquiry_get_state_timer() != TIMER_NO_TIMEOUT)
            {
                MessageSendLater(app_get_instance(), APP_INQUIRY_STATE_TIMEOUT, 0, D_SEC(inquiry_get_state_timer()));
            }
        }
    }
    
    if (INQUIRY_RUN_DATA)
    {
        /* start Bluetooth inquiry */
        ConnectionInquire(connection_mgr_get_instance(), INQUIRY_LAP, INQUIRY_MAX_RESPONSES, INQUIRY_TIMEOUT, (uint32)COD_MAJOR_AV);            
    }
    else
    {
        /* memory should exist here issue a Panic */
        Panic();
    }
}


/****************************************************************************
NAME    
    inquiry_handle_result

DESCRIPTION
    Process the inquiry result contained in the CL_DM_INQUIRE_RESULT message.

RETURNS
    void
*/
void inquiry_handle_result(const CL_DM_INQUIRE_RESULT_T *result)
{    
    switch (states_get_state())
    {
        case SOURCE_STATE_INQUIRING:
        {
            switch (result->status)
            {
                case inquiry_status_result:
                {
                    INQUIRY_DEBUG(("    result\n"));
                    inquiry_store_result(result);
                }
                break;
                
                case inquiry_status_ready:
                {
                    INQUIRY_DEBUG(("    ready\n"));
                    inquiry_process_results();
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
    inquiry_complete

DESCRIPTION
    Inquiry procedure has completed so tidy up any inquiry data.

RETURNS
    void
*/
void inquiry_complete(void)
{
    INQUIRY_DEBUG(("INQUIRY: complete\n"));
    if (INQUIRY_RUN_DATA)
    {
        memory_free(INQUIRY_RUN_DATA);
        INQUIRY_RUN_DATA = NULL;
        MessageCancelAll(app_get_instance(), APP_INQUIRY_STATE_TIMEOUT);
    }
}


/****************************************************************************
NAME    
    inquiry_has_results

DESCRIPTION
    Determines if any device has been located during the inquiry procedure.
    
RETURNS
    bool
*/
bool inquiry_has_results(void)
{
    if ((INQUIRY_RUN_DATA != NULL) && (INQUIRY_RUN_DATA->read_idx < INQUIRY_RUN_DATA->write_idx))
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    inquiry_process_results

DESCRIPTION
    Process the devices located during the inquiry procedure.

RETURNS
    void
*/
void inquiry_process_results(void)
{
    INQUIRY_DEBUG(("INQUIRY: inquiry_process_results\n"));
    if (inquiry_has_results())
    {
        PROFILES_T connect_profile = PROFILE_NONE;
        
        /* store the index of the remote device to try */
        INQUIRY_RUN_DATA->search_idx = INQUIRY_RUN_DATA->read_idx;
        /* increment inquiry read index */
        INQUIRY_RUN_DATA->read_idx++; 
        
        INQUIRY_DEBUG(("    has result\n"));
        
        if (connection_mgr_is_aghfp_profile_enabled() &&
                ((INQUIRY_RUN_DATA->eir_data[INQUIRY_RUN_DATA->search_idx].profiles & PROFILE_AGHFP) == PROFILE_AGHFP))
        {
            /* connect with AGHFP profile if supported on Source and advertised as supported on remote device in EIR data */
            connect_profile = PROFILE_AGHFP;
        }
        else if (connection_mgr_is_a2dp_profile_enabled() && 
                ((INQUIRY_RUN_DATA->eir_data[INQUIRY_RUN_DATA->search_idx].profiles & PROFILE_A2DP) == PROFILE_A2DP))
        {
            /* connect with A2DP profile if supported on Source and advertised as supported on remote device in EIR data */
            connect_profile = PROFILE_A2DP;
        }
        else
        {
            /* connect with AGHFP profile if enabled otherwise use A2DP profile */
            connect_profile = connection_mgr_is_aghfp_profile_enabled() ? PROFILE_AGHFP : PROFILE_A2DP;
        }
         
        /* initialise the connection with the connection manager */
        connection_mgr_start_connection_attempt(&INQUIRY_RUN_DATA->buffer[INQUIRY_RUN_DATA->search_idx], connect_profile, 0); 
    }
    else
    {               
        if (INQUIRY_RUN_DATA && INQUIRY_RUN_DATA->inquiry_state_timeout)
        {
            /* free inquiry memory */
            inquiry_complete();
            /* inquiry state has timed out, move to next procedure */
            if (inquiry_get_Idle_timer())
            {
                states_set_state(SOURCE_STATE_IDLE);
            }
            else
            {
                /* restart inquiry */
                inquiry_start_discovery();
            }            
        }
        else
        {
            /* restart inquiry */
            inquiry_start_discovery();
        }
    }
}


/****************************************************************************
NAME    
    inquiry_store_result - 

DESCRIPTION
    Store the device returned in the CL_DM_INQUIRE_RESULT message

RETURNS
    void
*/
static void inquiry_store_result(const CL_DM_INQUIRE_RESULT_T *prim)
{      
    INQUIRY_EIR_DATA_T result;
    
    INQUIRY_DEBUG(("INQUIRY: Found device:"));
    DEBUG_BDADDR(prim->bd_addr);
    
    result = inquiry_parse_eir_data(prim->size_eir_data, prim->eir_data);
             
    /* If device doesn't support anything we can use forget it */
    if ((result.profiles == PROFILE_NONE) && (result.profiles_complete))
    {        
        INQUIRY_DEBUG(("INQUIRY: Device Unsupported\n"));
        return;
    }
    
    /* Subtract RSSI from Inquiry Tx Power, assume min possible RSSI if unknown */
    result.path_loss -= (prim->rssi == CL_RSSI_UNKNOWN) ? -127 : prim->rssi;
    
    INQUIRY_DEBUG(("INQUIRY: path loss: %i\n", result.path_loss));
    
    if ((INQUIRY_RUN_DATA != NULL) && (INQUIRY_RUN_DATA->write_idx < INQUIRY_SCAN_BUFFER_SIZE))
    {
        uint8 j, k;    
        
        /* Start by checking if we have already found this device */
        for (k = 0; k < INQUIRY_RUN_DATA->write_idx; k++)
        {
            /* Found duplicate */
            if (BdaddrIsSame(&prim->bd_addr, &INQUIRY_RUN_DATA->buffer[k] ))
            {
                INQUIRY_DEBUG(("INQUIRY: Device already found\n"));
                
                /* If we got a lower path loss this time */
                if (result.path_loss < INQUIRY_RUN_DATA->eir_data[k].path_loss)
                {
                    /* Remove the old record and put this one in */
                    INQUIRY_DEBUG(("INQUIRY: - updating\n"));
                    INQUIRY_RUN_DATA->write_idx--;
                    for (j = k; j < INQUIRY_RUN_DATA->write_idx; j++)
                    {
                        INQUIRY_RUN_DATA->buffer[j] = INQUIRY_RUN_DATA->buffer[j+1];
                        INQUIRY_RUN_DATA->eir_data[j] = INQUIRY_RUN_DATA->eir_data[j+1];
                    }
                    break;
                }
                else
                {
                    /* No point updating */
                    INQUIRY_DEBUG(("INQUIRY: - returning\n"));
                    return;
                }
            }
        }
        
        /* Move up the found devices list */
        for (k = k; k > 0; k--)
        {
            /* If next dev up has lower path loss we have found our place */
            if (INQUIRY_RUN_DATA->eir_data[k-1].path_loss <= result.path_loss)
                break;
        }
        
        INQUIRY_DEBUG(("INQUIRY: Adding device at %d of %d\n", k, INQUIRY_RUN_DATA->write_idx));        
        INQUIRY_DEBUG(("    path_loss:%d  profiles:%d  profiles_complete:%d\n", result.path_loss, result.profiles, result.profiles_complete));
        DEBUG_BDADDR(prim->bd_addr);
        
        
        /* Shuffle down other entries if required */
        for (j = INQUIRY_RUN_DATA->write_idx; j > k; j--)
        {
            INQUIRY_RUN_DATA->buffer[j] = INQUIRY_RUN_DATA->buffer[j-1];
            INQUIRY_RUN_DATA->eir_data[j] = INQUIRY_RUN_DATA->eir_data[j-1];
        }
        
        /* Add device at k and increment write index */
        INQUIRY_RUN_DATA->buffer[k] = prim->bd_addr;
        INQUIRY_RUN_DATA->eir_data[k] = result;
        INQUIRY_RUN_DATA->write_idx++;
    }
}


/****************************************************************************
NAME    
    inquiry_parse_eir_uuids - 

DESCRIPTION
   Returns the profiles found in the EIR data

RETURNS
    PROFILES_T
*/
static PROFILES_T inquiry_parse_eir_uuids(const uint8 size_uuids, const uint8 *uuids)
{
    PROFILES_T profiles = PROFILE_NONE;
    uint8 k;
    uint16 uuid;
    
    for (k = 0; k < size_uuids; k += 2)
    {
        /* Get UUID from data */
        uuid = uuids[k] | (uuids[k+1] << 8);
            
        /* Is this something we can connect to */      
        if (uuid == BT_UUID_SERVICE_CLASS_AUDIO_SINK)
            profiles |= PROFILE_A2DP;
        else if (uuid == BT_UUID_SERVICE_CLASS_AVRCP)
            profiles |= PROFILE_AVRCP;
        else if (uuid == BT_UUID_SERVICE_CLASS_HFP_HF)
            profiles |= PROFILE_AGHFP;        
    }
    return profiles;
}


/****************************************************************************
NAME    
    inquiry_parse_eir_data 

DESCRIPTION
   - Returns the the required EIR data found in the inquiry result

RETURNS
    INQUIRY_EIR_DATA_T
*/
static INQUIRY_EIR_DATA_T inquiry_parse_eir_data(const uint8 size_eir_data, const uint8* eir_data)
{
    const uint8* p = eir_data;
    INQUIRY_EIR_DATA_T result;
    
    /* Default to max possible Inquiry Tx Power */
    result.path_loss = 127;
    result.profiles = PROFILE_NONE;
    result.profiles_complete = FALSE;
    
    /* Search until no more to read */
    for (p = eir_data; (uint8)(p - eir_data) != size_eir_data; p += (*p)+1)
    {
        /* Check type fields for UUIDs or Inquiry Tx Power */
        if (*(p+1) == EIR_TYPE_INQUIRY_TX)
        {
            /* Initially set path loss to Inquiry Tx Power*/
            result.path_loss = *p+2;
        }
        else if ((*(p+1) == EIR_TYPE_UUID16_COMPLETE) || (*(p+1) == EIR_TYPE_UUID16_SHORTENED))
        {
            /* Get the profile information */
            result.profiles_complete = (*(p+1) == EIR_TYPE_UUID16_COMPLETE);
            result.profiles = inquiry_parse_eir_uuids(*p , p+2);
        }
    }
    
    /* Return number of UUIDs found in EIR data */
    return result;
}
/****************************************************************************
NAME    
    inquiry_get_inquiry_data - 

DESCRIPTION
   - Returns the inquiry data pointer.

RETURNS
    INQUIRY_SCAN_DATA_T
*/
INQUIRY_SCAN_DATA_T *inquiry_get_inquiry_data(void)
{
    return INQUIRY_RUN_DATA;
}
/****************************************************************************
NAME    
    inquiry_set_inquiry_state_timeout - 

DESCRIPTION
   - Sets the inquiry state timeout.

RETURNS
    void
*/
void inquiry_set_inquiry_state_timeout(bool inquiry_state_timeout)
{
     INQUIRY_RUN_DATA->inquiry_state_timeout = inquiry_state_timeout;
}
/****************************************************************************
NAME    
    inquiry_set_forced_inquiry_mode -

DESCRIPTION
   Sets the Forced Inquiry Mode variable.

RETURNS
    void
*/
void inquiry_set_forced_inquiry_mode(bool force_inquiry_mode)
{
     INQUIRY_MODE_DATA.force_inquiry_mode = force_inquiry_mode;
}
/****************************************************************************
NAME    
    inquiry_get_forced_inquiry_mode -

DESCRIPTION
    Gets the Forced Inquiry Mode variable.

RETURNS
    bool
*/
bool inquiry_get_forced_inquiry_mode(void)
{
     return INQUIRY_MODE_DATA.force_inquiry_mode;
}
/****************************************************************************
NAME    
    inquiry_set_inquiry_tx - 

DESCRIPTION
  Sets the Inquiry Tx.

RETURNS
    void
*/
void inquiry_set_inquiry_tx(uint8 inquiry_tx )
{
     INQUIRY_MODE_DATA.inquiry_tx = inquiry_tx;
}
/*************************************************************************
NAME
    inquiry_get_state_timer

DESCRIPTION
    Helper function to Get the Inquiry state timer.

RETURNS
    The inquiry state timer value read from the corresponding config block section .

**************************************************************************/
uint16 inquiry_get_state_timer(void)
{
    uint16 inquiry_state_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        inquiry_state_timer = timer_data->private_data_timers.InquiryState_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return inquiry_state_timer;
}
/*************************************************************************
NAME
    inquiry_get_Idle_timer

DESCRIPTION
    Helper function to Get the Inquiry Idle timer.

RETURNS
    The inquiry idle timer value read from the corresponding config block section .

**************************************************************************/
uint16 inquiry_get_Idle_timer(void)
{
    uint16 inquiry_idle_timer = 0;
    sourcedata_readonly_config_def_t *timer_data;

    if (configManagerGetReadOnlyConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID, (const void **)&timer_data))
    {
        inquiry_idle_timer = timer_data->private_data_timers.InquiryIdle_s;
    }
    configManagerReleaseConfig(SOURCEDATA_READONLY_CONFIG_BLK_ID);
    return inquiry_idle_timer;
}
