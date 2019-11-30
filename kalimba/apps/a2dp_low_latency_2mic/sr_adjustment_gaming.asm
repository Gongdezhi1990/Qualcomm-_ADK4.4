// Copyright (c) 2003 - 2015 Qualcomm Technologies International, Ltd.

#include "core_library.h"
#include "codec_library.h"
#include "sr_adjustment_gaming.h"
#include "kalimba_standard_messages.h"

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
//
//
// *****************************************************************************
.MODULE $M.sra_calcrate;
   .CODESEGMENT MUSIC_EXAMPLE_SRA_CALCRATE_PM;
   .DATASEGMENT DM;

  .VAR mode_funtion_table[] = &idle, &start, &addup;

   $sra_calcrate:

   // push rLink onto stack
   $push_rLink_macro;


      r0 = M[$M.a2dp_in.decoder_codec_stream_struc + $codec.av_decode.CURRENT_RUNNING_MODE_FIELD];
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
 M[$sra_struct + $sra.CODEC_CBUFFER_START_ADDR_TAG_FIELD] = Null;

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
   call $cbuffer.calc_amount_data;
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
   Null = r0 - r1;
   if POS r0 = r1;
   r1 = r6 - r7;
   Null = r0 - r1;
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
   Null = r0 - r1;
   if POS r0 = r1;
   r1 = r6 - r7;
   Null = r0 - r1;
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

// *****************************************************************************
// MODULE:
//    $calc_actual_samples
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
//    A call to $calc_actual_samples should be placed at the start of
//    the output timer interrupt handler to ensure timing accuracy (don't
//    want timing variation caused by code executed earlier in the handler).
//
//
// INPUTS:
//    - r8 = pointer to $calc_actual_samples data structure
//
// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    r0, r1, r2
//
// *****************************************************************************
.MODULE $M.calc_actual_samples;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
   .VAR state_tab[] = reset, wait, start, run;
   $calc_actual_samples:
   // Push rLink onto stack
   $push_rLink_macro;
   // Get the state and jump to the associated routine
   r0 = M[r8 + $calc_actual_samples.STATE_FIELD];
   r0 = M[state_tab + r0];
   jump r0;
   // Function executed when in reset state
   // -------------------------------------------------------------------------------
   reset:
   // Next state is WAIT
   r0 = $calc_actual_samples.WAIT;
   M[r8 + $calc_actual_samples.STATE_FIELD] = r0;
   M[r8 + $calc_actual_samples.ACCUMULATOR_FIELD] = 0;
   M[r8 + $calc_actual_samples.PERIOD_COUNTER_FIELD] = 0;
   jump exit;
   // Function executed when in wait state
   // -------------------------------------------------------------------------------
   wait:
   // Count the number of calls
   r1 = M[r8 + $calc_actual_samples.PERIOD_COUNTER_FIELD];
   r1 = r1 + 1;
   M[r8 + $calc_actual_samples.PERIOD_COUNTER_FIELD] = r1;
   // Check if the wait period is complete
   r2 = M[r8 + $calc_actual_samples.WAIT_DURATION_FIELD];
   null = r1 - r2;
   if NZ jump exit;
      // Next state is START
      r0 = $calc_actual_samples.START;
      M[r8 + $calc_actual_samples.STATE_FIELD] = r0;
   jump exit;
   // Function executed when in start state
   // -------------------------------------------------------------------------------
   start:
   // Next state is RUN
   r0 = $calc_actual_samples.RUN;
   M[r8 + $calc_actual_samples.STATE_FIELD] = r0;
   M[r8 + $calc_actual_samples.ACCUMULATOR_FIELD] = 0;
   M[r8 + $calc_actual_samples.PERIOD_COUNTER_FIELD] = 0;
   // How much data (l(n) = current fill level) in the output port?
   r0 = M[r8 + $calc_actual_samples.PORT_FIELD];
   r0 = r0 AND $cbuffer.PORT_NUMBER_MASK;
   r0 = M[($cbuffer.write_port_limit_addr - $cbuffer.WRITE_PORT_OFFSET) + r0];
   r0 = M[r0];
   // Save the port read pointer
   M[r8 + $calc_actual_samples.PREV_PORT_READ_PTR_FIELD] = r0;
   jump exit;
   // Function executed when in run state
   // -------------------------------------------------------------------------------
   run:
   // How much data (l(n) = current fill level) in the output port?
   r0 = M[r8 + $calc_actual_samples.PORT_FIELD];
   call $cbuffer.calc_amount_space;
   // Get the port read pointer value
   r0 = M[r8 + $calc_actual_samples.PORT_FIELD];
   r0 = r0 AND $cbuffer.PORT_NUMBER_MASK;
   r0 = M[($cbuffer.write_port_limit_addr - $cbuffer.WRITE_PORT_OFFSET) + r0];
   r0 = M[r0];
   // Calculate how many bytes have been read since the last timer interrupt
   // (and adjust for wrap around)
   r1 = M[r8 + $calc_actual_samples.PREV_PORT_READ_PTR_FIELD];
   r1 = r0 - r1;
   if NEG r1 = r1 + r2;                                     // Adjust wrap around by adding port size (in bytes)
   // Save the port read pointer
   M[r8 + $calc_actual_samples.PREV_PORT_READ_PTR_FIELD] = r0;

   // Get the result in samples
   push r3;
   r3 = M[r8 + $calc_actual_samples.PORT_FIELD];
   r2 = r1;
   // Convert to samples (in: r2 = octets, r3 = port config; out r2 = samples)
   call $cbuffer.mmu_octets_to_samples;
   pop r3;
   r1 = r2;

   r0 = M[r8 + $calc_actual_samples.ACCUMULATOR_FIELD];     //
   r0 = r0 + r1;                                            // Accumulate
   M[r8 + $calc_actual_samples.ACCUMULATOR_FIELD] = r0;     //
   // Count the number of calls
   r1 = M[r8 + $calc_actual_samples.PERIOD_COUNTER_FIELD];
   r1 = r1 + 1;
   M[r8 + $calc_actual_samples.PERIOD_COUNTER_FIELD] = r1;
   // Check if the calculation period is complete
   r2 = M[r8 + $calc_actual_samples.ACCUMULATOR_DURATION_FIELD];
   null = r1 - r2;
   if NZ jump exit;
      // Apply a scaling factor to adjust the SRA calculation and compensate
      // for the resampling function
      call $apply_sra_resampling_adjustment;
      // Complete, so load the expected number of samples with the actual number
      M[$sra_struct + $sra.AUDIO_AMOUNT_EXPECTED_FIELD] = r0;
      // Restart the calculation statemachine
      r0 = $calc_actual_samples.START;
      M[r8 + $calc_actual_samples.STATE_FIELD] = r0;
   exit:
   // Pop rLink from stack
   jump $pop_rLink_and_rts;
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
//    - r0 = audio amount expected
//
// OUTPUTS:
//    - r0 = audio amount expected adjusted for resampling
//
// *****************************************************************************
.MODULE $M.apply_sra_resampling_adjustment;
   .CODESEGMENT PM;
   $apply_sra_resampling_adjustment:
   pushm <r1, r2>;            // Save regs
   // For downsampling: resamp_adjust_int = 0, with the fractional part in resamp_adjust_frac
   // For upsampling: resamp_adjust_int > 0, with the fractional part in resamp_adjust_frac
   // Get the resampler adjustment factors
   r1 = M[$sra_resamp_adjust_int];
   r2 = M[$sra_resamp_adjust_frac];
   // Apply the pre-calculated adjustment factors
   r1 = r0 * r1 (int);
   r2 = r0 * r2 (frac);
   r0 = r1 + r2;
   popm <r1, r2>;             // Save regs
   rts;
.ENDMODULE;