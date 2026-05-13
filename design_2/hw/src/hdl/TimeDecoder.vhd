--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : Time_Decoder.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  :    
--    This module decodes a 16-bit encoded time value into a 32-bit float
--    decoded time representation. It supports pipelined operation 
--    with configurable depth and uses a valid/ready handshake protocol.
--
--  Interface    :
--    - `clk`, `reset`         : clock and synchronous reset
--    - `i_valid`, `i_rdy`     : input-side handshake signals
--    - `i_encoded_time`       : 16-bit encoded time input
--    - `o_decoded_time`       : 32-bit decoded time output
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

entity TimeDecoder is
    generic (PIPE_DEPTH : integer :=3);
    Port (
        clk            : in  STD_LOGIC;
        reset            : in  STD_LOGIC;
        i_valid	    : in  STD_LOGIC;
        i_rdy	    : in  STD_LOGIC;
        i_encoded_time  : in  STD_LOGIC_VECTOR(15 downto 0);
        o_decoded_time        : out STD_LOGIC_VECTOR(31 downto 0)
    );
end TimeDecoder;

architecture Behavioral of TimeDecoder is
   type fifo_type is array (0 to PIPE_DEPTH-1) of STD_LOGIC_VECTOR(15 downto 0);
   signal r_time_fifo : fifo_type;
   signal r_valid_fifo : std_logic_vector(0 to PIPE_DEPTH-1); 
--   signal r_read_counter : unsigned(6 downto 0);
--   signal r_write_counter : unsigned(6 downto 0);
   constant INT_SIZE :integer := 16;
   constant DEC_SIZE :integer := 29;
   signal s_read_time : STD_LOGIC_VECTOR(INT_SIZE-1 downto 0);
   constant fixed_dot_01 : STD_LOGIC_VECTOR(INT_SIZE + DEC_SIZE-1 downto 0):= "000000000000000000000010100011110101110000101";
   constant fixed_dec_0 : STD_LOGIC_VECTOR(DEC_SIZE-1 downto 0):= (others =>'0');
   signal fixed_nonnormalised_product_expanded : STD_LOGIC_VECTOR(2*(INT_SIZE + DEC_SIZE)-1 downto 0);
   signal fixed_nonnormalised_product : STD_LOGIC_VECTOR(INT_SIZE + DEC_SIZE-1 downto 0);
   signal fixed_raw : STD_LOGIC_VECTOR(INT_SIZE + DEC_SIZE-1 downto 0);
   signal fixed_abs : unsigned(INT_SIZE + DEC_SIZE-2 downto 0);
   
   signal s_fp_mantisse : STD_LOGIC_VECTOR(22 downto 0);
   signal s_fp_exp : STD_LOGIC_VECTOR(7 downto 0);
   signal s_fp_sign : std_logic;
   --signal s_fp : STD_LOGIC_VECTOR(31 downto 0);
   
   
    attribute retiming_allow : string;
    attribute retiming_allow of r_time_fifo : signal is "true";
    attribute retiming_forward : integer;
    attribute retiming_forward of r_time_fifo : signal is 1;
   
begin

    process(clk)
    begin
    	if rising_edge(clk) then
    	     if reset = '1' then
    	     	    r_valid_fifo <= (others=>'0');
    		elsif i_rdy ='1' then
    		    --r_time_fifo(to_integer(r_write_counter)) <= i_encoded_time;
    		    r_time_fifo(0) <= i_encoded_time;
    		    r_valid_fifo(0) <= i_valid;
    		    for i in 1 to PIPE_DEPTH-1 loop
    		       r_time_fifo(i) <= r_time_fifo(i-1);
    		       r_valid_fifo(i) <= r_valid_fifo(i-1);
    		    end loop;
    		end if;
        end if;
    end process;

    s_read_time <= r_time_fifo(PIPE_DEPTH-1);

    --s_range_energy <= unsigned(s_read_energy(15 downto 14));
    --s_mantisse_energy <= s_read_energy(12 downto 0);
    --s_sign_energy <= s_read_energy(13);
    --s_range_energy_8 <= "000000" & s_range_energy;
    fixed_raw <= s_read_time & fixed_dec_0;
    fixed_nonnormalised_product_expanded <= std_logic_vector(signed(fixed_raw) * signed(fixed_dot_01));
    fixed_nonnormalised_product<= fixed_nonnormalised_product_expanded(2*DEC_SIZE + INT_SIZE-1 downto DEC_SIZE);
    
    s_fp_sign <= fixed_nonnormalised_product(INT_SIZE + DEC_SIZE-1);
    
    fixed_abs <= unsigned(not fixed_nonnormalised_product(INT_SIZE + DEC_SIZE-2 downto 0)) + 1 when s_fp_sign = '1' else
                 unsigned(fixed_nonnormalised_product(INT_SIZE + DEC_SIZE-2 downto 0));
       
    process(fixed_abs)
    begin
        s_fp_mantisse <= (others=>'0');
        s_fp_exp <= (others=>'0');
        for i in 23 to INT_SIZE + DEC_SIZE-2 loop
            if fixed_abs(i) = '1' then 
 --             if i=23 then
                s_fp_mantisse <= std_logic_vector(fixed_abs(i-1 downto i-23));
 --             elsif i=24 then
 --           	s_fp_mantisse <= std_logic_vector(fixed_abs(i-1 downto i-23)+fixed_abs(i-24 downto i-24)); -- addition for matching the rounding in float representation
 --             else
 --           	s_fp_mantisse <= std_logic_vector(fixed_abs(i-1 downto i-23)+(fixed_abs(i-24 downto i-24) or fixed_abs(i-25 downto i-25)) ); -- addition for matching the rounding in float representation
 --             end if;
              s_fp_exp <= std_logic_vector(to_unsigned(i,8)-DEC_SIZE+ 127); 
            	--exit;
            end if;
        end loop;
    end process;
    
    o_decoded_time <= s_fp_sign & s_fp_exp & s_fp_mantisse ; -- with decoding
    --o_decoded_time <= x"0000" & s_read_time; -- no decoding
    
    
end Behavioral;

