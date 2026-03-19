# 🌐 WEB SERVER MANAGER — `webm`

Автоматическая настройка VPS: Nginx, SSL, UFW, Fail2ban, SSI-конфиг.  
При создании сайта `index.html` и `config.js` скачиваются с GitHub автоматически.

---

## ⚡ Установка — одна команда

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ChernOvOne/PRTG/main/webserver-setup.sh)
```

После установки — управление сервером:

```bash
sudo webm
```

---

## 📋 Меню

| # | Действие |
|---|---------|
| `1` | Полная установка (Nginx + SSL + UFW + Fail2ban + скачать файлы с GitHub) |
| `2` | Переустановить команду `webm` |
| `3` | **Создать новый сайт** |
| `4` | Список сайтов |
| `5` | Удалить сайт |
| `6` | Выпустить SSL для домена |
| `7` | Обновить SSL вручную |
| `8` | Статус сервера (CPU / RAM / диск / аптайм / SSL) |
| `9` | Запустить все сервисы |
| `10` | Остановить все сервисы |
| `11` | Перезапустить все сервисы |
| `12` | Управление Nginx (старт / стоп / reload / проверка конфига) |
| `13` | Логи (Nginx access, error, Fail2ban, webm, live) |
| `14` | Отчёт безопасности (баны, SSH-входы, порты, SSL) |

---

## 🌍 Создание сайта

```
sudo webm → 3) Создать новый сайт
```

Скрипт спросит:
- **Домен** — `example.com`
- **Ссылка на бота** — `https://t.me/MyVPN_bot`
- **Ссылка на поддержку** — `https://t.me/MySupport`

Затем автоматически:
1. Скачивает `index.html` с GitHub → `/var/www/ДОМЕН/html/`
2. Скачивает `config.js` с GitHub, подставляет введённые ссылки → `/etc/nginx/private/ДОМЕН/config.js`
3. Настраивает Nginx с SSI (прямой доступ к `config.js` из браузера заблокирован)
4. Предлагает выпустить SSL

---

## 🔒 config.js

Хранится только на сервере. Браузер не может его запросить — Nginx вставляет содержимое в HTML через SSI.

**Редактировать:**
```bash
nano /etc/nginx/private/ДОМЕН/config.js
```

**Загрузить с компьютера:**
```bash
scp config.js root@IP:/etc/nginx/private/ДОМЕН/config.js
```

После правок перезагружать Nginx **не нужно**.

---

## 📁 Структура файлов на сервере

```
/usr/local/bin/webm                      ← команда webm
/var/log/webm.log                        ← лог всех действий

/var/www/ДОМЕН/html/index.html           ← страница сайта
/etc/nginx/sites-available/ДОМЕН        ← конфиг Nginx
/etc/nginx/private/ДОМЕН/config.js      ← приватный конфиг (прокси, пароли)

/var/www/_github_cache/                  ← кэш файлов с GitHub
```

---

## 🔄 Обновление

**index.html на сайте:**
```bash
scp index.html root@IP:/var/www/ДОМЕН/html/index.html
```

**Скрипт webm:**
```bash
curl -fsSL https://raw.githubusercontent.com/ChernOvOne/PRTG/main/webserver-setup.sh \
  -o /usr/local/bin/webm && chmod +x /usr/local/bin/webm
```

---

## ⚙️ Прямые команды

```bash
sudo webm --status      # статус сервера
sudo webm --restart     # перезапустить сервисы
sudo webm --renew-ssl   # обновить SSL
sudo webm --install     # полная установка
sudo webm --help        # справка
```
