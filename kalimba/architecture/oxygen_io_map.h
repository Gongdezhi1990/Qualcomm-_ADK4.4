// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef OXYGEN_IO_MAP_H_INCLUDED
#define OXYGEN_IO_MAP_H_INCLUDED

   // Memory map
   .CONST $INT_SW_ERROR_EVENT_TRIGGER          0xFFFE00; // RW   0 bits
   .CONST $INT_GBL_ENABLE                      0xFFFE11; // RW   1 bits
   .CONST $INT_ENABLE                          0xFFFE12; // RW   1 bits
   .CONST $INT_CLK_SWITCH_EN                   0xFFFE13; // RW   1 bits
   .CONST $INT_SOURCES_EN                      0xFFFE14; // RW  10 bits
   .CONST $INT_PRIORITIES                      0xFFFE15; // RW  20 bits
   .CONST $INT_LOAD_INFO                       0xFFFE16; // RW  15 bits
   .CONST $INT_ACK                             0xFFFE17; // RW   1 bits
   .CONST $INT_SOURCE                          0xFFFE18; //  R   6 bits
   .CONST $INT_SAVE_INFO                       0xFFFE19; //  R  15 bits
   .CONST $INT_ADDR                            0xFFFE1A; // RW  24 bits
   .CONST $DSP2MCU_EVENT_DATA                  0xFFFE1B; // RW  16 bits
   .CONST $PC_STATUS                           0xFFFE1C; //  R  24 bits
   .CONST $MCU2DSP_EVENT_DATA                  0xFFFE1D; //  R  16 bits
   .CONST $DOLOOP_CACHE_EN                     0xFFFE1E; // RW   1 bits
   .CONST $TIMER1_EN                           0xFFFE1F; // RW   1 bits
   .CONST $TIMER2_EN                           0xFFFE20; // RW   1 bits
   .CONST $TIMER1_TRIGGER                      0xFFFE21; // RW  24 bits
   .CONST $TIMER2_TRIGGER                      0xFFFE22; // RW  24 bits
   .CONST $WRITE_PORT0_DATA                    0xFFFE23; //  W  24 bits
   .CONST $WRITE_PORT1_DATA                    0xFFFE24; //  W  24 bits
   .CONST $WRITE_PORT2_DATA                    0xFFFE25; //  W  24 bits
   .CONST $WRITE_PORT3_DATA                    0xFFFE26; //  W  24 bits
   .CONST $WRITE_PORT4_DATA                    0xFFFE27; //  W  24 bits
   .CONST $WRITE_PORT5_DATA                    0xFFFE28; //  W  24 bits
   .CONST $WRITE_PORT6_DATA                    0xFFFE29; //  W  24 bits
   .CONST $WRITE_PORT7_DATA                    0xFFFE2A; //  W  24 bits
   .CONST $READ_PORT0_DATA                     0xFFFE2B; //  R  24 bits
   .CONST $READ_PORT1_DATA                     0xFFFE2C; //  R  24 bits
   .CONST $READ_PORT2_DATA                     0xFFFE2D; //  R  24 bits
   .CONST $READ_PORT3_DATA                     0xFFFE2E; //  R  24 bits
   .CONST $READ_PORT4_DATA                     0xFFFE2F; //  R  24 bits
   .CONST $READ_PORT5_DATA                     0xFFFE30; //  R  24 bits
   .CONST $READ_PORT6_DATA                     0xFFFE31; //  R  24 bits
   .CONST $READ_PORT7_DATA                     0xFFFE32; //  R  24 bits
   .CONST $PORT_BUFFER_SET                     0xFFFE33; // RW   0 bits
   .CONST $MM_DOLOOP_START                     0xFFFE40; // RW  24 bits
   .CONST $MM_DOLOOP_END                       0xFFFE41; // RW  24 bits
   .CONST $MM_QUOTIENT                         0xFFFE42; // RW  24 bits
   .CONST $MM_REM                              0xFFFE43; // RW  24 bits
   .CONST $MM_RINTLINK                         0xFFFE44; // RW  24 bits
   .CONST $CLOCK_DIVIDE_RATE                   0xFFFE4D; // RW  16 bits
   .CONST $INT_CLOCK_DIVIDE_RATE               0xFFFE4E; // RW  16 bits
   .CONST $PIO_IN                              0xFFFE4F; //  R  24 bits
   .CONST $PIO2_IN                             0xFFFE50; //  R   8 bits
   .CONST $PIO_OUT                             0xFFFE51; // RW  24 bits
   .CONST $PIO2_OUT                            0xFFFE52; // RW   8 bits
   .CONST $PIO_DIR                             0xFFFE53; // RW  24 bits
   .CONST $PIO2_DIR                            0xFFFE54; // RW   8 bits
   .CONST $PIO_EVENT_EN_MASK                   0xFFFE55; // RW  24 bits
   .CONST $PIO2_EVENT_EN_MASK                  0xFFFE56; // RW   8 bits
   .CONST $INT_SW0_EVENT                       0xFFFE57; // RW   1 bits
   .CONST $INT_SW1_EVENT                       0xFFFE58; // RW   1 bits
   .CONST $INT_SW2_EVENT                       0xFFFE59; // RW   1 bits
   .CONST $INT_SW3_EVENT                       0xFFFE5A; // RW   1 bits
   .CONST $FLASH_WINDOW1_START_ADDR            0xFFFE5B; // RW  23 bits
   .CONST $FLASH_WINDOW2_START_ADDR            0xFFFE5C; // RW  23 bits
   .CONST $FLASH_WINDOW3_START_ADDR            0xFFFE5D; // RW  23 bits
   .CONST $NOSIGNX_MCUWIN1                     0xFFFE5F; // RW   1 bits
   .CONST $NOSIGNX_MCUWIN2                     0xFFFE60; // RW   1 bits
   .CONST $FLASHWIN1_CONFIG                    0xFFFE61; // RW   2 bits
   .CONST $FLASHWIN2_CONFIG                    0xFFFE62; // RW   2 bits
   .CONST $FLASHWIN3_CONFIG                    0xFFFE63; // RW   2 bits
   .CONST $NOSIGNX_PMWIN                       0xFFFE64; // RW   1 bits
   .CONST $PM_WIN_ENABLE                       0xFFFE65; // RW   1 bits
   .CONST $STACK_START_ADDR                    0xFFFE66; // RW  24 bits
   .CONST $STACK_END_ADDR                      0xFFFE67; // RW  24 bits
   .CONST $STACK_POINTER                       0xFFFE68; // RW  24 bits
   .CONST $STACK_OVERFLOW_PC                   0xFFFE69; //  R  24 bits
   .CONST $FRAME_POINTER                       0xFFFE6A; // RW  24 bits
   .CONST $NUM_RUN_CLKS_MS                     0xFFFE6B; // RW   8 bits
   .CONST $NUM_RUN_CLKS_LS                     0xFFFE6C; // RW  24 bits
   .CONST $NUM_INSTRS_MS                       0xFFFE6D; // RW   8 bits
   .CONST $NUM_INSTRS_LS                       0xFFFE6E; // RW  24 bits
   .CONST $NUM_STALLS_MS                       0xFFFE6F; // RW   8 bits
   .CONST $NUM_STALLS_LS                       0xFFFE70; // RW  24 bits
   .CONST $TIMER_TIME                          0xFFFE71; //  R  24 bits
   .CONST $TIMER_TIME_MS                       0xFFFE72; //  R   8 bits
   .CONST $WRITE_PORT0_CONFIG                  0xFFFE73; // RW   4 bits
   .CONST $WRITE_PORT1_CONFIG                  0xFFFE74; // RW   4 bits
   .CONST $WRITE_PORT2_CONFIG                  0xFFFE75; // RW   4 bits
   .CONST $WRITE_PORT3_CONFIG                  0xFFFE76; // RW   4 bits
   .CONST $WRITE_PORT4_CONFIG                  0xFFFE77; // RW   4 bits
   .CONST $WRITE_PORT5_CONFIG                  0xFFFE78; // RW   4 bits
   .CONST $WRITE_PORT6_CONFIG                  0xFFFE79; // RW   4 bits
   .CONST $WRITE_PORT7_CONFIG                  0xFFFE7A; // RW   4 bits
   .CONST $READ_PORT0_CONFIG                   0xFFFE7B; // RW   4 bits
   .CONST $READ_PORT1_CONFIG                   0xFFFE7C; // RW   4 bits
   .CONST $READ_PORT2_CONFIG                   0xFFFE7D; // RW   4 bits
   .CONST $READ_PORT3_CONFIG                   0xFFFE7E; // RW   4 bits
   .CONST $READ_PORT4_CONFIG                   0xFFFE7F; // RW   4 bits
   .CONST $READ_PORT5_CONFIG                   0xFFFE80; // RW   4 bits
   .CONST $READ_PORT6_CONFIG                   0xFFFE81; // RW   4 bits
   .CONST $READ_PORT7_CONFIG                   0xFFFE82; // RW   4 bits
   .CONST $PM_FLASHWIN_START_ADDR              0xFFFE83; // RW  23 bits
   .CONST $PM_FLASHWIN_SIZE                    0xFFFE84; // RW  24 bits
   .CONST $BITREVERSE_VAL                      0xFFFE89; // RW  24 bits
   .CONST $BITREVERSE_DATA                     0xFFFE8A; //  R  24 bits
   .CONST $BITREVERSE_DATA16                   0xFFFE8B; //  R  24 bits
   .CONST $BITREVERSE_ADDR                     0xFFFE8C; //  R  24 bits
   .CONST $ARITHMETIC_MODE                     0xFFFE93; // RW   5 bits
   .CONST $FORCE_FAST_MMU                      0xFFFE94; // RW   1 bits
   .CONST $DBG_COUNTERS_EN                     0xFFFE9F; // RW   1 bits
   .CONST $DSP_ROM_PATCH0_ADDR                 0xFFFEB0; // RW  23 bits
   .CONST $DSP_ROM_PATCH1_ADDR                 0xFFFEB1; // RW  23 bits
   .CONST $DSP_ROM_PATCH2_ADDR                 0xFFFEB2; // RW  23 bits
   .CONST $DSP_ROM_PATCH3_ADDR                 0xFFFEB3; // RW  23 bits
   .CONST $DSP_ROM_PATCH4_ADDR                 0xFFFEB4; // RW  23 bits
   .CONST $DSP_ROM_PATCH5_ADDR                 0xFFFEB5; // RW  23 bits
   .CONST $DSP_ROM_PATCH6_ADDR                 0xFFFEB6; // RW  23 bits
   .CONST $DSP_ROM_PATCH7_ADDR                 0xFFFEB7; // RW  23 bits
   .CONST $DSP_ROM_PATCH8_ADDR                 0xFFFEB8; // RW  23 bits
   .CONST $DSP_ROM_PATCH9_ADDR                 0xFFFEB9; // RW  23 bits
   .CONST $DSP_ROM_PATCH10_ADDR                0xFFFEBA; // RW  23 bits
   .CONST $DSP_ROM_PATCH11_ADDR                0xFFFEBB; // RW  23 bits
   .CONST $DSP_ROM_PATCH12_ADDR                0xFFFEBC; // RW  23 bits
   .CONST $DSP_ROM_PATCH13_ADDR                0xFFFEBD; // RW  23 bits
   .CONST $DSP_ROM_PATCH14_ADDR                0xFFFEBE; // RW  23 bits
   .CONST $DSP_ROM_PATCH15_ADDR                0xFFFEBF; // RW  23 bits
   .CONST $DSP_ROM_PATCH0_BRANCH               0xFFFEC0; // RW  14 bits
   .CONST $DSP_ROM_PATCH1_BRANCH               0xFFFEC1; // RW  14 bits
   .CONST $DSP_ROM_PATCH2_BRANCH               0xFFFEC2; // RW  14 bits
   .CONST $DSP_ROM_PATCH3_BRANCH               0xFFFEC3; // RW  14 bits
   .CONST $DSP_ROM_PATCH4_BRANCH               0xFFFEC4; // RW  14 bits
   .CONST $DSP_ROM_PATCH5_BRANCH               0xFFFEC5; // RW  14 bits
   .CONST $DSP_ROM_PATCH6_BRANCH               0xFFFEC6; // RW  14 bits
   .CONST $DSP_ROM_PATCH7_BRANCH               0xFFFEC7; // RW  14 bits
   .CONST $DSP_ROM_PATCH8_BRANCH               0xFFFEC8; // RW  14 bits
   .CONST $DSP_ROM_PATCH9_BRANCH               0xFFFEC9; // RW  14 bits
   .CONST $DSP_ROM_PATCH10_BRANCH              0xFFFECA; // RW  14 bits
   .CONST $DSP_ROM_PATCH11_BRANCH              0xFFFECB; // RW  14 bits
   .CONST $DSP_ROM_PATCH12_BRANCH              0xFFFECC; // RW  14 bits
   .CONST $DSP_ROM_PATCH13_BRANCH              0xFFFECD; // RW  14 bits
   .CONST $DSP_ROM_PATCH14_BRANCH              0xFFFECE; // RW  14 bits
   .CONST $DSP_ROM_PATCH15_BRANCH              0xFFFECF; // RW  14 bits
   .CONST $PM_FLASHWIN_CACHE_SIZE              0xFFFEE0; // RW   1 bits
   .CONST $GPS_SSP_PIO_CFG                     0xFFFEF0; // RW   8 bits
   .CONST $GPS_SSP_DEBUG_CFG                   0xFFFEF1; // RW   7 bits
   .CONST $GPS_SSP_DEBUG                       0xFFFEF2; //  R  24 bits
   .CONST $GPS_SSP_TEST_IQ                     0xFFFEF3; // RW  24 bits
   .CONST $GPU_ROUTING1                        0xFFFF00; // RW  24 bits
   .CONST $GPU_ROUTING2                        0xFFFF01; // RW  22 bits
   .CONST $GPU_ROUTING3                        0xFFFF02; // RW  20 bits
   .CONST $GPU_ROUTING4                        0xFFFF03; // RW  20 bits
   .CONST $GPU_ROUTING5                        0xFFFF04; // RW  14 bits
   .CONST $GPU_DAG0_BUFFER_ADDRESS             0xFFFF05; // RW  24 bits
   .CONST $GPU_DAG0_CONTROL1                   0xFFFF06; // RW  24 bits
   .CONST $GPU_DAG0_CONTROL2                   0xFFFF07; // RW  24 bits
   .CONST $GPU_DAG0_CONTROL3                   0xFFFF08; // RW  19 bits
   .CONST $GPU_DAG0_CONTROL4                   0xFFFF09; // RW  11 bits
   .CONST $GPU_DAG0_WINDOW_START               0xFFFF0A; // RW  24 bits
   .CONST $GPU_DAG0_WINDOW_STOP                0xFFFF0B; // RW  24 bits
   .CONST $GPU_DAG0_WINDOW_FILLCONST           0xFFFF0C; // RW  24 bits
   .CONST $GPU_DAG0_CONTROL5                   0xFFFF0D; // RW  24 bits
   .CONST $GPU_DAG1_BUFFER_ADDRESS             0xFFFF0E; // RW  24 bits
   .CONST $GPU_DAG1_CONTROL1                   0xFFFF0F; // RW  24 bits
   .CONST $GPU_DAG1_CONTROL2                   0xFFFF10; // RW  24 bits
   .CONST $GPU_DAG1_CONTROL3                   0xFFFF11; // RW  19 bits
   .CONST $GPU_DAG1_CONTROL4                   0xFFFF12; // RW  11 bits
   .CONST $GPU_DAG1_WINDOW_START               0xFFFF13; // RW  24 bits
   .CONST $GPU_DAG1_WINDOW_STOP                0xFFFF14; // RW  24 bits
   .CONST $GPU_DAG1_WINDOW_FILLCONST           0xFFFF15; // RW  24 bits
   .CONST $GPU_DAG1_CONTROL5                   0xFFFF16; // RW  24 bits
   .CONST $GPU_DAG2_BUFFER_ADDRESS             0xFFFF17; // RW  24 bits
   .CONST $GPU_DAG2_CONTROL1                   0xFFFF18; // RW  24 bits
   .CONST $GPU_DAG2_CONTROL2                   0xFFFF19; // RW  24 bits
   .CONST $GPU_DAG2_CONTROL3                   0xFFFF1A; // RW  19 bits
   .CONST $GPU_DAG2_CONTROL4                   0xFFFF1B; // RW  11 bits
   .CONST $GPU_DAG2_WINDOW_START               0xFFFF1C; // RW  24 bits
   .CONST $GPU_DAG2_WINDOW_STOP                0xFFFF1D; // RW  24 bits
   .CONST $GPU_DAG2_WINDOW_FILLCONST           0xFFFF1E; // RW  24 bits
   .CONST $GPU_DAG2_CONTROL5                   0xFFFF1F; // RW  24 bits
   .CONST $GPU_DAG3_BUFFER_ADDRESS             0xFFFF20; // RW  24 bits
   .CONST $GPU_DAG3_CONTROL1                   0xFFFF21; // RW  24 bits
   .CONST $GPU_DAG3_CONTROL2                   0xFFFF22; // RW  24 bits
   .CONST $GPU_DAG3_CONTROL3                   0xFFFF23; // RW  19 bits
   .CONST $GPU_DAG3_CONTROL4                   0xFFFF24; // RW  11 bits
   .CONST $GPU_DAG3_WINDOW_START               0xFFFF25; // RW  24 bits
   .CONST $GPU_DAG3_WINDOW_STOP                0xFFFF26; // RW  24 bits
   .CONST $GPU_DAG3_WINDOW_FILLCONST           0xFFFF27; // RW  24 bits
   .CONST $GPU_DAG3_CONTROL5                   0xFFFF28; // RW  24 bits
   .CONST $GPU_DAG4_BUFFER_ADDRESS             0xFFFF29; // RW  24 bits
   .CONST $GPU_DAG4_CONTROL1                   0xFFFF2A; // RW  24 bits
   .CONST $GPU_DAG4_CONTROL2                   0xFFFF2B; // RW  24 bits
   .CONST $GPU_DAG4_CONTROL3                   0xFFFF2C; // RW  19 bits
   .CONST $GPU_DAG4_CONTROL4                   0xFFFF2D; // RW  11 bits
   .CONST $GPU_DAG4_WINDOW_START               0xFFFF2E; // RW  24 bits
   .CONST $GPU_DAG4_WINDOW_STOP                0xFFFF2F; // RW  24 bits
   .CONST $GPU_DAG4_WINDOW_FILLCONST           0xFFFF30; // RW  24 bits
   .CONST $GPU_DAG4_CONTROL5                   0xFFFF31; // RW  24 bits
   .CONST $GPU_DAG5_BUFFER_ADDRESS             0xFFFF32; // RW  24 bits
   .CONST $GPU_DAG5_CONTROL1                   0xFFFF33; // RW  24 bits
   .CONST $GPU_DAG5_CONTROL2                   0xFFFF34; // RW  24 bits
   .CONST $GPU_DAG5_CONTROL3                   0xFFFF35; // RW  19 bits
   .CONST $GPU_DAG5_CONTROL4                   0xFFFF36; // RW  11 bits
   .CONST $GPU_DAG5_WINDOW_START               0xFFFF37; // RW  24 bits
   .CONST $GPU_DAG5_WINDOW_STOP                0xFFFF38; // RW  24 bits
   .CONST $GPU_DAG5_WINDOW_FILLCONST           0xFFFF39; // RW  24 bits
   .CONST $GPU_DAG5_CONTROL5                   0xFFFF3A; // RW  24 bits
   .CONST $GPU_PRN1_CONTROL1                   0xFFFF3B; // RW  14 bits
   .CONST $GPU_PRN1_CONTROL2                   0xFFFF3C; // RW  16 bits
   .CONST $GPU_EXP1_CONTROL1                   0xFFFF3D; // RW   9 bits
   .CONST $GPU_EXP1_PHASE_STEP                 0xFFFF3E; // RW  21 bits
   .CONST $GPU_EXP1_INITIAL_PHASE              0xFFFF3F; // RW  21 bits
   .CONST $GPU_EXP2_CONTROL1                   0xFFFF40; // RW   9 bits
   .CONST $GPU_EXP2_PHASE_STEP                 0xFFFF41; // RW  21 bits
   .CONST $GPU_EXP2_INITIAL_PHASE              0xFFFF42; // RW  21 bits
   .CONST $GPU_ABS1_CONTROL1                   0xFFFF43; // RW  11 bits
   .CONST $GPU_ABS1_CONTROL2                   0xFFFF44; // RW  16 bits
   .CONST $GPU_ABS2_CONTROL1                   0xFFFF45; // RW  11 bits
   .CONST $GPU_ABS2_CONTROL2                   0xFFFF46; // RW  16 bits
   .CONST $GPU_MULT1_CONTROL                   0xFFFF47; // RW   9 bits
   .CONST $GPU_MULT2_CONTROL                   0xFFFF48; // RW   9 bits
   .CONST $GPU_ALU1_ICONTROL                   0xFFFF49; // RW  24 bits
   .CONST $GPU_ALU1_QCONTROL                   0xFFFF4A; // RW  24 bits
   .CONST $GPU_ALU1_ITHRESH_HI                 0xFFFF4B; // RW  24 bits
   .CONST $GPU_ALU1_ITHRESH_LO                 0xFFFF4C; // RW  24 bits
   .CONST $GPU_ALU1_QTHRESH_HI                 0xFFFF4D; // RW  24 bits
   .CONST $GPU_ALU1_QTHRESH_LO                 0xFFFF4E; // RW  24 bits
   .CONST $GPU_ALU2_ICONTROL                   0xFFFF4F; // RW  24 bits
   .CONST $GPU_ALU2_QCONTROL                   0xFFFF50; // RW  24 bits
   .CONST $GPU_ALU2_ITHRESH_HI                 0xFFFF51; // RW  24 bits
   .CONST $GPU_ALU2_ITHRESH_LO                 0xFFFF52; // RW  24 bits
   .CONST $GPU_ALU2_QTHRESH_HI                 0xFFFF53; // RW  24 bits
   .CONST $GPU_ALU2_QTHRESH_LO                 0xFFFF54; // RW  24 bits
   .CONST $GPU_FFT_CONTROL                     0xFFFF55; // RW  12 bits
   .CONST $GPU_QUADFOLDING_PHASE_STEP          0xFFFF56; // RW  21 bits
   .CONST $GPU_QUADFOLDING_VECTORPHASE_STEP    0xFFFF57; // RW  21 bits
   .CONST $GPU_QUADFOLDING_INITIAL_PHASE       0xFFFF58; // RW  21 bits
   .CONST $GPU_QUADFOLDING_CONTROL             0xFFFF59; // RW  15 bits
   .CONST $GPU_DAG_START                       0xFFFF5A; // RW   1 bits
   .CONST $GPU_DAG_STOP                        0xFFFF5B; // RW   1 bits
   .CONST $GPU_ENABLES                         0xFFFF5C; // RW   5 bits
   .CONST $GPU_VIM_TEMPLATE_START_ADDR         0xFFFF5D; // RW  24 bits
   .CONST $GPU_VIM_CONTROL                     0xFFFF5E; // RW  14 bits
   .CONST $GPU_DEBUG_MUX_SEL                   0xFFFF5F; // RW   3 bits
   .CONST $GPU_DEBUG                           0xFFFF60; //  R  24 bits
   .CONST $GPU_CORR_TIMER_RST                  0xFFFF61; // RW   0 bits
   .CONST $GPU_CORR_CFG_1OF2                   0xFFFF62; // RW  13 bits
   .CONST $GPU_CORR_CFG_2OF2                   0xFFFF63; // RW  23 bits
   .CONST $GPU_CORR_CCS_BUFF_START_ADDR        0xFFFF64; // RW  24 bits
   .CONST $GPU_CORR_DAG_WIN_START              0xFFFF65; // RW  24 bits
   .CONST $GPU_CORR_DAG_WIN_STOP               0xFFFF66; // RW  24 bits
   .CONST $GPU_CORR_DAG_INV_WIN_MODE_EN        0xFFFF67; // RW   1 bits
   .CONST $GPU_CORR_SLEEP_MODE                 0xFFFF68; // RW   1 bits
   .CONST $GPU_CORR_SW_ACCESS_FLAG             0xFFFF69; // RW   1 bits
   .CONST $GPU_CORR_START                      0xFFFF6A; // RW   0 bits
   .CONST $GPU_CORR_SW_OVERRUN_FLAG            0xFFFF6B; //  R   1 bits
   .CONST $GPU_CORR_CCS_CNTR                   0xFFFF6C; //  R   7 bits
   .CONST $GPU_CORR_ACC_OVERFLOW               0xFFFF6D; //  R   1 bits
   .CONST $GPU_BUSY                            0xFFFF6E; //  R   8 bits
   .CONST $GPU_DAG0_PEAK_FINAL_ADDRESS1        0xFFFF6F; //  R  24 bits
   .CONST $GPU_DAG0_PEAK_FINAL_ADDRESS2        0xFFFF70; //  R  23 bits
   .CONST $GPU_DAG0_PEAK_VALUE                 0xFFFF71; //  R  24 bits
   .CONST $GPU_DAG1_PEAK_FINAL_ADDRESS1        0xFFFF72; //  R  24 bits
   .CONST $GPU_DAG1_PEAK_FINAL_ADDRESS2        0xFFFF73; //  R  23 bits
   .CONST $GPU_DAG1_PEAK_VALUE                 0xFFFF74; //  R  24 bits
   .CONST $GPU_DAG2_PEAK_FINAL_ADDRESS1        0xFFFF75; //  R  24 bits
   .CONST $GPU_DAG2_PEAK_FINAL_ADDRESS2        0xFFFF76; //  R  23 bits
   .CONST $GPU_DAG2_PEAK_VALUE                 0xFFFF77; //  R  24 bits
   .CONST $GPU_DAG3_PEAK_FINAL_ADDRESS1        0xFFFF78; //  R  24 bits
   .CONST $GPU_DAG3_PEAK_FINAL_ADDRESS2        0xFFFF79; //  R  23 bits
   .CONST $GPU_DAG3_PEAK_VALUE                 0xFFFF7A; //  R  24 bits
   .CONST $GPU_DAG4_PEAK_FINAL_ADDRESS1        0xFFFF7B; //  R  24 bits
   .CONST $GPU_DAG4_PEAK_FINAL_ADDRESS2        0xFFFF7C; //  R  23 bits
   .CONST $GPU_DAG4_PEAK_VALUE                 0xFFFF7D; //  R  24 bits
   .CONST $GPU_DAG5_PEAK_FINAL_ADDRESS1        0xFFFF7E; //  R  24 bits
   .CONST $GPU_DAG5_PEAK_FINAL_ADDRESS2        0xFFFF7F; //  R  23 bits
   .CONST $GPU_DAG5_PEAK_VALUE                 0xFFFF80; //  R  24 bits
   .CONST $GPU_ABS1_ACCUM                      0xFFFF81; //  R  24 bits
   .CONST $GPU_ABS2_ACCUM                      0xFFFF82; //  R  24 bits
   .CONST $GPU_FFT_STATUS                      0xFFFF83; //  R  12 bits
   .CONST $GPU_VERSION                         0xFFFF84; //  R  16 bits
   .CONST $GPU_INT_CLEAR                       0xFFFF85; //  W  10 bits
   .CONST $GPU_INT_CAUSE                       0xFFFF86; //  R  10 bits
   .CONST $GPU_INT_MASK                        0xFFFF87; // RW  10 bits
   .CONST $GPS_SSP_VERSION                     0xFFFF88; //  R  16 bits
   .CONST $GPS_SSP_DC_REMOVAL_CFG              0xFFFF89; // RW  24 bits
   .CONST $GPS_SSP_ACCUM_I                     0xFFFF8A; //  R  24 bits
   .CONST $GPS_SSP_ACCUM_Q                     0xFFFF8B; //  R  24 bits
   .CONST $GPS_SSP_RSSI                        0xFFFF8C; //  R   8 bits
   .CONST $GPS_SSP_IBS_THRESH                  0xFFFF8D; // RW  16 bits
   .CONST $GPS_SSP_PHASE_COMP_CFG              0xFFFF8E; // RW  16 bits
   .CONST $GPS_SSP_DATA_GAIN_SHIFT             0xFFFF8F; // RW   4 bits
   .CONST $GPS_SSP_SHARED_FIR_COEFFS           0xFFFF90; // RW  60 bits
   .CONST $GPS_SSP_SHARED_FIR_ACC_SHIFT        0xFFFF93; // RW   2 bits
   .CONST $GPS_SSP_TONCAN_AGC_SET              0xFFFF94; // RW   9 bits
   .CONST $GPS_SSP_TONCAN_CFG_1                0xFFFF95; // RW  18 bits
   .CONST $GPS_SSP_TONCAN_AGC_1                0xFFFF96; // RW  12 bits
   .CONST $GPS_SSP_TONCAN_FREQ_1               0xFFFF97; // RW  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_LO_HI_1         0xFFFF98; // RW  16 bits
   .CONST $GPS_SSP_TONCAN_CFG_2                0xFFFF99; // RW  18 bits
   .CONST $GPS_SSP_TONCAN_AGC_2                0xFFFF9A; // RW  12 bits
   .CONST $GPS_SSP_TONCAN_FREQ_2               0xFFFF9B; // RW  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_LO_HI_2         0xFFFF9C; // RW  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_1               0xFFFF9D; //  R  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_FREQ_1          0xFFFF9E; //  R  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_PHASE_1         0xFFFF9F; //  R  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_MAG_1           0xFFFFA0; //  R  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_PRES_1          0xFFFFA1; //  R  12 bits
   .CONST $GPS_SSP_TONCAN_TONE_2               0xFFFFA2; //  R  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_FREQ_2          0xFFFFA3; //  R  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_PHASE_2         0xFFFFA4; //  R  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_MAG_2           0xFFFFA5; //  R  16 bits
   .CONST $GPS_SSP_TONCAN_TONE_PRES_2          0xFFFFA6; //  R  12 bits
   .CONST $GPS_SSP_MIXER_CFG_A                 0xFFFFA7; // RW  18 bits
   .CONST $GPS_SSP_IIR_1_FILTER_COEFFS_A       0xFFFFA8; // RW  40 bits
   .CONST $GPS_SSP_IIR_2_FILTER_COEFFS_A       0xFFFFAA; // RW  40 bits
   .CONST $GPS_SSP_IIR_FILTER_CFG_A            0xFFFFAC; // RW  16 bits
   .CONST $GPS_SSP_FIR_FILTER_COEFFS_A         0xFFFFAD; // RW  60 bits
   .CONST $GPS_SSP_FIR_ACC_SHIFT_A             0xFFFFB0; // RW   2 bits
   .CONST $GPS_SSP_QUANT_THRESH_WR_A           0xFFFFB1; // RW  11 bits
   .CONST $GPS_SSP_QUANT_THRESH_RD_A           0xFFFFB2; //  R  11 bits
   .CONST $GPS_SSP_QUANT_ADAPT_A               0xFFFFB3; // RW  20 bits
   .CONST $GPS_SSP_QUANT_CFG_A                 0xFFFFB4; // RW  24 bits
   .CONST $GPS_SSP_DMA_CFG_A                   0xFFFFB5; // RW  18 bits
   .CONST $GPS_SSP_DMA_START_ADDR1_A           0xFFFFB6; // RW  24 bits
   .CONST $GPS_SSP_DMA_START_ADDR2_A           0xFFFFB7; // RW  24 bits
   .CONST $GPS_SSP_DMA_COUNT_A                 0xFFFFB8; //  R  17 bits
   .CONST $GPS_SSP_MIXER_CFG_B                 0xFFFFB9; // RW  18 bits
   .CONST $GPS_SSP_IIR_1_FILTER_COEFFS_B       0xFFFFBA; // RW  40 bits
   .CONST $GPS_SSP_IIR_2_FILTER_COEFFS_B       0xFFFFBC; // RW  40 bits
   .CONST $GPS_SSP_IIR_FILTER_CFG_B            0xFFFFBE; // RW  16 bits
   .CONST $GPS_SSP_FIR_FILTER_COEFFS_B         0xFFFFBF; // RW  60 bits
   .CONST $GPS_SSP_FIR_ACC_SHIFT_B             0xFFFFC2; // RW   2 bits
   .CONST $GPS_SSP_QUANT_THRESH_WR_B           0xFFFFC3; // RW  11 bits
   .CONST $GPS_SSP_QUANT_THRESH_RD_B           0xFFFFC4; //  R  11 bits
   .CONST $GPS_SSP_QUANT_ADAPT_B               0xFFFFC5; // RW  20 bits
   .CONST $GPS_SSP_QUANT_CFG_B                 0xFFFFC6; // RW  24 bits
   .CONST $GPS_SSP_DMA_CFG_B                   0xFFFFC7; // RW  18 bits
   .CONST $GPS_SSP_DMA_START_ADDR1_B           0xFFFFC8; // RW  24 bits
   .CONST $GPS_SSP_DMA_START_ADDR2_B           0xFFFFC9; // RW  24 bits
   .CONST $GPS_SSP_DMA_COUNT_B                 0xFFFFCA; //  R  17 bits
   .CONST $GPS_SSP_MIXER_CFG_C                 0xFFFFCB; // RW  18 bits
   .CONST $GPS_SSP_IIR_1_FILTER_COEFFS_C       0xFFFFCC; // RW  40 bits
   .CONST $GPS_SSP_IIR_2_FILTER_COEFFS_C       0xFFFFCE; // RW  40 bits
   .CONST $GPS_SSP_IIR_FILTER_CFG_C            0xFFFFD0; // RW  16 bits
   .CONST $GPS_SSP_FIR_FILTER_COEFFS_C         0xFFFFD1; // RW  60 bits
   .CONST $GPS_SSP_FIR_ACC_SHIFT_C             0xFFFFD4; // RW   2 bits
   .CONST $GPS_SSP_QUANT_THRESH_WR_C           0xFFFFD5; // RW  11 bits
   .CONST $GPS_SSP_QUANT_THRESH_RD_C           0xFFFFD6; //  R  11 bits
   .CONST $GPS_SSP_QUANT_ADAPT_C               0xFFFFD7; // RW  20 bits
   .CONST $GPS_SSP_QUANT_CFG_C                 0xFFFFD8; // RW  24 bits
   .CONST $GPS_SSP_DMA_CFG_C                   0xFFFFD9; // RW  18 bits
   .CONST $GPS_SSP_DMA_START_ADDR1_C           0xFFFFDA; // RW  24 bits
   .CONST $GPS_SSP_DMA_START_ADDR2_C           0xFFFFDB; // RW  24 bits
   .CONST $GPS_SSP_DMA_COUNT_C                 0xFFFFDC; //  R  17 bits
   .CONST $GPS_SSP_TRACK_TOGGLE                0xFFFFDD; // RW  14 bits
   .CONST $GPS_SSP_BLANK_CTRL                  0xFFFFDE; // RW   9 bits
   .CONST $GPS_SSP_BLANK_TIME_HI               0xFFFFDF; //  R  24 bits
   .CONST $GPS_SSP_BLANK_TIME_LO               0xFFFFE0; //  R  24 bits
   .CONST $GPS_SSP_BLANK_SIGNAL                0xFFFFE1; //  R   8 bits
   .CONST $GPS_SSP_MEM_PROC_FINISHED           0xFFFFE2; // RW   3 bits
   .CONST $GPS_SSP_CFG                         0xFFFFE3; // RW  13 bits
   .CONST $GPS_SSP_CLK_RESET                   0xFFFFE4; // RW  18 bits
   .CONST $GPS_SSP_BLOCK_ENABLES               0xFFFFE5; // RW  17 bits
   .CONST $GPS_SSP_BT_EVENT_TIME               0xFFFFE6; // RW  24 bits
   .CONST $GPS_SSP_BT_EVENT_EN_MASK            0xFFFFE7; // RW  12 bits
   .CONST $GPS_SSP_SC_EVENT_TIME1              0xFFFFE8; // RW  24 bits
   .CONST $GPS_SSP_SC_EVENT_EN_MASK1           0xFFFFE9; // RW  12 bits
   .CONST $GPS_SSP_SC_EVENT_TIME2              0xFFFFEA; // RW  24 bits
   .CONST $GPS_SSP_SC_EVENT_EN_MASK2           0xFFFFEB; // RW  12 bits
   .CONST $GPS_SSP_SAMP_CNT_VALUE              0xFFFFEC; //  R  24 bits
   .CONST $GPS_SSP_SAMP_CNT_RESET_TIME         0xFFFFED; // RW  24 bits
   .CONST $GPS_SSP_EVENT_LATENCIES_A           0xFFFFEE; // RW  24 bits
   .CONST $GPS_SSP_EVENT_LATENCIES_B           0xFFFFEF; // RW  24 bits
   .CONST $GPS_SSP_EVENT_LATENCIES_C           0xFFFFF0; // RW  24 bits
   .CONST $GPS_SSP_INT_NUM_OUT_SAMPS_A         0xFFFFF1; // RW  24 bits
   .CONST $GPS_SSP_INT_IN_OUT_DIFF_A           0xFFFFF2; // RW  24 bits
   .CONST $GPS_SSP_INT_ACCUM_INIT_A            0xFFFFF3; // RW  24 bits
   .CONST $GPS_SSP_INT_SHIFTS_A                0xFFFFF4; // RW  13 bits
   .CONST $GPS_SSP_INT_INIT_A                  0xFFFFF5; // RW   1 bits
   .CONST $GPS_SSP_INT_NUM_OUT_SAMPS_B         0xFFFFF6; // RW  24 bits
   .CONST $GPS_SSP_INT_IN_OUT_DIFF_B           0xFFFFF7; // RW  24 bits
   .CONST $GPS_SSP_INT_ACCUM_INIT_B            0xFFFFF8; // RW  24 bits
   .CONST $GPS_SSP_INT_SHIFTS_B                0xFFFFF9; // RW  13 bits
   .CONST $GPS_SSP_INT_INIT_B                  0xFFFFFA; // RW   1 bits
   .CONST $GPS_SSP_INT_NUM_OUT_SAMPS_C         0xFFFFFB; // RW  24 bits
   .CONST $GPS_SSP_INT_IN_OUT_DIFF_C           0xFFFFFC; // RW  24 bits
   .CONST $GPS_SSP_INT_ACCUM_INIT_C            0xFFFFFD; // RW  24 bits
   .CONST $GPS_SSP_INT_SHIFTS_C                0xFFFFFE; // RW  13 bits
   .CONST $GPS_SSP_INT_INIT_C                  0xFFFFFF; // RW   1 bits

#endif
