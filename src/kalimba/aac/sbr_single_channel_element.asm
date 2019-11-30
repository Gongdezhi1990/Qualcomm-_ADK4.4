// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_single_channel_element
//
// DESCRIPTION:
//    Get sbr single channel element information
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r8, r10, I1-I7, M0-M3
//    - L5 set to zero
//    - $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_single_channel_element;
   .CODESEGMENT AACDEC_SBR_SINGLE_CHANNEL_ELEMENT_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_single_channel_element:

   // push rLink onto stack
   push rLink;

   r0 = 1;
   M[$aacdec.sbr_info + $aacdec.SBR_HF_reconstruction] = r0;

   // SBR_bs_data_extra
   call $aacdec.get1bit;

   // if(SBR_bs_data_extra)
   if NZ call $aacdec.get4bits;

   // ch
   r5 = 0;
#ifdef AACDEC_ELD_ADDITIONS
    call $aacdec.sbr_ld_grid;
#else 
    call $aacdec.sbr_grid;
#endif 

   call $aacdec.sbr_dtdf;

   call $aacdec.sbr_invf;

   call $aacdec.sbr_envelope;

   call $aacdec.sbr_noise;

   // if(SBR_bs_coupling==0) call sbr_envelope_noise_dequantisation;
   Null = M[$aacdec.sbr_info + $aacdec.SBR_bs_coupling];
   if NZ jump not_in_coupling_mode;
      call $aacdec.sbr_envelope_noise_dequantisation;
   not_in_coupling_mode:

   r2 = &$aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic;
   I1 = r2;
   r0 = 0;

   r10 = 64;
   do clear_bs_add_harmonic_loop;
      M[I1,1] = r0;
   clear_bs_add_harmonic_loop:

   I1 = r2;

   call $aacdec.get1bit;
   M[$aacdec.sbr_np_info + $aacdec.SBR_bs_add_harmonic_flag] = r1;

   if Z jump no_sinusoidal_coding_ch1;

      r10 = M[$aacdec.sbr_info + $aacdec.SBR_Nhigh];

      do sinusoidal_coding_ch1_loop;
         call $aacdec.get1bit;
         M[I1, 1] = r1;
      sinusoidal_coding_ch1_loop:
   no_sinusoidal_coding_ch1:


   call $aacdec.get1bit;

   // if(SBR_bs_extended_data)
   if Z jump no_extended_data;
      // SBR_bs_extension_size
      call $aacdec.get4bits;

      Null = r1 - 15;
      if NZ jump count_not_15;
         // SBR_bs_esc_count
         call $aacdec.get1byte;
         r1 = r1 + 15;
      count_not_15:

#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS

      M[$aacdec.ps_info +  $aacdec.PS_EXT_DATA_READ] = Null;
      // r8 = num_bits_left = cnt * 8
      r8 = r1 * 8 (int);
      if Z jump no_extended_data;
      // while(num_bits_left > 7)
      ps_extension_data_loop:
         // SBR_bs_extension_id = getbits(2)
         call $aacdec.get2bits;
         // num_bits_left -= 2
         r8 = r8 - 2;
         // if(SBR_bs_extension_id == EXT_ID_PS)
         Null = r1 - $aacdec.PS_EXT_ID_PARAMETRIC_STEREO;
         if NZ jump end_if_ext_id_ps;
            r0 = 1;
            M[$aacdec.parametric_stereo_present] = r0;

            // if(PS_EXT_DATA_READ == 0)
            Null = M[$aacdec.ps_info + $aacdec.PS_EXT_DATA_READ];
            if NZ jump ps_ext_data_already_read;
               M[$aacdec.ps_info + $aacdec.PS_EXT_DATA_READ] = r0;
               call $aacdec.ps_data;
               jump end_if_ext_id_ps;
            // else
            ps_ext_data_already_read:
               call $aacdec.get6bits;
               // num_bits_left -= 6
               r8 = r8 - 6;

         end_if_ext_id_ps:
      Null = r8 - 7;
      if GT jump ps_extension_data_loop;

      // if(num_bits_left > 0) getbits(num_bits_left)
      r0 = r8;
      if NZ call $aacdec.getbits;

#else

      r10 = r1;

      Null = r10 AND 1;
      if Z jump discard_byte_pairs;
         r10 = r10 - 1;
         call $aacdec.get1byte;
      discard_byte_pairs:
      r10 = r10 LSHIFT -1;

      do discard_cnt_bytes;
         call $aacdec.get2bytes;
      discard_cnt_bytes:

#endif

   no_extended_data:

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
