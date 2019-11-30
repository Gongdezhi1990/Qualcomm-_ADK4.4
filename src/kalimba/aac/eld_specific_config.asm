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
//    $aacdec.eld_specific_config
//
// DESCRIPTION:
//    Read the Enhanced Low Delay specific config info
//
// INPUTS:
//    - I0 = buffer pointer to read words from
//
// OUTPUTS:
//    - I0 = buffer pointer to read words from (updated)
//
// TRASHED REGISTERS:
//    - r0, r2, r3, r10
//
// *****************************************************************************
.MODULE $M.aacdec.eld_specific_config;
   .CODESEGMENT AACDEC_ELD_SPECIFIC_CONFIG_PM;
   .DATASEGMENT DM;

   $aacdec.eld_specific_config:

   // push rLink onto stack
   $push_rLink_macro;

   // read frameLengthFlag
   call $aacdec.get1bit;
   M[$aacdec.frame_length_flag] = r1;

   // read aacSectionDataResilienceFlag
   call $aacdec.get1bit;
   // If aacSectionDataResilienceFlag == 1 the AAC section data is encoded 
   // with the Virtual Codebook 11 which we don't support.
   if NZ jump $aacdec.possible_corruption;

   // read aacScalefactorDataResilienceFlag
   call $aacdec.get1bit;
   // If aacScalefactorDataResilienceFlag == 1 the AAC scalefactor data is encoded
   // with the Reversible Variable Length Coding tool which we don't support.
   if NZ jump $aacdec.possible_corruption;

   // read aacSpectralDataResilienceFlag
   call $aacdec.get1bit;
   // If aacSpectralDataResilienceFlag == 1 the AAC spectral data is encoded
   // with Huffman Code Reordering tool which we don't support.
   if NZ jump $aacdec.possible_corruption;

   // read ld sbr present flag
   call $aacdec.get1bit;
   M[$aacdec.ld_sbr_present_flag] = r1;
   // replicate the behaviour of reference decoder by setting audioSpecificConfig -> sbr_present 
   // flag to the same value as ELDSpecificConfig->ld_sbr_present_flag
   M[$aacdec.sbr_present] = r1;

   if Z jump no_low_delay_sbr;

      // replicate the behaviour of reference decoder - set the extension AOT to SBR
      r0 = 5; 
      M[$aacdec.extension_audio_object_type] = r0;

      // read ld sbr sampling rate
      call $aacdec.get1bit;
      M[$aacdec.ld_sbr_sampling_rate] = r1;

      // read ld sbr crc flag
      call $aacdec.get1bit;
      M[$aacdec.ld_sbr_crc_flag] = r1;

      // read the low delay sbr header
      r0 = M[$aacdec.channel_configuration];
      call $aacdec.ld_sbr_header;
   no_low_delay_sbr:

   /* read extension type, eld length descriptor, first and second additional lengths
   while (eldExtType != ELDEXT_TERM) {        4b
      eldExtLen;                              4b
      len = eldExtLen;
      if (eldExtLen == 15) {
         eldExtLenAdd;                        8b
         len += eldExtLenAdd;
      }
      if (eldExtLenAdd == 255) {
         eldExtLenAddAdd;                    16b
         len += eldExtLenAddAdd;
      }
   }*/
   extension_loop:
      // initialise r10 here - as this loop exits it will contain len.
      r10 = 0; 
      call $aacdec.get4bits;
      Null = r1 - $aacdec.ELDEXT_TERM;
      if EQ jump end_extension_loop;
         // read eldExtLen
         call $aacdec.get4bits;
         r10 = r1;
         r1 = 0;

         Null = r10 - 15;
         // conditional read of eldExtLenAdd
         if EQ call $aacdec.get1byte;
         r2 = r1;
         r10 = r10 + r1;
         r1 = 0;

         // conditional read of eldExtLenAddAdd
         Null = r2 - 255;
         if EQ call $aacdec.get2bytes;
         r10 = r10 + r1;
      jump extension_loop;
   end_extension_loop:

   /* for(cnt=0; cnt<len; cnt++) {
      other_byte;                             8b
   } */

   // r10 is already set by the loop above (it can be 0)
   do discard_data;
      call $aacdec.get1byte;
   discard_data:

   r0 = $aacdec.DEFAULT_DELAY_512; 
   r1 = $aacdec.DEFAULT_DELAY_480;
   Null = M[$aacdec.frame_length_flag];
   if NZ r0 = r1;
   M[$aacdec.delay_shift] = r0;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif //AACDEC_ELD_ADDITIONS