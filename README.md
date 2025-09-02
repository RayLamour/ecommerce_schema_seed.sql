# Banco de Dados - eCommerce

Este projeto apresenta a modelagem e implementação de um banco de dados relacional para um sistema de e-commerce.  
O objetivo é simular operações reais de clientes, pedidos, pagamentos e itens, servindo como base para estudos em SQL e para projetos que necessitem de uma estrutura de dados sólida.


## Estrutura do Repositório

- `db_ecommerce.sql` → Script completo contendo a estrutura do banco (tabelas, relacionamentos, constraints) e os dados de exemplo.
  

## Modelagem

As principais entidades do sistema são:

- **Cliente** → Representa pessoas físicas ou jurídicas que realizam compras.  
- **Produto** → Itens disponíveis para venda.  
- **Pedido** → Registro das compras realizadas pelos clientes.  
- **Pagamento** → Associado aos pedidos, com suporte a métodos como cartão, PIX e boleto.  
- **Itens do Pedido** → Relação de produtos que compõem cada pedido.  

As tabelas estão relacionadas por chaves estrangeiras, garantindo integridade referencial e consistência dos dados.


## Requisitos

- MySQL Server 8 ou superior  
- MySQL Workbench (opcional, recomendado para visualização e execução dos scripts)

  ## Como Importar o Banco

1. Clone o repositório anexo: ecommerce_db
2.	Crie o schema no MySQL
3.	Importe o script
4.	Verifique as tabelas criadas: SHOW TABLES;
5. No schema ja existem algumas queries de exemplos de consultas, fique a vontade para fazer as suas.



## Observações

Os dados inseridos são fictícios e foram criados apenas para fins de prática e demonstração.
A estrutura pode ser expandida de acordo com necessidades específicas de projetos futuros.
