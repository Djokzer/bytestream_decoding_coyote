library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use work.ROM_content_package.all;
use work.ID_types_package.all;
use work.Correction_LUT_pack.all;

entity Online_2_Offline_Hash_ID_LUT_and_E_correction is
generic (parallel: integer:= 2; pipe_depth :integer:=10);
port (
   clk : in std_logic;
   reset : in std_logic;
   valid_in : in std_logic_vector(parallel-1 downto 0) ;
   rdy_out : out std_logic_vector(parallel-1 downto 0) ;
   Online_ID : in par_vector_32_type(0 to parallel-1);
   valid_out : out std_logic_vector(parallel-1 downto 0);
   Offline_Hash_ID : out par_vector_18_type(0 to parallel-1);
   Pointer_for_correction_LUT : out par_vector_11_type(0 to parallel-1);
   i_rdy : in std_logic_vector(parallel-1 downto 0) 
   );
end Online_2_Offline_Hash_ID_LUT_and_E_correction;

architecture behavioral of Online_2_Offline_Hash_ID_LUT_and_E_correction is

    signal ROM_Online_ID_2_Index : CABLING_ROM_type := fill_cabling_mem(N_CELLS);
    type pipe_18 is array (0 to pipe_depth-1) of unsigned(17 downto 0);
    type par_pipe is array (0 to parallel-1) of pipe_18;
    type par_ID is array (0 to parallel-1) of unsigned(17 downto 0);
    type par_pipe_ctrl is array (0 to parallel-1) of std_logic_vector(0 to pipe_depth-1);
    type par_ctrl is array (0 to parallel-1) of std_logic;
    
    
   signal correction_LUT : Online_ID_to_Geometry_pointer_array_t := correction_LUT_content;
    signal address : par_pipe;
    signal address_2 : par_pipe;
    
    signal internal_valid : par_pipe_ctrl :=(others=>(others=>'0'));
    
--    attribute retiming_allow : string;
--    attribute retiming_allow of address : signal is "true";
   attribute retiming_forward : integer;
   --attribute retiming_backward : integer;
   attribute retiming_forward of address : signal is 1;
--   attribute retiming_backward of address : signal is 1;
   attribute retiming_forward of address_2 : signal is 1;
--   attribute retiming_backward of address_2 : signal is 1;

    attribute shreg_extract : string;
    attribute shreg_extract of address : signal is "no";
    attribute shreg_extract of address_2 : signal is "no";
    
    
    attribute ram_style : string;
    attribute ram_style of ROM_Online_ID_2_Index : signal is "BRAM";
    attribute ram_style of correction_LUT : signal is "BRAM";

    attribute cascade_height : integer;
    attribute cascade_height of ROM_Online_ID_2_Index : signal is 1;  -- to limit cascades
    attribute cascade_height of correction_LUT : signal is 1;  -- to limit cascades
    
begin

Ways: for i in 0 to parallel-1 generate
  begin
   
    process(clk)
    begin
    	if rising_edge(clk) then
    	    if reset = '1' then
                 internal_valid(i)<= (others => '0'); 
                 address(i) <= (others=>(others=>'0')); 
                 address_2(i) <= (others=>(others=>'0')); 
            elsif i_rdy(i)='1' then  
               address(i)(0) <= unsigned(Online_ID(i)(25 downto 8));	
               address_2(i)(0) <= unsigned(Online_ID(i)(25 downto 8));	
               internal_valid(i)(0) <= valid_in(i);
      	       address(i)(1 to pipe_depth-1)        <= address(i)(0 to pipe_depth-2); 
      	       address_2(i)(1 to pipe_depth-1)      <= address_2(i)(0 to pipe_depth-2);
      	       internal_valid(i)(1 to pipe_depth-1) <= internal_valid(i)(0 to pipe_depth-2);
    	     end if;
    	 end if;
    end process;
        
    rdy_out(i) <= i_rdy(i) ;    
    valid_out(i)<=internal_valid(i)(pipe_depth-1);
    --Offline_Hash_ID(i) <= ROM_Online_ID_2_Index(to_integer(address(i)(pipe_depth-1)));
    --Pointer_for_correction_LUT(i) <= correction_LUT(to_integer(address_2(i)((pipe_depth/2)-1)));
     
    process(clk)
    begin
    	if rising_edge(clk) then
    	  if i_rdy(i)='1' then  
            Offline_Hash_ID(i) <= ROM_Online_ID_2_Index(to_integer(address(i)(pipe_depth-2)));
            Pointer_for_correction_LUT(i) <= correction_LUT(to_integer(address_2(i)((pipe_depth/2)-2)));
          end if;
        end if;
    end process;
    
end generate;
    
end behavioral;
