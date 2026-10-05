# Captura Android

A captura Android será implementada como adaptador separado do motor central.

Fluxo:
1. Usuário instala o Acessor.
2. O app explica claramente o que será lido e por quê.
3. Usuário concede a permissão necessária.
4. O adaptador observa somente os dados necessários para analisar a oferta.
5. O texto/dados capturados são enviados ao OfferPipeline.
6. O Acessor mostra BOA/ACEITAR ou RUIM/NAO ACEITAR.
7. O usuário continua sendo responsável por tocar no botão da plataforma.

Não usar a AccessibilityService para clicar automaticamente em aceitar.

Antes da publicação, preencher a declaração exigida pelo Google Play e manter a divulgação/consentimento dentro do app.
