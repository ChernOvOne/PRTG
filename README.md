# 🌐 WEB SERVER MANAGER — `webm`

Автоматическая настройка VPS: Nginx, SSL, UFW, Fail2ban.  
При создании сайта `index.html` и `config.js` скачиваются с GitHub автоматически.

---

## ⚡ Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ChernOvOne/PRTG/main/webserver-setup.sh)
```

После установки:

```bash
sudo webm
```

---

## 📋 Меню

| # | Действие |
|---|---------|
| `1` | Полная установка |
| `2` | Переустановить `webm` |
| `3` | Создать новый сайт |
| `4` | Список сайтов |
| `5` | Удалить сайт |
| `6` | Выпустить SSL |
| `7` | Обновить SSL вручную |
| `8` | Статус сервера |
| `9` | Запустить все сервисы |
| `10` | Остановить все сервисы |
| `11` | Перезапустить все сервисы |
| `12` | Управление Nginx |
| `13` | Логи |
| `14` | Отчёт безопасности |

---

## 🌍 Создание сайта

```
sudo webm → 3) Создать новый сайт
```

Скрипт спросит домен, ссылку на бота и поддержку, затем:
- Скачает `index.html` с GitHub
- Скачает `config.js` с GitHub и подставит введённые ссылки
- Настроит Nginx
- Предложит выпустить SSL

---

## 🔒 config.js

Лежит рядом с `index.html` в `/var/www/ДОМЕН/html/config.js`.

**Редактировать на сервере:**
```bash
nano /var/www/ДОМЕН/html/config.js
```

**Загрузить с компьютера:**
```bash
scp config.js root@IP:/var/www/ДОМЕН/html/config.js
```

### Структура файла

```javascript
const CFG = {

  // Ссылки
  botLink:     "https://t.me/MyVPN_bot",
  supportLink: "https://t.me/MySupport",

  // MTProto прокси — каждый объект = одна карточка на сайте
  mtproto: [
    {
      name: "ПРОКСИ RU-1",
      tag:  "ОСНОВНОЙ",
      addr: "proxy.example.com:443",
      link: "tg://proxy?server=proxy.example.com&port=443&secret=ВАШ_СЕКРЕТ",
      desc: "Основной · Москва"
    },
    {
      name: "ПРОКСИ RU-2",
      tag:  "РЕЗЕРВНЫЙ",
      addr: "proxy2.example.com:443",
      link: "tg://proxy?server=proxy2.example.com&port=443&secret=ВАШ_СЕКРЕТ",
      desc: "Резервный · Москва"
    }
  ],

  // SOCKS5 прокси — login/pass = "" если авторизация не нужна
  socks5: [
    {
      name:  "SOCKS5 RU-1",
      tag:   "РОССИЯ",
      ip:    "1.2.3.4",
      port:  "1080",
      login: "user",
      pass:  "password",
      desc:  "Москва · для Telegram и браузера"
    },
    {
      name:  "SOCKS5 FREE",
      tag:   "БЕЗ ПАРОЛЯ",
      ip:    "5.6.7.8",
      port:  "1080",
      login: "",
      pass:  "",
      desc:  "Публичный"
    }
  ],

  // Тексты страницы
  t: {
    navPill:    "// MTProto · SOCKS5 · VLESS · VPN",
    heroBadge:  "СЕТЬ АКТИВНА · ШИФРОВАНИЕ ВКЛЮЧЕНО",
    heroLine1:  "TELEGRAM",
    heroLine2:  "РАЗБЛОКИРОВАН",
    heroLine3:  "В 2 КЛИКА И БЕСПЛАТНО",
    heroSub:    "Бесплатный MTProto и SOCKS5 прокси для Telegram.",
    ex1title:   "Что такое MTProto прокси?",
    ex1desc:    "Работает внутри Telegram — один клик и готово.",
    ex2title:   "Что такое SOCKS5 прокси?",
    ex2desc:    "Универсальный прокси для Telegram и браузера.",
    ex3title:   "Зачем платный VPN?",
    ex3desc:    "Шифрует весь трафик. YouTube, Discord — всё сразу.",
    proxyBlockTitle: "ВЫБЕРИ ПРОКСИ СЕРВЕР",
    proxyBlockSub:   "БЕСПЛАТНО · MTProto и SOCKS5",
    proxyNote:       "Если сервер не работает — попробуй другой.",
    howTitle:   "Как работает MTProto прокси",
    howDesc:    "Прокси обходит блокировки — трафик идёт через незаблокированный сервер.",
    step1t: "Без прокси — блокировка",
    step1d: "Telegram заблокирован провайдером.",
    step2t: "С MTProto прокси",
    step2d: "Трафик идёт через наш незаблокированный сервер.",
    step3t: "Почему безопасно?",
    step3d: "Прокси не видит содержимое переписки.",
    cmpTitle:   "Прокси или VPN?",
    cmpDesc:    "Только Telegram — прокси бесплатно. Всё остальное — VPN.",
    plansTitle: "VPN на протоколе VLESS",
    plansDesc:  "Современный необнаруживаемый протокол.",
    ctaTitle:   "Начни за 10 секунд",
    ctaDesc:    "Прокси бесплатно. VPN через бота.",
    footerCopy: "© 2025 HIDEYOU · ALL SYSTEMS NOMINAL"
  }
};
```

---

## 📁 Структура файлов на сервере

```
/usr/local/bin/webm              ← команда webm
/var/log/webm.log                ← лог всех действий

/var/www/ДОМЕН/html/
  ├── index.html                 ← страница сайта
  └── config.js                 ← конфиг (прокси, ссылки, тексты)

/etc/nginx/sites-available/ДОМЕН ← конфиг Nginx
/var/www/_github_cache/          ← кэш файлов с GitHub
```

---

## 🔄 Обновление

**index.html:**
```bash
scp index.html root@IP:/var/www/ДОМЕН/html/index.html
```

**config.js:**
```bash
scp config.js root@IP:/var/www/ДОМЕН/html/config.js
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
