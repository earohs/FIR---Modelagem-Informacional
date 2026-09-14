/************************************************************            
						ATENÇÃO!
Por favor, leia cuidadosamente todo o código antes de executá-lo.

1. Rode o script em partes e valide cada ponto.
2. Leia as referências passadas como comentários.

************************************************************/
/*****

Rode apenas depois de rodar os scripts:

DDL_oper_FIR_PT_BR.sql   (cria oper_fir e já popula com dados de exemplo)
DW_FIR_PT_BR.sql         (cria dw_fir)

Siga atentamente os passos abaixo.

*****/

set search_path=dw_fir;

-- Truncar todas as tabelas do DW, caso já existam (fatos primeiro, por causa das FKs)

truncate table FatoDespesa;
truncate table FatoReceitaPassagem;
truncate table FatoRota;
truncate table FatoSugestaoRota;
delete from Calendario;
delete from Passageiro;
delete from Endereco;
delete from Veiculo;
delete from Funcionario;


select
	gen_random_uuid(),
	f.FuncionarioID,
	f.FuncionarioNome,
	case f.FuncionarioCategoria when 'A' then 'Administrativo' else 'Motorista' end,
	f.FuncionarioSalario,
	m.MotoristaCNH,
	m.MotoristaCategoriaCNH,
	1,
	cast('1900-01-01' as date),
	null,
	'S'
from
	oper_fir.Funcionario f left join oper_fir.Motorista m on m.FuncionarioID=f.FuncionarioID
	left join oper_fir.Administrativo a on a.FuncionarioID=f.FuncionarioID;

INSERT INTO dw_fir.Funcionario
select
	gen_random_uuid(),
	f.FuncionarioID,
	f.FuncionarioNome,
	case f.FuncionarioCategoria when 'A' then 'Administrativo' else 'Motorista' end,
	f.FuncionarioSalario,
	m.MotoristaCNH,
	m.MotoristaCategoriaCNH,
	1,
	cast('1900-01-01' as date),
	null,
	'S'
from
	oper_fir.Funcionario f left join oper_fir.Motorista m on m.FuncionarioID=f.FuncionarioID
	left join oper_fir.Administrativo a on a.FuncionarioID=f.FuncionarioID;

\echo Carga da dimensao Veiculo

INSERT INTO dw_fir.Veiculo
select
	gen_random_uuid(),
	v.VeiculoID,
	v.VeiculoPlaca,
	case v.VeiculoTipo when 'C' then 'Carro' else 'Onibus' end,
	v.VeiculoDescricao
from
	oper_fir.Veiculo v;

\echo Carga da dimensao Passageiro

INSERT INTO dw_fir.Passageiro
select
	gen_random_uuid(),
	p.PassageiroID,
	p.PassageiroNome,
	p.PassageiroCPF,
	p.PassageiroDataNascimento,
	p.PassageiroFormaPagamento
from
	oper_fir.Passageiro p;

\echo Carga da dimensao Endereco

INSERT INTO dw_fir.Endereco
select
	gen_random_uuid(),
	e.EnderecoID,
	e.EnderecoCEP,
	e.EnderecoLogradouro,
	e.EnderecoMunicipio,
	e.EnderecoUF,
	e.EnderecoPontoReferencia
from
	oper_fir.Endereco e;

\echo Carga do calendario - junta as datas de todas as tabelas que tem data/hora
\echo carrega apenas as datas novas, mesma logica usada para o calendario da ZAGI

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

\echo Fato Despesa - une pagamento de funcionario e manutencao de veiculo
\echo repare no LEFT JOIN dos dois lados: cada linha só preenche funcionario OU veiculo


INSERT INTO dw_fir.FatoDespesa
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
	oper_fir.PagamentoFuncionario pg inner join oper_fir.Funcionario f on f.FuncionarioID=pg.FuncionarioID
	inner join dw_fir.Funcionario dwf on dwf.IDFuncionario=pg.FuncionarioID
		and pg.PagamentoData >= dwf.DataInicioFuncionario
		and (dwf.DataFimFuncionario is null or pg.PagamentoData < dwf.DataFimFuncionario)
	inner join dw_fir.Calendario dwcal on dwcal.DataCompleta=cast(pg.PagamentoData as date)
union all
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
	oper_fir.Manutencao mn inner join dw_fir.Veiculo dwv on dwv.IDVeiculo=mn.VeiculoID
	inner join dw_fir.Calendario dwcal on dwcal.DataCompleta=cast(mn.ManutencaoData as date);

\echo Fato Receita Passagem - 1 linha por passageiro embarcado em uma rota
\echo StatusRota calculado com subquery correlacionada em oper_fir.AvisoRota
\echo o motorista tambem entra pela versao vigente na data de inicio da rota

INSERT INTO dw_fir.FatoReceitaPassagem
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
	oper_fir.RotaPassageiro rp inner join oper_fir.Rota r on r.RotaID=rp.RotaID
	inner join dw_fir.Passageiro dwp on dwp.IDPassageiro=rp.PassageiroID
	inner join dw_fir.Funcionario dwf on dwf.IDFuncionario=r.MotoristaID
		and cast(r.RotaInicio as date) >= dwf.DataInicioFuncionario
		and (dwf.DataFimFuncionario is null or cast(r.RotaInicio as date) < dwf.DataFimFuncionario)
	inner join dw_fir.Veiculo dwv on dwv.IDVeiculo=r.VeiculoID
	inner join dw_fir.Endereco dweo on dweo.IDEndereco=r.EnderecoOrigemID
	inner join dw_fir.Endereco dwed on dwed.IDEndereco=r.EnderecoDestinoID
	inner join dw_fir.Calendario dwcal on dwcal.DataCompleta=cast(rp.RotaPassageiroDataPagamento as date);

\echo Fato Rota - 1 linha por rota, com contagem de passageiros e de avisos
\echo agregados em subquery, igual ao espirito das agregacoes feitas na Vendas

INSERT INTO dw_fir.FatoRota
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
		and cast(r.RotaInicio as date) >= dwf.DataInicioFuncionario
		and (dwf.DataFimFuncionario is null or cast(r.RotaInicio as date) < dwf.DataFimFuncionario)
	inner join dw_fir.Endereco dweo on dweo.IDEndereco=r.EnderecoOrigemID
	inner join dw_fir.Endereco dwed on dwed.IDEndereco=r.EnderecoDestinoID
	inner join dw_fir.Calendario dwcalini on dwcalini.DataCompleta=cast(r.RotaInicio as date)
	left join dw_fir.Calendario dwcalfim on dwcalfim.DataCompleta=cast(r.RotaFim as date);

\echo Fato Sugestao Rota

INSERT INTO dw_fir.FatoSugestaoRota
select
	s.SugestaoID,
	case s.SugestaoIndicacao when 'O' then 'Origem' else 'Destino' end,
	s.SugestaoDataPrevista,
	dwcalprev.ChaveCalendario,
	dwcalreg.ChaveCalendario,
	dwp.ChavePassageiro,
	dwe.ChaveEndereco
from
	oper_fir.SugestaoRota s
	inner join dw_fir.Passageiro dwp on dwp.IDPassageiro=s.PassageiroID
	inner join dw_fir.Endereco dwe on dwe.IDEndereco=s.EnderecoID
	inner join dw_fir.Calendario dwcalprev on dwcalprev.DataCompleta=cast(s.SugestaoDataPrevista as date)
	inner join dw_fir.Calendario dwcalreg on dwcalreg.DataCompleta=cast(s.SugestaoDataRegistro as date);

---- validando ....


select count(*) as despesas from dw_fir.FatoDespesa;
select count(*) as receitas from dw_fir.FatoReceitaPassagem;
select count(*) as rotas    from dw_fir.FatoRota;
select count(*) as sugestoes from dw_fir.FatoSugestaoRota;

\echo se a consulta abaixo (EXCEPT) não retornar nada, a receita bate com a origem

select
	rp.RotaID, rp.PassageiroID, rp.RotaPassageiroValorPago
from
	oper_fir.RotaPassageiro rp
EXCEPT
select
	IDRota, IDPassageiro, ValorPago
from
	dw_fir.FatoReceitaPassagem;


select IDFuncionario, count(*) as qtd_versoes, count(*) filter (where CorrenteFuncionario='S') as qtd_correntes
from dw_fir.Funcionario group by IDFuncionario order by IDFuncionario;


select IDFuncionario from dw_fir.Funcionario where CorrenteFuncionario='S'
group by IDFuncionario having count(*) > 1;

select count(*) as pagamentos_origem from oper_fir.PagamentoFuncionario;
select count(*) as pagamentos_no_fato from dw_fir.FatoDespesa where TipoDespesa='Pagamento Funcionario';
