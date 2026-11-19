---
description: Створити базову структуру Java Hello World через project-scaffold
agent: build-engineer
---

# create-project

Створи або доповни початкову структуру Java-проєкту, викликаючи skill `project-scaffold`.

## Передумови

- За замовчуванням мова — `Java`, назва проєкту — `hello`. Використовуй ці значення без додаткових питань.
- Спочатку перевір наявне робоче дерево та конфігурацію без перезапису готових файлів.
- Не виконуй git commit, git push або видалення файлів.
- Якщо явно передана мова не Java, повідом про відсутність підтримки й не змінюй файли.

## Дії

1. Виклич skill `project-scaffold` і застосуй його правила для поточного workspace.
2. Створи лише відсутні каталоги `src/main/java/edu/lpnu/hello`, `src/test/java/edu/lpnu/hello` і `docs`.
3. Створи `src/main/java/edu/lpnu/hello/App.java` лише за умови відсутності файлу; його пакет і вихід мають бути `edu.lpnu.hello` та `Hello, World!`.
4. Якщо `App.java` існує й доречний, залиш його без змін. Якщо вміст конфліктний, зупини створення цього файлу й опиши конфлікт.
5. Якщо `README.md` існує, доповни відсутні розділи з ПІБ `Мельник В.О.`, групою `КІ-402`, варіантом `11`, описом, командами запуску та інструкцією для build-engineer. Не дублюй і не змінюй наявні розділи.
6. Якщо `.gitignore` існує, додай лише відсутні правила `/out/`, `/target/`, `*.class`, `*.log`, `.env`, `*.iml`, `.DS_Store`, `.idea/` і `.vscode/` без дублікатів.
7. Повторний запуск не має змінювати наявні правильні файли чи створювати копії.

## Очікувані файли

- `src/main/java/edu/lpnu/hello/App.java`
- Каталоги `src/main/java/edu/lpnu/hello`, `src/test/java/edu/lpnu/hello`, `docs`
- `README.md`
- `.gitignore`

## Команди перевірки

Запусти з кореня workspace:

```sh
test -f src/main/java/edu/lpnu/hello/App.java
grep -F "package edu.lpnu.hello;" src/main/java/edu/lpnu/hello/App.java
grep -F "Hello, World!" src/main/java/edu/lpnu/hello/App.java
grep -F "java src/main/java/edu/lpnu/hello/App.java" README.md
grep -F "java -jar target/hello.jar" README.md
java src/main/java/edu/lpnu/hello/App.java
```

Перевірте також наявність усіх перелічених каталогів і обов'язкових розділів README.

## Повідомлення про помилку

- Для відсутнього або непідтримуваного входу повідом про необхідність уточнення й не створюй файлів.
- Якщо `App.java` конфліктує з очікуваним пакетом або виводом, наведи шлях і різницю, не перезаписуй файл і не повідомляй про повний успіх.
- Якщо перевірка README, каталогу, файлу або запуску провалилась, наведи конкретний пункт і текст помилки.
- Не приховуй помилки попереднього або часткового запуску загальним повідомленням про успіх.
