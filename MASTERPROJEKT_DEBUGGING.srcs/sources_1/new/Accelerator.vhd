library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Accelerator is
    generic (
        D : integer := 10000;  -- Dimensionality of hypervectors
        N : integer := 32;     -- Number of input features
        M : integer := 200     -- Number of levels in Continuous Memory (CIM)
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
        bundled_result : out STD_LOGIC_VECTOR(D-1 downto 0); -- Majority result

        -- Memory interfaces for Identity Memory (IM) and Continuous Memory (CM)
        im_we : in STD_LOGIC;
        im_addr : in STD_LOGIC_VECTOR(15 downto 0);
        im_data_in : in STD_LOGIC_VECTOR(31 downto 0);
        cm_we : in STD_LOGIC;
        cm_addr : in STD_LOGIC_VECTOR(15 downto 0);
        cm_data_in : in STD_LOGIC_VECTOR(31 downto 0);
        im_data_out : out STD_LOGIC_VECTOR(31 downto 0);
        cm_data_out : out STD_LOGIC_VECTOR(31 downto 0);

        -- Debug outputs
        state_slv_debug : out STD_LOGIC_VECTOR(3 downto 0);
        im_data_dbg : out STD_LOGIC_VECTOR(31 downto 0);
        cm_data_dbg : out STD_LOGIC_VECTOR(31 downto 0);
        im_addr_mux_dbg : out std_logic_vector(15 downto 0);
        cm_addr_mux_dbg : out std_logic_vector(15 downto 0);
        chunk_counter_dbg : out std_logic_vector(9 downto 0);
        feature_index_dbg : out std_logic_vector(4 downto 0); -- N=32 → 5 bits
        level_index_dbg   : out std_logic_vector(7 downto 0);
        majority_chunk_dbg_0 : out std_logic_vector(31 downto 0);
        bound_chunk_dbg : out std_logic_vector(31 downto 0)
    );
end Accelerator;

architecture Behavioral of Accelerator is

    -- === Memory Components ===
    component IdentityMemory
        Port (
            clk      : in  STD_LOGIC;
            we       : in  STD_LOGIC;
            addr     : in  STD_LOGIC_VECTOR(15 downto 0);
            data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
            data_out : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    component ContinousMemory
        Port (
            clk      : in  STD_LOGIC;
            we       : in  STD_LOGIC;
            addr     : in  STD_LOGIC_VECTOR(15 downto 0);
            data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
            data_out : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    -- === Constants ===
    constant CHUNK_WIDTH     : integer := 32;
    constant CHUNKS_PER_VEC  : integer := (D + CHUNK_WIDTH - 1) / CHUNK_WIDTH;

    -- === Majority RAM (one 32-bit word per chunk of the result vector) ===
    type ram_array_type is array(0 to CHUNKS_PER_VEC-1) of std_logic_vector(31 downto 0);
    signal majority_ram : ram_array_type := (others => (others => '0'));

    -- === Bit counters for majority calculation (5-bit counters for each bit in a 32-bit chunk) ===
    type counter_array_type is array(0 to 31) of unsigned(4 downto 0);
    signal count_array : counter_array_type := (others => (others => '0'));

    -- === FSM State ===
    signal state : integer range 0 to 11 := 0;

    -- === Index signals for control ===
    signal feature_index : integer range 0 to N-1 := 0;
    signal chunk_counter : integer range 0 to CHUNKS_PER_VEC-1 := 0;
    signal level_index   : integer range 0 to M-1 := 0;

    -- === Memory data signals ===
    signal position_chunk : std_logic_vector(31 downto 0) := (others => '0');
    signal level_chunk    : std_logic_vector(31 downto 0) := (others => '0');
    signal bound_chunk    : std_logic_vector(31 downto 0) := (others => '0');

    -- === Address mux signals for IM/CM ===
    signal im_addr_mux, cm_addr_mux : std_logic_vector(15 downto 0);
    signal im_data, cm_data         : std_logic_vector(31 downto 0);

    -- === Debug and internal control ===
    signal test         : std_logic := '0';
    signal state_slv    : std_logic_vector(3 downto 0);
    signal start_prev   : std_logic := '0';
    signal im_addr_mux_dbg_reg : std_logic_vector(15 downto 0);
    signal cm_addr_mux_dbg_reg : std_logic_vector(15 downto 0);

begin

    -- === Identity Memory Address Muxing ===
    process(clk)
    begin
        if rising_edge(clk) then
            if load_mode = '1' then
                -- External memory load
                im_addr_mux <= im_addr;
            else
                -- Compute address based on feature_index and chunk_counter
                im_addr_mux <= std_logic_vector(to_unsigned(feature_index * CHUNKS_PER_VEC + chunk_counter, 16));
            end if;
            im_addr_mux_dbg_reg <= std_logic_vector(to_unsigned(feature_index * CHUNKS_PER_VEC + chunk_counter, 16));
        end if;
    end process;

    -- === Continuous Memory Address Muxing ===
    process(clk)
    begin
        if rising_edge(clk) then
            if load_mode = '1' then
                cm_addr_mux <= cm_addr;
            else
                cm_addr_mux <= std_logic_vector(to_unsigned(level_index * CHUNKS_PER_VEC + chunk_counter, 16));
            end if;
            cm_addr_mux_dbg_reg <= std_logic_vector(to_unsigned(level_index * CHUNKS_PER_VEC + chunk_counter, 16));
        end if;
    end process;

    -- === Identity Memory Instantiation ===
    IM: IdentityMemory
        port map (
            clk      => clk,
            we       => im_we,
            addr     => im_addr_mux,
            data_in  => im_data_in,
            data_out => im_data
        );

    -- === Continuous Memory Instantiation ===
    CIM: ContinousMemory
        port map (
            clk      => clk,
            we       => cm_we,
            addr     => cm_addr_mux,
            data_in  => cm_data_in,
            data_out => cm_data
        );

    -- === Output data when in load_mode ===
    im_data_out <= im_data when load_mode = '1' else (others => '0');
    cm_data_out <= cm_data when load_mode = '1' else (others => '0');

    -- === Main FSM: Controls Hypervector Encoding ===
    process(clk, reset)
    begin
        if reset = '1' then
            -- Reset all state and control signals
            state <= 0;
            feature_index <= 0;
            chunk_counter <= 0;
            majority_ram <= (others => (others => '0'));
            count_array <= (others => (others => '0'));
            bundled_result <= (others => '0');
            done <= '0';
            encoded_hv_ready <= '0';
            start_prev <= '0';

        elsif rising_edge(clk) then
            -- Save current FSM state for debug
            state_slv <= std_logic_vector(to_unsigned(state, 4));
            state_slv_debug <= state_slv;

            -- Store start signal from previous clock
            start_prev <= start;

            case state is

                when 0 =>  -- === IDLE ===
                    if start = '1' and start_prev = '0' and load_mode = '0' then
                        -- Rising edge of start & load_mode = 0 → begin encoding
                        bundled_result <= (others => '0');
                        feature_index <= 0;
                        chunk_counter <= 0;
                        count_array <= (others => (others => '0'));
                        done <= '0';
                        encoded_hv_ready <= '0';
                        state <= 1;
                    end if;

                when 1 =>  -- === Set IM Address ===
                    -- Address is already set via im_addr_mux process
                    state <= 2;

                when 2 =>  -- === Wait 1 cycle for IM data ===
                    -- Compute level_index from input feature value (mapped from 0..65535 to 0..M-1)
                    level_index <= (to_integer(unsigned(feature_values((feature_index+1)*16-1 downto feature_index*16))) * (M - 1) + 27500) / 55000;
                    state <= 3;

                when 3 =>  -- === Save IM Data ===
                    -- Wait state: transition to position chunk loading
                    state <= 4;
                            when 4 =>  -- === Load Position Hypervector Chunk ===
                    position_chunk <= im_data;
                    state <= 5;

                when 5 =>  -- === Set CM Address ===
                    -- Address is already set via cm_addr_mux process
                    state <= 6;

                when 6 =>  -- === Wait 1 cycle for CM data ===
                    state <= 7;

                when 7 =>  -- === Load Level Hypervector Chunk ===
                    level_chunk <= cm_data;
                    state <= 8;

                when 8 =>  -- === XOR Operation: Generate Bound Chunk ===
                    bound_chunk <= position_chunk xor level_chunk;

                    -- Count 1s in bound_chunk and accumulate per bit
                    for i in 0 to 31 loop
                        if bound_chunk(i) = '1' then
                            count_array(i) <= count_array(i) + 1;
                        end if;
                    end loop;

                    -- Next feature or switch to majority
                    if feature_index < N-1 then
                        feature_index <= feature_index + 1;
                        state <= 1;  -- Go to next feature
                    else
                        feature_index <= 0;
                        state <= 9;  -- All features processed → compute majority
                    end if;

                            when 9 =>  -- === Compute Majority for Current Chunk ===
                    for k in 0 to 31 loop
                        if (chunk_counter * 32 + k) < (D + 15) then
                            if count_array(k)(4) = '1' then
                                -- If count ≥ 16 (MSB of 5-bit counter = 1) → majority '1'
                                majority_ram(chunk_counter)(k) <= '1';
                            else
                                majority_ram(chunk_counter)(k) <= '0';
                            end if;
                        end if;
                    end loop;

                    -- Reset count array for next chunk
                    count_array <= (others => (others => '0'));

                    if chunk_counter < CHUNKS_PER_VEC - 1 then
                        chunk_counter <= chunk_counter + 1;
                        state <= 1;  -- Next chunk → restart feature loop
                    else
                        chunk_counter <= 0;
                        state <= 10; -- All chunks processed → build result
                    end if;

                when 10 =>  -- === Write Majority RAM into Output Vector ===
                    for i in 0 to 311 loop
                        bundled_result(D - i*32 - 1 downto D - (i+1)*32) <= majority_ram(i);
                    end loop;
                    -- Last partial chunk (e.g., 16 remaining bits)
                    for j in 0 to 15 loop
                        bundled_result(D - 312*32 - j) <= majority_ram(312)(31 - j);
                    end loop;

                    encoded_hv_ready <= '1';
                    done <= '1';
                    majority_ram <= (others => (others => '0'));
                    state <= 11;

                when 11 =>  -- === Cleanup and Return to IDLE ===
                    done <= '0';
                    state <= 0;

                when others =>
                    state <= 0;
            end case;
        end if;
    end process;

    -- === Debug Output Assignments ===
    chunk_counter_dbg     <= std_logic_vector(to_unsigned(chunk_counter, 10));
    feature_index_dbg     <= std_logic_vector(to_unsigned(feature_index, 5));
    level_index_dbg       <= std_logic_vector(to_unsigned(level_index, 8));
    majority_chunk_dbg_0  <= majority_ram(0);
    bound_chunk_dbg       <= bound_chunk;
    im_data_dbg           <= position_chunk;

    -- Register CM debug output to improve timing visibility
    process(clk)
    begin
        if rising_edge(clk) then
            cm_data_dbg <= cm_data;
        end if;
    end process;

    -- Output current IM/CM address for debug
    im_addr_mux_dbg <= im_addr_mux_dbg_reg;
    cm_addr_mux_dbg <= cm_addr_mux_dbg_reg;

end Behavioral;