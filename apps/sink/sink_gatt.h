/*******************************************************************************
Copyright (c) 2014 - 2015 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    sink_gatt.h

DESCRIPTION
    Manage GATT messages.
    
NOTES

*/

#ifndef _SINK_GATT_H_
#define _SINK_GATT_H_

/* The minimum GATT MTU - this is requested for all connections */
#define SINK_GATT_MTU_MIN 64

#include <csrtypes.h>
#include <message.h>

/*******************************************************************************
NAME
    sinkGattMsgHandler
    
DESCRIPTION
    Handle messages from the GATT library
    
PARAMETERS
    task    The task the message is delivered
    id      The ID for the GATT message
    message The message payload
    
RETURNS
    void
*/
#ifdef GATT_ENABLED
void sinkGattMsgHandler(Task task, MessageId id, Message message);
#else
#define sinkGattMsgHandler(task, id, message) ((void)(0))
#endif


#endif /* _SINK_GATT_H_ */

