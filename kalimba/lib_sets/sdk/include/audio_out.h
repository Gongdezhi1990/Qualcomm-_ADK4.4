/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/
/*!
    @file audio_out.h
    @brief Synchronised Audio Output.

    Outputs audio frames at the correct time according to the audio metadata.
*/

#ifndef AUDIO_OUT_H
#define AUDIO_OUT_H

#ifdef KCC
#include <core_library_c_stubs.h>
#include <md.h>
#endif /* KCC */

/** The audio output is synchronised. */
#define AUDIO_OUTPUT_TTP_OK               0
/** The audio output has no input audio. */
#define AUDIO_OUTPUT_NO_AUDIO             (1 << 0)
/** The audio output is inserting silence in order to become synchronised. */
#define AUDIO_OUTPUT_SILENCE_SYNC         (1 << 1)
/** The audio output sample rate differs from the sample rate of the input
    frame. The input frame will be discarded. */
#define AUDIO_OUTPUT_SAMPLE_RATE_MISMATCH (1 << 2)
/** The input frame's timestamp is too late to be played.
    The input frame will be discarded. */
#define AUDIO_OUTPUT_FRAME_LATE           (1 << 3)
/** The input frame's timestamp is too far in the future. Silence will be
    inserted before the frame is played. */
#define AUDIO_OUTPUT_TOO_FAR_IN_FUTURE    (1 << 4)
/** The input frame time-to-play is invalid - the frame will be played
    immediately. */
#define AUDIO_OUTPUT_TTP_INVALID          (1 << 5)
/** The audio output's output ports are disconnected. All input frames
    are discarded whilst the output ports are disconnected. */
#define AUDIO_OUTPUT_PORTS_DISCONNECTED   (1 << 6)

#ifdef KCC
/**
 * Structure defining the MMU ports used by Broadcast Audio.
 * The audio_output module requires the left and right output
 * ports to be defined.
 */
struct audio_port_ids
{
    /** The left output port number */
    unsigned int left_out_port;
    /** The right output port number */
    unsigned int right_out_port;
    /** The codec input port */
    unsigned int codec_in_port;
    /** The usb input port */
    unsigned int usb_in_port;
    /** The left analogue input port */
    unsigned int left_in_port;
    /** The right analogue input port */
    unsigned int right_in_port;
    /** The codec output port */
    unsigned int codec_out_port;
};

/**
 * Structure defining the tone mixing data used by Broadcast Audio.
 */
typedef struct tone_mixing_data
/* struct tone_mixing_data */
{    
    cbuffer_t *tone_left;
    cbuffer_t *tone_right;
    int24_t tone_gain;
} tone_mixing_data;

/**
 * \brief Initialise the audio_output module.
 *
 * Initialises the audio output module with a default sample rate of 44100 Hz.
 * It is assumed the DACs have already been configured by the VM before this
 * routine is called.
 *
 * \param   port_ids            The structure containing definitions port ids. The
 *                              left_out_port and right_out_port ids must be defined.
 */
void audio_output_initialise(const struct audio_port_ids *port_ids);

/**
 * \brief Set the audio output delay.
 *
 * The audio output library automatically accounts for the difference in delay
 * added by the DAC output between Gordon and Rick devices. If the product uses
 * an I2S output with external codec (which will introduce a codec-specific
 * delay) this function may be used to null that delay, such that audio playback
 * is synchronised between a Gordon/Rick device with DAC output and the product
 * with I2S output.
 *
 * \param delay_us The delay in microseconds.
 */
void audio_output_set_output_delay_us(int24_t delay_us);


/**
 * \brief  Sets the sample rate.
 *
 * Set output sample rate, it's assumed that the DACs have already been
 * configured by the VM before this routine is called.
 *
 * @param   sample_rate     the sample_rate in Hz.
 */
void audio_output_set_rate(int sample_rate);

/**
 * \brief Output an audio frame.
 *
 * \param left_list  Pointer to the metadata list for the left PCM output.
 * \param right_list  Pointer to the metadata list for the right PCM output.
 *
 * Take audio frame and play it at correct time according to the metadata in
 * audio_output_md_buffer.
 */
int audio_output_timestamped_frames(md_list_t *left_list, md_list_t *right_list, tone_mixing_data *tone_data);

/**
 * \brief  Get the audio output status.
 */
unsigned int audio_output_get_status(void);

/**
 * \brief  Destroys audio output state.
 *
 * Releases any resources owned by the audio output module.
 */
void audio_output_destroy(void);

/**
 * \brief  Sets DAC(s) gain.
 *
 * \param gain_db_x4    DAC gain*4
 * \param dac_a         TRUE if setting DAC_A
 * \param dac_b         TRUE if setting DAC_B
 */
void audio_output_set_dac_gain(signed gain_db_x4, bool dac_a, bool dac_b);

#else /* KCC */
    .CONST $audio.output.NO_AUDIO             AUDIO_OUTPUT_NO_AUDIO;
    .CONST $audio.output.SILENCE_SYNC         AUDIO_OUTPUT_SILENCE_SYNC;
    .CONST $audio.output.SAMPLE_RATE_MISMATCH AUDIO_OUTPUT_SAMPLE_RATE_MISMATCH;
    .CONST $audio.output.FRAME_LATE           AUDIO_OUTPUT_FRAME_LATE;
    .CONST $audio.output.TOO_FAR_IN_FUTURE    AUDIO_OUTPUT_TOO_FAR_IN_FUTURE;
    .CONST $audio.output.TTP_INVALID          AUDIO_OUTPUT_TTP_INVALID;
#endif /* KCC */

#endif /* AUDIO_OUT_H */
