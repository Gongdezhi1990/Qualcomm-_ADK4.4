/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file rtime.h
    @brief  Basic time services.

    The system's real time clock services.

    The kalimba chip hardware provides a 24 bit clock with 1 microsecond
    resolution in register TIMER_TIME. This can be read by the software,
    so it is used to provide the system with real time clock services.
    The register TIMER_TIME_MS provides an additional 8 most
    significant bits of the 1us timer, but this register is not used.

    The services offered by this file can also be used to operate on
    time_to_play values which are derived from the TIMER_TIME.

    The fundamental type "time_t" is really a uint24_t.   time_t values will
    *wrap* after around 16.777 seconds, so functions using time_ts must be
    cautious.

    Most of the "functions" in this file are really macros.   The user
    will have to use great caution to ensure sane behaviour.
*/

#ifndef __RTIME_H__
#define __RTIME_H__

#include <stdint.h>

/** System time, in microseconds. */
typedef uint24_t time_t;

/* TIME constants. */
#define US_PER_MS         ((time_t) 1000)
#define MS_PER_SEC        ((time_t) 1000)
#define US_PER_SEC        (US_PER_MS * MS_PER_SEC)

#define MILLISECOND       US_PER_MS
#define SECOND            US_PER_SEC
#define MINUTE            (60 * SECOND)

#define US_PER_SLOT       ((time_t) 625)

/**
 * \brief  Add two time values
 *
 * \returns The sum of "t1 and t2".
 *
 * NOTES
 *  Implemented as a macro, because it's trivial.
 *
 *  Adding the numbers can overflow the range of a time_t, so the user must
 *  be cautious.
 */
#define time_add(t1, t2) ((t1) + (t2))


/**
 * \brief  Subtract two time values
 *
 * \returns t1 - t2.
 * 
 * Implemented as a macro, because it's trivial.
 * 
 * Subtracting the numbers can provoke an underflow.   This returns
 * a signed number for correct use in comparisons.
 * 
 * If you want to know whether the time since last timestamp has exceeded
 * some threshold value, don't be tempted to use this:
 * 
 * if((uint32) time_sub(current_time, last_time) > some_threshold);
 * 
 * or any other such variant. This may give wrong result.
 * 
 * The correct way to express the above is using time_gt macro:
 * 
 * if (time_gt(time_sub(current_time, last_time), threshold_time));
 * or, equivalently:
 * if (time_gt(current_time, time_add(last_time, threshold_time));
 */
#define time_sub(t1, t2) ((int24_t) (t1) - (int24_t) (t2))


/**
 * \brief  Compare two time values
 *
 * \returns TRUE if "t1" equals "t2", else FALSE.
 * 
 * Compares the two time values "t1" and "t2".
 * Implemented as a macro, because it's trivial.
 * 
 */
#define time_eq(t1, t2) ((t1) == (t2))


/**
 * \brief  Compare two time values
 *
 * \returns FALSE if "t1" equals "t2", else TRUE.
 * 
 * Compares the two time values "t1" and "t2".
 * Implemented as a macro, because it's trivial.
 * 
 */
#define time_ne(t1, t2) ((t1) != (t2))


/**
 * \brief  Compare two time values
 *
 * \returns TRUE if "t1" is greater than "t2", else FALSE.
 * 
 * Compares the time values "t1" and "t2".
 *
 * Because time values wrap, "t1" and "t2" must differ by less than half
 * the range of the clock apart.
 * Implemented as a macro, because it's trivial.
 * 
 */
#define time_gt(t1, t2) (time_sub((t1), (t2)) > 0)


/**
 * \brief  Compare two time values
 *
 * \returns TRUE if "t1" is greater than, or equal to, "t2", else FALSE.
 * 
 * Compares the time values "t1" and "t2".
 *
 * Because time values wrap, "t1" and "t2" must differ by less than half
 * the range of the clock apart.
 * Implemented as a macro, because it's trivial.
 * 
 */
#define time_ge(t1, t2) (time_sub((t1), (t2)) >= 0)


/**
 * \brief  Compare two time values
 *
 * \returns TRUE if "t1" is less than "t2", else FALSE.
 * 
 * Compares the time values "t1" and "t2".
 *
 * Because time values wrap "t1" and "t2" must be less than half the
 * range of the clock apart.
 * Implemented as a macro, because it's trivial.
 * 
 */
#define time_lt(t1, t2) (time_sub((t1), (t2)) < 0)


/**
 * \brief  Compare two time values
 *
 * \returns TRUE if "t1" is less than, or equal to, "t2", else FALSE.
 * 
 * Compares the time values "t1" and "t2".
 *
 * Because time values wrap "t1" and "t2" must be less than half the
 * range of the clock apart.
 * Implemented as a macro, because it's trivial.
 * 
 */
#define time_le(t1, t2) (time_sub((t1), (t2)) <= 0)

/**
 * \brief  Minimum of two time values
 *
 * \returns Minimum of t1 and t2
 *
 * Implemented as a macro, because it's trivial.
 */
#define time_min(t1, t2) (time_lt(t1, t2) ? (t1) : (t2))

/**
 * \brief  Maximum of two time values
 *
 * \returns Maximum of t1 and t2
 *
 * Implemented as a macro, because it's trivial.
 */
#define time_max(t1, t2) (time_gt(t1, t2) ? (t1) : (t2))

#endif  /* __RTIME_H__ */
