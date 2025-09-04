-- ============================================================================
-- TABLA OPTIMIZADA PARA LABORES PERMANENTES
-- CHECK LIST LABORES CULTURALES PERMANENTE ROSAS
-- Código: R-CORP-CDP-GA-02
-- ============================================================================

USE Kontrollers;
GO

-- ============================================================================
-- 1. CREAR TABLA PRINCIPAL
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[check_labores_permanentes]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[check_labores_permanentes] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [id_local] INT NULL, -- ID del dispositivo móvil
        [fecha] DATETIME2(3) NOT NULL,
        [finca_nombre] NVARCHAR(100) NOT NULL,
        
        -- Campos específicos de labores permanentes
        [up_unidad_productiva] NVARCHAR(100) NULL,
        [semana] NVARCHAR(50) NULL,
        [kontroller] NVARCHAR(100) NULL,
        
        -- JSON con información de cuadrantes (supervisor, bloque, variedad, cuadrante)
        [cuadrantes_json] NVARCHAR(MAX) NOT NULL,
        
        -- JSON con resultados de la matriz de evaluación (12 items x 5 paradas por cuadrante)
        [items_json] NVARCHAR(MAX) NOT NULL,
        
        -- Métricas calculadas
        [porcentaje_cumplimiento] DECIMAL(5,2) DEFAULT 0,
        [total_evaluaciones] INT DEFAULT 0,
        [total_conformes] INT DEFAULT 0,
        [total_no_conformes] INT DEFAULT 0,
        
        -- Observaciones generales
        [observaciones_generales] NVARCHAR(MAX) NULL,
        
        -- Campos de auditoría
        [usuario_creacion] NVARCHAR(100) NOT NULL,
        [fecha_creacion] DATETIME2(3) DEFAULT GETDATE(),
        [usuario_modificacion] NVARCHAR(100) NULL,
        [fecha_modificacion] DATETIME2(3) NULL,
        
        -- Control de estado
        [activo] BIT DEFAULT 1,
        [sincronizado] BIT DEFAULT 1,
        
        -- Índice único para evitar duplicados desde el mismo dispositivo
        CONSTRAINT UK_check_labores_permanentes_local UNIQUE (id_local, usuario_creacion),
        
        -- Validaciones JSON
        CONSTRAINT CK_check_labores_permanentes_cuadrantes_json CHECK (ISJSON(cuadrantes_json) = 1),
        CONSTRAINT CK_check_labores_permanentes_items_json CHECK (ISJSON(items_json) = 1),
        
        -- Validaciones de datos
        CONSTRAINT CK_check_labores_permanentes_porcentaje CHECK (porcentaje_cumplimiento >= 0 AND porcentaje_cumplimiento <= 100),
        CONSTRAINT CK_check_labores_permanentes_evaluaciones CHECK (total_evaluaciones >= 0),
        CONSTRAINT CK_check_labores_permanentes_conformes CHECK (total_conformes >= 0),
        CONSTRAINT CK_check_labores_permanentes_no_conformes CHECK (total_no_conformes >= 0)
    );
    
    PRINT 'Tabla check_labores_permanentes creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Tabla check_labores_permanentes ya existe';
END
GO

-- ============================================================================
-- 2. CREAR ÍNDICES OPTIMIZADOS
-- ============================================================================

-- Índice por fecha para consultas temporales
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_permanentes_fecha')
BEGIN
    CREATE INDEX IX_check_labores_permanentes_fecha 
    ON [dbo].[check_labores_permanentes] (fecha DESC, activo) 
    INCLUDE (finca_nombre, kontroller, semana, porcentaje_cumplimiento);
    
    PRINT 'Índice IX_check_labores_permanentes_fecha creado exitosamente';
END

-- Índice por finca para filtros
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_permanentes_finca')
BEGIN
    CREATE INDEX IX_check_labores_permanentes_finca 
    ON [dbo].[check_labores_permanentes] (finca_nombre, activo) 
    INCLUDE (fecha, kontroller, semana, porcentaje_cumplimiento);
    
    PRINT 'Índice IX_check_labores_permanentes_finca creado exitosamente';
END

-- Índice por kontroller
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_permanentes_kontroller')
BEGIN
    CREATE INDEX IX_check_labores_permanentes_kontroller 
    ON [dbo].[check_labores_permanentes] (kontroller, activo) 
    INCLUDE (fecha, finca_nombre, semana, porcentaje_cumplimiento);
    
    PRINT 'Índice IX_check_labores_permanentes_kontroller creado exitosamente';
END

-- Índice por semana
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_permanentes_semana')
BEGIN
    CREATE INDEX IX_check_labores_permanentes_semana 
    ON [dbo].[check_labores_permanentes] (semana, activo) 
    INCLUDE (fecha, finca_nombre, kontroller, porcentaje_cumplimiento);
    
    PRINT 'Índice IX_check_labores_permanentes_semana creado exitosamente';
END

-- Índice compuesto para reportes semanales
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_permanentes_reportes_semana')
BEGIN
    CREATE INDEX IX_check_labores_permanentes_reportes_semana 
    ON [dbo].[check_labores_permanentes] (semana, fecha DESC, activo) 
    INCLUDE (finca_nombre, kontroller, porcentaje_cumplimiento, total_evaluaciones);
    
    PRINT 'Índice IX_check_labores_permanentes_reportes_semana creado exitosamente';
END

-- ============================================================================
-- 3. CREAR VISTA RESUMIDA
-- ============================================================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_check_labores_permanentes_resumen')
BEGIN
    DROP VIEW [dbo].[vw_check_labores_permanentes_resumen];
    PRINT 'Vista vw_check_labores_permanentes_resumen eliminada para recrear';
END
GO

CREATE VIEW [dbo].[vw_check_labores_permanentes_resumen] AS
SELECT 
    id,
    id_local,
    fecha,
    finca_nombre,
    up_unidad_productiva,
    semana,
    kontroller,
    
    -- Extraer información de cuadrantes desde JSON
    CASE 
        WHEN cuadrantes_json IS NOT NULL 
        THEN (SELECT COUNT(*) FROM OPENJSON(cuadrantes_json))
        ELSE 0 
    END as total_cuadrantes,
    
    -- Extraer supervisores únicos desde JSON
    CASE 
        WHEN cuadrantes_json IS NOT NULL 
        THEN (SELECT COUNT(DISTINCT JSON_VALUE(value, '$.supervisor'))
              FROM OPENJSON(cuadrantes_json)
              WHERE JSON_VALUE(value, '$.supervisor') IS NOT NULL)
        ELSE 0 
    END as supervisores_distintos,
    
    -- Extraer bloques únicos desde JSON
    CASE 
        WHEN cuadrantes_json IS NOT NULL 
        THEN (SELECT COUNT(DISTINCT JSON_VALUE(value, '$.bloque'))
              FROM OPENJSON(cuadrantes_json)
              WHERE JSON_VALUE(value, '$.bloque') IS NOT NULL)
        ELSE 0 
    END as bloques_distintos,
    
    -- Métricas de cumplimiento
    porcentaje_cumplimiento,
    total_evaluaciones,
    total_conformes,
    total_no_conformes,
    
    -- Calcular paradas totales (cuadrantes * 5 paradas)
    CASE 
        WHEN cuadrantes_json IS NOT NULL 
        THEN (SELECT COUNT(*) FROM OPENJSON(cuadrantes_json)) * 5
        ELSE 0 
    END as paradas_totales,
    
    -- Observaciones
    CASE 
        WHEN LEN(COALESCE(observaciones_generales, '')) > 0 THEN 1 
        ELSE 0 
    END as tiene_observaciones,
    
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
    END as porcentaje_calculado,
    
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
    DATEPART(WEEK, fecha) as semana_numero

FROM [dbo].[check_labores_permanentes]
WHERE activo = 1;
GO

PRINT 'Vista vw_check_labores_permanentes_resumen creada exitosamente';

-- ============================================================================
-- 4. CREAR FUNCIÓN PARA CALCULAR CUMPLIMIENTO
-- ============================================================================

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_calcular_cumplimiento_labores_permanentes' AND type = 'FN')
BEGIN
    DROP FUNCTION [dbo].[fn_calcular_cumplimiento_labores_permanentes];
    PRINT 'Función fn_calcular_cumplimiento_labores_permanentes eliminada para recrear';
END
GO

CREATE FUNCTION [dbo].[fn_calcular_cumplimiento_labores_permanentes](@checklistId INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @porcentaje DECIMAL(5,2) = 0;
    DECLARE @totalEvaluaciones INT = 0;
    DECLARE @totalConformes INT = 0;
    
    -- Obtener campos precalculados
    SELECT 
        @totalEvaluaciones = total_evaluaciones,
        @totalConformes = total_conformes
    FROM [dbo].[check_labores_permanentes] 
    WHERE id = @checklistId AND activo = 1;
    
    -- Calcular porcentaje
    IF @totalEvaluaciones > 0
    BEGIN
        SET @porcentaje = CAST(@totalConformes AS DECIMAL(10,2)) / @totalEvaluaciones * 100;
    END
    
    RETURN @porcentaje;
END
GO

PRINT 'Función fn_calcular_cumplimiento_labores_permanentes creada exitosamente';

-- ============================================================================
-- 5. CREAR TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA
-- ============================================================================

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_check_labores_permanentes_update_metrics')
BEGIN
    DROP TRIGGER [dbo].[tr_check_labores_permanentes_update_metrics];
    PRINT 'Trigger tr_check_labores_permanentes_update_metrics eliminado para recrear';
END
GO

CREATE TRIGGER [dbo].[tr_check_labores_permanentes_update_metrics]
ON [dbo].[check_labores_permanentes]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Actualizar métricas para registros modificados
    UPDATE c
    SET 
        porcentaje_cumplimiento = [dbo].[fn_calcular_cumplimiento_labores_permanentes](c.id),
        fecha_modificacion = GETDATE(),
        usuario_modificacion = COALESCE(SYSTEM_USER, 'SYSTEM')
    FROM [dbo].[check_labores_permanentes] c
    INNER JOIN inserted i ON c.id = i.id;
END
GO

PRINT 'Trigger tr_check_labores_permanentes_update_metrics creado exitosamente';

-- ============================================================================
-- 6. PROCEDIMIENTOS ALMACENADOS PRINCIPALES
-- ============================================================================

-- Procedimiento para obtener estadísticas generales
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_estadisticas_check_labores_permanentes')
BEGIN
    DROP PROCEDURE [dbo].[sp_estadisticas_check_labores_permanentes];
    PRINT 'Procedimiento sp_estadisticas_check_labores_permanentes eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_estadisticas_check_labores_permanentes]
    @fecha_inicio DATETIME2 = NULL,
    @fecha_fin DATETIME2 = NULL,
    @finca_nombre NVARCHAR(100) = NULL,
    @kontroller NVARCHAR(100) = NULL,
    @semana NVARCHAR(50) = NULL
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
        COUNT(DISTINCT kontroller) as kontrollers_activos,
        COUNT(DISTINCT semana) as semanas_evaluadas,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        MIN(COALESCE(porcentaje_cumplimiento, 0)) as min_cumplimiento,
        MAX(COALESCE(porcentaje_cumplimiento, 0)) as max_cumplimiento,
        SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones_periodo,
        SUM(COALESCE(total_conformes, 0)) as total_conformes_periodo,
        SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes_periodo
    FROM [dbo].[check_labores_permanentes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
    AND (@kontroller IS NULL OR kontroller = @kontroller)
    AND (@semana IS NULL OR semana = @semana);
    
    -- Estadísticas por finca
    SELECT 
        'Por Finca' as categoria,
        finca_nombre,
        COUNT(*) as total_checklists,
        COUNT(DISTINCT kontroller) as kontrollers_distintos,
        COUNT(DISTINCT semana) as semanas_evaluadas,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones,
        SUM(COALESCE(total_conformes, 0)) as total_conformes,
        MIN(fecha) as primera_evaluacion,
        MAX(fecha) as ultima_evaluacion
    FROM [dbo].[check_labores_permanentes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
    AND (@kontroller IS NULL OR kontroller = @kontroller)
    AND (@semana IS NULL OR semana = @semana)
    GROUP BY finca_nombre
    ORDER BY promedio_cumplimiento DESC;
    
    -- Estadísticas por kontroller
    SELECT 
        'Por Kontroller' as categoria,
        kontroller,
        COUNT(*) as total_checklists,
        COUNT(DISTINCT finca_nombre) as fincas_atendidas,
        COUNT(DISTINCT semana) as semanas_activas,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones,
        SUM(COALESCE(total_conformes, 0)) as total_conformes,
        MIN(fecha) as primera_evaluacion,
        MAX(fecha) as ultima_evaluacion
    FROM [dbo].[check_labores_permanentes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
    AND (@kontroller IS NULL OR kontroller = @kontroller)
    AND (@semana IS NULL OR semana = @semana)
    GROUP BY kontroller
    ORDER BY promedio_cumplimiento DESC;
    
    -- Estadísticas por semana
    SELECT 
        'Por Semana' as categoria,
        semana,
        COUNT(*) as total_checklists,
        COUNT(DISTINCT finca_nombre) as fincas_evaluadas,
        COUNT(DISTINCT kontroller) as kontrollers_distintos,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones,
        SUM(COALESCE(total_conformes, 0)) as total_conformes,
        MIN(fecha) as primera_evaluacion,
        MAX(fecha) as ultima_evaluacion
    FROM [dbo].[check_labores_permanentes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    AND (@finca_nombre IS NULL OR finca_nombre = @finca_nombre)
    AND (@kontroller IS NULL OR kontroller = @kontroller)
    AND (@semana IS NULL OR semana = @semana)
    GROUP BY semana
    ORDER BY semana DESC;
END
GO

PRINT 'Procedimiento sp_estadisticas_check_labores_permanentes creado exitosamente';

-- ============================================================================
-- 7. PROCEDIMIENTO PARA REPORTE DETALLADO
-- ============================================================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_reporte_detallado_labores_permanentes')
BEGIN
    DROP PROCEDURE [dbo].[sp_reporte_detallado_labores_permanentes];
    PRINT 'Procedimiento sp_reporte_detallado_labores_permanentes eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_reporte_detallado_labores_permanentes]
    @checklist_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Información general del checklist
    SELECT 
        'Información General' as seccion,
        id,
        fecha,
        finca_nombre,
        up_unidad_productiva,
        semana,
        kontroller,
        porcentaje_cumplimiento,
        total_evaluaciones,
        total_conformes,
        total_no_conformes,
        observaciones_generales,
        usuario_creacion,
        fecha_creacion
    FROM [dbo].[check_labores_permanentes]
    WHERE id = @checklist_id AND activo = 1;
    
    -- Cuadrantes del checklist
    SELECT 
        'Cuadrantes' as seccion,
        JSON_VALUE(value, '$.supervisor') as supervisor,
        JSON_VALUE(value, '$.bloque') as bloque,
        JSON_VALUE(value, '$.variedad') as variedad,
        JSON_VALUE(value, '$.cuadrante') as cuadrante
    FROM [dbo].[check_labores_permanentes] c
    CROSS APPLY OPENJSON(c.cuadrantes_json)
    WHERE c.id = @checklist_id AND c.activo = 1;
    
    -- Items de control
    SELECT 
        'Items de Control' as seccion,
        JSON_VALUE(value, '$.id') as item_id,
        JSON_VALUE(value, '$.proceso') as proceso,
        JSON_VALUE(value, '$.resultadosPorCuadranteParada') as resultados
    FROM [dbo].[check_labores_permanentes] c
    CROSS APPLY OPENJSON(c.items_json)
    WHERE c.id = @checklist_id AND c.activo = 1;
END
GO

PRINT 'Procedimiento sp_reporte_detallado_labores_permanentes creado exitosamente';

-- ============================================================================
-- 8. PROCEDIMIENTO PARA SINCRONIZACIÓN
-- ============================================================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_sincronizar_labores_permanentes')
BEGIN
    DROP PROCEDURE [dbo].[sp_sincronizar_labores_permanentes];
    PRINT 'Procedimiento sp_sincronizar_labores_permanentes eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_sincronizar_labores_permanentes]
    @usuario NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @checklists_sincronizados INT = 0;
    DECLARE @checklists_fallidos INT = 0;
    
    BEGIN TRY
        -- Marcar todos los registros como sincronizados
        UPDATE [dbo].[check_labores_permanentes]
        SET 
            sincronizado = 1,
            fecha_modificacion = GETDATE(),
            usuario_modificacion = @usuario
        WHERE sincronizado = 0 AND activo = 1;
        
        SET @checklists_sincronizados = @@ROWCOUNT;
        
        -- Retornar resultado
        SELECT 
            'Sincronización Completada' as mensaje,
            @checklists_sincronizados as registros_sincronizados,
            @checklists_fallidos as registros_fallidos,
            GETDATE() as fecha_sincronizacion,
            @usuario as usuario_sincronizacion;
            
    END TRY
    BEGIN CATCH
        SET @checklists_fallidos = 1;
        
        SELECT 
            'Error en Sincronización' as mensaje,
            ERROR_MESSAGE() as error_descripcion,
            @checklists_sincronizados as registros_sincronizados,
            @checklists_fallidos as registros_fallidos,
            GETDATE() as fecha_sincronizacion,
            @usuario as usuario_sincronizacion;
    END CATCH
END
GO

PRINT 'Procedimiento sp_sincronizar_labores_permanentes creado exitosamente';

-- ============================================================================
-- 9. PROCEDIMIENTO PARA LIMPIEZA DE DATOS
-- ============================================================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_limpiar_datos_antiguos_labores_permanentes')
BEGIN
    DROP PROCEDURE [dbo].[sp_limpiar_datos_antiguos_labores_permanentes];
    PRINT 'Procedimiento sp_limpiar_datos_antiguos_labores_permanentes eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_limpiar_datos_antiguos_labores_permanentes]
    @dias_antiguedad INT = 365,
    @usuario NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @fecha_limite DATETIME2 = DATEADD(DAY, -@dias_antiguedad, GETDATE());
    DECLARE @registros_eliminados INT = 0;
    
    BEGIN TRY
        -- Soft delete de registros antiguos ya sincronizados
        UPDATE [dbo].[check_labores_permanentes]
        SET 
            activo = 0,
            fecha_modificacion = GETDATE(),
            usuario_modificacion = @usuario
        WHERE fecha_creacion < @fecha_limite 
        AND sincronizado = 1 
        AND activo = 1;
        
        SET @registros_eliminados = @@ROWCOUNT;
        
        -- Retornar resultado
        SELECT 
            'Limpieza Completada' as mensaje,
            @registros_eliminados as registros_marcados_inactivos,
            @fecha_limite as fecha_limite_aplicada,
            GETDATE() as fecha_limpieza,
            @usuario as usuario_limpieza;
            
    END TRY
    BEGIN CATCH
        SELECT 
            'Error en Limpieza' as mensaje,
            ERROR_MESSAGE() as error_descripcion,
            @registros_eliminados as registros_marcados_inactivos,
            @fecha_limite as fecha_limite_aplicada,
            GETDATE() as fecha_limpieza,
            @usuario as usuario_limpieza;
    END CATCH
END
GO

PRINT 'Procedimiento sp_limpiar_datos_antiguos_labores_permanentes creado exitosamente';

-- ============================================================================
-- 10. PROCEDIMIENTO PARA EXPORTACIÓN DE DATOS
-- ============================================================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_exportar_labores_permanentes')
BEGIN
    DROP PROCEDURE [dbo].[sp_exportar_labores_permanentes];
    PRINT 'Procedimiento sp_exportar_labores_permanentes eliminado para recrear';
END
GO

CREATE PROCEDURE [dbo].[sp_exportar_labores_permanentes]
    @fecha_inicio DATETIME2 = NULL,
    @fecha_fin DATETIME2 = NULL,
    @formato NVARCHAR(10) = 'JSON' -- JSON, CSV, XML
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Establecer fechas por defecto si no se proporcionan
    IF @fecha_inicio IS NULL
        SET @fecha_inicio = DATEADD(YEAR, -1, GETDATE());
        
    IF @fecha_fin IS NULL
        SET @fecha_fin = GETDATE();
    
    -- Datos para exportación
    SELECT 
        id,
        id_local,
        fecha,
        finca_nombre,
        up_unidad_productiva,
        semana,
        kontroller,
        cuadrantes_json,
        items_json,
        porcentaje_cumplimiento,
        total_evaluaciones,
        total_conformes,
        total_no_conformes,
        observaciones_generales,
        usuario_creacion,
        fecha_creacion,
        fecha_modificacion,
        activo,
        sincronizado
    FROM [dbo].[check_labores_permanentes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1
    ORDER BY fecha DESC, id DESC;
    
    -- Metadatos de exportación
    SELECT 
        'Metadatos de Exportación' as tipo,
        @fecha_inicio as fecha_inicio,
        @fecha_fin as fecha_fin,
        @formato as formato_solicitado,
        GETDATE() as fecha_exportacion,
        COUNT(*) as total_registros_exportados
    FROM [dbo].[check_labores_permanentes]
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    AND activo = 1;
END
GO

PRINT 'Procedimiento sp_exportar_labores_permanentes creado exitosamente';

-- ============================================================================
-- 11. CREAR VISTAS ADICIONALES PARA REPORTES
-- ============================================================================

-- Vista para reportes semanales
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_reportes_semanales_labores_permanentes')
BEGIN
    DROP VIEW [dbo].[vw_reportes_semanales_labores_permanentes];
    PRINT 'Vista vw_reportes_semanales_labores_permanentes eliminada para recrear';
END
GO

CREATE VIEW [dbo].[vw_reportes_semanales_labores_permanentes] AS
SELECT 
    semana,
    COUNT(*) as total_checklists,
    COUNT(DISTINCT finca_nombre) as fincas_evaluadas,
    COUNT(DISTINCT kontroller) as kontrollers_activos,
    AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
    MIN(COALESCE(porcentaje_cumplimiento, 0)) as min_cumplimiento,
    MAX(COALESCE(porcentaje_cumplimiento, 0)) as max_cumplimiento,
    SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones,
    SUM(COALESCE(total_conformes, 0)) as total_conformes,
    SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes,
    MIN(fecha) as primera_evaluacion,
    MAX(fecha) as ultima_evaluacion
FROM [dbo].[check_labores_permanentes]
WHERE activo = 1 
AND semana IS NOT NULL 
AND semana != ''
GROUP BY semana;
GO

PRINT 'Vista vw_reportes_semanales_labores_permanentes creada exitosamente';

-- Vista para reportes por finca
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_reportes_por_finca_labores_permanentes')
BEGIN
    DROP VIEW [dbo].[vw_reportes_por_finca_labores_permanentes];
    PRINT 'Vista vw_reportes_por_finca_labores_permanentes eliminada para recrear';
END
GO

CREATE VIEW [dbo].[vw_reportes_por_finca_labores_permanentes] AS
SELECT 
    finca_nombre,
    COUNT(*) as total_checklists,
    COUNT(DISTINCT kontroller) as kontrollers_distintos,
    COUNT(DISTINCT semana) as semanas_evaluadas,
    AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
    MIN(COALESCE(porcentaje_cumplimiento, 0)) as min_cumplimiento,
    MAX(COALESCE(porcentaje_cumplimiento, 0)) as max_cumplimiento,
    SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones,
    SUM(COALESCE(total_conformes, 0)) as total_conformes,
    SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes,
    MIN(fecha) as primera_evaluacion,
    MAX(fecha) as ultima_evaluacion
FROM [dbo].[check_labores_permanentes]
WHERE activo = 1
GROUP BY finca_nombre;
GO

PRINT 'Vista vw_reportes_por_finca_labores_permanentes creada exitosamente';

-- ============================================================================
-- 12. SCRIPT DE VERIFICACIÓN FINAL
-- ============================================================================

PRINT '============================================================================';
PRINT 'VERIFICACIÓN FINAL DE OBJETOS CREADOS';
PRINT '============================================================================';

-- Verificar tabla
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[check_labores_permanentes]') AND type in (N'U'))
    PRINT '✓ Tabla check_labores_permanentes: OK';
ELSE
    PRINT '✗ Tabla check_labores_permanentes: ERROR';

-- Verificar índices
DECLARE @indices_count INT = 0;
SELECT @indices_count = COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[check_labores_permanentes]') AND is_primary_key = 0;
PRINT '✓ Índices creados: ' + CAST(@indices_count AS VARCHAR(10));

-- Verificar vistas
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_check_labores_permanentes_resumen')
    PRINT '✓ Vista vw_check_labores_permanentes_resumen: OK';
ELSE
    PRINT '✗ Vista vw_check_labores_permanentes_resumen: ERROR';

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_reportes_semanales_labores_permanentes')
    PRINT '✓ Vista vw_reportes_semanales_labores_permanentes: OK';
ELSE
    PRINT '✗ Vista vw_reportes_semanales_labores_permanentes: ERROR';

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_reportes_por_finca_labores_permanentes')
    PRINT '✓ Vista vw_reportes_por_finca_labores_permanentes: OK';
ELSE
    PRINT '✗ Vista vw_reportes_por_finca_labores_permanentes: ERROR';

-- Verificar función
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_calcular_cumplimiento_labores_permanentes' AND type = 'FN')
    PRINT '✓ Función fn_calcular_cumplimiento_labores_permanentes: OK';
ELSE
    PRINT '✗ Función fn_calcular_cumplimiento_labores_permanentes: ERROR';

-- Verificar trigger
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_check_labores_permanentes_update_metrics')
    PRINT '✓ Trigger tr_check_labores_permanentes_update_metrics: OK';
ELSE
    PRINT '✗ Trigger tr_check_labores_permanentes_update_metrics: ERROR';

-- Verificar procedimientos almacenados
DECLARE @procedimientos_count INT = 0;
SELECT @procedimientos_count = COUNT(*) FROM sys.procedures WHERE name LIKE '%labores_permanentes%';
PRINT '✓ Procedimientos almacenados creados: ' + CAST(@procedimientos_count AS VARCHAR(10));

PRINT '============================================================================';
PRINT 'SCRIPT DE LABORES PERMANENTES COMPLETADO EXITOSAMENTE';
PRINT '============================================================================';
GO