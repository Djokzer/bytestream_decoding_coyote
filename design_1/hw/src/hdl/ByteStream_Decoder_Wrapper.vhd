--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : ByteStream_Decoder_Wrapper.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  : 
--    Wrapper module for the Byte_Stream_Decoder entity.
--    Provides a simplified single-stream AXI-compatible interface
--    suitable for integration into FPGA-based processing pipelines
--    targeting ATLAS calorimeter front-end data decoding.
--

--  Interface    :
--    - `ap_clk`     : global clock input
--    - `reset`      : synchronous reset (active low)
--    - `valid_in`   : input valid flag
--    - `Stream_in`  : 32-bit input word from upstream module
--    - `rdy_out`    : indicates downstream is ready to receive data
--    - `valid_out`  : indicates output data is valid
--    - `Stream_out` : decoded 32-bit output data (can be extended to 128-bit)
--    - `rdy_in`     : input from downstream indicating readiness

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


entity ByteStream_Decoder_Wrapper is
port (
   ap_clk : in std_logic;
   reset : in std_logic;
   valid_in_a : in std_logic;
   Stream_in_a : in std_logic_vector(31 downto 0);
   rdy_out_a : out std_logic;
   valid_out_a : out std_logic; 
   Stream_out_a : out std_logic_vector(31 downto 0);   
   rdy_in_a: in std_logic;   
   valid_in_b : in std_logic;
   Stream_in_b : in std_logic_vector(31 downto 0);
   rdy_out_b : out std_logic;
   valid_out_b : out std_logic; 
   Stream_out_b : out std_logic_vector(31 downto 0);   
   rdy_in_b: in std_logic;
   par_valid_in : in std_logic;
   par_Stream_in : in std_logic_vector(31 downto 0);
   par_rdy_out : out std_logic
   );
end ByteStream_Decoder_Wrapper;

architecture Behavioral of ByteStream_Decoder_Wrapper is


component Byte_Stream_Decoder is
generic (PAR : integer :=2);
port (
   clk : in std_logic;
   reset : in std_logic;
   valid_in : in std_logic_vector (0 to par-1);
   Stream_in : in par_vector_32_type(0 to par-1);
   rdy_out : out std_logic_vector (0 to par-1);
   valid_out : out std_logic_vector (0 to par-1);
   --Stream_out : out par_vector_128_type(0 to par-1);   
   Stream_out : out par_vector_32_type(0 to par-1);   
   rdy_in: in std_logic_vector (0 to par-1);
   par_valid_in : in std_logic_vector (0 to par-1);
   par_Stream_in : in par_vector_32_type (0 to par-1);
   par_rdy_out : out std_logic_vector (0 to par-1)
   );
end component;

--signal Stream_out_128 : std_logic_vector (127 downto 0);
signal reset_sig : std_logic;

begin

reset_sig <= not reset;

bsd_inst: Byte_Stream_Decoder
generic map(1)
port map(
   clk => ap_clk,
   reset => reset_sig,
   valid_in(0) => valid_in_a,
--   valid_in(1) => valid_in_b,
   Stream_in(0) => Stream_in_a,
--   Stream_in(1) => Stream_in_b,
   rdy_out(0) => rdy_out_a,
--   rdy_out(1) => rdy_out_b,
   valid_out(0) => valid_out_a, 
--   valid_out(1) => valid_out_b,  
   Stream_out(0) => Stream_out_a, 
--   Stream_out(1) => Stream_out_b,  
   rdy_in(0) => rdy_in_a,  
--   rdy_in(1) => rdy_in_b,
   par_valid_in(0) => par_valid_in,
--   par_valid_in(1) => par_valid_in,
   par_Stream_in(0) => par_Stream_in,
--   par_Stream_in(1) => par_Stream_in,
   par_rdy_out(0) => par_rdy_out
--   par_rdy_out(1) => open
   );

rdy_out_b <='1';
valid_out_b <= valid_in_b;
Stream_out_b <= (others =>'0');

--valid_out <= valid_in;
--rdy_out <= rdy_in;
--Stream_out <= std_logic_vector(unsigned(Stream_in)+1);

--Stream_out <= Stream_out_128(127 downto 96);
--Stream_out <= Stream_out_128;
--Stream_out <= Stream_out_128(127 downto 32) & x"A6" & Stream_out_128(119 downto 96); -- for testing...

end;
