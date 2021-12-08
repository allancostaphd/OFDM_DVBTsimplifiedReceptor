library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity divider is
    Generic (N : integer := 10;
	          M : integer := 10);
    Port ( dividend  : in   signed (N-1 downto 0);
           divisor   : in   signed (M-1 downto 0);
			  valid     : in   std_logic;
           quotient  : out  signed (N-1 downto 0);
           remainder : out  signed (M-1 downto 0);
			  out_valid : out  std_logic;
			  busy      : out  std_logic;
			  err       : out  std_logic;
			  rst       : in   std_logic;
			  clk       : in   std_logic
			  );
end divider;

architecture Behavioral of divider is

  signal sign_A, n_sign_A, sign_B, n_sign_B: std_logic;
  signal A, n_A: unsigned(N-1 downto 0);
  signal B, n_B: unsigned(M-1 downto 0);
  signal step, n_step: integer range 0 to N-1;
  signal Q, n_Q: unsigned(N-1 downto 0);
  signal R, n_R: unsigned(M-1 downto 0);

  type t_state is (idle, divide, adjust_sign, error_state);
  signal state, n_state: t_state;


begin

  sync: process(rst, clk)
  begin
    if rst = '1' then
	   state <= idle;
		step  <= N-1;
		sign_A <= '0';
		sign_B <= '0';
		A <= (others => '0');
		B <= (others => '0');
		Q <= (others => '0');
		R <= (others => '0');
	 elsif rising_edge(clk) then
	   state <= n_state;
		step  <= n_step;
		sign_A <= n_sign_A;
		sign_B <= n_sign_B;
		A <= n_A;
		B <= n_B;
		Q <= n_Q;
		R <= n_R;
	 end if;
  end process;
  
  busy <= '0' when state = idle else '1';
  
  comb: process(state, A, B, sign_A, sign_B, dividend, divisor, Q, R, step, valid)
  begin
    -- Default values:
	 n_A <= A;
	 n_B <= B;
    n_sign_A <= sign_A;
	 n_sign_B <= sign_B;
	 n_Q <= Q;
	 n_R <= R;
    n_state <= state;
	 n_step  <= step;
	 
	 quotient <= (others => '0');
	 remainder <= (others => '0');
	 err <= '0';
	 out_valid <= '0';
    case state is
	   when idle =>
		  -- Set everything to initial values
		  n_Q <= (others => '0');
		  n_R <= (others => '0');
		  n_step <= N-1;
		  if valid = '1' then
		    n_state <= divide;
			 -- Store operand sign for later
			 n_sign_A <= dividend(N-1);
			 n_sign_B <= divisor(M-1);
			 -- If operands are negative, store their absolute value
			 -- since we perform an unsigned division and later adjust the
			 -- sign of the result
			 if dividend(N-1) = '1' then
			   n_A <= unsigned(NOT std_logic_vector(dividend)) + 1;
			 else
			   n_A <= unsigned(std_logic_vector(dividend));
			 end if;
			 if divisor(M-1) = '1' then
			   n_B <= unsigned(NOT std_logic_vector(divisor)) + 1;
			 else
			   n_B <= unsigned(std_logic_vector(divisor));
		    end if;
			 -- If divisor is zero, raise an error
			 if (divisor = 0) then
			   n_state <= error_state;
			 end if;
		  end if;
		when divide =>
		  -- Algorithm from https://en.wikipedia.org/wiki/Division_algorithm#Integer_division_(unsigned)_with_remainder
		  n_R <= R sll 1;  -- Shift 1 bit left
		  n_R(0) <= A(step);
		  -- if (n_R >= B), but we shouldn't read n_R here so calculate it again
		  if (R(M-2 downto 0) & A(step)) >= B then
		    n_R <= (R(M-2 downto 0) & A(step))-B;
			 n_Q(step) <= '1';
		  end if;
		  if step = 0 then  -- Exit after the last step
		    n_state <= adjust_sign;
		  else
		    n_step <= step - 1;
		  end if;
		when adjust_sign =>
		  -- Negate the result (quotient) if one (and only one) of the signs was negative
		  if (sign_A XOR sign_B) = '0' then
		    -- No adjustment needed
			 quotient <= signed(std_logic_vector(Q));
		  else
		    -- Negate result
			 quotient <= signed(NOT std_logic_vector(Q))+1;
		  end if;
                  -- The remainder has the sign of the dividend, negate if dividend is negative
                  if (sign_A = '0') then
		    remainder <= signed(std_logic_vector(R));
                  else
                    remainder <= signed(NOT std_logic_vector(R))+1;
                  end if;
		  -- Output is now valid
		  out_valid <='1';
		  n_state <= idle;
		when error_state =>
		  err <= '1';
		  n_state <= idle;
		when others =>
		  n_state <= error_state;
		end case;
  end process;
  
-- Firewall assertions:
-- 1) Fail if valid = '1' while state is not idle
-- 2) Fail if division by zero is attempted
  firewall_assertions: process(clk)
  begin
    if falling_edge(clk) then
	   if valid = '1' and state /= idle then
		  report "divider: valid asserted while busy, expect data loss"
		  severity failure;
		end if;
		if state = error_state then
		  report "divider: tried to divide by zero"
		  severity failure;
		end if;
	 end if;
  end process; 

end Behavioral;

