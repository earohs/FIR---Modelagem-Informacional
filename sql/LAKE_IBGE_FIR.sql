/*****
LAKE_IBGE_FIR.sql

IMPORTACAO da zona CURATED (silver) do data lake da fonte EXTERNA E PUBLICA:
IBGE - populacao residente por municipio (Censo Demografico 2022).

O data lake agora vive em Python (notebook FIR_data_lake_python.ipynb, Databricks):

  BRONZE (raw)      bronze_ibge_populacao       -> no Databricks: CSV do jeito que chegou, tudo texto,
                                                   com arquivo e data de ingestao, so cresce (append)
  SILVER (curated)  silver_populacao_municipio  -> no Databricks: limpo, tipado, sem duplicatas, com
                                                   chave normalizada (municipio sem acento + UF)
  CONSUMO           dw_fir.Endereco e views     -> aqui no PostgreSQL (ver ETLs)

Este script NAO recria o lake: ele apenas IMPORTA a silver exportada pelo notebook
(arquivo silver_populacao_municipio.csv) para a tabela lake_ibge.curated_populacao_municipio,
que e o que os ETLs leem. Os nomes e colunas da tabela foram mantidos, entao os ETLs e as
views do DW nao mudam.

Rode DEPOIS de:   DDL_oper_FIR_PT_BR.sql, DML_oper_FIR_PT_BR.sql, DW_FIR_PT_BR.sql
                  e de executar o notebook (celula "Exportar a silver") e baixar o CSV
Rode ANTES de:    ETL_carga_inicial_FIR.sql

IMPORTANTE: rode o psql na MESMA pasta onde esta o arquivo silver_populacao_municipio.csv
(o \copy usa caminho relativo). Exemplo no PowerShell:
    cd C:\caminho\da\pasta
    psql -U postgres -d fir_dw -f LAKE_IBGE_FIR.sql

Esta fonte entra no DW como NOVO ATRIBUTO da dimensao Endereco (Tipo 1 - "as is"), nao como
nova tabela de fatos. O OLTP (oper_fir) NAO e alterado: a populacao nao pertence ao
minimundo operacional, ela vem de fora.
*****/

drop schema if exists lake_ibge cascade;
create schema lake_ibge;
set search_path=lake_ibge;

-- Catalogo de dados (metadados do lake)

create table catalogo_dados
(
  NomeDataset varchar not null,
  Fonte varchar not null,
  URLFonte varchar not null,
  Formato varchar not null,
  Periodicidade varchar not null,
  Descricao varchar not null,
  ArquivoOrigem varchar,
  UltimaImportacao timestamp with time zone,
  QtdLinhasSilver int,
  PRIMARY KEY (NomeDataset)
);

insert into catalogo_dados (NomeDataset,Fonte,URLFonte,Formato,Periodicidade,Descricao,ArquivoOrigem)
values (
  'populacao_municipio',
  'IBGE - Censo Demografico 2022 (populacao residente por municipio)',
  'https://www.ibge.gov.br/estatisticas/sociais/populacao/22827',
  'CSV (exportacao do SIDRA / API de agregados do IBGE), tratado no notebook FIR_data_lake_python.ipynb',
  'Decenal (Censo) com estimativas anuais',
  'Populacao residente por municipio, com codigo IBGE. Complementa a analise de receita e sugestoes de rota da FIR com o tamanho do mercado de cada cidade.',
  'silver_populacao_municipio.csv'
);

-- Funcao que normaliza o nome do municipio para servir de chave de ligacao
-- (o OLTP da FIR grava Niteroi sem acento e o IBGE publica com acento; sem isso o join nao casa)
-- ATENCAO: a regra tem de ser a mesma da funcao chave_municipio() do notebook

create or replace function lake_ibge.chave_municipio(nome text, uf text) returns text as $$
	select upper(
		translate(regexp_replace(trim(nome), '\s+', ' ', 'g'),
			U&'\00E1\00E0\00E3\00E2\00E4\00E9\00E8\00EA\00EB\00ED\00EC\00EE\00EF\00F3\00F2\00F5\00F4\00F6\00FA\00F9\00FB\00FC\00E7\00C1\00C0\00C3\00C2\00C4\00C9\00C8\00CA\00CB\00CD\00CC\00CE\00CF\00D3\00D2\00D5\00D4\00D6\00DA\00D9\00DB\00DC\00C7',
			'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')
	) || '/' || upper(trim(uf));
$$ language sql immutable;

-- ZONA CURATED (silver) - tabela importada do notebook, mesmas colunas da silver

create table curated_populacao_municipio
(
  CodigoMunicipioIBGE varchar(7) not null,
  NomeMunicipio varchar not null,
  UF varchar(2) not null,
  PopulacaoResidente int not null,
  AnoReferencia int,
  ChaveMunicipio varchar not null,
  DataIngestao timestamp,
  PRIMARY KEY (CodigoMunicipioIBGE)
);

create unique index ix_curated_pop_chave on curated_populacao_municipio (ChaveMunicipio);

\copy curated_populacao_municipio (CodigoMunicipioIBGE, NomeMunicipio, UF, PopulacaoResidente, AnoReferencia, ChaveMunicipio, DataIngestao) from 'silver_populacao_municipio.csv' with (format csv, header true, encoding 'UTF8')

update catalogo_dados
set
	UltimaImportacao = current_timestamp,
	QtdLinhasSilver = (select count(*) from curated_populacao_municipio)
where NomeDataset = 'populacao_municipio';

-- conteudo da zona curated importada:

select * from curated_populacao_municipio order by CodigoMunicipioIBGE;

-- catalogo:

select NomeDataset, ArquivoOrigem, UltimaImportacao, QtdLinhasSilver from catalogo_dados;

-- consistencia Python x SQL - a chave gerada no notebook deve ser igual a gerada aqui (esperado: 0 linhas):

select CodigoMunicipioIBGE, NomeMunicipio, ChaveMunicipio,
       lake_ibge.chave_municipio(NomeMunicipio, UF) as ChaveRecalculadaNoPostgres
from curated_populacao_municipio
where ChaveMunicipio is distinct from lake_ibge.chave_municipio(NomeMunicipio, UF);

-- o indice unico acima impede duas linhas com a mesma chave; se a importacao falhar por
-- chave duplicada, existe nome+UF repetido na silver e o join do DW multiplicaria linhas.
