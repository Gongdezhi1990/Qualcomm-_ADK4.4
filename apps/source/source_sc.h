/****************************************************************************

Copyright (c) 2016 - 2015 Qualcomm Technologies International, Ltd.

FILE NAME
    source_sc.h

DESCRIPTION
    

NOTES

*/

#ifndef _SOURCE_SC_H_
#define _SOURCE_SC_H_

#include <connection.h>
#include "source_aghfp.h"

#ifdef ENABLE_BREDR_SC
#define SC_CONNECTION_LIB_OPTIONS connection_mgr_get_secure_connection_mode()
#else
#define SC_CONNECTION_LIB_OPTIONS CONNLIB_OPTIONS_NONE
#endif

#if defined ENABLE_BREDR_SC && defined TEST_SCOM
#define  LOCAL_IO_CAPABILITY   (\
          connection_mgr_get_man_in_the_mid_value() ? \
               cl_sm_io_cap_display_yes_no : \
               cl_sm_io_cap_no_input_no_output \
         )
#define  LOCAL_MITM_SETTING   (\
           connection_mgr_get_man_in_the_mid_value() ? \
                   mitm_required : mitm_not_required \
         )
#else
#define  LOCAL_IO_CAPABILITY cl_sm_io_cap_no_input_no_output
#define  LOCAL_MITM_SETTING mitm_not_required;
#endif
           
#if defined ENABLE_BREDR_SC && defined TEST_SCOM
void sc_handle_user_confirmation_ind(const CL_SM_USER_CONFIRMATION_REQ_IND_T   *ind);
#else
#define sc_handle_user_confirmation_ind(message) ((void)(0))
#endif


/****************************************************************************
NAME
    sc_write_apt
    
DESCRIPTION
    Write the APT value to the controller. 
RETURNS
    void
*/
#ifdef ENABLE_BREDR_SC
void sc_write_apt(aghfpInstance *inst);
#else
#define sc_write_apt(inst) ((void)(0))
#endif
/****************************************************************************
NAME
    sc_set_aghfp_link_mode_secure
    
DESCRIPTION
    Informs aghfp library about the link is secure.

RETURNS
    void
*/
#ifdef ENABLE_BREDR_SC
void sc_set_aghfp_link_mode_secure(aghfpInstance *inst);
#else
#define sc_set_aghfp_link_mode_secure(inst) ((void)(0))
#endif

/****************************************************************************
NAME
    sc_init_features
    
DESCRIPTION
    Intialises connection library with required configuration based on mode.

RETURNS
    void
*/
void sc_init_features(const msg_filter connection_msg_filter);

/****************************************************************************
NAME   
     is_link_secure
    
DESCRIPTION
     This function is called to check if the given aghfp link is secure or not.

RETURNS
     TRUE if the link is secure else FALSE
*/
#ifdef ENABLE_BREDR_SC
bool  is_link_secure(aghfpInstance *inst);
#else
#define is_link_secure(inst) FALSE
#endif

#endif /* _SOURCE_SC_ */

