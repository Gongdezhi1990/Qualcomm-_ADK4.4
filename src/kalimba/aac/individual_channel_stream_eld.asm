// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifdef AACDEC_ELD_ADDITIONS

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.individual_channel_stream_eld
//
// DESCRIPTION:
//    Get an eld raw data block
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
.MODULE $M.aacdec.individual_channel_stream_eld;
   .CODESEGMENT AACDEC_INDIVIDUAL_CHANNEL_STREAM_ELD_PM;
   .DATASEGMENT DM;

   $aacdec.individual_channel_stream_eld:

   // push rLink onto stack
   $push_rLink_macro;

   // global_gain = getbits(8);
   r4 = M[$aacdec.current_ics_ptr];
   call $aacdec.get1byte;
   M[r4 + $aacdec.ics.GLOBAL_GAIN_FIELD] = r1;

   // for AAC ELD the window sequence is not read from the
   // bit stream and only long window sequences are allowed.
   r0 = $aacdec.ONLY_LONG_SEQUENCE;
   M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD] = r0;
   
   Null = M[$aacdec.common_window];
   if NZ jump no_max_sfb;
      call $aacdec.get6bits;
      M[r4 + $aacdec.ics.MAX_SFB_FIELD] = r1;
   no_max_sfb:

   // -- read section data --
   call $aacdec.section_data;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump $aacdec.possible_corruption;

   // -- read scalefactor data --
   call $aacdec.scalefactor_data;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump $aacdec.possible_corruption;
   
   // read tns_data_present
   call $aacdec.get1bit;
   if NZ call $aacdec.tns_data;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump $aacdec.possible_corruption;
   
   // -- read spectral data --
   call $aacdec.spectral_data;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump $aacdec.possible_corruption;
   jump done;
   
   done:
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif //AACDEC_ELD_ADDITIONS