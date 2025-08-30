library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ContinousMemory is
    Port (
        clk       : in  STD_LOGIC;
        we        : in  STD_LOGIC;
        addr      : in  STD_LOGIC_VECTOR(15 downto 0);
        data_in   : in  STD_LOGIC_VECTOR(31 downto 0);
        data_out  : out STD_LOGIC_VECTOR(31 downto 0)
    );
end ContinousMemory;

architecture Behavioral of ContinousMemory is
    constant VECTOR_WIDTH   : integer := 10000;
    constant WORD_WIDTH     : integer := 32;
    constant NUM_VECTORS    : integer := 200;
    constant CHUNKS_PER_VEC : integer := (VECTOR_WIDTH + WORD_WIDTH - 1) / WORD_WIDTH;
    constant MEM_DEPTH      : integer := CHUNKS_PER_VEC * NUM_VECTORS;  -- 15650

    type memory_array is array (0 to MEM_DEPTH - 1) of std_logic_vector(WORD_WIDTH - 1 downto 0);
    signal memory : memory_array := (others => (others => '0'));

    signal data_out_reg : std_logic_vector(31 downto 0) := (others => '0');

    attribute ram_style : string;
    attribute ram_style of memory : signal is "block";
begin

    data_out <= data_out_reg;

    process(clk)
        variable addr_int : integer;
    begin
        if rising_edge(clk) then
            addr_int := to_integer(unsigned(addr));
            if addr_int < MEM_DEPTH then
                if we = '1' then
                    memory(addr_int) <= data_in;
                end if;
                data_out_reg <= memory(addr_int);
            else
                report "Invalid memory access at addr = " & integer'image(addr_int)
                    severity failure;
                data_out_reg <= (others => '0');
            end if;
        end if;
    end process;

end Behavioral;
