/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/
/*!
    @file bitreader.h
    @brief Read bits from a buffer.
*/

#ifndef BITREADER_H
#define BITREADER_H

#ifdef KCC
#include <stdint.h>
#include <stdbool.h>
#include <core_library_c_stubs.h>

typedef struct bitreader
{
    /** Base buffer address */
    uint24_t *base_ptr;

    /** Current read address */
    uint24_t *read_ptr;

    /** Current read bit position */
    uint24_t read_bit_pos;

    /** Number of bits read */
    uint24_t bits_read;

    /** Number of bits that can be read from the buffer */
    uint24_t size_bits;
} bitreader_t;

/**
 * \brief Initialise a bitreader
 *
 * \param b Pointer to a bitreader object
 * \param buffer Pointer to buffer to read bits from. Data must be packed 16
 *               bits per word in the buffer.
 * \param s The buffer size in octets
 */
extern void bitreader_initialise(bitreader_t *b, uint24_t *buffer, uint24_t s);

/**
 * \brief Read octet
 *
 * \param b [IN] Pointer to a bitreader object.
 * \param data [OUT] The bits read from the bitreader.
 * \return True if the bits could be read, false otherwise.
 */
extern bool bitreader_read_8(bitreader_t *b, uint24_t *data);

/**
 * \brief Read 16 bits
 *
 * \param b [IN] Pointer to a bitreader object.
 * \param data [OUT] The bits read from the bitreader.
 * \return True if the bits could be read, false otherwise.
 */
extern bool bitreader_read_16(bitreader_t *b, uint24_t *data);

/**
 * \brief Read 24 bits
 *
 * \param b [IN] Pointer to a bitreader object.
 * \param data [OUT] The bits read from the bitreader.
 * \return True if the bits could be read, false otherwise.
 */
extern bool bitreader_read_24(bitreader_t *b, uint24_t *data);

/**
 * \brief Skip bits in bitreader object.
 *
 * \param b [IN] Pointer to a bitreader.
 * \param bits [IN] Number of bits to skip over.
 * \return True if the bits could be skipped, false otherwise.
 */
extern bool bitreader_skip_bits(bitreader_t *b, uint24_t bits);

/**
 * \brief Read data from bitreader object into CBuffer.
 *
 * \param b Pointer to a bitreader object.
 * \param cbuffer Pointer to CBuffer, data stored as 16 bits per word.
 * \param num_octets Number of octets to copy from bitreader object to CBuffer.
 * \return True if the bits could be read, false otherwise.
 *
 * The function returns false if the number of octets requested to be copied
 * would read from beyond the end of the bitreader buffer.
 */
extern bool bitreader_read_to_cbuffer(bitreader_t *b, cbuffer_t *cbuffer,
                                      unsigned num_octets);

/**
 * \brief Read data from bitreader object into linear buffer.
 *
 * \param b Pointer to a bitreader object.
 * \param buffer Pointer to linear buffer, data stored as 16 bits per word.
 * \param num_octets Number of octets to copy from bitreader object to linear buffer.
 *
 * The function returns false if the number of octets requested to be copied
 * would read from beyond the end of the bitreader buffer.
 */
extern bool bitreader_read_to_linear_buffer(bitreader_t *b, uint24_t *buffer,
                                            unsigned num_octets);

/**
 * \brief Get the number of bits read by the bitreader
 *
 * \param b Pointer to a bitreader object
 * \return The number of bits read by the bitreader
 */
extern uint24_t bitreader_get_bits_read(const bitreader_t *b);

/**
 * \brief Get the buffer base address
 *
 * \param b Pointer to a bitreader object.
 * \return The base address of the buffer.
 */
extern uint24_t *bitreader_get_base_address(const bitreader_t *b);

/**
 * \brief Get the buffer read address
 *
 * \param b Pointer to a bitreader object.
 * \return The read address of the buffer.
 */
extern uint24_t *bitreader_get_read_address(const bitreader_t *b);

/**
 * \brief Get the number of bits in the bitreader buffer
 *
 * \param b Pointer to a bitreader object
 * \return The number of bits in the bitreader buffer
 */
extern uint24_t bitreader_get_size_bits(const bitreader_t *b);

/**
 * \brief Get the number of bits remaining (to be read) from the bitreader buffer
 *
 * \param b Pointer to a bitreader object
 * \return The number of bits remaining in the bitreader buffer
 */
extern int24_t bitreader_remaining_bits(const bitreader_t *b);

#else /* KCC */

#define BITREADER_BASE_PTR_FIELD     (0)
#define BITREADER_READ_PTR_FIELD     (1)
#define BITREADER_READ_BIT_POS_FIELD (2)
#define BITREADER_BITS_READ_FIELD    (3)
#define BITREADER_SIZE_BITS_FIELD    (4)

#endif /* KCC */

/** The size in words of the bitreader structure. */
#define BITREADER_STRUC_SIZE (5)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(bitreader_t, BITREADER_STRUC_SIZE);
#endif  /* KCC */

#endif /* BITREADER_H */
