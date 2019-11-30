/*******************************************************************************
Copyright (c) 2015 - 2018 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
*/
/**
\file
\ingroup sink_app
\brief
    Support for Ambient Noise Cancellation (ANC). 

    The ANC feature is included in
    an add-on installer and is only supported on CSR8675.
*/

#include "sink_anc.h"

#ifdef ENABLE_ANC

#include "sink_debug.h"
#include "sink_configmanager.h"
#include "sink_led_err.h"
#include "sink_leds.h"
#include "sink_peer.h"

#include "config_definition.h"
#include "sink_anc_config_def.h"
#include "sink_audio_routing.h"
#include "sink_main_task.h"
#include <audio.h>
#include <config_store.h>

#ifdef ENABLE_ANC_TUNING_MODE
#include "audio_anc_tuning.h"
#endif

#ifdef DEBUG_ANC
/* Ensure that we enable the development macros for a debug build */
#define DEVELOPMENT_BUILD
#endif /* DEBUG_ANC */

#include "sink_development.h"

#include <stdlib.h>

/* ANC specific debug/development macros */
#ifdef DEBUG_ANC

#define ANC_INFO(x) DEBUG(x)
#define ANC_ERROR(x) TOLERATED_ERROR(x)
#define ANC_ASSERT(x, y) {if (!(x)) FATAL_ERROR(y);}

#else /* DEBUG_ANC */

#define ANC_INFO(x)
#define ANC_ERROR(x)
#define ANC_ASSERT(x, y) {if (!(x)) FATAL_ERROR(y);}

#endif /* DEBUG_ANC */

/*Sink ANC Global Data */
typedef struct __sink_anc_globaldata_t
{
    unsigned gain:8;
    unsigned requested_active_mode:1;
    unsigned requested_enabled:1;
    unsigned actual_active_mode:1;
    unsigned actual_enabled:1;
    unsigned power_on:1;
    unsigned persist_anc_gain:1;
    unsigned persist_anc_mode:1;
    unsigned persist_anc_enabled:1;
    sink_anc_state state;
}sink_anc_globaldata_t;

static sink_anc_globaldata_t gAncData;

#define ANC gAncData
/* Sink ANC State Machine Events */
typedef enum
{
    sink_anc_state_event_initialise,
    sink_anc_state_event_power_on,
    sink_anc_state_event_power_off,
    sink_anc_state_event_enable,
    sink_anc_state_event_disable,
    sink_anc_state_event_volume_up,
    sink_anc_state_event_volume_down,
    sink_anc_state_event_set_active_mode,
    sink_anc_state_event_set_leakthrough_mode,
    sink_anc_state_event_audio_disconnected,
    sink_anc_state_event_cycle_gain,
    sink_anc_state_event_activate_tuning_mode
} sink_anc_state_event_id;

/* ANC Message handler task, only used for ANC Internal messages */
static void sinkAncHandleMessage (Task task, MessageId id, Message message);
static struct TaskData anc_task = { sinkAncHandleMessage };

#ifdef ENABLE_ANC_TUNING_MODE
static audio_instance_t tuning_instance;
#endif

/* ANC Internal Messages */
typedef enum
{
    ANC_AUDIO_DISCONNECTED_EVENT
} sink_anc_message_id;

static bool readAncMicConfigParams(anc_mic_params_t *anc_mic_params);
static void sinkAncChangeState(sink_anc_state new_state);

/******************************************************************************
NAME
    enterTuningMode

DESCRIPTION
    Connects up the tuning mode plugin via the audio library.
*/
static bool enterTuningMode(void)
{
#ifdef ENABLE_ANC_TUNING_MODE
    AudioPluginFeatures features;

    memset(&features, 0, sizeof(features));

    audioDisconnectRoutedAudio();
    audioDisconnectRoutedVoice();

    if(AncIsEnabled())
    {
        AncEnable(FALSE);
    }

    tuning_instance = AudioConnect((Task)AncGetTuningModePlugin(),
            (Sink)NULL,
            (AUDIO_SINK_T)NULL,
            0,
            0,
            features,
            (AUDIO_MODE_T)0,
            (AUDIO_ROUTE_T)0,
            (AUDIO_POWER_T)0,
            (void *)AncGetAncMicParams(),
            (Task)NULL );

    sinkAncChangeState(sink_anc_state_tuning_mode_active);

    return TRUE;
#else
    Panic();
    return FALSE;
#endif
}

static bool exitTuningMode(void)
{
#ifdef ENABLE_ANC_TUNING_MODE
    AudioDisconnectInstance(tuning_instance);

    sinkAncChangeState(sink_anc_state_power_off);
    return TRUE;
#else
    Panic();
    return FALSE;
#endif
}

/******************************************************************************
NAME
    sinkAncCheckForAudioRouting

DESCRIPTION
    This function checks if ANC is in a state where the audio could be routed.
    The called audioUpdateAudioRouting function will actually
    determine which audio is prioritised, but may fall back to just ANC if
    no other audio sources are active.
*/
static void sinkAncCheckForAudioRouting(void)
{
    if ((ANC.power_on) && (ANC.state != sink_anc_state_disconnecting_audio))
    {
        /* Test for ANC audio routing when enabled */
        audioUpdateAudioRouting();
    }
}


/******************************************************************************
NAME
    sinkAncSetSessionData

DESCRIPTION
    This function is responsible for persisting any of the ANC session data
    that is required.
*/
static void sinkAncSetSessionData(void)
{
    sink_anc_writeable_config_def_t *write_data = NULL;

    if(configManagerGetWriteableConfig(SINK_ANC_WRITEABLE_CONFIG_BLK_ID, (void **)&write_data, 0))
    {
        if (ANC.persist_anc_enabled)
        {
            ANC_INFO(("Persisting ANC enabled state %d\n", ANC.requested_enabled));
            write_data->initial_anc_state =  ANC.requested_enabled;
        }
    
        if (ANC.persist_anc_mode)
        {
            ANC_INFO(("Persisting ANC mode %d\n", ANC.requested_active_mode));
            write_data->initial_anc_mode = ANC.requested_active_mode;
        }
    
        if (ANC.persist_anc_gain)
        {
            ANC_INFO(("Persisting ANC gain %d\n", ANC.gain));
            write_data->initial_anc_gain = ANC.gain;
        }
    
        configManagerUpdateWriteableConfig(SINK_ANC_WRITEABLE_CONFIG_BLK_ID);
    }
}


/******************************************************************************
NAME
    sinkAncChangeState

DESCRIPTION
    Handle the transition into a new state. This function is responsible for
    generating the state related system events.
*/
static void sinkAncChangeState(sink_anc_state new_state)
{
    ANC_INFO(("Sink ANC State %d -> %d\n", ANC.state, new_state));

    if (new_state == sink_anc_state_disconnecting_audio)
    {
        /* When transitioning into the disconnecting audio state ensure we are
           notified when the disconnection has been completed */
        MessageSendConditionallyOnTask(&anc_task, ANC_AUDIO_DISCONNECTED_EVENT, 0, AudioBusyPtr());
    }
    else if ((new_state == sink_anc_state_power_off) && (ANC.state != sink_anc_state_uninitialised))
    {
        /* When we power off from an on state persist any state required */
        sinkAncSetSessionData();
    }
    else if (new_state == sink_anc_state_disabled)
    {
        /* Notify that ANC is disabled */
        MessageSend(&theSink.task, EventSysAncDisabled, 0);
    }
    else if (new_state == sink_anc_state_enabled)
    {
        /* Notify that ANC is enabled and the mode is it working in */
        sinkEvents_t sys_event = (ANC.actual_active_mode) ? EventSysAncActiveModeEnabled :
                                                            EventSysAncLeakthroughModeEnabled;
        MessageSend(&theSink.task, sys_event, 0);
    }

    /* Update state */
    ANC.state = new_state;
}


/******************************************************************************
NAME
    sinkAncUpdateSidetoneGain

DESCRIPTION
    This function can be used to increment or decrement the current ANC gain. It
    is responsible for bounds checking the gain value and raising the appropriate
    gain related system events as required.

RETURNS
    Bool indicating if updating the gain was successful or not.
*/
static bool sinkAncUpdateSidetoneGain(bool increment)
{
    bool updated = FALSE;

    if (ANC.gain == ANC_SIDETONE_GAIN_MIN)
    {
        /* At minimum gain already, raise system event */
        MessageSend(&theSink.task, EventSysAncMinGain, 0);
        updated = TRUE;
    }
    else if (ANC.gain >= ANC_SIDETONE_GAIN_MAX)
    {
        /* At maximum gain already, raise system event */
        MessageSend(&theSink.task, EventSysAncMaxGain, 0);
        updated = TRUE;
    }
    else
    {
        uint16 new_gain = (increment) ? ANC.gain + 1 : ANC.gain - 1;
        if (AncSetSidetoneGain(new_gain))
        {
            /* Update local copy of gain */
            ANC.gain = new_gain;
            updated = TRUE;
        }
    }
    return updated;
}


/******************************************************************************
NAME
    updateAncLibState

DESCRIPTION
    Update the state of the ANC VM library. This is the 'actual' state, as opposed
    to the 'requested' state and therefore the 'actual' state variables should
    only ever be updated in this function.

RETURNS
    FALSE   if the state was updated.
    TRUE    if audio blocked the state update. If TRUE is returned then this 
            function will also initiate audio disconnection.
*/  
static bool updateAncLibState(bool enable, bool active_mode)
{
    bool retry_later = FALSE;

    /* Check to see if we are either changing mode or turning on/off */
    if ((ANC.actual_active_mode != active_mode) || (ANC.actual_enabled != enable))
    {
        if (AncIsAudioDisconnectRequiredOnStateChange() && (sinkAudioIsAudioRouted() || sinkAudioIsVoiceRouted()))
        {
            /* If we are changing ANC state then we must first disconnect any audio
               that is currently being routed */
            audioDisconnectRoutedAudio();
            audioDisconnectRoutedVoice();

            /* Return TRUE to indicate we have to wait for the audio to be disconnected
               before we can update the ANC state. */
            retry_later = TRUE;
        }
        else
        {
            if (ANC.actual_active_mode != active_mode)
            {
                /* Set ANC Mode */
                if (!AncSetMode((active_mode) ? anc_mode_active : anc_mode_leakthrough))
                {
                    /* If this does fail in a release build then we will continue
                       and updating the ANC state will be tried again next time
                       an event causes a state change. */
                    ANC_ERROR(("Sink ANC Set Mode failed %d\n", active_mode));
                }

                /* Update mode state */
                ANC_INFO(("Sink ANC Set Active Mode %d\n", active_mode));
                ANC.actual_active_mode = active_mode;
            }
            /* Determine state to update in VM lib */
            if (ANC.actual_enabled != enable)
            {
                if (!AncEnable(enable))
                {
                    /* If this does fail in a release build then we will continue
                       and updating the ANC state will be tried again next time
                       an event causes a state change. */
                    ANC_ERROR(("Sink ANC Enable failed %d\n", enable));
                }

                /* Update enabled state */
                ANC_INFO(("Sink ANC Enable %d\n", enable));
                ANC.actual_enabled = enable;
            }
        }
    }
    return retry_later;
}
/******************************************************************************
NAME
    sinkAncGetSessionData

DESCRIPTION
    Update session data retrieved from config

RETURNS
    Bool indicating if updating config was successful or not.
*/
static bool sinkAncGetSessionData(void)
{
    sink_anc_writeable_config_def_t *write_data = NULL;

    configManagerGetReadOnlyConfig(SINK_ANC_WRITEABLE_CONFIG_BLK_ID, (const void **)&write_data);

    /* Extract session data */
    ANC.requested_enabled = write_data->initial_anc_state;
    ANC.persist_anc_enabled = write_data->persist_initial_state;
    ANC.requested_active_mode = write_data->initial_anc_mode;
    ANC.persist_anc_mode = write_data->persist_initial_mode;
    ANC.gain = write_data->initial_anc_gain;
    ANC.persist_anc_gain = write_data->persist_anc_gain;
    
    configManagerReleaseConfig(SINK_ANC_WRITEABLE_CONFIG_BLK_ID);

    /* Bounds check session data */
    if ((ANC.gain < ANC_SIDETONE_GAIN_MIN) || (ANC.gain > ANC_SIDETONE_GAIN_MAX))
    {
        /* ANC Sidetone Gain out of bounds */
        ANC_ERROR(("ANC Sidetone Gain out of bounds\n"));
        return TRUE;
    }

    return TRUE;
}

/******************************************************************************
NAME
    getMicParams

DESCRIPTION
    Get microphone parameters
*/
static audio_mic_params getMicParams(mic_selection mic)
{
	audio_mic_params mic_params = sinkAudioGetMic1aParams();

    switch(mic)
    {
        case microphone_1a:
            mic_params = sinkAudioGetMic1aParams();
            break;
        case microphone_1b:
            mic_params = sinkAudioGetMic1bParams();
            break;
        case microphone_2a:
            mic_params = sinkAudioGetMic2aParams();
            break;
        case microphone_2b:
            mic_params = sinkAudioGetMic2bParams();
            break;
        case microphone_3a:
            mic_params = sinkAudioGetMic3aParams();
            break;
        case microphone_3b:
            mic_params = sinkAudioGetMic3bParams();
            break;
        default:
            break;
    }

    return mic_params;
}


/******************************************************************************
NAME
    readAncMicConfigParams

DESCRIPTION
    Read the configuration from the ANC Mic params.
*/
static bool readAncMicConfigParams(anc_mic_params_t *anc_mic_params)
{
    sink_anc_readonly_config_def_t *read_data = NULL;

    if (configManagerGetReadOnlyConfig(SINK_ANC_READONLY_CONFIG_BLK_ID, (const void **)&read_data))
    {
        mic_selection feedForwardLeftMic = read_data->anc_mic_params_r_config.feed_forward_left_mic;
        mic_selection feedForwardRightMic = read_data->anc_mic_params_r_config.feed_forward_right_mic;
        mic_selection feedBackLeftMic = read_data->anc_mic_params_r_config.feed_back_left_mic;
        mic_selection feedBackRightMic = read_data->anc_mic_params_r_config.feed_back_right_mic;

        memset(anc_mic_params, 0, sizeof(anc_mic_params_t));

        anc_mic_params->mic_gain_step_size = read_data->anc_mic_params_r_config.mic_gain_step_size;

        if (feedForwardLeftMic)
        {
            anc_mic_params->enabled_mics |= feed_forward_left;
            anc_mic_params->feed_forward_left = getMicParams(feedForwardLeftMic);
        }

        if (feedForwardRightMic)
        {
            anc_mic_params->enabled_mics |= feed_forward_right;
            anc_mic_params->feed_forward_right = getMicParams(feedForwardRightMic);
        }

        if (feedBackLeftMic)
        {
            anc_mic_params->enabled_mics |= feed_back_left;
            anc_mic_params->feed_back_left = getMicParams(feedBackLeftMic);
        }

        if (feedBackRightMic)
        {
            anc_mic_params->enabled_mics |= feed_back_right;
            anc_mic_params->feed_back_right = getMicParams(feedBackRightMic);
        }

        configManagerReleaseConfig(SINK_ANC_READONLY_CONFIG_BLK_ID);

        return TRUE;
    }
    ANC_ERROR(("Failed to read ANC Config Block\n"));
    return FALSE;
}

static anc_mode getAncModeFromSessionData(void)
{
    return ((ANC.requested_active_mode) ? anc_mode_active : anc_mode_leakthrough);
}

/******************************************************************************
NAME
    sinkConfigureAndInitAnc
DESCRIPTION
    This function reads the ANC configuration and initialises the ANC library
    returns TRUE on success FALSE otherwise 
*/ 
static bool sinkConfigureAndInitAnc(void)
{
    anc_mic_params_t anc_mic_params;
    bool init_success = FALSE;

    if(readAncMicConfigParams(&anc_mic_params) && sinkAncGetSessionData())
    {
        if(AncInit(&anc_mic_params, getAncModeFromSessionData(), ANC.gain))
        {
            /* Update local state to indicate successful initialisation of ANC */
            ANC.actual_active_mode = ANC.requested_active_mode;
            ANC.actual_enabled = FALSE;
            sinkAncChangeState(sink_anc_state_power_off);
            init_success = TRUE;
        }
    }

    return init_success;
}

/******************************************************************************
NAME
    sinkAncStateUninitialisedHandleEvent

DESCRIPTION
    Event handler for the Uninitialised State

RETURNS
    Bool indicating if processing event was successful or not.
*/ 
static bool sinkAncStateUninitialisedHandleEvent(sink_anc_state_event_id event)
{
    bool init_success = FALSE;

    switch (event)
    {
        case sink_anc_state_event_initialise:
        {
            if(sinkConfigureAndInitAnc())
            {
                init_success = TRUE;
            }
            else
            {
                ANC_INFO(("ANC Failed to Initialise\n"));
                LedsIndicateError(led_err_id_enum_anc);
            }
        }
        break;

        default:
        {
            ANC_ERROR(("Unhandled event [%d]\n", event));
        }
        break;
    }
    return init_success;
}


/******************************************************************************
NAME
    sinkAncStatePowerOffHandleEvent

DESCRIPTION
    Event handler for the Power Off State

RETURNS
    Bool indicating if processing event was successful or not.
*/ 
static bool sinkAncStatePowerOffHandleEvent(sink_anc_state_event_id event)
{
    bool event_handled = FALSE;

    ANC_ASSERT(!ANC.actual_enabled, ("ANC actual enabled in power off state\n"));

    switch (event)
    {
        case sink_anc_state_event_power_on:
        {
            sink_anc_state next_state = sink_anc_state_disabled;
            ANC.power_on = TRUE;

            /* If we were previously enabled then enable on power on */
            if (ANC.requested_enabled)
            {
                if (updateAncLibState(ANC.requested_enabled, ANC.requested_active_mode))
                {
                    /* Audio being disconnected... */
                    next_state = sink_anc_state_disconnecting_audio;
                }
                else
                {
                    /* Lib is enabled */
                    next_state = sink_anc_state_enabled;
                }
            }
            /* Update state */
            sinkAncChangeState(next_state);
            /* Check if ANC audio should be routed */
            sinkAncCheckForAudioRouting();
            event_handled = TRUE;
        }
        break;

        default:
        {
            ANC_ERROR(("Unhandled event [%d]\n", event));
        }
        break;
    }
    return event_handled;
}


/******************************************************************************
NAME
    sinkAncStateEnabledHandleEvent

DESCRIPTION
    Event handler for the Enabled State

RETURNS
    Bool indicating if processing event was successful or not.
*/
static bool sinkAncStateEnabledHandleEvent(sink_anc_state_event_id event)
{
    /* Assume failure until proven otherwise */
    bool event_handled = FALSE;
    sink_anc_state next_state = sink_anc_state_disabled;

    ANC_ASSERT(ANC.actual_enabled, ("ANC actual not enabled in Enabled state\n"));
    ANC_ASSERT(ANC.requested_enabled, ("ANC requested not enabled in Enabled state\n"));

    ANC_ASSERT(ANC.actual_active_mode == ANC.requested_active_mode,
               ("ANC actual and requested mode out of sync in Enabled state\n"));

    switch (event)
    {
        case sink_anc_state_event_power_off:
        {
            /* When powering off we need to disable ANC in the VM Lib first */
            next_state = sink_anc_state_power_off;
            ANC.power_on = FALSE;
        }
        /* fallthrough */
        case sink_anc_state_event_disable:
        {
            /* Only update requested enabled if not due to a power off event */
            ANC.requested_enabled = (next_state == sink_anc_state_power_off);

            /* Disable ANC */
            if (updateAncLibState(FALSE, ANC.requested_active_mode))
            {
                /* Audio being disconnected... */
                next_state = sink_anc_state_disconnecting_audio;
            }
            /* Update state */
            sinkAncChangeState(next_state);
            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_set_active_mode: /* fallthrough */
        case sink_anc_state_event_set_leakthrough_mode:
        {
            ANC.requested_active_mode = (event == sink_anc_state_event_set_active_mode);

            /* Update the ANC Mode */
            if (updateAncLibState(ANC.requested_enabled, ANC.requested_active_mode))
            {
                /* Audio being disconnected... */
                sinkAncChangeState(sink_anc_state_disconnecting_audio);
            }
            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_volume_up: /* fallthrough */
        case sink_anc_state_event_volume_down:
        {
            /* Update the ANC Gain */
            event_handled = sinkAncUpdateSidetoneGain(event == sink_anc_state_event_volume_up);
        }
        break;

        case sink_anc_state_event_cycle_gain:
        {
            event_handled = AncCycleFineTuneGain();
        }
        break;

        case sink_anc_state_event_activate_tuning_mode:
        {
            event_handled = enterTuningMode();
        }
        break;
            
        default:
        {
            ANC_ERROR(("Unhandled event [%d]\n", event));
        }
        break;
    }
    return event_handled;
}


/******************************************************************************
NAME
    sinkAncStateDisabledHandleEvent

DESCRIPTION
    Event handler for the Disabled State

RETURNS
    Bool indicating if processing event was successful or not.
*/
static bool sinkAncStateDisabledHandleEvent(sink_anc_state_event_id event)
{
    /* Assume failure until proven otherwise */
    bool event_handled = FALSE;

    ANC_ASSERT(!ANC.actual_enabled, ("ANC actual enabled in Disabled state\n"));
    ANC_ASSERT(!ANC.requested_enabled, ("ANC requested enabled in Disabled state\n"));

    switch (event)
    {
        case sink_anc_state_event_power_off:
        {
            /* Nothing to do, just update state */
            sinkAncChangeState(sink_anc_state_power_off);
            ANC.power_on = FALSE;
            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_enable:
        {
            /* Try to enable */
            sink_anc_state next_state = sink_anc_state_enabled;
            ANC.requested_enabled = TRUE;

            /* Enable ANC */
            if (updateAncLibState(ANC.requested_enabled, ANC.requested_active_mode))
            {
                /* Audio being disconnected... */
                next_state = sink_anc_state_disconnecting_audio;
            }
            /* Update state */
            sinkAncChangeState(next_state);
            /* Check if ANC audio should be routed */
            sinkAncCheckForAudioRouting();
           
            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_set_active_mode: /* fallthrough */
        case sink_anc_state_event_set_leakthrough_mode:
        {
            /* Update the requested ANC Mode, will get applied next time we enable */
            ANC.requested_active_mode = (event == sink_anc_state_event_set_active_mode);
            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_volume_up: /* fallthrough */
        case sink_anc_state_event_volume_down:
        {
            /* Update the ANC Gain */
            event_handled = sinkAncUpdateSidetoneGain(event == sink_anc_state_event_volume_up);
        }
        break;
        
        case sink_anc_state_event_activate_tuning_mode:
        {
            event_handled = enterTuningMode();
        }
        break;

        default:
        {
            ANC_ERROR(("Unhandled event [%d]\n", event));
        }
        break;
    }
    return event_handled;
}


/******************************************************************************
NAME
    sinkAncStateDisconnectingAudioHandleEvent

DESCRIPTION
    Event handler for the Disconnecting Audio State

RETURNS
    Bool indicating if processing event was successful or not.
*/
static bool sinkAncStateDisconnectingAudioHandleEvent(sink_anc_state_event_id event)
{
    bool event_handled = FALSE;

    switch (event)
    {
        case sink_anc_state_event_power_on:
        case sink_anc_state_event_power_off:
        {
            /* Just update our local state, appropriate action will be taken when
               Audio has been disconnected */
            ANC.power_on = (event == sink_anc_state_event_power_on);
            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_audio_disconnected:
        {
            /* Audio disconnected, update to the correct state */
            bool enable = ANC.requested_enabled;
            sink_anc_state next_state = (enable) ? sink_anc_state_enabled : 
                                                   sink_anc_state_disabled;
          
            if (!ANC.power_on)
            {
                /* Power Off overrides the value of requested_enabled */
                enable = FALSE;
                next_state = sink_anc_state_power_off;
            }

            if (updateAncLibState(enable, ANC.requested_active_mode))
            {
                /* It is possible that audio has been reconnected before we
                   recieved the disconnect message, try again... */
                next_state = sink_anc_state_disconnecting_audio;
            }
            /* Update state */
            sinkAncChangeState(next_state);
            /* Check if ANC audio should be routed */
            sinkAncCheckForAudioRouting();

            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_enable: /* fallthrough */
        case sink_anc_state_event_disable:
        {
            /* Update the requested ANC enabled, actual ANC enabled will be updated once applied */
            ANC.requested_enabled = (event == sink_anc_state_event_enable);
            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_set_active_mode: /* fallthrough */
        case sink_anc_state_event_set_leakthrough_mode:
        {
            /* Update the lib ANC Mode, app ANC mode will be updated once applied */
            ANC.requested_active_mode = (event == sink_anc_state_event_set_active_mode);
            event_handled = TRUE;
        }
        break;

        case sink_anc_state_event_volume_up: /* fallthrough */
        case sink_anc_state_event_volume_down:
        {
            /* Update the ANC Gain */
            event_handled = sinkAncUpdateSidetoneGain(event == sink_anc_state_event_volume_up);
        }
        break;
        
        case sink_anc_state_event_activate_tuning_mode:
        {
            event_handled = TRUE;
        }
        break;

        default:
        {
            ANC_ERROR(("Unhandled event [%d]\n", event));
        }
        break;
    }
    return event_handled;
}

static bool sinkAncStateTuningModeActiveHandleEvent(sink_anc_state_event_id event)
{
    bool event_handled = FALSE;
    switch(event)
    {
        case sink_anc_state_event_power_off:
            event_handled = exitTuningMode();
            break;
        default:
            break;
    }
    return event_handled;
}


/******************************************************************************
NAME
    sinkAncStateMachineHandleEvent

DESCRIPTION
    Entry point to the Sink ANC State Machine.

RETURNS
    Bool indicating if processing event was successful or not.
*/
static bool sinkAncStateMachineHandleEvent(sink_anc_state_event_id event)
{
    bool ret_val = FALSE;

    ANC_INFO(("Sink ANC Handle Event %d in State %d\n", event, ANC.state));

    switch(ANC.state)
    {
        case sink_anc_state_uninitialised:
            ret_val = sinkAncStateUninitialisedHandleEvent(event);
        break;
        
        case sink_anc_state_power_off:
            ret_val = sinkAncStatePowerOffHandleEvent(event);
        break;

        case sink_anc_state_enabled:
            ret_val = sinkAncStateEnabledHandleEvent(event);
        break;

        case sink_anc_state_disabled:
            ret_val = sinkAncStateDisabledHandleEvent(event);
        break;

        case sink_anc_state_disconnecting_audio:
            ret_val = sinkAncStateDisconnectingAudioHandleEvent(event);
        break;

        case sink_anc_state_tuning_mode_active:
            ret_val = sinkAncStateTuningModeActiveHandleEvent(event);
            break;

        default:
            ANC_ERROR(("Unhandled state [%d]\n", ANC.state));
        break;
    }
    return ret_val;
}


/******************************************************************************
NAME
    sinkAncHandleMessage

DESCRIPTION
    Message handler for Sink ANC.
*/
static void sinkAncHandleMessage (Task task, MessageId id, Message message)
{
    UNUSED(task);
    UNUSED(message);
    if (id == ANC_AUDIO_DISCONNECTED_EVENT)
    {
        if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_audio_disconnected))
        {
            ANC_ERROR(("Processing Audio Disconnected ANC event failed\n"));
        }        
    }
    else
    {
        /* Unknown message */
        ANC_ERROR(("Unknown ANC Message\n"));
    }
}

/*******************************************************************************
 * All the functions from this point onwards are the Sink ANC module API functions
 * as described in sink_anc.h. The functions are simply responsible for injecting
 * the correct event into the Sink ANC State Machine, which is then responsible
 * for taking the appropriate action.
 ******************************************************************************/

/******************************************************************************/
void sinkAncInit(void)
{
    /* Initialise the ANC VM Lib */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_initialise))
    {
        ANC_ERROR(("Initialisation failure of ANC VM lib\n"));
    }
}


/******************************************************************************/
void sinkAncHandlePowerOn(void)
{
    /* Power On ANC */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_power_on))
    {
        ANC_ERROR(("Power On ANC failed\n"));
    }
}


/******************************************************************************/
void sinkAncHandlePowerOff(void)
{
    /* Power Off ANC */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_power_off))
    {
        ANC_ERROR(("Power Off ANC failed\n"));
    }
}


/******************************************************************************/
void sinkAncEnable(void)
{
    /* Enable ANC */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_enable))
    {
        ANC_ERROR(("Enable ANC failed\n"));
    }
}


/******************************************************************************/
void sinkAncDisable(void)
{
    /* Disable ANC */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_disable))
    {
        ANC_ERROR(("Disable ANC failed\n"));
    }
}


/******************************************************************************/
void sinkAncSetLeakthroughMode(void)
{
    /* Set ANC Leakthrough mode */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_set_leakthrough_mode))
    {
        ANC_ERROR(("Set ANC Leakthrough Mode failed\n"));
    }
}


/******************************************************************************/
void sinkAncSetActiveMode(void)
{
    /* Set ANC Active mode */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_set_active_mode))
    {
        ANC_ERROR(("Set ANC Active Mode failed\n"));
    }
}

/******************************************************************************/
void sinkAncVolumeDown(void)
{
    /* Decrease ANC volume */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_volume_down))
    {
        ANC_ERROR(("Decrease ANC volume failed\n"));
    }
}

/******************************************************************************/
void sinkAncVolumeUp(void)
{
    /* Increase ANC volume */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_volume_up))
    {
        ANC_ERROR(("Increase ANC volume failed\n"));
    }
}

/******************************************************************************/
void sinkAncCycleAdcDigitalGain(void)
{
    /* Cycle through the ADC digital gains */
    if (!sinkAncStateMachineHandleEvent(sink_anc_state_event_cycle_gain))
    {
        ANC_ERROR(("Cycle digital Gain failed\n"));
    }
}

static void sinkAncEnterTuningEvent(void)
{
    if(!sinkAncStateMachineHandleEvent(sink_anc_state_event_activate_tuning_mode))
    {
        ANC_ERROR(("Tuning mode event failed\n"));
    }
}

/******************************************************************************/
bool sinkAncIsEnabled(void)
{
    return ANC.requested_enabled;
}

/******************************************************************************/
bool sinkAncIsModeActive(void)
{
    return ANC.requested_active_mode;
}

/******************************************************************************/
bool sinkAncProcessEvent(const MessageId anc_event)
{
    bool indicate_event = TRUE;

    if(peerProcessEvent(anc_event))
    {
        indicate_event = FALSE;
        ANC_INFO(("Event handled by peer"));
    }
    else
    {
        switch(anc_event)
        {
            case EventUsrAncOn:
            case EventSysPeerGeneratedAncOn:
                sinkAncEnable();
                break;

            case EventUsrAncOff:
            case EventSysPeerGeneratedAncOff:
                sinkAncDisable();
                break;

            case EventUsrAncLeakthroughMode:
            case EventSysPeerGeneratedAncLeakthroughMode:
                sinkAncSetLeakthroughMode();
                break;

            case EventUsrAncActiveMode:
            case EventSysPeerGeneratedAncActiveMode:
                sinkAncSetActiveMode();
                break;

            case EventUsrAncNextMode:
                if (sinkAncIsModeActive())
                {
                    sinkAncSetLeakthroughMode();
                }
                else
                {
                    sinkAncSetActiveMode();
                }
                break;

            case EventUsrAncVolumeDown:
                sinkAncVolumeDown();
                break;

            case EventUsrAncVolumeUp:
                sinkAncVolumeUp();
                break;

            case EventUsrAncCycleGain:
                sinkAncCycleAdcDigitalGain();
                break;

            case EventUsrAncToggleOnOff:
                if (sinkAncIsEnabled())
                {
                    sinkAncDisable();
                }
                else
                {
                    sinkAncEnable();
                }
                break;

            case EventSysAncDisabled:
                ANC_INFO(( "ANC Disabled\n" ));
                break;

            case EventSysAncActiveModeEnabled:
                ANC_INFO(( "ANC Enabled in Active Mode\n" ));
                break;

            case EventSysAncLeakthroughModeEnabled:
                ANC_INFO(( "ANC Enabled in Leakthrough Mode\n" ));
                break;

            case EventUsrEnterAncTuningMode:
                sinkAncEnterTuningEvent();
                break;
        }
    }

    return indicate_event;
}

/******************************************************************************/
void sinkAncSychroniseStateWithPeer (void)
{
    if (peerIsLinkMaster())
    {
        peerSendAncState();
        peerSendAncMode();
    }
}

/******************************************************************************/
MessageId sinkAncGetNextState(void)
{
    MessageId id;

    if (sinkAncIsEnabled())
    {
        id = EventUsrAncOff;
    }
    else
    {
        id = EventUsrAncOn;
    }

    return id;
}

/******************************************************************************/
MessageId sinkAncGetNextMode(void)
{
    MessageId id;

    if (sinkAncIsModeActive())
    {
        id = EventUsrAncLeakthroughMode;
    }
    else
    {
        id = EventUsrAncActiveMode;
    }

    return id;
}

/******************************************************************************/
bool sinkAncIsTuningModeActive(void)
{
    return (ANC.state == sink_anc_state_tuning_mode_active);
}

#ifdef ANC_TEST_BUILD
/******************************************************************************/
void sinkAncResetStateMachine(sink_anc_state anc_state)
{
    ANC.state = anc_state;
}

#endif /* ANC_TEST_BUILD */

#endif /* ENABLE_ANC */
