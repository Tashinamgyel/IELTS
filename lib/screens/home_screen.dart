// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';
import '../language_setting.dart';
import '../services/chatgpt_service.dart';
import '../services/firebase_service.dart';
import '../models/essay.dart';
import '../widgets/topic_card.dart';
import 'essay_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const HomeScreen({super.key, required this.onThemeChanged, required this.isDarkMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ChatGPTService _chatGPTService = ChatGPTService();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  // Predefined IELTS topics.
  final List<String> topics = [
    'The advantages and disadvantages of globalization',
    'Whether governments should invest more in education than other sectors',
    'The impact of technology on communication skills',
    'The role of arts in society today',
    'Environmental problems and solutions',
    'The importance of preserving traditional cultures',
  ];

  late TabController _tabController;
  // Pagination state for latest essays.
  int _latestEssaysPageSize = initialLatestEssayPageSize;
  // Dropdown selected value for sorting/filtering in Latest Essays tab.
  String _sortOption = 'Latest';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Three tabs: Topics, Latest Essays, Top Rated Essays.
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _checkGenerationLimit() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String savedDate = prefs.getString("essayGenerationDate") ?? "";
    int count = prefs.getInt("essayGenerationCount") ?? 0;
    if (savedDate != today) {
      await prefs.setString("essayGenerationDate", today);
      await prefs.setInt("essayGenerationCount", 0);
      return true;
    }
    return count < dailyEssayGenerationLimit;
  }

  Future<void> _incrementGenerationCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt("essayGenerationCount") ?? 0;
    await prefs.setInt("essayGenerationCount", count + 1);
  }

  Future<void> _generateAndSaveEssay(String topic) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      List<Essay> existingEssays = await _firebaseService.getEssaysByTopic(topic);
      Essay essay;

      if (existingEssays.isEmpty) {
        bool allowed = await _checkGenerationLimit();
        if (!allowed) {
          _showSnackBar('Daily generation limit reached. Please try again tomorrow.');
          setState(() {
            _isLoading = false;
          });
          return;
        }
        essay = await _chatGPTService.createEssay(topic);
        await _firebaseService.saveEssay(essay);
        await _incrementGenerationCount();
      } else {
        essay = existingEssays.first;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EssayScreen(essay: essay),
        ),
      );
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Essay>> _fetchLatestEssays() async {
    List<Essay> essays = await _firebaseService.getEssays();
    essays.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return essays;
  }

  Future<List<Essay>> _fetchTopRatedEssays() async {
    List<Essay> essays = await _firebaseService.getTopRatedEssays(minRating: 5);
    return essays;
  }

  Future<void> _showCustomTopicDialog() async {
    String customTopic = "";
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Generate New Essay"),
          content: TextField(
            onChanged: (value) {
              customTopic = value;
            },
            decoration: const InputDecoration(
              hintText: "Enter your essay topic",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (customTopic.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _generateAndSaveEssay(customTopic.trim());
                }
              },
              child: const Text("Generate"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    if (_tabController.index != 0) {
      _tabController.index = 0;
      return false;
    }
    return true;
  }

  Widget _buildTopicsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        return TopicCard(
          topic: topics[index],
          onTap: () {
            _generateAndSaveEssay(topics[index]);
          },
        );
      },
    );
  }

  Widget _buildLatestEssaysTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: _sortOption,
            onChanged: (newValue) {
              if (newValue == 'Top Rated') {
                _tabController.index = 2;
              } else {
                setState(() {
                  _sortOption = newValue!;
                });
              }
            },
            items: <String>['Latest', 'Top Rated']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text("Sort by: $value"),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Essay>>(
            future: _fetchLatestEssays(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                final essays = snapshot.data!;
                if (essays.isEmpty) {
                  return const Center(child: Text("No essays available."));
                }
                final totalCount = essays.length;
                final displayCount = _latestEssaysPageSize < totalCount
                    ? _latestEssaysPageSize + 1
                    : totalCount;
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _latestEssaysPageSize = initialLatestEssayPageSize;
                    });
                    await _fetchLatestEssays();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: displayCount,
                    itemBuilder: (context, index) {
                      if (_latestEssaysPageSize < totalCount && index == _latestEssaysPageSize) {
                        return Center(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _latestEssaysPageSize += latestEssayPageIncrement;
                              });
                            },
                            child: const Text("Load More"),
                          ),
                        );
                      } else {
                        final essay = essays[index];
                        String generatedDate = DateFormat('dd/MM/yyyy').format(essay.createdAt);
                        return Card(
                          elevation: 3.0,
                          margin: const EdgeInsets.only(bottom: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EssayScreen(essay: essay),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12.0),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.description_outlined,
                                        color: Colors.blue,
                                        size: 24.0,
                                      ),
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: Text(
                                          essay.topic,
                                          style: const TextStyle(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12.0),
                                  Text(
                                    'Generated: $generatedDate',
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 12.0),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EssayScreen(essay: essay),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                      ),
                                      child: const Text('View Essay'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              } else {
                return const Center(child: Text("No essays found."));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopRatedEssaysTab() {
    return FutureBuilder<List<Essay>>(
      future: _fetchTopRatedEssays(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          final essays = snapshot.data!;
          if (essays.isEmpty) {
            return const Center(child: Text("No top-rated essays available."));
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await _fetchTopRatedEssays();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: essays.length,
              itemBuilder: (context, index) {
                final essay = essays[index];
                String generatedDate = DateFormat('dd/MM/yyyy').format(essay.createdAt);
                return Card(
                  elevation: 3.0,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EssayScreen(essay: essay),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.orange,
                                size: 24.0,
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  essay.topic,
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            'Generated: $generatedDate',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EssayScreen(essay: essay),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                              ),
                              child: const Text('View Essay'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        } else {
          return const Center(child: Text("No essays found."));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final User? currentUser = FirebaseAuth.instance.currentUser;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IELTS Essay App'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Topics"),
              Tab(text: "Latest Essays"),
              Tab(text: "Top Rated Essays"),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(currentUser?.displayName ?? 'User'),
                accountEmail: Text(currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : const AssetImage('assets/default_user.png') as ImageProvider,
                ),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  // Navigate to settings or perform other actions.
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text("Language"),
                trailing: DropdownButton<String>(
                  value: LanguageSettings.selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: "Thai", child: Text("🇹🇭 Thai")),
                    DropdownMenuItem(value: "Chinese", child: Text("🇨🇳 Chinese")),
                    DropdownMenuItem(value: "Korean", child: Text("🇰🇷 Korean")),
                    DropdownMenuItem(value: "Japanese", child: Text("🇯🇵 Japanese")),
                  ],
                  onChanged: (newValue) {
                    if (newValue != null) {
                      LanguageSettings.selectedLanguage = newValue;
                      setState(() {}); // Refresh UI.
                    }
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: widget.isDarkMode,
                onChanged: (bool value) {
                  widget.onThemeChanged(value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildTopicsTab(),
                _buildLatestEssaysTab(),
                _buildTopRatedEssaysTab(),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isLoading ? null : _showCustomTopicDialog,
          tooltip: "Generate Custom Essay",
          child: _isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.add),
        ),
      ),
    );
  }
}
