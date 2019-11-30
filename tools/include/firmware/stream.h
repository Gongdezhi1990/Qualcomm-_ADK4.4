/*
 * Copyright (c) 2018 Qualcomm Technologies International, Ltd.
 * This file was automatically generated for firmware version 22.0
 */

#ifndef __STREAM_H

#define __STREAM_H

#include <csrtypes.h>
/*! @file stream.h @brief Sources and sinks of 8-bit data
**
**
The Stream API provides functions for efficiently processing streams of eight bit data.
Available streams include RFCOMM, L2CAP, the serial port, USB endpoints and files.
**
Streams are classified into sources (which can be read) and sinks (which can be written).
*/
#include <bdaddr_.h>
#include <source_.h>
#include <sink_.h>
#include <transform_.h>
#include <app/vm/vm_if.h>
#include <app/file/file_if.h>
#include <app/uart/uart_if.h>
#include <app/stream/stream_if.h>
#include <app/usb/usb_if.h>
#include <app/partition/partition_if.h>
#include <operator_.h>
/*!
@brief Get the Source for the specified stream-based BCSP#13 channel.
@param channel The channel to fetch the Source for.
*/
#define StreamHostSource(channel) StreamSourceFromSink(StreamHostSink(channel))
/*!
@brief Find the Source associated with the raw UART.
**
**
Returns zero if it is unavailable (for example the appropriate
transport has not been configured.)
*/
#define StreamUartSource() StreamSourceFromSink(StreamUartSink())
#include <app/audio/audio_if.h>
#include <app/ringtone/ringtone_if.h>
/*!
@brief Returns a Source from the SCO stream passed.
@param handle The SCO stream from which to fetch the Source.
*/
#define StreamScoSource(handle) StreamSourceFromSink(StreamScoSink(handle))
/*!
@brief Find the Source corresponding to an RFCOMM connection.
*/
#define StreamRfcommSource(conn_id) StreamSourceFromSink(StreamRfcommSink(conn_id))
/*!
@brief Find the Source corresponding to an L2CAP connection
**
**
@param cid The connection ID to fetch the Source for.
*/
#define StreamL2capSource(cid) StreamSourceFromSink(StreamL2capSink(cid))
/*!
@brief The Source connected to the port passed on Kalimba.
@param port In the range 0..3 (BC3-MM) or 0..7 (BC5-MM)
*/
#define StreamKalimbaSource(port) StreamSourceFromSink(StreamKalimbaSink(port))
/*!
@brief Return the USB Class Request Source associated with 'interface'.
@param interface The USB interface (returned by UsbAddInterface) to fetch the Source for.
*/
#define StreamUsbClassSource(interface) StreamSourceFromSink(StreamUsbClassSink(interface))
/*!
@brief Return the USB Request Source associated with the USB transport.
@param end_point The USB endpoint (bEndPointAddress field in EndPointInfo structure) to fetch the Source for.
*/
#define StreamUsbEndPointSource(end_point) StreamSourceFromSink(StreamUsbEndPointSink(end_point))
/*!
@brief Return the USB Vendor Source associated with the USB transport.
*/
#define StreamUsbVendorSource() StreamSourceFromSink(StreamUsbVendorSink())
/*!
@brief Return the FastPipe Source for the pipe requested.
@param id The ID of the pipe needed.
*/
#define StreamFastPipeSource(id) StreamSourceFromSink(StreamFastPipeSink(id))


/*!
  @brief Move the specified number of bytes from the start of
  'source' to the end of 'sink'. 

  @param sink The Sink to move data from.
  @param source The Source to move data from.
  @param count The number of bytes to move.
  @return Zero on failure and the count on success.

  The count must be no more than both SinkSlack() and SourceBoundary().

  This call does not invalidate any active SourceMap() or SinkMap().

  @note This call will return zero if the source/sink stream is connected to another stream.

  @note
  If either source or sink is an operator source/sink stream then it always
  returns zero(0), irrespective of whether the operator source/sink stream
  is valid or not.
*/
uint16 StreamMove(Sink sink, Source source, uint16 count);

/*!
  @brief Make an automatic connection between a source and sink
  
  @param source The Source data will be taken from.
  @param sink The Sink data will be written to.

  @return An already started transform on success, or zero on failure.

  @note This call will return zero if the source/sink stream is connected to another stream.
  
  Transform created via this call is started implicitly. It is not 
  desired to start or stop such transforms by invoking @a TransformStart()
  or @a TransformStop() respectively from the application.
*/
Transform StreamConnect(Source source, Sink sink);

/*!
  @brief Dispose of all data arriving on the specified source by throwing it
  away.

  @param source The source whose data is to be disposed of.

  @return FALSE on failure, TRUE on success.

  On success the source is effectively connected using StreamConnect();
  you can stop discarding data from the source by calling
  StreamDisconnect(source, 0).

  @note This call will return FALSE if the source stream is connected to another stream.
*/
bool StreamConnectDispose(Source source);

/*!
  @brief Break any existing automatic connection involving the source *or* sink.

  @param source The Source to check for connections.
  @param sink The Sink to check for connections.

  Source or sink may be zero.
*/
void StreamDisconnect(Source source, Sink sink);

/*! 
    @brief Configure the stream subsystem.
    
    @param key Keys are defined in #vm_stream_config_key.
    @param value The value to set \e key to.

    @return TRUE if the configure worked, FALSE if the configure failed.

    Reasons for a FALSE return value include attempting to use an invalid \e key,
    attempting to use a \e key not supported in the current firmware build and 
    attempting to use a \e value that is not suitable for the \e key being used.

    The application will be panicked if it attempts to enable or
    disable streams when any corresponding L2CAP/RFCOMM connection is
    open.

    Note that this trap is also used to enable/disable an application's interest
    in receiving certain messages (eg.see keys #VM_STREAM_USB_ALT_IF_MSG_ENABLED
    and #VM_STREAM_USB_ATTACH_MSG_ENABLED).

    This trap is also used to enable L2CAP large buffers for particular PSM
    using key #VM_STREAM_L2CAP_ADD_LARGE_BUFFER_ON_PSM and remove all large 
    buffer information using key #VM_STREAM_L2CAP_REMOVE_ALL_LARGE_BUFFER.
    #VM_STREAM_L2CAP_ADD_LARGE_BUFFER_ON_PSM key should be used to configure 
    before sending or accepting L2CAP connection request.
*/
bool StreamConfigure(vm_stream_config_key key, uint16 value);

/*!
  @brief Find the Source from its Sink.
  @param sink The Sink whose source is required.
      
  @note
  If the sink is an operator sink stream then this trap always returns zero(0),
  because BlueCore firmware can not convert operator sink stream into operator 
  source stream.
*/
Source StreamSourceFromSink(Sink sink);

/*!
  @brief Find the Sink from its Source.
  @param source The source whose sink is required.
        
  @note
  If the source is an operator source stream then this trap always returns
  zero(0), because BlueCore firmware can not convert operator source stream
  into an operator sink stream.
*/
Sink StreamSinkFromSource(Source source);

/*!
  @brief Create a source from a region of memory. 

  @param data The memory that the source will be created from.
  @param length The size of the memory region.

  This function allows a region of memory to be treated as a source.
  This is useful when there is a requirement to handle data (held in a
  known region of memory) using functions that expect a source, e.g.
  StreamConnect(), in order to efficiently transfer the data without
  having to copy it.

  It is important that the memory being treated as a source persists
  long enough for the stream operation to complete, i.e., long enough
  for the source to be read. The source created using this function
  only exists while the data is being read. However, the memory block
  being treated as a source is not freed by the stream subsystem once
  the data has been read. It remains the caller's responsibility to
  manage the memory and free it when it is appropriate to do so.

  If length is zero then 0 is returned.
*/
Source StreamRegionSource(const uint8 *data, uint16 length);

/*!
  @brief Get the Sink for the specified stream-based BCSP#13 channel.
  @param channel The channel to fetch the Sink for.
*/
Sink StreamHostSink(uint16 channel);

/*!
  @brief Find the Sink associated with the raw UART.

  Returns zero if it is unavailable (for example the appropriate
  transport has not been configured.)
*/
Sink StreamUartSink(void);

/*!
  @brief Dynamically configure the UART settings. 

  @param rate The UART rate to use.
  @param stop The UART stop to use.
  @param parity The UART parity to use.

  Ignored unless raw access to the UART is enabled.
*/
void StreamUartConfigure(vm_uart_rate rate, vm_uart_stop stop, vm_uart_parity parity);

/*!
  @brief Returns a source for a synthesised sequence of notes.

  @param ringtone This must be a pointer to an array of ringtone notes.

  If the ringtone_note* passed is invalid, the function returns 0.

  See \ref playing_ringtones for details of how to construct
  the \e ringtone argument.
*/
Source StreamRingtoneSource(const ringtone_note* ringtone);

/*!
    @brief Request to create an audio source
    @param hardware The audio hardware which would be reserved as a source
    @param instance The audio hardware instance (meaning depends on \e hardware)
    @param channel The audio channel (meaning depends on \e hardware)
    
    @return The Source ID associated with the audio hardware.
*/
Source StreamAudioSource(audio_hardware hardware, audio_instance instance, audio_channel channel);

/*!
    @brief Request to create an audio sink
    @param hardware The audio hardware which would be reserved as a sink
    @param instance The audio hardware instance (meaning depends on \e hardware)
    @param channel The audio channel (meaning depends on \e hardware)
    
    @return The Sink ID associated with the audio hardware.
*/
Sink StreamAudioSink(audio_hardware hardware, audio_instance instance, audio_channel channel);

/*!
   @brief Returns a Sink from the SCO stream passed.
   @param handle The SCO stream from which to fetch the Sink.
*/
Sink StreamScoSink(uint16 handle);

/*!
  @brief Find the Sink corresponding to an RFCOMM connection.
*/
Sink StreamRfcommSink(uint16 conn_id);

/*!
  @brief Find the Sink corresponding to an L2CAP connection

  @param cid The connection ID to fetch the Sink for.
*/
Sink StreamL2capSink(uint16 cid);

/*!
  @brief Find all the sinks connected to a given Bluetooth address. 

  @param max Stores up to *max sinks in the array given, and updates *max. 
  @param sinks The array of sinks to store into.
  @param taddr The Bluetooth address to use.

  @return TRUE if there was enough space, FALSE if some had to be discarded.
*/
bool StreamSinksFromBdAddr(uint16 *max, Sink *sinks, const tp_bdaddr *tpaddr);

/*!
  @brief Return a source with the contents of the specified file.

  @param index the file whose contents are requested

  @return 0 if index is #FILE_NONE, or does not correspond to a narrow file.
*/
Source StreamFileSource(FILE_INDEX index);

/*!
  @brief The Sink connected to the port passed on Kalimba.
  @param port In the range 0..3 (BC3-MM) or 0..7 (BC5-MM)
*/
Sink StreamKalimbaSink(uint16 port);

/*!
  @brief Return a source with the contents of the specified I2C address.
  @param slave_addr The slave address of the device to read data from.
  @param array_addr The array address to read data from.
  @param size The amount of data (in bytes) to read.

  @return The source associated with the I2C stream.
*/
Source StreamI2cSource(uint16 slave_addr, uint16 array_addr, uint16 size);

/*!
   @brief Return the USB Class Request Sink.
   @param interface The USB interface (returned by UsbAddInterface) to fetch the Sink for. 
*/
Sink StreamUsbClassSink(UsbInterface interface);

/*!
   @brief Return the USB Request Sink associated with the USB transport.
   @param end_point The USB endpoint (bEndPointAddress field in EndPointInfo structure) to fetch the Sink for.
*/
Sink StreamUsbEndPointSink(uint16 end_point);

/*!
   @brief Return the USB Vendor Sink associated with the USB transport.
*/
Sink StreamUsbVendorSink(void);

/*!
    @brief Return the FastPipe Sink for the pipe requested.
    @param id The ID of the pipe needed.
*/
Sink StreamFastPipeSink(uint16 id);

/*!
  @brief Return the sink corresponding to the shunt for the given L2CAP CID on the given ACL
  @param acl the ACL connection handle (from the host)
  @param cid the L2CAP connection id (from the host)
*/
Sink StreamShuntSink(uint16 acl, uint16 cid);

/*!
  @brief Find the Source corresponding to an ATT connection with a specific
         connection id and attribute handle.
  @param cid The channel id to get the connection source id for.
  @param handle The attribute handle to get the connection source id for.

  @return Source on success or zero on failure.
*/
Source StreamAttSource(uint16 cid, uint16 handle);


/*!
  @brief Add an attribute handle corresponding to an ATT connection with a specific
         connection id.

         The number available streams is limited, and can change in the future, and 
         therefore the application shall always check the return value for being NULL
         
  @param cid The channel id to get the connection source id for.
  @param handle The attribute handle to get the connection source id for.
  @return Source in case of successful addition or zero on failure.
*/
Source StreamAttSourceAddHandle(uint16 cid, uint16 handle);

/*!
  @brief Open a sink to erase and write to an external flash partition.
  This function will perform a flash erase on the entire partition specified
  and then provide a Sink to allow it to be written from the start.

  @param device device to which to write, cannot be internal flash,
  see #partition_filesystem_devices

  @param partition partition number to overwrite

  @return Sink if partition found or sink already exists, else return NULL. 
  If this trap is used on a partition which already has a partition sink open
  then the same sink is returned rather than creating a new sink.

  \note
  If the VM application uses the VM software watchdog functionality, BlueCore
  firmware automatically extends the VM software watchdog before the erase of
  an external serial flash memory. Erasing of the external serial flash memory
  is time consuming. This ensures that the VM application is given enough time
  to kick the VM software watchdog when the operation has completed.

  \note
  This trap expects all the partitions in the #PARTITION_SERIAL_FLASH 
  device to be sector aligned. If partition is not sector aligned then
  firmware will erase shared sectors (i.e., end of previous partition's 
  sector or start of next partition's sector).

  \note
  If the total number of octets committed to the sink is odd then the last octet 
  will be cached until any of the following events occur:
  1. Associated sink stream is closed.
  2. New data is provided to the sink such that total number of octets
     committed to the sink will become even.  
*/
Sink StreamPartitionOverwriteSink(partition_filesystem_devices device, uint16 partition);

/*!
  @brief Remove all attribute handles corresponding to an ATT connection registered with
         StreamAttSourceAddHandle.
         
  @param  cid  The channel id of the ATT connection

  @return bool TRUE in case of successful deletion otherwise FALSE
*/
bool StreamAttSourceRemoveAllHandles(uint16 cid);

/*!
  @brief Open a sink to erase and write to an external serial flash.
  This function will perform a chip erase on the entire serial flash including partition table 
  and then provide a Sink to allow it to be written from the start.

  @param device device which needs to be reformatted, cannot be internal flash

  @return The sink associated with reformatting of the serial flash.

  \note
  If the VM software watchdog is not disabled, BlueCore firmware
  extends the VM software watchdog before chip erase operation. Erase
  to an external serial flash is time consuming. This ensures that the
  VM application is given enough time to kick the VM software watchdog
  once erase to an external serial flash is over.
*/
Sink StreamReformatSerialFlashSink(partition_filesystem_devices device);

/*!
  @brief Resume external flash sink partition after a controlled power failure.

  @param device device to which to write, cannot be internal flash,
  see #partition_filesystem_devices.  
  @param partition_no partition number of the sink partition to be resumed.
  @param first_word first word of the sink partition to be resumed.

  @return Sink if partition found or sink already exists, else return NULL. 
  If this trap is used on a partition which already has a partition sink open
  then the same sink is returned rather than resuming the sink.

  This VM trap is used to resume sink stream to write into external flash
  partition which got interrupted while writing previously. This trap returns
  the sink stream by reopening the stream for the interrupted external flash
  partition. This trap will not erase the contents of the partition.
  See #PartitionSinkGetPosition trap description to know how to retrieve the
  sink position from which the data can be written.

*/
Sink StreamPartitionResumeSink(partition_filesystem_devices device, uint16 partition_no, uint16 first_word);

/*!
  @brief Gets operator source stream for the operator
  @param opid Operator, which was created in the DSP
  @param terminal Source stream connection number for the specified operator
  @return Operator source stream, if it is successful, otherwise zero(0).

  This trap checks validity of the operator and its specified source terminal
  number. If the supplied input parameters are valid then it provides the
  operator source stream.

  @note
  This API returns zero(0) in either one of the below mentioned scenarios:
  1. Operator is not valid
  2. Source terminal ID is not valid with regards to the supplied operator.
*/
Source StreamSourceFromOperatorTerminal(Operator opid, uint16 terminal);

/*!
  @brief Gets operator sink stream for the operator
  @param opid Operator, which was created in the DSP
  @param terminal Sink stream connection number for the specified operator
  @return Operator sink stream, if it is successful, otherwise zero(0).

  This API checks validity of the operator and its specified sink terminal
  number. If the supplied input parameters are valid then it provides the
  operator sink stream.

  @note
  This API returns zero(0) in either one of the below specified scenarios:
  1. Operator is not valid
  2. Sink terminal ID is not valid with regards to the supplied operator.
*/
Sink StreamSinkFromOperatorTerminal(Operator opid,  uint16 terminal);

/*!
  @brief Find the Sink corresponding to a CSB transmitter stream.

  @param lt_addr The logical transport address used for CSB link.

  @return Sink if CSB transmitter stream exists for a given lt_addr otherwise
  NULL.
*/
Sink StreamCsbSink(uint16 lt_addr);

/*!
  @brief Find the Source corresponding to a CSB receiver stream. 

  @param lt_addr The logical transport address used for CSB link.
  @param remote_addr The remote device bluetooth address.

  @return Source if CSB receiver stream exists for the given parameters
  otherwise NULL.
*/
Source StreamCsbSource(const bdaddr *remote_addr, uint16 lt_addr);

/*!
  @brief Erase an external flash partition without blocking VM.
  This function will perform flash erase on the entire partition specified
  without blocking the VM application.

  @param device device of whose partition to erase, cannot be internal flash,
  see #partition_filesystem_devices.

  @param partition partition number to erase.

  @return the error code #partition_erase_start_status

  @note
  Partition erase will happen in background sector by sector. If multiple
  partitions are triggered by VM application, these partitions will be erased
  serially. Completion status of erase operation will be informed by firmware
  to application using MESSAGE_PARTITION_ERASE_RESULT message. This message
  will be sent on system task. On receiving the message, application
  is required to call StreamPartitionOverwriteSink() to get the sink id.

  @note
  This trap expects all the partitions in the #PARTITION_SERIAL_FLASH device to
  be sector aligned. If partition is not sector aligned, then firmware might
  erase shared sectors (i.e. end of previous partition's sector or start of
  next partition's sector).

*/
partition_erase_start_status StreamPartitionBackgroundErase(partition_filesystem_devices device, uint16 partition);

/*!
  @brief Return the progress of an on-going partition erase
  This function will return the remaining number of sectors to be erased in
  an external serial flash partition during on-going partition erase.

  @param device device of whose partition is getting erased, cannot be
  internal flash, see #partition_filesystem_devices.

  @param partition partition number

  @return the remaining number of sectors to be erased in a partition

  @note
  This trap will return zero if an erase operation of a given partition is not
  in progress or if an invalid partition information is passed to the trap.

*/
uint16 StreamPartitionBgEraseStatus(partition_filesystem_devices device, uint16 partition);

/*!
  @brief Enable or Disable the sidetone ADC channels and the corresponding connected DAC channels.

  @param enable TRUE to enable ADC sidetone channels and corresponding
   connected DAC channels, FALSE to disable them. 

  @return TRUE if sidetone is enabled otherwise FALSE 

  @note
   Using this trap, ADC and DAC channels are enabled without being 
   connected to corresponding Stream end point i.e., ADC is enabled 
   without being stream connected to a sink and DAC is enabled without
   being connected to audio source. 
   Here, ADCs are connected to dummy buffers to write into and DACs are 
   connected to silence buffer to read from.
   To use this trap it is required to have a valid sidetone mask set on
   DAC and #STREAM_CODEC_INDIVIDUAL_SIDETONE_ENABLE enabled.
*/
bool StreamEnableSidetone(bool enable);

/*!
  @brief Find the Server Sink corresponding to an ATT connection with a specific
         connection id.
  @param cid The channel id to get the connection source id for.

  @return Sink on success or zero on failure.
*/
Sink StreamAttSink(uint16 cid);

/*!
  @brief Create a bi-directional Pipe Stream to transfer data

  @param sink_a Address of the sink of stream a
  @param sink_b Address of the sink of stream b
  @param size_a_to_b Size of the buffer to transfer data from stream a to
  stream b
  @param size_b_to_a Size of the buffer to transfer data from stream b to
  stream a

  @return TRUE if the Pipe Stream is created successfully, else FALSE

  @note
  This trap creates two streams with buffers. sink of stream a and source of
  stream b share a common buffer and forms one Pipe. Similarly, sink of stream
  b and source of stream a share another common buffer and forms the second
  Pipe.

  Data arriving at one end of the pipe will be automatically available at the
  other end of the pipe. For example: Data arriving at sink of stream a will be
  automatically available at source of stream b and data arriving at sink of
  stream b will be automatically available at source of stream a. Application
  must pass a valid buffer size for both the interconnected buffers of stream a
  and stream b or else this trap will return FALSE. Passing the size as either
  Zero or greater than the supported buffer memory size is considered as
  invalid size. Typically, the maximum supported buffer memory size is lesser
  than 4KB. It is also strongly recommended not to use buffer memory with
  large size

  @note Destroying the entire pipe stream requires the application to
  individually invoke close (on either the sink or source) of both the pipes.
  In order to destroy the Pipe Stream, Application can call either
  SourceClose() or SinkClose() trap. Closing one of the Pipe ends
  (source or sink) shall also close the source or sink of the other end.
  However, the other pipe and hence it's corresponding source and sink will
  remain active. In order to destroy the other pipe, application needs to call
  either SourceClose() or SinkClose() again on the other pipe. Closing any one
  pipe using SourceClose() or SinkClose() trap will not invalidate the source
  and sink ids since these are required to retrieve the sink or source of the
  other pipe using either StreamSourceFromSink() or StreamSinkFromSource() trap.

  Usage:
  Sink A, B;
  StreamPipePair(&A, &B, 512, 512);
  Sink U;
  U = StreamUartSink();
  StreamConnect(StreamSourceFromSink(A), U);
*/
bool StreamPipePair(Sink *sink_a, Sink *sink_b, uint16 size_a_to_b, uint16 size_b_to_a);

/*!
  @brief Find the ATT Server Source corresponding to an ATT connection with a specific
         connection id.
  @param cid The channel id to get the connection source id for.

  @return Source on success or zero on failure.
*/
Source StreamAttServerSource(uint16 cid);

/*!
  @brief Find the ATT Client Source corresponding to an ATT connection with a specific
         connection id.
  @param cid The channel id to get the connection source id for.

  @return Source on success or zero on failure.
*/
Source StreamAttClientSource(uint16 cid);

/*!
  @brief Add an attribute handle corresponding to an ATT source stream specified
         with source id.

         The number available streams is limited, and can change in the future, and 
         therefore the application shall always check the return value for being FALSE
         
  @param source The source stream id of the ATT stream.
  @param handle The attribute handle to be added to the specifed source stream.
  @return TRUE in case of successful addition or FALSE on failure.
*/
bool StreamAttAddHandle(Source source, uint16 handle);

/*!
  @brief Remove all attribute handles corresponding to an ATT source stream registered with
         StreamAttAddHandle or StreamAttSourceAddHandle.
         
  @param  source  The source stream id in use.

  @return bool TRUE in case of successful deletion otherwise FALSE
*/
bool StreamAttRemoveAllHandles(Source source);

/*!
  @brief Find the Client Sink corresponding to an ATT connection with a specific
         connection id.
  @param cid The channel id to get the connection sink id for.

  @return Sink on success or zero on failure.
*/
Sink StreamAttClientSink(uint16 cid);

/*!
  @brief Find the Server Sink corresponding to an ATT connection with a specific
         connection id.
  @param cid The channel id to get the connection sink id for.

  @return Sink on success or zero on failure.
*/
Sink StreamAttServerSink(uint16 cid);

/*!
  @brief Make an automatic connection between a source and sink, or dispose it.

  @param source The Source data will be taken from.
  @param sink The Sink data will be written to.
  @return TRUE if the connection was made between \e source and \e sink;
    FALSE if the initial connection failed (in which case, if \e source was
    valid, it will have been immediately passed to StreamConnectDispose()).

  Like StreamConnect(), but if the connection could not be made then the
  source will be passed to StreamConnectDispose(). Similarly, if the
  connection is subsequently broken using StreamDisconnect() or by the
  sink being closed the source will be passed to StreamConnectDispose().

  The end result is that the source will be tidied up correctly, no
  matter what happens after this call.

  Note that the task associated with the source will be
  changed. Messages related to the source will no longer be sent to
  the task previously associated with it.
*/
bool StreamConnectAndDispose(Source source, Sink sink);

#endif
