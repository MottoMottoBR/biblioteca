import 'package:flutter/material.dart';

// --- Imports de Serviços ---
import '../dados/google_books_service.dart';
import '../dados/membro_service.dart';

// --- Imports de Telas ---
import '../dados/status_membro_screen.dart';
import 'livro_detalhes_page.dart';
import 'membro_cadastro_page.dart';

class LivrosApiScreen extends StatefulWidget {
  const LivrosApiScreen({super.key});

  @override
  State<LivrosApiScreen> createState() => _LivrosApiScreenState();
}

class _LivrosApiScreenState extends State<LivrosApiScreen> {
  final GoogleBooksService _service = GoogleBooksService();
  // Não precisamos do MembroService aqui, mas mantemos a instância por convenção se for usada em outro lugar
  // final MembroService _membroService = MembroService();

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

  // --- FUNÇÃO _adicionarECatalogar REMOVIDA: A lógica de empréstimo foi movida para LivroDetalhesScreen ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Catálogo de Livros (Google Books API)'),
        backgroundColor: Colors.indigo.shade800,
        elevation: 0,
        actions: [
          // Botão de acesso ao Cadastro de Membros
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            tooltip: 'Cadastrar Novo Membro',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MembroCadastroScreen(),
                ),
              );
            },
          ),

          // Botão de acesso à Devolução/Status
          IconButton(
            icon: const Icon(Icons.assignment_turned_in, color: Colors.white),
            tooltip: 'Gerenciar Empréstimos e Devoluções',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StatusMembroScreen(),
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

  // --- Widgets de Componentes (demais métodos mantidos) ---

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

  // FUNÇÃO MODIFICADA: O Botão agora apenas navega para a tela de detalhes
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
            // Botão de Ação (VER DETALHES E EMPRESTAR)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navega para a tela de Detalhes, que contém a lógica de empréstimo.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LivroDetalhesScreen(livro: livro),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 20),
                label: const Text('Ver Detalhes e Emprestar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, // Cor alterada para Detalhes
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