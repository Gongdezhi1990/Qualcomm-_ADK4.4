// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CBUFFER_HEADER_INCLUDED
#define CBUFFER_HEADER_INCLUDED

#include "cbuffer_defines.h"

   .CONST    $cbuffer.SIZE_FIELD           0;
   .CONST    $cbuffer.READ_ADDR_FIELD      1;
   .CONST    $cbuffer.WRITE_ADDR_FIELD     2;
   #ifdef BASE_REGISTER_MODE
      .CONST    $cbuffer.START_ADDR_FIELD     3;
      .CONST    $cbuffer.STRUC_SIZE           4;
   #else
      .CONST    $cbuffer.STRUC_SIZE           3;
   #endif


   // Frame Buffer for Processing Modules
   .CONST    $frmbuffer.CBUFFER_PTR_FIELD             0;
   .CONST    $frmbuffer.FRAME_PTR_FIELD               1;
   .CONST    $frmbuffer.FRAME_SIZE_FIELD              2;
   .CONST    $frmbuffer.STRUC_SIZE                    3;
	
   // flags to indicate port connect or disconnect for callback functions
   .CONST    $cbuffer.CALLBACK_PORT_DISCONNECT        CBUFFER_CALLBACK_PORT_DISCONNECT;
   .CONST    $cbuffer.CALLBACK_PORT_CONNECT           CBUFFER_CALLBACK_PORT_CONNECT;

   // flags in MESSAGE_CONFIGURE_PORT indicating type of metadata
   .CONST    $cbuffer.CONFIGURE_PORT_IS_SCO_METADATA  0x000001;
   .CONST    $cbuffer.CONFIGURE_PORT_IS_KAL_METADATA  0x000002;
   .CONST    $cbuffer.CONFIGURE_PORT_IS_DMB           0x000004;
   .CONST    $cbuffer.DMB_PORT_HEADER_MIN_SIZE        2;
   .CONST    $cbuffer.DMB_PORT_HEADER_STD_SIZE        3;
   .CONST    $cbuffer.DMB_PORT_HEADER_WORD            0x10C0;
   .CONST    $cbuffer.DMB_PORT_HEADER_PORT_MASK       0x00001F;
   .CONST    $cbuffer.DMB_PORT_HEADER_MSG_MASK        0x008000;
   .CONST    $cbuffer.DMB_CBUFFER_HEADER_MIN_SIZE     2;
   .CONST    $cbuffer.DMB_CBUFFER_HEADER_OFFSET_INDEX 0;
   .CONST    $cbuffer.DMB_CBUFFER_HEADER_SIZE_INDEX   1;

   // MMU port identifier masks
   .CONST    $cbuffer.NUM_PORTS                       CBUFFER_NUM_PORTS;
   .CONST    $cbuffer.NUM_MMU_PORTS                   CBUFFER_NUM_MMU_PORTS;
   .CONST    $cbuffer.WRITE_PORT_OFFSET               CBUFFER_WRITE_PORT_OFFSET;
   .CONST    $cbuffer.PORT_NUMBER_MASK                CBUFFER_PORT_NUMBER_MASK;
   .CONST    $cbuffer.TOTAL_PORT_NUMBER_MASK          CBUFFER_TOTAL_PORT_NUMBER_MASK;
   .CONST    $cbuffer.TOTAL_CONTINUOUS_PORTS          CBUFFER_TOTAL_CONTINUOUS_PORTS;

   .CONST    $cbuffer.MMU_PAGE_SIZE                   CBUFFER_MMU_PAGE_SIZE;

   .CONST    $cbuffer.READ_PORT_MASK                  CBUFFER_READ_PORT_MASK;
   .CONST    $cbuffer.WRITE_PORT_MASK                 CBUFFER_WRITE_PORT_MASK;


   // MMU port force masks
   // force 'endian' constants
   .CONST    $cbuffer.FORCE_ENDIAN_MASK               CBUFFER_FORCE_ENDIAN_MASK;
   .CONST    $cbuffer.FORCE_ENDIAN_SHIFT_AMOUNT       CBUFFER_FORCE_ENDIAN_SHIFT_AMOUNT;
   .CONST    $cbuffer.FORCE_LITTLE_ENDIAN             CBUFFER_FORCE_LITTLE_ENDIAN;
   .CONST    $cbuffer.FORCE_BIG_ENDIAN                CBUFFER_FORCE_BIG_ENDIAN;

   // force 'sign extend' constants
   .CONST    $cbuffer.FORCE_SIGN_EXTEND_MASK          CBUFFER_FORCE_SIGN_EXTEND_MASK;
   .CONST    $cbuffer.FORCE_SIGN_EXTEND_SHIFT_AMOUNT  CBUFFER_FORCE_SIGN_EXTEND_SHIFT_AMOUNT;
   .CONST    $cbuffer.FORCE_SIGN_EXTEND               CBUFFER_FORCE_SIGN_EXTEND;
   .CONST    $cbuffer.FORCE_NO_SIGN_EXTEND            CBUFFER_FORCE_NO_SIGN_EXTEND;

   // force 'bit width' constants
   .CONST    $cbuffer.FORCE_BITWIDTH_MASK             CBUFFER_FORCE_BITWIDTH_MASK;
   .CONST    $cbuffer.FORCE_BITWIDTH_SHIFT_AMOUNT     CBUFFER_FORCE_BITWIDTH_SHIFT_AMOUNT;
   .CONST    $cbuffer.FORCE_8BIT_WORD                 CBUFFER_FORCE_8BIT_WORD;
   .CONST    $cbuffer.FORCE_16BIT_WORD                CBUFFER_FORCE_16BIT_WORD;
   .CONST    $cbuffer.FORCE_24BIT_WORD                CBUFFER_FORCE_24BIT_WORD;
   .CONST    $cbuffer.FORCE_32BIT_WORD                CBUFFER_FORCE_32BIT_WORD;

   // force 'saturate' constants
   .CONST    $cbuffer.FORCE_SATURATE_MASK             CBUFFER_FORCE_SATURATE_MASK;
   .CONST    $cbuffer.FORCE_SATURATE_SHIFT_AMOUNT     CBUFFER_FORCE_SATURATE_SHIFT_AMOUNT;
   .CONST    $cbuffer.FORCE_NO_SATURATE               CBUFFER_FORCE_NO_SATURATE;
   .CONST    $cbuffer.FORCE_SATURATE                  CBUFFER_FORCE_SATURATE;

   .CONST    $cbuffer.FORCE_PADDING_MASK              CBUFFER_FORCE_PADDING_MASK;
   .CONST    $cbuffer.FORCE_PADDING_SHIFT_AMOUNT      CBUFFER_FORCE_PADDING_SHIFT_AMOUNT;
   .CONST    $cbuffer.FORCE_PADDING_NONE              CBUFFER_FORCE_PADDING_NONE;
   .CONST    $cbuffer.FORCE_PADDING_LS_BYTE           CBUFFER_FORCE_PADDING_LS_BYTE;
   .CONST    $cbuffer.FORCE_PADDING_MS_BYTE           CBUFFER_FORCE_PADDING_MS_BYTE;

   // force 'defaults for pcm audio' constants
   .CONST    $cbuffer.FORCE_PCM_AUDIO                 CBUFFER_FORCE_PCM_AUDIO;
   .CONST    $cbuffer.FORCE_24B_PCM_AUDIO             CBUFFER_FORCE_24B_PCM_AUDIO;
   // force 'defaults for raw 16bit data' constants
   .CONST    $cbuffer.FORCE_16BIT_DATA_STREAM         CBUFFER_FORCE_16BIT_DATA_STREAM;


#endif
