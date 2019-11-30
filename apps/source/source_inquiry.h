/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_inquiry.h

DESCRIPTION
    Inquiry sub-system used to locate discoverable remote devices.
    
*/


#ifndef _SOURCE_INQUIRY_H_
#define _SOURCE_INQUIRY_H_


/* profile/library headers */
#include <connection.h>


/* Inquiry defines */
#define INQUIRY_LAP                 0x9e8b33
#define INQUIRY_MAX_RESPONSES       10
#define INQUIRY_TIMEOUT             4           /* timeout * 1.28 seconds */ 
#define INQUIRY_SCAN_BUFFER_SIZE    10


/* Values used to identify profiles */
typedef enum
{
    PROFILE_NONE   = 0x00,  
    PROFILE_A2DP   = 0x01,
    PROFILE_AGHFP  = 0x02,
    PROFILE_AVRCP  = 0x04,
    PROFILE_ALL    = 0x0f
} PROFILES_T;


/* Inquiry structures */
typedef struct
{    
    int16 path_loss;
    PROFILES_T profiles:4;
    unsigned profiles_complete:1;
} INQUIRY_EIR_DATA_T;

typedef struct
{
    uint16 read_idx;
    uint16 write_idx;
    uint16 search_idx;    
    bdaddr buffer[INQUIRY_SCAN_BUFFER_SIZE];
    INQUIRY_EIR_DATA_T eir_data[INQUIRY_SCAN_BUFFER_SIZE];
    unsigned inquiry_state_timeout:1;
} INQUIRY_SCAN_DATA_T;

/***************************************************************************
Function definitions
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
void inquiry_init(void);


/****************************************************************************
NAME    
    inquiry_write_eir_data

DESCRIPTION
    Write EIR data after reading the local name of the device.

RETURNS
    void
*/
void inquiry_write_eir_data(const CL_DM_LOCAL_NAME_COMPLETE_T *data);


/****************************************************************************
NAME    
    inquiry_start_discovery

DESCRIPTION
    Begin the inquiry procedure.

RETURNS
    void
*/
void inquiry_start_discovery(void);


/****************************************************************************
NAME    
    inquiry_handle_result

DESCRIPTION
    Process the inquiry result contained in the CL_DM_INQUIRE_RESULT message.

RETURNS
    void
    
*/
void inquiry_handle_result(const CL_DM_INQUIRE_RESULT_T *result);


/****************************************************************************
NAME    
    inquiry_complete

DESCRIPTION
    Inquiry procedure has completed so tidy up any inquiry data.

RETURNS
    void
*/
void inquiry_complete(void);


/****************************************************************************
NAME    
    inquiry_has_results

DESCRIPTION
    Determines if any device has been located during the inquiry procedure.
    
RETURNS
    bool
    
*/
bool inquiry_has_results(void);


/****************************************************************************
NAME    
    inquiry_process_results

DESCRIPTION
    Process the devices located during the inquiry procedure.

RETURNS
    void
*/
void inquiry_process_results(void);
/****************************************************************************
NAME    
    inquiry_get_inquiry_data - 
    
DESCRIPTION
    Returns the inquiry data pointer.

RETURNS:
    INQUIRY_SCAN_DATA_T *
*/
INQUIRY_SCAN_DATA_T *inquiry_get_inquiry_data(void);
/****************************************************************************
NAME    
    inquiry_set_inquiry_state_timeout -
    
DESCRIPTION
     Sets the inquiry state timeout.

RETURNS:
   void
*/
void inquiry_set_inquiry_state_timeout(bool inquiry_state_timeout);
/****************************************************************************
NAME    
    inquiry_set_forced_inquiry_mode -

DESCRIPTION
      Sets the Forced Inquiry Mode variable.

RETURNS:
   void
*/
void inquiry_set_forced_inquiry_mode(bool force_inquiry_mode);
/****************************************************************************
NAME    
    inquiry_get_forced_inquiry_mode -

DESCRIPTION
       Gets the Forced Inquiry Mode variable.

RETURNS:
   bool
*/
bool inquiry_get_forced_inquiry_mode(void);
/****************************************************************************
NAME    
    inquiry_set_inquiry_tx 

DESCRIPTION
       - Sets the Inquiry Tx variable.

RETURNS:
    void
*/
void inquiry_set_inquiry_tx(uint8 inquiry_tx );
/*************************************************************************
NAME
    inquiry_get_state_timer

DESCRIPTION
    Helper function to Get the Inquiry state timer.

RETURNS
    The inquiry state timer value read from the corresponding config block section .

**************************************************************************/
uint16 inquiry_get_state_timer(void);
/*************************************************************************
NAME
    inquiry_get_Idle_timer

DESCRIPTION
    Helper function to Get the Inquiry Idle timer.

RETURNS
    The inquiry idle timer value read from the corresponding config block section .

**************************************************************************/
uint16 inquiry_get_Idle_timer(void);

#endif /* _SOURCE_INQUIRY_H_ */
