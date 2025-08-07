library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HDC_Controller_AXI_Wrapper is
    Port (
        S_AXI_ACLK     : in  STD_LOGIC;
        S_AXI_ARESETN  : in  STD_LOGIC;

        -- AXI Write Channel
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

        -- AXI Read Channel
        S_AXI_ARADDR   : in  STD_LOGIC_VECTOR(31 downto 0);
        S_AXI_ARVALID  : in  STD_LOGIC;
        S_AXI_ARREADY  : out STD_LOGIC;
        S_AXI_RDATA    : out STD_LOGIC_VECTOR(31 downto 0);
        S_AXI_RRESP    : out STD_LOGIC_VECTOR(1 downto 0);
        S_AXI_RVALID   : out STD_LOGIC;
        S_AXI_RREADY   : in  STD_LOGIC;

        feature_value           : out STD_LOGIC_VECTOR(15 downto 0);
        expected_class_index    : out STD_LOGIC_VECTOR(2 downto 0);
        feature_valid_pulse     : out STD_LOGIC;

        -- Debug for ILA
        feature_valid_reg_dbg     : out STD_LOGIC;
        feature_valid_prev_dbg    : out STD_LOGIC;
        feature_valid_pulse_dbg   : out STD_LOGIC;
        feature_values_packed_dbg : out STD_LOGIC_VECTOR(511 downto 0);
        status_bits_dbg           : out STD_LOGIC_VECTOR(2 downto 0);
        bundled_result_ila_dbg : out STD_LOGIC_VECTOR(255 downto 0);
        bundled_result_acc_ila_dbg : out STD_LOGIC_VECTOR(255 downto 0);
        accelerator_state_dbg     : out STD_LOGIC_VECTOR(3 downto 0);
        im_data_dbg : out STD_LOGIC_VECTOR(31 downto 0);
        cm_data_dbg : out STD_LOGIC_VECTOR(31 downto 0);
        im_addr_mux_dbg : out std_logic_vector(15 downto 0);
        cm_addr_mux_dbg : out std_logic_vector(15 downto 0);
        chunk_counter_dbg : out std_logic_vector(9 downto 0);
        feature_index_dbg : out std_logic_vector(4 downto 0);
        level_index_dbg   : out std_logic_vector(7 downto 0);
        chunk_counter_internal_dbg : out std_logic_vector(2 downto 0);
        similarity_counter_dbg    : out std_logic_vector(7 downto 0);
        min_hamming_distance_dbg : out unsigned(15 downto 0);
        majority_chunk_dbg_0 : out std_logic_vector(31 downto 0);
        bound_chunk_dbg : out std_logic_vector(31 downto 0);
        memory_index_dbg : out unsigned(2 downto 0);
        compare_state_dbg : out std_logic_vector(3 downto 0);
        xor_chunk_dbg : out std_logic_vector(3 downto 0);
        popcount_step_dbg : out std_logic_vector(2 downto 0);
        segment_index_dbg : out std_logic_vector(5 downto 0);
        sim_counter_dbg : out STD_LOGIC_VECTOR(7 downto 0)
    );
end HDC_Controller_AXI_Wrapper;

architecture Behavioral of HDC_Controller_AXI_Wrapper is

    constant C_NUM_REGS : integer := 11;
    type reg_array is array(0 to C_NUM_REGS-1) of STD_LOGIC_VECTOR(31 downto 0);
    signal slv_reg : reg_array := (others => (others => '0'));

    signal clk   : STD_LOGIC;
    signal reset : STD_LOGIC;

    signal axi_awready_int : STD_LOGIC := '0';
    signal axi_wready_int  : STD_LOGIC := '0';
    signal axi_bvalid_int  : STD_LOGIC := '0';
    signal axi_arready_int : STD_LOGIC := '0';
    signal axi_rvalid_int  : STD_LOGIC := '0';
    signal axi_rdata_int   : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal araddr_index : integer := 0;

    signal awaddr_int, araddr_int : STD_LOGIC_VECTOR(31 downto 0);
    signal write_addr_latched, write_data_latched : STD_LOGIC := '0';

    signal feature_valid_reg, feature_valid_prev, feature_valid_pulse_int : STD_LOGIC;
    signal feature_value_int        : STD_LOGIC_VECTOR(15 downto 0);
    signal expected_class_index_int : STD_LOGIC_VECTOR(2 downto 0);
    signal start                    : STD_LOGIC;
    signal read_addr_latched : std_logic := '0';

    signal done                    : STD_LOGIC;
    signal done_encoding_monitor   : STD_LOGIC;
    signal mem_data_out            : STD_LOGIC_VECTOR(31 downto 0);
    signal similarity_counter_out  : STD_LOGIC_VECTOR(7 downto 0);
    signal load_mode               : STD_LOGIC;
    signal mem_sel                 : STD_LOGIC_VECTOR(1 downto 0);
    signal mem_we                  : STD_LOGIC;
    signal mem_addr                : STD_LOGIC_VECTOR(15 downto 0);
    signal mem_data_in             : STD_LOGIC_VECTOR(31 downto 0);
    signal status_bits             : STD_LOGIC_VECTOR(2 downto 0);
    signal status_bits_extended    : STD_LOGIC_VECTOR(6 downto 0);
    signal accelerator_state_dbg_internal : std_logic_vector(3 downto 0);
    signal bundled_result_ila_dbg_internal : STD_LOGIC_VECTOR(9999 downto 0);
    signal bundled_result_ila_acc_dbg_internal : STD_LOGIC_VECTOR(9999 downto 0);
    signal min_hamming_distance_internal : unsigned(15 downto 0);
    -- In der Architektur hinzufügen:
    signal bundled_result_internal : STD_LOGIC_VECTOR(9999 downto 0);
    signal bundled_result_acc_internal : STD_LOGIC_VECTOR(9999 downto 0);
    signal im_data_dbg_internal : STD_LOGIC_VECTOR(31 downto 0);
    signal cm_data_dbg_internal : STD_LOGIC_VECTOR(31 downto 0);
    signal im_addr_mux_dbg_internal : std_logic_vector(15 downto 0);
    signal cm_addr_mux_dbg_internal : std_logic_vector(15 downto 0);
    signal chunk_counter_dbg_internal : std_logic_vector(9 downto 0);
    signal feature_index_dbg_internal : std_logic_vector(4 downto 0);
    signal level_index_dbg_internal   : std_logic_vector(7 downto 0);
    signal chunk_counter_internal_dbg_internal : std_logic_vector(2 downto 0);
    signal similarity_counter_dbg_internal : std_logic_vector(7 downto 0);
    signal majority_chunk_dbg_0_internal : std_logic_vector(31 downto 0);
    signal bound_chunk_dbg_internal : std_logic_vector(31 downto 0);
    signal memory_index_dbg_internal : unsigned(2 downto 0);
    signal compare_state_dbg_internal: std_logic_vector(3 downto 0);
    signal xor_chunk_dbg_internal : std_logic_vector(3 downto 0);
    signal popcount_step_dbg_internal : std_logic_vector(2 downto 0);
    signal segment_index_dbg_internal : std_logic_vector(5 downto 0);
    signal sim_counter_dbg_internal : STD_LOGIC_VECTOR(7 downto 0);
begin

    clk   <= S_AXI_ACLK;
    reset <= not S_AXI_ARESETN;

    process(clk)
        variable reg_index : integer;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                axi_awready_int <= '0'; axi_wready_int <= '0'; axi_bvalid_int <= '0';
                write_addr_latched <= '0'; write_data_latched <= '0';
            else
                if S_AXI_AWVALID = '1' and axi_awready_int = '0' then
                    axi_awready_int <= '1'; awaddr_int <= S_AXI_AWADDR; write_addr_latched <= '1';
                end if;
                if S_AXI_WVALID = '1' and axi_wready_int = '0' then
                    axi_wready_int <= '1'; write_data_latched <= '1';
                end if;
                if write_addr_latched = '1' and write_data_latched = '1' then
                    reg_index := to_integer(unsigned(awaddr_int(5 downto 2)));
                    if reg_index >= 0 and reg_index < C_NUM_REGS then
                        slv_reg(reg_index) <= S_AXI_WDATA;
                    end if;
                    axi_awready_int <= '0'; axi_wready_int <= '0'; axi_bvalid_int <= '1';
                    write_addr_latched <= '0'; write_data_latched <= '0';
                end if;
                if axi_bvalid_int = '1' and S_AXI_BREADY = '1' then
                    axi_bvalid_int <= '0';
                end if;
            end if;
        end if;
    end process;

   ----------------------------------------------------------
    -- Read Address Ready
    ----------------------------------------------------------
    

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                axi_arready_int     <= '0';
                araddr_int          <= (others => '0');
                read_addr_latched   <= '0';
            elsif (S_AXI_ARVALID = '1') and (axi_arready_int = '0') then
                axi_arready_int     <= '1';                 -- Setze ARREADY
                araddr_int          <= S_AXI_ARADDR;        -- Latch Adresse
                read_addr_latched   <= '1';                 -- Triggere Leseprozess
            else
                axi_arready_int     <= '0';
                read_addr_latched   <= '0'; -- Hier war der Bug vorher!
            end if;
        end if;
    end process;


    ----------------------------------------------------------
    -- Read Data Valid + MUX
    ----------------------------------------------------------
   process(clk)
    variable reg_index : integer;
begin
    if rising_edge(clk) then
        if reset = '1' then
            axi_rvalid_int <= '0';
            axi_rdata_int  <= (others => '0');
        elsif read_addr_latched = '1' then
            axi_rvalid_int <= '1';

            reg_index := to_integer(unsigned(araddr_int(5 downto 2)));
            case reg_index is
                when 0  => axi_rdata_int <= slv_reg(0);
                when 1  => axi_rdata_int <= slv_reg(1);
                when 2  => axi_rdata_int <= slv_reg(2);
                when 3  => axi_rdata_int <= slv_reg(3);
                when 4  => axi_rdata_int <= slv_reg(4);
                when 5  => axi_rdata_int <= slv_reg(5);
                when 6  => axi_rdata_int <= slv_reg(6);
                when 7  => axi_rdata_int <= slv_reg(7);
                when 8  => axi_rdata_int <= slv_reg(8);
                when 9  => axi_rdata_int <= slv_reg(9);
                when 10 => axi_rdata_int <= slv_reg(10);
                when 11 => axi_rdata_int <= (23 downto 0 => '0') & sim_counter_dbg_internal;
                when 13 => axi_rdata_int <= x"DEADBEEF";  -- Testregister mit fixem Wert
                when 14 => axi_rdata_int <= (28 downto 0 => '0') & status_bits;
                when others =>
                    axi_rdata_int <= (others => '0');
            end case;

        elsif (axi_rvalid_int = '1') and (S_AXI_RREADY = '1') then
            axi_rvalid_int <= '0'; -- Handshake abgeschlossen
        end if;
    end if;
end process;




    feature_valid_reg <= slv_reg(3)(0);
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                feature_valid_prev <= '0'; feature_valid_pulse_int <= '0';
            else
                feature_valid_prev <= feature_valid_reg;
                if feature_valid_reg = '1' and feature_valid_prev = '0' then
                    feature_valid_pulse_int <= '1';
                else
                    feature_valid_pulse_int <= '0';
                end if;
            end if;
        end if;
    end process;

    start                    <= slv_reg(0)(0);
    feature_value_int        <= slv_reg(1)(15 downto 0);
    expected_class_index_int <= slv_reg(2)(10 downto 8);
    mem_sel                  <= slv_reg(4)(1 downto 0);
    mem_we                   <= slv_reg(5)(0);
    mem_addr                 <= slv_reg(6)(15 downto 0);
    mem_data_in              <= slv_reg(7);
    load_mode                <= slv_reg(8)(0);

    feature_value            <= feature_value_int;
    expected_class_index     <= expected_class_index_int;
    feature_valid_pulse      <= feature_valid_pulse_int;

    status_bits <= start & done_encoding_monitor & done;
    status_bits_extended <= accelerator_state_dbg_internal & status_bits;

    S_AXI_AWREADY <= axi_awready_int;
    S_AXI_WREADY  <= axi_wready_int;
    S_AXI_BVALID  <= axi_bvalid_int;
    S_AXI_BRESP   <= "00";
    S_AXI_ARREADY <= axi_arready_int;
    S_AXI_RVALID  <= axi_rvalid_int;
    S_AXI_RRESP   <= "00";
    S_AXI_RDATA   <= axi_rdata_int;

    feature_valid_reg_dbg     <= feature_valid_reg;
    feature_valid_prev_dbg    <= feature_valid_prev;
    feature_valid_pulse_dbg   <= feature_valid_pulse_int;
    status_bits_dbg           <= status_bits;
    accelerator_state_dbg     <= accelerator_state_dbg_internal;
    bundled_result_ila_dbg_internal <= bundled_result_internal;
    bundled_result_ila_dbg          <= bundled_result_internal(9999 downto 9744);
    bundled_result_acc_ila_dbg      <= bundled_result_acc_internal(9999 downto 9744);
    im_data_dbg <= im_data_dbg_internal;
    cm_data_dbg <= cm_data_dbg_internal;
    im_addr_mux_dbg <= im_addr_mux_dbg_internal;
    cm_addr_mux_dbg <= cm_addr_mux_dbg_internal;
    chunk_counter_dbg   <= chunk_counter_dbg_internal;
    feature_index_dbg   <= feature_index_dbg_internal;
    level_index_dbg     <= level_index_dbg_internal;
    chunk_counter_internal_dbg <= chunk_counter_internal_dbg_internal;
    similarity_counter_dbg <= similarity_counter_dbg_internal;
    min_hamming_distance_dbg <= min_hamming_distance_internal;
    majority_chunk_dbg_0 <= majority_chunk_dbg_0_internal;
    bound_chunk_dbg <= bound_chunk_dbg_internal;
    memory_index_dbg <= memory_index_dbg_internal;
    compare_state_dbg <= compare_state_dbg_internal;
    xor_chunk_dbg <= xor_chunk_dbg_internal;
    popcount_step_dbg <= popcount_step_dbg_internal;
    segment_index_dbg <= segment_index_dbg_internal;
    sim_counter_dbg <= sim_counter_dbg_internal;
    
    hdc_unit: entity work.HDC_Controller
    port map (
        clk                          => clk,
        reset                        => reset,
        start                        => start,
        done                         => done,
        similarity_counter_out       => similarity_counter_dbg_internal,
        feature_value                => feature_value_int,
        feature_valid                => feature_valid_pulse_int,
        expected_class_index         => expected_class_index_int,
        mem_sel                      => mem_sel,
        mem_we                       => mem_we,
        mem_addr                     => mem_addr,
        mem_data_in                  => mem_data_in,
        done_encoding_monitor        => done_encoding_monitor,
        internal_done                => open,
        load_mode                    => load_mode,
        mem_data_out                 => mem_data_out,
        feature_values_packed_dbg    => feature_values_packed_dbg,
        accelerator_state_dbg        => accelerator_state_dbg_internal,
        bundled_result_ila_dbg       => bundled_result_internal,
        bundled_result_acc_ila_dbg   => bundled_result_acc_internal,
        im_data_dbg                  => im_data_dbg_internal,  
        cm_data_dbg                  => cm_data_dbg_internal,    
        im_addr_mux_dbg => im_addr_mux_dbg_internal,
        cm_addr_mux_dbg => cm_addr_mux_dbg_internal,
        chunk_counter_dbg      => chunk_counter_dbg_internal,
        feature_index_dbg      => feature_index_dbg_internal,
        level_index_dbg        => level_index_dbg_internal,
        chunk_counter_internal_dbg   => chunk_counter_internal_dbg_internal,
        min_hamming_distance_dbg => min_hamming_distance_internal,
        majority_chunk_dbg_0 => majority_chunk_dbg_0_internal,
        bound_chunk_dbg => bound_chunk_dbg_internal,
        memory_index_dbg => memory_index_dbg_internal,
        compare_state_dbg => compare_state_dbg_internal,
        xor_chunk_dbg => xor_chunk_dbg_internal,
        popcount_step_dbg => popcount_step_dbg_internal,
        segment_index_dbg => segment_index_dbg_internal,
        sim_counter_dbg => sim_counter_dbg_internal
    );


end Behavioral;