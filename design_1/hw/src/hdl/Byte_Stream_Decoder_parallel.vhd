--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : Byte_Stream_Decoder.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  : 
--    Byte stream decoder module designed for parallel input streams.
--    The module decodes raw 32-bit words from a serialized stream
--    format into structured data, using ROM-based content decoding
--    and ID conversion from online ID to offline hash ID.
--
--  Interface    :
--    - Generic PAR: number of parallel streams processed (default = 2)
--    - `valid_in`, `rdy_out`, `Stream_in`: input stream data and validity flags
--    - `par_valid_in`, `par_rdy_out`, `par_Stream_in`: input stream and flags for loading parameters
--    - `valid_out`, `rdy_in`, `Stream_out`: output stream interface

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


entity Byte_Stream_Decoder is
generic (PAR : integer :=1);
port (
   clk : in std_logic;
   reset : in std_logic;
   valid_in : in std_logic_vector (0 to par-1);
   Stream_in : in par_vector_32_type (0 to par-1);
   rdy_out : out std_logic_vector (0 to par-1);
   valid_out : out std_logic_vector (0 to par-1);
   --Stream_out : out par_vector_128_type(0 to par-1);   
   Stream_out : out par_vector_32_type(0 to par-1);   
   rdy_in: in std_logic_vector (0 to par-1);
   par_valid_in : in std_logic_vector (0 to par-1);
   par_Stream_in : in par_vector_32_type (0 to par-1);
   par_rdy_out : out std_logic_vector (0 to par-1)
   );
end Byte_Stream_Decoder;

architecture Behavioral of Byte_Stream_Decoder is

    constant PIPE_DEPTH: integer :=40; -- MUST be an EVEN number
    
component axis_fifo_1reg_sync_ready is
   generic (
        DATA_WIDTH : integer := 32
    );
    port (
        -- AXI Stream input
        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;

        -- AXI Stream output
        m_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;

        -- Clock & Reset
        clk    : in  std_logic;
        reset : in  std_logic
    );
end component;

    component Online_2_Offline_Hash_ID_LUT_and_E_correction is
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
    end component;
    
    component FEB_parser is
    port (
     clk : in std_logic;
     reset : in std_logic;
     i_valid: in std_logic;
     o_rdy : out std_logic;
     i_stream : in std_logic_vector(31 downto 0);
     o_raw_cell : out raw_cell_type;
     i_rdy: in std_logic
       );
    end component;
    
 
    
--    component Output_Merger is
      component Output_Merger_32 is
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
--       Stream_out: out std_logic_vector(127 downto 0);
       Stream_out: out std_logic_vector(31 downto 0);
       rdy_in: in std_logic
       );
    end component;
    
    component TimeDecoder is
    generic (PIPE_DEPTH : integer :=3);
    Port (
        clk            : in  STD_LOGIC;
        reset            : in  STD_LOGIC;
        i_valid	    : in  STD_LOGIC;
        i_rdy	    : in  STD_LOGIC;
        i_encoded_time  : in  STD_LOGIC_VECTOR(15 downto 0);
        o_decoded_time        : out STD_LOGIC_VECTOR(31 downto 0)
    );
    end component;
    

component EnergyDecoderCorrection is
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
end component;

  component Gain_Decoder is
    generic (PIPE_DEPTH : integer :=3);
    Port (
        clk            : in  STD_LOGIC;
        reset            : in  STD_LOGIC;
        i_valid	    : in  STD_LOGIC;
        i_rdy	    : in  STD_LOGIC;
        i_gain  : in  STD_LOGIC_VECTOR(1 downto 0);
        o_gain        : out STD_LOGIC_VECTOR(1 downto 0)
    );
  end component;
    
    
    signal Raw_Cell_out : par_raw_cell_type(0 to par-1);
    signal Raw_Cell_out2 : par_raw_cell_type(0 to par-1);
    signal rdy_CAM_2_parser: std_logic_vector (0 to par-1);
    signal rdy_CAM_2_parser2: std_logic_vector (0 to par-1);
    signal valid_CAM_2_merger,valid_CAM_2_merger2: std_logic_vector (0 to par-1);
    signal rdy_merger_2_CAM,rdy_merger_2_CAM2: std_logic_vector (0 to par-1);
    signal en_1,en_2: std_logic_vector (0 to par-1);
    
    signal valid_parser_2_CAM: std_logic_vector (0 to par-1);
    signal Energy_sig,Energy_sig2: par_vector_32_type(0 to par-1);
    signal Offline_Hash_ID,Offline_Hash_ID2 : par_vector_18_type(0 to par-1);
    signal Time_sig, Time_sig2 : par_vector_32_type(0 to par-1);
    signal Provenance_sig,Provenance_sig2 : par_vector_16_type(0 to par-1);
    signal Quality_sig,Quality_sig2 : par_vector_16_type(0 to par-1);
    signal Gain_sig,Gain_sig2 : par_vector_2_type(0 to par-1);
    signal Raw_cell_Online_ID : par_vector_32_type(0 to par-1);
    signal Pointer_for_correction_LUT : par_vector_11_type(0 to par-1);
    signal FIFO_data_99_in : par_vector_99_type(0 to par-1);
    signal FIFO_data_99_out : par_vector_99_type(0 to par-1);
    signal FIFO_data_128_in : par_vector_128_type(0 to par-1);
    signal FIFO_data_128_out : par_vector_128_type(0 to par-1);
    

begin


    inst_LUT: Online_2_Offline_Hash_ID_LUT_and_E_correction
    generic map (PAR,PIPE_DEPTH)
    port map(
       clk => clk,
       reset => reset,
       valid_in => valid_parser_2_CAM,
       rdy_out => rdy_CAM_2_parser2,
       Online_ID => Raw_cell_Online_ID,
       valid_out => valid_CAM_2_merger,
       Offline_Hash_ID => Offline_Hash_ID,
       Pointer_for_correction_LUT => Pointer_for_correction_LUT,
       i_rdy =>  rdy_merger_2_CAM
       );
       
 
    
    process(Raw_cell_out2)
    begin
      for i in 0 to PAR-1 loop
         Raw_cell_Online_ID(i) <= Raw_cell_out2(i).Online_ID;
      end loop;
    end process;

 Ways: for i in 0 to PAR-1 generate
  begin

    inst_parser: FEB_parser
    port map (
       clk => clk,
       reset => reset,
       i_valid => valid_in(i),
       o_rdy => rdy_out(i),
       i_stream => Stream_in(i),
       o_raw_cell => Raw_cell_out(i),
       i_rdy => rdy_CAM_2_parser(i)
       );
    
    FIFO_data_99_in(i)(98 downto 83)    <= Raw_cell_out(i).raw_energy;
    FIFO_data_99_in(i)(82 downto 81)    <= Raw_cell_out(i).gain;
    FIFO_data_99_in(i)(80)              <= Raw_cell_out(i).TQM;
    FIFO_data_99_in(i)(79 downto 64)    <= Raw_cell_out(i).raw_time; 
    FIFO_data_99_in(i)(63 downto 48)    <= Raw_cell_out(i).raw_quality; 
    FIFO_data_99_in(i)(47 downto 32)    <= Raw_cell_out(i).raw_provenance; 
    FIFO_data_99_in(i)(31 downto 0)     <= Raw_cell_out(i).Online_ID;

    Raw_cell_out2(i).raw_energy <=      FIFO_data_99_out(i)(98 downto 83); 
    Raw_cell_out2(i).gain <=            FIFO_data_99_out(i)(82 downto 81);
    Raw_cell_out2(i).TQM <=             FIFO_data_99_out(i)(80);
    Raw_cell_out2(i).raw_time <=        FIFO_data_99_out(i)(79 downto 64);
    Raw_cell_out2(i).raw_quality <=     FIFO_data_99_out(i)(63 downto 48);
    Raw_cell_out2(i).raw_provenance <=  FIFO_data_99_out(i)(47 downto 32);
    Raw_cell_out2(i).Online_ID <=       FIFO_data_99_out(i)(31 downto 0);
    
      FIFO_after_parser:  axis_fifo_1reg_sync_ready
   generic map ( 99 )
    port map(
        -- AXI Stream input
        s_axis_tdata  => FIFO_data_99_in(i),
        s_axis_tvalid => Raw_cell_out(i).valid,
        s_axis_tready => rdy_CAM_2_parser(i),
        -- AXI Stream output
        m_axis_tdata  => FIFO_data_99_out(i),
        m_axis_tvalid => Raw_cell_out2(i).valid,
        m_axis_tready => rdy_CAM_2_parser2(i),
        clk    => clk,
        reset => reset
    );
    
    en_1(i) <= valid_parser_2_CAM(i);
    en_2(i) <= rdy_merger_2_CAM(i);
        
    inst_energy: EnergyDecoderCorrection 
    generic map (PIPE_DEPTH)
    port map(
        clk => clk,
        reset => reset,
        i_valid => en_1(i),
        i_rdy => en_2(i),
        i_encoded_energy => Raw_cell_out2(i).raw_energy,
        Pointer_for_correction_LUT => Pointer_for_correction_LUT(i),
        o_decoded_energy => Energy_sig(i),
        par_valid_in => par_valid_in(i),
        par_Stream_in => par_Stream_in(i),
        par_rdy_out => par_rdy_out(i)
        );            
        
    inst_gain: Gain_Decoder 
    generic map (PIPE_DEPTH)
    port map(
        clk => clk,
        reset => reset,
        i_valid => en_1(i),
        i_rdy => en_2(i),
        i_gain => Raw_cell_out2(i).gain,
        o_gain => Gain_sig(i)
        );
    
    inst_time: TimeDecoder 
    generic map (PIPE_DEPTH)
    Port map (
        clk => clk,
        reset => reset,
        i_valid => en_1(i),
        i_rdy => en_2(i),
        i_encoded_time  => Raw_cell_out2(i).raw_time,
        o_decoded_time   => Time_sig(i)
    );

   FIFO_data_128_in(i)(127 downto 116)  <= x"000";
   FIFO_data_128_in(i)(115 downto 114)  <= Gain_sig(i);
   FIFO_data_128_in(i)(113 downto 96)   <= Offline_Hash_ID(i);
   FIFO_data_128_in(i)(95 downto 64)    <= Energy_sig(i) ;
   FIFO_data_128_in(i)(63 downto 32)    <= Time_sig(i);
   FIFO_data_128_in(i)(31 downto 16)    <= Provenance_sig(i);
   FIFO_data_128_in(i)(15 downto 0)     <= Quality_sig(i);

   Gain_sig2(i)         <= FIFO_data_128_out(i)(115 downto 114);
   Offline_Hash_ID2(i)  <= FIFO_data_128_out(i)(113 downto 96);
   Energy_sig2(i)       <= FIFO_data_128_out(i)(95 downto 64);
   Time_sig2(i)         <= FIFO_data_128_out(i)(63 downto 32);
   Provenance_sig2(i)   <= FIFO_data_128_out(i)(31 downto 16);
   Quality_sig2(i)      <= FIFO_data_128_out(i)(15 downto 0);

   FIFO_before_merger:  axis_fifo_1reg_sync_ready
   generic map ( 128 )
    port map(
        -- AXI Stream input
        s_axis_tdata  => FIFO_data_128_in(i),
        s_axis_tvalid => valid_CAM_2_merger(i),
        s_axis_tready => rdy_merger_2_CAM(i),
        -- AXI Stream output
        m_axis_tdata  => FIFO_data_128_out(i),
        m_axis_tvalid => valid_CAM_2_merger2(i),
        m_axis_tready => rdy_merger_2_CAM2(i),
        clk    => clk,
        reset => reset
    );

    inst_merger : Output_Merger_32
    port map(
       clk => clk,
       reset => reset,
       valid_in => valid_CAM_2_merger2(i),
       rdy_out => rdy_merger_2_CAM2(i),
       Offline_Hash_ID => Offline_Hash_ID2(i),
       Energy_fp => Energy_sig2(i),
       Time_fp => Time_sig2(i),
       Provenance => Provenance_sig2(i),
       Quality => Quality_sig2(i),
       Gain => Gain_sig2(i),
       valid_out => valid_out(i),
       Stream_out => Stream_out(i),
       rdy_in => rdy_in(i)
       );

    valid_parser_2_CAM(i) <= Raw_cell_out2(i).valid;
    --Gain_sig <= Raw_cell_out.gain;
    Provenance_sig(i) <= Raw_cell_out2(i).raw_provenance;
    Quality_sig(i) <= Raw_cell_out2(i).raw_quality;
    --Time_sig <= (others => '0');
  end generate;  
    
end Behavioral;
