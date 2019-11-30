/****************************************************************************

Copyright (c) 2016 - 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    source_sc.c

DESCRIPTION
    

NOTES

*/
/* header for this file */
#include "source_sc.h"
/* application header files */ 
#include "source_debug.h"
#include "source_connection_mgr.h"
#include "sink.h"


#ifdef ENABLE_BREDR_SC

#ifdef DEBUG_SC
    #define SC_DEBUG(x) DEBUG(x)
#else
    #define SC_DEBUG(x)
#endif 

/* As per HFP1.7 Spec Section 6.2 If Secure Connections is used, the
*  Authenticated Payload Timeout should be less than or equal to 10s. 
*  APT timer = N* 10 msec. N is 1000 for  APT = 10000 msec or 10 seconds 
*/
#define AUTHENTICATED_PAYLOAD_TIMEOUT_AGHFP_SC_MAX       1000

#ifdef TEST_SCOM
/****************************************************************************
NAME    
    sc_handle_user_confirmation_ind - Called when receiving the the CL_SM_USER_CONFIRMATION_REQ_IND message during MITM pairing
*/  
void sc_handle_user_confirmation_ind(const CL_SM_USER_CONFIRMATION_REQ_IND_T   *ind)
{
    /* There is no Voice prompt support in source so accept the key blindly for testing Secure Connection Only Mode.*/
    ConnectionSmUserConfirmationResponse(&ind->tpaddr, TRUE);
}
#endif /* TEST_SCOM*/

void sc_write_apt(aghfpInstance *inst)
{
    tp_bdaddr hf_addr;
    ATTRIBUTES_T attributes;

    /* Retrieve the device attributes */
    ConnectionSmGetAttributeNow(0, &inst->addr, sizeof(ATTRIBUTES_T), (uint8*)&attributes);
    SC_DEBUG((" sc_write_apt Source Link Mode  =%d\n", attributes.mode));
                
    /* If link was secure connection write APT to the controller */
    if(attributes.mode)
    {
        inst->source_link_mode = attributes.mode;
        if(connection_mgr_get_authenticated_payload_timer()> AUTHENTICATED_PAYLOAD_TIMEOUT_AGHFP_SC_MAX)
        {
           connection_mgr_set_authenticated_payload_timer(AUTHENTICATED_PAYLOAD_TIMEOUT_AGHFP_SC_MAX);
        }
                    
        /* Get the remote bluetooth address from the sink */
        SinkGetBdAddr(inst->slc_sink, &hf_addr);

        /* Write the APT value to the controller for the link */
        ConnectionWriteAPT(connection_mgr_get_instance(), &hf_addr, connection_mgr_get_authenticated_payload_timer(), cl_apt_bluestack);
    }
}

/****************************************************************************
NAME
    sc_set_aghfp_link_mode_secure
    
DESCRIPTION
    Informs aghfp library about the link is secure.

RETURNS
    void
*/
void sc_set_aghfp_link_mode_secure(aghfpInstance *inst)
{
    if(is_link_secure(inst))
        AghfpLinkSetLinkMode(inst->aghfp, TRUE);
}

/****************************************************************************
NAME   
     is_link_secure
    
DESCRIPTION
     This function is called to check if the given aghfp link is secure or not.

RETURNS
     TRUE if the link is secure else FALSE
*/
bool  is_link_secure(aghfpInstance *inst)
{
    ATTRIBUTES_T attributes;

    /* Get the attributes for addr and then update the remote name for the addr */
    ConnectionSmGetAttributeNow(0, &inst->addr, sizeof(ATTRIBUTES_T), (uint8*)&attributes);

    return attributes.mode;
}
#endif

