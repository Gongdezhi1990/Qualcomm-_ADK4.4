// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MIXED_RADIX_FFT_INCLUDED
#define MIXED_RADIX_FFT_INCLUDED
#include "stack.h"
#include "mixed_radix_fft.h"

//.include "mixed_radix_fft_init.h"

// *****************************************************************************
// MODULE:
//    $mixed_radix_fft/$mixed_radix_ifft
//
// DESCRIPTION:
//    sets up the FFT/IFFT mode and the pointers to the lookup tables
//    needed for a particular number of points.
//
// INPUTS:
//    - I7 = pointer to fft structure:
//           - $fft.NUM_POINT_FIELD - number of data points
//           - $fft.REAL_FIELD      - ptr to real input data (becomes output data)
//           - $fft.IMAG_FIELD      - ptr to imag input data (becomes output data)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0 - r8, r10, I1, I2, I4, I5, M0 - M3
//
// *****************************************************************************
.MODULE $M.math.mixed_radix_fft;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR/DM1 $input_reord_re[192];
   .VAR/DM2 $input_reord_im[192];

   // shared tables/variables
   .VAR $func_ptr[6] =                    0, 0,        &$radix2_dft,        &$radix3_dft,       &$radix4_dft,     &$radix5_dft;
   .VAR $tw_set_count;
   .VAR $num_stages;
   .VAR $stage_count;
   .VAR $twiddle_tables_re;
   .VAR $twiddle_tables_im;
   .VAR $current_radix_ptr;
   .VAR $rem_ptr;
   .VAR $sofar_ptr;
   .VAR $scale_ptr;
   .VAR $ifft_v;
   .VAR $alpha;

   $math.mixed_radix_fft:
      r0 = 1.0;
      M[$ifft_v] = r0;
      M[$alpha] = r8;
      jump mixed_radix_start;

   $math.mixed_radix_ifft:
      r0 = -1.0;
      M[$ifft_v] = r0;
      M[$alpha] = r8;

   mixed_radix_start:
   // push rLink onto stack
   $push_rLink_macro;

      // select the lookup tables for the fft size
      r0 = M[I7,1];
      call $math.mixed_radix_fft_init;
      // mix radix fft bit reordering
      r4 = M[I7,1];
      r5 = M[I7,-1];
      r0 = M[I7,-1]; //dummy read to move pointer
      I2 = &$input_reord_re;
      I5 = &$input_reord_im;
      r6 = 0;
      M1 = 1;
      call $math.bit_reordering;

      // compute the fft
      M[$stage_count] = Null;
      call $math.small_radix_wrapper;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $small_radix_wrapper
//
// DESCRIPTION:
//    small_radix_wrapper calls radix2,3,4,5 DFTs to compute a larger FFT.
//
// INPUTS:
//    - I7 = pointer to fft structure:
//           - $fft.NUM_POINT_FIELD - number of data points
//           - $fft.REAL_FIELD      - ptr to real input data (becomes output data)
//           - $fft.IMAG_FIELD      - ptr to imag input data (becomes output data)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0 - r5, r8, r10
//
// *****************************************************************************


.MODULE $M.math.small_radix_wrapper;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR temp_val;

   $math.small_radix_wrapper:

   // push rLink onto stack
   $push_rLink_macro;

      stage_change:
         rMAC = 0;
         r0 = M[I7,0];
         rMAC0 = r0;
         r1 = M[$current_radix_ptr];
         r2 = M[$sofar_ptr];
         r1 = M[r1];
         r2 = M[r2];
         r1 = r1*r2 (int);
         Div = rMAC/r1;
         r8 = DivResult;
         M[temp_val] = r8;

         M[$tw_set_count] = Null;
         r0 = &$input_reord_re;
         r1 = &$input_reord_im;
         I1 = r0;
         I4 = r1;

         r2 = M[$sofar_ptr];
         r2 = M[r2];
         r0 = 1;
         r1 = r0*r2 (int);
         r0 = -1;
         M0 = r1;
         r1 = r0*r2 (int);
         r0 = 2;
         M1 = r1;
         r1 = r0*r2 (int);
         r0 = -2;
         M2 = r1;
         r1 = r0*r2 (int);
         M3 = r1;

         r0 = M[$current_radix_ptr];
         r0 = M[r0];
         if Z jump $pop_rLink_and_rts;

         // current stage computed sofar_radix times
         current_stage:
            r0 = &$input_reord_re;
            r1 = &$input_reord_im;
            r2 = M[$tw_set_count];
            I1 = r0 + r2;
            I4 = r1 + r2;

            r0 = M[$twiddle_tables_re];
            r1 = M[$twiddle_tables_im];
            r0 = M[r0];
            r1 = M[r1];
            r3 = M[$current_radix_ptr];
            r3 = M[r3];
            r4 = r2*r3 (int);
            I2 = r0 + r4;
            I5 = r1 + r4;
            r0 = M[$scale_ptr];
            r0 = M[r0];
            r1 = M[$alpha];
            r0 = r0 * r1 (frac);
            r8 = M[temp_val];
            r1 = &$math.prescale_twid;
            r2 = &$math.prescale;
            Null = M[$stage_count];
            if Z r1 = r2;
            call r1;
            r10 = M[temp_val];
            r3 = M[$current_radix_ptr];
            r3 = M[r3];
            r0 = M[$func_ptr + r3];
            call r0;
            r1 = M[$tw_set_count];
            r1 = r1 + 1;
            M[$tw_set_count] = r1;
            r2 = M[$sofar_ptr];
            r2 = M[r2];
            Null = r1 - r2;
         if NEG jump current_stage;

      check_stages_left:
         r0 = M[$stage_count];
         r0 = r0 + 1;
         M[$stage_count] = r0;
         r1 = M[$num_stages];
         Null = r1 - r0;
         if GT jump next_stage;

         r1 = &$input_reord_re;
         I1 = r1;
         r1 = &$input_reord_im;
         I4 = r1;
         r0 = I7;
         r1 = M[r0+1];
         I2 = r1;
         r1 = M[r0+2];
         I5 = r1;

         r2 = M[$ifft_v];
         call &$math.postprocess;

         jump $pop_rLink_and_rts;

      next_stage:
         r0 = M[$current_radix_ptr];
         r0 = r0 + 1;
         M[$current_radix_ptr] = r0;
         r0 = M[$rem_ptr];
         r0 = r0 + 1;
         M[$rem_ptr] = r0;
         r0 = M[$sofar_ptr];
         r0 = r0 + 1;
         M[$sofar_ptr] = r0;
         r0 = M[$twiddle_tables_re];
         r0 = r0 + 1;
         M[$twiddle_tables_re] = r0;
         r0 = M[$twiddle_tables_im];
         r0 = r0 + 1;
         M[$twiddle_tables_im] = r0;
         r0 = M[$scale_ptr];
         r0 = r0 + 1;
         M[$scale_ptr] = r0;
         jump stage_change;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $radix2_dft
//
// DESCRIPTION:
//    radix2 DTF routine
//
// INPUTS:
//    - r10 number of times to run radix2 loop
//      (calculated as $fft.NUM_POINTS_FIELD/(radix size))
//    - I1 pointer to real input buffer
//    - I4 pointer to imaginary input buffer
//    - M0 = 1*sofar_radix
//    - M1 = -1*sofar_radix
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0 - r5
//
// *****************************************************************************

.MODULE $M.math.radix2_dft;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $radix2_dft:

      do calc_dft;
         r0 = M[I1,M0], r1 = M[I4,M0];
         r2 = M[I1,M1], r3 = M[I4,M1];
         r4 = r0 + r2;                                // calc re[0] + re[1]
         r5 = r1 + r3;                                // calc im[0] + im[1]
         r0 = r0 - r2, M[I1,M0] = r4, M[I4,M0] = r5;  // calc re[0] - re[1]
         r1 = r1 - r3;                                // calc im[0] - im[1]
         M[I1,M0] = r0, M[I4,M0] = r1;
      calc_dft:

   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $radix3_dft
//
// DESCRIPTION:
//    radix3 DTF routine
//
// INPUTS:
//    - r10 number of times to run radix3 loop
//      (calculated as $fft.NUM_POINTS_FIELD/(radix size))
//    - I1 pointer to real input buffer
//    - I4 pointer to imaginary input buffer
//    - M0 =  1*sofar_radix
//    - M1 = -1*sofar_radix
//    - M2 =  2*sofar_radix
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0 - r7, rMAC
//
// *****************************************************************************

.MODULE $M.math.radix3_dft;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $radix3_dft:

      r0 = M[I1,M2], r1 = M[I4,M2];

      do calc_dft;
         r0 = M[I1,M1], r1 = M[I4,M1];             // read re[2] im[2], decrement pointers
         r2 = M[I1,M1], r3 = M[I4,M1];             // read re[1] im[1], decrement pointers
         r0 = r0 + r2, r4 = M[I1,0], r5 = M[I4,0]; // calc re[1] + re[2], read re[0] im[0], leave pointers unchanged
         r1 = r1 + r3;                             // calc im[1] + im[2], leave pointers unchanged
         r4 = r4 + r0;                             // calc re[0] + re[1] + re[2]
         r5 = r5 + r1;                             // calc im[0] + im[1] + im[2]
         M[I1,M0] = r4, M[I4,M0] = r5;             // save (re[0] + re[1] + re[2]) (im[0] + im[1] + im[2])
                                                   // r0 = re[1] + re[2]; r1 = im[1] + im[2]
                                                   // r4 = re[0] + re[1] + re[2]; r5 = im[0] + im[1] + im[2]
         rMAC = r4;
         r6 = $ph1_radix3;
         r7 = $ph3_radix3;
         rMAC = rMAC + r6*r0;
         rMAC = rMAC + r7*r0;

         r4 = rMAC;                                //A = (re[0] + re[1]+ re[2]) + c3_1*(re[1] + re[2])
         rMAC = r5;
         rMAC = rMAC + r6*r1;
         rMAC = rMAC + r7*r1;

         r5 = rMAC;                                //B = (im[0] + im[1]+ im[2]) + c3_1*(im[1] + im[2])
         r1 = r3 - r1;
         r1 = r1 + r3;                             // r1 = im[1] - im[2]

         r6 = $ph2_radix3;
         r0 = r0 - r2;
         r0 = r0 - r2;                             // r2 = re[2] - re[1]
         rMAC = r1*r6;                             // C = c3_2*(im[1] - im[2])
         r2 = r4 + rMAC;
         r4 = r4 - rMAC;
         rMAC = r0*r6;                             // D = c3_2*(re[2] - re[1])
         r0 = r5 + rMAC;
         r5 = r5 - rMAC, M[I1,M0] = r2, M[I4,M0] = r0;
         M[I1,M0] = r4, M[I4,M0] = r5;
         r0 = M[I1,M2], r1 = M[I4,M2];             //dummy read to move pointers

      calc_dft:

   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $radix4_dft
//
// DESCRIPTION:
//    radix4 DTF routine
//
// INPUTS:
//    - r10 number of times to run radix4 loop
//      (calculated as $fft.NUM_POINTS_FIELD/(radix size))
//    - I1 pointer to real input buffer
//    - I4 pointer to imaginary input buffer
//    - M0 =  1*sofar_radix
//    - M1 = -1*sofar_radix
//    - M2 =  2*sofar_radix
//    - M3 = -2*sofar_radix
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0 - r5
//
// *****************************************************************************

.MODULE $M.math.radix4_dft;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $radix4_dft:

      do calc_dft;
         r0 = M[I1,M2], r1 = M[I4,M2];                   // read re[0] im[0]
         r2 = M[I1,0], r3 = M[I4,0];                     // read re[2] im[2]
         r4 = r0 - r2;                                   // r4 = re[0] - re[2]
         r0 = r0 + r2;                                   // r0 = re[0] + re[2]

         r5 = r1 - r3;                                   // r5 = im[0] - im[2]
         r1 = r1 + r3, M[I1,M3] = r4, M[I4,M3] = r5;     // r1 = im[0] + im[2]

         M[I1,M0] = r0, M[I4,M0] = r1;

         r0 = M[I1,M2], r1 = M[I4,M2];                   // read re[1] im[1]
         r2 = M[I1,0], r3 = M[I4,0];                     // read re[3] im[3]

         r4 = r2 - r0;                                   // r4 = re[3] - re[1]
         r5 = r1 - r3;                                   // r5 = im[1] - im[3]
         r0 = r0 + r2, M[I1,M3] = r5, M[I4,M3] = r4;     // r0 = re[1] + re[3]

         r1 = r1 + r3;                                   // r1 = im[1] + im[3]
         M[I1,M1] = r0, M[I4,M1] = r1;

         // halfway
         r0 = M[I1,M0], r1 = M[I4,M0];                   // read re[0] + re[2] im[0] + im[2]
         r2 = M[I1,M1], r3 = M[I4,M1];                   // read re[1] + re[3] im[1] + im[3]
         r4 = r0 + r2;                                   // r4 = re[0] + re[2] + re[1] + re[3]
         r2 = r0 - r2;                                   // r2 = re[0] + re[2] - re[1] - re[3]

         r5 = r1 + r3;                                   // r5 = im[0] + im[2] + im[1] + im[3]
         r3 = r1 - r3;                                   // r3 = im[0] + im[2] - im[1] - im[3]
         M[I1,M2] = r4, M[I4,M2] = r5;

         r0 = M[I1,0], r1 = M[I4,0];                     // read  (re[0] - re[2])  (im[0] - im[2])
         M[I1,M0] = r2, M[I4,M0] = r3;

         r2 = M[I1,M3], r3 = M[I4,M3];                   // read im[1] - im[3] re[3] - re[1]
         r4 = r0 + r2;                                   // r4 = re[0] - re[2] + im[3] - im[1]
         r0 = r0 - r2;                                   // r0 = im[3] - im[1] + re[0] - re[2]

         r5 = r1 + r3;                                   // r5 = im[0] - im[2] - re[1] + re[3]
         r1 = r1 - r3, M[I1,M2] = r4, M[I4,M2] = r5;     // r1 = im[0] - im[2] - re[3] + re[1]

         M[I1,M0] = r0, M[I4,M0] = r1;

      calc_dft:
   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $radix5_dft
//
// DESCRIPTION:
//    radix5 DTF routine
//
// INPUTS:
//    - r10 number of times to run radix5 loop
//      (calculated as $fft.NUM_POINTS_FIELD/(radix size))
//    - I1 pointer to real input buffer
//    - I4 pointer to imaginary input buffer
//    - M0 =  1*sofar_radix
//    - M1 = -1*sofar_radix
//    - M2 =  2*sofar_radix
//    - M3 = -2*sofar_radix
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0 - r8, rMAC
//
// *****************************************************************************


.MODULE $M.math.radix5_dft;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $radix5_dft:

      r0 = M[I1,M2], r1 = M[I4,M2];                      // dummy read to move pointers
      r0 = M[I1,M0], r1 = M[I4,M0];                      // dummy read to move pointers

      do calc_dft;
         r0 = M[I1,M1], r1 = M[I4,M1];                   // read re[3] im[3]
         r2 = M[I1,0], r3 = M[I4,0];                     // read re[2] im[2]

         r4 = r0 + r2;                                   // t2_re = re[3] + re[2]
         r5 = r1 + r3;                                   // t2_im = im[3] + im[2]
         r0 = r0 - r2, M[I1,M1] = r4, M[I4,M1] = r5;     // t4_re = re[3] - re[2]; save t2_re t2_im
         r1 = r1 - r3, r4= M[I1,M2], r5 = M[I4,M2];      // t4_im = im[3] - im[2]; read re[1] im[1]

         M[I1,M0] = r0, M[I4,M0] = r1;                   // save t4_r4 t4_im
         r0 = M[I1,0], r1 = M[I4,0];                     // read re[4] im[4];

         r2 = r4 - r0;                                   // t3_re = re[1] - re[4]
         r3 = r5 - r1;                                   // r3_im = im[1] - im[4]
         r0 = r0 + r4, M[I1,M3] = r2, M[I4,M3] = r3;     // t1_re = re[1] + re[4]
         r1 = r1 + r5, r2= M[I1,M1], r3 = M[I4,M1];      // t1_im = im[1] + im[4]; read re[2] im[2]
         M[I1,M1] = r0, M[I4,M1] = r1;                   // save t1_re; t1_im
         r4 = M[I1,0], r5 = M[I4,0];                     // read re[0] im[0]
         r6 = r2 + r0;                                   // t5_re = re[1] + re[2] + re[3] + re[4]
         r7 = r3 + r1;                                   // t5_im = im[1] + im[2] + im[3] + im[4]
         r4 = r4 + r6;                                   // r4 = re[0] + re[1] + re[2] + re[3] + re[4]
         r5 = r5 + r7;                                   // r5 = im[0] + im[1] + im[2] + im[3] + im[4]
         M[I1,M0] = r4, M[I4,M0] = r5;                   // save re[0] im[0]

         r8 = $ph1_radix5;
         r5 = $ph6_radix5;
         rMAC = r6*r8;
         rMAC = rMAC +r6*r5;                             // calc m1_re = c5_1*(re[1] + re[2] + re[3] + re[4])
         r4 = rMAC;
         rMAC = r7*r8;
         rMAC = rMAC +r7*r5;                             // calc m1_im = c5_1*(im[1] + im[2] + im[3] + im[4])
         M[I1,M0] = r4, M[I4,M0] = rMAC;                 // save m1_re in re[1] m1_im in im[1]
         r4 = r0 - r2;                                   // calc re[1] + re[2] - re[3] - re[4] ....(t1_re - t2_re)
         r5 = r1 - r3;                                   // calc im[1] + im[2] - im[3] - im[4] ....(t1_im - t2_im)

         rMAC = r4*$ph2_radix5;                          // calc m2_re = c5_2*(t1_re - t2_re)
         r4 = rMAC;
         rMAC = r5*$ph2_radix5;                          // calc m2_im = c5_2*(t1_im - t2_im)
         r5 = rMAC;
         M[I1,M2] = r4, M[I4,M2] = r5;                   // save m2_re in re[2] m2_im in im[2]

         // debug: first checkpoint
         r0 = M[I1,M1], r1 =  M[I4,M1];                  // read t3_re t3_im
         r2 = M[I1,0], r3 =  M[I4,0];                    // read t4_re t4_im

         r4 = $ph3_radix5;
         rMAC = r1*r4;
         rMAC = rMAC + r3*r4;                            // calc m3_re = -c5_3*(t3_im + t4_im)
         r5 = - rMAC;                                    // r5 = m3_re
         rMAC = r0*r4;
         rMAC = rMAC + r2*r4;                            // calc m3_im = c5_3*(t3_re + t4_re)
         r6 = rMAC;                                      // r6 = m3_im
         r7 = $ph4_radix5;
         rMAC = r3*r4;
         rMAC = rMAC + r3*r7;                            // calc m4_re = -c5_4*t4_im
         r3 = -rMAC;                                     // r3 = r4_re
         rMAC = r2*r4;
         rMAC = rMAC + r2*r7;                            // calc m4_im = c5_4*t4_re
         r4 = $ph5_radix5;
         r2 = rMAC;                                      // r2 = m4_im
         rMAC = r0*r4;                                   // calc m5_im = c5_5*t3_re
         r0 = rMAC;                                      // r0 = m5_im
         rMAC = r1*r4;                                   // calc -m5_re = c5_5*t3_im -> rMAC

         // debug: second checkpoint
         r1 = r5 - r3;                                   // calc s3_re = m3_re - m4_re
         r3 = r6 - r2;                                   // calc s3_im = m3_im - m4_im

         r5 = r5 - rMAC;                                 // calc s5_re = m3_re + m3_re
         r6 = r6 + r0, M[I1,M3]=r1, M[I4,M3]=r3;         // calc s5_im = m3_im + m5_im; save s3_re s3_im
         r2 = M[I1,M1], r3 = M[I4,M1];                   // read m1_re m1_im
         r0 = M[I1,M2], r1 = M[I4,M2];                   // read re[0] im[0]
         r0 = r0 + r2;                                   // calc s1_re = re[0] + m1_re
         r1 = r1 + r3;                                   // calc s1_im = im[0] + m1_im
         r2 = M[I1,0], r3 = M[I4,0];                     // read m2_re m2_im
         r4 = r0 + r2;                                   // calc s2_re = s1_re + m2_re
         rMAC = r1 + r3;                                 // calc s2_im = s1_im + m2_im
         r0 = r0 - r2, M[I1,M2] = r4, M[I4,M2] = rMAC;   // calc s4_re = s1_re - m2_re; save s2_re; s2_im
         r1 = r1 - r3;                                   // calc s4_im = s1_im - m2_im
         M[I1,M1] = r0, M[I4,M1] = r1;                   // save s4_re; s4_im

         // debug: third checkpoint
         r2 = M[I1,M3], r3 = M[I4,M3];                   // read s3_re s3_im
         r0 = r4 + r2;                                   // calc re[1] = s2_re + s3_re
         r1 = rMAC + r3;                                 // calc im[1] = s2_im + s3_im
         M[I1,M2] = r0, M[I4,M2] = r1;                   // save re[1] im[1]
         r4 = r4 - r2, r0 = M[I1,M0], r1 = M[I4,M0];     // calc re[4] = s2_re - s5_re; dummy read to point to s4_re s4_im
         rMAC = rMAC - r3;                               // calc im[4] = s2_im - s3_im
         r0 = M[I1,0], r1 = M[I4,0];                     // read s4_re s4_im
         M[I1,M3] = r4, M[I4,M3] = rMAC;                 // save re[4] im[4]
         r4 = r0 + r5;                                   // calc re[2] = s4_re + s5_re
         rMAC = r1 + r6;                                 // calc im[2] = s4_im + s5_im
         M[I1,M0] = r4, M[I4,M0] = rMAC;                 // save re[2] im[2]
         r0 = r0 - r5;                                   // calc re[3] = s4_re - s5_re
         r1 = r1 - r6;                                   // calc im[3] = s4_im - s5_im
         M[I1,M2] = r0, M[I4,M2] = r1;                   // save re[3] im[3]
         r0 = M[I1,M2], r1 = M[I4,M2];                   // dummy read -> move pointer +2
         r0 = M[I1,M0], r1 = M[I4,M0];                   // dummy read -> move pointer +1

      calc_dft:

   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $bit_reordering
//
// DESCRIPTION:
//    bit_reordering routine
//
// INPUTS:
//    - r4 start of fft in real buffer
//    - r5 start of fft in imaginary buffer
//    - r6 number of times to outer loop
//    - r7 number of times to run inner loop (== to 1st stage radix)
//    - r8 bit reorder lookup table
//    - M0 remaining radix for 1st stage
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0, r1, r6, r10, I1, I2, I4, I5
//
// *****************************************************************************

.MODULE $M.math.bit_reordering;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $math.bit_reordering:

      outer_loop:
      r10 = r7;
      r0 = M[r8 + r6];
      I1 = r0 + r4;
      I4 = r0 + r5;

      do int_loop;
         r0 = M[I1,M0], r1 = M[I4,M0];
         M[I2,1] = r0, M[I5,1] = r1;
      int_loop:

      r6 = r6 + 1;
      Null = r6 - M0;
      if NEG jump outer_loop;

   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $prescale
//
// DESCRIPTION:
//    prescale routine
//
// INPUTS:
//    - r0 = scale factor
//    - I1 = pointer to real input buffer for current stage
//    - I4 = pointer to imaginary input buffer for current stage
//    - I7 = pointer to fft structure:
//           - $fft.NUM_POINT_FIELD - number of data points
//           - $fft.REAL_FIELD      - ptr to real input data (becomes output data)
//           - $fft.IMAG_FIELD      - ptr to imag input data (becomes output data)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r1 - r5, I1, I4
//
// *****************************************************************************

.MODULE $M.math.prescale;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $math.prescale:

      r4 = I1;
      r5 = I4;
      r1 = M[I7,0];
      r10 = r1;
      r3 = M[$ifft_v];

      do scale_input;
        r1 = M[I1,0], r2 = M[I4,0];
        r1 = r1 * r0 (frac);
        r2 = r2 * r0 (frac);
        r2 = r2 * r3 (frac);
        M[I1,1] = r1, M[I4,1] = r2;

      scale_input:
      I1 = r4;
      I4 = r5;

   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $prescale_twid
//
// DESCRIPTION:
//    prescale and apply inter-stage twiddle factors
//
// INPUTS:
//    - r0 = scale factor
//    - r8 = $fft.NUM_POINT_FIELD/(sofar_radix*current_radix)
//    - I1 = pointer to real input buffer for current stage
//    - I4 = pointer to imaginary input buffer for current stage
//    - I2 = pointer to real input twiddle factors for current stage
//    - I5 = pointer to imaginary input twiddle factors for current stage
//    - I7 = pointer to fft structure:
//           - $fft.NUM_POINT_FIELD - number of data points
//           - $fft.REAL_FIELD      - ptr to real input data (becomes output data)
//           - $fft.IMAG_FIELD      - ptr to imag input data (becomes output data)
//    - M0 =  1 * sofar_radix
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r1 - r8, rMAC, r10, I1 - I3, I4 - I6
//
// *****************************************************************************

.MODULE $M.math.prescale_twid;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $math.prescale_twid:

      I3 = I2;
      I6 = I5;

      r6 = I1;
      r7 = I4;

      scale_loop_start:
      r1 = M[$current_radix_ptr];
      r10 = M[r1];

      do scale_input;
        r1 = M[I1,0], r2 = M[I4,0];
        r1 = r1 * r0 (frac), r4 = M[I2,1], r5 = M[I5,1];
        r2 = r2 * r0 (frac);
        rMAC = r1*r4;
        rMAC = rMAC - r2*r5;
        r3 = rMAC;
        rMAC = r1*r5;
        rMAC = rMAC + r2*r4;
        M[I1,M0] = r3, M[I4,M0] = rMAC;
      scale_input:

      I2 = I3;
      I5 = I6;
      r8 = r8 - 1;
      if NZ jump scale_loop_start;

      I1 = r6;
      I4 = r7;

   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $postprocess
//
// DESCRIPTION:
//    postprocess routine IFFT only negate imaginary output
//
// INPUTS:
//    - I4 = pointer to imaginary input buffer for current stage
//    - I7 = pointer to fft structure:
//           - $fft.NUM_POINT_FIELD - number of data points
//           - $fft.REAL_FIELD      - ptr to real input data (becomes output data)
//           - $fft.IMAG_FIELD      - ptr to imag input data (becomes output data)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0, r1, r5, r10, I4
//
// *****************************************************************************

.MODULE $M.math.postprocess;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $math.postprocess:

      r0 = M[I7,0];
      r10 = r0;

      do post_process;
        r0 = M[I1,1], r1 = M[I4,1];
        r1 = r1*r2 (frac);
        M[I2,1] = r0, M[I5,1] = r1;
      post_process:

   rts;

.ENDMODULE;





#endif //MIX_RADIX_FFT_INCLUDED