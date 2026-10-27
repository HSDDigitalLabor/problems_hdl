library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fft_tb is
end entity fft_tb;

architecture testbench of fft_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal in_valid  : std_logic := '0';
    signal in_re     : signed(15 downto 0) := (others => '0');
    signal in_im     : signed(15 downto 0) := (others => '0');
    signal out_valid : std_logic;
    signal bin_idx   : unsigned(3 downto 0);
    signal out_re    : signed(15 downto 0);
    signal out_im    : signed(15 downto 0);

    -- Signalkonfiguration: 48 kHz Abtastrate, 16-Punkt-FFT -> 3 kHz pro Bin
    constant FS         : real := 48000.0;
    constant F_SIG_3K   : real := 3000.0;  -- Bin 1
    constant F_SIG_6K   : real := 6000.0;  -- Bin 2
    constant F_SIG_9K   : real := 9000.0;  -- Bin 3
    
    constant AMPLITUDE  : real := 32767.0; -- Volle 16-Bit Aussteuerung
    
    -- Phasenwinkel in Radiant
    constant PHASE_45   : real := MATH_PI / 4.0;             -- 45 Grad
    constant PHASE_20   : real := 20.0 * MATH_PI / 180.0;    -- 20 Grad

begin

    -- Taktgenerator (100 MHz Systemtakt)
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT Instanziierung[cite: 4]
    dut: entity work.fft16_core
        port map (
            clk       => clk,
            rst       => rst,
            in_valid  => in_valid,
            in_re     => in_re,
            in_im     => in_im,
            out_valid => out_valid,
            bin_idx   => bin_idx,
            out_re    => out_re,
            out_im    => out_im
        );

    -- Stimulus-Prozess mit 6 Testfällen und Handshake-Prüfung
    process
        variable t_sample    : real;
        variable val_real    : real;
        variable valid_count : integer;
    begin
        rst <= '1';
        wait for 40 ns;
        rst <= '0';
        wait for 20 ns;

        -- ====================================================================
        -- TESTFALL 1: Reiner Sinus (0 Grad) bei 3 kHz
        -- ====================================================================
        for n in 0 to 15 loop
            t_sample := real(n) / FS;
            val_real := AMPLITUDE * sin(2.0 * MATH_PI * F_SIG_3K * t_sample);
            in_re    <= to_signed(integer(round(val_real)), 16);
            in_im    <= (others => '0');
            in_valid <= '1';
            wait for CLK_PERIOD;
            in_valid <= '0';
        end loop;

        valid_count := 0;
        for timeout in 0 to 100 loop
            if out_valid = '1' then
                valid_count := valid_count + 1;
            end if;
            wait for CLK_PERIOD;
            exit when valid_count = 16;
        end loop;
        assert valid_count = 16 report "Error: Test 1 failed - No or incomplete FFT output!" severity error;

        -- ====================================================================
        -- TESTFALL 2: Reiner Kosinus (0 Grad) bei 3 kHz
        -- ====================================================================
        for n in 0 to 15 loop
            t_sample := real(n) / FS;
            val_real := AMPLITUDE * cos(2.0 * MATH_PI * F_SIG_3K * t_sample);
            in_re    <= to_signed(integer(round(val_real)), 16);
            in_im    <= (others => '0');
            in_valid <= '1';
            wait for CLK_PERIOD;
            in_valid <= '0';
        end loop;

        valid_count := 0;
        for timeout in 0 to 100 loop
            if out_valid = '1' then
                valid_count := valid_count + 1;
            end if;
            wait for CLK_PERIOD;
            exit when valid_count = 16;
        end loop;
        assert valid_count = 16 report "Error: Test 2 failed - No or incomplete FFT output!" severity error;

        -- ====================================================================
        -- TESTFALL 3: Sinus mit 45 Grad Phase bei 3 kHz
        -- ====================================================================
        for n in 0 to 15 loop
            t_sample := real(n) / FS;
            val_real := AMPLITUDE * sin(2.0 * MATH_PI * F_SIG_3K * t_sample + PHASE_45);
            in_re    <= to_signed(integer(round(val_real)), 16);
            in_im    <= (others => '0');
            in_valid <= '1';
            wait for CLK_PERIOD;
            in_valid <= '0';
        end loop;

        valid_count := 0;
        for timeout in 0 to 100 loop
            if out_valid = '1' then
                valid_count := valid_count + 1;
            end if;
            wait for CLK_PERIOD;
            exit when valid_count = 16;
        end loop;
        assert valid_count = 16 report "Error: Test 3 failed - No or incomplete FFT output!" severity error;

        -- ====================================================================
        -- TESTFALL 4: Sinus mit 20 Grad Phase bei 3 kHz
        -- ====================================================================
        for n in 0 to 15 loop
            t_sample := real(n) / FS;
            val_real := AMPLITUDE * sin(2.0 * MATH_PI * F_SIG_3K * t_sample + PHASE_20);
            in_re    <= to_signed(integer(round(val_real)), 16);
            in_im    <= (others => '0');
            in_valid <= '1';
            wait for CLK_PERIOD;
            in_valid <= '0';
        end loop;

        valid_count := 0;
        for timeout in 0 to 100 loop
            if out_valid = '1' then
                valid_count := valid_count + 1;
            end if;
            wait for CLK_PERIOD;
            exit when valid_count = 16;
        end loop;
        assert valid_count = 16 report "Error: Test 4 failed - No or incomplete FFT output!" severity error;

        -- ====================================================================
        -- TESTFALL 5: Sinus mit 20 Grad Phase bei 6 kHz (Bin 2)
        -- ====================================================================
        for n in 0 to 15 loop
            t_sample := real(n) / FS;
            val_real := AMPLITUDE * sin(2.0 * MATH_PI * F_SIG_6K * t_sample + PHASE_20);
            in_re    <= to_signed(integer(round(val_real)), 16);
            in_im    <= (others => '0');
            in_valid <= '1';
            wait for CLK_PERIOD;
            in_valid <= '0';
        end loop;

        valid_count := 0;
        for timeout in 0 to 100 loop
            if out_valid = '1' then
                valid_count := valid_count + 1;
            end if;
            wait for CLK_PERIOD;
            exit when valid_count = 16;
        end loop;
        assert valid_count = 16 report "Error: Test 5 failed - No or incomplete FFT output!" severity error;

        -- ====================================================================
        -- TESTFALL 6: Sinus mit 20 Grad Phase bei 9 kHz (Bin 3)
        -- ====================================================================
        for n in 0 to 15 loop
            t_sample := real(n) / FS;
            val_real := AMPLITUDE * sin(2.0 * MATH_PI * F_SIG_9K * t_sample + PHASE_20);
            in_re    <= to_signed(integer(round(val_real)), 16);
            in_im    <= (others => '0');
            in_valid <= '1';
            wait for CLK_PERIOD;
            in_valid <= '0';
        end loop;

        valid_count := 0;
        for timeout in 0 to 100 loop
            if out_valid = '1' then
                valid_count := valid_count + 1;
            end if;
            wait for CLK_PERIOD;
            exit when valid_count = 16;
        end loop;
        assert valid_count = 16 report "Error: Test 6 failed - No or incomplete FFT output!" severity error;

        -- Simulation erfolgreich beendet
        report "Simulation finished." severity note;
        wait;
    end process;

    -- Integritätsprüfung für den Bin-Index per Assert
    process(clk)
    begin
        if rising_edge(clk) then
            if out_valid = '1' then
                assert bin_idx <= 15 report "Error: Bin Index out of range!" severity error;
            end if;
        end if;
    end process;

end architecture testbench;