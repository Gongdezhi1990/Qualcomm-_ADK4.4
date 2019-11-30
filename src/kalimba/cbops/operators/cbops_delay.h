//------------------------------------------------------------------------------
// Copyright (c) 2010 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
//------------------------------------------------------------------------------
// 


#ifndef CBOPS_DELAY_HEADER_INCLUDED
#define CBOPS_DELAY_HEADER_INCLUDED

    // Operator structure definition

    .const  $cbops.delay.INPUT_INDEX            0;      // Index to Input Buffer
    .const  $cbops.delay.OUTPUT_INDEX           1;      // Index to Output Buffer
    .const  $cbops.delay.DBUFF_ADDR_FIELD       2;      // Pointer to delay buffer
    .const  $cbops.delay.DBUFF_SIZE_FIELD       3;      // Size of delay buffer, MUST BE CIRCULAR
    .const  $cbops.delay.DELAY_FIELD            4;      // Delay length in samples
   
    .const  $cbops.delay.STRUC_SIZE             5;

    
#endif // CBOPS_DELAY_HEADER_INCLUDED
