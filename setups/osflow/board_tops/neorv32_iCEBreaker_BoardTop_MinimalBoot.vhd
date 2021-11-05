-- #################################################################################################
-- # << NEORV32 - Example setup including the bootloader, for the iCEBreaker (c) Board >>            #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library iCE40;
use iCE40.components.all; -- for device primitives and macros

entity neorv32_iCEBreaker_BoardTop_MinimalBoot is
  -- Top-level ports. Board pins are defined in setups/osflow/constraints/iCEBreaker.pcf
  port (
    -- 12MHz Clock input
    iCEBreakerv10_CLK : in std_logic;
    -- UART0
    iCEBreakerv10_RX : in  std_logic;
    iCEBreakerv10_TX : out std_logic;
    -- Button inputs
    iCEBreakerv10_BTN_N: in std_logic;
    iCEBreakerv10_PMOD2_9_Button_1: in std_logic;
    iCEBreakerv10_PMOD2_10_Button_3: in std_logic;
    -- LED outputs
    iCEBreakerv10_LED_R_N : out std_logic;
    iCEBreakerv10_LED_G_N : out std_logic;
    iCEBreakerv10_PMOD2_7_LED_center : out std_logic;
    iCEBreakerv10_PMOD2_8_LED_up: out std_logic;
    iCEBreakerv10_PMOD2_3_LED_down: out std_logic;
    iCEBreakerv10_PMOD2_2_LED_right: out std_logic
  );
end entity;

architecture neorv32_iCEBreaker_BoardTop_MinimalBoot_rtl of neorv32_iCEBreaker_BoardTop_MinimalBoot is

  -- configuration --
  constant f_clock_c : natural := 12_000_000; -- Microprocessor clock frequency (Hz)

  -- internal IO connection --
  signal con_gpio_o : std_ulogic_vector(3 downto 0);
  signal con_pwm  : std_logic_vector(2 downto 0);

begin

  -- Instance the microprocessor
  -- -------------------------------------------------------------------------------------------

  -- This instance just sets the generics we want to have non-default values
  -- The default values for the rest of the generics can be seen in the vhdl file that
  -- describes the entity we are instancing here
  -- neorv32_ProcessorTop_MinimalBoot is an entity defined in
  -- rtl/processor_templates/neorv32_ProcessorTop_MinimalBoot.vhd 
  neorv32_inst: entity work.neorv32_ProcessorTop_MinimalBoot
  generic map (
    CLOCK_FREQUENCY => f_clock_c,  -- clock frequency of clk_i in Hz

    -- If changing MEM_INT_DMEM_SIZE, the linker script in sw/common/neorv32.ld
    -- must be modified to account for the different ram size, specifically this line:
    --   ram  (rwx) : ORIGIN = 0x80000000, LENGTH = DEFINED(make_bootloader) ? 512 : 8*1024
    MEM_INT_DMEM_SIZE => 8*1024 -- size of processor-internal data memory in bytes
  )
  port map (
    -- Global control --
    clk_i      => std_ulogic(iCEBreakerv10_CLK), --std_ulogic(pll_clk),
    rstn_i     => std_ulogic(iCEBreakerv10_BTN_N), --std_ulogic(pll_rstn),

    -- GPIO --
    gpio_o     => con_gpio_o,

    -- primary UART --
    uart_txd_o => iCEBreakerv10_TX, -- UART0 send data
    uart_rxd_i => iCEBreakerv10_RX, -- UART0 receive data
    uart_rts_o => open, -- hw flow control: UART0.RX ready to receive ("RTR"), low-active, optional
    uart_cts_i => '0',  -- hw flow control: UART0.TX allowed to transmit, low-active, optional

    -- PWM (to on-board RGB LED) --
    pwm_o      => con_pwm
  );

  -- IO Connection --------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------

  -- This is a hard IP that can drive leds and includes some PWMs

  RGB_inst: SB_RGBA_DRV
  generic map (
    CURRENT_MODE => "0b1",
    RGB0_CURRENT => "0b000011",
    RGB1_CURRENT => "0b000011",
    RGB2_CURRENT => "0b000011"
  )
  port map (
    CURREN   => '1',  -- I
    RGBLEDEN => '1',  -- I
    RGB2PWM  => con_pwm(2),                   -- I - blue  - pwm channel 2
    RGB1PWM  => con_pwm(1) or con_gpio_o(0),  -- I - red   - pwm channel 1 || BOOT blink
    RGB0PWM  => con_pwm(0),                   -- I - green - pwm channel 0
    RGB2     => iCEBreakerv10_PMOD2_7_LED_center,  -- O - center led in PMOD2
    RGB1     => iCEBreakerv10_LED_R_N,            -- O - red
    RGB0     => iCEBreakerv10_LED_G_N             -- O - green
  );

  -- Connect some buttons to LEDs so we know our bitstream is ok
  --iCEBreakerv10_PMOD2_8_LED_up <= NOT iCEBreakerv10_PMOD2_9_Button_1;
  --iCEBreakerv10_PMOD2_3_LED_down <= NOT iCEBreakerv10_PMOD2_10_Button_3;

  iCEBreakerv10_PMOD2_8_LED_up <= con_gpio_o(1);
  iCEBreakerv10_PMOD2_3_LED_down <= con_gpio_o(2);
  iCEBreakerv10_PMOD2_2_LED_right <= con_gpio_o(3);

end architecture;
