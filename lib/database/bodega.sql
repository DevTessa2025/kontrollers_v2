CREATE TABLE check_bodega (
    id INT IDENTITY(1,1) PRIMARY KEY,
    -- Identificador único para agrupar todos los ítems de un mismo checklist
    checklist_uuid UNIQUEIDENTIFIER NOT NULL,

    -- Datos del encabezado (se repiten en cada ítem del mismo checklist)
    finca_nombre NVARCHAR(255),
    supervisor_id INT,
    supervisor_nombre NVARCHAR(255),
    pesador_id INT,
    pesador_nombre NVARCHAR(255),
    usuario_id INT,
    usuario_nombre NVARCHAR(255),
    fecha_creacion DATETIME,
    porcentaje_cumplimiento DECIMAL(5, 2),
    fecha_envio DATETIME,

    -- Item 1
    item_1_respuesta NVARCHAR(10),
    item_1_valor_numerico DECIMAL(5, 2),
    item_1_observaciones NVARCHAR(MAX),
    item_1_foto_base64 NVARCHAR(MAX),

    -- Item 2
    item_2_respuesta NVARCHAR(10),
    item_2_valor_numerico DECIMAL(5, 2),
    item_2_observaciones NVARCHAR(MAX),
    item_2_foto_base64 NVARCHAR(MAX),

    -- Item 3
    item_3_respuesta NVARCHAR(10),
    item_3_valor_numerico DECIMAL(5, 2),
    item_3_observaciones NVARCHAR(MAX),
    item_3_foto_base64 NVARCHAR(MAX),

    -- Item 4
    item_4_respuesta NVARCHAR(10),
    item_4_valor_numerico DECIMAL(5, 2),
    item_4_observaciones NVARCHAR(MAX),
    item_4_foto_base64 NVARCHAR(MAX),

    -- Item 5
    item_5_respuesta NVARCHAR(10),
    item_5_valor_numerico DECIMAL(5, 2),
    item_5_observaciones NVARCHAR(MAX),
    item_5_foto_base64 NVARCHAR(MAX),

    -- Item 6
    item_6_respuesta NVARCHAR(10),
    item_6_valor_numerico DECIMAL(5, 2),
    item_6_observaciones NVARCHAR(MAX),
    item_6_foto_base64 NVARCHAR(MAX),

    -- Item 7
    item_7_respuesta NVARCHAR(10),
    item_7_valor_numerico DECIMAL(5, 2),
    item_7_observaciones NVARCHAR(MAX),
    item_7_foto_base64 NVARCHAR(MAX),

    -- Item 8
    item_8_respuesta NVARCHAR(10),
    item_8_valor_numerico DECIMAL(5, 2),
    item_8_observaciones NVARCHAR(MAX),
    item_8_foto_base64 NVARCHAR(MAX),

    -- Item 9
    item_9_respuesta NVARCHAR(10),
    item_9_valor_numerico DECIMAL(5, 2),
    item_9_observaciones NVARCHAR(MAX),
    item_9_foto_base64 NVARCHAR(MAX),

    -- Item 10
    item_10_respuesta NVARCHAR(10),
    item_10_valor_numerico DECIMAL(5, 2),
    item_10_observaciones NVARCHAR(MAX),
    item_10_foto_base64 NVARCHAR(MAX),

    -- Item 11
    item_11_respuesta NVARCHAR(10),
    item_11_valor_numerico DECIMAL(5, 2),
    item_11_observaciones NVARCHAR(MAX),
    item_11_foto_base64 NVARCHAR(MAX),

    -- Item 12
    item_12_respuesta NVARCHAR(10),
    item_12_valor_numerico DECIMAL(5, 2),
    item_12_observaciones NVARCHAR(MAX),
    item_12_foto_base64 NVARCHAR(MAX),

    -- Item 13
    item_13_respuesta NVARCHAR(10),
    item_13_valor_numerico DECIMAL(5, 2),
    item_13_observaciones NVARCHAR(MAX),
    item_13_foto_base64 NVARCHAR(MAX),

    -- Item 14
    item_14_respuesta NVARCHAR(10),
    item_14_valor_numerico DECIMAL(5, 2),
    item_14_observaciones NVARCHAR(MAX),
    item_14_foto_base64 NVARCHAR(MAX),

    -- Item 15
    item_15_respuesta NVARCHAR(10),
    item_15_valor_numerico DECIMAL(5, 2),
    item_15_observaciones NVARCHAR(MAX),
    item_15_foto_base64 NVARCHAR(MAX),

    -- Item 16
    item_16_respuesta NVARCHAR(10),
    item_16_valor_numerico DECIMAL(5, 2),
    item_16_observaciones NVARCHAR(MAX),
    item_16_foto_base64 NVARCHAR(MAX),

    -- Item 17
    item_17_respuesta NVARCHAR(10),
    item_17_valor_numerico DECIMAL(5, 2),
    item_17_observaciones NVARCHAR(MAX),
    item_17_foto_base64 NVARCHAR(MAX),

    -- Item 18
    item_18_respuesta NVARCHAR(10),
    item_18_valor_numerico DECIMAL(5, 2),
    item_18_observaciones NVARCHAR(MAX),
    item_18_foto_base64 NVARCHAR(MAX),

    -- Item 19
    item_19_respuesta NVARCHAR(10),
    item_19_valor_numerico DECIMAL(5, 2),
    item_19_observaciones NVARCHAR(MAX),
    item_19_foto_base64 NVARCHAR(MAX),

    -- Item 20
    item_20_respuesta NVARCHAR(10),
    item_20_valor_numerico DECIMAL(5, 2),
    item_20_observaciones NVARCHAR(MAX),
    item_20_foto_base64 NVARCHAR(MAX)
);