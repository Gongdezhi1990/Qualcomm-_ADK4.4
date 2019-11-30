// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "core_library.h"

/* Outputs Kalimba log messages to a cbuffer. */

// *****************************************************************************
// MODULE:
//    C code
//
// DESCRIPTION:
//    Write an arbitrary block of data to a log buffer with a message
//    id/length header. Can be called from a C function.
//
//
// INPUTS:
//    - r0 = 8 bit message id
//    - r1 = pointer to the message
//    - r2 = length of the message in words
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//   r1, r2, r3, r10, I4, I0, L0
//
// *****************************************************************************
.MODULE $M.cbuffer_log;
    .CODESEGMENT CBUFFER_LOG_PM;
    .DATASEGMENT CBUFFER_LOG_DM;
    .VAR $cbuffer_log.overflow;

    // debug cbuffer to record arbitrary messages
    .VAR/DMCIRC $debug.log[4096];
    .VAR $debug.log_cbuffer_struc[$cbuffer.STRUC_SIZE] =
        LENGTH($debug.log),         // size
        &$debug.log,                // read pointer
#ifndef BASE_REGISTER_MODE
        &$debug.log;                // write pointer
#else
        &$debug.log,                // write pointer
        0 ...;
#endif

$_cbuffer_log:
    $push_rLink_macro;
    pushm <I0, I4>;
    push L0;
    pushm <r5, r6, r8>;

    r5 = r0;
    r6 = r1;
    call $interrupt.block;
    r0 = r5;
    r1 = r6;

    /* Length including header */
    r8 = r2;

    // Combined message id and length
    r3 = r0 LSHIFT 16;
    r3 = r3 + r2;

    r0 = &$debug.log_cbuffer_struc;
    call cbuffer_log_write_block;

    call $interrupt.unblock;

    popm <r5, r6, r8>;
    pop L0;
    popm <I0, I4>;
    jump $pop_rLink_and_rts;

cbuffer_log_write_block:
    r2 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
    I0 = r2;
    r2 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r2;

    // Test if cbuffer has enough space to complete the write
    r2 = M[r0 + $cbuffer.READ_ADDR_FIELD];
    I4 = r2;

    // calculate the amount of space
    I4 = I4 - I0;
    if LE I4 = I4 + L0;

    // always say it's 3 less so that buffer never gets totally filled up
    // including the header word and timestamp.
    // When the buffer is full drop new log messages.
    I4 = I4 - 3;
    I4 = I4 - r8;
    if GE jump cbuffer_log_write_header;
    r0 = M[$cbuffer_log.overflow];
    r0 = r0 + r1;
    M[$cbuffer_log.overflow] = r0;
    L0 = 0;
    rts;

cbuffer_log_write_header:
    r2 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r2;
    r2 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
    I0 = r2;
    // Every log has a timestamp
    r2 = M[$TIMER_TIME];
    M[I0, 1] = r2;
    // Write header
    M[I0, 1] = r3;
    r2 = I0;
    M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r2;
    L0 = 0;

    // r8 - length
    // r1 = pointer to data
    // r0 - pointer to cbuff
cbuffer_log_write_body:
    r2 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
    I0 = r2;
    r2 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r2;

    I4 = r1;
    r10 = r8 - 1;
    r1 = M[I4,1];
    do write_block_loop;
        M[I0,1] = r1, r1 = M[I4,1];
    write_block_loop:
    M[I0,1] = r1;
    L0 = 0;
    // Update the write address
    r1 = I0;
    M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r1;
    rts;
.ENDMODULE;
