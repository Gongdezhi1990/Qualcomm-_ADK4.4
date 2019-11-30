/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file frame_info.h
    @brief Gets audio frame information for SBC & CELT frames

*/

#ifndef FRAME_INFO_H
#define FRAME_INFO_H

/** Size of SBC frame header */
#define HEADER_SIZE_SBC 4

/** Size of CELT frame header */
#define HEADER_SIZE_CELT 0

#ifdef KCC

#include <stdbool.h>
#include <stdint.h>

/** @defgroup CeltVars The application must define the following variables/consts 
 *
 * @{
 */
/** CELT frame size in octets for 44100KHz */
extern uint24_t celt_decoder_frame_size_octets_44100;
/** CELT frame size in octets for 48000KHz */
extern uint24_t celt_decoder_frame_size_octets_48000;
/** Number of samples in CELT frame at 44100KHz */
extern uint24_t celt_decoder_frame_samples_44100;
/** Number of samples in CELT frame at 48000KHz */
extern uint24_t celt_decoder_frame_samples_48000;
/** Number of channels in CELT frame */
extern uint24_t celt_decoder_frame_channels;
/** @} */


typedef bool (*get_frame_info_fn_t)(uint24_t *header,
                                    uint24_t *frame_length_octets,
                                    uint24_t *frame_samples,
                                    uint24_t *frame_channels);

/**
 * \brief  Get CELT decoder codec frame information
 *
 * \param[in] header A buffer containing the codec frame header
 * \param[out] frame_length_octets The frame length in octets
 * \param[out] frame_samples The number of samples in the frame
 * \param[out] frame_channels The number of channels in the frame
 * \return True is successful, False if unsuccessful
 */
bool get_frame_info_celt_decoder(uint24_t *header, uint24_t *frame_length_octets, uint24_t *frame_samples, uint24_t *frame_channels);

/**
 * \brief  Get SBC decoder codec frame information
 *
 * \param[in] header A buffer containing the codec frame header
 * \param[out] frame_length_octets The frame length in octets
 * \param[out] frame_samples The number of samples in the frame
 * \param[out] frame_channels The number of channels in the frame
 * \return True is successful, False if unsuccessful
 */
bool get_frame_info_sbc(uint24_t *header, uint24_t *frame_length_octets, uint24_t *frame_samples, uint24_t *frame_channels);

#else /* KCC */

#endif /* KCC */

#endif /* FRAME_INFO_H */

