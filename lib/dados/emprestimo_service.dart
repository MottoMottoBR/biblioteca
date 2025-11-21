import 'package:flutter/material.dart';

import 'membro_service.dart';

class EmprestimoScreen extends StatefulWidget {
  final String livroId;
  final String tituloLivro;

  const EmprestimoScreen({
    super.key,
    required this.livroId,
    required this.tituloLivro,
  });

  @override
  State<EmprestimoScreen> createState() => _EmprestimoScreenState();
}

class _EmprestimoScreenState extends State<EmprestimoScreen> {
  final MembroService _service = MembroService();
  List<Map<String, dynamic>> _membros = [];
  String? _selectedMembroId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembros();
  }

  Future<void> _loadMembros() async {
    try {
      final todosMembros = await _service.getTodosMembros();
      setState(() {
        _membros = todosMembros;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackbar('Erro ao carregar membros: ${e.toString()}', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarEmprestimo() async {
    if (_selectedMembroId == null) {
      _showSnackbar('Por favor, selecione um membro.', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Chama a função RPC transacional no Supabase
      await _service.registrarEmprestimo(
        livroId: widget.livroId,
        membroId: _selectedMembroId!,
        diasEmprestimo: 10, // Empréstimo padrão de 7 dias
      );

      _showSnackbar(
        'Empréstimo de "${widget.tituloLivro}" registrado com sucesso! (Estoque atualizado)',
        Colors.green,
      );
      // Volta para a tela anterior
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackbar(e.toString(), Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Empréstimo'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Livro a ser Emprestado:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                widget.tituloLivro,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const Divider(height: 30),

              const Text('Selecione o Membro:', style: TextStyle(fontSize: 16)),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedMembroId,
                      hint: const Text('Escolha um membro cadastrado'),
                      items: _membros.map((membro) {
                        return DropdownMenuItem<String>(
                          value: membro['membro_id'].toString(),
                          child: Text('${membro['nome']} (${membro['email']})'),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() => _selectedMembroId = newValue);
                      },
                      validator: (value) =>
                          value == null ? 'Seleção obrigatória.' : null,
                    ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _finalizarEmprestimo,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Confirmar Empréstimo (7 dias)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
