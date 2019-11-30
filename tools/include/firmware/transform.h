/*
 * Copyright (c) 2018 Qualcomm Technologies International, Ltd.
 * This file was automatically generated for firmware version 22.0
 */

#ifndef __TRANSFORM_H

#define __TRANSFORM_H

#include <csrtypes.h>
/*! @file transform.h @brief Transform data between sources and sinks */
#include <app/vm/vm_if.h>
#include <sink_.h>
#include <source_.h>
#include <transform_.h>


/*!
  @brief Start a transform; newly created transforms must be started.

  @param transform The transform to start.

  @return FALSE on failure, TRUE on success.

  @note
  Application shouldn't call this function for transforms created via 
  @a StreamConnect() call as those transforms are started implicitly.
*/
bool TransformStart(Transform transform);

/*!
  @brief Stop a transform,

  @param transform The transform to stop.

  @return FALSE on failure, TRUE on success.

  @note
  Application shouldn't call this function for transforms created 
  via @a StreamConnect() call. To stop data flow for such transforms, 
  application would typically call @a TransformDisconnect().
*/
bool TransformStop(Transform transform);

/*!
  @brief Disconnect and destroy a transform. 

  @param transform The transform to destroy.

  @return TRUE on success, FALSE on failure.

  The transform can no longer be used after successful disconnecting of the 
  transform.
*/
bool TransformDisconnect(Transform transform);

/*!
  @brief Report if any traffic has been handled by this transform.

  @param transform The transform to query.

  Reads and clears a bit that reports any activity on a
  transform. This can be used to detect activity on connect streams.

  @return TRUE if the transform exists and has processed data, FALSE otherwise.
          
  @note
  If the transform is connected between stream and an operator then this trap
  reports traffic by the transform. But, if the transform is connected between
  two operators inside the DSP then the trap would return FALSE.
*/
bool TransformPollTraffic(Transform transform);

/*!
  @brief Find the transform connected to a source.

  @param source The source to look for.

  @return The transform connected to the specified source, or zero if no transform or connection is active.
*/
Transform TransformFromSource(Source source);

/*!
  @brief Find the transform connected to a sink.

  @param sink The sink to look for.

  @return The transform connected to the specified sink, or zero if no transform or connection is active.
*/
Transform TransformFromSink(Sink sink);

/*!
  @brief Configure parameters associated with a transform. 

  @param transform The transform to configure.
  @param key Valid values depend on the transform.
  @param value Valid values depend on the transform.
  @return Returns FALSE if the key was unrecognised, or if the value was out of bounds, or
          if sink buffer doesn't have sufficient space to hold the packet data.
*/
bool TransformConfigure(Transform transform, vm_transform_config_key key, uint16 value);

/*!
  @brief Create a transform between the specified source and sink. 

  @param source The Source to use in the transform.
  @param sink The Sink to use in the transform.

  @return 0 on failure, otherwise the transform.

  Copies data in chunks. 

  @note
  The application must set the chunk size via TransformConfigure() before
  starting the transform. The chunk size should be an integral multiple of
  the source data size. Otherwise, data gets copied partially barring
  the last chunk.
*/
Transform TransformChunk(Source source, Sink sink);

/*!
  @brief Create a transform between the specified source and sink. 

  @param source The Source to use in the transform.
  @param sink The Sink to use in the transform.

  @return 0 on failure, otherwise the transform.

  Removes bytes from start and end of packets.
*/
Transform TransformSlice(Source source, Sink sink);

/*!
   @brief Create an ADPCM decode transform between source and sink
   
   @param source The source containing ADPCM encoded data
   @param sink   The destination sink
   
   @return 0 on failure, otherwise the transform.
*/
Transform TransformAdpcmDecode(Source source, Sink sink);

/*!
  @brief Generic HID transform supporting the following devices
        a) Boot mode mouse
        b) Report mode mouse
        c) Boot mode keyboard
        d) Report mode keyboard


  @param source The Source data will be taken from.
  @param sink The Sink data will be written to.

  @return An already started transform on success, or zero on failure.

*/
Transform TransformHid(Source source, Sink sink);

/*!
  @brief Packs Audio frames from the DSP into RTP packets. This
  trap attaches RTP stamping for the Audio packets arriving from DSP.
  It configures default codec type as SBC and also sets payload header
  size for SBC.
  
  The sequence of function calls in a VM Application which is acting as an
  encoder would be:
  1. Call the TransformRtpEncode trap.
  2. Using the TransformConfigure trap configure the required parameters:
     2.1 Codec type (APTX  / SBC / ATRAC / MP3 / AAC)
     2.2 Manage Timing (Yes/No)
     2.3 Payload header size
     2.4 SCMS Enable (Yes/No)
     2.5 SCMS Bits
     2.6 Frame period
     2.7 Packet size
  3. Call the TransformStart trap.

  @param source The media Source.
  @param sink The sink receiving the Audio Digital stream
                (typically corresponding to a Kalimba port).

  @return The transform if successful, or zero on failure.
*/
Transform TransformRtpEncode(Source source, Sink sink);

/*!
  @brief Unpacks Audio frames from Audio-RTP packets. It configures
  default codec type as SBC and also sets payload header size for SBC.

  The sequence of function calls in a VM Application which is acting as a
  decoder would be:
  1. Call the TransformRtpDecode trap.
  2. Using the TransformConfigure trap configure the required parameters:
     2.1 Codec type (APTX  / SBC / ATRAC / MP3 / AAC)
     2.2 SCMS Enable (Yes/No)
     2.3 Payload header size
     2.4 Is payload header required for DSP (Yes/No)
  3. Call the TransformStart trap

  @param source The source containing the Audio Digital stream 
                (typically corresponding to a Kalimba port).
  @param sink The media Sink.

  @return The transform if successful, or zero on failure.
*/
Transform TransformRtpDecode(Source source, Sink sink);

#endif
