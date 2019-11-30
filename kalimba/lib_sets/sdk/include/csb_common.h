/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/
/*!
  @file csb_common.h
  @brief Definition of CSB packet structure.
*/
#ifndef CSB_COMMON_H
#define CSB_COMMON_H

#ifdef KCC
#define CSB_ASSERT(x) do { if (!(x)) kalimba_error(); } while (0)
#endif

/*! The size in bits of the CSB packet TTP. */
#define CSB_TTP_SIZE_BITS   (40)
/*! The size in octets of the CSB packet TTP. */
#define CSB_TTP_SIZE_OCTETS (CSB_TTP_SIZE_BITS / BITS_PER_OCTET)

/*! The size in bits of the CSB packet MAC. */
#define CSB_MAC_SIZE_BITS   (32)
/*! The size in octets of the CSB packet MAC. */
#define CSB_MAC_SIZE_OCTETS (CSB_MAC_SIZE_BITS / BITS_PER_OCTET)

/*! The size in bits of the tag defining the start of a section. */
#define CSB_TAG_SIZE_BITS  (8)
/*! The size in octets of the tag defining the start of a section. */
#define CSB_TAG_SIZE_OCTETS  (CSB_TAG_SIZE_BITS / BITS_PER_OCTET)

/*! The size in bits of the audio section header. */
#define CSB_AUDIO_HEADER_SIZE_BITS (8)
/*! The size in octets of the audio section header. */
#define CSB_AUDIO_HEADER_SIZE_OCTETS  (CSB_AUDIO_HEADER_SIZE_BITS / BITS_PER_OCTET)

/*! The size in bits of the sample period within the audio section. */
#define CSB_AUDIO_SAMPLE_PERIOD_SIZE_BITS (8)
/*! The size in octets of the sample period within the audio section. */
#define CSB_AUDIO_SAMPLE_PERIOD_SIZE_OCTETS  (CSB_AUDIO_SAMPLE_PERIOD_SIZE_BITS / BITS_PER_OCTET)


#endif
