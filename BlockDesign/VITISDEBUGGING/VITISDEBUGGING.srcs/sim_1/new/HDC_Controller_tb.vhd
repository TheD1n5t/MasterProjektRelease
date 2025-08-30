library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use IEEE.MATH_REAL.ALL;

entity HDC_Controller_tb is
end HDC_Controller_tb;

architecture Behavioral of HDC_Controller_tb is

    constant CHUNKS_PER_VEC : integer := 10000 / 32;
    type integer_vector is array (natural range <>) of integer;

    component HDC_Controller is
        generic (
            D : integer := 10000;
            N : integer := 32;
            M : integer := 100
        );
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            start : in STD_LOGIC;
            done : out STD_LOGIC;
            feature_value : in STD_LOGIC_VECTOR(15 downto 0);
            feature_valid : in STD_LOGIC;
            similarity_counter_out : out STD_LOGIC_VECTOR(7 downto 0);
            signal_counter_out : out STD_LOGIC_VECTOR(31 downto 0);
            mem_sel : in STD_LOGIC_VECTOR(1 downto 0);
            mem_we : in STD_LOGIC;
            mem_addr : in STD_LOGIC_VECTOR(15 downto 0);
            mem_data_in : in STD_LOGIC_VECTOR(31 downto 0);
            mem_data_out : out STD_LOGIC_VECTOR(31 downto 0);
            internal_done : out STD_LOGIC;
            done_encoding_monitor : out STD_LOGIC;
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
            sim_counter_dbg : out STD_LOGIC_VECTOR(9 downto 0);
            maj_class_index_dbg: out std_logic_vector(2 downto 0);
            test_cnt_dbg: out std_logic_vector(12 downto 0);
            global_cnt_dbg: out unsigned(9 downto 0)
        );
    end component;

    signal clk : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '1';
    signal start : STD_LOGIC := '0';
    signal load_mode : STD_LOGIC := '0';
    signal done : STD_LOGIC;
    signal feature_value : STD_LOGIC_VECTOR(15 downto 0);
    signal feature_valid : STD_LOGIC := '0';
    signal similarity_counter : STD_LOGIC_VECTOR(7 downto 0);

    signal mem_sel : STD_LOGIC_VECTOR(1 downto 0);
    signal mem_we : STD_LOGIC := '0';
    signal mem_addr : STD_LOGIC_VECTOR(15 downto 0);
    signal mem_data_in : STD_LOGIC_VECTOR(31 downto 0);
    signal mem_data_out : STD_LOGIC_VECTOR(31 downto 0);

    signal done_encoding_monitor : STD_LOGIC := '0';
    signal internal_done : STD_LOGIC := '0';
    signal majority : STD_LOGIC_VECTOR(9999 downto 0);

    signal mem_init_done : boolean := false;
    signal im_init_done  : boolean := false;
    signal cm_init_done  : boolean := false;
    signal ready_to_start : boolean := false;
    signal dbg_compare_state : integer range 0 to 10;
    signal dbg_signal_counter : integer range 0 to 10000;
    constant clk_period : time := 10 ns;
    

begin

    uut: HDC_Controller
        port map (
            clk => clk,
            reset => reset,
            start => start,
            feature_value => feature_value,
            feature_valid => feature_valid,
            similarity_counter_out => similarity_counter,
            done => done,
            mem_sel => mem_sel,
            mem_we => mem_we,
            mem_addr => mem_addr,
            mem_data_in => mem_data_in,
            mem_data_out => mem_data_out,
            internal_done => internal_done,
            done_encoding_monitor => done_encoding_monitor,
            load_mode => load_mode,
            dbg_compare_state => dbg_compare_state,
            dbg_signal_counter => dbg_signal_counter
        );

    clk_process : process
    begin
        while true loop
            clk <= '0'; wait for clk_period / 2;
            clk <= '1'; wait for clk_period / 2;
        end loop;
    end process;

    sync_wrapper: process(clk)
    begin
        if rising_edge(clk) then
            if mem_init_done and im_init_done and cm_init_done then
                ready_to_start <= true;
            end if;
        end if;
    end process;

    initialization_process: process
    file am_file : text open read_mode is "D:/Documents/FAU/MASTERPROJEKT/compare_values.txt";
    file im_file : text open read_mode is "D:/Documents/FAU/MASTERPROJEKT/position-vectors.txt";
    file cm_file : text open read_mode is "D:/Documents/FAU/MASTERPROJEKT/value_vectors.txt";

    variable text_line : line;
    variable char : character;
    variable segment_bits : std_logic_vector(31 downto 0);
    variable bit_idx : integer;
    variable file_char_idx : integer;
begin
    load_mode  <= '1';
    -- ========== AM (compare-values) ==========
    wait until reset = '0';
    wait for clk_period * 5;
    -- Jetzt beginnt Initialisierung
    
    mem_we  <= '0';
    mem_sel <= "10"; -- AM
    mem_addr <= (others => '0');
    mem_data_in <= (others => '0');
    wait until rising_edge(clk);
    mem_we <= '1';
    
      for i in 0 to 4 loop
            readline(am_file, text_line);
            file_char_idx := 0;

            for chunk in 0 to CHUNKS_PER_VEC loop
                for bit_idx in 31 downto 0 loop
                    if file_char_idx < text_line'length then
                        char := text_line(file_char_idx + 1);
                        case char is
                            when '0' => segment_bits(bit_idx) := '0';
                            when '1' => segment_bits(bit_idx) := '1';
                            when others =>
                                report "Ungültiges Zeichen '" & char & "' in Zeile " & integer'image(i) severity error;
                        end case;
                        file_char_idx := file_char_idx + 1;
                    else
                        segment_bits(bit_idx) := '0';
                    end if;
                end loop;
            
                mem_addr <= std_logic_vector(to_unsigned(i * (CHUNKS_PER_VEC+1) + chunk, 16));
                mem_data_in <= segment_bits;
                wait until rising_edge(clk);
            end loop;
        end loop;

    -- ========== IM (position-vectors) ==========
    wait for clk_period * 5;
    -- Jetzt beginnt Initialisierung
    
    mem_we  <= '0';
    mem_sel <= "00"; -- IM
    mem_addr <= (others => '0');
    mem_data_in <= (others => '0');
    wait until rising_edge(clk);
    mem_we <= '1';
    
    for i in 0 to 31 loop
        readline(im_file, text_line);
        file_char_idx := 0;
    
        for chunk in 0 to CHUNKS_PER_VEC loop
            -- Daten aus Datei laden
            for bit_idx in 31 downto 0 loop
                if file_char_idx < text_line'length then
                    char := text_line(file_char_idx + 1);
                    case char is
                        when '0' => segment_bits(bit_idx) := '0';
                        when '1' => segment_bits(bit_idx) := '1';
                        when others =>
                            report "Ungültiges Zeichen '" & char & "' in Zeile " & integer'image(i) severity error;
                    end case;
                    file_char_idx := file_char_idx + 1;
                else
                    segment_bits(bit_idx) := '0';
                end if;
            end loop;
    
             mem_addr <= std_logic_vector(to_unsigned(i * (CHUNKS_PER_VEC+1) + chunk, 16));
             
             wait until rising_edge(clk);
             mem_data_in <= segment_bits;
        end loop;
    end loop;


    
    -- ========== CM (value-vectors) ==========
    mem_we  <= '0';
    mem_sel <= "01"; -- CM
    mem_addr <= (others => '0');
    mem_data_in <= (others => '0');
    wait until rising_edge(clk);
    mem_we <= '1';
    for i in 0 to 99 loop
        readline(cm_file, text_line);
        file_char_idx := 0;

        for chunk in 0 to CHUNKS_PER_VEC loop
            for bit_idx in 31 downto 0 loop
                if file_char_idx < text_line'length then
                    char := text_line(file_char_idx + 1);
                    case char is
                        when '0' => segment_bits(bit_idx) := '0';
                        when '1' => segment_bits(bit_idx) := '1';
                        when others =>
                            report "Ungültiges Zeichen '" & char & "' in CM-Zeile " & integer'image(i) severity error;
                    end case;
                    file_char_idx := file_char_idx + 1;
                else
                    segment_bits(bit_idx) := '0';
                end if;
            end loop;

            mem_addr    <= std_logic_vector(to_unsigned(i * (CHUNKS_PER_VEC+1) + chunk, 16));
            wait until rising_edge(clk);
            mem_data_in <= segment_bits;
        end loop;
    end loop;

    mem_we <= '0';
    wait for clk_period * 2;
    load_mode  <= '0';
    -- Initialisierung abgeschlossen
    mem_init_done <= true;
    im_init_done  <= true;
    cm_init_done  <= true;

    wait;
end process;


    file_read_process: process
        file feature_file : text open read_mode is "D:/Documents/FAU/MASTERPROJEKT/feature_values.txt";
        variable line_content : line;
        variable features : integer_vector(0 to 31);
        variable temp_value : real;
        variable emgcounter: integer := 0;
        variable last_counter : integer := 0;
    begin
        reset <= '1';
        wait for clk_period * 2;
        reset <= '0';

        wait until cm_init_done = true;
        wait for clk_period * 10;

        while not endfile(feature_file) loop
            for i in 0 to 31 loop
                readline(feature_file, line_content);
                read(line_content, temp_value);
                features(i) := integer(temp_value * 10000.0 + 10000.0);
                if features(i) >= 55000 then
                    features(i) := 55000;
                end if;
            end loop;

            for j in 0 to 31 loop
                feature_value <= std_logic_vector(to_unsigned(features(j), 16));
                feature_valid <= '1';
                wait until rising_edge(clk);
                feature_valid <= '0';
                wait until rising_edge(clk);
            end loop;
            
            emgcounter := emgcounter +1;
            start <= '1';
            last_counter := dbg_signal_counter;
            wait until dbg_signal_counter /= last_counter;
            start <= '0';
        end loop;
        wait;
    end process;

-- File Writing Process
    file_write_process: process
        file output_file : text open write_mode is "D:\Documents\FAU\MASTERPROJEKT\bundled_result_accumulator.txt";
        variable line_content : line;
        variable majority_string : string(1 to 10000);
    begin
        wait until internal_done = '1';

        -- Convert majority signal to string
        for i in 0 to 9999 loop
            if majority(i) = '1' then
                majority_string(i+1) := '1';
            else
                majority_string(i+1) := '0';
            end if;
        end loop;

        -- Write the result to the file
        write(line_content, majority_string);
        writeline(output_file, line_content);
        wait;
    end process;


end Behavioral;

