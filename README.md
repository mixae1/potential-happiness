# Сервис сдачи автомобилей в аренду
## db

В бд 3 основные сущности: клиенты, автомобили, заказы.
Для каждой создана отдельная таблица (Clients, Cars, Orders). 
Для указания состояния автомобиля используется маленькая таблица CarStates.
Для хранения истории изменений заказов используется таблица orders_history.

Таблица клиентов содержит 2 поля - 
  pass(номер пасспорта) и 
  name(имя клиента).
Таблица автомобилей содержит 7 полей -
  reg_num(номер автомобиля),
  state_id(номер состояния, состояние в таблице CarStates),
  color,
  mark,
  type(параметры автомобиля),
  price(цена аренды автомобиля за сутки),
  tech_serv_date(дата последнего ТО)
Таблица заказов содержит 6 полей -
  id,
  client_pass,
  car_reg_num,
  rented_at(время начала аренды),
  returned_at(время окончания аренды),
  total_price(вычисленная стоимость аренды)

В таблице заказов содержатся только открытые заказы (клиент ещё не вернул автомобиль).
Клиент может продлить время заказа, тогда в таблице заказов изменятся поля returned_at и total_price.
Клиент может поменять машину, тогда в таблице заказов изменятся поля car_reg_num и total_price.
total_price в этом случае будет вычеслен следующим образом: total_price += оставшееся время в днях * (new_car_price - old_car_price)
Также клиент может закрыть заказ, вернув машину преждевременно. total_price при этом не изменится. Заказ будет удален из открытых заказов.

(Также есть возможность изменить rented_at в случае ошибки при создании заказа)

Создание, любое исправление заказа, а также его удаление, будут внесены в таблицу orders_history.
Таблица orders_history содержит дополнительные поля - 
  order_id(указание на номер заказа),
  changed_at(время изменения),
  status(статус заказа: '0': заказ открыт, '1': заказ закрыт),
  note('сопровождение изменения поясняющим текстом'),
  v_user(user, выполнивший изменение)

При создании заказ будет продублирован в orders_history.
При изменении в orders_history будет продублировано новое состояние заказа.
При удалении сохранится последнее состояние заказа.

При каждом добавлении записи в orders_history будет сохраняться время и текущий статус заказа. Обычно это статус '0'. При удалении используется статус '1'.

Индексация автоматически создается oracle для unique полей. Дополнительно создана индексация для полей client_pass, car_reg_num & status в таблице orders_history. Также, так как это таблица логирования и никакие записи в ней не будут изменены, для этой таблицы параметр pctfree = 2(для экономии места на дисковом пространстве).

Изменение orders_history происходит через тригеры.

Созданы скрипты для наполнения БД тестовыми данными.

```sql
exec initCarStates;
exec randCars(25, systimestamp - 50);
exec randCars(25, systimestamp - 40);
exec randCars(50, systimestamp - 30);
exec randClients(80);
exec randOrders(30);
```

Созданы CRUD операции для основных сущностей. 
```sql
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
```


Для отчетов созданые процедуры.
c.	сохранение истории изменения заказов.
  ```sql
script task_c.sql
  ```
d.	отчет об истории изменения заказов.
  ```sql
exec orders_changes_report;
  ```
e.	сохранение истории сдачи в аренду авто.
  ```sql
script task_e.sql
  ```
f.	отчет об истории сдачи в аренду авто.
  ```sql
exec cars_report;
  ```
g.	отчет о финансовой деятельности сервиса за период (для простоты будем считать, что стоимость сдачи в аренду на сутки одного автомобиля константна).
  ```sql
exec fin_report(systimestamp - 10, systimestamp);
  ```
h.	Отчет о клиентах: когда какие авто брал в аренду, сколько заплатил и т.д.
  ```sql
exec autopark_status;
  ```
i.	Отчет о текущем состоянии автопарка: сколько в аренде, сколько свободны, сколько на ТО и т.д.
  ```sql
--exec findCar(type => 'sedan');
  ```

![db](https://github.com/mixae1/potential-happiness/assets/56720762/f3e624b3-0e58-4774-b827-5cfa67b9aecb)

## virual box

https://drive.google.com/file/d/1QsvjHYPnVGK3N0j7AEkUt2-0dAoaigOl/view?usp=sharing
