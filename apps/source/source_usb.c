/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_usb.c

DESCRIPTION
    USB functionality.
    
*/


/* header for this file */
#include "source_usb.h"
/* application header files */
#include "source_app_msg_handler.h"
#include "source_debug.h"
#include "source_memory.h"
#include "source_private.h"
#include "source_volume.h"
#include "source_usb_config_def.h" 
#include "Source_configmanager.h" 
#include "source_aghfp.h"
#include "source_connection_mgr.h"
/* profile/library headers */
#include <usb_device_class.h>
#include "ahi_host_usb.h"
#include "source_ahi.h"
/* VM headers */
#include <boot.h>
#include <panic.h>
#include <stdlib.h>
#include <stream.h>
#include <string.h>


#ifdef DEBUG_USB
    #define USB_DEBUG(x) DEBUG(x)
#else
    #define USB_DEBUG(x)
#endif  

/* AHI uses the DATA_TRANSFER report and nothing else. */
#define HID_REPORTID_DATA_TRANSFER (1)

/* USB data structure */
typedef struct
{
    USB_HID_MODE_T hid_mode;
    unsigned ffwd_press:1;
    unsigned rew_press:1;
    unsigned unused:14;
} USB_DATA_T;


/* USB HID class descriptor - Consumer Transport Control Device*/
static const uint8 usb_interface_descriptor_hid_consumer_transport[] =
{
    USB_HID_DESCRIPTOR_LENGTH,                              /* bLength */
    USB_B_DESCRIPTOR_TYPE_HID,                              /* bDescriptorType */
    0x11, 0x01,                                             /* bcdHID */
    0,                                                      /* bCountryCode */
    1,                                                      /* bNumDescriptors */
    USB_B_DESCRIPTOR_TYPE_HID_REPORT,                       /* bDescriptorType */
    USB_HID_CONSUMER_TRANSPORT_REPORT_DESCRIPTOR_LENGTH,    /* wDescriptorLength */
    0                                                       /* wDescriptorLength */
};

/* HID Report Descriptor - Consumer Transport Control Device */
static const uint8 usb_report_descriptor_hid_consumer_transport[USB_HID_CONSUMER_TRANSPORT_REPORT_DESCRIPTOR_LENGTH] = 
{
    0x05, 0x0C,                  /* USAGE_PAGE (Consumer Devices) */
    0x09, 0x01,                  /* USAGE (Consumer Control) */
    0xa1, 0x01,                  /* COLLECTION (Application) */    
    0x85, 0x01,                  /*   REPORT_ID (1) */    
    0x15, 0x00,                  /*   LOGICAL_MINIMUM (0) */
    0x25, 0x01,                  /*   LOGICAL_MAXIMUM (1) */
    0x09, 0xcd,                  /*   USAGE (Play/Pause) */
    0x09, 0xb5,                  /*   USAGE (Scan Next Track) */
    0x09, 0xb6,                  /*   USAGE (Scan Previous Track) */
    0x09, 0xb7,                  /*   USAGE (Stop) */
    0x75, 0x01,                  /*   REPORT_SIZE (1) */
    0x95, 0x04,                  /*   REPORT_COUNT (4) */
    0x81, 0x02,                  /*   INPUT (Data,Var,Abs,Bit Field) */    
    0x15, 0x00,                  /*   LOGICAL_MINIMUM (0) */
    0x25, 0x01,                  /*   LOGICAL_MAXIMUM (1) */
    0x09, 0xb0,                  /*   USAGE (Play) */
    0x09, 0xb1,                  /*   USAGE (Pause) */
    0x09, 0xb3,                  /*   USAGE (Fast Forward) */
    0x09, 0xb4,                  /*   USAGE (Rewind) */
    0x75, 0x01,                  /*   REPORT_SIZE (1) */
    0x95, 0x04,                  /*   REPORT_COUNT (4) */    
    0x81, 0x22,                  /*   INPUT (Data,Var,Abs,Bit Field) */    
    0x15, 0x00,                  /*   LOGICAL_MINIMUM (0) */
    0x25, 0x01,                  /*   LOGICAL_MAXIMUM (1) */
    0x09, 0xe9,                  /*   USAGE (Volume Increment) */
    0x09, 0xea,                  /*   USAGE (Volume Decrement) */
    0x09, 0xe2,                  /*   USAGE (Mute) */
    0x75, 0x01,                  /*   REPORT_SIZE (1) */
    0x95, 0x03,                  /*   REPORT_COUNT (3) */    
    0x81, 0x22,                  /*   INPUT (Data,Var,Abs,Bit Field) */
    0x75, 0x05,                  /*   REPORT_SIZE (5) */
    0x95, 0x01,                  /*   REPORT_COUNT (1) */    
    0x81, 0x01,                  /*   INPUT (Const,Array,Abs,Bit Field) */    
    0xc0,                        /* END_COLLECTION */
    
    0x06, 0xa0, 0xff,            /* USAGE_PAGE (Vendor-defined 0xFFA0) */
    0x09, 0x01,                  /* USAGE (Vendor-defined 0x0001) */
    0xa1, 0x01,                  /* COLLECTION (Application) */  
    0x85, 0x02,                  /*   REPORT_ID (2) */  
    0x09, 0x01,                  /*   USAGE (Vendor-defined 0x0001) */
    0x15, 0x00,                  /*   LOGICAL_MINIMUM (0) */
    0x26, 0xff, 0x00,            /*   LOGICAL_MAXIMUM (255) */
    0x75, 0x08,                  /*   REPORT_SIZE (8) */
    0x95, 0x12,                  /*   REPORT_COUNT (18) */    
    0x91, 0x00,                  /*   OUTPUT (Data,Array,Abs,Non-volatile,Bit Field) */
    0x09, 0x02,                  /*   USAGE (Vendor-defined 0x0002) */    
    0x75, 0x08,                  /*   REPORT_SIZE (8) */
    0x95, 0x12,                  /*   REPORT_COUNT (18) */     
    0x81, 0x00,                  /*   INPUT (Const,Array,Abs,Bit Field) */
    
    0xc0
};

static const EndPointInfo usb_epinfo_hid_consumer_transport[] =
{
    {        
        end_point_int_out, /* address */
        end_point_attr_int, /* attributes */
        16, /* max packet size */
        1, /* poll_interval */
        0, /* data to be appended */
        0, /* length of data appended */
    }
};

static const usb_device_class_hid_consumer_transport_config usb_descriptor_hid_consumer_transport =
{
    {usb_interface_descriptor_hid_consumer_transport,
    sizeof(usb_interface_descriptor_hid_consumer_transport),
    usb_epinfo_hid_consumer_transport},
    {usb_report_descriptor_hid_consumer_transport,
    sizeof(usb_report_descriptor_hid_consumer_transport),
    NULL}
};


/* USB Audio Class Descriptors */
static const uint8 usb_interface_descriptor_control_mic_and_speaker[] =
{
    /* Class Specific Header */
    0x0A,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x01,         /* bDescriptorSubType = HEADER */
    0x00, 0x01,   /* bcdADC = Audio Device Class v1.00 */
#ifdef USB_AUDIO_STEREO_SPEAKER    
    0x0A + 0x0c + 0x0a + 0x09 + 0x0c + 0x09 + 0x09, /* wTotalLength LSB */
#else
    0x0A + 0x0c + 0x09 + 0x09 + 0x0c + 0x09 + 0x09, /* wTotalLength LSB */
#endif    
    0x00,         /* wTotalLength MSB */
    0x02,         /* bInCollection = 2 AudioStreaming interfaces */
    0x01,         /* baInterfaceNr(1) - AS#1 id */
    0x02,         /* baInterfaceNr(2) - AS#2 id */
    
    /* Speaker IT */
    0x0c,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x02,         /* bDescriptorSubType = INPUT_TERMINAL */
    USB_AUDIO_SPEAKER_IT,       /* bTerminalID */
    0x01, 0x01,   /* wTerminalType = USB streaming */
    0x00,         /* bAssocTerminal = none */
    USB_AUDIO_CHANNELS_SPEAKER, /* bNrChannels */
    USB_AUDIO_CHANNEL_CONFIG_SPEAKER & 0xFF, USB_AUDIO_CHANNEL_CONFIG_SPEAKER >> 8,   /* wChannelConfig */
    0x00,         /* iChannelName = no string */
    0x00,         /* iTerminal = same as USB product string */
    
    /* Speaker Features */
#ifdef USB_AUDIO_STEREO_SPEAKER    
    0x0a,           /*bLength*/
#else
    0x09,           /*bLength*/
#endif    
    0x24,           /*bDescriptorType = CS_INTERFACE */
    0x06,           /*bDescriptorSubType = FEATURE_UNIT*/
    USB_AUDIO_SPEAKER_FU,     /*bUnitId*/
    USB_AUDIO_SPEAKER_IT,     /*bSourceId - Speaker IT*/
    0x01,           /*bControlSize = 1 byte per control*/
    0x03,           /*bmaControls[0] = 03 (Master Channel - mute and volume)*/
    0x00,           /*bmaControls[1] = 00 (Logical Channel 1 - nothing)*/ 
#ifdef USB_AUDIO_STEREO_SPEAKER    
    0x00,           /*bmaControls[2] = 00 (Logical Channel 2 - nothing)*/
#endif    
    0x00,           /*iFeature = same as USB product string*/
    
    /* Speaker OT */
    0x09,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x03,         /* bDescriptorSubType = OUTPUT_TERMINAL */
    USB_AUDIO_SPEAKER_OT,   /* bTerminalID */
    0x01, 0x03,   /* wTerminalType = Speaker */
    0x00,         /* bAssocTerminal = none */
    USB_AUDIO_SPEAKER_FU,   /* bSourceID - Speaker Features */
    0x00,         /* iTerminal = same as USB product string */
    
    /* Microphone IT */
    0x0c,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x02,         /* bDescriptorSubType = INPUT_TERMINAL */
    USB_AUDIO_MIC_IT,       /* bTerminalID */
    0x01, 0x02,   /* wTerminalType = Microphone */
    0x00,         /* bAssocTerminal = none */
    USB_AUDIO_CHANNELS_MIC, /* bNrChannels */
    USB_AUDIO_CHANNEL_CONFIG_MIC & 0xFF, USB_AUDIO_CHANNEL_CONFIG_MIC >> 8,   /* wChannelConfig */
    0x00,         /* iChannelName = no string */
    0x00,         /* iTerminal = same as USB product string */
    
    /* Microphone Features */
    0x09,           /*bLength*/
    0x24,           /*bDescriptorType = CS_INTERFACE */
    0x06,           /*bDescriptorSubType = FEATURE_UNIT*/
    USB_AUDIO_MIC_FU,         /*bUnitId*/
    USB_AUDIO_MIC_IT,         /*bSourceId - Microphone IT*/
    0x01,           /*bControlSize = 1 byte per control*/
    0x02,           /*bmaControls[0] = 02 (Master Channel - volume)*/
    0x00,           /*bmaControls[0] = 00 (Logical Channel 1 - nothing)*/
    0x00,           /*iFeature = same as USB product string*/

    /* Microphone OT */
    0x09,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x03,         /* bDescriptorSubType = OUTPUT_TERMINAL */
    USB_AUDIO_MIC_OT,       /* bTerminalID */
    0x01, 0x01,   /* wTerminalType = USB streaming */
    0x00,         /* bAssocTerminal = none */
    USB_AUDIO_MIC_FU,       /* bSourceID - Microphone Features */
    0x00          /* iTerminal = same as USB product string */  
};

static const uint8 usb_interface_descriptor_control_mic[] =
{
    /* Class Specific Header */
    0x09,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x01,         /* bDescriptorSubType = HEADER */
    0x00, 0x01, /* bcdADC = Audio Device Class v1.00 */
    0x09 + 0x0c + 0x09 + 0x09, /* wTotalLength LSB */
    0x00,         /* wTotalLength MSB */
    0x01,         /* bInCollection = 1 AudioStreaming interface */
    0x01,         /* baInterfaceNr(1) - AS#1 id */

    /* Microphone IT */
    0x0c,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x02,         /* bDescriptorSubType = INPUT_TERMINAL */
    USB_AUDIO_MIC_IT, /* bTerminalID */
    0x01, 0x02,   /* wTerminalType = Microphone */
    0x00,         /* bAssocTerminal = none */
    USB_AUDIO_CHANNELS_MIC, /* bNrChannels */
    USB_AUDIO_CHANNEL_CONFIG_MIC & 0xFF, USB_AUDIO_CHANNEL_CONFIG_MIC >> 8, /* wChannelConfig */
    0x00,         /* iChannelName = no string */
    0x00,         /* iTerminal = same as USB product string */
    
    /* Microphone Features */
    0x09,           /*bLength*/
    0x24,           /*bDescriptorType = CS_INTERFACE */
    0x06,           /*bDescriptorSubType = FEATURE_UNIT*/
    USB_AUDIO_MIC_FU,         /*bUnitId*/
    USB_AUDIO_MIC_IT,         /*bSourceId - Microphone IT*/
    0x01,           /*bControlSize = 1 byte per control*/
    0x02,           /*bmaControls[0] = 0001 (Master Channel - volume)*/
    0x00,           /*bmaControls[1] = 0000 (Logical Channel 1 - nothing)*/
    0x00,           /*iFeature = same as USB product string*/

    /* Microphone OT */
    0x09,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x03,         /* bDescriptorSubType = OUTPUT_TERMINAL */
    USB_AUDIO_MIC_OT,       /* bTerminalID */
    0x01, 0x01,   /* wTerminalType = USB streaming */
    0x00,         /* bAssocTerminal = none */
    USB_AUDIO_MIC_FU,       /* bSourceID - Microphone Features */
    0x00,         /* iTerminal = same as USB product string */
};


static const uint8 usb_interface_descriptor_control_speaker[] =
{
    /* Class Specific Header */
    0x09,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x01,         /* bDescriptorSubType = HEADER */
    0x00, 0x01, /* bcdADC = Audio Device Class v1.00 */
#ifdef USB_AUDIO_STEREO_SPEAKER    
    0x09 + 0x0c + 0x0a + 0x09, /* wTotalLength LSB */
#else
    0x09 + 0x0c + 0x09 + 0x09, /* wTotalLength LSB */
#endif    
    0x00,         /* wTotalLength MSB */
    0x01,         /* bInCollection = 1 AudioStreaming interface */
    0x01,         /* baInterfaceNr(1) - AS#1 id */
    
    /* Speaker IT */
    0x0c,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x02,         /* bDescriptorSubType = INPUT_TERMINAL */
    USB_AUDIO_SPEAKER_IT,   /* bTerminalID */
    0x01, 0x01,   /* wTerminalType = USB streaming */
    0x00,         /* bAssocTerminal = none */
    USB_AUDIO_CHANNELS_SPEAKER, /* bNrChannels */
    USB_AUDIO_CHANNEL_CONFIG_SPEAKER & 0xFF, USB_AUDIO_CHANNEL_CONFIG_SPEAKER >> 8, /* wChannelConfig */
    0x00,         /* iChannelName = no string */
    0x00,         /* iTerminal = same as USB product string */
    
    /* Speaker Features */
#ifdef USB_AUDIO_STEREO_SPEAKER    
    0x0a,           /*bLength*/
#else
    0x09,           /*bLength*/
#endif    
    0x24,           /*bDescriptorType = CS_INTERFACE */
    0x06,           /*bDescriptorSubType = FEATURE_UNIT*/
    USB_AUDIO_SPEAKER_FU,     /*bUnitId*/
    USB_AUDIO_SPEAKER_IT,     /*bSourceId - Speaker IT*/
    0x01,           /*bControlSize = 1 byte per control*/
    0x03,           /*bmaControls[0] = 03 (Master Channel - mute and volume)*/
    0x00,           /*bmaControls[1] = 00 (Logical Channel 1 - nothing)*/
#ifdef USB_AUDIO_STEREO_SPEAKER    
    0x00,           /*bmaControls[2] = 00 (Logical Channel 2 - nothing)*/
#endif    
    0x00,           /*iFeature = same as USB product string*/

    /* Speaker OT */
    0x09,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x03,         /* bDescriptorSubType = OUTPUT_TERMINAL */
    USB_AUDIO_SPEAKER_OT,   /* bTerminalID */
    0x01, 0x03,   /* wTerminalType = Speaker */
    0x00,         /* bAssocTerminal = none */
    USB_AUDIO_SPEAKER_FU,   /* bSourceID - Speaker Features*/
    0x00,         /* iTerminal = same as USB product string */
};


static const uint8 usb_interface_descriptor_streaming_mic[] =
{
    /* Class Specific AS interface descriptor */
    0x07,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x01,         /* bDescriptorSubType = AS_GENERAL */
    USB_AUDIO_MIC_OT,       /* bTerminalLink = Microphone OT */
    0x00,         /* bDelay */
    0x01, 0x00,   /* wFormatTag = PCM */

    /* Type 1 format type descriptor */
    0x08 + 0x03,  /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x02,         /* bDescriptorSubType = FORMAT_TYPE */
    0x01,         /* bFormatType = FORMAT_TYPE_I */
    USB_AUDIO_CHANNELS_MIC, /* bNumberOfChannels */
    0x02,         /* bSubframeSize = 2 bytes */
    0x10,         /* bBitsResolution */
    0x01,         /* bSampleFreqType = 1 discrete sampling freq */
    0xFF & (USB_AUDIO_SAMPLE_RATE_MIC),       /* tSampleFreq */
    0xFF & (USB_AUDIO_SAMPLE_RATE_MIC >> 8),  /* tSampleFreq */
    0xFF & (USB_AUDIO_SAMPLE_RATE_MIC >> 16), /* tSampleFreq */

    /* Class specific AS isochronous audio data endpoint descriptor */
    0x07,         /* bLength */
    0x25,         /* bDescriptorType = CS_ENDPOINT */
    0x01,         /* bDescriptorSubType = AS_GENERAL */
    0x00,         /* bmAttributes = none */
    0x02,         /* bLockDelayUnits = Decoded PCM samples */
    0x00, 0x00     /* wLockDelay */
};

static const uint8 usb_interface_descriptor_streaming_speaker[] =
{
    /* Class Specific AS interface descriptor */
    0x07,         /* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x01,         /* bDescriptorSubType = AS_GENERAL */
    USB_AUDIO_SPEAKER_IT,       /* bTerminalLink = Speaker IT */
    0x00,         /* bDelay */
    0x01, 0x00,   /* wFormatTag = PCM */

    /* Type 1 format type descriptor */
    0x08 + 0x03,/* bLength */
    0x24,         /* bDescriptorType = CS_INTERFACE */
    0x02,         /* bDescriptorSubType = FORMAT_TYPE */
    0x01,         /* bFormatType = FORMAT_TYPE_I */
    USB_AUDIO_CHANNELS_SPEAKER, /* bNumberOfChannels */
    0x02,         /* bSubframeSize = 2 bytes */
    0x10,         /* bBitsResolution */
    0x01,         /* bSampleFreqType = 1 discrete sampling freq */
    0xFF & (USB_AUDIO_SAMPLE_RATE_SPEAKER),       /* tSampleFreq */
    0xFF & (USB_AUDIO_SAMPLE_RATE_SPEAKER >> 8),  /* tSampleFreq */
    0xFF & (USB_AUDIO_SAMPLE_RATE_SPEAKER >> 16), /* tSampleFreq */

    /* Class specific AS isochronous audio data endpoint descriptor */
    0x07,         /* bLength */
    0x25,         /* bDescriptorType = CS_ENDPOINT */
    0x01,         /* bDescriptorSubType = AS_GENERAL */
    0x81,         /* bmAttributes = MaxPacketsOnly and SamplingFrequency control */
    0x02,         /* bLockDelayUnits = Decoded PCM samples */
    0x00, 0x00    /* wLockDelay */
};

static const uint8 usb_audio_endpoint_user_data[] =
{
    0, /* bRefresh */
    0  /* bSyncAddress */
};


/*  Streaming Isochronous Endpoint. Maximum packet size 192 (stereo at 48khz) */
static const EndPointInfo usb_epinfo_streaming_speaker[] =
{
    {
        end_point_iso_in, /* address */
        end_point_attr_iso, /* attributes */
        USB_AUDIO_MAX_PACKET_SIZE_SPEAKER, /* max packet size */
        1, /* poll_interval */
        usb_audio_endpoint_user_data, /* data to be appended */
        sizeof(usb_audio_endpoint_user_data) /* length of data appended */      
    }
};


/* Streaming Isochronous Endpoint. Maximum packet size 96 (mono at 48khz) */
static const EndPointInfo usb_epinfo_streaming_mic[] =
{
    {
        end_point_iso_out, /* address */
        end_point_attr_iso, /* attributes */
        USB_AUDIO_MAX_PACKET_SIZE_MIC, /* max packet size */
        1, /* poll_interval */
        usb_audio_endpoint_user_data, /* data to be appended */
        sizeof(usb_audio_endpoint_user_data), /* length of data appended */
    }
};

static const usb_device_class_audio_config usb_descriptor_audio =
{
    {usb_interface_descriptor_control_mic_and_speaker,
    sizeof(usb_interface_descriptor_control_mic_and_speaker),
    NULL},
    {usb_interface_descriptor_streaming_mic,
    sizeof(usb_interface_descriptor_streaming_mic),
    usb_epinfo_streaming_mic},
    {usb_interface_descriptor_streaming_speaker,
    sizeof(usb_interface_descriptor_streaming_speaker),
    usb_epinfo_streaming_speaker}
};

static const usb_device_class_audio_config usb_descriptor_mic =
{
    {usb_interface_descriptor_control_mic,
    sizeof(usb_interface_descriptor_control_mic),
    NULL},
    {usb_interface_descriptor_streaming_mic,
    sizeof(usb_interface_descriptor_streaming_mic),
    usb_epinfo_streaming_mic},
    {NULL, 
     0, 
     NULL}
};

static const usb_device_class_audio_config usb_descriptor_speaker =
{
    {usb_interface_descriptor_control_speaker,
    sizeof(usb_interface_descriptor_control_speaker),
    NULL},
    {NULL,
     0,
     NULL},
    {usb_interface_descriptor_streaming_speaker,
    sizeof(usb_interface_descriptor_streaming_speaker),
    usb_epinfo_streaming_speaker}
};

/* USB audio level configuration */
static const usb_device_class_audio_volume_config usb_audio_levels = {  0xf100, /* speaker_min */
                                                                        0x0000, /* speaker_max */
                                                                        0x0100, /* speaker_res */
                                                                        0xfb00, /* speaker_default */
                                                                        0x0000, /* mic_min */
                                                                        0x1f00, /* mic_max */
                                                                        0x0100, /* mic_res */
                                                                        0x1800  /* mic_default */
                                                                    };


/* Mic table for converting USB volume to local volume */
#define MIC_VOLUME_TABLE_START (9)
static const uint16 micVolumeTable[VOLUME_MAX_MIC_VALUE + 1] =
{
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START, 
    MIC_VOLUME_TABLE_START, 
    MIC_VOLUME_TABLE_START, 
    MIC_VOLUME_TABLE_START, 
    MIC_VOLUME_TABLE_START, 
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START,
    MIC_VOLUME_TABLE_START + 1,
    MIC_VOLUME_TABLE_START + 1, 
    MIC_VOLUME_TABLE_START + 1,
    MIC_VOLUME_TABLE_START + 1,
    MIC_VOLUME_TABLE_START + 1,
    MIC_VOLUME_TABLE_START + 1,
    MIC_VOLUME_TABLE_START + 1,
    MIC_VOLUME_TABLE_START + 2,
    MIC_VOLUME_TABLE_START + 2, 
    MIC_VOLUME_TABLE_START + 2, 
    MIC_VOLUME_TABLE_START + 2,
    MIC_VOLUME_TABLE_START + 2,
    MIC_VOLUME_TABLE_START + 3,
    MIC_VOLUME_TABLE_START + 3,
    MIC_VOLUME_TABLE_START + 3,
    MIC_VOLUME_TABLE_START + 3
};

static USB_DATA_T USB_RUNDATA;

static uint16 usb_get_media_repeat_timer(void);
static bool usb_get_fwd_press(void);
static bool usb_get_rew_press(void);
static void usb_set_fast_forward(bool status);
static void usb_set_rewind(bool status);
static void usb_get_configuration_data(source_usb_configs_values_config_def_t *usb_data);
#ifndef ANALOGUE_INPUT_DEVICE  
static bool usb_get_mic_interface(void);
static bool usb_get_speaker_interface(void);
static bool usb_get_hid_keyboard_interface(void); 
static uint16 usb_vol_mic_rounded(uint16 volume);
static uint16 usb_vol_speaker_rounded(uint16 volume);
#endif

/***************************************************************************
Functions
****************************************************************************
*/


/****************************************************************************
NAME    
    usb_unhandled_host_command -

DESCRIPTION
     Unhandled command received from the Host

RETURNS
    void
*/
static void usb_unhandled_host_command(uint8 cmd, uint8 sub_cmd)
{
    USB_DEBUG(("    USB Host Command Unhandled: Cmd[%d] Sub[%d]\n", cmd, sub_cmd));    
}
/****************************************************************************
NAME    
    usb_convert_report_state - 

DESCRIPTION
     Convert application state to a bit position for reporting current state to the USB host

RETURNS
    The current USB device command state from the application state.
*/
static USB_DEVICE_DATA_STATE_T usb_convert_report_state(SOURCE_STATE_T state)
{
    switch (state)
    {
        case SOURCE_STATE_CONNECTABLE:        
            return USB_DEVICE_DATA_STATE_PAGE_SCAN;
      
        case SOURCE_STATE_DISCOVERABLE:
            return USB_DEVICE_DATA_STATE_INQUIRY_SCAN;
       
        case SOURCE_STATE_CONNECTING:
            return USB_DEVICE_DATA_STATE_PAGE;
        
        case SOURCE_STATE_INQUIRING:
            return USB_DEVICE_DATA_STATE_INQUIRY;
        
        case SOURCE_STATE_CONNECTED:
            return USB_DEVICE_DATA_STATE_CONNECTED;
        
        default:
            return USB_DEVICE_DATA_STATE_UNKNOWN;
    }
}


/****************************************************************************
NAME    
    usb_clear_report_data - 

DESCRIPTION
    Clears a report by setting values to 0

RETURNS
    void
*/
static void usb_clear_report_data(uint8 *report, uint16 report_size)
{
    uint16 index = 0;
    
    for (index = 0; index < report_size; index++)
    {
        report[index] = 0;
    }
}


/****************************************************************************
NAME    
    usb_send_device_command_status - 

DESCRIPTION
    Send application state to host

RETURNS
    void
*/
static bool usb_send_device_command_status(void)
{
    USB_DEVICE_DATA_STATE_T status;
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];    
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Bytes 2-17 - Command Data
           
    */
    
    SOURCE_STATE_T current_state = states_get_state();
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    if (current_state == SOURCE_STATE_IDLE)
    {
        /* if IDLE state, use the pre IDLE state */
        current_state = theSource->app_data.pre_idle_state;
    }
    
    /* initialise report */
    report_bytes[0] = USB_DEVICE_COMMAND_STATE;
    report_bytes[1] = 0;
    
    status = usb_convert_report_state(current_state);
    
    if (status != USB_DEVICE_DATA_STATE_UNKNOWN)
    {
        /*  set data byte indicating status */   
        report_bytes[1] = status;        
    }
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_process_host_command_connection -

DESCRIPTION
     Handles the Host command for current Host connection state

RETURNS
    void
*/
static void usb_process_host_command_connection(uint8 data)
{
    if (data)
    {
        /* Host connected */
        usb_set_hid_mode(USB_HID_MODE_HOST);
    }
    else
    {
        /* Host disconnected */
        usb_set_hid_mode(USB_HID_MODE_CONSUMER);
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_status - 

DESCRIPTION
     Handles the Host command for current status

RETURNS
    void
*/
static void usb_process_host_command_status(uint8 data)
{
    switch (data)
    {
        case USB_HOST_DATA_STATE_ENTER_DUT_MODE:
        {
            USB_DEBUG(("    --- Enter DUT Mode ---\n"));
            MessageCancelAll(app_get_instance(), APP_CONNECT_REQ);
            states_set_state(SOURCE_STATE_TEST_MODE);
        }
        break;
        
        case USB_HOST_DATA_STATE_ENTER_DFU_MODE:
        {
            USB_DEBUG(("    --- Enter DFU Mode ---\n")); 
            BootSetMode(0);        
        }
        break;
        
        case USB_HOST_DATA_STATE_GET_STATE:
        {
            USB_DEBUG(("    --- Get State ---\n")); 
            /* return status to Host */
            usb_send_device_command_status();
        }    
        break;
        
        case USB_HOST_DATA_STATE_INQUIRY:
        {
            USB_DEBUG(("    --- Enter Inquiry ---\n"));
            /* cancel connecting timer */
            MessageCancelAll(app_get_instance(), APP_CONNECT_REQ);  
            /* move to inquiry state */    
            states_set_state(SOURCE_STATE_INQUIRING);
            /* indicate this is a forced inquiry, and must remain in this state until a successful connection */
            inquiry_set_forced_inquiry_mode(TRUE);
        }
        break;
        
        case USB_HOST_DATA_STATE_INQUIRY_SCAN:
        {
            USB_DEBUG(("    --- Enter Inquiry Scan ---\n"));
            /* cancel connecting timer */
            MessageCancelAll(app_get_instance(), APP_CONNECT_REQ);  
            /* move to discoverable state */    
            states_set_state(SOURCE_STATE_DISCOVERABLE);     
        }
        break;
        
        case USB_HOST_DATA_STATE_PAGE:
        {
            bdaddr  bt_addr = {0,0,0};
            USB_DEBUG(("    --- Enter Page ---\n"));        
            if (states_get_state() == SOURCE_STATE_CONNECTED)
            {
                MessageSend(app_get_instance(), APP_DISCONNECT_REQ, 0);
            }
            else if (states_get_state() != SOURCE_STATE_CONNECTING)
            {            
                inquiry_set_forced_inquiry_mode(FALSE);
                connection_mgr_get_remote_device_address(&bt_addr);
                /* initialise the connection with the connection manager */
                connection_mgr_start_connection_attempt(&bt_addr, connection_mgr_is_aghfp_profile_enabled() ? PROFILE_AGHFP : PROFILE_A2DP, 0);
            }
            /* set appropriate timers as it is being forced to stay in page state */
            states_no_timers();
        }
        break;
        
        case USB_HOST_DATA_STATE_PAGE_SCAN:
        {
            USB_DEBUG(("    --- Enter Page Scan ---\n"));  
            MessageCancelAll(app_get_instance(), APP_CONNECT_REQ);
            states_set_state(SOURCE_STATE_CONNECTABLE); 
        }
        break;
        
        default:
        {
            usb_unhandled_host_command(USB_HOST_COMMAND_STATE, data);
        }
        break;
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_call - 

DESCRIPTION
     Handles the Host command for current call state

RETURNS
    void
*/
static void usb_process_host_command_call(uint8 call_state, uint16 size_data, const uint8 *data)
{
    switch (call_state)
    {
       case USB_HOST_DATA_AG_CALL_STATE_NONE:
        {
            USB_DEBUG(("    --- No Call ---\n"));
            aghfp_call_ind_none();
        }
        break;
        
       case USB_HOST_DATA_AG_CALL_STATE_INCOMING:
        {
            USB_DEBUG(("    --- Incoming Call ---\n"));
            aghfp_call_ind_incoming(size_data, data);
        }
        break;
        
        case USB_HOST_DATA_AG_CALL_STATE_OUTGOING:
        {
            USB_DEBUG(("    --- Outgoing Call ---\n"));
            aghfp_call_ind_outgoing();
        }
        break;
        
        case USB_HOST_DATA_AG_CALL_STATE_ACTIVE:
        {
            USB_DEBUG(("    --- Active Call ---\n"));
            aghfp_call_ind_active();
        }
        break;
        
        case USB_HOST_DATA_AG_CALL_STATE_CALL_WAITING_ACTIVE_CALL:
        {
            USB_DEBUG(("    --- Call Waiting Active Call ---\n"));
            aghfp_call_ind_waiting_active_call(size_data, data);
        }
        break;
        
        case USB_HOST_DATA_AG_CALL_STATE_CALL_HELD_ACTIVE_CALL:
        {
            USB_DEBUG(("    --- Call Held Active Call ---\n"));
            aghfp_call_ind_held_active_call();
        }
        break;
        
        case USB_HOST_DATA_AG_CALL_STATE_CALL_HELD:
        {
            USB_DEBUG(("    --- Call Held ---\n"));
            aghfp_call_ind_held();
        }
        break;
        
        default:
        {
            usb_unhandled_host_command(USB_HOST_COMMAND_AG_CALL_STATE, call_state);
        }
        break;
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_signal_strength - 

DESCRIPTION
     Handles the Host command for signal strength

RETURNS
    void
*/
static void usb_process_host_command_signal_strength(uint8 sub_cmd, uint16 size_data, const uint8 *data)
{
    if (sub_cmd == USB_HOST_DATA_AG_SIGNAL_STRENGTH_VALUE)
    {
        if (size_data >= 1)
        {
            USB_DEBUG(("    --- Signal Strength ---\n"));
            aghfp_signal_strength_ind(data[0]);
        }
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_battery_level -

DESCRIPTION
     Handles the Host command for battery level

RETURNS
    void
*/
static void usb_process_host_command_battery_level(uint8 sub_cmd, uint16 size_data, const uint8 *data)
{
    if (sub_cmd == USB_HOST_DATA_AG_BATTERY_LEVEL_VALUE)
    {
        if (size_data >= 1)
        {
            USB_DEBUG(("    --- Battery Level ---\n"));
            aghfp_battery_level_ind(data[0]);
        }
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_audio - 

DESCRIPTION
     Handles the Host command for audio

RETURNS
    void
*/
static void usb_process_host_command_audio(uint8 command, uint16 size_data, const uint8 *data)
{
    switch (command)
    {
        case USB_HOST_DATA_AG_AUDIO_GET_STATE:
        {
            USB_DEBUG(("    --- Get Audio State ---\n"));  
            if (aghfp_is_audio_active())
                usb_send_device_command_audio_state(USB_DEVICE_DATA_AG_AUDIO_STATE_AUDIO_CONNECTED);
            else if (aghfp_get_number_connections())
                usb_send_device_command_audio_state(USB_DEVICE_DATA_AG_AUDIO_STATE_AUDIO_DISCONNECTED);
            else
                usb_send_device_command_audio_state(USB_DEVICE_DATA_AG_AUDIO_STATE_NO_SLC_CONNECTION);
        }
        break;
        
        case USB_HOST_DATA_AG_AUDIO_TRANSFER:
        {
            USB_DEBUG(("    --- Transfer Audio ---\n"));  
            aghfp_audio_transfer_req(data[0]);
        }
        break;
        
        default:
        {
            usb_unhandled_host_command(USB_HOST_COMMAND_AG_AUDIO, command);
        }
        break;
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_link_mode -

DESCRIPTION
      Handles the Host command for link mode

RETURNS
    void
*/
static void usb_process_host_command_link_mode(uint8 sub_cmd, uint16 size_data, const uint8 *data)
{
    USB_DEVICE_DATA_AG_LINK_MODE_T mode;
    if (sub_cmd == USB_HOST_DATA_AG_LINK_GET_MODE)
    {
        if (size_data >= 1)
        {
            USB_DEBUG(("     --- Get Link Mode ---\n"));
	        mode = aghfp_get_link_mode();
            usb_send_device_command_link_mode(mode);
        }
    }	
}


/****************************************************************************
NAME    
    usb_process_host_command_network - 

DESCRIPTION
      Handles the Host command for network state

RETURNS
    void
*/
static void usb_process_host_command_network(uint8 command, uint16 size_data, const uint8 *data)
{
    switch (command)
    {
        case USB_HOST_DATA_AG_NETWORK_OPERATOR:
        {
            USB_DEBUG(("    --- Network Operator Name ---\n"));
            aghfp_network_operator_ind(size_data, data);
        }
        break;
        
        case USB_HOST_DATA_AG_NETWORK_AVAILABILITY:
        {
            if (size_data >= 1)
            {
                USB_DEBUG(("    --- Network Operator Availability ---\n"));
                aghfp_network_availability_ind(data[0]);
            }
        }
        break;
        
        case USB_HOST_DATA_AG_NETWORK_ROAM:
        {
            if (size_data >= 1)
            {
                USB_DEBUG(("    --- Network Operator Roam ---\n"));
                aghfp_network_roam_ind(data[0]);
            }
        }
        break;
        
        default:
        {
            usb_unhandled_host_command(USB_HOST_COMMAND_AG_NETWORK, command);
        }
        break;
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_network - 

DESCRIPTION
      Handles the Host command for hf indicator state(enable/disable)

RETURNS
    void
*/
static void usb_process_host_command_hf_indicator(uint8 command, uint16 size_data, const uint8 *data)
{
    switch (command)
    {
        case USB_HOST_DATA_AG_HF_INDICATOR_ENHANCED_SAFETY:
        {
            if (size_data >= 1)
            {			
                USB_DEBUG(("    --- Enhanced Safety Indicator ---\n"));
                aghfp_hf_indicator_ind(command, data[0]);
            }
        }
        break;
        
        case USB_HOST_DATA_AG_HF_INDICATOR_BATTERY_LEVEL:
        {
            if (size_data >= 1)
            {
                USB_DEBUG(("    --- Battery Level Indicator ---\n"));
                aghfp_hf_indicator_ind(command, data[0]);
            }
        }
        break;
        
        default:
        {
            usb_unhandled_host_command(USB_HOST_COMMAND_AG_HF_INDICATOR, command);
        }
        break;
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_ag_error - 

DESCRIPTION
      Handles the Host command for AG error status

RETURNS
    void
*/
static void usb_process_host_command_ag_error(uint8 command)
{
    switch (command)
    {
        case USB_HOST_DATA_AG_ERROR_INVALID_MEMORY_LOCATION:
        {
            USB_DEBUG(("    --- AG Error Invalid Memory Location ---\n"));
            aghfp_error_ind();
        }
        break;
        
        case USB_HOST_DATA_AG_ERROR_INVALID_LAST_NUMBER_DIAL:
        {
            USB_DEBUG(("    --- AG Error Invalid Last Number Dial ---\n"));
            aghfp_error_ind();
        }
        break;
        
        default:
        {
            usb_unhandled_host_command(USB_HOST_COMMAND_AG_ERROR, command);
        }
        break;
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_ag_ok - 

DESCRIPTION
      Handles the Host command for AG ok status

RETURNS
    void
*/
static void usb_process_host_command_ag_ok(uint8 command)
{
    switch (command)
    {            
        case USB_HOST_DATA_AG_OK_VALID_MEMORY_LOCATION:
        {
            USB_DEBUG(("    --- AG OK Valid Memory Location ---\n"));
            aghfp_ok_ind();
        }
        break;
        
        case USB_HOST_DATA_AG_OK_VALID_LAST_NUMBER_DIAL:
        {
            USB_DEBUG(("    --- AG OK Valid Last Number Dial ---\n"));
            aghfp_ok_ind();
        }
        break;
        
        case USB_HOST_DATA_AG_OK_SENT_ALL_CURRENT_CALLS:
        {
            USB_DEBUG(("    --- AG OK Sent All Current Calls ---\n"));
            aghfp_ok_ind();
        }
        break;
        
        default:
        {
            usb_unhandled_host_command(USB_HOST_COMMAND_AG_OK, command);
        }
        break;
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_current_call - 

DESCRIPTION
     Handles the Host command for current call status

RETURNS
    void
*/
static void usb_process_host_command_current_call(uint8 sub_cmd, uint16 size_data, const uint8 *data)
{
    if (sub_cmd == USB_HOST_DATA_AG_CURRENT_CALL_DETAILS)
    {
        USB_DEBUG(("    --- AG Current Call ---\n"));
        aghfp_current_call_ind(size_data, data);
    }
}


/****************************************************************************
NAME    
    usb_process_host_command_ag_voice - 

DESCRIPTION
     Handles the Host command for voice recognition

RETURNS
    void
*/
static void usb_process_host_command_ag_voice(uint8 command)
{
    USB_DEBUG(("    --- Voice Recognition ---\n"));
    aghfp_voice_recognition_ind(command ? TRUE : FALSE);
}


/****************************************************************************
NAME    
    usb_process_vendor_report - 

DESCRIPTION
     Handle host report

RETURNS
    void
*/
static void usb_process_vendor_report(const uint16 size_data, const uint8 *data)
{
    if (size_data >= 2) /* expect SET_REPORT to have 2 bytes - first byte is report ID, second byte is command type */
    {        
        USB_DEBUG(("USB: Process SET_REPORT (Report ID = %d) command=[0x%x]\n", data[0], data[1]));
        
        /* Expected Report (ID=2) received from Host is to be the expected format:
           
           Byte 0 - Report ID
           
           Byte 1 - Host Command           
           
           Bytes 2-17 - Command Data
          
        */
        
        switch (data[1])
        {
            case USB_HOST_COMMAND_HOST_CONNECTION:
            {
                usb_process_host_command_connection(data[2]);
            }
            break;
            
            case USB_HOST_COMMAND_STATE:
            {        
                usb_process_host_command_status(data[2]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_CALL_STATE:
            {        
                usb_process_host_command_call(data[2], size_data - 3, &data[3]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_SIGNAL_STRENGTH:
            {            
                usb_process_host_command_signal_strength(data[2], size_data - 3, &data[3]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_BATTERY_LEVEL:
            {
                usb_process_host_command_battery_level(data[2], size_data - 3, &data[3]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_AUDIO:
            {
                usb_process_host_command_audio(data[2],size_data - 3, &data[3]);
            }
            break;

            case USB_HOST_COMMAND_AG_LINK_MODE:
            {
                usb_process_host_command_link_mode(data[2], size_data - 3, &data[3]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_NETWORK:
            {
                usb_process_host_command_network(data[2], size_data - 3, &data[3]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_ERROR:
            {
                usb_process_host_command_ag_error(data[2]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_OK:
            {
                usb_process_host_command_ag_ok(data[2]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_CURRENT_CALL:
            {
                usb_process_host_command_current_call(data[2], size_data - 3, &data[3]);
            }
            break;
            
            case USB_HOST_COMMAND_AG_VOICE_RECOGNITION:
            {
                usb_process_host_command_ag_voice(data[2]);
            }
            break;

            case USB_HOST_COMMAND_AG_HF_INDICATOR:
            {
                usb_process_host_command_hf_indicator(data[2], size_data - 3, &data[3]);
            }
            break;
			
            default:
            {
                USB_DEBUG(("USB: Host Command not recognised %d\n", data[1])); 
            }
            break;
        }
    }
}


/****************************************************************************
NAME    
    usb_time_critical_init - 

DESCRIPTION
     Enumerate as a USB device before the main application starts up

RETURNS
    void
*/
void usb_time_critical_init(void)
{
    uint16 device_class = 0;
    usb_device_class_status status = usb_device_class_status_invalid_param_value;
    source_usb_configs_values_config_def_t usb_data ;

    USB_DEBUG(("USB usb_time_critical_init\n"));
    memset(&usb_data,0,sizeof(source_usb_configs_values_config_def_t));

    /* Read USB configuration if not Analogue Input device */
    usb_get_configuration_data(&usb_data);

    /* check which USB Device Classes have been enabled */
    if (usb_data.usbHidConsumerInterface)
    {
        device_class |= USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL;

        if(sourceAhiIsUsbHidDataLinkEnabled())
        {
            device_class |= USB_DEVICE_CLASS_TYPE_HID_DATALINK_CONTROL;
        }
          
        /* configure HID consumer transport */
        status = UsbDeviceClassConfigure(USB_DEVICE_CLASS_CONFIG_HID_CONSUMER_TRANSPORT_DESCRIPTORS, 0, 0, (const uint8*)&usb_descriptor_hid_consumer_transport); 
        
        if(status != usb_device_class_status_success)
        {
            USB_DEBUG(("USB HID Config Descriptor Error %d\n", status));       
            return;
        }              
    }
    #ifndef ANALOGUE_INPUT_DEVICE
    if (usb_data.usbHidKeybInterface)
    {
        device_class |= USB_DEVICE_CLASS_TYPE_HID_KEYBOARD;
    }
    if (usb_data.usbMicInterface)
    {
        device_class |= USB_DEVICE_CLASS_TYPE_AUDIO_MICROPHONE;
    }
    if (usb_data.usbSpeakerInterface)
    {
        device_class |= USB_DEVICE_CLASS_TYPE_AUDIO_SPEAKER;
    }
    
    USB_DEBUG(("    device class [0x%x]\n", device_class));
        
    if (usb_data.usbMicInterface|| usb_data.usbSpeakerInterface)
    {
        /* configure Audio to include Vendor specific functionality */
        
        if (usb_data.usbMicInterface&& usb_data.usbSpeakerInterface)
        {
            status = UsbDeviceClassConfigure(USB_DEVICE_CLASS_CONFIG_AUDIO_INTERFACE_DESCRIPTORS, 0, 0, (const uint8*)&usb_descriptor_audio);
        }
        else if (usb_data.usbMicInterface)
        {
            status = UsbDeviceClassConfigure(USB_DEVICE_CLASS_CONFIG_AUDIO_INTERFACE_DESCRIPTORS, 0, 0, (const uint8*)&usb_descriptor_mic);
        }
        else if (usb_data.usbSpeakerInterface)
        {
            status = UsbDeviceClassConfigure(USB_DEVICE_CLASS_CONFIG_AUDIO_INTERFACE_DESCRIPTORS, 0, 0, (const uint8*)&usb_descriptor_speaker);
        }
    
        if(status != usb_device_class_status_success)
        {
            USB_DEBUG(("USB Audio Descriptor Config Error %d\n", status));
            return;
        } 
       
        /* configure Audio to set volume levels */
        status = UsbDeviceClassConfigure(USB_DEVICE_CLASS_CONFIG_AUDIO_VOLUMES, 0, 0, (const uint8*)&usb_audio_levels); 
    
        if(status != usb_device_class_status_success)
        {
            USB_DEBUG(("USB Audio Volume Config Error %d\n", status));
            return;
        } 
       
    }
    #endif
    if (device_class)
    {
        /* Attempt to enumerate - abort if failed */
        status = UsbDeviceClassEnumerate(&theSource->usbTask, device_class);

        if(status != usb_device_class_status_success)
        {
            USB_DEBUG(("USB Enumerate Error %d\n", status));
            return;
        }
    }
}


/****************************************************************************
NAME    
    usb_get_speaker_source - 

DESCRIPTION
     Get the instance of speake sourcer .

RETURNS
    The speaker Source.
*/
Source usb_get_speaker_source(void)
{
    Source speaker_src = NULL;
    #ifndef ANALOGUE_INPUT_DEVICE  
    if (usb_get_speaker_interface())
    {    
        /* Speaker will be the USB Source data */
        UsbDeviceClassGetValue(USB_DEVICE_CLASS_GET_VALUE_AUDIO_SOURCE, (uint16*)(&speaker_src));
    }
    #endif
    return speaker_src;
}


/****************************************************************************
NAME    
    usb_get_mic_sink 

DESCRIPTION
     Get the instance of Sink Mic.

RETURNS
    The mic Sink.
*/
Sink usb_get_mic_sink(void)
{
    Sink mic_sink = NULL;
    #ifndef ANALOGUE_INPUT_DEVICE     
    if (usb_get_mic_interface())
    {
        /* Mic will be the USB Sink data */
        UsbDeviceClassGetValue(USB_DEVICE_CLASS_GET_VALUE_AUDIO_SINK, (uint16*)(&mic_sink));
    }
    #endif
    return mic_sink;
}


/****************************************************************************
NAME    
    usb_get_audio_levels_update_headset - 

DESCRIPTION
     Get USB audio levels which could be echoed to the remote device

RETURNS
    void
*/
void usb_get_audio_levels_update_headset(bool only_if_volumes_changed)
{    
    #ifndef ANALOGUE_INPUT_DEVICE  
    usb_device_class_audio_levels levels;
    if (usb_get_speaker_interface() || usb_get_mic_interface())
    {
        /* get the current USB audio levels */ 
        UsbDeviceClassGetValue(USB_DEVICE_CLASS_GET_VALUE_AUDIO_LEVELS, (uint16*)&levels);
    
        /* convert raw USB audio levels to local volume settings */
        levels.out_l_vol = usb_vol_speaker_rounded(levels.out_l_vol);
        levels.out_r_vol = usb_vol_speaker_rounded(levels.out_r_vol);
        levels.in_vol = usb_vol_mic_rounded(levels.in_vol);

        USB_DEBUG(("USB Gain L [%X] R [%X] MIC [%X]\n", levels.out_l_vol, levels.out_r_vol, levels.in_vol));
        USB_DEBUG(("USB Mute M [%X] S [%X]\n", levels.in_mute, levels.out_mute));
        
        volume_usb_levels_changed_ind(levels.in_vol, levels.out_l_vol, levels.in_mute, levels.out_mute);    
    }
    #endif
}


/****************************************************************************
NAME    
    usb_send_media_hid_command - 

DESCRIPTION
     Get USB media command to host

RETURNS
    void
*/
void usb_send_media_hid_command(avc_operation_id op_id, bool state)
{
    USB_DEBUG(("USB Set Media HID cmd[%d] state[%d]\n", op_id, state));
    
    if ((op_id != opid_fast_forward) && usb_get_fwd_press())
    {
        /* send a FFWD release event if another media command is activated without sending a release */
        MessageCancelAll(app_get_instance(), APP_USB_FFWD_RELEASE);
        usb_fast_forward_release();
    }
    if ((op_id != opid_rewind) && usb_get_rew_press())
    {
        /* send a REW release event if another media command is activated without sending a release */
        MessageCancelAll(app_get_instance(), APP_USB_REW_RELEASE);
        usb_rewind_release();
    }
    
    switch (op_id)
    {
        case opid_play:
        {
            if (!state)
            {
                /* play press */
                {
                    if (usb_get_hid_consumer_interface())
                    {
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_PLAY_PAUSE);
                    }
                }
            }
            else
            {
                /* play release */
            }
        }
        break;
        
        case opid_stop:
        {
            if (!state)
            {
                /* stop press */
                {
                    if (usb_get_hid_consumer_interface())
                    {
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_STOP);
                    }
                }
            }
            else
            {
                /* stop release */
            }
        }
        break;
        
        case opid_pause:
        {
            if (!state)
            {
                /* play press */
                {
                    if (usb_get_hid_consumer_interface())
                    {
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_PLAY_PAUSE);
                    }
                }
            }
            else
            {
                /* play release */
            }
        }
        break;
        
        case opid_rewind:
        {
            if (!state)
            {
                if (!usb_get_rew_press())
                {                    
                    /* send REW event on first press */
                    usb_set_rewind(TRUE);
                    {
                        if (usb_get_hid_consumer_interface())
                        {
                            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_REW_ON);
                            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_REW_OFF);
                        }
                    }
                }
                /* send release event after timeout if no further press commands received */
                MessageCancelAll(app_get_instance(), APP_USB_REW_RELEASE);
                MessageSendLater(app_get_instance(), APP_USB_REW_RELEASE, 0, usb_get_media_repeat_timer());
            }
        }
        break;
        
        case opid_fast_forward:
        {
            if (!state)
            {
                if (!usb_get_fwd_press())
                {                  
                    /* send FFWD event on first press */
                    usb_set_fast_forward(TRUE);
                    {
                        if (usb_get_hid_consumer_interface())
                        {
                            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_FFWD_ON);
                            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_FFWD_OFF);
                        }
                    }
                }
                /* send release event after timeout if no further press commands received */               
                MessageCancelAll(app_get_instance(), APP_USB_FFWD_RELEASE);
                MessageSendLater(app_get_instance(), APP_USB_FFWD_RELEASE, 0, usb_get_media_repeat_timer());               
            }
        }
        break;
        
        case opid_forward:
        {
            if (!state)
            {
                /* skip forward press */
                {
                    if (usb_get_hid_consumer_interface())
                    {
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_NEXT_TRACK);
                    }
                }
            }
            else
            {
                /* forward release */
            }
        }
        break;
        
        case opid_backward:
        {
            if (!state)
            {
                /* skip backward press */
                {
                    if (usb_get_hid_consumer_interface())
                    {
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_PREVIOUS_TRACK);
                    }
                }
            }
            else
            {
                /* backward release */
            }    
        }
        break;
        
        case opid_volume_up:
        {            
            if (!state)
            {
                usb_device_class_audio_levels levels;
    
                if (usb_get_hid_consumer_interface())
                {
                    /* get the current USB audio levels */ 
                    UsbDeviceClassGetValue(USB_DEVICE_CLASS_GET_VALUE_AUDIO_LEVELS, (uint16*)&levels);
                
                    if (levels.out_mute)
                    {
                        /* send mute over USB */
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_MUTE);
                    }
                    else
                    {
                        /* send volume up over USB */
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_VOL_UP);
                    }
                }
            }
        }
        break;
        
        case opid_volume_down:
        {
            if (!state)
            {
                usb_device_class_audio_levels levels;
                
                if (usb_get_hid_consumer_interface())
                {    
                    /* get the current USB audio levels */ 
                    UsbDeviceClassGetValue(USB_DEVICE_CLASS_GET_VALUE_AUDIO_LEVELS, (uint16*)&levels);
                
                    if (levels.out_mute)
                    {
                        /* send mute over USB */
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_MUTE);
                    }
                    else
                    {
                        /* send volume down over USB */
                        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_VOL_DOWN);
                    }
                }
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
    usb_get_hid_mode - 

DESCRIPTION
     Get USB HID modes

RETURNS
    The current HID mode.Possible values are :
    USB_HID_MODE_CONSUMER
    USB_HID_MODE_HOST
*/
USB_HID_MODE_T usb_get_hid_mode(void)
{
    return USB_RUNDATA.hid_mode;
}


/****************************************************************************
NAME    
    usb_set_hid_mode - 

DESCRIPTION
     Set USB HID mode

RETURNS
    void
*/
void usb_set_hid_mode(USB_HID_MODE_T mode)
{
    USB_RUNDATA.hid_mode = mode;
    USB_DEBUG(("USB Set Mode [%d]\n", mode));
    if (usb_get_hid_mode() == USB_HID_MODE_CONSUMER)
    {
        /* restore timers read from PS */
        states_restore_timers();
        /* no longer forcing inquiry mode */
        inquiry_set_forced_inquiry_mode(FALSE);
    }
}


/****************************************************************************
NAME    
    usb_send_vendor_state - 

DESCRIPTION
     Sends application state to host after a state change

RETURNS
    void
*/
void usb_send_vendor_state(void)
{
    if (usb_get_hid_mode() == USB_HID_MODE_HOST)
    {
        usb_send_device_command_status();
    }
}


/****************************************************************************
NAME    
    usb_handle_report - 

DESCRIPTION
     Handles USB_DEVICE_CLASS_MSG_REPORT_IND message 

RETURNS
    void
*/
void usb_handle_report(MessageId id,const USB_DEVICE_CLASS_MSG_REPORT_IND_T *msg)
{
    if (msg->class_type == USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL)
    {
        if ((msg->report_id & 0xf )== USB_CONSUMER_REPORT_ID)
        {
            /* this is a Vendor SET_REPORT received from the Host */
            usb_process_vendor_report(msg->size_report, msg->report);
        }        
    }
    else if(msg->class_type == USB_DEVICE_CLASS_TYPE_HID_DATALINK_CONTROL)
    {
        if((msg->report_id & 0xf )== HID_REPORTID_DATA_TRANSFER)
        {
            AhiUsbHostHandleMessage(id, msg);
        }
    }
}


/****************************************************************************
NAME    
    usb_rewind_release -

DESCRIPTION
      Send Rewind released to host

RETURNS
    void
*/
void usb_rewind_release(void)
{
    USB_RUNDATA.rew_press = FALSE;
    {
        if (usb_get_hid_consumer_interface())
        {
            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_REW_ON);
            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_REW_OFF);
        }
    }
}


/****************************************************************************
NAME    
    usb_fast_forward_release - 

DESCRIPTION
      Send Fast Forward released to host

RETURNS
    void
*/
void usb_fast_forward_release(void)
{
    USB_RUNDATA.ffwd_press = FALSE;
    {
        if (usb_get_hid_consumer_interface())
        {            
            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_FFWD_ON);
            UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_CONSUMER_TRANSPORT_FFWD_OFF);
        }
    }
}


/****************************************************************************
NAME    
    usb_send_hid_answer -

DESCRIPTION
       Sends a HID command to answer a call

RETURNS
    void
*/
void usb_send_hid_answer(void)
{
    #ifndef ANALOGUE_INPUT_DEVICE  
    if (usb_get_hid_keyboard_interface())
    {
        /* send ALT+PGUP over USB */
        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_KEYBOARD_ALT_PGUP);
    }
    #endif
}


/****************************************************************************
NAME    
    usb_send_hid_hangup - 

DESCRIPTION
       Sends a HID command to hang up a call

RETURNS
    void
*/
void usb_send_hid_hangup(void)
{
    #ifndef ANALOGUE_INPUT_DEVICE  
    if (usb_get_hid_keyboard_interface())
    {
        /* send ALT+PGDN over USB */
        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_KEYBOARD_ALT_PGDN);
        /* send ALT+End over USB */
        UsbDeviceClassSendEvent(USB_DEVICE_CLASS_EVENT_HID_KEYBOARD_ALT_END);
    }
    #endif
}


/****************************************************************************
NAME    
    usb_send_device_command_accept_call - 

DESCRIPTION
       Send accept call event to host

RETURNS
    TRUE, if the USB command to accept the call on host  is sent successfully.
    FALSE, if the USB send report is error.
*/
bool usb_send_device_command_accept_call(void)
{
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];
    
    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Byte 2 - Device Sub-Command
           
           Bytes 3-17 - Command Data
           
    */
    
    /* initialise report */
    report_bytes[0] = USB_DEVICE_COMMAND_AG_CALL;
    report_bytes[1] = USB_DEVICE_COMMAND_AG_CALL_ACCEPT;
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_send_device_command_reject_call - 

DESCRIPTION
       Send reject call event to host

RETURNS
    TRUE, if the USB command to reject the call on host  is sent successfully.
    FALSE, if the USB send report is error.
*/
bool usb_send_device_command_reject_call(void)
{
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];
    
    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Byte 2 - Device Sub-Command
           
           Bytes 3-17 - Command Data
           
    */
    
    /* initialise report */
    report_bytes[0] = USB_DEVICE_COMMAND_AG_CALL;
    report_bytes[1] = USB_DEVICE_COMMAND_AG_CALL_REJECT;
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_send_device_command_dial_number - 

DESCRIPTION
       Send number to dial to the Host

RETURNS
    TRUE, if the USB command to send the number dial for host  is sent successfully.
    FALSE, if the USB send report is error.
*/
bool usb_send_device_command_dial_number(uint16 size_number, uint8 *number)
{
    uint16 index;
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];
    
    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Byte 2 - Device Sub-Command
           
           Bytes 3-17 - Command Data
           
    */
    
    /* initialise report */
    if (size_number > (USB_CONSUMER_REPORT_SIZE - 3))
    {
        size_number = USB_CONSUMER_REPORT_SIZE - 3;
    }    
    report_bytes[0] = USB_DEVICE_COMMAND_AG_CALL;
    report_bytes[1] = USB_DEVICE_COMMAND_AG_CALL_NUMBER_SUPPLIED; /* command */
    report_bytes[2] = size_number; /* size byte */
    for (index = 0; index < size_number; index ++)
    {
        report_bytes[index + 3] = number[index]; /* number to dial */
    }
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_send_device_command_dial_memory - 

DESCRIPTION
       Send memory location to dial to the Host

RETURNS
    TRUE, if the USB command to send the memory location to dial for host  is sent successfully.
    FALSE, if the USB send report is error.
*/
bool usb_send_device_command_dial_memory(uint16 size_number, uint8 *number)
{
    uint16 index;
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];
    
    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Byte 2 - Device Sub-Command
           
           Bytes 3-17 - Command Data
           
    */
    
    /* initialise report */
    if (size_number > (USB_CONSUMER_REPORT_SIZE - 3))
    {
        size_number = USB_CONSUMER_REPORT_SIZE - 3;
    }    
    report_bytes[0] = USB_DEVICE_COMMAND_AG_CALL;
    report_bytes[1] = USB_DEVICE_COMMAND_AG_CALL_MEMORY; /* command */
    report_bytes[2] = size_number; /* size byte */
    for (index = 0; index < size_number; index ++)
    {
        report_bytes[index + 3] = number[index]; /* memory location to dial */
    }
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_send_device_command_dial_last -

DESCRIPTION
        Send last number dial to the Host

RETURNS
    TRUE, if the USB command to send the dial last command  is sent successfully.
    FALSE, if the USB send report is error.
    
*/
bool usb_send_device_command_dial_last(void)
{
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];
    
    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Byte 2 - Device Sub-Command
           
           Bytes 3-17 - Command Data
           
    */
    
    /* initialise report */
    report_bytes[0] = USB_DEVICE_COMMAND_AG_CALL;
    report_bytes[1] = USB_DEVICE_COMMAND_AG_CALL_LAST_NUMBER;
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_send_device_command_audio_state - 

DESCRIPTION
        Sends the audio connection state to the Host

RETURNS
    TRUE, if the USB command to send the audio state to is sent successfully.
    FALSE, if the USB send report is error.
    
*/
bool usb_send_device_command_audio_state(USB_DEVICE_DATA_AG_AUDIO_STATE_T state)
{
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];
    
    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Byte 2 - Device Sub-Command
           
           Bytes 3-17 - Command Data
           
    */
    
    /* initialise report */
    report_bytes[0] = USB_DEVICE_COMMAND_AG_AUDIO_STATE;
    report_bytes[1] = state;
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_send_device_command_link_mode - 

DESCRIPTION
        Sends the link mode to the Host

RETURNS
    TRUE, if the USB command to send the link mode is sent successfully.
    FALSE, if the USB send report is error.
    
*/
bool usb_send_device_command_link_mode(USB_DEVICE_DATA_AG_LINK_MODE_T mode)
{
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];    

    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Bytes 2-17 - Command Data
           
    */  
  
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* initialise report */
    report_bytes[0] = USB_DEVICE_COMMAND_AG_LINK_MODE;
    report_bytes[1] = mode; 
   
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_send_device_command_current_calls - 

DESCRIPTION
        Sends the command the get the current call list to the Host

RETURNS
    TRUE, if the USB command to get the current call list  is sent successfully.
    FALSE, if the USB send report is error.
*/
bool usb_send_device_command_current_calls(void)
{
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];
    
    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Byte 2 - Device Sub-Command
           
           Bytes 3-17 - Command Data
           
    */
    
    /* initialise report */
    report_bytes[0] = USB_DEVICE_COMMAND_AG_CALL;
    report_bytes[1] = USB_DEVICE_COMMAND_AG_CALL_GET_CURRENT_CALLS;    
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_send_device_command_voice_recognition - 

DESCRIPTION
        Sends the voice recognition state to the Host

RETURNS
    TRUE, if the USB command to send the voice recognition is sent successfully.
    FALSE, if the USB send report is error.
    
*/
bool usb_send_device_command_voice_recognition(bool enable)
{
    uint8 report_bytes[USB_CONSUMER_REPORT_SIZE];
    
    if (usb_get_hid_mode() != USB_HID_MODE_HOST)
    {
        /* only send USB message to Host if it is connected */
        return FALSE;
    }
    
    /* clear report data */
    usb_clear_report_data(report_bytes, USB_CONSUMER_REPORT_SIZE);
    
    /* Expected Report (ID=2) sent to Host is to be the expected format:
           
           Byte 0 - Report ID
         
           Byte 1 - Device Command
           
           Byte 2 - Device Sub-Command
           
           Bytes 3-17 - Command Data
           
    */
    
    /* initialise report */
    report_bytes[0] = USB_DEVICE_COMMAND_AG_VOICE_RECOGNITION;
    report_bytes[1] = enable ? USB_DEVICE_DATA_AG_VOICE_RECOGNITION_ENABLE : USB_DEVICE_DATA_AG_VOICE_RECOGNITION_DISABLE;
    
    USB_DEBUG(("USB: Send Vendor Report (Report ID = %d) data_0 = [0x%x] data_1 = [0x%x]\n", USB_CONSUMER_REPORT_ID, report_bytes[0], report_bytes[1]));
        
    /* send USB Report */        
    if (UsbDeviceClassSendReport(USB_DEVICE_CLASS_TYPE_HID_CONSUMER_TRANSPORT_CONTROL, USB_CONSUMER_REPORT_ID, USB_CONSUMER_REPORT_SIZE, report_bytes) == usb_device_class_status_success)
        return TRUE;
    
    return FALSE;
}


/****************************************************************************
NAME    
    usb_get_speaker_sample_rate - 

DESCRIPTION
        Gets the configured USB sample rate for the speaker

RETURNS
    Returns the audio sample rate of 48000 if non LYNC build is enabled,
    0 if not set.
*/    
uint32 usb_get_speaker_sample_rate(void)
{
#ifdef USB_AUDIO_SAMPLE_RATE_SPEAKER
    return USB_AUDIO_SAMPLE_RATE_SPEAKER;
#endif
    
    return 0;
}
/*************************************************************************
NAME
    usb_get_configuration_data

DESCRIPTION
    This function gets the USB configuration structure data values.

RETURNS
    void

**************************************************************************/
static void usb_get_configuration_data(source_usb_configs_values_config_def_t *usb_data)
{
    source_usb_configs_values_config_def_t *usb_data_temp;

    if (configManagerGetReadOnlyConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (const void **)&usb_data_temp))
    {
        *usb_data = *usb_data_temp;
    }
    configManagerReleaseConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);
}
#ifndef ANALOGUE_INPUT_DEVICE    
/*************************************************************************
NAME
    usb_get_hid_keyboard_interface

DESCRIPTION
    Get USB HID interface type

RETURNS
    TRUE, if the HID keyboard interface is set.
    FALSE, if otherwise

**************************************************************************/
static bool usb_get_hid_keyboard_interface(void)
{
    bool HidKeybInterface = FALSE;

    source_usb_configs_values_config_def_t *usb_data;

    if (configManagerGetReadOnlyConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (const void **)&usb_data))
    {
        HidKeybInterface = usb_data->usbHidKeybInterface;
    }
    configManagerReleaseConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);

    return HidKeybInterface;
}
/*************************************************************************
NAME
    usb_get_hid_consumer_interface

DESCRIPTION
    Get USB HID Consumer interface type

RETURNS
    TRUE, if the HID consumer interface is set.
    FALSE, if otherwise

**************************************************************************/
bool usb_get_hid_consumer_interface(void)
{
    bool hid_consumer_interface = FALSE;

    source_usb_configs_values_config_def_t *usb_data;

    if (configManagerGetReadOnlyConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (const void **)&usb_data))
    {
        hid_consumer_interface = usb_data->usbHidConsumerInterface;
    }
    configManagerReleaseConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);

    return hid_consumer_interface;
}

/*************************************************************************
NAME
    usb_get_mic_interface

DESCRIPTION
    Get USB MIC interface type

RETURNS
    TRUE, if the mic interface is set.
    FALSE, if otherwise

**************************************************************************/
static bool usb_get_mic_interface(void)
{
    bool MicInterface = FALSE;

    source_usb_configs_values_config_def_t *usb_data;

    if (configManagerGetReadOnlyConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (const void **)&usb_data))
    {
        MicInterface = usb_data->usbMicInterface;
    }
    configManagerReleaseConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);

    return MicInterface;
}

/*************************************************************************
NAME
    usb_get_speaker_interface

DESCRIPTION
    Get USB Speaker interface type

RETURNS
    TRUE, if the speaker interface is set.
    FALSE, if otherwise

**************************************************************************/
static bool usb_get_speaker_interface(void)
{
    bool SpeakerInterface = FALSE;

    source_usb_configs_values_config_def_t *usb_data;

    if (configManagerGetReadOnlyConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (const void **)&usb_data))
    {
        SpeakerInterface = usb_data->usbSpeakerInterface;
    }
    configManagerReleaseConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);

    return SpeakerInterface;
}
/*************************************************************************
NAME
    usb_get_audioactive_timer

DESCRIPTION
    Helper function to Get the USB Audio Active timer.

RETURNS
    The value of usb audio active  timer as read from the config block section 

**************************************************************************/
uint16 usb_get_audioactive_timer(void)
{
    uint16 USBAudio_active_timer = 0;
    source_usb_configs_values_config_def_t *usb_data;

    if (configManagerGetReadOnlyConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (const void **)&usb_data))
    {
        USBAudio_active_timer = usb_data->USBAudioActive_s;
    }
    configManagerReleaseConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);
    return USBAudio_active_timer;
}
/****************************************************************************
NAME    
    usb_vol_mic_rounded - 

DESCRIPTION
     Convert USB Microphone volume to local volume level

RETURNS
    The current local volume level from the USB microphone volume.
*/
static uint16 usb_vol_mic_rounded(uint16 volume)
{
    int16 newVol = volume >> 8;
    
    if (newVol & 0x80)
    {
        /* sign extend */
        newVol |= 0xFF00;
    }

    if (volume == 0x8000)
    {
        return VOLUME_MIN_INDEX;
    }
    
    if ((newVol <= VOLUME_MAX_MIC_VALUE) &&
        (newVol >= VOLUME_MIN_MIC_VALUE))
    {
        return micVolumeTable[newVol];
    }

    return VOLUME_MIN_INDEX;

}


/****************************************************************************
NAME    
    usb_vol_speaker_rounded - 

DESCRIPTION
     Convert USB Speaker volume to local volume level

RETURNS
    The current local volume level from the USB speaker volume.
*/
static uint16 usb_vol_speaker_rounded(uint16 volume)
{
    /* convert USB volume to a volume index that can be sent to the remote side (0 - 16) */
    int16 newVol = volume >> 8;

    if (newVol & 0x80)
    {
        /* sign extend */
        newVol |= 0xFF00;
    }

    if (volume == 0x8000)
    {
        return VOLUME_MIN_INDEX;
    }
    
    if (volume == usb_audio_levels.speaker_max)
    {
        return VOLUME_MAX_INDEX;
    }
    
    if ((newVol <= VOLUME_MAX_SPEAKER_VALUE) &&
        (newVol >= VOLUME_MIN_SPEAKER_VALUE))
    {
        return (newVol - VOLUME_MIN_SPEAKER_VALUE);
    }

    return VOLUME_MIN_INDEX;

}

#endif
/*************************************************************************
NAME
    usb_get_fwd_press

DESCRIPTION
    Get USB FFWD Press

RETURNS
    TRUE, if the forward press is enabled
    FALSE, if otherwise

**************************************************************************/
static bool usb_get_fwd_press(void)
{
    return USB_RUNDATA.ffwd_press;
}
/*************************************************************************
NAME
    usb_get_rew_press

DESCRIPTION
    Get USB Rew Press

RETURNS
    TRUE, if the rewind press is enabled
    FALSE, if otherwise


**************************************************************************/
static bool usb_get_rew_press(void)
{
    return USB_RUNDATA.ffwd_press;
}
/*************************************************************************
NAME
    usb_set_fast_forward

DESCRIPTION
    Set USB ffwd_press value.

RETURNS
    void

**************************************************************************/
static void usb_set_fast_forward(bool status)
{
    USB_RUNDATA.ffwd_press = status;
}
/*************************************************************************
NAME
    usb_set_rewind

DESCRIPTION
    Set USB rewind value.

RETURNS
    void

**************************************************************************/
static void  usb_set_rewind(bool status)
{
    USB_RUNDATA.rew_press = status;
}
/*************************************************************************
NAME
    usb_set_audio_active_timer

DESCRIPTION
    Helper function to set the USB Audio Active timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool usb_set_audio_active_timer(uint16 timeout)
{
    source_usb_configs_values_config_def_t *usb_data = NULL;
    bool ret = FALSE;
    if (configManagerGetWriteableConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (void **)&usb_data, 0))
    {
        usb_data->USBAudioActive_s = timeout ;
        ret =  TRUE;
    }
    else
        ret =  FALSE;

    configManagerUpdateWriteableConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);
    return ret;
}
/*************************************************************************
NAME
    usb_get_media_repeat_timer

DESCRIPTION
    Helper function to Get the Media Repeat timer.

RETURNS
    The value of media repeat timer as read from the config block section 

**************************************************************************/
static uint16 usb_get_media_repeat_timer(void)
{
    uint16 Media_Repeat_timer = 0;
    source_usb_configs_values_config_def_t *media_repeat_timer = NULL;

    if (configManagerGetReadOnlyConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (const void **)&media_repeat_timer))
    {
        Media_Repeat_timer = media_repeat_timer->MediaRepeat_ms;;
    }
    configManagerReleaseConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);
    return Media_Repeat_timer;
}
/*************************************************************************
NAME
    usb_set_media_repeat_timer

DESCRIPTION
    Helper function to set the Media Repeat timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool usb_set_media_repeat_timer(uint16 timeout)
{
    source_usb_configs_values_config_def_t *media_repeat_timer = NULL;
    bool ret = FALSE;
    if (configManagerGetWriteableConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID, (void **)&media_repeat_timer, 0))
    {
        media_repeat_timer->MediaRepeat_ms= timeout ;
        ret =  TRUE;
    }
    else
         ret =  FALSE;

    configManagerUpdateWriteableConfig(SOURCE_USB_CONFIGS_VALUES_CONFIG_BLK_ID);
    return ret;
}
