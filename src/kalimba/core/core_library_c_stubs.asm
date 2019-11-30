// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// C stubs for "core" library
// These obey the C compiler calling convention (see documentation)
// Comments show the syntax to call the routine also see matching header file

#include "stack.h"


// C stubs for "core" library
// These obey the C compiler calling convention (see documentation)
// Comments show the syntax to call the routine also see matching header file


// *****************************************************************************
// Interrupt.asm
// *****************************************************************************
.MODULE $M.core_c_stubs.interrupt_initialise;
   .CODESEGMENT CORE_C_STUBS_INTERRUPT_INITIALISE_PM;

   // interrupt_initialise();
   $_interrupt_initialise:
   jump $interrupt.initialise;

.ENDMODULE;

.MODULE $M.core_c_stubs.interrupt_block;
   .CODESEGMENT CORE_C_STUBS_INTERRUPT_BLOCK_PM;

   // block_interrupts(); or interrupt_block();
   $_block_interrupts:
   $_interrupt_block:
   jump $interrupt.block;

.ENDMODULE;

.MODULE $M.core_c_stubs.interrupt_unblock;
   .CODESEGMENT CORE_C_STUBS_INTERRUPT_UNBLOCK_PM;

   // unblock_interrupts(); or interrupt_unblock();
   $_unblock_interrupts:
   $_interrupt_unblock:
   jump $interrupt.unblock;

.ENDMODULE;

.MODULE $M.core_c_stubs.interrupt_register;
   .CODESEGMENT CORE_C_STUBS_INTERRUPT_REGISTER_PM;

   // interrupt_register(int int_source, int int_priority, tIntFunction IntFunction);
   $_interrupt_register:
   pushm <r5, rLink>;

   call $interrupt.register;

   popm <r5, rLink>;
   rts;

.ENDMODULE;

// *****************************************************************************
// Timer.asm
// *****************************************************************************
.MODULE $M.core_c_stubs.timer_schedule_event_at;
   .CODESEGMENT CORE_C_STUBS_TIMER_SCHEDULE_EVENT_AT_PM;

   // timer_schedule_event_at(tTimerStruct * pTimerStruc, unsigned int time_absolute, tTimerEventFunction TimerEventFunction)
   $_timer_schedule_event_at:
   pushm <r4, r5, rLink>;
   r3 = r2;
   r2 = r1;
   r1 = r0;
   call $timer.schedule_event_at;
   popm <r4, r5, rLink>;
   r0 = r3;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.timer_schedule_event_in;
   .CODESEGMENT CORE_C_STUBS_TIMER_SCHEDULE_EVENT_IN_PM;

   // timer_schedule_event_in(tTimerStruct * pTimerStruc, int time_in, tTimerEventFunction TimerEventFunction);
   $_timer_schedule_event_in:
   pushm <r4, r5, rLink>;
   r3 = r2;
   r2 = r1;
   r1 = r0;
   call $timer.schedule_event_in;
   popm <r4, r5, rLink>;
   r0 = r3;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.timer_schedule_event_in_period;
   .CODESEGMENT CORE_C_STUBS_TIMER_SCHEDULE_EVENT_IN_PERIOD_PM;

   // timer_schedule_event_in_period(tTimerStruct * pTimerStruc, int time_period, tTimerEventFunction TimerEventFunction);
   $_timer_schedule_event_in_period:
   pushm <r4, r5, rLink>;
   r3 = r2;
   r2 = r1;
   r1 = r0;
   call $timer.schedule_event_in_period;
   popm <r4, r5, rLink>;
   r0 = r3;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.timer_cancel_event;
   .CODESEGMENT CORE_C_STUBS_TIMER_CANCEL_EVENT_PM;

   // timer_cancel_event(int event_id);
   $_timer_cancel_event:
   pushm <r4, r5, rLink>;
   r2 = r0;
   call $timer.cancel_event;
   popm <r4, r5, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.timer_1ms_delay;
   .CODESEGMENT CORE_C_STUBS_TIMER_1MS_DELAY_PM;

   // timer_1ms_delay();
   $_timer_1ms_delay:
   jump $timer.1ms_delay;

.ENDMODULE;

.MODULE $M.core_c_stubs.timer_n_ms_delay;
   .CODESEGMENT CORE_C_STUBS_TIMER_N_MS_DELAY_PM;

   // timer_n_ms_delay(int delay_duration_ms);
   $_timer_n_ms_delay:
   jump $timer.n_ms_delay;

.ENDMODULE;

.MODULE $M.core_c_stubs.timer_n_us_delay;
   .CODESEGMENT CORE_C_STUBS_TIMER_N_US_DELAY_PM;

   // timer_n_us_delay(int delay_duration_us);
   $_timer_n_us_delay:
   jump $timer.n_us_delay;

.ENDMODULE;

.MODULE $M.core_c_stubs.timer_time_get;
    .CODESEGMENT CORE_C_STUBS_TIMER_TIME_GET_PM;
    // int timer_time_get(void)
    $_timer_time_get:
    r0 = M[$TIMER_TIME];
    rts;
.ENDMODULE;

// *****************************************************************************
// wall_clock.asm / wall_clock_csb.asm
// *****************************************************************************
.MODULE $M.core_c_stubs.wall_clock_get_time;
    .CODESEGMENT CORE_C_STUBS_WALL_CLOCK_GET_TIME_PM;
    // int wall_clock_get_time(int *wall_clock_struc)
    $_wall_clock_get_time:
    push rLink;
    r1 = r0;
    call $wall_clock.get_time;
    r0 = r1;
    pop rLink;
    rts;
.ENDMODULE;

.MODULE $M.core_c_stubs.wall_clock_csb_get_time;
    .CODESEGMENT CORE_C_STUBS_WALL_CLOCK_CSB_GET_TIME_PM;
    // int wall_clock_csb_get_time(int *wall_clock_csb_struc)
    $_wall_clock_csb_get_time:
    push rLink;
    r1 = r0;
    call $wall_clock_csb.get_time;
    r0 = r1;
    pop rLink;
    rts;
.ENDMODULE;

// *****************************************************************************
// Cbuffer.asm
// *****************************************************************************
.MODULE $M.core_c_stubs.cbuffer_initialise;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_INITIALISE_PM;

   // cbuffer_initialise();
   $_cbuffer_initialise:
   jump $cbuffer.initialise;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_is_it_enabled;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_IS_IT_ENABLED_PM;

   // cbuffer_is_it_enabled(tCbuffer * cbuffer);
   $_cbuffer_is_it_enabled:
   push rLink;
   // assume the port is enabled
   r1 = 1;
   call $cbuffer.is_it_enabled;
   // the flags are set, so we just need to test them
   if Z r1 = 0;
   r0 = r1;
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_get_read_address_and_size;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_GET_READ_ADDRESS_AND_SIZE_PM;

   // cbuffer_get_read_address_and_size(tCbuffer * cbuffer, int ** read_address, int * buffer_size);
   $_cbuffer_get_read_address_and_size:
   push rLink;
   // save r1 (read_address), r2 (buffer_size) is not trashed
   r3 = r1;
   call $cbuffer.get_read_address_and_size;
   M[r3] = r0;       // pointer to read_address
   M[r2] = r1;       // pointer to buffer_size
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_get_write_address_and_size;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_GET_WRITE_ADDRESS_AND_SIZE_PM;

   // cbuffer_get_write_address_and_size(tCbuffer * cbuffer, int ** write_address, int * buffer_size);
   $_cbuffer_get_write_address_and_size:
   push rLink;
   // save r1 (write_address), r2 (buffer_size) is not trashed
   r3 = r1;
   call $cbuffer.get_write_address_and_size;
   M[r3] = r0;       // pointer to write_address
   M[r2] = r1;       // pointer to buffer_size
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_set_read_address;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_SET_READ_ADDRESS_PM;

   // cbuffer_set_read_address(tCbuffer * cbuffer, int * read_address);
   $_cbuffer_set_read_address:
   pushm <r4, r5, r6, rLink>;
   call $cbuffer.set_read_address;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_set_write_address;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_SET_WRITE_ADDRESS_PM;

   // cbuffer_set_write_address(tCbuffer * cbuffer, int * write_address);
   $_cbuffer_set_write_address:
   pushm <r4, r5, rLink>;
   call $cbuffer.set_write_address;
   popm <r4, r5, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_calc_amount_space;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_CALC_AMOUNT_SPACE_PM;

   // cbuffer_calc_amount_space(tCbuffer * cbuffer, int * buffer_size);
   $_cbuffer_calc_amount_space:
   push rLink;
   r3 = r1;
   call $cbuffer.calc_amount_space;
   Null = r3; // @todo Change this to use a definition of C NUL
   if NZ M[r3] = r2;
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_calc_amount_data;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_CALC_AMOUNT_DATA_PM;

   // cbuffer_calc_amount_data(tCbuffer * cbuffer, int * buffer_size);
   $_cbuffer_calc_amount_data:
   push rLink;
   r3 = r1;
   call $cbuffer.calc_amount_data;
   Null = r3; // @todo Change this to use a definition of C NULL
   if NZ M[r3] = r2;
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_buffer_configure;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_BUFFER_CONFIGURE_PM;

   // cbuffer_buffer_configure(tCbuffer * cbuffer, int * buffer_start, int buffer_size);
   $_cbuffer_buffer_configure:
   jump $cbuffer.buffer_configure;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_force_mmu_set;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_FORCE_MMU_SET_PM;

   // cbuffer_force_mmu_set(void);
   $_cbuffer_force_mmu_set:
   jump $cbuffer.force_mmu_set;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_empty_buffer;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_EMPTY_BUFFER_PM;

   // cbuffer_empty_buffer(tCbuffer * cbuffer);
   $_cbuffer_empty_buffer:
   pushm <r4, r5, r6, rLink>;
   call $cbuffer.empty_buffer;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_fill_buffer;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_FILL_BUFFER_PM;

   // cbuffer_fill_buffer(tCbuffer * cbuffer, int value);
   $_cbuffer_fill_buffer:
   pushm <r4, r5, r6, rLink>;
   call $cbuffer.fill_buffer;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_advance_read_ptr;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_ADVANCE_READ_PTR_PM;

   // cbuffer_advance_read_ptr(tCbuffer * cbuffer, int amount);
   $_cbuffer_advance_read_ptr:
   push rLink;
   pushm <I0, M3>;
   r10 = r1;
   call $cbuffer.advance_read_ptr;
   popm <I0, M3>;
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_advance_write_ptr;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_ADVANCE_WRITE_PTR_PM;

   // cbuffer_advance_write_ptr(tCbuffer * cbuffer, int amount);
   $_cbuffer_advance_write_ptr:
   push rLink;
   pushm <I0, M3>;
   r10 = r1;
   call $cbuffer.advance_write_ptr;
   popm <I0, M3>;
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_set_read_port_connect_callback;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_SET_READ_PORT_CONNECT_CALLBACK_PM;

   // cbuffer_set_read_port_connect_callback(tCbufferPortCallback callback);
   $_cbuffer_set_read_port_connect_callback:
   M[$cbuffer.read_port_connect_address] = r0;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_set_read_port_disconnect_callback;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_SET_READ_PORT_DISCONNECT_CALLBACK_PM;

   // cbuffer_set_read_port_disconnect_callback(tCbufferPortCallback callback);
   $_cbuffer_set_read_port_disconnect_callback:
   M[$cbuffer.read_port_disconnect_address] = r0;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_set_write_port_connect_callback;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_SET_WRITE_PORT_CONNECT_CALLBACK_PM;

   // cbuffer_set_write_port_connect_callback(tCbufferPortCallback callback);
   $_cbuffer_set_write_port_connect_callback:
   M[$cbuffer.write_port_connect_address] = r0;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_set_write_port_disconnect_callback;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_SET_WRITE_PORT_DISCONNECT_CALLBACK_PM;

   // cbuffer_set_write_port_disconnect_callback(tCbufferPortCallback callback);
   $_cbuffer_set_write_port_disconnect_callback:
   M[$cbuffer.write_port_disconnect_address] = r0;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_read;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_READ_PM;

   // cbuffer_read(tCbuffer * cbuffer, int * buffer, int size);
   $_cbuffer_read:
   pushm <r4, rLink>;
   push I0;
   // save the information that will get trashed, use scratch registers rather than stack where possible
   I3 = r0;
   I7 = r1;
   r4 = r2;
   call $cbuffer.calc_amount_data;
   Null = r4 - r0;
   if POS r4 = r0;
   // load r10, but decrement for the read we do outside the loop
   r10 = r4 - 1;
   // check there is something to do
   if NEG jump done;

   // get the read pointer and size, reloading the buffer pointer
   r0 = I3;
   call $cbuffer.get_read_address_and_size;
   I0 = r0;
   L0 = r1;
   r0 = M[I0, M1];
   do rd_loop;
      r0 = M[I0, M1], M[I7, M1] = r0;
   rd_loop:
   M[I7, M1] = r0;
   // update the buffer structure, getting saved values
   r0 = I3;
   r1 = I0;
   call $cbuffer.set_read_address;
   L0 = 0;
   done:
   pop I0;
   // finally say how much we copied
   r0 = r4;
   popm <r4, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_read_from_address;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_READ_FROM_ADDRESS_PM;
// void *cbuffer_read_from_address(tCbuffer *cbuffer, void *buffer_ptr, void *read_ptr, int size)
$_cbuffer_read_from_address:
    pushm <I0, I4, L0, L4>;
    I0 = r2;
    r2 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r2;
    I4 = r1;
    L4 = 0;
    r10 = r3 - 1;
    r2 = M[I0,1];
    do read_block_loop;
        M[I4,1] = r2, r2 = M[I0,1];
    read_block_loop:
    M[I4,1] = r2;
    r0 = I0;
    L0 = 0;
    popm <I0, I4, L0, L4>;
    rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_write;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_WRITE_PM;
   // cbuffer_write(tCbuffer * cbuffer, int * buffer, int size);
   $_cbuffer_write:
   pushm <r4, rLink>;
   push I0;
   // save the information that will get trashed, use scratch registers rather than stack where possible
   I3 = r0;
   I7 = r1;
   r4 = r2;
   call $cbuffer.calc_amount_space;
   Null = r4 - r0;
   if POS r4 = r0;
   // load r10, but decrement for the read we do outside the loop
   r10 = r4 - 1;
   // check there is something to do
   if NEG jump done;

   // get the write pointer and size, reloading the buffer pointer
   r0 = I3;
   call $cbuffer.get_write_address_and_size;
   I0 = r0;
   L0 = r1;
   r0 = M[I7, M1];
   do wr_loop;
      r0 = M[I7, M1], M[I0, M1] = r0;
   wr_loop:
   M[I0, M1] = r0;
   // finally update the buffer structure, getting saved values
   r0 = I3;
   r1 = I0;
   call $cbuffer.set_write_address;
   L0 = 0;
   done:
   pop I0;
   // finally say how much we copied
   r0 = r4;
   popm <r4, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_sync_read;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_SYNC_READ_PM;
// tCbuffer* cbuffer_sync_read(tCbuffer *cbuffer[]);
$_cbuffer_sync_read:
    push rLink;
    push r4;
    push I0;
    call $cbuffer.sync_read;
    pop I0;
    pop r4;
    pop rLink;
    rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_update_word_at_offset;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_UPDATE_WORD_AT_OFFSET_PM;
//void cbuffer_update_word_at_offset(tCbuffer *cbuffer, int offset, int value);
$_cbuffer_update_word_at_offset:
    push rLink;
    pushm <I0, M0, L0>;
    call $cbuffer.update_word_at_offset;
    popm <I0, M0, L0>;
    pop rLink;
    rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_peek_block;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_PEEK_BLOCK_PM;
// void cbuffer_peek_block(tCbuffer *cbuffer, void *data, size_t size);
$_cbuffer_peek_block:
    push rLink;
    pushm <I0, I4, L0>;
    pushm <r8, r10>;
    r8 = r2;
    call $cbuffer.peek_block;
    popm <r8, r10>;
    popm <I0, I4, L0>;
    pop rLink;
    rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_get_size;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_GET_SIZE_PM;
// int cbuffer_get_size (tCbuffer *cbuffer);
$_cbuffer_get_size:
    push rLink;
    call $cbuffer.calc_amount_space;
    r0 = r2;
    pop rLink;
    rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_buffer_to_buffer;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_BUFFER_TO_BUFFER_PM;

   // cbuffer_buffer_to_buffer(tCbuffer * input, tCbuffer * output)
   $_cbuffer_buffer_to_buffer:
   push rLink;
   pushm <I0, I4>;
   // save the buffer structures
   I3 = r0;
   I7 = r1;

   // r0 set
   call $cbuffer.calc_amount_data;
   r3 = r0;
   r0 = I7;
   call $cbuffer.calc_amount_space;
   Null = r3 - r0;
   if POS r3 = r0;
   // load into r10 and decrement
   r10 = r3 - 1;
   if NEG jump done;

   // now go through getting the read and write pointers
   r0 = I3;
   call $cbuffer.get_read_address_and_size;
   I0 = r0;
   L0 = r1;
   r0 = I7;
   call $cbuffer.get_write_address_and_size;
   I4 = r0;
   L4 = r1;

   // do the copy, remember first read/last write outside the loop
   r0 = M[I0, M1];
   do copy_loop;
      r0 = M[I0, M1], M[I4, M1] = r0;
   copy_loop:
   M[I4, M1] = r0;

   // update buffer structures
   r0 = I3;
   r1 = I0;
   call $cbuffer.set_read_address;
   L0 = 0;
   r0 = I7;
   r1 = I4;
   call $cbuffer.set_write_address;
   L4 = 0;

   done:
   popm <I0, I4>;
   // finally say how much we copied
   r0 = r3;
   jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
.MODULE $M.core_c_stubs.cbuffer_move_pack_16;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_MOVE_PACK_16_PM;
$_cbuffer_move_pack_16:
    push rLink;
    pushm <I0, I1, L0, L1>;
    pushm <r4, r10>;
    call $cbuffer.move_pack_16;
    popm <r4, r10>;
    popm <I0, I1, L0, L1>;
    pop rLink;
    rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.cbuffer_advance_address;
   .CODESEGMENT CORE_C_STUBS_CBUFFER_ADVANCE_ADDRESS_PM;
// void *cbuffer_advance_address(tCbuffer *cbuffer, void *address, size_t size)
$_cbuffer_advance_address:
    pushm <I0, M3, L0>;
    I0 = r1;
    r1 = M[r0 + $cbuffer.SIZE_FIELD];
    L0 = r1;
    M3 = r2;
    r0 = M[I0, M3];
    r0 = I0;
    popm <I0, M3, L0>;
    rts;

.ENDMODULE;

// Message.asm
// *****************************************************************************
.MODULE $M.core_c_stubs.message_initialise;
   .CODESEGMENT CORE_C_STUBS_MESSAGE_INITIALISE_PM;

   // message_initialise();
   $_message_initialise:
   jump $message.initialise;

.ENDMODULE;

.MODULE $M.core_c_stubs.message_register_handler;
   .CODESEGMENT CORE_C_STUBS_MESSAGE_REGISTER_HANDLER_PM;
   // message_register_handler(tMessageStruct * message_struc, int message_id, MessageEventFunction message_function)
   $_message_register_handler:
   r3 = r2;
   r2 = r1;
   r1 = r0;
   jump $message.register_handler;

.ENDMODULE;

.MODULE $M.core_c_stubs.message_register_handler_with_mask;
   .CODESEGMENT CORE_C_STUBS_MESSAGE_REGISTER_HANDLER_WITH_MASK_PM;

   // message_register_handler_with_mask(tMessageStruct * message_struc, int message_id, MessageEventFunction message_function, int message_mask)
   $_message_register_handler_with_mask:
   pushm <r4, rLink>;
   r4 = r3;
   r3 = r2;
   r2 = r1;
   r1 = r0;
   call $message.register_handler_with_mask;
   popm <r4, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.message_send_ready_wait_for_go;
   .CODESEGMENT CORE_C_STUBS_MESSAGE_SEND_READY_WAIT_FOR_GO_PM;

   // message_send_ready_wait_for_go();
   $_message_send_ready_wait_for_go:
   pushm <r4, r5, r6, rLink>;
   call $message.send_ready_wait_for_go;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;


.MODULE $M.core_c_stubs.message_send_short;
   .CODESEGMENT CORE_C_STUBS_MESSAGE_SEND_SHORT_PM;

   // message_send_short(int message_id, int p0, int p1, int p2, int p3);
   $_message_send_short:
   pushm <r4, r5, r6, rLink>;
   r6 = M[SP - 5];
   r5 = r3;
   r4 = r2;
   r3 = r1;
   r2 = r0;
   call $message.send_short;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.message_send_long;
   .CODESEGMENT CORE_C_STUBS_MESSAGE_SEND_LONG_PM;

   // message_send_long(int message_id, int msg_size, int * msg_payload);
   $_message_send_long:
   pushm <r4, r5, r6, rLink>;
   r3 = r0;
   r4 = r1;
   r5 = r2;
   call $message.send_long;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;


.MODULE $M.core_c_stubs.message_send_queue_space;
   .CODESEGMENT CORE_C_STUBS_MESSAGE_SEND_QUEUE_SPACE_PM;

   // int message_send_queue_space(void)
   $_message_send_queue_space:
   jump $message.send_queue_space;

.ENDMODULE;


.MODULE $M.core_c_stubs.message_send_queue_fullness;
   .CODESEGMENT CORE_C_STUBS_MESSAGE_SEND_QUEUE_FULLNESS_PM;

   // int message_send_queue_fullness(void)
   $_message_send_queue_fullness:
   jump $message.send_queue_fullness;

.ENDMODULE;


.MODULE $M.core_c_stubs.pskey_initialise;
   .CODESEGMENT CORE_C_STUBS_PSKEY_INITIALISE_PM;

   // pskey_initialise();
   $_pskey_initialise:
   jump $pskey.initialise;

.ENDMODULE;

.MODULE $M.core_c_stubs.pskey_read_key;
   .CODESEGMENT CORE_C_STUBS_PSKEY_READ_KEY_PM;

   // pskey_read_key(tPSKeyStruct * message_handler_struc_ptr, int message_id, tPsKeyEventFunction pskey_function);
   $_pskey_read_key:
   pushm <r4, r5, r6, rLink>;
   r3 = r2;
   r2 = r1;
   r1 = r0;
   call $pskey.read_key;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.flash_map_page_into_dm;
   .CODESEGMENT CORE_C_STUBS_FLASH_MAP_PAGE_INTO_DM_PM;

   // int * flash_map_page_into_dm(int * variable_segment_address, int * variable_size, int * segment_address);
   $_flash_map_page_into_dm:
   push rLink;
   r10 = r1;
   call $flash.map_page_into_dm;
   Null = r10 - FLASH_NULL;
   if Z jump $pop_rLink_and_rts;
   M[r10] = r1;
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.flash_copy_to_dm;
   .CODESEGMENT CORE_C_STUBS_FLASH_COPY_TO_DM_PM;

   // int flash_copy_to_dm(int * variable_segment_address, int variable_size, int * segment_address, int ** dest_addr);
   $_flash_copy_to_dm:
   pushm <r3, r4, r5, rLink>;
   pushm <I0, I1>;
   r3 = M[r3];
   I0 = r3;
   call $flash.copy_to_dm;
   r1 = I0;
   popm <I0, I1>;
   popm <r3, r4, r5, rLink>;
   M[r3] = r1;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.flash_copy_to_dm_32_to_24;
   .CODESEGMENT CORE_C_STUBS_FLASH_COPY_TO_DM_32_TO_24_PM;

   // flash_copy_to_dm_32_to_24(int * variable_segment_address, int variable_size, int * segment_address, int ** dest_addr);
   $_flash_copy_to_dm_32_to_24:
   pushm <r3, r4, r5, rLink>;
   pushm <I0, I1>;
   r3 = M[r3];
   I0 = r3;
   call $flash.copy_to_dm_32_to_24;
   r1 = I0;
   popm <I0, I1>;
   popm <r3, r4, r5, rLink>;
   M[r3] = r1;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.flash_copy_to_dm_24;
   .CODESEGMENT CORE_C_STUBS_FLASH_COPY_TO_DM_24;

   // flash_copy_to_dm_24(int * variable_segment_address, int variable_size, int * segment_address, int ** dest_addr);
   $_flash_copy_to_dm_24:
   pushm <r3, r4, r5, rLink>;
   pushm <I0, I1>;
   r3 = M[r3];
   I0 = r3;
   call $flash.copy_to_dm_24;
   r1 = I0;
   popm <I0, I1>;
   popm <r3, r4, r5, rLink>;
   M[r3] = r1;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.flash_get_file_address;
   .CODESEGMENT CORE_C_STUBS_FLASH_GET_FILE_ADDRESS_PM;

   // flash_get_file_address(tFileAddressStruct * file_address_structure, unsigned int file_id, tFileAddressFunction FileAddressFunction);
   $_flash_get_file_address:
   pushm <r4, r5, r6, rLink>;
   r3 = r2;
   r2 = r1;
   r1 = r0;
   call $flash.get_file_address;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.fwrandom_initialise;
   .CODESEGMENT CORE_C_STUBS_FWRANDOM_INITIALISE_PM;

   // void fwrandom_initialise(void);
   $_fwrandom_initialise:
   jump $fwrandom.initialise;

.ENDMODULE;


.MODULE $M.core_c_stubs.fwrandom_get_rand_bits;
   .CODESEGMENT CORE_C_STUBS_FWRANDOM_GET_RAND_BITS_PM;

   // void fwrandom_get_rand_bits(tFwRandomNumberStruct * fw_random_number_structure, int num_bits, tFwRandomNumberFunction FwRandomNumberFunction, int * buffer);
   $_fwrandom_get_rand_bits:
   pushm <r4, r5, r6, rLink>;
   r4 = r3;
   r3 = r2;
   r2 = r1;
   r1 = r0;
   call $fwrandom.get_rand_bits;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.pio_initialise;
   .CODESEGMENT CORE_C_STUBS_PIO_INITIALISE_PM;

   // void pio_initialise(void);
   $_pio_initialise:
   jump $pio.initialise;

.ENDMODULE;

.MODULE $M.core_c_stubs.pio_register_handler;
   .CODESEGMENT CORE_C_STUBS_PIO_REGISTER_HANDLER_PM;

   // void pio_register_handler(tPioStruct * pio_structure, unsigned int pio_bitmask, unsigned int pio2_bitmask, unsigned int pio3_bitmask, tPioFunction PioFunction);
   $_pio_register_handler:
   pushm <r4, r5, rLink>;
   r4 = M[SP - 4];
   call $pio.register_handler;
   popm <r4, r5, rLink>;
   rts;

.ENDMODULE;

.MODULE $M.core_c_stubs.kalimba_error;
   .CODESEGMENT CORE_C_STUBS_KALIMBA_ERROR_PM;

   // kalimba_error(void)
   // panic(void)
   $_kalimba_error:
   $_panic:
   jump $error;

.ENDMODULE;

