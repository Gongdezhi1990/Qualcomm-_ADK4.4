/*
Copyright (c) 2004 - 2016 Qualcomm Technologies International, Ltd.
*/

/*!
@file
@ingroup source_app
@brief
    Configuration manager for the sink device - responsible for extracting user information out of the
    PSKEYs and initialising the configurable nature of the devices' components

*/
#ifndef SOURCE_CONFIG_MANAGER_H
#define SOURCE_CONFIG_MANAGER_H

#include <stdlib.h>
#include <pblock.h>
#include <audio.h>
#include <hfp.h>
#include <vmtypes.h>


/* Persistent store key allocation  */
#define CONFIG_BASE  (0)


/***********************************************************************/
/***********************************************************************/
/* ***** do not alter order or insert gaps as device will panic ***** */
/***********************************************************************/
/***********************************************************************/
enum
{
    CONFIG_AHI                                = 1
};

/******************************************************************************
NAME    
    configManagerGetReadOnlyConfig
    
DESCRIPTION
    Open a config block as read-only.

    The pointer to the memory for the config block is returned in *data.

    If the block cannot be opened, this function will panic.

PARAMS
    config_id [in] Id of config block to open
    data [out] Will be set with the pointer to the config data buffer if
               successful, NULL otherwise.

RETURNS
    uint16 size of the opened config block buffer. The size can be 0,
    e.g. if the config is an empty array.Here size returned is not 
    equivalent to sizeof(), but represents the number of uint16's
    containing config blocks information.
*/
uint16 configManagerGetReadOnlyConfig(uint16 config_id, const void **data);

/******************************************************************************
NAME
    configManagerGetWriteableConfig
 
DESCRIPTION
    Open a config block as writeable.

    The pointer to the memory for the config block is returned in *data.

    If the block cannot be opened, this function will panic.
 
PARAMS
    config_id [in] Id of config block to open
    data [out] Will be set with the pointer to the config data buffer if
               successful, NULL otherwise.
    size [in] Size of the buffer to allocate for the config data.
              Set this to 0 to use the size of config block in the
              config store.

RETURNS
    uint16 Size of the opened config block buffer. The size can be 0,
           e.g. if the config is an empty array.
*/
uint16 configManagerGetWriteableConfig(uint16 config_id, void **data, uint16 size);

/******************************************************************************
NAME    
    configManagerReleaseConfig
    
DESCRIPTION
    Release the given config block so that config_store can release any
    resources it is using to keep track of it.

    After this has been called any pointers to the config block data buffer
    will be invalid.

PARAMS
    config_id Id of the config block to release.

RETURNS
    void
*/
void configManagerReleaseConfig(uint16 config_id);

/******************************************************************************
NAME    
    configManagerUpdateWriteableConfig
    
DESCRIPTION
    Update the config block data in the config store and release it.
   
    After this has been called any pointers to the config block data buffer
    will be invalid.

PARAMS
    config_id Id of the config block to update and release.

RETURNS
    void
*/
void configManagerUpdateWriteableConfig(uint16 config_id);
#endif
