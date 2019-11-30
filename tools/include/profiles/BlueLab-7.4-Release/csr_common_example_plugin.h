/****************************************************************************
Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.

FILE NAME
   csr_common_example_plugin.h

DESCRIPTION
    
    
NOTES
   
*/
#ifndef _CSR_COMMON_EXAMPLE_PLUGIN_H_
#define _CSR_COMMON_EXAMPLE_PLUGIN_H_

#include <message.h> 

/*!  audio plugin
   This is an audio plugin that can be used with the audio library.
*/

typedef struct
{
   TaskData   data;
   unsigned	  example_plugin_variant:4;   /* Selects the example plugin variant */
   unsigned   two_mic:1;                  /* Set the bit if using 2mic plugin */
   unsigned   reserved:11;                /* Set the reserved bits to zero */
}ExamplePluginTaskdata;


#endif

