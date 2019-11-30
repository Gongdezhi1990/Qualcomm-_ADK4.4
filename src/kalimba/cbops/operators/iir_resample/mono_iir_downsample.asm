// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


// *****************************************************************************
// NAME:
//    Mono IIR downsample operator
//
// DESCRIPTION:
//    This operator uses an IIR and a FIR filter combination to
//    perform sample rate conversion.  The utilization of the IIR
//    filter allows a lower order FIR filter to be used to obtain
//    an equivalent frequency response.  The result is that the
//    IIR resampler uses less MIPs than the current polyphase FIR method.
//    It also provides a better frequency response.
//
//    The IIR component is a 9th order filter applied at the input sample
//    rate.  The IIR filter coefficients are unique for each conversion ratio.
//
//    The FIR component is implemented in a polyphase configuration.
//    Each phase is a 10 order filter applied at the output sample rate.  The filter
//    is symetrical so only half the coefficients need to be stored. The FIR filter
//    coefficients are the same for all conversion ratios. For all the
//    phases, 640 coefficients are stored.
//
//    The operator utilizes its own history buffers.  As a result the input and/or
//    output may be a port.  Also, for downsampling, in-place operation is supported.
//
//    MIPs for IIR downsamplig is approximatly:             26*output_rate + 15*input_rate
//    MIPs for FIR only downsampling is approximately:      97*output_rate
//
//    ***** WARNING *******
//        See $cbops.iir_resample_complete operator for usage
//
// When using the operator the following data structure is used:
//
//   $cbops.mono.iir_resample.INPUT_1_START_INDEX_FIELD = The index of the input
//       buffer
//   $cbops.mono.iir_resample.OUTPUT_1_START_INDEX_FIELD = The index of the output
//       buffer
//   $cbops.mono.iir_resample.FILTER_DEFINITION_PTR_FIELD = Pointer to configuration
//       object defining the supported sample rate conversions.  These objects are
//       constants in defined iir_resample_coefs.asm:
//            $M.cbops.iir_resample.16_to_8.filter
//            $M.cbops.iir_resample.22_05_to_8.filter
//            $M.cbops.iir_resample.22_05_to_16.filter
//            $M.cbops.iir_resample.32_to_8.filter
//            $M.cbops.iir_resample.32_to_16.filter
//            $M.cbops.iir_resample.32_to_22_05.filter
//            $M.cbops.iir_resample.44_1_to_8.filter
//            $M.cbops.iir_resample.44_1_to_16.filter
//            $M.cbops.iir_resample.44_1_to_22_05.filter
//            $M.cbops.iir_resample.44_1_to_32.filter
//   $cbops.mono.iir_resample.INPUT_SCALE_FIELD = A power of 2 scale
//       factor applied to the input signal.  The input should be
//       scaled to at Q8.15 resolution (i.e 16-bits).
//   $cbops.mono.iir_resample.OUTPUT_SCALE_FIELD = A power of 2 scale
//       factor applied to the output signal.  The signal before scaling
//       will be at Q8.15 resolution
//   $cbops.mono.iir_resample.SAMPLE_COUNT_FIELD = Internal parameter
//       tracking the polyphase operation.  Initialize to zero.
//   $cbops.mono.iir_resample.IIR_HISTORY_BUF_PTR_FIELD = Pointer to
//        a circular memory buffer of length $IIR_RESAMPLE_IIR_BUFFER_SIZE.
//   $cbops.mono.iir_resample.FIR_HISTORY_BUF_PTR_FIELD = Pointer to
//        a circular memory buffer of length $IIR_DOWNSAMPLE_FIR_BUFFER_SIZE.
//   $cbops.mono.iir_resample.RESET_FLAG_FIELD = Flag indicating that the
//        IIR history buffer should be cleared.  This flag is self resetting
//        and should be initialized to non-zero.
// *****************************************************************************

#include "cbops.h"
#include "core_library.h"

.MODULE $M.cbops.mono_iir_downsample;
   .DATASEGMENT DM;

   // ** function vector **
   .VAR $cbops.mono_iir_downsample[$cbops.function_vector.STRUC_SIZE] =
      $cbops.function_vector.NO_FUNCTION,         // reset function
      &$cbops.mono_iir_downsample.amount_to_use,  // amount to use function
      &$cbops.mono_iir_downsample.main;           // main function

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbops.mono_iir_downsample.amount_to_use
//
// DESCRIPTION:
//    operator amount_to_use function for Mono IIR downsampler
//
// INPUTS:
//    - r5 = amount of input data to use
//    - r6 = minimum available input amount
//    - r7 = minimum available output amount
//    - r8  = pointer to operator structure
//
// OUTPUTS:
//    - r5 = amount of input data to use
//    - r8  = pointer to operator structure
//
// TRASHED REGISTERS:
//    r0,r1,r2,r10,I0
//
// *****************************************************************************
.MODULE $M.cbops.mono_iir_downsample.amount_to_use;
   .CODESEGMENT CBOPS_MONO_IIR_DOWNSAMPLE_AMOUNT_TO_USE_PM;

   $cbops.mono_iir_downsample.amount_to_use:

   r2 = M[r8 + $cbops.mono.iir_resample.FILTER_DEFINITION_PTR_FIELD];
   r0 = M[r2 + 6];    // filter.iir_inv_ratio

   // Calculate output for available input
   r1 = r0 * r6 (frac);

   // Correct for calculation inaccuracy and fractional round up
   r1 = r1 - 1;
   if NEG r1 = 0;

   // Limit output to available space
   r5 = r7;
   Null = r5 - r1;
   if GT r5 = r1;

   // Check Reset flag
   Null = M[r8 + $cbops.mono.iir_resample.RESET_FLAG_FIELD];
   if Z rts;
   // Clear IIR buffer
   r10 = 9;
   r2 = M[r8 + $cbops.mono.iir_resample.IIR_HISTORY_BUF_PTR_FIELD];
   I0 = r2;
   L0 = r10;
   r0 = Null;
   do lp_clr_iir;
      M[I0,1] = r0;
   lp_clr_iir:
   L0 = Null;
   // Clear Reset Flag
   M[r8 + $cbops.mono.iir_resample.RESET_FLAG_FIELD] = Null;
   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbops.mono_iir_downsample.main
//
// DESCRIPTION:
//    operator main function for Mono IIR downsampler
//
// INPUTS:
//    - r6  = pointer to the list of input and output buffer pointers
//    - r7  = pointer to the list of buffer lengths
//    - r8  = pointer to operator structure
//    - r10 = the number of samples to generate
//
// OUTPUTS:
//    - r8  = pointer to operator structure
//
// TRASHED REGISTERS:
//    everything
//
// *****************************************************************************
.MODULE $M.cbops.mono_iir_downsample.main;
   .CODESEGMENT CBOPS_MONO_IIR_DOWNSAMPLE_MAIN_PM;
   .DATASEGMENT DM;

   .VAR save;

   $cbops.mono_iir_downsample.main:

   $push_rLink_macro;

   M[save] = r8;
   M0 = 1;
   I2=r8;
   r0=M[I2,M0];                // INPUT_1_START_INDEX_FIELD
   // get the input buffer read address
   r1 = M[r6 + r0];
   // store the value in I0
   I0 = r1,            r4=M[I2,M0];                 // OUTPUT_1_START_INDEX_FIELD
   // get the input buffer length
   r1 = M[r7 + r0];
   // store the value in L0
   L0 = r1, r0 = M[I2,M0];                            // FILTER_DEFINITION_PTR_FIELDy
   // get 'filter' config object
   I3 = r0, r0 = M[I2,M0];                            // INPUT_SCALE_FIELD
   // get the output buffer write address
   r1 = M[r6 + r4];
   // store the value
   I4 = r1,            r2=M[I3,M0];       // fir increment
   // setup FIR filter
   M1 = r2,            r3=M[I3,M0];       // FIR coefficients
   M2 = NULL - M1,     r1=M[I3,M0];       // input scale adjust
   r2 = r2 * 10 (int);
   M3 = r2 - M0;                          // (fir increment)*10 -1
   // get the output buffer length
   r2 = M[r7 + r4];
   // store the value in L0
   L4 = r2,          r2=M[I2,M0];                // OUTPUT_SCALE_FIELD
   // get FIR scaling factor
   r6 = r0 + r1,       r0=M[I3,M0];             // output scale adjust
   // get input scale and sample counter
   r8 = r0 + r2,       r0=M[I3,M0];             // R_out
   // get the R_out, which is a integer
   r7 = r0,            r5=M[I3,M0];              // fractional ratio
   I6 = I3+M0;
   // set up M3 to be used in mirroring fir coefficients
   I3 = r3;
   M3 = M3 + I3;
   M3 = M3 + I3;

   // r10 = Number of output samples to generate
   call $cbops.iir_downsample_common;

   // r4 is number of input samples consumed
   M[$M.cbops.iir_resample_complete.amount_to_use] = r4;
   r8 = M[save];

   // Check if last operator in chain
   r0 = M[r8 + ($cbops.NEXT_OPERATOR_ADDR_FIELD - $cbops.PARAMETER_AREA_START_FIELD)];
   Null = r0 - $cbops.NO_MORE_OPERATORS;
   if NZ jump $pop_rLink_and_rts;

   // If Last operator in chain then set $cbops.amount_to_use to advance input buffer
   M[$cbops.amount_to_use] = r4;
   jump $pop_rLink_and_rts;
.ENDMODULE;







