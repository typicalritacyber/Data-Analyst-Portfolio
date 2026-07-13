-- Objetivo: Criar uma estrutura de dados central (vw_Grupo2) para garantir que toda a equipa cruza as mesmas tabelas vitais 
--e não há discrepância nos cálculos financeiros (dedução de custos e identificação de faturas pagas/Status=5).

CREATE VIEW vw_Grupo2 AS
 SELECT YEAR(h.OrderDate) AS Ano, 
MONTH(h.OrderDate) AS Mes,
 h.SalesOrderID AS FaturaID,
pc.Name AS Categoria,
 p.Name AS NomeProduto,
 d.OrderQty AS Quantidade, 
d.UnitPrice AS PrecoUnitario,
 d.UnitPriceDiscount AS Desconto,
 d.LineTotal AS ReceitaTotal, 
(p.StandardCost * d.OrderQty) AS CustoTotal, 
(d.LineTotal - (p.StandardCost * d.OrderQty)) AS Margem_Lucro 
FROM Sales.SalesOrderHeader h 
INNER JOIN Sales.SalesOrderDetail d 
ON h.SalesOrderID = d.SalesOrderID
 INNER JOIN Production.Product p
 ON d.ProductID = p.ProductID 
LEFT JOIN Production.ProductSubcategory ps 
ON p.ProductSubcategoryID = ps.ProductSubcategoryID 
LEFT JOIN Production.ProductCategory pc
 ON ps.ProductCategoryID = pc.ProductCategoryID
WHERE h.Status = 5;

--Testes de Integridade

-- Teste 1 - Verificar linhas de encomenda duplicadas
-- Esta consulta encontra combinações da mesma fatura (FaturaID), produto (NomeProduto),
-- mês (Mes) e ano (Ano) que aparecem mais do que uma vez
-- Duplicados podem inflacionar receita/lucro se não forem tratados

SELECT FaturaID, NomeProduto, Mes, Ano, COUNT(*) AS CountRows 
FROM vw_Grupo2 
GROUP BY FaturaID, NomeProduto, Mes, Ano 
HAVING COUNT(*) > 1;

-- Teste 2 - Verificar valores negativos ou inválidos
-- Procura linhas onde os campos numéricos são inferiores a 0,
-- o que é inválido para receita, custo, quantidade ou preço
-- ReceitaTotal, CustoTotal, Quantidade, PrecoUnitario não devem ser negativos
-- Margem_Lucro pode ser negativa (prejuízo), por isso não está incluída aqui
SELECT * 
FROM vw_Grupo2 
WHERE ReceitaTotal < 0 
  OR CustoTotal < 0 
  OR Quantidade < 1 
  OR PrecoUnitario < 0;

-- Teste 3 - Verificar se os valores do mês são válidos
-- Mes deve estar entre 1 e 12
SELECT DISTINCT Mes FROM vw_Grupo2 ORDER BY Mes;

-- Teste 4 - Verificar se os valores do ano são razoáveis
-- Esta consulta lista todos os anos distintos presentes nos dados
SELECT DISTINCT Ano FROM vw_Grupo2 ORDER BY Ano;

-- Teste 5 - Verificar consistência das categorias
-- Lista todas as categorias de produto distintas presentes
-- Ajuda a identificar categorias em falta ou inconsistentes
SELECT DISTINCT Categoria FROM vw_Grupo2;

-- Teste 6 - Verificar intervalos de desconto
-- Retorna os valores mínimo e máximo de Desconto
-- Os descontos devem estar dentro de um intervalo razoável (ex.: 0–1)
SELECT MIN(Desconto), MAX(Desconto) FROM vw_Grupo2;

-- Teste de Integridade 7: Verificação de Nulos em colunas críticas 
-- Objetivo: Garantir que não existem vendas sem lucro calculado ou sem categoria atribuída 
SELECT FaturaID,
NomeProduto, 
Categoria,
 Margem_Lucro 
FROM vw_Grupo2 
WHERE Margem_Lucro IS NULL
 OR Categoria IS NULL;

 --Teste de Integridade 8: Consistência Financeira 
 -- Objetivo: Garantir que a Margem de Lucro segue a lógica (Receita - Custo) 
 -- Se houver falhas aqui, o "Data Panel" teria erro de cálculo. 

SELECT FaturaID,
 ReceitaTotal, 
CustoTotal, 
Margem_Lucro 
FROM vw_Grupo2 
WHERE ABS(Margem_Lucro - (ReceitaTotal - CustoTotal)) > 0.01;

---- Teste de Viabilidade 1: Representatividade por Categoria 
-- Objetivo: Verificar se temos vendas suficientes com e sem desconto em todas as categorias 
-- Se uma categoria tiver 0 descontos, não podemos fazer a "Autópsia". 

SELECT Categoria, 
COUNT(*) AS TotalVendas, 
SUM(CASE WHEN Desconto > 0 THEN 1 ELSE 0 END) AS VendasComDesconto, SUM(CASE WHEN Desconto = 0 THEN 1 ELSE 0 END) AS VendasSemDesconto
 FROM vw_Grupo2 
GROUP BY Categoria;

 -- Teste de Viabilidade 2: Cobertura Temporal 
 -- Objetivo: Confirmar se temos dados de todos os meses para evitar conclusões baseadas em anos incompletos. 

SELECT Ano, 
COUNT(DISTINCT Mes) AS MesesComDados 
FROM vw_Grupo2 
GROUP BY Ano;



--TEMA 1 - Sazonalidade
-- Agrupar por mês e ano
SELECT  
   Ano, 
   Mes, 
   SUM(ReceitaTotal) AS Receita_Mensal, 
   SUM(Margem_Lucro) AS Lucro_Mensal 
FROM vw_Grupo2 
GROUP BY Ano, Mes 
ORDER BY Ano, Mes;

-- Média agrupada por mês
SELECT  
   Mes, 
   AVG(ReceitaTotal) AS Receita_Media, 
   AVG(Margem_Lucro) AS Lucro_Medio 
FROM vw_Grupo2 
GROUP BY Mes 
ORDER BY Mes;

-- Média agrupada por ano
SELECT  
   Ano, 
   AVG(ReceitaTotal) AS Receita_Media, 
   AVG(Margem_Lucro) AS Lucro_Medio 
FROM vw_Grupo2 
GROUP BY Ano 
ORDER BY Ano;

-- Calcula valores médios para meses específicos (abril e junho) de 2012
-- Ajuda a comparar estes meses com a média geral para entender por que o lucro foi negativo
SELECT  
   Ano, 
   Mes, 
   AVG(Desconto) AS Avg_Desconto, 
   AVG(CustoTotal) AS Avg_Custo, 
   AVG(ReceitaTotal) AS Avg_Receita 
FROM vw_Grupo2 
WHERE Ano = 2012 AND Mes IN (4,6) 
GROUP BY Ano, Mes;

-- Calcula a receita total e o lucro total geral
-- Soma todas as transações na vista vw_Grupo2
SELECT  
   SUM(ReceitaTotal) AS Receita_Total,   -- Receita total de todas as vendas
   SUM(Margem_Lucro) AS Lucro_Total      -- Lucro total (receita menos custo) de todas as vendas
FROM vw_Grupo2;                          -- Vista de origem com dados transacionais

-- Calcula o lucro mensal total por ano 
-- e classifica os meses dentro de cada ano com base no lucro
SELECT  
   Ano,                                  
   Mes,                                  
   SUM(Margem_Lucro) AS Margem_Total,    -- Lucro total desse mês (soma de receita menos custo)
   RANK() OVER (PARTITION BY Ano 
                ORDER BY SUM(Margem_Lucro) DESC) AS Ranking_Mensal
                                         -- Atribui uma classificação a cada mês dentro do mesmo ano
                                         -- Rank 1 = maior lucro total
FROM vw_Grupo2 
GROUP BY Ano, Mes                         
ORDER BY Ano, Ranking_Mensal;      

-- Calcula o lucro total de cada trimestre de cada ano
-- e classifica os trimestres dentro do mesmo ano com base no lucro total
SELECT  
   Ano,                                   
   DATEPART(QUARTER, DATEFROMPARTS(Ano, Mes, 1)) AS Trimestre,  
                                          -- Calcula o trimestre (1–4) a partir do ano e mês
   SUM(Margem_Lucro) AS Margem_Total,     -- Lucro total do trimestre (soma de receita menos custo)
   RANK() OVER (PARTITION BY Ano 
                ORDER BY SUM(Margem_Lucro) DESC) AS Ranking_Trimestral
                                          -- Atribui uma classificação a cada trimestre dentro do mesmo ano
                                          -- Rank 1 = trimestre com maior lucro
FROM vw_Grupo2 
GROUP BY  
   Ano, 
   DATEPART(QUARTER, DATEFROMPARTS(Ano, Mes, 1))  
                                          -- Agrupa o lucro por ano e trimestre
ORDER BY Ano, Ranking_Trimestral;


-- Tema 2: Crescimento de Receita e Rentabilidade 

SELECT 
    Ano,
    CAST(SUM(ReceitaTotal) AS DECIMAL(18,2)) AS Receita_Total,
    CAST(SUM(Margem_Lucro) AS DECIMAL(18,2)) AS Lucro_Total
FROM vw_Grupo2
GROUP BY Ano
ORDER BY Ano;
/*
Ações do código
SELECT Ano
- Escolhe o ano como base da análise
SUM(ReceitaTotal)
- Soma toda a receita de cada ano
SUM(Margem_Lucro)
- Soma todo o lucro de cada ano
CAST(... DECIMAL(18,2))
- Formata os valores com 2 casas decimais
FROM vw_Grupo2
- Vai buscar os dados já limpos e preparados
GROUP BY Ano
- Agrupa os dados por ano (1 linha por ano)
ORDER BY Ano
- Organiza os resultados por ordem cronológica
*/

SELECT 
    Ano,
    Mes,
    SUM(ReceitaTotal) AS Receita_Mensal,
    SUM(Margem_Lucro) AS Lucro_Mensal
FROM vw_Grupo2
GROUP BY Ano, Mes
ORDER BY Ano, Mes;
/*
Ações do código
SELECT Ano, Mes
- Define o nível de detalhe (ano + mês)
SUM(ReceitaTotal)
- Calcula a receita total de cada mês
SUM(Margem_Lucro)
- Calcula o lucro total de cada mês
FROM vw_Grupo2
- Usa a base de dados preparada
GROUP BY Ano, Mes
- Agrupa por cada mês de cada ano
ORDER BY Ano, Mes
- Ordena cronologicamente (timeline correta);
*/

WITH ReceitaPorAno AS (
    SELECT 
        Ano,
        SUM(ReceitaTotal) AS Receita_Total
    FROM vw_Grupo2
    GROUP BY Ano
)
SELECT 
    Ano,
    Receita_Total,
    Receita_Total - LAG(Receita_Total) OVER (ORDER BY Ano) AS Crescimento_Anual
FROM ReceitaPorAno;
/*
Ações do código
CTE (primeira parte)
WITH ReceitaPorAno AS (...)
- Cria uma tabela temporária
SUM(ReceitaTotal)
- Calcula a receita total por ano
GROUP BY Ano
- Garante 1 valor por ano

Query final
SELECT Ano, Receita_Total
- Mostra os valores calculados
LAG(Receita_Total)
- Vai buscar a receita do ano anterior
OVER (ORDER BY Ano)
- Define a ordem temporal (importante para o LAG)
Receita_Total - LAG(...)
- Calcula o crescimento entre anos;
*/


--TEMA 3: Lucratividade e Descontos 

-- TESTE EXPLORATÓRIO 1: Frequência de Aplicação de Descontos 
-- Objetivo: Perceber o peso das promoções no volume total de operações 
-- da empresa, calculando a percentagem de linhas faturadas com desconto. 

SELECT COUNT(*) AS Total_Linhas_Faturadas,
 SUM(CASE WHEN Desconto > 0 THEN 1 ELSE 0 END) AS Linhas_Com_Desconto, 
 ROUND((CAST(SUM(CASE WHEN Desconto > 0 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 2) AS Percentagem_Com_Desconto 
FROM vw_Grupo2;


--TESTE EXPLORATÓRIO 2: Identificação do "Bottom 5" (Os Piores Infratores) 
-- Objetivo: Aprofundar o prejuízo detetado na categoria 'Bicicletas', 
-- identificando os 5 modelos específicos que mais dinheiro destruíram 
-- quando vendidos com desconto financeiro. 

SELECT TOP 5 NomeProduto,
 Categoria, 
SUM(Quantidade) AS Volume_Vendido_Com_Desconto, 
ROUND(SUM(Margem_Lucro), 2) AS Prejuizo_Total
 FROM vw_Grupo2 
WHERE Desconto > 0 AND Categoria = 'Bikes'
 GROUP BY NomeProduto,
 Categoria ORDER BY Prejuizo_Total ASC


 -- As Queries de Autópsia e Recomendações

--Query Principal 1(Tema 3): O Impacto Global e a Segmentação por Categoria 
-- Objetivo: Comparar a tração de volume e a destruição/criação de margem média separando o cenário com e sem promoção por categoria de produto.

SELECT CASE 
WHEN Desconto > 0 THEN 'Com Desconto' 
ELSE 'Sem Desconto' 
END AS Estrategia_Preco, 
Categoria, 
AVG(Quantidade) AS Media_Unidades_Compradas,
 ROUND(AVG(Margem_Lucro), 2) AS Media_Lucro_Por_Linha 
FROM vw_Grupo2
GROUP BY Categoria, CASE WHEN Desconto > 0 THEN 'Com Desconto' ELSE 'Sem Desconto' END


 --Query Principal 2: A Linha Temporal da Estratégia de Preços 
 -- Objetivo: Acompanhar o aumento crónico do uso de descontos por ano fiscal e expor o impacto destrutivo dessa tática na Margem de Lucro anual.

Select Ano,
Case
When Desconto > 0 then 'Com Desconto'
Else 'Sem Desconto'
End 'Estrategia Preco',
Count (*) as Total_Vendas,
FORMAT (Sum (Margem_Lucro), 'N2') as Total_Lucro
From vw_Grupo2
Group by Ano,
Case
When Desconto > 0 then 'Com Desconto'
Else 'Sem Desconto'
End 
Order By Ano asc


 --A Elasticidade do Desconto (A Ilusão do Volume) 
 -- Objetivo: Calcular a curva exata de resposta do consumidor. 
 --Isolar os escalões de desconto para provar que descontos superiores a 10% causam quebra no volume e disparo do prejuízo.

SELECT Desconto, 
AVG(Quantidade) AS Media_Unidades, 
ROUND(AVG(Margem_Lucro), 2) AS Media_Lucro 
FROM vw_Grupo2 
WHERE Desconto > 0
 GROUP BY Desconto
 ORDER BY Desconto ASC


-- O Top 10 Intocável (Proteger o Núcleo) 
-- Objetivo: Identificar os 10 produtos heróis com maior Margem de Lucro Acumulada para os bloquear de campanhas promocionais futuras.

SELECT TOP 10 NomeProduto, 
Categoria, 
SUM(Quantidade) AS Total_Quantidade, 
ROUND(SUM(Margem_Lucro), 2) AS Total_Margem_Lucro 
FROM vw_Grupo2 
GROUP BY NomeProduto, Categoria 
ORDER BY Total_Margem_Lucro DESC
