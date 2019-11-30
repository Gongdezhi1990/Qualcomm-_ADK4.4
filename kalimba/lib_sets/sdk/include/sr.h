/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file  sr.h
    @brief  Sample rate manipulation.

    Functions for manipulating sample rates and converting between
    sample rates and time
*/
 
#ifndef SAMPLE_RATE_H
#define SAMPLE_RATE_H

/* Definitions used in c and asm */

// These IDs must match those defined in the association service record
#define SR_FREQUENCY_ID_44100    0
#define SR_FREQUENCY_ID_48000    1
#define SR_FREQUENCY_ID_LAST     1

#define SR_FREQUENCY_BITFIELD_44100    (1 << SR_FREQUENCY_ID_44100)
#define SR_FREQUENCY_BITFIELD_48000    (1 << SR_FREQUENCY_ID_48000)

#ifdef KCC

#include <stdint.h>
#include <stdbool.h>
#include <kalimba_int.h>

/** A 48 bit sample period type stored in Q24 format (integer microseconds).
    It is assumed that no operation on sp_t will overflow this format */
typedef int48_t sp_t;
/** Get the microsecond integer part of the Q24 sample period */
#define SP_INT(sp) U48_MSW((sp))
/** Get the microsecond fractional part of the Q24 sample period */
#define SP_FRAC(sp) U48_LSW((sp))

/** All sp adjustments must be symmetric around zero within the range:
    MIN_SP_ADJUSTMENT <= sp_adj <= MAX_SP_ADJUSTMENT */
#define MAX_SP_ADJUSTMENT_F 0.005
#define MAX_SP_ADJUSTMENT FLOAT_TO_FRAC(MAX_SP_ADJUSTMENT_F)
#define MIN_SP_ADJUSTMENT FLOAT_TO_FRAC(-MAX_SP_ADJUSTMENT_F)

/** Set of sample rates */
enum srbits
{
    sr_44100 = SR_FREQUENCY_ID_44100,
    sr_48000 = SR_FREQUENCY_ID_48000,
    sr_last = SR_FREQUENCY_ID_LAST
};

/**
 * \brief  Convert samples to time in Q24 format (integer microseconds)
 *
 * \param samples The number of samples
 * \param sr The base sample rate
 * \param sp_adj The sample _period_ adjustment (fractional -1 -> +1)
 * \return sp_t a 48 bit Q24 format time
 */
sp_t samples2time(int24_t samples, enum srbits sr, int24_t sp_adj);

/**
 * \brief  Convert samples to time in microseconds
 *
 * \param samples The number of samples
 * \param sr The base sample rate
 * \param sp_adj The sample _period_ adjustment (fractional -1 -> +1)
 * \return time_t the equivalent time in microseconds
 */
#define samples2timeus(samples, sr, sp_adj) SP_INT(samples2time((samples), (sr), (sp_adj)))

/**
 * \brief  Convert srbits to raw sample rate
 *
 * \param sr The srbits sample rate
 * \return The raw sample rate equivalent of sr
 */
unsigned srbits2sr(enum srbits sr);

/**
 * \brief  Convert raw sample rate to srbits.
 *         Calls kalimba_error if the raw sample rate is not one defined
 *         in the enum srbits
 *
 * \param sr The raw sample rate
 * \return The srbits equivalent of sr
 */
enum srbits sr2srbits(unsigned sr);

/**
 * \brief  Convert a signed 24-bit sample period adjustment to a mini sample
 *         period adjustment
 *
 * \param sp_adj Full signed 24-bit sample period adjustment
 * \param nbits The number of bits required in the mini adjustment
 *
 * \return The mini sample period adjustment, in the lsbits of the word
 */
unsigned sp_adjustment_to_mini(int24_t sp_adj, unsigned nbits);

/**
 * \brief  Convert a mini sample period adjustment to a signed 24-bit sample
 *         period adjustment.
 *
 * \param mini The mini sample period adjustment, in the lsbits of the word
 * \param nbits The number of bits in the mini adjustment
 *
 * \return The full signed 24-bit sample period adjustment
 */
int24_t mini_to_sp_adjustment(unsigned mini, unsigned nbits);

/**
 * \brief  Test if the srbits are valid
 *
 * \param sr The srbits sample rate
 * \return true if valid and false if invalid
 */
bool srbits_valid(enum srbits sr);

/**
 * \brief  Test if a sample rate is supported
 *
 * \param sr The srbits sample rate. The caller is responsible for checking the
 *           validity of sr
 * \param supported_sample_rates_bitfield A bitfield where each bit defines
 *        a supported sample rate. Bitfield must be initialised from defines
 *        SR_FREQUENCY_BITFIELD_X.
 * \return true if supported and false if not supported
 */
bool sr_supported(enum srbits sr, unsigned supported_sample_rates_bitfield);

#endif
#endif
