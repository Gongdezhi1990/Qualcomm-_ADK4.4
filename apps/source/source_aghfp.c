/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_aghfp.c

DESCRIPTION
    AGHFP profile functionality.
    
*/

/* header for this file */
#include "source_aghfp.h"
/* application header files */
#include "source_aghfp_msg_handler.h"
#include "source_app_msg_handler.h"
#include "source_debug.h"
#include "source_memory.h"
#include "source_sc.h"
#include "source_usb.h"
#include "source_volume.h"
#include "source_power.h"
#include "source_audio.h"
#include "source_connection_mgr.h"
/* profile/library headers */
#include <aghfp.h>
/* VM headers */
#include <stdlib.h>

#include <source_aghfp_data.h>

/* structure holding the AGHFP data */
typedef struct
{
    aghfpInstance *inst;  
    AGHFP *aghfp;
    AGHOST_T aghost_state;
    AGHFP_AUDIO_T gHfpSrcData;
    lp_power_table *aghfp_powertable;
    unsigned number_aghfp_entries;
} AGHFP_DATA_T;

#ifdef DEBUG_AGHFP
    #define AGHFP_DEBUG(x) DEBUG(x)

    const char *const aghfp_state_strings[AGHFP_STATES_MAX] = { "Disconnected",
                                                                "Connecting Local",
                                                                "Connecting Remote",
                                                                "Connected",
                                                                "Connecting Audio Local",
                                                                "Connecting Audio Remote",
                                                                "Connected Audio",
                                                                "Disconnecting Audio",
                                                                "Disconnecting"
                                                                };
      
#else
    #define AGHFP_DEBUG(x)
#endif

/* loop through all HFP connection instances */
#define for_all_aghfp_instance(index) index = 0;/*for (index = 0; index < AGHFP_MAX_INSTANCES; index++)*/
#define PACK_32(bandwidth_low, bandwidth_high) (((uint32)bandwidth_high << 16) | ((uint32) (bandwidth_low) & 0x0000FFFFUL))

static AGHFP_DATA_T AGHFP_RUNDATA;

/* Determines if in an audio active state */    
#define aghfp_is_audio(state) ((state >= AGHFP_STATE_CONNECTED_AUDIO) && (state <= AGHFP_STATE_DISCONNECTING_AUDIO))    
/* Display unhandled states in Debug Mode */    
#define aghfp_unhandled_state(inst) AGHFP_DEBUG(("    AGHFP Unhandled State [%d] inst[0x%x]\n", aghfp_get_state(inst), (uint16)inst));    


/* exit state functions */
static void aghfp_exit_state(aghfpInstance *inst);
static void aghfp_exit_state_disconnected(aghfpInstance *inst);
static void aghfp_exit_state_connecting_local(aghfpInstance *inst);
static void aghfp_exit_state_connecting_remote(aghfpInstance *inst);
static void aghfp_exit_state_connected(aghfpInstance *inst);
static void aghfp_exit_state_connecting_audio_local(aghfpInstance *inst);
static void aghfp_exit_state_connecting_audio_remote(aghfpInstance *inst);
static void aghfp_exit_state_connected_audio(aghfpInstance *inst);
static void aghfp_exit_state_disconnecting_audio(aghfpInstance *inst);
static void aghfp_exit_state_disconnecting(aghfpInstance *inst);
/* enter state functions */
static void aghfp_enter_state(aghfpInstance *inst, AGHFP_STATE_T old_state);
static void aghfp_enter_state_disconnected(aghfpInstance *inst, AGHFP_STATE_T old_state);
static void aghfp_enter_state_connecting_local(aghfpInstance *inst, AGHFP_STATE_T old_state);
static void aghfp_enter_state_connecting_remote(aghfpInstance *inst, AGHFP_STATE_T old_state);
static void aghfp_enter_state_connected(aghfpInstance *inst, AGHFP_STATE_T old_state);
static void aghfp_enter_state_connecting_audio_local(aghfpInstance *inst, AGHFP_STATE_T old_state);
static void aghfp_enter_state_connecting_audio_remote(aghfpInstance *inst, AGHFP_STATE_T old_state);
static void aghfp_enter_state_disconnecting_audio(aghfpInstance *inst, AGHFP_STATE_T old_state);
static void aghfp_enter_state_disconnecting(aghfpInstance *inst, AGHFP_STATE_T old_state);
/* misc local functions */
static void aghfp_set_remote_volume(AGHFP *aghfp);
static void aghfp_get_indicators(void);

/***************************************************************************
Functions
****************************************************************************
*/
/****************************************************************************
NAME    
    aghfp_get_indicators
    
    DESCRIPTION
    This function gets HFP indicatroes if profile version supported is HFP1.7

RETURNS
    void
****************************************************************************/
void aghfp_get_indicators(void)
{
    if(aghfp_get_profile_Value() == HFP_PROFILE_1_7)
    {
       /*Default HF Indicators enabled */
        AGHFP_RUNDATA.aghost_state.hf_indicator_info.active_hf_indicators = aghfp_enhanced_safety_mask | aghfp_battery_level_mask;
        AGHFP_RUNDATA.aghost_state.hf_indicator_info.hf_indicators_state =  (aghfp_hf_indicator_on << aghfp_enhanced_safety) |
                                                                              (aghfp_hf_indicator_on << aghfp_battery_level);  
    }

}

/****************************************************************************
NAME    
    aghfp_init -

    DESCRIPTION
    Initialises the AGHFP profile libary and prepares the application so it can handle AGHFP connections.
    The application will allocate a memory block to hold connection related information.
    Each AGHFP connection with a remote device will be stored within the memory block as an AGHFP instance. 

RETURNS
    void
*/
void aghfp_init(void)
{    
    /* Init AGHFP library as HFP v1.7 profile. eSCO S4 settings is supported. Enhanced call status is Mandatory for AG.
       Codec negotiation required for Wide Band Speech (WBS).
    */
    aghfp_profile profile = aghfp_handsfree_17_profile;
    uint16 features = aghfp_voice_recognition | aghfp_enhanced_call_status | aghfp_codec_negotiation |
    aghfp_esco_s4_supported | aghfp_hf_indicators;
    uint16 index;

    /*initialize this structure to 0.*/
    memset(&AGHFP_RUNDATA,0,sizeof(AGHFP_DATA_T));
    /*Initializes the AGHFP configuration data*/
    aghfp_source_data_init();
    /*Get HFP indicators */
    aghfp_get_indicators();
    /* allocate memory for AGHFP instances */
    AGHFP_RUNDATA.inst = (aghfpInstance *)memory_get_block(MEMORY_GET_BLOCK_PROFILE_AGHFP);
    
    /* initialise each instance */
    for_all_aghfp_instance(index)
    {
        AGHFP_RUNDATA.inst[index].aghfp_state = AGHFP_STATE_DISCONNECTED;        
        aghfp_init_instance(&AGHFP_RUNDATA.inst[index]);
    }
    
    /* Register AGHFP library */
    AghfpInit(&AGHFP_RUNDATA.inst[0].aghfpTask, 
                profile, 
                features);  
}


/****************************************************************************
NAME    
    aghfp_get_instance_from_bdaddr -

DESCRIPTION
    Finds and returns the AGHFP instance with address set to the addr passed to the function.
    
RETURNS
    If an AGHFP instance has address set as addr then that aghfpInstance will be returned.
    Otherwise NULL.
*/
aghfpInstance *aghfp_get_instance_from_bdaddr(const bdaddr *addr)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst)
    {
        for_all_aghfp_instance(index)
        {
            if (!BdaddrIsZero(&inst->addr) && BdaddrIsSame(&inst->addr, addr))
                return inst;
            inst++;
        }
    }
    
    return NULL;
}


/****************************************************************************
NAME    
    aghfp_get_instance_from_pointer - 

DESCRIPTION
    Finds and returns the AGHFP instance with AGHFP pointer set to the aghfp address passed to the function.
    
RETURNS
    If an AGHFP instance has the AGHFP pointer set as aghfp then that aghfpInstance will be returned.
    Otherwise NULL.
*/
aghfpInstance *aghfp_get_instance_from_pointer(AGHFP *aghfp)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst)
    {
        for_all_aghfp_instance(index)
        {
            if ((inst->aghfp != 0) && (inst->aghfp == aghfp))
                return inst;
            inst++;
        }
    }
    
    return NULL;
}


/****************************************************************************
NAME    
    aghfp_get_free_instance - 

DESCRIPTION
    Finds and returns the a free AGHFP instance which has no current ongoing connection.
    
RETURNS
    If an AGHFP instance has no ongoing connection then that aghfpInstance will be returned.
    Otherwise NULL.
*/
aghfpInstance *aghfp_get_free_instance(void)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst)
    {
        for_all_aghfp_instance(index)
        {
            if (BdaddrIsZero(&inst->addr))
                return inst;
            inst++;
        }
    }
    
    return NULL;
}


/****************************************************************************
NAME    
    aghfp_init_instance 

DESCRIPTION
     - Sets an AGHFP instance to a default state of having no ongoing connection.

RETURNS
    void
*/
void aghfp_init_instance(aghfpInstance *inst)
{
    uint16 i = 0;
    
    inst->aghfpTask.handler = aghfp_msg_handler;
    MessageFlushTask(&inst->aghfpTask);
    aghfp_set_state(inst, AGHFP_STATE_DISCONNECTED);
    BdaddrSetZero(&inst->addr);
    inst->aghfp = 0;
    inst->link_type = sync_link_unknown;
    inst->slc_sink = 0;
	inst->audio_sink = 0;
    inst->using_wbs = 0;
    inst->cli_enable = 0;
    inst->aghfp_support = AGHFP_SUPPORT_UNKNOWN;
    inst->aghfp_connection_retries = 0;
    inst->connecting_audio = 0;
    inst->disconnecting_audio = 0;
    inst->use_negotiated_codec = FALSE;
    inst->source_link_mode = source_no_secure_connection;
    
    for (i = 0; i < CSR_AG_AUDIO_WARP_NUMBER_VALUES; i++)
    {
        inst->warp[i] = 0;
    }
}


/****************************************************************************
NAME    
    aghfp_start_connection 

DESCRIPTION
    Initiates an AGHFP connection to the remote device with address stored in theSource->connection_data.remote_connection_addr. 

RETURNS
    void
*/
void aghfp_start_connection(void)
{
    aghfpInstance *inst = NULL;
    
    if (!BdaddrIsZero(connection_mgr_get_remote_address()))
    {            
        inst = aghfp_get_instance_from_bdaddr(connection_mgr_get_remote_address());            
    
        if (inst == NULL)
        {
            inst = aghfp_get_free_instance();
            
            if (inst != NULL)
            {
                /* store address of device it's attempting to connect to */
                 inst->addr = *connection_mgr_get_remote_address();
                /* store library pointer */
                inst->aghfp = AGHFP_RUNDATA.aghfp;
                /* don't know if HFP is supported at the moment */
                inst->aghfp_support = AGHFP_SUPPORT_UNKNOWN;
            }
        }
    
        AGHFP_DEBUG(("AGHFP: aghfp_start_connection"));
        DEBUG_BTADDR(connection_mgr_get_remote_address());
    
        if (inst != NULL)
        {    
            /* there is a free AGHFP instance so initiate signalling connection */
            MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_CONNECT_REQ, 0);
        }
        else
        {
            /* there is no free AGHFP instance so signal to the app that the connection attempt has failed */            
            MessageSend(app_get_instance(), APP_CONNECT_FAIL_CFM, 0);
        }
    }
}


/****************************************************************************
NAME    
    aghfp_get_number_connections - 

DESCRIPTION
    Returns the number of currently active AGHFP connections.
    
RETURNS
    The number of currently active AGHFP connections.
*/
uint16 aghfp_get_number_connections(void)
{
    uint16 connections = 0;
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(aghfp_get_state(inst)))
                connections++;
            inst++;
        }
    }
    
    return connections;
}


/****************************************************************************
NAME    
    aghfp_disconnect_all - 

DESCRIPTION
    Disconnects all active AGHFP connections.

RETURNS
    void
*/
void aghfp_disconnect_all(void)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(aghfp_get_state(inst)))
            {
                /* disconnect SLC */
                aghfp_set_state(inst, AGHFP_STATE_DISCONNECTING);
            }
            inst++;
        }
    }
}


/****************************************************************************
NAME    
    aghfp_set_state - 

DESCRIPTION
    Sets the new state of an AGHFP connection.

RETURNS
    void
*/
void aghfp_set_state(aghfpInstance *inst, AGHFP_STATE_T new_state)
{
    if (new_state < AGHFP_STATES_MAX)
    {
        AGHFP_STATE_T old_state = inst->aghfp_state;
        
        /* leaving current state */        
        aghfp_exit_state(inst);
        
        /* store new state */
        inst->aghfp_state = new_state;
        AGHFP_DEBUG(("AGHFP STATE: new state [%s]\n", aghfp_state_strings[new_state]));
        
        /* entered new state */
        aghfp_enter_state(inst, old_state);
    }
}


/****************************************************************************
NAME    
    aghfp_get_state 

DESCRIPTION
   -  Gets the current state of an AGHFP connection.

RETURNS
    AGHFP_STATE_T
*/
AGHFP_STATE_T aghfp_get_state(aghfpInstance *inst)
{
    return inst->aghfp_state;
}

/****************************************************************************
NAME    
    aghfp_route_all_audio -

DESCRIPTION
    Routes audio for all AGHFP connections.

RETURNS
    void
*/
void aghfp_route_all_audio(void)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            /* cancel pending disconnect audio requests */
            MessageCancelAll(&inst->aghfpTask, AGHFP_INTERNAL_DISCONNECT_AUDIO_REQ);
            
            if (aghfp_is_connected(aghfp_get_state(inst)))
            {
                /* initiate the audio connection */    
                MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_CONNECT_AUDIO_REQ, 0);
            }
            inst++;
        }
    }
    
    /* reset audio delay flag */
    audio_set_aghfp_conn_delay(FALSE);
}


/****************************************************************************
NAME    
    aghfp_suspend_all_audio -

DESCRIPTION
    Suspends audio for all AGHFP connections.

RETURNS
    void
*/
void aghfp_suspend_all_audio(void)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_audio(aghfp_get_state(inst)))
                MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_DISCONNECT_AUDIO_REQ, 0);
        }
        inst++;
    }
}


/****************************************************************************
NAME    
    aghfp_is_connecting - 

DESCRIPTION
   -  Returns if the AGHFP profile is currently connecting.

RETURNS
    TRUE - AGHFP profile is currently connecting
    FALSE - AGHFP profile is not connecting
*/
bool aghfp_is_connecting(void)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    AGHFP_STATE_T state;
    
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            state = aghfp_get_state(inst);
            if ((state == AGHFP_STATE_CONNECTING_LOCAL) || (state == AGHFP_STATE_CONNECTING_REMOTE))
                return TRUE;
            inst++;
        }
    }
    
    return FALSE;
}


/****************************************************************************
NAME    
    aghfp_get_link_mode - 

DESCRIPTION
    Returns the AGHFP profile link mode(secure or not).

RETURNS
    Link mode
*/
AGHFP_LINK_MODE_T aghfp_get_link_mode(void)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if(aghfp_is_connected(inst->aghfp_state))
            {
               if(is_link_secure(inst))
                  return AGHFP_LINK_MODE_SECURE;
               else
                  return AGHFP_LINK_MODE_UNSECURE;
	        }
            inst++;
        }
    }
    
    return AGHFP_LINK_MODE_NO_SLC_CONNECTION;
}


/****************************************************************************
NAME    
    aghfp_is_audio_active - 

DESCRIPTION
   -  Returns if the AGHFP profile has audio active.

RETURNS
    TRUE - AGHFP profile has audio active
    FALSE - AGHFP profile does not have audio active
*/
bool aghfp_is_audio_active(void)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    bool aghfp_audio_present = FALSE;    
    
    if (inst != NULL)
    {
        if (connection_mgr_is_aghfp_profile_enabled())
        {
            for_all_aghfp_instance(index)
            {
                if (aghfp_is_audio(inst->aghfp_state))
                    aghfp_audio_present = TRUE;
                inst++;
            }
        }
    }
    
    return aghfp_audio_present;
}


/****************************************************************************
NAME    
    aghfp_call_ind_none - 

DESCRIPTION
    A call indication has been recieved from the host - no call.

RETURNS
    void
*/
void aghfp_call_ind_none(void)
{
    /* update AG Host state */
    aghfp_host_set_call_state(aghfp_call_none);
    aghfp_host_set_call_setup_state(aghfp_call_setup_none);
    aghfp_host_set_call_held_state(aghfp_call_held_none);
    
}


/****************************************************************************
NAME    
    aghfp_call_ind_incoming - 

DESCRIPTION
   -  A call indication has been recieved from the host (incoming call)

RETURNS
    void
    
*/
void aghfp_call_ind_incoming(uint16 size_data, const uint8 *data)
{
    /* update AG Host state */
    aghfp_host_set_call_state(aghfp_call_none);
    aghfp_host_set_call_setup_state(aghfp_call_setup_incoming);
    aghfp_host_set_call_held_state(aghfp_call_held_none);
    
    if (size_data >= 3)
    {
        aghfp_host_set_ring_indication(data[0], data[1], &data[2]);
    }
}


/****************************************************************************
NAME    
    aghfp_call_ind_outgoing -

DESCRIPTION
   -   A call indication has been recieved from the host (outgoing call)

RETURNS
    void
    
*/
void aghfp_call_ind_outgoing(void)
{
    /* update AG Host state */
    aghfp_host_set_call_state(aghfp_call_none);
    aghfp_host_set_call_setup_state(aghfp_call_setup_outgoing);
    aghfp_host_set_call_held_state(aghfp_call_held_none);
}


/****************************************************************************
NAME    
    aghfp_call_ind_active -

DESCRIPTION
   -    A call indication has been recieved from the host (active call)

RETURNS
    void
    
*/
void aghfp_call_ind_active(void)
{
    /* update AG Host state */
    aghfp_host_set_call_state(aghfp_call_active);
    aghfp_host_set_call_setup_state(aghfp_call_setup_none);
    aghfp_host_set_call_held_state(aghfp_call_held_none);
}


/****************************************************************************
NAME    
    aghfp_call_ind_waiting_active_call - 

DESCRIPTION
   -    A call indication has been recieved from the host (active call with call waiting)

RETURNS
    void
    
*/
void aghfp_call_ind_waiting_active_call(uint16 size_data, const uint8 *data)
{
    /* update AG Host state */
    aghfp_host_set_call_state(aghfp_call_active);
    
    if (size_data >= 3)
    {
        aghfp_host_set_ring_indication(data[0], data[1], &data[2]);
    }
    
    aghfp_host_set_call_setup_state(aghfp_call_setup_incoming);
    aghfp_host_set_call_held_state(aghfp_call_held_none);    
}


/****************************************************************************
NAME    
    aghfp_call_ind_held_active_call -

DESCRIPTION
   -     A call indication has been recieved from the host (active call with held call)

RETURNS
    void
    
*/
void aghfp_call_ind_held_active_call(void)
{   
    /* update AG Host state */
    aghfp_host_set_call_state(aghfp_call_active);
    aghfp_host_set_call_setup_state(aghfp_call_setup_none);
    aghfp_host_set_call_held_state(aghfp_call_held_active);
}


/****************************************************************************
NAME    
    aghfp_call_ind_held - 

DESCRIPTION
   -    A call indication has been recieved from the host (held call)

RETURNS
    void
    
*/
void aghfp_call_ind_held(void)
{
    /* update AG Host state */
    aghfp_host_set_call_state(aghfp_call_active);
    aghfp_host_set_call_setup_state(aghfp_call_setup_none);
    aghfp_host_set_call_held_state(aghfp_call_held_active);
}


/****************************************************************************
NAME    
    aghfp_signal_strength_ind - 

DESCRIPTION
   -    A signal strength indication has been received from the host

RETURNS
    void
*/
void aghfp_signal_strength_ind(uint8 signal_strength)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                AghfpSendSignalIndicator(AGHFP_RUNDATA.aghfp, signal_strength);
            }
            inst++;
        }
    }
    
    aghfp_host_set_signal_strength(signal_strength);
}


/****************************************************************************
NAME    
    aghfp_battery_level_ind - 

DESCRIPTION
   -   A battery level indication has been received from the host

RETURNS
    void

*/
void aghfp_battery_level_ind(uint8 battery_level)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                AghfpSendBattChgIndicator(AGHFP_RUNDATA.aghfp, battery_level);
            }
            inst++;
        }
    }
    
    aghfp_host_set_battery_level(battery_level);
}


/****************************************************************************
NAME    
    aghfp_audio_transfer_req -

DESCRIPTION
   -    Transfers audio HF->AG or AG->HF

RETURNS
    void

*/
void aghfp_audio_transfer_req(bool use_codec_negotiated)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst != NULL)
    {
        inst->use_negotiated_codec = use_codec_negotiated;
        for_all_aghfp_instance(index)
        {
            switch (aghfp_get_state(inst))
            {
                case AGHFP_STATE_CONNECTED_AUDIO:
                {
                    if (connection_mgr_is_a2dp_profile_enabled())
                    {
                        audio_set_voip_music_mode(AUDIO_MUSIC_MODE);
                    }
                    aghfp_set_state(inst, AGHFP_STATE_DISCONNECTING_AUDIO);
                }
                break;
                    
                case AGHFP_STATE_CONNECTED:
                {
                    if (connection_mgr_is_aghfp_profile_enabled())
                    {
                        audio_set_voip_music_mode(AUDIO_VOIP_MODE);
                    }
                    aghfp_set_state(inst, AGHFP_STATE_CONNECTING_AUDIO_LOCAL);
                }
                break;
                    
                default:
                {
                }
                break;
            }
            inst++;
        }
    }
}


/****************************************************************************
NAME    
    aghfp_network_operator_ind - 

DESCRIPTION
   -    A network operator indication has been received from the host

RETURNS
    void
*/
void aghfp_network_operator_ind(uint16 size_data, const uint8 *data)
{
    if (size_data >= 1)
    {
        aghfp_host_set_network_operator(data[0], &data[1]);
    }
    
}


/****************************************************************************
NAME    
    aghfp_hf_indicator_ind -

DESCRIPTION
   -     A hf indicator state has been received from the host

RETURNS
    void
*/
void aghfp_hf_indicator_ind(aghfp_hf_indicators_assigned_id assigned_num, bool status)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    aghfp_hf_indicator_state state = status ? aghfp_hf_indicator_on : aghfp_hf_indicator_off;
        
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                /* Update the AG supported hf indicator state locally */
                if(state == aghfp_hf_indicator_on)
                {
                    /* Set the HF Indicator state */
                    AGHFP_RUNDATA.aghost_state.hf_indicator_info.hf_indicators_state |= (aghfp_hf_indicator_on << assigned_num);
                }
                else
                {
                    /* Clear the HF Indicator state */
                   AGHFP_RUNDATA.aghost_state.hf_indicator_info.hf_indicators_state &= ~(aghfp_hf_indicator_on << assigned_num);
                }
                
		        /* Send to aghfp library to notify to hf*/
                AghfpSendHfIndicatorState(AGHFP_RUNDATA.aghfp, assigned_num, state);
            }
            inst++;
        }
    }
    
}


/****************************************************************************
NAME    
    aghfp_network_availability_ind 

DESCRIPTION
   -    = A network availability indication has been received from the host

RETURNS
    void
*/
void aghfp_network_availability_ind(bool available)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    aghfp_service_availability availability = available ? aghfp_service_present : aghfp_service_none;
        
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                AghfpSendServiceIndicator(AGHFP_RUNDATA.aghfp, availability);
            }
            inst++;
        }
    }
    
    aghfp_host_set_network_availability(availability);
}
  

/****************************************************************************
NAME    
    aghfp_network_roam_ind -

DESCRIPTION
   -     A network roam indication has been received from the host

RETURNS
    void
*/
void aghfp_network_roam_ind(bool roam)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    aghfp_roam_status roaming = roam ? aghfp_roam_active : aghfp_roam_none;
        
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                AghfpSendRoamIndicator(AGHFP_RUNDATA.aghfp, roaming);
            }
            inst++;
        }
    }
    
    aghfp_host_set_roam_status(roaming);
}


/****************************************************************************
NAME    
    aghfp_error_ind -

DESCRIPTION
   -      An error indication has been received from the host

RETURNS
    void
*/
void aghfp_error_ind(void)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
        
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                /* send ERROR to remote side */
                AghfpSendError(AGHFP_RUNDATA.aghfp);
            }
            inst++;
        }
    }
}


/****************************************************************************
NAME    
    aghfp_ok_ind -

DESCRIPTION
   -     An ok indication has been received from the host

RETURNS
    void
*/
void aghfp_ok_ind(void)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
        
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                /* send OK to remote side */
                AghfpSendOk(AGHFP_RUNDATA.aghfp);
            }
            inst++;
        }
    }
}


/****************************************************************************
NAME    
    aghfp_current_call_ind 

DESCRIPTION
   -    A current call indication has been received from the host

RETURNS
    void
*/
void aghfp_current_call_ind(uint16 size_data, const uint8 *data)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    aghfp_call_info call;
    
    call.type = 0;
    call.size_number = 0;
    call.number = 0;
    
    if (size_data >= 5)
    {
        call.idx = (uint8)data[0];
	    call.dir = data[1];
	    call.status = data[2];
	    call.mode = data[3];
	    call.mpty = data[4];
    
        if (size_data >=7)
        {    
	        call.type = data[5];
	        call.size_number = data[6];
            if (call.size_number)
            {
                call.number = memory_create(call.size_number);
                for (index = 0; index < call.size_number; index++)
                {
                    call.number[index] = data[index + 7];
                }
            }
        }
        
        if (inst != NULL)
        {
            for_all_aghfp_instance(index)
            {
                if (aghfp_is_connected(inst->aghfp_state))
                {
                    /* send OK to remote side */
                    AghfpSendCurrentCall(AGHFP_RUNDATA.aghfp, &call);
                }
                inst++;
            }
        }
    }
}


/****************************************************************************
NAME    
    aghfp_voice_recognition_ind -

DESCRIPTION
   -     A voice recognition indication has been received from the host

RETURNS
    void
*/
void aghfp_voice_recognition_ind(bool enable)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
        
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                /* send voice recognition to remote side */
                AghfpVoiceRecognitionEnable(AGHFP_RUNDATA.aghfp, enable);
            }
            inst++;
        }
    }
    
    if (enable)
    {
        /* switch to VOIP mode and enable audio connection */
        aghfp_voip_mode_answer_call();
    }
    
    /* send state to USB host */
    usb_send_device_command_voice_recognition(enable);
}


/****************************************************************************
NAME    
    aghfp_music_mode_end_call - 

DESCRIPTION
   -  Music mode should be entered and the current call ended by sending USB HID command to host

RETURNS
    void
    
*/
void aghfp_music_mode_end_call(void)
{
    /* send USB HID command for HangUp */
    usb_send_hid_hangup();
    
    /* try a switch to MUSIC mode */
    audio_switch_voip_music_mode(AUDIO_MUSIC_MODE);
}


/****************************************************************************
NAME    
    aghfp_voip_mode_answer_call - 

DESCRIPTION
   - VOIP mode should be entered and the current call answered by sending USB HID command to host

RETURNS
    void
    
*/
void aghfp_voip_mode_answer_call(void)
{
    /* send USB HID command for Answer */
    usb_send_hid_answer();
    
    /* try a switch to VOIP mode */
    audio_switch_voip_music_mode(AUDIO_VOIP_MODE);
}


/****************************************************************************
NAME    
    aghfp_send_source_volume - 

DESCRIPTION
   - Send locally stored volumes over AGHFP

RETURNS
    void
*/
void aghfp_send_source_volume(aghfpInstance *inst)
{
    uint16 index = 0;
    
    if (inst)
    {
        aghfp_set_remote_volume(inst->aghfp);        
    }
    else
    {    
        inst = AGHFP_RUNDATA.inst;
        
        if (inst)
        {  
            for_all_aghfp_instance(index)
            {
                if ((inst->aghfp != 0))
                {
                    if (aghfp_is_connected(inst->aghfp_state))
                    {
                        aghfp_set_remote_volume(inst->aghfp);
                    }
                }
                inst++;
            }
        }
    }
}


/****************************************************************************
NAME    
    aghfp_speaker_volume_ind - 

DESCRIPTION
   - Receives speaker volume from the remote device 

RETURNS
    void
*/
void aghfp_speaker_volume_ind(uint8 volume)
{
    usb_device_class_audio_levels levels;
    
    if (usb_get_hid_consumer_interface())
    {
        /* get the current USB audio levels */ 
        UsbDeviceClassGetValue(USB_DEVICE_CLASS_GET_VALUE_AUDIO_LEVELS, (uint16*)&levels);

        /* send USB HID command to the Host to update volume */
        if (levels.out_mute)
        {
            /* the volume was muted so unmute on receiving a volume command */
            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_MUTE);
        }
        else if (volume_get_speaker_volume() > volume)
        {
            /* the new volume is less than the current volume - can only send a volume decrement event to the host */
            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_VOL_DOWN);
        } 
        else if (volume_get_speaker_volume() < volume)
        {
            /* the new volume is more than the current volume - can only send a volume increment event to the host */
            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_VOL_UP);
        } 
    }            
}


/****************************************************************************
NAME    
    aghfp_mic_gain_ind - 

DESCRIPTION
   - Receives microphone gain from the remote device 

RETURNS
    void
*/
void aghfp_mic_gain_ind(uint8 gain)
{
    
}


/****************************************************************************
NAME    
    aghfp_send_voice_recognition -

DESCRIPTION
   -  Sends Voice Recognition command to the remote device

RETURNS
    void
*/
void aghfp_send_voice_recognition(bool enable)
{
    uint16 index;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(aghfp_get_state(inst)))
            {
                /* initiate the audio connection */   
                MAKE_MESSAGE(AGHFP_INTERNAL_VOICE_RECOGNITION); 
                message->enable = enable;
                MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_VOICE_RECOGNITION, message);
            }
            inst++;
        }
    }
}


/****************************************************************************
NAME    
    aghfp_host_set_call_state - 

DESCRIPTION
   -  Sets the call state of the AG Host

RETURNS
    void
*/
void aghfp_host_set_call_state(aghfp_call_status status)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    aghfp_call_status old_call_state = AGHFP_RUNDATA.aghost_state.call_status;
    
    AGHFP_RUNDATA.aghost_state.call_status = status;
    AGHFP_DEBUG(("AGHFP: Host call state [%d]\n", status));
    
    if (inst != NULL && (AGHFP_RUNDATA.aghost_state.call_status != old_call_state))
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {                       
                MessageCancelFirst(&inst->aghfpTask, AGHFP_INTERNAL_RING_ALERT);
                AghfpSendCallIndicator(AGHFP_RUNDATA.aghfp, AGHFP_RUNDATA.aghost_state.call_status);
            }
            inst++;
        }
    }
    aghfp_host_clear_ring_indication();
}


/****************************************************************************
NAME    
    aghfp_host_set_call_setup_state -

DESCRIPTION
   -   Sets the call setup state of the AG Host

RETURNS
    void
*/
void aghfp_host_set_call_setup_state(aghfp_call_setup_status status)

{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    aghfp_call_setup_status old_setup_state = AGHFP_RUNDATA.aghost_state.call_setup_status;
    
    AGHFP_RUNDATA.aghost_state.call_setup_status = status;
    AGHFP_DEBUG(("AGHFP: Host call setup state [%d]\n", status));
    
    if (inst != NULL && (AGHFP_RUNDATA.aghost_state.call_setup_status != old_setup_state))
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {                       
                if (AGHFP_RUNDATA.aghost_state.call_setup_status == aghfp_call_setup_incoming)
                {                                        
                    if (AGHFP_RUNDATA.aghost_state.call_status == aghfp_call_active)
                    {
                        if (AGHFP_RUNDATA.aghost_state.ring)
                        {
                            AghfpSendCallWaitingNotification(AGHFP_RUNDATA.aghfp,
                                                             AGHFP_RUNDATA.aghost_state.ring->clip_type, 
                                                             AGHFP_RUNDATA.aghost_state.ring->size_clip_number, 
                                                             AGHFP_RUNDATA.aghost_state.ring->clip_number, 
                                                             0, 
                                                             NULL);
                        }
                        else
                        {
                            AghfpSendCallWaitingNotification(AGHFP_RUNDATA.aghfp,
                                                             0, 
                                                             0, 
                                                             0, 
                                                             0, 
                                                             NULL);
                        }
                    }
                    else
                    {
                        MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_RING_ALERT, 0); 
                    }
                }
                
                AghfpSendCallSetupIndicator(AGHFP_RUNDATA.aghfp, AGHFP_RUNDATA.aghost_state.call_setup_status);
            }
            inst++;
        }
    }    
}


/****************************************************************************
NAME    
    aghfp_host_set_call_held_state - 

DESCRIPTION
   -  Sets the call held state of the AG Host

RETURNS
    void
*/
void aghfp_host_set_call_held_state(aghfp_call_held_status status)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;
    aghfp_call_held_status old_held_state = AGHFP_RUNDATA.aghost_state.call_held_status;
    
    AGHFP_RUNDATA.aghost_state.call_held_status = status;
    AGHFP_DEBUG(("AGHFP: Host call held state [%d]\n", status));
    
    if (inst != NULL && (AGHFP_RUNDATA.aghost_state.call_held_status != old_held_state))
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {                       
                AghfpSendCallHeldIndicator(AGHFP_RUNDATA.aghfp, AGHFP_RUNDATA.aghost_state.call_held_status);
            }
            inst++;
        }
    }        
}


/****************************************************************************
NAME    
    aghfp_host_set_signal_strength -

DESCRIPTION
   -   Sets the signal strength of the AG Host

RETURNS
    void
*/
void aghfp_host_set_signal_strength(uint8 signal_strength)
{
    AGHFP_RUNDATA.aghost_state.signal = signal_strength;
    AGHFP_DEBUG(("AGHFP: Host signal strength [%d]\n", signal_strength));
}


/****************************************************************************
NAME    
    aghfp_host_set_battery_level - 

DESCRIPTION
   -   Sets the battery level of the AG Host

RETURNS
    void
*/
void aghfp_host_set_battery_level(uint8 battery_level)
{
    AGHFP_RUNDATA.aghost_state.batt = battery_level;
    AGHFP_DEBUG(("AGHFP: Host battery level [%d]\n", battery_level));
}


/****************************************************************************
NAME    
    aghfp_host_set_roam_status - 

DESCRIPTION
   -   Sets the roam status of the AG Host

RETURNS
    void
*/
void aghfp_host_set_roam_status(aghfp_roam_status roam_status)
{
    AGHFP_RUNDATA.aghost_state.roam_status = roam_status;
    AGHFP_DEBUG(("AGHFP: Host roam status [%d]\n", roam_status));
}


/****************************************************************************
NAME    
    aghfp_host_set_network_availability - 

DESCRIPTION
   -   Sets the network availability of the AG Host.

RETURNS
    void
*/
void aghfp_host_set_network_availability(aghfp_service_availability availability)
{
    AGHFP_RUNDATA.aghost_state.availability = availability;
    AGHFP_DEBUG(("AGHFP: Host network availability [%d]\n", availability));
}


/****************************************************************************
NAME    
    aghfp_host_set_network_operator - 

DESCRIPTION
   -   Sets the network operator name of the AG Host

RETURNS
    void
*/
void aghfp_host_set_network_operator(uint16 size_name, const uint8 *name)
{
    uint16 index;
    
    if (size_name > AGHOST_MAX_NETWORK_OPERATOR_CHARACTERS)
    {
        size_name = AGHOST_MAX_NETWORK_OPERATOR_CHARACTERS;
    }
    
    for (index = 0; index < size_name; index++)
    {
        AGHFP_RUNDATA.aghost_state.network_operator[index] = name[index];
    }
    AGHFP_RUNDATA.aghost_state.size_network_operator = size_name;
    
#ifdef DEBUG_AGHFP    
    AGHFP_DEBUG(("AGHFP: Host network operator size [%d] name [", size_name));
    for (index = 0; index < size_name; index++)
    {
        AGHFP_DEBUG(("%c",AGHFP_RUNDATA.aghost_state.network_operator[index]));
    }
    AGHFP_DEBUG(("]\n"));
#endif
    
}


/****************************************************************************
NAME    
    aghfp_host_set_ring_indication - 

DESCRIPTION
   -   Stores the data associated with a RING indication

RETURNS
    void
*/
void aghfp_host_set_ring_indication(uint8 clip_type, uint8 size_clip_number, const uint8 *clip_number)
{
    uint16 index = 0;
    
    aghfp_host_clear_ring_indication();
   
    AGHFP_RUNDATA.aghost_state.ring = memory_create(sizeof(AGHFP_RING_ALERT_T) + size_clip_number);       
    
    AGHFP_RUNDATA.aghost_state.ring->clip_type = clip_type;
    AGHFP_RUNDATA.aghost_state.ring->size_clip_number = size_clip_number;
    
    AGHFP_DEBUG(("AGHFP: Ring Indication Set type[%d] size_no[%d]\n", clip_type, size_clip_number));
    
    for (index = 0; index < size_clip_number; index++)
    {
        AGHFP_RUNDATA.aghost_state.ring->clip_number[index] = clip_number[index];
    }
}


/****************************************************************************
NAME    
    aghfp_host_clear_ring_indication - 

DESCRIPTION
   -  Frees the data associated with a RING indication

RETURNS
    void
*/
void aghfp_host_clear_ring_indication(void)
{
    if (AGHFP_RUNDATA.aghost_state.ring)
    {
        free(AGHFP_RUNDATA.aghost_state.ring);
        AGHFP_RUNDATA.aghost_state.ring = 0;
        
        AGHFP_DEBUG(("AGHFP: Ring Indication Cleared\n"));
    }
}


/****************************************************************************
NAME    
    aghfp_store_warp_values - 

DESCRIPTION
   -  Stores the warp values for the current AGHFP audio connection    

RETURNS
    void
*/
void aghfp_store_warp_values(uint16 number_warp_values, uint16 *warp)
{
    uint16 index = 0;
    uint16 i = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;    
        
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                /* send message to update attributes in PS */
                MAKE_MESSAGE(APP_STORE_DEVICE_ATTRIBUTES);
                message->addr = inst->addr;
                for (i = 0; i < number_warp_values; i++)
                {
                    message->attributes.warp[i] = warp[i];
                    /* store the values locally */
                    inst->warp[i] = warp[i];
                }
                /* Get other device attributes before storing device attributes */
                message->attributes.mode = inst->source_link_mode;
    	        message->attributes.unused = 0;

                MessageSend(app_get_instance(), APP_STORE_DEVICE_ATTRIBUTES, message);
            }
            inst++;
        }
    }
}


/****************************************************************************
NAME    
    aghfp_send_audio_params - 

DESCRIPTION
   -  Sends the audio params to the AGHFP library for the current AGHFP audio connections

RETURNS
    void
*/
void aghfp_send_audio_params(void)
{
    uint16 index = 0;
    aghfpInstance *inst = AGHFP_RUNDATA.inst;    
        
    if (inst != NULL)
    {
        for_all_aghfp_instance(index)
        {
            if (aghfp_is_connected(inst->aghfp_state))
            {
                /* remote side has initiated audio connection by sending AT+BCC */
                aghfp_set_state(inst, AGHFP_STATE_CONNECTING_AUDIO_REMOTE);
                AghfpSetAudioParams(inst->aghfp, aghfp_source_data_get_syncpkt_types(), aghfp_source_data_get_audio_plugin_params());
            }
            inst++;
        }
    }
}


/****************************************************************************
NAME    
    aghfp_exit_state - 

DESCRIPTION
   - Exits an AGHFP state

RETURNS
    void
*/
static void aghfp_exit_state(aghfpInstance *inst)
{
    switch (aghfp_get_state(inst))
    {     
        case AGHFP_STATE_DISCONNECTED:
        {
            aghfp_exit_state_disconnected(inst);
        }
        break;
        
        case AGHFP_STATE_CONNECTING_LOCAL:
        {
            aghfp_exit_state_connecting_local(inst);
        }
        break;
        
        case AGHFP_STATE_CONNECTING_REMOTE:
        {
            aghfp_exit_state_connecting_remote(inst);
        }
        break;
        
        case AGHFP_STATE_CONNECTED:
        {
            aghfp_exit_state_connected(inst);
        }
        break;
        
        case AGHFP_STATE_CONNECTING_AUDIO_LOCAL:
        {
            aghfp_exit_state_connecting_audio_local(inst);
        }
        break;
        
        case AGHFP_STATE_CONNECTING_AUDIO_REMOTE:
        {
            aghfp_exit_state_connecting_audio_remote(inst);
        }
        break;
        
        case AGHFP_STATE_CONNECTED_AUDIO:
        {
            aghfp_exit_state_connected_audio(inst);
        }
        break;
        
        case AGHFP_STATE_DISCONNECTING_AUDIO:
        {
            aghfp_exit_state_disconnecting_audio(inst);
        }
        break;
        
        case AGHFP_STATE_DISCONNECTING:
        {
            aghfp_exit_state_disconnecting(inst);
        }
        break;
        
        default:
        {
            aghfp_unhandled_state(inst);
        }
        break;
    }
}


/****************************************************************************
NAME    
    aghfp_exit_state_disconnected - 

DESCRIPTION
   - Called on exiting the AGHFP_STATE_DISCONNECTED state

RETURNS
    void
*/
static void aghfp_exit_state_disconnected(aghfpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    aghfp_exit_state_connecting_local - 

DESCRIPTION
   - Called on exiting the AGHFP_STATE_CONNECTING_LOCAL state

RETURNS
    void
*/
static void aghfp_exit_state_connecting_local(aghfpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    aghfp_exit_state_connecting_remote -

DESCRIPTION
   -  Called on exiting the AGHFP_STATE_CONNECTING_REMOTE state

RETURNS
    void
*/
static void aghfp_exit_state_connecting_remote(aghfpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    aghfp_exit_state_connected - 

DESCRIPTION
   - Called on exiting the AGHFP_STATE_CONNECTED state

RETURNS
    void
*/
static void aghfp_exit_state_connected(aghfpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    aghfp_exit_state_connecting_audio_local - 

DESCRIPTION
   - Called on exiting the AGHFP_STATE_CONNECTING_AUDIO_LOCAL state

RETURNS
    void
*/
static void aghfp_exit_state_connecting_audio_local(aghfpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    aghfp_exit_state_connecting_audio_remote - 

DESCRIPTION
   -Called on exiting the AGHFP_STATE_CONNECTING_AUDIO_REMOTE state

RETURNS
    void
*/
static void aghfp_exit_state_connecting_audio_remote(aghfpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    aghfp_exit_state_connected_audio - 

DESCRIPTION
   -Called on exiting the AGHFP_STATE_CONNECTED_AUDIO state

RETURNS
    void
*/
static void aghfp_exit_state_connected_audio(aghfpInstance *inst)
{
    /* disconnect any AGHFP audio */
    audio_aghfp_disconnect();
}


/****************************************************************************
NAME    
    aghfp_exit_state_disconnecting_audio -

DESCRIPTION
   Called on exiting the AGHFP_STATE_DISCONNECTING_AUDIO state

RETURNS
    void
*/
static void aghfp_exit_state_disconnecting_audio(aghfpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    aghfp_exit_state_disconnecting - 

DESCRIPTION
   Called on exiting the AGHFP_STATE_DISCONNECTING state

RETURNS
    void
*/
static void aghfp_exit_state_disconnecting(aghfpInstance *inst)
{
    
}
        

/****************************************************************************
NAME    
    aghfp_enter_state -

DESCRIPTION
    Enters an AGHFP state

RETURNS
    void
*/
static void aghfp_enter_state(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    switch (aghfp_get_state(inst))
    {
        case AGHFP_STATE_DISCONNECTED:
        {
            aghfp_enter_state_disconnected(inst, old_state);
        }
        break;
        
        case AGHFP_STATE_CONNECTING_LOCAL:
        {
            aghfp_enter_state_connecting_local(inst, old_state);
        }
        break;
        
        case AGHFP_STATE_CONNECTING_REMOTE:
        {
            aghfp_enter_state_connecting_remote(inst, old_state);
        }
        break;
        
        case AGHFP_STATE_CONNECTED:
        {
            aghfp_enter_state_connected(inst, old_state);
        }
        break;
        
        case AGHFP_STATE_CONNECTING_AUDIO_LOCAL:
        {
            aghfp_enter_state_connecting_audio_local(inst, old_state);
        }
        break;
        
        case AGHFP_STATE_CONNECTING_AUDIO_REMOTE:
        {
            aghfp_enter_state_connecting_audio_remote(inst, old_state);
        }
        break;
        
        case AGHFP_STATE_CONNECTED_AUDIO:
        {
            aghfp_enter_state_connected_audio(inst, old_state);
        }
        break;
        
        case AGHFP_STATE_DISCONNECTING_AUDIO:
        {
            aghfp_enter_state_disconnecting_audio(inst, old_state);
        }
        break;
        
        case AGHFP_STATE_DISCONNECTING:
        {
            aghfp_enter_state_disconnecting(inst, old_state);
        }
        break;
        
        default:
        {
            aghfp_unhandled_state(inst);
        }
        break;
    }
}


/****************************************************************************
NAME    
    aghfp_enter_state_disconnected - 

DESCRIPTION
    Called on entering the AGHFP_STATE_DISCONNECTED state

RETURNS
    void
*/
static void aghfp_enter_state_disconnected(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    ATTRIBUTES_T attributes;
    if (aghfp_is_connected(old_state))
    {
        uint16 i = 0;
        /* update attributes on a disconnection */
        MAKE_MESSAGE(APP_STORE_DEVICE_ATTRIBUTES);
        message->addr = inst->addr;
        for (i = 0; i < CSR_AG_AUDIO_WARP_NUMBER_VALUES; i++)
        {
            message->attributes.warp[i] = inst->warp[i];
        }

        /* Get other device attributes before storing device attributes */
        message->attributes.mode = inst->source_link_mode;
        message->attributes.unused = 0;

        /* Get the attributes for bd_addr for remote name and then update the link mode for the bd_addr */
        ConnectionSmGetAttributeNow(0, &inst->addr, sizeof(ATTRIBUTES_T), (uint8*)&attributes);
		
        message->attributes.remote_name_size = attributes.remote_name_size;		
        memset(message->attributes.remote_name, 0, MAX_REMOTE_DEVICE_NAME_LEN);
        memmove(message->attributes.remote_name,attributes.remote_name, attributes.remote_name_size);       
		
        MessageSend(app_get_instance(), APP_STORE_DEVICE_ATTRIBUTES, message);
        
        /* send message that has disconnection has occurred */    
        MessageSend(app_get_instance(), APP_DISCONNECT_IND, 0); 
        /* cancel any audio connect requests */
        MessageCancelAll(&inst->aghfpTask, AGHFP_INTERNAL_CONNECT_AUDIO_REQ);
        /* reset audio delay flag */
        audio_set_aghfp_conn_delay(FALSE);
        
        /* attempt to switch audio mode and end any active call */
        aghfp_music_mode_end_call();
    }
}


/****************************************************************************
NAME    
    aghfp_enter_state_connecting_local - 

DESCRIPTION
    Called on entering the AGHFP_STATE_CONNECTING_LOCAL state

RETURNS
    void
*/
static void aghfp_enter_state_connecting_local(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    AghfpSlcConnect(inst->aghfp, &inst->addr);
}


/****************************************************************************
NAME    
    aghfp_enter_state_connecting_remote - 

DESCRIPTION
    Called on entering the AGHFP_STATE_CONNECTING_REMOTE state

RETURNS
    void
*/
static void aghfp_enter_state_connecting_remote(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    
}


/****************************************************************************
NAME    
    aghfp_enter_state_connected - 

DESCRIPTION
    Called on entering the AGHFP_STATE_CONNECTED state

RETURNS
    void
*/
static void aghfp_enter_state_connected(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    if ((old_state == AGHFP_STATE_CONNECTING_LOCAL) || (old_state == AGHFP_STATE_CONNECTING_REMOTE))
    {                              
        ATTRIBUTES_T attributes;
        
        /* store current device to PS */   
        connection_mgr_write_new_remote_device(&inst->addr, PROFILE_AGHFP);
        
        /* clear forced inquiry mode flag as is now connected to a device */
        inquiry_set_forced_inquiry_mode(FALSE);
        
        /* send message that has connection has occurred */    
        MessageSend(app_get_instance(), APP_CONNECT_SUCCESS_CFM, 0); 
        
        /* register connection with connection manager */
        connection_mgr_set_profile_connected(PROFILE_AGHFP, &inst->addr);
        
        /* Retrieve the role of this device */
        ConnectionGetRole(connection_mgr_get_instance(), inst->slc_sink);
        
        /* Retrieve the device attributes */
        if (ConnectionSmGetAttributeNow(0, &inst->addr, sizeof(ATTRIBUTES_T), (uint8*)&attributes))
        {
            uint16 i = 0;
            /* Store locally the attributes that were read */
            for (i = 0; i < CSR_AG_AUDIO_WARP_NUMBER_VALUES; i++)
            {
                inst->warp[i] = attributes.warp[i];
            }
            inst->source_link_mode = attributes.mode;
        }
        else
        {
            /* Clear values as they couldn't be read from PS */
            inst->warp[0] = 0;
            inst->warp[1] = 0;
            inst->warp[2] = 0;
            inst->warp[3] = 0;
            inst->source_link_mode = source_no_secure_connection;
			
        }

        /* reset connection attempts */
        inst->aghfp_connection_retries = 0;
        
        /* send audio volumes over AGHFP */
        aghfp_send_source_volume(inst);
        
        /* for remote connections need to record that locally initiated audio connection 
            should be delayed incase remote end wants to initiate audio */
        if (old_state == AGHFP_STATE_CONNECTING_REMOTE)
        {
            audio_set_aghfp_conn_delay(TRUE);
        }
        
        /* send RING alert on connection if there is an incoming call */
        if (AGHFP_RUNDATA.aghost_state.call_setup_status == aghfp_call_setup_incoming)
        {
            MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_RING_ALERT, 0);
        }
    }
    else if ((old_state == AGHFP_STATE_CONNECTING_AUDIO_LOCAL) || 
             ((old_state == AGHFP_STATE_CONNECTING_AUDIO_REMOTE) && (usb_get_hid_mode() != USB_HID_MODE_HOST))) /* Qual test TC_AG_ACS_BI_14_I doesn't want dongle to reconnect eSCO after a rejection */
    {
        /* try audio connection again after the PS delay */
        if (inst->aghfp_connection_retries < aghfp_get_max_connection_retries())
        {
            inst->aghfp_connection_retries++;
            
            MessageSendLater(&inst->aghfpTask, AGHFP_INTERNAL_CONNECT_AUDIO_REQ, 0,connection_mgr_get_audio_delay_timer());  
        }
        else
        {
            /* send message to disconnect as audio connection can't be made */    
            MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_DISCONNECT_REQ, 0);
        }
    }
    else if ((old_state == AGHFP_STATE_DISCONNECTING_AUDIO) || (old_state == AGHFP_STATE_CONNECTED_AUDIO))
    {
        /* try a resume of A2DP audio after AGHFP audio has been removed */
        a2dp_resume_audio();
    }
    
    /* no audio connecting / disconnecting at this point */
    inst->connecting_audio = 0;
    inst->disconnecting_audio = 0;   
}


/****************************************************************************
NAME    
    aghfp_enter_state_connecting_audio_local - 

DESCRIPTION
   Called on entering the AGHFP_STATE_CONNECTING_AUDIO_LOCAL state

RETURNS
    void
*/
static void aghfp_enter_state_connecting_audio_local(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    sync_pkt_type packet_type;
    aghfp_audio_params  ag_audio_params;
    inst->connecting_audio = 1;

    if(inst->use_negotiated_codec)
    {
        /* Get negotiated audio params from AGHFP library, if not obtained ignore */
        if (AghfpGetNegotiatedAudioParams(inst->aghfp, &packet_type, &ag_audio_params))
        {
           /* Send Audio Connect request with negotiated params */
           AghfpAudioConnect(inst->aghfp, packet_type, &ag_audio_params);
        }
    }
    else
    {
        AghfpAudioConnect(inst->aghfp,aghfp_source_data_get_syncpkt_types(),aghfp_source_data_get_audio_plugin_params());
    }
}


/****************************************************************************
NAME    
    aghfp_enter_state_connecting_audio_remote -

DESCRIPTION
    Called on entering the AGHFP_STATE_CONNECTING_AUDIO_REMOTE state

RETURNS
    void
*/
static void aghfp_enter_state_connecting_audio_remote(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    inst->connecting_audio = 1;
}


/****************************************************************************
NAME    
    aghfp_enter_state_disconnecting_audio - 

DESCRIPTION
    Called on entering the AGHFP_STATE_DISCONNECTING_AUDIO state

RETURNS
    void
*/
static void aghfp_enter_state_disconnecting_audio(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    inst->disconnecting_audio = 1;
    
    AghfpAudioDisconnect(inst->aghfp);
}


/****************************************************************************
NAME    
    aghfp_enter_state_disconnecting -

DESCRIPTION
    Called on entering the AGHFP_STATE_DISCONNECTING state

RETURNS
    void
*/
static void aghfp_enter_state_disconnecting(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    AghfpSlcDisconnect(inst->aghfp);
}


/****************************************************************************
NAME    
    aghfp_set_remote_volume - 

DESCRIPTION
    Sets the remote volume

RETURNS
    void
*/
static void aghfp_set_remote_volume(AGHFP *aghfp)
{
    AghfpSetRemoteSpeakerVolume(aghfp, volume_get_speaker_volume());
    AghfpSetRemoteMicrophoneGain(aghfp, volume_get_mic_volume());
}


/****************************************************************************
NAME    
    aghfp_enter_state_connected_audio

DESCRIPTION
    Function which is called when the connected audio state is entered.

RETURNS
    void

*/
void aghfp_enter_state_connected_audio(aghfpInstance *inst, AGHFP_STATE_T old_state)
{
    if (inst->audio_sink)
    {
        /* Disconnect all A2DP audio if it is routed */
        audio_a2dp_disconnect_all();
        
        if ((old_state == AGHFP_STATE_CONNECTING_AUDIO_REMOTE) && (audio_get_voip_music_mode() == AUDIO_MUSIC_MODE))
        {
            /* switch to VOIP mode from MUSIC mode as the remote side has initiated the audio */
            audio_set_voip_music_mode(AUDIO_VOIP_MODE);
        }
        
        if (audio_get_voip_music_mode() == AUDIO_VOIP_MODE)
        {                    
            if (states_get_state() == SOURCE_STATE_CONNECTED)
            {
                /* suspend A2DP stream */
                a2dp_suspend_all_audio();
                
                /* connect new audio */
                audio_aghfp_connect(inst->audio_sink, (inst->link_type == sync_link_esco) ? TRUE : FALSE, inst->using_wbs, CSR_AG_AUDIO_WARP_NUMBER_VALUES, inst->warp);
            
                /* set sniff mode if PS Key has been read */
                if (power_get_aghfp_number_of_entries() && power_get_aghfp_power_table())
                {
                    ConnectionSetLinkPolicy(inst->audio_sink, power_get_aghfp_number_of_entries() ,power_get_aghfp_power_table());
                }
            }
            else
            {
                /* if not connected then remove audio */
                MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_DISCONNECT_AUDIO_REQ, 0);
            }        
        }
        else
        {
            /* VOIP mode not active so suspend AGHFP audio */
            MessageSend(&inst->aghfpTask, AGHFP_INTERNAL_DISCONNECT_AUDIO_REQ, 0);
        }
    }
    
    /* reset connection attempts */
    inst->aghfp_connection_retries = 0;
    
    /* no longer connecting audio */
    inst->connecting_audio = 0;
}
/****************************************************************************
NAME    
    aghfp_get_state_avialability -

DESCRIPTION
     Returns the aghfp state availability param.

RETURNS
    The value of Service indicator parameter.
*/
aghfp_service_availability aghfp_get_state_avialability(void)
{
    return AGHFP_RUNDATA.aghost_state.availability;
}
/****************************************************************************
NAME    
    aghfp_get_state_call_status -

DESCRIPTION
      Returns the aghfp state call status.

RETURNS
    The value of call  indicator parameter.
*/
aghfp_call_status aghfp_get_state_call_status(void)
{
    return AGHFP_RUNDATA.aghost_state.call_status;
}
/****************************************************************************
NAME    
    aghfp_get_state_call_status - 

DESCRIPTION
      Returns the aghfp state call setup status.

RETURNS
    The current value of call setup indicator parameter.
*/
aghfp_call_setup_status aghfp_get_state_call_setup_status(void)
{
    return AGHFP_RUNDATA.aghost_state.call_setup_status;
}
/****************************************************************************
NAME    
    aghfp_get_state_call_held_status -

DESCRIPTION
       Returns the aghfp state call held status.

RETURNS
    The value of the call held indicator parameter 
*/
aghfp_call_held_status aghfp_get_state_call_held_status(void)
{
    return AGHFP_RUNDATA.aghost_state.call_held_status;
}
/****************************************************************************
NAME    
    aghfp_get_state_signal -

DESCRIPTION
        Returns the aghfp state signal param.

RETURNS
    The value of the structure variable 'signal' 
*/
uint16 aghfp_get_state_signal(void)
{
    return AGHFP_RUNDATA.aghost_state.signal;
}
/****************************************************************************
NAME    
    aghfp_get_state_roam_status - 

DESCRIPTION
    Returns the aghfp state roam status.

RETURNS
    The current roaming state if active or not.Iff active , roam_status = aghfp_roam_active else  aghfp_roam_none.
*/
aghfp_roam_status aghfp_get_state_roam_status(void)
{
    return AGHFP_RUNDATA.aghost_state.roam_status;
}
/****************************************************************************
NAME    
    aghfp_get_state_batt_val - 

DESCRIPTION
    Returns the aghfp state batt level

RETURNS
    The value of the structure variable 'batt.'
*/
uint16 aghfp_get_state_batt_val(void)
{
    return AGHFP_RUNDATA.aghost_state.batt;
}
/****************************************************************************
NAME    
    aghfp_get_hf_indicator_state -

DESCRIPTION
     Returns the hf indicator state.

RETURNS
    The value of the structure variable hf_indicators_state.
*/
uint16 aghfp_get_hf_indicator_state(void)
{
    return AGHFP_RUNDATA.aghost_state.hf_indicator_info.hf_indicators_state;
}
/****************************************************************************
NAME    
    aghfp_get_hf_indicator_state - 

DESCRIPTION
     Returns the hf indicator state.

RETURNS
    void
*/
void  aghfp_set_instance(AGHFP *aghfp)
{
    AGHFP_RUNDATA.aghfp = aghfp;
}
/****************************************************************************
NAME    
    aghfp_get_hf_indicator_state -

DESCRIPTION
      Returns the hf indicator state.

RETURNS
    The instance of the stucture AGHFP.
*/
AGHFP *aghfp_get_instance(void)
{
    return AGHFP_RUNDATA.aghfp;
}
/****************************************************************************
NAME    
    aghfp_get_active_hf_indicator - 

DESCRIPTION
    Returns the active hf indicator state.

RETURNS
    The  variable of the structure type aghfp_hf_indicators_mask. 
*/
aghfp_hf_indicators_mask aghfp_get_active_hf_indicator(void)
{
    return  AGHFP_RUNDATA.aghost_state.hf_indicator_info.active_hf_indicators;
}
/****************************************************************************
NAME    
    aghfp_get_hf_indicator_state - 

DESCRIPTION
    Returns the hf indicator state.

RETURNS
    The instance of the structure AGHFP_RING_ALERT_T.
*/
AGHFP_RING_ALERT_T *aghfp_get_state_ring(void)
{
    return AGHFP_RUNDATA.aghost_state.ring;
}
/****************************************************************************
NAME    
    aghfp_get_state_ring_cliptype - 

DESCRIPTION
    Returns the aghfp state ring clip type .

RETURNS
    The value of the structure variable 'clip_type'.
*/
uint8 aghfp_get_state_ring_cliptype(void)
{
    return AGHFP_RUNDATA.aghost_state.ring->clip_type;
}
/****************************************************************************
NAME    
    aghfp_get_state_ring_cliptype - 

DESCRIPTION
    Returns the aghfp state ring clip number .

RETURNS
     pointer to the array 'clip_number'
*/
uint8 *aghfp_get_state_ring_clipnumber(void)
{
    return &AGHFP_RUNDATA.aghost_state.ring->clip_number[0];
}
/****************************************************************************
NAME    
    aghfp_get_state_ring_cliptype - 

DESCRIPTION
    Returns the aghfp state ring size clip number .

RETURNS
    The value of the structure variable 'size_clip_number'.
*/
uint8 aghfp_get_state_ring_size_clipnumber(void)
{
    return AGHFP_RUNDATA.aghost_state.ring->size_clip_number;
}
/****************************************************************************
NAME    
    aghfp_get_size_network_operator -

DESCRIPTION
    Returns the agfhp size network operator.

RETURNS
    The value of the structure variable 'size_network_operator'.
*/
uint16 aghfp_get_size_network_operator(void)
{
    return AGHFP_RUNDATA.aghost_state.size_network_operator;
}
/****************************************************************************
NAME    
    aghfp_get_size_network_operator - 

DESCRIPTION
    Returns the agfhp size network operator.

RETURNS
    pointer to the array 'network_operator'
*/
uint8 *aghfp_get_network_operator_instance(void)
{
    return AGHFP_RUNDATA.aghost_state.network_operator;
}
/*************************************************************************
NAME
    aghfp_source_init_globaldata

DESCRIPTION
    Function to Initialise the AGHfp configuration data into a structure member of AGHFP_RUNDATA.

RETURNS
    void

*****************************************************************************/
void aghfp_source_init_globaldata(source_aghfp_data_readonly_config_def_t *hfp_config_data)
{
    if(hfp_config_data != NULL)
    {
        aghfp_source_data_create_syncpkt_types();
        AGHFP_RUNDATA.gHfpSrcData.audio_params.bandwidth = PACK_32(hfp_config_data->hfp_initial_parameters.audio_params.bandwidth_low,hfp_config_data->hfp_initial_parameters.audio_params.bandwidth_high);
        AGHFP_RUNDATA.gHfpSrcData.audio_params.max_latency= hfp_config_data->hfp_initial_parameters.audio_params.max_latency;
        AGHFP_RUNDATA.gHfpSrcData.audio_params.retx_effort = hfp_config_data->hfp_initial_parameters.audio_params.retransmission_effort;
        AGHFP_RUNDATA.gHfpSrcData.audio_params.voice_settings = hfp_config_data->hfp_initial_parameters.audio_params.voice_settings;
        AGHFP_RUNDATA.gHfpSrcData.audio_params.override_wbs= hfp_config_data->hfp_initial_parameters.audio_params.hfpAudioOverrideWideBandSpeech;
        AGHFP_RUNDATA.gHfpSrcData.sync_pkt_types = aghfp_source_data_get_syncpkt_types();
    }
}
/*************************************************************************
NAME
    aghfp_source_data_get_audio_plugin_params

DESCRIPTION
     Reads the audio params used by aghfp.

RETURNS
    Pointer to  aghfp_audio_params.

***************************************************************************/
aghfp_audio_params *  aghfp_source_data_get_audio_plugin_params(void)
{
    return &AGHFP_RUNDATA.gHfpSrcData.audio_params;
}

