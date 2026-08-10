-- ============================================================================
-- Script 2: Anonymize Country Codes (2 characters) - Oracle 19c - COMPLETE
-- ============================================================================
-- This script anonymizes positions 5-6 of BIC/SWIFT codes (country code)
-- Maintains consistency across all occurrences via mapping table

-- Step 1: Create function to generate random 2-character country code
-- ============================================================================

create or replace function atrace.generate_random_country_code return varchar2 as
 v_chars varchar2(26) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
 v_result varchar2(2) := '';
 v_pos number;
begin
 for i in 1..2 loop
 v_pos := trunc(dbms_random.value(
 1,
 27
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

-- Step 2: Extract all unique country codes and create mappings
-- ============================================================================

-- Insert country code mappings for 87A, BIC, 82A (standard BIC format)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value,
 5,
 2
 ) as original_value
 from oppayments.bulk_payment_additional_info
 where key in ( '87A',
 'BIC',
 '82A' )
 and value is not null
 and length(value) >= 8
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 value,
 5,
 2
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_country_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'COUNTRY_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert country code mappings for transmission_contract_attV
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value,
 instr(
 value,
 'o='
 ) + 6,
 2
 ) as original_value
 from oppayments.transmission_contract_attv
 where transmission_contract_att_id = 1
 and value is not null
 and value like '%o=%,o=swift%'
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 value,
 instr(
 value,
 'o='
 ) + 6,
 2
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_country_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'COUNTRY_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert country code mappings for PAYMENT_ADDITIONAL_INFO (CtryOfRes)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct value as original_value
 from oppayments.payment_additional_info
 where key = 'CtryOfRes'
 and value is not null
 and length(value) = 2
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = value
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_country_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'COUNTRY_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert country code mappings for PAYMENT table (benef_account_isocountry)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct benef_account_isocountry as original_value
 from oppayments.payment
 where benef_account_isocountry is not null
 and length(benef_account_isocountry) = 2
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = benef_account_isocountry
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_country_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'COUNTRY_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert country code mappings for PAYMENT table (benef_swift_country_code)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct benef_swift_country_code as original_value
 from oppayments.payment
 where benef_swift_country_code is not null
 and length(benef_swift_country_code) = 2
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = benef_swift_country_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_country_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'COUNTRY_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert country code mappings for CONFIRMATION_EXCHANGE_DETAILS (VALUE_SENDER)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value_sender,
 5,
 2
 ) as original_value
 from oppayments.confirmation_exchange_details
 where key_sender in ( '87A',
 'BIC',
 '82A' )
 and value_sender is not null
 and length(value_sender) >= 8
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 value_sender,
 5,
 2
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_country_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'COUNTRY_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert country code mappings for CONFIRMATION_EXCHANGE_DETAILS (VALUE_RECIVER)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value_reciver,
 5,
 2
 ) as original_value
 from oppayments.confirmation_exchange_details
 where key_reciver in ( '87A',
 'BIC',
 '82A' )
 and value_reciver is not null
 and length(value_reciver) >= 8
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 value_reciver,
 5,
 2
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_country_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'COUNTRY_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert country code mappings for CONFIRMATION_EXCHANGE_INFO (value column)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value,
 5,
 2
 ) as original_value
 from oppayments.confirmation_exchange_info
 where key in ( '87A',
 'BIC',
 '82A' )
 and value is not null
 and length(value) >= 8
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 value,
 5,
 2
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_country_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'COUNTRY_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Step 3: Apply anonymization to actual data
-- ============================================================================

-- Anonymize PAYMENT table - benef_account_isocountry
update oppayments.payment p
 set
 p.benef_account_isocountry = (
 select m.anonymized_value
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = p.benef_account_isocountry
 )
 where p.benef_account_isocountry is not null
 and length(p.benef_account_isocountry) = 2
 and exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = p.benef_account_isocountry
);

commit;

-- -- VERIFY
-- select p.benef_account_isocountry as country_code_current,
-- a.original_value as country_code_original,
-- a.anonymized_value as country_code_anonymized,
-- count(*) as occurrences
-- from oppayments.payment p
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'COUNTRY_CODE'
-- and p.benef_account_isocountry = a.anonymized_value
-- where p.benef_account_isocountry is not null
-- group by p.benef_account_isocountry,
-- a.original_value,
-- a.anonymized_value
-- order by p.benef_account_isocountry;

-- Anonymize PAYMENT table - benef_swift_country_code
update oppayments.payment p
 set
 p.benef_swift_country_code = (
 select m.anonymized_value
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = p.benef_swift_country_code
 )
 where p.benef_swift_country_code is not null
 and length(p.benef_swift_country_code) = 2
 and exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'COUNTRY_CODE'
 and m.original_value = p.benef_swift_country_code
);
commit;

-- -- VERIFY
-- select p.benef_swift_country_code as country_code_current,
-- a.original_value as country_code_original,
-- a.anonymized_value as country_code_anonymized,
-- count(*) as occurrences
-- from oppayments.payment p
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'COUNTRY_CODE'
-- and p.benef_swift_country_code = a.anonymized_value
-- where p.benef_swift_country_code is not null
-- group by p.benef_swift_country_code,
-- a.original_value,
-- a.anonymized_value
-- order by p.benef_swift_country_code;

-- Anonymize 87A, BIC, 82A (standard BIC format)
merge into oppayments.bulk_payment_additional_info bpai
using (
 select bpai2.rowid as rid,
 substr(
 bpai2.value,
 1,
 4
 )
 || m.anonymized_value
 || substr(
 bpai2.value,
 7
 ) as new_value
 from oppayments.bulk_payment_additional_info bpai2
 join atrace.epf_anonymization_map m
 on m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 bpai2.value,
 5,
 2
 )
 where bpai2.key in ( '87A',
 'BIC',
 '82A' )
 and bpai2.value is not null
 and length(bpai2.value) >= 8
) src on ( bpai.rowid = src.rid )
when matched then update
set bpai.value = src.new_value;

commit;

-- -- VERIFY
-- select bpai.value as value,
-- a.original_value as country_original,
-- a.anonymized_value as country_anonymized
-- from oppayments.bulk_payment_additional_info bpai
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'COUNTRY_CODE'
-- and substr(
-- bpai.value,
-- 5,
-- 2
-- ) = a.anonymized_value
-- where bpai.key in ( '87A',
-- 'BIC',
-- '82A' )
-- and bpai.value is not null
-- and length(bpai.value) >= 8
-- order by bpai.value;

-- Anonymize transmission_contract_att
merge into oppayments.transmission_contract_attv tca
using (
 select tca2.rowid as rid,
 substr(
 tca2.value,
 1,
 instr(
 tca2.value,
 'o='
 ) + 5
 )
 || m.anonymized_value
 || substr(
 tca2.value,
 instr(
 tca2.value,
 'o='
 ) + 8
 ) as new_value
 from oppayments.transmission_contract_attv tca2
 join atrace.epf_anonymization_map m
 on m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 tca2.value,
 instr(
 tca2.value,
 'o='
 ) + 6,
 2
 )
 where tca2.transmission_contract_att_id = 1
 and tca2.value is not null
 and tca2.value like '%o=%,o=swift%'
) src on ( tca.rowid = src.rid )
when matched then update
set tca.value = src.new_value;

commit;

-- -- VERIFY
-- select tca.value as value,
-- a.original_value as country_original,
-- a.anonymized_value as country_anonymized
-- from oppayments.transmission_contract_attv tca
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'COUNTRY_CODE'
-- and substr(
-- tca.value,
-- instr(
-- tca.value,
-- 'o='
-- ) + 6,
-- 2
-- ) = a.anonymized_value
-- where tca.transmission_contract_att_id = 1
-- and tca.value is not null
-- and tca.value like '%o=%,o=swift%'
-- order by tca.value;

-- Anonymize PAYMENT_ADDITIONAL_INFO (CtryOfRes)
merge into oppayments.payment_additional_info pai
using (
 select pai2.rowid as rid,
 m.anonymized_value as new_value
 from oppayments.payment_additional_info pai2
 join atrace.epf_anonymization_map m
 on m.component_type = 'COUNTRY_CODE'
 and m.original_value = pai2.value
 where pai2.key = 'CtryOfRes'
 and pai2.value is not null
 and length(pai2.value) = 2
) src on ( pai.rowid = src.rid )
when matched then update
set pai.value = src.new_value;

commit;

-- -- VERIFY
-- select pai.value as value,
-- a.original_value as country_original,
-- a.anonymized_value as country_anonymized
-- from oppayments.payment_additional_info pai
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'COUNTRY_CODE'
-- and pai.value = a.anonymized_value
-- where pai.key = 'CtryOfRes'
-- and pai.value is not null
-- and length(pai.value) = 2
-- order by pai.value;

-- Anonymize CONFIRMATION_EXCHANGE_DETAILS - VALUE_SENDER (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 substr(
 ced2.value_sender,
 1,
 4
 )
 || m.anonymized_value
 || substr(
 ced2.value_sender,
 7
 ) as new_value
 from oppayments.confirmation_exchange_details ced2
 join atrace.epf_anonymization_map m
 on m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 ced2.value_sender,
 5,
 2
 )
 where ced2.key_sender in ( '87A',
 'BIC',
 '82A' )
 and ced2.value_sender is not null
 and length(ced2.value_sender) >= 8
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_sender = src.new_value;

commit;

-- -- VERIFY
-- select ced.value_sender as value_sender,
-- a.original_value as country_original,
-- a.anonymized_value as country_anonymized
-- from oppayments.confirmation_exchange_details ced
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'COUNTRY_CODE'
-- and substr(
-- ced.value_sender,
-- 5,
-- 2
-- ) = a.anonymized_value
-- where ced.key_sender in ( '87A',
-- 'BIC',
-- '82A' )
-- and ced.value_sender is not null
-- and length(ced.value_sender) >= 8
-- order by ced.value_sender;

-- Anonymize CONFIRMATION_EXCHANGE_DETAILS - VALUE_RECIVER (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 substr(
 ced2.value_reciver,
 1,
 4
 )
 || m.anonymized_value
 || substr(
 ced2.value_reciver,
 7
 ) as new_value
 from oppayments.confirmation_exchange_details ced2
 join atrace.epf_anonymization_map m
 on m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 ced2.value_reciver,
 5,
 2
 )
 where ced2.key_reciver in ( '87A',
 'BIC',
 '82A' )
 and ced2.value_reciver is not null
 and length(ced2.value_reciver) >= 8
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_reciver = src.new_value;

commit;

-- -- VERIFY
-- select ced.value_reciver as value_reciver,
-- a.original_value as country_original,
-- a.anonymized_value as country_anonymized
-- from oppayments.confirmation_exchange_details ced
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'COUNTRY_CODE'
-- and substr(
-- ced.value_reciver,
-- 5,
-- 2
-- ) = a.anonymized_value
-- where ced.key_reciver in ( '87A',
-- 'BIC',
-- '82A' )
-- and ced.value_reciver is not null
-- and length(ced.value_reciver) >= 8
-- order by ced.value_reciver;

-- Anonymize CONFIRMATION_EXCHANGE_INFO - value (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_info cei
using (
 select cei2.rowid as rid,
 substr(
 cei2.value,
 1,
 4
 )
 || m.anonymized_value
 || substr(
 cei2.value,
 7
 ) as new_value
 from oppayments.confirmation_exchange_info cei2
 join atrace.epf_anonymization_map m
 on m.component_type = 'COUNTRY_CODE'
 and m.original_value = substr(
 cei2.value,
 5,
 2
 )
 where cei2.key in ( '87A',
 'BIC',
 '82A' )
 and cei2.value is not null
 and length(cei2.value) >= 8
) src on ( cei.rowid = src.rid )
when matched then update
set cei.value = src.new_value;

commit;

-- -- VERIFY
-- select cei.value as value,
-- a.original_value as country_original,
-- a.anonymized_value as country_anonymized
-- from oppayments.confirmation_exchange_info cei
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'COUNTRY_CODE'
-- and substr(
-- cei.value,
-- 5,
-- 2
-- ) = a.anonymized_value
-- where cei.key in ( '87A',
-- 'BIC',
-- '82A' )
-- and cei.value is not null
-- and length(cei.value) >= 8
-- order by cei.value;

-- Step 4: Verification query
-- ============================================================================

select 'Country Code Mappings' as check_type,
 count(*) as total
 from atrace.epf_anonymization_map
 where component_type = 'COUNTRY_CODE';