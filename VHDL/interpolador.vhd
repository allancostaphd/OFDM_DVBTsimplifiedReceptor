----------------------------------------------------------------------------------
--
--
--		Autor: Pablo Linares Serrano 
--		Fecha: 11/6/2020
--
--		Descripcion: Bloque interpolador de 11 puntos
--
--		Estado: Listo.
--
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.myPack.all;
use IEEE.NUMERIC_STD.ALL;



entity Interpolador is
generic (
		-- tamanio de los datos y direcciones que vamos a usar
		DATA_WIDTH 	: integer := 20;
		ADDR_WIDTH 	: integer := 13;
		-- tamanio de los datos y direcciones: potencia de 2
		DATA_WIDTH2	: integer := 32; 
		ADDR_WIDTH2	: integer := 16
	);
    Port ( clk 			: in  STD_LOGIC;
			rst 		: in  STD_LOGIC;
			inf 		: in  complex10;
			sup 		: in  complex10;
			okDato		: in  STD_LOGIC;
			valid 		: in  STD_LOGIC;
			okInterpolF	: out std_logic;
			okInterpolB	: out std_logic;
			estim 		: out complex10;
			pos 		: out unsigned (ADDR_WIDTH-1 downto 0));
end Interpolador;

architecture Behavioral of Interpolador is

type estados is (espera, activo);
type DATA is array (1 to 11) of signed (9 downto 0);

constant pesos : DATA := ("0000101011", "0001010101", "0010000000", "0010101011",
									"0011010101", "0100000000", "0100101011", "0101010101", 
									"0110000000", "0110101011", "0111010101");

signal cont 	: integer range 0 to 11;
signal pcont 	: integer range 0 to 12;
signal estado	: estados;
signal pestado	: estados;
signal dif		: complex10;
signal tmpi		: signed (19 downto 0);
signal tmpr		: signed (19 downto 0);
signal restoR 	: signed (9 downto 0);
signal restoI 	: signed (9 downto 0);

-- Senial que almacena si ha llegado un dato valido
signal bandera	: std_logic;
signal pbandera	: std_logic;

begin
-- Asignaciones estaticas
dif.re 	<= sup.re - inf.re;
dif.im 	<= sup.im - inf.im;
--estim_valid <= estim_valid2;
pos 	<= to_unsigned(cont, ADDR_WIDTH);

sinc: process (clk, rst)
begin
	if rst = '1' then
		cont 	<= 0;
		estado	<= espera;
	elsif rising_edge(clk) then
		estado	<= pestado;
		cont	<= pcont;
		bandera	<= pbandera;
	end if;
end process;

comb: process (estado, cont, tmpi, tmpr, bandera, valid, inf, sup, dif, okDato, restoR, restoI, pcont)
begin


	pestado			<= estado;
	tmpi			<= (others => '0');
	tmpr			<= (others => '0');
	pcont			<= cont;
	pbandera		<= '0';
	estim.re 		<= (others => '0');
	estim.im 		<= (others => '0');
	restoR 			<= (others => '0');
	restoI 			<= (others => '0');
	okInterpolF 	<= '0';
	okInterpolB		<= '0';


	case estado is

		when espera =>
			pcont <= 0;
			if not(pcont = cont) then
				okInterpolB <= '1';
			end if ;
			if  bandera = '1' or valid = '1' then
				if okDato = '1' then
				-- Cuando el divisor da el visto bueno, se da el visto 
				-- bueno a la maquina de estados del top para que actualice 
				-- su contador.
					okInterpolF <= '1';				
					pcont 	<= cont +1;
				end if ;
				pbandera <= '1';
				estim 	 <= inf;
				pestado <= activo;
			end if;
		
		when activo =>
			
			okInterpolF <= '1';	
			if not(pcont = cont) then
			-- cuando se va a cambiar el valor del contador
			-- se le da el visto bueno a la maquina de estados
			-- del top para que haga lo mismo.
				okInterpolB <= '1';
			end if ;
			if cont = 0 then
				if okDato = '1' then
					pestado <= activo;
					pcont 	<= cont +1;
				end if ;
				estim 	 <= inf;
			else
				-- se multiplica la diferencia entre las entradas
				-- inferior y superior por el peso adecuado.
				tmpi		<= dif.im * pesos(cont);
				tmpr		<= dif.re * pesos(cont);
				-- redondeamos, no truncamos.
				restoR(0)	<= tmpr(8);
				restoI(0)	<= tmpi(8);
				estim.im	<= inf.im + tmpi(18 downto 9) + restoI;
				estim.re	<= inf.re + tmpr(18 downto 9) + restoR;
				if okDato = '1' then
					pcont <= cont + 1;
					if cont = 11 then
						pestado	<= espera;
						pcont 	<= 0;
					else
				end if ;
				
			end if;
		end if;
	end case;

end process;

end Behavioral;
