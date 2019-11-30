/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file log.h
    @brief Testbench logging

    Macros used for logging when running test benches.
*/

#ifndef LOG_H
#define LOG_H

#include <kalimba_int.h>

enum LOG_LEVEL
{
    LOG_LEVEL_ERROR = 0,
    LOG_LEVEL_INFO  = 1,
    LOG_LEVEL_DEBUG = 2,
    LOG_LEVEL_TRACE = 3,
};

#if defined(KALSIM)
#include <stdio.h>
#define LOG_MSG(PREFIX, LEVEL, FMT, ...) \
{ \
    if (log_level >= LEVEL) \
        printf(PREFIX ":%25s: " FMT "\n", __func__,  ##__VA_ARGS__); \
} do {} while(0) \

#define LOG_ERROR(FMT, ...) LOG_MSG("ERR", LOG_LEVEL_ERROR, FMT, ##__VA_ARGS__)
#define LOG_INFO(FMT, ...)  LOG_MSG("INF", LOG_LEVEL_INFO,  FMT, ##__VA_ARGS__)
#define LOG_DEBUG(FMT, ...) LOG_MSG("DBG", LOG_LEVEL_DEBUG, FMT, ##__VA_ARGS__)
#define LOG_TRACE(FMT, ...) LOG_MSG("TRC", LOG_LEVEL_TRACE, FMT, ##__VA_ARGS__)

#define LOG_DEBUG_U48(S,X) \
    LOG_DEBUG("%30s 0x%08x_0x%06x", S, TO_UINT24(U48_MSW(X)), TO_UINT24(X))

#define LOG_DEBUG_U24(S,X) \
    LOG_DEBUG("%30s 0x%06x", S, TO_UINT24(X))

#define LOG_TRACE_U48(S,X) \
    LOG_TRACE("%30s 0x%08x_0x%06x", S, TO_UINT24(U48_MSW(X)), TO_UINT24(X))

#define LOG_TRACE_U24(S,X) \
    LOG_TRACE("%30s 0x%06x", S, TO_UINT24(X))

extern enum LOG_LEVEL log_level;
void log_set_level(enum LOG_LEVEL level);

#else // KALSIM

#define LOG_MSG(PREFIX, LEVEL, FMT, ...) do {} while(0)
#define LOG_ERROR(FMT, ...) do {} while(0)
#define LOG_INFO(FMT, ...) do {} while(0)
#define LOG_DEBUG(FMT, ...) do {} while(0)
#define LOG_TRACE(FMT, ...) do {} while(0)
#define LOG_DEBUG_U48(S,X) do {} while(0)
#define LOG_DEBUG_U24(S,X) do {} while(0)
#define LOG_TRACE_U48(S,X) do {} while(0)
#define LOG_TRACE_U24(S,X) do {} while(0)

#endif

#endif /* LOG_H */
