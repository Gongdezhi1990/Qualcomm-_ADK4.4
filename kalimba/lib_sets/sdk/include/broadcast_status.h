/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/
/**
 * @file  broadcast_status.h
 *
 * @brief Broadcast status messages sent from the DSP applications to the VM.
 */

#ifndef BROADCAST_STATUS_H
#define BROADCAST_STATUS_H

#include <csb_input.h>
#include <csb_output.h>
#include <erasure_code_input.h>
#include <ttp.h>

/**
 * \brief  Send a broadcast status message for the broadcast DSP application.
 *
 * \param msg_id [IN] The id of the message.
 * \param ttp_state [IN] Pointer to the TTP state.
 * \param csb_output_params [IN] Pointer to the CSB output parameters.
 */
void broadcast_status_send_broadcaster(unsigned msg_id, struct ttp_state *ttp_state,
                                       csb_output_params_t* csb_output_params);

/**
 * \brief  Send a broadcast status message for the receiver DSP application.
 *
 * \param msg_id [IN] The id of the message.
 * \param csb_input [IN] Pointer to the CSB input.
 * \param ec_input [IN] Pointer to the Erasure Code input.
 */
void broadcast_status_send_receiver(unsigned msg_id, csb_input_t *csb_input, ec_input_t *ec_input);

#endif
