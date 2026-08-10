-- ============================================================================
-- Script 4: Anonymize Branch Codes (3 characters) - Oracle 19c - UPDATED
-- ============================================================================
-- This script anonymizes positions 9-11 of BIC/SWIFT codes (branch code)
-- Maintains consistency across all occurrences via mapping table
-- NOTE: 'XXX' branch codes are kept as-is per requirements

-- Step 1: Create function to generate random 3-character branch code
-- ============================================================================

create or replace function atrace.generate_random_branch_code return varchar2 as
 v_chars varchar2(36) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
 v_result varchar2(3) := '';
 v_pos number;
begin
 for i in 1..3 loop
 v_pos := trunc(dbms_random.value(
 1,
 37
 ));
 v_result := v_result
 || substr(
 v_chars,
 v_pos,
 1
 );
 end loop;
 return v_result;
end;
/

-- Step 2: Extract all unique branch codes and create mappings
-- ============================================================================

-- Insert branch code mappings for BULK_PAYMENT_ADDITIONAL_INFO (87A, BIC)
declare
 v_anon_value varchar2(3);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value,
 9,
 3
 ) as original_value
 from oppayments.bulk_payment_additional_info
 where key in ( '87A',
 'BIC' )
 and value is not null
 and length(value) = 11
 and substr(
 value,
 9,
 3
 ) != 'XXX'
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BRANCH_CODE'
 and m.original_value = substr(
 value,
 9,
 3
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_branch_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BRANCH_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BRANCH_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert branch code mappings for PAYMENT table (benef_swift_branch_code)
declare
 v_anon_value varchar2(3);
 v_exists number;
begin
 for rec in (
 select distinct benef_swift_branch_code as original_value
 from oppayments.payment
 where benef_swift_branch_code is not null
 and length(benef_swift_branch_code) = 3
 and benef_swift_branch_code != 'XXX'
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BRANCH_CODE'
 and m.original_value = benef_swift_branch_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_branch_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BRANCH_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BRANCH_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert branch code mappings for CONFIRMATION_EXCHANGE_DETAILS (VALUE_SENDER)
declare
 v_anon_value varchar2(3);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value_sender,
 9,
 3
 ) as original_value
 from oppayments.confirmation_exchange_details
 where key_sender in ( '87A',
 'BIC' )
 and value_sender is not null
 and length(value_sender) = 11
 and substr(
 value_sender,
 9,
 3
 ) != 'XXX'
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BRANCH_CODE'
 and m.original_value = substr(
 value_sender,
 9,
 3
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_branch_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BRANCH_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BRANCH_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert branch code mappings for CONFIRMATION_EXCHANGE_DETAILS (VALUE_RECIVER)
declare
 v_anon_value varchar2(3);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value_reciver,
 9,
 3
 ) as original_value
 from oppayments.confirmation_exchange_details
 where key_reciver in ( '87A',
 'BIC' )
 and value_reciver is not null
 and length(value_reciver) = 11
 and substr(
 value_reciver,
 9,
 3
 ) != 'XXX'
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BRANCH_CODE'
 and m.original_value = substr(
 value_reciver,
 9,
 3
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_branch_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BRANCH_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BRANCH_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert branch code mappings for CONFIRMATION_EXCHANGE_INFO (value column)
declare
 v_anon_value varchar2(3);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value,
 9,
 3
 ) as original_value
 from oppayments.confirmation_exchange_info
 where key in ( '87A',
 'BIC' )
 and value is not null
 and length(value) = 11
 and substr(
 value,
 9,
 3
 ) != 'XXX'
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BRANCH_CODE'
 and m.original_value = substr(
 value,
 9,
 3
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_branch_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BRANCH_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;
 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BRANCH_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Step 3: Apply anonymization to actual data
-- ============================================================================

-- Anonymize PAYMENT table - benef_swift_branch_code
update oppayments.payment p
 set
 p.benef_swift_branch_code = (
 select m.anonymized_value
 from atrace.epf_anonymization_map m
 where m.component_type = 'BRANCH_CODE'
 and m.original_value = p.benef_swift_branch_code
 )
 where p.benef_swift_branch_code is not null
 and length(p.benef_swift_branch_code) = 3
 and p.benef_swift_branch_code != 'XXX'
 and exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BRANCH_CODE'
 and m.original_value = p.benef_swift_branch_code
);

commit;

-- -- VERIFY
-- select p.benef_swift_branch_code as branch_code_current,
-- a.original_value as branch_code_original,
-- a.anonymized_value as branch_code_anonymized,
-- count(*) as occurrences
-- from oppayments.payment p
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'BRANCH_CODE'
-- and p.benef_swift_branch_code = a.anonymized_value
-- where p.benef_swift_branch_code is not null
-- group by p.benef_swift_branch_code,
-- a.original_value,
-- a.anonymized_value
-- order by p.benef_swift_branch_code;

-- Anonymize BULK_PAYMENT_ADDITIONAL_INFO (87A, BIC with branch codes)
merge into oppayments.bulk_payment_additional_info bpai
using (
 select bpai2.rowid as rid,
 substr(
 bpai2.value,
 1,
 8
 )
 || m.anonymized_value as new_value
 from oppayments.bulk_payment_additional_info bpai2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BRANCH_CODE'
 and m.original_value = substr(
 bpai2.value,
 9,
 3
 )
 where bpai2.key in ( '87A',
 'BIC' )
 and bpai2.value is not null
 and length(bpai2.value) = 11
 and substr(
 bpai2.value,
 9,
 3
 ) != 'XXX'
) src on ( bpai.rowid = src.rid )
when matched then update
set bpai.value = src.new_value;

commit;

-- -- VERIFY
-- select bpai.value as value,
-- a.original_value as branch_original,
-- a.anonymized_value as branch_anonymized
-- from oppayments.bulk_payment_additional_info bpai
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'BRANCH_CODE'
-- and substr(
-- bpai.value,
-- 9,
-- 3
-- ) = a.anonymized_value
-- where bpai.key in ( '87A',
-- 'BIC' )
-- and bpai.value is not null
-- and length(bpai.value) = 11
-- and substr(
-- bpai.value,
-- 9,
-- 3
-- ) != 'XXX'
-- order by bpai.value;

-- Anonymize CONFIRMATION_EXCHANGE_DETAILS - VALUE_SENDER (87A, BIC with branch codes)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 substr(
 ced2.value_sender,
 1,
 8
 )
 || m.anonymized_value as new_value
 from oppayments.confirmation_exchange_details ced2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BRANCH_CODE'
 and m.original_value = substr(
 ced2.value_sender,
 9,
 3
 )
 where ced2.key_sender in ( '87A',
 'BIC' )
 and ced2.value_sender is not null
 and length(ced2.value_sender) = 11
 and substr(
 ced2.value_sender,
 9,
 3
 ) != 'XXX'
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_sender = src.new_value;

commit;

-- -- VERIFY
-- select ced.value_sender as value_sender,
-- a.original_value as branch_original,
-- a.anonymized_value as branch_anonymized
-- from oppayments.confirmation_exchange_details ced
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'BRANCH_CODE'
-- and substr(
-- ced.value_sender,
-- 9,
-- 3
-- ) = a.anonymized_value
-- where ced.key_sender in ( '87A',
-- 'BIC' )
-- and ced.value_sender is not null
-- and length(ced.value_sender) = 11
-- and substr(
-- ced.value_sender,
-- 9,
-- 3
-- ) != 'XXX'
-- order by ced.value_sender;

-- Anonymize CONFIRMATION_EXCHANGE_DETAILS - VALUE_RECIVER (87A, BIC with branch codes)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 substr(
 ced2.value_reciver,
 1,
 8
 )
 || m.anonymized_value as new_value
 from oppayments.confirmation_exchange_details ced2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BRANCH_CODE'
 and m.original_value = substr(
 ced2.value_reciver,
 9,
 3
 )
 where ced2.key_reciver in ( '87A',
 'BIC' )
 and ced2.value_reciver is not null
 and length(ced2.value_reciver) = 11
 and substr(
 ced2.value_reciver,
 9,
 3
 ) != 'XXX'
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_reciver = src.new_value;

commit;

-- -- VERIFY
-- select ced.value_reciver as value_reciver,
-- a.original_value as branch_original,
-- a.anonymized_value as branch_anonymized
-- from oppayments.confirmation_exchange_details ced
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'BRANCH_CODE'
-- and substr(
-- ced.value_reciver,
-- 9,
-- 3
-- ) = a.anonymized_value
-- where ced.key_reciver in ( '87A',
-- 'BIC' )
-- and ced.value_reciver is not null
-- and length(ced.value_reciver) = 11
-- and substr(
-- ced.value_reciver,
-- 9,
-- 3
-- ) != 'XXX'
-- order by ced.value_reciver;

-- Anonymize CONFIRMATION_EXCHANGE_INFO - value (87A, BIC with branch codes)
merge into oppayments.confirmation_exchange_info cei
using (
 select cei2.rowid as rid,
 substr(
 cei2.value,
 1,
 8
 )
 || m.anonymized_value as new_value
 from oppayments.confirmation_exchange_info cei2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BRANCH_CODE'
 and m.original_value = substr(
 cei2.value,
 9,
 3
 )
 where cei2.key in ( '87A',
 'BIC' )
 and cei2.value is not null
 and length(cei2.value) = 11
 and substr(
 cei2.value,
 9,
 3
 ) != 'XXX'
) src on ( cei.rowid = src.rid )
when matched then update
set cei.value = src.new_value;

commit;

-- -- VERIFY
-- select cei.value as value,
-- a.original_value as branch_original,
-- a.anonymized_value as branch_anonymized
-- from oppayments.confirmation_exchange_info cei
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'BRANCH_CODE'
-- and substr(
-- cei.value,
-- 9,
-- 3
-- ) = a.anonymized_value
-- where cei.key in ( '87A',
-- 'BIC' )
-- and cei.value is not null
-- and length(cei.value) = 11
-- and substr(
-- cei.value,
-- 9,
-- 3
-- ) != 'XXX'
-- order by cei.value;

-- Step 4: Verification queries
-- ============================================================================

select 'Branch Code Mappings' as check_type,
 count(*) as total_mappings
 from atrace.epf_anonymization_map
 where component_type = 'BRANCH_CODE';
 -- Show distribution of branch codes across all tables
select 'BULK_PAYMENT_ADDITIONAL_INFO' as table_name,
 case
 when length(value) = 11
 and substr(
 value,
 9,
 3
 ) = 'XXX' then
 'XXX (preserved)'
 when length(value) = 11
 and substr(
 value,
 9,
 3
 ) != 'XXX' then
 'Real branch (anonymized)'
 when length(value) = 8 then
 'No branch code'
 else
 'Other'
 end as branch_status,
 count(*) as count
 from oppayments.bulk_payment_additional_info
 where key in ( '87A',
 'BIC' )
 and value is not null
 group by
 case
 when length(value) = 11
 and substr(
 value,
 9,
 3
 ) = 'XXX' then
 'XXX (preserved)'
 when length(value) = 11
 and substr(
 value,
 9,
 3
 ) != 'XXX' then
 'Real branch (anonymized)'
 when length(value) = 8 then
 'No branch code'
 else
 'Other'
 end
union all
select 'CONFIRMATION_EXCHANGE_INFO' as table_name,
 case
 when length(value) = 11
 and substr(
 value,
 9,
 3
 ) = 'XXX' then
 'XXX (preserved)'
 when length(value) = 11
 and substr(
 value,
 9,
 3
 ) != 'XXX' then
 'Real branch (anonymized)'
 when length(value) = 8 then
 'No branch code'
 else
 'Other'
 end as branch_status,
 count(*) as count
 from oppayments.confirmation_exchange_info
 where key in ( '87A',
 'BIC' )
 and value is not null
 group by
 case
 when length(value) = 11
 and substr(
 value,
 9,
 3
 ) = 'XXX' then
 'XXX (preserved)'
 when length(value) = 11
 and substr(
 value,
 9,
 3
 ) != 'XXX' then
 'Real branch (anonymized)'
 when length(value) = 8 then
 'No branch code'
 else
 'Other'
 end
 order by table_name,
 count desc;