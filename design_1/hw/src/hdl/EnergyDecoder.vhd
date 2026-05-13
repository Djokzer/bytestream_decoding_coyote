--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : EnergyDecoder.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  : 
--    This module implements an energy decoder.
--    It receives a 16-bit encoded energy value and produces a 32-bit 
--    decoded energy output. It includes a valid/ready handshake mechanism
--    and supports pipelining through a configurable PIPE_DEPTH generic.
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

entity EnergyDecoder is
    generic (PIPE_DEPTH : integer :=3);
    Port (
        clk            : in  STD_LOGIC;
        reset            : in  STD_LOGIC;
        i_valid	    : in  STD_LOGIC;
        i_rdy	    : in  STD_LOGIC;
        i_encoded_energy  : in  STD_LOGIC_VECTOR(15 downto 0);
        o_decoded_energy        : out STD_LOGIC_VECTOR(31 downto 0)
    );
end EnergyDecoder;

architecture Behavioral of EnergyDecoder is
   type fifo_type is array (0 to PIPE_DEPTH-1) of STD_LOGIC_VECTOR(15 downto 0);
   signal r_energy_fifo : fifo_type;
   signal r_read_counter : unsigned(6 downto 0);
   signal r_write_counter : unsigned(6 downto 0);
   signal s_range_energy : unsigned(1 downto 0);   
   --signal s_range_energy_8 : unsigned(7 downto 0);   
   signal s_mantisse_energy : STD_LOGIC_VECTOR(12 downto 0);
   signal s_sign_energy : STD_LOGIC;
   signal s_read_energy : STD_LOGIC_VECTOR(15 downto 0);
   
   signal s_fp_mantisse : STD_LOGIC_VECTOR(22 downto 0);
   signal s_fp_exp : STD_LOGIC_VECTOR(7 downto 0);
   signal s_fp_sign : std_logic;
   signal s_fp : STD_LOGIC_VECTOR(31 downto 0);
   
   
    attribute retiming_allow : string;
    attribute retiming_allow of r_energy_fifo : signal is "true";
   
begin

    process(clk)
    begin
    	if rising_edge(clk) then
    	     	if reset = '1' then
    	     	    r_write_counter <= (others=>'0');
    		elsif i_valid ='1' then
    		    r_energy_fifo(to_integer(r_write_counter)) <= i_encoded_energy;
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

    s_read_energy <= r_energy_fifo(to_integer(r_read_counter));

    s_range_energy <= unsigned(s_read_energy(15 downto 14));
    s_mantisse_energy <= s_read_energy(12 downto 0);
    s_sign_energy <= s_read_energy(13);
    --s_range_energy_8 <= "000000" & s_range_energy;

    
 --   process(s_range_energy,s_mantisse_energy,s_energy_abs)
 --   begin
 --           s_energy_abs <= (others => '0');
 --           s_energy_abs(12 + to_integer(s_range_energy)*3 downto to_integer(s_range_energy)*3) <= s_mantisse_energy;
 --           if s_sign_energy = '1' then
 --               o_decoded_energy <= std_logic_vector(-signed(s_energy_abs));
 --           else
 --               o_decoded_energy <= s_energy_abs;
 --           end if;
 --   end process;
    
    process(s_mantisse_energy,s_range_energy)
    begin
        s_fp_mantisse <= (others=>'0');
        s_fp_exp <= (others=>'0');
        for i in 0 to 12 loop
            if s_mantisse_energy(i) = '1' then 
            	s_fp_mantisse(22 downto 22-(i-1)) <= s_mantisse_energy(i-1 downto 0);
            	s_fp_exp <= std_logic_vector(to_unsigned(i,8) + s_range_energy + s_range_energy + s_range_energy+  127); 
            	--exit;
            end if;
        end loop;
    end process;
    
    s_fp_sign <= s_sign_energy;
    s_fp <= s_fp_sign & s_fp_exp & s_fp_mantisse;
    o_decoded_energy <= s_fp;
    
    
    
end Behavioral;

