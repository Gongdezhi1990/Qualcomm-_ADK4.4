// *****************************************************************************
// Copyright (c) 2009 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_SEEK_INCLUDED
#define MP3DEC_SEEK_INCLUDED

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.register_seeker
//
// DESCRIPTION:
//    API function for application to register the user seek utility for mp3 to
//    skip/scan data
//
// INPUTS:
//    - r0 = user seek utility function pointer
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - none
//
// NOTE:
//    The seeker utility function should take input r4(MSB) and r3(LSB:even) as
//    number bytes to seek.
//
// *****************************************************************************
.MODULE $M.mp3dec.register_seeker;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $mp3dec.register_seeker:

   M[$mp3dec.skip_function] = r0;
   rts;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $mp3dec.skip_through_file
//
// DESCRIPTION:
//    wrapper function to call the skip function
//
// INPUTS:
//    - r4 = MS byte of skip size
//    - r3 = LS 3 bytes of skip size
//    - r6 = external skip function pointer
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//    - assume everything
//
// *****************************************************************************
.MODULE $M.mp3dec.skip_through_file;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $mp3dec.skip_through_file:

   // push rLink onto stack
   $push_rLink_macro;

   // seeking is relative to read pointer, so move the read pointer
   // to the current word
   r5 = M[$mp3dec.codec_struc];
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   r1 = I0;
   call $cbuffer.set_read_address;

   // fix bitpos if needed
   // seek_value   bitpos      fix
   // ----------------------------------------------------------------
   // even          x          not required
   // odd           >7         bitpos-=8, seek_value-=1
   // odd           <8         bitpos+=8, seek_value+=1
   Null = r3 AND 1;
   if Z jump no_fix_needed;
      r0 = M[$mp3dec.get_bitpos];
      r0 = r0 - 8;
      if POS jump fix_finished;
         r3 = r3 + 1;
         r4 = r4 + carry;
         r0 = r0 + 16;
      fix_finished:
      M[$mp3dec.get_bitpos] = r0;
      r3 = r3 AND 0xFFFFFE;
   no_fix_needed:
   // decide whether seek is required
   Null = r4;
   if NZ jump seek_required;         // seek if negative or too big
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   call $cbuffer.calc_amount_data;
   r1 = r3 LSHIFT -1;
   Null = r0 - r1;
   if LE jump seek_required;         // seek if not enough data
      // just skip words in the input buffer
      M0 = r1;
      r0 = M[I0, M0];
      r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
      r1 = I0;
      call $cbuffer.set_read_address;
      jump seek_done;
   // call external seek function
   seek_required:
   call r6;

   // update to the new state
   r5 = M[$mp3dec.codec_struc];
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   call $cbuffer.get_read_address_and_size;
   I0 = r0;
   L0 = r1;

   seek_done:

   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;


#endif // MP3DEC_SEEK_INCLUDED