import '../database/database_helper.dart';
import '../models/person.dart';

class PersonRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<int> insertPerson(Person person) async {
    final db = await _databaseHelper.database;
    return await db.insert('persons', person.toMap());
  }

  Future<List<Person>> getAllPersons() async {
    final db = await _databaseHelper.database;
    final result = await db.query('persons', orderBy: 'created_at DESC');
    return result.map((map) => Person.fromMap(map)).toList();
  }

  Future<Person?> getPersonById(int id) async {
    final db = await _databaseHelper.database;
    final result =
        await db.query('persons', where: 'id = ?', whereArgs: [id]);

    if (result.isNotEmpty) {
      return Person.fromMap(result.first);
    }
    return null;
  }

  Future<int> deletePerson(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }
}