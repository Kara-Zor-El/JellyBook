// The purpose of this file is to fetch the categories from the database

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as Http;
import 'dart:convert';
import 'package:jellybook/providers/fetchBooks.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jellybook/providers/folderProvider.dart';
import 'package:jellybook/models/entry.dart';
import 'package:jellybook/models/folder.dart';
import 'package:isar/isar.dart';
import 'package:package_info_plus/package_info_plus.dart';
// import 'package:hive_flutter/hive_flutter.dart';

// have optional perameter to have the function return the list of folders
Future<List<Map<String, dynamic>>> getServerCategories(context,
    {bool returnFolders = false}) async {
  debugPrint("getting server categories");
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken') ?? "";
  final url = prefs.getString('server') ?? "";
  final userId = prefs.getString('UserId') ?? "";
  final client = prefs.getString('client') ?? "JellyBook";
  final device = prefs.getString('device') ?? "";
  final deviceId = prefs.getString('deviceId') ?? "";
  final version = prefs.getString('version') ?? packageInfo.version;

  debugPrint("got prefs");
  Map<String, String> headers =
      getHeaders(url, client, device, deviceId, version, token);
  final response = await Http.get(
    Uri.parse(url + "/Users/" + userId + "/Views"),
    headers: headers,
  );

  debugPrint("got response");
  debugPrint(response.statusCode.toString());
  debugPrint(response.body);
  final data = await json.decode(response.body);

  bool hasComics = true;
  if (hasComics) {
    String comicsId = '';
    String etag = '';
    List<String> categories = [];
    // add all data['Items'] to categories
    data['Items'].forEach((item) {
      categories.add(item['Name']);
    });

    categories.remove('Shows');
    categories.remove('Movies');
    categories.remove('Music');
    categories.remove('Collections');
    categories.remove('shows');
    categories.remove('movies');
    categories.remove('music');
    categories.remove('collections');

    List<String> selected = [];
    List<String> includedAutomatically = [
      'comics',
      'book',
      'comic book',
      'book',
      'books',
      'comic books',
      'manga',
      'mangas',
      'comics & graphic novels',
      'graphic novels',
      'graphic novel',
      'novels',
      'novel',
      'ebook',
      'ebooks',
    ];
    for (var i = 0; i < categories.length; i++) {
      if (includedAutomatically.contains(categories[i].toLowerCase())) {
        selected.add(categories[i]);
      }
    }
    // get length of prefs.getStringList('categories') (its a List<dynamic>?)
    // List<String> selected = prefs.getStringList('categories') ?? ['Error'];
    // if (selected[0] == 'Error') {
    //   selected = await chooseCategories(categories, context);
    //   debugPrint("selected: $selected");
    //   prefs.setStringList('categories', selected);
    // }
    // if (prefs.getStringList('categories')!.length == 0) {
    //   selected = await chooseCategories(categories, context);
    //   prefs.setStringList('categories', selected);
    // } else {
    //   selected = prefs.getStringList('categories')!;
    // }
    List<Future<List<Map<String, dynamic>>>> comicsArray = [];
    List<String> comicsIds = [];
    debugPrint("selected: " + selected.toString());
    for (int i = 0; i < data['Items'].length; i++) {
      if (selected.contains(data['Items'][i]['Name'])) {
        comicsId = data['Items'][i]['Id'];
        comicsIds.add(comicsId);
        etag = data['Items'][i]['Etag'];
        comicsArray.add(getComics(comicsId, etag));
      }
    }

    // once all the comics are fetched, combine them into one list
    List<Map<String, dynamic>> comics = [];
    for (int i = 0; i < comicsArray.length; i++) {
      comics.addAll(await comicsArray[i]);
    }

    prefs.setStringList('comicsIds', comicsIds);

    if (returnFolders) {
      final isar = Isar.getInstance();
      List<String> categoriesList = [];
      for (int i = 0; i < selected.length; i++) {
        categoriesList.add(selected[i]);
      }
      debugPrint("categoriesList: $categoriesList");
      List<Entry> entries = await isar!.entrys.where().findAll();

      List<Folder> folders = [];
      await CreateFolders.getFolders(entries, categoriesList);
      folders = await isar.folders.where().findAll();

      // convert the folders to a list of maps
      List<Map<String, dynamic>> foldersList = [];
      for (int i = 0; i < folders.length; i++) {
        // toMap() function doesn't exist so we have to do it manually
        Map<String, dynamic> folderMap = {
          'id': folders[i].id,
          'name': folders[i].name,
          'bookIds': folders[i].bookIds,
          'image': folders[i].image,
        };
        foldersList.add(folderMap);
      }

      return foldersList;
    } else {
      return comics;
    }
    // debugPrint("Returning comics");
    // return comics;
  } else {
    debugPrint('No comics found');
  }
  return [];
}

Future<List<String>> chooseCategories(List<String> categories, context) async {
  List<String> selected = [];

  debugPrint("Getting categories");

  // pop up a dialog to choose categories
  // use stateful builder to rebuild the dialog when the list changes
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Choose Categories'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    title: Text(categories[index]),
                    value: selected.contains(categories[index]),
                    onChanged: (bool? value) {
                      if (value == true &&
                          !selected.contains(categories[index])) {
                        selected.add(categories[index]);
                        // debugPrint(selected.toString() + " added");
                      } else if (value == false &&
                          selected.contains(categories[index])) {
                        selected.remove(categories[index]);
                        // debugPrint(selected.toString() + " removed");
                      }
                      setState(() {});
                    },
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Done'),
                onPressed: () {
                  if (selected != null && selected.isNotEmpty) {
                    Navigator.of(context).pop();
                  } else {
                    debugPrint("No categories selected");
                    // snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No categories selected'),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
  return selected;
}
