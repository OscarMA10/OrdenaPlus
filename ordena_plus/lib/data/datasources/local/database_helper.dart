import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ordena_plus/domain/models/folder.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ordena_plus.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Folders Table
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        iconPath TEXT,
        "order" INTEGER NOT NULL
      )
    ''');

    // Media Items Table
    await db.execute('''
      CREATE TABLE media_items (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        type INTEGER NOT NULL,
        dateCreated INTEGER,
        folderId TEXT,
        FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE SET NULL
      )
    ''');

    // Insert Default Folders
    await _insertDefaultFolders(db);
  }

  Future<void> _insertDefaultFolders(Database db) async {
    final defaultFolders = [
      const Folder(
        id: Folder.unorganizedId,
        name: 'Sin Organizar',
        type: FolderType.system,
        order: 0,
      ),
      const Folder(
        id: Folder.photosId,
        name: 'Fotos',
        type: FolderType.system,
        order: 1,
      ),
      const Folder(
        id: Folder.videosId,
        name: 'Vídeos',
        type: FolderType.system,
        order: 2,
      ),
      const Folder(
        id: Folder.trashId,
        name: 'Papelera',
        type: FolderType.system,
        order: 3,
      ),
    ];

    for (var folder in defaultFolders) {
      await db.insert('folders', folder.toMap());
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
