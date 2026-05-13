library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity fpu_sub is
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
end fpu_sub;

architecture Behavioral of fpu_sub is
   type fifo_type_32 is array (0 to PIPE_DEPTH-1) of STD_LOGIC_VECTOR(31 downto 0);
   signal r_b : fifo_type_32;
   signal r_a : fifo_type_32;
 --  signal r_valid_fifo : std_logic_vector(0 to PIPE_DEPTH-1); 
   
   signal a,b: STD_LOGIC_VECTOR(31 downto 0);
   signal sign_a,sign_b,sign_res: STD_LOGIC;
   signal exp_a,exp_b,exp_res: unsigned(7 downto 0);
   signal max_exp: unsigned(7 downto 0);
   
   signal mant_a_slv,mant_b_slv,mant_res_slv: STD_LOGIC_VECTOR(25 downto 0);
   signal mant_a,mant_b: signed(25 downto 0);
   signal mant_res: signed(25 downto 0);
   signal unnorm_mant_a,unnorm_mant_b,unnorm_mant_res,abs_unnorm_mant_res: signed(25 downto 0);
   signal pre_exp: signed(7 downto 0);

   
--   attribute retiming_allow : string;
--   attribute retiming_allow of r_b : signal is "true";
--   attribute retiming_allow of r_a : signal is "true";
   
   attribute retiming_forward : integer;
   attribute retiming_backward : integer;
   attribute retiming_forward of r_a : signal is 1;
   attribute retiming_forward of r_b : signal is 1;
--   attribute retiming_backward of r_a : signal is 1;
   attribute retiming_backward of r_b : signal is 1;


    attribute shreg_extract : string;
    attribute shreg_extract of r_a : signal is "no";
    attribute shreg_extract of r_b : signal is "no";
   
begin


    process(clk)
    begin
    	if rising_edge(clk) then
    	     --if reset = '1' then
    	     --	    r_valid_fifo <= (others=>'0');    	     	    
    		 --      r_a <= (others=>(others=>'0'));	     	    
    		 --      r_b <= (others=>(others=>'0'));
    		--els
            if i_rdy ='1' then
    		    r_a(0) <= i_a;
    		    r_b(0) <= i_b;
    		--    r_valid_fifo(0) <= i_valid;
    		    for i in 1 to PIPE_DEPTH-1 loop
    		       r_a(i) <= r_a(i-1);
    		       r_b(i) <= r_b(i-1);
    		--       r_valid_fifo(i) <= r_valid_fifo(i-1);
    		    end loop;
    		end if;
        end if;
    end process;

    a <= r_a(PIPE_DEPTH-1);
    b <= r_b(PIPE_DEPTH-1);
    
    sign_a <= a(31);
    sign_b <= b(31);
    
    exp_a <= unsigned(a(30 downto 23));
    exp_b <= unsigned(b(30 downto 23));
    max_exp <= exp_a when exp_a > exp_b else exp_b;
    mant_a_slv <= "001" & a(22 downto 0);   -- we add a bit '1' for completing the mantisse, a bit '0' for the sign,
    mant_b_slv <= "001" & b(22 downto 0);   -- and another '0' for avoiding overflow in the further sum
    mant_a <= signed(mant_a_slv) when sign_a = '0' else   
    		- signed(mant_a_slv);                   
    mant_b <= signed(mant_b_slv) when sign_b = '1' else
    		- signed(mant_b_slv);
    
    -- lets align the mantisse with the larger exponent.
    process (mant_a,mant_b,exp_a, exp_b)
    begin
       if exp_a > exp_b then
           unnorm_mant_a <= mant_a;
       else
           unnorm_mant_a <= (others => mant_a(25));      -- we set by default all values to sign
           unnorm_mant_a (25 - to_integer(exp_b-exp_a) downto 0) <= mant_a(25 downto to_integer(exp_b-exp_a));
       end if; 
       if exp_a < exp_b then
           unnorm_mant_b <= mant_b;
       else
           unnorm_mant_b <= (others => mant_b(25));      -- sign
           unnorm_mant_b (25 - to_integer(exp_a-exp_b) downto 0) <= mant_b(25 downto to_integer(exp_a-exp_b));
       end if; 
    end process;
    
    unnorm_mant_res <= unnorm_mant_a + unnorm_mant_b;   
    
    sign_res <= unnorm_mant_res(25);
    abs_unnorm_mant_res <= unnorm_mant_res when sign_res = '0' else
                           -unnorm_mant_res;
                           
    process (abs_unnorm_mant_res)
    begin        
        mant_res <= (others=>'0');
        for i in 0 to 24 loop
            if abs_unnorm_mant_res(i) = '1' then 
                	mant_res(24 downto 24-(i-1)) <= abs_unnorm_mant_res(i+1 downto 2);
            	pre_exp <= to_signed(23-i,8);
            	--exit;
            end if;
        end loop;
    end process;
    
    exp_res <= max_exp - UNSIGNED(std_logic_vector(pre_exp));
    
--    o_res <= (others => '0') when a=b else 
    o_res <=         sign_res & std_logic_vector(exp_res) & std_logic_vector(mant_res(22 downto 0));
    
    
end Behavioral;

