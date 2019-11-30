// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


#ifndef CBOPS_SWITCH_HEADER_INCLUDED
#define CBOPS_SWITCH_HEADER_INCLUDED

    .CONST $cbops.switch_op.SWITCH_ADDR_FIELD               0;  // Points at switch variable (one bit represents the switch)
    .CONST $cbops.switch_op.ALT_NEXT_FIELD                  1;  // Alternative next operator (selected whe switch is off)
    .CONST $cbops.switch_op.SWITCH_MASK_FIELD               2;  // Switch bit mask (indicates which bit is used for the switch)
    .CONST $cbops.switch_op.INVERT_CONTROL_FIELD            3;  // Invert the switch control sense (inverts if non-zero)
    .CONST $cbops.switch_op.STRUC_SIZE                      4;

    .CONST $cbops.switch_op.OFF                             0;  // Code uses zero value to represent "OFF"
    .CONST $cbops.switch_op.ON                              1;  // Code uses any non-zero value to represent "ON"

    .CONST $cbops.switch_op.INVERT_CONTROL                  1;  // Invert the control sense

#endif // CBOPS_SWITCH_HEADER_INCLUDED
