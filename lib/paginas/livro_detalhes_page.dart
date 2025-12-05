import 'package:flutter/material.dart';
import '../dados/membro_service.dart';

class LivroDetalhesScreen extends StatefulWidget {
  final Map<String, dynamic> livro;
  const LivroDetalhesScreen({super.key, required this.livro});

  @override
  State<LivroDetalhesScreen> createState() => _LivroDetalhesScreenState();
}

class _LivroDetalhesScreenState extends State<LivroDetalhesScreen> {
  final MembroService _service = MembroService();
  List<Map<String, dynamic>> _membros = [];
  String? _selectedMembroId;
  bool _isLoading = true;
  String? _livroIdCatalogado; // Mantido para referência, mas a lógica usa 'livroId' localmente.

  final _diasEmprestimoController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _diasEmprestimoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final membros = await _service.getTodosMembros();
      setState(() {
        _membros = membros;
        _isLoading = false;

        // CORREÇÃO E ROBUSTEZ: Se o estado for recriado e o livro já tiver ID no BD,
        // o _livroIdCatalogado não será setado aqui, o que é OK, pois será setado no _handleEmprestimo.
      });
    } catch (e) {
      _showSnackbar('Erro ao carregar membros: ${e.toString().replaceFirst('Exception: ', '')}', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmprestimo() async {
    if (_selectedMembroId == null || _selectedMembroId!.isEmpty) {
      _showSnackbar('Selecione uma pessoa (membro) para o empréstimo.', Colors.orange);
      return;
    }

    final int? diasEmprestimo = int.tryParse(_diasEmprestimoController.text);
    if (diasEmprestimo == null || diasEmprestimo <= 0) {
      _showSnackbar('Insira um prazo válido (número de dias) para o empréstimo.', Colors.orange);
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final livro = widget.livro;
      final String capaUrl = (livro['capa_url'] ?? '') as String;
      final String isbnLivro = (livro['isbn'] ?? 'N/A') as String;

      // --- 1. VERIFICAÇÃO/CATALOGAÇÃO (RESOLVE O ERRO 23505) ---
      // Tenta encontrar o livro pelo ISBN no catálogo.
      String? livroId = await _service.getLivroIdByIsbn(isbnLivro);

      if (livroId == null) {
        // Se o livro NÃO existe no catálogo, cataloga-o.
        _livroIdCatalogado = await _service.adicionarLivroAoCatalogo(
          titulo: (livro['titulo'] ?? 'Título Desconhecido') as String,
          isbn: isbnLivro,
          autores: (livro['autores'] ?? 'Autor Desconhecido') as String,
          dataPublicacao: (livro['data_publicacao'] ?? '2000') as String,
          capaUrl: capaUrl,
        );
        livroId = _livroIdCatalogado;
      } else {
        // Se o livro JÁ existe, usa o ID encontrado e evita o erro 23505.
        _livroIdCatalogado = livroId;
      }

      // Garante que temos um ID válido antes de continuar
      if (livroId == null) {
        throw Exception('Falha ao obter o ID do livro.');
      }


      // --- 2. VERIFICAÇÃO DE EMPRÉSTIMO DUPLICADO (REMOVIDA) ---
      // A lógica que chamava: `await _service.isLivroEmprestadoPeloMembro(...)`
      // e o bloco `if (jaEmprestado)` foram removidos.
      // Agora o fluxo segue diretamente para o registro do empréstimo.


      // --- 3. REGISTRAR O EMPRÉSTIMO ---
      await _service.registrarEmprestimo(
        livroId: livroId,
        membroId: _selectedMembroId!,
        diasEmprestimo: diasEmprestimo,
      );

      _showSnackbar(
        'Empréstimo de "${livro['titulo']}" para o membro registrado com sucesso! Prazo: $diasEmprestimo dias.',
        Colors.green,
      );

      Navigator.pop(context);
    } on Exception catch (e) {
      // O catch agora lida com erros de estoque ou outros erros de DB
      _showSnackbar(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color)
    );
  }

  @override
  Widget build(BuildContext context) {
    final livro = widget.livro;
    final titulo = (livro['titulo'] ?? 'Livro Sem Título') as String;
    final capaUrl = (livro['capa_url'] ?? '') as String;
    final autores = (livro['autores'] ?? 'Autor Desconhecido') as String;
    final isbn = (livro['isbn'] ?? 'N/A') as String;
    final anoPublicacao = (livro['data_publicacao']?.split('-').first ?? 'Ano Desconhecido') as String;
    final descricao = (livro['descricao'] ?? 'Sem descrição disponível.') as String;

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.network(
                capaUrl,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.book, size: 100, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Detalhes do Livro',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
            ),
            const Divider(),

            _buildDetailRow('Autor(es):', autores),
            _buildDetailRow('ISBN:', isbn),
            _buildDetailRow('Ano de Publicação:', anoPublicacao),
            _buildDetailRow('Descrição:', descricao),
            const SizedBox(height: 30),

            Text(
              'Registrar Empréstimo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 10),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMembroSelector(),

            const SizedBox(height: 15),

            // NOVO CAMPO: Prazo de Empréstimo
            TextFormField(
              controller: _diasEmprestimoController,
              decoration: const InputDecoration(
                labelText: 'Prazo de Empréstimo (dias)',
                hintText: 'Ex: 10',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.timer),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (int.tryParse(value ?? '') == null || (int.tryParse(value ?? '') ?? 0) <= 0) {
                  return 'Insira um número de dias válido.';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleEmprestimo,
                icon: const Icon(Icons.outbound, size: 20),
                label: Text(
                  // Atualiza o texto do botão com base no ID encontrado
                  _livroIdCatalogado == null ? 'Catalogar e Emprestar' : 'Emprestar Livro',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(value, style: const TextStyle(fontSize: 15), softWrap: true),
        ],
      ),
    );
  }

  Widget _buildMembroSelector() {
    if (_membros.isEmpty) {
      return const Text(
        'Nenhum membro cadastrado. Cadastre um membro primeiro.',
        style: TextStyle(color: Colors.red),
      );
    }
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Selecionar Pessoa para Empréstimo',
        border: OutlineInputBorder(),
      ),
      value: _selectedMembroId,
      hint: const Text('Pesquisar por Nome/Email'),
      items: _membros.map((m) {
        final membroIdStr = m['membro_id']?.toString() ?? '';
        final nomeEmail = '${m['nome']} (${m['email']})';

        return DropdownMenuItem<String>(
          value: membroIdStr,
          child: Text(
            nomeEmail,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedMembroId = newValue;
        });
      },
    );
  }
}