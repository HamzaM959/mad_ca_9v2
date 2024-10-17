import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'helper.dart'; // 导入 helper.dart

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
  Future<List<Map<String, dynamic>>> getFolders() async {
    return await DatabaseHelper.instance.getFolders();
  }

  Future<List<Map<String, dynamic>>> getCards(int folderId) async {
    return await DatabaseHelper.instance.getCards(folderId);
  }

  Future<void> addFolder(String name) async {
    await DatabaseHelper.instance.addFolder(name);
    notifyListeners();
  }

  Future<void> addCard(String name, String suit, String imageUrl, int folderId) async {
    await DatabaseHelper.instance.addCard(name, suit, imageUrl, folderId);
    notifyListeners();
  }

  Future<void> deleteCard(int cardId) async {
    await DatabaseHelper.instance.deleteCard(cardId);
    notifyListeners();
  }

  Future<void> updateFolderName(int folderId, String newName) async {
    await DatabaseHelper.instance.updateFolderName(folderId, newName);
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
                  final folderName = folder['name'];
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CardScreen(folderId: folder['id'], folderName: folderName),
                  ));
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
  final String folderName;

  CardScreen({required this.folderId, required this.folderName});

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
              _addCardDialog(context, folderId, folderName);
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
                  } else {
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

  void _addCardDialog(BuildContext context, int folderId, String folderName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddCardDialog(folderId: folderId, folderName: folderName);
      },
    );
  }
}

class AddCardDialog extends StatefulWidget {
  final int folderId;
  final String folderName;

  AddCardDialog({required this.folderId, required this.folderName});

  @override
  _AddCardDialogState createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  String selectedSuit = 'Spades';
  String selectedCardName = 'Ace';

  final List<String> suits = ['Spades', 'Clubs', 'Hearts', 'Diamonds'];
  final List<String> cardNames = ['Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King'];

  @override
  Widget build(BuildContext context) {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    return AlertDialog(
      title: Text('Add Card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String>(
            value: selectedSuit,
            onChanged: (String? newValue) {
              setState(() {
                selectedSuit = newValue!;
              });
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
              setState(() {
                selectedCardName = newValue!;
              });
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
          onPressed: () async {
            // get the number of cards in current folder
            final existingCards = await dbProvider.getCards(widget.folderId);

            //check if the card is in current folder
            bool cardExists = existingCards.any((card) =>
            card['name'] == selectedCardName && card['suit'] == selectedSuit);

            if (existingCards.length >= 6) {
              // not more than 6 cards
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
            } else if (cardExists) {
              // make sure the card is not already in the folder
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Card Already Exists'),
                    content: Text('This card already exists in this folder.'),
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
            } else if (selectedSuit.toLowerCase() != widget.folderName.toLowerCase()) {
              // make sure the suit matches
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Invalid Suit'),
                    content: Text('You can only add ${widget.folderName} cards to this folder.'),
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
            } else {
              final imageUrl = 'assets/${selectedCardName.toLowerCase()}_of_${selectedSuit.toLowerCase()}.png';
              await dbProvider.addCard(selectedCardName, selectedSuit, imageUrl, widget.folderId);
              Navigator.of(context).pop();
            }
          },
          child: Text('Add'),
        ),
      ],
    );
  }
}
