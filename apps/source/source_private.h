/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_private.h

DESCRIPTION
    Application specific data.
    
*/


#ifndef _SOURCE_PRIVATE_H_
#define _SOURCE_PRIVATE_H_


/* application header files */
#include "source_states.h"
#include "source_inquiry.h"

/* Class of Device definitions */
#define COD_MAJOR_CAPTURING                             0x080000
#define COD_MAJOR_AV                                    0x000400  
#define COD_MINOR_AV_HIFI_AUDIO                         0x000028
/* no timeout for timer events */
#define TIMER_NO_TIMEOUT                                0xffff
/* invalid value */
#define INVALID_VALUE                                   0xffff


/* Macro for creating messages with payload */
#define MAKE_MESSAGE(TYPE) TYPE##_T *message = PanicUnlessNew(TYPE##_T);
#define MAKE_MESSAGE_WITH_LEN(TYPE, LEN) TYPE##_T *message = (TYPE##_T *) PanicUnlessMalloc(sizeof(TYPE##_T) + LEN);

/* structure holding the general application variables and state */
typedef struct
{
    TaskData appTask;
    SOURCE_STATE_T app_state; 
    SOURCE_STATE_T pre_idle_state; /* used to return meaningful status to Host */ 
} APP_DATA_T;

/* structure holding all application variables */
typedef struct
{    
    TaskData connectionTask;
    TaskData usbTask;
    TaskData audioTask;
    TaskData ahiTask;
    #ifdef INCLUDE_POWER_READINGS
    TaskData powerTask;
    #endif
    Task codec; 
    APP_DATA_T app_data;
} SOURCE_TASK_DATA_T;

/* application variables declared in another file */
extern SOURCE_TASK_DATA_T *theSource;

/*Function to get app task */
#define app_get_instance() (&theSource->app_data.appTask)

#endif /* _SOURCE_PRIVATE_H_ */

