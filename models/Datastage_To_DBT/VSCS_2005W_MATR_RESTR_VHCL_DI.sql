{{ config(
    materialized='incremental',
    unique_key=['I_PLT_HOLD', 'I_VHCL_SAN'],
    incremental_strategy='merge',
    merge_update_columns=['C_VHCL_UMI_CURR','C_VHCL_UMI_ORIG','I_PLT_LOC','T_STMP_UPD'],
    on_schema_change='append_new_columns'
) }}


WITH vehicle AS (
    SELECT
        I_PLT_HOLD_DIM,
        I_VHCL_SAN,
        C_CATGY_SRCE_CURR,
        C_CATGY_SRCE_ORG,
        C_SLSCD,
        I_PLT_LOC,
        T_STMP_UPD
    FROM DBT_DEMO.SCM.SEQ_MR_VHCL_DATA
),

Expression_1 AS (
    SELECT
        I_PRTITION,
        I_VHCL_SAN,
        SALES_CD_1,
        SALES_CD_2,
        SALES_CD_3,
        SALES_CD_4,
        SALES_CD_5
    FROM  DBT_DEMO.SCM.SEQ_MATR_RESTR_SLSCD
),

Joinner_Expression AS (
    SELECT 
        v.I_PLT_HOLD_DIM,
        v.I_VHCL_SAN,
        v.C_CATGY_SRCE_CURR,
        v.C_CATGY_SRCE_ORG,
        v.C_SLSCD,
        v.I_PLT_LOC,
        v.T_STMP_UPD,
        s.I_PRTITION,
        s.SALES_CD_1,
        s.SALES_CD_2,
        s.SALES_CD_3,
        s.SALES_CD_4,
        s.SALES_CD_5
    FROM vehicle v
    LEFT JOIN Expression_1 s
        ON v.I_VHCL_SAN = s.I_VHCL_SAN
),

Expression_2 AS (
    SELECT 
        I_PLT_HOLD_DIM,
        I_VHCL_SAN,
        C_CATGY_SRCE_CURR,
        C_CATGY_SRCE_ORG,
        C_SLSCD,
        I_PLT_LOC,
        T_STMP_UPD,
        I_PRTITION,
        CASE 
            WHEN SUBSTR(C_SLSCD, 1, 1) = ':' THEN TRIM(C_SLSCD)
            ELSE ':' || TRIM(C_SLSCD)
        END AS stgslscd,
        CASE 
            WHEN POSITION(':' IN C_SLSCD) > 1 OR POSITION(';' IN C_SLSCD) > 1 THEN 1
            ELSE 0
        END AS stgmulscd,
        TRIM(COALESCE(SALES_CD_1, '')) || ':' ||
        TRIM(COALESCE(SALES_CD_2, '')) || ':' ||
        TRIM(COALESCE(SALES_CD_3, '')) || ':' ||
        TRIM(COALESCE(SALES_CD_4, '')) || ':' ||
        TRIM(COALESCE(SALES_CD_5, '')) AS stgvhclslscd
    FROM Joinner_Expression
),

Expression_2_1 AS (
    SELECT 
        I_PLT_HOLD_DIM,
        I_VHCL_SAN,
        C_CATGY_SRCE_CURR,
        C_CATGY_SRCE_ORG,
        stgslscd AS CSLSCD,
        I_PLT_LOC,
        C_SLSCD,
        CAST(T_STMP_UPD AS TIMESTAMP) AS T_STMP_UPD,
        stgvhclslscd AS VHCL_SCD
    FROM Expression_2
    WHERE stgmulscd = 0
      AND TRIM(C_SLSCD) <> ''
),

Expression_2_2 AS (
    SELECT 
        I_PLT_HOLD_DIM,
        I_VHCL_SAN,
        C_CATGY_SRCE_CURR,
        C_CATGY_SRCE_ORG,
        stgslscd AS CSLSCD,
        I_PLT_LOC,
        C_SLSCD,
        CAST(T_STMP_UPD AS TIMESTAMP) AS T_STMP_UPD,
        stgvhclslscd AS VHCL_SCD
    FROM Expression_2
    WHERE stgmulscd = 1
      AND TRIM(C_SLSCD) <> ''
),

Expression_3_Common_Column AS (
    SELECT 
        I_PLT_HOLD_DIM,
        I_VHCL_SAN,
        C_CATGY_SRCE_CURR,
        C_CATGY_SRCE_ORG,
        I_PLT_LOC,
        T_STMP_UPD
    FROM Expression_2_1
),

Expression_4_Common_Column AS (
    SELECT 
        I_PLT_HOLD_DIM,
        I_VHCL_SAN,
        C_CATGY_SRCE_CURR,
        C_CATGY_SRCE_ORG,
        I_PLT_LOC,
        T_STMP_UPD
    FROM Expression_2_2
),

Union_Expression AS (
    SELECT * FROM Expression_3_Common_Column
    UNION
    SELECT * FROM Expression_4_Common_Column
)

SELECT
    I_PLT_HOLD_DIM AS I_PLT_HOLD,
    I_VHCL_SAN,
    C_CATGY_SRCE_ORG  AS C_VHCL_UMI_ORIG,
    C_CATGY_SRCE_CURR AS C_VHCL_UMI_CURR,
    I_PLT_LOC,
    CURRENT_TIMESTAMP() AS T_STMP_UPD,
    T_STMP_UPD AS T_STMP_UPD_SRCE
FROM Union_Expression
