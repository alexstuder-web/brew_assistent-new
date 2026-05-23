import 'package:flutter/material.dart';
import '../models/how_to_topic.dart';
import '../services/how_to_service.dart';
import '../services/user_profile_service.dart';
import 'how_to/how_to_sidebar.dart';
import 'how_to/how_to_tab_bar.dart';
import 'how_to/how_to_editor.dart';
import 'how_to/resizer_handle.dart';

class HowToPage extends StatefulWidget {
  const HowToPage({super.key});

  @override
  State<HowToPage> createState() => _HowToPageState();
}

class _HowToPageState extends State<HowToPage> {
  final HowToService _howToService = HowToService();
  List<HowToTopic> _topics = [];
  int _selectedIndex = 0;
  int _selectedPageIndex = 0;
  bool _isLoading = true;
  
  final _topicTitleController = TextEditingController();
  final _pageTitleController = TextEditingController();
  final _pageContentController = TextEditingController();
  
  double _sidebarWidth = 250.0;
  String get _profileId => UserProfileService.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();

    _topicTitleController.addListener(_onTopicTitleChanged);
    _pageTitleController.addListener(_onPageTitleChanged);
    _pageContentController.addListener(_onPageContentChanged);
  }

  @override
  void dispose() {
    _topicTitleController.dispose();
    _pageTitleController.dispose();
    _pageContentController.dispose();
    super.dispose();
  }

  void _onTopicTitleChanged() {
    if (_selectedIndex >= 0 && _selectedIndex < _topics.length) {
      final val = _topicTitleController.text;
      if (_topics[_selectedIndex].title != val) {
        setState(() {
          _topics[_selectedIndex] = _topics[_selectedIndex].copyWith(title: val);
        });
      }
    }
  }

  void _onPageTitleChanged() {
    if (_selectedIndex >= 0 && _selectedIndex < _topics.length) {
      final topic = _topics[_selectedIndex];
      if (_selectedPageIndex >= 0 && _selectedPageIndex < topic.pages.length) {
        final val = _pageTitleController.text;
        if (topic.pages[_selectedPageIndex].title != val) {
          setState(() {
            final newPages = List<HowToPageData>.from(topic.pages);
            newPages[_selectedPageIndex] = newPages[_selectedPageIndex].copyWith(title: val);
            _topics[_selectedIndex] = topic.copyWith(pages: newPages);
          });
        }
      }
    }
  }

  void _onPageContentChanged() {
    if (_selectedIndex >= 0 && _selectedIndex < _topics.length) {
      final topic = _topics[_selectedIndex];
      if (_selectedPageIndex >= 0 && _selectedPageIndex < topic.pages.length) {
        final val = _pageContentController.text;
        if (topic.pages[_selectedPageIndex].content != val) {
          setState(() {
            final newPages = List<HowToPageData>.from(topic.pages);
            newPages[_selectedPageIndex] = newPages[_selectedPageIndex].copyWith(content: val);
            _topics[_selectedIndex] = topic.copyWith(pages: newPages);
          });
        }
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final topics = await _howToService.loadTopics(_profileId);
      setState(() {
        _topics = topics;
        if (_topics.isNotEmpty) {
          _updateEditorFields();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _updateEditorFields() {
    if (_selectedIndex >= 0 && _selectedIndex < _topics.length) {
      final topic = _topics[_selectedIndex];
      _topicTitleController.text = topic.title;
      
      if (topic.pages.isNotEmpty) {
        if (_selectedPageIndex >= topic.pages.length) {
          _selectedPageIndex = 0;
        }
        _pageTitleController.text = topic.pages[_selectedPageIndex].title;
        _pageContentController.text = topic.pages[_selectedPageIndex].content;
      } else {
        _pageTitleController.text = '';
        _pageContentController.text = '';
      }
    }
  }

  Future<void> _saveCurrentTopic() async {
    if (_selectedIndex < 0 || _selectedIndex >= _topics.length) return;

    final topic = _topics[_selectedIndex];
    try {
      final saved = await _howToService.saveTopic(topic);
      setState(() {
        _topics[_selectedIndex] = saved;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gespeichert'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  Future<void> _addTopic() async {
    final newTopic = HowToTopic.create(
      userProfileId: _profileId,
      title: 'Neues Thema',
      pages: [HowToPageData.create(title: 'Seite 1')],
      position: _topics.length,
    );

    try {
      final saved = await _howToService.saveTopic(newTopic);
      setState(() {
        _topics.add(saved);
        _selectedIndex = _topics.length - 1;
        _selectedPageIndex = 0;
        _updateEditorFields();
      });
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Hinzufügen: $e')),
        );
      }
    }
  }

  Future<void> _deleteTopicAt(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thema löschen?'),
        content: Text('Möchtest du das Thema "${_topics[index].title}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      await _howToService.deleteTopic(_topics[index].id);
      setState(() {
        _topics.removeAt(index);
        if (_topics.isEmpty) {
          _selectedIndex = 0;
        } else if (_selectedIndex >= _topics.length) {
          _selectedIndex = _topics.length - 1;
        }
        _selectedPageIndex = 0;
        if (_topics.isNotEmpty) {
          _updateEditorFields();
        }
      });
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Löschen: $e')),
        );
      }
    }
  }

  void _onReorderTopics(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _topics.removeAt(oldIndex);
      _topics.insert(newIndex, item);
      
      if (_selectedIndex == oldIndex) {
        _selectedIndex = newIndex;
      } else if (oldIndex < _selectedIndex && newIndex >= _selectedIndex) {
        _selectedIndex--;
      } else if (oldIndex > _selectedIndex && newIndex <= _selectedIndex) {
        _selectedIndex++;
      }
    });
    
    _howToService.updatePositions(_topics);
  }

  void _addPage() {
    if (_selectedIndex < 0 || _selectedIndex >= _topics.length) return;
    final topic = _topics[_selectedIndex];
    final newPage = HowToPageData.create(title: 'Neue Seite');
    setState(() {
      final newPages = List<HowToPageData>.from(topic.pages)..add(newPage);
      _topics[_selectedIndex] = topic.copyWith(pages: newPages);
      _selectedPageIndex = newPages.length - 1;
      _updateEditorFields();
    });
  }

  void _deletePage(int pageIndex) {
    if (_selectedIndex < 0 || _selectedIndex >= _topics.length) return;
    final topic = _topics[_selectedIndex];
    if (topic.pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Das Thema muss mindestens eine Seite haben.')),
      );
      return;
    }

    setState(() {
      final newPages = List<HowToPageData>.from(topic.pages)..removeAt(pageIndex);
      _topics[_selectedIndex] = topic.copyWith(pages: newPages);
      if (_selectedPageIndex >= newPages.length) {
        _selectedPageIndex = newPages.length - 1;
      }
      _updateEditorFields();
    });
  }

  Future<void> _confirmDeletePage(int pageIndex) async {
    if (_selectedIndex < 0 || _selectedIndex >= _topics.length) return;
    final topic = _topics[_selectedIndex];
    if (topic.pages.length <= 1) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Das Thema muss mindestens eine Seite haben.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seite löschen?'),
        content: Text('Möchtest du die Seite "${topic.pages[pageIndex].title}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      _deletePage(pageIndex);
    }
  }

  void _onReorderPages(int oldIndex, int newIndex) {
    if (_selectedIndex < 0 || _selectedIndex >= _topics.length) return;
    final topic = _topics[_selectedIndex];
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final newPages = List<HowToPageData>.from(topic.pages);
      final item = newPages.removeAt(oldIndex);
      newPages.insert(newIndex, item);
      _topics[_selectedIndex] = topic.copyWith(pages: newPages);
      
      if (_selectedPageIndex == oldIndex) {
        _selectedPageIndex = newIndex;
      } else if (oldIndex < _selectedPageIndex && newIndex >= _selectedPageIndex) {
        _selectedPageIndex--;
      } else if (oldIndex > _selectedPageIndex && newIndex <= _selectedPageIndex) {
        _selectedPageIndex++;
      }
    });
  }

  void _showTabContextMenu(BuildContext context, Offset position, int pageIndex) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Seite löschen'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        _confirmDeletePage(pageIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topics.isNotEmpty && _selectedIndex < _topics.length ? _topics[_selectedIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How To\'s'),
        actions: [
          if (_topics.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveCurrentTopic,
              tooltip: 'Speichern',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                HowToSidebar(
                  topics: _topics,
                  selectedIndex: _selectedIndex,
                  width: _sidebarWidth,
                  onTopicSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                      _selectedPageIndex = 0;
                      _updateEditorFields();
                    });
                  },
                  onReorderTopics: _onReorderTopics,
                  onDeleteTopic: _deleteTopicAt,
                  onAddTopic: _addTopic,
                ),
                ResizerHandle(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _sidebarWidth += details.delta.dx;
                      if (_sidebarWidth < 150) _sidebarWidth = 150;
                      if (_sidebarWidth > 600) _sidebarWidth = 600;
                    });
                  },
                ),
                Expanded(
                  child: topic == null
                      ? const Center(child: Text('Erstelle ein neues Thema oder wähle eines aus.'))
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                              child: TextField(
                                controller: _topicTitleController,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                decoration: const InputDecoration(
                                  hintText: 'Themen-Titel (Sidebar)...',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            HowToTabBar(
                              topic: topic,
                              selectedPageIndex: _selectedPageIndex,
                              onPageSelected: (index) {
                                setState(() {
                                  _selectedPageIndex = index;
                                  _updateEditorFields();
                                });
                              },
                              onReorderPages: _onReorderPages,
                              onAddPage: _addPage,
                              onSecondaryTap: _showTabContextMenu,
                            ),
                            HowToEditor(
                              pageTitleController: _pageTitleController,
                              pageContentController: _pageContentController,
                              onDeletePage: () => _confirmDeletePage(_selectedPageIndex),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
