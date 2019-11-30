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
//    $aacdec.sbr_hf_generation
//
// DESCRIPTION:
//    Generate high frequency components of X_sbr from low frequency components
//    and information from the bitstream
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r8, r10, rMAC
//    - I0-I7
//    - M0-M3
//    - DivResult, DivRemainder
//    - aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_hf_generation;
   .CODESEGMENT AACDEC_SBR_HF_GENERATION_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_hf_generation:

   // push rLink onto stack
   push rLink;

  PROFILER_START(&$aacdec.profile_sbr_calc_chirp_factors)
      call $aacdec.sbr_calc_chirp_factors;
  PROFILER_STOP(&$aacdec.profile_sbr_calc_chirp_factors)

  PROFILER_START(&$aacdec.profile_sbr_patch_construction)
      call $aacdec.sbr_patch_construction;
  PROFILER_STOP(&$aacdec.profile_sbr_patch_construction)

   // for i=0:sbr.noPatches-1
   r6 = 0;
   outer_loop:
      M[$aacdec.tmp +1] = r6;

      // for x=0:sbr.patchNoSubbands(i)-1
      r7 = 0;
      inner_loop:
         M[$aacdec.tmp +2] = r7;

         // r6 = i, r7 = x

         // p = sbr.patchStartSubband(i) + x;
         r8 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_patch_start_subband) + r6];
         r8 = r8 + r7;                                      //r8 = p

         // k = sbr.Kx + x;
         r2 = M[$aacdec.sbr_info + $aacdec.SBR_kx] + r7;

         // for q=0:i-1,
         //    k = k + sbr.patchNoSubbands(q);
         // end;
         r10 = r6;
         I0 = &$aacdec.tmp_mem_pool + $aacdec.SBR_patch_num_subbands;
         r1 = M[I0, 1];
         do make_k_loop;
            r2 = r2 + r1,
             r1 = M[I0, 1];
         make_k_loop:
                                                            // r2 = k

         // g = sbr.table_map_k_to_g(k+1);
         r3 = M[($aacdec.sbr_info + $aacdec.SBR_table_map_k_to_g) + r2];


         // bw = sbr.bwArray(ch, g);
         r5 = M[$aacdec.current_channel];                   // r5 = ch
         r1 = r5 * 5 (int);
         r1 = r1 + r3;
         r1 = M[($aacdec.sbr_info + $aacdec.SBR_bwArray) + r1];                  // r1 = bw

         // if(bw_2 > 0)
         if Z jump zero_bw;

            // store k, p, bw as registers trashed in following functions
            M[$aacdec.tmp +5] = r2;
            M[$aacdec.tmp +6] = r8;
            M[$aacdec.tmp +7] = r1;

           PROFILER_START(&$aacdec.profile_sbr_auto_correlation_opt)
               call $aacdec.sbr_auto_correlation_opt;
           PROFILER_STOP(&$aacdec.profile_sbr_auto_correlation_opt)

           PROFILER_START(&$aacdec.profile_sbr_prediction_coeff)
               call $aacdec.sbr_prediction_coeff;
           PROFILER_STOP(&$aacdec.profile_sbr_prediction_coeff)

           PROFILER_START(&$aacdec.profile_sbr_hf_generation_internal)

               // first = sbr.t_E(ch, 1);
               // last = sbr.t_E(ch, sbr.bs_num_env(ch)+1);
               r5 = M[$aacdec.current_channel];
               r1 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
               r0 = r5 * 6 (int);
               r3 = M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r0];          // r3 = first
               r1 = r1 + r0;
               r1 = M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r1];          // r1 = last


               // for l=first:last-1,
               //    sbr.X_sbr(ch, k, l + 2) = sbr.X_sbr(ch, p, l + 2) + (bw * sbr.alpha_0(p) * sbr.X_sbr(ch, p, l + 1)) + ...
               //                                                        (bw_2 * sbr.alpha_1(p) * sbr.X_sbr(ch, p, l));
               // end
               // Note, the above is complex so the implementation is slightly more complicated than it looks like it should be.
               r10 = r1 - r3;

               M0 = $aacdec.X_SBR_WIDTH;             // increment by M0 as X_sbr stored columnwise (if k, p denote row numbers)
               M1 = -3;
               M2 = 1;

               r3 = r3 * $aacdec.X_SBR_WIDTH (int);
               r2 = M[$aacdec.tmp +5];
               r2 = r2 + r3;
               r8 = M[$aacdec.tmp +6];
               r8 = r8 + r3;
               I0 = r2 + ((&$aacdec.sbr_x_real+512) + (2*$aacdec.X_SBR_WIDTH));        // real[X_sbr(ch, k, first+2)]
               I1 = r8 + (&$aacdec.sbr_x_real+512);                                // real[X_sbr(ch, p, first)]
               I4 = r2 + ((&$aacdec.sbr_x_imag+1536) + (2*$aacdec.X_SBR_WIDTH));        // imag[X_sbr(ch, k, first+2)]
               I5 = r8 + (&$aacdec.sbr_x_imag+1536);                                // imag[X_sbr(ch, p, first)]

               // aacdec.tmp + 7  = bw * REAL(alpha_0)
               // aacdec.tmp + 8  = bw * IMAG(alpha_0)
               // aacdec.tmp + 9  = bw^2 * REAL(alpha_1)
               // aacdec.tmp + 10 = bw^2 * IMAG(alpha_1)
               I2 = &$aacdec.tmp + 7;
               r1 = M[I2, 0];
               r2 = M[$aacdec.tmp + $aacdec.SBR_alpha_0];
               r2 = r2 * r1 (frac);
               M[I2, 1] = r2;
               r2 = M[$aacdec.tmp + ($aacdec.SBR_alpha_0 +1)];
               r2 = r2 * r1 (frac);
               M[I2, 1] = r2;
               r1 = r1 * r1 (frac);
               r2 = M[$aacdec.tmp + $aacdec.SBR_alpha_1];
               r2 = r2 * r1 (frac);
               M[I2, M2] = r2;
               r2 = M[$aacdec.tmp + ($aacdec.SBR_alpha_1 +1)];
               r2 = r2 * r1 (frac);
               M[I2, M1] = r2;


               r5 = M[I1, M0],               // r5 = real[X_sbr(ch, p, first)]
                r0 = M[I5, M0];
               r6 = r0,                      // r6 = imag[X_sbr(ch, p, first)]
                r0 = M[I1, M0];              // r0 = real[X_sbr(ch, p, first + 1)]
               r1 = M[I5, M0];               // r1 = imag[X_sbr(ch, p, first + 1)]

               do big_loop;
                  r7 = r5,                // r7 = real[X_sbr(ch, p, l)]
                   r2 = M[I2, M2];           // r2 = bw * REAL(alpha_0)
                  r8 = r6,                // r8 = imag[X_sbr(ch, p, l)]
                   r3 = M[I2, M2];           // r3 = bw * IMAG(alpha_0)
                  r5 = r0;                // r5 = real[X_sbr(ch, p, l + 1)]
                  r6 = r1;                // r6 = imag[X_sbr(ch, p, l + 1)]
                  r0 = M[I1, M0],         // r0 = real[X_sbr(ch, p, l + 2)]
                   r1 = M[I5, M0];        // r1 = imag[X_sbr(ch, p, l + 2)]


                  rMAC = r0 * 0.0625;
                  rMAC = rMAC + r2 * r5,
                   r2 = M[I2, M2];           // r2 = bw^2 * REAL(alpha_1)
                  rMAC = rMAC - r3 * r6,
                   r3 = M[I2, M1];           // r3 = bw^2 * IMAG(alpha_1)
                  rMAC = rMAC + r2 * r7,
                   r2 = M[I2, M2];           // r2 = bw * REAL(alpha_0)
                  rMAC = rMAC - r3 * r8,
                   r3 = M[I2, M2];           // r3 = bw * IMAG(alpha_0)

                  r4 = rMAC * 16 (int);

                  rMAC = r1 * 0.0625;
                  M[I0, M0] = r4;    // real[X_sbr(ch, k, l + 2)] = answer
                  rMAC = rMAC + r2 * r6,
                   r2 = M[I2, M2];           // r2 = bw^2 * REAL(alpha_1)
                  rMAC = rMAC + r3 * r5,
                   r3 = M[I2, M1];           // r3 = bw^2 * REAL(alpha_1)
                  rMAC = rMAC + r2 * r8;
                  rMAC = rMAC + r3 * r7;
                  r4 = rMAC * 16 (int);
                  M[I4, M0] = r4;       // imag[X_sbr(ch, k, l + 2)] = answer
               big_loop:

           PROFILER_STOP(&$aacdec.profile_sbr_hf_generation_internal)
            jump out_if;

         zero_bw:
            // first = sbr.t_E(ch, 0);
            // last = sbr.t_E(ch, sbr.bs_num_env(ch));
            r5 = M[$aacdec.current_channel];
            r1 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
            r0 = r5 * 6 (int);
            r3 = M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r0];          // r3 = first
            r1 = r1 + r0;
            r1 = M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r1];          // r1 = last


            // for l=first:last-1,
            //    sbr.X_sbr(ch, k, l + 2) = sbr.X_sbr(ch, p, l + 2);
            // end;
            // Do the above in two sections as X_sbr is split across two memory buffers.
            // First section is for 'l+2' up to tHFGen. Here we are dealing with X_sbr_curr_real/imag
            // Second section is for 'l+2' beyond tHFGen. Here we are dealing with X_sbr_shared_real/imag
            r10 = r1 - r3;

            M0 = $aacdec.X_SBR_WIDTH;            // increment by M0 as X_sbr stored columnwise (if k, p denote row numbers)
            r3 = r3 + 2;
            r3 = r3 * $aacdec.X_SBR_WIDTH (int);
            r6 = r2 + r3;
            r7 = r8 + r3;
            I0 = r6 + (&$aacdec.sbr_x_real+512);                       //real[X_sbr(ch, k, first + 2)]
            I4 = r6 + (&$aacdec.sbr_x_imag+1536);                       //imag[X_sbr(ch, k, first + 2)]
            I1 = r7 + (&$aacdec.sbr_x_real+512);                       //real[X_sbr(ch, p, first + 2)]
            I5 = r7 + (&$aacdec.sbr_x_imag+1536);                       //imag[X_sbr(ch, p, first + 2)]

            do simple_loop;
               r0 = M[I1, M0],            // real[X_sbr(ch, p, l + 2)]
                r1 = M[I5, M0];           // imag[X_sbr(ch, p, l + 2)]
               M[I0, M0] = r0,            // real[X_sbr(ch, k, l + 2)]
                M[I4, M0] = r1;           // imag[X_sbr(ch, k, l + 2)]
            simple_loop:


         out_if:

         // for x=0:sbr.patchNoSubbands(i)-1
         r6 = M[$aacdec.tmp +1];
         r7 = M[$aacdec.tmp +2];
         r7 = r7 + 1;
         r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_patch_num_subbands) + r6];
         Null = r7 - r1;
         if LT jump inner_loop;

      // for i=0:sbr.noPatches-1
      r6 = r6 + 1;
      r1 = M[$aacdec.tmp_mem_pool + $aacdec.SBR_num_patches];
      Null = r6 - r1;
      if LT jump outer_loop;

  PROFILER_START(&$aacdec.profile_sbr_limiter_frequency_table)
      Null = M[$aacdec.current_channel];
      if Z call $aacdec.sbr_limiter_frequency_table;
  PROFILER_STOP(&$aacdec.profile_sbr_limiter_frequency_table)



   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;


#endif
