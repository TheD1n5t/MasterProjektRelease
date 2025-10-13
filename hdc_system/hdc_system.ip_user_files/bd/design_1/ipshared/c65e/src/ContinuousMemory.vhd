library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ContinousMemory is
    generic (
        D : integer := 10000;  -- Vector width
        M : integer := 40     -- Number of stored vectors
    );
    Port (
        clk      : in  STD_LOGIC;                       -- Clock signal
        we       : in  STD_LOGIC;                       -- Write enable
        addr     : in  STD_LOGIC_VECTOR(15 downto 0);   -- Word address
        data_in  : in  STD_LOGIC_VECTOR(31 downto 0);   -- Data input
        data_out : out STD_LOGIC_VECTOR(31 downto 0)    -- Data output
    );
end ContinousMemory;

architecture Behavioral of ContinousMemory is

    -- === Configuration Constants ===
    constant WORD_WIDTH     : integer := 32;     -- Width per word
    constant CHUNKS_PER_VEC : integer := (D + WORD_WIDTH - 1) / WORD_WIDTH;
    constant MEM_DEPTH      : integer := CHUNKS_PER_VEC * M;  -- Total word count

    -- === Memory Array ===
    type memory_array is array (0 to MEM_DEPTH - 1) of std_logic_vector(WORD_WIDTH - 1 downto 0);
    signal memory : memory_array := (others => (others => '0'));

    -- === Output Register ===
    signal data_out_reg : std_logic_vector(WORD_WIDTH - 1 downto 0) := (others => '0');

    -- === Synthesis Hint: Use Block RAM ===
    attribute ram_style : string;
    attribute ram_style of memory : signal is "block";

begin

    -- Register output assignment
    data_out <= data_out_reg;

    -- === Synchronous Read/Write Memory Process ===
    process(clk)
        variable addr_int : integer;
    begin
        if rising_edge(clk) then
            -- Convert address to integer
            addr_int := to_integer(unsigned(addr));

            if addr_int < MEM_DEPTH then
                -- Perform write if enabled
                if we = '1' then
                    memory(addr_int) <= data_in;
                end if;

                -- Register read output (same-cycle registered read)
                data_out_reg <= memory(addr_int);
            else
                -- Address out of range: report and return zero
                report "Invalid CM access at addr = " & integer'image(addr_int)
                    severity failure;
                data_out_reg <= (others => '0');
            end if;
        end if;
    end process;

end Behavioral;
