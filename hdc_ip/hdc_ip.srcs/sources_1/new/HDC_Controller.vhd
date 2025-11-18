library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================
-- Entity: HDC_Controller
-- ============================================================
-- This is the top-level controller module for the Hyperdimensional
-- Computing (HDC) system. It controls the encoding of features into 
-- hypervectors, accumulation into bundled results, comparison against 
-- associative memory, and thresholding for training/testing phases.
--
-- Generics:
--   D : Hypervector dimension (default 10,000 bits).
--   N : Number of features per input sample (default 32).
--   M : Number of levels (continuous memory granularity, default 40).
--
-- Ports:
--   clk, reset   : Standard clock and asynchronous reset.
--   start        : Start signal for encoding.
--   done         : Global done flag (e.g., training/test cycle finished).
--   feature_value: 16-bit input feature value.
--   feature_valid: Indicates when feature_value is valid.
--   similarity_counter_out : Counts successful classifications (10-bit).
--   signal_counter_out     : Global signal counter (32-bit).
--   closest_memory_index_out: Index of the closest associative memory entry.
--   mem_sel, mem_we, mem_addr, mem_data_in/out: 
--       Unified external memory interface (IM/CM/AM selectable).
--   internal_done           : Asserted when internal training step finishes.
--   done_encoding_monitor   : Monitor flag for completed feature encoding.
--   expected_class_index    : Class index expected (used for supervised training).
--   load_mode               : Switch between memory load and compute mode.
--
entity HDC_Controller is
    generic (
        D : integer := 10000;
        N : integer := 32;
        M : integer := 40
    );
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        start : in STD_LOGIC;
        done : out STD_LOGIC;
        feature_value : in STD_LOGIC_VECTOR(31 downto 0);
        feature_valid : in STD_LOGIC;
        similarity_counter_out : out STD_LOGIC_VECTOR(9 downto 0);
        signal_counter_out : out STD_LOGIC_VECTOR(31 downto 0);
        closest_memory_index_out : out std_logic_vector(2 downto 0);
        mem_sel      : in  STD_LOGIC_VECTOR(1 downto 0); -- "00"=IM, "01"=CM, "10"=AM
        mem_we       : in  STD_LOGIC;
        mem_addr     : in  STD_LOGIC_VECTOR(15 downto 0);
        mem_data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
        mem_data_out : out STD_LOGIC_VECTOR(31 downto 0);
        internal_done: out STD_LOGIC;
        done_encoding_monitor : out STD_LOGIC;
        expected_class_index : in STD_LOGIC_VECTOR(2 downto 0);
        load_mode : in STD_LOGIC
    );
end HDC_Controller;


architecture Behavioral of HDC_Controller is

    -- ============================================================
    -- Helper Function: rotate_right
    -- ============================================================
    -- Performs a circular right rotation of a std_logic_vector.
    -- Used to shift hypervectors depending on feature index.
    --
    function rotate_right(signal in_vec : STD_LOGIC_VECTOR; shift : integer) 
        return STD_LOGIC_VECTOR is
        variable result : STD_LOGIC_VECTOR(in_vec'range);
    begin
        for i in 0 to in_vec'length-1 loop
            result(i) := in_vec((i - shift + in_vec'length) mod in_vec'length);
        end loop;
        return result;
    end function;

    -- ============================================================
    -- Popcount LUT for 4-bit input
    -- ============================================================
    -- A small lookup table (LUT) that gives the number of '1's
    -- in a 4-bit input vector. Used for fast population count 
    -- when computing Hamming distances.
    --
    type popcount_array_t is array (0 to 15) of std_logic_vector(3 downto 0);
    constant popcount_lut : popcount_array_t := (
        "0000", -- 0: 0000 → 0 ones
        "0001", -- 1: 0001 → 1
        "0001", -- 2: 0010 → 1
        "0010", -- 3: 0011 → 2
        "0001", -- 4: 0100 → 1
        "0010", -- 5: 0101 → 2
        "0010", -- 6: 0110 → 2
        "0011", -- 7: 0111 → 3
        "0001", -- 8: 1000 → 1
        "0010", -- 9: 1001 → 2
        "0010", --10: 1010 → 2
        "0011", --11: 1011 → 3
        "0010", --12: 1100 → 2
        "0011", --13: 1101 → 3
        "0011", --14: 1110 → 3
        "0100"  --15: 1111 → 4
    );

    -- Wrapper function: converts LUT output to integer
    function popcount4(v : std_logic_vector(3 downto 0)) return integer is
    begin
        return to_integer(unsigned(popcount_lut(to_integer(unsigned(v)))));
    end function;

    -- ============================================================
    -- Constants for segmentation
    -- ============================================================
    -- Hypervectors are processed in blocks to save resources.
    --
    constant SEG_WIDTH : integer := 256;                       -- Segment width in bits
    constant WORD_WIDTH : integer := 32;                       -- Word width in bits
    constant CHUNKS_PER_VEC : integer := (D + WORD_WIDTH - 1) / WORD_WIDTH;
        -- Number of 32-bit words needed for one hypervector
    constant NUM_FULL_SEGMENTS : integer := D / SEG_WIDTH;     
        -- Number of full 256-bit segments
    constant REMAINDER_BITS    : integer := D mod SEG_WIDTH;   
        -- Remaining bits in last segment
    constant NUM_SEGMENTS : integer := NUM_FULL_SEGMENTS + 
              ( (REMAINDER_BITS + SEG_WIDTH - 1) / SEG_WIDTH );
        -- Total number of segments (full + remainder)
    constant BLOCK_WIDTH : integer := 4;                       
        -- Width of popcount processing block
    constant BLOCKS_PER_SEG : integer := SEG_WIDTH / BLOCK_WIDTH; 
        -- Number of 4-bit blocks per segment

    -- ============================================================
    -- Training/Test control values
    -- ============================================================
    signal DIVIDER      : integer := 173; -- Training sample count per class
    signal TESTDIVIDER  : integer := 34;  -- Test sample count per class
    signal TRAINDIVIDER : integer := 173; -- Alias for training divider
    signal threshold_val : integer := DIVIDER / 2; 
        -- Majority threshold for training
    type confusion_matrix_t is array (0 to 4, 0 to 4) of unsigned(9 downto 0);
    signal confusion_matrix : confusion_matrix_t := (others => (others => (others => '0')));
    signal true_class_index : integer range 0 to 4 := 0;

    -- ============================================================
    -- Internal memory arrays (RAM-based)
    -- ============================================================
    -- BRAM-style arrays used to store intermediate hypervectors
    --
    type bram_array_t is array (0 to CHUNKS_PER_VEC-1) of std_logic_vector(WORD_WIDTH-1 downto 0);
    
    signal bundled_result_acc_ram : bram_array_t := (others => (others => '0'));
        -- Accumulator for bundled hypervectors (XORed results)
    signal am_buffer_ram : bram_array_t := (others => (others => '0'));
        -- Buffer for associative memory hypervectors

    -- Force Block RAM inference in synthesis
    attribute ram_style : string;
    attribute ram_style of am_buffer_ram           : signal is "block";
    attribute ram_style of bundled_result_acc_ram  : signal is "block";
    -- ============================================================
    -- Control and data signals
    -- ============================================================

    -- Feature input handling
    signal feature_load_index : integer range 0 to N := 0;
        -- Index of the current feature being loaded (0..N-1)
    signal features_ready : STD_LOGIC := '0';
        -- Raised when all N features have been loaded into the buffer
    signal feature_values_packed : STD_LOGIC_VECTOR(N*32-1 downto 0);
        -- Concatenated feature vector (N × 16 bits)

    -- Bundled hypervector accumulation
    signal bundled_result : STD_LOGIC_VECTOR(D-1 downto 0) := (others => '0');
        -- Encoded hypervector result from Accelerator
    signal similarity_counter : unsigned(9 downto 0) := (others => '0');
        -- Counts how often classification matches the expected class
    signal global_counter : unsigned(9 downto 0) := (others => '0');
        -- Counts the number of encoded samples processed
    signal memory_index : unsigned(2 downto 0) := (others => '0');
        -- Current class index during associative memory comparison
    signal closest_memory_index : unsigned(2 downto 0) := (others => '0');
        -- Stores the closest class index (minimum Hamming distance)
    signal final_accumulation : STD_LOGIC_VECTOR(D-1 downto 0) := (others => '0');
        -- Final accumulated bundled result (not always used directly)
    signal done_encoding : STD_LOGIC := '0';
        -- Flag raised when Accelerator finishes encoding one sample

    -- FSM state registers
    signal compare_state : integer range 0 to 10 := 0;
        -- State machine for comparison and training
    signal segment_index : integer range 0 to NUM_SEGMENTS-1 := 0;
        -- Index of current 256-bit segment during Hamming distance calculation
    signal word_index : integer range 0 to CHUNKS_PER_VEC-1 := 0;
        -- Index of current 32-bit word when reading/writing memory

    -- Intermediate XOR and popcount signals
    signal xor_result : STD_LOGIC_VECTOR(SEG_WIDTH-1 downto 0);
        -- Result of XOR between bundled_result and AM hypervector
    signal xor_chunk : std_logic_vector(3 downto 0);
        -- 4-bit block extracted from xor_result for popcount
    signal popcount_step : integer range 0 to 63 := 0;
        -- Step index inside one segment (counts 4-bit groups)

    -- Unified memory interface control (IM, CM, AM)
    signal im_we, cm_we, am_we : std_logic;
        -- Write enables for Identity, Continuous, and Associative Memories
    signal im_addr, cm_addr, am_addr : std_logic_vector(15 downto 0):= (others => '0');
        -- Memory addresses for IM, CM, and AM
    signal im_data_in, cm_data_in, am_data_in : std_logic_vector(31 downto 0);
        -- Write data input to IM, CM, AM
    signal im_data_out, cm_data_out, am_data_out : std_logic_vector(31 downto 0);
        -- Read data output from IM, CM, AM

    -- AM buffer signals
    signal am_buffer : STD_LOGIC_VECTOR(D-1 downto 0) := (others => '0');
        -- Associative memory vector buffer (full hypervector)
    signal am_addr_internal : std_logic_vector(15 downto 0):= (others => '0');
        -- Internal address when controller directly drives AM
    signal use_internal_am_addr : std_logic := '0';
        -- Selects between external address or internal FSM address

    -- Debug and monitoring signals
    signal bundled_result_dbg_dummy : std_logic := '0'; -- placeholder/debug
    signal im_addr_mux_dbg_internal : std_logic_vector(15 downto 0);
    signal cm_addr_mux_dbg_internal : std_logic_vector(15 downto 0);

    -- Majority class tracking
    signal MAJ_CLASS_IDX : integer := 4;
        -- Index of the class currently being trained (counting down)
    signal am_we_internal        : std_logic := '0';
        -- Internal write-enable for AM during thresholding
    signal am_data_in_internal   : std_logic_vector(31 downto 0) := (others => '0');
        -- Internal write data for AM during thresholding
    signal am_we_mux             : std_logic;
        -- Final write-enable selection (external vs internal)
    signal am_data_in_mux        : std_logic_vector(31 downto 0);
        -- Final write-data selection (external vs internal)
    signal am_write_active       : std_logic := '0';
        -- Indicates AM write is in progress
    signal am_write_word_idx     : integer range 0 to CHUNKS_PER_VEC-1 := 0;
        -- Current word index during AM write
    signal am_addr_fsm   : std_logic_vector(15 downto 0);
        -- FSM-controlled AM address
    signal am_addr_write : std_logic_vector(15 downto 0);
        -- Address for AM write during thresholding

    -- Majority accumulation (before thresholding)
    type bundle_cnt_array is array (0 to D-1) of integer;
    signal trained_majority: bundle_cnt_array := (others => 0);
        -- Stores integer counters for each bit during training
    signal majority_write_req    : std_logic := '0';
        -- Triggers when a majority vector is ready to be written

    -- Majority FSM addressing
    signal maj_addr      : unsigned(13 downto 0) := (others => '0');
    signal maj_bit_word  : std_logic_vector(31 downto 0) := (others => '0');
    signal maj_word_idx  : integer range 0 to CHUNKS_PER_VEC-1 := 0;
    signal maj_bit_pos   : integer range 0 to 31 := 0;
    signal maj_active    : std_logic := '0';

    -- Counter RAM interface (used for bit-level majority)
    signal cnt_dout      : unsigned(9 downto 0);
        -- Counter RAM read data (bit counter value)
    signal cnt_din       : unsigned(9 downto 0);
        -- Counter RAM write data
    signal cnt_we        : std_logic := '0';
        -- Counter RAM write-enable

    -- Thresholding control
    signal thresholding : std_logic := '0';
        -- Flag indicates thresholding (majority finalization) is active
    signal thr_valid    : std_logic := '0';
        -- Pipeline flag: counter RAM output is valid
    signal thr_idx      : unsigned(13 downto 0) := (others => '0');
        -- Thresholding index (current bit index)
    signal thr_step     : integer range 0 to 3 := 0;
        -- Sub-state in thresholding FSM
    signal thr_total    : integer range 0 to D := 0;
        -- Total processed bits during thresholding
    signal word_idx_thr : integer range 0 to CHUNKS_PER_VEC-1 := 0;
        -- Current AM word index being written
    signal pack_reg           : std_logic_vector(31 downto 0) := (others => '0');
        -- Register for packing thresholded bits into 32-bit words
    signal pack_fill_count    : integer range 0 to 32 := 0;
        -- Counter: how many bits have been packed into current word
    signal bits_needed_in_word: integer range 0 to 32 := 32;
        -- Required bits in current word (last word may be <32)
    signal am_waddr_base      : integer := 0;
        -- Base AM address for current class
    signal am_waddr_cur       : integer range 0 to 65535 := 0;
        -- Current AM write address (base + word index)

    -- Majority FSM addressing (read/write separation)
    signal maj_addr_prev : unsigned(13 downto 0) := (others => '0');
    signal chunk_idx     : integer range 0 to CHUNKS_PER_VEC := 0;
        -- Current chunk index during majority accumulation
    signal bit_idx       : integer range 0 to WORD_WIDTH := 0;
        -- Current bit index within a word
    signal maj_state_step : integer range 0 to 2 := 0;
        -- Sub-state of majority FSM (0=READ, 1=WAIT, 2=WRITE)
    signal maj_addr_rd    : unsigned(13 downto 0) := (others => '0');
        -- Read address for counter RAM
    signal maj_addr_wr    : unsigned(13 downto 0) := (others => '0');
        -- Write address for counter RAM

    -- Counter RAM clearing after thresholding
    signal cnt_clear_index : unsigned(13 downto 0) := (others => '0');
        -- Counter RAM clear index (reset for next training cycle)
    signal clearing_cnt_ram : std_logic := '0';
        -- Indicates counter RAM is being cleared
    signal cnt_dout_prev : unsigned(9 downto 0);
        -- Previous counter RAM output (pipeline)

    -- Debug / test counters
    signal test_cnt      : std_logic_vector(12 downto 0);
    signal signal_counter : unsigned(31 downto 0) := (others => '0');
        -- Global signal counter (monitors processed hypervectors)
    -- ============================================================
    -- Component Declarations
    -- ============================================================

    -- Accelerator
    -- ------------------------------------------------------------
    -- Encodes feature values into a hypervector using IdentityMemory (IM)
    -- and ContinuousMemory (CM). Outputs the bundled hypervector.
    --
    component Accelerator
        generic (
            D : integer := 10000; -- Hypervector dimension
            N : integer := 32;    -- Number of features
            M : integer := 40     -- Number of continuous levels
        );
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            feature_values : in STD_LOGIC_VECTOR(N*32-1 downto 0);
                -- Concatenated feature input values
            start : in STD_LOGIC;
                -- Start encoding
            load_mode : in STD_LOGIC;
                -- If '1' → load memory values instead of computing
            done : out STD_LOGIC;
                -- Encoding finished
            encoded_hv_ready : out STD_LOGIC;
                -- Indicates hypervector ready (not used here)
            bundled_result : out STD_LOGIC_VECTOR(D-1 downto 0);
                -- Encoded hypervector output
            -- Memory interface for Identity Memory (IM)
            im_we : in STD_LOGIC;
            im_addr : in STD_LOGIC_VECTOR(15 downto 0);
            im_data_in : in STD_LOGIC_VECTOR(31 downto 0);
            -- Memory interface for Continuous Memory (CM)
            cm_we : in STD_LOGIC;
            cm_addr : in STD_LOGIC_VECTOR(15 downto 0);
            cm_data_in : in STD_LOGIC_VECTOR(31 downto 0);
            -- Data outputs from IM/CM
            im_data_out : out STD_LOGIC_VECTOR(31 downto 0);
            cm_data_out : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    -- Associative Memory
    -- ------------------------------------------------------------
    -- Stores class hypervectors. During training, thresholded 
    -- bundled results are written into AM. During classification,
    -- vectors are read out for comparison.
    --
    component AssociativeMemory
        Port (
            clk      : in  STD_LOGIC;
            we       : in  STD_LOGIC;
            am_addr     : in  STD_LOGIC_VECTOR(15 downto 0);
            am_data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
            am_data_out : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    -- Counter RAM
    -- ------------------------------------------------------------
    -- Stores per-bit counters during training. Each bit position 
    -- (0..D-1) has a counter that is incremented every time a '1'
    -- is encountered in the bundled_result. Later, thresholding
    -- determines the final majority hypervector for each class.
    --
    component counter_ram
        generic (
            DEPTH      : integer := 10000; -- Number of counters = D
            ADDR_WIDTH : integer := 14     -- Address width (log2(D))
        );
        port (
            clk    : in  std_logic;
            -- Port A: Read
            addr_a : in  unsigned(ADDR_WIDTH-1 downto 0);
            dout_a : out unsigned(9 downto 0); -- Counter value
            -- Port B: Write
            addr_b : in  unsigned(ADDR_WIDTH-1 downto 0);
            din_b  : in  unsigned(9 downto 0);
            we_b   : in  std_logic
        );
    end component;

begin

    -- ============================================================
    -- Memory Demultiplexer (unified interface to IM, CM, AM)
    -- ============================================================
    -- Depending on mem_sel, external accesses are routed to 
    -- IdentityMemory (IM), ContinuousMemory (CM), or AssociativeMemory (AM).
    -- During training thresholding, internal FSM overrides AM signals.
    --

    -- Write-enable routing
    im_we <= mem_we when (mem_sel = "00" and load_mode = '1') else '0';
    cm_we <= mem_we when (mem_sel = "01" and load_mode = '1') else '0';
    am_we_mux <= am_we when use_internal_am_addr = '0' else am_we_internal;
        -- AM write enable can come from external load mode or internal FSM

    -- Address routing
    im_addr <= mem_addr when mem_sel = "00" else (others => '0');
    cm_addr <= mem_addr when mem_sel = "01" else (others => '0');
    am_addr <= am_addr_internal when use_internal_am_addr = '1' else
               mem_addr         when mem_sel = "10" else
               (others => '0');
        -- If FSM controls AM (thresholding), use am_addr_internal

    -- Data-in routing
    im_data_in <= mem_data_in;
    cm_data_in <= mem_data_in;
    am_data_in_mux <= mem_data_in when use_internal_am_addr = '0' 
                      else am_data_in_internal;

    -- Data-out multiplexing
    with mem_sel select
        mem_data_out <= im_data_out when "00",
                        cm_data_out when "01",
                        am_data_out when "10",
                        (others => '0') when others;

    -- AM address muxing
    am_addr_internal <= am_addr_write when am_write_active = '1'
                        else am_addr_fsm;

    -- Debug monitor signal
    done_encoding_monitor <= done_encoding;

    -- ============================================================
    -- Accelerator Instance
    -- ============================================================
    accelerator_unit: Accelerator
        generic map (
            D => D, 
            N => N, 
            M => M
        )
        port map (
            clk => clk,
            reset => reset,
            feature_values => feature_values_packed,
            start => start,
            load_mode => load_mode,
            done => done_encoding,
            encoded_hv_ready => open, -- not used here
            bundled_result => bundled_result,
            im_we => im_we,
            im_addr => im_addr,
            im_data_in => im_data_in,
            cm_we => cm_we,
            cm_addr => cm_addr,
            cm_data_in => cm_data_in,
            im_data_out => im_data_out,
            cm_data_out => cm_data_out 
        );

    -- ============================================================
    -- Associative Memory Instance
    -- ============================================================
    associative_memory_unit: AssociativeMemory
        port map (
            clk => clk,
            we => am_we_mux,
            am_addr => am_addr,
            am_data_in => am_data_in_mux,
            am_data_out => am_data_out
        );

    -- ============================================================
    -- Counter RAM Instance
    -- ============================================================
    counter_ram_inst: entity work.counter_ram
        generic map (
            DEPTH => D,        -- total counters = dimension size
            ADDR_WIDTH => 14   -- log2(10000) ≈ 14
        )
        port map (
            clk    => clk,
            -- Read port
            addr_a => maj_addr_rd,
            dout_a => cnt_dout,
            -- Write port
            addr_b => maj_addr_wr,
            din_b  => cnt_din,
            we_b   => cnt_we
        );
    -- ============================================================
    -- Main FSM Process
    -- ============================================================
    -- Controls feature loading, encoding, accumulation,
    -- Hamming distance comparison, majority accumulation, and thresholding.
    --
    process(clk, reset)
        -- Local variables (used inside the FSM only)
        variable pop : integer := 0;  -- temporary popcount result
        variable shifted_result_var : STD_LOGIC_VECTOR(D-1 downto 0);
            -- stores rotated bundled result
        variable acc_last_word : std_logic_vector(31 downto 0);
        variable am_last_word  : std_logic_vector(31 downto 0);
        variable xor_partial   : std_logic_vector(REMAINDER_BITS-1 downto 0);
        variable acc_segment   : std_logic_vector(SEG_WIDTH-1 downto 0);
        variable xor_temp      : std_logic_vector(SEG_WIDTH - 1 downto 0);
        variable lin_idx_int   : integer; -- linear index for counters
        variable chunk_counter : unsigned(3 downto 0) := (others => '0');
            -- rotates bundled results (used in encoding)
        variable partial_hamming : unsigned(15 downto 0) := (others => '0');
            -- stores current Hamming distance sum
        variable min_hamming_distance : unsigned(15 downto 0) := (others => '1');
            -- minimum Hamming distance found
    begin
        -- ========================================================
        -- Reset behavior
        -- ========================================================
        if reset = '1' then
            feature_load_index <= 0;
            features_ready <= '0';
            -- Clear accumulator RAM
            for i in 0 to CHUNKS_PER_VEC-1 loop
                bundled_result_acc_ram(i) <= (others => '0');
            end loop;
            chunk_counter := (others => '0');
            compare_state <= 0;
            memory_index <= (others => '0');
            similarity_counter <= (others => '0');
            closest_memory_index <= (others => '0');
            segment_index <= 0;
            partial_hamming := (others => '0');
            min_hamming_distance := (others => '1');
            done <= '0';
            word_index <= 0;
            use_internal_am_addr <= '0'; -- reset AM mux to external
        -- ========================================================
        -- Clocked behavior
        -- ========================================================
        elsif rising_edge(clk) then

            -- ----------------------------------------------------
            -- Feature loading (state-independent)
            -- ----------------------------------------------------
            if (compare_state = 0) and feature_valid = '1' and features_ready = '0' then
                -- Pack feature_value into feature_values_packed
                feature_values_packed((feature_load_index+1)*32-1 downto feature_load_index*32) 
                    <= feature_value;

                if feature_load_index = N-1 then
                    -- All N features loaded
                    features_ready <= '1';
                    feature_load_index <= 0;
                else
                    feature_load_index <= feature_load_index + 1;
                end if;
            else
                features_ready <= '0';
            end if;

            -- Default: reset majority write request each cycle
            majority_write_req <= '0';

            -- If AM write FSM is active, force AM to internal address/data
            if am_write_active = '1' then
                use_internal_am_addr <= '1';
            end if;

            -- ====================================================
            -- FSM States
            -- ====================================================
            case compare_state is

                -- ------------------------------------------------
                -- STATE 0: Wait for encoding done
                -- ------------------------------------------------
                when 0 =>
                    if done_encoding = '1' then
                        -- Rotate bundled_result according to chunk_counter
                        shifted_result_var := rotate_right(bundled_result, to_integer(chunk_counter));

                        -- XOR accumulate into bundled_result_acc_ram
                        for i in 0 to CHUNKS_PER_VEC-1 loop
                            if i = CHUNKS_PER_VEC - 1 and D mod 32 /= 0 then
                                -- Last word may not be full (e.g., 10000 mod 32 = 16 bits valid)
                                bundled_result_acc_ram(i)(D mod 32 - 1 downto 0) <=
                                    bundled_result_acc_ram(i)(D mod 32 - 1 downto 0) xor
                                    shifted_result_var(D mod 32 - 1 downto 0);
                            else
                                -- Normal full 32-bit word
                                bundled_result_acc_ram(i) <=
                                    bundled_result_acc_ram(i) xor
                                    shifted_result_var(D-1 - i*32 downto D - (i+1)*32);
                            end if;
                        end loop;

                        -- Count processed signals
                        signal_counter <= signal_counter + 1;
                        chunk_counter := chunk_counter + 1;

                        -- After 5 rotations → move to comparison
                        if chunk_counter = 5 then
                            global_counter <= global_counter + 1;
                            memory_index <= (others => '0');
                            chunk_counter := (others => '0');
                            word_index <= 0;
                            am_buffer <= (others => '0');

                            -- If in training phase → jump to majority state
                            if MAJ_CLASS_IDX >= 0 then
                                compare_state <= 7;
                            else
                                -- Else go to normal AM comparison
                                compare_state <= 1;
                            end if;
                        end if;
                    end if;
                -- ------------------------------------------------
                -- STATE 1: Prepare AM read (set address)
                -- ------------------------------------------------
                -- Build AM address = (class_index * words_per_vector) + word_index
                -- and switch AM to internal addressing for the FSM.
                when 1 =>
                    am_addr_fsm <= std_logic_vector(
                        to_unsigned(to_integer(memory_index) * CHUNKS_PER_VEC + word_index, 16)
                    );
                    use_internal_am_addr <= '1';   -- drive AM from FSM
                    compare_state <= 2;            -- -> one-cycle BRAM latency

                -- ------------------------------------------------
                -- STATE 2: Wait for BRAM read latency
                -- ------------------------------------------------
                when 2 =>
                    compare_state <= 3;            -- data valid next cycle

                -- ------------------------------------------------
                -- STATE 3: Buffer AM word (reverse order, last-word special)
                -- ------------------------------------------------
                -- We store the AM vector word-by-word into am_buffer_ram.
                -- The final 32-bit word only contains the upper 16 valid bits (for D=10000).
                when 3 =>
                    if word_index = CHUNKS_PER_VEC - 1 then
                        -- Last 32-bit word: only the upper 16 bits are valid for D mod 32 = 16.
                        am_buffer_ram(word_index)(15 downto 0) <= am_data_out(31 downto 16);

                        -- Done reading one full class vector
                        word_index      <= 0;
                        segment_index   <= 0;
                        partial_hamming := (others => '0');
                        compare_state   <= 4;       -- move to XOR/segment handling
                    else
                        -- Regular words: store as-is. Note: words are stored "backwards" later
                        -- when reconstructing 256-bit segments for XOR/popcount.
                        am_buffer_ram(word_index) <= am_data_out;

                        -- Continue reading next word of the same class vector
                        word_index    <= word_index + 1;
                        compare_state <= 1;         -- request next address
                    end if;

                -- ------------------------------------------------
                -- STATE 4: Assemble 256-bit segment and compute XOR
                -- ------------------------------------------------
                -- Reconstruct a 256-bit segment for both:
                --   - bundled_result_acc_ram (accumulated encoded vector)
                --   - am_buffer_ram         (class hypervector from AM)
                -- Then compute XOR of both segments to prepare popcount.
                when 4 =>
                    if segment_index = NUM_SEGMENTS - 1 then
                        -- Last (partial) segment with only REMAINDER_BITS valid (e.g. 16)
                        acc_segment := (others => '0');
                        xor_temp    := (others => '0');

                        acc_segment(REMAINDER_BITS - 1 downto 0) :=
                            bundled_result_acc_ram(0)(REMAINDER_BITS - 1 downto 0);
                        xor_temp(REMAINDER_BITS - 1 downto 0) :=
                            am_buffer_ram(0)(REMAINDER_BITS - 1 downto 0);
                    else
                        -- Full 256-bit segment = 8 × 32-bit words.
                        -- Words are taken "backwards" so that bit order matches the original D-1..0 mapping.
                        for i in 0 to (SEG_WIDTH / WORD_WIDTH) - 1 loop  -- i = 0..7
                            acc_segment((i+1)*WORD_WIDTH - 1 downto i*WORD_WIDTH) :=
                                bundled_result_acc_ram(CHUNKS_PER_VEC - 1 - (segment_index * 8 + i));
                            xor_temp((i+1)*WORD_WIDTH - 1 downto i*WORD_WIDTH) :=
                                am_buffer_ram(CHUNKS_PER_VEC - 1 - (segment_index * 8 + i));
                        end loop;
                    end if;

                    -- Compute XOR of current segment (acc vs AM)
                    xor_result   <= acc_segment xor xor_temp;

                    -- Prepare popcount over 4-bit nibbles in the segment
                    popcount_step <= 0;
                    compare_state <= 8;  -- popcount state (handled next part)

                -- ------------------------------------------------
                -- STATE 5: Update minimum Hamming distance winner
                -- ------------------------------------------------
                -- After finishing popcount over all segments for this class,
                -- compare the accumulated Hamming distance to the current minimum.
                when 5 =>
                    if partial_hamming < min_hamming_distance then
                        min_hamming_distance := partial_hamming;
                        closest_memory_index <= memory_index;   -- remember current best class
                    end if;
                    compare_state <= 6;

                -- ------------------------------------------------
                -- STATE 6: Iterate over classes or finish comparison
                -- ------------------------------------------------
                -- If not at the last class, move to next class:
                --   - reset word_index
                --   - clear AM buffer for safety
                --   - go back to STATE 1 to read next class vector
                -- Else:
                --   - optionally update similarity_counter (if closest == expected class index 4)
                --   - proceed to majority/training state (STATE 7)
                when 6 =>
                    if memory_index = to_unsigned(4, 3) then   -- last class (0..4)
                        confusion_matrix(true_class_index, to_integer(unsigned(closest_memory_index))) 
                        <= confusion_matrix(true_class_index, to_integer(unsigned(closest_memory_index))) + 1;
                        -- Bookkeeping: if predicted class = "100" (index 4), increment success counter
                        if closest_memory_index = "100" then
                            similarity_counter <= similarity_counter + 1;
                        end if;
                        compare_state <= 7;   -- proceed to majority accumulation/training
                    else
                        -- Next class
                        memory_index <= memory_index + 1;
                        word_index   <= 0;
                        compare_state <= 1;

                        -- Clear AM buffer RAM for next class read
                        for i in 0 to CHUNKS_PER_VEC-1 loop
                            am_buffer_ram(i) <= (others => '0');
                        end loop;
                    end if;
                -- ------------------------------------------------
                -- STATE 8: Popcount over XOR segment
                -- ------------------------------------------------
                -- Process the 256-bit xor_result segment in 4-bit chunks.
                -- Each 4-bit chunk is passed through popcount4() → integer 0..4,
                -- and accumulated into partial_hamming.
                when 8 =>
                    -- Extract 4-bit chunk at index popcount_step
                    xor_chunk <= xor_result((popcount_step+1)*4 - 1 downto popcount_step*4);

                    -- Add # of ones in chunk to partial_hamming
                    partial_hamming := partial_hamming + 
                        to_unsigned(popcount4(xor_chunk), partial_hamming'length);

                    if popcount_step = BLOCKS_PER_SEG - 1 then
                        -- Done with all 4-bit chunks of this segment
                        popcount_step <= 0;

                        if segment_index = NUM_SEGMENTS - 1 then
                            -- Finished all segments of this class hypervector
                            compare_state <= 5; -- → evaluate Hamming distance
                        else
                            -- More segments left → increment and go back to STATE 4
                            segment_index <= segment_index + 1;
                            compare_state <= 4;
                        end if;
                    else
                        -- Next 4-bit chunk
                        popcount_step <= popcount_step + 1;
                    end if;

                -- ------------------------------------------------
                -- STATE 7: Majority accumulation (training phase)
                -- ------------------------------------------------
                -- In training mode, each bit of the bundled_result_acc_ram
                -- contributes to counters stored in counter_ram.
                -- FSM sub-states (maj_state_step):
                --   0 = READ counter
                --   1 = WAIT for BRAM latency
                --   2 = WRITE updated counter
                --
                when 7 =>
                    case maj_state_step is

                        -- ====== PHASE 0: READ ======
                        when 0 =>
                            cnt_we <= '0';  -- default: disable write

                            -- Compute linear bit index for current chunk + bit
                            if chunk_idx = CHUNKS_PER_VEC - 1 then
                                -- Special case: last chunk only has 16 valid bits
                                lin_idx_int := chunk_idx * WORD_WIDTH + 16 - 1 - bit_idx;
                            else
                                -- Normal case: all 32 bits valid
                                lin_idx_int := chunk_idx * WORD_WIDTH + (WORD_WIDTH - 1 - bit_idx);
                            end if;

                            if lin_idx_int < D then
                                -- Request counter at that bit index
                                maj_addr_rd <= to_unsigned(lin_idx_int, maj_addr_rd'length);
                            end if;

                            maj_state_step <= 1; -- → wait cycle

                        -- ====== PHASE 1: WAIT ======
                        when 1 =>
                            -- BRAM latency → counter value available next cycle
                            maj_state_step <= 2;

                        -- ====== PHASE 2: WRITE ======
                        when 2 =>
                            if lin_idx_int < D then
                                if bundled_result_acc_ram(chunk_idx)(bit_idx) = '1' then
                                    -- If bit = 1 → increment counter
                                    cnt_din    <= cnt_dout + 1;
                                    cnt_we     <= '1';
                                    maj_addr_wr <= to_unsigned(lin_idx_int, maj_addr_wr'length);
                                else
                                    -- Bit = 0 → nothing to update
                                    cnt_we <= '0';
                                end if;
                            else
                                cnt_we <= '0';
                            end if;

                            -- Special case: last chunk has only 16 valid bits
                            if chunk_idx = CHUNKS_PER_VEC - 1 and bit_idx >= 16 then
                                cnt_we <= '0'; 
                            end if;

                            -- Advance bit/chunk indices
                            if bit_idx = WORD_WIDTH - 1 then
                                -- Done with current 32-bit word
                                bit_idx <= 0;

                                if chunk_idx = CHUNKS_PER_VEC - 1 then
                                    -- Done with all words of hypervector

                                    -- Decide next step: training vs test
                                    if global_counter = DIVIDER and DIVIDER = TRAINDIVIDER then
                                        -- Completed training set → go to thresholding
                                        global_counter <= (others => '0');
                                        thresholding   <= '1';
                                        thr_idx        <= (others => '0');
                                        thr_valid      <= '1';
                                        thr_step       <= 0;
                                        thr_total      <= 0;
                                        word_idx_thr   <= 0;
                                        pack_reg       <= (others => '0');
                                        pack_fill_count <= 0;
                                        bits_needed_in_word <= 32;
                                        am_waddr_base  <= MAJ_CLASS_IDX * CHUNKS_PER_VEC;
                                        am_waddr_cur   <= MAJ_CLASS_IDX * CHUNKS_PER_VEC;
                                        use_internal_am_addr <= '1';  -- FSM controls AM
                                        am_write_active <= '1';
                                        compare_state <= 9;           -- → thresholding state
                                    elsif global_counter = DIVIDER and DIVIDER = TESTDIVIDER then
                                        -- Completed test set → reset
                                        global_counter <= (others => '0');
                                        compare_state  <= 0;
                                        true_class_index <= true_class_index + 1;
                                    else
                                        -- Not yet at DIVIDER → process next sample
                                        compare_state  <= 0;
                                    end if;

                                    -- Reset accumulator RAM for next input
                                    for i in 0 to CHUNKS_PER_VEC-1 loop
                                        bundled_result_acc_ram(i) <= (others => '0');
                                    end loop;

                                    -- Reset state
                                    min_hamming_distance := (others => '1');
                                    chunk_idx      <= 0;
                                    maj_state_step <= 0;
                                else
                                    -- Move to next chunk
                                    chunk_idx      <= chunk_idx + 1;
                                    maj_state_step <= 0;
                                end if;
                            else
                                -- Move to next bit in current word
                                bit_idx <= bit_idx + 1;
                                maj_state_step <= 0;
                            end if;

                        when others =>
                            maj_state_step <= 0;
                    end case;

                -- ------------------------------------------------
                -- STATE 9: Thresholding & writing majority vector to AM
                -- ------------------------------------------------
                -- Convert counter RAM values into final majority hypervector:
                --   For each bit index: if count > threshold_val → bit = 1.
                -- Bits are packed into 32-bit words and written to AM.
                --
                when 9 =>
                    if thresholding = '1' then
                        case thr_step is
                            -- ===== PHASE 0: READ counter =====
                            when 0 =>
                                maj_addr_rd <= to_unsigned(thr_total, maj_addr_rd'length);
                                thr_step    <= 1;

                            -- ===== PHASE 1: WAIT for BRAM =====
                            when 1 =>
                                thr_step <= 2;

                            -- ===== PHASE 2: PROCESS bit =====
                            when 2 =>
                                -- Check threshold
                                if cnt_dout > threshold_val then
                                    if bits_needed_in_word = 32 then
                                        pack_reg(31 - pack_fill_count) <= '1';
                                    else
                                        -- Last word only uses lower 16 bits
                                        pack_reg(15 - pack_fill_count) <= '1';
                                    end if;
                                end if;

                                pack_fill_count <= pack_fill_count + 1;
                                thr_total       <= thr_total + 1;

                                -- Word complete or all bits done?
                                if (pack_fill_count + 1 = bits_needed_in_word) or (thr_total = D) then
                                    thr_step <= 3;   -- → write to AM
                                else
                                    thr_step <= 0;   -- → next bit
                                end if;

                            -- ===== PHASE 3: WRITE AM word =====
                            when 3 =>
                                am_addr_write       <= std_logic_vector(to_unsigned(am_waddr_cur, 16));
                                am_data_in_internal <= pack_reg;
                                am_we_internal      <= '1';

                                if thr_total = D then
                                    -- Finished thresholding all D bits
                                    internal_done <= '1';
                                    done          <= '1';
                                    thresholding  <= '0';
                                    thr_step      <= 0;
                                    compare_state <= 10; -- → clear counter RAM
                                else
                                    -- Prepare next word
                                    word_idx_thr    <= word_idx_thr + 1;
                                    am_waddr_cur    <= am_waddr_base + word_idx_thr + 1;
                                    pack_reg        <= (others => '0');
                                    pack_fill_count <= 0;

                                    -- Last word only needs 16 bits
                                    if (word_idx_thr + 1 = CHUNKS_PER_VEC - 1) then
                                        bits_needed_in_word <= 16;
                                    else
                                        bits_needed_in_word <= 32;
                                    end if;

                                    thr_step <= 0; -- continue
                                end if;

                            when others =>
                                thr_step <= 0;
                        end case;
                    end if;

                -- ------------------------------------------------
                -- STATE 10: Clear counter RAM after thresholding
                -- ------------------------------------------------
                -- Reset all counters to 0 in preparation for next training class.
                --
                when 10 =>
                    cnt_we      <= '1';
                    maj_addr_wr <= cnt_clear_index;
                    cnt_din     <= (others => '0');

                    if cnt_clear_index = D then
                        -- Finished clearing all counters
                        cnt_clear_index <= (others => '0');
                        if MAJ_CLASS_IDX > 0 then
                            -- Move to next class
                            MAJ_CLASS_IDX <= MAJ_CLASS_IDX - 1;
                        else
                            -- All classes trained → switch to test mode
                            MAJ_CLASS_IDX <= -1;
                            DIVIDER       <= TESTDIVIDER;
                        end if;
                        compare_state   <= 0;
                        am_write_active <= '0';
                        am_we_internal  <= '0';
                        cnt_we          <= '0';
                    else
                        -- Continue clearing
                        cnt_clear_index <= cnt_clear_index + 1;
                    end if;

                -- ------------------------------------------------
                -- DEFAULT: safety fallback
                -- ------------------------------------------------
                when others =>
                    compare_state <= 0;
            end case;
        end if; -- rising_edge
    end process;
    -- ============================================================
    -- Final output assignments
    -- ============================================================

    -- Expose internal counters and results to top-level ports
    signal_counter_out        <= std_logic_vector(signal_counter);
        -- Number of processed hypervectors (global counter)

    similarity_counter_out    <= std_logic_vector(similarity_counter);
        -- Number of correct classifications (success counter)

    closest_memory_index_out  <= std_logic_vector(closest_memory_index);
        -- Index of the closest class in associative memory
end Behavioral;