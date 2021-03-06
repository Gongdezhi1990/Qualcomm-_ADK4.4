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
//    $aacdec.imdct480
//
// DESCRIPTION:
//    480 sample IMDCT routine
//
// INPUTS:
//    - r6 = pointer to imdct structure:
//         $aacdec.imdct.NUM_POINTS_FIELD
//            - number of input data points (480)
//         $aacdec.imdct.INPUT_ADDR_FIELD
//            - pointer to input data (circular)
//         $aacdec.imdct.INPUT_ADDR_BR_FIELD
//            - bit reversed pointer to input data (circular)
//         $aacdec.imdct.OUTPUT_ADDR_FIELD
//            - pointer to output data (circular)
//         $aacdec.imdct.OUTPUT_ADDR_BR_FIELD
//            - bit reversed pointer to output data (circular)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - everything including $aacdec.tmp but L0 & L1
//
// *****************************************************************************
.MODULE $M.aacdec.imdct480;
   .CODESEGMENT AACDEC_IMDCT480_PM;
   .DATASEGMENT DM;

   $aacdec.imdct480:


   // The cos and sin variables are stored in the following order:
   //       sin_const =  cos(          pi/480),      sin(          pi/480),
   //                    cos(          pi/480/8),    sin(          pi/480/8),
   //                    cos( 60.125 * pi/480),      sin( 60.125 * pi/480),
   //                    cos(120.125 * pi/480),      sin(120.125 * pi/480),
   //                    cos(180.125 * pi/480),      sin(180.125 * pi/480),
   .VAR  sin_const480[10] = 0.9999785817,               0.0065449380,
                            0.9999996653,               0.0008181230,
                            0.9235661412,               0.3834391514,
                            0.7065280442,               0.7076850449,
                            0.3819274572,               0.9241923054;

   // push rLink onto stack
   $push_rLink_macro;

   r8 = M[r6 + $aacdec.imdct.NUM_POINTS_FIELD];
   I2 = &sin_const480;

   // set up the modify registers
   M0 = 1;
   M1 = 2;
   M2 = -2;

   // need to copy the odd values into the output buffer
   r10 = r8 LSHIFT -1;
   r10 = r10 - M0;

   // set a pointer to the start of the copy, and the target
   // and two buffers as output pointers for below
   r1 = M[r6 + $aacdec.imdct.INPUT_ADDR_FIELD];
   I0 = r1;                                                          // input
   I4 = r1;                                                          // input
   I0 = I0 + r8,
    r2 = M[I2,M0];                                                   // cfreq
   I0 = I0 - M0,
    r3 = M[I2,M0];                                                   // sfreq

   r1 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_FIELD];
   I5 = r1;                                                          // output
   I6 = r1;                                                          // output
   I5 = I5 + r8,
    r0 = M[I0,M2];

   do pre_copy_loop;
      r0 = M[I0,M2],
       M[I5,M0] = r0;
   pre_copy_loop:

   M[I5,M0] = r0;

   // set up two registers to work through the input in opposite directions
   I0 = I4;                                                          // input
   I5 = I6;                                                          // output
   I5 = I5 + r8,
    r4 = M[I2,M0];                                                   // c

   // to make the additions easier below set c= -c & s= -s
   r4 = -r4,                                                         // r4 = -c
    r5 = M[I2,M0];                                                   // s
   r5 = -r5,                                                         // r5 = -s
    r0 = M[I0, M1];                                                  // -tempr

   // use M3 as a loop counter
   M3 = 3;
   M2 = 0;

   // tmp used to store c
   I1 = &$aacdec.tmp;

   outer_pre_process_loop:

      r10 = r8 LSHIFT -3;                                            // r10 = N/8
      do pre_process_loop;

         // process the data
         rMAC = r0 * r4,                                             // rMAC = (-tempr) * (-c)
          r1 = M[I5, M0];                                            // tempi

         rMAC = rMAC + r1 * r5;                                      // rMAC = temp*c + tempi*(-s)

         rMAC = r0 * r5,                                             // rMAC = (-tempr)*(-s)
          M[I4, M0] = rMAC;

         rMAC = rMAC - r1 * r4;                                      // rMAC = tempr*s - tempi*(-c)

         // update the multipliers: "c" and "s"
         rMAC = r4 * r2,                                             // (-c) * cfreq
          M[I6, M0] = rMAC;

         rMAC = rMAC - r5 * r3,                                      // (-c)'= (-c) * cfreq - (-s) * sfreq
          r0 = M[I0, M1];

         rMAC = r4 * r3,                                             // (-c_old) * sfreq
          M[I1,M2] = rMAC;
         rMAC = rMAC + r5 * r2;                                      // (-s)' = (-c_old)*sfreq + (-s)*cfreq

         r5 = rMAC,                                                  // r5 = (-s)'
          r4 = M[I1,M2];
      pre_process_loop:

      // load the constant points mid way to improve accuracy
      r4 = M[I2,M0];

      r4 = -r4,
       r5 = M[I2,M0];

      r5 = -r5;
      M3 = M3 - M0;
   if POS jump outer_pre_process_loop;

   // set up data in fft_structure
   
   // store imdct structure pointer and NUM_POINTS_FIELD
   M[$aacdec.tmp + 3] = r6;
   M[$aacdec.tmp + 2] = r8;

   // store INPUT_ADDR_FIELD, OUTPUT_ADDR_FIELD and OUTPUT_ADDR_BR_FIELD
   r0 = M[r6 + $aacdec.imdct.INPUT_ADDR_FIELD];
   r1 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_FIELD];
   r2 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_BR_FIELD];
   M[$aacdec.tmp + 7] = r0;
   M[$aacdec.tmp + 8] = r1;
   M[$aacdec.tmp + 11] = r2;

   // -- call the ifft --
   call $aacdec.scaleable_ifft240;

   r8 = M[$aacdec.tmp + 2];                           
   r1 = M[$aacdec.tmp + 3];                                          // restore imdct structure pointer
   r0 = M[$aacdec.tmp + 8];
   r2 = M[$aacdec.tmp + 11];                          
   M[r1 + $aacdec.imdct.OUTPUT_ADDR_FIELD] = r0;                     // restore OUTPUT_ADDR_FIELD
   M[r1 + $aacdec.imdct.NUM_POINTS_FIELD] = r8;                      // restore NUM_POINTS_FIELD
   M[r1 + $aacdec.imdct.OUTPUT_ADDR_BR_FIELD] = r2;                  // restore OUTPUT_ADDR_BR_FIELD
   r10 = r8 ASHIFT -1;

   // set up the shift registers
   M0 = 1;
   M1 = 2;
   M2 = -2;
   M3 = 0;

   // post process the data
   I2 = &sin_const480;
   
   r1 = M[$aacdec.tmp + 7];                                          // restore $aacdec.imdct.INPUT_ADDR_FIELD
   r3 = 256;
   // for AAC ELD we write the output buffer from an offset == half the size of IMDCT 
   I7 = r0 + r10;
   I0 = r1;                                                          // real ifft component
   I1 = I0 + r3,                                                     // imag ifft component
    r2 = M[I2, M0];                                                  // cfreq

   r7 = 3;                                                           // setting r7 - used as loop counter

   // set up pointers to output buffers
   r3 = M[I2, M0];                                                   // sfreq
   I6 = I7 - M0,
    r4 = M[I2, M0];                                                  // c
   I6 = I6 + r8,
    r5 = M[I2, M0];                                                  // s

   // store the constant locations in r6
   r6 = I2;

   // in the loop below $aacdec.tmp[9] is used as temporary storage
   // for the calculated cos value - we are setting its address here
   I2 = &$aacdec.tmp;
   I2 = I2 + 9;

   r0 = M[I0, M0];                                                   // tempr

   // use r7 as outer loop counter, set above
   post_process_loop:

      r10 = r8 LSHIFT -3;                                            // r10 = N/8

      do inner_post_process_loop;

         rMAC = r0 * r4,                                             // rMAC = tempr * c
          r1 = M[I1, M0];                                            // tempi

         rMAC = rMAC - r1 * r5;                                      // rMAC = tempr*c - tempi*s


         rMAC = r1 * r4,                                             // rMAC = tempi * c
          M[I6, M2] = rMAC;                                          // I6 = tr

         rMAC = rMAC + r0 * r5;                                      // rMAC = tempi*c + tempr*s

         // update the multipliers: "c" and "s"
         rMAC = r4 * r2,                                             // c * cfreq
          M[I7, M1] = rMAC;

         rMAC = rMAC - r5 * r3,                                      // c' = c * cfreq - s * sfreq
          r0 = M[I0, M0];

         rMAC = r4 * r3,                                             // c_old * sfreq
          M[I2,M3] = rMAC;

         rMAC = rMAC + r5 * r2;                                      // s' = c_old*sfreq + s*cfreq

         r5 = rMAC,                                                  // r5 = s'
          r4 = M[I2,M3];

      inner_post_process_loop:

      // load more accurate data for c and s
      r4 = M[r6];
      r5 = M[r6 + 1];
      // update sin_const480 offset and outer loop counter
      r6 = r6 + 2;
      r7 = r7 - 1;
   if POS jump post_process_loop;

   L4 = 0;
   L5 = 0;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $aacdec.scaleable_ifft240
//
// DESCRIPTION:
//    240 point scaleable IFFT
//
// INPUTS:
//    - r6 = pointer to imdct structure:
//         $aacdec.imdct.NUM_POINTS_FIELD
//            - number of input data points (480)
//         $aacdec.imdct.INPUT_ADDR_FIELD
//            - pointer to input data (circular)
//         $aacdec.imdct.INPUT_ADDR_BR_FIELD
//            - bit reversed pointer to input data (circular)
//         $aacdec.imdct.OUTPUT_ADDR_FIELD
//            - pointer to output data (circular)
//         $aacdec.imdct.OUTPUT_ADDR_BR_FIELD
//            - bit reversed pointer to output data (circular)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - everything including $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.$aacdec.scaleable_ifft240;
   .CODESEGMENT AACDEC_SCALEABLE_IFFT240_PM;
   .DATASEGMENT DM;

   $aacdec.scaleable_ifft240:

   // push rLink onto stack
   $push_rLink_macro;

   // 16p IFFT - standard math library
   r7 = Null;
   M[$aacdec.tmp + 4] = r7;

   // Set imdct BR input and BR output pointers in the fft structure which is 
   // wrapped up in the imdct structure as below:
   //
   //   | $aacdec.imdct.INPUT_ADDR_FIELD == $fft.REAL_ADDR_FIELD
   //   | $aacdec.imdct.OUTPUT_ADDR_FIELD == $fft.IMAG_ADDR_FIELD
   //   | $aacdec.imdct.NUM_POINTS_FIELD == $fft.NUM_POINTS_FIELD
   //
   // and set up the data in the ifft input buffers.
   r0 = $aacdec.ifft_re;
   M[r6 + $aacdec.imdct.INPUT_ADDR_FIELD] = r0;                      // $fft.REAL_ADDR_FIELD
   call $math.address_bitreverse;
   M[r6 + $aacdec.imdct.INPUT_ADDR_BR_FIELD] = r1;
   r1 = $aacdec.IFFT_OUTPUT_OFFSET;
   r0 = &$aacdec.tmp_mem_pool + r1;
   M[r6 + $aacdec.imdct.OUTPUT_ADDR_FIELD] = r0;                     // $fft.IMAG_ADDR_FIELD
   call $math.address_bitreverse;
   M[r6 + $aacdec.imdct.OUTPUT_ADDR_BR_FIELD] = r1;

   // override the IFFT size
   r4 = $aacdec.POWER_OF_2_IFFT_SIZE;
   M[r6 + $aacdec.imdct.NUM_POINTS_FIELD] = r4;                      // $fft.NUM_POINTS_FIELD

   ifft_loop:
      // Each iteration we read NUM_POINTS_FIELD real and imaginary inputs
      // with a step equal to $aacdec.NON_POWER_OF_2_DFT_SIZE.
      // M[$aacdec.current_spec_ptr] contains the real spectral input (SP_RE)
      // $aacdec.tmp_mem_pool contains the imaginary spectral input (SP_IM)
      //
      // The IFFT receives the following inputs:
      //
      // ifft_in_re[j] = SP_RE[i + $aacdec.NON_POWER_OF_2_DFT_SIZE*j]   
      // ifft_in_im[j] = SP_IM[i + $aacdec.NON_POWER_OF_2_DFT_SIZE*j]
      //
      // where
      // i = 0 ... $aacdec.NON_POWER_OF_2_DFT_SIZE (iteration counter)
      // j = 0 ... $aacdec.POWER_OF_2_IFFT_SIZE (sample counter for one iteration)
      //
      
      r10 = M[r6 + $aacdec.imdct.NUM_POINTS_FIELD];
      M0 = $aacdec.NON_POWER_OF_2_DFT_SIZE;
      M1 = 1;
      r2 = M[$aacdec.current_spec_ptr];
      r3 = M[r6 + $aacdec.imdct.INPUT_ADDR_FIELD];
      I1 = r2 + r7;
      I4 = r3;

      r2 = &$aacdec.tmp_mem_pool;
      r3 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_FIELD];
      I2 = r2 + r7;
      I5 = r3;

      do copy_ifft_input;
         r0 = M[I1, M0];
         r1 = M[I2, M0],
          M[I4, M1] = r0;
         M[I5, M1] = r1;
      copy_ifft_input:
   
      // Set the scaling value calculated with the formula (8.53333333333*0.5^4)^(1/4).
      r8 = 0.854574012792468;          
      // set the pointer to ifft structure
      I7 = r6;   
      call $math.scaleable_ifft;

      // Enable BR addressing on AG1 as the IFFT output is returned bit reversed (BR)
      rFlags = rFlags OR $BR_FLAG;

      //
      // Un-BR the IFFT output buffers which is similar to $math.bitreverse_array with two differences:
      // - it processes two buffers per loop.
      // - the inputs are read in bitreverse order ($math.bitreverse_array writes the outputs in BR order).
      // 
      // This bit of code relies on the size of the buffer pointed to by OUTPUT_ADDR_FIELD to
      // be at least 6 x $aacdec.IFFT_NUM_POINTS (it should actually be 8 x $aacdec.IFFT_NUM_POINTS
      // for the $aacdec.imdct480 to produce correct results).
      //
      // The un-BR IFFT outputs are stored in a temporary area at higher offsets 
      // of OUTPUT_ADDR_FIELD:
      // - im_offset = (3*$aacdec.IFFT_NUM_POINTS + $aacdec.POWER_OF_2_IFFT_SIZE).
      // - re_offset = (4*$aacdec.IFFT_NUM_POINTS + $aacdec.POWER_OF_2_IFFT_SIZE).
      //
      r7 = M[$aacdec.tmp + 4];                                       // restore loop counter
      r6 = $aacdec.imdct_info;
      r10 = M[r6 + $aacdec.imdct.NUM_POINTS_FIELD];
      r1 = M[r6 + $aacdec.imdct.INPUT_ADDR_BR_FIELD];
      r2 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_FIELD];
      r3 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_BR_FIELD];
      I1 = r1;
      r8 = r10 * r7 (int);
      I5 = r2 + $aacdec.POWER_OF_2_IFFT_SIZE;
      I5 = I5 + r8;
      I2 = r3;
      I4 = I5 + $aacdec.IFFT_NUM_POINTS;
      r8 = r10 ASHIFT 1;

      // calculate bit reverse modify register
      r3 = SIGNDET r8;
      r3 = r3 + 2;                                                   // would use +1, but splitting data in half
      r4 = 1;
      r3 = r4 LSHIFT r3;
      M0 = r3;                                                       // bit reverse modify register
   
      M1 = 1;                                                        // output modify register 

      do copy_ifft_output;
         r0 = M[I1, M0];
         r1 = M[I2, M0], 
          M[I4, M1] = r0;
         M[I5, M1] = r1;
      copy_ifft_output:

      // disable bit reversed addressing on AG1
      rFlags = rFlags AND $NOT_BR_FLAG;

      // increment loop counter and reload imdct_info pointer
      r7 = r7 + 1;
      r6 = $aacdec.imdct_info;
      M[$aacdec.tmp + 4] = r7;
   Null = r7 - $aacdec.NON_POWER_OF_2_DFT_SIZE;
   if LT jump ifft_loop;

   // brute force 15p DFT
   r7 = 0;
   r4 = $aacdec.TWIDDLE_TABLE_SIZE - 1;
   r0 = &$aacdec.twiddle_tab;
   I6 = r0 + r4;
   I7 = r0;
   M0 = 1;
   M1 = -1;
   M2 = $aacdec.POWER_OF_2_IFFT_SIZE;
   M3 = 0;
   r2 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_FIELD];
   r5 = r2 + $aacdec.POWER_OF_2_IFFT_SIZE;                           // in - imag 
   r4 = r5 + $aacdec.IFFT_NUM_POINTS;                                // in - real 
   r2 = &$aacdec.tmp;
   I3 = r2 + 4;
   M[$aacdec.tmp + 5] = r4;
   M[$aacdec.tmp + 6] = r5;

   r2 = M[$aacdec.current_spec_ptr];        
   I0 = r2;                                                               // out - real
   I1 = r2 + ($aacdec.IFFT_NUM_POINTS + $aacdec.POWER_OF_2_IFFT_SIZE);    // out - imag
   r8 = $aacdec.IFFT_Q1_BOUNDARY;

   dft_outer_loop:
      r0 = r7 AND $aacdec.POWER_OF_2_IFFT_SIZE_MASK;                 // outer_loop_counter % IFFT_SMALL_POW2_SIZE
      I4 = r4 + r0;
      I5 = r5 + r0;

      r0 = $aacdec.ifft_re;                                          // storage for cos values
      r1 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_FIELD];                  // storage for sin values
      I2 = r0;
      I3 = r1;
      
      // save phase factor buffer pointers for later
      r2 = I2;                                                       // ph_real
      r3 = I3;                                                       // ph_imag

      // For increased precision, on each iteration we read the sin/cos twiddle factor
      // increments from &$aacdec.twiddle_tab and based on them we generate 
      // $aacdec.NON_POWER_OF_2_DFT_SIZE real and imaginary twiddle factors.
      //
      // To save 3/4 memory locations that would be otherwise needed to save the sin/cos values 
      // we divided their reading in 4 quadrants.
      //
      r10 = $aacdec.NON_POWER_OF_2_DFT_SIZE - 1;
      r4 = 1.0;                                                      // curcos
      r5 = 0;                                                        // cursin

      Null = r7 - r8;
      if GT jump second_q;
      if LT jump first_q_no_swap;
         M[I2,M0] = r4,                                              // save first value of curcos
          r1 = M[I6,M0];                                             // ca - cos step
         M[I3,M3] = r5,                                              // save first value of cursin
          r0 = M[I7,M1];                                             // sa - sin step
         jump loop_start;
      first_q_no_swap:
         M[I2,M0] = r4,                                              // save first value of curcos
          r1 = M[I6,M1];                                             // ca - cos step
         M[I3,M3] = r5,                                              // save first value of cursin
          r0 = M[I7,M0];                                             // sa - sin step
         jump loop_start;

      second_q:
      Null = r7 - $aacdec.IFFT_Q2_BOUNDARY;
      if GT jump third_q;
      if LT jump second_q_no_swap;
         M[I2,M0] = r4,                                              // save first value of curcos
          r1 = M[I6,M1];                                             // ca - cos step
         M[I3,M3] = r5,                                              // save first value of cursin
          r0 = M[I7,M0];                                             // sa - sin step
         r1 = -r1;
         jump loop_start;
      second_q_no_swap:
         M[I2,M0] = r4,                                              // save first value of curcos
          r1 = M[I6,M0];                                             // ca - cos step
         M[I3,M3] = r5,                                              // save first value of cursin
          r0 = M[I7,M1];                                             // sa - sin step
         r1 = -r1;
         jump loop_start;

      third_q:
      Null = r7 - $aacdec.IFFT_Q3_BOUNDARY;
      if GT jump fourth_q;
      if LT jump third_q_no_swap;
         M[I2,M0] = r4;                                              // save first value of curcos
          r1 = M[I6,M0];                                             // ca - cos step
         M[I3,M3] = r5,                                              // save first value of cursin
          r0 = M[I7,M1];                                             // sa - sin step
          r1 = -r1;                                                  
          r0 = -r0;
         jump loop_start;

      third_q_no_swap:
         M[I2,M0] = r4;                                              // save first value of curcos
          r1 = M[I6,M1];                                             // ca - cos step
         M[I3,M3] = r5,                                              // save first value of cursin
          r0 = M[I7,M0];                                             // sa - sin step
          r1 = -r1;
          r0 = -r0;
         jump loop_start;

      fourth_q:
         M[I2,M0] = r4,                                              // save first value of curcos
          r1 = M[I6,M0];                                             // ca - cos step
         M[I3,M3] = r5,                                              // save first value of cursin
          r0 = M[I7,M1];                                             // sa - sin step
          r0 = -r0;

      loop_start:         
      // oldcos = curcos;
      do generate_phase_factors;
         rMAC = r1 * r4,                                             // curcos = oldcos * ca
          r5 = M[I3,M0];                                             // oldsin = cursin
         rMAC = rMAC - r0 * r5;                                      // curcos = oldcos * ca - oldsin * sa
         rMAC = r0 * r4,                                             // cursin = oldcos * sa
          M[I2,M3] = rMAC;                                           // write curcos
         rMAC = rMAC + r1 * r5;                                      // cursin = oldcos * sa + oldsin * ca
         M[I3,M3] = rMAC;                                            // write cursin
         r4 =  M[I2,M0];                                             // oldcos = curcos;
      generate_phase_factors:

      // reload loop counter and restore the phase factor buffer pointers
      r10 = $aacdec.NON_POWER_OF_2_DFT_SIZE;
      I2 = r2;                                                       // ph_real          
      I3 = r3;                                                       // ph_imag

      rMAC = 0;
      r4 = M[I2,M0],                                                 // read ph_real[]
       r0 = M[I4,M2];                                                // read in_real[]
      do calc_dft_re;
         rMAC = rMAC + r0 * r4,                                      // out_real = in_real[] * ph_real[]
          r5 = M[I3,M0],                                             // read ph_imag[]
          r1 = M[I5,M2];                                             // read in_imag[]
         rMAC = rMAC - r1 * r5,                                      // out_real = in_real[] * ph_real[]- in_imag[] * ph_imag[]
          r4 = M[I2,M0],                                             // read ph_real[]
          r0 = M[I4,M2];                                             // read in_real[]
      calc_dft_re:

      rMAC = rMAC ASHIFT -1;
      M[I0,M0] = rMAC;                                               // save out_real
      
      // reload loop counter and restore the phase factor buffer pointers
      r10 = $aacdec.NON_POWER_OF_2_DFT_SIZE;
      I2 = r2;                                                       // ph_real          
      I3 = r3;                                                       // ph_imag

      r0 = r7 AND $aacdec.POWER_OF_2_IFFT_SIZE_MASK;                 // outer_loop_counter % IFFT_SMALL_POW2_SIZE
      r4 = M[$aacdec.tmp + 5];
      r5 = M[$aacdec.tmp + 6]; 
      I4 = r4 + r0;
      I5 = r5 + r0;

      rMAC = 0;
      r4 = M[I2,M0],                                                 // read ph_real[]
       r0 = M[I5,M2];                                                // read in_real[]
      do calc_dft_im;
         rMAC = rMAC + r0 * r4,                                      // out_imag = in_real[] * ph_real[]
          r5 = M[I3,M0],                                             // read ph_imag[]
          r1 = M[I4,M2];                                             // read in_imag[]
         rMAC = rMAC + r1 * r5,                                      // out_imag = in_real[] * ph_real[] + in_imag[] * ph_imag[]
          r4 = M[I2,M0],                                             // read ph_real[]
          r0 = M[I5,M2];                                             // read in_real[]
      calc_dft_im:

      rMAC = rMAC ASHIFT -1;
      M[I1,M0] = rMAC;                                               // save out_imag
      r4 = M[$aacdec.tmp + 5];
      r5 = M[$aacdec.tmp + 6]; 
      r7 = r7 + 1;
      Null = r7 - $aacdec.IFFT_NUM_POINTS;
   if LT jump dft_outer_loop;
   
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif //AACDEC_ELD_ADDITIONS
