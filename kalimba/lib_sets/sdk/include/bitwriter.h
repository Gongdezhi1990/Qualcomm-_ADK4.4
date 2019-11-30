/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/
/*!
    @file bitwriter.h
    @brief Write bits to a buffer.
*/

#ifndef BITWRITER_H
#define BITWRITER_H

#ifdef KCC
#include <stdint.h>
#include <stdbool.h>
#include <core_library_c_stubs.h>

typedef struct bitwriter
{
    /** Base buffer address */
    uint24_t *base_ptr;

    /** Current write address */
    uint24_t *write_ptr;

    /** Current write bit position */
    uint24_t write_bit_pos;

    /** Current word being written */
    uint24_t write_value;

    /** Number of bits written */
    uint24_t bits_written;

    /** Size of buffer in bits */
    uint24_t bits_size;
} bitwriter_t;

/**
 * \brief Initialise bitwriter object
 *
 * \param b Pointer to a bitwriter object.
 * \param buffer Pointer to the buffer to which the bitwriter will write. The
 *               bitwriter will write data packed 16-bits per word.
 * \param s The buffer size in bits
 */
extern void bitwriter_initialise(bitwriter_t *b, uint24_t *buffer, size_t s);

/**
 * \brief Write bits
 *
 * \param b Pointer to a bitwriter object.
 * \param value Value to write. Only bits 0 to (size-1) may be set.
 * \param size Number of bits of value to write.
 */
extern void bitwriter_write_bits(bitwriter_t *b, unsigned value, unsigned size);

/**
 * \brief Write octet
 *
 * \param b Pointer to a bitwriter object.
 * \param value Octet to write. Only bits 0 to 7 may be set.
 */
extern void bitwriter_write_8(bitwriter_t *b, unsigned value);

/**
 * \brief Write 16 bits
 *
 * \param b Pointer to a bitwriter object.
 * \param value 16 bit value to write. Only bits 0 to 15 may be set.
 */
extern void bitwriter_write_16(bitwriter_t *b, unsigned value);

/**
 * \brief Write 24 bits
 *
 * \param b Pointer to a bitwriter object.
 * \param value 24 bit value to write. Only bits 0 to 23 may be set.
 */
extern void bitwriter_write_24(bitwriter_t *b, unsigned value);

/**
 * \brief Write data from a CBuffer
 *
 * \param b Pointer to a bitwriter object.
 * \param cbuffer Pointer to CBuffer, data stored as 16 bits per word.
 * \param num_octets Number of octets to copy from CBuffer.
 */
extern void bitwriter_write_from_cbuffer(bitwriter_t *b, cbuffer_t *cbuffer, unsigned num_octets);

/**
 * \brief Write data from a linear buffer
 *
 * \param b Pointer to a bitwriter object.
 * \param buffer Pointer to linear buffer, data stored as 16 bits per word.
 * \param num_octets Number of octets to copy from linear buffer
 */
extern void bitwriter_write_from_linear_buffer(bitwriter_t *b, uint24_t *buffer, unsigned num_octets);

/**
 * \brief Get the number of bits written
 *
 * \param b Pointer to a bitwriter object.
 * \return The number of bits written
 */
extern unsigned bitwriter_get_bits_written(const bitwriter_t *b);

/**
 * \brief Get the number of octets written (rounded up)
 *
 * \param b Pointer to a bitwriter object.
 * \return The number of octets written
 */
#define bitwriter_get_octets_written(b) ((bitwriter_get_bits_written(b) + 7) / 8)

/**
 * \brief Get the space left in bits
 *
 * \param b Pointer to a bitwriter object.
 * \return The space left in bits.
 */
extern unsigned bitwriter_get_bits_space(const bitwriter_t *b);

/**
 * \brief Get the buffer base address
 *
 * \param b Pointer to a bitwriter object.
 * \return The base address of the buffer.
 */
extern uint24_t * bitwriter_get_base_address(const bitwriter_t *b);

/**
 * \brief Get the buffer write address
 *
 * \param b Pointer to a bitwriter object.
 * \return The write address of the buffer.
 */
extern uint24_t * bitwriter_get_write_address(const bitwriter_t *b);

/**
 * \brief Copy data written to port
 *
 * \param b Pointer to a bitwriter object.
 * \param port MMU Port number.
 * \param header Pointer to header data, one octet per word.
 * \param size_header The number of octets in the header.
 */
extern void bitwriter_copy_to_port(bitwriter_t *b, unsigned port, uint24_t *header, unsigned size_header);

/**
 * \brief Skip bits in bitwriter object.
 *
 * \param b Pointer to a bitwriter object.
 * \param bits Number of bits to skip over.
 */
extern void bitwriter_skip_bits(bitwriter_t *b, uint24_t bits);

/**
 * \brief Flush - write buffered bits to the buffer.
 *
 * \param b Pointer to a bitwriter object.
 */
extern void bitwriter_flush(bitwriter_t *b);

/**
 * \brief Test if the bitwriter has overflowed the buffer
 *
 * \param b Pointer to a bitwriter object.
 */
extern bool bitwriter_has_overflowed(bitwriter_t *b);

/**
 * \brief Split the data written to bitwriter into two halves.
 *        If necessary, the buffer is first padded with zeros until an even
 *        number of 16-bit words have been written. The buffer is then split at
 *        the word boundary at the centre of the written data.
 *
 * \param s [IN] Pointer to the source bitwriter.
 * \param a [OUT] Pointer to the first half split
 * \param b [OUT] Pointer to the second half split
 * \return Number of bits padding added to make an even number of 16-bit words.
 */
extern unsigned int bitwriter_halve(bitwriter_t *s, bitwriter_t *a, bitwriter_t *b);

#endif /* KCC */

/** Size in words of the bitwriter structure */
#define BITWRITER_STRUC_SIZE (6)

#define BITWRITER_BASE_PTR_FIELD      0
#define BITWRITER_WRITE_PTR_FIELD     1
#define BITWRITER_WRITE_BIT_POS_FIELD 2
#define BITWRITER_WRITE_VALUE_FIELD   3
#define BITWRITER_BITS_WRITTEN_FIELD  4
#define BITWRITER_END_PTR_FIELD       5

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(bitwriter_t, BITWRITER_STRUC_SIZE);
#endif /* KCC */

#endif /* BITWRITER_H */

