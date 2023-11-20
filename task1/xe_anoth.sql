set serveroutput on
--=============================
--  Tables
--=============================

CREATE TABLE CARS(
    reg_num char(10) primary key,
    state varchar2(20) not null,
    color varchar2(20) not null,
    mark varchar2(20) not null,
    type varchar2(20) not null,
    price number(10, 2) not null
    -- tech_serv_date  date -- не реализовывал, так как применения кроме как временной недоступности не увидел
);

CREATE TABLE CLIENTS(
    pass char(10) primary key,
    name varchar2(40) not null
);

create table orders(
    id integer primary key,
    client_pass char(10) not null,
    car_reg_num char(10) not null,
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
    status char not null, -- '0' машина у клиента, '1' - клиент вернул машину
    total_price number(10, 2) not null,
    
    note varchar2(100),
    v_user varchar2(10) not null
    
    -- так как я удаляю order и заношу их в orders_history
    --foreign key (order_id) references orders(id),
    --foreign key (car_reg_num) references cars(reg_num)
);

create SEQUENCE seq_orders_history
    minvalue 1
    increment by 1
    cache 10;

--=============================
--  наполнение БД
--=============================

-- create cars
create or replace procedure randCars(num IN int) as
    type CarStatesArray is varray(3) of varchar2(20);
    carStates CarStatesArray := CarStatesArray('waiting', 'rented', 'maintenance');
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
            carStates(1), --dbms_random.value(1, 3)
            carColors(dbms_random.value(1, 10)),
            carMarks(dbms_random.value(1, 10)),
            carTypes(dbms_random.value(1, 10)),
            dbms_random.value(800, 3000));
            
    end loop;
exception 
    when others then
        dbms_output.put_line('err: randCars');
end;


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
        SYSTIMESTAMP, -- при генерации данных у всех полей будет одно и тоже время+-, однако в реальных условиях всё будет верно
        :new.client_pass,
        :new.car_reg_num,
        :new.rented_at,
        :new.returned_at,
        '0',
        :new.total_price,
        note,
        v_username);
end;

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
        SYSTIMESTAMP, -- при генерации данных у всех полей будет одно и тоже время+-, однако в реальных условиях всё будет верно
        :old.client_pass,
        :old.car_reg_num,
        :old.rented_at,
        :old.returned_at,
        '1',
        :old.total_price,
        'client returned a car.',
        v_username);
end;

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
        where state = 'waiting'
        order by dbms_random.random()
        fetch next 1 rows only;
        return car_data;
    exception
        when no_data_found then
            return car_data;
    end randCar;

    function ts_diff(a timestamp, b timestamp) return number is 
    begin
      return (extract (day    from (a-b))) +
             (extract (hour   from (a-b)) / 24) +
             (extract (minute from (a-b)) / (24*60)) +
             (extract (second from (a-b)) / (24*60*60));
    end;
begin
    curr_ts := start_ts;
    loop
        -- close all orders, where curr_timestamp > order.returned_at
        update cars
            set state = 'waiting'
            where reg_num = any(
                select car_reg_num
                from orders
                where returned_at <= curr_ts);
        
        /*
        update orders
            set status = '1'
            where status = '0' and returned_at <= curr_ts;
        */

        delete from orders
        where returned_at <= curr_ts;

        curr_ts := curr_ts + dbms_random.value(min_interval, max_interval);

        rc_pass := randClient;

        order_data := null;

        begin
            select * into order_data
            from orders
            where orders.client_pass = rc_pass
            fetch next 1 rows only;
            exception
                when no_data_found then
                    order_data := null; -- пустышка
        end;

        if sql%found then
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
                        set state = 'waiting'
                        where reg_num = order_data.car_reg_num;

                    /*
                    update orders 
                        set total_price = order_data.total_price -- ? decrease?
                        where id = order_data.id;
                    */
                    
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
                        --dbms_output.put_line('diff: ' || diff);

                        select price into old_price
                        from cars
                        where reg_num = order_data.car_reg_num;

                        order_data.total_price := order_data.total_price - (diff * old_price) + (diff * car_data.price);

                        update cars
                        set state = 'waiting'
                        where reg_num = order_data.car_reg_num;

                        update orders 
                        set total_price = order_data.total_price,
                            car_reg_num = car_data.reg_num
                        where id = order_data.id;

                        update cars
                        set state = 'rented'
                        where reg_num = car_data.reg_num;
                    end if;
                end if;                    
            end;

        else
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
                    set state = 'rented'
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

exec randCars(100);
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
            state cars.state%type default 'waiting',
            color cars.color%type default null, 
            mark cars.mark%type default null, 
            type cars.type%type default null, 
            price cars.price%type default null);
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
    function ts_diff(a timestamp, b timestamp) return number is 
    begin
      return (extract (day    from (a-b))) +
             (extract (hour   from (a-b)) / 24) +
             (extract (minute from (a-b)) / (24*60)) +
             (extract (second from (a-b)) / (24*60*60));
    end;

    -- cars
        --
        procedure add_car(reg_num cars.reg_num%type, 
            color cars.color%type, 
            mark cars.mark%type, 
            type cars.type%type, 
            price cars.price%type) as
        begin
            insert into cars
            values(reg_num,
                'waiting',
                color,
                mark,
                type,
                price);
        exception
            when others then
                dbms_output.put_line('err: pcrud.add_car');
        end;
        --
        procedure list_cars as
        cursor c_cars is
            select * from cars;
        car cars%rowtype;
        begin
            open c_cars; 
            loop 
                fetch c_cars into car; 
                exit when c_cars%notfound; 
                dbms_output.put_line('[' || car.state || ']' || car.reg_num || ': ' ||  car.color || ', ' || car.mark || ', ' || car.type || ' - Р' || car.price); 
            end loop; 
            close c_cars;
        exception
            when others then
                dbms_output.put_line('err: pcrud.list_cars');
        end;
        --
        procedure update_car(reg_num cars.reg_num%type, 
            state cars.state%type default 'waiting',
            color cars.color%type default null, 
            mark cars.mark%type default null, 
            type cars.type%type default null, 
            price cars.price%type default null) as
        car cars%rowtype;
        begin
            select * into car 
            from cars
            where cars.reg_num = update_car.reg_num;
            
            update cars
            set state = coalesce(update_car.state, car.state),
                color = coalesce(update_car.color, car.color),
                type = coalesce(update_car.type, car.type),
                mark = coalesce(update_car.mark, car.mark),
                price = coalesce(update_car.price, car.price)
            where cars.reg_num = update_car.reg_num;
            
        exception
            when others then
                dbms_output.put_line('err: pcrud.update_car');
        end;
        --
        procedure del_car(reg_num cars.reg_num%type) as
        begin
            delete from cars
            where cars.reg_num = del_car.reg_num;
        exception
            when others then
                dbms_output.put_line('err: pcrud.del_car');
        end;
        
    -- clients
        procedure add_client(passport clients.pass%type, name clients.name%type) as
        begin
            insert into clients
                values(passport,
                    name);
        exception
            when others then
                dbms_output.put_line('err: pcrud.add_client');
        end;
        --
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
        --
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
        procedure add_order(client_pass orders.client_pass%type,
            car_reg_num orders.car_reg_num%type,
            returned_at orders.returned_at%type) as
        car_price orders.total_price%type;
        diff number;
        begin
            select price into car_price
            from cars
            where car_reg_num = cars.reg_num;
            
            diff := pcrud.ts_diff(returned_at, systimestamp);
            
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
        --
        procedure list_orders as
        cursor c_orders is
            select * from orders;
        ord orders%rowtype;
        begin
            open c_orders; 
            loop 
                fetch c_orders into ord; 
                exit when c_orders%notfound; 
                dbms_output.put_line('[' || ord.id || '], (' || ord.client_pass || ':' ||  ord.car_reg_num || '), (' || ord.rented_at || ' - ' || ord.returned_at || ') - Р' || ord.total_price); 
            end loop; 
            close c_orders;
        exception
            when others then
                dbms_output.put_line('err: pcrud.list_orders');
        end;
        --
        procedure update_order(id orders.id%type,
            car_reg_num orders.car_reg_num%type default null,
            rented_at orders.rented_at%type default null,
            returned_at orders.returned_at%type default null) as
        ord orders%rowtype;
        oldprice cars.price%type;
        newprice cars.price%type;
        diff number;
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
            
            diff := pcrud.ts_diff(coalesce(update_order.returned_at, ord.returned_at), systimestamp);
            
            update orders
            set 
                car_reg_num = coalesce(update_order.car_reg_num, ord.car_reg_num),
                rented_at = coalesce(update_order.rented_at, ord.rented_at),
                returned_at = coalesce(update_order.returned_at, ord.returned_at),
                total_price = total_price + diff * (newprice - oldprice)
            where update_order.id = orders.id;

        exception
            when others then
                dbms_output.put_line('err: pcrud.update_order');
            
        end;
        --
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
exec pcrud.del_car('AAAAA55555');

exec pcrud.add_client('9999944444', 'Гордый орёл');
exec pcrud.update_client('9999944444', 'Горный бараш');
exec pcrud.list_clients;
exec pcrud.del_client('9999944444');

exec pcrud.add_order('9999944444', 'AAAAA55555', systimestamp + 1);
exec pcrud.list_orders;
exec pcrud.update_order(3335, returned_at => systimestamp + 3);
exec pcrud.del_order(3335);
*/

--=============================
--  сохранение истории изменения заказов.
--=============================

    -- script task_c.sql

--=============================
--  отчет об истории изменения заказов.
--=============================

create or replace function ts_diff(a timestamp, b timestamp) return number is 
    begin
      return (extract (day    from (a-b))) +
             (extract (hour   from (a-b)) / 24) +
             (extract (minute from (a-b)) / (24*60)) +
             (extract (second from (a-b)) / (24*60*60));
    end;
/

-- возвращает таблицу по каждому договору
create or replace view orders_changes as
select order_id, 
        count(*) as "changed _ times",
        count(distinct car_reg_num) as "used _ cars",
        ts_diff(max(returned_at), min(returned_at)) as "renews on", -- в днях
        case
            when max(status) = '1' then 'closed'    -- договор закрыт, машина возвращена
            when max(status) = '0' then 'open'      -- договор открыт, машина у клиента
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

    dbms_output.put_line('Всего заказов: ' || total_orders);
    dbms_output.put_line('Открытых заказов: ' || open_orders);
    dbms_output.put_line('Среднее число изменений договоров: ' || avg_changes);
    dbms_output.put_line('Среднее число используемых машин: ' || avg_cars);
    dbms_output.put_line('Среднее время продления (в днях): ' || avg_renew);
    dbms_output.put_line('Сумма заказа(min, avg, max): ' || min_price || ' ' || avg_price || ' ' || max_price);

exception
    when others then
        dbms_output.put_line('Ошибка при создании отчета.');
end;
/

--exec orders_changes_report;

--=============================
--  сохранение истории сдачи в аренду авто.
--=============================
    
    -- script task_e.sql

--=============================
--  отчет об истории сдачи в аренду авто.
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

--select * from cars_rents;

create or replace procedure cars_report as
    cursor c1 is 
        select car_reg_num,
            count(distinct order_id) as orders_num,
            count(distinct client_pass) as clients_num,
            sum(revenue) as total_revenue,
            sum(rented_time) as total_rented_time
        from cars_rents
        group by car_reg_num;
    reg_num cars.reg_num%type;
    orders_num int;
    clients_num int;
    total_revenue number(10, 2);
    total_rented_time number(10, 2);
begin
    open c1;
    loop
        fetch c1 into reg_num, 
            orders_num, 
            clients_num, 
            total_revenue, 
            total_rented_time;
        exit when c1%notfound;
        dbms_output.put_line('Машина ' || reg_num || ': ' || 
            orders_num || ' заказов, ' ||
            clients_num || ' клиентов, доход' ||
            total_revenue || 'Р, ' ||
            total_rented_time || ' дней в аренде');
    end loop;
    close c1;
end;
/

--exec cars_report;

--=============================
--  отчет о финансовой деятельности сервиса за период (только закрытые заказы в этот период)
--=============================

create or replace procedure fin_report(start_ts IN timestamp, end_ts IN timestamp) as
    revenue number(10, 2);
begin
    select sum(total_price) into revenue 
    from orders_history
    where status = '1' and returned_at between start_ts and end_ts;

    dbms_output.put_line('Итого за ' || substr(start_ts, 1, 17) || ' - ' || substr(end_ts, 1, 17) || ': ' || revenue || 'Р');
end;
/

--exec fin_report(systimestamp - 10, systimestamp);

--=============================
--  отчет о клиентах (без учета открытых заказов)
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
        dbms_output.put_line('Клиент: ' || pass || ', машины: ' || car_list);
        dbms_output.put_line('  Выручка: ' || revenue);
    end loop;
    close c1;
end;
/

--exec client_report;

--=============================
--  отчет о текущем состоянии автопарка
--=============================

create or replace procedure autopark_status as
    cursor c1 is
        select cars.state, count(*) as num
        from cars
        group by cars.state;
    car_state cars.state%type;
    car_number int;
begin
    open c1;
    loop 
        fetch c1 into car_state, car_number; 
        exit when c1%notfound; 
        dbms_output.put_line('[' || car_state || '] ' || car_number); 
    end loop; 
    close c1;
end;
/

--exec autopark_status;

--=============================
--  Подбор(поиск) авто по параметрам
--=============================

-- find car by color, type, mark and state.
create or replace procedure findCar(
        color IN varchar2 default null, 
        type IN varchar2 default null,
        mark in varchar2 default null,
        state IN varchar2 default 'waiting') as

    c_car cars%rowtype;
    cursor c_cars is
        select *
        from cars
        where cars.state = coalesce(findCar.state, cars.state) and
            cars.color = coalesce(findCar.color, cars.color) and
            cars.type = coalesce(findCar.type, cars.type) and
            cars.mark = coalesce(findCar.mark, cars.mark);
begin
    open c_cars;
    loop
        fetch c_cars into c_car;
        exit when c_cars%notfound;
        dbms_output.put_line('[' || c_car.state || ']' || c_car.reg_num || ': ' || 
                        c_car.color || ', ' || 
                        c_car.type || ', ' || 
                        c_car.mark || ' - ' || 
                        c_car.price || 'Р');
    end loop;
    close c_cars;
end;
/

--exec findCar(type => 'sedan');

--=============================