#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║   🌐  WEB SERVER MANAGER  v3.0                              ║
# ║   Nginx · SSL · UFW · Fail2ban · Auto-renew                 ║
# ║   Ubuntu 20.04 / 22.04 / 24.04                              ║
# ║                                                              ║
# ║   После установки запускай просто:  sudo webm               ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ЦВЕТА И СТИЛИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ПУТИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WEB_ROOT="/var/www"
NGINX_SITES="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
LOG_FILE="/var/log/webm.log"
INSTALL_PATH="/usr/local/bin/webm"
# ── URL публичного GitHub репо (вшит в скрипт) ──────────────
GITHUB_RAW="https://raw.githubusercontent.com/ChernOvOne/PRTG/main"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log()    { echo -e "  ${GREEN}✅${RESET} ${BOLD}$*${RESET}" | tee -a "$LOG_FILE"; }
warn()   { echo -e "  ${YELLOW}⚠️  ${RESET}$*" | tee -a "$LOG_FILE"; }
error()  { echo -e "  ${RED}❌${RESET} ${BOLD}$*${RESET}" | tee -a "$LOG_FILE"; }
info()   { echo -e "  ${CYAN}💡${RESET} $*"; }
step()   { echo -e "\n  ${MAGENTA}◆${RESET} ${BOLD}$*${RESET}"; }
spacer() { echo ""; }

line() {
    echo -e "  ${DIM}────────────────────────────────────────────────${RESET}"
}

section() {
    spacer
    echo -e "  ${BOLD}${BLUE}$*${RESET}"
    line
    spacer
}

svc_status() {
    local name="$1" svc="$2" emoji="${3:-🔵}"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  $emoji  ${BOLD}$name${RESET}  ${GREEN}● работает${RESET}"
    else
        echo -e "  $emoji  ${BOLD}$name${RESET}  ${RED}● остановлен${RESET}"
    fi
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Нужны права root. Запусти: ${BOLD}sudo webm${RESET}"
        exit 1
    fi
}

press_enter() {
    spacer
    echo -e "  ${DIM}Нажми Enter чтобы продолжить...${RESET}"
    read -r
}

check_ubuntu() {
    if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        warn "Система не Ubuntu — возможны проблемы."
    fi
}

spinner() {
    local pid=$1 msg="${2:-Подождите...}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % ${#spin} ))
        printf "\r  ${CYAN}${spin:$i:1}${RESET}  ${DIM}%s${RESET}" "$msg"
        sleep 0.1
    done
    printf "\r  ${GREEN}✅${RESET}  %-50s\n" "$msg"
}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GITHUB — загрузка файлов из публичного репо
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Скачивает файл из репо на локальный путь
# Использование: github_pull "index.html" "/var/www/site/html/index.html"
github_pull() {
    local remote_file="$1"
    local local_path="$2"
    local url="$GITHUB_RAW/$remote_file"

    step "Скачиваю $remote_file..."
    if curl -fsSL "$url" -o "$local_path"; then
        log "$remote_file → $local_path ✅"
        return 0
    else
        warn "Не удалось скачать: $url"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  САМОУСТАНОВКА КАК КОМАНДА webm

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
self_install() {
    step "Установка глобальной команды webm..."

    if [[ -x "$INSTALL_PATH" ]] && diff -q         <(curl -fsSL "$GITHUB_RAW/webserver-setup.sh" 2>/dev/null)         "$INSTALL_PATH" &>/dev/null; then
        log "Команда webm уже актуальна в $INSTALL_PATH"
        return
    fi

    if curl -fsSL "$GITHUB_RAW/webserver-setup.sh" -o "$INSTALL_PATH"; then
        chmod +x "$INSTALL_PATH"
        log "Команда ${BOLD}webm${RESET} установлена → $INSTALL_PATH"
        log "Теперь в любом месте запускай: ${CYAN}sudo webm${RESET}"
    else
        error "Не удалось скачать скрипт с GitHub."
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  УСТАНОВКА ЗАВИСИМОСТЕЙ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
apt_run() {
    # Запускает apt с живым выводом, строки фильтруются до читаемых
    # Использование: apt_run "Описание" apt-get install -y foo
    local desc="$1"; shift
    spacer
    echo -e "  ${MAGENTA}◆${RESET} ${BOLD}$desc${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────────────${RESET}"
    # Показываем только строки с реальным прогрессом, остальное — в лог
    "$@" 2>&1 | tee -a "$LOG_FILE" | grep --line-buffered \
        -E "^(Get:|Hit:|Fetched|Reading|Building|Setting up|Unpacking|Preparing|Processing|Selecting|Removing|upgrade)" \
        | sed 's/^/    /' \
        || true
    local rc=${PIPESTATUS[0]}
    if [[ $rc -ne 0 ]]; then
        error "$desc — ошибка (код $rc). Подробности: tail $LOG_FILE"
        return $rc
    fi
    log "$desc — готово ✅"
}

install_dependencies() {
    section "📦 Установка зависимостей"
    info "Живой вывод включён — видишь каждый скачиваемый пакет."
    info "Полный лог: ${BOLD}tail -f $LOG_FILE${RESET}"
    spacer

    # apt-get update отдельно — быстро, без upgrade
    apt_run "Обновление списков пакетов (apt update)" \
        apt-get update -y

    # upgrade запускаем с DEBIAN_FRONTEND чтобы не было интерактивных вопросов
    apt_run "Обновление системных пакетов (apt upgrade)" \
        env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold"

    apt_run "Базовые утилиты (curl wget git unzip build-essential...)" \
        apt-get install -y \
            curl wget git unzip zip \
            build-essential software-properties-common \
            apt-transport-https ca-certificates gnupg lsb-release

    apt_run "Nginx" \
        apt-get install -y nginx

    apt_run "Certbot + python3-certbot-nginx" \
        apt-get install -y certbot python3-certbot-nginx

    apt_run "UFW (брандмауэр)" \
        apt-get install -y ufw

    apt_run "Fail2ban (защита от брутфорса)" \
        apt-get install -y fail2ban

    apt_run "unattended-upgrades (авто-патчи безопасности)" \
        apt-get install -y unattended-upgrades

    spacer
    log "Все зависимости установлены! 🎉"
    info "Полный лог установки: ${BOLD}$LOG_FILE${RESET}"
}

configure_firewall() {
    section "🔥 Настройка брандмауэра UFW"

    ufw default deny incoming  >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1
    ufw allow ssh              >> "$LOG_FILE" 2>&1
    ufw allow 80/tcp           >> "$LOG_FILE" 2>&1
    ufw allow 443/tcp          >> "$LOG_FILE" 2>&1
    echo "y" | ufw enable      >> "$LOG_FILE" 2>&1

    log "По умолчанию — блокировать входящее"
    log "Разрешено: SSH (22), HTTP (80), HTTPS (443)"
    spacer
    ufw status | sed 's/^/  /'
}

configure_fail2ban() {
    section "🛡️  Настройка Fail2ban"

    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = %(sshd_backend)s

[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log

[nginx-limit-req]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 10

[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 2
EOF

    systemctl enable fail2ban  >> "$LOG_FILE" 2>&1
    systemctl restart fail2ban >> "$LOG_FILE" 2>&1

    log "Fail2ban настроен и запущен"
    log "Бан: 5 попыток за 10 минут → блокировка на 1 час"
}

configure_nginx_security() {
    section "🔒 Усиление безопасности Nginx"

    cat > /etc/nginx/conf.d/security.conf << 'EOF'
server_tokens off;
client_max_body_size 10M;
client_body_timeout   12;
client_header_timeout 12;
keepalive_timeout     15;
send_timeout          10;
limit_req_zone $binary_remote_addr zone=general:10m rate=30r/m;
limit_req_zone $binary_remote_addr zone=api:10m      rate=10r/m;
client_body_buffer_size     1k;
client_header_buffer_size   1k;
large_client_header_buffers 2 1k;
add_header X-Frame-Options           "SAMEORIGIN"                          always;
add_header X-XSS-Protection          "1; mode=block"                       always;
add_header X-Content-Type-Options    "nosniff"                             always;
add_header Referrer-Policy           "strict-origin-when-cross-origin"     always;
add_header Permissions-Policy        "geolocation=(), microphone=(), camera=()" always;
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
EOF

    nginx -t >> "$LOG_FILE" 2>&1 && systemctl reload nginx >> "$LOG_FILE" 2>&1

    log "Заголовки безопасности применены (XSS, HSTS, Frame, MIME)"
    log "Rate limiting: 30 req/min общий, 10 req/min API"
    log "Версия Nginx скрыта"
}

enable_auto_updates() {
    section "🔄 Авто-обновления безопасности"

    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    log "Патчи безопасности устанавливаются автоматически ежедневно"
}

setup_ssl_renewal() {
    section "🔐 Настройка авто-обновления SSL"

    if systemctl list-timers 2>/dev/null | grep -q certbot; then
        log "Systemd-таймер Certbot уже активен"
    else
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --nginx && systemctl reload nginx") \
            | sort -u | crontab -
        log "Cron: обновление SSL ежедневно в 03:00"
    fi

    certbot renew --dry-run >> "$LOG_FILE" 2>&1 \
        && log "Dry-run OK — авто-обновление работает" \
        || warn "Dry-run не прошёл (нормально, если домен ещё не настроен)"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  УПРАВЛЕНИЕ САЙТАМИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Создаёт минимальный index.html если GitHub недоступен
_create_index_placeholder() {
    local site_dir="$1" domain="$2" private_dir="$3"
    cat > "$site_dir/index.html" << HTMLEOF
<!DOCTYPE html><html lang="ru"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$domain</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui,sans-serif;background:#0f172a;color:#f8fafc;display:flex;align-items:center;justify-content:center;min-height:100vh}.card{text-align:center;padding:3rem 4rem;border:1px solid #1e293b;border-radius:16px}h1{font-size:2rem;color:#38bdf8;margin-bottom:.5rem}.badge{background:#0ea5e9;color:#fff;font-size:.75rem;padding:.25rem .75rem;border-radius:999px;margin-bottom:1.5rem;display:inline-block}p{color:#94a3b8;margin:.5rem 0}code{background:#1e293b;color:#38bdf8;padding:.15rem .5rem;border-radius:6px}</style>
</head><body>
<script>
<!--# include virtual="/.private/config.js" -->
</script>
<div class="card"><h1>🚀 $domain</h1>
<div class="badge">Сервер работает · SSI активен</div>
<p>Загрузи свой index.html с GitHub или по SCP</p>
<p>Конфиг: <code>$private_dir/config.js</code></p></div>
</body></html>
HTMLEOF
}

create_site() {
    section "🌍 Создание нового сайта"

    read -rp "$(echo -e "  ${CYAN}Домен ${DIM}(например: example.com)${RESET}: ")" DOMAIN
    [[ -z "$DOMAIN" ]] && { error "Домен не может быть пустым."; return; }

    # ── Спрашиваем ссылки для config.js ────────────────────────
    spacer
    echo -e "  ${BOLD}🔧 Настройка config.js${RESET}"
    echo -e "  ${DIM}Записывается в: /etc/nginx/private/$DOMAIN/config.js (недоступен из браузера)${RESET}"
    echo -e "  ${DIM}Редактировать позже: nano /etc/nginx/private/$DOMAIN/config.js${RESET}"
    spacer

    read -rp "$(echo -e "  ${CYAN}Ссылка на Telegram-бота VPN ${DIM}(Enter = пропустить)${RESET}: ")" CFG_BOT_LINK
    [[ -z "$CFG_BOT_LINK" ]] && CFG_BOT_LINK="https://t.me/ВАШ_БОТ"

    read -rp "$(echo -e "  ${CYAN}Ссылка на поддержку Telegram ${DIM}(Enter = пропустить)${RESET}: ")" CFG_SUPPORT_LINK
    [[ -z "$CFG_SUPPORT_LINK" ]] && CFG_SUPPORT_LINK="https://t.me/ВАША_ПОДДЕРЖКА"

    SITE_DIR="$WEB_ROOT/$DOMAIN/html"
    mkdir -p "$SITE_DIR"
    chown -R www-data:www-data "$WEB_ROOT/$DOMAIN"
    chmod -R 755 "$WEB_ROOT/$DOMAIN"

    # ── Приватная директория для config.js (внутри web-root, скрыта через Nginx) ──
    PRIVATE_DIR="$SITE_DIR/.private"
    mkdir -p "$PRIVATE_DIR"
    chown www-data:www-data "$PRIVATE_DIR"
    chmod 750 "$PRIVATE_DIR"

    # ── config.js — скачиваем с GitHub (или из кэша), подставляем данные
    local _cfg_tmp
    _cfg_tmp=$(mktemp)

    # 1. Пробуем кэш из full_install
    if [[ -f "/var/www/_github_cache/config.js" ]]; then
        cp "/var/www/_github_cache/config.js" "$_cfg_tmp"
        log "config.js взят из кэша GitHub"
    # 2. Пробуем скачать напрямую
    elif github_pull "config.js" "$_cfg_tmp"; then
        log "config.js скачан с GitHub"
    # 3. Создаём из встроенного шаблона
    else
        warn "config.js не скачан — создаю встроенный шаблон"
        cat > "$_cfg_tmp" << 'TPLEOF'
const CFG = {
  botLink:     "PLACEHOLDER_BOT",
  supportLink: "PLACEHOLDER_SUP",
  mtproto: [
    { name:"ПРОКСИ RU-1", tag:"ОСНОВНОЙ", addr:"your.server.com:443",
      link:"tg://proxy?server=your.server.com&port=443&secret=ВАШ_СЕКРЕТ", desc:"Москва" }
  ],
  socks5: [
    { name:"SOCKS5 RU-1", tag:"РОССИЯ", ip:"0.0.0.0", port:"1080",
      login:"user", pass:"password", desc:"Москва" }
  ],
  t: {
    navPill:"// MTProto · SOCKS5 · VLESS · VPN",
    heroBadge:"СЕТЬ АКТИВНА · ШИФРОВАНИЕ ВКЛЮЧЕНО",
    heroLine1:"TELEGRAM", heroLine2:"РАЗБЛОКИРОВАН", heroLine3:"В 2 КЛИКА И БЕСПЛАТНО",
    heroSub:"Бесплатный прокси для Telegram.",
    ex1title:"Что такое MTProto прокси?", ex1desc:"Один клик — и Telegram работает через наш сервер.",
    ex2title:"Что такое SOCKS5 прокси?",  ex2desc:"Универсальный прокси для любых приложений.",
    ex3title:"Зачем платный VPN?",         ex3desc:"Шифрует весь трафик. YouTube, Discord — всё сразу.",
    proxyBlockTitle:"ВЫБЕРИ ПРОКСИ СЕРВЕР", proxyBlockSub:"БЕСПЛАТНО · MTProto и SOCKS5",
    proxyNote:"Если сервер не работает — попробуй другой.",
    howTitle:"Как работает MTProto прокси", howDesc:"Прокси обходит блокировки РКН.",
    step1t:"Без прокси — блокировка", step1d:"Telegram заблокирован провайдером.",
    step2t:"С MTProto прокси",        step2d:"Трафик идёт через незаблокированный сервер.",
    step3t:"Почему безопасно?",       step3d:"Прокси не видит содержимое переписки.",
    cmpTitle:"Прокси или VPN?", cmpDesc:"Только Telegram — прокси. Всё остальное — VPN.",
    plansTitle:"VPN на протоколе VLESS", plansDesc:"Современный необнаруживаемый протокол.",
    ctaTitle:"Начни за 10 секунд", ctaDesc:"Прокси бесплатно. VPN через бота.",
    footerCopy:"© 2025 HIDEYOU"
  }
};
TPLEOF
    fi

    # Подставляем реальные ссылки и домен
    # Подставляем реальные ссылки и домен через python3
    python3 - "$_cfg_tmp" "$CFG_BOT_LINK" "$CFG_SUPPORT_LINK" "$DOMAIN" << 'PYEOF2'
import sys
path, bot, sup, domain = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path, 'r') as f:
    c = f.read()
for placeholder, value in [
    ('PLACEHOLDER_BOT', bot),
    ('PLACEHOLDER_SUP', sup),
    ('https://t.me/MyVPN_bot', bot),
    ('https://t.me/MySupport', sup),
    ('\u00a9 2025 HIDEYOU', '\u00a9 2025 ' + domain),
    ('© 2025 HIDEYOU', '© 2025 ' + domain),
]:
    c = c.replace(placeholder, value)
with open(path, 'w') as f:
    f.write(c)
PYEOF2

    cp "$_cfg_tmp" "$PRIVATE_DIR/config.js"
    rm -f "$_cfg_tmp"

    chown www-data:www-data "$PRIVATE_DIR/config.js"
    chmod 640 "$PRIVATE_DIR/config.js"

    # ── index.html — скачиваем с GitHub ────────────────────────
    if github_pull "index.html" "$SITE_DIR/index.html"; then
        # Подставляем реальный домен в SSI-тег
        log "SSI путь прописан верно: /.private/config.js"
        log "index.html скачан с GitHub и настроен для $DOMAIN"
    else
        warn "Не удалось скачать index.html — создаю заглушку."
        _create_index_placeholder "$SITE_DIR" "$DOMAIN" "$PRIVATE_DIR"
    fi

    cat > "$NGINX_SITES/$DOMAIN" << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $SITE_DIR;
    index index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log  /var/log/nginx/${DOMAIN}_error.log;

    limit_req zone=general burst=20 nodelay;
    autoindex off;

    # ── SSI: Nginx вставляет config.js в HTML на сервере ────────
    ssi on;
    ssi_silent_errors off;

    # ── Блокировка прямого доступа к приватным файлам ───────────
    location ~ /\. { deny all; return 404; }
    location ~* \.(env|log|conf|bak|sql|sh|git)$ { deny all; return 404; }

    # .private — только для SSI, браузер получает 404
    location ^~ /.private/ { internal; }

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff2?|ttf)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
NGINXEOF

    ln -sf "$NGINX_SITES/$DOMAIN" "$NGINX_ENABLED/$DOMAIN"
    nginx -t >> "$LOG_FILE" 2>&1 && systemctl reload nginx >> "$LOG_FILE" 2>&1

    spacer
    log "Сайт ${BOLD}$DOMAIN${RESET} создан! SSI включён 🔒"
    spacer
    echo -e "  📁 ${BOLD}Куда класть файлы:${RESET}"
    echo -e "     ${GREEN}$SITE_DIR/index.html${RESET}         ← главная страница"
    echo -e "     ${GREEN}$SITE_DIR/css/${RESET}               ← стили"
    echo -e "     ${GREEN}$SITE_DIR/js/${RESET}                ← скрипты"
    echo -e "     ${GREEN}$SITE_DIR/img/${RESET}               ← картинки"
    spacer
    echo -e "  🔒 ${BOLD}Приватный конфиг (SSI):${RESET}"
    echo -e "     ${CYAN}/etc/nginx/private/$DOMAIN/config.js${RESET}  ← редактируй здесь"
    echo -e "     ${DIM}Файл НЕ доступен через браузер — Nginx вставляет его в HTML на сервере${RESET}"
    spacer
    echo -e "  📤 ${BOLD}Залить index.html по SCP:${RESET}"
    echo -e "     ${DIM}scp ./index.html user@IP:$SITE_DIR/index.html${RESET}"
    spacer
    echo -e "  📤 ${BOLD}Залить config.js по SCP:${RESET}"
    echo -e "     ${DIM}scp ./config.js user@IP:/etc/nginx/private/$DOMAIN/config.js${RESET}"
    spacer
    read -rp "$(echo -e "  ${CYAN}Получить SSL для $DOMAIN прямо сейчас? (y/n):${RESET} ")" GET_SSL
    [[ "$GET_SSL" =~ ^[Yy]$ ]] && issue_ssl "$DOMAIN"
}

issue_ssl() {
    local DOMAIN="${1:-}"
    if [[ -z "$DOMAIN" ]]; then
        read -rp "$(echo -e "  ${CYAN}Домен для SSL:${RESET} ")" DOMAIN
    fi
    read -rp "$(echo -e "  ${CYAN}Email для Let's Encrypt:${RESET} ")" EMAIL

    spacer
    certbot --nginx -d "$DOMAIN" \
        --non-interactive --agree-tos \
        --email "$EMAIL" --redirect \
        2>&1 | tee -a "$LOG_FILE" | sed 's/^/  /'

    log "SSL-сертификат получен и настроен 🔐"
    log "Авто-обновление активно"
}

delete_site() {
    section "🗑️  Удаление сайта"
    set +e  # отключаем выход по ошибке на время функции
    list_sites

    spacer
    read -rp "$(echo -e "  ${CYAN}Домен для удаления:${RESET} ")" DOMAIN
    if [[ -z "$DOMAIN" ]]; then info "Отменено."; set -e; return; fi

    spacer
    warn "Это удалит ${BOLD}$DOMAIN${RESET} и все файлы навсегда!"
    read -rp "$(echo -e "  ${RED}Введи «yes» для подтверждения:${RESET} ")" CONFIRM
    [[ "$CONFIRM" != "yes" ]] && { info "Отменено."; return; }

    spacer
    step "Удаляю конфиг Nginx..."
    rm -f "$NGINX_ENABLED/$DOMAIN"      && log "Симлинк удалён"        || warn "Симлинк не найден"
    rm -f "$NGINX_SITES/$DOMAIN"        && log "Конфиг Nginx удалён"   || warn "Конфиг Nginx не найден"

    step "Удаляю файлы сайта..."
    rm -rf "${WEB_ROOT:?}/$DOMAIN"      && log "Файлы сайта удалены"   || warn "Файлы не найдены"

    step "Удаляю приватный конфиг..."
    rm -rf "$SITE_DIR/.private" && log "config.js удалён" || warn "Приватный конфиг не найден"

    step "Удаляю SSL-сертификат..."
    if certbot delete --cert-name "$DOMAIN" --non-interactive >> "$LOG_FILE" 2>&1; then
        log "SSL-сертификат удалён"
    else
        warn "SSL-сертификат не найден или уже удалён"
    fi

    step "Перезагружаю Nginx..."
    if nginx -t >> "$LOG_FILE" 2>&1 && systemctl reload nginx >> "$LOG_FILE" 2>&1; then
        log "Nginx перезагружен"
    else
        error "Ошибка Nginx — проверь: nginx -t"
    fi

    spacer
    log "Сайт ${BOLD}$DOMAIN${RESET} полностью удалён ✅"
    set -e  # восстанавливаем
}

list_sites() {
    section "🌐 Список сайтов"
    set +e

    local found=0
    for f in "$NGINX_ENABLED"/*; do
        [[ -f "$f" ]] || continue
        local NAME
        NAME=$(basename "$f")
        [[ "$NAME" == "default" ]] && continue
        found=1

        local SSL_TAG="${DIM}[без SSL]${RESET}"
        if certbot certificates 2>/dev/null | grep -q "Domains:.*$NAME"; then
            SSL_TAG="${GREEN}[🔐 SSL]${RESET}"
        fi

        echo -e "  🟢 ${BOLD}${CYAN}$NAME${RESET}  $SSL_TAG"
        echo -e "     ${DIM}📁 $WEB_ROOT/$NAME/html${RESET}"
        line
    done

    if [[ $found -eq 0 ]]; then
        info "Нет настроенных сайтов. Создай первый через пункт 3!"
    fi
    set -e
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  УПРАВЛЕНИЕ СЕРВЕРОМ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
server_status() {
    section "📊 Статус сервера"

    svc_status "Nginx"    "nginx"    "🌐"
    svc_status "Fail2ban" "fail2ban" "🛡️ "
    svc_status "UFW"      "ufw"      "🔥"

    spacer; line

    echo -e "  ${BOLD}🔐 SSL-сертификаты:${RESET}"
    certbot certificates 2>/dev/null \
        | grep -E "Domains:|Expiry Date:" \
        | sed 's/^/     /' \
        || echo -e "     ${DIM}Нет сертификатов${RESET}"

    spacer; line

    echo -e "  ${BOLD}💻 Ресурсы системы:${RESET}"
    local cpu ram disk uptime_str
    cpu=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "?")
    ram=$(free -h | awk '/^Mem:/{print $3 " / " $2}')
    disk=$(df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}')
    uptime_str=$(uptime -p)

    echo -e "     🖥️  CPU:    ${GREEN}${cpu}%${RESET}"
    echo -e "     🧠 RAM:    ${GREEN}${ram}${RESET}"
    echo -e "     💾 Диск:   ${GREEN}${disk}${RESET}"
    echo -e "     ⏱️  Аптайм: ${GREEN}${uptime_str}${RESET}"

    spacer; line

    local conn
    conn=$(ss -tnp 2>/dev/null | grep -cE ":80|:443" || echo "0")
    echo -e "  ${BOLD}🔗 Соединений (80/443):${RESET} ${GREEN}$conn${RESET}"
    spacer
}

restart_all_services() {
    section "♻️  Перезапуск всех сервисов"

    for svc in nginx fail2ban ufw; do
        step "Перезапуск $svc..."
        if systemctl restart "$svc" >> "$LOG_FILE" 2>&1; then
            log "$svc — перезапущен"
        else
            error "$svc — ошибка при перезапуске"
        fi
    done

    spacer; line
    spacer
    svc_status "Nginx"    "nginx"    "🌐"
    svc_status "Fail2ban" "fail2ban" "🛡️ "
    svc_status "UFW"      "ufw"      "🔥"
    spacer
    log "Все сервисы перезапущены ♻️"
}

stop_all_services() {
    section "⏹️  Остановка всех сервисов"

    warn "Nginx будет остановлен — сайты станут недоступны!"
    read -rp "$(echo -e "  ${YELLOW}Продолжить? (y/n):${RESET} ")" CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { info "Отменено."; return; }

    for svc in nginx fail2ban; do
        if systemctl stop "$svc" >> "$LOG_FILE" 2>&1; then
            warn "$svc остановлен"
        else
            error "$svc — ошибка при остановке"
        fi
    done
}

start_all_services() {
    section "▶️  Запуск всех сервисов"

    for svc in nginx fail2ban ufw; do
        step "Запуск $svc..."
        if systemctl start "$svc" >> "$LOG_FILE" 2>&1; then
            log "$svc запущен"
        else
            error "$svc — ошибка запуска"
        fi
    done

    spacer; line; spacer
    svc_status "Nginx"    "nginx"    "🌐"
    svc_status "Fail2ban" "fail2ban" "🛡️ "
    svc_status "UFW"      "ufw"      "🔥"
}

nginx_control() {
    section "🌐 Управление Nginx"

    echo -e "  ${CYAN}1)${RESET}  ▶️   Запустить"
    echo -e "  ${CYAN}2)${RESET}  ⏹️   Остановить"
    echo -e "  ${CYAN}3)${RESET}  ♻️   Перезапустить"
    echo -e "  ${CYAN}4)${RESET}  🔄  Перезагрузить конфиг ${DIM}(без простоя)${RESET}"
    echo -e "  ${CYAN}5)${RESET}  ✅  Проверить конфиг"
    echo -e "  ${RED}0)${RESET}  ↩️   Назад"
    spacer
    read -rp "$(echo -e "  ${YELLOW}Выбор:${RESET} ")" OPT
    case "$OPT" in
        1) systemctl start   nginx >> "$LOG_FILE" 2>&1 && log "Nginx запущен ▶️" ;;
        2) systemctl stop    nginx >> "$LOG_FILE" 2>&1 && warn "Nginx остановлен ⏹️" ;;
        3) systemctl restart nginx >> "$LOG_FILE" 2>&1 && log "Nginx перезапущен ♻️" ;;
        4) nginx -t && systemctl reload nginx >> "$LOG_FILE" 2>&1 && log "Конфиг перезагружен без простоя 🔄" ;;
        5) nginx -t && log "Конфиг корректен ✅" ;;
        0) return ;;
        *) error "Неверный выбор." ;;
    esac
}

view_logs() {
    section "📋 Просмотр логов"

    echo -e "  ${CYAN}1)${RESET}  📥  Nginx — access log"
    echo -e "  ${CYAN}2)${RESET}  ❌  Nginx — error log"
    echo -e "  ${CYAN}3)${RESET}  🛡️   Fail2ban log"
    echo -e "  ${CYAN}4)${RESET}  📝  Лог webm"
    echo -e "  ${CYAN}5)${RESET}  👀  Следить за логом ${DIM}(live, Ctrl+C для выхода)${RESET}"
    echo -e "  ${RED}0)${RESET}  ↩️   Назад"
    spacer
    read -rp "$(echo -e "  ${YELLOW}Выбор:${RESET} ")" OPT
    spacer

    case "$OPT" in
        1) tail -50 /var/log/nginx/access.log 2>/dev/null | sed 's/^/  /' || warn "Лог пуст." ;;
        2) tail -50 /var/log/nginx/error.log  2>/dev/null | sed 's/^/  /' || warn "Лог пуст." ;;
        3) tail -50 /var/log/fail2ban.log     2>/dev/null | sed 's/^/  /' || warn "Лог пуст." ;;
        4) tail -50 "$LOG_FILE"               2>/dev/null | sed 's/^/  /' || warn "Лог пуст." ;;
        5)
            info "Слежение за access log... Нажми Ctrl+C для выхода."
            tail -f /var/log/nginx/access.log
            ;;
        0) return ;;
    esac

    press_enter
}

security_report() {
    section "🛡️  Отчёт безопасности"

    echo -e "  ${BOLD}🚫 Заблокированные IP (Fail2ban):${RESET}"
    fail2ban-client status 2>/dev/null \
        | grep "Jail list" \
        | sed 's/.*Jail list:\s*//' \
        | tr ',' '\n' \
        | while read -r jail; do
            jail=$(echo "$jail" | xargs)
            [[ -z "$jail" ]] && continue
            local banned
            banned=$(fail2ban-client status "$jail" 2>/dev/null | grep "Banned IP" | awk -F: '{print $2}' | xargs)
            [[ -n "$banned" ]] \
                && echo -e "     ${RED}$jail:${RESET} $banned" \
                || echo -e "     ${DIM}$jail: нет банов${RESET}"
        done

    spacer; line

    echo -e "  ${BOLD}🔐 SSH — неудачные входы за 24ч:${RESET}"
    journalctl -u ssh --since "24h ago" 2>/dev/null \
        | grep "Failed" \
        | awk '{print $1,$2,$3,$11}' \
        | tail -10 \
        | sed 's/^/     /' \
        || echo -e "     ${DIM}Нет данных${RESET}"

    spacer; line

    echo -e "  ${BOLD}🔓 Открытые порты:${RESET}"
    ss -tlnp | awk 'NR>1 {printf "     %-8s %s\n", $1, $4}'

    spacer; line

    echo -e "  ${BOLD}🔐 Срок SSL-сертификатов:${RESET}"
    certbot certificates 2>/dev/null \
        | grep -E "Domains:|Expiry Date:" \
        | sed 's/^/     /' \
        || echo -e "     ${DIM}Нет сертификатов${RESET}"

    spacer
    press_enter
}

renew_ssl_manual() {
    section "🔐 Обновление SSL-сертификатов"

    step "Запуск certbot renew..."
    certbot renew --nginx 2>&1 | tee -a "$LOG_FILE" | sed 's/^/  /'
    systemctl reload nginx >> "$LOG_FILE" 2>&1

    spacer
    log "Все сертификаты проверены / обновлены"
    press_enter
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ПОЛНАЯ УСТАНОВКА
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
full_install() {
    clear
    echo -e "${BOLD}${BLUE}"
    cat << 'BANNER'
  ╔══════════════════════════════════════════════════════════════╗
  ║   🚀  ПОЛНАЯ УСТАНОВКА WEB SERVER                           ║
  ║   Nginx · SSL · UFW · Fail2ban · Auto-updates               ║
  ╚══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${RESET}"
    info "Это займёт 2–5 минут. Сядь поудобнее ☕"
    spacer

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    install_dependencies
    configure_firewall
    configure_fail2ban
    configure_nginx_security
    enable_auto_updates
    setup_ssl_renewal

    rm -f "$NGINX_ENABLED/default"
    nginx -t >> "$LOG_FILE" 2>&1 && systemctl reload nginx >> "$LOG_FILE" 2>&1
    systemctl enable nginx fail2ban >> "$LOG_FILE" 2>&1

    # Самоустановка команды webm
    self_install

    # Скачиваем актуальные файлы сайта с GitHub
    section "🐙 Загрузка файлов с GitHub"
    mkdir -p /var/www/_github_cache
    github_pull "index.html" "/var/www/_github_cache/index.html" \
        && log "index.html сохранён в /var/www/_github_cache/index.html" \
        || warn "index.html не скачан — будет скачан при создании сайта"
    github_pull "config.js"  "/var/www/_github_cache/config.js" \
        && log "config.js (демо) сохранён в /var/www/_github_cache/config.js" \
        || warn "config.js не скачан — будет создан из шаблона при создании сайта"

    # ── Итоговый экран ────────────────────────────────────────
    clear
    echo -e "${BOLD}${GREEN}"
    cat << 'DONE'
  ╔══════════════════════════════════════════════════════════════╗
  ║                                                              ║
  ║   ✅  УСТАНОВКА ЗАВЕРШЕНА!                                   ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
DONE
    echo -e "${RESET}"

    echo -e "  ${GREEN}🌐 Nginx${RESET}         — запущен и в автозапуске"
    echo -e "  ${GREEN}🔥 UFW${RESET}           — порты 22, 80, 443 открыты"
    echo -e "  ${GREEN}🛡️  Fail2ban${RESET}      — защита SSH и Nginx"
    echo -e "  ${GREEN}🔄 Auto-updates${RESET}  — обновления безопасности ежедневно"
    echo -e "  ${GREEN}🔐 SSL renewal${RESET}   — сертификаты обновляются сами"
    spacer; line; spacer

    echo -e "  ${BOLD}📁 КАК ДОБАВИТЬ СВОЙ САЙТ:${RESET}"
    spacer
    echo -e "  ${CYAN}1)${RESET} Запусти менеджер:  ${BOLD}${GREEN}sudo webm${RESET}"
    echo -e "  ${CYAN}2)${RESET} Выбери:            ${BOLD}3) Создать новый сайт${RESET}"
    echo -e "  ${CYAN}3)${RESET} Введи домен        ${DIM}(например: mysite.ru)${RESET}"
    echo -e "  ${CYAN}4)${RESET} Клади файлы в:     ${GREEN}/var/www/mysite.ru/html/${RESET}"
    spacer
    echo -e "  📤 ${BOLD}Залить файлы по SCP:${RESET}"
    echo -e "     ${DIM}scp -r ./my-site/* user@ВАШ-IP:/var/www/mysite.ru/html/${RESET}"
    spacer; line; spacer

    echo -e "  ${BOLD}${MAGENTA}  ✨ Теперь просто набирай:  sudo webm${RESET}"
    spacer; line; spacer
    echo -e "  ${BOLD}📁 СЛЕДУЮЩИЙ ШАГ — создать сайт:${RESET}"
    spacer
    echo -e "  ${CYAN}1)${RESET} Запусти:   ${BOLD}${GREEN}sudo webm${RESET}"
    echo -e "  ${CYAN}2)${RESET} Выбери:    ${BOLD}3) Создать новый сайт${RESET}"
    echo -e "  ${CYAN}3)${RESET} Введи домен, ссылку на бота и поддержку"
    spacer
    echo -e "  ${GREEN}index.html и config.js скачаются с GitHub автоматически${RESET}"
    echo -e "  ${DIM}Конфиг прокси: nano /etc/nginx/private/ДОМЕН/config.js${RESET}"
    spacer

    press_enter
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  БАННЕР
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    cat << 'BANNER'
  ╔══════════════════════════════════════════════════════════════╗
  ║   🌐  WEB SERVER MANAGER  v3.0                              ║
  ║   Nginx · SSL · UFW · Fail2ban                              ║
  ╚══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${RESET}"

    # Живой мини-статус в шапке
    local ng_st fb_st
    ng_st=$(systemctl is-active nginx    2>/dev/null || echo "inactive")
    fb_st=$(systemctl is-active fail2ban 2>/dev/null || echo "inactive")

    local ng_dot fb_dot
    [[ "$ng_st" == "active" ]] && ng_dot="${GREEN}●${RESET}" || ng_dot="${RED}●${RESET}"
    [[ "$fb_st" == "active" ]] && fb_dot="${GREEN}●${RESET}" || fb_dot="${RED}●${RESET}"

    echo -e "  🌐 Nginx $ng_dot   🛡️  Fail2ban $fb_dot   🕐 $(date '+%H:%M  %d.%m.%Y')"
    line
    spacer
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ГЛАВНОЕ МЕНЮ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
main_menu() {
    while true; do
        show_banner

        echo -e "  ${DIM}${BOLD}── 🔧 УСТАНОВКА ─────────────────────────────────${RESET}"
        echo -e "  ${GREEN}1)${RESET}  🚀  Полная установка веб-сервера"
        echo -e "  ${GREEN}2)${RESET}  🔁  Переустановить команду webm"
        spacer

        echo -e "  ${DIM}${BOLD}── 🌍 УПРАВЛЕНИЕ САЙТАМИ ────────────────────────${RESET}"
        echo -e "  ${CYAN}3)${RESET}  ➕  Создать новый сайт"
        echo -e "  ${CYAN}4)${RESET}  📋  Список всех сайтов"
        echo -e "  ${CYAN}5)${RESET}  🗑️   Удалить сайт"
        spacer

        echo -e "  ${DIM}${BOLD}── 🔐 SSL-СЕРТИФИКАТЫ ───────────────────────────${RESET}"
        echo -e "  ${CYAN}6)${RESET}  🔐  Выпустить SSL для домена"
        echo -e "  ${CYAN}7)${RESET}  🔄  Обновить все SSL вручную"
        spacer

        echo -e "  ${DIM}${BOLD}── ⚙️  УПРАВЛЕНИЕ СЕРВИСАМИ ──────────────────────${RESET}"
        echo -e "  ${CYAN}8)${RESET}  📊  Статус сервера"
        echo -e "  ${CYAN}9)${RESET}  ▶️   Запустить все сервисы"
        echo -e "  ${CYAN}10)${RESET} ⏹️   Остановить все сервисы"
        echo -e "  ${CYAN}11)${RESET} ♻️   Перезапустить все сервисы"
        echo -e "  ${CYAN}12)${RESET} 🌐  Управление Nginx"
        spacer

        echo -e "  ${DIM}${BOLD}── 🔍 МОНИТОРИНГ ────────────────────────────────${RESET}"
        echo -e "  ${CYAN}13)${RESET} 📋  Просмотр логов"
        echo -e "  ${CYAN}14)${RESET} 🛡️   Отчёт безопасности"
        spacer

        echo -e "  ${RED}0)${RESET}  👋  Выход"
        spacer
        line

        read -rp "$(echo -e "  ${YELLOW}▶ Выбор:${RESET} ")" CHOICE
        spacer

        case "$CHOICE" in
            1)  require_root; full_install ;;
            2)  require_root; self_install; press_enter ;;
            3)  require_root; create_site; press_enter ;;
            4)  list_sites; press_enter ;;
            5)  require_root; delete_site; press_enter ;;
            6)  require_root; issue_ssl; press_enter ;;
            7)  require_root; renew_ssl_manual ;;
            8)  server_status; press_enter ;;
            9)  require_root; start_all_services; press_enter ;;
            10) require_root; stop_all_services; press_enter ;;
            11) require_root; restart_all_services; press_enter ;;
            12) require_root; nginx_control; press_enter ;;
            13) view_logs ;;
            14) security_report ;;
            0)
                spacer
                echo -e "  👋 ${GREEN}${BOLD}До встречи!${RESET} Сервер продолжает работать."
                spacer
                exit 0
                ;;
            *)
                error "Неверный выбор: «$CHOICE». Попробуй ещё раз."
                sleep 1
                ;;
        esac
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ТОЧКА ВХОДА
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
case "${1:-}" in
    --install)   require_root; full_install ;;
    --status)    server_status ;;
    --restart)   require_root; restart_all_services ;;
    --renew-ssl) require_root; certbot renew --nginx && systemctl reload nginx ;;
    --help|-h)
        spacer
        echo -e "  ${BOLD}🌐 Web Server Manager — webm v3.0${RESET}"
        spacer
        echo -e "  ${BOLD}Использование:${RESET}  sudo webm [ОПЦИЯ]"
        spacer
        echo -e "  ${CYAN}(без аргументов)${RESET}   Интерактивное меню"
        echo -e "  ${CYAN}--install${RESET}          Полная установка"
        echo -e "  ${CYAN}--status${RESET}           Статус сервера"
        echo -e "  ${CYAN}--restart${RESET}          Перезапустить все сервисы"
        echo -e "  ${CYAN}--renew-ssl${RESET}        Обновить SSL-сертификаты"
        echo -e "  ${CYAN}--help${RESET}             Эта справка"
        spacer
        ;;
    *)
        require_root
        check_ubuntu
        main_menu
        ;;
esac
