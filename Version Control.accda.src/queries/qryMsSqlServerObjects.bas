﻿dbMemo "SQL" ="-- On Microsoft SQL Server, return a listing of all parent level objects\015\012"
    "SELECT o.[name],\015\012    SCHEMA_NAME(o.[schema_id]) AS [schema],\015\012\011C"
    "ASE\015\012\011\011-- Return the most recent modfied date of the object or any d"
    "ependent object\015\012\011\011WHEN isnull(c.max_modified, 0) > o.modify_date TH"
    "EN c.max_modified\015\012\011\011ELSE o.modify_date\015\012\011END AS last_modif"
    "ied,\015\012\011o.type_desc,\015\012\011CASE o.[type]\015\012\011\011WHEN 'V' TH"
    "EN 'views'\015\012\011\011WHEN 'U' THEN 'tables'\015\012\011\011WHEN 'IT' THEN '"
    "tables'\011\011-- Internal tables\015\012\011\011WHEN 'TR' THEN 'tables'\015\012"
    "\011\011WHEN 'P' THEN 'procedures'\015\012\011\011WHEN 'FN' THEN 'functions'\011"
    "-- Scalar function\015\012\011\011WHEN 'IF' THEN 'functions'\011-- Inline table "
    "valued function\015\012\011\011WHEN 'TF' THEN 'functions'\011-- Table valued fun"
    "ction\015\012\011\011WHEN 'TT' THEN 'types'\011\011-- Type table\015\012\011\011"
    "WHEN 'SO' THEN 'sequences'\011-- Sequence object\015\012\011\011WHEN 'SN' THEN '"
    "synonymns'\011-- Synonyms\015\012\011\011ELSE 'unknown'\015\012\011END as folder"
    ",\015\012\011o.[type] AS object_type\015\012    -- ,*\015\012FROM sys.objects o\015"
    "\012LEFT JOIN \015\012\011-- Get most recent modified date of any child object\015"
    "\012\011(select \015\012\011\011parent_object_id,\015\012\011\011max(modify_date"
    ") AS max_modified\015\012\011\011from sys.objects\015\012\011\011WHERE parent_ob"
    "ject_id > 0\015\012\011\011GROUP BY parent_object_id\015\012\011)AS c \015\012\011"
    "ON c.parent_object_id = o.object_id\015\012WHERE 1 = 1\015\012--AND o.type = 'TT"
    "'\015\012AND o.parent_object_id = 0\015\012AND o.[type] NOT IN (\015\012\011 'S'"
    "  -- System Tables\015\012\011,'SQ' -- Service queues\015\012\011,'TR'  -- Trigg"
    "ers saved from tables\015\012\011,'IT'  -- Internal tables\015\012\011,'TT'  -- "
    "Type tables\015\012\011,'SO'  -- Sequence objects\015\012\011)\015\012"
dbMemo "Connect" ="ODBC;"
dbBoolean "ReturnsRecords" ="-1"
dbInteger "ODBCTimeout" ="60"
dbBoolean "LogMessages" ="0"
dbByte "Orientation" ="0"