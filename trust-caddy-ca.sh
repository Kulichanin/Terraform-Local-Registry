#!/bin/bash

# Путь к корневому сертификату Caddy (согласно README и структуре проекта)
CERT_PATH="./infra/caddy-data/caddy/pki/authorities/local/root.crt"

if [ ! -f "$CERT_PATH" ]; then
    echo "Ошибка: Файл сертификата не найден по пути $CERT_PATH"
    echo "Убедись, что контейнер Caddy запущен и тома примонтированы."
    exit 1
fi

# Определение типа ОС
if [ -f /etc/debian_version ]; then
    OS_TYPE="debian"
elif [ -f /etc/redhat-release ]; then
    OS_TYPE="rpm"
else
    echo "Неподдерживаемая ОС для автоматической установки."
    exit 1
fi

echo "Обнаружена система: $OS_TYPE. Добавляем сертификат..."

if [ "$OS_TYPE" == "debian" ]; then
    sudo cp "$CERT_PATH" /usr/local/share/ca-certificates/caddy-internal-ca.crt
    sudo update-ca-certificates
else
    sudo cp "$CERT_PATH" /etc/pki/ca-trust/source/anchors/caddy-internal-ca.crt
    sudo update-ca-trust
fi

echo "Сертификат успешно добавлен."
