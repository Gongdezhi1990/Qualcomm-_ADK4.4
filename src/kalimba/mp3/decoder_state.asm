// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_DECODER_STATE_INCLUDED
#define MP3DEC_DECODER_STATE_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.store_boundary_snapshot
//
// DESCRIPTION:
//    - Store the changing state of the decoder.
//
// INPUTS:
//    - I0 = pointer to state storing buffer
//
// OUTPUTS:
//    - I0 = Updated
//    - r0 = Offset from the beginning of the packet (in words)
//
// TRASHED REGISTERS:
//    - none
//
// *****************************************************************************
.MODULE $M.mp3dec.store_boundary_snapshot;
   .CODESEGMENT MP3DEC_STORE_BOUNDARY_SNAPSHOT_PM;
   .DATASEGMENT DM;

   $mp3dec.store_boundary_snapshot:
   $mp3dec.suspend_decoder:

   r0 = M[$mp3dec.get_bitpos];
   M[I0, 1] = r0;

   r0 = 0;

   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $mp3dec.restore_boundary_snapshot
//
// DESCRIPTION:
//    - restore the state of the decoder at the beginning of the most recent
//      frame
//
// INPUTS:
//    - I0 = pointer to state storing buffer
//
// OUTPUTS:
//    - I0 = Updtated
//
// TRASHED REGISTERS:
//    - r0
//
// *****************************************************************************
.MODULE $M.mp3dec.restore_boundary_snapshot;
   .CODESEGMENT MP3DEC_RESTORE_BOUNDARY_SNAPSHOT_PM;
   .DATASEGMENT DM;

   $mp3dec.restore_boundary_snapshot:
   $mp3dec.resume_decoder:

   // restore get_bitpos
   r0 = M[I0, 1];
   M[$mp3dec.get_bitpos] = r0;

   // reset granule and channel count to 0
   M[$mp3dec.current_grch] = Null;

   // empty the bit reservoir
#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.BITRES_FIELD];
#else
   r0 = &$mp3dec.bitres;
#endif

   M[$mp3dec.bitres_inptr] = r0;
   M[$mp3dec.bitres_outptr] = r0;

   r0 = 1<<23;
   M[$mp3dec.bitres_inbitmask] = r0;
   M[$mp3dec.bitres_outbitmask] = r0;

   rts;

.ENDMODULE;
#endif
