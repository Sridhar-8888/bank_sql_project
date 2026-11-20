use bank;
select * from accounts;
select * from branches;
select * from customers;
select * from transactions;
-- Banking dataset query pack adapted from the supplied ShopEase tutorial
-- MySQL 8.0+. Existing tables: branches, customers, accounts, transactions.


-- 1. TABLES AND CONSTRAINTS (the supplied bank_db.sql already creates these)
SHOW TABLES;
DESCRIBE branches;
DESCRIBE customers;
DESCRIBE accounts;
DESCRIBE transactions;
SHOW CREATE TABLE accounts;

-- Safe schema additions/demos; run individually and only if desired.
-- ALTER TABLE customers ADD COLUMN customer_segment VARCHAR(20) DEFAULT 'Regular';
-- ALTER TABLE accounts MODIFY status VARCHAR(20);
-- ALTER TABLE accounts ADD CONSTRAINT chk_account_balance CHECK (balance >= 0);
-- Example of DELETE / TRUNCATE / DROP on a disposable table only:
CREATE TABLE IF NOT EXISTS temp_demo (demo_id INT PRIMARY KEY, note VARCHAR(40));
INSERT IGNORE INTO temp_demo VALUES (1,'temporary row'),(2,'remove this row');
DELETE FROM temp_demo WHERE demo_id=2;
TRUNCATE TABLE temp_demo;
DROP TABLE temp_demo;

-- 2. AGGREGATION AND HAVING
SELECT status, COUNT(*) AS account_count FROM accounts GROUP BY status ORDER BY account_count DESC;
SELECT customer_id, COUNT(*) AS account_count FROM accounts GROUP BY customer_id HAVING COUNT(*) > 1 ORDER BY account_count DESC;
SELECT b.city, SUM(t.amount) AS transaction_amount
FROM transactions t JOIN accounts a ON a.account_id=t.account_id JOIN branches b ON b.branch_id=(SELECT c.branch_id FROM customers c WHERE c.customer_id=a.customer_id)
GROUP BY b.city HAVING SUM(t.amount)>50000 ORDER BY transaction_amount DESC;
SELECT txn_type, COUNT(*) AS transaction_count FROM transactions GROUP BY txn_type HAVING COUNT(*)>5 ORDER BY transaction_count DESC;
SELECT account_type, COUNT(*) AS accounts, ROUND(AVG(balance),2) AS avg_balance, ROUND(SUM(balance),2) AS total_balance
FROM accounts GROUP BY account_type ORDER BY total_balance DESC;

-- 3. JOINS
-- 3.1 Each account with its customer and branch
SELECT a.account_id, CONCAT(c.first_name,' ',c.last_name) AS customer_name, a.account_type, a.balance, a.status, b.branch_name, b.city
FROM accounts a JOIN customers c ON c.customer_id=a.customer_id JOIN branches b ON b.branch_id=c.branch_id ORDER BY a.account_id;
-- 3.2 All customers, including customers with no accounts
SELECT c.customer_id, CONCAT(c.first_name,' ',c.last_name) AS customer_name, COUNT(a.account_id) AS account_count
FROM customers c LEFT JOIN accounts a ON a.customer_id=c.customer_id GROUP BY c.customer_id,c.first_name,c.last_name ORDER BY account_count DESC;
-- 3.3 Customers with no accounts
SELECT c.customer_id,c.first_name,c.last_name FROM customers c LEFT JOIN accounts a ON a.customer_id=c.customer_id WHERE a.account_id IS NULL;
-- Accounts with no transactions
SELECT a.account_id,a.account_type FROM accounts a WHERE NOT EXISTS (SELECT 1 FROM transactions t WHERE t.account_id=a.account_id);
-- Transactions with no matching account (normally none when foreign keys are enforced)
SELECT t.txn_id,t.account_id FROM transactions t LEFT JOIN accounts a ON a.account_id=t.account_id WHERE a.account_id IS NULL;
-- 3.4 Detailed transaction report across four tables
SELECT t.txn_id,t.txn_date,t.txn_type,t.amount,a.account_id,a.account_type,CONCAT(c.first_name,' ',c.last_name) AS customer_name,b.branch_name
FROM transactions t JOIN accounts a ON a.account_id=t.account_id JOIN customers c ON c.customer_id=a.customer_id JOIN branches b ON b.branch_id=c.branch_id ORDER BY t.txn_date;
-- 3.5 Self join: customers in the same branch (unique pairs)
SELECT CONCAT(c1.first_name,' ',c1.last_name) AS customer_1, CONCAT(c2.first_name,' ',c2.last_name) AS customer_2, b.branch_name
FROM customers c1 JOIN customers c2 ON c1.branch_id=c2.branch_id AND c1.customer_id<c2.customer_id JOIN branches b ON b.branch_id=c1.branch_id;
-- 3.6 Customers above their branch's average credit score
SELECT c.customer_id,c.first_name,c.last_name,c.credit_score,b.branch_name
FROM customers c JOIN branches b ON b.branch_id=c.branch_id
WHERE c.credit_score>(SELECT AVG(c2.credit_score) FROM customers c2 WHERE c2.branch_id=c.branch_id);

-- 4. STRING, DATE, AND MATH FUNCTIONS
SELECT customer_id, UPPER(CONCAT(TRIM(first_name),' ',TRIM(last_name))) AS customer_name FROM customers;
SELECT LOWER(state) AS state, COUNT(*) AS branch_count FROM branches GROUP BY LOWER(state) ORDER BY branch_count DESC;
SELECT txn_type, COUNT(*) AS transactions FROM transactions GROUP BY txn_type ORDER BY transactions DESC;
SELECT DAYNAME(txn_date) AS weekday, COUNT(*) AS transaction_count FROM transactions GROUP BY DAYNAME(txn_date),WEEKDAY(txn_date) ORDER BY WEEKDAY(txn_date);
SELECT c.customer_id, DATEDIFF(MIN(a.opened_date),c.join_date) AS days_joined_to_first_account
FROM customers c LEFT JOIN accounts a ON a.customer_id=c.customer_id GROUP BY c.customer_id,c.join_date;
SELECT account_id,account_type,MOD(account_id,2) AS parity FROM accounts; -- 0 even, 1 odd
SELECT txn_type, ROUND(AVG(amount),2) AS average_amount, ROUND(MAX(amount),2) AS largest_amount FROM transactions GROUP BY txn_type;

-- 5. NULLS, CASE, AND DUPLICATES
SELECT customer_id,first_name,last_name FROM customers WHERE date_of_birth IS NULL;
SELECT customer_id,COALESCE(CONCAT(first_name,' ',last_name),'Name unavailable') AS customer_name FROM customers;
SELECT COUNT(*) AS customers, COUNT(credit_score) AS customers_with_score FROM customers;
SELECT COUNT(*) AS account_count, COUNT(NULLIF(status,'Active')) AS non_active_count FROM accounts;
SELECT account_id,balance,CASE WHEN balance>=100000 THEN 'High balance' WHEN balance>=25000 THEN 'Medium balance' ELSE 'Low balance' END AS balance_band FROM accounts;
SELECT customer_id, SUM(status='Active') AS active_accounts, SUM(status='Closed') AS closed_accounts
FROM accounts GROUP BY customer_id;
-- Find duplicate-looking customer names (names alone do not prove duplicate identity)
SELECT first_name,last_name,COUNT(*) AS matching_names FROM customers GROUP BY first_name,last_name HAVING COUNT(*)>1 ORDER BY matching_names DESC;
-- Find duplicate transaction values for the same account/date/type
SELECT account_id,txn_date,txn_type,amount,COUNT(*) AS copies FROM transactions GROUP BY account_id,txn_date,txn_type,amount HAVING COUNT(*)>1;

-- 6. WINDOW FUNCTIONS
SELECT txn_id,account_id,txn_date,amount,ROW_NUMBER() OVER (ORDER BY amount DESC,txn_id) AS row_num FROM transactions;
SELECT txn_id,amount,RANK() OVER (ORDER BY amount DESC) AS amount_rank,DENSE_RANK() OVER (ORDER BY amount DESC) AS dense_amount_rank FROM transactions;
SELECT account_id,txn_id,txn_date,amount,RANK() OVER (PARTITION BY account_id ORDER BY amount DESC) AS account_amount_rank FROM transactions;
SELECT account_id,txn_date,amount,LAG(amount) OVER (PARTITION BY account_id ORDER BY txn_date,txn_id) AS previous_amount,
 LEAD(amount) OVER (PARTITION BY account_id ORDER BY txn_date,txn_id) AS next_amount FROM transactions;
WITH ranked AS (SELECT account_id,txn_id,txn_date,amount,ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY amount DESC,txn_id) AS rn FROM transactions)
SELECT * FROM ranked WHERE rn<=2 ORDER BY account_id,rn;
WITH monthly AS (SELECT DATE_FORMAT(txn_date,'%Y-%m') AS txn_month,SUM(amount) AS total_amount FROM transactions GROUP BY DATE_FORMAT(txn_date,'%Y-%m'))
SELECT txn_month,total_amount,LAG(total_amount) OVER (ORDER BY txn_month) AS previous_month,
 total_amount-LAG(total_amount) OVER (ORDER BY txn_month) AS change_amount,
 ROUND((total_amount-LAG(total_amount) OVER (ORDER BY txn_month))/NULLIF(LAG(total_amount) OVER (ORDER BY txn_month),0)*100,2) AS change_pct
FROM monthly ORDER BY txn_month;
SELECT txn_date,txn_id,amount,SUM(amount) OVER (ORDER BY txn_date,txn_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_transaction_amount FROM transactions;

-- 7. BANKING KPIs