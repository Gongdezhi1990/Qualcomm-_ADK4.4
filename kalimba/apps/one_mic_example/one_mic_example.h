// *****************************************************************************
// Copyright (c) 2007 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef one_mic_example_LIB_H
#define one_mic_example_LIB_H


.CONST $one_mic_example.REINITIALIZE                    1;
.CONST $one_mic_example.VMMSG.SETMODE                   4;
.CONST $one_mic_example.VMMSG.READY                     5;
.CONST $one_mic_example.VM_SET_TONE_RATE_MESSAGE_ID     0x1072;         // Set the tone/prompt sampling rate from the VM
.CONST $one_mic_example.PLAY_BACK_FINISHED_MSG          0x1080;         // Indicate tone/prompt finished to VM
.CONST $one_mic_example.MESSAGE_REM_BT_ADDRESS          0x2001;

.CONST $one_mic_example.$PCM_END_DETECTION_TIME_OUT     40;

// System Modes
.CONST $one_mic_example.SYSMODE.PASSTHRU       0;

// Data block size
#if uses_16kHz
// Decoded WBS frames are 120 samples
.CONST $one_mic_example.NUM_SAMPLES_PER_FRAME  120;
.CONST $one_mic_example.JITTER                 32;
#else
.CONST $one_mic_example.NUM_SAMPLES_PER_FRAME  60;
.CONST $one_mic_example.JITTER                 16;
#endif



#endif
