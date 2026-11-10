## Criação de Arquitetura do Data Warehouse da FIR Transportes

A partir de um banco de dados transacional (OLTP) da FIR Transportes fictício, modelado via DDL e populado via DML, projetamos um Data Warehouse dimensional e implementamos processos de ETL de carga inicial e carga incremental — esta última baseada em captura de mudanças (CDC) via triggers. Uma fonte externa e pública (população por município, IBGE) é tratada em um data lake em Python (Databricks), em camadas bronze e silver (esta é importada para o DW). Além disso, simulamos operações OLAP através de tabelas dinâmicas do Excel conectadas às views do DW.

### Data lake (Databricks) — antes da etapa 5
1. Executar todas as células de `FIR_data_lake_python.ipynb` no Databricks.
2. Baixar o arquivo `silver_populacao_municipio.csv`, gerado na última célula,
   e salvá-lo na pasta `sql/`.

### Comandos rodados a partir da raiz do repositório
```
cd sql/
```

#### 1. cria o banco
```
createdb fir_dw
```

#### 2. schema de origem (oper_fir) - DDL
```
psql -d fir_dw -v ON_ERROR_STOP=1 -f DDL_oper_FIR_PT_BR.sql
```

#### 3. dados de exemplo - DML
```
psql -d fir_dw -v ON_ERROR_STOP=1 -f DML_oper_FIR_PT_BR.sql
```

#### 4. schema do Data Warehouse (dw_fir)
```
psql -d fir_dw -v ON_ERROR_STOP=1 -f DW_FIR_PT_BR.sql
```

#### 5. importa a silver do data lake (lake_ibge) - população por município (IBGE)
Requer o arquivo `silver_populacao_municipio.csv` na pasta `sql/`.
```
psql -d fir_dw -v ON_ERROR_STOP=1 -f LAKE_IBGE_FIR.sql
```

#### 6. carga inicial (popula as dimensões e os 4 fatos)
```
psql -d fir_dw -v ON_ERROR_STOP=1 -f ETL_carga_inicial_FIR.sql
```

#### 7. cria triggers de auditoria/CDC + roda o primeiro incremental de teste
```
psql -d fir_dw -v ON_ERROR_STOP=1 -f ETL_incremental_FIR.sql
```