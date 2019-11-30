/*
 * Copyright (c) 2018 Qualcomm Technologies International, Ltd.
 * This file was automatically generated for firmware version 22.0
 */

#ifndef __OPERATOR_H

#define __OPERATOR_H

#include <csrtypes.h>
/*! @file operator.h @brief Traps that provide access to the VM-DSP Manager interface
**
**
Operator traps provide access to the DSP Manager interface.
**
DSP Manager is a feature of BlueCore that allows the VM, to
control how data sources and sinks are connected to each other.
It introduces a new kind of functional block called
operator, which is used to process data.
**
An operator is an active entity within DSPManager.
An operator has one or more inputs and one or more outputs.
It need not have the same number of input and output.
It processes the incoming data in some way to generate the
outgoing data - this can be as simple as copying
with a volume change, through mixing two inputs or splitting
an input into two outputs, all the way to things like active
noise cancellation or MP3 encoding or decoding.
**
The behaviour of an operator is called its capability
and an operator instantiates that capability. Each capability
has a unique identifier (the capability identifier or capid).
The general meaning of a given capability will never change
(thus capability 1 is defined as being "mono pass through"
and will always be this).
However, new features may be added to a capability from time to
time in an upwards-compatible manner (that is, host software
that is unaware of the new feature will not be affected by it).
When an operator is created it has a unique operator identifier
or opid that is valid until it is destroyed. Several operators
can instantiate the same capability and all are independent
from each other. When an operator is destroyed its identifier
becomes invalid. The identifier will eventually be re-used,
but normally this re-use will be delayed as long as possible.
Operators can be running or stopped. Starting an operator changes
it from stopped to running; stopping an operator
changes it back to stopped again.
An operator cannot be destroyed while running.
**
The VM may be able to configure an operator by sending it
messages. The operator can also send unsolicited messages to
the VM to inform it of significant events. The messages that
are available (in both directions) and their meaning depend
on the specific capability.
**
**
*/
#include <operator_.h>
#include <string.h>
#include <stdlib.h>
#include <panic.h>
#include <app/operator/operator_if.h>
#define OperatorDestroy(opid) OperatorDestroyMultiple(1, &(opid), NULL)
#define OperatorStart(opid) OperatorStartMultiple(1, &(opid), NULL)
#define OperatorStop(opid) OperatorStopMultiple(1, &(opid), NULL)
#define OperatorReset(opid) OperatorResetMultiple(1, &(opid), NULL)


/*!
  @brief Creates a new operator that instantiates the requested capability 
  @param cap_id Type of the operator (or Capability ID).
  @param num_keys Number of key-value pairs specified. 
  @param info Points to list of key-value pairs for setting certain parameters
  for the operator at the time of its creation.
  @return Operator ID if the operator was created successfully, zero(0) otherwise.

  BlueCore firmware loads the DSP software internally on-demand when the create
  operator trap is called for the first time.

  If the loaded DSP software supports the requested capability then DSP creates
  an operator in stopped state. If it does not support the requested capability,
  then this trap returns zero(0).

  @note
  If DSP is already loaded with DSP software that does not support operators
  then BlueCore firmware returns zero(0) on a call to this trap, till the DSP
  gets powered off.
*/
Operator OperatorCreate(uint16 cap_id, uint16 num_keys, OperatorCreateKeys *info);

/*!
  @brief Destroys one or more operators
  @param n_ops Number of operators to destroy
  @param oplist List of operators to destroy
  @param success_ops Number of successfully destroyed operators, which is 
  passed by reference.
  If set to NULL then this parameter is ignored and application will only 
  know that some (or all) operators could not be destroyed from the return
  status.
  @return TRUE if all operator(s) were successfully destroyed, FALSE otherwise.

  This trap destroys all the operator(s) passed to it as a list. If DSP fails
  to destroy one of the operators then no attempt is made to destroy the
  subsequent operator(s) in the list. The number of successfully destroyed 
  operator(s) is placed in @a success_ops parameter, which is passed by
  reference.
  
  @note
  VM application must handle the allocation and de-allocation of memory space
  for API parameters. If an operator is running, any attempt to destroy the
  operator will fail. An operator can only be destroyed when it has been
  stopped. To destroy a single operator, refer # OperatorDestroy.
*/
bool OperatorDestroyMultiple(uint16 n_ops, Operator *oplist, uint16 *success_ops);

/*!
  @brief Starts one or more operators
  @param n_ops Number of operators to start
  @param oplist List of operators to start
  @param success_ops Number of successfully started operators, which is passed
  by reference. If set to NULL then this parameter is ignored and application
  will only know that some (or all) operators could not be started from the
  return status.
  @return TRUE if all operator(s) were successfully started, FALSE otherwise.

  This starts all the operator(s) passed to it as a list. If DSP fails to
  start one of the operators then no attempt is made to start the subsequent
  operator(s). The number of successfully started operator(s) is placed in
  @a success_ops parameter, which is passed by reference.

  @note
  VM application must handle the allocation and de-allocation of memory space
  for API parameters. It is permitted to start an operator that has already been
  started. Starting an operator that has nothing connected to it, or has
  insufficient connections, may fail (depending on the capability).
*/
bool OperatorStartMultiple(uint16 n_ops, Operator *oplist, uint16 *success_ops);

/*!
  @brief Stops one or more operators
  @param n_ops Number of operators to stop
  @param oplist List of operators to stop
  @param success_ops Number of successfully stopped operators, which is passed
  by reference. If set to NULL then this parameter is ignored and application
  will only know that some (or all) operators could not be stopped from the
  return status.
  @return TRUE if all operator(s) were successfully stopped, FALSE otherwise.

  This API stops all the operator(s) passed to it as a list. If DSP fails to 
  stop one of the operators then no attempt is made to stop the subsequent
  operator(s). The number of successfully stopped operator(s) is placed
  in @a success_ops parameter only if it is not NULL.

  @note
  VM application must handle the allocation and de-allocation of memory space
  for API parameters. It is permitted to stop an operator that has never been
  started or has already been stopped.
*/
bool OperatorStopMultiple(uint16 n_ops, Operator *oplist, uint16 *success_ops);

/*!
  @brief Resets one or more operators
  @param n_ops Number of operators to reset
  @param oplist List of operators to reset
  @param success_ops Number of operators have successfully been reset,
  which is passed by reference. If set to NULL, then this parameter is ignored 
  and application will only know that some (or all) operators could not be
  reset from the return status.
  @return TRUE if all the operator(s) have successfully been reset, FALSE 
  otherwise. 

  This API resets all the operator(s) passed to it as a list. If DSP fails
  to reset one of the operators then no attempt is made to reset the subsequent
  operator(s). The number of operators have successfully been reset is placed
  in @a success_ops parameter only if it is not NULL.

  @note
  VM application must handle the allocation and de-allocation of memory space
  for API parameters. It is permitted to reset an operator that has never been
  started or has already been stopped.
*/
bool OperatorResetMultiple(uint16 n_ops, Operator *oplist, uint16 *success_ops);

/*!
  @brief Sends a message to the operator
  @param opid Operator to which VM application sends a message
  @param send_msg Message to the operator
  @param send_len Length of the message to be sent
  @param recv_msg Message response, which will be received from the DSP
  in response to the sent message
  @param recv_len Length of the response message
  @return TRUE if it gets a response from the specific operator, otherwise FALSE.
  
  The messages that are available and their meaning depend on the specific
  capability that the operator instantiates.

  Apart from sending message to an operator, there are messages that can be
  sent directly to the DSP component of DSPManager. These messages
  are sent as an operator message with the special operator ID of 0xC001.
  The special operator ID 0xC001 (which is not a valid operator ID) is used only
  to send a message to the DSP component of the DSPManager.

  @note
  VM application must handle the allocation and de-allocation of memory space
  for API parameters. Determining the size of the message to be sent and that
  of the corresponding response-message to be received depends on the
  respective structures being used for the message to be sent and received.

  @note
  If DSP is already loaded with DSP software that does not support operators
  then BlueCore firmware returns FALSE for any operator message request
  till DSP gets powered off.
*/
bool OperatorMessage(Operator opid, void *send_msg, uint16 send_len,void *recv_msg, uint16 recv_len);

/*!
  @brief Loads DSP operator framework / powers-off DSP.
  @param state DSP operator framework power state for specific DSP core.
  @return TRUE if DSP operator framework is loaded / unloaded successfully,
  FALSE otherwise.

  @note
  Multiple VM libraries or the application can load and power-off DSP
  independently. All the VM libraries and application MUST follow the
  below sequences to reduce system power consumption by powering-off DSP.

  Step-1: OperatorFrameworkEnable (ON);
  Step-2: Create operators / Download a new capability
  Step-3: Perform operator actions / Send message to operators
  Step-4: Destroy operators / Remove downloaded capability
  Step-5: OperatorFrameworkEnable (OFF);

  The VM library / application cannot assume DSP being powered off even
  after receiving a TRUE return from OperatorFrameworkEnable(OFF) because
  some other part of the application might keep it on.

  The VM library / application should not rely on getting a FALSE return for
  OperatorFrameworkEnable(OFF) as the FALSE return could be because of an
  error made a long time ago. It is at most an opportunity to detect errors.
*/
bool OperatorFrameworkEnable(OperatorFrameworkPowerState state);

/*!
  @brief Sets DSP operator framework configuration parameters.
  @param key Configuration parameter identifier.
  @param send_msg Points to configuration parameters to be set.
  @param send_len Number of configuration parameters to set.

  @return TRUE if the DSP operator framework parameters have successfully been 
  set, FALSE otherwise.
*/
bool OperatorFrameworkConfigurationSet(uint16 key, void *send_msg, uint16 send_len);

/*!
  @brief Gets DSP operator framework configuration parameters.
  @param key Configuration parameter identifier.
  @param send_msg Message to DSP framework for getting the configuration 
  parameters.
  @param send_len Length of message to be sent.
  @param recv_msg The response containing the requested configuration
  parameters.
  @param recv_len Length of the response containing requested configuration 
  parameters.
  @return TRUE if it gets a response from the DSP framework, otherwise FALSE.

  @note
  send_msg specifies more about what exactly is to be fetched.
*/
bool OperatorFrameworkConfigurationGet(uint16 key, void *send_msg, uint16 send_len, void *recv_msg, uint16 recv_len);

#endif
