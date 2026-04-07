# Terraform local registry

## Локальное размещение провайдера

### Предварительная сборка и размещение провайдера

Скачиваем провайдер.

```bash
wget https://github.com/hashicorp/terraform-provider-local/archive/refs/tags/v2.8.0.zip
unzip v2.8.0.zip && cd terraform-provider-local-2.8.0
```

Создание структуры папок (Plugins Directory)

```bash
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/local/2.8.0/linux_amd64/
```

Собираем их исходников провайдер.

```bash
GOOS=linux GOARCH=amd64 go build -v
```

Terraform очень внимательно следит за каталогами. Он ищет провайдеров в строго определенных путях. Нам нужно имитировать структуру официального реестра. Для работы через `filesystem_mirror` структура внутри path должна выглядеть так: **{path}/{hostname}/{namespace}/{type}/{version}/{os}_{arch}/...**. В нашем случае структура: **<ПУТЬ>/registry.terraform.io/hashicorp/local/<ВЕРСИЯ>/<ОС_АРХИТЕКТУРА>/**

Теперь переместим туда собранный файл с помощью `install`(install -D копирует файл и создаёт необходимые каталоги).

```bash
install -D terraform-provider-local ~/.terraform.d/plugins/registry.terraform.io/hashicorp/local/2.8.0/linux_amd64/terraform-provider-local
```

### Конфигурация terraform

Создайте (или отредактируйте) файл `.terraformrc` в домашнем каталоге (`~/.terraformrc` для Linux/Mac или `%APPDATA%\terraform.rc` для Windows). [Подробнее про CLI конфигурацию](https://developer.hashicorp.com/terraform/cli/config/config-file).

```rc
provider_installation {
  # Terraform будет сначала искать провайдер в локальной папке.
  filesystem_mirror {
    path    = "/home/mda/.terraform.d/plugins" 
    include = ["hashicorp/local"]
  }

  # Прямой доступ к официальному реестру для всего остального (если не найдет нужное)
  direct {
    exclude = ["hashicorp/local"]
  }
}
```

Теперь можем вернуться к своему манифесту с local_file и запусти инициализацию

```bash
TF_LOG=DEBUG terraform init
```

## Nexus

Nexus написан на Java. [Требования](https://help.sonatype.com/en/sonatype-nexus-repository-system-requirements.html) к ресурсам. Минимальное значение [ОЗУ](https://help.sonatype.com/en/nexus-repository-memory-overview.html) Основные параметры конфигурации:

```bash
-Xms1500m: Устанавливает начальный размер ОЗУ при запуске приложения.
-Xmx1500m: Устанавливает максимальный предел ОЗУ, который JVM может занять у операционной системы.
-XX:MaxDirectMemorySize=1500m: Максимальный размер использования ОЗУ.
```

На данный момент версия образа `sonatype/nexus3:3.90.0` нестабильна и падает с ошибкой.

## Запуск окружения для стенда

```bash
docker compose up -d
```

Остановить окружения и удалить volume

```bash
docker compose down
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
│ Cannot use "http://localhost/repository/terraform-hosted" as a URL for
│ a network provider mirror: the mirror must be at an https: URL.
╵
```

В зависимости от типа Linux, действия будут отличаться. Для автоматизации добавления сертификата подготовлен скрипт - **trust-caddy-ca.sh**.

Для работы не забыть выдать права

```bash
chmod u+x trust-caddy-ca.sh
```

Логика добавления сертификата такая:

Копируем самоподписной сертификат в системную папку. В зависимости от типа Linux, действия будут отличаться.

Для Deb (Debian / Ubuntu / Astra Linux). Копируем файл в каталог `/usr/local/share/ca-certificates`:

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

Перед началом работы необходимо получить пароль от админа

```bash
docker exec -it nexus cat /nexus-data/admin.password
```

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
zip terraform-provider-local_2.8.0_linux_amd64.zip terraform-provider-local LICENSE
```

Загрузка архива с помощью **curl**

```bash
curl -X PUT \
  'https://localhost/repository/rebrain/v1/providers/hashicorp/local/2.8.0/download/linux/amd64' \
  -u 'user:pass' \
  -H 'Content-Type: application/zip' \
  -H 'Content-Disposition: attachment; filename="terraform-provider-local_2.8.0_linux_amd64.zip"' \
  --data-binary '@terraform-provider-local_2.8.0_linux_amd64.zip'
```

Теперь, когда приватный terraform registry подготовлен, необходимо авторизоваться в нём.

К сожалению, Nexus не поддерживает `terraform login localhost`:

```bash
╷
│ Error: Host does not support Terraform tokens API
│ 
│ The given hostname "localhost" does not support creating Terraform authorization tokens.
╵
```

Перед тем как настроить наш новый провайдер для terraform, нужно активировать [Terraform Token Realm](https://help.sonatype.com/en/realms.html). Поэтому необходимо добавить авторизацию в настройки **~/.terraformrc** вместе с указанием URL для провайдеров:

```conf
host "registry.terraform.io" {
  services = {
    "providers.v1" = "https://localhost/repository/rebrain/v1/providers/<USER_TOKEN>/"
  }
}
```

<USER_TOKEN> - Представление в формате base64 либо токена пользователя Nexus, либо имени пользователя:пароля.

```bash
echo -n 'username:password' | base64
```

Полезные ссылки:

- [terraform-repositories](https://help.sonatype.com/en/terraform-repositories.html#terraform-repositories)
- [Подробнее про CLI конфигурацию](https://developer.hashicorp.com/terraform/cli/config/config-file)
- [Provider Network Mirror Protocol Reference](https://developer.hashicorp.com/terraform/internals/provider-network-mirror-protocol)
