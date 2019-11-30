/*******************************************************************************
Copyright (c) 2015 Qualcomm Technologies International, Ltd.
 %%version
*******************************************************************************/

#ifndef APTX_API_HEADER_INCLUDED
#define APTX_API_HEADER_INCLUDED
// SPRINT custom AV data object
.CONST $sprint.CHUNK_INDEX_48K                                    0;
.CONST $sprint.CHUNK_INDEX_441K                                   1;

.CONST $sprint.ENCODER_OBJECT.CHUNK_INDEX_FIELD              0; // 0=48k, 1=44.1k
.CONST $sprint.ENCODER_OBJECT.IO_HANDLER_ADDR_FIELD          $sprint.ENCODER_OBJECT.CHUNK_INDEX_FIELD + 1;
.CONST $sprint.ENCODER_OBJECT.WATCHDOG_IO_HANDLER_ADDR_FIELD $sprint.ENCODER_OBJECT.IO_HANDLER_ADDR_FIELD + 1;
.CONST $sprint.ENCODER_OBJECT.STRUC_SIZE                     $sprint.ENCODER_OBJECT.WATCHDOG_IO_HANDLER_ADDR_FIELD + 1;

#endif
