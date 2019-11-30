/*******************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 Part of ADK_CSR867x.WIN. 4.4
*******************************************************************************/

#ifndef DALE_IO_DEFS_H_INCLUDED
#define DALE_IO_DEFS_H_INCLUDED

   // Bitfield Defines
   .CONST $FLASH_CACHE_SIZE_1K_ENUM            0x000000;
   .CONST $FLASH_CACHE_SIZE_512_ENUM           0x000001;
   .CONST $ADDSUB_SATURATE_ON_OVERFLOW_POSN    0x000000;
   .CONST $ADDSUB_SATURATE_ON_OVERFLOW_MASK    0x000001;
   .CONST $ARITHMETIC_16BIT_MODE_POSN          0x000001;
   .CONST $ARITHMETIC_16BIT_MODE_MASK          0x000002;
   .CONST $DISABLE_UNBIASED_ROUNDING_POSN      0x000002;
   .CONST $DISABLE_UNBIASED_ROUNDING_MASK      0x000004;
   .CONST $DISABLE_FRAC_MULT_ROUNDING_POSN     0x000003;
   .CONST $DISABLE_FRAC_MULT_ROUNDING_MASK     0x000008;
   .CONST $DISABLE_RMAC_STORE_ROUNDING_POSN    0x000004;
   .CONST $DISABLE_RMAC_STORE_ROUNDING_MASK    0x000010;
   .CONST $FLASHWIN_CONFIG_NOSIGNX_POSN        0x000000;
   .CONST $FLASHWIN_CONFIG_NOSIGNX_MASK        0x000001;
   .CONST $FLASHWIN_CONFIG_24BIT_POSN          0x000001;
   .CONST $FLASHWIN_CONFIG_24BIT_MASK          0x000002;
   .CONST $INT_EVENT_TIMER1_POSN               0x000000;
   .CONST $INT_EVENT_TIMER1_MASK               0x000001;
   .CONST $INT_EVENT_TIMER2_POSN               0x000001;
   .CONST $INT_EVENT_TIMER2_MASK               0x000002;
   .CONST $INT_EVENT_XAP_POSN                  0x000002;
   .CONST $INT_EVENT_XAP_MASK                  0x000004;
   .CONST $INT_EVENT_PIO_POSN                  0x000003;
   .CONST $INT_EVENT_PIO_MASK                  0x000008;
   .CONST $INT_EVENT_MMU_UNMAPPED_POSN         0x000004;
   .CONST $INT_EVENT_MMU_UNMAPPED_MASK         0x000010;
   .CONST $INT_EVENT_SW0_POSN                  0x000005;
   .CONST $INT_EVENT_SW0_MASK                  0x000020;
   .CONST $INT_EVENT_SW1_POSN                  0x000006;
   .CONST $INT_EVENT_SW1_MASK                  0x000040;
   .CONST $INT_EVENT_SW2_POSN                  0x000007;
   .CONST $INT_EVENT_SW2_MASK                  0x000080;
   .CONST $INT_EVENT_SW3_POSN                  0x000008;
   .CONST $INT_EVENT_SW3_MASK                  0x000100;
   .CONST $INT_EVENT_GPS_POSN                  0x000009;
   .CONST $INT_EVENT_GPS_MASK                  0x000200;
   .CONST $BITMODE_POSN                        0x000000;
   .CONST $BITMODE_MASK                        0x000003;
   .CONST $BITMODE_8BIT_ENUM                   0x000000;
   .CONST $BITMODE_16BIT_ENUM                  0x000001;
   .CONST $BITMODE_24BIT_ENUM                  0x000002;
   .CONST $BYTESWAP_POSN                       0x000002;
   .CONST $BYTESWAP_MASK                       0x000004;
   .CONST $SATURATE_POSN                       0x000003;
   .CONST $SATURATE_MASK                       0x000008;
   .CONST $NOSIGNEXT_POSN                      0x000003;
   .CONST $NOSIGNEXT_MASK                      0x000008;

#endif
