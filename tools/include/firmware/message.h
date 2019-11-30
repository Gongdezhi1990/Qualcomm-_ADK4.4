/*
 * Copyright (c) 2018 Qualcomm Technologies International, Ltd.
 * This file was automatically generated for firmware version 22.0
 */

#ifndef __MESSAGE_H

#define __MESSAGE_H

#include <csrtypes.h>
#include <sink_.h>
#include <message_.h>
#include <app/message/system_message.h>
#include <app/status/status_if.h>
#include <operator_.h>
/*!
No delay, perform immediately.
*/
#define D_IMMEDIATE ((Delay) -1)
/*!
Number of seconds to delay for.
*/
#define D_SEC(s)    ((Delay) ((s) * (Delay) 1000))
/*!
Number of minutes to delay for.
*/
#define D_MIN(m)    ((Delay) ((m) * (Delay) 1000 * (Delay) 60))
/*!
Number of hours to delay for.
*/
#define D_HOUR(h)   ((Delay) ((h) * (Delay) 1000 * (Delay) 60) * (Delay) 60)
/*!
@brief Associate a Task with a Sink (and the corresponding source).
@param sink The sink to use.
@param task The task to associate.
@return The previous task for this sink, if any, or zero otherwise.
Between ADK 4.3 and ADK 4.4 the VM API MessageSinkTask was renamed to
MessageStreamTaskFromSink. The change was made to aid portability between
ADK 4 and ADK 6. On ADK 6 only the latter API exists.
The reason for this change relates to differences introduced into the Stream
API when dealing with DSP operators which are a feature of ADK 6. Without
operators, all streams have both a Source and a Sink. When there is need to
refer to a whole stream, APIs can be provided that deal with just one
direction (conventionally the Sink). Code that has a handle for the other
direction can call a conversion function (such as StreamSourceFromSink).
The API MessageSinkTask has always controlled the task associated with the
entire stream. It will receive messages for both source and sink activities
(for example, it will receive both MESSAGE_MORE_SPACE and MESSAGE_MORE_DATA
messages).
With operators, functions that convert between Sources and Sinks will fail
if the Stream does not have both. Hence, APIs need to be provided that can
identify streams given either a Source or a Sink. The new counterpart to
MessageSinkTask would naturally be called MessageSourceTask. However, these
new names imply that the Source and Sink can have separate tasks. This is
not the case.
To make it clearer that, for bidirectional streams, these two APIs identify
the same task just using different identifiers, the old traps was renamed
to MessageStreamTaskFromSink so the new trap could be called
MessageStreamTaskFromSource.
To aid portability between ADK 4 and ADK 6, the new trap names have been
made available on ADK 4 starting with ADK 4.4. To aid portability between
ADK 4.4 and earlier versions, an aliases has been introduced to allow code
using the old name to continue to work.
*/
#define MessageSinkTask(sink,task) MessageStreamTaskFromSink((sink),(task))
/*!
@brief Get the Task currently associated with a sink.
@param sink The sink to use.
Between ADK 4.3 and ADK 4.4 the VM API MessageSinkGetTask was renamed to
MessageStreamGetTaskFromSink. The change was made to aid portability between
ADK 4 and ADK 6. On ADK 6 only the latter API exists. To aid portability
between ADK 4.3 and 4.4 an alias has been introduced to allow old code to
continue to work. See the documentation for the MessageSinkTask alias for
the reason for this change.
*/
#define MessageSinkGetTask(sink) MessageStreamGetTaskFromSink((sink))
/*! @file message.h @brief Control message passing
**
**
@par Tasks and Message Queues
**
The messaging functions provide a mechanism for asynchronously posting
messages between tasks. Messages are posted to MessageQueues which are owned by Tasks.
A Task which owns a non-empty MessageQueue will be run by the scheduler.
**
@par Creating and Destroying Messages
**
Messages are dynamically allocated which means that they come out of a very limited
dynamic-block budget. It is therefore important to ensure that messages are consumed as
soon as possible after being produced. Put another way, messages are intended to be a
signaling mechanism rather than a data-buffering mechanism.
**
All messages have an identifier property, and some may also contain a payload.
*/
/*!
@brief Allocate a message, suitable for sending.
This macro allocates space for a message and initialises a variable
with a pointer to the space.
The pointer should be passed to one of the MessageSend functions, or
passed to free. The space could either be on the stack or the heap.
@param NAME the name of the variable to be declared and initialised with the pointer
@param TYPE the type to use to determine how much space to allocate
*/
#define MESSAGE_MAKE(NAME,TYPE) \
uint16 NAME##_[1+(sizeof(TYPE) < 4 ? 4 : sizeof(TYPE) < 20 ? sizeof(TYPE) : 0)]; \
TYPE * const NAME = sizeof(NAME##_)>1 ? (TYPE *) ((NAME##_[0]=sizeof(TYPE)),(1+NAME##_)) : PanicUnlessNew(TYPE)
#define MessageOperatorFrameworkTask(task) MessageOperatorTask(0xC001, task)


/*!
  @brief Send a message to the corresponding task after the given delay in ms.
  The message will be passed to free after delivery.

  @param task The task to deliver the message to.
  @param id The message type identifier. 
  @param message The message data (if any).
  @param delay The delay in ms before the message will be sent.
*/
void MessageSendLater(Task task, MessageId id, void *message, uint32 delay);

/*!
  @brief Cancel the first queued message with the given task and message id.

  @param task The task whose messages will be searched.
  @param id The message identifier to search for.
  @return TRUE if such a message was found and cancelled.
*/
bool MessageCancelFirst(Task task, MessageId id);

/*! 
  @brief Block waiting for the next message. 
  
  @param m This will be filled out if a message is ready to be delivered.

  This function will either:
   - Fill out 'm' if a message is ready for delivery.
   - Send the VM to sleep until message delivery time if a message 
     exists but is not ready for delivery.
   - Send the VM to sleep for the range of a uint32 if no message exists.
*/
void MessageWait(void *m);

/*!
  @brief Send a message to be delivered when the corresponding uint16 is zero.

  @param t The task to deliver the message to.
  @param id The message identifier.
  @param m The message data.
  @param c The condition that must be zero for the message to be delivered.
*/
void MessageSendConditionally(Task t, MessageId id, Message m, const uint16 *c);

/*!
  @brief Frees the memory pointer to by data.
  @param id  The message identifier.
  @param data A pointer to the memory to free.
*/
void MessageFree(MessageId id, Message data);

/*!
  @brief Cancel all queued messages (independent of id) for the given task.

  @param task The task to flush all message for.
  @return The number of messages removed from the queue.

  This function is used as part of the process of freeing a task.

  It will flush all the messages which were queued earlier
  to be sent to the registered task.

  Also, it will deregister the given task from being
  the recipient of any firmware/bluestack messages.
*/
uint16 MessageFlushTask(Task task);

/*!
  @brief Register a task to handle system-wide messages.

  @param task The task which will receive the messages.

  @return The old task (or zero).

  Currently the system-wide messages are:
  - #MESSAGE_USB_ENUMERATED 
  - #MESSAGE_USB_SUSPENDED
  - #MESSAGE_USB_DECONFIGURED
  - #MESSAGE_USB_ALT_INTERFACE
  - #MESSAGE_USB_ATTACHED
  - #MESSAGE_USB_DETACHED
  - #MESSAGE_PSFL_FAULT
  - #MESSAGE_TX_POWER_CHANGE_EVENT

  Other such messages may be added.
*/
Task MessageSystemTask(Task task);

/*!
  @brief Register a task to handle PIO changes.

  @param task This task will receive #MESSAGE_PIO_CHANGED messages when the pins
  configured by PioDebounce32() change.
  @return The old task (or zero).
*/
Task MessagePioTask(Task task);

/*!
  @brief Associate a Task with a Stream using a Sink identifier.

  @param sink The Sink that identifies this Stream. 
  @param task The Task to associate.

  @return The previous Task for this sink, if any, or zero(0) otherwise.

  @note
  # Task cannot be registered for operator sink which is not
     connected to a source.
  # Task cannot be registered for operator sink which is connected
     to an operator source.
  # Task can be registered on all streams irrespective of whether
     they are connected or not.
*/
Task MessageStreamTaskFromSink(Sink sink, Task task);

/*!
  @brief Get the Task currently associated with a sink.
 
  @param sink The sink to use.
*/
Task MessageStreamGetTaskFromSink(Sink sink);

/*!
  @brief Register a task to receive a message when status values change.

  @param task The task to receive the #MESSAGE_STATUS_CHANGED message.
  @param count How many fields to monitor
  @param fields The fields to monitor

  @return The previously registered task, if any.

  The registered task
  will receive just one message and must register itself again if it
  wishes to receive another.

  A message will be sent when any of the listed status fields may have
  changed.
*/
Task MessageStatusTask(Task task, uint16 count, const status_field *fields);

/*!
  @brief Register a task to handle HostComms primitives.

  @param task This task will receive #MESSAGE_FROM_HOST
  @return The old task (or zero).
*/
Task MessageHostCommsTask(Task task);

/*!
  @brief Register a task to handle BlueStack primitives.

  @param task This task will receive MESSAGE_BLUESTACK_*_PRIM, except 
         #MESSAGE_BLUESTACK_ATT_PRIM that are handled by the MessageAttTask().
  @return The old task (or zero).
*/
Task MessageBlueStackTask(Task task);

/*!
  @brief Register a task to handle messages from Kalimba.

  @param task This task will receive #MESSAGE_FROM_KALIMBA and 
              #MESSAGE_FROM_KALIMBA_LONG messages.

  @return The previous task, if any, or zero otherwise.
*/
Task MessageKalimbaTask(Task task);

/*!
    @brief Register a task to handle messages from the onchip battery charger 
           and power system hardware.
    @param task This task will receive #MESSAGE_CHARGER_CHANGED messages when
           parts of the charger or power system hardware changes.
    @return The old task (or zero).
*/
Task MessageChargerTask(Task task);

/*!
    @brief Register a task to handle touch sensor messages.
    @param task The task which will receive the messages.

    @return The old task (or zero).
*/    
Task MessageCapsenseTask(Task task);

/*!
  @brief Register a task to handle BlueStack ATT primitives.

  @param task This task will receive #MESSAGE_BLUESTACK_ATT_PRIM.
  @return The old task (or zero).
*/
Task MessageAttTask(Task task);

/*!
  @brief Register a task to handle infrared messages.

  @param task The task which will receive the messages.

  @return The old task (or zero).
*/
Task MessageInfraredTask(Task task);

/*!
  @brief Registers a task to get the unsolicited messages from operator
  @param Opid operator which registers the task
  @param Task Task which will receive the unsolicited messages from the operator

  @return The previous task, if any, or zero otherwise.

  VM application should register a task for each operator to get the
  unsolicited messages from the operator. The operator posts unsolicited
  messages to the registered task, if they have any.
*/
Task MessageOperatorTask(Operator opid, Task task);

/*!
  @brief Associate a task with a Stream using a Source identifier

  @param source The source that identifies the stream
  @param task The Task to associate with

  @return The previous Task for this source, if any, or zero(0) otherwise.

  @note
  # Task cannot be registered for operator source which is not
    connected to a sink.
  # Task cannot be registered for operator source which is connected
    to an operator sink.
  # Task can be registered on all streams irrespective of whether
    they are connected or not.
*/
Task MessageStreamTaskFromSource(Source source, Task task);

/*!
  @brief Get the task currently associated with a source.
 
  @param source The source to use.
*/
Task MessageStreamGetTaskFromSource(Source source);

/*!
  @brief Register a task to handle the BCCMD messages from Host.

  @param task The task will receive the message #MESSAGE_HOST_BCCMD.
  @return The previous registered task, if any, or zero otherwise.
*/
Task MessageHostBccmdTask(Task task);

/*!
  @brief Send a message to the corresponding task immediately.
  The message will be passed to free after delivery.
 
  @param task The task to deliver the message to.
  @param id The message type identifier.
  @param message The message data (if any).
*/
void MessageSend(Task task, MessageId id, void *message);

/*!
  @brief Cancel all queued messages with the given task and message id.

  @param task The task to cancel message for.
  @param id The message identifier to search for.
  @return A count of how many such messages were cancelled.
*/
uint16 MessageCancelAll(Task task, MessageId id);

/*!
  @brief The main scheduler loop; it waits until the next message is due and
  then sends it to the corresponding task. Never returns.
*/
void MessageLoop(void);

/*!
  @brief Send a message to be delivered when the corresponding Task is zero.

  @param t The task to deliver the message to.
  @param id The message identifier.
  @param m The message data.
  @param c The task that must be zero for the message to be delivered.
*/
void MessageSendConditionallyOnTask(Task t, MessageId id, Message m, const Task *c);

#endif
