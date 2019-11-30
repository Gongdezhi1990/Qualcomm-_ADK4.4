/*******************************************************************************
Copyright (c) 2015 Qualcomm Technologies International, Ltd.
 Part of ADK_CSR867x.WIN. 4.4
*******************************************************************************/

#include <app/message/system_message.h>
#include <message.h>
#include <panic.h>
#include <stdlib.h>

#include "source_private.h"
#include "test_source.h"
#include "test_utils.h"

static const TaskData testTask = {handle_msg_from_host};

/* Register the test task  */
void test_init(void) {
    if (MessageHostCommsTask((TaskData*)&testTask)) {Panic();}
}

/**************************************************
   VM2HOST
 **************************************************/

/* HS State notification */
void vm2host_send_state(SOURCE_STATE_T state) {
    SOURCE_TEST_STATE_T message;
    message.state = state;
    test_send_message(SOURCE_TEST_STATE, (Message)&message, sizeof(SOURCE_TEST_STATE_T), 0, NULL);
}

/* HS Event Notification */
void vm2host_send_event(PioMessage event) {
    SOURCE_TEST_EVENT_T message;
    message.event = event;
    test_send_message(SOURCE_TEST_EVENT, (Message)&message, sizeof(SOURCE_TEST_EVENT_T), 0, NULL);
}

/**************************************************
   HOST2VM
 **************************************************/

/* HS host messages handler */
void handle_msg_from_host(Task task, MessageId id, Message message) {
    source_from_host_msg_T *tmsg = (source_from_host_msg_T *)message;

    switch (tmsg->funcId) {
        case SOURCE_TEST_EVENT_MSG:
            MessageSend(
                &theSource->button_data.buttonTask,
                tmsg->source_from_host_msg.SOURCE_TEST_EVENT_MSG.event,
                NULL
            );
            break;
    }
}
