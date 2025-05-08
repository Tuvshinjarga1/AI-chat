import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aichat/services/chat_service.dart';

class AdminQAEntryPage extends StatefulWidget {
  const AdminQAEntryPage({Key? key}) : super(key: key);

  @override
  State<AdminQAEntryPage> createState() => _AdminQAEntryPageState();
}

class _AdminQAEntryPageState extends State<AdminQAEntryPage> {
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _editingDocId;
  bool _isSaving = false;

  Future<void> _addQA() async {
    final question = _questionController.text.trim();
    final answer = _answerController.text.trim();
    final tags = _tagsController.text
        .trim()
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    if (question.isEmpty || answer.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_editingDocId != null) {
        // Хэрэв засвар хийж байгаа бол
        await FirebaseFirestore.instance
            .collection('questions')
            .doc(_editingDocId)
            .update({
          'question': question,
          'answer': answer,
          'tags': tags,
          'updatedAt': Timestamp.now(),
        });

        // Давхар локал хадгалалт хийх
        await ChatService.saveQuestionAnswerLocally(
          question: question,
          answer: answer,
          tags: tags,
        );

        _editingDocId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Асуулт амжилттай засварлагдлаа')),
        );
      } else {
        // Шинээр нэмж байгаа бол
        // Firebase-д хадгалах
        await FirebaseFirestore.instance.collection('questions').add({
          'question': question,
          'answer': answer,
          'tags': tags,
          'createdAt': Timestamp.now(),
          'createdBy': 'admin',
        });

        // Давхар локал хадгалалт хийх
        await ChatService.saveQuestionAnswerLocally(
          question: question,
          answer: answer,
          tags: tags,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Асуулт амжилттай нэмэгдлээ')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа гарлаа: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
      _resetForm();
    }
  }

  void _resetForm() {
    _questionController.clear();
    _answerController.clear();
    _tagsController.clear();
    _editingDocId = null;
    setState(() {});
  }

  Future<void> _deleteQA(String id) async {
    try {
      // Firebase-ээс устгах
      await FirebaseFirestore.instance.collection('questions').doc(id).delete();

      // Локал хадгалалтаас устгах шаардлагатай бол энд код нэмнэ

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Асуулт устгагдлаа')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Устгахад алдаа гарлаа: $e')),
      );
    }
  }

  void _editQA(String id, Map<String, dynamic> data) {
    _questionController.text = data['question'] ?? '';
    _answerController.text = data['answer'] ?? '';

    if (data['tags'] != null) {
      _tagsController.text = (data['tags'] as List).join(', ');
    } else {
      _tagsController.clear();
    }

    _editingDocId = id;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(labelText: 'Асуулт'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(labelText: 'Хариулт'),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Тагууд (таслалаар тусгаарлан бичнэ үү)',
                hintText: 'жишээ: эрүүл мэнд, дархлаа',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : _addQA,
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Text(_editingDocId == null ? 'Нэмэх' : 'Хадгалах'),
                ),
                if (_editingDocId != null)
                  TextButton(
                    onPressed: _isSaving ? null : _resetForm,
                    child: const Text('Цуцлах'),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('questions')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (ChatService.isOffline) {
                    return const Center(
                      child: Text(
                        'Оффлайн горимд Firebase өгөгдөл харах боломжгүй',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('Асуулт хариулт хоосон байна'));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final tags = data['tags'] != null
                          ? (data['tags'] as List).join(', ')
                          : '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(data['question']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['answer']),
                              if (tags.isNotEmpty)
                                Text(
                                  'Тагууд: $tags',
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editQA(docs[index].id, data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteQA(docs[index].id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
