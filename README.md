# Swiggy Delivery Analytics: Pipeline de Dados End-to-End 🚀
Este projeto demonstra a transformação de dados transacionais brutos da plataforma Swiggy, da Índia, em uma solução analítica estruturada para Business Intelligence.


## 💻 Contexto Técnico
O projeto foi desenvolvido em um MacBook Air M2. Para contornar limitações de compatibilidade, utilizei Docker para executar o SQL Server em ambiente ARM, com gerenciamento do banco de dados via DBeaver.

## 🛠️ Principais Etapas do Pipeline
- **Ingestão segura de dados**  
  Criação de uma camada de staging para receber os dados brutos sem perda de informação e com suporte à auditoria de tipos.

- **Tratamento e qualidade de dados**  
  Aplicação de conversões defensivas com `TRY_CONVERT`, identificação de valores inválidos, análise de nulos e remoção de duplicidades com `ROW_NUMBER()`.

- **Modelagem analítica**  
  Construção de um **Star Schema** com tabelas fato e dimensões, otimizando a base para consultas, relatórios e dashboards.

- **Validação estrutural**  
  Verificações de integridade referencial, consistência entre tabelas e conferência de volume entre origem e modelo final.

## 🔎 Principal Observação Analítica
Durante a análise, identifiquei uma limitação importante na fonte: a ausência de padronização nos nomes dos pratos compromete a confiabilidade de métricas relacionadas a mix de produtos.  
Sem normalização prévia ou regras adicionais de negócio, esse tipo de análise pode gerar interpretações imprecisas.

## 📊 Insights de Negócio
- **Faturamento total:** aproximadamente **Rs. 53 milhões**
- **Volume transacional:** mais de **197 mil pedidos**
- **Distribuição geográfica:** forte concentração urbana, com **Karnataka** representando mais de **10% do market share**
- **Players dominantes:** redes globais como **KFC** e **McDonald's** lideram o faturamento na plataforma

## 🎯 Tecnologias Utilizadas
- SQL Server
- Docker
- DBeaver
- SQL para ETL e modelagem dimensional

## ✅ Resultado
O resultado foi uma base analítica limpa, validada e estruturada para suportar exploração de dados, geração de KPIs e construção de dashboards.