--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : Online_2_Offline_Hash_ID_LUT.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  :   
--    This module implements a lookup-table (LUT) based mapping from Online IDs 
--    to Offline Hash IDs for ATLAS calorimeter cells. It supports multiple 
--    parallel decoding lanes and includes pipeline stages to meet timing.
--
--  Interface    :
--    - `clk`, `reset`           : clock and synchronous reset
--    - `valid_in`               : input validity flags (per stream)
--    - `rdy_out`                : indicates module readiness (per stream)
--    - `Online_ID`              : vector of 32-bit Online IDs (hardware-facing)
--    - `valid_out`              : indicates valid output data
--    - `Offline_Hash_ID`        : corresponding 18-bit physics-layer IDs
--    - `i_rdy`                  : downstream ready flags (per stream)
--
--
--  Generics     :
--    - `parallel`             : number of parallel decoding lanes (default = 2)
--                               2 lanes can reuse a single dual-port BRAM for conversion
--    - `pipe_depth`           : pipelining depth (default = 3)
--
--  Context      :
--    This work is carried out in the framework of the ATLAS detector 
--    upgrade at CERN, and contributes to the digital processing chain 
--    for calorimeter data readout.
--
--=============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use work.ROM_content_package.all;
use work.ID_types_package.all;

entity Online_2_Offline_Hash_ID_LUT is
generic (parallel: integer:= 8; pipe_depth :integer:=3);
port (
   clk : in std_logic;
   reset : in std_logic;
   valid_in : in std_logic_vector(parallel-1 downto 0) ;
   rdy_out : out std_logic_vector(parallel-1 downto 0) ;
   Online_ID : in par_vector_32_type(0 to parallel-1);
   valid_out : out std_logic_vector(parallel-1 downto 0);
   Offline_Hash_ID : out par_vector_18_type(0 to parallel-1);
   i_rdy : in std_logic_vector(parallel-1 downto 0) 
   );
end Online_2_Offline_Hash_ID_LUT;

architecture behavioral of Online_2_Offline_Hash_ID_LUT is

    signal ROM_Online_ID_2_Index : CABLING_ROM_type := fill_cabling_mem(N_CELLS);
   
    type pipe_18 is array (0 to pipe_depth-1) of unsigned(17 downto 0);
    type par_pipe is array (0 to parallel-1) of pipe_18;
    type par_ID is array (0 to parallel-1) of unsigned(17 downto 0);
    type par_pipe_ctrl is array (0 to parallel-1) of std_logic_vector(0 to pipe_depth-1);
    type par_ctrl is array (0 to parallel-1) of std_logic;
    
    signal address : par_pipe;
    signal internal_valid : par_pipe_ctrl;
    
    attribute retiming_allow : string;
    attribute retiming_allow of address : signal is "true";
    attribute retiming_allow of internal_valid : signal is "true";
    
    attribute ram_style : string;
    attribute ram_style of ROM_Online_ID_2_Index : signal is "bram";
    
begin

Ways: for i in 0 to parallel-1 generate
  begin
   
    process(clk)
    begin
    	if rising_edge(clk) then
    	    if reset = '1' then
                 internal_valid(i)<= (others => '0');     
            elsif i_rdy(i)='1' then  
               address(i)(0) <= unsigned(Online_ID(i)(25 downto 8));	
               internal_valid(i)(0) <= valid_in(i);
    	       address(i)(1 to pipe_depth-1) <= address(i)(0 to pipe_depth-2);    
    	       internal_valid(i)(1 to pipe_depth-1) <= internal_valid(i)(0 to pipe_depth-2);
    	     end if;
    	 end if;
    end process;
        
    rdy_out(i) <= i_rdy(i) ;
    Offline_Hash_ID(i) <= ROM_Online_ID_2_Index(to_integer(address(i)(pipe_depth-1)));
    valid_out(i)<=internal_valid(i)(pipe_depth-1);       
    --Offline_Hash_ID(i) <= std_logic_vector(address(i)(pipe_depth-1)); -- to be removed. Only for 500MHz execution purposes
    
end generate;
    
end behavioral;
