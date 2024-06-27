--liquibase formatted sql
--preconditions onFail:HALT onError:HALT

--changeset MEMBER_RESOURCE_MAPPING:1 runOnChange:true stripComments:true
--labels: "MEMBER_RESOURCE_MAPPING or GENERIC"

--Override CDOPS Variables

ALTER TASK IF EXISTS CDOPS_STATESTORE.REPORTING.TASK_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING SUSPEND;


CREATE OR REPLACE PROCEDURE CDOPS_STATESTORE.REPORTING.SP_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING()
  returns string not null
  language javascript
  EXECUTE AS CALLER
  as
  '
    const sql_begin_trans = snowflake.createStatement({ sqlText:`BEGIN TRANSACTION;`});
    const sql_commit_trans = snowflake.createStatement({ sqlText:`COMMIT;`});


    const sql_mrm_table = snowflake.createStatement({ sqlText:
      `
          CREATE OR REPLACE TEMPORARY TABLE CDOPS_STATESTORE.REPORTING.VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING_TABLE AS
            SELECT
                 sha1_binary( concat(             ifnull( ACCOUNT, \'~\' )
                                          ,\'|\', ifnull( ROLE, \'~\' )
                                          ,\'|\', ifnull( WAREHOUSE, \'~\' )
                                          ,\'|\', ifnull( DATABASE, \'~\' )
                                         )
                                  )   SH_KEY,
                ACCOUNT,ROLE,WAREHOUSE,DATABASE
            FROM CDOPS_STATESTORE.REPORTING.MEMBER_RESOURCE_MAPPING;
    `
    });

    const sql_mrm_delta = snowflake.createStatement({ sqlText:
    `
           CREATE OR REPLACE TEMPORARY TABLE CDOPS_STATESTORE.REPORTING.VW_SNOWFLAKE_MRM_TRAM_TEMP AS
            SELECT
               *
            FROM CDOPS_STATESTORE.REPORTING.VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING_TABLE where 1 = 2;
    `
    });



    const sql_merge_table = snowflake.createStatement({ sqlText:
    `
    MERGE INTO CDOPS_STATESTORE.REPORTING.VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING_TABLE T USING CDOPS_STATESTORE.REPORTING.VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING_TABLE_TEMP S
    ON (T.SH_KEY = S.SH_KEY)
    WHEN NOT MATCHED THEN
    INSERT (SH_KEY,ACCOUNT,ROLE,WAREHOUSE,DATABASE)
    VALUES (S.SH_KEY,S.ACCOUNT,S.ROLE,S.WAREHOUSE,S.DATABASE);

    `
    });

    const sql_final_refresh = snowflake.createStatement({ sqlText:
    `
    INSERT OVERWRITE INTO  CDOPS_STATESTORE.REPORTING.MEMBER_RESOURCE_MAPPING
    SELECT ACCOUNT,ROLE,WAREHOUSE,DATABASE FROM CDOPS_STATESTORE.REPORTING.VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING_TABLE;

    `
    });


    try{
        snowflake.execute({sqlText: ` USE ROLE CDOPS_ADMIN;`});

        sql_begin_trans.execute();

        sql_mrm_table.execute();

        sql_mrm_delta.execute();

        var obj_rs = sql_select_roles.execute();

        snowflake.execute({sqlText: ` USE ROLE SYSADMIN;`});

        while (obj_rs.next())
            {
                snowflake.execute({sqlText: `SHOW GRANTS TO ROLE "` + obj_rs.getColumnValue(1) + `" ;` });
                sql_insert_grants.execute();
            }

        snowflake.execute({sqlText: ` USE ROLE CDOPS_ADMIN;`});

        sql_mrm_temp_table_add_sh_key.execute();
        sql_merge_table.execute();
        sql_final_refresh.execute();

      }
    catch(err){
   const error = `Failed: Code: ${err.code}\\n  State: ${err.state}\\n  Message: ${err.message}\\n Stack Trace:\\n   ${err.stackTraceTxt}`;
   throw error;
               }
    finally{
        sql_commit_trans.execute();
    }
    return "Success" ;
  ';

SET TASK_SCHEDULE = (SELECT VAR_VALUE FROM table(get_var('TASK_SCHEDULE','TASK_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING',CURRENT_ACCOUNT(),CURRENT_REGION())));

CREATE OR REPLACE task CDOPS_STATESTORE.REPORTING.TASK_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING
    WAREHOUSE = ${TASK_WAREHOUSE}
    SCHEDULE = $TASK_SCHEDULE
AS
    CALL CDOPS_STATESTORE.REPORTING.SP_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING();

ALTER TASK IF EXISTS CDOPS_STATESTORE.REPORTING.TASK_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING RESUME;

CALL CDOPS_STATESTORE.REPORTING.SP_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING();

-- rollback DROP TABLE IF EXISTS "CDOPS_STATESTORE"."REPORTING"."VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING_TABLE_TEMP";
-- rollback DROP TABLE IF EXISTS "CDOPS_STATESTORE"."REPORTING"."VW_SNOWFLAKE_TRAM_METADATA_TABLE_TEMP";
-- rollback DROP TABLE IF EXISTS "CDOPS_STATESTORE"."REPORTING"."VW_SNOWFLAKE_MRM_TRAM_TEMP";
-- rollback DROP TABLE IF EXISTS "CDOPS_STATESTORE"."REPORTING"."VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING_TABLE";
-- rollback DROP TASK IF EXISTS  CDOPS_STATESTORE.REPORTING.TASK_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING;
-- rollback DROP PROCEDURE IF EXISTS  CDOPS_STATESTORE.REPORTING.SP_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING();
-- rollback DROP VIEW IF EXISTS  CDOPS_STATESTORE.REPORTING_EXT.EXTENDED_TABLE_VW_SNOWFLAKE_MEMBER_RESOURCE_MAPPING;
