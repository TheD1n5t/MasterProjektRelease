library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HDC_Controller is
    generic (
        D : integer := 10000;  -- Dimensionality of the hypervectors
        N : integer := 32;     -- Number of features per sample
        M : integer := 200;    -- Number of items in Continuous Item Memory (CIM)
        A : integer := 5       -- Number of Associative Memory (AM) classes
    );
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        start : in STD_LOGIC;
        done : out STD_LOGIC;
        feature_value : in STD_LOGIC_VECTOR(15 downto 0);         -- Incoming feature value
        feature_valid : in STD_LOGIC;                             -- Pulsed high for each feature
        similarity_counter_out : out STD_LOGIC_VECTOR(7 downto 0);-- Number of correct matches

        -- Memory interface (shared between IM, CM, and AM)
        mem_sel      : in  STD_LOGIC_VECTOR(1 downto 0);          -- "00" = IM, "01" = CM, "10" = AM
        mem_we       : in  STD_LOGIC;
        mem_addr     : in  STD_LOGIC_VECTOR(15 downto 0);
        mem_data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
        mem_data_out : out STD_LOGIC_VECTOR(31 downto 0);

        -- Top-level debug and state outputs
        majority : out STD_LOGIC_VECTOR(D-1 downto 0);            -- Final result vector (not used internally)
        internal_done: out STD_LOGIC;
        done_encoding_monitor : out STD_LOGIC;
        expected_class_index : in STD_LOGIC_VECTOR(2 downto 0);   -- Ground truth label for comparison

        -- Debug outputs
        feature_values_packed_dbg : out STD_LOGIC_VECTOR(N*16-1 downto 0);
        load_mode : in STD_LOGIC;
        accelerator_state_dbg : out STD_LOGIC_VECTOR(3 downto 0);
        bundled_result_ila_dbg : out STD_LOGIC_VECTOR(D-1 downto 0);
        bundled_result_acc_ila_dbg : out STD_LOGIC_VECTOR(D-1 downto 0);
        im_data_dbg : out STD_LOGIC_VECTOR(31 downto 0);
        cm_data_dbg : out STD_LOGIC_VECTOR(31 downto 0);
        im_addr_mux_dbg : out std_logic_vector(15 downto 0);
        cm_addr_mux_dbg : out std_logic_vector(15 downto 0);
        chunk_counter_dbg : out std_logic_vector(9 downto 0);
        feature_index_dbg : out std_logic_vector(4 downto 0);
        level_index_dbg   : out std_logic_vector(7 downto 0);
        chunk_counter_internal_dbg : out std_logic_vector(2 downto 0);
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
end HDC_Controller;


architecture Behavioral of HDC_Controller is

    -- Rotate a vector to the right by 'shift' positions
    function rotate_right(signal in_vec : STD_LOGIC_VECTOR; shift : integer) return STD_LOGIC_VECTOR is
        variable result : STD_LOGIC_VECTOR(in_vec'range);
    begin
        for i in 0 to in_vec'length-1 loop
            result(i) := in_vec((i + shift) mod in_vec'length);
        end loop;
        return result;
    end function;

    -- Lookup table for 4-bit popcount (counting '1's in a nibble)
    type popcount_array_t is array (0 to 15) of std_logic_vector(3 downto 0);
    constant popcount_lut : popcount_array_t := (
        "0000", "0001", "0001", "0010",
        "0001", "0010", "0010", "0011",
        "0001", "0010", "0010", "0011",
        "0010", "0011", "0011", "0100"
    );

    -- Convert 4-bit vector to integer number of set bits using LUT
    function popcount4(v : std_logic_vector(3 downto 0)) return integer is
    begin
        return to_integer(unsigned(popcount_lut(to_integer(unsigned(v)))));
    end function;

    -- === Segmentation Constants ===
    constant SEG_WIDTH          : integer := 256;
    constant WORD_WIDTH         : integer := 32;
    constant CHUNKS_PER_VEC     : integer := (D + WORD_WIDTH - 1) / WORD_WIDTH;
    constant NUM_FULL_SEGMENTS  : integer := D / SEG_WIDTH;
    constant REMAINDER_BITS     : integer := D mod SEG_WIDTH;
    constant NUM_SEGMENTS       : integer := NUM_FULL_SEGMENTS + ((REMAINDER_BITS + SEG_WIDTH - 1) / SEG_WIDTH);
    constant BLOCK_WIDTH        : integer := 4;
    constant BLOCKS_PER_SEG     : integer := SEG_WIDTH / BLOCK_WIDTH;

    -- === RAM arrays for accumulation and buffer ===
    type bram_array_t is array (0 to CHUNKS_PER_VEC-1) of std_logic_vector(WORD_WIDTH-1 downto 0);
    signal bundled_result_acc_ram : bram_array_t := (others => (others => '0'));
    signal am_buffer_ram : bram_array_t := (others => (others => '0'));

    -- Force BRAM usage in synthesis
    attribute ram_style : string;
    attribute ram_style of bundled_result_acc_ram : signal is "block";
    attribute ram_style of am_buffer_ram         : signal is "block";

    -- === Feature loading and encoding control ===
    signal feature_load_index : integer range 0 to N := 0;
    signal features_ready     : STD_LOGIC := '0';
    signal feature_values_packed : STD_LOGIC_VECTOR(N*16-1 downto 0);

    -- === Bundled result and control ===
    signal bundled_result     : STD_LOGIC_VECTOR(D-1 downto 0) := (others => '0');
    signal chunk_counter      : unsigned(2 downto 0) := (others => '0');
    signal similarity_counter : unsigned(7 downto 0) := (others => '0');
    signal global_counter     : unsigned(7 downto 0) := (others => '0');
    signal memory_index       : unsigned(2 downto 0) := (others => '0');
    signal closest_memory_index : unsigned(2 downto 0) := (others => '0');
    signal final_accumulation : STD_LOGIC_VECTOR(D-1 downto 0) := (others => '0');
    signal done_encoding      : STD_LOGIC := '0';

    -- === FSM comparison logic ===
    signal compare_state    : integer range 0 to 8 := 0;
    signal segment_index    : integer range 0 to NUM_SEGMENTS-1 := 0;
    signal word_index       : integer range 0 to CHUNKS_PER_VEC-1 := 0;
    signal xor_result       : STD_LOGIC_VECTOR(SEG_WIDTH-1 downto 0);
    signal xor_chunk        : std_logic_vector(3 downto 0);
    signal partial_hamming  : unsigned(15 downto 0) := (others => '0');
    signal min_hamming_distance : unsigned(15 downto 0) := (others => '1');

    -- === Memory interface signals (split per RAM) ===
    signal im_we, cm_we, am_we : std_logic;
    signal im_addr, cm_addr, am_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal im_data_in, cm_data_in, am_data_in : std_logic_vector(31 downto 0);
    signal im_data_out, cm_data_out, am_data_out : std_logic_vector(31 downto 0);
    signal am_buffer : STD_LOGIC_VECTOR(D-1 downto 0) := (others => '0');

    -- === Popcount control ===
    signal popcount_step : integer range 0 to 63 := 0;

    -- === Address muxing for AM ===
    signal am_addr_internal : std_logic_vector(15 downto 0) := (others => '0');
    signal use_internal_am_addr : std_logic := '0';

    -- === Debug routing signals ===
    signal bundled_result_dbg_dummy : std_logic := '0';
    signal im_addr_mux_dbg_internal : std_logic_vector(15 downto 0);
    signal cm_addr_mux_dbg_internal : std_logic_vector(15 downto 0);

        -- === Submodule: Accelerator ===
    component Accelerator
        generic (
            D : integer := 10000;
            N : integer := 32;
            M : integer := 200
        );
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            feature_values : in STD_LOGIC_VECTOR(N*16-1 downto 0);
            start : in STD_LOGIC;
            load_mode : in STD_LOGIC;
            done : out STD_LOGIC;
            encoded_hv_ready : out STD_LOGIC;
            bundled_result : out STD_LOGIC_VECTOR(D-1 downto 0);

            -- Memory interfaces for IM and CM
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
            feature_index_dbg : out std_logic_vector(4 downto 0);
            level_index_dbg   : out std_logic_vector(7 downto 0);
            majority_chunk_dbg_0 : out std_logic_vector(31 downto 0);
            bound_chunk_dbg : out std_logic_vector(31 downto 0)
        );
    end component;

    -- === Submodule: Associative Memory ===
    component AssociativeMemory
        Port (
            clk      : in  STD_LOGIC;
            we       : in  STD_LOGIC;
            am_addr     : in  STD_LOGIC_VECTOR(15 downto 0);
            am_data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
            am_data_out : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

begin

    -- === Memory Write Enable Selection ===
    im_we <= mem_we when (mem_sel = "00" and load_mode = '1') else '0';
    cm_we <= mem_we when (mem_sel = "01" and load_mode = '1') else '0';
    am_we <= mem_we when mem_sel = "10" else '0';

    -- === Address Muxing ===
    im_addr <= mem_addr when mem_sel = "00" else (others => '0');
    cm_addr <= mem_addr when mem_sel = "01" else (others => '0');
    am_addr <= am_addr_internal when use_internal_am_addr = '1' else
               mem_addr when mem_sel = "10" else
               (others => '0');

    -- === Data Write Routing ===
    im_data_in <= mem_data_in;
    cm_data_in <= mem_data_in;
    am_data_in <= mem_data_in;

    -- === Data Read Muxing ===
    with mem_sel select
        mem_data_out <= im_data_out when "00",
                        cm_data_out when "01",
                        am_data_out when "10",
                        (others => '0') when others;

    -- === Debug Routing ===
    done_encoding_monitor <= done_encoding;
    bundled_result_ila_dbg <= bundled_result;
    chunk_counter_internal_dbg <= std_logic_vector(chunk_counter);
    memory_index_dbg <= memory_index;
    min_hamming_distance_dbg <= min_hamming_distance;
    compare_state_dbg <= std_logic_vector(to_unsigned(compare_state, compare_state_dbg'length));
    popcount_step_dbg <= std_logic_vector(to_unsigned(popcount_step, 3));
    segment_index_dbg <= std_logic_vector(to_unsigned(segment_index, segment_index_dbg'length));
    sim_counter_dbg <= std_logic_vector(similarity_counter);

    -- === Accelerator Instantiation ===
    accelerator_unit: Accelerator
        generic map ( D => D, N => N, M => M )
        port map (
            clk => clk,
            reset => reset,
            feature_values => feature_values_packed,
            start => start,
            load_mode => load_mode,
            done => done_encoding,
            encoded_hv_ready => open,
            bundled_result => bundled_result,
            im_we => im_we,
            im_addr => im_addr,
            im_data_in => im_data_in,
            cm_we => cm_we,
            cm_addr => cm_addr,
            cm_data_in => cm_data_in,
            im_data_out => im_data_out,
            cm_data_out => cm_data_out,
            state_slv_debug => accelerator_state_dbg,
            im_data_dbg => im_data_dbg,
            cm_data_dbg => cm_data_dbg,
            im_addr_mux_dbg => im_addr_mux_dbg_internal,
            cm_addr_mux_dbg => cm_addr_mux_dbg_internal,
            chunk_counter_dbg => chunk_counter_dbg,
            feature_index_dbg => feature_index_dbg,
            level_index_dbg   => level_index_dbg,
            majority_chunk_dbg_0 => majority_chunk_dbg_0,
            bound_chunk_dbg => bound_chunk_dbg   
        );

    -- === Associative Memory Instantiation ===
    associative_memory_unit: AssociativeMemory
        port map (
            clk => clk,
            we => am_we,
            am_addr => am_addr,
            am_data_in => am_data_in,
            am_data_out => am_data_out
        );


        process(clk, reset)
        variable pop : integer := 0;
        variable shifted_result_var : STD_LOGIC_VECTOR(D-1 downto 0);
        variable acc_last_word : std_logic_vector(31 downto 0);
        variable am_last_word  : std_logic_vector(31 downto 0);
        variable xor_partial   : std_logic_vector(REMAINDER_BITS-1 downto 0);
        variable acc_segment : std_logic_vector(SEG_WIDTH-1 downto 0);
        variable xor_temp : std_logic_vector(SEG_WIDTH - 1 downto 0);
    begin
        if reset = '1' then
            -- Reset all relevant control signals and memories
            feature_load_index <= 0;
            features_ready <= '0';
            for i in 0 to CHUNKS_PER_VEC-1 loop
                bundled_result_acc_ram(i) <= (others => '0');
            end loop;
            chunk_counter <= (others => '0');
            compare_state <= 0;
            memory_index <= (others => '0');
            similarity_counter <= (others => '0');
            closest_memory_index <= (others => '0');
            segment_index <= 0;
            partial_hamming <= (others => '0');
            min_hamming_distance <= (others => '1');
            done <= '0';
            word_index <= 0;
            use_internal_am_addr <= '0';  -- Reset AM address mux
        elsif rising_edge(clk) then

            -- === Feature Packing: Build 512-bit packed feature input for accelerator ===
            if feature_valid = '1' and features_ready = '0' then
                feature_values_packed((feature_load_index+1)*16-1 downto feature_load_index*16) <= feature_value;
                if feature_load_index = N-1 then
                    features_ready <= '1';
                    feature_values_packed_dbg <= feature_values_packed;
                    feature_load_index <= 0;
                else
                    feature_load_index <= feature_load_index + 1;
                end if;
            else
                features_ready <= '0';
            end if;

            -- === FSM ===
            case compare_state is
                when 0 =>
                    -- Wait for encoded hypervector
                    if done_encoding = '1' then

                        -- Optional debug pulse
                        if bundled_result(0) = '1' then
                            bundled_result_dbg_dummy <= not bundled_result_dbg_dummy;
                        end if;

                        -- Rotate bundled result by chunk_counter bits
                        shifted_result_var := rotate_right(bundled_result, to_integer(chunk_counter));

                        -- Accumulate rotated bundled result into RAM (XOR)
                        for i in 0 to CHUNKS_PER_VEC-1 loop
                            if i = CHUNKS_PER_VEC - 1 and D mod 32 /= 0 then
                                -- Last partial word (e.g. D = 10000 → last 16 bits)
                                bundled_result_acc_ram(i)(D mod 32 - 1 downto 0) <=
                                    bundled_result_acc_ram(i)(D mod 32 - 1 downto 0) xor
                                    shifted_result_var(D mod 32 - 1 downto 0);
                            else
                                -- Full 32-bit blocks
                                bundled_result_acc_ram(i) <=
                                    bundled_result_acc_ram(i) xor
                                    shifted_result_var(D-1 - i*32 downto D - (i+1)*32);
                            end if;
                        end loop;

                        -- Next chunk
                        chunk_counter <= chunk_counter + 1;

                        -- After 5 chunks (0-4): start comparison
                        if chunk_counter = to_unsigned(4, chunk_counter'length) then
                            global_counter <= global_counter + 1;
                            compare_state <= 1;
                            memory_index <= (others => '0');
                            chunk_counter <= (others => '0');
                            word_index <= 0;
                            am_buffer <= (others => '0');
                        end if;
                    end if;


                when 1 =>
                    -- Set AM address to read word from class `memory_index`
                    -- Word index selects the current 32-bit block
                    am_addr_internal <= std_logic_vector(to_unsigned(to_integer(memory_index) * CHUNKS_PER_VEC + word_index, 16));
                    use_internal_am_addr <= '1';
                    compare_state <= 2;

                when 2 =>
                    -- Wait one cycle for AM read
                    compare_state <= 3;

                when 3 =>
                    -- Write AM word into buffer
                    if word_index = CHUNKS_PER_VEC - 1 then
                        -- Final word may only contain partial bits (e.g., 16 bits if D=10000)
                        am_buffer_ram(word_index)(15 downto 0) <= am_data_out(31 downto 16);

                        -- Reset for next phase
                        word_index <= 0;
                        segment_index <= 0;
                        partial_hamming <= (others => '0');
                        compare_state <= 4;
                    else
                        -- Store full 32-bit word in AM buffer
                        am_buffer_ram(word_index) <= am_data_out;

                        -- Next word
                        word_index <= word_index + 1;
                        compare_state <= 1;
                    end if;

                              when 4 =>
                    -- === Segment Reconstruction ===
                    if segment_index = NUM_SEGMENTS - 1 then
                        -- Last segment may be incomplete (REMAINDER_BITS < SEG_WIDTH)
                        acc_segment := (others => '0');
                        xor_temp    := (others => '0');
                        acc_segment(REMAINDER_BITS - 1 downto 0) :=
                            bundled_result_acc_ram(0)(REMAINDER_BITS - 1 downto 0);
                        xor_temp(REMAINDER_BITS - 1 downto 0) :=
                            am_buffer_ram(0)(REMAINDER_BITS - 1 downto 0);
                    else
                        -- Full 256-bit segment from RAM (8 × 32-bit blocks, reversed)
                        for i in 0 to SEG_WIDTH / WORD_WIDTH - 1 loop
                            acc_segment((i+1)*WORD_WIDTH - 1 downto i*WORD_WIDTH) :=
                                bundled_result_acc_ram(CHUNKS_PER_VEC - 1 - (segment_index * 8 + i));
                            xor_temp((i+1)*WORD_WIDTH - 1 downto i*WORD_WIDTH) :=
                                am_buffer_ram(CHUNKS_PER_VEC - 1 - (segment_index * 8 + i));
                        end loop;
                    end if;

                    -- Compute XOR between accumulator and AM buffer
                    xor_result <= acc_segment xor xor_temp;

                    -- Reset popcount step
                    popcount_step <= 0;
                    compare_state <= 8;

                when 8 =>
                    -- === Popcount on 4-bit chunks ===
                    xor_chunk <= xor_result((popcount_step+1)*4 - 1 downto popcount_step*4);
                    partial_hamming <= partial_hamming + to_unsigned(popcount4(xor_chunk), partial_hamming'length);

                    if popcount_step = BLOCKS_PER_SEG - 1 then
                        popcount_step <= 0;

                        if segment_index = NUM_SEGMENTS - 1 then
                            -- Done with all segments
                            compare_state <= 5;
                        else
                            -- Go to next segment
                            segment_index <= segment_index + 1;
                            compare_state <= 4;
                        end if;
                    else
                        popcount_step <= popcount_step + 1;
                    end if;


                                when 5 =>
                    -- === Compare Hamming Distance to Min ===
                    if partial_hamming < min_hamming_distance then
                        min_hamming_distance <= partial_hamming;
                        closest_memory_index <= memory_index;
                    end if;
                    compare_state <= 6;

                when 6 =>
                    -- === Check if all memory classes compared ===
                    if memory_index = to_unsigned(4, 3) then
                        -- All classes checked → evaluate result
                        if closest_memory_index = unsigned(expected_class_index) then
                            similarity_counter <= similarity_counter + 1;
                        end if;
                        compare_state <= 7;
                    else
                        -- Next memory index
                        memory_index <= memory_index + 1;
                        word_index <= 0;
                        compare_state <= 1;
                    end if;

                when 7 =>
                    -- === Sample Done: Output Result and Reset ===
                    similarity_counter_out <= std_logic_vector(similarity_counter);
                    done <= '1';

                    -- Reset accumulator RAM
                    for i in 0 to CHUNKS_PER_VEC-1 loop
                        bundled_result_acc_ram(i) <= (others => '0');
                    end loop;

                    -- Reset state for next input
                    compare_state <= 0;
                    min_hamming_distance <= (others => '1');
            end case;
        end if;
    end process;

end Behavioral;