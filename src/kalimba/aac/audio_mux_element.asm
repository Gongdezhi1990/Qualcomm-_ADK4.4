// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.audio_mux_element
//
// DESCRIPTION:
//    Read the audio_mux_element block
//
// INPUTS:
//    - r0 = muxConfigPresent
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.audio_mux_element;
   .CODESEGMENT AACDEC_AUDIO_MUX_ELEMENT_PM;
   .DATASEGMENT DM;

   $aacdec.audio_mux_element:

   // push rLink onto stack
   push rLink;


   Null = M[$aacdec.latm.current_subframe];
   if NZ jump do_next_subframe;

   // if muxConfigPresent
   //    useSameStreamMux = getbits(1);
   //    if ~useSameStreamMux,
   //       stream_mux_config;
   //    end
   // end
   Null = r0;
   if Z jump mux_config_not_present;
      call $aacdec.get1bit;
      if Z call $aacdec.stream_mux_config;
      Null = M[$aacdec.possible_frame_corruption];
      if NZ jump $aacdec.possible_corruption;
   mux_config_not_present:


   // if (latm.audioMuxVersionA == 0)
   //    for i=1:latm.numSubFrames + 1,
   //       fprintf('\nBlock no: %d\n', rawblockno);
   //       payload_length_info;
   //       payload_mux;
   //       rawblockno = rawblockno + 1;
   //    end
   //    if (latm.otherDataPresent)
   //       for i=1:latm.otherDataLenBits,
   //          getbits(1);
   //       end
   //    end
   // else
   //   error('Dont support audioMuxVersionA != 0');
   // end
   //

   r0 = M[$aacdec.latm.audio_mux_version_a];
   if NZ jump $aacdec.possible_corruption;

   do_next_subframe:

      call $aacdec.payload_length_info;
      M[$aacdec.latm.mux_slot_length_bytes] = r4;

#ifdef AACDEC_ENABLE_LATM_GARBAGE_DETECTION
      // garbage test
      Null = r4 -  ($aacdec.MAX_AAC_FRAME_SIZE_IN_BYTES*2);
      if POS jump $aacdec.possible_corruption;
#endif

      call $aacdec.payload_mux;
      Null = M[$aacdec.possible_frame_corruption];
      if NZ jump $aacdec.possible_corruption;

      r0 = M[$aacdec.latm.current_subframe];
      r0 = r0 + 1;
      M[$aacdec.latm.current_subframe] = r0;
      Null = r0 - M[$aacdec.latm.num_subframes];
      if LE jump done_this_payload;

      M[$aacdec.latm.current_subframe] = Null;

      //    if (latm.otherDataPresent)
      //       for i=1:latm.otherDataLenBits,
      //          getbits(1);
      //       end
      //    end
      r10 = M[$aacdec.latm.other_data_len_bits];
      do loop;
         call $aacdec.get1bit;
         nop;
      loop:


      // byte_alignment;
      call $aacdec.byte_align;


   done_this_payload:

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

