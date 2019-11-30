/*!

 Copyright (c) 2017 - 2018 Qualcomm Technologies International, Ltd.
 All Rights Reserved.
 Qualcomm Technologies International, Ltd. Confidential and Proprietary.

\file   vendor_specific_hci.h

\brief  This file contains HCI specific type definitions for Qualcomm Vendor
        Specific commands.

\verbatim
 *++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 *
 *   W   W    A    RRRR   N   N  IIIII  N   N   GGG
 *   W   W   A A   R   R  N   N    I    N   N  G   G
 *   W   W  A   A  R   R  NN  N    I    NN  N  G
 *   W   W  A   A  RRRR   N N N    I    N N N  G GGG
 *   W W W  AAAAA  R R    N  NN    I    N  NN  G   G
 *   W W W  A   A  R  R   N   N    I    N   N  G   G
 *    W W   A   A  R   R  N   N  IIIII  N   N   GGGG
 *
 *  This header file uses structures for defining the messages, but does
 *  nothing regarding the guaranteeing of packing of those structures.
 *
 *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
\endverbatim
*/


#ifndef BLUESTACK_VENDOR__HCI_H    /* Once is enough */
#define BLUESTACK_VENDOR__HCI_H

/*****************************************************************************
*  We expect this file to be included *only* by hci.h. This file is for 
*  vendor specific commands only and is actually a part of hci.h. We have
*  separated these commands in order to keep hci.h clean.
*****************************************************************************/

typedef uint8_t hci_sub_op_code_t;            /* used for Qualcomm commands  */

/******************************************************************************
  OP CODE defines - ULP
 ******************************************************************************/
#define HCI_ULP_QVS_BT_LOWER_TESTER              ((hci_op_code_t)HCI_MANUFACTURER_EXTENSION| 0x0018)

/******************************************************************************
   HCI_COMMAND, Argument Length Definitions.
 *****************************************************************************/
#define HCI_LT_DATA_LENGTH_LEN                  ((uint8_t)  9)
#define HCI_LT_PHY_TEST_MODE_LEN                ((uint8_t)  4)

/******************************************************************************
   HCI_COMMAND_COMPLETE, Argument Length Definitions (Full length)
   Should consist of: nhcp (1) + opcode (2) + return parameters
                    : = 3 + return parameters from spec (incl. status)
   When an argument length is dependant on the number of elements in the array
   the defined length contains the constant parameter lengths only. The full
   array length must be calculated.
*****************************************************************************/
#define  HCI_ULP_QVS_BT_LOWER_TESTER_ARG_LEN     ((uint8_t)  5)

/******************************************************************************* 
    Qualcomm Vendor Specific command sub-opcodes 
 ******************************************************************************/
#define SUB_OPCODE_LT_DATA_LENGTH                  ((uint8_t) 0xB)
#define SUB_OPCODE_LT_PHY_TEST_MODE                ((uint8_t) 0xC)

/******************************************************************************* 
    MACROS
 ******************************************************************************/
/* Used by the Lower Tester PHY Test Mode command */

#ifdef INSTALL_ULP_MULTI_PHY
extern uint16_t global_phy_test_mode;
extern uint16_t global_phy_m2s;
extern uint16_t global_phy_s2m;
#endif

/* Used by the HCI Qualcomm Lower Tester PHY Test Mode command */

typedef enum {
/* Used by the Slave Resp of PHY Update Procedure. When set to 1, it forces the 
Slave to send an LL_UNKNOWN_PHY PDU to the other end. */
    DEBUG_ULP_2LE_UNKN_RSP = 1,
/* Used by the Master Init/Resp of PHY Update Procedure and also by Slave 
Resp of PHY Update procedure. When set to 1, it forces the Master/Slave to *NOT* 
send an LL_PHY_UPDATE_REQ/LL_PHY_RSP PDU to the other end. 
This means that the other end will timeout.*/
    DEBUG_ULP_2LE_TIMEOUT = 2,
/* Flag used by the Master or Slave Init of PHY Update Procedure. 
When set to 1, it will block the initiation of the PHY Exchange. */
    DEBUG_ULP_2LE_BLOCK_INIT = 4,
/* Used to force the instant of an LL_PHY_UPDATE_REQ PDU to be in the past 
(well actually zero). This is used for testing the remote device response to 
receiving a past instant. Setting to 1 will force the update instant to be zero.*/
    DEBUG_ULP_2LE_INSTANT_PAST = 8,
/* Used by the Master Init or Resp of PHY Update Procedure. When set to 1, it 
forces the Master to use m2s_phy and s2m_phy in the LL_PHY_UPDATE_REQ.*/
    DEBUG_ULP_2LE_FORCE_UPDATE_REQ = 16,
/* Used by Master or Slave of an LE link. When used by Master or Slave
initiator it forces a PHY_REQ with the values given in global_phy_m2s and 
global_phy_s2m. The debug command must be followed by an LE Set PHY command 
whose TX_PHY and RX_PHY parameters will be ignored in the PHY update procedure.
When used by Slave responder it forces a PHY_RSP with the values given in 
global_phy_m2s and global_phy_s2m.*/
    DEBUG_ULP_2LE_FORCE_REQ_RSP = 32
} DEBUG_ULP_2LE_PHY_TEST_MODES;


#ifdef LMP_DEBUG
#define IS_PHY_TEST_MODE_BIT_ON(x)  (global_phy_test_mode & (x))
#else
#define IS_PHY_TEST_MODE_BIT_ON(x)  (FALSE)
#endif

/*----------------------------------------------------------------------------*
 * PURPOSE
 *     HCI Qualcomm Lower Tester Data Length command
 *
 *----------------------------------------------------------------------------*/

typedef struct
{
    uint8_t                  override;
    uint16_t                 max_tx_octets;
    uint16_t                 max_rx_octets;
    uint16_t                 max_tx_time;
    uint16_t                 max_rx_time;
} HCI_LT_DATA_LENGTH_T;

/*----------------------------------------------------------------------------*
 * PURPOSE
 *     HCI Qualcomm Lower Tester PHY Test Mode command
 *
 *----------------------------------------------------------------------------*/
typedef struct
{
    uint8_t                  enable;
    uint8_t                  phy_test_mode;
    uint8_t                  phy_m2s;
    uint8_t                  phy_s2m;
} HCI_LT_PHY_TEST_MODE_T;


/*----------------------------------------------------------------------------*
 * PURPOSE
 *     HCI Qualcomm Vendor Specific command OpCode = 0xFC18
 *
 *----------------------------------------------------------------------------*/
typedef struct
{
  hci_sub_op_code_t          sub_opcode;
} HCI_ULP_QVS_BT_LOWER_TESTER_RET_T;


typedef union
{
    HCI_LT_DATA_LENGTH_T     hci_lt_data_length;
    HCI_LT_PHY_TEST_MODE_T   hci_lt_phy_test_mode;
} HCI_QVS_COMMAND_T;

typedef struct
{
    HCI_COMMAND_COMMON_T     common;
    hci_sub_op_code_t        sub_opcode;
    HCI_QVS_COMMAND_T        command;
} HCI_ULP_QVS_BT_LOWER_TESTER_T;

#endif
