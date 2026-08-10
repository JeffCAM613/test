-- ============================================================================
-- Script 1: Anonymize Bank Codes (4 characters) - Oracle 19c - COMPLETE
-- ============================================================================

create or replace function atrace.generate_random_bank_code return varchar2 as
 v_chars varchar2(26) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
 v_result varchar2(4) := '';
 v_pos number;
begin
 for i in 1..4 loop
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

-- Step 2: Extract unique bank codes and create mappings
-- ============================================================================

-- BULK_PAYMENT_ADDITIONAL_INFO: 87A, BIC, 82A
declare
 v_anon_value varchar2(4);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value,
 1,
 4
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
 where m.component_type = 'BANK_CODE'
 and m.original_value = substr(
 value,
 1,
 4
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_bank_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BANK_CODE'
 and anonymized_value = v_anon_value;
 exit when v_exists = 0;
 end loop;
 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BANK_CODE',
 rec.original_value,
 v_anon_value );
 end loop;
end;
/

-- BULK_PAYMENT_ADDITIONAL_INFO: 22C
declare
 v_anon_value varchar2(4);
 v_exists number;
begin
 for rec in (
 select distinct bank_code as original_value
 from (
 select substr(
 value,
 1,
 4
 ) as bank_code
 from oppayments.bulk_payment_additional_info
 where key = '22C'
 and value is not null
 and length(value) >= 14
 union
 select substr(
 value,
 11,
 4
 ) as bank_code
 from oppayments.bulk_payment_additional_info
 where key = '22C'
 and value is not null
 and length(value) >= 14
 ) bank_codes
 where length(bank_code) = 4
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BANK_CODE'
 and m.original_value = bank_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_bank_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BANK_CODE'
 and anonymized_value = v_anon_value;
 exit when v_exists = 0;
 end loop;
 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BANK_CODE',
 rec.original_value,
 v_anon_value );
 end loop;
end;
/

-- transmission_contract_attv
declare
 v_anon_value varchar2(4);
 v_exists number;
begin
 for rec in (
 select distinct substr(
 value,
 instr(
 value,
 'o='
 ) + 2,
 4
 ) as original_value
 from oppayments.transmission_contract_attv
 where transmission_contract_att_id = 1
 and value is not null
 and value like '%o=%,o=swift%'
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BANK_CODE'
 and m.original_value = substr(
 value,
 instr(
 value,
 'o='
 ) + 2,
 4
 )
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_bank_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BANK_CODE'
 and anonymized_value = v_anon_value;
 exit when v_exists = 0;
 end loop;
 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BANK_CODE',
 rec.original_value,
 v_anon_value );
 end loop;
end;
/

-- CONFIRMATION_EXCHANGE_DETAILS: VALUE_SENDER
declare
 v_anon_value varchar2(4);
 v_exists number;
begin
 for rec in (
 select distinct bank_code as original_value
 from (
 select substr(
 value_sender,
 1,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_details
 where key_sender in ( '87A',
 'BIC',
 '82A' )
 and value_sender is not null
 and length(value_sender) >= 8
 union
 select substr(
 value_sender,
 1,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_details
 where key_sender = '22C'
 and value_sender is not null
 and length(value_sender) >= 14
 union
 select substr(
 value_sender,
 11,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_details
 where key_sender = '22C'
 and value_sender is not null
 and length(value_sender) >= 14
 ) bank_codes
 where length(bank_code) = 4
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BANK_CODE'
 and m.original_value = bank_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_bank_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BANK_CODE'
 and anonymized_value = v_anon_value;
 exit when v_exists = 0;
 end loop;
 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BANK_CODE',
 rec.original_value,
 v_anon_value );
 end loop;
end;
/

-- CONFIRMATION_EXCHANGE_DETAILS: VALUE_RECIVER
declare
 v_anon_value varchar2(4);
 v_exists number;
begin
 for rec in (
 select distinct bank_code as original_value
 from (
 select substr(
 value_reciver,
 1,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_details
 where key_reciver in ( '87A',
 'BIC',
 '82A' )
 and value_reciver is not null
 and length(value_reciver) >= 8
 union
select substr(
 value_reciver,
 1,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_details
 where key_reciver = '22C'
 and value_reciver is not null
 and length(value_reciver) >= 14
 union
 select substr(
 value_reciver,
 11,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_details
 where key_reciver = '22C'
 and value_reciver is not null
 and length(value_reciver) >= 14
 ) bank_codes
 where length(bank_code) = 4
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BANK_CODE'
 and m.original_value = bank_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_bank_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BANK_CODE'
 and anonymized_value = v_anon_value;
 exit when v_exists = 0;
 end loop;
 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BANK_CODE',
 rec.original_value,
 v_anon_value );
 end loop;
end;
/

-- CONFIRMATION_EXCHANGE_INFO: value
declare
 v_anon_value varchar2(4);
 v_exists number;
begin
 for rec in (
 select distinct bank_code as original_value
 from (
 select substr(
 value,
 1,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_info
 where key in ( '87A',
 'BIC',
 '82A' )
 and value is not null
 and length(value) >= 8
 union
 select substr(
 value,
 1,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_info
 where key = '22C'
 and value is not null
 and length(value) >= 14
 union
 select substr(
 value,
 11,
 4
 ) as bank_code
 from oppayments.confirmation_exchange_info
 where key = '22C'
 and value is not null
 and length(value) >= 14
 ) bank_codes
 where length(bank_code) = 4
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BANK_CODE'
 and m.original_value = bank_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_bank_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BANK_CODE'
 and anonymized_value = v_anon_value;
 exit when v_exists = 0;
 end loop;
 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BANK_CODE',
 rec.original_value,
 v_anon_value );
 end loop;
end;
/

-- payment: benef_swift_bank_code
declare
 v_anon_value varchar2(4);
 v_exists number;
begin
 for rec in (
 select distinct benef_swift_bank_code as original_value
 from oppayments.payment
 where benef_swift_bank_code is not null
 and not exists (
 select 1
 from atrace.epf_anonymization_map m
 where m.component_type = 'BANK_CODE'
 and m.original_value = benef_swift_bank_code
 )
 ) loop
 loop
 v_anon_value := atrace.generate_random_bank_code();
 select count(*)
 into v_exists
 from atrace.epf_anonymization_map
 where component_type = 'BANK_CODE'
 and anonymized_value = v_anon_value;
 exit when v_exists = 0;
 end loop;
 insert into atrace.epf_anonymization_map (
 component_type,
 original_value,
 anonymized_value
 ) values ( 'BANK_CODE',
 rec.original_value,
 v_anon_value );
 end loop;
end;
/

-- Step 3: Apply anonymization
-- ============================================================================

-- BULK_PAYMENT_ADDITIONAL_INFO: 87A, BIC, 82A
merge into oppayments.bulk_payment_additional_info bpai
using (
 select bpai2.rowid as rid,
 m.anonymized_value
 || substr(
 bpai2.value,
 5
 ) as new_value
 from oppayments.bulk_payment_additional_info bpai2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BANK_CODE'
 and m.original_value = substr(
 bpai2.value,
 1,
 4
 )
 where bpai2.key in ( '87A',
 'BIC',
 '82A' )
 and bpai2.value is not null
 and length(bpai2.value) >= 8
) src on ( bpai.rowid = src.rid )
when matched then update
set bpai.value = src.new_value;

-- BULK_PAYMENT_ADDITIONAL_INFO: 22C
merge into oppayments.bulk_payment_additional_info bpai
using (
 select bpai2.rowid as rid,
 nvl(
 m1.anonymized_value,
 substr(
 bpai2.value,
 1,
 4
 )
 )
 || substr(
 bpai2.value,
 5,
 6
 )
 || nvl(
 m2.anonymized_value,
 substr(
 bpai2.value,
 11,
 4
 )
 )
 || substr(
 bpai2.value,
 15
 ) as new_value
 from oppayments.bulk_payment_additional_info bpai2
 left join atrace.epf_anonymization_map m1
 on m1.component_type = 'BANK_CODE'
 and m1.original_value = substr(
 bpai2.value,
 1,
 4
 )
 left join atrace.epf_anonymization_map m2
 on m2.component_type = 'BANK_CODE'
 and m2.original_value = substr(
 bpai2.value,
 11,
 4
 )
 where bpai2.key = '22C'
 and bpai2.value is not null
 and length(bpai2.value) >= 14
) src on ( bpai.rowid = src.rid )
when matched then update
set bpai.value = src.new_value;

-- transmission_contract_attv
merge into oppayments.transmission_contract_attv tca
using (
 select tca2.rowid as rid,
 substr(
 tca2.value,
 1,
 instr(
 tca2.value,
 'o='
 ) + 1
 )
 || m.anonymized_value
 || substr(
 tca2.value,
 instr(
 tca2.value,
 'o='
 ) + 6
 ) as new_value
 from oppayments.transmission_contract_attv tca2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BANK_CODE'
 and m.original_value = substr(
 tca2.value,
 instr(
 tca2.value,
 'o='
 ) + 2,
 4
 )
 where tca2.transmission_contract_att_id = 1
 and tca2.value is not null
 and tca2.value like '%o=%,o=swift%'
) src on ( tca.rowid = src.rid )
when matched then update
set tca.value = src.new_value;

-- CONFIRMATION_EXCHANGE_DETAILS: VALUE_SENDER (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 m.anonymized_value
 || substr(
 ced2.value_sender,
 5
 ) as new_value
 from oppayments.confirmation_exchange_details ced2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BANK_CODE'
 and m.original_value = substr(
ced2.value_sender,
 1,
 4
 )
 where ced2.key_sender in ( '87A',
 'BIC',
 '82A' )
 and ced2.value_sender is not null
 and length(ced2.value_sender) >= 8
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_sender = src.new_value;

-- CONFIRMATION_EXCHANGE_DETAILS: VALUE_SENDER (22C)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 nvl(
 m1.anonymized_value,
 substr(
 ced2.value_sender,
 1,
 4
 )
 )
 || substr(
 ced2.value_sender,
 5,
 6
 )
 || nvl(
 m2.anonymized_value,
 substr(
 ced2.value_sender,
 11,
 4
 )
 )
 || substr(
 ced2.value_sender,
 15
 ) as new_value
 from oppayments.confirmation_exchange_details ced2
 left join atrace.epf_anonymization_map m1
 on m1.component_type = 'BANK_CODE'
 and m1.original_value = substr(
 ced2.value_sender,
 1,
 4
 )
 left join atrace.epf_anonymization_map m2
 on m2.component_type = 'BANK_CODE'
 and m2.original_value = substr(
 ced2.value_sender,
 11,
 4
 )
 where ced2.key_sender = '22C'
 and ced2.value_sender is not null
 and length(ced2.value_sender) >= 14
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_sender = src.new_value;

-- CONFIRMATION_EXCHANGE_DETAILS: VALUE_RECIVER (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 m.anonymized_value
 || substr(
 ced2.value_reciver,
 5
 ) as new_value
 from oppayments.confirmation_exchange_details ced2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BANK_CODE'
 and m.original_value = substr(
 ced2.value_reciver,
 1,
 4
 )
 where ced2.key_reciver in ( '87A',
 'BIC',
 '82A' )
 and ced2.value_reciver is not null
 and length(ced2.value_reciver) >= 8
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_reciver = src.new_value;

-- CONFIRMATION_EXCHANGE_DETAILS: VALUE_RECIVER (22C)
merge into oppayments.confirmation_exchange_details ced
using (
 select ced2.rowid as rid,
 nvl(
 m1.anonymized_value,
 substr(
 ced2.value_reciver,
 1,
 4
 )
 )
 || substr(
 ced2.value_reciver,
 5,
 6
 )
 || nvl(
 m2.anonymized_value,
 substr(
 ced2.value_reciver,
 11,
 4
 )
 )
 || substr(
 ced2.value_reciver,
 15
 ) as new_value
 from oppayments.confirmation_exchange_details ced2
 left join atrace.epf_anonymization_map m1
 on m1.component_type = 'BANK_CODE'
 and m1.original_value = substr(
 ced2.value_reciver,
 1,
 4
 )
 left join atrace.epf_anonymization_map m2
 on m2.component_type = 'BANK_CODE'
 and m2.original_value = substr(
 ced2.value_reciver,
 11,
 4
 )
 where ced2.key_reciver = '22C'
 and ced2.value_reciver is not null
 and length(ced2.value_reciver) >= 14
) src on ( ced.rowid = src.rid )
when matched then update
set ced.value_reciver = src.new_value;

-- CONFIRMATION_EXCHANGE_INFO: value (87A, BIC, 82A)
merge into oppayments.confirmation_exchange_info cei
using (
 select cei2.rowid as rid,
 m.anonymized_value
 || substr(
 cei2.value,
 5
 ) as new_value
 from oppayments.confirmation_exchange_info cei2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BANK_CODE'
 and m.original_value = substr(
 cei2.value,
 1,
 4
 )
 where cei2.key in ( '87A',
 'BIC',
 '82A' )
 and cei2.value is not null
 and length(cei2.value) >= 8
) src on ( cei.rowid = src.rid )
when matched then update
set cei.value = src.new_value;

-- CONFIRMATION_EXCHANGE_INFO: value (22C)
merge into oppayments.confirmation_exchange_info cei
using (
 select cei2.rowid as rid,
 nvl(
 m1.anonymized_value,
 substr(
 cei2.value,
 1,
 4
 )
 )
 || substr(
 cei2.value,
 5,
 6
 )
 || nvl(
 m2.anonymized_value,
 substr(
 cei2.value,
 11,
 4
 )
 )
 || substr(
 cei2.value,
 15
 ) as new_value
 from oppayments.confirmation_exchange_info cei2
 left join atrace.epf_anonymization_map m1
 on m1.component_type = 'BANK_CODE'
 and m1.original_value = substr(
 cei2.value,
 1,
 4
 )
 left join atrace.epf_anonymization_map m2
 on m2.component_type = 'BANK_CODE'
 and m2.original_value = substr(
 cei2.value,
 11,
 4
 )
 where cei2.key = '22C'
 and cei2.value is not null
 and length(cei2.value) >= 14
) src on ( cei.rowid = src.rid )
when matched then update
set cei.value = src.new_value;

-- payment: benef_swift_bank_code
merge into oppayments.payment p
using (
 select p2.rowid as rid,
 m.anonymized_value as new_value
 from oppayments.payment p2
 join atrace.epf_anonymization_map m
 on m.component_type = 'BANK_CODE'
 and m.original_value = p2.benef_swift_bank_code
 where p2.benef_swift_bank_code is not null
) src on ( p.rowid = src.rid )
when matched then update
set p.benef_swift_bank_code = src.new_value;

-- Verification
select 'Bank Code Mappings' as check_type,
 count(*) as total
 from atrace.epf_anonymization_map
 where component_type = 'BANK_CODE';

commit;