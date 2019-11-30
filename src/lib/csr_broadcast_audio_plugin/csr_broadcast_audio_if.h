/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_broadcast_audio_if.h

DESCRIPTION
   
*/

#ifndef _CSR_BROADCAST_AUDIO_INTERFACE_H_
#define _CSR_BROADCAST_AUDIO_INTERFACE_H_

/* VM -> DSP messages */

/* DSP -> VM messages */

/* The DAC gain must be limited to 0 dB so that no distortion occurs and so the echo canceller works. */
#define VOLUME_0DB              0x0F


/* dsp message structure*/
typedef struct
{
    uint16 id;
    uint16 a;
    uint16 b;
    uint16 c;
    uint16 d;
} DSP_REGISTER_T;

#endif

