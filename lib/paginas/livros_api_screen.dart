import 'package:flutter/material.dart';

import 'emprestimo_page.dart';
import '../dados/google_books_service.dart';
import '../dados/membro_service.dart';
import 'membro_cadastro_page.dart';

class LivrosApiScreen extends StatefulWidget {
  const LivrosApiScreen({super.key});

  @override
  State<LivrosApiScreen> createState() => _LivrosApiScreenState();
}

class _LivrosApiScreenState extends State<LivrosApiScreen> {
  final GoogleBooksService _service = GoogleBooksService();
  final MembroService _membroService = MembroService(); // Instância do Serviço

  List<Map<String, dynamic>> _livrosEncontrados = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController(
    text: 'Flutter',
  );

  @override
  void initState() {
    super.initState();
    _buscarLivros(_searchController.text);
  }

  Future<void> _buscarLivros(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
    });

    final results = await _service.searchBooks(query);

    setState(() {
      _livrosEncontrados = results;
      _isLoading = false;
    });
  }

  // FUNÇÃO PRINCIPAL: CATALOGA O LIVRO E INICIA O PROCESSO DE EMPRÉSTIMO
  void _adicionarECatalogar(Map<String, dynamic> livro) async {
    // 1. Inserir o livro no Supabase para obter o livro_id
    try {
      final livroId = await _membroService.adicionarLivroAoCatalogo(
        titulo: livro['titulo'] as String,
        isbn: livro['isbn'] as String,
        autores: livro['autores'] as String,
        dataPublicacao: livro['data_publicacao'] as String,
      );

      // 2. Feedback visual e navegação para a tela de empréstimo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Livro "${livro['titulo']}" catalogado. Registrando empréstimo...'),
          backgroundColor: Colors.blue.shade700,
        ),
      );

      // Navega, passando o ID do livro criado
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmprestimoScreen(
            livroIdInicial: livroId,
            tituloLivroInicial: livro['titulo'] as String,
          ),
        ),
      );

    } catch (e) {
      // Trata erros de inserção (ex: ISBN duplicado, erro de BD)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao catalogar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Catálogo de Livros (Google Books API)'),
        backgroundColor: Colors.indigo.shade800,
        elevation: 0,
        actions: [
          // Botão de acesso à Gestão de Membros
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            tooltip: 'Gerenciar Membros (Cadastro e Status)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MembroCadastroScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_isLoading)
            const LinearProgressIndicator(color: Colors.indigoAccent)
          else
            Expanded(
              child: _livrosEncontrados.isEmpty
                  ? _buildEmptyState()
                  : _buildBooksGrid(),
            ),
        ],
      ),
    );
  }

  // --- Widgets de Componentes ---

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.indigo.shade100,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Buscar Título ou Autor',
          fillColor: Colors.white,
          filled: true,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search, color: Colors.indigo),
            onPressed: () => _buscarLivros(_searchController.text),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        ),
        onSubmitted: _buscarLivros,
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'Nenhum livro encontrado para esta pesquisa.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.7,
      ),
      itemCount: _livrosEncontrados.length,
      itemBuilder: (context, index) {
        final livro = _livrosEncontrados[index];
        return _buildBookCard(livro);
      },
    );
  }

  Widget _buildBookCard(Map<String, dynamic> livro) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem da Capa (Centralizada)
            Center(
              child: Container(
                height: 150,
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (livro['capa_url'] as String).isNotEmpty
                      ? Image.network(
                    livro['capa_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.book_outlined, size: 60),
                  )
                      : const Icon(Icons.book, size: 60, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Título
            Text(
              livro['titulo'] as String,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),

            // Autor(es)
            Text(
              'Autor: ${livro['autores']}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // ISBN e Data
            Text(
              'ISBN: ${livro['isbn']}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              'Ano: ${livro['data_publicacao'].split('-').first}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),

            const Spacer(), // Empurra o botão para baixo

            // Botão de Ação (Adicionar ao Catálogo/Supabase)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Usa a nova função de catalogar e emprestar
                onPressed: () => _adicionarECatalogar(livro),
                icon: const Icon(Icons.swap_horiz, size: 20), // Ícone de troca/empréstimo
                label: const Text('Catalogar e Emprestar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}