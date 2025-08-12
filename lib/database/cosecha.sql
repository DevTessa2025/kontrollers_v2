-- ============================================================================
-- SCRIPT DE CREACIÓN DE TABLA PARA CHECKLIST DE COSECHA
-- Nombre de tabla: check_cosecha (compatible con el código Flutter)
-- Base de datos: Kontrollers (SQL Server)
-- ============================================================================

USE Kontrollers;
GO

-- ============================================================================
-- TABLA PRINCIPAL: check_cosecha
-- Almacena los checklist de cosecha completados
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[check_cosecha]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[check_cosecha] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,

        -- UUID único del checklist
        [checklist_uuid] NVARCHAR(50) UNIQUE NOT NULL,

        -- Información básica del checklist
        [finca_nombre] NVARCHAR(100) NULL,
        [bloque_nombre] NVARCHAR(50) NULL,
        [variedad_nombre] NVARCHAR(100) NULL,

        -- Información del usuario y fechas
        [usuario_id] INT NULL,
        [usuario_nombre] NVARCHAR(100) NULL,
        [fecha_creacion] DATETIME2(3) NOT NULL,
        [fecha_envio] DATETIME2(3) NOT NULL DEFAULT GETDATE(),

        -- Métricas del checklist
        [porcentaje_cumplimiento] REAL DEFAULT 0,

        -- Campos para cada item del checklist (25 items total)
        -- SECCIÓN: PREPARACIÓN Y IDENTIFICACIÓN (Items 1-6)
        [item_1_respuesta] NVARCHAR(10) NULL, -- 'si', 'no', 'na'
        [item_1_valor_numerico] REAL NULL,
        [item_1_observaciones] NVARCHAR(500) NULL,
        [item_1_foto_base64] NVARCHAR(MAX) NULL,

        [item_2_respuesta] NVARCHAR(10) NULL,
        [item_2_valor_numerico] REAL NULL,
        [item_2_observaciones] NVARCHAR(500) NULL,
        [item_2_foto_base64] NVARCHAR(MAX) NULL,

        [item_3_respuesta] NVARCHAR(10) NULL,
        [item_3_valor_numerico] REAL NULL,
        [item_3_observaciones] NVARCHAR(500) NULL,
        [item_3_foto_base64] NVARCHAR(MAX) NULL,

        [item_4_respuesta] NVARCHAR(10) NULL,
        [item_4_valor_numerico] REAL NULL,
        [item_4_observaciones] NVARCHAR(500) NULL,
        [item_4_foto_base64] NVARCHAR(MAX) NULL,

        [item_5_respuesta] NVARCHAR(10) NULL,
        [item_5_valor_numerico] REAL NULL,
        [item_5_observaciones] NVARCHAR(500) NULL,
        [item_5_foto_base64] NVARCHAR(MAX) NULL,

        [item_6_respuesta] NVARCHAR(10) NULL,
        [item_6_valor_numerico] REAL NULL,
        [item_6_observaciones] NVARCHAR(500) NULL,
        [item_6_foto_base64] NVARCHAR(MAX) NULL,

        -- SECCIÓN: INFRAESTRUCTURA Y MANTENIMIENTO (Items 7-15)
        [item_7_respuesta] NVARCHAR(10) NULL,
        [item_7_valor_numerico] REAL NULL,
        [item_7_observaciones] NVARCHAR(500) NULL,
        [item_7_foto_base64] NVARCHAR(MAX) NULL,

        [item_8_respuesta] NVARCHAR(10) NULL,
        [item_8_valor_numerico] REAL NULL,
        [item_8_observaciones] NVARCHAR(500) NULL,
        [item_8_foto_base64] NVARCHAR(MAX) NULL,

        [item_9_respuesta] NVARCHAR(10) NULL,
        [item_9_valor_numerico] REAL NULL,
        [item_9_observaciones] NVARCHAR(500) NULL,
        [item_9_foto_base64] NVARCHAR(MAX) NULL,

        [item_10_respuesta] NVARCHAR(10) NULL,
        [item_10_valor_numerico] REAL NULL,
        [item_10_observaciones] NVARCHAR(500) NULL,
        [item_10_foto_base64] NVARCHAR(MAX) NULL,

        [item_11_respuesta] NVARCHAR(10) NULL,
        [item_11_valor_numerico] REAL NULL,
        [item_11_observaciones] NVARCHAR(500) NULL,
        [item_11_foto_base64] NVARCHAR(MAX) NULL,

        [item_12_respuesta] NVARCHAR(10) NULL,
        [item_12_valor_numerico] REAL NULL,
        [item_12_observaciones] NVARCHAR(500) NULL,
        [item_12_foto_base64] NVARCHAR(MAX) NULL,

        [item_13_respuesta] NVARCHAR(10) NULL,
        [item_13_valor_numerico] REAL NULL,
        [item_13_observaciones] NVARCHAR(500) NULL,
        [item_13_foto_base64] NVARCHAR(MAX) NULL,

        [item_14_respuesta] NVARCHAR(10) NULL,
        [item_14_valor_numerico] REAL NULL,
        [item_14_observaciones] NVARCHAR(500) NULL,
        [item_14_foto_base64] NVARCHAR(MAX) NULL,

        [item_15_respuesta] NVARCHAR(10) NULL,
        [item_15_valor_numerico] REAL NULL,
        [item_15_observaciones] NVARCHAR(500) NULL,
        [item_15_foto_base64] NVARCHAR(MAX) NULL,

        -- SECCIÓN: LIMPIEZA Y MANTENIMIENTO GENERAL (Items 16-18)
        [item_16_respuesta] NVARCHAR(10) NULL,
        [item_16_valor_numerico] REAL NULL,
        [item_16_observaciones] NVARCHAR(500) NULL,
        [item_16_foto_base64] NVARCHAR(MAX) NULL,

        [item_17_respuesta] NVARCHAR(10) NULL,
        [item_17_valor_numerico] REAL NULL,
        [item_17_observaciones] NVARCHAR(500) NULL,
        [item_17_foto_base64] NVARCHAR(MAX) NULL,

        [item_18_respuesta] NVARCHAR(10) NULL,
        [item_18_valor_numerico] REAL NULL,
        [item_18_observaciones] NVARCHAR(500) NULL,
        [item_18_foto_base64] NVARCHAR(MAX) NULL,

        -- SECCIÓN: APLICACIÓN Y CONTROL (Items 19-25)
        [item_19_respuesta] NVARCHAR(10) NULL,
        [item_19_valor_numerico] REAL NULL,
        [item_19_observaciones] NVARCHAR(500) NULL,
        [item_19_foto_base64] NVARCHAR(MAX) NULL,

        [item_20_respuesta] NVARCHAR(10) NULL,
        [item_20_valor_numerico] REAL NULL,
        [item_20_observaciones] NVARCHAR(500) NULL,
        [item_20_foto_base64] NVARCHAR(MAX) NULL,

        [item_21_respuesta] NVARCHAR(10) NULL,
        [item_21_valor_numerico] REAL NULL,
        [item_21_observaciones] NVARCHAR(500) NULL,
        [item_21_foto_base64] NVARCHAR(MAX) NULL,

        [item_22_respuesta] NVARCHAR(10) NULL,
        [item_22_valor_numerico] REAL NULL,
        [item_22_observaciones] NVARCHAR(500) NULL,
        [item_22_foto_base64] NVARCHAR(MAX) NULL,

        [item_23_respuesta] NVARCHAR(10) NULL,
        [item_23_valor_numerico] REAL NULL,
        [item_23_observaciones] NVARCHAR(500) NULL,
        [item_23_foto_base64] NVARCHAR(MAX) NULL,

        [item_24_respuesta] NVARCHAR(10) NULL,
        [item_24_valor_numerico] REAL NULL,
        [item_24_observaciones] NVARCHAR(500) NULL,
        [item_24_foto_base64] NVARCHAR(MAX) NULL,

        [item_25_respuesta] NVARCHAR(10) NULL,
        [item_25_valor_numerico] REAL NULL,
        [item_25_observaciones] NVARCHAR(500) NULL,
        [item_25_foto_base64] NVARCHAR(MAX) NULL
    );

    PRINT 'Tabla check_cosecha creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Tabla check_cosecha ya existe';
END
GO

-- ============================================================================
-- ÍNDICES PARA OPTIMIZAR CONSULTAS
-- ============================================================================

-- Índice único por UUID
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cosecha_uuid')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [IX_check_cosecha_uuid]
    ON [dbo].[check_cosecha] ([checklist_uuid]);
    PRINT 'Índice IX_check_cosecha_uuid creado';
END

-- Índice por finca y fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cosecha_finca_fecha')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_check_cosecha_finca_fecha]
    ON [dbo].[check_cosecha] ([finca_nombre], [fecha_creacion] DESC);
    PRINT 'Índice IX_check_cosecha_finca_fecha creado';
END

-- Índice por usuario y fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cosecha_usuario_fecha')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_check_cosecha_usuario_fecha]
    ON [dbo].[check_cosecha] ([usuario_id], [fecha_creacion] DESC);
    PRINT 'Índice IX_check_cosecha_usuario_fecha creado';
END

-- Índice por fecha de envío
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cosecha_fecha_envio')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_check_cosecha_fecha_envio]
    ON [dbo].[check_cosecha] ([fecha_envio] DESC);
    PRINT 'Índice IX_check_cosecha_fecha_envio creado';
END

GO

-- ============================================================================
-- VISTA PARA CONSULTAS RESUMIDAS
-- ============================================================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_check_cosecha_resumen')
DROP VIEW [dbo].[vw_check_cosecha_resumen];
GO

CREATE VIEW [dbo].[vw_check_cosecha_resumen] AS
SELECT
    c.id,
    c.checklist_uuid,
    c.finca_nombre,
    c.bloque_nombre,
    c.variedad_nombre,
    c.usuario_nombre,
    c.fecha_creacion,
    c.fecha_envio,
    c.porcentaje_cumplimiento,

    -- Contadores dinámicos
    (SELECT COUNT(*) FROM (
        VALUES (c.item_1_respuesta), (c.item_2_respuesta), (c.item_3_respuesta),
               (c.item_4_respuesta), (c.item_5_respuesta), (c.item_6_respuesta),
               (c.item_7_respuesta), (c.item_8_respuesta), (c.item_9_respuesta),
               (c.item_10_respuesta), (c.item_11_respuesta), (c.item_12_respuesta),
               (c.item_13_respuesta), (c.item_14_respuesta), (c.item_15_respuesta),
               (c.item_16_respuesta), (c.item_17_respuesta), (c.item_18_respuesta),
               (c.item_19_respuesta), (c.item_20_respuesta), (c.item_21_respuesta),
               (c.item_22_respuesta), (c.item_23_respuesta), (c.item_24_respuesta),
               (c.item_25_respuesta)
    ) AS t(respuesta) WHERE t.respuesta IS NOT NULL AND t.respuesta != 'na') AS items_respondidos,

    (SELECT COUNT(*) FROM (
        VALUES (c.item_1_foto_base64), (c.item_2_foto_base64), (c.item_3_foto_base64),
               (c.item_4_foto_base64), (c.item_5_foto_base64), (c.item_6_foto_base64),
               (c.item_7_foto_base64), (c.item_8_foto_base64), (c.item_9_foto_base64),
               (c.item_10_foto_base64), (c.item_11_foto_base64), (c.item_12_foto_base64),
               (c.item_13_foto_base64), (c.item_14_foto_base64), (c.item_15_foto_base64),
               (c.item_16_foto_base64), (c.item_17_foto_base64), (c.item_18_foto_base64),
               (c.item_19_foto_base64), (c.item_20_foto_base64), (c.item_21_foto_base64),
               (c.item_22_foto_base64), (c.item_23_foto_base64), (c.item_24_foto_base64),
               (c.item_25_foto_base64)
    ) AS t(foto) WHERE t.foto IS NOT NULL AND LEN(t.foto) > 0) AS items_con_fotos

FROM [dbo].[check_cosecha] c;
GO

PRINT 'Vista vw_check_cosecha_resumen creada exitosamente';

-- ============================================================================
-- PROCEDIMIENTOS ALMACENADOS ÚTILES
-- ============================================================================

-- Procedimiento para obtener estadísticas generales
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_estadisticas_check_cosecha')
DROP PROCEDURE [dbo].[sp_estadisticas_check_cosecha];
GO

CREATE PROCEDURE [dbo].[sp_estadisticas_check_cosecha]
AS
BEGIN
    SELECT
        COUNT(*) AS total_checklists,
        AVG(porcentaje_cumplimiento) AS promedio_cumplimiento,
        COUNT(DISTINCT finca_nombre) AS total_fincas,
        COUNT(DISTINCT usuario_id) AS total_usuarios,
        MIN(fecha_creacion) AS primer_checklist,
        MAX(fecha_creacion) AS ultimo_checklist
    FROM [dbo].[check_cosecha]
    WHERE fecha_creacion >= DATEADD(month, -1, GETDATE());
END
GO

PRINT 'Procedimiento sp_estadisticas_check_cosecha creado exitosamente';

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================

SELECT
    'check_cosecha' AS tabla,
    COUNT(*) AS registros
FROM [dbo].[check_cosecha];

PRINT '============================================================================';
PRINT 'SCRIPT COMPLETADO EXITOSAMENTE';
PRINT 'Tabla creada: check_cosecha';
PRINT 'Vista creada: vw_check_cosecha_resumen';
PRINT 'Procedimiento creado: sp_estadisticas_check_cosecha';
PRINT 'La tabla está lista para recibir datos desde la aplicación Flutter';
PRINT '============================================================================';