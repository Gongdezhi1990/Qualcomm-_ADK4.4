// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_GETBITS_INCLUDED
#define CELT_GETBITS_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.get1byte
//
// DESCRIPTION:
//    reads  one byte from celt input cbuffer
//
// INPUTS:
//    - I0/L0 = buffer pointer to read the byte from
//    - r5 = pointer to the structure
//
// OUTPUTS:
//    - r1 = the byte read from the buffer
//    - I0 = buffer pointer is updated
//    - $celt.dec.frame_bytes_remained is also updated
// TRASHED REGISTERS:
//    r0
//
// NOTE: 
//    this function must return 0 when no byte is available to read
// *****************************************************************************
.MODULE $M.celt.get1byte;
   .CODESEGMENT CELT_GET1BYTE_PM;
   .DATASEGMENT DM;
   
   $celt.get1byte:
   
   r0 = M[$celt.dec.get_bytepos];           // calc amount of shift
   r0 = r0 * (-8) (int); 
   r1 = M[I0, 0];                           // r1 = the current word
   r1 = r1 LSHIFT r0;                       // shift current word
   r1 = r1 AND 0xFF;                        // extract only the desired bits
   r0 = M[$celt.dec.get_bytepos];
   r0 = r0 XOR 1;
   M[$celt.dec.get_bytepos] = r0;
   if Z jump no_p_update;
      r0 = M[I0,1]; // increment I0 to point to the next word
   no_p_update:
   r0 = Null + M[$celt.dec.frame_bytes_remained];
   if LE r1 = 0;
   r0 = r0 - 1;
   M[$celt.dec.frame_bytes_remained] = r0;  // update number of frame bits read
   rts;

.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.get1byte_from_end
//
// DESCRIPTION:
//    reads  one byte from end of buffer
//
// INPUTS:
//    - I1/L1 = buffer pointer to read the byte from
//    - r5 = pointer to the structure
//
// OUTPUTS:
//    - r1 = the byte read from the buffer
//    - I1 = buffer pointer is updated
//    - $celt.dec.frame_bytes_remained_reverse is also updated
// TRASHED REGISTERS:
//    r0
//
// NOTE: 
//    this function must return -1 when no byte is available to read
// *****************************************************************************
.MODULE $M.celt.get1byte_from_end;
   .CODESEGMENT CELT_GET1BYTE_FROM_END_PM;
   .DATASEGMENT DM;
   
   $celt.get1byte_from_end:
   r1 = -1;
   r0 = M[$celt.dec.frame_bytes_remained_reverse];
   r0 = r0 - 1;
   if NEG rts;
   M[$celt.dec.frame_bytes_remained_reverse] = r0;  // update number of frame bits read
   r0 = M[$celt.dec.get_bytepos_reverse];           // calc amount of shift
   if Z jump stay_in_this_word;
      r1 = M[I1, -1];
   stay_in_this_word:
   r0 = r0 XOR 1;
   M[$celt.dec.get_bytepos_reverse] = r0;
   r0 = r0 * (-8) (int); 
   r1 = M[I1, 0];                                   // r1 = the current word
   r1 = r1 LSHIFT r0;                               // shift current word
   r1 = r1 AND 0xFF;                                // extract only the desired bits
   rts;

.ENDMODULE;
#endif
