-- База данных городской библиотеки (MySQL 8)
-- Запуск: mysql -u root -p < library.sql   (или выполнить целиком в VS Code)

DROP DATABASE IF EXISTS city_library;
CREATE DATABASE city_library CHARACTER SET utf8mb4;
USE city_library;

CREATE TABLE book (
    book_id      INT AUTO_INCREMENT PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    author       VARCHAR(150) NOT NULL,
    isbn         VARCHAR(17)  NOT NULL UNIQUE,
    publisher    VARCHAR(100),
    publish_year SMALLINT,
    genre        VARCHAR(50)
);

CREATE TABLE book_copy (
    copy_id          INT AUTO_INCREMENT PRIMARY KEY,
    book_id          INT NOT NULL,
    inventory_number VARCHAR(20) NOT NULL UNIQUE,
    shelf            VARCHAR(20),
    acquired_date    DATE NOT NULL,
    status           ENUM('в наличии', 'выдан', 'списан') NOT NULL DEFAULT 'в наличии',
    FOREIGN KEY (book_id) REFERENCES book (book_id)
);

CREATE TABLE reader (
    reader_id     INT AUTO_INCREMENT PRIMARY KEY,
    card_number   VARCHAR(10)  NOT NULL UNIQUE,
    full_name     VARCHAR(150) NOT NULL,
    birth_date    DATE,
    phone         VARCHAR(20)  NOT NULL,
    email         VARCHAR(100),
    address       VARCHAR(200),
    registered_on DATE NOT NULL
);

CREATE TABLE loan (
    loan_id     INT AUTO_INCREMENT PRIMARY KEY,
    copy_id     INT  NOT NULL,
    reader_id   INT  NOT NULL,
    issue_date  DATE NOT NULL,
    due_date    DATE NOT NULL,
    return_date DATE NULL,
    FOREIGN KEY (copy_id)   REFERENCES book_copy (copy_id),
    FOREIGN KEY (reader_id) REFERENCES reader (reader_id),
    CHECK (due_date >= issue_date),
    CHECK (return_date IS NULL OR return_date >= issue_date)
);

-- ===== Тестовые данные =====
INSERT INTO book (title, author, isbn, publisher, publish_year, genre) VALUES
('Мастер и Маргарита', 'М. А. Булгаков', '978-5-17-090770-1', 'АСТ', 2019, 'Роман'),
('Преступление и наказание', 'Ф. М. Достоевский', '978-5-04-098516-3', 'Эксмо', 2020, 'Роман'),
('Пикник на обочине', 'А. и Б. Стругацкие', '978-5-17-118346-3', 'АСТ', 2021, 'Фантастика');
INSERT INTO book_copy (book_id, inventory_number, shelf, acquired_date, status) VALUES
(1, 'ИН-0001', 'А-1', '2023-02-01', 'выдан'),
(1, 'ИН-0002', 'А-1', '2023-02-01', 'в наличии'),
(2, 'ИН-0003', 'А-2', '2023-03-15', 'выдан'),
(3, 'ИН-0004', 'Б-4', '2024-01-10', 'в наличии'),
(3, 'ИН-0005', 'Б-4', '2024-01-10', 'выдан');
INSERT INTO reader (card_number, full_name, birth_date, phone, email, address, registered_on) VALUES
('Ч-1001', 'Иванов Иван Петрович', '1995-04-12', '+79161112233', 'ivanov@mail.ru', 'ул. Ленина, 5', '2024-09-01'),
('Ч-1002', 'Смирнова Анна Сергеевна', '2001-11-30', '+79032223344', NULL, 'пр. Мира, 17', '2025-01-15');
INSERT INTO loan (copy_id, reader_id, issue_date, due_date, return_date) VALUES
(4, 1, '2026-08-01', '2026-08-15', '2026-08-14'),
(1, 1, '2026-10-10', '2026-10-24', NULL),
(3, 1, '2026-10-20', '2026-11-03', NULL),
(5, 2, '2026-09-25', '2026-10-09', NULL),
(2, 2, '2026-05-01', '2026-05-15', '2026-05-20');

-- ===== Запросы =====
-- Запрос 1. Книги, которые сейчас на руках у читателя N (билет Ч-1001)
SELECT b.title, b.author, c.inventory_number, l.issue_date, l.due_date
FROM loan l
JOIN reader r    ON r.reader_id = l.reader_id
JOIN book_copy c ON c.copy_id   = l.copy_id
JOIN book b      ON b.book_id   = c.book_id
WHERE r.card_number = 'Ч-1001'
  AND l.return_date IS NULL
ORDER BY l.due_date;
-- Запрос 2. Должники: просроченные выдачи
SELECT r.full_name, r.phone, b.title, c.inventory_number, l.due_date,
       DATEDIFF(CURDATE(), l.due_date) AS days_overdue
FROM loan l
JOIN reader r    ON r.reader_id = l.reader_id
JOIN book_copy c ON c.copy_id   = l.copy_id
JOIN book b      ON b.book_id   = c.book_id
WHERE l.return_date IS NULL
  AND l.due_date < CURDATE()
ORDER BY days_overdue DESC;
-- Запрос 3. Сколько экземпляров каждой книги всего и сколько на полке
SELECT b.title, b.author,
       COUNT(c.copy_id) AS total_copies,
       COALESCE(SUM(c.status = 'в наличии'), 0) AS available
FROM book b
LEFT JOIN book_copy c ON c.book_id = b.book_id AND c.status <> 'списан'
GROUP BY b.book_id, b.title, b.author
ORDER BY b.title;
-- Запрос 4. Пять самых популярных книг за последний год
SELECT b.title, b.author, COUNT(*) AS loans_count
FROM loan l
JOIN book_copy c ON c.copy_id = l.copy_id
JOIN book b      ON b.book_id = c.book_id
WHERE l.issue_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY b.book_id, b.title, b.author
ORDER BY loans_count DESC
LIMIT 5;
