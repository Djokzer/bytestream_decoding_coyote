
--=============================================================================
--  Project      : ATLAS Experiment – Bytestream Decoder on FPGA
--  File         : ID_types_package_body.vhd
--  Author       : Andres Upegui
--  Institution  : HEPIA – HES-SO Genève
--  Created      : 2025-07-17
--  Last updated : 2025-07-17
--
--  Description  : 
--    Package body for `ID_types_package`. This body implements several utility
--    functions used across the calorimeter readout firmware to initialize 
--    lookup tables and perform bit-level transformations or statistics.
--
--  Implemented Functions :
--    - `fill_ROM_1` / `fill_ROM_2` :
--        Fill ROM arrays from `COL1_CONSTANTS` and `COL2_CONSTANTS` by extracting
--        a specific bit range per entry. The ROM is filled in four segments.
--
--    - `count_1s` :
--        Computes the Hamming weight (number of '1's) in a 32-bit vector.
--
--    - `fill_cabling_mem` :
--        Initializes a cabling memory ROM by mapping Online IDs from
--        `COL1_CONSTANTS` to corresponding Offline Hash IDs from `COL2_CONSTANTS`.
--        Uses a partial bit range (bits 25 downto 8) as the ROM index.
--
--    - `bit_shuffle` :
--        Performs a custom reordering of a 7-bit input vector. 
--        Can be used for address scrambling or bit re-alignment logic.
--
--
--  Context      :
--    This work is carried out in the framework of the ATLAS detector 
--    upgrade at CERN, and contributes to the digital processing chain 
--    for calorimeter data readout.
--
--=============================================================================

package body ID_types_package is

    function fill_ROM_1 (size: in integer; range_h: in integer; range_l: in integer) return ROM is
        variable filled_ROM : ROM :=(others =>(others=>'0'));
    begin
        for i in 0 to size/4-1 loop
            filled_ROM(i) := COL1_CONSTANTS(i)(range_h downto range_l);
        end loop;         
        for i in size/4 to size/2-1 loop
            filled_ROM(i) := COL1_CONSTANTS(i)(range_h downto range_l);
        end loop; 
         for i in size/2 to (3*size)/4-1 loop
            filled_ROM(i) := COL1_CONSTANTS(i)(range_h downto range_l);
        end loop;  
         for i in (3*size)/4 to size-1 loop
            filled_ROM(i) := COL1_CONSTANTS(i)(range_h downto range_l);
        end loop; 
    	return filled_ROM;
  end function fill_ROM_1;
    

    function fill_ROM_2 (size: in integer; range_h: in integer; range_l: in integer) return ROM is
        variable filled_ROM : ROM :=(others =>(others=>'0'));
    begin
        
        for i in 0 to size/4-1 loop
            filled_ROM(i) := COL2_CONSTANTS(i)(range_h downto range_l);
        end loop;         
        for i in size/4 to size/2-1 loop
            filled_ROM(i) := COL2_CONSTANTS(i)(range_h downto range_l);
        end loop; 
         for i in size/2 to (3*size)/4-1 loop
            filled_ROM(i) := COL2_CONSTANTS(i)(range_h downto range_l);
        end loop;  
         for i in (3*size)/4 to size-1 loop
            filled_ROM(i) := COL2_CONSTANTS(i)(range_h downto range_l);
        end loop;  
    	return filled_ROM;
  end function fill_ROM_2;
  
  
      function count_1s (vector_in: in std_logic_vector(31 downto 0)) return integer is
         variable counter : integer;
      begin
         counter :=0;
         for i in 0 to 31 loop
            counter := counter + to_integer(unsigned(vector_in(i downto i)));
         end loop;
         return counter;
      end function count_1s;
      
  
    function fill_cabling_mem (SIZE: in integer) return CABLING_ROM_type is
           variable filled_ROM : CABLING_ROM_type :=(others =>(others=>'1'));
        begin
        
        for i in 0 to SIZE/4-1 loop
            filled_ROM(to_integer(unsigned(COL1_CONSTANTS(i)(25 downto 8)))) := COL2_CONSTANTS(i)(17 downto 0);
        end loop;         
        for i in SIZE/4 to SIZE/2-1 loop
            filled_ROM(to_integer(unsigned(COL1_CONSTANTS(i)(25 downto 8)))) := COL2_CONSTANTS(i)(17 downto 0);
        end loop; 
         for i in SIZE/2 to (3*SIZE)/4-1 loop
            filled_ROM(to_integer(unsigned(COL1_CONSTANTS(i)(25 downto 8)))) := COL2_CONSTANTS(i)(17 downto 0);
        end loop;  
         for i in (3*SIZE)/4 to SIZE-1 loop
            filled_ROM(to_integer(unsigned(COL1_CONSTANTS(i)(25 downto 8)))) := COL2_CONSTANTS(i)(17 downto 0);
        end loop;  
    	return filled_ROM;
    end function fill_cabling_mem;
    
    function bit_shuffle(a: in std_logic_vector(6 downto 0)) return std_logic_vector is
       begin
        return a(0)&a(3)&a(2)&a(1)&a(6)&a(5)&a(4);
       --0 -> 6,  1 -> 3, 2 -> 4, 3 -> 5, 4 -> 0, 5 -> 1, 6 -> 2
    end function bit_shuffle;
    
    
    
end package body ID_types_package;



