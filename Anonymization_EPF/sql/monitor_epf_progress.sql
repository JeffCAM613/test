-- ============================================================================
-- EPF ANONYMIZATION - Progress Tracker
-- ============================================================================
-- Run as OPPAYMENTS (or SYS with schema prefix)
--
-- HOW IT WORKS:
-- The EPF anonymization runs in 4 phases:
-- Phase A: Infrastructure (SYS) - creates tables/functions
-- Phase B: Code-based (ITR1) - maps OP tiers/cb codes to OPPAYMENTS tables
-- Phase C: BIC/SWIFT + Amounts - component anonymization
-- Phase D: Independent (ITR2) - admin_user, cascades, free-text, etc.
--
-- Progress is tracked via:
-- 1. epf_anon_log table (real-time entries from each step)
-- 2. Direct table checks (verify anonymization coverage)
-- ============================================================================

-- ============================================================================
-- SECTION 1: Live Log - Recent Activity (last run)
-- ============================================================================
SELECT log_id, module, operation, table_name, rows_affected, status,
 TO_CHAR(log_timestamp, 'HH24:MI:SS') AS time_stamp,
 ROUND(elapsed_seconds, 1) AS secs,
 SUBSTR(message, 1, 60) AS message
FROM oppayments.epf_anon_log
WHERE run_id = (SELECT MAX(run_id) FROM oppayments.epf_anon_log)
ORDER BY log_id;

-- ============================================================================
-- SECTION 2: Phase Progress Summary
-- ============================================================================
SELECT
 CASE
 WHEN module LIKE 'ORCHESTRATOR%' OR module LIKE 'ITR2_ORCHESTRATOR%' THEN '0.ORCHESTRATOR'
 WHEN module IN ('TRIGGERS') THEN '0.TRIGGERS'
 WHEN module IN ('PAYMENT','BULK_PAYMENT','ADMIN_TEMPLATE','META_CONDITION','CLEANUP') THEN 'B.ITR1 (Codes)'
 WHEN module LIKE 'PHASE1%' OR module = 'ADMIN_USER' THEN 'D1.Admin User'
 WHEN module LIKE 'PHASE2%' OR module = 'APPROBATION_GROUP_USERS' THEN 'D2.Approbation'
 WHEN module LIKE 'PHASE3%' OR module = 'USER_SETTING' THEN 'D3.User Setting'
 WHEN module LIKE 'PHASE4%' OR module = 'USER_FIELDS' THEN 'D4.User Fields'
 WHEN module = 'NOTIFICATION_USER' THEN 'D5.Notif User'
 WHEN module = 'PAYMENT_AUDIT' THEN 'D6.Payment Audit'
 WHEN module = 'PAYMENT_TEXT' OR module = 'TEMPLATE_TEXT' THEN 'D7.Free Text'
 WHEN module IN ('CORRESP_ADDR','BENEF_BANK','BILL_REMIT') THEN 'D8.Addresses'
 WHEN module = 'SWIFT_COMPONENTS' THEN 'D9.SWIFT'
 WHEN module IN ('SIRET','CLEARING') THEN 'D10.SIRET/Clear'
 WHEN module IN ('INVOICE','TRANSMISSION_CONTRACT') THEN 'D11.Invoice/TC'
 ELSE module
 END AS phase,
 COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END) AS success,
 COUNT(CASE WHEN status = 'ERROR' THEN 1 END) AS errors,
 SUM(rows_affected) AS total_rows,
 MAX(TO_CHAR(log_timestamp, 'HH24:MI:SS')) AS last_activity
FROM oppayments.epf_anon_log
WHERE run_id = (SELECT MAX(run_id) FROM oppayments.epf_anon_log)
GROUP BY
 CASE
 WHEN module LIKE 'ORCHESTRATOR%' OR module LIKE 'ITR2_ORCHESTRATOR%' THEN '0.ORCHESTRATOR'
 WHEN module IN ('TRIGGERS') THEN '0.TRIGGERS'
 WHEN module IN ('PAYMENT','BULK_PAYMENT','ADMIN_TEMPLATE','META_CONDITION','CLEANUP') THEN 'B.ITR1 (Codes)'
 WHEN module LIKE 'PHASE1%' OR module = 'ADMIN_USER' THEN 'D1.Admin User'
 WHEN module LIKE 'PHASE2%' OR module = 'APPROBATION_GROUP_USERS' THEN 'D2.Approbation'
 WHEN module LIKE 'PHASE3%' OR module = 'USER_SETTING' THEN 'D3.User Setting'
 WHEN module LIKE 'PHASE4%' OR module = 'USER_FIELDS' THEN 'D4.User Fields'
 WHEN module = 'NOTIFICATION_USER' THEN 'D5.Notif User'
 WHEN module = 'PAYMENT_AUDIT' THEN 'D6.Payment Audit'
 WHEN module = 'PAYMENT_TEXT' OR module = 'TEMPLATE_TEXT' THEN 'D7.Free Text'
 WHEN module IN ('CORRESP_ADDR','BENEF_BANK','BILL_REMIT') THEN 'D8.Addresses'
 WHEN module = 'SWIFT_COMPONENTS' THEN 'D9.SWIFT'
 WHEN module IN ('SIRET','CLEARING') THEN 'D10.SIRET/Clear'
 WHEN module IN ('INVOICE','TRANSMISSION_CONTRACT') THEN 'D11.Invoice/TC'
 ELSE module
 END
ORDER BY phase;

-- ============================================================================
-- SECTION 3: Direct Table Verification (coverage checks)
-- ============================================================================
SELECT
 check_name,
 done,
 total,
 total - done AS remaining,
 CASE WHEN total > 0 THEN ROUND(done * 100.0 / total, 1) ELSE 100 END AS pct_done
FROM (
 -- Admin User codes anonymized
 SELECT 'A. admin_user (USR_)' AS check_name,
 COUNT(CASE WHEN code LIKE 'USR_%' THEN 1 END) AS done,
 COUNT(*) AS total
 FROM oppayments.admin_user

 UNION ALL

 -- Payment user_id cascaded
 SELECT 'B. payment.user_id',
 COUNT(CASE WHEN user_id LIKE 'USR_%' OR user_id IS NULL THEN 1 END),
 COUNT(*)
 FROM oppayments.payment

 UNION ALL

 -- Payment free-text anonymized
 SELECT 'C. payment free-text (benef_desc)',
 COUNT(CASE WHEN benef_description IS NULL OR benef_description LIKE 'BENEF_%' THEN 1 END),
 COUNT(*)
 FROM oppayments.payment

 UNION ALL

 -- Payment code fields cascaded (entity_code should match OP tiers)
 SELECT 'D. payment.entity_code (E_/P_)',
 COUNT(CASE WHEN entity_code IS NULL OR entity_code LIKE 'E_%' OR entity_code LIKE 'P_%' THEN 1 END),
 COUNT(*)
 FROM oppayments.payment

 UNION ALL

 -- Bulk payment codes
 SELECT 'E. bulk_payment.entity_code',
 COUNT(CASE WHEN entity_code IS NULL OR entity_code LIKE 'E_%' OR entity_code LIKE 'P_%' THEN 1 END),
 COUNT(*)
 FROM oppayments.bulk_payment

 UNION ALL

 -- Admin template free-text
 SELECT 'F. admin_template free-text',
 COUNT(CASE WHEN benef_description IS NULL OR benef_description LIKE 'BENEF_%' THEN 1 END),
 COUNT(*)
 FROM oppayments.admin_template

 UNION ALL

 -- Payment audit user_id
 SELECT 'G. payment_audit.user_id',
 COUNT(CASE WHEN user_id IS NULL OR user_id LIKE 'USR_%' THEN 1 END),
 COUNT(*)
 FROM oppayments.payment_audit

 UNION ALL

 -- Corresp addresses
 SELECT 'H. FC corresp addresses',
 COUNT(CASE WHEN final_corresp_description IS NULL OR final_corresp_description LIKE 'FC_%' THEN 1 END),
 COUNT(*)
 FROM oppayments.payment

 UNION ALL

 -- SIRET
 SELECT 'I. entity_siret (14-digit)',
 COUNT(CASE WHEN entity_siret IS NULL OR (LENGTH(entity_siret) = 14 AND NOT REGEXP_LIKE(entity_siret, '[A-Za-z]')) THEN 1 END),
 COUNT(*)
 FROM oppayments.payment

 UNION ALL

 -- Benef bank
 SELECT 'J. benef_bank_description',
 COUNT(CASE WHEN benef_bank_description IS NULL OR benef_bank_description LIKE 'BBANK_%' THEN 1 END),
 COUNT(*)
 FROM oppayments.payment
)
ORDER BY check_name;
-- ============================================================================
-- SECTION 4: Execution Timeline (elapsed per step)
-- ============================================================================
SELECT step_number, module, operation, table_name,
 rows_affected,
 ROUND(elapsed_seconds, 1) AS elapsed_secs,
 status
FROM oppayments.epf_anon_log
WHERE run_id = (SELECT MAX(run_id) FROM oppayments.epf_anon_log)
 AND operation NOT LIKE '%START%'
 AND status IN ('SUCCESS', 'ERROR')
ORDER BY step_number NULLS FIRST, log_id;

-- ============================================================================
-- SECTION 5: Error Details (if any)
-- ============================================================================
SELECT log_id, module, table_name, error_code, error_message,
 TO_CHAR(log_timestamp, 'HH24:MI:SS') AS time_stamp
FROM oppayments.epf_anon_log
WHERE status = 'ERROR'
 AND run_id = (SELECT MAX(run_id) FROM oppayments.epf_anon_log)
ORDER BY log_id;

-- ============================================================================
-- SECTION 6: Overall status
-- ============================================================================
SELECT
 CASE
 WHEN EXISTS (SELECT 1 FROM oppayments.epf_anon_log WHERE status = 'ERROR' AND run_id = (SELECT MAX(run_id) FROM oppayments.epf_anon_log))
 THEN 'FAILED (check errors above)'
 WHEN EXISTS (SELECT 1 FROM oppayments.epf_anon_log WHERE operation = 'RUN_END' AND module = 'ITR2_ORCHESTRATOR' AND run_id = (SELECT MAX(run_id) FROM oppayments.epf_anon_log))
 THEN 'COMPLETE'
 WHEN EXISTS (SELECT 1 FROM oppayments.epf_anon_log WHERE run_id = (SELECT MAX(run_id) FROM oppayments.epf_anon_log))
 THEN 'IN PROGRESS (step ' || (SELECT MAX(step_number) FROM oppayments.epf_anon_log WHERE run_id = (SELECT MAX(run_id) FROM oppayments.epf_anon_log) AND status = 'SUCCESS') || ' of 19)'
 ELSE 'NOT STARTED'
 END AS epf_anonymization_status
FROM dual;