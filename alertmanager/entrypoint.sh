#!/bin/sh
set -e

sed \
  -e "s|\${TELEGRAM_BOT_TOKEN}|${TELEGRAM_BOT_TOKEN}|g" \
  -e "s|\${TELEGRAM_CHAT_ID}|${TELEGRAM_CHAT_ID}|g" \
  -e "s|\${TELEGRAM_MESSAGE_THREAD_ID}|${TELEGRAM_MESSAGE_THREAD_ID}|g" \
  /etc/alertmanager/alertmanager.yml.tmpl > /alertmanager/alertmanager.yml

exec alertmanager "$@"
