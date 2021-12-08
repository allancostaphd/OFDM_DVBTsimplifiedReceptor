----------------------------------------------------------------
--
--
--			Autor: Pablo Linares Serrano
--
--			Fecha: 13/6/2020
--
--			Descripcion: Paquete empleado en el trabajo de EDC
--			de 1o de MIT. contiene la definicion del tipo complejo a emplear
--
--
--
----------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

package mypack is

type complex10 is record
	re : signed (9 downto 0);
	im : signed (9 downto 0);

end record complex10;
 
end mypack;
