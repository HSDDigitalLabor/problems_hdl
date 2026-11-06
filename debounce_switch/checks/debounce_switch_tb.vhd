library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce_switch_tb is
end entity debounce_switch_tb;

architecture testbench of debounce_switch_tb is
    component debounce_switch is
        generic (
            CLK_FREQ_HZ      : integer := 24_576_000;
            DEBOUNCE_TIME_MS : integer := 10
        );
        port (
            i_clk    : in  std_logic;
            i_switch : in  std_logic;
            o_switch : out std_logic
        );
    end component;

    constant c_clk_freq_hz      : integer := 24_576_000;
    constant c_debounce_time_ms : integer := 10;
    constant c_debounce_limit   : integer := (c_clk_freq_hz / 1000) * c_debounce_time_ms; -- 245760 Takte

    -- 500 ps Taktperiode -> Gesamte Testbench (~770.000 Takte) benoetigt ca. 385 us (passt optimal in 500 us)
    constant CLK_PERIOD : time := 500 ps;

    signal i_clk    : std_logic := '0';
    signal i_switch : std_logic := '0';
    signal o_switch : std_logic;
    signal sim_done : boolean   := false;

begin
    dut : debounce_switch
        port map (
            i_clk    => i_clk,
            i_switch => i_switch,
            o_switch => o_switch
        );

    -- Clock generation (stoppt automatisch, sobald sim_done = true ist)
    i_clk <= not i_clk after CLK_PERIOD / 2 when not sim_done else '0';

    process
    begin
        wait for 10 * CLK_PERIOD;
        assert o_switch = '0' report "FAIL: Initialer Zustand von o_switch ist nicht '0'!" severity failure;

        -- Test 1: Tasterprellen beim Einschalten
        report "Test 1: Simuliere Prellen (Bouncing) auf '1'" severity note;
        i_switch <= '1';
        wait for 5000 * CLK_PERIOD;
        assert o_switch = '0' report "FAIL: Test 1a - Ausgang hat bei kurzem Impuls zu frueh geschaltet!" severity failure;

        i_switch <= '0';
        wait for 1000 * CLK_PERIOD;

        i_switch <= '1';
        wait for (c_debounce_limit - 10) * CLK_PERIOD;
        assert o_switch = '0' report "FAIL: Test 1b - Ausgang hat kurz vor Ablauf der Entprellzeit geschaltet!" severity failure;

        i_switch <= '0';
        wait for 10 * CLK_PERIOD;
        assert o_switch = '0' report "FAIL: Test 1c - Ausgang ist nach Zaehler-Reset nicht auf '0' geblieben!" severity failure;

        -- Test 2: Stabiler Tastendruck ('0' -> '1')
        report "Test 2: Stabiler Tastendruck ('0' -> '1')" severity note;
        wait until falling_edge(i_clk);
        i_switch <= '1';

        wait for (c_debounce_limit - 1) * CLK_PERIOD;
        assert o_switch = '0' report "FAIL: Test 2a - Ausgang hat mindestens 2 Takte zu frueh auf '1' geschaltet!" severity failure;

        wait for 2 * CLK_PERIOD;
        assert o_switch = '1' report "FAIL: Test 2b - Ausgang hat nach Ablauf der Entprellzeit nicht auf '1' geschaltet!" severity failure;

        wait for 1000 * CLK_PERIOD;
        assert o_switch = '1' report "FAIL: Test 2c - Ausgang bleibt nicht stabil auf '1'!" severity failure;

        -- Test 3: Tasterprellen beim Loslassen ('1' -> '0')
        report "Test 3: Simuliere Prellen (Bouncing) auf '0'" severity note;
        i_switch <= '0';
        wait for (c_debounce_limit / 2) * CLK_PERIOD;
        assert o_switch = '1' report "FAIL: Test 3 - Ausgang ist bei kurzem Einbruch auf '0' abgefallen!" severity failure;

        i_switch <= '1';
        wait for 100 * CLK_PERIOD;
        assert o_switch = '1' report "FAIL: Test 3 - Ausgang ist nach Einbruch nicht auf '1' geblieben!" severity failure;

        -- Test 4: Stabiles Loslassen des Tasters ('1' -> '0')
        report "Test 4: Stabiles Loslassen ('1' -> '0')" severity note;
        wait until falling_edge(i_clk);
        i_switch <= '0';

        wait for (c_debounce_limit - 1) * CLK_PERIOD;
        assert o_switch = '1' report "FAIL: Test 4a - Ausgang hat zu frueh auf '0' geschaltet!" severity failure;

        wait for 2 * CLK_PERIOD;
        assert o_switch = '0' report "FAIL: Test 4b - Ausgang hat nach Entprellzeit nicht auf '0' geschaltet!" severity failure;

        -- End simulation
        report "Simulation finished." severity note;
        sim_done <= true;
        wait;
    end process;

end architecture testbench;