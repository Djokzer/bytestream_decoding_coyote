--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : CAM_ID.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  :  
--    This module implements a Content Addressable Memory (CAM)-like structure 
--    to map Online IDs to corresponding Offline Hash IDs for calorimeter cells.
--    The design supports parallel inputs and is pipelined for performance.
--
--  Interface    :
--    - `clk`, `reset`         : global clock and synchronous reset
--    - `valid_in`             : vector of input validity flags (per stream)
--    - `rdy_out`              : vector indicating decoder readiness per input
--    - `Online_ID`            : parallel array of Online IDs (from hardware)
--    - `valid_out`            : output validity for corresponding mappings
--    - `Offline_Hash_ID`      : resolved Offline Hash IDs
--    - `i_rdy`                : input indicating downstream readiness
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

entity CAM_ID is
generic (parallel: integer:= 2; pipe_depth :integer:=3);
port (
   clk : in std_logic;
   reset : in std_logic;
   valid_in : in std_logic_vector(parallel-1 downto 0) ;
   rdy_out : out std_logic_vector(parallel-1 downto 0) ;
   Online_ID : in ID32_parallel_type(parallel -1 downto 0);
   valid_out : out std_logic_vector(parallel-1 downto 0);
   Offline_Hash_ID : out ID18_parallel_type(parallel -1 downto 0);
   i_rdy : in std_logic_vector(parallel-1 downto 0) 
   );
end CAM_ID;

architecture behavioral of CAM_ID is

    signal ROM_Online_ID_2_Index : ROM := fill_ROM_1(N_CELLS,25,8);
    signal ROM_Index_2_Offline_Hash_ID : ROM := fill_ROM_2(N_CELLS,17,0);

--    type state is (IDLE, SEARCHING);
--    signal c_state, n_state : state := IDLE;
    
    type pipe_18 is array (0 to pipe_depth-1) of unsigned(17 downto 0);
    type par_pipe is array (0 to parallel-1) of pipe_18;
    type par_ID is array (0 to parallel-1) of unsigned(17 downto 0);
    type par_pipe_ctrl is array (0 to parallel-1) of std_logic_vector(0 to pipe_depth-1);
    type par_ctrl is array (0 to parallel-1) of std_logic;
    
    
    signal address : par_pipe;--:=(others=>(others=>'0'));
    signal index : par_pipe;--:=(others=>(others=>'0'));
    constant index_initial_value : unsigned(17 downto 0):= to_unsigned(N_CELLS/2,18);
    signal delta : par_pipe;--:=(others=>(others=>'0'));
    constant delta_initial_value : unsigned(17 downto 0):= to_unsigned((N_CELLS-8)/4,18);
    
    signal internal_valid : par_pipe_ctrl;--:=(others=>'0');
    signal first_valid : par_pipe_ctrl;--:=(others=>'0');
    
    signal match : par_ctrl:=(others =>'0');
    signal s_rdy_out : par_ctrl;
    signal matched_index : par_ID;
    signal read_Online_ID : par_ID; 

--    signal valid_in_reg :par_ctrl:=(others =>'0');
    signal valid_out_reg : par_pipe_ctrl:=(others =>(others=>'0'));
    signal Online_ID_reg: par_pipe;
    signal Offline_Hash_ID_reg: par_pipe;
    
    attribute retiming_allow : string;
    attribute retiming_allow of delta : signal is "true";
    attribute retiming_allow of address : signal is "true";
    attribute retiming_allow of internal_valid : signal is "true";
    attribute retiming_allow of Offline_Hash_ID_reg : signal is "true";
    attribute retiming_allow of index : signal is "true";
    attribute retiming_allow of valid_out_reg : signal is "true";
    
    
    attribute ram_style : string;
    attribute ram_style of ROM_Online_ID_2_Index : signal is "bram";
    attribute ram_style of ROM_Index_2_Offline_Hash_ID : signal is "bram";
    
begin

Ways: for i in 0 to parallel-1 generate
  begin
   
    process(clk)
    begin
    	if rising_edge(clk) then
    	    if reset = '1' then
    	         index(i)(0) <= index_initial_value;
    	         delta(i)(0) <= delta_initial_value;
                 internal_valid(i)(0)<= '0';       
                 address(i)(0) <= (others =>'0');          
            elsif i_rdy(i)='1' then           
               match(i) <='0';
               first_valid(i)(0)<= '0';
               matched_index(i) <= address(i)(pipe_depth-1);   
               if internal_valid(i)(pipe_depth-1) = '1'then
    	         if unsigned(read_Online_ID(i)) = Online_ID_reg(i)(pipe_depth-1) then 
    	              match(i) <='1'; 	              
    	              internal_valid(i)(0) <= '0';
--    	              address(i)(0) <= (others =>'0');
    	              address(i)(0) <= address(i)(pipe_depth-1);
    	              if valid_in(i) = '1' then
         	              index(i)(0) <= index(i)(pipe_depth-1); --The very first time, try with the last index. If it is the same FEB it will be faster!
        	              first_valid(i)(0)<= '1';
    	                      delta(i)(0) <= delta_initial_value;
    	                      internal_valid(i)(0) <= '1'; 
    	                      address(i)(0) <= address(i)(pipe_depth-1) (17 downto 7) & unsigned(Online_ID(i)(14 downto 8));   	      
    	              end if;    	
                 elsif first_valid(i)(pipe_depth-1) = '1' then
                    index(i)(0) <= index_initial_value;
    	            delta(i)(0) <= delta_initial_value;
    	            internal_valid(i)(0) <= '1';
    	            --address(i)(0) <= index(i)(pipe_depth-1) (17 downto 7) & unsigned(Online_ID_reg(i)(pipe_depth-1)(6 downto 0));
    	            address(i)(0) <= index_initial_value(17 downto 7) & unsigned(Online_ID_reg(i)(pipe_depth-1)(6 downto 0));
    	         elsif unsigned(read_Online_ID(i)) > Online_ID_reg(i)(pipe_depth-1) then
    	              index(i)(0) <= index(i)(pipe_depth-1) - delta(i)(pipe_depth-1);
    	              delta(i)(0) <= (delta(i)(pipe_depth-1) + 1) /2;
    	              internal_valid(i)(0) <= '1';
    	              address(i)(0) <= (index(i)(pipe_depth-1) (17 downto 7)- delta(i)(pipe_depth-1)(17 downto 7)) & unsigned(Online_ID_reg(i)(pipe_depth-1)(6 downto 0));
    	         else
    	              index(i)(0) <= index(i)(pipe_depth-1) + delta(i)(pipe_depth-1);
    	              delta(i)(0) <= (delta(i)(pipe_depth-1) + 1) /2;
    	              internal_valid(i)(0) <= '1';
    	              address(i)(0) <= (index(i)(pipe_depth-1) (17 downto 7)+ delta(i)(pipe_depth-1)(17 downto 7)) & unsigned(Online_ID_reg(i)(pipe_depth-1)(6 downto 0));
    	         end if;
    	       elsif valid_in(i) = '1' and internal_valid(i)(pipe_depth-1) = '0' then
    	              index(i)(0) <= index(i)(pipe_depth-1); --The very first time, try with the last index. If it is the same FEB it will be faster!
    	              first_valid(i)(0)<= '1';
    	              delta(i)(0) <= delta_initial_value;
    	              internal_valid(i)(0) <= '1';    	
    	              address(i)(0) <= address(i)(pipe_depth-1) (17 downto 7) & unsigned(Online_ID(i)(14 downto 8));
    	                            
    	       else
    	              index(i)(0) <= index_initial_value;
    	              delta(i)(0) <= delta_initial_value;
    	              internal_valid(i)(0) <= '0';
    	              address(i)(0) <= address(i)(pipe_depth-1);
    	       end if;
    	     end if;
    	 end if;
    end process;
    
        
    process(clk)
    begin
    	if rising_edge(clk) then
    	    if reset = '1' then
    	         internal_valid(i)(1 to pipe_depth-1) <= (others => '0');
    	         first_valid(i)(1 to pipe_depth-1) <= (others => '0');
    	    elsif i_rdy(i)='1' then
    	         address(i)(1 to pipe_depth-1) <= address(i)(0 to pipe_depth-2);
    	         index(i)(1 to pipe_depth-1) <= index(i)(0 to pipe_depth-2);    	         
    	         delta(i)(1 to pipe_depth-1) <= delta(i)(0 to pipe_depth-2);    	         
    	         internal_valid(i)(1 to pipe_depth-1) <= internal_valid(i)(0 to pipe_depth-2);
    	         first_valid(i)(1 to pipe_depth-1) <= first_valid(i)(0 to pipe_depth-2);
    	    end if;
    	end if;
    end process; 
    
    process(clk)
    begin
        if rising_edge(clk) then
    	  if i_rdy(i)='1' then
    	    if valid_in(i) = '1' and s_rdy_out(i) ='1' then
         	    Online_ID_reg(i)(0) <= unsigned(Online_ID(i)(25 downto 8));
            else
         	    Online_ID_reg(i)(0) <= Online_ID_reg(i)(pipe_depth -1); 
            end if;
            Online_ID_reg(i)(1 to pipe_depth -1) <= Online_ID_reg(i)(0 to pipe_depth -2);
         end if;
       end if;
    end process;
    

    rdy_out(i) <= s_rdy_out(i) and i_rdy(i) ;
--     s_rdy_out(i) <= not internal_valid(i)(pipe_depth-1);
    s_rdy_out(i) <= '1' when internal_valid(i)(pipe_depth-1) = '0' or unsigned(read_Online_ID(i)) = Online_ID_reg(i)(pipe_depth-1) else '0';
    

    
    
    --address <= unsigned(std_logic_vector(index(17 downto 7)) & Online_ID_reg(6 downto 0)); -- simplification given the order of cells ID inside a FEB 
    --address(i)(0) <= index(i)(0) (17 downto 7) & unsigned(Online_ID_reg(i)(1)(6 downto 0)); -- simplification given the order of cells ID inside a FEB 
    --address(0) <= index(0);

    --process(clk)
    --begin
     --if rising_edge(clk) then 
        read_Online_ID(i) <= unsigned(ROM_Online_ID_2_Index(to_integer(address(i)(pipe_depth-1))));
     --end if;
    --end process;
    
    process(clk)
    begin
    	if rising_edge(clk) then
    	  if reset = '1' then
          	  valid_out_reg(i) <= (others =>'0');
          	  valid_out(i)<= '0';
          elsif i_rdy(i) = '1' then
    	      valid_out_reg(i)(0) <= '0';
    	      if match(i) ='1' then
    	          Offline_Hash_ID_reg(i)(0) <= unsigned(ROM_Index_2_Offline_Hash_ID(to_integer(matched_index(i))));    
    	          valid_out_reg(i)(0) <= '1';
    	      end if;	        
    	      valid_out_reg(i)(1 to pipe_depth-1) <= valid_out_reg(i)(0 to pipe_depth-2);
    	      Offline_Hash_ID_reg(i)(1 to pipe_depth-1) <= Offline_Hash_ID_reg(i)(0 to pipe_depth-2);
    	      valid_out(i)<= valid_out_reg(i)(pipe_depth-1);
              Offline_Hash_ID(i) <= std_logic_vector(Offline_Hash_ID_reg(i)(pipe_depth-1));
    	  end if;
    	end if;
    end process;
        
    
end generate;
    
end behavioral;
