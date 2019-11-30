/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/
/*!
    @file bluetooth.h
    @brief Bluetooth definitions.
*/

/** The number of 16-bit words required to store x octets. */
#define OCTETS_TO_16BIT_WORDS(x) (((x) + 1) / 2)
/** The number of 24-bit words required to store x octets. */
#define OCTETS_TO_24BIT_WORDS(x) (((x) + 2) / 3)
/** The number of 16-bit words required to store x bits. */
#define BITS_TO_16BIT_WORDS(x)   (((x) + 15) / 16)
/** The number of 24-bit words require to store x bits. */
#define BITS_TO_24BIT_WORDS(x)   (((x) + 23) / 24)

/** The number of bits per octet. */
#define BITS_PER_OCTET (8)

/** The length in octets of a 2-DH5 packet, not including the 2-octet header. */
#define BT_PACKET_2DH5_MAX_DATA_OCTETS  (679)
/** The length in bits of a 2-DH5 packet, not including the 2-octet header. */
#define BT_PACKET_2DH5_MAX_DATA_BITS    (BT_PACKET_2DH5_MAX_DATA_OCTETS * BITS_PER_OCTET)
/** The length in 16-bit words of a 2-DH5 packet, not including the 2-octet header. */
#define BT_PACKET_2DH5_MAX_DATA_16BIT_WORDS OCTETS_TO_16BIT_WORDS(BT_PACKET_2DH5_MAX_DATA_OCTETS)
/** The length in 24-bit words of a 2-DH5 packet, not including the 2-octet header. */
#define BT_PACKET_2DH5_MAX_DATA_24BIT_WORDS OCTETS_TO_24BIT_WORDS(BT_PACKET_2DH5_MAX_DATA_OCTETS)
