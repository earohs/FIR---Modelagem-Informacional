/*****

DML insert FIR PT BR.sql (dados de exemplo para os testes - parte 1.1)

*****/
set search_path=oper_fir;

INSERT INTO Funcionario (FuncionarioNome,FuncionarioCPF,FuncionarioSalario,FuncionarioCategoria) VALUES
('Ana Souza','11111111111',6500,'A'),
('Bruno Lima','22222222222',3800,'M'),
('Carla Dias','33333333333',4200,'M');

INSERT INTO Administrativo VALUES (1,'Financeiro','2010');
INSERT INTO Motorista VALUES
(2,'987654321','D','2028-05-01'),
(3,'123456789','D','2027-11-30');

INSERT INTO PagamentoFuncionario (FuncionarioID,PagamentoData,PagamentoValorPago,PagamentoValorImposto) VALUES
(1,'2025-06-05',6500,1430),
(2,'2025-06-05',3800,646),
(3,'2025-06-05',4200,714);

INSERT INTO Veiculo (VeiculoPlaca,VeiculoTipo,VeiculoDescricao) VALUES
('RJA1B23','O','Onibus 42 lugares'),
('RJC4D56','C','Sedan executivo');

INSERT INTO Manutencao (VeiculoID,ManutencaoData,ManutencaoDescricao,ManutencaoValorDespesa) VALUES
(1,'2025-06-12','Revisao de suspensao',2400),
(2,'2025-06-20','Troca de oleo',380);

INSERT INTO Endereco (EnderecoCEP,EnderecoLogradouro,EnderecoNumero,EnderecoMunicipio,EnderecoUF,EnderecoPontoReferencia) VALUES
('20031170','Av. Rio Branco','1','Rio de Janeiro','RJ','Centro'),
('22410003','Av. Vieira Souto','200','Rio de Janeiro','RJ','Ipanema'),
('24210200','Rua Gavioes','45','Niteroi','RJ','Icarai');

INSERT INTO Passageiro (PassageiroNome,PassageiroCPF,PassageiroDataNascimento,PassageiroFormaPagamento) VALUES
('Diego Alves','44444444444','1990-04-12','PIX'),
('Elisa Rocha','55555555555','2001-09-30','CREDITO');

INSERT INTO PassageiroEndereco VALUES (1,1),(2,2);

INSERT INTO Rota (VeiculoID,MotoristaID,EnderecoOrigemID,EnderecoDestinoID,RotaInicio,RotaFim,RotaValorPassagem) VALUES
(1,2,1,2,'2025-06-25 07:00-03','2025-06-25 08:10-03',12.50),
(2,3,2,3,'2025-06-26 18:00-03',NULL,25.00);

INSERT INTO RotaPassageiro VALUES
(1,1,12.50,'2025-06-25 07:02-03'),
(1,2,10.00,'2025-06-25 07:05-03');

INSERT INTO AvisoRota (RotaID,FuncionarioID,AvisoTipo,AvisoMotivo) VALUES
(1,2,'A','Transito na Av. Brasil');

INSERT INTO SugestaoRota (PassageiroID,EnderecoID,SugestaoIndicacao,SugestaoDataPrevista) VALUES
(1,3,'O','2025-07-01 06:30-03'),
(2,1,'D','2025-07-01 07:00-03');