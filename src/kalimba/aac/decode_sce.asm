// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.decode_sce
//
// DESCRIPTION:
//    Get single channel element information
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
.MODULE $M.aacdec.decode_sce;
   .CODESEGMENT AACDEC_DECODE_SCE_PM;
   .DATASEGMENT DM;

   $aacdec.decode_sce:

   // push rLink onto stack
   push rLink;

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

   // dummy = getbits(4);  //element_instance_tag
   call $aacdec.get4bits;

   // set current ics and current spec pointers
   r0 = &$aacdec.ics_left;
   M[$aacdec.current_ics_ptr] = r0;
 #ifndef AAC_USE_EXTERNAL_MEMORY
   r0 = &$aacdec.buf_left;
 #else 
   r0 = M[$aacdec.buf_left_ptr]; 
 #endif // AAC_USE_EXTERNAL_MEMORY
   M[$aacdec.current_spec_ptr] = r0;
   M[$aacdec.current_channel] = Null;


   #ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
      // -- reset the list of unpacked huffman tables --
      call $aacdec.huffman_reset_unpacked_list;
   #endif


   // individual_channel_stream(0);
   M[$aacdec.common_window] = Null;
   call $aacdec.individual_channel_stream;


   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
