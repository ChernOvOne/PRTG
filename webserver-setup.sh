#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║   🌐  WEB SERVER MANAGER  v4.0                              ║
# ║   Nginx · SSL · UFW · Fail2ban · Auto-renew                 ║
# ║   Ubuntu 20.04 / 22.04 / 24.04                              ║
# ║   После установки запускай просто:  sudo webm               ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  КОНФИГУРАЦИЯ — вшитый URL репо
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GITHUB_RAW="https://raw.githubusercontent.com/ChernOvOne/PRTG/main"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ЦВЕТА
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log()    { echo -e "  ${GREEN}✅${RESET} ${BOLD}$*${RESET}" | tee -a "$LOG_FILE"; }
warn()   { echo -e "  ${YELLOW}⚠️  ${RESET}$*" | tee -a "$LOG_FILE"; }
error()  { echo -e "  ${RED}❌${RESET} ${BOLD}$*${RESET}" | tee -a "$LOG_FILE"; }
info()   { echo -e "  ${CYAN}💡${RESET} $*"; }
step()   { echo -e "\n  ${MAGENTA}◆${RESET} ${BOLD}$*${RESET}"; }
spacer() { echo ""; }
line()   { echo -e "  ${DIM}────────────────────────────────────────────────${RESET}"; }

section() {
    spacer
    echo -e "  ${BOLD}${BLUE}$*${RESET}"
    line
    spacer
}

press_enter() {
    spacer
    echo -e "  ${DIM}Нажми Enter чтобы продолжить...${RESET}"
    read -r
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Нужны права root. Запусти: ${BOLD}sudo webm${RESET}"
        exit 1
    fi
}

svc_status() {
    local name="$1" svc="$2" emoji="${3:-🔵}"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  $emoji  ${BOLD}$name${RESET}  ${GREEN}● работает${RESET}"
    else
        echo -e "  $emoji  ${BOLD}$name${RESET}  ${RED}● остановлен${RESET}"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GITHUB — скачивание файлов
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
    local desc="$1"; shift
    spacer
    echo -e "  ${MAGENTA}◆${RESET} ${BOLD}$desc${RESET}"
    line
    "$@" 2>&1 | tee -a "$LOG_FILE" | grep --line-buffered \
        -E "^(Get:|Hit:|Fetched|Reading|Building|Setting up|Unpacking|Preparing|Processing|Selecting)" \
        | sed 's/^/    /' || true
    local rc=${PIPESTATUS[0]}
    if [[ $rc -ne 0 ]]; then
        error "$desc — ошибка (код $rc). Подробности: tail $LOG_FILE"
        return $rc
    fi
    log "$desc — готово ✅"
}

install_dependencies() {
    section "📦 Установка зависимостей"
    info "Полный лог: ${BOLD}tail -f $LOG_FILE${RESET}"
    spacer

    apt_run "Обновление списков пакетов" apt-get update -y

    apt_run "Обновление системных пакетов" \
        env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold"

    apt_run "Базовые утилиты" \
        apt-get install -y curl wget git unzip zip \
            build-essential software-properties-common \
            apt-transport-https ca-certificates gnupg lsb-release

    apt_run "Nginx"   apt-get install -y nginx
    apt_run "Certbot" apt-get install -y certbot python3-certbot-nginx
    apt_run "UFW"     apt-get install -y ufw
    apt_run "Fail2ban" apt-get install -y fail2ban
    apt_run "Авто-патчи" apt-get install -y unattended-upgrades

    spacer
    log "Все зависимости установлены! 🎉"
}

configure_firewall() {
    section "🔥 Настройка UFW"
    ufw default deny incoming  >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1
    ufw allow ssh              >> "$LOG_FILE" 2>&1
    ufw allow 80/tcp           >> "$LOG_FILE" 2>&1
    ufw allow 443/tcp          >> "$LOG_FILE" 2>&1
    echo "y" | ufw enable      >> "$LOG_FILE" 2>&1
    log "UFW настроен: 22, 80, 443 открыты"
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
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
port    = http,https
logpath = /var/log/nginx/error.log

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
    systemctl enable fail2ban >> "$LOG_FILE" 2>&1
    systemctl restart fail2ban >> "$LOG_FILE" 2>&1
    log "Fail2ban: бан после 5 попыток за 10 минут на 1 час"
}

configure_nginx_security() {
    section "🔒 Безопасность Nginx"
    cat > /etc/nginx/conf.d/security.conf << 'EOF'
server_tokens off;
client_max_body_size 10M;
client_body_timeout   12;
client_header_timeout 12;
keepalive_timeout     15;
send_timeout          10;
limit_req_zone $binary_remote_addr zone=general:10m rate=30r/m;
add_header X-Frame-Options           "SAMEORIGIN"                      always;
add_header X-XSS-Protection          "1; mode=block"                   always;
add_header X-Content-Type-Options    "nosniff"                         always;
add_header Referrer-Policy           "strict-origin-when-cross-origin" always;
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
EOF
    nginx -t >> "$LOG_FILE" 2>&1 && systemctl reload nginx >> "$LOG_FILE" 2>&1
    log "Заголовки безопасности применены"
}

enable_auto_updates() {
    section "🔄 Авто-обновления"
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
    log "Патчи безопасности — автоматически"
}

setup_ssl_renewal() {
    section "🔐 Авто-обновление SSL"
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --nginx && systemctl reload nginx") \
        | sort -u | crontab -
    log "Cron: обновление SSL каждый день в 03:00"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  УПРАВЛЕНИЕ САЙТАМИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
create_site() {
    section "🌍 Создание нового сайта"
    set +e

    read -rp "$(echo -e "  ${CYAN}Домен (например: example.com):${RESET} ")" DOMAIN
    if [[ -z "$DOMAIN" ]]; then info "Отменено."; set -e; return; fi

    spacer
    echo -e "  ${BOLD}🔧 Настройка config.js${RESET}"
    echo -e "  ${DIM}Файл будет лежать рядом с index.html в /var/www/$DOMAIN/html/config.js${RESET}"
    spacer

    read -rp "$(echo -e "  ${CYAN}Ссылка на Telegram-бота VPN (Enter = пропустить):${RESET} ")" CFG_BOT_LINK
    [[ -z "$CFG_BOT_LINK" ]] && CFG_BOT_LINK="https://t.me/MyVPN_bot"

    read -rp "$(echo -e "  ${CYAN}Ссылка на поддержку Telegram (Enter = пропустить):${RESET} ")" CFG_SUPPORT_LINK
    [[ -z "$CFG_SUPPORT_LINK" ]] && CFG_SUPPORT_LINK="https://t.me/MySupport"

    SITE_DIR="$WEB_ROOT/$DOMAIN/html"
    mkdir -p "$SITE_DIR"

    # ── Скачиваем index.html с GitHub ───────────────────────────
    step "Скачиваю index.html с GitHub..."
    if [[ -f "/var/www/_github_cache/index.html" ]]; then
        cp "/var/www/_github_cache/index.html" "$SITE_DIR/index.html"
        log "index.html взят из кэша"
    elif curl -fsSL "$GITHUB_RAW/index.html" -o "$SITE_DIR/index.html"; then
        log "index.html скачан с GitHub"
    else
        warn "Не удалось скачать index.html — создаю заглушку"
        cat > "$SITE_DIR/index.html" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>$DOMAIN</title>
<script src="config.js"></script></head>
<body><h1>$DOMAIN</h1><p>Загрузи свой index.html</p></body></html>
HTMLEOF
    fi

    # ── Создаём config.js рядом с index.html ────────────────────
    step "Создаю config.js..."
    local _cfg_tmp
    _cfg_tmp=$(mktemp)

    if [[ -f "/var/www/_github_cache/config.js" ]]; then
        cp "/var/www/_github_cache/config.js" "$_cfg_tmp"
        log "config.js взят из кэша"
    elif curl -fsSL "$GITHUB_RAW/config.js" -o "$_cfg_tmp"; then
        log "config.js скачан с GitHub"
    else
        warn "config.js не скачан — создаю шаблон"
        cat > "$_cfg_tmp" << 'CFGTPL'
const CFG = {
  botLink: "PLACEHOLDER_BOT", supportLink: "PLACEHOLDER_SUP",
  mtproto: [{name:"ПРОКСИ RU-1",tag:"ОСНОВНОЙ",addr:"proxy.example.com:443",
    link:"tg://proxy?server=proxy.example.com&port=443&secret=SECRET",desc:"Москва"}],
  socks5: [{name:"SOCKS5 RU-1",tag:"РОССИЯ",ip:"1.2.3.4",port:"1080",
    login:"user",pass:"password",desc:"Москва"}],
  t:{navPill:"// MTProto · SOCKS5 · VLESS · VPN",heroBadge:"СЕТЬ АКТИВНА",
    heroLine1:"TELEGRAM",heroLine2:"РАЗБЛОКИРОВАН",heroLine3:"В 2 КЛИКА И БЕСПЛАТНО",
    heroSub:"Бесплатный прокси для Telegram.",
    ex1title:"MTProto прокси",ex1desc:"Один клик — Telegram работает.",
    ex2title:"SOCKS5 прокси",ex2desc:"Для Telegram и браузера.",
    ex3title:"VPN",ex3desc:"Шифрует весь трафик.",
    proxyBlockTitle:"ВЫБЕРИ ПРОКСИ",proxyBlockSub:"БЕСПЛАТНО",
    proxyNote:"Если не работает — попробуй другой.",
    howTitle:"Как работает прокси",howDesc:"Обходит блокировки РКН.",
    step1t:"Без прокси",step1d:"Telegram заблокирован.",
    step2t:"С прокси",step2d:"Трафик через незаблокированный сервер.",
    step3t:"Безопасно?",step3d:"Прокси не видит переписку.",
    cmpTitle:"Прокси или VPN?",cmpDesc:"Только Telegram — прокси. Всё — VPN.",
    plansTitle:"VPN VLESS",plansDesc:"Необнаруживаемый протокол.",
    ctaTitle:"Начни за 10 секунд",ctaDesc:"Прокси бесплатно.",
    footerCopy:"© 2025 HIDEYOU"}
};
CFGTPL
    fi

    # Подставляем ссылки через python3
    python3 - "$_cfg_tmp" "$CFG_BOT_LINK" "$CFG_SUPPORT_LINK" "$DOMAIN" << 'PYEOF'
import sys
path, bot, sup, domain = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path) as f: c = f.read()
for old, new in [
    ('PLACEHOLDER_BOT', bot), ('PLACEHOLDER_SUP', sup),
    ('https://t.me/MyVPN_bot', bot), ('https://t.me/MySupport', sup),
    ('© 2025 HIDEYOU', f'© 2025 {domain}'),
]:
    c = c.replace(old, new)
with open(path, 'w') as f: f.write(c)
PYEOF

    cp "$_cfg_tmp" "$SITE_DIR/config.js"
    rm -f "$_cfg_tmp"

    # Права
    chown -R www-data:www-data "$WEB_ROOT/$DOMAIN"
    chmod -R 755 "$WEB_ROOT/$DOMAIN"

    # ── Nginx конфиг ────────────────────────────────────────────
    cat > "$NGINX_SITES/$DOMAIN" << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $SITE_DIR;
    index index.html;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log  /var/log/nginx/${DOMAIN}_error.log;

    limit_req zone=general burst=20 nodelay;
    autoindex off;
    ssi on;
    ssi_silent_errors on;

    location ~ /\. { deny all; return 404; }
    location ~* \.(env|log|conf|bak|sql|sh|git)$ { deny all; return 404; }

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

    set -e
    spacer
    log "Сайт ${BOLD}$DOMAIN${RESET} создан! ✅"
    spacer
    echo -e "  📁 ${BOLD}Файлы сайта:${RESET}"
    echo -e "     ${GREEN}$SITE_DIR/index.html${RESET}"
    echo -e "     ${GREEN}$SITE_DIR/config.js${RESET}  ← редактируй здесь"
    spacer
    echo -e "  📤 ${BOLD}Обновить config.js:${RESET}"
    echo -e "     ${DIM}scp config.js root@IP:$SITE_DIR/config.js${RESET}"
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
    log "SSL настроен 🔐"
}

delete_site() {
    section "🗑️  Удаление сайта"
    set +e
    list_sites

    spacer
    read -rp "$(echo -e "  ${CYAN}Домен для удаления:${RESET} ")" DOMAIN
    if [[ -z "$DOMAIN" ]]; then info "Отменено."; set -e; return; fi

    spacer
    warn "Это удалит ${BOLD}$DOMAIN${RESET} и все файлы навсегда!"
    read -rp "$(echo -e "  ${RED}Введи «yes» для подтверждения:${RESET} ")" CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then info "Отменено."; set -e; return; fi

    spacer
    rm -f "$NGINX_ENABLED/$DOMAIN"  && log "Симлинк удалён"       || warn "Симлинк не найден"
    rm -f "$NGINX_SITES/$DOMAIN"    && log "Конфиг Nginx удалён"  || warn "Конфиг не найден"
    rm -rf "${WEB_ROOT:?}/$DOMAIN"  && log "Файлы сайта удалены"  || warn "Файлы не найдены"

    if certbot delete --cert-name "$DOMAIN" --non-interactive >> "$LOG_FILE" 2>&1; then
        log "SSL-сертификат удалён"
    else
        warn "SSL-сертификат не найден"
    fi

    if nginx -t >> "$LOG_FILE" 2>&1 && systemctl reload nginx >> "$LOG_FILE" 2>&1; then
        log "Nginx перезагружен"
    else
        error "Ошибка Nginx — проверь: nginx -t"
    fi

    spacer
    log "Сайт ${BOLD}$DOMAIN${RESET} удалён ✅"
    set -e
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
        info "Нет настроенных сайтов."
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
    local ram disk cpu uptime_str
    cpu=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "?")
    ram=$(free -h | awk '/^Mem:/{print $3 " / " $2}')
    disk=$(df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}')
    uptime_str=$(uptime -p)
    echo -e "  🖥️  CPU:    ${GREEN}${cpu}%${RESET}"
    echo -e "  🧠 RAM:    ${GREEN}${ram}${RESET}"
    echo -e "  💾 Диск:   ${GREEN}${disk}${RESET}"
    echo -e "  ⏱️  Аптайм: ${GREEN}${uptime_str}${RESET}"
    spacer; line
    echo -e "  ${BOLD}🔐 SSL-сертификаты:${RESET}"
    certbot certificates 2>/dev/null | grep -E "Domains:|Expiry Date:" | sed 's/^/     /' \
        || echo -e "     ${DIM}Нет сертификатов${RESET}"
    spacer
}

restart_all_services() {
    section "♻️  Перезапуск сервисов"
    for svc in nginx fail2ban ufw; do
        if systemctl restart "$svc" >> "$LOG_FILE" 2>&1; then
            log "$svc перезапущен"
        else
            error "$svc — ошибка"
        fi
    done
}

stop_all_services() {
    section "⏹️  Остановка сервисов"
    warn "Nginx будет остановлен — сайты станут недоступны!"
    read -rp "$(echo -e "  ${YELLOW}Продолжить? (y/n):${RESET} ")" CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { info "Отменено."; return; }
    for svc in nginx fail2ban; do
        systemctl stop "$svc" >> "$LOG_FILE" 2>&1 && warn "$svc остановлен" || error "$svc — ошибка"
    done
}

start_all_services() {
    section "▶️  Запуск сервисов"
    for svc in nginx fail2ban ufw; do
        systemctl start "$svc" >> "$LOG_FILE" 2>&1 && log "$svc запущен" || error "$svc — ошибка"
    done
}

nginx_control() {
    section "🌐 Управление Nginx"
    echo -e "  ${CYAN}1)${RESET} ▶️  Запустить"
    echo -e "  ${CYAN}2)${RESET} ⏹️  Остановить"
    echo -e "  ${CYAN}3)${RESET} ♻️  Перезапустить"
    echo -e "  ${CYAN}4)${RESET} 🔄 Перезагрузить конфиг (без простоя)"
    echo -e "  ${CYAN}5)${RESET} ✅ Проверить конфиг"
    echo -e "  ${RED}0)${RESET} ↩️  Назад"
    spacer
    read -rp "$(echo -e "  ${YELLOW}Выбор:${RESET} ")" OPT
    case "$OPT" in
        1) systemctl start   nginx >> "$LOG_FILE" 2>&1 && log "Nginx запущен" ;;
        2) systemctl stop    nginx >> "$LOG_FILE" 2>&1 && warn "Nginx остановлен" ;;
        3) systemctl restart nginx >> "$LOG_FILE" 2>&1 && log "Nginx перезапущен" ;;
        4) nginx -t && systemctl reload nginx >> "$LOG_FILE" 2>&1 && log "Конфиг перезагружен" ;;
        5) nginx -t && log "Конфиг корректен ✅" ;;
        0) return ;;
        *) error "Неверный выбор." ;;
    esac
}

view_logs() {
    section "📋 Просмотр логов"
    echo -e "  ${CYAN}1)${RESET} Nginx — access log"
    echo -e "  ${CYAN}2)${RESET} Nginx — error log"
    echo -e "  ${CYAN}3)${RESET} Fail2ban log"
    echo -e "  ${CYAN}4)${RESET} Лог webm"
    echo -e "  ${CYAN}5)${RESET} Live (Ctrl+C для выхода)"
    echo -e "  ${RED}0)${RESET} Назад"
    spacer
    read -rp "$(echo -e "  ${YELLOW}Выбор:${RESET} ")" OPT
    spacer
    case "$OPT" in
        1) tail -50 /var/log/nginx/access.log 2>/dev/null | sed 's/^/  /' ;;
        2) tail -50 /var/log/nginx/error.log  2>/dev/null | sed 's/^/  /' ;;
        3) tail -50 /var/log/fail2ban.log     2>/dev/null | sed 's/^/  /' ;;
        4) tail -50 "$LOG_FILE"               2>/dev/null | sed 's/^/  /' ;;
        5) tail -f /var/log/nginx/access.log ;;
        0) return ;;
    esac
    press_enter
}

security_report() {
    section "🛡️  Отчёт безопасности"
    echo -e "  ${BOLD}🚫 Заблокированные IP:${RESET}"
    fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:\s*//' | tr ',' '\n' | while read -r jail; do
        jail=$(echo "$jail" | xargs)
        [[ -z "$jail" ]] && continue
        local banned
        banned=$(fail2ban-client status "$jail" 2>/dev/null | grep "Banned IP" | awk -F: '{print $2}' | xargs)
        [[ -n "$banned" ]] && echo -e "     ${RED}$jail:${RESET} $banned" || echo -e "     ${DIM}$jail: нет банов${RESET}"
    done
    spacer; line
    echo -e "  ${BOLD}🔐 Срок SSL:${RESET}"
    certbot certificates 2>/dev/null | grep -E "Domains:|Expiry Date:" | sed 's/^/     /' \
        || echo -e "     ${DIM}Нет сертификатов${RESET}"
    spacer
    press_enter
}

renew_ssl_manual() {
    section "🔐 Обновление SSL"
    certbot renew --nginx 2>&1 | tee -a "$LOG_FILE" | sed 's/^/  /'
    systemctl reload nginx >> "$LOG_FILE" 2>&1
    log "SSL проверен / обновлён"
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
  ║   Nginx · SSL · UFW · Fail2ban                              ║
  ╚══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${RESET}"
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

    self_install

    # Кэш файлов с GitHub
    section "🐙 Загрузка файлов с GitHub"
    mkdir -p /var/www/_github_cache
    github_pull "index.html" "/var/www/_github_cache/index.html" || true
    github_pull "config.js"  "/var/www/_github_cache/config.js"  || true

    clear
    echo -e "${BOLD}${GREEN}"
    cat << 'DONE'
  ╔══════════════════════════════════════════════════════════════╗
  ║   ✅  УСТАНОВКА ЗАВЕРШЕНА!                                   ║
  ╚══════════════════════════════════════════════════════════════╝
DONE
    echo -e "${RESET}"
    echo -e "  ${GREEN}🌐 Nginx${RESET}        — запущен"
    echo -e "  ${GREEN}🔥 UFW${RESET}          — 22, 80, 443 открыты"
    echo -e "  ${GREEN}🛡️  Fail2ban${RESET}     — защита SSH и Nginx"
    echo -e "  ${GREEN}🔄 Авто-патчи${RESET}   — активны"
    echo -e "  ${GREEN}🔐 SSL renewal${RESET}  — каждый день в 03:00"
    spacer; line; spacer
    echo -e "  ${BOLD}📁 СЛЕДУЮЩИЙ ШАГ:${RESET}"
    echo -e "  ${CYAN}1)${RESET} sudo webm"
    echo -e "  ${CYAN}2)${RESET} 3) Создать новый сайт"
    spacer
    echo -e "  ${BOLD}${MAGENTA}✨ Управление: sudo webm${RESET}"
    spacer
    press_enter
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  МЕНЮ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    cat << 'BANNER'
  ╔══════════════════════════════════════════════════════════════╗
  ║   🌐  WEB SERVER MANAGER  v4.0                              ║
  ║   Nginx · SSL · UFW · Fail2ban                              ║
  ╚══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${RESET}"
    local ng_st fb_st
    ng_st=$(systemctl is-active nginx    2>/dev/null || echo "inactive")
    fb_st=$(systemctl is-active fail2ban 2>/dev/null || echo "inactive")
    [[ "$ng_st" == "active" ]] && ng_dot="${GREEN}●${RESET}" || ng_dot="${RED}●${RESET}"
    [[ "$fb_st" == "active" ]] && fb_dot="${GREEN}●${RESET}" || fb_dot="${RED}●${RESET}"
    echo -e "  🌐 Nginx $ng_dot   🛡️  Fail2ban $fb_dot   🕐 $(date '+%H:%M  %d.%m.%Y')"
    line; spacer
}

main_menu() {
    while true; do
        show_banner
        echo -e "  ${DIM}${BOLD}── 🔧 УСТАНОВКА ─────────────────────────────────${RESET}"
        echo -e "  ${GREEN}1)${RESET}  🚀  Полная установка"
        echo -e "  ${GREEN}2)${RESET}  🔁  Переустановить webm"
        spacer
        echo -e "  ${DIM}${BOLD}── 🌍 САЙТЫ ─────────────────────────────────────${RESET}"
        echo -e "  ${CYAN}3)${RESET}  ➕  Создать новый сайт"
        echo -e "  ${CYAN}4)${RESET}  📋  Список сайтов"
        echo -e "  ${CYAN}5)${RESET}  🗑️   Удалить сайт"
        spacer
        echo -e "  ${DIM}${BOLD}── 🔐 SSL ───────────────────────────────────────${RESET}"
        echo -e "  ${CYAN}6)${RESET}  🔐  Выпустить SSL"
        echo -e "  ${CYAN}7)${RESET}  🔄  Обновить SSL вручную"
        spacer
        echo -e "  ${DIM}${BOLD}── ⚙️  СЕРВИСЫ ───────────────────────────────────${RESET}"
        echo -e "  ${CYAN}8)${RESET}  📊  Статус сервера"
        echo -e "  ${CYAN}9)${RESET}  ▶️   Запустить все"
        echo -e "  ${CYAN}10)${RESET} ⏹️   Остановить все"
        echo -e "  ${CYAN}11)${RESET} ♻️   Перезапустить все"
        echo -e "  ${CYAN}12)${RESET} 🌐  Управление Nginx"
        spacer
        echo -e "  ${DIM}${BOLD}── 🔍 МОНИТОРИНГ ────────────────────────────────${RESET}"
        echo -e "  ${CYAN}13)${RESET} 📋  Логи"
        echo -e "  ${CYAN}14)${RESET} 🛡️   Отчёт безопасности"
        spacer
        echo -e "  ${RED}0)${RESET}  👋  Выход"
        spacer; line

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
                echo -e "  👋 ${GREEN}${BOLD}До встречи!${RESET}"
                spacer
                exit 0
                ;;
            *) error "Неверный выбор."; sleep 1 ;;
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
        echo -e "  ${BOLD}🌐 Web Server Manager v4.0${RESET}"
        spacer
        echo -e "  ${CYAN}(без аргументов)${RESET}   Меню"
        echo -e "  ${CYAN}--install${RESET}          Полная установка"
        echo -e "  ${CYAN}--status${RESET}           Статус"
        echo -e "  ${CYAN}--restart${RESET}          Перезапустить"
        echo -e "  ${CYAN}--renew-ssl${RESET}        Обновить SSL"
        spacer
        ;;
    *)
        require_root
        main_menu
        ;;
esac
