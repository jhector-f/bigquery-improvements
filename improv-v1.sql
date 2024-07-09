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
Example is from Dev_Dataset.Hours_by_Employees (line: ??) (Additional note: the original field name is [jtran.job.] I replaced the field with [job] for ease of replication
*/
/* Theres also a STARTS_WITH() function instead of 'a%'? */
-- New Code:
CASE
  WHEN job LIKE ANY ('e%', 'x%', 'q%')
  THEN CONCAT(UPPER(LEFT(job, 1)), TRIM(job,'exq'))
  ELSE job
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

/* 4. CASE/WHEN statements
This is more of a note for me for queries that CANuse this. When using a CASE/WHEN statement where all the arguments are the same, you can write it as follows where the argument is presented first.
IF more conditions are needed other than "=" (i.e. multiple conditions need to be met for one assignment), the following cannot be used.
Example is from Interior_Dataset.Interior_WC_Completed (Line 5)
*/
-- New Code
  CASE jcd.wc
    WHEN 'SLG'
    THEN 1
    WHEN 'PPR'
    THEN 2
    WHEN 'FLR'
    THEN 3
    WHEN 'IEL'
    THEN 4
    WHEN  'AWP'
    THEN 5
    WHEN 'ACT'
    THEN 6
    WHEN 'FEL'  --notice how 'AIR', 'FRN', and 'OPT' are missing. They need an OR for the logic but it cannot be used with this syntax (without explicit assignment)
    THEN 8
    WHEN 'FLROPT'
    THEN 9
    WHEN 'PRD'
    THEN 10
    ELSE null
  END as sequence,
-- Old Code    
    CASE 
    WHEN jcd.wc = 'SLG'
    THEN 1
    WHEN jcd.wc = 'PPR'
    THEN 2
    WHEN jcd.wc = 'FLR'
    THEN 3
    WHEN jcd.wc = 'IEL'
    THEN 4
    WHEN jcd.wc = 'AWP'
    THEN 5
    WHEN jcd.wc = 'ACT'
    THEN 6
    WHEN (jcd.wc = 'AIR' or jcd.wc = 'FRN' or jcd.wc = 'OPT')
    THEN 7
    WHEN jcd.wc = 'FEL'
    THEN 8
    WHEN jcd.wc = 'FLROPT'
    THEN 9
    WHEN jcd.wc = 'PRD'
    THEN 10
    ELSE null
  END as sequence,

/* 5. LAST_DAY Function
In an instance where dates are pushed to a certain day of the week (i.e. marking the end day of a certain period of time), 
use the LAST_DAY function instead of a CASE/WHEN to match every different condition.
In the following example, it helped that every date was converging to the same day.
Example is from Operations_Dataset.Distribution_Material_Handlers (Line 2 AND Line 81)
*/

-- New Code

  CASE
    WHEN EXTRACT(dayofweek FROM JTM.PR_End_date) = 7 
    THEN LAST_DAY(MT.trans_date, WEEK(SUNDAY)) -- Argument is thefirst day of the week (Sunday 1 - Saturday 7)
    WHEN EXTRACT(dayofWeek FROM JTM.PR_End_date) = 3 
    THEN LAST_DAY(MT.trans_date, WEEK(WEDNESDAY)) -- (Wednesday 4 - Tuesday 3)
  END AS Payroll_Week
    -- when JTM.PR_End_date is 7, Payroll Week day is a Saturday vs
    -- when JTM.PR_End_date is 3, Payroll Week day is Tuesday (side note: there were no examples of this instance in this particular query)

-- Old Code
CASE
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 1 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 7 
    THEN (DATE(MT.trans_date) + 6)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 2 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 7 
    THEN (DATE(MT.trans_date) +5)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 3 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 7 
    THEN (DATE(MT.trans_date) +4)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 4 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 7 
    THEN (DATE(MT.trans_date) +3)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 5 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 7 
    THEN (DATE(MT.trans_date) +2)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 6 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 7 
    THEN (DATE(MT.trans_date) +1)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 7 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 7 
    THEN (DATE(MT.trans_date) +0)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 4 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 3 
    THEN (DATE(MT.trans_date) - 1)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 5 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 3 
    THEN (DATE(MT.trans_date) - 2)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 6 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 3 
    THEN (DATE(MT.trans_date) -3)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 7 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 3 
    THEN (DATE(MT.trans_date) - 4)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 3 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 3 
    THEN (DATE(MT.trans_date) + 0)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 2 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 3 
    THEN (DATE(MT.trans_date) + 1)
    WHEN EXTRACT(dayofweek FROM MT.trans_date) = 1 AND EXTRACT(dayofweek FROM JTM.PR_End_date) = 3 
    THEN (DATE(MT.trans_date) + 2)
  END AS Payroll_Week

-- I updated Operations_Dataset.Job_Complete_Data to make it more readable. No syntax/function changes
-- Note 7/3/2024 : Started saving Operations_Dataset.Monthly_Prod_Goals and on (following list) with previous improvements
-- Note 7/3/2024 : Left off at Paint_Dataset.Buffing_Labor Hours

/* Paint_Dataset.Paint_Labor_Utilization has something strange I can't figure out with the naming of the fields
BQ asks if the proper field name is PR End Date (sans underscores) instead of PR_End_Date in Line 61, even though the field with the underscores
is used throughout the statement
*/

WHERE
    /*Home_Dept NOT IN ('OFFICERS',
      'EXECUTIVE',
      'MIS',
      'SERVICE',
      'HUMAN RESOURCES',
      'DISTRIBUTION',
      'SALES',
      'ACCOUNTS',
      'TRANSPORTATION',
      'PURCHASING')
    AND Home_Dept NOT LIKE 'ENG%'
    AND Home_Dept NOT LIKE 'MIS%'
    AND Home_Dept NOT LIKE 'CONTINUOUS%'
    AND*/ PR_End_Date >'2017-08-21'
-- In Job_Time_Master_2019, the field [PR End Date] is used, I don't know how long for. Should it be changed? 
--The other JTMs with 2018, 2022 dates use the underscores */

/* 6. DIVISION BY ZERO
To fix a division by zero problem, use the following.
(This error has occured before and was fixed with the same statement)
Example from Supply_Chain_Dataset.Avg_Cycle_Count (line 11)
*/

-- New Code
 (1 - sum(abs_error__)/NULLIF(SUM(precount_ext_cost), 0)) * 100 as value_accuracy
-- Old Code
(1 - sum(abs_error__)/SUM(precount_ext_cost)) * 100 as value_accuracy

