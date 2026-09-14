
/*****

DDL create tables FIR PT BR.sql

Base operacional (OLTP) da FIR Transportes.
Convenção de nomes: EntidadeAtributo (ex.: FuncionarioNome), igual ao restante
da base ZAGI usada em aula. As tabelas do DW, no arquivo DW_FIR_PT_BR.sql,
invertem essa convenção para AtributoEntidade (ex.: NomeFuncionario).

*****/

drop schema if exists oper_fir cascade;
create schema oper_fir;

set search_path=oper_fir;

/*****
Funcionario + especialização disjunta (Administrativo / Motorista)
*****/

CREATE TABLE Funcionario(
	FuncionarioID serial NOT NULL,
	FuncionarioNome varchar NOT NULL,
	FuncionarioCPF varchar NOT NULL,
	FuncionarioSalario money NOT NULL,
	FuncionarioCategoria char(1) NOT NULL, -- A = Administrativo , M = Motorista
	PRIMARY KEY (FuncionarioID)
);

CREATE TABLE Administrativo(
	FuncionarioID int NOT NULL,
	AdministrativoSetor varchar NOT NULL,
	AdministrativoRamal varchar,
	PRIMARY KEY (FuncionarioID),
	FOREIGN KEY (FuncionarioID) REFERENCES Funcionario(FuncionarioID)
);

CREATE TABLE Motorista(
	FuncionarioID int NOT NULL,
	MotoristaCNH varchar NOT NULL,
	MotoristaCategoriaCNH varchar NOT NULL,
	MotoristaValidadeCNH date,
	PRIMARY KEY (FuncionarioID),
	FOREIGN KEY (FuncionarioID) REFERENCES Funcionario(FuncionarioID)
);

CREATE TABLE PagamentoFuncionario(
	PagamentoID serial NOT NULL,
	FuncionarioID int NOT NULL,
	PagamentoData date NOT NULL,
	PagamentoValorPago money NOT NULL,
	PagamentoValorImposto money NOT NULL,
	PRIMARY KEY (PagamentoID),
	FOREIGN KEY (FuncionarioID) REFERENCES Funcionario(FuncionarioID)
);

/*****
Veiculo e Manutencao
*****/

CREATE TABLE Veiculo(
	VeiculoID serial NOT NULL,
	VeiculoPlaca varchar NOT NULL,
	VeiculoTipo char(1) NOT NULL, -- C = Carro , O = Onibus
	VeiculoDescricao varchar,
	PRIMARY KEY (VeiculoID)
);

CREATE TABLE Manutencao(
	ManutencaoID serial NOT NULL,
	VeiculoID int NOT NULL,
	ManutencaoData date NOT NULL,
	ManutencaoDescricao varchar NOT NULL,
	ManutencaoValorDespesa money NOT NULL,
	PRIMARY KEY (ManutencaoID),
	FOREIGN KEY (VeiculoID) REFERENCES Veiculo(VeiculoID)
);

/*****
Endereco e Passageiro
*****/

CREATE TABLE Endereco(
	EnderecoID serial NOT NULL,
	EnderecoCEP varchar NOT NULL,
	EnderecoLogradouro varchar NOT NULL,
	EnderecoNumero varchar,
	EnderecoMunicipio varchar NOT NULL,
	EnderecoUF char(2) NOT NULL,
	EnderecoPontoReferencia varchar,
	PRIMARY KEY (EnderecoID)
);

CREATE TABLE Passageiro(
	PassageiroID serial NOT NULL,
	PassageiroNome varchar NOT NULL,
	PassageiroCPF varchar NOT NULL,
	PassageiroDataNascimento date NOT NULL,
	PassageiroFormaPagamento varchar NOT NULL,
	PRIMARY KEY (PassageiroID)
);

-- passageiro possui 1 ou mais enderecos ; endereco pode nao estar associado a nenhum passageiro
CREATE TABLE PassageiroEndereco(
	PassageiroID int NOT NULL,
	EnderecoID int NOT NULL,
	PRIMARY KEY (PassageiroID, EnderecoID),
	FOREIGN KEY (PassageiroID) REFERENCES Passageiro(PassageiroID),
	FOREIGN KEY (EnderecoID) REFERENCES Endereco(EnderecoID)
);

/*****
Rota, avisos de atraso/cancelamento e passageiros embarcados
*****/

CREATE TABLE Rota(
	RotaID serial NOT NULL,
	VeiculoID int NOT NULL,
	MotoristaID int NOT NULL, -- referencia Funcionario ; espera-se FuncionarioCategoria = 'M'
	EnderecoOrigemID int NOT NULL,
	EnderecoDestinoID int NOT NULL,
	RotaInicio timestamp with time zone NOT NULL,
	RotaFim timestamp with time zone, -- nulo enquanto a rota está em andamento
	RotaValorPassagem money NOT NULL,
	PRIMARY KEY (RotaID),
	FOREIGN KEY (VeiculoID) REFERENCES Veiculo(VeiculoID),
	FOREIGN KEY (MotoristaID) REFERENCES Funcionario(FuncionarioID),
	FOREIGN KEY (EnderecoOrigemID) REFERENCES Endereco(EnderecoID),
	FOREIGN KEY (EnderecoDestinoID) REFERENCES Endereco(EnderecoID)
);

CREATE TABLE AvisoRota(
	AvisoID serial NOT NULL,
	RotaID int NOT NULL,
	FuncionarioID int NOT NULL, -- motorista que emitiu o aviso
	AvisoTipo char(1) NOT NULL, -- A = Atraso , C = Cancelamento
	AvisoData timestamp with time zone NOT NULL DEFAULT current_timestamp,
	AvisoMotivo varchar,
	PRIMARY KEY (AvisoID),
	FOREIGN KEY (RotaID) REFERENCES Rota(RotaID),
	FOREIGN KEY (FuncionarioID) REFERENCES Funcionario(FuncionarioID)
);

CREATE TABLE RotaPassageiro(
	RotaID int NOT NULL,
	PassageiroID int NOT NULL,
	RotaPassageiroValorPago money NOT NULL,
	RotaPassageiroDataPagamento timestamp with time zone NOT NULL DEFAULT current_timestamp,
	PRIMARY KEY (RotaID, PassageiroID),
	FOREIGN KEY (RotaID) REFERENCES Rota(RotaID),
	FOREIGN KEY (PassageiroID) REFERENCES Passageiro(PassageiroID)
);

CREATE TABLE SugestaoRota(
	SugestaoID serial NOT NULL,
	PassageiroID int NOT NULL,
	EnderecoID int NOT NULL,
	SugestaoIndicacao char(1) NOT NULL, -- O = Origem , D = Destino
	SugestaoDataPrevista timestamp with time zone NOT NULL,
	SugestaoDataRegistro timestamp with time zone NOT NULL DEFAULT current_timestamp,
	PRIMARY KEY (SugestaoID),
	FOREIGN KEY (PassageiroID) REFERENCES Passageiro(PassageiroID),
	FOREIGN KEY (EnderecoID) REFERENCES Endereco(EnderecoID)
);