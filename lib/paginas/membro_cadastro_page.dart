import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../dados/membro_service.dart';

class MembroCadastroScreen extends StatefulWidget {
  const MembroCadastroScreen({super.key});

  @override
  State<MembroCadastroScreen> createState() => _MembroCadastroScreenState();
}

class _MembroCadastroScreenState extends State<MembroCadastroScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MembroService _service = MembroService();

  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dataNascimento;

  List<Map<String, dynamic>> _membros = [];
  Map<String, dynamic>? _selectedMembro;
  Map<String, dynamic>? _statusEmprestimo;
  List<Map<String, dynamic>> _emprestimosAtivos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMembros();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitCadastro() async {
    if (_formKey.currentState!.validate() && _dataNascimento != null) {
      setState(() => _isLoading = true);
      try {
        await _service.registrarMembro(
          nome: _nomeController.text,
          email: _emailController.text,
          dataNascimento: _dataNascimento!,
        );
        _showSnackbar(
          'Membro ${_nomeController.text} cadastrado com sucesso!',
          Colors.green,
        );
        _resetForm();
        await _loadMembros();
      } catch (e) {
        _showSnackbar('Erro ao cadastrar: ${e.toString()}', Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    } else if (_dataNascimento == null) {
      _showSnackbar('Selecione a Data de Nascimento.', Colors.orange);
    }
  }

  void _resetForm() {
    _nomeController.clear();
    _emailController.clear();
    setState(() => _dataNascimento = null);
  }

  Future<void> _loadMembros() async {
    setState(() => _isLoading = true);
    try {
      _membros = await _service.getTodosMembros();
      setState(() {
        _isLoading = false;
        if (_membros.isNotEmpty && _selectedMembro == null) {
          _selectedMembro = _membros.first;
          _loadStatus(_selectedMembro!['membro_id'].toString());
        } else if (_membros.isEmpty) {
          _selectedMembro = null;
          _statusEmprestimo = null;
          _emprestimosAtivos = [];
        }
      });
    } catch (e) {
      _showSnackbar('Erro ao carregar membros: ${e.toString()}', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatus(String membroId) async {
    setState(() {
      _isLoading = true;
      _statusEmprestimo = null;
      _emprestimosAtivos = [];
    });
    try {
      final status = await _service.getStatusMembro(membroId);
      final ativos = await _service.getEmprestimosAtivos(membroId);
      setState(() {
        _statusEmprestimo = status;
        _emprestimosAtivos = ativos;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackbar('Erro ao buscar status: ${e.toString()}', Colors.red);
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
        title: const Text('Gestão de Membros da Biblioteca'),
        backgroundColor: Colors.black12,
        bottom: TabBar(
          labelColor: Colors.black,
          indicator: BoxDecoration(color: Colors.blue),
          indicatorSize: TabBarIndicatorSize.tab,
          unselectedLabelColor: Colors.white,
          controller: _tabController,
          tabs: [
            Tab(text: 'Cadastrar Novo Membro', icon: Icon(Icons.person_add)),
            Tab(text: 'Consultar Status', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCadastroForm(), _buildConsultaStatus()],
      ),
    );
  }

  Widget _buildCadastroForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ficha de Cadastro',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Divider(),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    icon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Nome é obrigatório.' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    icon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty || !value.contains('@')
                      ? 'Email inválido.'
                      : null,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _dataNascimento == null
                        ? 'Selecione a Data de Nascimento'
                        : 'Nascimento: ${DateFormat('dd/MM/yyyy').format(_dataNascimento!)}',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null)
                      setState(() => _dataNascimento = picked);
                  },
                ),
                const SizedBox(height: 30),
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _submitCadastro,
                          icon: const Icon(Icons.save),
                          label: const Text('Cadastrar Membro'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsultaStatus() {
    if (_isLoading && _membros.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_membros.isEmpty) {
      return const Center(child: Text('Nenhum membro cadastrado.'));
    }

    return Row(
      children: [
        SizedBox(
          width: 250,
          child: ListView.builder(
            itemCount: _membros.length,
            itemBuilder: (context, index) {
              final membro = _membros[index];
              final isSelected =
                  _selectedMembro?['membro_id'] == membro['membro_id'];
              return ListTile(
                title: Text(
                  membro['nome'].toString(),
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(membro['email'].toString()),
                leading: CircleAvatar(child: Text(membro['nome'][0])),
                selected: isSelected,
                onTap: () {
                  setState(() => _selectedMembro = membro);
                  _loadStatus(membro['membro_id'].toString());
                },
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _selectedMembro == null
                ? const Center(
                    child: Text('Selecione um membro para ver o status.'),
                  )
                : _buildStatusDetails(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDetails() {
    if (_isLoading || _statusEmprestimo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _statusEmprestimo!;
    final totalEmprestimos = status['total_emprestimos'] as int;
    final atrasadosCount = status['atrasados_count'] as int;
    final proximaDevolucao = status['proxima_devolucao'];

    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    final String dataFormatada = proximaDevolucao != null
        ? formatter.format(DateTime.parse(proximaDevolucao))
        : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status de Empréstimos: ${_selectedMembro!['nome']}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const Divider(),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusCard(
              title: 'Livros Emprestados',
              value: totalEmprestimos.toString(),
              icon: Icons.menu_book,
              color: Colors.blue,
            ),
            _buildStatusCard(
              title: 'Devoluções Pendentes/Atrasadas',
              value: atrasadosCount.toString(),
              icon: Icons.warning,
              color: atrasadosCount > 0 ? Colors.red : Colors.green,
            ),
            _buildStatusCard(
              title: 'Próximo Prazo de Entrega',
              value: dataFormatada.split(' ')[0],
              icon: Icons.calendar_today,
              color: Colors.purple,
              subtitle: dataFormatada.split(' ').length > 1
                  ? dataFormatada.split(' ')[1]
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 30),

        Text(
          'Detalhes dos Livros Ativos (${totalEmprestimos})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Divider(),

        Expanded(
          child: _emprestimosAtivos.isEmpty
              ? const Center(child: Text('Nenhum livro ativo com este membro.'))
              : ListView.builder(
                  itemCount: _emprestimosAtivos.length,
                  itemBuilder: (context, index) {
                    final emp = _emprestimosAtivos[index];
                    final livroTitulo =
                        emp['livros']?['titulo'] ?? 'Título Desconhecido';
                    final prazo = DateTime.parse(
                      emp['data_prevista_devolucao'],
                    );
                    final isAtrasado = prazo.isBefore(DateTime.now());

                    return Card(
                      color: isAtrasado ? Colors.red.shade50 : Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: isAtrasado
                            ? const Icon(Icons.gavel, color: Colors.red)
                            : const Icon(
                                Icons.check_circle_outline,
                                color: Colors.teal,
                              ),
                        title: Text(
                          livroTitulo,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          isAtrasado
                              ? 'ATRASADO! Prazo: ${formatter.format(prazo)}'
                              : 'Prazo de Entrega: ${formatter.format(prazo)}',
                          style: TextStyle(
                            color: isAtrasado
                                ? Colors.red.shade800
                                : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
        ),
      ),
    );
  }
}
