library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_duration_detector_tb is
end entity button_duration_detector_tb;

architecture testbench of button_duration_detector_tb is
    component button_duration_detector is
        generic (
            CLK_FREQ_HZ : integer := 24_576_000
        );
        port (
            i_clk         : in  std_logic;
            i_reset_n     : in  std_logic;
            i_switch      : in  std_logic;
            o_pulse_short : out std_logic;
            o_pulse_long  : out std_logic
        );
    end component;

    -- Frequenz für den Test auf 1000 Hz herunterskalieren (1 Sekunde = 1000 Takte)
    constant c_clk_freq_hz   : integer := 1000;
    constant c_one_sec_ticks : integer := c_clk_freq_hz;
    constant CLK_PERIOD      : time    := 10 ns;

    signal i_clk         : std_logic := '0';
    signal i_reset_n     : std_logic := '0';
    signal i_switch      : std_logic := '0';
    signal o_pulse_short : std_logic;
    signal o_pulse_long  : std_logic;
    signal sim_done      : boolean   := false;

begin
    -- Generic map übergeben, damit die Schaltung mit 1000 Takten pro Sekunde rechnet
    dut : button_duration_detector
        generic map (
            CLK_FREQ_HZ => c_clk_freq_hz
        )
        port map (
            i_clk         => i_clk,
            i_reset_n     => i_reset_n,
            i_switch      => i_switch,
            o_pulse_short => o_pulse_short,
            o_pulse_long  => o_pulse_long
        );

    -- Clock generation
    i_clk <= not i_clk after CLK_PERIOD / 2 when not sim_done else '0';

    process
    begin
        -- Test 1: Asynchroner Reset
        report "Test 1: Asynchroner Reset" severity note;
        i_reset_n <= '0';
        i_switch  <= '0';
        wait for 2 * CLK_PERIOD;
        assert o_pulse_short = '0' and o_pulse_long = '0'
            report "FAIL: Test 1 - Ausgaenge waehrend Reset nicht '0'!" severity failure;

        wait until falling_edge(i_clk);
        i_reset_n <= '1';
        wait for 2 * CLK_PERIOD;

        -- Test 2: Kurzer Tastendruck (< 1 s)
        report "Test 2: Kurzer Tastendruck (100 Takte)" severity note;
        wait until falling_edge(i_clk);
        i_switch <= '1';

        for i in 1 to 100 loop
            wait until falling_edge(i_clk);
            assert o_pulse_short = '0' and o_pulse_long = '0'
                report "FAIL: Test 2a - Impuls waehrend des kurzen Drueckens aktiv!" severity failure;
        end loop;

        i_switch <= '0';
        wait until rising_edge(i_clk);
        wait for 1 ns;

        assert o_pulse_short = '1'
            report "FAIL: Test 2b - o_pulse_short wurde beim Loslassen nicht '1'!" severity failure;
        assert o_pulse_long = '0'
            report "FAIL: Test 2c - o_pulse_long darf bei kurzem Druck nicht '1' sein!" severity failure;

        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_short = '0'
            report "FAIL: Test 2d - o_pulse_short ist laenger als 1 Taktzyklus aktiv!" severity failure;

        wait for 5 * CLK_PERIOD;

        -- Test 3: Langer Tastendruck (>= 1 s / 1000 Takte)
        report "Test 3: Langer Tastendruck (ONE_SEC_TICKS)" severity note;
        wait until falling_edge(i_clk);
        i_switch <= '1';

        wait for (c_one_sec_ticks - 1) * CLK_PERIOD;
        assert o_pulse_long = '0' and o_pulse_short = '0'
            report "FAIL: Test 3a - o_pulse_long hat mindestens 1 Takt zu frueh geschaltet!" severity failure;

        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_long = '1'
            report "FAIL: Test 3b - o_pulse_long wurde nach exakt 1 s nicht '1'!" severity failure;
        assert o_pulse_short = '0'
            report "FAIL: Test 3c - o_pulse_short darf bei langem Druck nicht '1' sein!" severity failure;

        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_long = '0'
            report "FAIL: Test 3d - o_pulse_long ist laenger als 1 Taktzyklus aktiv!" severity failure;

        wait for 50 * CLK_PERIOD;
        assert o_pulse_long = '0' and o_pulse_short = '0'
            report "FAIL: Test 3e - Erneuter Impuls waehrend des Haltens aufgetreten!" severity failure;

        wait until falling_edge(i_clk);
        i_switch <= '0';
        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_short = '0' and o_pulse_long = '0'
            report "FAIL: Test 3f - o_pulse_short wurde beim Loslassen nach langem Druck faelschlich ausgeloest!" severity failure;

        wait for 5 * CLK_PERIOD;

        -- Test 4: Reset während eines laufenden Tastendrucks
        report "Test 4: Asynchroner Reset waehrend Tastendruck" severity note;
        wait until falling_edge(i_clk);
        i_switch <= '1';
        wait for 50 * CLK_PERIOD;

        i_reset_n <= '0';
        wait for 1 ns;
        assert o_pulse_short = '0' and o_pulse_long = '0'
            report "FAIL: Test 4a - Ausgaenge bei Reset nicht '0'!" severity failure;

        wait until falling_edge(i_clk);
        i_switch  <= '0';
        i_reset_n <= '1';
        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_short = '0' and o_pulse_long = '0'
            report "FAIL: Test 4b - Nach Reset wurde faelschlicherweise ein Impuls erzeugt!" severity failure;

        -- End simulation
        report "Simulation finished." severity note;
        sim_done <= true;
        wait;
    end process;

end architecture testbench;