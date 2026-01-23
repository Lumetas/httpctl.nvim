# its my fork of [resty.nvim](https://github.com/lima1909/resty.nvim)

# Headers, URL and body

```
POST https://jsonplaceholder.org/posts
Authorization: Bearer token

{
  "title": "foo",
  "body": "bar",
  "userId": 1
}
```

### Variables

```
@host = jsonplaceholder.org

POST https://{{host}}/posts
Authorization: Bearer token

{
  "title": "foo",
  "body": "bar",
  "userId": 1
}
```

### post scripts

```
@host = jsonplaceholder.org
@token = token

POST https://{{host}}/auth

{
    "login" : "admin",
    "password" : "password"
}

> {%
    api.set('token', json_body().token)
%}
```

### pre scripts

```
POST https://{{host}}/posts
Authorization: Bearer {{token}}

{
  "title": "%title%",
  "body": "%body%",
  "userId": %userId%
}

> {%
    api.set_dynamic('title', 'foo')
    api.set_dynamic('body', 'bar')
    api.set_dynamic('userId', 1)
%}
```


## Install

via your favorite plugin manager

- [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'lumetas/ht.nvim',
    config = function()
        require('ht').setup(
            auto_focus_response = false -- auto focus response window
        )
    end
}
```


## API

### Pre-request скрипты
Используются для модификации запроса перед его выполнением.

| Метод | Описание | Пример |
|-------|----------|--------|
| `api.request` | Доступ к объекту запроса (только чтение) | `local url = api.request.url` |
| `api.set_dynamic(key, value)` | Установить динамическую переменную, которая будет подставлена в запрос | `api.set_dynamic("token", "abc123")` |
| `api.get(key)` | Получить значение глобальной переменной | `local baseUrl = api.get("base_url")` |
| `api.modify_request(modifications)` | Модифицировать параметры запроса | `api.modify_request({url = "https://api.com/v2"})` |
| `api.exec(cmd)` | Выполнить системную команду и вернуть результат | `local date = api.exec("date")` |

### Post-request скрипты
Используются для обработки ответа от сервера.

| Метод | Описание | Пример |
|-------|----------|--------|
| `api.result` | Объект с результатом запроса (body, status, headers) | `local status = api.result.status` |
| `api.response` | Псевдоним для `api.result` | `local body = api.response.body` |
| `api.request` | Объект с оригинальным запросом | `local method = api.request.method` |
| `api.set(key, value)` | Установить глобальную переменную для будущих запросов | `api.set("auth_token", token)` |
| `api.get(key)` | Получить значение глобальной переменной | `local token = api.get("auth_token")` |
| `api.json_body()` | Распарсить тело ответа как JSON | `local data = api.json_body()` |
| `api.jq_body(filter)` | Применить jq-фильтр к телу ответа | `local ids = api.jq_body(".items[].id")` |
| `api.output.write(text)` | Записать текст в вывод (очистив предыдущий) | `api.output.write("Success!")` |
| `api.output.clear()` | Очистить вывод | `api.output.clear()` |
| `api.output.append(text)` | Добавить текст в вывод | `api.output.append("More info")` |
| `api.send(name)` | Отправить запрос в избранное с указанным именем | `api.send("my_favorite")` |
