/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

/*!
    @file md.h
    @brief Metadata library.

*/

#ifndef MD_H
#define MD_H

#ifdef KCC

#include <stdint.h>
#include <stdbool.h>
#include <core_library_c_stubs.h>
#include <sr.h>
#include <rtime.h>
#include <system_time.h>

/**
 * @brief Metadata for each PCM audio frame
 *
 * This structure contains the metadata for a PCM audio frame, part of md_t structure.
 */
typedef struct md_pcm_frame
{
    /** Set if this metadata frame marks the start of a stream */
    unsigned stream_start:1;

    /** Set if the metadata ttp is invalid. This flag is currently
        used to make the audio output play the frame immediately */
    unsigned ttp_invalid:1;
    unsigned reserved:5;

    /** Time source against which the ttp is referenced */
    unsigned system_time_source : SYSTEM_TIME_SOURCE_WIDTH_BITS;

    /** The the audio sample rate of the samples */
    enum srbits sample_rate_bits:4;

    /** The number of samples in this frame */
    unsigned num_samples:11;

    /** The time-to-play the first sample referred to by the metadata */
    time_t ttp;

    /** 0.23 signed fraction with range -1.0 to +1.0.
        sample_period = nominal_sample_period * (1 + sample_period_adjustment) */
    int24_t  sample_period_adjustment;
} md_pcm_frame_t;

/**
 * @brief Metadata for each RTP packet
 *
 * This structure contains the metadata for a RTP packet, part of md_t structure.
 */
typedef struct md_rtp_packet
{
    /** The time at which the rtp packet arrived in the DSP */
    time_t time_of_arrival;

    /** Time source against which the time of arrival is referenced */
    unsigned int system_time_source;

} md_rtp_packet_t;

/**
 * @brief Metadata for each encoded audio frame
 *
 * This structure contains the metadata for an encoded audio frame, part of md_t structure.
 */
typedef struct md_codec_frame
{
    /** Set if this metadata frame marks the start of a stream */
    unsigned start:1;

    /** Set if the metadata ttp is invalid. This flag is currently
        used to make the audio output play the frame immediately */
    unsigned ttp_invalid:1;
    unsigned reserved:5;

    /** Time source against which the ttp is referenced */
    unsigned system_time_source : SYSTEM_TIME_SOURCE_WIDTH_BITS;

    /** The audio sample rate of the samples */
    enum srbits sample_rate_bits:4;
    
    /** The number of octets in this frame */
    unsigned num_octets:11;

    /** The time-to-play the first sample referred to by the metadata */
    time_t ttp;

    /** 0.23 signed fraction with range -1.0 to +1.0.
        sample_period = nominal_sample_period * (1 + sample_period_adjustment) */
    int24_t  sample_period_adjustment;
} md_codec_frame_t;


/**
 * @brief Metadata structure
 *
 * This structure is the main metadata strcutre for audio within the DSP.  It contains a union
 * of sub-metadata structures for the various types of metadata within the audio chain.
 */
typedef struct md_t
{
    /** Pointer to next metadata in list */
    struct md_t *next;
    
    /** Pointer to cbuffer that this metadata is for */
    tCbuffer *cbuffer;
    
    /** Number of words of data in cbuffer that this metadata is for */
    uint24_t num_words;
    
    /** Pointer to data in cbuffer */
    uint24_t *read_ptr;

    /** Union of specific metadata structures */
    union
    {
        md_pcm_frame_t pcm;
        md_codec_frame_t codec;
        md_rtp_packet_t rtp;
    } u;
#ifdef DEBUG_MD
    /** Magic value for metadata validation in debug builds */
    uint24_t magic;
#endif /* DEBUG_MD */
} md_t;


/**
 * @brief Metadata list structure
 *
 * Metadata is normally stored in a linked list, this structure is is.
 */
typedef struct md_list_t
{
    /** Pointer to metadata at head of list, 0 if no metadata on list. */
    md_t *head;
    
    /** Pointer to metadata at tail of list */
    md_t *tail;
    
    /** Number of metadata items on list */
    int length;
} md_list_t;


typedef struct md_track_state
{
    /** Input presentation cbuffer - presents all data in the input_md_list */
    cbuffer_t *input_cbuffer;
    
    /** Output cbuffer to track */
    cbuffer_t *output_cbuffer;
    
    /** Input metadata list to track */
    md_list_t *input_md_list;
    
    /** Output metadata list - metadata is moved here from the input_md_list */
    md_list_t *output_md_list;
    
    /** The number of samples algorithmic delay introduced in the processing
        between input and output cbuffers. The tracker will adjust the ttps to
        account for this delay. */
    unsigned algorithmic_delay_samples;
    
    /** Internal state */
    /** The original number of words in the md in the head of the input_md_list */
    unsigned original_md_words;
    
    /** Stores the next read point in the output_cbuffer */
    uint24_t *next_read_ptr;
    
    /** Stored input cbuffer, used to calculate the number of words read */
    cbuffer_t i;
    
    /** stored output cbuffer, used to calculate the number of words written */
    cbuffer_t o;
} md_track_state_t;


/**
 * \brief  Initialise metdata library.
 *
 * Called at DSP startup, can't be called multiple times.
 * No return code, jumps to error on failure
 * Prepares linked list of 'free' metadata blocks.
 */
void md_initialise(void);

/**
 * \brief Allocate metadata block from free list.
 * \return Pointer to metadata block or 0 if no blocks free.
 *
 * Allocate a fixed size metadata block.  Sizde is fixed at compile time to contain largest metadata.
 */
md_t *md_alloc(void);

/**
 * \brief Allocate 2 metadata block from free list.
 * \param a Address of metadata block pointer, set to first block allocated.
 * \param b Address of metadata block pointer, set to second block allocated.
  * \return TRUE if allocate successed, FALSE if it failed.
 *
 * Allocates 2 fixed size metadata block.
 */
bool md_alloc_pair(md_t **a, md_t **b);

/**
 * \brief Allocate n metadata block from free list.
 * \param md_list Pointer to metdata list to store allocated blocks on.
 * \param n Number of blocks to allocate.
 * \return TRUE if allocate successed, FALSE if it failed.
 *
 * Allocate n metadata blocks and store in metadata list.
 */
bool md_list_alloc_n(md_list_t *md_list, unsigned n);

/**
 * \brief  Free meta-data block
 *
 * \param  md  Pointer to meta-data block to be free'd
 *
 * Adds specified meta-data block back to the free list.
 * It is safe to call this function from an interupt.
 */
void md_free(md_t *md);

/**
 * \brief Check number of blocks on free list matches free block count 
 */ 
void md_validate(void);

/**
 * \brief  Add meta-data block to tail of list
 *
 * \param  md_list  Pointer to meta-data list to add block to
 * \param  md       Pointer to meta-data block to add to list
 *
 * This function add the meta-data block to the tail of the specified list.
 * pointer to it.  If there's no blocks on the list NULL is returned.
 */
void md_list_add_tail(md_list_t *md_list, md_t *md);

/**
 * \brief  Return pointer to meta-data block at head of list
 *
 * \param  md_list  Pointer to meta-data list to get block from
 * \return  Pointer to meta-data block at head of list or NULL if no blocks on list
 *
 * This function returns a pointer to the meta-data block at the head of the list, or NULL
 * if there's no blocks on the list.  The block is not removed from the list.
 */
 md_t *md_list_get_head(md_list_t *md_list);

/**
 * \brief  Removes meta-data block at head of list
 *
 * \param  md_list  Pointer to meta-data list to get block from
 * \return  Pointer to meta-data block at head of list or NULL if no blocks on list
 *
 * This function removes the meta-data block at the head of the list and returns a
 * pointer to it.  If there's no blocks on the list NULL is returned.
 */
md_t *md_list_remove_head(md_list_t *md_list);


/**
 * \brief Free all the metadata in a list
 */ 
void md_list_free_all(md_list_t *md_list);


/**
 * \brief Allocate a metadata block and intialise it to reference cbuffer
 * \param  cbuffer Pointer to cbuffer to associate metadata block with.
 * \return Pointer to metadata block or 0 if no blocks free.
 */
md_t *md_cbuffer_alloc(tCbuffer *cbuffer);

/**
 * \brief  Free metadata block and update cbuffer read index
 *
 * \param  md  Pointer to metadata block to free
 *
 * This function free the specified metadata block and returns it to the free list.
 * The cbuffer associated with this metadata block will have it's read index updated
 */
void md_cbuffer_free(md_t *md);

/**
 * \brief  Read data from cbuffer associated with metadata block
 *
 * \param  md  Pointer to metadata block
 * \param  buffer  Pointer to linear buffer to write data in to
 * \param  num_words Number of words to read out of cbuffer
 *
 * This function reads data from the cbuffer associated with the metadata block.
 * The metadata block tracks the read index into the cbuffer so the cbuffer
 * associated with this metadata block will not have it's read index updated.
 */
void md_cbuffer_read(md_t *md, void *buffer, uint24_t num_words);

/**
 * \brief  Advance metadata block read pointer
 *
 * \param  md  Pointer to metadata block
 * \param  num_words Number of words to advance
 *
 * This function advances the metadata read pointer by the required number of
 * words.
 * The meta-data block tracks the read index into the cbuffer so the cbuffer
 * associated with this metadata block will not have it's read index updated.
 */
void md_cbuffer_advance(md_t *md, uint24_t num_words);

/**
 * \brief  Calculate amount of data remaining for meta-data block
 *
 * \param  md  Pointer to metadata block
 * \return Number of words of data in cbuffer associated with metadata block.
 */
uint24_t md_cbuffer_calc_data(md_t *md);

/**
 * \brief  Move and pack data into cbuffer
 *
 * \param  md  Pointer to metadata block
 * \param  num_bytes Number of octets of data to move
 * \param  cbuffer Destination cbuffer to write packed data into.
 *
 * This function will move the specified number of octests from the cbuffer
 * associated with the metadata block to the destination cbuffer, packing 2
 * octets into 1 16-bit word.
 */
void md_cbuffer_move_pack16(md_t *md, uint24_t num_bytes, tCbuffer *cbuffer);

/**
 * \brief Initialise cbuffer with all the data in metadata block.
 * \param cbuffer The cbuffer to initialise
 * \param md_ptr The metadata block
 */

void md_cbuffer_init_from_md(cbuffer_t *cbuffer, md_t *md_ptr);

/**
 * \brief Initialise cbuffer with all the data in md_list.
 *        Assumes all md in the list points to the same cbuffer.
 *        Assumes all cbuffer data in md in the list is contiguous.
 * \param cbuffer The cbuffer to initialise
 * \param md_list The metadata list
 */
void md_cbuffer_init_from_md_list(cbuffer_t *cbuffer, md_list_t *md_list);


typedef struct md_chunk_state
{
    md_t *md_ptr;
} md_chunk_state_t;

/**
 * \brief Initialise PCM metadata
 */
void md_pcm_init(md_t *md_ptr, unsigned stream_start, unsigned ttp_invalid,
                 unsigned system_time_source, enum srbits sample_rate_bits,
                 unsigned num_samples, time_t ttp, int24_t sample_period_adjustment);

/**
 * \brief Calculate TTP for sample within metadata block
 *
 * \param  md_ptr  Pointer to metadata block
 * \param  num_samples Offset into block to calculate TTP for.
 */
time_t md_pcm_calc_ttp(md_t *md_ptr, unsigned num_samples);

/**
 * \brief  Join two metadata blocks together
 *
 * \param  md1_ptr  Pointer to first metadata block
 * \param  md2_ptr  Pointer to second metadata block
 * \return  Pointer to joined metadata block
 * 
 * Joins second metadata block to the end of the first metadata block.
 * Both blocks must reference the same cbuffer, with the samples of the second
 * block immediately following the first block.
 */
md_t *md_pcm_join(md_t *md1_ptr, md_t *md2_ptr);

/**
 * \brief  Duplicate metadata blocks
 *
 * \param  md1_ptr  Pointer to metadata block to duplicate
 * \return Pointer to duplicate metadata block
 * 
 * Creates a new metablock that is a duplicate of the specified block.
 */
md_t *md_pcm_duplicate(const md_t *const md1_ptr);

/**
 * \brief  Split a metadata block
 *
 * \param  md1_ptr  Pointer to metadata block to split
 * \param  offset  Offset into block where split should be
 * \result Pointer to new block as second part.
 *
 *  Split block at offset, original block is first part, return new block as second part.
 */
md_t *md_pcm_split(md_t *md1_ptr, unsigned offset);

/**
 * \brief  Resize metadata blocks to fixed number of samples
 *
 * \param  chunk_st  Chunk state.
 * \param  md_ptr    New metadata block to pass in to chunking mechanism.
 * \param  num_samples Number of samples for each block.
 * \result Pointer to new block.
 */
md_t *md_pcm_chunk(md_chunk_state_t *chunk_st, md_t *md_ptr, unsigned num_samples);


/**
 * \brief Initialise CODEC metadata
 */
void md_codec_init(md_t *md_ptr, unsigned start, unsigned ttp_invalid,
                   unsigned system_time_source, enum srbits sample_rate_bits,
                   unsigned num_octets, time_t ttp, int24_t sample_period_adjustment);

/**
 * \brief Initialise the md tracker state
 *
 * \param state - The md tracker state
 */
void md_track_cbuffers_initialise(md_track_state_t *state);

/**
 * \brief Call this function before processing data. This function initialises
 *        input_cbuffer to present all the data in input_md_list.
 *
 * \param state The md tracker state
 * \return True: the processing may proceed
 *         False: the processing must not proceed
 */
bool md_track_cbuffers_pre(md_track_state_t *state);

/**
 * \brief Call this function after processing data.
 *        This function calculates the number of samples moved from
 *        input_cbuffer to output_cbuffer. It moves metadata from
 *        input_md_list to output_md_list when the the number of samples
 *        associated with the md at the head of the input_md_list have been
 *        moved from input_cbuffer to output_cbuffer.
 *
 * \param state The md tracker state
 * \return The number of samples moved from input to output.
 */
unsigned int md_track_cbuffers_post(md_track_state_t *state);

/**
 * \brief Call this function on one md after running a resampler.
 *        This function calculates the number of samples moved from
 *        input_cbuffer to output_cbuffer. It moves metadata from
 *        input_md_list to output_md_list.
 *
 * \param state The md tracker state
 * \return The number of samples moved from input to output.
 */
unsigned int md_track_cbuffers_post_resampler(md_track_state_t *state, signed output_fs);


/**
 * \brief Copy all data in the input metadata list to one of two output lists
 *        depending on the state of control. This is a single pole double throw
 *        switch.
 *
 * \param control if true, md is copied from the input to output_true
 *                if false, md is copied from the input to output_false
 * \param input The input metadata list
 * \param output_true md is copied to this list if control is true
 * \param output_false md is copied to this list if control is false
 */
void md_list_spdt_switch(bool control, md_list_t *input,
                         md_list_t *output_true, md_list_t *output_false);

/**
 * \brief Dispose of all data in a metadata list. For each md in this list,
 *        the data in the underlying cbuffer is freed and the md is freed.
 *
 * \param md_list The metadata list whose data is to be disposed.
 */
void md_list_dispose(md_list_t *md_list);

#else /* KCC */

#define MD_NEXT_FIELD_INDEX         (0)
#define MD_CBUFFER_FIELD_INDEX      (1)
#define MD_NUM_WORDS_FIELD_INDEX    (2)
#define MD_READ_PTR_FIELD_INDEX     (3)

#define MD_RTP_PACKET_TIME_OF_ARRIVAL_FIELD_INDEX   (4)
#define MD_RTP_PACKET_TIME_SRC_FIELD_INDEX          (5)

#endif /* KCC */

/* Size in words of the meta-data structures */
#define MD_LIST_STRUC_SIZE          3
#define MD_CHUNK_STATE_STRUC_SIZE   1
#define MD_TRACK_STATE_STRUC_SIZE   (5+2+3+3)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(md_list_t, MD_LIST_STRUC_SIZE);
STRUC_SIZE_CHECK(md_chunk_state_t, MD_CHUNK_STATE_STRUC_SIZE);
STRUC_SIZE_CHECK(md_track_state_t, MD_TRACK_STATE_STRUC_SIZE);
#endif /* KCC */

#endif /* MD_H */

