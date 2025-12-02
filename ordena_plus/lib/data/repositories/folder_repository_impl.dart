import 'package:ordena_plus/data/datasources/local/database_helper.dart';
import 'package:ordena_plus/domain/models/folder.dart';
import 'package:ordena_plus/domain/repositories/folder_repository.dart';
import 'package:sqflite/sqflite.dart';

class FolderRepositoryImpl implements FolderRepository {
  final DatabaseHelper _dbHelper;

  FolderRepositoryImpl(this._dbHelper);

  @override
  Future<List<Folder>> getFolders() async {
    final db = await _dbHelper.database;
    final result = await db.query('folders', orderBy: '"order" ASC');
    return result.map((map) => Folder.fromMap(map)).toList();
  }

  @override
  Future<void> createFolder(Folder folder) async {
    final db = await _dbHelper.database;
    await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    final db = await _dbHelper.database;
    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  @override
  Future<void> deleteFolder(String id) async {
    final db = await _dbHelper.database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Folder?> getFolderById(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Folder.fromMap(result.first);
    }
    return null;
  }
}
