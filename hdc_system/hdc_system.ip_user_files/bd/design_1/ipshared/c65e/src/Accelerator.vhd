library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================
-- Entity: Accelerator
-- ============================================================
-- Encodes input features into a high-dimensional hypervector.
-- Uses:
--   - Identity Memory (IM): provides position hypervectors
--   - Continuous Memory (CM): provides level hypervectors
-- For each feature, the IM vector is XORed with the CM vector.
-- A majority mechanism accumulates the results over all features
-- to generate the bundled result hypervector.
--
-- Generics:
--   D : Hypervector dimension (default 10000)
--   N : Number of features (default 32)
--   M : Number of quantization levels in CM (default 40)
--
entity Accelerator is
    generic (
        D : integer := 10000;  -- Dimensionality of hypervectors
        N : integer := 32;     -- Number of input features
        M : integer := 40      -- Number of levels in Continuous Memory (CIM)
    );
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;

        -- Feature input: N × 16-bit packed values
        feature_values : in STD_LOGIC_VECTOR(N*16-1 downto 0);
        start : in STD_LOGIC;                 -- Start signal (1-pulse)
        load_mode : in STD_LOGIC;             -- If '1', external memory write/read mode

        -- Result
        done : out STD_LOGIC;                 -- Indicates computation done
        encoded_hv_ready : out STD_LOGIC;     -- Hypervector encoding done
        bundled_result : out STD_LOGIC_VECTOR(D-1 downto 0); -- Final bundled hypervector

        -- Memory interfaces for Identity Memory (IM) and Continuous Memory (CM)
        im_we : in STD_LOGIC;
        im_addr : in STD_LOGIC_VECTOR(15 downto 0);
        im_data_in : in STD_LOGIC_VECTOR(31 downto 0);
        cm_we : in STD_LOGIC;
        cm_addr : in STD_LOGIC_VECTOR(15 downto 0);
        cm_data_in : in STD_LOGIC_VECTOR(31 downto 0);
        im_data_out : out STD_LOGIC_VECTOR(31 downto 0);
        cm_data_out : out STD_LOGIC_VECTOR(31 downto 0)
    );
end Accelerator;


architecture Behavioral of Accelerator is

    -- ============================================================
    -- Components: IM + CM
    -- ============================================================
    -- IdentityMemory:
    --   Provides unique random hypervector per feature index
    --
    component IdentityMemory
    Port (
        clk : in STD_LOGIC;
        we : in STD_LOGIC;
        addr : in STD_LOGIC_VECTOR(15 downto 0);
        data_in : in STD_LOGIC_VECTOR(31 downto 0);
        data_out : out STD_LOGIC_VECTOR(31 downto 0)
    );
    end component;

    -- ContinuousMemory:
    --   Provides level-specific hypervector, depending on quantized feature value
    --
    component ContinousMemory
    generic (
        D : integer := 10000;
        M : integer := 40
    );
    Port (
        clk : in STD_LOGIC;
        we : in STD_LOGIC;
        addr : in STD_LOGIC_VECTOR(15 downto 0);
        data_in : in STD_LOGIC_VECTOR(31 downto 0);
        data_out : out STD_LOGIC_VECTOR(31 downto 0)
    );
    end component;

    -- ============================================================
    -- Constants
    -- ============================================================
    constant CHUNK_WIDTH    : integer := 32;  -- Each memory word = 32 bits
    constant CHUNKS_PER_VEC : integer := (D + CHUNK_WIDTH - 1) / CHUNK_WIDTH;
        -- Number of 32-bit chunks required to represent one hypervector

    -- ============================================================
    -- Majority RAM
    -- ============================================================
    type ram_array_type is array(0 to CHUNKS_PER_VEC-1) of std_logic_vector(31 downto 0);
    signal majority_ram : ram_array_type := (others => (others => '0'));

    -- ============================================================
    -- Local counters for per-bit accumulation
    -- ============================================================
    -- Each of the 32 bits in a chunk has its own 5-bit counter
    -- (enough for max count = 32 features).
    type counter_array_type is array(0 to 31) of unsigned(4 downto 0);

    -- ============================================================
    -- FSM State register
    -- ============================================================
    -- States of the encoding process:
    --   0 = Idle
    --   1 = Prepare IM/CM read
    --   2 = Wait cycle (for BRAM latency)
    --   3 = Process XOR & accumulate ones into counters
    --   4 = Write chunk majority result into majority_ram
    --   5 = Finalize → build bundled_result
    signal state : integer range 0 to 5 := 0;

    -- ============================================================
    -- Indices for feature and chunk processing
    -- ============================================================
    signal feature_index : integer range 0 to N-1 := 0;
    signal chunk_counter : integer range 0 to CHUNKS_PER_VEC-1 := 0;
    signal level_index   : integer range 0 to M-1 := 0;

    -- ============================================================
    -- Address muxing and data signals for IM / CM
    -- ============================================================
    signal im_addr_mux, cm_addr_mux : std_logic_vector(15 downto 0);
    signal im_data, cm_data : std_logic_vector(31 downto 0);
    signal im_read_en, cm_read_en : std_logic := '0';

    -- ============================================================
    -- Debug / control
    -- ============================================================
    signal test       : std_logic := '0';
    signal state_slv  : std_logic_vector(3 downto 0);
    signal start_prev : std_logic := '0';

begin

    -- ============================================================
    -- Identity Memory Address Multiplexing
    -- ============================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if load_mode = '1' then
                im_addr_mux <= im_addr;
            else
                im_addr_mux <= std_logic_vector(
                    to_unsigned(feature_index * CHUNKS_PER_VEC + chunk_counter, 16)
                );
            end if;
        end if;
    end process;

    -- ============================================================
    -- Continuous Memory Address Multiplexing
    -- ============================================================
    process(clk)
        variable level_index : integer range 0 to M-1 := 0;
    begin
        if rising_edge(clk) then
            if load_mode = '1' then
                cm_addr_mux <= cm_addr;
            else
                -- Quantize 16-bit feature value into one of M levels
                level_index := (to_integer(
                                    unsigned(feature_values((feature_index+1)*16-1 downto feature_index*16))
                                ) * (M - 1) + 10000) / 20000;

                cm_addr_mux <= std_logic_vector(
                    to_unsigned(level_index * CHUNKS_PER_VEC + chunk_counter, 16)
                );
            end if;
        end if;
    end process;

    -- ============================================================
    -- Memory Instantiations
    -- ============================================================
    IM: IdentityMemory
    port map (
        clk     => clk,
        we      => im_we,
        addr    => im_addr_mux,
        data_in => im_data_in,
        data_out=> im_data
    );

    CIM: ContinousMemory 
        generic map (
            D => D,
            M => M
        )
    port map (
        clk     => clk, 
        we      => cm_we, 
        addr    => cm_addr_mux, 
        data_in => cm_data_in, 
        data_out=> cm_data
    );

    -- ============================================================
    -- External Data Outputs
    -- ============================================================
    im_data_out <= im_data when load_mode = '1' else (others => '0');
    cm_data_out <= cm_data when load_mode = '1' else (others => '0');

    -- ============================================================
    -- FSM: Encoding Process
    -- ============================================================
  process(clk, reset)
    variable position_chunk : std_logic_vector(31 downto 0) := (others => '0');
    variable level_chunk    : std_logic_vector(31 downto 0) := (others => '0');
    variable bound_chunk    : std_logic_vector(31 downto 0) := (others => '0');
    variable count_array : counter_array_type := (others => (others => '0'));
  begin
    if reset = '1' then
        state         <= 0;
        feature_index <= 0;
        chunk_counter <= 0;
        majority_ram  <= (others => (others => '0'));
        count_array   := (others => (others => '0'));
        bundled_result <= (others => '0');
        done          <= '0';
        encoded_hv_ready <= '0';
        im_read_en    <= '0';
        cm_read_en    <= '0';

    elsif rising_edge(clk) then
        case state is

            -- STATE 0: Idle
            when 0 =>
                done <= '0';
                if start = '1' and load_mode = '0' then
                    bundled_result   <= (others => '0');
                    feature_index    <= 0;
                    chunk_counter    <= 0;
                    count_array      := (others => (others => '0'));
                    done             <= '0';
                    encoded_hv_ready <= '0';
                    state            <= 1;
                end if;

            -- STATE 1: Prepare IM/CM read
            when 1 =>
                state <= 2;

            -- STATE 2: Wait cycle (BRAM latency)
            when 2 =>
                state <= 3;

            -- STATE 3: XOR & accumulate
            when 3 =>
                position_chunk := im_data;
                level_chunk    := cm_data;
                bound_chunk    := position_chunk xor level_chunk;

                for i in 0 to 31 loop
                    if bound_chunk(i) = '1' then
                        count_array(i) := count_array(i) + 1;
                    end if;
                end loop;

                if feature_index < N-1 then
                    feature_index <= feature_index + 1;
                    state <= 1;
                else
                    feature_index <= 0;
                    state <= 4;
                end if;

            -- STATE 4: Majority vote for current chunk
            when 4 =>
                for k in 0 to 31 loop
                    if (chunk_counter * 32 + k) < (D+15) then
                        if count_array(k)(4) = '1' then
                            majority_ram(chunk_counter)(k) <= '1';
                        else
                            majority_ram(chunk_counter)(k) <= '0';
                        end if;
                    end if;
                end loop;
                count_array := (others => (others => '0'));

                if chunk_counter < CHUNKS_PER_VEC-1 then
                    chunk_counter <= chunk_counter + 1;
                    state <= 1;
                else
                    chunk_counter <= 0;
                    state <= 5;
                end if;

            -- STATE 5: Build bundled_result
            when 5 =>
                for i in 0 to CHUNKS_PER_VEC-1 loop
                    if i < CHUNKS_PER_VEC-1 then
                        bundled_result(D-i*32-1 downto D-(i+1)*32) <= majority_ram(i);
                    else
                        for j in 0 to 15 loop
                            bundled_result(D-i*32 - j) <= majority_ram(i)(31-j);
                        end loop;
                    end if;
                end loop;

                encoded_hv_ready <= '1';
                done             <= '1';
                majority_ram     <= (others => (others => '0'));
                state <= 0;

            -- Default
            when others =>
                state <= 0;
        end case;
    end if;
  end process;

end Behavioral;
