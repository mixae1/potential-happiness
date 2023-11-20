set sqlformat csv;
set termout off;
set echo off;
set feedback off;
set sqlformat delimited ; ' '
spool task_e.csv;

select /*csv*/
    distinct car_reg_num, 
    order_id, 
    client_pass,
    substr(min(rented_at) over (partition by order_id, client_pass, car_reg_num), 1, 17) as rented_at,
    substr(max(returned_at) over (partition by order_id, client_pass, car_reg_num), 1, 17) as returned_at,
    ts_diff(max(returned_at) over (partition by order_id, client_pass, car_reg_num),
        min(rented_at) over (partition by order_id, client_pass, car_reg_num)) * cars.price as revenue
from orders_history oh
join cars on cars.reg_num = oh.car_reg_num 
order by order_id;
spool off;