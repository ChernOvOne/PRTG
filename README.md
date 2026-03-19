# 🌐 HideYou — Web Server Manager

Публичный репозиторий. Скрипт и `index.html` — не секрет.  
Реальный `config.js` с паролями хранится **только на сервере**, в репо его нет.

---

## ⚡ Одна команда — полная установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ВАШ_ЮЗЕР/ВАШ_РЕПО/main/webserver-setup.sh)
```

Скрипт установит Nginx, SSL, UFW, Fail2ban и установит себя как `sudo webm`.

---

## 📁 Структура репозитория

```
/
├── webserver-setup.sh   ← главный скрипт
├── index.html           ← страница сайта (без секретов)
└── README.md

НЕ В РЕПО (только на сервере):
  /etc/nginx/private/ДОМЕН/config.js   ← прокси, пароли, ссылки
  /etc/webm/github.conf                ← сохранённый GitHub URL
```

---

## 🛠️ Первичная настройка

### 1. Создай репозиторий на GitHub

[github.com/new](https://github.com/new) → **Public** → **Create repository**

### 2. Залей файлы

```bash
git clone https://github.com/ВАШ_ЮЗЕР/ВАШ_РЕПО.git
cd ВАШ_РЕПО
cp /path/to/webserver-setup.sh .
cp /path/to/index.html .
git add . && git commit -m "init" && git push
```

### 3. На новом сервере — одна команда

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ВАШ_ЮЗЕР/ВАШ_РЕПО/main/webserver-setup.sh)
```

### 4. Настроить GitHub URL в скрипте (один раз)

```
sudo webm → 15) Настроить GitHub URL
```

Введи:
```
https://raw.githubusercontent.com/ВАШ_ЮЗЕР/ВАШ_РЕПО/main
```

URL сохраняется в `/etc/webm/github.conf`.  
Теперь при создании сайта `index.html` скачается автоматически.

---

## 🌍 Создание сайта (sudo webm → пункт 3)

Скрипт спросит:
1. **Домен** — `hideyou.top`
2. **Ссылка на бота** — `https://t.me/HideYouTop_bot`
3. **Ссылка на поддержку** — `https://t.me/Hide_You`

Затем автоматически:
- Скачает `index.html` с GitHub и подставит домен в SSI-тег
- Создаст `/etc/nginx/private/ДОМЕН/config.js` с твоими ссылками
- Настроит Nginx + SSI + запрет прямого доступа к конфигу
- Предложит выпустить SSL

После — добавь прокси-серверы:
```bash
nano /etc/nginx/private/ДОМЕН/config.js
```

---

## 🔄 Обновления

**Обновить webm с GitHub:**
```
sudo webm → 16) Обновить webm с GitHub
```

**Обновить index.html вручную:**
```bash
scp index.html root@IP:/var/www/ДОМЕН/html/index.html
```

---

## 🔒 Безопасность

| Что | Публично? | Комментарий |
|-----|-----------|-------------|
| `webserver-setup.sh` | ✅ | Не содержит секретов |
| `index.html` | ✅ | Шаблон без паролей |
| `config.js` (реальный) | ❌ | Только на сервере |
| Конфиг в браузере | ❌ | SSI — вставка на сервере |
