// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


// *****************************************************************************
// NAME:
//    Upsample and mix operator
//
// DESCRIPTION:
//    This operator mixes a mono/stereo audio stream with some other mono audio
//    stream, e.g. Mix a decoded stereo SBC stream with a tone source from the
//    VM. Furthermore it upsamples the tone stream to match the sample rate of
//    the SBC stream.
//
//    IMPORTANT this operator must not operate directly on ports, ie it must not
//    be the first operator when reading from ports or the last when writing to
//    ports.
//
//    Upsampling occurs in two steps, firstly the audio is upsampled and
//    filtered. If this achieves the desired frequency the result is mixed with
//    the audio stream. If however the desired rate is not a multiple of the
//    initial rate then linear interpolation is applied to reduce the sample rate
//    down to the required rate.
//
//    For example if an 8kHz tone stream is to be mixed with a 44.1 kHz stream
//    the tones are first upsampled to 48kHz and then interpolated down to
//    44.1 kHz.
//
//    To achieve this set the values as:
// @verbatim
//    UPSAMPLE_RATIO_FIELD = 48000.0 / 8000.0 = 6
//    INTERP_RATIO_FIELD   = 48000.0 / 44100.0 - 1 = 0.088
// @endverbatim
//
//    If this operator is to be used to mix tones generated by the VM with
//    an audio stream decoded by the DSP it may be necessary to buffer the tone
//    data in the DSP before passing it to this mixing routine. If this is the
//    case, copy the data into the intermediate buffer WITHOUT applying any
//    shift.
//
// When using the operator the following data structure is used:
//    - $cbops.upsample_mix.INPUT_START_INDEX_FIELD = indexes of input buffers
//       (up to 2 input buffers)
//    - $cbops.upsample_mix.TONE_SOURCE_FIELD = tone source cbuffer/port
//       (address of cbuffer structure or port ID)
//    - $cbops.upsample_mix.TONE_VOL_FIELD = volume to apply to tone data
//       (fractional in range 0 - 1.0)
//    - $cbops.upsample_mix.AUDIO_VOL_FIELD = volume to apply to audio data
//       (fractional in range 0 - 1.0)
//    - $cbops.upsample_mix.RESAMPLE_COEFS_ADDR_FIELD = address of resample
//       filter coefficients
//    - $cbops.upsample_mix.RESAMPLE_COEFS_SIZE_FIELD = size of resample
//       filter coefficients (10 * upsample factor)
//    - $cbops.upsample_mix.RESAMPLE_BUFFER_ADDR_FIELD = address of resample
//       buffer
//    - $cbops.upsample_mix.RESAMPLE_BUFFER_SIZE_FIELD = size of resample
//       buffer ( 10 )
//    - $cbops.upsample_mix.UPSAMPLE_RATIO_FIELD = intermediate upsampling
//       ratio (eg 8k -> 48k = 6)
//    - $cbops.upsample_mix.INTERP_RATIO_FIELD = interpolation ratio
//       (eg (48000.0 / 44100.0) - 1 )
//    - $cbops.upsample_mix.INTERP_COEF_CURRENT_FIELD = updated interpolation
//       coefficient (initialise as 0)
//    - $cbops.upsample_mix.INTERP_LAST_VAL_FIELD = last interpolation data
//       value (initialise as 0)
//    - $cbops.upsample_mix.TONE_PLAYING_STATE_FIELD = tone playing state
//       (initialise as 0)
//    - $cbops.upsample_mix.TONE_DATA_AMOUNT_READ_FIELD = amount of tone data
//       read (initialise as 0)
//    - $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD = amount of tone data
//       available (initialise as 0)
//    - $cbops.upsample_mix.LOCATION_IN_LOOP_FIELD = position in loop
//       producing outputs from inputs (initialise as 0)
//
// *****************************************************************************

#include "stack.h"
#include "cbops.h"

.MODULE $M.cbops.upsample_mix;
   .DATASEGMENT DM;

   // ** function vector **
   .VAR $cbops.upsample_mix[$cbops.function_vector.STRUC_SIZE] =
      &$cbops.upsample_mix.reset,           // reset function
      $cbops.function_vector.NO_FUNCTION,   // amount to use function
      &$cbops.upsample_mix.main;            // main function

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $cbops.upsample_mix.reset
//
// DESCRIPTION:
//    Reset routine for the upsample and mix operator, see
//    $cbops.upsample.main
//
// INPUTS:
//    - r8 = pointer to operator structure
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume all (due to setting the read address of a port)
//
// *****************************************************************************
.MODULE $M.cbops.upsample_mix.reset;
   .CODESEGMENT CBOPS_UPSAMPLE_MIX_RESET_PM;
   .DATASEGMENT DM;

   // ** reset function **
   $cbops.upsample_mix.reset:
   // zero the various state information
   M[r8 + $cbops.upsample_mix.INTERP_COEF_CURRENT_FIELD] = Null;
   M[r8 + $cbops.upsample_mix.INTERP_LAST_VAL_FIELD] = Null;
   M[r8 + $cbops.upsample_mix.TONE_PLAYING_STATE_FIELD] = Null;
   M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD] = Null;
   M[r8 + $cbops.upsample_mix.LOCATION_IN_LOOP_FIELD] = Null;

   // update the tone port if we have read any data
   r2 = M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_READ_FIELD];

   if Z rts;

   // push rLink onto stack
   $push_rLink_macro;

   r0 = M[r8 + $cbops.upsample_mix.TONE_SOURCE_FIELD];
   // Only want to update the read address if it is a port
   Null = SIGNDET r0;
   if Z call $cbuffer.set_read_address;

   M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_READ_FIELD] = Null;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $cbops.upsample_mix.main
//
// DESCRIPTION:
//    Mix mono data with a mono/stereo stream. The mono data can be upsampled to
//    match the sample rate of the stereo stream. An example application is
//    mixing tones genarated by the VM at 8kHz with SBC data decoded by Kalimba
//    at 48kHz.
//
// INPUTS:
//    - r6 = pointer to the list of input and output buffer pointers
//    - r7 = pointer to the list of buffer lengths
//    - r8 = pointer to operator structure
//    - r10 = the number of samples to process
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    Everything
//
// NOTES:
//    This operator can be used to mix mono data with a stereo stream or to mix
//    mono data with a mono stream. For the stereo case set the
//    INPUT_START_INDEX_FIELD as:
// @verbatim
//    .VAR upsample_mix_operator[$cbops.upsample_mix.STRUC_SIZE] =
//           0,   // First input buffer index
//           1,   // Second input buffer index
//           ...
// @endverbatim
//
//    For the mono case set the second channel indices to
//    $cbops.upsample_mix.NO_BUFFER:
// @verbatim
//    .VAR upsample_mix_operator[$cbops.upsample_mix.STRUC_SIZE] =
//           0,
//           $cbops.upsample_mix.NO_BUFFER,
//           0,
//           $cbops.upsample_mix.NO_BUFFER,
//           ...
// @endverbatim
//
//    Some resample filter coefficients are defined as part of the library. Six
//    sets are defined:
// @verbatim
//    Name                                                  Length
//    $cbops.upsample_mix.filter_coefs_x6_high_quality      60
//    $cbops.upsample_mix.filter_coefs_x4_high_quality      40
//    $cbops.upsample_mix.filter_coefs_x2_high_quality      20
//    $cbops.upsample_mix.filter_coefs_x6_low_quality       24
//    $cbops.upsample_mix.filter_coefs_x4_low_quality       16
//    $cbops.upsample_mix.filter_coefs_x2_low_quality       8
// @endverbatim
//    Each set of filters will only be included if they are referenced in your
//    application code.
//
//    As well as the filter coefficients a circular resample buffer is required.
//    This buffer needs to be declared in the application. The size of this
//    buffer is dependent on the quality of filters used, higher quality
//    requires longer filters, lower quality requires shorter filters.
//
//    For each set of filters, high or low quality, a single buffer size is
//    required, independent of upsample rate, hence two constants have been
//    defined, one for use with the high quality filters and one with the low
//    quality filters:
// @verbatim
//    $cbops.upsample_mix.RESAMPLE_BUFFER_LENGTH_HIGH_QUALITY
//    $cbops.upsample_mix.RESAMPLE_BUFFER_LENGTH_LOW_QUALITY
// @endverbatim
//
// *****************************************************************************
.MODULE $M.cbops.upsample_mix.main;
   .CODESEGMENT CBOPS_UPSAMPLE_MIX_MAIN_PM;
   .DATASEGMENT DM;

   // ** main function **
   $cbops.upsample_mix.main:

   // push rLink onto stack
   $push_rLink_macro;

   // start profiling if enabled
   #ifdef ENABLE_PROFILER_MACROS
      .VAR/DM1 $cbops.profile_upsample_mix[$profiler.STRUC_SIZE] = $profiler.UNINITIALISED, 0 ...;
      r0 = &$cbops.profile_upsample_mix;
      call $profiler.start;
   #endif

   // check to see if we are mixing tones
   r0 = M[r8 + $cbops.upsample_mix.TONE_PLAYING_STATE_FIELD];
   if Z jump dont_mix_tone_data;

      // get the offset to the read buffer to use
      r2 = M[r8 + $cbops.upsample_mix.INPUT_START_INDEX_FIELD];
      // get the input buffer read address
      r3 = M[r6 + r2];
      // store the value in I0
      I0 = r3;
      // get the input buffer length
      r4 = M[r7 + r2];
      // store the value in L0
      L0 = r4;

      rFlags = rFlags OR $UD_FLAG;
      r2 = M[r8 + ($cbops.upsample_mix.INPUT_START_INDEX_FIELD + 1)];
      if NEG jump only_one_channel;
         // set the UD flag for stereo
         rFlags = rFlags AND $NOT_UD_FLAG;
         // get the output buffer write address
         r3 = M[r6 + r2];
         // store the value in I5
         I5 = r3;
         // get the output buffer length
         r4 = M[r7 + r2];
         // store the value in L5
         L5 = r4;
      only_one_channel:

      // we are playing tones set the amount of audio to copy
      r7 = r10;

      // set the amount of tone data available
      r0 = M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD];
      I6 = r0;

      // get the interpolation coefficient
      r3 = M[r8 + $cbops.upsample_mix.INTERP_COEF_CURRENT_FIELD];

      // get the tone and audio volume
      r4 = M[r8 + $cbops.upsample_mix.TONE_VOL_FIELD];
      r5 = M[r8 + $cbops.upsample_mix.AUDIO_VOL_FIELD];

      // set up M registers
      M0 = 0;
      M1 = 1;

      r0 = M[r8 + $cbops.upsample_mix.UPSAMPLE_RATIO_FIELD];
      M2 = r0;

      // get the location in the loop
      r2 = M[r8 + $cbops.upsample_mix.LOCATION_IN_LOOP_FIELD];
      if Z r2 = M1;

      // point I3 at the tones source
      r0 = M[r8 + $cbops.upsample_mix.TONE_SOURCE_FIELD];
      call $cbuffer.get_read_address_and_size;
      I3 = r0;
      r6 = r1 - 1;

      // get the filter address and length
      r0 = M[r8 + $cbops.upsample_mix.RESAMPLE_COEFS_ADDR_FIELD];
      I2 = r0;
      I4 = r0 - r2;
      I4 = I4 + M2;
      I4 = I4 + 1;
      r0 = M[r8 + $cbops.upsample_mix.RESAMPLE_COEFS_SIZE_FIELD];
      L4 = r0;

      // get the local buffer address and size
      r0 = M[r8 + $cbops.upsample_mix.RESAMPLE_BUFFER_ADDR_FIELD];
      I1 = r0;
      r0 = M[r8 + $cbops.upsample_mix.RESAMPLE_BUFFER_SIZE_FIELD];
      L1 = r0;

      // -- resample --
      generate_data:

         r2 = r2 - M1;

         if GT jump no_new_data;

            // increment the data counter
            I6 = I6 - M1;
            if NEG jump done;

            // check for wrap on the pointer
            r1 = I3 - r6;
            Null = r1 AND r6;
            if Z M1 = -r6;

            // reset the "location in loop" value
            // and read the new data point
            r2 = M2, r0 = M[I3,M1];

            // restore M1
            M1 = 1;
            r0 = r0 LSHIFT 8;

            // apply the volume setting
            // and move pointer to oldest data - dummy read
            r0 = r0 * r4 (frac), r1 = M[I1,-1];

            // point I4 at the filter
            // and overwrite the oldest data
            I4 = I2, M[I1,M0] = r0;

         no_new_data:

         r10 = L1 - M1;

         // zero rMAC
         // and load the first input data
         // and load the first filter coefficient
         rMAC = 0, r0 = M[I1,M1], r1 = M[I4,M2];

         do loop;
            rMAC = rMAC + r0 * r1, r0 = M[I1,M1], r1 = M[I4,M2];
         loop:

         rMAC = rMAC + r0 * r1, r0 = M[I4,1];

         // interpolation ratio
         r0 = M[r8 + $cbops.upsample_mix.INTERP_RATIO_FIELD];

         // read the old interpolation value
         r1 = M[r8 + $cbops.upsample_mix.INTERP_LAST_VAL_FIELD];

         // write the "new" old interpolation value
         M[r8 + $cbops.upsample_mix.INTERP_LAST_VAL_FIELD] = rMAC;

         r3 = r3 - r0;
         if NEG jump no_data_to_produce;

            // perform the interpolation
            // and read the left input data
            rMAC = rMAC - rMAC * r3, r0 = M[I0,0];
            // interpolation result
            // and read the right input data
            rMAC = rMAC + r1 * r3, r1 = M[I5,0];

            if USERDEF jump no_right;
               // right value
               // and store interpolation result
               rMAC = rMAC + r1 * r5, M[I0,0] = rMAC;

               // save right value
               // and restore interpolation result
               M[I5,1] = rMAC, rMAC = M[I0,0];
            no_right:

            // left value
            rMAC = rMAC + r0 * r5;

            // decrement data counter
            // and save left value
            r7 = r7 - M1, M[I0,1] = rMAC;

            // if we have used up all the audio data rts
            if LE jump done;

            // else go round again
            jump generate_data;

         no_data_to_produce:

         // remove the sign bit
         r3 = r3 LSHIFT 1;
         r3 = r3 LSHIFT -1;

         // offset so we use right value in next loop
         r3 = r3 + r0;

      jump generate_data;

      done:

      // save the location in the loop
      M[r8 + $cbops.upsample_mix.LOCATION_IN_LOOP_FIELD] = r2;

      // save the interpolation coefficient
      M[r8 + $cbops.upsample_mix.INTERP_COEF_CURRENT_FIELD] = r3;

      // need to store the new buffer position
      r0 = I1;
      M[r8 + $cbops.upsample_mix.RESAMPLE_BUFFER_ADDR_FIELD] = r0;

      // restore the USERDEF flag
      rFlags = rFlags AND $NOT_UD_FLAG;

      // store the read pointer in r1 for the set_read_address functions below
      r1 = I3;

      // update the local copies of the tone port data counts
      r0 = I6 + 0;
      if GT jump still_playing;

         // no more tones - set the state to stopped playing
         M[r8 + $cbops.upsample_mix.TONE_PLAYING_STATE_FIELD] = $cbops.upsample_mix.TONE_PLAYING_STATE_STOPPED;

         // zero the amount read and the amount left
         r0 = M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD];
         M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD] = Null;
         r2 = M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_READ_FIELD];
         M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_READ_FIELD] = Null;

         // calculate the amount read
         r2 = r2 + r0;

         // update the port
         r0 = M[r8 + $cbops.upsample_mix.TONE_SOURCE_FIELD];
         // r1 is set above to I3
         // r2 is set above to amount read
         call $cbuffer.set_read_address;

      // pop rLink from stack
      jump finished;

      still_playing:

      // update the amount of tone data left
      r2 = M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD];
      M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD] = r0;

      // calculate the amount we have read
      r2 = r2 - r0;

      // add this to the current total and save
      r0 = M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_READ_FIELD];
      r2 = r2 + r0;

      // work out if the tone source is a cbuffer
      r0 = M[r8 + $cbops.upsample_mix.TONE_SOURCE_FIELD];
      Null = SIGNDET r0;
      if NZ jump update_port;

      // its a port, check if we have read enough
      Null = r2 - $cbops.upsample_mix.TONE_BLOCK_SIZE;
      if NEG jump dont_update_port;

      update_port:
         // set the read address - ask for more data
         // r0 is set above to port number/cbuffer struc
         // r1 is set above to I3
         // r2 is set above to amount read
         call $cbuffer.set_read_address;

         // get the amount of data
         r0 = M[r8 + $cbops.upsample_mix.TONE_SOURCE_FIELD];
         call $cbuffer.calc_amount_data;

         M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD] = r0;
         r2 = 0;

      dont_update_port:

      M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_READ_FIELD] = r2;

      // pop rLink from stack
      jump finished;

   dont_mix_tone_data:

   // find out how much data is in the port
   r0 = M[r8 + $cbops.upsample_mix.TONE_SOURCE_FIELD];
   call $cbuffer.calc_amount_data;

   Null = r0 - $cbops.upsample_mix.TONE_START_LEVEL;
   if NEG jump finished;

   // set the state to playing
   r1 = $cbops.upsample_mix.TONE_PLAYING_STATE_PLAYING;
   M[r8 + $cbops.upsample_mix.TONE_PLAYING_STATE_FIELD] = r1;

   M[r8 + $cbops.upsample_mix.TONE_DATA_AMOUNT_FIELD] = r0;

   finished:

   // zero the length registers we've changed
   L0 = 0;
   L1 = 0;
   L4 = 0;
   // may not have used this but its quicker than checking
   L5 = 0;

   // stop profiling if enabled
   #ifdef ENABLE_PROFILER_MACROS
      r0 = &$cbops.profile_upsample_mix;
      call $profiler.stop;
   #endif

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;


.MODULE $M.cbops.upsample_mix.filter_coefs_x6_high_quality;
   .DATASEGMENT DM;

   // the number of coefficients is given by (QUALITY_FACTOR * UPSAMPLE_RATE * 2)
   // length = 5 * 6 * 2 = 60
   .VAR/DM2CIRC $cbops.upsample_mix.resample_filter_coefs_x6_high_quality[60] =
       0.00175722899824,  0.00430036228218,  0.00672607817759,  0.00765034812859,  0.00566496473423, 0.00000000000000,
      -0.00883395925890, -0.01871565051396, -0.02614655445681, -0.02714208339500, -0.01863508675718, 0.00000000000000,
       0.02585177581496,  0.05234294995253,  0.07039127355578,  0.07080289993573,  0.04739714224298, 0.00000000000000,
      -0.06369562283236, -0.12823724383200, -0.17285403031074, -0.17593958053047, -0.12062082085458, 0.00000000000000,
       0.17942901157812,  0.39733857651378,  0.62252836180971,  0.81881694567653,  0.95256225248778, 1.00000000000000,
       0.95256225248778,  0.81881694567653,  0.62252836180971,  0.39733857651378,  0.17942901157812, 0.00000000000000,
      -0.12062082085458, -0.17593958053047, -0.17285403031074, -0.12823724383200, -0.06369562283236, 0.00000000000000,
       0.04739714224298,  0.07080289993573,  0.07039127355578,  0.05234294995253,  0.02585177581496, 0.00000000000000,
      -0.01863508675718, -0.02714208339500, -0.02614655445681, -0.01871565051396, -0.00883395925890, 0.00000000000000,
       0.00566496473423,  0.00765034812859,  0.00672607817759,  0.00430036228218,  0.00175722899824, 0.00000000000000;

.ENDMODULE;


.MODULE $M.cbops.upsample_mix.filter_coefs_x4_high_quality;
   .DATASEGMENT DM;

   // the number of coefficients is given by (QUALITY_FACTOR * UPSAMPLE_RATE * 2)
   // length = 5 * 4 * 2 = 40
   .VAR/DM2CIRC $cbops.upsample_mix.resample_filter_coefs_x4_high_quality[40] =
       0.00297243636477,  0.00672607817759,  0.00709275949208, -0.00000000000000,
      -0.01383752170577, -0.02614655445681, -0.02418908643613,  0.00000000000000,
       0.03954915425764,  0.07039127355578,  0.06225857462155, -0.00000000000000,
      -0.09707846099711, -0.17285403031074, -0.15629800227656,  0.00000000000000,
       0.28532606017931,  0.62252836180971,  0.89530055642607,  1.00000000000000,
       0.89530055642607,  0.62252836180971,  0.28532606017931,  0.00000000000000,
      -0.15629800227656, -0.17285403031074, -0.09707846099711, -0.00000000000000,
       0.06225857462155,  0.07039127355578,  0.03954915425764,  0.00000000000000,
      -0.02418908643613, -0.02614655445681, -0.01383752170577, -0.00000000000000,
       0.00709275949208,  0.00672607817759,  0.00297243636477,  0.00000000000000;

.ENDMODULE;


.MODULE $M.cbops.upsample_mix.filter_coefs_x2_high_quality;
   .DATASEGMENT DM;

   // the number of coefficients is given by (QUALITY_FACTOR * UPSAMPLE_RATE * 2)
   // length = 5 * 2 * 2 = 20
   .VAR/DM2CIRC $cbops.upsample_mix.resample_filter_coefs_x2_high_quality[20] =
       0.00672607817759, -0.00000000000000,
      -0.02614655445681,  0.00000000000000,
       0.07039127355578, -0.00000000000000,
      -0.17285403031074,  0.00000000000000,
       0.62252836180971,  1.00000000000000,
       0.62252836180971,  0.00000000000000,
      -0.17285403031074, -0.00000000000000,
       0.07039127355578,  0.00000000000000,
      -0.02614655445681, -0.00000000000000,
       0.00672607817759,  0.00000000000000;

.ENDMODULE;


.MODULE $M.cbops.upsample_mix.filter_coefs_x6_low_quality;
   .DATASEGMENT DM;

   // the number of coefficients is given by (QUALITY_FACTOR * UPSAMPLE_RATE * 2)
   // length = 2 * 6 * 2 = 24
   .VAR/DM2CIRC $cbops.upsample_mix.resample_filter_coefs_x6_low_quality[24] =
      -0.00725609990924, -0.02453001685692, -0.04892302716485, -0.06785520848751, -0.05967459621722, 0.00000000000000,
       0.12755510128765,  0.32059310957999,  0.55259688647834,  0.77695041101293,  0.94021075049331, 1.00000000000000,
       0.94021075049331,  0.77695041101293,  0.55259688647834,  0.32059310957999,  0.12755510128765, 0.00000000000000,
      -0.05967459621722, -0.06785520848751, -0.04892302716485, -0.02453001685692, -0.00725609990924, 0.00000000000000;

.ENDMODULE;


.MODULE $M.cbops.upsample_mix.filter_coefs_x4_low_quality;
   .DATASEGMENT DM;

   // the number of coefficients is given by (QUALITY_FACTOR * UPSAMPLE_RATE * 2)
   // length = 2 * 4 * 2 = 16
   .VAR/DM2CIRC $cbops.upsample_mix.resample_filter_coefs_x4_low_quality[16] =
      -0.01462326188680, -0.04892302716485, -0.06872604675108,  0.00000000000000,
       0.21697731202861,  0.55259688647834,  0.86933532633822,  1.00000000000000,
       0.86933532633822,  0.55259688647834,  0.21697731202861,  0.00000000000000,
      -0.06872604675108, -0.04892302716485, -0.01462326188680, -0.00000000000000;

.ENDMODULE;


.MODULE $M.cbops.upsample_mix.filter_coefs_x2_low_quality;
   .DATASEGMENT DM;

   // the number of coefficients is given by (QUALITY_FACTOR * UPSAMPLE_RATE * 2)
   // length = 2 * 2 * 2 = 8
   .VAR/DM2CIRC $cbops.upsample_mix.resample_filter_coefs_x2_low_quality[8] =
      -0.04892302716485,  0.00000000000000,
       0.55259688647834,  1.00000000000000,
       0.55259688647834,  0.00000000000000,
      -0.04892302716485, -0.00000000000000;

.ENDMODULE;





