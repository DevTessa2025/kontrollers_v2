
USE Kontrollers;
GO

CREATE TABLE dbo.observaciones_adicionales (
  id                INT IDENTITY(1,1) PRIMARY KEY,
  id_local          INT NULL,            -- ID local en el dispositivo (para upsert)
  fecha             DATETIME NULL,
  finca_nombre      NVARCHAR(150) NOT NULL,
  bloque_nombre     NVARCHAR(150) NOT NULL,
  variedad_nombre   NVARCHAR(150) NOT NULL,
  tipo              NVARCHAR(20)  NOT NULL,  -- MIPE | CULTIVO | MIRFE
  observacion       NVARCHAR(MAX) NOT NULL,
  imagenes_json     NVARCHAR(MAX) NULL,      -- arreglo JSON de cadenas base64
  usuario_creacion  NVARCHAR(100) NOT NULL,  -- username
  usuario_nombre    NVARCHAR(150) NULL,      -- nombre legible si se tiene
  fecha_creacion    DATETIME      NOT NULL DEFAULT(GETDATE()),
  fecha_actualizacion DATETIME NULL,
  fecha_envio       DATETIME NULL,
  enviado           BIT          NOT NULL DEFAULT(0),
  activo            BIT          NOT NULL DEFAULT(1),

  -- Campos específicos MIPE
  blanco_biologico  NVARCHAR(200) NULL,
  incidencia        DECIMAL(5,2)  NULL,     -- porcentaje
  severidad         DECIMAL(5,2)  NULL,     -- porcentaje
  tercio            NVARCHAR(10)  NULL      -- Alto | Medio | Bajo
);

-- Índices y constraint útil para upsert por id_local
CREATE UNIQUE INDEX UX_observaciones_adicionales_id_local 
  ON dbo.observaciones_adicionales(id_local) 
  WHERE id_local IS NOT NULL;

-- Índices de consulta comunes
CREATE INDEX IX_observaciones_adicionales_usuario_fecha 
  ON dbo.observaciones_adicionales(usuario_creacion, fecha_creacion);

CREATE INDEX IX_observaciones_adicionales_activo_enviado 
  ON dbo.observaciones_adicionales(activo, enviado);
