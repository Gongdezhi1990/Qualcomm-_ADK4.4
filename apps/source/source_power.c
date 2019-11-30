/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_power.c

DESCRIPTION
    Handles power readings when running as a self powered device.    

*/


/* header for this file */
#include "source_power.h"
/* application header files */
#include "source_debug.h"
#include "source_led_handler.h" 
#include "source_states.h"
#include "Source_configmanager.h" 
#include "source_memory.h"
#include "source_power_manager_config_def.h"
#include "source_private_data_config_def.h"
#include "source_aghfp_data_config_def.h"
#include "source_a2dp_config_def.h"
/* VM headers */
#include <charger.h>
#include <panic.h>
#include <psu.h>
/* profile/library headers */
#include <power.h>

#ifdef DEBUG_POWER
    #define POWER_DEBUG(x) DEBUG(x)
#else
    #define POWER_DEBUG(x)
#endif

/* Power table entries for Sniff mode */
#define POWER_TABLE_ENTRIES                             10

/* PSKey configurable sniff parameters */
typedef struct
{
    unsigned unused:8;
    unsigned number_a2dp_entries:4;
    unsigned number_aghfp_entries:4;
    lp_power_table *a2dp_powertable;
    lp_power_table *aghfp_powertable;
} POWER_DATA_T;

POWER_DATA_T   POWER_RUNDATA = {0};

#ifdef INCLUDE_POWER_READINGS
/* function prototypes*/
static void power_set_number_of_entries(PROFILES_T profile,uint8 entries);
static void power_populate_power_table_entries(PROFILES_T profile,lp_power_table *power_table);
static void power_print_table_entries(PROFILES_T profile);
static void power_update_power_settings(power_config* config, source_power_readonly_values_config_def_t* data);
static bool power_get_power_table_values(POWER_TABLE_T  *power_table);
static void power_read_tables_entries(void);
/****************************************************************************
NAME    
    power_handle_battery_voltage
    
DESCRIPTION
    Called when the battery voltage is returned.
    
*/
static void power_handle_battery_voltage(voltage_reading vbat)
{
    power_battery_level level = vbat.level;
    
    POWER_DEBUG(("PM: Battery voltage[0x%x] level[%d]\n", vbat.voltage, vbat.level));
        
    if (!power_is_charger_connected())
    {   
        switch (states_get_state())
        {
            case SOURCE_STATE_IDLE:
            case SOURCE_STATE_CONNECTABLE:
            case SOURCE_STATE_DISCOVERABLE:
            case SOURCE_STATE_INQUIRING:
            case SOURCE_STATE_CONNECTING:
            case SOURCE_STATE_CONNECTED:
            {
                switch (level)
                {
                    case POWER_BATT_CRITICAL:
                    {
                        POWER_DEBUG(("    Critical battery\n"));

                        /* power off device */
                        states_set_state(SOURCE_STATE_POWERED_OFF);
                    }
                    break;
                    
                    case POWER_BATT_LOW:
                    {
                        POWER_DEBUG(("    Low battery\n"));
                        
#ifdef INCLUDE_LEDS            
                        /* show low battery LED */
                        leds_show_event(LED_EVENT_LOW_BATTERY);
#endif                                 
                    }
                    break;
                    
                    default:
                    {
                    }
                    break;
                }
            }
            break;
            
            default:
            {
            }
            break;
        }
    }
}


/****************************************************************************
NAME    
    power_handle_battery_temp
    
DESCRIPTION
    Called when the battery temperature is returned.
    
*/
static void power_handle_battery_temp(voltage_reading vthm)
{
    POWER_DEBUG(("PM: Battery temp voltage[0x%x] level[%d]\n", vthm.voltage, vthm.level));
    
    if (power_is_charger_connected())
    {
        /* Enable charger */
        PowerChargerEnable(TRUE);
    }
}


/****************************************************************************
NAME    
    power_handle_charge_state
    
DESCRIPTION
    Called when the charge state is returned.
    
*/
static void power_handle_charge_state(power_charger_state state)
{
    POWER_DEBUG(("PM: Charger State [%d]\n", state));
    
    switch(state)
    {
        case power_charger_trickle:
        case power_charger_fast:
        case power_charger_boost_internal:
        case power_charger_boost_external:
        {
            POWER_DEBUG(("PM: Charge In Progress\n"));
        }   
        break;
        
        case power_charger_complete:
        {
            POWER_DEBUG(("PM: Charge Complete\n"));
        }
        break;
        
        case power_charger_disconnected:
        {
            POWER_DEBUG(("PM: Charger Disconnected\n"));
        }
        break;
        
        case power_charger_disabled:
        {
            POWER_DEBUG(("PM: Charger Disabled\n"));
        }
        break;
        
        default:
        {
            POWER_DEBUG(("PM: Charger Unhandled!\n"));
        }
        break;
    }
}


/****************************************************************************
NAME    
    power_handle_charge_voltage
    
DESCRIPTION
    Called when the charge voltage is returned.
    
*/
static void power_handle_charge_voltage(voltage_reading vchg)
{
    POWER_DEBUG(("PM: Charge voltage[0x%x] level[%d]\n", vchg.voltage, vchg.level));
}
    

static void power_msg_handler(Task task, MessageId id, Message message)
{
    switch(id)
    {
        case POWER_INIT_CFM:
        {
            POWER_INIT_CFM_T *cfm = (POWER_INIT_CFM_T *)message;
            
            POWER_DEBUG(("POWER_INIT_CFM\n"));
            
            if (!cfm->success) 
                Panic();
            
            /* handle returned charge state */
            power_handle_charge_state(cfm->state);
            /* handle returned battery voltage */
            power_handle_battery_voltage(cfm->vbat);
            /* handle returned battery temperature */
            power_handle_battery_temp(cfm->vthm);
        }
        break;
        
        case POWER_BATTERY_VOLTAGE_IND:
        {
            POWER_BATTERY_VOLTAGE_IND_T *ind = (POWER_BATTERY_VOLTAGE_IND_T *)message;
            
            POWER_DEBUG(("POWER_BATTERY_VOLTAGE_IND\n"));
            
            /* handle returned battery voltage */
            power_handle_battery_voltage(ind->vbat);
        }
        break;
        
        case POWER_CHARGER_VOLTAGE_IND:
        {
            POWER_CHARGER_VOLTAGE_IND_T *ind = (POWER_CHARGER_VOLTAGE_IND_T *)message;
            
            POWER_DEBUG(("POWER_CHARGER_VOLTAGE_IND\n"));
            
            /* handle returned charge voltage */
            power_handle_charge_voltage(ind->vchg);
        }
        break;
        
        case POWER_BATTERY_TEMPERATURE_IND:
        {
            POWER_BATTERY_TEMPERATURE_IND_T *ind = (POWER_BATTERY_TEMPERATURE_IND_T *)message;
            
            POWER_DEBUG(("POWER_BATTERY_TEMPERATURE_IND\n"));
            
            /* handle returned battery temperature */
            power_handle_battery_temp(ind->vthm);
        }
        break;
        
        case POWER_CHARGER_STATE_IND:
        {
            POWER_CHARGER_STATE_IND_T *ind = (POWER_CHARGER_STATE_IND_T *)message;
            
            POWER_DEBUG(("POWER_CHARGER_STATE_IND\n"));
            
            /* handle returned charge state */
            power_handle_charge_state(ind->state);
        }
        break;
        
        default:
        {
            POWER_DEBUG(("Unhandled Power message 0x%x\n", id));
        }
        break;
    }
}


/***************************************************************************
Functions
****************************************************************************
*/

/****************************************************************************
NAME    
    power_init - Initialises the power manager.
 
*/
void power_init(void)
{
    uint16 size = 0;
    power_config config;
    source_power_readonly_values_config_def_t *ps_config = NULL;

    /* initialize the power table*/
    power_read_tables_entries();

    /* Read configuration data */
    size = configManagerGetReadOnlyConfig(SOURCE_POWER_READONLY_VALUES_CONFIG_BLK_ID, (const void **)&ps_config);

    power_update_power_settings(&config, ps_config);

     theSource->powerTask.handler = power_msg_handler;   
    PowerInit(&theSource->powerTask, &config,NULL);
     
    configManagerReleaseConfig(SOURCE_POWER_READONLY_VALUES_CONFIG_BLK_ID);

}
/****************************************************************************
NAME    
power_update_power_settings    

DESCRIPTION
    This function manipulates the Power Settings Config structure into power_config structure 
    
RETURNS
    void
*/
static void power_update_power_settings(power_config* config, source_power_readonly_values_config_def_t* data)
{
    uint16 level = 0;
    if(config && data)
    {
        config->vref.adc.period_chg = D_SEC(data->PowerConfig.p_config.vref.adc.period_chg);
        config->vref.adc.period_no_chg = D_SEC(data->PowerConfig.p_config.vref.adc.period_no_chg);
        config->vref.adc.source =  data->PowerConfig.p_config.vref.adc.source;
        
        config->vbat.adc.period_chg = D_SEC(data->PowerConfig.p_config.vbat.adc.period_chg);
        config->vbat.adc.period_no_chg = D_SEC(data->PowerConfig.p_config.vbat.adc.period_no_chg);
        config->vbat.adc.source = data->PowerConfig.p_config.vbat.adc.source;

        /* store the critical voltage as the min battery voltage */
        for (level = 0; level <= POWER_MAX_VBAT_LIMITS; level++)
        {
             config->vbat.limits[level].limit =data->PowerConfig.p_config.vbat.VBAT_Limit[level];
             config->vbat.limits[level].limit =data->PowerConfig.p_config.vbat.VBAT_Notify_Period[level];
        }

        config->vthm.adc.period_chg = D_SEC(data->PowerConfig.p_config.vthm.adc.period_chg);
        config->vthm.adc.period_no_chg = D_SEC(data->PowerConfig.p_config.vthm.adc.period_no_chg);
        config->vthm.adc.source = data->PowerConfig.p_config.vthm.adc.source;
        config->vthm.delay = data->PowerConfig.p_config.vthm.vthm_delay;
        config->vthm.drive_pio= data->PowerConfig.p_config.vthm.vthm_drive_pio;
        config->vthm.raw_limits= data->PowerConfig.p_config.vthm.VTHM_raw_limits;
        config->vthm.pio = data->PowerConfig.p_config.vthm.vthm_pio;
        memcpy(&config->vthm.limits,&data->PowerConfig.p_config.vthm.limits, POWER_MAX_VTHM_LIMITS);

        config->vchg.adc.period_chg = D_SEC(data->PowerConfig.p_config.vchg.adc.period_chg);
        config->vchg.adc.period_no_chg = D_SEC(data->PowerConfig.p_config.vchg.adc.period_no_chg);
        config->vchg.adc.source = data->PowerConfig.p_config.vchg.adc.source;
        config->vchg.limit = data->PowerConfig.p_config.vchg.VCHG_limit;
    }
}

    
/****************************************************************************
NAME    
    power_get_power_table_values -

DESCRIPTION
     Gets the power table structure values.

RETURNS
    FALSE, if the number of entries of A2DP and AGHFP are 0's.
    TRUE, if otherwise
    
*/
static bool power_get_power_table_values(POWER_TABLE_T  *power_table)
{
    source_power_table_config_def_t *power_table_tmp = NULL;
    number_of_entries_a2dp_config_def_t *a2dp_entries_ptr = NULL;
    number_of_entries_aghfp_config_def_t  *aghfp_entries_ptr  = NULL;
    bool ret = TRUE;

    if (configManagerGetReadOnlyConfig(SOURCE_POWER_TABLE_CONFIG_BLK_ID, (const void **)&power_table_tmp))
    {
        memcpy(power_table->powertable,power_table_tmp->power_table,sizeof(power_table_tmp->power_table));
    }
    configManagerReleaseConfig(SOURCE_POWER_TABLE_CONFIG_BLK_ID);

    if (configManagerGetReadOnlyConfig(NUMBER_OF_ENTRIES_A2DP_CONFIG_BLK_ID, (const void **)&a2dp_entries_ptr))
    {
       power_table->a2dp_entries = a2dp_entries_ptr->a2dp_entries;
    }
    configManagerReleaseConfig(NUMBER_OF_ENTRIES_A2DP_CONFIG_BLK_ID);

    if (configManagerGetReadOnlyConfig(NUMBER_OF_ENTRIES_AGHFP_CONFIG_BLK_ID, (const void **)&aghfp_entries_ptr))
    {
        power_table->aghfp_entries = aghfp_entries_ptr->aghfp_entries;
    }
    configManagerReleaseConfig(NUMBER_OF_ENTRIES_AGHFP_CONFIG_BLK_ID);


    if((power_table->a2dp_entries  == 0)&&(power_table->aghfp_entries == 0) )
    {
        ret = FALSE;
     }
    return ret;
}
/****************************************************************************
NAME    
    power_read_tables_entries

DESCRIPTION
    This function reads the power table entries from the power config xml file.

RETURNS
    void
    
*/
static void power_read_tables_entries(void)
{

    POWER_TABLE_T *power_table ;

    /* Read Sniff configuration */  
    power_table = (POWER_TABLE_T *)memory_create(((sizeof(lp_power_table) * POWER_TABLE_ENTRIES) + sizeof(uint16)));	    
    
     if (power_table && power_get_power_table_values(power_table)) 
     {
        power_set_number_of_entries(PROFILE_A2DP,power_table->a2dp_entries);
        power_set_number_of_entries(PROFILE_AGHFP,power_table->aghfp_entries);
        power_populate_power_table_entries(PROFILE_A2DP,power_table->powertable);
        power_populate_power_table_entries(PROFILE_AGHFP,&power_table->powertable[power_table->a2dp_entries]);
#ifdef DEBUG_PS   
        {
            power_print_table_entries(PROFILE_A2DP);
            power_print_table_entries(PROFILE_AGHFP);
        }
#endif
    }
    else
    {
        memory_free(power_table);
        POWER_DEBUG(("Power: No sniff\n"));
    }

}
/****************************************************************************
NAME    
    power_set_number_of_entries

DESCRIPTION
    This function sets the number of entries read from the xml into its corresponding profile entries.

RETURNS
    void
    
*/
static void power_set_number_of_entries(PROFILES_T profile,uint8 entries)
{
    switch(profile)
    {
        case PROFILE_A2DP:
            POWER_RUNDATA.number_a2dp_entries = entries;
            break;
        case PROFILE_AGHFP:
            POWER_RUNDATA.number_aghfp_entries = entries;
            break;
         default:
            break;
     } 
}
/****************************************************************************
NAME    
    power_print_table_entries

DESCRIPTION
    This function prints the structure values based on the profile input.

RETURNS
    void
    
*/
static void power_print_table_entries(PROFILES_T profile)
{
    uint16 i;
    switch(profile)
    {
        case PROFILE_A2DP:
            POWER_DEBUG(("POWER: Sniff; A2DP entries[%d]:\n",POWER_RUNDATA.number_a2dp_entries));
            for (i = 0; i < POWER_RUNDATA.number_a2dp_entries; i++)
            {
                POWER_DEBUG(("    state:%d min:%d max:%d attempt:%d timeout:%d time:%d\n", 
                                             POWER_RUNDATA.a2dp_powertable[i].state,
                                             POWER_RUNDATA.a2dp_powertable[i].min_interval,
                                             POWER_RUNDATA.a2dp_powertable[i].max_interval,
                                             POWER_RUNDATA.a2dp_powertable[i].attempt,
                                             POWER_RUNDATA.a2dp_powertable[i].timeout,
                                             POWER_RUNDATA.a2dp_powertable[i].time));
            }
            break;
        case PROFILE_AGHFP:
            POWER_DEBUG(("POWER: Sniff; AGHFP entries[%d]:\n", POWER_RUNDATA.number_aghfp_entries));
            for (i = 0; i < POWER_RUNDATA.number_aghfp_entries; i++)
            {
                POWER_DEBUG(("    state:%d min:%d max:%d attempt:%d timeout:%d time:%d\n", 
                                             POWER_RUNDATA.aghfp_powertable[i].state,
                                             POWER_RUNDATA.aghfp_powertable[i].min_interval,
                                             POWER_RUNDATA.aghfp_powertable[i].max_interval,
                                             POWER_RUNDATA.aghfp_powertable[i].attempt,
                                             POWER_RUNDATA.aghfp_powertable[i].timeout,
                                             POWER_RUNDATA.aghfp_powertable[i].time));
            }
            break;
        default:
             break;
    }

}
/****************************************************************************
NAME    
    power_populate_a2dp_table_entries

DESCRIPTION
    This function populates the a2dp  and aghfp power table entries.

RETURNS
    void
    
*/
static void power_populate_power_table_entries(PROFILES_T profile,lp_power_table *power_table)
{
    switch(profile)
    {
        case PROFILE_A2DP:
            memcpy(POWER_RUNDATA.a2dp_powertable,power_table,sizeof(power_table));
            break;
        case PROFILE_AGHFP:
            memcpy(POWER_RUNDATA.aghfp_powertable,power_table,sizeof(power_table));
            break;
         default:
            break;
    }
}
#endif /*INCLUDE_POWER_READINGS */
/****************************************************************************
NAME    
    power_is_charger_connected -

DESCRIPTION
        This function checks  if the charger is connected  or not

RETURNS
    bool
    
*/
bool power_is_charger_connected(void)
{
    return (ChargerStatus() != NO_POWER);
}
/****************************************************************************
NAME    
    power_get_a2dp_number_of_entries

DESCRIPTION
    This function gets the a2dp number of entries as initialized from the xml file.

RETURNS
    The number of A2DP entries read from the config block section.
    
*/
uint8 power_get_a2dp_number_of_entries(void)
{
    return POWER_RUNDATA.number_a2dp_entries ;
}
/****************************************************************************
NAME    
    power_get_aghfp_number_of_entries

DESCRIPTION
    This function gets the aghfp number of entries as initialized from the xml file.

RETURNS
    The number of AGHFP entries read from the config block section.
    
*/
uint8 power_get_aghfp_number_of_entries(void)
{
    return POWER_RUNDATA.number_aghfp_entries ;
}
/****************************************************************************
NAME    
    power_get_a2dp_power_table

DESCRIPTION
    This function gets the address of the a2dp power table entries.

RETURNS
    The pointer to the structure variable a2dp_powertable
    
*/
lp_power_table  *power_get_a2dp_power_table(void)
{
    return POWER_RUNDATA.a2dp_powertable;
}
/****************************************************************************
NAME    
    power_get_aghfp_power_table

DESCRIPTION
    This function gets the address of the aghfp power table entries.

RETURNS
    The pointer to the structure variable aghfp_powertable
    
*/
lp_power_table  *power_get_aghfp_power_table(void)
{
    return POWER_RUNDATA.aghfp_powertable;
}
