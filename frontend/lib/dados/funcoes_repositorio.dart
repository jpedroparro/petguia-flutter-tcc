import "dart:convert";

import "package:firebase_auth/firebase_auth.dart";
import "package:http/http.dart" as http;

import "api_config.dart";

/// Erro lançado quando a API responde com o campo `error` preenchido —
/// mesmo shape `{ data, error }` usado no sistema web.
class FuncaoRepositorioException implements Exception {
  final String mensagem;

  FuncaoRepositorioException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Ponte com a API auto-hospedada (módulo de Planejamento da Execução) —
/// toda escrita de negócio da equipe passa por aqui, nunca por escrita
/// direta no Firestore do cliente.
class FuncoesRepositorio {
  final http.Client _client;
  final String _baseUrl;

  FuncoesRepositorio({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<Map<String, String>> _cabecalhos() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  dynamic _tratarResposta(http.Response resposta) {
    final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
    final erro = corpo["error"];
    if (erro != null) {
      throw FuncaoRepositorioException(erro as String);
    }
    return corpo["data"];
  }

  /// Plano free do Render "dorme" depois de inatividade — a primeira
  /// requisição depois disso pode levar ~30s pra acordar o servidor, então
  /// o timeout precisa ser generoso o bastante pra não cortar isso, mas
  /// finito pra nunca deixar a tela girando pra sempre.
  static const _tempoLimite = Duration(seconds: 45);

  /// Tanto buscar o token (Firebase) quanto a chamada HTTP em si podem
  /// travar numa rede ruim — o timeout precisa envolver os dois, nunca só
  /// o `_client.post`/`.get`, senão uma trava no `getIdToken()` nunca é
  /// cortada.
  Future<http.Response> _executarComTempoLimite(
    Future<http.Response> Function(Map<String, String> cabecalhos) chamada,
  ) {
    return (() async {
      final cabecalhos = await _cabecalhos();
      return chamada(cabecalhos);
    })().timeout(_tempoLimite);
  }

  Future<dynamic> _post(String caminho, [Map<String, dynamic>? corpo]) async {
    final resposta = await _executarComTempoLimite(
      (cabecalhos) => _client.post(
        Uri.parse("$_baseUrl$caminho"),
        headers: cabecalhos,
        body: jsonEncode(corpo ?? const {}),
      ),
    );
    return _tratarResposta(resposta);
  }

  Future<dynamic> _get(String caminho) async {
    final resposta = await _executarComTempoLimite(
      (cabecalhos) =>
          _client.get(Uri.parse("$_baseUrl$caminho"), headers: cabecalhos),
    );
    return _tratarResposta(resposta);
  }

  Future<dynamic> _put(String caminho, [Map<String, dynamic>? corpo]) async {
    final resposta = await _executarComTempoLimite(
      (cabecalhos) => _client.put(
        Uri.parse("$_baseUrl$caminho"),
        headers: cabecalhos,
        body: jsonEncode(corpo ?? const {}),
      ),
    );
    return _tratarResposta(resposta);
  }

  Future<Map<String, dynamic>> cadastrarAnimal(
    Map<String, dynamic> dados,
  ) async {
    final resultado = await _post("/animais", dados);
    return Map<String, dynamic>.from(resultado as Map);
  }

  /// Geocodificação reversa (Módulo de Comunicação com Sistemas Externos —
  /// Nominatim) — retorna `{rua, bairro, cep}` pro ponto informado, ou null
  /// se o serviço não encontrou nada. Usada só pra sugerir o preenchimento;
  /// os campos continuam editáveis à mão.
  Future<Map<String, dynamic>?> buscarEnderecoPorCoordenadas(
    double latitude,
    double longitude,
  ) async {
    final dados = await _get("/geo/reverso?lat=$latitude&lon=$longitude");
    return dados == null ? null : Map<String, dynamic>.from(dados as Map);
  }

  /// Geocodificação direta (CEP, rua ou endereço livre -> coordenadas) —
  /// usada pela busca por região do portal público. Retorna null se o
  /// endereço não foi encontrado em Rio do Sul.
  Future<({double latitude, double longitude})?> geocodificarEndereco(
    String endereco,
  ) async {
    final dados = await _get(
      "/geo/geocodificar?endereco=${Uri.encodeQueryComponent(endereco)}",
    );
    if (dados == null) return null;
    final mapa = Map<String, dynamic>.from(dados as Map);
    return (
      latitude: (mapa["latitude"] as num).toDouble(),
      longitude: (mapa["longitude"] as num).toDouble(),
    );
  }

  /// Ranking de urgência dos animais "resgatados" — Módulo de Análise e
  /// Tomada de Decisão. Cada item traz `animal.id`, `classificacaoRua`,
  /// `horasAteInterditar` e `motivo` (explicação legível da pontuação).
  Future<List<Map<String, dynamic>>> listarUrgencia() async {
    final dados = await _get("/animais/urgencia") as List;
    return dados.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> criarAbrigo(Map<String, dynamic> dados) async {
    await _post("/abrigos", dados);
  }

  Future<void> atualizarAbrigo(String id, Map<String, dynamic> dados) async {
    await _put("/abrigos/$id", dados);
  }

  /// Solicitação pública de reunificação com o tutor original — não exige
  /// login (o público não tem conta), mesmo padrão do sistema web.
  Future<void> solicitarReunificacao(Map<String, dynamic> dados) async {
    await _post("/reunificacoes", dados);
  }

  /// Registra um pedido de tutoria temporária. Usado hoje só pela equipe,
  /// no próprio cadastro do animal — a rota em si não exige login (mesmo
  /// endpoint que já existia), mas nada no app chama isso sem a equipe
  /// estar autenticada e confirmar em seguida (ver `confirmarTutoria`).
  Future<Map<String, dynamic>> solicitarTutoria(
    Map<String, dynamic> dados,
  ) async {
    final resultado = await _post("/tutorias", dados);
    return Map<String, dynamic>.from(resultado as Map);
  }

  Future<void> marcarAnimalComoEmAbrigo(
    String animalId,
    String abrigoId,
  ) async {
    await _post("/animais/$animalId/em-abrigo", {"abrigoId": abrigoId});
  }

  Future<void> marcarAnimalComoReunificado(String animalId) async {
    await _post("/animais/$animalId/reunificado");
  }

  Future<void> marcarAnimalComoComTutor(String animalId) async {
    await _post("/animais/$animalId/com-tutor");
  }

  Future<List<Map<String, dynamic>>> listarSolicitacoesTutoria() async {
    final dados = await _get("/tutorias") as List;
    return dados.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> confirmarTutoria(String id) async {
    await _post("/tutorias/$id/confirmar");
  }

  Future<List<Map<String, dynamic>>> listarSolicitacoesReunificacao() async {
    final dados = await _get("/reunificacoes") as List;
    return dados.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> confirmarReunificacao(String id) async {
    await _post("/reunificacoes/$id/confirmar");
  }

  Future<void> recusarReunificacao(String id) async {
    await _post("/reunificacoes/$id/recusar");
  }

  /// Nível atual do rio, classificação (normal/atenção/alerta/emergência) e
  /// ruas afetadas — Módulo de Análise e Decisão, dado público de segurança.
  Future<Map<String, dynamic>> buscarRio() async {
    final dados = await _get("/rio");
    return Map<String, dynamic>.from(dados as Map);
  }

  /// As 3 estações monitoradas publicamente pela Defesa Civil de Rio do Sul.
  Future<List<Map<String, dynamic>>> buscarEstacoesRio() async {
    final dados = await _get("/rio/estacoes") as List;
    return dados.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Alerta público de resgate urgente (animal preso/ilhado, precisa de
  /// equipamento especial) — não exige login, mesmo padrão de tutoria e
  /// reunificação.
  Future<void> solicitarResgate(Map<String, dynamic> dados) async {
    await _post("/resgates", dados);
  }

  /// Fila de alertas de resgate — só a equipe (Defesa Civil/bombeiros) vê.
  Future<List<Map<String, dynamic>>> listarSolicitacoesResgate() async {
    final dados = await _get("/resgates") as List;
    return dados.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> marcarResgateEmAtendimento(String id) async {
    await _post("/resgates/$id/atender");
  }

  Future<void> marcarResgateConcluido(String id) async {
    await _post("/resgates/$id/concluir");
  }

  /// Painel único do operador de campo — Módulo de Supervisão da
  /// Execução. Junta nível do rio, ruas bloqueadas, risco da posição
  /// atual do operador e os alertas de resgate mais urgentes/próximos.
  /// Sem [latitude]/[longitude], vem sem avaliação de risco pessoal e os
  /// alertas ficam ordenados só por urgência, sem desempate por distância.
  Future<Map<String, dynamic>> buscarPainelOperador({
    double? latitude,
    double? longitude,
  }) async {
    final query = (latitude != null && longitude != null)
        ? "?lat=$latitude&lon=$longitude"
        : "";
    final dados = await _get("/painel-operador$query");
    return Map<String, dynamic>.from(dados as Map);
  }
}
