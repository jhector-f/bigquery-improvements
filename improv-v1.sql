-- A list of improvements for BigQuery queries. Subject to review

/* 1. LIKE / NOT LIKE Statements
In some of the queries, there are lines of LIKE/NOT LIKE Statements
that can be replaced with another quantifier { ANY | SOME | ALL } after the LIKE
(ANY / SOME are basically equivalent)
Example is from Dev_Dataset.Distribution_Dashboard: (line ??) 
*/
-- New Code:
  OR (jo.stat like 'R' and jo.rework = 1)
  AND jmat.ref_type != 'J')
  AND (jo.stat LIKE ANY ('R', 'F'))
  AND jo.type = 'J'
  AND (items.plan_code NOT LIKE ANY ('SKN', 'FRM', 'NA', 'SER'))
  AND jmat.backflush = 0
  AND OH.qty_on_hand > 0
  AND jr.complete = 0

-- Previous Code:
  OR (jo.stat like 'R' AND jo.rework = 1)
  AND jmat.ref_type != 'J')
  AND (jo.stat LIKE 'R'
  OR jo.stat LIKE 'F')
  AND jo.type = 'J'
  AND (items.plan_code NOT LIKE 'SKN'
  OR items.plan_code NOT LIKE 'FRM'
  OR items.plan_code NOT LIKE 'NA'
  OR items.plan_code NOT LIKE 'SER')
  AND jmat.backflush = 0
  AND OH.qty_on_hand > 0 
  AND jr.complete = 0

/* 2. Changing Cases
In instances where the unit number is lowercase (e00000 instead of E00000), replace with functions that capitalize, trim, then concatenate
Example is from Dev_Dataset.Hours_by_Employees (line: ??) 
*/
/* Theres also a STARTS_WITH() function instead of 'a%'? */
-- New Code:
CASE
  WHEN jtran.job LIKE ANY ('e%', 'x%', 'q%')
  THEN CONCAT(UPPER(LEFT(jtran.job, 1)), TRIM(jtran.job,'exq'))
  ELSE jtran.job
END as job

-- Old Code:
CASE
  WHEN jtran.job like 'e%'
  THEN REPLACE(jtran.job, 'e', 'E')
  WHEN jtran.job like 'x%'
  THEN REPLACE(jtran.job, 'x', 'X')
  WHEN jtran.job like 'q%'
  THEN REPLACE(jtran.job, 'q', 'Q')
  ELSE jtan.job
END as Job

/* I updated and saved Hours_By_WC to make it more readable. No syntax/functionl changes */

/* 3. Equivalencies in AND/OR statements
In instances where certain values are chosen with "=" operator, use IN and an array of values (I see other queries that use this method)
Example is from Electrical_Dataset.Electrical_Defects (Line 53)
*/
-- New Code 
WHERE
   CAST(d.createDate AS date) > DATE_ADD(CURRENT_DATE(), INTERVAL -10 WEEK)
   AND jr.wc = 'SLF' -- because all the jr.wc statements weren't in ( ) and weren't all AND or OR, this AND is on its own
   OR jr.wc IN ('IEL', 'LIT','FEL', 'PRD', 'CON', 'TRK2')
   OR dept.description like 'ELE%'

-- Old Code
WHERE
   CAST(d.createDate as date) > DATE_ADD(CURRENT_DATE(), INTERVAL -10 WEEK)
   AND jr.wc = 'SLF'
  or jr.wc = 'IEL'
  or jr.wc = 'LIT'
  or jr.wc = 'FEL'
  or jr.wc = 'PRD'
  or jr.wc = 'CON'
  or jr.wc = 'TRK2'
   or dept.description like 'ELE%'

--NOTE TO  SELF:: Ended on Fabrication_Dataset.Item_Transactions

