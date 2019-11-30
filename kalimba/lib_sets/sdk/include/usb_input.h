/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file usb_input.h
    @brief USB audio input

    Handles USB audio input, coalesces USB audio frames into required size
    blocks with time stamps.
*/


#ifndef USB_INPUT_H
#define USB_INPUT_H

// Ensure these match the definitions in usb_audio.h
#define SAMPLE_RATE 48000  // Sampling rate in Hertz
#define SAMPLE_SIZE 2      // 2 bytes per sample
#define PACKET_RATE 1000   // Number of packets in 1 second
#define NUM_CHANNELS 2     // Number of channels (Mono: 1, Stereo: 2)

// Number of audio data bytes in a USB packet (for all channels)
#define USB_PACKET_LEN ((SAMPLE_RATE * SAMPLE_SIZE * NUM_CHANNELS) / PACKET_RATE)

// Samples (16 bit words) per channel per packet
#define USB_PACKET_SIZE (SAMPLE_RATE / PACKET_RATE)

#ifdef KCC

#include <core_library_c_stubs.h>
#include <md.h>
#include <stdbool.h>
#include <ttp.h>

typedef struct usb_input_params
{
    /** The size (in samples) for a meta-data packet for a single channel */
    int pcm_md_size;

    /** The USB port/cbuffer to read from. */
    tCbuffer *source;

    /** The left cbuffer to write to. */
    tCbuffer *left_output;

    /** The right cbuffer to write to. */
    tCbuffer *right_output;

    /** The meta-data list for left_output */
    md_list_t *left_pcm_md_list;

    /** The meta-data list for right_output */
    md_list_t *right_pcm_md_list;

    /** Length of "large" USB packet in bytes (e.g. 192) */
    unsigned packet_length;

    /** Gain shift applied to the samples on output */
    signed shift_amount;

    /** The TTP state structure used to timestamp the meta-data packets */
    struct ttp_state *ttp_state;

    /** The TTP settings used to timestamp the meta-data packets */
    struct ttp_settings *ttp_settings;

    /** Address of variable defining the system time source */
    unsigned *system_time_source;

    /* Internal state initialised by USB input */
    unsigned last_sync_byte;
    unsigned last_samples_copied;
    bool initialised;
    int samples_copied;
    unsigned zero_copies;
    uint24_t *left_read_ptr;   /* Boundary of last meta-data block */
    uint24_t *right_read_ptr;  /* Boundary of last meta-data block */
} usb_input_params_t;

extern void usb_input_copy_and_timestamp_frames(struct usb_input_params *params);

#else

// USB Stereo Input Copy constants
#define USB_INPUT_STEREO_SOURCE_PORT_FIELD          1  // [In] USB input port
#define USB_INPUT_STEREO_LEFT_CBUFFER_FIELD         2  // [In] Left audio output cbuffer
#define USB_INPUT_STEREO_RIGHT_CBUFFER_FIELD        3  // [In] Right audio output cbuffer
#define USB_INPUT_STEREO_LEFT_MD_FIELD              4  // [In] Left audio output metadata list
#define USB_INPUT_STEREO_RIGHT_MD_FIELD             5  // [In] Right audio output metadata list
#define USB_INPUT_STEREO_PACKET_LENGTH_FIELD        6  // [In] Length of "large" USB packet in bytes (e.g. 192)
#define USB_INPUT_STEREO_SHIFT_AMOUNT_FIELD         7  // [In] Gain shift applied to the samples on output
#define USB_INPUT_STEREO_TTP_STATE_FIELD            8  // [In] TTP state
#define USB_INPUT_STEREO_TTP_SETTINGS_FIELD         9  // [In] TTP settings
#define USB_INPUT_STEREO_SYSTEM_TIME_SOURCE_FIELD   10 // [In] The system time source
// Internal state
#define USB_INPUT_STEREO_LAST_HEADER_FIELD          11 // Previous sync byte received (0..0x7f)
#define USB_INPUT_STEREO_COPIED_SAMPLES_FIELD       12 // Samples copied

#endif // KCC

#define USB_INPUT_PARAMS_STRUC_SIZE            18

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(usb_input_params_t, USB_INPUT_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif 
