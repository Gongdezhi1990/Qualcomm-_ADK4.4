/*
 * Copyright (c) 2018 Qualcomm Technologies International, Ltd.
 * This file was automatically generated for firmware version 22.0
 */

#ifndef __CODEC__H

#define __CODEC__H

#include <csrtypes.h>
/*! @file codec_.h @brief Control the various aspects of the audio CODEC
*/
#include <app/audio/audio_if.h>


/*!
    @brief Some BlueCore variants have a programmable IIR filter on ADC A and/or B. This trap
    configures those filters. 

    @param instance The audio hardware instance to configure. (See description of #AUDIO_HARDWARE_CODEC for meaning.)
    @param channel The audio channel. (See description of #AUDIO_HARDWARE_CODEC for meaning.)
    @param enable Enables (pass TRUE) or disables (pass FALSE) the filter.
    @param coefficients An array of values to program into the filter. Ten values 
    are required for the filter on existing chips.

    @return TRUE if the filter was configured as requested, else FALSE. An invalid coefficient
    address will result in a FALSE return, as will an invalid instance or channel.

    To keep microphones in synchronisation, IIR filter(if used) should be configured before
    ADC is turned on(i.e. before StreamConnect()).
*/
bool CodecSetIirFilter(audio_instance instance, audio_channel channel, bool enable, uint16 *coefficients);

/*!
  @brief IIR Filter coefficients are configurable on some Bluecore variants.
  This trap is used to program set of 16-bit-coefficients to multiple
  IIR filters on ADC channels. This trap is licensed and can be used only
  with licensed devices.

  @param channel_mask ADC channel bit mask to configure IIR coefficients on
  multiple ADC channels.
  It is a bitmask with 6 valid bits, each bit representing an ADC channel.
  @param enable Enables (TRUE) or disables (FALSE) the filter.
  @param coefficients A pointer to structure (IIR_COEFFICIENTS) containing
  16-bit IIR coefficients.

  @return TRUE if the filter was configured/disabled as requested, else FALSE.
  This will return FALSE if IIR feature is not licensed. An invalid coefficient
  address or an invalid mask will also result in a FALSE return.

  Example:
  if channel_mask = 0x0003, IIR Filters of ADC A and ADC B are updated with the
  given set of coefficients.

*/
bool CodecSetIirFilter16Bit(uint16 channel_mask, bool enable, IIR_COEFFICIENTS *iir_coefficients);

#endif
