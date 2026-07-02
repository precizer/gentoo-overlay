# Gentoo repository for Precizer

[English translation](README.md)

Этот репозиторий является внешним ebuild-репозиторием Gentoo для установки Precizer через Portage

Precizer — лёгкая и быстрая консольная программа на C для проверки целостности и сравнения файлов. Она обходит деревья каталогов, вычисляет SHA512-контрольные суммы и сохраняет результаты в SQLite-базу данных. Базы данных можно сравнивать между собой, чтобы находить отсутствующие файлы и файлы с различающимся содержимым

Инструмент полезен для проверки результатов синхронизации, резервного копирования и сценариев аварийного восстановления. Precizer не изменяет, не удаляет и не перемещает проверяемые файлы. Все рабочие данные записываются только в базу Precizer

## Подключение

Выполняйте команды от имени `root`

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

## Установка

```sh
emerge --ask app-forensics/precizer
precizer --version
```

## Обновление

Для обновления только этого репозитория используйте

```sh
emaint sync --repo precizer
```

После синхронизации обновите пакет обычным способом

```sh
emerge --ask --update app-forensics/precizer
```

`emerge --sync` также будет синхронизировать этот репозиторий, потому что для него включён `auto-sync = yes`

## Отключение

```sh
emerge --ask --depclean app-forensics/precizer
rm -f /etc/portage/repos.conf/precizer.conf
rm -rf /var/db/repos/precizer
```

## Структура репозитория

```text
app-forensics/precizer/
metadata/
profiles/
```

`app-forensics/precizer/` содержит ebuild и metadata пакета. `metadata/layout.conf` сообщает Portage, что этот overlay наследует основной репозиторий Gentoo. `profiles/repo_name` задаёт имя репозитория `precizer`

## Ссылки

- Основной проект: https://github.com/precizer/precizer
- Сайт проекта: https://precizer.github.io/
- Ошибки и предложения: https://github.com/precizer/precizer/issues
