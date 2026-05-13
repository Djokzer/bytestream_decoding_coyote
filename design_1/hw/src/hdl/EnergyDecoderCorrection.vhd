library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.Correction_LUT_pack.all;
use work.Correction_content_pack.all;

entity EnergyDecoderCorrection is
    generic (PIPE_DEPTH : integer :=3);
    Port (
        clk            : in  STD_LOGIC;
        reset            : in  STD_LOGIC;
        i_valid	    : in  STD_LOGIC;
        i_rdy	    : in  STD_LOGIC;
        i_encoded_energy  : in  STD_LOGIC_VECTOR(15 downto 0);
        Pointer_for_correction_LUT : in STD_LOGIC_VECTOR(10 downto 0);
        o_decoded_energy        : out STD_LOGIC_VECTOR(31 downto 0);
        par_valid_in : in std_logic;
        par_Stream_in : in STD_LOGIC_VECTOR(31 downto 0);
        par_rdy_out : out std_logic
    );
end EnergyDecoderCorrection;

architecture Behavioral of EnergyDecoderCorrection is
   type fifo_type is array (0 to (PIPE_DEPTH/2)-1) of STD_LOGIC_VECTOR(15 downto 0);
   --signal r_valid_fifo : std_logic_vector(0 to (PIPE_DEPTH/2)-1); 
   signal r_energy_fifo : fifo_type;
   signal s_range_energy : unsigned(1 downto 0);   
   --signal s_range_energy_8 : unsigned(7 downto 0);   
   signal s_mantisse_energy : STD_LOGIC_VECTOR(12 downto 0);
   signal s_sign_energy : STD_LOGIC;
   signal s_read_energy : STD_LOGIC_VECTOR(15 downto 0);
   
   signal s_fp_mantisse : STD_LOGIC_VECTOR(22 downto 0);
   signal s_fp_exp : STD_LOGIC_VECTOR(7 downto 0);
   signal s_fp_sign : std_logic;
   signal s_fp : STD_LOGIC_VECTOR(31 downto 0);
   
   signal corrected_value : STD_LOGIC_VECTOR(31 downto 0);
   
   signal correction_LUT:Correction_LUTs_const_array_t:= Correction_LUTs_const;
   signal par_valid_reg : std_logic;
   signal par_Stream_reg : STD_LOGIC_VECTOR(31 downto 0);
   signal LUT_address: unsigned(10 downto 0);
       
    attribute ram_style : string;
    attribute ram_style of correction_LUT : signal is "BRAM";
   
   signal opa, opb, res : STD_LOGIC_VECTOR(63 downto 0);
   signal bidon : STD_LOGIC_VECTOR(2 downto 0);
   
--   attribute retiming_allow : string;
--   attribute retiming_allow of r_energy_fifo : signal is "true";
   --attribute retiming_forward : integer;
   --attribute retiming_forward of r_energy_fifo : signal is 1;
   
   component fpu_sub IS
   generic (PIPE_DEPTH : integer :=3);
    Port (
        clk            : in  STD_LOGIC;
        reset            : in  STD_LOGIC;
        i_valid	    : in  STD_LOGIC;
        i_rdy	    : in  STD_LOGIC;
        i_a  : in  STD_LOGIC_VECTOR(31 downto 0);
        i_b : in STD_LOGIC_VECTOR(31 downto 0);
        o_res        : out STD_LOGIC_VECTOR(31 downto 0)
    );
   end component;
   
begin


    process(clk)
    begin
    	if rising_edge(clk) then
    	     if reset = '1' then
    --	     	    r_valid_fifo <= (others=>'0');
    		  --     r_energy_fifo <= (others=>(others=>'0'));
    		elsif i_rdy ='1' then
    		    r_energy_fifo(0) <= i_encoded_energy;
    --		    r_valid_fifo(0) <= i_valid;
    		    for i in 1 to (PIPE_DEPTH/2)-1 loop
    		       r_energy_fifo(i) <= r_energy_fifo(i-1);
    --		       r_valid_fifo(i) <= r_valid_fifo(i-1);
    		    end loop;
    		end if;
        end if;
    end process;

    s_read_energy <= r_energy_fifo((PIPE_DEPTH/2)-1);

    s_range_energy <= unsigned(s_read_energy(15 downto 14));
    s_mantisse_energy <= s_read_energy(12 downto 0);
    s_sign_energy <= s_read_energy(13);
    --s_range_energy_8 <= "000000" & s_range_energy;

    
 --   process(s_range_energy,s_mantisse_energy,s_energy_abs)
 --   begin(PIPE_DEPTH/2)
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
    corrected_value <= correction_LUT(to_integer(unsigned(Pointer_for_correction_LUT))) when unsigned(Pointer_for_correction_LUT) < 1832 else x"FFFFFFFF";
    
    --o_decoded_energy <= s_fp - corrected_value; -- BUT!!!! These are float values, so it is more complucated than this 
    --o_decoded_energy <= corrected_value; -- for now
    
   substracter: fpu_sub 
   generic map(PIPE_DEPTH/2)
   PORT map( 
      clk => clk,
      reset => reset,
    --  i_valid  => r_valid_fifo((PIPE_DEPTH/2) -1),
      i_valid  => '0',
      i_rdy => i_rdy,
      i_a => s_fp,
      i_b => corrected_value,
      o_res =>o_decoded_energy
   );
  
   -----------------------------------------------------------------------------------
   process(clk)
    begin
    	if rising_edge(clk) then
    	    par_Stream_reg <= par_Stream_in;
    	    par_valid_reg <= par_valid_in;
    	    if par_valid_reg = '1' then
    	        correction_LUT(to_integer(LUT_address))<= par_Stream_reg;  
    	        LUT_address <= LUT_address + 1;
    	    end if;
    	    if i_rdy = '0' then -- if the decoder is used we can reset the pointer for a new parameter loading
    	        LUT_address <= (others =>'0');
    	    end if;
    	end if;
    end process;
    
    par_rdy_out <= '1';
    
end Behavioral;

