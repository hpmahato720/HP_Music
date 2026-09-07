import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HP Music',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF1ED760),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          selectedItemColor: Color(0xFF1ED760),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<SongModel> _allSongs = [];
  List<SongModel> _filteredSongs = [];
  List<int> _favoriteIds = [];
  Map<int, Uint8List?> _artworkCache = {};
  
  int _currentIndex = 0;
  int? _currentPlayingIndex;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
    _setupAudioListeners();
  }

  Future<void> _requestPermissionAndLoad() async {
    PermissionStatus status = await Permission.storage.request();
    if (status.isGranted) {
      await _loadSongs();
    } else {
      await _requestPermissionAndLoad();
    }
  }

  Future<void> _loadSongs() async {
    List<SongModel> songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      uriType: UriType.EXTERNAL,
    );
    setState(() {
      _allSongs = songs;
      _filteredSongs = songs;
    });
    for (var song in songs) {
      try {
        Uint8List? art = await _audioQuery.queryArtwork(song.id, ArtworkType.AUDIO);
        _artworkCache[song.id] = art;
      } catch (e) {
        _artworkCache[song.id] = null;
      }
    }
    setState(() {});
  }

  void _setupAudioListeners() {
    _audioPlayer.durationStream.listen((d) {
      if (d != null) setState(() => _duration = d);
    });
    _audioPlayer.positionStream.listen((p) {
      if (p != null) setState(() => _position = p);
    });
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  void _playSong(SongModel song) {
    int index = _allSongs.indexOf(song);
    setState(() => _currentPlayingIndex = index);
    _audioPlayer.setAudioSource(
      AudioSource.uri(Uri.parse(song.uri!)),
    );
    _audioPlayer.play();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _nextSong() {
    if (_currentPlayingIndex != null && _allSongs.isNotEmpty) {
      int next = (_currentPlayingIndex! + 1) % _allSongs.length;
      _playSong(_allSongs[next]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              children: [
                const Text('HP Music', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomePage(),
                _buildSearchPage(),
                _buildPlaylistPage(),
              ],
            ),
          ),
          if (_currentPlayingIndex != null)
            _buildMiniPlayer(),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlist'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    if (_allSongs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    List<SongModel> speedDialSongs = _allSongs.length > 8 ? _allSongs.sublist(0, 8) : _allSongs;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Speed dial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: speedDialSongs.length,
              itemBuilder: (ctx, index) {
                SongModel song = speedDialSongs[index];
                return GestureDetector(
                  onTap: () => _playSong(song),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildArtwork(song.id, height: 45, width: 45),
                        ),
                        const SizedBox(height: 4),
                        Text(song.title.length > 10 ? '${song.title.substring(0, 10)}...' : song.title,
                            style: const TextStyle(fontSize: 10, color: Colors.white)),
                        const Text('100 VIEWS', style: TextStyle(fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text('Keep listening', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allSongs.length,
            itemBuilder: (ctx, index) {
              SongModel song = _allSongs[index];
              return GestureDetector(
                onTap: () => _playSong(song),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _buildArtwork(song.id, height: 50, width: 50),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(song.artist ?? 'Unknown Artist', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('${_formatDuration(song.duration)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_vert, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search songs...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (value) {
              setState(() {
                _filteredSongs = _allSongs.where((song) =>
                  song.title.toLowerCase().contains(value.toLowerCase()) ||
                  (song.artist?.toLowerCase().contains(value.toLowerCase()) ?? false)
                ).toList();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSongs.length,
              itemBuilder: (ctx, index) {
                SongModel song = _filteredSongs[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildArtwork(song.id, height: 40, width: 40),
                  ),
                  title: Text(song.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(song.artist ?? 'Unknown', style: const TextStyle(color: Colors.grey)),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Color(0xFF1ED760)),
                    onPressed: () => _playSong(song),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistPage() {
    List<SongModel> favorites = _allSongs.where((song) => _favoriteIds.contains(song.id)).toList();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Favourites', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (favorites.isEmpty)
            const Expanded(child: Center(child: Text('No favourites yet!', style: TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (ctx, index) {
                  SongModel song = favorites[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildArtwork(song.id, height: 40, width: 40),
                    ),
                    title: Text(song.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(song.artist ?? 'Unknown', style: const TextStyle(color: Colors.grey)),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Color(0xFF1ED760)),
                      onPressed: () {
                        setState(() {
                          _favoriteIds.remove(song.id);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    SongModel currentSong = _allSongs[_currentPlayingIndex!];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _buildArtwork(currentSong.id, height: 40, width: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentSong.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Text(currentSong.artist ?? 'Unknown', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ProgressBar(
                  progress: _position,
                  total: _duration,
                  onSeek: (value) => _audioPlayer.seek(value),
                  barHeight: 2,
                  baseBarColor: Colors.grey[800],
                  progressBarColor: const Color(0xFF1ED760),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: const Color(0xFF1ED760), size: 35),
            onPressed: _togglePlayPause,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
            onPressed: _nextSong,
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(int id, {double height = 50, double width = 50}) {
    final art = _artworkCache[id];
    if (art != null) {
      return Image.memory(art, height: height, width: width, fit: BoxFit.cover);
    } else {
      return Container(
        height: height,
        width: width,
        color: Colors.grey[800],
        child: const Icon(Icons.music_note, color: Colors.grey),
      );
    }
  }

  String _formatDuration(int? milliseconds) {
    if (milliseconds == null) return '0:00';
    Duration dur = Duration(milliseconds: milliseconds);
    return '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }
