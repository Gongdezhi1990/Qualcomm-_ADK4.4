// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// Header file for C stubs of "core" library
// Comments show the syntax to call the routine

#if !defined(CORE_LIBRARY_C_STUBS_H)
#define CORE_LIBRARY_C_STUBS_H

#include "cbuffer_defines.h"
#include "flash_defines.h"
#include "fwrandom_defines.h"
#include "message_defines.h"
#include "pskey_defines.h"
#include <stdlib.h>

/* **************************************************************************
                              -- interrupt --
   **************************************************************************/

/* PUBLIC TYPES DEFINITIONS *************************************************/
typedef void (* tIntFunction)(void);

/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
void interrupt_initialise(void);
void interrupt_block(void);
void interrupt_unblock(void);
void interrupt_register(int int_source, int int_priority, tIntFunction IntFunction);


/* **************************************************************************
                                -- timer --
   **************************************************************************/

/* PUBLIC TYPES DEFINITIONS *************************************************/
typedef struct tTimerStuctTag tTimerStruct;

typedef void (* tTimerEventFunction)(int timer_id, tTimerStruct * timerStruc);

struct tTimerStuctTag
{
    struct tTimerStuctTag * next;
    unsigned int            time;
    tTimerEventFunction     timerEventFunction;
    int                     id;
};

/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
int timer_schedule_event_at(tTimerStruct * pTimerStruc, unsigned int time_absolute, tTimerEventFunction TimerEventFunction);
int timer_schedule_event_in(tTimerStruct * pTimerStruc, int time_in, tTimerEventFunction TimerEventFunction);
int timer_schedule_event_in_period(tTimerStruct * pTimerStruc, int time_period, tTimerEventFunction TimerEventFunction);
void timer_cancel_event(int timer_id);
void timer_1ms_delay(void);
void timer_n_ms_delay(int delay_duration_ms);
void timer_n_us_delay(int delay_duration_us);
int timer_time_get(void);


/* **************************************************************************
                                -- cbuffer --
   **************************************************************************/

/* PUBLIC TYPES DEFINITIONS *************************************************/
typedef void (* tCbufferPortCallback)(int status, int port_num);
/* Application should never use priv_tCbuffer, always use tCbuffer. The contents
 * of the structures should never be accessed directly. Always use the accessor
 * functions defined below. */
typedef struct
{
    int   size;
    int * read_ptr;
    int * write_ptr;
#ifdef BASE_REGISTER_MODE
    int * base;
#endif
} private_tCbuffer;

typedef struct { char _DO_NOT_USE[sizeof(private_tCbuffer)]; } tCbuffer;
typedef tCbuffer cbuffer_t;


/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
void cbuffer_initialise(void);
int cbuffer_is_it_enabled(tCbuffer * cbuffer);
#ifndef BASE_REGISTER_MODE
void cbuffer_get_read_address_and_size(tCbuffer * cbuffer, int ** read_ptr, int * buffer_size);
void cbuffer_get_write_address_and_size(tCbuffer * cbuffer, int ** write_ptr, int * buffer_size);
#else
void cbuffer_get_read_address_and_size_and_start_address(tCbuffer * cbuffer, int ** read_ptr, int * buffer_size, int ** start_addr);
void cbuffer_get_write_address_and_size_and_start_address(tCbuffer * cbuffer, int ** write_ptr, int * buffer_size, int ** start_addr);
#endif
unsigned *cbuffer_get_read_address(tCbuffer *cbuffer);
unsigned *cbuffer_get_write_address(tCbuffer *cbuffer);
void cbuffer_set_read_address(tCbuffer * cbuffer, int * read_ptr);
void cbuffer_set_write_address(tCbuffer * cbuffer, int * write_ptr);

/*!
 * @brief Calculates the amount of space for new data in a cbuffer/port
 * @param cbuffer buffer or port reference
 * @param buffer_size pointer to store buffer size in words (bytes if an mmu port) (may be NULL)
 * @return Amount of space (for new data) in words
 */
int cbuffer_calc_amount_space(tCbuffer * cbuffer, int * buffer_size);

/*!
 * @brief Calculates the amount of data already in a cbuffer/port
 * @param cbuffer buffer or port reference
 * @param buffer_size pointer to store buffer size in words (bytes if an mmu port) (may be NULL)
 * @return Amount of data available in words
 */
int cbuffer_calc_amount_data(tCbuffer * cbuffer, int * buffer_size);

void cbuffer_buffer_configure(tCbuffer * cbuffer, int * buffer_start, int buffer_size);
void cbuffer_force_mmu_set(void);
void cbuffer_empty_buffer(tCbuffer * cbuffer);
void cbuffer_fill_buffer(tCbuffer * cbuffer, int value);
void cbuffer_advance_read_ptr(tCbuffer * cbuffer, int amount);
void cbuffer_advance_write_ptr(tCbuffer * cbuffer, int amount);
void cbuffer_set_read_port_connect_callback(tCbufferPortCallback callback);
void cbuffer_set_read_port_disconnect_callback(tCbufferPortCallback callback);
void cbuffer_set_write_port_connect_callback(tCbufferPortCallback callback);
void cbuffer_set_write_port_disconnect_callback(tCbufferPortCallback callback);

// The following functions are not really stubs in the same way, they are new
// functionality to help the C applications. The implementations may move from
// the C stubs in future.
//
// Read data from a circualr buffer into the provided linear buffer, if there is
// more data than the size of the buffer, limit to the size. Returning the
// number of words copied
int cbuffer_read(tCbuffer * cbuffer, int * buffer, int buffer_size);
// Write data to a circualr buffer from the provided linear buffer, if there is
// more data in the buffer than space in the circular buffer, limit to the
// amount of space. Returning the number of words copied
int cbuffer_write(tCbuffer * cbuffer, int * buffer, int buffer_size);
// Copy data form a buffer like object (cbuffer or port) into another buffer
// object. Returning the number of words copied
int cbuffer_buffer_to_buffer(tCbuffer * input, tCbuffer * output);

tCbuffer* cbuffer_sync_read (tCbuffer *cbuffer[]);

void cbuffer_advance_read_ptr (tCbuffer *cbuffer, int step);

void cbuffer_update_word_at_offset (tCbuffer *cbuffer, int offset, int value);

void cbuffer_peek_block (tCbuffer *cbuffer, void *data, int size);

int cbuffer_get_size (tCbuffer *cbuffer);

void cbuffer_move_pack_16(tCbuffer *src, tCbuffer *dest, int size);

void *cbuffer_read_from_address(tCbuffer *cbuffer, void *buffer_ptr, const void *read_ptr, int size);

void *cbuffer_advance_address(tCbuffer *cbuffer, void *address, size_t size);

unsigned cbuffer_diff_read(tCbuffer *before, tCbuffer *after);
unsigned cbuffer_diff_write(tCbuffer *before, tCbuffer *after);

// macro to declare a port
#define DECLARE_PORT(name, value) \
asm void name##DeclareAsm(void) { .CONST $_##name (value); .CONST $##name (value);} \
static void name##Declare(void) { name##DeclareAsm(); } \
extern tCbuffer name

/* **************************************************************************
                                -- message --
   **************************************************************************/

/* PUBLIC TYPES DEFINITIONS *************************************************/
typedef void (* tMessageEventFunction)(int ID, int p0, int p1, int p2, int p3);

typedef struct tMessageStructTag
{
    struct tMessageStructTag * next;
    int                        id;
    tMessageEventFunction      MessageEventFunction;
    int                        mask;
} tMessageStruct;

typedef struct
{
    int nMessageId;
    int m1;
    int m2;
    int m3;
    int m4;
} KALIMBA_SHORT_MESSAGE_T;

/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
void message_initialise(void);
void message_register_handler(tMessageStruct * message_struc, int message_id, tMessageEventFunction message_function);
void message_register_handler_with_mask(tMessageStruct * message_struc, int message_id, tMessageEventFunction message_function, int message_mask);
void message_send_ready_wait_for_go(void);
void message_send_short(int message_id, int p0, int p1, int p2, int p3);
void message_send_long(int message_id, int msg_size, int * msg_payload);


/* **************************************************************************
                              -- pskey --
   **************************************************************************/

/* PUBLIC TYPES DEFINITIONS *************************************************/
typedef struct tPSKeyStructTag tPSKeyStruct;

/* NOTE: the memory for the payload must not be freed, it can be changed    */
typedef void (* tPSKeyEventFunction)(tPSKeyStruct * pskey_struct, int ID, int length, const int * payload);

typedef struct tPSKeyStructTag
{
    struct tPSKeyStructTag * next;
    int                      id;
    tPSKeyEventFunction      PsKeyEventFunction;
};

/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
void pskey_initialise(void);
void pskey_read_key(tPSKeyStruct * pskey_struct, int pskey_id, tPSKeyEventFunction pskey_function);


/* **************************************************************************
                              -- flash --
   **************************************************************************/

/* PUBLIC TYPES DEFINITIONS *************************************************/
typedef struct tFileAddressStructTag tFileAddressStruct;

typedef void (* tFileAddressFunction)(tFileAddressStruct * file_address_structure, unsigned int file_handle, unsigned int const * file_address);

struct tFileAddressStructTag
{
    tFileAddressStruct   * next;
    unsigned int           file_id;
    tFileAddressFunction   FileAddressFunction;
};

/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
/* If a size is not required, pass in FLASH_NULL. If a size is provided, it will
 * be updated as described in the assembly function documentation */
int * flash_map_page_into_dm(int * variable_segment_address, int * variable_size, int * segment_address);
int flash_copy_to_dm(int * variable_segment_address, int variable_size, int * segment_address, int ** dest_addr);
int flash_copy_to_dm_32_to_24(int * variable_segment_address, int variable_size, int * segment_address, int ** dest_addr);
int flash_copy_to_dm_24(int * variable_segment_address, int variable_size, int * segment_address, int ** dest_addr);
void flash_get_file_address(tFileAddressStruct * file_address_structure, unsigned int file_id, tFileAddressFunction FileAddressFunction);

/* **************************************************************************
                              -- FW random number --
   **************************************************************************/

/* PUBLIC TYPES DEFINITIONS *************************************************/
typedef struct tFwRandomNumberStructTag tFwRandomNumberStruct;

typedef void (* tFwRandomNumberFunction)(int status, tFwRandomNumberStruct * fw_random_number_structure, int length, int * buffer);

struct tFwRandomNumberStructTag
{
    tFwRandomNumberStruct  * next;
    unsigned int             num_req;
    unsigned int             num_resp;
    unsigned int           * resp_buf;
    tFwRandomNumberFunction  FwRandomNumberFunction;
};


/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
void fwrandom_initialise(void);
void fwrandom_get_rand_bits(tFwRandomNumberStruct * fw_random_number_structure, int num_bits, tFwRandomNumberFunction FwRandomNumberFunction, int * buffer);
/* **************************************************************************
                                -- exit and debug --
   **************************************************************************/

/* PUBLIC TYPES DEFINITIONS *************************************************/
typedef struct tPioStructTag tPioStruct;

typedef void (* tPioFunction)(tPioStruct * pio_structure, unsigned int change_pios, unsigned int change_pio2s, unsigned int change_pio3s);

struct tPioStructTag
{
    tPioStruct   * next;
    unsigned int   pio_bitmask;
    unsigned int   pio2_bitmask;
    unsigned int   pio3_bitmask;
    tPioFunction   PioFunction;
};

/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
void pio_initialise(void);
void pio_register_handler(tPioStruct * pio_structure, unsigned int pio_bitmask, unsigned int pio2_bitmask, unsigned int pio3_bitmask, tPioFunction PioFunction);
void pio_set_bit(unsigned int bit);
void pio_clear_bit(unsigned int bit);
void pio_toggle_bit(unsigned int bit);
void pio_set_dir_output_bit(unsigned int bit);
void pio_set_dir_input_bit(unsigned int bit);

/* **************************************************************************
                                -- exit and debug --
   **************************************************************************/

/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
#pragma ckf kalimba_error f DoesNotReturn
void kalimba_error(void);
#pragma ckf panic f DoesNotReturn
void panic(void);
void exit(void);
void abort(void);
#ifdef DEBUG_ON
   void putchar(char);
   /* there are other dump_xxx functions to add */
#endif

#endif // CORE_LIBRARY_C_STUBS_H