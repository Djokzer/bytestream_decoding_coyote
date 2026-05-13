library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_fifo_1reg_sync_ready is
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
end entity;

architecture rtl of axis_fifo_1reg_sync_ready is
    signal data_reg    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal valid_reg   : std_logic ;
    signal ready_reg   : std_logic ; -- Registered ready
    signal backpressure : std_logic ;
begin
    --m_axis_tdata  <= s_axis_tdata;
    --m_axis_tvalid <= s_axis_tvalid;
    --s_axis_tready <= m_axis_tready;

    m_axis_tdata  <= s_axis_tdata when backpressure = '0' else data_reg;
    m_axis_tvalid <= s_axis_tvalid when backpressure = '0' else valid_reg;
    s_axis_tready <= not backpressure;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                valid_reg <= '0';
                ready_reg <= '1';
                backpressure <= '0';
            else
                backpressure <= (not m_axis_tready) and (valid_reg or s_axis_tvalid);
                if (backpressure = '0') then
                    data_reg  <= s_axis_tdata;
                    valid_reg <= s_axis_tvalid;
                end if;

                
            end if;
        end if;
    end process;

end architecture;
