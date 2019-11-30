// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN 4.2
//
// *****************************************************************************

// *****************************************************************************
// DESCRIPTION
//    Broadcast Audio Master Application
//
// *****************************************************************************

.CONST $TIMER_PERIOD    1000;

// includes
#include "core_library.h"
#include "cbops_library.h"
#include "codec_library.h"

#if defined(SELECTED_DECODER_AAC) || defined(SELECTED_MULTI_DECODER)
#include "aac_library.h"
#include "aac_consts.h"
#include <aac.h>
#endif

#include "malloc.h"
#include "music_manager_config.h"
#include "frame_sync_stream_macros.h"

#include <cbuffer_defines.h>
#include <md.h>
#include <audio_out.h>
#include <ttp.h>
#include <scm.h>
#include <csb_encoder.h>
#include <csb_output.h>
#include <erasure_code_output.h>
#include <analogue_input.h>
#include <usb_input.h>
#include <rtp_input.h>
#include <rtp_input_decoder.h>
#include <csb_aesccm.h>
#include <system_time.h>
#include <broadcast_msg_interface.h>



.CONST $MESSAGE_AUDIO_SAMPLE_RATE   KALIMBA_MSG_AUDIO_SAMPLE_RATE;
.CONST $MESSAGE_CONFIGURE_SCMS_T    KALIMBA_MSG_SET_CONTENT_PROTECTION;
.CONST $MESSAGE_LED_COLOUR          KALIMBA_MSG_LED_COLOUR;
.CONST $MESSAGE_AUDIO_STATUS        KALIMBA_MSG_AUDIO_STATUS;
.CONST $MESSAGE_SET_LATENCY         KALIMBA_MSG_SET_LATENCY;
.CONST $MESSAGE_SET_VOLUME          KALIMBA_MSG_SET_VOLUME;
.CONST $MESSAGE_RANDOM_BITS_REQ     KALIMBA_MSG_RANDOM_BITS_REQ;
.CONST $MESSAGE_RANDOM_BITS_RESP    KALIMBA_MSG_RANDOM_BITS_RESP;
.CONST $MESSAGE_SET_KEY             KALIMBA_MSG_SET_KEY;
.CONST $MESSAGE_SET_IV              KALIMBA_MSG_SET_IV;
.CONST $MESSAGE_SET_FIXED_IV        KALIMBA_MSG_SET_FIXED_IV;
.CONST $MESSAGE_BROADCAST_STATUS    KALIMBA_MSG_BROADCAST_STATUS;
.CONST $MESSAGE_SET_TTP_EXTENSION   KALIMBA_MSG_SET_TTP_EXTENSION;
.CONST $MESSAGE_SET_CSB_TIMING      KALIMBA_MSG_SET_CSB_TIMING;
.CONST $MESSAGE_SET_STREAM_ID       KALIMBA_MSG_SET_STREAM_ID;
.CONST $MESSAGE_SET_CELT_CONFIG     KALIMBA_MSG_SET_CELT_CONFIG;
.CONST $MESSAGE_SET_SCM_SEGMENT_REQ KALIMBA_MSG_SET_SCM_SEGMENT_REQ;
.CONST $MESSAGE_SET_SCM_SEGMENT_CFM KALIMBA_MSG_SET_SCM_SEGMENT_CFM;
.CONST $MESSAGE_SCM_SHUTDOWN_REQ    KALIMBA_MSG_SCM_SHUTDOWN_REQ;
.CONST $MESSAGE_SCM_SHUTDOWN_CFM    KALIMBA_MSG_SCM_SHUTDOWN_CFM;
.CONST $MESSAGE_AFH_CHANNEL_MAP_CHANGE_PENDING KALIMBA_MSG_AFH_CHANNEL_MAP_CHANGE_PENDING;



   // ** setup ports that are to be used **
.CONST  $AUDIO_OUT_LEFT_PORT_NUMBER  0;
.CONST  $AUDIO_OUT_RIGHT_PORT_NUMBER 1;
.CONST  $CSB_OUT_PORT_NUMBER 2;


.CONST  $RTP_IN_PORT_NUMBER 0;
.CONST  $USB_IN_PORT_NUMBER 4;
.CONST  $AUDIO_IN_LEFT_PORT_NUMBER  1;
.CONST  $AUDIO_IN_RIGHT_PORT_NUMBER 2;
.CONST  $TONE_IN_PORT_NUMBER        3;
.CONST  $TONE_IN_PORT                (($cbuffer.READ_PORT_MASK | $cbuffer.FORCE_PCM_AUDIO) + $TONE_IN_PORT_NUMBER);


.CONST  $AUDIO_LEFT_OUT_PORT    ($cbuffer.WRITE_PORT_MASK + $AUDIO_OUT_LEFT_PORT_NUMBER);
.CONST  $AUDIO_RIGHT_OUT_PORT   ($cbuffer.WRITE_PORT_MASK + $AUDIO_OUT_RIGHT_PORT_NUMBER);
.CONST  $CSB_OUT_PORT           ($cbuffer.WRITE_PORT_MASK + $CSB_OUT_PORT_NUMBER + $cbuffer.FORCE_8BIT_WORD);
.CONST  $RTP_IN_PORT            ($cbuffer.READ_PORT_MASK  + $RTP_IN_PORT_NUMBER + $cbuffer.FORCE_8BIT_WORD);
.CONST  $USB_IN_PORT            ($cbuffer.READ_PORT_MASK  + $USB_IN_PORT_NUMBER);
.CONST  $AUDIO_LEFT_IN_PORT     ($cbuffer.READ_PORT_MASK + $AUDIO_IN_LEFT_PORT_NUMBER);
.CONST  $AUDIO_RIGHT_IN_PORT    ($cbuffer.READ_PORT_MASK + $AUDIO_IN_RIGHT_PORT_NUMBER);

#define VM_SET_DAC_RATE_MESSAGE_ID                   0x1070   // Set the DAC sampling rate
#define VM_SET_CODEC_RATE_MESSAGE_ID                 0x1071   // Set the codec sampling rate
#define UNSUPPORTED_SAMPLING_RATES_MSG               0x1090

.CONST $EQ_OUT_CBUFFER_SIZE                             513;  // (Number of input samples + 1);
.CONST $TEMP_BUFF_SIZE                                  977;  // (Number of Input Samples in frame + 1) /(int_ration_s1 + frac_ratio_s1)
                                                              //  = (512 + 1) /(0 + 0.525000) = 977.142

#define VM_SET_TONE_RATE_MESSAGE_ID                   0x1072  // Set the tone sampling rate
#define PLAY_BACK_FINISHED_MSG                        0x1080
#define DAC_OUT_CBUFFER_SIZE                            1116  // Number of input sample * (max worst case resampling ratio) * 2 + 1 
                                                              // = 512*48/44.1*2+1

#define TONE_SAMPLE_RATE                                8000  // for 8khz input and 16ms interrupt period
#define TONE_BUFFER_SIZE                                 129  // for 8khz
  
// SINGLE_TIMER
#define TMR_PERIOD_TONE_COPY                   $TIMER_PERIOD
.CONST  $MAX_AUDIO_PAUSE_COUNT                          100;  
.CONST  $PCM_END_DETECTION_TIME_OUT                 (30000);  // minimum tone inactivity time before sending TONE END message

// codec type, list may expand, only include what's needed for now
// I/O configuration enum matches the PLUGIN type from the VM
// music plugin message from VM 
#ifdef  SELECTED_MULTI_DECODER
#define SETPLUGIN_MESSAGE_ID        					0x1020
.CONST  $INVALID_CONFIG                                -1;
.CONST  $SBC_IO                                         1;
.CONST  $AAC_IO                                         3;
#endif  // SELECTED_MULTI_DECODER

