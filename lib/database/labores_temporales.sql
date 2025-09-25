-- ============================================================================
-- TABLA OPTIMIZADA PARA LABORES TEMPORALES
-- CHECK LIST LABORES CULTURALES TEMPORALES ROSAS
-- Código: R-CORP-CDP-GA-03
-- ============================================================================

USE Kontrollers;
GO

-- ============================================================================
-- 1. CREAR TABLA PRINCIPAL
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[check_labores_temporales]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[check_labores_temporales] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [id_local] INT NULL, -- ID del dispositivo móvil
        [fecha] DATETIME2(3) NOT NULL,
        [finca_nombre] NVARCHAR(100) NOT NULL,
        
        -- Campos específicos de labores temporales
        [up_unidad_productiva] NVARCHAR(100) NULL,
        [semana] NVARCHAR(50) NULL,
        [kontroller] NVARCHAR(100) NULL,
        
        -- JSON con información de cuadrantes (supervisor, bloque, variedad, cuadrante)
        [cuadrantes_json] NVARCHAR(MAX) NOT NULL,
        
        -- JSON con resultados de la matriz de evaluación (5 items x 5 paradas por cuadrante)
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
        [enviado] BIT DEFAULT 0,
        [fecha_envio] DATETIME2(3) NULL,
    );
    
    PRINT 'Tabla check_labores_temporales creada exitosamente';
END
ELSE
BEGIN
    PRINT 'La tabla check_labores_temporales ya existe';
END
GO

-- ============================================================================
-- 2. CREAR ÍNDICES PARA OPTIMIZACIÓN
-- ============================================================================

-- Índice para búsquedas por fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_temporales_fecha')
BEGIN
    CREATE INDEX IX_check_labores_temporales_fecha 
    ON [dbo].[check_labores_temporales] ([fecha] DESC);
    PRINT 'Índice IX_check_labores_temporales_fecha creado';
END

-- Índice para búsquedas por finca
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_temporales_finca')
BEGIN
    CREATE INDEX IX_check_labores_temporales_finca 
    ON [dbo].[check_labores_temporales] ([finca_nombre]);
    PRINT 'Índice IX_check_labores_temporales_finca creado';
END

-- Índice para búsquedas por kontroller
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_temporales_kontroller')
BEGIN
    CREATE INDEX IX_check_labores_temporales_kontroller 
    ON [dbo].[check_labores_temporales] ([kontroller]);
    PRINT 'Índice IX_check_labores_temporales_kontroller creado';
END

-- Índice para búsquedas por semana
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_temporales_semana')
BEGIN
    CREATE INDEX IX_check_labores_temporales_semana 
    ON [dbo].[check_labores_temporales] ([semana]);
    PRINT 'Índice IX_check_labores_temporales_semana creado';
END

-- Índice para búsquedas por estado de envío
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_temporales_enviado')
BEGIN
    CREATE INDEX IX_check_labores_temporales_enviado 
    ON [dbo].[check_labores_temporales] ([enviado], [activo]);
    PRINT 'Índice IX_check_labores_temporales_enviado creado';
END

-- Índice compuesto para reportes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_check_labores_temporales_reporte')
BEGIN
    CREATE INDEX IX_check_labores_temporales_reporte 
    ON [dbo].[check_labores_temporales] ([finca_nombre], [semana], [kontroller], [fecha]);
    PRINT 'Índice IX_check_labores_temporales_reporte creado';
END

GO

-- ============================================================================
-- 3. CREAR VISTAS PARA REPORTES
-- ============================================================================

-- Vista para resumen por finca
IF EXISTS (SELECT * FROM sys.views WHERE name = 'VW_LaboresTemporales_ResumenFinca')
    DROP VIEW VW_LaboresTemporales_ResumenFinca;
GO

CREATE VIEW VW_LaboresTemporales_ResumenFinca AS
SELECT 
    finca_nombre,
    COUNT(*) as total_evaluaciones,
    AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
    MAX(porcentaje_cumplimiento) as mejor_cumplimiento,
    MIN(porcentaje_cumplimiento) as peor_cumplimiento,
    COUNT(DISTINCT kontroller) as kontrollers_distintos,
    COUNT(DISTINCT semana) as semanas_evaluadas,
    SUM(total_conformes) as total_conformes,
    SUM(total_no_conformes) as total_no_conformes,
    SUM(total_evaluaciones) as total_evaluaciones_suma
FROM check_labores_temporales
WHERE activo = 1
GROUP BY finca_nombre;
GO

-- Vista para resumen por kontroller
IF EXISTS (SELECT * FROM sys.views WHERE name = 'VW_LaboresTemporales_ResumenKontroller')
    DROP VIEW VW_LaboresTemporales_ResumenKontroller;
GO

CREATE VIEW VW_LaboresTemporales_ResumenKontroller AS
SELECT 
    kontroller,
    COUNT(*) as total_evaluaciones,
    AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
    MAX(porcentaje_cumplimiento) as mejor_cumplimiento,
    MIN(porcentaje_cumplimiento) as peor_cumplimiento,
    COUNT(DISTINCT finca_nombre) as fincas_atendidas,
    COUNT(DISTINCT semana) as semanas_activas,
    SUM(total_conformes) as total_conformes,
    SUM(total_no_conformes) as total_no_conformes,
    SUM(total_evaluaciones) as total_evaluaciones_suma
FROM check_labores_temporales
WHERE activo = 1 AND kontroller IS NOT NULL
GROUP BY kontroller;
GO

-- Vista para resumen por semana
IF EXISTS (SELECT * FROM sys.views WHERE name = 'VW_LaboresTemporales_ResumenSemana')
    DROP VIEW VW_LaboresTemporales_ResumenSemana;
GO

CREATE VIEW VW_LaboresTemporales_ResumenSemana AS
SELECT 
    semana,
    COUNT(*) as total_evaluaciones,
    AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
    MAX(porcentaje_cumplimiento) as mejor_cumplimiento,
    MIN(porcentaje_cumplimiento) as peor_cumplimiento,
    COUNT(DISTINCT kontroller) as kontrollers_distintos,
    COUNT(DISTINCT finca_nombre) as fincas_evaluadas,
    SUM(total_conformes) as total_conformes,
    SUM(total_no_conformes) as total_no_conformes,
    SUM(total_evaluaciones) as total_evaluaciones_suma
FROM check_labores_temporales
WHERE activo = 1 AND semana IS NOT NULL AND semana != ''
GROUP BY semana;
GO

PRINT 'Vistas de reportes creadas exitosamente';

-- ============================================================================
-- 4. CREAR PROCEDIMIENTOS ALMACENADOS
-- ============================================================================

-- Procedimiento para obtener estadísticas generales
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'SP_LaboresTemporales_Estadisticas')
    DROP PROCEDURE SP_LaboresTemporales_Estadisticas;
GO

CREATE PROCEDURE SP_LaboresTemporales_Estadisticas
AS
BEGIN
    SELECT 
        COUNT(*) as total_checklists,
        COUNT(CASE WHEN enviado = 1 THEN 1 END) as enviados,
        COUNT(CASE WHEN enviado = 0 THEN 1 END) as pendientes,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        MAX(COALESCE(porcentaje_cumplimiento, 0)) as mejor_cumplimiento,
        MIN(COALESCE(porcentaje_cumplimiento, 0)) as menor_cumplimiento,
        COUNT(DISTINCT finca_nombre) as fincas_evaluadas,
        COUNT(DISTINCT kontroller) as kontrollers_activos,
        SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones_suma,
        SUM(COALESCE(total_conformes, 0)) as total_conformes_suma,
        SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes_suma
    FROM check_labores_temporales
    WHERE activo = 1;
END
GO

-- Procedimiento para obtener reporte por rango de fechas
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'SP_LaboresTemporales_ReporteFechas')
    DROP PROCEDURE SP_LaboresTemporales_ReporteFechas;
GO

CREATE PROCEDURE SP_LaboresTemporales_ReporteFechas
    @FechaInicio DATETIME2,
    @FechaFin DATETIME2
AS
BEGIN
    SELECT 
        fecha,
        finca_nombre,
        kontroller,
        semana,
        porcentaje_cumplimiento,
        total_evaluaciones,
        total_conformes,
        total_no_conformes,
        observaciones_generales
    FROM check_labores_temporales
    WHERE activo = 1 
        AND fecha BETWEEN @FechaInicio AND @FechaFin
    ORDER BY fecha DESC, finca_nombre, kontroller;
END
GO

-- Procedimiento para limpiar registros antiguos
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'SP_LaboresTemporales_LimpiarAntiguos')
    DROP PROCEDURE SP_LaboresTemporales_LimpiarAntiguos;
GO

CREATE PROCEDURE SP_LaboresTemporales_LimpiarAntiguos
    @DiasMantener INT = 120
AS
BEGIN
    DECLARE @FechaCorte DATETIME2 = DATEADD(DAY, -@DiasMantener, GETDATE());
    
    UPDATE check_labores_temporales
    SET activo = 0,
        fecha_modificacion = GETDATE()
    WHERE fecha_creacion < @FechaCorte 
        AND enviado = 1 
        AND activo = 1;
    
    SELECT @@ROWCOUNT as registros_marcados_eliminados;
END
GO

PRINT 'Procedimientos almacenados creados exitosamente';

-- ============================================================================
-- 5. CREAR TRIGGERS PARA AUDITORÍA
-- ============================================================================

-- Trigger para actualizar fecha de modificación
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'TR_LaboresTemporales_Update')
    DROP TRIGGER TR_LaboresTemporales_Update;
GO

CREATE TRIGGER TR_LaboresTemporales_Update
ON check_labores_temporales
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE check_labores_temporales
    SET fecha_modificacion = GETDATE()
    FROM check_labores_temporales c
    INNER JOIN inserted i ON c.id = i.id;
END
GO

PRINT 'Triggers de auditoría creados exitosamente';

-- ============================================================================
-- 6. INSERTAR DATOS DE PRUEBA (OPCIONAL)
-- ============================================================================

-- Descomentar para insertar datos de prueba
/*
INSERT INTO check_labores_temporales (
    fecha, finca_nombre, up_unidad_productiva, semana, kontroller,
    cuadrantes_json, items_json, porcentaje_cumplimiento,
    total_evaluaciones, total_conformes, total_no_conformes,
    observaciones_generales, usuario_creacion, activo, enviado
) VALUES (
    GETDATE(), 'Finca Prueba', 'UP-001', 'Semana 1', 'Kontroller Prueba',
    '[]', '[]', 85.5,
    25, 20, 5,
    'Evaluación de prueba', 'Sistema', 1, 0
);

PRINT 'Datos de prueba insertados';
*/

-- ============================================================================
-- 7. VERIFICACIÓN FINAL
-- ============================================================================

-- Verificar que la tabla fue creada correctamente
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'check_labores_temporales')
BEGIN
    PRINT '✓ Tabla check_labores_temporales creada y configurada exitosamente';
    PRINT '✓ Índices creados para optimización';
    PRINT '✓ Vistas de reportes configuradas';
    PRINT '✓ Procedimientos almacenados implementados';
    PRINT '✓ Triggers de auditoría activados';
    PRINT '';
    PRINT 'La tabla está lista para recibir datos de labores temporales.';
    PRINT 'Código: R-CORP-CDP-GA-03';
    PRINT 'Módulo: Labores Culturales Temporales';
END
ELSE
BEGIN
    PRINT '✗ Error: No se pudo crear la tabla check_labores_temporales';
END

GO
