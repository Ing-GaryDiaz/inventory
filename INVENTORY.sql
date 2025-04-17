--La sgt Query incluye el esquema para evitar el error de relación inexistente y asegura que solo muestra un máximo de 10 filas.
SELECT
	*
FROM
	CC_USER.PARTS
LIMIT
	10;

--------------------------------- 1. MEJORANDO EL SEGUIMIENTO DE PIEZAS: --------------------------------------------------------
/* Establece que la columna code no puede contener valores nulos.
Crea una restricción única para garantizar que no haya códigos duplicados en la tabla parts. */
ALTER TABLE CC_USER.PARTS
ALTER COLUMN CODE
SET NOT NULL,
ADD CONSTRAINT CODE_UNIQUE UNIQUE (CODE);

/*En el sgte código nos aseguramos que todas las filas de la columna description contengan un valor */
UPDATE CC_USER.PARTS
SET
	DESCRIPTION = 'Descripción no disponible'
WHERE
	DESCRIPTION IS NULL;

/*Luego, para garantizar que no se puedan insertar valores nulos en la columna description , añadimos una restricción NOT NULL */
ALTER TABLE CC_USER.PARTS
ALTER COLUMN DESCRIPTION
SET NOT NULL;

/*Luego se me ocurre para llenar los campos faltantes de `description` 
con valores diferentes para cada pieza, lo sgte:*/
UPDATE CC_USER.PARTS
SET
	DESCRIPTION = CONCAT(
		'Pieza fabricada por: ',
		(
			SELECT
				NAME
			FROM
				CC_USER.MANUFACTURERS
			WHERE
				MANUFACTURERS.ID = PARTS.MANUFACTURER_ID
		)
	)
WHERE
	DESCRIPTION IS NULL;

/*El sgte código permite asegurar que los valores en filas de la columna 'description' de la tabla 'parts' nunca mas sean valores null'*/
ALTER TABLE CC_USER.PARTS
ALTER COLUMN DESCRIPTION
SET NOT NULL;

--Para  evitar que se ingresen descripciones vacías (por ejemplo, cadenas como '' ), se puede crear una restricción adicional utilizando una verificación (CHECK)
ALTER TABLE CC_USER.PARTS
ADD CONSTRAINT NOT_EMPTY_DESCRIPTION CHECK (TRIM(DESCRIPTION) <> '');

--Como ya existian valores nulos se tuvo que ejecutar una verificacion y un UPDATE:
SELECT
	*
FROM
	CC_USER.PARTS
WHERE
	TRIM(DESCRIPTION) = ''
	OR DESCRIPTION IS NULL;

UPDATE CC_USER.PARTS
SET
	DESCRIPTION = 'Descripción no disponible'
WHERE
	TRIM(DESCRIPTION) = ''
	OR DESCRIPTION IS NULL;

--Código apara verificar el funcionamiento de las restricciones, ya que no se especificará un valor para la columna 'description'
INSERT INTO
	CC_USER.PARTS (ID, CODE, MANUFACTURER_ID)
VALUES
	(101, 'GARY123', 1);

--Manera correcta del Query:
INSERT INTO
	CC_USER.PARTS (ID, DESCRIPTION, CODE, MANUFACTURER_ID)
VALUES
	(101, 'Nueva pieza electro-mecánica', 'GARY123', 1);

--Verifiquemos:
SELECT
	*
FROM
	CC_USER.PARTS
WHERE
	ID = 101;

--------------------------------- 2. MEJORANDO LAS OPCIONES DE REORDENAMIENTO: --------------------------------------------------------
--Aseguramos que en price_usd y quantity no se acepten valores NULL:
ALTER TABLE CC_USER.REORDER_OPTIONS
ALTER COLUMN PRICE_USD
SET NOT NULL,
ALTER COLUMN QUANTITY
SET NOT NULL;

--Aseguramos que los precios (price_usd) siempre sean mayores a cero: 
ALTER TABLE CC_USER.REORDER_OPTIONS
ADD CONSTRAINT PRICE_POSITIVE CHECK (PRICE_USD > 0);

--Aseguramos que las cantidades (quantity) siempre sean mayores a cero:
ALTER TABLE CC_USER.REORDER_OPTIONS
ADD CONSTRAINT QUANTITY_POSITIVE CHECK (QUANTITY > 0);

--Para añadir la restricción primero verificamos las filas problemáticas si existen
SELECT
	*
FROM
	CC_USER.REORDER_OPTIONS
WHERE
	QUANTITY <= 0
	OR PRICE_USD / QUANTITY NOT BETWEEN 0.02 AND 25.00;

--Aplicamos la restricción a la columna PRICE_USD Y QUANTITY  
ALTER TABLE CC_USER.REORDER_OPTIONS
ADD CONSTRAINT PRICE_UNIT_RANGE CHECK (
	QUANTITY > 0
	AND (PRICE_USD / QUANTITY) BETWEEN 0.02 AND 25.00
);

/*RELACIÓN CON LA TABLA parts: Aseguramos que la columna part_id tenga una clave foránea (fk) que haga referencia a la tabla parts, 
esto nos sirve para garantizar que solo se registren reorder_options para piezas válidas:*/
--Antes del ALTER TABLE es una buena práctica asegurar que no existan filas en REORDER_OPTIONS con valores de part_id que no estén presentes en parts:   
SELECT
	*
FROM
	CC_USER.REORDER_OPTIONS
WHERE
	PART_ID NOT IN (
		SELECT
			ID
		FROM
			CC_USER.PARTS
	);

ALTER TABLE CC_USER.REORDER_OPTIONS
ADD CONSTRAINT FK_PART_ID FOREIGN KEY (PART_ID) REFERENCES CC_USER.PARTS (ID);

--Al ejecutar el anterior ALTER TABLE, se muestra : there is no unique constraint matching given keys for referenced table "parts" .
-- Para resolver este problema, debes asegurarte de que la columna 'id' en la tabla 'parts'  tenga una restricción de unicidad.
--SOLUCIÓN:
ALTER TABLE CC_USER.PARTS
ADD CONSTRAINT PARTS_PKEY PRIMARY KEY (ID);

---------------------------------MEJORANDO EL SEGUIMIENTO DE UBICACIONES : --------------------------------------------------------
--1.
--Nos aseguramos que los valores en la columna 'qty' sean siempre mayores que cero.
--Antes verificamos si existen valores que violan la restricción de antemano:
SELECT
	*
FROM
	CC_USER.LOCATIONS
WHERE
	QTY <= 0;

ALTER TABLE CC_USER.LOCATIONS
ADD CONSTRAINT QTY_POSITIVE CHECK (QTY > 0);

--2.
SELECT
	LOCATION,
	PART_ID,
	COUNT(*)
FROM
	CC_USER.LOCATIONS
GROUP BY
	LOCATION,
	PART_ID
HAVING
	COUNT(*) > 1;

ALTER TABLE CC_USER.LOCATIONS
ADD CONSTRAINT UNIQUE_LOCATION_PART UNIQUE (LOCATION, PART_ID);

--3
--Antes de añadir la clave foránea, nos aseguramos de que todos los valores actuales en 'locations.part_id' ya existen en 'parts.id':
SELECT
	*
FROM
	CC_USER.LOCATIONS
WHERE
	PART_ID NOT IN (
		SELECT
			ID
		FROM
			CC_USER.PARTS
	);

--Corregimos un error proveniente de los datos cargados en la tabla original parts.csv
INSERT INTO
	CC_USER.PARTS (ID, DESCRIPTION, CODE, MANUFACTURER_ID)
VALUES
	(54, 'PiezaFaltante', 'Falta123', 1);

--Para ahora si asignar Fk, referenciando desde cc_user.parts
ALTER TABLE CC_USER.LOCATIONS
ADD CONSTRAINT FK_PART_ID FOREIGN KEY (PART_ID) REFERENCES CC_USER.PARTS (ID);

---------------------------------MEJORANDO EL SEGUIMIENTO DE FABRICANTES : --------------------------------------------------------
--1.
--Primero verificamos para proceder a establecer una restricción que establezca una relación entre `parts` y `manufacturers`, garantizando 
--que todas las piezas tengan un fabricante registrado:
SELECT
	*
FROM
	CC_USER.PARTS
WHERE
	MANUFACTURER_ID NOT IN (
		SELECT
			ID
		FROM
			CC_USER.MANUFACTURERS
	);

ALTER TABLE CC_USER.PARTS
ADD CONSTRAINT FK_MANUFACTURER_ID FOREIGN KEY (MANUFACTURER_ID) REFERENCES CC_USER.MANUFACTURERS (ID);

--2.
-- Probemos verificando una fusión que se vea reflejada en 'manufacturers':
INSERT INTO
	CC_USER.MANUFACTURERS (ID, NAME)
VALUES
	(11, 'Pip-NNC Industrial');

SELECT
	*
FROM
	CC_USER.MANUFACTURERS
WHERE
	ID = 11;

SELECT
	*
FROM
	CC_USER.PARTS
WHERE
	MANUFACTURER_ID IN (
		SELECT
			ID
		FROM
			CC_USER.MANUFACTURERS
		WHERE
			NAME IN ('Pip Industrial', 'NNC Manufacturing')
	);

--3
-- Actualizamos teniendo en cuenta la anterior fusión:
UPDATE CC_USER.PARTS
SET
	MANUFACTURER_ID = 11
WHERE
	MANUFACTURER_ID IN (
		SELECT
			ID
		FROM
			CC_USER.MANUFACTURERS
		WHERE
			NAME IN ('Pip Industrial', 'NNC Manufacturing')
	);

--Probemos:
SELECT
	*
FROM
	CC_USER.PARTS
WHERE
	MANUFACTURER_ID = 11;

--Como la anterior consulta me arrojó Total Rows: 0,
--verificamos que pudieramos eliminar posibles problemas de digitación en los datos
--contenidos en la tabla original (archivos .csv), en este caso (" Pip Industrial" en lugar de "Pip Industrial").
--Para eso usamos TRIM(name):
UPDATE CC_USER.PARTS
SET
	MANUFACTURER_ID = 11
WHERE
	MANUFACTURER_ID IN (
		SELECT
			ID
		FROM
			CC_USER.MANUFACTURERS
		WHERE
			TRIM(NAME) IN ('Pip Industrial', 'NNC Manufacturing')
	);

--Probemos(incluyendo el name):
SELECT
	CC_USER.PARTS.*,
	CC_USER.MANUFACTURERS.NAME
FROM
	CC_USER.PARTS
	JOIN CC_USER.MANUFACTURERS ON CC_USER.PARTS.MANUFACTURER_ID = CC_USER.MANUFACTURERS.ID
WHERE
	CC_USER.PARTS.MANUFACTURER_ID = 11;