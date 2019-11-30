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
//    $aacdec.er_raw_data_block_eld
//
// DESCRIPTION:
//    Get a raw data block ELD
//
// INPUTS:
//    - r0 = channel configuration
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    - assume everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.er_raw_data_block_eld;
   .CODESEGMENT AACDEC_ER_RAW_DATA_BLOCK_ELD_PM;
   .DATASEGMENT DM;

   $aacdec.er_raw_data_block_eld:

   // push rLink onto stack
   $push_rLink_macro;

   // save byte alignment switch
   M[$aacdec.tmp + 2] = r1;

   // zero the SCE and CPE counters
   M[$aacdec.num_SCEs] = Null;
   M[$aacdec.num_CPEs] = Null;
   

  r1= 16; 
  r2 = 15;
  Null = M[$aacdec.frame_length_flag];
      if NZ r1 = r2;
      
   M[$aacdec.SBR_numTimeSlots_eld]=r1;
   M[$aacdec.SBR_numTimeSlotsRate_eld] = r1; 
   M[$aacdec.in_synth_loops] = r1;
  

   Null = r0 - 1;
   if LT jump $aacdec.possible_corruption;
   if GT jump ch_conf_2;
      call $aacdec.decode_sce_eld;
      jump get_ld_sbr_block;
   ch_conf_2:
   Null = r0 - 2;
   if GT jump $aacdec.possible_corruption;
      call $aacdec.decode_cpe_eld;

   get_ld_sbr_block:
      r0 = M[$aacdec.channel_configuration];
      Null = M[$aacdec.ld_sbr_present_flag];
        if NZ call $aacdec.er_low_delay_sbr_block; 
   
   // restore byte alignment switch
   // - for .mp4 file format the byte alignment is done here
   // - for .latm file format the byte alignment is done by $aacdec.payload_mux
   r1 = M[$aacdec.tmp + 2];
   Null = r1 - $aacdec.BYTE_ALIGN_ON;
   if EQ call $aacdec.byte_align;

   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;

#endif //AACDEC_ELD_ADDITIONS