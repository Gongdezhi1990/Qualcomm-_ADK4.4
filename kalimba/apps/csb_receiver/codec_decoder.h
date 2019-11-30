// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN 4.2
//
// DESCRIPTION
//    Decoder for an audio playing device (non USB)
//
// *****************************************************************************

#define TIMER_PERIOD 1000

// includes
#include "core_library.h"
#include "cbops_library.h"
#include "codec_library.h"

#include <erasure_code_input.h>
#include "music_manager_config.h"
#include <csb_input.h>
#include <csb_decoder.h>
#include <audio_out.h>
#include <frame_info.h>
#include <md.h>
#include <scm.h>
#include <csb_aesccm.h>
#include <system_time.h>
#include <sr.h>
#include <broadcast_msg_interface.h>


// TONE_MIXER
#include "frame_sync_stream_macros.h"



.CONST $MESSAGE_AUDIO_SAMPLE_RATE   		KALIMBA_MSG_AUDIO_SAMPLE_RATE;
.CONST $MESSAGE_CSB_SAMPLE_RATE_CHANGED     KALIMBA_MSG_CSB_SAMPLE_RATE_CHANGED;
.CONST $MESSAGE_LED_COLOUR                  KALIMBA_MSG_LED_COLOUR;
.CONST $MESSAGE_AUDIO_STATUS                KALIMBA_MSG_AUDIO_STATUS;
.CONST $MESSAGE_SET_VOLUME                  KALIMBA_MSG_SET_VOLUME;
.CONST $MESSAGE_VOLUME_IND                  KALIMBA_MSG_VOLUME_IND;
.CONST $MESSAGE_SET_KEY                     KALIMBA_MSG_SET_KEY;
.CONST $MESSAGE_SET_IV                      KALIMBA_MSG_SET_IV;
.CONST $MESSAGE_SET_FIXED_IV                KALIMBA_MSG_SET_FIXED_IV;
.CONST $MESSAGE_BROADCAST_STATUS            KALIMBA_MSG_BROADCAST_STATUS;
.CONST $MESSAGE_BROADCAST_CONFIG            KALIMBA_MSG_BROADCAST_CONFIG;
.CONST $MESSAGE_SET_STREAM_ID               KALIMBA_MSG_SET_STREAM_ID;
.CONST $MESSAGE_SET_CELT_CONFIG             KALIMBA_MSG_SET_CELT_CONFIG;
.CONST $MESSAGE_SCM_SEGMENT_IND             KALIMBA_MSG_SCM_SEGMENT_IND;
.CONST $MESSAGE_SCM_SEGMENT_EXPIRED         KALIMBA_MSG_SCM_SEGMENT_EXPIRED;
.CONST $MESSAGE_AFH_CHANNEL_MAP_CHANGE_PENDING KALIMBA_MSG_AFH_CHANNEL_MAP_CHANGE_PENDING;


   // ** setup ports that are to be used **
.CONST  $AUDIO_OUT_LEFT_PORT_NUMBER 0;
.CONST  $AUDIO_OUT_RIGHT_PORT_NUMBER 1;
.CONST  $CSB_IN_PORT_NUMBER 0;
.CONST  $AUDIO_LEFT_OUT_PORT    ($cbuffer.WRITE_PORT_MASK + $AUDIO_OUT_LEFT_PORT_NUMBER);
.CONST  $AUDIO_RIGHT_OUT_PORT   ($cbuffer.WRITE_PORT_MASK + $AUDIO_OUT_RIGHT_PORT_NUMBER);
.CONST  $CSB_IN_PORT            ($cbuffer.READ_PORT_MASK  + $CSB_IN_PORT_NUMBER + $cbuffer.FORCE_8BIT_WORD);

#define VM_SET_DAC_RATE_MESSAGE_ID                   0x1070   // Set the DAC sampling rate
#define VM_SET_CODEC_RATE_MESSAGE_ID                 0x1071   // Set the codec sampling rate
#define UNSUPPORTED_SAMPLING_RATES_MSG               0x1090

.CONST $EQ_OUT_CBUFFER_SIZE                             513;  // (Number of input samples + 1);
.CONST $TEMP_BUFF_SIZE                                  977;  // (Number of Input Samples in frame + 1) /(int_ration_s1 + frac_ratio_s1)
                                                              //  = (512 + 1) /(0 + 0.525000) = 977.142
// TONE_MIXER
.CONST  $TONE_IN_PORT_NUMBER     3;
.CONST  $TONE_IN_PORT                (($cbuffer.READ_PORT_MASK | $cbuffer.FORCE_PCM_AUDIO) + $TONE_IN_PORT_NUMBER);

// added for tone mixer
#define VM_SET_TONE_RATE_MESSAGE_ID                     0x1072 // Set the tone sampling rate
#define PLAY_BACK_FINISHED_MSG                          0x1080

#define DAC_OUT_CBUFFER_SIZE                            1116   // Number of input sample * (max worst case resampling ratio) * 2 + 1 
                                                               // = 512*48/44.1*2+1

#define TONE_SAMPLE_RATE                                 8000  // for 8khz
#define TONE_BUFFER_SIZE                                 129   // for 8khz
  
// SINGLE_TIMER
#define TMR_PERIOD_TONE_COPY                             TIMER_PERIOD
   
   
.CONST  $MAX_AUDIO_PAUSE_COUNT                          100;
   
   
   
.CONST  $PCM_END_DETECTION_TIME_OUT                     (30000);        // minimum tone inactivity time before sending TONE END message

