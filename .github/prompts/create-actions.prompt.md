---
description: Налаштувати кросплатформний GitHub Actions CI через github-actions
agent: build-engineer
---

# create-actions

Налаштуй GitHub Actions CI для Maven-проєкту Java 17, викликаючи skill `github-actions`.

## Передумови

- Назва artifact завжди має бути `hello-app-${{ matrix.os }}` для унікального завантаження кожної ОС матриці; JAR завжди називається `target/hello.jar`.
- Обов'язкові ОС: `ubuntu-latest`, `windows-latest`, `macos-latest`.
- Перевір `ci.sh`, `ci.bat`, `.github/workflows/ci.yml`, робоче дерево та наявну конфігурацію перед змінами.
- Не змінюй `pom.xml`, Java-код або інші CI-файли поза цим завданням.
- Не виконуй git commit, git push або видалення файлів.
- Якщо перелік ОС неповний, попроси уточнення й не створюй файлів. Назву artifact не змінюй і не запитуй окремо.

## Дії

1. Виклич skill `github-actions`.
2. Створи `ci.sh` лише за відсутності:
   - виконує `mvn -B verify`;
   - перевіряє наявність `target/hello.jar`;
   - завершується з помилкою за невдалої збірки або відсутності JAR;
   - запускає `java -jar target/hello.jar`.
3. Створи `ci.bat` лише за відсутності:
   - викликає Maven через `call mvn -B verify`;
   - перевіряє `%ERRORLEVEL%` після Maven, перевірки JAR і запуску JAR;
   - повертає ненульовий код для кожної помилки.
4. Створи `.github/workflows/ci.yml` лише за відсутності; workflow має один job із matrix для усіх трьох ОС.
5. Налаштуй тригери `push` і `pull_request` лише для гілок `develop` та `master`.
6. Додай checkout, `actions/setup-java` із Java 17, запуск скриптів і `actions/upload-artifact` для `target/hello.jar` із назвою `hello-app-${{ matrix.os }}`.
7. Не додавай Maven, тест або запуск Java напряму до workflow і не використовуй секрети.
8. Якщо кожен файл вже містить правильну конфігурацію, залиш його без змін. Якщо один конфліктний, не перезаписуй його і не додавай решту частково.
9. Повторний запуск не має дублювати job, кроки, скрипти чи workflow.

## Очікувані файли

- `ci.sh`
- `ci.bat`
- `.github/workflows/ci.yml`

## Команди перевірки

Запусти з кореня workspace:

```sh
test -f ci.sh
test -f ci.bat
test -f .github/workflows/ci.yml
grep -F "ubuntu-latest" .github/workflows/ci.yml
grep -F "windows-latest" .github/workflows/ci.yml
grep -F "macos-latest" .github/workflows/ci.yml
```

Також перевір YAML доступним парсером; якщо доступний `actionlint`, запусти його. Для поточної ОС перевір відповідний скрипт лише якщо доступні Maven та JDK 17. Не видавай локальне тестування за повну перевірку всіх трьох ОС.

Переконайся, що workflow має:

- один job і matrix для усіх трьох ОС;
- тригери лише для `develop` і `master`;
- checkout і Java 17;
- Linux/macOS через `bash ci.sh`;
- Windows через `shell: cmd` і `ci.bat`;
- завантаження саме `target/hello.jar` під унікальним для кожної ОС ім'ям `hello-app-${{ matrix.os }}`;
- відсутність секретів і прямих команд збірки у workflow.

## Повідомлення про помилку

- Для неповного списку ОС повідом про необхідність уточнення й не створюй файли. Назву artifact має завжди дорівнювати `hello-app-${{ matrix.os }}`.
- Якщо один із трьох файлів конфліктний, наведи його шлях і різницю з очікуваною конфігурацією; не перезаписуй і не роби решту частково.
- Якщо Maven/JDK або скрипт невдається, наведи конкретну команду, вихідний код і текст помилки.
- Якщо JAR не створено, перевір Maven-конфігурацію і повідом точний крок, не приховуючи збій перевіркою скрипта.
- Для YAML/actionlint повідом блокувальний діагноз; не підтверджуй повний успіх CI, якщо перевірку всіх ОС неможливо виконати локально.

## Приклад очікуваного artifact

Для matrix-OS очікувані унікальні назви:

- `hello-app-ubuntu-latest`
- `hello-app-windows-latest`
- `hello-app-macos-latest`

У конфігурації використовуй вираз `hello-app-${{ matrix.os }}`; не використовуй спільну назву `hello-app` для всіх рядків матриці.
