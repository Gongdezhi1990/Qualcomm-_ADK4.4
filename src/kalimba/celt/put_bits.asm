// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_PUTBITS_INCLUDED
#define CELT_PUTBITS_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.put1byte
//
// DESCRIPTION:
//    writes one byte to celt output cbuffer
//
// INPUTS:
//    - I0/L0 = buffer pointer to write the byte to
//    - r5 = pointer to the structure
//    - r1 = byte to write
//
// OUTPUTS:
//    - I0 = buffer pointer is updated
//    - $celt.enc.frame_bytes_remained is also updated
// TRASHED REGISTERS:
//    r0
//
// NOTE: 
//    this function must return immidiately if no space is available for new byte 
// *****************************************************************************
.MODULE $M.celt.put1byte;
   .CODESEGMENT CELT_PUT1BYTE_PM;
   .DATASEGMENT DM;
   $celt.put1byte:
   r0 = Null + M[$celt.enc.frame_bytes_remained];
   if LE rts;
   r0 = r0 - 1;
   M[$celt.enc.frame_bytes_remained] = r0;   
   r0 = M[$celt.enc.put_bytepos];
   r0 = r0 XOR 1;
   M[$celt.enc.put_bytepos] = r0;
   if NZ jump anotherword;                // see if another word needs to be written
      r1 = r1 LSHIFT 8;                  // shift new data to the left
      r0 = M[I0, 0];
      r0 = r0 AND 0xFF;
      r0 = r0 OR r1;
      r1 = r1 LSHIFT -8;
      M[I0, 0] = r0;
      rts;
   anotherword:
   r0 = M[I0, 0];
   r0 = r0 AND 0xFF00;
   r0 = r0 OR r1;
   M[I0, 1] = r0;
   rts;

.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.put1byte_to_end
//
// DESCRIPTION:
//    writes one byte to end of buffer
//
// INPUTS:
//    - I1/L1 = buffer pointer to write the byte into
//    - r5 = pointer to the structure
//    - r1 = input byte
// OUTPUTS:
//    - I1 = buffer pointer is updated
//    - $celt.enc.frame_bytes_remained_reverse is also updated
// TRASHED REGISTERS:
//    r0
//
// NOTE: 
//    this function must return immidiately if no space is available for new byte 
// *****************************************************************************
.MODULE $M.celt.put1byte_to_end;
   .CODESEGMENT CELT_PUT1BYTE_TO_END_PM;
   .DATASEGMENT DM;
   $celt.put1byte_to_end:
   r0 = M[$celt.enc.frame_bytes_remained_reverse];
   r0 = r0 - 1;
   if NEG rts;
   M[$celt.enc.frame_bytes_remained_reverse] = r0;  // update number of frame bits read
   r0 = M[$celt.enc.put_bytepos_reverse];
   r0 = r0 XOR 1;
   M[$celt.enc.put_bytepos_reverse] = r0;
   if Z jump anotherword;                // see if another word needs to be written
      r0 = M[I1, 0];
      r1 = r1 LSHIFT 8;
      r0 = r0 AND 0xFF;
      r0 = r0 OR r1;
      M[I1, 0] = r0;
      rts;
   anotherword:
   r0 = M[I1, -1];
   r0 = M[I1, 0];
   r0 = r0 AND 0xFF00;
   r0 = r0 OR r1;
   M[I1, 0] = r0;
   rts;
.ENDMODULE;
#endif
