/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    sink_aov.h

DESCRIPTION
    Sink module to support Always-on-Voice (AoV) functionality.

*/
/*!
@file   sink_aov.h
@brief  Sink module to support Always-on-Voice (AoV) functionality.
*/

#ifndef SINK_AOV_H_
#define SINK_AOV_H_

#include <csrtypes.h>

#define AOV_OFF (int)-1

typedef enum{
    aov_set_phrase_response_success,
    aov_set_phrase_response_not_avail,
    aov_set_phrase_response_invalid
}aov_set_phrase_response;

/*!
    @brief Request to activate or deactivate AoV functionality.

    Note: If AoV functionality is disabled in the application config all
          requests to this function will be ignored.

    @param activate TRUE to turn on the AoV audio graph and audio subsystem
                    low-power mode, FALSE to turn it off.
*/
#ifdef ENABLE_AOV
void sinkAovActivate(bool activate);
#else
#define sinkAovActivate(activate) ((void)0)
#endif

/*!
    @brief Cycle through AoV phrases.

    Note: If AoV functionality is disabled in the application config all
          requests to this function will be ignored.

*/
#ifdef ENABLE_AOV
void sinkAovCyclePhrase(void);
#else
#define sinkAovCyclePhrase() ((void)0);
#endif

/*!
    @brief Initialise the AoV Module.

    Note: If AoV functionality is disabled in the application config all
          requests to this function will be ignored.

*/
#ifdef ENABLE_AOV
void sinkAovInit(void);
#else
#define sinkAovInit() ((void)0);
#endif

/*!
    @brief Sets the trigger phrase we respond to.

    @param phrase_index 
 
    @return bool TRUE If phrase updated
                 else FALSE
*/
#ifdef ENABLE_AOV
aov_set_phrase_response sinkAovSetPhraseIndex(int16 phrase_index);
#else
#define sinkAovSetPhraseIndex(x) (aov_set_phrase_response_not_avail)
#endif


/*!
    @brief Gets the trigger phrase we're responding to.

    @param *phrase_index will contain the phrase if success.
 
    @return bool TRUE If AoV enabled
                 else FALSE
*/
#ifdef ENABLE_AOV
bool sinkAovGetPhraseIndex(int16 *phrase_index);
#else
#define sinkAovGetPhraseIndex(x) (FALSE)
#endif

#endif /* SINK_AOV_H_ */
