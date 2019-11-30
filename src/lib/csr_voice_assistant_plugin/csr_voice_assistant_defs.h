/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    voice_prompts_defs.h
 
DESCRIPTION
    Write a short description about what the sub module does and how it 
    should be used.
*/

#ifndef LIBS_CSR_VOICE_ASSISTANT_DEFS_H_
#define LIBS_CSR_VOICE_ASSISTANT_DEFS_H_

#include "audio_plugin_if.h"

typedef struct
{

    /*! Application task */
    Task                app_task;
    /* Is VA laucnhed standalone or in parallel*/
    bool    is_standalone;
    /* Storing the Sink from Pipe stream*/
    Sink va_snk_vm;
    Sink va_snk_dsp;
} va_context_t ;

#endif
