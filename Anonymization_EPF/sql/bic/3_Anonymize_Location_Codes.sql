-- ============================================================================
-- Script 3: Anonymize Location Codes (2 characters) - Oracle 19c - UPDATED
-- ============================================================================
-- This script anonymizes positions 7-8 of BIC/SWIFT codes (location code)
-- Maintains consistency across all occurrences via mapping table

-- Step 1: Create function to generate random 2-character location code
-- ============================================================================

create or replace function atrace.generate_random_location_code return varchar2 as
 v_chars varchar2(36) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
 v_result varchar2(2) := '';
 v_pos number;
begin
 for i in 1..2 loop
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

-- Step 2: Extract all unique location codes and create mappings
-- ============================================================================

-- Insert location code mappings for 87A, BIC, 82A (standard BIC format)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value,
 7,
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
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = substr(
 value,
 7,
 2
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_location_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'LOCATION_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'LOCATION_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert location code mappings for 22C (complex format)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct location_code as original_value
 from (
-- Location code from first bank in 22C (positions 5-6)
 select substr(
 value,
 5,
 2
 ) as location_code
 from oppayments.bulk_payment_additional_info
 where key = '22C'
 and value is not null
 and length(value) >= 16
 and regexp_like ( substr(
 value,
 5,
 2
 ),
 '^[A-Z0-9]{2}$' )
 and not regexp_like ( substr(
 value,
 5,
 2
 ),
 '^[0-9]{2}$' )
 union

-- Location code from second bank in 22C (positions 15-16)
 select substr(
 value,
 15,
 2
 ) as location_code
 from oppayments.bulk_payment_additional_info
 where key = '22C'
 and value is not null
 and length(value) >= 16
 and regexp_like ( substr(
 value,
 15,
 2
 ),
 '^[A-Z0-9]{2}$' )
 ) location_codes
 where not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = location_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_location_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'LOCATION_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'LOCATION_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert location code mappings for transmission_contract_attv
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
 ) + 8,
 2
 ) as original_value
 from oppayments.transmission_contract_attv
 where transmission_contract_att_id = 1
 and value is not null
 and value like '%o=%,o=swift%'
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = substr(
 value,
 instr(
 value,
 'o='
 ) + 8,
 2
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_location_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'LOCATION_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'LOCATION_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert location code mappings for PAYMENT table (benef_swift_location_code)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct benef_swift_location_code as original_value
 from oppayments.payment
 where benef_swift_location_code is not null
 and length(benef_swift_location_code) = 2
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = benef_swift_location_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_location_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'LOCATION_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'LOCATION_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert location code mappings for CONFIRMATION_EXCHANGE_DETAILS (VALUE_SENDER)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct location_code as original_value
 from (
-- Standard BIC format (87A, BIC, 82A)
 select substr(
 value_sender,
 7,
 2
 ) as location_code
 from oppayments.confirmation_exchange_details
 where key_sender in ( '87A',
 'BIC',
 '82A' )
 and value_sender is not null
 and length(value_sender) >= 8
 union

-- 22C format - first location code
 select substr(
 value_sender,
 5,
 2
 ) as location_code
 from oppayments.confirmation_exchange_details
 where key_sender = '22C'
 and value_sender is not null
 and length(value_sender) >= 16
 and regexp_like ( substr(
 value_sender,
 5,
 2
 ),
 '^[A-Z0-9]{2}$' )
 and not regexp_like ( substr(
 value_sender,
 5,
 2
 ),
 '^[0-9]{2}$' )
 union

-- 22C format - second location code
 select substr(
 value_sender,
 15,
 2
 ) as location_code
 from oppayments.confirmation_exchange_details
 where key_sender = '22C'
 and value_sender is not null
 and length(value_sender) >= 16
 and regexp_like ( substr(
 value_sender,
 15,
 2
 ),
 '^[A-Z0-9]{2}$' )
 ) location_codes
 where not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = location_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_location_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'LOCATION_CODE'
 and anonymized_value = v_anon_value;
 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'LOCATION_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert location code mappings for CONFIRMATION_EXCHANGE_DETAILS (VALUE_RECIVER)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct location_code as original_value
 from (
-- Standard BIC format (87A, BIC, 82A)
 select substr(
 value_reciver,
 7,
 2
 ) as location_code
 from oppayments.confirmation_exchange_details
 where key_reciver in ( '87A',
 'BIC',
 '82A' )
 and value_reciver is not null
 and length(value_reciver) >= 8
 union

-- 22C format - first location code
 select substr(
 value_reciver,
 5,
 2
 ) as location_code
 from oppayments.confirmation_exchange_details
 where key_reciver = '22C'
 and value_reciver is not null
 and length(value_reciver) >= 16
 and regexp_like ( substr(
 value_reciver,
 5,
 2
 ),
 '^[A-Z0-9]{2}$' )
 and not regexp_like ( substr(
 value_reciver,
 5,
 2
 ),
 '^[0-9]{2}$' )
 union

-- 22C format - second location code
 select substr(
 value_reciver,
 15,
 2
 ) as location_code
 from oppayments.confirmation_exchange_details
 where key_reciver = '22C'
 and value_reciver is not null
 and length(value_reciver) >= 16
 and regexp_like ( substr(
 value_reciver,
 15,
 2
 ),
 '^[A-Z0-9]{2}$' )
 ) location_codes
 where not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = location_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_location_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'LOCATION_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'LOCATION_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Insert location code mappings for CONFIRMATION_EXCHANGE_INFO (value column)
declare
 v_anon_value varchar2(2);
 v_exists number;
begin
 for rec in (
 select distinct location_code as original_value
 from (
-- Standard BIC format (87A, BIC, 82A)
 select substr(
 value,
 7,
 2
 ) as location_code
 from oppayments.confirmation_exchange_info
 where key in ( '87A',
 'BIC',
 '82A' )
 and value is not null
 and length(value) >= 8
 union

-- 22C format - first location code
 select substr(
 value,
 5,
 2
 ) as location_code
 from oppayments.confirmation_exchange_info
 where key = '22C'
 and value is not null
 and length(value) >= 16
 and regexp_like ( substr(
 value,
 5,
 2
 ),
 '^[A-Z0-9]{2}$' )
 and not regexp_like ( substr(
 value,
 5,
 2
 ),
 '^[0-9]{2}$' )
 union

-- 22C format - second location code
 select substr(
 value,
 15,
 2
 ) as location_code
 from oppayments.confirmation_exchange_info
 where key = '22C'
 and value is not null
 and length(value) >= 16
 and regexp_like ( substr(
 value,
 15,
 2
 ),
 '^[A-Z0-9]{2}$' )
 ) location_codes
 where not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = location_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_location_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'LOCATION_CODE'
 and anonymized_value = v_anon_value;

 exit when v_exists = 0;
 end loop;

 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'LOCATION_CODE',
 rec.original_value,
 v_anon_value );
 end loop;

commit;
end;
/

-- Step 3: Apply anonymization to actual data
-- ============================================================================

-- Anonymize PAYMENT table - benef_swift_location_code
update oppayments.payment p
 set
 p.benef_swift_location_code = (
 select m.anonymized_value
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = p.benef_swift_location_code
 )
 where p.benef_swift_location_code is not null
 and length(p.benef_swift_location_code) = 2
 and exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.original_value = p.benef_swift_location_code
);

commit;

-- -- VERIFY
-- select p.benef_swift_location_code as location_code_current,
-- a.original_value as location_code_original,
-- a.anonymized_value as location_code_anonymized,
-- count(*) as occurrences
-- from oppayments.payment p
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'LOCATION_CODE'
-- and p.benef_swift_location_code = a.anonymized_value
-- where p.benef_swift_location_code is not null
-- group by p.benef_swift_location_code,
-- a.original_value,
-- a.anonymized_value
-- order by p.benef_swift_location_code;

-- Anonymize BULK_PAYMENT_ADDITIONAL_INFO (87A, BIC, 82A)
merge into oppayments.bulk_payment_additional_info bpai
using (
 select bpai2.rowid as rid,
 substr(
 bpai2.value,
 1,
 6
 )
 || m.anonymized_value
 ||
 case
 when length(bpai2.value) > 8 then
 substr(
 bpai2.value,
 9
 )
 else
 ''
 end
 as new_value
 from oppayments.bulk_payment_additional_info bpai2
 join atrace.epf_anonymization_map m
 on m.component_type = 'LOCATION_CODE'
 and m.original_value = substr(
 bpai2.value,
 7,
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
-- a.original_value as location_original,
-- a.anonymized_value as location_anonymized
-- from oppayments.bulk_payment_additional_info bpai
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'LOCATION_CODE'
-- and substr(
-- bpai.value,
-- 7,
-- 2
-- ) = a.anonymized_value
-- where bpai.key in ( '87A',
-- 'BIC',
-- '82A' )
-- and bpai.value is not null
-- and length(bpai.value) >= 8
-- order by bpai.value;

-- Anonymize BULK_PAYMENT_ADDITIONAL_INFO (22C)
merge into oppayments.bulk_payment_additional_info bpai
using (
 select bpai2.rowid as rid,
 substr(
 bpai2.value,
 1,
 4
 )
 || nvl(
 m1.anonymized_value,
 substr(
 bpai2.value,
 5,
 2
 )
 )
 || substr(
 bpai2.value,
 7,
 8
 )
 || nvl(
 m2.anonymized_value,
 substr(
 bpai2.value,
 15,
 2
 )
 )
 ||
 case
 when length(bpai2.value) > 16 then
 substr(
 bpai2.value,
 17
 )
 else
 ''
 end
 as new_value
 from oppayments.bulk_payment_additional_info bpai2
 left join atrace.epf_anonymization_map m1
 on m1.component_type = 'LOCATION_CODE'
 and m1.original_value = substr(
 bpai2.value,
 5,
 2
 )
 left join atrace.epf_anonymization_map m2
 on m2.component_type = 'LOCATION_CODE'
 and m2.original_value = substr(
 bpai2.value,
 15,
 2
 )
 where bpai2.key = '22C'
 and bpai2.value is not null
 and length(bpai2.value) >= 16
) src on ( bpai.rowid = src.rid )
when matched then update
set bpai.value = src.new_value;

commit;

-- -- VERIFY
-- select bpai.value as value,
-- a1.original_value as first_location_original,
-- a1.anonymized_value as first_location_anonymized,
-- a2.original_value as second_location_original,
-- a2.anonymized_value as second_location_anonymized
-- from oppayments.bulk_payment_additional_info bpai
-- left join atrace.epf_anonymization_map a1
-- on a1.component_type = 'LOCATION_CODE'
-- and substr(
-- bpai.value,
-- 5,
-- 2
-- ) = a1.anonymized_value
-- left join atrace.epf_anonymization_map a2
-- on a2.component_type = 'LOCATION_CODE'
-- and substr(
-- bpai.value,
-- 15,
-- 2
-- ) = a2.anonymized_value
-- where bpai.key = '22C'
-- and bpai.value is not null
-- and length(bpai.value) >= 16
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
 ) + 7
 )
 || m.anonymized_value
 || substr(
 tca2.value,
 instr(
 tca2.value,
 'o='
 ) + 10
 ) as new_value
 from oppayments.transmission_contract_attv tca2
 join atrace.epf_anonymization_map m
 on m.component_type = 'LOCATION_CODE'
 and m.original_value = substr(
 tca2.value,
 instr(
 tca2.value,
 'o='
 ) + 8,
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
-- a.original_value as location_original,
-- a.anonymized_value as location_anonymized
-- from oppayments.transmission_contract_attv tca
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'LOCATION_CODE'
-- and substr(
-- tca.value,
-- instr(
-- tca.value,
-- 'o='
-- ) + 8,
-- 2
-- ) = a.anonymized_value
-- where tca.transmission_contract_att_id = 1
-- and tca.value is not null
-- and tca.value like '%o=%,o=swift%'
-- order by tca.value;

-- Anonymize CONFIRMATION_EXCHANGE_DETAILS - VALUE_SENDER (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 substr(
 ced2.value_sender,
 1,
 6
 )
 || m.anonymized_value
 ||
 case
 when length(ced2.value_sender) > 8 then
 substr(
 ced2.value_sender,
 9
 )
 else
 ''
 end
 as new_value
 from oppayments.confirmation_exchange_details ced2
 join atrace.epf_anonymization_map m
 on m.component_type = 'LOCATION_CODE'
 and m.original_value = substr(
 ced2.value_sender,
 7,
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
-- a.original_value as location_original,
-- a.anonymized_value as location_anonymized
-- from oppayments.confirmation_exchange_details ced
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'LOCATION_CODE'
-- and substr(
-- ced.value_sender,
-- 7,
-- 2
-- ) = a.anonymized_value
-- where ced.key_sender in ( '87A',
-- 'BIC',
-- '82A' )
-- and ced.value_sender is not null
-- and length(ced.value_sender) >= 8
-- order by ced.value_sender;

-- Anonymize CONFIRMATION_EXCHANGE_DETAILS - VALUE_SENDER (22C)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 substr(
 ced2.value_sender,
 1,
 4
 )
 || nvl(
 m1.anonymized_value,
 substr(
 ced2.value_sender,
 5,
 2
 )
 )
 || substr(
 ced2.value_sender,
 7,
 8
 )
 || nvl(
 m2.anonymized_value,
 substr(
 ced2.value_sender,
 15,
 2
 )
 )
 ||
 case
 when length(ced2.value_sender) > 16 then
 substr(
 ced2.value_sender,
 17
 )
 else
 ''
 end
 as new_value
 from oppayments.confirmation_exchange_details ced2
 left join atrace.epf_anonymization_map m1
 on m1.component_type = 'LOCATION_CODE'
 and m1.original_value = substr(
 ced2.value_sender,
 5,
 2
 )
 left join atrace.epf_anonymization_map m2
 on m2.component_type = 'LOCATION_CODE'
 and m2.original_value = substr(
 ced2.value_sender,
 15,
 2
 )
 where ced2.key_sender = '22C'
 and ced2.value_sender is not null
 and length(ced2.value_sender) >= 16
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_sender = src.new_value;

commit;

-- -- VERIFY
-- select ced.value_sender as value_sender,
-- a1.original_value as first_location_original,
-- a1.anonymized_value as first_location_anonymized,
-- a2.original_value as second_location_original,
-- a2.anonymized_value as second_location_anonymized
-- from oppayments.confirmation_exchange_details ced
-- left join atrace.epf_anonymization_map a1
-- on a1.component_type = 'LOCATION_CODE'
-- and substr(
-- ced.value_sender,
-- 5,
-- 2
-- ) = a1.anonymized_value
-- left join atrace.epf_anonymization_map a2
-- on a2.component_type = 'LOCATION_CODE'
-- and substr(
-- ced.value_sender,
-- 15,
-- 2
-- ) = a2.anonymized_value
-- where ced.key_sender = '22C'
-- and ced.value_sender is not null
-- and length(ced.value_sender) >= 16
-- order by ced.value_sender;

-- Anonymize CONFIRMATION_EXCHANGE_DETAILS - VALUE_RECIVER (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 substr(
 ced2.value_reciver,
 1,
 6
 )
 || m.anonymized_value
 ||
 case
 when length(ced2.value_reciver) > 8 then
 substr(
 ced2.value_reciver,
 9
 )
 else
 ''
 end
 as new_value
 from oppayments.confirmation_exchange_details ced2
 join atrace.epf_anonymization_map m
 on m.component_type = 'LOCATION_CODE'
 and m.original_value = substr(
 ced2.value_reciver,
 7,
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
-- a.original_value as location_original,
-- a.anonymized_value as location_anonymized
-- from oppayments.confirmation_exchange_details ced
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'LOCATION_CODE'
-- and substr(
-- ced.value_reciver,
-- 7,
-- 2
-- ) = a.anonymized_value
-- where ced.key_reciver in ( '87A',
-- 'BIC',
-- '82A' )
-- and ced.value_reciver is not null
-- and length(ced.value_reciver) >= 8
-- order by ced.value_reciver;

-- Anonymize CONFIRMATION_EXCHANGE_DETAILS - VALUE_RECIVER (22C)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 substr(
 ced2.value_reciver,
 1,
 4
 )
 || nvl(
 m1.anonymized_value,
 substr(
 ced2.value_reciver,
 5,
 2
 )
 )
 || substr(
 ced2.value_reciver,
 7,
 8
 )
 || nvl(
 m2.anonymized_value,
 substr(
 ced2.value_reciver,
 15,
 2
 )
 )
 ||
 case
 when length(ced2.value_reciver) > 16 then
 substr(
 ced2.value_reciver,
 17
 )
 else
 ''
 end
 as new_value
 from oppayments.confirmation_exchange_details ced2
 left join atrace.epf_anonymization_map m1
 on m1.component_type = 'LOCATION_CODE'
 and m1.original_value = substr(
 ced2.value_reciver,
 5,
 2
 )
 left join atrace.epf_anonymization_map m2
 on m2.component_type = 'LOCATION_CODE'
 and m2.original_value = substr(
 ced2.value_reciver,
 15,
 2
 )
 where ced2.key_reciver = '22C'
 and ced2.value_reciver is not null
 and length(ced2.value_reciver) >= 16
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_reciver = src.new_value;

commit;

-- -- VERIFY
-- select ced.value_reciver as value_reciver,
-- a1.original_value as first_location_original,
-- a1.anonymized_value as first_location_anonymized,
-- a2.original_value as second_location_original,
-- a2.anonymized_value as second_location_anonymized
-- from oppayments.confirmation_exchange_details ced
-- left join atrace.epf_anonymization_map a1
-- on a1.component_type = 'LOCATION_CODE'
-- and substr(
-- ced.value_reciver,
-- 5,
-- 2
-- ) = a1.anonymized_value
-- left join atrace.epf_anonymization_map a2
-- on a2.component_type = 'LOCATION_CODE'
-- and substr(
-- ced.value_reciver,
-- 15,
-- 2
-- ) = a2.anonymized_value
-- where ced.key_reciver = '22C'
-- and ced.value_reciver is not null
-- and length(ced.value_reciver) >= 16
-- order by ced.value_reciver;

-- Anonymize CONFIRMATION_EXCHANGE_INFO - value (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_info cei
using (
 select cei2.rowid as rid,
 substr(
 cei2.value,
 1,
 6
 )
 || m.anonymized_value
 ||
 case
 when length(cei2.value) > 8 then
 substr(
 cei2.value,
 9
 )
 else
 ''
 end
 as new_value
 from oppayments.confirmation_exchange_info cei2
 join atrace.epf_anonymization_map m
 on m.component_type = 'LOCATION_CODE'
 and m.original_value = substr(
 cei2.value,
 7,
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
-- a.original_value as location_original,
-- a.anonymized_value as location_anonymized
-- from oppayments.confirmation_exchange_info cei
-- left join atrace.epf_anonymization_map a
-- on a.component_type = 'LOCATION_CODE'
-- and substr(
-- cei.value,
-- 7,
-- 2
-- ) = a.anonymized_value
-- where cei.key in ( '87A',
-- 'BIC',
-- '82A' )
-- and cei.value is not null
-- and length(cei.value) >= 8
-- order by cei.value;

-- Anonymize CONFIRMATION_EXCHANGE_INFO - value (22C)
merge into oppayments.confirmation_exchange_info cei
using (
 select cei2.rowid as rid,
 substr(
 cei2.value,
 1,
 4
 )
 || nvl(
 m1.anonymized_value,
 substr(
 cei2.value,
 5,
 2
 )
 )
 || substr(
 cei2.value,
 7,
 8
 )
 || nvl(
 m2.anonymized_value,
 substr(
 cei2.value,
 15,
 2
 )
 )
 ||
 case
 when length(cei2.value) > 16 then
 substr(
 cei2.value,
 17
 )
 else
 ''
 end
 as new_value
 from oppayments.confirmation_exchange_info cei2
 left join atrace.epf_anonymization_map m1
 on m1.component_type = 'LOCATION_CODE'
 and m1.original_value = substr(
 cei2.value,
 5,
 2
 )
 left join atrace.epf_anonymization_map m2
 on m2.component_type = 'LOCATION_CODE'
 and m2.original_value = substr(
 cei2.value,
 15,
 2
 )
 where cei2.key = '22C'
 and cei2.value is not null
 and length(cei2.value) >= 16
) src on ( cei.rowid = src.rid )
when matched then update
set cei.value = src.new_value;

commit;

-- --VERIFY
-- select cei.value as value,
-- a1.original_value as first_location_original,
-- a1.anonymized_value as first_location_anonymized,
-- a2.original_value as second_location_original,
-- a2.anonymized_value as second_location_anonymized
-- from oppayments.confirmation_exchange_info cei
-- left join atrace.epf_anonymization_map a1
-- on a1.component_type = 'LOCATION_CODE'
-- and substr(
-- cei.value,
-- 5,
-- 2
-- ) = a1.anonymized_value
-- left join atrace.epf_anonymization_map a2
-- on a2.component_type = 'LOCATION_CODE'
-- and substr(
-- cei.value,
-- 15,
-- 2
-- ) = a2.anonymized_value
-- where cei.key = '22C'
-- and cei.value is not null
-- and length(cei.value) >= 16
-- order by cei.value;

-- Step 4: Verification queries
-- ============================================================================

select 'Location Code Mappings' as verification_step,
 count(*) as total_mappings
 from atrace.epf_anonymization_map
 where component_type = 'LOCATION_CODE';

select 'BULK_PAYMENT_ADDITIONAL_INFO Updated' as verification_step,
 count(*) as records_updated
 from oppayments.bulk_payment_additional_info bpai
 where exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'LOCATION_CODE'
 and m.anonymized_value = substr(
 bpai.value,
 7,
 2
 )
);