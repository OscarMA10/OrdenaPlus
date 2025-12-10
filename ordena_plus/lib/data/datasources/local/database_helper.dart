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
      version: 4, // Incremented version
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
        path TEXT,
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
        originalPath TEXT,
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

    if (oldVersion < 3) {
      // V3: Add 'path' column to folders
      await db.execute('ALTER TABLE folders ADD COLUMN path TEXT');

      // Migrate existing folders: Set default internal path
      // Note: We hardcode this base path as it was the previous default.
      // Future folders will have explicit paths.
      const String rootPath = '/storage/emulated/0/Pictures/Ordena+';

      final List<Map<String, dynamic>> folders = await db.query(
        'folders',
        where: 'type = ?',
        whereArgs: [FolderType.custom.index],
      );

      final batch = db.batch();
      for (final folder in folders) {
        final id = folder['id'] as String;
        final name = folder['name'] as String;
        final path = '$rootPath/$name';
        batch.update(
          'folders',
          {'path': path},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    }

    if (oldVersion < 4) {
      // V4: Add 'originalPath' to media_items
      await db.execute('ALTER TABLE media_items ADD COLUMN originalPath TEXT');

      // Best effort migration: assume current path is original path for existing items
      // This is true for unorganized items. For organized items, we lost the info,
      // but strictly speaking, their "original path" *in the app context* is where they are now.
      await db.execute('UPDATE media_items SET originalPath = path');
    }
  }
}
