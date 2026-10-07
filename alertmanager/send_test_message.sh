#!/usr/bin/env bash
# Тестовая отправка сообщения в Telegram через бот Alertmanager.
#
# Работает напрямую через Bot API, без Alertmanager: проверяет токен,
# chat_id, message_thread_id и HTML-разметку шаблона уведомлений.
#
# Использование:
#   ./send_test_message.sh                 # шаблонное сообщение об алерте
#   ./send_test_message.sh plain           # короткий текст без разметки
#   ./send_test_message.sh alert <name>    # своё имя устройства
#   ./send_test_message.sh text "привет"  # произвольный текст
#
# Настройки берутся из .env в корне репозитория (TELEGRAM_BOT_TOKEN,
# TELEGRAM_CHAT_ID и, для групп с форумами, TELEGRAM_MESSAGE_THREAD_ID).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Не найден $ENV_FILE. Создайте из шаблона: cp .env.example .env" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "В $ENV_FILE должны быть TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID" >&2
    exit 1
fi

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
COMMON=(--data-urlencode "chat_id=${TELEGRAM_CHAT_ID}")

# message_thread_id поддерживается только в группах с форумами.
if [[ -n "${TELEGRAM_MESSAGE_THREAD_ID:-}" ]]; then
    COMMON+=(--data-urlencode "message_thread_id=${TELEGRAM_MESSAGE_THREAD_ID}")
fi

send() { # send <parse_mode> <text>
    local parse_mode="$1" text="$2"
    curl -s -X POST "$API" \
        "${COMMON[@]}" \
        --data-urlencode "parse_mode=${parse_mode}" \
        --data-urlencode "text=${text}"
}

report() { # report <ответ API>
    python3 -c '
import json, sys
data = json.load(sys.stdin)
if not data.get("ok"):
    print("Ошибка Telegram API:", data.get("description"), file=sys.stderr)
    sys.exit(1)
msg = data["result"]
chat = msg.get("chat", {})
print("Отправлено: message_id=%s | chat=%s (%s) | thread=%s" % (
    msg.get("message_id"),
    chat.get("title") or chat.get("username") or chat.get("id"),
    chat.get("type"),
    msg.get("message_thread_id", "—"),
))
' <<<"$1"
}

MODE="${1:-alert}"
NAME="${2:-Router-1}"

case "$MODE" in
    plain)
        report "$(send HTML "✅ Тест: бот на связи.
📌 Проверка отправки в $([[ -n "${TELEGRAM_MESSAGE_THREAD_ID:-}" ]] && echo "топик ${TELEGRAM_MESSAGE_THREAD_ID}" || echo "General").")"
        ;;
    text)
        if [[ $# -lt 2 ]]; then
            echo "Использование: $0 text \"ваш текст\"" >&2
            exit 1
        fi
        report "$(send HTML "$2")"
        ;;
    alert)
        report "$(send HTML "🚨 <b>MikroTikUnreachable</b>
🖥 Устройство: <b>${NAME}</b>
📍 Адрес: 10.54.1.254
🖧 Instance: mktxp:49090
📊 Job: mktxp
🔴 Severity: critical
📌 Не отвечает на ping
📝 ICMP-ответ отсутствует дольше минуты — устройство выключено или потеряна связь.
⏱ Начало: $(TZ=Asia/Novosibirsk date '+%Y-%m-%d %H:%M:%S %Z')
🔗 <a href=\"http://localhost:9090/graph\">Открыть в Prometheus</a>")"
        ;;
    *)
        echo "Неизвестный режим: $MODE (доступны: alert, plain, text)" >&2
        exit 1
        ;;
esac
