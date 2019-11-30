/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file ttp.h
    @brief  Time-to-play generator

    Generates the time to play by tracking the source sample periods.
*/

#ifndef TTP_H
#define TTP_H

#ifdef KCC
/****************************************************************************
  Include Files
*/
#include <limits.h>
#include <stdint.h>
#if (defined(KAL_ARCH2) || defined(KAL_ARCH3) || defined(KAL_ARCH5) || defined(KALSIM))
#include <core_library_c_stubs.h>
#endif
#include <sr.h>
#include <kalimba_int.h>

/****************************************************************************
  Public Type Declarations
*/

typedef struct ttp_settings {
    /** The multiplier to apply to the previously held leakage (fractional integer) */
    int24_t latency_hold_leakage;
    int24_t latency_difference_limit;
    int24_t latency_error_filter_gain;
    int24_t latency_error_filter_shift;
    int24_t latency_initial_countdown_value_us;
    int24_t latency;
    enum srbits sample_rate;
} ttp_settings_t;

struct ttp_state;

#endif /* KCC */

#define TTP_SETTINGS_LATENCY_HOLD_LEAKAGE_FIELD         0
#define TTP_SETTINGS_LATENCY_DIFFERENCE_LIMIT_FIELD     1
#define TTP_SETTINGS_LATENCY_ERROR_FILTER_GAIN_FIELD    2
#define TTP_SETTINGS_LATENCY_ERROR_FILTER_SHIFT_FIELD   3
#define TTP_SETTINGS_INITIAL_COUNTDOWN_VALUE_US_FIELD   4    // Should be a multiple of the
                                                             // timer interrupt period
#define TTP_SETTINGS_LATENCY_FIELD 5
#define TTP_SETTINGS_SAMPLE_RATE_FIELD 6
#define TTP_SETTINGS_STRUC_SIZE 7

/* Size in words of the opaque ttp_state structure (over-allocated) */
#define TTP_STATE_STRUC_SIZE                    20

/****************************************************************************
  Public Constant Declarations
*/

/****************************************************************************
  Public Macro Declarations
*/

/****************************************************************************
  Public Variable Definitions
*/

/****************************************************************************
  Public Function Definitions
*/
#ifdef KCC
/**
 * \brief  Initialises the TTP state.
 *
 * \param ttp_state   the TTP internal state.
 *
 * Initialises the time to play module to a default state.
 */
void ttp_initialise(struct ttp_state *ttp_state);

/**
 * \brief  Destroys the TTP state.
 *
 * \param ttp_state   the TTP internal state.
 *
 * Releases any resources owned by the time to play module.
 */
void ttp_destroy(struct ttp_state *ttp_state);

/**
 * \brief  Gets the initial countdown.
 *
 * \param ttp_state   the TTP internal state.
 * \return The current value of the countdown.
 *
 * Gets the current value of the countdown which is used to re-calculate the
 * buffered time to play meta-data when it reaches zero.
 */
int ttp_get_initial_countdown(struct ttp_state *ttp_state);

/**
 * \brief  Gets the measured latency error.
 *
 * \param ttp_state   the TTP internal state.
 * \return The measured latency error in us.
 *
 * Gets the latency error in us
 */
int ttp_get_latency_error(struct ttp_state *ttp_state);

/**
 * \brief  Gets the sample period adjustment.
 *
 * \param ttp_state   the TTP internal state.
 * \return The sample period adjustment as a Q18 fractional number.
 *
 * Gets the filtered error that is applied to nominmal sample period.
 */
int ttp_get_sample_period_adjustment(struct ttp_state *ttp_state);

/**
 * \brief  Gets the time to play.
 *
 * \param ttp_state   the TTP internal state.
 * \return The time to play.
 *
 * Gets the time to play calculated by ttp_calculate.
 */
int ttp_get_ttp(struct ttp_state *ttp_state);

/**
 * \brief  Informs ttp that time has passed
 *
 * \param ttp_state   the TTP internal state.
 * \param time_passed_us the number of microseconds passed since the previous call
 *
 */
void ttp_tick(struct ttp_state *ttp_state, int24_t time_passed_us);

/**
 * \brief  Sets the initial countdown
 *
 * \param ttp_state   the TTP internal state.
 * \param initial_countdown the initial_countdown in us
 *
 * Sets the initial delay in us.
 */
void ttp_set_initial_countdown(struct ttp_state *ttp_state, int initial_countdown);

/**
 * \brief  Sets the time to play
 *
 * \param ttp_state   the TTP internal state.
 * \param ttp   the time to play.
 *
 * Sets the time to play.
 */
void ttp_set_ttp(struct ttp_state *ttp_state, int24_t ttp);

/**
 * \brief  Runs the time to play algorithm.
 *
 * \param ttp_state         the TTP internal state.
 * \param wall_clock_time   the time when the frame was received.
 * \param source            the system time source for this time
 * \param settings          the sink specific parameters for TTP generator.
 *
 * Runs the time to play algorithm to calculate the current sample_period.
 */
void ttp_run(struct ttp_state *ttp_state, uint24_t wall_clock_time,
             uint24_t source, const struct ttp_settings *settings);

/**
 * \brief  Calculates the next time to play value.
 *
 * \param ttp_state         the TTP internal state.
 * \param ttp_settings      the TTP settings
 * \param num_samples   the number of samples in the frame.
 *
 * Calculates the next time to play value for num_samples given the sample
 * period calculated by the previous call to ttp_run.
 */
void ttp_calculate(struct ttp_state *ttp_state,
                   const struct ttp_settings *ttp_settings,
                   int24_t num_samples);

/**
 * \brief   Re-syncs the TTP state.
 *
 * \param ttp_state         the TTP internal state.
 *
 * Re-syncs the time to play state to the wall clock time on the next call to
 * ttp_run.
 */
void ttp_resync(struct ttp_state *ttp_state);
#endif /* KCC */

#endif /* TTP_H */
