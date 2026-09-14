/*****

PARTE INCREMENTAL

https://bryteflow.com/postgres-cdc-6-easy-methods-capture-data-changes/#:~:text=5.,%2DAhead%20Log%20(WAL).

****/

Drop schema if exists audit cascade;
create schema audit;
set search_path=audit;

/****
-- Gravar as alterações em uma tabela (log geral, para toda a base oper_fir)
****/
create table audit.historico_mudancas_fir (
schema_name text not null,
table_name text not null,
user_name text,
action_tstamp timestamp with time zone not null default current_timestamp,
action TEXT NOT NULL check (action in ('I','D','U')),
original_data text,
new_data text,
query text
) with (fillfactor=100);

/***

Função de trigger para gravar as alterações de forma geral
(a mesma função usada na base ZAGI)

****/

CREATE OR REPLACE FUNCTION audit.if_modified_func() RETURNS trigger AS $body$
DECLARE
    v_old_data TEXT;
    v_new_data TEXT;
BEGIN
if (TG_OP = 'UPDATE') then
v_old_data := ROW(OLD.*);
v_new_data := ROW(NEW.*);
insert into audit.historico_mudancas_fir (schema_name,table_name,user_name,action,original_data,new_data,query)
values (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_old_data,v_new_data, current_query());
RETURN NEW;
elsif (TG_OP = 'DELETE') then
v_old_data := ROW(OLD.*);
insert into audit.historico_mudancas_fir (schema_name,table_name,user_name,action,original_data,query)
values (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_old_data, current_query());
RETURN OLD;
elsif (TG_OP = 'INSERT') then
v_new_data := ROW(NEW.*);
insert into audit.historico_mudancas_fir (schema_name,table_name,user_name,action,new_data,query)
values (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_new_data, current_query());
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN data_exception THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [DATA EXCEPTION] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
WHEN unique_violation THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [UNIQUE] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;


-- Trigger de log geral em todas as tabelas transacionais da FIR

CREATE TRIGGER Funcionario_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.Funcionario
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER PagamentoFuncionario_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.PagamentoFuncionario
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER Veiculo_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.Veiculo
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER Manutencao_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.Manutencao
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER Endereco_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.Endereco
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER Passageiro_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.Passageiro
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER Rota_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.Rota
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER AvisoRota_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.AvisoRota
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER RotaPassageiro_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.RotaPassageiro
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();

CREATE TRIGGER SugestaoRota_if_modified_trg
AFTER INSERT OR UPDATE OR DELETE ON oper_fir.SugestaoRota
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


/***
Trigger para salvar inserções da tabela PagamentoFuncionario
(tabela "espelho" só com INSERT, usada depois para alimentar o fato)
***/

Create table audit.ins_PagamentoFuncionario as select * from oper_fir.PagamentoFuncionario where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_PagamentoFuncionario_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_PagamentoFuncionario values (NEW.PagamentoID,NEW.FuncionarioID,NEW.PagamentoData,NEW.PagamentoValorPago,NEW.PagamentoValorImposto);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER PagamentoFuncionario_insert_trg
AFTER INSERT ON oper_fir.PagamentoFuncionario
FOR EACH ROW EXECUTE PROCEDURE audit.ins_PagamentoFuncionario_func();

/***
Trigger para salvar inserções da tabela Manutencao
***/

Create table audit.ins_Manutencao as select * from oper_fir.Manutencao where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_Manutencao_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_Manutencao values (NEW.ManutencaoID,NEW.VeiculoID,NEW.ManutencaoData,NEW.ManutencaoDescricao,NEW.ManutencaoValorDespesa);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER Manutencao_insert_trg
AFTER INSERT ON oper_fir.Manutencao
FOR EACH ROW EXECUTE PROCEDURE audit.ins_Manutencao_func();

/***
Trigger para salvar inserções da tabela Rota
***/

Create table audit.ins_Rota as select * from oper_fir.Rota where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_Rota_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_Rota values (NEW.RotaID,NEW.VeiculoID,NEW.MotoristaID,NEW.EnderecoOrigemID,NEW.EnderecoDestinoID,NEW.RotaInicio,NEW.RotaFim,NEW.RotaValorPassagem);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER Rota_insert_trg
AFTER INSERT ON oper_fir.Rota
FOR EACH ROW EXECUTE PROCEDURE audit.ins_Rota_func();

/***
Trigger para salvar inserções da tabela RotaPassageiro
***/

Create table audit.ins_RotaPassageiro as select * from oper_fir.RotaPassageiro where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_RotaPassageiro_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_RotaPassageiro values (NEW.RotaID,NEW.PassageiroID,NEW.RotaPassageiroValorPago,NEW.RotaPassageiroDataPagamento);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER RotaPassageiro_insert_trg
AFTER INSERT ON oper_fir.RotaPassageiro
FOR EACH ROW EXECUTE PROCEDURE audit.ins_RotaPassageiro_func();

/***
Trigger para salvar inserções da tabela SugestaoRota
***/

Create table audit.ins_SugestaoRota as select * from oper_fir.SugestaoRota where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_SugestaoRota_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_SugestaoRota values (NEW.SugestaoID,NEW.PassageiroID,NEW.EnderecoID,NEW.SugestaoIndicacao,NEW.SugestaoDataPrevista,NEW.SugestaoDataRegistro);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER SugestaoRota_insert_trg
AFTER INSERT ON oper_fir.SugestaoRota
FOR EACH ROW EXECUTE PROCEDURE audit.ins_SugestaoRota_func();

-- Funcionario, Veiculo, Passageiro e Endereco - exemplos de dimensao
-- (o log geral já existe pelas triggers *_if_modified_trg criadas acima;
--  falta apenas a tabela espelho para pegar só as linhas novas)

Create table audit.ins_Funcionario as select * from oper_fir.Funcionario where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_Funcionario_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_Funcionario values (NEW.FuncionarioID,NEW.FuncionarioNome,NEW.FuncionarioCPF,NEW.FuncionarioSalario,NEW.FuncionarioCategoria);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER Funcionario_insert_trg
AFTER INSERT ON oper_fir.Funcionario
FOR EACH ROW EXECUTE PROCEDURE audit.ins_Funcionario_func();

Create table audit.ins_Veiculo as select * from oper_fir.Veiculo where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_Veiculo_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_Veiculo values (NEW.VeiculoID,NEW.VeiculoPlaca,NEW.VeiculoTipo,NEW.VeiculoDescricao);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER Veiculo_insert_trg
AFTER INSERT ON oper_fir.Veiculo
FOR EACH ROW EXECUTE PROCEDURE audit.ins_Veiculo_func();

Create table audit.ins_Passageiro as select * from oper_fir.Passageiro where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_Passageiro_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_Passageiro values (NEW.PassageiroID,NEW.PassageiroNome,NEW.PassageiroCPF,NEW.PassageiroDataNascimento,NEW.PassageiroFormaPagamento);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER Passageiro_insert_trg
AFTER INSERT ON oper_fir.Passageiro
FOR EACH ROW EXECUTE PROCEDURE audit.ins_Passageiro_func();

Create table audit.ins_Endereco as select * from oper_fir.Endereco where 1=0;

CREATE OR REPLACE FUNCTION audit.ins_Endereco_func() RETURNS trigger AS $body$
BEGIN
if (TG_OP = 'INSERT') then
insert into audit.ins_Endereco values (NEW.EnderecoID,NEW.EnderecoCEP,NEW.EnderecoLogradouro,NEW.EnderecoNumero,NEW.EnderecoMunicipio,NEW.EnderecoUF,NEW.EnderecoPontoReferencia);
RETURN NEW;
else
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
RETURN NULL;
end if;

EXCEPTION
WHEN others THEN
RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit;

CREATE TRIGGER Endereco_insert_trg
AFTER INSERT ON oper_fir.Endereco
FOR EACH ROW EXECUTE PROCEDURE audit.ins_Endereco_func();


/****
Apagar o trigger no caso de começar do zero:

DROP TRIGGER Rota_if_modified_trg on oper_fir.Rota;
*****/

-- TESTE EXEMPLO
-- registro de nova manutencao, novo pagamento e rota nova com um passageiro embarcado

/*
Veiculo
 1 | RJA1B23 (Onibus)

Funcionario
 2 | Bruno Lima (Motorista)

Passageiro
 1 | Diego Alves
*/

INSERT INTO oper_fir.Manutencao (VeiculoID,ManutencaoData,ManutencaoDescricao,ManutencaoValorDespesa)
SELECT 1,'2025-07-10','Troca de pneus',1500
WHERE NOT EXISTS (
  SELECT 1 FROM oper_fir.Manutencao WHERE VeiculoID=1 AND ManutencaoData='2025-07-10'
);

INSERT INTO oper_fir.PagamentoFuncionario (FuncionarioID,PagamentoData,PagamentoValorPago,PagamentoValorImposto)
SELECT 2,'2025-07-05',3800,646
WHERE NOT EXISTS (
  SELECT 1 FROM oper_fir.PagamentoFuncionario WHERE FuncionarioID=2 AND PagamentoData='2025-07-05'
);

INSERT INTO oper_fir.Rota (VeiculoID,MotoristaID,EnderecoOrigemID,EnderecoDestinoID,RotaInicio,RotaFim,RotaValorPassagem)
SELECT 1,2,1,3,'2025-07-11 07:00-03','2025-07-11 08:05-03',15.00
WHERE NOT EXISTS (
  SELECT 1 FROM oper_fir.Rota WHERE RotaID=3
);

INSERT INTO oper_fir.RotaPassageiro (RotaID,PassageiroID,RotaPassageiroValorPago,RotaPassageiroDataPagamento)
SELECT 3,1,15.00,'2025-07-11 07:02-03'
WHERE NOT EXISTS (
  SELECT 1 FROM oper_fir.RotaPassageiro WHERE RotaID=3 AND PassageiroID=1
);

-- Cliente novo - exemplo de dimensao (Passageiro, no caso da FIR)

INSERT INTO oper_fir.Passageiro (PassageiroNome,PassageiroCPF,PassageiroDataNascimento,PassageiroFormaPagamento)
VALUES ('Manuela Prado','66666666666','1995-03-20','DEBITO');


/*****

Atualizar calendário

repete a mesma instrução da carga inicial

O resultado esperado é apenas a data das transações inserida depois da carga inicial

******/

insert into dw_fir.Calendario
select
	gen_random_uuid(),
	a.datacompleta,
	a.diasemana,
	a.dia,
	a.mes,
	a.trimestre,
	a.ano
from (
	select distinct
		cast(dt as date) as datacompleta,
		to_char(dt, 'DY') as diasemana,
		extract(day from dt) as dia,
		to_char(dt, 'MM') as mes,
		cast(to_char(dt, 'Q') as int) as trimestre,
		extract(year from dt) as ano
	from (
		select RotaInicio as dt from oper_fir.Rota
		union select RotaFim from oper_fir.Rota where RotaFim is not null
		union select RotaPassageiroDataPagamento from oper_fir.RotaPassageiro
		union select SugestaoDataPrevista from oper_fir.SugestaoRota
		union select SugestaoDataRegistro from oper_fir.SugestaoRota
		union select cast(PagamentoData as timestamp with time zone) from oper_fir.PagamentoFuncionario
		union select cast(ManutencaoData as timestamp with time zone) from oper_fir.Manutencao
	) as todas_as_datas
	where cast(dt as date) not in (select DataCompleta from dw_fir.Calendario)
	) as a;

-- Atualizar dimensão Passageiro
-- MODO 1 apenas, devido à surrogate key

INSERT INTO dw_fir.Passageiro
select
	gen_random_uuid(),
	p.PassageiroID,
	p.PassageiroNome,
	p.PassageiroCPF,
	p.PassageiroDataNascimento,
	p.PassageiroFormaPagamento
from
	audit.ins_Passageiro p;

truncate table audit.ins_Passageiro;

-- Atualizar dimensão Funcionario, Veiculo e Endereco (mesma logica: só o que é novo)

INSERT INTO dw_fir.Funcionario
select
	gen_random_uuid(),
	f.FuncionarioID,
	f.FuncionarioNome,
	case f.FuncionarioCategoria when 'A' then 'Administrativo' else 'Motorista' end,
	f.FuncionarioSalario,
	m.MotoristaCNH,
	m.MotoristaCategoriaCNH
from
	audit.ins_Funcionario f left join oper_fir.Motorista m on m.FuncionarioID=f.FuncionarioID;

truncate table audit.ins_Funcionario;

INSERT INTO dw_fir.Veiculo
select gen_random_uuid(), v.VeiculoID, v.VeiculoPlaca,
       case v.VeiculoTipo when 'C' then 'Carro' else 'Onibus' end, v.VeiculoDescricao
from audit.ins_Veiculo v;

truncate table audit.ins_Veiculo;

INSERT INTO dw_fir.Endereco
select gen_random_uuid(), e.EnderecoID, e.EnderecoCEP, e.EnderecoLogradouro,
       e.EnderecoMunicipio, e.EnderecoUF, e.EnderecoPontoReferencia
from audit.ins_Endereco e;

truncate table audit.ins_Endereco;

-- atualização do fato despesa
-- tomar nota da quantidade de linhas

select * from dw_fir.FatoDespesa;

-- só funciona se as tabelas espelho (audit.ins_PagamentoFuncionario / audit.ins_Manutencao)
-- ainda tiverem as linhas novas (por isso truncamos só depois de carregar)

-- MODO 1 - rápido, apenas novas transações das tabelas de auditoria

insert into dw_fir.FatoDespesa
select
	pg.PagamentoID,
	'Pagamento Funcionario',
	'Pagamento de salario - ' || f.FuncionarioNome,
	pg.PagamentoValorPago + pg.PagamentoValorImposto,
	pg.PagamentoValorPago,
	pg.PagamentoValorImposto,
	dwcal.ChaveCalendario,
	dwf.ChaveFuncionario,
	null
from
	audit.ins_PagamentoFuncionario pg inner join oper_fir.Funcionario f on f.FuncionarioID=pg.FuncionarioID
	inner join dw_fir.Funcionario dwf on dwf.IDFuncionario=pg.FuncionarioID
	inner join dw_fir.Calendario dwcal on dwcal.DataCompleta=cast(pg.PagamentoData as date);

insert into dw_fir.FatoDespesa
select
	mn.ManutencaoID,
	'Manutencao Veiculo',
	mn.ManutencaoDescricao,
	mn.ManutencaoValorDespesa,
	mn.ManutencaoValorDespesa,
	0::money,
	dwcal.ChaveCalendario,
	null,
	dwv.ChaveVeiculo
from
	audit.ins_Manutencao mn inner join dw_fir.Veiculo dwv on dwv.IDVeiculo=mn.VeiculoID
	inner join dw_fir.Calendario dwcal on dwcal.DataCompleta=cast(mn.ManutencaoData as date);

-- MODO 2 - lento, a diferença entre a base OPER e o DW - opção mais pesada

-- select
-- 	pg.PagamentoID, 'Pagamento Funcionario', 'Pagamento de salario - ' || f.FuncionarioNome,
-- 	pg.PagamentoValorPago + pg.PagamentoValorImposto, pg.PagamentoValorPago, pg.PagamentoValorImposto,
-- 	dwcal.ChaveCalendario, dwf.ChaveFuncionario, null
-- from
-- 	oper_fir.PagamentoFuncionario pg inner join oper_fir.Funcionario f on f.FuncionarioID=pg.FuncionarioID
-- 	inner join dw_fir.Funcionario dwf on dwf.IDFuncionario=pg.FuncionarioID
-- 	inner join dw_fir.Calendario dwcal on dwcal.DataCompleta=cast(pg.PagamentoData as date)
-- EXCEPT
-- SELECT IDOrigemDespesa, TipoDespesa, DescricaoDespesa, ValorDespesa, ValorLiquido, ValorImposto,
--        ChaveCalendario, ChaveFuncionario, ChaveVeiculo
-- FROM dw_fir.FatoDespesa WHERE TipoDespesa='Pagamento Funcionario';

truncate table audit.ins_PagamentoFuncionario;
truncate table audit.ins_Manutencao;

-- atualização do fato receita passagem e do fato rota
-- ambos dependem de Rota + RotaPassageiro + AvisoRota

insert into dw_fir.FatoReceitaPassagem
select
	rp.RotaID,
	rp.PassageiroID,
	rp.RotaPassageiroDataPagamento,
	rp.RotaPassageiroValorPago,
	r.RotaValorPassagem,
	r.RotaValorPassagem - rp.RotaPassageiroValorPago,
	case
		when exists (select 1 from oper_fir.AvisoRota av where av.RotaID=r.RotaID and av.AvisoTipo='C') then 'Cancelada'
		when exists (select 1 from oper_fir.AvisoRota av where av.RotaID=r.RotaID and av.AvisoTipo='A') then 'Concluida com atraso'
		when r.RotaFim is not null then 'Concluida'
		else 'Em andamento'
	end,
	dwcal.ChaveCalendario,
	dwp.ChavePassageiro,
	dwf.ChaveFuncionario,
	dwv.ChaveVeiculo,
	dweo.ChaveEndereco,
	dwed.ChaveEndereco
from
	audit.ins_RotaPassageiro rp inner join oper_fir.Rota r on r.RotaID=rp.RotaID
	inner join dw_fir.Passageiro dwp on dwp.IDPassageiro=rp.PassageiroID
	inner join dw_fir.Funcionario dwf on dwf.IDFuncionario=r.MotoristaID
	inner join dw_fir.Veiculo dwv on dwv.IDVeiculo=r.VeiculoID
	inner join dw_fir.Endereco dweo on dweo.IDEndereco=r.EnderecoOrigemID
	inner join dw_fir.Endereco dwed on dwed.IDEndereco=r.EnderecoDestinoID
	inner join dw_fir.Calendario dwcal on dwcal.DataCompleta=cast(rp.RotaPassageiroDataPagamento as date);

truncate table audit.ins_RotaPassageiro;

/****
Atenção: FatoRota é um snapshot que precisa ser recriado sempre que a rota
muda (por exemplo quando RotaFim é preenchido depois, ou quando chega um
aviso de atraso/cancelamento). A tabela espelho audit.ins_Rota só guarda
o INSERT original da rota; por isso apagamos a linha antiga do fato antes
de inserir a versão atual, lendo direto de oper_fir (e não do espelho).
****/

delete from dw_fir.FatoRota
where IDRota in (select RotaID from audit.ins_Rota)
   or IDRota in (select RotaID from oper_fir.AvisoRota where AvisoData > current_date - interval '1 day');

insert into dw_fir.FatoRota
select
	r.RotaID,
	r.RotaInicio,
	r.RotaFim,
	case
		when exists (select 1 from oper_fir.AvisoRota av where av.RotaID=r.RotaID and av.AvisoTipo='C') then 'Cancelada'
		when exists (select 1 from oper_fir.AvisoRota av where av.RotaID=r.RotaID and av.AvisoTipo='A') then 'Concluida com atraso'
		when r.RotaFim is not null then 'Concluida'
		else 'Em andamento'
	end,
	r.RotaValorPassagem,
	coalesce(pax.qtd,0),
	coalesce(pax.receita,0::money),
	case when r.RotaFim is not null then extract(epoch from (r.RotaFim - r.RotaInicio))/60 end,
	coalesce(av.qtdatraso,0),
	coalesce(av.qtdcancel,0),
	dwcalini.ChaveCalendario,
	dwcalfim.ChaveCalendario,
	dwv.ChaveVeiculo,
	dwf.ChaveFuncionario,
	dweo.ChaveEndereco,
	dwed.ChaveEndereco
from
	oper_fir.Rota r
	left join (select RotaID, count(*) as qtd, sum(RotaPassageiroValorPago) as receita
	           from oper_fir.RotaPassageiro group by RotaID) pax on pax.RotaID=r.RotaID
	left join (select RotaID,
	                  count(*) filter (where AvisoTipo='A') as qtdatraso,
	                  count(*) filter (where AvisoTipo='C') as qtdcancel
	           from oper_fir.AvisoRota group by RotaID) av on av.RotaID=r.RotaID
	inner join dw_fir.Veiculo dwv on dwv.IDVeiculo=r.VeiculoID
	inner join dw_fir.Funcionario dwf on dwf.IDFuncionario=r.MotoristaID
	inner join dw_fir.Endereco dweo on dweo.IDEndereco=r.EnderecoOrigemID
	inner join dw_fir.Endereco dwed on dwed.IDEndereco=r.EnderecoDestinoID
	inner join dw_fir.Calendario dwcalini on dwcalini.DataCompleta=cast(r.RotaInicio as date)
	left join dw_fir.Calendario dwcalfim on dwcalfim.DataCompleta=cast(r.RotaFim as date)
where
	r.RotaID not in (select IDRota from dw_fir.FatoRota);

truncate table audit.ins_Rota;

-- atualização do fato sugestão de rota

insert into dw_fir.FatoSugestaoRota
select
	s.SugestaoID,
	case s.SugestaoIndicacao when 'O' then 'Origem' else 'Destino' end,
	s.SugestaoDataPrevista,
	dwcalprev.ChaveCalendario,
	dwcalreg.ChaveCalendario,
	dwp.ChavePassageiro,
	dwe.ChaveEndereco
from
	audit.ins_SugestaoRota s
	inner join dw_fir.Passageiro dwp on dwp.IDPassageiro=s.PassageiroID
	inner join dw_fir.Endereco dwe on dwe.IDEndereco=s.EnderecoID
	inner join dw_fir.Calendario dwcalprev on dwcalprev.DataCompleta=cast(s.SugestaoDataPrevista as date)
	inner join dw_fir.Calendario dwcalreg on dwcalreg.DataCompleta=cast(s.SugestaoDataRegistro as date);

truncate table audit.ins_SugestaoRota;


--- montar as consultas para os fatos (igual ao FatoVendas da ZAGI)

create or replace view dw_fir.FatoDespesas as
select
	fd.TipoDespesa, fd.DescricaoDespesa, fd.ValorDespesa, fd.ValorLiquido, fd.ValorImposto,
	c.Ano, c.DataCompleta, c.Mes, c.Trimestre,
	f.NomeFuncionario, f.CategoriaFuncionario,
	v.PlacaVeiculo, v.TipoVeiculo
from
	dw_fir.FatoDespesa fd inner join dw_fir.Calendario c on c.ChaveCalendario=fd.ChaveCalendario
	left join dw_fir.Funcionario f on f.ChaveFuncionario=fd.ChaveFuncionario
	left join dw_fir.Veiculo v on v.ChaveVeiculo=fd.ChaveVeiculo;

create or replace view dw_fir.FatoReceitas as
select
	fr.HoraPagamento, fr.ValorPago, fr.ValorTabela, fr.ValorDesconto, fr.StatusRota,
	c.Ano, c.DataCompleta, c.Mes, c.Trimestre,
	p.NomePassageiro, p.FormaPagamentoPassageiro,
	f.NomeFuncionario as NomeMotorista,
	v.PlacaVeiculo,
	eo.MunicipioEndereco as MunicipioOrigem, ed.MunicipioEndereco as MunicipioDestino
from
	dw_fir.FatoReceitaPassagem fr inner join dw_fir.Calendario c on c.ChaveCalendario=fr.ChaveCalendario
	inner join dw_fir.Passageiro p on p.ChavePassageiro=fr.ChavePassageiro
	inner join dw_fir.Funcionario f on f.ChaveFuncionario=fr.ChaveFuncionario
	inner join dw_fir.Veiculo v on v.ChaveVeiculo=fr.ChaveVeiculo
	inner join dw_fir.Endereco eo on eo.ChaveEndereco=fr.ChaveEnderecoOrigem
	inner join dw_fir.Endereco ed on ed.ChaveEndereco=fr.ChaveEnderecoDestino;

create or replace view dw_fir.FatoRotas as
select
	fr.HoraInicio, fr.HoraFim, fr.StatusRota, fr.QtdPassageiros, fr.ReceitaRota,
	fr.DuracaoMinutos, fr.QtdAvisosAtraso, fr.QtdAvisosCancelamento,
	c.Ano, c.DataCompleta,
	v.PlacaVeiculo, v.TipoVeiculo,
	f.NomeFuncionario as NomeMotorista
from
	dw_fir.FatoRota fr inner join dw_fir.Calendario c on c.ChaveCalendario=fr.ChaveCalendarioInicio
	inner join dw_fir.Veiculo v on v.ChaveVeiculo=fr.ChaveVeiculo
	inner join dw_fir.Funcionario f on f.ChaveFuncionario=fr.ChaveFuncionario;

create or replace view dw_fir.FatoSugestoes as
select
	fs.TipoSugestao, fs.HoraPrevista,
	c.Ano, c.DataCompleta,
	p.NomePassageiro,
	e.MunicipioEndereco, e.UFEndereco
from
	dw_fir.FatoSugestaoRota fs inner join dw_fir.Calendario c on c.ChaveCalendario=fs.ChaveCalendarioPrevista
	inner join dw_fir.Passageiro p on p.ChavePassageiro=fs.ChavePassageiro
	inner join dw_fir.Endereco e on e.ChaveEndereco=fs.ChaveEndereco;

select * from dw_fir.FatoDespesas;
select * from dw_fir.FatoReceitas;
select * from dw_fir.FatoRotas;
select * from dw_fir.FatoSugestoes;