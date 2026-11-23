-- ============================================================================
-- Файл    : tb_i2c.vhd
-- Модуль  : tb_i2c — Testbench для i2c_master та i2c_slave
-- Мова    : VHDL-2008
-- Тести   : 1) запис 0xA5 у Slave (адреса 0x50), перевірка ACK та регістра;
--           2) читання байта назад, порівняння з 0xA5;
--           3) запис 0x3C і читання назад;
--           4) звернення до неіснуючої адреси 0x51 -> очікуємо NACK (ack_err='1').
-- Структура: Master (DUT) і Slave (модель сусіднього пристрою) з'єднані двома
--           лініями SCL/SDA з підтяжкою 'H'. Тест самоперевірний: результати
--           порівнюються через assert, при розбіжності виводиться помилка.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i2c is
end entity tb_i2c;

architecture sim of tb_i2c is

  -- Параметри тесту (масштабовані для швидкої симуляції)
  -- Для швидкої симуляції: clk = 8 МГц, SCL = 400 кГц (Fast mode, DIV = 5)
  constant CLK_FREQ   : positive := 8_000_000;
  constant I2C_FREQ   : positive := 400_000;
  constant CLK_PERIOD : time := 125 ns;

  -- Сигнали тестового середовища (з'єднують Master, Slave і сценарій)
  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal start    : std_logic := '0';
  signal rw       : std_logic := '0';
  signal addr     : std_logic_vector(6 downto 0) := (others => '0');
  signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
  signal data_out : std_logic_vector(7 downto 0);
  signal busy     : std_logic;
  signal done     : std_logic;
  signal ack_err  : std_logic;
  signal scl      : std_logic;
  signal sda      : std_logic;
  signal slave_reg: std_logic_vector(7 downto 0);  -- вміст регістра Slave (для перевірки)

  -- Процедура: виконати одну I2C-транзакцію і дочекатися її завершення.
  -- Подає параметри (адреса, R/W, дані), формує імпульс start на 1 такт
  -- і чекає імпульс done від Master.
  procedure transaction (
    signal start_s : out std_logic;
    signal rw_s    : out std_logic;
    signal addr_s  : out std_logic_vector(6 downto 0);
    signal din_s   : out std_logic_vector(7 downto 0);
    signal done_s  : in  std_logic;
    constant a     : in  std_logic_vector(6 downto 0);
    constant r     : in  std_logic;
    constant d     : in  std_logic_vector(7 downto 0)) is
  begin
    wait until rising_edge(clk);           -- синхронізація з фронтом clk
    addr_s  <= a;
    rw_s    <= r;
    din_s   <= d;
    start_s <= '1';                        -- імпульс запуску
    wait until rising_edge(clk);
    start_s <= '0';
    wait until done_s = '1';               -- чекаємо завершення (після STOP)
    wait until rising_edge(clk);           -- даємо сигналам встановитися
  end procedure;

begin

  -- Підтягувальні резистори шини I2C (логічна '1' при відпущених лініях)
  scl <= 'H';
  sda <= 'H';

  -- Генератор тактового сигналу (скважність 50 %)
  clk <= not clk after CLK_PERIOD / 2;

  -- Перевіряється Master
  u_master : entity work.i2c_master
    generic map (CLK_FREQ => CLK_FREQ, I2C_FREQ => I2C_FREQ)
    port map (clk => clk, rst => rst, start => start, rw => rw, addr => addr,
              data_in => data_in, data_out => data_out, busy => busy,
              done => done, ack_err => ack_err, scl => scl, sda => sda);

  -- Slave імітує "інший пристрій" на шині
  u_slave : entity work.i2c_slave
    generic map (SLAVE_ADDR => "1010000")
    port map (clk => clk, rst => rst, scl => scl, sda => sda, reg_o => slave_reg);

  -- Сценарій тесту: послідовність транзакцій і перевірка результатів
  stim : process
  begin
    -- Початкове скидання обох модулів
    rst <= '1';
    wait for 5 * CLK_PERIOD;
    rst <= '0';
    wait for 10 * CLK_PERIOD;

    -- Тест 1: запис 0xA5 за адресою 0x50
    report "Test 1: write 0xA5 to 0x50";
    transaction(start, rw, addr, data_in, done, "1010000", '0', x"A5");
    assert ack_err = '0' report "T1: unexpected NACK" severity error;
    assert slave_reg = x"A5" report "T1: slave register mismatch" severity error;

    wait for 20 * CLK_PERIOD;   -- пауза між транзакціями

    -- Тест 2: читання з адреси 0x50
    report "Test 2: read from 0x50";
    transaction(start, rw, addr, data_in, done, "1010000", '1', x"00");
    assert ack_err = '0' report "T2: unexpected NACK" severity error;
    assert data_out = x"A5" report "T2: read data mismatch" severity error;

    wait for 20 * CLK_PERIOD;

    -- Тест 3: запис 0x3C та читання назад
    report "Test 3: write 0x3C then read back";
    transaction(start, rw, addr, data_in, done, "1010000", '0', x"3C");
    assert slave_reg = x"3C" report "T3: slave register mismatch" severity error;
    wait for 20 * CLK_PERIOD;
    transaction(start, rw, addr, data_in, done, "1010000", '1', x"00");
    assert data_out = x"3C" report "T3: read data mismatch" severity error;

    wait for 20 * CLK_PERIOD;

    -- Тест 4: неіснуюча адреса 0x51 -> NACK
    report "Test 4: wrong address 0x51 -> NACK expected";
    transaction(start, rw, addr, data_in, done, "1010001", '0', x"FF");
    assert ack_err = '1' report "T4: NACK was expected" severity error;
    assert slave_reg = x"3C" report "T4: register must not change" severity error;

    wait for 20 * CLK_PERIOD;
    -- Усі перевірки пройдені (інакше вище було б виведено severity error)
    report "ALL TESTS FINISHED";
    std.env.finish;             -- зупинка симуляції
  end process;

end architecture sim;