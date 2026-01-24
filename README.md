## Заголовки, URL и тело запроса

```
POST https://jsonplaceholder.org/posts
Authorization: Bearer token

{
  "title": "foo",
  "body": "bar",
  "userId": 1
}
```

## file
```
POST https://jsonplaceholder.org/posts
Authorization: Bearer token

<path/to/file.txt

```

## Variables

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

## post scripts

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

## pre scripts

```
POST https://{{host}}/posts
Authorization: Bearer {{token}}

{
  "title": "%title%",
  "body": "%body%",
  "userId": %userId%
}

> {%
    --pre
    api.set_dynamic('title', 'foo')
    api.set_dynamic('body', 'bar')
    api.set_dynamic('userId', 1)
    
    --post
    -- это пост скрипт
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
            output = {
                move_to_win = true,
                body_pretty_print = false,
            },
            response = {
                with_folding = true,
                bufname = "ht_response",
                output_window_split = "right", -- Split direction: "left", "right", "above", "below".
                auto_focus_response = true,
            },
            highlight = {
                hint_replace = "LightYellow",
            }
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
| `api.set_dynamic(key, value)` | Установить динамическую переменную, которая будет подставлена в запрос, %varName% | `api.set_dynamic("token", "abc123")` |
| `api.get(key)` | Получить значение глобальной переменной | `local baseUrl = api.get("base_url")` |
| `api.modify_request(modifications)` | Модифицировать параметры запроса | `api.modify_request({url = "https://api.com/v2"})` |

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
| `api.send(name)` | Отправить другай запрос из избранного | `api.send("my_favorite")` |

### Команды

| Команда | Описание | Пример |
|-------|----------|--------|
| `:HT run` | Выполнить запрос | `:HT run` |
| `:HT favorite` | Открыть меню избранных запросов | `:HT favorite` |
| `:HT favorite <favoriteName>` | Выполнить запрос из избранного | `:HT favorite favorite` |
| `:HT last` | Выполнить последний запрос | `:HT last` |


## Изюранное
```
### #favoreiteRequest
GET https://jsonplaceholder.org/posts
Authorization: Bearer token

{
  "title": "foo",
  "body": "bar",
  "userId": 1
}
```
Открыть меню избранных запросов: `:HT favorite`

Выполнить запрос из меню избранных: `:HT run <favoriteName>`

## Пример

```
@host = https://jsonplaceholder.org

### #posts
GET {{host}}/posts

> {%
	data = api.json_body()
	api.set('updateId', data[1]['id'])
	api.send('editPostTitle')

%}

### #editPostTitle
PUT {{host}}/posts/{{updateId}}

{
	"title" : "%title%"
}

> {%
	--pre
	api.set_dynamic('title', vim.fn.input('Enter a new title: '))
	
	--post
	print(api.json_body().title)
%}
```
