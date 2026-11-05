library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_duration_detector_tb is
end entity button_duration_detector_tb;

architecture testbench of button_duration_detector_tb is
    -- Component declaration
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

    -- Default-Konstante passend zur Entity
    constant c_clk_freq_hz   : integer := 24_576_000;
    constant c_one_sec_ticks : integer := c_clk_freq_hz;

    -- Kompakte Taktperiode für schnelle Simulation bei 24,576 Mio. Zyklen
    constant CLK_PERIOD : time := 10 ns;

    -- Signals
    signal i_clk         : std_logic := '0';
    signal i_reset_n     : std_logic := '0';
    signal i_switch      : std_logic := '0';
    signal o_pulse_short : std_logic;
    signal o_pulse_long  : std_logic;

begin
    -- Component instantiation (nutzt den Default-Generic)
    dut : button_duration_detector
        port map (
            i_clk         => i_clk,
            i_reset_n     => i_reset_n,
            i_switch      => i_switch,
            o_pulse_short => o_pulse_short,
            o_pulse_long  => o_pulse_long
        );

    -- Clock generation
    i_clk <= not i_clk after CLK_PERIOD / 2;

    -- Testbench process
    process
    begin
        -- =========================================================
        -- Test 1: Asynchroner Reset
        -- =========================================================
        report "Test 1: Asynchroner Reset" severity note;
        i_reset_n <= '0';
        i_switch  <= '0';
        wait for 2 * CLK_PERIOD;
        assert o_pulse_short = '0' and o_pulse_long = '0'
            report "FAIL: Test 1 - Ausgaenge waehrend Reset nicht '0'!" severity failure;

        wait until falling_edge(i_clk);
        i_reset_n <= '1';
        wait for 2 * CLK_PERIOD;

        -- =========================================================
        -- Test 2: Kurzer Tastendruck (< 1 s)
        -- =========================================================
        report "Test 2: Kurzer Tastendruck (1000 Takte)" severity note;
        wait until falling_edge(i_clk);
        i_switch <= '1';

        -- Für 1000 Takte gedrückt halten
        for i in 1 to 1000 loop
            wait until falling_edge(i_clk);
            assert o_pulse_short = '0' and o_pulse_long = '0'
                report "FAIL: Test 2a - Impuls waehrend des kurzen Drueckens aktiv!" severity failure;
        end loop;

        -- Taster loslassen (vor steigender Flanke)
        i_switch <= '0';
        wait until rising_edge(i_clk);
        wait for 1 ns; -- Delta-Delay für Signalzuweisung abwarten

        assert o_pulse_short = '1'
            report "FAIL: Test 2b - o_pulse_short wurde beim Loslassen nicht '1'!" severity failure;
        assert o_pulse_long = '0'
            report "FAIL: Test 2c - o_pulse_long darf bei kurzem Druck nicht '1' sein!" severity failure;

        -- Prüfen, ob Impuls exakt 1 Takt lang ist
        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_short = '0'
            report "FAIL: Test 2d - o_pulse_short ist laenger als 1 Taktzyklus aktiv!" severity failure;

        wait for 5 * CLK_PERIOD;

        -- =========================================================
        -- Test 3: Langer Tastendruck (>= 1 s / 24.576.000 Takte)
        -- =========================================================
        report "Test 3: Langer Tastendruck (ONE_SEC_TICKS)" severity note;
        wait until falling_edge(i_clk);
        i_switch <= '1';

        -- (c_one_sec_ticks - 1) steigende Flanken abwarten
        wait for (c_one_sec_ticks - 1) * CLK_PERIOD;
        assert o_pulse_long = '0' and o_pulse_short = '0'
            report "FAIL: Test 3a - o_pulse_long hat mindestens 1 Takt zu frueh geschaltet!" severity failure;

        -- Exakt die 24.576.000-ste steigende Taktflanke prüfen
        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_long = '1'
            report "FAIL: Test 3b - o_pulse_long wurde nach exakt 1 s nicht '1'!" severity failure;
        assert o_pulse_short = '0'
            report "FAIL: Test 3c - o_pulse_short darf bei langem Druck nicht '1' sein!" severity failure;

        -- Im nächsten Takt muss o_pulse_long wieder '0' sein (obwohl Taster weiter gehalten wird)
        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_long = '0'
            report "FAIL: Test 3d - o_pulse_long ist laenger als 1 Taktzyklus aktiv!" severity failure;

        -- Noch 100 Takte weiter gedrückt halten (darf nicht erneut triggern)
        wait for 100 * CLK_PERIOD;
        assert o_pulse_long = '0' and o_pulse_short = '0'
            report "FAIL: Test 3e - Erneuter Impuls waehrend des Haltens aufgetreten!" severity failure;

        -- Taster nach langem Druck loslassen -> o_pulse_short darf NICHT ausgelöst werden
        wait until falling_edge(i_clk);
        i_switch <= '0';
        wait until rising_edge(i_clk);
        wait for 1 ns;
        assert o_pulse_short = '0' and o_pulse_long = '0'
            report "FAIL: Test 3f - o_pulse_short wurde beim Loslassen nach langem Druck faelschlich ausgeloest!" severity failure;

        wait for 5 * CLK_PERIOD;

        -- =========================================================
        -- Test 4: Reset während eines laufenden Tastendrucks
        -- =========================================================
        report "Test 4: Asynchroner Reset waehrend Tastendruck" severity note;
        wait until falling_edge(i_clk);
        i_switch <= '1';
        wait for 500 * CLK_PERIOD;

        -- Reset aktivieren, während Taster noch gedrückt ist
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
        report "PASS: Simulation erfolgreich beendet. Alle Tests bestanden." severity note;
        std.env.stop;
        wait;
    end process;

end architecture testbench;