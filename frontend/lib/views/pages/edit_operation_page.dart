import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:prbd_2425_a08/core/tools/validating_text_editing_controller.dart';
import 'package:prbd_2425_a08/models/repartition.dart';
import 'package:prbd_2425_a08/models/operation.dart';
import 'package:prbd_2425_a08/models/tricount.dart';
import 'package:prbd_2425_a08/models/user.dart';
import 'package:prbd_2425_a08/providers/current_tricount_provider.dart';

import '../../core/widgets/dialog_box.dart';

class _RepartitionLine {
  final User user;
  bool selected;
  int weight;

  _RepartitionLine({
    required this.user,
    this.selected = true,
    this.weight = 1
  });
}

class EditOperationPage extends ConsumerStatefulWidget {
  final Operation operation;

  const EditOperationPage({super.key, required this.operation});

  @override
  ConsumerState<EditOperationPage> createState() => _EditOperationPageState();
}

class _EditOperationPageState extends ConsumerState<EditOperationPage> {
  late final ValidatingTextEditingController _titleController;
  late final ValidatingTextEditingController _amountController;
  late final ValidatingTextEditingController _dateController;
  

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  late final Tricount tricount;
  late Operation operation;
  DateTime _selectedDate = DateTime.now();
  late User _selectedInitiator;
  late final List<_RepartitionLine> repartitions;


  @override
  void initState() {
    super.initState();

    tricount   = ref.read(currentTricountProvider).tricount!;
    operation = widget.operation;
    
    _selectedDate = operation.operationDate;
    
    _titleController = ValidatingTextEditingController(
      initialValue: operation.title,
      validator: OperationValidator.validateTitle,
      onAfterValidated: () => setState(() {}),
    );
    _amountController = ValidatingTextEditingController(
      initialValue: operation.amount.toStringAsFixed(2),
      validator: OperationValidator.validateAmount,
      onAfterValidated: () => setState(() {}),
    );
    _dateController = ValidatingTextEditingController(
      initialValue: DateFormat('dd/MM/yyyy').format(_selectedDate),
      validator: (s) => OperationValidator.validateDate(s, tricount.createdAt),
      onAfterValidated: () => setState(() {}),
    );

    _selectedInitiator = operation.initiator;

    repartitions = tricount.participants.map((user) {
      final rep = operation.repartitions.firstWhere(
            (r) => r.user == user,
        orElse: () => Repartition(user: user, weight: 0),
      );
      return _RepartitionLine(
        user: user,
        selected: rep.weight > 0,
        weight:   rep.weight,
      );
    }).toList();
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
        title: const Text('Edit Operation', style: TextStyle(color: Colors.white)),
        actions: [
          /* --------- SAVE BUTTON --------- */
          IconButton(
            icon: Icon(Icons.save,
                color: _isButtonSaveActivated ? Colors.white : Colors.blueGrey),
            onPressed: _isButtonSaveActivated ? () => _submitForm(context) : null,
          ),
          /* --------- DELETE BUTTON --------- */
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              final action = await DialogBox(
                title: 'Confirmation',
                message: 'Are you sure you want to delete this operation ?',
                actions: const ['Yes', 'No'],
              ).show(context);

              if (action == 'Yes') {
                await ref.read(currentTricountProvider.notifier).deleteOperation(widget.operation);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
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
                        focusNode:  _titleFocusNode,
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
                        focusNode:  _amountFocusNode,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: "Amount (*)",
                          prefixIcon: showEuro
                              ?  Padding(
                            padding: EdgeInsets.only(left: 12.0, right: 8.0),
                            child: Text(
                                "€",
                                style: TextStyle(fontSize: 16, color: Colors.black)),
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
                          errorText: _dateController.errorText,
                        ),
                        onChanged: (text) {
                          final date = OperationValidator.tryParseDate(text);
                          if (date != null) _selectedDate = date;
                          _dateController.validate();
                        },
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
                        items: sortedParticipants.map(
                              (user) =>
                            DropdownMenuItem<User>(
                              value: user,
                              child: Text(user.fullName),
                            )
                        ).toList(),
                        onChanged: (user) => setState(() => _selectedInitiator = user!),
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
                                        repartition.weight   = v ? 1 : 0;
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
                                          },
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
        ),
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
    final title  = _titleController.text.trim();
    final operationDate = OperationValidator.tryParseDate(_dateController.text) ?? _selectedDate;

    final repSet = SplayTreeSet<Repartition>.from(
      repartitions
          .where((r) => r.selected && r.weight > 0)
          .map((r) => Repartition(user: r.user, weight: r.weight),
      ),
    );

    await ref.read(currentTricountProvider.notifier).addOperation(
      operation.id, // id car mise à jour
      title,
      amount,
      operationDate,
      _selectedInitiator,
      repSet,
    );

    if (context.mounted) {
      Navigator.pop(context);
    }
  }


  bool get _hasValidRepartition =>
      repartitions.any((r) => r.selected && r.weight > 0);

  bool get _isFormValid =>
      _titleController.isValid  == true && 
      _amountController.isValid == true &&
      _dateController.isValid   == true &&    
      _hasValidRepartition;

  bool get _isButtonSaveActivated =>
          _isFormValid &&
          _titleController.text.trim().isNotEmpty &&
          _amountController.text.trim().isNotEmpty;

}