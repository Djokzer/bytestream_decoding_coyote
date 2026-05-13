--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : Gain_Decoder.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  :    
--    This module implements decoding or transformation logic for gain flags
--    received from the calorimeter front-end electronics. It processes the 
--    2-bit encoded gain input and outputs a formatted 2-bit gain value, 
--    possibly with pipeline stages.
--
--  Interface    :
--    - `clk`, `reset` : clock and synchronous reset (active high)
--    - `i_valid`      : input valid signal
--    - `i_rdy`        : input ready (from downstream)
--    - `i_gain`       : 2-bit encoded gain input
--    - `o_gain`       : 2-bit decoded or transformed gain output
--
--  Generics     :
--    - `PIPE_DEPTH`  : number of pipeline stages (default = 3)
--
--
--  Context      :
--    This work is carried out in the framework of the ATLAS detector 
--    upgrade at CERN, and contributes to the digital processing chain 
--    for calorimeter data readout.
--
--=============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity Gain_Decoder is
    generic (PIPE_DEPTH : integer :=3);
    Port (
        clk            : in  STD_LOGIC;
        reset            : in  STD_LOGIC;
        i_valid	    : in  STD_LOGIC;
        i_rdy	    : in  STD_LOGIC;
        i_gain  : in  STD_LOGIC_VECTOR(1 downto 0);
        o_gain        : out STD_LOGIC_VECTOR(1 downto 0)
    );
end Gain_Decoder;

architecture Behavioral of Gain_Decoder is
   type fifo_type is array (0 to PIPE_DEPTH-1) of STD_LOGIC_VECTOR(1 downto 0);
   signal r_gain_fifo : fifo_type;
   signal r_read_counter : unsigned(6 downto 0);
   signal r_write_counter : unsigned(6 downto 0);
   
begin

    process(clk)
    begin
    	if rising_edge(clk) then
    	     	if reset = '1' then
    	     	    r_write_counter <= (others=>'0');
    		elsif i_valid ='1' then
    		    r_gain_fifo(to_integer(r_write_counter)) <= i_gain;
    		    if r_write_counter =  PIPE_DEPTH-1 then
         		    r_write_counter <= (others=>'0');
         	    else
         		    r_write_counter <= r_write_counter+1;
         	    end if;
    		end if;
        end if;
    end process;

    process(clk)
    begin
    	if rising_edge(clk) then
    	     	if reset = '1' then
    	     	    r_read_counter <= (others=>'0');
    		elsif i_rdy ='1' then
    		    if r_read_counter =  PIPE_DEPTH-1 then
         		    r_read_counter <= (others=>'0');
         	    else
         		    r_read_counter <= r_read_counter+1;
         	    end if;
    		end if;
        end if;
    end process;

    o_gain <= "00" when r_gain_fifo(to_integer(r_read_counter)) = "11" else r_gain_fifo(to_integer(r_read_counter))(0) & r_gain_fifo(to_integer(r_read_counter))(1);  -- 0 ⟶ 0, 1 ⟶ 2, 2 ⟶ 1, 3 ⟶ 0
   
    
    
end Behavioral;

