// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CBUFFER_DEFINES_HEADER_INCLUDED
#define CBUFFER_DEFINES_HEADER_INCLUDED


// MMU port identifier masks
#if defined(KAL_ARCH5)
   // -- rick --
   #define CBUFFER_NUM_PORTS                   (12)
   #define CBUFFER_NUM_MMU_PORTS               (12)
   #define CBUFFER_WRITE_PORT_OFFSET           (0x00000C)
   #define CBUFFER_PORT_NUMBER_MASK            (0x00000F)
   #define CBUFFER_TOTAL_PORT_NUMBER_MASK      (0x00001F)
   #define CBUFFER_TOTAL_CONTINUOUS_PORTS      (12)

#elif defined(KAL_ARCH3)
   // -- BC7 onwards --
   #if defined(GORDON)
      #define CBUFFER_NUM_PORTS                   (12)
      #define CBUFFER_NUM_MMU_PORTS               (11)
      #define CBUFFER_WRITE_PORT_OFFSET           (0x00000C)
      #define CBUFFER_PORT_NUMBER_MASK            (0x00000F)
      #define CBUFFER_TOTAL_PORT_NUMBER_MASK      (0x00001F)
      #define CBUFFER_TOTAL_CONTINUOUS_PORTS      (8)
   #else
      #define CBUFFER_NUM_PORTS                   (8)
      #define CBUFFER_NUM_MMU_PORTS               (8)
      #define CBUFFER_WRITE_PORT_OFFSET           (0x000008)
      #define CBUFFER_PORT_NUMBER_MASK            (0x000007)
      #define CBUFFER_TOTAL_PORT_NUMBER_MASK      (0x00000F)
      #define CBUFFER_TOTAL_CONTINUOUS_PORTS      (8)
   #endif
#endif

#define CBUFFER_MMU_PAGE_SIZE                   (64)

#define CBUFFER_CALLBACK_PORT_DISCONNECT        (0)
#define CBUFFER_CALLBACK_PORT_CONNECT           (1)

#define CBUFFER_READ_PORT_MASK                  (0x800000)
#define CBUFFER_WRITE_PORT_MASK                 (CBUFFER_READ_PORT_MASK + CBUFFER_WRITE_PORT_OFFSET)


// MMU port force masks
// -- BC5MM onwards --
// force 'endian' constants
#define CBUFFER_FORCE_ENDIAN_MASK               (0x300000)
#define CBUFFER_FORCE_ENDIAN_SHIFT_AMOUNT       (-21)
#define CBUFFER_FORCE_LITTLE_ENDIAN             (0x100000)
#define CBUFFER_FORCE_BIG_ENDIAN                (0x300000)

// force 'sign extend' constants
#define CBUFFER_FORCE_SIGN_EXTEND_MASK          (0x0C0000)
#define CBUFFER_FORCE_SIGN_EXTEND_SHIFT_AMOUNT  (-19)
#define CBUFFER_FORCE_SIGN_EXTEND               (0x040000)
#define CBUFFER_FORCE_NO_SIGN_EXTEND            (0x0C0000)

// force 'bit width' constants
#define CBUFFER_FORCE_BITWIDTH_MASK             (0x038000)
#define CBUFFER_FORCE_BITWIDTH_SHIFT_AMOUNT     (-16)
#define CBUFFER_FORCE_8BIT_WORD                 (0x008000)
#define CBUFFER_FORCE_16BIT_WORD                (0x018000)
#define CBUFFER_FORCE_24BIT_WORD                (0x028000)
#define CBUFFER_FORCE_32BIT_WORD                (0x038000)

// force 'saturate' constants
#define CBUFFER_FORCE_SATURATE_MASK             (0x006000)
#define CBUFFER_FORCE_SATURATE_SHIFT_AMOUNT     (-14)
#define CBUFFER_FORCE_NO_SATURATE               (0x002000)
#define CBUFFER_FORCE_SATURATE                  (0x006000)

// force 'padding' constants
#define CBUFFER_FORCE_PADDING_MASK              (0x001C00)
#define CBUFFER_FORCE_PADDING_SHIFT_AMOUNT      (-11)
#define CBUFFER_FORCE_PADDING_NONE              (0x000400)
#define CBUFFER_FORCE_PADDING_LS_BYTE           (0x000C00)
#define CBUFFER_FORCE_PADDING_MS_BYTE           (0x001400)

// force 'defaults for pcm audio' constants
#define CBUFFER_FORCE_PCM_AUDIO                 ($cbuffer.FORCE_LITTLE_ENDIAN + \
                                                 $cbuffer.FORCE_SIGN_EXTEND + \
                                                 $cbuffer.FORCE_SATURATE)
#define CBUFFER_FORCE_24B_PCM_AUDIO             ($cbuffer.FORCE_LITTLE_ENDIAN + \
                                                 $cbuffer.FORCE_32BIT_WORD + \
                                                 $cbuffer.FORCE_PADDING_MS_BYTE + \
                                                 $cbuffer.FORCE_NO_SATURATE);
// force 'defaults for raw 16bit data' constants
#define CBUFFER_FORCE_16BIT_DATA_STREAM         ($cbuffer.FORCE_BIG_ENDIAN + \
                                                 $cbuffer.FORCE_NO_SIGN_EXTEND + \
                                                 $cbuffer.FORCE_NO_SATURATE)

#endif
