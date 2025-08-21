import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/email_service.dart';

class MultiEmailField extends StatefulWidget {
  final List<String> initialEmails;
  final Function(List<String>) onEmailsChanged;
  final String? Function(List<String>)? validator;
  final String labelText;
  final String hintText;
  final bool enabled;
  final int maxEmails;

  const MultiEmailField({
    Key? key,
    this.initialEmails = const [],
    required this.onEmailsChanged,
    this.validator,
    this.labelText = 'Destinatarios',
    this.hintText = 'Ingresa el usuario (ej: hernan.iturralde)',
    this.enabled = true,
    this.maxEmails = 10,
  }) : super(key: key);

  @override
  _MultiEmailFieldState createState() => _MultiEmailFieldState();
}

class _MultiEmailFieldState extends State<MultiEmailField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  List<String> _emails = [];
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emails = List.from(widget.initialEmails);
    
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    
    if (text.isEmpty) {
      _hideSuggestions();
      return;
    }

    // Generar sugerencias
    List<String> newSuggestions = [];
    
    // Autocompletado del dominio
    List<String> domainSuggestions = EmailService.obtenerSugerenciasAutocompletado(text);
    newSuggestions.addAll(domainSuggestions);
    
    // Usuarios comunes
    List<String> commonUsers = EmailService.filtrarUsuariosComunes(text);
    newSuggestions.addAll(commonUsers);
    
    // Remover duplicados y emails ya agregados
    newSuggestions = newSuggestions.toSet().toList();
    newSuggestions.removeWhere((email) => _emails.contains(email));
    
    setState(() {
      _suggestions = newSuggestions.take(5).toList(); // Máximo 5 sugerencias
    });
    
    if (_suggestions.isNotEmpty) {
      _showSuggestions;
    } else {
      _hideSuggestions();
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestions();
      _processCurrentInput();
    }
  }

  void _processCurrentInput() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _addEmail(text);
    }
  }

  void _addEmail(String email) {
    if (_emails.length >= widget.maxEmails) {
      _setError('Máximo ${widget.maxEmails} destinatarios permitidos');
      return;
    }

    String processedEmail = EmailService.procesarEmail(email);
    
    if (processedEmail.isEmpty) {
      _setError('Email inválido');
      return;
    }

    if (_emails.contains(processedEmail)) {
      _setError('Email ya agregado');
      return;
    }

    if (!EmailService.validarEmail(processedEmail)) {
      _setError('Formato de email inválido');
      return;
    }

    setState(() {
      _emails.add(processedEmail);
      _controller.clear();
      _errorText = null;
    });
    
    _hideSuggestions();
    widget.onEmailsChanged(_emails);
    _validate();
  }

  void _removeEmail(int index) {
    setState(() {
      _emails.removeAt(index);
      _errorText = null;
    });
    widget.onEmailsChanged(_emails);
    _validate();
  }

  void _setError(String error) {
    setState(() {
      _errorText = error;
    });
    
    // Limpiar error después de 3 segundos
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorText = null;
        });
      }
    });
  }

  void _validate() {
    if (widget.validator != null) {
      String? validationError = widget.validator!(_emails);
      setState(() {
        _errorText = validationError;
      });
    }
  }


  void _hideSuggestions() {
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta del campo
        if (widget.labelText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              widget.labelText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),

        // Chips de emails agregados
        if (_emails.isNotEmpty)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emails.asMap().entries.map((entry) {
                int index = entry.key;
                String email = entry.value;
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[300]!),
                  ),
                  child: IntrinsicWidth(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: 12, top: 6, bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.email, size: 14, color: Colors.blue[700]),
                              SizedBox(width: 6),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: widget.enabled ? () => _removeEmail(index) : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: widget.enabled ? Colors.blue[700] : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Campo de entrada
        CompositedTransformTarget(
          link: _layerLink,
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            decoration: InputDecoration(
              hintText: _emails.length >= widget.maxEmails 
                  ? 'Máximo ${widget.maxEmails} destinatarios'
                  : widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(Icons.person_add),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => _addEmail(_controller.text),
                    )
                  : null,
              errorText: _errorText,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onFieldSubmitted: (value) => _addEmail(value),
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')), // No espacios
            ],
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.emailAddress,
          ),
        ),

        // Información adicional
        if (_emails.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  '${_emails.length} de ${widget.maxEmails} destinatarios agregados',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

        // Ayuda para el usuario
        if (_emails.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 14, color: Colors.orange[600]),
                    SizedBox(width: 6),
                    Text(
                      'Consejos:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '• Solo escribe el usuario: "hernan.iturralde"',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  '• Se autocompletará con @tessacorporation.com',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  '• Presiona Enter para agregar cada destinatario',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}