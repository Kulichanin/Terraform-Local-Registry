# Terraform local registry

## Локальное размещение провайдера

### Предварительная сборка и размещение провайдера

Скачиваем провайдер. Если нужно собираем провайдер из исходников через команду `go build`

```bash
wget https://github.com/hashicorp/terraform-provider-local/archive/refs/tags/v2.7.0.zip
unzip v2.7.0.zip
cd terraform-provider-local-2.7.0
```

Создание структуры папок (Plugins Directory)

```bash
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/local/2.7.0/linux_amd64/
```

Terraform очень внимательно следит за каталогами. Он ищет провайдеров в строго определенных путях. Нам нужно имитировать структуру официального реестра. Структура: <ПУТЬ>/registry.terraform.io/hashicorp/local/<ВЕРСИЯ>/<ОС_АРХИТЕКТУРА>/

Теперь перемести туда собранный файл

```bash
cp terraform-provider-local ~/.terraform.d/plugins/registry.terraform.io/hashicorp/local/2.7.0/linux_amd64/
```

### Конфигурация terraform

Создайте (или отредактируйте) файл .terraformrc в домашнем каталоге (`~/.terraformrc` для Linux/Mac или `%APPDATA%\terraform.rc` для Windows). [Подробнее про CLI конфигурацию](https://developer.hashicorp.com/terraform/cli/config/config-file).

```rc
provider_installation {
  # Это заставляет Terraform искать провайдеров сначала в локальной папке
  filesystem_mirror {
    path    = "/home/mda/.terraform.d/plugins" # Замени 'mda' на своего юзера
    include = ["hashicorp/local"]
  }

  # Прямой доступ к официальному реестру для всего остального (если нужно)
  direct {
    exclude = ["hashicorp/local"]
  }
}
```

Теперь можем вернуться к своему манифесту с local_file и запусти инициализацию

```bash
terraform init
```

## Nexus

Nexus пишет данные в папку `/nexus-data` внутри контейнера. Чтобы данные не пропали после перезагрузки, их нужно вынести на хост-машину. Для этого необходимо подготовить каталог для хранения данных. Nexus внутри контейнера работает под пользователем с UID 200.

```bash
mkdir nexus-data && sudo chown -R 200 nexus-data
```

Nexus написан на Java. [Требования](https://help.sonatype.com/en/sonatype-nexus-repository-system-requirements.html) к ресурсам. Минимальное значение [ОЗУ](https://help.sonatype.com/en/nexus-repository-memory-overview.html) Основные параметры конфигурации:

```bash
-Xms1500m: Устанавливает начальный размер ОЗУ при запуске приложения.
-Xmx1500m: Устанавливает максимальный предел ОЗУ, который JVM может занять у операционной системы.
-XX:MaxDirectMemorySize=1500m: Максимальный размер использования ОЗУ.
```

На данный момент версия образа sonatype/nexus3:3.90.0 нестабильна и падает с ошибкой.

## Запуск окружения для стенда

```bash
docker compose up -d --force-recreate
```

Остановить окружения и удалить volume

```bash
docker compose down -v
```

Получить пароль от пользователя admin

```bash
docker exec nexus cat /nexus-data/admin.password
```

## Caddy

Начиная с версии 0.13, terraform жестко требует протокол HTTPS для любых сетевых зеркал (network mirrors). Если настроить Nexus без ssl возникнет ошибка.

```bash
There are some problems with the provider_installation configuration:
╷
│ Error: Invalid URL for provider installation source
│
│ Cannot use "http://localhost:8081/repository/terraform-hosted" as a URL for
│ a network provider mirror: the mirror must be at an https: URL.
╵
```

В зависимости от типа Linux, действия будут отличаться.

Копируем самоподписной сертификат в системную папку. В зависимости от типа Linux, действия будут отличаться.

Для Deb (Debian / Ubuntu / Astra Linux). Копируем файл в каталог /usr/local/share/ca-certificates:

```bash
sudo cp ./infra/caddy-data/caddy/pki/authorities/local/root.crt /usr/local/share/ca-certificates/
```

Выполняем обновление:

```bash
sudo update-ca-certificates
```

Для RPM (Fedora / Almalinux). Копируем файл в каталог /etc/pki/ca-trust/source/anchors:

```bash
sudo cp ./infra/caddy-data/caddy/pki/authorities/local/root.crt  /etc/pki/ca-trust/source/anchors/
```

Выполняем обновление:

```bash
sudo update-ca-trust
```

Go по умолчанию ищет SSL-сертификаты (корневые сертификаты CA) в системных путях, зависящих от операционной системы. Go не использует хранилище сертификатов браузеров, а полагается на системные библиотеки `crypto/x509`.

## Настройка Terraform для работы в Nexus

### Создание репозитория в Nexus

Предварительно подготовим GPG ключ для подписи нашего репозитория.

Создание нового ключа.

```bash
gpg --full-generate-key
```

Найти свой новый ключ.

```bash
gpg --list-secret-keys --keyid-format=LONG
```

Экспортируем его закрытую часть.

```bash
gpg --export-secret-key --armor YOUR_KEY_ID
```

Добавление провайдера в Nexus
Перед тем как добавить провайдер его нужно положить в архив. Имя архива должно соответствовать стандарту `{name}_{version}_{os}_{arch}.zip`.

```bash
zip terraform-provider-local_2.7.0_linux_amd64.zip terraform-provider-local 
```

Загрузка архива с помощью curl !TODO

```bash
curl -X PUT \
	'https://localhost/repository/terraform-hosted/v1/providers/hashicorp/local/2.7.0/download/linux/amd64' \
	-u 'admin:nexus' \
	-H 'Content-Type: application/zip' \
	--data-binary '@{terraform-provider-local_2.7.0_linux_amd64}.zip'
```

Настройка репозитория. Исправим ~/.terraformrc

```conf
host "registry.terraform.io" {
  services = {
    "providers.v1" = "https://localhost/repository/terraform-hosted/v1/providers/<USER_TOKEN>/"
  }
}
```

Полезные ссылки

- [terraform-repositories](https://help.sonatype.com/en/terraform-repositories.html#terraform-repositories)
- [Подробнее про CLI конфигурацию](https://developer.hashicorp.com/terraform/cli/config/config-file)
- [Provider Network Mirror Protocol Reference](https://developer.hashicorp.com/terraform/internals/provider-network-mirror-protocol)
