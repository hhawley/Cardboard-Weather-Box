#!/usr/bin/env python

"""
This script reads from the Weather API and sends
the information to the display which is a LCD 16x2
"""
import time
import serial
import pyowm

# PORT constants
PORT_NAME = 'COM12'

# API keys
API_KEY = 'YOUR API KEY'
OWM = pyowm.OWM(API_KEY)
MANAGER = OWM.weather_manager()
KINGSTON_CITY_STR = 'YOUR, CITY'
SHOW_CITY = KINGSTON_CITY_STR + '    '

class MachineState():
    """docstring for MachineState"""
    def __init__(self, name):
        self.name = name
        self.conditions = {}
        self.start_func = None
        self.run_func = None
        self.finish_func = None


    def new_condition(self, condition, output_state_name):
        """
            condition -> a function that takes one or more parameters
            and returns true or false
        """
        self.conditions[output_state_name] = condition

    def check_conditions(self, new_parameters):
        for new_state_name, condition in self.conditions:
            if condition(new_parameters):
                return new_state_name

        # Just return the current name if no condition is met
        return self.name

    def run(self, new_parameters):
        return self.check_conditions(new_parameters)

class API_FSM():
    """docstring for API_FSM"""
    def __init__(self):
        self.current_state = None
        self.states = {}

    def add_state(self, name, state):
        self.states[name] = state

    def run(self, new_parameters):
        new_state_name = self.current_state.run(new_parameters)

        if new_state_name != self.current_state.name:
            self.current_state = self.states[new_state_name]

def write_char(port, char, addr):
    """
        The FPGA Accepts commands only in the form
            w ADDR CHAR\r
        where ADDR, and CHAR are in HEX format.
        This function takes care of all the nuisances of sending a command.

        Function does not send command if ADDR below 0 or higher than 32.
        As the LCD only has 32 total chars
    """
    if (addr < 0) or (addr > 32):
        return

    # ord -> turns char into int
    # hex -> turn int into hex string
    # [2:] -> removes the 0x from hex string
    cmd = f'w { hex(ord(char))[2:] } { hex(addr)[2:] }\r'
    port.write(cmd.encode('utf-8'))

def send_string(port, out_string):
    """
        Send a string to the FPGA, pads with empty spaces if string is not
        long enough
    """
    if len(out_string) >= 36:
        for i in range(0, 36):
            write_char(port, out_string[i], i)
    else:
        i = 0
        for out_char in out_string:
            write_char(port, out_char, i)
            i += 1

        for j in range(0, 36 - len(out_string)):
            write_char(port, ' ', i + j)

# STATES
READ_WEATHER_DATA = 0
STANDBY = 1
EXIT = 2

# Standby SUB states
STANDBY_STATUS = 0
STANDBY_TEMPERATURE = 1
STANDBY_WIND = 2
STANDBY_RAIN = 3
STANDBY_CLOUDS = 4
STANDBY_HUMIDITY = 5
STANDBY_SNOW = 6

current_state = READ_WEATHER_DATA
current_standby_state = STANDBY_STATUS
current_weather = None

INIT_TIME = time.time()
current_time = INIT_TIME

with serial.Serial(port=PORT_NAME, baudrate=500000) as port:
    while True:

        try:
            current_time = abs(time.time() - INIT_TIME)

            if current_state == STANDBY:
                if current_time > 3600:
                    INIT_TIME = time.time()
                    current_state = READ_WEATHER_DATA
                else:
                    current_state = STANDBY

                if current_standby_state == STANDBY_STATUS:
                    #print(current_weather.detailed_status)

                    send_string(port, SHOW_CITY + current_weather.detailed_status)

                    current_standby_state = STANDBY_TEMPERATURE

                elif current_standby_state == STANDBY_TEMPERATURE:
                    temps = current_weather.temperature('celsius')
                    #print(temps)

                    temp = temps['temp']
                    temp_feelslike = temps['feels_like']

                    send_string(port, SHOW_CITY + f'T={temp:2.0f}, Tfl={temp_feelslike:2.0f}')
                    current_standby_state = STANDBY_HUMIDITY

                elif current_standby_state == STANDBY_HUMIDITY:
                    humidity = current_weather.humidity
                    #print(humidity)

                    send_string(port, SHOW_CITY + f'Humidity={humidity}%')
                    current_standby_state = STANDBY_WIND

                elif current_standby_state == STANDBY_WIND:
                    winds = current_weather.wind()
                    #print(winds)

                    wind_speed = winds['speed']
                    send_string(port, SHOW_CITY + f'Wind speed={wind_speed}')

                    if current_weather.status == 'Rain':
                        current_standby_state = STANDBY_RAIN
                    elif current_weather.status == 'Snow':
                        current_standby_state = STANDBY_SNOW
                    else:
                        current_standby_state = STANDBY_STATUS

                elif current_standby_state == STANDBY_RAIN:
                    rains = current_weather.rain
                    #print(rains)

                    if len(rains) == 0:
                        send_string(port, SHOW_CITY + f'No rain as now.')
                    else:
                        send_string(port, SHOW_CITY + f'1h: {rains["1h"]}mm')

                    current_standby_state = STANDBY_STATUS

                elif current_standby_state == STANDBY_SNOW:
                    snows = current_weather.snow
                    #print(snows)

                    if len(snows) == 0:
                        send_string(port, SHOW_CITY + f'No snow as now.')
                    else:
                        send_string(port, SHOW_CITY + f'1h: {snows["1h"]}mm')

                    current_standby_state = STANDBY_STATUS

                time.sleep(2)

            elif current_state == READ_WEATHER_DATA:
                print('Reading from weather API...')
                weather_info = MANAGER.weather_at_place(KINGSTON_CITY_STR)
                current_weather = weather_info.weather

                if current_state is not None:
                    print('Reading from weather API success!')
                    current_state = STANDBY

            elif current_state == EXIT:
                print('Exiting program, thanks!')
                break

            # Unknown state, go to standby state
            else:
                current_state = STANDBY
        except KeyboardInterrupt:
            current_state = EXIT
