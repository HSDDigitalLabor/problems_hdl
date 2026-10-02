library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_transmitter_tb is
end entity i2s_transmitter_tb;

architecture sim of i2s_transmitter_tb is

    -- BCLK: 3.072 MHz -> Periode ca. 325.52 ns
    constant BCLK_PERIOD : time := 325.52 ns;

    signal bclk       : std_logic := '0';
    signal lrclk      : std_logic := '0';
    signal rst        : std_logic := '0';
    signal data_left  : signed(15 downto 0) := (others => '0');
    signal data_right : signed(15 downto 0) := (others => '0');
    signal sdata      : std_logic;

    signal sim_finished : boolean := false;

    -- Test-Muster
    constant PATTERN_LEFT_1  : signed(15 downto 0) := x"A5A5";
    constant PATTERN_RIGHT_1 : signed(15 downto 0) := x"5B5B";
    constant PATTERN_LEFT_2  : signed(15 downto 0) := x"1234";
    constant PATTERN_RIGHT_2 : signed(15 downto 0) := x"89AB";

begin

    -- Device Under Test (DUT)
    dut: entity work.i2s_transmitter
        port map (
            bclk       => bclk,
            lrclk      => lrclk,
            rst        => rst,
            data_left  => data_left,
            data_right => data_right,
            sdata      => sdata
        );

    -- BCLK Generator (3.072 MHz)
    bclk_process : process
    begin
        while not sim_finished loop
            bclk <= '0';
            wait for BCLK_PERIOD / 2;
            bclk <= '1';
            wait for BCLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimulus & Test Process
    stim_proc : process
        variable expected_vec : std_logic_vector(31 downto 0);

        -- Hilfsprozedur zum Überprüfen eines 32-Bit I2S-Subframes
        -- Tastet tolerant in der Mitte des BCLK-Low-Pegels ab
        procedure check_subframe(
            constant data_word : in signed(15 downto 0);
            constant channel_name : in string
        ) is
        begin
            expected_vec := std_logic_vector(data_word) & x"0000";

            -- I2S 1-BCLK Versatz:
            -- Der erste Takt nach der LRCLK-Flanke ist das Delay-Bit (noch kein MSB)
            wait until falling_edge(bclk);
            wait for BCLK_PERIOD / 4; -- Abtastung tolerant in der Mitte von Low

            -- 32 Datenbits (MSB first) pruefen
            for i in 31 downto 0 loop
                wait until falling_edge(bclk);
                wait for BCLK_PERIOD / 4; -- Abtastpunkt tolerant gewaehlt

                assert (sdata = expected_vec(i))
                    report "Bit-Fehler in " & channel_name & " bei Bit " & integer'image(i) &
                           "! Erwartet: " & std_logic'image(expected_vec(i)) &
                           ", Erhalten: " & std_logic'image(sdata)
                    severity error;
            end loop;
        end procedure;

    begin
        -- Test 1: Reset-Verhalten prüfen
        report "Test 1: Reset" severity note;
        rst <= '0';
        lrclk <= '1';
        data_left  <= PATTERN_LEFT_1;
        data_right <= PATTERN_RIGHT_1;
        
        wait for 4 * BCLK_PERIOD;
        assert (sdata = '0')
            report "Reset failed: sdata nicht '0'!" severity error;

        -- Reset synchron freigeben
        wait until falling_edge(bclk);
        rst <= '1';

        -- Test 2: Erster Frame (Left = 0, Right = 1)
        report "Test 2: Pruefe Frame 1 (Links: 0xA5A5, Rechts: 0x5B5B)" severity note;

        -- Flanke zu Left (LRCLK = 0)
        wait until falling_edge(bclk);
        lrclk <= '0';
        check_subframe(PATTERN_LEFT_1, "Links (0xA5A5)");

        -- Flanke zu Right (LRCLK = 1)
        wait until falling_edge(bclk);
        lrclk <= '1';
        check_subframe(PATTERN_RIGHT_1, "Rechts (0x5B5B)");

        -- Test 3: Zweiter Frame mit neuen Daten
        report "Test 3: Pruefe Frame 2 mit dynamischem Datenwechsel" severity note;
        data_left  <= PATTERN_LEFT_2;
        data_right <= PATTERN_RIGHT_2;

        wait until falling_edge(bclk);
        lrclk <= '0';
        check_subframe(PATTERN_LEFT_2, "Links (0x1234)");

        wait until falling_edge(bclk);
        lrclk <= '1';
        check_subframe(PATTERN_RIGHT_2, "Rechts (0x89AB)");

        -- Test 4: Reset waehrend des Betriebs
        report "Test 4: Reset waehrend Betrieb" severity note;
        wait until falling_edge(bclk);
        rst <= '0';
        wait for 3 * BCLK_PERIOD;
        
        assert (sdata = '0')
            report "Re-Reset fehlgeschlagen: sdata nicht auf '0'!" severity error;

        -- Pufferzeit am Ende für saubere Waveform-Darstellung
        wait for 5 * BCLK_PERIOD;

        report "Alle Tests erfolgreich abgeschlossen!" severity note;
        sim_finished <= true;
        wait;
    end process;

end architecture sim;