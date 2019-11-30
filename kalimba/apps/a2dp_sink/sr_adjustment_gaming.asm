// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#include "core_library.h"
#include "cbops_library.h"
#include "codec_library.h"
#include "kalimba_standard_messages.h"

#if defined(APTX_ACL_SPRINT_ENABLE)
#include "codec_decoder_aptx_acl_sprint.h"
#include "sr_adjustment_gaming.h"
#else
#include "codec_decoder_faststream.h"
#include "sr_adjustment_gaming.h"
#endif

// *****************************************************************************
// MODULE:
//    $sra_calcrate
//
// DESCRIPTION:
//    calculates the mistmatch rate between sink and source
// NOTE:
//    the structure is different from MP3/SBC structure
//    rate is calculated based on a target average level for codec cbuffer,
//    this can be inaccurate if frames are lost over the air,
//    however the maximum rate is limited so no effect of warping would be heard
//
// TBD: fine without BYTEPOS info, if is_it_within_range works without BYTEPOS
// *****************************************************************************
.MODULE $M.sra_calcrate;
   .CODESEGMENT MUSIC_EXAMPLE_SRA_CALCRATE_PM;
   .DATASEGMENT DM;

  .VAR mode_funtion_table[] = &idle, &start, &addup;

   $sra_calcrate:

   // push rLink onto stack
   $push_rLink_macro;


      r0 = M[$decoder_codec_stream_struc + $codec.av_decode.CURRENT_RUNNING_MODE_FIELD];
      if Z jump $reset_sra;


   // jump to proper function
   r0 = M[$sra_struct + $sra.RATECALC_MODE_FIELD];
   r0 = M[r0 + mode_funtion_table];
   jump r0;


// -- idle mode function
idle:
   // check if start address has been tagged
   r0 = M[$sra_struct + $sra.CODEC_CBUFFER_START_ADDR_TAG_FIELD];
   // if not stay in idle  mode
   if Z jump end;

   // set mode to start mode and go to start funtion
   r0 = $sra.RATECALC_START_MODE;
   M[$sra_struct + $sra.RATECALC_MODE_FIELD] = r0;

// -- start mode function
start:
   // get the read pointer of codec cbuffer
   r0 = M[$sra_struct + $sra.CODEC_CBUFFER_TO_TAG_FIELD];
   call $cbuffer.get_read_address_and_size;

   // check if start tag address has just passed
   r1 = M[$sra_struct + $sra.CODEC_CBUFFER_PREV_READ_ADDR_FIELD];
   r2 = M[$sra_struct + $sra.CODEC_CBUFFER_START_ADDR_TAG_FIELD];
   call is_it_within_range;

   // stay in start mode if not yet passed
   Null = r3;
   if Z jump end;

 // start tag address just passed
 //clear start tag
 M[$sra_struct + $sra.CODEC_CBUFFER_START_ADDR_TAG_FIELD] = NULL;

 // clear accumulator
 M[$sra_struct + $sra.AUDIO_TOTAL_DECODED_SAMPLES_FIELD] = Null;

 // set next mode to rate_calc mode (addup)
 r0 = $sra.RATECALC_ADD_MODE;
 M[$sra_struct + $sra.RATECALC_MODE_FIELD] = r0;
 jump end;

// -- addup mode function,
//    in this mode the number of PCM samples produced by the decoder is continously counted
//    until an end tag is seen
addup:
  // work out number of  PCM samples has been generated since last time by seeing the amount of movement
  // in write pointer of audio cbuffer
  r0 = M[$sra_struct + $sra.AUDIO_CBUFFER_TO_TAG_FIELD];
  call $cbuffer.get_write_address_and_size;
  r2 = r0 - M[$sra_struct + $sra.AUDIO_CBUFFER_PREV_WRITE_ADDR_FIELD];
  if NEG r2 = r2 + r1;
  // update accumulator
  r1 = r2 + M[$sra_struct + $sra.AUDIO_TOTAL_DECODED_SAMPLES_FIELD];
  M[$sra_struct + $sra.AUDIO_TOTAL_DECODED_SAMPLES_FIELD] = r1;

  // search for end tag
  r2 = M[$sra_struct + $sra.CODEC_CBUFFER_END_ADDR_TAG_FIELD];
  if Z jump end;
  // end tag seen, from now see if it jas just passed
  r0 = M[$sra_struct + $sra.CODEC_CBUFFER_TO_TAG_FIELD];
  call $cbuffer.get_read_address_and_size;
  r1 = M[$sra_struct + $sra.CODEC_CBUFFER_PREV_READ_ADDR_FIELD];
  r2 = M[$sra_struct + $sra.CODEC_CBUFFER_END_ADDR_TAG_FIELD];
  call is_it_within_range;
  Null = r3;
  // if not passed, stay in add-up mode
  if Z jump end;

  // end tag address has just been passed by the decoder, end accumulation and update the rate
  //clear the end tag address
  M[$sra_struct + $sra.CODEC_CBUFFER_END_ADDR_TAG_FIELD] = Null;
  // set new mode to idle mode, it should automatically go to start mode if everything is right
  r0 = $sra.RATECALC_IDLE_MODE;
  M[$sra_struct + $sra.RATECALC_MODE_FIELD] = r0;

  // make sure accumulated value is right
  r2 = M[$sra_struct + $sra.AUDIO_AMOUNT_EXPECTED_FIELD];
  r3 = 1;
  r1 = r2 - M[$sra_struct + $sra.AUDIO_TOTAL_DECODED_SAMPLES_FIELD];
  if NEG r3 = -r3;
  r1 = r1*r3(int);
  r7 = M[$sra_struct + $sra.MAX_RATE_FIELD];
  r7 = r7 * 3 (int);
  r2 = r2 * r7(frac); // twice maximum value
  r2 = r1 - r2;
  // if too big value then ignore it
  if POS jump idle; //r1 = r1 - r2;

  r1 = r1*r3(int);
  // save the diff value into history
  r0 = M[$sra_struct + $sra.HIST_INDEX_FIELD];
  M[r0 + ($sra_struct+$sra.HIST_BUFF_FIELD)] = r1;

  // r0 = update index
  r0 = r0 + 1;
  r0 = r0 AND ($sra.BUFF_SIZE-1);
  M[$sra_struct + $sra.HIST_INDEX_FIELD] = r0;

  // if for the first time buffer is full?
  if NZ jump init_phase_passed;
  r2 = $sra.STEADY_SAVING_MODE;
  M[$sra_struct + $sra.SAVIN_STATE_FIELD] = r2;
  init_phase_passed:

  // if init phase not yet passed, partially average
  r1 = $sra.BUFF_SIZE;
  Null = M[$sra_struct + $sra.SAVIN_STATE_FIELD];
  if NZ r0 = r1;

  calc_final_rate:
  // calculate sum of hist values
  r10 = r0 - 1;
  r3 = 1.0;
  I0 = (&$sra_struct+$sra.HIST_BUFF_FIELD);
  r1 = 0, r2 = M[I0, 1];
  do acc_loop;
     r1 = r1 + r2, r2 = M[I0, 1];
  acc_loop:
  r1 = r1 + r2;

  // r1 = abs(sum), r3 = sign
  if NEG r3 = -r3;
  r1 = r1 * r3 (frac);

  // averaging
  rMAC = 0;
  rMAC0 = r1;
  Div = rMAC / r0;
  r1 = DivResult;

  // rate calculation
  rMAC = r1 ASHIFT -1;
  r2 = M[$sra_struct + $sra.AUDIO_AMOUNT_EXPECTED_FIELD];
  Div = rMAC / r2;
  r1 = DivResult;
  // limit rate
  r2 = r1 - M[$sra_struct + $sra.MAX_RATE_FIELD];
  if POS r1 = r1 - r2;
  // add sign
  r1 = r1 * r3 (frac);
  // set rate
  M[$sra_struct + $sra.RATE_BEFORE_FIX_FIELD] = r1;

  // exit this mode
  jump idle;

end:
 // update previous read pointer for codec cbuffer
 r0 = M[$sra_struct + $sra.CODEC_CBUFFER_TO_TAG_FIELD];
 call $cbuffer.get_read_address_and_size;
 M[$sra_struct + $sra.CODEC_CBUFFER_PREV_READ_ADDR_FIELD] = r0;

 // update previous write pointer for audio cbuffer
 r0 = M[$sra_struct + $sra.AUDIO_CBUFFER_TO_TAG_FIELD];
 call $cbuffer.get_write_address_and_size;
 M[$sra_struct + $sra.AUDIO_CBUFFER_PREV_WRITE_ADDR_FIELD] = r0;

 exit:

  // pop rLink from stack
   jump $pop_rLink_and_rts;

 //r0 = addr1, r1= addr2, r2=addr
 // result: r3
 is_it_within_range:
  r3 = 1;
  Null = r0 - r1;
  if NEG jump neg_part;
  pos_part:

   Null = r2 - r0;
   if POS r3 = 0;
   Null = r2 - r1;
   if NEG r3 = 0;
  rts;

 neg_part:
   Null = r2 - r1;
   if POS rts;
   Null = r2 - r0;
   if POS r3 = 0;

rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $sra_tagtimes
//
// DESCRIPTION:
//    tags the cbuffer contatining codec data, so that rate calculator can measure
//    the amount of PCM samples received in a defined period
//
// *****************************************************************************
.MODULE $M.sra_tagtimes;
   .CODESEGMENT MUSIC_EXAMPLE_SRA_TAGTIMES_PM;
   .DATASEGMENT DM;

  .VAR mode_funtion_table[] = &idle, &counting;

   $sra_tagtimes:

   // push rLink onto stack
   $push_rLink_macro;

   // work out total data in PORT+CBUFFER
   r0 = M[$sra_struct + $sra.CODEC_PORT_FIELD];
   call $cbuffer.calc_amount_data;
   r5 = r0;
   r0 = M[$sra_struct + $sra.CODEC_CBUFFER_TO_TAG_FIELD];
#ifdef USE_PACKED_ENCODED_DATA
   call $packed_cbuffer.calc_amount_data_word16;
#else   // USE_PACKED_ENCODED_DATA
   call $cbuffer.calc_amount_data;
#endif  // USE_PACKED_ENCODED_DATA   
   r5 = r5 + r0;

   // acumulate the codec level for averaging
   r5 = r5 + M[$sra_struct + $sra.BUFFER_LEVEL_ACC_FIELD];
   M[$sra_struct + $sra.BUFFER_LEVEL_ACC_FIELD] = r5;

   // increament counter
   r4 = M[$sra_struct + $sra.BUFFER_LEVEL_COUNTER_FIELD];
   r4 = r4 + 1;
   M[$sra_struct + $sra.BUFFER_LEVEL_COUNTER_FIELD] = r4;

   // averaging is done for 25% of TAG_DURATION (0.5 seconds)
   r1 = M[$sra_struct + $sra.TAG_DURATION_FIELD];
   r1 = r1 * 0.125(frac);
   Null = r4 - r1;
   // time to average?
   if NEG jump no_update_on_buf_level;

   M[$sra_struct + $sra.BUFFER_LEVEL_COUNTER_FIELD] = Null;
   M[$sra_struct + $sra.BUFFER_LEVEL_ACC_FIELD] = Null;
   r0 = M[$sra_struct + $sra.CODEC_CBUFFER_TO_TAG_FIELD];
   r0 = M[r0]; // get the size of buffer
   r0 = r0 * r4 (int); // size*N
#ifdef USE_PACKED_ENCODED_DATA
   // translate size to 16bit word
   r3 = r0 ASHIFT -1;
   r0 = r0 + r3;
#endif   // USE_PACKED_ENCODED_DATA
   rMAC = r5 ASHIFT -1;
   Div = rMAC / r0;   // sum/(N*size)
   r1 = DivResult;
   r4 = M[$sra_struct + $sra.AVERAGE_LEVEL_FIELD];
   M[$sra_struct +$sra.AVERAGE_LEVEL_FIELD] = r1;
   r4 = r1 - r4;
   r0 = M[$sra_struct + $sra.TARGET_LEVEL_FIELD];
   r2 = r1 - r0;
   r2 = r2 * (-0.05)(frac);
   r1 = r2 - 0.005;
   if POS r2 = r2 - r1;
   r1 = r2 + 0.0025;
   if NEG r2 = r2 - r1;
   r7 = 0.0005;
   r6 = M[$sra_struct + $sra.FIX_VALUE_FIELD];
   r0 = r2;
fix_rate:
   // limit the change in fix value
   r1 = r6 + r7;
   NULL = r0 - r1;
   if POS r0 = r1;
   r1 = r6 - r7;
   NULL = r0 - r1;
   if NEG r0 = r1;
   // set the fix value
   M[$sra_struct + $sra.FIX_VALUE_FIELD] = r0;


set_final_rate:
   //set final gain
   r0 = M[$sra_struct + $sra.RATE_BEFORE_FIX_FIELD];
   r0 = r0 + M[$sra_struct + $sra.FIX_VALUE_FIELD];
   // another limit check might be useful again???
   r1 = r0 - M[$sra_struct + $sra.MAX_RATE_FIELD];
   if POS r0 = r0 - r1;
   r1 = r0 + M[$sra_struct + $sra.MAX_RATE_FIELD];
   if NEG r0 = r0 - r1;
   r1 = r0 + 0.015;
   if NEG r0 = r0 - r1;
   r6 = M[$sra_struct + $sra.SRA_RATE_FIELD];
   r1 = r6 + r7;
   NULL = r0 - r1;
   if POS r0 = r1;
   r1 = r6 - r7;
   NULL = r0 - r1;
   if NEG r0 = r1;
   M[$sra_struct + $sra.SRA_RATE_FIELD] = r0;

no_update_on_buf_level:

   r0 = M[$sra_struct + $sra.CODEC_PORT_FIELD];
   call $cbuffer.calc_amount_data;
   r3 = r0;

   // update no data counter
   r0 = M[$sra_struct+ $sra.NO_CODEC_DATA_COUNTER_FIELD];
   r0 = r0 + 1;
   Null = r3;
   if NZ r0 = 0;
   M[$sra_struct+ $sra.NO_CODEC_DATA_COUNTER_FIELD] = r0;

   // rest sra if no activity during past NO_ACTIVITY_PERIOD perio
   Null = r0 - $sra.NO_ACTIVITY_PERIOD;
   if NEG jump no_reset_sra;
   M[$sra_struct + $sra.FIX_VALUE_FIELD] = Null;
   jump $reset_sra;

no_reset_sra:
   // increment active period counter
   r0 = M[$sra_struct + $sra.ACTIVE_PERIOD_COUNTER_FIELD];
   r1 = $sra.ACTIVITY_PERIOD_BEFORE_START + 10;
   r0 = r0 + 1;
   Null = r0 - r1;
   if POS r0 = r1;
   M[$sra_struct + $sra.ACTIVE_PERIOD_COUNTER_FIELD] = r0;

   // jump to the proper mode
   r0 = M[$sra_struct + $sra.MODE_FIELD];
   r0 = M[r0 + mode_funtion_table];
   jump r0;

// -- idele mode function
 idle:
   // switch to start mode only if it has been active during past ACTIVITY_PERIOD_BEFORE_START
   r0 = M[$sra_struct + $sra.ACTIVE_PERIOD_COUNTER_FIELD];
   Null = r0 - $sra.ACTIVITY_PERIOD_BEFORE_START;
   if POS jump start;
   jump end;

// -- start mode function
start:


   // tag start point so it can be used for rate calc thread
   r0 = M[$sra_struct + $sra.CODEC_CBUFFER_TO_TAG_FIELD];
   call $cbuffer.get_write_address_and_size;
   M[$sra_struct + $sra.CODEC_CBUFFER_START_ADDR_TAG_FIELD]= r0;

   // and go to counting mode
   r0 = $sra.COUNTING_MODE;
   M[$sra_struct + $sra.MODE_FIELD] = r0;
   M[$sra_struct + $sra.TAG_TIME_COUNTER_FIELD] = Null;

// -- counting mode function
 counting:
   // increament the counter
   r0 = M[$sra_struct + $sra.TAG_TIME_COUNTER_FIELD];
   r0 = r0 + 1;
   M[$sra_struct + $sra.TAG_TIME_COUNTER_FIELD] = r0;
   // time to end counting?
   r0 = r0 - 1;
   Null = r0 - M[$sra_struct + $sra.TAG_DURATION_FIELD];
   if NEG jump end;

   //now pcm thread shouldnt be in idle mode, if so reset
   r0 = M[$sra_struct + $sra.RATECALC_MODE_FIELD];
   Null = r0 - $sra.RATECALC_ADD_MODE;
   if NZ jump  $reset_sra;

   // tag  end point address
   r0 = M[$sra_struct + $sra.CODEC_CBUFFER_TO_TAG_FIELD];
   call $cbuffer.get_write_address_and_size;
   M[$sra_struct + $sra.CODEC_CBUFFER_END_ADDR_TAG_FIELD]= r0;

   // jump idle to restart
   jump idle;

end:
   // pop rLink from stack
   jump $pop_rLink_and_rts;

  $reset_sra:
  M[$sra_struct + $sra.ACTIVE_PERIOD_COUNTER_FIELD] = Null;
  M[$sra_struct + $sra.RATECALC_MODE_FIELD] = Null;
  M[$sra_struct + $sra.CODEC_CBUFFER_END_ADDR_TAG_FIELD] = Null;
  M[$sra_struct + $sra.CODEC_CBUFFER_START_ADDR_TAG_FIELD] = Null;
  M[$sra_struct + $sra.MODE_FIELD] = Null;

  jump $pop_rLink_and_rts;

.ENDMODULE;

// In order to support Slave I2S we need additional code to calculate and
// update the output sampling rate (for master I2S operation or
// DAC without H/W warping this is normally a constant value
// since the output rate is determined by the internal system clock).
// The following code can be used in the output copy handler to
// perform this operation

.MODULE $M.slave_output_rate_op;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

    // ** function vector **
   .VAR $slave_output_rate_op[$cbops.function_vector.STRUC_SIZE] =
      $cbops.function_vector.NO_FUNCTION,       // reset function
      $slave_output_rate_op.amount_to_use,      // amount to use function
      $slave_output_rate_op.main;               // main function

// *****************************************************************************
// MODULE:
//   $slave_output_rate_op.amount_to_use
//
// DESCRIPTION:
//   Slave output rate calculation amount to use function
//
// INPUTS:
//    - r5 = the minimum of the number of input samples available and the
//      amount of output space available
//    - r6 = the number of input samples available
//    - r7 = the amount of output space available
//    - r8 = pointer to operator structure
//
// OUTPUTS:
//    none (r5-r8, r10) preserved
//
// TRASHED REGISTERS:
//    r0
//
// *****************************************************************************
$slave_output_rate_op.amount_to_use:

   // Push rLink onto stack
   $push_rLink_macro;

   // Wait for Port to connect
   r0 = M[r8 + $slave_output_rate_op.PORT_OFFSET];

   // Check if the port is enabled (Z: disabled, NZ: enabled)
   call $cbuffer.is_it_enabled;
   if Z jump restart;

      // Increment Period Counter
      r0 = M[r8 + $slave_output_rate_op.PERIOD_COUNTER_OFFSET];
      r0 = r0 + 1;
      M[r8 + $slave_output_rate_op.PERIOD_COUNTER_OFFSET] = r0;

      // If negative, wait for settle time to complete
      if NEG jump exit;

      // Wait for completion of sample collection
      r1 = M[r8 + $slave_output_rate_op.ACCUMULATOR_DURATION_OFFSET];
      null = r0 - r1;
      if NEG jump exit;

      // Load number of samples output
      r0 = M[r8 + $slave_output_rate_op.ACCUMULATOR_OFFSET];

      // Accumulator contains the total number of output samples in given period
      // Configure the sra amount expected with this number of samples
      M[$sra_struct + $sra.AUDIO_AMOUNT_EXPECTED_FIELD] = r0;

      jump rate_ok;

   restart:

#ifdef DEBUG_SLAVE_OUTPUT_RATE_OP_ON
   .VAR $debug_slave_output_rate_op_restart_count;
   r0 = M[$debug_slave_output_rate_op_restart_count];
   r0 = r0 + 1;
   M[$debug_slave_output_rate_op_restart_count] = r0;
#endif

   rate_ok:

   // Reset ready for another period
   M[r8 + $slave_output_rate_op.ACCUMULATOR_OFFSET] = 0;
   M[r8 + $slave_output_rate_op.PERIOD_COUNTER_OFFSET] = 0;

   exit:

   // Pop rLink from stack
   jump $pop_rLink_and_rts;

// *****************************************************************************
// MODULE:
//    $slave_output_rate_op.main
//
// DESCRIPTION:
//    Accumulate data transfered to port
//
// INPUTS:
//    - r5 = pointer to the list of input and output buffer start addresses
//    - r6 = pointer to the list of input and output buffer pointers
//    - r7 = pointer to the list of buffer lengths
//    - r8 = pointer to operator structure
//    - r10 = the number of samples to process
//
// OUTPUTS:
//    none (r5-r8, r10) preserved
//
// TRASHED REGISTERS:
//    r0, r1, r2
//
// *****************************************************************************
$slave_output_rate_op.main:

   // Push rLink onto stack
   $push_rLink_macro;

   null = M[r8 + $slave_output_rate_op.PERIOD_COUNTER_OFFSET];
   if NEG rts;

   // How much data (l(n) = current fill level) in the output port?
   r0 = M[r8 + $slave_output_rate_op.PORT_OFFSET];
   call $cbuffer.calc_amount_space;
   r0 = r2 - r1;                       // Amount of data in bytes (calculate fill_level = buf_size - buf_space)
   push r3;
   r3 = M[r8 + $slave_output_rate_op.PORT_OFFSET];
   r2 = r0;
   // Convert to samples (in: r2 = octets, r3 = port config; out r2 = samples)
   call $cbuffer.mmu_octets_to_samples;
   pop r3;
   r0 = r2;

   // Get the previous fill level
   r1 = M[r8 + $slave_output_rate_op.PREV_PORT_FILL_LEVEL_OFFSET];

   // Save the current fill level
   M[r8 + $slave_output_rate_op.PREV_PORT_FILL_LEVEL_OFFSET] = r0;

   // Calculate the number of words read from the port since the last call
   r1 = r1 - r0;                       // l(n-1) - l(n)
   r1 = r1 + r10;                      // Read = (n-1) - l(n) + Written

   // Accumulate the number of samples read from the port (i.e. the port consumption)
   r0 = M[r8 + $slave_output_rate_op.ACCUMULATOR_OFFSET];
   r0 = r0 + r1;
   M[r8 + $slave_output_rate_op.ACCUMULATOR_OFFSET] = r0;

   // Pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.calc_sra_resampling_adjustment
//
// DESCRIPTION:
// Calculate the adjustment factor needed to modify the SRA output amount
// expected value in accordance with the resampling factor. This is needed since
// the SRA calculation is based on the codec output rate (not the dac output rate).
// Used for a2dp and SPDIF input
//
// Calculate a scaling factor to compensate for the resampling function:
//
//    adjusted_audio_amount_expected = audio_amount_expected * codec_rate / dac_rate
//
// This adjustment factor is pre-calculated and expressed as two values
// one integer and one fractional:
//
//    sra_resamp_adjust_int
// and
//    sra_resamp_adjust_frac
//
// such that:
//
//    adjusted_audio_amount_expected = audio_amount_expected * (resamp_adjust_int + resamp_adjust_frac)
//
// where
//
// For downsampling: resamp_adjust_int = 0, with the fractional part in resamp_adjust_frac
// For upsampling: resamp_adjust_int > 0, with the fractional part in resamp_adjust_frac
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// *****************************************************************************
.MODULE $M.calc_sra_resampling_adjustment;
   .CODESEGMENT CALC_SRA_RESAMPLING_ADJUSTMENT_PM;
   .DATASEGMENT DM;

   .CONST frac_shift                2; // Shift to allow in range fractional divide

   // SRA adjustment factors to compensate for the resampling function
   .VAR $sra_resamp_adjust_int  = 1;
   .VAR $sra_resamp_adjust_frac = 0.0;

   $calc_sra_resampling_adjustment:

   pushm <rMAC, r0, r1, r2, r3>;       // Save regs

   r0 = M[$current_codec_sampling_rate];
   r1 = M[$current_dac_sampling_rate];

   // Defaults for no resampling
   r2 = 1;                             // Integer adjustment factor
   r3 = 0.0;                           // Fractional adjustment factor

   // Upsampling?
   null = r0 - r1;
   if Z jump no_resampling;            // Use defaults if no resampling
   if NEG jump upsampling;

      // Scale to allow a fractional divide
      r0 = r0 LSHIFT -frac_shift;

      // (codec_rate >> frac_shift) / dac_rate
      rMAC = r0 LSHIFT -1;             // Shift to correct fractional divide
      Div = rMAC / r1;
      r0 = DivResult;

      // Calculate the integer and fractional parts
      r2 = r0 LSHIFT (-23 + frac_shift);
      r0 = r0 AND ((1 << (23 - frac_shift)) - 1);
      r3 = r0 LSHIFT frac_shift;

      jump done;

   upsampling:

      // codec_rate / dac_rate
      rMAC = r0 LSHIFT -1;             // Shift to correct fractional divide
      Div = rMAC / r1;
      r2 = 0;
      r3 = DivResult;

   no_resampling:
   done:

   // Set the SRA resampling adjustment factors
   M[$sra_resamp_adjust_int] = r2;
   M[$sra_resamp_adjust_frac] = r3;

   popm <rMAC, r0, r1, r2, r3>;       // Restore regs

   rts;

.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $M.apply_sra_resampling_adjustment
//
// DESCRIPTION:
// Calculate the adjustment factor needed to modify the SRA output amount
// expected value in accordance with the resampling factor. This is needed since
// the SRA calculation is based on the codec output rate (not the dac output rate).
//
// INPUTS:
//    - r0 = expected sample rate
//
// OUTPUTS:
//    - r0 = None
// *****************************************************************************
.MODULE $M.apply_sra_resampling_adjustment;
   .CODESEGMENT APPLY_SRA_RESAMPLING_ADJUSTMENT_PM;
   $apply_sra_resampling_adjustment:

#ifndef SPDIF_ENABLE
   // No need for rate adjustment compensation since the output rate is measured (after resampler)
   r0 = r0 * SRA_AVERAGING_TIME (int);
   M[$sra_struct + $sra.AUDIO_AMOUNT_EXPECTED_FIELD] = r0;
   rts;
#else

#ifdef  MERGE_SPDIF_SBC
     r1 = M[$app_config.io];
     Null = r1 - $SPDIF_IO;
     if Z  jump  apply_spdif_sra_adj;
     // No need for rate adjustment compensation since the output rate is measured (after resampler)
     r0 = r0 * SRA_AVERAGING_TIME (int);
     M[$sra_struct + $sra.AUDIO_AMOUNT_EXPECTED_FIELD] = r0;
     rts;
apply_spdif_sra_adj:
#endif // MERGE_SPDIF_SBC
   // Need rate adjustment compensation for SPDIF

   // Get the resampler adjustment factors
   r1 = M[$sra_resamp_adjust_int];
   r2 = M[$sra_resamp_adjust_frac];

   // Apply the pre-calculated adjustment factors
   r1 = r0 * r1 (int);
   r2 = r0 * r2 (frac);
   r0 = r1 + r2;

   // see if it has changed
   r1 = M[$spdif_sra_struct + $spdif_sra.EXPECTED_SAMPLE_RATE_FIELD];
   Null = r0 - r1;
   if Z rts;

   // save new expected rate and compute inverse
   $push_rLink_macro;
   M[$spdif_sra_struct + $spdif_sra.EXPECTED_SAMPLE_RATE_FIELD] = r0;
   call $latency.calc_inv_fs;
   M[$spdif_sra_struct + $spdif_sra.EXPECTED_SAMPLE_RATE_INV_FIELD] = r0;
   jump $pop_rLink_and_rts;
   #endif
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $calc_actual_port_rate
//
// DESCRIPTION:
//    Calculate the number of samples consumed by the output port in the
//    SRA_AVERAGING_TIME. This configures the S/W rate matching structure
//    to cope with 'slave' output devices (e.g. I2S slave) where the sampling
//    rate is derived externally. However, it can also be used for 'master'
//    output devices (e.g. I2S master or DAC without H/W warping) - these could
//    use a known constant number of samples since the output sampling rate
//    is only determined by the internal system clock.
//
//    How to use:
//
//    A call to $calc_actual_port_rate should be placed at the start of
//    the output timer interrupt handler to ensure timing accuracy (don't
//    want timing variation caused by code executed earlier in the handler).
//
//
// INPUTS:
//    - r8 = pointer to $calc_actual_port_rate data structure
//
// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    r0, r1, r2, r3, rMAC
//
// *****************************************************************************
.MODULE $M.calc_actual_samples;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR state_tab[] = reset, wait, run;

   $calc_actual_port_rate:

   // Push rLink onto stack
   $push_rLink_macro;

   // if we have been explicitly told that this is a master interface
   // then use the nominal rate and return immediately
   rMAC = M[r8 + $calc_actual_port_rate.MASTER_RATE_PTR_FIELD];
   if Z jump measure_rate;
   rMAC = M[rMAC];
   if Z jump measure_rate;
      M[r8 + $calc_actual_port_rate.STATE_FIELD] = 0;
      M[r8   + $calc_actual_port_rate.ACCUMULATOR_REMAINDER_FIELD] = 0;
      rMAC = rMAC ASHIFT 4;
   jump set_rate;

   measure_rate:
   // Get the state and jump to the associated routine
   r0 = M[r8 + $calc_actual_port_rate.STATE_FIELD];
   r0 = M[state_tab + r0];
   jump r0;

   // Function executed when in reset state
   // -------------------------------------------------------------------------------
   reset:
   // Next state is WAIT
   r0 = $calc_actual_port_rate.WAIT;
   M[r8 + $calc_actual_port_rate.STATE_FIELD] = r0;
   M[r8 + $calc_actual_port_rate.ACCUMULATOR_FIELD] = 0;
   M[r8   + $calc_actual_port_rate.ACCUMULATOR_REMAINDER_FIELD] = 0;
   r0 = M[$TIMER_TIME];
   M[r8 + $calc_actual_port_rate.START_TIME_FIELD] = r0;

   jump exit;

   // Function executed when in wait state
   // -------------------------------------------------------------------------------
   wait:

   // calc how long we have been in waiting mode
   r0 = M[$TIMER_TIME];
   r1 = M[r8 + $calc_actual_port_rate.START_TIME_FIELD];
   r1 = r0 - r1;
   r1 = ABS r1;

   // get waiting time setting
   r3 = 100000; // default waiting time
   r2 = M[r8 + $calc_actual_port_rate.WAIT_DURATION_FIELD];
   if LE r2 = r3;


   // Check if the wait period is complete
   null = r1 - r2;
   if NEG jump exit;

   // set start time for run mode
   M[r8 + $calc_actual_port_rate.START_TIME_FIELD] = r0;

   // Next state is RUN
   r0 = $calc_actual_port_rate.RUN;
   M[r8 + $calc_actual_port_rate.STATE_FIELD] = r0;
   M[r8 + $calc_actual_port_rate.ACCUMULATOR_FIELD] = 0;

   // How much data (l(n) = current fill level) in the output port?
   r0 = M[r8 + $calc_actual_port_rate.PORT_FIELD];
   r0 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
   r0 = M[($cbuffer.write_port_limit_addr - $cbuffer.WRITE_PORT_OFFSET) + r0];
   // make sure the port is valid
   if Z jump reset;
   r0 = M[r0];

   // Save the port read pointer
   M[r8 + $calc_actual_port_rate.PREV_PORT_READ_PTR_FIELD] = r0;

   jump exit;

   // Function executed when in run state
   // -------------------------------------------------------------------------------
   run:

   // Save the time now
   r3 = M[$TIMER_TIME];

   // How much data (l(n) = current fill level) in the output port?
   r0 = M[r8 + $calc_actual_port_rate.PORT_FIELD];
   call $cbuffer.calc_amount_space;

   // Get the port read pointer value
   r0 = M[r8 + $calc_actual_port_rate.PORT_FIELD];
   r0 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
   r0 = M[($cbuffer.write_port_limit_addr - $cbuffer.WRITE_PORT_OFFSET) + r0];
   // make sure the port is valid
   if Z jump reset;
   r0 = M[r0];

   // Calculate how many bytes have been read since the last timer interrupt
   // (and adjust for wrap around)
   r1 = M[r8 + $calc_actual_port_rate.PREV_PORT_READ_PTR_FIELD];
   r1 = r0 - r1;
   if NEG r1 = r1 + r2;                                     // Adjust wrap around by adding port size (in bytes)

   // Save the port read pointer
   M[r8 + $calc_actual_port_rate.PREV_PORT_READ_PTR_FIELD] = r0;

   // Get the result in samples
   push r3;
   r3 = M[r8 + $calc_actual_port_rate.PORT_FIELD];
   r2 = r1;
   // Convert to samples (in: r2 = octets, r3 = port config; out r2 = samples)
   call $cbuffer.mmu_octets_to_samples;
   pop r3;
   r1 = r2;

   r0 = M[r8 + $calc_actual_port_rate.ACCUMULATOR_FIELD];     //
   r0 = r0 + r1;                                              // Accumulate
   M[r8 + $calc_actual_port_rate.ACCUMULATOR_FIELD] = r0;     //

   // Restore the time (held in r3)
   r1 = r3;
   r2 = M[r8 + $calc_actual_port_rate.START_TIME_FIELD];
   r3 = r1 - r2;
   r3 = ABS r3;

   // Check if the calculation period is complete
   rMAC = 1000000;
   r2 = M[r8 + $calc_actual_port_rate.ACCUMULATOR_DURATION_FIELD];
   if Z r2 = rMAC;

   null = r3 - r2;
   if NEG jump exit;
      M[r8 + $calc_actual_port_rate.START_TIME_FIELD] = r1;
      // r0 = total samples received
      // r3 = duration in microsecond
      // calculate fs = samples/seconds=r2*1e6/r3
      r2 = M[r8 + $calc_actual_port_rate.ACCUMULATOR_REMAINDER_FIELD];
      rMAC = 0;
      rMAC0 = r2;
      rMAC = rMAC + r0 * 8000000;
      Div = rMAC / r3;
      r0 = DivRemainder;
      M[r8   + $calc_actual_port_rate.ACCUMULATOR_REMAINDER_FIELD] = r0;
      rMAC = DivResult;
   set_rate:
      M[r8 + $calc_actual_port_rate.SAMPLE_RATE_HIRES_FIELD] = rMAC;
      rMAC = rMAC ASHIFT -4 (56bit);
      M[r8 + $calc_actual_port_rate.SAMPLE_RATE_FIELD] = rMAC;
      M[r8 + $calc_actual_port_rate.ACCUMULATOR_FIELD] = 0;
   exit:

   // Pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
#if SPDIF_ENABLE
#include "spdif_library.h"
// *****************************************************************************
// MODULE:
//    $spdif_sra.calc_rate
//
// DESCRIPTION:
//   calculate the mismatch between the input SPDIF interface and the
//   output interface, the result is used to perform rate matching between
//   source and sink devices.
//
// INPUTS:
//   r7 = amount of new data copied from spdif ports
//
// OUTPUTS:
//   None
//
// TRASHED REGISTERS:
//    assume everything
//
//  NOTE:
//   mismatch rate is calculated based on the average flow of data received
//   from spdif input interface compared the sampling rate. It assumes the
//   consumer clock is synchronised to local clock.
//
//   It also adds a fixing value to mismatch rate in order to keep the latency
//   of the system close to a target level. The fixing value is only temporarily
//   and should converge to zero when the target latency is achieved.
// *****************************************************************************
.MODULE $M.spdif_sra_calc_rate;
   .CODESEGMENT SPDIF_SRA_CALC_RATE_PM;
   .DATASEGMENT DM;

   $spdif_sra.calc_rate:

   // push rLink onto stack
   $push_rLink_macro;

   // r8 = input structure
   r8 = &$spdif_sra_struct;

   // when stream is invalid no further data is received
   Null = M[$spdif_copy_struct + $spdif.frame_copy.STREAM_INVALID_FIELD];
   if Z jump calc_sra_rate;

   // reset sra hist
   M[r8 + $spdif_sra.RATE_BEFORE_FIX_FIELD] = 0;

   // gradually reset the fix rate
   r1 = M[r8 + $spdif_sra.FIX_RATE_FIELD];
   r1 = r1 ASHIFT -1;
   M[r8 + $spdif_sra.FIX_RATE_FIELD] = r1;
   jump rate_calc_done;

   calc_sra_rate:

   // calc the average latency
   r4 = M[r8 + $spdif_sra.CURRENT_LATENCY_PTR_FIELD];
   r1 = M[r8 + $spdif_sra.AVERAGE_LATENCY_FIELD];
   r4 = M[r4];
   rMAC = r4 * 0.3;
   rMAC = rMAC + r1*0.7;
   M[r8 + $spdif_sra.AVERAGE_LATENCY_FIELD] = rMAC;

   // see how far latency can be increased
   r0 = $spdif_in_cbuffer_struc;
   call $cbuffer.calc_amount_space;
   r2 = M[$spdif_copy_struct + $spdif.frame_copy.INV_SAMPLING_FREQ_FIELD];
   rMAC = r0 * r2;
   rMAC = rMAC ASHIFT 6;
   r0 = rMAC;

   // r0 = latency left in the input buffer
   // do an averaging
   r1 = M[r8 + $spdif_sra.AVERAGE_LATENCY_LEFT_FIELD];
   r2 = 0.99;     // fast track for low space
   r3 = 0.01;     // slow track for high space
   Null = r1 - r0;
   if POS r3 = r2;
   r2 = 1.0 - r3;
   rMAC = r0 * r3;
   rMAC = rMAC + r1*r2;
   M[r8 + $spdif_sra.AVERAGE_LATENCY_LEFT_FIELD] = rMAC;

   // set the target latency
   // modified target latency =
   //     min (requested_target_latency,
   //          current_latency + space_left - 10ms)
   //
   r0 = M[r8 + $spdif_sra.AVERAGE_LATENCY_FIELD];
   r0 = r0 + rMAC;
   r4 = r0 - 10000;
   r3 = M[r8 + $spdif_sra.TARGET_LATENCY_MS_FIELD];
   r3 = r3 * 1000 (int);
   Null = r3 - r4;
   if POS r3 = r4;

   // r3 = modified target latency
   rMAC = M[r8 + $spdif_sra.AVERAGE_LATENCY_FIELD];
   r0 = r3 - rMAC;

   // stop fixing the rate if the latency is very
   // close to the target
   r2 = ABS r0;

   // scale, how fast we want to fix it
   r0 = r0 * 200 (int)(sat);
   r0 = r0 ASHIFT -1;

   NULL = M[r8 + $spdif_sra.LATENCY_CONVERGED_FIELD];
   if Z jump not_converged;
   converged:
      // see if exited the convergence outer limits
      Null = r2 - (SPDIF_LATENCY_CONVERGE_US*3);
      if POS jump not_converged;
      r0 = r0 * 5 (int);
      r6 = r0 * r0 (frac);
      r0 = r0 * r6 (frac);
      r2 = 1;
      M[r8 + $spdif_sra.LATENCY_CONVERGED_FIELD] = r2;
      jump converge_check_done;

   not_converged:
      // see if entered converged inner limits
      Null = r2 - SPDIF_LATENCY_CONVERGE_US;
      if NEG jump converged;
      r6 = r0 ASHIFT 24;
      r0 = r0 * r0(frac);
      r0 = r0 * r6(frac);
      M[r8 + $spdif_sra.LATENCY_CONVERGED_FIELD] = 0;
   converge_check_done:

   // limit fixing range,
   // capped at compensation for max 10ms diff
   r1 = r0 - 0.01;
   if POS r0 = r0 - r1;
   r1 = r0 + 0.01;
   if NEG r0 = r0 - r1;

   // get current fixing value
   r1 = M[r8 + $spdif_sra.FIX_RATE_FIELD];

   // r0 = new fixing value
   // r1 = old fixing value
   // move slightly towards new value
   r4 = r0 - r1;
   r4 = r4 *(1.0/32)(frac);
   r1 = r1 + r4;
   Null = r4;
   if Z r1 = r0;
   M[r8 + $spdif_sra.FIX_RATE_FIELD] = r1;

   // mismatch-rate = 1.0 - measured_rate/expected_rate;
   r0 = M[$spdif_copy_struct + $spdif.frame_copy.MEASURED_SAMPLING_FREQ_FIELD];
   rMAC = M[$spdif_copy_struct + $spdif.frame_copy.SAMPLING_FREQ_FIELD];
   r1 = M[$spdif_copy_struct + $spdif.frame_copy.INV_SAMPLING_FREQ_FIELD];
   r3 = M[r8 + $spdif_sra.EXPECTED_SAMPLE_RATE_INV_FIELD];
   r2 = M[r8 + $spdif_sra.EXPECTED_SAMPLE_RATE_FIELD];
   if NZ rMAC = r2;
   if NZ r1 = r3;
   // dif = expected_rate - measured_rate
   rMAC = rMAC - r0;
   // dif/expected_rate
   rMAC = rMAC * r1;
   rMAC = rMAC ASHIFT 15 (56bit);
   r0 = rMAC * 0.524288(frac);
   r4 = M[r8 + $spdif_sra.RATE_BEFORE_FIX_FIELD];
   rMAC = r0 * 0.005;
   rMAC = rMAC + r4*0.995;
   M[r8 + $spdif_sra.RATE_BEFORE_FIX_FIELD] = rMAC;

   rate_calc_done:
   // get the mismatch rate
   r4 = M[r8 + $spdif_sra.RATE_BEFORE_FIX_FIELD];
   r4 = r4 * (1/16.0)(frac);

   // add previously computed fixing value
   r3 = M[r8 + $spdif_sra.FIX_RATE_FIELD];
   r4 = r4 + r3;

   // limit max and min mismatch rate to compensate
   r0 = M[r8 + $spdif_sra.MAX_RATE_FIELD];
   r3 = r4 - r0;
   if POS r4 = r4 - r3;
   r3 = r4 + r0;
   if NEG r4 = r4 - r3;

   // store mismatch value, this will be used by rate matching module
   M[r8 + $spdif_sra.SRA_RATE_FIELD] = r4;

   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
#endif
// *****************************************************************************
// MODULE:
//   $pcm_sync_calc_rate
//
// DESCRIPTION:
//
//    calculate the rate to match a pcm output to another(reference) pcm output
//
//                    --------- process 1 ----> pcm output
//                    |
//   pcm input ------>|
//                    |
//                    --------- process 2 -----> pcm reference output
//
//   it will try to apply a rate to the output so its consumption rate follows the
//   consumption rate at reference output. It works based on measuring the latency
//   difference in the two links, and trying to maintaining that close to 0 or
//   a configurable target value. The reference can be 'None', in that case the
//   sra will try to maintain the latency in main link close to a target value
//
//   INPUT:
//       r8 = pcm_sync input structure
//
//   NOTE:
//       This function shall not be called from an ISR
//
// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    assume everything except r8
//
// *****************************************************************************
.MODULE $M.pcm_sync_calcrate;
   .CODESEGMENT PCM_SYNC_CALC_RATE_PM;
   .DATASEGMENT DM;

   $pcm_sync_calc_rate:

   // push rLink onto stack
   $push_rLink_macro;

   // block interrupts to read latencies
   call $block_interrupts;

      // see how much time has passed since last handle
      r4 = M[$TIMER_TIME];
      r1 = M[r8 +$pcm_sync.PREV_TIME_FIELD];
      r2 = r4 - r1;
      if NEG r2 = -r2;
      r3 = M[r8 + $pcm_sync.CALC_PERIOD_FIELD];
      Null = r2 - r3;
      if POS jump read_latency;

      // too early to update the rate
      call $unblock_interrupts;
      jump $pop_rLink_and_rts;
      read_latency:

      // update last calc time
      r1 = r1 + r3;
      r2 = r1 - r4;
      if NEG r2 = -r2;
      Null = r2 - r3;
      if POS r1 = r4;
      M[r8 +$pcm_sync.PREV_TIME_FIELD] = r1;

      // calc latency for output stream 1
      push r8;
      r7 = M[r8 +$pcm_sync.ADJ_CHANNEL_PCM_LATENCY_STRUCT_FIELD];
      call $latency.calc_pcm_latency;
      pop r8;
      push r6;

      // calc latency for output stream 2 (second stream can be none)
      r6 = 0;
      push r8;
      r7 = M[r8 +$pcm_sync.REF_CHANNEL_PCM_LATENCY_STRUCT_FIELD];
      if NZ call $latency.calc_pcm_latency;
      pop r8;
      pop r7;

      // r3 = diff latency
      r3 = r6 - r7;

   call $unblock_interrupts;

   // store measured diff latency (for monitoring)
   M[r8 + $pcm_sync.DIFF_LATENCY_FIELD] = r3;

   // get the target latency
   r0 = M[r8 +$pcm_sync.TARGET_LATENCY_US_FIELD];
   r3 = r3 - r0;
   // limit the latency diff to 10ms
   r1 = 10000;
   r3 = MIN r1;
   r1 = -10000;
   r3 = MAX r1;

   // stop fixing the rate if the latency is very
   // close to the target value
   r2 = ABS r3;

   // scale, how fast we want to fix it
   // big values could cause overshoot
   r0 = r3 * 400 (int)(sat);
   r0 = r0 ASHIFT -1;
   NULL = M[r8 +$pcm_sync.LATENCY_CONVERGED_FIELD];
   if Z jump not_converged;
   converged:
      // see if exited the convergence outer limits
      Null = r2 - (PCM_SYNC_LATENCY_CONVERGE_US*3);
      if POS jump not_converged;
      r0 = r0 * 5 (int);
      r6 = r0 * r0 (frac);
      r0 = r0 * r6 (frac);
      r2 = 1;
      M[r8 +$pcm_sync.LATENCY_CONVERGED_FIELD] = r2;
      jump converge_check_done;

   not_converged:
      // see if entered converged inner limits
      Null = r2 - PCM_SYNC_LATENCY_CONVERGE_US;
      if NEG jump converged;
      r6 = r0 ASHIFT 24;
      r0 = r0 * r0(frac);
      r0 = r0 * r6(frac);
      M[r8 +$pcm_sync.LATENCY_CONVERGED_FIELD] = 0;
   converge_check_done:

   // limit fixing range,
   // capped the fix value
   r1 = r0 - 0.01;
   if POS r0 = r0 - r1;
   r1 = r0 + 0.01;
   if NEG r0 = r0 - r1;
   M[r8 +$pcm_sync.FIX_RATE_FIELD] = r0;

   // get the sample rate for second channel
   rMAC = 0;
   r0 = M[r8 +$pcm_sync.REF_CHANNEL_SAMPLE_RATE_PTR_FIELD];
   if Z jump calc_rate_done;
   r0 = M[r0];
   if Z jump calc_rate_done;

   // get the sample rate for main channel
   r1 = M[r8 +$pcm_sync.ADJ_CHANNEL_SAMPLE_RATE_PTR_FIELD];
   r1 = M[r1];
   if Z jump calc_rate_done;

   // work out long term compensation (<<4 for more accuracy)
   rMAC = r1 - r0;
   rMAC = rMAC ASHIFT 3;
   Div = rMAC / r0;
   rMAC = DivResult;

   // if first time, don't apply auto-regressive smoothing
   Null = M[r8 +$pcm_sync.SAMPLE_RATES_VALID_FIELD];
   if Z jump update_rate_before_fix;
   r0 = 1;
   Null = M[r8 +$pcm_sync.SAMPLE_RATES_VALID_FIELD];

   // apply auto-regressive smoothing
   r4 = M[r8 +$pcm_sync.RATE_BEFORE_FIX_FIELD];
   rMAC = rMAC * 0.01;
   rMAC = rMAC + r4 * 0.99;

   update_rate_before_fix:
   M[r8 + $pcm_sync.RATE_BEFORE_FIX_FIELD] = rMAC;

   calc_rate_done:
   // rMAC = long term compensation
   r4 = rMAC *(1/16.0)(frac);

   // r3 = short term temp compensation
   r3 = M[r8 +$pcm_sync.FIX_RATE_FIELD];
   r4 = r4 + r3;

   // limit max and min mismatch rate to compensate
   r0 = M[r8 +$pcm_sync.MAX_RATE_FIELD];
   r4 = MIN r0;
   r0 = Null - r0;
   r4 = MAX r0;

   // set final rate
   M[r8 +$pcm_sync.SRA_RATE_FIELD] = r4;

jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.config_calc_port_rate
//
// DESCRIPTION:
//    Configure the port rate calculation
//
// INPUTS:
//    r0 = master/slave flag (0: master; 1: slave)
//    r1 = address of actual chain actual port rate structure
//
// OUTPUTS:
//    none
//    [but routine sets the MASTER_RATE_PTR_FIELD field of the given structure]
//
// TRASHED:
//    r2
//
// *****************************************************************************
.MODULE $M.config_calc_port_rate;
   .CODESEGMENT CONFIG_CALC_PORT_RATE_PM;

   $config_calc_port_rate:

   r2 = $current_dac_sampling_rate;                            // Pointer to DAC rate used for master operation
   null = r0;                                                  // Is slave operation used?
   if NZ r2 = 0;                                               // Yes - Calculate the rate (as done for ptr=0)
   M[r1 + $calc_actual_port_rate.MASTER_RATE_PTR_FIELD] = r2;  // 0: Calculate rate; non-zero pointer to rate: Specified rate

   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//   $apply_hardware_warp_rate
//
// DESCRIPTION:
//   Applies hardware warp rate by sending message to the firmware
//
// *****************************************************************************
.MODULE $M.apply_hardware_warp_rate;
   .CODESEGMENT APPLY_WARP_RATE_PM;
   .DATASEGMENT DM;

   $apply_hardware_warp_rate:

   // push rLink onto stack
   $push_rLink_macro;

   // see if it's time to update hardware warp
   r0 = M[$TIMER_TIME];
   r1 = M[$hw_warp_struct + $hw_warp.LAST_TIME_FIELD];
   r2 = r0 - r1;
   if NEG r2 = -r2;
   r3 = M[$hw_warp_struct + $hw_warp.TIMER_PERIOD_FIELD];
   Null = r2 - r3;
   if NEG jump $pop_rLink_and_rts;

   // update last update time
   r1 = r1 + r3;
   r2 = r1 - r0;
   if NEG r2 = -r2;
   Null = r2 - 2000;
   if POS r1 = r0;
   M[$hw_warp_struct + $hw_warp.LAST_TIME_FIELD] = r1;

   // slowly move towards the target rate
   r4 = M[$hw_warp_struct + $hw_warp.TARGET_RATE_PTR_FIELD];
   r5 = M[$hw_warp_struct + $hw_warp.CURRENT_RATE_FIELD];
   r4 = M[r4];

   // calculate moving step (logarithmic then linear)
   r0 = r5 - r4;
   if Z jump $pop_rLink_and_rts;
   if NEG r0 = -r0;
   r1 = M[$hw_warp_struct + $hw_warp.MOVING_STEP_FIELD];
   rMAC = r3 * 274878;
   r3 = rMAC ASHIFT 8;
   r2 = r0 * r3(frac);
   Null = r0 - 0.0015;
   if NEG r2 = r1;
   r3 = r1 * 20 (int);
   r1 = r2 - r3;
   if POS r2 = r2 - r1;
   r1 = r5 - r4;
   r0 = r1 - r2;
   if POS r1 = r1 - r0;
   r0 = r1 + r2;
   if NEG r1 = r1 - r0;

   // update the current rate
   r5 = r5 - r1;
   r4 = r5 ASHIFT -6;
   r5 = r4 ASHIFT 6;

   // Has the rate changed? - only send rate update message if changed
   r0 = M[$hw_warp_struct + $hw_warp.CURRENT_RATE_FIELD];
   r1 = r5 - r0;
   if Z jump end_hw_rate_apply;
      //  apply harware warp rate
      M[$hw_warp_struct + $hw_warp.CURRENT_RATE_FIELD] = r5;
      r4 = -r4;
      r2 = &$MESSAGE_WARP_DAC;
      r3 = 3;
      call $message.send_short;
   end_hw_rate_apply:

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
