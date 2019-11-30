// *****************************************************************************
// Copyright (c) 2007 - 2015 Qualcomm Technologies International, Ltd.
// %%version
//
// *****************************************************************************


#ifndef CBOPS_HW_WARP_OP_HEADER_INCLUDED
#define CBOPS_HW_WARP_OP_HEADER_INCLUDED
//  which     1 for A, 2 for B, 3 for A&B   0: none
//  bits 3:0 = ADC which ports
//  bits 7:4 = DAC which ports
.CONST $cbops.hw_warp_op.PORT_OFFSET                0;
.CONST $cbops.hw_warp_op.MONITOR_INDEX_OFFSET       1;
.CONST $cbops.hw_warp_op.WHICH_PORTS_OFFSET         2;
.CONST $cbops.hw_warp_op.TARGET_RATE_OFFSET         3;
.CONST $cbops.hw_warp_op.PERIODS_PER_SECOND_OFFSET  4;
.CONST $cbops.hw_warp_op.COLLECT_SECONDS_OFFSET     5;
.CONST $cbops.hw_warp_op.ENABLE_DITHER_OFFSET       6;

.CONST $cbops.hw_warp_op.ACCUMULATOR_OFFSET         7;
.CONST $cbops.hw_warp_op.PERIOD_COUNTER_OFFSET      8;
.CONST $cbops.hw_warp_op.LAST_WARP_OFFSET           9;

.CONST $cbops.hw_warp_op.STRUC_SIZE                 10;



//  which     1 for A, 2 for B, 3 for A&B   0: none
//  bits 7:0  0xFF   = ADC instances mask
//  bits 15:8 0xFF00 = DAC instances mask
//  bits 5:0  0x3F   = ADC instances mask for instance 0, 1, 2   
//  bits 1:0  0x03   = ADC instance  mask for instance 0   
//  bits 3:2  0x0C   = ADC instance  mask for instance 1   
//  bits 5:4  0x30   = ADC instance  mask for instance 2   
//  bits 7:6  reserved for additional ADC instance 
//  bits 9:8  (0x03 << $cbops.hw_warp_op.PORT_MASK_DAC_START_POS) = DAC instance  0
//  bits 15:10  reserved for additional DAC instance 
  
.CONST $cbops.hw_warp_op.PORT_MASK_ADC_BITMASK   		0xFF;
.CONST $cbops.hw_warp_op.PORT_MASK_ADC_BITMASK_INST012  0x3F;
.CONST $cbops.hw_warp_op.PORT_MASK_DAC_BITMASK          $cbops.hw_warp_op.PORT_MASK_ADC_BITMASK;
.CONST $cbops.hw_warp_op.PORT_MASK_DAC_BITMASK_INST0    0x03;
.CONST $cbops.hw_warp_op.PORT_MASK_DAC_START_POS    	8;


#endif // CBOPS_HW_WARP_OP_HEADER_INCLUDED

