import 'package:supabase_flutter/supabase_flutter.dart';

class MembroService {
  final SupabaseClient supabase = Supabase.instance.client;

  // READ: Retorna todos os membros
  Future<List<Map<String, dynamic>>> getTodosMembros() async {
    return await supabase
        .from('membros')
        .select('membro_id, nome, email, data_cadastro')
        .order('nome', ascending: true);
  }

  // CREATE: Cadastra um novo membro
  // ATUALIZE ESTE MÉTODO em MembroService.dart
  Future<void> registrarMembro({
    required String nome,
    String? email, // Alterado para opcional
    DateTime? dataNascimento, // Alterado para opcional
    // NOVOS PARÂMETROS
    String? telefone,
    String? endereco,
    String? cpf,
  }) async {
    await supabase.from('membros').insert({
      'nome': nome,
      'email': email,
      'data_nascimento': dataNascimento?.toIso8601String().split('T').first,

      // NOVOS CAMPOS PARA INSERÇÃO NO BD
      'telefone': telefone,
      'endereco': endereco,
      'cpf': cpf,
    });
  }

  // E O MAIS IMPORTANTE:
  // Você deve rodar um script SQL ALTER TABLE na sua tabela 'membros' no Supabase
  // para adicionar as colunas 'telefone', 'endereco' e 'cpf'.

  // NOVO MÉTODO: Verifica se o livro já está emprestado pelo membro
  // Future<bool> isLivroEmprestadoPeloMembro({
  //   required String livroId,
  //   required String membroId,
  // }) async {
  //   final response = await supabase
  //       .from('emprestimos')
  //       .select('emprestimo_id')
  //       .eq('livro_id', livroId)
  //       .eq('membro_id', membroId)
  //       // CORREÇÃO: Usando .is_() (o método postgrest para IS NULL)
  //       .filter('data_devolucao', 'is', null)
  //       .limit(1);
  //
  //   // Se a lista de resultados não estiver vazia, significa que há um empréstimo ativo.
  //   return response.isNotEmpty;
  // }

  // FUNÇÃO RPC: Registra um novo empréstimo
  Future<void> registrarEmprestimo({
    required String livroId,
    required String membroId,
    required int diasEmprestimo,
  }) async {
    // 1. A VERIFICAÇÃO DE EMPRÉSTIMO DUPLICADO FOI REMOVIDA.
    // Agora, a função RPC será chamada diretamente, permitindo empréstimos duplicados.

    try {
      await supabase.rpc(
        'registrar_emprestimo_transacao',
        params: {
          'p_livro_id': livroId,
          'p_membro_id': membroId,
          'p_dias_emprestimo': diasEmprestimo,
        },
      );
    } on PostgrestException catch (e) {
      // Removemos o tratamento de erro de 'Estoque indisponível'
      throw Exception('Erro ao registrar empréstimo: ${e.message}');
    } catch (e) {
      throw Exception('Erro desconhecido: ${e.toString()}');
    }

    try {
      await supabase.rpc(
        'registrar_emprestimo_transacao',
        params: {
          'p_livro_id': livroId,
          'p_membro_id': membroId,
          'p_dias_emprestimo': diasEmprestimo,
        },
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('Estoque indisponível')) {
        // Se a verificação acima falhou por algum motivo, e o erro ainda é de estoque zero,
        // lançamos uma mensagem genérica de estoque.
        throw Exception(
          'Erro de Estoque: O livro não está disponível para empréstimo.',
        );
      }
      throw Exception('Erro ao registrar empréstimo: ${e.message}');
    } catch (e) {
      throw Exception('Erro desconhecido: ${e.toString()}');
    }
  }

  // FUNÇÃO RPC: Registra a devolução
  Future<void> registrarDevolucao({required String emprestimoId}) async {
    try {
      await supabase.rpc(
        'registrar_devolucao_transacao',
        params: {'p_emprestimo_id': emprestimoId},
      );
    } on PostgrestException catch (e) {
      throw Exception('Erro ao registrar devolução: ${e.message}');
    } catch (e) {
      throw Exception('Erro desconhecido: ${e.toString()}');
    }
  }

  // READ (RPC): Obtém o status resumido
  Future<Map<String, dynamic>> getStatusMembro(String membroId) async {
    final List<dynamic> result = await supabase.rpc(
      'get_status_membro',
      params: {'p_membro_id': membroId},
    );
    return result.isNotEmpty
        ? result.first as Map<String, dynamic>
        : {
            'total_emprestimos': 0,
            'atrasados_count': 0,
            'proxima_devolucao': null,
          };
  }

  // READ: Retorna livros com estoque disponível
  Future<List<Map<String, dynamic>>> getLivrosDisponiveis() async {
    return await supabase
        .from('livros')
        .select('*, LivroAutor(Autores(nome))')
        .gt('estoque_disponivel', 0)
        .order('titulo', ascending: true);
  }

  // READ/CREATE: Adiciona um livro da API ao catálogo
  Future<String> adicionarLivroAoCatalogo({
    required String titulo,
    required String isbn,
    required String autores,
    required String dataPublicacao,
    required String capaUrl,
  }) async {
    // --- 1. CORREÇÃO DO ISBN ÚNICO (Evita erro 23505) ---
    String isbnParaBD = isbn;

    if (isbnParaBD == 'N/A' || isbnParaBD.isEmpty || isbnParaBD == '0') {
      isbnParaBD = 'TEMP-${DateTime.now().microsecondsSinceEpoch}';
    }

    // --- 2. CORREÇÃO DA DATA (Evita erro 22007) ---
    final anoString = dataPublicacao.split('-').first;
    final int? ano = int.tryParse(anoString);

    String dataValida;
    if (ano != null && ano >= 1000 && ano <= DateTime.now().year) {
      dataValida = '$anoString-01-01';
    } else {
      dataValida = '2000-01-01';
    }

    final List<Map<String, dynamic>> results = await supabase
        .from('livros')
        .insert({
          'titulo': titulo,
          'isbn': isbnParaBD,
          'data_publicacao': dataValida,
          'capa_url': capaUrl, // Reativado após a criação da coluna
          'autor_display':
              autores, // Coluna criada para armazenar o nome dos autores
          'estoque_total': 1,
          'estoque_disponivel': 1,
        })
        .select('livro_id');

    if (results.isNotEmpty) {
      return results.first['livro_id'] as String;
    }
    throw Exception('Falha ao adicionar livro ao catálogo.');
  }

  // READ: Retorna os empréstimos ativos de um membro
  Future<List<Map<String, dynamic>>> getEmprestimosAtivos(
    String membroId,
  ) async {
    final response = await supabase
        .from('emprestimos')
        // Seleção de capa_url reativada, assumindo que a coluna já foi criada no BD
        .select(
          'emprestimo_id, data_emprestimo, data_prevista_devolucao, livros!inner(titulo, capa_url)',
        )
        .eq('membro_id', membroId)
        .filter('data_devolucao', 'is', null)
        .order('data_emprestimo', ascending: false);

    return response;
  }

  // Adicione ao seu MembroService.dart
  Future<String?> getLivroIdByIsbn(String isbn) async {
    final response = await supabase
        .from('livros')
        .select('livro_id')
        .eq('isbn', isbn)
        .limit(1);

    if (response.isNotEmpty) {
      return response.first['livro_id'] as String;
    }
    return null;
  }
}
