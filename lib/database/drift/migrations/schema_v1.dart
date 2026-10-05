// Frozen from drift_schema_v1.json. Do not update when adding v2 fields.
// ignore_for_file: lines_longer_than_80_chars

// Dart imports:
import 'dart:convert';

final legacyV1Tables =
    (jsonDecode(r'''
{
  "AppBmf": {
    "sql": "CREATE TABLE IF NOT EXISTS \"AppBmf\" (\"id\" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, \"subject\" INTEGER NOT NULL UNIQUE, \"title\" TEXT NULL DEFAULT '', \"rss\" TEXT NULL, \"download\" TEXT NULL, \"mkBgmId\" TEXT NULL DEFAULT '', \"mkGroupId\" TEXT NULL DEFAULT '', \"airDate\" TEXT NULL DEFAULT '', \"autoUpdate\" INTEGER NOT NULL DEFAULT 1);",
    "columns": [
      {
        "name": "id",
        "ddl": "INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT",
        "nullable": false,
        "primaryKey": true,
        "safeMissing": false
      },
      {
        "name": "subject",
        "ddl": "INTEGER NOT NULL UNIQUE",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "title",
        "ddl": "TEXT NULL DEFAULT ''",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "rss",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "download",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "mkBgmId",
        "ddl": "TEXT NULL DEFAULT ''",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "mkGroupId",
        "ddl": "TEXT NULL DEFAULT ''",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "airDate",
        "ddl": "TEXT NULL DEFAULT ''",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "autoUpdate",
        "ddl": "INTEGER NOT NULL DEFAULT 1",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": true
      }
    ]
  },
  "AppRss": {
    "sql": "CREATE TABLE IF NOT EXISTS \"AppRss\" (\"rss\" TEXT NOT NULL, \"data\" TEXT NULL, \"mkBgmId\" TEXT NULL, \"mkGroupId\" TEXT NULL, \"ttl\" INTEGER NOT NULL, \"updated\" INTEGER NOT NULL, \"pendingItems\" TEXT NOT NULL DEFAULT '[]', \"cacheVersion\" INTEGER NOT NULL DEFAULT 1, \"lastFailed\" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (\"rss\"));",
    "columns": [
      {
        "name": "rss",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": true,
        "safeMissing": false
      },
      {
        "name": "data",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "mkBgmId",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "mkGroupId",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "ttl",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "updated",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "pendingItems",
        "ddl": "TEXT NOT NULL DEFAULT '[]'",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "cacheVersion",
        "ddl": "INTEGER NOT NULL DEFAULT 1",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "lastFailed",
        "ddl": "INTEGER NOT NULL DEFAULT 0",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": true
      }
    ]
  },
  "AppConfig": {
    "sql": "CREATE TABLE IF NOT EXISTS \"AppConfig\" (\"key\" TEXT NOT NULL, \"value\" TEXT NOT NULL, PRIMARY KEY (\"key\"));",
    "columns": [
      {
        "name": "key",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": true,
        "safeMissing": false
      },
      {
        "name": "value",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      }
    ]
  },
  "AppPlayback": {
    "sql": "CREATE TABLE IF NOT EXISTS \"AppPlayback\" (\"pathKey\" TEXT NOT NULL, \"filePath\" TEXT NOT NULL, \"title\" TEXT NOT NULL, \"subject\" INTEGER NULL, \"positionMs\" INTEGER NOT NULL DEFAULT 0, \"durationMs\" INTEGER NOT NULL DEFAULT 0, \"completed\" INTEGER NOT NULL DEFAULT 0, \"updatedAt\" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (\"pathKey\"));",
    "columns": [
      {
        "name": "pathKey",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": true,
        "safeMissing": false
      },
      {
        "name": "filePath",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "title",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "subject",
        "ddl": "INTEGER NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "positionMs",
        "ddl": "INTEGER NOT NULL DEFAULT 0",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "durationMs",
        "ddl": "INTEGER NOT NULL DEFAULT 0",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "completed",
        "ddl": "INTEGER NOT NULL DEFAULT 0",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "updatedAt",
        "ddl": "INTEGER NOT NULL DEFAULT 0",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": true
      }
    ]
  },
  "BangumiUser": {
    "sql": "CREATE TABLE IF NOT EXISTS \"BangumiUser\" (\"key\" TEXT NOT NULL, \"value\" TEXT NOT NULL, PRIMARY KEY (\"key\"));",
    "columns": [
      {
        "name": "key",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": true,
        "safeMissing": false
      },
      {
        "name": "value",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      }
    ]
  },
  "BangumiCollection": {
    "sql": "CREATE TABLE IF NOT EXISTS \"BangumiCollection\" (\"subjectId\" INTEGER NOT NULL, \"subjectType\" INTEGER NOT NULL, \"rate\" INTEGER NOT NULL, \"collectionType\" INTEGER NOT NULL, \"comment\" TEXT NULL, \"tags\" TEXT NOT NULL, \"epStat\" INTEGER NOT NULL, \"volStat\" INTEGER NOT NULL, \"updatedAt\" TEXT NOT NULL, \"private\" INTEGER NOT NULL, \"subject\" TEXT NULL, PRIMARY KEY (\"subjectId\"));",
    "columns": [
      {
        "name": "subjectId",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": true,
        "safeMissing": false
      },
      {
        "name": "subjectType",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "rate",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "collectionType",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "comment",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "tags",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "epStat",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "volStat",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "updatedAt",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "private",
        "ddl": "INTEGER NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "subject",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      }
    ]
  },
  "BangumiDataSite": {
    "sql": "CREATE TABLE IF NOT EXISTS \"BangumiDataSite\" (\"id\" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, \"key\" TEXT NOT NULL UNIQUE, \"title\" TEXT NOT NULL, \"urlTemplate\" TEXT NOT NULL, \"type\" TEXT NULL, \"regions\" TEXT NULL);",
    "columns": [
      {
        "name": "id",
        "ddl": "INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT",
        "nullable": false,
        "primaryKey": true,
        "safeMissing": false
      },
      {
        "name": "key",
        "ddl": "TEXT NOT NULL UNIQUE",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "title",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "urlTemplate",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "type",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "regions",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      }
    ]
  },
  "BangumiDataItem": {
    "sql": "CREATE TABLE IF NOT EXISTS \"BangumiDataItem\" (\"id\" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, \"title\" TEXT NOT NULL, \"titleTranslate\" TEXT NULL, \"type\" TEXT NULL, \"lang\" TEXT NULL, \"officialSite\" TEXT NULL, \"begin\" TEXT NULL, \"broadcast\" TEXT NULL, \"end\" TEXT NULL, \"comment\" TEXT NULL, \"sites\" TEXT NULL);",
    "columns": [
      {
        "name": "id",
        "ddl": "INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT",
        "nullable": false,
        "primaryKey": true,
        "safeMissing": false
      },
      {
        "name": "title",
        "ddl": "TEXT NOT NULL",
        "nullable": false,
        "primaryKey": false,
        "safeMissing": false
      },
      {
        "name": "titleTranslate",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "type",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "lang",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "officialSite",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "begin",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "broadcast",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "end",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "comment",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      },
      {
        "name": "sites",
        "ddl": "TEXT NULL",
        "nullable": true,
        "primaryKey": false,
        "safeMissing": true
      }
    ]
  }
}
''')
        as Map<String, dynamic>);
