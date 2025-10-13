library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity AssociativeMemory is
    Port (
        clk         : in  STD_LOGIC;                       -- Clock input
        we          : in  STD_LOGIC;                       -- Write enable
        am_addr     : in  STD_LOGIC_VECTOR(15 downto 0);   -- Address input (sized for 5 × 313 entries)
        am_data_in  : in  STD_LOGIC_VECTOR(31 downto 0);   -- Data to be written
        am_data_out : out STD_LOGIC_VECTOR(31 downto 0)    -- Read data output
    );
end AssociativeMemory;

architecture Behavioral of AssociativeMemory is

    -- === Configuration Constants ===
    constant VECTOR_WIDTH   : integer := 10000;  -- Bit-width of one vector
    constant WORD_WIDTH     : integer := 32;     -- Word size in bits
    constant NUM_VECTORS    : integer := 5;      -- Number of AM class vectors
    constant CHUNKS_PER_VEC : integer := (VECTOR_WIDTH + WORD_WIDTH - 1) / WORD_WIDTH;  -- = 313
    constant MEM_DEPTH      : integer := CHUNKS_PER_VEC * NUM_VECTORS;  -- = 5 * 313 = 1565

    -- === RAM Storage ===
    type memory_array is array (0 to MEM_DEPTH - 1) of std_logic_vector(WORD_WIDTH - 1 downto 0);
    signal memory : memory_array := (others => (others => '0'));

    -- === Synthesis Hint: Use Block RAM ===
    attribute ram_style : string;
    attribute ram_style of memory : signal is "block";

begin

    -- === Synchronous Read/Write Memory Process ===
    process(clk)
        variable addr_int : integer;
    begin
        if rising_edge(clk) then
            -- Convert address to integer
            addr_int := to_integer(unsigned(am_addr));

            if addr_int < MEM_DEPTH then
                -- Write operation if enabled
                if we = '1' then
                    memory(addr_int) <= am_data_in;
                end if;

                -- Read operation
                am_data_out <= memory(addr_int);
            else
                -- Address out of range
                report "Invalid memory access at addr = " & integer'image(addr_int)
                    severity failure;
                am_data_out <= (others => '0'); -- Return zero on error
            end if;
        end if;
    end process;

end Behavioral;
