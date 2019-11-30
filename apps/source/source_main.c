/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_a2dp.c

DESCRIPTION
    
*/


/* application header files */
#include "source_a2dp_msg_handler.h"
#include "source_app_msg_handler.h"
#include "source_audio.h"
#include "source_connection_msg_handler.h"
#include "source_debug.h"
#include "source_memory.h"
#include "source_private.h"
#include "source_states.h"
#include "source_usb.h"
#include "source_usb_msg_handler.h"
#include "source_volume.h"
#include "source_ahi.h"
/* profile/library headers */
#include <a2dp.h>
#include <audio.h>
#include <connection.h>
#include <usb_device_class.h>
/* VM headers */
#include <panic.h>
#include <string.h>
#include <config_store.h>
#include "config_definition.h"


/* function for time critical functionality */
extern void _init(void);


/* application variables */
SOURCE_TASK_DATA_T *theSource;

        
/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    _init - Time critical initialisation
*/
void _init(void)
{
    config_store_status_t status;
    theSource = memory_create(sizeof(SOURCE_TASK_DATA_T));
    
    if (theSource == NULL)
    {
        /* cannot create memory required to hold variables - check memory usage */
        Panic();
    }
      
    /* Initialize config store library */
    status = ConfigStoreInit(ConfigDefinitionGetConstData(), ConfigDefinitionGetConstDataSize(),FALSE);
    if(status != config_store_success)
    {
       DEBUG (("ConfigStoreInit failed [status = %u] \n",status));
       Panic();
    }
   
    /* initialise the application variables */
    memset(theSource, 0, sizeof(SOURCE_TASK_DATA_T));

    /* Initialise Source Ahi private data */
    sourceAhiEarlyInit();
    
    /* Set task message handlers */
    theSource->connectionTask.handler = connection_msg_handler;
    theSource->usbTask.handler = usb_msg_handler;
    theSource->app_data.appTask.handler = app_handler;        
    theSource->audioTask.handler = audio_plugin_msg_handler;
    theSource->ahiTask.handler = app_handler;

    /* setup volume before USB is initialised as new volumes may be sent instantly over USB */
    volume_initialise();
    
    /* Time critical USB setup */
    usb_time_critical_init();   
}

      
/****************************************************************************
NAME    
    main - Initial function called when the application runs
*/
int main(void)
{
    /* Initialise Source Ahi */
    sourceAhiInit(&theSource->ahiTask);  

    /* turn off charger LED indications */
    ChargerConfigure(CHARGER_SUPPRESS_LED0, TRUE);

    if(sourceAhiGetAppMode() == ahi_app_mode_configuration)
    {
        /* Config mode - do not initialise the main source app. */
        states_set_state(SOURCE_STATE_CONFIGURE_MODE);
    }
    else
    {
        /* initialise state machine */
        states_set_state(SOURCE_STATE_INITIALISING);
    }

    MessageLoop();

    return 0;
}
