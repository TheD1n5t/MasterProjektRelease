library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter_ram is
    generic (
        DEPTH      : integer := 10000;
        ADDR_WIDTH : integer := 14
    );
    port (
        clk    : in  std_logic;

        -- Port A: Read-only
        addr_a : in  unsigned(ADDR_WIDTH-1 downto 0);
        dout_a : out unsigned(9 downto 0);

        -- Port B: Write-only
        addr_b : in  unsigned(ADDR_WIDTH-1 downto 0);
        din_b  : in  unsigned(9 downto 0);
        we_b   : in  std_logic
    );
end entity;

architecture Behavioral of counter_ram is
    type ram_type is array (0 to DEPTH-1) of unsigned(9 downto 0);
    signal ram : ram_type := (others => (others => '0'));
begin
    -- Port A: Synchronous read
    process(clk)
    begin
        if rising_edge(clk) then
            dout_a <= ram(to_integer(addr_a));
        end if;
    end process;

    -- Port B: Synchronous write
    process(clk)
    begin
        if rising_edge(clk) then
            if we_b = '1' then
                ram(to_integer(addr_b)) <= din_b;
            end if;
        end if;
    end process;
end architecture;
