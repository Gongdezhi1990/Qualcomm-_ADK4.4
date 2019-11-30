/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_connection_msg_handler.c

DESCRIPTION
    Connection library message handling.
    
*/


/* header for this file */
#include "source_connection_msg_handler.h"
/* application header files */
#include "source_app_msg_handler.h"
#include "source_connection_mgr.h"
#include "source_debug.h"
#include "source_init.h"
#include "source_inquiry.h"
#include "source_private.h"
#include "source_sc.h"
#include "source_a2dp.h"
/* profile/library headers */
#include <connection.h>
/* VM headers */
#include <panic.h>
#include <ps.h>

#include <Source_aghfp_data.h>

#ifdef DEBUG_CL_MSG
    #define CL_MSG_DEBUG(x) DEBUG(x)
#else
    #define CL_MSG_DEBUG(x)
#endif


/* local functions */
static void connection_msg_pin_code_ind(const CL_SM_PIN_CODE_IND_T* ind);
static void connection_msg_io_capability_ind(const CL_SM_IO_CAPABILITY_REQ_IND_T* ind);
static void connection_msg_authorise_ind(const CL_SM_AUTHORISE_IND_T *ind);
static void connection_msg_authorise_cfm(const CL_SM_AUTHENTICATE_CFM_T *cfm);
static void connection_msg_remote_name_complete(const CL_DM_REMOTE_NAME_COMPLETE_T *cfm);
static void connection_msg_handle_role_cfm(const CL_DM_ROLE_CFM_T *cfm);


/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    connection_msg_handler - Handles Connection library messages
*/  
void connection_msg_handler(Task task, MessageId id, Message message)
{
    switch(id)
    {        
        /* confirmation of Connection library initialisation completed */
        case CL_INIT_CFM:
        {
            CL_MSG_DEBUG(("CL_INIT_CFM [%d]\n", ((CL_INIT_CFM_T *)message)->status));
            if (((CL_INIT_CFM_T *)message)->status == success)
            {                
                /* Configure Mode4 Security Settings */
                ConnectionSmSecModeConfig(connection_mgr_get_instance(), cl_sm_wae_acl_owner_none, FALSE, TRUE);
                
                /* Turn off all SDP security */
                ConnectionSmSetSecurityLevel(protocol_l2cap, 1, ssp_secl4_l0, TRUE, FALSE, FALSE);
                
                /* EIR inquiry mode */
                ConnectionWriteInquiryMode(connection_mgr_get_instance(), inquiry_mode_eir);
                
                /* Indicate Connection library is initialised */
                init_register_profiles(REGISTERED_PROFILE_CL);
            }
            else
            {
                Panic();
            }
        }
        break;
        
        /* confirmation of Writing Inquiry Mode */
        case CL_DM_WRITE_INQUIRY_MODE_CFM:
        {
            CL_MSG_DEBUG(("CL_DM_WRITE_INQUIRY_MODE_CFM [%d]\n", ((CL_DM_WRITE_INQUIRY_MODE_CFM_T *)message)->status));
            /* Read the local name to put in our EIR data */
            ConnectionReadInquiryTx(connection_mgr_get_instance());
        }
        break;
        
        /* confirmation of Reading Inquiry Tx */
        case CL_DM_READ_INQUIRY_TX_CFM:
        {
            CL_MSG_DEBUG(("CL_DM_READ_INQUIRY_TX_CFM [%d]\n", ((CL_DM_READ_INQUIRY_TX_CFM_T *)message)->status));
            inquiry_set_inquiry_tx(((CL_DM_READ_INQUIRY_TX_CFM_T *)message)->tx_power);
            ConnectionReadLocalName(connection_mgr_get_instance());
        }
        break;
        
        /* confirmation of Reading local name */
        case CL_DM_LOCAL_NAME_COMPLETE:
        {
            CL_MSG_DEBUG(("CL_DM_LOCAL_NAME_COMPLETE\n"));
            /* Write EIR data and initialise the codec task */
            inquiry_write_eir_data((CL_DM_LOCAL_NAME_COMPLETE_T *)message);
        }
        break;
        
        /* confirmation of setting Security Mode */
        case CL_SM_SEC_MODE_CONFIG_CFM:
        {
            CL_MSG_DEBUG(("CL_SM_SEC_MODE_CONFIG_CFM\n"));
        }
        break;
        
        /* indication that the PIN Code has been requested */
        case CL_SM_PIN_CODE_IND:
        {    
            CL_MSG_DEBUG(("CL_SM_PIN_IND\n"));
            connection_msg_pin_code_ind((CL_SM_PIN_CODE_IND_T *)message);
        }
        break;
               
        /* indication that the IO capabilities have been requested */
        case CL_SM_IO_CAPABILITY_REQ_IND:
        {
            CL_MSG_DEBUG(("CL_SM_IO_CAPABILITY_REQ_IND\n"));
            connection_msg_io_capability_ind((CL_SM_IO_CAPABILITY_REQ_IND_T*) message);
        }
        break;
        
        /* indication of the remote IO capabilities */
        case CL_SM_REMOTE_IO_CAPABILITY_IND:
        {
            CL_MSG_DEBUG(("CL_SM_REMOTE_IO_CAPABILITY_IND\n"));                        
        }
        break;
        
        /* indication that the remote device needs authorisation */
        case CL_SM_AUTHORISE_IND:
        {
            CL_MSG_DEBUG(("CL_SM_AUTHORISE_IND\n"));
            connection_msg_authorise_ind((CL_SM_AUTHORISE_IND_T*) message);
        }
        break;            
        
        /* confirmation that the remote device has been authenticated */
        case CL_SM_AUTHENTICATE_CFM:
        {
            CL_MSG_DEBUG(("CL_SM_AUTHENTICATE_CFM\n"));
            connection_msg_authorise_cfm((CL_SM_AUTHENTICATE_CFM_T*) message);
        }
        break;           
        
        /* confirmation of the remote features */
        case CL_DM_REMOTE_FEATURES_CFM:
        {
            CL_MSG_DEBUG(("CL_DM_REMOTE_FEATURES_CFM\n"));
        }
        break;
        
        /* message containing an inquiry result */
        case CL_DM_INQUIRE_RESULT:
        {
            CL_MSG_DEBUG(("CL_DM_INQUIRE_RESULT\n"));
            inquiry_handle_result((CL_DM_INQUIRE_RESULT_T *)message);
        }
        break;
        
        /* confirmation of a Get Attribute */
        case CL_SM_GET_ATTRIBUTE_CFM:
        {
            CL_MSG_DEBUG(("CL_SM_GET_ATTRIBUTE_CFM\n"/*,((CL_SM_GET_ATTRIBUTE_CFM_T *)(message))->psdata[0]*/));
        }
        break;
        
        /* confirmation of a Get Indexed Attribute */
        case CL_SM_GET_INDEXED_ATTRIBUTE_CFM:
        {
            CL_MSG_DEBUG(("CL_SM_GET_INDEXED_ATTRIBUTE_CFM[%d]\n", ((CL_SM_GET_INDEXED_ATTRIBUTE_CFM_T*)message)->status));
        }
        break;    
        
        /* confirmation of Get/Set Role */
        case CL_DM_ROLE_CFM:
        {
            CL_MSG_DEBUG(("CL_DM_ROLE_CFM role : %d\n", ((CL_DM_ROLE_CFM_T *)message)->role));
            connection_msg_handle_role_cfm((CL_DM_ROLE_CFM_T *)message);            
        }
        break;
        
        /* indication that an ACL has opened */
        case CL_DM_ACL_OPENED_IND:
        {
            CL_MSG_DEBUG(("CL_DM_ACL_OPENED_IND\n"));
        }
        break;
        
        /* indication that an ACL has closed */
        case CL_DM_ACL_CLOSED_IND:
        {
            CL_MSG_DEBUG(("CL_DM_ACL_CLOSED_IND\n"));       
        }
        break;
        
        /* indication of a change in Role */
        case CL_DM_ROLE_IND:
        {
            CL_MSG_DEBUG(("CL_DM_ROLE_IND role : %d\n", ((CL_DM_ROLE_IND_T *)message)->role)); 
            /* store role for A2DP connections */
            a2dp_store_role(((CL_DM_ROLE_IND_T *)message)->bd_addr, ((CL_DM_ROLE_IND_T *)message)->role);
        }
        break;
        
        /* confirmation of a remote name read */
        case CL_DM_REMOTE_NAME_COMPLETE:
        {
            CL_MSG_DEBUG(("CL_DM_REMOTE_NAME_COMPLETE status = %d\n", ((CL_DM_REMOTE_NAME_COMPLETE_T *)message)->status));
            connection_msg_remote_name_complete((CL_DM_REMOTE_NAME_COMPLETE_T*) message);
        }
        break;
        
        /* confirmation of a remote version read */
        case CL_DM_REMOTE_VERSION_CFM:
        {
            CL_DM_REMOTE_VERSION_CFM_T *cfm = (CL_DM_REMOTE_VERSION_CFM_T *)message;
            CL_MSG_DEBUG(("CL_DM_REMOTE_VERSION_CFM %d\n", cfm->status));

            if(cfm->status == hci_error_no_connection)
            {               
                /* Clear the manufacturer ID */
                connection_mgr_reset_remote_manufacturer();
            }
            else
            {
                CL_MSG_DEBUG(("    LMP:0x%X LMPsub:0x%X mfr:0x%X\n", cfm->lmpVersion, cfm->lmpSubVersion, cfm->manufacturerName));
                /* Store the manufacturer ID */
                connection_mgr_set_remote_manufacturer(cfm->manufacturerName);
            }
        }
        break;
        
        /* confirmation of a DUT mode attempt */
        case CL_DM_DUT_CFM:
        {
            CL_MSG_DEBUG(("CL_DM_DUT_CFM\n"));
        }
        break;
        
        /* link supervision timeout has changed */
        case CL_DM_LINK_SUPERVISION_TIMEOUT_IND:
        {
            CL_MSG_DEBUG(("CL_DM_LINK_SUPERVISION_TIMEOUT_IND timeout : 0x%x\n", ((CL_DM_LINK_SUPERVISION_TIMEOUT_IND_T *)message)->timeout));
        }
        break;

        case CL_DM_APT_IND:
        {
            CL_MSG_DEBUG(("CL_DM_APT_IND - APT expire & link disconnect Indication \n"));
        }
        break;
		
        case CL_DM_READ_APT_CFM:
        {
            CL_MSG_DEBUG(("CL_DM_READ_APT_CFM [%x]\n", ((CL_DM_READ_APT_CFM_T*)message)->apt));			
        }
        break;

        case CL_DM_WRITE_APT_CFM:
        {
            CL_MSG_DEBUG(("CL_DM_WRITE_APT_CFM [%x]\n", ((CL_DM_WRITE_APT_CFM_T*)message)->status));			
        }
        break;

        case CL_SM_USER_CONFIRMATION_REQ_IND:
        {
            CL_MSG_DEBUG(("CL_SM_USER_CONFIRMATION_REQ_IND[%ld]\n", ((CL_SM_USER_CONFIRMATION_REQ_IND_T*)message)->numeric_value));
            sc_handle_user_confirmation_ind((CL_SM_USER_CONFIRMATION_REQ_IND_T*)message);			
        }			
        break;		
        
        /* messages that will be recieved but don't have to handle */
        
        /*all unhandled connection lib messages end up here */
        default :
        {
            CL_MSG_DEBUG(("CL MSG Unhandled[0x%x]\n", id));
        }
        break ;
    }
}
    

/****************************************************************************
NAME    
    connection_msg_pin_code_ind - Called when receiving the the CL_SM_PIN_CODE_IND message during legacy pairing
*/
static void connection_msg_pin_code_ind(const CL_SM_PIN_CODE_IND_T* ind)
{
    uint16 pin_length = 0;
    uint8 pin[16];
    uint16 count = 0;
    
    if (connection_mgr_can_pair(&ind->taddr.addr))
    {
        /* find the PIN index for this device */
        uint16 index = connection_mgr_find_pin_index_by_addr(&ind->taddr.addr);
        uint16 code_index = 0;
              
        if (index == INVALID_VALUE)
        {            
            /* PIN for this device not found so create new entry for this device */
            index = connection_mgr_get_number_of_device_pins();
            if (index >= CONNECTION_MAX_DEVICE_PIN_CODES)
            {
                /* the stored list of device PIN codes is full so overwrite the oldest entry */
                index = 0;                
            }
            CL_MSG_DEBUG(("  index invalid, new index : %d\n", index));
            connection_mgr_set_pin_address(index,ind->taddr.addr);
            connection_mgr_set_index_value(index,0);
            connection_mgr_increment_number_of_devicePins();
        }
            
        code_index = connection_mgr_get_index_value(index);
        CL_MSG_DEBUG(("  code index %d\n", code_index));
        /* store PIN code for this index */
        CL_MSG_DEBUG(("CL Pin Code Response PIN["));
        pin_length = connection_mgr_get_pin_length(code_index);
        for (count = 0; count < pin_length; count++)
        {
            pin[count] = connection_mgr_get_pin_value(code_index,count);
            CL_MSG_DEBUG(("%c", pin[count]));
        }
        CL_MSG_DEBUG(("]\n"));
	} 
    CL_MSG_DEBUG(("CL Pin Code Response Length[%d]\n", pin_length));
    /* Respond to the PIN code request */
    ConnectionSmPinCodeResponse(&ind->taddr, pin_length, pin); 
}


/****************************************************************************
NAME    
    connection_msg_io_capability_ind - Called when receiving the CL_SM_IO_CAPABILITY_REQ_IND message during simple pairing
*/
static void connection_msg_io_capability_ind(const CL_SM_IO_CAPABILITY_REQ_IND_T* ind)
{	
	/* If not pairable should reject */
	if (connection_mgr_can_pair(&ind->tpaddr.taddr.addr))
	{
        cl_sm_io_capability local_io_capability = LOCAL_IO_CAPABILITY;
        mitm_setting source_mitm_setting = LOCAL_MITM_SETTING;

           /* Send Response */
        CL_MSG_DEBUG(("CL IO Capability Response Accept\n"));
        ConnectionSmIoCapabilityResponse(&ind->tpaddr, 
                                         local_io_capability,
                                         source_mitm_setting, TRUE, KEY_DIST_NONE,
                                         oob_data_none, 0, 0);
	}
	else
	{		
        CL_MSG_DEBUG(("CL IO Capability Response Reject\n"));
        ConnectionSmIoCapabilityResponse(&ind->tpaddr, 
                                         cl_sm_reject_request, 
                                         mitm_not_required, FALSE, KEY_DIST_NONE, 
                                         oob_data_none, 0, 0);
	}
}


/****************************************************************************
NAME    
    connection_msg_authorise_ind - Called when receiving the CL_SM_AUTHORISE_IND message to authorise a connection
*/
static void connection_msg_authorise_ind(const CL_SM_AUTHORISE_IND_T *ind)
{	
	bool lAuthorised = TRUE ;
	   
	/* complete the authentication with the authorised flag */
    ConnectionSmAuthoriseResponse(&ind->bd_addr, ind->protocol_id, ind->channel, ind->incoming, lAuthorised);
}


/****************************************************************************
NAME    
    connection_msg_authorise_cfm - Called when receiving the CL_SM_AUTHORISE_CFM message after authorisation has completed
*/
static void connection_msg_authorise_cfm(const CL_SM_AUTHENTICATE_CFM_T *cfm)
{	
	if (cfm->status == auth_status_success)
    {
        CL_MSG_DEBUG(("    Auth success\n"));

        /* Update the link mode in device attributes */
        connection_mgr_write_device_link_mode(cfm);
		
        /* read the friendly name of the remote device just paired with */
        ConnectionReadRemoteName(connection_mgr_get_instance(), &cfm->bd_addr);        
    }
}


/****************************************************************************
NAME    
    connection_msg_remote_name_complete - Called when receiving the CL_DM_REMOTE_NAME_COMPLETE message after reading the remote name
*/
static void connection_msg_remote_name_complete(const CL_DM_REMOTE_NAME_COMPLETE_T *cfm)
{
    if (cfm->status == hci_success)
    {
        /* store the local friendly name of the device with this address */
        connection_mgr_write_device_name(&cfm->bd_addr, cfm->size_remote_name, cfm->remote_name);
    }
}


/****************************************************************************
NAME    
    connection_msg_handle_role_cfm - Called when receiving the CL_DM_ROLE_CFM message with the current role
*/
static void connection_msg_handle_role_cfm(const CL_DM_ROLE_CFM_T *cfm)
{
    tp_bdaddr tpaddr;
    
    if (cfm->status == hci_success)
    {
        /* store role for A2DP connections */
        
        if (SinkGetBdAddr(cfm->sink, &tpaddr))
        {
            a2dp_store_role(tpaddr.taddr.addr, cfm->role);
        }
        
        if (cfm->role == hci_role_slave)
        {
            ConnectionSetRole(connection_mgr_get_instance(), cfm->sink, hci_role_master);
        }
    }
    
    if (cfm->role == hci_role_master)
    {
        /* set link supervision timeout when Master of the link */
        if (SinkGetBdAddr(cfm->sink, &tpaddr))
        {
            connection_mgr_set_link_supervision_timeout(cfm->sink);
        }
    }
}

