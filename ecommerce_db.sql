-- =========================================================
-- E-COMMERCE | Esquema Lógico + Seeds + Consultas de Exemplo
-- Banco: MySQL 8+
-- =========================================================

-- 1) Criação do banco
DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_db;

-- 2) Segurança para recriação das tabelas
SET FOREIGN_KEY_CHECKS = 0;

-- 3) Drops (idempotência)
DROP TABLE IF EXISTS entrega;
DROP TABLE IF EXISTS pagamento;
DROP TABLE IF EXISTS metodo_pagamento;
DROP TABLE IF EXISTS item_pedido;
DROP TABLE IF EXISTS pedido;
DROP TABLE IF EXISTS estoque;
DROP TABLE IF EXISTS produto_fornecedor;
DROP TABLE IF EXISTS produto_vendedor;
DROP TABLE IF EXISTS produto;
DROP TABLE IF EXISTS vendedor;
DROP TABLE IF EXISTS fornecedor;
DROP TABLE IF EXISTS endereco;
DROP TABLE IF EXISTS cliente;

DROP TRIGGER IF EXISTS trg_cliente_xor_bi;
DROP TRIGGER IF EXISTS trg_cliente_xor_bu;
DROP TRIGGER IF EXISTS trg_pedido_endereco_bi;
DROP TRIGGER IF EXISTS trg_pagamento_mpid_owner_bi;

SET FOREIGN_KEY_CHECKS = 1;

-- 4) Tabelas

CREATE TABLE cliente (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(120) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  telefone VARCHAR(20),
  tipo_cliente ENUM('PF','PJ') NOT NULL,
  cpf CHAR(11) UNIQUE,
  cnpj CHAR(14) UNIQUE,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- CHECK ajuda na documentação. Para MySQL 8+, mantém por clareza,
  -- mas gatilhos (triggers) abaixo fazem a validação efetiva.
  CONSTRAINT chk_cliente_pf_pj CHECK (
    (tipo_cliente='PF' AND cpf IS NOT NULL AND cnpj IS NULL)
    OR
    (tipo_cliente='PJ' AND cnpj IS NOT NULL AND cpf IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE endereco (
  id INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id INT NOT NULL,
  apelido VARCHAR(60),
  cep VARCHAR(12),
  logradouro VARCHAR(120),
  numero VARCHAR(15),
  complemento VARCHAR(60),
  bairro VARCHAR(80),
  cidade VARCHAR(80),
  estado CHAR(2),
  pais VARCHAR(60) DEFAULT 'Brasil',
  CONSTRAINT fk_endereco_cliente FOREIGN KEY (cliente_id)
    REFERENCES cliente(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE fornecedor (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(120) NOT NULL,
  tipo ENUM('PF','PJ') NOT NULL,
  doc CHAR(14) NOT NULL UNIQUE, -- guarda CPF (11) à esquerda com zeros ou CNPJ (14)
  email VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE vendedor (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(120) NOT NULL,
  tipo ENUM('PF','PJ') NOT NULL,
  doc CHAR(14) NOT NULL UNIQUE, -- guarda CPF ou CNPJ, alinhado com fornecedor.doc
  email VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE produto (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(120) NOT NULL,
  descricao TEXT,
  preco DECIMAL(10,2) NOT NULL,
  sku VARCHAR(40) UNIQUE,
  ativo BOOLEAN DEFAULT TRUE,
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE produto_fornecedor (
  produto_id INT NOT NULL,
  fornecedor_id INT NOT NULL,
  preco_custo DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (produto_id, fornecedor_id),
  CONSTRAINT fk_pf_produto FOREIGN KEY (produto_id)
    REFERENCES produto(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pf_fornecedor FOREIGN KEY (fornecedor_id)
    REFERENCES fornecedor(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE produto_vendedor (
  produto_id INT NOT NULL,
  vendedor_id INT NOT NULL,
  preco_anuncio DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (produto_id, vendedor_id),
  CONSTRAINT fk_pv_produto FOREIGN KEY (produto_id)
    REFERENCES produto(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pv_vendedor FOREIGN KEY (vendedor_id)
    REFERENCES vendedor(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE estoque (
  produto_id INT PRIMARY KEY,
  quantidade INT NOT NULL DEFAULT 0,
  localizacao VARCHAR(60) DEFAULT 'CD-Recife',
  CONSTRAINT fk_estoque_produto FOREIGN KEY (produto_id)
    REFERENCES produto(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pedido (
  id INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id INT NOT NULL,
  endereco_entrega_id INT NOT NULL,
  status ENUM('aberto','pago','cancelado') NOT NULL DEFAULT 'aberto',
  total DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- mantemos o total "carimbado" no pedido
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id)
    REFERENCES cliente(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pedido_endereco FOREIGN KEY (endereco_entrega_id)
    REFERENCES endereco(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE item_pedido (
  pedido_id INT NOT NULL,
  produto_id INT NOT NULL,
  quantidade INT NOT NULL,
  preco_unit DECIMAL(10,2) NOT NULL, -- preço do item na data do pedido
  PRIMARY KEY (pedido_id, produto_id),
  CONSTRAINT fk_item_pedido FOREIGN KEY (pedido_id)
    REFERENCES pedido(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_item_produto FOREIGN KEY (produto_id)
    REFERENCES produto(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE metodo_pagamento (
  id INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id INT NOT NULL,
  tipo ENUM('cartao','pix','boleto') NOT NULL,
  apelido VARCHAR(60),
  numero_mask VARCHAR(25), -- ex: **** **** **** 1234
  nome_cartao VARCHAR(120),
  validade_mes INT,
  validade_ano INT,
  chave_pix VARCHAR(120),
  banco_boleto VARCHAR(80),
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_metodo_cliente FOREIGN KEY (cliente_id)
    REFERENCES cliente(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pagamento (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  metodo_pagamento_id INT NOT NULL,
  valor DECIMAL(10,2) NOT NULL,
  status ENUM('pendente','pago','estornado') NOT NULL DEFAULT 'pendente',
  transacao_ref VARCHAR(80),
  criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pag_pedido FOREIGN KEY (pedido_id)
    REFERENCES pedido(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pag_metodo FOREIGN KEY (metodo_pagamento_id)
    REFERENCES metodo_pagamento(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE entrega (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL UNIQUE, -- 1:1 com pedido
  status ENUM('pendente','postado','em_transito','entregue','devolvido') NOT NULL DEFAULT 'pendente',
  codigo_rastreio VARCHAR(40) UNIQUE,
  atualizado_em DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_entrega_pedido FOREIGN KEY (pedido_id)
    REFERENCES pedido(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 5) TRIGGERS (regras de negócio críticas)
DELIMITER $$

-- (A) Cliente PF xor PJ
CREATE TRIGGER trg_cliente_xor_bi
BEFORE INSERT ON cliente
FOR EACH ROW
BEGIN
  IF NEW.tipo_cliente = 'PF' THEN
    IF NEW.cpf IS NULL OR NEW.cnpj IS NOT NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente PF exige CPF e CNPJ deve ser NULL';
    END IF;
  ELSEIF NEW.tipo_cliente = 'PJ' THEN
    IF NEW.cnpj IS NULL OR NEW.cpf IS NOT NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente PJ exige CNPJ e CPF deve ser NULL';
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_cliente_xor_bu
BEFORE UPDATE ON cliente
FOR EACH ROW
BEGIN
  IF NEW.tipo_cliente = 'PF' THEN
    IF NEW.cpf IS NULL OR NEW.cnpj IS NOT NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente PF exige CPF e CNPJ deve ser NULL';
    END IF;
  ELSEIF NEW.tipo_cliente = 'PJ' THEN
    IF NEW.cnpj IS NULL OR NEW.cpf IS NOT NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente PJ exige CNPJ e CPF deve ser NULL';
    END IF;
  END IF;
END$$

-- (B) Pedido: endereço de entrega deve pertencer ao mesmo cliente
CREATE TRIGGER trg_pedido_endereco_bi
BEFORE INSERT ON pedido
FOR EACH ROW
BEGIN
  DECLARE v_cliente_id INT;
  SELECT e.cliente_id INTO v_cliente_id FROM endereco e WHERE e.id = NEW.endereco_entrega_id;
  IF v_cliente_id IS NULL OR v_cliente_id <> NEW.cliente_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Endereco de entrega não pertence ao cliente do pedido';
  END IF;
END$$

-- (C) Pagamento: método de pagamento deve pertencer ao mesmo cliente do pedido
CREATE TRIGGER trg_pagamento_mpid_owner_bi
BEFORE INSERT ON pagamento
FOR EACH ROW
BEGIN
  DECLARE v_cliente_pedido INT;
  DECLARE v_cliente_metodo INT;
  SELECT p.cliente_id INTO v_cliente_pedido FROM pedido p WHERE p.id = NEW.pedido_id;
  SELECT m.cliente_id INTO v_cliente_metodo FROM metodo_pagamento m WHERE m.id = NEW.metodo_pagamento_id;
  IF v_cliente_pedido IS NULL OR v_cliente_metodo IS NULL OR v_cliente_pedido <> v_cliente_metodo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Método de pagamento não pertence ao cliente do pedido';
  END IF;
END$$

DELIMITER ;

-- 6) DADOS (Seeds)
-- Clientes (6 clientes: 3 PF, 3 PJ)
INSERT INTO cliente (nome, email, telefone, tipo_cliente, cpf, cnpj)
VALUES
('Ana Souza', 'ana.souza@example.com', '(81) 99999-0001', 'PF', '12345678901', NULL),
('Bruno Lima', 'bruno.lima@example.com', '(81) 99999-0002', 'PF', '98765432100', NULL),
('Casa do Byte LTDA', 'contato@casadobyte.com', '(11) 4002-8922', 'PJ', NULL, '11222333000155'),
('Tech&Co SA', 'suporte@techco.com', '(21) 3003-5599', 'PJ', NULL, '55443322000199'),
('Carla Almeida', 'carla.almeida@example.com', '(81) 99999-0003', 'PF', '11122233344', NULL),
('Mega Market ME', 'vendas@megamarket.com', '(31) 3555-1212', 'PJ', NULL, '00998877000166');

DESCRIBE cliente;

SELECT *FROM	cliente;

-- Endereços
INSERT INTO endereco (cliente_id, apelido, cep, logradouro, numero, complemento, bairro, cidade, estado, pais) VALUES
(1, 'Casa', '50000-000', 'Rua das Flores', '123', NULL, 'Centro', 'Recife', 'PE', 'Brasil'),
(1, 'Trabalho', '50000-100', 'Av. Boa Viagem', '1000', 'Sala 203', 'Boa Viagem', 'Recife', 'PE', 'Brasil'),
(2, 'Casa', '52000-000', 'Rua A', '45', NULL, 'Graças', 'Recife', 'PE', 'Brasil'),
(3, 'Sede', '01000-000', 'Rua B', '200', 'Conj. 12', 'Centro', 'São Paulo', 'SP', 'Brasil'),
(4, 'Sede', '20000-000', 'Av. Atlântica', '500', NULL, 'Copacabana', 'Rio de Janeiro', 'RJ', 'Brasil'),
(5, 'Casa', '53000-000', 'Rua C', '789', 'Ap 302', 'Olinda', 'Olinda', 'PE', 'Brasil'),
(6, 'Sede', '30100-000', 'Rua D', '88', NULL, 'Savassi', 'Belo Horizonte', 'MG', 'Brasil');

-- Fornecedores (3) — um deles terá o mesmo DOC de um vendedor para responder à pergunta
INSERT INTO fornecedor (nome, tipo, doc, email) VALUES
('Acme Suprimentos', 'PJ', '12345678000199', 'contato@acme.com'),
('Brasil Tech Import', 'PJ', '55779966000122', 'hello@brasiltech.com'),
('João Peças', 'PF', LPAD('22233344455', 14, '0'), 'joaopecas@gmail.com'); -- doc 00000022233344455? (LPAD 14) -> '000022233344455'?

-- Vendedores (3) — um deles com o mesmo DOC do fornecedor 'João Peças'
INSERT INTO vendedor (nome, tipo, doc, email) VALUES
('Loja X Marketplace', 'PJ', '99887766000111', 'loja-x@market.com'),
('Vendedora Carla Mall', 'PF', LPAD('11122233344', 14, '0'), 'carla.mall@market.com'),
('JP Distribuição', 'PF', LPAD('22233344455', 14, '0'), 'jp@market.com'); -- mesmo doc do fornecedor 'João Peças'

-- Produtos (8)
INSERT INTO produto (nome, descricao, preco, sku, ativo) VALUES
('Notebook 14"', 'Notebook leve para uso diário', 3500.00, 'NB14-001', TRUE),
('Mouse Óptico', 'Mouse com 1600dpi', 50.00, 'MO-1600', TRUE),
('Teclado Mecânico', 'ABNT2, switches blue', 350.00, 'TK-ABNT2', TRUE),
('Monitor 24"', 'IPS Full HD', 900.00, 'MN24-IPS', TRUE),
('Headset Gamer', '7.1 virtual', 450.00, 'HS-71', TRUE),
('Cadeira Gamer', 'Ergonômica, reclinável', 1200.00, 'CG-PRIME', TRUE),
('Smartphone X', '128GB, 6GB RAM', 2200.00, 'SPX-128', TRUE),
('Carregador Rápido', 'USB-C 30W', 120.00, 'CG-30W', TRUE);

-- Relacionamento produto x fornecedor (custo)
INSERT INTO produto_fornecedor (produto_id, fornecedor_id, preco_custo) VALUES
(1, 1, 2800.00),
(2, 1, 25.00),
(3, 2, 220.00),
(4, 2, 650.00),
(5, 1, 300.00),
(6, 3, 800.00),
(7, 2, 1700.00),
(8, 3, 70.00);

-- Relacionamento produto x vendedor (preço de anúncio)
INSERT INTO produto_vendedor (produto_id, vendedor_id, preco_anuncio) VALUES
(1, 1, 3550.00),
(2, 1, 49.90),
(3, 2, 339.90),
(4, 1, 899.90),
(5, 3, 439.90),
(6, 2, 1199.00),
(7, 1, 2199.00),
(8, 3, 119.00);

-- Estoque (por produto)
INSERT INTO estoque (produto_id, quantidade, localizacao) VALUES
(1, 15, 'CD-Recife'),
(2, 300, 'CD-Recife'),
(3, 40, 'CD-Recife'),
(4, 25, 'CD-Recife'),
(5, 60, 'CD-Recife'),
(6, 8, 'CD-Recife'),
(7, 12, 'CD-Recife'),
(8, 200, 'CD-Recife');

-- Métodos de pagamento (múltiplos por cliente)
INSERT INTO metodo_pagamento (cliente_id, tipo, apelido, numero_mask, nome_cartao, validade_mes, validade_ano, chave_pix, banco_boleto) VALUES
(1, 'cartao', 'Visa final 1234', '**** **** **** 1234', 'ANA S SOUZA', 9, 2028, NULL, NULL),
(1, 'pix', 'Chave principal', NULL, NULL, NULL, NULL, 'ana.souza@pix.com', NULL),
(2, 'boleto', 'Boleto Banco A', NULL, NULL, NULL, NULL, NULL, 'Banco A'),
(3, 'cartao', 'Corp Amex 0005', '**** ****** *0005', 'CASA DO BYTE LTDA', 12, 2027, NULL, NULL),
(4, 'pix', 'PIX Tech&Co', NULL, NULL, NULL, NULL, 'pix@techco.com', NULL),
(5, 'cartao', 'Master final 4444', '**** **** **** 4444', 'CARLA ALMEIDA', 7, 2029, NULL, NULL),
(6, 'cartao', 'Elo final 7777', '**** **** **** 7777', 'MEGA MARKET', 1, 2027, NULL, NULL),
(6, 'pix', 'Pix MM', NULL, NULL, NULL, NULL, 'financeiro@megamarket.com', NULL);

-- PEDIDOS (12 situações)
-- Observação: total será "carimbado" manualmente aqui para facilitar,
-- mas nas consultas mostramos como derivar a soma dos itens.
INSERT INTO pedido (cliente_id, endereco_entrega_id, status, total, criado_em) VALUES
(1, 1, 'aberto',    3550.00, '2025-08-10 10:00:00'),
(1, 2, 'pago',       399.90, '2025-08-11 09:00:00'),
(2, 3, 'pago',      2599.00, '2025-08-11 14:30:00'),
(3, 4, 'cancelado',  900.00, '2025-08-12 10:15:00'),
(3, 4, 'pago',      4750.00, '2025-08-12 16:45:00'),
(4, 5, 'aberto',    1199.00, '2025-08-13 11:20:00'),
(4, 5, 'pago',      4099.00, '2025-08-14 08:10:00'),
(5, 6, 'pago',       469.90, '2025-08-14 17:00:00'),
(6, 7, 'pago',      2299.00, '2025-08-15 09:50:00'),
(2, 3, 'aberto',     120.00, '2025-08-16 12:12:00'),
(5, 6, 'pago',      4700.00, '2025-08-17 10:05:00'),
(1, 1, 'pago',       170.00, '2025-08-18 15:45:00');

-- Itens por pedido
INSERT INTO item_pedido (pedido_id, produto_id, quantidade, preco_unit) VALUES
-- Pedido 1 (Ana) Notebook
(1, 1, 1, 3550.00),
-- Pedido 2 (Ana) Mouse + Teclado
(2, 2, 1, 49.90),
(2, 3, 1, 350.00),
-- Pedido 3 (Bruno) Smartphone X + Carregador
(3, 7, 1, 2199.00),
(3, 8, 1, 120.00),
-- Pedido 4 (Casa do Byte) Monitor (cancelado)
(4, 4, 1, 900.00),
-- Pedido 5 (Casa do Byte) Notebook + Headset
(5, 1, 1, 3500.00),
(5, 5, 1, 450.00),
(5, 2, 1, 49.90),
(5, 8, 1, 120.00),
-- Pedido 6 (Tech&Co) Cadeira
(6, 6, 1, 1199.00),
-- Pedido 7 (Tech&Co) Notebook + Monitor + Mouse
(7, 1, 1, 3500.00),
(7, 4, 1, 900.00),
(7, 2, 1, 49.90),
-- Pedido 8 (Carla) Headset + Mouse
(8, 5, 1, 450.00),
(8, 2, 1, 19.90),
-- Pedido 9 (Mega Market) Smartphone
(9, 7, 1, 2299.00),
-- Pedido 10 (Bruno) Carregador
(10, 8, 1, 120.00),
-- Pedido 11 (Carla) Notebook + Cadeira + Mouse
(11, 1, 1, 3500.00),
(11, 6, 1, 1200.00),
(11, 2, 1, 0.00), -- promoção mouse grátis
-- Pedido 12 (Ana) Headset + Carregador
(12, 5, 1, 50.00), -- cupom forte
(12, 8, 1, 120.00);

SELECT *FROM item_pedido;

SELECT 
    mp.id, 
    mp.tipo, 
    mp.cliente_id, 
    c.nome AS cliente
FROM metodo_pagamento mp
JOIN cliente c ON c.id = mp.cliente_id;

SELECT 
    p.id AS pedido_id,
    p.cliente_id,
    c.nome AS cliente_pedido,
    mp.id AS metodo_pagamento_id,
    mp.tipo,
    mp.cliente_id AS cliente_metodo,
    c2.nome AS cliente_metodo_nome
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id
LEFT JOIN pagamento pg ON pg.pedido_id = p.id
LEFT JOIN metodo_pagamento mp ON mp.id = pg.metodo_pagamento_id
LEFT JOIN cliente c2 ON c2.id = mp.cliente_id
ORDER BY p.id;


-- Pagamentos (inclui exemplo de split)
INSERT INTO pagamento (pedido_id, metodo_pagamento_id, valor, status, transacao_ref) VALUES
    -- Pedido 2 (Ana Souza via cartao, método 1)
    (2, 1, 399.90, 'pago', 'TX-ANA-0002'),

    -- Pedido 3 (Bruno Lima via boleto, método 3)
    (3, 3, 2599.00, 'pago', 'TX-BRU-0003'),

    -- Pedido 4 (Casa do Byte via cartao, método 4) - estornado
    (4, 4, 900.00, 'estornado', 'TX-CDB-0004'),

    -- Pedido 5 (Casa do Byte via cartao, método 4)
    (5, 4, 4750.00, 'pago', 'TX-CDB-0005'),

    -- Pedido 7 (Tech&Co via pix, método 5)
    (7, 5, 4099.00, 'pago', 'TX-TEC-0007'),

    -- Pedido 8 (Carla Almeida via cartao, método 6)
    (8, 6, 469.90, 'pago', 'TX-CAR-0008'),

    -- Pedido 9 (Mega Market via cartao, método 7)
    (9, 7, 2299.00, 'pago', 'TX-MEG-0009'),

    -- Pedido 11 (Carla Almeida split: 3000 + 1700, sempre método 6)
    (11, 6, 3000.00, 'pago', 'TX-CAR-0011-A'),
    (11, 6, 1700.00, 'pago', 'TX-CAR-0011-B'),

    -- Pedido 12 (Ana Souza via pix, método 2)
    (12, 2, 170.00, 'pago', 'TX-ANA-0012');

-- Entregas (apenas para pedidos não cancelados/enviados), alguns em trânsito
INSERT INTO entrega (pedido_id, status, codigo_rastreio, atualizado_em) VALUES
(2, 'entregue',   'BR123456789BR', '2025-08-13 10:00:00'),
(3, 'entregue',   'BR987654321BR', '2025-08-13 16:00:00'),
(5, 'em_transito','BR111222333BR', '2025-08-14 18:30:00'),
(7, 'em_transito','BR444555666BR', '2025-08-15 12:00:00'),
(8, 'entregue',   'BR777888999BR', '2025-08-16 11:00:00'),
(9, 'postado',    'BR222333444BR', '2025-08-16 17:20:00'),
(11,'pendente',   'BR555666777BR', '2025-08-17 09:15:00'),
(12,'entregue',   'BR000111222BR', '2025-08-19 14:40:00');

-- 7) CONSULTAS (Queries de exemplo)
-- Observação: sinta-se livre para copiar/colar e adaptar para seu estudo/projeto.

-- 7.1) Recuperação simples (SELECT) + ORDER BY
-- Lista de produtos ativos por preço decrescente
SELECT id, nome, preco
FROM produto
WHERE ativo = TRUE
ORDER BY preco DESC;

-- 7.2) Filtro com WHERE + expressão derivada (quantidade*preco_unit)
-- Itens de pedido com valor total da linha e apenas os com valor > 500
SELECT ip.pedido_id,
       ip.produto_id,
       ip.quantidade,
       ip.preco_unit,
       (ip.quantidade * ip.preco_unit) AS valor_item
FROM item_pedido ip
WHERE (ip.quantidade * ip.preco_unit) > 500
ORDER BY valor_item DESC;

-- 7.3) Quantos pedidos por cliente? (GROUP BY)
SELECT c.id, c.nome, COUNT(p.id) AS qtd_pedidos
FROM cliente c
LEFT JOIN pedido p ON p.cliente_id = c.id
GROUP BY c.id, c.nome
ORDER BY qtd_pedidos DESC, c.nome;

-- 7.4) Clientes com mais de 1 pedido (HAVING)
SELECT c.id, c.nome, COUNT(p.id) AS qtd_pedidos
FROM cliente c
JOIN pedido p ON p.cliente_id = c.id
GROUP BY c.id, c.nome
HAVING COUNT(p.id) > 1
ORDER BY qtd_pedidos DESC;

-- 7.5) Total derivado por pedido (JOIN + SUM + GROUP BY)
-- Mostra o total calculado (soma dos itens) e o total "carimbado" na tabela pedido
SELECT p.id AS pedido_id,
       SUM(ip.quantidade * ip.preco_unit) AS total_itens,
       p.total AS total_pedido,
       (SUM(ip.quantidade * ip.preco_unit) - p.total) AS dif_total
FROM pedido p
JOIN item_pedido ip ON ip.pedido_id = p.id
GROUP BY p.id, p.total
ORDER BY p.id;

-- 7.6) Produtos mais vendidos (por quantidade)
SELECT pr.id, pr.nome, SUM(ip.quantidade) AS qtd_vendida
FROM produto pr
JOIN item_pedido ip ON ip.produto_id = pr.id
JOIN pedido p ON p.id = ip.pedido_id AND p.status <> 'cancelado'
GROUP BY pr.id, pr.nome
ORDER BY qtd_vendida DESC, pr.nome;

-- 7.7) Relação produtos x fornecedores x estoque
SELECT pr.nome AS produto,
       f.nome  AS fornecedor,
       pf.preco_custo,
       e.quantidade AS estoque
FROM produto pr
JOIN produto_fornecedor pf ON pf.produto_id = pr.id
JOIN fornecedor f ON f.id = pf.fornecedor_id
LEFT JOIN estoque e ON e.produto_id = pr.id
ORDER BY pr.nome, f.nome;

-- 7.8) Relação nomes dos fornecedores e nomes dos produtos (apenas nomes distintos)
SELECT DISTINCT f.nome AS fornecedor, pr.nome AS produto
FROM fornecedor f
JOIN produto_fornecedor pf ON pf.fornecedor_id = f.id
JOIN produto pr ON pr.id = pf.produto_id
ORDER BY f.nome, pr.nome;

-- 7.9) Algum vendedor também é fornecedor? (interseção por DOC)
SELECT v.nome AS vendedor, f.nome AS fornecedor, v.doc
FROM vendedor v
JOIN fornecedor f ON f.doc = v.doc;

-- 7.10) Pedidos e status de entrega (JOIN)
SELECT p.id AS pedido_id, c.nome AS cliente, p.status AS status_pedido,
       en.status AS status_entrega, en.codigo_rastreio
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id
LEFT JOIN entrega en ON en.pedido_id = p.id
ORDER BY p.id;

-- 7.11) Forma de pagamento mais usada por cliente (contagem)
SELECT c.nome AS cliente, mp.tipo, COUNT(pg.id) AS qtd_pagamentos
FROM cliente c
JOIN pedido p ON p.cliente_id = c.id
JOIN pagamento pg ON pg.pedido_id = p.id AND pg.status = 'pago'
JOIN metodo_pagamento mp ON mp.id = pg.metodo_pagamento_id
GROUP BY c.nome, mp.tipo
ORDER BY c.nome, qtd_pagamentos DESC;

-- 7.12) Ticket médio por cliente (SUM/COUNT) + HAVING para filtrar quem tem ticket > 1000
SELECT c.nome AS cliente,
       SUM(p.total) / NULLIF(COUNT(p.id),0) AS ticket_medio
FROM cliente c
JOIN pedido p ON p.cliente_id = c.id AND p.status <> 'cancelado'
GROUP BY c.nome
HAVING ticket_medio > 1000
ORDER BY ticket_medio DESC;

-- 7.13) Estoques baixos (WHERE + ORDER BY)
SELECT pr.nome, e.quantidade
FROM estoque e
JOIN produto pr ON pr.id = e.produto_id
WHERE e.quantidade < 20
ORDER BY e.quantidade ASC;

-- 7.14) Receita por dia (derivada de pedidos pagos) + HAVING (dias com receita > 1000)
SELECT DATE(p.criado_em) AS dia, SUM(p.total) AS receita
FROM pedido p
WHERE p.status = 'pago'
GROUP BY DATE(p.criado_em)
HAVING SUM(p.total) > 1000
ORDER BY dia ASC;


-- FIM DO SCRIPT
