-- ============================================
-- 1) CATÁLOGOS
-- ============================================
INSERT INTO moneda (id, nombre, simbolo) VALUES
  (1,'Colón costarricense','₡'),
  (2,'Dólar estadounidense','$'),
  (3,'Córdoba nicaragüense','C$')
ON CONFLICT (id) DO NOTHING;

INSERT INTO pais (id, nombre, "monedaFK") VALUES
  (1,'Costa Rica', 1),
  (2,'Estados Unidos', 2),
  (3,'Nicaragua', 3)
ON CONFLICT (id) DO NOTHING;

INSERT INTO "catalogoTipoSorteo" (id, nombre) VALUES
  (1,'WEEKLY'),
  (2,'EXTRA')
ON CONFLICT (id) DO NOTHING;

INSERT INTO "metodoPago" (id, metodo) VALUES
  (1,'SINPE'),
  (2,'PAYPAL'),
  (3,'TARJETA')
ON CONFLICT (id) DO NOTHING;

INSERT INTO "metodoPagoXPais" (id, api, "paisFK", "metodoPagoFK") VALUES
  (1,'sinpeCR',  1, 1),
  (2,'paypalCR', 1, 2),
  (3,'cardCR',   1, 3),
  (4,'paypalUS', 2, 2),
  (5,'cardUS',   2, 3),
  (6,'cardNI',   3, 3)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 2) USUARIOS (1000)
-- ============================================
INSERT INTO usuario (nombre, telefono, "paisFK")
SELECT
  'Usuario ' || gs,                          -- Usuario 1..1000
  LPAD((70000000 + gs)::text, 8, '0'),       -- teléfono de 8 dígitos
  (ARRAY[1,2,3])[1 + floor(random()*3)]::int -- país al azar
FROM generate_series(1,1000) AS gs;

-- ============================================
-- 3) SORTEOS
-- ============================================
INSERT INTO sorteo (id, numero, "paisFK", "categoriaSorteoFK", "fechaSorteo") VALUES
  (101, 1001, 1, 1, '2025-09-25 20:00:00-06'),  -- CR semanal
  (102, 2001, 1, 2, '2025-10-01 20:00:00-06'),  -- CR extra
  (201, 1101, 2, 1, '2025-09-26 20:00:00-05'),  -- US semanal
  (202, 2101, 2, 2, '2025-10-03 20:00:00-05'),  -- US extra
  (301, 1201, 3, 1, '2025-09-27 20:00:00-06'),  -- NI semanal
  (302, 2201, 3, 2, '2025-10-05 20:00:00-06')   -- NI extra
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 4) PAGOS 
-- ============================================
INSERT INTO pago (cantidad, "metodoPagoXPaisFK", "monedaFK", "usuarioFK")
SELECT
  (100 + floor(random()*10000))::bigint AS cantidad,
  (SELECT mp.id FROM "metodoPagoXPais" mp
     WHERE mp."paisFK" = u."paisFK"
     ORDER BY random() LIMIT 1)          AS metodoPagoXPaisFK,
  (SELECT p."monedaFK" FROM pais p WHERE p.id = u."paisFK") AS monedaFK,
  u.id AS usuarioFK
FROM usuario u
ORDER BY u.id
LIMIT 1000;

-- ============================================
-- 5) APUESTAS
-- ============================================
INSERT INTO apuesta (numero, monto, "monedaFK", "pagoFK", "sorteoFK", "usuarioFK")
SELECT
  (floor(random()*10000))::int                    AS numero,     -- 0..9999
  (100 + floor(random()*5000))::bigint            AS monto,
  (SELECT p."monedaFK" FROM pais p WHERE p.id = u."paisFK") AS monedaFK,
  (SELECT pg.id FROM pago pg
     WHERE pg."usuarioFK" = u.id
     ORDER BY pg.id DESC LIMIT 1)                 AS pagoFK,
  (SELECT s.id FROM sorteo s
     WHERE s."paisFK" = u."paisFK"
     ORDER BY random() LIMIT 1)                   AS sorteoFK,
  u.id                                            AS usuarioFK
FROM usuario u
ORDER BY u.id
LIMIT 1000;