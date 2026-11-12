import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const DartCodeEditorApp());
}

class DartCodeEditorApp extends StatelessWidget {
  const DartCodeEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dart Code Editor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101820),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: const EditorPage(),
    );
  }
}

class HighlightController extends TextEditingController {
  String searchWord = '';
  int currentMatch = 0;

  List<int> get matches {
    if (searchWord.isEmpty) return [];

    final result = <int>[];
    final source = text.toLowerCase();
    final query = searchWord.toLowerCase();

    int start = 0;

    while (start < source.length) {
      final index = source.indexOf(query, start);

      if (index == -1) break;

      result.add(index);
      start = index + query.length;
    }

    return result;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final found = matches;

    if (found.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final children = <TextSpan>[];
    int position = 0;

    for (int i = 0; i < found.length; i++) {
      final index = found[i];

      if (index > position) {
        children.add(
          TextSpan(
            text: text.substring(position, index),
            style: baseStyle,
          ),
        );
      }

      final isCurrent = i == currentMatch;

      children.add(
        TextSpan(
          text: text.substring(index, index + searchWord.length),
          style: baseStyle.copyWith(
            backgroundColor: isCurrent ? Colors.deepOrange : Colors.yellow,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      position = index + searchWord.length;
    }

    if (position < text.length) {
      children.add(
        TextSpan(
          text: text.substring(position),
          style: baseStyle,
        ),
      );
    }

    return TextSpan(children: children, style: baseStyle);
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final HighlightController editorController = HighlightController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController replaceController = TextEditingController();
  final ScrollController editorScrollController = ScrollController();

  String fileName = 'untitled.dart';
  double fontSize = 16;
  int currentMatch = 0;

  List<int> get foundWords => editorController.matches;

  @override
  void initState() {
    super.initState();

    editorController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    editorController.dispose();
    searchController.dispose();
    replaceController.dispose();
    editorScrollController.dispose();
    super.dispose();
  }

  void searchWord(String value) {
    setState(() {
      editorController.searchWord = value;
      currentMatch = 0;
      editorController.currentMatch = 0;
    });
  }

  void moveToMatch(int index) {
    final matches = foundWords;

    if (matches.isEmpty) return;

    currentMatch = index.clamp(0, matches.length - 1);

    editorController.currentMatch = currentMatch;

    final position = matches[currentMatch];

    final beforeText = editorController.text.substring(0, position);
    final lineNumber = '\n'.allMatches(beforeText).length;

    final estimatedLineHeight = fontSize * 1.6;
    final targetOffset = lineNumber * estimatedLineHeight;

    setState(() {});

    if (editorScrollController.hasClients) {
      final maxScroll = editorScrollController.position.maxScrollExtent;

      editorScrollController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void nextMatch() {
    if (foundWords.isEmpty) return;

    moveToMatch((currentMatch + 1) % foundWords.length);
  }

  void previousMatch() {
    if (foundWords.isEmpty) return;

    moveToMatch(
      (currentMatch - 1 + foundWords.length) % foundWords.length,
    );
  }

  Future<void> openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dart', 'txt', 'json'],
        withData: true,
      );

      if (result == null) return;

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null) return;

      editorController.text = utf8.decode(bytes);
      fileName = file.name;

      setState(() {
        currentMatch = 0;
        editorController.currentMatch = 0;
      });
    } catch (e) {
      showMessage('File open error: $e');
    }
  }

  Future<void> saveFile() async {
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(editorController.text),
      );

      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Dart File',
        fileName: fileName,
        bytes: bytes,
      );

      showMessage('Save process completed');
    } catch (e) {
      showMessage('Save error: $e');
    }
  }

  void replaceOne() {
    final matches = foundWords;

    if (matches.isEmpty) {
      showMessage('Word not found');
      return;
    }

    final index = matches[currentMatch];
    final wordLength = editorController.searchWord.length;

    final newText = editorController.text.replaceRange(
      index,
      index + wordLength,
      replaceController.text,
    );

    editorController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: index + replaceController.text.length,
      ),
    );

    showMessage('Word replaced');
  }

  void replaceAll() {
    if (editorController.searchWord.isEmpty) return;

    final count = foundWords.length;

    if (count == 0) {
      showMessage('Word not found');
      return;
    }

    final newText = editorController.text.replaceAll(
      RegExp(
        RegExp.escape(editorController.searchWord),
        caseSensitive: false,
      ),
      replaceController.text,
    );

    editorController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: 0),
    );

    showMessage('$count words replaced');
  }

  void newFile() {
    editorController.clear();
    searchController.clear();
    replaceController.clear();

    setState(() {
      fileName = 'untitled.dart';
      currentMatch = 0;
      editorController.searchWord = '';
      editorController.currentMatch = 0;
    });
  }

  Future<void> copyAll() async {
    await Clipboard.setData(
      ClipboardData(text: editorController.text),
    );
    showMessage('All code copied');
  }

  Future<void> copySelected() async {
    final selection = editorController.selection;

    if (selection.isCollapsed) {
      showMessage('First select some code');
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: selection.textInside(editorController.text),
      ),
    );

    showMessage('Selected code copied');
  }

  void selectAll() {
    editorController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: editorController.text.length,
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget actionButton(
    String title,
    IconData icon,
    VoidCallback action,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 17),
        label: Text(title),
      ),
    );
  }

  Widget searchPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: const Color(0xFF1C2935),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: searchWord,
                  decoration: const InputDecoration(
                    hintText: 'Search word...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    '${foundWords.length} words found',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    foundWords.isEmpty
                        ? '0 / 0'
                        : '${currentMatch + 1} / ${foundWords.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: previousMatch,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: nextMatch,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: replaceController,
                  decoration: const InputDecoration(
                    hintText: 'Replace with...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Replace',
                onPressed: replaceOne,
                icon: const Icon(Icons.find_replace),
              ),
              IconButton(
                tooltip: 'Replace All',
                onPressed: replaceAll,
                icon: const Icon(Icons.done_all),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget markerBar(double height) {
    final matches = foundWords;
    final textLength = editorController.text.length;

    return Container(
      width: 22,
      height: height,
      color: const Color(0xFF263442),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (matches.isEmpty || textLength == 0) {
            return const SizedBox.shrink();
          }

          return Stack(
            children: [
              for (int i = 0; i < matches.length; i++)
                Positioned(
                  top: (matches[i] / textLength) * (constraints.maxHeight - 5),
                  left: 3,
                  child: GestureDetector(
                    onTap: () => moveToMatch(i),
                    child: Container(
                      width: 16,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == currentMatch
                            ? Colors.deepOrange
                            : Colors.yellow,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dart Code Editor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF17232E),
        actions: [
          IconButton(
            tooltip: 'New File',
            onPressed: newFile,
            icon: const Icon(Icons.note_add),
          ),
          IconButton(
            tooltip: 'Open File',
            onPressed: openFile,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: 'Save File',
            onPressed: saveFile,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Column(
        children: [
          searchPanel(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            color: const Color(0xFF17232E),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy Selected',
                  onPressed: copySelected,
                  icon: const Icon(Icons.copy, size: 19),
                ),
                IconButton(
                  tooltip: 'Copy All',
                  onPressed: copyAll,
                  icon: const Icon(Icons.copy_all, size: 19),
                ),
                IconButton(
                  tooltip: 'Select All',
                  onPressed: selectAll,
                  icon: const Icon(Icons.select_all, size: 19),
                ),
                IconButton(
                  tooltip: 'Decrease Font',
                  onPressed: () {
                    setState(() {
                      if (fontSize > 10) fontSize--;
                    });
                  },
                  icon: const Icon(Icons.remove, size: 19),
                ),
                Text('${fontSize.toInt()}'),
                IconButton(
                  tooltip: 'Increase Font',
                  onPressed: () {
                    setState(() {
                      if (fontSize < 30) fontSize++;
                    });
                  },
                  icon: const Icon(Icons.add, size: 19),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    color: const Color(0xFF101820),
                    padding: const EdgeInsets.only(
                      left: 10,
                      top: 10,
                      bottom: 10,
                    ),
                    child: TextField(
                      controller: editorController,
                      scrollController: editorScrollController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                        height: 1.6,
                        color: const Color(0xFFE5EDF5),
                      ),
                      cursorColor: Colors.cyanAccent,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write your Dart code here...',
                      ),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return markerBar(constraints.maxHeight);
                  },
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF17232E),
            child: Text(
              'Ready  |  ${editorController.text.length} characters'
              '  |  ${foundWords.length} matches',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
