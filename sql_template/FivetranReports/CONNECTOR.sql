--liquibase formatted sql
--preconditions onFail:HALT onError:HALT

--changeset FIVETRAN_CONNECTOR:1 runOnChange:true stripComments:true
--labels: "FIVETRAN_CONNECTOR or GENERIC"

CREATE OR REPLACE VIEW   CDOPS_STATESTORE.REPORTING_EXT.VW_FIVETRAN_CONNECTOR as
SELECT *
  FROM FIVETRAN_TERRAFORM_LAB_DB.FIVETRAN_LOG.CONNECTOR;

-- rollback DROP VIEW IF EXISTS CDOPS_STATESTORE.REPORTING_EXT.VW_FIVETRAN_CONNECTOR;