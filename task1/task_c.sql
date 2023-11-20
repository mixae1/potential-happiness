set sqlformat csv;
set termout off;
set echo off;
set feedback off;
set sqlformat delimited ; ' '
spool task_c.csv;

select /*csv*/ 
    id, 
    order_id as "order id",
    substr(changed_at, 1, 17) as "changed at",
    client_pass as client,
    car_reg_num as "reg number of car",
    substr(rented_at, 1, 17) as "rented at",
    substr(returned_at, 1, 17) as "returned at",
    case 
        when status = '1' then 'returned' 
        when status = '0' then 'rented'
    end as status,
    total_price as total,
    note,
    v_user
from orders_history
order by rented_at;
spool off;