---
description: Перевірити структуру, збірку, CI та безпеку проєкту без змін
agent: build-engineer
---

# check

Лише перевір поточний проєкт. Не виправляй помилки й не створюй або редагуй файли проєкту. Єдиний дозволений побічний результат — створення чи оновлення `target/` командами збірки.

## Передумови

- Працюй із кореня поточного workspace.
- Перед перевірками зафіксуй `git status --short`, щоб розрізняти наявні зміни й побічні результати збірки.
- Не запускай `git init`, форматери, генератори, інсталяцію залежностей, команди очищення чи будь-які команди, що змінюють файли поза `target/`.
- Не виконуй git commit, push, reset, checkout для скасування змін або видалення файлів.
- Не виводь знайдені значення секретів у звіт. Для секретоподібного збігу вказуй лише шлях і номер рядка.
- Запускай усі незалежні перевірки, навіть якщо деякі з них не пройшли, і зафіксуй конкретну причину кожного збою.

## Дії

Перевір кожен пункт нижче окремо. Відсутній файл, недоступний обов'язковий інструмент або перевірка, яку неможливо завершити, є `FAIL`, а не `PASS`.

1. **Manifest агента:** перевір, що `.github/agents/build-engineer.agent.md` існує та описує роль агента, обмеження із забороненими діями й критерії завершення/успіху.
2. **Skills:** перевір наявність:
   - `.github/skills/project-scaffold/SKILL.md`
   - `.github/skills/build-and-test/SKILL.md`
   - `.github/skills/github-actions/SKILL.md`

   Для кожного skill окремо підтверди, що він пояснює призначення/умови застосування, вхідні дані, що створюється, і перевірки. Наявності лише заголовків недостатньо: відповідний розділ має містити зміст.
3. **Prompt-команди:** переконайся, що існують усі файли:
   - `.github/prompts/git-init.prompt.md`
   - `.github/prompts/create-project.prompt.md`
   - `.github/prompts/create-build.prompt.md`
   - `.github/prompts/create-actions.prompt.md`
   - `.github/prompts/check.prompt.md`
   - `.github/prompts/init.prompt.md`
4. **Порядок `init`:** перевір вміст `.github/prompts/init.prompt.md` і підтверди, що він викликає саме `git-init`, `create-project`, `create-build`, `create-actions`, `check` у такому порядку. Не зараховуй просту згадку команд поза послідовністю дій.
5. **Файли проєкту:** перевір наявність `pom.xml`, `src/main/java/edu/lpnu/hello/App.java`, `src/main/java/edu/lpnu/hello/Calculator.java`, `src/test/java/edu/lpnu/hello/CalculatorTest.java`, `README.md`, `docs/architecture.md`, `docs/usage.md`, `ci.sh` і `ci.bat`.
6. **Maven, тест та JAR:** виконай з кореня проєкту:

   ```sh
   mvn -B verify
   mvn -B -Dtest=CalculatorTest test
   ```

   Переконайся, що тест `CalculatorTest.BasicAddition` пройшов (перевір звіт Surefire, а не лише код завершення), існує `target/hello.jar`, а команда

   ```sh
   java -jar target/hello.jar
   ```

   завершується успішно та виводить рівно `Hello, World!` (без інших рядків у stdout).
7. **Workflow CI:** переконайся, що `.github/workflows/ci.yml` існує, розбирається YAML-парсером і має:
   - рівно одну job та matrix із `ubuntu-latest`, `windows-latest`, `macos-latest`;
   - лише тригери `push` і `pull_request`, кожен лише для гілок `develop` і `master`;
   - виклики `ci.sh` та `ci.bat` у відповідних кроках/для відповідних ОС;
   - відсутність секретів або посилань на secrets.

   Використай наявний YAML-парсер; якщо його немає, перевір доступний `actionlint`. Якщо жодного валідатора немає, зафіксуй `FAIL`. Парсерна перевірка й перевірка полів workflow мають бути окремо підтверджені.
8. **Git та секрети:** перевір Git-відстеження через `git ls-files`:
   - жоден шлях під `target/` не має бути відстежуваним;
   - серед відстежуваних файлів не має бути очевидних файлів секретів, зокрема `.env` (крім шаблонів на кшталт `.env.example`), приватних ключів (`*.pem`, `*.key`, `id_rsa`), credential-файлів або файлів із назвою `secrets`.

   Також виконай простий пошук у відстежуваних текстових файлах за схожими на токен/пароль присвоєннями, наприклад полями `token`, `password`, `passwd`, `secret` або `api_key` із непорожнім буквальним значенням. Не вважай безпечне посилання на сховище секретів (`${{ secrets.NAME }}`) секретом у CI, але перевір його наявність за умовами пункту 7. Не показуй значення збігів: повідомляй лише шлях і номер рядка. Не трактуй назви полів, документацію з очевидними placeholder-значеннями або явні зразки як реальні секрети; за сумнівного збігу став `FAIL` і поясни його без розкриття значення. Якщо Git-репозиторію немає або перелік відстежуваних файлів отримати неможливо, цей пункт — `FAIL`.

## Очікувані файли

Перевір, але не створюй і не змінюй:

- Manifest: `.github/agents/build-engineer.agent.md`
- Skills: `.github/skills/project-scaffold/SKILL.md`, `.github/skills/build-and-test/SKILL.md`, `.github/skills/github-actions/SKILL.md`
- Команди: `.github/prompts/git-init.prompt.md`, `.github/prompts/create-project.prompt.md`, `.github/prompts/create-build.prompt.md`, `.github/prompts/create-actions.prompt.md`, `.github/prompts/check.prompt.md`, `.github/prompts/init.prompt.md`
- Проєкт: `pom.xml`, `src/main/java/edu/lpnu/hello/App.java`, `src/main/java/edu/lpnu/hello/Calculator.java`, `src/test/java/edu/lpnu/hello/CalculatorTest.java`, `README.md`, `docs/architecture.md`, `docs/usage.md`, `ci.sh`, `ci.bat`, `.github/workflows/ci.yml`
- Артефакт після Maven-збірки: `target/hello.jar`

## Команди перевірки

Запускай команди з кореня workspace. Окрім `target/`, вони не мають змінювати файли. Збережи код завершення й релевантний текст помилки кожної команди; не продовжуй після помилки так, ніби попередній крок пройшов.

```sh
git status --short
test -f .github/agents/build-engineer.agent.md
test -f .github/skills/project-scaffold/SKILL.md
test -f .github/skills/build-and-test/SKILL.md
test -f .github/skills/github-actions/SKILL.md
test -f .github/prompts/git-init.prompt.md
test -f .github/prompts/create-project.prompt.md
test -f .github/prompts/create-build.prompt.md
test -f .github/prompts/create-actions.prompt.md
test -f .github/prompts/check.prompt.md
test -f .github/prompts/init.prompt.md
test -f pom.xml
test -f src/main/java/edu/lpnu/hello/App.java
test -f src/main/java/edu/lpnu/hello/Calculator.java
test -f src/test/java/edu/lpnu/hello/CalculatorTest.java
test -f README.md
test -f docs/architecture.md
test -f docs/usage.md
test -f ci.sh
test -f ci.bat
test -f .github/workflows/ci.yml
mvn -B verify
mvn -B -Dtest=CalculatorTest test
test -f target/hello.jar
java -jar target/hello.jar
git ls-files
```

Для YAML застосуй доступний валідатор, наприклад `actionlint` або встановлений YAML-парсер; не встановлюй пакети. Для перевірки секретів переглянь лише відстежувані текстові файли, не друкуючи вивід із секретоподібними значеннями. Переконайся, що файли поза `target/` не змінилися через цю команду: порівняй фінальний `git status --short` із початковим і врахуй лише зміни, спричинені перевіркою.

## Повідомлення про помилку

- Якщо будь-який пункт не пройшов, у таблиці вкажи `FAIL`, точний файл/команду/перевірку та коротку причину з релевантною помилкою. Не виправляй проблему й не приховуй її частковим успіхом.
- Для Maven, JUnit, JAR, YAML або Git збою повідом конкретний код завершення й суттєвий текст помилки; для `BasicAddition` вкажи назву тесту та результат Surefire.
- Для manifest, skill, prompt-команди, послідовності `init`, очікуваного файла, workflow-умови або секрету вкажи, що саме відсутнє, некоректне чи знайдене. Не розкривай значення секрету.
- Якщо команда чи інструмент недоступні, відповідна перевірка — `FAIL` із назвою відсутнього інструмента; не підмінюй її припущенням.
- Не виконуй commit, push або видалення файлів за жодних обставин.

## Підсумковий звіт

Наприкінці виведи таблицю з окремим рядком для кожної перевірки: manifest; кожен skill; наявність кожної prompt-команди; порядок `init`; наявність кожного очікуваного файла проєкту; кожна з двох Maven-команд; проходження `BasicAddition`; наявність JAR; точний вивід JAR; валідність YAML; одна job; matrix та всі ОС; тригери та гілки; виклики скриптів; відсутність секретів у workflow; Git-відстеження `target/`; відсутність відстежуваних файлів секретів; пошук секретоподібних значень; відсутність змін поза `target/`. Для кожного рядка наведи `PASS` або `FAIL` і причину. Якщо кілька файлів перевіряються однією командою, все одно наведи окремий рядок на кожен файл.

Загальний підсумок — `PASS` лише якщо кожен рядок має `PASS`. Якщо є хоча б один `FAIL`, загальний підсумок — `FAIL`; чітко переліч усі невдалі перевірки й що саме зламано. Не називай проєкт перевіреним успішно за часткового результату.
