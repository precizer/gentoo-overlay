# Gentoo repository for Precizer

[English translation](README.md)

Этот репозиторий является внешним ebuild-репозиторием Gentoo для установки Precizer через Portage

Precizer — лёгкая и быстрая консольная программа на C для проверки целостности и сравнения файлов. Она обходит деревья каталогов, вычисляет SHA512-контрольные суммы и сохраняет результаты в SQLite-базу данных. Базы данных можно сравнивать между собой, чтобы находить отсутствующие файлы и файлы с различающимся содержимым

Инструмент полезен для проверки результатов синхронизации, резервного копирования и сценариев аварийного восстановления. Precizer не изменяет, не удаляет и не перемещает проверяемые файлы. Все рабочие данные записываются только в базу Precizer

## Подключение

Для выполнения команд требуются права `root`

```sh
emerge --ask --noreplace dev-vcs/git
install -d /etc/portage/repos.conf
cat >/etc/portage/repos.conf/precizer.conf <<'EOF'
[precizer]
location = /var/db/repos/precizer
sync-type = git
sync-uri = https://github.com/precizer/gentoo-overlay.git
auto-sync = yes
EOF
emaint sync --repo precizer
```

## Установка Precizer

Установка Precizer и проверка доступности команды выполняются следующим образом

```sh
emerge --ask app-forensics/precizer
precizer --version
```

## Обновление Precizer

Сначала синхронизируется оверлей

```sh
emaint sync --repo precizer
```

Затем пакет обновляется обычным способом

```sh
emerge --ask --update app-forensics/precizer
```

`emerge --sync` также синхронизирует этот репозиторий, поскольку для него включён параметр `auto-sync = yes`

## Удаление Precizer

Удаление Precizer через Portage выполняется следующей командой

```sh
emerge --ask --depclean app-forensics/precizer
```

## Отключение оверлея

После удаления Precizer конфигурация и локальная копия оверлея удаляются следующим образом

```sh
rm -f /etc/portage/repos.conf/precizer.conf
rm -rf /var/db/repos/precizer
```

## Внесение изменений в оверлей

Добавление новых версий Precizer, обновление `Manifest` и проверка ebuild описаны в [руководстве для разработчиков](CONTRIBUTING.ru.md)

## Ссылки

- Основной проект: https://github.com/precizer/precizer
- Сайт проекта: https://precizer.github.io/
- Ошибки и предложения: https://github.com/precizer/precizer/issues
