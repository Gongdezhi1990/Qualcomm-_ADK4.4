/*
 * Copyright (c) 2018 Qualcomm Technologies International, Ltd.
 * This file was automatically generated for firmware version 22.0
 */

#ifndef __SOURCE_H

#define __SOURCE_H

#include <csrtypes.h>
/*! @file source.h @brief Operations on sources of 8-bit data */
#include <source_.h>
#include <app/vm/vm_if.h>
#include <app/stream/stream_if.h>
/*! Discard all bytes that are currently in the source */
#define SourceEmpty(s) do { Source _x=(s); SourceDrop(_x, SourceSize(_x)); } while(0)


/*!
  @brief Reports the number of bytes available in the source.

  @param source The source to fetch the size of.
  @return Zero if the source is invalid.
  
  @note This call will return zero if the source stream is connected to another stream.

  @note
  If the source is an operator source stream then it always returns zero(0),
  irrespective of whether the operator source stream is valid or not.
*/
uint16 SourceSize(Source source);

/*! 
  @brief Reports the number of words available in the first header
  associated with source.

  @param source The Source whose header size is required.

  @return zero if the source is invalid or has no header.

  @note This call will return zero if the source stream is connected to another stream.

  @note
  If the source is an operator source stream then it always returns zero(0),
  irrespective of whether the operator source stream is valid or not.
*/
uint16 SourceSizeHeader(Source source);

/*!
  @brief Map the source into the address map, returning a pointer to the
  first byte in the source. 

  @param source The source to map into the address map.

  The number of accessible bytes is as given by SourceSize(). 
  At most one source can be mapped in at any time;
  pointers previously obtained from SourceMap() become invalid when
  another call to SourceMap() is made.

  @return zero if the source is invalid.
  
  @note This call will return zero if the source stream is connected to another stream.

  @note
  If the source is an operator source stream then it always returns zero(0),
  irrespective of whether the operator source stream is valid or not.
*/
const uint8 *SourceMap(Source source);

/*!
  @brief Map the first header associated with a source into the address map.

  @param source The Source whose header we wish to map.
  @return A pointer to the first word in the header, or zero
  if the source is invalid or has no headers.

  The number of accessible words is as given by SourceSizeHeader(). At most one header
  source can be mapped in at any time; pointers previously obtained
  from SourceMapHeader() become invalid when another call to
  SourceMapHeader() is made.
  
  @note This call will return zero if the source stream is connected to another stream.

  @note
  If the source is an operator source stream then it always returns zero(0),
  irrespective of whether the operator source stream is valid or not.
*/
const uint16 *SourceMapHeader(Source source);

/*!
  @brief Discards the indicated number of bytes from the front of the source.

  @param source The Source to drop the data from.
  @param amount The number of bytes to drop.
  
  @note This call will fail if the source stream is connected to another stream.

  @note
  If the supplied source is of operator source stream type, data will not
  dropped, irrespective of whether the operator source stream is valid or not.
*/
void SourceDrop(Source source, uint16 amount);

/*!
  @brief Return how many bytes in this source are before the next packet boundary
  (for non packet-based sources returns the same as SourceSize.)

  @param source The source to evaluate.

  @return Zero if the source is invalid.
  
  @note This call will return zero if the source stream is connected to another stream.

  @note
  If the source is an operator source stream then it always returns zero(0),
  irrespective of whether the operator source stream is valid or not.
*/
uint16 SourceBoundary(Source source);

/*!
  @brief Return TRUE if a source is valid, FALSE otherwise.

  @param source The source to check.

  @note
  Even if the source is an operator source, this trap should able to check
  whether the supplied source stream is valid or not.
*/
bool SourceIsValid(Source source);

/*!
    @brief Configure a particular source.

    @param source The source to configure.
    @param key The key to configure.
    @param value The value to write to 'key'

    @return FALSE if the request could not be performed, TRUE otherwise.

    See #stream_config_key for the possible keys and their meanings. Note that
    some keys apply only to specific kinds of source. Configuration Values will
    be lost once source is closed and key needs to be reconfigured if source
    is reopened.

    @note
    This trap cannot configure operator source stream. So, it always returns 
    FALSE over operator source stream input.
*/
bool SourceConfigure(Source source, stream_config_key key, uint32 value);

/*!
    @brief Request to close the source
    @param source The source to close
    
    @return TRUE if the source could be closed, else FALSE
    otherwise.

    Source stream can be closed only if the requested source stream
    is not connected to any stream. If the requested stream is
    connected, then TransformDisconnect or StreamDisconnect
    should be called before SourceClose.

    Some sources, such as RFCOMM connections or the USB
    hardware, have a lifetime defined by other means, and cannot be
    closed using this call.
    And audio ADC and Digital mic sources which have sidetone enabled
    also cannot be closed until the sidetone is disabled.

    For Pipe streams, a SourceClose(Src) call shall close the source of that
    stream and the corresponding sink of the other stream, with which this
    stream shares the common buffer. Also, any transform that exists on these
    source or sink shall get disconnected.
    
    @note
    For operator source stream, this trap always returns FALSE.
*/
bool SourceClose(Source source);

/*!
    @brief Request to synchronise two Sources
    @param source1 The first Source to be synchronised
    @param source2 The second Source to be synchronised
    
    @return TRUE if the Sources are synchronised successfully, else FALSE.

    Call this function to synchronise timing drifts between two
    source streams before calling a StreamConnect
*/
bool SourceSynchronise(Source source1, Source source2);

#endif
