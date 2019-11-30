/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_a2dp.c

DESCRIPTION
    A2DP profile functionality.
    
*/


/* header for this file */
#include "source_a2dp.h"
/* application header files */
#include "source_a2dp_msg_handler.h"
#include "source_app_msg_handler.h"
#include "source_audio.h"
#include "source_debug.h"
#include "source_inquiry.h"
#include "source_memory.h"
#include "Source_configmanager.h" 
#include "source_power.h"
#include "source_aghfp.h"
#include "source_avrcp.h"
#include "Source_a2dp_config_def.h" 
#include "source_private_data_config_def.h"
#include "source_connection_mgr.h"
/* profile/library headers */
#include <a2dp.h>
/* VM headers */
#include <bdaddr.h>
#include <stdlib.h>
#include <string.h>

/* structure holding the A2DP data */
typedef struct
{
    a2dpInstance *inst; 
    uint8 *codec_config;
    sep_config_type sbc_caps;
    uint8 *sbc_codec_config;
    sep_config_type faststream_caps;
    uint8 *faststream_codec_config;
    sep_config_type aptx_caps;
    uint8 *aptx_codec_config;
    sep_config_type aptxLowLatency_caps;
    uint8 *aptxLowLatency_codec_config;
    sep_config_type aptxhd_caps;
    uint8 *aptxhd_codec_config;
    lp_power_table *a2dp_powertable;
    unsigned number_a2dp_entries;
} A2DP_DATA_T;

/* A2DP supported codecs*/
typedef enum
{
    A2DP_CODEC_SBC = 0,
    A2DP_CODEC_FAST_STREAM,
    A2DP_CODEC_APTX,
    A2DP_CODEC_APTX_LOW_LATENCY,
    A2DP_CODEC_APTX_HD
} A2DP_CODEC_CONFIG_T;

/*  A2DP Service Search Pattern    
    DataEl(0x35), Length(0x03), UUID(0x19), Advanced Audio Distribution(0x110D) */
static const uint8 a2dp_service_search_pattern[] = {0x35, 0x03, 0x19, 0x11, 0x0D};
static A2DP_DATA_T A2DP_RUNDATA;

#ifdef DEBUG_A2DP
    #define A2DP_DEBUG(x) DEBUG(x)

    const char *const a2dp_state_strings[A2DP_STATES_MAX] = {   "Disconnected",
                                                                "Connecting Local",
                                                                "Connecting Remote",
                                                                "Connected Signalling",
                                                                "Connecting Media Local",
                                                                "Connecting Media Remote",
                                                                "Connected Media",
                                                                "Media Streaming",
                                                                "Media Suspending Local",
                                                                "Media Suspended",
                                                                "Media Starting Local",
                                                                "Disconnecting Media",
                                                                "Disconnecting"};
#else
    #define A2DP_DEBUG(x)
#endif
    
    
/* Display unhandled states in Debug Mode */
#define a2dp_unhandled_state(inst) A2DP_DEBUG(("    A2DP Unhandled State [%d] inst[0x%x]\n", a2dp_get_state(inst), (uint16)inst));    

    
/* SBC Stream-End Point Capabilities */ 
static const uint8 a2dp_sbc_caps_source[] = {
    AVDTP_SERVICE_MEDIA_TRANSPORT,
    0,
    AVDTP_SERVICE_MEDIA_CODEC,
    6,
    AVDTP_MEDIA_TYPE_AUDIO<<2,
    AVDTP_MEDIA_CODEC_SBC,

#if (defined ANALOGUE_INPUT_DEVICE && defined BC5_MULTIMEDIA)
    A2DP_SBC_SAMPLING_FREQ_44100     |
#else
    A2DP_SBC_SAMPLING_FREQ_48000     |
#endif    
    A2DP_SBC_CHANNEL_MODE_MONO       | A2DP_SBC_CHANNEL_MODE_DUAL_CHAN | A2DP_SBC_CHANNEL_MODE_STEREO    | A2DP_SBC_CHANNEL_MODE_JOINT_STEREO,

    A2DP_SBC_BLOCK_LENGTH_4          | A2DP_SBC_BLOCK_LENGTH_8         | A2DP_SBC_BLOCK_LENGTH_12        | A2DP_SBC_BLOCK_LENGTH_16        |
    A2DP_SBC_SUBBANDS_4              | A2DP_SBC_SUBBANDS_8             | A2DP_SBC_ALLOCATION_SNR         | A2DP_SBC_ALLOCATION_LOUDNESS,

    A2DP_SBC_BITPOOL_MIN,
    A2DP_SBC_BITPOOL_MAX,
        
    AVDTP_SERVICE_CONTENT_PROTECTION,
    2,
    AVDTP_CP_TYPE_SCMS_LSB,
    AVDTP_CP_TYPE_SCMS_MSB
};


/* Faststream Stream-End Point Capabilities */ 
static const uint8 a2dp_faststream_caps_source[] = {
    AVDTP_SERVICE_MEDIA_TRANSPORT,
    0,
    AVDTP_SERVICE_MEDIA_CODEC,
    10,
    AVDTP_MEDIA_TYPE_AUDIO<<2,
    AVDTP_MEDIA_CODEC_NONA2DP,

    A2DP_CSR_VENDOR_ID0,
    A2DP_CSR_VENDOR_ID1,
    A2DP_CSR_VENDOR_ID2,
    A2DP_CSR_VENDOR_ID3,
    A2DP_FASTSTREAM_CODEC_ID0,
    A2DP_FASTSTREAM_CODEC_ID1,
    A2DP_FASTSTREAM_MUSIC | A2DP_FASTSTREAM_VOICE,
#if (defined ANALOGUE_INPUT_DEVICE && defined BC5_MULTIMEDIA)
    A2DP_FASTSTREAM_MUSIC_SAMP_44100 | A2DP_FASTSTREAM_VOICE_SAMP_16000,
#else
    A2DP_FASTSTREAM_MUSIC_SAMP_48000 | A2DP_FASTSTREAM_VOICE_SAMP_16000,
#endif    
};


/* APT-X Stream-End Point Capabilities */ 
static const uint8 a2dp_aptx_caps_source[] = {
    AVDTP_SERVICE_MEDIA_TRANSPORT,
    0,
    AVDTP_SERVICE_MEDIA_CODEC,
    9,
    AVDTP_MEDIA_TYPE_AUDIO<<2,
    AVDTP_MEDIA_CODEC_NONA2DP,
    
    A2DP_APTX_VENDOR_ID0,
    A2DP_APTX_VENDOR_ID1,
    A2DP_APTX_VENDOR_ID2,
    A2DP_APTX_VENDOR_ID3,
    A2DP_APTX_CODEC_ID0,
    A2DP_APTX_CODEC_ID1,
    
#if (defined ANALOGUE_INPUT_DEVICE && defined BC5_MULTIMEDIA)
    A2DP_APTX_SAMPLING_FREQ_44100 | A2DP_APTX_CHANNEL_MODE_STEREO,
#else    
    A2DP_APTX_SAMPLING_FREQ_48000 | A2DP_APTX_CHANNEL_MODE_STEREO,
#endif    
    
    AVDTP_SERVICE_CONTENT_PROTECTION,
    2,
    AVDTP_CP_TYPE_SCMS_LSB,
    AVDTP_CP_TYPE_SCMS_MSB
};


/* APT-X Low Latency Stream-End Point Capabilities */ 
static const uint8 a2dp_aptxLowLatency_caps_source[] = {
    AVDTP_SERVICE_MEDIA_TRANSPORT,
    0,
    AVDTP_SERVICE_MEDIA_CODEC,
    19,
    AVDTP_MEDIA_TYPE_AUDIO<<2,
    AVDTP_MEDIA_CODEC_NONA2DP,
    
    A2DP_QTI_VENDOR_ID0,
    A2DP_QTI_VENDOR_ID1,
    A2DP_QTI_VENDOR_ID2,
    A2DP_QTI_VENDOR_ID3,
    A2DP_APTX_LOWLATENCY_CODEC_ID0,
    A2DP_APTX_LOWLATENCY_CODEC_ID1,
    
#if (defined ANALOGUE_INPUT_DEVICE && defined BC5_MULTIMEDIA)
    A2DP_APTX_SAMPLING_FREQ_44100 | A2DP_APTX_CHANNEL_MODE_STEREO,
#else    
    A2DP_APTX_SAMPLING_FREQ_48000 | A2DP_APTX_CHANNEL_MODE_STEREO,
#endif    

    A2DP_APTX_LOWLATENCY_VOICE_16000 | A2DP_APTX_LOWLATENCY_NEW_CAPS,

    A2DP_APTX_LOWLATENCY_RESERVED,
    A2DP_APTX_LOWLATENCY_TCL_LSB,
    A2DP_APTX_LOWLATENCY_TCL_MSB,
    A2DP_APTX_LOWLATENCY_ICL_LSB,
    A2DP_APTX_LOWLATENCY_ICL_MSB,
    A2DP_APTX_LOWLATENCY_MAX_RATE,
    A2DP_APTX_LOWLATENCY_AVG_TIME,
    A2DP_APTX_LOWLATENCY_GWBL_LSB,
    A2DP_APTX_LOWLATENCY_GWBL_MSB,
    
    AVDTP_SERVICE_CONTENT_PROTECTION,
    2,
    AVDTP_CP_TYPE_SCMS_LSB,
    AVDTP_CP_TYPE_SCMS_MSB
};


/* aptX-HD Stream-End Point Capabilities */ 
static const uint8 a2dp_aptxhd_caps_source[] = {
    AVDTP_SERVICE_MEDIA_TRANSPORT,
    0,
    AVDTP_SERVICE_MEDIA_CODEC,
    13,
    AVDTP_MEDIA_TYPE_AUDIO<<2,
    AVDTP_MEDIA_CODEC_NONA2DP,
    
    A2DP_QTI_VENDOR_ID0,
    A2DP_QTI_VENDOR_ID1,
    A2DP_QTI_VENDOR_ID2,
    A2DP_QTI_VENDOR_ID3,
    A2DP_APTXHD_CODEC_ID0,
    A2DP_APTXHD_CODEC_ID1,
    
#if (defined ANALOGUE_INPUT_DEVICE && defined BC5_MULTIMEDIA)
    A2DP_APTX_SAMPLING_FREQ_44100 | A2DP_APTX_CHANNEL_MODE_STEREO,
#else    
    A2DP_APTX_SAMPLING_FREQ_48000 | A2DP_APTX_CHANNEL_MODE_STEREO,
#endif    
    
    A2DP_APTXHD_RESERVED,
    A2DP_APTXHD_RESERVED,
    A2DP_APTXHD_RESERVED,
    A2DP_APTXHD_RESERVED,

    AVDTP_SERVICE_CONTENT_PROTECTION,
    2,
    AVDTP_CP_TYPE_SCMS_LSB,
    AVDTP_CP_TYPE_SCMS_MSB
};


/* exit state functions */    
static void a2dp_exit_state(a2dpInstance *inst);
static void a2dp_exit_state_disconnected(a2dpInstance *inst);
static void a2dp_exit_state_connecting_local(a2dpInstance *inst);
static void a2dp_exit_state_connecting_remote(a2dpInstance *inst);
static void a2dp_exit_state_connected_signalling(a2dpInstance *inst);
static void a2dp_exit_state_connecting_media_local(a2dpInstance *inst);
static void a2dp_exit_state_connecting_media_remote(a2dpInstance *inst);
static void a2dp_exit_state_connected_media(a2dpInstance *inst);
static void a2dp_exit_state_connected_media_streaming(a2dpInstance *inst);
static void a2dp_exit_state_connected_media_suspending_local(a2dpInstance *inst);
static void a2dp_exit_state_connected_media_suspended(a2dpInstance *inst);
static void a2dp_exit_state_connected_media_starting_local(a2dpInstance *inst);
static void a2dp_exit_state_disconnecting_media(a2dpInstance *inst);
static void a2dp_exit_state_disconnecting(a2dpInstance *inst);
/* enter state functions */
static void a2dp_enter_state(a2dpInstance *inst, A2DP_STATE_T old_state);    
static void a2dp_enter_state_disconnected(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connecting_local(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connecting_remote(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connected_signalling(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connecting_media_local(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connecting_media_remote(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connected_media(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connected_media_suspending_local(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connected_media_suspended(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_connected_media_starting_local(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_disconnecting_media(a2dpInstance *inst, A2DP_STATE_T old_state);
static void a2dp_enter_state_disconnecting(a2dpInstance *inst, A2DP_STATE_T old_state);
/* other local functions */
static void a2dp_get_codec_enable_values(a2dp_codecs_config_def_t *a2dp_config_data);
static void a2dp_create_memory_for_codec_configs(void);
static void a2dp_reset_codec_config(A2DP_CODEC_CONFIG_T Config);
static void a2dp_set_caps_values(A2DP_CODEC_CONFIG_T Config,sep_config_type caps);
static uint8 *a2dp_get_codec_config(A2DP_CODEC_CONFIG_T Config);
static void a2dp_set_codec_config(uint8 index,uint8 * Dstval,const uint8 *Srcval);
static void a2dp_set_codec_config_values_on_index(uint8 index,uint8 * Dstval,uint8 Srcval);
static void a2dp_set_codec_config_caps_values( const uint8  **Dstval,uint8 **Srcval);
static bool a2dp_get_sbc_force_max_bit_pool(void);
static void a2dp_set_memory_for_codecs(A2DP_CODEC_CONFIG_T Config);
static sep_config_type *a2dp_get_config_caps(A2DP_CODEC_CONFIG_T Config);
static uint8 a2dp_get_sbc_sampling_frequency(void);
static uint8 a2dp_get_min_bit_pool(void);
static uint8 a2dp_get_max_bit_pool(void);
static uint8 a2dp_get_faststream_sampling_frequency(void);
static uint8 a2dp_get_faststream_voice_music_support(void);
static uint8 a2dp_get_aptx_sampling_frequency(void);
static uint8 a2dp_get_aptxLL_sampling_frequency(void);
static bool a2dp_get_aptxLL_bidiirectional_value(void);
static uint8 a2dp_get_aptxHD_sampling_frequency(void);
static void a2dp_set_sampling_frequency(uint8 SamplingFrequency);
static bool a2dp_is_dualstream_reconfigure_needed(void);
static A2DP_AUDIO_QUALITY_T a2dp_get_lowest_quality(void);
#ifdef PTS_TEST_ENABLED
static uint8 a2dp_get_sbc_parameters(void);
#endif

/* Stream-End Point Definitions */
#ifdef INCLUDE_APPLICATION_A2DP_CODEC_CONFIGURATION
/* application must respond to A2DP_CODEC_CONFIGURE_IND message */
static const sep_config_type sbc_sep = {A2DP_SEID_SBC, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 0, 0, sizeof(a2dp_sbc_caps_source), a2dp_sbc_caps_source};
static const sep_config_type faststream_sep = {A2DP_SEID_FASTSTREAM, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 0, 0, sizeof(a2dp_faststream_caps_source), a2dp_faststream_caps_source};
static const sep_config_type aptx_sep = {A2DP_SEID_APTX, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 0, 0, sizeof(a2dp_aptx_caps_source), a2dp_aptx_caps_source};
static const sep_config_type aptxLowLatency_sep = {A2DP_SEID_APTX_LOW_LATENCY, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 0, 0, sizeof(a2dp_aptxLowLatency_caps_source), a2dp_aptxLowLatency_caps_source};
static const sep_config_type aptxhd_sep = {A2DP_SEID_APTXHD, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 0, 0, sizeof(a2dp_aptxhd_caps_source), a2dp_aptxhd_caps_source};

#else
/* no A2DP_CODEC_CONFIGURE_IND message sent to application, the A2DP library chooses the configuration based on the registered Stream End Points */
static const sep_config_type sbc_sep = {A2DP_SEID_SBC, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 1, 0, sizeof(a2dp_sbc_caps_source), a2dp_sbc_caps_source};
static const sep_config_type faststream_sep = {A2DP_SEID_FASTSTREAM, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 1, 0, sizeof(a2dp_faststream_caps_source), a2dp_faststream_caps_source};
static const sep_config_type aptx_sep = {A2DP_SEID_APTX, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 1, 0, sizeof(a2dp_aptx_caps_source), a2dp_aptx_caps_source};
static const sep_config_type aptxLowLatency_sep = {A2DP_SEID_APTX_LOW_LATENCY, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 1, 0, sizeof(a2dp_aptxLowLatency_caps_source), a2dp_aptxLowLatency_caps_source};
static const sep_config_type aptxhd_sep = {A2DP_SEID_APTXHD, A2DP_KALIMBA_RESOURCE_ID, sep_media_type_audio, a2dp_source, 1, 0, sizeof(a2dp_aptxhd_caps_source), a2dp_aptxhd_caps_source};

#endif /*INCLUDE_APPLICATION_A2DP_CODEC_CONFIGURATION */

/* The max bitpools for the different audio qualities */
static const uint16 a2dp_max_bitpool_array[] = {A2DP_SBC_BITPOOL_LOW_QUALITY, A2DP_SBC_BITPOOL_MEDIUM_QUALITY, A2DP_SBC_BITPOOL_GOOD_QUALITY, A2DP_SBC_BITPOOL_HIGH_QUALITY};
/* The max bitpools for the different audio qualities under pool link conditions */
static const uint16 a2dp_max_bitpool_poor_link_array[] = {A2DP_SBC_BITPOOL_LOW_QUALITY-10, A2DP_SBC_BITPOOL_MEDIUM_QUALITY, A2DP_SBC_BITPOOL_GOOD_QUALITY-15, A2DP_SBC_BITPOOL_HIGH_QUALITY};

static uint8 a2dp_get_caps_value_by_index(uint8 index,A2DP_CODEC_CONFIG_T Config);

/*A2DP codec configuration configurable  read functions.*/
static uint16  a2dp_get_aptxHD_configurable_values(void);
static uint16  a2dp_get_aptxLL_configurable_values(void);
static uint16  a2dp_get_aptx_configurable_values(void);
static uint16  a2dp_get_faststream_configurable_values(void);
static uint16  a2dp_get_sbc_configurable_values(void);

/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    a2dp_initialize_codecs - 
    
DESCRIPTION
    Initialise A2DP codecs to its default values.
    
*/    
void a2dp_initialize_codecs(void)
{
    /* set to default configs */
    a2dp_set_sbc_config(TRUE);
    a2dp_set_faststream_config(TRUE);
    a2dp_set_aptx_config(TRUE);
    a2dp_set_aptxLowLatency_config(TRUE);
    a2dp_set_aptxhd_config(TRUE);
}
/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    a2dp_init - Initialise A2DP
*/    
void a2dp_init(void)
{
    sep_data_type seps[A2DP_MAX_ENDPOINTS];   
    uint16 index;
    uint16 num_endpoints = 0;
    a2dp_codecs_config_def_t a2dp_config_data;

    /*Initialize the A2dp codecs*/
    a2dp_initialize_codecs();

    /* Create memory for all the codec configurations*/
    a2dp_create_memory_for_codec_configs();

    /* allocate memory for A2DP instances */
    A2DP_RUNDATA.inst = (a2dpInstance *)memory_get_block(MEMORY_GET_BLOCK_PROFILE_A2DP);
    /* initialise each instance */
    for_all_a2dp_instance(index)
    {
        A2DP_RUNDATA.inst[index].a2dp_state = A2DP_STATE_DISCONNECTED;
        a2dp_init_instance(&A2DP_RUNDATA.inst[index]);
    }

    /*Get the codec config values from the  a2dp module config xml files.*/
    a2dp_get_codec_enable_values(&a2dp_config_data);

    /* initialise the A2DP profile library */
    if (a2dp_config_data.a2dpCodecsSBCEnable)
    {
        seps[num_endpoints].in_use = FALSE;
        seps[num_endpoints++].sep_config = a2dp_get_config_caps(A2DP_CODEC_SBC);
    }    
    if (a2dp_config_data.a2dpCodecsFastStreamEnable)
    {
        seps[num_endpoints].in_use = FALSE;
        seps[num_endpoints++].sep_config = a2dp_get_config_caps(A2DP_CODEC_FAST_STREAM); 
    }
    if (a2dp_config_data.a2dpCodecsAptXEnable)
    {
        seps[num_endpoints].in_use = FALSE;
        seps[num_endpoints++].sep_config = a2dp_get_config_caps(A2DP_CODEC_APTX); 
    }
    if (a2dp_config_data.a2dpCodecsAptXLLEnable)
    {
        seps[num_endpoints].in_use = FALSE;
        seps[num_endpoints++].sep_config = a2dp_get_config_caps(A2DP_CODEC_APTX_LOW_LATENCY);
    }
    if (a2dp_config_data.a2dpCodecsAptXHDEnable)
    {
        seps[num_endpoints].in_use = FALSE;
        seps[num_endpoints++].sep_config = a2dp_get_config_caps(A2DP_CODEC_APTX_HD); 
    }
    
    A2dpInit(&A2DP_RUNDATA.inst[0].a2dpTask, A2DP_INIT_ROLE_SOURCE, NULL, num_endpoints, seps, 0);
}


/****************************************************************************
NAME    
    a2dp_set_state - Set A2DP state
*/
void a2dp_set_state(a2dpInstance *inst, A2DP_STATE_T new_state)
{
    if ((inst != NULL) && new_state < A2DP_STATES_MAX)
    {
        A2DP_STATE_T old_state = inst->a2dp_state;
        
        /* leaving current state */        
        a2dp_exit_state(inst);
        
        /* store new state */
        inst->a2dp_state = new_state;
        A2DP_DEBUG(("A2DP STATE: new state [%s]\n", a2dp_state_strings[new_state]));
        
        /* entered new state */
        a2dp_enter_state(inst, old_state);
    }
}


/****************************************************************************
NAME    
    a2dp_get_state - Gets A2DP state
*/
A2DP_STATE_T a2dp_get_state(a2dpInstance *inst)
{
    return inst->a2dp_state;
}


/****************************************************************************
NAME    
    a2dp_start_connection - Starts an A2DP connection
*/
void a2dp_start_connection(void)
{
    a2dpInstance *inst = NULL;
    
    if (!BdaddrIsZero(connection_mgr_get_remote_address()))
    {            
        inst = a2dp_get_instance_from_bdaddr(connection_mgr_get_remote_address());            
    
        if (inst == NULL)
        {
            inst = a2dp_get_free_instance();
            
            if (inst != NULL)
            {
                /* store address of device it's attempting to connect to */
                inst->addr = *connection_mgr_get_remote_address();
                /* don't know if A2DP is supported at the moment */
                inst->a2dp_support = A2DP_SUPPORT_UNKNOWN;
            }
        }
    
        A2DP_DEBUG(("A2DP:a2dp_start_connection\n"));
        DEBUG_BTADDR(connection_mgr_get_remote_address());
    
        if (inst != NULL)
        {           
            /* there is a free A2DP instance so initiate signalling connection */
            MessageSend(&inst->a2dpTask, A2DP_INTERNAL_SIGNALLING_CONNECT_REQ, 0);        
        }
        else
        {
            /* there is no free A2DP instance so signal to the app that the connection attempt has failed */            
            MessageSend(app_get_instance(), APP_CONNECT_FAIL_CFM, 0);
        }
    }
}


/****************************************************************************
NAME    
    a2dp_get_instance_from_device_id - Returns A2DP instance from Device ID
*/
a2dpInstance *a2dp_get_instance_from_device_id(uint16 device_id)
{
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst;
    
    for_all_a2dp_instance(index)
    {
        if ((inst != NULL) && inst->a2dp_device_id == device_id)
        {
            A2DP_DEBUG(("    instance from deviceID %d\n", device_id));
            return inst;
        }
        inst++;
    }
    
    return NULL;
}


/****************************************************************************
NAME    
    a2dp_get_instance_from_bdaddr - Returns A2DP instance from Bluetooth address
*/
a2dpInstance *a2dp_get_instance_from_bdaddr(const bdaddr *addr)
{
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst; 
    
    for_all_a2dp_instance(index)
    {
        if ( (inst != NULL) && !BdaddrIsZero(&inst->addr) && BdaddrIsSame(&inst->addr, addr))
        {
            A2DP_DEBUG(("    instance from bdaddr\n"));
            return inst;
        }
        inst++;
    }

    return NULL;
}


/****************************************************************************
NAME    
    a2dp_get_free_instance - Returns A2DP unused instance
*/
a2dpInstance *a2dp_get_free_instance(void)
{
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    

    for_all_a2dp_instance(index)
    {
        if ((inst != NULL) && BdaddrIsZero(&inst->addr))
        {
            A2DP_DEBUG(("    got free instance\n"));
            return inst;
        }
        inst++;
    }

    A2DP_DEBUG(("    no free instance\n"));
    
    return NULL;
}


/****************************************************************************
NAME    
    a2dp_init_instance - Initialises A2DP instance
*/
void a2dp_init_instance(a2dpInstance *inst)
{
    A2DP_DEBUG(("A2DP: a2dp_init_instance inst[0x%x]\n", (uint16)inst));
    inst->a2dpTask.handler = a2dp_msg_handler;
    a2dp_set_state(inst, A2DP_STATE_DISCONNECTED);
    inst->a2dp_device_id = A2DP_INVALID_ID;
    inst->a2dp_stream_id = A2DP_INVALID_ID; 
    inst->media_sink = 0;
    inst->a2dp_support = A2DP_SUPPORT_UNKNOWN;
    inst->a2dp_connection_retries = 0;
    inst->a2dp_suspending = 0;
    inst->a2dp_reconfiguring = FALSE;
    inst->a2dp_reconfigure_codec = 0;
    inst->a2dp_role = hci_role_master;
    inst->a2dp_quality = A2DP_AUDIO_QUALITY_UNKNOWN;
    BdaddrSetZero(&inst->addr);
}


/****************************************************************************
NAME    
    a2dp_get_number_connections - Returns the number of A2DP connections
*/
uint16 a2dp_get_number_connections(void)
{
    uint16 connections = 0;
    uint16 index;

    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    
    
    for_all_a2dp_instance(index)
    {
        if ((inst != NULL) && a2dp_is_connected(a2dp_get_state(inst)))
            connections++;
        inst++;
    }
    
    return connections;
}


/****************************************************************************
NAME    
    a2dp_disconnect_all - Disconnect all A2DP connections
*/
void a2dp_disconnect_all(void)
{
    uint16 index;
     a2dpInstance *inst = A2DP_RUNDATA.inst ;
    
    for_all_a2dp_instance(index)
    {
        A2DP_DEBUG(("A2DP: inst[0x%x]\n", (uint16)inst));
        if ((inst != NULL) && a2dp_is_connected(a2dp_get_state(inst)))
        {
            A2DP_DEBUG(("A2DP: CONNECTED inst[0x%x] state[0x%d]\n", (uint16)inst, a2dp_get_state(inst)));
            /* cancel any suspending attempt */
            inst->a2dp_suspending = 0;
            /* cancel any reconfigure attempt */
            inst->a2dp_reconfiguring = FALSE;
     
            if (a2dp_is_media(a2dp_get_state(inst)))
            {
                /* disconnect media first if it exists */
                a2dp_set_state(inst, A2DP_STATE_DISCONNECTING_MEDIA);
            }
            else
            {
                /* no media so disconnect signalling */
                a2dp_set_state(inst, A2DP_STATE_DISCONNECTING);
            }
        }
        inst++;
    }
}


/****************************************************************************
NAME    
    a2dp_set_sbc_config - Sets the SBC Stream-End Point configuration
*/
void a2dp_set_sbc_config(bool use_defaults)
{
    if (use_defaults)
    {
        a2dp_reset_codec_config(A2DP_CODEC_SBC);/* no change in configuration */
        a2dp_set_caps_values(A2DP_CODEC_SBC,sbc_sep);/* default End Point data */
    }
    else
    {        
        if(a2dp_get_codec_config(A2DP_CODEC_SBC))
        {         
            uint16 index;
            /* copy the original codec settings to the memory location */
            for (index = 0; index < sizeof(a2dp_sbc_caps_source); index++)
            { 
#ifdef PTS_TEST_ENABLED
                    if(A2DP_SBC_BLOCK_LENGTH_INDEX == index)
                    {
                        A2DP_RUNDATA.sbc_codec_config[A2DP_SBC_BLOCK_LENGTH_INDEX] =  a2dp_get_sbc_parameters();
                    }
                    else
                    {
                        a2dp_set_codec_config(index, A2DP_RUNDATA.sbc_codec_config,a2dp_sbc_caps_source);
                    }
#else
                    a2dp_set_codec_config(index, A2DP_RUNDATA.sbc_codec_config,a2dp_sbc_caps_source);
#endif
            }
            
            /* change as defined in PS Key data */
            /* if SPDIF is configured as an input, then only permit 44.1 or 48kHz sampling frequency. */
            if(audio_get_input_source() ==A2dpEncoderInputDeviceSPDIF )
            {
                /* clear out unsupported 16kHz and 32kHz frequency options if present,
                 * if neither of the permitted 44.1kHz or 48kHz are set, then default to 48kHz */
                uint8 ReadSamplingFrequency = a2dp_get_sbc_sampling_frequency();
                ReadSamplingFrequency &= ~(A2DP_SBC_SAMPLING_FREQ_16000 | A2DP_SBC_SAMPLING_FREQ_32000);
                a2dp_set_sampling_frequency(ReadSamplingFrequency);
                if (!(ReadSamplingFrequency & (A2DP_SBC_SAMPLING_FREQ_44100 | A2DP_SBC_SAMPLING_FREQ_48000)))
                {
                    ReadSamplingFrequency |= A2DP_SBC_SAMPLING_FREQ_48000;
                    a2dp_set_sampling_frequency(ReadSamplingFrequency);
                }
            }

            a2dp_set_codec_config_values_on_index(A2DP_SBC_SAMPLING_CHANNEL_INDEX,A2DP_RUNDATA.sbc_codec_config, a2dp_get_sbc_sampling_frequency() );
            a2dp_set_codec_config_values_on_index(A2DP_SBC_MIN_BITPOOL_INDEX,A2DP_RUNDATA.sbc_codec_config, a2dp_get_min_bit_pool());
            a2dp_set_codec_config_values_on_index(A2DP_SBC_MAX_BITPOOL_INDEX,A2DP_RUNDATA.sbc_codec_config, a2dp_get_max_bit_pool());
      
            /* update with the new caps */
            a2dp_set_codec_config_caps_values(&(A2DP_RUNDATA.sbc_caps.caps), &(A2DP_RUNDATA.sbc_codec_config));
        }
    }
}


/****************************************************************************
NAME    
    a2dp_set_faststream_config - Sets the Faststream Stream-End Point configuration
*/
void a2dp_set_faststream_config(bool use_defaults)
{
    if (use_defaults)
    {
        a2dp_reset_codec_config(A2DP_CODEC_FAST_STREAM);/* no change in configuration */
        a2dp_set_caps_values(A2DP_CODEC_FAST_STREAM,faststream_sep);/* default End Point data */
        A2DP_RUNDATA.faststream_caps.flush_timeout = A2DP_LOW_LATENCY_FLUSH_TIMEOUT; /* set flush timeout */
        
        A2DP_DEBUG(("A2DP: seid[0x%x] timeout[0x%x]\n", A2DP_RUNDATA.faststream_caps.seid, A2DP_RUNDATA.faststream_caps.flush_timeout));       
    }
    else
    {        
        if(a2dp_get_codec_config(A2DP_CODEC_FAST_STREAM))
        {           
            uint16 i;
            /* copy the original codec settings to the memory location */
            for (i = 0; i < sizeof(a2dp_faststream_caps_source); i++)
            { 
                a2dp_set_codec_config(i,A2DP_RUNDATA.faststream_codec_config,a2dp_faststream_caps_source);
            }

            /* change as defined in PS Key data */
            a2dp_set_codec_config_values_on_index(A2DP_FASTSTREAM_DIRECTION_INDEX,A2DP_RUNDATA.faststream_codec_config , a2dp_get_faststream_voice_music_support());
            a2dp_set_codec_config_values_on_index(A2DP_FASTSTREAM_SAMPLING_INDEX,A2DP_RUNDATA.faststream_codec_config, a2dp_get_faststream_sampling_frequency());
            /* update with the new caps */
            a2dp_set_codec_config_caps_values(&(A2DP_RUNDATA.faststream_caps.caps),&(A2DP_RUNDATA.faststream_codec_config));
        }
    }
}


/****************************************************************************
NAME    
    a2dp_set_aptx_config - Sets the APT-X Stream-End Point configuration
*/
void a2dp_set_aptx_config(bool use_defaults)
{
    if (use_defaults)
    {
        a2dp_reset_codec_config(A2DP_CODEC_APTX);/* no change in configuration */
        a2dp_set_caps_values(A2DP_CODEC_APTX,aptx_sep);/* default End Point data */
    }
    else
    {
        if(a2dp_get_codec_config(A2DP_CODEC_APTX))
        {        
            uint16 i;
            /* copy the original codec settings to the memory location */
            for (i = 0; i < sizeof(a2dp_aptx_caps_source); i++)
            { 
                 a2dp_set_codec_config(i,A2DP_RUNDATA.aptx_codec_config,a2dp_aptx_caps_source);
            }

            /* change as defined in PS Key data */
            a2dp_set_codec_config_values_on_index(A2DP_APTX_SAMPLING_RATE_INDEX,A2DP_RUNDATA.aptx_codec_config, (a2dp_get_aptx_sampling_frequency() & 0xf0) | A2DP_APTX_CHANNEL_MODE_STEREO );
            /* update with the new caps */
            a2dp_set_codec_config_caps_values(&(A2DP_RUNDATA.aptx_caps.caps),&(A2DP_RUNDATA.aptx_codec_config));
        }
    }
}


/****************************************************************************
NAME    
    a2dp_set_aptxLowLatency_config - Sets the APT-X Low Latency Stream-End Point configuration
*/
void a2dp_set_aptxLowLatency_config(bool use_defaults)
{
    if (use_defaults)
    {
        a2dp_reset_codec_config(A2DP_CODEC_APTX_LOW_LATENCY);/* no change in configuration */
        a2dp_set_caps_values(A2DP_CODEC_APTX_LOW_LATENCY,aptxLowLatency_sep);/* default End Point data */
    }
    else
    {
        if(a2dp_get_codec_config(A2DP_CODEC_APTX_LOW_LATENCY))
        {        
            uint16 i;
            /* copy the original codec settings to the memory location */
            for (i = 0; i < sizeof(a2dp_aptxLowLatency_caps_source); i++)
            { 
                a2dp_set_codec_config(i,A2DP_RUNDATA.aptxLowLatency_codec_config,a2dp_aptxLowLatency_caps_source);
            }

            /* change as defined in PS Key data */
            a2dp_set_codec_config_values_on_index(A2DP_APTX_SAMPLING_RATE_INDEX,A2DP_RUNDATA.aptxLowLatency_codec_config, (a2dp_get_aptxLL_sampling_frequency() & 0xf0) | A2DP_APTX_CHANNEL_MODE_STEREO );
            a2dp_set_codec_config_values_on_index(A2DP_APTX_DIRECTION_INDEX,A2DP_RUNDATA.aptxLowLatency_codec_config, A2DP_APTX_LOWLATENCY_NEW_CAPS );
            if (a2dp_get_aptxLL_bidiirectional_value())
            {
                a2dp_set_codec_config_values_on_index(A2DP_APTX_DIRECTION_INDEX,A2DP_RUNDATA.aptxLowLatency_codec_config, (A2DP_RUNDATA.aptxLowLatency_codec_config[A2DP_APTX_DIRECTION_INDEX] )|(A2DP_APTX_LOWLATENCY_VOICE_16000));
            }
            /* update with the new caps */
            a2dp_set_codec_config_caps_values(&(A2DP_RUNDATA.aptxLowLatency_caps.caps),&(A2DP_RUNDATA.aptxLowLatency_codec_config));
        }
    }
}


/****************************************************************************
NAME    
    a2dp_set_aptxhd_config - Sets the aptX-HD Stream-End Point configuration
*/
void a2dp_set_aptxhd_config(bool use_defaults)
{
    if (use_defaults)
    {
        a2dp_reset_codec_config(A2DP_CODEC_APTX_HD);/* no change in configuration */
        a2dp_set_caps_values(A2DP_CODEC_APTX_HD,aptxhd_sep);/* default End Point data */
    }
    else
    {
        if(a2dp_get_codec_config(A2DP_CODEC_APTX_HD))
        {        
            uint16 i;
            A2DP_DEBUG(("sizeof(a2dp_aptxhd_caps_source) : %d\n",sizeof(a2dp_aptxhd_caps_source)));
            /* copy the original codec settings to the memory location */
            for (i = 0; i < sizeof(a2dp_aptxhd_caps_source); i++)
            { 
                a2dp_set_codec_config(i,A2DP_RUNDATA.aptxhd_codec_config,a2dp_aptxhd_caps_source);
            }

            /* change as defined in PS Key data */
            a2dp_set_codec_config_values_on_index(A2DP_APTX_SAMPLING_RATE_INDEX,A2DP_RUNDATA.aptxhd_codec_config ,(a2dp_get_aptxHD_sampling_frequency() & 0xf0) | A2DP_APTX_CHANNEL_MODE_STEREO);
            /* update with the new caps */
            a2dp_set_codec_config_caps_values(&(A2DP_RUNDATA.aptxhd_caps.caps),&(A2DP_RUNDATA.aptxhd_codec_config));
        }
    }
}


/****************************************************************************
NAME    
    a2dp_get_sbc_caps_size - Returns the SBC Stream-End Point configuration size
*/
uint16 a2dp_get_sbc_caps_size(void)
{
    return sizeof(a2dp_sbc_caps_source);
}


/****************************************************************************
NAME    
    a2dp_get_faststream_caps_size - Returns the Faststream Stream-End Point configuration size
*/
uint16 a2dp_get_faststream_caps_size(void)
{
    return sizeof(a2dp_faststream_caps_source);
}


/****************************************************************************
NAME    
    a2dp_get_aptx_caps_size - Returns the APT-X Stream-End Point configuration size
*/
uint16 a2dp_get_aptx_caps_size(void)
{
    return sizeof(a2dp_aptx_caps_source);
}


/****************************************************************************
NAME    
    a2dp_get_aptxLowLatency_caps_size - Returns the APT-X Low Latency Stream-End Point configuration size
*/
uint16 a2dp_get_aptxLowLatency_caps_size(void)
{
    return sizeof(a2dp_aptxLowLatency_caps_source);
}


/****************************************************************************
NAME    
    a2dp_get_aptxhd_caps_size - Returns the aptX-HD Stream-End Point configuration size
*/
uint16 a2dp_get_aptxhd_caps_size(void)
{
    return sizeof(a2dp_aptxhd_caps_source);
}


/****************************************************************************
NAME    
    a2dp_sdp_search_cfm - Handles an A2DP service search result
*/
void a2dp_sdp_search_cfm(a2dpInstance *inst, const CL_SDP_SERVICE_SEARCH_CFM_T *message)
{
    switch (a2dp_get_state(inst))
    {
        case A2DP_STATE_CONNECTING_LOCAL:
        {
            if (message->status == sdp_response_success)
            {
                A2DP_DEBUG(("A2DP SDP ok, issue connect\n"));
                inst->a2dp_support = A2DP_SUPPORT_YES;
                /* now issue connect request */
                if (!A2dpSignallingConnectRequest(&inst->addr))
                {
                    MessageSend(app_get_instance(), APP_CONNECT_FAIL_CFM, 0);         
                }                
            }
            else
            {
                MessageSend(app_get_instance(), APP_CONNECT_FAIL_CFM, 0);
                a2dp_init_instance(inst); 
            }
        }
        break;
        
        default:
        {
            
        }
        break;
    }
}


/****************************************************************************
NAME    
    a2dp_remote_features_cfm - Called when the remote device features have been read
*/
void a2dp_remote_features_cfm(a2dpInstance *inst, const CL_DM_REMOTE_FEATURES_CFM_T *message)
{
    A2DP_AUDIO_QUALITY_T quality = A2DP_AUDIO_QUALITY_UNKNOWN;
    A2DP_AUDIO_QUALITY_T lowest_quality = a2dp_get_lowest_quality();
    
    /* Determine the sort of audio quality a link could support. */
    if ((message->features[1] & A2DP_SUPPORTED_FEATURES_WORD2_EDR_ACL_2MBPS_3MBPS) && 
        (message->features[2] & A2DP_SUPPORTED_FEATURES_WORD3_EDR_ACL_3SLOT_5SLOT))
    {
        /* Capable of supporting EDR ACL 2Mbps and/or 3Mbps with three or five slot packets */
        quality = A2DP_AUDIO_QUALITY_HIGH;
    }
    else if (message->features[0] & A2DP_SUPPORTED_FEATURES_WORD1_5SLOT)
    {
        /* Capable of supporting BR ACL 1Mbps with five slot packets */
        quality = A2DP_AUDIO_QUALITY_MEDIUM;
    }
    else
    {
        /* All other data rate and slot size combinations only capable of supporting a low data rate */
        quality = A2DP_AUDIO_QUALITY_LOW;
    }
    
    /* store audio quality for A2DP link */
    if(inst != NULL) 
    inst->a2dp_quality = quality;

    /* check DualStream quality */
    if ((a2dp_get_number_connections() > 1) && (lowest_quality <= A2DP_AUDIO_QUALITY_MEDIUM))
    {
        /* If the quality is too low in DualStream mode then must disconnect A2DP for 2nd device */
        MessageSend(&inst->a2dpTask, A2DP_INTERNAL_SIGNALLING_DISCONNECT_REQ, 0);
        A2DP_DEBUG(("A2DP disconnecting 2nd link due to quality\n"));
    }
    else
    {
        /* may need to update bitpool for SBC links */
        a2dp_update_sbc_bitpool();
    }
    
    A2DP_DEBUG(("A2DP link quality [%d]\n", quality));
}


/****************************************************************************
NAME    
    a2dp_resume_audio - This is called to Resume the A2DP audio, normally when an (e)SCO audio connection has been removed
*/
void a2dp_resume_audio(void)
{
    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    uint16 index = 0;
    
    A2DP_DEBUG(("A2DP a2dp_resume_audio\n"));
    
    for_all_a2dp_instance(index)
    {
        A2DP_STATE_T a2dp_state = A2DP_STATE_DISCONNECTED ;        
        
        if(inst != NULL)
        {
		  /* cancel pending suspend requests */
          MessageCancelAll(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_SUSPEND_REQ);
          a2dp_state = inst->a2dp_state;
        }
        
        switch (a2dp_state)
        {
            case A2DP_STATE_CONNECTED_SIGNALLING:
            {
                if(inst != NULL)
                a2dp_set_state(inst, A2DP_STATE_CONNECTING_MEDIA_LOCAL);
            }
            return;
            
            case A2DP_STATE_CONNECTED_MEDIA:
            case A2DP_STATE_CONNECTED_MEDIA_SUSPENDED:
            {
                if(inst != NULL)
                a2dp_set_state(inst, A2DP_STATE_CONNECTED_MEDIA_STARTING_LOCAL); 
            }
            return;
            
            case A2DP_STATE_CONNECTED_MEDIA_SUSPENDING_LOCAL:
            {
                if(inst != NULL)
                MessageSendConditionally(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_START_REQ, 0, &inst->a2dp_suspending);
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


/****************************************************************************
NAME    
    a2dp_route_all_audio - Routes audio for all A2DP connections
*/
void a2dp_route_all_audio(void)
{
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    

    for_all_a2dp_instance(index)
    {   
        if ( (inst != NULL) && a2dp_is_connected(a2dp_get_state(inst)))
        {
            /* initiate the audio connection */    
            MessageSend(&inst->a2dpTask, A2DP_INTERNAL_CONNECT_AUDIO_REQ, 0);
        }
        inst++;
    }
    
    /* reset audio delay flag */
    audio_set_a2dp_conn_delay(FALSE);
}


/****************************************************************************
NAME    
    a2dp_suspend_all_audio - Suspends audio for all A2DP connections
*/
void a2dp_suspend_all_audio(void)
{
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    
    for_all_a2dp_instance(index)
    {   
        if ((inst != NULL) && a2dp_is_streaming(a2dp_get_state(inst)))
        {
            /* suspend the audio connection */    
            MessageSend(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_SUSPEND_REQ, 0);
        }
        inst++;
    }   
}


#ifdef INCLUDE_APPLICATION_A2DP_CODEC_CONFIGURATION
/****************************************************************************
NAME    
    a2dp_configure_sbc - Configures the SBC codec
*/
bool a2dp_configure_sbc(A2DP_CODEC_CONFIGURE_IND_T *message)
{
    uint16 local_index = 6;
    uint16 remote_index = 0;    
    uint8 min_bitpool = 0;
    uint8 max_bitpool = 0;
    uint8 sbc_caps= 0;

    while(AVDTP_SERVICE_MEDIA_CODEC  !=  message->codec_service_caps[remote_index])
            remote_index++;

    remote_index = remote_index + 4;

    sbc_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_SBC);
    /* Select Sample rate */
    if ((sbc_caps& 0x10)  && (message->codec_service_caps[remote_index] & 0x10))
    {
        /* choose 48kHz */
        message->codec_service_caps[remote_index] &= 0x1f;
    }
    else if ((sbc_caps& 0x20) &&
             (message->codec_service_caps[remote_index] & 0x20))
    {
        /* choose 44.1kHz */
        message->codec_service_caps[remote_index] &= 0x2f;
    }
    else if ((sbc_caps & 0x40) && 
             (message->codec_service_caps[remote_index] & 0x40))
    {
        /* choose 32kHz */
        message->codec_service_caps[remote_index] &= 0x4f;
    }
    else if ((sbc_caps & 0x80) && 
             (message->codec_service_caps[remote_index] & 0x80))
    {
        /* choose 16kHz */
        message->codec_service_caps[remote_index] &= 0x8f;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    /* Select Channel Mode */
    if ((sbc_caps & 0x01) && 
        (message->codec_service_caps[remote_index] & 0x01))
    {
        /* choose joint stereo */
        message->codec_service_caps[remote_index] &= 0xf1;
    }
    else if ((sbc_caps & 0x02) && 
             (message->codec_service_caps[remote_index] & 0x02))
    {
        /* choose stereo */
        message->codec_service_caps[remote_index] &= 0xf2;
    }
    else if ((sbc_caps & 0x04) && 
             (message->codec_service_caps[remote_index] & 0x04))
    {
        /* choose dual mode */
        message->codec_service_caps[remote_index] &= 0xf4;
    }
    else if ((sbc_caps& 0x08) && 
             (message->codec_service_caps[remote_index] & 0x08))
    {
        /* choose dual mode */
        message->codec_service_caps[remote_index] &= 0xf8;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    /* process next data octet */
    local_index++;
    remote_index++;

     sbc_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_SBC);
    
    /* Select Block Length */
    if ((sbc_caps & 0x10) && 
        (message->codec_service_caps[remote_index] & 0x10))
    {
        /* choose 16 */
        message->codec_service_caps[remote_index] &= 0x1f;
    }
    else if ((sbc_caps & 0x20) && 
             (message->codec_service_caps[remote_index] & 0x20))
    {
        /* choose 12 */
        message->codec_service_caps[remote_index] &= 0x2f;
    }
    else if ((sbc_caps & 0x40) && 
             (message->codec_service_caps[remote_index] & 0x40))
    {
        /* choose 8 */
        message->codec_service_caps[remote_index] &= 0x4f;
    }
    else if ((sbc_caps & 0x80) && 
             (message->codec_service_caps[remote_index] & 0x80))
    {
        /* choose 4 */
        message->codec_service_caps[remote_index] &= 0x8f;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
  
    /* Select Subbands */
    if ((sbc_caps & 0x04) && 
        (message->codec_service_caps[remote_index] & 0x04))
    {
        /* choose 8 */
        message->codec_service_caps[remote_index] &= 0xf7;
    }
    else if ((sbc_caps & 0x08) && 
             (message->codec_service_caps[remote_index] & 0x08))
    {
        /* choose 4 */
        message->codec_service_caps[remote_index] &= 0xfb;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
      
    /* Select Allocation Method */
    if ((sbc_caps & 0x01) && 
        (message->codec_service_caps[remote_index] & 0x01))
    {
        /* choose Loudness */
        message->codec_service_caps[remote_index] &= 0xfd;
    }
    else if ((sbc_caps & 0x02) && 
             (message->codec_service_caps[remote_index] & 0x02))
    {
        /* choose SNR */
        message->codec_service_caps[remote_index] &= 0xfe;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    /* process next data octet */
    local_index++;
    remote_index++;

     /* Select the minimum bitpool value based on local and remote settings */
    min_bitpool = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_SBC);

    if (min_bitpool > message->codec_service_caps[remote_index])
        message->codec_service_caps[remote_index] = min_bitpool;
    
    /* process next data octet */
    local_index++;
    remote_index++;
    
    sbc_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_SBC);
    /* Select the maximum bitpool value based on local and remote settings */
    max_bitpool =sbc_caps;
    if (max_bitpool < message->codec_service_caps[remote_index])
        message->codec_service_caps[remote_index] = max_bitpool;
    
    return TRUE;
}


/****************************************************************************
NAME    
    a2dp_configure_faststream - Configures the FastStream codec
*/
bool a2dp_configure_faststream(A2DP_CODEC_CONFIGURE_IND_T *message)
{
    uint16 local_index = 12;
    uint16 remote_index = 0;
    bool audio_in_mic = FALSE;
    bool audio_out_music = FALSE;
    uint8 faststream_caps = 0;

    while(AVDTP_SERVICE_MEDIA_CODEC  !=  message->codec_service_caps[remote_index])
            remote_index++;

    remote_index = remote_index + 10;

    faststream_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_FAST_STREAM) ;
    /* Choose audio direction */
    if ((faststream_caps& 0x03) &&
        (message->codec_service_caps[remote_index] & 0x03))
    {
        /* bi-directional audio */
        message->codec_service_caps[remote_index] = 0x03;
        audio_in_mic = TRUE;
        audio_out_music = TRUE;
    }
    else if ((faststream_caps& 0x01) &&
             (message->codec_service_caps[remote_index] & 0x01))
    {
        /* audio out music channel */
        message->codec_service_caps[remote_index] = 0x01;
        audio_out_music = TRUE;
    }
    else if ((faststream_caps & 0x02) &&
             (message->codec_service_caps[remote_index] & 0x02))
    {
        /* audio in mic channel */
        message->codec_service_caps[remote_index] = 0x02;
        audio_in_mic = TRUE;
    }    
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    /* process next data octet */
    local_index++;
    remote_index++;

     faststream_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_FAST_STREAM) ;
    /* Choose Sample rates */
    if ((faststream_caps & 0x20) &&
        (message->codec_service_caps[remote_index] & 0x20))
    {
        /* audio in mic channel rate */
        message->codec_service_caps[remote_index] &= 0x2f;
    }
    else if (audio_in_mic)
    {
        /* audio in configured but no sample rate, return error */
        return FALSE;
    }
    else if ((faststream_caps & 0x01) &&
             (message->codec_service_caps[remote_index] & 0x01) &&
             (audio_get_a2dp_input_device_type() == A2dpEncoderInputDeviceUsb))
    {
        /* choose 48kHz audio out music rate */
        message->codec_service_caps[remote_index] &= 0xf1;
    }
    else if ((faststream_caps & 0x02) &&
             (message->codec_service_caps[remote_index] & 0x01))
    {
        /* choose 44.1kHz audio out music rate */
        message->codec_service_caps[remote_index] &= 0xf2;
    }
    else if (audio_out_music)
    {
        /* audio out configured but no sample rate, return error */
        return FALSE;
    }   
    
    return TRUE;
}


/****************************************************************************
NAME    
    a2dp_configure_aptx - Configures the APT-X codec
*/
bool a2dp_configure_aptx(A2DP_CODEC_CONFIGURE_IND_T *message)
{
    uint16 local_index = 12;
    uint16 remote_index = 0; 
    uint8 aptx_caps = 0;

    while(AVDTP_SERVICE_MEDIA_CODEC  !=  message->codec_service_caps[remote_index])
            remote_index++;

    remote_index = remote_index + 10;

    aptx_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_APTX);
    /* Check Sample Rates */
    if ((aptx_caps & 0x10) &&
        (message->codec_service_caps[remote_index] & 0x10))
    {
        /* 48kHz */
        message->codec_service_caps[remote_index] &= 0x1f;
    }
    else if ((aptx_caps & 0x20) &&
             (message->codec_service_caps[remote_index] & 0x20))
    {
        /* 44.1kHz */
        message->codec_service_caps[remote_index] &= 0x2f;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    /* Select Channel Mode */
    if ((aptx_caps  & 0x01) && 
        (message->codec_service_caps[remote_index] & 0x01))
    {
        /* choose joint stereo */
        message->codec_service_caps[remote_index] &= 0xf1;
    }
    else if ((aptx_caps & 0x02) && 
             (message->codec_service_caps[remote_index] & 0x02))
    {
        /* choose stereo */
        message->codec_service_caps[remote_index] &= 0xf2;
    }
    else if ((aptx_caps & 0x04) && 
             (message->codec_service_caps[remote_index] & 0x04))
    {
        /* choose dual mode */
        message->codec_service_caps[remote_index] &= 0xf4;
    }
    else if ((aptx_caps & 0x08) && 
             (message->codec_service_caps[remote_index] & 0x08))
    {
        /* choose dual mode */
        message->codec_service_caps[remote_index] &= 0xf8;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    return TRUE;
}


/****************************************************************************
NAME    
    a2dp_configure_aptxLowLatency - Configures the APT-X Low Latency codec
*/
bool a2dp_configure_aptxLowLatency(A2DP_CODEC_CONFIGURE_IND_T *message)
{
    uint16 local_index = 12;
    uint16 remote_index = 0; 
    uint8 aptx_lowLatency_caps = 0;

    while(AVDTP_SERVICE_MEDIA_CODEC  !=  message->codec_service_caps[remote_index])
            remote_index++;

    remote_index = remote_index + 10;

    aptx_lowLatency_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_APTX_LOW_LATENCY) ;
    /* Check Sample Rates */
    if ((aptx_lowLatency_caps & 0x10) &&
        (message->codec_service_caps[remote_index] & 0x10))
    {
        /* 48kHz */
        message->codec_service_caps[remote_index] &= 0x1f;
    }
    else if ((aptx_lowLatency_caps & 0x20) &&
             (message->codec_service_caps[remote_index] & 0x20))
    {
        /* 44.1kHz */
        message->codec_service_caps[remote_index] &= 0x2f;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    /* Select Channel Mode */
    if ((aptx_lowLatency_caps & 0x01) && 
        (message->codec_service_caps[remote_index] & 0x01))
    {
        /* choose joint stereo */
        message->codec_service_caps[remote_index] &= 0xf1;
    }
    else if ((aptx_lowLatency_caps & 0x02) && 
             (message->codec_service_caps[remote_index] & 0x02))
    {
        /* choose stereo */
        message->codec_service_caps[remote_index] &= 0xf2;
    }
    else if ((aptx_lowLatency_caps & 0x04) && 
             (message->codec_service_caps[remote_index] & 0x04))
    {
        /* choose dual mode */
        message->codec_service_caps[remote_index] &= 0xf4;
    }
    else if ((aptx_lowLatency_caps & 0x08) && 
             (message->codec_service_caps[remote_index] & 0x08))
    {
        /* choose dual mode */
        message->codec_service_caps[remote_index] &= 0xf8;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
	
	/* process next data octet */
    local_index++;
    remote_index++;

    aptx_lowLatency_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_APTX_LOW_LATENCY) ;
    /* Check new low latency caps support */
	if ((aptx_lowLatency_caps & 0x02) && 
        (message->codec_service_caps[remote_index] & 0x02))
    {
        /* For the low latency parameters the source dongle sets the values
	       irrespective of what the remote device sends */ 
		remote_index = 13;
	    message->codec_service_caps[remote_index++] = A2DP_APTX_LOWLATENCY_TCL_LSB;
	    message->codec_service_caps[remote_index++] = A2DP_APTX_LOWLATENCY_TCL_MSB;
	    message->codec_service_caps[remote_index++] = A2DP_APTX_LOWLATENCY_ICL_LSB;
	    message->codec_service_caps[remote_index++] = A2DP_APTX_LOWLATENCY_ICL_MSB;
	    message->codec_service_caps[remote_index++] = A2DP_APTX_LOWLATENCY_MAX_RATE;
	    message->codec_service_caps[remote_index++] = A2DP_APTX_LOWLATENCY_AVG_TIME;
	    message->codec_service_caps[remote_index++] = A2DP_APTX_LOWLATENCY_GWBL_LSB;
	    message->codec_service_caps[remote_index]   = A2DP_APTX_LOWLATENCY_GWBL_MSB;
    }
  
    return TRUE;
}


/****************************************************************************
NAME    
    a2dp_configure_aptxhd - Configures the aptX-HD codec
*/
bool a2dp_configure_aptxhd(A2DP_CODEC_CONFIGURE_IND_T *message)
{
    uint16 local_index = 12;
    uint16 remote_index = 0; 
    uint8 aptx_HD_caps = 0;

    while(AVDTP_SERVICE_MEDIA_CODEC  !=  message->codec_service_caps[remote_index])
            remote_index++;

    remote_index = remote_index + 10;

    aptx_HD_caps = a2dp_get_caps_value_by_index(local_index,A2DP_CODEC_APTX_HD);
    /* Check Sample Rates */
    if ((aptx_HD_caps & 0x10) &&
        (message->codec_service_caps[remote_index] & 0x10))
    {
        /* 48kHz */
        message->codec_service_caps[remote_index] &= 0x1f;
    }
    else if ((aptx_HD_caps  & 0x20) &&
             (message->codec_service_caps[remote_index] & 0x20))
    {
        /* 44.1kHz */
        message->codec_service_caps[remote_index] &= 0x2f;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    /* Select Channel Mode */
    if ((aptx_HD_caps & 0x01) && 
        (message->codec_service_caps[remote_index] & 0x01))
    {
        /* choose joint stereo */
        message->codec_service_caps[remote_index] &= 0xf1;
    }
    else if ((aptx_HD_caps & 0x02) && 
             (message->codec_service_caps[remote_index] & 0x02))
    {
        /* choose stereo */
        message->codec_service_caps[remote_index] &= 0xf2;
    }
    else if ((aptx_HD_caps & 0x04) && 
             (message->codec_service_caps[remote_index] & 0x04))
    {
        /* choose dual mode */
        message->codec_service_caps[remote_index] &= 0xf4;
    }
    else if ((aptx_HD_caps & 0x08) && 
             (message->codec_service_caps[remote_index] & 0x08))
    {
        /* choose dual mode */
        message->codec_service_caps[remote_index] &= 0xf8;
    }
    else
    {
        /* error occured so return failure */
        return FALSE;
    }
    
    return TRUE;
}
#endif /* INCLUDE_APPLICATION_A2DP_CODEC_CONFIGURATION */


/****************************************************************************
NAME    
    a2dp_get_sbc_bitpool - Gets the SBC bitpool that should be used for the audio stream
*/
bool a2dp_get_sbc_bitpool(uint8 *bitpool, uint8 *bad_link_bitpool, bool *multiple_streams)
{
    a2dp_codec_settings *settings = NULL;
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    uint8 min_bitpool = 0;
    uint8 max_bitpool = 0;
    uint8 min_configured_bp = 0;
    uint8 max_configured_bp = 0;
    uint8 optimal_bitpool = 0;
    hci_role role = hci_role_master;
    A2DP_AUDIO_QUALITY_T quality = A2DP_AUDIO_QUALITY_HIGH;
    uint16 a2dp_media_streams = 0;
    a2dp_codecs_config_def_t a2dp_config_data;
    
    memset(&a2dp_config_data,0,sizeof(a2dp_codecs_config_def_t));
    
    *bitpool = 0;
    *bad_link_bitpool = 0;
    *multiple_streams = FALSE;

    /*Get the codec config values from the  a2dp module config xml files.*/
    a2dp_get_codec_enable_values(&a2dp_config_data);
    if(!(a2dp_config_data.a2dpCodecsSBCEnable))
    {
        /* return if SBC not enabled */
        return FALSE;
    }
    
    /* loop through all A2DP connections to look for open SBC media channels */
    for_all_a2dp_instance(index)
    {
        if ((inst != NULL) && a2dp_is_media(a2dp_get_state(inst)))
        {
            settings = A2dpCodecGetSettings(inst->a2dp_device_id, inst->a2dp_stream_id);
        
            if (settings)
            {
                if (a2dp_seid_is_sbc(settings->seid))
                {
                    /* get min and max bitpools from configured codec settings */
                    min_configured_bp = 0;
                    max_configured_bp = 0;
                    if (settings->size_configured_codec_caps >= sizeof(a2dp_sbc_caps_source))
                    {
                        if ((settings->configured_codec_caps[A2DP_SERVICE_TRANSPORT_INDEX] == AVDTP_SERVICE_MEDIA_TRANSPORT) &&
                            (settings->configured_codec_caps[A2DP_SERVICE_CODEC_INDEX] == AVDTP_SERVICE_MEDIA_CODEC) &&
                            (settings->configured_codec_caps[A2DP_MEDIA_CODEC_INDEX] == AVDTP_MEDIA_CODEC_SBC))
                        {
                            min_configured_bp = settings->configured_codec_caps[A2DP_SBC_MIN_BITPOOL_INDEX];
                            max_configured_bp = settings->configured_codec_caps[A2DP_SBC_MAX_BITPOOL_INDEX];
                        }
                    }
                    
                    /* check if the bitpool limits need to be updated based on all configured A2DP streams */
                    if (!min_bitpool || (min_bitpool && min_configured_bp && (min_configured_bp > min_bitpool)))
                    {
                        /* store the new min bitpool */
                        min_bitpool = min_configured_bp;
                    }
                    if (!max_bitpool || (max_bitpool && max_configured_bp && (max_configured_bp < max_bitpool)))
                    {
                        /* store the new max and optimal bitpool */
                        max_bitpool = max_configured_bp;
                        optimal_bitpool = settings->codecData.bitpool;
                    }
                    /* store worst case audio quality */
                    if (inst->a2dp_quality < quality)
                        quality = inst->a2dp_quality;
                    if (inst->a2dp_role == hci_role_slave)
                        role = hci_role_slave;
                
                    a2dp_media_streams++;
                }
            
                memory_free(settings);
            }
        }
        inst++;
    }

    if (a2dp_get_sbc_force_max_bit_pool() && max_bitpool)
    {
        /* choose max bitpool */
        optimal_bitpool = max_bitpool;
        
        /* make sure chosen bitpool is not outside local bitpool settings */
        /* check min bitpool */
        if (a2dp_get_caps_value_by_index(A2DP_SBC_MIN_BITPOOL_INDEX,A2DP_CODEC_SBC) > optimal_bitpool)
            optimal_bitpool = a2dp_get_caps_value_by_index(A2DP_SBC_MIN_BITPOOL_INDEX,A2DP_CODEC_SBC);    
        /* check max bitpool */
        if (a2dp_get_caps_value_by_index(A2DP_SBC_MAX_BITPOOL_INDEX,A2DP_CODEC_SBC) < optimal_bitpool)
            optimal_bitpool = a2dp_get_caps_value_by_index(A2DP_SBC_MAX_BITPOOL_INDEX,A2DP_CODEC_SBC);
    }
    
    /* if there are multiple A2DP streams then might need to adjust bitpool further */
    if (a2dp_media_streams > 1)
    {
        if (role == hci_role_slave)
        {
            /* reduce quality futher if scatternet */
            if (quality > A2DP_AUDIO_QUALITY_LOW)
                quality--;
        }
        /* reduce bitpool if we need to stream at lower rate */
        if (a2dp_max_bitpool_array[quality] < optimal_bitpool)
        {
            optimal_bitpool = a2dp_max_bitpool_array[quality];                        
        }
        *bad_link_bitpool = a2dp_max_bitpool_poor_link_array[quality];

        /* make sure bitpool selection hasn't gone below the minimum */
        if (optimal_bitpool < min_bitpool)
            optimal_bitpool = min_bitpool;
        if (*bad_link_bitpool < min_bitpool)
            *bad_link_bitpool = min_bitpool;
        
        *multiple_streams = TRUE;
    }       
    
    /* return bitpools */
    if (a2dp_media_streams)
    {
        *bitpool = optimal_bitpool;
        if ((*bad_link_bitpool == 0) || (*bad_link_bitpool > *bitpool))
        {
            *bad_link_bitpool = *bitpool;
        }

        A2DP_DEBUG(("A2DP SBC bitpool [%d] bad_link_bitpool[%d]\n", *bitpool, *bad_link_bitpool));

        return TRUE;
    }
    
    return FALSE;
}


/****************************************************************************
NAME    
    a2dp_update_sbc_bitpool - Update the SBC bitpool that should be used for the audio stream
*/
void a2dp_update_sbc_bitpool(void)
{
    uint8 bitpool;
    uint8 bad_link_bitpool;
    bool multiple_streams;
          
    if (A2DP_DUALSTREAM_ENABLED)
    {
        if (a2dp_get_sbc_bitpool(&bitpool, &bad_link_bitpool, &multiple_streams))
        {
            if (multiple_streams)
            {
                /* Send new bitpool levels to DSP */
                audio_a2dp_update_bitpool(bitpool, bad_link_bitpool);
            }
        }
    }
}


/****************************************************************************
NAME    
    a2dp_store_role - Stores the role for the link (Master/Slave)
*/
void a2dp_store_role(bdaddr addr, hci_role role)
{
    a2dpInstance *inst = a2dp_get_instance_from_bdaddr(&addr);
    
    if (inst != NULL)
    {
        inst->a2dp_role = role; 
        
        /* may need to update bitpool for SBC links */
        a2dp_update_sbc_bitpool();
        
        A2DP_DEBUG(("A2DP new role [%d]\n", role));
    }
}

/****************************************************************************
NAME    
    a2dp_is_connecting - Returns if the A2DP profile is currently connecting.
*/
bool a2dp_is_connecting(void)
{
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    A2DP_STATE_T state;
    
    for_all_a2dp_instance(index)
    {
        if (inst)
        {
            state = a2dp_get_state(inst);
            if ((state == A2DP_STATE_CONNECTING_LOCAL) || (state == A2DP_STATE_CONNECTING_REMOTE))
                return TRUE;
        }
        inst++;
    }
    
    return FALSE;
}

/****************************************************************************
NAME    
    a2dp_allow_more_connections - Check if more A2DP connections are allowed
*/
bool a2dp_allow_more_connections(void)
{
    if (connection_mgr_is_a2dp_profile_enabled() && 
        A2DP_DUALSTREAM_ENABLED &&
        (a2dp_get_number_connections() < A2DP_ENABLED_INSTANCES))
    {
        return TRUE;
    }
    
    return FALSE;
}


/****************************************************************************
NAME    
    a2dp_disconnect_media - Closes all open A2DP media connections and returns if A2DP media needs to be closed
*/
bool a2dp_disconnect_media(void)
{
    uint16 index;
    A2DP_STATE_T state;
    bool disconnect_required = FALSE;

    a2dpInstance *inst = A2DP_RUNDATA.inst ;

    for_all_a2dp_instance(index)
    {
        state = a2dp_get_state(inst);
        if (a2dp_is_media(state))
        {
            MessageSend(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_CLOSE_REQ, 0);
            disconnect_required = TRUE;
        }
        inst++;
    }
    
    return disconnect_required;
}


/****************************************************************************
NAME    
    a2dp_any_media_connections - This function returns if any media connections are still active
*/
bool a2dp_any_media_connections(void)
{
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    A2DP_STATE_T state;
 
    for_all_a2dp_instance(index)
    {
        if(inst)
        {
            state = a2dp_get_state(inst);
            if (state >= A2DP_STATE_CONNECTED_MEDIA)
            {
                return TRUE;       
            }
        }
        inst++;
    }
    
    return FALSE;
}


/****************************************************************************
NAME    
    a2dp_get_connected_addr - This function returns the addresses of any connected A2DP devices.

*/
bool a2dp_get_connected_addr(bdaddr *addr_a, bdaddr *addr_b)
{
    uint16 index;
    a2dpInstance *inst = A2DP_RUNDATA.inst ;
    bool result = FALSE;
    uint16 count = 0;


    for_all_a2dp_instance(index)
    {
        if (inst)
        {
            if (a2dp_is_connected(a2dp_get_state(inst)))
            {
                if (!count)
                {
                    *addr_a = inst->addr;
                }
                else
                {
                    *addr_b = inst->addr;
                }
                count++;
                result = TRUE;       
            }
        }
        inst++;            
    }
    return result;
}


/****************************************************************************
NAME    
    a2dp_exit_state - Exits an A2DP state
*/
static void a2dp_exit_state(a2dpInstance *inst)
{
    if(inst != NULL)
    {
        switch (a2dp_get_state(inst))
        {
            case A2DP_STATE_DISCONNECTED:
            {
                a2dp_exit_state_disconnected(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTING_LOCAL:
            {
                a2dp_exit_state_connecting_local(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTING_REMOTE:
            {
                a2dp_exit_state_connecting_remote(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTED_SIGNALLING:
            {
                a2dp_exit_state_connected_signalling(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTING_MEDIA_LOCAL:
            {
                a2dp_exit_state_connecting_media_local(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTING_MEDIA_REMOTE:
            {
                a2dp_exit_state_connecting_media_remote(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA:
            {
                a2dp_exit_state_connected_media(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA_STREAMING:
            {
                a2dp_exit_state_connected_media_streaming(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA_SUSPENDING_LOCAL:
            {
                a2dp_exit_state_connected_media_suspending_local(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA_SUSPENDED:
            {
                a2dp_exit_state_connected_media_suspended(inst);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA_STARTING_LOCAL:
            {
                a2dp_exit_state_connected_media_starting_local(inst);
            }
            break;
            
            case A2DP_STATE_DISCONNECTING_MEDIA:
            {
                a2dp_exit_state_disconnecting_media(inst);
            }
            break;
            
            case A2DP_STATE_DISCONNECTING:
            {
                a2dp_exit_state_disconnecting(inst);
            }
            break;
            
            default:
            {
                a2dp_unhandled_state(inst);
            }
            break;
        }
    }
}


/****************************************************************************
NAME    
    a2dp_enter_state - Enters an A2DP state
*/
static void a2dp_enter_state(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    if(inst != NULL)
    {
        switch (a2dp_get_state(inst))
        {
            case A2DP_STATE_DISCONNECTED:
            {
                a2dp_enter_state_disconnected(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTING_LOCAL:
            {
                a2dp_enter_state_connecting_local(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTING_REMOTE:
            {
                a2dp_enter_state_connecting_remote(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTED_SIGNALLING:
            {
                a2dp_enter_state_connected_signalling(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTING_MEDIA_LOCAL:
            {
                a2dp_enter_state_connecting_media_local(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTING_MEDIA_REMOTE:
            {
                a2dp_enter_state_connecting_media_remote(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA:
            {
                a2dp_enter_state_connected_media(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA_STREAMING:
            {
                a2dp_enter_state_connected_media_streaming(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA_SUSPENDING_LOCAL:
            {
                a2dp_enter_state_connected_media_suspending_local(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA_SUSPENDED:
            {
                a2dp_enter_state_connected_media_suspended(inst, old_state);
            }
            break;
            
            case A2DP_STATE_CONNECTED_MEDIA_STARTING_LOCAL:
            {
                a2dp_enter_state_connected_media_starting_local(inst, old_state);
            }
            break;
            
            case A2DP_STATE_DISCONNECTING_MEDIA:
            {
                a2dp_enter_state_disconnecting_media(inst, old_state);
            }
            break;
            
            case A2DP_STATE_DISCONNECTING:
            {
                a2dp_enter_state_disconnecting(inst, old_state);
            }
            break;
            
            default:
            {
                a2dp_unhandled_state(inst);
            }
            break;
        }   
   }
}


/****************************************************************************
NAME    
    a2dp_exit_state_disconnected - Called on exiting the A2DP_STATE_DISCONNECTED state
*/
static void a2dp_exit_state_disconnected(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connecting_local - Called on exiting the A2DP_STATE_CONNECTING_LOCAL state
*/
static void a2dp_exit_state_connecting_local(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connecting_remote - Called on exiting the A2DP_STATE_CONNECTING_REMOTE state
*/
static void a2dp_exit_state_connecting_remote(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connected_signalling - Called on exiting the A2DP_STATE_CONNECTED_SIGNALLING state
*/
static void a2dp_exit_state_connected_signalling(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connecting_media_local - Called on exiting the A2DP_STATE_CONNECTING_MEDIA_LOCAL state
*/
static void a2dp_exit_state_connecting_media_local(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connecting_media_remote - Called on exiting the A2DP_STATE_CONNECTING_MEDIA_REMOTE state
*/
static void a2dp_exit_state_connecting_media_remote(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connected_media - Called on exiting the A2DP_STATE_CONNECTED_MEDIA state
*/
static void a2dp_exit_state_connected_media(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connected_media_streaming - Called on exiting the A2DP_STATE_CONNECTED_MEDIA_STREAMING state
*/
static void a2dp_exit_state_connected_media_streaming(a2dpInstance *inst)
{
    /* disconnect any audio */
    audio_a2dp_disconnect(inst->a2dp_device_id, inst->media_sink);
}


/****************************************************************************
NAME    
    a2dp_exit_state_connected_media_suspending_local - Called on exiting the A2DP_STATE_CONNECTED_MEDIA_SUSPENDING_LOCAL state
*/
static void a2dp_exit_state_connected_media_suspending_local(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connected_media_suspended - Called on exiting the A2DP_STATE_CONNECTED_MEDIA_SUSPENDED state
*/
static void a2dp_exit_state_connected_media_suspended(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_connected_media_starting_local - Called on exiting the A2DP_STATE_CONNECTED_MEDIA_STARTING_LOCAL state
*/
static void a2dp_exit_state_connected_media_starting_local(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_disconnecting_media - Called on exiting the A2DP_STATE_DISCONNECTING_MEDIA state
*/
static void a2dp_exit_state_disconnecting_media(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_exit_state_disconnecting - Called on exiting the A2DP_STATE_DISCONNECTING state
*/
static void a2dp_exit_state_disconnecting(a2dpInstance *inst)
{
    
}


/****************************************************************************
NAME    
    a2dp_enter_state_disconnected - Called on entering the A2DP_STATE_DISCONNECTED state
*/
static void a2dp_enter_state_disconnected(a2dpInstance *inst, A2DP_STATE_T old_state)
{   
    if (a2dp_is_connected(old_state))
    {
        /* send message that has disconnection has occurred */    
        MessageSend(app_get_instance(), APP_DISCONNECT_IND, 0); 
        /* cancel any media connect requests */
        MessageCancelAll(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_OPEN_REQ);
        /* reset audio delay flag */
        audio_set_a2dp_conn_delay(FALSE);
        
        if (!a2dp_get_number_connections())
        {
            /* attempt to switch audio mode if this is the last A2DP device to disconnect */
            audio_switch_voip_music_mode(AUDIO_VOIP_MODE);
        }
    }
}


/****************************************************************************
NAME    
    a2dp_enter_state_connecting_local - Called on entering the A2DP_STATE_CONNECTING_LOCAL state
*/
static void a2dp_enter_state_connecting_local(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    if ((inst != NULL) && inst->a2dp_support != A2DP_SUPPORT_YES)
    {
        /* attempt SDP search before issuing connect request */
        ConnectionSdpServiceSearchRequest(&inst->a2dpTask, &inst->addr, A2DP_MAX_SDP_RECS, sizeof(a2dp_service_search_pattern), a2dp_service_search_pattern);
    }
    else
    {
        /* it is known that A2DP is supported so try a connection */
        if ((inst != NULL) && !A2dpSignallingConnectRequest(&inst->addr))
        {
            MessageSend(app_get_instance(), APP_CONNECT_FAIL_CFM, 0);         
        }   
    }
}


/****************************************************************************
NAME    
    a2dp_enter_state_connecting_remote - Called on entering the A2DP_STATE_CONNECTING_REMOTE state
*/
static void a2dp_enter_state_connecting_remote(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    
}


/****************************************************************************
NAME    
    a2dp_enter_state_connected_signalling - Called on entering the A2DP_STATE_CONNECTED_SIGNALLING state
*/
static void a2dp_enter_state_connected_signalling(a2dpInstance *inst, A2DP_STATE_T old_state)
{    
    if ((old_state == A2DP_STATE_DISCONNECTED) ||
        (old_state == A2DP_STATE_CONNECTING_LOCAL) ||
        (old_state == A2DP_STATE_CONNECTING_REMOTE))
    {
        tp_bdaddr tpaddr;
        
        /* Retrieve the role of this device */
        if(inst != NULL)
        ConnectionGetRole(connection_mgr_get_instance(), A2dpSignallingGetSink(inst->a2dp_device_id));
  
        /* initiate an AVRCP connection to the device */
        avrcp_start_connection(inst->addr); 
        
        /* send message that has connection has occurred */    
        MessageSend(app_get_instance(), APP_CONNECT_SUCCESS_CFM, 0); 
        
        /* register connection with connection manager */        
        if(inst != NULL)
        connection_mgr_set_profile_connected(PROFILE_A2DP, &inst->addr);
        
        /* augment the simple bluteooth address for compatibility with
         * ConnectionReadRemoteVersionBdaddr() */
        tpaddr.transport = TRANSPORT_BREDR_ACL;
        tpaddr.taddr.type = TYPED_BDADDR_PUBLIC;
        tpaddr.taddr.addr = inst->addr;
        /* Send a request to find information about the connected device */
        ConnectionReadRemoteVersionBdaddr(connection_mgr_get_instance(), &tpaddr); 
        
        /* Read remote device features */
        if(inst != NULL)
        {
            ConnectionReadRemoteSuppFeatures(&inst->a2dpTask, A2dpSignallingGetSink(inst->a2dp_device_id));
        
            /* reset connection attempts */
            inst->a2dp_connection_retries = 0;
        }
        
        /* for remote connections need to record that locally initiated audio connection 
            should be delayed incase remote end wants to initiate audio */
        if (old_state == A2DP_STATE_CONNECTING_REMOTE)
        {
            audio_set_a2dp_conn_delay(TRUE);
        }
        
        /* check audio mode */
        if (audio_get_voip_music_mode() == AUDIO_VOIP_MODE)
        {
            /* attempt to switch audio mode from VOIP to MUSIC if A2DP connects */
            audio_set_voip_music_mode(AUDIO_MUSIC_MODE);
        }
    }
    else if (old_state == A2DP_STATE_DISCONNECTING_MEDIA)
    {
        /* The Source device disconnected the A2DP media */
        if (connection_mgr_get_a2dp_media_before_signalling())
        {
            /* The Source device wants to disconnect signalling after all A2DP media channels are removed.
               Check that all media has disconnected before removing signalling connections.
            */
            if (!a2dp_any_media_connections())
            {
                MessageCancelAll(app_get_instance(), APP_DISCONNECT_SIGNALLING_REQ);
                MessageSend(app_get_instance(), APP_DISCONNECT_SIGNALLING_REQ, 0);
            }
        }
        else
        {
            if (inst && inst->a2dp_suspending)   
            {
                /* this was from a failed Suspend attempt, so remain in the connected state */
                inst->a2dp_suspending = 0;
            }
            if (inst && inst->a2dp_reconfiguring)
            {
                /* this is a reconfigure so reopen media */
                MessageSend(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_OPEN_REQ, 0);
            }
        }
    }
    else
    {
        if ((inst != NULL) && inst->a2dp_connection_retries < a2dp_get_max_connection_retries())
        {
            /* try to open media again after the PS delay */
            MessageSendLater(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_OPEN_REQ, 0, connection_mgr_get_audio_delay_timer());
            inst->a2dp_connection_retries++;
        }
        else
        {
            /* disconnect signalling as media couldn't be opened */
            MessageSend(&inst->a2dpTask, A2DP_INTERNAL_SIGNALLING_DISCONNECT_REQ, 0);
        }        
    }        
    
    /* no media sink at this point */
    inst->media_sink = 0;
}


/****************************************************************************
NAME    
    a2dp_enter_state_connecting_media_local - Called on entering the A2DP_STATE_CONNECTING_MEDIA_LOCAL state
*/
static void a2dp_enter_state_connecting_media_local(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    uint8 a2dp_seid_list[A2DP_MAX_ENDPOINTS];
    uint8 a2dp_seid_preference[A2DP_MAX_ENDPOINTS];
    uint16 current_endpoint = 0;
    uint16 i = 0;
    uint16 j = 0;
    uint16 k = 0;
    uint16 temp_id;
    uint16 temp_pref;
    uint16 preference = 1;
    a2dp_codecs_config_def_t a2dp_config_data;
    
    memset(&a2dp_config_data,0,sizeof(a2dp_codecs_config_def_t));
    memset(&a2dp_seid_list,0,sizeof(a2dp_seid_list));
    memset(&a2dp_seid_preference,0,sizeof(a2dp_seid_preference));

    /*Get the codec config values from the  a2dp module config xml files.*/
    a2dp_get_codec_enable_values(&a2dp_config_data);

    if (inst && inst->a2dp_reconfiguring)
    {
        /* this is a reconfigure so chose CODECS based on what is set as a2dp_reconfigure_codec */
        if (a2dp_seid_is_aptx(inst->a2dp_reconfigure_codec))
        {
            a2dp_seid_list[current_endpoint] = A2DP_SEID_APTX;
            a2dp_seid_preference[current_endpoint++] = preference++;                   
        }
        a2dp_seid_list[current_endpoint] = A2DP_SEID_SBC;
        a2dp_seid_preference[current_endpoint++] = preference++;
    }
    else
    {
        /* this is a standard A2DP Open so choose CODECS based on PS configuration */
        if(a2dp_config_data.a2dpCodecsSBCEnable)
        {
            a2dp_seid_list[current_endpoint] = A2DP_SEID_SBC;
            a2dp_seid_preference[current_endpoint++] =a2dp_config_data.a2dpCodecsSBCPref;
        }
        if(a2dp_config_data.a2dpCodecsFastStreamEnable)
        {
            a2dp_seid_list[current_endpoint] = A2DP_SEID_FASTSTREAM;
            a2dp_seid_preference[current_endpoint++] = a2dp_config_data.a2dpFastStreamPref;
        }    
        if(a2dp_config_data.a2dpCodecsAptXEnable)
        {
            a2dp_seid_list[current_endpoint] = A2DP_SEID_APTX;
            a2dp_seid_preference[current_endpoint++] = a2dp_config_data.a2dpCodecsAptXPref;
        }   
        if(a2dp_config_data.a2dpCodecsAptXLLEnable)
        {
            a2dp_seid_list[current_endpoint] = A2DP_SEID_APTX_LOW_LATENCY;
            a2dp_seid_preference[current_endpoint++] =a2dp_config_data.a2dpCodecsAptXLLPref;
        }
        if(a2dp_config_data.a2dpCodecsAptXHDEnable)
        {
            a2dp_seid_list[current_endpoint] = A2DP_SEID_APTXHD;
            a2dp_seid_preference[current_endpoint++] = a2dp_config_data.a2dpCodecsAptXHDPref;
        } 
    }
    
    /* sort list to try preferred codecs first */
    for (i = 1; i < current_endpoint; i++)
    {
        for (j = 0; j < i; j++)
        {
            if (a2dp_seid_preference[i] < a2dp_seid_preference[j])
            {
                temp_id = a2dp_seid_list[i];
                temp_pref = a2dp_seid_preference[i];
                for (k = i; k > j; k--)
                { 
                    a2dp_seid_list[k] = a2dp_seid_list[k - 1];
                    a2dp_seid_preference[k] = a2dp_seid_preference[k - 1];
                }
                a2dp_seid_list[j] = temp_id;
                a2dp_seid_preference[j] = temp_pref;
            }
        }
    }
    
#ifdef DEBUG_A2DP
    A2DP_DEBUG(("A2DP: Preferred List:\n"));
    for (i = 0; i < current_endpoint; i++)
    {
        A2DP_DEBUG(("    ID:[0x%x] Pref:[0x%x]\n", a2dp_seid_list[i], a2dp_seid_preference[i]));
    }
#endif    
    
    if (!A2dpMediaOpenRequest(inst->a2dp_device_id, current_endpoint, a2dp_seid_list))
    {
        MessageSend(&inst->a2dpTask, A2DP_INTERNAL_SIGNALLING_DISCONNECT_REQ, 0);
    }
}


/****************************************************************************
NAME    
    a2dp_enter_state_connecting_media_remote - Called on entering the A2DP_STATE_CONNECTING_MEDIA_REMOTE state
*/
static void a2dp_enter_state_connecting_media_remote(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    
}

/****************************************************************************
NAME    
    a2dp_enter_state_connected_media - Called on entering the A2DP_STATE_CONNECTED_MEDIA state
*/
static void a2dp_enter_state_connected_media(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    if(!inst)
    {
       return;
    }
    
    if ((old_state == A2DP_STATE_CONNECTING_MEDIA_LOCAL) || (old_state == A2DP_STATE_CONNECTING_MEDIA_REMOTE))
    {        
        if (!a2dp_is_dualstream_reconfigure_needed())
        {
            if (old_state == A2DP_STATE_CONNECTING_MEDIA_REMOTE)
            {
                /* start the media stream after a delay to see if remote side does the Start */
                MessageSendLater(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_START_REQ, 0, connection_mgr_get_audio_delay_timer());
                /* cancel any media connect requests */
                MessageCancelAll(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_OPEN_REQ);
            }
            else
            {
                /* start the media stream immediately after the media is opened */
                MessageSend(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_START_REQ, 0);               
            }
        }
        
        /* reset connection attempts */
        inst->a2dp_connection_retries = 0;
        
        /* store media sink */
        inst->media_sink = A2dpMediaGetSink(inst->a2dp_device_id, inst->a2dp_stream_id);
    }
    if (old_state == A2DP_STATE_CONNECTED_MEDIA_STARTING_LOCAL)
    {                
        if (inst->a2dp_connection_retries < a2dp_get_max_connection_retries())
        {
            /* increase the number of times we've tried to issue an AVDTP_START */
            inst->a2dp_connection_retries++;
            /* issue start of the media stream again */
            MessageSendLater(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_START_REQ, 0, connection_mgr_get_audio_delay_timer());
        }
        else
        {
            /* start of media failed, must disconnect and begin connection again */
            MessageSend(&inst->a2dpTask, A2DP_INTERNAL_SIGNALLING_DISCONNECT_REQ, 0);
        }
    }
}


/****************************************************************************
NAME    
    a2dp_enter_state_connected_media_suspending_local - Called on entering the A2DP_STATE_CONNECTED_MEDIA_SUSPENDING_LOCAL state
*/
static void a2dp_enter_state_connected_media_suspending_local(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    if(!inst)
    {
        return;
    }
    if (!A2dpMediaSuspendRequest(inst->a2dp_device_id, inst->a2dp_stream_id))
    {
        MessageSend(&inst->a2dpTask, A2DP_INTERNAL_SIGNALLING_DISCONNECT_REQ, 0);
    }
    else
    {
        inst->a2dp_suspending = 1;
    }
}


/****************************************************************************
NAME    
    a2dp_enter_state_connected_media_suspended - Called on entering the A2DP_STATE_CONNECTED_MEDIA_SUSPENDED state
*/
static void a2dp_enter_state_connected_media_suspended(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    if(inst != NULL)
    inst->a2dp_suspending = 0;
}


/****************************************************************************
NAME    
    a2dp_enter_state_connected_media_starting_local - Called on entering the A2DP_STATE_CONNECTED_MEDIA_STARTING_LOCAL state
*/
static void a2dp_enter_state_connected_media_starting_local(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    if ((inst != NULL) && !A2dpMediaStartRequest(inst->a2dp_device_id, inst->a2dp_stream_id))
    {
        MessageSend(&inst->a2dpTask, A2DP_INTERNAL_SIGNALLING_DISCONNECT_REQ, 0);
    }
}


/****************************************************************************
NAME    
    a2dp_enter_state_disconnecting_media - Called on entering the A2DP_STATE_DISCONNECTING_MEDIA state
*/
static void a2dp_enter_state_disconnecting_media(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    if ((inst != NULL) && !A2dpMediaCloseRequest(inst->a2dp_device_id, inst->a2dp_stream_id))
    {
        MessageSend(&inst->a2dpTask, A2DP_INTERNAL_SIGNALLING_DISCONNECT_REQ, 0);
    }
}


/****************************************************************************
NAME    
    a2dp_enter_state_disconnecting - Called on entering the A2DP_STATE_DISCONNECTING state
*/
static void a2dp_enter_state_disconnecting(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    if ((inst != NULL) && !A2dpSignallingDisconnectRequest(inst->a2dp_device_id))
    {
        /* force disconnect by sending message which calls a2dp_init_instance(inst); */
        MessageSend(&inst->a2dpTask, A2DP_INTERNAL_FORCE_DISCONNECT_REQ, 0);
    }
}


/****************************************************************************
NAME    
    a2dp_is_dualstream_reconfigure_needed - Check if A2DP streams need to reconfigured due to DualStream operation
*/
static bool a2dp_is_dualstream_reconfigure_needed(void)
{
#ifdef INCLUDE_DUALSTREAM   
    
    a2dpInstance *inst = memory_get_a2dp_instance(0);
    a2dp_codec_settings *codec_settings[A2DP_MAX_INSTANCES];
    bool reconfigure_needed = FALSE;
    uint16 index = 0;
    uint16 reconfigure_codec = A2DP_SEID_SBC;
    
    /* return FALSE to check boundary condition if A2DP_MAX_INSTANCES is set to 1 instead of 2 */
    if(A2DP_MAX_INSTANCES < 2)
    {       
        return FALSE;
    }
    codec_settings[0] = codec_settings[1] = NULL;
    
    for_all_a2dp_instance(index)
    {
        if (inst && a2dp_is_media(inst->a2dp_state)) /* validate inst pointer afer incrementing for index 1 */
        {
            codec_settings[index] = A2dpCodecGetSettings(inst->a2dp_device_id, inst->a2dp_stream_id);
        }
        inst++;
    }
    
    if (codec_settings[0] && codec_settings[1]) /* check if 2 A2DP streams are configured */
    {
        /* check CODECS in use */
        if (a2dp_seid_is_sbc(codec_settings[0]->seid) && a2dp_seid_is_sbc(codec_settings[1]->seid))
        {
            /* both SBC */
            reconfigure_codec = A2DP_SEID_SBC;
        }
        else if (a2dp_seid_is_faststream(codec_settings[0]->seid) && a2dp_seid_is_faststream(codec_settings[1]->seid))
        {
            /* both FastStream */
            reconfigure_codec = A2DP_SEID_FASTSTREAM;
        }
        else if (a2dp_seid_is_aptx(codec_settings[0]->seid) && a2dp_seid_is_aptx(codec_settings[1]->seid))
        {
            /* both APT-X */
            reconfigure_codec = A2DP_SEID_APTX; /* both support APT-X so can reopen with APT-X */
        }
        else if (a2dp_seid_is_aptxll(codec_settings[0]->seid) && a2dp_seid_is_aptxll(codec_settings[1]->seid))
        {
            /* both APT-X LL */
            reconfigure_codec = A2DP_SEID_APTX_LOW_LATENCY; /* both support APT-X LL so can reopen with APT-X LL */
        }		
        else
        {
            reconfigure_needed = TRUE; /* codecs different */    
        }
        
        if (codec_settings[0]->rate != codec_settings[1]->rate)
        {
            reconfigure_needed = TRUE; /* rates not the same */
        }  
        if (codec_settings[0]->channel_mode != codec_settings[1]->channel_mode)
        {
            reconfigure_needed = TRUE; /* channel modes not the same */
        }
        if (codec_settings[0]->codecData.content_protection != codec_settings[1]->codecData.content_protection)
        {
            reconfigure_needed = TRUE; /* content protection not the same */
        }
        if (codec_settings[0]->codecData.voice_rate != codec_settings[1]->codecData.voice_rate)
        {
            reconfigure_needed = TRUE; /* voice rate not the same */
        }
        if (codec_settings[0]->codecData.bitpool != codec_settings[1]->codecData.bitpool)
        {
            reconfigure_needed = TRUE; /* bitpool not the same */
        }
    }
    
    /* free memory */
    if (codec_settings[0])
        memory_free(codec_settings[0]);    
    if (codec_settings[1])
        memory_free(codec_settings[1]);
    
    /* decide if streams need to be reconfigured */
    if (reconfigure_needed)
    {
        inst = memory_get_a2dp_instance(0);

        for_all_a2dp_instance(index)
        {
            /* close media so it can be re-opened with the correct configuration */
            if(inst)
            {
                inst->a2dp_reconfiguring = TRUE;
                inst->a2dp_reconfigure_codec = reconfigure_codec;
                MessageSend(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_CLOSE_REQ, 0);     
            }                
            inst++;
        }
        return TRUE;
    }

#endif /* INCLUDE_DUALSTREAM */
    
    return FALSE;
}


/****************************************************************************
NAME    
    a2dp_get_lowest_quality - Returns the lowest quality connection for all A2DP connections
*/
static A2DP_AUDIO_QUALITY_T a2dp_get_lowest_quality(void)
{
    uint16 index = 0;
    a2dpInstance *inst = memory_get_a2dp_instance(0);
    A2DP_AUDIO_QUALITY_T lowest_quality = A2DP_AUDIO_QUALITY_UNKNOWN;
    
    for_all_a2dp_instance(index)
    {
        if (inst && a2dp_is_connected(a2dp_get_state(inst)))
        {
            if (inst->a2dp_quality < lowest_quality)
            {
                lowest_quality = inst->a2dp_quality;
            }
        }
        inst++;
    }
    
    return lowest_quality;
}



/****************************************************************************
NAME    
    a2dp_enter_state_connected_media_streaming
*/
void a2dp_enter_state_connected_media_streaming(a2dpInstance *inst, A2DP_STATE_T old_state)
{
    Sink sink = A2dpMediaGetSink(inst->a2dp_device_id, inst->a2dp_stream_id);
    
    inst->media_sink = sink;

    /* reset reconfiguring flag */
    inst->a2dp_reconfiguring = FALSE;
    
    if (audio_get_voip_music_mode() == AUDIO_MUSIC_MODE)
    {        
        /* route A2DP audio */
        if (sink)
        {
            if (states_get_state() == SOURCE_STATE_CONNECTED)
            {             
                /* suspend AGHFP stream */
                aghfp_suspend_all_audio();
                
                if (!aghfp_is_audio_active())
                {
                    /* no AGHFP audio active */
                    if (A2DP_DUALSTREAM_ENABLED)
                    {
                        /* For Dual Stream, must make sure that if two A2DP device are connected they share the same Stream-End Point configuration */
                        if (!a2dp_is_dualstream_reconfigure_needed())
                        {                    
                            /* no reconfigure needed so okay to route A2DP audio */                
                            audio_a2dp_connect(sink, inst->a2dp_device_id, inst->a2dp_stream_id);
                        }
                    }
                    else
                    {
                        /* no AGHFP audio so okay to route A2DP audio */                
                        audio_a2dp_connect(sink, inst->a2dp_device_id, inst->a2dp_stream_id);
                    }
            
                    /* set sniff mode if PS Key has been read */
                    if (power_get_a2dp_number_of_entries() && power_get_a2dp_power_table())
                    {
                        ConnectionSetLinkPolicy(A2dpSignallingGetSink(inst->a2dp_device_id), power_get_a2dp_number_of_entries()  ,power_get_a2dp_power_table());
                    }
                }
                else
                {
                    /* AGHFP audio is still active so suspend A2DP audio until AGHFP audio is fully disconnected
                        as remote devices can fail to route audio correctly */
                    MessageSend(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_SUSPEND_REQ, 0);              
                }
            }
            else
            {
                /* not in connected state, so suspend A2DP audio */
                MessageSend(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_SUSPEND_REQ, 0);              
            }
        }
    }
    else
    {
        /* MUSIC mode not active so suspend A2DP audio */
        MessageSend(&inst->a2dpTask, A2DP_INTERNAL_MEDIA_SUSPEND_REQ, 0);   
    }
    
    /* store current device to PS */   
    connection_mgr_write_new_remote_device(&inst->addr, PROFILE_A2DP);
            
    /* clear forced inquiry mode flag as is now streaming to a device */
    inquiry_set_forced_inquiry_mode(FALSE);
    
    /* reset connection attempts */
    inst->a2dp_connection_retries = 0;
}
/******************************************************************************
NAME
    a2dp_get_sbc_enable_value

DESCRIPTION
    Helper function to get the SBC Enable feature.

RETURNS
    uint8
*/
static void a2dp_get_codec_enable_values(a2dp_codecs_config_def_t *a2dp_config_data)
{
    a2dp_codecs_config_def_t *a2dp_config_data_temp  = NULL;
    if (configManagerGetReadOnlyConfig(A2DP_CODECS_CONFIG_BLK_ID, (const void **)&a2dp_config_data_temp))
    {
        *a2dp_config_data = *a2dp_config_data_temp;
    }
    configManagerReleaseConfig(A2DP_CODECS_CONFIG_BLK_ID);
}
/******************************************************************************
NAME
    a2dp_create_memory_configurations_for_codec_configs

DESCRIPTION
    THis function creates memory for different codec configurations

RETURNS
    void
*/
static void a2dp_create_memory_for_codec_configs(void)
{
    uint16 sbc_config;
    uint16 faststream_config;
    uint16 aptx_config;
    uint16 aptxLowLatency_config;
    uint16 aptxhd_config;

    /* Read SBC configuration */
    sbc_config = a2dp_get_sbc_configurable_values();;
    /* Read Faststream configuration */
    faststream_config = a2dp_get_faststream_configurable_values();
    /* Read APT-X configuration */
    aptx_config = a2dp_get_aptx_configurable_values();
    /* Read APT-X Low Latency configuration */
    aptxLowLatency_config = a2dp_get_aptxLL_configurable_values();
    /* Read aptX-HD configuration */
    aptxhd_config = a2dp_get_aptxHD_configurable_values();

    if (sbc_config || faststream_config || aptx_config || aptxLowLatency_config || aptxhd_config)
    {
        /* create memory to hold all codec configurations */
        if (!memory_create_block(MEMORY_CREATE_BLOCK_CODECS))
        {
            Panic(); /* Panic if can't allocate memory */
        }   
        if (sbc_config)
        {
            a2dp_set_memory_for_codecs(A2DP_CODEC_SBC);
            a2dp_set_sbc_config(FALSE);
        }
        if (faststream_config)
        {
            a2dp_set_memory_for_codecs(A2DP_CODEC_FAST_STREAM);
            a2dp_set_faststream_config(FALSE);
        }
        if (aptx_config)
        {
            a2dp_set_memory_for_codecs(A2DP_CODEC_APTX);
            a2dp_set_aptx_config(FALSE);
        }
        if (aptxLowLatency_config)
        {
            a2dp_set_memory_for_codecs(A2DP_CODEC_APTX_LOW_LATENCY);
            a2dp_set_aptxLowLatency_config(FALSE);
        }
        if (aptxhd_config)
        {
            a2dp_set_memory_for_codecs(A2DP_CODEC_APTX_HD);
            a2dp_set_aptxhd_config(FALSE);
        }
    }
}
/******************************************************************************
NAME
    a2dp_set_memory_for_codecs

DESCRIPTION
    Helper function to create the memory based on different codecs values.

RETURNS
    void
*/
static void a2dp_set_memory_for_codecs(A2DP_CODEC_CONFIG_T Config)
{
    switch(Config)
    {
        case A2DP_CODEC_SBC:
                A2DP_RUNDATA.sbc_codec_config = (uint8 *)memory_get_block(MEMORY_GET_BLOCK_CODEC_SBC);
                break;
        case A2DP_CODEC_FAST_STREAM:
                A2DP_RUNDATA.faststream_codec_config = (uint8 *)memory_get_block(MEMORY_GET_BLOCK_CODEC_FASTSTREAM);
                break;
        case A2DP_CODEC_APTX:
                A2DP_RUNDATA.aptx_codec_config = (uint8 *)memory_get_block(MEMORY_GET_BLOCK_CODEC_APTX);
                break;
        case A2DP_CODEC_APTX_LOW_LATENCY:
                A2DP_RUNDATA.aptxLowLatency_codec_config = (uint8 *)memory_get_block(MEMORY_GET_BLOCK_CODEC_APTX_LOW_LATENCY);
                break;
        case A2DP_CODEC_APTX_HD:
                A2DP_RUNDATA.aptxhd_codec_config = (uint8 *)memory_get_block(MEMORY_GET_BLOCK_CODEC_APTXHD);
                break;
    }
}
/******************************************************************************
NAME
    a2dp_set_memory_for_codec_config

DESCRIPTION
    Helper function which creates the memory for A2DP codec config.

RETURNS
    void
*/
void  a2dp_set_memory_for_codec_config(void)
{
    A2DP_RUNDATA.codec_config = memory_create(a2dp_get_sbc_caps_size() + a2dp_get_faststream_caps_size() + a2dp_get_aptx_caps_size()  + a2dp_get_aptxLowLatency_caps_size() +a2dp_get_aptxhd_caps_size()); 
}
/******************************************************************************
NAME
    a2dp_get_memory_for_codec_config

DESCRIPTION
    Thsi functions returns the memory address allocated for A2DP codec config.

RETURNS
    The pointer to the structure variable codec_config.
*/
uint8 *a2dp_get_memory_for_codec_config(void)
{
    return  A2DP_RUNDATA.codec_config;
}
/******************************************************************************
NAME
    a2dp_reset_codec_config

DESCRIPTION
    Helper function to reset the A2DP code config values for different codecs.

RETURNS
    void
*/
static void a2dp_reset_codec_config(A2DP_CODEC_CONFIG_T Config)
{
    switch(Config)
    {
        case A2DP_CODEC_SBC:
                A2DP_RUNDATA.sbc_codec_config = NULL;
                break;
        case A2DP_CODEC_FAST_STREAM:
                A2DP_RUNDATA.faststream_codec_config = NULL;
                break;
        case A2DP_CODEC_APTX:
               A2DP_RUNDATA.aptx_codec_config = NULL;
                break;
        case A2DP_CODEC_APTX_LOW_LATENCY:
                A2DP_RUNDATA.aptxLowLatency_codec_config = NULL;
                break;
        case A2DP_CODEC_APTX_HD:
                A2DP_RUNDATA.aptxhd_codec_config= NULL;
                break;
    }
}

/******************************************************************************
NAME
    a2dp_set_caps_values

DESCRIPTION
    Helper function to set the caps value associated with different codecs.

RETURNS
    void
*/
static void a2dp_set_caps_values(A2DP_CODEC_CONFIG_T Config,sep_config_type caps)
{
    switch(Config)
    {
        case A2DP_CODEC_SBC:
                A2DP_RUNDATA.sbc_caps = caps; /* default End Point data */ 
                break;
        case A2DP_CODEC_FAST_STREAM:
                A2DP_RUNDATA.faststream_caps = caps;
                break;
        case A2DP_CODEC_APTX:
                A2DP_RUNDATA.aptx_caps = caps;
                break;
        case A2DP_CODEC_APTX_LOW_LATENCY:
                A2DP_RUNDATA.aptxLowLatency_caps = caps;
                break;
        case A2DP_CODEC_APTX_HD:
                A2DP_RUNDATA.aptxhd_caps = caps;
                break;
    }
}
/******************************************************************************
NAME
    a2dp_get_codec_config

DESCRIPTION
    This function returns the address allocated for the respective codec config values.

RETURNS
    The pointer to the respective structure variable codec_config based on config values. 
*/
static uint8 *a2dp_get_codec_config(A2DP_CODEC_CONFIG_T Config)
{
    uint8 *ret = NULL;
    switch(Config)
    {
        case A2DP_CODEC_SBC:
                ret = A2DP_RUNDATA.sbc_codec_config ;
                break;
        case A2DP_CODEC_FAST_STREAM:
                ret = A2DP_RUNDATA.faststream_codec_config ;
                break;
        case A2DP_CODEC_APTX:
                ret = A2DP_RUNDATA.aptx_codec_config ;
                break;
        case A2DP_CODEC_APTX_LOW_LATENCY:
                ret = A2DP_RUNDATA.aptxLowLatency_codec_config; 
                break;
        case A2DP_CODEC_APTX_HD:
                ret = A2DP_RUNDATA.aptxhd_codec_config; 
                break;
    }
    return ret;
}
/******************************************************************************
NAME
    a2dp_get_config_caps

DESCRIPTION
    This function returns the local SEP structure with respect to different codec configs.

RETURNS
    The pointer to the structure sep_config_type .
*/
static sep_config_type *a2dp_get_config_caps(A2DP_CODEC_CONFIG_T Config)
{
    sep_config_type *ret = NULL;
    switch(Config)
    {
        case A2DP_CODEC_SBC:
                ret = &A2DP_RUNDATA.sbc_caps ;
                break;
        case A2DP_CODEC_FAST_STREAM:
                ret =&A2DP_RUNDATA.faststream_caps ;
                break;
        case A2DP_CODEC_APTX:
                ret =&A2DP_RUNDATA.aptx_caps ;
                break;
        case A2DP_CODEC_APTX_LOW_LATENCY:
                ret =&A2DP_RUNDATA.aptxLowLatency_caps ;
                break;
        case A2DP_CODEC_APTX_HD:
                ret =&A2DP_RUNDATA.aptxhd_caps ;
                break;
    }
    return ret;
}
/******************************************************************************
NAME
    a2dp_get_caps_value_by_index

DESCRIPTION
    This function returns the value of the the respective element in the caps array w.r.t to different
    codec config values.

RETURNS
    The capabilities for the SEP. These can be taken from one of the default codec capability header files that are supplied by CSR. The service capabilities section of the AVDTP specification details the format of these capabilities. 
*/
static uint8 a2dp_get_caps_value_by_index(uint8 index,A2DP_CODEC_CONFIG_T Config)
{
    uint8  ret = 0;
    switch(Config)
    {
        case A2DP_CODEC_SBC:
                ret = A2DP_RUNDATA.sbc_caps.caps[index];
                break;
        case A2DP_CODEC_FAST_STREAM:
                ret = A2DP_RUNDATA.faststream_caps.caps[index];
                break;
        case A2DP_CODEC_APTX:
                ret = A2DP_RUNDATA.aptx_caps.caps[index];
                break;
        case A2DP_CODEC_APTX_LOW_LATENCY:
                ret = A2DP_RUNDATA.aptxLowLatency_caps.caps[index];
                break;
        case A2DP_CODEC_APTX_HD:
                ret = A2DP_RUNDATA.aptxhd_caps.caps[index];
                break;
    }   
    return ret;
}
/******************************************************************************
NAME
    a2dp_set_codec_config

DESCRIPTION
    This functions assigns the address of the corresponding end point capabilities static array .

RETURNS
    void
*/
static void a2dp_set_codec_config(uint8 index,uint8 * Dstval,const uint8 *Srcval)
{
    Dstval[index] = Srcval[index];
}
/******************************************************************************
NAME
    a2dp_set_codec_config_values_on_Index

DESCRIPTION
    This function assigns  the corresponding code config values with the value in the Srcval.

RETURNS
    void
*/
static void a2dp_set_codec_config_values_on_index(uint8 index,uint8 * Dstval,uint8 Srcval)
{
    Dstval[index] =  Srcval;
}
/******************************************************************************
NAME
    a2dp_set_codec_config_caps_values

DESCRIPTION
    This function assigns  the corresponding caps value with the codec config address.

*/
static void a2dp_set_codec_config_caps_values(const uint8 **Dstval,uint8  **Srcval)
{
    *Dstval =  *Srcval;
}
/*************************************************************************
NAME
    a2dp_get_sbc_force_max_bit_pool

DESCRIPTION
    Helper function to Get the SBC Force Max Bit Pool..

RETURNS
   TRUE is value was set ok, FALSE otherwise.

**************************************************************************/
static bool a2dp_get_sbc_force_max_bit_pool(void)
{
    bool sbc_force_max_bitpool = FALSE;
    sbc_codec_features_config_def_t *sbc_codec_config;

    if (configManagerGetReadOnlyConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID, (const void **)&sbc_codec_config))
    {
        sbc_force_max_bitpool = sbc_codec_config->featuresForceMaxBitpool;
    }
    configManagerReleaseConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID);
    return sbc_force_max_bitpool;
}
/*************************************************************************
NAME
    a2dp_get_max_connection_retries

DESCRIPTION
    Helper function to Get the a2dp max connection retries.

RETURNS
    The max connection retries value as read from the config block section.

**************************************************************************/
uint16 a2dp_get_max_connection_retries(void)
{
    uint16 a2dp_max_connection_retries = 0;
    a2dp_codecs_config_def_t *a2dp_connection_retries;

    if (configManagerGetReadOnlyConfig(A2DP_CODECS_CONFIG_BLK_ID, (const void **)&a2dp_connection_retries))
    {
        a2dp_max_connection_retries = a2dp_connection_retries->A2DPMaxContRetries;
    }
    configManagerReleaseConfig(A2DP_CODECS_CONFIG_BLK_ID);
    return a2dp_max_connection_retries;
}
/*************************************************************************
NAME
    a2dp_get_sbc_sampling_frequency

DESCRIPTION
    Helper function to get the sampling frequency to be used over SBC.

RETURNS
   0 = Channel Mode Joint Stereo,1 = Channel Mode Stereo,3 = Channel Mode Mono,
   4 = Sampling Frequency 48 kHz,5 =Sampling Frequency 44.1 kHz ,6  =Sampling Frequency 32 kHz ,
   7 =Sampling Frequency 16 kHz 

**************************************************************************/
static  uint8 a2dp_get_sbc_sampling_frequency(void)
{
    uint8 SamplingFrequency = 0;
    sbc_codec_features_config_def_t *sbc_codec_features;

    if (configManagerGetReadOnlyConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID, (const void **)&sbc_codec_features))
    {
        SamplingFrequency = sbc_codec_features->SamplingFrequency;
    }
    configManagerReleaseConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID);
    return SamplingFrequency;
}
/*************************************************************************
NAME
    a2dp_get_min_bit_pool

DESCRIPTION
   Helper function to get the minimum bit pool size supported by SBC.

RETURNS
    The min bit pool value as read from the config block section.,

**************************************************************************/
static uint8 a2dp_get_min_bit_pool(void)
{
    uint8 sbcMinBitpool = 0;
    sbc_codec_features_config_def_t *sbc_codec_features;

    if (configManagerGetReadOnlyConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID, (const void **)&sbc_codec_features))
    {
        sbcMinBitpool = sbc_codec_features->sbcMinBitpool;
    }
    configManagerReleaseConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID);
    return sbcMinBitpool;
}
/*************************************************************************
NAME
    a2dp_get_max_bit_pool

DESCRIPTION
    Helper function to get the maximum bit pool size supported by SBC.

RETURNS
    The max bit pool value as read from the config block section.

**************************************************************************/
static uint8 a2dp_get_max_bit_pool(void)
{
    uint8 sbcMaxBitpool = 0;
    sbc_codec_features_config_def_t *sbc_codec_features;

    if (configManagerGetReadOnlyConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID, (const void **)&sbc_codec_features))
    {
        sbcMaxBitpool = sbc_codec_features->sbcMaxBitpool;
    }
    configManagerReleaseConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID);
    return sbcMaxBitpool;
}
/*************************************************************************
NAME
    a2dp_get_faststream_sampling_frequency

DESCRIPTION
    Helper function to get the sampling frequency to be used over fast stream.

RETURNS
       0 = FastStream Music Sampling Frequency 48 kHz,1 = FastStream Music Sampling Frequency 44.1 kHz
       5 =FastStream Voice Sampling Frequency 16 kHz

**************************************************************************/
static uint8 a2dp_get_faststream_sampling_frequency(void)
{
    uint8 SamplingFrequency = 0;
    fast_stream_config_def_t *fastStream_codec_features;

    if (configManagerGetReadOnlyConfig(FAST_STREAM_CONFIG_BLK_ID, (const void **)&fastStream_codec_features))
    {
        SamplingFrequency = fastStream_codec_features->MusicVoiceSampFreq;
    }
    configManagerReleaseConfig(FAST_STREAM_CONFIG_BLK_ID);
    return SamplingFrequency;
}
/*************************************************************************
NAME
    a2dp_get_faststream_voice_music_support

DESCRIPTION
    Helper function to get the voice and music support to be used over fast stream.

RETURNS
       0 = FastStream Music, 1 =  FastStream Voice,

**************************************************************************/
static uint8 a2dp_get_faststream_voice_music_support(void)
{
    uint8 voicemusicsupport = 0;
    fast_stream_config_def_t *fastStream_codec_features;

    if (configManagerGetReadOnlyConfig(FAST_STREAM_CONFIG_BLK_ID, (const void **)&fastStream_codec_features))
    {
        voicemusicsupport = fastStream_codec_features->MusicVoiceSupport;
    }
    configManagerReleaseConfig(FAST_STREAM_CONFIG_BLK_ID);
    return voicemusicsupport;
}
/*************************************************************************
NAME
    a2dp_get_aptx_sampling_frequency

DESCRIPTION
    Helper function to get the sampling frequency to be used over aptx.

RETURNS
       4 = if the value is set as 'Sampling Frequency 48 kHz' in the config block
       5 = if the value is set as 'Sampling Frequency 44.1 kHz' in the config block
       6 = if the value is set as 'Sampling Frequency 32 kHz ' in the config block
       7 = if the value is set as 'Sampling Frequency 16 kHz ' in the config block

**************************************************************************/
static uint8 a2dp_get_aptx_sampling_frequency(void)
{
    uint8 SamplingFrequency = 0;
    aptx_config_def_t *Aptx_codec_features;

    if (configManagerGetReadOnlyConfig(APTX_CONFIG_BLK_ID, (const void **)&Aptx_codec_features))
    {
        SamplingFrequency = Aptx_codec_features->AptXSamplingFreq;
    }
    configManagerReleaseConfig(APTX_CONFIG_BLK_ID);
    return SamplingFrequency;
}
/*************************************************************************
NAME
    a2dp_get_aptxLL_sampling_frequency

DESCRIPTION
    Helper function to get the sampling frequency to be used over aptx low latency.

RETURNS
       4 = if the value is set as 'Sampling Frequency 48 kHz' in the config block.
       5 = if the value is set as 'Sampling Frequency 44.1 kHz'in the config block.

**************************************************************************/
static uint8 a2dp_get_aptxLL_sampling_frequency(void)
{
    uint8 SamplingFrequency = 0;
    aptx_low_latency_config_def_t *AptxLL_codec_features;

    if (configManagerGetReadOnlyConfig(APTX_LOW_LATENCY_CONFIG_BLK_ID, (const void **)&AptxLL_codec_features))
    {
        SamplingFrequency = AptxLL_codec_features->AptXLowLatencySampFreq;
    }
    configManagerReleaseConfig(APTX_LOW_LATENCY_CONFIG_BLK_ID);
    return SamplingFrequency;
}
/*************************************************************************
NAME
    a2dp_get_aptxLL_bidiirectional_value

DESCRIPTION
    Helper function to get the bidirectional value to be used over aptx low latency.

RETURNS
    TRUE, if this value is set,
    FALSE, otherwise.

**************************************************************************/
static bool a2dp_get_aptxLL_bidiirectional_value(void)
{
    uint8 aptxLLBidirectional = 0;
    aptx_low_latency_config_def_t *AptxLL_codec_features;

    if (configManagerGetReadOnlyConfig(APTX_LOW_LATENCY_CONFIG_BLK_ID, (const void **)&AptxLL_codec_features))
    {
        aptxLLBidirectional = AptxLL_codec_features->aptxLLBidirectional;
    }
    configManagerReleaseConfig(APTX_LOW_LATENCY_CONFIG_BLK_ID);
    return aptxLLBidirectional;
}
/*************************************************************************
NAME
    a2dp_get_aptxHD_sampling_frequency

DESCRIPTION
    Helper function to get the sampling frequency to be used over aptx HD.

RETURNS
       4 = Sampling Frequency 48 kHz,5 = Sampling Frequency 44.1 kHz

**************************************************************************/
static uint8 a2dp_get_aptxHD_sampling_frequency(void)
{
    uint8 SamplingFrequency = 0;
    aptx_hd_config_def_t *AptxHD_codec_features;

    if (configManagerGetReadOnlyConfig(APTX_HD_CONFIG_BLK_ID, (const void **)&AptxHD_codec_features))
    {
        SamplingFrequency = AptxHD_codec_features->AptXHDSampFreq;
    }
    configManagerReleaseConfig(APTX_HD_CONFIG_BLK_ID);
    return SamplingFrequency;
}

/*************************************************************************
NAME
    a2dp_get_profile_value

DESCRIPTION
    Helper function to get the A2DP profile values.

RETURNS
    A2DP_PROFILE_1_2 if enabled, else returns A2DP_PROFILE_DISABLED.

**************************************************************************/
A2DP_PROFILE_T a2dp_get_profile_value(void)
{       
    A2DP_PROFILE_T a2dp_profile = A2DP_PROFILE_DISABLED;
    
#ifdef MS_LYNC_ONLY_BUILD   
    a2dp_profile = A2DP_PROFILE_DISABLED;
#else
    a2dp_codecs_config_def_t *a2dp_codec_config = NULL;
    if (configManagerGetReadOnlyConfig(A2DP_CODECS_CONFIG_BLK_ID, (const void **)&a2dp_codec_config))
    {
        a2dp_profile = a2dp_codec_config->a2dpProfile;;
    }
    configManagerReleaseConfig(A2DP_CODECS_CONFIG_BLK_ID);
#endif
    return a2dp_profile;
}
/*************************************************************************
NAME
    a2dp_set_sampling_frequency

DESCRIPTION
    Helper function to set the sampling frequency to be used over SBC.

**************************************************************************/
static void a2dp_set_sampling_frequency(uint8 SamplingFrequency)
{
    sbc_codec_features_config_def_t *sbc_codec_features = NULL;

    if (configManagerGetWriteableConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID, (void **)&sbc_codec_features,0))
    {
        sbc_codec_features->SamplingFrequency = SamplingFrequency;
    }
    configManagerUpdateWriteableConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID);
}

/*************************************************************************
NAME
    a2dp_get_sbc_configurable_values

DESCRIPTION
    This function reads the  SBC configuration values.

**************************************************************************/
static uint16  a2dp_get_sbc_configurable_values(void)
{
    sbc_codec_features_config_def_t *a2dp_sbc_codec_config = NULL;
    uint16  ret = 0;

    ret  = configManagerGetReadOnlyConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID, (const void **)&a2dp_sbc_codec_config);
    configManagerReleaseConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID);

    return ret;
}
/*************************************************************************
NAME
    a2dp_get_faststream_configurable_values

DESCRIPTION
    This function reads Faststream configuration values 


**************************************************************************/
static uint16  a2dp_get_faststream_configurable_values(void)
{
    fast_stream_config_def_t *a2dp_faststream_codec_config = NULL;
    uint16  ret = 0;

    ret = configManagerGetReadOnlyConfig(FAST_STREAM_CONFIG_BLK_ID, (const void **)&a2dp_faststream_codec_config);
    configManagerReleaseConfig(FAST_STREAM_CONFIG_BLK_ID);
    return ret;
}
/*************************************************************************
NAME
    a2dp_get_aptx_configurable_values

DESCRIPTION
    This function reads aptx configuration values 


**************************************************************************/
static uint16  a2dp_get_aptx_configurable_values(void)
{
    aptx_config_def_t *a2dp_aptx_codec_config = NULL;
    uint16  ret = 0;

    ret  = configManagerGetReadOnlyConfig(APTX_CONFIG_BLK_ID, (const void **)&a2dp_aptx_codec_config);
    configManagerReleaseConfig(APTX_CONFIG_BLK_ID);

    return ret;
}
/*************************************************************************
NAME
    a2dp_get_aptxLL_configurable_values

DESCRIPTION
    This function reads aptx Low latency configuration values 


**************************************************************************/
static uint16  a2dp_get_aptxLL_configurable_values(void)
{
    aptx_low_latency_config_def_t *a2dp_aptxLL_codec_config = NULL;
    uint16  ret = 0;

    ret = configManagerGetReadOnlyConfig(APTX_LOW_LATENCY_CONFIG_BLK_ID, (const void **)&a2dp_aptxLL_codec_config);
    configManagerReleaseConfig(APTX_LOW_LATENCY_CONFIG_BLK_ID);
 
    return ret;
}
/*************************************************************************
NAME
    a2dp_get_aptxHD_configurable_values

DESCRIPTION
    This function reads aptx HD configuration values 


**************************************************************************/
static uint16  a2dp_get_aptxHD_configurable_values(void)
{
    aptx_hd_config_def_t *a2dp_aptxHD_codec_config = NULL;
    uint16  ret = 0;

    ret = configManagerGetReadOnlyConfig(APTX_HD_CONFIG_BLK_ID, (const void **)&a2dp_aptxHD_codec_config);
    configManagerReleaseConfig(APTX_HD_CONFIG_BLK_ID);
    return ret;
}
/*************************************************************************
NAME
    a2dp_get_connection_failed_timer

DESCRIPTION
    Helper function to Get the A2DP Connection Failed timer.

RETURNS
    The connection failed timer value as read from the config block section.,

**************************************************************************/
uint16 a2dp_get_connection_failed_timer(void)
{
    uint16 A2DP_Connection_timer = 0;
    a2dp_codecs_config_def_t *a2dp_timer_data;

    if (configManagerGetReadOnlyConfig(A2DP_CODECS_CONFIG_BLK_ID, (const void **)&a2dp_timer_data))
    {
        A2DP_Connection_timer = a2dp_timer_data->A2DPConnectionFailed_m;
    }
    configManagerReleaseConfig(A2DP_CODECS_CONFIG_BLK_ID);
    return A2DP_Connection_timer;
}
/*************************************************************************
NAME
    a2dp_set_connection_failed_timer

DESCRIPTION
    Helper function to set the A2DPP Connection Failed timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
***************************************************************************/
bool a2dp_set_connection_failed_timer(uint16 timeout)
{
    a2dp_codecs_config_def_t *a2dp_tmer_data = NULL;
    bool ret = FALSE;
    
    if (configManagerGetWriteableConfig(A2DP_CODECS_CONFIG_BLK_ID, (void **)&a2dp_tmer_data, 0))
    {
        a2dp_tmer_data->A2DPConnectionFailed_m = timeout ;
        ret= TRUE;
    }
    else
    {
        ret =  FALSE;
    }
    configManagerReleaseConfig(A2DP_CODECS_CONFIG_BLK_ID);
    return ret;
}
/******************************************************************************
NAME
    audio_get_input_source

DESCRIPTION
    Helper function to get the Input Source.

RETURNS:
    0 = USB, 1 = Analogue,2 = SPDIF ,3  = I2S and 4 = Unassigned.The default value is set to 0
***************************************************************************/
uint8 audio_get_input_source(void)
{
    uint8 input_source = 0;
    source_audio_type_config_def_t *audio_input_source = NULL;

    if (configManagerGetReadOnlyConfig(SOURCE_AUDIO_TYPE_CONFIG_BLK_ID, (const void **)&audio_input_source))
    {
        input_source = audio_input_source->Input_Source;
    }
    configManagerReleaseConfig(SOURCE_AUDIO_TYPE_CONFIG_BLK_ID);
    return input_source;
}
/******************************************************************************
NAME
    audio_get_digital_input_bits_per_sample

DESCRIPTION
    Helper function to get the digital input bits per sample.

RETURNS
    The current bits per sample which is configured.
    16 = 16 bits per sample,24 = 24 bits per sample,32 = 32 bits per sample and 0 = Unassigned.
***************************************************************************/
uint8 audio_get_digital_input_bits_per_sample(void)
{
    uint8 digital_input_bits_per_sample = 0;
    source_audio_type_config_def_t *audio_input_source = NULL;

    if (configManagerGetReadOnlyConfig(SOURCE_AUDIO_TYPE_CONFIG_BLK_ID, (const void **)&audio_input_source))
    {
        digital_input_bits_per_sample = audio_input_source->featuresDigitalInputBitsPerSample;
    }
    configManagerReleaseConfig(SOURCE_AUDIO_TYPE_CONFIG_BLK_ID);
    return digital_input_bits_per_sample;
}
/*************************************************************************
NAME
    audio_get_spdif_input_Values

DESCRIPTION
    Helper function to Get the SPDIF input output values

RETURNS
    The current PIO that is configured.
    PIO 0 - PIO 31,Disable,Always Detect and Unassigned.

**************************************************************************/
uint16  audio_get_spdif_input_Values(void)
{
    source_input_output_readonly_config_def_t *SPDIF_Input = NULL;
    uint16 spdif_value = 0;
    
    if (configManagerGetReadOnlyConfig(SOURCE_INPUT_OUTPUT_READONLY_CONFIG_BLK_ID, (const void **)&SPDIF_Input))
    {
        spdif_value  = SPDIF_Input->spdif_pio;
    }
    configManagerReleaseConfig(SOURCE_INPUT_OUTPUT_READONLY_CONFIG_BLK_ID);
    return spdif_value;
}
#ifdef PTS_TEST_ENABLED
/*************************************************************************
NAME
    a2dp_get_sbc_parameters

DESCRIPTION
    Helper function to get the block length,subband ,allocation and loudness for SBC codec. 
	This is used only for Qualification testing.

RETURNS
   0 = SBC Allocation Loudness,1 = SBC Allocation SNR,2 = SBC Subbands 8,
   3 = SBC Subbands 4,4 =SBC Block Length 16 ,5  =SBC Block Length 12 ,
   6 = SBC Block Length 8 , 7 = SBC Block Length 4. 

**************************************************************************/
static uint8 a2dp_get_sbc_parameters(void)
{
    uint8 sbc_config_values = 0;
    sbc_codec_features_config_def_t *sbc_codec_features;

    if (configManagerGetReadOnlyConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID, (const void **)&sbc_codec_features))
    {
        sbc_config_values = sbc_codec_features->SbcParams;
    }
    configManagerReleaseConfig(SBC_CODEC_FEATURES_CONFIG_BLK_ID);
    return sbc_config_values;
}
#endif
/********************************************************************************************************/
