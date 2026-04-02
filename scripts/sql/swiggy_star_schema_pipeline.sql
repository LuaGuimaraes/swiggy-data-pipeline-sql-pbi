/* =====================================================================
PROJETO: Pedidos Swiggy (SQL Server)
RESPONSÁVEL PELO PROJETO: Luana Guimaraes

   OBJETIVO:
     - Ingerir dados brutos com segurança (tudo como texto)
     - Converter para uma tabela limpa com tipagem correta
     - Executar verificações de qualidade dos dados (nulos, vazios e duplicados)
     - Construir um modelo Star Schema (Dimensões + Fato)
     - Carregar as dimensões com valores distintos
     - Carregar a tabela fato, convertendo texto em IDs por meio de joins
     - Validar integridade referencial e contagem de linhas
     - Disponibilizar consultas analíticas iniciais (KPIs)

   OBSERVAÇÕES:
     - Este script foi feito para SQL Server (usa TRY_CONVERT, GO e IDENTITY).
     - Execute as seções em ordem.
     - Dica no DBeaver: selecione a instrução inteira antes de executar,
       para evitar execução parcial.
   ===================================================================== */


/* =====================================================================
   0) RESET
   OBJETIVO:
     - Remover tabelas existentes para permitir uma nova execução limpa
       em ambiente de desenvolvimento ou aprendizado.
   AVISO:
     - Isso apaga todos os dados dessas tabelas.
   ===================================================================== */

IF OBJECT_ID('dbo.swiggy_orders', 'U') IS NOT NULL
    DROP TABLE dbo.swiggy_orders;

IF OBJECT_ID('dbo.swiggy_orders_raw', 'U') IS NOT NULL
    DROP TABLE dbo.swiggy_orders_raw;

GO


/* =====================================================================
   1) TABELA DE STAGING / BRUTA (TUDO COMO TEXTO)
   OBJETIVO:
     - Carregar os dados sem falhar por problemas de tipagem
       (datas, decimais, inteiros).
     - Preservar os valores originais para auditoria e troubleshooting.
   ===================================================================== */

CREATE TABLE dbo.swiggy_orders_raw (
    state            VARCHAR(150) NULL,
    city             VARCHAR(150) NULL,
    order_date_raw   VARCHAR(50)  NULL,  -- data como texto bruto
    restaurant_name  VARCHAR(300) NULL,
    location         VARCHAR(300) NULL,
    category         VARCHAR(150) NULL,
    dish_name        VARCHAR(500) NULL,
    price_inr_raw    VARCHAR(50)  NULL,  -- valor numérico como texto bruto
    rating_raw       VARCHAR(50)  NULL,  -- nota como texto bruto
    rating_count_raw VARCHAR(50)  NULL   -- quantidade de avaliações como texto bruto
);

GO


/* =====================================================================
   2) TABELA LIMPA (TIPADA)
   OBJETIVO:
     - Armazenar os dados padronizados e com tipagem correta,
       prontos para análise e modelagem.
   ===================================================================== */

CREATE TABLE dbo.swiggy_orders (
    state            VARCHAR(150)  NULL,
    city             VARCHAR(150)  NULL,
    order_date       DATE          NULL,
    restaurant_name  VARCHAR(300)  NULL,
    location         VARCHAR(300)  NULL,
    category         VARCHAR(150)  NULL,
    dish_name        VARCHAR(500)  NULL,
    price_inr        DECIMAL(10,2) NULL,
    rating           DECIMAL(3,1)  NULL,
    rating_count     INT           NULL
);

GO



/* =====================================================================
   3) CARGA: BRUTA -> LIMPA (CONVERSÃO SEGURA)
   REGRAS DE CONVERSÃO:
     - Data: tenta primeiro dd-mm-yyyy (estilo 105),
       depois dd/mm/yyyy (estilo 103)
     - Numéricos: TRY_CONVERT retorna NULL em vez de gerar erro
   RESULTADO:
     - Insere todas as linhas da tabela bruta na tabela limpa,
       transformando conversões inválidas em NULL
   ===================================================================== */

INSERT INTO dbo.swiggy_orders (
    state, city, order_date, restaurant_name, location, category, dish_name,
    price_inr, rating, rating_count
)
SELECT
    state,
    city,
    COALESCE(
        TRY_CONVERT(date, order_date_raw, 105), -- dd-mm-yyyy
        TRY_CONVERT(date, order_date_raw, 103)  -- dd/mm/yyyy
    ) AS order_date,
    restaurant_name,
    location,
    category,
    dish_name,
    TRY_CONVERT(DECIMAL(10,2), price_inr_raw)    AS price_inr,
    TRY_CONVERT(DECIMAL(3,1),  rating_raw)       AS rating,
    TRY_CONVERT(INT,           rating_count_raw) AS rating_count
FROM dbo.swiggy_orders_raw;



/* =====================================================================
   4) AUDITORIA: DATAS QUE FALHARAM NA CONVERSÃO
   OBJETIVO:
     - Identificar valores de data na tabela bruta que não estão vazios,
       mas não puderam ser convertidos.
   ===================================================================== */

SELECT TOP 50 order_date_raw
FROM dbo.swiggy_orders_raw
WHERE COALESCE(
        TRY_CONVERT(date, order_date_raw, 105),
        TRY_CONVERT(date, order_date_raw, 103)
      ) IS NULL
  AND NULLIF(LTRIM(RTRIM(order_date_raw)), '') IS NOT NULL;



/* =====================================================================
   5) QUALIDADE DOS DADOS: CONTAGEM DE NULOS
   OBJETIVO:
     - Fazer uma verificação rápida de saúde dos dados
       após o processo de conversão.
   ===================================================================== */

SELECT
    SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END)            AS null_state,
    SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END)             AS null_city,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END)       AS null_order_date,
    SUM(CASE WHEN restaurant_name IS NULL THEN 1 ELSE 0 END)  AS null_restaurant_name,
    SUM(CASE WHEN location IS NULL THEN 1 ELSE 0 END)         AS null_location,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END)         AS null_category,
    SUM(CASE WHEN dish_name IS NULL THEN 1 ELSE 0 END)        AS null_dish_name,
    SUM(CASE WHEN price_inr IS NULL THEN 1 ELSE 0 END)        AS null_price_inr,
    SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END)           AS null_rating,
    SUM(CASE WHEN rating_count IS NULL THEN 1 ELSE 0 END)     AS null_rating_count
FROM dbo.swiggy_orders;



/* =====================================================================
   6) QUALIDADE DOS DADOS: STRINGS VAZIAS
   OBJETIVO:
     - Valores vazios não são NULL.
     - Esta consulta encontra colunas de texto com valor vazio
       ou apenas espaços.
   OBSERVAÇÃO:
     - Depois, se quiser, esses vazios podem ser tratados como NULL.
   ===================================================================== */

SELECT *
FROM dbo.swiggy_orders
WHERE NULLIF(LTRIM(RTRIM(state)), '') IS NULL
   OR NULLIF(LTRIM(RTRIM(city)), '') IS NULL
   OR NULLIF(LTRIM(RTRIM(restaurant_name)), '') IS NULL
   OR NULLIF(LTRIM(RTRIM(location)), '') IS NULL
   OR NULLIF(LTRIM(RTRIM(category)), '') IS NULL
   OR NULLIF(LTRIM(RTRIM(dish_name)), '') IS NULL;



/* =====================================================================
   7) DUPLICADOS: IDENTIFICAÇÃO
   OBJETIVO:
     - Identificar linhas duplicadas considerando todas
       as colunas de negócio.
   ===================================================================== */

SELECT
    state, city, order_date, restaurant_name, location, category, dish_name,
    price_inr, rating, rating_count,
    COUNT(*) AS cnt
FROM dbo.swiggy_orders
GROUP BY
    state, city, order_date, restaurant_name, location, category, dish_name,
    price_inr, rating, rating_count
HAVING COUNT(*) > 1
ORDER BY cnt DESC;



/* =====================================================================
   8) DUPLICADOS: REMOÇÃO (MANTENDO APENAS 1 LINHA)
   MÉTODO:
     - ROW_NUMBER() gera rn = 1..n para cada grupo duplicado
     - As linhas com rn > 1 são removidas
   ===================================================================== */

WITH cte AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY state, city, order_date, restaurant_name, location, category, dish_name,
                         price_inr, rating, rating_count
            ORDER BY (SELECT NULL)
        ) AS rn
    FROM dbo.swiggy_orders
)
DELETE FROM cte
WHERE rn > 1;



/* =====================================================================
   9) STAR SCHEMA: DIMENSÕES + FATO
   ORDEM:
     - Criar primeiro as dimensões
     - Depois criar a tabela fato, que depende das dimensões
       por meio de chaves estrangeiras
   ===================================================================== */

IF OBJECT_ID('dbo.fact_swiggy_orders', 'U') IS NOT NULL DROP TABLE dbo.fact_swiggy_orders;
IF OBJECT_ID('dbo.dim_dish', 'U') IS NOT NULL DROP TABLE dbo.dim_dish;
IF OBJECT_ID('dbo.dim_category', 'U') IS NOT NULL DROP TABLE dbo.dim_category;
IF OBJECT_ID('dbo.dim_restaurant', 'U') IS NOT NULL DROP TABLE dbo.dim_restaurant;
IF OBJECT_ID('dbo.dim_location', 'U') IS NOT NULL DROP TABLE dbo.dim_location;
IF OBJECT_ID('dbo.dim_date', 'U') IS NOT NULL DROP TABLE dbo.dim_date;
GO

CREATE TABLE dbo.dim_date (
    date_id     INT IDENTITY(1,1) PRIMARY KEY,
    full_date   DATE NOT NULL,
    [year]      INT  NULL,
    [month]     INT  NULL,
    month_name  VARCHAR(20) NULL,
    quarter     INT  NULL,
    [day]       INT  NULL,
    [week]      INT  NULL
);

CREATE TABLE dbo.dim_location (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    state       VARCHAR(100) NULL,
    city        VARCHAR(100) NULL,
    location    VARCHAR(200) NULL
);

CREATE TABLE dbo.dim_restaurant (
    restaurant_id   INT IDENTITY(1,1) PRIMARY KEY,
    restaurant_name VARCHAR(200) NULL
);

CREATE TABLE dbo.dim_category (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category    VARCHAR(200) NULL
);

CREATE TABLE dbo.dim_dish (
    dish_id   INT IDENTITY(1,1) PRIMARY KEY,
    dish_name VARCHAR(200) NULL
);

CREATE TABLE dbo.fact_swiggy_orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,

    -- chaves estrangeiras
    date_id INT NULL,
    location_id INT NULL,
    restaurant_id INT NULL,
    category_id INT NULL,
    dish_id INT NULL,

    -- métricas
    price_inr DECIMAL(10,2) NULL,
    rating DECIMAL(3,1) NULL,
    rating_count INT NULL,

    CONSTRAINT fk_fact_date
        FOREIGN KEY (date_id) REFERENCES dbo.dim_date(date_id),

    CONSTRAINT fk_fact_location
        FOREIGN KEY (location_id) REFERENCES dbo.dim_location(location_id),

    CONSTRAINT fk_fact_restaurant
        FOREIGN KEY (restaurant_id) REFERENCES dbo.dim_restaurant(restaurant_id),

    CONSTRAINT fk_fact_category
        FOREIGN KEY (category_id) REFERENCES dbo.dim_category(category_id),

    CONSTRAINT fk_fact_dish
        FOREIGN KEY (dish_id) REFERENCES dbo.dim_dish(dish_id)
);



/* =====================================================================
   9.1) PROTEÇÕES RECOMENDADAS: CONSTRAINTS ÚNICAS
   OBJETIVO:
     - Evitar duplicidade nas dimensões
     - Impedir que joins futuros multipliquem linhas indevidamente
       na tabela fato
   ===================================================================== */

ALTER TABLE dbo.dim_date
ADD CONSTRAINT uq_dim_date_full_date UNIQUE (full_date);

ALTER TABLE dbo.dim_location
ADD CONSTRAINT uq_dim_location UNIQUE (state, city, location);

ALTER TABLE dbo.dim_restaurant
ADD CONSTRAINT uq_dim_restaurant UNIQUE (restaurant_name);

ALTER TABLE dbo.dim_category
ADD CONSTRAINT uq_dim_category UNIQUE (category);

ALTER TABLE dbo.dim_dish
ADD CONSTRAINT uq_dim_dish UNIQUE (dish_name);



/* =====================================================================
   10) CARGA DAS DIMENSÕES
   OBJETIVO:
     - Popular as tabelas dimensão com valores distintos vindos
       da tabela limpa
   ===================================================================== */

INSERT INTO dbo.dim_date (full_date, [year], [month], month_name, quarter, [day], [week])
SELECT DISTINCT
    so.order_date,
    YEAR(so.order_date),
    MONTH(so.order_date),
    DATENAME(MONTH, so.order_date),
    DATEPART(QUARTER, so.order_date),
    DAY(so.order_date),
    DATEPART(WEEK, so.order_date)
FROM dbo.swiggy_orders so
WHERE so.order_date IS NOT NULL;

INSERT INTO dbo.dim_location (state, city, location)
SELECT DISTINCT so.state, so.city, so.location
FROM dbo.swiggy_orders so;

INSERT INTO dbo.dim_restaurant (restaurant_name)
SELECT DISTINCT so.restaurant_name
FROM dbo.swiggy_orders so
WHERE so.restaurant_name IS NOT NULL;

INSERT INTO dbo.dim_category (category)
SELECT DISTINCT so.category
FROM dbo.swiggy_orders so
WHERE so.category IS NOT NULL;

INSERT INTO dbo.dim_dish (dish_name)
SELECT DISTINCT so.dish_name
FROM dbo.swiggy_orders so
WHERE so.dish_name IS NOT NULL;



/* =====================================================================
   11) CARGA DA TABELA FATO
   OBJETIVO:
     - Converter os valores textuais da tabela limpa em IDs
       das dimensões por meio de joins
   OBSERVAÇÃO:
     - Como foram usados INNER JOINs, linhas sem correspondência
       em alguma dimensão serão excluídas da fato
   ===================================================================== */

INSERT INTO dbo.fact_swiggy_orders (
    date_id, location_id, restaurant_id, category_id, dish_id,
    price_inr, rating, rating_count
)
SELECT
    dd.date_id,
    dl.location_id,
    dr.restaurant_id,
    dc.category_id,
    ddi.dish_id,
    so.price_inr,
    so.rating,
    so.rating_count
FROM dbo.swiggy_orders so
JOIN dbo.dim_date dd
    ON so.order_date = dd.full_date
JOIN dbo.dim_location dl
    ON so.state = dl.state
   AND so.city = dl.city
   AND so.location = dl.location
JOIN dbo.dim_restaurant dr
    ON so.restaurant_name = dr.restaurant_name
JOIN dbo.dim_category dc
    ON so.category = dc.category
JOIN dbo.dim_dish ddi
    ON so.dish_name = ddi.dish_name;



/* =====================================================================
   12) VALIDAÇÕES
   12.1 Comparação de contagem de linhas entre a tabela limpa e a fato
   ===================================================================== */

SELECT COUNT(*) AS total_orders_clean
FROM dbo.swiggy_orders;

SELECT COUNT(*) AS total_orders_fact
FROM dbo.fact_swiggy_orders;



/* =====================================================================
   12.2 CONSISTÊNCIA DAS DIMENSÕES
   OBJETIVO:
     - Comparar:
       1. IDs distintos presentes na fato
       2. valores distintos da origem
       3. quantidade de linhas na dimensão
   ===================================================================== */

-- Restaurante
SELECT COUNT(DISTINCT restaurant_id) AS fact_distinct_restaurant_ids FROM dbo.fact_swiggy_orders;
SELECT COUNT(DISTINCT restaurant_name) AS source_distinct_restaurant_names FROM dbo.swiggy_orders WHERE restaurant_name IS NOT NULL;
SELECT COUNT(*) AS dim_restaurant_rows FROM dbo.dim_restaurant;

-- Categoria
SELECT COUNT(DISTINCT category_id) AS fact_distinct_category_ids FROM dbo.fact_swiggy_orders;
SELECT COUNT(DISTINCT category) AS source_distinct_categories FROM dbo.swiggy_orders WHERE category IS NOT NULL;
SELECT COUNT(*) AS dim_category_rows FROM dbo.dim_category;

-- Prato
SELECT COUNT(DISTINCT dish_id) AS fact_distinct_dish_ids FROM dbo.fact_swiggy_orders;
SELECT COUNT(DISTINCT dish_name) AS source_distinct_dishes FROM dbo.swiggy_orders WHERE dish_name IS NOT NULL;
SELECT COUNT(*) AS dim_dish_rows FROM dbo.dim_dish;

-- Localização
SELECT COUNT(DISTINCT location_id) AS fact_distinct_location_ids FROM dbo.fact_swiggy_orders;

SELECT COUNT(*) AS source_distinct_locations
FROM (
    SELECT DISTINCT state, city, location
    FROM dbo.swiggy_orders
    WHERE state IS NOT NULL AND city IS NOT NULL AND location IS NOT NULL
) x;

SELECT COUNT(*) AS dim_location_rows FROM dbo.dim_location;

-- Data
SELECT COUNT(DISTINCT date_id) AS fact_distinct_date_ids FROM dbo.fact_swiggy_orders;
SELECT COUNT(DISTINCT order_date) AS source_distinct_dates FROM dbo.swiggy_orders WHERE order_date IS NOT NULL;
SELECT COUNT(*) AS dim_date_rows FROM dbo.dim_date;



/* =====================================================================
   12.3 VERIFICAÇÃO DE ÓRFÃOS
   OBJETIVO:
     - Garantir que todos os IDs da tabela fato existam
       nas tabelas dimensão
   RESULTADO ESPERADO:
     - Todas as consultas devem retornar 0
   ===================================================================== */

SELECT COUNT(*) AS orphan_restaurant_ids
FROM dbo.fact_swiggy_orders f
LEFT JOIN dbo.dim_restaurant d ON f.restaurant_id = d.restaurant_id
WHERE d.restaurant_id IS NULL;

SELECT COUNT(*) AS orphan_category_ids
FROM dbo.fact_swiggy_orders f
LEFT JOIN dbo.dim_category d ON f.category_id = d.category_id
WHERE d.category_id IS NULL;

SELECT COUNT(*) AS orphan_dish_ids
FROM dbo.fact_swiggy_orders f
LEFT JOIN dbo.dim_dish d ON f.dish_id = d.dish_id
WHERE d.dish_id IS NULL;

SELECT COUNT(*) AS orphan_location_ids
FROM dbo.fact_swiggy_orders f
LEFT JOIN dbo.dim_location d ON f.location_id = d.location_id
WHERE d.location_id IS NULL;

SELECT COUNT(*) AS orphan_date_ids
FROM dbo.fact_swiggy_orders f
LEFT JOIN dbo.dim_date d ON f.date_id = d.date_id
WHERE d.date_id IS NULL;



/* =====================================================================
   13) CONSULTAS KPI INICIAIS
   OBJETIVO:
     - Gerar métricas básicas para análise, relatório ou dashboard
   ===================================================================== */

-- Total de pedidos
SELECT COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders;

-- Receita total (soma bruta)
SELECT SUM(price_inr) AS revenue
FROM dbo.fact_swiggy_orders;

-- Receita total formatada
SELECT FORMAT(CONVERT(FLOAT, SUM(price_inr)) / 1000000, 'N2') + ' INR Million' AS total_revenue
FROM dbo.fact_swiggy_orders;

-- Preço médio dos pratos
SELECT AVG(price_inr) AS average_dish_price
FROM dbo.fact_swiggy_orders;

-- Preço médio dos pratos formatado
SELECT FORMAT(AVG(price_inr), 'N2') + ' INR' AS average_dish_price
FROM dbo.fact_swiggy_orders;

-- Avaliação média
SELECT AVG(rating) AS average_rating
FROM dbo.fact_swiggy_orders;



/* =====================================================================
   14) ANÁLISE TEMPORAL
   ===================================================================== */

-- Pedidos por mês
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;

-- Pedidos por trimestre
SELECT
    d.year,
    d.quarter,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;

-- Pedidos por ano
SELECT
    d.year,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_date d ON f.date_id = d.date_id
GROUP BY d.year
ORDER BY d.year;

-- Pedidos por dia da semana
SELECT
    DATENAME(WEEKDAY, d.full_date) AS day_name,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_date d ON f.date_id = d.date_id
GROUP BY DATENAME(WEEKDAY, d.full_date), DATEPART(dw, d.full_date)
ORDER BY DATEPART(dw, d.full_date);



/* =====================================================================
   15) ANÁLISE DE LOCALIZAÇÃO
   ===================================================================== */

-- Top 10 cidades por volume de pedidos
SELECT TOP 10
    l.city,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_location l ON f.location_id = l.location_id
GROUP BY l.city
ORDER BY total_orders DESC;

-- Receita por estado
SELECT
    l.state,
    SUM(f.price_inr) AS total_revenue
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_location l ON f.location_id = l.location_id
GROUP BY l.state
ORDER BY total_revenue DESC;



/* =====================================================================
   16) ANÁLISE DE DESEMPENHO DOS ALIMENTOS
   ===================================================================== */

-- Top 10 restaurantes por volume de pedidos
SELECT TOP 10
    r.restaurant_name,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_restaurant r ON f.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_name
ORDER BY total_orders DESC;

-- Pedidos por categoria
SELECT
    c.category,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC;

-- Pratos mais pedidos
SELECT
    d.dish_name,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_dish d ON f.dish_id = d.dish_id
GROUP BY d.dish_name
ORDER BY total_orders DESC;

-- Avaliação média e volume de pedidos por categoria
SELECT
    c.category,
    AVG(f.rating) AS average_rating,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders f
JOIN dbo.dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC;



/* =====================================================================
   17) FAIXA DE PREÇO / INSIGHTS DE GASTO
   ===================================================================== */

SELECT
    CASE
        WHEN price_inr < 100 THEN 'Under 100'
        WHEN price_inr BETWEEN 100 AND 199 THEN '100-199'
        WHEN price_inr BETWEEN 200 AND 299 THEN '200-299'
        WHEN price_inr BETWEEN 300 AND 399 THEN '300-399'
        WHEN price_inr BETWEEN 400 AND 499 THEN '400-499'
        ELSE '500+'
    END AS price_range,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders
GROUP BY
    CASE
        WHEN price_inr < 100 THEN 'Under 100'
        WHEN price_inr BETWEEN 100 AND 199 THEN '100-199'
        WHEN price_inr BETWEEN 200 AND 299 THEN '200-299'
        WHEN price_inr BETWEEN 300 AND 399 THEN '300-399'
        WHEN price_inr BETWEEN 400 AND 499 THEN '400-499'
        ELSE '500+'
    END
ORDER BY total_orders DESC;



/* =====================================================================
   18) DISTRIBUIÇÃO DAS AVALIAÇÕES
   ===================================================================== */

SELECT
    rating,
    COUNT(*) AS total_orders
FROM dbo.fact_swiggy_orders
GROUP BY rating
ORDER BY rating DESC;