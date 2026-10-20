# Especificação — Cartão flutuante do Acessor Motorista

## Objetivo
Exibir a análise da oferta sobre o aplicativo de corridas, de forma compacta, legível e sem cobrir informações ou controles importantes da plataforma.

## Padrão visual
- Tamanho inicial: **Mini**.
- Cartão escuro, compacto, com alto contraste e cantos arredondados.
- Janela flutuante nativa do Android, autorizada pelo usuário.
- Posição ajustável por arraste.
- Evitar cobrir valor, mapa, endereços, distância, tempo e botões da oferta.
- Se não for possível garantir uma posição livre, priorizar não interferir nos controles da plataforma.

## Indicadores configuráveis
Todos os itens abaixo devem poder ser ativados ou ocultados individualmente nas configurações:
1. Classificação da corrida: boa ou ruim (semáforo de decisão).
2. Valor total da corrida.
3. Ganho por quilômetro (R$/km).
4. Ganho por hora (R$/h).
5. Ganho por minuto (R$/min).
6. Distância total, incluindo busca e viagem, quando disponíveis.
7. Tempo total, incluindo busca e viagem, quando disponíveis.
8. Nota do passageiro, quando disponível.
9. Categoria da corrida (UberX, Comfort, Black etc.), quando disponível.
10. Origem e destino, quando disponíveis.

## Regras de leitura e cálculo
- Capturar o máximo de informações que a plataforma disponibilizar por acessibilidade e outros mecanismos autorizados.
- Não inventar nem presumir valores ausentes.
- Identificar quando um dado não está disponível ou não pôde ser lido com confiança.
- Calcular rentabilidade com uma base consistente: incluir busca e viagem quando ambas as informações forem conhecidas.
- A classificação boa/ruim deve respeitar os critérios de análise configurados no aplicativo.
- A interface deve continuar funcional quando alguns indicadores não estiverem disponíveis.

## Preferências do usuário
- Salvar localmente as escolhas de indicadores e o tamanho do cartão.
- Configuração inicial: todos os indicadores disponíveis para seleção; tamanho Mini.
- A seleção de um indicador não garante que ele estará presente em todas as ofertas.

## Escopo inicial de implementação
1. Implementar janela flutuante nativa e fluxo de permissão.
2. Conectar a janela aos resultados da análise existentes.
3. Criar configurações individuais para mostrar/ocultar os dez indicadores.
4. Persistir as preferências no aparelho.
5. Testar no Uber; depois adaptar e validar no 99.
6. Confirmar que o cartão não bloqueia os controles de aceitar/recusar e ajustar posição/tamanho em aparelho real.

## Critérios de aceite
- O cartão aparece sobre o app de corrida depois de uma análise válida.
- A classificação e os indicadores selecionados atualizam automaticamente para uma nova oferta.
- Preferências permanecem salvas após fechar e reabrir o Acessor.
- Campos desativados não aparecem no cartão.
- Dados indisponíveis não são exibidos como se fossem reais.
- O cartão pode ser movido e não deve interceptar toques destinados aos controles da oferta.
