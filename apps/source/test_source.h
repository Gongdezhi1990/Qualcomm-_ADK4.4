/*******************************************************************************
Copyright (c) 2015 Qualcomm Technologies International, Ltd.
 Part of ADK_CSR867x.WIN. 4.4
*******************************************************************************/

#ifndef _TEST_SOURCE_H_
#define _TEST_SOURCE_H_

#include <message.h>
#include "source_states.h"
#include "source_buttons.h"

/* Register the main task  */
void test_init(void);

#define SOURCE_TEST_MESSAGE_BASE   0x2000

/**************************************************
   VM2HOST
 **************************************************/
typedef enum {
    SOURCE_TEST_STATE = SOURCE_TEST_MESSAGE_BASE,
    SOURCE_TEST_EVENT
} vm2host_source;

typedef struct {
    uint16 state;    /*!< The Source app state. */
} SOURCE_TEST_STATE_T;

typedef struct {
    uint16 event;   /*!< The Source app event. */
} SOURCE_TEST_EVENT_T;

/* Source State notification */
void vm2host_send_state(SOURCE_STATE_T state);

/* Source Event notification */
void vm2host_send_event(PioMessage event);

/**************************************************
   HOST2VM
 **************************************************/
typedef enum {
    SOURCE_TEST_EVENT_MSG = SOURCE_TEST_MESSAGE_BASE + 0x80
} host2vm_source;

typedef struct {
    uint16 event;
} SOURCE_TEST_EVENT_MSG_T;

typedef struct {
    uint16 length;
    uint16 bcspType;
    uint16 funcId;

    union {
        SOURCE_TEST_EVENT_MSG_T SOURCE_TEST_EVENT_MSG;
    } source_from_host_msg;
} source_from_host_msg_T;

/* Source app host messages handler */
void handle_msg_from_host(Task task, MessageId id, Message message);

#endif
