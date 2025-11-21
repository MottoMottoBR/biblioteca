import 'package:flutter/material.dart';
import '../dados/membro_service.dart'; // Importe seu serviço (Localização ajustada)

class StatusMembroScreen extends StatefulWidget {
  const StatusMembroScreen({super.key});

  @override
  State<StatusMembroScreen> createState() => _StatusMembroScreenState();
}

class _StatusMembroScreenState extends State<StatusMembroScreen> {
  final MembroService _service = MembroService();
  List<Map<String, dynamic>> _membros = [];
  String? _selectedMembroId;
  List<Map<String, dynamic>> _emprestimosAtivos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembros(); // Carrega todos os membros ao iniciar a tela
  }

  // --- Funções de Carregamento de Dados ---

  Future<void> _loadMembros() async {
    try {
      final membros = await _service.getTodosMembros(); // Usa o método do service
      setState(() {
        _membros = membros;
        if (_membros.isNotEmpty) {
          // Define o primeiro membro como padrão para iniciar a busca de empréstimos
          _selectedMembroId = _membros.first['membro_id']?.toString();
          _loadEmprestimos(_selectedMembroId!);
        }
        _isLoading = false;
      });
    } catch (e) {
      _showSnackbar('Erro ao carregar membros: ${e.toString().replaceFirst('Exception: ', '')}', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmprestimos(String membroId) async {
    setState(() {
      _isLoading = true;
      _emprestimosAtivos = [];
    });
    try {
      final emprestimos = await _service.getEmprestimosAtivos(membroId); // Busca empréstimos ativos
      setState(() {
        _emprestimosAtivos = emprestimos;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackbar('Erro ao carregar empréstimos: ${e.toString().replaceFirst('Exception: ', '')}', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // --- Função de Ação ---

  Future<void> _handleDevolucao(String emprestimoId, String livroTitulo) async {
    setState(() => _isLoading = true);
    try {
      await _service.registrarDevolucao(emprestimoId: emprestimoId); // Chama a RPC de devolução
      _showSnackbar('Livro "$livroTitulo" devolvido com sucesso!', Colors.green);

      // Recarrega a lista para atualizar a UI e remover o item devolvido
      await _loadEmprestimos(_selectedMembroId!);
    } on Exception catch (e) {
      _showSnackbar(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status e Devoluções de Membros'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading && _membros.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMembroSelector(),
          _buildEmprestimosHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildEmprestimosList(),
          ),
        ],
      ),
    );
  }

  // --- Widgets de UI ---

  Widget _buildMembroSelector() {
    if (_membros.isEmpty && !_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Nenhum membro encontrado. Cadastre um membro primeiro.', style: TextStyle(color: Colors.red)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Membro',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_search, color: Colors.teal),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        value: _selectedMembroId,
        hint: const Text('Selecione um membro'),
        items: _membros.map((m) {
          return DropdownMenuItem<String>(
            value: m['membro_id'].toString(),
            child: Text(m['nome'] as String),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedMembroId = newValue;
            });
            _loadEmprestimos(newValue); // Recarrega os empréstimos para o novo membro
          }
        },
      ),
    );
  }

  Widget _buildEmprestimosHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        'Empréstimos Ativos:',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
      ),
    );
  }

  Widget _buildEmprestimosList() {
    if (_emprestimosAtivos.isEmpty) {
      // ... (código para lista vazia)
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 50, color: Colors.green),
            SizedBox(height: 10),
            Text(
              'Nenhum empréstimo ativo para este membro.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _emprestimosAtivos.length,
      itemBuilder: (context, index) {
        final e = _emprestimosAtivos[index];

        // Acesso seguro aos dados do JOIN
        final livroData = e['livros'] as Map<String, dynamic>?;

        final livroTitulo = livroData?['titulo'] ?? 'Livro Desconhecido';
        // GARANTIA: Acessa a URL da capa
        final capaUrl = livroData?['capa_url'] as String?;

        final dataPrevistaStr = e['data_prevista_devolucao'] as String?;
        final dataPrevista = (dataPrevistaStr != null)
            ? DateTime.parse(dataPrevistaStr).toLocal().toString().split(' ')[0]
            : 'N/A';

        // Determina se a URL é válida para ser usada
        final bool hasCapa = capaUrl != null && capaUrl.isNotEmpty;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: ListTile(
            leading: SizedBox(
              width: 50,
              height: 80,
              child: hasCapa
                  ? Image.network(
                capaUrl!,
                fit: BoxFit.cover,
                // Fallback se a URL da imagem falhar
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.menu_book, color: Colors.teal, size: 40),
              )
              // Fallback se a URL for nula ou vazia no BD
                  : const Icon(Icons.menu_book, color: Colors.teal, size: 40),
            ),

            title: Text(livroTitulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Emprestado em: ${e['data_emprestimo'].split('T')[0]}\nDevolução Prevista: $dataPrevista'),
            isThreeLine: true,
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.keyboard_return, size: 18),
              label: const Text('Devolver'),
              onPressed: () => _handleDevolucao(e['emprestimo_id'].toString(), livroTitulo),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }  }