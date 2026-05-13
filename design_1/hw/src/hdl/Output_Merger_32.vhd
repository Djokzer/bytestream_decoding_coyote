--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : Output_Merger_32.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  :  
--    This module merges decoded calorimeter data fields into a unified 
--    32-bit output stream. It combines various 
--    metadata fields (Offline Hash ID, energy, time, etc.) into a 
--    serial output stream with valid/ready handshaking.
--
--  Interface    :
--    - `clk`, `reset`       : clock and synchronous reset
--    - `valid_in`, `rdy_out`: input-side handshake
--    - `Offline_Hash_ID`    : 18-bit identifier for the calorimeter cell
--    - `Energy_fp`          : 32-bit floating-point energy value
--    - `Time_fp`            : 32-bit floating-point time value
--    - `Provenance`         : 16-bit provenance metadata
--    - `Quality`            : 16-bit quality indicator
--    - `Gain`               : 2-bit gain flag
--    - `valid_out`, `Stream_out`, `rdy_in` : output-side stream interface
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

   entity Output_Merger_32 is
    generic (word_size: integer:= 32);
    port (
       clk : in std_logic;
       reset : in std_logic;
       valid_in : in std_logic;
       rdy_out : out std_logic;
       Offline_Hash_ID : in std_logic_vector(17 downto 0);
       Energy_fp : in std_logic_vector(31 downto 0);
       Time_fp : in std_logic_vector(31 downto 0);
       Provenance : in std_logic_vector(15 downto 0);
       Quality : in std_logic_vector(15 downto 0);
       Gain : in std_logic_vector(1 downto 0);
       valid_out : out std_logic;
       Stream_out: out std_logic_vector(31 downto 0);
       rdy_in: in std_logic
       );
    end Output_Merger_32;

architecture Behavioral of Output_Merger_32 is

    type CaloCell_type is array (0 to 3) of std_logic_vector(31 downto 0);
    signal CaloCell : CaloCell_type;
    signal sending, sending_done : std_logic;
    signal rdy_out_sig : std_logic;
    signal counter : unsigned (1 downto 0);

begin
    
    rdy_out <= rdy_out_sig;
    
    process (clk)
    begin
       if rising_edge(clk) then
           if reset = '1' then
               sending <= '0';
           elsif valid_in ='1' and rdy_out_sig = '1' then
               CaloCell(0) <= "000000" & Gain & "000000" & Offline_Hash_ID;
               CaloCell(1) <= Energy_fp;
               CaloCell(2) <= Time_fp;
               CaloCell(3) <= Quality & Provenance;
               sending <='1';
           elsif sending_done ='1' then
               sending <= '0';
           end if;
       end if;
    end process;
     
    valid_out <= sending; 
    rdy_out_sig <='1' when (rdy_in ='1' and (sending = '0' or sending_done = '1')) else '0';
    Stream_out <= CaloCell(to_integer(counter));
    
    process (clk)
    begin
       if rising_edge(clk) then
          if reset = '1' or sending_done = '1' then
              counter <= (others => '0');
          elsif sending ='1' and rdy_in ='1' then
              counter <= counter + 1;          
          end if;
        end if;
     end process;
     
     sending_done <= '1' when sending ='1' and rdy_in = '1' and counter = 3 else '0';
     
     
     
end Behavioral;
