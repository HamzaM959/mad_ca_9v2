import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DatabaseProvider(),
      child: MaterialApp(
        title: 'Card Manager',
        home: FolderScreen(),
      ),
    );
  }
}

class DatabaseProvider with ChangeNotifier {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'card_manager.db');
    return await openDatabase(
      path,
      onCreate: _onCreate,
      version: 1,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
    final db = await database;
    return await db.query('Folders');
  }

  Future<List<Map<String, dynamic>>> getCards(int folderId) async {
    final db = await database;
    return await db.query('Cards', where: 'folderId = ?', whereArgs: [folderId]);
  }

  Future<void> addFolder(String name) async {
    final db = await database;
    await db.insert('Folders', {
      'name': name,
      'timestamp': DateTime.now().toString(),
    });
    notifyListeners();
  }

  Future<void> addCard(String name, String suit, String imageUrl, int folderId) async {
    final db = await database;
    await db.insert('Cards', {'name': name, 'suit': suit, 'imageUrl': imageUrl, 'folderId': folderId});
    notifyListeners();
  }

  Future<void> deleteCard(int cardId) async {
    final db = await database;
    await db.delete('Cards', where: 'id = ?', whereArgs: [cardId]);
    notifyListeners();
  }

  Future<void> updateFolderName(int folderId, String newName) async {
    final db = await database;
    await db.update('Folders', {'name': newName}, where: 'id = ?', whereArgs: [folderId]);
    notifyListeners();
  }
}

class FolderScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dbProvider = Provider.of<DatabaseProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Card Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              _addFolderDialog(context);
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: dbProvider.getFolders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          final folders = snapshot.data as List<Map<String, dynamic>>;
          return ListView.builder(
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                title: GestureDetector(
                  onLongPress: () {
                    _renameFolderDialog(context, folder['id'], folder['name']);
                  },
                  child: Text(folder['name']),
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => CardScreen(folderId: folder['id'])));
                },
              );
            },
          );
        },
      ),
    );
  }

  void _addFolderDialog(BuildContext context) {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Folder'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Folder Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                dbProvider.addFolder(controller.text);
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _renameFolderDialog(BuildContext context, int folderId, String currentName) {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final TextEditingController controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rename Folder'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Folder Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                dbProvider.updateFolderName(folderId, controller.text);
                Navigator.of(context).pop();
              },
              child: Text('Rename'),
            ),
          ],
        );
      },
    );
  }
}

class CardScreen extends StatelessWidget {
  final int folderId;

  CardScreen({required this.folderId});

  @override
  Widget build(BuildContext context) {
    final dbProvider = Provider.of<DatabaseProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Cards'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              _addCardDialog(context, folderId);
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: dbProvider.getCards(folderId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          final cards = snapshot.data as List<Map<String, dynamic>>;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return GestureDetector(
                onTap: () {
                  if (cards.length > 3) {
                    dbProvider.deleteCard(card['id']);
                  }else{
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Card Limit Reached'),
                          content: Text('You cannot have fewer than 3 cards in this folder.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  }
                },
                child: Image.asset(card['imageUrl']),
              );
            },
          );
        },
      ),
    );
  }

  void _addCardDialog(BuildContext context, int folderId) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    // get the numbers of cards in the folder
    final existingCards = await dbProvider.getCards(folderId);

    // the number of cards is more tha 6
    if(existingCards.length >= 6){
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Card Limit Reached'),
            content: Text('You cannot add more than 6 cards to this folder.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final List<String> suits = ['Spades', 'Clubs', 'Hearts', 'Diamonds'];
        final List<String> cardNames = ['Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King'];
        String selectedSuit = suits[0];
        String selectedCardName = cardNames[0];

        return AlertDialog(
          title: Text('Add Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedSuit,
                onChanged: (String? newValue) {
                  selectedSuit = newValue!;
                },
                items: suits.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              DropdownButton<String>(
                value: selectedCardName,
                onChanged: (String? newValue) {
                  selectedCardName = newValue!;
                },
                items: cardNames.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final imageUrl = 'assets/${selectedCardName.toLowerCase()}_of_${selectedSuit.toLowerCase()}.png';
                dbProvider.addCard(selectedCardName, selectedSuit, imageUrl, folderId);
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
