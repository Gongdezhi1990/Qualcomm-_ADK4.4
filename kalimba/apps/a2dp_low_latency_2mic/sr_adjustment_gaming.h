// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef SRA_HEADER
#define SRA_HEADER


#ifdef FASTSTREAM_ENABLE
.CONST $sra.NO_ACTIVITY_PERIOD             30;  //the port is regarded inactive if no activity seen for this minumum number of interrupt
#else
.CONST $sra.NO_ACTIVITY_PERIOD             50;  //the port is regarded inactive if no activity seen for this minumum number of interrupt
#endif
.CONST $sra.ACTIVITY_PERIOD_BEFORE_START   100; //SRA counting starts if port has bee active during past ACTIVITY_PERIOD_BEFORE_START interrupts

 // mode definition for sra thread (runs in interrupt)
.CONST $sra.IDLE_MODE                      0;   // SRA in idle mode is wating for the port to becomes active, usually doesnt stay in idle mode
.CONST $sra.COUNTING_MODE                  1;   // in counting mode it just waits to reach the end of counting period (20 seconds), goes to idle then

 // mode definitions for rate_calc thread (runs in background)
.CONST $sra.RATECALC_IDLE_MODE             0;   // waits for sra thread to tag the start
.CONST $sra.RATECALC_START_MODE            1;   // waits until the codec passes the start tag
.CONST $sra.RATECALC_ADD_MODE              2;   // count the total number of PCM samples generated by CODEC since start time

.CONST $sra.TRANSIENT_SAVING_MODE          0;   // history has not get full yet
.CONST $sra.STEADY_SAVING_MODE             1;   // history is now full

#define SRA_MAXIMUM_RATE              0.005  // max value of SRA rate to compensate for drift between SRC & SNK(~+-250Hz)and jitter
#define SRA_AVERAGING_TIME            3      // in seconds (this is optimal value, smaller values might handle jitter better but might cause warping effect)
#define SRA_WAIT_TIME                 5        // Time to wait before calculating actual output port consumption (in seconds)

.CONST $sra.BUFF_SIZE 32;                        // history buffer size, must be a power of 2

 // sra structure fields, except for input fields, leave all initialized to zero
.CONST $sra.TAG_DURATION_FIELD                     0;  //input: duration of the rate calc (in number of interrupts)
.CONST $sra.CODEC_PORT_FIELD                        1;  //input: codec input port to check activity
.CONST $sra.CODEC_CBUFFER_TO_TAG_FIELD              2;  //input: codec input cbuffer to tag the times
.CONST $sra.AUDIO_CBUFFER_TO_TAG_FIELD              3;  //input: audio output cbuffer to count PCM samples
.CONST $sra.MAX_RATE_FIELD                          4;  //input: maximum possible rate
.CONST $sra.AUDIO_AMOUNT_EXPECTED_FIELD             5;  //input: amount of PCM sample expected to receive in one period (FS*TAG_DURATION_FIELD*interrupt_time)
.CONST $sra.TARGET_LEVEL_FIELD                      6;  //input: amount of PCM sample expected to receive in one period (FS*TAG_DURATION_FIELD*interrupt_time)
.CONST $sra.CODEC_DATA_READ_FIELD                   7;  //internal state, previous read address
.CONST $sra.NO_CODEC_DATA_COUNTER_FIELD             8;  //internal state, counter to keep no activity period
.CONST $sra.ACTIVE_PERIOD_COUNTER_FIELD             9;  //internal state, counter to store active period
.CONST $sra.MODE_FIELD                              10;  //internal state, sra thread mode
.CONST $sra.CODEC_CBUFFER_START_ADDR_TAG_FIELD      11; //internal state, start tag
.CONST $sra.CODEC_CBUFFER_END_ADDR_TAG_FIELD        12; //internal state, end tag
.CONST $sra.TAG_TIME_COUNTER_FIELD                  13; //internal state, tag time counter
.CONST $sra.RATECALC_MODE_FIELD                     14; //internal state, rate_calc thread mode
.CONST $sra.CODEC_CBUFFER_PREV_READ_ADDR_FIELD      15; //internal state, previous read address of codec cbuffer
.CONST $sra.AUDIO_CBUFFER_PREV_WRITE_ADDR_FIELD     16; //internal state, previous write address of audio cbuffer
.CONST $sra.AUDIO_TOTAL_DECODED_SAMPLES_FIELD       17; //internal state, total number of decoded samples so far
.CONST $sra.SRA_RATE_FIELD                          18; //output: target rate to be used by the sra operator
.CONST $sra.RESET_HIST_FIELD                        19; //internal state, request flag to reset the history
.CONST $sra.HIST_INDEX_FIELD                        20; //internal state, index to history buffer
.CONST $sra.SAVIN_STATE_FIELD                       21; //internal state, leave it initialized to zero
.CONST $sra.BUFFER_LEVEL_COUNTER_FIELD              22; //internal state, counter to calc average buffer level
.CONST $sra.BUFFER_LEVEL_ACC_FIELD                  23; //internal state, accumulator to average buffer level
.CONST $sra.FIX_VALUE_FIELD                         24; //internal state, fix value calculated based on buffer level to fix the final value
.CONST $sra.RATE_BEFORE_FIX_FIELD                   25; //internal state, rate calclated before adding fix value
.CONST $sra.LONG_TERM_RATE_FIELD                    26; //internal state
.CONST $sra.LONG_TERM_RATE_DETECTED_FIELD           27; //internal state
.CONST $sra.AVERAGE_LEVEL_FIELD                     28; //internal state
.CONST $sra.HIST_BUFF_FIELD                         29; //internal state


.CONST $sra.STRUC_SIZE ($sra.HIST_BUFF_FIELD+$sra.BUFF_SIZE);

.CONST $calc_actual_samples.RESET                           0;
.CONST $calc_actual_samples.WAIT                            1;
.CONST $calc_actual_samples.START                           2;
.CONST $calc_actual_samples.RUN                             3;

// Structure to control slave (e.g. I2S slave) output sample rate calculation
.CONST $calc_actual_samples.PORT_FIELD                      0; // Output port
.CONST $calc_actual_samples.STATE_FIELD                     1; // State
.CONST $calc_actual_samples.WAIT_DURATION_FIELD             2; // Wait duration (number of timer interrupt periods)
.CONST $calc_actual_samples.ACCUMULATOR_DURATION_FIELD      3; // Accumulator duration (number of timer interrupt periods)
.CONST $calc_actual_samples.ACCUMULATOR_FIELD               4; // Accumulated number of samples read from output port
.CONST $calc_actual_samples.PERIOD_COUNTER_FIELD            5; // Counter for timing measurement period
.CONST $calc_actual_samples.PREV_PORT_READ_PTR_FIELD        6; // Previous position of output port read pointer (used to calculate actual number of samples output)

.CONST $calc_actual_samples.STRUC_SIZE                      7;


#endif
