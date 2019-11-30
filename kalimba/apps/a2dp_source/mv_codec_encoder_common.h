// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef MV_CODEC_ENCODER_COMMON_H
#define MV_CODEC_ENCODER_COMMON_H

#include "cbuffer.h"

    // ** message ids **
    .CONST $mv.message_from_vm.CHANGE_MODE                  0x7300;
    .CONST $mv.message_to_vm.USB_IN_STATE                   0x7301;
    .CONST $mv.message_to_vm.USB_OUT_STATE                  0x7302;
    .CONST $mv.message_from_vm.CODEC_TYPE                   0x7303;
    .CONST $SPDIF_FULL_CHSTS_WORDS_MESSAGE_ID               0x1078;     // DSP to VM, to send the whole channel status bits

    .CONST $mv.message_from_vm.SET_RESOLUTION_MODES         0x7304;
    .CONST $mv.message_from_vm.SET_INPUT_RATE               0x7305;
    .CONST $mv.message_from_vm.SET_CODEC_RATE               0x7306;

    // ** modes **
    .CONST $mv.mode.IDLE_MODE                               0;
    .CONST $mv.mode.USB_MODE                                1;
    .CONST $mv.mode.ANALOG_MODE                             2;
    .CONST $mv.mode.SPDIF_MODE                              3;
    .CONST $mv.mode.I2S_MODE                                4;

    .CONST $mv.mode.TOTAL_MODES                             5;

    .CONST $RESOLUTION_MODE_16BIT                           16;         // 16bit resolution mode
    .CONST $RESOLUTION_MODE_24BIT                           24;         // 24bit resolution mode

    // ** copy results **
    .CONST $mv.block_copy.CAN_IDLE                          0;
    .CONST $mv.block_copy.DONT_IDLE                         1;

    // ** port states **
    .CONST $mv.usb_port.UNKNOWN                             -1;
    .CONST $mv.usb_port.STOPPED                             0;
    .CONST $mv.usb_port.MOVING                              1;

    // codec type definitions
    .CONST $mv.codec_type.SBC_CODEC                         0;
    .CONST $mv.codec_type.MP3_CODEC                         1;
    .CONST $mv.codec_type.FASTSTREAM_CODEC                  2;
    .CONST $mv.codec_type.FASTSTREAM_BIDIR_CODEC            3;
    .CONST $mv.codec_type.APTX_CODEC                        4;
    .CONST $mv.codec_type.APTX_LL_CODEC                     5;
    .CONST $mv.codec_type.APTX_LL_BIDIR_CODEC               6;
    .CONST $mv.codec_type.APTXHD_CODEC                      7;

    // ** define to make declaring buffers and structures easier **
    #define declare_cbuf_and_struc(buf,strc,sze)            \
    .VAR/DMCIRC buf[sze];                                   \
    .VAR strc[$cbuffer.STRUC_SIZE] =                        \
        LENGTH(buf),                                        \
        buf,                                                \
        buf;

    #define declare_cbuf_and_struc_inDM1(buf,strc,sze)      \
    .VAR/DM1CIRC buf[sze];                                  \
    .VAR strc[$cbuffer.STRUC_SIZE] =                        \
        LENGTH(buf),                                        \
        buf,                                                \
        buf;

    // USB Stereo Input Copy constants
    .CONST $mvdongle.STEREO_COPY_SOURCE_FIELD               0;
    .CONST $mvdongle.STEREO_COPY_LEFT_SINK_FIELD            1;
    .CONST $mvdongle.STEREO_COPY_RIGHT_SINK_FIELD           2;
    .CONST $mvdongle.STEREO_COPY_PACKET_LENGTH_FIELD        3;
    .CONST $mvdongle.STEREO_COPY_SHIFT_AMOUNT_FIELD         4;
    .CONST $mvdongle.STEREO_COPY_LAST_HEADER_FIELD          5;
    .CONST $mvdongle.STEREO_COPY_SILENCE_CNT_FIELD          6;
    .CONST $mvdongle.STEREO_COPY_STALL_FIELD                7;
    .CONST $mvdongle.STEREO_COPY_STRUC_SIZE                 8;

    .CONST $PEQ_COPY_MINIMUM                                25;         // based on 1000 audio copy timer period
    .CONST $PEQ_COPY_MAXIMUM                                50;         // based on 1000 audio copy timer period

#endif //.ifndef MV_CODEC_ENCODER_HEADER
