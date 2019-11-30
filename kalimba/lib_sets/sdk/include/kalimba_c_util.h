/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/**
 * @file  kalimba_c_util.h
 * @brief This file contains c/asm utilities
 */
#ifndef KALIMBA_C_UTIL_H
#define KALIMBA_C_UTIL_H

#ifdef KCC

#if defined(KALSIM)
#define kalimba_error abort
#endif

#define INT_ENABLE  (*((volatile uint24_t *)(0xFFFE12U)))

#define STATIC_ASSERT(x, msg) extern struct static_assert_ ## msg { \
    int static_assert_ ## msg [1 - (!(x))*2]; \
}

#define STRUC_SIZE_CHECK(t, s)  STATIC_ASSERT(sizeof(t) == (s), t)

#endif /* KCC */

#endif /* KALIMBA_C_UTIL_H */
