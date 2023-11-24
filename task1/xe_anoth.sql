set serveroutput on
--=============================
--  Tables
--=============================

CREATE TABLE CARSTATES(
    id int primary key,
    state varchar2(20) unique
);

CREATE TABLE CARS(
    reg_num char(10) primary key,
    state_id int not null,
    color varchar2(20) not null,
    mark varchar2(20) not null,
    type varchar2(20) not null,
    price number(10, 2) not null,
    tech_serv_date date not null,

    foreign key (state_id) references carstates(id)
);

CREATE TABLE CLIENTS(
    pass char(10) primary key,
    name varchar2(40) not null
);

create table orders(
    id integer primary key,
    client_pass char(10) not null unique,
    car_reg_num char(10) not null unique,
    rented_at timestamp not null,
    returned_at timestamp not null,
    total_price number(10, 2) not null,
    
    foreign key (client_pass) references clients(pass),
    foreign key (car_reg_num) references cars(reg_num)
);

create SEQUENCE seq_orders
    minvalue 1
    increment by 1
    cache 10;

create table orders_history(
    id integer primary key,
    order_id int not null,
    changed_at timestamp not null,
    
    client_pass char(10) not null,
    car_reg_num char(10) not null,
    rented_at timestamp not null,
    returned_at timestamp not null,
    status char not null check(status in ('0', '1')),
    total_price number(10, 2) not null,
    
    note varchar2(100),
    v_user varchar2(10) not null
    
    --foreign key (order_id) references orders(id),
    --foreign key (car_reg_num) references cars(reg_num)
) pctfree 2;

create index ind_orders_history_status on orders_history(status);
create index ind_orders_history_car on orders_history(client_pass);
create index ind_orders_history_client on orders_history(car_reg_num);

create SEQUENCE seq_orders_history
    minvalue 1
    increment by 1
    cache 10;

--=============================
--  additional functions
--=============================

create or replace function state_name(state_id IN int) return carstates.state%type as
    ret carstates.state%type;
begin
    select state into ret
    from carstates where id = state_id;
    return ret;
end;
/

create or replace function ts_diff(a timestamp, b timestamp) return number is 
begin
    return (extract (day from (a-b))) +
        (extract (hour from (a-b)) / 24) +
        (extract (minute from (a-b)) / (24*60)) +
        (extract (second from (a-b)) / (24*60*60));
end;
/

--=============================
--  sripts for generating data
--=============================

-- initialize car states
create or replace procedure initCarStates as
begin
    insert into carstates
    values(1, 'waiting');
    insert into carstates
    values(2, 'rented');
    insert into carstates
    values(3, 'onserving');
exception
    when others then
        dbms_output.put_line('err: initCarStates');
end;
/

-- create cars (number of cars and timestamp of purchase)
create or replace procedure randCars(num IN int, added_ts IN timestamp) as
    type CarColorsArray is varray(10) of varchar2(20);
    carColors CarColorsArray := CarColorsArray('red', 'white', 'blue', 'black', 'green', 'gray', 'mixed', 'yellow', 'pink', 'orange');
    type CarTypesArray is varray(10) of varchar2(20);
    carTypes CarTypesArray := CarTypesArray('micro', 'sedan', 'hatchback', 'universal', 'coupe', 'lemousine', 'sportcar', 'crossover', 'pickup', 'minivan');
    type CarMarksArray is varray(10) of varchar2(20);
    carMarks CarMarksArray := CarMarksArray('tesla', 'bmw', 'honda', 'audi', 'jeep', 'toyota', 'dodge', 'subaru', 'nissan', 'kia');
    
    reg char(10);
    total int;
begin

    for i in 1..num loop        
        loop
            reg := dbms_random.string('x', 10);
            
            select count(*) into total
            from cars 
            where cars.reg_num = reg;
            
            exit when total = 0;
        end loop;
        
        insert into cars 
        values(
            dbms_random.string('x', 10),
            1,
            carColors(dbms_random.value(1, 10)),
            carMarks(dbms_random.value(1, 10)),
            carTypes(dbms_random.value(1, 10)),
            dbms_random.value(800, 3000),
            added_ts);
            
    end loop;
exception 
    when others then
        dbms_output.put_line('err: randCars');
end;
/

-- create clients
create or replace procedure randClients(num IN int) as
    pass_buf char(10);
    total int;
    function random_pin (digits IN number) return number as
    begin
      IF digits IS NULL OR digits < 1 OR digits > 39 THEN
        RAISE_APPLICATION_ERROR(-20000,'digits must be 1..39');
      END IF;
     
      IF digits = 1 THEN
        RETURN TRUNC( DBMS_RANDOM.value(0,10) );
      ELSE
        RETURN TRUNC( DBMS_RANDOM.value(
                        POWER(10, digits-1)
                       ,POWER(10, digits) ));
      END IF;
    end random_pin;

begin
    for i in 1..num loop
        loop
            pass_buf := to_char(random_pin(10));
            
            select count(*) into total
            from clients 
            where clients.pass = pass_buf;
            
            exit when total = 0;
        end loop;
    
        insert into clients 
        values(
            pass_buf, 
            dbms_random.string('l', dbms_random.value(5, 8)) || ' ' || dbms_random.string('l', dbms_random.value(5, 8)));
    end loop;
exception
    when others then
        dbms_output.put_line('err: randClients');
end;
/

create or replace trigger log_order_updated
before update or insert on orders
for each row
when (new.id > 0)
declare
    note orders_history.note%type;
    v_username varchar2(10);
begin
    select user into v_username
        from dual;

    if :old.client_pass <> :new.client_pass then
        note := 'client was changed.';
    end if;

    if :old.returned_at <> :new.returned_at then
        note := 'client renewed a car.';
    end if;

    if :old.car_reg_num <> :new.car_reg_num then
        note := 'client changed a car.';
    end if;

    if :old.id is null then
        note := 'order was created.';
    end if;
    
    insert into orders_history
    values(seq_orders_history.nextval,
        :new.id,
        SYSTIMESTAMP, -- generated data will be have wrong ts
        :new.client_pass,
        :new.car_reg_num,
        :new.rented_at,
        :new.returned_at,
        '0',
        :new.total_price,
        note,
        v_username);
end;
/

create or replace trigger log_order_deleted
before delete on orders
for each row
declare
    v_username varchar2(10);
begin
    select user into v_username
        from dual;
    
    insert into orders_history
    values(seq_orders_history.nextval,
        :old.id,
        SYSTIMESTAMP, -- generated data will be have wrong ts
        :old.client_pass,
        :old.car_reg_num,
        :old.rented_at,
        :old.returned_at,
        '1',
        :old.total_price,
        'client returned a car.',
        v_username);
end;
/
-- create orders
create or replace procedure randOrders(days in NUMBER) as 
    start_ts timestamp := SYSTIMESTAMP - days; -- days before now
    end_ts timestamp := SYSTIMESTAMP;
    curr_ts timestamp;

    min_interval number := 10 / (24*60); -- 10 minutes
    max_interval number := 3 / 24; -- 3 hours

    rc_pass clients.pass%type;
    order_data orders%rowtype;

    function randClient 
        return char as
    client_pass clients.pass%type;
    begin
        select pass into client_pass
        from clients
        order by dbms_random.random()
        fetch next 1 rows only;
        return client_pass;
    end randClient;

    function randCar 
        return cars%rowtype as
    car_data cars%rowtype;
    begin
        select * into car_data
        from cars
        where state_id = 1
        order by dbms_random.random()
        fetch next 1 rows only;
        return car_data;
    exception
        when no_data_found then
            return car_data;
    end randCar;
begin
    curr_ts := start_ts;
    loop
        -- close all orders, where curr_timestamp > order.returned_at
        update cars
        set state_id = 1
        where reg_num = any(
            select car_reg_num
            from orders
            where returned_at <= curr_ts);

        delete from orders
        where returned_at <= curr_ts;

        -- next ts
        curr_ts := curr_ts + dbms_random.value(min_interval, max_interval);

        -- send cars to tech serving
        
        update cars
        set state_id = 3,
            tech_serv_date = curr_ts
        where state_id = 1 and ts_diff(curr_ts, tech_serv_date) >= 20;
        
        -- return cars from tech serving
        
        update cars
        set state_id = 1
        where state_id = 3 and curr_ts > (tech_serv_date + 1);

        rc_pass := randClient;

        order_data := null;

        begin
            select * into order_data
            from orders
            where orders.client_pass = rc_pass
            fetch next 1 rows only;
            exception
                when no_data_found then
                    order_data := null; -- zati4ka for exception, exception is ok
        end;

        if sql%found then   -- if no exception
        -- client has an order so we do something with it
            declare
                r number(1, 0) := dbms_random.value(1, 3);
                car_data cars%rowtype;
                diff number;
                --ret_money orders.total_price%type;
                old_price cars.price%type;
            begin
                if r = 1 then 
                    -- client returns a car earlier
                    update cars
                        set state_id = 1
                        where reg_num = order_data.car_reg_num;

                    delete from orders
                    where id = order_data.id;
                    
                end if; 
                if r = 2 then
                    -- client renews
                    select price into old_price
                        from cars
                        where reg_num = order_data.car_reg_num;

                    update orders 
                        set total_price = order_data.total_price + old_price, -- for simplicity the client renews a car for a day
                            returned_at = returned_at + 1
                        where id = order_data.id;
                end if;
                if r = 3 then 
                    --dbms_output.put_line('client ask for another car');
                    -- client ask for another car
                    car_data := randCar;
                    if sql%found then
                        diff := ts_diff(order_data.returned_at, curr_ts);

                        select price into old_price
                        from cars
                        where reg_num = order_data.car_reg_num;

                        order_data.total_price := order_data.total_price - (diff * old_price) + (diff * car_data.price);

                        update cars
                        set state_id = 1
                        where reg_num = order_data.car_reg_num;

                        update orders 
                        set total_price = order_data.total_price,
                            car_reg_num = car_data.reg_num
                        where id = order_data.id;

                        update cars
                        set state_id = 2
                        where reg_num = car_data.reg_num;
                    end if;
                end if;                    
            end;

        else    -- if was an exception cause sql%notfound
            -- in this case a client does not have an active order, so create one            
            declare
                car_data cars%rowtype;
                temp_ts timestamp;
                r number;
            begin
                car_data := randCar;
                if sql%found then
                    r := dbms_random.value(1, 7);
                    temp_ts := curr_ts + r;
                    insert into orders 
                    values(seq_orders.nextval, rc_pass, 
                        car_data.reg_num, curr_ts, 
                        temp_ts,
                        r * car_data.price);

                    update cars
                    set state_id = 2
                    where reg_num = car_data.reg_num;
                end if;
            end;
        end if;

        exit when curr_ts >= end_ts;
    end loop;
end;
/

-- test data generating
/*
truncate table orders;
truncate table orders_history;
truncate table cars;
truncate table clients;
truncate table carstates;

exec initCarStates;
exec randCars(25, systimestamp - 50);
exec randCars(25, systimestamp - 40);
exec randCars(50, systimestamp - 30);
exec randClients(80);
exec randOrders(30);
*/

--=============================
--  CRUD
--=============================

create or replace package pcrud as
    -- cars
        procedure add_car(reg_num cars.reg_num%type, 
            color cars.color%type, 
            mark cars.mark%type, 
            type cars.type%type, 
            price cars.price%type);
        procedure list_cars;
        procedure update_car(reg_num cars.reg_num%type, 
            state_id cars.state_id%type default 1,
            color cars.color%type default null, 
            mark cars.mark%type default null, 
            type cars.type%type default null, 
            price cars.price%type default null,
            tech_serv_date cars.tech_serv_date%type default null);
        procedure del_car(reg_num cars.reg_num%type);
        
    -- clients
        procedure add_client(passport clients.pass%type, name clients.name%type);
        procedure list_clients;
        procedure update_client(passport clients.pass%type, name clients.name%type);
        procedure del_client(passport clients.pass%type);
        
    -- orders
        procedure add_order(client_pass orders.client_pass%type,
            car_reg_num orders.car_reg_num%type,
            returned_at orders.returned_at%type);
        procedure list_orders;
        procedure update_order(id orders.id%type,
            car_reg_num orders.car_reg_num%type default null,
            rented_at orders.rented_at%type default null,
            returned_at orders.returned_at%type default null);
        procedure del_order(id orders.id%type);
end pcrud;
/

create or replace package body pcrud as
    -- cars
        -- add car with parameters
        procedure add_car(reg_num cars.reg_num%type, 
            color cars.color%type, 
            mark cars.mark%type, 
            type cars.type%type, 
            price cars.price%type) as
        begin
            insert into cars
            values(reg_num,
                1,
                color,
                mark,
                type,
                price,
                sysdate);
        exception
            when others then
                dbms_output.put_line('err: pcrud.add_car');
        end;
        -- list of cars
        procedure list_cars as
        cursor c_cars is
            select * from cars;
        car cars%rowtype;
        begin
            open c_cars; 
            loop 
                fetch c_cars into car; 
                exit when c_cars%notfound; 
                dbms_output.put_line('[' || state_name(car.state_id) || ']' || car.reg_num || ': ' ||  car.color || ', ' || car.mark || ', ' || car.type || ' - �' || car.price); 
            end loop; 
            close c_cars;
        exception
            when others then
                dbms_output.put_line('err: pcrud.list_cars');
        end;
        -- update the car. null means the same value.
        procedure update_car(reg_num cars.reg_num%type, 
            state_id cars.state_id%type default 1,
            color cars.color%type default null, 
            mark cars.mark%type default null, 
            type cars.type%type default null, 
            price cars.price%type default null,
            tech_serv_date cars.tech_serv_date%type default null) as
        car cars%rowtype;
        begin
            select * into car 
            from cars
            where cars.reg_num = update_car.reg_num;
            
            update cars
            set state_id = coalesce(update_car.state_id, car.state_id),
                color = coalesce(update_car.color, car.color),
                type = coalesce(update_car.type, car.type),
                mark = coalesce(update_car.mark, car.mark),
                price = coalesce(update_car.price, car.price),
                tech_serv_date = coalesce(update_car.tech_serv_date, car.tech_serv_date)
            where cars.reg_num = update_car.reg_num;
            
        exception
            when others then
                dbms_output.put_line('err: pcrud.update_car');
        end;
        -- try to delete the car. if a client is using the car, we got an exception.
        procedure del_car(reg_num cars.reg_num%type) as
            state_id cars.state_id%type;
            e_busy_car exception;
        begin
            select state_id into state_id 
            from cars where reg_num = del_car.reg_num;
            
            if state_id = 2 then
                raise e_busy_car;
            end if;
            delete from cars
            where cars.reg_num = del_car.reg_num;
        exception
            when e_busy_car then
                dbms_output.put_line('err: pcrud.del_car: the car is used by a client.');
            when others then
                dbms_output.put_line('err: pcrud.del_car');
        end;
        
    -- clients
        -- add a client
        procedure add_client(passport clients.pass%type, name clients.name%type) as
        begin
            insert into clients
                values(passport,
                    name);
        exception
            when others then
                dbms_output.put_line('err: pcrud.add_client');
        end;
        -- list of clients
        procedure list_clients as
        cursor c_client is
            select * from clients;
        client clients%rowtype;
        begin
            open c_client; 
            loop 
                fetch c_client into client; 
                exit when c_client%notfound; 
                dbms_output.put_line(client.pass || ': ' || client.name); 
            end loop; 
            close c_client;
        exception
            when others then
                dbms_output.put_line('err: pcrud.list_clients');
        end;
        -- update the client, null means the same value
        procedure update_client(passport clients.pass%type, name clients.name%type) as
        client clients%rowtype;
        begin
            select * into client 
            from clients
            where clients.pass = update_client.passport;

            update clients
            set name = coalesce(update_client.name, client.name)
            where clients.pass = update_client.passport;

        exception
            when others then
                dbms_output.put_line('err: pcrud.update_client');
        end;
        --
        procedure del_client(passport clients.pass%type) as
        begin

        delete from clients
            where clients.pass = del_client.passport;

        exception
            when others then
                dbms_output.put_line('err: pcrud.del_client');
        end;        
        
    -- orders
        -- add an order
        procedure add_order(client_pass orders.client_pass%type,
            car_reg_num orders.car_reg_num%type,
            returned_at orders.returned_at%type) as
        car_price orders.total_price%type;
        diff number;
        begin
            select price into car_price
            from cars
            where car_reg_num = cars.reg_num;
            
            diff := ts_diff(returned_at, systimestamp);
            
            insert into orders
            values(seq_orders.nextval,
                client_pass,
                car_reg_num,
                systimestamp,
                returned_at,
                car_price * diff);

        exception
            when others then
                dbms_output.put_line('err: pcrud.add_order');
        end;
        -- list of open orders
        procedure list_orders as
        cursor c_orders is
            select * from orders
            order by id;
        ord orders%rowtype;
        begin
            open c_orders; 
            loop 
                fetch c_orders into ord; 
                exit when c_orders%notfound; 
                dbms_output.put_line('[' || ord.id || '], (' || ord.client_pass || ':' ||  ord.car_reg_num || '), (' || ord.rented_at || ' - ' || ord.returned_at || ') - �' || ord.total_price); 
            end loop; 
            close c_orders;
        exception
            when others then
                dbms_output.put_line('err: pcrud.list_orders');
        end;
        -- update the order, null means the same value
        procedure update_order(id orders.id%type,
            car_reg_num orders.car_reg_num%type default null,
            rented_at orders.rented_at%type default null,
            returned_at orders.returned_at%type default null) as
        ord orders%rowtype;
        oldprice cars.price%type;
        newprice cars.price%type;
        diff1 number;
        diff2 number;
        begin
            select * into ord 
            from orders
            where orders.id = update_order.id;
            
            if returned_at is not null and update_order.returned_at < systimestamp then
                raise VALUE_ERROR;
            end if;
            
            select price into oldprice
            from cars
            where reg_num = ord.car_reg_num;
            
            if car_reg_num is not null then
                select price into newprice
                from cars
                where reg_num = update_order.car_reg_num;
            else
                newprice := oldprice;
            end if;
            
            diff1 := ts_diff(ord.returned_at, systimestamp);
            diff2 := ts_diff(coalesce(update_order.returned_at, ord.returned_at), ord.returned_at);
            
            update orders
            set 
                car_reg_num = coalesce(update_order.car_reg_num, ord.car_reg_num),
                rented_at = coalesce(update_order.rented_at, ord.rented_at),
                returned_at = coalesce(update_order.returned_at, ord.returned_at),
                total_price = total_price + diff1 * (newprice - oldprice) + diff2 * newprice
            where update_order.id = orders.id;

        exception
            when others then
                dbms_output.put_line('err: pcrud.update_order');
            
        end;
        -- delete the order from open orders
        procedure del_order(id orders.id%type) as
        begin
        delete from orders
            where orders.id = del_order.id;

        exception
            when others then
                dbms_output.put_line('err: pcrud.del_order');
        end;
        --
end pcrud;
/

/*
exec pcrud.add_car('AAAAA55555', 'red', 'bently', 'supercar', 8000);
exec pcrud.update_car('AAAAA55555', color => 'mixed');
exec pcrud.list_cars;

exec pcrud.add_client('9999944444', 'steven');
exec pcrud.update_client('9999944444', 'stephen');
exec pcrud.list_clients;

exec pcrud.add_order('9999944444', 'AAAAA55555', systimestamp + 1);
exec pcrud.list_orders;
exec pcrud.update_order(3616, returned_at => systimestamp + 3);
exec pcrud.del_order(3616);

exec pcrud.del_car('AAAAA55555');
exec pcrud.del_client('9999944444');
*/

--=============================
--  save history of orders changing
--=============================

    -- script task_c.sql

--=============================
--  report about history of orders changing
--=============================

create or replace view orders_changes as
select order_id, 
        count(*) as "changed _ times",
        count(distinct car_reg_num) as "used _ cars",
        ts_diff(max(returned_at), min(returned_at)) as "renews on", -- additional time by renewing
        case
            when max(status) = '1' then 'closed'    -- client returned a car
            when max(status) = '0' then 'open'      -- client is using a car, order is open
        end as status
    from orders_history
    group by order_id;
/

--select * from orders_changes;

create or replace procedure orders_changes_report as
    total_orders int;
    open_orders int;
    avg_changes number(10, 2);
    avg_cars number(10, 2);
    avg_renew number(10, 2);
    min_price number(10, 2);
    avg_price number(10, 2);
    max_price number(10, 2);
begin

    select count(distinct orders_history.order_id) into total_orders
    from orders_history;
    
    select count(*) into open_orders
    from orders;

    total_orders := total_orders + open_orders;

    select avg("changed _ times"), 
        avg("used _ cars")
    into avg_changes, 
        avg_cars
    from orders_changes;

    select avg("renews on") into avg_renew
    from orders_changes
    where "renews on" > 0;

    select min(total_price), 
        avg(total_price), 
        max(total_price) 
    into
        min_price,
        avg_price,
        max_price  
    from orders_history
    where status = '1';

    dbms_output.put_line('Total orders: ' || total_orders);
    dbms_output.put_line('Open orders: ' || open_orders);
    dbms_output.put_line('Avg changing of order: ' || avg_changes);
    dbms_output.put_line('Avg number of usage cars: ' || avg_cars);
    dbms_output.put_line('Avg renew time (in days): ' || avg_renew);
    dbms_output.put_line('Revenue by order(min, avg, max): ' || min_price || ' ' || avg_price || ' ' || max_price);

exception
    when others then
        dbms_output.put_line('err: orders_changes_report');
end;
/

--exec orders_changes_report;

--=============================
--  saving history of rented cars
--=============================
    
    -- script task_e.sql

--=============================
--  report about history of rented cars
--=============================

create or replace view cars_rents as
    select distinct car_reg_num, 
        order_id, 
        client_pass,
        min(rented_at) over (partition by order_id, client_pass, car_reg_num) as rented_at,
        max(returned_at) over (partition by order_id, client_pass, car_reg_num) as returned_at,
        ts_diff(max(returned_at) over (partition by order_id, client_pass, car_reg_num),
            min(rented_at) over (partition by order_id, client_pass, car_reg_num)) as rented_time,
        ts_diff(max(returned_at) over (partition by order_id, client_pass, car_reg_num),
            min(rented_at) over (partition by order_id, client_pass, car_reg_num)) * cars.price as revenue
    from orders_history oh
    join cars on cars.reg_num = oh.car_reg_num 
    order by order_id;
/

-- select * from cars_rents;

create or replace procedure cars_report as
    cursor c1 is 
        select reg_num, temp.orders_num, temp.clients_num, temp.total_revenue, temp.total_rented_time, tech_serv_date
        from cars
        join (select car_reg_num,
                count(distinct order_id) as orders_num,
                count(distinct client_pass) as clients_num,
                sum(revenue) as total_revenue,
                sum(rented_time) as total_rented_time            
            from cars_rents
            group by car_reg_num) temp
        on (temp.car_reg_num = cars.reg_num);
        
    reg_num cars.reg_num%type;
    orders_num int;
    clients_num int;
    total_revenue number(10, 2);
    total_rented_time number(10, 2);
    tsdate cars.tech_serv_date%type;
begin
    open c1;
    loop
        fetch c1 into reg_num, 
            orders_num, 
            clients_num, 
            total_revenue, 
            total_rented_time,
            tsdate;
        exit when c1%notfound;
        dbms_output.put_line('Reg num ' || reg_num || ': ' || 
            orders_num || ' orders, ' ||
            clients_num || ' clients, revenue ' ||
            total_revenue || ' P, ' ||
            total_rented_time || ' days in rent, ' || 
            round(ts_diff(systimestamp, tsdate), 2) || ' from last serving');
    end loop;
    close c1;
end;
/

--exec cars_report;

--=============================
--  finance report by period
--=============================

create or replace procedure fin_report(start_ts IN timestamp, end_ts IN timestamp) as
    revenue number(10, 2);
begin
    select sum(total_price) into revenue 
    from orders_history
    where status = '1' and returned_at between start_ts and end_ts;

    dbms_output.put_line('����� �� ' || substr(start_ts, 1, 17) || ' - ' || substr(end_ts, 1, 17) || ': ' || revenue || '�');
end;
/

--exec fin_report(systimestamp - 10, systimestamp);

--=============================
--  report about clients
--=============================

create or replace procedure client_report as
    car_list varchar2(200);
    pass clients.pass%type;
    revenue number(10, 2);

    cursor c1 is
        select listagg(distinct oh.car_reg_num, ', '), 
            oh.client_pass, 
            sum(t1.total_price)
        from orders_history oh
        join (
            select client_pass, total_price
            from orders_history
            where status = '1'
        ) t1 on t1.client_pass = oh.client_pass
        group by oh.client_pass;
begin
    open c1;
    loop
        fetch c1 into car_list, pass, revenue;
        exit when c1%notfound;
        dbms_output.put_line('������: ' || pass || ', ������: ' || car_list);
        dbms_output.put_line('  �������: ' || revenue);
    end loop;
    close c1;
end;
/

--exec client_report;

--=============================
--  report about current autopark
--=============================

create or replace procedure autopark_status as
    cursor c1 is
        select state_id, count(*) as num
        from cars
        group by cars.state_id;
    car_state_id cars.state_id%type;
    car_number int;
begin
    open c1;
    loop 
        fetch c1 into car_state_id, car_number; 
        exit when c1%notfound;
        dbms_output.put_line('[' || state_name(car_state_id) || '] ' || car_number); 
    end loop; 
    close c1;
end;
/

--exec autopark_status;

--=============================
--  searching a car by parameters
--=============================

-- find car by color, type, mark and state.
create or replace procedure findCar(
        color IN varchar2 default null, 
        type IN varchar2 default null,
        mark in varchar2 default null,
        state_id IN int default 1) as

    c_car cars%rowtype;
    cursor c_cars is
        select *
        from cars
        where cars.state_id = coalesce(findCar.state_id, cars.state_id) and
            cars.color = coalesce(findCar.color, cars.color) and
            cars.type = coalesce(findCar.type, cars.type) and
            cars.mark = coalesce(findCar.mark, cars.mark);
begin
    open c_cars;
    loop
        fetch c_cars into c_car;
        exit when c_cars%notfound;
        dbms_output.put_line('[' || state_name(c_car.state_id) || ']' || 
                        c_car.reg_num || ': ' || 
                        c_car.color || ', ' || 
                        c_car.type || ', ' || 
                        c_car.mark || ' - ' || 
                        c_car.price || '�');
    end loop;
    close c_cars;
end;
/

--exec findCar(type => 'sedan');

--=============================