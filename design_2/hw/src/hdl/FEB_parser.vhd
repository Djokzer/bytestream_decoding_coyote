--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : FEB_parser.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  :   
--    This module parses 32-bit input words from a Front-End Board (FEB) stream
--    and extracts raw calorimeter cell information. It decodes the bitfields 
--    and outputs a structured `raw_cell_type` record representing the cell data.
--    Includes valid/ready handshaking for streaming integration.
--
--  Interface    :
--    - `clk`, `reset`     : clock and synchronous reset
--    - `i_valid`          : indicates valid input stream word
--    - `o_rdy`            : high when parser is ready to accept new input
--    - `i_stream`         : 32-bit input word from FEB stream
--    - `o_raw_cell`       : parsed cell output of type `raw_cell_type`
--    - `i_rdy`            : indicates downstream module is ready to consume output
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
use IEEE.numeric_std.all;
use work.ROM_content_package.all;
use work.ID_types_package.all;

entity FEB_parser is
port (
   clk : in std_logic;
   reset : in std_logic;
   i_valid: in std_logic;
   o_rdy : out std_logic;
   i_stream : in std_logic_vector(31 downto 0);
   o_raw_cell : out raw_cell_type;
   i_rdy: in std_logic
   );
end FEB_parser;

architecture behavioral of FEB_parser is


    signal s_raw_cell : raw_cell_type;
    
    constant E_FIFO_ADDR_SIZE : integer :=6;
    constant e_fifo_depth: integer:=2**E_FIFO_ADDR_SIZE;
    constant G_FIFO_ADDR_SIZE : integer :=3;
    constant G_FIFO_DEPTH: integer:=2**G_FIFO_ADDR_SIZE;
    constant TQ_FIFO_ADDR_SIZE : integer :=7;
    constant TQ_FIFO_DEPTH: integer:=2**TQ_FIFO_ADDR_SIZE;
    constant CELL_SIZE: integer:=128;
    
    constant ROD_MARKER:std_logic_vector(31 downto 0) := x"ee1234ee";
    constant STREAM_COUNTER_SIZE: integer:= 16;
    constant FEB1_OFFSET_from_ROD:integer:=9;
    constant SOURCE_ID_OFFSET_FROM_ROD:integer:=3;
    constant E_DATA_OFFSET:integer:= 29;
    constant E_DATA_SIZE:integer:= 64;
    constant G_DATA_OFFSET:integer:= 10;
    constant G_DATA_SIZE:integer:= 8;
    constant TQM_DATA_OFFSET:integer:= 18;
    constant TQM_DATA_SIZE:integer:= 4;
    constant TQ_DATA_OFFSET:integer:= 97;
    signal r_tq_data_size:unsigned(6 downto 0):=(others=>'0');
    
    type e_fifo_32_type is array (0 to e_fifo_depth-1) of std_logic_vector(31 downto 0);
    signal r_e_fifo_1:e_fifo_32_type;
    signal r_e_fifo_2:e_fifo_32_type;
    signal s_e_fifo_wr_en: std_logic;
    signal r_e_fifo_wr_addr : unsigned(E_FIFO_ADDR_SIZE-1 downto 0);
    
    type g_fifo_32_type is array (0 to G_FIFO_DEPTH-1) of std_logic_vector(31 downto 0);
    signal r_g_fifo_1:g_fifo_32_type;
    signal r_g_fifo_2:g_fifo_32_type;
    signal s_g_fifo_wr_en: std_logic;
    signal r_g_fifo_wr_addr : unsigned(G_FIFO_ADDR_SIZE-1 downto 0);
    
    type tq_fifo_32_type is array (0 to TQ_FIFO_DEPTH-1) of std_logic_vector(31 downto 0);
    signal r_tq_fifo_1:tq_fifo_32_type;
    signal r_tq_fifo_2:tq_fifo_32_type;
    signal s_tq_fifo_wr_en: std_logic;
    signal r_tq_fifo_wr_addr : unsigned(TQ_FIFO_ADDR_SIZE-1 downto 0);
    
    type tqm_reg_type is array (0 to 3) of std_logic_vector(31 downto 0);
    signal r_tqm_1:tqm_reg_type;
    signal r_tqm_2:tqm_reg_type;
    
    signal r_stream: std_logic_vector(31 downto 0);
    signal r_valid_in :std_logic;
    signal r_rdy_o:std_logic;
    
    signal r_stream_counter: unsigned(STREAM_COUNTER_SIZE-1 downto 0);
    signal s_rst_stream_counter, s_rst_2_stream_counter:std_logic;
    signal s_en_stream_counter:std_logic;
    
    type state_in is (Search_ROB_marker,Verify_LAR_ID,Search_FEB_1,fill_FIFO);
    signal c_state,n_state : state_in;
    
    type state_out is (waiting, reading1, reading2);
    signal c2_state,n2_state : state_out;
    signal r_cell_counter : unsigned(7 downto 0);
    
    signal s_rst_fifos: std_logic;
    signal r_feb1_done,r_feb2_done :std_logic;
    signal s_start_FIFO_read, s_cell_out_enable,s_tqm_value:std_logic;
    
    signal r_feb2_pos,r_feb_id_in,r_feb_id_out:std_logic_vector(31 downto 0);
    signal s_e_fifo_rd_value,s_raw_time,s_raw_quality : std_logic_vector(15 downto 0);
    signal s_g_fifo_rd_value : std_logic_vector(1 downto 0);
    signal r_tq_pointer : unsigned(7 downto 0);
    
    
    attribute retiming_allow : string;
    attribute retiming_allow of c_state : signal is "true";
    attribute retiming_allow of c2_state : signal is "true";
    
    
begin


    process(clk)
    begin
    	if rising_edge(clk) then
    	   if reset = '1' then
    	      r_stream <= (others =>'0');
    	      r_valid_in<='0';
    	   elsif i_rdy = '1' then
    	      r_stream <= i_stream;
    	      r_valid_in<=i_valid;
    	   end if;
    	end if;
    end process;
    
    --r_rdy_o <='1' when stall_input = '0' else '1';
    o_rdy <= r_rdy_o and i_rdy;

   process(clk)
    begin
    	if rising_edge(clk) then
    	  if i_rdy = '1' then
           if s_rst_fifos = '1' then
              r_e_fifo_wr_addr <=(others=>'0'); 
    	   elsif s_e_fifo_wr_en = '1' and r_valid_in='1' and r_rdy_o = '1' then
    	     if r_feb1_done = '0' then
    	         r_e_fifo_1(to_integer(r_e_fifo_wr_addr)) <= r_stream;
    	     else
    	         r_e_fifo_2(to_integer(r_e_fifo_wr_addr)) <= r_stream;
    	     end if;
    	      r_e_fifo_wr_addr <=r_e_fifo_wr_addr + 1;
    	   end if;
    	end if;
       end if;
    end process;

   process(clk)
    begin
    	if rising_edge(clk) then
    	 if i_rdy = '1' then
    	   if s_rst_fifos = '1' then
              r_g_fifo_wr_addr <=(others=>'0'); 
    	   elsif s_g_fifo_wr_en = '1' and r_valid_in='1' and r_rdy_o = '1' then
    	     if r_feb1_done = '0' then
         	      r_g_fifo_1(to_integer(r_g_fifo_wr_addr)) <= r_stream;
             else
                      r_g_fifo_2(to_integer(r_g_fifo_wr_addr)) <= r_stream;
             end if;
    	      r_g_fifo_wr_addr <=r_g_fifo_wr_addr + 1;
    	   end if;
    	end if;
       end if;
    end process;

   process(clk)
    begin
    	if rising_edge(clk) then
    	  if i_rdy = '1' then
    	   if s_rst_fifos = '1' then
              r_tq_fifo_wr_addr <=(others=>'0'); 
    	   elsif s_tq_fifo_wr_en = '1' and r_valid_in='1' and r_rdy_o = '1' then
    	      if r_feb1_done = '0' then
    	         r_tq_fifo_1(to_integer(r_tq_fifo_wr_addr)) <= r_stream;
    	      else
    	         r_tq_fifo_2(to_integer(r_tq_fifo_wr_addr)) <= r_stream;
    	      end if;
    	      r_tq_fifo_wr_addr <=r_tq_fifo_wr_addr + 1;
    	   end if;
    	end if;
       end if;
    end process;


--  process(clk)
--    begin
--    	if rising_edge(clk) then
--    	   if fifo_wr_en = '1' then
--    	      fifo(to_integer(wr_addr)) <= r_stream;
--    	      wr_addr <=wr_addr + 1;
--    	   end if;
--    	end if;
--    end process;
    

    process(clk)
    begin
    	if rising_edge(clk) then
    	  if i_rdy = '1' then
    	   if (s_rst_stream_counter = '1' or s_rst_2_stream_counter = '1') and r_rdy_o = '1' then
    	      r_stream_counter <= (others=>'0');
    	   elsif s_en_stream_counter = '1' and r_valid_in='1' and r_rdy_o = '1' then
    	      r_stream_counter <= r_stream_counter +1;
    	   end if;
    	end if;
    	end if;
    end process;
    
    -- State Machine for handling the input stream parsing the RAW packet and filling the FIFOs -----------
    
    process(clk)
    begin
    	if rising_edge(clk) then
    	  if i_rdy = '1' then
    	   if reset = '1' then
    	      c_state <= Search_ROB_marker;
    	   else
    	      c_state <= n_state;
    	   end if;
    	end if;
    	end if;
    end process;
    
    process(c_state,r_stream,r_valid_in,r_rdy_o,r_stream_counter,c2_state,r_tq_data_size,r_feb2_pos)
    begin
       n_state <= c_state;
       s_rst_stream_counter <='0';
       s_en_stream_counter <='0';
                 s_rst_2_stream_counter <='0';
          s_start_FIFO_read <='0';
          s_rst_fifos <= '0';
          s_tq_fifo_wr_en<='0';
          s_e_fifo_wr_en <= '0';
          s_g_fifo_wr_en <= '0';
          r_rdy_o<='1';
       case c_state is
          when Search_ROB_marker =>
            s_rst_fifos <= '1';
            if r_stream = ROD_MARKER and r_valid_in='1' and r_rdy_o = '1' then
                n_state <= Verify_LAR_ID;
                s_rst_stream_counter <='1';
            end if;
          when Verify_LAR_ID =>
            s_en_stream_counter <= '1';
            if r_stream_counter = SOURCE_ID_OFFSET_FROM_ROD-1 then
                if r_valid_in='1' and r_rdy_o = '1' then
                     if r_stream(23 downto 12) = x"410" or r_stream(23 downto 12) = x"420" or r_stream(23 downto 12) = x"430" or r_stream(23 downto 12) = x"440" or
                        r_stream(23 downto 12) = x"450" or r_stream(23 downto 12) = x"460" or r_stream(23 downto 12) = x"470" or r_stream(23 downto 12) = x"480"  then
                           n_state <= Search_FEB_1;
                     else
                           n_state <= Search_ROB_marker;
                     end if;
                end if;
            end if;
          when Search_FEB_1 =>
            s_en_stream_counter <= '1';
            if r_stream_counter = FEB1_OFFSET_from_ROD-1 and r_valid_in='1' and r_rdy_o = '1' then
               s_rst_stream_counter <= '1';
               n_state <= fill_FIFO;
            end if;
            
          when fill_FIFO =>
            s_en_stream_counter <='1';
            if r_feb2_done =  '1' and r_rdy_o ='1' then
               n_state <= Search_ROB_marker;
               s_rst_stream_counter <= '1';
            end if;
            if r_valid_in='1' then
              if r_stream_counter >= E_DATA_OFFSET-1 and r_stream_counter < E_DATA_OFFSET+E_DATA_SIZE-1 then
                 s_e_fifo_wr_en <= '1';
              elsif r_stream_counter >= G_DATA_OFFSET-1  and r_stream_counter < G_DATA_OFFSET+G_DATA_SIZE-1 then
                 s_g_fifo_wr_en <= '1';
              elsif r_stream_counter >= TQ_DATA_OFFSET-1 and r_stream_counter < TQ_DATA_OFFSET+r_tq_data_size-1 then
                 s_tq_fifo_wr_en<='1';
              elsif r_stream_counter = TQ_DATA_OFFSET+r_tq_data_size-1 then
                 if c2_state = waiting then
                   s_start_FIFO_read <='1';
                 else
                   r_rdy_o<='0';
                 end if;
              elsif r_stream_counter = unsigned(r_feb2_pos) then
                s_rst_fifos <= '1';
                s_rst_2_stream_counter <='1';
              end if;
            end if;
       end case;
    end process;
    
    
    -- Counter complemeting the FSM that will directly fill the corresponding FIFOs according to the position on the packet
    
    process(clk)
    begin
      if rising_edge(clk) then
        if i_rdy = '1' then
          if c_state = Search_ROB_marker then
                r_feb1_done <= '0';
                r_feb2_done <= '0'; 
          elsif c_state = Search_FEB_1 and r_stream_counter = FEB1_OFFSET_from_ROD-1 and r_valid_in='1' and r_rdy_o = '1' then
                r_feb2_pos <= std_logic_vector(unsigned(r_stream) + 6);
            elsif c_state = fill_FIFO and r_valid_in='1' then
             if r_stream_counter = 1-1 then
                r_feb_id_in <= r_stream;
             elsif r_stream_counter = TQM_DATA_OFFSET-1 then
                if r_feb1_done = '0' then
                   r_tqm_1(0) <= r_stream;
                else
                   r_tqm_2(0) <= r_stream;
                end if;
                r_tq_data_size<=to_unsigned(count_1s(r_stream),7);
             elsif r_stream_counter = TQM_DATA_OFFSET+1-1 then
                if r_feb1_done = '0' then
                   r_tqm_1(1) <= r_stream;
                else
                   r_tqm_2(1) <= r_stream;
                end if;
                r_tq_data_size<=r_tq_data_size+to_unsigned(count_1s(r_stream),7);
             elsif r_stream_counter = TQM_DATA_OFFSET+2-1 then
                if r_feb1_done = '0' then
                   r_tqm_1(2) <= r_stream;
                else
                   r_tqm_2(2) <= r_stream;
                end if;
                r_tq_data_size<=r_tq_data_size+to_unsigned(count_1s(r_stream),7);
             elsif r_stream_counter = TQM_DATA_OFFSET+3-1 then
                if r_feb1_done = '0' then
                   r_tqm_1(3) <= r_stream;
                else
                   r_tqm_2(3) <= r_stream;
                end if;
                r_tq_data_size<=r_tq_data_size+to_unsigned(count_1s(r_stream),7);
             elsif r_stream_counter = TQ_DATA_OFFSET+r_tq_data_size-1 then
                if c2_state = waiting then
                   r_feb_id_out<=r_feb_id_in;
                   if r_feb1_done = '1' then
                      r_feb2_done <= '1'; 
                   end if;
                end if;
             elsif r_stream_counter = unsigned(r_feb2_pos)-1 then
                r_feb1_done <= '1';
             end if;
           end if;
          end if;
        end if;
     end process;
         
    ------ State Machine for handling the input stream parsing the RAW packet and filling the FIFOs -----------
   
    s_cell_out_enable <= i_rdy and s_raw_cell.valid;
   
    process(clk)
    begin
    	if rising_edge(clk) then
    	  if i_rdy = '1' then
    	   if c2_state = waiting then
    	      r_cell_counter <=(others=>'0');
    	   elsif s_cell_out_enable = '1' then
    	      r_cell_counter <= r_cell_counter+1;
    	   end if;
    	  end if;
    	end if;
    end process;
    
    process(clk)
    begin
    	if rising_edge(clk) then
    	   if reset = '1' then
    	      c2_state <= waiting;
    	   elsif i_rdy = '1' then
    	      c2_state <= n2_state;
    	   end if;
    	end if;
    end process;
    
    process ( c2_state, s_start_FIFO_read,r_cell_counter,r_feb1_done,r_feb2_done)
    begin
       n2_state <= c2_state;
       case c2_state is
          when waiting =>
              if s_start_FIFO_read ='1' and r_feb1_done = '0' then
                 n2_state <= reading1;
              elsif (s_start_FIFO_read ='1' and r_feb1_done = '1') or r_feb2_done ='1' then
                 n2_state <= reading2;
              end if;
          when reading1 =>
              if r_cell_counter = 127 then
                 n2_state <= waiting;
              end if;
          when reading2 =>
              if r_cell_counter = 127 then
                 n2_state <= waiting;
              end if;
       end case;
    end process;
        
    s_raw_cell.valid <= '1' when c2_state = reading1 or c2_state = reading2 else '0';
    s_raw_cell.Online_ID <= r_feb_id_out(31 downto 15) & bit_shuffle(std_logic_vector(r_cell_counter(6 downto 0))) & x"00";
    s_raw_cell.raw_energy <= s_e_fifo_rd_value;
    s_raw_cell.gain <= s_g_fifo_rd_value;
    s_raw_cell.TQM <= s_tqm_value;
    s_raw_cell.raw_provenance <=(others=>'0');
    s_raw_cell.raw_time <= s_raw_time;
    s_raw_cell.raw_quality <= s_raw_quality;
    
    o_raw_cell <= s_raw_cell;    
    
    --s_e_fifo_rd_value <=  r_e_fifo_1(to_integer(r_cell_counter(6 downto 1)))(15+16*to_integer(r_cell_counter(0 downto 0)) downto 16*to_integer(r_cell_counter(0 downto 0))) when c2_state = reading1 else 
    --			r_e_fifo_2(to_integer(r_cell_counter(6 downto 1)))(15+16*to_integer(r_cell_counter(0 downto 0)) downto 16*to_integer(r_cell_counter(0 downto 0)));
    s_e_fifo_rd_value <=  r_e_fifo_1(to_integer(r_cell_counter(6 downto 1)))(15+16*to_integer(1-r_cell_counter(0 downto 0)) downto 16*to_integer(1-r_cell_counter(0 downto 0))) when c2_state = reading1 else 
    			r_e_fifo_2(to_integer(r_cell_counter(6 downto 1)))(15+16*to_integer(1-r_cell_counter(0 downto 0)) downto 16*to_integer(1-r_cell_counter(0 downto 0)));
    s_g_fifo_rd_value <=  r_g_fifo_1(to_integer(r_cell_counter(6 downto 4)))(1+2*to_integer(r_cell_counter(3 downto 0)) downto 2*to_integer(r_cell_counter(3 downto 0))) when c2_state = reading1 else
    		         r_g_fifo_2(to_integer(r_cell_counter(6 downto 4)))(1+2*to_integer(r_cell_counter(3 downto 0)) downto 2*to_integer(r_cell_counter(3 downto 0))); 
    s_tqm_value <= r_tqm_1(to_integer(r_cell_counter(6 downto 5)))(to_integer(r_cell_counter(4 downto 0))) when c2_state = reading1 else
    			r_tqm_2(to_integer(r_cell_counter(6 downto 5)))(to_integer(r_cell_counter(4 downto 0))); 
    			
    process(r_tq_pointer,s_tqm_value,c2_state,r_tq_fifo_1,r_tq_fifo_2)
    begin
        s_raw_time <=(others=>'0');
        s_raw_quality <= (others=>'0');
        if s_tqm_value='1' then
             if c2_state = reading1 then
                 s_raw_quality <= r_tq_fifo_1(to_integer(r_tq_pointer))(31 downto 16);
                 s_raw_time <= r_tq_fifo_1(to_integer(r_tq_pointer))(15 downto 0);
             else
                 s_raw_quality <= r_tq_fifo_2(to_integer(r_tq_pointer))(31 downto 16);
                 s_raw_time <= r_tq_fifo_2(to_integer(r_tq_pointer))(15 downto 0);
             end if;
        end if;
     end process;
                 
    --s_raw_time <= (r_tq_fifo_1(to_integer(r_tq_pointer))(31 downto 16) when s_tqm_value='1' else (others=>'0')) when c2_state = reading1 else
    --			(r_tq_fifo_2(to_integer(r_tq_pointer))(31 downto 16) when s_tqm_value='1' else (others=>'0'));    
    --s_raw_quality <= r_tq_fifo_1(to_integer(r_tq_pointer))(15 downto 0) when s_tqm_value='1' else (others=>'0') when c2_state = reading1 else
    --			r_tq_fifo_2(to_integer(r_tq_pointer))(15 downto 0) when s_tqm_value='1' else (others=>'0');
    
    
    process(clk)
    begin
    	if rising_edge(clk) then
    	  if i_rdy = '1' then
    	   if c2_state = waiting then
    	      r_tq_pointer <=(others=>'0');
    	   elsif s_tqm_value = '1' and s_cell_out_enable='1' then
    	      r_tq_pointer <= r_tq_pointer+1;
    	   end if;
    	  end if;
    	end if;
    end process;                    
    
    
end behavioral;
