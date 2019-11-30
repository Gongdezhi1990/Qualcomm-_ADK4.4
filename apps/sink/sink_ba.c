/*******************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    sink_ba.c

DESCRIPTION
    Manages Broadcast Audio Application.
    
NOTES

*/

#include "sink_ba.h"
#include "sink_ba_common.h"
#include "sink_ba_broadcaster.h"
#include "sink_ba_receiver.h"
#include "sink_main_task.h"
#include "sink_audio_indication.h"
#include "sink_statemanager.h"
#include "sink_configmanager.h"
#include "sink_multi_channel_config_def.h"
#include "sink_ble.h"
#include "sink_ba_ble_gap.h"
#include "sink_a2dp.h"
#include "sink_wired.h"
#include "sink_usb.h"
#include "sink_volume.h"

#ifdef ENABLE_BROADCAST_AUDIO
#include "sink_broadcast_audio_config_def.h"

#include <gatt_manager.h>
#include <message.h>
#include <gain_utils.h>
#include <audio_output.h>
#include <vmtypes.h>
#include <broadcast_context.h>
#include <broadcast_cmd.h>
#include <ttp_latency.h>

#ifdef DEBUG_BA_COMMON
#define DEBUG_BA(x) DEBUG(x)
#else
#define DEBUG_BA(x) 
#endif

/* PSKEY to store broadcast audio mode */
#define SINK_BROADCAST_AUDIO_PSKEY  (CONFIG_BROADCAST_AUDIO_MODE)
/* Default BA association time out */
#define SINK_BA_ASSOCIATION_TIME_OUT 30

const char * const ba_modes[3] = {
    "NORMAL",
    "BROADCASTER",
    "RECEIVER",
};

/* Global data for Broadcast Audio Module  */
typedef struct _ba_global_data_t
{
    TaskData baAppTask; /* Broadcast Audio Application handler */
    uint16 modeswitch_inprogress; /* Are we in the process of mode change */
    erasure_coding_scheme_t requested_ec_scheme;
    unsigned ba_mode:2; /* Stores current broadcast Audio Mode*/
    unsigned ba_stored_mode:2; /* Stores current broadcast Audio Mode*/
    unsigned unused:12; /* Padding */
}ba_global_data_t;

/* Broadcast audio global data */
static ba_global_data_t gBaData;
#define BA_DATA  gBaData

/* Broadcast Audio Role Defines */
#define IS_MODE_CHANGE_IN_PROGRESS (BA_DATA.modeswitch_inprogress == TRUE)

/* The delay in seconds for playing power on prompt, after which Broadcast audio is powered on */
#define BA_POWER_ON_PROMPT_DELAY (1)

/*-----------------------Static Functions ---------------------------------*/

/***************************************************************************
NAME
    broadcastAudioResetData
 
DESCRIPTION
    Utility function used to reset Broadcast Audio related data.
 
PARAMS
    void 
RETURNS
    void
*/
static void broadcastAudioResetData(void)
{
   memset(&BA_DATA,0,sizeof(BA_DATA));
}

/***************************************************************************
NAME
    broadcastAudioReadConfigItem
 
DESCRIPTION
    Utility function to Read Broadcast Audio Config Items, if the config items
    are not as per required format then defualt values will be used
PARAMS
    item  Buffer to where config item need to be copied
RETURNS
    void
*/
static void broadcastAudioReadConfigItem(uint16* item)
{
    if(item)
    {
        uint16 read_data_size;

        read_data_size = PsRetrieve(SINK_BROADCAST_AUDIO_PSKEY, (void*)item, sizeof(uint16));
        /* If the data read is not as per required, then fill in default values */
        if(!read_data_size)
        {
            /* Return default config */
            *item = sink_ba_appmode_normal;
        }
    }
}

/*******************************************************************************
NAME
    broadcastAudioGetRequestedMode().

DESCRIPTION
    Utility function to get the requested mode

 PARAMS
    None

 RETURNS
    sink_ba_app_mode_t current app mode
*/
static sink_ba_app_mode_t broadcastAudioGetRequestedMode(void)
{
    sink_ba_app_mode_t req_mode;
    req_mode = BA_DATA.ba_stored_mode;
    return req_mode;
}

/***************************************************************************
NAME
    ReceiverMessageHandler
 
DESCRIPTION
    Application Message Handler for Receiver Role.
 
PARAMS
    task Application Task
    id Message ID
    Message Message to application receiver task
 
RETURNS
    void
*/
static void ReceiverMessageHandler(Task task, MessageId id, Message message)
{
    UNUSED(task);

    if(!BA_RECEIVER_MODE_ACTIVE)
    {
        /* We could have received this for switching to standalone mode */
        if(id == RECEIVER_INTERNAL_MSG_STOP_BLE_BROADCAST)
            sinkBleStopBroadcastEvent();
        return;
    }

    if ((id >= BROADCAST_MESSAGE_BASE) && (id < BROADCAST_MESSAGE_TOP))
    {
        sinkReceiverHandleBroadcastMessage(&BA_DATA.baAppTask, id, message);
        return;
    }

    /* handle SCM messages */
    if ((id >= BROADCAST_CMD_MESSAGE_BASE) && (id < BROADCAST_CMD_MESSAGE_TOP))
    {
        sinkReceiverHandleBcmdMessage(&BA_DATA.baAppTask, id, message);
        return;
    }

    switch(id)
    {
    case RECEIVER_MSG_WRITE_VOLUME_PSKEY:
        sinkReceiverWriteVolumePsKey();
        break;

    case RECEIVER_INTERNAL_MSG_STOP_RECEIVER:
        sinkReceiverStopReceiver();
        break;

    case RECEIVER_INTERNAL_MSG_DESTROY_RECEIVER:
        sinkReceiverDestroyReceiver();
        break;

    case RECEIVER_INTERNAL_MSG_START_RECEIVER:
        sinkReceiverInternalStartReceiver(task);
        break;

    case RECEIVER_INTERNAL_MSG_AUDIO_DISCONNECT:
        sinkReceiverInternalDisconnectAudio();
        break;

    default:
        DEBUG_BA(("BA: Receiver unhandled Message : %d) \n",id ));
        break;
    }
}

/***************************************************************************
NAME
    broadcastAudioPowerOff
 
DESCRIPTION
    Utility function to power off broadacast Audio.
 
PARAMS
    None
RETURNS
    bool TRUE if init successful else FALSE;
*/
static bool broadcastAudioPowerOff(void)
{
    /* No action if in broadcaster mode */
    if(BA_RECEIVER_MODE_ACTIVE)
    {
       DEBUG_BA(("BA: Power Off Receiver\n" ));
       sinkReceiverPowerOff(&BA_DATA.baAppTask);
       return TRUE;
    }
    else if(BA_BROADCASTER_MODE_ACTIVE)
    {
        /* If we are powering off, stop broadcasting */
        DEBUG_BA(("Sending stop broadcaster\n"));
        MessageSendConditionally(&BA_DATA.baAppTask,
                                 BROADCASTER_INTERNAL_MSG_STOP_BROADCASTER,
                                 NULL, BroadcastContextGetBroadcastBusy());
        return TRUE;
    }
    return FALSE;
}

/*******************************************************************************/
static bool broadcastAudioIsModeValid(sink_ba_app_mode_t mode)
{
    bool valid = FALSE;
    
    switch(mode)
    {
        case sink_ba_appmode_normal:
        case sink_ba_appmode_broadcaster:
        case sink_ba_appmode_receiver:
            valid = TRUE;
            break;
        default:
            break;
    }
    return valid;
}

static bool hasEcSchemeChangeBeenRequested(void)
{
    return sinkBroadcastAudioGetEcScheme() != BroadcastContextGetEcScheme();
}

static bool isModeAllowedToChange(sink_ba_app_mode_t mode)
{
    bool broadcaster_internal_transition = BA_DATA.ba_mode == mode && mode == sink_ba_appmode_broadcaster;

    if(broadcaster_internal_transition && hasEcSchemeChangeBeenRequested())
    {
        return TRUE;
    }
    else
    {
        return BA_DATA.ba_mode != mode;
    }
}

/*******************************************************************************/
static bool broadcastAudioAllowModeChange(sink_ba_app_mode_t mode)
{
    if( stateManagerGetState() != deviceLimbo )
    {
        /* If we are already in the process of mode switching or the switch request
            role is the existing role, then reject the request
        */
        if(isModeAllowedToChange(mode) && !IS_MODE_CHANGE_IN_PROGRESS)
        {
            /* if Call is in progress */
            if(stateManagerGetState() != deviceActiveCallSCO)
               return TRUE;
        }
    }
    return FALSE;
}

/*******************************************************************************/
static bool isModeSwitchToNormal(void)
{
    bool switch_to_normal = FALSE;
    
   if(IS_MODE_CHANGE_IN_PROGRESS && 
      (broadcastAudioGetRequestedMode() == sink_ba_appmode_normal))
        switch_to_normal = TRUE;

    return switch_to_normal;
}

/*******************************************************************************/
static void broadcastAudioStart(void)
{
    /* Init Broadcaster/Receiver */
    sinkBroadcastAudioInit();
    sinkBroadcastAudioPowerOn();
}
/***************************************************************************
NAME
    broadcastAudioRestrictSupportedCodecs

DESCRIPTION
    Utility function to restrict supported codecs
PARAMS
    void
RETURNS
    void
*/

static void broadcastAudioRestrictSupportedCodecs(void)
{
    uint8 compatible_optional_codecs = 0x00;

    /*All supported optional codecs in BA*/
    compatible_optional_codecs = sinkBroadcastAudioGetOptionalCodecsMask();

    /*Create final list of supported optional codecs by cross referencing
    *against the ones user selected
    */
    compatible_optional_codecs &= sinkA2dpGetOptionalCodecsEnabledFlag();

    sinkA2dpRestrictSupportedCodecs(compatible_optional_codecs);
    sinkA2dpRenegotiateCodecsForAllSources();
}

static void indicateModeSwitchEvent(sink_ba_app_mode_t mode)
{
    sinkEvents_t switch_event = EventSysLast;

    switch (mode)
    {
        case sink_ba_appmode_broadcaster:
            switch_event = EventSysBABroadcasterModeActive;
        break;
        case sink_ba_appmode_receiver:
            switch_event = EventSysBAReceiverModeActive;
        break;
        case sink_ba_appmode_normal:
            switch_event = EventSysNormalModeActive;
        break;
        default:
        break;
    }

    if(switch_event != EventSysLast)
        MessageSend(sinkGetMainTask(), switch_event, NULL );
}

/*******************************************************************************/
static void broadcastAudioSwitchMode(sink_ba_app_mode_t requested_mode)
{
    switch(requested_mode)
    {
        case sink_ba_appmode_normal:
            {
                if(BA_RECEIVER_MODE_ACTIVE)
                {
                    /* De-Init Receiver */
                   sinkReceiverDeInit();
                }
                else if(BA_BROADCASTER_MODE_ACTIVE)
                {
                    /*De-Init Broadcaster*/
                    sinkBroadcasterDeInit();
                }
                sinkA2dpEnableAllSupportedCodecs();
                audioUpdateAudioRouting();
            }
            break;
        case sink_ba_appmode_broadcaster:
            {
                if(!BA_BROADCASTER_MODE_ACTIVE)
                {
                    if(BA_RECEIVER_MODE_ACTIVE)
                    {
                        sinkReceiverDeleteBroadcasterInfo();
                        /* De-Init Receiver */
                        sinkReceiverDeInit();
                    }
                    else
                    {
                        /* Set New mode as Broadcaster */
                        sinkBroadcastAudioSetMode(requested_mode);
                        indicateModeSwitchEvent(sink_ba_appmode_broadcaster);
                        broadcastAudioStart();
                    }
                    broadcastAudioRestrictSupportedCodecs();
                    audioUpdateAudioRouting();
                }
                else
                {
                    sinkBroadcasterDeInit();
                }
            }
            break;
        case sink_ba_appmode_receiver:
            {
                if(BA_BROADCASTER_MODE_ACTIVE)
                    sinkBroadcasterDeInit();
                else
                {
                    /* Set New mode as Receiver */
                    sinkBroadcastAudioSetMode(requested_mode);
                    indicateModeSwitchEvent(sink_ba_appmode_receiver);
                    /* Init Receiver */
                    broadcastAudioStart();
                }
            }
            break;
        default:
            break;
    }
}

/*--------------------Interfaces to BA Module----------------------*/

/*******************************************************************************/
void  sinkBroadcastAudioStoreConfigItem(void)
{
    uint16 config_item = BA_DATA.ba_mode;
    PsStore(SINK_BROADCAST_AUDIO_PSKEY, (const void*)&config_item, sizeof(config_item));
}

/*******************************************************************************/
void sinkBroadcastAudioHandleUserPowerOn(void)
{
    /* Power On broadcast audio */
    sinkBroadcastAudioPowerOn();
}

/*******************************************************************************/
void sinkBroadcastAudioPowerOff(void)
{
    if (sinkBroadcastAudioIsActive())
    {
        /* If broadcast audio is in the process of mode change no need to handle
         power off request, power off of broadcst audio must be already handled
         */
        if(!IS_MODE_CHANGE_IN_PROGRESS)
            broadcastAudioPowerOff();
    }
    sinkBroadcastAudioStoreConfigItem();
}

/*******************************************************************************/
void sinkBroadcastAudioVolumeUp(void)
{
} 

/*******************************************************************************/
void sinkBroadcastAudioVolumeDown(void)
{
}

/*******************************************************************************/
void sinkBroadcastAudioStartAssociation(void)
{
    if(BA_RECEIVER_MODE_ACTIVE)
    {
       DEBUG_BA(("BA: Start Association for receiver\n" ));
       sinkReceiverStartAssociation();
    }
    /* Call the BLE module to take care of the event */
    sinkBleAssociationEvent();
}

/*******************************************************************************/
Task sinkBroadcastAudioGetAppTask(void)
{
    return (&BA_DATA.baAppTask);
}

/*******************************************************************************/
void sinkBroadcastAudioHandleInitCfm(void)
{
    if(IS_MODE_CHANGE_IN_PROGRESS)
    {
        DEBUG_BA(("BA: sinkBroadcastAudioHandleInitCfm(): Mode = %d \n", sinkBroadcastAudioGetMode()));
        /* This initialization is due to mode switch */
        BA_DATA.modeswitch_inprogress  = FALSE;
    }
    else
    {
        /* Initialization in BA mode upon boot up */
    }
}

/*******************************************************************************/
void sinkBroadcastAudioHandleDeInitCfm(sink_ba_app_mode_t mode)
{
    if(IS_MODE_CHANGE_IN_PROGRESS)
    {
        sink_ba_app_mode_t next_mode = broadcastAudioGetRequestedMode();
        /* Set New mode */
        sinkBroadcastAudioSetMode(next_mode);

        /* This initialization was due to mode switch */
        if(mode != next_mode)
        {
            if(next_mode == sink_ba_appmode_normal)
            {
                /* Switching from BA to normal mode */
                BA_DATA.modeswitch_inprogress = FALSE;
                audioUpdateAudioRouting();
            }
            else
            {
                /* Initialize Broadcaster/reciever */
                broadcastAudioStart();
            }
        }
        else if(mode == sink_ba_appmode_broadcaster && hasEcSchemeChangeBeenRequested())
        {
            broadcastAudioStart();
        }
        indicateModeSwitchEvent(next_mode);
    }
    else
    {
        /* Initialization in BA mode upon boot up */
    }
}

/*******************************************************************************/
void sinkBroadcastAudioInit(void)
{
    DEBUG_BA(("BA: sinkBroadcastAudioInit(): Mode = %s \n", ba_modes[sinkBroadcastAudioGetMode()]));
    /* Check if we are in proper BA role before initialising the lib */
    switch(sinkBroadcastAudioGetMode())
    {
        case sink_ba_appmode_broadcaster:
            {
                /* Initialize the Broadcaster */
                (void)sinkBroadcasterInit(&BA_DATA.baAppTask);
            }
            break;
        case sink_ba_appmode_receiver:
            {
                /* Initialise Broadcaster task handler */
                BA_DATA.baAppTask.handler = ReceiverMessageHandler;
                /* Init receiver */
                sinkReceiverInit(&BA_DATA.baAppTask);
            }
            break;

        default:
            return;
    }

    /*Indicate on LED that we are in BA Mode */
    MessageSend(sinkGetMainTask(), EventSysBAModeIndicationStart, NULL ) ;
}

/*******************************************************************************/
bool sinkBroadcastAudioIsActive(void)
{
    return (BA_DATA.ba_mode != sink_ba_appmode_normal);
}

/*******************************************************************************/
void sinkBroadcastAudioConfigure(void)
{
    uint16 config_data;

    DEBUG_BA(("BA: sinkBroadcastAudioConfigure()\n"));
    /* Reset BA global data */
    broadcastAudioResetData();
    /* Read the mode configuration */
    broadcastAudioReadConfigItem(&config_data);
    /* Store the Mode for future use */
    BA_DATA.ba_mode = config_data;
    /* Validate mode */
    PanicFalse(broadcastAudioIsModeValid(BA_DATA.ba_mode));

    DEBUG_BA(("BA: Broadcast Audio Configured with Mode [%s] \n",ba_modes[BA_DATA.ba_mode]));
}

/*******************************************************************************/
void sinkBroadcastAudioSetMasterRole( uint16 device_id)
{
    if(BA_BROADCASTER_MODE_ACTIVE)
        sinkBroadcasterSetMasterRole(device_id);
}

/*******************************************************************************/
sink_ba_app_mode_t sinkBroadcastAudioGetMode(void)
{
    /*DEBUG_BA(("BA: sinkBroadcastAudioGetMode(), Mode [%s] \n",ba_modes[BA_DATA.ba_mode]));*/
    return BA_DATA.ba_mode;
}

/*******************************************************************************/
void sinkBroadcastAudioSetMode(sink_ba_app_mode_t mode)
{
    DEBUG_BA(("BA: sinkBaSetBroadcastMode(), Mode %s \n",ba_modes[mode]));
    BA_DATA.ba_mode = mode;
}

/*******************************************************************************/
bool sinkBroadcastAudioChangeMode(sink_ba_app_mode_t mode)
{
    bool result = FALSE;

    if( broadcastAudioAllowModeChange(mode) )
    {
        /* Mark we are in the process of mode switch */
        BA_DATA.modeswitch_inprogress = TRUE;

        /* If association is in progress then cancel before we leave BA mode */
        if(gapBaGetAssociationInProgress())
            sinkBleCancelAssociationEvent();

        /* First disconnect routed Audio/Voice source if any */
        audioDisconnectRoutedAudio();
        audioDisconnectRoutedVoice();

        /* Store the requested mode */
        BA_DATA.ba_stored_mode = mode;
        broadcastAudioSwitchMode(mode);
        result = TRUE;
    }
    return result;
}

/*******************************************************************************/
Task sinkBroadcastAudioGetHandler(void)
{
    return &BA_DATA.baAppTask;
}

/*******************************************************************************/
void sinkBroadcastAudioPowerOn(void)
{
    DEBUG_BA(("BA: Broadcast Audio Power On \n"));
    if(BA_BROADCASTER_MODE_ACTIVE)
    {
        sinkBroadcasterHandlePowerOn(&BA_DATA.baAppTask);
    }
    else if(BA_RECEIVER_MODE_ACTIVE)
    {
        sinkReceiverHandlePowerOn(&BA_DATA.baAppTask);
    }
}

/*******************************************************************************/
uint8 sinkBroadcastAudioGetOptionalCodecsMask(void)
{
    uint8 mask = 1 << AAC_CODEC_BIT;

    return mask;
}

/*******************************************************************************/
uint16 sinkBroadcastAudioGetAssociationTimeOut(void)
{
    ba_config_def_t* ro_config_data = NULL;
    /* Let's have default timer value of 30 seconds */
    uint16 assoc_timeout = SINK_BA_ASSOCIATION_TIME_OUT;

    if (configManagerGetReadOnlyConfig(BA_CONFIG_BLK_ID, (const void **)&ro_config_data))
    {
        assoc_timeout = ro_config_data->assoc_timeout_s;
        configManagerReleaseConfig(BA_CONFIG_BLK_ID);
    }
    return assoc_timeout;
}

/***************************************************************************
NAME
    setupReceiverAudio
 
DESCRIPTION
    Utility function to Connect DSP to DACs
 
PARAMS
    rate Sampling Frequency
 
RETURNS
    void
*/
static void audioGetVolumeInfoFromSource(audio_sources source, volume_info *volume)
{
    switch(source)
    {  
        case audio_source_ANALOG:
        case audio_source_I2S:
            SinkWiredGetAnalogVolume(volume);
            break;

        case audio_source_USB:
            sinkUsbGetUsbVolume(volume);
            break;
        case audio_source_a2dp_1:
            *volume = *sinkA2dpGetA2dpVolumeInfoAtIndex(a2dp_primary);
            break;
        case audio_source_a2dp_2:
            *volume = *sinkA2dpGetA2dpVolumeInfoAtIndex(a2dp_secondary);
            break;
        case audio_source_none:
        default:
            memset(volume, 0, sizeof(*volume));
            break;
    }
}

/***************************************************************************
NAME
    getSystemGainFromMaster
 
DESCRIPTION
    Utility function to get system gain from Master (digital) gain
 
PARAMS
    volume Volume in DB
 
RETURNS
    uint16 Gain
*/
static uint16 getSystemGainFromMaster(int16 master)
{
    int16 system = 0;
    int16 ba_offset = 0;
    /* Convert dB master volume to DAC based system volume */
    int16 normal_mode_system_step = (CODEC_STEPS + (master / DB_TO_DAC));

    if(normal_mode_system_step > 0)
    {
        /* BA offset is always 2 times as it ranges from 0-31 */
        ba_offset = (CODEC_STEPS - normal_mode_system_step) * 2;
        system = BA_MAX_STEPS - ba_offset;
    }

    DEBUG_BA(("BA System Volume level %d\n", system));
   
    return (uint16)system;
}

/*******************************************************************************/
int16 sinkBroadcastAudioGetVolume(audio_sources audio_source)
{
    volume_info volume;
    int16 master_volume_in_db;

    audioGetVolumeInfoFromSource(audio_source, &volume);
    
    /* Set current volume */
    master_volume_in_db = sinkVolumeGetVolInDb(volume.main_volume, audio_output_group_main);
    return (getSystemGainFromMaster(master_volume_in_db));
}

/*******************************************************************************/
bool useBroadcastPlugin( void )
{
    bool broadcast_plugin = FALSE;
    if((sinkBroadcastAudioGetMode() == sink_ba_appmode_broadcaster) && sinkBroadcastAudioIsActive() && !IS_MODE_CHANGE_IN_PROGRESS)
    {
        broadcast_plugin = TRUE;
    }
    return broadcast_plugin;
}

/*****************************************************************************/
uint16 SinkBroadcasAudioGetA2dpLatency( void )
{
    /* returns the a2dp delay for broadcast audio */
    return (BA_A2DP_LATENCY_MS * 10);
}

/*******************************************************************************/
void sinkBroadcastAudioStopIVAdvertsAndScan(void)
{
    /* Defer stoping of IV adverts/scanning until de-init of broadcast library is complete */
    if(isModeSwitchToNormal())
    {
        MessageId id = BROADCASTER_INTERNAL_MSG_STOP_BLE_BROADCAST;
        if(BA_RECEIVER_MODE_ACTIVE)
            id = RECEIVER_INTERNAL_MSG_STOP_BLE_BROADCAST;
        MessageSendConditionally(&BA_DATA.baAppTask, id, NULL, &BA_DATA.modeswitch_inprogress);
    }        
    else
    {
        /* so stop advertising/scanning the IV */
        sinkBleStopBroadcastEvent();
    }
}

void SinkBroadcastAudioHandlePluginUpStreamMessage(Task task, MessageId id, Message message)
{
    if(BA_RECEIVER_MODE_ACTIVE)
    {
        sinkReceiverUpStreamMsgHandler(task, id, message);
    }
    /* Broadcaster too will handle up stream messages in future */
}

static bool isSeidSupported(uint16 seid)
{
    /* SBC is always supported */
    if(seid == SBC_SEID)
    {
        return TRUE;
    }

    if(sinkBroadcastAudioGetOptionalCodecsMask() & sinkA2dpGetCodecBitMaskFromSeid(seid))
    {
        return TRUE;
    }

    return FALSE;
}

bool sinkBroadcastIsA2dpCodecSupported(uint16 a2dp_source_index)
{
    if(sink_ba_appmode_broadcaster == sinkBroadcastAudioGetMode())
    {
        if(!isSeidSupported(getA2dpLinkDataSeId(a2dp_source_index)))
        {
            return FALSE;
        }
    }
    return TRUE;
}

bool sinkBroadcastIsReadyForRouting(void)
{
    /* In the brodcaster mode presence of sink indicates that
       broadcaster is ready for streaming.
     */
    DEBUG_BA(("BA: sinkBroadcastIsReadyForRouting mode %d sink %p in_progress %d next_mode %d - ",
              sinkBroadcastAudioGetMode(), BroadcastContextGetSink(), IS_MODE_CHANGE_IN_PROGRESS, broadcastAudioGetRequestedMode()));
    if(BA_BROADCASTER_MODE_ACTIVE)
    {
        if(BroadcastContextGetSink() == NULL || IS_MODE_CHANGE_IN_PROGRESS)
        {
            DEBUG_BA(("FALSE\n"));
            return FALSE;
        }
    }
    else if (IS_MODE_CHANGE_IN_PROGRESS && BA_RECEIVER_MODE_ACTIVE
             && (sink_ba_appmode_broadcaster == broadcastAudioGetRequestedMode()))
    {
        /* If device is in the process of switching from receiver mode to
         * broadcaster mode we are not yet ready to route audio. */
        DEBUG_BA(("FALSE\n"));
        return FALSE;
    }
    DEBUG_BA(("TRUE\n"));
    return TRUE;
}

void baAudioPostRoutingAudioConfiguration(void)
{
    DEBUG_BA(("BA: baAudioPostRoutingAudioConfiguration\n"));

    if(!sinkAudioIsAudioRouted() && !sinkAudioIsVoiceRouted())
    {
        DEBUG_BA(("nothing is routed\n"));
        if (BA_RECEIVER_MODE_ACTIVE)
        {
            if (!sinkReceiverIsRoutable()
                && (deviceLimbo != stateManagerGetState()))
            {
                /* Unless the sink has powered off,
                   re-start the broadcast receiver. */
                DEBUG_BA(("start receiver\n"));
                sinkReceiverStartReceiver();
            }
        }
    }
    else if(sinkAudioIsAudioRouted())
    {
        DEBUG_BA(("some audio is routed\n"));
    }
    else if(sinkAudioIsVoiceRouted())
    {
        DEBUG_BA(("voice is routed\n"));
    }
}

void sinkBroadcastAcquireVolumeTable(void)
{
    ba_volume_readonly_config_def_t *ro_config = NULL;

    if(configManagerGetReadOnlyConfig(BA_VOLUME_READONLY_CONFIG_BLK_ID, (const void **)&ro_config))
    {
        BroadcastContextSetVolumeTable((int16 *)ro_config->ba_volume_array);
    }
}

void sinkBroadcastReleaseVolumeTable(void)
{
    BroadcastContextSetVolumeTable(NULL);
    configManagerReleaseConfig(BA_VOLUME_READONLY_CONFIG_BLK_ID);
}

bool sinkBroadcastAudioIsModeChangeInProgress(void)
{
    return IS_MODE_CHANGE_IN_PROGRESS;
}

void sinkBroadcastAudioSetEcScheme(erasure_coding_scheme_t ec_scheme)
{
    BA_DATA.requested_ec_scheme = ec_scheme;
}

erasure_coding_scheme_t sinkBroadcastAudioGetEcScheme(void)
{
    return BA_DATA.requested_ec_scheme;
}

#endif /* ENABLE_BROADCAST_AUDIO */

