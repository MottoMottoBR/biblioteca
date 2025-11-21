import 'package:supabase_flutter/supabase_flutter.dart';

class MembroService {
  final SupabaseClient supabase = Supabase.instance.client;

  // READ: Retorna todos os membros (Usado no Cadastro e Status)
  Future<List<Map<String, dynamic>>> getTodosMembros() async {
    // CORREÇÃO: Usando 'membros' em minúsculo para evitar PGRST205
    return await supabase
        .from('membros')
        .select('membro_id, nome, email, data_cadastro')
        .order('nome', ascending: true);
  }

  // CREATE: Cadastra um novo membro
  Future<void> registrarMembro({
    required String nome,
    required String email,
    required DateTime dataNascimento,
  }) async {
    // CORREÇÃO: Usando 'membros' em minúsculo
    await supabase.from('membros').insert({
      'nome': nome,
      'email': email,
      'data_nascimento': dataNascimento.toIso8601String().split('T').first,
    });
  }

  // FUNÇÃO RPC: Registra um novo empréstimo (Chama a transação SQL)
  Future<void> registrarEmprestimo({
    required String livroId,
    required String membroId,
    required int diasEmprestimo,
  }) async {
    try {
      // CORREÇÃO: Nomenclatura consistente (rpc minúsculo)
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
        // Ajuste o SELECT conforme a correção de chave que você descobriu
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
  }) async {
    // --- 1. CORREÇÃO DO ISBN ÚNICO (Para evitar erro 23505) ---
    String isbnParaBD = isbn;

    // Cria um valor único temporário se o ISBN for nulo ou inválido
    if (isbnParaBD == 'N/A' || isbnParaBD.isEmpty || isbnParaBD == '0') {
      isbnParaBD = 'TEMP-' + DateTime.now().microsecondsSinceEpoch.toString();
    }

    // --- 2. CORREÇÃO DA DATA (Para evitar erro 22007) ---
    // Garante que o formato é YYYY-MM-DD para a coluna DATE do PostgreSQL
    final ano = dataPublicacao.split('-').first;
    final dataValida = '$ano-01-01';

    final List<Map<String, dynamic>> results = await supabase
        .from('livros')
        .insert({
          'titulo': titulo,
          'isbn': isbnParaBD,
          'data_publicacao': dataValida,
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
        // Ajuste o select de livros (minúsculo) conforme a correção que você descobriu
        .select('emprestimo_id, data_emprestimo, data_prevista_devolucao, livros!inner(titulo)')
        .eq('membro_id', membroId)
        // CORREÇÃO FINAL: Uso correto do .is() para filtrar NULL
        .filter('data_devolucao', 'is', null)
        .order('data_emprestimo', ascending: false);

    return response;
  }
}
