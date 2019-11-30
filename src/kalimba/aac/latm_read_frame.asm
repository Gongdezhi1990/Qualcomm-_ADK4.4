// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.latm_read_frame
//
// DESCRIPTION:
//    Read an latm frame (1 raw_data_block's worth per call)
//
// INPUTS:
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.latm_read_frame;
   .CODESEGMENT AACDEC_LATM_READ_FRAME_PM;
   .DATASEGMENT DM;

   $aacdec.latm_read_frame:

   // push rLink onto stack
   push rLink;

   .VAR saved_I0;
   .VAR saved_bitpos;
   .VAR saved_current_subframe;

   // default is no faults detected
   M[$aacdec.frame_underflow] = Null;
   M[$aacdec.frame_corrupt] = Null;
   M[$aacdec.possible_frame_corruption] = Null;

   // save some info to restore in case buffer under flow happened
   r0 = I0;
   M[saved_I0] = r0;
   r0 = M[$aacdec.get_bitpos];
   M[saved_bitpos] = r0;
   r0 = M[$aacdec.latm.current_subframe];
   M[saved_current_subframe] = r0;

#if defined(AACDEC_ELD_ADDITIONS) && defined(LOAS_AUDIO_SYNC_STREAM)
   // AudioSyncStream() flavour of LOAS present in the ISO reference encoded streams consists of:
   // - syncword                 11bits
   // - length information       13bits
   //
   // LOAS - Low Overhead Audio Stream
   r0 = 11;
   call $aacdec.getbits;
   Null = r1 - $aacdec.LATM_SYNC_WORD;
   if NE jump corrupt_file_error;
      r0 = 13;
      // skip audio_mux_element length
      call $aacdec.getbits;
#endif // AACDEC_ELD_ADDITIONS && LOAS_AUDIO_SYNC_STREAM

   // call audio_mux_element() with muxConfigPresent = 1
   r0 = 1;
   call $aacdec.audio_mux_element;

#ifdef AACDEC_ENABLE_LATM_GARBAGE_DETECTION
   // garbage test
   r0 = M[$aacdec.read_bit_count];
   Null = r0 -  ($aacdec.MAX_AAC_FRAME_SIZE_IN_BYTES*8*2);
   if POS jump garbage_detected;
#endif

   // check whether under flow has happened
   r0 = M[$aacdec.frame_num_bits_avail];
   r0 = r0 - M[$aacdec.read_bit_count];
   if NEG jump buffer_underflow_occured;
   
   // buffer underflow already checked, any possible_frame_corruption
   // will mean input stream error.
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump corrupt_file_error;


   // pop rLink from stack
   jump $pop_rLink_and_rts;

   buffer_underflow_occured:

      // restore saved context
      r0 = M[saved_I0];
      I0 = r0;
      r0 = M[saved_bitpos];
      M[$aacdec.get_bitpos] = r0;
      r0 = M[saved_current_subframe];
      M[$aacdec.latm.current_subframe] = r0;

      r0 = 1;
      M[$aacdec.frame_underflow] = r0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;

#ifdef AACDEC_ENABLE_LATM_GARBAGE_DETECTION
   garbage_detected:
   // we have detected garbage, discard everything in the
   // buffer, hopefully next chunck of data will be valid
   // This in practice should not happen
   #ifdef DEBUG_AACDEC
         r0 = M[$aacdec.frame_garbage_errors];
         r0 = r0 + 1;
         M[$aacdec.frame_garbage_errors] = r0;
   #endif
   r0 = M[$aacdec.frame_num_bits_avail];
   r0 = r0 - M[saved_bitpos];
   r0 = r0 + BITPOS_START;
#ifndef USE_PACKED_ENCODED_DATA
   r0 = r0 LSHIFT -4;
#else
   rMAC = 0;
   rMAC0 = r0;
   r0 = 24;
   Div = rMAC / r0;
   r0 = divResult;
#endif

   M0 = r0;
   r0 = M[saved_I0];
   I0 = r0;
   r0 = M[I0, M0];
#endif

   corrupt_file_error:
      M[$aacdec.latm.current_subframe] = Null;
      r0 = 1;
      M[$aacdec.frame_corrupt] = r0;
      // pop rLink from stack
      jump $pop_rLink_and_rts;

.ENDMODULE;

