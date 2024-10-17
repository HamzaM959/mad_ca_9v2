import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'card_manager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE Folders (id INTEGER PRIMARY KEY, name TEXT, timestamp TEXT)',
    );
    await db.execute(
      'CREATE TABLE Cards (id INTEGER PRIMARY KEY, name TEXT, suit TEXT, imageUrl TEXT, folderId INTEGER, FOREIGN KEY(folderId) REFERENCES Folders(id))',
    );

    for (var suit in ['Spades', 'Clubs', 'Hearts', 'Diamonds']) {
      await db.insert('Folders', {
        'name': suit,
        'timestamp': DateTime.now().toString(),
      });
    }

    final List<Map<String, dynamic>> cards = [];
    for (var suit in ['Spades', 'Clubs', 'Hearts', 'Diamonds']) {
      for (var i = 1; i <= 13; i++) {
        final name = i == 1
            ? 'Ace'
            : i == 11
            ? 'Jack'
            : i == 12
            ? 'Queen'
            : i == 13
            ? 'King'
            : i.toString();
        cards.add({
          'name': '$name of $suit',
          'suit': suit,
          'imageUrl': 'assets/${name.toLowerCase()}_of_${suit.toLowerCase()}.png',
        });
      }
    }

    for (var card in cards) {
      await db.insert('Cards', card);
    }
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    final db = await instance.database;
    return await db.query('Folders');
  }

  Future<List<Map<String, dynamic>>> getCards(int folderId) async {
    final db = await instance.database;
    return await db.query('Cards', where: 'folderId = ?', whereArgs: [folderId]);
  }

  Future<void> addFolder(String name) async {
    final db = await instance.database;
    await db.insert('Folders', {
      'name': name,
      'timestamp': DateTime.now().toString(),
    });
  }

  Future<void> addCard(String name, String suit, String imageUrl, int folderId) async {
    final db = await instance.database;
    await db.insert('Cards', {'name': name, 'suit': suit, 'imageUrl': imageUrl, 'folderId': folderId});
  }

  Future<void> deleteCard(int cardId) async {
    final db = await instance.database;
    await db.delete('Cards', where: 'id = ?', whereArgs: [cardId]);
  }

  Future<void> updateFolderName(int folderId, String newName) async {
    final db = await instance.database;
    await db.update('Folders', {'name': newName}, where: 'id = ?', whereArgs: [folderId]);
  }
}
