import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleBooksService {
  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': query,
      'maxResults': '20',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List items = data['items'] ?? [];

        return items.map((item) {
          final volumeInfo =
              (item as Map<String, dynamic>)['volumeInfo']
                  as Map<String, dynamic>? ??
              {};

          String isbn = 'N/A';
          final identifiers =
              volumeInfo['industryIdentifiers'] as List<dynamic>?;
          if (identifiers != null) {
            for (var id in identifiers) {
              final map = id as Map<String, dynamic>;
              if (map['type'] == 'ISBN_13') {
                isbn = map['identifier'] as String;
                break;
              }
            }
            if (isbn == 'N/A') {
              for (var id in identifiers) {
                final map = id as Map<String, dynamic>;
                if (map['type'] == 'ISBN_10') {
                  isbn = map['identifier'] as String;
                  break;
                }
              }
            }
          }


          String capaUrl = '';
          final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
          if (imageLinks != null) {
            capaUrl =
                (imageLinks['thumbnail'] ?? imageLinks['smallThumbnail'] ?? '')
                    as String;
            capaUrl = capaUrl.replaceFirst(RegExp(r'^http://'), 'https://');
          }

          return {
            'titulo': volumeInfo['title'] ?? 'Título Desconhecido',
            'autores':
                (volumeInfo['authors'] as List<dynamic>?)?.join(', ') ??
                'Autor(es) Desconhecido(s)',
            'isbn': isbn,
            'data_publicacao': volumeInfo['publishedDate'] ?? 'N/A',
            'capa_url': capaUrl,
          };
        }).toList();
      } else {
        throw Exception('Falha na API Google Books: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao buscar livros: $e');
      return [];
    }
  }
}
