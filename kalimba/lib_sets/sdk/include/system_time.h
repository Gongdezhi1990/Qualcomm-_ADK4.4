// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// %%version
// *****************************************************************************

/*!
    @file system_time.h
    @brief  System time clock switching

    Functions for switch between system time clock sources.
*/

#ifndef SYSTEM_TIME_H
#define SYSTEM_TIME_H

#ifdef KCC

#include <stdint.h>
#include <stdbool.h>
#include <rtime.h>

#define SYSTEM_TIME_SOURCE_WIDTH_BITS 2
#define SYSTEM_TIME_SOURCES_MAX (1 << SYSTEM_TIME_SOURCE_WIDTH_BITS)
#define SYSTEM_TIME_SOURCE_MASK (SYSTEM_TIME_SOURCES_MAX - 1)

typedef time_t (*system_time_get_clock_fn_t)(void *arg);

/** A structure for storing the parameters of an instance of a system time
    clock. E.g. wall clock, local timer, etc */
typedef struct system_time_clock_params
{
    /** The function to call to get the clock value */
    system_time_get_clock_fn_t get_clock_fn;
    /** The argument to pass to the function */
    void * arg;
    /** This clock's offset w.r.t. the local clock */
    time_t offset;
    /** Indicates whether this source is active / inactive */
    bool active;
} system_time_clock_params_t;

/**
 * \brief Get the time from a source
 *
 * \param source The timing source index
 * \param t Address of variable where the time will be written
 * \return true if the time was available, otherwise false.
 */
bool system_time_get(unsigned source, time_t *t);

/**
 * \brief Register a clock source
 *
 * \param source The timing source index
 * \param params The parameters for the clock source
 */
void system_time_register_source(unsigned source, system_time_clock_params_t *params);

/**
 * \brief Unregister a source
 *
 * \param source The timing source index
 */
void system_time_unregister_source(unsigned source);

/**
 * \brief Set the clock offset for the source
 *
 * \param source The timing source index
 * \param offset The clock's offset w.r.t. the local clock
 */
void system_time_set_source_offset(unsigned source, time_t offset);

/**
 * \brief Get the clock offset between sources
 *
 * \param source1 The first timing source index
 * \param source2 The second time source index
 */
int system_time_get_source_offset(unsigned source1, unsigned source2);

/**
 * \brief Set a clock source as active
 *
 * \param source The timing source index
 */
void system_time_set_source_active(unsigned source);

/**
 * \brief Set a clock source as inactive
 *
 * \param source The timing source index
 */
void system_time_set_source_inactive(unsigned source);

/**
 * \brief Determine whether a clock source is active or inactive
 *
 * \param source The timing source index
 * \return True if the source is active, False if the source is inactive
 */
bool system_time_source_is_active(unsigned source);



#else /* KCC */

#endif /* KCC */

#define SYSTEM_TIME_CLOCK_PARAMS_STRUC_SIZE 4

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(system_time_clock_params_t, SYSTEM_TIME_CLOCK_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* SYSTEM_TIME_H */

