// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef SBC_WBS_ONLY
#include "stack.h"

#include "sbc.h"

// *****************************************************************************

// output:  r6- get_bitpos of the location before the syncword or 99 indicating
//              sync word not found
//          I2- I0 of the location before the sync word or not used

// *****************************************************************************

.MODULE $M.sbcdec.find_sync;
   .CODESEGMENT SBCDEC_FIND_SYNC_PM;
   .DATASEGMENT DM;

   $sbcdec.find_sync:

   // push rLink onto stack
   $push_rLink_macro;

#if defined(PATCH_LIBS)
   push r1;
   LIBS_SLOW_SW_ROM_PATCH_POINT($sbcdec.FIND_SYNC_ASM.FIND_SYNC.PATCH_ID_0, r1)
   pop r1;
#endif

   // get byte aligned - we should be anyway but for robustness we force it
   call $sbcdec.byte_align;

   // r10 as input
   Null = M[r9 + $sbc.mem.FRAME_SYNC_SEARCH_DISABLE];
   if NZ jump skip_findsyncloop;
   DO findsyncloop;
      // backup the bitstream buffer pointer before reading next byte
skip_findsyncloop:

      r6 = M[r9 + $sbc.mem.GET_BITPOS_FIELD];

      I2 = I0;

      call $sbcdec.get8bits;
      Null = r1 - $sbc.SYNC_WORD;
      if Z jump found_sync;
   findsyncloop:

   // all available data are searched and sync word not found
   r6 = $sbc.SBC_NOT_SYNC;
   jump $pop_rLink_and_rts;



   found_sync:

   // restore bitstream buffer pointer to just before the sync word
   I0 = I2;

   M[r9 + $sbc.mem.GET_BITPOS_FIELD] = r6;


   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
