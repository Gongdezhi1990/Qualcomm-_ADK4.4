/*
Copyright (c) 2004 - 2016 Qualcomm Technologies International, Ltd.
*/

/*!
@file
@ingroup source_app
@brief   
    Configuration manager for the device - resoponsible for extracting user information out of the 
    PSKEYs and initialising the configurable nature of the sink device components
    
*/

/****************************************************************************
NAME 
      configManagerFeatureBlock

DESCRIPTION
      Read the system feature block and configure system accordingly
 
RETURNS
      void
*/
#include <config_store.h>
#include "config_definition.h"
#include <source_configmanager.h>
#include <source_configmanager.h>

#ifdef DEBUG_CONFIG
#define CONF_DEBUG(x) DEBUG(x)
#else
#define CONF_DEBUG(x) 
#endif


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
uint16 configManagerGetReadOnlyConfig(uint16 config_id, const void **data)
{
    config_store_status_t status;
    uint16 size = 0;

    status = ConfigStoreGetReadOnlyConfig(config_id, &size, data);
    if (config_store_success != status)
    {
        CONF_DEBUG(("CFG: configManagerGetReadOnlyConfig(): Error opening RO config block %u status %u\n", config_id, status));
        Panic();
    }

    return size;
}

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
uint16 configManagerGetWriteableConfig(uint16 config_id, void **data, uint16 size)
{
    config_store_status_t status;
    uint16 config_size = size;

    status = ConfigStoreGetWriteableConfig(config_id, &config_size, data);
    if (config_store_success != status)
    {
        CONF_DEBUG(("CFG: configManagerGetWriteableConfig(): Error opening writeable config block %u status %u\n", config_id, status));
        Panic();
    }

    return config_size;
}

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
void configManagerReleaseConfig(uint16 config_id)
{
    ConfigStoreReleaseConfig(config_id);
}

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
void configManagerUpdateWriteableConfig(uint16 config_id)
{
    ConfigStoreWriteConfig(config_id);
    ConfigStoreReleaseConfig(config_id);
}
