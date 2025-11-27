import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:prbd_2425_a08/core/tools/validating_text_editing_controller.dart';
import 'package:prbd_2425_a08/models/user.dart';
import 'package:prbd_2425_a08/models/repartition.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';
import 'package:prbd_2425_a08/providers/current_tricount_provider.dart';
import '../../models/operation.dart';
import '../../models/tricount.dart';

class _RepartitionLine {
  final User user;
  bool selected;
  int weight;

  _RepartitionLine({
    required this.user,
    this.selected = true,
    this.weight = 1,
  });
}

class AddOperationPage extends ConsumerStatefulWidget {
  const AddOperationPage({super.key});
  
  @override
  ConsumerState<AddOperationPage> createState() => _AddOperationPageState();
}

class _AddOperationPageState extends ConsumerState<AddOperationPage> {
  late final ValidatingTextEditingController _titleController;
  late final ValidatingTextEditingController _amountController;
  late final ValidatingTextEditingController _dateController;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  late final User? userConnected;
  late final Tricount tricount;
  DateTime _selectedDate = DateTime.now();
  User? _selectedInitiator;
  late final List<_RepartitionLine> repartitions;


  @override
  void initState() {
    super.initState();

    userConnected = ref.read(securityProvider).value;
    tricount = ref.read(currentTricountProvider).tricount!;

    _titleController = ValidatingTextEditingController(
      validator: OperationValidator.validateTitle,
      onAfterValidated: () => setState(() {}),
    );
    _amountController = ValidatingTextEditingController(
      validator: OperationValidator.validateAmount,
      onAfterValidated: () => setState(() {}),
    );

    _dateController = ValidatingTextEditingController(
      initialValue: DateFormat('dd/MM/yyyy').format(_selectedDate),
      validator: _validateDate,
      onAfterValidated: () => setState(() {}),
    );
     
    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus && _titleController.text.trim().isEmpty) {
        _titleController.validate();
      }
    });

    // cette ligne signifie : "Quand tout est à l’écran, lance cette action"
    WidgetsBinding.instance.addPostFrameCallback((_) => _amountController.validate());

    _selectedInitiator = tricount.participants.firstWhere(
      (p) => p.id == userConnected!.id,
      orElse: () => tricount.participants.first,
    );

    repartitions = tricount.participants.map((u) => _RepartitionLine(user: u)).toList();
  }
  
  DateTime? _tryParseDate(String text) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(text);
    } catch (_) {
      return null;
    }
  }
  
  String? _validateDate(String text) {
    final date = _tryParseDate(text);
    if (date == null) return 'dd/MM/yyyy';
    if (date.isBefore(tricount.createdAt)) return 'may not be before the tricount creation date';
    if (date.isAfter(DateTime.now())) return 'may not be in the future';
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    final sortedParticipants = [...tricount.participants]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final amount       = double.tryParse(_amountController.text) ?? 0;
    final totalWeight  = repartitions
        .where((r) => r.selected && r.weight > 0)
        .fold<int>(0, (sum, r) => sum + r.weight);

    final showEuro     = _amountFocusNode.hasFocus;

    return Scaffold(
      /* -------------------- APP BAR ------------------------- */
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Operation', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.save,
                color: _isButtonSaveActivated ? Colors.white : Colors.blueGrey),
            onPressed: _isButtonSaveActivated ? () => _submitForm(context)
                : null,
          ),
          const SizedBox(width: 4),
        ],
      ),

      /* ---------------------- BODY ------------------------- */
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9 > 500
                      ? 500 : MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    children: [
                      // -------- title ---------
                      TextFormField(
                        autofocus: true,
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: "Title (*)",
                          border: const OutlineInputBorder(),
                          errorText: _titleController.errorText,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // -------- amount ---------
                      TextFormField(
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: "Amount (*)",
                          prefixIcon: showEuro
                            ? Padding(
                                padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                                child: Text(
                                    "€",
                                    style: TextStyle(fontSize: 16, color: Colors.black)
                                ),
                            )
                          : null,
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          border: const OutlineInputBorder(),
                          errorText: _amountController.errorText,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // -------- operation date ----------
                      TextFormField(
                        controller: _dateController,
                        keyboardType: TextInputType.datetime,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: "Operation Date (*)",
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: OperationValidator.tryParseDate(_dateController.text) ?? _selectedDate,
                                firstDate: tricount.createdAt,
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                  _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
                                  _dateController.validate();
                                });
                              }
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // -------- drop down button paid by ----------
                      DropdownButtonFormField<User>(
                        value: _selectedInitiator,
                        decoration: const InputDecoration(
                          labelText: 'Paid by (*)',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: sortedParticipants
                            .map((user) =>
                            DropdownMenuItem<User>(
                              value: user,
                              child: Text(user.fullName),
                            ))
                            .toList(),
                        onChanged: (user) =>
                            setState(() => _selectedInitiator = user),
                      ),
                      const SizedBox(height: 24),

                      // -------- FROM WHOM ? ----------
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("From whom?", style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(height: 8),

                      // -------- At least one participants must be selected. ----------
                      if (!_hasValidRepartition &&
                          _titleController.isValid == true &&
                          _amountController.isValid == true)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              "At least one participants must be selected.",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),

                      // -------- liste des repartitions ------------------------------------------
                      Column(
                        children: [
                          for (final repartition in repartitions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  /* checkbox */
                                  Checkbox(
                                    value: repartition.selected,
                                    onChanged: (v) {
                                      setState(() {
                                        repartition.selected = v!;
                                        repartition.weight = v ? 1 : 0;
                                      });
                                    },
                                  ),
                                  /* nom */
                                  Expanded(child: Text(repartition.user.fullName)),
                                  /* weight + montant */
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${repartition.weight}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        '${(amount * repartition.weight / (totalWeight > 0 ? totalWeight : 1)).toStringAsFixed(2)} €',
                                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          padding: EdgeInsets.zero,
                                          splashRadius: 20,
                                          color: Colors.black,
                                          onPressed: repartition.weight > 0
                                              ? () {
                                            setState(() {
                                              repartition.weight--;
                                              if (repartition.weight == 0) repartition.selected = false;
                                            });
                                          }
                                              : null,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          padding: EdgeInsets.zero,
                                          splashRadius: 20,
                                          color: Colors.black,
                                          onPressed: () {
                                            setState(() {
                                              if (!repartition.selected) repartition.selected = true;
                                              repartition.weight++;
                                            });
                                          }
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(BuildContext context) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final title = _titleController.text.trim();
    final operationDate = OperationValidator.tryParseDate(_dateController.text) ?? _selectedDate;

    final repSet = SplayTreeSet<Repartition>.from(
      repartitions
          .where((r) => r.selected && r.weight > 0)
          .map((r) => Repartition(user: r.user, weight: r.weight)),
    );

    await ref.read(currentTricountProvider.notifier).addOperation(
      0,        // id = 0 car nouvelle dépense
      title,
      amount,
      operationDate,
      _selectedInitiator!,
      repSet,
    );

    if (context.mounted) {
      Navigator.pop(context);
    }
  }


  bool get _hasValidRepartition =>
      repartitions.any((r) => r.selected && r.weight > 0);

  bool get _isFormValid =>
      _titleController.isValid == true &&
      _amountController.isValid == true &&
      _dateController.isValid == true &&
      _selectedInitiator != null &&
      _hasValidRepartition;
  
  bool get _isButtonSaveActivated =>
      _isFormValid &&
      _titleController.text.trim().isNotEmpty &&
      _amountController.text.trim().isNotEmpty;

}
