--liquibase formatted sql
--preconditions onFail:HALT onError:HALT

--changeset BUDGET_EXTENDED_TABLES:1 runOnChange:true stripComments:true
--labels: BUDGET
--comment: Since many of the tables here are populated manually or from some sub-system, rollback will not perform drop of these tables.
USE ROLE SYSADMIN;
USE DATABASE CDOPS_STATESTORE;
CREATE TABLE IF NOT EXISTS CDOPS_STATESTORE.REPORTING.OVERRIDE_DATABASE_METADATA (
    NAME VARCHAR,
    OWNER VARCHAR,
    COMMENT VARCHAR,
    DB_TYPE VARCHAR,
    ENV VARCHAR,
    BU VARCHAR,
    DB_NAME VARCHAR
);

CREATE TABLE IF NOT EXISTS CDOPS_STATESTORE.REPORTING.OVERRIDE_WAREHOUSE_METADATA (
    NAME VARCHAR,
    OWNER VARCHAR,
    COMMENT VARCHAR,
    WH_TYPE VARCHAR,
    ENV VARCHAR,
    BU VARCHAR,
    DB_NAME VARCHAR,
    PURPOSE VARCHAR
);

CREATE TABLE IF NOT EXISTS CDOPS_STATESTORE.REPORTING.RAW_WAREHOUSE_TAGS ( NAME VARCHAR, TAG VARCHAR );
CREATE TABLE IF NOT EXISTS CDOPS_STATESTORE.REPORTING.RAW_DATABASE_TAGS ( NAME VARCHAR, TAG VARCHAR );

CREATE SEQUENCE IF NOT EXISTS CDOPS_STATESTORE.REPORTING.PUR_ID_SEQ;
CREATE TABLE IF NOT EXISTS CDOPS_STATESTORE.REPORTING.WORKSPACE_PURCHASES (
	PUR_ID NUMBER(38,0) NOT NULL DEFAULT PUR_ID_SEQ.NEXTVAL,
	WS_ID NUMBER(38,0) NOT NULL,
	Purchased_Credits NUMBER(38,0),
	Purchased_Rate NUMBER(38,2),
	Purchased_Amount NUMBER(38,2),
	Purchased_Date DATE,
	Purchased_Type VARCHAR(256),
	Purchased_Source VARCHAR(256),
	Renewal_Date DATE
);

CREATE SEQUENCE IF NOT EXISTS  CDOPS_STATESTORE.REPORTING.WS_ID_SEQ;
CREATE TABLE IF NOT EXISTS CDOPS_STATESTORE.REPORTING.WORKSPACE_TRACKER (
	WS_ID NUMBER(38,0) NOT NULL DEFAULT WS_ID_SEQ.NEXTVAL,
	WORKSPACE VARCHAR(256) NOT NULL,
	WORKSPACE_DESC VARCHAR(256) NOT NULL,
	WORKSPACE_TYPE VARCHAR(3) NOT NULL,
	BU VARCHAR(256) NOT NULL
);

CREATE TABLE IF NOT EXISTS CDOPS_STATESTORE.REPORTING.WORKSPACE_TYPES (
	WORKSPACE_TYPE VARCHAR(3) NOT NULL,
	WORKSPACE_TYPE_DESC VARCHAR(256) NOT NULL
);

DELETE FROM CDOPS_STATESTORE.REPORTING.WORKSPACE_TYPES WHERE WORKSPACE_TYPE IN ('LRN','POC','ES','DP');
INSERT INTO CDOPS_STATESTORE.REPORTING.WORKSPACE_TYPES VALUES ('LRN','Learner Workspace');
INSERT INTO CDOPS_STATESTORE.REPORTING.WORKSPACE_TYPES VALUES ('POC','Proff Of Concept Workspace');
INSERT INTO CDOPS_STATESTORE.REPORTING.WORKSPACE_TYPES VALUES ('ES','Explore Workspace');
INSERT INTO CDOPS_STATESTORE.REPORTING.WORKSPACE_TYPES VALUES ('DP','Data Product Workspace');

--comment: One time creation the procedure would overwrite this with WAREHOUSE_CREDIT_USAGE
CREATE OR REPLACE TABLE CDOPS_STATESTORE.REPORTING.WAREHOUSE_CREDIT_USAGE AS
SELECT
  WAREHOUSE_METERING_HISTORY.WAREHOUSE_NAME AS WAREHOUSE_NAME,
  TO_CHAR(TO_DATE(WAREHOUSE_METERING_HISTORY.START_TIME), 'YYYY-MM-DD') AS ACTIVE_DATE,
  COALESCE(SUM(WAREHOUSE_METERING_HISTORY.CREDITS_USED), 0) AS CREDITS_USED
FROM
  SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY AS WAREHOUSE_METERING_HISTORY
GROUP BY
  WAREHOUSE_NAME,
  ACTIVE_DATE
ORDER BY
  WAREHOUSE_NAME,
  ACTIVE_DATE;

--rollback: DROP TABLE IF EXISTS CDOPS_STATESTORE.REPORTING.WAREHOUSE_CREDIT_USAGE;