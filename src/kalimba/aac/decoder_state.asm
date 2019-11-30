// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.store_boundary_snapshot
//
// DESCRIPTION:
//    - Store the changing state of the decoder.
//
// INPUTS:
//    - I0 = pointer to state storing buffer
//
// OUTPUTS:
//    - I0 = Updated
//    - r0 = Offset from the beginning of the frame (in words)
//
// TRASHED REGISTERS:
//    - r1, r2
//
// *****************************************************************************
.MODULE $M.aacdec.store_boundary_snapshot;
   .CODESEGMENT AACDEC_STORE_BOUNDARY_SNAPSHOT_PM;
   .DATASEGMENT DM;

   $aacdec.store_boundary_snapshot:
   $aacdec.suspend_decoder:

   r1 = 1;
   r0 = M[$aacdec.read_frame_function]; // store as offset into read_frame_func_table (1 bit as just using first two entries)
   r0 = r0 - M[$aacdec.read_frame_func_table + 0];
   if NZ r0 = r1;
   r1 = r0;

   r0 = M[$aacdec.get_bitpos]; // 5 bits
   r0 = r0 AND 0x1F;
   r0 = r0 LSHIFT 1;
   r1 = r1 OR r0;

   r0 = M[$aacdec.sf_index]; // 4 bits
   r0 = r0 AND 0xF;
   r0 = r0 LSHIFT 6;
   r1 = r1 OR r0;

   r0 = M[$aacdec.channel_configuration]; // 4 bits
   r0 = r0 AND 0xF;
   r0 = r0 LSHIFT 10;
   r1 = r1 OR r0;

   r0 = M[$aacdec.audio_object_type]; // 5 bits
   r0 = r0 AND 0x1F;
   r0 = r0 LSHIFT 14;
   r1 = r1 OR r0;

   r0 = M[$aacdec.mp4_header_parsed]; // 1 bit
   r0 = r0 AND 0x1;
   r0 = r0 LSHIFT 19;
   r1 = r1 OR r0;

   r0 = M[$aacdec.mp4_header_parsed]; // 1 bit
   Null = r0 AND 0x6;
   if NZ jump not_first_snapshot;

      r0 = 3;
      r2 = 1;
      Null = M[$aacdec.mdat_size+0];
      if NZ jump mdat_size_done;
      r0 = r0 - r2;
      Null = M[$aacdec.mdat_size+1];
      if NZ jump mdat_size_done;
      r0 = r0 - r2;
      Null = M[$aacdec.mdat_size+2];
      if NZ jump mdat_size_done;
      r0 = r0 - r2;
      mdat_size_done:
      r0 = r0 LSHIFT 20;
      r1 = r1 OR r0;                  // 2 bit
      r2 = r0 LSHIFT -19;
      r0 = M[$aacdec.mp4_header_parsed];
      r0 = r0 OR r2;
      M[$aacdec.mp4_header_parsed] = r0;
      jump cont_saving_first_word;

   not_first_snapshot:
      r0 = M[$aacdec.mp4_header_parsed];
      r0 = r0 AND 0x6;
      r0 = r0 LSHIFT 19;
      r1 = r1 OR r0;
   cont_saving_first_word:
   M[I0, 1] = r1;

   // frame offset
   r0 = 0;

   r1 = M[$aacdec.mp4_header_parsed];
   Null = r1 AND 0x1;
   if Z rts;
   r1 = r1 LSHIFT -1;
   r2 = r1 AND 0x3;
   if Z rts;
      r1 = M[$aacdec.mdat_size+2];
      M[I0, 1] = r1;
   r2 = r2 - 1;
   if Z rts;
      r1 = M[$aacdec.mdat_size+1];
      M[I0, 1] = r1;
   r2 = r2 - 1;
   if Z rts;
      r1 = M[$aacdec.mdat_size+0];
      M[I0, 1] = r1;
   rts;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $aacdec.restore_boundary_snapshot
//
// DESCRIPTION:
//    - restore the state of the decoder at the beginning of the most recent
//      packet
//
// INPUTS:
//    - I0 = pointer to state storing buffer
//
// OUTPUTS:
//    - I0 = Updtated
//
// TRASHED REGISTERS:
//    - r0, r1, r2
//
// *****************************************************************************
.MODULE $M.aacdec.restore_boundary_snapshot;
   .CODESEGMENT AACDEC_RESTORE_BOUNDARY_SNAPSHOT_PM;
   .DATASEGMENT DM;

   $aacdec.restore_boundary_snapshot:
   $aacdec.resume_decoder:

   r0 = M[I0, 1];

   r1 = r0 AND 0x1;
   r1 = M[$aacdec.read_frame_func_table + r1];
   M[$aacdec.read_frame_function] = r1; // 1 bits
   r0 = r0 LSHIFT -1;

   r1 = r0 AND 0x1F;
   M[$aacdec.get_bitpos] = r1; // 5 bits
   r0 = r0 LSHIFT -5;

   r1 = r0 AND 0xF;
   M[$aacdec.sf_index] = r1; // 4 bits
   r0 = r0 LSHIFT -4;

   r1 = r0 AND 0xF;
   M[$aacdec.channel_configuration] = r1; // 4 bits
   r0 = r0 LSHIFT -4;

   r1 = r0 AND 0x1F;
   M[$aacdec.audio_object_type] = r1; // 5 bits
   r0 = r0 LSHIFT -5;

   r1 = r0 AND 0x1;
   M[$aacdec.mp4_header_parsed] = r1; // 1 bit

   r1 = M[$aacdec.mp4_header_parsed];
   Null = r1 AND 1;
   if Z rts;

   r1 = r0 LSHIFT -1;

   r2 = r1 AND 0x3;
   if Z rts;
      r1 = M[I0, 1];
      M[$aacdec.mdat_size+2] = r1;
   r2 = r2 - 1;
   if Z rts;
      r1 = M[I0, 1];
      M[$aacdec.mdat_size+1] = r1;
   r2 = r2 - 1;
   if Z rts;
      r1 = M[I0, 1];
      M[$aacdec.mdat_size+0] = r1;
   rts;

.ENDMODULE;
