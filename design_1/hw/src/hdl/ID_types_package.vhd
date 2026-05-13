--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : ID_types_package.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  : 
--    This package defines types, constants, and utility functions used 
--    for handling calorimeter cell identifiers, parallel data structures,
--    and raw cell content within the ATLAS firmware readout chain.
--
--  Contents     :
--    - Constants:
--        * N_CELLS : number of calorimeter cells (default = 195072)
--        * LUT_SIZE : default size for cabling lookup tables (2^18 entries)
--    - Types:
--        * ID32_parallel_type     : vector of 32-bit Online IDs
--        * ID18_parallel_type     : vector of 18-bit Offline Hash IDs
--        * par_vector_*_type      : generic parallel arrays for standard widths
--        * raw_cell_type          : record containing unprocessed calorimeter cell data
--        * par_raw_cell_type      : vector of raw_cell_type
--        * ROM, CABLING_ROM_type  : ROM structures for ID mapping
--    - Functions:
--        * fill_ROM_1 / fill_ROM_2      : fill ID mapping ROMs
--        * fill_cabling_mem             : generate cabling memory contents
--        * count_1s                     : population count over a 32-bit vector
--        * bit_shuffle                  : bit-level transformation for address scrambling
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

package ID_types_package is

    
    constant N_CELLS : integer := 195072;
    --constant N_CELLS : integer := 195072/8;
    type ROM is array (0 to N_CELLS-1) of std_logic_vector(17 downto 0);

    function fill_ROM_1 (size: in integer; range_h: in integer; range_l: in integer) return ROM;
    function fill_ROM_2 (size: in integer; range_h: in integer; range_l: in integer) return ROM;
    function count_1s (vector_in: in std_logic_vector(31 downto 0)) return integer;
    function bit_shuffle(a: in std_logic_vector(6 downto 0)) return std_logic_vector;

    type ID32_parallel_type is array (natural range <>) of std_logic_vector(31 downto 0);
    type ID18_parallel_type is array (natural range <>) of std_logic_vector(17 downto 0);
    
    --type par_vector_type is array (natural range <>) of std_logic_vector;  
    type par_vector_32_type is array (natural range <>) of std_logic_vector(31 downto 0);  
    type par_vector_128_type is array (natural range <>) of std_logic_vector(127 downto 0);  
    type par_vector_99_type is array (natural range <>) of std_logic_vector(98 downto 0);  
    type par_vector_18_type is array (natural range <>) of std_logic_vector(17 downto 0);  
    type par_vector_16_type is array (natural range <>) of std_logic_vector(15 downto 0);  
    type par_vector_11_type is array (natural range <>) of std_logic_vector(10 downto 0);  
    type par_vector_2_type is array (natural range <>) of std_logic_vector(1 downto 0);
    
    type raw_cell_type is record
      valid  : std_logic;                
      raw_energy : std_logic_vector(15 downto 0);                
      gain    : std_logic_vector(1 downto 0);
      TQM     : std_logic;
      raw_time    : std_logic_vector(15 downto 0);
      raw_quality : std_logic_vector(15 downto 0);
      raw_provenance: std_logic_vector(15 downto 0);
      Online_ID: std_logic_vector(31 downto 0);
    end record raw_cell_type;  
    
    type par_raw_cell_type is array (natural range <>) of raw_cell_type;
    
    constant LUT_SIZE : integer := 2**18;
    type CABLING_ROM_type is array (0 to 2**18-1) of std_logic_vector(17 downto 0);
    function fill_cabling_mem (size: in integer) return CABLING_ROM_type;
    --constant CABLING_MEM : CABLING_ROM_type := fill_cabling_mem(N_CELLS);
    

end package ID_types_package;
