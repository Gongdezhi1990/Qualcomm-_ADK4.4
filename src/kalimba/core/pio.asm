// *****************************************************************************
// Copyright (c) 2006 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


// *****************************************************************************
// NAME:
//   PIO library
//
// DESCRIPTION:
//   Both the PIOs and the AIOs inputs can trigger interrupts (NB: the AIOs are
//   used as digital-input). This library contains functions to register user
//   defined interrupt event handlers. This library also contains some simple
//   kcc compliant functions to manipulate PIOs.
//
//   All the PIOs/AIOs to be used as the interrupt sources need to be configured
//   appropriately (e.g. direction, drive-enable, pull-up/down), prior to register
//   an interrupt event handler.
//
//   Interrupt event handlers can be registered with multiple PIOs and AIOs to
//   monitor. When an interrupt event handler is called, all the changes on the
//   registered PIOs and AIOs are notified as 3 24-bit word bitmask parameters
//   by setting the relevant bits to "1".
//
//   The library uses structures to hold the information it requires for each
//   request. Each structure should be of size $pio.STRUC_SIZE and contains the
//   following fields:
// @verbatim
//     Name                          Index
//     $pio.NEXT_ADDR_FIELD            0
//     $pio.PIO_BITMASK_FIELD          1
//     $pio.PIO2_BITMASK_FIELD         2
//     $pio.PIO3_BITMASK_FIELD         3
//     $pio.HANDLER_ADDR_FIELD         4
// @endverbatim
//
// *****************************************************************************

#ifndef PIO_INCLUDED
#define PIO_INCLUDED

#include "pio.h"
#include "stack.h"
#include "interrupt.h"

.MODULE $pio;
   .DATASEGMENT DM;

   .VAR last_addr = $pio.LAST_ENTRY;
   .VAR prev_pio_state;
   .VAR prev_pio2_state;
#ifdef VULTAN
   .VAR prev_pio3_state;
#endif

   #ifdef PIO_DEBUG_ON
      .VAR debug_count;
   #endif

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $pio.initialise
//
// DESCRIPTION:
//    Initialises the monitoring of PIOs.
//
//  INPUTS:
//    - none
//
//  OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r1, r2, r3
//
// *****************************************************************************
.MODULE $M.pio.initialise;
   .CODESEGMENT PIO_INITIALISE_PM;

   $pio.initialise:

   // push rLink onto stack
   $push_rLink_macro;

   // save previous PIO state for the very first time
   r0 = M[$PIO_IN];
   M[$pio.prev_pio_state] = r0;
   r0 = M[$PIO2_IN];
   M[$pio.prev_pio2_state] = r0;
#ifdef VULTAN
   r0 = M[$PIO3_IN];
   M[$pio.prev_pio3_state] = r0;
#endif

   // set up handler for pio interrupts (priority 2)
   r0 = $INT_SOURCE_PIO_EVENT;
   r1 = 2;
   r2 = &$pio.event_service_routine;
   #ifdef OPTIONAL_FAST_INTERRUPT_SUPPORT
      call $interrupt.register_fast;
   #else
      call $interrupt.register;
   #endif

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $pio.register_handler
//
// DESCRIPTION:
//    Registers a PIO event handler.
//
//  INPUTS
//    - r0 = pointer to a structure that stores the pio handler structure,
//           should be of length $pio.STRUC_SIZE
//    - r1 = bitmask of PIOs to monitor (PIO_IN register:  PIO[23:0])
//    - r2 = bitmask of PIOs to monitor (PIO2_IN register: AIO[15:0] PIO[31:24])
//    - r3 = bitmask of PIOs to monitor (PIO3_IN register: AIO[31:16])
//    - r4 = address of PIO event handler for this PIO
//
//  OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0-4
//
// *****************************************************************************
.MODULE $M.pio.register_handler;
   .CODESEGMENT PIO_REGISTER_HANDLER_PM;

   $pio.register_handler:

   // store new entry's bitmaskand handler address in this structre
   M[r0 + $pio.PIO_BITMASK_FIELD]  = r1;
   M[r0 + $pio.PIO2_BITMASK_FIELD] = r2;
#ifdef VULTAN
   M[r0 + $pio.PIO3_BITMASK_FIELD] = r3;
#endif
   M[r0 + $pio.HANDLER_ADDR_FIELD] = r4;

   // set the next address field of this structure to the previous last_addr
   r4 = M[$pio.last_addr];
   M[r0 + $pio.NEXT_ADDR_FIELD] = r4;
   // set new last_addr to the address of this structure
   M[$pio.last_addr] = r0;

   // adjust the PIO event register to detect changes on these PIOs
   r0 = M[$PIO_EVENT_EN_MASK];
   r0 = r0 OR r1;
   M[$PIO_EVENT_EN_MASK] = r0;

   r0 = M[$PIO2_EVENT_EN_MASK];
   r0 = r0 OR r2;
   M[$PIO2_EVENT_EN_MASK] = r0;

#ifdef VULTAN
   r0 = M[$PIO3_EVENT_EN_MASK];
   r0 = r0 OR r3;
   M[$PIO3_EVENT_EN_MASK] = r0;
#endif

   rts;

.ENDMODULE;








// *****************************************************************************
// MODULE:
//    $pio.event_service_routine
//
// DESCRIPTION:
//    Process a PIO interrupt event by calling the appropriate handler functions
// that have been configured to monitor the PIOs that have changed.
//
//  INPUTS:
//    - none
//
//  OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    Assume everything
//
// NOTES:
//    The Handler is passed:
//       - r0 = address of the PIO handler struc
//       - r1 = PIOs that have changed
//       - r2 = PIOs that have changed
//       - r3 = PIOs that have changed
//
//    In all cases:
//       The handler function is allowed to trash r0, r1, r2, r3 and r4.
//
//    If OPTIONAL_FAST_INTERRUPT_SUPPORT is defined (in interrupt.h):
//       All other registers must be saved and restored if used.
//
//    If OPTIONAL_FAST_INTERRUPT_SUPPORT is NOT defined (in interrupt.h):
//       All other registers can be trashed as required.
//
// *****************************************************************************
.MODULE $M.pio.event_service_routine;
   .CODESEGMENT PIO_EVENT_SERVICE_ROUTINE_PM;

   $pio.event_service_routine:

   // push rLink onto stack
   $push_rLink_macro;

   // detect which PIOs have changed
   r1 = M[$PIO_IN];
   r2 = M[$PIO2_IN];
#ifdef VULTAN
   r3 = M[$PIO3_IN];
#endif

   r0 = M[$pio.prev_pio_state];
   M[$pio.prev_pio_state] = r1;
   r1 = r0 XOR r1;

   r0 = M[$pio.prev_pio2_state];
   M[$pio.prev_pio2_state] = r2;
   r2 = r0 XOR r2;

#ifdef VULTAN
   r0 = M[$pio.prev_pio3_state];
   M[$pio.prev_pio3_state] = r3;
   r3 = r0 XOR r3;
#endif

   // ** work out which handler functions to call **
   r0 = M[$pio.last_addr];

   #ifdef PIO_DEBUG_ON
      r4 = $pio.MAX_HANDLERS;
      M[$pio.debug_count] = r4;
   #endif

   #ifdef BUILD_WITH_C_SUPPORT
      M0 = 0;
      M1 = 1;
      M2 = -1;
   #endif

   find_structure_loop:
      // see if we're at the end of the linked list
      Null = r0 - $pio.LAST_ENTRY;
      if Z jump $pop_rLink_and_rts;

      #ifdef PIO_DEBUG_ON
         // have we been round too many times
         r4 = M[$pio.debug_count];
         r4 = r4 - 1;
         if NEG call $error;
         M[$pio.debug_count] = r4;
      #endif

      pushm <r0, r1, r2, r3>;

      // Mask off the bits which the event handler is not interested in
      r4 = M[r0 + $pio.PIO_BITMASK_FIELD];
      r1 = r4 AND r1;
      r4 = M[r0 + $pio.PIO2_BITMASK_FIELD];
      r2 = r4 AND r2;
#ifdef VULTAN
      r4 = M[r0 + $pio.PIO3_BITMASK_FIELD];
      r3 = r4 AND r3;
#endif

      r4 = r1 OR r2;
      r4 = r4 OR r3;
      if Z jump next_linked_list;
         r4 = M[r0 + $pio.HANDLER_ADDR_FIELD];
         call r4;
      next_linked_list:
      popm <r0, r1, r2, r3>;

      r0 = M[r0 + $pio.NEXT_ADDR_FIELD];
   jump find_structure_loop;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $pio.set_bit, $pio.clear_bit, $pio.toggle_bit,
//    $pio.set_dir_output_bit, $pio.set_dir_input_bit
//
// DESCRIPTION:
//    Set/clear/toggle a PIO bit.
//    Set a bit as an output/input
//
//  INPUTS:
//    - r0 the bit to modify
//
// TRASHED REGISTERS:
//    r0, r1
//
// *****************************************************************************
.MODULE $M.pio.set_bit;
   .CODESEGMENT PM;
$_pio_set_bit:
    r0 = 1 LSHIFT r0;
    r1 = M[$PIO_OUT];
    r0 = r0 OR r1;
    M[$PIO_OUT] = r0;
    rts;
.ENDMODULE;

.MODULE $M.pio.clear_bit;
   .CODESEGMENT PM;
$_pio_clear_bit:
    r0 = 1 LSHIFT r0;
    r0 = r0 XOR -1;
    r1 = M[$PIO_OUT];
    r0 = r0 AND r1;
    M[$PIO_OUT] = r0;
    rts;
.ENDMODULE;

.MODULE $M.pio.toggle_bit;
    .CODESEGMENT PM;
$_pio_toggle_bit:
    r0 = 1 LSHIFT r0;
    r1 = M[$PIO_OUT];
    r0 = r0 XOR r1;
    M[$PIO_OUT] = r0;
    rts;
.ENDMODULE;

.MODULE $M.pio.set_dir_output_bit;
    .CODESEGMENT PM;
$_pio_set_dir_output_bit:
    r0 = 1 LSHIFT r0;
    r1 = M[$PIO_DIR];
    r0 = r0 OR r1;
    M[$PIO_DIR] = r0;
    rts;
.ENDMODULE;

.MODULE $M.pio.set_dir_input_bit;
   .CODESEGMENT PM;
$_pio_set_dir_input_bit:
    r0 = 1 LSHIFT r0;
    r0 = r0 XOR -1;
    r1 = M[$PIO_DIR];
    r0 = r0 AND r1;
    M[$PIO_DIR] = r0;
    rts;
.ENDMODULE;

#endif
