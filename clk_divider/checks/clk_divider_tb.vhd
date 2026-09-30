library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_divider_tb is
end entity clk_divider_tb;

architecture sim of clk_divider_tb is

    -- 24.576 MHz -> Periode ca. 40.6901 ns
    constant CLK_PERIOD : time := 40.69 ns;

    -- Erwartete Dauern:
    -- 1 BCLK Halbtakt = 4 MCLK = 162.76 ns
    -- 1 LRCLK Halbtakt = 32 BCLK = 256 MCLK = 10416.64 ns
    constant BCLK_HALF_PERIOD  : time := 4 * CLK_PERIOD;
    constant LRCLK_HALF_PERIOD : time := 256 * CLK_PERIOD;

    signal clk_24_576m : std_logic := '0';
    signal rst         : std_logic := '0';
    signal bclk        : std_logic;
    signal lrclk       : std_logic;

    signal sim_finished : boolean := false;

    -- Hilfsfunktion zur formatierten Zeitausgabe in Mikrosekunden mit Komma
    function to_us_string(t : time) return string is
        variable t_ns     : integer;
        variable whole_us : integer;
        variable frac_us  : integer;
    begin
        t_ns     := t / 1 ns;
        whole_us := t_ns / 1000;
        frac_us  := (t_ns mod 1000) / 10;

        if frac_us < 10 then
            return integer'image(whole_us) & ",0" & integer'image(frac_us) & " us";
        else
            return integer'image(whole_us) & "," & integer'image(frac_us) & " us";
        end if;
    end function;

begin

    -- Instanziierung des Device Under Test (DUT)
    dut: entity work.clk_divider
        port map (
            clk_24_576m => clk_24_576m,
            rst         => rst,
            bclk        => bclk,
            lrclk       => lrclk
        );

    -- Clock Generation: 24.576 MHz
    clk_process : process
    begin
        while not sim_finished loop
            clk_24_576m <= '0';
            wait for CLK_PERIOD / 2;
            clk_24_576m <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimulus & Test Process
    stim_proc : process
        variable mclk_count : natural := 0;
        variable t_edge     : time;
        variable t_diff     : time;
    begin
        -- Test 1: Reset-Verhalten prüfen
        report "Test 1: Reset" severity note;
        rst <= '1';
        wait for 4 * CLK_PERIOD;
        assert (bclk = '0' and lrclk = '0')
            report "Reset failed: Ausgaenge nicht auf '0'!" severity error;
        
        -- Reset synchron zur fallenden Flanke freigeben
        wait until falling_edge(clk_24_576m);
        rst <= '0';

        -- Test 2: BCLK Timing exakt prüfen
        report "Test 2: Pruefe BCLK Timing exakt" severity note;
        
        -- Nach Reset muss BCLK nach genau 4 MCLK-Takten auf '1' gehen
        mclk_count := 0;
        while bclk = '0' loop
            wait until falling_edge(clk_24_576m);
            mclk_count := mclk_count + 1;
            assert (mclk_count <= 4)
                report "BCLK bleibt zu lange LOW nach Reset!" severity error;
        end loop;
        assert (mclk_count = 4)
            report "BCLK ging nicht nach genau 4 MCLK-Takten HIGH! Zaehler: " & integer'image(mclk_count)
            severity error;

        -- Test 3: LRCLK über 2 volle Perioden vermessen
        report "Test 3: Pruefe LRCLK Umschaltung und Dauer" severity note;
        
        -- Auf die erste reguläre steigende Flanke von LRCLK synchronisieren
        wait until rising_edge(lrclk);

        for cycle in 1 to 2 loop
            t_edge := now;
            
            -- High-Phase abwarten und Dauer prüfen
            wait until falling_edge(lrclk);
            t_diff := now - t_edge;
            assert (t_diff = LRCLK_HALF_PERIOD)
                report "LRCLK High-Phase ungleich 256 MCLK-Takte! Gemessen: " & to_us_string(t_diff) &
                       " (Erwartet: " & to_us_string(LRCLK_HALF_PERIOD) & ")"
                severity error;

            t_edge := now;
            
            -- Low-Phase abwarten und Dauer prüfen
            wait until rising_edge(lrclk);
            t_diff := now - t_edge;
            assert (t_diff = LRCLK_HALF_PERIOD)
                report "LRCLK Low-Phase ungleich 256 MCLK-Takte! Gemessen: " & to_us_string(t_diff) &
                       " (Erwartet: " & to_us_string(LRCLK_HALF_PERIOD) & ")"
                severity error;
        end loop;

        -- Test 4: Reset waehrend des Betriebs
        report "Test 4: Reset waehrend Betrieb" severity note;
        wait until falling_edge(clk_24_576m);
        rst <= '1';
        
        -- Reset lange genug halten (mindestens 1 BCLK-Periode = 8 MCLKs)
        wait for 10 * CLK_PERIOD;
        wait until falling_edge(clk_24_576m);
        
        assert (bclk = '0' and lrclk = '0')
            report "Re-Reset fehlgeschlagen: Ausgaenge nicht auf '0'!" severity error;
        rst <= '0';

        -- Pufferzeit am Ende für saubere Darstellung in der Waveform
        wait for 10 us;

        report "Alle Tests erfolgreich abgeschlossen!" severity note;
        sim_finished <= true;
        wait;
    end process;

end architecture sim;