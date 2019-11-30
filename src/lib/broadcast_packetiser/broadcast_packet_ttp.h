/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    broadcast_packet_ttp.h

DESCRIPTION
    Define the TTP used in the broadcast packet.

*/

#ifndef BROADCAST_PACKET_TTP_H_
#define BROADCAST_PACKET_TTP_H_

#include <rtime.h>

/*! The packet time-to-play byte representation */
typedef struct __ttp_bytes
{
    uint8 ttp[5];
} ttp_bytes_t;

/*! The packet time-to-play */
typedef struct __ttp
{
    /*! Base 32 bits */
    rtime_t base;
    /*! Extends the TTP to 40 bits */
    uint8 extension;
} ttp_t;

#endif
