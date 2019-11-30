/*
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
*/
/**
\file

\ingroup sink_app

\brief  This module pulls the referenced enum declarations into the ELF file.

*/
/** 
 \addtogroup sink_app 
 \{
*/
/****************************************************************************
    Header files
*/
#include "connection_no_ble.h"
#ifdef HYDRACORE
#include "macros.h"
#include "hfp.h"
#include "power.h"
#include "a2dp.h"
#include "a2dp.h"
#include "audio_plugin_if.h"
#include <app/message/system_message.h>
#include <audio.h>
#include "sink_display.h"

#ifdef ENABLE_ADK_NFC
#include "nfc/nfc_prim.h"
#include "nfc_cl.h"
#endif

#ifdef ENABLE_AVRCP
#include "sink_avrcp.h"
#endif

#ifdef ENABLE_GAIA
#include "gaia.h"
#endif

#ifdef ENABLE_PBAP
#include "sink_pbap.h"
#endif

#ifdef ENABLE_MAPC
#include "sink_mapc.h"
#endif

#include <display_plugin_if.h>

#ifdef ENABLE_SUBWOOFER
#include "sink_swat.h"
#endif

#ifdef ENABLE_FM
#include "sink_fm.h"
#endif

#ifdef ENABLE_USB
#include <usb_device_class.h>
#endif

#include <upgrade.h>

/**
 * The items in this enum are #defines from the system_message.h header file.
 * The ELF file does not list #defines, so this enum is defined with the same
 * identifiers but prefixed with "ENUM_" so that the debug_log.py script can
 * pick the values and the identifiers up and use them for the trap API log.
 *
 * There is a maintenence overhead overhead in keeping this definition in step
 * with the system_message.h header file, though the only consequence of not
 * keeping in step is that the id will not be decoded to the name in the log.
 */
typedef enum
{
    ENUM_MESSAGE_BLUESTACK_BASE_ = MESSAGE_BLUESTACK_BASE_,
    ENUM_MESSAGE_BLUESTACK_LC_PRIM = MESSAGE_BLUESTACK_LC_PRIM,
    ENUM_MESSAGE_BLUESTACK_LM_PRIM = MESSAGE_BLUESTACK_LM_PRIM,
    ENUM_MESSAGE_BLUESTACK_HCI_PRIM = MESSAGE_BLUESTACK_HCI_PRIM,
    ENUM_MESSAGE_BLUESTACK_DM_PRIM = MESSAGE_BLUESTACK_DM_PRIM,
    ENUM_MESSAGE_BLUESTACK_L2CAP_PRIM = MESSAGE_BLUESTACK_L2CAP_PRIM,
    ENUM_MESSAGE_BLUESTACK_RFCOMM_PRIM = MESSAGE_BLUESTACK_RFCOMM_PRIM,
    ENUM_MESSAGE_BLUESTACK_SDP_PRIM = MESSAGE_BLUESTACK_SDP_PRIM,
    ENUM_MESSAGE_BLUESTACK_BCSP_LM_PRIM = MESSAGE_BLUESTACK_BCSP_LM_PRIM,
    ENUM_MESSAGE_BLUESTACK_BCSP_HQ_PRIM = MESSAGE_BLUESTACK_BCSP_HQ_PRIM,
    ENUM_MESSAGE_BLUESTACK_BCSP_BCCMD_PRIM = MESSAGE_BLUESTACK_BCSP_BCCMD_PRIM,
    ENUM_MESSAGE_BLUESTACK_CALLBACK_PRIM = MESSAGE_BLUESTACK_CALLBACK_PRIM,
    ENUM_MESSAGE_BLUESTACK_TCS_PRIM = MESSAGE_BLUESTACK_TCS_PRIM,
    ENUM_MESSAGE_BLUESTACK_BNEP_PRIM = MESSAGE_BLUESTACK_BNEP_PRIM,
    ENUM_MESSAGE_BLUESTACK_TCP_PRIM = MESSAGE_BLUESTACK_TCP_PRIM,
    ENUM_MESSAGE_BLUESTACK_UDP_PRIM = MESSAGE_BLUESTACK_UDP_PRIM,
    ENUM_MESSAGE_BLUESTACK_FB_PRIM = MESSAGE_BLUESTACK_FB_PRIM,
    ENUM_MESSAGE_BLUESTACK_ATT_PRIM = MESSAGE_BLUESTACK_ATT_PRIM,
    ENUM_MESSAGE_BLUESTACK_END_ = MESSAGE_BLUESTACK_END_,
    ENUM_MESSAGE_FROM_HOST = MESSAGE_FROM_HOST,
    ENUM_MESSAGE_MORE_DATA = MESSAGE_MORE_DATA,
    ENUM_MESSAGE_MORE_SPACE = MESSAGE_MORE_SPACE,
    ENUM_MESSAGE_PIO_CHANGED = MESSAGE_PIO_CHANGED,
    ENUM_MESSAGE_FROM_KALIMBA = MESSAGE_FROM_KALIMBA,
    ENUM_MESSAGE_ADC_RESULT = MESSAGE_ADC_RESULT,
    ENUM_MESSAGE_STREAM_DISCONNECT = MESSAGE_STREAM_DISCONNECT,
    ENUM_MESSAGE_ENERGY_CHANGED = MESSAGE_ENERGY_CHANGED,
    ENUM_MESSAGE_STATUS_CHANGED = MESSAGE_STATUS_CHANGED,
    ENUM_MESSAGE_SOURCE_EMPTY = MESSAGE_SOURCE_EMPTY,
    ENUM_MESSAGE_FROM_KALIMBA_LONG = MESSAGE_FROM_KALIMBA_LONG,
    ENUM_MESSAGE_USB_ENUMERATED = MESSAGE_USB_ENUMERATED,
    ENUM_MESSAGE_USB_SUSPENDED = MESSAGE_USB_SUSPENDED,
    ENUM_MESSAGE_CHARGER_CHANGED = MESSAGE_CHARGER_CHANGED,
    ENUM_MESSAGE_PSFL_FAULT = MESSAGE_PSFL_FAULT,
    ENUM_MESSAGE_USB_DECONFIGURED = MESSAGE_USB_DECONFIGURED,
    ENUM_MESSAGE_USB_ALT_INTERFACE = MESSAGE_USB_ALT_INTERFACE,
    ENUM_MESSAGE_USB_ATTACHED = MESSAGE_USB_ATTACHED,
    ENUM_MESSAGE_USB_DETACHED = MESSAGE_USB_DETACHED,
    ENUM_MESSAGE_KALIMBA_WATCHDOG_EVENT = MESSAGE_KALIMBA_WATCHDOG_EVENT,
    ENUM_MESSAGE_TX_POWER_CHANGE_EVENT = MESSAGE_TX_POWER_CHANGE_EVENT,
    ENUM_MESSAGE_CAPACITIVE_SENSOR_CHANGED = MESSAGE_CAPACITIVE_SENSOR_CHANGED,
    ENUM_MESSAGE_STREAM_SET_DIGEST = MESSAGE_STREAM_SET_DIGEST,
    ENUM_MESSAGE_STREAM_PARTITION_VERIFY = MESSAGE_STREAM_PARTITION_VERIFY,
    ENUM_MESSAGE_STREAM_REFORMAT_VERIFY = MESSAGE_STREAM_REFORMAT_VERIFY,
    ENUM_MESSAGE_INFRARED_EVENT = MESSAGE_INFRARED_EVENT,
    ENUM_MESSAGE_DFU_SQIF_STATUS = MESSAGE_DFU_SQIF_STATUS,
    ENUM_MESSAGE_FROM_OPERATOR = MESSAGE_FROM_OPERATOR,
    ENUM_MESSAGE_EXE_FS_VALIDATION_STATUS = MESSAGE_EXE_FS_VALIDATION_STATUS,
    ENUM_MESSAGE_FROM_OPERATOR_FRAMEWORK = MESSAGE_FROM_OPERATOR_FRAMEWORK
} SYSTEM_MESSAGE_ENUM;

/*
 * The sinkEvents_t enum type from sink_events.h is already in the apps1 ELF
 * file and hence does not need to be included here.
 */
PRESERVE_TYPE_FOR_DEBUGGING(ConnectionMessageId)
PRESERVE_TYPE_FOR_DEBUGGING(HfpMessageId)
PRESERVE_TYPE_FOR_DEBUGGING(PowerMessageId)
PRESERVE_TYPE_FOR_DEBUGGING(A2dpMessageId)
PRESERVE_TYPE_FOR_DEBUGGING(audio_plugin_upstream_message_type_t)
PRESERVE_TYPE_FOR_DEBUGGING(audio_plugin_interface_message_type_t)
PRESERVE_TYPE_FOR_DEBUGGING(SYSTEM_MESSAGE_ENUM)

#ifdef ENABLE_AVRCP
PRESERVE_TYPE_FOR_DEBUGGING(SinkAvrcpMessageId)
PRESERVE_TYPE_FOR_DEBUGGING(AvrcpMessageId)
PRESERVE_TYPE_FOR_DEBUGGING(avrcp_ctrl_message)
#endif

#ifdef ENABLE_GAIA
PRESERVE_TYPE_FOR_DEBUGGING(GaiaMessageId)
#endif

#if defined(ENABLE_ADK_NFC)
PRESERVE_TYPE_FOR_DEBUGGING(NFC_VM_MSG_ID)
PRESERVE_TYPE_FOR_DEBUGGING(NFC_CL_MSG_ID)
#endif

#ifdef ENABLE_PBAP
PRESERVE_TYPE_FOR_DEBUGGING(PbapcMessageId)
PRESERVE_TYPE_FOR_DEBUGGING(PbapcAppMsgId)
#endif

#ifdef ENABLE_MAPC
PRESERVE_TYPE_FOR_DEBUGGING(MapcMessageId)
PRESERVE_TYPE_FOR_DEBUGGING(MapcAppMessageId)
#endif

#ifdef ENABLE_DISPLAY
PRESERVE_TYPE_FOR_DEBUGGING(display_plugin_upstream_message_type_t)
#endif

#ifdef ENABLE_SUBWOOFER
PRESERVE_TYPE_FOR_DEBUGGING(SwatMessageId)
#endif

#ifdef ENABLE_FM
PRESERVE_TYPE_FOR_DEBUGGING(fm_plugin_upstream_message_type_t)
#endif

#ifdef ENABLE_USB
PRESERVE_TYPE_FOR_DEBUGGING(usb_device_class_message)
#endif

#ifdef ENABLE_DISPLAY
PRESERVE_TYPE_FOR_DEBUGGING(display_plugin_upstream_message_type_t)
#endif

PRESERVE_TYPE_FOR_DEBUGGING(upgrade_application_message)
PRESERVE_TYPE_FOR_DEBUGGING(upgrade_transport_message)

/** TODO:
* There are currently anonymous enum types in:
* - connection_private.h for connectionBluestackHandler
* - hfp_private.h for hfpProfileHandler
* - avrcp_private.h for avrcpProfileHandler
* - a2dp_private.h for a2dpProfileHandler and avrcpInitHandler
* that have not been made available in the apps1 ELF file but which could be
* of use in the trap API logging in the debug_log.py script.
*/

#endif /* HYDRACORE */
/**  \} */ /* End sink_app group */
