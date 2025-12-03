import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ordena_plus/domain/models/folder.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ordena_plus.db');

    return await openDatabase(
      path,
      version: 2, // Incremented version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        iconPath TEXT,
        iconKey TEXT,
        color INTEGER,
        type INTEGER NOT NULL,
        order_index INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE media_items(
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        type INTEGER NOT NULL,
        folderId TEXT,
        dateCreated INTEGER,
        FOREIGN KEY(folderId) REFERENCES folders(id) ON DELETE SET NULL
      )
    ''');

    // Insert default folders
    await db.insert('folders', {
      'id': Folder.unorganizedId,
      'name': 'Sin organizar',
      'type': FolderType.system.index,
      'order_index': 0,
    });

    await db.insert('folders', {
      'id': Folder.trashId,
      'name': 'Papelera',
      'type': FolderType.system.index,
      'order_index': 1,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to folders table
      await db.execute('ALTER TABLE folders ADD COLUMN iconKey TEXT');
      await db.execute('ALTER TABLE folders ADD COLUMN color INTEGER');
    }
  }
}
