-- =============================================================================
-- DDL CHANGES REQUIRED FOR SENTINEL AUTOMATION SOLUTION
-- Schema: CONFIGURACION
-- =============================================================================
-- NOTE: The existing tables are assumed to already exist as described.
-- The following DDL creates sequences (if not already created) required
-- for auto-increment columns SERVICE_ID and LOG_ID.
-- Run this script as a DBA or privileged user in the CONFIGURACION schema.
-- =============================================================================

-- Sequence for OBS_SERVICE.SERVICE_ID
BEGIN
  EXECUTE IMMEDIATE 'CREATE SEQUENCE CONFIGURACION.OBS_SERVICE_SEQ
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -955 THEN RAISE; END IF; -- ORA-00955: name already used
END;
/

-- Sequence for OBS_SERVICE_LOG.LOG_ID
BEGIN
  EXECUTE IMMEDIATE 'CREATE SEQUENCE CONFIGURACION.OBS_SERVICE_LOG_SEQ
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -955 THEN RAISE; END IF;
END;
/

-- =============================================================================
-- OPTIONAL: If the tables do not yet exist, create them using the statements
-- below (skip if they already exist in the schema).
-- =============================================================================

CREATE TABLE CONFIGURACION.OBS_BATCH_EXECUTION (
  BATCH_ID                    VARCHAR2(36)                    NOT NULL,
  BATCH_EXECUTION_TIMESTAMP   TIMESTAMP(6) WITH TIME ZONE     NOT NULL,
  EXECUTION_TYPE              VARCHAR2(20)                    NOT NULL,
  TOTAL_SERVERS               NUMBER(10,0)                    NOT NULL,
  CONSTRAINT PK_OBS_BATCH PRIMARY KEY (BATCH_ID)
);
/

CREATE TABLE CONFIGURACION.OBS_SERVER (
  SERVER_ID         VARCHAR2(36)    NOT NULL,
  HOSTNAME          VARCHAR2(255)   NOT NULL,
  IP_ADDRESS        VARCHAR2(45)    NOT NULL,
  OPERATING_SYSTEM  VARCHAR2(50)    NOT NULL,
  ENVIRONMENT       VARCHAR2(30)    NOT NULL,
  CONSTRAINT PK_OBS_SERVER  PRIMARY KEY (SERVER_ID),
  CONSTRAINT UQ_OBS_SERVER_HOST UNIQUE (HOSTNAME)
);
/

CREATE TABLE CONFIGURACION.OBS_SERVICE (
  SERVICE_ID    NUMBER          NOT NULL,
  SERVER_ID     VARCHAR2(36)    NOT NULL,
  SERVICE_NAME  VARCHAR2(200)   NOT NULL,
  SERVICE_TYPE  VARCHAR2(50)    NOT NULL,
  TECHNOLOGY    VARCHAR2(50)    NOT NULL,
  CONSTRAINT PK_OBS_SERVICE PRIMARY KEY (SERVICE_ID),
  CONSTRAINT UQ_OBS_SERVICE UNIQUE (SERVER_ID, SERVICE_NAME),
  CONSTRAINT FK_OBS_SERVICE_SERVER FOREIGN KEY (SERVER_ID)
    REFERENCES CONFIGURACION.OBS_SERVER (SERVER_ID)
);
/

CREATE TABLE CONFIGURACION.OBS_SERVICE_LOG (
  LOG_ID                      NUMBER                          NOT NULL,
  BATCH_ID                    VARCHAR2(36)                    NOT NULL,
  SERVER_ID                   VARCHAR2(36)                    NOT NULL,
  SERVICE_ID                  NUMBER                          NOT NULL,
  COLLECTION_TIMESTAMP        TIMESTAMP(6) WITH TIME ZONE     NOT NULL,
  PID                         NUMBER(12,0),
  RUNNING_USER                VARCHAR2(255),
  BINARY_PATH                 VARCHAR2(4000),
  VERSION_DETECTED            VARCHAR2(200),
  UPTIME_SECONDS              NUMBER(18,0),
  CPU_USAGE_PERCENT           NUMBER(5,2),
  MEMORY_USAGE_MB             NUMBER(12,2),
  PROTOCOL                    VARCHAR2(10),
  SERVICE_STATUS              VARCHAR2(20)                    NOT NULL,
  SEVERITY                    VARCHAR2(20)                    NOT NULL,
  LAST_STATE_CHANGE_TIMESTAMP TIMESTAMP(6) WITH TIME ZONE,
  LISTENING_PORTS             CLOB,
  CONSTRAINT PK_OBS_SERVICE_LOG PRIMARY KEY (LOG_ID),
  CONSTRAINT FK_OBS_SL_BATCH   FOREIGN KEY (BATCH_ID)
    REFERENCES CONFIGURACION.OBS_BATCH_EXECUTION (BATCH_ID),
  CONSTRAINT FK_OBS_SL_SERVER  FOREIGN KEY (SERVER_ID)
    REFERENCES CONFIGURACION.OBS_SERVER (SERVER_ID),
  CONSTRAINT FK_OBS_SL_SERVICE FOREIGN KEY (SERVICE_ID)
    REFERENCES CONFIGURACION.OBS_SERVICE (SERVICE_ID)
);
/

-- Grant required privileges to the Ansible DB user (adjust user name as needed)
-- GRANT SELECT, INSERT, UPDATE ON CONFIGURACION.OBS_BATCH_EXECUTION TO ansible_user;
-- GRANT SELECT, INSERT, UPDATE ON CONFIGURACION.OBS_SERVER           TO ansible_user;
-- GRANT SELECT, INSERT, UPDATE ON CONFIGURACION.OBS_SERVICE          TO ansible_user;
-- GRANT INSERT                  ON CONFIGURACION.OBS_SERVICE_LOG      TO ansible_user;
-- GRANT SELECT ON CONFIGURACION.OBS_SERVICE_SEQ                      TO ansible_user;
-- GRANT SELECT ON CONFIGURACION.OBS_SERVICE_LOG_SEQ                  TO ansible_user;
