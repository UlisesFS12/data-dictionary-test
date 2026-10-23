-- Esquemas de ejemplo (datos ficticios)
CREATE SCHEMA core;
CREATE SCHEMA publicado;

CREATE TABLE core.socios (
  socio_id   serial PRIMARY KEY,
  nombre     varchar(100) NOT NULL,
  email      varchar(150) UNIQUE,
  id_externo varchar(20) UNIQUE,
  creado_en  timestamp DEFAULT now()
);
COMMENT ON TABLE core.socios IS 'Personas inscritas en la biblioteca';
COMMENT ON COLUMN core.socios.id_externo IS 'Identificador usado por el sistema externo';

CREATE TABLE core.libros (
  libro_id serial PRIMARY KEY,
  titulo   varchar(200) NOT NULL,
  autor    varchar(120)
);
COMMENT ON TABLE core.libros IS 'Catálogo de libros';

CREATE TABLE core.prestamos (
  prestamo_id      serial PRIMARY KEY,
  socio_id         int NOT NULL REFERENCES core.socios(socio_id),
  libro_id         int NOT NULL REFERENCES core.libros(libro_id),
  fecha_prestamo   date NOT NULL DEFAULT current_date,
  fecha_devolucion date,
  estado           varchar(20) NOT NULL DEFAULT 'ABIERTO'
);
COMMENT ON TABLE core.prestamos IS 'Préstamo de un libro a un socio';
COMMENT ON COLUMN core.prestamos.estado IS 'ABIERTO, DEVUELTO o VENCIDO';

CREATE TABLE core.multas (
  multa_id    serial PRIMARY KEY,
  prestamo_id int NOT NULL REFERENCES core.prestamos(prestamo_id),
  monto       numeric(10,2) NOT NULL,
  pagada      boolean DEFAULT false
);
COMMENT ON TABLE core.multas IS 'Multas por devolución tardía';

-- Sin llave foránea real: la relación se define en .tbls.yml
CREATE TABLE publicado.socio_publicado (
  id           serial PRIMARY KEY,
  id_externo   int NOT NULL,
  publicado_en timestamp
);
COMMENT ON TABLE publicado.socio_publicado IS 'Socios enviados al sistema externo';
COMMENT ON COLUMN publicado.socio_publicado.id_externo IS 'Equivale a core.socios.id_externo (con cast a texto)';

-- Vista
CREATE VIEW core.vw_multas_pendientes AS
SELECT s.socio_id, s.nombre, SUM(m.monto) AS total_pendiente
FROM core.multas m
JOIN core.prestamos p ON p.prestamo_id = m.prestamo_id
JOIN core.socios s    ON s.socio_id   = p.socio_id
WHERE NOT m.pagada
GROUP BY s.socio_id, s.nombre;
COMMENT ON VIEW core.vw_multas_pendientes IS 'Total de multas sin pagar por socio';

-- Función + trigger
CREATE FUNCTION core.fn_marcar_devuelto() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.fecha_devolucion IS NOT NULL THEN
    NEW.estado := 'DEVUELTO';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_marcar_devuelto
BEFORE UPDATE ON core.prestamos
FOR EACH ROW EXECUTE FUNCTION core.fn_marcar_devuelto();
