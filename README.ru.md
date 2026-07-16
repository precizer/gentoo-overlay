# Gentoo repository for Precizer

[English translation](README.md)

Этот репозиторий является внешним ebuild-репозиторием Gentoo для установки Precizer через Portage

Precizer — лёгкая и быстрая консольная программа на C для проверки целостности и сравнения файлов. Она обходит деревья каталогов, вычисляет SHA512-контрольные суммы и сохраняет результаты в SQLite-базу данных. Базы данных можно сравнивать между собой, чтобы находить отсутствующие файлы и файлы с различающимся содержимым

Инструмент полезен для проверки результатов синхронизации, резервного копирования и сценариев аварийного восстановления. Precizer не изменяет, не удаляет и не перемещает проверяемые файлы. Все рабочие данные записываются только в базу Precizer

## Подключение

Для выполнения команд требуются права `root`

### Подключение через каталог Gentoo

Оверлей `precizer` зарегистрирован в поддерживаемом Gentoo каталоге сторонних ebuild-репозиториев. Это основной способ подключения

```sh
emerge --ask app-eselect/eselect-repository
eselect repository enable precizer
emaint sync -r precizer
```

Регистрация в каталоге позволяет `eselect repository` получить готовую конфигурацию оверлея без ручного создания локального репозитария

### Альтернативное ручное подключение

В качестве альтернативы оверлей может быть подключён путём ручного создания и дальнейшего обслуживания локального репозитория

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

Для установки Precizer и проверки доступности команды в системе используются следующие команды

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

### Дополнительный запуск тестов

При желании во время обновления можно дополнительно запустить тесты, входящие в состав Precizer. Обычное обновление этого не требует

```sh
USE="test" FEATURES="test" emerge --ask --update app-forensics/precizer
```

В этой команде `USE=test` разрешает тестовую фазу ebuild, а `FEATURES=test` указывает Portage выполнить её во время сборки

## Удаление Precizer

Удаление Precizer через Portage выполняется следующей командой

```sh
emerge --ask --depclean app-forensics/precizer
```

## Отключение и удаление оверлея

### Оверлей, подключённый через каталог Gentoo

Оверлей можно отключить, сохранив загруженные файлы

```sh
eselect repository disable precizer
```

Если загруженная копия больше не нужна, вместо `disable` используется полное удаление

```sh
eselect repository remove precizer
```

### Оверлей, созданный вручную

После удаления Precizer можно удалить созданные вручную конфигурацию и локальную копию оверлея

```sh
rm -f /etc/portage/repos.conf/precizer.conf
rm -rf /var/db/repos/precizer
```

## Внесение изменений в оверлей проекта Precizer

Добавление новых версий Precizer, обновление `Manifest` и проверка ebuild описаны в [руководстве для разработчиков](CONTRIBUTING.ru.md)

## Ссылки

- Основной проект: https://github.com/precizer/precizer
- Сайт проекта: https://precizer.github.io/
- Ошибки и предложения: https://github.com/precizer/precizer/issues
- Каталог Gentoo ebuild-репозиториев: https://overlays.gentoo.org/
- Документация `eselect repository`: https://wiki.gentoo.org/wiki/Eselect-repository
