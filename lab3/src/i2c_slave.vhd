-- ============================================================================
-- Файл    : i2c_slave.vhd
-- Модуль  : i2c_slave — I2C Slave (приймач Rx для перевірки Master)
-- Мова    : VHDL-2008
-- Опис    : Slave з однією 8-бітною регістровою коміркою reg_o.
--           Запис (R/W='0')  : байт від Master зберігається у reg_o.
--           Читання (R/W='1'): Slave видає вміст reg_o, Master відповідає NACK.
--
-- Принцип роботи (приймач Rx):
--   * Slave не має власного тактового сигналу шини: він працює від системного
--     clk і відстежує лінії SCL/SDA, які асинхронні відносно clk. Тому вони
--     спершу проходять через 2-тригерний синхронізатор (захист від
--     метастабільності).
--   * Умови START/STOP розпізнаються за зміною SDA при SCL='1'.
--   * Біт даних читається на фронті SCL вгору (SDA стабільна).
--   * Slave змінює SDA лише на фронті SCL вниз (коли SCL='0'), щоб не
--     створити хибних START/STOP.
--   * Для ACK Slave притискає SDA до '0' на 9-му такті.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_slave is
  generic (
    SLAVE_ADDR : std_logic_vector(6 downto 0) := "1010000"  -- адреса пристрою (0x50)
  );
  port (
    clk   : in    std_logic;                     -- системний тактовий сигнал
    rst   : in    std_logic;                     -- синхронне скидання, активний '1'
    scl   : in    std_logic;                     -- лінія SCL (формує Master), тільки вхід
    sda   : inout std_logic;                     -- лінія SDA (відкритий стік)
    reg_o : out   std_logic_vector(7 downto 0)   -- вміст регістра (для спостереження)
  );
end entity i2c_slave;

architecture rtl of i2c_slave is

  -- Стани FSM Slave:
  --   S_IDLE     — очікування START
  --   S_ADDR     — прийом 8 біт (7 біт адреси + R/W)
  --   S_ADDR_ACK — видано ACK на адресу (чекаємо кінця 9-го такту)
  --   S_WR_DATA  — прийом байта даних від Master
  --   S_WR_ACK   — видано ACK на отримані дані
  --   S_RD_DATA  — видача байта даних Master-у (біт за бітом)
  --   S_RD_ACK   — слот ACK/NACK від Master після прочитаного байта
  type state_t is (S_IDLE, S_ADDR, S_ADDR_ACK, S_WR_DATA, S_WR_ACK, S_RD_DATA, S_RD_ACK);
  signal state : state_t := S_IDLE;

  signal scl_s, scl_d : std_logic := '1';   -- синхронізований SCL та його попереднє значення
  signal sda_s, sda_d : std_logic := '1';   -- синхронізований SDA та його попереднє значення
  signal sda_low      : std_logic := '0';   -- '1' = Slave притискає SDA до '0'
  signal cnt          : integer range 0 to 8 := 0;           -- лічильник біт у байті
  signal shreg        : std_logic_vector(7 downto 0) := (others => '0'); -- приймальний регістр
  signal reg_q        : std_logic_vector(7 downto 0) := x"00";           -- регістр даних Slave
  signal rw_r         : std_logic := '0';   -- прийнятий біт R/W

begin

  -- Вихід з відкритим стоком: '0' або високий імпеданс
  sda   <= '0' when sda_low = '1' else 'Z';
  reg_o <= reg_q;

  process (clk)
    -- Ознаки подій, обчислюються щотакту за синхронізованими сигналами
    variable scl_rise, scl_fall, start_det, stop_det : boolean;
  begin
    if rising_edge(clk) then
      -- 2-тригерний синхронізатор вхідних ліній: *_s — поточне значення,
      -- *_d — значення на попередньому такті (для виявлення фронтів)
      scl_s <= to_x01(scl);  scl_d <= scl_s;
      sda_s <= to_x01(sda);  sda_d <= sda_s;

      scl_rise  := (scl_d = '0' and scl_s = '1');                  -- фронт SCL вгору
      scl_fall  := (scl_d = '1' and scl_s = '0');                  -- фронт SCL вниз
      start_det := (sda_d = '1' and sda_s = '0' and scl_s = '1');  -- SDA падає при SCL=1
      stop_det  := (sda_d = '0' and sda_s = '1' and scl_s = '1');  -- SDA зростає при SCL=1

      if rst = '1' then
        state   <= S_IDLE;
        sda_low <= '0';
        cnt     <= 0;
        reg_q   <= x"00";
      elsif start_det then
        state   <= S_ADDR;                -- (повторний) START: починаємо прийом адреси
        cnt     <= 0;
        sda_low <= '0';
      elsif stop_det then
        state   <= S_IDLE;                -- STOP: транзакція завершена
        sda_low <= '0';
      else

        -- Фронт SCL вгору: Master виставив стабільний біт на SDA — вибірка
        if scl_rise then
          case state is
            when S_ADDR | S_WR_DATA =>
              shreg <= shreg(6 downto 0) & sda_s;  -- зсув: новий біт заходить справа
              cnt   <= cnt + 1;
            when S_RD_DATA =>
              cnt   <= cnt + 1;           -- рахуємо біти, які прочитав Master
            when others => null;
          end case;
        end if;

        -- Фронт SCL вниз: SCL='0', безпечно змінювати SDA
        if scl_fall then
          case state is
            when S_ADDR =>
              if cnt = 8 then               -- 8 біт прийнято (адреса + R/W)
                if shreg(7 downto 1) = SLAVE_ADDR then
                  rw_r    <= shreg(0);      -- запам'ятовуємо напрямок передачі
                  sda_low <= '1';           -- ACK: притискаємо SDA до '0'
                  state   <= S_ADDR_ACK;
                else
                  state   <= S_IDLE;        -- чужа адреса: ігноруємо, SDA не чіпаємо (NACK)
                end if;
              end if;

            when S_ADDR_ACK =>              -- 9-й такт (ACK) завершився
              cnt <= 0;
              if rw_r = '1' then            -- Master читає: виставляємо перший біт даних
                sda_low <= not reg_q(7);
                state   <= S_RD_DATA;
              else                          -- Master пише: відпускаємо SDA, чекаємо дані
                sda_low <= '0';
                state   <= S_WR_DATA;
              end if;

            when S_WR_DATA =>
              if cnt = 8 then               -- байт даних отримано повністю
                reg_q   <= shreg;           -- зберігаємо отриманий байт у регістр
                sda_low <= '1';             -- ACK
                state   <= S_WR_ACK;
              end if;

            when S_WR_ACK =>                -- 9-й такт (ACK) завершився
              sda_low <= '0';               -- відпускаємо SDA
              state   <= S_IDLE;            -- чекаємо STOP від Master

            when S_RD_DATA =>
              if cnt = 8 then               -- усі 8 біт видано
                sda_low <= '0';             -- відпускаємо SDA для ACK/NACK Master-а
                state   <= S_RD_ACK;
              else
                sda_low <= not reg_q(7 - cnt);  -- наступний біт (старший першим)
              end if;

            when S_RD_ACK =>
              sda_low <= '0';
              state   <= S_IDLE;            -- чекаємо STOP

            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;