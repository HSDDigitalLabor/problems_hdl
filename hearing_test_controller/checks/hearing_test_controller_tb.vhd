library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hearing_test_controller_tb is
end entity hearing_test_controller_tb;

architecture testbench of hearing_test_controller_tb is
    component hearing_test_controller is
        generic (
            CLK_FREQ_HZ     : integer := 24_576_000;
            RAMP_TIME_S     : integer := 10;
            NUM_FREQUENCIES : integer := 8
        );
        port (
            i_clk         : in  std_logic;
            i_reset_n     : in  std_logic;
            i_pulse_short : in  std_logic;
            i_pulse_long  : in  std_logic;
            o_fcw_addr    : out std_logic_vector(3 downto 0);
            o_volume      : out std_logic_vector(15 downto 0);
            o_is_running  : out std_logic
        );
    end component;

    constant c_clk_freq_hz     : integer := 24_576_000;
    constant c_ramp_time_s     : integer := 10;
    constant c_num_frequencies : integer := 8;
    constant c_ticks_per_step  : integer := (c_clk_freq_hz * c_ramp_time_s) / 65536; -- 3750 Takte

    -- 10 ns Taktperiode -> 1 Stufe (3750 Takte) dauert 37,5 us; Gesamtlaufzeit ca. 250 us
    constant CLK_PERIOD : time := 10 ns;

    signal i_clk         : std_logic := '0';
    signal i_reset_n     : std_logic := '0';
    signal i_pulse_short : std_logic := '0';
    signal i_pulse_long  : std_logic := '0';
    signal o_fcw_addr    : std_logic_vector(3 downto 0);
    signal o_volume      : std_logic_vector(15 downto 0);
    signal o_is_running  : std_logic;
    signal sim_done      : boolean   := false;

begin
    dut : hearing_test_controller
        port map (
            i_clk         => i_clk,
            i_reset_n     => i_reset_n,
            i_pulse_short => i_pulse_short,
            i_pulse_long  => i_pulse_long,
            o_fcw_addr    => o_fcw_addr,
            o_volume      => o_volume,
            o_is_running  => o_is_running
        );

    -- Clock generation
    i_clk <= not i_clk after CLK_PERIOD / 2 when not sim_done else '0';

    process
    begin
        -- Test 1: Asynchroner Reset
        report "Test 1: Asynchroner Reset" severity note;
        i_reset_n     <= '0';
        i_pulse_short <= '0';
        i_pulse_long  <= '0';
        wait for 2 * CLK_PERIOD;

        assert o_fcw_addr = x"0" and o_volume = x"0000" and o_is_running = '0'
            report "FAIL: Test 1 - Ausgaenge waehrend Reset nicht im Initialzustand!" severity failure;

        wait until falling_edge(i_clk);
        i_reset_n <= '1';
        wait for 2 * CLK_PERIOD;

        -- Test 2: Start durch kurzen Tastendruck & Timing pro Stufe (3750 Takte)
        report "Test 2: Start durch i_pulse_short und Pruefung von TICKS_PER_STEP" severity note;
        wait until falling_edge(i_clk);
        i_pulse_short <= '1';
        wait until falling_edge(i_clk);
        i_pulse_short <= '0';

        assert o_is_running = '1'
            report "FAIL: Test 2a - o_is_running wurde nach i_pulse_short nicht '1'!" severity failure;
        assert o_volume = x"0000"
            report "FAIL: Test 2b - o_volume muss direkt nach dem Start noch 0x0000 sein!" severity failure;

        wait for (c_ticks_per_step - 1) * CLK_PERIOD;
        assert o_volume = x"0000"
            report "FAIL: Test 2c - o_volume wurde mindestens 1 Takt zu frueh inkrementiert!" severity failure;

        wait for CLK_PERIOD;
        assert o_volume = x"0001"
            report "FAIL: Test 2d - o_volume wurde nach TICKS_PER_STEP nicht auf 0x0001 erhoeht!" severity failure;

        wait for 2 * c_ticks_per_step * CLK_PERIOD;
        assert o_volume = x"0003"
            report "FAIL: Test 2e - o_volume hat nach 3 Stufen nicht den Wert 0x0003!" severity failure;

        -- Test 3: Pause durch erneuten kurzen Tastendruck
        report "Test 3: Pause durch erneuten i_pulse_short" severity note;
        wait for (c_ticks_per_step / 2) * CLK_PERIOD;
        wait until falling_edge(i_clk);
        i_pulse_short <= '1';
        wait until falling_edge(i_clk);
        i_pulse_short <= '0';

        assert o_is_running = '0'
            report "FAIL: Test 3a - o_is_running wurde beim Pausieren nicht '0'!" severity failure;
        assert o_volume = x"0003"
            report "FAIL: Test 3b - o_volume hat sich beim Pausieren veraendert!" severity failure;

        wait for 2 * c_ticks_per_step * CLK_PERIOD;
        assert o_volume = x"0003" and o_is_running = '0'
            report "FAIL: Test 3c - o_volume hat sich waehrend der Pause weiter erhoeht!" severity failure;

        wait until falling_edge(i_clk);
        i_pulse_short <= '1';
        wait until falling_edge(i_clk);
        i_pulse_short <= '0';

        assert o_is_running = '1'
            report "FAIL: Test 3d - o_is_running wurde beim Fortsetzen nicht '1'!" severity failure;

        wait for (c_ticks_per_step - 1) * CLK_PERIOD;
        assert o_volume = x"0003"
            report "FAIL: Test 3e - Interner Tick-Zaehler wurde beim Toggle nicht zurueckgesetzt!" severity failure;

        wait for CLK_PERIOD;
        assert o_volume = x"0004"
            report "FAIL: Test 3f - o_volume wurde nach Fortsetzen nicht korrekt auf 0x0004 erhoeht!" severity failure;

        -- Test 4: Frequenzwechsel, Priorität & Wrap-Around (i_pulse_long)
        report "Test 4: Frequenzwechsel und Wrap-Around (i_pulse_long)" severity note;
        wait until falling_edge(i_clk);
        i_pulse_long <= '1';
        wait until falling_edge(i_clk);
        i_pulse_long <= '0';

        assert o_fcw_addr = x"1"
            report "FAIL: Test 4a - o_fcw_addr wurde nicht auf 1 erhoeht!" severity failure;
        assert o_volume = x"0000"
            report "FAIL: Test 4b - o_volume wurde bei Frequenzwechsel nicht auf 0x0000 zurueckgesetzt!" severity failure;
        assert o_is_running = '0'
            report "FAIL: Test 4c - o_is_running wurde bei Frequenzwechsel nicht auf '0' gesetzt!" severity failure;

        wait until falling_edge(i_clk);
        i_pulse_long  <= '1';
        i_pulse_short <= '1';
        wait until falling_edge(i_clk);
        i_pulse_long  <= '0';
        i_pulse_short <= '0';

        assert o_fcw_addr = x"2" and o_is_running = '0'
            report "FAIL: Test 4d - i_pulse_long hatte keine Prioritaet gegenueber i_pulse_short!" severity failure;

        for f in 3 to c_num_frequencies - 1 loop
            wait until falling_edge(i_clk);
            i_pulse_long <= '1';
            wait until falling_edge(i_clk);
            i_pulse_long <= '0';
            assert unsigned(o_fcw_addr) = to_unsigned(f, 4)
                report "FAIL: Test 4e - Inkorrekte Adresse beim Durchschalten!" severity failure;
        end loop;

        wait until falling_edge(i_clk);
        i_pulse_long <= '1';
        wait until falling_edge(i_clk);
        i_pulse_long <= '0';

        assert o_fcw_addr = x"0"
            report "FAIL: Test 4f - Wrap-Around von NUM_FREQUENCIES-1 auf 0 fehlgeschlagen!" severity failure;

        -- Test 5: Asynchroner Reset im Betrieb
        report "Test 5: Asynchroner Reset im Betrieb" severity note;
        wait until falling_edge(i_clk);
        i_pulse_long <= '1';
        wait until falling_edge(i_clk);
        i_pulse_long <= '0';

        i_reset_n <= '0';
        wait for 1 ns;
        assert o_fcw_addr = x"0" and o_volume = x"0000" and o_is_running = '0'
            report "FAIL: Test 5 - Asynchroner Reset hat Ausgaenge nicht sofort auf 0 gesetzt!" severity failure;

        wait for 2 * CLK_PERIOD;
        i_reset_n <= '1';

        wait for 500 * CLK_PERIOD;

        -- End simulation
        report "Simulation finished." severity note;
        sim_done <= true;
        wait;
    end process;

end architecture testbench;