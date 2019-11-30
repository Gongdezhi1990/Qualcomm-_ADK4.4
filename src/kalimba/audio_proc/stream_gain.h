// *****************************************************************************
// Copyright (c) 2007 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef STREAM_GAIN_HEADER_INCLUDED
#define STREAM_GAIN_HEADER_INCLUDED

.CONST      $M.audio_proc.stream_gain.OFFSET_INPUT_PTR			 0;
.CONST      $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR		     1;
.CONST      $M.audio_proc.stream_gain.OFFSET_PTR_MANTISSA        2;
.CONST      $M.audio_proc.stream_gain.OFFSET_PTR_EXPONENT        3;                                                      
.CONST      $M.audio_proc.stream_gain.STRUC_SIZE                 4;

.CONST $audio_proc.stream_gain_ramp.RAMP_STEP_FIELD             0; // (input) gain step size (e.g. 0.01 gives 100 steps)
.CONST $audio_proc.stream_gain_ramp.RAMP_GAIN_FIELD             1; // internal state blending gain
.CONST $audio_proc.stream_gain_ramp.PREV_MANTISSA_FIELD         2; // internal state previous gain mantissa
.CONST $audio_proc.stream_gain_ramp.PREV_EXPONENT_FIELD         3; // internal state previous gain exponent
.CONST $audio_proc.stream_gain_ramp.STRUC_SIZE                  4;

#endif   //STREAM_GAIN_HEADER_INCLUDED
