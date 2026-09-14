## Criação de Arquitetura do Data Warehouse da FIR Transportes

A partir de um banco de dados transacional (OLTP) da FIR Transportes fictício, modelado via DDL e populado via DML, projetamos um Data Warehouse dimensional e implementamos processos de ETL de carga inicial e carga incremental — esta última baseada em captura de mudanças (CDC) via triggers. Além de algumas simulações de operações OLAP através de tabelas dinâmicas do Excel conectadas às views do DW.

### Comandos rodados a partir da raiz do repositório
```
cd sql/
```

#### 1. cria o banco
```
createdb fir_dw
```

#### 2. schema de origem (oper_fir) - DML
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

#### 5. carga inicial (popula as dimensões e os 4 fatos)
```
psql -d fir_dw -v ON_ERROR_STOP=1 -f ETL_carga_inicial_FIR.sql
```

#### 6. cria triggers de auditoria/CDC + roda o primeiro incremental de teste
```
psql -d fir_dw -v ON_ERROR_STOP=1 -f ETL_incremental_FIR.sql
```
