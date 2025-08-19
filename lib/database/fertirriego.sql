-- ============================================================================
-- SCRIPT DE CREACIÓN DE TABLA PARA CHECKLIST DE FERTIRRIEGO
-- Nombre de tabla: check_fertirriego (compatible con el código Flutter)
-- Base de datos: Kontrollers (SQL Server)
-- ============================================================================

USE Kontrollers;
GO

-- ============================================================================
-- TABLA PRINCIPAL: check_fertirriego
-- Almacena los checklist de fertirriego completados
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[check_fertirriego]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[check_fertirriego] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,

        -- UUID único del checklist
        [checklist_uuid] NVARCHAR(50) UNIQUE NOT NULL,

        -- Información básica del checklist
        [finca_nombre] NVARCHAR(100) NULL,
        [bloque_nombre] NVARCHAR(50) NULL,

        -- Información del usuario y fechas
        [usuario_id] INT NULL,
        [usuario_nombre] NVARCHAR(100) NULL,
        [fecha_creacion] DATETIME2(3) NOT NULL,
        [fecha_envio] DATETIME2(3) NOT NULL DEFAULT GETDATE(),

        -- Métricas del checklist
        [porcentaje_cumplimiento] REAL DEFAULT 0,

        -- Campos para cada item del checklist (23 items total)
        -- SECCIÓN: FÓRMULA DE FERTILIZACIÓN Y RECEPCIÓN DE PEDIDOS (Items 1-6)
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

        -- SECCIÓN: PREPARACIÓN (Items 7-11, 13-15)
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

        -- SECCIÓN: PROGRAMACIÓN DEL SISTEMA DE RIEGO (Items 16-17)
        [item_16_respuesta] NVARCHAR(10) NULL,
        [item_16_valor_numerico] REAL NULL,
        [item_16_observaciones] NVARCHAR(500) NULL,
        [item_16_foto_base64] NVARCHAR(MAX) NULL,

        [item_17_respuesta] NVARCHAR(10) NULL,
        [item_17_valor_numerico] REAL NULL,
        [item_17_observaciones] NVARCHAR(500) NULL,
        [item_17_foto_base64] NVARCHAR(MAX) NULL,

        -- SECCIÓN: CONTROL DE VARIABLES EN EL CAMPO (Items 18, 20-25)
        [item_18_respuesta] NVARCHAR(10) NULL,
        [item_18_valor_numerico] REAL NULL,
        [item_18_observaciones] NVARCHAR(500) NULL,
        [item_18_foto_base64] NVARCHAR(MAX) NULL,

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
    
    PRINT 'Tabla check_fertirriego creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Tabla check_fertirriego ya existe';
END
GO

-- ============================================================================
-- ÍNDICES PARA OPTIMIZACIÓN
-- ============================================================================

-- Índice para búsquedas por fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_fertirriego_fecha_creacion')
BEGIN
    CREATE INDEX IX_check_fertirriego_fecha_creacion ON [dbo].[check_fertirriego] ([fecha_creacion] DESC);
    PRINT 'Índice IX_check_fertirriego_fecha_creacion creado';
END

-- Índice para búsquedas por finca
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_fertirriego_finca')
BEGIN
    CREATE INDEX IX_check_fertirriego_finca ON [dbo].[check_fertirriego] ([finca_nombre]);
    PRINT 'Índice IX_check_fertirriego_finca creado';
END

-- Índice para búsquedas por usuario
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_fertirriego_usuario')
BEGIN
    CREATE INDEX IX_check_fertirriego_usuario ON [dbo].[check_fertirriego] ([usuario_id]);
    PRINT 'Índice IX_check_fertirriego_usuario creado';
END

-- Índice compuesto para reportes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_fertirriego_reporte')
BEGIN
    CREATE INDEX IX_check_fertirriego_reporte ON [dbo].[check_fertirriego] ([finca_nombre], [bloque_nombre], [fecha_creacion] DESC);
    PRINT 'Índice IX_check_fertirriego_reporte creado';
END

-- Índice para porcentaje de cumplimiento
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_fertirriego_cumplimiento')
BEGIN
    CREATE INDEX IX_check_fertirriego_cumplimiento ON [dbo].[check_fertirriego] ([porcentaje_cumplimiento] DESC);
    PRINT 'Índice IX_check_fertirriego_cumplimiento creado';
END

-- ============================================================================
-- VISTA RESUMIDA PARA REPORTES
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'vw_check_fertirriego_resumen')
BEGIN
    EXEC('
    CREATE VIEW [dbo].[vw_check_fertirriego_resumen] AS
    SELECT 
        id,
        checklist_uuid,
        finca_nombre,
        bloque_nombre,
        usuario_nombre,
        fecha_creacion,
        fecha_envio,
        porcentaje_cumplimiento,
        
        -- Contadores de respuestas
        (
            CASE WHEN item_1_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_2_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_3_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_4_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_5_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_6_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_7_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_8_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_9_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_10_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_11_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_13_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_14_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_15_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_16_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_17_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_18_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_20_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_21_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_22_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_23_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_24_respuesta = ''si'' THEN 1 ELSE 0 END +
            CASE WHEN item_25_respuesta = ''si'' THEN 1 ELSE 0 END
        ) as total_respuestas_si,
        
        (
            CASE WHEN item_1_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_2_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_3_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_4_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_5_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_6_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_7_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_8_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_9_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_10_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_11_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_13_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_14_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_15_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_16_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_17_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_18_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_20_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_21_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_22_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_23_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_24_respuesta = ''no'' THEN 1 ELSE 0 END +
            CASE WHEN item_25_respuesta = ''no'' THEN 1 ELSE 0 END
        ) as total_respuestas_no,
        
        (
            CASE WHEN item_1_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_2_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_3_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_4_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_5_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_6_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_7_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_8_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_9_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_10_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_11_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_13_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_14_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_15_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_16_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_17_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_18_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_20_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_21_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_22_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_23_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_24_respuesta = ''na'' THEN 1 ELSE 0 END +
            CASE WHEN item_25_respuesta = ''na'' THEN 1 ELSE 0 END
        ) as total_respuestas_na
        
    FROM [dbo].[check_fertirriego]
    ');
    
    PRINT 'Vista vw_check_fertirriego_resumen creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Vista vw_check_fertirriego_resumen ya existe';
END
GO

-- ============================================================================
-- FUNCIÓN PARA CALCULAR PORCENTAJE DE CUMPLIMIENTO
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_calcular_cumplimiento_fertirriego]') AND type in (N'FN'))
BEGIN
    EXEC('
    CREATE FUNCTION [dbo].[fn_calcular_cumplimiento_fertirriego](@checklist_id INT)
    RETURNS REAL
    AS
    BEGIN
        DECLARE @porcentaje REAL = 0;
        DECLARE @total_items INT = 0;
        DECLARE @puntaje_total REAL = 0;
        DECLARE @puntaje_maximo REAL = 0;
        
        SELECT 
            @total_items = (
                CASE WHEN item_1_respuesta IS NOT NULL AND item_1_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_2_respuesta IS NOT NULL AND item_2_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_3_respuesta IS NOT NULL AND item_3_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_4_respuesta IS NOT NULL AND item_4_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_5_respuesta IS NOT NULL AND item_5_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_6_respuesta IS NOT NULL AND item_6_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_7_respuesta IS NOT NULL AND item_7_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_8_respuesta IS NOT NULL AND item_8_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_9_respuesta IS NOT NULL AND item_9_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_10_respuesta IS NOT NULL AND item_10_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_11_respuesta IS NOT NULL AND item_11_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_13_respuesta IS NOT NULL AND item_13_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_14_respuesta IS NOT NULL AND item_14_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_15_respuesta IS NOT NULL AND item_15_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_16_respuesta IS NOT NULL AND item_16_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_17_respuesta IS NOT NULL AND item_17_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_18_respuesta IS NOT NULL AND item_18_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_20_respuesta IS NOT NULL AND item_20_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_21_respuesta IS NOT NULL AND item_21_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_22_respuesta IS NOT NULL AND item_22_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_23_respuesta IS NOT NULL AND item_23_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_24_respuesta IS NOT NULL AND item_24_respuesta != ''na'' THEN 1 ELSE 0 END +
                CASE WHEN item_25_respuesta IS NOT NULL AND item_25_respuesta != ''na'' THEN 1 ELSE 0 END
            ),
            @puntaje_maximo = @total_items * 4, -- Valor máximo por item es 4
            @puntaje_total = (
                CASE WHEN item_1_respuesta = ''si'' THEN ISNULL(item_1_valor_numerico, 4) WHEN item_1_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_2_respuesta = ''si'' THEN ISNULL(item_2_valor_numerico, 4) WHEN item_2_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_3_respuesta = ''si'' THEN ISNULL(item_3_valor_numerico, 4) WHEN item_3_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_4_respuesta = ''si'' THEN ISNULL(item_4_valor_numerico, 4) WHEN item_4_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_5_respuesta = ''si'' THEN ISNULL(item_5_valor_numerico, 4) WHEN item_5_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_6_respuesta = ''si'' THEN ISNULL(item_6_valor_numerico, 4) WHEN item_6_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_7_respuesta = ''si'' THEN ISNULL(item_7_valor_numerico, 4) WHEN item_7_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_8_respuesta = ''si'' THEN ISNULL(item_8_valor_numerico, 4) WHEN item_8_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_9_respuesta = ''si'' THEN ISNULL(item_9_valor_numerico, 4) WHEN item_9_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_10_respuesta = ''si'' THEN ISNULL(item_10_valor_numerico, 4) WHEN item_10_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_11_respuesta = ''si'' THEN ISNULL(item_11_valor_numerico, 4) WHEN item_11_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_13_respuesta = ''si'' THEN ISNULL(item_13_valor_numerico, 4) WHEN item_13_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_14_respuesta = ''si'' THEN ISNULL(item_14_valor_numerico, 4) WHEN item_14_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_15_respuesta = ''si'' THEN ISNULL(item_15_valor_numerico, 4) WHEN item_15_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_16_respuesta = ''si'' THEN ISNULL(item_16_valor_numerico, 4) WHEN item_16_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_17_respuesta = ''si'' THEN ISNULL(item_17_valor_numerico, 4) WHEN item_17_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_18_respuesta = ''si'' THEN ISNULL(item_18_valor_numerico, 4) WHEN item_18_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_20_respuesta = ''si'' THEN ISNULL(item_20_valor_numerico, 4) WHEN item_20_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_21_respuesta = ''si'' THEN ISNULL(item_21_valor_numerico, 4) WHEN item_21_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_22_respuesta = ''si'' THEN ISNULL(item_22_valor_numerico, 4) WHEN item_22_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_23_respuesta = ''si'' THEN ISNULL(item_23_valor_numerico, 4) WHEN item_23_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_24_respuesta = ''si'' THEN ISNULL(item_24_valor_numerico, 4) WHEN item_24_respuesta = ''no'' THEN 0 ELSE 0 END +
                CASE WHEN item_25_respuesta = ''si'' THEN ISNULL(item_25_valor_numerico, 4) WHEN item_25_respuesta = ''no'' THEN 0 ELSE 0 END
            )
        FROM [dbo].[check_fertirriego]
        WHERE id = @checklist_id;
        
        IF @total_items > 0 AND @puntaje_maximo > 0
            SET @porcentaje = (@puntaje_total / @puntaje_maximo) * 100;
        ELSE
            SET @porcentaje = 0;
            
        RETURN @porcentaje;
    END
    ');
    
    PRINT 'Función fn_calcular_cumplimiento_fertirriego creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Función fn_calcular_cumplimiento_fertirriego ya existe';
END
GO

-- ============================================================================
-- TRIGGER PARA ACTUALIZAR PORCENTAJE AUTOMÁTICAMENTE
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_check_fertirriego_update_porcentaje')
BEGIN
    EXEC('
    CREATE TRIGGER [dbo].[tr_check_fertirriego_update_porcentaje]
    ON [dbo].[check_fertirriego]
    AFTER INSERT, UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        
        UPDATE [dbo].[check_fertirriego]
        SET porcentaje_cumplimiento = [dbo].[fn_calcular_cumplimiento_fertirriego](id)
        WHERE id IN (SELECT id FROM inserted);
    END
    ');
    
    PRINT 'Trigger tr_check_fertirriego_update_porcentaje creado exitosamente';
END
ELSE
BEGIN
    PRINT 'Trigger tr_check_fertirriego_update_porcentaje ya existe';
END
GO

-- ============================================================================
-- PROCEDIMIENTOS ALMACENADOS
-- ============================================================================

-- Procedimiento para obtener estadísticas
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_estadisticas_check_fertirriego')
BEGIN
    EXEC('
    CREATE PROCEDURE [dbo].[sp_estadisticas_check_fertirriego]
    AS
    BEGIN
        SET NOCOUNT ON;
        
        SELECT 
            COUNT(*) as total_checklists,
            AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
            MIN(porcentaje_cumplimiento) as min_cumplimiento,
            MAX(porcentaje_cumplimiento) as max_cumplimiento,
            COUNT(DISTINCT finca_nombre) as total_fincas,
            COUNT(DISTINCT bloque_nombre) as total_bloques,
            COUNT(DISTINCT usuario_id) as total_usuarios,
            MIN(fecha_creacion) as fecha_primer_checklist,
            MAX(fecha_creacion) as fecha_ultimo_checklist
        FROM [dbo].[check_fertirriego];
        
        -- Estadísticas por finca
        SELECT 
            finca_nombre,
            COUNT(*) as cantidad_checklists,
            AVG(porcentaje_cumplimiento) as promedio_cumplimiento
        FROM [dbo].[check_fertirriego]
        WHERE finca_nombre IS NOT NULL
        GROUP BY finca_nombre
        ORDER BY promedio_cumplimiento DESC;
    END
    ');
    
    PRINT 'Procedimiento sp_estadisticas_check_fertirriego creado exitosamente';
END
ELSE
BEGIN
    PRINT 'Procedimiento sp_estadisticas_check_fertirriego ya existe';
END
GO

-- Procedimiento para obtener checklists por período
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_checklists_fertirriego_periodo')
BEGIN
    EXEC('
    CREATE PROCEDURE [dbo].[sp_checklists_fertirriego_periodo]
        @fecha_inicio DATETIME2,
        @fecha_fin DATETIME2,
        @finca_nombre NVARCHAR(100) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;
        
        SELECT *
        FROM [dbo].[vw_check_fertirriego_resumen]
        WHERE fecha_creacion BETWEEN @fecha_inicio AND @fecha_fin
        AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
        ORDER BY fecha_creacion DESC;
    END
    ');
    
    PRINT 'Procedimiento sp_checklists_fertirriego_periodo creado exitosamente';
END
ELSE
BEGIN
    PRINT 'Procedimiento sp_checklists_fertirriego_periodo ya existe';
END
GO

-- Procedimiento de mantenimiento
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_mantenimiento_check_fertirriego')
BEGIN
    EXEC('
    CREATE PROCEDURE [dbo].[sp_mantenimiento_check_fertirriego]
    AS
    BEGIN
        SET NOCOUNT ON;
        
        PRINT ''Iniciando mantenimiento de check_fertirriego...'';
        
        -- Actualizar porcentajes de cumplimiento
        UPDATE [dbo].[check_fertirriego]
        SET porcentaje_cumplimiento = [dbo].[fn_calcular_cumplimiento_fertirriego](id);
        
        PRINT ''Mantenimiento completado exitosamente'';
    END
    ');
    
    PRINT 'Procedimiento sp_mantenimiento_check_fertirriego creado exitosamente';
END
ELSE
BEGIN
    PRINT 'Procedimiento sp_mantenimiento_check_fertirriego ya existe';
END
GO

-- ============================================================================
-- EJECUCIÓN INICIAL Y VERIFICACIÓN
-- ============================================================================

-- Ejecutar procedimiento de estadísticas para verificar
EXEC [dbo].[sp_estadisticas_check_fertirriego];

-- Ejecutar mantenimiento inicial
EXEC [dbo].[sp_mantenimiento_check_fertirriego];

PRINT '============================================================================';
PRINT 'TABLA CHECK_FERTIRRIEGO CREADA EXITOSAMENTE';
PRINT '============================================================================';
PRINT 'Se han creado:';
PRINT '- Tabla principal: check_fertirriego (23 items)';
PRINT '- 5 índices optimizados';
PRINT '- 1 vista resumida: vw_check_fertirriego_resumen';
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
WHERE TABLE_NAME = 'check_fertirriego'
ORDER BY ORDINAL_POSITION;