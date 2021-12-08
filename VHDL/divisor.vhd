----------------------------------------------------------------------------------
--
--
--		Autor: Pablo Linares Serrano 
--		Fecha: 11/6/2020
--
--		Descripcion: Bloque divisor complejo. Basado en el divisor que se nos ha dado.
--
--		Estado: recien nacido.
--
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.myPack.all;
use IEEE.NUMERIC_STD.ALL;

entity divisor is
generic (
		-- tamanio de los datos y direcciones que vamos a usar
		DATA_WIDTH 	: integer := 20;
		ADDR_WIDTH 	: integer := 13;
		-- tamanio de los datos y direcciones pot de 2
		DATA_WIDTH2	: integer := 32; 
		ADDR_WIDTH2	: integer := 16
	);
    Port ( clk 			: in  STD_LOGIC;
			rst 		: in  STD_LOGIC;
			H 			: in  complex10;
			portadora	: in  complex10;
			valid 		: in  STD_LOGIC;
			okDivisorF 	: out std_logic;
			okDivisorB 	: out std_logic;
			datoEc 		: out complex10);
end divisor;

architecture Behavioral of divisor is

-- Seniales para hacer el conjugado del canal
	signal a11 		: signed (9 downto 0);
	signal a12 		: signed (9 downto 0);
	signal a2 		: signed (19 downto 0);
	signal b11 		: signed (9 downto 0);
	signal b12 		: signed (9 downto 0);
	signal b2 		: signed (19 downto 0);
	signal pRealTem	: signed (19 downto 0);
	signal pImagTem	: signed (19 downto 0);
	signal pReal	: signed (9 downto 0);
	signal pImag	: signed (9 downto 0);

-- Seniales de entrada al bloque divider
	constant 	dividend 		: signed(9 downto 0) := "0111111111";
	signal 	 	divisorS  		: signed(9 downto 0);
	-- Senial asegurada contra ceros
	signal		divisorA		: signed(9 downto 0);
	signal 		divisorTemp 	: signed(19 downto 0);
	signal 		validDivider	: STD_LOGIC;
	signal 		pValidDivider 	: STD_LOGIC;

-- Seniales de salida del divider
	signal 	quotient 	: signed(9 downto 0);
	signal 	remainder	: signed(9 downto 0);
	signal 	outValid 	: STD_LOGIC;
	signal 	dividerBusy	: STD_LOGIC;
	signal 	err			: STD_LOGIC; 

-- Seniales para registrar las entradas
	signal Hreg 			: complex10;
	signal pHreg			: complex10;
	signal portadoraReg 	: complex10;
	signal pPortadoraReg 	: complex10;

-- Seniales de la maquina de estados
	--type estados is (espera, sincronizar, regEntradas, dividir, salida);
	type estados is (espera, sincronizar, regEntradas, dividir);
	signal estado 	: estados;
	signal pestado 	: estados;

-- Seniales para gestionar la salida del divisor
	signal datoRtemp : signed (19 downto 0);
	signal datoItemp : signed (19 downto 0);
begin
-- obtenemos el divisor a partir de las señiales registradas
	a11 		<= Hreg.re;
	a12 		<= Hreg.re;
	b11 		<= Hreg.im;
	b12 		<= Hreg.im;
	a2 			<= a11 * a12;
	b2 			<= b11 * b12;
	divisorTemp <= a2 + b2;
	-- Redondeamos, no truncamos.
	divisorS 	<= divisorTemp(19 downto 10) when divisorTemp(9) = '0' else
					divisorTemp(19 downto 10) + to_signed(1, 10);
	-- Si alguna vez fuese cero, ponemos un uno.
	divisorA	<= to_signed(1, 10) when divisorS = 0 else
				divisorS;
	pRealTem	<= Hreg.re * portadoraReg.re + Hreg.im * portadoraReg.im;
	pImagTem 	<= Hreg.re * portadoraReg.im - Hreg.im * portadoraReg.re;
	-- Redondeamos, no truncamos.
	pReal 	<= pRealTem(19 downto 10) when pRealTem(9) = '0' else
					pRealTem(19 downto 10) + to_signed(1, 10);
	pImag 	<= pImagTem(19 downto 10) when pImagTem(9) = '0' else
					pImagTem(19 downto 10) + to_signed(1, 10);

	divider: entity work.divider
	port map (
		clk 		=> clk,
		rst 		=> rst,
		dividend 	=> dividend,
		divisor 	=> divisorA,
		valid 		=> validDivider,
		quotient 	=> quotient,
		remainder 	=> remainder,
		out_valid 	=> outValid,
		busy 		=> dividerBusy,
		err			=> err 
		);

sinc: process (clk, rst)
begin
	if rst = '1' then
		Hreg.re 		<= (others => '0');
		Hreg.im 		<= (others => '0');
		portadoraReg.re <= (others => '0');
		portadoraReg.im <= (others => '0');
		estado 			<= espera;
		validDivider 	<= '0';
	elsif rising_edge(clk) then
		estado 			<= pestado;
		Hreg 			<= pHreg;
		portadoraReg 	<= pPortadoraReg;
		validDivider 	<= pValidDivider;
	end if;

end process;

comb: process (estado, H, Hreg, portadora, portadoraReg, quotient, outValid, dividerBusy, validDivider, pReal, pImag, valid, datoRtemp, datoItemp)
begin
	pValidDivider 	<= '0';
	pestado			<= estado;
	okDivisorF 		<= '0';
	okDivisorB 		<= '0';
	datoEc.re 		<= (others => '0');
	datoEc.im 		<= (others => '0');
	pHreg 			<= Hreg;
	pPortadoraReg 	<= portadoraReg;
	datoRtemp 		<= (others => '0');
	datoItemp 		<= (others => '0');

case estado  is

	when espera =>
	-- Esperamos a que llegue un valor desde el interpolador
		if valid = '1' then
		-- cuando llega, avanzamos de estado
			pestado <= sincronizar;
		end if ;

	when sincronizar =>
	-- esperamos un ciclo, para que la memoria sirva el dato apropiado
		pestado	<= regEntradas;

	when regEntradas =>
	-- registramos las entradas y damos el visto bueno al interpolador
	-- para que siga interpolando
		pestado 		<= dividir;
		pPortadoraReg 	<= portadora;
		pHreg 			<= H;
		pValidDivider 	<= '1';
		okDivisorB 		<= '1';

	when dividir =>
	-- Esperamos a que termine el bloque divider de dividir
	if outValid = '1' then
	-- cuando termina, generamos la salida e indicamos que el dato
	-- a la salida el valido.
		pestado		<= espera; 
		okDivisorF	<= '1';
		datoRtemp 	<= quotient * pReal;
		datoItemp 	<= quotient * pImag;
		-- Redondeamos, no truncamos
		if datoRtemp(2) = '1' then
			datoEc.re <= datoRtemp(12 downto 3) + to_signed(1, 10);
		else
			datoEc.re <= datoRtemp(12 downto 3);
		end if ;
		if datoItemp(2) = '1' then
			datoEc.im <= datoItemp(12 downto 3) + to_signed(1, 10);
		else
			datoEc.im <= datoItemp(12 downto 3);
		end if ;
	end if ;
	
end case ;

end process;


end architecture ; -- Behavioral