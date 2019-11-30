// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// *****************************************************************************
// NAME:
//    Connection Buffer Library
//
// DESCRIPTION:
//    This library provides an API for dealing with buffers in Kalimba memory
//    (which are called cbuffers) and the MMU ports which stream data between
//    the Bluecore subsystem and the Kalimba.
//
//    An interface is of use since the hardware buffers are a fixed size that
//    is often too small to take a 'frame' of codec data.  Also, data jitter
//    is removed through the use of larger software based buffers.
//
//    Once a cbuffer has been initialised, it may be referenced using its
//    buffer structure alone; the size, read and write pointers are all stored
//    and used appropriately.
//
//    This interface is potentially wasteful in memory since data is,
//    effectively, buffered twice but for most real world applications,
//    for example MP3 decoding, codecs produce data in large chunks that
//    would need to be stored in a temporary buffer.
//
//    Libraries may be written that read or write data to/from a cbuffer
//    and hence provide a standard interface.  These cbuffers may then be
//    connected (using a copying function) to a Kalimba port to transfer
//    the data to the Bluecore subsystem.  During this copying operation,
//    operations such as bit width conversion, DC removal, volume
//    adjustment, filtering and equalisation may be performed using the CBOPS
//    library routines.
//
//    For example, a generic codec decoder library may be written which
//    has 1 cbuffer (the compressed input stream) as input and two
//    cbuffers (stereo audio streams) as outputs.  These cbuffers may then
//    be connected (using copying functions) to Kalimba ports, or perhaps
//    through some other library such as an audio equaliser.
//
// *****************************************************************************
#ifndef CBUFFER_INCLUDED
#define CBUFFER_INCLUDED

#include "stack.h"
#include "cbuffer.h"
#include "message.h"
#include "interrupt.h"
#include "kalimba_standard_messages.h"
#include "architecture.h"


#ifdef DALE_ON_GORDON
   #ifdef NON_CONTIGUOUS_PORTS
      #undef NON_CONTIGUOUS_PORTS
   #endif
#endif

#ifdef RICK
#define DUMMY_READ_FOR_24BIT_CLEANUP
#endif

.MODULE $cbuffer;
   .DATASEGMENT DM;

#ifdef DALE_ON_GORDON
   .BLOCK port_buffer_size;
    .VAR      read_port_buffer_size[8];
    .VAR      write_port_buffer_size[8];
   .ENDBLOCK;
   .BLOCK port_offset_addr;
    .VAR      read_port_offset_addr[8];
    .VAR      write_port_offset_addr[8];
   .ENDBLOCK;
   .BLOCK port_limit_addr;
    .VAR      read_port_limit_addr[8];
    .VAR      write_port_limit_addr[8];
   .ENDBLOCK;
#ifdef METADATA_SUPPORT
   .BLOCK port_dmb_cbuffer;
    .VAR      read_port_dmb_cbuffer[8];
    .VAR      write_port_dmb_cbuffer[8];
   .ENDBLOCK;
#endif
#else
   .BLOCK port_buffer_size;
    .VAR      read_port_buffer_size[$cbuffer.NUM_PORTS];
    .VAR      write_port_buffer_size[$cbuffer.NUM_PORTS];
   .ENDBLOCK;
   .BLOCK port_offset_addr;
    .VAR      read_port_offset_addr[$cbuffer.NUM_PORTS];
    .VAR      write_port_offset_addr[$cbuffer.NUM_PORTS];
   .ENDBLOCK;
#ifdef METADATA_SUPPORT
   .BLOCK port_offset_cache;
    .VAR      write_port_offset_cache[$cbuffer.NUM_PORTS];
   .ENDBLOCK;
#endif
   .BLOCK port_limit_addr;
    .VAR      read_port_limit_addr[$cbuffer.NUM_PORTS];
    .VAR      write_port_limit_addr[$cbuffer.NUM_PORTS];
   .ENDBLOCK;
#ifdef METADATA_SUPPORT
   .BLOCK port_dmb_cbuffer;
    .VAR      read_port_dmb_cbuffer[$cbuffer.NUM_PORTS];
    .VAR      write_port_dmb_cbuffer[$cbuffer.NUM_PORTS];
   .ENDBLOCK;
#endif
#endif

#ifdef METADATA_SUPPORT
   .VAR     dmb_read_port;
   .VAR     dmb_write_port;
   .VAR     dmb_write_ports_mask;
#endif
      
   .VAR      write_port_connect_address = 0;
   .VAR      write_port_disconnect_address = 0;
   .VAR      read_port_connect_address = 0;
   .VAR      read_port_disconnect_address = 0;
   .VAR      auto_mcu_message = 1;

   .VAR      configure_port_message_struc[$message.STRUC_SIZE];

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.initialise
//
// DESCRIPTION:
//    Initialise cbuffer library.
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r1, r2, r3
//
// NOTES:
//    Should be called after $message.initialise since it sets up the message
// handler for buffer configuring.
//
// *****************************************************************************
.MODULE $M.cbuffer.initialise;
   .CODESEGMENT CBUFFER_INITIALISE_PM;

   $cbuffer.initialise:

   // push rLink onto stack
   $push_rLink_macro;

   // set up message handers for $MESSAGE_CONFIGURE_PORT message
   r1 = &$cbuffer.configure_port_message_struc;
   r2 = Null OR $MESSAGE_CONFIGURE_PORT;
   r3 = &$cbuffer.configure_port_message_handler;
   call $message.register_handler;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.is_it_enabled
//
// DESCRIPTION:
//    See if a cbuffer/port is enabled/valid
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//
// OUTPUTS:
//    - Z flag set if the port/cbuffer isn't enabled/valid
//    - Z flag cleared if the port/cbuffer is enabled/valid
//
// TRASHED REGISTERS:
//    r0
//
// *****************************************************************************
.MODULE $M.cbuffer.is_it_enabled;
   .CODESEGMENT CBUFFER_IS_IT_ENABLED_PM;

   $cbuffer.is_it_enabled:

   Null = SIGNDET r0;
   // if its NZ its a cbuffer so exit
   if NZ rts;

   // its a port we need to check if its enabled
   r0 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
   Null = M[$cbuffer.port_offset_addr + r0];
   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.get_read_address_and_size
//
// DESCRIPTION:
//    Get a read address and size for a cbuffer/port so that it can read in a
// generic way.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//
// OUTPUTS:
//    - r0 = read address
//    - r1 = buffer size
//
// TRASHED REGISTERS:
//    none
//
// NOTES:
//    If passed a pointer to a cbuffer structure then return the value of the
// current read address and size of the cbuffer.
// If passed a port identifier then return the read address for the port, and
// set the size always to 1.
//
//    After having read a block of data a call must be made to
// $cbuffer.set_read_address to actually update the read pointer
// accordingly. E.g.
//    @verbatim
//       // get the read pointer for $my_cbuffer_struc
//       r0 = $my_cbuffer_struc;
//       call $cbuffer.get_read_address_and_size;
//       I0 = r0;
//       L0 = r1;
//
//       // now read some data from it
//       // NOTE: Should already have checked that there is enough data
//       // in the buffer to be able to read these 10 locations, ie.
//       // using $cbuffer.calc_amount_data.
//       r10 = 10;
//       r5 = 0;
//       do sum_10_samples_loop;
//          r1 = M[I0,1];
//          r5 = r5 + r1;
//       sum_10_samples_loop:
//       ....
//
//       // now update the stored pointers
//       r0 = $my_cbuffer_struc;
//       r1 = I0;
//       call $cbuffer.set_read_address;
//    @endverbatim
//
//
// *****************************************************************************
#ifndef BASE_REGISTER_MODE
.MODULE $M.cbuffer.get_read_address_and_size;
   .CODESEGMENT CBUFFER_GET_READ_ADDRESS_AND_SIZE_PM;

   $cbuffer.get_read_address_and_size:
   $_cbuffer_get_read_address:

   Null = SIGNDET r0;
   if Z jump $cbuffer.get_read_address_and_size.its_a_port;

   its_a_cbuffer:
      r1 = M[r0 + $cbuffer.SIZE_FIELD];
      r0 = M[r0 + $cbuffer.READ_ADDR_FIELD];
      rts;
.ENDMODULE;
#endif
.MODULE $M.cbuffer.get_read_address_and_size.its_a_port;
   .CODESEGMENT CBUFFER_GET_READ_ADDRESS_AND_SIZE_ITS_A_PORT_PM;

   $cbuffer.get_read_address_and_size.its_a_port:

#ifdef DEBUG_ON
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      Null = r1 - $cbuffer.NUM_PORTS;
      // cannot get a read address for a write port so we error
      if POS call $error;
#endif
      // it's a read port
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      // if force flags are set then alter appropriate config bits for the port
      Null = r0 AND ($cbuffer.FORCE_ENDIAN_MASK + $cbuffer.FORCE_SIGN_EXTEND_MASK + $cbuffer.FORCE_BITWIDTH_MASK + $cbuffer.FORCE_PADDING_MASK);

      if Z jump no_forcing;

         // save r2 & r3
         pushm <r2, r3>;

#ifdef NON_CONTIGUOUS_PORTS
         r2 = ($READ_CONFIG_GAP - 1);
         Null = ($cbuffer.TOTAL_CONTINUOUS_PORTS -1) - r1;
         if NEG  r1 = r1 + r2;
#endif

         // read config register
         r3 = M[r1 + $READ_PORT0_CONFIG];

         // adjust config register if 'forced' endian selected
         r2 = r0 AND $cbuffer.FORCE_ENDIAN_MASK;
         if Z jump no_forcing_endian;
            r3 = r3 AND (65535 - $BYTESWAP_MASK);
            r2 = r2 LSHIFT $cbuffer.FORCE_ENDIAN_SHIFT_AMOUNT;
            r2 = r2 LSHIFT $BYTESWAP_POSN;
            r3 = r3 OR r2;
         no_forcing_endian:

         // adjust config register if 'forced' sign extension selected
         r2 = r0 AND $cbuffer.FORCE_SIGN_EXTEND_MASK;
         if Z jump no_forcing_sign_extend;
            r3 = r3 AND (65535 - $NOSIGNEXT_MASK);
            r2 = r2 LSHIFT $cbuffer.FORCE_SIGN_EXTEND_SHIFT_AMOUNT;
            r2 = r2 LSHIFT $NOSIGNEXT_POSN;
            r3 = r3 OR r2;
         no_forcing_sign_extend:

         // adjust config register if 'forced' bitwidth selected
         r2 = r0 AND $cbuffer.FORCE_BITWIDTH_MASK;
         if Z jump no_forcing_bitwidth;
#if defined(DEBUG_ON) && ! defined(RICK)
            // if we're not on a Rick, check the port isn't 32 bit
            Null = r2 - $cbuffer.FORCE_32BIT_WORD;
            if Z call $error;
#endif
            r3 = r3 AND (65535 - $BITMODE_MASK);
            r2 = r2 LSHIFT $cbuffer.FORCE_BITWIDTH_SHIFT_AMOUNT;
            r2 = r2 LSHIFT $BITMODE_POSN;
            r3 = r3 OR r2;
         no_forcing_bitwidth:
         
#if defined(RICK)
         // adjust config register if 'forced' padding selected
         r2 = r0 AND $cbuffer.FORCE_PADDING_MASK;
         if Z jump no_forcing_padding;
            r3 = r3 AND (65535 - $PAD_EN_MASK);
            r2 = r2 LSHIFT $cbuffer.FORCE_PADDING_SHIFT_AMOUNT;
            r2 = r2 LSHIFT $PAD_EN_POSN;
            r3 = r3 OR r2;
         no_forcing_padding:
#endif

         // update config register with any 'forces' required
         M[r1 + $READ_PORT0_CONFIG] = r3;

         // restore the saved registers
         popm <r2, r3>;

      no_forcing:

      // return the data address of it and a size of 1
      r0 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
#ifdef NON_CONTIGUOUS_PORTS
         r1 =($READ_DATA_GAP - 1);
         Null = ($cbuffer.TOTAL_CONTINUOUS_PORTS -1) - r0;
         if NEG  r0 = r0 + r1;
#endif
      r0 = r0 + $READ_PORT0_DATA;
      r1 = 1;
      rts;

.ENDMODULE;

#ifdef BASE_REGISTER_MODE
// *****************************************************************************
// MODULE:
//    $cbuffer.get_read_address_and_size_and_start_address
//
// DESCRIPTION:
//    Get a read address and size for a cbuffer/port so that it can read in a
// generic way.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//
// OUTPUTS:
//    - r0 = read address
//    - r1 = buffer size
//    - r2 = buffer start address
//
// TRASHED REGISTERS:
//    none
//
// NOTES:
//    If passed a pointer to a cbuffer structure then return the value of the
// current read address and size of the cbuffer.
//
// *****************************************************************************
.MODULE $M.cbuffer.get_read_address_and_size_and_start_address;
   .CODESEGMENT CBUFFER_GET_READ_ADDRESS_AND_SIZE_PM;

   $cbuffer.get_read_address_and_size_and_start_address:

   Null = SIGNDET r0;
   if Z jump its_a_port;
      r2 = M[r0 + $cbuffer.START_ADDR_FIELD];
      r1 = M[r0 + $cbuffer.SIZE_FIELD];
      r0 = M[r0 + $cbuffer.READ_ADDR_FIELD];
      rts;

   its_a_port:
      push rLink;
      call $cbuffer.get_read_address_and_size.its_a_port;
      pop rLink;
      r2 = r0;
      rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.get_write_address_and_size_and_start_address
//
// DESCRIPTION:
//    Get the write address and size for a cbuffer/port so that it can written
// in a generic way.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//
// OUTPUTS:
//    - r0 = write address
//    - r1 = buffer size
//    - r2 = buffer start address
//
// TRASHED REGISTERS:
//    none
//
// NOTES:
//    If passed a pointer to a cbuffer structure then return the value of the
//    current write address and size of the cbuffer.
//    If passed a port identifier then return the write address for the port, and
//    set the size always to 1.
//
// *****************************************************************************
.MODULE $M.cbuffer.get_write_address_and_size_and_start_address;
   .CODESEGMENT CBUFFER_GET_WRITE_ADDRESS_AND_SIZE_PM;

   $cbuffer.get_write_address_and_size_and_start_address:

   Null = SIGNDET r0;
   if Z jump its_a_port;

   its_a_cbuffer:
      r2 = M[r0 + $cbuffer.START_ADDR_FIELD];
      r1 = M[r0 + $cbuffer.SIZE_FIELD];
      r0 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
      rts;

   its_a_port:
      push rLink;
      call $cbuffer.get_write_address_and_size.its_a_port;
      pop rLink;
      r2 = r0;
      rts;

.ENDMODULE;


#endif


// *****************************************************************************
// MODULE:
//    $frmbuffer.get_buffer
//	  $frmbuffer.get_buffer_with_start_address
//
// DESCRIPTION:
//    Get frame buffer frame size, ptr,length, and base address
//
// INPUTS:
//    - r0 = pointer to frame buffer structure
//
// OUTPUTS:
//    - r0 = buffer address
//    - r1 = buffer size
//    - r2 = buffer start address   <base address variant>
//    - r3 = frame size
//
// TRASHED REGISTERS:
//    r2 - (not base address variant)
//
// NOTES:
//    Return the buffer start address in r2 if BASE_REGISTER_MODE
//
// *****************************************************************************
.MODULE $M.frmbuffer.get_buffer;
   .CODESEGMENT CBUFFER_FRM_BUFFER_PM;

#ifdef BASE_REGISTER_MODE
$frmbuffer.get_buffer_with_start_address:
#else
$frmbuffer.get_buffer:
#endif
   r3  = M[r0 + $frmbuffer.FRAME_SIZE_FIELD];
   r2  = M[r0 + $frmbuffer.CBUFFER_PTR_FIELD];
   r0  = M[r0 + $frmbuffer.FRAME_PTR_FIELD];
   r1  = M[r2 + $cbuffer.SIZE_FIELD];
#ifdef BASE_REGISTER_MODE
   r2  = M[r2 + $cbuffer.START_ADDR_FIELD];
#endif
   rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $frmbuffer.set_frame_size
//
// DESCRIPTION:
//    Set frame buffer's frame size
//
// INPUTS:
//    - r0 = pointer to frame buffer structure
//    - r3 = frame size
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//    none
//
// NOTES:
//
// *****************************************************************************
.MODULE $M.frmbuffer.set_frame_size;
   .CODESEGMENT CBUFFER_FRM_BUFFER_PM;

$frmbuffer.set_frame_size:
   M[r0 + $frmbuffer.FRAME_SIZE_FIELD] = r3;
   rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $frmbuffer.set_frame_address
//
// DESCRIPTION:
//    Set frame buffer's frame address
//
// INPUTS:
//    - r0 = pointer to frame buffer structure
//    - r1 = frame address
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//    none
//
// NOTES:
//
// *****************************************************************************
.MODULE $M.frmbuffer.set_frame_address;
   .CODESEGMENT CBUFFER_FRM_BUFFER_PM;

$frmbuffer.set_frame_address:
   M[r0 + $frmbuffer.FRAME_PTR_FIELD] = r1;
   rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $cbuffer.get_write_address_and_size
//
// DESCRIPTION:
//    Get the write address and size for a cbuffer/port so that it can written
// in a generic way.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//
// OUTPUTS:
//    - r0 = write address
//    - r1 = buffer size
//
// TRASHED REGISTERS:
//    none
//
// NOTES:
//    If passed a pointer to a cbuffer structure then return the value of the
//    current write address and size of the cbuffer.
//    If passed a port identifier then return the write address for the port, and
//    set the size always to 1.
//
// *****************************************************************************
#ifndef BASE_REGISTER_MODE
.MODULE $M.cbuffer.get_write_address_and_size;
   .CODESEGMENT CBUFFER_GET_WRITE_ADDRESS_AND_SIZE_PM;

   $cbuffer.get_write_address_and_size:
   $_cbuffer_get_write_address:

   Null = SIGNDET r0;
   if Z jump $cbuffer.get_write_address_and_size.its_a_port;

   its_a_cbuffer:
      r1 = M[r0 + $cbuffer.SIZE_FIELD];
      r0 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
      rts;
.ENDMODULE;
#endif
.MODULE $M.cbuffer.get_write_address_and_size.its_a_port;
   .CODESEGMENT CBUFFER_GET_WRITE_ADDRESS_AND_SIZE_ITS_A_PORT_PM;

   $cbuffer.get_write_address_and_size.its_a_port:

   #ifdef DEBUG_ON
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      Null = r1 - $cbuffer.NUM_PORTS;
      // cannot get a write address for a read port so we error
      if NEG call $error;
   #endif

      // it's a write port
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      r1 = r1 - $cbuffer.NUM_PORTS;

      // save r2 & r3
      pushm <r2, r3>;

#ifdef METADATA_SUPPORT
      // check if port has metadata 
      r2 = M[$cbuffer.write_port_dmb_cbuffer + r1];
      if Z jump $cbuffer.get_write_address_and_size.not_a_metadata_port;

      // force an MMU buffer set
      Null = M[$PORT_BUFFER_SET];

      // cache write offset if not already cached, so we can work out how many
      // octets were written when calling cbuffer.set_write_address
      r2 = M[$cbuffer.write_port_offset_cache + r1];
   #ifdef DEBUG_ON
      // if offset is pos then get_write_address_and_size has been called already
      if POS call $error;
   #endif
         r3 = M[$cbuffer.write_port_offset_addr + r1];
         r3 = M[r3];
         M[$cbuffer.write_port_offset_cache + r1] = r3;              
      $cbuffer.get_write_address_and_size.write_port_offset_cached:

   $cbuffer.get_write_address_and_size.not_a_metadata_port:
#endif

      // if force flags are set then alter appropriate config bits for the port
      Null = r0 AND ($cbuffer.FORCE_ENDIAN_MASK + $cbuffer.FORCE_BITWIDTH_MASK + $cbuffer.FORCE_SATURATE_MASK + $cbuffer.FORCE_PADDING_MASK);
      if Z jump no_forcing;

#ifdef NON_CONTIGUOUS_PORTS
         r2 = ($WRITE_CONFIG_GAP - 1);
         Null =($cbuffer.TOTAL_CONTINUOUS_PORTS - 1) - r1;
         if NEG  r1 = r1 + r2;
#endif

         // read config register
         r3 = M[r1 + $WRITE_PORT0_CONFIG];

         // adjust config register if 'forced' endian selected
         r2 = r0 AND $cbuffer.FORCE_ENDIAN_MASK;
         if Z jump no_forcing_endian;
            r3 = r3 AND (65535 - $BYTESWAP_MASK);
            r2 = r2 LSHIFT $cbuffer.FORCE_ENDIAN_SHIFT_AMOUNT;
            r2 = r2 LSHIFT $BYTESWAP_POSN;
            r3 = r3 OR r2;
         no_forcing_endian:

         // adjust config register if 'forced' bitwidth selected
         r2 = r0 AND $cbuffer.FORCE_BITWIDTH_MASK;
         if Z jump no_forcing_bitwidth;
            r3 = r3 AND (65535 - $BITMODE_MASK);
#if defined(DEBUG_ON) && !defined(RICK)
            // if we're not on a Rick, check the port isn't 32 bit
            Null = r2 - $cbuffer.FORCE_32BIT_WORD;
            if Z call $error;
#endif
            r2 = r2 LSHIFT $cbuffer.FORCE_BITWIDTH_SHIFT_AMOUNT;
            r2 = r2 LSHIFT $BITMODE_POSN;
            r3 = r3 OR r2;
         no_forcing_bitwidth:

#if defined(RICK)
         // adjust config register if 'forced' padding selected
         r2 = r0 AND $cbuffer.FORCE_PADDING_MASK;
         if Z jump no_forcing_padding;
            r3 = r3 AND (65535 - $PAD_EN_MASK);
            r2 = r2 LSHIFT $cbuffer.FORCE_PADDING_SHIFT_AMOUNT;
            r2 = r2 LSHIFT $PAD_EN_POSN;
            r3 = r3 OR r2;
         no_forcing_padding:
#endif

         // adjust config register if 'forced' saturate selected
         r2 = r0 AND $cbuffer.FORCE_SATURATE_MASK;
         if Z jump no_forcing_saturate;
            r3 = r3 AND (65535 - $SATURATE_MASK);
            r2 = r2 LSHIFT $cbuffer.FORCE_SATURATE_SHIFT_AMOUNT;
            r2 = r2 LSHIFT $SATURATE_POSN;
            r3 = r3 OR r2;
         no_forcing_saturate:

         // update config register with any 'forces' required
         M[r1 + $WRITE_PORT0_CONFIG] = r3;

      no_forcing:

#ifdef NON_CONTIGUOUS_PORTS
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      r1 = r1 - $cbuffer.NUM_PORTS;
      r2 = ($WRITE_DATA_GAP - 1);
      Null =($cbuffer.TOTAL_CONTINUOUS_PORTS - 1) - r1;
      if NEG  r1 = r1 + r2;
#endif
     // restore the saved registers
     popm <r2, r3>;

     // return the data address of it and a size of 1
     r0 = r1 + $WRITE_PORT0_DATA;
     r1 = 1;
     rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.set_read_address
//
// DESCRIPTION:
//    Set the read address for a cbuffer/port.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//    - r1 = read address
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    If a cbuffer: none
//    If a port: r0, r1, r2, r3, r4, r5, r6, r10, DoLoop
//
// NOTES:
//    If passed a pointer to a cbuffer structure then set the value of the
//    current read address of the cbuffer.
//    If passed a port identifier then set the read offset for the port, and
//    handle other maintainance tasks associated with ports.
//
// *****************************************************************************
.MODULE $M.cbuffer.set_read_address;
   .CODESEGMENT CBUFFER_SET_READ_ADDRESS_PM;

   $cbuffer.set_read_address:

   Null = SIGNDET r0;
   if Z jump $cbuffer.set_read_address.its_a_port;

   its_a_cbuffer:
      M[r0 + $cbuffer.READ_ADDR_FIELD] = r1;
      rts;
.ENDMODULE;

.MODULE $M.cbuffer.set_read_address.its_a_port;
   .CODESEGMENT CBUFFER_SET_READ_ADDRESS_ITS_A_PORT_PM;

   $cbuffer.set_read_address.its_a_port:

   #ifdef DEBUG_ON
      // cannot set the read address for a write port so we error
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      Null = r1 - $cbuffer.NUM_PORTS;
      if POS call $error;
   #endif

      // push rLink onto stack
      $push_rLink_macro;

      // get port number
      r3 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;

      // force an MMU buffer set
      Null = M[$PORT_BUFFER_SET];

#ifdef METADATA_SUPPORT
      // check if port has metadata 
      r0 = M[$cbuffer.read_port_dmb_cbuffer + r3];
      if Z jump $cbuffer.set_read_address.not_a_metadata_port;

      // save I0, L0 as we about to modify them
      pushm <I0, L0>;

   #ifdef DEBUG_ON
      // check there's actually metadata in the cbuffer associated with the
      // port, if there's not metadata the application has called us in error
      push r0;
      r0 = M[$cbuffer.read_port_dmb_cbuffer + r3];
      call $cbuffer.calc_amount_data;
      Null = r0 - $cbuffer.DMB_CBUFFER_HEADER_MIN_SIZE;
      if NEG call $error;
      pop r0;
   #endif

      // get metadata cbuffer read address and size
      call $cbuffer.get_read_address_and_size;
      I0 = r0;
      L0 = r1;
    
      // get metadata offset
      r1 = M[I0, 0];

      // get updated read offset
      r0 = M[$cbuffer.read_port_offset_addr + r3];
      r0 = M[r0];
    
      // calculate difference between offsets, i.e. amount of data read
      r1 = r0 - r1;
      r0 = M[$cbuffer.read_port_buffer_size + r3];
      r0 = r0 - 1;
      r1 = r1 AND r0;
        
      // update offset
      r2 = M[I0, 0];    // msgfrag offset
      r2 = r2 + r1;
      r2 = r2 AND r0;
      M[I0, 1] = r2;

      // update length
      r2 = M[I0, 1];    // msgfrag length
      r2 = r2 - r1;
      if NEG call $error;
       
      // only update cbuffer read address if length is 0
      if NZ jump dont_update_cbuffer;
         r0 = M[$cbuffer.read_port_dmb_cbuffer + r3];
         r1 = I0;
         call $cbuffer.set_read_address;
         L0 = 0;
      dont_update_cbuffer:

      // restore I0, L0
      popm <I0, L0>;

   $cbuffer.set_read_address.not_a_metadata_port:
#endif

#ifdef DUMMY_READ_FOR_24BIT_CLEANUP
      // dummy read from port 11 to make sure any 24 bit reads are all cleaned up
      Null = M[$READ_PORT11_DATA];
#endif

      // if requested send message to MCU
      Null = M[$cbuffer.auto_mcu_message];
      if Z jump dont_message_send;

         // if limit_addr is in MCU_WIN1 then the device connected to the port
         // is software triggered and so we should send a DATA_CONSUMED message
         r1 = M[$cbuffer.read_port_limit_addr + r3];
         Null = r1 - $MCUWIN2_START;
         if POS jump dont_message_send;

            // setup message
            r2 = Null OR $MESSAGE_DATA_CONSUMED;

            // r3 = bit mask depending on port number
            r3 = 1 ASHIFT r3;
            call $message.send_short;

      dont_message_send:

#ifdef DEBUG_ON
      // The description states that r4, r5, r6 will be trashed, but they are
      // only trashed if a message is sent that uses a timer. This leads to a
      // class of bugs where r4, r5, r6 are not saved by the caller and are
      // only occasionally trashed by this function. Therefore in debug mode,
      // intentionally trash them. The intention is to provoke a crash
      // immediately.
      r4 = 0;
      r5 = 0;
      r6 = 0;
#endif

      // pop rLink from stack
      jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.set_write_address
//
// DESCRIPTION:
//    Set the write address for a cbuffer/port.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//    - r1 = write address
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    If a cbuffer: none
//    If a port: r0, r1, r2, r3, r4, r5, r6, r10, DoLoop
//
// NOTES:
//    If passed a pointer to a cbuffer structure then set the value of the
//    current write address of the cbuffer.
//    If passed a port identifier then set the write offset for the port, and
//    handle other maintainance tasks associated with ports.
//
// *****************************************************************************
.MODULE $M.cbuffer.set_write_address;
   .CODESEGMENT CBUFFER_SET_WRITE_ADDRESS_PM;

   $cbuffer.set_write_address:

   Null = SIGNDET r0;
   if Z jump $cbuffer.set_write_address.its_a_port;

   its_a_cbuffer:
      M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r1;
      rts;
.ENDMODULE;

.MODULE $M.cbuffer.set_write_address.its_a_port;
   .CODESEGMENT CBUFFER_SET_WRITE_ADDRESS_ITS_A_PORT_PM;

   $cbuffer.set_write_address.its_a_port:

   #ifdef DEBUG_ON
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      Null = r1 - $cbuffer.NUM_PORTS;
      // cannot set the write address for a read port so we error
      if NEG call $error;
   #endif

      // push rLink onto stack
      $push_rLink_macro;

      r0 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      r0 = r0 - $cbuffer.NUM_PORTS;

      // force an MMU buffer set
      Null = M[$PORT_BUFFER_SET];

   #ifdef METADATA_SUPPORT
      // check if port has metadata 
      r2 = M[$cbuffer.write_port_dmb_cbuffer + r0];
      if Z jump $cbuffer.set_write_address.not_a_metadata_port;

      // get updated write offset
      r3 = M[$cbuffer.write_port_offset_addr + r0];
      r3 = M[r3];

      // get write_offset cached when get_write_address was called
      r1 = M[$cbuffer.write_port_offset_cache + r0];
   #ifdef DEBUG_ON
      // if offset is negate get_write_address_and_size wasn't called
      if NEG call $error;
   #endif

      // calculate number of octets written
      r3 = r3 - r1;
      r4 = M[$cbuffer.write_port_buffer_size + r0];
      r4 = r4 - 1;
      r3 = r3 AND r4;

      // save I0, L0 as we about to modify them
      pushm <I0, L0>;

      // write to metadata cbuffer
      r4 = M[r2 + $cbuffer.SIZE_FIELD];
      L0 = r4;
      r4 = M[r2 + $cbuffer.WRITE_ADDR_FIELD];
      I0 = r4;
      M[I0, 1] = r1;
      M[I0, 1] = r3;
      r4 = I0;
      M[r2 + $cbuffer.WRITE_ADDR_FIELD] = r4;

   #ifdef DEBUG_ON
      // clear cache
      r1 = -1;
      M[$cbuffer.write_port_offset_cache + r0] = r1;
   #endif

      // Attempt to copy cbuffer to DMB write port
      pushm <I4, L4>;
      push r0;
      r3 = 1 LSHIFT r0;
      call $cbuffer.update_dmb_write_port;
      pop r0;
      popm <I4, L4>;

      // restore I0, L0
      popm <I0, L0>;

   $cbuffer.set_write_address.not_a_metadata_port:
   #endif

      // if requested send message to MCU
      Null = M[$cbuffer.auto_mcu_message];
      if Z jump dont_message_send;

         // if limit_addr is in MCU_WIN1 then the device connected to the port
         // is software triggered and so we should send a DATA_PRODUCED message
         r1 = M[$cbuffer.write_port_limit_addr + r0];
         Null = r1 - $MCUWIN2_START;
         if POS jump dont_message_send;

            // setup message
            r2 = Null OR $MESSAGE_DATA_PRODUCED;
            // r3 = bit mask depending on port number
            r3 = 1 ASHIFT r0;
            call $message.send_short;
      dont_message_send:

#ifdef DEBUG_ON
      // The description states that r4, r5, r6 will be trashed, but they are
      // only trashed if a message is sent that uses a timer. This leads to a
      // class of bugs where r4, r5, r6 are not saved by the caller and are
      // only occasionally trashed by this function. Therefore in debug mode,
      // intentionally trash them. The intention is to provoke a crash
      // immediately.
      r4 = 0;
      r5 = 0;
      r6 = 0;
#endif

      // pop rLink from stack
      jump $pop_rLink_and_rts;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $cbuffer.calc_amount_space
//
// DESCRIPTION:
//    Calculates the amount of space for new data in a cbuffer/port.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//
// OUTPUTS:
//    - r0 = amount of space (for new data) in words
//    - r2 = buffer size in words (bytes if an mmu port)
//
// TRASHED REGISTERS:
//    r1
//
// NOTES:
//    If passed a pointer to a cbuffer structure then return the amount of space
//    (for new data) in the cbuffer.
//    If passed a port identifier then return the amount of space (for new data)
//    in the port.
//
// *****************************************************************************
.MODULE $M.cbuffer.calc_amount_space;
   .CODESEGMENT CBUFFER_CALC_AMOUNT_SPACE_PM;

   $cbuffer.calc_amount_space:

   Null = SIGNDET r0;
   if Z jump $cbuffer.calc_amount_space.its_a_port;

   its_a_cbuffer:
      r2 = M[r0 + $cbuffer.SIZE_FIELD];
      r1 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
      r0 = M[r0 + $cbuffer.READ_ADDR_FIELD];

      // calculate the amount of space
      r0 = r0 - r1;
      if LE r0 = r0 + r2;

      // always say it's 1 less so that buffer never gets totally filled up
      r0 = r0 - 1;
      rts;
.ENDMODULE;

.MODULE $M.cbuffer.calc_amount_space.its_a_port;
   .CODESEGMENT CBUFFER_CALC_AMOUNT_SPACE_ITS_A_PORT_PM;

   $cbuffer.calc_amount_space.its_a_port:
      // get the port number
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
      r1 = r1 - $cbuffer.NUM_PORTS;

      #ifdef DEBUG_ON
         // cannot get the amount of space for a read port so we error
         if NEG call $error;
      #endif

      r2 = M[$cbuffer.write_port_limit_addr + r1];
      // check port is still valid, otherwise rts
      if Z r0 = 0;
      if Z rts;

      // save r3
      push r3;

      // get limit offset value
      r3 = M[r2];

      // get the actual MMU offset
      r2 = M[$cbuffer.write_port_offset_addr + r1];
      r2 = M[r2];

      // calculate the amount of space (Limit offset - local write offset)
      r3 = r3 - r2;

      // get buffer size
      r2 = M[$cbuffer.write_port_buffer_size + r1];
      r1 = r2 - 1;

      // mask out wrap around
      r1 = r3 AND r1;

      // if ptrs equal then Space = BufSize
      if Z r1 = r2;

      // always say 1 less so that buffer never gets totally filled up
      r1 = r1 - 1;

      // restore r3
      pop r3;

      // now convert from num_bytes to the correct word size
      r0 = r0 AND $cbuffer.FORCE_BITWIDTH_MASK;
      if Z jump port_width_16bit;
      Null = r0 - $cbuffer.FORCE_16BIT_WORD;
      if Z jump port_width_16bit;
      if NEG jump port_width_8bit;
      Null = r0 - $cbuffer.FORCE_24BIT_WORD;
      if Z jump port_width_24bit;

      port_width_32bit:
         // calc floor(num_bytes / 4)
         r0 = r1 ASHIFT -2;
         rts;

      port_width_24bit:
         // calc floor(num_bytes / 3)
         r0 = r1 - 1;
         // * 0.3333 (16bt precison) so no prefix needed
         r0 = r0 * 0x2AAB00 (frac);
         rts;

      port_width_8bit:
         // calc floor(num_bytes / 1)
         r0 = r1;
         rts;

      port_width_16bit:
         // calc floor(num_bytes / 2)
         r0 = r1 ASHIFT -1;
         rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.calc_amount_data
//
// DESCRIPTION:
//    Calculates the amount of data already in a cbuffer/port.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//
// OUTPUTS:
//    - r0 = amount of data available in words
//    - r1 = amount of data available in bytes (needed for USB support)
//    - r2 = buffer size in words (bytes if an mmu port)
//
// TRASHED REGISTERS:
//    r1
//
// NOTES:
//    If passed a pointer to a cbuffer structure then return the amount of data
//    in the cbuffer.
//    If passed a port identifier then return the amount of data in the port.
//
// *****************************************************************************
.MODULE $M.cbuffer.calc_amount_data;
   .CODESEGMENT CBUFFER_CALC_AMOUNT_DATA_PM;

   $cbuffer.calc_amount_data:

   Null = SIGNDET r0;
   if Z jump $cbuffer.calc_amount_data.its_a_port;

   its_a_cbuffer:
      r2 = M[r0 + $cbuffer.SIZE_FIELD];
      r1 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
      r0 = M[r0 + $cbuffer.READ_ADDR_FIELD];

      // calculate the amount of data
      r0 = r1 - r0;
      if NEG r0 = r0 + r2;
      rts;
.ENDMODULE;

.MODULE $M.cbuffer.calc_amount_data.its_a_port;
   .CODESEGMENT CBUFFER_CALC_AMOUNT_DATA_ITS_A_PORT_PM;

   $cbuffer.calc_amount_data.its_a_port:

      // get the port number
      r1 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;

      #ifdef DEBUG_ON
          Null = r1 - $cbuffer.NUM_PORTS;
          // cannot get the amount of data available for a write port so we error
          if POS call $error;
      #endif

      // check port is still valid, otherwise rts
      r2 = M[$cbuffer.read_port_limit_addr + r1];
      if Z r0 = 0;
      if Z rts;

      // save r0
      push r0;

#ifdef METADATA_SUPPORT
      // check if port has metadata 
      r0 = M[$cbuffer.read_port_dmb_cbuffer + r1];
      if NZ jump $cbuffer.calc_amount_data.its_a_metadata_port;
#endif
    
      // get limit offset value
      r2 = M[r2];

      r0 = M[$cbuffer.read_port_offset_addr + r1];
      r0 = M[r0];

      // calculate the amount of data (Limit offset - local read offset)
      r0 = r2 - r0;

      // get buffer size
      r2 = M[$cbuffer.read_port_buffer_size + r1];
      r1 = r2 - 1;

      // mask out any wrap around
      r1 = r0 AND r1;

   $cbuffer.calc_amount_data.convert_size:

      // restore r0
      pop r0;

   convert:
      // now convert from num_bytes to the correct word size
      r0 = r0 AND $cbuffer.FORCE_BITWIDTH_MASK;
      if Z jump port_width_16bit;
      Null = r0 - $cbuffer.FORCE_16BIT_WORD;
      if Z jump port_width_16bit;
      if NEG jump port_width_8bit;
      Null = r0 - $cbuffer.FORCE_24BIT_WORD;
      if Z jump port_width_24bit;

      port_width_32bit:
         // calc floor(num_bytes / 4)
         r0 = r1 ASHIFT -2;
         rts;

      port_width_24bit:
         // calc floor(num_bytes / 3)
         r0 = r1 - 1;
         // * 0.3333 (16bt precison) so no prefix needed
         r0 = r0 * 0x2AAB00 (frac);
         rts;

      port_width_8bit:
         // calc floor(num_bytes / 1)
         r0 = r1;
         rts;

      port_width_16bit:
         // calc floor(num_bytes / 2)
         r0 = r1 ASHIFT - 1;
         rts;

#ifdef METADATA_SUPPORT
   // on metadata ports, only return the size of packet at head of the queue
   $cbuffer.calc_amount_data.its_a_metadata_port:

      // push rLink onto stack
      $push_rLink_macro;

      // save cbuffer address
      push r0;
      
      // calc amount of data in DMB cbuffer
      call $cbuffer.calc_amount_data;
      
      // check enough data for DMB header
      Null = r0 - $cbuffer.DMB_CBUFFER_HEADER_MIN_SIZE;
      if NEG jump $cbuffer.calc_amount_data.no_metadata;

      // get read address and size
      pop r0;
      call $cbuffer.get_read_address_and_size;

      // read meta-data from cbuffer
      pushm <I0, L0>;        
      I0 = r0;
      L0 = r1;
      r1 = M[I0, 1];    // msgfrag offset
      r1 = M[I0, 1];    // msgfrag length
      popm <I0, L0>;

      // pop rLink from stack
      $pop_rLink_macro;

      // jump back to convert size     
      jump $cbuffer.calc_amount_data.convert_size;   

   $cbuffer.calc_amount_data.no_metadata:

      // clean up stack
      pop Null;
      $pop_rLink_macro;
      pop Null;

      // no data
      r0 = 0;
      r1 = 0;
      rts;
#endif

.ENDMODULE;

// ******************************************************************************************************
// MODULE:
//    $cbuffer.mmu_octets_to_samples
//
// DESCRIPTION:
//    Convert the number of octets (in a port) to samples
//    (note: this depends on the port configuration.
//
// INPUTS:
//    - r2 = Number of octets (e.g. size of port in octets)
//    - r3 = Port ID/configuration
//
// OUTPUTS:
//    - r2 = Number of samples
//
// TRASHED REGISTERS:
//    None
//
// *******************************************************************************************************
.MODULE $M.cbuffer.mmu_octets_to_samples;
   .CODESEGMENT CBUFFER_MMU_OCTETS_TO_SAMPLES_PM;

   $cbuffer.mmu_octets_to_samples:

   // If not a port skip the conversion
   Null = SIGNDET r3;
   if NZ jump skip_conversion;

      push rLink;
      pushm <r0,r1>;
      // Make register usage compatible with existing routine
      r0 = r3;
      r1 = r2;
      call $M.cbuffer.calc_amount_data.its_a_port.convert;
      r2 = r0;
      popm <r0,r1>;
      pop rLink;

   skip_conversion:

   rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.buffer_configure
//
// DESCRIPTION:
//    Configures a kalimba cbuffer for use
//
// INPUTS:
//    - r0 = cbuffer structure
//    - r1 = read/write address (ie. initialised to be the same)
//    - r2 = buffer size
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    none
//
// *****************************************************************************
.MODULE $M.cbuffer.buffer_configure;
   .CODESEGMENT CBUFFER_BUFFER_CONFIGURE_PM;

   $cbuffer.buffer_configure:

   M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r1;
   M[r0 + $cbuffer.READ_ADDR_FIELD]  = r1;
#ifdef BASE_REGISTER_MODE
   M[r0 + $cbuffer.START_ADDR_FIELD] = r1;
#endif
   M[r0 + $cbuffer.SIZE_FIELD]       = r2;
   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.configure_port_message_handler
//
// DESCRIPTION:
//    Message handler for $MESSAGE_CONFIGURE_PORT message
//
// INPUTS:
//    - r0 = message ID
//    - r1 = message Data 0  (Port number 0-3 read port, 4-7 write port)
//    - r2 = message Data 1  (Offset address pointer)
//    - r3 = message Data 2  (Limit address pointer)
//    - r4 = message Data 3  (Metadata flags)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r1, r2
//
// *****************************************************************************
.MODULE $M.cbuffer.configure_port_message_handler;
   .CODESEGMENT CBUFFER_CONFIGURE_PORT_MESSAGE_HANDLER_PM;

   $cbuffer.configure_port_message_handler:

   // push rLink onto stack
   $push_rLink_macro;

#ifdef BUILD_WITH_C_SUPPORT
   // prep for the C compiler
   M0 = 0;
   M1 = 1;
   M2 = -1;
#endif

   // See if it's a read or write port that's being configured
   Null = r1 - $cbuffer.NUM_PORTS;
   if POS call write_port;

   read_port:
   
#ifdef METADATA_SUPPORT
      // check if DMB port
      Null = r4 AND $cbuffer.CONFIGURE_PORT_IS_DMB;
      if Z jump not_dmb_read_port;
         r0 = r1 + ($cbuffer.READ_PORT_MASK + $cbuffer.FORCE_16BIT_WORD + $cbuffer.FORCE_LITTLE_ENDIAN);
         M[$cbuffer.dmb_read_port] = r0;
      not_dmb_read_port:
#endif
   
      // ** Configure read port for use by cbuffer functions**
      // r1 = msg_data_1: port number
      // r2 = msg_data_2: offset address
      // r3 = msg_data_3: limit address
      M[$cbuffer.read_port_limit_addr + r1] = r3;
      M[$cbuffer.read_port_offset_addr + r1] = r2;

      // if offset address is zero then port has been disconnected
      if NZ jump read_port_connect;

      read_port_disconnect:
#ifdef METADATA_SUPPORT
         // empty metadata cbuffer for this port
         pushm <r1, r3>;
         r0 = M[($cbuffer.write_port_dmb_cbuffer - $cbuffer.WRITE_PORT_OFFSET) + r1];
         if NZ call $cbuffer.empty_buffer;
         popm <r1, r3>;
#endif
         // call disconnection callback function
         r0 = $cbuffer.CALLBACK_PORT_DISCONNECT;
         rLink = M[$cbuffer.read_port_disconnect_address];
         if NZ call rLink;

         // pop rLink from stack
         jump $pop_rLink_and_rts;

      read_port_connect:

         // save port number in r0 so it doesn't get trashed
         r0 = r1;

         // store buffer size
         r2 = M[r2 + (-1)];                   // buffer size field
         r1 = $cbuffer.MMU_PAGE_SIZE;
         r2 = r2 LSHIFT -8;                   // calc buffer size
         r2 = r1 LSHIFT r2;
         M[$cbuffer.read_port_buffer_size + r0] = r2;

         // if we're connected to a non-software triggered device (eg DAC/ADC/SCO)
         // then assume we need 16-bit and sign-extension
         r1 = $BITMODE_16BIT_ENUM;

         // if we're connected to a software triggered device (eg UART/L2CAP)
         // then assume we need to byteswap the 16-bit data and not do sign-extension
         r2 = ($BITMODE_16BIT_ENUM + $BYTESWAP_MASK + $NOSIGNEXT_MASK);
         Null = r3 - $MCUWIN2_START;
         if NEG r1 = r2;

#ifdef NON_CONTIGUOUS_PORTS
         pushm <r0, r2>;
         r2 =($READ_CONFIG_GAP - 1);
         Null = ($cbuffer.TOTAL_CONTINUOUS_PORTS -1) - r0;
         if NEG r0 = r0 + r2;
         M[$READ_PORT0_CONFIG + r0] = r1;
         popm <r0, r2>;
#else
         M[$READ_PORT0_CONFIG + r0] = r1;
#endif

         // load the port number in r1 & call the connect function if there is one
         r1 = r0;
         r0 = $cbuffer.CALLBACK_PORT_CONNECT;
         rLink = M[$cbuffer.read_port_connect_address];
         if NZ call rLink;

         // pop rLink from stack
         jump $pop_rLink_and_rts;

   write_port:

#ifdef METADATA_SUPPORT
      // check if DMB port
      Null = r4 AND $cbuffer.CONFIGURE_PORT_IS_DMB;
      if Z jump not_dmb_write_port;
         r0 = r1 - $cbuffer.NUM_PORTS;
         r0 = r0 + ($cbuffer.WRITE_PORT_MASK + $cbuffer.FORCE_16BIT_WORD + $cbuffer.FORCE_LITTLE_ENDIAN);
         M[$cbuffer.dmb_write_port] = r0;
      not_dmb_write_port:
#endif

      // ** Configure write port for use by cbuffer functions**
      // r1 = msg_data_1: port number
      // r2 = msg_data_2: offset address
      // r3 = msg_data_3: limit address
      M[($cbuffer.write_port_limit_addr - $cbuffer.WRITE_PORT_OFFSET) + r1] = r3;
      M[($cbuffer.write_port_offset_addr - $cbuffer.WRITE_PORT_OFFSET) + r1] = r2;

      // if offset address is zero then port has been disconnected
      if NZ jump write_port_connect;

         write_port_disconnect:

#ifdef METADATA_SUPPORT
            // empty metadata cbuffer for this port
            pushm <r1, r3>;
            r0 = M[($cbuffer.write_port_dmb_cbuffer - $cbuffer.WRITE_PORT_OFFSET) + r1];
            if NZ call $cbuffer.empty_buffer;
            popm <r1, r3>;
#endif
 
            r0 = $cbuffer.CALLBACK_PORT_DISCONNECT;
            rLink = M[$cbuffer.write_port_disconnect_address];
            if NZ call rLink;

            // pop rLink from stack
            jump $pop_rLink_and_rts;

         write_port_connect:

#ifdef METADATA_SUPPORT
#ifdef DEBUG_ON
            // clear write_port_offset_cache
            r0 = -1;
            M[($cbuffer.write_port_offset_cache - $cbuffer.WRITE_PORT_OFFSET) + r1] = r0;
#endif
#endif

            r0 = r1;

            // store buffer size
            r2 = M[r2 + (-1)];                   // buffer size field
            r1 = $cbuffer.MMU_PAGE_SIZE;
            r2 = r2 LSHIFT -8;                   // calc buffer size
            r2 = r1 LSHIFT r2;
            M[($cbuffer.write_port_buffer_size - $cbuffer.WRITE_PORT_OFFSET) + r0]  = r2;

            // if we're connected to a non-software triggered device (eg DAC/ADC/SCO)
            // then assume we need 16-bit data
            // and also saturate to 16bits
            r1 = ($BITMODE_16BIT_ENUM + $SATURATE_MASK);

            // if we're connected to a software triggered device (eg UART/L2CAP)
            // then assume we need to byteswap the 16-bit data
            r2 = ($BITMODE_16BIT_ENUM + $BYTESWAP_MASK);
            Null = r3 - $MCUWIN2_START;
            if NEG r1 = r2;

#ifdef NON_CONTIGUOUS_PORTS
            pushm <r0,r2>;
            r0 = r0 - $cbuffer.NUM_PORTS;
            r2 = ($WRITE_CONFIG_GAP - 1);
            Null = ($cbuffer.TOTAL_CONTINUOUS_PORTS - 1) - r0;
            if NEG r0 = r0 + r2;
            M[$WRITE_PORT0_CONFIG + r0] = r1;
            popm <r0, r2>;
#else
            M[($WRITE_PORT0_CONFIG - $cbuffer.WRITE_PORT_OFFSET) + r0] = r1;
#endif

            // load the port number in r1 & call the connect function if there is one
            r1 = r0;
            r0 = $cbuffer.CALLBACK_PORT_CONNECT;
            rLink = M[$cbuffer.write_port_connect_address];
            if NZ call rLink;

            // pop rLink from stack
            jump $pop_rLink_and_rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.force_mmu_set
//
// DESCRIPTION:
//    Update the MMU offsets
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    none
//
// NOTES:
//    This forces an MMU buffer set.
//
//    Each MMU port has an offset which tracks how much data has been accessed
// from the port. The DSP uses this value to work out how much data/space is
// available in the port.
//
// Kalimba can explicitly force an MMU buffer set. Consequently a local offset
// is not stored in the DSP and the cache will never be stale so long as you
// perform a set after reads and writes - i.e. call
// $cbuffer.set_read_address and $cbuffer.set_write_address.
//
// *****************************************************************************
.MODULE $M.cbuffer.force_mmu_set;
   .CODESEGMENT CBUFFER_FORCE_MMU_SET_PM;

   $cbuffer.force_mmu_set:

   // force an MMU buffer set
   Null = M[$PORT_BUFFER_SET];

   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.empty_buffer
//
// DESCRIPTION:
//    Empties the supplied port or cbuffer.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    If a cbuffer: r0, r1, r3
//    If a port   : r0, r1, r2, r3, r4, r5, r6, r10, DoLoop
//
// NOTES:
//    This routine empties a port or cbuffer. For cbuffers it simply moves the
// read pointer, for ports it must read the samples from the port.
//
//    Interrupts should be blocked before this call, unless you "own" the
// cbuffer read pointer.
//
// *****************************************************************************
.MODULE $M.cbuffer.empty_buffer;
   .CODESEGMENT CBUFFER_EMPTY_BUFFER_PM;

   $cbuffer.empty_buffer:

   // push rLink onto stack
   $push_rLink_macro;

   // save r0
   r3 = r0;

   Null = SIGNDET r0;
   if Z jump its_a_port;
      // move the read pointer to the write pointer
      call $cbuffer.get_write_address_and_size;
      r1 = r0;
   jump set_address_and_exit;

   its_a_port:
      // for a port its a bit more work, we actually have to read the data
      // how much data is there
      call $cbuffer.calc_amount_data;
      r10 = r0;
      // get the read address
      r0 = r3;
      call $cbuffer.get_read_address_and_size;

      // go round and read the data
      do empty_port_loop;
         Null = M[r0];
      empty_port_loop:

   set_address_and_exit:
   // update the read address - r1 set if its a cbuffer, r2 if its a port
   r0 = r3;
   call $cbuffer.set_read_address;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.fill_buffer
//
// DESCRIPTION:
//    Fills a port or cbuffer with a supplied value.
//
// INPUTS:
//    - r0 = pointer to cbuffer structure (for cbuffers)
//           or a port identifier (for ports)
//    - r1 = value to write into buffer/port
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    If a cbuffer: r0 - r4, r10, I0, L0, DoLoop
//    If a port   : r0, r1, r2, r3, r4, r5, r6, r10, DoLoop
//
//
// NOTES:
//    This routine fills a port or cbuffer with a supplied value.
//
//    Interrupts must be blocked during this call.
//
// *****************************************************************************
.MODULE $M.cbuffer.fill_buffer;
   .CODESEGMENT CBUFFER_FILL_BUFFER_PM;

   $cbuffer.fill_buffer:

   // push rLink onto stack
   $push_rLink_macro;

   // save the inputs
   r3 = r0;
   r4 = r1;

   // work out how much space we've got
   call $cbuffer.calc_amount_space;
   r10 = r0;

   // get the read address and size
   r0 = r3;
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   push r2;
   pop B0;
#else
   call $cbuffer.get_write_address_and_size;
#endif
   I0 = r0;
   L0 = r1;

   // fill the buffer
   do fill_buffer_loop;
      M[I0,1] = r4;
   fill_buffer_loop:

   // set the write address, r2 has already been set (in case its a port)
   r0 = r3;
   r1 = I0;
   call $cbuffer.set_write_address;
   L0 = 0;
#ifdef BASE_REGISTER_MODE
   push Null;
   pop B0;
#endif

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.advance_read_ptr
//
// DESCRIPTION:
//    Advances read pointer of a cbuffer by a supplied value
//
// INPUTS:
//    - r0 = pointer to cbuffer struc
//    - r10 = number by which read pointer would be advanced
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r1, I0, L0, M3
//
// NOTES:
//    This routine advances the read pointer of the cbuffer by a supplied value
//
// *****************************************************************************
.MODULE $M.cbuffer.advance_read_ptr;
   .CODESEGMENT CBUFFER_ADVANCE_READ_PTR_PM;

   $cbuffer.advance_read_ptr:

   // push rLink onto stack
   $push_rLink_macro;

   // push r0 onto stack
   push r0;

   // get cbuffer read address and size
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_read_address_and_size_and_start_address;
   push r2;
   pop  B0;
#else
   call $cbuffer.get_read_address_and_size;
#endif
   I0 = r0;
   L0 = r1;

   // advance read pointer by r10
   M3 = r10;
   r0 = M[I0,M3];

   // pop r0 from the stack
   pop  r0;

   // set advanced read address
   r1 = I0;
   call $cbuffer.set_read_address;
   L0 = 0;
#ifdef BASE_REGISTER_MODE
   push Null;
   pop  B0;
#endif

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;




// *****************************************************************************
// MODULE:
//    $cbuffer.advance_write_ptr
//
// DESCRIPTION:
//    Advances write pointer of a cbuffer by a supplied value
//
// INPUTS:
//    - r0 = pointer to cbuffer struc
//    - r10 = number by which write pointer should be advanced
//            May be negative to achieve regression
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r1, I0, L0, M3
//
// NOTES:
//    This routine advances the write pointer of the cbuffer by a supplied value
//
// *****************************************************************************
.MODULE $M.cbuffer.advance_write_ptr;
   .CODESEGMENT PM;

   $cbuffer.advance_write_ptr:

   // push rLink onto stack
   $push_rLink_macro;

   // push r0 onto stack
   push r0;

   // get cbuffer write address and size
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   push B0;
   push r2;
   pop  B0;
#else
   call $cbuffer.get_write_address_and_size;
#endif
   I0 = r0;
   L0 = r1;

   // advance write pointer by r10
   M3 = r10;
   r0 = M[I0,M3];

#ifdef BASE_REGISTER_MODE
   pop  B0;
#endif
   // pop r0 from the stack
   pop  r0;

   // set advanced write address
   r1 = I0;
   call $cbuffer.set_write_address;
   L0 = 0;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.write_word
//
// DESCRIPTION:
//    Writes 1 word to cbuffer
//
// INPUTS:
//    - r0 = pointer to cbuffer struc
//    - r1 = word to write to cbuffer
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r2, I0, L0
//
// NOTES:
//    cbuffer is not checked to see if it is full
//
// *****************************************************************************
.MODULE $M.cbuffer.write_word;
   .CODESEGMENT PM;

$cbuffer.write_word:
   r2 = M[r0 + $cbuffer.SIZE_FIELD];
   L0 = r2;
   r2 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
   I0 = r2;
   M[I0, 1] = r1;
   r2 = I0;
   M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r2;
   L0 = 0;
   rts;
   
.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.read_word
//
// DESCRIPTION:
//    Read 1 word from cbuffer
//
// INPUTS:
//    - r0 = pointer to cbuffer struc
//
// OUTPUTS:
//    - r1 = word read from cbuffer
//
// TRASHED REGISTERS:
//    r2, I0, L0
//
// NOTES:
//    cbuffer is not checked to see if it is empty
//
// *****************************************************************************
.MODULE $M.cbuffer.read_word;
   .CODESEGMENT PM;

$cbuffer.read_word:
   r2 = M[r0 + $cbuffer.SIZE_FIELD];
   L0 = r2;
   r2 = M[r0 + $cbuffer.READ_ADDR_FIELD];
   I0 = r2;
   r1 = M[I0, 1];
   r2 = I0;
   M[r0 + $cbuffer.READ_ADDR_FIELD] = r2;
   L0 = 0;
   rts;
   
.ENDMODULE;






// *****************************************************************************
// MODULE:
//    $cbuffer.peek_word_at_offset
//
// DESCRIPTION:
//    Read 1 word from cbuffer at offset from read address without changing read
//    address
//
// INPUTS:
//    - r0 = pointer to cbuffer struc
//    - r1 = offset to read address
//
// OUTPUTS:
//    - r1 = word read from cbuffer
//
// TRASHED REGISTERS:
//    r2, I0, M0, L0
//
// NOTES:
//    cbuffer is not checked to see if it is empty
//
// *****************************************************************************
.MODULE $M.cbuffer.peek_word_at_offset;
   .CODESEGMENT PM;

$cbuffer.peek_word_at_offset:
   r2 = M[r0 + $cbuffer.SIZE_FIELD];
   L0 = r2;
   r2 = M[r0 + $cbuffer.READ_ADDR_FIELD];
   I0 = r2;
   M0 = r1;
   r1 = M[I0, M0];
   r1 = M[I0, 0];
   L0 = 0;
   rts;
   
.ENDMODULE;




// *****************************************************************************
// MODULE:
//    $cbuffer.update_word_at_offset
//
// DESCRIPTION:
//    Updates 1 word in cbuffer at offset from read address without changing
//    read address
//
// INPUTS:
//    - r0 = pointer to cbuffer struc
//    - r1 = offset to read address
//    - r2 = new value for the word
//
// OUTPUTS:
//    - None
//
// TRASHED REGISTERS:
//    r2, r3, I0, M0, L0
//
// NOTES:
//    cbuffer is not checked to see if it is empty
//
// *****************************************************************************
.MODULE $M.cbuffer.update_word_at_offset;
   .CODESEGMENT PM;

$cbuffer.update_word_at_offset:
   r3 = M[r0 + $cbuffer.SIZE_FIELD];
   L0 = r3;
   r3 = M[r0 + $cbuffer.READ_ADDR_FIELD];
   I0 = r3;
   M0 = r1;
   r1 = M[I0, M0];
   M[I0, 0] = r2;
   L0 = 0;
   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.sync_write
//
// DESCRIPTION:
//    Synchronise write address of secondary cbuffers to primary cbuffer
//
// INPUTS:
//    - r0 = pointer to NULL terminated array cbuffers
//
// OUTPUTS:
//    - r0 = address after NULL
//
// TRASHED REGISTERS:
//   r1, I0
//
// *****************************************************************************
.MODULE $M.cbuffer.sync_write;
   .CODESEGMENT PM;

$cbuffer.sync_write:
    I0 = r0;

    // get primary cbuffer write address
    r0 = M[I0, 1];
    r0 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
        
    sync_write_loop:
    
        // get secondary cbuffer, exit if 0
        r1 = M[I0, 1];
        Null = r1;
        if Z jump sync_write_exit;
            
        // copy write address to secondary cbuffer
        M[r1 + $cbuffer.WRITE_ADDR_FIELD] = r0;
        jump sync_write_loop;
            
sync_write_exit:

    // load r0 with address after NULL
    r0 = I0;
    rts;
            
.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $cbuffer.sync_write_from_read
//
// DESCRIPTION:
//    Synchronise write address of secondary cbuffers to primary cbuffer
//    read address
//
// INPUTS:
//    - r0 = pointer to NULL terminated array cbuffers
//
// OUTPUTS:
//    - r0 = address after NULL
//
// TRASHED REGISTERS:
//   r1, I0
//
// *****************************************************************************
.MODULE $M.cbuffer.sync_write_from_read;
   .CODESEGMENT PM;

$cbuffer.sync_write_from_read:
    I0 = r0;

    // get primary cbuffer read address
    r0 = M[I0, 1];
    r0 = M[r0 + $cbuffer.READ_ADDR_FIELD];
        
    sync_write_loop:
    
        // get secondary cbuffer, exit if 0
        r1 = M[I0, 1];
        Null = r1;
        if Z jump sync_write_exit;
            
        // copy write address to secondary cbuffer
        M[r1 + $cbuffer.WRITE_ADDR_FIELD] = r0;
        jump sync_write_loop;
            
sync_write_exit:

    // load r0 with address after NULL
    r0 = I0;
    rts;
            
.ENDMODULE;






// *****************************************************************************
// MODULE:
//    $cbuffer.sync_read
//
// DESCRIPTION:
//    Synchronise read address of primary cbuffer to secondary cbuffers.  The
//    read address of the primary cbuffer will be set to the read address of the
//    secondary cbuffer which is the furthest behind the primary cbuffer write
//    address.
//
// INPUTS:
//    - r0 = pointer to NULL terminated array cbuffers
//
// OUTPUTS:
//    - r0 - address after the NULL terminator
//
// TRASHED REGISTERS:
//   r1-r4, r1, I0
//
// *****************************************************************************
.MODULE $M.cbuffer.sync_read;
    .CODESEGMENT PM;

$cbuffer.sync_read:
    I0 = r0;

    // maximum of data in cbuffer
    r3 = 0;
        
    // get primary cbuffer write address
    r4 = M[I0, 1];
        
    sync_read_loop:
   
        // get secondary cbuffer, exit if 0
        r0 = M[I0, 1];
        Null = r0;
        if Z jump sync_read_exit;
            
        // calc amount of data between read and write
        r1 = M[r4 + $cbuffer.WRITE_ADDR_FIELD];
        r2 = M[r0 + $cbuffer.READ_ADDR_FIELD];
        r1 = r1 - r2;
        if POS jump sync_read_no_wrap;
            r2 = M[r4 + $cbuffer.SIZE_FIELD];
            r1 = r1 + r2;
   
    sync_read_no_wrap:
            
        // check if read address should be updated
        // The read address is always updated the first time round the loop
        Null = r1 - r3;
        if NEG jump sync_read_loop;
            
        // update primary cbuffer read address
        // r3 is set to r1+1 so that after the first loop r1 must exceed r3
        // for the read address to be updated
        r3 = r1 + 1;
        r0 = M[r0 + $cbuffer.READ_ADDR_FIELD];
        M[r4 + $cbuffer.READ_ADDR_FIELD] = r0;
            
        jump sync_read_loop;
            
sync_read_exit:

    // load r0 with address after NULL
    r0 = I0;
    rts;
    
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $cbuffer.write_block
//
// DESCRIPTION:
//    Write a block of data to a cbuffer
//    Only works on cbuffers
//
// INPUTS:
//    - r0 = pointer to cbuffer struct
//    - r1 = pointer to block of data
//    - r8 = length of data to copy
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//   r1, r2, r10, I4, I0, L0
//
// *****************************************************************************
.MODULE $M.cbuffer.write_block;
    .CODESEGMENT PM;

$cbuffer.write_block:
    r2 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
    I0 = r2;
    r2 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r2;

#ifdef DEBUG_ON
    // Test if cbuffer has enough space to complete the write
    r2 = M[r0 + $cbuffer.READ_ADDR_FIELD];
    I4 = r2;

    // calculate the amount of space
    I4 = I4 - I0;
    if LE I4 = I4 + L0;

    // always say it's 1 less so that buffer never gets totally filled up
    I4 = I4 - 1;
    I4 = I4 - r8;
    if GE jump cbuffer_write_block_start_proper;
    L0 = 0;
    call $error;
#endif
cbuffer_write_block_start_proper:
    I4 = r1;
    r10 = r8 - 1;
    r1 = M[I4,1];
    do write_block_loop;
        M[I0,1] = r1, r1 = M[I4,1];
    write_block_loop:
    M[I0,1] = r1;
    L0 = 0;
    // Update the write address
    r1 = I0;
    M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r1;
    rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.write_block_from_stack
//
// DESCRIPTION:
//    Reads data from the stack and writes to cbuffer
//    Only works on cbuffers
//
// INPUTS:
//    - r0 = pointer to cbuffer struct
//    - r8 = length of data to copy
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//   r1, r10, I0, L0
//
// *****************************************************************************
.MODULE $M.cbuffer.write_block_from_stack;
    .CODESEGMENT PM;

$cbuffer.write_block_from_stack:
    r1 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
    I0 = r1;
    r1 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r1;

#ifdef DEBUG_ON
    // Test if cbuffer has enough space to complete the write
    r1 = M[r0 + $cbuffer.READ_ADDR_FIELD];

    // calculate the amount of space
    r1 = r1 - I0;
    if LE r1 = r1 + L0;

    // always say it's 1 less so that buffer never gets totally filled up
    r1 = r1 - 1;
    r1 = r1 - r8;
    if GE jump cbuffer_write_block_from_stack_start_proper;
    L0 = 0;
    call $error;
#endif
cbuffer_write_block_from_stack_start_proper:
    r10 = r8;
    do write_block_loop;
        pop r1;
        M[I0,1] = r1;
    write_block_loop:
    L0 = 0;
    // Update the write address
    r1 = I0;
    M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r1;
    rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbuffer.read_block
//
// DESCRIPTION:
//    Read data from a cbuffer into a block of memory
//    Only works on cbuffers
//
// INPUTS:
//    - r0 = pointer to cbuffer struct
//    - r1 = pointer to block of data
//    - r8 = length of data to copy
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//   r2, r10, I4, I0, L0
//
// *****************************************************************************
.MODULE $M.cbuffer.read_block;
    .CODESEGMENT PM;
$cbuffer.read_block:
    r2 = M[r0 + $cbuffer.READ_ADDR_FIELD];
    I0 = r2;
    r2 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r2;
    I4 = r1;
    r10 = r8 - 1;
    r2 = M[I0,1];
    do read_block_loop;
        M[I4,1] = r2, r2 = M[I0,1];
    read_block_loop:
    M[I4,1] = r2;
    L0 = 0;
    // Update the read address
    r2 = I0;
    M[r0 + $cbuffer.READ_ADDR_FIELD] = r2;
    rts;
.ENDMODULE;




// *****************************************************************************
// MODULE:
//    $cbuffer.peek_block
//
// DESCRIPTION:
//    Read data from a cbuffer into a block of memory
//    The read pointer is not updated after the read
//    Only works on cbuffers
//
// INPUTS:
//    - r0 = pointer to cbuffer struct
//    - r1 = pointer to block of data
//    - r8 = length of data to copy
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//   r2, r10, I4, I0, L0
//
// *****************************************************************************
.MODULE $M.cbuffer.peek_block;
    .CODESEGMENT PM;
$cbuffer.peek_block:
    r2 = M[r0 + $cbuffer.READ_ADDR_FIELD];
    I0 = r2;
    r2 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r2;
    I4 = r1;
    r10 = r8 - 1;
    r2 = M[I0,1];
    do peek_block_loop;
        M[I4,1] = r2, r2 = M[I0,1];
    peek_block_loop:
    M[I4,1] = r2;
    L0 = 0;
    rts;
.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $cbuffer.move_pack_16
//
// DESCRIPTION:
//    Move data from one cbuffer at 8 bits per word to another cbuffer as 16
//    bits per word.
//
//    - r0 = pointer to source cbuffer struc (8 bits per word)
//    - r1 = pointer to destination cbuffer struc (16 bits per word)
//    - r2 = number of bytes to copy
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//   r3,r4,r10
//
// *****************************************************************************
.MODULE $M.cbuffer.move_pack_16;
    .CODESEGMENT PM;
$cbuffer.move_pack_16:
    r3 = M[r0 + $cbuffer.READ_ADDR_FIELD];
    I0 = r3;
    r3 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r3;
    r3 = M[r1 + $cbuffer.WRITE_ADDR_FIELD];
    I1 = r3;
    r3 = M[r1 + $cbuffer.SIZE_FIELD];
    L1 = r3;

    r10 = r2 LSHIFT -1;
    do move_loop;
        r3 = M[I0, 1];
        r3 = r3 LSHIFT 8;
        r4 = M[I0, 1];
        r3 = r3 OR r4;
        M[I1, 1] = r3;
    move_loop:

    Null = r2 AND 1;
    if Z jump no_byte;
       r3 = M[I0, 1];
       r3 = r3 LSHIFT 8;
       M[I1, 1] = r3;
    no_byte:
    
    r3 = I0;
    M[r0 + $cbuffer.READ_ADDR_FIELD] = r3;
    L0 = 0;
    r3 = I1;
    M[r1 + $cbuffer.WRITE_ADDR_FIELD] = r3;
    L1 = 0;    
    rts; 
.ENDMODULE;

//    - r0 = pointer to source cbuffer struc (8 bits per word)
//    - r1 = pointer to destination cbuffer struc (24 bits per word)
//    - r2 = number of bytes to copy
.MODULE $M.cbuffer.copy_packed_24;
    .CODESEGMENT PM;
$cbuffer.copy_packed_24:
.ENDMODULE;






// *****************************************************************************
// MODULE:
//    $cbuffer.diff_read
//
// DESCRIPTION:
//    Calculates the difference in the number of words read from 'before' to
//    'after'. Assumes the before and after cbuffer strucs are the same size.
//
// INPUTS:
//    - r0 = pointer to 'before' cbuffer struc
//    - r1 = pointer to 'after' cbuffer struc
//
// OUTPUTS:
//    - r0 = the number of words read from before to after
//
// TRASHED REGISTERS:
//   r0, r1, r2, r3
//
// *****************************************************************************
.MODULE $M.cbuffer.diff_read;
   .CODESEGMENT PM;
$cbuffer.diff_read:
$_cbuffer_diff_read:
   $push_rLink_macro;
   push r1;

#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_read_address_and_size_and_start_address;
   r3 = r0;
   pop r0;
   call $cbuffer.get_read_address_and_size_and_start_address;
#else
   call $cbuffer.get_read_address_and_size;
   r3 = r0;
   pop r0;
   call $cbuffer.get_read_address_and_size;
#endif
   r0 = r0 - r3;
   if NEG r0 = r0 + r1;

   jump $pop_rLink_and_rts;
.ENDMODULE;






// *****************************************************************************
// MODULE:
//    $cbuffer.diff_write
//
// DESCRIPTION:
//    Calculates the difference in the number of words written from 'before' to
//    'after'. Assumes the before and after cbuffer strucs are the same size.
//
// INPUTS:
//    - r0 = pointer to 'before' cbuffer struc
//    - r1 = pointer to 'after' cbuffer struc
//
// OUTPUTS:
//    - r0 = the number of words written from before to after
//
// TRASHED REGISTERS:
//   r0, r1, r2, r3
//
// *****************************************************************************
.MODULE $M.cbuffer.diff_write;
   .CODESEGMENT PM;
$cbuffer.diff_write:
$_cbuffer_diff_write:
   $push_rLink_macro;
   push r1;

#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   r3 = r0;
   pop r0;
   call $cbuffer.get_write_address_and_size_and_start_address;
#else
   call $cbuffer.get_write_address_and_size;
   r3 = r0;
   pop r0;
   call $cbuffer.get_write_address_and_size;
#endif
   r0 = r0 - r3;
   if NEG r0 = r0 + r1;

   jump $pop_rLink_and_rts;
.ENDMODULE;






#ifdef METADATA_SUPPORT
// *****************************************************************************
// MODULE:
//    $cbuffer.check_dmb_read_port
//
// DESCRIPTION:
//    Check DMB port for more metadata.  Copies metadata into cbuffer associated
//    with MMU port.  If no cbuffer metadata is thrown away.
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r1, r2  r3, r10, I0, L0, I4, L4
//
// *****************************************************************************
.MODULE $M.cbuffer_check_dmb_read_port;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
$cbuffer.check_dmb_read_port:

   // exit if no DMB read port configured
   r0 = M[$cbuffer.dmb_read_port];
   if Z rts;

   // push rLink onto stack
   $push_rLink_macro;

   // get amount of data in DMB read port
   call $cbuffer.calc_amount_data.its_a_port;
   r10 = r0;

   // get read address and size of DMB read port
   r0 = M[$cbuffer.dmb_read_port];
   call $cbuffer.get_read_address_and_size.its_a_port;
   I0 = r0;
   L0 = r1;

$cbuffer.check_dmb_read_port.loop:

   // exit loop if not enough data (left) in DMB port
   r10 = r10 - $cbuffer.DMB_PORT_HEADER_MIN_SIZE;
   if NEG jump $cbuffer.check_dmb_read_port.done;
    
   // read in port number, message length and type
   r3 = M[I0, 1];

   // jump if message
   Null = r3 AND $cbuffer.DMB_PORT_HEADER_MSG_MASK;
   if NZ jump $cbuffer.check_dmb_read_port.read_message;
     
   // metadata is 3 words, subtract 1 more from total size
   r10 = r10 - 1;
   if NEG call $error;

   // drop metadata if port is not connected
   r3 = r3 AND $cbuffer.DMB_PORT_HEADER_PORT_MASK;
   r0 = r3;
   call $cbuffer.is_it_enabled;
   if Z jump $cbuffer.check_dmb_read_port.drop_metadata;

   // check metadata cbuffer exists for this port
   r0 = M[$cbuffer.read_port_dmb_cbuffer + r3];
   if Z jump $cbuffer.check_dmb_read_port.drop_metadata;  
  
   // check there's enough space in cbuffer
   r0 = M[$cbuffer.read_port_dmb_cbuffer + r3];
   call $cbuffer.calc_amount_space;
   Null = r0 - $cbuffer.DMB_CBUFFER_HEADER_MIN_SIZE;

   // error if not enough space 
   if NEG call $error;
  
   // port is connected and has metadata cbuffer
   r0 = M[$cbuffer.read_port_dmb_cbuffer + r3];
   call $cbuffer.get_write_address_and_size;
   I4 = r0;
   L4 = r1;

   // copy msgfrag offset and length into cbuffer
   r0 = M[I0, 1];
   M[I4, 1] = r0, r0 = M[I0, 1];
   M[I4, 1] = r0;

   // update cbuffer write address
   r0 = M[$cbuffer.read_port_dmb_cbuffer + r3];
   r1 = I4;
   call $cbuffer.set_write_address;
   jump $cbuffer.check_dmb_read_port.loop;

$cbuffer.check_dmb_read_port.drop_metadata: 
   r0 = M[I0, 1];
   r0 = M[I0, 1];
   jump $cbuffer.check_dmb_read_port.loop;

$cbuffer.check_dmb_read_port.read_message:
   r0 = M[I0, 1];
   jump $cbuffer.check_dmb_read_port.loop;

$cbuffer.check_dmb_read_port.done: 

   // put length registers back to 0
   L0 = 0;
   L4 = 0;

   // don't call $cbuffer.set_read_adddress as we don't need to send a message
   // to the firmware.
   Null = M[$PORT_BUFFER_SET];
   jump $pop_rLink_and_rts;

.ENDMODULE;
#endif // METADATA_SUPPORT






#ifdef METADATA_SUPPORT
// *****************************************************************************
// MODULE:
//    $cbuffer.update_dmb_write_port
//
// DESCRIPTION:
//    Attempt to write more metadata to DMB port.
//
// INPUTS:
//    - r3 - mask of mmu ports to check
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r1, r2, r3, r4, r5, r6, r10, I0, L0, I4, L4
//
// *****************************************************************************
.MODULE $M.cbuffer_update_dmb_write_port;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$cbuffer.update_dmb_write_port:

   // exit if no DMB write port configured
   Null = M[$cbuffer.dmb_write_port];
   if Z rts;

   // push rLink onto stack
   $push_rLink_macro;

   // get write address and size of DMB write port
   r0 = M[$cbuffer.dmb_write_port];
   call $cbuffer.get_write_address_and_size.its_a_port;
   I0 = r0;
   L0 = r1;

   // set to zero, will be non zero on exit of loop if any metadata was copied
   I4 = 0;

   // block interrupts in case message service routine fires
   $block_interrupts_macro;

   // get amount of space in DMB write port
   r0 = M[$cbuffer.dmb_write_port];
   call $cbuffer.calc_amount_space.its_a_port;
   r10 = r0 - $cbuffer.DMB_PORT_HEADER_STD_SIZE;
   if NEG jump $cbuffer.update_dmb_write_port.done;   

$cbuffer.update_dmb_write_port.loop:

   // get highest port in mask
   r4 = SIGNDET r3;
#ifdef KAL_ARCH4
   r4 = 30 - r4;
#else
   r4 = 22 - r4;
#endif
   if NEG jump $cbuffer.update_dmb_write_port.done;
   
   // clear highest port bit in mask 
   r0 = 1 LSHIFT r4;
   r3 = r3 XOR r0;

#ifdef DEBUG_ON
   // check DMB cbuffer is associated with this write port
   Null = M[$cbuffer.write_port_dmb_cbuffer + r4];
   if Z call $error;
#endif

   // get amount of metadata in DMB cbuffer
   r0 = M[$cbuffer.write_port_dmb_cbuffer + r4];
   call $cbuffer.calc_amount_data;

   // jump back to try next port if there's not enough metadata
   r6 = r0 - $cbuffer.DMB_CBUFFER_HEADER_MIN_SIZE;
   if NEG jump $cbuffer.update_dmb_write_port.loop;
   
   // get read address and size of DMB cbuffer
   r0 = M[$cbuffer.write_port_dmb_cbuffer + r4];
   call $cbuffer.get_read_address_and_size;
   I4 = r0;
   L4 = r1;

$cbuffer.update_dmb_write_port.port_loop:
  
   // write port number, offset, length
   r0 = r4 + $cbuffer.DMB_PORT_HEADER_WORD;  
   M[I0, 1] = r0, r1 = M[I4, 1];             
   M[I0, 1] = r1, r0 = M[I4, 1];
   M[I0, 1] = r0;

   // check space in DMB write port
   r10 = r10 - $cbuffer.DMB_PORT_HEADER_STD_SIZE;
   if NEG jump $cbuffer.update_dmb_write_port.port_full;

   // exit loop if we've run out of metadata in DMB cbuffer
   r6 = r6 - $cbuffer.DMB_CBUFFER_HEADER_MIN_SIZE;
   if POS jump $cbuffer.update_dmb_write_port.port_loop;

$cbuffer.update_dmb_write_port.port_full:

   // update cbuffer read address
   r0 = M[$cbuffer.write_port_dmb_cbuffer + r4];
   r1 = I4;
   call $cbuffer.set_read_address;
   L4 = 0;

$cbuffer.update_dmb_write_port.done:

   // unblock interrupt now we have finished writing to DMB port
   $unblock_interrupts_macro;

   Null = I4;
   if Z jump $pop_rLink_and_rts;

   // set write address of DMB write port
   r0 = M[$cbuffer.dmb_write_port];
   r1 = I0;
   L0 = 0;
   call $cbuffer.set_write_address.its_a_port;
   jump $pop_rLink_and_rts;

.ENDMODULE;
#endif // METADATA_SUPPORT






#ifdef METADATA_SUPPORT
// *****************************************************************************
// MODULE:
//    $cbuffer.register_metadata_cbuffer
//
// DESCRIPTION:
//    Registers a cbuffer for MMU port metadata.
//
// INPUTS:
//    - r0 = port
//    - r1 = cbuffer
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0, r1
//
// *****************************************************************************
.MODULE $M.cbuffer_register_metadata_cbuffer;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
$cbuffer.register_metadata_cbuffer:

   Null = SIGNDET r0;
   if NZ call $error;

   r0 = r0 AND $cbuffer.TOTAL_PORT_NUMBER_MASK;
   M[$cbuffer.port_dmb_cbuffer + r0] = r1;

   // get write port number, exit if read port
   r0 = r0 - $cbuffer.NUM_PORTS;
   if NEG rts;

   // convert port number into mask
   r0 = 1 LSHIFT r0;

   // jump if unregistering cbuffer
   Null = r1;
   if Z jump unregister_cbuffer;

       // register cbuffer, set bit in write ports mask
       r1 = M[$cbuffer.dmb_write_ports_mask];
       r1 = r1 OR r0;
       M[$cbuffer.dmb_write_ports_mask] = r1;
       rts;

   unregister_cbuffer:

       // unregister cbuffer, clear bit in write ports mask
       r0 = r0 XOR $cbuffer.TOTAL_PORT_NUMBER_MASK;
       r1 = M[$cbuffer.dmb_write_ports_mask];
       r1 = r1 AND r0;
       M[$cbuffer.dmb_write_ports_mask] = r1;
       rts;

.ENDMODULE;
#endif // METADATA_SUPPORT

#endif // CBUFFER_INCLUDED



    
    
