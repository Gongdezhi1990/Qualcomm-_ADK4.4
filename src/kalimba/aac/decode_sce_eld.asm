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
//    $aacdec.decode_sce
//
// DESCRIPTION:
//    Common function to get single channel element information
//    or read lfe channel element information (ELD version)
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume everything
//
// *****************************************************************************
.MODULE $M.aacdec.decode_sce_eld;
   .CODESEGMENT AACDEC_DECODE_SCE_ELD_PM;
   .DATASEGMENT DM;

   $aacdec.decode_sce_eld:
   $aacdec.decode_lfe_ce_eld:

   // push rLink onto stack
   $push_rLink_macro;

   // make sure that sample_rate is known
   // (ie. corrupt frames might get us here with out it being set)
   Null = M[$aacdec.sf_index];
   if NEG jump $aacdec.possible_corruption;

   // make sure we haven't had too many SCEs
   r0 = M[$aacdec.num_SCEs];
   r0 = r0 + 1;
   M[$aacdec.num_SCEs] = r0;
   Null = r0 - $aacdec.MAX_NUM_SCES;
   if GT jump $aacdec.possible_corruption;

   // set current ics and current spec pointers
   r4 = &$aacdec.ics_left;
   M[$aacdec.current_ics_ptr] = r4;
   r0 = &$aacdec.buf_left;
   M[$aacdec.current_spec_ptr] = r0;
   M[$aacdec.current_channel] = Null;

   // calc_sfbs_and_wingroups();
   call $aacdec.calc_sfb_and_wingroup;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump $aacdec.possible_corruption;
   
   #ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
      // -- reset the list of unpacked huffman tables --
      call $aacdec.huffman_reset_unpacked_list;
   #endif

   // individual_channel_stream_eld(0);
   M[$aacdec.common_window] = Null;
   call $aacdec.individual_channel_stream_eld;

   // Flag that ics_info has been called successfully
   r0 = 1;
   M[$aacdec.ics_info_done] = r0;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif //AACDEC_ELD_ADDITIONS