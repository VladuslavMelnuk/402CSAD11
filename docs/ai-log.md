# Журнал взаємодії з AI

**Студент:** Мельник В.О., КІ-402, варіант 11 (Java, Maven, JUnit)
**Дата виконання:** 19.11.2026
**Інструменти:** GitHub Copilot Chat у VS Code (план Copilot Free, модель обирається автоматично); консультації щодо плану роботи, перевірки результатів і діагностики помилок: Claude.
**Секрети:** паролі, токени та ключі в запитах до AI не передавалися.

## 1. Запити до Copilot Chat і результати

| № | Запит (суть) | Важлива відповідь / результат | Рішення |
|---|---|---|---|
| 1 | Створити `.github/agents/build-engineer.agent.md` для автоматизації Java Hello World (Java 17, Maven, JUnit 5, `target/hello.jar`) | Manifest з роллю, обов'язками, правилами, забороненими діями, workflow, обробкою помилок, критеріями успіху | Прийнято з доповненнями (п. 1 нижче) |
| 2 | Доповнити manifest: `.gitignore` у `git-init`, скрипти `ci.sh`/`ci.bat`, повні критерії успіху, документація, дозвіл `mvn clean` лише для `target/` | Manifest оновлено | Прийнято |
| 3 | Створити skill `project-scaffold` | `SKILL.md` з входами, виходами, перевірками, прикладом, помилкою | Виправлено (п. 2) |
| 4 | Створити skill `build-and-test` | `SKILL.md` для `pom.xml`, `Calculator`, тесту `BasicAddition` | Прийнято |
| 5 | Створити skill `github-actions` | `SKILL.md` для `ci.sh`, `ci.bat`, `ci.yml` з matrix | Виправлено (п. 3, 4) |
| 6 | Створити команди `git-init`, `create-project`, `create-build`, `create-actions` | Чотири `.prompt.md` з передумовами, діями, перевірками, помилками | Виправлено (п. 5) |
| 7 | Створити команду `check` (без змін у проєкті) | `check.prompt.md` з таблицею PASS/FAIL | Прийнято |
| 8 | Створити команду-оркестратор `init` | `init.prompt.md`: передумови, послідовність кроків, зупинка на помилці | Перейменовано й виправлено (п. 6, 7) |
| 9 | Створити `README.md`, `docs/architecture.md`, `docs/usage.md` | Три документи | Прийнято |
| 10 | Запуск `run-init` на гілці `feature/hello-java` | Згенеровано `pom.xml`, `App`, `Calculator`, тест, `ci.sh`, `ci.bat`, `ci.yml`; `check` = PASS | Прийнято після перегляду |
| 11 | Повторний запуск `run-init` | Файли не змінилися, `git status` порожній | Ідемпотентність підтверджено |

## 2. Помилки та їх виправлення

1. **Неповний manifest.** `git-init` не створював `.gitignore`, не було `ci.sh`/`ci.bat` і частини критеріїв успіху. *Виправлення:* додатковий запит до Copilot (рядок 2 таблиці).
2. **Skill `project-scaffold` зупинявся на існуючому README.** Через це `init` не відпрацював би після ручного створення README. *Виправлення:* README лише доповнюється, зупинка тільки при конфлікті `App.java`; додано правила `.gitignore` для секретів.
3. **Однакова назва artifact для трьох ОС.** `actions/upload-artifact@v4` дає конфлікт імен у matrix. *Виправлення:* назва `hello-app-${{ matrix.os }}`.
4. **Windows-специфіка CI.** Без `shell: cmd` та без `call` перед `mvn` скрипт `ci.bat` завершується одразу після Maven. *Виправлення:* `shell: cmd`, `call mvn`, перевірка `%ERRORLEVEL%`.
5. **Команди без значень за замовчуванням.** `create-project` вимагала назву проєкту й могла зупинити `init`. *Виправлення:* мова `Java`, назва `hello` за замовчуванням.
6. **Конфлікт імені `/init` з вбудованою командою VS Code.** Запуск `init` виконував вбудовану команду, яка створила непотрібний `.github/copilot-instructions.md`. *Виправлення:* зайвий файл видалено, `init.prompt.md` перейменовано на `run-init.prompt.md`, документацію оновлено.
7. **Copilot не може «викликати» prompt-команди.** `run-init` завершувався з `FAIL`: «Prompt-команда недоступна в поточному інструменті». *Виправлення:* оркестратор читає файл кожної команди за Markdown-посиланням і виконує його інструкції.
8. **Copilot не бачив Maven** (`mvn` лише в `~/.zshrc`). *Виправлення:* PATH додано в `~/.zprofile`, VS Code перезапущено.

## 3. Прийняті рішення

- Варіант 11 → 5 (Java, Maven, JUnit): 11 mod 6 = 5, у методичці лише шість варіантів.
- Виконуваний файл `hello` реалізовано як `target/hello.jar`, каталог збірки `build/` як `target/` (стандарт Maven); відмінності описано в `docs/architecture.md`.
- Агент (manifest, skills, commands, документація) лежить у `develop`; повний проєкт генерується командою `run-init` у `feature/hello-java`.

## 4. Докази перевірки

- Локально: `mvn -B verify` — `BUILD SUCCESS`, `Tests run: 1, Failures: 0`; `java -jar target/hello.jar` виводить `Hello, World!`.
- Команда `check`: `PASS`.
- Повторний `run-init`: змін у файлах немає.
- GitHub Actions: див. pull request `lab1/finish`.