----------------------------------------------------------------
--
--
--			Autor: Pablo Linares Serrano
--
--			Fecha: 13/6/2020
--
--			Descripcion: Bloque que genera la secuencia PRBS. 
--						mas simple que el mecanismo de un chupete.
--
--
--
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity prbs is
    Port ( clk 		: in  STD_LOGIC;
			rst 	: in  STD_LOGIC;
			enable 	: in  STD_LOGIC;
			salida	: out  STD_LOGIC);
end prbs;
architecture Behavioral of prbs is

signal vector 	: STD_LOGIC_VECTOR (10 downto 0);
signal pvector 	: STD_LOGIC_VECTOR (10 downto 0);

begin
	-- La salida sera el ultimo bit del registro
	-- La salida esta registrada, se podrá leer al siguiente flanco de 
	-- subida del reloj de cuando se activo enable'.
	salida <= vector(10);
	
	sinc: process (clk, rst)
	begin
		
		if rising_edge (clk) then
			if rst = '1' then
			-- al hacer reset el valor del registro es todo 1
				vector <= (others => '1');
			else
				vector <= pvector;
			end if;
		end if;
	end process;
	
	comb: process (vector, enable)
	begin
		pvector <= vector;
		
		if enable = '1' then
			pvector(10 downto 1) <= vector(9 downto 0);
			-- El nuevo elemento se obtiene de las posiciones 8 y 10 (ultima)
			pvector(0) <= vector(8) xor vector(10);
		end if;
	end process;

end architecture;