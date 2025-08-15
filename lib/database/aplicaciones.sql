-- ============================================================================
-- SCRIPT DE CREACIÓN DE TABLA PARA CHECKLIST DE APLICACIONES
-- Nombre de tabla: check_aplicaciones (compatible con el código Flutter)
-- Base de datos: Kontrollers (SQL Server)
-- ============================================================================

USE Kontrollers;
GO

-- ============================================================================
-- TABLA PRINCIPAL: check_aplicaciones
-- Almacena los checklist de aplicaciones completados
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[check_aplicaciones]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[check_aplicaciones] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,

        -- UUID único del checklist
        [checklist_uuid] NVARCHAR(50) UNIQUE NOT NULL,

        -- Información básica del checklist
        [finca_nombre] NVARCHAR(100) NULL,
        [bloque_nombre] NVARCHAR(50) NULL,
        [bomba_nombre] NVARCHAR(100) NULL,

        -- Información del usuario y fechas
        [usuario_id] INT NULL,
        [usuario_nombre] NVARCHAR(100) NULL,
        [fecha_creacion] DATETIME2(3) NOT NULL,
        [fecha_envio] DATETIME2(3) NOT NULL DEFAULT GETDATE(),

        -- Métricas del checklist
        [porcentaje_cumplimiento] REAL DEFAULT 0,

        -- Campos para cada item del checklist (20 items total según el patrón de aplicaciones)
        -- SECCIÓN: PREPARACIÓN Y VERIFICACIÓN INICIAL (Items 1-5)
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

        -- SECCIÓN: EQUIPOS Y CALIBRACIÓN (Items 6-10)
        [item_6_respuesta] NVARCHAR(10) NULL,
        [item_6_valor_numerico] REAL NULL,
        [item_6_observaciones] NVARCHAR(500) NULL,
        [item_6_foto_base64] NVARCHAR(MAX) NULL,

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

        -- SECCIÓN: APLICACIÓN Y PROCESO (Items 11-15)
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

        -- SECCIÓN: VERIFICACIÓN FINAL Y LIMPIEZA (Items 16-20)
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

        [item_19_respuesta] NVARCHAR(10) NULL,
        [item_19_valor_numerico] REAL NULL,
        [item_19_observaciones] NVARCHAR(500) NULL,
        [item_19_foto_base64] NVARCHAR(MAX) NULL,

        [item_20_respuesta] NVARCHAR(10) NULL,
        [item_20_valor_numerico] REAL NULL,
        [item_20_observaciones] NVARCHAR(500) NULL,
        [item_20_foto_base64] NVARCHAR(MAX) NULL,

        -- Campos adicionales por si se necesitan más items en el futuro
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
        [item_25_foto_base64] NVARCHAR(MAX) NULL,

        -- Items adicionales 26-40
        [item_26_respuesta] NVARCHAR(10) NULL,
        [item_26_valor_numerico] REAL NULL,
        [item_26_observaciones] NVARCHAR(500) NULL,
        [item_26_foto_base64] NVARCHAR(MAX) NULL,

        [item_27_respuesta] NVARCHAR(10) NULL,
        [item_27_valor_numerico] REAL NULL,
        [item_27_observaciones] NVARCHAR(500) NULL,
        [item_27_foto_base64] NVARCHAR(MAX) NULL,

        [item_28_respuesta] NVARCHAR(10) NULL,
        [item_28_valor_numerico] REAL NULL,
        [item_28_observaciones] NVARCHAR(500) NULL,
        [item_28_foto_base64] NVARCHAR(MAX) NULL,

        [item_29_respuesta] NVARCHAR(10) NULL,
        [item_29_valor_numerico] REAL NULL,
        [item_29_observaciones] NVARCHAR(500) NULL,
        [item_29_foto_base64] NVARCHAR(MAX) NULL,

        [item_30_respuesta] NVARCHAR(10) NULL,
        [item_30_valor_numerico] REAL NULL,
        [item_30_observaciones] NVARCHAR(500) NULL,
        [item_30_foto_base64] NVARCHAR(MAX) NULL,

        [item_31_respuesta] NVARCHAR(10) NULL,
        [item_31_valor_numerico] REAL NULL,
        [item_31_observaciones] NVARCHAR(500) NULL,
        [item_31_foto_base64] NVARCHAR(MAX) NULL,

        [item_32_respuesta] NVARCHAR(10) NULL,
        [item_32_valor_numerico] REAL NULL,
        [item_32_observaciones] NVARCHAR(500) NULL,
        [item_32_foto_base64] NVARCHAR(MAX) NULL,

        [item_33_respuesta] NVARCHAR(10) NULL,
        [item_33_valor_numerico] REAL NULL,
        [item_33_observaciones] NVARCHAR(500) NULL,
        [item_33_foto_base64] NVARCHAR(MAX) NULL,

        [item_34_respuesta] NVARCHAR(10) NULL,
        [item_34_valor_numerico] REAL NULL,
        [item_34_observaciones] NVARCHAR(500) NULL,
        [item_34_foto_base64] NVARCHAR(MAX) NULL,

        [item_35_respuesta] NVARCHAR(10) NULL,
        [item_35_valor_numerico] REAL NULL,
        [item_35_observaciones] NVARCHAR(500) NULL,
        [item_35_foto_base64] NVARCHAR(MAX) NULL,

        [item_36_respuesta] NVARCHAR(10) NULL,
        [item_36_valor_numerico] REAL NULL,
        [item_36_observaciones] NVARCHAR(500) NULL,
        [item_36_foto_base64] NVARCHAR(MAX) NULL,

        [item_37_respuesta] NVARCHAR(10) NULL,
        [item_37_valor_numerico] REAL NULL,
        [item_37_observaciones] NVARCHAR(500) NULL,
        [item_37_foto_base64] NVARCHAR(MAX) NULL,

        [item_38_respuesta] NVARCHAR(10) NULL,
        [item_38_valor_numerico] REAL NULL,
        [item_38_observaciones] NVARCHAR(500) NULL,
        [item_38_foto_base64] NVARCHAR(MAX) NULL,

        [item_39_respuesta] NVARCHAR(10) NULL,
        [item_39_valor_numerico] REAL NULL,
        [item_39_observaciones] NVARCHAR(500) NULL,
        [item_39_foto_base64] NVARCHAR(MAX) NULL,

        [item_40_respuesta] NVARCHAR(10) NULL,
        [item_40_valor_numerico] REAL NULL,
        [item_40_observaciones] NVARCHAR(500) NULL,
        [item_40_foto_base64] NVARCHAR(MAX) NULL
    );

    PRINT 'Tabla check_aplicaciones creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Tabla check_aplicaciones ya existe';
END
GO

-- ============================================================================
-- ÍNDICES PARA OPTIMIZAR CONSULTAS
-- ============================================================================

-- Índice único por UUID
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_aplicaciones_uuid')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [IX_check_aplicaciones_uuid]
    ON [dbo].[check_aplicaciones] ([checklist_uuid]);
    PRINT 'Índice IX_check_aplicaciones_uuid creado';
END

-- Índice por finca y fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_aplicaciones_finca_fecha')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_check_aplicaciones_finca_fecha]
    ON [dbo].[check_aplicaciones] ([finca_nombre], [fecha_creacion] DESC);
    PRINT 'Índice IX_check_aplicaciones_finca_fecha creado';
END

-- Índice por usuario y fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_aplicaciones_usuario_fecha')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_check_aplicaciones_usuario_fecha]
    ON [dbo].[check_aplicaciones] ([usuario_id], [fecha_creacion] DESC);
    PRINT 'Índice IX_check_aplicaciones_usuario_fecha creado';
END

-- Índice por fecha de envío
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_aplicaciones_fecha_envio')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_check_aplicaciones_fecha_envio]
    ON [dbo].[check_aplicaciones] ([fecha_envio] DESC);
    PRINT 'Índice IX_check_aplicaciones_fecha_envio creado';
END

-- Índice compuesto por finca, bloque y bomba
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_aplicaciones_finca_bloque_bomba')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_check_aplicaciones_finca_bloque_bomba]
    ON [dbo].[check_aplicaciones] ([finca_nombre], [bloque_nombre], [bomba_nombre]);
    PRINT 'Índice IX_check_aplicaciones_finca_bloque_bomba creado';
END

GO

-- ============================================================================
-- VISTA PARA CONSULTAS RESUMIDAS
-- ============================================================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_check_aplicaciones_resumen')
DROP VIEW [dbo].[vw_check_aplicaciones_resumen];
GO

CREATE VIEW [dbo].[vw_check_aplicaciones_resumen] AS
SELECT
    c.id,
    c.checklist_uuid,
    c.finca_nombre,
    c.bloque_nombre,
    c.bomba_nombre,
    c.usuario_nombre,
    c.fecha_creacion,
    c.fecha_envio,
    c.porcentaje_cumplimiento,

    -- Contadores dinámicos para 40 items
    (SELECT COUNT(*) FROM (
        VALUES (c.item_1_respuesta), (c.item_2_respuesta), (c.item_3_respuesta),
               (c.item_4_respuesta), (c.item_5_respuesta), (c.item_6_respuesta),
               (c.item_7_respuesta), (c.item_8_respuesta), (c.item_9_respuesta),
               (c.item_10_respuesta), (c.item_11_respuesta), (c.item_12_respuesta),
               (c.item_13_respuesta), (c.item_14_respuesta), (c.item_15_respuesta),
               (c.item_16_respuesta), (c.item_17_respuesta), (c.item_18_respuesta),
               (c.item_19_respuesta), (c.item_20_respuesta), (c.item_21_respuesta),
               (c.item_22_respuesta), (c.item_23_respuesta), (c.item_24_respuesta),
               (c.item_25_respuesta), (c.item_26_respuesta), (c.item_27_respuesta),
               (c.item_28_respuesta), (c.item_29_respuesta), (c.item_30_respuesta),
               (c.item_31_respuesta), (c.item_32_respuesta), (c.item_33_respuesta),
               (c.item_34_respuesta), (c.item_35_respuesta), (c.item_36_respuesta),
               (c.item_37_respuesta), (c.item_38_respuesta), (c.item_39_respuesta),
               (c.item_40_respuesta)
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
               (c.item_25_foto_base64), (c.item_26_foto_base64), (c.item_27_foto_base64),
               (c.item_28_foto_base64), (c.item_29_foto_base64), (c.item_30_foto_base64),
               (c.item_31_foto_base64), (c.item_32_foto_base64), (c.item_33_foto_base64),
               (c.item_34_foto_base64), (c.item_35_foto_base64), (c.item_36_foto_base64),
               (c.item_37_foto_base64), (c.item_38_foto_base64), (c.item_39_foto_base64),
               (c.item_40_foto_base64)
    ) AS t(foto) WHERE t.foto IS NOT NULL AND LEN(t.foto) > 0) AS items_con_fotos

FROM [dbo].[check_aplicaciones] c;
GO

PRINT 'Vista vw_check_aplicaciones_resumen creada exitosamente';

-- ============================================================================
-- PROCEDIMIENTOS ALMACENADOS ÚTILES
-- ============================================================================

-- Procedimiento para obtener estadísticas generales
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_estadisticas_check_aplicaciones')
DROP PROCEDURE [dbo].[sp_estadisticas_check_aplicaciones];
GO

CREATE PROCEDURE [dbo].[sp_estadisticas_check_aplicaciones]
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        COUNT(*) as total_checklists,
        COUNT(DISTINCT finca_nombre) as total_fincas,
        COUNT(DISTINCT bloque_nombre) as total_bloques,
        COUNT(DISTINCT bomba_nombre) as total_bombas,
        AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
        MIN(fecha_creacion) as fecha_primer_checklist,
        MAX(fecha_creacion) as fecha_ultimo_checklist
    FROM [dbo].[check_aplicaciones];
    
    -- Estadísticas por finca
    SELECT 
        finca_nombre,
        COUNT(*) as total_checklists,
        AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
        MAX(fecha_creacion) as ultimo_checklist
    FROM [dbo].[check_aplicaciones]
    GROUP BY finca_nombre
    ORDER BY COUNT(*) DESC;
END
GO

-- Procedimiento para obtener checklists por fecha
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_checklists_por_fecha_aplicaciones')
DROP PROCEDURE [dbo].[sp_checklists_por_fecha_aplicaciones];
GO

CREATE PROCEDURE [dbo].[sp_checklists_por_fecha_aplicaciones]
    @FechaInicio DATETIME2,
    @FechaFin DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT *
    FROM [dbo].[vw_check_aplicaciones_resumen]
    WHERE fecha_creacion BETWEEN @FechaInicio AND @FechaFin
    ORDER BY fecha_creacion DESC;
END
GO

-- Procedimiento para obtener checklists por finca
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_checklists_por_finca_aplicaciones')
DROP PROCEDURE [dbo].[sp_checklists_por_finca_aplicaciones];
GO

CREATE PROCEDURE [dbo].[sp_checklists_por_finca_aplicaciones]
    @Finca NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT *
    FROM [dbo].[vw_check_aplicaciones_resumen]
    WHERE finca_nombre = @Finca
    ORDER BY fecha_creacion DESC;
END
GO

-- ============================================================================
-- FUNCIÓN PARA CALCULAR PORCENTAJE DE CUMPLIMIENTO
-- ============================================================================

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_calcular_cumplimiento_aplicaciones')
DROP FUNCTION [dbo].[fn_calcular_cumplimiento_aplicaciones];
GO

CREATE FUNCTION [dbo].[fn_calcular_cumplimiento_aplicaciones](@ChecklistId INT)
RETURNS REAL
AS
BEGIN
    DECLARE @TotalItems INT = 40; -- Cambiado a 40 items
    DECLARE @ItemsRespondidos INT;
    DECLARE @Cumplimiento REAL;
    
    SELECT @ItemsRespondidos = (
        SELECT COUNT(*) FROM (
            VALUES (item_1_respuesta), (item_2_respuesta), (item_3_respuesta),
                   (item_4_respuesta), (item_5_respuesta), (item_6_respuesta),
                   (item_7_respuesta), (item_8_respuesta), (item_9_respuesta),
                   (item_10_respuesta), (item_11_respuesta), (item_12_respuesta),
                   (item_13_respuesta), (item_14_respuesta), (item_15_respuesta),
                   (item_16_respuesta), (item_17_respuesta), (item_18_respuesta),
                   (item_19_respuesta), (item_20_respuesta), (item_21_respuesta),
                   (item_22_respuesta), (item_23_respuesta), (item_24_respuesta),
                   (item_25_respuesta), (item_26_respuesta), (item_27_respuesta),
                   (item_28_respuesta), (item_29_respuesta), (item_30_respuesta),
                   (item_31_respuesta), (item_32_respuesta), (item_33_respuesta),
                   (item_34_respuesta), (item_35_respuesta), (item_36_respuesta),
                   (item_37_respuesta), (item_38_respuesta), (item_39_respuesta),
                   (item_40_respuesta)
        ) AS t(respuesta) WHERE t.respuesta IS NOT NULL AND t.respuesta != 'na'
    )
    FROM [dbo].[check_aplicaciones]
    WHERE id = @ChecklistId;
    
    SET @Cumplimiento = CASE 
        WHEN @TotalItems > 0 THEN CAST(@ItemsRespondidos AS REAL) / @TotalItems * 100
        ELSE 0 
    END;
    
    RETURN @Cumplimiento;
END
GO

-- ============================================================================
-- TRIGGER PARA ACTUALIZAR AUTOMÁTICAMENTE EL PORCENTAJE DE CUMPLIMIENTO
-- ============================================================================

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_update_cumplimiento_aplicaciones')
DROP TRIGGER [dbo].[tr_update_cumplimiento_aplicaciones];
GO

CREATE TRIGGER [dbo].[tr_update_cumplimiento_aplicaciones]
ON [dbo].[check_aplicaciones]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE c
    SET porcentaje_cumplimiento = [dbo].[fn_calcular_cumplimiento_aplicaciones](c.id)
    FROM [dbo].[check_aplicaciones] c
    INNER JOIN inserted i ON c.id = i.id;
END
GO

-- ============================================================================
-- PROCEDIMIENTO DE MANTENIMIENTO
-- ============================================================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_mantenimiento_check_aplicaciones')
DROP PROCEDURE [dbo].[sp_mantenimiento_check_aplicaciones];
GO

CREATE PROCEDURE [dbo].[sp_mantenimiento_check_aplicaciones]
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Iniciando mantenimiento de check_aplicaciones...';
    
    -- Actualizar estadísticas de la tabla
    UPDATE STATISTICS [dbo].[check_aplicaciones] WITH FULLSCAN;
    
    -- Recalcular porcentajes de cumplimiento
    UPDATE [dbo].[check_aplicaciones]
    SET porcentaje_cumplimiento = [dbo].[fn_calcular_cumplimiento_aplicaciones](id);
    
    PRINT 'Mantenimiento completado exitosamente';
END
GO

-- ============================================================================
-- EJECUCIÓN INICIAL Y VERIFICACIÓN
-- ============================================================================

-- Ejecutar procedimiento de estadísticas para verificar
EXEC [dbo].[sp_estadisticas_check_aplicaciones];

-- Ejecutar mantenimiento inicial
EXEC [dbo].[sp_mantenimiento_check_aplicaciones];

PRINT '============================================================================';
PRINT 'TABLA CHECK_APLICACIONES CREADA EXITOSAMENTE';
PRINT '============================================================================';
PRINT 'Se han creado:';
PRINT '- Tabla principal: check_aplicaciones (40 items)';
PRINT '- 5 índices optimizados';
PRINT '- 1 vista resumida: vw_check_aplicaciones_resumen';
PRINT '- 3 procedimientos almacenados';
PRINT '- 1 función de cálculo de cumplimiento';
PRINT '- 1 trigger automático para actualizar porcentajes';
PRINT '============================================================================';

-- Mostrar estructura de la tabla
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'check_aplicaciones'
ORDER BY ORDINAL_POSITION;



--#################################################################################################################
-- ============================================================================
-- TABLA OPTIMIZADA PARA APLICACIONES
-- Extrae datos únicos de base_MIPE para mejorar performance
-- ============================================================================

USE Kontrollers;
GO

-- ============================================================================
-- 1. CREAR TABLA OPTIMIZADA
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[aplicaciones_data]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[aplicaciones_data] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [finca] NVARCHAR(100) NOT NULL,
        [bloque] NVARCHAR(50) NOT NULL,
        [bomba] NVARCHAR(100) NOT NULL,
        [activo] BIT DEFAULT 1,
        [fecha_creacion] DATETIME2(3) DEFAULT GETDATE(),
        [fecha_actualizacion] DATETIME2(3) DEFAULT GETDATE(),
        
        -- Constraint único para evitar duplicados
        CONSTRAINT UK_aplicaciones_data_unique UNIQUE (finca, bloque, bomba)
    );
    
    PRINT 'Tabla aplicaciones_data creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Tabla aplicaciones_data ya existe';
END
GO

-- ============================================================================
-- 2. CREAR ÍNDICES PARA OPTIMIZAR CONSULTAS
-- ============================================================================

-- Índice por finca
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_aplicaciones_data_finca')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_aplicaciones_data_finca]
    ON [dbo].[aplicaciones_data] ([finca]) 
    WHERE [activo] = 1;
    PRINT 'Índice IX_aplicaciones_data_finca creado';
END

-- Índice por finca y bloque
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_aplicaciones_data_finca_bloque')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_aplicaciones_data_finca_bloque]
    ON [dbo].[aplicaciones_data] ([finca], [bloque]) 
    WHERE [activo] = 1;
    PRINT 'Índice IX_aplicaciones_data_finca_bloque creado';
END

-- Índice por fecha de actualización
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_aplicaciones_data_fecha_actualizacion')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_aplicaciones_data_fecha_actualizacion]
    ON [dbo].[aplicaciones_data] ([fecha_actualizacion] DESC);
    PRINT 'Índice IX_aplicaciones_data_fecha_actualizacion creado';
END
GO

-- ============================================================================
-- 3. POBLAR TABLA CON DATOS ÚNICOS DE base_MIPE
-- ============================================================================

-- Limpiar tabla si existe data previa
TRUNCATE TABLE [dbo].[aplicaciones_data];

-- Insertar datos únicos con el registro más reciente por DT_LOAD
INSERT INTO [dbo].[aplicaciones_data] (finca, bloque, bomba, activo, fecha_creacion, fecha_actualizacion)
SELECT DISTINCT
    b.FINCA as finca,
    CAST(b.BLOQUE as NVARCHAR(50)) as bloque,
    b.NUMERO_O_CODIGO_DE_LA_BOMBA as bomba,
    1 as activo,
    GETDATE() as fecha_creacion,
    GETDATE() as fecha_actualizacion
FROM [Kontrollers].[dbo].[base_MIPE] b
INNER JOIN (
    -- Subconsulta para obtener el registro más reciente por combinación
    SELECT 
        FINCA, 
        BLOQUE, 
        NUMERO_O_CODIGO_DE_LA_BOMBA, 
        MAX(DT_LOAD) as max_dt_load
    FROM [Kontrollers].[dbo].[base_MIPE]
    WHERE FINCA IS NOT NULL 
      AND FINCA != ''
      AND BLOQUE IS NOT NULL 
      AND BLOQUE != ''
      AND NUMERO_O_CODIGO_DE_LA_BOMBA IS NOT NULL 
      AND NUMERO_O_CODIGO_DE_LA_BOMBA != ''
    GROUP BY FINCA, BLOQUE, NUMERO_O_CODIGO_DE_LA_BOMBA
) latest ON b.FINCA = latest.FINCA
        AND b.BLOQUE = latest.BLOQUE
        AND b.NUMERO_O_CODIGO_DE_LA_BOMBA = latest.NUMERO_O_CODIGO_DE_LA_BOMBA
        AND b.DT_LOAD = latest.max_dt_load
WHERE b.FINCA IS NOT NULL 
  AND b.FINCA != ''
  AND b.BLOQUE IS NOT NULL 
  AND b.BLOQUE != ''
  AND b.NUMERO_O_CODIGO_DE_LA_BOMBA IS NOT NULL 
  AND b.NUMERO_O_CODIGO_DE_LA_BOMBA != '';

-- Mostrar estadísticas de la inserción
SELECT 
    COUNT(*) as total_registros,
    COUNT(DISTINCT finca) as total_fincas,
    COUNT(DISTINCT CONCAT(finca, '-', bloque)) as total_bloques,
    MIN(fecha_creacion) as primera_insercion,
    MAX(fecha_actualizacion) as ultima_actualizacion
FROM [dbo].[aplicaciones_data];

PRINT 'Datos insertados exitosamente en aplicaciones_data';
GO

-- ============================================================================
-- 4. CREAR VISTAS PARA CONSULTAS RÁPIDAS
-- ============================================================================

-- Vista para obtener fincas únicas
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_aplicaciones_fincas')
    DROP VIEW [dbo].[vw_aplicaciones_fincas];
GO

CREATE VIEW [dbo].[vw_aplicaciones_fincas] AS
SELECT DISTINCT 
    finca as nombre,
    COUNT(*) as total_registros,
    MAX(fecha_actualizacion) as ultima_actualizacion
FROM [dbo].[aplicaciones_data] 
WHERE activo = 1
GROUP BY finca;
GO

-- Vista para obtener bloques por finca
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_aplicaciones_bloques')
    DROP VIEW [dbo].[vw_aplicaciones_bloques];
GO

CREATE VIEW [dbo].[vw_aplicaciones_bloques] AS
SELECT DISTINCT 
    finca,
    bloque as nombre,
    COUNT(*) as total_bombas,
    MAX(fecha_actualizacion) as ultima_actualizacion
FROM [dbo].[aplicaciones_data] 
WHERE activo = 1
GROUP BY finca, bloque;
GO

-- Vista para obtener bombas por finca y bloque
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_aplicaciones_bombas')
    DROP VIEW [dbo].[vw_aplicaciones_bombas];
GO

CREATE VIEW [dbo].[vw_aplicaciones_bombas] AS
SELECT 
    finca,
    bloque,
    bomba as nombre,
    fecha_actualizacion
FROM [dbo].[aplicaciones_data] 
WHERE activo = 1;
GO

-- ============================================================================
-- 5. QUERIES OPTIMIZADAS PARA LA APP
-- ============================================================================

-- Query para obtener fincas (SÚPER RÁPIDA)
/*
SELECT nombre 
FROM vw_aplicaciones_fincas 
ORDER BY nombre;
*/

-- Query para obtener bloques por finca (SÚPER RÁPIDA)
/*
SELECT nombre 
FROM vw_aplicaciones_bloques 
WHERE finca = 'NOMBRE_FINCA' 
ORDER BY 
    CASE WHEN ISNUMERIC(nombre) = 1 THEN CAST(nombre AS INT) ELSE 999999 END,
    nombre;
*/

-- Query para obtener bombas por finca y bloque (SÚPER RÁPIDA)
/*
SELECT nombre 
FROM vw_aplicaciones_bombas 
WHERE finca = 'NOMBRE_FINCA' AND bloque = 'NOMBRE_BLOQUE' 
ORDER BY 
    CASE WHEN ISNUMERIC(nombre) = 1 THEN CAST(nombre AS INT) ELSE 999999 END,
    nombre;
*/

-- ============================================================================
-- 6. PROCEDIMIENTO PARA ACTUALIZAR DATOS (OPCIONAL)
-- ============================================================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_update_aplicaciones_data')
    DROP PROCEDURE [dbo].[sp_update_aplicaciones_data];
GO

CREATE PROCEDURE [dbo].[sp_update_aplicaciones_data]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @affected_rows INT = 0;
    
    BEGIN TRY
        -- Marcar registros existentes como posiblemente obsoletos
        UPDATE [dbo].[aplicaciones_data] 
        SET activo = 0, fecha_actualizacion = GETDATE()
        WHERE activo = 1;
        
        -- Insertar/actualizar con datos frescos de base_MIPE
        MERGE [dbo].[aplicaciones_data] AS target
        USING (
            SELECT DISTINCT
                b.FINCA as finca,
                CAST(b.BLOQUE as NVARCHAR(50)) as bloque,
                b.NUMERO_O_CODIGO_DE_LA_BOMBA as bomba
            FROM [Kontrollers].[dbo].[base_MIPE] b
            INNER JOIN (
                SELECT 
                    FINCA, 
                    BLOQUE, 
                    NUMERO_O_CODIGO_DE_LA_BOMBA, 
                    MAX(DT_LOAD) as max_dt_load
                FROM [Kontrollers].[dbo].[base_MIPE]
                WHERE FINCA IS NOT NULL 
                  AND FINCA != ''
                  AND BLOQUE IS NOT NULL 
                  AND BLOQUE != ''
                  AND NUMERO_O_CODIGO_DE_LA_BOMBA IS NOT NULL 
                  AND NUMERO_O_CODIGO_DE_LA_BOMBA != ''
                GROUP BY FINCA, BLOQUE, NUMERO_O_CODIGO_DE_LA_BOMBA
            ) latest ON b.FINCA = latest.FINCA
                    AND b.BLOQUE = latest.BLOQUE
                    AND b.NUMERO_O_CODIGO_DE_LA_BOMBA = latest.NUMERO_O_CODIGO_DE_LA_BOMBA
                    AND b.DT_LOAD = latest.max_dt_load
            WHERE b.FINCA IS NOT NULL 
              AND b.FINCA != ''
              AND b.BLOQUE IS NOT NULL 
              AND b.BLOQUE != ''
              AND b.NUMERO_O_CODIGO_DE_LA_BOMBA IS NOT NULL 
              AND b.NUMERO_O_CODIGO_DE_LA_BOMBA != ''
        ) AS source ON target.finca = source.finca 
                    AND target.bloque = source.bloque 
                    AND target.bomba = source.bomba
        WHEN MATCHED THEN
            UPDATE SET 
                activo = 1,
                fecha_actualizacion = GETDATE()
        WHEN NOT MATCHED THEN
            INSERT (finca, bloque, bomba, activo, fecha_creacion, fecha_actualizacion)
            VALUES (source.finca, source.bloque, source.bomba, 1, GETDATE(), GETDATE());
        
        SET @affected_rows = @@ROWCOUNT;
        
        -- Eliminar registros que ya no existen en base_MIPE
        DELETE FROM [dbo].[aplicaciones_data] WHERE activo = 0;
        
        PRINT 'Actualización completada exitosamente';
        PRINT 'Registros afectados: ' + CAST(@affected_rows AS VARCHAR(10));
        PRINT 'Tiempo transcurrido: ' + CAST(DATEDIFF(MILLISECOND, @start_time, GETDATE()) AS VARCHAR(10)) + ' ms';
        
    END TRY
    BEGIN CATCH
        PRINT 'Error durante la actualización: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

-- ============================================================================
-- 7. ESTADÍSTICAS FINALES
-- ============================================================================

SELECT 
    'aplicaciones_data' as tabla,
    COUNT(*) as total_registros,
    COUNT(DISTINCT finca) as total_fincas,
    COUNT(DISTINCT CONCAT(finca, '-', bloque)) as combinaciones_finca_bloque,
    MIN(fecha_creacion) as fecha_creacion_tabla,
    MAX(fecha_actualizacion) as ultima_actualizacion
FROM [dbo].[aplicaciones_data]
WHERE activo = 1;

PRINT '============================================================================';
PRINT 'TABLA APLICACIONES_DATA CREADA Y POBLADA EXITOSAMENTE';
PRINT 'Usa las vistas vw_aplicaciones_* para consultas ultra-rápidas';
PRINT 'Ejecuta sp_update_aplicaciones_data para actualizar datos periódicamente';
PRINT '============================================================================';