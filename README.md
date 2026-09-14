## Criação de Arquitetura do Data Warehouse da FIR Transportes

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
