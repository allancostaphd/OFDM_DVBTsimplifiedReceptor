----------------------------------------------------------------
--
--		Autor: Pablo Linares serrano
--		Fecha: 13/06/2020
--
--		Descripcion: test bench para el top del proyecto
--		de EDC de 1o de MIT. Debera leer los simbolos desde un
--		fichero generado en MatLab e interactuar con 
--		el bloque 'top'.
--
--
--		Estado: en desarrollo.
--
--
----------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- To use the utility library (clk generator, checkers, alerts)
library uvvm_util;
use uvvm_util.types_pkg.all;
use uvvm_util.string_methods_pkg.all;
use uvvm_util.adaptations_pkg.all;
use uvvm_util.methods_pkg.all;

-- To use randomization and functional coverage
library osvvm;
use osvvm.RandomBasePkg.all;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

use work.mypack.all;

use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_top is
generic(
	-- Eleccion del tipo de simbolo a simular
	-- Modo 2k
	modoGen : std_logic := '0'
	-- Modo 8k
	--modoGen : std_logic := '1'
	);
end tb_top;

architecture simulation of tb_top is

-- Seniales del reloj
	constant 	clk_period 	: time 		:= 10 ns;
	signal		clk_enable 	: boolean 	:= true;
	signal 		clk 		: std_logic;

-- Seniales del bloque 'top'
	-- entradas
	signal rst 			: std_logic;
	signal modo 		: std_logic;
	signal datos 		: complex10;
	signal datosValid 	: std_logic := '1';
	--salidas
	signal okDatos		: std_logic;
	signal estimValid	: std_logic;
	signal estim 		: complex10;
	signal datosEc 		: complex10;
	signal datosEcValid : std_logic;

	signal bandera 		: std_logic :='1';

	-- Ficheros para simulaciones de simbolos 8k, comentar eoc:
	-- Declaracion de fichero de entrada
	file f8kR : text open read_mode is "verif/simb8kR_ML.dat";
	file f8kI : text open read_mode is "verif/simb8kI_ML.dat";
	-- Declaracion de fichero de salida
	file f8kRo : text open write_mode is "verif/v2canal8kR_VHDL.dat";
	file f8kIo : text open write_mode is "verif/v2canal8kI_VHDL.dat";
	-- Declaracion del fichero con los datos ecualizados
	file f8kRec : text open write_mode is "verif/v2ec8kR_VHDL.dat";
	file f8kIec : text open write_mode is "verif/v2ec8kI_VHDL.dat";

	-- Ficheros para simulaciones de simbolos 2k, comentar eoc
	-- Declaracion de fichero de entrada
	file f2kR : text open read_mode is "verif/simb2kR_ML.dat";
	file f2kI : text open read_mode is "verif/simb2kI_ML.dat";
	-- Declaracion de fichero de salida
	file f2kRo : text open write_mode is "verif/v2canal2kR_VHDL.dat";
	file f2kIo : text open write_mode is "verif/v2canal2kI_VHDL.dat";
	-- Declaracion del fichero con los datos ecualizados
	file f2kRec : text open write_mode is "verif/v2ec2kR_VHDL.dat";
	file f2kIec : text open write_mode is "verif/v2ec2kI_VHDL.dat";


begin


	modo <= modoGen;
	-- Instanciamos el top
	instanciaTop: entity work.top2
		port map(
			clk 			=> clk,
			rst 			=> rst,
			modo 			=> modo,
			datos 			=> datos,
			datosValid 		=> datosValid,
			okDatos 		=> okDatos,
			estimValid 		=> estimValid,
			estim 			=> estim,
			datosEc 		=> datosEc,
			datosEcValid 	=> datosEcValid
			);


	-- Generamos el reloj
	clock_generator (clk, clk_enable, clk_period, "Global clock", clk_period/2);

	-- Proceso principal
	main: process
	begin
		log (ID_LOG_HDR, "Starting simulation");
		rst <= '1';
		wait for 1 ns;
		wait for 10 * clk_period;
		rst <= '0';

		wait;
	end process;

	lectura: process (clk, rst)
	-- Leemos los simbolos del fichero correspondiente
		variable lineaR 	: line;
		variable lineaI 	: line;
		variable realLeido 	: integer range -511 to 511 :=0;
		variable imagLeido 	: integer range -511 to 511 :=0;
	begin
		if (rst = '1') then
			datosValid <= '0';
			datos.re <= to_signed(0, 10);
			datos.im <= to_signed(0, 10);
		end if;
		if rising_edge(clk) and not(rst = '1') then
			datosValid <= '1';
			if bandera = '1' then
				if modoGen = '0' and not(endfile(f2kR)) and not(endfile(f2kI)) then
					readline(f2kR, lineaR);
					readline(f2kI, lineaI);
				elsif modoGen = '1' and not(endfile(f8kR)) and not(endfile(f8kI)) then
					readline(f8kR, lineaR);
					readline(f8kI, lineaI);
				end if;
				read(lineaR, realLeido);
				read(lineaI, imagLeido);
				datos.re <= to_signed(realLeido, 10);
				datos.im <= to_signed(imagLeido, 10);
				bandera <= '0';
			end if ;
			if okDatos = '1' and bandera = '0' then
			-- Leemos de los ficheros en el flanco de subida, cuando okDatos esta activado.
				if modoGen = '0' and not(endfile(f2kR)) and not(endfile(f2kI)) then
					readline(f2kR, lineaR);
					readline(f2kI, lineaI);
				elsif modoGen = '1' and not(endfile(f8kR)) and not(endfile(f8kI)) then
					readline(f8kR, lineaR);
					readline(f8kI, lineaI);
				end if;
				if endfile(f2kR) or endfile(f2kI) or endfile(f8kI) or endfile(f8kR) then
					-- Desactivamos el reloj cuando se cumple:
					-- a) Se ha alcanzado el final de alguno de los ficheros de entrada
					-- b) se ha terminado de procesar el simbolo anterior (el 'top' da okDatos = '1').
					clk_enable <= false;
					log (ID_LOG_HDR, "End of simulation");
					datosValid <= '0';
				else
					-- Le indicamos al top que hay datos disponibles cuando nos indica que espera datos
					-- nos indica que espera datos mediante okDatos = '1'.
					datosValid <= '1';
					read(lineaR, realLeido);
					read(lineaI, imagLeido);
				end if;
			end if;
			-- Sin el 'top' no espera datos, no leemos del fichero y mantenemos los valores anteriores.
			datos.re <= to_signed(realLeido, 10);
			datos.im <= to_signed(imagLeido, 10);
				
		end if;
			
	end process;

	escritura: process (clk, rst)
	-- Vuelca el canal estimado en los ficheros adecuados
	variable lineaRo 		: line;
	variable lineaIo 		: line;
	variable realEscrito 	: integer range -512 to 511 := 0;
	variable imagEscrito 	: integer range -512 to 511 := 0;
	
	begin
		if rising_edge(clk) and not(rst = '1') then
			if estimValid = '1' then
				realEscrito := to_integer(estim.re);
				imagEscrito := to_integer(estim.im);
				write(lineaRo, realEscrito);
				write(lineaIo, imagEscrito);
				if modoGen = '0' then
					writeline(f2kRo, lineaRo);
					writeline(f2kIo, lineaIo);
				end if ;
				if modoGen = '1' then
					writeline(f8kRo, lineaRo);
					writeline(f8kIo, lineaIo);
				end if ;
			end if ;
		end if ;

	end process;

	escritura2: process (clk, rst)
	-- Vuelca los datos ecuallizados en los ficheros adecuados
	variable lineaRo2 		: line;
	variable lineaIo2 		: line;
	variable realEscrito2 	: integer range -512 to 511 := 0;
	variable imagEscrito2 	: integer range -512 to 511 := 0;
	
	begin
		if rising_edge(clk) and not(rst = '1') then
			if datosEcValid = '1' then
				realEscrito2 := to_integer(datosEc.re);
				imagEscrito2 := to_integer(datosEc.im);
				write(lineaRo2, realEscrito2);
				write(lineaIo2, imagEscrito2);
				if modoGen = '0' then
					writeline(f2kRec, lineaRo2);
					writeline(f2kIec, lineaIo2);
				end if ;
				if modoGen = '1' then
					writeline(f8kRec, lineaRo2);
					writeline(f8kIec, lineaIo2);
				end if ;
			end if ;
		end if ;

	end process;
end architecture;