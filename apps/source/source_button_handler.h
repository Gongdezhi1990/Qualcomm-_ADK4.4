/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_button_handler.h

DESCRIPTION
    Handles button events.
    The functionality is only included if INCLUDE_BUTTONS is defined.
    
*/


#ifdef INCLUDE_BUTTONS


#ifndef _SOURCE_BUTTON_HANDLER_H_
#define _SOURCE_BUTTON_HANDLER_H_


#include "source_buttons.h"


/* Base message number for button messages which is created by ButtonParsePro */
#define BUTTON_MSG_BASE 1000

/***************************************************************************
Function definitions
****************************************************************************
*/

/****************************************************************************
NAME    
    button_msg_handler

DESCRIPTION
    Message handler for button events.

*/
#ifdef INCLUDE_BUTTONS
void button_msg_handler(Task task, MessageId id, Message message);
#else
#define button_msg_handler(task, id,message) ((void)(0))
#endif

/****************************************************************************
NAME    
    buttons_init

DESCRIPTION
    Initialises the button handling.

*/
#ifdef INCLUDE_BUTTONS
void buttons_init(void);
#else
#define buttons_init() ((void)(0))
#endif

#endif /* _SOURCE_BUTTON_HANDLER_H_ */


#endif /* INCLUDE_BUTTONS */
