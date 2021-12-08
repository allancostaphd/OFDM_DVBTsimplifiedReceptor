----------------------------------------------------------------
--
--		Autor: Pablo Linares serrano
--		Fecha: 11/06/2020
--
--		Descripcion: Fichero que ensambla los distintos 
--		Componentes del proyecto de la asignatura EDC
--		de 2o de MIT en la ETSI (estimador de canal)
--
--
--		Estado: Listo.
--
--
----------------------------------------------------------------

-- Declaraciones de bibliotecas
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.myPack.all;
use IEEE.NUMERIC_STD.ALL;



entity top2 is
	generic (
		-- tamanio de los datos y direcciones que vamos a usar
		DATA_WIDTH 	: integer := 20;
		ADDR_WIDTH 	: integer := 13;
		-- tamanio de los datos y direcciones pot de 2
		DATA_WIDTH2	: integer := 32; 
		ADDR_WIDTH2	: integer := 16
	);
	port ( clk 			: in	STD_LOGIC;
		rst 			: in	STD_LOGIC;
		modo 			: in	STD_LOGIC;
		datos 			: in	complex10;
		datosValid 		: in	STD_LOGIC;
		okDatos			: out	STD_LOGIC;
		estimValid 		: out	STD_LOGIC;
		estim 			: out	complex10;
		datosEc 		: out 	complex10;
		datosEcValid 	: out 	STD_LOGIC);
end top2;

architecture Behavioral of top2 is

	-- Seniales del la secuencia PRBS:
	signal prbsOut		: STD_LOGIC;
	signal prbsEnable	: STD_LOGIC;
	signal resetPRBS	: STD_LOGIC;

	-- Seniales del interpolador
	signal okInterpolF 	: STD_LOGIC;
	signal okInterpolB 	: STD_LOGIC;
	signal estim2 		: complex10;
	signal valid 		: STD_LOGIC;
	signal inf			: complex10;
	signal pinf			: complex10;
	signal sup			: complex10;
	signal psup			: complex10;
	--signal okInterpol  	: STD_LOGIC;
	signal posInterpol  : unsigned(ADDR_WIDTH-1 downto 0);
	signal tmpR			: signed(19 downto 0);
	signal tmpI			: signed(19 downto 0);
	signal restI 		: signed(9 downto 0);
	signal restR 		: signed(9 downto 0);


	-- valores por el que se multiplican los pilotos para obtener el canal
	constant pesoP : signed(9 downto 0) := to_signed(384, 10);
	constant pesoN : signed(9 downto 0) := to_signed(-384, 10);

	-- Seniales de la memoria
	signal	datosc 	: STD_LOGIC_VECTOR (DATA_WIDTH2-1 downto 0);
	signal	addr 	: unsigned (ADDR_WIDTH2-1 downto 0);
	signal 	datos2c	: STD_LOGIC_VECTOR (DATA_WIDTH2-1 downto 0);
	signal 	datos2 	: complex10;
	signal	addr2	: unsigned (ADDR_WIDTH2-1 downto 0);
	signal	we 		: STD_LOGIC;

	-- Seniales del divisor
	signal okDivisorB : STD_LOGIC;
	signal okDivisorF : STD_LOGIC;

	-- Constantes para poner seniales a tierra
	constant tierra 	: STD_LOGIC := '0';
	constant tierraVect : STD_LOGIC_VECTOR (DATA_WIDTH2-1 downto 0) := (others => '0');

	-- Seniales del contador de la entrada en memoria
	signal	cont 	: unsigned(ADDR_WIDTH-1 downto 0);
	signal	pcont 	: unsigned(ADDR_WIDTH-1 downto 0);

	-- Seniales del contador que monitoriza los pilotos
	signal contPilotos 	: unsigned(ADDR_WIDTH-1 downto 0);
	signal pContPilotos : unsigned(ADDR_WIDTH-1 downto 0);

	-- Registro de la posicion del piloto inferior interpolandose
	signal	posPilInf	: unsigned(ADDR_WIDTH-1 downto 0);
	signal	pPosPilInf	: unsigned(ADDR_WIDTH-1 downto 0);

	-- Constantes que marcan la zona util del simbolo
	-- Estos valores hay que repasarlos: comparar con simulaciones ML.
	-- Tal y como esta ahora mismo, el conPilotos deberia empezar en 0.
	constant inicio2k 	: unsigned (ADDR_WIDTH-1 downto 0) := to_unsigned(172, ADDR_WIDTH);
	constant final2k	: unsigned (ADDR_WIDTH-1 downto 0) := to_unsigned(1876, ADDR_WIDTH);
	constant inicio8k 	: unsigned (ADDR_WIDTH-1 downto 0) := to_unsigned(688, ADDR_WIDTH);
	constant final8k	: unsigned (ADDR_WIDTH-1 downto 0) := to_unsigned(7504, ADDR_WIDTH);

	-- Registro del modo (2k vs 8k)
	signal modoReg	: STD_LOGIC;
	signal pmodoReg : STD_LOGIC;

	-- Seniales de la maquina de estados
	type estados is (espera, piloto1, piloto2, pilotoNuevo, espera2);
	signal estado 	: estados;
	signal pestado 	: estados;

begin
	-- Conversiones de tipos de datos y asignaciones estaticas
	datosEcValid 								<= okDivisorF;
	datosc(DATA_WIDTH-1 downto DATA_WIDTH/2) 	<= STD_LOGIC_VECTOR(datos.re);
	datosc(DATA_WIDTH/2-1 downto 0)				<= STD_LOGIC_VECTOR(datos.im);
	datosc(DATA_WIDTH2-1 downto DATA_WIDTH)		<= (others => '0');
	datos2.re 									<= signed(datos2c(DATA_WIDTH-1 downto DATA_WIDTH/2));
	datos2.im 									<= signed(datos2c(DATA_WIDTH/2-1 downto 0));
	estimValid 									<= okInterpolB;
	addr(ADDR_WIDTH-1 downto 0) 				<= cont;
	addr(ADDR_WIDTH2-1 downto ADDR_WIDTH)		<= (others => '0');		
	addr2(ADDR_WIDTH2-1 downto ADDR_WIDTH)		<= (others => '0');
	addr2(ADDR_WIDTH-1 downto 0)				<= posPilInf+posInterpol;
	estim 										<= estim2;


	memoria: entity work.dpram
	generic map (
	  DATA_WIDTH => DATA_WIDTH2,
	  ADDR_WIDTH => ADDR_WIDTH2
	  )
	port map (
		clk_a   => clk,
		addri_a => addr,
		datai_a => datosc,
		we_a    => we,
		clk_b   => clk,
		addri_b => addr2,
		datai_b => tierraVect,
		we_b    => tierra,
		datao_b => datos2c
	  );

	interpolador: entity work.interpolador
	port map(
		clk 		=> clk,
		rst 		=> rst,
		inf 		=> inf,
		sup 		=> sup,
		okDato 		=> okDivisorB,
		okInterpolF => okInterpolF,
		okInterpolB => okInterpolB,
		valid 		=> valid,
		estim 		=> estim2,
		pos 		=> posInterpol);
		
	PRBS: entity work.prbs
	port map(
		clk 	=> clk,
		rst 	=> resetPRBS,
		enable 	=> prbsEnable,
		salida	=> prbsOut);

	divisor: entity work.divisor
	port map(
		clk 		=> clk,
		rst 		=> rst,
		H 			=> estim2,
		portadora 	=> datos2,
		valid 		=> okInterpolF,
		okDivisorB	=> okDivisorB,
		okDivisorF	=> okDivisorF,
		datoEc 		=> datosEc
		);

	sinc: process (clk, rst)
	begin
		if rst = '1' then
		-- Damos un valor inicial a las señales registradas
			cont 		<= (others => '0');
			contPilotos <= (others => '0');
			modoReg		<= '0';
			inf.re 		<= (others => '0');
			inf.im 		<= (others => '0');
			sup.re 		<= (others => '0');
			sup.im 		<= (others => '0');
			posPilInf 	<= (others => '0');

		elsif rising_edge(clk) then
		-- Actualizamos las señales registradas
			cont 		<= pcont;
			contPilotos <= pContPilotos;
			modoReg		<= pmodoReg;
			inf			<= pinf;
			sup			<= psup;
			estado 		<= pestado;
			posPilInf 	<= pPosPilInf;
		end if;
	end process;

	comb: process (estado, modo, modoReg, cont, contPilotos, datosValid, datosc, posPilInf, prbsOut, datos, tmpR, tmpI, okInterpolF, okInterpolB, sup, inf, restR, restI)
	begin
		-- Damos una valor estandar a las seniales que dependen del proceso combinacional para evitar latches
		pmodoReg 		<= modoReg;
		okDatos 		<= '0';
		pestado 		<= estado;
		pcont 			<= cont;
		pContPilotos 	<= contPilotos;
		we 				<= '0';
		psup			<= sup;
		pinf 			<= inf;
		prbsEnable 		<= '0';
		resetPRBS 		<= '0';
		pPosPilInf		<= posPilInf;
		tmpR 			<= (others => '0');
		tmpI 			<= (others => '0');
		restR 			<= (others => '0');
		restI 			<= (others => '0');
		valid 			<= '0';

		case estado is
		
			when espera =>
			-- La maquina de estados esta a la espera de que llegue un simbolo
				pcont <= (others =>'0');
				pContPilotos <= (others => '0');
				if datosValid = '1' then
				-- hay un simbolo disponible a la entrada
					pmodoReg 	<= modo;
					pestado 	<= piloto1;
					we 			<= '1';
					okDatos 	<= '1';
					pcont   	<= cont+1;
					resetPRBS 	<= '1';
				end if ;
			
			when piloto1 =>
			-- Se ha empezado a recibir un simbolo, esperamos a que llegue el primer piloto
				pcont 	<= cont +1;
				okDatos <= '1';
				we 		<= '1';
				if (cont = inicio8k and modoReg = '1') or (cont = inicio2k and modoReg = '0') then
				-- se ha alcanzado el primer piloto, pasamos a esperar el segundo
					pestado		<= piloto2;
					pContPilotos 	<= (others =>'0');
					-- calculamos el canal segun el piloto y la secuencia PRBS
					if prbsOut <= '0' then
						tmpR <= pesoP * datos.re;
						tmpI <= pesoP * datos.im;
					elsif prbsOut = '1' then
						tmpR <= pesoN * datos.re;
						tmpI <= pesoN * datos.im;
					end if ;
					-- Redondeamos, no truncamos.
					if tmpR(DATA_WIDTH/2-2) = '1' then
						restR <= to_signed(1, DATA_WIDTH/2);
					end if ;
					if tmpI(DATA_WIDTH/2-2) = '1' then
						restI <= to_signed(1, DATA_WIDTH/2);
					end if ;
					psup.re 		<= tmpR(DATA_WIDTH-2 downto DATA_WIDTH/2-1) + restR;
					psup.im 		<= tmpI(DATA_WIDTH-2 downto DATA_WIDTH/2-1) + restI;	
				end if ;

			when piloto2 =>
			-- Esperamos a la llegada del segundo piloto del simbolo
				we 				<= '1';
				prbsEnable 		<= '1';
				pcont 			<= cont + 1;
				pContPilotos 	<= contPilotos + 1;
				okDatos 		<= '1';
				if contPilotos = to_unsigned(11, ADDR_WIDTH) then
					pcont <= cont;
					okDatos 		<= '0';
				end if ;
				if contPilotos = to_unsigned(12, ADDR_WIDTH) then
				-- llega el piloto esperado, se da la señial para poner en marcha el interpolador
				-- antes de eso se registran los pilotos.
					valid 			<= '0';
					prbsEnable 		<= '0';
					pcont 			<= cont;
					okDatos 		<= '0';
					-- calculamos el canal segun el piloto y la secuencia PRBS
					if prbsOut = '0' then
						tmpR <= pesoP * datos.re;
						tmpI <= pesoP * datos.im;
					elsif prbsOut = '1' then
						tmpR <= pesoN * datos.re;
						tmpI <= pesoN * datos.im;
					end if ;
					-- Redondeamos, no truncamos.
					if tmpR(DATA_WIDTH/2-2) = '1' then
						restR <= to_signed(1, DATA_WIDTH/2);
					end if ;
					if tmpI(DATA_WIDTH/2-2) = '1' then
						restI <= to_signed(1, DATA_WIDTH/2);
					end if ;
					psup.re <= tmpR(DATA_WIDTH-2 downto DATA_WIDTH/2-1) + restR;
					psup.im <= tmpI(DATA_WIDTH-2 downto DATA_WIDTH/2-1) + restI;	
					pinf			<= sup;
					pPosPilInf 		<= cont - 12;
				end if;
				if contPilotos = to_unsigned(13, ADDR_WIDTH) then
					pestado 		<= pilotoNuevo;
					pcont 			<= cont;
					okDatos 		<= '0';
					pContPilotos 	<= contPilotos;
					valid 			<= '1';
					prbsEnable 		<= '0';
					if okInterpolB = '1' then
						-- cuando el interpolador da el visto bueno, avanzamos de estado.
						okDatos 		<= '1';
						pContPilotos 	<= (others => '0');
						pcont 			<= cont+1;
					end if ;
				end if;


			when pilotoNuevo =>
			-- Buscamos los pilotos restantes, lanzando el interpolador cada vez que se llega a uno.
				pcont 	<= cont +1;
				okDatos <= '1';
				we 		<= '1';
				prbsEnable <= '1';
				if okInterpolB = '1' then 
				-- solo se incrementa el contador cuando el interpolador da el visto bueno
					pContPilotos	<= contPilotos +1;
				else
					-- en caso contrario, se mantienen los valores.
					pContPilotos <= contPilotos;
					pcont 		 <= cont;
					okDatos 	 <= '0';
					prbsEnable <= '0';
				end if;
				if contPilotos = to_unsigned(11, ADDR_WIDTH) then
					pcont <= cont;
					okDatos 		<= '0';
				end if;
				if contPilotos = to_unsigned(12, ADDR_WIDTH) then
				-- Cuando se alcanza un nuevo piloto, se calcula el canal y se relanza el interpolador
					pContPilotos <= contPilotos + 1;
					valid 			<= '0';
					prbsEnable 		<= '0';
					pcont 			<= cont;
					okDatos 		<= '0';
					if prbsOut = '0' then
						tmpR <= pesoP * datos.re;
						tmpI <= pesoP * datos.im;
					elsif prbsOut = '1' then
						tmpR <= pesoN * datos.re;
						tmpI <= pesoN * datos.im;
					end if ;
					if tmpR(DATA_WIDTH/2-2) = '1' then
						restR <= to_signed(1, DATA_WIDTH/2);
					end if ;
					if tmpI(DATA_WIDTH/2-2) = '1' then
						restI <= to_signed(1, DATA_WIDTH/2);
					end if ;
					psup.re <= tmpR(DATA_WIDTH-2 downto DATA_WIDTH/2-1) + restR;
					psup.im <= tmpI(DATA_WIDTH-2 downto DATA_WIDTH/2-1) + restI;	
					pinf			<= sup;
					pPosPilInf 		<= cont - 12;
				end if;
				if contPilotos = to_unsigned(13, ADDR_WIDTH) then
					okDatos 		<= '1';
					valid 			<= '1';
					prbsEnable 		<= '0';
					pContPilotos 	<= (others => '0'); 
					pcont 			<= cont+1;
					if (cont = final2k and modoReg = '0') or (cont = final8k and modoReg = '1') then
					-- Se ha alcanzado el final de la carga util del simbolo, cambiamos de estado
						pcont 	<= (others => '0');
						pestado <= espera2;
					end if ;
				end if;

				when espera2 =>
				-- esperamos a que finalice el simbolo.
				pcont 	<= cont +1;
				okDatos <= '1';
				we 		<= '1';
				if (cont = (inicio8k-2) and modoReg = '1') or (cont = (inicio2k-2) and modoReg = '0') then
					-- se ha alcanzado el final del simbolo, pasamos a esperar la llegada de uno nuevo
					pestado	<= espera;
					pcont 	<= (others => '0');
				end if ;
			
		end case ;

	end process;



end Behavioral;