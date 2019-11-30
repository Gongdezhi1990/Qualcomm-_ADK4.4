// *****************************************************************************
// Copyright (c) 2010 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


#ifndef CBOPS_SOFT_MUTE_HEADER_INCLUDED
#define CBOPS_SOFT_MUTE_HEADER_INCLUDED

    // Operator structure definition
   
    .const  $cbops.soft_mute_op.STRUC_SIZE_MONO                     5;
    .const  $cbops.soft_mute_op.STRUC_SIZE_STEREO                   7;

    .const  $cbops.soft_mute_op.MUTE_DIRECTION                      0;
    .const  $cbops.soft_mute_op.MUTE_INDEX                          1;
    .const  $cbops.soft_mute_op.NUM_CHANNELS                        2;
    .const  $cbops.soft_mute_op.INPUT_1_START_INDEX_FIELD           3;
    .const  $cbops.soft_mute_op.OUTPUT_1_START_INDEX_FIELD          4;
    .const  $cbops.soft_mute_op.INPUT_2_START_INDEX_FIELD           5;
    .const  $cbops.soft_mute_op.OUTPUT_2_START_INDEX_FIELD          6;
    
#endif // CBOPS_SOFT_MUTE_HEADER_INCLUDED
