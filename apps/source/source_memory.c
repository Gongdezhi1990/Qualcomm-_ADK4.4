/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_memory.c
    
DESCRIPTION
    Handles application memory applications.
    
*/


/* header for this file */
#include "source_memory.h"
/* application header files */
#include "source_a2dp.h"
#include "source_aghfp.h"
#include "source_avrcp.h"
#include "source_debug.h"
/* profile/library headers */
#include <audio.h>
/* VM headers */
#include <stdlib.h>


#ifdef DEBUG_MEMORY
    #define MEMORY_DEBUG(x) DEBUG(x)
#else
    #define MEMORY_DEBUG(x)
#endif

/* structure holding all the data for all profile instances */
typedef struct
{
    a2dpInstance a2dp[A2DP_MAX_INSTANCES];
    aghfpInstance aghfp[AGHFP_MAX_INSTANCES];    
    avrcpInstance avrcp[AVRCP_MAX_INSTANCES]; 
} PROFILE_INST_T;

 static PROFILE_INST_T *PROFILE_RUNDATA;

/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    memory_create

DESCRIPTION
    Allocates memory of the specified size.
    Use when allocating memory to keep track of application memory.
    
RETURNS
    The memory allocated.
*/
void *memory_create(size_t size)
{
    void *memory = malloc(size);
    MEMORY_DEBUG(("MEMORY: Create; size[0x%x] address[0x%x]\n", size, (uint16)memory));
    return memory;
}


/****************************************************************************
NAME    
    memory_free

DESCRIPTION
    Frees the memory that is passed in.
    Use when freeing memory to keep track of application memory.
*/
void memory_free(void *memory)
{
    MEMORY_DEBUG(("MEMORY: Free; address[0x%x]\n", (uint16)memory));
    free(memory);
}


/****************************************************************************
NAME    
    memory_create_block

DESCRIPTION
    Creates a memory block that can be split up and used for different elements
    
RETURNS
    TRUE - memory block created successfully
    FALSE - memory block creation failed
*/
bool memory_create_block(MEMORY_CREATE_BLOCK_T block)
{
    MEMORY_DEBUG(("MEMORY: Create block [%d]\n", block));
                  
    switch (block)
    {
        case MEMORY_CREATE_BLOCK_PROFILES:
        {
            PROFILE_RUNDATA = memory_create(sizeof(a2dpInstance) * A2DP_MAX_INSTANCES +
                                                      sizeof(aghfpInstance) * AGHFP_MAX_INSTANCES +
                                                      sizeof(avrcpInstance) * AVRCP_MAX_INSTANCES);
            if (PROFILE_RUNDATA)
            {
                return TRUE;
            }
        }
        break;
        
        case MEMORY_CREATE_BLOCK_CODECS:
        {
            a2dp_set_memory_for_codec_config();
            if (a2dp_get_memory_for_codec_config())
            {
                return TRUE;
            }
        }
        break;
        
        default:
        {
            MEMORY_DEBUG(("MEMORY: Unknown create block\n"));
        }
        break;
    }
    
    return FALSE;
}


/****************************************************************************
NAME    
    memory_get_block

DESCRIPTION
    Gets an element of a memory block
    
RETURNS
    Returns a pointer to the memory allocated or NULL if unsuccessful
*/
void *memory_get_block(MEMORY_GET_BLOCK_T block)
{
    switch (block)
    {
        case MEMORY_GET_BLOCK_PROFILE_A2DP:
        {
            if (PROFILE_RUNDATA)
            {
                return PROFILE_RUNDATA->a2dp;
            }
        }
        break;
        
        case MEMORY_GET_BLOCK_PROFILE_AGHFP:
        {
            if (PROFILE_RUNDATA)
            {
                return PROFILE_RUNDATA->aghfp;
            }
        }
        break;
        
        case MEMORY_GET_BLOCK_PROFILE_AVRCP:
        {
            if (PROFILE_RUNDATA)
            {
                return PROFILE_RUNDATA->avrcp;
            }
        }
        break;
        
        case MEMORY_GET_BLOCK_CODEC_SBC:
        {
            if (a2dp_get_memory_for_codec_config())
            {
                return a2dp_get_memory_for_codec_config();
            }
        }
        break;
        
        case MEMORY_GET_BLOCK_CODEC_FASTSTREAM:
        {
            if (a2dp_get_memory_for_codec_config())
            {
                return a2dp_get_memory_for_codec_config() + a2dp_get_sbc_caps_size();
            }
        }
        break;
        
        case MEMORY_GET_BLOCK_CODEC_APTX:
        {
            if (a2dp_get_memory_for_codec_config())
            {
                return a2dp_get_memory_for_codec_config() + a2dp_get_sbc_caps_size() + a2dp_get_faststream_caps_size();
            }
        }
        break;
        
        case MEMORY_GET_BLOCK_CODEC_APTX_LOW_LATENCY:
        {
            if (a2dp_get_memory_for_codec_config())
            {
                return a2dp_get_memory_for_codec_config() + a2dp_get_sbc_caps_size() + a2dp_get_faststream_caps_size()  + a2dp_get_aptx_caps_size();
            }
        }
        break;
        
        case MEMORY_GET_BLOCK_CODEC_APTXHD:
        {
            if (a2dp_get_memory_for_codec_config())
            {
                return a2dp_get_memory_for_codec_config() + a2dp_get_sbc_caps_size() + a2dp_get_faststream_caps_size() + a2dp_get_aptx_caps_size() + a2dp_get_aptxLowLatency_caps_size() ;
            }
        }
        break;
        
        default:
        {
            MEMORY_DEBUG(("MEMORY: Unknown get block [%d]\n", block));
        }
        break;
    }
    
    return NULL;
}
/****************************************************************************
NAME    
    memory_get_a2dp_instance 
    
DESCRIPTION
    Returns the a2dp array instance.

RETURNS
    Returns a pointer to the a2dpInstance structure.
*/
a2dpInstance *memory_get_a2dp_instance(uint8 index)
{
    return &PROFILE_RUNDATA->a2dp[index];
}
