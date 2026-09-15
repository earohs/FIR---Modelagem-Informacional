
drop schema if exists dw_fir cascade;
create schema dw_fir;

set search_path=dw_fir;

CREATE TABLE Funcionario
(
  ChaveFuncionario VARCHAR NOT NULL,
  IDFuncionario INT NOT NULL,
  NomeFuncionario VARCHAR NOT NULL,          -- Tipo 1
  CategoriaFuncionario VARCHAR NOT NULL,     -- Tipo 2
  SalarioFuncionario money NOT NULL,         -- Tipo 2
  CNHMotorista VARCHAR,                      -- Tipo 1
  CategoriaCNHMotorista VARCHAR,             -- Tipo 1
  VersaoFuncionario INT NOT NULL,
  DataInicioFuncionario DATE NOT NULL,
  DataFimFuncionario DATE,
  CorrenteFuncionario CHAR(1) NOT NULL,
  PRIMARY KEY (ChaveFuncionario),
  UNIQUE (IDFuncionario, VersaoFuncionario),
  CHECK (CorrenteFuncionario in ('S','N')),
  CHECK (DataFimFuncionario is null or DataFimFuncionario >= DataInicioFuncionario)
);

CREATE TABLE Veiculo
(
  ChaveVeiculo VARCHAR NOT NULL,
  IDVeiculo INT NOT NULL,
  PlacaVeiculo VARCHAR NOT NULL,
  TipoVeiculo VARCHAR NOT NULL,
  DescricaoVeiculo VARCHAR,
  PRIMARY KEY (ChaveVeiculo)
);

CREATE TABLE Passageiro
(
  ChavePassageiro VARCHAR NOT NULL,
  IDPassageiro INT NOT NULL,
  NomePassageiro VARCHAR NOT NULL,
  CPFPassageiro VARCHAR NOT NULL,
  DataNascimentoPassageiro DATE NOT NULL,
  FormaPagamentoPassageiro VARCHAR NOT NULL,
  PRIMARY KEY (ChavePassageiro)
);

CREATE TABLE Endereco
(
  ChaveEndereco VARCHAR NOT NULL,
  IDEndereco INT NOT NULL,
  CEPEndereco VARCHAR NOT NULL,
  LogradouroEndereco VARCHAR NOT NULL,
  MunicipioEndereco VARCHAR NOT NULL,
  UFEndereco VARCHAR NOT NULL,
  PontoReferenciaEndereco VARCHAR,
  PRIMARY KEY (ChaveEndereco)
);

CREATE TABLE Calendario
(
  ChaveCalendario VARCHAR NOT NULL,
  DataCompleta DATE NOT NULL,
  DiaSemana VARCHAR NOT NULL,
  DiaMes INT NOT NULL,
  Mes VARCHAR NOT NULL,
  Trimestre INT NOT NULL,
  Ano INT NOT NULL,
  PRIMARY KEY (ChaveCalendario)
);

/*****
FatoDespesa - grao: 1 linha por evento de despesa (folha OU manutencao).
TipoDespesa distingue a origem, no mesmo espirito de NomeCategoriaProduto /
NomeFornecedorProduto que ficam "achatados" dentro da dimensao Produto.
*****/
CREATE TABLE FatoDespesa
(
  IDOrigemDespesa INT NOT NULL,       -- PagamentoID ou ManutencaoID, conforme TipoDespesa
  TipoDespesa VARCHAR NOT NULL,       -- 'Pagamento Funcionario' ou 'Manutencao Veiculo'
  DescricaoDespesa VARCHAR NOT NULL,
  ValorDespesa money NOT NULL,        -- custo total para a FIR
  ValorLiquido money NOT NULL,
  ValorImposto money NOT NULL,
  ChaveCalendario VARCHAR NOT NULL,
  ChaveFuncionario VARCHAR,           -- nulo quando TipoDespesa = manutencao
  ChaveVeiculo VARCHAR,               -- nulo quando TipoDespesa = pagamento
  PRIMARY KEY (IDOrigemDespesa, TipoDespesa),
  FOREIGN KEY (ChaveCalendario) REFERENCES Calendario(ChaveCalendario),
  FOREIGN KEY (ChaveFuncionario) REFERENCES Funcionario(ChaveFuncionario),
  FOREIGN KEY (ChaveVeiculo) REFERENCES Veiculo(ChaveVeiculo)
);

/*****
FatoReceitaPassagem - grao: 1 linha por passageiro embarcado em uma rota.
*****/
CREATE TABLE FatoReceita
(
  IDRota INT NOT NULL,
  IDPassageiro INT NOT NULL,
  HoraPagamento TIMESTAMP WITH TIME ZONE NOT NULL,
  ValorPago money NOT NULL,
  ValorTabela money NOT NULL,
  ValorDesconto money NOT NULL,
  StatusRota VARCHAR NOT NULL,
  ChaveCalendario VARCHAR NOT NULL,
  ChavePassageiro VARCHAR NOT NULL,
  ChaveFuncionario VARCHAR NOT NULL,  -- motorista da rota
  ChaveVeiculo VARCHAR NOT NULL,
  ChaveEnderecoOrigem VARCHAR NOT NULL,
  ChaveEnderecoDestino VARCHAR NOT NULL,
  PRIMARY KEY (IDRota, IDPassageiro),
  FOREIGN KEY (ChaveCalendario) REFERENCES Calendario(ChaveCalendario),
  FOREIGN KEY (ChavePassageiro) REFERENCES Passageiro(ChavePassageiro),
  FOREIGN KEY (ChaveFuncionario) REFERENCES Funcionario(ChaveFuncionario),
  FOREIGN KEY (ChaveVeiculo) REFERENCES Veiculo(ChaveVeiculo),
  FOREIGN KEY (ChaveEnderecoOrigem) REFERENCES Endereco(ChaveEndereco),
  FOREIGN KEY (ChaveEnderecoDestino) REFERENCES Endereco(ChaveEndereco)
);

/*****
FatoRota - grao: 1 linha por rota (snapshot que é atualizado quando a rota
encerra ou recebe um aviso de atraso/cancelamento).
*****/
CREATE TABLE FatoRota
(
  IDRota INT NOT NULL,
  HoraInicio TIMESTAMP WITH TIME ZONE NOT NULL,
  HoraFim TIMESTAMP WITH TIME ZONE,
  StatusRota VARCHAR NOT NULL,
  ValorPassagem money NOT NULL,
  QtdPassageiros INT NOT NULL,
  ReceitaRota money NOT NULL,
  DuracaoMinutos INT,
  QtdAvisosAtraso INT NOT NULL,
  QtdAvisosCancelamento INT NOT NULL,
  ChaveCalendarioInicio VARCHAR NOT NULL,
  ChaveCalendarioFim VARCHAR,
  ChaveVeiculo VARCHAR NOT NULL,
  ChaveFuncionario VARCHAR NOT NULL, -- motorista
  ChaveEnderecoOrigem VARCHAR NOT NULL,
  ChaveEnderecoDestino VARCHAR NOT NULL,
  PRIMARY KEY (IDRota),
  FOREIGN KEY (ChaveCalendarioInicio) REFERENCES Calendario(ChaveCalendario),
  FOREIGN KEY (ChaveCalendarioFim) REFERENCES Calendario(ChaveCalendario),
  FOREIGN KEY (ChaveVeiculo) REFERENCES Veiculo(ChaveVeiculo),
  FOREIGN KEY (ChaveFuncionario) REFERENCES Funcionario(ChaveFuncionario),
  FOREIGN KEY (ChaveEnderecoOrigem) REFERENCES Endereco(ChaveEndereco),
  FOREIGN KEY (ChaveEnderecoDestino) REFERENCES Endereco(ChaveEndereco)
);

/*****
FatoSugestaoRota - grao: 1 linha por sugestao de rota registrada pelo
passageiro (factless fact - a metrica é a contagem de linhas).
*****/
CREATE TABLE FatoSugestaoRota
(
  IDSugestao INT NOT NULL,
  TipoSugestao VARCHAR NOT NULL,      -- 'Origem' ou 'Destino'
  HoraPrevista TIMESTAMP WITH TIME ZONE NOT NULL,
  ChaveCalendarioPrevista VARCHAR NOT NULL,
  ChaveCalendarioRegistro VARCHAR NOT NULL,
  ChavePassageiro VARCHAR NOT NULL,
  ChaveEndereco VARCHAR NOT NULL,
  PRIMARY KEY (IDSugestao),
  FOREIGN KEY (ChaveCalendarioPrevista) REFERENCES Calendario(ChaveCalendario),
  FOREIGN KEY (ChaveCalendarioRegistro) REFERENCES Calendario(ChaveCalendario),
  FOREIGN KEY (ChavePassageiro) REFERENCES Passageiro(ChavePassageiro),
  FOREIGN KEY (ChaveEndereco) REFERENCES Endereco(ChaveEndereco)
);
