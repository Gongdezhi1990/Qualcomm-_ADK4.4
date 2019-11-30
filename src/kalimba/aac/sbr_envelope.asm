// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"
#include "profiler.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_envelope
//
// DESCRIPTION:
//    Get envelope information
//
// INPUTS:
//    - r5 current channel (0/1)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r4, r6-r8, r10, I1-I6, M0-M3
//    - an element of $aacdec.tmp
//    - L5 set to zero
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_envelope;
   .CODESEGMENT AACDEC_SBR_ENVELOPE_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_envelope:

   // push rLink onto stack
   push rLink;


   // if((SBR_bs_num_env[ch]==1)&&(SBR_bs_frame_class[ch]==SBR_FIXFIX))
   r6 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
   Null = r6 - 1;
   if NZ jump non_zero_amplitude_resolution;
      r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_frame_class) + r5];
      Null = r0 - $aacdec.SBR_FIXFIX;
      if NZ jump non_zero_amplitude_resolution;
         r7 = 0;
         M[($aacdec.sbr_info + $aacdec.SBR_amp_res) + r5] = Null;
         jump amplitude_resolution_assigned;
   // else
   non_zero_amplitude_resolution:

   r7 = M[$aacdec.sbr_info + $aacdec.SBR_bs_amp_res];
   M[($aacdec.sbr_info + $aacdec.SBR_amp_res) + r5] = r7;

   amplitude_resolution_assigned:


   Null = M[$aacdec.sbr_info + $aacdec.SBR_bs_coupling];
   if Z jump not_coupling_mode;
      // if(ch==0)
      Null = r5;
      if Z jump ch_0_coupling_mode;
         // if(SBR_amp_res[ch]==1)
         Null = r7;
         if Z jump zero_amp_res_coupling;
            I3 = &$aacdec.t_huffman_env_bal_3_0dB;
            I4 = &$aacdec.f_huffman_env_bal_3_0dB;
            r7 = $aacdec.SBR_HUFFMAN_ENV_BAL_3_0_DB_SIZE;
            jump huffman_tables_selected;
         zero_amp_res_coupling:
            I3 = &$aacdec.t_huffman_env_bal_1_5dB;
            I4 = &$aacdec.f_huffman_env_bal_1_5dB;
            r7 = $aacdec.SBR_HUFFMAN_ENV_BAL_1_5_DB_SIZE;
            jump huffman_tables_selected;
      ch_0_coupling_mode:
   not_coupling_mode:
      // if(SBR_amp_res[ch]==1)
      Null = r7;
      if Z jump zero_amp_res_non_coupling;
         I3 = &$aacdec.t_huffman_env_3_0dB;
         I4 = &$aacdec.f_huffman_env_3_0dB;
         r7 = $aacdec.SBR_HUFFMAN_ENV_3_0_DB_SIZE;
         jump huffman_tables_selected;
      zero_amp_res_non_coupling:
         I3 = &$aacdec.t_huffman_env_1_5dB;
         I4 = &$aacdec.f_huffman_env_1_5dB;
         r7 = $aacdec.SBR_HUFFMAN_ENV_1_5_DB_SIZE;
   huffman_tables_selected:


   Null = r5;
   if NZ jump ch1_envelope;
      r1 = &$aacdec.tmp_mem_pool + 2048;
      jump envelope_base_ptr_assigned;
   ch1_envelope:
      r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
      r0 = r0 * 64 (int);
      // assumes last 320 words of frame_mem_pool are not in use
      // elsewhere from here until this channel has been processed by AAC+SBR
      r1 = (&$aacdec.frame_mem_pool + $aacdec.FRAME_MEM_POOL_LENGTH);
      r1 = r1 - r0;
   envelope_base_ptr_assigned:

   M[($aacdec.tmp_mem_pool + $aacdec.SBR_E_envelope_base_ptr) + r5] = r1;
   M[$aacdec.tmp + $aacdec.SBR_HUFFMAN_TABLE_SIZE] = r7;

   #ifdef AACDEC_SBR_HUFFMAN_IN_FLASH
      r0 = I3;
      r2 = M[$flash.windowed_data16.address];
      call $aacdec.sbr_allocate_and_unpack_from_flash;
      I3 = r1;
      r0 = I4;
      r2 = M[$flash.windowed_data16.address];
      call $aacdec.sbr_allocate_and_unpack_from_flash;
      I4 = r1;
   #endif

   r8 = M[$aacdec.sbr_info + ($aacdec.SBR_num_env_bands + 1)];
   r0 = r5 * 5 (int);
   M2 = r0;
   r0 = r5 * 6 (int);
   M3 = r0;
   r0 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_E_envelope_base_ptr) + r5];
   L5 = r0;
   // env
   r7 = 0;

   // for env=0:SBR_bs_num_env[ch]
   outer_loop:
      // if(SBR_bs_df_env[ch][env] == 0)
      r0 = M2 + r7;
      r0 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_df_env) + r0];
      if NZ jump delta_time_coding;
         // if((SBR_bs_coupling==1) && (ch==1))
         Null = M[$aacdec.sbr_info + $aacdec.SBR_bs_coupling];
         if Z jump not_coupling_mode_and_ch1;
            Null = r5;
            if Z jump not_coupling_mode_and_ch1;
               // if(SBR_amp_res[ch]==1)
               Null = M[($aacdec.sbr_info + $aacdec.SBR_amp_res) + r5];
               if Z jump zero_amp_res_coupling_and_ch1;
                  r0 = 5;
                  jump delta_frequency_coding;
               zero_amp_res_coupling_and_ch1:
               r0 = 6;
               jump delta_frequency_coding;
         not_coupling_mode_and_ch1:
         // if(SBR_amp_res[ch]==1)
         Null = M[($aacdec.sbr_info + $aacdec.SBR_amp_res) + r5];
         if Z jump zero_amp_res_not_coupling_and_ch1;
            r0 = 6;
            jump delta_frequency_coding;
         zero_amp_res_not_coupling_and_ch1:
         r0 = 7;

         delta_frequency_coding:
         // SBR_E_envelope[ch][band=0][env] = getbits(r0)
         call $aacdec.getbits;
         r0 = r8 * r7 (int);
         I6 = L5 + r0;
         M[I6,1] = r1;
         I2 = I4;

         // for band=1:SBR_num_env_bands[SBR_bs_freq_res[ch][env]]-1,
         r0 = M3 + r7;
         r1 = M[($aacdec.sbr_info + $aacdec.SBR_bs_freq_res) + r0];

         r10 = M[($aacdec.sbr_info + $aacdec.SBR_num_env_bands) + r1];
         r10 = r10 - 1;

         do huff_decode_envelope_d_freq_coding;
            call $aacdec.sbr_huff_dec;
            M[I6, 1] = r1;
         huff_decode_envelope_d_freq_coding:

         jump eval_loop_index;

      delta_time_coding:
         // for band=0:SBR_num_env_bands[SBR_bs_freq_res[ch][env]]-1,
         r0 = M3 + r7;
         r1 = M[($aacdec.sbr_info + $aacdec.SBR_bs_freq_res) + r0];

         r10 = M[($aacdec.sbr_info + $aacdec.SBR_num_env_bands) + r1];

         r0 = r8 * r7 (int);
         I6 = L5 + r0;
         I2 = I3;

         do huff_decode_envelope_d_time_coding;
            call $aacdec.sbr_huff_dec;
            M[I6, 1] = r1;
         huff_decode_envelope_d_time_coding:

   eval_loop_index:
   r7 = r7 + 1;
   Null = r6 - r7;
   if GT jump outer_loop;

   L5 = 0;

   #ifdef AACDEC_SBR_HUFFMAN_IN_FLASH
      r0 = M[$aacdec.tmp + $aacdec.SBR_HUFFMAN_TABLE_SIZE];
      r0 = r0 LSHIFT 1;
      call $aacdec.frame_mem_pool_free;
   #endif

  PROFILER_START(&$aacdec.profile_sbr_extract_envelope_data)
      call $aacdec.sbr_extract_envelope_data;
  PROFILER_STOP(&$aacdec.profile_sbr_extract_envelope_data)



   // pop rLink from stack
   jump $pop_rLink_and_rts;



.ENDMODULE;

#endif
