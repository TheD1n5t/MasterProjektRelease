library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;


entity tb_axi_wrapper is
end tb_axi_wrapper;

architecture Behavioral of tb_axi_wrapper is

function to_bitvector(slv: std_logic_vector) return bit_vector is
    variable bv: bit_vector(slv'range);
begin
    for i in slv'range loop
        if slv(i) = '1' then
            bv(i) := '1';
        else
            bv(i) := '0';
        end if;
    end loop;
    return bv;
end function;


    signal S_AXI_ACLK     : std_logic := '0';
    signal S_AXI_ARESETN  : std_logic := '0';

    signal S_AXI_AWADDR   : std_logic_vector(31 downto 0) := (others => '0');
    signal S_AXI_AWVALID  : std_logic := '0';
    signal S_AXI_AWREADY  : std_logic;
    signal S_AXI_WDATA    : std_logic_vector(31 downto 0) := (others => '0');
    signal S_AXI_WSTRB    : std_logic_vector(3 downto 0) := (others => '1');
    signal S_AXI_WVALID   : std_logic := '0';
    signal S_AXI_WREADY   : std_logic;
    signal S_AXI_BRESP    : std_logic_vector(1 downto 0);
    signal S_AXI_BVALID   : std_logic;
    signal S_AXI_BREADY   : std_logic := '1';
    signal S_AXI_ARADDR   : std_logic_vector(31 downto 0) := (others => '0');
    signal S_AXI_ARVALID  : std_logic := '0';
    signal S_AXI_ARREADY  : std_logic;
    signal S_AXI_RDATA    : std_logic_vector(31 downto 0);
    signal S_AXI_RRESP    : std_logic_vector(1 downto 0);
    signal S_AXI_RVALID   : std_logic;
    signal S_AXI_RREADY   : std_logic := '1';

    component HDC_Controller_AXI_Wrapper
        port (
            S_AXI_ACLK     : in  STD_LOGIC;
            S_AXI_ARESETN  : in  STD_LOGIC;
            S_AXI_AWADDR   : in  STD_LOGIC_VECTOR(31 downto 0);
            S_AXI_AWVALID  : in  STD_LOGIC;
            S_AXI_AWREADY  : out STD_LOGIC;
            S_AXI_WDATA    : in  STD_LOGIC_VECTOR(31 downto 0);
            S_AXI_WSTRB    : in  STD_LOGIC_VECTOR(3 downto 0);
            S_AXI_WVALID   : in  STD_LOGIC;
            S_AXI_WREADY   : out STD_LOGIC;
            S_AXI_BRESP    : out STD_LOGIC_VECTOR(1 downto 0);
            S_AXI_BVALID   : out STD_LOGIC;
            S_AXI_BREADY   : in  STD_LOGIC;
            S_AXI_ARADDR   : in  STD_LOGIC_VECTOR(31 downto 0);
            S_AXI_ARVALID  : in  STD_LOGIC;
            S_AXI_ARREADY  : out STD_LOGIC;
            S_AXI_RDATA    : out STD_LOGIC_VECTOR(31 downto 0);
            S_AXI_RRESP    : out STD_LOGIC_VECTOR(1 downto 0);
            S_AXI_RVALID   : out STD_LOGIC;
            S_AXI_RREADY   : in  STD_LOGIC
        );
    end component;

begin

    dut: HDC_Controller_AXI_Wrapper
        port map (
            S_AXI_ACLK     => S_AXI_ACLK,
            S_AXI_ARESETN  => S_AXI_ARESETN,
            S_AXI_AWADDR   => S_AXI_AWADDR,
            S_AXI_AWVALID  => S_AXI_AWVALID,
            S_AXI_AWREADY  => S_AXI_AWREADY,
            S_AXI_WDATA    => S_AXI_WDATA,
            S_AXI_WSTRB    => S_AXI_WSTRB,
            S_AXI_WVALID   => S_AXI_WVALID,
            S_AXI_WREADY   => S_AXI_WREADY,
            S_AXI_BRESP    => S_AXI_BRESP,
            S_AXI_BVALID   => S_AXI_BVALID,
            S_AXI_BREADY   => S_AXI_BREADY,
            S_AXI_ARADDR   => S_AXI_ARADDR,
            S_AXI_ARVALID  => S_AXI_ARVALID,
            S_AXI_ARREADY  => S_AXI_ARREADY,
            S_AXI_RDATA    => S_AXI_RDATA,
            S_AXI_RRESP    => S_AXI_RRESP,
            S_AXI_RVALID   => S_AXI_RVALID,
            S_AXI_RREADY   => S_AXI_RREADY
        );

    -- Clock
    clk_proc: process
    begin
        while true loop
            S_AXI_ACLK <= '0'; wait for 5 ns;
            S_AXI_ACLK <= '1'; wait for 5 ns;
        end loop;
    end process;

    -- Stimulus
    stim_proc: process
    variable addr_int : integer := 0;
    variable addr_slv : std_logic_vector(31 downto 0);
begin
    -- Reset
    S_AXI_ARESETN <= '0';
    wait for 20 ns;
    S_AXI_ARESETN <= '1';
    wait for 20 ns;

    ------------------------------------------------------
    -- 1. Schreibe 0x00001234 nach Register 0x04
    ------------------------------------------------------
    S_AXI_AWADDR  <= x"00000004";
    S_AXI_WDATA   <= x"00001234";
    S_AXI_AWVALID <= '1';
    S_AXI_WVALID  <= '1';

    wait until rising_edge(S_AXI_ACLK) and S_AXI_AWREADY = '1' and S_AXI_WREADY = '1';
    S_AXI_AWVALID <= '0';
    S_AXI_WVALID  <= '0';

    wait until rising_edge(S_AXI_ACLK) and S_AXI_BVALID = '1';
    wait until rising_edge(S_AXI_ACLK);

    ------------------------------------------------------
    -- 2. Lies alle wichtigen Register aus (inkl. 0x04)
    ------------------------------------------------------
    for i in 0 to 15 loop
        addr_int := i * 4;
        addr_slv := std_logic_vector(to_unsigned(addr_int, 32));

       -- Starte Leseoperation
        S_AXI_ARADDR  <= x"00000004"; 
        S_AXI_ARVALID <= '1';
        
        -- Warte bis DUT ARREADY setzt (Handshake)
        wait until rising_edge(S_AXI_ACLK) and S_AXI_ARREADY = '1';
        
        -- Beende AR-Phase
        S_AXI_ARVALID <= '0';
        
        -- Warte bis RVALID bei Taktflanke aktiv wird
        loop
            wait until S_AXI_ACLK = '1' and S_AXI_ACLK'event;
            exit when S_AXI_RVALID = '1';
        end loop;

        
        -- Jetzt kannst du lesen
        report "AXI READ @ " & integer'image(addr_int) &
               " = " & to_hstring(to_bitvector(S_AXI_RDATA));
        

        wait until rising_edge(S_AXI_ACLK);
    end loop;

    wait;
end process;


end Behavioral;