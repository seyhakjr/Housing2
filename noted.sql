--------------------code 1 ----------------------------------------------------------------------------



select
 date_format(a.day_key ,'yyyy-MM') as period,
 concat_ws('_', a.whitelist_program, a.is_factory) as loan_program_segment,
 --a.whitelist_program,
 --a.is_factory,
 case when a.working_province is null or a.working_province = 'NA' then a.province else a.working_province end as region,
 --a.province,
 --a.working_province,
 count(*) as n_application,
 sum(case when a.app_ccy = 'KHR' then a.loan_request_amount/4000 else a.loan_request_amount end) as total_request_amount_usd,
 count(distinct a.customer_no) as n_unique_customer_applied,
 round(count(*)/count(distinct a.customer_no),2) as n_application_per_custtomer,
 sum(case when a.app_created_on is not null then 1 else 0 end) as n_application_submitted,
 sum(case when a.app_status = 'APPROVED' then 1 else 0 end) as n_application_approved,
 round(sum(case when a.app_status = 'APPROVED' then 1 else 0 end)/count(*),4) as approval_rate,
 count(distinct b.account_number) as application_disbursted,
 round(count(distinct b.account_number)/count(*),4) as conversion_rate,
 sum(case when b.currency = 'KHR' then b.amount_disbursed/4000 else b.amount_disbursed end) as total_disbursed_amount_usd,
 'dont have' as avg_application_time_to_disbursed_sec,
 sum(case when a.loan_status not in ('CLOSED','OPENED') and upper(trim(remarks)) = 'REJECTED DUE TO LOW WING CREDIT SCORE' then 1 else 0 end) as n_declined_by_score,
 'will find those criteria' as n_declined_by_knock_out,
 sum(case when a.loan_status not in ('CLOSED','OPENED') and a.loan_comments = 'CBC Rejected' then 1 else 0 end) as n_declined_by_cbc_rule,
 'will find those criteria' as n_declined_by_budget_rule,
 'will find those criteria' as n_declined_by_underwriter,
 'will find those criteria' as n_declined_by_other_reasons
from lendb.loan_applications a
LEFT JOIN (
  SELECT * 
  FROM lendb.loan_account_master 
  WHERE DATE_FORMAT(value_date, 'yyyyMM') >= '2025-01-01'
) b ON a.account_number = b.account_number
WHERE a.day_key >= '2025-01-01'
AND a.is_digital_loan = 'Y'

group by 
 date_format(a.day_key ,'yyyy-MM'), 
 concat_ws('_', a.whitelist_program, a.is_factory),
 case when a.working_province is null or a.working_province = 'NA' then a.province else a.working_province end
 



--------------------------------------code2--------------------------------------------------------------------------------
WITH A AS (
    SELECT
        DATE_FORMAT(a.day_key,'yyyy-MM') AS period,
        CONCAT_WS('_', a.whitelist_program, a.is_factory) AS program_segment,
        CASE 
            WHEN a.working_province IS NULL OR a.working_province = 'NA' 
            THEN a.province 
            ELSE a.working_province 
        END AS region,
        b.account_number,
        b.account_status AS status,
        b.payment_frequency,
        b.closed_date ,
        b.maturity_date, 
      
        MAX (
        CASE when b.currency = 'KHR' THEN b.amount_disbursed / 4000
             ELSE b.amount_disbursed END 
        ) AS amount_disbursed_usd,
        MAX(
        	CASE
           		WHEN b.currency = 'KHR' THEN (c.principal_amount_settled + c.main_int_amount_settled) / 4000
           ELSE (c.principal_amount_settled + c.main_int_amount_settled)
       END
        ) AS recovered,
        
        MAX(
            CASE 
                WHEN a.app_ccy = 'KHR' THEN a.loan_amount / 4000 
                ELSE a.loan_amount 
            END
        ) AS amount_usd,
        MAX(
            CASE 
                WHEN b.currency = 'KHR' THEN b.loan_outstanding / 4000 
                ELSE b.loan_outstanding 
            END
        ) AS outstanding_balance,
        MAX(
            CASE
                WHEN c.principal_amount_due = 0 
                     AND c.main_int_amount_due <> c.main_int_amount_settled
                THEN DATEDIFF(CURRENT_DATE, c.schedule_due_date)
                WHEN c.principal_amount_due = 0
                     AND c.main_int_amount_due > 0
                     AND c.main_int_amount_due = c.main_int_amount_settled
                THEN DATEDIFF(c.main_int_lASt_paid_date, c.schedule_due_date)
                WHEN c.principal_amount_due <> c.principal_amount_settled
                THEN DATEDIFF(CURRENT_DATE, c.schedule_due_date)
                WHEN c.principal_amount_due = c.principal_amount_settled
                THEN DATEDIFF(c.principal_lASt_paid_date, c.schedule_due_date)
                ELSE 0
            END
        ) AS days_late
    FROM lendb.loan_applications a
	LEFT JOIN (
	  SELECT *
	  FROM lendb.loan_account_master
	  WHERE value_date >= '2025-01-01'
	) b ON a.account_number = b.account_number
	LEFT JOIN lendb.loan_schedule c ON b.account_number = c.account_number
	WHERE a.day_key >= '2025-01-01'
	  AND a.is_digital_loan = 'Y'
    GROUP BY 
        DATE_FORMAT(a.day_key,'yyyy-MM'),
        CONCAT_WS('_', a.whitelist_program, a.is_factory),
        CASE 
            WHEN a.working_province IS NULL OR a.working_province = 'NA' 
            THEN a.province 
            ELSE a.working_province 
        END,
        b.account_number,
        b.account_status,
        b.payment_frequency,
        b.closed_date ,
        b.maturity_date
       
),
A_Loan AS (
    SELECT
        period,
        program_segment,
        region,
        account_number,
        status,
        payment_frequency,
        amount_usd,
        outstanding_balance,
        days_late,
        amount_disbursed_usd,
        recovered,
        CASE WHEN days_late between 10 and 29 THEN 1 ELSE 0 END AS DPD10,
        CASE WHEN days_late between 30 and 59 THEN 1 ELSE 0 END AS DPD30,
        CASE WHEN days_late between 60 and 89 THEN 1 ELSE 0 END AS DPD60,
        CASE WHEN days_late between 90 and 119 THEN 1 ELSE 0 END AS DPD90,
        CASE WHEN days_late >= 90 THEN 1 ELSE 0 END AS NPL,
        CASE WHEN days_late >= 120 AND status  in ('Active','Hold','Closed') THEN 1 ELSE 0 END AS Default_flag,
        CASE 
            WHEN payment_frequency = 'Weekly' AND days_late BETWEEN 7 AND 13 THEN 1
            WHEN payment_frequency = 'Monthly' AND days_late BETWEEN 30 AND 59 THEN 1
            WHEN payment_frequency = 'Bullet' AND days_late > 0 THEN 1
            WHEN payment_frequency IS NULL AND days_late > 0 THEN 1
            ELSE 0 
        END AS FPD,
        CASE 
            WHEN payment_frequency = 'Weekly' AND days_late BETWEEN 14 AND 20 THEN 1
            WHEN payment_frequency = 'Monthly' AND days_late BETWEEN 60 AND 89 THEN 1
            WHEN payment_frequency = 'Bullet' AND days_late > 0 THEN 1
            WHEN payment_frequency IS NULL AND days_late > 0 THEN 1
            ELSE 0 
        END AS PD2,
        CASE when closed_date is not null and closed_date < maturity_date 
             and days_late = 0 THEN 1 ELSE 0 END AS prepaid_loan
    FROM A
),
B AS (
    SELECT * FROM A_Loan
)
SELECT
    period,
    program_segment,
    region,
    COUNT(*) AS total_loans,
    SUM(amount_usd) AS total_loan_amount_usd,
    SUM(FPD) AS FPD,
    SUM(PD2) AS PD2,
    SUM(DPD10) AS DPD10,
    SUM(DPD30) AS DPD30,
    SUM(DPD60) AS DPD60,
    SUM(DPD90) AS DPD90,
    SUM(NPL) AS NPL,
    SUM(Default_flag) AS Default_val,
    ROUND(SUM(FPD) * 100 / COUNT(*), 2) AS FPD_Rate,
    ROUND(SUM(PD2) * 100 / COUNT(*), 2) AS PD2_Rate,
    ROUND(SUM(DPD10) * 100 / COUNT(*), 2) AS DPD10_Rate,
    ROUND(SUM(DPD30) * 100 / COUNT(*), 2) AS DPD30_Rate,
    ROUND(SUM(DPD60) * 100 / COUNT(*), 2) AS DPD60_Rate,
    ROUND(SUM(DPD90) * 100 / COUNT(*), 2) AS DPD90_Rate,
    ROUND(SUM(NPL) * 100 / COUNT(*), 2) AS NPL_Rate,
    ROUND(SUM(Default_flag) * 100 / COUNT(*), 2) AS Default_Rate,
    SUM(CASE WHEN FPD=1 THEN amount_usd END) AS FPD_amount_usd,
    SUM(CASE WHEN PD2=1 THEN amount_usd END) AS PD2_amount_usd,
    SUM(CASE WHEN DPD10=1 THEN amount_usd END) AS Amount_DPD10_plus_usd,
    SUM(CASE WHEN DPD30=1 THEN amount_usd END) AS DPD30_amount_usd,
    SUM(CASE WHEN DPD60=1 THEN amount_usd END) AS DPD60_amount_usd,
    SUM(CASE WHEN DPD90=1 THEN amount_usd END) AS DPD90_amount_usd,
    SUM(CASE WHEN NPL=1 THEN amount_usd END) AS NPL_amount_usd,
    SUM(CASE WHEN Default_flag=1 THEN amount_usd END) AS Default_amount_usd,
    ROUND(SUM(CASE WHEN FPD=1 THEN amount_usd END)*100.0 / SUM(amount_usd),2) AS FPD_amount_rate_pct,
    ROUND(SUM(CASE WHEN PD2=1 THEN amount_usd END)*100.0 / SUM(amount_usd),2) AS PD2_amount_rate_pct,
    ROUND(SUM(CASE WHEN DPD10=1 THEN amount_usd END)*100.0 / SUM(amount_usd),2) AS Amount_DPD10_plus_rate_pct,
    ROUND(SUM(CASE WHEN DPD30=1 THEN amount_usd END)*100.0 / SUM(amount_usd),2) AS DPD30_amount_rate_pct,
    ROUND(SUM(CASE WHEN DPD60=1 THEN amount_usd END)*100.0 / SUM(amount_usd),2) AS DPD60_amount_rate_pct,
    ROUND(SUM(CASE WHEN DPD90=1 THEN amount_usd END)*100.0 / SUM(amount_usd),2) AS DPD90_amount_rate_pct,
    ROUND(SUM(CASE WHEN NPL=1 THEN amount_usd END)*100.0 / SUM(amount_usd),2) AS NPL_amount_rate_pct,
    ROUND(SUM(CASE WHEN Default_flag=1 THEN amount_usd END)*100.0 / SUM(amount_usd),2) AS Default_amount_rate_pct,
    SUM(recovered)     AS Recovery_Amount_Usd,
	ROUND(SUM(recovered) * 100.0 / NULLIF(SUM(CASE WHEN Default_flag = 1 THEN amount_usd END), 0), 2) AS Recovery_Rate_pct,

    SUM(prepaid_loan)  AS Prepaid_Loan,
	ROUND(SUM(prepaid_loan) * 100 / count(*) , 2) AS Prepayment_Rate,
	SUM(CASE when prepaid_loan = 1 THEN amount_disbursed_usd ELSE 0 END) AS Prepaid_Amount_usd,
	ROUND(SUM(CASE when prepaid_loan = 1 THEN amount_disbursed_usd ELSE 0 END ) * 100 / SUM(amount_usd) , 2) AS Prepayment_Amount_Rate,
    SUM(outstanding_balance) AS Outstanding_Balance_Usd
FROM B
GROUP BY period, program_segment, region
ORDER BY period, program_segment, region;