import 'package:flutter/material.dart';
import '../dados/emprestimo_service.dart';
import '../dados/membro_service.dart'; // Seu serviço (MembroService/BibliotecaService)

class EmprestimoScreen extends StatefulWidget {
  // Parâmetros opcionais (NULLABLE) para quando a tela for chamada
  // diretamente de uma busca (LivrosApiScreen).
  final String? livroIdInicial;
  final String? tituloLivroInicial;

  const EmprestimoScreen({
    super.key,
    this.livroIdInicial,
    this.tituloLivroInicial,
  });

  @override
  State<EmprestimoScreen> createState() => _EmprestimoScreenState();
}

class _EmprestimoScreenState extends State<EmprestimoScreen> {
  final MembroService _service = MembroService();
  List<Map<String, dynamic>> _livros = [];
  List<Map<String, dynamic>> _membros = [];
  String? _selectedMembroId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final livros = await _service.getLivrosDisponiveis();
      final membros = await _service
          .getTodosMembros(); // Assumindo que o nome do método é getTodosMembros

      setState(() {
        _livros = livros;
        _membros = membros;

        // CORREÇÃO E ROBUSTEZ: Se nenhum membro estiver selecionado, define o primeiro.
        if (_membros.isNotEmpty && _selectedMembroId == null) {
          _selectedMembroId = _membros.first['membro_id']?.toString();
        }

        _isLoading = false;
      });
    } catch (e) {
      _showSnackbar('Erro ao carregar dados: ${e.toString()}', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _handleEmprestimo(String livroId, String livroTitulo) async {
    // Certifica-se de que o membro está selecionado E o ID não é nulo.
    if (_selectedMembroId == null || _selectedMembroId!.isEmpty) {
      _showSnackbar('Selecione um membro para o empréstimo.', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Chama o método RPC (registrar_emprestimo_transacao) no serviço
      await _service.registrarEmprestimo(
        livroId: livroId,
        membroId: _selectedMembroId!,
        diasEmprestimo: 10,
      );

      _showSnackbar(
        'Empréstimo de "$livroTitulo" registrado com sucesso!',
        Colors.green,
      );

      // Recarrega os dados para atualizar o estoque
      await _loadData();
    } on Exception catch (e) {
      // Trata exceções lançadas pelo serviço (ex: estoque indisponível)
      _showSnackbar(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Empréstimos'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMembroSelector(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Livros Disponíveis em Estoque:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _livros.isEmpty
                      ? const Center(
                          child: Text('Nenhum livro disponível no momento.'),
                        )
                      : ListView.builder(
                          itemCount: _livros.length,
                          itemBuilder: (context, index) {
                            final livro = _livros[index];

                            // Extração de autor (mantida, mas depende do JOIN correto no getLivrosDisponiveis)
                            String autorNome = 'Desconhecido';
                            final autoresData = livro['LivroAutor'] as List?;

                            if (autoresData != null && autoresData.isNotEmpty) {
                              final primeiroAutor =
                                  autoresData[0]['Autores']
                                      as Map<String, dynamic>?;
                              autorNome =
                                  primeiroAutor?['nome'] ?? 'Desconhecido';
                            }
                            // Fim da extração de autor

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: 2,
                              child: ListTile(
                                title: Text(
                                  livro['titulo'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Autor: $autorNome | Estoque: ${livro['estoque_disponivel']}',
                                ),
                                trailing:
                                    (livro['estoque_disponivel'] as int) > 0
                                    ? ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.outbound,
                                          size: 18,
                                        ),
                                        label: const Text('Emprestar'),
                                        onPressed: () => _handleEmprestimo(
                                          livro['livro_id'].toString(),
                                          livro['titulo'].toString(),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Indisponível',
                                        style: TextStyle(color: Colors.red),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
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
    return Row(
      children: [
        const Text('Emprestar para:', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true, // Adiciona isExpanded para evitar overflow
            value: _selectedMembroId,
            hint: const Text('Selecione o Membro'),
            items: _membros.map((m) {
              return DropdownMenuItem<String>(
                value: m['membro_id'].toString(),
                child: Text(
                  '${m['nome']} (${m['email']})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedMembroId = newValue;
              });
            },
          ),
        ),
      ],
    );
  }
}
