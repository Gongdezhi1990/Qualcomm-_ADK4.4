// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


#ifndef STACK_HEADER_INCLUDED
#define STACK_HEADER_INCLUDED

// *****************************************************************************
// MODULE:
//    $stack.push_rLink_macro
//
// DESCRIPTION:
//    Macro to push rLink onto the stack
//
// INPUTS:
//    - rLink = data to be pushed onto the stack
//    - r9 = the current stack pointer
//
// OUTPUTS:
//    - r9 = the updated stack pointer
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************

#define $push_rLink_macro                       \
         push rLink






// *****************************************************************************
// MODULE:
//    $stack.pop_rLink_macro
//
// DESCRIPTION:
//    Macro to pop rLink from the stack
//
// INPUTS:
//    - r9 = the current stack pointer
//
// OUTPUTS:
//    - r9 = the updated stack pointer
//    - rLink = data popped off the stack
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************

#define $pop_rLink_macro                        \
         pop rLink





// *****************************************************************************
// MODULE:
//    $stack.pop_rLink_and_rts_macro
//
// DESCRIPTION:
//    Macro to pop rLink from the stack and rts
//
// INPUTS:
//    - r9 = the current stack pointer
//
// OUTPUTS:
//    - r9 = the updated stack pointer
//    - rLink = data popped off the stack
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************

#define $pop_rLink_and_rts_macro                   \
         pop rLink;                                \
         rts





// *****************************************************************************
// MODULE:
//    $stack.push_r0_macro
//
// DESCRIPTION:
//    Macro to push r0 onto the stack
//
// INPUTS:
//    - r0 = data to be pushed onto the stack
//    - r9 = the current stack pointer
//
// OUTPUTS:
//    - r9 = the updated stack pointer
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************

#define $push_r0_macro                          \
         push r0





// *****************************************************************************
// MODULE:
//    $stack.pop_r0_macro
//
// DESCRIPTION:
//    Macro to pop r0 from the stack
//
// INPUTS:
//    r9 = the current stack pointer
//
// OUTPUTS:
//    r9 = the updated stack pointer
//    r0 = data popped off the stack
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************

#define $pop_r0_macro                           \
      pop r0

// *****************************************************************************
//    Push all registers used by kcc to the stack.
// *****************************************************************************
#define $kcc_regs_save_macro \
    pushm <r4, r5, r6, r7, r8, r9, rMACB>; \
    pushm <I0, I1, I2, I4, I5, I6, M0, M1, M2, M3>

// *****************************************************************************
//    Pop all registers used by kcc off the stack.
// *****************************************************************************
#define $kcc_regs_restore_macro \
    popm <I0, I1, I2, I4, I5, I6, M0, M1, M2, M3>;\
    popm <r4, r5, r6, r7, r8, r9, rMACB>

// *****************************************************************************
// DESCRIPTION:
//    Call a c function that returns an int
//
// INPUTS:
//    - r0,r1,r2,r3 (optional)
//
// OUTPUTS:
//    - r0
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************
#define $call_c_with_int_return_macro(CFUNC) \
    push &$_ ## CFUNC;                       \
    call $call_c_with_int_return;            \
    pop Null

// *****************************************************************************
// DESCRIPTION:
//    Call a c function that returns void
//
// INPUTS:
//    - r0,r1,r2,r3 (optional)
//
// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************
#define $call_c_with_void_return_macro(CFUNC) \
    push &$_ ## CFUNC;                        \
    call $call_c_with_void_return;            \
    pop Null

#endif // STACK_HEADER_INCLUDED
