import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/core/tools/validating_text_editing_controller.dart';
import 'package:prbd_2425_a08/models/tricount.dart';
import 'package:prbd_2425_a08/models/user.dart';
import 'package:prbd_2425_a08/providers/all_users_provider.dart';
import 'package:prbd_2425_a08/providers/tricount_list_provider.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';

import '../widgets/data_error_widget.dart';

class AddTricountPage extends ConsumerStatefulWidget {
  const AddTricountPage({super.key});

  @override
  ConsumerState<AddTricountPage> createState() => _AddTricountPageState();
}

class _AddTricountPageState extends ConsumerState<AddTricountPage> {
  late final ValidatingTextEditingController _titleController;
  late final ValidatingTextEditingController _descriptionController;
  final FocusNode _titleFocusNode = FocusNode();

  late final User? userConnected;
  final participants = SplayTreeSet<User>();
  final nonParticipants = SplayTreeSet<User>();
  User? selectedToAdd; // dropdown selection

  @override // initState est une méthode de StatefulWidget qui est appelée une seule fois lors de la création du widget
  void initState() {
    super.initState();

    userConnected = ref.read(securityProvider).value;

    _titleController = ValidatingTextEditingController(
      validator: TricountValidator.validateTitle,
      asyncValidator: (s) => TricountValidator.validateTricountUnicity(
        title: s,
        tricountId: 0, // car création d'un nouveau tricount
      ),
      onAfterValidated: () => setState(() {}), // setState() sert à reconstruire le build
    );

    _descriptionController = ValidatingTextEditingController(
      validator: TricountValidator.validateDescription,
      onAfterValidated: () => setState(() {}),
    );

    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus && _titleController.text.trim().isEmpty) {
        _titleController.validate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allUsersAsyncState = ref.watch(allUsersProvider);

    return Scaffold(
      /* -------------------- APP BAR ------------------------- */
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Tricount',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color: _isButtonSaveActivated ? Colors.white : Colors.blueGrey,
            ),
            onPressed: _isButtonSaveActivated ? () {
              _submitForm(context);
            } : null, // à compléter
          ),
          const SizedBox(width: 4), // espace à droite du bouton save
        ],
      ),

      /* ---------------------- BODY ------------------------- */
      body: allUsersAsyncState.when(
        data: (allUsers) => data(context, allUsers, isLoading: false),
        loading: () => data(context, allUsersAsyncState.value ?? SplayTreeSet(), isLoading: true),
        error: (err, st) => DataErrorWidget(error: err, stackTrace: st, provider: allUsersProvider),
      ),
    );
  }

  Widget data(
      BuildContext context,
      SplayTreeSet<User> allUsers,
      { bool isLoading = false, }
  ) {

    // Initialisation des _participants (se produit une seule fois)
    if (participants.isEmpty) {
      participants.add(userConnected!); // créateur
    }

    // Calcul (ou recalcul) des utilisateurs restants
    nonParticipants
      ..clear()
      ..addAll(allUsers)
      ..removeAll(participants);


    // ──────────────── BODY ──────────────────
    return Stack(
      children: [
        SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 60, 0, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: min(MediaQuery.of(context).size.width * 0.9, 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // -------- title ---------
                        TextFormField(
                          autofocus: true,
                          autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: const OutlineInputBorder(),
                            errorText: _titleController.errorText,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // -------- description ---------
                        TextFormField(
                          autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            border: const OutlineInputBorder(),
                            errorText: _descriptionController.errorText,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ───────────────── Participants ─────────────────
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Participants', style: TextStyle(fontSize: 22)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // —— liste actuelle ——————————————————————————
                        for (final participant in participants)
                          _participantTile(participant),

                        const SizedBox(height: 16),

                        /* ---- DROPDOWN ADD USER ---- */
                        if (nonParticipants.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<User>(
                                  value: selectedToAdd,
                                  hint: const Text('Add a participant'),
                                  items: nonParticipants.map((user) =>
                                      DropdownMenuItem<User>(value: user, child: Text(user.fullName),)).toList(),
                                  onChanged: (user) => setState(() => selectedToAdd = user),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.person_add),
                                onPressed: selectedToAdd == null ? null : () {
                                  _addParticipant(selectedToAdd!);
                                  setState(() => selectedToAdd = null);
                                },
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
        if (isLoading)
          const Center(
              child: CircularProgressIndicator(color: Colors.black)),
      ],
    );
  }

  Widget _participantTile(User participant) {
    // Créateur du tricount ?
    final bool isCreator = participant == userConnected; // création

    // Peut-on le supprimer ?
    //  pas le créateur
    final bool isDeletable = !isCreator;

    // ListTile
    return ListTile(
      leading: isCreator
          ? const Icon(Icons.account_circle)
          : const Icon(Icons.account_circle_outlined),

      title: isCreator
          ? Text(participant.fullName, style: TextStyle(fontWeight: FontWeight.bold))
          : Text(participant.fullName),

      trailing: isDeletable
          ? IconButton(
              icon: const Icon(Icons.person_remove),
              onPressed: () => _removeParticipant(participant) )
          : IconButton(
              icon: const Icon(Icons.person_remove),
              onPressed: null ),
    );
  }

  void _addParticipant(User user) {
    setState(() {
      participants.add(user);
      nonParticipants.remove(user);
    });
  }

  void _removeParticipant(User user) {
    setState(() {
      participants.remove(user);
      nonParticipants.add(user);
    });
  }


  // ──────── Gestion validation des champs ─────────────────
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(BuildContext context) async {
    if (!await _validateForm()) return;
    final notifier = ref.read(tricountListProvider.notifier);
    final int id = 0;

    Tricount? tric = await notifier.saveTricount(
      id,
      _titleController.text,
      _descriptionController.text,
      participants
    );

          // pour débugger
          // if (tric == null) {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     const SnackBar(content: Text('Error saving tricount')),
          //   );
          //   return;
          // }
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/view_tricount');
    }
  }

  Future<bool> _validateForm() async {
    await _titleController.validateAndWait();
    await _descriptionController.validateAndWait();
    return _isFormValid;
  }

  bool get _isFormValid =>
      _titleController.isValid == true &&
          _descriptionController.isValid == true;

  bool get _isButtonSaveActivated =>
      _isFormValid && _titleController.text.trim().isNotEmpty;

}











