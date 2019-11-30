// *****************************************************************************
// Copyright (c) 2003 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CODEC_DECODER_APTX_ACL_SPRINT_HEADER_INCLUDED
#define CODEC_DECODER_APTX_ACL_SPRINT_HEADER_INCLUDED

#include "../common/ports.h"
#include "music_example.h"

#define SIGNAL_DETECT_THRESHOLD                         (0.000316)  // detection level threshold (0.000316 = -70 dBFS)
#define SIGNAL_DETECT_TIMEOUT                           (600)       // length of silence before message sent to VM (600 = 10 minutes)

#ifdef PATCH_EFUSE
#define EFUSE
#endif

#ifdef EFUSE
// Define Feature mask 
#define   EFUSE_APTX_MASK       0x08
#define   EFUSE_APTX_LL_MASK    0x10
#define   EFUSE_SRC_MASK        0x20
#define   EFUSE_SHAREME_MASK    0x40
#define   EFUSE_TWS_MASK        0x80 
#endif // EFUSE


// 1ms is chosen as the interrupt rate for the codec input/output as this is a
// good compromise between not overloading the xap with messages and making
// sure that the xap side buffer is emptied relatively often.
#define TMR_PERIOD_CODEC_COPY                           1000

// 0.75ms is chosen as the interrupt rate for the audio input/output because:
// adc/dac mmu buffer is 256byte = 128samples
//                               - upto 8 sample fifo in voice interface
//                               = 120samples = 2.5ms @ 48KHz
// assume absolute worst case jitter on interrupts = 1.0ms
// hence we need it <=1.5ms between audio input/output interrupts
// We want absolute minimum latency so choose 0.75ms

// On the 8675 chip the adc/dac mmu buffer is 512bytes
// The above calculation would therefore also support 96kHz ANC operation
// For 192kHz ANC operation this must be lowered to prevent the output
// ports emptying
#define TMR_PERIOD_AUDIO_COPY                           750
#define TMR_PERIOD_HI_RATE_AUDIO_COPY                   750
#define ANC_192K_TMR_PERIOD_AUDIO_COPY                  500

// The timer period for copying tones.  We don't want to force the VM to fill
// up the tone buffer too regularly.
#define TMR_PERIOD_TONE_COPY                            16000
.CONST  $PCM_END_DETECTION_TIME_OUT                     (30000);        // minimum tone inactivity time before sending TONE END message


#define TONE_BUFFER_SIZE                                192    // for 8khz input and 16ms interrupt period

#define TARGET_CODEC_BUFFER_LEVEL                       280    // in WORDS

#define MAX_SAMPLE_RATE                                 48000
#define ABSOLUTE_MAXIMUM_CLOCK_MISMATCH_COMPENSATION    0.03     // this is absolute maximum value(3%), it is also capped to value received from vm
.CONST $OUTPUT_AUDIO_CBUFFER_SIZE                       ($music_example.NUM_SAMPLES_PER_FRAME + 2*(TMR_PERIOD_AUDIO_COPY * MAX_SAMPLE_RATE/1000000));
#define SRA_AVERAGING_TIME                              3               // in seconds (this is optimal value, smaller values migh handle jitter better but might cause warping effect)
#define SRA_MAXIMUM_RATE                                0.005           // max absolute value of SRA rate, this is to compensate for clock drift between SRC and SNK(~ +-250Hz)
                                                                        // and to some extent handle the jitter,

// A debug define to force the decoder to use a mono output
//#define FORCE_MONO_OUTPUT

// I/O configuration enum matches the PLUGIN type from the VM
.CONST  $INVALID_IO                                     -1;
.CONST  $SBC_IO                                         1;
.CONST  $MP3_IO                                         2;
.CONST  $AAC_IO                                         3;
.CONST  $FASTSTREAM_IO                                  4;
.CONST  $USB_IO                                         5;
.CONST  $APTX_IO                                        6;
.CONST  $APTX_ACL_SPRINT_IO                             7;
.CONST  $ANALOGUE_IO                                    8;
.CONST  $SPDIF_IO                                       9;
.CONST  $I2S_IO                                         10;
.CONST  $APTXHD_IO                                      11;
.CONST  $AAC_ELD_IO                                     12;

// Output interface types
.CONST $OUTPUT_INTERFACE_TYPE_NONE                      0;              // No audio output port control
.CONST $OUTPUT_INTERFACE_TYPE_DAC                       1;              // Output to internal DACs
.CONST $OUTPUT_INTERFACE_TYPE_I2S                       2;              // Output to I2S interface
.CONST $OUTPUT_INTERFACE_TYPE_SPDIF                     3;              // Output to spdif interface

.CONST $ANC_NONE                                        0;              // Standard operation no ANC output resampling
.CONST $ANC_96K                                         1;              // ANC output resampling to 96kHz
.CONST $ANC_192K                                        2;              // ANC output resampling to 192kHz
.CONST $ANC_MASK                                        3;              // Mask for ANC output resampling control

.CONST $RESOLUTION_MODE_16BIT                           16;             // 16bit resolution mode
.CONST $RESOLUTION_MODE_24BIT                           24;             // 24bit resolution mode

#define VM_DAC_RATE_MESSAGE_ID                          0x7050          // Obsoleted message use VM_SET_DAC_RATE_MESSAGE_ID

#define VM_SET_DAC_RATE_MESSAGE_ID                      0x1070          // Set the DAC sampling rate (plus other rate match params)
#define VM_SET_CODEC_RATE_MESSAGE_ID                    0x1071          // Set the codec sampling rate
#define VM_SET_TONE_RATE_MESSAGE_ID                     0x1072          // Set the tone sampling rate

#define PLAY_BACK_FINISHED_MSG                          0x1080
#define UNSUPPORTED_SAMPLING_RATES_MSG                  0x1090
#define VM_APTX_LL_PARAMS_MESSAGE1_ID                   0x1036
#define VM_APTX_LL_PARAMS_MESSAGE2_ID                   0x1037

.CONST  $AUDIO_IF_MASK                                  (0x00ff);       // Mask to select the audio i/f info
.CONST  $LOCAL_PLAYBACK_MASK                            (0x0100);       // Mask to select the local playback control bit

// Port used for CODEC inputs
.CONST  $CODEC_IN_PORT                                  ($cbuffer.READ_PORT_MASK + 2);

// Port used for tone inputs
.CONST  $TONE_IN_PORT                                   (($cbuffer.READ_PORT_MASK | $cbuffer.FORCE_PCM_AUDIO)  + 3);

#endif
