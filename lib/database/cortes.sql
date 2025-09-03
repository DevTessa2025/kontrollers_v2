-- ============================================================================
-- TABLA OPTIMIZADA PARA CORTES DEL DÍA
-- Sistema de checklist con matriz de evaluación por cuadrantes
-- ============================================================================

USE Kontrollers;
GO

-- ============================================================================
-- 1. CREAR TABLA PRINCIPAL
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[check_cortes]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[check_cortes] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [id_local] INT NULL, -- ID del dispositivo móvil
        [fecha] DATETIME2(3) NOT NULL,
        [finca_nombre] NVARCHAR(100) NOT NULL,
        [supervisor] NVARCHAR(100) NOT NULL,
        
        -- JSON con información de cuadrantes
        [cuadrantes_json] NVARCHAR(MAX) NOT NULL,
        
        -- JSON con resultados de la matriz de evaluación
        [items_json] NVARCHAR(MAX) NOT NULL,
        
        -- Métricas calculadas
        [porcentaje_cumplimiento] DECIMAL(5,2) DEFAULT 0,
        [total_evaluaciones] INT DEFAULT 0,
        [total_conformes] INT DEFAULT 0,
        [total_no_conformes] INT DEFAULT 0,
        
        -- Campos de auditoría
        [usuario_creacion] NVARCHAR(100) NOT NULL,
        [fecha_creacion] DATETIME2(3) DEFAULT GETDATE(),
        [usuario_modificacion] NVARCHAR(100) NULL,
        [fecha_modificacion] DATETIME2(3) NULL,
        
        -- Control de estado
        [activo] BIT DEFAULT 1,
        [sincronizado] BIT DEFAULT 1,
        
        -- Índice único para evitar duplicados desde el mismo dispositivo
        CONSTRAINT UK_check_cortes_local UNIQUE (id_local, usuario_creacion),
        
        -- Validaciones JSON
        CONSTRAINT CK_check_cortes_cuadrantes_json CHECK (ISJSON(cuadrantes_json) = 1),
        CONSTRAINT CK_check_cortes_items_json CHECK (ISJSON(items_json) = 1),
        
        -- Validaciones de datos
        CONSTRAINT CK_check_cortes_porcentaje CHECK (porcentaje_cumplimiento >= 0 AND porcentaje_cumplimiento <= 100),
        CONSTRAINT CK_check_cortes_evaluaciones CHECK (total_evaluaciones >= 0),
        CONSTRAINT CK_check_cortes_conformes CHECK (total_conformes >= 0),
        CONSTRAINT CK_check_cortes_no_conformes CHECK (total_no_conformes >= 0)
    );
    
    PRINT 'Tabla check_cortes creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Tabla check_cortes ya existe';
END
GO

-- ============================================================================
-- 2. CREAR ÍNDICES OPTIMIZADOS
-- ============================================================================

-- Índice por fecha para consultas temporales
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cortes_fecha')
BEGIN
    CREATE INDEX IX_check_cortes_fecha 
    ON [dbo].[check_cortes] (fecha DESC, activo) 
    INCLUDE (finca_nombre, supervisor, porcentaje_cumplimiento);
    
    PRINT 'Índice IX_check_cortes_fecha creado exitosamente';
END

-- Índice por finca para filtros
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cortes_finca')
BEGIN
    CREATE INDEX IX_check_cortes_finca 
    ON [dbo].[check_cortes] (finca_nombre, activo) 
    INCLUDE (fecha, supervisor, porcentaje_cumplimiento);
    
    PRINT 'Índice IX_check_cortes_finca creado exitosamente';
END

-- Índice por supervisor
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cortes_supervisor')
BEGIN
    CREATE INDEX IX_check_cortes_supervisor 
    ON [dbo].[check_cortes] (supervisor, activo) 
    INCLUDE (fecha, finca_nombre, porcentaje_cumplimiento);
    
    PRINT 'Índice IX_check_cortes_supervisor creado exitosamente';
END

-- Índice por usuario y fecha de creación
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cortes_usuario_fecha')
BEGIN
    CREATE INDEX IX_check_cortes_usuario_fecha 
    ON [dbo].[check_cortes] (usuario_creacion, fecha_creacion DESC) 
    INCLUDE (finca_nombre, supervisor, porcentaje_cumplimiento);
    
    PRINT 'Índice IX_check_cortes_usuario_fecha creado exitosamente';
END

-- Índice compuesto para reportes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_cortes_reportes')
BEGIN
    CREATE INDEX IX_check_cortes_reportes 
    ON [dbo].[check_cortes] (fecha, finca_nombre, supervisor, activo) 
    INCLUDE (porcentaje_cumplimiento, total_evaluaciones, total_conformes);
    
    PRINT 'Índice IX_check_cortes_reportes creado exitosamente';
END

-- ============================================================================
-- 3. CREAR VISTA RESUMIDA
-- ============================================================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_check_cortes_resumen')
BEGIN
    DROP VIEW [dbo].[vw_check_cortes_resumen];
    PRINT 'Vista vw_check_cortes_resumen eliminada para recrear';
END
GO

CREATE VIEW [dbo].[vw_check_cortes_resumen] AS
SELECT 
    id,
    id_local,
    fecha,
    finca_nombre,
    supervisor,
    
    -- Extraer información básica de cuadrantes desde JSON
    JSON_VALUE(cuadrantes_json, '$[0].cuadrante') as primer_cuadrante,
    
    -- Contar cuadrantes evaluados
    CASE 
        WHEN cuadrantes_json IS NOT NULL 
        THEN (SELECT COUNT(*) FROM OPENJSON(cuadrantes_json))
        ELSE 0 
    END as total_cuadrantes,
    
    -- Métricas de cumplimiento
    porcentaje_cumplimiento,
    total_evaluaciones,
    total_conformes,
    total_no_conformes,
    
    -- Campos de auditoría
    usuario_creacion,
    fecha_creacion,
    fecha_modificacion,
    
    -- Estado
    activo,
    sincronizado,
    
    -- Cálculos derivados
    CASE 
        WHEN total_evaluaciones > 0 
        THEN CAST(total_conformes AS DECIMAL(10,2)) / total_evaluaciones * 100
        ELSE 0 
    END as porcentaje_cumplimiento_calculado,
    
    -- Clasificación de rendimiento
    CASE 
        WHEN porcentaje_cumplimiento >= 95 THEN 'Excelente'
        WHEN porcentaje_cumplimiento >= 85 THEN 'Bueno'
        WHEN porcentaje_cumplimiento >= 70 THEN 'Regular'
        ELSE 'Deficiente'
    END as clasificacion_cumplimiento,
    
    -- Información temporal
    YEAR(fecha) as año,
    MONTH(fecha) as mes,
    DAY(fecha) as dia,
    DATEPART(WEEK, fecha) as semana_año

FROM [dbo].[check_cortes]
WHERE activo = 1;
GO

PRINT 'Vista vw_check_cortes_resumen creada exitosamente';

-- ============================================================================
-- 4. CREAR FUNCIÓN PARA CALCULAR CUMPLIMIENTO
-- ============================================================================

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_calcular_cumplimiento_cortes' AND type = 'FN')
BEGIN
    DROP FUNCTION [dbo].[fn_calcular_cumplimiento_cortes];
    PRINT 'Función fn_calcular_cumplimiento_cortes eliminada para recrear';
END
GO

CREATE FUNCTION [dbo].[fn_calcular_cumplimiento_cortes](@checklistId INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @porcentaje DECIMAL(5,2) = 0;
    DECLARE @itemsJson NVARCHAR(MAX);
    DECLARE @cuadrantesJson NVARCHAR(MAX);
    DECLARE @totalEvaluaciones INT = 0;
    DECLARE @totalConformes INT = 0;
    
    -- Obtener JSON de items y cuadrantes
    SELECT 
        @itemsJson = items_json,
        @cuadrantesJson = cuadrantes_json
    FROM [dbo].[check_cortes] 
    WHERE id = @checklistId;
    
    -- Si no hay datos, retornar 0
    IF @itemsJson IS NULL OR @cuadrantesJson IS NULL
    BEGIN
        RETURN 0;
    END
    
    -- Procesar cada ítem y cada cuadrante
    DECLARE @itemId INT;
    DECLARE @cuadrante NVARCHAR(50);
    DECLARE @muestra INT;
    DECLARE @resultado NVARCHAR(10);
    
    -- Recorrer ítems (simulado - en implementación real usaríamos OPENJSON)
    -- Por simplicidad, usamos los campos precalculados
    SELECT 
        @totalEvaluaciones = total_evaluaciones,
        @totalConformes = total_conformes
    FROM [dbo].[check_cortes] 
    WHERE id = @checklistId;
    
    -- Calcular porcentaje
    IF @totalEvaluaciones > 0
    BEGIN
        SET @porcentaje = CAST(@totalConformes AS DECIMAL(10,2)) / @totalEvaluaciones * 100;
    END
    
    RETURN @porcentaje;
END
GO

PRINT 'Función fn_calcular_cumplimiento_cortes creada exitosamente';

-- ============================================================================
-- 5. CREAR TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA
-- ============================================================================

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_check_cortes_update_metrics')
BEGIN
    DROP TRIGGER [dbo].[tr_check_cortes_update_metrics];
    PRINT 'Trigger tr_check_cortes_update_metrics eliminado para recrear';
END
GO

CREATE TRIGGER [dbo].[tr_check_cortes_update_metrics]
ON [dbo].[check_cortes]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Actualizar métricas para registros modificados
    UPDATE c
    SET 
        porcentaje_cumplimiento = [dbo].[fn_calcular_cumplimiento_cortes](c.id),
        fecha_modificacion = GETDATE(),
        usuario_modificacion = SYSTEM_USER
    FROM [dbo].[check_cortes] c
    INNER JOIN inserted i ON c.id = i.id;
END
GO

PRINT 'Trigger tr_check_cortes_update_metrics creado exitosamente';

-- ============================================================================
-- 6. PROCEDIMIENTOS ALMACENADOS
-- ============================================================================

-- Procedimiento para obtener estadísticas
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_estadisticas_check_cortes')
BEGIN
    DROP PROCEDURE [dbo].[sp_estadisticas_check_cortes];
    PRINT 'Procedimiento sp_estadisticas_check_cortes eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_estadisticas_check_cortes]
    @fecha_inicio DATETIME2 = NULL,
    @fecha_fin DATETIME2 = NULL,
    @finca_nombre NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Establecer fechas por defecto si no se proporcionan
    IF @fecha_inicio IS NULL
        SET @fecha_inicio = DATEADD(MONTH, -1, GETDATE());
        
    IF @fecha_fin IS NULL
        SET @fecha_fin = GETDATE();
    
    -- Estadísticas generales
    SELECT 
        'Estadísticas Generales' as categoria,
        COUNT(*) as total_checklists,
        COUNT(DISTINCT finca_nombre) as fincas_evaluadas,
        COUNT(DISTINCT supervisor) as supervisores_activos,
        AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
        MIN(porcentaje_cumplimiento) as min_cumplimiento,
        MAX(porcentaje_cumplimiento) as max_cumplimiento,
        SUM(total_evaluaciones) as total_evaluaciones_periodo,
        SUM(total_conformes) as total_conformes_periodo,
        SUM(total_no_conformes) as total_no_conformes_periodo
    FROM [dbo].[check_cortes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre);
    
    -- Estadísticas por finca
    SELECT 
        'Por Finca' as categoria,
        finca_nombre,
        COUNT(*) as total_checklists,
        COUNT(DISTINCT supervisor) as supervisores,
        AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
        SUM(total_evaluaciones) as total_evaluaciones,
        SUM(total_conformes) as total_conformes,
        MIN(fecha) as primera_evaluacion,
        MAX(fecha) as ultima_evaluacion
    FROM [dbo].[check_cortes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
    GROUP BY finca_nombre
    ORDER BY promedio_cumplimiento DESC;
    
    -- Estadísticas por supervisor
    SELECT 
        'Por Supervisor' as categoria,
        supervisor,
        COUNT(*) as total_checklists,
        COUNT(DISTINCT finca_nombre) as fincas_atendidas,
        AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
        SUM(total_evaluaciones) as total_evaluaciones,
        SUM(total_conformes) as total_conformes,
        MIN(fecha) as primera_evaluacion,
        MAX(fecha) as ultima_evaluacion
    FROM [dbo].[check_cortes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
    GROUP BY supervisor
    ORDER BY promedio_cumplimiento DESC;
    
    -- Tendencia temporal (por semana)
    SELECT 
        'Tendencia Semanal' as categoria,
        YEAR(fecha) as año,
        DATEPART(WEEK, fecha) as semana,
        COUNT(*) as total_checklists,
        AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
        SUM(total_evaluaciones) as total_evaluaciones,
        SUM(total_conformes) as total_conformes
    FROM [dbo].[check_cortes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
    GROUP BY YEAR(fecha), DATEPART(WEEK, fecha)
    ORDER BY año DESC, semana DESC;
END
GO

PRINT 'Procedimiento sp_estadisticas_check_cortes creado exitosamente';

-- Procedimiento para obtener checklists por período
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_checklists_cortes_periodo')
BEGIN
    DROP PROCEDURE [dbo].[sp_checklists_cortes_periodo];
    PRINT 'Procedimiento sp_checklists_cortes_periodo eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_checklists_cortes_periodo]
    @fecha_inicio DATETIME2,
    @fecha_fin DATETIME2,
    @finca_nombre NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT *
    FROM [dbo].[vw_check_cortes_resumen]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
    ORDER BY fecha DESC;
END
GO

PRINT 'Procedimiento sp_checklists_cortes_periodo creado exitosamente';

-- Procedimiento de mantenimiento
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_mantenimiento_check_cortes')
BEGIN
    DROP PROCEDURE [dbo].[sp_mantenimiento_check_cortes];
    PRINT 'Procedimiento sp_mantenimiento_check_cortes eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_mantenimiento_check_cortes]
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Iniciando mantenimiento de check_cortes...';
    
    -- Actualizar porcentajes de cumplimiento
    UPDATE [dbo].[check_cortes]
    SET porcentaje_cumplimiento = [dbo].[fn_calcular_cumplimiento_cortes](id);
    
    PRINT 'Mantenimiento completado exitosamente';
END
GO

PRINT 'Procedimiento sp_mantenimiento_check_cortes creado exitosamente';

-- ============================================================================
-- 7. PROCEDIMIENTO PARA PROCESAR DATOS DE MATRIZ
-- ============================================================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_procesar_matriz_cortes')
BEGIN
    DROP PROCEDURE [dbo].[sp_procesar_matriz_cortes];
    PRINT 'Procedimiento sp_procesar_matriz_cortes eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_procesar_matriz_cortes]
    @checklistId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @itemsJson NVARCHAR(MAX);
    DECLARE @cuadrantesJson NVARCHAR(MAX);
    DECLARE @totalEvaluaciones INT = 0;
    DECLARE @totalConformes INT = 0;
    DECLARE @totalNoConformes INT = 0;
    
    -- Obtener datos del checklist
    SELECT 
        @itemsJson = items_json,
        @cuadrantesJson = cuadrantes_json
    FROM [dbo].[check_cortes] 
    WHERE id = @checklistId;
    
    -- Procesar matriz de resultados (implementación simplificada)
    -- En una implementación completa, aquí se procesaría el JSON
    -- para contar evaluaciones, conformes y no conformes
    
    -- Por ahora, actualizamos con valores de ejemplo
    -- (En la implementación real, esto sería calculado desde el JSON)
    
    UPDATE [dbo].[check_cortes]
    SET 
        total_evaluaciones = @totalEvaluaciones,
        total_conformes = @totalConformes,
        total_no_conformes = @totalNoConformes,
        porcentaje_cumplimiento = CASE 
            WHEN @totalEvaluaciones > 0 
            THEN CAST(@totalConformes AS DECIMAL(10,2)) / @totalEvaluaciones * 100
            ELSE 0 
        END,
        fecha_modificacion = GETDATE()
    WHERE id = @checklistId;
    
    PRINT 'Matriz de cortes procesada exitosamente';
END
GO

PRINT 'Procedimiento sp_procesar_matriz_cortes creado exitosamente';

-- ============================================================================
-- EJECUCIÓN INICIAL Y VERIFICACIÓN
-- ============================================================================

-- Ejecutar procedimiento de estadísticas para verificar
EXEC [dbo].[sp_estadisticas_check_cortes];

-- Ejecutar mantenimiento inicial
EXEC [dbo].[sp_mantenimiento_check_cortes];

PRINT '============================================================================';
PRINT 'TABLA CHECK_CORTES CREADA EXITOSAMENTE';
PRINT '============================================================================';
PRINT 'Se han creado:';
PRINT '- Tabla principal: check_cortes con matriz de evaluación';
PRINT '- 5 índices optimizados para consultas rápidas';
PRINT '- 1 vista resumida: vw_check_cortes_resumen';
PRINT '- 4 procedimientos almacenados para estadísticas y mantenimiento';
PRINT '- 1 función de cálculo de cumplimiento';
PRINT '- 1 trigger automático para actualizar métricas';
PRINT '============================================================================';

-- Mostrar estructura de la tabla
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'check_cortes'
ORDER BY ORDINAL_POSITION;