---
description: Налаштувати Maven, Java 17, JUnit 5 та target/hello.jar через build-and-test
agent: build-engineer
---

# create-build

Налаштуй Maven-збірку та тестування для Java-проєкту, викликаючи skill `build-and-test`.

## Передумови

- Вхідні дані: назва артефакту `hello` і Java-пакет `edu.lpnu.hello`.
- Перевір `pom.xml`, Java-файли, робоче дерево та наявність `target/` перед змінами.
- Не виконуй git commit, git push, видалення файлів і не видаляй `target/` вручну.
- `mvn clean` дозволений лише для перегенерації артефакту.
- Якщо параметри відсутні або конфігурація конфліктує з очікуваними значеннями, попроси уточнення й не змінюй файли без узгодження.

## Дії

1. Виклич skill `build-and-test`.
2. Створи або доповни `pom.xml`, не замінюючи несумісні готові налаштування повністю.
3. Налаштуй Java 17, JUnit 5, Maven Surefire та Maven Jar Plugin з `Main-Class: edu.lpnu.hello.App`.
4. Забезпеч назву Maven артефакту `hello` і результат `target/hello.jar`.
5. Створи `App.java` лише за відсутності або залиш його без змін, якщо він друкує `Hello, World!`; за конфліктом не перезаписуй його.
6. Створи `src/main/java/edu/lpnu/hello/Calculator.java` з публічним методом `public int add(int first, int second)`.
7. Створи `src/test/java/edu/lpnu/hello/CalculatorTest.java` з JUnit 5 і публічним тестом `BasicAddition`, який перевіряє суму `2 + 3 = 5`.
8. Не дублюй Maven залежності, plugins чи наявні Java-файли під час повторного запуску.

## Очікувані файли

- `pom.xml`
- `src/main/java/edu/lpnu/hello/App.java`, якщо він відсутній
- `src/main/java/edu/lpnu/hello/Calculator.java`
- `src/test/java/edu/lpnu/hello/CalculatorTest.java`
- `target/hello.jar` після успішної перевірки

## Команди перевірки

Запусти з кореня workspace:

```sh
java -version
mvn -version
mvn -B verify
mvn -B -Dtest=CalculatorTest test
java -jar target/hello.jar
git check-ignore -v target/
```

Успіх потребує одночасно:

- успішного `mvn -B verify`;
- проходження `CalculatorTest.BasicAddition`;
- точного створення `target/hello.jar`;
- рівно `Hello, World!` у виводі JAR;
- винятку `target/` через `.gitignore`.

## Повідомлення про помилку

- Для відсутніх Java 17 або Maven перевір і покажи `java -version`, `mvn -version` і `JAVA_HOME`; не приховуй блокування частковою збіркою.
- Для конфлікту `pom.xml` або App.java наведи точний файл, потрібні налаштування та наявну відмінність.
- Для невдалого тесту наведи файл тесту, назву `BasicAddition` і повний релевантний текст Maven.
- Якщо JAR відсутній або друкує інший рядок, не повідомляй про успіх; наведи крок, помилку та очікуваний результат.
