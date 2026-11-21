-- ============================================================================
-- Файл    : i2c_master.vhd
-- Модуль  : i2c_master — I2C Master (передавач Tx + приймач Rx даних)
-- Мова    : VHDL-2008
-- Опис    : Виконує одну транзакцію на кожен імпульс start:
--             START -> [ADDR(7) + R/W] -> ACK -> [DATA(8)] -> ACK/NACK -> STOP
--           R/W = '0' : запис байта data_in у Slave (Master передає, Tx)
--           R/W = '1' : читання байта зі Slave у data_out (Master приймає, Rx)
--
-- Принцип роботи шини I2C:
--   * Дві лінії: SCL (тактування, її формує Master) і SDA (дані, двонапрямлена).
--   * Обидві лінії з ВІДКРИТИМ СТОКОМ: пристрій може лише притиснути лінію
--     до '0' або відпустити її (високий імпеданс 'Z'). Логічну '1' створює
--     зовнішній підтягувальний резистор. Тому на шині не буває короткого
--     замикання, навіть якщо два пристрої керують лінією одночасно.
--   * Дані на SDA змінюються ТІЛЬКИ коли SCL = '0'; приймач читає SDA,
--     коли SCL = '1'.
--   * Виняток — службові умови: START (SDA падає при SCL='1') та
--     STOP (SDA зростає при SCL='1').
--   * Після кожних 8 біт приймач на 9-му такті відповідає ACK ('0') або
--     NACK ('1').
--
-- Тактування: кожен біт SCL поділено на 4 фази (ph = 0..3). Лічильник-дільник
-- формує імпульс tick кожні DIV тактів clk, тобто чверть періоду SCL.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
  generic (
    CLK_FREQ : positive := 50_000_000;  -- частота системного тактового сигналу, Гц
    I2C_FREQ : positive := 100_000      -- частота шини SCL, Гц (Standard mode)
  );
  port (
    clk      : in    std_logic;                     -- системний тактовий сигнал
    rst      : in    std_logic;                     -- синхронне скидання, активний '1'
    start    : in    std_logic;                     -- імпульс запуску транзакції (1 такт)
    rw       : in    std_logic;                     -- '0' = запис, '1' = читання
    addr     : in    std_logic_vector(6 downto 0);  -- 7-бітна адреса Slave
    data_in  : in    std_logic_vector(7 downto 0);  -- байт для запису
    data_out : out   std_logic_vector(7 downto 0);  -- прийнятий байт (оновлюється після читання)
    busy     : out   std_logic;                     -- '1' поки триває транзакція
    done     : out   std_logic;                     -- імпульс завершення транзакції (1 такт)
    ack_err  : out   std_logic;                     -- '1' якщо Slave не відповів ACK
    scl      : inout std_logic;                     -- лінія тактування I2C
    sda      : inout std_logic                      -- лінія даних I2C
  );
end entity i2c_master;

architecture rtl of i2c_master is

  -- Чверть періоду SCL у тактах clk. Приклад: 50 МГц / (100 кГц * 4) = 125.
  -- Чотири tick = один період SCL = один біт даних.
  constant DIV : positive := CLK_FREQ / (I2C_FREQ * 4);

  -- Стани скінченного автомата (FSM) Master:
  --   S_IDLE     — очікування команди start, лінії відпущені (шина вільна)
  --   S_START    — формування умови START
  --   S_ADDR     — передача 8 біт: 7 біт адреси + біт R/W
  --   S_ADDR_ACK — прийом ACK/NACK від Slave після адреси
  --   S_WR_DATA  — передача 8 біт даних (режим запису)
  --   S_WR_ACK   — прийом ACK/NACK від Slave після даних
  --   S_RD_DATA  — прийом 8 біт даних від Slave (режим читання)
  --   S_RD_NACK  — Master відповідає NACK (єдиний байт прочитано)
  --   S_STOP     — формування умови STOP, повернення в IDLE
  type state_t is (S_IDLE, S_START, S_ADDR, S_ADDR_ACK,
                   S_WR_DATA, S_WR_ACK, S_RD_DATA, S_RD_NACK, S_STOP);
  signal state : state_t := S_IDLE;

  signal divcnt  : integer range 0 to DIV - 1 := 0;  -- лічильник дільника частоти
  signal tick    : std_logic := '0';                 -- імпульс "чверть періоду SCL"
  signal ph      : integer range 0 to 3 := 0;        -- номер фази поточного біта (0..3)
  signal bitcnt  : integer range 0 to 8 := 0;        -- кількість вже оброблених біт байта
  signal shreg   : std_logic_vector(7 downto 0) := (others => '0'); -- зсувний регістр (Tx/Rx)
  signal data_r  : std_logic_vector(7 downto 0) := (others => '0'); -- зафіксована копія data_in
  signal rw_r    : std_logic := '0';                 -- зафіксована копія rw
  signal scl_low : std_logic := '0';                 -- '1' = притиснути SCL до '0'
  signal sda_low : std_logic := '0';                 -- '1' = притиснути SDA до '0'
  signal err_r   : std_logic := '0';                 -- прапорець помилки (NACK від Slave)
  signal rx_r    : std_logic_vector(7 downto 0) := (others => '0'); -- прийнятий байт

begin

  -- Вихід з відкритим стоком: або активний '0', або високий імпеданс 'Z'.
  -- Значення '1' на лінію ніколи не подається — його дає підтяжка.
  scl <= '0' when scl_low = '1' else 'Z';
  sda <= '0' when sda_low = '1' else 'Z';

  -- Допоміжні вихідні сигнали
  busy     <= '0' when state = S_IDLE else '1';
  ack_err  <= err_r;
  data_out <= rx_r;

  -- --------------------------------------------------------------------------
  -- Генератор імпульсів tick.
  -- Поза станом IDLE рахує DIV тактів clk і видає 1-тактовий імпульс tick.
  -- В IDLE (або при rst) лічильник обнуляється, щоб кожна транзакція
  -- починалася з однаковою фазою.
  -- --------------------------------------------------------------------------
  p_tick : process (clk)
  begin
    if rising_edge(clk) then
      if state = S_IDLE or rst = '1' then
        divcnt <= 0;
        tick   <= '0';
      elsif divcnt = DIV - 1 then
        divcnt <= 0;
        tick   <= '1';             -- минула чверть періоду SCL
      else
        divcnt <= divcnt + 1;
        tick   <= '0';
      end if;
    end if;
  end process p_tick;

  -- --------------------------------------------------------------------------
  -- Основний скінченний автомат (FSM).
  -- Стан змінюється лише по tick (у всіх станах крім IDLE), тому кожна
  -- ph-фаза триває рівно чверть періоду SCL.
  -- --------------------------------------------------------------------------
  p_fsm : process (clk)
  begin
    if rising_edge(clk) then
      done <= '0';                 -- done — імпульс на 1 такт, за замовчуванням '0'
      if rst = '1' then
        -- Синхронне скидання: відпускаємо обидві лінії, скидаємо лічильники
        state   <= S_IDLE;
        scl_low <= '0';
        sda_low <= '0';
        err_r   <= '0';
        ph      <= 0;
        bitcnt  <= 0;
      else
        case state is

          -- IDLE: шина вільна (SCL=SDA='1'), чекаємо імпульс start.
          -- Фіксуємо вхідні параметри, щоб вони могли змінитись під час передачі.
          when S_IDLE =>
            scl_low <= '0';
            sda_low <= '0';
            if start = '1' then
              shreg  <= addr & rw;       -- 7 біт адреси + біт R/W (старший біт першим)
              data_r <= data_in;         -- байт для запису
              rw_r   <= rw;
              err_r  <= '0';             -- очищаємо помилку попередньої транзакції
              ph     <= 0;
              bitcnt <= 0;
              state  <= S_START;
            end if;

          when others =>
            if tick = '1' then         -- далі працюємо тільки по імпульсу tick
              case state is

                -- START: перехід SDA 1->0 при SCL='1'.
                --   ph0: лінії вільні (обидві '1')
                --   ph1: SDA -> '0' при SCL='1'  (це і є умова START)
                --   ph2: пауза
                --   ph3: SCL -> '0', готуємось до передачі першого біта
                when S_START =>
                  case ph is
                    when 0 => scl_low <= '0'; sda_low <= '0'; ph <= 1;
                    when 1 => sda_low <= '1';                 ph <= 2;
                    when 2 =>                                 ph <= 3;
                    when 3 => scl_low <= '1'; ph <= 0; bitcnt <= 0; state <= S_ADDR;
                  end case;

                -- Передача 8 біт (адреса+R/W або дані), старший біт першим.
                --   ph0: при SCL='0' виставляємо черговий біт на SDA
                --        (sda_low = not біт, бо '0' = притиснути, '1' = відпустити)
                --   ph1: SCL -> '1' (Slave читає SDA)
                --   ph2: SCL тримається високо
                --   ph3: SCL -> '0', зсуваємо регістр; після 8-го біта
                --        переходимо до слоту ACK
                when S_ADDR | S_WR_DATA =>
                  case ph is
                    when 0 => scl_low <= '1'; sda_low <= not shreg(7); ph <= 1;
                    when 1 => scl_low <= '0';                          ph <= 2;
                    when 2 =>                                          ph <= 3;
                    when 3 =>
                      scl_low <= '1';
                      shreg   <= shreg(6 downto 0) & '0';  -- зсув вліво
                      ph      <= 0;
                      if bitcnt = 7 then                   -- передано 8 біт
                        bitcnt <= 0;
                        if state = S_ADDR then state <= S_ADDR_ACK;
                        else                   state <= S_WR_ACK;
                        end if;
                      else
                        bitcnt <= bitcnt + 1;
                      end if;
                  end case;

                -- Слот ACK від Slave: Master відпускає SDA і читає її при SCL='1'.
                --   SDA='0' -> ACK (Slave підтвердив); SDA='1' -> NACK (помилка)
                when S_ADDR_ACK | S_WR_ACK =>
                  case ph is
                    when 0 => scl_low <= '1'; sda_low <= '0'; ph <= 1;  -- відпустити SDA
                    when 1 => scl_low <= '0';                 ph <= 2;
                    when 2 =>
                      if to_x01(sda) = '1' then err_r <= '1'; end if;  -- NACK -> помилка
                      ph <= 3;
                    when 3 =>
                      scl_low <= '1'; ph <= 0;
                      if state = S_ADDR_ACK then
                        if err_r = '1' then
                          state <= S_STOP;           -- адреса не підтверджена: завершуємо
                        elsif rw_r = '1' then
                          shreg <= (others => '0'); bitcnt <= 0; state <= S_RD_DATA;
                        else
                          shreg <= data_r;          bitcnt <= 0; state <= S_WR_DATA;
                        end if;
                      else
                        state <= S_STOP;             -- після даних завжди STOP
                      end if;
                  end case;

                -- Прийом 8 біт від Slave: Master відпускає SDA, Slave її формує.
                --   ph2 (SCL='1'): вибірка SDA у зсувний регістр
                when S_RD_DATA =>
                  case ph is
                    when 0 => scl_low <= '1'; sda_low <= '0'; ph <= 1;
                    when 1 => scl_low <= '0';                 ph <= 2;
                    when 2 =>
                      shreg <= shreg(6 downto 0) & to_x01(sda);  -- вибірка SDA
                      ph    <= 3;
                    when 3 =>
                      scl_low <= '1'; ph <= 0;
                      if bitcnt = 7 then                     -- прийнято 8 біт
                        bitcnt <= 0; rx_r <= shreg; state <= S_RD_NACK;
                      else
                        bitcnt <= bitcnt + 1;
                      end if;
                  end case;

                -- Master відповідає NACK (SDA відпущена = '1'): повідомляє Slave,
                -- що більше байтів не потрібно (читаємо лише один байт).
                when S_RD_NACK =>
                  case ph is
                    when 0 => scl_low <= '1'; sda_low <= '0'; ph <= 1;  -- SDA='1' = NACK
                    when 1 => scl_low <= '0';                 ph <= 2;
                    when 2 =>                                 ph <= 3;
                    when 3 => scl_low <= '1'; ph <= 0; state <= S_STOP;
                  end case;

                -- STOP: перехід SDA 0->1 при SCL='1'.
                --   ph0: SDA притиснута до '0' (SCL='0')
                --   ph1: SCL -> '1'
                --   ph2: SDA відпускається -> '1' при SCL='1'  (умова STOP)
                --   ph3: шина вільна, видаємо імпульс done, повертаємось в IDLE
                when S_STOP =>
                  case ph is
                    when 0 => scl_low <= '1'; sda_low <= '1'; ph <= 1;
                    when 1 => scl_low <= '0';                 ph <= 2;
                    when 2 => sda_low <= '0';                 ph <= 3;
                    when 3 => ph <= 0; done <= '1'; state <= S_IDLE;
                  end case;

                when others => state <= S_IDLE;   -- захист від невизначеного стану
              end case;
            end if;
        end case;
      end if;
    end if;
  end process p_fsm;

end architecture rtl;