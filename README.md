# Terraform local registry

## Nexus

Nexus пишет данные в папку `/nexus-data` внутри контейнера. Чтобы данные не пропали после перезагрузки, их нужно вынести на хост-машину. Для этого необходимо подготовить каталог для хранения данных. Nexus внутри контейнера работает под пользователем с UID 200.

```bash
mkdir nexus-data && sudo chown -R 200 nexus-data
```

Nexus написан на Java. [Требования](https://help.sonatype.com/en/sonatype-nexus-repository-system-requirements.html) к ресурсам. Минимальное значение [ОЗУ](https://help.sonatype.com/en/nexus-repository-memory-overview.html) Основные параметры конфигурации:

```bash
-Xms1g: Устанавливает начальный размер ОЗУ при запуске приложения.
-Xmx1g: Устанавливает максимальный предел ОЗУ, который JVM может занять у операционной системы.
-XX:MaxDirectMemorySize=1g: Максимальный размер использования ОЗУ.
```

## Запуск окружения для стенда

```bash
docker compose up -d --force-recreate
```

Остановить окружения и удалить volume

```bash
docker compose down -v
```
