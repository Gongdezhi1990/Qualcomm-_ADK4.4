// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MIXED_RADIX_FFT_INIT_INCLUDED
#define MIXED_RADIX_FFT_INIT_INCLUDED

// *****************************************************************************
// MODULE:
//    $math.mixed_radix_fft_init
//
// DESCRIPTION:
//    sets up the FFT/IFFT mode and the pointers to the lookup tables
//    needed for a particular number of points.
//
// INPUTS:
//    r0 = $fft.NUM_POINT_FIELD - number of data points
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - none
//
// *****************************************************************************
.MODULE $M.math.mixed_radix_fft_init;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $math.mixed_radix_fft_init:

      $push_rLink_macro;
      // select the lookup tables for the fft size
#ifdef USE_60_POINT_MIXED_RADIX_FFT
      Null = r0 - 60;
      if NZ jump test1;
         call $math.setup_60pt_fft;
         jump $pop_rLink_and_rts;
      test1:
#endif
#ifdef USE_120_POINT_MIXED_RADIX_FFT
      Null = r0 - 120;
      if NZ jump test2;
         call $math.setup_120pt_fft;
         jump $pop_rLink_and_rts;
      test2:
#endif
#ifdef USE_180_POINT_MIXED_RADIX_FFT
      Null = r0 - 180;
      if NZ jump test3;
         call $math.setup_180pt_fft;
         jump $pop_rLink_and_rts;
      test3:
#endif
#ifdef USE_192_POINT_MIXED_RADIX_FFT
      Null = r0 - 192;
      if NZ jump $error;
         call $math.setup_192pt_fft;
#endif
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif //MIXED_RADIX_FFT_INIT_INCLUDED