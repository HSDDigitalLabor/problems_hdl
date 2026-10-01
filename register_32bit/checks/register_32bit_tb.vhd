library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_32bit_tb is
end entity register_32bit_tb;

architecture testbench of register_32bit_tb is
    -- Component declaration
    component register_32bit is
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            data_in   : in  std_logic_vector(31 downto 0);
            data_out  : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Signals
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '0';
    signal data_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal data_out : std_logic_vector(31 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

begin
    -- Component instantiation
    dut : register_32bit port map (
        clk      => clk,
        reset    => reset,
        data_in  => data_in,
        data_out => data_out
    );

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- Testbench process
    process
    begin
        -- Test 1: Reset
        report "Test 1: Reset" severity note;
        data_in <= x"DEADBEEF";
        reset <= '0';
        wait for CLK_PERIOD;
        reset <= '1';
        wait for 1 ns;
        assert data_out = x"00000000" report "Reset failed!" severity error;

        -- Test 2: Write and read 0xBAADC0FE
        report "Test 2: Write and read 0xBAADC0FE" severity note;
        data_in <= x"BAADC0FE";
        wait for CLK_PERIOD;
        assert data_out = x"BAADC0FE" report "Write/Read 0xBAADC0FE failed!" severity error;

        -- Test 3: Write and read 0x00000000
        report "Test 3: Write and read 0x00000000" severity note;
        data_in <= x"00000000";
        wait for CLK_PERIOD;
        assert data_out = x"00000000" report "Write/Read 0x00000000 failed!" severity error;

        -- Test 4: Write and read 0xFFFFFFFF
        report "Test 4: Write and read 0xFFFFFFFF" severity note;
        data_in <= x"FFFFFFFF";
        wait for CLK_PERIOD;
        assert data_out = x"FFFFFFFF" report "Write/Read 0xFFFFFFFF failed!" severity error;

        -- Test 5: Write and read 0xA5A5A5A5
        report "Test 5: Write and read 0xA5A5A5A5" severity note;
        data_in <= x"A5A5A5A5";
        wait for CLK_PERIOD;
        assert data_out = x"A5A5A5A5" report "Write/Read 0xA5A5A5A5 failed!" severity error;

        -- Test 6: Reset with data in register
        report "Test 6: Reset with data in register" severity note;
        reset <= '0';
        wait for 1 ns;
        assert data_out = x"00000000" report "Reset with data failed!" severity error;
        wait for CLK_PERIOD;
        reset <= '1';

        -- End simulation
        report "Simulation finished." severity note;
        wait;
    end process;

end architecture testbench;